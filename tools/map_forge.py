#!/usr/bin/env python3
"""Generate the Lemonade map as Rojo JSON models: Hearthmere hub + Iron Lowlands slice.

    python3 tools/map_forge.py            # writes lemonade-map/LemonadeMap/ + docs/map/*.png

Everything is classic Parts laid out on a dimensioned plan (docs/map/FIRST_SLICE.md).
+X is east, +Z is south, Y is up. The output is deterministic (seeded jitter only).

Folder contract consumed by gameplay (see docs/map/MARKERS.md):
  LemonadeMap/Grounds_<Region>   walkable floors and ramps; enemy ground raycasts hit only these
  LemonadeMap/Collision          invisible wall proxies; visual cliffs have collision disabled
  LemonadeMap/<Region>           visual geometry (buildings, cliffs, props)
  LemonadeMap/Markers            invisible gameplay markers (spawns, NPCs, safe zones, waypoints)
"""
from __future__ import annotations

import json
import math
import random
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "lemonade-map" / "LemonadeMap"
DOCS = ROOT / "docs" / "map"
MAP_VERSION = 1

# [TUNING] Floor heights. The place's Baseplate top sits at Y=0, so every walkable
# floor is a slab resting on it with its top above 0 (no coplanar faces).
HUB_Y = 10.0
QUARRY_Y = 2.0
PROXY_TOP = 110.0  # invisible wall proxies reach this high so nobody jumps out

# ── Palette (RGB 0-255) ───────────────────────────────────────────────────────
GRASS = (92, 142, 64)
GRASS_DARK = (80, 126, 56)
PATH = (124, 121, 115)
PATH_EDGE = (98, 96, 92)
HUB_ROCK = (124, 94, 68)
HUB_ROCK_DARK = (100, 75, 55)
TIMBER = (156, 100, 60)
BEAM = (72, 48, 32)
PLASTER = (216, 200, 164)
ROOF = (112, 54, 44)
STONE = (152, 148, 140)
STONE_DARK = (112, 108, 102)
QUARRY_FLOOR = (152, 110, 74)
QUARRY_PATH = (128, 95, 66)
QUARRY_CLIFF = (170, 122, 80)
QUARRY_CLIFF_DARK = (142, 100, 66)
ROCK_GRAY = (106, 103, 99)
LEAVES = [(70, 128, 52), (60, 112, 46), (86, 138, 58)]
TRUNK = (96, 64, 40)
WARLORD_RED = (130, 45, 55)
GOLD = (204, 168, 72)
IRON = (92, 94, 100)
FROST = (208, 226, 236)
CALDERA = (62, 46, 42)
EMBER = (232, 112, 42)
CELESTIAL = (232, 226, 212)
VOID = (72, 42, 104)
VOID_GLOW = (150, 90, 220)
LANTERN = (255, 196, 120)

IDENTITY = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]


# ── Rotation helpers (Roblox CFrame rows, R00..R22) ───────────────────────────
def rot_y(deg: float):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rot_x(deg: float):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def rot_z(deg: float):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def apply(m, v):
    return tuple(sum(m[i][k] * v[k] for k in range(3)) for i in range(3))


def yaw_facing(dx: float, dz: float) -> float:
    """Yaw (degrees) whose LookVector points along (dx, dz)."""
    # LookVector is -column2 of the rotation; for rot_y(t) that is (-sin t, 0, -cos t).
    return math.degrees(math.atan2(-dx, -dz))


# ── Instance tree ─────────────────────────────────────────────────────────────
REGISTRY: list[dict] = []  # every BasePart, for the top-down preview


def _r(x: float) -> float:
    return round(float(x), 4)


def inst(name: str, cls: str, props=None, attrs=None, children=None) -> dict:
    node = {"name": name, "className": cls}
    if props:
        node["properties"] = props
    if attrs:
        node["attributes"] = attrs
    if children:
        node["children"] = children
    return node


def model(name: str, children: list, attrs=None, cls: str = "Model") -> dict:
    return inst(name, cls, attrs=attrs, children=[c for c in children if c])


def part(name, size, pos, color, material="SmoothPlastic", rot=None, cls="Part", *,
         collide=True, query=True, touch=False, shadow=True, transparency=0.0, shape=None,
         attrs=None, children=None, extra=None, layer="prop") -> dict:
    rot = rot or IDENTITY
    props = {
        "Anchored": True,
        "Size": [_r(v) for v in size],
        "CFrame": {"CFrame": {"position": [_r(v) for v in pos],
                              "orientation": [[_r(v) for v in row] for row in rot]}},
        "Color": [_r(c / 255) for c in color],
        "Material": material,
        "TopSurface": "Smooth",
        "BottomSurface": "Smooth",
        "CanCollide": collide,
        "CanQuery": query,
        "CanTouch": touch,
        "CastShadow": shadow,
    }
    if transparency:
        props["Transparency"] = _r(transparency)
    if shape:
        props["Shape"] = shape
    if extra:
        props.update(extra)
    REGISTRY.append({"name": name, "size": size, "pos": pos, "rot": rot, "color": color,
                     "collide": collide, "transparency": transparency, "layer": layer, "cls": cls})
    return inst(name, cls, props, attrs, children)


