#!/usr/bin/env python3
"""Generate the Lemonade map as Rojo JSON models: Hearthmere hub, Iron Lowlands, Briarwood.

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
import re
import shutil
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import glacier_kit as GK  # noqa: E402  (the Frostbound Glacier's kit: tools/glacier_kit.py)

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
# Ground palette (PS99 pass, round 2: calm vs vivid). PS99 is not one even pastel: its big walked
# surfaces are near-white tints (cream paths, lavender-white walks, saturation ~0.1-0.25) and its grass
# is a full-chroma lime (saturation ~0.75-0.85), and that pale-against-vivid contrast is what makes it
# read as a punchy toy world. So the grass is pushed to three vivid greens (the accent), and the
# warm family splits into near-white cream roads and walks (the calm) stepping up through peach to a
# golden desert sand. Darker steps stay the same hue: never grey, never brown mud. Each value here is
# shared verbatim with the matching terrain material colour in WorldTerrain.server.luau (Grass,
# LeafyGrass, Mud, Sand, Ground, Snow, Cobblestone, Concrete): most floor slabs are hidden under that
# terrain at runtime, so a slab carries the colour of the terrain that covers it and the ground reads
# as one palette, not two.
GRASS = (56, 248, 92)         # terrain Grass: the hub meadow and open Briarwood turf; vivid lime
GRASS_DARK = (38, 232, 86)    # terrain LeafyGrass: leafy cover, moss on the graves and gutters
GRASS_DEEP = (30, 204, 116)   # terrain Mud: the damp mossy shore of the Mirror Pool, path mottling
GROUND_PALE = (255, 248, 228) # terrain Snow: pale drift crests; the quarry rim, the pass; near-white cream
PATH = (255, 238, 208)        # terrain Cobblestone: the High Street, roads, plaza, yards, arena; cream
GROUND_MID = (252, 228, 190)  # terrain Ground: the cart line, path edges, leaf litter; the mid bench
GROUND_SAND = (255, 214, 130) # terrain Sand: the desert floor; the pit; golden toy sand
GROUND_TAN = (250, 214, 160)  # terrain Concrete: damp sand at the water; pool beds, haul roads; peach
PATH_EDGE = PATH
HUB_ROCK = (124, 94, 68)
HUB_ROCK_DARK = (100, 75, 55)
TIMBER = (255, 158, 36)  # crate orange at full chroma: the toy-box pop, never brown
BEAM = (240, 120, 20)  # the same orange one step darker for beams, posts, doors and trims
PLASTER = (255, 238, 210)  # calm cream wall: a pale warm tint, the quiet surface the roofs pop against
ROOF = (255, 84, 64)  # coral-red roof at full chroma
STONE = (188, 216, 255)  # calm masonry: near-white sky-blue tint (PS99 walkway), gates, plinths, chimney caps
STONE_DARK = (64, 144, 255)  # the same blue at full chroma for foundations, steps and trims: a pop, never grey
QUARRY_FLOOR = GROUND_PALE
QUARRY_PATH = GROUND_TAN
QUARRY_CLIFF = (170, 122, 80)
QUARRY_CLIFF_DARK = (142, 100, 66)
ROCK_GRAY = (209, 222, 255)  # toy stone: a calm near-white sky-blue tint (PS99's walkway stone), never grey
LEAVES = [(104, 230, 98), (80, 216, 86), (130, 238, 104)]  # spring greens, one hue, three values
TRUNK = (244, 150, 62)  # bright toy caramel-orange bark, never chocolate
WARLORD_RED = (236, 48, 84)  # the gang's banners: a full-chroma crimson-pink accent, never maroon
GOLD = (255, 206, 24)
IRON = (60, 122, 255)  # toy azure for bars, bands and brackets: full chroma, never grey
FROST = (160, 226, 255)  # saturated ice blue
CALDERA = (222, 84, 58)  # hot ember-red volcanic rock, never near-black
EMBER = (232, 112, 42)
CELESTIAL = (196, 184, 255)  # pale saturated lavender marble
VOID = (120, 64, 200)
VOID_GLOW = (150, 90, 220)
LANTERN = (255, 190, 64)
# Quarry palette: packed earth, cart ruts, rusted iron, moss, sump mud and water.
HAUL_ROAD = GROUND_TAN
RUT = (248, 184, 112)  # the cart ruts: one step deeper than the peach haul road, same hue, more saturated
RUST = (246, 104, 52)  # the gang's scrap plates: vivid toy orange-red, no corrosion
IRON_DARK = (44, 66, 160)  # the gang's iron (frames, chains, spikes): deep navy, a darker blue, never charcoal
MOSS = (122, 228, 138)
MUD = GROUND_TAN
SUMP_WATER = (72, 118, 112)  # the sump, cleared by the waterfall that feeds it
SPLINTER = (226, 110, 40)  # the gang's rough timber: crate orange one step deeper, never tar-brown

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
    REGISTRY.append({"name": name, "size": size, "pos": pos, "rot": rot, "color": color, "shape": shape,
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


USED_CLIFF_TOPS: set[int] = set()  # heights reserved map-wide (walkable floors, positionless callers)
LOCAL_CLIFF_TOPS: list[tuple[float, float, float]] = []  # (top, x, z) of every placed cliff chunk top


def free_top(top: float, x: float | None = None, z: float | None = None, reach: float = 36.0) -> float:
    """Nudge a cliff top, alternately down and up by 0.3, until it is clear of every reserved
    height and of every cliff top placed within `reach` studs. Coplanar tops only z-fight where
    chunks overlap, so the check is local: a map-wide rule ran out of free heights once the
    third region's 500 chunks arrived and ratcheted its walls 20+ studs above the others."""
    def taken(t):
        key = round(t * 10)
        if any(key + d in USED_CLIFF_TOPS for d in (-1, 0, 1)):
            return True
        return any(abs(ot - t) < 0.15 and (x is None or math.hypot(ox - x, oz - z) < reach)
                   for ot, ox, oz in LOCAL_CLIFF_TOPS)

    cand, k = top, 0
    while taken(cand):
        k += 1
        cand = top + 0.3 * ((k + 1) // 2) * (-1 if k % 2 else 1)
    if x is None:
        USED_CLIFF_TOPS.add(round(cand * 10))
    else:
        LOCAL_CLIFF_TOPS.append((cand, x, z))
    return cand


# When True, prop helpers ignore the caller's Y and rest on the floor generated under (x, z):
# benches, ramps and paths included. Off for the hub, whose props were placed by hand.
AUTO_GROUND = False


def entry_top(e, x, z):
    """World Y of a REGISTRY entry's top face above (x, z), or None outside its footprint.
    Same math as check_map_project.top_at, so props and the validator agree on the floor."""
    r, (px, py, pz), (sx, sy, sz) = e["rot"], e["pos"], e["size"]
    if e["shape"] == "Cylinder" and abs(r[1][0]) > 0.99:  # disc: axis vertical
        return py + sx / 2 if math.hypot(x - px, z - pz) <= sy / 2 else None
    if abs(r[1][1]) < 0.2:
        return None
    dx, dz = x - px, z - pz
    y = py + (sy / 2 - r[0][1] * dx - r[2][1] * dz) / r[1][1]
    d = (dx, y - py, dz)
    lx = sum(r[i][0] * d[i] for i in range(3))
    lz = sum(r[i][2] * d[i] for i in range(3))
    if abs(lx) <= sx / 2 + 1e-6 and abs(lz) <= sz / 2 + 1e-6:
        return y
    return None


def floor_at(x, z, default=None):
    """Highest Grounds_* top generated so far under (x, z); `default` when AUTO_GROUND is off
    or no floor covers the point."""
    if not AUTO_GROUND:
        return default
    best = None
    for e in REGISTRY:
        if e["layer"] != "ground":
            continue
        y = entry_top(e, x, z)
        if y is not None and (best is None or y > best):
            best = y
    return default if best is None else best


def cliff_run(name, a, b, inward, base_y, height, color, dark, rng, depth=14.0, chunk=(10, 18),
              material="Sandstone", h_jitter=(0.82, 1.18), caps=True, proxy=True, protrude=0.0, solid=False,
              taper=None):
    """Visual cliff chunks along segment a→b whose inner faces sit on the segment line.

    `inward` is +1 when the play area lies to the left of a→b (looking down from +Y), else -1.
    Returns (visual_children, proxy_part). Visual chunks never collide; the proxy does.
    `taper(x, z)`, when given, scales each chunk's height at its centre (it draws nothing from
    `rng`, so a taper never shifts the rest of the map's seeded layout).
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
        h = height * rng.uniform(*h_jitter)
        if abs(h - last_h) < 0.6:  # equal neighbouring tops would z-fight where the chunks overlap
            h += 1.5
        d = depth * rng.uniform(0.9, 1.3)
        cx = ax + dx * (s + length / 2) - nx * (d / 2 - protrude)
        cz = az + dz * (s + length / 2) - nz * (d / 2 - protrude)
        if taper:
            h *= taper(cx, cz)
        h = free_top(base_y + h - 1, cx, cz) - base_y + 1
        last_h = h
        jitter = rng.uniform(-4, 4)
        col = color if i % 3 else dark
        out.append(part(f"{name}_{i:02d}", (length + 1.2, h, d), (cx, base_y + h / 2 - 1, cz), col,
                        material, rot_y(yaw + jitter), collide=solid, layer="cliff"))
        if caps and rng.random() < 0.45:  # stepped ledge breaks the silhouette
            lh = h * rng.uniform(0.25, 0.45)
            ld = rng.uniform(3, 5)
            lx = ax + dx * (s + length / 2) - nx * (d + ld / 2 - 1.5)
            lz = az + dz * (s + length / 2) - nz * (d + ld / 2 - 1.5)
            cap_top = free_top(base_y + h + 1.45, lx, lz)
            cap_bottom = base_y + h - 1.6  # 0.6 below the chunk top, so the ledge always sits on it
            out.append(part(f"{name}_{i:02d}_cap", (length * 0.8, cap_top - cap_bottom, ld), (lx, (cap_top + cap_bottom) / 2, lz),
                            dark, material, rot_y(yaw + jitter * 0.5), collide=False, layer="cliff"))
        s += length
        i += 1
    if not proxy:
        return out, None
    proxy = part(f"{name}_Proxy", (seg, PROXY_TOP - base_y + 2, 6),
                 ((ax + bx) / 2 - nx * 3, (base_y - 2 + PROXY_TOP) / 2, (az + bz) / 2 - nz * 3),
                 (255, 0, 255), "SmoothPlastic", rot_y(yaw), transparency=1, query=False,
                 shadow=False, layer="proxy")
    return out, proxy


# ── Hearthmere castle wall ────────────────────────────────────────────────────
# Bright, high-key, saturated sky-blue toy-plastic masonry and a coral-red cap: the
# castle-wall pass (Pet Simulator 99 is the bar). Deliberately far from HUB_ROCK's muddy brown --
# docs/ART_DIRECTION.md calls for nothing desaturated anywhere in frame.
CASTLE_STONE = (188, 216, 255)  # main masonry: near-white sky blue, the big calm surface
CASTLE_STONE_SHADE = (60, 140, 255)  # base course, parapet lip, tower rim: the same blue at full chroma
CASTLE_TRIM = (168, 204, 255)  # buttress pilasters: one pale step deeper than the body
CASTLE_ROOF = (255, 80, 60)  # tower cap: full-chroma coral red, the warm pop
CASTLE_ROOF_DARK = (236, 48, 48)  # the cap's topmost, smallest ring


def _wall_box(name, ax, az, dx, dz, nx, nz, r, t0, t1, o0, o1, y0, y1, color, material, **kw):
    """A box in a wall run's local frame: spans segment-param [t0, t1] along the run (t=0 at a,
    t=seg at b), [o0, o1] studs outward from the a->b line (negative o reaches toward the hub),
    and [y0, y1] in height. Mirrors cliff_run's own axis convention exactly, so a castle_wall
    call with the same (a, b, inward) as a cliff_run segment sits flush on its line."""
    tc, oc = (t0 + t1) / 2, (o0 + o1) / 2
    cx = ax + dx * tc - nx * oc
    cz = az + dz * tc - nz * oc
    size = (abs(t1 - t0), y1 - y0, abs(o1 - o0))
    return part(name, size, (cx, (y0 + y1) / 2, cz), color, material, r, layer="castle", **kw)


def castle_wall(name, a, b, inward, base_y, rng, depth=8.0, merlon_w=4.0, gap_w=4.0,
                buttress_every=20.0):
    """A chunky cream-sandstone castle-wall facade along segment a->b: a stepped base course, a
    tall masonry body, a corbelled parapet lip and a battlemented row of merlons on top, with
    buttress pilasters proud of the face at intervals -- rounded corner towers are its own
    castle_tower, placed by the caller at the run's ends. Decorative only (every part here is
    CanCollide=False): cliff_run's own invisible proxy, unchanged, still holds players in, and the
    sculpted canyon crest still rises above and behind this facade -- a fortress built into the
    canyon wall, not floating apart from it."""
    ax, az = a
    bx, bz = b
    seg = math.hypot(bx - ax, bz - az)
    dx, dz = (bx - ax) / seg, (bz - az) / seg
    nx, nz = dz * inward, -dx * inward
    yaw = math.degrees(math.atan2(-dz, dx))
    r = rot_y(yaw)
    base_h, body_h, lip_h, mer_h = 4.0, 20.0, 1.6, 4.4
    y0 = base_y
    y1 = y0 + base_h
    y2 = y1 + body_h
    y3 = y2 + lip_h
    y4 = y3 + mer_h
    kids = [
        _wall_box(f"{name}_Base", ax, az, dx, dz, nx, nz, r, 0, seg, 0, depth + 3.0, y0, y1,
                  CASTLE_STONE_SHADE, "SmoothPlastic", collide=False),
        _wall_box(f"{name}_Body", ax, az, dx, dz, nx, nz, r, 0, seg, 0, depth, y1, y2,
                  CASTLE_STONE, "SmoothPlastic", collide=False),
        _wall_box(f"{name}_Lip", ax, az, dx, dz, nx, nz, r, -0.3, seg + 0.3, 0, depth + 1.6, y2, y3,
                  CASTLE_STONE_SHADE, "SmoothPlastic", collide=False, shadow=False),
    ]
    # The buttress top sits 0.6 studs proud of the body's own top (y2): flush would be an exact
    # coplanar overlap (z-fighting) between two different parts sharing that whole footprint.
    n_but = max(0, round(seg / buttress_every) - 1)
    for k in range(1, n_but + 1):
        t = seg * k / (n_but + 1)
        kids.append(_wall_box(f"{name}_Buttress{k}", ax, az, dx, dz, nx, nz, r, t - 1.3, t + 1.3,
                              -1.4, depth - 2.0, y0, y2 + 0.6, CASTLE_TRIM, "SmoothPlastic",
                              collide=False, shadow=False))
    period = merlon_w + gap_w
    n_mer = max(1, round(seg / period))
    start = (seg - n_mer * period) / 2 + gap_w / 2
    for k in range(n_mer):
        t = start + k * period
        if t < 0.5 or t + merlon_w > seg - 0.5:
            continue
        kids.append(_wall_box(f"{name}_Merlon{k}", ax, az, dx, dz, nx, nz, r, t, t + merlon_w,
                              0.4, depth * 0.85, y3, y4, CASTLE_STONE, "SmoothPlastic",
                              collide=False, shadow=False))
    return model(name, kids, attrs={"CastleWall": True})


def castle_tower(name, x, z, base_y, rng, height=24.0, radius=7.0, roof_h=11.0, merlons=8,
                 stone=CASTLE_STONE, roof=CASTLE_ROOF, roof_dark=CASTLE_ROOF_DARK):
    """A rounded corner/gatehouse tower: a cylindrical drum, a crenellated corbel rim, and a
    chunky stepped conical cap (three tapering drums -- Roblox parts have no native cone -- with a
    small gold finial). Decorative only (CanCollide=False everywhere): the wall's own invisible
    proxy still blocks players at every tower position."""
    top = base_y + height
    kids = [
        part(f"{name}_Trunk", (height, radius * 2, radius * 2), (x, base_y + height / 2, z),
             stone, "SmoothPlastic", rot_z(90), shape="Cylinder", collide=False, layer="castle"),
        part(f"{name}_Rim", (1.6, radius * 2 + 1.0, radius * 2 + 1.0), (x, top + 0.8, z),
             CASTLE_STONE_SHADE, "SmoothPlastic", rot_z(90), shape="Cylinder", collide=False,
             shadow=False, layer="castle"),
    ]
    rim_top = top + 1.6
    for k in range(merlons):
        a = math.tau * k / merlons + rng.uniform(-0.03, 0.03)
        mx, mz = x + math.cos(a) * radius * 0.82, z + math.sin(a) * radius * 0.82
        kids.append(part(f"{name}_Merlon{k}", (2.6, 3.6, 2.2), (mx, rim_top + 1.8, mz),
                         stone, "SmoothPlastic", rot_y(math.degrees(a)), collide=False, shadow=False,
                         layer="castle"))
    cap_y = rim_top + 3.6  # above the rim and the merlon row
    rings = 3
    for k in range(rings):
        frac = k / rings
        d = radius * 2 * (0.98 - 0.62 * frac)
        h = roof_h / rings
        col = roof if k < rings - 1 else roof_dark
        if k == rings - 1:
            # The top ring is a round toy dome, not a third flat drum: a chunky rounded crown.
            cy = cap_y + d * 0.3
            kids.append(part(f"{name}_Cap{k}", (d, d, d), (x, cy, z), col, "SmoothPlastic",
                             shape="Ball", collide=False, shadow=False, layer="castle"))
            cap_y = cy + d / 2 - 0.2
            continue
        kids.append(part(f"{name}_Cap{k}", (h, d, d), (x, cap_y + h / 2, z), col, "SmoothPlastic",
                         rot_z(90), shape="Cylinder", collide=False, shadow=False, layer="castle"))
        cap_y += h
    kids.append(part(f"{name}_Finial", (1.4, 1.4, 1.4), (x, cap_y + 0.7, z), GOLD, "SmoothPlastic",
                     shape="Ball", collide=False, shadow=False, layer="castle"))
    return model(name, kids, attrs={"CastleTower": True})


def hsv(h, s, v):
    """An RGB 0-255 tuple from hue in degrees and saturation/value in 0..1."""
    h = (h % 360) / 60
    i, f = int(h), h - int(h)
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    r, g, b = ((v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q))[i % 6]
    return (round(r * 255), round(g * 255), round(b * 255))


def blend(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


# Toy canopies, the Pet Simulator 99 way: not one green but several candy hues, each a
# (shade, body, highlight) triple. The shade is the same hue deeper (never grey), the highlight a
# pale tint of it where the sun catches the crown. Vivid families (lime, pink, cyan, orange) are the
# full-chroma pops; calm families (mint, cream, lavender) are pale quiet masses they pop against,
# so the wood ranges from near-white tints to full chroma instead of one mid pastel wash.
CANOPY = {
    "lime": (hsv(112, 0.88, 0.84), hsv(104, 0.82, 0.96), hsv(92, 0.22, 1.0)),
    "pink": (hsv(334, 0.82, 0.9), hsv(330, 0.66, 1.0), hsv(330, 0.17, 1.0)),
    "cyan": (hsv(194, 0.9, 0.86), hsv(188, 0.74, 1.0), hsv(186, 0.18, 1.0)),
    "orange": (hsv(26, 0.88, 0.96), hsv(36, 0.78, 1.0), hsv(42, 0.2, 1.0)),
    "lavender": (hsv(268, 0.62, 0.92), hsv(270, 0.4, 1.0), hsv(272, 0.16, 1.0)),
    "mint": (hsv(150, 0.56, 0.9), hsv(146, 0.22, 0.98), hsv(138, 0.1, 1.0)),
    "cream": (hsv(46, 0.6, 1.0), hsv(50, 0.24, 1.0), hsv(54, 0.1, 1.0)),
}
# Which family a broadleaf takes: mostly lime and the candy pops, with pale mint/cream/lavender
# crowns scattered through them as the calm masses.
BROADLEAF_MIX = (("lime", 0.22), ("pink", 0.14), ("cyan", 0.12), ("orange", 0.08), ("lavender", 0.14), ("mint", 0.16),
                 ("cream", 0.14))
CONIFER_MIX = (("lime", 0.34), ("cyan", 0.3), ("mint", 0.36))
UNDERSTORY_MIX = (("cream", 0.3), ("pink", 0.25), ("orange", 0.2), ("lime", 0.25))


def canopy_of(name, mix=BROADLEAF_MIX):
    """A tree's canopy family, picked from its name so no shared random stream is drawn."""
    u = (zlib.crc32(f"canopy:{name}".encode()) % 10007) / 10007 * sum(w for _, w in mix)
    for fam, w in mix:
        u -= w
        if u < 0:
            return CANOPY[fam]
    return CANOPY[mix[-1][0]]


# Hub tree palette: caramel bark, and the lime canopy triple as the default leaf tones.
BARK = (250, 160, 72)  # bright caramel-orange plastic bark: a crate-orange pop, never brown
BARK_DARK = (236, 138, 56)  # the same caramel one step deeper for the bole and roots
LEAF_SHADE, LEAF_MID, LEAF_SUN = CANOPY["lime"]
# Horizontal direction toward the afternoon sun (WorldLook: latitude -10, mid afternoon), so the
# leaf masses on that side take the warm tone.
SUN_XZ = (-0.68, -0.73)


def tree(name, x, y, z, rng, scale=1.0):
    """Hearthmere broadleaf: a tapered bark trunk with a flared, rooted foot, two limbs, and a
    crown of eight overlapping leaf masses (a big core, a ring of offset lobes, two crown lobes),
    darker blue-green beneath and warmer on the sun side, so the silhouette breaks up and the
    gaps between lobes dapple the lawn. The shared `rng` is drawn exactly as the old two-cube
    tree drew it (five draws); the extra detail comes from a per-tree seed, so every other part
    of the map generates unchanged. A child named Canopy stays (HubAmbience's butterflies)."""
    y = floor_at(x, z, y)
    s = scale * rng.uniform(0.85, 1.15)
    trunk_h = 11 * s
    rng.choice(LEAVES)
    trunk_yaw = rng.uniform(0, 90)
    yaw = rng.uniform(0, 90)
    rng.choice(LEAVES)
    local = random.Random(zlib.crc32(name.encode()))
    shade, mid, sun = canopy_of(name)
    up = rot_z(90)  # Cylinder parts run along X; this stands them up
    kids = [
        part("Bole", (trunk_h * 0.5, 2.7 * s, 2.7 * s), (x, y + trunk_h * 0.25, z), BARK_DARK, "SmoothPlastic",
             mul(rot_y(trunk_yaw), up), shape="Cylinder", layer="tree"),
        part("Trunk", (trunk_h * 0.62, 2.0 * s, 2.0 * s), (x, y + trunk_h * 0.69, z), BARK, "SmoothPlastic",
             mul(rot_y(trunk_yaw + 40), up), shape="Cylinder", layer="tree"),
        part("RootFlare", (1.0 * s, 3.8 * s, 3.8 * s), (x, y + 0.5 * s, z), BARK_DARK, "SmoothPlastic", up,
             shape="Cylinder", collide=False, shadow=False, layer="tree"),
    ]
    for k in range(4):
        a = math.radians(trunk_yaw) + k * math.pi / 2 + local.uniform(-0.35, 0.35)
        reach = local.uniform(2.6, 3.4) * s
        kids.append(beam(f"Root{k}", (x + math.cos(a) * 0.6 * s, y + 1.9 * s, z + math.sin(a) * 0.6 * s),
                         (x + math.cos(a) * reach, y + 0.1, z + math.sin(a) * reach), 0.75 * s, BARK_DARK,
                         "SmoothPlastic", depth=0.9 * s, collide=False, query=False, shadow=False, layer="tree"))
    top = y + trunk_h
    for k in range(2):
        a = math.radians(yaw) + k * math.pi + local.uniform(-0.4, 0.4)
        kids.append(beam(f"Limb{k}", (x, top - 2.6 * s, z), (x + math.cos(a) * 3.2 * s, top + 1.2 * s, z + math.sin(a) * 3.2 * s),
                         0.7 * s, BARK, "SmoothPlastic", collide=False, query=False, shadow=False, layer="tree"))

    def tone(dx, dy, dz):
        """Leaf tone for a lobe offset: underside cool, sun side and crown warm."""
        h = math.hypot(dx, dz) or 1.0
        facing = (dx * SUN_XZ[0] + dz * SUN_XZ[1]) / h
        lift = dy / (2.5 * s) + facing * 0.8
        return sun if lift > 0.6 else shade if lift < -0.35 else mid

    lobes = [("Canopy", 0.0, 2.2 * s, 0.0, 9.0 * s, mid)]
    ring = local.randint(5, 6)
    for k in range(ring):
        a = math.radians(yaw) + k * math.tau / ring + local.uniform(-0.3, 0.3)
        r = local.uniform(3.4, 4.4) * s
        d = local.uniform(5.2, 7.0) * s
        dy = local.uniform(-0.6, 2.4) * s
        dx, dz = math.cos(a) * r, math.sin(a) * r
        dy = max(dy, d / 2 - 2.4 * s)  # lobe bottoms stay 8.6+ studs up (camera clearance)
        lobes.append((f"Leaves{k}", dx, dy, dz, d, tone(dx, dy, dz)))
    for k in range(2):
        a = math.radians(yaw) + math.pi / 3 + k * math.pi + local.uniform(-0.4, 0.4)
        dx, dz = math.cos(a) * 1.8 * s, math.sin(a) * 1.8 * s
        lobes.append((f"Crown{k}", dx, local.uniform(5.2, 6.2) * s, dz, local.uniform(5.4, 6.4) * s, sun))
    for lname, dx, dy, dz, d, color in lobes:
        kids.append(part(lname, (d, d, d), (x + dx, top + dy, z + dz), color, "SmoothPlastic",
                         rot_y(local.uniform(0, 360)), shape="Ball", collide=False, query=False, layer="canopy"))
    return model(name, kids)


def rock_cluster(name, x, y, z, rng, color=ROCK_GRAY, size=1.0, collide=True):
    y = floor_at(x, z, y)
    kids = []
    tops = set()
    for i in range(rng.randint(2, 4)):
        w, h, d = (rng.uniform(4, 9) * size, rng.uniform(2.5, 6) * size, rng.uniform(4, 8) * size)
        while round(h * 10) in tops:  # two flat-ish rocks with equal tops would z-fight where they overlap
            h += 0.35
        tops.add(round(h * 10))
        ox, oz = rng.uniform(-4, 4) * size, rng.uniform(-4, 4) * size
        r = mul(rot_y(rng.uniform(0, 90)), rot_z(rng.uniform(-10, 10)))
        kids.append(part(f"Rock{i}", (w, h, d), (x + ox, y + h / 2 - 0.6, z + oz), color, "SmoothPlastic", r,
                         collide=collide and i == 0, layer="rock"))
    return model(name, kids)


def lamp_post(name, x, y, z, yaw=0.0):
    y = floor_at(x, z, y)
    fwd = apply(rot_y(yaw), (0, 0, -1))
    arm = (x + fwd[0] * 1.6, y + 9.2, z + fwd[2] * 1.6)
    return model(name, [
        part("Post", (0.8, 10, 0.8), (x, y + 5, z), BEAM, "SmoothPlastic"),
        part("Arm", (0.5, 0.5, 3), (x + fwd[0] * 1.2, y + 9.7, z + fwd[2] * 1.2), BEAM, "SmoothPlastic",
             rot_y(yaw), collide=False),
        part("Lantern", (1.3, 1.6, 1.3), (arm[0], y + 8.6, arm[2]), LANTERN, "Neon", rot_y(yaw),
             collide=False, query=False, shadow=False, transparency=0.15, children=[light(20, 1.1)]),
    ])


def sign(name, x, y, z, yaw, width, height, title, subtitle="", board=TIMBER, text=(255, 238, 200),
         post_h=None):
    """Signboard between two posts. Posts sit outside the board's width so they can't cover text."""
    y = floor_at(x, z, y)
    post_h = post_h if post_h is not None else height + 3
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))
    board_y = y + post_h - height / 2 - 0.3
    kids = []
    if post_h > height:
        for side in (-1, 1):
            offset = side * (width / 2 + 0.45)
            kids.append(part(f"Post{side}", (0.8, post_h, 0.8), (x + right[0] * offset, y + post_h / 2, z + right[2] * offset),
                             BEAM, "SmoothPlastic", r))
    kids.append(part("Board", (width, height, 0.5), (x, board_y, z), board, "SmoothPlastic", r,
                     collide=False, children=[label_gui("Front", title, subtitle, text),
                                              label_gui("Back", title, subtitle, text)]))
    return model(name, kids)


def fence_run(name, a, b, y, height=3.2, gap=None, collide=True, skip_first_post=False):
    """Timber fence with posts every ~8 studs. `gap` = (s0, s1) distances along the run left open."""
    y = floor_at((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, y)
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
                             (ax + dx * s, y + (height + 0.6) / 2, az + dz * s), BEAM, "SmoothPlastic", rot_y(yaw),
                             collide=collide))
        mid = (s0 + s1) / 2
        for ri, rh in enumerate((height * 0.45, height * 0.9)):
            kids.append(part(f"Rail{si}_{ri}", (s1 - s0, 0.45, 0.35),
                             (ax + dx * mid, y + rh, az + dz * mid), TIMBER, "SmoothPlastic", rot_y(yaw),
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
    kids = [box("Foundation", x0 - 1, x1 + 1, y - 0.6, y + 0.8, z0 - 1, z1 + 1, STONE_DARK, "SmoothPlastic")]
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
                kids.append(box(f"Wall{side}L", a0, mid - door_w / 2, y + 0.8, top, b0, b1, wall_color, "SmoothPlastic"))
                kids.append(box(f"Wall{side}R", mid + door_w / 2, a1, y + 0.8, top, b0, b1, wall_color, "SmoothPlastic"))
            else:
                mid = (b0 + b1) / 2
                kids.append(box(f"Wall{side}L", a0, a1, y + 0.8, top, b0, mid - door_w / 2, wall_color, "SmoothPlastic"))
                kids.append(box(f"Wall{side}R", a0, a1, y + 0.8, top, mid + door_w / 2, b1, wall_color, "SmoothPlastic"))
            continue
        kids.append(box(f"Wall{side}", a0, a1, y + 0.8, top, b0, b1, wall_color, "SmoothPlastic"))
    # Door: plank slab in the opening, iron bands and a ring handle. Collidable, so the empty
    # interior stays closed rather than being a box players can wander into.
    if door and not open_front:
        a0, a1, b0, b1 = walls[front]
        door_h = min(wall_h - 1.0, 8.0)
        if front in "NS":
            mid = (a0 + a1) / 2
            bz = (b0 + b1) / 2
            kids.append(box("Door", mid - door_w / 2 + 0.2, mid + door_w / 2 - 0.2, y + 0.8, y + 0.8 + door_h,
                            bz - 0.2, bz + 0.2, BEAM, "SmoothPlastic"))
            for k, hy in enumerate((0.25, 0.7)):
                kids.append(box(f"DoorBand{k}", mid - door_w / 2 + 0.3, mid + door_w / 2 - 0.3,
                                y + 0.8 + door_h * hy - 0.2, y + 0.8 + door_h * hy + 0.2, bz - 0.32, bz + 0.32,
                                IRON, "SmoothPlastic", collide=False))
            hz = bz - 0.3 if front == "N" else bz + 0.3  # 0.05 into the leaf so it moves with the door
            kids.append(part("DoorHandle", (0.5, 0.5, 0.3), (mid + door_w / 2 - 1.1, y + 0.8 + door_h * 0.45, hz),
                             GOLD, "SmoothPlastic", collide=False))
            kids.append(box("DoorLintel", mid - door_w / 2 - 0.6, mid + door_w / 2 + 0.6, y + 0.8 + door_h,
                            y + 0.8 + door_h + 0.7, b0 - 0.15, b1 + 0.15, BEAM, "SmoothPlastic"))
        else:
            mid = (b0 + b1) / 2
            bx = (a0 + a1) / 2
            kids.append(box("Door", bx - 0.2, bx + 0.2, y + 0.8, y + 0.8 + door_h, mid - door_w / 2 + 0.2,
                            mid + door_w / 2 - 0.2, BEAM, "SmoothPlastic"))
            for k, hy in enumerate((0.25, 0.7)):
                kids.append(box(f"DoorBand{k}", bx - 0.32, bx + 0.32, y + 0.8 + door_h * hy - 0.2,
                                y + 0.8 + door_h * hy + 0.2, mid - door_w / 2 + 0.3, mid + door_w / 2 - 0.3,
                                IRON, "SmoothPlastic", collide=False))
            hx = bx - 0.3 if front == "W" else bx + 0.3
            kids.append(part("DoorHandle", (0.3, 0.5, 0.5), (hx, y + 0.8 + door_h * 0.45, mid + door_w / 2 - 1.1),
                             GOLD, "SmoothPlastic", collide=False))
            kids.append(box("DoorLintel", a0 - 0.15, a1 + 0.15, y + 0.8 + door_h, y + 0.8 + door_h + 0.7,
                            mid - door_w / 2 - 0.6, mid + door_w / 2 + 0.6, BEAM, "SmoothPlastic"))
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
                kids.append(part(f"Glass{side}{wi}", size, glass_pos, (130, 216, 255), "Glass", collide=False,
                                 transparency=0.35, children=[light(9, 0.8, (255, 205, 140))]))
                kids.append(part(f"Frame{side}{wi}T", fsize, frame_h, BEAM, "SmoothPlastic", collide=False))
                kids.append(part(f"Frame{side}{wi}B", fsize, frame_l, BEAM, "SmoothPlastic", collide=False))
                kids.append(part(f"Frame{side}{wi}L", sides_size, side_a, BEAM, "SmoothPlastic", collide=False))
                kids.append(part(f"Frame{side}{wi}R", sides_size, side_b, BEAM, "SmoothPlastic", collide=False))
                kids.append(part(f"FlowerBox{side}{wi}", box_size, box_pos, BEAM, "SmoothPlastic", collide=False))
                for fi in range(3):
                    off = (fi - 1) * 0.9
                    fp = (box_pos[0] + (off if side in "NS" else 0), box_pos[1] + 0.55,
                          box_pos[2] + (off if side in "EW" else 0))
                    kids.append(part(f"Bloom{side}{wi}{fi}", (0.55, 0.55, 0.55), fp, rng.choice(FLOWER_COLORS),
                                     "SmoothPlastic", shape="Ball", collide=False, query=False, shadow=False))
    # Timber frame: corner posts, sill and top beams, a diagonal brace per long wall.
    for cx in (x0, x1):
        for cz in (z0, z1):
            kids.append(box("CornerPost", cx - 0.7, cx + 0.7, y + 0.8, top - 0.2, cz - 0.7, cz + 0.7, BEAM, "SmoothPlastic"))
    for side, (a0, a1, b0, b1) in walls.items():
        if side == front and open_front:
            continue
        pad = 0.25
        mid0, mid1 = y + 0.8 + wall_h * 0.45, y + 0.8 + wall_h * 0.45 + 0.7
        # The mid rail stops either side of the doorway; a full rail crossed the opening at
        # chest height and players walked straight through it.
        if side in "NS":
            bz = b0 - pad if side == "N" else b1 + pad
            kids.append(box(f"TopBeam{side}", a0, a1, top - 0.9, top, bz - 0.3, bz + 0.3, BEAM, "SmoothPlastic", collide=False))
            spans = [(a0, a1)] if side != front else [(a0, (a0 + a1) / 2 - door_w / 2), ((a0 + a1) / 2 + door_w / 2, a1)]
            for si, (m0, m1) in enumerate(spans):
                if m1 - m0 > 0.2:
                    kids.append(box(f"MidBeam{side}{si}", m0, m1, mid0, mid1, bz - 0.3, bz + 0.3, BEAM, "SmoothPlastic",
                                    collide=False))
        else:
            bx = a0 - pad if side == "W" else a1 + pad
            kids.append(box(f"TopBeam{side}", bx - 0.3, bx + 0.3, top - 0.9, top, b0, b1, BEAM, "SmoothPlastic", collide=False))
            spans = [(b0, b1)] if side != front else [(b0, (b0 + b1) / 2 - door_w / 2), ((b0 + b1) / 2 + door_w / 2, b1)]
            for si, (m0, m1) in enumerate(spans):
                if m1 - m0 > 0.2:
                    kids.append(box(f"MidBeam{side}{si}", bx - 0.3, bx + 0.3, mid0, mid1, m0, m1, BEAM, "SmoothPlastic",
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
                             (cx, top + math.tan(math.radians(pitch)) * (span_z / 4 - overhang / 2), cz + sgn * half / 2), roof_color, "SmoothPlastic", r,
                             collide=False, layer="roof"))
        # WedgePart: bottom face flat, vertical face at local +Z, slope descending toward -Z.
        for gx in (x0 + 0.5, x1 - 0.5):
            for sgn, yaw in ((-1, 0), (1, 180)):  # north half rises toward +Z, south half toward -Z
                kids.append(part(f"Gable{'N' if sgn < 0 else 'S'}", (1, rise, span_z / 2),
                                 (gx, top + rise / 2, cz + sgn * span_z / 4), wall_color, "SmoothPlastic", rot_y(yaw),
                                 cls="WedgePart", collide=False, layer="roof"))
    else:
        half = span_x / 2 + overhang
        rise = math.tan(math.radians(pitch)) * (span_x / 2)
        slope_len = half / math.cos(math.radians(pitch))
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        for sgn in (-1, 1):
            r = rot_z(-pitch * sgn)  # rot_z(+a) raises +X; the east slab drops toward +X
            kids.append(part(f"Roof{'W' if sgn < 0 else 'E'}", (slope_len, 0.9, span_z + overhang * 2),
                             (cx + sgn * half / 2, top + math.tan(math.radians(pitch)) * (span_x / 4 - overhang / 2), cz), roof_color, "SmoothPlastic", r,
                             collide=False, layer="roof"))
        for gz in (z0 + 0.5, z1 - 0.5):
            for sgn, yaw in ((-1, 90), (1, -90)):  # west half rises toward +X, east half toward -X
                kids.append(part(f"Gable{'W' if sgn < 0 else 'E'}", (1, rise, span_x / 2),
                                 (cx + sgn * span_x / 4, top + rise / 2, gz), wall_color, "SmoothPlastic", rot_y(yaw),
                                 cls="WedgePart", collide=False, layer="roof"))
    if chimney:
        # Stone stack through the roof near one end of the ridge, with smoke drifting from it.
        if span_x >= span_z:
            chx, chz = x0 + span_x * 0.22, cz
        else:
            chx, chz = cx, z0 + span_z * 0.22
        ch_top = top + rise + 2.4
        kids.append(part("Chimney", (2.4, ch_top - top + 1.5, 2.4), (chx, (top - 1.5 + ch_top) / 2, chz), STONE_DARK,
                         "SmoothPlastic", collide=False))
        kids.append(part("ChimneyCap", (3.0, 0.6, 3.0), (chx, ch_top + 0.3, chz), STONE, "SmoothPlastic", collide=False))
        kids.append(part("ChimneyFlue", (1.2, 0.3, 1.2), (chx, ch_top + 0.6, chz), (44, 112, 240), "SmoothPlastic",
                         collide=False, query=False, children=[smoke(2.2, 0.16, 2.5)]))
    if door and not open_front:
        # A furnished room so an opened door shows a home, not an empty box.
        fl = y + 0.8
        ix0, ix1, iz0, iz1 = x0 + 1.2, x1 - 1.2, z0 + 1.2, z1 - 1.2
        cxi, czi = (ix0 + ix1) / 2, (iz0 + iz1) / 2
        kids.append(box("FloorBoards", ix0, ix1, fl, fl + 0.12, iz0, iz1, TIMBER, "SmoothPlastic", collide=False))
        kids.append(part("Rug", (min(7, (ix1 - ix0) * 0.5), 0.08, min(5, (iz1 - iz0) * 0.4)), (cxi, fl + 0.18, czi),
                         rng.choice([(255, 72, 72), (90, 150, 250), TIMBER]), "SmoothPlastic", collide=False))
        # Bed along the wall opposite the door; table and stools in the middle; shelf on a side wall.
        if front in "NS":
            bz = iz0 + 2.2 if front == "S" else iz1 - 2.2
            kids.append(part("BedFrame", (4.4, 1.2, 3.2), (ix0 + 3.0, fl + 0.6, bz), BEAM, "SmoothPlastic"))
            kids.append(part("Mattress", (4.2, 0.6, 3.0), (ix0 + 3.0, fl + 1.5, bz), (255, 236, 200), "SmoothPlastic", collide=False))
            kids.append(part("Blanket", (2.6, 0.25, 3.05), (ix0 + 3.8, fl + 1.9, bz), (255, 72, 72), "SmoothPlastic", collide=False))
            kids.append(part("Pillow", (1.2, 0.5, 1.6), (ix0 + 1.4, fl + 2.0, bz), (255, 240, 210), "SmoothPlastic", collide=False))
            kids.append(part("Shelf", (3.0, 0.3, 0.9), (ix1 - 2.0, fl + 5.0, iz0 + 0.35 if front == "S" else iz1 - 0.35),
                             BEAM, "SmoothPlastic", collide=False))
        else:
            bx = ix0 + 2.2 if front == "E" else ix1 - 2.2
            kids.append(part("BedFrame", (3.2, 1.2, 4.4), (bx, fl + 0.6, iz0 + 3.0), BEAM, "SmoothPlastic"))
            kids.append(part("Mattress", (3.0, 0.6, 4.2), (bx, fl + 1.5, iz0 + 3.0), (255, 236, 200), "SmoothPlastic", collide=False))
            kids.append(part("Blanket", (3.05, 0.25, 2.6), (bx, fl + 1.9, iz0 + 3.8), (255, 72, 72), "SmoothPlastic", collide=False))
            kids.append(part("Pillow", (1.6, 0.5, 1.2), (bx, fl + 2.0, iz0 + 1.4), (255, 240, 210), "SmoothPlastic", collide=False))
            kids.append(part("Shelf", (0.9, 0.3, 3.0), (ix0 + 0.35 if front == "E" else ix1 - 0.35, fl + 5.0, iz1 - 2.0),
                             BEAM, "SmoothPlastic", collide=False))
        kids.append(part("TableTop", (3.6, 0.3, 2.4), (cxi, fl + 2.6, czi), TIMBER, "SmoothPlastic"))
        for sx, sz in ((-1.5, -0.9), (1.5, -0.9), (-1.5, 0.9), (1.5, 0.9)):
            kids.append(part("TableLeg", (0.3, 2.5, 0.3), (cxi + sx, fl + 1.25, czi + sz), BEAM, "SmoothPlastic", collide=False))
        for sx in (-2.8, 2.8):
            kids.append(part("Stool", (1.1, 1.4, 1.1), (cxi + sx, fl + 0.7, czi), BEAM, "SmoothPlastic"))
        kids.append(part("Candle", (0.25, 0.7, 0.25), (cxi + 0.6, fl + 3.1, czi - 0.4), (240, 230, 200), "SmoothPlastic",
                         collide=False, query=False, children=[fire(0.6, 4), light(10, 0.8, (255, 200, 130))]))
        kids.append(part("Bowl", (0.9, 0.3, 0.9), (cxi - 0.8, fl + 2.9, czi + 0.3), BEAM, "SmoothPlastic", rot_z(90),
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


def gate(name, cx, y, cz, yaw, width, height, title, subtitle, sealed, stone=STONE, accent=(250, 80, 70),
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
        kids.append(part(f"Pillar{side}", (pw, height, pw + 1), (px, y + height / 2, pz), stone, "SmoothPlastic", r))
        kids.append(part(f"PillarCap{side}", (pw + 1.5, 1.6, pw + 2.5), (px, y + height + 0.8, pz), STONE_DARK,
                         "SmoothPlastic", r))
        tx, tz = at(side * (width / 2 + pw / 2), -(pw + 1) / 2 - 0.4)
        kids.append(part(f"Torch{side}", (0.9, 1.4, 0.9), (tx, y + height * 0.62, tz), LANTERN, "Neon", r,
                         collide=False, query=False, shadow=False, children=[light(18, 1.0)]))
    kids.append(part("Lintel", (width + pw * 2 + 2, 4, pw + 1.4), (cx, y + height + 2.6, cz), BEAM, "SmoothPlastic", r))
    sign_depth = (pw + 2.5) / 2 + 0.4  # clear of the pillar caps, which are the deepest part
    sx, sz = at(0, -sign_depth)
    kids.append(part("Sign", (width + 4, 5.2, 0.5), (sx, y + height + 2.8, sz), BEAM, "SmoothPlastic", r,
                     collide=False, children=[label_gui("Front", title, subtitle, (255, 226, 160), px=30)]))
    bx2, bz2 = at(0, sign_depth)
    kids.append(part("SignBack", (width + 4, 5.2, 0.5), (bx2, y + height + 2.8, bz2), BEAM, "SmoothPlastic",
                     r, collide=False, children=[label_gui("Back", back_title, back_subtitle, (255, 226, 160), px=30)]))
    for side in (-1, 1):  # brackets tie both boards to the lintel
        for sgn in (-1, 1):
            kx, kz = at(side * (width / 2 + 1.2), sgn * (sign_depth - 0.7))
            kids.append(part(f"SignBracket{side}{sgn}", (0.5, 0.5, 1.8), (kx, y + height + 4.4, kz), BEAM, "SmoothPlastic", r,
                             collide=False))
    for side in (-1, 1):
        bx, bz = at(side * (width / 2 + pw / 2), -(pw + 1) / 2 - 0.3)
        kids.append(part(f"Banner{side}", (4.2, 9, 0.3), (bx, y + height - 5.5, bz), accent, "SmoothPlastic", r,
                         collide=False))
    if sealed:
        bars = max(4, int(width // 3))
        for k in range(bars):
            lx = -width / 2 + width * (k + 0.5) / bars
            px, pz = at(lx, 0)
            kids.append(part(f"Bar{k}", (0.7, height, 0.7), (px, y + height / 2, pz), IRON, "SmoothPlastic", r,
                             collide=False))
        for hk, hy in enumerate((height * 0.3, height * 0.7)):
            kids.append(part(f"Crossbar{hk}", (width, 0.7, 0.8), (cx, y + hy, cz), IRON, "SmoothPlastic", r, collide=False))
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


FABRIC_GREEN = (64, 204, 120)  # a clean toy green, not olive
FABRIC_CREAM = (255, 236, 190)


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
            kids.append(part("Post", (0.9, eave - y, 0.9), (px_, y + (eave - y) / 2, pz), BEAM, "SmoothPlastic"))
    for pz in (z0, z1):
        kids.append(part("KingPost", (0.8, ridge - y, 0.8), (npc_x, y + (ridge - y) / 2, pz), BEAM, "SmoothPlastic"))
    # Frame: eave plates along Z, tie beams along X, ridge beam, rafters on each gable.
    for px_ in (x0, x1):
        kids.append(part("EavePlate", (0.7, 0.7, z1 - z0 + 1.2), (px_, eave - 0.35, cz), BEAM, "SmoothPlastic", collide=False))
    for pz in (z0, z1):
        kids.append(part("TieBeam", (x1 - x0 + 1.2, 0.6, 0.7), (npc_x, eave - 1.2, pz), BEAM, "SmoothPlastic", collide=False))
    kids.append(part("RidgeBeam", (0.8, 0.8, z1 - z0 + 1.6), (npc_x, ridge + 0.1, cz), BEAM, "SmoothPlastic", collide=False))
    run = npc_x - x0
    pitch = math.degrees(math.atan2(ridge - eave, run))
    rafter = math.hypot(run, ridge - eave) + 0.6
    for pz in (z0, z1):
        for sgn in (-1, 1):  # front rafter rises toward +X (rot_z +), back rafter toward -X
            kids.append(part("Rafter", (rafter, 0.55, 0.55), (npc_x + sgn * run / 2, (eave + ridge) / 2, pz), BEAM,
                             "SmoothPlastic", rot_z(-sgn * pitch), collide=False))
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
                             (mid_x, mid_y, zk), color, "SmoothPlastic", rot_z(-sgn * pitch),
                             collide=False, layer="roof"))
        # Valance: short hanging flaps along the low edge.
        edge_x = npc_x + sgn * (slope_run - 0.05)
        edge_y = ridge + 0.45 - math.tan(math.radians(pitch)) * slope_run
        for k in range(strips):
            zk = z0 - 1.2 + strip_w * (k + 0.5)
            color = FABRIC_CREAM if k % 2 == 0 else FABRIC_GREEN
            kids.append(part(f"Valance{'F' if sgn < 0 else 'B'}{k}", (0.15, 0.9, strip_w - 0.1),
                             (edge_x, edge_y - 0.45, zk), color, "SmoothPlastic", collide=False, layer="roof"))
    # Counter on the road side: plank top, slatted front, lower shelf, legs.
    cx0, cx1 = x0 - 0.4, x0 + 2.4
    top_y = y + 3.4
    kids.append(box("CounterTop", cx0 - 0.3, cx1 + 0.2, top_y - 0.35, top_y, z0 + 0.6, z1 - 0.6, TIMBER, "SmoothPlastic"))
    kids.append(box("CounterShelf", cx0 + 0.3, cx1 - 0.2, y + 1.0, y + 1.3, z0 + 0.9, z1 - 0.9, TIMBER, "SmoothPlastic",
                    collide=False))
    slats = 9
    for k in range(slats):
        zk = z0 + 1.1 + (z1 - z0 - 2.2) * (k + 0.5) / slats
        kids.append(box(f"Slat{k}", cx0 - 0.15, cx0 + 0.15, y, top_y - 0.35, zk - 0.55, zk + 0.55,
                        TIMBER if k % 2 else BEAM, "SmoothPlastic"))
    for lz in (z0 + 0.8, z1 - 0.8):
        kids.append(box("CounterLeg", cx1 - 0.5, cx1, y, top_y - 0.35, lz - 0.25, lz + 0.25, BEAM, "SmoothPlastic",
                        collide=False))
    # Goods: rolled quest scrolls, a stack of notices, an ink pot and a small crate.
    for k, (dz, length) in enumerate(((-3.8, 1.6), (-2.6, 1.3), (-3.2, 1.4))):
        kids.append(part(f"Scroll{k}", (length, 0.45, 0.45), (x0 + 0.9 + 0.1 * k, top_y + 0.23 + (0.4 if k == 2 else 0),
                                                            cz + dz), FABRIC_CREAM, "SmoothPlastic",
                         rot_y(15 * k), shape="Cylinder", collide=False))
    kids.append(part("Notices", (1.4, 0.3, 1.9), (x0 + 1.0, top_y + 0.15, cz + 2.8), (255, 236, 190), "SmoothPlastic",
                     rot_y(-8), collide=False))
    kids.append(part("InkPot", (0.45, 0.5, 0.45), (x0 + 1.2, top_y + 0.25, cz + 4.4), (44, 112, 240), "Glass",
                     collide=False))
    kids.append(part("Crate", (2.2, 2.2, 2.2), (x1 - 0.9, y + 1.1, z1 - 1.6), TIMBER, "SmoothPlastic", rot_y(10)))
    kids.append(part("CrateSmall", (1.5, 1.5, 1.5), (x1 - 1.0, y + 2.95, z1 - 1.8), TIMBER, "SmoothPlastic",
                     rot_y(-14), collide=False))
    # Hanging sign under the front eave.
    sign_y = eave - 2.1
    for dz in (-1.8, 1.8):
        kids.append(part("SignChain", (0.12, 1.0, 0.12), (x0 - 0.2, eave - 1.0, cz + dz), IRON, "SmoothPlastic", collide=False))
    kids.append(part("SignBoard", (4.6, 1.8, 0.35), (x0 - 0.2, sign_y, cz), BEAM, "SmoothPlastic",
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
                     STONE, "SmoothPlastic", rot_z(90), shape="Cylinder"))
    kids.append(part("RimCap", (0.35, (radius + 0.5) * 2, (radius + 0.5) * 2), (x, rim_top + 0.1, z), STONE_DARK,
                     "SmoothPlastic", rot_z(90), shape="Cylinder", collide=False))
    kids.append(part("Shaft", (rim_top - y + 0.6, (radius - 0.9) * 2, (radius - 0.9) * 2), (x, (y + rim_top) / 2 - 0.1, z),
                     (70, 110, 210), "SmoothPlastic", rot_z(90), shape="Cylinder", collide=False))
    kids.append(part("Water", (0.4, (radius - 1.1) * 2, (radius - 1.1) * 2), (x, y + 0.9, z), (90, 190, 255), "Glass",
                     rot_z(90), shape="Cylinder", collide=False, transparency=0.25))
    # Winch frame: two posts up to the eaves, a crossbeam, the roller and a crank.
    post_top = y + 9.4
    for side in (-1, 1):
        kids.append(part(f"Post{side}", (0.7, post_top - y, 0.7), (x + side * (radius + 0.4), (y + post_top) / 2, z),
                         BEAM, "SmoothPlastic"))
    kids.append(part("Crossbeam", (radius * 2 + 2.4, 0.7, 0.7), (x, y + 8.6, z), BEAM, "SmoothPlastic", collide=False))
    kids.append(part("Roller", (radius * 2 - 0.4, 0.8, 0.8), (x, y + 7.4, z), TIMBER, "SmoothPlastic", rot_z(90),
                     shape="Cylinder", collide=False))
    kids.append(part("Crank", (0.35, 1.4, 0.35), (x + radius + 0.2, y + 6.9, z), IRON, "Metal", collide=False))
    kids.append(part("CrankHandle", (0.9, 0.3, 0.3), (x + radius + 0.6, y + 6.3, z), IRON, "Metal", collide=False))
    # Rope and bucket hanging over the shaft.
    kids.append(part("Rope", (0.14, 2.6, 0.14), (x, y + 5.9, z - 0.2), (255, 214, 150), "SmoothPlastic", collide=False))
    kids.append(part("Bucket", (1.5, 1.5, 1.5), (x, y + 3.9, z - 0.2), TIMBER, "SmoothPlastic", rot_y(12),
                     collide=False))
    kids.append(part("BucketBand", (1.62, 0.3, 1.62), (x, y + 4.2, z - 0.2), IRON, "Metal", rot_y(12), collide=False))
    # Small pitched roof resting on the posts: eave plates on the post tops, rafters, two slabs.
    pitch, half = 32.0, radius + 1.6
    rise = math.tan(math.radians(pitch)) * half
    slope = half / math.cos(math.radians(pitch))
    eave = post_top
    for side in (-1, 1):
        kids.append(part(f"EavePlate{side}", (0.7, 0.6, half * 2 + 0.6), (x + side * (radius + 0.4), eave + 0.3, z),
                         BEAM, "SmoothPlastic", collide=False))
        for sgn in (-1, 1):
            kids.append(part(f"Rafter{side}{sgn}", (0.5, 0.5, slope), (x + side * (radius + 0.4), eave + 0.6 + rise / 2,
                                                                       z + sgn * half / 2), BEAM, "SmoothPlastic",
                             rot_x(pitch * sgn), collide=False))
    kids.append(part("RidgeBeam", (radius * 2 + 1.6, 0.6, 0.6), (x, eave + 0.6 + rise, z), BEAM, "SmoothPlastic", collide=False))
    for sgn in (-1, 1):
        kids.append(part(f"Roof{sgn}", (radius * 2 + 3, 0.4, slope + 0.4), (x, eave + 1.05 + rise / 2, z + sgn * half / 2),
                         ROOF, "SmoothPlastic", rot_x(pitch * sgn), collide=False, layer="roof"))
    return model(name, kids)


FLOWER_COLORS = [(232, 92, 96), (244, 206, 76), (236, 236, 240), (176, 108, 220), (255, 150, 70)]
BUNTING_COLORS = [(250, 80, 70), (255, 220, 90), (90, 160, 250), (100, 220, 120), (255, 240, 210)]


def bush(name, x, y, z, rng, scale=1.0):
    y = floor_at(x, z, y)
    fam = canopy_of(name, UNDERSTORY_MIX)
    kids = []
    for k in range(3):
        d = rng.uniform(2.0, 3.2) * scale
        ox, oz = rng.uniform(-0.9, 0.9) * scale, rng.uniform(-0.9, 0.9) * scale
        tone = fam[(1, 0, 2)[LEAVES.index(rng.choice(LEAVES))]]  # the old draw picks body, shade or highlight
        kids.append(part(f"Leaf{k}", (d, d * 0.8, d), (x + ox, y + d * 0.36, z + oz), tone, "SmoothPlastic",
                         rot_y(rng.uniform(0, 90)), shape="Ball", collide=False, query=False, layer="prop"))
    return model(name, kids)


def flower_bed(name, x, y, z, width, depth, yaw, rng):
    """Soil box with a stone edge, a low mound of leaves and a scatter of blooms on it. Tagged
    FlowerBed for butterflies.

    The leaves are two soft LeafyGrass mounds rather than a stem and a leaf per flower (a bed used
    to cost up to 61 parts); the blooms sit on the foliage, so the bed reads fuller for a third of
    the parts. `rng` is drawn exactly as the stem-and-leaf beds drew it, so nothing else in the
    seeded map moves.
    """
    r = rot_y(yaw)
    common = dict(collide=False, query=False, shadow=False)
    kids = [part("Soil", (width, 0.7, depth), (x, y + 0.35, z), (74, 52, 36), "Ground", r, collide=False),
            part("Edge", (width + 0.8, 0.5, depth + 0.8), (x, y + 0.22, z), STONE_DARK, "Cobblestone", r, collide=False)]
    for k, (share, lift, tone) in enumerate(((1.0, 0.0, (70, 124, 48)), (0.62, 0.28, (96, 150, 58)))):
        off = apply(r, ((k - 0.5) * 0.3 * width * (1 - share), 0, 0))
        if k == 1:  # the raised inner mound's footprint, in bed space: only blooms over it stand the 0.28 higher
            mound_u, mound_hw, mound_hd = 0.5 * 0.3 * width * (1 - share), (width * share - 0.2) / 2, depth * 0.35
        kids.append(part(f"Foliage{k}", (width * share - 0.2, 1.0 + lift, depth * (0.9 if k == 0 else 0.7)),
                         (x + off[0], y + 0.75 + lift / 2, z + off[2]), tone, "LeafyGrass", r, **common))
    n = max(6, int(width * depth / 1.6))
    cols, rows = max(1, round(width / 1.1)), max(1, round(depth / 1.1))
    for k in range(n):
        lx = -width / 2 + 0.55 + (k % cols) * (width - 1.1) / max(cols - 1, 1) + rng.uniform(-0.2, 0.2)
        lz = -depth / 2 + 0.5 + ((k // cols) % rows) * (depth - 1.0) / max(rows - 1, 1) + rng.uniform(-0.2, 0.2)
        w = apply(r, (lx, 0, lz))
        fx, fz = x + w[0], z + w[2]
        h = rng.uniform(0.8, 1.4)
        color = rng.choice(FLOWER_COLORS)
        rng.uniform(0, 180)  # the old per-flower leaf's turn, still drawn to keep the seeded sequence
        # Blooms stand just proud of the foliage mound, a little taller where the stem was taller.
        on_mound = abs(lx) < width * 0.31 and abs(lx - mound_u) <= mound_hw and abs(lz) <= mound_hd
        by = y + 1.2 + (0.28 if on_mound else 0.0) + (h - 0.8) * 0.5
        if k % 3 == 2:  # tulip
            kids.append(part(f"Bloom{k}", (0.55, 0.8, 0.55), (fx, by + 0.3, fz), color, "SmoothPlastic",
                             shape="Ball", **common))
        else:  # daisy: flat petal disc tilted slightly toward the sun, dark centre on top
            tilt = mul(rot_y(rng.uniform(0, 360)), rot_x(rng.uniform(8, 22)))
            if k % 3 == 1 and n > 8:  # big beds keep every other daisy's disc only (the centre alone reads at range)
                kids.append(part(f"Centre{k}", (0.42, 0.3, 0.42), (fx, by + 0.12, fz), color,
                                 "SmoothPlastic", tilt, shape="Ball", **common))
                continue
            kids.append(part(f"Petals{k}", (0.08, 0.95, 0.95), (fx, by, fz), color, "SmoothPlastic",
                             mul(tilt, rot_z(90)), shape="Cylinder", **common))
            kids.append(part(f"Centre{k}", (0.32, 0.22, 0.32), (fx, by + 0.08, fz), (255, 214, 80),
                             "SmoothPlastic", tilt, shape="Ball", **common))
    return model(name, kids, attrs={"FlowerBed": True, "BedX": x, "BedY": y + 2.0, "BedZ": z})


def bench(name, x, y, z, yaw):
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))
    back = apply(r, (0, 0, 1))
    kids = [part("Seat", (5.2, 0.4, 1.6), (x, y + 1.6, z), TIMBER, "SmoothPlastic", r),
            part("Back", (5.2, 1.6, 0.35), (x + back[0] * 0.65, y + 2.7, z + back[2] * 0.65), TIMBER, "SmoothPlastic",
                 mul(r, rot_x(-8)), collide=False)]
    for side in (-1, 1):
        kids.append(part(f"Leg{side}", (0.5, 1.4, 1.4), (x + right[0] * side * 2.1, y + 0.7, z + right[2] * side * 2.1),
                         IRON, "SmoothPlastic", r))
    return model(name, kids)


def barrel(name, x, y, z, rng):
    y = floor_at(x, z, y)
    kids = [part("Body", (3.0, 2.6, 2.6), (x, y + 1.5, z), TIMBER, "SmoothPlastic", rot_z(90), shape="Cylinder")]
    for k, hy in enumerate((0.7, 2.3)):
        kids.append(part(f"Band{k}", (0.25, 2.75, 2.75), (x, y + hy, z), IRON, "SmoothPlastic", rot_z(90), shape="Cylinder",
                         collide=False))
    return model(name, kids)


def crate_stack(name, x, y, z, rng):
    y = floor_at(x, z, y)
    return model(name, [
        part("Crate0", (3, 3, 3), (x, y + 1.5, z), TIMBER, "SmoothPlastic", rot_y(rng.uniform(-8, 8))),
        part("Crate1", (2.4, 2.4, 2.4), (x + 0.3, y + 4.2, z - 0.2), TIMBER, "SmoothPlastic",
             rot_y(rng.uniform(10, 30)), collide=False),
        part("Crate2", (2.6, 2.6, 2.6), (x + 3.2, y + 1.3, z + 0.6), TIMBER, "SmoothPlastic",
             rot_y(rng.uniform(-20, -5))),
    ])


def woodpile(name, x, y, z, yaw, rng):
    y = floor_at(x, z, y)
    r = rot_y(yaw)
    kids = []
    for row in range(3):
        for k in range(5 - row):
            off = apply(r, ((k - (4 - row) / 2) * 1.05, 0, 0))
            kids.append(part(f"Log{row}{k}", (1.0, 1.0, 3.6), (x + off[0], y + 0.5 + row * 0.9, z + off[2]), TRUNK,
                             "SmoothPlastic", mul(r, rot_z(rng.uniform(-4, 4))), collide=(row == 0)))
    return model(name, kids)


def hand_cart(name, x, y, z, yaw):
    y = floor_at(x, z, y)
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))
    fwd = apply(r, (0, 0, -1))
    kids = [part("Bed", (4.2, 0.5, 6.0), (x, y + 2.2, z), TIMBER, "SmoothPlastic", mul(r, rot_x(-6))),
            part("SideL", (0.3, 1.4, 5.6), (x + right[0] * 2.0, y + 2.9, z + right[2] * 2.0), TIMBER, "SmoothPlastic",
                 mul(r, rot_x(-6)), collide=False),
            part("SideR", (0.3, 1.4, 5.6), (x - right[0] * 2.0, y + 2.9, z - right[2] * 2.0), TIMBER, "SmoothPlastic",
                 mul(r, rot_x(-6)), collide=False),
            part("Axle", (5.4, 0.35, 0.35), (x, y + 1.8, z), IRON, "Metal", r, collide=False)]
    for side in (-1, 1):
        kids.append(part(f"Wheel{side}", (0.5, 3.6, 3.6), (x + right[0] * side * 2.6, y + 1.8, z + right[2] * side * 2.6),
                         BEAM, "SmoothPlastic", r, shape="Cylinder", collide=False))
        kids.append(part(f"Handle{side}", (0.35, 0.35, 4.0), (x + right[0] * side * 1.6 + fwd[0] * 4.4, y + 2.4,
                                                              z + right[2] * side * 1.6 + fwd[2] * 4.4), BEAM, "SmoothPlastic",
                         mul(r, rot_x(10)), collide=False))
    kids.append(part("Sacks", (3.2, 1.4, 3.6), (x - fwd[0] * 0.4, y + 3.1, z - fwd[2] * 0.4), (255, 214, 150), "SmoothPlastic",
                     mul(r, rot_y(6)), collide=False))
    return model(name, kids)


def hay_bale(name, x, y, z, yaw):
    y = floor_at(x, z, y)
    return model(name, [
        part("Bale", (3.2, 2.2, 2.2), (x, y + 1.1, z), (255, 220, 100), "SmoothPlastic", rot_y(yaw)),
        part("Twine", (3.3, 0.15, 2.3), (x, y + 1.35, z), BEAM, "SmoothPlastic", rot_y(yaw), collide=False),
    ])


def stump(name, x, y, z, rng):
    y = floor_at(x, z, y)
    d = rng.uniform(2.2, 3.0)
    return model(name, [
        part("Stump", (1.4, d, d), (x, y + 0.7, z), TRUNK, "SmoothPlastic", rot_z(90), shape="Cylinder"),
        part("Rings", (0.12, d * 0.7, d * 0.7), (x, y + 1.42, z), (250, 214, 150), "SmoothPlastic", rot_z(90), shape="Cylinder",
             collide=False),
        part("MushroomStem", (0.5, 0.6, 0.5), (x + d / 2 + 0.3, y + 0.3, z + 0.4), (230, 220, 200), "SmoothPlastic",
             collide=False, query=False),
        part("MushroomCap", (0.9, 0.35, 0.9), (x + d / 2 + 0.3, y + 0.72, z + 0.4), (244, 84, 84), "SmoothPlastic",
             shape="Ball", collide=False, query=False),
    ])


def fingerpost(name, x, y, z, boards):
    """Signpost with one pointing board per destination. boards: [(text, yaw_deg, height)]."""
    kids = [part("Post", (0.9, 11, 0.9), (x, y + 5.5, z), BEAM, "SmoothPlastic"),
            part("Finial", (1.3, 1.3, 1.3), (x, y + 11.4, z), GOLD, "Metal", shape="Ball", collide=False)]
    for k, (text, yaw, h) in enumerate(boards):
        r = rot_y(yaw)
        fwd = apply(r, (0, 0, -1))  # the board points along its look vector
        centre = (x + fwd[0] * 3.1, y + h, z + fwd[2] * 3.1)
        kids.append(part(f"Board{k}", (1.4, 1.5, 6.0), centre, BEAM, "SmoothPlastic", r, collide=False,
                         children=[label_gui("Right", text, "", (255, 232, 170), px=50),
                                   label_gui("Left", text, "", (255, 232, 170), px=50)]))
        kids.append(part(f"Point{k}", (1.4, 1.5, 1.4), (x + fwd[0] * 6.4, y + h, z + fwd[2] * 6.4), BEAM,
                         "SmoothPlastic", mul(r, rot_y(45)), collide=False))
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
        kids.append(part(f"Pole{k}", (0.5, height + 0.6, 0.5), (px_, y + (height + 0.6) / 2, pz), BEAM, "SmoothPlastic"))
    kids.append(part("Cord", (seg, 0.12, 0.12), ((ax + bx) / 2, y + height, (az + bz) / 2), BEAM, "SmoothPlastic",
                     rot_y(yaw), collide=False, query=False))
    for k in range(pennants):
        t = (k + 0.5) / pennants
        sag = math.sin(t * math.pi) * 0.9
        cx_, cz_ = ax + dx * seg * t, az + dz * seg * t
        kids.append(part(f"Pennant{k}", (1.4, 1.6, 0.08), (cx_, y + height - sag - 0.85, cz_), BUNTING_COLORS[k % 5],
                         "SmoothPlastic", mul(rot_y(yaw), rot_x(180)), cls="WedgePart", collide=False, query=False,
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
             children=[smoke(4.0, 0.22, 3.5, (226, 214, 202))]),  # pale, so it never reads as soot against the sky
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
            kids.append(part("Post", (0.8, top - y, 0.8), (px_, y + (top - y) / 2, pz), BEAM, "SmoothPlastic"))
    kids.append(part("Awning", (x1 - x0 + 3.2, 0.3, z1 - z0 + 2.4), (npc_x - 0.6, top + 0.4, cz), canopy, "SmoothPlastic",
                     rot_z(-9), collide=False, layer="roof"))
    for k in range(6):
        zk = z0 - 1.2 + (z1 - z0 + 2.4) * (k + 0.5) / 6
        kids.append(part(f"Scallop{k}", (0.12, 0.9, (z1 - z0 + 2.4) / 6 - 0.1), (x0 - 2.1, top - 0.35, zk),
                         canopy if k % 2 else (255, 236, 190), "SmoothPlastic", collide=False, layer="roof"))
    cx0, cx1 = x0 - 0.3, x0 + 2.2
    kids.append(box("CounterTop", cx0 - 0.3, cx1 + 0.2, y + 3.0, y + 3.35, z0 + 0.5, z1 - 0.5, TIMBER, "SmoothPlastic"))
    kids.append(box("CounterFront", cx0 - 0.15, cx0 + 0.15, y, y + 3.0, z0 + 0.7, z1 - 0.7, BEAM, "SmoothPlastic"))
    for k, color in enumerate(((250, 80, 70), (255, 160, 56), (120, 210, 90))):
        zk = z0 + 1.8 + k * 3.4
        kids.append(part(f"Crate{k}", (2.4, 1.2, 2.6), (x0 + 1.0, y + 3.95, zk), TIMBER, "SmoothPlastic", collide=False))
        for j in range(5):
            kids.append(part(f"Fruit{k}{j}", (0.7, 0.7, 0.7), (x0 + 0.5 + (j % 3) * 0.5, y + 4.9 + (j // 3) * 0.4,
                                                                 zk - 0.8 + (j % 2) * 0.8 + (j // 3) * 0.3), color,
                             "SmoothPlastic", shape="Ball", collide=False, query=False, shadow=False))
    kids.append(part("Sacks", (2.2, 1.6, 2.2), (x1 - 1.2, y + 0.8, z1 - 1.6), (255, 214, 150), "SmoothPlastic", rot_y(12)))
    kids.append(part("Basket", (1.6, 1.0, 1.6), (x1 - 1.4, y + 0.5, z0 + 1.6), TIMBER, "SmoothPlastic", rot_z(90),
                     shape="Cylinder", collide=False))
    return model(name, kids, attrs={"Vendor": True, "VendorX": npc_x + 1.2, "VendorY": y, "VendorZ": cz})


SLATE_ROOF = (36, 118, 255)
STONE_WALL = (188, 216, 255)
STONE_WALL_DARK = (64, 144, 255)


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
    kids = [box("Paving", x0 - 1.5, x1 + 1.5, y, y + 0.2, z0 - 1.5, z1 + 2.0, STONE_DARK, "SmoothPlastic", layer="prop")]
    # Walls: back and front (with the opening), sides inset between them so no tops overlap.
    kids.append(box("WallN", x0, x1, y, top, z0, z0 + t, STONE_WALL, "SmoothPlastic"))
    kids.append(box("WallSL", x0, ox0 - 1.2, y, top, z1 - t, z1, STONE_WALL, "SmoothPlastic"))
    kids.append(box("WallSR", ox1 + 1.2, x1, y, top, z1 - t, z1, STONE_WALL, "SmoothPlastic"))
    kids.append(box("WallW", x0, x0 + t, y, top, z0 + t, z1 - t, STONE_WALL, "SmoothPlastic"))
    kids.append(box("WallE", x1 - t, x1, y, top, z0 + t, z1 - t, STONE_WALL, "SmoothPlastic"))
    for k in range(6):  # darker courses break up the stone
        zz = z0 + t + 0.02 if k % 2 else z1 - t - 0.02
        kids.append(box(f"Course{k}", x0 + 2 + k * 5.5, x0 + 5.5 + k * 5.5, y + 2 + (k % 3) * 3.2, y + 3.2 + (k % 3) * 3.2,
                        z0 - 0.1, z0 + 0.1, STONE_WALL_DARK, "SmoothPlastic", collide=False))
    # Timber front frame around the opening and a heavy lintel.
    for px_ in (ox0 - 0.6, ox1 + 0.6):
        kids.append(box("FramePost", px_ - 0.7, px_ + 0.7, y, top - 2.4, z1 - t - 0.3, z1 + 0.3, BEAM, "SmoothPlastic"))
    kids.append(box("Lintel", ox0 - 1.6, ox1 + 1.6, top - 2.4, top - 0.8, z1 - t - 0.35, z1 + 0.35, BEAM, "SmoothPlastic"))
    kids.append(box("LintelBrace", ox0 - 1.2, ox1 + 1.2, top - 0.8, top + 0.6, z1 - t - 0.3, z1 + 0.3, STONE_WALL_DARK,
                    "SmoothPlastic", collide=False))
    # Barred windows on the side walls with a warm glow inside.
    for side, wx in (("W", x0 - 0.2), ("E", x1 + 0.2)):
        for wi, wz in enumerate((z0 + 9, z1 - 9)):
            kids.append(part(f"Window{side}{wi}", (0.4, 2.8, 2.8), (wx, y + 7.2, wz), (255, 178, 96), "SmoothPlastic", collide=False,
                             children=[light(9, 0.9, (255, 170, 90))]))
            for b in (-0.7, 0, 0.7):
                kids.append(part(f"Bar{side}{wi}", (0.5, 3.0, 0.18), (wx, y + 7.2, wz + b), IRON, "SmoothPlastic", collide=False))
            kids.append(part(f"Sill{side}{wi}", (0.9, 0.3, 3.4), (wx, y + 5.7, wz), STONE_WALL_DARK, "SmoothPlastic", collide=False))
    # Low slate roof, ridge along X, stone gables, big overhang.
    pitch, overhang = 22.0, 2.4
    span_z = z1 - z0
    half = span_z / 2 + overhang
    rise = math.tan(math.radians(pitch)) * (span_z / 2)
    slope = half / math.cos(math.radians(pitch))
    for sgn, label in ((-1, "N"), (1, "S")):
        kids.append(part(f"Roof{label}", (x1 - x0 + overhang * 2, 0.7, slope), (cx, top + math.tan(math.radians(pitch)) * (span_z / 4 - overhang / 2),
                                                                             cz + sgn * half / 2), SLATE_ROOF, "SmoothPlastic",
                         rot_x(pitch * sgn), collide=False, layer="roof"))
        kids.append(part(f"Eave{label}", (x1 - x0 + overhang * 2 + 0.4, 0.5, 0.5), (cx, top - 0.35, cz + sgn * (span_z / 2 + overhang - 0.2)),
                         BEAM, "SmoothPlastic", collide=False, layer="roof"))
    kids.append(part("Ridge", (x1 - x0 + overhang * 2 + 0.6, 0.6, 0.9), (cx, top + rise + 0.3, cz), STONE_WALL_DARK, "SmoothPlastic",
                     collide=False, layer="roof"))
    for gx in (x0 + 0.7, x1 - 0.7):
        for sgn, yaw in ((-1, 0), (1, 180)):
            kids.append(part(f"Gable{'N' if sgn < 0 else 'S'}", (1.4, rise, span_z / 2), (gx, top + rise / 2, cz + sgn * span_z / 4),
                             STONE_WALL, "SmoothPlastic", rot_y(yaw), cls="WedgePart", collide=False, layer="roof"))
    # Hearth against the back wall, its stack rising into the chimney through the roof.
    hx, hz = cx + 11, z0 + 4.2
    kids += [
        box("HearthBase", hx - 3.2, hx + 3.2, y + 0.2, y + 3.6, hz - 2.4, hz + 2.4, STONE_WALL_DARK, "SmoothPlastic"),
        box("HearthBack", hx - 3.2, hx + 3.2, y + 3.6, y + 9.0, hz - 2.4, hz - 0.8, STONE_WALL_DARK, "SmoothPlastic", collide=False),
        part("Coals", (4.4, 0.5, 2.6), (hx, y + 3.85, hz + 0.5), EMBER, "Neon", collide=False, query=False, shadow=False,
             children=[fire(5, 10), light(22, 1.8, (255, 140, 70))]),
        part("Hood", (6.0, 0.8, 4.6), (hx, y + 9.2, hz + 0.6), IRON, "SmoothPlastic", collide=False),
        part("HoodFront", (6.0, 2.2, 0.4), (hx, y + 7.9, hz + 2.7), IRON, "SmoothPlastic", collide=False),
        part("Stack", (3.2, top + rise + 5 - (y + 9.6), 3.2), (hx, (y + 9.6 + top + rise + 5) / 2, hz - 0.6), STONE_WALL_DARK,
             "SmoothPlastic", collide=False),
        part("StackCap", (4.0, 0.7, 4.0), (hx, top + rise + 5.35, hz - 0.6), STONE_WALL, "SmoothPlastic", collide=False),
        part("StackFlue", (1.6, 0.3, 1.6), (hx, top + rise + 5.8, hz - 0.6), (44, 112, 240), "SmoothPlastic", collide=False, query=False,
             children=[smoke(5.0, 0.24, 4.0, (226, 214, 202))]),  # pale, so it never reads as soot against the sky
        part("Bellows", (2.6, 1.0, 1.8), (hx - 4.6, y + 2.8, hz + 0.4), BEAM, "SmoothPlastic", rot_y(-20), collide=False),
        part("BellowsHandle", (0.3, 0.3, 2.4), (hx - 5.8, y + 3.4, hz + 1.2), BEAM, "SmoothPlastic", rot_y(-20), collide=False),
    ]
    # Anvil on a stump mid-room, where the smith works.
    ax, az = cx + 3, cz + 4
    kids += [
        part("AnvilStump", (2.0, 3.0, 3.0), (ax, y + 1.2, az), BEAM, "SmoothPlastic", rot_z(90), shape="Cylinder"),
        part("AnvilBase", (1.5, 1.0, 1.8), (ax, y + 2.7, az), IRON, "SmoothPlastic", collide=False),
        part("AnvilTop", (3.6, 0.8, 1.5), (ax, y + 3.6, az), (60, 122, 255), "SmoothPlastic", collide=False),
        part("AnvilHorn", (1.3, 0.55, 0.8), (ax + 2.35, y + 3.7, az), (60, 122, 255), "SmoothPlastic", rot_z(-12), collide=False),
        part("Workpiece", (1.6, 0.24, 0.32), (ax - 0.3, y + 4.12, az), (255, 150, 60), "Neon", collide=False, query=False,
             shadow=False, children=[light(8, 0.7, (255, 140, 60))]),
    ]
    # Quench trough along the east wall, workbench and racks along the west wall, tools on the back wall.
    kids += [
        box("Trough", x1 - t - 2.6, x1 - t - 0.4, y + 0.2, y + 2.4, cz - 4, cz + 4, BEAM, "SmoothPlastic"),
        box("TroughWater", x1 - t - 2.4, x1 - t - 0.6, y + 1.9, y + 2.25, cz - 3.8, cz + 3.8, (90, 190, 255), "Glass",
            collide=False, transparency=0.3),
        box("Bench", x0 + t + 0.4, x0 + t + 3.2, y + 2.6, y + 3.0, z0 + 5, z0 + 13, TIMBER, "SmoothPlastic"),
        box("BenchLegA", x0 + t + 0.6, x0 + t + 1.0, y + 0.2, y + 2.6, z0 + 5.3, z0 + 5.7, BEAM, "SmoothPlastic", collide=False),
        box("BenchLegB", x0 + t + 0.6, x0 + t + 1.0, y + 0.2, y + 2.6, z0 + 12.3, z0 + 12.7, BEAM, "SmoothPlastic", collide=False),
        part("Vise", (1.0, 1.0, 1.4), (x0 + t + 2.4, y + 3.5, z0 + 7), IRON, "SmoothPlastic", collide=False),
        box("RackBoard", x0 + t, x0 + t + 0.4, y + 3.0, y + 8.6, z1 - 12, z1 - 3, BEAM, "SmoothPlastic", collide=False),
    ]
    for k in range(5):  # finished blades hanging on the rack
        zz = z1 - 11 + k * 1.8
        kids.append(part(f"RackBlade{k}", (0.25, 4.0, 0.7), (x0 + t + 0.55, y + 5.4, zz), (200, 220, 255), "SmoothPlastic",
                         rot_x(rng.uniform(-3, 3)), collide=False))
        kids.append(part(f"RackHilt{k}", (0.35, 0.9, 0.35), (x0 + t + 0.55, y + 7.8, zz), BEAM, "SmoothPlastic", collide=False))
        kids.append(part(f"RackGuard{k}", (0.3, 0.25, 1.3), (x0 + t + 0.55, y + 7.35, zz), GOLD, "SmoothPlastic", collide=False))
    for k, (dz, kind) in enumerate(((-11, "tongs"), (-9.2, "hammer"), (-7.4, "tongs"), (-5.6, "hammer"))):
        px_, pz = cx + dz, z0 + t + 0.4
        if kind == "tongs":
            kids.append(part(f"Tool{k}", (0.22, 2.8, 0.22), (px_, y + 7.0, pz), IRON, "SmoothPlastic", rot_z(6), collide=False))
            kids.append(part(f"ToolB{k}", (0.22, 2.8, 0.22), (px_ + 0.35, y + 7.0, pz), IRON, "SmoothPlastic", rot_z(-6), collide=False))
        else:
            kids.append(part(f"Tool{k}", (0.3, 2.4, 0.3), (px_, y + 6.8, pz), TIMBER, "SmoothPlastic", collide=False))
            kids.append(part(f"ToolB{k}", (1.0, 0.5, 0.5), (px_, y + 8.1, pz), IRON, "SmoothPlastic", collide=False))
    kids.append(box("ToolBoard", cx - 12.2, cx - 4.4, y + 5.2, y + 8.8, z0 + t, z0 + t + 0.25, BEAM, "SmoothPlastic", collide=False))
    # Counter across the opening with two display blades; the merchant stands behind it.
    kz = z1 - 0.9
    kids.append(box("CounterTop", ox0 - 0.4, ox1 + 0.4, y + 3.3, y + 3.7, kz - 1.3, kz + 1.0, TIMBER, "SmoothPlastic"))
    kids.append(box("CounterFront", ox0 - 0.2, ox1 + 0.2, y + 0.2, y + 3.3, kz + 0.6, kz + 1.0, BEAM, "SmoothPlastic"))
    kids.append(box("CounterBack", ox0 - 0.2, ox1 + 0.2, y + 0.2, y + 3.3, kz - 1.3, kz - 0.9, BEAM, "SmoothPlastic",
                    collide=False))
    for k, dx in enumerate((-4.5, 4.5)):
        kids.append(part(f"DisplayBlade{k}", (3.8, 0.2, 0.7), (cx + dx, y + 3.85, kz - 0.2), (200, 220, 255), "SmoothPlastic",
                         rot_y(12 * (1 if k else -1)), collide=False))
        kids.append(part(f"DisplayGuard{k}", (0.3, 0.3, 1.3), (cx + dx - 2.0 * (1 if k else -1), y + 3.85, kz - 0.2), GOLD, "SmoothPlastic",
                         rot_y(12 * (1 if k else -1)), collide=False))
    # Hanging shop sign on a bracket at the front corner.
    bx_ = x1 + 0.6
    kids.append(part("SignBracket", (3.6, 0.4, 0.4), (bx_ + 1.1, y + 9.6, z1 - 3), IRON, "SmoothPlastic", collide=False))
    kids.append(part("SignChainA", (0.12, 1.2, 0.12), (bx_ + 1.4, y + 8.9, z1 - 2.2), IRON, "SmoothPlastic", collide=False))
    kids.append(part("SignChainB", (0.12, 1.2, 0.12), (bx_ + 1.4, y + 8.9, z1 - 3.8), IRON, "SmoothPlastic", collide=False))
    kids.append(part("SignBoard", (0.35, 2.6, 3.4), (bx_ + 1.4, y + 7.0, z1 - 3), BEAM, "SmoothPlastic", collide=False,
                     children=[label_gui("Right", "Sword Shop", "Relic blades", (255, 232, 170), px=50),
                               label_gui("Left", "Sword Shop", "Relic blades", (255, 232, 170), px=50)]))
    kids.append(part("SignAnvilIcon", (0.5, 0.6, 1.3), (bx_ + 1.4, y + 5.2, z1 - 3), IRON, "SmoothPlastic", collide=False))
    # Outside: coal heap, ingot stack, water bucket.
    for k in range(5):
        kids.append(part(f"Coal{k}", (rng.uniform(1.2, 2.0), rng.uniform(0.8, 1.3), rng.uniform(1.2, 2.0)),
                         (x1 + 3.5 + rng.uniform(-1, 1), y + 0.5 + k * 0.12, z0 + 6 + rng.uniform(-1.5, 1.5)), (120, 150, 230),
                         "SmoothPlastic", mul(rot_y(rng.uniform(0, 90)), rot_z(rng.uniform(-8, 8))), collide=False))
    for k in range(6):
        kids.append(part(f"Ingot{k}", (2.2, 0.5, 0.9), (x1 + 3.5 + (k % 2) * 1.0 - 0.5, y + 0.45 + (k // 2) * 0.5, z0 + 12 + (k // 2) * 0.1),
                         (160, 190, 250), "SmoothPlastic", rot_y((k // 2) * 90), collide=False))
    return model(name, kids, attrs={"Forge": True, "Smithy": True, "AnvilX": ax - 0.3, "AnvilY": y + 4.1, "AnvilZ": az,
                                    "AnvilStandX": ax - 3.0, "AnvilStandY": y + 0.2, "AnvilStandZ": az,
                                    "CounterX": cx, "CounterY": y + 0.2, "CounterZ": kz - 3.4})


def chest(name, x, y, z, yaw, open_lid=False, rng=None):
    """Iron-banded wooden chest; an open one shows sword hilts standing in it."""
    r = rot_y(yaw)
    kids = [part("Body", (3.4, 1.8, 2.2), (x, y + 0.9, z), TIMBER, "SmoothPlastic", r),
            # Bands stop 0.1 short of the body's top so the two faces never sit coplanar.
            part("BandL", (0.25, 1.6, 2.3), (x + apply(r, (-1.0, 0, 0))[0], y + 0.9, z + apply(r, (-1.0, 0, 0))[2]), IRON, "SmoothPlastic", r, collide=False),
            part("BandR", (0.25, 1.6, 2.3), (x + apply(r, (1.0, 0, 0))[0], y + 0.9, z + apply(r, (1.0, 0, 0))[2]), IRON, "SmoothPlastic", r, collide=False),
            part("Lock", (0.5, 0.6, 0.2), (x + apply(r, (0, 0, -1.15))[0], y + 1.1, z + apply(r, (0, 0, -1.15))[2]), GOLD, "SmoothPlastic", r, collide=False)]
    if open_lid:
        back = apply(r, (0, 0, 1.0))
        kids.append(part("Lid", (3.5, 0.5, 2.3), (x + back[0], y + 2.9, z + back[2]), BEAM, "SmoothPlastic",
                         mul(r, rot_x(-100)), collide=False))
        for k in range(3):
            off = apply(r, ((k - 1) * 0.9, 0, 0.1))
            kids.append(part(f"Hilt{k}", (0.3, 1.3, 0.3), (x + off[0], y + 2.3, z + off[2]), (255, 72, 72), "SmoothPlastic",
                             mul(r, rot_z((k - 1) * 8)), collide=False))
            kids.append(part(f"Guard{k}", (1.0, 0.22, 0.3), (x + off[0], y + 1.75, z + off[2]), GOLD, "SmoothPlastic",
                             mul(r, rot_z((k - 1) * 8)), collide=False))
            kids.append(part(f"Pommel{k}", (0.45, 0.45, 0.45), (x + off[0], y + 3.0, z + off[2]), GOLD, "SmoothPlastic",
                             shape="Ball", collide=False))
    else:
        kids.append(part("Lid", (3.5, 0.5, 2.3), (x, y + 2.05, z), BEAM, "SmoothPlastic", r, collide=False))
    return model(name, kids)


def storage_shack(name, x0, x1, z0, z1, y, rng, turn=0.0):
    """The Vaultkeeper's shack: stacked-log walls on a stone base, plank roof, open doorway on
    the south side, chests and shelves inside. Attribute VaultShack marks it for docs/tools.
    `turn` (degrees) turns the finished shack about its centre: 90 puts the doorway on the east.
    """
    start = len(REGISTRY)
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    wall_h = 9.0
    base_top = y + 0.4
    kids = [box("Base", x0 - 0.8, x1 + 0.8, y, base_top, z0 - 0.8, z1 + 0.8, STONE_DARK, "SmoothPlastic"),
            box("Floor", x0 + 0.6, x1 - 0.6, base_top, base_top + 0.12, z0 + 0.6, z1 - 0.6, TIMBER, "SmoothPlastic", collide=False)]
    # Log walls: horizontal cylinders stacked; the south wall leaves a doorway.
    logs = int(wall_h / 1.15)
    door_w = 5.0
    for k in range(logs):
        ly = base_top + 0.575 + k * 1.15
        shade = BEAM if k % 2 else BEAM
        kids.append(part(f"LogN{k}", (x1 - x0 + 1.2, 1.15, 1.15), (cx, ly, z0), shade, "SmoothPlastic", collide=(k < 3)))
        kids.append(part(f"LogW{k}", (1.15, 1.15, z1 - z0 + 1.2), (x0, ly, cz), shade, "SmoothPlastic", collide=(k < 3)))
        kids.append(part(f"LogE{k}", (1.15, 1.15, z1 - z0 + 1.2), (x1, ly, cz), shade, "SmoothPlastic", collide=(k < 3)))
        if k >= 7:  # above the doorway the south logs run full width
            kids.append(part(f"LogS{k}", (x1 - x0 + 1.2, 1.15, 1.15), (cx, ly, z1), shade, "SmoothPlastic", collide=False))
        else:
            kids.append(part(f"LogSL{k}", (cx - door_w / 2 - x0 + 0.6, 1.15, 1.15), ((x0 - 0.6 + cx - door_w / 2) / 2, ly, z1),
                             shade, "SmoothPlastic", collide=(k < 3)))
            kids.append(part(f"LogSR{k}", (x1 + 0.6 - cx - door_w / 2, 1.15, 1.15), ((cx + door_w / 2 + x1 + 0.6) / 2, ly, z1),
                             shade, "SmoothPlastic", collide=(k < 3)))
    # Invisible wall proxies so the round logs feel solid.
    top = base_top + logs * 1.15
    for label, (a0, a1, b0, b1) in (("N", (x0 - 0.6, x1 + 0.6, z0 - 0.6, z0 + 0.6)), ("W", (x0 - 0.6, x0 + 0.6, z0, z1)),
                                    ("E", (x1 - 0.6, x1 + 0.6, z0, z1))):
        kids.append(box(f"Proxy{label}", a0, a1, base_top, top, b0, b1, (255, 0, 255), transparency=1, query=False, shadow=False))
    kids.append(box("ProxySL", x0 - 0.6, cx - door_w / 2, base_top, top, z1 - 0.6, z1 + 0.6, (255, 0, 255), transparency=1, query=False, shadow=False))
    kids.append(box("ProxySR", cx + door_w / 2, x1 + 0.6, base_top, top, z1 - 0.6, z1 + 0.6, (255, 0, 255), transparency=1, query=False, shadow=False))
    for px_ in (cx - door_w / 2 - 0.5, cx + door_w / 2 + 0.5):
        kids.append(box("DoorPost", px_ - 0.5, px_ + 0.5, base_top, base_top + 7 * 1.15, z1 - 0.7, z1 + 0.7, BEAM, "SmoothPlastic"))
    kids.append(box("DoorLintel", cx - door_w / 2 - 1.0, cx + door_w / 2 + 1.0, base_top + 7 * 1.15, base_top + 7 * 1.15 + 0.8,
                    z1 - 0.7, z1 + 0.7, BEAM, "SmoothPlastic", collide=False))
    # Plank roof: two slabs meeting at a ridge along X, plus a rear chimney-less cap.
    pitch, overhang = 26.0, 1.8
    span_z = z1 - z0
    half = span_z / 2 + overhang
    rise = math.tan(math.radians(pitch)) * (span_z / 2)
    slope = half / math.cos(math.radians(pitch))
    for sgn, label in ((-1, "N"), (1, "S")):
        kids.append(part(f"Roof{label}", (x1 - x0 + overhang * 2, 0.6, slope), (cx, top + math.tan(math.radians(pitch)) * (span_z / 4 - overhang / 2),
                                                                             cz + sgn * half / 2), BEAM, "SmoothPlastic",
                         rot_x(pitch * sgn), collide=False, layer="roof"))
    kids.append(part("RoofRidge", (x1 - x0 + overhang * 2 + 0.4, 0.5, 0.8), (cx, top + rise + 0.25, cz), BEAM, "SmoothPlastic",
                     collide=False, layer="roof"))
    for gx in (x0 + 0.5, x1 - 0.5):
        for sgn, yaw in ((-1, 0), (1, 180)):
            kids.append(part(f"Gable{'N' if sgn < 0 else 'S'}", (1.1, rise, span_z / 2), (gx, top + rise / 2, cz + sgn * span_z / 4),
                             BEAM, "SmoothPlastic", rot_y(yaw), cls="WedgePart", collide=False, layer="roof"))
    # Inside: chests along the back and side walls, one open; shelves with crates and sacks.
    fl = base_top + 0.12
    kids.append(chest("ChestOpen", cx - 4.2, fl, z0 + 2.4, 0, open_lid=True))
    kids.append(chest("Chest1", cx, fl, z0 + 2.4, 0))
    kids.append(chest("Chest2", cx + 4.2, fl, z0 + 2.4, 0))
    kids.append(chest("Chest3", x0 + 2.4, fl, cz + 1.0, 90))
    kids.append(chest("Chest4", x0 + 2.4, fl, cz + 4.4, 90))
    kids.append(box("Shelf1", x1 - 2.6, x1 - 1.0, fl + 3.2, fl + 3.5, z0 + 1.2, z1 - 1.2, BEAM, "SmoothPlastic", collide=False))
    kids.append(box("Shelf2", x1 - 2.6, x1 - 1.0, fl + 6.0, fl + 6.3, z0 + 1.2, z1 - 1.2, BEAM, "SmoothPlastic", collide=False))
    for k, zz in enumerate((z0 + 2.4, z0 + 5.4, z1 - 3.0)):
        kids.append(part(f"ShelfCrate{k}", (1.4, 1.4, 1.4), (x1 - 1.8, fl + 4.2, zz), TIMBER, "SmoothPlastic", rot_y(k * 17), collide=False))
    kids.append(part("ShelfSack", (1.5, 1.2, 1.5), (x1 - 1.8, fl + 6.9, cz), (255, 214, 150), "SmoothPlastic", collide=False))
    kids.append(part("ShelfJar", (0.6, 0.9, 0.6), (x1 - 1.8, fl + 6.75, z0 + 2.4), (110, 220, 255), "Glass", rot_z(90),
                     shape="Cylinder", collide=False, transparency=0.3))
    # Keeper's desk by the door with a ledger and lantern.
    kids.append(box("Desk", cx + 1.4, cx + 5.0, fl + 2.5, fl + 2.8, z1 - 5.2, z1 - 3.2, TIMBER, "SmoothPlastic"))
    for dx, dz in ((cx + 1.7, z1 - 5.0), (cx + 4.7, z1 - 5.0), (cx + 1.7, z1 - 3.4), (cx + 4.7, z1 - 3.4)):
        kids.append(part("DeskLeg", (0.3, 2.5, 0.3), (dx, fl + 1.25, dz), BEAM, "SmoothPlastic", collide=False))
    kids.append(part("Ledger", (1.4, 0.25, 1.0), (cx + 3.2, fl + 2.95, z1 - 4.2), (255, 72, 72), "SmoothPlastic", rot_y(-12), collide=False))
    kids.append(part("DeskLantern", (0.9, 1.2, 0.9), (cx + 4.4, fl + 3.4, z1 - 3.6), LANTERN, "Neon", collide=False, query=False,
                     shadow=False, transparency=0.15, children=[light(14, 1.0)]))
    # Hanging sign by the door.
    kids.append(part("SignBracket", (0.3, 0.3, 2.6), (cx + door_w / 2 + 1.6, base_top + 7.4, z1 + 1.0), IRON, "SmoothPlastic", collide=False))
    kids.append(part("SignBoard", (2.8, 1.6, 0.3), (cx + door_w / 2 + 1.6, base_top + 6.2, z1 + 2.0), BEAM, "SmoothPlastic",
                     collide=False, children=[label_gui("Front", "Vault", "", (255, 232, 170), px=60),
                                              label_gui("Back", "Vault", "", (255, 232, 170), px=60)]))
    kids.append(lamp_post("DoorLamp", cx - door_w / 2 - 2.4, y, z1 + 2.6, yaw_facing(1, 0)))
    shack = model(name, kids, attrs={"VaultShack": True, "InsideX": cx - 1.0, "InsideY": fl, "InsideZ": z1 - 6.0})
    return turned(shack, turn, (cx, cz), start) if turn else shack


def campfire(name, x, y, z, rng):
    y = floor_at(x, z, y)
    kids = []
    for k in range(7):
        a = k / 7 * math.tau
        kids.append(part(f"Stone{k}", (1.4, 0.9, 1.2), (x + math.cos(a) * 2.4, y + 0.45, z + math.sin(a) * 2.4),
                         STONE_DARK, "SmoothPlastic", rot_y(math.degrees(-a)), collide=False))
    for k in range(3):
        kids.append(part(f"Log{k}", (0.8, 0.8, 4.2), (x, y + 0.6, z), BEAM, "SmoothPlastic",
                         mul(rot_y(k * 60), rot_x(18)), collide=False))
    kids.append(part("Embers", (1.2, 0.4, 1.2), (x, y + 0.5, z), EMBER, "Neon", collide=False, query=False,
                     shadow=False, children=[fire(4, 7), light(22, 1.6, (255, 160, 90))]))
    return model(name, kids)


def scaffold(name, x, y, z, yaw, length, height=16):
    y = floor_at(x, z, y)
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
    y = floor_at(x, z, y)
    r = rot_y(yaw)
    kids = [part("Body", (4.5, 2.6, 6.5), (x, y + 2.3, z), (88, 70, 54), "WoodPlanks", r),
            part("Load", (3.8, 1.2, 5.6), (x, y + 3.7, z), ROCK_GRAY, "Slate", r, collide=False)]
    right = apply(r, (1, 0, 0))
    fwd = apply(r, (0, 0, 1))
    for sx in (-1, 1):
        for sz in (-1, 1):
            wx = x + right[0] * sx * 2.4 + fwd[0] * sz * 2.2
            wz = z + right[2] * sx * 2.4 + fwd[2] * sz * 2.2
            kids.append(part(f"Wheel{sx}{sz}", (0.6, 1.8, 1.8), (wx, y + 0.9, wz), RUST, "CorrodedMetal", r, shape="Cylinder",
                             collide=False))
    return model(name, kids)


def rail_run(name, a, b, y=None, gauge=1.6, piece=6.0):
    """Two rusted rails on wooden sleepers from a=(x, z) to b=(x, z), any heading. Laid in short
    pieces that each rest on floor_at under their own ends, so one run follows a haul ramp's
    slope as readily as flat ground; sleepers sit every 3 studs. Nothing here collides."""
    (ax, az), (bx, bz) = a, b
    seg = math.hypot(bx - ax, bz - az)
    dx, dz = (bx - ax) / seg, (bz - az) / seg
    nx, nz = -dz, dx  # perpendicular, for the two rails and the sleepers' long axis
    yaw = math.degrees(math.atan2(-dz, dx))  # rails run along local X, like cliff chunks

    def height(s):
        return floor_at(ax + dx * s, az + dz * s, y if y is not None else 0.0)

    kids = []
    s, i = 0.0, 0
    while s < seg - 0.3:
        length = min(piece, seg - s)
        y0, y1 = height(s), height(s + length)
        pitch = math.degrees(math.atan2(y1 - y0, length))  # rot_z(+a) raises the +X (far) end
        r = mul(rot_y(yaw), rot_z(pitch))
        run = math.hypot(length, y1 - y0)
        cx, cz, cy = ax + dx * (s + length / 2), az + dz * (s + length / 2), (y0 + y1) / 2
        for side in (-1, 1):
            kids.append(part(f"Rail{i}{'L' if side < 0 else 'R'}", (run + 0.3, 0.35, 0.4),
                             (cx + nx * gauge * side, cy + 0.18, cz + nz * gauge * side), RUST, "CorrodedMetal", r,
                             collide=False, layer="prop"))
        s += length
        i += 1
    s, k = 1.0, 0
    while s < seg - 1.0:
        x, z = ax + dx * s, az + dz * s
        y0, y1 = height(max(0.0, s - 0.5)), height(min(seg, s + 0.5))
        pitch = math.degrees(math.atan2(y1 - y0, 1.0))
        kids.append(part(f"Sleeper{k}", (1.0, 0.25, 2 * gauge + 2.0), (x, (y0 + y1) / 2 + 0.1, z), TRUNK, "Wood",
                         mul(rot_y(yaw), rot_z(pitch)), collide=False, layer="prop"))
        s += 3.0
        k += 1
    return model(name, kids)


def rail_track(name, x, y, z0, z1):
    """Straight rails along Z (the mid-bench spur); see rail_run for the general case."""
    return rail_run(name, (x, z0), (x, z1), y)


def stone_stack(name, x, y, z, rng, color=(186, 160, 120)):
    y = floor_at(x, z, y)
    kids = []
    layers = rng.randint(1, 3)
    for lv in range(layers):
        for k in range(max(1, 3 - lv)):
            w = rng.uniform(4.5, 6)
            kids.append(part(f"Block{lv}_{k}", (w, 3.2, w * 0.8),
                             (x + (k - (2 - lv) / 2) * 6.3, y + 1.6 + lv * 3.2, z + rng.uniform(-0.6, 0.6)),
                             color, "Limestone", rot_y(rng.uniform(-6, 6)), collide=(lv == 0)))
    return model(name, kids)


def tent(name, x, y, z, yaw, color=(60, 196, 245)):
    y = floor_at(x, z, y)
    r = rot_y(yaw)
    kids = []
    for sgn in (-1, 1):
        off = apply(r, (sgn * 2.05, 0, 0))
        kids.append(part(f"Cloth{sgn}", (7.5, 0.3, 6.2), (x + off[0], y + 2.3, z + off[2]), color, "SmoothPlastic",
                         mul(r, rot_z(-sgn * 48)), collide=False))
    kids.append(part("Ridge", (0.5, 0.5, 8), (x, y + 4.6, z), BEAM, "SmoothPlastic", mul(r, rot_y(90)), collide=False))
    return model(name, kids)


def banner_pole(name, x, y, z, yaw, color=WARLORD_RED):
    y = floor_at(x, z, y)
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))
    return model(name, [
        part("Pole", (0.7, 14, 0.7), (x, y + 7, z), BEAM, "SmoothPlastic"),
        part("Cloth", (3.6, 7, 0.25), (x + right[0] * 2.1, y + 9.5, z + right[2] * 2.1), color, "SmoothPlastic", r,
             collide=False),
        part("Finial", (1, 1, 1), (x, y + 14.5, z), GOLD, "SmoothPlastic", collide=False, shape="Ball"),
    ])


def brazier(name, x, y, z):
    y = floor_at(x, z, y)
    return model(name, [
        part("Base", (2.6, 3.2, 2.6), (x, y + 1.6, z), STONE_DARK, "SmoothPlastic"),
        part("Bowl", (3.6, 1.2, 3.6), (x, y + 3.8, z), IRON, "SmoothPlastic", collide=False),
        part("Coals", (2.6, 0.5, 2.6), (x, y + 4.4, z), EMBER, "Neon", collide=False, query=False, shadow=False,
             children=[fire(5, 8), light(26, 1.4, (255, 150, 80))]),
    ])


def waystone(name, waypoint_id, x, y, z, glow=(120, 210, 240)):
    """Giant crystal waystone: a glowing shard cluster on a rough stone base.

    The tallest shard is named Core: MapTravel puts the travel prompt on it, and HubAmbience
    slowly turns the FloatShard pieces around the cluster.
    """
    y = floor_at(x, z, y)
    rng = random.Random(zlib.crc32(waypoint_id.encode()) & 0xFFFF)
    kids = [part("Base", (1.6, 7.6, 7.6), (x, y + 0.8, z), STONE_DARK, "SmoothPlastic", rot_z(90), shape="Cylinder")]
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
    # id, archetype, level, role, (x, z), leash — [TUNING] rim bench → mid bench → pit, see FIRST_SLICE.md
    ("IL_S1", "IronSquire", 1, "minion", (-36, 206), 20),
    ("IL_S2", "IronSquire", 1, "minion", (34, 200), 20),
    ("IL_S3", "IronSquire", 2, "minion", (-6, 224), 20),
    ("IL_S4", "IronSquire", 2, "minion", (-46, 268), 20),
    ("IL_S5", "IronSquire", 3, "minion", (50, 278), 20),
    ("IL_S6", "IronSquire", 3, "minion", (-14, 306), 20),
    ("IL_B1", "IronBerserker", 3, "minion", (40, 314), 22),
    ("IL_S7", "IronSquire", 4, "minion", (-66, 348), 20),
    ("IL_B2", "IronBerserker", 4, "minion", (44, 350), 22),
    ("IL_B3", "IronBerserker", 5, "minion", (-44, 359), 22),
    ("IL_S8", "IronSquire", 4, "minion", (66, 390), 20),
    ("IL_E1", "IronBerserker", 6, "elite", (-142, 300), 18),
    ("IL_BOSS", "Boss_Gorgon", 10, "boss", (0, 432), 50),
]

WAYPOINTS = [
    # id, display, region, (x, y, z) arrival, facing yaw, order — waystone models carry WaypointId
    ("HubSpawn", "Hearthmere", "Hub", (0, HUB_Y, -40), 180.0, 1),
    ("IronOverlook", "Quarry Overlook", "IronLowlands", (18, HUB_Y, 152), 180.0, 2),
    ("WarlordGate", "Warlord's Gate", "IronLowlands", (0, QUARRY_Y, 358), 180.0, 3),
    ("BriarGate", "Briarwood Gate", "Briarwood", (0, QUARRY_Y, 500), 180.0, 4),
    ("GroveEdge", "Grove's Edge", "Briarwood", (10, QUARRY_Y, 782), 180.0, 5),
    ("FrostHollow", "Frost Hollow", "FrostboundGlacier", (-142, HUB_Y, 14), yaw_facing(-1, 0), 6),
    ("GargoyleRidge", "Gargoyle Ridge", "FrostboundGlacier", (-366, 30.0, -44), yaw_facing(-0.4, 1), 7),
]


def build_markers():
    npcs = model("NPCs", [
        marker("QuestMaster", (15, HUB_Y + 0.2, 50), yaw_facing(-1, 0)),
        marker("Merchant", (-63, HUB_Y + 0.2, -24.6), yaw_facing(0, 1)),
        marker("SkillTrainer", (58, HUB_Y, -12), yaw_facing(0, 1)),
        marker("RebirthKeeper", (64, HUB_Y, 22), yaw_facing(0, -1)),
        # the Vault faces the south road, across it from the Quest Master (its doorway on the east)
        marker("Vaultkeeper", (-20, HUB_Y + 0.52, 49), yaw_facing(1, 0)),
        # the town spin wheel (WorldLayout reads this; the Upgrade Stall stands 17 studs to its
        # right, north toward the plaza): on the south road's east side, beside the Quest Master
        marker("SpinWheel", (22, HUB_Y, 30), yaw_facing(-1, 0)),
    ], cls="Folder")
    safe = model("SafeZones", [
        volume("Hub", -100, 100, 0, 90, -100, 100, attrs={"Region": "Hub"}),
        volume("IronOverlook", -40, 40, 0, 90, 100, 168, attrs={"Region": "IronLowlands"}),
        volume("BriarGate", -20, 20, 0, 90, 472, 528, attrs={"Region": "Briarwood"}),
        volume("FrostHollow", -184, -104, 0, 90, -56, 56, attrs={"Region": "FrostboundGlacier"}),
    ], cls="Folder")
    regions = model("Regions", [
        volume("Hub", -100, 100, 0, 120, -100, 100,
               attrs={"DisplayName": "Hearthmere", "Subtitle": "Safe haven", "Order": 0}),
        volume("IronLowlands", -170, 112, 0, 120, 100, 472,
               attrs={"DisplayName": "Iron Lowlands", "Subtitle": "Recommended Lv 1 - 10", "Order": 1}),
        volume("Briarwood", -140, 140, 0, 120, 472, 942,
               attrs={"DisplayName": "Briarwood", "Subtitle": "Recommended Lv 9 - 14", "Order": 2}),
        volume("FrostboundGlacier", -484, -104, 0, 140, -154, 92,
               attrs={"DisplayName": "Frostbound Glacier", "Subtitle": "Recommended Lv 18 - 25", "Order": 3}),
    ], cls="Folder")
    spawns = []
    for zone, table in (("IronLowlands", ENEMY_SPAWNS), ("Briarwood", BRIAR_SPAWNS), ("FrostboundGlacier", GLACIER_SPAWNS)):
        for sid, arch, level, role, (x, z), leash in table:
            spawns.append(marker(sid, (x, floor_at(x, z, QUARRY_Y), z), 0, attrs={
                "Archetype": arch, "Level": level, "Role": role, "Zone": zone,
                "Region": zone, "LeashRadius": leash}))
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
        marker("FrostboundGlacier", (-100, HUB_Y, 0), 0, attrs={"DisplayName": "Frostbound Glacier", "Region": "FrostboundGlacier", "Sealed": False, "RequiredLevel": 18}),
        marker("InfernalCaldera", (100, HUB_Y, 0), 0, attrs={"DisplayName": "Infernal Caldera", "Region": "InfernalCaldera", "Sealed": True, "RequiredLevel": 34}),
        marker("CelestialSummit", (0, HUB_Y, -100), 0, attrs={"DisplayName": "Celestial Summit", "Region": "CelestialSummit", "Sealed": True, "RequiredLevel": 80}),
        marker("VoidRift", (68, HUB_Y, -72), 0, attrs={"DisplayName": "Void Rift", "Region": "VoidRift", "Sealed": True, "RequiredLevel": 55}),
        marker("Briarwood", (0, QUARRY_Y, 470), 0, attrs={"DisplayName": "Briarwood", "Region": "Briarwood", "Sealed": False, "RequiredLevel": 9}),
    ], cls="Folder")
    # A Persistent model is sent to every client on join and never streamed out, so client UI
    # (region banner, travel menu, quest guide) can read markers anywhere on the map.
    markers = model("Markers", [npcs, safe, regions, enemy, waypoints, gates, spawn_location],
                    attrs={"SchemaVersion": 1})
    markers["properties"] = {"ModelStreamingMode": "Persistent"}
    return markers


# ── Hearthmere High Street kit ────────────────────────────────────────────────
# The north road from the plaza to the Ascension Gate is the town's street: shopfronts and houses
# line both sides on a flagstone walk, behind a raised curb and a dark gutter course. The kit is lean
# on purpose (a closed plaster body, a front dressed with doors, framed windows, shutters, flower
# boxes, awnings and hanging signs, a real roof), since every face but the street front is seen
# only from afar. Palette: sun-bleached whitewash and lemon, peach and cream plaster under
# terracotta, teal, berry and orange roofs, with bright shutters: warm and friendly, Lemonade's own.
TOWN_PLINTH = (64, 144, 255)
TOWN_TRIM = (240, 120, 20)
TOWN_GLASS = (110, 220, 255)
# The High Street's walks are PS99's lavender-white walkway (a pale tint, calm), edged by a raised
# curb in the same lavender-blue at full chroma, the way PS99 trims its pale paths in a deeper blue.
TOWN_CURB = (116, 142, 252)  # the raised curb: vivid periwinkle, the walk's hue pushed to full colour
TOWN_GUTTER = GROUND_TAN
TOWN_WALK = (226, 232, 255)  # the flagstone walk: lavender-white, the cool calm beside the cream road
WHITEWASH = (255, 242, 220)  # calm: a pale warm tint
LEMON_WASH = (255, 220, 40)  # lemon at full chroma: the pop wall
PEACH_WASH = (255, 150, 90)
CREAM_WASH = (255, 234, 198)
TERRACOTTA = (255, 104, 48)
ROOF_TEAL = (20, 200, 228)
ROOF_BERRY = (248, 50, 124)
ROOF_ORANGE = (255, 150, 20)
AWNING_CREAM = (255, 234, 186)


def town_house(name, fx, fz, out, width, depth, y, rng, storeys=2, roof="eaves", wall=WHITEWASH,
               roof_color=TERRACOTTA, roof_material="SmoothPlastic", shutter=(80, 200, 215), awning=None,
               sign_text=None, door_color=BEAM, chimney=True, smoky=False, pitch=34.0,
               storey_h=(8.6, 7.2), shop=False, flowers=True):
    """A street-fronted town building. (fx, fz) is the middle of the front wall's face; `out` is the
    outward normal of that front ((±1, 0) or (0, ±1)); the body runs `depth` studs inward and
    `width` along the street. roof='eaves' puts the ridge along the street, 'gable' turns the gable
    to it. Two-storey buildings jetty their upper floor 0.9 over the walk on a timber beam.
    """
    R = rot_y(yaw_facing(*out))

    def at(u, h, d):
        v = apply(R, (u, 0, d))
        return (fx + v[0], y + h, fz + v[2])

    def P(pname, size, u, h, d, color, material, turn=None, **kw):
        return part(pname, size, at(u, h, d), color, material, mul(R, turn) if turn else R, **kw)

    W, D = width, depth
    s1 = storey_h[0]
    s2 = storey_h[1] if storeys > 1 else 0.0
    base = 1.3  # plinth top: the walk is at +0.5, so the doorstep climbs 0.8
    top = base + s1 + s2
    d0 = -0.9 if storeys > 1 else 0.0  # front face of the top storey
    kids = [
        P("Plinth", (W + 0.6, 1.7, D + 0.6), 0, 0.45, D / 2, TOWN_PLINTH, "SmoothPlastic"),
        P("SmoothPlastic", (W, s1, D), 0, base + s1 / 2, D / 2, wall, "SmoothPlastic"),
    ]
    if storeys > 1:
        kids.append(P("Upper", (W, s2, D - d0), 0, base + s1 + s2 / 2, (D + d0) / 2, wall, "SmoothPlastic"))
        kids.append(P("JettyBeam", (W + 0.4, 0.8, 1.3), 0, base + s1 - 0.1, -0.45, TOWN_TRIM, "SmoothPlastic", collide=False))
    # Timber corner posts on the ground storey, and a head beam under the eaves.
    for side in (-1, 1):
        kids.append(P(f"Corner{side}", (0.8, s1, 0.8), side * (W / 2 - 0.25), base + s1 / 2, -0.15, TOWN_TRIM, "SmoothPlastic",
                      collide=False))
    # Its top sits 0.08 under the wall's (flush, the two tops z-fought where the beam bites the wall).
    kids.append(P("HeadBeam", (W + 0.3, 0.7, 0.5), 0, top - 0.43, d0 - 0.1, TOWN_TRIM, "SmoothPlastic", collide=False))

    def window(tag, u, hc, face, w=2.6, h=3.0, shutters=True, box=False):
        kids.append(P(f"Frame{tag}", (w + 0.7, h + 0.7, 0.3), u, hc, face - 0.1, TOWN_TRIM, "SmoothPlastic", collide=False))
        kids.append(P(f"Glass{tag}", (w, h, 0.2), u, hc, face - 0.2, TOWN_GLASS, "Glass", collide=False, query=False,
                      extra={"Reflectance": 0.18}))
        kids.append(P(f"Mullion{tag}", (0.22, h, 0.24), u, hc, face - 0.24, TOWN_TRIM, "SmoothPlastic", collide=False,
                      query=False, shadow=False))
        if shutters:
            for sgn in (-1, 1):
                kids.append(P(f"Shutter{tag}{sgn}", (w / 2 - 0.1, h + 0.5, 0.2), u + sgn * (w / 2 + w / 4 + 0.35),
                              hc, face - 0.12, shutter, "SmoothPlastic", collide=False, query=False, shadow=False))
        if box:
            by = hc - h / 2 - 0.75
            kids.append(P(f"FlowerBox{tag}", (w + 0.6, 0.7, 0.9), u, by, face - 0.45, TOWN_TRIM, "SmoothPlastic",
                          collide=False))
            kids.append(P(f"Leaves{tag}", (w + 0.4, 0.7, 0.8), u, by + 0.6, face - 0.5, (110, 232, 110), "SmoothPlastic",
                          collide=False, query=False, shadow=False))
            for k in range(3):
                kids.append(P(f"Bloom{tag}{k}", (0.65, 0.65, 0.65), u + (k - 1) * (w / 3), by + 1.05, face - 0.55,
                              rng.choice(FLOWER_COLORS), "SmoothPlastic", shape="Ball", collide=False, query=False,
                              shadow=False))

    # Ground storey: the door off-centre, a shop window or a house window beside it.
    door_u = -W / 2 + 3.0 if W >= 10 else 0.0
    kids.append(P("DoorFrame", (4.0, 7.4, 0.3), door_u, base + 3.7, -0.1, TOWN_TRIM, "SmoothPlastic", collide=False))
    kids.append(P("Door", (3.0, 6.8, 0.3), door_u, base + 3.4, -0.2, door_color, "SmoothPlastic", collide=False))
    kids.append(P("Step", (4.4, 0.8, 1.4), door_u, 0.9, -0.7, TOWN_PLINTH, "SmoothPlastic"))
    rest = W / 2 - (door_u + 2.0)  # frontage left of the door, beside it
    if W >= 10:
        wu = door_u + 2.0 + rest / 2
        if shop:
            window("Shop", wu, base + 3.4, 0.0, w=min(rest - 2.2, 6.0), h=3.8, shutters=False, box=False)
        else:
            window("G", wu, base + 3.8, 0.0, shutters=False, box=flowers)
    if awning and W >= 10:
        # Striped awning over the shop window and door, sloping out over the walk.
        aw = W - 1.0
        drop = math.radians(22)
        reach = 3.0
        strips = max(3, round(aw / 1.7))
        ah = base + s1 - 0.9
        for k in range(strips):
            su = -aw / 2 + aw * (k + 0.5) / strips
            kids.append(P(f"Awning{k}", (aw / strips, 0.22, reach), su, ah - math.sin(drop) * reach / 2,
                          -math.cos(drop) * reach / 2, awning if k % 2 == 0 else AWNING_CREAM, "SmoothPlastic",
                          rot_x(-22), collide=False, query=False, layer="roof"))
        kids.append(P("Valance", (aw, 0.7, 0.14), 0, ah - math.sin(drop) * reach - 0.3, -math.cos(drop) * reach - 0.02,
                      awning, "SmoothPlastic", collide=False, query=False, shadow=False, layer="roof"))
    # Upper storey (or the attic of a single storey): two shuttered windows, flower boxes below.
    if storeys > 1:
        hc = base + s1 + s2 * 0.5
        slots = [-(W / 2 - 3.1), W / 2 - 3.1] if W >= 11.6 else [0.0]
        for k, u in enumerate(slots):
            window(f"U{k}", u, hc, d0, box=flowers and k == len(slots) - 1)
    if sign_text:
        # Upstairs it hangs over the awning; on a single storey it hangs just past the front's
        # corner, below the eaves, clear of the awning.
        su = W / 2 - 1.4 if storeys > 1 else W / 2 + 0.2
        sh = base + s1 + 0.9 if storeys > 1 else base + s1 - 3.1
        sd = d0 if storeys > 1 else 0.0
        kids.append(P("SignArm", (0.3, 0.3, 3.2), su, sh + 1.15, sd - 1.6, (44, 112, 240), "SmoothPlastic", collide=False))
        kids.append(P("SignBoard", (0.3, 2.0, 2.6), su, sh, sd - 1.9, TOWN_TRIM, "SmoothPlastic", collide=False,
                      children=[label_gui("Left", sign_text, "", (255, 232, 170), px=60),
                                label_gui("Right", sign_text, "", (255, 232, 170), px=60)]))
    # Roof.
    ov = 1.2
    span_d = D - d0
    dc = (D + d0) / 2
    tp = math.tan(math.radians(pitch))
    if roof == "eaves":
        half = span_d / 2 + ov
        rise = tp * span_d / 2
        slope_len = half / math.cos(math.radians(pitch))
        for sgn in (-1, 1):
            kids.append(P(f"Roof{sgn}", (W + 1.6, 0.9, slope_len), 0, top + tp * (span_d / 4 - ov / 2), dc + sgn * half / 2,
                          roof_color, roof_material, rot_x(pitch * sgn), collide=False, layer="roof"))
        for gu in (-W / 2 + 0.5, W / 2 - 0.5):
            for sgn, yaw in ((-1, 0), (1, 180)):
                kids.append(P(f"Gable{sgn}", (1, rise, span_d / 2), gu, top + rise / 2, dc + sgn * span_d / 4, wall,
                              "SmoothPlastic", rot_y(yaw), cls="WedgePart", collide=False, layer="roof"))
        kids.append(P("Ridge", (W + 1.8, 0.6, 1.1), 0, top + rise + 0.45, dc, TOWN_TRIM, "SmoothPlastic", collide=False,
                      layer="roof"))
    else:
        half = W / 2 + ov
        rise = tp * W / 2
        slope_len = half / math.cos(math.radians(pitch))
        for sgn in (-1, 1):
            kids.append(P(f"Roof{sgn}", (slope_len, 0.9, span_d + 1.6), sgn * half / 2, top + tp * (W / 4 - ov / 2),
                          dc - 0.4, roof_color, roof_material, rot_z(-pitch * sgn), collide=False, layer="roof"))
        for gd in (d0 + 0.5, D - 0.5):
            for sgn, yaw in ((-1, 90), (1, -90)):
                kids.append(P(f"Gable{sgn}", (1, rise, W / 2), sgn * W / 4, top + rise / 2, gd, wall, "SmoothPlastic",
                              rot_y(yaw), cls="WedgePart", collide=False, layer="roof"))
        # A diamond attic window in the street gable.
        ah = top + rise * 0.38
        kids.append(P("AtticFrame", (2.0, 2.0, 0.3), 0, ah, d0 - 0.1, TOWN_TRIM, "SmoothPlastic", rot_z(45), collide=False))
        kids.append(P("AtticGlass", (1.4, 1.4, 0.2), 0, ah, d0 - 0.2, TOWN_GLASS, "Glass", rot_z(45), collide=False,
                      query=False, extra={"Reflectance": 0.18}))
        kids.append(P("Ridge", (1.1, 0.6, span_d + 1.8), 0, top + rise + 0.45, dc - 0.4, TOWN_TRIM, "SmoothPlastic",
                      collide=False, layer="roof"))
    if chimney:
        cu, cd = (W * 0.28, D * 0.62) if roof == "eaves" else (W * 0.22, D * 0.75)
        ch_top = top + rise + 2.2
        kids.append(P("Chimney", (2.0, ch_top - top + 1.0, 2.0), cu, (top - 1.0 + ch_top) / 2, cd, (250, 120, 90),
                      "SmoothPlastic", collide=False))
        kids.append(P("ChimneyCap", (2.6, 0.5, 2.6), cu, ch_top + 0.25, cd, TOWN_PLINTH, "SmoothPlastic", collide=False,
                      children=[smoke(2.6, 0.2, 3.0, (236, 228, 218))] if smoky else None))
    return model(name, kids)


def street_stall(name, x, z, out, rng, canopy=(246, 196, 52), length=7.0, goods=((236, 204, 60), (232, 96, 70))):
    """A market stall on the walk: four posts, a striped awning sloping toward the customers, a
    plank counter along the front, and two crates of produce on it. `out` faces the customers."""
    R = rot_y(yaw_facing(*out))

    def P(pname, size, u, h, d, color, material, turn=None, **kw):
        v = apply(R, (u, 0, d))
        return part(pname, size, (x + v[0], HUB_Y + h, z + v[2]), color, material, mul(R, turn) if turn else R, **kw)

    L, Dp = length, 4.2
    kids = []
    for su in (-1, 1):
        for sd, hh in ((-1, 7.4), (1, 8.4)):
            kids.append(P("Post", (0.6, hh, 0.6), su * (L / 2 - 0.3), hh / 2, sd * (Dp / 2 - 0.3), TOWN_TRIM, "SmoothPlastic"))
    strips = 4
    for k in range(strips):
        su = -L / 2 - 0.4 + (L + 0.8) * (k + 0.5) / strips
        kids.append(P(f"Canopy{k}", ((L + 0.8) / strips, 0.2, Dp + 1.8), su, 8.0, -0.1,
                      canopy if k % 2 == 0 else AWNING_CREAM, "SmoothPlastic", rot_x(-16), collide=False, query=False,
                      layer="roof"))
    kids.append(P("Valance", (L + 0.8, 0.6, 0.12), 0, 6.9, -Dp / 2 - 1.05, canopy, "SmoothPlastic", collide=False,
                  query=False, shadow=False, layer="roof"))
    kids.append(P("Counter", (L - 0.4, 0.35, 1.8), 0, 3.2, -Dp / 2 + 1.1, TIMBER, "SmoothPlastic"))
    kids.append(P("CounterFront", (L - 0.6, 3.0, 0.3), 0, 1.5, -Dp / 2 + 0.3, BEAM, "SmoothPlastic"))
    for k, color in enumerate(goods):
        cu = (k - 0.5) * (L * 0.45)
        kids.append(P(f"Crate{k}", (2.4, 0.9, 1.5), cu, 3.8, -Dp / 2 + 1.1, TIMBER, "SmoothPlastic", collide=False,
                      shadow=False))
        kids.append(P(f"Heap{k}", (2.1, 0.8, 1.2), cu, 4.35, -Dp / 2 + 1.1, color, "SmoothPlastic",
                      rot_y(rng.uniform(-6, 6)), shape="Ball", collide=False, query=False, shadow=False))
    kids.append(P("Sack", (1.8, 1.6, 1.6), L / 2 - 1.4, 0.8, Dp / 2 - 1.2, (255, 214, 150), "SmoothPlastic", rot_y(rng.uniform(-20, 20)),
                  collide=False, shadow=False))
    return model(name, kids)


def street_lamp(name, x, y, z, yaw=0.0):
    """High Street lamp: a slim post on a stone footing, an iron arm, and a small lantern (hood,
    warm glass, base plate) hanging from it. `yaw` turns the arm (its look vector) over the road."""
    fwd = apply(rot_y(yaw), (0, 0, -1))
    r = rot_y(yaw)
    lx, lz = x + fwd[0] * 2.2, z + fwd[2] * 2.2
    iron = (44, 112, 240)
    return model(name, [
        part("Footing", (1.3, 0.8, 1.3), (x, y + 0.4, z), TOWN_PLINTH, "SmoothPlastic", r),
        part("Post", (0.6, 9.6, 0.6), (x, y + 5.2, z), TOWN_TRIM, "SmoothPlastic", r),
        part("Arm", (0.3, 0.3, 2.8), (x + fwd[0] * 1.2, y + 9.7, z + fwd[2] * 1.2), iron, "SmoothPlastic", r, collide=False),
        part("Hood", (1.2, 0.4, 1.2), (lx, y + 9.25, lz), iron, "SmoothPlastic", mul(r, rot_y(45)), collide=False, shadow=False),
        part("Glow", (0.7, 1.0, 0.7), (lx, y + 8.55, lz), (255, 206, 138), "Neon", r, collide=False, query=False,
             shadow=False, transparency=0.35, children=[light(18, 1.0)]),
        part("Plate", (0.95, 0.2, 0.95), (lx, y + 7.95, lz), iron, "SmoothPlastic", r, collide=False, query=False, shadow=False),
    ])


def planter(name, x, z, rng, w=2.6):
    """A stone planter box with a leafy mound and blooms, for building corners."""
    y = HUB_Y + 0.5
    kids = [part("Box", (w, 1.4, w), (x, y + 0.7, z), TOWN_PLINTH, "Cobblestone", collide=True),
            part("Leaves", (w * 0.95, w * 0.75, w * 0.95), (x, y + 1.6, z), (78, 136, 52), "LeafyGrass", shape="Ball",
                 collide=False, query=False, shadow=False)]
    for k in range(2):
        a = rng.uniform(0, math.tau)
        kids.append(part(f"Bloom{k}", (0.6, 0.6, 0.6), (x + math.cos(a) * w * 0.3, y + 2.1 + k * 0.2, z + math.sin(a) * w * 0.3),
                         rng.choice(FLOWER_COLORS), "SmoothPlastic", shape="Ball", collide=False, query=False,
                         shadow=False))
    return model(name, kids)


def street_bunting(name, a, b, heights, rng, pennants=10, sag=1.4):
    """A pennant line strung across the street between two fronts (no poles); `heights` gives the
    cord's height at a and at b."""
    ax, az = a
    bx, bz = b
    ya, yb = heights
    seg = math.hypot(bx - ax, bz - az)
    dx, dz = (bx - ax) / seg, (bz - az) / seg
    yaw = math.degrees(math.atan2(-dz, dx))

    def cord_y(t):  # two straight runs down to the sag at the middle
        return ya + (yb - ya) * t - sag * (2 * t if t <= 0.5 else 2 * (1 - t))

    kids = []
    for half in (0, 1):
        t0, t1 = half * 0.5, half * 0.5 + 0.5
        p0 = (ax + dx * seg * t0, cord_y(t0), az + dz * seg * t0)
        p1 = (ax + dx * seg * t1, cord_y(t1), az + dz * seg * t1)
        kids.append(beam(f"Cord{half}", p0, p1, 0.12, BEAM, "SmoothPlastic", collide=False, query=False, shadow=False))
    for k in range(pennants):
        t = (k + 0.5) / pennants
        cx_, cz_ = ax + dx * seg * t, az + dz * seg * t
        kids.append(part(f"Pennant{k}", (1.3, 1.5, 0.08), (cx_, cord_y(t) - 0.8, cz_),
                         [(246, 200, 50), (232, 88, 80), (90, 200, 215), (255, 240, 210), (240, 140, 60)][k % 5],
                         "SmoothPlastic", mul(rot_y(yaw), rot_x(180)), cls="WedgePart", collide=False, query=False,
                         shadow=False, layer="roof"))
    return model(name, kids, attrs={"Bunting": True})


# ── Hub: Hearthmere ───────────────────────────────────────────────────────────
def build_hub(rng):
    ground = [slab("HubFloor", -104, 104, -104, 104, HUB_Y, GRASS, "SmoothPlastic")]
    road = HUB_Y + 0.2
    ground += disc("Plaza", 0, 0, 27, road + 0.1, 0.7, PATH, "SmoothPlastic")
    ground += [
        box("RoadSouth", -8, 8, road - 0.6, road, 25, 104, PATH, "SmoothPlastic", layer="ground"),
        # The High Street's surface is painted in voxel Terrain by WorldTerrain.server.luau (cobbles
        # worn to earth down the cart line, grass and soil creeping in at the gutters); this slab
        # keeps its collision and is hidden at runtime.
        box("RoadNorth", -8, 8, road - 0.6, road, -104, -25, PATH, "SmoothPlastic", layer="ground",
            attrs={"TerrainPaving": True}),
        box("RoadWest", -104, -25, road - 0.6, road, -8, 8, PATH, "SmoothPlastic", layer="ground"),
        box("RoadEast", 25, 104, road - 0.6, road, -8, 8, PATH, "SmoothPlastic", layer="ground"),
        box("ShopYard", -84, -40, road - 0.6, road, -18, -8, PATH_EDGE, "SmoothPlastic", layer="ground"),
        box("TrainingYard", 42, 86, road - 0.6, road, -48, -8, PATH, "SmoothPlastic", layer="ground"),
        box("QuestCourt", 8, 26, road - 0.6, road, 40, 62, PATH_EDGE, "SmoothPlastic", layer="ground"),
    ]
    visual = []
    proxies = []

    # Perimeter cliffs with 24-stud gate openings at each side's midpoint.
    wall_h = 38  # crest ≈ Y48, level with the quarry's (Y2 + 46) and Briarwood's walls
    g = 19.5  # gate half-width 12 + pillar 7 + clearance: the wall meets the pillar's outer face
    segments = [
        ((-100, -100), (-g, -100), -1), ((g, -100), (100, -100), -1),   # north (play area to +Z)
        ((100, -100), (100, -g), -1), ((100, g), (100, 100), -1),       # east
        ((100, 100), (g, 100), -1), ((-g, 100), (-100, 100), -1),       # south
        ((-100, 100), (-100, g), -1), ((-100, -g), (-100, -100), -1),   # west
    ]
    # The canyon walls themselves are sculpted voxel Terrain (lemonade-game/Map/WorldTerrain.server.luau:
    # broken crags, stepped ledges, crevices and overhangs painted in horizontal strata, scree at the
    # foot), so no visible wall parts are made here. cliff_run still lays out each run (and draws
    # from `rng` exactly as before, so nothing else in the map moves) for its invisible proxy, which
    # reaches PROXY_TOP and keeps holding players in wherever the rock's crest dips.
    for i, (a, b, inward) in enumerate(segments):
        _, proxy = cliff_run(f"HubCliff{i}", a, b, inward, HUB_Y, wall_h, HUB_ROCK, HUB_ROCK_DARK, rng,
                             depth=16, material="Rock")
        proxies.append(proxy)
    REGISTRY[:] = [e for e in REGISTRY if not (e["layer"] == "cliff" and (
        re.match(r"^HubCliff\d+_\d+(_cap)?$", e["name"]) or e["name"] == "CornerBastion"))]

    # Hearthmere castle wall: chunky cream-sandstone masonry with rounded, crenellated corner and
    # gatehouse towers all the way around the ring -- every side (the Ascension, Iron Lowlands,
    # Caldera and Frostbound gates alike), not just the north stretch a player first sees from the
    # plaza. Wrapping all four sides is deliberate: a facade on only one side read as a stone
    # front tacked onto an otherwise bare dirt-brown canyon, not a cobblestone castle. The rest of
    # the ring's height (the crest above the facade, and behind it) stays the sculpted canyon rock
    # WorldTerrain.server.luau builds at runtime, so Hearthmere still reads as a fortress built
    # into the canyon rather than a wall floating apart from it. No gate itself is moved or
    # resized -- these towers only flank each one. Everything here is decorative
    # (CanCollide=False): cliff_run's own invisible proxies, generated above unchanged, still hold
    # players in along the whole ring.
    castle_rng = random.Random(20260921)
    visual.append(castle_wall("CastleWallNW", (-100, -100), (-19.5, -100), -1, HUB_Y, castle_rng))
    visual.append(castle_wall("CastleWallNE", (19.5, -100), (100, -100), -1, HUB_Y, castle_rng))
    visual.append(castle_wall("CastleWallEN", (100, -100), (100, -19.5), -1, HUB_Y, castle_rng))
    visual.append(castle_wall("CastleWallES", (100, 19.5), (100, 100), -1, HUB_Y, castle_rng))
    visual.append(castle_wall("CastleWallSE", (100, 100), (19.5, 100), -1, HUB_Y, castle_rng))
    visual.append(castle_wall("CastleWallSW", (-19.5, 100), (-100, 100), -1, HUB_Y, castle_rng))
    visual.append(castle_wall("CastleWallWS", (-100, 100), (-100, 19.5), -1, HUB_Y, castle_rng))
    visual.append(castle_wall("CastleWallWN", (-100, -19.5), (-100, -100), -1, HUB_Y, castle_rng))
    # Heights are picked clear of the wall's own course tops (y 34/34.6/35.6/40 above HUB_Y=10) so
    # a tower trunk or rim never lands exactly coplanar with the wall body, its buttress caps or
    # its parapet lip: an exact match there is invisible in the model but z-fights in Studio.
    visual.append(castle_tower("CastleTowerNW", -100, -100, HUB_Y, castle_rng, height=34))
    visual.append(castle_tower("CastleTowerNE", 100, -100, HUB_Y, castle_rng, height=34))
    visual.append(castle_tower("CastleTowerSE", 100, 100, HUB_Y, castle_rng, height=34))
    visual.append(castle_tower("CastleTowerSW", -100, 100, HUB_Y, castle_rng, height=34))
    visual.append(castle_tower("CastleTowerGateNW", -24, -100, HUB_Y, castle_rng, radius=6.5, height=28))
    visual.append(castle_tower("CastleTowerGateNE", 24, -100, HUB_Y, castle_rng, radius=6.5, height=28))
    visual.append(castle_tower("CastleTowerGateSW", -24, 100, HUB_Y, castle_rng, radius=6.5, height=28))
    visual.append(castle_tower("CastleTowerGateSE", 24, 100, HUB_Y, castle_rng, radius=6.5, height=28))
    visual.append(castle_tower("CastleTowerGateEN", 100, -24, HUB_Y, castle_rng, radius=6.5, height=28))
    visual.append(castle_tower("CastleTowerGateES", 100, 24, HUB_Y, castle_rng, radius=6.5, height=28))
    visual.append(castle_tower("CastleTowerGateWN", -100, -24, HUB_Y, castle_rng, radius=6.5, height=28))
    visual.append(castle_tower("CastleTowerGateWS", -100, 24, HUB_Y, castle_rng, radius=6.5, height=28))

    # Monument: a sword in a stepped stone plinth, orientation landmark at the plaza centre.
    mon = []
    for k, (w, h) in enumerate(((13, 1.2), (9.5, 1.4), (6.5, 3.2))):
        base = HUB_Y + 0.2 + sum(hh for _, hh in ((13, 1.2), (9.5, 1.4), (6.5, 3.2))[:k])
        mon.append(part(f"Step{k}", (w, h, w), (0, base + h / 2, 0), STONE if k < 2 else STONE_DARK, "SmoothPlastic",
                        rot_y(45 * k)))
    top = HUB_Y + 0.2 + 5.8
    tilt = rot_z(7)
    axis = apply(tilt, (0, 1, 0))  # every piece is placed along the tilted blade axis

    def along(distance):
        return tuple(axis[i] * distance + (0, top, 0)[i] for i in range(3))

    # Distances along the axis from where the blade enters the stone (negative = buried).
    mon += [
        part("Blade", (0.6, 12, 2.2), along(4.5), (200, 220, 255), "Metal", tilt, collide=False),  # -1.5 .. 10.5
        part("Fuller", (0.64, 9, 0.5), along(5.2), (150, 176, 240), "Metal", tilt, collide=False),
        part("Guard", (1.2, 0.9, 7), along(10.95), GOLD, "Metal", tilt, collide=False),
        part("Grip", (0.9, 3.2, 0.9), along(13.0), BEAM, "SmoothPlastic", tilt, collide=False),
        part("Pommel", (1.6, 1.6, 1.6), along(15.2), GOLD, "Metal", tilt, collide=False, shape="Ball"),
    ]
    visual.append(model("SwordMonument", mon))

    # Spawn pad + travel board.
    visual += disc("SpawnPad", 0, -40, 6, HUB_Y + 0.45, 0.5, STONE, "SmoothPlastic", collide=False, layer="decal")
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
    visual.append(timber_house("TrainerHut", 70, 88, -50, -36, HUB_Y, 10, "W", rng, door_w=5, roof_color=(80, 150, 240), door=True))
    visual.append(fence_run("TrainingFenceN", (42, -50), (70, -50), road))
    visual.append(fence_run("TrainingFenceW", (42, -49.5), (42, -10), road, gap=(26, 40), skip_first_post=True))
    visual.append(fence_run("TrainingFenceE", (88, -36), (88, -10), road))
    for k, (x, z) in enumerate(((52, -40), (60, -30), (68, -22), (76, -28))):
        visual.append(model(f"Dummy{k}", [
            part("Post", (0.8, 6, 0.8), (x, HUB_Y + 3, z), BEAM, "SmoothPlastic", collide=False),
            part("Body", (2.4, 3, 1.4), (x, HUB_Y + 4.4, z), (255, 214, 120), "SmoothPlastic", collide=False),
            part("Arms", (5, 0.6, 0.6), (x, HUB_Y + 5.2, z), BEAM, "SmoothPlastic", collide=False),
        ], attrs={"TrainingDummy": True}))  # HubAmbience: the Skill Trainer practises on these
    visual.append(sign("TrainerSign", 50, HUB_Y, -10.5, 180, 10, 3.6, "Skill Trainer", "Reset your skill points"))

    # Rebirth shrine (south-east): octagonal dais, pillars, a pale floating crystal.
    visual += disc("ShrineDais", 64, 40, 15, HUB_Y + 1.2, 1.2, STONE, "SmoothPlastic", layer="prop")
    visual += disc("ShrineInner", 64, 40, 9, HUB_Y + 2.2, 1.0, (210, 198, 255), "SmoothPlastic", layer="prop")
    for k in range(4):
        a = math.radians(45 + 90 * k)
        px, pz = 64 + math.cos(a) * 12, 40 + math.sin(a) * 12
        visual.append(part(f"ShrinePillar{k}", (2.4, 14, 2.4), (px, HUB_Y + 1.2 + 7, pz), (222, 212, 255), "SmoothPlastic"))
        visual.append(part(f"ShrineCap{k}", (3.4, 1, 3.4), (px, HUB_Y + 15.7, pz), GOLD, "Metal", collide=False))
    visual.append(hologram_sword("RebirthHologram", 64, HUB_Y + 2.2, 40))
    visual.append(sign("ShrineSign", 76, HUB_Y, 22, yaw_facing(0, -1), 10, 3.6, "Rebirth Shrine", "Begin again, stronger"))

    # Quest court beside the route out: the Quest Master's market stall, open toward the road.
    visual.append(quest_stall("QuestStall", 14, HUB_Y + 0.2, 50))

    # Houses and dressing (north-west, south-west).
    visual.append(timber_house("HouseNW1", -86, -60, -90, -70, HUB_Y, 11, "S", rng, door=True))
    visual.append(timber_house("HouseNW2", -48, -26, -88, -68, HUB_Y, 10, "S", rng, wall_color=LEMON_WASH,
                               roof_color=ROOF, door=True))
    visual.append(timber_house("HouseSW", -86, -64, 66, 90, HUB_Y, 10, "E", rng, roof_color=(64, 200, 210), door=True))
    visual.append(timber_house("HouseSE", 46, 68, 76, 94, HUB_Y, 10, "W", rng, wall_color=PEACH_WASH,
                               roof_color=(255, 160, 56), door=True))
    visual.append(barrel("BarrelSE", 70, HUB_Y, 92, rng))
    # the Vault: on the south road's west side, opposite the Quest Master, its door to the road
    visual.append(storage_shack("VaultShack", -31, -13, 41, 57, HUB_Y, rng, turn=90))
    visual.append(woodpile("WoodpileNW", -58, HUB_Y, -84, 0, rng))
    visual.append(crate_stack("CratesNW", 16, HUB_Y, -79.5, rng))  # in the Vault lane, clear of the High Street
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
    for k, (x, z, w, d) in enumerate(((-24, -34, 8, 3.2), (24, -34, 8, 3.2), (-24, 34, 8, 3.2), (36, 40, 8, 3.2),
                                      (-36, -22, 3.2, 8), (36, 22, 3.2, 8))):
        visual.append(flower_bed(f"Bed{k}", x, HUB_Y, z, w, d, 0, rng))
    # Market corner by the well: produce stall, gathering fire with log seats.
    visual.append(market_stall("ProduceStall", -38, HUB_Y, 52, rng))
    visual.append(campfire("GatheringFire", -24, HUB_Y, 66, rng))
    for k in range(3):
        a = math.radians(30 + 120 * k)
        visual.append(part(f"SeatLog{k}", (1.2, 1.2, 4.4), (-24 + math.cos(a) * 4.8, HUB_Y + 0.6, 66 + math.sin(a) * 4.8),
                           BEAM, "SmoothPlastic", mul(rot_y(-math.degrees(a)), rot_z(90)), shape="Cylinder"))
    # Waterfall on the east cliff into a pool.
    visual.append(waterfall("Waterfall", 100, HUB_Y, 72, rng))
    # Trainer yard extras.
    visual.append(hay_bale("Hay0", 80, HUB_Y + 0.2, -14, 20))
    visual.append(hay_bale("Hay1", 83, HUB_Y + 0.2, -18, -30))
    visual.append(hay_bale("Hay2", 81.5, HUB_Y + 2.4, -16, 5))
    visual.append(part("YardRack", (6, 5, 0.9), (48, HUB_Y + 2.5, -46), BEAM, "SmoothPlastic"))
    for j in range(4):
        visual.append(part(f"YardRackBlade{j}", (0.4, 4.2, 1), (46 + j * 1.3, HUB_Y + 3.6, -45.4), (188, 216, 255), "SmoothPlastic",
                           collide=False))
    # Bushes, stumps and boulders soften the edges.
    for k, (x, z) in enumerate(((-92, -40), (-92, 30), (92, -30), (92, 40), (-30, 92), (30, 92), (-60, -92), (60, -92),
                                (-40, -60), (44, -70), (76, 64), (-70, 50), (-94, 62), (94, 90), (-26, 84))):
        visual.append(bush(f"Bush{k:02d}", x, HUB_Y, z, rng, scale=rng.uniform(0.9, 1.5)))
    for k, (x, z) in enumerate(((-78, -52), (28, -74), (-24, 20), (44, 62))):
        visual.append(stump(f"Stump{k}", x, HUB_Y, z, rng))
    for k, (x, z) in enumerate(((-94, -34), (94, -62), (-50, 94), (82, 94), (-94, 86))):
        visual.append(rock_cluster(f"HubBoulder{k}", x, HUB_Y, z, rng, color=ROCK_GRAY, size=0.9))
    visual.append(well("Well", -50, HUB_Y, 48, rng))

    # Sealed destinations: visible milestones through barred gates.
    visual.append(gate("GateIronLowlands", 0, HUB_Y, 100, 0, 24, 22, "Iron Lowlands", "Lv 1 - 10  |  Open",
                       sealed=False, region="IronLowlands", required_level=1))
    visual.append(gate("GateFrostbound", -100, HUB_Y, 0, -90, 24, 22, "Frostbound Glacier", "Lv 18 - 25  |  Open",
                       sealed=False, accent=(110, 180, 250), region="FrostboundGlacier", required_level=18))
    visual.append(gate("GateCaldera", 100, HUB_Y, 0, 90, 24, 22, "Infernal Caldera", "Lv 34+  |  Coming soon",
                       sealed=True, accent=(250, 120, 50), region="InfernalCaldera", required_level=34))
    visual.append(gate("GateAscension", 0, HUB_Y, -100, 180, 24, 26, "Ascension Gate", "Celestial Summit  |  Coming soon",
                       sealed=True, stone=CELESTIAL, accent=GOLD, region="CelestialSummit", required_level=80))
    # Vistas behind sealed gates (collidable floors, unreachable past the portcullis).
    for k in range(8):  # celestial stair rising north
        z0 = -104 - k * 6
        visual.append(box(f"AscensionStep{k}", -10, 10, 0, HUB_Y + 1.5 * (k + 1), z0 - 6, z0, CELESTIAL, "SmoothPlastic",
                          layer="vista"))
    for side in (-1, 1):
        for k in range(3):
            visual.append(part(f"AscensionColumn{side}{k}", (3, 22 + k * 4, 3),
                               (side * 11, HUB_Y + 11 + k * 6, -112 - k * 14), CELESTIAL, "SmoothPlastic", collide=False,
                               layer="vista"))
    visual.append(box("CalderaVista", 104, 150, 0, HUB_Y, -14, 14, CALDERA, "SmoothPlastic", layer="vista"))
    visual.append(part("CalderaGlow", (3, 10, 20), (140, HUB_Y + 5, 0), EMBER, "Neon", collide=False, query=False,
                       transparency=0.35, layer="vista", children=[light(40, 2.0, (255, 120, 50))]))
    for k in range(3):
        visual.append(part(f"MineBeam{k}", (1.4, 14, 1.4), (118 + k * 8, HUB_Y + 7, 10 - k), BEAM, "SmoothPlastic",
                           collide=False, layer="vista"))

    # Void Rift portal (sealed) in the north-east quarter.
    vr = []
    fx, fz, yaw = 68, -72, yaw_facing(-1, 1)
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))
    for side in (-1, 1):
        vr.append(part(f"VoidPillar{side}", (4, 18, 4), (fx + right[0] * side * 8, HUB_Y + 9, fz + right[2] * side * 8),
                       VOID, "SmoothPlastic", r))
    vr.append(part("VoidArch", (21, 3.5, 4.4), (fx, HUB_Y + 19.5, fz), VOID, "SmoothPlastic", r))
    vr.append(part("VoidVeil", (12, 16, 0.4), (fx, HUB_Y + 8.5, fz), VOID_GLOW, "ForceField", r, collide=True,
                   query=False, transparency=0.3, shadow=False, children=[light(20, 0.9, VOID_GLOW)]))
    vr.append(sign("VoidSign", fx - 9, HUB_Y, fz + 9, yaw_facing(-1, 1), 9, 3.4, "Void Rift", "Lv 55+  |  Coming soon",
                   board=(120, 70, 200), text=(220, 190, 255)))
    visual.append(model("VoidRiftPortal", vr, attrs={"Region": "VoidRift", "Sealed": True, "RequiredLevel": 55}))

    # Trees in the green quarters, lamp posts along roads.
    # (Three spots moved off the High Street's frontage: (-30, -54), (-20, -80), (-14, -62).)
    tree_spots = [(-88, -54), (-70, -58), (-36, -58), (-34, -96), (36, -48),
                  (48, -62), (86, -64), (24, -28), (-28, 24),
                  (-70, 30), (-34, 66), (-18, 86), (-88, 46), (36, 86),
                  (40, 70), (86, 16), (36, -88), (-88, 12), (-40, 90)]  # (36, -88): where the Vault stood
    for k, (x, z) in enumerate(tree_spots):
        visual.append(tree(f"Tree{k:02d}", x, HUB_Y, z, rng))
    lamps = [(11, 78), (-90, 11), (78, 11)]  # one per road (the High Street has its own); more crowded the plaza
    for k, (x, z) in enumerate(lamps, start=1):
        visual.append(lamp_post(f"Lamp{k}", x, HUB_Y, z, yaw_facing(-x, 0) if abs(x) < 20 else yaw_facing(0, -z)))
    high_street(ground, visual)
    return ground, visual, proxies


def high_street(ground, visual):
    """Hearthmere's High Street: the north road from the plaza to the Ascension Gate, lined with
    shopfronts and houses. Draws only from its own seeded Random, so the shared map rng (and every
    region generated after the hub) is untouched."""
    trng = random.Random(20260919)
    walk_top = HUB_Y + 0.5
    z_end, z_gate = -41.0, -95.5
    for side in (-1, 1):
        sx = side
        # Gutter course (dark, flush with the cobbles), a raised pale curb, then the flagstone walk.
        ground.append(box(f"Gutter{'W' if side < 0 else 'E'}", *sorted((sx * 8.0, sx * 8.8)), HUB_Y - 0.4, HUB_Y + 0.27,
                          z_gate, z_end, TOWN_GUTTER, "SmoothPlastic", layer="ground"))
        ground.append(box(f"Curb{'W' if side < 0 else 'E'}", *sorted((sx * 8.8, sx * 9.6)), HUB_Y - 0.4, HUB_Y + 0.62,
                          z_gate, z_end + 0.4, TOWN_CURB, "SmoothPlastic", layer="ground"))
        ground.append(box(f"Walk{'W' if side < 0 else 'E'}", *sorted((sx * 9.6, sx * 14.0)), HUB_Y - 0.4, walk_top,
                          z_gate, z_end, TOWN_WALK, "SmoothPlastic", layer="ground"))
    ground.append(box("WalkForecourt", -17.0, -14.0, HUB_Y - 0.4, walk_top, -94.0, -84.0, TOWN_WALK, "SmoothPlastic",
                      layer="ground"))

    # East row (fronts face west, lit by the afternoon sun): bakery, a tall gabled house, the tailor.
    visual.append(town_house("Bakery", 14, -48, (-1, 0), 12, 12, HUB_Y, trng, wall=LEMON_WASH, roof_color=TERRACOTTA,
                             shutter=(72, 200, 220), awning=(250, 90, 80), sign_text="Bakery", shop=True, smoky=True))
    visual.append(town_house("GableHouseE", 14, -64, (-1, 0), 12, 11, HUB_Y, trng, roof="gable", wall=WHITEWASH,
                             roof_color=ROOF_TEAL, roof_material="SmoothPlastic", shutter=(240, 186, 56),
                             door_color=(70, 170, 190), storey_h=(8.6, 7.6), pitch=42.0))
    visual.append(town_house("Tailor", 14, -87.5, (-1, 0), 11, 6.6, HUB_Y, trng, storeys=1, wall=PEACH_WASH,
                             roof_color=ROOF_BERRY, roof_material="SmoothPlastic", awning=(72, 200, 220),
                             sign_text="Tailor", shop=True, storey_h=(9.6, 0.0), pitch=40.0, chimney=False))
    # West row: the Lemon Press cafe, a gabled house, a little lemon-washed cottage. It is kept to a
    # single storey: the mid-afternoon sun comes from the west, and taller fronts here would shade
    # the whole street; low ones throw their eaves' and gables' shadows only across its near half.
    visual.append(town_house("LemonPress", -14, -55.5, (1, 0), 12, 11, HUB_Y, trng, storeys=1, wall=CREAM_WASH,
                             roof_color=ROOF_ORANGE, shutter=(120, 210, 90), awning=(246, 196, 52),
                             sign_text="Lemon Press", shop=True, storey_h=(9.8, 0.0), pitch=30.0, smoky=True))
    visual.append(town_house("GableHouseW", -14, -71.5, (1, 0), 13, 10, HUB_Y, trng, storeys=1, roof="gable",
                             wall=PEACH_WASH, roof_color=TERRACOTTA, shutter=(100, 170, 250), door_color=(230, 80, 80),
                             storey_h=(9.4, 0.0), pitch=40.0))
    visual.append(town_house("Cottage", -17, -89, (1, 0), 10, 6, HUB_Y, trng, storeys=1, roof="gable", wall=LEMON_WASH,
                             roof_color=ROOF_TEAL, roof_material="SmoothPlastic", shutter=(250, 100, 90),
                             storey_h=(9.0, 0.0), pitch=45.0, chimney=False))

    # Stalls where people stop: one at the plaza end, one in the cottage's forecourt by the gate.
    visual.append(street_stall("FruitStall", 12.3, -36.5, (-1, 0), trng))
    visual.append(street_stall("FlowerStall", -13.2, -89, (1, 0), trng, canopy=(232, 88, 80),
                               goods=((244, 150, 190), (250, 226, 120))))
    visual.append(fingerpost("StreetSign", 10.6, HUB_Y, -30.5, [("Ascension Gate", yaw_facing(0, -1), 9.6),
                                                              ("Sword Shop", yaw_facing(-1, 0), 8.0)]))
    # Lamps every eight studs or so, alternating sides of the walk.
    for k, (x, z) in enumerate(((10.9, -47), (-10.9, -55), (10.9, -62), (-10.9, -70), (10.9, -78), (-10.9, -81),
                                (10.9, -92))):
        visual.append(street_lamp(f"StreetLamp{k}", x, walk_top, z, yaw_facing(-x, 0)))
    # Barrels and crates against the walls and in the alley mouths; planters at the corners.
    for k, (x, z) in enumerate(((12.4, -71.6), (15.6, -71.8), (15.8, -56.0), (18.5, -56.3), (-15.8, -63.2),
                                (12.2, -94.0), (12.5, -91.3))):
        visual.append(barrel(f"StreetBarrel{k}", x, walk_top if abs(x) < 14 else HUB_Y, z, trng))
    visual.append(crate_stack("StreetCrates", -20, HUB_Y, -81.5, trng))
    for k, (x, z) in enumerate(((-12.2, -48.8), (12.2, -43.0), (12.2, -83.6))):
        visual.append(planter(f"Planter{k}", x, z, trng))
    # Pennant lines strung between the upper floors, zig-zagging down the street.
    visual.append(street_bunting("StreetBunting0", (-13.8, -53.0), (13.1, -49.0), (HUB_Y + 10.6, HUB_Y + 15.6), trng))
    visual.append(street_bunting("StreetBunting1", (13.1, -61.0), (-13.8, -68.0), (HUB_Y + 15.8, HUB_Y + 10.2), trng))


# ── Horizon: far mountain ranges ─────────────────────────────────────────────
# Aerial perspective, staged: every far layer is its own base colour pulled toward HAZE (the pale
# blue the sky shows just over the walls) by how far away it stands, and split into a warm sunlit
# half and a cool blue shaded half, so each range reads as lit form seen through air rather than a
# flat cut-out. The Atmosphere adds its share on top.
HAZE = (194, 210, 234)


def haze(color, f):
    return tuple(round(c + (h - c) * f) for c, h in zip(color, HAZE))


HORIZON_SUN = (156, 130, 108)    # warm sunlit rock, muted: even the near ridge stands behind a mile of air
HORIZON_SHADE = (58, 74, 122)   # cool shaded rock, lit only by the blue sky
HORIZON_SNOW = (255, 250, 240)
HORIZON_SNOW_SHADE = (176, 196, 232)
# The south country is sculpted in build_south_country; the colours above are the north, east and
# west ranges'.
HORIZON_EYE = (0.0, 20.0, 13.0)  # the town's main path, south of the Sword Monument
# Sky space. Past about 510-575 studs this game's parts drop out of view in play (thin facets
# first: the sculpted ranges' triangles vanished piecemeal at 516-630 studs), so the far country cannot stand where it would really
# be. Each group of Horizon parts is designed at its true distance and then shrunk toward
# HORIZON_EYE until it sits SKY_SHELL studs out: a uniform scale about the eye maps every part onto
# exactly the pixels it covered, so from the eye the view is unchanged. On the client,
# WorldHorizon.client.luau carries the whole model along with the camera (translation only), which
# is how anything infinitely far behaves, so the ranges read as distant from anywhere in the map.
# Layers keep their order: the Sunspire's hill in front, each range behind the last.
SKY_SHELL = {"hill": 420, "Ridge": 525, "Range": 542, "FarRange": 556, "ring": 530}
SKY_DROP = 110  # every layer's foot sinks this far below the eye in sky space, out of sight


def _sky_k(group, dist):
    return SKY_SHELL[group] / dist


def _to_sky(parts, k):
    """Scale Horizon parts by k about HORIZON_EYE (positions and sizes), keeping rotations."""
    ex, ey, ez = HORIZON_EYE
    for node in parts:
        props = node["properties"]
        cf = props["CFrame"]["CFrame"]
        x, y, z = cf["position"]
        cf["position"] = [_r(ex + (x - ex) * k), _r(ey + (y - ey) * k), _r(ez + (z - ez) * k)]
        props["Size"] = [_r(v * k) for v in props["Size"]]
        for entry in reversed(REGISTRY):
            if entry["layer"] == "horizon" and entry["name"] == node["name"]:
                entry["pos"] = tuple(cf["position"])
                entry["size"] = tuple(props["Size"])
                break
    return parts


def _summit(dist, elev):
    """Summit height that stands `elev` degrees above the horizontal from HORIZON_EYE."""
    return HORIZON_EYE[1] + dist * math.tan(math.radians(elev))


def _peak(name, sx, sz, h, left, right, depth, color, lean, material="SmoothPlastic", base=-20.0, shade=None):
    """A mountain peak as two back-to-back wedges whose tall ends meet at the summit (sx, h, sz):
    the one reaching toward -x spans `left` studs, the one toward +x `right`, so each peak gets its
    own slopes. Each half turns `lean` degrees about its own summit edge, the -x half toward the
    afternoon sun and the +x half away from it, so every peak splits into a warm sunlit face and a
    cool shaded one; `shade`, when given, is the +x half's own colour, so the split is baked in
    as well as lit."""
    out = []
    height = h - base
    for side, reach in ((-1, left), (1, right)):
        col = shade if (shade and side > 0) else color
        # A wedge's tall end is at its local +Z; point that at the summit, the slope running out.
        r = mul(rot_y(90 if side < 0 else -90), rot_y(-lean * side))
        tip = apply(r, (0, height / 2, reach / 2))
        centre = (sx - tip[0], h - tip[1], sz - tip[2])
        out.append(part(f"{name}{'W' if side > 0 else 'E'}", (depth, height, reach), centre, col, material, r,
                        cls="WedgePart", collide=False, query=False, shadow=False, layer="horizon"))
    return out


def _gable(name, x, y, z, width, height, depth, color):
    """A pitched roof whose triangular end faces the town: two wedges meeting at a ridge at y + height."""
    out = []
    for side in (-1, 1):
        r = rot_y(90 if side < 0 else -90)
        tip = apply(r, (0, height / 2, width / 4))
        centre = (x - tip[0], y + height - tip[1], z - tip[2])
        out.append(part(f"{name}{'W' if side > 0 else 'E'}", (depth, height, width / 2), centre, color,
                        "SmoothPlastic", r, cls="WedgePart", collide=False, query=False, shadow=False,
                        layer="horizon"))
    return out


# ── The south country, sculpted ──────────────────────────────────────────────
# What the town sees over its south wall, built straight in sky space as faceted rock: every
# mountain is a fan of triangles (each triangle two thin WedgeParts) round its summit, and every
# facet takes its own colour from what it is (snow, bare rock, wooded lower slope), from which way
# it faces (warm where it turns to the afternoon sun, cool blue where only the sky lights it) and
# from how far off and how low it stands (pulled toward the horizon haze), so the ranges read as
# lit, weathered stone seen through miles of air. The hierarchy is deliberate: one dominant peak
# left of the gate, a second to the right, lower shoulders between, a pale far range standing in
# the gaps and behind the Sunspire, and round green foothills in front that tuck every foot away.
#
# Heights are given as the elevation the point shows at on screen from HORIZON_EYE looking down
# the gate axis (a rectilinear lens stretches elevations off-axis by 1/cos(bearing)), so the
# composition holds across the whole frame. Bearings: 0 is +Z (down the gate), +90 is +X.
SOUTH_SUN = (-0.68 * 0.82, 0.57, -0.73 * 0.82)  # toward the afternoon sun (SUN_XZ, ~35 deg up)
SOUTH_SHADE = (0.46, 0.55, 0.86)   # facets turned from the sun: blue sky light only
SOUTH_ROCK = (204, 156, 106)       # warm sunlit sandstone-granite, the Lemonade range's own colour
SOUTH_ROCK_DEEP = (136, 102, 84)   # the darker bands and gullies
SOUTH_FOREST = (72, 112, 62)
SOUTH_SNOW = (255, 251, 243)
SOUTH_HILL = (100, 150, 54)
# (name, bearing, summit elevation, reach toward -bearing, reach toward +bearing, ring points,
#  snow?) -- the great range, 565 studs out.
SOUTH_RANGE = [
    ("Crown", 25, 27.2, 17, 15, 9, True),       # the dominant peak
    ("Warden", -37, 24.9, 13, 16, 7, True),     # the second
    ("CrownShoulder", 45, 21.9, 10, 10, 5, False),
    ("GateShoulder", -15, 21.4, 9, 9, 5, False),
    ("Saddle", 7, 20.4, 7, 8, 4, False),
    ("WardenShoulder", -56, 21.2, 10, 10, 5, False),
    ("EastSpur", 62, 19.8, 10, 10, 4, False),
]
# The far range, 630 studs out and deep in the haze: a broad pale massif behind the Sunspire and
# peaks standing in the gaps of the great range.
SOUTH_FAR = [
    ("FarMassif", -3, 23.4, 16, 16, 6, True),
    ("FarEast", 38, 23.9, 11, 12, 5, True),
    ("FarWest", -25, 22.8, 11, 11, 5, True),
    ("FarWestEnd", -50, 22.2, 12, 12, 5, False),
    ("FarNotch", 13, 21.9, 9, 9, 4, False),
    ("FarEastEnd", 60, 21.0, 11, 11, 4, False),
]
# Round wooded foothills in front of the range's feet, 530 studs out: (bearing, top elevation,
# radius in studs).
SOUTH_FOOTHILLS = [(-54, 18.9, 80), (-41, 19.4, 64), (-28, 18.7, 72), (-18, 19.1, 52),
                   (18, 19.2, 56), (29, 18.8, 72), (41, 19.5, 64), (54, 19.0, 80)]


def _sky_pt(bearing, elev, r):
    """Sky-space point at `bearing` degrees, showing `elev` degrees up on screen, `r` studs out."""
    ex, ey, ez = HORIZON_EYE
    b = math.radians(bearing)
    dz = math.cos(b) * r
    return (ex + math.sin(b) * r, ey + math.tan(math.radians(elev)) * dz, ez + dz)


def _v_sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _v_cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _v_dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _v_unit(a):
    m = math.sqrt(_v_dot(a, a)) or 1.0
    return (a[0] / m, a[1] / m, a[2] / m)


def _smooth(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def facet(name, a, b, c, color, material="Rock", thickness=0.3):
    """A triangle as two thin WedgeParts (the classic two-wedge split along the longest edge)."""
    ab, ac, bc = _v_sub(b, a), _v_sub(c, a), _v_sub(c, b)
    abd, acd, bcd = _v_dot(ab, ab), _v_dot(ac, ac), _v_dot(bc, bc)
    if abd > acd and abd > bcd:
        a, c = c, a
    elif acd > bcd and acd > abd:
        a, b = b, a
    ab, ac, bc = _v_sub(b, a), _v_sub(c, a), _v_sub(c, b)
    right = _v_unit(_v_cross(ac, ab))
    up = _v_unit(_v_cross(bc, right))
    back = _v_unit(bc)
    height = abs(_v_dot(ab, up))
    out = []
    for k, (other, sgn) in enumerate(((b, 1), (c, -1))):
        edge = _v_sub(other, a)
        depth = abs(_v_dot(edge, back))
        if height < 0.05 or depth < 0.05:
            continue
        rx, bk = tuple(v * sgn for v in right), tuple(v * sgn for v in back)
        rot = [[rx[0], up[0], bk[0]], [rx[1], up[1], bk[1]], [rx[2], up[2], bk[2]]]
        mid = tuple((a[i] + other[i]) / 2 for i in range(3))
        out.append(part(f"{name}{'ab'[k]}", (thickness, height, depth), mid, color, material, rot,
                        cls="WedgePart", collide=False, query=False, shadow=False, layer="horizon"))
    return out


def _facet_colour(kind, a, b, c, haze_share, rng):
    """Colour for one facet: what it is, how it faces the sun, and how much air it stands behind."""
    ex, ey, ez = HORIZON_EYE
    n = _v_unit(_v_cross(_v_sub(b, a), _v_sub(c, a)))
    cen = tuple((a[i] + b[i] + c[i]) / 3 for i in range(3))
    if _v_dot(n, _v_sub(HORIZON_EYE, cen)) < 0:
        n = tuple(-v for v in n)
    lit = _smooth(-0.05, 0.75, _v_dot(n, _v_unit(SOUTH_SUN)))
    elev = math.degrees(math.atan2(cen[1] - ey, cen[2] - ez))  # screen elevation of the facet
    jit = rng.uniform(0.93, 1.06)
    if kind == "snow":
        base = SOUTH_SNOW
        jit = 1.0
    elif kind == "forest":
        base = SOUTH_FOREST
    elif kind == "deep":
        base = SOUTH_ROCK_DEEP
    else:
        base = SOUTH_ROCK
    col = [base[i] * jit * (SOUTH_SHADE[i] + (1 - SOUTH_SHADE[i]) * lit) for i in range(3)]
    # aerial perspective: the layer's share, and more toward the feet where the air is thickest
    f = haze_share + (1 - haze_share) * 0.36 * (1 - _smooth(16.5, 26.0, elev))
    return tuple(max(0, min(255, round(col[i] + (HAZE[i] - col[i]) * f))) for i in range(3))


def _mountain(name, bearing, top, reach_lo, reach_hi, k, snowy, r, haze_share, rng, foot=15.0, lower=True,
              spur=(14, 26)):
    """One faceted mountain: summit, a ring of k ridge points (outer ones on the silhouette, inner
    ones pushed forward as spurs), a foot ring hidden behind the walls, and a snow cap split off
    each summit facet at a ragged snow line."""
    apex = _sky_pt(bearing + rng.uniform(-0.6, 0.6), top, r)
    ring, feet = [], []
    for i in range(k):
        t = -1 + 2 * i / (k - 1)
        reach = reach_lo if t < 0 else reach_hi
        b = bearing + t * reach * rng.uniform(0.9, 1.05)
        drop = (top - foot) * (0.34 + 0.46 * abs(t) ** 0.85) + rng.uniform(-0.8, 0.8)
        depth = r - (1 - abs(t)) * rng.uniform(*spur)  # spurs reach toward the town
        ring.append(_sky_pt(b, top - drop, depth))
    for i in range(k):
        t = -1 + 2 * i / (k - 1)
        reach = reach_lo if t < 0 else reach_hi
        b = bearing + t * reach * 1.3
        feet.append(_sky_pt(b, foot, r - (1 - abs(t)) * 26 - 12))
    out = []
    for i in range(k - 1):
        a, b = ring[i], ring[i + 1]
        if snowy:
            fa, fb = rng.uniform(0.38, 0.72), rng.uniform(0.38, 0.72)
            sa = tuple(apex[j] + (a[j] - apex[j]) * fa for j in range(3))
            sb = tuple(apex[j] + (b[j] - apex[j]) * fb for j in range(3))
            out += facet(f"{name}Snow{i}", apex, sa, sb, _facet_colour("snow", apex, sa, sb, haze_share * 0.45, rng),
                         "Snow")
            kind = "rock" if i % 2 else "deep"
            out += facet(f"{name}Face{i}a", sa, sb, b, _facet_colour(kind, sa, sb, b, haze_share, rng))
            out += facet(f"{name}Face{i}b", sa, b, a, _facet_colour("rock", sa, b, a, haze_share, rng))
        else:
            kind = "rock" if i % 2 else "deep"
            out += facet(f"{name}Face{i}", apex, a, b, _facet_colour(kind, apex, a, b, haze_share, rng))
        if lower:
            fa, fb = feet[i], feet[i + 1]
            ea = math.degrees(math.atan2(a[1] - HORIZON_EYE[1], a[2] - HORIZON_EYE[2]))
            kind = "forest" if ea < 19.6 else "rock"
            out += facet(f"{name}Slope{i}a", a, b, fb, _facet_colour(kind, a, b, fb, haze_share, rng),
                         "Grass" if kind == "forest" else "Rock")
            out += facet(f"{name}Slope{i}b", a, fb, fa, _facet_colour("forest", a, fb, fa, haze_share, rng), "Grass")
    return out


def build_south_country():
    """The sculpted south: foothills, the great range, the far range and the Sunspire's hill."""
    rng = random.Random(5650)
    kids = []
    for spec in SOUTH_FAR:
        name, bearing, top, lo, hi, k, snowy = spec
        kids.append(model(f"Far{name}", _mountain(name, bearing, top, lo, hi, k, snowy, 504, 0.5, rng,
                                                   foot=17.0, spur=(3, 7))))
    for spec in SOUTH_RANGE:
        name, bearing, top, lo, hi, k, snowy = spec
        kids.append(model(f"Range{name}", _mountain(name, bearing, top, lo, hi, k, snowy, 492, 0.24, rng, spur=(10, 30))))
    # Foothills: rounded wooded domes, each a sphere sunk until the tangent from the eye over its
    # crown shows at the given elevation; the engine shades each from sunlit crown to shaded flank.
    hills = []
    ex, ey, ez = HORIZON_EYE
    for i, (bearing, top, radius) in enumerate(SOUTH_FOOTHILLS):
        b = math.radians(bearing)
        want = math.degrees(math.atan(math.tan(math.radians(top)) * math.cos(b)))
        d = 455.0
        hc = d * math.tan(math.radians(want)) - radius
        for _ in range(40):
            dist = math.hypot(d, hc)
            seen = math.degrees(math.atan2(hc, d) + math.asin(min(1.0, radius / dist)))
            hc -= (seen - want) * dist * math.pi / 180
        col = haze(SOUTH_FOREST if i % 2 else SOUTH_HILL, 0.26)
        hills.append(part(f"Foothill{i}", (radius * 2, radius * 2, radius * 2),
                          (ex + math.sin(b) * d, ey + hc, ez + math.cos(b) * d), col, "Grass",
                          shape="Ball", collide=False, query=False, shadow=False, layer="horizon"))
    kids.append(model("Foothills", hills))
    # The Sunspire's hill: a broad green dome (its crown the old mesa's top, Y176 in sky space)
    # whose brow rolls down toward the town through the Iron Lowlands gate,
    # with dark tree clumps along it, all softened a third of the way into the haze.
    hill = []
    ks = SKY_SHELL["hill"] / 505.0  # the hill was designed at 505 studs
    top_y, radius, zc = ey + (177.0 - ey) * ks, 200.0 * ks, ez + (535.0 - ez) * ks
    hill.append(part("SunspireHill", (270 * ks, radius * 2, radius * 2), (0, top_y - radius, zc), haze(SOUTH_HILL, 0.22),
                     "Grass", collide=False, query=False, shadow=False, layer="horizon", shape="Cylinder"))
    for side in (-1, 1):  # round shoulders over the dome's flat ends
        r2 = radius * 0.62
        hill.append(part(f"SunspireHillEnd{'EW'[side > 0]}", (r2 * 2, r2 * 2, r2 * 2),
                         (side * 130 * ks, top_y - 16 * ks - r2, zc + 10 * ks), haze(SOUTH_FOREST, 0.32), "Grass",
                         shape="Ball", collide=False, query=False, shadow=False, layer="horizon"))
    for i in range(24):  # woods down the face the Iron Lowlands gate frames (32-56 deg round the dome)
        phi = math.radians((32, 40, 48, 56)[i % 4] + rng.uniform(-3, 3))
        x = (-72 + (i // 4) * 29 + rng.uniform(-9, 9)) * ks
        d = rng.uniform(22, 30) * ks
        hill.append(part(f"HillWood{i}", (d, d, d),
                         (x, top_y - radius * (1 - math.cos(phi)) + d * 0.05, zc - radius * math.sin(phi)),
                         haze((86, 132, 58) if i % 3 else SOUTH_HILL, 0.2), "Grass",
                         shape="Ball", collide=False, query=False, shadow=False, layer="horizon"))
    for i in range(30):  # tree clumps down the brow in ragged rows, thinning toward the town
        row = i % 3
        x = (-126 + (i // 3) * 28 + rng.uniform(-9, 9)) * ks
        dz = (rng.uniform(-50, -40), rng.uniform(-72, -60), rng.uniform(-94, -84))[row] * ks
        y = top_y - radius + math.sqrt(radius * radius - dz * dz)
        d = rng.uniform(9, 15) * ks
        hill.append(part(f"HillTrees{i}", (d, d, d), (x, y + d * 0.1, zc + dz),
                         haze(SOUTH_FOREST if i % 4 else SOUTH_HILL, 0.24), "Grass",
                         shape="Ball", collide=False, query=False, shadow=False, layer="horizon"))
    kids.append(model("SunspireHill", hill))
    for m in kids:  # nested models stream on their own unless they are Persistent too
        m["properties"] = {"ModelStreamingMode": "Persistent"}
    return kids


def build_horizon():
    """Far country past the baseplate on every side, so every view that opens over a wall ends on a
    layered skyline instead of empty sky. South, where the town looks out through the Iron Lowlands
    gate, it is the sculpted south country (build_south_country): wooded foothills, the great range
    and a hazier far range, faceted and coloured by material, sun and air, with the Sunspire's wooded
    hill in front; their summits are set by the angle they show above the level hub walls
    from the main path, so each layer shows a band of its own over the crest and a band of sky stays
    open above. Everything stands within about 505 studs of the eye, since parts further out drop
    out of view in play. North, east and west keep a single range of diamond peaks (a big block turned about the
    view axis, its top vertex the summit, snow capped when tall). No collision, queries or shadows;
    the model is Persistent so none of it streams out. Seeded on its own, so it does not disturb the
    regions' layout."""
    # Scrapped entirely: Alex asked to remove the background mountains, foothills and the
    # Sunspire hill (this whole far-country dressing: south country AND the north/east/west
    # diamond-peak ranges), not just hide them client-side. Every part this used to build had
    # collide=False, query=False, shadow=False -- pure decoration, no gameplay footprint -- so an
    # empty Horizon model is safe: nothing depended on it existing.
    ex, ey, ez = HORIZON_EYE
    kids = []
    if False:
        rng = random.Random(20260918)
        kids = build_south_country()
        # North, east and west: one range each, built like the south ranges (two-tone ridges,
        # hazed about as far as the middle southern range), turned to face the town.
        sides = [
            ((0, -1), 1150, 1300, 9, (110, 220), 180),   # north
            ((1, 0), 1150, 1400, 10, (100, 200), 90),    # east
            ((-1, 0), 1150, 1400, 10, (100, 200), -90),  # west
        ]
        f = 0.44
        for (ox, oz), out, half, n, (h0, h1), yaw in sides:
            along = (oz, ox) if ox == 0 else (0, 1)
            centre_z = 520 if ox != 0 else 0  # east/west ranges run alongside the whole map
            turn = rot_y(yaw)
            # which of a peak's halves (local -x or +x) ends up on the sun's side once turned
            lx = apply(turn, (-1, 0, 0))
            sun_first = lx[0] * SUN_XZ[0] + lx[2] * SUN_XZ[1] > 0
            sun, shade = haze(HORIZON_SUN, f), haze(HORIZON_SHADE, f)
            if not sun_first:
                sun, shade = shade, sun
            for k in range(n):
                t = (k + rng.uniform(0.2, 0.8)) / n * 2 - 1
                d = out + rng.uniform(-80, 140)
                px = ox * d + along[0] * t * half
                pz = oz * d + along[1] * t * half + centre_z
                h = rng.uniform(h0, h1)
                left, right = h * rng.uniform(1.4, 2.2), h * rng.uniform(1.4, 2.2)
                depth = rng.uniform(160, 240)
                lean = rng.uniform(16, 26)
                dist = math.hypot(px - ex, pz - ez)
                ks = _sky_k("ring", dist)
                base = ey - SKY_DROP / ks
                stretch = (h - base) / (h + 20)
                group = _peak(f"Side{len(kids):03d}", 0, 0, h, left * stretch, right * stretch, depth, sun, lean,
                              base=base, shade=shade)
                if h > (h0 + h1) / 2:
                    c = 0.22
                    snow_sun, snow_shade = haze(HORIZON_SNOW, f * 0.8), haze(HORIZON_SNOW_SHADE, f * 0.8)
                    if not sun_first:
                        snow_sun, snow_shade = snow_shade, snow_sun
                    group += _peak(f"SideSnow{len(kids):03d}", 0, 0, h + 1, left * c, right * c, depth + 6, snow_sun,
                                   lean, base=h - (h + 20) * c, shade=snow_shade)
                for node in group:  # turn to face the town, then stand at (px, pz)
                    cf = node["properties"]["CFrame"]["CFrame"]
                    x, y, z = cf["position"]
                    q = apply(turn, (x, y, z))
                    cf["position"] = [_r(q[0] + px), _r(q[1]), _r(q[2] + pz)]
                    cf["orientation"] = [[_r(v) for v in row] for row in mul(turn, cf["orientation"])]
                kids += _to_sky(group, ks)
    horizon = model("Horizon", kids, attrs={"Region": "Horizon", "SkyEyeX": ex, "SkyEyeY": ey, "SkyEyeZ": ez})
    horizon["properties"] = {"ModelStreamingMode": "Persistent"}
    return horizon


# ── Iron Lowlands: pass → overlook → yard → pits → Warlord's Pit ─────────────
# ── Iron Lowlands: the bandit quarry ─────────────────────────────────────────
# Three worked benches step down from the Overlook rim (Y 10) to the pit (Y 2). [TUNING]
RIM_Y, MID_Y, PIT_Y = HUB_Y, 6.0, QUARRY_Y
RIM_Z, MID_Z, PIT_Z = (168, 232), (232, 330), (330, 472)
RAMP1 = (6, 34, 232, 254)      # rim → mid, x0 x1 z0 z1 (10.3°)
RAMP2 = (-36, -8, 330, 352)    # mid → pit
SUMP = (76, 112, 330, 364)     # drainage corner of the pit, bed at PIT_Y - 1.2 (clear of the ridge)
PASSAGE = (-167, -112, 270, 330)  # the gang's back-door passage off the mid bench


def haul_ramp(name, x0, x1, z0, z1, y_top, y_bottom):
    """Packed-earth ramp with a timber curb log on each side, laid along the slope."""
    floor = ramp(name, x0, x1, z0, z1, y_top, y_bottom, HAUL_ROAD, "SmoothPlastic")
    dz, dy = z1 - z0, y_bottom - y_top
    angle = -math.degrees(math.atan2(dy, dz))
    length = math.hypot(dz, dy)
    curbs = []
    for side, x in ((-1, x0 + 0.6), (1, x1 - 0.6)):
        curbs.append(part(f"{name}Curb{side}", (0.9, 0.9, length - 1.5), (x, (y_top + y_bottom) / 2 + 0.42, (z0 + z1) / 2),
                          BEAM, "Wood", rot_x(angle), collide=False, layer="prop"))
    return floor, curbs


def haul_road(name, x0, x1, z0, z1, y, along="z"):
    """Worn earth strip (a floor) plus two cart ruts (decals, slightly proud so they read at a
    distance). Returns (floor_parts, decal_parts): decals belong in the region model, not Grounds_*."""
    floor = [box(f"{name}", x0, x1, y, y + 0.2, z0, z1, HAUL_ROAD, "SmoothPlastic", layer="ground")]
    ruts = []
    if along == "z":
        for k, x in enumerate(((x0 + x1) / 2 - 2.6, (x0 + x1) / 2 + 2.6)):
            ruts.append(box(f"{name}Rut{k}", x - 0.35, x + 0.35, y + 0.2, y + 0.32, z0 + 1, z1 - 1, RUT, "SmoothPlastic",
                            collide=False, layer="decal"))
    else:
        for k, z in enumerate(((z0 + z1) / 2 - 2.6, (z0 + z1) / 2 + 2.6)):
            ruts.append(box(f"{name}Rut{k}", x0 + 1, x1 - 1, y + 0.2, y + 0.32, z - 0.35, z + 0.35, RUT, "SmoothPlastic",
                            collide=False, layer="decal"))
    return floor, ruts


def bench_face(name, a, b, inward, lower_y, drop, rng):
    """Rough rock toe along a bench edge: chunks straddle the slab face (2 studs proud of it) and
    collide, so the drop reads as broken rock rather than a sawn slab. No proxy: the slab itself
    is the wall, and players may drop off the edge."""
    chunks, _ = cliff_run(name, a, b, inward, lower_y, drop + 0.4, QUARRY_CLIFF, QUARRY_CLIFF_DARK, rng, depth=3.5,
                          chunk=(6, 11), h_jitter=(0.86, 1.06), caps=False, proxy=False, protrude=2.6, solid=True)
    return chunks


def spoil_heap(name, x, z, rng, radius=12.0, color=QUARRY_CLIFF_DARK):
    """Rubble mound: two collidable discs with loose rock scattered over them."""
    y = floor_at(x, z, PIT_Y)
    kids = disc("Mound", x, z, radius, y + 2.6, 2.6, color, "Slate")
    kids += disc("Crown", x + rng.uniform(-2, 2), z + rng.uniform(-2, 2), radius * 0.55, y + 4.4, 1.8, color, "Slate")
    for k in range(rng.randint(7, 10)):
        a, rr = rng.uniform(0, math.tau), rng.uniform(0.2, 0.95) * radius
        rx, rz = x + math.cos(a) * rr, z + math.sin(a) * rr
        top = y + (4.4 if rr < radius * 0.5 else 2.6)
        w, h, d = rng.uniform(1.6, 3.4), rng.uniform(1.0, 2.2), rng.uniform(1.6, 3.2)
        kids.append(part(f"Rubble{k}", (w, h, d), (rx, top + h / 2 - 0.3, rz), rng.choice((ROCK_GRAY, STONE_DARK, color)),
                         "Slate", mul(rot_y(rng.uniform(0, 90)), rot_z(rng.uniform(-14, 14))), collide=False, layer="rock"))
    return model(name, kids)



def moss_plate(name, x, y, z, w, h, yaw):
    """Thin moss plate on a north-facing wall; 0.05 into the wall, 0.17 proud of it (never coplanar)."""
    r = rot_y(yaw)
    fwd = apply(r, (0, 0, -1))
    return part(name, (w, h, 0.22), (x + fwd[0] * 0.06, y, z + fwd[2] * 0.06), MOSS, "Grass", r, collide=False,
                query=False, shadow=False)


def ladder(name, x, z, yaw, height, lean=14.0):
    """Timber ladder leaning back against a face: rails and rungs tilted by `lean` toward local -Z."""
    y = floor_at(x, z, MID_Y)
    r = mul(rot_y(yaw), rot_x(lean))
    up = apply(r, (0, 1, 0))
    right = apply(r, (1, 0, 0))
    kids = []
    for side in (-1, 1):
        c = tuple((x, y, z)[i] + up[i] * height / 2 + right[i] * side * 1.1 for i in range(3))
        kids.append(part(f"Rail{side}", (0.4, height, 0.35), c, SPLINTER, "Wood", r, collide=False))
    n = int(height / 1.3)
    for k in range(n):
        c = tuple((x, y, z)[i] + up[i] * (0.9 + k * 1.3) for i in range(3))
        kids.append(part(f"Rung{k}", (2.2, 0.3, 0.3), c, TIMBER, "Wood", r, collide=False))
    return model(name, kids)


def bench_lines(name, x, z0, z1, base, rng, inward=-1):
    """Stepped ledges every 6 studs up a tall cut face (the old working benches, too narrow to walk)."""
    kids = []
    for lv, dy in enumerate((8, 14, 20, 26)):
        z = z0 + rng.uniform(2, 8)
        k = 0
        while z < z1 - 8:
            length = rng.uniform(10, 26)
            length = min(length, z1 - z - 1)
            top = free_top(base + dy + rng.uniform(-0.6, 0.6))
            kids.append(part(f"Ledge{lv}_{k}", (3.6, 1.4, length), (x - inward * 0.4, top - 0.7, z + length / 2),
                             QUARRY_CLIFF_DARK, "Sandstone", rot_y(rng.uniform(-2, 2)), collide=False, layer="cliff"))
            z += length + rng.uniform(4, 14)
            k += 1
    return model(name, kids)


def head_frame(name, x, z, rng, height=24.0):
    """Timber A-frame hoist over the pit edge: sheave at the apex, snapped boom, a hook still dangling."""
    y = floor_at(x, z, MID_Y)
    kids = []
    spread, top_gap = 5.0, 0.7
    lean = math.degrees(math.atan2(spread - top_gap, height))
    leg_len = math.hypot(spread - top_gap, height)
    for sx in (-1, 1):
        for sz in (-1, 1):
            cx = x + sx * (spread + top_gap) / 2
            kids.append(part(f"Leg{sx}{sz}", (1.2, leg_len, 1.2), (cx, y + height / 2, z + sz * 3.2), BEAM, "Wood",
                             rot_z(sx * lean), collide=(sz == -1)))
            for k, hy in enumerate((7.0, 15.0)):  # rusted iron straps
                lx = x + sx * ((spread + top_gap) / 2 - (hy - height / 2) * math.tan(math.radians(lean)))
                kids.append(part(f"Strap{sx}{sz}{k}", (1.5, 0.5, 1.5), (lx, y + hy, z + sz * 3.2), RUST, "CorrodedMetal",
                                 rot_z(sx * lean), collide=False, query=False))
        # X-brace on each long side
        for k, tilt in enumerate((52, -52)):
            kids.append(part(f"Brace{sx}{k}", (0.6, 11.5, 0.6), (x + sx * 3.1, y + 9.5, z), BEAM, "Wood",
                             mul(rot_y(90), rot_z(tilt)), collide=False))
    kids.append(part("Apex", (1.6, 1.4, 9.0), (x, y + height + 0.4, z), BEAM, "Wood", collide=False))
    kids.append(part("Sheave", (0.8, 4.2, 4.2), (x, y + height - 2.2, z), RUST, "CorrodedMetal", shape="Cylinder", collide=False))
    kids.append(part("SheavePin", (2.4, 0.5, 0.5), (x, y + height - 2.2, z), IRON_DARK, "CorrodedMetal", collide=False))
    # Boom: a stub still pinned at the apex, tilted down where it snapped; the rest lies below.
    stub = 6.0
    kids.append(part("BoomStub", (0.9, 0.9, stub), (x, y + height - stub / 2 * math.sin(math.radians(32)),
                                                    z + 4.0 + stub / 2 * math.cos(math.radians(32))),
                     SPLINTER, "Wood", rot_x(32), collide=False))
    kids.append(part("BoomFallen", (0.9, 0.9, 16), (x + 2.5, y + 0.45, z + 12), SPLINTER, "Wood", rot_y(-14), collide=False))
    kids.append(part("Rope", (0.25, 9.5, 0.25), (x, y + height - 2.2 - 4.75, z - 1.6), (90, 80, 60), "Fabric", collide=False))
    kids.append(part("Hook", (0.5, 1.6, 0.5), (x, y + height - 7.7, z - 1.6), RUST, "CorrodedMetal", collide=False))
    kids.append(part("HookTip", (0.5, 0.5, 1.4), (x, y + height - 8.4, z - 1.1), RUST, "CorrodedMetal", collide=False))
    for sx in (-1, 1):  # moss on the north face of the north legs (legs lean, so find their x at that height)
        leg_x = x + sx * ((spread + top_gap) / 2 + (height / 2 - 2.6) * math.tan(math.radians(lean)))
        kids.append(moss_plate(f"Moss{sx}", leg_x, y + 2.6, z - 3.8, 1.2, 3.0, 0))
    return model(name, kids)


def ore_chute(name, x, z_top, z_bottom, y_top, rng):
    """Timber trough on legs from the upper bench down to the lower one; the lower legs gave way, so
    it now lies with its foot on the lower floor, spilling grey rubble."""
    y_bottom = floor_at(x, z_bottom, MID_Y)
    length = z_bottom - z_top
    dy = (y_top + 0.9) - (y_bottom + 0.5)
    angle = math.degrees(math.atan2(dy, length))
    r = rot_x(angle)
    cy, cz = (y_top + 0.9 + y_bottom + 0.5) / 2, (z_top + z_bottom) / 2
    slope = math.hypot(length, dy)
    kids = [part("Bed", (4.2, 0.4, slope), (x, cy, cz), SPLINTER, "WoodPlanks", r, collide=False)]
    for side in (-1, 1):
        kids.append(part(f"Side{side}", (0.4, 1.6, slope), (x + side * 1.95, cy + 0.6, cz), TIMBER, "WoodPlanks", r,
                         collide=False))
    kids.append(part("Cradle", (5.2, 1.2, 3.0), (x, y_top + 0.6, z_top + 1.2), BEAM, "Wood", collide=False))
    kids.append(part("CradleStrap", (5.4, 0.4, 0.6), (x, y_top + 1.05, z_top + 1.6), RUST, "CorrodedMetal", collide=False))
    # Broken legs and the rubble that ran out of it.
    kids.append(part("BrokenLegA", (0.8, 4.0, 0.8), (x + 3.4, y_bottom + 0.9, z_bottom - 3), SPLINTER, "Wood",
                     mul(rot_y(20), rot_z(66)), collide=False))
    kids.append(part("BrokenLegB", (0.8, 2.6, 0.8), (x - 3.0, y_bottom + 0.6, z_bottom - 6), SPLINTER, "Wood",
                     mul(rot_y(-35), rot_z(-72)), collide=False))
    kids += disc("Gravel", x + 0.5, z_bottom + 2.5, 3.4, y_bottom + 0.36, 0.36, ROCK_GRAY, "Slate", collide=False, layer="decal")
    for k in range(6):
        a, rr = rng.uniform(0, math.tau), rng.uniform(0.5, 3.6)
        d = rng.uniform(0.8, 1.7)
        kids.append(part(f"Rubble{k}", (d, d * 0.7, d * 0.9), (x + 0.5 + math.cos(a) * rr, y_bottom + d * 0.35 - 0.1,
                                                            z_bottom + 2.5 + math.sin(a) * rr), ROCK_GRAY, "Slate",
                         rot_y(rng.uniform(0, 90)), collide=False, layer="rock"))
    return model(name, kids)


def crusher_house(name, x0, x1, z0, z1, rng):
    """Stone crushing shed: a sound pitched roof over four walls, rusted flywheel and belt in the
    open east bay, a cold ember pit with the only light. The gang sleeps in here (camp props
    added by bandit_camp)."""
    y = floor_at((x0 + x1) / 2, (z0 + z1) / 2, MID_Y)
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    wall_h, t = 9.0, 1.2
    stone = (120, 110, 98)
    kids = [
        box("WallN", x0, x1, y, y + wall_h, z0, z0 + t, stone, "Cobblestone"),
        box("WallW", x0, x0 + t, y, y + wall_h, z0 + t, z1 - t, stone, "Cobblestone"),
        box("WallS", x0, x1, y, y + wall_h, z1 - t, z1, stone, "Cobblestone"),
        box("WallE_N", x1 - t, x1, y, y + wall_h, z0 + t, cz - 5, stone, "Cobblestone"),
        box("WallE_S", x1 - t, x1, y, y + wall_h, cz + 5, z1 - t, stone, "Cobblestone"),
        box("BayLintel", x1 - t - 0.3, x1 + 0.3, y + wall_h - 1.4, y + wall_h, cz - 5.6, cz + 5.6, SPLINTER, "Wood", collide=False),
        box("Floor", x0 + t, x1 - t, y, y + 0.16, z0 + t, z1 - t, (96, 88, 80), "Slate", collide=False, layer="decal"),
    ]
    # Roof: two plank slopes meeting on a ridge beam, stone gables closing each end.
    span = x1 - x0
    pitch = 24.0
    half = span / 2 + 0.8
    rise = math.tan(math.radians(pitch)) * span / 2
    slope_len = half / math.cos(math.radians(pitch))
    for side, sname in ((-1, "RoofW"), (1, "RoofE")):
        kids.append(part(sname, (slope_len, 0.7, z1 - z0 + 1.6), (cx + side * half / 2, y + wall_h + rise / 2, cz),
                         (88, 60, 44), "WoodPlanks", rot_z(-side * pitch), collide=False, layer="roof"))
    for gz in (z0 + 0.6, z1 - 0.6):
        for side, yaw in ((-1, 90), (1, -90)):
            kids.append(part(f"Gable{'W' if side < 0 else 'E'}", (1.2, rise, span / 2), (cx + side * span / 4, y + wall_h + rise / 2, gz),
                             stone, "Cobblestone", rot_y(yaw), cls="WedgePart", collide=False, layer="roof"))
    kids.append(part("RidgeBeam", (span + 1.6, 0.9, 0.9), (cx, y + wall_h + rise + 0.2, cz), BEAM, "Wood",
                     collide=False, layer="roof"))
    # Flywheel on a plinth in the bay, belt to a small pulley on the wall.
    wx, wz = x1 - 7.5, cz - 4
    kids += [
        part("Plinth", (2.6, 1.4, 2.6), (wx, y + 0.7, wz), STONE_DARK, "Cobblestone"),
        part("Bearing", (1.2, 3.2, 1.6), (wx, y + 2.6, wz), IRON_DARK, "CorrodedMetal", collide=False),
        part("Flywheel", (1.0, 6.4, 6.4), (wx, y + 4.4, wz), RUST, "CorrodedMetal", shape="Cylinder", collide=False),
        part("Axle", (3.6, 0.6, 0.6), (wx, y + 4.4, wz), IRON_DARK, "CorrodedMetal", collide=False),
        part("Pulley", (0.9, 2.2, 2.2), (wx, y + 6.4, wz + 8), RUST, "CorrodedMetal", shape="Cylinder", collide=False),
        part("PulleyBracket", (0.8, 0.8, 1.6), (wx, y + 6.4, wz + 8.6), IRON_DARK, "CorrodedMetal", collide=False),
    ]
    belt_len = math.hypot(8, 2)
    belt_tilt = -math.degrees(math.atan2(2, 8))  # rot_x(-a) raises the +Z end
    for k, (dy, off) in enumerate(((3.0, 1.1), (-3.0, -1.1))):
        kids.append(part(f"Belt{k}", (0.16, 0.5, belt_len), (wx + 0.55, y + 4.4 + dy + (off - dy) / 2 + 1.0, wz + 4),
                         (52, 40, 30), "Fabric", rot_x(belt_tilt), collide=False))
    kids.append(part("Crusher", (4.6, 3.2, 3.6), (x0 + 5, y + 1.6, z0 + 5), IRON_DARK, "CorrodedMetal"))
    kids.append(part("CrusherJaw", (2.2, 2.0, 2.4), (x0 + 5, y + 4.2, z0 + 5), RUST, "CorrodedMetal", rot_y(8), collide=False))
    # The only light: a cold ember pit the bandits keep barely alive.
    kids.append(part("EmberRing", (0.9, 3.6, 3.6), (cx - 2, y + 0.45, cz + 5), STONE_DARK, "Slate", rot_z(90), shape="Cylinder",
                     collide=False))
    kids.append(part("Embers", (2.2, 0.4, 2.2), (cx - 2, y + 0.95, cz + 5), (150, 60, 24), "Neon", collide=False, query=False,
                     shadow=False, children=[light(18, 0.9, (255, 120, 50))]))
    # Moss on the north wall.
    for k, mx in enumerate((x0 + 6, x0 + 14, x1 - 5)):
        kids.append(moss_plate(f"Moss{k}", mx, y + 2.2 + k * 0.6, z0, rng.uniform(2.5, 4.5), rng.uniform(2, 3.4), 0))
    return model(name, kids)


def lean_to_ruin(name, x0, x1, z0, z1, rng):
    """The old smithy lean-to: back wall standing, one post gone, roof half down, a cold forge."""
    y = floor_at((x0 + x1) / 2, (z0 + z1) / 2, RIM_Y)
    cx = (x0 + x1) / 2
    stone = (124, 112, 100)
    kids = [box("BackWall", x0, x1, y, y + 5.2, z1 - 1, z1, stone, "Cobblestone"),
            part("PostW", (0.8, 6.6, 0.8), (x0 + 0.6, y + 3.3, z0 + 0.6), BEAM, "Wood"),
            part("PostStub", (0.8, 1.6, 0.8), (x1 - 0.6, y + 0.8, z0 + 0.6), SPLINTER, "Wood", rot_z(12))]
    depth = z1 - z0
    w = (x1 - x0) / 2
    pitch = math.degrees(math.atan2(6.6 - 5.2, depth))
    kids.append(part("RoofW", (w + 0.6, 0.4, depth + 1.2), (x0 + w / 2, y + 5.9 + 0.2, (z0 + z1) / 2), TIMBER, "WoodPlanks",
                     rot_x(pitch), collide=False, layer="roof"))
    # East half dropped: tilted sideways, one corner on the ground, the other on the wall top.
    tilt = math.degrees(math.atan2(5.0, w))
    kids.append(part("RoofE_Fallen", (w + 0.6, 0.4, depth + 1.2), (cx + w / 2 - 0.4, y + 2.7, (z0 + z1) / 2 + 0.3), SPLINTER,
                     "WoodPlanks", mul(rot_x(pitch), rot_z(tilt)), collide=False, layer="roof"))
    kids += [
        part("ForgeBody", (4.2, 3.0, 4.0), (x0 + 3.6, y + 1.5, z1 - 3.4), STONE_DARK, "Cobblestone"),
        part("ForgeHood", (3.4, 0.9, 3.2), (x0 + 3.6, y + 3.45, z1 - 3.4), IRON_DARK, "CorrodedMetal", collide=False),
        part("ForgeAsh", (2.6, 0.3, 2.4), (x0 + 3.6, y + 3.1, z1 - 3.4), (70, 66, 62), "Slate", collide=False),
        part("AnvilStump", (1.4, 1.8, 1.8), (cx + 1, y + 0.9, z1 - 4), TRUNK, "Wood", rot_z(90), shape="Cylinder"),
        part("Anvil", (2.6, 1.0, 1.1), (cx + 1, y + 2.3, z1 - 4), IRON_DARK, "CorrodedMetal", collide=False),
        part("AnvilHorn", (1.2, 0.6, 0.6), (cx + 2.6, y + 2.35, z1 - 4), IRON_DARK, "CorrodedMetal", rot_y(0), collide=False),
        part("Wheel", (0.5, 3.6, 3.6), (x1 - 3, y + 0.25, z0 + 3), (96, 64, 40), "Wood", rot_z(90), shape="Cylinder", collide=False),
        part("WheelHub", (0.7, 1.0, 1.0), (x1 - 3, y + 0.35, z0 + 3), RUST, "CorrodedMetal", rot_z(90), shape="Cylinder",
             collide=False),
    ]
    kids.append(barrel("BarrelA", x0 + 2, 0, z0 + 2.4, rng))
    kids.append(barrel("BarrelB", x0 + 5.2, 0, z0 + 1.8, rng))
    kids.append(moss_plate("Moss", cx - 2, y + 2.0, z1, 5, 2.6, 180))
    return model(name, kids)


def collapsed_scaffold(name, x, z, rng, height=16.0):
    """A scaffold that came down: posts leaning at 55°, decks slid off, all lying on each other."""
    y = floor_at(x, z, RIM_Y)
    kids = []
    for k, (dx, dz, tilt, yaw) in enumerate(((0, -3, 56, 0), (0, 2, 60, 8), (7, -2, 52, -6), (7, 3, 64, 4))):
        h = height * rng.uniform(0.8, 1.0)
        c = (x + dx + math.sin(math.radians(tilt)) * h / 2, y + math.cos(math.radians(tilt)) * h / 2 + 0.2, z + dz)
        kids.append(part(f"Post{k}", (0.8, h, 0.8), c, SPLINTER, "Wood", mul(rot_y(yaw), rot_z(-tilt)), collide=False))
    kids.append(part("DeckA", (10, 0.5, 5), (x + 5, y + 2.6, z), TIMBER, "WoodPlanks", mul(rot_y(10), rot_z(-24)), collide=False))
    kids.append(part("DeckB", (9, 0.5, 5), (x + 9, y + 1.4, z + 3), TIMBER, "WoodPlanks", mul(rot_y(-18), rot_z(-9)), collide=False))
    kids.append(part("Brace", (0.5, 0.5, 12), (x + 4, y + 0.6, z - 1), SPLINTER, "Wood", mul(rot_y(35), rot_x(6)), collide=False))
    return model(name, kids)


def derailed_cart(name, x, z, rng, yaw=15.0, roll=28.0):
    """Mine cart off its rails, tipped on one side with its load spilled."""
    y = floor_at(x, z, MID_Y)
    r = mul(rot_y(yaw), rot_z(roll))
    drop = 1.3 * math.cos(math.radians(roll)) + 2.25 * math.sin(math.radians(roll)) + 0.3
    kids = [part("Body", (4.5, 2.6, 6.5), (x, y + drop, z), (88, 70, 54), "WoodPlanks", r)]
    right = apply(r, (1, 0, 0))
    fwd = apply(r, (0, 0, 1))
    for sx in (-1, 1):
        for sz in (-1, 1):
            c = tuple((x, y + drop, z)[i] + right[i] * sx * 2.4 + fwd[i] * sz * 2.2 - apply(r, (0, 1, 0))[i] * 1.4 for i in range(3))
            kids.append(part(f"Wheel{sx}{sz}", (0.6, 1.8, 1.8), c, RUST, "CorrodedMetal", r, shape="Cylinder", collide=False))
    for k in range(6):
        d = rng.uniform(0.8, 1.6)
        kids.append(part(f"Spill{k}", (d, d * 0.7, d), (x - 3.2 + rng.uniform(-2, 2), y + d * 0.35 - 0.1, z + rng.uniform(-3, 3)),
                         ROCK_GRAY, "Slate", rot_y(rng.uniform(0, 90)), collide=False, layer="rock"))
    return model(name, kids)


def bent_rails(name, x, z, rng):
    """Where the spur ends: two rails curled up off the sleepers."""
    y = floor_at(x, z, MID_Y)
    kids = []
    for k, (sx, yaw, lift) in enumerate(((-1.6, -18, -26), (1.6, 14, -32))):
        kids.append(part(f"Rail{k}", (0.4, 0.35, 5.5), (x + sx, y + 0.4 + 2.75 * math.sin(math.radians(-lift)), z + 2.6),
                         RUST, "CorrodedMetal", mul(rot_y(yaw), rot_x(lift)), collide=False))
    return model(name, kids)


def broken_cart(name, x, z, yaw, rng):
    """Hand cart with a wheel gone, dropped on its axle stub."""
    y = floor_at(x, z, RIM_Y)
    r = mul(rot_y(yaw), rot_z(-16))
    right = apply(r, (1, 0, 0))
    fwd = apply(r, (0, 0, -1))
    side_off = apply(r, (2.0, 0.85, 0))
    kids = [part("Bed", (4.2, 0.5, 6.0), (x, y + 1.6, z), SPLINTER, "WoodPlanks", r),
            part("SideL", (0.3, 1.4, 5.6), (x + side_off[0], y + 1.6 + side_off[1], z + side_off[2]), SPLINTER, "WoodPlanks", r,
                 collide=False),
            part("Axle", (5.4, 0.35, 0.35), (x, y + 1.2, z), RUST, "CorrodedMetal", r, collide=False),
            part("Wheel", (0.5, 3.6, 3.6), (x + right[0] * 2.6 + 0.2, y + 1.9, z + right[2] * 2.6), (96, 64, 40), "Wood", r,
                 shape="Cylinder", collide=False),
            part("Handle", (0.35, 0.35, 4.0), (x + fwd[0] * 4.2, y + 1.3, z + fwd[2] * 4.2), SPLINTER, "Wood",
                 mul(r, rot_x(8)), collide=False)]
    kids.append(part("LostWheel", (0.5, 3.6, 3.6), (x - right[0] * 5, y + 0.25, z - right[2] * 5 + 2), (96, 64, 40), "Wood",
                     rot_z(90), shape="Cylinder", collide=False))
    return model(name, kids)



def bedroll(name, x, z, yaw, color=(60, 196, 245)):
    y = floor_at(x, z, MID_Y)
    r = rot_y(yaw)
    fwd = apply(r, (0, 0, -1))
    return model(name, [
        part("Roll", (2.4, 0.45, 5.6), (x, y + 0.22, z), color, "SmoothPlastic", r, collide=False),
        part("Pillow", (1.8, 0.7, 1.4), (x + fwd[0] * 2.2, y + 0.55, z + fwd[2] * 2.2), (255, 246, 228), "SmoothPlastic", r,
             collide=False),
    ])


def cook_fire(name, x, z, rng):
    """Campfire with a spit: two forked posts, an iron rod, something roasting."""
    y = floor_at(x, z, MID_Y)
    kids = [campfire("Fire", x, 0, z, rng)]
    for side in (-1, 1):
        kids.append(part(f"SpitPost{side}", (0.5, 3.4, 0.5), (x + side * 2.8, y + 1.7, z), BEAM, "SmoothPlastic", rot_z(side * 6),
                         collide=False))
    kids.append(part("SpitRod", (6.6, 0.3, 0.3), (x, y + 3.2, z), IRON_DARK, "SmoothPlastic", collide=False))
    kids.append(part("Roast", (2.2, 1.1, 1.1), (x - 0.4, y + 3.2, z), (240, 120, 80), "SmoothPlastic", rot_x(90), shape="Cylinder",
                     collide=False))
    return model(name, kids)


def hanging_lantern(name, x, y_hook, z, drop=1.6, bright=1.0):
    """Lantern on a short chain below a beam or bracket at y_hook (the chain overlaps the beam)."""
    return model(name, [
        part("Chain", (0.18, drop + 0.4, 0.18), (x, y_hook - drop / 2 + 0.2, z), IRON_DARK, "SmoothPlastic", collide=False),
        part("Lantern", (1.1, 1.4, 1.1), (x, y_hook - drop - 0.6, z), LANTERN, "Neon", collide=False, query=False, shadow=False,
             transparency=0.15, children=[light(16, bright)]),
        part("Cap", (1.3, 0.25, 1.3), (x, y_hook - drop + 0.2, z), IRON_DARK, "SmoothPlastic", collide=False),
    ])


def rag_banner(name, x, z, yaw, height=9.0, color=WARLORD_RED, on_y=None):
    """Torn gang banner: pole with two ragged cloth strips. on_y = base height when it stands on a deck."""
    y = floor_at(x, z, MID_Y) if on_y is None else on_y
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))
    kids = [part("Pole", (0.5, height, 0.5), (x, y + height / 2, z), SPLINTER, "SmoothPlastic", collide=False)]
    for k, (w, h, dy) in enumerate(((2.6, 4.2, height - 2.6), (1.4, 5.0, height - 3.4))):
        kids.append(part(f"Rag{k}", (w, h, 0.2), (x + right[0] * (0.25 + w / 2 + k * 1.2), y + dy, z + right[2] * (0.25 + w / 2 + k * 1.2)),
                         color, "SmoothPlastic", mul(r, rot_z(-6 - k * 8)), collide=False))
    return model(name, kids)


def barricade(name, x, z, yaw, length, rng):
    """Quarry timber and cart wheels piled across part of a road; the planks block, the rest is dressing."""
    y = floor_at(x, z, MID_Y)
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))
    fwd = apply(r, (0, 0, -1))
    kids = [part("Planks", (length, 3.2, 1.6), (x, y + 1.6, z), SPLINTER, "SmoothPlastic", r),
            part("TopPlank", (length * 0.8, 0.7, 1.8), (x + right[0] * 0.6, y + 3.6, z + right[2] * 0.6), TIMBER, "SmoothPlastic",
                 mul(r, rot_z(3)), collide=False)]
    for k in range(int(length / 4)):
        sx = -length / 2 + 2 + k * 4
        kids.append(part(f"Stake{k}", (0.45, 4.6, 0.45), (x + right[0] * sx + fwd[0] * 1.3, y + 1.9, z + right[2] * sx + fwd[2] * 1.3),
                         SPLINTER, "SmoothPlastic", mul(r, rot_x(-38)), collide=False))
    for k, sx in enumerate((-length / 2 + 1.5, length / 2 - 1.5)):
        wx, wz = x + right[0] * sx - fwd[0] * 1.2, z + right[2] * sx - fwd[2] * 1.2
        kids.append(part(f"Wheel{k}", (0.5, 3.6, 3.6), (wx, y + 1.8, wz), IRON_DARK, "SmoothPlastic", mul(r, rot_y(90 + rng.uniform(-8, 8))),
                         shape="Cylinder", collide=False))
    return model(name, kids)


def skull_sign(name, x, z, yaw, title, subtitle):
    """Bandit warning: a signboard with a bone-white skull spiked on the post."""
    y = floor_at(x, z, RIM_Y)
    r = rot_y(yaw)
    kids = [sign("Board", x, 0, z, yaw, 9, 3.6, title, subtitle, board=WARLORD_RED, text=(255, 246, 228), post_h=7.6)]
    right = apply(r, (1, 0, 0))
    sx, sz = x + right[0] * 4.95, z + right[2] * 4.95
    kids.append(part("Skull", (1.3, 1.4, 1.3), (sx, y + 8.2, sz), (255, 250, 240), "SmoothPlastic", shape="Ball", collide=False,
                     query=False))
    kids.append(part("Jaw", (1.0, 0.5, 0.9), (sx, y + 7.55, sz), (246, 238, 226), "SmoothPlastic", r, collide=False, query=False))
    kids.append(part("Spike", (0.3, 1.4, 0.3), (sx, y + 7.4, sz), IRON_DARK, "SmoothPlastic", collide=False, query=False))
    return model(name, kids)


def scrap_gate(name, x, z, yaw, width=9.0, height=12.0):
    """One leaf of a gate welded from cart plates, hung open on a timber post."""
    y = floor_at(x, z, PIT_Y)
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))
    kids = [part("HingePost", (1.4, height + 1, 1.4), (x, y + (height + 1) / 2, z), BEAM, "SmoothPlastic")]
    cx, cz = x + right[0] * (width / 2 + 0.7), z + right[2] * (width / 2 + 0.7)
    kids.append(part("Frame", (width, height, 0.6), (cx, y + height / 2, cz), IRON_DARK, "SmoothPlastic", r))
    for k, (dx, dy, w, h) in enumerate(((-2.2, 3.2, 3.6, 4.4), (1.9, 2.6, 4.0, 3.6), (-1.4, 8.0, 4.4, 3.2), (2.4, 7.4, 3.0, 4.6))):
        kids.append(part(f"Plate{k}", (w, h, 0.35), (cx + right[0] * dx, y + dy, cz + right[2] * dx), RUST, "SmoothPlastic", r,
                         collide=False))
    kids.append(part("Spikes", (width - 1, 1.2, 0.4), (cx, y + height + 0.4, cz), IRON_DARK, "SmoothPlastic", r, collide=False))
    return model(name, kids)


def throne(name, x, z, yaw):
    """The Warden's seat: a stone block, a mine-cart body for a back, axles for armrests, rusted plates."""
    y = floor_at(x, z, PIT_Y)
    r = rot_y(yaw)
    fwd = apply(r, (0, 0, -1))
    right = apply(r, (1, 0, 0))
    def at(dx, dz, dy):
        return (x + right[0] * dx - fwd[0] * dz, y + dy, z + right[2] * dx - fwd[2] * dz)
    kids = [part("Block", (7.0, 2.0, 5.5), at(0, 0, 1.0), STONE_DARK, "SmoothPlastic", r),
            part("Step", (7.0, 0.8, 2.0), at(0, -3.6, 0.4), STONE_DARK, "SmoothPlastic", r),
            part("Seat", (4.0, 0.7, 3.4), at(0, 0.3, 2.35), SPLINTER, "SmoothPlastic", r, collide=False),
            part("Back", (4.4, 5.2, 0.6), at(0, 2.2, 4.6), WARLORD_RED, "SmoothPlastic", mul(r, rot_x(-8)), collide=False),
            part("BackPlate", (3.0, 3.0, 0.3), at(0, 2.55, 5.0), RUST, "SmoothPlastic", mul(r, rot_x(-8)), collide=False),
            part("Crest", (1.6, 1.6, 0.4), at(0, 2.3, 7.4), IRON_DARK, "SmoothPlastic", mul(r, rot_y(45)), collide=False)]
    for side in (-1, 1):
        kids.append(part(f"Arm{side}", (0.4, 0.4, 3.6), at(side * 2.2, 0.2, 3.3), RUST, "SmoothPlastic", r, collide=False))
        kids.append(part(f"ArmPost{side}", (0.4, 1.2, 0.4), at(side * 2.2, -1.2, 2.6), IRON_DARK, "SmoothPlastic", r, collide=False))
    return model(name, kids)


def standing_stone(name, x, z, h, rng, lean=True):
    """A round menhir: a stout cylinder up out of the pit floor under a domed cap, leaning a touch.
    It replaced a 4.5 x 3 slab that read as a paper card edge-on (2026-09-24 recording). The three
    that carry manacles stand straight, so the cuffs stay pinned to the face 1.55 studs out."""
    diam = 3.4
    base = (x, PIT_Y - 0.6, z)
    dx, dz = (rng.uniform(-0.45, 0.45), rng.uniform(-0.45, 0.45)) if lean else (0.0, 0.0)
    top = (x + dx, PIT_Y + h - 0.9, z + dz)
    cap_rot = mul(rot_x(math.degrees(math.atan2(dz, h))), rot_z(-math.degrees(math.atan2(dx, h))))
    return model(name, [
        cyl("Body", base, top, diam, STONE_PEACH, layer="rock"),
        ellipsoid("Cap", (diam * 1.08, 2.4, diam * 1.08), top, STONE_CAP, rot=mul(cap_rot, rot_y(rng.uniform(0, 90))),
                  layer="rock"),
    ])


STONE_PEACH = (240, 184, 120)  # recoloured to the basin's pale peach in the desert pass below
STONE_CAP = (250, 206, 150)


def manacles(name, x, y, z, yaw):
    """Empty iron cuffs on a short chain, pinned to a rock face at (x, y, z) facing `yaw`."""
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))
    fwd = apply(r, (0, 0, -1))
    kids = [part("Pin", (0.5, 0.5, 0.9), (x - fwd[0] * 0.25, y, z - fwd[2] * 0.25), IRON_DARK, "SmoothPlastic", r, collide=False)]
    for side in (-1, 1):
        kids.append(part(f"Chain{side}", (0.16, 1.6, 0.16), (x + right[0] * side * 0.5 + fwd[0] * 0.3, y - 0.8,
                                                            z + right[2] * side * 0.5 + fwd[2] * 0.3), IRON_DARK, "SmoothPlastic",
                         rot_z(side * 12), collide=False))
        kids.append(part(f"Cuff{side}", (0.45, 0.9, 0.9), (x + right[0] * side * 0.7 + fwd[0] * 0.35, y - 1.7,
                                                          z + right[2] * side * 0.7 + fwd[2] * 0.35), RUST, "SmoothPlastic",
                         mul(r, rot_y(90)), shape="Cylinder", collide=False))
    return model(name, kids)



def snap_to_terrain(node, base_y, sink=0.3):
    """Tag a model for WorldTerrain to set down on the terrain rock under its pivot (bench-top
    shrubs, trees and blocks: the benches are sculpted at runtime, so their heights are not known
    here). base_y is the height the model was built standing on."""
    node.setdefault("attributes", {}).update({"SnapToTerrain": True, "SnapBaseY": base_y, "SnapSink": sink})
    return node


def raised(node, dy, start):
    """Lift a just-built model by dy studs: every part under it and its REGISTRY entries (those from
    index `start` on), so the preview and floor_at see the same heights as the file."""
    def walk(n):
        cf = n.get("properties", {}).get("CFrame")
        if cf:
            pos = cf["CFrame"]["position"]
            pos[1] = _r(pos[1] + dy)
        for c in n.get("children", ()):
            walk(c)
    walk(node)
    for e in REGISTRY[start:]:
        e["pos"] = (e["pos"][0], e["pos"][1] + dy, e["pos"][2])
    return node


def scaled(node, s, anchor, start, drift=None):
    """Grow a just-built model by `s` about `anchor` (its foot on the ground): every part's size and
    its offset from the anchor, point-light ranges and fire with them, and its REGISTRY entries (those
    from index `start` on), so the preview, floor_at and the validator see the model as written.
    Rotations are untouched (a uniform scale keeps every contact a contact), and no part is added.
    A SandDrift attribute grows by `drift` (default `s`), so WorldTerrain banks the sand higher."""
    ax, ay, az = anchor

    def walk(n):
        p = n.get("properties", {})
        cf = p.get("CFrame")
        if cf and "Size" in p:
            pos = cf["CFrame"]["position"]
            for i, a in enumerate((ax, ay, az)):
                pos[i] = _r(a + (pos[i] - a) * s)
            p["Size"] = [_r(v * s) for v in p["Size"]]
        elif n.get("className") == "PointLight":
            p["Range"] = _r(min(60, p["Range"] * s))
        elif n.get("className") == "Fire":
            p["Size"] = _r(min(30, p["Size"] * s))
            p["Heat"] = _r(min(25, p["Heat"] * s))
        for c in n.get("children", ()):
            walk(c)
    walk(node)
    attrs = node.get("attributes")
    if attrs and "SandDrift" in attrs:
        attrs["SandDrift"] = _r(attrs["SandDrift"] * (s if drift is None else drift))
    for e in REGISTRY[start:]:
        e["pos"] = tuple(a + (v - a) * s for v, a in zip(e["pos"], (ax, ay, az)))
        e["size"] = tuple(v * s for v in e["size"])
    return node


def turned(node, yaw, pivot, start):
    """Turn a just-built model by `yaw` degrees about the vertical line through pivot (x, z): every
    part's position and orientation, its REGISTRY entries (those from index `start` on) and any
    X/Z attribute pair (InsideX/InsideZ), so the preview and the validator see it as written."""
    r = rot_y(yaw)
    px, pz = pivot

    def spin(x, z):
        d = apply(r, (x - px, 0, z - pz))
        return px + d[0], pz + d[2]

    def walk(n):
        cf = n.get("properties", {}).get("CFrame")
        if cf:
            f = cf["CFrame"]
            x, z = spin(f["position"][0], f["position"][2])
            f["position"][0], f["position"][2] = _r(x), _r(z)
            f["orientation"] = [[_r(v) for v in row] for row in mul(r, f["orientation"])]
        for c in n.get("children", ()):
            walk(c)
    walk(node)
    attrs = node.get("attributes", {})
    for key in [k for k in attrs if k.endswith("X") and k[:-1] + "Z" in attrs]:
        x, z = spin(attrs[key], attrs[key[:-1] + "Z"])
        attrs[key], attrs[key[:-1] + "Z"] = _r(x), _r(z)
    for e in REGISTRY[start:]:
        x, z = spin(e["pos"][0], e["pos"][2])
        e["pos"] = (x, e["pos"][1], z)
        e["rot"] = mul(r, e["rot"])
    return node


def grown(s, x, z, build, drift=None):
    """Build a desert prop with `build()` (standing on the floor at (x, z)) and grow it by `s`
    about that foot (see scaled)."""
    start = len(REGISTRY)
    node = build()
    return scaled(node, s, (x, floor_at(x, z, 0.0), z), start, drift)


def quarry_fall(name, x, z, top, bottom, width=6.0):
    """The sump's waterfall: a stream running out of the notch in the east wall's second bench and
    three falling sheets down the plain face below it into the sump, foam and mist at the foot.
    Tagged Waterfall, so HubAmbience shimmers the sheets."""
    height = top - bottom
    kids = []
    # A white core, a blue-green veil either side of it and a loose outer spray, each a little proud
    # of the one behind and ragged at the edges, so the fall reads as tumbling water, not a pane.
    sheets = ((0.0, width, (178, 216, 232), 0.35), (-0.45, width * 0.72, (236, 247, 252), 0.08),
              (-0.9, width * 0.4, (255, 255, 255), 0.02), (-0.7, width * 0.18, (150, 200, 222), 0.25))
    for k, (dx, w, color, tr) in enumerate(sheets):
        kids.append(part(f"WaterSheet{k}", (0.35, height + 0.6, w), (x - 0.5 + dx, bottom + height / 2 + 0.2,
                                                                    z + (0.6 if k == 3 else 0.0)),
                         color, "Glass" if k != 2 else "SmoothPlastic", collide=False, query=False, shadow=False,
                         transparency=tr, layer="decal"))
    # runnels: streaks of darker, faster water down the white core sheet (within its width, so each
    # one is laid on the water, not hung in the air beside it)
    for k, off in enumerate((-0.15, -0.06, 0.05, 0.14)):
        kids.append(part(f"Runnel{k}", (0.12, height - 2.0 - k * 1.5, width * 0.07), (x - 1.45, bottom + height / 2 + k * 0.75,
                                                                                   z + off * width),
                         (104, 160, 182), "Glass", collide=False, query=False, shadow=False, transparency=0.3,
                         layer="decal"))
    kids.append(part("Stream", (15, 0.5, width - 1.2), (x + 7.2, top + 0.15, z), (120, 180, 206), "Glass", collide=False,
                     query=False, shadow=False, transparency=0.25, layer="decal"))
    # The foam crests 0.1 above the sheets' tops (level with them, the two z-fought).
    kids.append(part("LipFoam", (1.2, 0.8, width - 0.6), (x - 0.2, top + 0.2, z), (232, 244, 248), "SmoothPlastic",
                     collide=False, query=False, shadow=False, transparency=0.3, layer="decal"))
    kids.append(part("Foam", (0.14, 9.0, 9.0), (x - 4.0, bottom + 0.08, z), (236, 246, 250), "SmoothPlastic", rot_z(90),
                     shape="Cylinder", collide=False, query=False, shadow=False, transparency=0.3, layer="decal"))
    kids.append(part("Mist", (0.5, 0.5, 0.5), (x - 3.0, bottom + 1.2, z), (255, 255, 255), "SmoothPlastic", transparency=1,
                     collide=False, query=False, shadow=False, children=[smoke(5.0, 0.12, 1.4, (236, 242, 246))]))
    return model(name, kids, attrs={"Waterfall": True})


def quarry_derrick(name, x, z, yaw, rng, height=24.0):
    """A timber guy-derrick: a mast on a cross-footed sill, a boom slung out over the pit, guy ropes
    to stakes, a hand winch, and a cut block hanging on the fall rope. Nothing collides."""
    y = floor_at(x, z, PIT_Y)
    r = rot_y(yaw)
    fwd, right = apply(r, (0, 0, -1)), apply(r, (1, 0, 0))

    def at(f, s, h):
        return (x + fwd[0] * f + right[0] * s, y + h, z + fwd[2] * f + right[2] * s)

    kids = [
        part("SillA", (9, 0.9, 1.1), at(0, 0, 0.45), BEAM, "Wood", r, collide=False),
        part("SillB", (1.1, 1.0, 9), at(0, 0, 0.5), BEAM, "Wood", r, collide=False),  # proud of SillA: no shared top
        beam("Mast", at(0, 0, 0.9), at(0, 0, height), 1.3, TIMBER, collide=False),
        part("MastCap", (1.8, 0.8, 1.8), at(0, 0, height + 0.2), RUST, "CorrodedMetal", r, collide=False),
    ]
    tip = at(15, 0, height - 3)
    kids.append(beam("Boom", at(0.8, 0, 3.5), tip, 0.9, TIMBER, collide=False))
    kids.append(beam("Topping", at(0, 0, height - 0.4), tip, 0.18, (70, 60, 48), "Fabric", collide=False, shadow=False))
    for k, (f, s) in enumerate(((-9, -8), (-9, 8), (7, -12))):
        stake = at(f, s, 0)
        # A stake driven into whatever floor it lands on (Stake2 is up on the mid bench, not the pit floor).
        stake = (stake[0], floor_at(stake[0], stake[2], y), stake[2])
        kids.append(beam(f"Guy{k}", at(0, 0, height - 0.6), stake, 0.16, (70, 60, 48), "Fabric", collide=False, shadow=False))
        kids.append(part(f"Stake{k}", (0.5, 1.6, 0.5), (stake[0], stake[1] + 0.5, stake[2]), SPLINTER, "Wood", rot_x(12),
                         collide=False))
    for sgn in (-1, 1):
        kids.append(beam(f"Brace{sgn}", at(0, sgn * 3.6, 0.9), at(0, 0, 7), 0.5, BEAM, collide=False))
    kids.append(part("Winch", (0.9, 1.8, 1.8), at(-1.6, 0, 2.4), (88, 64, 44), "Wood", mul(r, rot_z(0)), shape="Cylinder",
                     collide=False))
    kids.append(part("WinchCrank", (0.3, 0.3, 1.6), at(-1.6, 1.2, 2.9), IRON_DARK, "CorrodedMetal", r, collide=False))
    drop = 9.0
    kids.append(part("Fall", (0.2, drop, 0.2), (tip[0], tip[1] - drop / 2, tip[2]), (70, 60, 48), "Fabric", collide=False,
                     shadow=False))
    kids.append(part("Hook", (0.5, 1.0, 0.5), (tip[0], tip[1] - drop - 0.3, tip[2]), IRON_DARK, "CorrodedMetal",
                     collide=False))
    for k, sgn in enumerate((-1, 1)):
        kids.append(beam(f"Sling{k}", (tip[0], tip[1] - drop - 0.6, tip[2]),
                         (tip[0] + right[0] * sgn * 1.6, tip[1] - drop - 2.4, tip[2] + right[2] * sgn * 1.6), 0.14,
                         (70, 60, 48), "Fabric", collide=False, shadow=False))
    kids.append(part("Block", (4.6, 3.0, 3.6), (tip[0], tip[1] - drop - 3.9, tip[2]), (214, 190, 146), "Limestone",
                     mul(r, rot_y(rng.uniform(-8, 8))), collide=False))
    return model(name, kids)


def wall_scaffold(name, x, z, yaw, height, rng, width=10.0, depth=4.0, base_y=None):
    """Timber working scaffold stood against a quarry face: four posts, two plank decks, X-braces
    on the open side, and a ladder up the front. `yaw` faces it out from the rock."""
    y = floor_at(x, z, base_y if base_y is not None else PIT_Y)
    r = rot_y(yaw)
    fwd, right = apply(r, (0, 0, -1)), apply(r, (1, 0, 0))

    def at(f, s, h):
        return (x + fwd[0] * f + right[0] * s, y + h, z + fwd[2] * f + right[2] * s)

    kids = []
    for sx in (-1, 1):
        for fz in (0, 1):
            kids.append(beam(f"Post{sx}{fz}", at(fz * depth, sx * width / 2, 0), at(fz * depth, sx * width / 2, height),
                             0.8, BEAM, collide=False))
    for k, h in enumerate((height * 0.5, height - 0.3)):
        kids.append(part(f"Deck{k}", (width + 1.2, 0.4, depth + 1.0), at(depth / 2, 0, h), TIMBER, "WoodPlanks",
                         mul(r, rot_z(rng.uniform(-1.5, 1.5))), collide=False))
    kids.append(beam("BraceA", at(depth, -width / 2, 0.6), at(depth, width / 2, height * 0.5 - 0.3), 0.45, SPLINTER,
                     collide=False))
    kids.append(beam("BraceB", at(depth, width / 2, height * 0.5 + 0.3), at(depth, -width / 2, height - 0.6), 0.45, SPLINTER,
                     collide=False))
    kids.append(part("Rail", (width, 0.3, 0.3), at(depth + 0.2, 0, height + 1.1), SPLINTER, "Wood", r, collide=False))
    for k in range(int(height / 1.3)):
        kids.append(part(f"Rung{k}", (2.2, 0.28, 0.28), at(depth + 1.1, -width / 2 + 2.2, 0.8 + k * 1.3), TIMBER, "Wood", r,
                         collide=False))
    for sgn in (-1, 1):
        kids.append(beam(f"LadderRail{sgn}", at(depth + 1.1, -width / 2 + 2.2 + sgn * 1.1, 0),
                         at(depth + 1.1, -width / 2 + 2.2 + sgn * 1.1, height + 0.6), 0.32, SPLINTER, collide=False))
    kids.append(part("Bucket", (1.4, 1.6, 1.6), at(depth / 2 + 1, 2, height * 0.5 + 0.9), (96, 70, 48), "Wood",
                     mul(r, rot_z(90)), shape="Cylinder", collide=False, shadow=False))
    return model(name, kids)


def cut_blocks(name, x, z, rng, y=None, count=5, color=(214, 190, 146), spread=5.0):
    """Sawn limestone blocks from the last cut, stacked two high and a few set down loose."""
    y0 = floor_at(x, z, PIT_Y) if y is None else y
    kids = []
    for k in range(count):
        w, h, d = rng.uniform(3.4, 5.0), rng.uniform(2.2, 3.0), rng.uniform(2.6, 3.6)
        if k < 2:
            px, pz, py = x + (k - 0.5) * (w + 0.3), z, y0 + h / 2
        elif k == 2:
            px, pz, py = x + rng.uniform(-0.6, 0.6), z + rng.uniform(-0.4, 0.4), y0 + 2.6 + h / 2
        else:
            a = rng.uniform(0, math.tau)
            px, pz, py = x + math.cos(a) * spread, z + math.sin(a) * spread, y0 + h / 2 - 0.1
        tone = tuple(max(0, min(255, int(c + rng.uniform(-10, 8)))) for c in color)
        kids.append(part(f"Block{k}", (w, h, d), (px, py, pz), tone, "Limestone", rot_y(rng.uniform(-12, 12)),
                         collide=False, shadow=k < 3, layer="rock"))
    return model(name, kids)


def quarry_dressing():
    """Set dressing for the sculpted quarry: the waterfall into the sump, a derrick and a rail spur
    with a loaded cart on the pit floor, a working scaffold against the mid bench's east face, sawn
    blocks, and shrubs and trees on the bench tops (snapped to the terrain at runtime). A private
    seed, so the shared layout `rng` (and every region after this one) is untouched."""
    lr = random.Random(0x51A7E)
    out = [quarry_fall("SumpFall", 110.0, 347.0, 34.0, PIT_Y - 0.35, width=7.0)]
    out.append(quarry_derrick("PitDerrick", 62, 337, yaw_facing(1, -0.15), lr))
    out.append(rail_run("PitSpurRails", (18, 350), (70, 350)))
    # The cart stands at the spur's west end: IL_B2 (an IronBerserker) spawns on the rails at x=44.
    out.append(mine_cart("PitSpurCart", 26, 0, 350, 90))
    out.append(cut_blocks("PitBlocksA", 70, 334, lr, count=4, spread=4.0))
    out.append(cut_blocks("PitBlocksB", 84, 390, lr, count=4))
    out.append(cut_blocks("PitBlocksC", -70, 440, lr, count=6))
    out.append(cut_blocks("MidBlocks", 98, 290, lr, count=4))
    out.append(wall_scaffold("EastScaffold", 104.5, 312, yaw_facing(-1, 0), 13.0, lr, base_y=MID_Y))
    out.append(wall_scaffold("WestScaffold", -104.5, 420, yaw_facing(1, 0), 17.0, lr))
    # Shrubs and trees on the bench tops, set down on the rock by WorldTerrain. The last figure is
    # roughly the rock top WorldTerrain sculpts under each one (its bench tier profile, sampled at
    # the model's pivot): each is built standing that high and tagged with it as SnapBaseY, so the
    # runtime snap lands it exactly where it always did, while the file on its own already shows it
    # on its bench (built at y=0, the ones over the pit's slab lay buried in it). Rounded to 0.5.
    greens = [
        ("tree", 118, 326, 0.8, 16.0), ("tree", 126, 362, 0.9, 27.5), ("tree", 122, 300, 0.75, 29.5),
        ("tree", 128, 331, 1.0, 31.5), ("tree", -120, 400, 0.85, 18.5), ("tree", 60, 480, 0.9, 17.5),
        ("tree", -60, 480, 0.8, 24.0), ("tree", -118, 200, 0.8, 15.5),
        ("bush", 116, 356, 1.2, 36.0), ("bush", 124, 332, 1.0, 30.0), ("bush", 115, 314, 1.1, 17.0),
        ("bush", 128, 312, 0.9, 28.0), ("bush", 116, 372, 1.0, 17.0), ("bush", 132, 350, 1.2, 45.0),
        ("bush", 118, 404, 1.0, 16.5), ("bush", 124, 430, 1.1, 31.5), ("bush", -116, 380, 1.0, 17.0),
        ("bush", -124, 440, 1.2, 30.0), ("bush", 30, 478, 1.0, 16.5), ("bush", -40, 478, 1.1, 16.5),
        # on the rock rib across the pit
        ("tree", 84, 375, 0.85, 18.5), ("bush", 72, 374, 1.1, 19.0), ("bush", 96, 376, 1.0, 19.5),
        ("tree", -70, 375, 0.8, 21.0),
    ]
    for k, (kind, x, z, sc, bench) in enumerate(greens):
        start = len(REGISTRY)
        if kind == "tree":
            node = tree(f"LedgeTree{k}", x, 0.0, z, lr, scale=sc)
        else:
            node = bush(f"LedgeBush{k}", x, 0.0, z, lr, scale=sc)
        out.append(snap_to_terrain(raised(node, bench, start), bench, sink=0.6 if kind == "tree" else 0.4))
    for k, (x, z, bench) in enumerate(((121, 346, 32.0), (117, 390, 16.5), (-118, 360, 18.5))):
        start = len(REGISTRY)
        node = cut_blocks(f"LedgeBlocks{k}", x, z, lr, y=0.0, count=3, spread=3.5)
        out.append(snap_to_terrain(raised(node, bench, start), bench, sink=0.3))
    return out


def quarry_layout(rng):
    """The Iron Lowlands' floors, walls and gameplay layout, as the old bandit quarry laid them out.
    build_iron_lowlands keeps its floors, proxies and gameplay pieces (waystones, the Briarwood gate,
    the Warden's arena) and dresses the rest as the desert oasis. It still runs whole, so it draws
    from the shared `rng` and reserves cliff tops exactly as before and Briarwood, built after it,
    comes out unchanged."""
    global AUTO_GROUND
    AUTO_GROUND = True
    T = HUB_Y
    # Reserve the floor heights so no cliff or lip chunk top lands coplanar with a walkable top.
    for top in (RIM_Y, MID_Y, PIT_Y, PIT_Y - 1.2, PIT_Y + 0.2, MID_Y + 0.2, PIT_Y + 0.25, PIT_Y + 0.32, MID_Y + 0.32):
        USED_CLIFF_TOPS.add(round(top * 10))
    ground = [
        slab("PassFloor", -14, 14, 104, 140, T, GROUND_PALE, "SmoothPlastic"),
        slab("OverlookFloor", -40, 40, 140, 168, T, GROUND_TAN, "SmoothPlastic"),
        # Bench 1, the rim: level with the overlook; the gang's front yard.
        slab("RimBench", -112, 112, RIM_Z[0], RIM_Z[1], RIM_Y, QUARRY_FLOOR, "SmoothPlastic"),
        # Bench 2: machinery level, plus the back-door passage west.
        slab("MidBench", -112, 112, MID_Z[0], MID_Z[1], MID_Y, GROUND_MID, "SmoothPlastic"),
        slab("PassageFloor", PASSAGE[0], PASSAGE[1], PASSAGE[2], PASSAGE[3], MID_Y, PATH, "SmoothPlastic"),
        # Bench 3, the pit: split around the drainage sump in its east corner.
        slab("PitFloorW", -112, SUMP[0], PIT_Z[0], PIT_Z[1], PIT_Y, GROUND_SAND, "SmoothPlastic"),
        slab("PitFloorE", SUMP[0], 112, SUMP[3], PIT_Z[1], PIT_Y, GROUND_TAN, "SmoothPlastic"),
        slab("SumpBed", SUMP[0], SUMP[1], SUMP[2], SUMP[3], PIT_Y - 1.2, MUD, "SmoothPlastic"),
    ]
    ruts = []
    for name, rect, y0, y1 in (("HaulRamp1", RAMP1, RIM_Y, MID_Y), ("HaulRamp2", RAMP2, MID_Y, PIT_Y)):
        floor, curbs = haul_ramp(name, *rect, y0, y1)
        ground.append(floor)
        ruts += curbs
    # Haul road: ramp 1 foot → south → west → ramp 2; ramp 2 foot → east → through the ridge gap.
    # The road carries real minecart rails (below), so it lays no cart-rut decals of its own.
    for args in (("HaulRoadA", RAMP1[0] + 2, RAMP1[1] - 2, RAMP1[3], 296, MID_Y),
                 ("HaulRoadB", RAMP2[0] + 2, RAMP1[1] - 2, 296, 318, MID_Y, "x"),
                 ("HaulRoadC", RAMP2[0] + 2, RAMP2[1] - 2, 318, RAMP2[2], MID_Y),
                 ("HaulRoadD", RAMP2[0] + 2, RAMP2[1] - 2, RAMP2[3], 362, PIT_Y),
                 ("HaulRoadE", RAMP2[0] + 2, 12, 362, 372, PIT_Y, "x"),
                 ("HaulRoadF", -12, 12, 372, 385.5, PIT_Y)):
        floor, _ = haul_road(*args)
        ground += floor
    ground += disc("ArenaFloor", 0, 424, 38, PIT_Y + 0.25, 0.5, PATH, "SmoothPlastic")
    visual, proxies = [model("HaulRuts", ruts)], []
    # Minecart line down the haul road: rim → ramp 1 → mid bench → ramp 2 → pit → the ridge gap.
    # Each leg runs to the centreline of the next so the corners meet.
    r1x, r2x = (RAMP1[0] + RAMP1[1]) / 2, (RAMP2[0] + RAMP2[1]) / 2
    visual.append(model("HaulRails", [
        rail_run("RailRamp1", (r1x, RAMP1[2]), (r1x, RAMP1[3])),
        rail_run("RailA", (r1x, RAMP1[3]), (r1x, 307)),
        rail_run("RailB", (r1x, 307), (r2x, 307)),
        rail_run("RailC", (r2x, 307), (r2x, RAMP2[2])),
        rail_run("RailRamp2", (r2x, RAMP2[2]), (r2x, RAMP2[3])),
        rail_run("RailD", (r2x, RAMP2[3]), (r2x, 367)),
        rail_run("RailE", (r2x, 367), (0, 367)),
        rail_run("RailF", (0, 367), (0, 385.5)),
    ]))

    # The quarry's walls are sculpted voxel Terrain (lemonade-game/Map/WorldTerrain.server.luau: stepped
    # benches with chipped lips, drill channels and crevices, tilted strata, crags on a broken crest,
    # talus fans at the foot), so no visible wall parts are made here. cliff_run still lays out each
    # run (and draws from `rng` exactly as before, so nothing else in the map moves) for its invisible
    # proxy, which reaches PROXY_TOP and keeps holding players in wherever the crest dips.
    def cliffs(name, pts, inward, base, height, depth=16):
        for i in range(len(pts) - 1):
            _, proxy = cliff_run(f"{name}{i}", pts[i], pts[i + 1], inward, base, height, QUARRY_CLIFF,
                                 QUARRY_CLIFF_DARK, rng, depth=depth)
            proxies.append(proxy)

    # Pass and overlook walls, then the quarry perimeter with its base stepping down per bench.
    cliffs("PassWest", [(-14, 100), (-14, 140), (-40, 140), (-40, 168)], 1, T, 30)
    cliffs("PassEast", [(40, 168), (40, 140), (14, 140), (14, 100)], 1, T, 30)
    cliffs("RimNorthW", [(-40, 168), (-110, 168), (-110, MID_Z[0])], 1, RIM_Y, 40)
    cliffs("RimEast", [(110, MID_Z[0]), (110, 168), (40, 168)], 1, RIM_Y, 40)
    cliffs("MidWest", [(-110, MID_Z[0]), (-110, PASSAGE[2]), (PASSAGE[0] + 2, PASSAGE[2]), (PASSAGE[0] + 2, PASSAGE[3]),
                       (-110, PASSAGE[3])], 1, MID_Y, 44)
    cliffs("MidEast", [(110, PIT_Z[0]), (110, MID_Z[0])], 1, MID_Y, 44)
    # Wall off the hideout's mouth so the elite inside can't be seen from the bench: rock either
    # side of the lantern arch, and a rock lintel above its beam, leaving only the arch as the way in.
    cliffs("PassageMouthN", [(-110, PASSAGE[2]), (-110, PASSAGE[2] + 12)], 1, MID_Y, 44)
    cliffs("PassageMouthS", [(-110, PASSAGE[3] - 12), (-110, PASSAGE[3])], 1, MID_Y, 44)
    # (The rock lintel over the lantern arch is terrain too, its underside at MID_Y + 13.4.)
    cliffs("PitWest", [(-110, PIT_Z[0]), (-110, 470)], 1, PIT_Y, 46)
    cliffs("PitSouth", [(-110, 470), (-19.5, 470)], 1, PIT_Y, 46)  # stop at the gate pillars' outer faces
    cliffs("PitSouthE", [(19.5, 470), (110, 470)], 1, PIT_Y, 46)
    cliffs("PitEast", [(110, 470), (110, PIT_Z[0])], 1, PIT_Y, 46)
    # Bench faces: rock lips along each drop, broken by the haul ramps.
    # Bench faces: the drops between benches are terrain too (a broken rock lip with rubble at its
    # foot, in WorldTerrain); the layout calls stay for their `rng` draws.
    bench_face("RimFaceW", (RAMP1[0], MID_Z[0]), (-112, MID_Z[0]), 1, MID_Y, RIM_Y - MID_Y, rng)
    bench_face("RimFaceE", (112, MID_Z[0]), (RAMP1[1], MID_Z[0]), 1, MID_Y, RIM_Y - MID_Y, rng)
    bench_face("MidFaceW", (RAMP2[0], PIT_Z[0]), (-112, PIT_Z[0]), 1, PIT_Y, MID_Y - PIT_Y, rng)
    bench_face("MidFaceE", (SUMP[0], PIT_Z[0]), (RAMP2[1], PIT_Z[0]), 1, PIT_Y, MID_Y - PIT_Y, rng)
    bench_face("MidFaceSump", (112, PIT_Z[0]), (SUMP[0], PIT_Z[0]), 1, PIT_Y - 1.2, MID_Y - PIT_Y + 1.2, rng)

    # Drainage sump: still brown water in the lowest corner, stone curb on the pit side.
    visual.append(model("Sump", [
        box("Water", SUMP[0] + 0.6, SUMP[1] - 0.6, PIT_Y - 1.2, PIT_Y - 0.35, SUMP[2] + 0.6, SUMP[3] - 0.6, SUMP_WATER,
            "Glass", transparency=0.3, collide=False, query=False, layer="decal"),
        box("CurbW", SUMP[0] - 1.2, SUMP[0] + 0.2, PIT_Y, PIT_Y + 0.8, SUMP[2], SUMP[3] + 1.2, STONE_DARK, "Cobblestone"),
        box("CurbS", SUMP[0] + 0.2, SUMP[1], PIT_Y, PIT_Y + 0.8, SUMP[3], SUMP[3] + 1.2, STONE_DARK, "Cobblestone"),
        box("MudStainA", SUMP[0] - 30, SUMP[0], PIT_Y, PIT_Y + 0.12, 344, 358, MUD, "Mud", collide=False, layer="decal"),
        box("MudStainB", SUMP[0] - 16, SUMP[0], PIT_Y, PIT_Y + 0.12, 358, 366, MUD, "Mud", collide=False, layer="decal"),
    ]))

    # Ridge across the pit with a 40-stud gap so the boss is visible before aggro. The rock rib itself
    # is terrain (WorldTerrain); the layout below still draws from `rng` as before, and its parts are
    # dropped, leaving the proxies.
    for side, (x0, x1) in ((-1, (-110, -20)), (1, (20, 110))):
        for k, xs in enumerate(range(int(x0), int(x1), 15)):
            xe = min(xs + 15, x1)
            h = free_top(PIT_Y + rng.uniform(16, 24) - 1) - PIT_Y + 1
            part(f"Ridge{side}_{k}", (xe - xs + 2, h, 16), ((xs + xe) / 2, PIT_Y + h / 2 - 1, 375),
                 QUARRY_CLIFF_DARK, "Sandstone", rot_y(rng.uniform(-5, 5)), collide=False, layer="cliff")
        proxies.append(box(f"RidgeProxy{side}", x0, x1, PIT_Y - 1, PIT_Y + 26, 368, 382, (255, 0, 255), transparency=1,
                           query=False, shadow=False, layer="proxy"))

    visual.append(waystone("OverlookWaystone", "IronOverlook", 31, T, 145))
    visual.append(spoil_heap("SpoilHeapRim", -84, 200, rng, radius=11))
    visual.append(spoil_heap("SpoilHeapPit", -80, 404, rng, radius=14))

    # Rim bench: the yard the crews worked from; the gang's front door.
    for k, (x, z) in enumerate(((-100, 186), (96, 192), (92, 224), (60, 178))):
        visual.append(rock_cluster(f"RimRocks{k}", x, 0, z, rng, color=(118, 100, 84), size=1.2))
    visual.append(lean_to_ruin("SmithyRuin", 70, 86, 198, 212, rng))
    visual.append(collapsed_scaffold("FallenScaffold", -104, 212, rng))
    visual.append(broken_cart("BrokenCart", -20, 186, 40, rng))
    visual.append(ore_chute("OreChute", -58, 224, 248, RIM_Y, rng))
    visual.append(ladder("RimLadder", -22, MID_Z[0] + 3.6, 0, 5.2))  # foot clear of the rock toe, top leaning on it
    visual.append(lamp_post("RimLampW", -16, 0, 204, yaw_facing(1, 0)))
    visual.append(lamp_post("RampLamp", RAMP1[1] + 3, 0, 244, yaw_facing(-1, 0)))

    # Mid bench: machinery level. Crusher house west, head-frame east, rail spur along the east wall.
    visual.append(crusher_house("CrusherHouse", -102, -72, 246, 272, rng))
    visual.append(head_frame("HeadFrame", 64, 246, rng))
    visual.append(rail_track("SpurRails", 94, 0.2, 240, 322))
    visual.append(mine_cart("SpurCartA", 94, 0.4, 262, 0))
    visual.append(derailed_cart("DerailedCart", 88, 300, rng))
    visual.append(bent_rails("SpurEnd", 94, 322, rng))
    visual.append(ladder("MidLadder", 60, PIT_Z[0] + 3.6, 0, 5.2))
    for k, (x, z) in enumerate(((-88, 296), (-92, 316), (70, 322), (-58, 300))):
        visual.append(stone_stack(f"MidStones{k}", x, 0, z, rng))
    for k, (x, z) in enumerate(((82, 252), (-100, 284), (100, 250))):
        visual.append(rock_cluster(f"MidRocks{k}", x, 0, z, rng, color=ROCK_GRAY))
    for k, (x, z) in enumerate(((-68, 250), (-70, 278), (-64, 282))):
        visual.append(barrel(f"MidBarrel{k}", x, 0, z, rng))
    visual.append(lamp_post("MidLampE", 36, 0, 300, yaw_facing(-1, 0)))

    # Bandit occupation: they sleep in the crusher house and cook outside its bay.
    visual.append(bedroll("BedrollA", -96, 252, 90))
    visual.append(bedroll("BedrollB", -96, 259, 84, color=(96, 84, 70)))
    visual.append(bedroll("BedrollC", -82, 265, 100, color=(110, 70, 60)))
    visual.append(crate_stack("LootCrates", -78, 0, 252, rng))
    visual.append(model("LootChest", [
        part("Chest", (4.0, 2.6, 2.6), (-92, MID_Y + 1.3, 268), (110, 70, 40), "WoodPlanks", rot_y(-14)),
        part("ChestBand", (4.2, 0.45, 2.8), (-92, MID_Y + 1.9, 268), GOLD, "Metal", rot_y(-14), collide=False),
        part("Coins", (1.6, 0.5, 1.2), (-90.2, MID_Y + 2.75, 267.2), GOLD, "Metal", rot_y(20), collide=False, query=False),
    ]))
    visual.append(hanging_lantern("BayLantern", -73.5, MID_Y + 7.6, 259))
    visual.append(cook_fire("CookFire", -62, 264, rng))
    visual.append(hay_bale("CampHay", -56, 0, 256, 30))
    visual.append(hand_cart("StolenCart", 40, 0, 184, 70))
    visual.append(skull_sign("TurnBackSign", 38, 258, yaw_facing(0, -1), "TURN BACK", "Quarry Bandits"))
    visual.append(barricade("BarricadeA", RAMP1[0] + 6, 276, 0, 12, rng))
    visual.append(barricade("BarricadeB", -20, 302, 90, 10, rng))
    # Lookout on the head-frame with the gang's rag banner.
    visual.append(part("LookoutDeck", (6.4, 0.5, 6.0), (64, MID_Y + 12, 246), TIMBER, "WoodPlanks", collide=False))
    visual.append(part("LookoutRail", (6.4, 0.3, 0.3), (64, MID_Y + 13.6, 249.2), SPLINTER, "Wood", collide=False))
    visual.append(ladder("LookoutLadder", 64, 250.4, 0, 12.6, lean=18))
    visual.append(rag_banner("LookoutBanner", 66.4, 243.6, 0, height=8, on_y=MID_Y + 12.25))
    visual.append(hanging_lantern("LookoutLantern", 61.6, MID_Y + 12.25, 243.6, drop=0.2))
    # Back-door hideout in the passage.
    visual.append(tent("HideoutTentA", -150, 0, 282, 10))
    visual.append(tent("HideoutTentB", -128, 0, 318, -12, color=(255, 110, 160)))
    visual.append(bedroll("HideoutBedroll", -150, 312, 80, color=(160, 104, 255)))
    visual.append(crate_stack("HideoutCrates", -134, 0, 284, rng))
    visual.append(rag_banner("HideoutBanner", -118, 276, 90))
    # The old plank "ledges" on the pit walls are gone (the terrain walls have real benches); the
    # calls stay for their `rng` draws.
    bench_lines("EastBenchLines", 110, PIT_Z[0] + 4, 468, PIT_Y, rng)
    bench_lines("WestBenchLines", -110, PIT_Z[0] + 30, 468, PIT_Y, rng, inward=1)

    # Back-door passage: lantern arch, hidden elite, a supply cache (decorative for now).
    visual.append(model("SideArch", [
        part("PostN", (1.6, 12, 1.6), (-111, MID_Y + 6, PASSAGE[2] + 12), BEAM, "Wood"),
        part("PostS", (1.6, 12, 1.6), (-111, MID_Y + 6, PASSAGE[3] - 12), BEAM, "Wood"),
        part("Beam", (1.8, 1.6, PASSAGE[3] - PASSAGE[2] - 22.4), (-111, MID_Y + 12.4, (PASSAGE[2] + PASSAGE[3]) / 2), BEAM, "Wood",
             collide=False),
        hanging_lantern("LanternN", -111, MID_Y + 11.6, PASSAGE[2] + 15, drop=1.2),
    ]))
    visual.append(model("SupplyCache", [
        part("Chest", (4.5, 3, 3), (-158, MID_Y + 1.5, 300), SPLINTER, "SmoothPlastic"),
        part("ChestBand", (4.7, 0.5, 3.2), (-158, MID_Y + 2.2, 300), GOLD, "SmoothPlastic", collide=False),
        part("Crate1", (4, 4, 4), (-156, MID_Y + 2, 290), TIMBER, "SmoothPlastic", rot_y(12)),
        part("Crate2", (3.4, 3.4, 3.4), (-159, MID_Y + 1.7, 311), TIMBER, "SmoothPlastic", rot_y(-20)),
    ]))

    # Pit: lamps at the ramp foot, standing stones and braziers around the boss, sealed Briarwood gate.
    visual.append(lamp_post("PitLampW", RAMP2[0] - 8, 0, 338, yaw_facing(1, 0)))
    for k in range(14):
        a = math.tau * k / 14
        if k in (0, 7):  # openings facing the ridge gap (north) and the Briarwood gate (south)
            continue
        x, z = math.sin(a) * 42, 424 - math.cos(a) * 42
        h = rng.uniform(10, 15)
        # own seed per stone: drawing its lean from `rng` would reshuffle every region built after the pit
        visual.append(standing_stone(f"StandingStone{k:02d}", x, z, h, random.Random(0x5701 + k), lean=k not in (3, 5, 10)))
    for k, (x, z) in enumerate(((-22, 390), (22, 390), (-42, 440), (42, 440))):
        visual.append(brazier(f"PitBrazier{k}", x, 0, z))
    # The Warden's throne behind the arena, gang banners, empty manacles on three standing stones.
    visual.append(throne("WardenThrone", 0, 454, yaw_facing(0, -1)))
    for k, x in enumerate((-9, 9)):
        visual.append(rag_banner(f"ThroneBanner{k}", x, 458, yaw_facing(0, -1), height=11, color=WARLORD_RED))
    for k, x in enumerate((-18, 18)):
        visual.append(banner_pole(f"WarlordBanner{k}", x, 0, 464, 0))
    for k in (3, 5, 10):
        a = math.tau * k / 14
        x, z = math.sin(a) * 42, 424 - math.cos(a) * 42
        visual.append(manacles(f"Manacles{k}", x - math.sin(a) * 1.55, PIT_Y + 5.2, z + math.cos(a) * 1.55,
                               yaw_facing(-math.sin(a), math.cos(a))))
    # Gate leaves hang open, folded back flat against the ridge ends inside the gap: the lane and the
    # view of the Warden stay clear.
    visual.append(scrap_gate("ScrapGateW", -18.3, 367.5, -90))
    visual.append(scrap_gate("ScrapGateE", 18.3, 367.5, -90))
    visual.append(sign("WardenSign", 36, 0, 360, yaw_facing(0, -1), 12, 5, "Warden's Pit",
                       "Warden of the Pit  |  Lv 10  |  Boss", board=WARLORD_RED))
    visual.append(waystone("WarlordWaystone", "WarlordGate", 12, 0, 352))
    visual.append(gate("GateBriarwood", 0, PIT_Y, 470, 0, 24, 22, "Briarwood", "Lv 9+  |  The wooded vale", sealed=False,
                       accent=(90, 120, 60), region="Briarwood", required_level=9,
                       back_title="Iron Lowlands", back_subtitle="Warden's Pit"))
    visual += quarry_dressing()
    REGISTRY[:] = [e for e in REGISTRY if not (e["layer"] == "cliff" and (
        re.match(r"^(PassWest|PassEast|RimNorthW|RimEast|MidWest|MidEast|PassageMouth[NS]|PitWest|PitSouth|PitSouthE|PitEast)"
                 r"\d+_\d+(_cap)?$", e["name"]) or re.match(r"^Ledge\d+_\d+$", e["name"])
        or re.match(r"^(Rim|Mid)Face(W|E|Sump)_\d+(_cap)?$", e["name"])
        or re.match(r"^Ridge-?1_\d+$", e["name"])))]
    return ground, visual, proxies


# ── Iron Lowlands: the desert oasis ──────────────────────────────────────────
# The basin itself (sand, dunes, scarps, striped mesas and rock towers, the oasis pool under its
# overhang, the hideout arch) is voxel Terrain built by lemonade-game/Map/WorldTerrain.server.luau on
# the quarry's floors. What stands on the sand is here: a small adobe settlement (sun-baked plaster
# houses with dark window frames, vigas, parapets and striped awnings), the bandits' tent camp round
# its fire, market stalls, palms and reeds at the oasis, cacti, fences, clay pots, lemon crates and
# the scattered rubble that seats everything in the sand. Pet Simulator 99's toy box, all smooth
# plastic: the big calm surfaces (walls, trim, rubble) are pale apricot and cream, a tint of a hue
# and never grey; the shadow side (plinths, pots, beams) is the same apricot pushed to a saturated
# terracotta, never brown; and the small things (awnings, tents, doors, panes, crates) are the
# full-chroma pops: hot pink, orange, lemon, cyan.
# The walls alternate house by house between pale apricot and a blue-washed powder blue (the
# painted-adobe towns of the Maghreb): one calm warm tone and one calm cool tone, as PS99 pairs its
# cream and lavender-blue walkways, with the terracotta and the awnings left to carry the colour.
ADOBE_WALLS = [(255, 204, 160), (180, 212, 255), (255, 206, 164), (184, 214, 255)]
ADOBE_PLINTH = (240, 104, 54)  # the walls' shadow side: saturated terracotta
ADOBE_TRIM = (255, 248, 234)  # copings and sills: nearly white cream
ADOBE_BRICK = (250, 140, 90)  # the painted tiles by the doors
FRAME_DARK = (255, 250, 240)  # window frames: toy white
PANE_DARK = (96, 186, 255)  # window panes: sky-blue glass
DOOR = (40, 196, 214)  # turquoise doors: the cool pop against the apricot
VIGA = (236, 124, 52)  # beams, poles and lintels: crate orange one step deeper
AWNINGS = [(255, 72, 110), (255, 150, 40), (255, 212, 48), (48, 196, 240)]  # hot pink, orange, lemon, cyan
AWNING_CREAM = (255, 250, 236)
POT_CLAY = [(248, 120, 72), (240, 104, 64), (255, 138, 86)]
CACTUS = [hsv(140, 0.8, 0.88), hsv(134, 0.74, 0.94), hsv(146, 0.66, 0.98)]  # full-chroma toy greens: the desert's pop
PALM_TRUNK = hsv(38, 0.24, 1.0)  # calm sandy-cream trunk
PALM_TRUNK_ALT = hsv(34, 0.36, 0.98)  # the same cream one step warmer on alternate segments
PALM_RING = hsv(28, 0.86, 0.96)  # the growth rings as full-chroma orange candy stripes
PALM_LEAF = [hsv(104, 0.82, 0.96), hsv(112, 0.88, 0.84), hsv(96, 0.34, 1.0)]  # lime body, deeper lime, pale-lime highlight
RUBBLE = [(255, 232, 204), (255, 220, 186), (252, 236, 214), (255, 214, 180)]  # pale cream-apricot: calm, never tan
TENT_CLOTH = [(255, 110, 160), (60, 196, 245), (160, 104, 255)]  # candy pink, cyan, violet
# Rubble used to draw a random stone finish per block; it is all smooth plastic now, but the draw is
# kept (three entries, as before) so the shared random stream, and every placement after it, is unchanged.
RUBBLE_FINISH = ("SmoothPlastic",) * 3
LEMON = (252, 220, 60)


def local_frame(x, y, z, yaw):
    """Rotation and a local→world point mapper for a model standing at (x, y, z) facing `yaw`."""
    r = rot_y(yaw)

    def at(lx, ly, lz):
        d = apply(r, (lx, 0, lz))
        return (x + d[0], y + ly, z + d[2])
    return r, at


def rubble(name, x, z, rng, n=8, spread=4.0, y=None, drift=0.9, shadow=False):
    """A heap of fallen sandstone and adobe brick: a few big blocks bedded in the sand with one or
    two more tumbled on top, and a scatter of chips round it. Tagged SandDrift, so WorldTerrain
    heaps sand into the pile and it rises out of a little mound instead of lying on the ground: the
    big blocks are bedded well down, the chips half sunk. `shadow` lets the big blocks cast
    their contact shadow (for the heaps in the foreground of the camp)."""
    y = floor_at(x, z, y)
    kids = []
    big = max(3, n // 2)
    tops = []
    for k in range(big):
        a = k / big * math.tau + rng.uniform(-0.4, 0.4)
        d = spread * 0.22 * rng.uniform(0.3, 1.0)
        sx, sy, sz = rng.uniform(1.4, 2.3), rng.uniform(0.9, 1.4), rng.uniform(1.1, 1.8)
        cx, cz = x + math.cos(a) * d, z + math.sin(a) * d
        kids.append(part(f"Block{k}", (sx, sy, sz), (cx, y + sy * 0.2, cz), rng.choice(RUBBLE),
                         rng.choice(RUBBLE_FINISH),
                         mul(rot_y(rng.uniform(0, 180)), rot_x(rng.uniform(-10, 10))), collide=False, query=False,
                         shadow=shadow))
        tops.append((cx, y + sy * 0.7, cz))
    for k in range(min(2, big - 1)):  # tumbled onto the blocks below, sunk into them a little
        bx, by, bz = tops[k]
        sx, sy, sz = rng.uniform(1.0, 1.6), rng.uniform(0.7, 1.0), rng.uniform(0.9, 1.3)
        kids.append(part(f"Top{k}", (sx, sy, sz), ((bx + x) / 2, by + sy * 0.15, (bz + z) / 2), rng.choice(RUBBLE),
                         "SmoothPlastic", mul(rot_y(rng.uniform(0, 180)), rot_z(rng.uniform(-18, 18))), collide=False,
                         query=False, shadow=False))
    for k in range(n - big):
        a, d = rng.uniform(0, math.tau), spread * rng.uniform(0.45, 1.0)
        sx, sy, sz = rng.uniform(0.5, 1.2), rng.uniform(0.35, 0.7), rng.uniform(0.45, 1.0)
        kids.append(part(f"Bit{k}", (sx, sy, sz), (x + math.cos(a) * d, y + sy * 0.25, z + math.sin(a) * d),
                         rng.choice(RUBBLE), rng.choice(RUBBLE_FINISH),
                         mul(rot_y(rng.uniform(0, 180)), rot_x(rng.uniform(-14, 14))), collide=False, query=False,
                         shadow=False, layer="decal"))
    return model(name, kids, attrs={"SandDrift": drift} if drift else None)


def clay_pot(name, x, z, rng, scale=1.0, y=None):
    y = floor_at(x, z, y) - 0.25 * scale  # set down in the sand, not on it
    s = scale
    c = rng.choice(POT_CLAY)
    return model(name, attrs={"SandDrift": 0.55}, children=[
        part("Belly", (1.9 * s, 1.9 * s, 1.9 * s), (x, y + 0.85 * s, z), c, "SmoothPlastic", shape="Ball", collide=False),
        part("Neck", (0.8 * s, 1.1 * s, 1.1 * s), (x, y + 1.95 * s, z), c, "SmoothPlastic", rot_z(90), shape="Cylinder",
             collide=False),
        part("Lip", (0.2 * s, 1.4 * s, 1.4 * s), (x, y + 2.45 * s, z), ADOBE_BRICK, "SmoothPlastic", rot_z(90), shape="Cylinder",
             collide=False),
    ])


def lemon_crate(name, x, z, yaw, rng, y=None):
    """Lemonade's own touch: a crate of lemons."""
    y = floor_at(x, z, y) - 0.2  # its foot sunk in the sand (WorldTerrain drifts round it)
    r, at = local_frame(x, y, z, yaw)
    kids = [part("Crate", (2.6, 1.5, 2.2), at(0, 0.75, 0), TIMBER, "SmoothPlastic", r)]
    for k in range(5):
        kids.append(part(f"Lemon{k}", (0.8, 0.7, 0.7), at(-0.8 + (k % 3) * 0.8, 1.6 + (k // 3) * 0.3, -0.4 + (k % 2) * 0.8),
                         LEMON, "SmoothPlastic", mul(r, rot_y(rng.uniform(0, 90))), shape="Ball", collide=False,
                         query=False, shadow=False))
    return model(name, kids, attrs={"SandDrift": 0.45})


def adobe_window(kids, at, r, lx, ly, face_z, shutters=None):
    """A dark pane in a timber frame with a cross bar, a plaster sill and a beam lintel."""
    kids.append(part("Pane", (2.0, 2.4, 0.3), at(lx, ly, face_z - 0.1), PANE_DARK, "SmoothPlastic", r, collide=False))
    kids.append(part("FrameV", (0.32, 2.7, 0.3), at(lx, ly, face_z - 0.22), FRAME_DARK, "SmoothPlastic", r, collide=False))
    kids.append(part("FrameH", (2.3, 0.32, 0.3), at(lx, ly + 0.15, face_z - 0.22), FRAME_DARK, "SmoothPlastic", r, collide=False))
    kids.append(part("Sill", (2.9, 0.4, 0.8), at(lx, ly - 1.45, face_z - 0.3), ADOBE_TRIM, "SmoothPlastic", r, collide=False))
    kids.append(part("Lintel", (3.1, 0.55, 0.7), at(lx, ly + 1.5, face_z - 0.25), VIGA, "SmoothPlastic", r, collide=False))
    if shutters:
        for side in (-1, 1):
            kids.append(part(f"Shutter{side}", (0.95, 2.5, 0.2), at(lx + side * 1.55, ly, face_z - 0.12), shutters,
                             "SmoothPlastic", r, collide=False))


def adobe_box(kids, at, r, rng, w, d, h, y0, wall, vigas=True, lz0=0.0, lx0=0.0):
    """One storey: a plaster body on a sandstone plinth, a roof lip, parapets front and back and
    the ends of the roof beams (vigas) poking out of the front. Returns the roof top height."""
    kids.append(part("Body", (w, h, d), at(lx0, y0 + h / 2, lz0), wall, "SmoothPlastic", r))
    kids.append(part("Coping", (w + 0.7, 0.7, d + 0.7), at(lx0, y0 + h + 0.35, lz0), ADOBE_TRIM, "SmoothPlastic", r))
    top = y0 + h + 0.7
    for k, sz in enumerate((-1, 1)):
        kids.append(part(f"Parapet{k}", (w + 0.7, 1.3, 0.8), at(lx0, top + 0.65, lz0 + sz * (d + 0.7 - 0.8) / 2),
                         wall, "SmoothPlastic", r))
    for k, sx in enumerate((-1, 1)):
        kids.append(part(f"ParapetEnd{k}", (0.8, 1.0, d + 0.7 - 1.6), at(lx0 + sx * (w + 0.7 - 0.8) / 2, top + 0.5, lz0),
                         wall, "SmoothPlastic", r))
    if vigas:
        n = max(2, int(w / 3.4))
        for k in range(n):
            lx = lx0 - w / 2 + w * (k + 0.5) / n
            kids.append(part(f"Viga{k}", (2.4, 0.6, 0.6), at(lx, y0 + h - 1.0, lz0 - d / 2 - 0.7), VIGA, "SmoothPlastic",
                             mul(r, rot_y(90)), shape="Cylinder", collide=False))
    return top


def adobe_house(name, x, z, w, d, h, face, rng, wall=None, awning=None, upper=None, windows=2, shutters=None,
                drift=2.8):
    """A sun-baked adobe house: plaster walls on a sandstone plinth, dark framed windows, a timber
    door under a striped awning, vigas, parapets, patches of bare brick where the plaster has
    flaked, and optionally a smaller upper storey set back on the roof.
    Tagged SandDrift: WorldTerrain piles sand against its walls. The front faces `face`."""
    y = floor_at(x, z, None)
    wall = wall or rng.choice(ADOBE_WALLS)
    r, at = local_frame(x, y - 0.3, z, yaw_facing(*face))
    kids = [part("Plinth", (w + 0.5, 1.5, d + 0.5), at(0, 0.75, 0), ADOBE_PLINTH, "SmoothPlastic", r)]
    roof = adobe_box(kids, at, r, rng, w, d, h, 0.0, wall)
    fz = -d / 2
    door_x = rng.choice((-1, 1)) * (w / 2 - 3.2) if w > 11 else 0.0
    kids.append(part("Door", (3.2, 5.6, 0.35), at(door_x, 2.8, fz - 0.1), DOOR, "SmoothPlastic", r, collide=False))
    kids.append(part("DoorLintel", (4.6, 0.7, 0.9), at(door_x, 5.95, fz - 0.3), VIGA, "SmoothPlastic", r, collide=False))
    slots = [lx for lx in (-w / 2 + 2.6, 0.0, w / 2 - 2.6) if abs(lx - door_x) > 3.6][:windows]
    for lx in slots:
        adobe_window(kids, at, r, lx, 3.9 if h < 9.5 else 3.6, fz, shutters)
    aw = 5.2
    if h >= 9.5:  # a second row, clear of the door's awning
        for lx in [lx for lx in slots if not awning or abs(lx - door_x) > aw / 2 + 2.3]:
            adobe_window(kids, at, r, lx, h - 3.0, fz, shutters)
    if awning:
        for k in range(4):
            kids.append(part(f"Awning{k}", (aw / 4, 0.18, 3.2), at(door_x - aw / 2 + aw * (k + 0.5) / 4, 7.2, fz - 1.5),
                             awning if k % 2 == 0 else AWNING_CREAM, "SmoothPlastic", mul(r, rot_x(-16)), collide=False,
                             layer="roof"))
        for side in (-1, 1):
            kids.append(part(f"AwningPole{side}", (0.3, 6.9, 0.3), at(door_x + side * (aw / 2 - 0.2), 3.45, fz - 2.9),
                             VIGA, "SmoothPlastic", r, collide=False))
    # painted terracotta tiles set into the wall by the corners (smooth, no flaking or grime)
    for k in range(2):
        px = rng.choice((-1, 1)) * (w / 2 - rng.uniform(0.9, 1.6))
        py = rng.uniform(2.2, h - 2.2)
        kids.append(part(f"Brick{k}", (rng.uniform(1.4, 2.4), rng.uniform(0.9, 1.6), 0.12), at(px, py, fz - 0.06),
                         ADOBE_BRICK, "SmoothPlastic", r, collide=False, query=False, shadow=False))
    if upper:
        uw, ud, uh = upper
        lz = d / 2 - ud / 2 - 0.4
        lx = rng.choice((-1, 1)) * (w - uw) / 2 * 0.6
        adobe_box(kids, at, r, rng, uw, ud, uh, roof, wall, lz0=lz, lx0=lx)
        adobe_window(kids, at, r, lx, roof + uh * 0.55, lz - ud / 2, shutters)
    return model(name, kids, attrs={"SandDrift": drift})


def a_tent(name, x, z, yaw, cloth, length=7.4, half=3.2, height=4.6, drift=1.4, stripe=None, rng=None):
    """An A-frame tent of candy-coloured toy cloth over a ridge pole, crossed poles jutting past the ridge at
    both ends. `yaw` turns the ridge; its ends face along it. Each side is cut the way cloth hangs:
    it falls steep from the ridge to a knee where it sags in, a dyed band (`stripe`, the awnings'
    terracotta) runs along the knee, and below it the skirt flares out to the ground in two
    panels at slightly different angles, so the hem ripples in folds instead of one straight edge.
    Tagged SandDrift: WorldTerrain heaps sand along the hem, which is sunk into it."""
    y = floor_at(x, z, None) - 0.15
    r, at = local_frame(x, y, z, yaw)
    stripe = stripe or AWNINGS[3]
    faded = tuple(min(255, round(c * 0.9 + 18)) for c in cloth)  # the sunward canvas, bleached paler
    kids = []
    knee_y = height * 0.42
    for sgn in (-1, 1):
        top = (0.0, height)
        knee = (sgn * half * 0.5, knee_y)  # inside the straight ridge-to-foot line: the sag
        cloth_s = faded if sgn > 0 else cloth
        dusty = tuple(round(c * 0.86) for c in cloth_s)  # the skirt: the same hue one step darker, never stained
        # upper sheet: ridge to knee
        ln = math.hypot(knee[0] - top[0], knee[1] - top[1])
        ang = math.degrees(math.atan2(top[1] - knee[1], abs(knee[0])))
        rz = rot_z(ang if sgn < 0 else -ang)
        # two sheets meeting in a shallow crease halfway along, where the cloth sags between the poles
        for k, lz in enumerate((-length / 4, length / 4)):
            kids.append(part(f"Canvas{sgn}_{k}", (ln + 0.2, 0.22, length / 2 + 0.05),
                             at(knee[0] / 2 * (1.04 if k else 1.0), (top[1] + knee[1]) / 2, lz), cloth_s, "SmoothPlastic",
                             mul(mul(r, rz), rot_x((-1 if k else 1) * sgn * 4.0)), collide=False, layer="roof"))
        # the dyed band along the knee, standing just proud of the sheet
        kids.append(part(f"Band{sgn}", (1.1, 0.4, length + 0.05), at(knee[0] * 0.93, knee[1] + 0.35, 0), stripe,
                         "SmoothPlastic", mul(r, rz), collide=False, query=False, shadow=False, layer="roof"))
        # the skirt: two panels, each flaring out to its own foot, the hem sunk into the sand
        for k, (lz, flare, foot_y) in enumerate(((-length / 4, 1.12, -0.35), (length / 4, 1.0, -0.2))):
            foot = (sgn * half * flare, foot_y)
            ln2 = math.hypot(foot[0] - knee[0], foot[1] - knee[1])
            ang2 = math.degrees(math.atan2(knee[1] - foot[1], abs(foot[0] - knee[0])))
            rz2 = mul(rot_z(ang2 if sgn < 0 else -ang2), rot_x((1 if k else -1) * 1.5))
            kids.append(part(f"Skirt{sgn}_{k}", (ln2 + 0.25, 0.22, length / 2 + 0.06),
                             at((knee[0] + foot[0]) / 2, (knee[1] + foot[1]) / 2, lz), dusty, "SmoothPlastic", mul(r, rz2),
                             collide=False, layer="roof"))
        # the crossed poles, along the straight ridge-to-foot line
        slant = math.hypot(half, height)
        pang = math.degrees(math.atan2(height, half))
        prz = rot_z(pang if sgn < 0 else -pang)
        ux, uy = (half / slant) * (-sgn), height / slant
        for k, lz in enumerate((-length / 2 - 0.1, length / 2 + 0.1)):
            kids.append(part(f"Pole{sgn}_{k}", (slant + 1.6, 0.35, 0.35),
                             at(sgn * half / 2 + ux * 0.8, height / 2 + uy * 0.8, lz), VIGA, "SmoothPlastic", mul(r, prz),
                             collide=False))
    kids.append(part("Ridge", (length + 0.8, 0.4, 0.4), at(0, height, 0), VIGA, "SmoothPlastic", mul(r, rot_y(90)),
                     shape="Cylinder", collide=False))
    return model(name, kids, attrs={"SandDrift": drift})


def desert_fire(name, x, z, rng):
    """The camp fire: a ring of sandstone, crossed logs, a bed of embers, flame and warm light."""
    y = floor_at(x, z, None)
    kids = []
    for k in range(8):
        a = k / 8 * math.tau + rng.uniform(-0.15, 0.15)
        kids.append(part(f"Stone{k}", (1.3, 0.8, 1.0), (x + math.cos(a) * 2.3, y + 0.3, z + math.sin(a) * 2.3),
                         rng.choice(RUBBLE), "SmoothPlastic", mul(rot_y(math.degrees(-a)), rot_x(rng.uniform(-8, 8))),
                         collide=False))
    for k in range(3):
        kids.append(part(f"Log{k}", (0.8, 0.8, 3.8), (x, y + 0.5, z), TRUNK, "SmoothPlastic", mul(rot_y(k * 60 + 10), rot_x(16)),
                         collide=False))
    kids.append(part("Embers", (1.4, 0.35, 1.4), (x, y + 0.35, z), EMBER, "Neon", collide=False, query=False,
                     shadow=False, children=[fire(5, 8), light(24, 1.7, (255, 170, 96))]))
    return model(name, kids)


def camp_table(name, x, z, yaw, rng, chairs=2):
    y = floor_at(x, z, None)
    r, at = local_frame(x, y - 0.1, z, yaw)
    kids = [part("Top", (4.6, 0.35, 2.8), at(0, 2.75, 0), TIMBER, "SmoothPlastic", r)]
    for k, (sx, sz) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        kids.append(part(f"Leg{k}", (0.35, 2.6, 0.35), at(sx * 1.9, 1.3, sz * 1.05), VIGA, "SmoothPlastic", r))
    kids.append(part("Mug0", (0.7, 0.55, 0.55), at(-0.9, 3.28, 0.3), (255, 250, 240), "SmoothPlastic", mul(r, rot_z(90)),
                     shape="Cylinder", collide=False, query=False, shadow=False))
    kids.append(part("Jug", (1.2, 0.9, 0.9), at(1.1, 3.5, -0.2), POT_CLAY[0], "SmoothPlastic", mul(r, rot_z(90)), shape="Cylinder",
                     collide=False, query=False, shadow=False))
    for c in range(chairs):
        side = -1 if c % 2 == 0 else 1
        cr = mul(r, rot_y(180 if side < 0 else 0))
        cx, cy, cz = at(-side * 0.6, 0.0, side * 2.6)

        def cp(lx, ly, lz, cx=cx, cy=cy, cz=cz, cr=cr):
            d = apply(cr, (lx, 0, lz))
            return (cx + d[0], cy + ly, cz + d[2])
        kids.append(part(f"Seat{c}", (1.8, 0.3, 1.7), cp(0, 1.6, 0), AWNINGS[3], "SmoothPlastic", cr))
        kids.append(part(f"Back{c}", (1.8, 2.1, 0.3), cp(0, 2.6, 0.85), AWNINGS[3], "SmoothPlastic", cr))
        for k, sx in enumerate((-0.75, 0.75)):
            kids.append(part(f"Side{c}_{k}", (0.3, 1.45, 1.5), cp(sx, 0.72, 0), VIGA, "SmoothPlastic", cr))
    return model(name, kids, attrs={"SandDrift": 0.35})


def log_bench(name, x, z, yaw, length=8.0):
    y = floor_at(x, z, None) - 0.2  # the log half-settled into the sand
    r, at = local_frame(x, y, z, yaw)
    return model(name, [
        part("Log", (length, 1.7, 1.7), at(0, 0.7, 0), VIGA, "SmoothPlastic", r, shape="Cylinder"),
        part("Seat", (length - 0.6, 0.3, 1.2), at(0, 1.5, 0), TIMBER, "SmoothPlastic", r, collide=False),
    ], attrs={"SandDrift": 0.45})


def saguaro(name, x, z, h, rng, arms=2):
    """A saguaro: a ribbed trunk with rounded top and one or two upturned arms."""
    y = floor_at(x, z, None) - 0.3
    c = rng.choice(CACTUS)
    yaw = rng.uniform(0, 180)
    r, at = local_frame(x, y, z, yaw)
    kids = [part("Trunk", (h, 1.9, 1.9), at(0, h / 2, 0), c, "SmoothPlastic", rot_z(90), shape="Cylinder"),
            part("Crown", (1.9, 1.9, 1.9), at(0, h, 0), c, "SmoothPlastic", shape="Ball", collide=False)]
    for k in range(arms):
        side = 1 if k == 0 else -1
        ay = h * rng.uniform(0.35, 0.55)
        up = h * rng.uniform(0.22, 0.34)
        kids.append(part(f"ArmOut{k}", (2.2, 1.35, 1.35), at(side * 1.4, ay, 0), c, "SmoothPlastic", r, shape="Cylinder",
                         collide=False))
        kids.append(part(f"ArmUp{k}", (up, 1.35, 1.35), at(side * 2.35, ay + up / 2, 0), c, "SmoothPlastic", rot_z(90),
                         shape="Cylinder", collide=False))
        kids.append(part(f"ArmTip{k}", (1.35, 1.35, 1.35), at(side * 2.35, ay + up, 0), c, "SmoothPlastic", shape="Ball",
                         collide=False))
    return model(name, kids)


def barrel_cactus(name, x, z, rng):
    y = floor_at(x, z, None)
    c = rng.choice(CACTUS)
    s = rng.uniform(1.6, 2.4)
    return model(name, [
        part("Body", (s, s * 0.9, s), (x, y + s * 0.35, z), c, "SmoothPlastic", shape="Ball", collide=False),
        part("Flower", (0.6, 0.45, 0.6), (x, y + s * 0.78, z), rng.choice(((240, 90, 110), (252, 204, 60))), "SmoothPlastic",
             shape="Ball", collide=False, query=False, shadow=False),
    ])


# Palm variety. Every palm draws its layout from the shared `rng` exactly as the old single design
# did (so nothing placed after it moves), and takes its character from its own stream seeded by its
# name: its kind, its trunk's curve and colours, its frond family, count, length and droop, its fruit.
PALM_KINDS = {  # curve: how much the trunk bows; droop: added to every frond's hang; reach: frond length
    "date": dict(curve=0.55, droop=8, reach=1.0, extra=(2, 3), segs=6, fruit="dates"),
    "coconut": dict(curve=1.7, droop=16, reach=1.2, extra=(0, 1), segs=5, fruit="coconuts"),
    "young": dict(curve=0.35, droop=-16, reach=0.75, extra=(2, 4), segs=4, fruit=None),
}
PALM_TRUNKS = [(hsv(38, 0.24, 1.0), hsv(34, 0.36, 0.98)), (hsv(32, 0.3, 1.0), hsv(26, 0.42, 0.97)),
               (hsv(44, 0.2, 1.0), hsv(40, 0.3, 0.99))]
PALM_RINGS = [hsv(28, 0.86, 0.96), hsv(36, 0.8, 1.0), hsv(14, 0.72, 0.98)]
PALM_FAMILIES = [  # (body, deep, highlight): lime, leaf green, yellow-green
    [hsv(104, 0.82, 0.96), hsv(112, 0.88, 0.84), hsv(96, 0.34, 1.0)],
    [hsv(134, 0.78, 0.86), hsv(140, 0.84, 0.74), hsv(128, 0.42, 0.98)],
    [hsv(84, 0.8, 0.96), hsv(90, 0.86, 0.86), hsv(76, 0.4, 1.0)],
]


def palm(name, x, z, rng, height=17.0, lean=(1.0, 0.0), y=None, kind=None):
    """A palm: a ringed trunk bowing away from `lean`'s opposite under a crown of arching fronds.
    `kind` (date / coconut / young, else picked from the name's own stream) sets its character: a
    tall straight date palm with a full drooping crown and dates, a bowed coconut palm with long
    hanging fronds and coconuts, or a short bushy young palm with its fronds held up. Nothing but the
    trunk's foot collides."""
    vr = random.Random(zlib.crc32(name.encode()))
    kind = kind or vr.choice(("date", "date", "coconut", "coconut", "young"))
    K = PALM_KINDS[kind]
    if kind == "young":
        height *= vr.uniform(0.38, 0.5)
    else:
        height *= vr.uniform(0.85, 1.2)
    trunk, trunk_alt = vr.choice(PALM_TRUNKS)
    ring = vr.choice(PALM_RINGS)
    fam = vr.choice(PALM_FAMILIES)
    reach = K["reach"] * vr.uniform(0.9, 1.15)
    fat = vr.uniform(0.9, 1.15) * (1.25 if kind == "young" else 1.0)
    y = floor_at(x, z, y) - 0.4
    lx, lz = lean
    n = math.hypot(lx, lz)
    lx, lz = lx / n, lz / n
    segs = K["segs"]
    seg = height / segs
    tilt0 = rng.uniform(12, 20)
    p = (x, y, z)
    kids = []
    for k in range(segs):
        f = k / (segs - 1)
        th = math.radians((tilt0 * (f + 0.2) + 20 * f * f) * K["curve"])
        q = (p[0] + math.sin(th) * lx * seg, p[1] + math.cos(th) * seg, p[2] + math.sin(th) * lz * seg)
        # every segment above the first runs a little way back down inside the thicker one below
        # it, so the joint holds however big the palm is grown (hidden under the ring)
        back = seg * 0.3 if k else 0.0
        u = tuple((q[i] - p[i]) / seg for i in range(3))
        mid = tuple((p[i] + q[i]) / 2 - u[i] * back / 2 for i in range(3))
        rad = (1.5 - f * 0.5) * fat
        kids.append(part(f"Trunk{k}", (seg + 0.35 + back, rad, rad), mid, trunk if k % 2 == 0 else trunk_alt, "SmoothPlastic",
                         mul(beam_rot(p, q), rot_z(90)), shape="Cylinder", collide=(k == 0)))
        if k < segs - 1:  # the knobbly ring where each year's growth meets the next
            kids.append(part(f"Ring{k}", (rad + 0.25, rad + 0.25, rad + 0.25), q, ring, "SmoothPlastic", shape="Ball",
                             collide=False, query=False))
        p = q
    kids.append(part("Heart", (1.6 * fat, 1.4 * fat, 1.6 * fat), (p[0], p[1] + 0.2, p[2]), ring, "SmoothPlastic", shape="Ball",
                     collide=False))
    # The crown: the shared draws lay out the main ring of fronds; the palm's own stream adds an
    # upper tier of shorter, steeper ones between them, so crowns differ in fullness too.
    fronds = rng.randint(7, 8)
    plan = []
    for k in range(fronds):
        plan.append((k / fronds * 360 + rng.uniform(-12, 12), rng.uniform(8, 22), rng.choice(PALM_LEAF),
                     rng.uniform(4.2, 5.2), rng.uniform(3.8, 4.8), 1.0))
    extra = vr.randint(*K["extra"])
    for k in range(extra):
        plan.append((vr.uniform(0, 360), vr.uniform(-6, 8), None, vr.uniform(3.4, 4.2), vr.uniform(3.0, 3.8), 0.8))
    for k, (a, droop, c, l1, l2, w) in enumerate(plan):
        droop += K["droop"] * w + vr.uniform(-5, 5)
        c = fam[k % 3] if vr.random() < 0.75 else fam[vr.randrange(3)]
        l1, l2 = l1 * reach, l2 * reach
        r1 = mul(rot_y(a), rot_x(droop - 30))
        d1 = apply(r1, (0, 0, 1))
        lift = 0.3 + 0.045 * k  # each frond's root a hair above the last, so no two share a face plane
        c1 = (p[0] + d1[0] * l1 / 2, p[1] + lift + d1[1] * l1 / 2, p[2] + d1[2] * l1 / 2)
        kids.append(part(f"Frond{k}a", (2.0 * w * vr.uniform(0.9, 1.15), 0.22, l1), c1, c, "SmoothPlastic", r1, collide=False,
                         query=False))
        e1 = (p[0] + d1[0] * l1, p[1] + lift + d1[1] * l1, p[2] + d1[2] * l1)
        r2 = mul(rot_y(a), rot_x(droop + 26))
        d2 = apply(r2, (0, 0, 1))
        # the tip tapers to a point: a wedge laid flat, its thin edge running out along the frond. Its
        # root is set back half a stud inside the frond's first leaf (on that leaf's own centre line,
        # not along the bent tip's), so the two stay joined whatever the droop and however big the
        # palm is grown.
        j = (e1[0] - d1[0] * 0.5, e1[1] - d1[1] * 0.5, e1[2] - d1[2] * 0.5)
        kids.append(part(f"Frond{k}b", (0.2, 1.5 * w, l2), (j[0] + d2[0] * l2 / 2, j[1] + d2[1] * l2 / 2, j[2] + d2[2] * l2 / 2),
                         c, "SmoothPlastic", mul(r2, ((0, 1, 0), (1, 0, 0), (0, 0, -1))), cls="WedgePart", collide=False,
                         query=False, shadow=False))
    fruit_at = [rng.uniform(0, math.tau) for _ in range(2)]
    if K["fruit"] == "dates":
        for k, a in enumerate(fruit_at + [a + 2.4 for a in fruit_at]):
            kids.append(part(f"Dates{k}", (0.8, 1.0, 0.8), (p[0] + math.cos(a) * 0.9, p[1] - 0.6, p[2] + math.sin(a) * 0.9),
                             (240, 150, 60), "SmoothPlastic", shape="Ball", collide=False, query=False, shadow=False))
    elif K["fruit"] == "coconuts":
        for k, a in enumerate(fruit_at + [fruit_at[0] + 1.3]):
            kids.append(part(f"Coconut{k}", (1.2, 1.2, 1.2), (p[0] + math.cos(a) * 0.95, p[1] - 0.55, p[2] + math.sin(a) * 0.95),
                             (236, 176, 96), "SmoothPlastic", shape="Ball", collide=False, query=False, shadow=False))
    return model(name, kids, attrs={"Species": kind.capitalize() + "Palm", "Sway": True})


def oasis_reeds(name, x, z, rng, n=7):
    """Reeds standing in the pool's shallows: rooted on its bed, tall enough to clear the water."""
    y = floor_at(x, z, None)
    kids = []
    for k in range(n):
        h = rng.uniform(4.4, 6.6)
        ox, oz = rng.uniform(-1.1, 1.1), rng.uniform(-1.1, 1.1)
        kids.append(part(f"Reed{k}", (0.22, h, 0.22), (x + ox, y + h / 2, z + oz), rng.choice((MOSS, (150, 236, 96), (176, 240, 110))),
                         "SmoothPlastic", mul(rot_y(rng.uniform(0, 90)), rot_z(rng.uniform(-7, 7))), collide=False, query=False,
                         shadow=False))
        if k % 3 == 0:
            kids.append(part(f"Head{k}", (0.42, 1.1, 0.42), (x + ox, y + h - 0.4, z + oz), (214, 128, 52), "SmoothPlastic",
                             collide=False, query=False, shadow=False))
    return model(name, kids)


def desert_stall(name, x, z, face, rng, canopy):
    """A market stall: timber posts, a striped canopy, a counter of lemons, oranges and dates."""
    y = floor_at(x, z, None)
    r, at = local_frame(x, y, z, yaw_facing(*face))
    kids = []
    for k, (sx, sz) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        h = 7.5 if sz < 0 else 8.25
        kids.append(part(f"Post{k}", (0.5, h, 0.5), at(sx * 3.6, h / 2, sz * 2.4), VIGA, "SmoothPlastic", r))
    for k in range(5):
        kids.append(part(f"Canopy{k}", (7.8 / 5, 0.18, 6.2), at(-3.9 + 7.8 * (k + 0.5) / 5, 8.0, 0),
                         canopy if k % 2 == 0 else AWNING_CREAM, "SmoothPlastic", mul(r, rot_x(-7)), collide=False, layer="roof"))
    kids.append(part("Counter", (7.0, 2.6, 1.6), at(0, 1.3, -1.6), TIMBER, "SmoothPlastic", r))
    for k, color in enumerate((LEMON, (255, 150, 40), (255, 84, 96))):
        bx = -2.3 + k * 2.3
        kids.append(part(f"Basket{k}", (1.9, 0.7, 1.3), at(bx, 2.95, -1.6), ADOBE_TRIM, "SmoothPlastic", r, collide=False))
        for j in range(3):
            kids.append(part(f"Fruit{k}{j}", (0.75, 0.7, 0.7), at(bx - 0.5 + j * 0.5, 3.45 + (j % 2) * 0.15, -1.6 + (j % 2) * 0.2),
                             color, "SmoothPlastic", r, shape="Ball", collide=False, query=False, shadow=False))
    return model(name, kids, attrs={"SandDrift": 1.3})


def lantern_post(name, x, z, yaw, rng):
    y = floor_at(x, z, None)
    r, at = local_frame(x, y, z, yaw)
    return model(name, [
        part("Pole", (0.5, 8.4, 0.5), at(0, 4.2, 0), VIGA, "SmoothPlastic", r),
        part("Arm", (0.35, 0.35, 2.2), at(0, 8.0, -0.9), VIGA, "SmoothPlastic", r, collide=False),
        part("Lantern", (0.9, 1.3, 0.9), at(0, 7.0, -1.7), (255, 208, 132), "Neon", r, collide=False, query=False,
             shadow=False, children=[light(18, 1.1, LANTERN)]),
    ])


def desert_dressing():
    """Everything that stands on the desert's sand. A private seed, so the shared `rng` is untouched."""
    lr = random.Random(0xDE5E7)
    out = []
    W, E, S_, N = (-1, 0), (1, 0), (0, 1), (0, -1)

    # Everything is built at the old prop sizes and grown to the player's scale (H, a character's
    # height, is about 5.5 studs): doors about 1.5H, one-storey houses about 3H to the parapet,
    # two-storey ones about 5H, tents 1.5H at the ridge, stall canopies 1.6H over waist-high counters,
    # palms 5-7H, saguaros 2-4H. Furniture a player uses (the table, chairs, bench, crates, pots)
    # grows only a little. Scaling adds no parts.
    S_HOUSE1, S_HOUSE2 = 1.55, 1.4  # one storey / two storeys (the same storey height either way)
    S_TENT, S_STALL, S_PALM, S_FIRE = 1.8, 1.1, 1.9, 1.3
    S_TABLE, S_BENCH, S_CRATE, S_POT, S_LANTERN = 1.1, 1.15, 1.3, 1.3, 1.35
    S_RUBBLE_HOUSE, S_RUBBLE_CAMP, S_REEDS = 1.45, 1.3, 1.25
    S_SAGUARO, S_SAGUARO_H, S_BARREL = 1.5, 1.27, 1.4  # saguaros: 1.9x taller, 1.5x thicker

    # The settlement: a street of houses along the basin's east side, rim to mid bench, and a quieter
    # pair on the rim's west side; two more by the Warden's pit. Each house backs onto the basin's
    # wall (x 110) with a stud or two of sand between: its centre is set from its grown depth.
    houses = [
        ("HouseRimNE", 100.0, 182, 12, 10, 8.5, W, None, None, AWNINGS[2]),
        ("HouseRimE", 100.0, 216, 14, 11, 10.0, W, (8, 7, 6.5), AWNINGS[0], None),
        ("HouseRimW", -99.5, 186, 14, 12, 10.0, E, (8, 7, 6.0), AWNINGS[1], AWNINGS[3]),
        ("HouseRimSW", -100.0, 219, 12, 10, 8.5, E, None, AWNINGS[3], None),
        ("HouseMidE", 99.5, 252, 16, 12, 10.5, W, (9, 7, 6.5), AWNINGS[0], AWNINGS[1]),
        ("HouseMidE2", 99.5, 283, 13, 11, 9.0, W, None, AWNINGS[2], None),
        ("HousePitE", 99.5, 423, 16, 12, 10.5, W, (8, 7, 6.5), AWNINGS[1], AWNINGS[2]),
        ("HousePitE2", 100.0, 453, 12, 10, 8.5, W, None, None, AWNINGS[0]),
    ]
    for k, (nm, x, z, w, d, h, face, upper, awning, shutters) in enumerate(houses):
        s = S_HOUSE2 if upper else S_HOUSE1
        out.append(grown(s, x, z, lambda: adobe_house(nm, x, z, w, d, h, face, lr, wall=ADOBE_WALLS[k % 4],
                                                       awning=awning, upper=upper, shutters=shutters)))
        # pots, crates and rubble at the foot of the front wall
        D, Wd = d * s, w * s
        fx = x + face[0] * (D / 2 + 2.2)
        pz = z + lr.uniform(-Wd / 2 + 2.0, -2.0)
        out.append(grown(S_POT, fx, pz, lambda: clay_pot(f"{nm}Pot", fx, pz, lr, lr.uniform(0.8, 1.1))))
        rx, rz = x + face[0] * (D / 2 + 3.6), z + lr.uniform(-3, 3)
        out.append(grown(S_RUBBLE_HOUSE, rx, rz, lambda: rubble(f"{nm}Rubble", rx, rz, lr, n=7, spread=4.5)))
    out.append(grown(S_CRATE, 95, 199, lambda: lemon_crate("LemonCrateRim", 95, 199, 70, lr)))  # the rim's alley
    out.append(grown(S_CRATE, 94, 268, lambda: lemon_crate("LemonCrateMid", 94, 268, 100, lr)))  # the mid alley
    out.append(grown(S_POT, 90.5, 298, lambda: clay_pot("PotMidA", 90.5, 298, lr, 1.2)))
    out.append(grown(S_POT, 88, 301, lambda: clay_pot("PotMidB", 88, 301, lr, 0.8)))

    # Market stalls: one on the rim by the trail down from the overlook, one on the mid bench.
    out.append(grown(S_STALL, 30, 180, lambda: desert_stall("StallRim", 30, 180, W, lr, AWNINGS[1])))
    out.append(grown(S_STALL, 70, 317, lambda: desert_stall("StallMid", 70, 317, W, lr, AWNINGS[0])))
    out.append(grown(S_RUBBLE_CAMP, 38, 186, lambda: rubble("StallRimRubble", 38, 186, lr, n=6, spread=4, shadow=True)))

    # The camp on the rim, west of the street: A-frame tents round a fire, a table and chairs, a log
    # bench, lanterns.
    fx, fz = 67, 207
    out.append(grown(S_FIRE, fx, fz, lambda: desert_fire("CampFire", fx, fz, lr)))
    # Two tents flank the camp's open west side, their ridges splayed out from the fire so their
    # A-frame ends face the path in; the third stands back by the street.
    for nm, x, z, yaw, cloth, stripe in (("CampTentE", 78, 222.5, 100, TENT_CLOTH[0], AWNINGS[0]),
                                         ("CampTentW", 54, 194, 110, TENT_CLOTH[2], AWNINGS[3]),
                                         ("CampTentS", 54, 221, 70, TENT_CLOTH[1], AWNINGS[1])):
        out.append(grown(S_TENT, x, z, lambda: a_tent(nm, x, z, yaw, cloth, stripe=stripe), drift=1.35))
    out.append(grown(S_TABLE, 78.5, 207.5, lambda: camp_table("CampTable", 78.5, 207.5, 14, lr)))
    out.append(grown(S_BENCH, 68, 198, lambda: log_bench("CampBench", 68, 198, -18)))
    out.append(grown(S_RUBBLE_CAMP, 46, 206, lambda: rubble("CampRubbleA", 46, 206, lr, n=9, spread=4.5, shadow=True)))
    out.append(grown(S_RUBBLE_CAMP, 66, 218, lambda: rubble("CampRubbleC", 66, 218, lr, n=7, spread=3.5)))
    out.append(grown(S_RUBBLE_CAMP, 87, 204.5, lambda: rubble("CampRubbleB", 87, 204.5, lr, n=6, spread=3.5, shadow=True)))
    out.append(grown(S_LANTERN, 89, 202, lambda: lantern_post("CampLantern", 89, 202, yaw_facing(-1, 0.2), lr)))
    out.append(grown(S_POT, 86, 200, lambda: clay_pot("CampPot", 86, 200, lr, 1.0)))
    out.append(grown(S_CRATE, 66, 226.5, lambda: lemon_crate("CampCrate", 66, 226.5, 20, lr)))

    # The oasis: palms round the pool and along the fence on the mid bench above it, reeds in the
    # shallows' edge, a fence along the drop.
    palms = [(70.5, 338, 18, (1, 0.3)), (68.5, 356, 16, (1, -0.2)), (84, 322, 19, (0.3, 1)), (102, 320, 15, (-0.4, 1)),
             (62, 342, 20, (1, 0.6)), (103, 302, 17, (-0.6, 0.8))]
    for k, (x, z, h, lean) in enumerate(palms):
        out.append(grown(S_PALM, x, z, lambda: palm(f"OasisPalm{k}", x, z, lr, height=h, lean=lean)))
    for k, (x, z) in enumerate(((78.5, 337), (78.5, 358), (85, 334.5), (104, 362), (79, 348), (92, 362.5))):
        out.append(grown(S_REEDS, x, z, lambda: oasis_reeds(f"OasisReeds{k}", x, z, lr, n=7)))
    # The town's spring pool on the mid bench, between the camp and the street (WorldTerrain's second
    # POOLS entry, x 62-84): palms round a raised spring, reeds in its shallows.
    for k, (x, z, h, lean, sp) in enumerate(((68, 257, 21, (0.6, -1), 1.5), (84, 262, 17, (-0.5, -1), S_PALM),
                                              (60, 301, 15, (1, 0.2), S_PALM), (85, 306, 16, (-0.6, 0.6), S_PALM))):
        out.append(grown(sp, x, z, lambda: palm(f"TownPalm{k}", x, z, lr, height=h, lean=lean)))
    for k, (x, z) in enumerate(((66, 272), (80, 297), (65.5, 294), (80, 271))):
        out.append(grown(S_REEDS, x, z, lambda: oasis_reeds(f"TownReeds{k}", x, z, lr, n=6)))
    out.append(fence_run("OasisFence", (78, 327.5), (108, 327.5), None, height=3.0))
    out.append(grown(S_RUBBLE_CAMP, 64, 334, lambda: rubble("OasisRubble", 64, 334, lr, n=6, spread=4)))
    out.append(quarry_fall("SpringFall", 111.5, 348.0, 14.5, WATER_TOP_Y, width=5.0))

    # (The loose cacti that stood about the sand are gathered into oasis_life's cactus gardens.)

    # A camp of the bandits' own in the pit's west, and the path into their hideout.
    out.append(grown(S_TENT, -92, 418, lambda: a_tent("BanditTentA", -92, 418, 30, TENT_CLOTH[1], stripe=AWNINGS[0]),
                     drift=1.35))
    out.append(grown(S_TENT, -88, 446, lambda: a_tent("BanditTentB", -88, 446, -20, TENT_CLOTH[0], stripe=AWNINGS[3]),
                     drift=1.35))
    out.append(grown(S_FIRE, -76, 432, lambda: desert_fire("BanditFire", -76, 432, lr)))
    out.append(grown(S_RUBBLE_CAMP, -78, 432, lambda: rubble("BanditRubble", -78, 432, lr, n=8, spread=5)))
    out.append(skull_sign("TurnBackSign", 38, 258, yaw_facing(0, -1), "TURN BACK", "Dune Bandits"))
    # (the loose heaps out on the open sand are terrain now: WorldTerrain's SAND_ROCKS)
    return out


# ── The oasis, alive ─────────────────────────────────────────────────────────
# A second pass of dressing (its own seed) that fills the basin's open sand: gardens and palm groves
# round the pools, flowering desert plants, a bazaar lane through the rim and the mid bench with a
# lemonade stand, the bandits' quarter in the pit's west, and small ground detail (pebbles, dune
# grass) everywhere between. Everything is placed through OasisPlacer, which keeps it off the
# trail, out of the lanes the audit keeps clear, clear of spawns, arrivals, waystones and the
# Warden's arena, and off anything already standing.
BLOOMS = [(255, 96, 150), (255, 212, 48), (255, 150, 40), (200, 120, 255), (255, 250, 236)]  # pink, lemon, orange, violet, cream
DESERT_GREENS = [hsv(104, 0.78, 0.96), hsv(128, 0.74, 0.9), hsv(96, 0.4, 1.0)]  # garden foliage: lime, leaf, pale lime
AGAVE_TONES = [hsv(150, 0.56, 0.9), hsv(142, 0.46, 0.98), hsv(160, 0.3, 1.0)]  # mint-green rosettes
PEBBLES = [(255, 214, 176), (255, 188, 140), (255, 236, 210), (250, 160, 120), (214, 196, 255)]  # warm candy stones, one lilac
LOOT_GOLD = (255, 204, 48)
DEBUG_OASIS = False
IL_TRAIL = [(0, 136), (0, 196), (20, 224), (20, 300), (-22, 310), (-22, 360), (0, 372), (0, 470)]  # WorldTerrain's TRAIL
IL_LANES = [(-12, 12, 104, 222), (-12, 32, 222, 231), (8, 32, 231, 262), (19, 32, 262, 296), (-30, 30, 309, 317),
            (-32, -12, 316, 352), (-32, -12, 352, 362), (-30, 10, 362, 366), (-12, 12, 366, 386)]  # audit_map.py LANES
IL_POOLS = [(76, 112, 330, 366), (60, 86, 264, 304)]


class OasisPlacer:
    """Where the oasis dressing may stand. Tracks what it has placed, so nothing lands on anything."""

    def __init__(self, mark):
        # what stands on the ground: a palm's crown or an awning overhead does not stop a flower bed
        # or a fern going under it, so only parts reaching down to within 3 studs of the floor count
        self.taken = []
        for e in REGISTRY[mark:]:
            if e["layer"] in ("ground", "proxy") or not (abs(e["pos"][0]) < 130 and 90 < e["pos"][2] < 480):
                continue
            ext = [sum(abs(e["rot"][i][j]) * e["size"][j] / 2 for j in range(3)) for i in range(3)]
            fy = floor_at(e["pos"][0], e["pos"][2], None)
            if fy is not None and e["pos"][1] - ext[1] > fy + 3:
                continue
            self.taken.append((e["pos"][0], e["pos"][2], max(ext[0], ext[2])))
        self.spawns = [(x, z) for _, _, _, _, (x, z), _ in ENEMY_SPAWNS]
        self.points = [(18, 152), (0, 358), (31, 145), (12, 352), (0, 470), (0, 100)]  # arrivals, waystones, gates
        # the validator's camera-clearance points: spawns (12 studs round) and arrivals (8)
        self.guard = [(sx, sz, floor_at(sx, sz, 0.0), 12) for sx, sz in self.spawns] + \
                     [(18, 152, floor_at(18, 152, 0.0), 8), (0, 358, floor_at(0, 358, 0.0), 8)]

    def ok(self, x, z, r, tall=False, water=False, gap=1.5):
        return self.why(x, z, r, tall, water, gap) is None

    def why(self, x, z, r, tall=False, water=False, gap=1.5):
        """None when (x, z) may take a prop of radius r, else the reason it may not."""
        if not (-107 <= x <= 107 and 170 <= z <= 468) and not (-40 <= x <= 40 and 142 <= z <= 170):
            return "outside"
        y = floor_at(x, z, None)
        if y is None:
            return "no floor"
        for k in range(8):  # one floor level under the whole footprint (not over a bench's step)
            fy = floor_at(x + math.cos(k * math.pi / 4) * (r + 1), z + math.sin(k * math.pi / 4) * (r + 1), None)
            if fy is None or abs(fy - y) > 0.3:
                return "step"
        if min(seg_dist(x, z, IL_TRAIL[i], IL_TRAIL[i + 1]) for i in range(len(IL_TRAIL) - 1)) < r + 5:
            return "trail"
        for x0, x1, z0, z1 in IL_LANES:
            if x0 - r - 1 < x < x1 + r + 1 and z0 - r - 1 < z < z1 + r + 1:
                return "lane"
        # a palm's crown spreads 15 studs or more: keep it out of the camera's headroom over a spawn
        if any(math.hypot(x - sx, z - sz) < r + (26 if tall else 9) for sx, sz in self.spawns):
            return "spawn"
        if any(math.hypot(x - px, z - pz) < r + 9 for px, pz in self.points):
            return "marker"
        if math.hypot(x, z - 424) < 42 + r or 362 < z < 388:  # the Warden's arena; the ridge across the pit
            return "arena/ridge"
        in_pool = any(x0 < x < x1 and z0 < z < z1 for x0, x1, z0, z1 in IL_POOLS)
        if in_pool != water:
            return "pool"
        for tx, tz, tr in self.taken:
            if math.hypot(x - tx, z - tz) < r + tr + gap:
                return f"taken@{tx:.0f},{tz:.0f}"
        return None

    def take(self, x, z, r):
        self.taken.append((x, z, r))


def desert_bed(name, x, z, w, d, yaw, lr, round_=False, colors=None):
    """A raised adobe planter of desert flowers: cream coping, a lime mound, blooms in one or two
    colours (a bed of everything reads as confetti). Round or oblong. Tagged FlowerBed, so the
    butterflies visit it."""
    y = floor_at(x, z, None)
    r, at = local_frame(x, y, z, yaw)
    colors = colors or lr.sample(BLOOMS[:4], 2)
    wall = lr.choice((ADOBE_WALLS[0], ADOBE_WALLS[1], ADOBE_TRIM))
    if round_:
        d = w
        kids = [drum("Box", x, y - 0.2, y + 1.1, z, w / 2, w / 2, wall, layer="prop"),
                drum("Coping", x, y + 1.1, y + 1.45, z, w / 2 + 0.25, w / 2 + 0.25, ADOBE_TRIM, layer="prop")]
    else:
        kids = [part("Box", (w, 1.3, d), at(0, 0.45, 0), wall, "SmoothPlastic", r, collide=False),
                part("Coping", (w + 0.5, 0.35, d + 0.5), at(0, 1.2, 0), ADOBE_TRIM, "SmoothPlastic", r, collide=False, query=False)]
    for k in range(2):
        sc = 0.9 if k == 0 else 0.6
        kids.append(ellipsoid(f"Mound{k}", (w * sc, 1.6 + k * 0.5, d * sc), at((k - 0.5) * w * 0.15, 1.4 + k * 0.2, 0),
                              DESERT_GREENS[k], rot=tilt(lr, 2, 5), shadow=False, layer="prop"))
    n = max(4, int(w * d / 2.2))
    for k in range(n):
        # on the big mound's surface: sat into it, so every bloom is held
        a, q = lr.uniform(0, math.tau), math.sqrt(lr.random()) * 0.8
        lx, lz = math.cos(a) * q * 0.45 * w, math.sin(a) * q * 0.45 * d
        sz = lr.uniform(0.7, 1.05)
        kids.append(part(f"Bloom{k}", (sz, sz * 0.8, sz), at(lx - 0.075 * w, 1.4 + 0.8 * math.sqrt(1 - q * q), lz),
                         colors[0] if k % 3 else colors[-1], "SmoothPlastic", shape="Ball", collide=False, query=False, shadow=False))
    return model(name, kids, attrs={"FlowerBed": True, "BedX": x, "BedY": y + 3.0, "BedZ": z, "SandDrift": 0.8})


def prickly_pear(name, x, z, lr):
    """A prickly pear: flat oval paddles growing out of one another, pink fruit on the top ones."""
    y = floor_at(x, z, None)
    c = lr.choice(CACTUS)
    kids = []
    frontier = [(x, y - 0.3, z, lr.uniform(0, 180), 0)]
    k = 0
    while frontier and k < lr.randint(5, 7):
        px, py, pz, yaw, depth = frontier.pop(0)
        s = 2.6 - 0.35 * depth
        lean = lr.uniform(-28, 28)
        rot = mul(rot_y(yaw), rot_z(lean))
        up = apply(rot, (0, 1, 0))
        cx, cy, cz = px + up[0] * s * 0.45, py + up[1] * s * 0.45, pz + up[2] * s * 0.45
        kids.append(ellipsoid(f"Pad{k}", (s * 0.85, s, 0.5), (cx, cy, cz), c if k % 2 else lr.choice(CACTUS), rot=rot, layer="prop"))
        tip = (cx + up[0] * s * 0.42, cy + up[1] * s * 0.42, cz + up[2] * s * 0.42)
        if depth < 2:
            for _ in range(2):
                frontier.append((tip[0], tip[1], tip[2], yaw + lr.uniform(-40, 40), depth + 1))
        elif lr.random() < 0.8:
            kids.append(part(f"Fruit{k}", (0.6, 0.75, 0.6), (tip[0], tip[1] + 0.2, tip[2]), (255, 70, 140), "SmoothPlastic",
                             shape="Ball", collide=False, query=False, shadow=False))
        k += 1
    return model(name, kids)


def agave(name, x, z, lr, s=1.0):
    """An agave: a rosette of stiff pointed leaves splaying out of the sand, a pale tip on each."""
    y = floor_at(x, z, None)
    kids = []
    n = lr.randint(7, 9)
    for k in range(n):
        a = k / n * 360 + lr.uniform(-10, 10)
        lean = lr.uniform(28, 58)
        L = lr.uniform(2.6, 3.6) * s
        rot = mul(rot_y(a), rot_x(lean))
        d = apply(rot, (0, 1, 0))
        kids.append(ellipsoid(f"Leaf{k}", (0.9 * s, L, 0.35 * s), (x + d[0] * L * 0.45, y + d[1] * L * 0.45 - 0.2, z + d[2] * L * 0.45),
                              AGAVE_TONES[k % 2], rot=rot, shadow=False, layer="prop"))
    kids.append(ellipsoid("Heart", (1.2 * s, 1.6 * s, 1.2 * s), (x, y + 0.5 * s, z), AGAVE_TONES[2], rot=tilt(lr, 2, 5), layer="prop"))
    return model(name, kids)


def dune_grass(name, x, z, lr):
    """A tuft of dune grass: a few thin blades fanning out of the sand."""
    y = floor_at(x, z, None)
    kids = []
    for k in range(lr.randint(4, 6)):
        h = lr.uniform(1.6, 2.8)
        rot = mul(rot_y(lr.uniform(0, 180)), rot_z(lr.uniform(-24, 24)))
        up = apply(rot, (0, 1, 0))
        kids.append(part(f"Blade{k}", (0.18, h, 0.45), (x + up[0] * h / 2, y + up[1] * h / 2 - 0.1, z + up[2] * h / 2),
                         lr.choice(DESERT_GREENS), "SmoothPlastic", rot, collide=False, query=False, shadow=False))
    return model(name, kids)


def pebbles(name, x, z, lr):
    """A few candy-coloured stones half sunk in the sand."""
    y = floor_at(x, z, None)
    kids = []
    for k in range(lr.randint(3, 5)):
        s = lr.uniform(0.7, 1.8)
        a, d = lr.uniform(0, math.tau), lr.uniform(0, 1.8)
        kids.append(ellipsoid(f"Stone{k}", (s * 1.3, s * 0.8, s), (x + math.cos(a) * d, y + s * 0.15, z + math.sin(a) * d),
                              lr.choice(PEBBLES), rot=tilt(lr, 4, 14), shadow=False, layer="prop"))
    return model(name, kids)


def blooming(node, lr):
    """Crown a built saguaro's tops (its Crown and arm tips) with candy flowers."""
    for c in list(node["children"]):
        if c["name"] == "Crown" or c["name"].startswith("ArmTip"):
            px, py, pz = c["properties"]["CFrame"]["CFrame"]["position"]
            d = c["properties"]["Size"][0]
            col = lr.choice(BLOOMS[:3])
            node["children"].append(part(f"{c['name']}Bloom", (d * 0.55, d * 0.4, d * 0.55), (px, py + d * 0.45, pz), col,
                                         "SmoothPlastic", shape="Ball", collide=False, query=False, shadow=False))
    return node


def shade_sail(name, x, z, yaw, lr, w=8.0, d=7.0):
    """A striped shade sail on four poles, tipped to shed the sun, over a bench's worth of shade."""
    y = floor_at(x, z, None)
    r, at = local_frame(x, y, z, yaw)
    kids = []
    for k, (sx, sz) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        h = 7.2 if sz < 0 else 8.4
        kids.append(part(f"Pole{k}", (0.45, h, 0.45), at(sx * (w / 2 - 0.3), h / 2, sz * (d / 2 - 0.3)), VIGA, "SmoothPlastic", r))
    cloth = lr.choice(AWNINGS)
    for k in range(4):
        kids.append(part(f"Sail{k}", (w / 4, 0.16, d + 0.4), at(-w / 2 + w * (k + 0.5) / 4, 7.95, 0),
                         cloth if k % 2 == 0 else AWNING_CREAM, "SmoothPlastic", mul(r, rot_x(-9)), collide=False, query=False,
                         layer="roof"))
    return model(name, kids, attrs={"SandDrift": 0.8})


def lemonade_stand(name, x, z, face, lr):
    """Lemonade's own stall: a lemon-yellow counter under a lemon-and-cream awning, a jug and cups, a
    big lemon on a pole and a sign."""
    y = floor_at(x, z, None)
    yaw = yaw_facing(*face)
    r, at = local_frame(x, y, z, yaw)
    kids = []
    for k, (sx, sz) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        kids.append(part(f"Post{k}", (0.5, 8.0, 0.5), at(sx * 3.4, 4.0, sz * 2.0), AWNING_CREAM, "SmoothPlastic", r))
    for k in range(6):
        kids.append(part(f"Awning{k}", (6.8 / 6, 0.18, 5.2), at(-3.4 + 6.8 * (k + 0.5) / 6, 8.1, 0),
                         LEMON if k % 2 == 0 else AWNING_CREAM, "SmoothPlastic", mul(r, rot_x(-8)), collide=False, layer="roof"))
    kids.append(part("Counter", (6.4, 2.8, 1.6), at(0, 1.4, -1.4), LEMON, "SmoothPlastic", r))
    kids.append(part("CounterTop", (6.8, 0.3, 2.0), at(0, 2.95, -1.4), AWNING_CREAM, "SmoothPlastic", r, collide=False))
    kids.append(part("Jug", (1.6, 1.0, 1.0), at(-1.6, 3.9, -1.4), (255, 236, 110), "Glass", rot_z(90), shape="Cylinder", collide=False,
                     transparency=0.25))
    for k in range(3):
        kids.append(part(f"Cup{k}", (0.8, 0.55, 0.55), at(0.4 + k * 0.9, 3.5, -1.5), (255, 250, 236), "SmoothPlastic", rot_z(90),
                         shape="Cylinder", collide=False, query=False, shadow=False))
    lx, ly, lz = at(4.4, 0, -2.6)
    kids.append(part("LemonPole", (0.35, 10.0, 0.35), (lx, ly + 5.0, lz), AWNING_CREAM, "SmoothPlastic", r, collide=False))
    kids.append(ellipsoid("BigLemon", (2.6, 2.0, 2.0), (lx, ly + 10.6, lz), LEMON, rot=mul(r, rot_z(12)), collide=False, layer="prop"))
    kids.append(part("LemonLeaf", (1.2, 0.2, 0.8), (lx - 0.4, ly + 11.7, lz), GRASS, "SmoothPlastic", mul(r, rot_z(-25)), collide=False,
                     query=False, shadow=False))
    kids.append(part("SignBoard", (5.0, 1.3, 0.3), at(0, 1.6, -2.3), AWNING_CREAM, "SmoothPlastic", r, collide=False,
                     children=[label_gui("Front", "LEMONADE", "", (240, 150, 20)), label_gui("Back", "LEMONADE", "", (240, 150, 20))]))
    return model(name, kids, attrs={"SandDrift": 1.0})


def pennant_line(name, a, b, height, lr, pennants=10):
    """Two poles with a taut cord between them and triangular pennants hanging from it (hung right
    off the cord, no sag, so every pennant is tied on)."""
    ax, az = a
    bx, bz = b
    y = min(floor_at(ax, az, None), floor_at(bx, bz, None))
    seg = math.hypot(bx - ax, bz - az)
    dx, dz = (bx - ax) / seg, (bz - az) / seg
    yaw = math.degrees(math.atan2(-dz, dx))
    kids = []
    for k, (px_, pz) in enumerate((a, b)):
        fy = floor_at(px_, pz, None)
        kids.append(part(f"Pole{k}", (0.5, y + height + 0.6 - fy, 0.5), (px_, (fy + y + height + 0.6) / 2, pz), VIGA, "SmoothPlastic"))
    kids.append(part("Cord", (seg, 0.14, 0.14), ((ax + bx) / 2, y + height, (az + bz) / 2), VIGA, "SmoothPlastic",
                     rot_y(yaw), collide=False, query=False))
    for k in range(pennants):
        t = (k + 0.5) / pennants
        kids.append(part(f"Pennant{k}", (1.4, 1.6, 0.08), (ax + dx * seg * t, y + height - 0.82, az + dz * seg * t),
                         (AWNINGS + [AWNING_CREAM])[k % 5], "SmoothPlastic", mul(rot_y(yaw), rot_x(180)), cls="WedgePart",
                         collide=False, query=False, shadow=False, layer="roof"))
    return model(name, kids, attrs={"Bunting": True})


def palisade(name, a, b, lr):
    """The bandits' stake fence: sharpened timber stakes, a little uneven, on a sand bank."""
    ax, az = a
    bx, bz = b
    seg = math.hypot(bx - ax, bz - az)
    n = max(2, int(seg / 1.3))
    kids = []
    for k in range(n):
        t = k / (n - 1)
        x, z = ax + (bx - ax) * t, az + (bz - az) * t
        y = floor_at(x, z, None)
        h = lr.uniform(5.2, 6.6)
        rot = mul(rot_y(lr.uniform(0, 90)), rot_z(lr.uniform(-4, 4)))
        kids.append(part(f"Stake{k}", (1.1, h, 1.1), (x, y + h / 2 - 0.4, z), TIMBER if k % 3 else VIGA, "SmoothPlastic", rot, collide=False))
        kids.append(part(f"Point{k}", (0.8, 0.8, 0.8), (x, y + h - 0.3, z), AWNING_CREAM, "SmoothPlastic",
                         mul(rot, mul(rot_x(45), rot_z(45))), collide=False, query=False, shadow=False))
    y = floor_at((ax + bx) / 2, (az + bz) / 2, None)
    kids.append(part("Rail", (seg, 0.5, 0.5), ((ax + bx) / 2, y + 3.4, (az + bz) / 2), VIGA, "SmoothPlastic",
                     rot_y(math.degrees(math.atan2(-(bz - az), bx - ax))), collide=False, query=False))
    return model(name, kids, attrs={"SandDrift": 1.2})


def lookout(name, x, z, lr):
    """A timber lookout tower: four legs, cross braces, a railed platform under a striped roof, a flag."""
    y = floor_at(x, z, None)
    H = 14.0
    kids = []
    for k, (sx, sz) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        kids.append(part(f"Leg{k}", (0.8, H + 0.6, 0.8), (x + sx * 2.6, y + (H + 0.6) / 2 - 0.3, z + sz * 2.6), VIGA, "SmoothPlastic"))
    for k, (dx, dz, yaw) in enumerate(((0, -2.6, 0), (0, 2.6, 0), (-2.6, 0, 90), (2.6, 0, 90))):
        kids.append(part(f"Brace{k}", (0.35, 7.6, 0.35), (x + dx, y + 5.0, z + dz), TIMBER, "SmoothPlastic",
                         mul(rot_y(yaw), rot_z(38)), collide=False, query=False))
    kids.append(part("Deck", (6.6, 0.6, 6.6), (x, y + H - 0.2, z), TIMBER, "SmoothPlastic"))
    for k, (dx, dz, sx, sz) in enumerate(((0, -3.1, 6.6, 0.3), (0, 3.1, 6.6, 0.3), (-3.1, 0, 0.3, 6.0), (3.1, 0, 0.3, 6.0))):
        kids.append(part(f"Rail{k}", (sx, 1.4, sz), (x + dx, y + H + 0.8, z + dz), AWNING_CREAM, "SmoothPlastic", collide=False))
    cloth = TENT_CLOTH[lr.randrange(3)]
    for k in range(2):
        kids.append(part(f"Roof{k}", (7.4, 0.25, 3.8), (x, y + H + 4.2, z + (k - 0.5) * 3.4), cloth if k == 0 else AWNING_CREAM,
                         "SmoothPlastic", rot_x(18 if k == 0 else -18), collide=False, layer="roof"))
    for k, (sx, sz) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        kids.append(part(f"RoofPost{k}", (0.35, 3.6, 0.35), (x + sx * 2.9, y + H + 1.9, z + sz * 2.9), VIGA, "SmoothPlastic", collide=False,
                         query=False))
    kids.append(part("FlagPole", (0.3, 4.2, 0.3), (x + 2.9, y + H + 6.0, z + 2.9), VIGA, "SmoothPlastic", collide=False, query=False))
    kids.append(part("Flag", (2.6, 1.6, 0.12), (x + 4.2, y + H + 7.2, z + 2.9), AWNINGS[0], "SmoothPlastic", collide=False, query=False,
                     shadow=False))
    return model(name, kids, attrs={"SandDrift": 1.4})


def loot_pile(name, x, z, lr):
    """The bandits' haul: a chest spilling gold coins, a couple of gem balls in the heap."""
    y = floor_at(x, z, None)
    yaw = lr.uniform(0, 180)
    r, at = local_frame(x, y, z, yaw)
    kids = [part("Chest", (3.0, 1.8, 2.0), at(0, 0.8, 0), TIMBER, "SmoothPlastic", r, collide=False),
            part("Lid", (3.1, 0.5, 2.1), at(0, 2.2, 0.8), VIGA, "SmoothPlastic", mul(r, rot_x(-60)), collide=False, query=False),
            part("Band", (3.15, 1.4, 0.3), at(0, 0.8, 0), LOOT_GOLD, "SmoothPlastic", r, collide=False, query=False)]
    kids.append(ellipsoid("Heap", (4.2, 1.6, 3.4), at(0, 0.2, -1.8), LOOT_GOLD, rot=mul(r, rot_x(4)), layer="prop"))
    for k in range(6):
        a, d = lr.uniform(0, math.tau), lr.uniform(1.0, 3.2)
        kids.append(part(f"Coin{k}", (0.18, 1.0, 1.0), (x + math.cos(a) * d, y + 0.2, z + math.sin(a) * d - 1.0), LOOT_GOLD, "SmoothPlastic",
                         mul(rot_y(lr.uniform(0, 180)), rot_z(90 + lr.uniform(-10, 10))), shape="Cylinder", collide=False, query=False,
                         shadow=False))
    for k, col in enumerate(((255, 72, 140), (60, 200, 255))):
        kids.append(part(f"Gem{k}", (0.9, 0.9, 0.9), at(-0.8 + 1.6 * k, 1.0, -1.8), col, "SmoothPlastic", shape="Ball", collide=False,
                         query=False, shadow=False))
    return model(name, kids, attrs={"SandDrift": 0.8})


def adobe_ruin(name, x, z, yaw, length, lr):
    """A broken run of adobe wall: blocks of uneven height, the top ragged, a few bricks fallen."""
    y = floor_at(x, z, None)
    r, at = local_frame(x, y, z, yaw)
    wall = ADOBE_WALLS[lr.randrange(4)]
    n = max(3, int(length / 2.6))
    kids = []
    for k in range(n):
        h = max(1.4, 6.5 * math.sin(math.pi * (k + 0.5) / n) * lr.uniform(0.55, 1.1))
        kids.append(part(f"Block{k}", (length / n + 0.05, h, 1.6), at(-length / 2 + length * (k + 0.5) / n, h / 2 - 0.3, 0), wall,
                         "SmoothPlastic", r))
    kids.append(part("Plinth", (length + 0.4, 0.9, 2.0), at(0, 0.15, 0), ADOBE_PLINTH, "SmoothPlastic", r, collide=False))
    return model(name, kids, attrs={"SandDrift": 1.6})


def bandit_banner(name, x, z, color, lr):
    y = floor_at(x, z, None)
    return model(name, [
        part("Pole", (0.4, 11.0, 0.4), (x, y + 5.3, z), VIGA, "SmoothPlastic", collide=False),
        part("Finial", (0.8, 0.8, 0.8), (x, y + 11.0, z), LOOT_GOLD, "SmoothPlastic", shape="Ball", collide=False, query=False),
        part("Banner", (0.12, 4.2, 2.2), (x, y + 8.0, z + 1.25), color, "SmoothPlastic", collide=False, query=False, shadow=False),
    ], attrs={"Sway": True})


def cactus_garden(name, x, z, lr):
    """A composed cactus garden: a tall flowering saguaro at the back, a shorter one beside it, prickly
    pears and agaves in front, a barrel cactus and two rounded rocks, on a low sand mound, all in a
    crescent opening one way, so it reads as one planted place rather than loose plants."""
    y = floor_at(x, z, None)
    face = lr.uniform(0, math.tau)
    fx, fz = math.cos(face), math.sin(face)  # the side it opens toward
    sx, sz = -fz, fx

    def at(u, v):  # u along the opening direction (negative = the back), v across it
        return x + fx * u + sx * v, z + fz * u + sz * v

    kids = [ellipsoid("Mound", (15, 1.6, 12), (x, y + 0.1, z), SAND_MOUND, rot=mul(rot_y(math.degrees(-face)), rot_x(1.5)),
                      layer="prop")]
    for k, (u, v, h, arms) in enumerate(((-3.5, -1.0, lr.uniform(12, 14), 2), (-2.0, 3.8, lr.uniform(7, 9), 1))):
        px, pz = at(u, v)
        start = len(REGISTRY)
        node = scaled(blooming(saguaro(f"Saguaro{k}", px, pz, h, lr, arms=arms), lr), 1.35, (px, y, pz), start)
        kids.append(node)
    for k, (u, v) in enumerate(((1.2, -3.8), (2.6, 2.4))):
        px, pz = at(u, v)
        kids.append(prickly_pear(f"Pear{k}", px, pz, lr))
    for k, (u, v, sc) in enumerate(((3.6, -0.6, 1.2), (-0.4, -5.6, 0.9))):
        px, pz = at(u, v)
        kids.append(agave(f"Agave{k}", px, pz, lr, s=sc))
    px, pz = at(1.0, 5.4)
    kids.append(barrel_cactus("Barrel", px, pz, lr))
    for k, (u, v, w) in enumerate(((-1.0, 6.4, 3.2), (-4.6, -5.0, 2.4))):
        px, pz = at(u, v)
        kids.append(ellipsoid(f"Rock{k}", (w * 1.3, w, w * 1.1), (px, y + w * 0.3, pz), MESA_BODY if k else MESA_BAND,
                              rot=tilt(lr, 4, 12), layer="rock"))
    return model(name, kids, attrs={"SandDrift": 1.0})


def rock_outcrop(name, x, z, lr, size=1.0):
    """A landmark heap of big rounded rocks in the mesas' coral, one standing tall, the others
    leaning on it, peach caps on the top ones."""
    y = floor_at(x, z, None)
    kids = []
    big = (lr.uniform(8, 10) * size, lr.uniform(9, 12) * size, lr.uniform(7, 9) * size)
    kids.append(ellipsoid("Tall", big, (x, y + big[1] * 0.38, z), MESA_BODY, rot=tilt(lr, 3, 8), layer="rock"))
    kids.append(ellipsoid("TallCap", (big[0] * 0.6, big[1] * 0.3, big[2] * 0.6), (x, y + big[1] * 0.8, z), MESA_BAND,
                          rot=tilt(lr, 3, 8), layer="rock", shadow=False))
    a0 = lr.uniform(0, math.tau)
    for k in range(lr.randint(2, 3)):
        a = a0 + k * lr.uniform(1.8, 2.4)
        w = lr.uniform(0.45, 0.65)
        d = big[0] * 0.55
        dims = (big[0] * w * 1.2, big[1] * w * 0.8, big[2] * w)
        kids.append(ellipsoid(f"Side{k}", dims, (x + math.cos(a) * d, y + dims[1] * 0.3, z + math.sin(a) * d),
                              MESA_DOME if k % 2 else MESA_BODY, rot=tilt(lr, 6, 16), layer="rock"))
    return model(name, kids, attrs={"SandDrift": 1.6})


def oasis_life(mark):
    """The basin's dressing, composed: a handful of themed places, each dense and planted with some
    care, at the edges of the play space and round the water, and open sand between them where the
    fighting is. A private seed; every place still goes through OasisPlacer (off the trail and lanes,
    clear of spawns, arrivals, the arena and the ridge, off anything standing, and tall pieces kept
    out of the camera's headroom over spawns)."""
    lr = random.Random(0xDE5E8)
    P = OasisPlacer(mark)
    out = []
    counts = {}

    def put(kind, x, z, r, build, tall=False, water=False, force=False, s=1.0, gap=1.0, near=0.0):
        spots = [(x, z)]
        if near:
            spots += [(x + math.cos(a) * d, z + math.sin(a) * d) for d in (1.5, 3, 4.5, 6, 8)[:int(near / 1.5)]
                      for a in [k * math.tau / 8 for k in range(8)]]
        for sx, sz in spots:
            if force or P.ok(sx, sz, r, tall=tall, water=water, gap=gap):
                break
        else:
            if DEBUG_OASIS:
                print("  skip", kind, (round(x), round(z)), P.why(x, z, r, tall, water, gap))
            return None
        n = counts.get(kind, 0)
        counts[kind] = n + 1
        start = len(REGISTRY)
        node = build(f"{kind}{n}", sx, sz)
        if s != 1.0:
            node = scaled(node, s, (sx, floor_at(sx, sz, 0.0), sz), start)
        if tall and not clearance_ok(start, P.guard):  # a crown over a spawn's camera: not here after all
            del REGISTRY[start:]
            counts[kind] = n
            if DEBUG_OASIS:
                print("  skip", kind, (round(x), round(z)), "camera clearance")
            return None
        out.append(node)
        P.take(sx, sz, r)
        return sx, sz

    def palms(group):
        """A natural group: (x, z, kind, height, lean). Tagged Sway."""
        for x, z, kind, h, lean in group:
            s = lr.uniform(1.6, 1.95)
            if put("Palm", x, z, 2.2, lambda nm, x, z: palm(nm, x, z, lr, height=h, lean=lean, kind=kind), tall=True, s=s, near=4):
                out[-1].setdefault("attributes", {})["Sway"] = True

    def bed(x, z, w, d, yaw, colors, round_=False, near=4):
        put("FlowerBed", x, z, max(w, d) / 2 + 0.4,
            lambda nm, x, z: desert_bed(nm, x, z, w, d, yaw, lr, round_=round_, colors=colors), near=near)

    def edge_detail(cx, cz, radius, n):
        """A few tufts of dune grass and pebbles round a place's edge, tying it into the sand."""
        for k in range(n):
            a = lr.uniform(0, math.tau)
            d = radius * lr.uniform(0.85, 1.25)
            x, z = cx + math.cos(a) * d, cz + math.sin(a) * d
            if k % 3 == 2:
                put("Pebbles", x, z, 1.8, lambda nm, x, z: pebbles(nm, x, z, lr), gap=0.6)
            else:
                put("DuneGrass", x, z, 1.4, lambda nm, x, z: dune_grass(nm, x, z, lr), gap=0.6)

    PINK, LEMON_, ORANGE, VIOLET = BLOOMS[:4]

    # 1. Lemonade Corner, on the rim just below the overlook: the first thing the eye lands on.
    put("LemonadeStand", -50, 178, 5.5, lambda nm, x, z: lemonade_stand(nm, x, z, (0, -1), lr), near=6)
    at = put("ShadeSail", -68, 186, 5.0, lambda nm, x, z: shade_sail(nm, x, z, 10, lr), near=6)
    if at:
        put("Bench", at[0], at[1] + 1.4, 2.8, lambda nm, x, z: bench(nm, x, floor_at(x, z, None), z, 190), force=True)
    palms([(-34, 175, "coconut", 18, (-1, 0.3)), (-62, 173, "young", 18, (1, 0)), (-80, 176, "date", 20, (0.3, 1))])
    bed(-57, 197, 5.5, 5.5, 0, [PINK, LEMON_], round_=True)
    put("LemonCrate", -42, 186, 2.0, lambda nm, x, z: lemon_crate(nm, x, z, 15, lr), near=4)
    put("Barrel", -60, 185, 1.3, lambda nm, x, z: barrel(nm, x, floor_at(x, z, None), z, lr), near=4)
    edge_detail(-54, 186, 16, 5)
    put("EntranceBunting", 0, 173, 1.0, lambda nm, x, z: pennant_line(nm, (-15, 173), (15, 173), 9.5, lr, pennants=12), force=True)

    # 2. The west rim's house gardens: a palm and a long bed before the two houses.
    palms([(-84, 199, "date", 21, (1, 0.2)), (-85, 228, "young", 18, (1, -0.4))])
    bed(-84, 206, 7.5, 3.0, 90, [ORANGE, LEMON_])

    # 3. The date grove on the mid bench's west: palms of every age with undergrowth and a bed.
    palms([(-98, 244, "date", 22, (0.6, 1)), (-90, 257, "coconut", 18, (1, 0.4)), (-78, 242, "young", 18, (-0.4, 1)),
           (-104, 238, "young", 18, (1, 0)), (-74, 255, "date", 19, (1, -0.5))])
    for x, z in ((-92, 249), (-82, 251)):
        put("Fern", x, z, 2.8, lambda nm, x, z: fern_clump(nm, x, z, lr, s=1.2, y=floor_at(x, z, None)), near=3)
    for x, z in ((-70, 246), (-104, 250)):
        put("LemonBush", x, z, 2.6, lambda nm, x, z: bush_clump(nm, x, z, lr, s=0.9, lemon=True, y=floor_at(x, z, None)), near=3)
    bed(-86, 239, 5.0, 5.0, 0, [ORANGE, LEMON_], round_=True)
    edge_detail(-88, 250, 18, 6)

    # 4. The town spring: flowers at its corners (its palms and reeds are desert_dressing's).
    bed(64, 262, 4.6, 4.6, 0, [VIOLET, PINK], round_=True)
    bed(62, 304, 6.0, 2.8, 20, [VIOLET, PINK])
    put("Fern", 88, 296, 2.8, lambda nm, x, z: fern_clump(nm, x, z, lr, s=1.1, y=floor_at(x, z, None)), near=3)

    # 5. The oasis's west shore: the lushest ground in the basin, beds and ferns under its palms.
    bed(58, 338, 7.0, 3.0, 90, [PINK, LEMON_])
    bed(60, 355, 5.2, 5.2, 0, [LEMON_, ORANGE], round_=True)
    for x, z in ((70, 347), (64, 336)):
        put("Fern", x, z, 2.8, lambda nm, x, z: fern_clump(nm, x, z, lr, s=1.25, y=floor_at(x, z, None)), near=3)
    put("LemonBush", 64, 360, 2.6, lambda nm, x, z: bush_clump(nm, x, z, lr, s=1.0, lemon=True, y=floor_at(x, z, None)), near=3)

    # 6. The bandits' quarter round their camp in the pit's west: a stake enclosure opening toward the
    # arena, a lookout in its far corner, the haul between the tents, banners at the gap.
    put("Palisade", -58, 409, 1.0, lambda nm, x, z: palisade(nm, (-58, 398), (-58, 418), lr), force=True)
    put("Palisade", -58, 448, 1.0, lambda nm, x, z: palisade(nm, (-58, 438), (-58, 458), lr), force=True)
    put("Palisade", -80, 394, 1.0, lambda nm, x, z: palisade(nm, (-100, 394), (-62, 394), lr), force=True)
    put("Lookout", -100, 404, 4.5, lambda nm, x, z: lookout(nm, x, z, lr), tall=True, near=6)
    for x, z in ((-96, 432), (-72, 452)):
        put("LootPile", x, z, 3.0, lambda nm, x, z: loot_pile(nm, x, z, lr), near=6)
    for k, (x, z) in enumerate(((-61, 422), (-61, 435))):
        put("BanditBanner", x, z, 1.0, lambda nm, x, z: bandit_banner(nm, x, z, AWNINGS[0] if k == 0 else AWNINGS[3], lr), near=3)
    put("RuinWall", -98, 462, 4.5, lambda nm, x, z: adobe_ruin(nm, x, z, 0, 9, lr), near=4)
    put("Outcrop", -104, 466, 5.0, lambda nm, x, z: rock_outcrop(nm, x, z, lr, 1.0), force=True)

    # 7. A palm and a bed between the pit's two houses.
    palms([(86, 438, "coconut", 17, (-1, 0.2))])
    bed(88, 445, 5.0, 2.8, 90, [PINK, ORANGE], near=6)

    # 8. Cactus gardens, one to each quarter of open sand.
    for x, z in ((52, 238), (-72, 304), (-54, 458), (60, 456)):
        put("CactusGarden", x, z, 8.0, lambda nm, x, z: cactus_garden(nm, x, z, lr), tall=True, near=6)

    # 9. Rock outcrops framing the Briarwood gate and marking the pit's east.
    for x, z, sz in ((-32, 465, 0.9), (32, 465, 0.9), (104, 396, 1.1)):
        put("Outcrop", x, z, 5.0 * sz, lambda nm, x, z: rock_outcrop(nm, x, z, lr, sz), near=4)

    print("[map_forge] oasis life:", dict(sorted(counts.items())))
    return out


# The legacy quarry pieces the desert keeps: gameplay (waystones, the Briarwood gate), the Warden's
# arena, the ridge gap's gate leaves, and the bandits' hideout in the passage.
QUARRY_KEEP = re.compile(r"^(OverlookWaystone|WarlordWaystone|GateBriarwood|WardenSign|ScrapGate[WE]|WardenThrone|"
                         r"ThroneBanner\d|WarlordBanner\d|PitBrazier\d|Manacles\d+|StandingStone\d+|SupplyCache|"
                         r"HideoutTent[AB]|HideoutBedroll|HideoutCrates|HideoutBanner|Barricade[AB])$")
WATER_TOP_Y = 4.0  # the oasis pool's terrain water surface (WorldTerrain fills whole voxels, Y0-4)


def _register_tree(node):
    """Put a kept node's parts back in REGISTRY (for the preview and the part count)."""
    props = node.get("properties", {})
    if "Size" in props and "CFrame" in props:
        cf = props["CFrame"]["CFrame"]
        REGISTRY.append({"name": node["name"], "size": tuple(props["Size"]), "pos": tuple(cf["position"]),
                         "rot": cf["orientation"], "color": tuple(round(c * 255) for c in props["Color"]),
                         "shape": props.get("Shape"), "collide": props.get("CanCollide", True),
                         "transparency": props.get("Transparency", 0), "layer": "prop",
                         "cls": node["className"]})
    for c in node.get("children", ()):
        _register_tree(c)


# ── The desert's rock, as parts ──────────────────────────────────────────────
# Iron Lowlands look gauntlet, round 3 (2026-09-24): 28 of 28 blind verdicts named the zone's
# terrain rock -- the mesas, the rim's scarp, the stacked towers, the arches -- as faceted voxel
# rock "with dark crevices", and asked for "a few large smooth rounded masses with bevelled
# edges". Voxel terrain cannot be that; the castle wall already is (SmoothPlastic parts), so the
# rock moves here and WorldTerrain keeps only sand (DESERT_ROCK_PARTS). Same positions and heights
# as the terrain had, so every collision proxy, spawn and marker stands where it did.
# Palette: the coral cliff face and the peach crest bands the round-3 hue split settled on; the
# floor's sand is WorldTerrain's (255, 232, 186).
MESA_BODY = (255, 132, 60)   # the cliff face: coral-orange, full chroma
MESA_BAND = (255, 208, 150)  # the crest and tier bands: pale peach, the calm step
MESA_DOME = (255, 176, 96)   # the domed tops: between the two
# { x, z, radius x, radius z, yaw, top } -- WorldTerrain's MESAS, verbatim.
DESERT_MESAS = [
    (204, 404, 40, 56, 18, 86), (170, 498, 30, 21, -12, 66), (-226, 420, 36, 48, -8, 76),
    (-214, 198, 32, 26, 24, 60), (-164, 498, 36, 19, 6, 74), (214, 196, 30, 24, -20, 64),
    (68, 494, 47, 22, 2, 80), (-70, 494, 49, 22, -2, 74),
]
# { x, z, radius x, radius z, top, yaw } -- WorldTerrain's FAR_MESAS, verbatim.
DESERT_FAR_MESAS = [
    (430, 236, 44, 30, 96, 12), (452, 352, 62, 38, 128, -18), (404, 468, 48, 34, 110, 28),
    (336, 572, 40, 28, 84, 6), (470, 120, 38, 30, 80, -30),
]
# { x, z, radius, height } -- WorldTerrain's TOWERS, verbatim.
DESERT_TOWERS = [
    (160, 262, 10, 98), (232, 300, 12, 116), (146, 446, 9, 82), (-198, 318, 10, 90),
    (-130, 505, 8, 76), (150, 168, 8, 72), (-236, 262, 9, 84),
]
DESERT_SAND_ROCKS = [(-100, 262), (-88, 300), (-60, 410), (60, 180), (-70, 196)]


def drum(name, x, y0, y1, z, rx, rz, color, yaw=0.0, **kw):
    """A vertical elliptical drum: a Cylinder part stood on end (axis X -> world Y), rx along the
    yawed X, rz along the yawed Z. Decorative: no collision, no query (the proxies hold players)."""
    kw.setdefault("collide", False)
    kw.setdefault("query", False)
    kw.setdefault("layer", "rock")
    return part(name, (y1 - y0, rx * 2, rz * 2), (x, (y0 + y1) / 2, z), color, "SmoothPlastic",
                mul(rot_y(yaw), rot_z(90)), shape="Cylinder", **kw)


def mesa(name, x, z, rx, rz, yaw, top, rng, base=-6.0):
    """A flat-topped mesa as three stepped drums, each narrower than the one below, a peach band
    at every tier's lip and a shallow dome on the crest: a few big rounded masses, no facets."""
    tiers = [(top - 30, 1.0), (top - 14, 0.84), (top, 0.66)]
    kids = []
    y = base
    for k, (ty, w) in enumerate(tiers):
        j = rng.uniform(0.97, 1.03)
        kids.append(drum(f"{name}_Tier{k}", x, y, ty, z, rx * w * j, rz * w * j, MESA_BODY, yaw))
        # the lip: a slightly wider, thin band in peach, so every tier reads as a step
        kids.append(drum(f"{name}_Band{k}", x, ty - 2.2, ty + 0.4, z, rx * w * j * 1.035, rz * w * j * 1.035,
                         MESA_BAND, yaw, shadow=False))
        y = ty
    w = tiers[-1][1]
    kids.append(ellipsoid(f"{name}_Dome", (rx * w * 2.0, 7.0, rz * w * 2.0), (x, top - 0.6, z), MESA_DOME,
                          rot=mul(rot_y(yaw), rot_x(1.5)), layer="rock", shadow=False))
    return model(name, kids, attrs={"DesertRock": True})


def rock_tower(name, x, z, r, h, rng, base=0.0):
    """A stacked hoodoo: bulging drums of falling radius, a peach band between every pair, a round
    cap. The old terrain tower's own recipe (segments 9-15 studs, radius easing to 0.82), in parts."""
    kids = []
    y = base
    k = 0
    while y < h:
        seg = rng.uniform(9, 15)
        rr = r * (1 - 0.18 * (y / h)) * rng.uniform(0.9, 1.12)
        kids.append(drum(f"{name}_Drum{k}", x + rng.uniform(-0.8, 0.8), y, y + seg + 0.5, z + rng.uniform(-0.8, 0.8),
                         rr, rr * rng.uniform(0.94, 1.06), MESA_BODY, rng.uniform(0, 180)))
        kids.append(drum(f"{name}_Band{k}", x, y + seg - 1.4, y + seg + 0.9, z, rr * 1.06, rr * 1.06, MESA_BAND,
                         shadow=False))
        y += seg
        k += 1
    cap = r * 0.8
    kids.append(part(f"{name}_Cap", (cap * 2, cap * 1.6, cap * 2), (x, y + cap * 0.6, z), MESA_DOME, "SmoothPlastic",
                     shape="Ball", collide=False, query=False, shadow=False, layer="rock"))
    return model(name, kids, attrs={"DesertRock": True})


def rock_arch(name, x, z, span, along_x, y_under, thick, pillar_r, base, rng):
    """A natural arch: two drums and a round lintel laid across them, its underside at y_under."""
    kids = []
    half = span / 2
    for sgn, tag in ((-1, "A"), (1, "B")):
        px = x + sgn * half if along_x else x
        pz = z if along_x else z + sgn * half
        kids.append(drum(f"{name}_Pillar{tag}", px, base, y_under + thick * 0.35, pz, pillar_r, pillar_r * 0.9,
                         MESA_BODY, rng.uniform(0, 90)))
        kids.append(part(f"{name}_Knob{tag}", (pillar_r * 1.9, pillar_r * 1.5, pillar_r * 1.9),
                         (px, y_under + thick * 0.35 + pillar_r * 0.5, pz), MESA_BAND, "SmoothPlastic",
                         shape="Ball", collide=False, query=False, shadow=False, layer="rock"))
    length = span + pillar_r * 2
    rot = None if along_x else rot_y(90)
    kids.append(part(f"{name}_Lintel", (length, thick, thick), (x, y_under + thick / 2, z), MESA_BODY,
                     "SmoothPlastic", rot, shape="Cylinder", collide=False, query=False, layer="rock"))
    kids.append(part(f"{name}_LintelBand", (length * 0.98, thick * 0.5, thick * 1.06), (x, y_under + thick * 0.72, z),
                     MESA_BAND, "SmoothPlastic", rot, shape="Cylinder", collide=False, query=False, shadow=False,
                     layer="rock"))
    return model(name, kids, attrs={"DesertRock": True})


def desert_rockforms():
    """The Iron Lowlands' rock as SmoothPlastic: mesas, far mesas, towers, the two arches and the
    loose boulders on the sand. Its own seed, so the shared rng and every other prop stay put."""
    rr = random.Random(0x40C5)
    out = []
    for i, (x, z, rx, rz, yaw, top) in enumerate(DESERT_MESAS):
        out.append(mesa(f"Mesa{i}", x, z, rx, rz, yaw, top, rr))
    for i, (x, z, rx, rz, top, yaw) in enumerate(DESERT_FAR_MESAS):
        out.append(mesa(f"FarMesa{i}", x, z, rx, rz, yaw, top, rr, base=-10.0))
    for i, (x, z, r, h) in enumerate(DESERT_TOWERS):
        out.append(rock_tower(f"Hoodoo{i}", x, z, r, h, rr))
    # the arch over the Briarwood trail (portal under y 35, the old terrain arch's underside was 26-38)
    out.append(rock_arch("TrailArch", 0, 506, 68, True, 35.0, 22.0, 12.0, -4.0, rr))
    # the bandits' hideout arch over the passage mouth (its underside was y 22)
    out.append(rock_arch("HideoutArch", -118, 300, 52, False, 23.0, 16.0, 6.5, 2.0, rr))
    # the loose boulders out on the open sand, where the terrain heaped its knobs
    for i, (x, z) in enumerate(DESERT_SAND_ROCKS):
        y = floor_at(x, z, QUARRY_Y)
        w, h, d = rr.uniform(7, 10), rr.uniform(4.5, 6.5), rr.uniform(6, 9)
        out.append(model(f"SandRock{i}", [
            ellipsoid("Body", (w, h, d), (x, y + h * 0.32, z), MESA_BODY, rot=tilt(rr, 4, 12), layer="rock"),
            ellipsoid("Cap", (w * 0.55, h * 0.5, d * 0.55), (x + w * 0.12, y + h * 0.62, z - d * 0.1), MESA_BAND,
                      rot=tilt(rr, 4, 12), layer="rock", shadow=False),
        ], attrs={"DesertRock": True}))
    return out


# ── Dressing the sand ────────────────────────────────────────────────────────
# Iron Lowlands look gauntlet, rounds 4-5 (2026-09-24): with the rock as parts, every verdict named
# the sand plane -- "60-70% of the frame, flat, nothing on it to run to". This lines the trail with
# chunky rounded things at the player's scale: a peach kerb along both edges of every trail segment,
# and a cluster every few studs to either side (coral boulders, barrel cacti, short saguaros, crate
# stacks, sand mounds, flower pads). Everything sits off the trail, off every spawn, pool, marker
# and the Warden's arena, and off the props already standing (REGISTRY clearance), so nothing that
# gameplay reads moves. Decorative: no collision, no query.
SAND_TRAIL = [(0, 136), (0, 196), (20, 224), (20, 300), (-22, 310), (-22, 360), (0, 372), (0, 470)]
SAND_KERB = (255, 208, 150)      # the trail's kerb: the mesas' peach band
SAND_MOUND = (255, 196, 116)     # a dune mound: the floor's gold, one step deeper
BLOOM_PAD = (120, 232, 96)       # a flower pad: the cactus lime
BLOOM_HEADS = [(255, 96, 160), (72, 204, 255), (255, 220, 64), (200, 120, 255)]
SAND_KEEP_OUT = [  # (x, z, radius): spawns, arrivals, the pools, the arena, the camp fire
    (18, 152, 12), (0, 358, 12), (0, 424, 40), (94, 348, 26), (73, 284, 22), (-66, 272, 14),
] + [(sp[4][0], sp[4][1], 9) for sp in ENEMY_SPAWNS]


def _trail_point(t):
    """Point t studs along SAND_TRAIL, its unit direction and its left normal (in xz)."""
    acc = 0.0
    for (ax, az), (bx, bz) in zip(SAND_TRAIL, SAND_TRAIL[1:]):
        seg = math.hypot(bx - ax, bz - az)
        if acc + seg >= t:
            u = (t - acc) / seg
            dx, dz = (bx - ax) / seg, (bz - az) / seg
            return (ax + dx * (t - acc), az + dz * (t - acc)), (dx, dz), (-dz, dx)
        acc += seg
    return None, None, None


def _sand_clear(x, z, radius):
    for kx, kz, kr in SAND_KEEP_OUT:
        if math.hypot(x - kx, z - kz) < kr + radius:
            return False
    for (ax, az), (bx, bz) in zip(SAND_TRAIL, SAND_TRAIL[1:]):
        seg = math.hypot(bx - ax, bz - az)
        u = max(0.0, min(1.0, ((x - ax) * (bx - ax) + (z - az) * (bz - az)) / (seg * seg)))
        if math.hypot(x - (ax + (bx - ax) * u), z - (az + (bz - az) * u)) < 7.0 + radius:
            return False
    for e in REGISTRY:
        if e["layer"] in ("ground", "proxy", "volume", "marker", "decal", "vista"):
            continue
        if e["name"].startswith("TrailKerb"):  # the trail band above already keeps clear of the kerbs
            continue
        w = max(e["size"][0], e["size"][2])
        if w > 24:  # the mesas and arches: their footprints are far bigger than their contact
            continue
        ex, _, ez = e["pos"]
        if math.hypot(x - ex, z - ez) < radius + w * 0.5 + 0.5:
            return False
    return True


def sand_boulders(name, x, z, rng):
    y = floor_at(x, z, QUARRY_Y)
    kids = []
    for i in range(rng.randint(2, 3)):
        w, h, d = rng.uniform(4, 7), rng.uniform(2.6, 4.2), rng.uniform(3.5, 6)
        ox, oz = rng.uniform(-2.5, 2.5), rng.uniform(-2.5, 2.5)
        kids.append(ellipsoid(f"Rock{i}", (w, h, d), (x + ox, y + h * 0.34, z + oz), MESA_BODY,
                              rot=tilt(rng, 4, 14), layer="rock"))
    kids.append(ellipsoid("Cap", (2.6, 1.8, 2.4), (x + 0.4, y + 3.2, z - 0.3), MESA_BAND, rot=tilt(rng, 4, 14),
                          layer="rock", shadow=False))
    return model(name, kids)


def sand_mound(name, x, z, rng):
    y = floor_at(x, z, QUARRY_Y)
    w, d = rng.uniform(9, 14), rng.uniform(7, 11)
    return model(name, [
        ellipsoid("Mound", (w, rng.uniform(2.2, 3.2), d), (x, y + 0.5, z), SAND_MOUND, rot=rot_y(rng.uniform(0, 180)),
                  layer="rock"),
        ellipsoid("Crest", (w * 0.55, 1.6, d * 0.5), (x + w * 0.1, y + 1.7, z), (255, 224, 170),
                  rot=rot_y(rng.uniform(0, 180)), layer="rock", shadow=False),
    ])


def bloom_pad(name, x, z, rng):
    y = floor_at(x, z, QUARRY_Y)
    kids = [ellipsoid("Pad", (rng.uniform(5, 7), 1.4, rng.uniform(4, 6)), (x, y + 0.3, z), BLOOM_PAD,
                      rot=rot_y(rng.uniform(0, 180)), layer="rock")]
    for i in range(rng.randint(3, 5)):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.6, 2.2)
        kids.append(part(f"Bloom{i}", (1.5, 1.5, 1.5), (x + math.cos(a) * r, y + 1.6, z + math.sin(a) * r),
                         rng.choice(BLOOM_HEADS), "SmoothPlastic", shape="Ball", collide=False, query=False,
                         shadow=False, layer="rock"))
    return model(name, kids)


KERB_OFFSET = 6.6   # studs from the trail's centre line to each kerb
KERB_PIECE = 10.0   # studs per straight kerb piece
KERB_DIAM = 1.4  # a slim lip, mostly sunk: at 2.2 and sat on the sand the kerbs read as logs lying down the trail


def _kerb_line(side):
    """The trail's centre line offset KERB_OFFSET to one side, mitred at every bend. One offset per
    segment (the old kerb) left a gap on the outside of each bend and crossed the trail on the
    inside (2026-09-24 recording, 3:39); a mitre meets both neighbours at one point, and the clamp
    keeps a sharp bend's inner point from shooting across the trail."""
    pts = SAND_TRAIL
    normals = []
    for (ax, az), (bx, bz) in zip(pts, pts[1:]):
        seg = math.hypot(bx - ax, bz - az)
        normals.append((-(bz - az) / seg, (bx - ax) / seg))
    line = []
    for i, (px, pz) in enumerate(pts):
        n0 = normals[max(0, i - 1)]
        n1 = normals[min(len(normals) - 1, i)]
        mx, mz = n0[0] + n1[0], n0[1] + n1[1]
        ml = math.hypot(mx, mz)
        mx, mz = mx / ml, mz / ml
        cos_half = max(1e-3, mx * n1[0] + mz * n1[1])
        reach = min(KERB_OFFSET / cos_half, 2 * KERB_OFFSET)
        line.append((px + mx * reach * side, pz + mz * reach * side))
    return line


def trail_kerbs():
    """A round peach kerb along each edge of the trail: ~10-stud straight pieces, each following
    the floor at its own ends, with a ball at every joint so the pieces read as one curb."""
    out = []
    for side, tag in ((-1, "L"), (1, "R")):
        line = _kerb_line(side)
        joints = [line[0]]
        for (ax, az), (bx, bz) in zip(line, line[1:]):
            seg = math.hypot(bx - ax, bz - az)
            steps = max(1, round(seg / KERB_PIECE))
            joints += [(ax + (bx - ax) * j / steps, az + (bz - az) * j / steps) for j in range(1, steps + 1)]
        for j, ((ax, az), (bx, bz)) in enumerate(zip(joints, joints[1:])):
            lift = 0.3 + 0.07 * (j % 2)  # neighbours a hair apart, so the overlap inside a joint never z-fights
            a3 = (ax, floor_at(ax, az, QUARRY_Y) + lift, az)
            b3 = (bx, floor_at(bx, bz, QUARRY_Y) + lift, bz)
            out.append(cyl(f"TrailKerb{tag}{j:02d}", a3, b3, KERB_DIAM, SAND_KERB, collide=False, query=False,
                           layer="rock"))
        for j, (jx, jz) in enumerate(joints):
            y = floor_at(jx, jz, QUARRY_Y) + 0.335
            out.append(part(f"TrailKerbJoint{tag}{j:02d}", (KERB_DIAM + 0.25,) * 3, (jx, y, jz), SAND_KERB,
                            shape="Ball", collide=False, query=False, layer="rock"))
    return out


def desert_sand_dressing():
    """The kerbs along the trail."""
    out = []
    out += trail_kerbs()
    # (The clusters that used to stand every 12 studs down both sides of the trail are gone: with a
    # prop every few studs the whole basin read as clutter. Its dressing is composed in oasis_life:
    # themed places at the edges, open sand where the fighting is.)
    return out


def build_iron_lowlands(rng):
    mark = len(REGISTRY)
    ground, legacy, proxies = quarry_layout(rng)
    # Drop the quarry's own dressing (its parts and their REGISTRY entries); keep the floors,
    # proxies and the pieces QUARRY_KEEP names.
    # (only the floors actually written: the quarry's own mounds were "ground" too, and left in the
    # registry they read as phantom floors to every later floor_at)
    floors = {g["name"] for g in ground}
    REGISTRY[mark:] = [e for e in REGISTRY[mark:] if e["layer"] == "proxy" or (e["layer"] == "ground" and e["name"] in floors)]
    visual = [n for n in legacy if QUARRY_KEEP.match(n["name"])]
    def resurface(node, pattern, color, material="SmoothPlastic"):
        for c in node.get("children", ()):
            if re.match(pattern, c["name"]):
                c["properties"]["Material"] = material
                c["properties"]["Color"] = [_r(v / 255) for v in color]
    for n in visual:
        if n["name"].startswith("StandingStone"):  # the arena's ring, re-cut in the basin's peach sandstone (toy plastic)
            resurface(n, r"^Body$", hsv(32, 0.2, 1.0))  # calm pale peach tint
            resurface(n, r"^Cap$", hsv(32, 0.12, 1.0))  # its dome a step paler, so the top reads round
        elif n["name"] == "GateBriarwood":  # the gate's pillars in the adobe's apricot, capped in terracotta
            resurface(n, r"^Pillar-?1$", ADOBE_WALLS[0])
            resurface(n, r"^PillarCap", ADOBE_PLINTH)
        elif n["name"].startswith("PitBrazier"):
            resurface(n, r"^Base$", ADOBE_PLINTH)
        _register_tree(n)
    for g in ground:
        if g["name"] == "SumpBed":  # the oasis pool's floor, seen through the water
            g["properties"]["Material"] = "SmoothPlastic"
            g["properties"]["Color"] = [_r(c / 255) for c in GROUND_TAN]
    global AUTO_GROUND
    AUTO_GROUND = True
    visual += desert_dressing()
    visual += desert_rockforms()
    visual += desert_sand_dressing()
    visual += oasis_life(mark)
    return ground, visual, proxies


# ── Briarwood: the wooded vale south of the Warden's Pit ─────────────────────
# Built to the Codex concept set (~/briarwood-concepts): angular leaning trees with block
# canopies, faceted moss boulders, packed-earth trails, broken settlement masonry, two
# waterfalls, the Mirror Pool, Hollow Rest graveyard, a ruined chapel arch and the Warden's
# Grove ringed by living trees. One floor level (the pit's), so the gate needs no ramp.
BRIAR_Y = PIT_Y
BRIAR_X = (-118, 118)          # cliff line; the floor slab runs a little past it
BRIAR_Z = (472, 940)
GROTTO = (118, 134, 649, 661)  # pocket behind the Mirror Pool waterfall: x0 x1 z0 z1
POOL = (82, 655, 15.5)         # Mirror Pool centre and water radius
POOL_HOLE = (66, 98, 639, 671) # gap in the grass floor the pool bed fills
GROVE = (0, 868, 36)           # Warden's Grove arena centre and radius
EARTH = (238, 190, 126)
SAND = (238, 198, 134)  # the quarry stones: pale saturated sandstone-peach
POOL_WATER = (40, 184, 228)  # the Mirror Pool and its streams: a vivid toy cyan, never slate teal
FALL_WATER = (206, 242, 255)  # the falling sheets: nearly white aqua
BRIAR_ROCK = (130, 158, 250)  # the waterfalls' rock shoulders: periwinkle toy stone
BRIAR_ROCK_DARK = (86, 112, 232)  # the same blue one step deeper, never charcoal
BRIAR_IRON = (24, 138, 150)  # grave pickets, straps and hooks: deep teal, never gunmetal
BRIAR_GLOW = (120, 240, 170)  # the vale's waystones: a clean mint, not sage
BRIAR_STONE = (228, 238, 255)  # the chapel and grave masonry: the big calm surface, a pale sky-blue white
BRIAR_STONE_DARK = (168, 196, 255)  # its alternate courses and darker headstones: the same blue, deeper
BRIAR_CANOPY = [(104, 230, 98), (60, 210, 68), (130, 238, 104)]  # spring greens, one hue, three values


def beam_rot(a, b):
    """Rotation whose local +Y runs from point a to point b (a tilted post, limb or root)."""
    dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    theta = math.degrees(math.atan2(math.hypot(dx, dz), dy))
    phi = 180 - math.degrees(math.atan2(dz, dx))
    return mul(rot_y(phi), rot_z(theta))


def beam(name, a, b, width, color, material="Wood", depth=None, **kw):
    """Box from a to b, `width` across; local Y along the beam."""
    length = math.dist(a, b)
    centre = tuple((a[i] + b[i]) / 2 for i in range(3))
    return part(name, (width, length, depth or width), centre, color, material, beam_rot(a, b), **kw)


class Tops:
    """Nudges horizontal top faces apart inside one prop so its own blocks never z-fight."""

    def __init__(self):
        self.used = set()

    def __call__(self, top, step=0.12):
        while any(round(top * 20) + d in self.used for d in (-1, 0, 1)):
            top += step
        self.used.add(round(top * 20))
        return top


def briar_tree(name, x, y, z, rng, scale=1.0, roots=True):
    """Codex's Briarwood tree: a leaning angular trunk, three crooked limbs each carrying a
    block of canopy, a crown block, and four angular roots. Canopy bottoms sit 8+ studs up,
    so a tree must stay 20+ studs from spawns and arrivals (camera clearance rule)."""
    y = floor_at(x, z, y)
    s = scale
    h = rng.uniform(8, 11) * s
    lean = rng.uniform(0, math.tau)
    lx, lz = x + math.cos(lean) * 0.4 * s, z + math.sin(lean) * 0.4 * s
    tops = Tops()
    kids = [part("Bole", (2.0 * s, h * 0.5, 2.0 * s), (x, y + h * 0.25, z), TRUNK, "SmoothPlastic", rot_y(rng.uniform(0, 90)),
                 layer="tree"),
            part("Trunk", (1.4 * s, h * 0.62, 1.4 * s), (lx, y + h * 0.69, lz), TRUNK, "SmoothPlastic", rot_y(rng.uniform(0, 90)),
                 layer="tree")]
    tops(y + h * 0.5)
    tops(y + h)
    for k in range(3):
        a = k * 2.094 + rng.uniform(0, 0.5)
        tip = (lx + math.cos(a) * 2.4 * s, y + h * 0.9, lz + math.sin(a) * 2.4 * s)
        kids.append(beam(f"Limb{k}", (lx, y + h * 0.55, lz), tip, 0.36 * s, TRUNK, "SmoothPlastic", collide=False, layer="tree"))
        ch = 2.6 * s
        top = tops(y + h * 0.9 + 1.0 * s + ch / 2 + k * 0.35 * s)
        kids.append(part(f"Canopy{k}", (5 * s, ch, 4.5 * s), (tip[0], top - ch / 2, tip[2]), BRIAR_CANOPY[k], "SmoothPlastic",
                         rot_y(math.degrees(a) * 0.3), collide=False, layer="canopy"))
    ch = 2.2 * s
    top = tops(y + h + 1.0 * s + ch / 2)
    kids.append(part("Crown", (4.6 * s, ch, 4.2 * s), (lx, top - ch / 2, lz), BRIAR_CANOPY[1], "SmoothPlastic", rot_y(12),
                     collide=False, layer="canopy"))
    if roots:
        for k in range(4):
            a = k * math.pi / 2 + 0.3 + lean
            kids.append(beam(f"Root{k}", (x, y + 1.2 * s, z), (x + math.cos(a) * 3 * s, y + 0.15, z + math.sin(a) * 3 * s),
                             0.5 * s, TRUNK, "SmoothPlastic", collide=False, query=False, layer="tree"))
    return model(name, kids)


def moss_boulder(name, x, y, z, rng, s=1.0, collide=True):
    """Faceted boulder with a moss cap."""
    y = floor_at(x, z, y)
    w, h, d = rng.uniform(2.2, 3.2) * s, rng.uniform(1.4, 2.0) * s, rng.uniform(1.8, 2.6) * s
    yaw = rng.uniform(0, 90)
    r = mul(rot_y(yaw), rot_z(rng.uniform(-8, 8)))
    return model(name, [
        part("Rock", (w, h, d), (x, y + h / 2 - 0.15, z), BRIAR_ROCK, "SmoothPlastic", r, collide=collide, layer="rock"),
        part("Moss", (w * 0.9, 0.3, d * 0.9), (x, y + h - 0.2, z), MOSS, "SmoothPlastic", rot_y(yaw), collide=False, query=False,
             layer="rock"),
    ])


def undergrowth(name, cx, cz, rx, rz, n, rng, keep_out):
    """Block undergrowth: small moss/leaf cubes scattered over an ellipse, off trails and spawns."""
    kids, tops = [], Tops()
    tries = 0
    while len(kids) < n and tries < n * 12:
        tries += 1
        x, z = cx + rng.uniform(-rx, rx), cz + rng.uniform(-rz, rz)
        if ((x - cx) / rx) ** 2 + ((z - cz) / rz) ** 2 > 1 or not clear_of(x, z, keep_out):
            continue
        w, h, d = rng.uniform(0.8, 2.2), rng.uniform(0.5, 1.3), rng.uniform(0.8, 2.2)
        y = floor_at(x, z, BRIAR_Y)
        top = tops(y + h, 0.06)
        kids.append(part(f"Growth{len(kids)}", (w, top - y, d), (x, (top + y) / 2, z),
                         rng.choice([MOSS, BRIAR_CANOPY[1], GRASS, GRASS_DARK]), "Grass", rot_y(rng.uniform(0, 90)),
                         collide=False, query=False, shadow=False, layer="prop"))
    return model(name, kids)


def clear_of(x, z, keep_out):
    """keep_out entries: (x, z, r) circles or ('trail', points, half_width)."""
    for k in keep_out:
        if k[0] == "trail":
            _, pts, hw = k
            for i in range(len(pts) - 1):
                if seg_dist(x, z, pts[i], pts[i + 1]) < hw:
                    return False
        elif math.hypot(x - k[0], z - k[1]) < k[2]:
            return False
    return True


def seg_dist(x, z, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)))
    return math.hypot(x - (ax + dx * t), z - (az + dz * t))


TRAIL_STEPS = (0.10, 0.16, 0.22)


def earth_trail(name, pts, width, y=None, color=EARTH, phase=0):
    """Packed-earth trail: one flat box per leg, legs cycling through three heights so their
    overlapping joints never share a top face. `phase` picks the first leg's height so a trail
    that branches off another never lands on the leg it joins."""
    kids = []
    for i in range(len(pts) - 1):
        (ax, az), (bx, bz) = pts[i], pts[i + 1]
        length = math.hypot(bx - ax, bz - az) + width * 0.9
        yaw = math.degrees(math.atan2(-(bz - az), bx - ax))
        fy = floor_at((ax + bx) / 2, (az + bz) / 2, y if y is not None else BRIAR_Y)
        t = TRAIL_STEPS[(phase + i) % 3]
        kids.append(part(f"Leg{i}", (length, t, width), ((ax + bx) / 2, fy + t / 2, (az + bz) / 2), color, "Ground",
                         rot_y(yaw), collide=False, query=False, shadow=False, layer="decal"))
    return model(name, kids)


def ruin_wall(name, x, z, yaw, n, rows, rng, block=(2.9, 1.8, 1.6)):
    """Broken settlement masonry: staggered courses of blocks with gaps where the wall has
    fallen, moss mounded along its foot. A block is only laid where the course below holds it."""
    y = floor_at(x, z, BRIAR_Y)
    r = rot_y(yaw)
    right, fwd = apply(r, (1, 0, 0)), apply(r, (0, 0, -1))
    bw, bh, bd = block
    present = [[True] * (n + 1) for _ in range(rows)]
    kids = []
    for row in range(rows):
        for i in range(n):
            s = i * (bw + 0.1) + (row % 2) * bw * 0.5
            # Odd courses are staggered half a block right: block i sits on i and i+1 below;
            # an even course's block i sits on the staggered i-1 and i.
            below = ((present[row - 1][i], present[row - 1][min(i + 1, n)]) if row % 2 else
                     (present[row - 1][max(i - 1, 0)] if i else False, present[row - 1][i])) if row else (True, True)
            if rng.random() < 0.18 + row * 0.12 or not any(below):
                present[row][i] = False
                continue
            px, pz = x + right[0] * s + fwd[0] * rng.uniform(-0.1, 0.1), z + right[2] * s + fwd[2] * rng.uniform(-0.1, 0.1)
            kids.append(part(f"Block{row}_{i}", (bw, bh, bd), (px, y + bh / 2 + row * bh, pz), BRIAR_STONE, "SmoothPlastic",
                             mul(r, rot_y(rng.uniform(-3, 3))), layer="prop"))
        present[row][n] = False
    for i in range(0, n, 2):
        s = i * (bw + 0.1) + bw * 0.4
        side = 1 if i % 4 == 0 else -1
        mx, mz = x + right[0] * s + fwd[0] * side * (bd * 0.5 + 0.6), z + right[2] * s + fwd[2] * side * (bd * 0.5 + 0.6)
        kids.append(part(f"Moss{i}", (3.0, 0.7 + (i % 3) * 0.06, 2.2), (mx, y + (0.7 + (i % 3) * 0.06) / 2, mz), MOSS, "SmoothPlastic",
                         mul(r, rot_y(15)), collide=False, query=False, layer="prop"))
    return model(name, kids)


def briar_fall(name, x, z, yaw, height, width, rng, lip_bottom=None):
    """Waterfall off a rock face: three stepped rock columns behind a planar sheet with darker
    stripes, foam at the foot. The face is at (x, z); water flows along the look direction."""
    y = floor_at(x, z, BRIAR_Y)
    r = rot_y(yaw)
    right, fwd = apply(r, (1, 0, 0)), apply(r, (0, 0, -1))
    tops = Tops()
    kids = []
    lip_bottom = lip_bottom if lip_bottom is not None else y + height - 0.6
    for k in (-1, 1):  # rock shoulders either side of the sheet; the face behind it is the cliff itself
        cw = width * 0.45 + 1.4
        top = tops(lip_bottom + 0.6 + rng.uniform(0, 1.2))
        cx = x + right[0] * k * (width / 2 + cw / 2 - 0.4) - fwd[0] * 1.0
        cz = z + right[2] * k * (width / 2 + cw / 2 - 0.4) - fwd[2] * 1.0
        kids.append(part(f"Step{k}", (cw, top - y + 1, 4.6), (cx, (top + y - 1) / 2, cz), BRIAR_ROCK if k > 0 else BRIAR_ROCK_DARK,
                         "SmoothPlastic", r, collide=False, layer="cliff"))
        kids.append(part(f"StepMoss{k}", (cw + 0.2, 0.36, 4.8), (cx, top + 0.18, cz), MOSS, "SmoothPlastic", r, collide=False,
                         query=False, layer="cliff"))
    for k in range(2):
        kids.append(part(f"WaterSheet{k}", (width - k * 0.8, height, 0.4), (x + fwd[0] * (0.3 + k * 0.5), y + height / 2 + 0.4,
                                                                          z + fwd[2] * (0.3 + k * 0.5)),
                         FALL_WATER, "Glass", r, collide=False, query=False, shadow=False, transparency=0.35 + k * 0.15))
    for k in range(3):
        off = (k - 1) * width * 0.3
        kids.append(part(f"Stripe{k}", (width * 0.12, height - 1, 0.1), (x + right[0] * off + fwd[0] * 0.75, y + height / 2,
                                                                       z + right[2] * off + fwd[2] * 0.75),
                         POOL_WATER, "Glass", r, collide=False, query=False, shadow=False, transparency=0.3))
    kids.append(part("Foam", (width + 2, 0.5, 2.4), (x + fwd[0] * 1.6, y + 0.25, z + fwd[2] * 1.6), FALL_WATER, "SmoothPlastic",
                     r, collide=False, query=False, shadow=False, transparency=0.25, layer="decal"))
    kids.append(part("Mist", (0.5, 0.5, 0.5), (x + fwd[0] * 1.6, y + 1.2, z + fwd[2] * 1.6), (255, 255, 255), "SmoothPlastic",
                     transparency=1, collide=False, query=False, shadow=False, children=[smoke(5.0, 0.16, 1.0, (235, 240, 245))]))
    kids.append(part("Lip", (width + 3, 3.2, 5.5), (x - fwd[0] * 1.2, lip_bottom + 1.6, z - fwd[2] * 1.2), BRIAR_ROCK_DARK,
                     "SmoothPlastic", mul(r, rot_y(4)), collide=False, layer="cliff"))
    return model(name, kids, attrs={"Waterfall": True})


def hanging_sign(name, x, z, yaw, title, subtitle=""):
    """Single post with an arm; the board hangs from two straps under the arm."""
    y = floor_at(x, z, BRIAR_Y)
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))

    def at(lx):
        return x + right[0] * lx, z + right[2] * lx

    px, pz = at(0)
    ax, az = at(2.6)
    kids = [part("Post", (0.7, 11, 0.7), (px, y + 5.5, pz), BEAM, "SmoothPlastic", r),
            part("Arm", (5.6, 0.5, 0.5), (ax, y + 10.6, az), BEAM, "SmoothPlastic", r, collide=False)]
    for k, lx in enumerate((1.4, 4.4)):
        sx, sz = at(lx)
        kids.append(part(f"Strap{k}", (0.25, 1.0, 0.25), (sx, y + 9.85, sz), BRIAR_IRON, "SmoothPlastic", r, collide=False, query=False))
    bx, bz = at(2.9)
    kids.append(part("Board", (4.6, 1.9, 0.45), (bx, y + 8.4, bz), BRIAR_IRON, "SmoothPlastic", r, collide=False,
                     children=[label_gui("Front", title, subtitle, (236, 220, 170), px=60),
                               label_gui("Back", title, subtitle, (236, 220, 170), px=60)]))
    return model(name, kids)


def headstone(name, x, z, rng, y=None):
    y = floor_at(x, z, y if y is not None else BRIAR_Y)
    h = rng.uniform(2.6, 3.6)
    return part(name, (1.8, h, 0.7), (x, y + h / 2 - 0.15, z), BRIAR_STONE if rng.random() < 0.7 else BRIAR_STONE_DARK, "SmoothPlastic",
                mul(rot_y(rng.uniform(-8, 8)), rot_z(rng.uniform(-5, 5))), layer="prop")


def iron_fence(name, a, b, rng, gaps=()):
    """Broken iron picket fence from a to b; `gaps` are (s0, s1) distances left open."""
    ax, az = a
    bx, bz = b
    seg = math.hypot(bx - ax, bz - az)
    dx, dz = (bx - ax) / seg, (bz - az) / seg
    yaw = math.degrees(math.atan2(-dz, dx))
    kids = []
    runs, run = [], []  # consecutive pickets; each rail spans one run so its ends sit inside pickets
    s = 0.0
    k = 0
    while s <= seg + 1e-6:
        if any(g0 <= s <= g1 for g0, g1 in gaps):
            if run:
                runs.append(run)
                run = []
        else:
            h = rng.uniform(2.4, 3.6)
            px, pz = ax + dx * s, az + dz * s
            kids.append(part(f"Picket{k}", (0.22, h, 0.22), (px, floor_at(px, pz, BRIAR_Y) + h / 2, pz), BRIAR_IRON, "SmoothPlastic",
                             rot_y(yaw), collide=False))
            run.append(s)
        s += 2.0
        k += 1
    if run:
        runs.append(run)
    for i, run in enumerate(runs):
        if len(run) < 2:
            continue
        s0, s1 = run[0], run[-1]
        mid = (s0 + s1) / 2
        px, pz = ax + dx * mid, az + dz * mid
        kids.append(part(f"Rail{i}", (s1 - s0, 0.16, 0.16), (px, floor_at(px, pz, BRIAR_Y) + 2.0, pz), BRIAR_IRON, "SmoothPlastic",
                         rot_y(yaw), collide=False, query=False))
    return model(name, kids)


def stone_arch(name, cx, cz, yaw, span=10.0, pier_h=8.4, depth=2.6, wedges=7):
    """Ruined chapel doorway: two piers of stacked blocks and a segmental arch of straight-edged
    wedge blocks. Local X spans the opening; the path runs through along local Z."""
    y = floor_at(cx, cz, BRIAR_Y)
    r = rot_y(yaw)
    right = apply(r, (1, 0, 0))
    kids = []
    courses = max(1, round(pier_h / 2.1))
    ch = pier_h / courses
    for side in (-1, 1):
        for i in range(courses):
            px, pz = cx + right[0] * side * (span / 2 + 1.25), cz + right[2] * side * (span / 2 + 1.25)
            kids.append(part(f"Pier{side}_{i}", (2.5, ch, depth), (px, y + ch / 2 + i * ch, pz), BRIAR_STONE if i % 2 else BRIAR_STONE_DARK,
                             "SmoothPlastic", mul(r, rot_y(2 * (-1) ** i))))
    r_in, r_out = span / 2, span / 2 + 2.3
    r_mid = (r_in + r_out) / 2
    chord = 2 * r_mid * math.sin(math.pi / (2 * wedges)) + 0.25
    for i in range(wedges):
        am = (i + 0.5) * math.pi / wedges
        wx, wz = cx + right[0] * math.cos(am) * r_mid, cz + right[2] * math.cos(am) * r_mid
        kids.append(part(f"Wedge{i}", (chord, r_out - r_in, depth), (wx, y + pier_h + math.sin(am) * r_mid, wz),
                         BRIAR_STONE if i % 2 else BRIAR_STONE_DARK, "SmoothPlastic", mul(r, rot_z(math.degrees(am) + 90)), collide=False))
    return model(name, kids)


GRAINY = {"Wood", "WoodPlanks", "Fabric", "Metal", "CorrodedMetal", "Slate", "Cobblestone", "Brick", "Sandstone",
          "Plaster", "Grass", "LeafyGrass", "Ground", "Sand"}


def toy_finish(node, recolor=None):
    """Re-finish a kit-built prop standing in the vale as smooth toy plastic: every grainy material
    goes to SmoothPlastic, and parts named in `recolor` take that colour. Geometry is untouched."""
    for c in node.get("children", ()):
        pr = c.get("properties", {})
        if pr.get("Material") in GRAINY:
            pr["Material"] = "SmoothPlastic"
        if recolor and c.get("name") in recolor:
            pr["Color"] = [_r(v / 255) for v in recolor[c["name"]]]
        toy_finish(c, recolor)
    return node


TOY_CHEST = {"Body": VIGA, "Lid": TIMBER, "BandL": IRON_DARK, "BandR": IRON_DARK, "Hilt0": IRON_DARK, "Hilt1": IRON_DARK,
             "Hilt2": IRON_DARK}


def lily_pads(name, cx, cz, radius, water_top, n, rng):
    kids, placed = [], []
    tries = 0
    while len(placed) < n and tries < n * 20:
        tries += 1
        a, d = rng.uniform(0, math.tau), rng.uniform(0.15, 0.85) * radius
        rr = rng.uniform(0.9, 1.6)
        x, z = cx + math.cos(a) * d, cz + math.sin(a) * d
        if any(math.hypot(x - px, z - pz) < rr + pr + 0.4 for px, pz, pr in placed):
            continue
        placed.append((x, z, rr))
        kids += disc(f"Pad{len(placed)}", x, z, rr, water_top + 0.1, 0.1, rng.choice([MOSS, BRIAR_CANOPY[2]]), "SmoothPlastic",
                     collide=False, layer="decal")
    return model(name, kids)


def reeds(name, x, z, rng, n=6):
    y = floor_at(x, z, BRIAR_Y)
    kids = []
    for k in range(n):
        h = rng.uniform(1.6, 3.2)
        ox, oz = rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8)
        kids.append(part(f"Reed{k}", (0.18, h, 0.18), (x + ox, y + h / 2, z + oz), rng.choice([MOSS, BRIAR_CANOPY[0]]), "SmoothPlastic",
                         mul(rot_y(rng.uniform(0, 90)), rot_z(rng.uniform(-6, 6))), collide=False, query=False, shadow=False))
    return model(name, kids)


# ── Briarwood woodland ────────────────────────────────────────────────────────
# The vale's trees are four species in three height tiers, all built from rounded leaf masses (a
# Part carrying a Sphere SpecialMesh is a textured ellipsoid, so a lobe can be wide and flat or
# tall and narrow) on round, tapering trunks whose feet WorldTerrain buries in soft root mounds:
#   * sun oaks, 30-46 studs: a leaning two-piece trunk, three roots, two limbs, and an umbrella
#     crown of seven overlapping lobes (cool beneath, warm where the sun catches it) 28-40 across,
#     so neighbouring crowns meet over the trails;
#   * firs, 36-54 studs: a straight red-brown bole under five scalloped tiers and a spire, the
#     lowest tier well above head height;
#   * lemon birches, 14-22 studs: pale slim trunks with small lime-to-golden crowns, the understory;
#   * young firs, 7-11 studs: the sapling layer.
# Under them: bush clusters (some lemon-yellow), fern clumps, and fallen mossy logs. The ground,
# paths, leaf litter, moss, root mounds and rocks are Terrain (WorldTerrain reads the ForestPlan
# this module writes), so nothing here is a floor or a rock.
# Toy-plastic palette: every green is one spring-green hue at three values (never pine, teal or
# olive), every bark a warm saturated caramel (never chocolate or grey).
OAK_BARK = BARK
OAK_BARK_DARK = BARK_DARK
FIR_BARK = (240, 146, 60)
BIRCH_BARK = hsv(40, 0.22, 1.0)  # birches keep a calm pale cream trunk against the caramel oaks
OAK_SHADE, OAK_MID, OAK_SUN = CANOPY["lime"]  # the default (lime) canopy triple


def fir_tones(fam):
    """Bottom tier to spire: the family's shade rising through its body to a pale-tinted tip."""
    shade, mid, sun = fam
    return [shade, blend(shade, mid, 0.5), mid, blend(mid, sun, 0.55)]


FIR_TONES = fir_tones(CANOPY["lime"])
BIRCH_TONES = [CANOPY["lime"][1], CANOPY["lime"][2], CANOPY["cream"][1], CANOPY["pink"][1]]  # sapling crowns
THICKET_TONES = [CANOPY["lime"][0], CANOPY["lime"][1], CANOPY["mint"][0], CANOPY["cyan"][1]]
SHRUB_TONES = [CANOPY["lime"][1], CANOPY["lime"][2], CANOPY["lime"][0], CANOPY["mint"][1]]
LEMON_BUSH = [hsv(52, 0.8, 1.0), hsv(48, 0.84, 0.98), hsv(54, 0.3, 1.0)]  # full-chroma lemon, a pale-lemon highlight
FERN_TONES = [hsv(150, 0.74, 0.92), hsv(144, 0.66, 0.97), hsv(156, 0.36, 1.0)]  # vivid mint-green pops, a pale tip
LOG_BARK = (246, 154, 66)


def ellipsoid(name, size, pos, color, material="SmoothPlastic", rot=None, **kw):
    """A smooth-plastic ellipsoid (Part + Sphere SpecialMesh). Always give it a small tilt: a level
    box's top face would read to the validator as a flat top that could z-fight."""
    kw.setdefault("collide", False)
    kw.setdefault("query", False)
    kw.setdefault("layer", "canopy")
    return part(name, size, pos, color, material, rot, children=[inst("Mesh", "SpecialMesh", {"MeshType": "Sphere"})], **kw)


def cyl(name, a, b, diam, color, material="SmoothPlastic", **kw):
    """Round log from a to b."""
    length = math.dist(a, b)
    centre = tuple((a[i] + b[i]) / 2 for i in range(3))
    kw.setdefault("layer", "tree")
    return part(name, (length, diam, diam), centre, color, material, mul(beam_rot(a, b), rot_z(90)), shape="Cylinder", **kw)


def tilt(rng, lo=3.0, hi=9.0):
    return mul(rot_y(rng.uniform(0, 360)), mul(rot_x(rng.uniform(lo, hi) * rng.choice((-1, 1))), rot_z(rng.uniform(-hi, hi))))


def jitter(c, rng, amt=7):
    """A colour nudged a few points in value and hue, so no two leaf masses match exactly."""
    v, g = rng.uniform(-amt, amt), rng.uniform(-amt * 0.5, amt * 0.5)
    return tuple(max(0, min(255, round(c[i] + v + (g if i == 1 else 0)))) for i in range(3))


def leaf_tone(dx, dy, dz, span, fam=None):
    """Underside in the family's shade, sun side and crown in its pale highlight (SUN_XZ points at
    the afternoon sun)."""
    shade, mid, sun = fam or CANOPY["lime"]
    h = math.hypot(dx, dz) or 1.0
    facing = (dx * SUN_XZ[0] + dz * SUN_XZ[1]) / h
    lift = dy / span + facing * 0.7
    return sun if lift > 0.45 else shade if lift < -0.35 else mid


def _roots(kids, x, y, z, r0, n, rng, reach=3.4, color=OAK_BARK_DARK):
    a0 = rng.uniform(0, math.tau)
    for k in range(n):
        a = a0 + k * math.tau / n + rng.uniform(-0.4, 0.4)
        rr = rng.uniform(0.8, 1.2) * reach * r0
        kids.append(cyl(f"Root{k}", (x + math.cos(a) * r0 * 0.3, y + r0 * 1.5, z + math.sin(a) * r0 * 0.3),
                        (x + math.cos(a) * rr, y - 0.5, z + math.sin(a) * rr), r0 * 0.75, color,
                        collide=False, query=False, shadow=False))


# ── Round-1 layout keeper ─────────────────────────────────────────────────────
# The vale's layout (every tree, bush and fern position) falls out of one shared random stream, so
# reshaping a species would reshuffle the whole wood. Each reshaped species therefore first draws
# exactly what its round-1 shape drew (the functions below, kept only for their draws; the parts
# they make are thrown away) and then builds its new shape from its own seeded stream. Tuning a
# shape never moves a tree.
_R1_FIVE = [(150, 198, 70), (174, 206, 66), (126, 182, 62), (140, 192, 66), (216, 204, 80)]  # round 1's birch tones


def _draws_briar_fir(name, x, z, rng, s=1.0, y=None):
    y = floor_at(x, z, BRIAR_Y) if y is None else y
    H = rng.uniform(40, 54) * s
    r0 = rng.uniform(0.95, 1.25) * min(s, 1.3)
    kids = [cyl("Bole", (x, y - 1.5, z), (x, y + H * 0.75, z), 2 * r0, FIR_BARK)]
    _roots(kids, x, y, z, r0, 3, rng, reach=3.0, color=FIR_BARK)
    # Seven whorls of branches, each overlapping the one below: wide and drooping low down,
    # narrowing to a spire, every one pushed a little off the bole and tipped, so the crown reads
    # as one scalloped cone rather than a stack of plates.
    n = 7
    cy = y + H * 0.34
    for i in range(n):
        t = i / (n - 1)
        w = H * (0.44 - 0.34 * t) * rng.uniform(0.82, 1.15)
        h = w * rng.uniform(0.42, 0.5)
        oa, od = rng.uniform(0, math.tau), rng.uniform(0.03, 0.08) * w
        kids.append(ellipsoid(f"Tier{i}", (w, h, w * rng.uniform(0.84, 0.96)), (x + math.cos(oa) * od, cy, z + math.sin(oa) * od),
                              FIR_TONES[min(3, (i * 4) // n + (i % 2))], rot=tilt(rng, 4, 11)))
        cy += h * rng.uniform(0.55, 0.66)
    kids.append(ellipsoid("Spire", (H * 0.06, H * 0.16, H * 0.06), (x, cy + H * 0.04, z), FIR_TONES[3], rot=tilt(rng, 1, 4)))
    return model(name, kids, attrs={"Species": "Fir"})


def _draws_briar_birch(name, x, z, rng, s=1.0, y=None):
    y = floor_at(x, z, BRIAR_Y) if y is None else y
    H = rng.uniform(14, 21) * s
    d = rng.uniform(0.85, 1.15)
    la, lean = rng.uniform(0, math.tau), rng.uniform(0.6, 2.0)
    top = (x + math.cos(la) * lean, y + H * 0.78, z + math.sin(la) * lean)
    fa = la + rng.uniform(1.6, 2.6)
    fork = (top[0] + math.cos(fa) * 2.2, y + H * 0.9, top[2] + math.sin(fa) * 2.2)
    kids = [cyl("Trunk", (x, y - 1.0, z), top, d, BIRCH_BARK, "Wood"),
            cyl("Fork", (x + (top[0] - x) * 0.55, y + H * 0.45, z + (top[2] - z) * 0.55), fork, d * 0.55, BIRCH_BARK, "Wood",
                collide=False, query=False, shadow=False)]
    tone = rng.choice(_R1_FIVE)
    for k, (px, pz, w) in enumerate(((top[0], top[2], 0.44), (fork[0], fork[2], 0.34), (top[0] + math.cos(la) * 2, top[2] + math.sin(la) * 2, 0.3))):
        w *= H
        kids.append(ellipsoid(f"Leaves{k}", (w, w * rng.uniform(0.8, 1.0), w * rng.uniform(0.8, 1.0)),
                              (px, y + H * (0.88 + 0.06 * k), pz), tone if k != 2 else rng.choice(_R1_FIVE), rot=tilt(rng)))
    return model(name, kids, attrs={"Species": "Birch"})


def _draws_young_fir(name, x, z, rng, s=1.0, y=None):
    y = floor_at(x, z, BRIAR_Y) if y is None else y
    H = rng.uniform(7, 11) * s
    kids = [cyl("Stem", (x, y - 0.8, z), (x, y + H * 0.8, z), 0.5 * s, FIR_BARK, collide=False, query=False, shadow=False)]
    for i in range(3):
        w = H * (0.66 - 0.19 * i) * rng.uniform(0.9, 1.1)
        oa, od = rng.uniform(0, math.tau), rng.uniform(0.05, 0.12) * w
        kids.append(ellipsoid(f"Tier{i}", (w, w * rng.uniform(0.4, 0.5), w * 0.9), (x + math.cos(oa) * od, y + H * (0.32 + 0.26 * i), z + math.sin(oa) * od),
                              FIR_TONES[i + 1], rot=tilt(rng, 6, 14), layer="prop", shadow=i == 0))
    return model(name, kids, attrs={"Species": "YoungFir"})


def _draws_sapling(name, x, z, rng, s=1.0, y=None):
    y = floor_at(x, z, BRIAR_Y) if y is None else y
    H = rng.uniform(6.5, 10) * s
    la, lean = rng.uniform(0, math.tau), rng.uniform(0.4, 1.4)
    top = (x + math.cos(la) * lean, y + H * 0.8, z + math.sin(la) * lean)
    kids = [cyl("Stem", (x, y - 0.8, z), top, 0.45 * s, OAK_BARK, collide=False, query=False, shadow=False)]
    tone = rng.choice(_R1_FIVE[:4] + [OAK_MID])
    for k in range(3):
        w = rng.uniform(0.46, 0.62) * H
        a = rng.uniform(0, math.tau)
        kids.append(ellipsoid(f"Leaves{k}", (w, w * rng.uniform(0.7, 0.9), w * 0.9),
                              (top[0] + math.cos(a) * w * 0.32, y + H * (0.52 + 0.16 * k), top[2] + math.sin(a) * w * 0.32),
                              tone, rot=tilt(rng), layer="prop", shadow=k == 0))
    return model(name, kids, attrs={"Species": "Sapling"})


def _draws_bush_clump(name, x, z, rng, s=1.0, lemon=False, y=None):
    y = floor_at(x, z, BRIAR_Y) if y is None else y
    tones = LEMON_BUSH if lemon else SHRUB_TONES
    kids = []
    for k in range(rng.randint(2, 3)):
        w = rng.uniform(3.0, 5.2) * s
        h = w * rng.uniform(0.55, 0.75)
        ox, oz = rng.uniform(-1.4, 1.4) * s, rng.uniform(-1.4, 1.4) * s
        kids.append(ellipsoid(f"Leaf{k}", (w, h, w * rng.uniform(0.8, 1.0)), (x + ox, y + h * 0.3, z + oz),
                              tones[k % len(tones)] if k else rng.choice(tones), rot=tilt(rng), shadow=False, layer="prop"))
    return model(name, kids)


def _keeps_layout(draws):
    def wrap(build):
        def planted(name, x, z, rng, *a, **kw):
            mark = len(REGISTRY)
            draws(name, x, z, rng, *a, **kw)
            del REGISTRY[mark:]
            return build(name, x, z, random.Random(f"{name}:{x:.2f}:{z:.2f}"), *a, **kw)
        planted.__name__ = build.__name__
        return planted
    return wrap


def briar_oak(name, x, z, rng, s=1.0, y=None, roots=3):
    y = floor_at(x, z, BRIAR_Y) if y is None else y
    H = rng.uniform(36, 48) * s
    C = rng.uniform(30, 38) * s  # crown scale: tall trunks, crowns no wider than before
    r0 = rng.uniform(1.3, 1.7) * min(s, 1.3)
    la, lean = rng.uniform(0, math.tau), rng.uniform(0.8, 2.6) * s
    top = (x + math.cos(la) * lean, y + H * 0.8, z + math.sin(la) * lean)
    kids = [cyl("Bole", (x, y - 1.5, z), top, 1.85 * r0, OAK_BARK)]
    _roots(kids, x, y, z, r0, roots, rng)
    cx, cy, cz = top[0], top[1] + C * 0.08, top[2]
    span = C * 0.12
    lobes = [("Canopy", 0.0, 0.0, 0.0, C * 0.42, C * 0.25)]
    ring = rng.randint(5, 6)
    a0 = rng.uniform(0, math.tau)
    for k in range(ring):
        a = a0 + k * math.tau / ring + rng.uniform(-0.3, 0.3)
        r = rng.uniform(0.2, 0.28) * C
        w = rng.uniform(0.26, 0.34) * C
        lobes.append((f"Leaves{k}", math.cos(a) * r, rng.uniform(-0.07, 0.05) * C, math.sin(a) * r, w, w * rng.uniform(0.56, 0.7)))
    a = rng.uniform(0, math.tau)
    lobes.append(("Crown", math.cos(a) * 0.06 * C, C * 0.13, math.sin(a) * 0.06 * C, C * 0.26, C * 0.18))
    for k in range(2):  # limbs from the trunk out to two ring lobes
        _, dx, dy, dz, _, _ = lobes[1 + k * (ring // 2)]
        kids.append(cyl(f"Limb{k}", (top[0], top[1] - C * 0.14, top[2]), (cx + dx * 0.7, cy + dy - 1, cz + dz * 0.7), r0 * 0.6,
                        OAK_BARK, collide=False, query=False, shadow=False))
    fam = canopy_of(name)
    for lname, dx, dy, dz, w, h in lobes:
        kids.append(ellipsoid(lname, (w, h, w * rng.uniform(0.85, 1.0)), (cx + dx, cy + dy, cz + dz), leaf_tone(dx, dy, dz, span, fam),
                              rot=tilt(rng)))
    return model(name, kids, attrs={"Species": "Oak"})


@_keeps_layout(_draws_briar_fir)
def briar_fir(name, x, z, rng, s=1.0, y=None):
    y = floor_at(x, z, BRIAR_Y) if y is None else y
    H = rng.uniform(40, 54) * s
    r0 = rng.uniform(0.95, 1.25) * min(s, 1.3)
    kids = [cyl("Bole", (x, y - 1.5, z), (x, y + H * 0.75, z), 2 * r0, FIR_BARK)]
    _roots(kids, x, y, z, r0, 3, rng, reach=3.0, color=FIR_BARK)
    # Seven whorls of branches, each overlapping the one below: wide and drooping low down,
    # narrowing to a spire, every one pushed a little off the bole and tipped, so the crown reads
    # as one scalloped cone rather than a stack of plates.
    # Five deep, rounded masses, each sunk more than half into the one below and pushed off the
    # bole by turns round a spiral, shaded in a smooth gradient: the outline is one tapering,
    # lumpy cone, with no flat disc or colour band at a tier to read as topiary.
    n = 5
    cy = y + H * 0.4
    oa = rng.uniform(0, math.tau)
    tones = fir_tones(canopy_of(name, CONIFER_MIX))
    for i in range(n):
        t = i / (n - 1)
        w = H * (0.46 - 0.3 * t) * rng.uniform(0.88, 1.1)
        h = w * rng.uniform(0.8, 0.95)
        oa += 2.4 + rng.uniform(-0.4, 0.4)
        od = rng.uniform(0.05, 0.11) * w
        f = t * (len(tones) - 1)
        lo = tones[int(f)]
        hi = tones[min(len(tones) - 1, int(f) + 1)]
        tone = tuple(round(lo[c] + (hi[c] - lo[c]) * (f - int(f))) for c in range(3))
        kids.append(ellipsoid(f"Tier{i}", (w, h, w * rng.uniform(0.8, 0.95)), (x + math.cos(oa) * od, cy, z + math.sin(oa) * od),
                              jitter(tone, rng, 5), rot=tilt(rng, 5, 12)))
        cy += h * rng.uniform(0.38, 0.44)
    kids.append(ellipsoid("Spire", (H * 0.06, H * 0.16, H * 0.06), (x, cy + H * 0.04, z), tones[3], rot=tilt(rng, 1, 4)))
    return model(name, kids, attrs={"Species": "Fir"})


@_keeps_layout(_draws_briar_birch)
def briar_birch(name, x, z, rng, s=1.0, y=None):
    """The understory broadleaf: a real leaning trunk (not a pale stick) that forks and rises into an
    irregular crown of three offset leaf masses in the canopy's own greens, hung low enough on the
    trunk that the wood runs up into the leaves instead of stopping under a ball."""
    y = floor_at(x, z, BRIAR_Y) if y is None else y
    H = rng.uniform(14, 21) * s
    d = rng.uniform(1.3, 1.7)
    la, lean = rng.uniform(0, math.tau), rng.uniform(0.6, 2.0)
    top = (x + math.cos(la) * lean, y + H * 0.66, z + math.sin(la) * lean)
    fa = la + rng.uniform(1.6, 2.6)
    fork = (top[0] + math.cos(fa) * H * 0.2, y + H * 0.74, top[2] + math.sin(fa) * H * 0.2)
    kids = [cyl("Trunk", (x, y - 1.2, z), top, d, BIRCH_BARK, "SmoothPlastic"),
            cyl("Fork", (x + (top[0] - x) * 0.5, y + H * 0.36, z + (top[2] - z) * 0.5), fork, d * 0.6, BIRCH_BARK, "SmoothPlastic",
                collide=False, query=False, shadow=False)]
    oa = fa + math.pi + rng.uniform(-0.6, 0.6)
    crown = ((top[0], top[2], 0.56, 0.78, 0.44), (fork[0], fork[2], 0.44, 0.8, 0.5),
             (top[0] + math.cos(oa) * H * 0.2, top[2] + math.sin(oa) * H * 0.2, 0.4, 0.7, 0.55))
    span = H * 0.3
    fam = canopy_of(name, UNDERSTORY_MIX)
    for k, (px, pz, w, fy, hr) in enumerate(crown):
        w *= H
        dx, dz = px - top[0], pz - top[2]
        kids.append(ellipsoid(f"Leaves{k}", (w, w * hr * rng.uniform(0.9, 1.1), w * rng.uniform(0.75, 0.95)),
                              (px, y + H * fy, pz), jitter(leaf_tone(dx, H * (fy - 0.75), dz, span, fam), rng), rot=tilt(rng, 4, 12)))
    return model(name, kids, attrs={"Species": "Birch"})


@_keeps_layout(_draws_young_fir)
def young_fir(name, x, z, rng, s=1.0, y=None):
    """Undergrowth thicket (the sapling layer's evergreen share): three loose, uneven leaf masses of
    different heights pushed off one another and sunk into the ground, never stacked on a stem."""
    y = floor_at(x, z, BRIAR_Y) if y is None else y
    H = rng.uniform(5.5, 8.5) * s
    a0 = rng.uniform(0, math.tau)
    kids = []
    for k, (w, h, off, da, sink) in enumerate(((0.8, 0.95, 0.0, 0.0, 0.34), (0.72, 0.6, 0.5, 0.0, 0.28),
                                                 (0.56, 0.48, 0.55, rng.uniform(1.8, 2.8), 0.24))):
        w *= H * rng.uniform(0.85, 1.15)
        h *= H * rng.uniform(0.85, 1.15)
        a = a0 + da
        kids.append(ellipsoid(f"Leaf{k}", (w, h, w * rng.uniform(0.6, 0.9)),
                              (x + math.cos(a) * off * H * 0.6, y + h * sink, z + math.sin(a) * off * H * 0.6),
                              jitter(rng.choice(THICKET_TONES), rng), "SmoothPlastic", rot=tilt(rng, 6, 18), layer="prop", shadow=k == 0))
    return model(name, kids, attrs={"Species": "Thicket"})


@_keeps_layout(_draws_sapling)
def sapling(name, x, z, rng, s=1.0, y=None):
    """A young broadleaf: a thin leaning stem and two or three small leaf masses."""
    y = floor_at(x, z, BRIAR_Y) if y is None else y
    H = rng.uniform(6.5, 10) * s
    la, lean = rng.uniform(0, math.tau), rng.uniform(0.4, 1.4)
    top = (x + math.cos(la) * lean, y + H * 0.62, z + math.sin(la) * lean)
    kids = [cyl("Stem", (x, y - 0.8, z), top, 0.55 * s, OAK_BARK, collide=False, query=False, shadow=False)]
    tone = rng.choice(BIRCH_TONES)
    a0 = rng.uniform(0, math.tau)
    for k in range(3):  # a loose, lopsided spray round the stem's head, not balls stacked on it
        w = rng.uniform(0.5, 0.66) * H * (1.0 if k == 0 else 0.8)
        a = a0 + k * rng.uniform(1.8, 2.6)
        off = 0.0 if k == 0 else rng.uniform(0.4, 0.55) * w
        kids.append(ellipsoid(f"Leaves{k}", (w, w * rng.uniform(0.55, 0.75), w * rng.uniform(0.7, 0.9)),
                              (top[0] + math.cos(a) * off, y + H * (0.7 - 0.1 * k + rng.uniform(-0.04, 0.04)), top[2] + math.sin(a) * off),
                              jitter(tone, rng), rot=tilt(rng), layer="prop", shadow=k == 0))
    return model(name, kids, attrs={"Species": "Sapling"})


@_keeps_layout(_draws_bush_clump)
def bush_clump(name, x, z, rng, s=1.0, lemon=False, y=None):
    """Loose undergrowth: two or three uneven leaf masses (one taller, the others spread low and
    pushed off it) sunk well into the ground, in one canopy family's smooth-plastic tones."""
    y = floor_at(x, z, BRIAR_Y) if y is None else y
    fam = canopy_of(name, (("lime", 0.4), ("pink", 0.2), ("mint", 0.2), ("lavender", 0.2)))
    tones = LEMON_BUSH if lemon else (fam[1], fam[2], fam[0], fam[1])
    kids = []
    a0 = rng.uniform(0, math.tau)
    for k in range(rng.randint(2, 3)):
        w = rng.uniform(3.4, 5.4) * s * (1.0 if k == 0 else rng.uniform(0.6, 0.85))
        h = w * (rng.uniform(0.8, 1.05) if k == 0 else rng.uniform(0.45, 0.65))
        a = a0 + k * rng.uniform(1.8, 2.6)
        off = 0.0 if k == 0 else rng.uniform(1.6, 2.6) * s
        kids.append(ellipsoid(f"Leaf{k}", (w, h, w * rng.uniform(0.6, 0.9)), (x + math.cos(a) * off, y + h * 0.2, z + math.sin(a) * off),
                              jitter(tones[k % len(tones)] if k else rng.choice(tones), rng), "SmoothPlastic", rot=tilt(rng, 6, 16),
                              shadow=False, layer="prop"))
    return model(name, kids)


def fern_clump(name, x, z, rng, s=1.0, y=None):
    """Five fronds arching out of one crown."""
    y = floor_at(x, z, BRIAR_Y) if y is None else y
    kids = []
    a0 = rng.uniform(0, math.tau)
    tone = rng.choice(FERN_TONES)
    for k in range(5):
        a = a0 + k * math.tau / 5 + rng.uniform(-0.3, 0.3)
        L = rng.uniform(3.4, 4.6) * s
        p = math.radians(rng.uniform(28, 46))
        d = (math.cos(a) * math.cos(p), math.sin(p), math.sin(a) * math.cos(p))
        base = (x + d[0] * 0.3, y + 0.1, z + d[2] * 0.3)
        tip = tuple(base[i] + d[i] * L for i in range(3))
        centre = tuple((base[i] + tip[i]) / 2 for i in range(3))
        kids.append(part(f"Frond{k}", (0.22 * s, L, 1.3 * s), centre, tone if k % 2 else FERN_TONES[(k // 2) % 3], "SmoothPlastic",
                         beam_rot(base, tip), collide=False, query=False, shadow=False, layer="prop",
                         children=[inst("Mesh", "SpecialMesh", {"MeshType": "Sphere"})]))
    return model(name, kids)


def mossy_log(name, x, z, yaw, length, rng, y=None):
    y = floor_at(x, z, BRIAR_Y) if y is None else y
    d = rng.uniform(1.6, 2.2)
    dx, dz = math.cos(math.radians(yaw)) * length / 2, math.sin(math.radians(yaw)) * length / 2
    a, b = (x - dx, y + d * 0.32, z - dz), (x + dx, y + d * 0.32 + rng.uniform(-0.2, 0.3), z + dz)
    return model(name, [
        cyl("Log", a, b, d, LOG_BARK, collide=False, shadow=False),
        ellipsoid("Moss", (length * 0.6, d * 0.5, d * 0.9), (x, y + d * 0.72, z), OAK_SHADE, "SmoothPlastic",
                  mul(rot_y(-yaw), rot_x(4)), shadow=False, layer="prop"),
    ])


# Toy stone: calm near-white sky-blue tints (PS99's pale walkway stone), the quiet surface the
# candy canopies pop against; the deepest is the same blue one step down, never grey.
BOULDER_GREYS = [hsv(222, 0.18, 1.0), hsv(224, 0.26, 0.97), hsv(216, 0.1, 1.0)]


def boulder(name, x, z, r, rng, collide=True, y=None):
    """A grey boulder half sunk in the ground, tipped, with a smaller stone leaning on it when it
    is big enough. WorldTerrain heaps leaf cover round its foot (the plan's rock entry)."""
    y = floor_at(x, z, BRIAR_Y) if y is None else y
    w, h, d = 2 * r * rng.uniform(0.95, 1.2), r * rng.uniform(1.1, 1.4), 2 * r * rng.uniform(0.75, 0.95)
    rot = mul(rot_y(rng.uniform(0, 180)), mul(rot_x(rng.uniform(6, 14) * rng.choice((-1, 1))), rot_z(rng.uniform(-12, 12))))
    kids = [part("Rock", (w, h, d), (x, y + h * 0.04, z), rng.choice(BOULDER_GREYS), "SmoothPlastic", rot, collide=collide, layer="rock")]
    if r > 2.6:
        a = rng.uniform(0, math.tau)
        s2 = rng.uniform(0.45, 0.6)
        rot2 = mul(rot_y(rng.uniform(0, 180)), mul(rot_x(rng.uniform(10, 22)), rot_z(rng.uniform(-15, 15))))
        kids.append(part("Stone", (w * s2, h * s2, d * s2), (x + math.cos(a) * r * 0.95, y + h * s2 * 0.05, z + math.sin(a) * r * 0.95),
                         rng.choice(BOULDER_GREYS), "SmoothPlastic", rot2, collide=False, shadow=False, layer="rock"))
    return model(name, kids)


def clearance_ok(mark, points):
    """The validator's camera-clearance rule, applied while planting: nothing opaque with its
    bottom 8-28 studs above a spawn (12 studs round it) or an arrival (8 studs)."""
    for e in REGISTRY[mark:]:
        if e["transparency"] >= 0.9 and not e["collide"]:
            continue
        ext = [sum(abs(e["rot"][i][j]) * e["size"][j] / 2 for j in range(3)) for i in range(3)]
        x0, x1 = e["pos"][0] - ext[0], e["pos"][0] + ext[0]
        z0, z1 = e["pos"][2] - ext[2], e["pos"][2] + ext[2]
        bottom, top = e["pos"][1] - ext[1], e["pos"][1] + ext[1]
        for px, pz, fy, radius in points:
            dx = max(x0 - px, 0, px - x1)
            dz = max(z0 - pz, 0, pz - z1)
            if math.hypot(dx, dz) <= radius and fy + 8 < bottom < fy + 28 and top > fy + 8:
                return False
    return True


def trail_dist(x, z, trails):
    best = 1e9
    for pts, hw in trails:
        for i in range(len(pts) - 1):
            best = min(best, seg_dist(x, z, pts[i], pts[i + 1]) - hw)
    return best


def plant_woodland(rng, inside, trails, spawns, arrivals, clear, x_rng, z_rng):
    """Plant the vale: clumped canopy trees (oak and fir in patches), birches and young firs in the
    gaps, and bushes, ferns and logs gathered round trunks and along the trail verges. Returns the
    visual models and the plan entries WorldTerrain needs (trunk feet and rocks)."""
    visual, feet, rocks = [], [], []
    y = BRIAR_Y
    guard = [(sx, sz, y, 12) for sx, sz in spawns] + [(ax, az, y, 8) for ax, az in arrivals]

    def near_spawn(x, z, r):
        return any(math.hypot(x - sx, z - sz) < r for sx, sz in spawns) or any(math.hypot(x - ax, z - az) < r for ax, az in arrivals)

    # Clumps: each has a centre, a reach and a leaning toward firs or oaks, so species gather.
    clumps = []
    for _ in range(34):
        cx, cz = rng.uniform(*x_rng), rng.uniform(*z_rng)
        clumps.append((cx, cz, rng.uniform(16, 30), rng.random()))

    def clump_at(x, z):
        best, share = 0.0, 0.5
        for cx, cz, r, fir in clumps:
            w = math.exp(-((x - cx) ** 2 + (z - cz) ** 2) / (r * r))
            if w > best:
                best, share = w, fir
        return best, share

    tall = []  # (x, z, radius)
    tries = 0
    while len(tall) < 118 and tries < 30000:
        tries += 1
        x, z = rng.uniform(*x_rng), rng.uniform(*z_rng)
        dens, fir_share = clump_at(x, z)
        td = trail_dist(x, z, trails)
        verge = 1.0 if 2.5 < td < 9 else 0.0  # line the trails, so crowns meet over them
        if rng.random() > 0.18 + 0.75 * dens + 0.45 * verge:
            continue
        if not inside(x, z, 5) or not clear_of(x, z, clear):
            continue
        fir = rng.random() < 0.2 + 0.7 * fir_share
        if td < (7.0 if fir else 2.6):
            continue
        if near_spawn(x, z, 21 if fir else 9):
            continue
        gap = 8.5 if fir else 10.5
        if any(math.hypot(x - px, z - pz) < max(gap, pr + 4) for px, pz, pr in tall):
            continue
        mark = len(REGISTRY)
        name = f"{'Fir' if fir else 'Oak'}{len(tall):03d}"
        placed = None
        for s in ((1.0, 1.15, 1.3) if not fir else (1.0,)):
            node = (briar_fir if fir else briar_oak)(name, x, z, rng, s=s * rng.uniform(0.9, 1.12))
            if clearance_ok(mark, guard):
                placed = node
                break
            del REGISTRY[mark:]
        if not placed:
            continue
        visual.append(placed)
        tall.append((x, z, 3.0 if fir else 5.0))
        r0 = placed["children"][0]["properties"]["Size"][1] / 2
        feet.append([_r(x), _r(z), _r(r0), 2 if fir else 1])

    mid = []
    tries = 0
    while len(mid) < 128 and tries < 20000:
        tries += 1
        x, z = rng.uniform(*x_rng), rng.uniform(*z_rng)
        dens, fir_share = clump_at(x, z)
        if rng.random() > 0.3 + 0.7 * dens:
            continue
        if not inside(x, z, 4) or not clear_of(x, z, clear) or trail_dist(x, z, trails) < 3.2 or near_spawn(x, z, 21):
            continue
        if any(math.hypot(x - px, z - pz) < 5.5 for px, pz, _ in tall) or any(math.hypot(x - px, z - pz) < 6 for px, pz in mid):
            continue
        mark = len(REGISTRY)
        young = rng.random() < 0.3 + 0.4 * fir_share
        maker = (young_fir if rng.random() < 0.25 + 0.6 * fir_share else sapling) if young else briar_birch
        node = maker(f"{'Young' if young else 'Birch'}{len(mid):03d}", x, z, rng)
        if not clearance_ok(mark, guard):
            del REGISTRY[mark:]
            continue
        visual.append(node)
        mid.append((x, z))
        if not young:
            feet.append([_r(x), _r(z), 0.5, 3])

    # Ground layer: bushes and ferns gathered at trunk feet and along the verges.
    anchors = [(px, pz, 3.5, 7.0) for px, pz, _ in tall] + [(px, pz, 2.0, 5.0) for px, pz in mid]
    low = []

    def free_low(x, z, r):
        if not inside(x, z, 3) or not clear_of(x, z, clear) or trail_dist(x, z, trails) < 1.2 or near_spawn(x, z, 6):
            return False
        if any(math.hypot(x - px, z - pz) < 2.6 for px, pz, _ in tall):
            return False
        return not any(math.hypot(x - px, z - pz) < r + pr for px, pz, pr in low)

    tries = 0
    n_bush = n_fern = 0
    hummocks = []  # [x, z, radius]: moss hummocks WorldTerrain raises (free), in place of some bushes
    while (n_bush < 110 or n_fern < 75) and tries < 30000:
        tries += 1
        roll = rng.random()
        if roll < 0.56:
            ax, az, r_in, r_out = rng.choice(anchors)
            a, d = rng.uniform(0, math.tau), r_in + (r_out - r_in) * rng.random() ** 0.7
            x, z = ax + math.cos(a) * d, az + math.sin(a) * d
        elif roll < 0.76:  # the open wood between the trunks, thinning away from them, so the
            # undergrowth carries through the middle ground instead of stopping at the trees
            ax, az, r_in, r_out = rng.choice(anchors)
            a, d = rng.uniform(0, math.tau), r_out + rng.expovariate(1 / 7.0)
            x, z = ax + math.cos(a) * d, az + math.sin(a) * d
        else:  # a verge: pick a trail point and step off it
            pts, hw = rng.choice(trails)
            i = rng.randrange(len(pts) - 1)
            t = rng.random()
            px = pts[i][0] + (pts[i + 1][0] - pts[i][0]) * t
            pz = pts[i][1] + (pts[i + 1][1] - pts[i][1]) * t
            a = rng.uniform(0, math.tau)
            d = hw + rng.uniform(1.6, 4.5)
            x, z = px + math.cos(a) * d, pz + math.sin(a) * d
        fern = n_fern < 75 and (n_bush >= 110 or rng.random() < 0.42)
        r = 2.6 if fern else 3.0
        if not free_low(x, z, r):
            continue
        low.append((x, z, r))
        if fern:
            visual.append(fern_clump(f"Fern{n_fern:03d}", x, z, rng, s=rng.uniform(0.8, 1.2)))
            n_fern += 1
        else:
            s_b, lemon = rng.uniform(0.75, 1.25), rng.random() < 0.1
            if not lemon and n_bush % 5 in (1, 3):  # two in five: a mossy hummock of the ground itself
                hummocks.append([_r(x), _r(z), _r(3.4 + 1.6 * s_b)])
            else:
                visual.append(bush_clump(f"Bush{n_bush:03d}", x, z, rng, s=s_b, lemon=lemon))
            n_bush += 1

    # Fallen logs in the deeper wood, and boulders among the trunks.
    n_log, tries = 0, 0
    while n_log < 10 and tries < 4000:
        tries += 1
        x, z = rng.uniform(*x_rng), rng.uniform(*z_rng)
        L = rng.uniform(8, 13)
        if not inside(x, z, L / 2 + 3) or not clear_of(x, z, clear) or trail_dist(x, z, trails) < L / 2 + 1.5 or near_spawn(x, z, 14):
            continue
        if any(math.hypot(x - px, z - pz) < L / 2 + 3 for px, pz, _ in tall):
            continue
        visual.append(mossy_log(f"FallenLog{n_log:02d}", x, z, rng.uniform(0, 180), L, rng))
        low.append((x, z, L / 2))
        n_log += 1
    n_rock, tries = 0, 0
    while n_rock < 30 and tries < 6000:
        tries += 1
        if rng.random() < 0.6:
            ax, az, _ = rng.choice(tall)
            a = rng.uniform(0, math.tau)
            x, z = ax + math.cos(a) * rng.uniform(4.5, 9), az + math.sin(a) * rng.uniform(4.5, 9)
        else:
            x, z = rng.uniform(*x_rng), rng.uniform(*z_rng)
        r = rng.uniform(1.8, 3.6)
        if not inside(x, z, r + 2) or not clear_of(x, z, clear) or trail_dist(x, z, trails) < r + 1.5 or near_spawn(x, z, r + 9):
            continue
        if any(math.hypot(x - px, z - pz) < r + 2.5 for px, pz, _ in tall) or any(math.hypot(x - px, z - pz) < r + pr for px, pz, pr in low):
            continue
        rocks.append([_r(x), _r(z), _r(r), 1])
        low.append((x, z, r))
        n_rock += 1
    return visual, feet, rocks, hummocks


BRIAR_TRAILS = {
    # Packed-earth routes (x, z). Entrance → Bramble Hollow fork; east to the Mirror Pool; west
    # through Thornbreak to Hollow Rest, on to the chapel and the Warden's Grove. Three more
    # routes make the vale a network rather than a corridor: the Old Road straight down the
    # middle, the Sunken Path along the pool's west shore to the chapel, and the Rootwalk, an
    # outer loop from the graveyard round behind the grove to the pool.
    "Entrance": [(0, 474), (0, 520), (-2, 545), (2, 562)],
    "EastFork": [(2, 562), (24, 586), (48, 612), (64, 628)],
    "WestFork": [(2, 562), (-24, 590), (-48, 620), (-64, 648)],
    "Thornbreak": [(-64, 648), (-78, 680), (-72, 712)],
    "Graveyard": [(-72, 712), (-96, 724), (-104, 760), (-80, 770), (-48, 776)],
    "Chapel": [(-48, 776), (-18, 790), (0, 792), (0, 810), (0, 832)],
    "Grove": [(0, 832), (0, 852)],
    "OldRoad": [(24, 586), (16, 640), (10, 690), (-6, 736), (-30, 784)],
    "SunkenPath": [(64, 628), (58, 652), (62, 684), (80, 708), (88, 736), (80, 764), (58, 788), (30, 796), (6, 792)],
    "Rootwalk": [(-104, 760), (-102, 806), (-96, 852), (-64, 892), (-30, 924), (30, 924), (64, 892), (96, 852),
                 (100, 806), (92, 770), (88, 736)],
}
# Each trail's first leg height must differ from the leg(s) it joins; where a trail ends on
# another, its last leg must differ too (see earth_trail).
BRIAR_TRAIL_PHASE = {"Entrance": 0, "EastFork": 0, "WestFork": 1, "Thornbreak": 1, "Graveyard": 0, "Chapel": 1, "Grove": 2,
                     "OldRoad": 2, "SunkenPath": 1, "Rootwalk": 0}

BRIAR_SPAWNS = [
    # id, archetype, level, role, (x, z), leash. Difficulty climbs with depth (+Z): Lv 9 at the
    # Hollow, Lv 14 on the Rootwalk behind the grove. Slots sit 20+ studs from every tree (camera
    # clearance), clear of walls and boulders, 40+ from both waystone arrivals, 20+ from the
    # gate safe zone. [TUNING]
    # Bramble Hollow (z 570-630)
    ("BW_T1", "ThornStalker", 9, "minion", (-14, 576), 20),
    ("BW_T2", "ThornStalker", 9, "minion", (24, 602), 20),
    ("BW_T3", "ThornStalker", 10, "minion", (-4, 622), 20),
    ("BW_T4", "ThornStalker", 10, "minion", (66, 626), 18),
    # Old Road (z 640-710)
    ("BW_M1", "ThornStalker", 10, "minion", (18, 646), 20),
    ("BW_M2", "BriarBrute", 11, "minion", (14, 684), 20),
    ("BW_M3", "ThornStalker", 11, "minion", (0, 708), 20),
    # Thornbreak (z 640-690)
    ("BW_T5", "ThornStalker", 10, "minion", (-94, 646), 20),
    ("BW_B1", "BriarBrute", 11, "minion", (-70, 664), 20),
    ("BW_T6", "ThornStalker", 11, "minion", (-50, 686), 20),
    # Hollow Rest and the Sunken Path (z 715-765)
    ("BW_B2", "BriarBrute", 12, "minion", (-96, 716), 20),
    ("BW_B3", "BriarBrute", 12, "minion", (-46, 720), 20),
    ("BW_P1", "ThornStalker", 12, "minion", (84, 722), 20),
    ("BW_P2", "BriarBrute", 12, "minion", (78, 758), 20),
    # Chapel approaches (z 770-800)
    ("BW_C1", "ThornStalker", 13, "minion", (-34, 770), 20),
    ("BW_C2", "BriarBrute", 13, "minion", (50, 796), 20),
    # The grotto behind the Mirror Pool's waterfall
    ("BW_E1", "BriarBrute", 13, "elite", (127, 655), 12),
    # Rootwalk: the deep loop round the grove (z 825-930)
    ("BW_W1", "ThornStalker", 13, "minion", (-98, 828), 20),
    ("BW_W2", "BriarBrute", 14, "elite", (-84, 876), 22),
    ("BW_K1", "ThornStalker", 14, "minion", (-40, 926), 20),
    ("BW_K2", "ThornStalker", 14, "minion", (40, 924), 20),
    ("BW_X1", "ThornStalker", 13, "minion", (98, 828), 20),
    ("BW_X2", "BriarBrute", 14, "elite", (84, 876), 22),
    ("BW_BOSS", "RootWarden", 14, "boss", (0, 872), 50),
]
BRIAR_ARRIVALS = {"BriarGate": (0, 500), "GroveEdge": (10, 782)}  # 12+ studs from their waystone tips


def build_briarwood(rng):
    global AUTO_GROUND
    AUTO_GROUND = True
    Y = BRIAR_Y
    x0, x1 = BRIAR_X[0] - 6, GROTTO[1] + 6
    z0, z1 = BRIAR_Z
    hx0, hx1, hz0, hz1 = POOL_HOLE
    # The floors stay as collision (and enemy ground raycasts); WorldTerrain lays the visible
    # ground over them and hides them.
    ground = [
        slab("BriarFloorN", x0, x1, z0, hz0, Y, GRASS_DEEP, "SmoothPlastic"),
        slab("BriarFloorS", x0, x1, hz1, z1 + 2, Y, GRASS_DARK, "SmoothPlastic"),
        slab("BriarFloorW", x0, hx0, hz0, hz1, Y, GRASS_DARK, "SmoothPlastic"),
        slab("BriarFloorE", hx1, x1, hz0, hz1, Y, GRASS_DARK, "SmoothPlastic"),
    ]
    ground += disc("PoolBed", POOL[0], POOL[1], 23.5, Y - 1.0, 1.0, GROUND_TAN, "SmoothPlastic")
    for row in range(4):  # Hollow Rest: four shallow mossy terraces climbing away from the fence
        ground.append(slab(f"GraveTerrace{row}", -88, -52, 728 + row * 6, 734 + row * 6, Y + 0.4 * (row + 1), GRASS_DARK, "SmoothPlastic"))
    ground += disc("GroveFloor", GROVE[0], GROVE[1], GROVE[2], Y + 0.25, 0.5, GROUND_TAN, "SmoothPlastic")
    visual, proxies = [], []
    rocks = []  # [x, z, radius, collide]: boulders, planted last (WorldTerrain beds each in leaf cover)

    def terrain_rock(x, z, s, collide=True):  # a boulder, placed after the planting
        rocks.append([_r(x), _r(z), _r(1.5 * s), 1 if collide else 0])

    # Perimeter: the rock walls are Terrain now (WorldTerrain sculpts wooded slopes and scarps
    # behind this line); map_forge keeps only their invisible proxies. The play area is on the
    # left of each run.
    outline = [(-16, 472), (-16, 540), (-60, 556), (-100, 600), (BRIAR_X[0], 640), (BRIAR_X[0], 900), (-60, 940),
               (60, 940), (BRIAR_X[1], 900), (BRIAR_X[1], 720), (BRIAR_X[1], GROTTO[3]), (GROTTO[1], GROTTO[3]),
               (GROTTO[1], GROTTO[2]), (BRIAR_X[1], GROTTO[2]), (BRIAR_X[1], 600), (100, 560), (60, 545), (16, 540), (16, 472)]
    for i in range(len(outline) - 1):
        mark = len(REGISTRY)
        _, proxy = cliff_run(f"BriarCliff{i:02d}", outline[i], outline[i + 1], 1, Y, 46, BRIAR_ROCK, BRIAR_ROCK_DARK, rng,
                             depth=14, material="Slate", chunk=(8, 14))
        REGISTRY[mark:] = [e for e in REGISTRY[mark:] if e["layer"] == "proxy"]
        proxies.append(proxy)

    keep = [("trail", pts, 4.6) for pts in BRIAR_TRAILS.values()]
    keep += [(x, z, 21) for _, _, _, _, (x, z), _ in BRIAR_SPAWNS]
    keep += [(x, z, 17) for (x, z) in BRIAR_ARRIVALS.values()]
    keep += [(POOL[0], POOL[1], 26), (GROVE[0], GROVE[1], GROVE[2] + 6), (-70, 742, 26), (0, 800, 18)]

    def inside_outline(x, z, margin):
        if not (x0 + margin < x < BRIAR_X[1] - margin and z0 + margin < z < z1 - margin):
            return False
        for i in range(len(outline) - 1):
            if seg_dist(x, z, outline[i], outline[i + 1]) < margin:
                return False
        if x > 16 + margin and z < 545 + margin:  # the corridor funnels: nothing beyond its walls
            return False
        if x < -16 - margin and z < 545 + margin:
            return False
        return True

    props_mark = len(REGISTRY)
    # Entrance road: sign, waystone, quarry-stone transition.
    visual.append(hanging_sign("BriarwoodSign", -8, 486, yaw_facing(-1, 0), "Briarwood", "Lv 9+"))
    visual.append(waystone("BriarGateWaystone", "BriarGate", 13, 0, 500, glow=BRIAR_GLOW))
    for k, (x, z, s) in enumerate(((-13, 478, 1.0), (13, 482, 0.8), (-12, 496, 0.7), (14, 512, 0.9))):
        visual.append(part(f"QuarryStone{k}", (5 * s, 2.2 * s, 4 * s), (x, Y + 1.1 * s - 0.1, z), SAND, "SmoothPlastic",
                           rot_y(rng.uniform(0, 90)), collide=False, layer="rock"))

    # Bramble Hollow: the road forks around gnarled trees between broken walls.
    visual.append(ruin_wall("HollowWallW", -34, 570, 20, 5, 2, rng))
    visual.append(ruin_wall("HollowWallE", 36, 614, -80, 5, 1, rng))
    visual.append(ruin_wall("HollowWallS", -36, 608, -10, 5, 2, rng))
    visual.append(toy_finish(fingerpost("HollowPost", 8, Y, 566, [("Mirror Pool", yaw_facing(1, 1), 8.6),
                                                                   ("Hollow Rest", yaw_facing(-1, 1), 7.2),
                                                                   ("Iron Lowlands", yaw_facing(0, -1), 5.8)])))
    for x, z in ((-24, 584), (30, 578), (-30, 626), (34, 618)):
        terrain_rock(x, z, rng.uniform(0.9, 1.4))
    for k, (x, z) in enumerate(((-36, 592), (38, 600))):
        visual.append(stump(f"HollowStump{k}", x, Y, z, rng))

    # Mirror Pool oasis: still water in a sunken basin ringed with mossy boulders and reeds, fed by
    # the big waterfall off the east wall, a chest half-buried on the near shore. Behind the sheet,
    # the grotto: a pocket in the cliff with the vale's elite and its cache.
    px, pz, pr = POOL
    visual.append(model("MirrorPool", disc("Water", px, pz, pr, Y - 0.3, 0.5, POOL_WATER, "Glass", collide=False, layer="decal")
                        + [part("Glow", (0.5, 0.5, 0.5), (px, Y - 0.2, pz), (255, 255, 255), transparency=1, collide=False,
                                query=False, shadow=False, children=[light(24, 0.5, (140, 200, 190))])]))
    visual.append(lily_pads("LilyPads", px, pz, pr, Y - 0.3, 12, rng))
    for k in range(17):
        a = k * math.tau / 17
        if 2.8 < a < 3.9 or a < 0.35 or a > 6.0:  # open to the Sunken Path on the west shore and at the waterfall's foot
            continue
        terrain_rock(px + math.cos(a) * 18.2, pz + math.sin(a) * 17.4, rng.uniform(0.9, 1.7))
    for k, (x, z) in enumerate(((70, 640), (98, 636), (100, 676), (72, 682), (52, 646))):
        visual.append(reeds(f"PoolReeds{k}", x, z, rng))
    visual.append(model("BuriedChest", [toy_finish(chest("Chest", 52, Y - 0.55, 672, yaw_facing(1, -0.3), rng=rng), TOY_CHEST),
                                        part("Mound", (5.2, 0.6, 3.8), (52, Y + 0.3, 672), EARTH, "SmoothPlastic", rot_y(-14),
                                             collide=False, query=False, layer="decal")]))
    visual.append(briar_fall("MirrorFall", BRIAR_X[1] + 0.6, pz, yaw_facing(-1, 0), 27, 11, rng, lip_bottom=Y + 29))
    visual.append(model("Grotto", [
        toy_finish(chest("Cache", 130, Y, 652, yaw_facing(-1, 0), open_lid=True, rng=rng), TOY_CHEST),
        part("CacheLantern", (0.9, 1.2, 0.9), (131, Y + 5.4, 659), LANTERN, "Neon", collide=False, query=False, shadow=False,
             transparency=0.2, children=[light(16, 0.9)]),
        part("LanternHook", (0.3, 3.0, 0.3), (131, Y + 7.5, 659), BRIAR_IRON, "SmoothPlastic", collide=False, query=False),
        part("GrottoRoof", (GROTTO[1] - GROTTO[0] + 8, 6, GROTTO[3] - GROTTO[2] + 4), ((GROTTO[0] + GROTTO[1]) / 2 + 2, Y + 34,
                                                                                    (GROTTO[2] + GROTTO[3]) / 2),
             BRIAR_ROCK_DARK, "SmoothPlastic", collide=False, layer="cliff"),
    ]))
    terrain_rock(121, 651, 0.8)

    # Thornbreak: a rougher second clearing, stumps and boulders, the brute's ground.
    for x, z in ((-96, 668), (-46, 656), (-84, 700), (-56, 704)):
        terrain_rock(x, z, rng.uniform(1.0, 1.6))
    for k, (x, z) in enumerate(((-100, 688), (-40, 668))):
        visual.append(stump(f"ThornStump{k}", x, Y, z, rng))
    visual.append(ruin_wall("ThornWall", -104, 660, 70, 4, 1, rng))

    # Old Road camp and the Rootwalk's deep camps: rougher ground, stumps and boulders.
    for x, z, s in ((28, 702, 1.2), (-10, 664, 1.0), (-110, 848, 1.3), (110, 846, 1.3), (-2, 934, 0.8),
                    (-62, 908, 1.0), (62, 908, 1.0)):
        terrain_rock(x, z, s)
    for k, (x, z) in enumerate(((26, 724), (-108, 800), (108, 800))):
        visual.append(stump(f"CampStump{k}", x, Y, z, rng))

    # Hollow Rest: headstones on the terraces, a broken picket fence along the front, the old
    # boundary wall behind, and the small cascade dropping off the west wall into a stream.
    for row in range(4):
        for col in range(5):
            visual.append(headstone(f"Headstone{row}{col}", -82 + col * 6 + rng.uniform(-0.3, 0.3), 731 + row * 6, rng))
    visual.append(iron_fence("GraveFence", (-92, 724.5), (-48, 724.5), rng, gaps=((6, 10), (24, 30))))
    visual.append(ruin_wall("GraveWall", -92, 758, 0, 12, 2, rng))
    visual.append(hanging_sign("GraveSign", -36, 740, yaw_facing(-1, 0), "Hollow Rest", "Rest quietly"))
    visual.append(briar_fall("GraveFall", BRIAR_X[0] - 0.6, 744, yaw_facing(1, 0), 13, 6, rng))
    visual.append(model("GraveStream", [
        part("StreamA", (16, 0.16, 5), (-108, Y + 0.08, 745), POOL_WATER, "Glass", rot_y(-8), collide=False, query=False,
             transparency=0.3, layer="decal"),
        part("StreamB", (14, 0.22, 4.4), (-95, Y + 0.11, 751), POOL_WATER, "Glass", rot_y(-30), collide=False, query=False,
             transparency=0.3, layer="decal"),
        part("StreamC", (12, 0.16, 3.6), (-86, Y + 0.08, 759), POOL_WATER, "Glass", rot_y(-55), collide=False, query=False,
             transparency=0.3, layer="decal"),
    ]))
    for x, z in ((-106, 736), (-100, 756), (-92, 764)):
        terrain_rock(x, z, 0.8, collide=False)

    # Ruined chapel: broken walls, the intact arch the trail passes through, roots wrenching the
    # masonry apart, and the vale's second waystone at the grove's edge.
    visual.append(stone_arch("ChapelArch", 0, 800, 0))
    visual.append(ruin_wall("ChapelWallW", -20, 800, 0, 4, 4, rng))
    visual.append(ruin_wall("ChapelWallE", 8, 800, 0, 3, 3, rng))
    visual.append(ruin_wall("ChapelSideW", -20, 802, -90, 6, 3, rng))
    visual.append(ruin_wall("ChapelSideE", 15, 802, -90, 5, 2, rng))
    tops = Tops()
    for k in range(18):
        x = rng.choice([-1, 1]) * rng.uniform(9, 26) + (0 if k % 2 else rng.uniform(-4, 4))
        z = rng.uniform(786, 824)
        if not clear_of(x, z, keep):
            continue
        h = tops(rng.uniform(1.2, 1.8), 0.08)
        visual.append(part(f"FallenBlock{k}", (rng.uniform(2.0, 2.8), h, rng.uniform(1.6, 2.2)), (x, Y + h / 2 - 0.1, z), BRIAR_STONE,
                           "SmoothPlastic", rot_y(rng.uniform(0, 90)), collide=False, layer="prop"))
    visual.append(model("WrenchingRoots", [
        beam("RootW0", (-30, Y + 2.0, 812), (-20, Y + 6.5, 803), 1.0, OAK_BARK_DARK, "SmoothPlastic", collide=False),
        beam("RootW1", (-20, Y + 6.5, 803), (-14, Y + 5.2, 800), 0.7, OAK_BARK_DARK, "SmoothPlastic", collide=False),
        beam("RootE0", (30, Y + 2.4, 818), (17, Y + 4.4, 804), 1.0, OAK_BARK_DARK, "SmoothPlastic", collide=False),
        beam("RootE1", (17, Y + 4.4, 804), (13, Y + 3.0, 801), 0.6, OAK_BARK_DARK, "SmoothPlastic", collide=False),
    ]))
    # Vines drape down the wall face to the floor, so they stand whether or not the course above survived.
    visual.append(model("ChapelVines", [beam(f"Vine{k}", (x, Y + 4.8, 800.7), (x + 0.4, Y + 0.3, 800.95), 0.22, MOSS, "SmoothPlastic",
                                             collide=False, query=False) for k, x in enumerate((-17, -12, 10, 14))]))
    visual.append(waystone("GroveWaystone", "GroveEdge", 23, 0, 780, glow=BRIAR_GLOW))
    visual.append(sign("GroveSign", -14, 0, 826, yaw_facing(0, -1), 12, 5, "Warden's Grove",
                       "Rootbound Warden  |  Lv 14  |  Keeper of the Grove", board=BRIAR_IRON))

    # Everything built so far keeps the planting off it: one circle per prop part.
    clear = [(POOL[0], POOL[1], 24), (GROVE[0], GROVE[1], GROVE[2] + 4), (-70, 742, 24), (0, 800, 14), (0, 500, 14)]
    for e in REGISTRY[props_mark:]:
        if e["layer"] in ("proxy", "ground") or e["transparency"] >= 0.9:
            continue
        ext = max(abs(e["rot"][i][j]) * e["size"][j] / 2 for i in (0, 2) for j in range(3))
        clear.append((e["pos"][0], e["pos"][2], min(ext, 12) + 2.5))
    clear += [(x, z, 1.5 * 1.5 * 1.0 + 2) for x, z, r, _ in rocks]
    spawns = [(x, z) for _, _, _, _, (x, z), _ in BRIAR_SPAWNS]
    arrivals = list(BRIAR_ARRIVALS.values())
    guard = [(sx, sz, Y, 12) for sx, sz in spawns] + [(ax, az, Y, 8) for ax, az in arrivals]
    feet = []

    def landmark(name, x, z, kinds, s):
        """A hand-placed tree: the first species/scale that keeps the camera clearance."""
        for kind, sc in kinds:
            mark = len(REGISTRY)
            node = kind(name, x, z, rng, s=sc * s)
            if clearance_ok(mark, guard):
                visual.append(node)
                r0 = node["children"][0]["properties"]["Size"][1] / 2
                feet.append([_r(x), _r(z), _r(r0), {"Oak": 1, "Fir": 2, "Birch": 3}.get(node["attributes"]["Species"], 3)])
                return
            del REGISTRY[mark:]

    big = [(briar_oak, 1.0), (briar_oak, 1.2), (briar_oak, 1.4), (briar_birch, 1.0)]
    # The corridor's vista pair and the fork's knot of trees.
    for k, (x, z, s) in enumerate(((-9, 548, 1.1), (10, 552, 1.15), (-4, 596, 1.0), (4, 600, 0.9))):
        landmark(f"FeatureTree{k}", x, z, big if k != 1 else [(briar_fir, 1.0)] + big, s)
    for k, (x, z, s) in enumerate(((-30, 812, 1.2), (30, 818, 1.3))):
        landmark(f"ChapelTree{k}", x, z, big, s)
    # Warden's Grove: an open ring of giant oaks and firs round the arena, roots reaching toward it;
    # nothing stands inside it but the Warden.
    gx, gz, gr = GROVE
    for i in range(11):
        a = i * math.tau / 11
        tx, tz = gx + math.cos(a) * (gr + 8), gz + math.sin(a) * (gr + 8)
        if tz - gz < -0.7 * (gr + 8):  # the opening toward the chapel
            continue
        landmark(f"GroveTree{i:02d}", tx, tz, [(briar_fir, 1.1)] + big if i % 3 == 1 else big, rng.uniform(1.25, 1.45))
    clear += [(f[0], f[1], 9) for f in feet]

    trails = [(pts, (5.0 if key in ("Entrance", "Grove") else 4.2) / 2) for key, pts in BRIAR_TRAILS.items()]
    woods, more_feet, more_rocks, hummocks = plant_woodland(rng, inside_outline, trails, spawns, arrivals, clear,
                                                  (x0, BRIAR_X[1]), (548, z1 - 6))
    visual += woods
    feet += more_feet
    rocks += more_rocks

    brng = random.Random(9151)
    for k, (x, z, r, collide) in enumerate(rocks):
        visual.append(boulder(f"Boulder{k:03d}", x, z, max(r, 1.4), brng, collide=bool(collide)))

    # The plan WorldTerrain builds the ground from: the wall line, the trails, every trunk's foot
    # (root mound and leaf litter), every rock, and the places the ground must stay flat.
    plan = {
        "y": Y, "outline": outline,
        "trails": [[pts, w] for pts, w in ((pts, 5.0 if key in ("Entrance", "Grove") else 4.2) for key, pts in BRIAR_TRAILS.items())],
        "feet": feet, "rocks": rocks, "hummocks": hummocks, "pool": list(POOL), "grove": list(GROVE), "grotto": list(GROTTO),
        "falls": [[BRIAR_X[1] + 0.6, pz, Y + 29 + 3.2, 11], [BRIAR_X[0] - 0.6, 744, Y + 12.4 + 3.2, 6]],
        "spawns": [[x, z] for x, z in spawns], "arrivals": [[x, z] for x, z in arrivals],
    }
    visual.append(inst("ForestPlan", "StringValue", {"Value": json.dumps(plan, separators=(",", ":"))}))
    return ground, visual, proxies


# ── Output ────────────────────────────────────────────────────────────────────
WRITTEN: set[str] = set()


# ── Frostbound Glacier: west of the hub's Frostbound gate ─────────────────────
# No voxel terrain: every floor is a Grounds_FrostboundGlacier slab and everything seen is parts.
# The big pieces (ice cliffs, firs, rocks, crystals, the temple, the colossus, the frozen fall, the
# peaks) come from the kit in tools/glacier_kit.py, which tools/blender_glacier_kit.py also models
# as meshes; each is a `MeshSlot` model that MeshSlots.server.luau upgrades to its mesh once the GLBs
# are imported into ServerStorage.MapMeshes (docs/map/GLACIER.md). The route, west from the gate:
#   Frost Hollow (Y10, safe camp, waystone 6) -> the Great Ascent (a broad snow ramp under an ice
#   arch) -> the Frozen Lake terrace (Y20, frost imps) -> the Gargoyle Stair -> Gargoyle Ridge (Y30,
#   gargoyles, the half-sunk Frozen Colossus, waystone 7) -> the ice bridge over the Blue Crevasse
#   -> the Revenant's Forecourt before the frozen temple (Y30, the Frost Revenant).

GL_HOLLOW_Y = HUB_Y  # 10: level with the hub, straight through the gate
GL_LAKE_Y = 20.0
GL_RIDGE_Y = 30.0
GL_LAKE = (-278.0, -18.0, 30.0)  # frozen lake centre x, z and radius
GL_PLAZA = (-394.0, 42.0, 32.0)  # the Revenant's round forecourt
GL_BRIDGE = (-398.0, -382.0)     # the bridge deck's x span over the crevasse
GL_CREVASSE = (-24.0, -4.0)      # the crevasse's z span, between the ridge and the forecourt
GL_KIT = {}
try:
    GL_KIT = json.loads((ROOT / "assets" / "glacier" / "kit.json").read_text())
except FileNotFoundError:
    pass
# Play-area outline (x, z), walked round; the V -> A closing edge is the gate corridor (the hub's
# own proxies hold its sides).
GL_OUTLINE = [(-116, -19.5), (-116, -56), (-184, -56), (-184, -36), (-228, -36), (-228, -104), (-350, -104),
              (-350, -132), (-440, -132), (-440, 18), (-462, 18), (-462, 62), (-440, 62), (-440, 88), (-350, 88),
              (-350, 64), (-228, 64), (-228, 36), (-184, 36), (-184, 56), (-116, 56), (-116, 19.5)]
GL_TRAIL = [(-104, 0), (-150, 4), (-186, 0), (-228, 0), (-254, 34), (-300, 36), (-318, 6), (-312, -44), (-318, -80),
            (-350, -80), (-362, -62), (-388, -34), (-390, -2), (-394, 10)]
GLACIER_SPAWNS = [
    # id, archetype, level, role, (x, z), leash. The Frozen Lake (Y20): imp packs, two of them out on
    # the ice. Gargoyle Ridge (Y30): the gargoyles and their elite. The Forecourt: the Revenant. [TUNING]
    ("FG_I1", "FrostImp", 18, "minion", (-256, 18), 20),
    ("FG_I2", "FrostImp", 18, "minion", (-278, -18), 20),
    ("FG_I3", "FrostImp", 19, "minion", (-302, 40), 20),
    ("FG_I4", "FrostImp", 19, "minion", (-318, -36), 18),
    ("FG_G1", "GlacialGargoyle", 21, "minion", (-380, -114), 18),
    ("FG_G2", "GlacialGargoyle", 22, "minion", (-414, -94), 18),
    ("FG_G3", "GlacialGargoyle", 22, "minion", (-428, -52), 16),
    ("FG_E1", "GlacialGargoyle", 23, "elite", (-398, -70), 16),
    ("FG_BOSS", "Boss_FrostRevenant", 25, "boss", (GL_PLAZA[0], GL_PLAZA[1] + 2), 30),
]
GLACIER_ARRIVALS = {"FrostHollow": (-142, 14), "GargoyleRidge": (-366, -44)}


def kit_piece(key, name, x, z, yaw, s=1.0, y=None, layer="rock", attrs=None, light_on=None):
    """One kit piece from tools/glacier_kit.py, built from parts: standing at (x, y, z) (y = the floor
    there), turned so its front (local -Z) faces `yaw`, grown by `s`. The model carries the MeshSlot
    attributes MeshSlots.server.luau needs to swap in the imported mesh: its key, the mesh's world
    centre (kit.json's measured centre, turned and grown the same way), yaw and scale. `light_on`
    names a glow part that gets a PointLight."""
    y = floor_at(x, z, 0.0) if y is None else y
    R = rot_y(yaw)
    kids = []
    for pt in GK.lofi(GK.build(key)):
        off = apply(R, tuple(v * s for v in pt["pos"]))
        pos = (x + off[0], y + off[1], z + off[2])
        size = tuple(v * s for v in pt["size"])
        rot = mul(R, pt["rot"])
        kw = dict(collide=False, query=False, layer=layer)
        if pt["glow"]:
            kw.update(shadow=False, attrs={"MeshGlow": True})
            if light_on == pt["name"]:
                kw["children"] = [light(min(60, 22 * s), 1.4, GK.GLOW)]
        mat = "Neon" if pt["glow"] else "SmoothPlastic"
        if pt["kind"] == "ball":
            kids.append(ellipsoid(pt["name"], size, pos, pt["color"], mat, rot, **kw))
        elif pt["kind"] == "cyl":
            kids.append(part(pt["name"], size, pos, pt["color"], mat, rot, shape="Cylinder", **kw))
        elif pt["kind"] == "wedge":
            kids.append(part(pt["name"], size, pos, pt["color"], mat, rot, cls="WedgePart", **kw))
        else:
            kids.append(part(pt["name"], size, pos, pt["color"], mat, rot, **kw))
    info = GL_KIT.get(key)
    centre = info["centre"] if info else (0.0, 0.0, 0.0)
    c = apply(R, tuple(v * s for v in centre))
    a = {"MeshSlot": True, "MeshKey": key, "SlotX": _r(x + c[0]), "SlotY": _r(y + c[1]), "SlotZ": _r(z + c[2]),
         "SlotYaw": _r(yaw), "SlotScale": _r(s)}
    a.update(attrs or {})
    return model(name, kids, attrs=a)


def ramp_x(name, x0, x1, z0, z1, y_at_x0, y_at_x1, color, thickness=12.0):
    """A ramp along X: a thick tilted slab whose top runs from y_at_x0 (at x0) to y_at_x1 (at x1).
    Thick, so its sides read as a snow embankment rather than a plank, its foot sunk in the floor."""
    if x1 < x0:  # build it running east, so the slab's up is up
        x0, x1, y_at_x0, y_at_x1 = x1, x0, y_at_x1, y_at_x0
    dx, dy = x1 - x0, y_at_x1 - y_at_x0
    length = math.hypot(dx, dy)
    r = rot_z(math.degrees(math.atan2(dy, dx)))
    up = apply(r, (0, 1, 0))
    mid = ((x0 + x1) / 2, (y_at_x0 + y_at_x1) / 2, (z0 + z1) / 2)
    centre = tuple(mid[i] - up[i] * thickness / 2 for i in range(3))
    return part(name, (length + 0.4, thickness, z1 - z0), centre, color, "SmoothPlastic", r, layer="ground")


def _inside_outline(x, z, pts=GL_OUTLINE):
    inside = False
    n = len(pts)
    for i in range(n):
        (ax, az), (bx, bz) = pts[i], pts[(i + 1) % n]
        if (az > z) != (bz > z) and x < ax + (z - az) * (bx - ax) / (bz - az):
            inside = not inside
    return inside


def gl_proxy(name, a, b, out, y0=0.0):
    """An invisible wall on segment a -> b, 6 thick on its `out` side, to PROXY_TOP."""
    (ax, az), (bx, bz) = a, b
    seg = math.hypot(bx - ax, bz - az)
    yaw = math.degrees(math.atan2(-(bz - az), bx - ax))
    return part(name, (seg + 1.0, PROXY_TOP - y0, 6), ((ax + bx) / 2 + out[0] * 3, (y0 + PROXY_TOP) / 2,
                (az + bz) / 2 + out[1] * 3), (255, 0, 255), "SmoothPlastic", rot_y(yaw), transparency=1,
                query=False, shadow=False, layer="proxy")


def snow_drift(name, x, z, sx, sz, rng, h=2.6, y=None, color=GK.SNOW_SHADE):
    y = floor_at(x, z, 0.0) if y is None else y
    return ellipsoid(name, (sx, h, sz), (x, y + h * 0.18, z), color, rot=tilt(rng, 1.5, 4), layer="rock", shadow=False)


def snowman(name, x, z, yaw, rng):
    y = floor_at(x, z, 0.0)
    r, at = local_frame(x, y, z, yaw)
    kids = [part("Base", (4.6, 4.6, 4.6), at(0, 2.0, 0), GK.SNOW, shape="Ball", collide=False, query=False),
            part("Middle", (3.5, 3.5, 3.5), at(0, 5.2, 0), GK.SNOW, shape="Ball", collide=False, query=False),
            part("Head", (2.6, 2.6, 2.6), at(0, 7.7, 0), GK.SNOW, shape="Ball", collide=False, query=False),
            part("Nose", (1.4, 0.5, 0.5), at(0, 7.7, -1.5), (255, 140, 40), "SmoothPlastic",
                 mul(r, rot_y(90)), shape="Cylinder", collide=False, query=False),
            part("Scarf", (3.0, 0.7, 3.0), at(0, 6.7, 0), LEMON, "SmoothPlastic", mul(r, rot_z(90)),
                 shape="Cylinder", collide=False, query=False),
            part("ScarfTail", (0.8, 2.2, 0.35), at(0.9, 5.8, -1.3), LEMON, "SmoothPlastic", mul(r, rot_z(-10)),
                 collide=False, query=False),
            part("HatBrim", (0.3, 3.0, 3.0), at(0, 8.9, 0), GK.TEMPLE_NIGHT, "SmoothPlastic", mul(r, rot_z(90)),
                 shape="Cylinder", collide=False, query=False),
            part("Hat", (1.9, 1.9, 1.9), at(0, 9.95, 0), GK.TEMPLE_NIGHT, "SmoothPlastic", mul(r, rot_z(90)),
                 shape="Cylinder", collide=False, query=False),
            part("HatBand", (0.5, 2.0, 2.0), at(0, 9.3, 0), (255, 84, 64), "SmoothPlastic", mul(r, rot_z(90)),
                 shape="Cylinder", collide=False, query=False)]
    for k, lx in enumerate((-0.5, 0.5)):
        kids.append(part(f"Eye{k}", (0.35, 0.35, 0.35), at(lx, 8.1, -1.2), GK.TEMPLE_NIGHT, shape="Ball",
                         collide=False, query=False))
    for side in (-1, 1):
        kids.append(cyl(f"Arm{side}", at(side * 1.4, 5.6, 0), at(side * 3.6, 7.4, -0.3), 0.35, BARK, collide=False,
                        query=False, layer="prop"))
    return model(name, kids)


def frost_cabin(name, x, z, yaw, rng):
    """The expedition's timber cabin: crate-orange walls, a coral roof under a thick snow blanket, a
    warm window and a smoking chimney. Front (the door) faces `yaw`."""
    y = floor_at(x, z, 0.0)
    r, at = local_frame(x, y, z, yaw)
    w, d, h = 14.0, 10.0, 7.0
    kids = [part("Plinth", (w + 1.2, 1.0, d + 1.2), at(0, 0.4, 0), GK.ROCK_DEEP, rot=r),
            part("Walls", (w, h, d), at(0, 0.9 + h / 2, 0), TIMBER, rot=r)]
    for k in range(3):  # log courses
        kids.append(part(f"Course{k}", (w + 0.5, 0.5, d + 0.5), at(0, 1.9 + k * 2.2, 0), BEAM, rot=r, collide=False))
    kids.append(part("Door", (3.2, 5.2, 0.5), at(0, 3.5, -d / 2 - 0.15), (40, 196, 214), rot=r, collide=False))
    kids.append(part("DoorFrame", (4.0, 6.0, 0.3), at(0, 3.9, -d / 2 - 0.05), BEAM, rot=r, collide=False))
    for side in (-1, 1):
        kids.append(part(f"Window{side}", (2.6, 2.2, 0.3), at(side * 4.3, 4.6, -d / 2 - 0.2), (255, 214, 140), "Neon",
                         r, collide=False, query=False, shadow=False))
        kids.append(part(f"Sill{side}", (3.2, 0.4, 0.8), at(side * 4.3, 3.3, -d / 2 - 0.4), GK.SNOW, rot=r,
                         collide=False))
    pitch = 30.0
    run = d / 2 + 1.2
    for side in (-1, 1):  # the roof: coral under a thick snow blanket
        rr = mul(r, rot_x(side * -pitch))
        kids.append(part(f"Roof{side}", (w + 2.4, 0.8, run / math.cos(math.radians(pitch))),
                         at(0, h + 0.9 + math.tan(math.radians(pitch)) * run / 2, side * run / 2), (255, 84, 64), rot=rr,
                         collide=False))
        kids.append(part(f"RoofSnow{side}", (w + 2.0, 1.3, run / math.cos(math.radians(pitch)) - 0.2),
                         at(0, h + 1.9 + math.tan(math.radians(pitch)) * run / 2, side * (run / 2 - 0.2)), GK.SNOW,
                         rot=rr, collide=False))
    ridge_y = h + 0.9 + math.tan(math.radians(pitch)) * run
    kids.append(ellipsoid("RidgeSnow", (w + 2.6, 1.8, 2.4), at(0, ridge_y + 0.9, 0), GK.SNOW, rot=mul(r, rot_z(2)),
                          layer="prop"))
    kids.append(part("Gable", (w, 3.4, 0.4), at(0, h + 2.4, 0), TIMBER, rot=r, collide=False))
    kids.append(part("Chimney", (2.2, 7.0, 2.2), at(4.2, h + 4.6, 2.0), GK.ROCK_DEEP, rot=r, collide=False,
                     children=[smoke(3.0, 0.25, 2.5, (236, 244, 255))]))
    kids.append(part("ChimneyCap", (2.8, 0.8, 2.8), at(4.2, h + 8.4, 2.0), GK.SNOW, rot=r, collide=False))
    kids.append(part("DoorLamp", (0.8, 1.1, 0.8), at(2.6, 6.0, -d / 2 - 0.6), (255, 208, 132), "Neon", r,
                     collide=False, query=False, shadow=False, children=[light(20, 1.2, LANTERN)]))
    return model(name, kids)


def sled(name, x, z, yaw, rng):
    y = floor_at(x, z, 0.0)
    r, at = local_frame(x, y, z, yaw)
    kids = []
    for side in (-1, 1):
        kids.append(part(f"Runner{side}", (0.4, 0.5, 7.4), at(side * 1.6, 0.25, 0), (255, 84, 64), rot=r, collide=False))
        kids.append(part(f"RunnerTip{side}", (0.4, 1.4, 0.5), at(side * 1.6, 0.8, -3.8), (255, 84, 64),
                         rot=mul(r, rot_x(-20)), collide=False))
        for k, lz in enumerate((-2.2, 2.2)):
            kids.append(part(f"Strut{side}{k}", (0.35, 0.9, 0.35), at(side * 1.6, 0.9, lz), BEAM, rot=r, collide=False))
    kids.append(part("Deck", (4.0, 0.4, 6.4), at(0, 1.5, 0), TIMBER, rot=r, collide=False))
    kids.append(part("Crate0", (2.4, 2.2, 2.4), at(-0.5, 2.8, 1.4), TIMBER, rot=mul(r, rot_y(8)), collide=False))
    kids.append(part("Crate1", (2.0, 1.8, 2.0), at(0.5, 2.6, -1.3), (255, 206, 24), rot=mul(r, rot_y(-12)), collide=False))
    kids.append(ellipsoid("Bedroll", (3.4, 1.4, 1.4), at(0.2, 4.4, 1.3), (60, 196, 245), rot=mul(r, rot_z(3)),
                          layer="prop"))
    return model(name, kids)


def frost_brazier(name, x, z, rng, lit=True):
    """The temple's cold fire: a trim-blue stand, a bowl, a crown of glowing ice shards."""
    y = floor_at(x, z, 0.0)
    kids = [drum("Stand", x, y - 0.2, y + 3.6, z, 1.1, 1.1, GK.TEMPLE_TRIM),
            drum("Foot", x, y - 0.2, y + 0.9, z, 1.9, 1.9, GK.TEMPLE),
            drum("Bowl", x, y + 3.5, y + 4.7, z, 2.2, 2.2, GK.TEMPLE)]
    for k in range(3):
        a = k * 120 + 20
        tip = mul(rot_y(a), rot_z(14))
        kids.append(part(f"Flame{k}", (0.9, 3.2, 0.9), (x + math.cos(math.radians(a)) * 0.5, y + 6.1,
                                                          z + math.sin(math.radians(a)) * 0.5), GK.GLOW, "Neon", tip,
                         collide=False, query=False, shadow=False, transparency=0.1,
                         children=[light(26, 1.5, GK.GLOW)] if lit and k == 0 else None))
    return model(name, kids)


def frost_banner(name, x, z, yaw, rng, h=12.0):
    y = floor_at(x, z, 0.0)
    r, at = local_frame(x, y, z, yaw)
    return model(name, [
        drum("Pole", x, y - 0.2, y + h, z, 0.35, 0.35, GK.TEMPLE_TRIM),
        part("Finial", (1.0, 1.0, 1.0), at(0, h + 0.4, 0), GK.GLOW, "Neon", mul(r, mul(rot_x(45), rot_z(45))),
             collide=False, query=False, shadow=False),
        part("Bar", (4.6, 0.4, 0.4), at(0, h - 0.8, -0.4), GK.TEMPLE_TRIM, rot=r, collide=False),
        part("Cloth", (4.0, 7.0, 0.25), at(0, h - 4.6, -0.5), GK.TEMPLE_NIGHT, rot=r, collide=False),
        part("Stripe", (0.8, 6.2, 0.1), at(0, h - 4.8, -0.68), GK.GLOW, rot=r, collide=False, shadow=False),
        part("Tail", (2.8, 2.8, 0.25), at(0, h - 8.1, -0.5), GK.TEMPLE_NIGHT, rot=mul(r, rot_z(45)), collide=False),
    ])


def ice_chunk(name, x, z, rng, s=1.0, y=None):
    y = floor_at(x, z, 0.0) if y is None else y
    w, h = rng.uniform(2.4, 4.2) * s, rng.uniform(3.2, 6.0) * s
    return part(name, (w, h, w * rng.uniform(0.3, 0.5)), (x, y + h * 0.3, z), rng.choice((GK.ICE, GK.ICE_PALE)),
                rot=mul(rot_y(rng.uniform(0, 180)), mul(rot_x(rng.uniform(18, 34)), rot_z(rng.uniform(-10, 10)))),
                collide=False, query=False, layer="rock")


def glacier_walls(rng):
    """Ice cliffs all round the outline (standing on the floors, which run out under them), an
    invisible proxy along every edge, and a second rank of crags stepping back and up behind the
    walls where the snowfield apron lies. Each cliff is grown so its columns stand ~72 studs over
    the floor it faces (its crest higher): at the default zoom cap no view reaches over it. The
    cliff with the fallen slab only stands well away from spawns and arrivals."""
    visual, proxies = [], []
    keys = ("IceCliffA", "IceCliffB", "IceCliffC")
    crags = ("IceCragA", "IceCragB")
    marks = [xz for *_, xz, _ in GLACIER_SPAWNS] + list(GLACIER_ARRIVALS.values())
    pts = GL_OUTLINE
    for i in range(len(pts) - 1):
        (ax, az), (bx, bz) = pts[i], pts[i + 1]
        seg = math.hypot(bx - ax, bz - az)
        dx, dz = (bx - ax) / seg, (bz - az) / seg
        out = (dz, -dx)
        mx, mz = (ax + bx) / 2, (az + bz) / 2
        if _inside_outline(mx + out[0], mz + out[1]):
            out = (-out[0], -out[1])
        proxies.append(gl_proxy(f"GlacierWall{i:02d}_Proxy", (ax, az), (bx, bz), out))
        if ax == bx == -116:  # against the hub's castle wall: its back is the wall here
            continue
        inner = floor_at(mx - out[0] * 3, mz - out[1] * 3, GL_HOLLOW_Y)
        n = max(1, math.ceil(seg / 46.0))
        for k in range(n):
            t = (k + 0.5) / n
            px, pz = ax + (bx - ax) * t + out[0] * 8, az + (bz - az) * t + out[1] * 8
            # where the floor outside is the lower one (a terrace's own edge), the cliff stands on the
            # terrace: its snow drift lies on the floor it faces, not buried in it
            foot = max(floor_at(px, pz, inner), inner)
            s = max(1.15, min(1.6, (inner + 72 - foot) / 60.0)) * rng.uniform(0.97, 1.08)
            key = "IceCliffC" if i in (3, 17) else keys[(i * 2 + k) % 3]  # the ascent: the finer columns
            if key == "IceCliffA":  # its fallen slab needs a flat floor in front, clear of the markers
                fx, fz = px - out[0] * 16, pz - out[1] * 16
                flat = all(abs(floor_at(fx + dx * u, fz + dz * u, inner) - foot) < 0.5 for u in (-22, 0, 22))
                if not flat or any(math.hypot(px - qx, pz - qz) < 40 for qx, qz in marks):
                    key = "IceCliffB"
            yaw = yaw_facing(-out[0], -out[1]) + rng.uniform(-5, 5)
            visual.append(kit_piece(key, f"GlacierCliff{i:02d}_{k}", px, pz, yaw, s, y=foot - 0.4, layer="cliff"))
        # the second rank: crags on the apron behind the wall, their crests ~110 over the floor inside
        m = max(1, math.ceil(seg / 80.0))
        for k in range(m):
            t = (k + 0.5) / m
            s = max(1.0, min(1.9, (inner + 112 - 0.5) / 100.0)) * rng.uniform(0.94, 1.08)
            # far enough out that its drift (23 * s in front of its centre) clears the floor slab,
            # which runs 20 past the outline (further past the forecourt's alcove: step out until clear)
            jx, jz = rng.uniform(-5, 5), rng.uniform(-5, 5)
            for d in (24 + 24 * s, 36 + 24 * s, 48 + 24 * s):
                qx = ax + (bx - ax) * t + out[0] * d + jx
                qz = az + (bz - az) * t + out[1] * d + jz
                if floor_at(qx - out[0] * 24 * s, qz - out[1] * 24 * s, 0.5) <= 1.0:
                    break
            else:
                continue
            if not (-596 < qx < -108 and -256 < qz < 90):
                continue  # off the snowfield apron: the hub east, the desert south
            foot = floor_at(qx, qz, 0.5)
            if foot > 1.0:
                continue
            yaw = yaw_facing(-out[0], -out[1]) + rng.uniform(-14, 14)
            visual.append(kit_piece(crags[(i + k) % 2], f"GlacierCrag{i:02d}_{k}", qx, qz, yaw, s, y=foot - 0.4,
                                    layer="vista"))
    return visual, proxies


def build_frostbound_glacier():
    global AUTO_GROUND
    AUTO_GROUND = True
    rng = random.Random(0x61AC1E5)
    Y0, Y1, Y2 = GL_HOLLOW_Y, GL_LAKE_Y, GL_RIDGE_Y
    lx, lz, lr = GL_LAKE
    px_, pz_, pr = GL_PLAZA
    b0, b1 = GL_BRIDGE
    c0, c1 = GL_CREVASSE
    # Floors. The slabs run out past the outline so the cliffs stand on them; the apron is the
    # snowfield under everything, out to the vista peaks, so no view ends on the bare baseplate.
    ground = [
        slab("GlacierApron", -600, -104, -260, 92, 0.5, GK.SNOW_SHADE, "SmoothPlastic"),
        slab("FrostHollowFloor", -200, -104, -76, 76, Y0, GK.SNOW, "SmoothPlastic"),
        slab("AscentFloor", -228, -200, -56, 56, Y0, GK.SNOW, "SmoothPlastic"),
        ramp_x("GreatAscent", -186, -228, -28, 28, Y0, Y1, GK.SNOW_PATH),
        slab("LakeTerrace", -350, -228, -124, 84, Y1, GK.SNOW, "SmoothPlastic"),
        ramp_x("GargoyleStair", -318, -350, -100, -60, Y1, Y2, GK.SNOW_PATH, thickness=14.0),
        slab("GargoyleRidge", -460, -350, -152, c0, Y2, GK.SNOW, "SmoothPlastic"),
        slab("Forecourt", -482, -350, c1, 108, Y2, GK.SNOW, "SmoothPlastic"),
        slab("CrevasseFloor", -460, -350, c0, c1, 3.0, GK.ICE_DEEP, "SmoothPlastic"),
        box("IceBridgeDeck", b0, b1, Y2 - 0.8, Y2 + 0.4, c0 - 2, c1 + 2, GK.ICE_PALE, layer="ground"),
    ]
    ground += disc("FrozenLake", lx, lz, lr, Y1 + 0.3, 0.8, GK.ICE, "SmoothPlastic")
    ground += disc("ForecourtPlaza", px_, pz_, pr, Y2 + 0.3, 0.8, GK.TEMPLE, "SmoothPlastic")

    visual, proxies = glacier_walls(rng)
    # Proxies inside the outline: the crevasse's lips (the bridge is the one crossing), the bridge's
    # rails, the crevasse mouth on the lake terrace, and the temple (its steps are for looking at: the
    # Revenant's plaza ends at them).
    for tag, zz, out in (("N", c0, (0, 1)), ("S", c1, (0, -1))):
        proxies.append(gl_proxy(f"CrevasseLip{tag}W", (-440, zz), (b0, zz), out, Y2 - 30))
        proxies.append(gl_proxy(f"CrevasseLip{tag}E", (b1, zz), (-350, zz), out, Y2 - 30))
    proxies.append(gl_proxy("BridgeRailW", (b0, c0), (b0, c1), (1, 0), Y2 - 30))
    proxies.append(gl_proxy("BridgeRailE", (b1, c0), (b1, c1), (-1, 0), Y2 - 30))
    proxies.append(gl_proxy("CrevasseMouth", (-350, c0), (-350, c1), (-1, 0)))
    proxies.append(box("TempleProxy", -466, -440, Y2, PROXY_TOP, 17, 63, (255, 0, 255), transparency=1,
                       query=False, shadow=False, layer="proxy"))

    spawns = [(x, z) for *_, (x, z), _ in GLACIER_SPAWNS]
    arrivals = list(GLACIER_ARRIVALS.values())

    def clear(x, z, r_spawn=20.0, r_arrive=14.0, r_trail=5.0):
        if any(math.hypot(x - sx, z - sz) < r_spawn for sx, sz in spawns):
            return False
        if any(math.hypot(x - ax, z - az) < r_arrive for ax, az in arrivals):
            return False
        return all(seg_dist(x, z, GL_TRAIL[i], GL_TRAIL[i + 1]) >= r_trail for i in range(len(GL_TRAIL) - 1))

    # The trail: packed-snow strips, alternate legs a hair higher so their overlaps never z-fight.
    for i in range(len(GL_TRAIL) - 1):
        (ax, az), (bx, bz) = GL_TRAIL[i], GL_TRAIL[i + 1]
        if ax > -186 or not (-186 >= ax >= -228 and -186 >= bx >= -228):
            ya, yb = floor_at(ax, az, Y0), floor_at(bx, bz, Y0)
            if abs(ya - yb) > 0.5 or (-318 >= ax >= -350 and -318 >= bx >= -350):
                continue  # ramps carry their own paler surface
            seg = math.hypot(bx - ax, bz - az)
            yaw = math.degrees(math.atan2(-(bz - az), bx - ax))
            top = max(ya, yb) + (0.12 if i % 2 else 0.2)
            visual.append(part(f"GlacierTrail{i:02d}", (seg + 7, 0.3, 7), ((ax + bx) / 2, top - 0.15, (az + bz) / 2),
                               GK.SNOW_PATH, rot=rot_y(yaw), collide=False, query=False, layer="decal"))

    # ── Frost Hollow: the expedition's camp, safe inside the gate ──
    visual.append(hanging_sign("GlacierSign", -112, -13, yaw_facing(-1, 0), "Frostbound Glacier", "Lv 18 - 25"))
    for k, z in enumerate((-11.5, 11.5)):
        visual.append(lantern_post(f"GateLantern{k}", -121, z, yaw_facing(0, -z), rng))
    visual.append(waystone("FrostHollowWaystone", "FrostHollow", -152, Y0, 26, glow=GK.GLOW))
    visual.append(frost_cabin("ExpeditionCabin", -158, -40, yaw_facing(0, 1), rng))
    visual.append(desert_fire("CampFire", -140, -20, rng))
    for k, (x, z, yaw) in enumerate(((-140, -26.5, 0), (-146.6, -20, 90), (-133.4, -20, 90))):
        visual.append(log_bench(f"CampLog{k}", x, z, yaw, 6.0))
    visual.append(a_tent("CampTent0", -124, -42, 20, TENT_CLOTH[0], rng=rng))
    visual.append(a_tent("CampTent1", -176, -20, 80, TENT_CLOTH[2], rng=rng))
    visual.append(sled("SupplySled", -170, -34, 150, rng))
    visual.append(crate_stack("CampCrates", -134, Y0, -44, rng))
    visual.append(barrel("CampBarrel", -129, Y0, -47, rng))
    visual.append(snowman("Snowman", -128, 34, yaw_facing(1, -0.4), rng))
    visual.append(toy_finish(fingerpost("HollowPost", -178, Y0, 17, [("Frozen Lake", yaw_facing(-1, 0), 7.2),
                                                                     ("Hearthmere", yaw_facing(1, 0), 6.4)])))
    for k, (key, x, z, s) in enumerate((("SnowFirA", -178, -48, 1.1), ("SnowFirB", -170, -50, 0.9),
                                        ("SnowFirC", -124, 48, 1.0), ("SnowFirB", -134, 50, 0.85),
                                        ("SnowFirA", -178, 48, 1.15), ("SnowFirC", -168, 50, 0.95),
                                        ("SnowFirB", -122, -52, 0.8))):
        visual.append(kit_piece(key, f"HollowFir{k}", x, z, rng.uniform(0, 360), s, layer="tree"))
    for k, (key, x, z, s) in enumerate((("SnowRockA", -120, 26, 0.9), ("SnowRockC", -120, -28, 1.0),
                                        ("SnowRockB", -182, 30, 0.9), ("SnowRockC", -160, 50, 1.0))):
        visual.append(kit_piece(key, f"HollowRock{k}", x, z, rng.uniform(0, 360), s))
    for k, (x, z, sx, sz) in enumerate(((-150, 52, 22, 7), (-120, 40, 6, 14), (-180, -2, 5, 16), (-146, -52, 16, 6))):
        visual.append(snow_drift(f"HollowDrift{k}", x, z, sx, sz, rng))

    # ── The Great Ascent: a broad snow ramp between fir-lined banks, under an ice arch ──
    for side in (-1, 1):
        for k, x in enumerate((-194, -214)):
            if k == 0:
                visual.append(lantern_post(f"AscentLantern{side}", x, side * 26, yaw_facing(0, -side), rng))
        for k, (key, x, s) in enumerate((("SnowFirB", -192, 0.8), ("SnowFirA", -206, 0.95), ("SnowFirC", -220, 0.9))):
            visual.append(kit_piece(key, f"AscentFir{side}{k}", x, side * 32.5, rng.uniform(0, 360), s, layer="tree"))
    visual.append(kit_piece("IceArch", "AscentArch", -236, 0, yaw_facing(1, 0), 1.3, layer="rock",
                            attrs={"Landmark": "AscentArch"}))

    # ── The Frozen Lake terrace ──
    visual.append(kit_piece("FrozenFall", "FrozenFall", -282, -100, yaw_facing(0, 1), 1.3, layer="rock"))
    crack_rng = random.Random(0xC4AC)
    for k in range(7):  # cracks: short zigzag polylines out from near the middle
        a = k / 7 * math.tau + crack_rng.uniform(-0.3, 0.3)
        r0 = crack_rng.uniform(2, 8)
        x, z = lx + math.cos(a) * r0, lz + math.sin(a) * r0
        for j in range(3):
            a2 = a + crack_rng.uniform(-0.5, 0.5)
            ln = crack_rng.uniform(4, 7)
            nx_, nz_ = x + math.cos(a2) * ln, z + math.sin(a2) * ln
            if math.hypot(nx_ - lx, nz_ - lz) > lr - 2:
                break
            visual.append(part(f"LakeCrack{k}_{j}", (ln + 0.3, 0.12, 0.35), ((x + nx_) / 2, Y1 + 0.36, (z + nz_) / 2),
                               GK.ICE_DEEP, rot=rot_y(math.degrees(math.atan2(-(nz_ - z), nx_ - x))), collide=False,
                               query=False, shadow=False, layer="decal"))
            x, z = nx_, nz_
    for k in range(14):  # a snow rim round the ice and a few plates of ice heaved up at its edge
        a = k / 14 * math.tau + rng.uniform(-0.12, 0.12)
        x, z = lx + math.cos(a) * (lr + 2.2), lz + math.sin(a) * (lr + 2.2)
        if clear(x, z, 12, 12, 4):
            visual.append(snow_drift(f"LakeRim{k}", x, z, rng.uniform(7, 11), rng.uniform(3.5, 5), rng, h=2.2,
                                     y=Y1, color=GK.SNOW))
        if k % 3 == 0:
            x, z = lx + math.cos(a + 0.2) * (lr - 1.5), lz + math.sin(a + 0.2) * (lr - 1.5)
            if clear(x, z, 10, 12, 3):
                visual.append(ice_chunk(f"LakeIce{k}", x, z, rng, 1.2, y=Y1 + 0.3))
    fx, fz = lx + 12, lz + 13  # an ice-fishing hole, the expedition's only trace out on the lake
    visual.append(disc("FishingHole", fx, fz, 1.6, Y1 + 0.42, 0.2, GK.TEMPLE_NIGHT, "SmoothPlastic", collide=False,
                       layer="decal")[0])
    visual.append(barrel("FishingBucket", fx + 2.8, Y1 + 0.3, fz + 1.0, rng))
    for k, (key, x, z, s) in enumerate((("CrystalClusterA", -240, -84, 1.2), ("CrystalClusterB", -236, -70, 1.0),
                                        ("CrystalClusterA", -338, 52, 1.1), ("CrystalClusterB", -262, 54, 1.0),
                                        ("CrystalClusterC", -332, -88, 1.0))):
        visual.append(kit_piece(key, f"LakeCrystal{k}", x, z, rng.uniform(0, 360), s,
                                light_on=None))
    for k, (key, x, z, s) in enumerate((("SnowFirA", -238, -96, 1.2), ("SnowFirC", -250, -98, 1.1),
                                        ("SnowFirB", -262, -94, 0.9), ("SnowFirA", -236, 56, 1.1),
                                        ("SnowFirC", -248, 58, 1.0), ("SnowFirB", -326, 58, 0.9),
                                        ("SnowFirA", -340, 38, 1.1), ("SnowFirC", -304, -96, 1.0),
                                        ("SnowFirB", -318, 58, 0.8))):
        if clear(x, z, 22, 20, 6):
            visual.append(kit_piece(key, f"LakeFir{k}", x, z, rng.uniform(0, 360), s, layer="tree"))
    for k, (key, x, z, s) in enumerate((("SnowRockA", -234, 30, 1.0), ("SnowRockB", -296, -92, 1.0),
                                        ("SnowRockC", -266, 58, 1.1), ("SnowRockA", -326, 12, 0.9),
                                        ("SnowRockC", -232, -46, 1.0), ("SnowRockB", -344, -48, 0.9))):
        if clear(x, z, 14, 14, 5):
            visual.append(kit_piece(key, f"LakeRock{k}", x, z, rng.uniform(0, 360), s))
    # the ridge's cliff face over the lake terrace, and the crevasse mouth
    for k, z in enumerate((-42, 14, 46)):
        visual.append(kit_piece("IceLedge", f"RidgeFace{k}", -345, z, yaw_facing(1, 0) + rng.uniform(-4, 4), 0.9,
                                y=Y1 - 0.3, layer="cliff"))
    for side, z in (("S", -60), ("N", -104)):
        visual.append(kit_piece("TempleColumnBroken", f"StairColumn{side}", -322, z + (2 if side == "S" else 2), 0, 1.1))
    visual.append(kit_piece("TempleColumn", "StairColumnTop", -346, -58, 0, 1.0))

    # ── Gargoyle Ridge ──
    visual.append(kit_piece("FrozenColossus", "FrozenColossus", -430, -122, yaw_facing(1, 0.8), 1.25,
                            y=Y2 - 1.0, attrs={"Landmark": "FrozenColossus"}))
    visual.append(waystone("GargoyleRidgeWaystone", "GargoyleRidge", -356, Y2, -34, glow=GK.GLOW))
    for k, (key, x, z, s, lit) in enumerate((("CrystalClusterC", -360, -124, 1.2, True),
                                             ("CrystalClusterC", -436, -80, 1.0, False),
                                             ("CrystalClusterA", -404, -128, 1.1, False),
                                             ("CrystalClusterB", -366, -92, 1.0, False),
                                             ("CrystalClusterA", -436, -30, 1.0, False),
                                             ("CrystalClusterC", -358, -56, 0.8, False))):
        if clear(x, z, 16, 10, 5):
            visual.append(kit_piece(key, f"RidgeCrystal{k}", x, z, rng.uniform(0, 360), s))
    for k, (key, x, z, s) in enumerate((("SnowRockB", -384, -130, 1.0), ("SnowRockA", -438, -104, 1.0),
                                        ("SnowRockC", -372, -30, 1.0), ("SnowRockA", -410, -30, 0.9))):
        if clear(x, z, 14, 10, 5):
            visual.append(kit_piece(key, f"RidgeRock{k}", x, z, rng.uniform(0, 360), s))
    for k, x in enumerate((b0 - 4, b1 + 4)):  # the bridgehead: two columns and a pair of braziers
        visual.append(kit_piece("TempleColumn", f"BridgeheadColumn{k}", x, c0 - 5, 0, 1.0))
    visual.append(kit_piece("IceBridge", "IceBridge", (b0 + b1) / 2, (c0 + c1) / 2, 0, 1.0, y=Y2 + 0.4))
    for k, x in enumerate((-356, -372, -416, -432)):  # ice columns lining the crevasse walls
        for side, zz in ((0, c0 + 0.6), (1, c1 - 0.6)):
            h = rng.uniform(18, 25)
            visual.append(part(f"CrevasseIce{k}{side}", (rng.uniform(4, 7), h, 1.4), (x + rng.uniform(-3, 3), 3 + h / 2, zz),
                               rng.choice((GK.ICE, GK.ICE_PALE, GK.ICE_DEEP)), rot=rot_y(rng.uniform(-6, 6)),
                               collide=False, query=False, layer="rock"))
    for k, x in enumerate((-366, -414, -436)):
        visual.append(kit_piece("CrystalClusterC", f"CrevasseCrystal{k}", x, (c0 + c1) / 2 + rng.uniform(-3, 3),
                                rng.uniform(0, 360), 0.9, y=3.0))

    # ── The Revenant's Forecourt and the frozen temple ──
    visual.append(kit_piece("TempleFacade", "FrozenTemple", -451, 40, yaw_facing(1, 0), 1.0, y=Y2,
                            light_on="DoorGlow", attrs={"Landmark": "FrozenTemple"}))
    visual.append(kit_piece("TempleSpire", "FrozenSpire", -474, 40, 0, 1.0, y=Y2, light_on="Tip"))
    for k, (x, z) in enumerate(((px_ + pr - 2, pz_), (px_, pz_ - pr + 2), (px_, pz_ + pr - 2), (px_ - pr + 4, pz_ - 20))):
        visual.append(frost_brazier(f"ForecourtBrazier{k}", x, z, rng))
    for k, (x, z) in enumerate(((-372, 6), (-416, 6), (-356, 60), (-432, 76))):
        visual.append(frost_banner(f"ForecourtBanner{k}", x, z, yaw_facing(px_ - x, pz_ - z), rng))
    for k, z in enumerate((70, 12)):  # the temple colonnade flanking the plaza's west edge
        visual.append(kit_piece("TempleColumn", f"PlazaColumn{k}", -432, z, 0, 1.0))
    for k, (key, x, z, s) in enumerate((("SnowFirA", -358, 80, 1.1), ("SnowFirC", -370, 82, 1.0),
                                        ("SnowFirB", -432, 84, 0.9), ("SnowFirA", -358, 12, 0.9),
                                        ("SnowFirC", -436, 2, 1.0))):
        if clear(x, z, 22, 12, 5):
            visual.append(kit_piece(key, f"ForecourtFir{k}", x, z, rng.uniform(0, 360), s, layer="tree"))
    for k, (key, x, z, s) in enumerate((("CrystalClusterA", -356, 36, 1.0), ("CrystalClusterB", -420, 84, 1.0),
                                        ("SnowRockA", -400, 84, 1.0), ("SnowRockC", -436, 30, 0.8))):
        if clear(x, z, 14, 10, 4):
            visual.append(kit_piece(key, f"ForecourtRock{k}", x, z, rng.uniform(0, 360), s))
    for k in range(12):  # the plaza's inlaid ring
        a = k / 12 * math.tau
        visual.append(part(f"PlazaRing{k}", (5.4, 0.12, 1.2), (px_ + math.cos(a) * (pr - 5), Y2 + 0.36,
                                                                pz_ + math.sin(a) * (pr - 5)), GK.TEMPLE_TRIM,
                           rot=rot_y(90 - math.degrees(a)), collide=False, query=False, shadow=False, layer="decal"))

    # ── Vista: snow peaks on the snowfield beyond the walls ──
    # (a third rank behind the crags: a range along the north and the west; south lies the desert)
    for k, (key, x, z, s) in enumerate((("SnowPeakA", -190, -200, 0.9), ("SnowPeakB", -270, -218, 1.0),
                                        ("SnowPeakB", -322, -196, 0.72), ("SnowPeakA", -372, -226, 1.15),
                                        ("SnowPeakB", -470, -212, 1.0), ("SnowPeakA", -556, -172, 1.1),
                                        ("SnowPeakB", -522, -118, 0.8), ("SnowPeakB", -574, -66, 1.0),
                                        ("SnowPeakA", -570, 34, 1.05), ("SnowPeakB", -142, -168, 0.7))):
        visual.append(kit_piece(key, f"VistaPeak{k}", x, z, rng.uniform(0, 360), s, y=0.3, layer="vista"))
    return ground, visual, proxies


def write_text(path: Path, text: str):
    """Rewrite a file only when its contents change. A connected Rojo session sees a deleted and
    recreated file as a new instance and leaves the old one in Studio, so the map is never wiped
    and regenerated wholesale: unchanged files are left alone and changed ones updated in place."""
    WRITTEN.add(path.name)
    if not path.exists() or path.read_text() != text:
        path.write_text(text)


def write_model(path: Path, node: dict):
    root = {k: v for k, v in node.items() if k != "name"}
    write_text(path, json.dumps(root, indent=1) + "\n")


def main():
    rng = random.Random(20260915)
    REGISTRY.clear()
    USED_CLIFF_TOPS.clear()
    LOCAL_CLIFF_TOPS.clear()
    hub_ground, hub_visual, hub_proxies = build_hub(rng)
    il_ground, il_visual, il_proxies = build_iron_lowlands(rng)
    bw_ground, bw_visual, bw_proxies = build_briarwood(rng)
    gl_ground, gl_visual, gl_proxies = build_frostbound_glacier()  # its own seed: nothing above moves
    markers = build_markers()
    global AUTO_GROUND
    AUTO_GROUND = False

    OUT.mkdir(parents=True, exist_ok=True)
    WRITTEN.clear()
    write_text(OUT / "init.meta.json", json.dumps({
        "className": "Folder",
        "attributes": {"MapVersion": MAP_VERSION, "MapName": "Lemonade Hearthmere Slice"},
    }, indent=1) + "\n")
    write_model(OUT / "Grounds_Hub.model.json", model("Grounds_Hub", hub_ground))
    write_model(OUT / "Grounds_IronLowlands.model.json", model("Grounds_IronLowlands", il_ground))
    write_model(OUT / "Grounds_Briarwood.model.json", model("Grounds_Briarwood", bw_ground))
    write_model(OUT / "Grounds_FrostboundGlacier.model.json", model("Grounds_FrostboundGlacier", gl_ground))
    write_model(OUT / "Collision.model.json", model("Collision", hub_proxies + il_proxies + bw_proxies + gl_proxies))
    hub_model = model("Hub", hub_visual, attrs={"Region": "Hub"})
    hub_model["properties"] = {"ModelStreamingMode": "Atomic"}  # arrives complete, so HubAmbience finds everything
    write_model(OUT / "Hub.model.json", hub_model)
    write_model(OUT / "IronLowlands.model.json", model("IronLowlands", il_visual, attrs={"Region": "IronLowlands"}))
    write_model(OUT / "Briarwood.model.json", model("Briarwood", bw_visual, attrs={"Region": "Briarwood"}))
    write_model(OUT / "FrostboundGlacier.model.json", model("FrostboundGlacier", gl_visual,
                                                           attrs={"Region": "FrostboundGlacier"}))
    write_model(OUT / "Markers.model.json", markers)
    write_model(OUT / "Horizon.model.json", build_horizon())
    for stale in OUT.iterdir():  # a model this build no longer makes
        if stale.name not in WRITTEN:
            stale.unlink()

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

    x_min, x_max, z_min, z_max = -500, 150, -270, 950
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
    for x in range(-500, 151, 50):
        draw.line([px(x, z_min), px(x, z_max)], fill=(255, 255, 255, 30))
        draw.text((px(x, z_min)[0] - 12, 8), f"x{x}", fill=(200, 200, 200), font=font)
    for z in range(-250, 951, 50):
        draw.line([px(x_min, z), px(x_max, z)], fill=(255, 255, 255, 30))
        draw.text((6, px(x_min, z)[1] - 7), f"z{z}", fill=(200, 200, 200), font=font)

    # Safe zones, spawns, NPCs, waypoints.
    for (x0, x1, z0, z1, name) in ((-100, 100, -100, 100, "SAFE: Hub"), (-40, 40, 100, 168, "SAFE: Overlook"),
                                   (-20, 20, 472, 528, "SAFE: Briar Gate"), (-184, -104, -56, 56, "SAFE: Frost Hollow")):
        draw.rectangle([px(x0, z0), px(x1, z1)], outline=(80, 255, 140, 220), width=2)
        draw.text((px(x0, z0)[0] + 4, px(x0, z0)[1] + 4), name, fill=(120, 255, 170), font=font)
    arch_color = {"IronSquire": (255, 210, 90), "IronBerserker": (255, 130, 60), "Boss_Gorgon": (255, 60, 60),
                  "ThornStalker": (170, 230, 90), "BriarBrute": (110, 170, 60), "RootWarden": (255, 60, 60),
                  "FrostImp": (150, 232, 255), "GlacialGargoyle": (72, 160, 255), "Boss_FrostRevenant": (255, 60, 60)}
    for sid, arch, level, role, (x, z), leash in ENEMY_SPAWNS + BRIAR_SPAWNS + GLACIER_SPAWNS:
        cx, cz = px(x, z)
        rr = leash * scale
        draw.ellipse([cx - rr, cz - rr, cx + rr, cz + rr], outline=(*arch_color[arch], 90))
        dot = 9 if role == "boss" else 6
        draw.ellipse([cx - dot, cz - dot, cx + dot, cz + dot], fill=arch_color[arch], outline=(0, 0, 0))
        draw.text((cx + 9, cz - 7), f"{arch.replace('Iron', '').replace('Boss_', '').replace('Root', 'Root ')} L{level}",
                  fill=(255, 255, 255), font=font)
    for name, (x, z) in (("Quest Master", (15, 50)), ("Merchant", (-63, -24.6)), ("Skill Trainer", (58, -12)),
                         ("Rebirth", (64, 22)), ("Vaultkeeper", (-20, 49)), ("Spin Wheel", (22, 30)), ("Travel board", (-16, -40))):
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
    dim((-110, 472), (110, 472), "Quarry 220 × 304: rim Y10 / mid Y6 / pit Y2", 26)
    dim((-118, 940), (118, 940), "Briarwood 236 × 468 at Y2", 26)
    dim((-462, -132), (-116, -132), "Frostbound Glacier: hollow Y10 / lake Y20 / ridge + forecourt Y30", -22)
    draw.text((pad, h - pad + 18), "Hearthmere + Iron Lowlands + Briarwood + Frostbound Glacier — map_forge top-down (1 grid = 50 studs, +Z down)",
              fill=(230, 230, 230), font=font_b)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"[map_forge] preview {path.relative_to(ROOT)} ({w}×{h})")


if __name__ == "__main__":
    main()
