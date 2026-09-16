#!/usr/bin/env python3
"""Oblique Pillow render of generated map parts, for eyeballing models without Studio.

    python3 tools/preview_model.py out.png --box x0 x1 z0 z1 [--yaw 35] [--pitch 30] [--scale 6]

Draws every REGISTRY part (from tools/map_forge.py) whose centre lies in the XZ box, as shaded
boxes/cylinders projected with a simple rotate-then-tilt camera, painter-sorted by depth.
Markers, proxies and volumes are skipped. Wedges draw as boxes (close enough for placement).
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import map_forge  # noqa: E402


def collect(box, ymax=80.0):
    """Regenerate the map and return the REGISTRY parts whose centre lies in the XZ box."""
    import random
    map_forge.REGISTRY.clear()
    map_forge.USED_CLIFF_TOPS.clear()
    rng = random.Random(20260915)
    map_forge.build_hub(rng)
    map_forge.build_iron_lowlands(rng)
    map_forge.build_markers()
    x0, x1, z0, z1 = box
    return [e for e in map_forge.REGISTRY
            if x0 <= e["pos"][0] <= x1 and z0 <= e["pos"][2] <= z1 and e["layer"] not in ("marker", "volume", "proxy")
            and e["transparency"] < 0.9 and e["pos"][1] - e["size"][1] / 2 < ymax
            and not (e["layer"] == "ground" and max(e["size"][0], e["size"][2]) > 1.5 * max(x1 - x0, z1 - z0))]


def render(parts, out, yaw=35.0, pitch=30.0, scale=6.0):
    """Draw REGISTRY-style part dicts ({size, pos, rot, color, shape}) to `out`."""
    from PIL import Image, ImageDraw

    class Args:
        pass
    args = Args()
    args.out, args.yaw, args.pitch, args.scale = out, yaw, pitch, scale
    cy, sy = math.cos(math.radians(args.yaw)), math.sin(math.radians(args.yaw))
    cp, sp = math.cos(math.radians(args.pitch)), math.sin(math.radians(args.pitch))
    light = (0.4, 0.8, 0.45)
    ln = math.sqrt(sum(c * c for c in light))
    light = tuple(c / ln for c in light)

    def cam(p):  # world → camera (x right, y up, z depth toward viewer); camera sits at +z, tilted down
        x, y, z = p
        rx, rz = x * cy - z * sy, x * sy + z * cy
        return rx, y * cp - rz * sp, rz * cp + y * sp

    def prism_faces(e, n=10):
        """Cylinder (axis local X) as an n-sided prism."""
        sx, sy_, sz = e["size"]
        r = e["rot"]
        cx, cy_, cz = e["pos"]
        rad = sy_ / 2
        ring = []
        for k in range(n):
            a = math.tau * k / n
            ring.append((math.cos(a) * rad, math.sin(a) * rad))
        def w(lx, ly, lz):
            v = map_forge.apply(r, (lx, ly, lz))
            return (cx + v[0], cy_ + v[1], cz + v[2])
        out = []
        for sgn in (-1, 1):
            quad = [w(sgn * sx / 2, y, z) for y, z in (ring if sgn > 0 else ring[::-1])]
            out.append((quad, map_forge.apply(r, (sgn, 0, 0))))
        for k in range(n):
            (y0, z0_), (y1, z1_) = ring[k], ring[(k + 1) % n]
            quad = [w(-sx / 2, y0, z0_), w(sx / 2, y0, z0_), w(sx / 2, y1, z1_), w(-sx / 2, y1, z1_)]
            my, mz = (y0 + y1) / 2 / rad, (z0_ + z1_) / 2 / rad
            out.append((quad, map_forge.apply(r, (0, my, mz))))
        return out

    def faces(e):
        if e["shape"] == "Cylinder":
            return prism_faces(e)
        sx, sy_, sz = e["size"]
        r = e["rot"]
        cx, cy_, cz = e["pos"]
        corners = {}
        for ix in (-1, 1):
            for iy in (-1, 1):
                for iz in (-1, 1):
                    v = map_forge.apply(r, (ix * sx / 2, iy * sy_ / 2, iz * sz / 2))
                    corners[(ix, iy, iz)] = (cx + v[0], cy_ + v[1], cz + v[2])
        out = []
        for axis, sign in ((0, 1), (0, -1), (1, 1), (1, -1), (2, 1), (2, -1)):
            quad = [k for k in corners if k[axis] == sign]
            # order around the face
            others = [i for i in range(3) if i != axis]
            quad.sort(key=lambda k: math.atan2(k[others[1]], k[others[0]]))
            n = map_forge.apply(r, tuple(sign if i == axis else 0 for i in range(3)))
            out.append(([corners[k] for k in quad], n))
        return out

    def tiles(quad, step=5.0):
        """Split a quad into tiles ≤ step studs so painter's sorting stays honest for big slabs."""
        if len(quad) != 4:
            return [quad]
        a, b, c, d = quad
        nu = max(1, int(math.dist(a, b) / step))
        nv = max(1, int(math.dist(a, d) / step))
        if nu == 1 and nv == 1:
            return [quad]
        def lerp(p, q, t):
            return tuple(p[i] + (q[i] - p[i]) * t for i in range(3))
        out = []
        for i in range(nu):
            for j in range(nv):
                u0, u1, v0, v1 = i / nu, (i + 1) / nu, j / nv, (j + 1) / nv
                p00 = lerp(lerp(a, b, u0), lerp(d, c, u0), v0)
                p10 = lerp(lerp(a, b, u1), lerp(d, c, u1), v0)
                p11 = lerp(lerp(a, b, u1), lerp(d, c, u1), v1)
                p01 = lerp(lerp(a, b, u0), lerp(d, c, u0), v1)
                out.append([p00, p10, p11, p01])
        return out

    shapes = []
    for e in parts:
        base = e["color"]
        for quad0, n in faces(e):
          for quad in tiles(quad0):
              cq = [cam(p) for p in quad]
              # back-face cull: face normal toward camera (camera looks along -z in cam space)
              nc = cam(n)
              nc = (nc[0] - cam((0, 0, 0))[0], nc[1] - cam((0, 0, 0))[1], nc[2] - cam((0, 0, 0))[2])
              if nc[2] <= 0:
                  continue
              shade = 0.55 + 0.45 * max(0.0, sum(n[i] * light[i] for i in range(3)))
              col = tuple(min(255, int(c * shade)) for c in base)
              depth = sum(p[2] for p in cq) / len(cq)
              shapes.append((depth, [(p[0], p[1]) for p in cq], col))
    shapes.sort(key=lambda s: s[0])
    xs = [p[0] for s in shapes for p in s[1]]
    ys = [p[1] for s in shapes for p in s[1]]
    if not xs:
        sys.exit("nothing in box")
    pad = 20
    w = int((max(xs) - min(xs)) * args.scale) + pad * 2
    h = int((max(ys) - min(ys)) * args.scale) + pad * 2
    img = Image.new("RGB", (w, h), (34, 36, 40))
    draw = ImageDraw.Draw(img)
    for _, quad, col in shapes:
        pts = [(pad + (x - min(xs)) * args.scale, pad + (max(ys) - y) * args.scale) for x, y in quad]
        draw.polygon(pts, fill=col, outline=tuple(int(c * 0.7) for c in col))
    img.save(args.out)
    print(f"[preview_model] {args.out} {w}x{h}, {len(parts)} parts")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--box", nargs=4, type=float, required=True, metavar=("X0", "X1", "Z0", "Z1"))
    ap.add_argument("--yaw", type=float, default=35.0, help="camera turn about Y, degrees")
    ap.add_argument("--pitch", type=float, default=30.0, help="camera tilt down, degrees")
    ap.add_argument("--scale", type=float, default=6.0, help="pixels per stud")
    ap.add_argument("--ymax", type=float, default=80.0, help="ignore parts whose bottom is above this")
    args = ap.parse_args()
    render(collect(args.box, args.ymax), args.out, args.yaw, args.pitch, args.scale)


if __name__ == "__main__":
    main()