def box(name, x0, x1, y0, y1, z0, z1, color, material="SmoothPlastic", **kw) -> dict:
    return part(name, (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
                color, material, **kw)


def light(range_=16, brightness=1.2, color=LANTERN, shadows=False) -> dict:
    return inst("Light", "PointLight", {"Range": range_, "Brightness": brightness,
                                         "Color": [_r(c / 255) for c in color], "Shadows": shadows})


def fire(size=4, heat=6) -> dict:
    return inst("Fire", "Fire", {"Size": size, "Heat": heat,
                                 "Color": [_r(c / 255) for c in (236, 140, 60)],
                                 "SecondaryColor": [_r(c / 255) for c in (140, 50, 20)]})


def label_gui(face: str, title: str, subtitle: str, text_color, px=40) -> dict:
    """Sign text. Labels are inset from the board edge and use Merriweather: the decorative
    Fantasy face overhangs its bounds under TextScaled, so its first/last letters got cut off."""
    rows = [inst("Title", "TextLabel", {
        "Text": title, "TextScaled": True, "Font": "Merriweather", "BackgroundTransparency": 1,
        "TextColor3": [_r(c / 255) for c in text_color], "TextStrokeTransparency": 0.7,
        "Size": {"UDim2": [[0.84, 0], [0.5 if subtitle else 0.76, 0]]},
        "Position": {"UDim2": [[0.08, 0], [0.08 if subtitle else 0.12, 0]]},
    }, children=[inst("MaxSize", "UITextSizeConstraint", {"MaxTextSize": 200, "MinTextSize": 6})])]
    if subtitle:
        rows.append(inst("Subtitle", "TextLabel", {
            "Text": subtitle, "TextScaled": True, "Font": "GothamMedium", "BackgroundTransparency": 1,
            "TextColor3": [_r(c / 255) for c in (236, 228, 210)],
            "Size": {"UDim2": [[0.84, 0], [0.26, 0]]}, "Position": {"UDim2": [[0.08, 0], [0.64, 0]]},
        }))
    return inst("Label" + face, "SurfaceGui", {
        "Face": face, "SizingMode": "PixelsPerStud", "PixelsPerStud": px, "LightInfluence": 0.4,
        "MaxDistance": 260, "ClipsDescendants": True,
    }, children=rows)


# ── Geometry kit ──────────────────────────────────────────────────────────────
def slab(name, x0, x1, z0, z1, top, color, material, bottom=0.0, **kw):
    return box(name, x0, x1, bottom, top, z0, z1, color, material, layer="ground", **kw)


def ramp(name, x0, x1, z0, z1, y_at_z0, y_at_z1, color, material, thickness=1.6):
    """A straight ramp along Z. Its top surface runs from y_at_z0 (at z0) to y_at_z1 (at z1)."""
    dz, dy = z1 - z0, y_at_z1 - y_at_z0
    length = math.hypot(dz, dy)
    angle = -math.degrees(math.atan2(dy, dz))  # rot_x(+a) lowers the +Z end
    r = rot_x(angle)
    up = apply(r, (0, 1, 0))
    mid = ((x0 + x1) / 2, (y_at_z0 + y_at_z1) / 2, (z0 + z1) / 2)
    centre = tuple(mid[i] - up[i] * thickness / 2 for i in range(3))
    return part(name, (x1 - x0, thickness, length + 0.4), centre, color, material, r, layer="ground")


USED_CLIFF_TOPS: set[int] = set()


def free_top(top: float) -> float:
    """Nudge a cliff top until no other cliff top sits within 0.1 studs of it."""
    while round(top * 10) in USED_CLIFF_TOPS:
        top += 0.25
    USED_CLIFF_TOPS.add(round(top * 10))
    return top


def cliff_run(name, a, b, inward, base_y, height, color, dark, rng, depth=14.0, chunk=(10, 18),
              material="Sandstone"):
    """Visual cliff chunks along segment a→b whose inner faces sit on the segment line.

    `inward` is +1 when the play area lies to the left of a→b (looking down from +Y), else -1.
    Returns (visual_children, proxy_part). Visual chunks never collide; the proxy does.
    """
    ax, az = a
    bx, bz = b
    seg = math.hypot(bx - ax, bz - az)
    dx, dz = (bx - ax) / seg, (bz - az) / seg
    # Left normal of (dx, dz) when viewed from above with +Z pointing down the page.
    nx, nz = dz * inward, -dx * inward
    yaw = math.degrees(math.atan2(-dz, dx))
    out = []
    s = 0.0
    i = 0
    last_h = -1.0
    while s < seg - 0.5:
        length = min(rng.uniform(*chunk), seg - s)
        h = height * rng.uniform(0.82, 1.18)
        if abs(h - last_h) < 0.6:  # equal neighbouring tops would z-fight where the chunks overlap
            h += 1.5
        h = free_top(base_y + h - 1) - base_y + 1
        last_h = h
        d = depth * rng.uniform(0.9, 1.3)
        cx = ax + dx * (s + length / 2) - nx * d / 2
        cz = az + dz * (s + length / 2) - nz * d / 2
        jitter = rng.uniform(-4, 4)
        col = color if i % 3 else dark
        out.append(part(f"{name}_{i:02d}", (length + 1.2, h, d), (cx, base_y + h / 2 - 1, cz), col,
                        material, rot_y(yaw + jitter), collide=False, layer="cliff"))
        if rng.random() < 0.45:  # stepped ledge breaks the silhouette
            lh = h * rng.uniform(0.25, 0.45)
            ld = rng.uniform(3, 5)
            lx = ax + dx * (s + length / 2) - nx * (d + ld / 2 - 0.5)
            lz = az + dz * (s + length / 2) - nz * (d + ld / 2 - 0.5)
            cap_top = free_top(base_y + h + 1.45)
            out.append(part(f"{name}_{i:02d}_cap", (length * 0.8, 2.5, ld), (lx, cap_top - 1.25, lz),
                            dark, material, rot_y(yaw + jitter * 0.5), collide=False, layer="cliff"))
        s += length
        i += 1
    proxy = part(f"{name}_Proxy", (seg, PROXY_TOP - base_y + 2, 6),
                 ((ax + bx) / 2 - nx * 3, (base_y - 2 + PROXY_TOP) / 2, (az + bz) / 2 - nz * 3),
                 (255, 0, 255), "SmoothPlastic", rot_y(yaw), transparency=1, query=False,
                 shadow=False, layer="proxy")
    return out, proxy


def tree(name, x, y, z, rng, scale=1.0):
    s = scale * rng.uniform(0.85, 1.15)
    trunk_h = 11 * s
    leaves = rng.choice(LEAVES)
    kids = [part("Trunk", (2.2 * s, trunk_h, 2.2 * s), (x, y + trunk_h / 2, z), TRUNK, "Wood",
                 rot_y(rng.uniform(0, 90)), layer="tree")]
    yaw = rng.uniform(0, 90)
    kids.append(part("Canopy", (11 * s, 8 * s, 11 * s), (x, y + trunk_h + 2 * s, z), leaves, "Grass",
                     rot_y(yaw), collide=False, layer="canopy"))
    kids.append(part("CanopyTop", (7.5 * s, 5 * s, 7.5 * s), (x, y + trunk_h + 7.5 * s, z),
                     rng.choice(LEAVES), "Grass", rot_y(yaw + 45), collide=False, layer="canopy"))
    return model(name, kids)


def rock_cluster(name, x, y, z, rng, color=ROCK_GRAY, size=1.0, collide=True):
    kids = []
    for i in range(rng.randint(2, 4)):
        w, h, d = (rng.uniform(4, 9) * size, rng.uniform(2.5, 6) * size, rng.uniform(4, 8) * size)
        ox, oz = rng.uniform(-4, 4) * size, rng.uniform(-4, 4) * size
        r = mul(rot_y(rng.uniform(0, 90)), rot_z(rng.uniform(-10, 10)))
        kids.append(part(f"Rock{i}", (w, h, d), (x + ox, y + h / 2 - 0.6, z + oz), color, "Slate", r,
                         collide=collide and i == 0, layer="rock"))
    return model(name, kids)


def lamp_post(name, x, y, z, yaw=0.0):
    fwd = apply(rot_y(yaw), (0, 0, -1))
    arm = (x + fwd[0] * 1.6, y + 9.2, z + fwd[2] * 1.6)
    return model(name, [
        part("Post", (0.8, 10, 0.8), (x, y + 5, z), BEAM, "Wood"),
        part("Arm", (0.5, 0.5, 3), (x + fwd[0] * 1.2, y + 9.7, z + fwd[2] * 1.2), BEAM, "Wood",
             rot_y(yaw), collide=False),
        part("Lantern", (1.3, 1.6, 1.3), (arm[0], y + 8.6, arm[2]), LANTERN, "Neon", rot_y(yaw),
             collide=False, query=False, shadow=False, transparency=0.15, children=[light(20, 1.1)]),
    ])


def sign(name, x, y, z, yaw, width, height, title, subtitle="", board=TIMBER, text=(255, 238, 200),
         post_h=None):
    """Signboard between two posts. Posts sit outside the board's width so they can't cover text."""
    post_h = post_h if post_h is not None else height + 3
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))
    board_y = y + post_h - height / 2 - 0.3
    kids = []
    if post_h > height:
        for side in (-1, 1):
            offset = side * (width / 2 + 0.45)
            kids.append(part(f"Post{side}", (0.8, post_h, 0.8), (x + right[0] * offset, y + post_h / 2, z + right[2] * offset),
                             BEAM, "Wood", r))
    kids.append(part("Board", (width, height, 0.5), (x, board_y, z), board, "WoodPlanks", r,
                     collide=False, children=[label_gui("Front", title, subtitle, text),
                                              label_gui("Back", title, subtitle, text)]))
    return model(name, kids)


def fence_run(name, a, b, y, height=3.2, gap=None, collide=True, skip_first_post=False):
    """Timber fence with posts every ~8 studs. `gap` = (s0, s1) distances along the run left open."""
    ax, az = a
    bx, bz = b
    seg = math.hypot(bx - ax, bz - az)
    dx, dz = (bx - ax) / seg, (bz - az) / seg
    yaw = math.degrees(math.atan2(-dz, dx))
    kids = []
    spans = [(0.0, seg)] if not gap else [(0.0, gap[0]), (gap[1], seg)]
    for si, (s0, s1) in enumerate(spans):
        if s1 - s0 < 1:
            continue
        n = max(1, round((s1 - s0) / 8))
        for k in range(n + 1):
            if skip_first_post and si == 0 and k == 0:
                continue
            s = s0 + (s1 - s0) * k / n
            kids.append(part(f"Post{si}_{k}", (0.9, height + 0.6, 0.9),
                             (ax + dx * s, y + (height + 0.6) / 2, az + dz * s), BEAM, "Wood", rot_y(yaw),
                             collide=collide))
        mid = (s0 + s1) / 2
        for ri, rh in enumerate((height * 0.45, height * 0.9)):
            kids.append(part(f"Rail{si}_{ri}", (s1 - s0, 0.45, 0.35),
                             (ax + dx * mid, y + rh, az + dz * mid), TIMBER, "WoodPlanks", rot_y(yaw),
                             collide=collide))
    return model(name, kids)


def timber_house(name, x0, x1, z0, z1, y, wall_h, front, rng, door_w=6.0, open_front=False,
                 wall_color=PLASTER, roof_color=ROOF):
    """Timber-framed building. `front` ∈ {'N','S','E','W'} gets the door (or is fully open)."""
    kids = [box("Foundation", x0 - 1, x1 + 1, y - 0.6, y + 0.8, z0 - 1, z1 + 1, STONE_DARK, "Cobblestone")]
    t = 1.0
    walls = {
        "N": (x0, x1, z0, z0 + t), "S": (x0, x1, z1 - t, z1),
        "W": (x0, x0 + t, z0 + t, z1 - t), "E": (x1 - t, x1, z0 + t, z1 - t),
    }
    top = y + 0.8 + wall_h
    for side, (a0, a1, b0, b1) in walls.items():
        horizontal = side in "NS"
        if side == front:
            if open_front:
                continue
            if horizontal:
                mid = (a0 + a1) / 2
                kids.append(box(f"Wall{side}L", a0, mid - door_w / 2, y + 0.8, top, b0, b1, wall_color, "Plaster"))
                kids.append(box(f"Wall{side}R", mid + door_w / 2, a1, y + 0.8, top, b0, b1, wall_color, "Plaster"))
            else:
                mid = (b0 + b1) / 2
                kids.append(box(f"Wall{side}L", a0, a1, y + 0.8, top, b0, mid - door_w / 2, wall_color, "Plaster"))
                kids.append(box(f"Wall{side}R", a0, a1, y + 0.8, top, mid + door_w / 2, b1, wall_color, "Plaster"))
            continue
        kids.append(box(f"Wall{side}", a0, a1, y + 0.8, top, b0, b1, wall_color, "Plaster"))
    # Timber frame: corner posts, sill and top beams, a diagonal brace per long wall.
    for cx in (x0, x1):
        for cz in (z0, z1):
            kids.append(box("CornerPost", cx - 0.7, cx + 0.7, y + 0.8, top - 0.2, cz - 0.7, cz + 0.7, BEAM, "Wood"))
    for side, (a0, a1, b0, b1) in walls.items():
        if side == front and open_front:
            continue
        pad = 0.25
        if side in "NS":
            bz = b0 - pad if side == "N" else b1 + pad
            kids.append(box(f"TopBeam{side}", a0, a1, top - 0.9, top, bz - 0.3, bz + 0.3, BEAM, "Wood", collide=False))
            kids.append(box(f"MidBeam{side}", a0, a1, y + 0.8 + wall_h * 0.45, y + 0.8 + wall_h * 0.45 + 0.7,
                            bz - 0.3, bz + 0.3, BEAM, "Wood", collide=False))
        else:
            bx = a0 - pad if side == "W" else a1 + pad
            kids.append(box(f"TopBeam{side}", bx - 0.3, bx + 0.3, top - 0.9, top, b0, b1, BEAM, "Wood", collide=False))
            kids.append(box(f"MidBeam{side}", bx - 0.3, bx + 0.3, y + 0.8 + wall_h * 0.45,
                            y + 0.8 + wall_h * 0.45 + 0.7, b0, b1, BEAM, "Wood", collide=False))
    # Gable roof, ridge along the longer axis, built from two tilted slabs + stepped gable fill.
    span_x, span_z = x1 - x0, z1 - z0
    pitch = 34.0
    overhang = 2.0
    if span_x >= span_z:
        half = span_z / 2 + overhang
        rise = math.tan(math.radians(pitch)) * (span_z / 2)
        slope_len = half / math.cos(math.radians(pitch))
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        for sgn in (-1, 1):
            r = rot_x(pitch * sgn)  # +pitch lowers +Z: the south slab drops toward +Z
            kids.append(part(f"Roof{'N' if sgn < 0 else 'S'}", (span_x + overhang * 2, 0.9, slope_len),
                             (cx, top + math.tan(math.radians(pitch)) * (span_z / 4 - overhang / 2), cz + sgn * half / 2), roof_color, "RoofShingles", r,
                             collide=False, layer="roof"))
        # WedgePart: bottom face flat, vertical face at local +Z, slope descending toward -Z.
        for gx in (x0 + 0.5, x1 - 0.5):
            for sgn, yaw in ((-1, 0), (1, 180)):  # north half rises toward +Z, south half toward -Z
                kids.append(part(f"Gable{'N' if sgn < 0 else 'S'}", (1, rise, span_z / 2),
                                 (gx, top + rise / 2, cz + sgn * span_z / 4), wall_color, "Plaster", rot_y(yaw),
                                 cls="WedgePart", collide=False, layer="roof"))
    else:
        half = span_x / 2 + overhang
        rise = math.tan(math.radians(pitch)) * (span_x / 2)
        slope_len = half / math.cos(math.radians(pitch))
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        for sgn in (-1, 1):
            r = rot_z(-pitch * sgn)  # rot_z(+a) raises +X; the east slab drops toward +X
            kids.append(part(f"Roof{'W' if sgn < 0 else 'E'}", (slope_len, 0.9, span_z + overhang * 2),
                             (cx + sgn * half / 2, top + math.tan(math.radians(pitch)) * (span_x / 4 - overhang / 2), cz), roof_color, "RoofShingles", r,
                             collide=False, layer="roof"))
        for gz in (z0 + 0.5, z1 - 0.5):
            for sgn, yaw in ((-1, 90), (1, -90)):  # west half rises toward +X, east half toward -X
                kids.append(part(f"Gable{'W' if sgn < 0 else 'E'}", (1, rise, span_x / 2),
                                 (cx + sgn * span_x / 4, top + rise / 2, gz), wall_color, "Plaster", rot_y(yaw),
                                 cls="WedgePart", collide=False, layer="roof"))
    return model(name, kids)


