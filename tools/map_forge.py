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
    while any(round(top * 10) + d in USED_CLIFF_TOPS for d in (-1, 0, 1)):
        top += 0.3
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


def smoke(size=4.0, opacity=0.35, rise=3.0, color=(200, 200, 205)) -> dict:
    return inst("Smoke", "Smoke", {"Size": size, "Opacity": opacity, "RiseVelocity": rise,
                                   "Color": [_r(c / 255) for c in color]})


def timber_house(name, x0, x1, z0, z1, y, wall_h, front, rng, door_w=6.0, open_front=False,
                 wall_color=PLASTER, roof_color=ROOF, door=False, windows=True, chimney=True):
    """Timber-framed building. `front` ∈ {'N','S','E','W'} gets the door (or is fully open).

    door=True closes the doorway with a collidable plank door; windows get frames, glass and a
    warm light; the chimney carries a Smoke emitter.
    """
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
    # Door: plank slab in the opening, iron bands and a ring handle. Collidable, so the empty
    # interior stays closed rather than being a box players can wander into.
    if door and not open_front:
        a0, a1, b0, b1 = walls[front]
        door_h = min(wall_h - 1.0, 8.0)
        if front in "NS":
            mid = (a0 + a1) / 2
            bz = (b0 + b1) / 2
            kids.append(box("Door", mid - door_w / 2 + 0.2, mid + door_w / 2 - 0.2, y + 0.8, y + 0.8 + door_h,
                            bz - 0.2, bz + 0.2, (110, 72, 42), "WoodPlanks"))
            for k, hy in enumerate((0.25, 0.7)):
                kids.append(box(f"DoorBand{k}", mid - door_w / 2 + 0.3, mid + door_w / 2 - 0.3,
                                y + 0.8 + door_h * hy - 0.2, y + 0.8 + door_h * hy + 0.2, bz - 0.32, bz + 0.32,
                                IRON, "Metal", collide=False))
            hz = b0 - 0.35 if front == "N" else b1 + 0.35
            kids.append(part("DoorHandle", (0.5, 0.5, 0.3), (mid + door_w / 2 - 1.1, y + 0.8 + door_h * 0.45, hz),
                             GOLD, "Metal", collide=False))
            kids.append(box("DoorLintel", mid - door_w / 2 - 0.6, mid + door_w / 2 + 0.6, y + 0.8 + door_h,
                            y + 0.8 + door_h + 0.7, b0 - 0.15, b1 + 0.15, BEAM, "Wood"))
        else:
            mid = (b0 + b1) / 2
            bx = (a0 + a1) / 2
            kids.append(box("Door", bx - 0.2, bx + 0.2, y + 0.8, y + 0.8 + door_h, mid - door_w / 2 + 0.2,
                            mid + door_w / 2 - 0.2, (110, 72, 42), "WoodPlanks"))
            for k, hy in enumerate((0.25, 0.7)):
                kids.append(box(f"DoorBand{k}", bx - 0.32, bx + 0.32, y + 0.8 + door_h * hy - 0.2,
                                y + 0.8 + door_h * hy + 0.2, mid - door_w / 2 + 0.3, mid + door_w / 2 - 0.3,
                                IRON, "Metal", collide=False))
            hx = a0 - 0.35 if front == "W" else a1 + 0.35
            kids.append(part("DoorHandle", (0.3, 0.5, 0.5), (hx, y + 0.8 + door_h * 0.45, mid + door_w / 2 - 1.1),
                             GOLD, "Metal", collide=False))
            kids.append(box("DoorLintel", a0 - 0.15, a1 + 0.15, y + 0.8 + door_h, y + 0.8 + door_h + 0.7,
                            mid - door_w / 2 - 0.6, mid + door_w / 2 + 0.6, BEAM, "Wood"))
    # Windows on every wall but the front: frame, glass and a warm light inside; a flower box below.
    if windows:
        wy = y + 0.8 + wall_h * 0.55
        for side, (a0, a1, b0, b1) in walls.items():
            if side == front:
                continue
            length = (a1 - a0) if side in "NS" else (b1 - b0)
            slots = [0.5] if length < 16 else [0.3, 0.7]
            for wi, frac in enumerate(slots):
                if side in "NS":
                    wx = a0 + length * frac
                    wz = b0 - 0.3 if side == "N" else b1 + 0.3
                    size, fsize, sides_size = (2.6, 2.6, 0.3), (3.2, 0.3, 0.5), (0.3, 2.9, 0.5)
                    glass_pos = (wx, wy, wz)
                    frame_h, frame_l = (wx, wy + 1.45, wz), (wx, wy - 1.45, wz)
                    side_a, side_b = (wx - 1.45, wy, wz), (wx + 1.45, wy, wz)
                    box_pos = (wx, wy - 1.9, wz + (0.55 if side == "S" else -0.55))
                    box_size = (3.0, 0.7, 0.9)
                else:
                    wz = b0 + length * frac
                    wx = a0 - 0.3 if side == "W" else a1 + 0.3
                    size, fsize, sides_size = (0.3, 2.6, 2.6), (0.5, 0.3, 3.2), (0.5, 2.9, 0.3)
                    glass_pos = (wx, wy, wz)
                    frame_h, frame_l = (wx, wy + 1.45, wz), (wx, wy - 1.45, wz)
                    side_a, side_b = (wx, wy, wz - 1.45), (wx, wy, wz + 1.45)
                    box_pos = (wx + (0.55 if side == "E" else -0.55), wy - 1.9, wz)
                    box_size = (0.9, 0.7, 3.0)
                kids.append(part(f"Glass{side}{wi}", size, glass_pos, (150, 190, 205), "Glass", collide=False,
                                 transparency=0.35, children=[light(9, 0.8, (255, 205, 140))]))
                kids.append(part(f"Frame{side}{wi}T", fsize, frame_h, BEAM, "Wood", collide=False))
                kids.append(part(f"Frame{side}{wi}B", fsize, frame_l, BEAM, "Wood", collide=False))
                kids.append(part(f"Frame{side}{wi}L", sides_size, side_a, BEAM, "Wood", collide=False))
                kids.append(part(f"Frame{side}{wi}R", sides_size, side_b, BEAM, "Wood", collide=False))
                kids.append(part(f"FlowerBox{side}{wi}", box_size, box_pos, (96, 64, 40), "Wood", collide=False))
                for fi in range(3):
                    off = (fi - 1) * 0.9
                    fp = (box_pos[0] + (off if side in "NS" else 0), box_pos[1] + 0.55,
                          box_pos[2] + (off if side in "EW" else 0))
                    kids.append(part(f"Bloom{side}{wi}{fi}", (0.55, 0.55, 0.55), fp, rng.choice(FLOWER_COLORS),
                                     "SmoothPlastic", shape="Ball", collide=False, query=False, shadow=False))
    # Timber frame: corner posts, sill and top beams, a diagonal brace per long wall.
    for cx in (x0, x1):
        for cz in (z0, z1):
            kids.append(box("CornerPost", cx - 0.7, cx + 0.7, y + 0.8, top - 0.2, cz - 0.7, cz + 0.7, BEAM, "Wood"))
    for side, (a0, a1, b0, b1) in walls.items():
        if side == front and open_front:
            continue
        pad = 0.25
        mid0, mid1 = y + 0.8 + wall_h * 0.45, y + 0.8 + wall_h * 0.45 + 0.7
        # The mid rail stops either side of the doorway; a full rail crossed the opening at
        # chest height and players walked straight through it.
        if side in "NS":
            bz = b0 - pad if side == "N" else b1 + pad
            kids.append(box(f"TopBeam{side}", a0, a1, top - 0.9, top, bz - 0.3, bz + 0.3, BEAM, "Wood", collide=False))
            spans = [(a0, a1)] if side != front else [(a0, (a0 + a1) / 2 - door_w / 2), ((a0 + a1) / 2 + door_w / 2, a1)]
            for si, (m0, m1) in enumerate(spans):
                if m1 - m0 > 0.2:
                    kids.append(box(f"MidBeam{side}{si}", m0, m1, mid0, mid1, bz - 0.3, bz + 0.3, BEAM, "Wood",
                                    collide=False))
        else:
            bx = a0 - pad if side == "W" else a1 + pad
            kids.append(box(f"TopBeam{side}", bx - 0.3, bx + 0.3, top - 0.9, top, b0, b1, BEAM, "Wood", collide=False))
            spans = [(b0, b1)] if side != front else [(b0, (b0 + b1) / 2 - door_w / 2), ((b0 + b1) / 2 + door_w / 2, b1)]
            for si, (m0, m1) in enumerate(spans):
                if m1 - m0 > 0.2:
                    kids.append(box(f"MidBeam{side}{si}", bx - 0.3, bx + 0.3, mid0, mid1, m0, m1, BEAM, "Wood",
                                    collide=False))
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
    if chimney:
        # Stone stack through the roof near one end of the ridge, with smoke drifting from it.
        if span_x >= span_z:
            chx, chz = x0 + span_x * 0.22, cz
        else:
            chx, chz = cx, z0 + span_z * 0.22
        ch_top = top + rise + 2.4
        kids.append(part("Chimney", (2.4, ch_top - top + 1.5, 2.4), (chx, (top - 1.5 + ch_top) / 2, chz), STONE_DARK,
                         "Cobblestone", collide=False))
        kids.append(part("ChimneyCap", (3.0, 0.6, 3.0), (chx, ch_top + 0.3, chz), STONE, "Slate", collide=False))
        kids.append(part("ChimneyFlue", (1.2, 0.3, 1.2), (chx, ch_top + 0.6, chz), (30, 28, 26), "Slate",
                         collide=False, query=False, children=[smoke(3.5, 0.3, 2.5)]))
    if door and not open_front:
        # A furnished room so an opened door shows a home, not an empty box.
        fl = y + 0.8
        ix0, ix1, iz0, iz1 = x0 + 1.2, x1 - 1.2, z0 + 1.2, z1 - 1.2
        cxi, czi = (ix0 + ix1) / 2, (iz0 + iz1) / 2
        kids.append(box("FloorBoards", ix0, ix1, fl, fl + 0.12, iz0, iz1, (150, 112, 70), "WoodPlanks", collide=False))
        kids.append(part("Rug", (min(7, (ix1 - ix0) * 0.5), 0.08, min(5, (iz1 - iz0) * 0.4)), (cxi, fl + 0.18, czi),
                         rng.choice([(150, 60, 60), (70, 100, 150), (120, 90, 60)]), "Fabric", collide=False))
        # Bed along the wall opposite the door; table and stools in the middle; shelf on a side wall.
        if front in "NS":
            bz = iz0 + 2.2 if front == "S" else iz1 - 2.2
            kids.append(part("BedFrame", (4.4, 1.2, 3.2), (ix0 + 3.0, fl + 0.6, bz), BEAM, "Wood"))
            kids.append(part("Mattress", (4.2, 0.6, 3.0), (ix0 + 3.0, fl + 1.5, bz), (226, 214, 190), "Fabric", collide=False))
            kids.append(part("Blanket", (2.6, 0.25, 3.05), (ix0 + 3.8, fl + 1.9, bz), (120, 60, 60), "Fabric", collide=False))
            kids.append(part("Pillow", (1.2, 0.5, 1.6), (ix0 + 1.4, fl + 2.0, bz), (240, 236, 226), "Fabric", collide=False))
            kids.append(part("Shelf", (3.0, 0.3, 0.9), (ix1 - 2.0, fl + 5.0, iz0 + 0.5 if front == "S" else iz1 - 0.5),
                             BEAM, "Wood", collide=False))
        else:
            bx = ix0 + 2.2 if front == "E" else ix1 - 2.2
            kids.append(part("BedFrame", (3.2, 1.2, 4.4), (bx, fl + 0.6, iz0 + 3.0), BEAM, "Wood"))
            kids.append(part("Mattress", (3.0, 0.6, 4.2), (bx, fl + 1.5, iz0 + 3.0), (226, 214, 190), "Fabric", collide=False))
            kids.append(part("Blanket", (3.05, 0.25, 2.6), (bx, fl + 1.9, iz0 + 3.8), (120, 60, 60), "Fabric", collide=False))
            kids.append(part("Pillow", (1.6, 0.5, 1.2), (bx, fl + 2.0, iz0 + 1.4), (240, 236, 226), "Fabric", collide=False))
            kids.append(part("Shelf", (0.9, 0.3, 3.0), (ix0 + 0.5 if front == "E" else ix1 - 0.5, fl + 5.0, iz1 - 2.0),
                             BEAM, "Wood", collide=False))
        kids.append(part("TableTop", (3.6, 0.3, 2.4), (cxi, fl + 2.6, czi), TIMBER, "WoodPlanks"))
        for sx, sz in ((-1.5, -0.9), (1.5, -0.9), (-1.5, 0.9), (1.5, 0.9)):
            kids.append(part("TableLeg", (0.3, 2.5, 0.3), (cxi + sx, fl + 1.25, czi + sz), BEAM, "Wood", collide=False))
        for sx in (-2.8, 2.8):
            kids.append(part("Stool", (1.1, 1.4, 1.1), (cxi + sx, fl + 0.7, czi), BEAM, "Wood"))
        kids.append(part("Candle", (0.25, 0.7, 0.25), (cxi + 0.6, fl + 3.1, czi - 0.4), (240, 230, 200), "SmoothPlastic",
                         collide=False, query=False, children=[fire(0.6, 4), light(10, 0.8, (255, 200, 130))]))
        kids.append(part("Bowl", (0.9, 0.3, 0.9), (cxi - 0.8, fl + 2.9, czi + 0.3), (110, 72, 42), "Wood", rot_z(90),
                         shape="Cylinder", collide=False))
    attrs = None
    if door and not open_front:
        # Doorway centre, a doorstep outside and a spot inside: HubAmbience villagers live here.
        a0, a1, b0, b1 = walls[front]
        if front == "N":
            dx, dz, ox, oz = (a0 + a1) / 2, b0, (a0 + a1) / 2, b0 - 4
        elif front == "S":
            dx, dz, ox, oz = (a0 + a1) / 2, b1, (a0 + a1) / 2, b1 + 4
        elif front == "W":
            dx, dz, ox, oz = a0, (b0 + b1) / 2, a0 - 4, (b0 + b1) / 2
        else:
            dx, dz, ox, oz = a1, (b0 + b1) / 2, a1 + 4, (b0 + b1) / 2
        attrs = {"House": True, "DoorX": dx, "DoorZ": dz, "OutsideX": ox, "OutsideZ": oz,
                 "InsideX": (x0 + x1) / 2, "InsideZ": (z0 + z1) / 2, "FloorY": y + 0.8}
    return model(name, kids, attrs=attrs)


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


