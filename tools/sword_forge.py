#!/usr/bin/env python3
"""sword_forge.py -- procedurally builds the five unique boss sword meshes.

Every sword follows the rules the original imported boss sword established, so the
game's existing placement maths (BossSwordTool.Grip, EnemyCombat's boss weld,
SWORD_GRIP_FRAC) fits all of them unchanged:

- one mesh, one material, one embedded JPEG texture (1024 px), far under Roblox's
  10,000-triangle / 21,000-vertex MeshPart limits
- length along Z normalised to exactly 1.0 with the bounding box centred on the origin
- blade toward -Z (tip at z = -0.5), grip toward +Z (pommel end at z = +0.5). Studio's
  3D importer rotates this 180 deg about Y; the game already corrects for that
- identical grip layout on every sword: crossguard z 0.195..0.255, handle z 0.255..0.46,
  so the hand sits 0.38 of the length from centre (SWORD_GRIP_FRAC)
- width along Y, thickness along X, bounding box symmetric in X and Y about the grip
  axis. Studio recentres a MeshPart on its bounding box, so an off-centre silhouette
  would put the hand beside the handle. Each crossguard is the widest feature (+-0.13)
  and symmetric, which guarantees this
- guard half-span capped at 0.13 so the swords stay in proportion to a player
  (about 1.1 studs across at the 4.2-stud held length)

Usage: tools/sword_forge.py [out_dir]     (needs numpy + Pillow)
"""
import io
import json
import math
import pathlib
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = (pathlib.Path(sys.argv[1]) if len(sys.argv) > 1
       else pathlib.Path(__file__).resolve().parent.parent / "assets" / "swords")
TEX = 1024

GUARD_Z0, GUARD_Z1 = 0.195, 0.255
HANDLE_Z0, HANDLE_Z1 = 0.255, 0.46
TIP_Z, TOP_Z = -0.50, 0.50
BLADE_BASE_Z = 0.21          # blade root tucked inside the crossguard
GRIP_FRAC = 0.38
GUARD_HALF_SPAN = 0.13

# texture atlas rects (u0, v0, u1, v1), image space, v down
R_BLADE = (0.00, 0.00, 0.60, 1.00)
R_GUARD = (0.62, 0.00, 1.00, 0.30)
R_GRIP = (0.62, 0.32, 1.00, 0.60)
R_POMMEL = (0.62, 0.62, 1.00, 0.80)
R_EXTRA = (0.62, 0.82, 1.00, 1.00)
INSET = 6 / TEX              # keep UVs off rect borders so mips don't bleed


# ----------------------------------------------------------------------------- geometry
class Part:
    """A group of triangles sharing one UV rect. Winding is fixed per triangle from an
    explicit outward 'want' vector, so every primitive is outward-facing by construction."""

    def __init__(self, name, rect, smooth=False):
        self.name, self.rect, self.smooth = name, rect, smooth
        self.V, self.F = [], []

    def vert(self, x, y, z):
        self.V.append((float(x), float(y), float(z)))
        return len(self.V) - 1

    def tri(self, a, b, c, want):
        A, B, C = (np.array(self.V[i]) for i in (a, b, c))
        n = np.cross(B - A, C - A)
        if np.linalg.norm(n) < 1e-12:
            return
        if np.dot(n, want) < 0:
            b, c = c, b
        self.F.append((a, b, c))

    def quad(self, a, b, c, d, want):
        self.tri(a, b, c, want)
        self.tri(a, c, d, want)


def ccw(poly):
    area = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1]
               for i in range(len(poly)))
    return poly if area > 0 else poly[::-1]


def _segments_cross(p1, p2, p3, p4):
    def o(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    d1, d2, d3, d4 = o(p3, p4, p1), o(p3, p4, p2), o(p1, p2, p3), o(p1, p2, p4)
    return (d1 * d2 < 0) and (d3 * d4 < 0)


def assert_simple(poly, label):
    n = len(poly)
    for i in range(n):
        for j in range(i + 1, n):
            if abs(i - j) in (1, n - 1):
                continue
            if _segments_cross(poly[i], poly[(i + 1) % n], poly[j], poly[(j + 1) % n]):
                raise ValueError(f"{label}: polygon self-intersects (edges {i}, {j})")


def triangulate(poly):
    """Ear clipping for a simple CCW polygon."""
    def area2(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

    def inside(p, a, b, c):
        d1, d2, d3 = area2(p, a, b), area2(p, b, c), area2(p, c, a)
        return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))

    idx, tris = list(range(len(poly))), []
    while len(idx) > 3:
        for i in range(len(idx)):
            ia, ib, ic = idx[i - 1], idx[i], idx[(i + 1) % len(idx)]
            a, b, c = poly[ia], poly[ib], poly[ic]
            if area2(a, b, c) <= 1e-12:
                continue
            if any(inside(poly[j], a, b, c) for j in idx if j not in (ia, ib, ic)):
                continue
            tris.append((ia, ib, ic))
            idx.pop(i)
            break
        else:
            raise ValueError("ear clipping failed")
    tris.append(tuple(idx))
    return tris