def gate(name, cx, y, cz, yaw, width, height, title, subtitle, sealed, stone=STONE, accent=WARLORD_RED,
         region="", required_level=0, back_title="Hearthmere", back_subtitle=""):
    """Two pillars, a lintel with sign, banners. Local X spans the opening; travel is along local Z."""
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))
    fwd = apply(r, (0, 0, -1))

    def at(lx, lz):
        return cx + right[0] * lx + fwd[0] * -lz, cz + right[2] * lx + fwd[2] * -lz

    kids = []
    pw = 7.0
    for side in (-1, 1):
        px, pz = at(side * (width / 2 + pw / 2), 0)
        kids.append(part(f"Pillar{side}", (pw, height, pw + 1), (px, y + height / 2, pz), stone, "Cobblestone", r))
        kids.append(part(f"PillarCap{side}", (pw + 1.5, 1.6, pw + 2.5), (px, y + height + 0.8, pz), STONE_DARK,
                         "Cobblestone", r))
        tx, tz = at(side * (width / 2 + pw / 2), -(pw + 1) / 2 - 0.4)
        kids.append(part(f"Torch{side}", (0.9, 1.4, 0.9), (tx, y + height * 0.62, tz), LANTERN, "Neon", r,
                         collide=False, query=False, shadow=False, children=[light(18, 1.0)]))
    kids.append(part("Lintel", (width + pw * 2 + 2, 4, pw + 1.4), (cx, y + height + 2.6, cz), BEAM, "Wood", r))
    sign_depth = (pw + 2.5) / 2 + 0.4  # clear of the pillar caps, which are the deepest part
    sx, sz = at(0, -sign_depth)
    kids.append(part("Sign", (width + 4, 5.2, 0.5), (sx, y + height + 2.8, sz), (58, 38, 26), "WoodPlanks", r,
                     collide=False, children=[label_gui("Front", title, subtitle, (255, 226, 160), px=30)]))
    bx2, bz2 = at(0, sign_depth)
    kids.append(part("SignBack", (width + 4, 5.2, 0.5), (bx2, y + height + 2.8, bz2), (58, 38, 26), "WoodPlanks",
                     r, collide=False, children=[label_gui("Back", back_title, back_subtitle, (255, 226, 160), px=30)]))
    for side in (-1, 1):
        bx, bz = at(side * (width / 2 + pw / 2), -(pw + 1) / 2 - 0.3)
        kids.append(part(f"Banner{side}", (4.2, 9, 0.3), (bx, y + height - 5.5, bz), accent, "Fabric", r,
                         collide=False))
    if sealed:
        bars = max(4, int(width // 3))
        for k in range(bars):
            lx = -width / 2 + width * (k + 0.5) / bars
            px, pz = at(lx, 0)
            kids.append(part(f"Bar{k}", (0.7, height, 0.7), (px, y + height / 2, pz), IRON, "Metal", r,
                             collide=False))
        for hk, hy in enumerate((height * 0.3, height * 0.7)):
            kids.append(part(f"Crossbar{hk}", (width, 0.7, 0.8), (cx, y + hy, cz), IRON, "Metal", r, collide=False))
        kids.append(part("SealProxy", (width + 0.5, height, 2), (cx, y + height / 2, cz), (255, 0, 255),
                         transparency=1, query=False, shadow=False, rot=r, layer="proxy"))
    return model(name, kids, attrs={"Region": region, "Sealed": sealed, "RequiredLevel": required_level})


FABRIC_GREEN = (78, 112, 72)
FABRIC_CREAM = (222, 206, 166)


def quest_stall(name, npc_x, y, cz):
    """Timber market stall with a peaked striped canopy; counter on the -X (road) side.

    The Quest Master marker stands at (npc_x, y, cz) behind the counter, facing -X.
    Footprint x npc_x-5 .. npc_x+5, z cz-7 .. cz+7. Ridge runs along Z.
    """
    x0, x1 = npc_x - 4.5, npc_x + 4.5        # post lines (front, back)
    z0, z1 = cz - 6.5, cz + 6.5
    eave, ridge = y + 8.4, y + 11.6
    kids = []
    # Corner posts up to the eaves, king posts at each end up to the ridge.
    for px_ in (x0, x1):
        for pz in (z0, z1):
            kids.append(part("Post", (0.9, eave - y, 0.9), (px_, y + (eave - y) / 2, pz), BEAM, "Wood"))
    for pz in (z0, z1):
        kids.append(part("KingPost", (0.8, ridge - y, 0.8), (npc_x, y + (ridge - y) / 2, pz), BEAM, "Wood"))
    # Frame: eave plates along Z, tie beams along X, ridge beam, rafters on each gable.
    for px_ in (x0, x1):
        kids.append(part("EavePlate", (0.7, 0.7, z1 - z0 + 1.2), (px_, eave - 0.35, cz), BEAM, "Wood", collide=False))
    for pz in (z0, z1):
        kids.append(part("TieBeam", (x1 - x0 + 1.2, 0.6, 0.7), (npc_x, eave - 1.2, pz), BEAM, "Wood", collide=False))
    kids.append(part("RidgeBeam", (0.8, 0.8, z1 - z0 + 1.6), (npc_x, ridge + 0.1, cz), BEAM, "Wood", collide=False))
    run = npc_x - x0
    pitch = math.degrees(math.atan2(ridge - eave, run))
    rafter = math.hypot(run, ridge - eave) + 0.6
    for pz in (z0, z1):
        for sgn in (-1, 1):  # front rafter rises toward +X (rot_z +), back rafter toward -X
            kids.append(part("Rafter", (rafter, 0.55, 0.55), (npc_x + sgn * run / 2, (eave + ridge) / 2, pz), BEAM,
                             "Wood", rot_z(-sgn * pitch), collide=False))
    # Striped canopy: strips run down each slope, alternating green and cream, with an overhang.
    overhang = 1.4
    slope_run = run + overhang
    slope_len = slope_run / math.cos(math.radians(pitch))
    strips = 8
    strip_w = (z1 - z0 + 2.4) / strips
    for sgn in (-1, 1):
        mid_x = npc_x + sgn * slope_run / 2
        mid_y = ridge + 0.45 - math.tan(math.radians(pitch)) * slope_run / 2
        for k in range(strips):
            zk = z0 - 1.2 + strip_w * (k + 0.5)
            color = FABRIC_GREEN if k % 2 == 0 else FABRIC_CREAM
            kids.append(part(f"Canopy{'F' if sgn < 0 else 'B'}{k}", (slope_len, 0.22, strip_w),
                             (mid_x, mid_y, zk), color, "Fabric", rot_z(-sgn * pitch),
                             collide=False, layer="roof"))
        # Valance: short hanging flaps along the low edge.
        edge_x = npc_x + sgn * (slope_run - 0.05)
        edge_y = ridge + 0.45 - math.tan(math.radians(pitch)) * slope_run
        for k in range(strips):
            zk = z0 - 1.2 + strip_w * (k + 0.5)
            color = FABRIC_CREAM if k % 2 == 0 else FABRIC_GREEN
            kids.append(part(f"Valance{'F' if sgn < 0 else 'B'}{k}", (0.15, 0.9, strip_w - 0.1),
                             (edge_x, edge_y - 0.45, zk), color, "Fabric", collide=False, layer="roof"))
    # Counter on the road side: plank top, slatted front, lower shelf, legs.
    cx0, cx1 = x0 - 0.4, x0 + 2.4
    top_y = y + 3.4
    kids.append(box("CounterTop", cx0 - 0.3, cx1 + 0.2, top_y - 0.35, top_y, z0 + 0.6, z1 - 0.6, TIMBER, "WoodPlanks"))
    kids.append(box("CounterShelf", cx0 + 0.3, cx1 - 0.2, y + 1.0, y + 1.3, z0 + 0.9, z1 - 0.9, TIMBER, "WoodPlanks",
                    collide=False))
    slats = 9
    for k in range(slats):
        zk = z0 + 1.1 + (z1 - z0 - 2.2) * (k + 0.5) / slats
        kids.append(box(f"Slat{k}", cx0 - 0.15, cx0 + 0.15, y, top_y - 0.35, zk - 0.55, zk + 0.55,
                        (120, 78, 46) if k % 2 else (104, 68, 40), "Wood"))
    for lz in (z0 + 0.8, z1 - 0.8):
        kids.append(box("CounterLeg", cx1 - 0.5, cx1, y, top_y - 0.35, lz - 0.25, lz + 0.25, BEAM, "Wood",
                        collide=False))
    # Goods: rolled quest scrolls, a stack of notices, an ink pot and a small crate.
    for k, (dz, length) in enumerate(((-3.8, 1.6), (-2.6, 1.3), (-3.2, 1.4))):
        kids.append(part(f"Scroll{k}", (length, 0.45, 0.45), (x0 + 0.9 + 0.1 * k, top_y + 0.23 + (0.4 if k == 2 else 0),
                                                            cz + dz), FABRIC_CREAM, "Fabric",
                         rot_y(15 * k), shape="Cylinder", collide=False))
    kids.append(part("Notices", (1.4, 0.3, 1.9), (x0 + 1.0, top_y + 0.15, cz + 2.8), (236, 224, 196), "SmoothPlastic",
                     rot_y(-8), collide=False))
    kids.append(part("InkPot", (0.45, 0.5, 0.45), (x0 + 1.2, top_y + 0.25, cz + 4.4), (36, 32, 40), "Glass",
                     collide=False))
    kids.append(part("Crate", (2.2, 2.2, 2.2), (x1 - 0.9, y + 1.1, z1 - 1.6), TIMBER, "WoodPlanks", rot_y(10)))
    kids.append(part("CrateSmall", (1.5, 1.5, 1.5), (x1 - 1.0, y + 2.95, z1 - 1.8), (140, 92, 54), "WoodPlanks",
                     rot_y(-14), collide=False))
    # Hanging sign under the front eave.
    sign_y = eave - 2.1
    for dz in (-1.8, 1.8):
        kids.append(part("SignChain", (0.12, 1.0, 0.12), (x0 - 0.2, eave - 1.0, cz + dz), IRON, "Metal", collide=False))
    kids.append(part("SignBoard", (4.6, 1.8, 0.35), (x0 - 0.2, sign_y, cz), (70, 46, 30), "WoodPlanks",
                     rot_y(yaw_facing(-1, 0)), collide=False,
                     children=[label_gui("Front", "Quests", "", (255, 232, 170), px=60),
                               label_gui("Back", "Quests", "", (255, 232, 170), px=60)]))
    return model(name, kids)


def campfire(name, x, y, z, rng):
    kids = []
    for k in range(7):
        a = k / 7 * math.tau
        kids.append(part(f"Stone{k}", (1.4, 0.9, 1.2), (x + math.cos(a) * 2.4, y + 0.45, z + math.sin(a) * 2.4),
                         STONE_DARK, "Slate", rot_y(math.degrees(-a)), collide=False))
    for k in range(3):
        kids.append(part(f"Log{k}", (0.8, 0.8, 4.2), (x, y + 0.6, z), TRUNK, "Wood",
                         mul(rot_y(k * 60), rot_x(18)), collide=False))
    kids.append(part("Embers", (1.2, 0.4, 1.2), (x, y + 0.5, z), EMBER, "Neon", collide=False, query=False,
                     shadow=False, children=[fire(4, 7), light(22, 1.6, (255, 160, 90))]))
    return model(name, kids)


def scaffold(name, x, y, z, yaw, length, height=16):
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))
    kids = []
    n = max(2, round(length / 8))
    for k in range(n + 1):
        s = -length / 2 + length * k / n
        for depth in (0.0, 4.0):
            fwd = apply(r, (0, 0, 1))
            px = x + right[0] * s + fwd[0] * depth
            pz = z + right[2] * s + fwd[2] * depth
            kids.append(part(f"Post{k}_{int(depth)}", (0.8, height, 0.8), (px, y + height / 2, pz), BEAM, "Wood", r,
                             collide=False))
    for lvl in (height * 0.5, height):
        fwd = apply(r, (0, 0, 1))
        kids.append(part(f"Deck{int(lvl)}", (length + 1, 0.5, 5), (x + fwd[0] * 2, y + lvl, z + fwd[2] * 2), TIMBER,
                         "WoodPlanks", r, collide=False))
    kids.append(part("Brace", (0.5, 0.5, math.hypot(length, height) * 0.95), (x, y + height / 2, z),
                     BEAM, "Wood", mul(r, mul(rot_y(90), rot_x(-math.degrees(math.atan2(height, length))))),
                     collide=False))
    return model(name, kids)