HOLO = (110, 220, 255)


def hologram_sword(name, x, floor_y, z):
    """Projector on the shrine dais with a translucent sword image floating above it.

    HubAmbience (client) spins and bobs every part named Holo* around the model's HoloAxis
    attribute point and flickers their transparency; the projector stays still.
    """
    center_y = floor_y + 6.8
    holo = dict(collide=False, query=False, shadow=False, layer="prop")
    kids = [
        part("ProjectorBase", (0.6, 4.2, 4.2), (x, floor_y + 0.3, z), IRON, "Metal", rot_z(90), shape="Cylinder",
             collide=False),
        part("ProjectorLens", (0.3, 2.4, 2.4), (x, floor_y + 0.75, z), HOLO, "Neon", rot_z(90), shape="Cylinder",
             collide=False, query=False, shadow=False, children=[light(16, 1.2, HOLO)]),
        part("ProjectorBeam", (3.8, 1.8, 1.8), (x, floor_y + 2.8, z), HOLO, "Neon", rot_z(90), shape="Cylinder",
             transparency=0.88, **holo),
        # The sword, tip down: blade, fuller, crossguard, grip, pommel.
        part("HoloBlade", (0.35, 6.4, 1.5), (x, center_y - 0.6, z), HOLO, "ForceField", transparency=0.15, **holo),
        part("HoloEdge", (0.2, 6.6, 1.7), (x, center_y - 0.6, z), (200, 245, 255), "Neon", transparency=0.7, **holo),
        part("HoloTip", (0.35, 1.06, 1.06), (x, center_y - 3.8, z), HOLO, "ForceField", rot_x(45),
             transparency=0.15, **holo),
        part("HoloGuard", (0.6, 0.5, 4.6), (x, center_y + 2.85, z), HOLO, "Neon", transparency=0.45, **holo),
        part("HoloGrip", (0.5, 1.9, 0.5), (x, center_y + 4.05, z), HOLO, "ForceField", transparency=0.2, **holo),
        part("HoloPommel", (0.9, 0.9, 0.9), (x, center_y + 5.3, z), HOLO, "Neon", shape="Ball", transparency=0.4,
             **holo),
    ]
    for k in range(3):  # scan rings the client slides up and down the image
        kids.append(part(f"HoloRing{k}", (0.08, 3.4, 3.4), (x, center_y - 3 + k * 3, z), HOLO, "Neon", rot_z(90),
                         shape="Cylinder", transparency=0.75, **holo))
    return model(name, kids, attrs={"Hologram": True, "HoloAxisY": center_y, "HoloX": x, "HoloZ": z})


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


def well(name, x, y, z, rng, radius=3.2):
    """Round stone well: block rim, dark shaft with water, winch frame, bucket and a small roof."""
    kids = []
    rim_top = y + 2.8
    # Round rim: a stone cylinder with a darker, slightly inset shaft cylinder inside it.
    kids.append(part("Rim", (rim_top - y, (radius + 0.2) * 2, (radius + 0.2) * 2), (x, (y + rim_top) / 2, z),
                     STONE, "Cobblestone", rot_z(90), shape="Cylinder"))
    kids.append(part("RimCap", (0.35, (radius + 0.5) * 2, (radius + 0.5) * 2), (x, rim_top + 0.1, z), STONE_DARK,
                     "Cobblestone", rot_z(90), shape="Cylinder", collide=False))
    kids.append(part("Shaft", (rim_top - y + 0.6, (radius - 0.9) * 2, (radius - 0.9) * 2), (x, (y + rim_top) / 2 - 0.1, z),
                     (26, 26, 30), "Slate", rot_z(90), shape="Cylinder", collide=False))
    kids.append(part("Water", (0.4, (radius - 1.1) * 2, (radius - 1.1) * 2), (x, y + 0.9, z), (58, 96, 128), "Glass",
                     rot_z(90), shape="Cylinder", collide=False, transparency=0.25))
    # Winch frame: two posts up to the eaves, a crossbeam, the roller and a crank.
    post_top = y + 9.4
    for side in (-1, 1):
        kids.append(part(f"Post{side}", (0.7, post_top - y, 0.7), (x + side * (radius + 0.4), (y + post_top) / 2, z),
                         BEAM, "Wood"))
    kids.append(part("Crossbeam", (radius * 2 + 2.4, 0.7, 0.7), (x, y + 8.6, z), BEAM, "Wood", collide=False))
    kids.append(part("Roller", (radius * 2 - 0.4, 0.8, 0.8), (x, y + 7.4, z), (120, 78, 46), "Wood", rot_z(90),
                     shape="Cylinder", collide=False))
    kids.append(part("Crank", (0.35, 1.4, 0.35), (x + radius + 0.2, y + 6.9, z), IRON, "Metal", collide=False))
    kids.append(part("CrankHandle", (0.9, 0.3, 0.3), (x + radius + 0.6, y + 6.3, z), IRON, "Metal", collide=False))
    # Rope and bucket hanging over the shaft.
    kids.append(part("Rope", (0.14, 2.6, 0.14), (x, y + 5.9, z - 0.2), (120, 104, 78), "Fabric", collide=False))
    kids.append(part("Bucket", (1.5, 1.5, 1.5), (x, y + 3.9, z - 0.2), (118, 80, 48), "WoodPlanks", rot_y(12),
                     collide=False))
    kids.append(part("BucketBand", (1.62, 0.3, 1.62), (x, y + 4.2, z - 0.2), IRON, "Metal", rot_y(12), collide=False))
    # Small pitched roof resting on the posts: eave plates on the post tops, rafters, two slabs.
    pitch, half = 32.0, radius + 1.6
    rise = math.tan(math.radians(pitch)) * half
    slope = half / math.cos(math.radians(pitch))
    eave = post_top
    for side in (-1, 1):
        kids.append(part(f"EavePlate{side}", (0.7, 0.6, half * 2 + 0.6), (x + side * (radius + 0.4), eave + 0.3, z),
                         BEAM, "Wood", collide=False))
        for sgn in (-1, 1):
            kids.append(part(f"Rafter{side}{sgn}", (0.5, 0.5, slope), (x + side * (radius + 0.4), eave + 0.6 + rise / 2,
                                                                       z + sgn * half / 2), BEAM, "Wood",
                             rot_x(pitch * sgn), collide=False))
    kids.append(part("RidgeBeam", (radius * 2 + 1.6, 0.6, 0.6), (x, eave + 0.6 + rise, z), BEAM, "Wood", collide=False))
    for sgn in (-1, 1):
        kids.append(part(f"Roof{sgn}", (radius * 2 + 3, 0.4, slope + 0.4), (x, eave + 1.05 + rise / 2, z + sgn * half / 2),
                         ROOF, "RoofShingles", rot_x(pitch * sgn), collide=False, layer="roof"))
    return model(name, kids)