def extrude(part, poly, thick, label):
    """Polygon in the (y, z) plane, extruded symmetrically along X."""
    poly = ccw(poly)
    assert_simple(poly, label)
    t = thick / 2
    top = [part.vert(t, y, z) for y, z in poly]
    bot = [part.vert(-t, y, z) for y, z in poly]
    for a, b, c in triangulate(poly):
        part.tri(top[a], top[b], top[c], (1, 0, 0))
        part.tri(bot[a], bot[b], bot[c], (-1, 0, 0))
    n = len(poly)
    for k in range(n):
        p, q = poly[k], poly[(k + 1) % n]
        part.quad(top[k], top[(k + 1) % n], bot[(k + 1) % n], bot[k], (0, q[1] - p[1], -(q[0] - p[0])))


def loft_blade(part, n, c, hw, ht):
    """Edge-sharpened hexagonal cross-section lofted from the blade root to the tip.
    c(z) = centre line (Y), hw(z) = half width, ht(z) = half thickness."""
    zs = np.linspace(BLADE_BASE_Z, TIP_Z, n)
    rings = []
    for z in zs:
        cc, w, t = c(z), max(hw(z), 0.0015), max(ht(z), 0.0008)
        e = min(w * 0.42, 0.028)
        pts = [(0.0, cc - w), (t, cc - w + e), (t, cc + w - e), (0.0, cc + w), (-t, cc + w - e), (-t, cc - w + e)]
        rings.append([part.vert(x, y, z) for x, y in pts])
    for i in range(n - 1):
        zc = (zs[i] + zs[i + 1]) / 2
        axis = np.array([0.0, c(zc), zc])
        for k in range(6):
            a, b = rings[i][k], rings[i][(k + 1) % 6]
            d, e_ = rings[i + 1][k], rings[i + 1][(k + 1) % 6]
            centre = np.mean([part.V[j] for j in (a, b, e_, d)], axis=0)
            want = centre - axis
            want[2] = 0.0
            part.quad(a, b, e_, d, want)
    for ring, z, sign in ((rings[0], zs[0], 1.0), (rings[-1], zs[-1], -1.0)):
        ctr = part.vert(0.0, c(z), z)
        for k in range(6):
            part.tri(ctr, ring[k], ring[(k + 1) % 6], (0, 0, sign))


def lathe(part, zs, radius, segs=16, cy=0.0):
    """Surface of revolution around the Z axis (circle in the X-Y plane)."""
    ang = np.linspace(0, 2 * math.pi, segs, endpoint=False)
    rings = []
    for z in zs:
        r = radius(z)
        rings.append([part.vert(r * math.cos(a), cy + r * math.sin(a), z) for a in ang])
    for i in range(len(zs) - 1):
        zc = (zs[i] + zs[i + 1]) / 2
        for k in range(segs):
            a, b = rings[i][k], rings[i][(k + 1) % segs]
            d, e = rings[i + 1][k], rings[i + 1][(k + 1) % segs]
            centre = np.mean([part.V[j] for j in (a, b, e, d)], axis=0)
            want = centre - np.array([0.0, cy, zc])
            want[2] = 0.0
            part.quad(a, b, e, d, want)
    for ring, z, sign in ((rings[0], zs[0], -1.0), (rings[-1], zs[-1], 1.0)):
        if radius(z) > 1e-6:
            ctr = part.vert(0.0, cy, z)
            for k in range(segs):
                part.tri(ctr, ring[k], ring[(k + 1) % segs], (0, 0, sign))


def torus_yz(part, zc, R, r, seg=44, tube=10):
    """Ring lying in the Y-Z plane (axis along X) -- faces the viewer from the side."""
    grid = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        ctr = np.array([0.0, R * math.cos(a), zc + R * math.sin(a)])
        out = np.array([0.0, math.cos(a), math.sin(a)])
        row = []
        for j in range(tube):
            b = 2 * math.pi * j / tube
            p = ctr + r * (math.cos(b) * out + math.sin(b) * np.array([1.0, 0, 0]))
            row.append((part.vert(*p), ctr))
        grid.append(row)
    for i in range(seg):
        for j in range(tube):
            a, ca = grid[i][j]
            b, _ = grid[(i + 1) % seg][j]
            c, cc = grid[(i + 1) % seg][(j + 1) % tube]
            d, _ = grid[i][(j + 1) % tube]
            centre = np.mean([part.V[k] for k in (a, b, c, d)], axis=0)
            part.quad(a, b, c, d, centre - (ca + cc) / 2)


def star(cx, cz, points, r_out, r_in, rot=math.pi / 2):
    out = []
    for k in range(points * 2):
        r = r_out if k % 2 == 0 else r_in
        a = rot + math.pi * k / points
        out.append((cx + r * math.cos(a), cz + r * math.sin(a)))
    return out