def mine_cart(name, x, y, z, yaw):
    r = rot_y(yaw)
    kids = [part("Body", (4.5, 2.6, 6.5), (x, y + 2.3, z), (88, 70, 54), "WoodPlanks", r),
            part("Load", (3.8, 1.2, 5.6), (x, y + 3.7, z), ROCK_GRAY, "Slate", r, collide=False)]
    right = apply(r, (1, 0, 0))
    fwd = apply(r, (0, 0, 1))
    for sx in (-1, 1):
        for sz in (-1, 1):
            wx = x + right[0] * sx * 2.4 + fwd[0] * sz * 2.2
            wz = z + right[2] * sx * 2.4 + fwd[2] * sz * 2.2
            kids.append(part(f"Wheel{sx}{sz}", (0.6, 1.8, 1.8), (wx, y + 0.9, wz), IRON, "Metal", r, shape="Cylinder",
                             collide=False))
    return model(name, kids)


def rail_track(name, x, y, z0, z1):
    kids = []
    for sx in (-1.6, 1.6):
        kids.append(box(f"Rail{sx}", x + sx - 0.2, x + sx + 0.2, y, y + 0.35, z0, z1, IRON, "Metal", collide=False))
    k = 0
    zz = z0 + 1
    while zz < z1:
        kids.append(box(f"Sleeper{k}", x - 2.6, x + 2.6, y - 0.05, y + 0.2, zz - 0.5, zz + 0.5, TRUNK, "Wood",
                        collide=False))
        zz += 3
        k += 1
    return model(name, kids)


def stone_stack(name, x, y, z, rng, color=(186, 160, 120)):
    kids = []
    layers = rng.randint(1, 3)
    for lv in range(layers):
        for k in range(max(1, 3 - lv)):
            w = rng.uniform(4.5, 6)
            kids.append(part(f"Block{lv}_{k}", (w, 3.2, w * 0.8),
                             (x + (k - (2 - lv) / 2) * 6.3, y + 1.6 + lv * 3.2, z + rng.uniform(-0.6, 0.6)),
                             color, "Limestone", rot_y(rng.uniform(-6, 6)), collide=(lv == 0)))
    return model(name, kids)


def tent(name, x, y, z, yaw, color=(150, 120, 90)):
    r = rot_y(yaw)
    kids = []
    for sgn in (-1, 1):
        off = apply(r, (sgn * 2.05, 0, 0))
        kids.append(part(f"Cloth{sgn}", (7.5, 0.3, 6.2), (x + off[0], y + 2.3, z + off[2]), color, "Fabric",
                         mul(r, rot_z(-sgn * 48)), collide=False))
    kids.append(part("Ridge", (0.5, 0.5, 8), (x, y + 4.6, z), BEAM, "Wood", mul(r, rot_y(90)), collide=False))
    return model(name, kids)


def banner_pole(name, x, y, z, yaw, color=WARLORD_RED):
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))
    return model(name, [
        part("Pole", (0.7, 14, 0.7), (x, y + 7, z), BEAM, "Wood"),
        part("Cloth", (3.6, 7, 0.25), (x + right[0] * 2.1, y + 9.5, z + right[2] * 2.1), color, "Fabric", r,
             collide=False),
        part("Finial", (1, 1, 1), (x, y + 14.5, z), GOLD, "Metal", collide=False, shape="Ball"),
    ])


def brazier(name, x, y, z):
    return model(name, [
        part("Base", (2.6, 3.2, 2.6), (x, y + 1.6, z), STONE_DARK, "Cobblestone"),
        part("Bowl", (3.6, 1.2, 3.6), (x, y + 3.8, z), IRON, "Metal", collide=False),
        part("Coals", (2.6, 0.5, 2.6), (x, y + 4.4, z), EMBER, "Neon", collide=False, query=False, shadow=False,
             children=[fire(5, 8), light(26, 1.4, (255, 150, 80))]),
    ])


def waystone(name, waypoint_id, x, y, z, glow=(120, 200, 230)):
    return model(name, [
        part("Plinth", (5, 1.2, 5), (x, y + 0.6, z), STONE_DARK, "Cobblestone"),
        part("Obelisk", (2.6, 8, 2.6), (x, y + 5.2, z), STONE, "Granite", rot_y(45)),
        part("Rune", (0.2, 3.2, 1.2), (x + 1.35, y + 5.6, z + 1.35), glow, "Neon", rot_y(45), collide=False,
             query=False, shadow=False, transparency=0.2),
        part("RuneBack", (0.2, 3.2, 1.2), (x - 1.35, y + 5.6, z - 1.35), glow, "Neon", rot_y(45), collide=False,
             query=False, shadow=False, transparency=0.2, children=[light(14, 0.8, glow)]),
    ], attrs={"Waystone": True, "WaypointId": waypoint_id})