FLOWER_COLORS = [(232, 92, 96), (244, 206, 76), (236, 236, 240), (176, 108, 220), (255, 150, 70)]
BUNTING_COLORS = [(196, 60, 52), (232, 200, 90), (70, 120, 176), (78, 140, 90), (220, 220, 210)]


def bush(name, x, y, z, rng, scale=1.0):
    kids = []
    for k in range(3):
        d = rng.uniform(2.0, 3.2) * scale
        ox, oz = rng.uniform(-0.9, 0.9) * scale, rng.uniform(-0.9, 0.9) * scale
        kids.append(part(f"Leaf{k}", (d, d * 0.8, d), (x + ox, y + d * 0.36, z + oz), rng.choice(LEAVES), "Grass",
                         rot_y(rng.uniform(0, 90)), shape="Ball", collide=False, query=False, layer="prop"))
    return model(name, kids)


def flower_bed(name, x, y, z, width, depth, yaw, rng):
    """Soil box with a stone edge and a scatter of blooms. Tagged FlowerBed for butterflies."""
    r = rot_y(yaw)
    kids = [part("Soil", (width, 0.7, depth), (x, y + 0.35, z), (74, 52, 36), "Ground", r, collide=False),
            part("Edge", (width + 0.8, 0.5, depth + 0.8), (x, y + 0.22, z), STONE_DARK, "Cobblestone", r, collide=False)]
    # Daisies (petal disc + centre) and tulips (tall cupped bloom), each on a stem with a leaf.
    n = max(6, int(width * depth / 1.6))
    cols, rows = max(1, round(width / 1.1)), max(1, round(depth / 1.1))
    for k in range(n):
        lx = -width / 2 + 0.55 + (k % cols) * (width - 1.1) / max(cols - 1, 1) + rng.uniform(-0.2, 0.2)
        lz = -depth / 2 + 0.5 + ((k // cols) % rows) * (depth - 1.0) / max(rows - 1, 1) + rng.uniform(-0.2, 0.2)
        w = apply(r, (lx, 0, lz))
        fx, fz = x + w[0], z + w[2]
        h = rng.uniform(0.8, 1.4)
        color = rng.choice(FLOWER_COLORS)
        common = dict(collide=False, query=False, shadow=False)
        kids.append(part(f"Stem{k}", (0.14, h, 0.14), (fx, y + 0.7 + h / 2, fz), (70, 120, 50), "Grass", **common))
        kids.append(part(f"Leaf{k}", (0.7, 0.08, 0.3), (fx + 0.3, y + 0.7 + h * 0.45, fz), (86, 138, 58), "Grass",
                         mul(rot_y(rng.uniform(0, 180)), rot_z(20)), **common))
        if k % 3 == 2:  # tulip
            kids.append(part(f"Bloom{k}", (0.5, 0.75, 0.5), (fx, y + 0.7 + h + 0.3, fz), color, "SmoothPlastic",
                             shape="Ball", **common))
        else:  # daisy: flat petal disc tilted slightly toward the sun, dark centre on top
            tilt = mul(rot_y(rng.uniform(0, 360)), rot_x(rng.uniform(8, 22)))
            kids.append(part(f"Petals{k}", (0.08, 0.95, 0.95), (fx, y + 0.7 + h, fz), color, "SmoothPlastic",
                             mul(tilt, rot_z(90)), shape="Cylinder", **common))
            kids.append(part(f"Centre{k}", (0.32, 0.22, 0.32), (fx, y + 0.7 + h + 0.08, fz), (255, 214, 80),
                             "SmoothPlastic", tilt, shape="Ball", **common))
    return model(name, kids, attrs={"FlowerBed": True, "BedX": x, "BedY": y + 2.0, "BedZ": z})


def bench(name, x, y, z, yaw):
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))
    back = apply(r, (0, 0, 1))
    kids = [part("Seat", (5.2, 0.4, 1.6), (x, y + 1.6, z), TIMBER, "WoodPlanks", r),
            part("Back", (5.2, 1.6, 0.35), (x + back[0] * 0.65, y + 2.7, z + back[2] * 0.65), TIMBER, "WoodPlanks",
                 mul(r, rot_x(-8)), collide=False)]
    for side in (-1, 1):
        kids.append(part(f"Leg{side}", (0.5, 1.4, 1.4), (x + right[0] * side * 2.1, y + 0.7, z + right[2] * side * 2.1),
                         IRON, "Metal", r))
    return model(name, kids)


def barrel(name, x, y, z, rng):
    kids = [part("Body", (3.0, 2.6, 2.6), (x, y + 1.5, z), (118, 84, 52), "Wood", rot_z(90), shape="Cylinder")]
    for k, hy in enumerate((0.7, 2.3)):
        kids.append(part(f"Band{k}", (0.25, 2.75, 2.75), (x, y + hy, z), IRON, "Metal", rot_z(90), shape="Cylinder",
                         collide=False))
    return model(name, kids)


def crate_stack(name, x, y, z, rng):
    return model(name, [
        part("Crate0", (3, 3, 3), (x, y + 1.5, z), TIMBER, "WoodPlanks", rot_y(rng.uniform(-8, 8))),
        part("Crate1", (2.4, 2.4, 2.4), (x + 0.3, y + 4.2, z - 0.2), (140, 96, 58), "WoodPlanks",
             rot_y(rng.uniform(10, 30)), collide=False),
        part("Crate2", (2.6, 2.6, 2.6), (x + 3.2, y + 1.3, z + 0.6), (128, 88, 52), "WoodPlanks",
             rot_y(rng.uniform(-20, -5))),
    ])


def woodpile(name, x, y, z, yaw, rng):
    r = rot_y(yaw)
    kids = []
    for row in range(3):
        for k in range(5 - row):
            off = apply(r, ((k - (4 - row) / 2) * 1.05, 0, 0))
            kids.append(part(f"Log{row}{k}", (1.0, 1.0, 3.6), (x + off[0], y + 0.5 + row * 0.9, z + off[2]), TRUNK,
                             "Wood", mul(r, rot_z(rng.uniform(-4, 4))), collide=(row == 0)))
    return model(name, kids)


def hand_cart(name, x, y, z, yaw):
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))
    fwd = apply(r, (0, 0, -1))
    kids = [part("Bed", (4.2, 0.5, 6.0), (x, y + 2.2, z), TIMBER, "WoodPlanks", mul(r, rot_x(-6))),
            part("SideL", (0.3, 1.4, 5.6), (x + right[0] * 2.0, y + 2.9, z + right[2] * 2.0), TIMBER, "WoodPlanks",
                 mul(r, rot_x(-6)), collide=False),
            part("SideR", (0.3, 1.4, 5.6), (x - right[0] * 2.0, y + 2.9, z - right[2] * 2.0), TIMBER, "WoodPlanks",
                 mul(r, rot_x(-6)), collide=False),
            part("Axle", (5.4, 0.35, 0.35), (x, y + 1.8, z), IRON, "Metal", r, collide=False)]
    for side in (-1, 1):
        kids.append(part(f"Wheel{side}", (0.5, 3.6, 3.6), (x + right[0] * side * 2.6, y + 1.8, z + right[2] * side * 2.6),
                         (96, 64, 40), "Wood", r, shape="Cylinder", collide=False))
        kids.append(part(f"Handle{side}", (0.35, 0.35, 4.0), (x + right[0] * side * 1.6 + fwd[0] * 4.4, y + 2.4,
                                                              z + right[2] * side * 1.6 + fwd[2] * 4.4), BEAM, "Wood",
                         mul(r, rot_x(10)), collide=False))
    kids.append(part("Sacks", (3.2, 1.4, 3.6), (x - fwd[0] * 0.4, y + 3.1, z - fwd[2] * 0.4), (190, 168, 120), "Fabric",
                     mul(r, rot_y(6)), collide=False))
    return model(name, kids)


def hay_bale(name, x, y, z, yaw):
    return model(name, [
        part("Bale", (3.2, 2.2, 2.2), (x, y + 1.1, z), (214, 186, 96), "Grass", rot_y(yaw)),
        part("Twine", (3.3, 0.15, 2.3), (x, y + 1.35, z), (120, 92, 60), "Fabric", rot_y(yaw), collide=False),
    ])


def stump(name, x, y, z, rng):
    d = rng.uniform(2.2, 3.0)
    return model(name, [
        part("Stump", (1.4, d, d), (x, y + 0.7, z), TRUNK, "Wood", rot_z(90), shape="Cylinder"),
        part("Rings", (0.12, d * 0.7, d * 0.7), (x, y + 1.42, z), (168, 132, 90), "Wood", rot_z(90), shape="Cylinder",
             collide=False),
        part("MushroomStem", (0.5, 0.6, 0.5), (x + d / 2 + 0.3, y + 0.3, z + 0.4), (230, 220, 200), "SmoothPlastic",
             collide=False, query=False),
        part("MushroomCap", (0.9, 0.35, 0.9), (x + d / 2 + 0.3, y + 0.72, z + 0.4), (200, 70, 60), "SmoothPlastic",
             shape="Ball", collide=False, query=False),
    ])


def fingerpost(name, x, y, z, boards):
    """Signpost with one pointing board per destination. boards: [(text, yaw_deg, height)]."""
    kids = [part("Post", (0.9, 11, 0.9), (x, y + 5.5, z), BEAM, "Wood"),
            part("Finial", (1.3, 1.3, 1.3), (x, y + 11.4, z), GOLD, "Metal", shape="Ball", collide=False)]
    for k, (text, yaw, h) in enumerate(boards):
        r = rot_y(yaw)
        fwd = apply(r, (0, 0, -1))  # the board points along its look vector
        centre = (x + fwd[0] * 3.1, y + h, z + fwd[2] * 3.1)
        kids.append(part(f"Board{k}", (1.4, 1.5, 6.0), centre, (70, 46, 30), "WoodPlanks", r, collide=False,
                         children=[label_gui("Right", text, "", (255, 232, 170), px=50),
                                   label_gui("Left", text, "", (255, 232, 170), px=50)]))
        kids.append(part(f"Point{k}", (1.4, 1.5, 1.4), (x + fwd[0] * 6.4, y + h, z + fwd[2] * 6.4), (70, 46, 30),
                         "WoodPlanks", mul(r, rot_y(45)), collide=False))
    return model(name, kids)