def grip(part, r0, ridge, wraps=6):
    zs = np.linspace(HANDLE_Z0 - 0.002, HANDLE_Z1 + 0.002, 26)
    span = HANDLE_Z1 - HANDLE_Z0
    lathe(part, zs, lambda z: r0 + ridge * abs(math.sin((z - HANDLE_Z0) / span * wraps * math.pi)), segs=16)


# ----------------------------------------------------------------------------- designs
def smooth_tip(base_fn, tip_len, power=0.9):
    """Taper a width function to a point over the last tip_len of the blade."""
    def f(z):
        w = base_fn(z)
        k = (z - TIP_Z) / tip_len
        return w * (max(k, 0.0) ** power if k < 1 else 1.0)
    return f


def lerp(a, b, t):
    return a + (b - a) * t


def design_gorgon():
    parts, blade = [], Part("blade", R_BLADE)
    hw = smooth_tip(lambda z: lerp(0.078, 0.066, min(max((BLADE_BASE_Z - z) / 0.54, 0), 1)), 0.17, 0.85)
    ht = smooth_tip(lambda z: lerp(0.020, 0.012, min(max((BLADE_BASE_Z - z) / 0.54, 0), 1)), 0.17, 0.6)
    loft_blade(blade, 38, lambda z: 0.0, hw, ht)
    guard = Part("guard", R_GUARD)
    extrude(guard, [(-0.115, 0.25), (-0.128, 0.238), (-0.13, 0.19), (-0.108, 0.205),
                    (0.108, 0.205), (0.13, 0.19), (0.128, 0.238), (0.115, 0.25)], 0.075, "gorgon guard")
    g = Part("grip", R_GRIP, smooth=True)
    grip(g, 0.022, 0.003)
    pommel = Part("pommel", R_POMMEL)
    lathe(pommel, [0.456, 0.47, 0.49, 0.5], lambda z: {0.456: 0.02, 0.47: 0.036, 0.49: 0.036, 0.5: 0.018}[z], segs=8)
    parts += [blade, guard, g, pommel]
    return parts, {"c": lambda z: 0.0, "hw": hw}


def design_frost():
    def top(z):
        return 0.042 if z > -0.40 else lerp(0.042, -0.07, (-0.40 - z) / 0.10)

    def bot(z):
        return (lerp(-0.040, -0.095, (BLADE_BASE_Z - z) / 0.51) if z > -0.30
                else lerp(-0.095, -0.07, (-0.30 - z) / 0.20))
    c = lambda z: (top(z) + bot(z)) / 2
    hw = lambda z: (top(z) - bot(z)) / 2
    ht = lambda z: lerp(0.016, 0.006, (BLADE_BASE_Z - z) / 0.71)
    blade = Part("blade", R_BLADE)
    loft_blade(blade, 40, c, hw, ht)
    spikes = Part("spikes", R_EXTRA)
    for i, z0 in enumerate((0.10, -0.02, -0.14, -0.26)):
        extrude(spikes, [(0.038, z0), (0.075, z0 - 0.055), (0.038, z0 - 0.05)], 0.02, f"frost spike {i}")
    guard = Part("guard", R_GUARD)
    extrude(guard, [(-0.045, 0.255), (-0.045, 0.24), (-0.13, 0.165), (-0.055, 0.2),
                    (0.055, 0.2), (0.13, 0.165), (0.045, 0.24), (0.045, 0.255)], 0.06, "frost guard")
    g = Part("grip", R_GRIP, smooth=True)
    grip(g, 0.020, 0.0025, wraps=8)
    pommel = Part("pommel", R_POMMEL)
    lathe(pommel, [0.456, 0.476, 0.5], lambda z: {0.456: 0.012, 0.476: 0.03, 0.5: 0.0}[z], segs=6)
    return [blade, spikes, guard, g, pommel], {"c": c, "hw": hw}


def design_infernal():
    wave = lambda z: (BLADE_BASE_Z - z) * 30
    c = lambda z: 0.010 * math.sin(wave(z))
    hw = smooth_tip(lambda z: (0.058 - 0.012 * (BLADE_BASE_Z - z) / 0.71) + 0.008 * math.sin(wave(z) + 1.2), 0.14)
    ht = smooth_tip(lambda z: lerp(0.016, 0.009, (BLADE_BASE_Z - z) / 0.71), 0.14, 0.6)
    blade = Part("blade", R_BLADE)
    loft_blade(blade, 72, c, hw, ht)
    guard = Part("guard", R_GUARD)
    extrude(guard, [(-0.04, 0.255), (-0.08, 0.25), (-0.12, 0.215), (-0.13, 0.155), (-0.10, 0.19),
                    (-0.06, 0.205), (0.06, 0.205), (0.10, 0.19), (0.13, 0.155), (0.12, 0.215),
                    (0.08, 0.25), (0.04, 0.255)], 0.065, "infernal guard")
    g = Part("grip", R_GRIP, smooth=True)
    grip(g, 0.021, 0.003, wraps=7)
    pommel = Part("pommel", R_POMMEL)
    extrude(pommel, [(-0.03, 0.456), (0.03, 0.456), (0.035, 0.474), (0.018, 0.489), (0.0, 0.5),
                     (-0.02, 0.488), (-0.035, 0.472)], 0.045, "infernal pommel")
    return [blade, guard, g, pommel], {"c": c, "hw": hw}