def disc(name, x, z, radius, top, thickness, color, material, collide=True, layer="ground"):
    """Flat round slab: a Cylinder part with its axis turned vertical. Replaces the old
    four-band octagon, whose overlapping coplanar tops z-fought as the camera moved."""
    return [part(name, (thickness, radius * 2, radius * 2), (x, top - thickness / 2, z), color, material,
                 rot_z(90), shape="Cylinder", collide=collide, layer=layer)]


# ── Markers ───────────────────────────────────────────────────────────────────
def marker(name, pos, yaw=0.0, size=(2, 2, 2), attrs=None, cls="Part"):
    return part(name, size, pos, (255, 220, 0), "SmoothPlastic", rot_y(yaw), cls=cls, collide=False, query=False,
                touch=False, shadow=False, transparency=1, attrs=attrs, layer="marker")


def volume(name, x0, x1, y0, y1, z0, z1, attrs=None):
    return box(name, x0, x1, y0, y1, z0, z1, (0, 255, 120), collide=False, query=False, touch=False,
               shadow=False, transparency=1, attrs=attrs, layer="volume")


ENEMY_SPAWNS = [
    # id, archetype, level, role, (x, z), leash — [TUNING] first-slice placement, see FIRST_SLICE.md
    ("IL_S1", "IronSquire", 1, "minion", (-35, 212), 20),
    ("IL_S2", "IronSquire", 1, "minion", (30, 206), 20),
    ("IL_S3", "IronSquire", 2, "minion", (-2, 236), 20),
    ("IL_S4", "IronSquire", 2, "minion", (-48, 252), 20),
    ("IL_S5", "IronSquire", 3, "minion", (44, 250), 20),
    ("IL_S6", "IronSquire", 3, "minion", (-22, 288), 20),
    ("IL_B1", "IronBerserker", 3, "minion", (30, 296), 22),
    ("IL_S7", "IronSquire", 4, "minion", (-60, 318), 20),
    ("IL_B2", "IronBerserker", 4, "minion", (12, 318), 22),
    ("IL_B3", "IronBerserker", 5, "minion", (52, 338), 22),
    ("IL_S8", "IronSquire", 4, "minion", (-40, 345), 20),
    ("IL_E1", "IronBerserker", 6, "elite", (-142, 315), 18),
    ("IL_BOSS", "Boss_Gorgon", 10, "boss", (0, 432), 50),
]

WAYPOINTS = [
    # id, display, region, (x, y, z) arrival, facing yaw, order — waystone models carry WaypointId
    ("HubSpawn", "Hearthmere", "Hub", (0, HUB_Y, -40), 180.0, 1),
    ("IronOverlook", "Quarry Overlook", "IronLowlands", (18, HUB_Y, 152), 180.0, 2),
    ("WarlordGate", "Warlord's Gate", "IronLowlands", (0, QUARRY_Y, 352), 180.0, 3),
]


def build_markers():
    npcs = model("NPCs", [
        marker("QuestMaster", (15, HUB_Y + 0.2, 50), yaw_facing(-1, 0)),
        marker("Merchant", (-62, HUB_Y, -16.5), yaw_facing(0, 1)),
        marker("SkillTrainer", (58, HUB_Y, -12), yaw_facing(0, 1)),
        marker("RebirthKeeper", (64, HUB_Y, 22), yaw_facing(0, -1)),
    ], cls="Folder")
    safe = model("SafeZones", [
        volume("Hub", -100, 100, 0, 90, -100, 100, attrs={"Region": "Hub"}),
        volume("IronOverlook", -40, 40, 0, 90, 100, 168, attrs={"Region": "IronLowlands"}),
    ], cls="Folder")
    regions = model("Regions", [
        volume("Hub", -100, 100, 0, 120, -100, 100,
               attrs={"DisplayName": "Hearthmere", "Subtitle": "Safe haven", "Order": 0}),
        volume("IronLowlands", -170, 112, 0, 120, 100, 472,
               attrs={"DisplayName": "Iron Lowlands", "Subtitle": "Recommended Lv 1 - 10", "Order": 1}),
    ], cls="Folder")
    spawns = []
    for sid, arch, level, role, (x, z), leash in ENEMY_SPAWNS:
        spawns.append(marker(sid, (x, QUARRY_Y, z), 0, attrs={
            "Archetype": arch, "Level": level, "Role": role, "Zone": "IronLowlands",
            "Region": "IronLowlands", "LeashRadius": leash}))
    enemy = model("EnemySpawns", spawns, cls="Folder")
    wps = []
    for wid, display, region, pos, yaw, order in WAYPOINTS:
        wps.append(marker(wid, pos, yaw, attrs={"DisplayName": display, "Region": region, "Order": order,
                                                "DiscoverRadius": 18}))
    waypoints = model("Waypoints", wps, cls="Folder")
    spawn_location = inst("PlayerSpawn", "SpawnLocation", {
        "Anchored": True, "Size": [8, 1, 8],
        "CFrame": {"CFrame": {"position": [0, HUB_Y + 0.5, -40],
                              "orientation": [[_r(v) for v in row] for row in rot_y(180)]}},
        "Transparency": 1, "CanCollide": False, "CanQuery": False, "CanTouch": False, "Neutral": True,
        "Duration": 0, "Enabled": True, "CastShadow": False,
    })
    gates = model("Gates", [
        marker("IronLowlands", (0, HUB_Y, 100), 0, attrs={"DisplayName": "Iron Lowlands", "Region": "IronLowlands", "Sealed": False, "RequiredLevel": 1}),
        marker("FrostboundGlacier", (-100, HUB_Y, 0), 0, attrs={"DisplayName": "Frostbound Glacier", "Region": "FrostboundGlacier", "Sealed": True, "RequiredLevel": 18}),
        marker("InfernalCaldera", (100, HUB_Y, 0), 0, attrs={"DisplayName": "Infernal Caldera", "Region": "InfernalCaldera", "Sealed": True, "RequiredLevel": 34}),
        marker("CelestialSummit", (0, HUB_Y, -100), 0, attrs={"DisplayName": "Celestial Summit", "Region": "CelestialSummit", "Sealed": True, "RequiredLevel": 80}),
        marker("VoidRift", (68, HUB_Y, -72), 0, attrs={"DisplayName": "Void Rift", "Region": "VoidRift", "Sealed": True, "RequiredLevel": 55}),
        marker("Briarwood", (0, QUARRY_Y, 470), 0, attrs={"DisplayName": "Briarwood", "Region": "Briarwood", "Sealed": True, "RequiredLevel": 9}),
    ], cls="Folder")
    # A Persistent model is sent to every client on join and never streamed out, so client UI
    # (region banner, travel menu, quest guide) can read markers anywhere on the map.
    markers = model("Markers", [npcs, safe, regions, enemy, waypoints, gates, spawn_location],
                    attrs={"SchemaVersion": 1})
    markers["properties"] = {"ModelStreamingMode": "Persistent"}
    return markers