def bunting(name, a, b, y, height, rng, pennants=9):
    """Two poles with a cord between them and triangular pennants hanging from it."""
    ax, az = a
    bx, bz = b
    seg = math.hypot(bx - ax, bz - az)
    dx, dz = (bx - ax) / seg, (bz - az) / seg
    yaw = math.degrees(math.atan2(-dz, dx))
    kids = []
    for k, (px_, pz) in enumerate((a, b)):
        kids.append(part(f"Pole{k}", (0.5, height + 0.6, 0.5), (px_, y + (height + 0.6) / 2, pz), BEAM, "Wood"))
    kids.append(part("Cord", (seg, 0.12, 0.12), ((ax + bx) / 2, y + height, (az + bz) / 2), (60, 50, 40), "Fabric",
                     rot_y(yaw), collide=False, query=False))
    for k in range(pennants):
        t = (k + 0.5) / pennants
        sag = math.sin(t * math.pi) * 0.9
        cx_, cz_ = ax + dx * seg * t, az + dz * seg * t
        kids.append(part(f"Pennant{k}", (1.4, 1.6, 0.08), (cx_, y + height - sag - 0.85, cz_), BUNTING_COLORS[k % 5],
                         "Fabric", mul(rot_y(yaw), rot_x(180)), cls="WedgePart", collide=False, query=False,
                         shadow=False, layer="roof"))
    return model(name, kids, attrs={"Bunting": True})


def forge_set(name, x, y, z, rng):
    """Blacksmith corner: stone forge with fire and chimney, anvil on a stump, hammer, quench barrel."""
    ax, az = x - 5.2, z + 2.2
    kids = [
        part("ForgeBody", (4.4, 3.2, 4.0), (x, y + 1.6, z), STONE_DARK, "Cobblestone"),
        part("ForgeHearth", (3.0, 0.6, 2.6), (x, y + 3.4, z + 0.4), (46, 40, 38), "Slate", collide=False),
        part("ForgeCoals", (2.2, 0.4, 1.8), (x, y + 3.75, z + 0.4), EMBER, "Neon", collide=False, query=False,
             shadow=False, children=[fire(3.5, 9), light(18, 1.5, (255, 140, 70))]),
        part("ForgeHood", (4.0, 0.6, 3.0), (x, y + 7.2, z - 0.4), IRON, "Metal", collide=False),
        part("ForgeStack", (1.8, 5.5, 1.8), (x, y + 10.2, z - 0.9), STONE_DARK, "Cobblestone", collide=False),
        part("ForgeFlue", (1.0, 0.3, 1.0), (x, y + 13.1, z - 0.9), (30, 28, 26), "Slate", collide=False, query=False,
             children=[smoke(4.0, 0.4, 3.5, (120, 116, 112))]),
        part("HoodPostL", (0.4, 3.6, 0.4), (x - 1.8, y + 5.2, z - 1.6), IRON, "Metal", collide=False),
        part("HoodPostR", (0.4, 3.6, 0.4), (x + 1.8, y + 5.2, z - 1.6), IRON, "Metal", collide=False),
        part("Bellows", (2.0, 0.8, 1.4), (x + 2.9, y + 3.0, z), (110, 72, 42), "Wood", rot_y(20), collide=False),
        part("AnvilStump", (1.6, 2.6, 2.6), (ax, y + 0.8, az), TRUNK, "Wood", rot_z(90), shape="Cylinder"),
        part("AnvilBase", (1.4, 0.9, 1.6), (ax, y + 2.05, az), IRON, "Metal", collide=False),
        part("AnvilTop", (3.2, 0.7, 1.3), (ax, y + 2.85, az), (120, 122, 128), "Metal", collide=False),
        part("AnvilHorn", (1.1, 0.5, 0.7), (ax + 2.05, y + 2.95, az), (120, 122, 128), "Metal", rot_z(-10),
             collide=False),
        part("Workpiece", (1.5, 0.22, 0.3), (ax - 0.2, y + 3.3, az), (255, 150, 60), "Neon", collide=False,
             query=False, shadow=False, children=[light(8, 0.7, (255, 140, 60))]),
        # The hammer: HubAmbience swings it about the Hammer* pivot (the smith's hand).
        part("SmithHammerHead", (1.1, 0.7, 0.7), (ax - 0.2, y + 5.6, az - 1.4), IRON, "Metal", collide=False, query=False),
        part("SmithHammerHandle", (0.3, 2.6, 0.3), (ax - 0.2, y + 4.3, az - 1.4), (120, 84, 50), "Wood", collide=False,
             query=False),
        part("QuenchBarrel", (2.6, 2.4, 2.4), (x + 3.6, y + 1.3, z + 3.2), (100, 70, 44), "Wood", rot_z(90),
             shape="Cylinder"),
        part("QuenchWater", (0.2, 2.1, 2.1), (x + 3.6, y + 2.42, z + 3.2), (60, 100, 130), "Glass", rot_z(90),
             shape="Cylinder", collide=False, transparency=0.3),
        part("ToolRack", (0.3, 3.0, 3.0), (x - 2.6, y + 5.0, z - 1.8), BEAM, "Wood", collide=False),
    ]
    for k in range(3):
        kids.append(part(f"Tongs{k}", (0.18, 2.4, 0.18), (x - 2.45, y + 5.0, z - 2.8 + k * 1.0), IRON, "Metal",
                         rot_x(6), collide=False, query=False))
    return model(name, kids, attrs={"Forge": True, "HammerX": ax - 0.2, "HammerY": y + 3.9, "HammerZ": az - 1.4,
                                    "AnvilX": ax - 0.2, "AnvilY": y + 3.35, "AnvilZ": az})


def waterfall(name, cliff_x, y, z, rng, height=34.0, pool_r=7.0):
    """Sheets of falling water down the east cliff face into a stone-rimmed pool. Sheets are
    tagged for HubAmbience, which shimmers them."""
    px_ = cliff_x - pool_r - 1.5
    kids = [
        part("PoolRim", (1.2, (pool_r + 1.2) * 2, (pool_r + 1.2) * 2), (px_, y + 0.5, z), STONE, "Cobblestone",
             rot_z(90), shape="Cylinder"),
        part("PoolWater", (0.6, pool_r * 2, pool_r * 2), (px_, y + 0.85, z), (52, 108, 140), "Glass", rot_z(90),
             shape="Cylinder", collide=False, transparency=0.3, children=[light(14, 0.6, (120, 180, 220))]),
        part("Foam", (0.12, 5.0, 5.0), (cliff_x - 3.6, y + 1.22, z), (230, 240, 245), "SmoothPlastic", rot_z(90),
             shape="Cylinder", collide=False, query=False, shadow=False, transparency=0.35),
        part("Mist", (0.5, 0.5, 0.5), (cliff_x - 2.5, y + 1.6, z), (255, 255, 255), "SmoothPlastic", transparency=1,
             collide=False, query=False, shadow=False, children=[smoke(6.0, 0.18, 1.2, (235, 240, 245))]),
        part("LipRock", (5, 3, 8), (cliff_x + 1.5, y + height + 2.2, z), HUB_ROCK_DARK, "Rock", rot_y(8),
             collide=False),
    ]
    for k in range(3):
        kids.append(part(f"WaterSheet{k}", (0.5, height, 5.2 - k * 0.6), (cliff_x - 0.4 - k * 0.45, y + height / 2 + 1.2, z),
                         (150, 200, 230) if k % 2 == 0 else (190, 225, 240), "Glass", collide=False, query=False,
                         shadow=False, transparency=0.35 + k * 0.1))
    for k in range(6):
        a = math.pi * 0.5 + (k - 2.5) * 0.5
        rx, rz = px_ + math.cos(a) * (pool_r + 1.8), z + math.sin(a) * (pool_r + 1.8)
        kids.append(part(f"PoolRock{k}", (rng.uniform(2, 3.4), rng.uniform(1.2, 2.4), rng.uniform(2, 3)),
                         (rx, y + 0.8, rz), ROCK_GRAY, "Slate", rot_y(rng.uniform(0, 90)), collide=False))
    return model(name, kids, attrs={"Waterfall": True})