def design_void():
    c = lambda z: 0.060 * ((BLADE_BASE_Z - z) / 0.71) ** 2
    hw = smooth_tip(lambda z: 0.047 - 0.010 * (BLADE_BASE_Z - z) / 0.71, 0.12)
    ht = smooth_tip(lambda z: lerp(0.015, 0.008, (BLADE_BASE_Z - z) / 0.71), 0.12, 0.6)
    blade = Part("blade", R_BLADE)
    loft_blade(blade, 44, c, hw, ht)
    teeth = Part("teeth", R_EXTRA)
    for i, z0 in enumerate((0.02, -0.10, -0.22)):
        yb = c(z0) - hw(z0) + 0.004
        extrude(teeth, [(yb, z0), (yb - 0.03, z0 - 0.03), (yb, z0 - 0.045)], 0.018, f"void tooth {i}")
    guard = Part("guard", R_GUARD)
    extrude(guard, [(-0.035, 0.255), (-0.13, 0.235), (-0.095, 0.215), (-0.115, 0.17), (-0.065, 0.205),
                    (0.05, 0.205), (0.13, 0.18), (0.085, 0.225), (0.10, 0.25), (0.035, 0.255)], 0.06, "void guard")
    g = Part("grip", R_GRIP, smooth=True)
    grip(g, 0.020, 0.0025, wraps=6)
    pommel = Part("pommel", R_POMMEL, smooth=True)
    R, zc = 0.022, 0.478
    zs = [zc - R + 2 * R * k / 12 for k in range(13)]
    lathe(pommel, zs, lambda z: math.sqrt(max(R * R - (z - zc) ** 2, 0.0)), segs=16)
    return [blade, teeth, guard, g, pommel], {"c": c, "hw": hw}


def design_celestial():
    def base_w(z):
        t = (BLADE_BASE_Z - z) / 0.71
        return 0.040 - 0.008 * math.sin(min(t / 0.45, 1) * math.pi / 2) + 0.018 * math.exp(-((t - 0.76) / 0.12) ** 2)
    hw = smooth_tip(base_w, 0.10)
    ht = smooth_tip(lambda z: lerp(0.013, 0.007, (BLADE_BASE_Z - z) / 0.71), 0.10, 0.6)
    blade = Part("blade", R_BLADE)
    loft_blade(blade, 48, lambda z: 0.0, hw, ht)
    halo = Part("halo", R_EXTRA, smooth=True)
    torus_yz(halo, 0.115, 0.075, 0.009)
    guard = Part("guard", R_GUARD)
    # 4-point star: long horizontal points, short vertical ones -- a uniform star would run
    # its upper point up the handle into the hand
    extrude(guard, [(0.13, 0.226), (0.028, 0.247), (0.0, 0.265), (-0.028, 0.247),
                    (-0.13, 0.226), (-0.028, 0.205), (0.0, 0.185), (0.028, 0.205)], 0.05, "celestial guard")
    g = Part("grip", R_GRIP, smooth=True)
    grip(g, 0.019, 0.002, wraps=5)
    pommel = Part("pommel", R_POMMEL)
    extrude(pommel, star(0.0, 0.478, 5, 0.022, 0.009), 0.03, "celestial pommel")
    return [blade, halo, guard, g, pommel], {"c": lambda z: 0.0, "hw": hw}


# ----------------------------------------------------------------------------- texture
def vnoise(h, w, cells, seed):
    g = np.random.default_rng(seed).random((cells, cells))
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255.0


def fbm(h, w, seed, base=6, octaves=4):
    out, amp, tot = np.zeros((h, w), np.float32), 1.0, 0.0
    for o in range(octaves):
        out += amp * vnoise(h, w, base * 2 ** o, seed + o)
        tot += amp
        amp *= 0.5
    return out / tot


def voronoi(h, w, n, seed, res=256):
    rng = np.random.default_rng(seed)
    pts = rng.random((n, 2))
    yy, xx = np.mgrid[0:res, 0:res] / res
    d = np.sqrt((xx[..., None] - pts[:, 0]) ** 2 + (yy[..., None] - pts[:, 1]) ** 2)
    d.sort(axis=-1)
    cell = np.argmin(np.sqrt((xx[..., None] - pts[:, 0]) ** 2 + (yy[..., None] - pts[:, 1]) ** 2), axis=-1)
    def up(a):
        img = Image.fromarray(a.astype(np.float32), mode="F").resize((w, h), Image.BILINEAR)
        return np.asarray(img, dtype=np.float32)
    rnd = rng.random(n)[cell]
    return up(d[..., 0]), up(d[..., 1]), up(rnd)