# ── Hub: Hearthmere ───────────────────────────────────────────────────────────
def build_hub(rng):
    ground = [slab("HubFloor", -104, 104, -104, 104, HUB_Y, GRASS, "Grass")]
    road = HUB_Y + 0.2
    ground += disc("Plaza", 0, 0, 27, road + 0.1, 0.7, PATH, "Cobblestone")
    ground += [
        box("RoadSouth", -8, 8, road - 0.6, road, 25, 104, PATH, "Cobblestone", layer="ground"),
        box("RoadNorth", -8, 8, road - 0.6, road, -104, -25, PATH, "Cobblestone", layer="ground"),
        box("RoadWest", -104, -25, road - 0.6, road, -8, 8, PATH, "Cobblestone", layer="ground"),
        box("RoadEast", 25, 104, road - 0.6, road, -8, 8, PATH, "Cobblestone", layer="ground"),
        box("ShopYard", -84, -40, road - 0.6, road, -18, -8, PATH_EDGE, "Cobblestone", layer="ground"),
        box("TrainingYard", 42, 86, road - 0.6, road, -48, -8, (150, 120, 86), "Ground", layer="ground"),
        box("QuestCourt", 8, 26, road - 0.6, road, 40, 62, PATH_EDGE, "Cobblestone", layer="ground"),
    ]
    visual = []
    proxies = []

    # Perimeter cliffs with 24-stud gate openings at each side's midpoint.
    wall_h = 32
    segments = [
        ((-100, -100), (-12, -100), -1), ((12, -100), (100, -100), -1),   # north (play area to +Z)
        ((100, -100), (100, -12), -1), ((100, 12), (100, 100), -1),       # east
        ((100, 100), (12, 100), -1), ((-12, 100), (-100, 100), -1),       # south
        ((-100, 100), (-100, 12), -1), ((-100, -12), (-100, -100), -1),   # west
    ]
    for i, (a, b, inward) in enumerate(segments):
        chunks, proxy = cliff_run(f"HubCliff{i}", a, b, inward, HUB_Y, wall_h, HUB_ROCK, HUB_ROCK_DARK, rng,
                                  depth=16, material="Rock")
        visual += chunks
        proxies.append(proxy)
    for cx, cz in ((-100, -100), (100, -100), (100, 100), (-100, 100)):
        visual.append(part("CornerBastion", (22, wall_h + 8, 22), (cx, HUB_Y + (wall_h + 8) / 2 - 1, cz),
                           HUB_ROCK_DARK, "Rock", rot_y(45), layer="cliff"))

    # Monument: a sword in a stepped stone plinth, orientation landmark at the plaza centre.
    mon = []
    for k, (w, h) in enumerate(((13, 1.2), (9.5, 1.4), (6.5, 3.2))):
        base = HUB_Y + 0.2 + sum(hh for _, hh in ((13, 1.2), (9.5, 1.4), (6.5, 3.2))[:k])
        mon.append(part(f"Step{k}", (w, h, w), (0, base + h / 2, 0), STONE if k < 2 else STONE_DARK, "Cobblestone",
                        rot_y(45 * k)))
    top = HUB_Y + 0.2 + 5.8
    tilt = rot_z(7)
    axis = apply(tilt, (0, 1, 0))  # every piece is placed along the tilted blade axis

    def along(distance):
        return tuple(axis[i] * distance + (0, top, 0)[i] for i in range(3))

    # Distances along the axis from where the blade enters the stone (negative = buried).
    mon += [
        part("Blade", (0.6, 12, 2.2), along(4.5), (196, 200, 206), "Metal", tilt, collide=False),  # -1.5 .. 10.5
        part("Fuller", (0.64, 9, 0.5), along(5.2), (150, 154, 162), "Metal", tilt, collide=False),
        part("Guard", (1.2, 0.9, 7), along(10.95), GOLD, "Metal", tilt, collide=False),
        part("Grip", (0.9, 3.2, 0.9), along(13.0), (84, 52, 36), "Fabric", tilt, collide=False),
        part("Pommel", (1.6, 1.6, 1.6), along(15.2), GOLD, "Metal", tilt, collide=False, shape="Ball"),
    ]
    visual.append(model("SwordMonument", mon))

    # Spawn pad + travel board.
    visual += disc("SpawnPad", 0, -40, 6, HUB_Y + 0.45, 0.5, STONE, "Slate", collide=False, layer="decal")
    visual.append(sign("TravelBoard", -16, HUB_Y, -44, yaw_facing(1, 0), 7, 5, "Travel", "Waystones you have found"))
    visual.append(waystone("HubWaystone", "HubSpawn", -16, HUB_Y, -36))

    # Sword shop (west): timber house, open counter facing the west road.
    visual.append(timber_house("SwordShop", -82, -44, -50, -20, HUB_Y, 13, "S", rng, door_w=12, roof_color=ROOF))
    visual.append(box("ShopCounter", -70, -54, HUB_Y, HUB_Y + 3.4, -14.6, -12.4, TIMBER, "WoodPlanks"))
    visual.append(part("ShopAwning", (26, 0.5, 7), (-62, HUB_Y + 11.2, -16.5), (176, 60, 52), "Fabric",
                       rot_x(16), collide=False))
    visual.append(sign("ShopSign", -38, HUB_Y, -12, yaw_facing(1, 0), 10, 3.6, "Sword Shop", "Relic blades"))
    for k, x in enumerate((-76, -48)):
        visual.append(part(f"WeaponRack{k}", (6, 5, 1), (x, HUB_Y + 2.5, -18.5), BEAM, "Wood", collide=True))
        for j in range(3):
            visual.append(part(f"RackBlade{k}{j}", (0.4, 4.2, 1), (x - 2 + j * 2, HUB_Y + 3.6, -17.8),
                               (190, 194, 200), "Metal", collide=False))

    # Skill trainer (east): fenced yard with dummies and a hut.
    visual.append(timber_house("TrainerHut", 70, 88, -50, -36, HUB_Y, 10, "W", rng, door_w=5, roof_color=(84, 70, 60)))
    visual.append(fence_run("TrainingFenceN", (42, -50), (70, -50), road))
    visual.append(fence_run("TrainingFenceW", (42, -49.5), (42, -10), road, gap=(26, 40), skip_first_post=True))
    visual.append(fence_run("TrainingFenceE", (88, -36), (88, -10), road))
    for k, (x, z) in enumerate(((52, -40), (60, -30), (68, -22), (76, -28))):
        visual.append(model(f"Dummy{k}", [
            part("Post", (0.8, 6, 0.8), (x, HUB_Y + 3, z), BEAM, "Wood", collide=False),
            part("Body", (2.4, 3, 1.4), (x, HUB_Y + 4.4, z), (196, 170, 100), "Sand", collide=False),
            part("Arms", (5, 0.6, 0.6), (x, HUB_Y + 5.2, z), BEAM, "Wood", collide=False),
        ]))
    visual.append(sign("TrainerSign", 50, HUB_Y, -10.5, 180, 10, 3.6, "Skill Trainer", "Reset your skill points"))

    # Rebirth shrine (south-east): octagonal dais, pillars, a pale floating crystal.
    visual += disc("ShrineDais", 64, 40, 15, HUB_Y + 1.2, 1.2, STONE, "Marble", layer="prop")
    visual += disc("ShrineInner", 64, 40, 9, HUB_Y + 2.2, 1.0, (200, 196, 186), "Marble", layer="prop")
    for k in range(4):
        a = math.radians(45 + 90 * k)
        px, pz = 64 + math.cos(a) * 12, 40 + math.sin(a) * 12
        visual.append(part(f"ShrinePillar{k}", (2.4, 14, 2.4), (px, HUB_Y + 1.2 + 7, pz), (220, 216, 204), "Marble"))
        visual.append(part(f"ShrineCap{k}", (3.4, 1, 3.4), (px, HUB_Y + 15.7, pz), GOLD, "Metal", collide=False))
    visual.append(part("RebirthCrystal", (3, 5, 3), (64, HUB_Y + 9, 40), (170, 220, 255), "Glass",
                       mul(rot_y(45), rot_x(45)), collide=False, query=False, transparency=0.25,
                       children=[light(18, 1.0, (170, 210, 255))]))
    visual.append(sign("ShrineSign", 76, HUB_Y, 22, yaw_facing(0, -1), 10, 3.6, "Rebirth Shrine", "Begin again, stronger"))

    # Quest court beside the route out: the Quest Master's market stall, open toward the road.
    visual.append(quest_stall("QuestStall", 14, HUB_Y + 0.2, 50))

    # Houses and dressing (north-west, south-west).
    visual.append(timber_house("HouseNW1", -86, -60, -90, -70, HUB_Y, 11, "S", rng))
    visual.append(timber_house("HouseNW2", -48, -26, -88, -68, HUB_Y, 10, "S", rng, wall_color=(206, 184, 150),
                               roof_color=(90, 64, 48)))
    visual.append(timber_house("HouseSW", -86, -64, 66, 90, HUB_Y, 10, "E", rng, roof_color=(96, 58, 46)))
    visual.append(model("Well", [
        part("WellRing", (7, 3, 7), (-50, HUB_Y + 1.5, 48), STONE, "Cobblestone"),
        part("WellWater", (5.4, 0.4, 5.4), (-50, HUB_Y + 2.7, 48), (70, 110, 140), "Glass", collide=False,
             transparency=0.2),
        part("WellPostL", (0.8, 7, 0.8), (-53.2, HUB_Y + 3.5, 48), BEAM, "Wood"),
        part("WellPostR", (0.8, 7, 0.8), (-46.8, HUB_Y + 3.5, 48), BEAM, "Wood"),
        part("WellRoof", (8.5, 0.6, 5), (-50, HUB_Y + 7.3, 48), ROOF, "RoofShingles", collide=False),
    ]))

    # Sealed destinations: visible milestones through barred gates.
    visual.append(gate("GateIronLowlands", 0, HUB_Y, 100, 0, 24, 22, "Iron Lowlands", "Lv 1 - 10  |  Open",
                       sealed=False, region="IronLowlands", required_level=1))
    visual.append(gate("GateFrostbound", -100, HUB_Y, 0, -90, 24, 22, "Frostbound Glacier", "Lv 18+  |  Coming soon",
                       sealed=True, accent=(90, 140, 190), region="FrostboundGlacier", required_level=18))
    visual.append(gate("GateCaldera", 100, HUB_Y, 0, 90, 24, 22, "Infernal Caldera", "Lv 34+  |  Coming soon",
                       sealed=True, accent=(190, 80, 30), region="InfernalCaldera", required_level=34))
    visual.append(gate("GateAscension", 0, HUB_Y, -100, 180, 24, 26, "Ascension Gate", "Celestial Summit  |  Coming soon",
                       sealed=True, stone=CELESTIAL, accent=GOLD, region="CelestialSummit", required_level=80))
    # Vistas behind sealed gates (collidable floors, unreachable past the portcullis).
    for k in range(8):  # celestial stair rising north
        z0 = -104 - k * 6
        visual.append(box(f"AscensionStep{k}", -10, 10, 0, HUB_Y + 1.5 * (k + 1), z0 - 6, z0, CELESTIAL, "Marble",
                          layer="vista"))
    for side in (-1, 1):
        for k in range(3):
            visual.append(part(f"AscensionColumn{side}{k}", (3, 22 + k * 4, 3),
                               (side * 11, HUB_Y + 11 + k * 6, -112 - k * 14), CELESTIAL, "Marble", collide=False,
                               layer="vista"))
    visual.append(box("FrostVista", -150, -104, 0, HUB_Y + 2, -14, 14, FROST, "Snow", layer="vista"))
    for k in range(4):
        visual.append(part(f"FrostRock{k}", (10, 18 + k * 5, 12), (-118 - k * 9, HUB_Y + 8 + k * 2, -8 + k * 5),
                           FROST, "Snow", rot_y(20 * k), collide=False, layer="vista"))
    visual.append(box("CalderaVista", 104, 150, 0, HUB_Y, -14, 14, CALDERA, "Basalt", layer="vista"))
    visual.append(part("CalderaGlow", (3, 10, 20), (140, HUB_Y + 5, 0), EMBER, "Neon", collide=False, query=False,
                       transparency=0.35, layer="vista", children=[light(40, 2.0, (255, 120, 50))]))
    for k in range(3):
        visual.append(part(f"MineBeam{k}", (1.4, 14, 1.4), (118 + k * 8, HUB_Y + 7, 10 - k), BEAM, "Wood",
                           collide=False, layer="vista"))

    # Void Rift portal (sealed) in the north-east quarter.
    vr = []
    fx, fz, yaw = 68, -72, yaw_facing(-1, 1)
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))
    for side in (-1, 1):
        vr.append(part(f"VoidPillar{side}", (4, 18, 4), (fx + right[0] * side * 8, HUB_Y + 9, fz + right[2] * side * 8),
                       VOID, "Basalt", r))
    vr.append(part("VoidArch", (21, 3.5, 4.4), (fx, HUB_Y + 19.5, fz), VOID, "Basalt", r))
    vr.append(part("VoidVeil", (12, 16, 0.4), (fx, HUB_Y + 8.5, fz), VOID_GLOW, "ForceField", r, collide=True,
                   query=False, transparency=0.3, shadow=False, children=[light(20, 0.9, VOID_GLOW)]))
    vr.append(sign("VoidSign", fx - 9, HUB_Y, fz + 9, yaw_facing(-1, 1), 9, 3.4, "Void Rift", "Lv 55+  |  Coming soon",
                   board=(50, 36, 70), text=(220, 190, 255)))
    visual.append(model("VoidRiftPortal", vr, attrs={"Region": "VoidRift", "Sealed": True, "RequiredLevel": 55}))

    # Trees in the green quarters, lamp posts along roads.
    tree_spots = [(-88, -54), (-70, -58), (-30, -54), (-20, -80), (-14, -62),
                  (32, -84), (48, -62), (86, -64), (24, -28), (-28, 24),
                  (-70, 30), (-34, 66), (-18, 86), (-88, 46), (36, 86),
                  (86, 66), (40, 70), (86, 16), (30, 26), (-88, 12), (-40, 90)]
    for k, (x, z) in enumerate(tree_spots):
        visual.append(tree(f"Tree{k:02d}", x, HUB_Y, z, rng))
    lamps = [(-11, -70), (11, -28), (-11, 34), (11, 78), (-34, 11), (-90, 11), (34, -11), (78, 11)]
    for k, (x, z) in enumerate(lamps):
        visual.append(lamp_post(f"Lamp{k}", x, HUB_Y, z, yaw_facing(-x, 0) if abs(x) < 20 else yaw_facing(0, -z)))
    return ground, visual, proxies