def market_stall(name, npc_x, y, cz, rng, canopy=(196, 70, 60)):
    """Smaller cousin of the quest stall: plain awning, counter with crates of produce."""
    x0, x1 = npc_x - 4.0, npc_x + 4.0
    z0, z1 = cz - 5.5, cz + 5.5
    top = y + 8.2
    kids = []
    for px_ in (x0, x1):
        for pz in (z0, z1):
            kids.append(part("Post", (0.8, top - y, 0.8), (px_, y + (top - y) / 2, pz), BEAM, "Wood"))
    kids.append(part("Awning", (x1 - x0 + 3.2, 0.3, z1 - z0 + 2.4), (npc_x - 0.6, top + 0.4, cz), canopy, "Fabric",
                     rot_z(-9), collide=False, layer="roof"))
    for k in range(6):
        zk = z0 - 1.2 + (z1 - z0 + 2.4) * (k + 0.5) / 6
        kids.append(part(f"Scallop{k}", (0.12, 0.9, (z1 - z0 + 2.4) / 6 - 0.1), (x0 - 2.1, top - 0.35, zk),
                         canopy if k % 2 else (236, 226, 200), "Fabric", collide=False, layer="roof"))
    cx0, cx1 = x0 - 0.3, x0 + 2.2
    kids.append(box("CounterTop", cx0 - 0.3, cx1 + 0.2, y + 3.0, y + 3.35, z0 + 0.5, z1 - 0.5, TIMBER, "WoodPlanks"))
    kids.append(box("CounterFront", cx0 - 0.15, cx0 + 0.15, y, y + 3.0, z0 + 0.7, z1 - 0.7, (104, 68, 40), "WoodPlanks"))
    for k, color in enumerate(((200, 50, 50), (240, 150, 50), (120, 170, 60))):
        zk = z0 + 1.8 + k * 3.4
        kids.append(part(f"Crate{k}", (2.4, 1.2, 2.6), (x0 + 1.0, y + 3.95, zk), (128, 88, 52), "WoodPlanks", collide=False))
        for j in range(5):
            kids.append(part(f"Fruit{k}{j}", (0.7, 0.7, 0.7), (x0 + 0.5 + (j % 3) * 0.5, y + 4.9 + (j // 3) * 0.4,
                                                                 zk - 0.8 + (j % 2) * 0.8 + (j // 3) * 0.3), color,
                             "SmoothPlastic", shape="Ball", collide=False, query=False, shadow=False))
    kids.append(part("Sacks", (2.2, 1.6, 2.2), (x1 - 1.2, y + 0.8, z1 - 1.6), (190, 168, 120), "Fabric", rot_y(12)))
    kids.append(part("Basket", (1.6, 1.0, 1.6), (x1 - 1.4, y + 0.5, z0 + 1.6), (150, 110, 60), "Wood", rot_z(90),
                     shape="Cylinder", collide=False))
    return model(name, kids, attrs={"Vendor": True, "VendorX": npc_x + 1.2, "VendorY": y, "VendorZ": cz})


SLATE_ROOF = (72, 72, 80)
STONE_WALL = (118, 112, 104)
STONE_WALL_DARK = (94, 88, 82)


def smithy(name, x0, x1, z0, z1, y, rng):
    """The Relic Blacksmith's workshop: thick stone walls, open timber-framed front, a low slate
    roof with a big chimney, and the forge, anvil, quench trough and racks inside where they can
    be seen. The merchant stands behind the counter across the opening; HubAmbience walks him to
    the anvil (AnvilStand*) to hammer between customers.
    """
    wall_h, t = 12.0, 1.4
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    top = y + wall_h
    ox0, ox1 = cx - 8.0, cx + 8.0  # front opening
    kids = [box("Paving", x0 - 1.5, x1 + 1.5, y, y + 0.2, z0 - 1.5, z1 + 2.0, STONE_DARK, "Cobblestone", layer="prop")]
    # Walls: back and front (with the opening), sides inset between them so no tops overlap.
    kids.append(box("WallN", x0, x1, y, top, z0, z0 + t, STONE_WALL, "Cobblestone"))
    kids.append(box("WallSL", x0, ox0 - 1.2, y, top, z1 - t, z1, STONE_WALL, "Cobblestone"))
    kids.append(box("WallSR", ox1 + 1.2, x1, y, top, z1 - t, z1, STONE_WALL, "Cobblestone"))
    kids.append(box("WallW", x0, x0 + t, y, top, z0 + t, z1 - t, STONE_WALL, "Cobblestone"))
    kids.append(box("WallE", x1 - t, x1, y, top, z0 + t, z1 - t, STONE_WALL, "Cobblestone"))
    for k in range(6):  # darker courses break up the stone
        zz = z0 + t + 0.02 if k % 2 else z1 - t - 0.02
        kids.append(box(f"Course{k}", x0 + 2 + k * 5.5, x0 + 5.5 + k * 5.5, y + 2 + (k % 3) * 3.2, y + 3.2 + (k % 3) * 3.2,
                        z0 - 0.1, z0 + 0.1, STONE_WALL_DARK, "Cobblestone", collide=False))
    # Timber front frame around the opening and a heavy lintel.
    for px_ in (ox0 - 0.6, ox1 + 0.6):
        kids.append(box("FramePost", px_ - 0.7, px_ + 0.7, y, top - 2.4, z1 - t - 0.3, z1 + 0.3, BEAM, "Wood"))
    kids.append(box("Lintel", ox0 - 1.6, ox1 + 1.6, top - 2.4, top - 0.8, z1 - t - 0.35, z1 + 0.35, BEAM, "Wood"))
    kids.append(box("LintelBrace", ox0 - 1.2, ox1 + 1.2, top - 0.8, top + 0.6, z1 - t - 0.3, z1 + 0.3, STONE_WALL_DARK,
                    "Cobblestone", collide=False))
    # Barred windows on the side walls with a warm glow inside.
    for side, wx in (("W", x0 - 0.2), ("E", x1 + 0.2)):
        for wi, wz in enumerate((z0 + 9, z1 - 9)):
            kids.append(part(f"Window{side}{wi}", (0.4, 2.8, 2.8), (wx, y + 7.2, wz), (28, 26, 24), "Slate", collide=False,
                             children=[light(9, 0.9, (255, 170, 90))]))
            for b in (-0.7, 0, 0.7):
                kids.append(part(f"Bar{side}{wi}", (0.5, 3.0, 0.18), (wx, y + 7.2, wz + b), IRON, "Metal", collide=False))
            kids.append(part(f"Sill{side}{wi}", (0.9, 0.3, 3.4), (wx, y + 5.7, wz), STONE_WALL_DARK, "Cobblestone", collide=False))
    # Low slate roof, ridge along X, stone gables, big overhang.
    pitch, overhang = 22.0, 2.4
    span_z = z1 - z0
    half = span_z / 2 + overhang
    rise = math.tan(math.radians(pitch)) * (span_z / 2)
    slope = half / math.cos(math.radians(pitch))
    for sgn, label in ((-1, "N"), (1, "S")):
        kids.append(part(f"Roof{label}", (x1 - x0 + overhang * 2, 0.7, slope), (cx, top + math.tan(math.radians(pitch)) * (span_z / 4 - overhang / 2),
                                                                             cz + sgn * half / 2), SLATE_ROOF, "Slate",
                         rot_x(pitch * sgn), collide=False, layer="roof"))
        kids.append(part(f"Eave{label}", (x1 - x0 + overhang * 2 + 0.4, 0.5, 0.5), (cx, top - 0.35, cz + sgn * (span_z / 2 + overhang - 0.2)),
                         BEAM, "Wood", collide=False, layer="roof"))
    kids.append(part("Ridge", (x1 - x0 + overhang * 2 + 0.6, 0.6, 0.9), (cx, top + rise + 0.3, cz), STONE_WALL_DARK, "Slate",
                     collide=False, layer="roof"))
    for gx in (x0 + 0.7, x1 - 0.7):
        for sgn, yaw in ((-1, 0), (1, 180)):
            kids.append(part(f"Gable{'N' if sgn < 0 else 'S'}", (1.4, rise, span_z / 2), (gx, top + rise / 2, cz + sgn * span_z / 4),
                             STONE_WALL, "Cobblestone", rot_y(yaw), cls="WedgePart", collide=False, layer="roof"))
    # Hearth against the back wall, its stack rising into the chimney through the roof.
    hx, hz = cx + 11, z0 + 4.2
    kids += [
        box("HearthBase", hx - 3.2, hx + 3.2, y + 0.2, y + 3.6, hz - 2.4, hz + 2.4, STONE_WALL_DARK, "Cobblestone"),
        box("HearthBack", hx - 3.2, hx + 3.2, y + 3.6, y + 9.0, hz - 2.4, hz - 0.8, STONE_WALL_DARK, "Cobblestone", collide=False),
        part("Coals", (4.4, 0.5, 2.6), (hx, y + 3.85, hz + 0.5), EMBER, "Neon", collide=False, query=False, shadow=False,
             children=[fire(5, 10), light(22, 1.8, (255, 140, 70))]),
        part("Hood", (6.0, 0.8, 4.6), (hx, y + 9.2, hz + 0.6), IRON, "Metal", collide=False),
        part("HoodFront", (6.0, 2.2, 0.4), (hx, y + 7.9, hz + 2.7), IRON, "Metal", collide=False),
        part("Stack", (3.2, top + rise + 5 - (y + 9.6), 3.2), (hx, (y + 9.6 + top + rise + 5) / 2, hz - 0.6), STONE_WALL_DARK,
             "Cobblestone", collide=False),
        part("StackCap", (4.0, 0.7, 4.0), (hx, top + rise + 5.35, hz - 0.6), STONE_WALL, "Slate", collide=False),
        part("StackFlue", (1.6, 0.3, 1.6), (hx, top + rise + 5.8, hz - 0.6), (30, 28, 26), "Slate", collide=False, query=False,
             children=[smoke(5.0, 0.45, 4.0, (110, 106, 102))]),
        part("Bellows", (2.6, 1.0, 1.8), (hx - 4.6, y + 2.8, hz + 0.4), (110, 72, 42), "Wood", rot_y(-20), collide=False),
        part("BellowsHandle", (0.3, 0.3, 2.4), (hx - 5.8, y + 3.4, hz + 1.2), BEAM, "Wood", rot_y(-20), collide=False),
    ]
    # Anvil on a stump mid-room, where the smith works.
    ax, az = cx + 3, cz + 4
    kids += [
        part("AnvilStump", (2.0, 3.0, 3.0), (ax, y + 1.2, az), TRUNK, "Wood", rot_z(90), shape="Cylinder"),
        part("AnvilBase", (1.5, 1.0, 1.8), (ax, y + 2.7, az), IRON, "Metal", collide=False),
        part("AnvilTop", (3.6, 0.8, 1.5), (ax, y + 3.6, az), (120, 122, 128), "Metal", collide=False),
        part("AnvilHorn", (1.3, 0.55, 0.8), (ax + 2.35, y + 3.7, az), (120, 122, 128), "Metal", rot_z(-12), collide=False),
        part("Workpiece", (1.6, 0.24, 0.32), (ax - 0.3, y + 4.12, az), (255, 150, 60), "Neon", collide=False, query=False,
             shadow=False, children=[light(8, 0.7, (255, 140, 60))]),
    ]
    # Quench trough along the east wall, workbench and racks along the west wall, tools on the back wall.
    kids += [
        box("Trough", x1 - t - 2.6, x1 - t - 0.4, y + 0.2, y + 2.4, cz - 4, cz + 4, (100, 70, 44), "WoodPlanks"),
        box("TroughWater", x1 - t - 2.4, x1 - t - 0.6, y + 1.9, y + 2.25, cz - 3.8, cz + 3.8, (60, 100, 130), "Glass",
            collide=False, transparency=0.3),
        box("Bench", x0 + t + 0.4, x0 + t + 3.2, y + 2.6, y + 3.0, z0 + 5, z0 + 13, TIMBER, "WoodPlanks"),
        box("BenchLegA", x0 + t + 0.6, x0 + t + 1.0, y + 0.2, y + 2.6, z0 + 5.3, z0 + 5.7, BEAM, "Wood", collide=False),
        box("BenchLegB", x0 + t + 0.6, x0 + t + 1.0, y + 0.2, y + 2.6, z0 + 12.3, z0 + 12.7, BEAM, "Wood", collide=False),
        part("Vise", (1.0, 1.0, 1.4), (x0 + t + 2.4, y + 3.5, z0 + 7), IRON, "Metal", collide=False),
        box("RackBoard", x0 + t, x0 + t + 0.4, y + 3.0, y + 8.6, z1 - 12, z1 - 3, BEAM, "Wood", collide=False),
    ]
    for k in range(5):  # finished blades hanging on the rack
        zz = z1 - 11 + k * 1.8
        kids.append(part(f"RackBlade{k}", (0.25, 4.0, 0.7), (x0 + t + 0.55, y + 5.4, zz), (200, 204, 210), "Metal",
                         rot_x(rng.uniform(-3, 3)), collide=False))
        kids.append(part(f"RackHilt{k}", (0.35, 0.9, 0.35), (x0 + t + 0.55, y + 7.8, zz), (84, 52, 36), "Fabric", collide=False))
        kids.append(part(f"RackGuard{k}", (0.3, 0.25, 1.3), (x0 + t + 0.55, y + 7.35, zz), GOLD, "Metal", collide=False))
    for k, (dz, kind) in enumerate(((-11, "tongs"), (-9.2, "hammer"), (-7.4, "tongs"), (-5.6, "hammer"))):
        px_, pz = cx + dz, z0 + t + 0.4
        if kind == "tongs":
            kids.append(part(f"Tool{k}", (0.22, 2.8, 0.22), (px_, y + 7.0, pz), IRON, "Metal", rot_z(6), collide=False))
            kids.append(part(f"ToolB{k}", (0.22, 2.8, 0.22), (px_ + 0.35, y + 7.0, pz), IRON, "Metal", rot_z(-6), collide=False))
        else:
            kids.append(part(f"Tool{k}", (0.3, 2.4, 0.3), (px_, y + 6.8, pz), (120, 84, 50), "Wood", collide=False))
            kids.append(part(f"ToolB{k}", (1.0, 0.5, 0.5), (px_, y + 8.1, pz), IRON, "Metal", collide=False))
    kids.append(box("ToolBoard", cx - 12.2, cx - 4.4, y + 5.2, y + 8.8, z0 + t, z0 + t + 0.25, BEAM, "Wood", collide=False))
    # Counter across the opening with two display blades; the merchant stands behind it.
    kz = z1 - 0.9
    kids.append(box("CounterTop", ox0 - 0.4, ox1 + 0.4, y + 3.3, y + 3.7, kz - 1.3, kz + 1.0, TIMBER, "WoodPlanks"))
    kids.append(box("CounterFront", ox0 - 0.2, ox1 + 0.2, y + 0.2, y + 3.3, kz + 0.6, kz + 1.0, (104, 68, 40), "WoodPlanks"))
    kids.append(box("CounterBack", ox0 - 0.2, ox1 + 0.2, y + 0.2, y + 3.3, kz - 1.3, kz - 0.9, (104, 68, 40), "WoodPlanks",
                    collide=False))
    for k, dx in enumerate((-4.5, 4.5)):
        kids.append(part(f"DisplayBlade{k}", (3.8, 0.2, 0.7), (cx + dx, y + 3.85, kz - 0.2), (200, 204, 210), "Metal",
                         rot_y(12 * (1 if k else -1)), collide=False))
        kids.append(part(f"DisplayGuard{k}", (0.3, 0.3, 1.3), (cx + dx - 2.0 * (1 if k else -1), y + 3.85, kz - 0.2), GOLD, "Metal",
                         rot_y(12 * (1 if k else -1)), collide=False))
    # Hanging shop sign on a bracket at the front corner.
    bx_ = x1 + 0.6
    kids.append(part("SignBracket", (3.2, 0.4, 0.4), (bx_ + 1.4, y + 9.6, z1 - 3), IRON, "Metal", collide=False))
    kids.append(part("SignChainA", (0.12, 1.2, 0.12), (bx_ + 1.4, y + 8.9, z1 - 2.2), IRON, "Metal", collide=False))
    kids.append(part("SignChainB", (0.12, 1.2, 0.12), (bx_ + 1.4, y + 8.9, z1 - 3.8), IRON, "Metal", collide=False))
    kids.append(part("SignBoard", (0.35, 2.6, 3.4), (bx_ + 1.4, y + 7.0, z1 - 3), (58, 38, 26), "WoodPlanks", collide=False,
                     children=[label_gui("Right", "Sword Shop", "Relic blades", (255, 232, 170), px=50),
                               label_gui("Left", "Sword Shop", "Relic blades", (255, 232, 170), px=50)]))
    kids.append(part("SignAnvilIcon", (0.5, 0.6, 1.3), (bx_ + 1.4, y + 5.2, z1 - 3), IRON, "Metal", collide=False))
    # Outside: coal heap, ingot stack, water bucket.
    for k in range(5):
        kids.append(part(f"Coal{k}", (rng.uniform(1.2, 2.0), rng.uniform(0.8, 1.3), rng.uniform(1.2, 2.0)),
                         (x1 + 3.5 + rng.uniform(-1, 1), y + 0.5 + k * 0.12, z0 + 6 + rng.uniform(-1.5, 1.5)), (36, 34, 34),
                         "Slate", mul(rot_y(rng.uniform(0, 90)), rot_z(rng.uniform(-8, 8))), collide=False))
    for k in range(6):
        kids.append(part(f"Ingot{k}", (2.2, 0.5, 0.9), (x1 + 3.5 + (k % 2) * 1.0 - 0.5, y + 0.45 + (k // 2) * 0.5, z0 + 12 + (k // 2) * 0.1),
                         (150, 152, 158), "Metal", rot_y((k // 2) * 90), collide=False))
    return model(name, kids, attrs={"Forge": True, "Smithy": True, "AnvilX": ax - 0.3, "AnvilY": y + 4.1, "AnvilZ": az,
                                    "AnvilStandX": ax - 3.0, "AnvilStandY": y + 0.2, "AnvilStandZ": az,
                                    "CounterX": cx, "CounterY": y + 0.2, "CounterZ": kz - 3.4})


def chest(name, x, y, z, yaw, open_lid=False, rng=None):
    """Iron-banded wooden chest; an open one shows sword hilts standing in it."""
    r = rot_y(yaw)
    kids = [part("Body", (3.4, 1.8, 2.2), (x, y + 0.9, z), (110, 72, 42), "WoodPlanks", r),
            part("BandL", (0.25, 1.9, 2.3), (x + apply(r, (-1.0, 0, 0))[0], y + 0.9, z + apply(r, (-1.0, 0, 0))[2]), IRON, "Metal", r, collide=False),
            part("BandR", (0.25, 1.9, 2.3), (x + apply(r, (1.0, 0, 0))[0], y + 0.9, z + apply(r, (1.0, 0, 0))[2]), IRON, "Metal", r, collide=False),
            part("Lock", (0.5, 0.6, 0.2), (x + apply(r, (0, 0, -1.15))[0], y + 1.1, z + apply(r, (0, 0, -1.15))[2]), GOLD, "Metal", r, collide=False)]
    if open_lid:
        back = apply(r, (0, 0, 1.0))
        kids.append(part("Lid", (3.5, 0.5, 2.3), (x + back[0], y + 2.9, z + back[2]), (96, 62, 36), "WoodPlanks",
                         mul(r, rot_x(-100)), collide=False))
        for k in range(3):
            off = apply(r, ((k - 1) * 0.9, 0, 0.1))
            kids.append(part(f"Hilt{k}", (0.3, 1.3, 0.3), (x + off[0], y + 2.3, z + off[2]), (84, 52, 36), "Fabric",
                             mul(r, rot_z((k - 1) * 8)), collide=False))
            kids.append(part(f"Guard{k}", (1.0, 0.22, 0.3), (x + off[0], y + 1.75, z + off[2]), GOLD, "Metal",
                             mul(r, rot_z((k - 1) * 8)), collide=False))
            kids.append(part(f"Pommel{k}", (0.45, 0.45, 0.45), (x + off[0], y + 3.0, z + off[2]), GOLD, "Metal",
                             shape="Ball", collide=False))
    else:
        kids.append(part("Lid", (3.5, 0.5, 2.3), (x, y + 2.05, z), (96, 62, 36), "WoodPlanks", r, collide=False))
    return model(name, kids)


def storage_shack(name, x0, x1, z0, z1, y, rng):
    """The Vaultkeeper's shack: stacked-log walls on a stone base, plank roof, open doorway on
    the south side, chests and shelves inside. Attribute VaultShack marks it for docs/tools.
    """
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    wall_h = 9.0
    base_top = y + 0.4
    kids = [box("Base", x0 - 0.8, x1 + 0.8, y, base_top, z0 - 0.8, z1 + 0.8, STONE_DARK, "Cobblestone"),
            box("Floor", x0 + 0.6, x1 - 0.6, base_top, base_top + 0.12, z0 + 0.6, z1 - 0.6, (150, 112, 70), "WoodPlanks", collide=False)]
    # Log walls: horizontal cylinders stacked; the south wall leaves a doorway.
    logs = int(wall_h / 1.15)
    door_w = 5.0
    for k in range(logs):
        ly = base_top + 0.575 + k * 1.15
        shade = TRUNK if k % 2 else (86, 58, 36)
        kids.append(part(f"LogN{k}", (x1 - x0 + 1.2, 1.15, 1.15), (cx, ly, z0), shade, "Wood", collide=(k < 3)))
        kids.append(part(f"LogW{k}", (1.15, 1.15, z1 - z0 + 1.2), (x0, ly, cz), shade, "Wood", collide=(k < 3)))
        kids.append(part(f"LogE{k}", (1.15, 1.15, z1 - z0 + 1.2), (x1, ly, cz), shade, "Wood", collide=(k < 3)))
        if k >= 7:  # above the doorway the south logs run full width
            kids.append(part(f"LogS{k}", (x1 - x0 + 1.2, 1.15, 1.15), (cx, ly, z1), shade, "Wood", collide=False))
        else:
            kids.append(part(f"LogSL{k}", (cx - door_w / 2 - x0 + 0.6, 1.15, 1.15), ((x0 - 0.6 + cx - door_w / 2) / 2, ly, z1),
                             shade, "Wood", collide=(k < 3)))
            kids.append(part(f"LogSR{k}", (x1 + 0.6 - cx - door_w / 2, 1.15, 1.15), ((cx + door_w / 2 + x1 + 0.6) / 2, ly, z1),
                             shade, "Wood", collide=(k < 3)))
    # Invisible wall proxies so the round logs feel solid.
    top = base_top + logs * 1.15
    for label, (a0, a1, b0, b1) in (("N", (x0 - 0.6, x1 + 0.6, z0 - 0.6, z0 + 0.6)), ("W", (x0 - 0.6, x0 + 0.6, z0, z1)),
                                    ("E", (x1 - 0.6, x1 + 0.6, z0, z1))):
        kids.append(box(f"Proxy{label}", a0, a1, base_top, top, b0, b1, (255, 0, 255), transparency=1, query=False, shadow=False))
    kids.append(box("ProxySL", x0 - 0.6, cx - door_w / 2, base_top, top, z1 - 0.6, z1 + 0.6, (255, 0, 255), transparency=1, query=False, shadow=False))
    kids.append(box("ProxySR", cx + door_w / 2, x1 + 0.6, base_top, top, z1 - 0.6, z1 + 0.6, (255, 0, 255), transparency=1, query=False, shadow=False))
    for px_ in (cx - door_w / 2 - 0.5, cx + door_w / 2 + 0.5):
        kids.append(box("DoorPost", px_ - 0.5, px_ + 0.5, base_top, base_top + 7 * 1.15, z1 - 0.7, z1 + 0.7, BEAM, "Wood"))
    kids.append(box("DoorLintel", cx - door_w / 2 - 1.0, cx + door_w / 2 + 1.0, base_top + 7 * 1.15, base_top + 7 * 1.15 + 0.8,
                    z1 - 0.7, z1 + 0.7, BEAM, "Wood", collide=False))
    # Plank roof: two slabs meeting at a ridge along X, plus a rear chimney-less cap.
    pitch, overhang = 26.0, 1.8
    span_z = z1 - z0
    half = span_z / 2 + overhang
    rise = math.tan(math.radians(pitch)) * (span_z / 2)
    slope = half / math.cos(math.radians(pitch))
    for sgn, label in ((-1, "N"), (1, "S")):
        kids.append(part(f"Roof{label}", (x1 - x0 + overhang * 2, 0.6, slope), (cx, top + math.tan(math.radians(pitch)) * (span_z / 4 - overhang / 2),
                                                                             cz + sgn * half / 2), (98, 66, 44), "WoodPlanks",
                         rot_x(pitch * sgn), collide=False, layer="roof"))
    kids.append(part("RoofRidge", (x1 - x0 + overhang * 2 + 0.4, 0.5, 0.8), (cx, top + rise + 0.25, cz), BEAM, "Wood",
                     collide=False, layer="roof"))
    for gx in (x0 + 0.5, x1 - 0.5):
        for sgn, yaw in ((-1, 0), (1, 180)):
            kids.append(part(f"Gable{'N' if sgn < 0 else 'S'}", (1.1, rise, span_z / 2), (gx, top + rise / 2, cz + sgn * span_z / 4),
                             (86, 58, 36), "Wood", rot_y(yaw), cls="WedgePart", collide=False, layer="roof"))
    # Inside: chests along the back and side walls, one open; shelves with crates and sacks.
    fl = base_top + 0.12
    kids.append(chest("ChestOpen", cx - 4.2, fl, z0 + 2.4, 0, open_lid=True))
    kids.append(chest("Chest1", cx, fl, z0 + 2.4, 0))
    kids.append(chest("Chest2", cx + 4.2, fl, z0 + 2.4, 0))
    kids.append(chest("Chest3", x0 + 2.4, fl, cz + 1.0, 90))
    kids.append(chest("Chest4", x0 + 2.4, fl, cz + 4.4, 90))
    kids.append(box("Shelf1", x1 - 2.6, x1 - 1.0, fl + 3.2, fl + 3.5, z0 + 1.2, z1 - 1.2, BEAM, "Wood", collide=False))
    kids.append(box("Shelf2", x1 - 2.6, x1 - 1.0, fl + 6.0, fl + 6.3, z0 + 1.2, z1 - 1.2, BEAM, "Wood", collide=False))
    for k, zz in enumerate((z0 + 2.4, z0 + 5.4, z1 - 3.0)):
        kids.append(part(f"ShelfCrate{k}", (1.4, 1.4, 1.4), (x1 - 1.8, fl + 4.2, zz), TIMBER, "WoodPlanks", rot_y(k * 17), collide=False))
    kids.append(part("ShelfSack", (1.5, 1.2, 1.5), (x1 - 1.8, fl + 6.9, cz), (190, 168, 120), "Fabric", collide=False))
    kids.append(part("ShelfJar", (0.6, 0.9, 0.6), (x1 - 1.8, fl + 6.75, z0 + 2.4), (120, 150, 170), "Glass", rot_z(90),
                     shape="Cylinder", collide=False, transparency=0.3))
    # Keeper's desk by the door with a ledger and lantern.
    kids.append(box("Desk", cx + 1.4, cx + 5.0, fl + 2.5, fl + 2.8, z1 - 5.2, z1 - 3.2, TIMBER, "WoodPlanks"))
    for dx, dz in ((cx + 1.7, z1 - 5.0), (cx + 4.7, z1 - 5.0), (cx + 1.7, z1 - 3.4), (cx + 4.7, z1 - 3.4)):
        kids.append(part("DeskLeg", (0.3, 2.5, 0.3), (dx, fl + 1.25, dz), BEAM, "Wood", collide=False))
    kids.append(part("Ledger", (1.4, 0.25, 1.0), (cx + 3.2, fl + 2.95, z1 - 4.2), (90, 50, 40), "Fabric", rot_y(-12), collide=False))
    kids.append(part("DeskLantern", (0.9, 1.2, 0.9), (cx + 4.4, fl + 3.4, z1 - 3.6), LANTERN, "Neon", collide=False, query=False,
                     shadow=False, transparency=0.15, children=[light(14, 1.0)]))
    # Hanging sign by the door.
    kids.append(part("SignBracket", (0.3, 0.3, 2.6), (cx + door_w / 2 + 1.6, base_top + 7.4, z1 + 1.0), IRON, "Metal", collide=False))
    kids.append(part("SignBoard", (2.8, 1.6, 0.3), (cx + door_w / 2 + 1.6, base_top + 6.2, z1 + 2.0), (58, 38, 26), "WoodPlanks",
                     collide=False, children=[label_gui("Front", "Vault", "", (255, 232, 170), px=60),
                                              label_gui("Back", "Vault", "", (255, 232, 170), px=60)]))
    kids.append(lamp_post("DoorLamp", cx - door_w / 2 - 2.4, y, z1 + 2.6, yaw_facing(1, 0)))
    return model(name, kids, attrs={"VaultShack": True, "InsideX": cx - 1.0, "InsideY": fl, "InsideZ": z1 - 6.0})


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


def waystone(name, waypoint_id, x, y, z, glow=(120, 210, 240)):
    """Giant crystal waystone: a glowing shard cluster on a rough stone base.

    The tallest shard is named Core: MapTravel puts the travel prompt on it, and HubAmbience
    slowly turns the FloatShard pieces around the cluster.
    """
    rng = random.Random(hash(waypoint_id) & 0xFFFF)
    kids = [part("Base", (1.6, 7.6, 7.6), (x, y + 0.8, z), STONE_DARK, "Slate", rot_z(90), shape="Cylinder")]
    shards = [("Core", 11.0, 2.1, 0.0, 0.0, 6.0), ("Shard1", 7.0, 1.5, -2.2, 1.4, 13.0),
              ("Shard2", 5.4, 1.2, 1.9, -1.7, -15.0), ("Shard3", 3.6, 1.0, 0.6, 2.6, 20.0)]
    for label, height, width, dx, dz, tilt in shards:
        yaw = rng.uniform(0, 90)
        rot = mul(rot_y(yaw), rot_z(tilt))
        up = apply(rot, (0, 1, 0))
        base = (x + dx, y + 1.4, z + dz)
        centre = tuple(base[i] + up[i] * height / 2 for i in range(3))
        tip = tuple(base[i] + up[i] * (height + width * 0.45) for i in range(3))
        kids.append(part(label, (width, height, width), centre, glow, "Glass", rot, collide=(label == "Core"),
                         query=(label == "Core"), transparency=0.35))
        kids.append(part(label + "Core", (width * 0.42, height * 0.94, width * 0.42), centre, (210, 250, 255), "Neon",
                         rot, collide=False, query=False, shadow=False, transparency=0.25,
                         children=[light(22, 1.1, glow)] if label == "Core" else None))
        kids.append(part(label + "Tip", (width * 0.72, width * 0.72, width * 0.72), tip, glow, "Glass",
                         mul(rot, mul(rot_x(45), rot_z(45))), collide=False, query=False, transparency=0.3))
    kids.append(part("PromptAnchor", (4, 5, 4), (x, y + 2.5, z), (255, 0, 255), "SmoothPlastic", collide=False,
                     query=False, shadow=False, transparency=1))
    for k in range(3):  # slow-turning splinters, animated by HubAmbience
        a = math.tau * k / 3
        kids.append(part(f"FloatShard{k}", (0.5, 1.6, 0.5), (x + math.cos(a) * 3.4, y + 5 + k * 1.4, z + math.sin(a) * 3.4),
                         (200, 245, 255), "Neon", mul(rot_y(20 * k), rot_z(25)), collide=False, query=False,
                         shadow=False, transparency=0.35))
    return model(name, kids, attrs={"Waystone": True, "WaypointId": waypoint_id, "OrbitX": x, "OrbitY": y + 6.5,
                                    "OrbitZ": z})


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
        marker("Merchant", (-63, HUB_Y + 0.2, -24.6), yaw_facing(0, 1)),
        marker("SkillTrainer", (58, HUB_Y, -12), yaw_facing(0, 1)),
        marker("RebirthKeeper", (64, HUB_Y, 22), yaw_facing(0, -1)),
        marker("Vaultkeeper", (30, HUB_Y + 0.52, -84), yaw_facing(0, 1)),
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
    g = 19.5  # gate half-width 12 + pillar 7 + clearance: the wall meets the pillar's outer face
    segments = [
        ((-100, -100), (-g, -100), -1), ((g, -100), (100, -100), -1),   # north (play area to +Z)
        ((100, -100), (100, -g), -1), ((100, g), (100, 100), -1),       # east
        ((100, 100), (g, 100), -1), ((-g, 100), (-100, 100), -1),       # south
        ((-100, 100), (-100, g), -1), ((-100, -g), (-100, -100), -1),   # west
    ]
    for i, (a, b, inward) in enumerate(segments):
        chunks, proxy = cliff_run(f"HubCliff{i}", a, b, inward, HUB_Y, wall_h, HUB_ROCK, HUB_ROCK_DARK, rng,
                                  depth=16, material="Rock")
        visual += chunks
        proxies.append(proxy)
    for cx, cz in ((-100, -100), (100, -100), (100, 100), (-100, 100)):
        visual.append(part("CornerBastion", (18, wall_h + 8, 18), (cx, HUB_Y + (wall_h + 8) / 2 - 1, cz),
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
    for k in range(8):  # rune ring
        a = math.tau * k / 8
        visual.append(part(f"SpawnRune{k}", (1.0, 0.12, 1.0), (math.cos(a) * 5.0, HUB_Y + 0.56, -40 + math.sin(a) * 5.0),
                           (140, 220, 240), "Neon", rot_y(45 + math.degrees(a)), collide=False, query=False, shadow=False,
                           transparency=0.2))

    visual.append(sign("TravelBoard", -16, HUB_Y, -44, yaw_facing(1, 0), 7, 5, "Travel", "Waystones you have found"))
    visual.append(waystone("HubWaystone", "HubSpawn", -16, HUB_Y, -36))

    # The smithy (west): stone workshop with an open front; forge, anvil and racks inside.
    visual.append(smithy("Smithy", -82, -44, -50, -20, HUB_Y, rng))

    # Skill trainer (east): fenced yard with dummies and a hut.
    visual.append(timber_house("TrainerHut", 70, 88, -50, -36, HUB_Y, 10, "W", rng, door_w=5, roof_color=(84, 70, 60), door=True))
    visual.append(fence_run("TrainingFenceN", (42, -50), (70, -50), road))
    visual.append(fence_run("TrainingFenceW", (42, -49.5), (42, -10), road, gap=(26, 40), skip_first_post=True))
    visual.append(fence_run("TrainingFenceE", (88, -36), (88, -10), road))
    for k, (x, z) in enumerate(((52, -40), (60, -30), (68, -22), (76, -28))):
        visual.append(model(f"Dummy{k}", [
            part("Post", (0.8, 6, 0.8), (x, HUB_Y + 3, z), BEAM, "Wood", collide=False),
            part("Body", (2.4, 3, 1.4), (x, HUB_Y + 4.4, z), (196, 170, 100), "Sand", collide=False),
            part("Arms", (5, 0.6, 0.6), (x, HUB_Y + 5.2, z), BEAM, "Wood", collide=False),
        ], attrs={"TrainingDummy": True}))  # HubAmbience: the Skill Trainer practises on these
    visual.append(sign("TrainerSign", 50, HUB_Y, -10.5, 180, 10, 3.6, "Skill Trainer", "Reset your skill points"))

    # Rebirth shrine (south-east): octagonal dais, pillars, a pale floating crystal.
    visual += disc("ShrineDais", 64, 40, 15, HUB_Y + 1.2, 1.2, STONE, "Marble", layer="prop")
    visual += disc("ShrineInner", 64, 40, 9, HUB_Y + 2.2, 1.0, (200, 196, 186), "Marble", layer="prop")
    for k in range(4):
        a = math.radians(45 + 90 * k)
        px, pz = 64 + math.cos(a) * 12, 40 + math.sin(a) * 12
        visual.append(part(f"ShrinePillar{k}", (2.4, 14, 2.4), (px, HUB_Y + 1.2 + 7, pz), (220, 216, 204), "Marble"))
        visual.append(part(f"ShrineCap{k}", (3.4, 1, 3.4), (px, HUB_Y + 15.7, pz), GOLD, "Metal", collide=False))
    visual.append(hologram_sword("RebirthHologram", 64, HUB_Y + 2.2, 40))
    visual.append(sign("ShrineSign", 76, HUB_Y, 22, yaw_facing(0, -1), 10, 3.6, "Rebirth Shrine", "Begin again, stronger"))

    # Quest court beside the route out: the Quest Master's market stall, open toward the road.
    visual.append(quest_stall("QuestStall", 14, HUB_Y + 0.2, 50))

    # Houses and dressing (north-west, south-west).
    visual.append(timber_house("HouseNW1", -86, -60, -90, -70, HUB_Y, 11, "S", rng, door=True))
    visual.append(timber_house("HouseNW2", -48, -26, -88, -68, HUB_Y, 10, "S", rng, wall_color=(206, 184, 150),
                               roof_color=(90, 64, 48), door=True))
    visual.append(timber_house("HouseSW", -86, -64, 66, 90, HUB_Y, 10, "E", rng, roof_color=(96, 58, 46), door=True))
    visual.append(timber_house("HouseSE", 46, 68, 76, 94, HUB_Y, 10, "W", rng, wall_color=(214, 196, 158),
                               roof_color=(84, 60, 50), door=True))
    visual.append(barrel("BarrelSE", 70, HUB_Y, 92, rng))
    visual.append(storage_shack("VaultShack", 22, 40, -94, -78, HUB_Y, rng))
    visual.append(woodpile("WoodpileNW", -58, HUB_Y, -84, 0, rng))
    visual.append(crate_stack("CratesNW", -22, HUB_Y, -76, rng))
    visual.append(barrel("BarrelNW1", -52, HUB_Y, -66, rng))
    visual.append(barrel("BarrelNW2", -49.2, HUB_Y, -65, rng))
    visual.append(hand_cart("CartSW", -58, HUB_Y, 74, yaw_facing(0, -1)))
    visual.append(barrel("BarrelSW", -60, HUB_Y, 88, rng))
    visual.append(barrel("BarrelShop", -41.5, HUB_Y, -34, rng))
    visual.append(crate_stack("CratesShop", -40, HUB_Y, -40, rng))
    # Plaza life: benches facing the monument, a ring of flowers, market bunting over the roads.
    for k in range(4):
        a = math.radians(45 + 90 * k)
        bx, bz = math.cos(a) * 18, math.sin(a) * 18
        visual.append(bench(f"Bench{k}", bx, HUB_Y + 0.3, bz, yaw_facing(-bx, -bz)))
    for k in range(8):
        a = math.radians(22.5 + 45 * k)
        visual.append(flower_bed(f"PlazaBloom{k}", math.cos(a) * 9.5, HUB_Y + 0.3, math.sin(a) * 9.5, 3.2, 1.6,
                                 -math.degrees(a), rng))
    for k, (x, z, w, d) in enumerate(((-24, -34, 8, 3.2), (24, -34, 8, 3.2), (-24, 34, 8, 3.2), (24, 34, 8, 3.2),
                                      (-36, -22, 3.2, 8), (36, 22, 3.2, 8))):
        visual.append(flower_bed(f"Bed{k}", x, HUB_Y, z, w, d, 0, rng))
    # Market corner by the well: produce stall, gathering fire with log seats.
    visual.append(market_stall("ProduceStall", -38, HUB_Y, 52, rng))
    visual.append(campfire("GatheringFire", -24, HUB_Y, 66, rng))
    for k in range(3):
        a = math.radians(30 + 120 * k)
        visual.append(part(f"SeatLog{k}", (1.2, 1.2, 4.4), (-24 + math.cos(a) * 4.8, HUB_Y + 0.6, 66 + math.sin(a) * 4.8),
                           TRUNK, "Wood", mul(rot_y(-math.degrees(a)), rot_z(90)), shape="Cylinder"))
    # Waterfall on the east cliff into a pool.
    visual.append(waterfall("Waterfall", 100, HUB_Y, 72, rng))
    # Trainer yard extras.
    visual.append(hay_bale("Hay0", 80, HUB_Y + 0.2, -14, 20))
    visual.append(hay_bale("Hay1", 83, HUB_Y + 0.2, -18, -30))
    visual.append(hay_bale("Hay2", 81.5, HUB_Y + 2.4, -16, 5))
    visual.append(part("YardRack", (6, 5, 0.9), (48, HUB_Y + 2.5, -46), BEAM, "Wood"))
    for j in range(4):
        visual.append(part(f"YardRackBlade{j}", (0.4, 4.2, 1), (46 + j * 1.3, HUB_Y + 3.6, -45.4), (150, 110, 70), "Wood",
                           collide=False))
    # Bushes, stumps and boulders soften the edges.
    for k, (x, z) in enumerate(((-92, -40), (-92, 30), (92, -30), (92, 40), (-30, 92), (30, 92), (-60, -92), (60, -92),
                                (-40, -60), (44, -70), (76, 64), (-70, 50), (-94, 62), (94, 90), (-26, 84))):
        visual.append(bush(f"Bush{k:02d}", x, HUB_Y, z, rng, scale=rng.uniform(0.9, 1.5)))
    for k, (x, z) in enumerate(((-78, -52), (28, -74), (-24, 20), (44, 62))):
        visual.append(stump(f"Stump{k}", x, HUB_Y, z, rng))
    for k, (x, z) in enumerate(((-94, -34), (94, -62), (-50, 94), (82, 94), (-94, 86))):
        visual.append(rock_cluster(f"HubBoulder{k}", x, HUB_Y, z, rng, color=HUB_ROCK_DARK, size=0.9))
    visual.append(well("Well", -50, HUB_Y, 48, rng))

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
                  (48, -62), (86, -64), (24, -28), (-28, 24),
                  (-70, 30), (-34, 66), (-18, 86), (-88, 46), (36, 86),
                  (40, 70), (86, 16), (30, 26), (-88, 12), (-40, 90)]
    for k, (x, z) in enumerate(tree_spots):
        visual.append(tree(f"Tree{k:02d}", x, HUB_Y, z, rng))
    lamps = [(-11, -70), (11, 78), (-90, 11), (78, 11)]  # one per road; more crowded the plaza
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
            h = free_top(Y + rng.uniform(16, 24) - 1) - Y + 1
            visual.append(part(f"Ridge{side}_{k}", (xe - xs + 2, h, 16), ((xs + xe) / 2, Y + h / 2 - 1, 375),
                               QUARRY_CLIFF_DARK, "Sandstone", rot_y(rng.uniform(-5, 5)), collide=False, layer="cliff"))
        proxies.append(box(f"RidgeProxy{side}", x0, x1, Y - 1, Y + 26, 368, 382, (255, 0, 255), transparency=1,
                           query=False, shadow=False, layer="proxy"))

    visual.append(waystone("OverlookWaystone", "IronOverlook", 31, T, 145))

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
    hub_model = model("Hub", hub_visual, attrs={"Region": "Hub"})
    hub_model["properties"] = {"ModelStreamingMode": "Atomic"}  # arrives complete, so HubAmbience finds everything
    write_model(OUT / "Hub.model.json", hub_model)
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
    for name, (x, z) in (("Quest Master", (15, 50)), ("Merchant", (-63, -24.6)), ("Skill Trainer", (58, -12)),
                         ("Rebirth", (64, 22)), ("Vaultkeeper", (30, -84)), ("Travel board", (-16, -40))):
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