def C(*rgb):
    return np.array(rgb, np.float32) / 255.0


def mix(a, b, t):
    t = np.clip(t, 0, 1)[..., None]
    return a * (1 - t) + b * t


def rect_px(rect):
    u0, v0, u1, v1 = rect
    return int(round(u0 * TEX)), int(round(v0 * TEX)), int(round(u1 * TEX)), int(round(v1 * TEX))


def paint(theme, blade_bounds, shape, seed):
    img = np.zeros((TEX, TEX, 3), np.float32)

    # ---- blade: painted in blade space so edges/fullers follow the real outline
    x0, y0, x1, y1 = rect_px(R_BLADE)
    H, W = y1 - y0, x1 - x0
    (ymin, ymax), (zmin, zmax) = blade_bounds
    uu, vv = np.meshgrid((np.arange(W) + 0.5) / W, (np.arange(H) + 0.5) / H)
    uu = (uu - INSET / (R_BLADE[2] - R_BLADE[0])) / (1 - 2 * INSET / (R_BLADE[2] - R_BLADE[0]))
    vv = (vv - INSET / (R_BLADE[3] - R_BLADE[1])) / (1 - 2 * INSET / (R_BLADE[3] - R_BLADE[1]))
    Y = ymin + uu * (ymax - ymin)
    Z = zmax - vv * (zmax - zmin)
    cz = np.vectorize(shape["c"])(Z[:, 0])[:, None]
    hz = np.maximum(np.vectorize(shape["hw"])(Z[:, 0]), 0.002)[:, None]
    S = np.clip((Y - cz) / hz, -1.2, 1.2)
    A = np.abs(S)
    nz = fbm(H, W, seed)
    T = (zmax - Z) / (zmax - zmin)  # 0 at root, 1 at tip
    img[y0:y1, x0:x1] = theme["blade"](S, A, Z, T, nz, H, W, seed)

    # ---- the other parts: themed surface patterns in rect-local space
    for key, rect in (("guard", R_GUARD), ("grip", R_GRIP), ("pommel", R_POMMEL), ("extra", R_EXTRA)):
        x0, y0, x1, y1 = rect_px(rect)
        H, W = y1 - y0, x1 - x0
        u, v = np.meshgrid((np.arange(W) + 0.5) / W, (np.arange(H) + 0.5) / H)
        img[y0:y1, x0:x1] = theme[key](u, v, fbm(H, W, seed + 17 + len(key)), H, W, seed)

    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))


def wrap(u, v, a, b, freq=7.0):
    band = ((u * 2.2 + v * freq) % 1.0) < 0.5
    return np.where(band[..., None], a, b)