# ── Iron Lowlands: pass → overlook → yard → pits → Warlord's Pit ─────────────
def build_iron_lowlands(rng):
    Y, T = QUARRY_Y, HUB_Y
    ground = [
        slab("PassFloor", -14, 14, 104, 140, T, (140, 130, 116), "Cobblestone"),
        slab("OverlookFloor", -40, 40, 140, 168, T, (140, 112, 84), "Ground"),
        slab("QuarryFloor", -112, 112, 168, 472, Y, QUARRY_FLOOR, "Ground"),
        slab("SidePassageFloor", -167, -112, 283, 347, Y, QUARRY_FLOOR, "Ground"),
        ramp("OverlookRamp", -14, 14, 168, 200, T, Y, (132, 104, 78), "WoodPlanks"),
        box("QuarryPath", -10, 10, Y, Y + 0.2, 200, 382, QUARRY_PATH, "Pebble", layer="ground"),
        box("SidePath", -140, -10, Y, Y + 0.2, 309, 321, QUARRY_PATH, "Pebble", layer="ground"),
    ]
    ground += disc("ArenaFloor", 0, 424, 38, Y + 0.25, 0.5, (118, 108, 98), "Cobblestone")
    visual, proxies = [], []

    def cliffs(name, pts, inward, base, height, depth=16):
        for i in range(len(pts) - 1):
            chunks, proxy = cliff_run(f"{name}{i}", pts[i], pts[i + 1], inward, base, height, QUARRY_CLIFF,
                                      QUARRY_CLIFF_DARK, rng, depth=depth)
            visual.extend(chunks)
            proxies.append(proxy)

    # Pass and overlook walls (upper level), quarry perimeter (lower level).
    cliffs("PassWest", [(-14, 100), (-14, 140), (-40, 140), (-40, 168)], 1, T, 30)
    cliffs("PassEast", [(40, 168), (40, 140), (14, 140), (14, 100)], 1, T, 30)
    cliffs("QuarryNorthW", [(-40, 168), (-110, 168)], 1, Y, 46)
    cliffs("QuarryWestN", [(-110, 168), (-110, 285), (-165, 285), (-165, 345), (-110, 345), (-110, 470)], 1, Y, 46)
    cliffs("QuarrySouth", [(-110, 470), (-12, 470)], 1, Y, 46)
    cliffs("QuarrySouthE", [(12, 470), (110, 470)], 1, Y, 46)
    cliffs("QuarryEast", [(110, 470), (110, 168), (40, 168)], 1, Y, 46)
    # Retaining face under the overlook edge (the slab's own face shows; dress it with timber).
    for x0, x1 in ((-40, -14), (14, 40)):
        visual.append(box(f"RetainingBeam{x0}", x0, x1, Y + 3.5, Y + 4.5, 168, 168.8, BEAM, "Wood", collide=False))
    for side in (-1, 1):  # stepped curbs hide the void beside the ramp and keep players on it
        for k in range(4):
            z0 = 168 + k * 8
            h = (T - Y) * (1 - k / 4)
            visual.append(box(f"RampCurb{side}_{k}", side * 14.8 - 0.8, side * 14.8 + 0.8, Y, Y + h + 0.6, z0, z0 + 8,
                              STONE_DARK, "Cobblestone", layer="prop"))
    visual.append(fence_run("OverlookFenceW", (-40, 167.4), (-14, 167.4), T))
    visual.append(fence_run("OverlookFenceE", (14, 167.4), (40, 167.4), T))

    # Boss gap: two rock ridges leave a 40-stud opening so the Warlord is visible early.
    for side, (x0, x1) in ((-1, (-110, -20)), (1, (20, 110))):
        for k, xs in enumerate(range(int(x0), int(x1), 15)):
            xe = min(xs + 15, x1)
            h = rng.uniform(16, 24)
            visual.append(part(f"Ridge{side}_{k}", (xe - xs + 2, h, 16), ((xs + xe) / 2, Y + h / 2 - 1, 375),
                               QUARRY_CLIFF_DARK, "Sandstone", rot_y(rng.uniform(-5, 5)), collide=False, layer="cliff"))
        proxies.append(box(f"RidgeProxy{side}", x0, x1, Y - 1, Y + 26, 368, 382, (255, 0, 255), transparency=1,
                           query=False, shadow=False, layer="proxy"))

    visual.append(waystone("OverlookWaystone", "IronOverlook", 28, T, 148))
    visual.append(sign("OverlookGuide", -26, T, 160, yaw_facing(0, -1), 12, 5, "Squire Yard  >  Crusher Pits",
                       "The Iron Warlord waits beyond the ridge"))

    # Squire Yard dressing (outside lanes: |x| >= 66 or tucked against cliffs).
    for k, (x, z) in enumerate(((-92, 190), (-80, 236), (94, 214), (86, 262), (-98, 262), (70, 190))):
        visual.append(rock_cluster(f"YardRocks{k}", x, Y, z, rng, color=(118, 100, 84), size=1.2))
    visual.append(scaffold("YardScaffoldE", 104, Y, 236, 90, 30))
    visual.append(scaffold("YardScaffoldW", -104, Y, 204, -90, 24))
    visual.append(campfire("YardCampfire", -72, Y, 212, rng))
    visual.append(tent("YardTentA", -88, Y, 222, 10))
    visual.append(tent("YardTentB", -86, Y, 200, -8, color=(130, 100, 80)))
    visual.append(stone_stack("YardStones", 76, Y, 236, rng))
    visual.append(lamp_post("YardLampW", -16, Y, 206, yaw_facing(1, 0)))
    visual.append(lamp_post("YardLampE", 16, Y, 262, yaw_facing(-1, 0)))

    # Crusher Pits dressing: rail line with carts, crane tower, stone stacks.
    visual.append(rail_track("PitRails", 94, Y + 0.2, 272, 364))
    visual.append(mine_cart("PitCartA", 94, Y + 0.4, 292, 0))
    visual.append(mine_cart("PitCartB", 94, Y + 0.4, 340, 0))
    crane = [part(f"CraneLeg{k}", (1.2, 26, 1.2), (78 + dx, Y + 13, 306 + dz), BEAM, "Wood", collide=(k == 0))
             for k, (dx, dz) in enumerate(((0, 0), (6, 0), (0, 6), (6, 6)))]
    crane += [part("CraneDeck", (8, 0.8, 8), (81, Y + 26, 309), TIMBER, "WoodPlanks", collide=False),
              part("CraneBoom", (22, 1, 1), (70, Y + 27.5, 309), BEAM, "Wood", collide=False),
              part("CraneRope", (0.25, 14, 0.25), (61, Y + 20.5, 309), (90, 80, 60), "Fabric", collide=False),
              part("CraneLoad", (4, 3.4, 4), (61, Y + 12, 309), (186, 160, 120), "Limestone", collide=False)]
    visual.append(model("PitCrane", crane))
    for k, (x, z) in enumerate(((-86, 290), (-92, 352), (70, 356), (-70, 276))):
        visual.append(stone_stack(f"PitStones{k}", x, Y, z, rng))
    for k, (x, z) in enumerate(((66, 276), (-96, 322), (100, 318))):
        visual.append(rock_cluster(f"PitRocks{k}", x, Y, z, rng, color=ROCK_GRAY))
    visual.append(lamp_post("PitLampW", -16, Y, 300, yaw_facing(1, 0)))
    visual.append(lamp_post("PitLampE", 16, Y, 344, yaw_facing(-1, 0)))

    # Optional side passage: lantern arch, hidden elite, a supply cache (decorative for now).
    visual.append(model("SideArch", [
        part("PostN", (1.6, 12, 1.6), (-111, Y + 6, 296), BEAM, "Wood"),
        part("PostS", (1.6, 12, 1.6), (-111, Y + 6, 334), BEAM, "Wood"),
        part("Beam", (1.8, 1.6, 40), (-111, Y + 12.4, 315), BEAM, "Wood", collide=False),
        part("LanternN", (1.2, 1.6, 1.2), (-109.5, Y + 10.5, 299), LANTERN, "Neon", collide=False, query=False,
             children=[light(16, 1.0)]),
    ]))
    visual.append(model("SupplyCache", [
        part("Chest", (4.5, 3, 3), (-158, Y + 1.5, 315), (110, 70, 40), "WoodPlanks"),
        part("ChestBand", (4.7, 0.5, 3.2), (-158, Y + 2.2, 315), GOLD, "Metal", collide=False),
        part("Crate1", (4, 4, 4), (-156, Y + 2, 305), TIMBER, "WoodPlanks", rot_y(12)),
        part("Crate2", (3.4, 3.4, 3.4), (-159, Y + 1.7, 326), TIMBER, "WoodPlanks", rot_y(-20)),
    ]))

    # Warlord's Pit: standing stones, braziers, banners, sealed Briarwood gate beyond.
    for k in range(14):
        a = math.tau * k / 14
        if k in (0, 7):  # openings facing the ridge gap (north) and the Briarwood gate (south)
            continue
        x, z = math.sin(a) * 42, 424 - math.cos(a) * 42
        h = rng.uniform(10, 15)
        visual.append(part(f"StandingStone{k:02d}", (4.5, h, 3), (x, Y + h / 2, z), (130, 118, 104), "Slate",
                           rot_y(-math.degrees(a)), layer="rock"))
    for k, (x, z) in enumerate(((-22, 390), (22, 390), (-42, 440), (42, 440))):
        visual.append(brazier(f"PitBrazier{k}", x, Y, z))
    for k, x in enumerate((-18, -6, 6, 18)):
        visual.append(banner_pole(f"WarlordBanner{k}", x, Y, 462, 0))
    visual.append(sign("WarlordSign", -30, Y, 360, yaw_facing(0, -1), 12, 5, "Warlord's Pit",
                       "Iron Warlord  |  Lv 10  |  Boss", board=(70, 36, 36)))
    visual.append(waystone("WarlordWaystone", "WarlordGate", -18, Y, 356))
    visual.append(gate("GateBriarwood", 0, Y, 470, 0, 24, 22, "Briarwood", "Lv 9+  |  Coming soon", sealed=True,
                       accent=(90, 120, 60), region="Briarwood", required_level=9,
                       back_title="Briarwood"))
    for k, (x, z) in enumerate(((-7, 486), (7, 495), (-2, 506))):
        visual.append(tree(f"BriarVistaTree{k}", x, Y, z, rng, scale=1.4))
    visual.append(box("BriarVistaFloor", -14, 14, 0, Y, 472, 514, GRASS_DARK, "Grass", layer="vista"))
    return ground, visual, proxies