def sparkle(H, W, seed, density=0.0015):
    m = np.random.default_rng(seed).random((H, W)) < density
    img = Image.fromarray((m * 255).astype(np.uint8)).resize((W, H))
    from PIL import ImageFilter
    return np.asarray(img.filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255.0 * 3


THEMES = {
    "Boss_Gorgon": {
        "blade": lambda S, A, Z, T, nz, H, W, sd: mix(
            mix(mix(C(92, 96, 104) * (0.85 + 0.3 * nz[..., None]), C(52, 55, 62),
                    np.exp(-(S / 0.13) ** 2) * np.clip((0.72 - T) / 0.2, 0, 1)),
                C(140, 28, 32), 0.45 * (nz > 0.55) * np.clip((0.35 - T) / 0.35, 0, 1)),
            C(212, 216, 224), (A - 0.6) / 0.3),
        "guard": lambda u, v, nz, H, W, sd: mix(C(72, 72, 78) * (0.8 + 0.4 * nz[..., None]), C(175, 175, 182),
                                                 (np.min([((u - c) ** 2 + ((v - 0.5) * 0.35) ** 2) for c in (0.12, 0.5, 0.88)],
                                                         axis=0) < 0.0016).astype(np.float32)),
        "grip": lambda u, v, nz, H, W, sd: wrap(u, v, C(105, 26, 30), C(70, 17, 21)) * (0.85 + 0.3 * nz[..., None]),
        "pommel": lambda u, v, nz, H, W, sd: mix(C(85, 85, 94), C(170, 172, 180), 1 - np.hypot(u - 0.4, v - 0.35) * 2.2),
        "extra": lambda u, v, nz, H, W, sd: np.broadcast_to(C(80, 80, 88), u.shape + (3,)).copy(),
    },
    "Boss_FrostRevenant": {
        "blade": lambda S, A, Z, T, nz, H, W, sd: (lambda d1, d2, cell: np.clip(
            mix(mix(mix(C(170, 212, 238) * (0.8 + 0.3 * cell[..., None]), C(232, 250, 255), (A - 0.55) / 0.35),
                    C(110, 165, 205), (S - 0.82) / 0.12),
                C(255, 255, 255), np.clip((nz - 0.72) / 0.1, 0, 1) + np.clip(1 - (d2 - d1) / 0.012, 0, 1) * 0.35)
            + sparkle(H, W, sd) [..., None] * 0.3, 0, 1))(*voronoi(H, W, 70, sd)),
        "guard": lambda u, v, nz, H, W, sd: (lambda d1, d2, cell: mix(C(110, 190, 232) * (0.75 + 0.4 * cell[..., None]),
                                                                    C(235, 250, 255), 1 - (d2 - d1) / 0.02))(*voronoi(H, W, 30, sd + 3)),
        "grip": lambda u, v, nz, H, W, sd: wrap(u, v, C(28, 45, 78), C(60, 105, 150), 9.0),
        "pommel": lambda u, v, nz, H, W, sd: mix(C(120, 190, 232), C(235, 252, 255), 1 - v),
        "extra": lambda u, v, nz, H, W, sd: mix(C(170, 215, 240), C(250, 255, 255), u * 0.6 + (1 - v) * 0.4),
    },
    "Boss_InfernalColossus": {
        "blade": lambda S, A, Z, T, nz, H, W, sd: (lambda d1, d2, cell: (lambda crack: np.clip(
            mix(mix(C(30, 25, 25) * (0.75 + 0.5 * nz[..., None]),
                    mix(C(255, 85, 20), C(255, 225, 95), crack ** 2), crack),
                C(255, 135, 40), (A - 0.72) / 0.28 + 0.25 * np.clip((0.2 - T) / 0.2, 0, 1)), 0, 1))(
            np.clip(1 - (d2 - d1) / 0.03, 0, 1) ** 1.6))(*voronoi(H, W, 55, sd)),
        "guard": lambda u, v, nz, H, W, sd: (lambda d1, d2, cell: mix(C(34, 27, 27) * (0.8 + 0.4 * nz[..., None]),
                                                                    C(255, 120, 35), np.clip(1 - (d2 - d1) / 0.025, 0, 1) ** 2))(
            *voronoi(H, W, 25, sd + 5)),
        "grip": lambda u, v, nz, H, W, sd: wrap(u, v, C(42, 36, 36), C(125, 40, 20), 8.0),
        "pommel": lambda u, v, nz, H, W, sd: mix(mix(C(200, 40, 15), C(255, 140, 30), 1 - v), C(255, 230, 110),
                                                  np.clip((0.45 - v) / 0.45, 0, 1) * (1 - np.abs(u - 0.5) * 2)),
        "extra": lambda u, v, nz, H, W, sd: np.broadcast_to(C(40, 30, 30), u.shape + (3,)).copy(),
    },
    "Boss_VoidWraith": {
        "blade": lambda S, A, Z, T, nz, H, W, sd: (lambda vein: np.clip(
            mix(mix(mix(C(26, 10, 40) * (0.75 + 0.4 * nz[..., None]), C(190, 80, 255), vein),
                    C(245, 200, 255), vein ** 4), C(165, 70, 235), (A - 0.76) / 0.24)
            + sparkle(H, W, sd, 0.001)[..., None] * 0.5, 0, 1))(
            np.clip(1 - np.abs(np.sin(Z * 42 + S * 5 + nz * 9)) / 0.14, 0, 1)),
        "guard": lambda u, v, nz, H, W, sd: mix(C(38, 14, 58) * (0.8 + 0.4 * nz[..., None]), C(200, 95, 255),
                                                 np.clip(1 - np.abs(np.sin(u * 20 + nz * 8)) / 0.12, 0, 1)),
        "grip": lambda u, v, nz, H, W, sd: wrap(u, v, C(18, 12, 24), C(95, 42, 138), 7.0),
        "pommel": lambda u, v, nz, H, W, sd: mix(C(150, 40, 220), C(255, 235, 255), 1 - np.hypot(u - 0.5, v - 0.5) * 2.4),
        "extra": lambda u, v, nz, H, W, sd: mix(C(30, 12, 45), C(190, 85, 250), u ** 2),
    },
    "Boss_CelestialTitan": {
        "blade": lambda S, A, Z, T, nz, H, W, sd: np.clip(
            mix(mix(mix(C(246, 240, 218) * (0.92 + 0.12 * nz[..., None]), C(255, 255, 250), (A - 0.6) / 0.3),
                    C(214, 168, 58),
                    ((np.abs(S - 0.36 * np.sin(Z * 38)) < 0.05) | (np.abs(S + 0.36 * np.sin(Z * 38)) < 0.05)
                     | (A < 0.035)).astype(np.float32) * np.clip((0.9 - T) / 0.15, 0, 1)),
                C(255, 250, 225), 0) + sparkle(H, W, sd, 0.0012)[..., None] * 0.4, 0, 1),
        "guard": lambda u, v, nz, H, W, sd: mix(C(222, 176, 66) * (0.85 + 0.3 * nz[..., None]), C(255, 238, 170),
                                                 np.clip(1 - np.abs(v - 0.5) / 0.12, 0, 1)),
        "grip": lambda u, v, nz, H, W, sd: wrap(u, v, C(238, 234, 224), C(214, 170, 60), 5.0),
        "pommel": lambda u, v, nz, H, W, sd: mix(C(225, 180, 70), C(255, 245, 200), 1 - np.hypot(u - 0.5, v - 0.4) * 2),
        "extra": lambda u, v, nz, H, W, sd: mix(C(232, 188, 80), C(255, 242, 185), np.abs(np.sin(u * 18)) ** 3),
    },
}

DESIGNS = {
    "Boss_Gorgon": ("Warlord Greatsword", design_gorgon),
    "Boss_FrostRevenant": ("Frostfang Cleaver", design_frost),
    "Boss_InfernalColossus": ("Inferno Edge", design_infernal),
    "Boss_VoidWraith": ("Voidrend Blade", design_void),
    "Boss_CelestialTitan": ("Astral Eclipse", design_celestial),
}


# ----------------------------------------------------------------------------- export
def assemble(parts):
    P, N, UV, I = [], [], [], []
    for part in parts:
        V = np.array(part.V, np.float64)
        used = sorted({i for f in part.F for i in f})
        ys, zs = V[used, 1], V[used, 2]
        ymn, ymx, zmn, zmx = ys.min(), ys.max(), zs.min(), zs.max()
        u0, v0, u1, v1 = part.rect
        u0, v0, u1, v1 = u0 + INSET, v0 + INSET, u1 - INSET, v1 - INSET

        def uv(p):
            return (u0 + (p[1] - ymn) / max(ymx - ymn, 1e-9) * (u1 - u0),
                    v0 + (zmx - p[2]) / max(zmx - zmn, 1e-9) * (v1 - v0))

        if part.smooth:
            acc = np.zeros_like(V)
            for a, b, c in part.F:
                n = np.cross(V[b] - V[a], V[c] - V[a])
                acc[[a, b, c]] += n
            base = len(P)
            remap = {}
            for i in used:
                remap[i] = len(P)
                n = acc[i] / (np.linalg.norm(acc[i]) or 1)
                P.append(V[i]); N.append(n); UV.append(uv(V[i]))
            I += [(remap[a], remap[b], remap[c]) for a, b, c in part.F]
        else:
            for a, b, c in part.F:
                n = np.cross(V[b] - V[a], V[c] - V[a])
                n /= np.linalg.norm(n)
                k = len(P)
                for i in (a, b, c):
                    P.append(V[i]); N.append(n); UV.append(uv(V[i]))
                I.append((k, k + 1, k + 2))
    return (np.array(P, np.float32), np.array(N, np.float32), np.array(UV, np.float32),
            np.array(I, np.uint32))


def write_glb(path, name, P, N, UV, I, jpeg):
    idx = I.ravel().astype(np.uint16 if len(P) < 65536 else np.uint32)
    blobs = [P.tobytes(), N.tobytes(), UV.tobytes(), idx.tobytes(), jpeg]
    pad = lambda b: b + b"\x00" * ((4 - len(b) % 4) % 4)
    offs, cur, parts = [], 0, []
    for b in blobs:
        offs.append((cur, len(b)))
        pb = pad(b); parts.append(pb); cur += len(pb)
    BIN = b"".join(parts)
    gltf = {
        "asset": {"version": "2.0", "generator": "lemonade sword_forge"},
        "scene": 0, "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": name}],
        "meshes": [{"name": name, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
                                                  "indices": 3, "material": 0}]}],
        "materials": [{"name": name + "Mat", "doubleSided": False,
                       "pbrMetallicRoughness": {"baseColorTexture": {"index": 0},
                                                "metallicFactor": 0.6, "roughnessFactor": 0.45}}],
        "textures": [{"source": 0, "sampler": 0}],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 33071, "wrapT": 33071}],
        "images": [{"bufferView": 4, "mimeType": "image/jpeg"}],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": len(P), "type": "VEC3",
             "min": P.min(axis=0).tolist(), "max": P.max(axis=0).tolist()},
            {"bufferView": 1, "componentType": 5126, "count": len(N), "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": len(UV), "type": "VEC2"},
            {"bufferView": 3, "componentType": 5123 if idx.dtype == np.uint16 else 5125,
             "count": len(idx), "type": "SCALAR"},
        ],
        "bufferViews": [{"buffer": 0, "byteOffset": o, "byteLength": l, **({"target": t} if t else {})}
                        for (o, l), t in zip(offs, (34962, 34962, 34962, 34963, None))],
        "buffers": [{"byteLength": len(BIN)}],
    }
    J = json.dumps(gltf, separators=(",", ":")).encode()
    J += b" " * ((4 - len(J) % 4) % 4)
    glb = b"glTF" + struct.pack("<II", 2, 12 + 8 + len(J) + 8 + len(BIN))
    glb += struct.pack("<I", len(J)) + b"JSON" + J + struct.pack("<I", len(BIN)) + b"BIN\x00" + BIN
    path.write_bytes(glb)
    return len(glb)


def render_side(P, N, UV, I, tex, height=900):
    """Flat-shaded side view (looking down -X), pommel up. For eyeballing only."""
    ss, pad = 3, 30
    ymax = float(np.abs(P[:, 1]).max())
    sc = height * ss
    Wd, Hd = int(2 * ymax * sc) + 2 * pad * ss, int(sc) + 2 * pad * ss
    img = Image.new("RGB", (Wd, Hd), (24, 24, 30))
    dr = ImageDraw.Draw(img)
    t = np.asarray(tex, np.float32) / 255.0
    order = np.argsort(P[I].mean(axis=1)[:, 0])
    for fi in order:
        a, b, c = I[fi]
        n = N[a] if np.allclose(N[a], N[b]) else (N[a] + N[b] + N[c]) / 3
        uvc = UV[[a, b, c]].mean(axis=0)
        col = t[min(int(uvc[1] * TEX), TEX - 1), min(int(uvc[0] * TEX), TEX - 1)]
        shade = 0.45 + 0.55 * max(n[0], 0) + 0.12 * max(n[2], 0)
        rgb = tuple(int(min(1, x * shade) * 255) for x in col)
        pts = [((P[k, 1] + ymax) * sc + pad * ss, (TOP_Z - P[k, 2]) * sc + pad * ss) for k in (a, b, c)]
        dr.polygon(pts, fill=rgb)
    return img.resize((Wd // ss, Hd // ss), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest, previews = {}, []
    for i, (key, (label, build)) in enumerate(DESIGNS.items()):
        parts, shape = build()
        blade = next(p for p in parts if p.name == "blade")
        BV = np.array(blade.V)
        bounds = ((BV[:, 1].min(), BV[:, 1].max()), (BV[:, 2].min(), BV[:, 2].max()))
        tex = paint(THEMES[key], bounds, shape, seed=1000 + 97 * i)
        P, N, UV, I = assemble(parts)

        mn, mx = P.min(axis=0), P.max(axis=0)
        checks = {
            "tris<=10000": len(I) <= 10000,
            "verts<=21000": len(P) <= 21000,
            "length==1": abs((mx[2] - mn[2]) - 1.0) < 1e-5,
            "tip z=-0.5": abs(mn[2] - TIP_Z) < 1e-5,
            "pommel z=+0.5": abs(mx[2] - TOP_Z) < 1e-5,
            "x symmetric": abs(mx[0] + mn[0]) < 1e-5,
            "y symmetric": abs(mx[1] + mn[1]) < 1e-4,
            "guard widest": abs(mx[1] - GUARD_HALF_SPAN) < 1e-4,
            "hand on handle": HANDLE_Z0 < GRIP_FRAC < HANDLE_Z1,
        }
        failed = [k for k, ok in checks.items() if not ok]
        if failed:
            raise SystemExit(f"{key}: rule check failed: {failed} (bbox {mn} .. {mx})")

        buf = io.BytesIO()
        tex.save(buf, "JPEG", quality=92)
        size = write_glb(OUT / f"{key}.glb", key, P, N, UV, I, buf.getvalue())
        manifest[key] = {
            "name": label, "file": f"{key}.glb", "bytes": size,
            "triangles": int(len(I)), "vertices": int(len(P)),
            "meshSize": [round(float(v), 5) for v in (mx - mn)],
            "gripFrac": GRIP_FRAC, "guardZ": [GUARD_Z0, GUARD_Z1], "handleZ": [HANDLE_Z0, HANDLE_Z1],
            "checks": "all passed",
        }
        previews.append((label, render_side(P, N, UV, I, tex)))
        print(f"{key:23} {label:19} tris={len(I):5} verts={len(P):5} "
              f"meshSize=({mx[0]-mn[0]:.3f}, {mx[1]-mn[1]:.3f}, {mx[2]-mn[2]:.3f})  {size/1024:.0f} KB")

    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))
    gap, top = 40, 60
    Wt = sum(p.width for _, p in previews) + gap * (len(previews) + 1)
    Ht = max(p.height for _, p in previews) + top + 20
    sheet = Image.new("RGB", (Wt, Ht), (18, 18, 22))
    dr = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
    x = gap
    for label, p in previews:
        sheet.paste(p, (x, top))
        tw = dr.textlength(label, font=font)
        dr.text((x + (p.width - tw) / 2, 18), label, fill=(235, 235, 240), font=font)
        x += p.width + gap
    sheet.save(OUT / "preview.png")
    print(f"wrote {len(previews)} swords + manifest.json + preview.png to {OUT}")


if __name__ == "__main__":
    main()