# ── Output ────────────────────────────────────────────────────────────────────
def write_model(path: Path, node: dict):
    root = {k: v for k, v in node.items() if k != "name"}
    path.write_text(json.dumps(root, indent=1) + "\n")


def main():
    rng = random.Random(20260915)
    REGISTRY.clear()
    USED_CLIFF_TOPS.clear()
    hub_ground, hub_visual, hub_proxies = build_hub(rng)
    il_ground, il_visual, il_proxies = build_iron_lowlands(rng)
    markers = build_markers()

    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    (OUT / "init.meta.json").write_text(json.dumps({
        "className": "Folder",
        "attributes": {"MapVersion": MAP_VERSION, "MapName": "Lemonade Hearthmere Slice"},
    }, indent=1) + "\n")
    write_model(OUT / "Grounds_Hub.model.json", model("Grounds_Hub", hub_ground))
    write_model(OUT / "Grounds_IronLowlands.model.json", model("Grounds_IronLowlands", il_ground))
    write_model(OUT / "Collision.model.json", model("Collision", hub_proxies + il_proxies))
    write_model(OUT / "Hub.model.json", model("Hub", hub_visual, attrs={"Region": "Hub"}))
    write_model(OUT / "IronLowlands.model.json", model("IronLowlands", il_visual, attrs={"Region": "IronLowlands"}))
    write_model(OUT / "Markers.model.json", markers)

    counts = {}
    for entry in REGISTRY:
        counts[entry["layer"]] = counts.get(entry["layer"], 0) + 1
    print(f"[map_forge] wrote {OUT.relative_to(ROOT)}: {len(REGISTRY)} parts", dict(sorted(counts.items())))
    try:
        render_topdown(DOCS / "first_slice_topdown.png")
    except ImportError:
        print("[map_forge] Pillow not installed; skipped top-down preview")


# ── Top-down preview ──────────────────────────────────────────────────────────
def render_topdown(path: Path):
    from PIL import Image, ImageDraw, ImageFont

    x_min, x_max, z_min, z_max = -190, 150, -160, 510
    scale = 2.2
    pad = 60
    w = int((x_max - x_min) * scale) + pad * 2
    h = int((z_max - z_min) * scale) + pad * 2
    img = Image.new("RGB", (w, h), (28, 30, 34))
    draw = ImageDraw.Draw(img, "RGBA")
    try:
        font = ImageFont.truetype("DejaVuSans.ttf", 13)
        font_b = ImageFont.truetype("DejaVuSans-Bold.ttf", 16)
    except OSError:
        font = font_b = ImageFont.load_default()

    def px(x, z):
        return pad + (x - x_min) * scale, pad + (z - z_min) * scale

    order = {"vista": 0, "ground": 1, "decal": 2, "cliff": 3, "prop": 4, "rock": 4, "tree": 4, "roof": 5,
             "canopy": 6, "proxy": 7, "volume": 8, "marker": 9}
    for e in sorted(REGISTRY, key=lambda e: (order.get(e["layer"], 4), e["pos"][1] + e["size"][1] / 2)):
        if e["layer"] in ("marker", "volume"):
            continue
        if abs(e["rot"][1][0]) > 0.99:  # vertical-axis cylinder disc
            cx, cz = px(e["pos"][0], e["pos"][2])
            rr = e["size"][1] / 2 * scale
            draw.ellipse([cx - rr, cz - rr, cx + rr, cz + rr], fill=(*e["color"], 255))
            continue
        sx, _, sz = e["size"]
        corners = []
        for cx, cz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            v = apply(e["rot"], (cx * sx / 2, 0, cz * sz / 2))
            corners.append(px(e["pos"][0] + v[0], e["pos"][2] + v[2]))
        if e["layer"] == "proxy":
            draw.polygon(corners, outline=(255, 60, 200, 110))
        else:
            alpha = 150 if e["layer"] == "canopy" else 255
            draw.polygon(corners, fill=(*e["color"], alpha))

    # Grid + axis labels every 50 studs.
    for x in range(-150, 151, 50):
        draw.line([px(x, z_min), px(x, z_max)], fill=(255, 255, 255, 30))
        draw.text((px(x, z_min)[0] - 12, 8), f"x{x}", fill=(200, 200, 200), font=font)
    for z in range(-150, 501, 50):
        draw.line([px(x_min, z), px(x_max, z)], fill=(255, 255, 255, 30))
        draw.text((6, px(x_min, z)[1] - 7), f"z{z}", fill=(200, 200, 200), font=font)

    # Safe zones, spawns, NPCs, waypoints.
    for (x0, x1, z0, z1, name) in ((-100, 100, -100, 100, "SAFE: Hub"), (-40, 40, 100, 168, "SAFE: Overlook")):
        draw.rectangle([px(x0, z0), px(x1, z1)], outline=(80, 255, 140, 220), width=2)
        draw.text((px(x0, z0)[0] + 4, px(x0, z0)[1] + 4), name, fill=(120, 255, 170), font=font)
    arch_color = {"IronSquire": (255, 210, 90), "IronBerserker": (255, 130, 60), "Boss_Gorgon": (255, 60, 60)}
    for sid, arch, level, role, (x, z), leash in ENEMY_SPAWNS:
        cx, cz = px(x, z)
        rr = leash * scale
        draw.ellipse([cx - rr, cz - rr, cx + rr, cz + rr], outline=(*arch_color[arch], 90))
        dot = 9 if role == "boss" else 6
        draw.ellipse([cx - dot, cz - dot, cx + dot, cz + dot], fill=arch_color[arch], outline=(0, 0, 0))
        draw.text((cx + 9, cz - 7), f"{arch.replace('Iron', '').replace('Boss_', '')} L{level}", fill=(255, 255, 255),
                  font=font)
    for name, (x, z) in (("Quest Master", (15, 50)), ("Merchant", (-62, -16.5)), ("Skill Trainer", (58, -12)),
                         ("Rebirth", (64, 22)), ("Travel board", (-16, -40))):
        cx, cz = px(x, z)
        draw.rectangle([cx - 5, cz - 5, cx + 5, cz + 5], fill=(90, 170, 255), outline=(0, 0, 0))
        draw.text((cx + 8, cz - 7), name, fill=(170, 210, 255), font=font)
    for wid, display, region, (x, y, z), yaw, order in WAYPOINTS:
        cx, cz = px(x, z)
        draw.polygon([(cx, cz - 9), (cx + 9, cz), (cx, cz + 9), (cx - 9, cz)], fill=(120, 230, 240), outline=(0, 0, 0))
        draw.text((cx + 11, cz + 2), display, fill=(160, 240, 250), font=font)

    # Dimension annotations.
    def dim(a, b, text, offset):
        (ax, az), (bx, bz) = px(*a), px(*b)
        draw.line([(ax, az + offset), (bx, bz + offset)], fill=(255, 255, 255), width=2)
        draw.text(((ax + bx) / 2 - 30, (az + bz) / 2 + offset - 18), text, fill=(255, 255, 255), font=font_b)

    dim((-100, -100), (100, -100), "Hub 200 × 200", -22)
    dim((-110, 472), (110, 472), "Quarry 220 × 304", 26)
    draw.text((pad, h - pad + 18), "Hearthmere + Iron Lowlands — map_forge top-down (1 grid = 50 studs, +Z down)",
              fill=(230, 230, 230), font=font_b)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"[map_forge] preview {path.relative_to(ROOT)} ({w}×{h})")


if __name__ == "__main__":
    main()
