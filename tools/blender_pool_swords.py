#!/usr/bin/env python3
"""blender_pool_swords.py -- a unique Blender mesh for every pool sword (BossWeapons.luau).

The brief is docs/prompts/pool_swords_blender.md: read it before adding a design. This forge
reuses the boss forge (tools/blender_boss_swords.py) for the Forge class, the layout constants,
the helpers, finish(), material(), the previews and the contact sheet, and adds the checks the
pool swords must also pass:
  * the build is at true scale: finish()'s normalisation moves nothing (+-0.002)
  * nothing but the guard reaches past |z| 0.122 (Blender Z = game width)
  * every colour slot passes the HSV rule (calm: s <= 0.22 and v >= 0.90; vivid: s >= 0.60 and
    v >= 0.85), >= 3 slots, calm area >= 20 %, vivid area >= 15 %, every slot >= 2 % of the area
  * the tier's triangle budget
  * side-silhouette IoU <= 0.85 against every other sword in the pool, the eight signature swords
    and the bandit template (written to silhouette_<pool>.csv)

Run with the Blender Python module (pip install "bpy==4.2.*" numpy pillow):
    python3 tools/blender_pool_swords.py [--pool=IronLowlands] [--only=Sword_PitShiv,...]
                                         [--no-preview] [--keep-previews]
Writes assets/swords/pool/<MeshKey>.glb, manifest.json, preview_<pool>.png, silhouette_<pool>.csv.
Never run it while Roblox Studio is open (16 GB machine).
"""
import colorsys
import csv
import importlib.util
import json
import math
import pathlib
import sys
import tempfile

import bpy
import bmesh
from mathutils import Vector

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"

# the boss forge reads sys.argv at import; hide ours from it
_argv, sys.argv = sys.argv, [sys.argv[0]]
_spec = importlib.util.spec_from_file_location("blender_boss_swords", TOOLS / "blender_boss_swords.py")
B = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(B)
_spec = importlib.util.spec_from_file_location("check_sword_glb", TOOLS / "check_sword_glb.py")
CHK = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(CHK)
sys.argv = _argv

Forge, P = B.Forge, B.P
TIP_Y, POMMEL_Y = B.TIP_Y, B.POMMEL_Y
GUARD_Y0, GUARD_Y1, GRIP_Y0, GRIP_Y1 = B.GUARD_Y0, B.GUARD_Y1, B.GRIP_Y0, B.GRIP_Y1
BLADE_ROOT_Y, GUARD_HALF_SPAN, GRIP_R = B.BLADE_ROOT_Y, B.GUARD_HALF_SPAN, B.GRIP_R
lerp, smooth, chaikin, star = B.lerp, B.smooth, B.chaikin, B.star
blade_rings, stations_from, grip_bands, guard_bar = B.blade_rings, B.stations_from, B.grip_bands, B.guard_bar

OUT = ROOT / "assets" / "swords" / "pool"
PREVIEW, KEEP_PREVIEWS, ONLY, POOL = True, False, None, None
for a in sys.argv[1:]:
    if a == "--no-preview":
        PREVIEW = False
    elif a == "--keep-previews":
        KEEP_PREVIEWS = True
    elif a.startswith("--only="):
        ONLY = set(a.split("=", 1)[1].split(","))
    elif a.startswith("--pool="):
        POOL = a.split("=", 1)[1]
    elif not a.startswith("--"):
        OUT = pathlib.Path(a)

# ----------------------------------------------------------------------------- palette additions
# Two boss-forge entries fail the HSV rule (magenta s 0.50, leaf v 0.82); pool swords use these.
P.update({
    "magenta_hot": (255, 96, 255), "leaf_bright": (56, 224, 96), "deep_violet": (96, 32, 224),
    "basalt": (226, 80, 52), "amber": (255, 196, 72), "hot_pink": (255, 96, 150), "duck": (255, 226, 80),
    "lemon": (255, 236, 90), "caramel": (255, 160, 60), "pale_sky": (214, 238, 255),
    "pale_peach": (255, 232, 208), "pale_lilac": (250, 226, 255), "lime_green": (150, 255, 96),
    "mint_bright": (96, 255, 196), "lodestone": (255, 220, 72), "honey": (255, 204, 72),
})

PROTRUSION = 0.122
# Triangle budgets AFTER finish()'s bevel, which roughly triples a part's raw count (the eight
# signature swords land at 3,292-5,380 through the same bevel). The budget keeps weight in step with
# the ladder; visual weight against the signatures is judged on the contact sheet, not here.
TIERS = {1: (1800, 3200), 2: (2600, 4800), 3: (3400, 6000), 4: (3800, 7000)}
SIGNATURES = ["Boss_Gorgon", "Boss_FrostRevenant", "Boss_InfernalColossus", "Boss_VoidWraith",
              "Boss_CelestialTitan", "RootWarden", "DrownedBellwarden", "TempestWarden", "SwordMeshTemplate"]


def hsv_class(rgb):
    _, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
    if s <= 0.22 and v >= 0.90:
        return "calm"
    if s >= 0.60 and v >= 0.85:
        return "vivid"
    return None


# ----------------------------------------------------------------------------- pool forge
class PoolForge(Forge):
    """Forge plus flat-shaded parts: faces of objects passed to flat() keep hard facets after
    finish()'s smooth-by-angle (which otherwise overrides any per-face use_smooth)."""

    def flat(self, obj):
        attr = obj.data.attributes.get("flat") or obj.data.attributes.new("flat", "INT", "FACE")
        for i in range(len(obj.data.polygons)):
            attr.data[i].value = 1
        return obj

    def orient(self, obj, rot=(0, 0, 0), loc=(0, 0, 0), scale=(1, 1, 1)):
        obj.rotation_euler, obj.location, obj.scale = rot, loc, scale
        self.apply_transform(obj)
        return obj

    def finish(self, name):
        sword, norm = super().finish(name)
        attr = sword.data.attributes.get("flat")
        if attr:
            for poly, a in zip(sword.data.polygons, attr.data):
                if a.value:
                    poly.use_smooth = False
        return sword, norm


def rim_disc(f, name, centre_y, r, half_x, colour, segs=28):
    """A disc facing the side view (axis along X)."""
    d = f.lathe(name, [(0.0, -half_x), (r, -half_x), (r, half_x), (0.0, half_x)], colour, segs=segs)
    return f.orient(d, rot=(0, 0, math.radians(90)), loc=(0, centre_y, 0))


def rod(f, name, a, b, r, colour, segs=12):
    """A cylinder from point a to point b (Blender coords)."""
    a, b = Vector(a), Vector(b)
    length = (b - a).length
    c = f.lathe(name, [(0.0, 0.0), (r, 0.0), (r, length), (0.0, length)], colour, segs=segs)
    q = Vector((0, 1, 0)).rotation_difference((b - a).normalized())
    c.rotation_mode = "QUATERNION"
    c.rotation_quaternion = q
    c.location = a
    f.apply_transform(c)
    return c


def through_cutter(f, name, centre_y, centre_z, r, colour, segs=28, depth=0.12):
    """A cylinder along X, long enough to pass through any blade: a round hole cutter."""
    c = f.lathe(name, [(0.0, -depth), (r, -depth), (r, depth), (0.0, depth)], colour, segs=segs)
    return f.orient(c, rot=(0, 0, math.radians(90)), loc=(0, centre_y, centre_z))


# ----------------------------------------------------------------------------- IronLowlands
# The quarry gang's everyday blades. Calm: sky_white, cream, cream_grip. Accents: coral, toy_blue,
# orange, gold, amber. Motifs: picks, rivets, cart plate, bandanas, rulers, magnets, lodestone.

def design_quarry_shank(f):
    """Quarry Shank -- a pickaxe spike reground into a blade. A narrow rectangular-section cream
    spike with an orange tip cap, a curved orange pick-head for a guard, a cream grip taped with
    toy-blue bands, and a coral cloth knot for a pommel. Calm: cream. Vivid: orange, toy_blue, coral."""
    n = 26
    rings = []
    for i in range(n):
        y = BLADE_ROOT_Y + (TIP_Y - BLADE_ROOT_Y) * i / (n - 1)
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        k = 1.0 if t < 0.62 else max(1.0 - smooth((t - 0.62) / 0.38), 0.03)
        w, th = 0.046 * k * lerp(1.0, 0.85, t), 0.03 * max(k, 0.12) * lerp(1.0, 0.8, t)
        rings.append([(th, y, -w), (th, y, w), (-th, y, w), (-th, y, -w)])
    cap_from = int(n * 0.72)
    f.loft("Spike", rings, lambda i, k: "orange" if i >= cap_from else "cream", "orange")
    # pick head: curved bar, the ends dip toward the pommel, flat end faces at +-0.13
    top = [(GUARD_Y1 + 0.004 - 0.022 * (z / GUARD_HALF_SPAN) ** 2, z) for z in [GUARD_HALF_SPAN * (k / 4 - 1) for k in range(9)]]
    bot = [(y - 0.036, z) for y, z in reversed(top)]
    f.prism("PickHead", top + bot, 0.05, "orange")
    grip_bands(f, "cream_grip", "toy_blue", bands=3, r=0.036)
    f.lathe("Collar", [(0.0, GRIP_Y0 - 0.012), (0.042, GRIP_Y0 - 0.012), (0.042, GRIP_Y0 + 0.004), (0.0, GRIP_Y0 + 0.004)], "toy_blue", segs=20)
    f.sphere("KnotA", (0.0, POMMEL_Y + 0.03, 0.014), 0.03, "coral", segs=14, rings=7)
    f.sphere("KnotB", (0.0, POMMEL_Y + 0.03, -0.014), 0.03, "coral", segs=14, rings=7)
    return {"design": "Quarry Shank", "concept": "a pickaxe spike reground into a blade", "tier": 1,
            "calm": ["cream", "cream_grip"], "vivid": ["orange", "toy_blue", "coral"]}


def design_toolhouse_cleaver(f):
    """Toolhouse Cleaver -- the heavy chopper off the toolhouse wall. A narrow orange neck that
    flares into a tall squared chopping head (the silhouette is a hatchet-cleaver, not the Warden's
    broad slab), a sky-white edge, a toy-blue spine cap and a hang hole in the head's top corner, a
    toy-blue bar guard, a cream grip with orange rivets and a hook ring for a pommel.
    Calm: sky_white, cream_grip. Vivid: orange, toy_blue."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        head = smooth((t - 0.34) / 0.12)                      # neck -> head flare at a third of the way
        zb = lerp(-0.034, -0.03, head)
        ze = lerp(0.036, 0.112, head)
        if t > 0.95:                                          # a squared, softly clipped end
            ze = lerp(0.112, 0.07, (t - 0.95) / 0.05)
        return zb, ze, lerp(0.028, 0.02, t)
    st = stations_from(fn, 26)
    rings, roles = blade_rings(st, 0.03, False)
    blade = f.loft("Blade", rings, ["orange" if r == "body" else "sky_white" for r in roles], "orange")
    f.cut(blade, through_cutter(f, "HangHole", 0.41, -0.004, 0.018, "toy_blue", segs=20))
    spine = []
    for y, zb, ze, th in st[:-2]:
        tt = th + 0.005
        spine.append([(tt, y, zb - 0.003), (tt, y, zb + 0.018), (-tt, y, zb + 0.018), (-tt, y, zb - 0.003)])
    f.loft("SpineCap", spine, ["toy_blue"] * 4, "toy_blue")
    guard_bar(f, "toy_blue", half_x=0.046)
    grip_bands(f, "cream_grip", "cream_grip", bands=0)
    for k in range(3):
        y = GRIP_Y0 + (GRIP_Y1 - GRIP_Y0) * (k + 1) / 4
        for side in (1, -1):
            f.sphere(f"Rivet{k}{side}", (side * GRIP_R, y, 0.0), 0.014, "orange", segs=12, rings=6)
    f.torus_yz("HookRing", POMMEL_Y + 0.03, 0.0, 0.019, 0.011, "toy_blue", seg=20, tube=12)
    return {"design": "Toolhouse Cleaver", "concept": "a hatchet-headed chopper off the toolhouse wall", "tier": 2,
            "calm": ["sky_white", "cream_grip"], "vivid": ["orange", "toy_blue"]}


def design_bandits_machete(f):
    """Bandit's Machete -- the quarry's first real sword. A long sky-white machete with a belly curve
    and a coral edge, a coral bandana knotted round the top of the grip with two tails hanging down
    each face, an orange bar guard, a cream grip with toy-blue bands and a toy-blue bird's-head
    pommel. Calm: sky_white, cream_grip. Vivid: coral, orange, toy_blue."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        zb = -0.042 if t < 0.8 else lerp(-0.042, 0.02, smooth((t - 0.8) / 0.2))
        ze = lerp(0.046, 0.082, smooth(t / 0.7)) if t < 0.78 else lerp(0.082, 0.02, smooth((t - 0.78) / 0.22))
        return zb, ze, lerp(0.026, 0.014, t)
    rings, roles = blade_rings(stations_from(fn, 30), 0.028, False)
    f.loft("Blade", rings, ["sky_white" if r == "body" else "coral" for r in roles], "sky_white")
    guard_bar(f, "orange", half_x=0.044)
    grip_bands(f, "cream_grip", "toy_blue", bands=2)
    # the bandana: a knot band round the grip top and a tail pair on each face
    f.lathe("Bandana", [(0.0, GRIP_Y1 - 0.045), (0.047, GRIP_Y1 - 0.045), (0.05, GRIP_Y1 - 0.02), (0.047, GRIP_Y1 + 0.002), (0.0, GRIP_Y1 + 0.002)], "coral", segs=20)
    for side in (1, -1):
        for k, (dz, drop) in enumerate(((0.016, 0.085), (-0.016, 0.07))):
            y0 = GRIP_Y1 - 0.04
            tail = [(y0, dz - 0.011), (y0, dz + 0.011), (y0 - drop, dz + 0.016 + 0.01 * k), (y0 - drop + 0.012, dz - 0.004)]
            f.prism(f"Tail{side}{k}", tail, 0.008, "coral", x_centre=side * (GRIP_R + 0.012))
    head = f.lathe("BirdHead", [(0.0, POMMEL_Y), (0.03, POMMEL_Y + 0.008), (0.04, POMMEL_Y + 0.03), (0.036, POMMEL_Y + 0.052), (0.0, POMMEL_Y + 0.06)], "toy_blue", segs=20)
    f.prism("Beak", [(POMMEL_Y + 0.012, 0.03), (POMMEL_Y + 0.04, 0.03), (POMMEL_Y + 0.02, 0.066)], 0.02, "orange")
    return {"design": "Bandit's Machete", "concept": "a camp machete with the bandit's bandana tied on", "tier": 2,
            "calm": ["sky_white", "cream_grip"], "vivid": ["coral", "orange", "toy_blue"]}


def design_rivetsteel_blade(f):
    """Rivetsteel Blade -- riveted from cart plate. A straight double-edged sky-white blade built from
    three overlapping plates, each stepping thinner with a visible lip, gold rivets at every joint, a
    riveted toy-blue plate guard, a cream grip and an orange cart-wheel pommel.
    Calm: sky_white, cream_grip. Vivid: coral, gold, toy_blue, orange."""
    # each plate is narrower than the one below it: the outline steps in at every joint
    segments = [(BLADE_ROOT_Y, 0.035, 0.031, 0.025, 0.084), (0.025, 0.245, 0.026, 0.020, 0.068), (0.235, TIP_Y, 0.021, 0.013, 0.054)]
    for s, (y0, y1, th0, th1, w0) in enumerate(segments):
        def width(y, y0=y0, y1=y1, w0=w0, last=(s == 2)):
            u = (y - y0) / (y1 - y0)
            return w0 if not last or u < 0.55 else lerp(w0, 0.008, smooth((u - 0.55) / 0.45))
        st = [(y, -width(y), width(y), lerp(th0, th1, (y - y0) / (y1 - y0))) for y in [y0 + (y1 - y0) * i / 6 for i in range(7)]]
        rings, roles = blade_rings(st, 0.024, True)
        f.loft(f"Plate{s}", rings, ["sky_white" if r == "body" else "coral" for r in roles], "sky_white")
    for yj in (0.03, 0.24):
        for z in (0.0,):
            for side in (1, -1):
                f.sphere(f"Rivet{yj}{z}{side}", (side * 0.028, yj, z), 0.013, "gold", segs=12, rings=6)
    guard_bar(f, "toy_blue", half_x=0.044)
    for z in (-0.095, 0.095):
        for side in (1, -1):
            f.sphere(f"GuardRivet{z}{side}", (side * 0.044, (GUARD_Y0 + GUARD_Y1) / 2, z), 0.014, "gold", segs=12, rings=6)
    grip_bands(f, "cream_grip", "toy_blue", bands=2)
    wy = POMMEL_Y + 0.037
    f.torus_yz("Wheel", wy, 0.0, 0.028, 0.009, "orange", seg=20, tube=12)
    for a in range(4):
        ang = math.pi / 4 + a * math.pi / 2
        rod(f, f"Spoke{a}", (0, wy, 0), (0, wy + 0.028 * math.sin(ang), 0.028 * math.cos(ang)), 0.007, "orange", segs=8)
    f.sphere("Hub", (0, wy, 0), 0.012, "toy_blue", segs=10, rings=6)
    return {"design": "Rivetsteel Blade", "concept": "a blade riveted together from three cart plates", "tier": 2,
            "calm": ["sky_white", "cream_grip"], "vivid": ["coral", "gold", "toy_blue", "orange"]}


def design_foremans_longsword(f):
    """Foreman's Longsword -- kept sharp out of spite. A toy-blue longsword with sky-white edges and a
    raised cream measuring-ruler fuller with notched ticks, a set-square guard, an orange grip with a
    coral wrap and a gold pocket-watch pommel with a cream face.
    Calm: sky_white, cream. Vivid: toy_blue, orange, coral, gold."""
    def fn(y):
        # parallel like a ruler, ending in a chisel: the back edge runs straight to the tip, the
        # front edge cuts across at an angle
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        zb = -0.058 if t < 0.8 else lerp(-0.058, 0.036, (t - 0.8) / 0.2)
        return zb, 0.058 if t < 0.97 else lerp(0.058, 0.04, (t - 0.97) / 0.03), lerp(0.027, 0.016, t)
    st = stations_from(fn, 28)
    rings, roles = blade_rings(st, 0.026, True)
    f.loft("Blade", rings, ["toy_blue" if r == "body" else "sky_white" for r in roles], "toy_blue")
    ruler = []
    for y, zb, ze, th in st[1:-7]:
        tt = th + 0.006
        ruler.append([(tt, y, -0.022), (tt, y, 0.022), (-tt, y, 0.022), (-tt, y, -0.022)])
    strip = f.loft("Ruler", ruler, ["cream"] * 4, "cream")
    y_end = st[-8][0]
    k = 0
    y = BLADE_ROOT_Y + 0.05
    while y < y_end - 0.03:
        depth = 0.02 if k % 2 == 0 else 0.011
        c = f.prism(f"Tick{k}", [(y - 0.008, 0.024 - depth), (y + 0.008, 0.024 - depth), (y + 0.008, 0.04), (y - 0.008, 0.04)], 0.05, "toy_blue")
        f.cut(strip, c)
        y += 0.05
        k += 1
    # set-square guard: a tall hub sloping down to flat ends at +-0.13
    sq = [(GUARD_Y0, -GUARD_HALF_SPAN), (GUARD_Y0, GUARD_HALF_SPAN), (GUARD_Y0 + 0.028, GUARD_HALF_SPAN), (-0.162, 0.03),
          (-0.162, -0.03), (GUARD_Y0 + 0.028, -GUARD_HALF_SPAN)]
    f.prism("SetSquare", sq, 0.042, "orange")
    grip_bands(f, "orange", "coral", bands=3)
    wy = POMMEL_Y + 0.046
    rim_disc(f, "WatchFace", wy, 0.036, 0.02, "cream", segs=20)
    f.torus_yz("WatchRim", wy, 0.0, 0.037, 0.009, "gold", seg=20, tube=12)
    for side in (1, -1):
        f.prism(f"HandA{side}", [(wy - 0.003, -0.007), (wy + 0.024, -0.007), (wy + 0.024, 0.007), (wy - 0.003, 0.007)], 0.004, "toy_blue", x_centre=side * 0.022)
        f.prism(f"HandB{side}", [(wy - 0.007, -0.003), (wy + 0.007, -0.003), (wy + 0.007, 0.02), (wy - 0.007, 0.02)], 0.004, "toy_blue", x_centre=side * 0.022)
    return {"design": "Foreman's Longsword", "concept": "the foreman's longsword with a ruler fuller and a pocket watch", "tier": 3,
            "calm": ["sky_white", "cream"], "vivid": ["toy_blue", "orange", "coral", "gold"]}


def design_lodestone_edge(f):
    """Lodestone Edge (Relic) -- a splinter of the quarry's singing lodestone, edged in gold. A
    faceted crystal blade, lodestone-gold faces and sky-white facet chamfers, two raised toy-blue
    music notes near the root, a coral horseshoe-magnet guard with sky-white poles, a toy-blue grip
    with gold bands and a floating amber stone in a gold ring for a pommel.
    Calm: sky_white. Vivid: lodestone, coral, toy_blue, gold, amber."""
    n = 11
    rings = []
    for i in range(n):
        y = BLADE_ROOT_Y + (TIP_Y - BLADE_ROOT_Y) * i / (n - 1)
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = (lerp(0.062, 0.094, t / 0.22) if t < 0.22 else lerp(0.094, 0.008, (t - 0.22) / 0.78)) * (1.0 + 0.07 * ((-1) ** i))
        th = lerp(0.03, 0.013, t)
        rings.append([(0.0, y, w), (th, y, 0.45 * w), (th, y, -0.45 * w), (0.0, y, -w), (-th, y, -0.45 * w), (-th, y, 0.45 * w)])
    f.flat(f.loft("Crystal", rings, lambda i, k: "lodestone" if k in (1, 4) else "sky_white", "lodestone"))
    # horseshoe magnet: a U opening toward the blade, outer faces flat at +-0.13 in the guard band
    outer, inner = [], []
    for k in range(13):
        a = math.pi * k / 12
        outer.append((-0.232 - 0.034 * math.sin(a), GUARD_HALF_SPAN * math.cos(a)))
        inner.append((-0.232 - 0.004 * math.sin(a), 0.072 * math.cos(a)))
    arms_bottom = [(-0.2, GUARD_HALF_SPAN)] + outer + [(-0.2, -GUARD_HALF_SPAN), (-0.2, -0.072)] + inner[::-1] + [(-0.2, 0.072)]
    f.prism("Magnet", arms_bottom, 0.04, "coral")
    for side in (1, -1):
        pole = [(-0.2, side * 0.072), (-0.2, side * GUARD_HALF_SPAN), (-0.176, side * GUARD_HALF_SPAN), (-0.176, side * 0.072)]
        f.prism(f"Pole{side}", pole if side > 0 else pole[::-1], 0.04, "sky_white")
    # music notes on both faces
    for side in (1, -1):
        for j, (ny, nz) in enumerate(((-0.10, -0.025), (-0.02, 0.022))):
            th = 0.03 - 0.004 * j
            head = rim_disc(f, f"NoteHead{side}{j}", ny, 0.014, 0.005, "toy_blue", segs=16)
            head.location = (side * (th + 0.003), 0, nz)
            f.apply_transform(head)
            f.prism(f"NoteStem{side}{j}", [(ny, nz + 0.008), (ny + 0.05, nz + 0.008), (ny + 0.05, nz + 0.022), (ny, nz + 0.022)], 0.005, "toy_blue", x_centre=side * (th + 0.003))
    grip_bands(f, "toy_blue", "gold", bands=2)
    f.lathe("Collar", [(0.0, GRIP_Y0 - 0.012), (0.044, GRIP_Y0 - 0.012), (0.044, GRIP_Y0 + 0.004), (0.0, GRIP_Y0 + 0.004)], "gold", segs=20)
    sy = POMMEL_Y + 0.043
    f.torus_yz("StoneRing", sy, 0.0, 0.034, 0.008, "gold", seg=24, tube=12)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.026)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((0, sy, 0)))
    verts = [tuple(v.co) for v in bm.verts]
    faces = [tuple(v.index for v in fc.verts) for fc in bm.faces]
    bm.free()
    f.flat(f.mesh_object("Stone", verts, faces, "lodestone"))
    return {"design": "Lodestone Edge", "concept": "a singing lodestone crystal set in a horseshoe magnet", "tier": 4,
            "calm": ["sky_white"], "vivid": ["lodestone", "coral", "toy_blue", "gold"]}


# ----------------------------------------------------------------------------- Briarwood
# Pale leaf against lime, bright leaf green, timber orange and bloom yellow. Each design owns
# its outline and guard. Helpers here only build the repeated leaves, ribs and curved branches.

def briar_leaf(f, name, y0, z0, y1, z1, width, colour, half_x=0.012, x=0.0):
    """A thick, pointed leaf with a lenticular outline, entirely inside its stated endpoints."""
    dy, dz = y1 - y0, z1 - z0
    length = math.hypot(dy, dz)
    ny, nz = -dz / length, dy / length
    outline = []
    for t, w in ((0, 0.12), (0.22, 0.78), (0.48, 1), (0.74, 0.68), (1, 0.12),
                 (0.74, -0.68), (0.48, -1), (0.22, -0.78)):
        outline.append((y0 + t * dy + w * width * ny, z0 + t * dz + w * width * nz))
    return f.prism(name, outline, half_x, colour, x_centre=x)


def briar_tube(f, name, points, radius, colour, segs=12):
    """A round branch following a Y-Z path, with X thickness independent of side curvature."""
    rings = []
    for i, (y, z) in enumerate(points):
        a, b = points[max(0, i - 1)], points[min(len(points) - 1, i + 1)]
        dy, dz = b[0] - a[0], b[1] - a[1]
        ll = math.hypot(dy, dz)
        rings.append([(radius * math.cos(2 * math.pi * k / segs),
                       y - dz / ll * radius * math.sin(2 * math.pi * k / segs),
                       z + dy / ll * radius * math.sin(2 * math.pi * k / segs)) for k in range(segs)])
    return f.loft(name, rings, [colour] * segs, colour)


def briar_rib(f, name, stations, offset, width, colour, extra=0.008):
    """A broad raised strip on both faces, following the blade; thickness survives the bevel."""
    rings = []
    for y, zb, ze, th in stations:
        c = (zb + ze) / 2 + offset
        rings.append([(th + extra, y, c - width), (th + extra, y, c + width),
                      (-th - extra, y, c + width), (-th - extra, y, c - width)])
    return f.loft(name, rings, [colour] * 4, colour)


def design_thornwood_dirk(f):
    """Thornwood Dirk -- cut from a thorn trunk. One curved pale thorn with a timber collar,
    a knotted bark bar, a timber grip with pale bands and a lime leaf pommel. A lime chamfer
    gives the thorn a readable toy cutting edge. Calm: pale_leaf. Vivid: timber, lime."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.072 * t * t
        w = lerp(0.062, 0.007, t ** 0.65)
        return c - w, c + w, lerp(0.029, 0.013, t)
    st = stations_from(fn, 24)
    rings, roles = blade_rings(st, 0.018, True)
    f.loft("Thorn", rings, ["pale_leaf" if r == "body" else "lime" for r in roles], "pale_leaf")
    f.lathe("BarkCollar", [(0.0, -0.222), (0.045, -0.222), (0.046, -0.18), (0.0, -0.18)], "timber", segs=16)
    guard_bar(f, "timber", half_x=0.045, half_y=(-0.255, -0.205))
    for z in (-0.078, 0.078):
        f.sphere(f"BarkKnot{z}", (0, -0.218, z), 0.027, "timber", segs=12, rings=6)
    grip_bands(f, "timber", "pale_leaf", bands=2)
    # The flat lower face is exactly -0.5; a pointed or rounded end would retreat under bevel.
    f.prism("LeafPommel", [(-0.5, -0.014), (-0.5, 0.014), (-0.482, 0.052), (-0.456, 0.06),
                           (-0.436, 0.036), (-0.43, 0), (-0.436, -0.036), (-0.456, -0.06), (-0.482, -0.052)], 0.03, "lime")
    return {"design": "Thornwood Dirk", "concept": "a single curved thorn cut from a bark trunk", "tier": 1,
            "calm": ["pale_leaf"], "vivid": ["timber", "lime"]}


def design_sapwood_falchion(f):
    """Sapwood Falchion -- a springy branch bent into an S-shaped lime blade. Three pale grain
    ribs follow the spring, bright leaf prongs form the guard, the timber grip has pale bands,
    and two leaves sprout from the pommel. Calm: pale_leaf. Vivid: lime, leaf_bright, timber."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.033 * math.sin(2 * math.pi * t) + 0.028 * t
        w = lerp(0.047, 0.063, smooth(t / 0.6)) if t < 0.76 else lerp(0.063, 0.008, smooth((t - 0.76) / 0.24))
        return c - w, c + w, lerp(0.028, 0.014, t)
    st = stations_from(fn, 34)
    rings, roles = blade_rings(st, 0.022, False)
    f.loft("SpringBlade", rings, ["lime" if r == "body" else "leaf_bright" for r in roles], "lime")
    for k, offset in enumerate((-0.028, 0.0, 0.028)):
        briar_rib(f, f"Grain{k}", st[2:26 - k * 2], offset, 0.009, "pale_leaf", extra=0.014)
    for sign in (-1, 1):
        outline = [(-0.249, 0.015), (-0.25, 0.09), (-0.238, 0.13), (-0.22, 0.13),
                   (-0.176, 0.078), (-0.184, 0.046), (-0.218, 0.015)]
        poly = [(y, sign * z) for y, z in outline]
        f.prism(f"LeafGuard{sign}", poly if sign > 0 else poly[::-1], 0.048, "leaf_bright")
    grip_bands(f, "timber", "pale_leaf", bands=2)
    f.lathe("SproutStem", [(0.014, -0.5), (0.014, -0.454), (0.0, -0.444)], "timber", segs=16)
    for sign in (-1, 1):
        briar_leaf(f, f"SproutLeaf{sign}", -0.488, 0, -0.438, sign * 0.054, 0.019, "lime", half_x=0.026)
    return {"design": "Sapwood Falchion", "concept": "a springy S-curved branch with three raised grain ribs", "tier": 2,
            "calm": ["pale_leaf"], "vivid": ["lime", "leaf_bright", "timber"]}


def design_bramblecut_sabre(f):
    """Bramblecut Sabre -- a sweeping green sabre that clears bramble by the armful. Five
    timber spine thorns, a broad pale edge, curling timber vine prongs, a pale grip wound with
    a green vine, and three coral raspberries for the pommel. Calm: pale_leaf.
    Vivid: leaf_bright, timber, coral (the sanctioned raspberry pop)."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.052 * t * t
        w = 0.052 if t < 0.78 else lerp(0.052, 0.007, smooth((t - 0.78) / 0.22))
        return c - w, c + w, lerp(0.028, 0.014, t)
    st = stations_from(fn, 28)
    rings, roles = blade_rings(st, 0.031, False)
    f.loft("Sabre", rings, ["leaf_bright" if r == "body" else "pale_leaf" for r in roles], "leaf_bright")
    for k, y in enumerate((-0.08, 0.02, 0.12, 0.22, 0.32)):
        thorn = f.lathe(f"SpineThorn{k}", [(0.018, 0), (0.018, 0.009), (0.010, 0.031), (0, 0.053)], "timber", segs=12)
        f.orient(thorn, rot=(math.radians(-133), 0, 0), loc=(0, y, fn(y)[0] + 0.006))
    guard_bar(f, "timber", half_x=0.048, half_y=(-0.25, -0.217))
    for sign in (-1, 1):
        pts = [(-0.225 + 0.063 * math.sin(a), sign * (0.055 + 0.042 * math.cos(a)))
               for a in [i * math.pi * 1.4 / 14 for i in range(15)]]
        briar_tube(f, f"VineProng{sign}", pts, 0.012, "timber")
    grip_bands(f, "pale_leaf", "pale_leaf", bands=0)
    coils = []
    for k in range(41):
        a = 4 * math.pi * k / 40
        y = -0.442 + 0.166 * k / 40
        coils.append([((0.041 + 0.008 * math.cos(b)) * math.cos(a), y + 0.008 * math.sin(b),
                       (0.041 + 0.008 * math.cos(b)) * math.sin(a)) for b in [2 * math.pi * j / 12 for j in range(12)]])
    f.loft("GripVine", coils, ["leaf_bright"] * 12, "leaf_bright")
    for k, (y, z) in enumerate(((-0.472, -0.023), (-0.472, 0.023), (-0.438, 0))):
        f.sphere(f"Raspberry{k}", (0, y, z), 0.028, "coral", segs=12, rings=6)
    return {"design": "Bramblecut Sabre", "concept": "five bramble thorns and a raspberry cluster on a vine-wrapped sabre", "tier": 2,
            "calm": ["pale_leaf"], "vivid": ["leaf_bright", "timber", "coral"]}


def design_rangers_longblade(f):
    """Ranger's Longblade -- the grove ranger's clean, narrow straight sword. A pale blade with
    lime edges and a green boolean fuller on both faces, a timber bow-arc guard, a green grip
    with pale bands and an acorn pommel. Calm: pale_leaf. Vivid: lime, leaf_bright, timber."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.052, 0.039, t) if t < 0.82 else lerp(0.0413, 0.006, (t - 0.82) / 0.18)
        return -w, w, lerp(0.029, 0.014, t)
    rings, roles = blade_rings(stations_from(fn, 28), 0.015, True)
    blade = f.loft("Longblade", rings, ["pale_leaf" if r == "body" else "lime" for r in roles], "pale_leaf")
    slot = [(-0.145, -0.011), (-0.128, -0.018), (0.352, -0.018), (0.378, -0.008),
            (0.378, 0.008), (0.352, 0.018), (-0.128, 0.018), (-0.145, 0.011)]
    for side in (-1, 1):
        cutter = f.prism(f"FullerCutter{side}", slot, 0.025, "leaf_bright", x_centre=side * 0.037)
        f.sync_materials()
        f.cut(blade, cutter)
    zs = [GUARD_HALF_SPAN * (k / 8 - 1) for k in range(17)]
    top = [(-0.191 - 0.038 * (z / GUARD_HALF_SPAN) ** 2, z) for z in zs]
    f.prism("BowArc", top + [(y - 0.026, z) for y, z in reversed(top)], 0.048, "timber")
    # The bow string is a second slender solid strip, visible across the open crescent.
    f.prism("BowString", [(-0.262, -0.115), (-0.262, 0.115), (-0.247, 0.115), (-0.247, -0.115)], 0.010, "lime")
    grip_bands(f, "leaf_bright", "pale_leaf", bands=3)
    f.lathe("AcornNut", [(0.008, -0.5), (0.022, -0.493), (0.033, -0.478), (0.037, -0.463),
                        (0.036, -0.455), (0, -0.455)], "lime", segs=20)
    f.lathe("AcornCap", [(0, -0.466), (0.047, -0.466), (0.052, -0.456), (0.047, -0.444),
                        (0.03, -0.435), (0.012, -0.432), (0, -0.432)], "timber", segs=20)
    return {"design": "Ranger's Longblade", "concept": "a ranger's straight blade with carved fuller, bow guard and acorn", "tier": 3,
            "calm": ["pale_leaf"], "vivid": ["lime", "leaf_bright", "timber"]}


def design_heartwood_broadsword(f):
    """Heartwood Broadsword -- grown rather than forged. A broad timber blade with green edges,
    three raised pale growth-ring arcs and two lime shoots; root tendrils curl toward the pale
    banded grip, above a concentric tree-ring disc pommel. Calm: pale_leaf.
    Vivid: timber, leaf_bright, lime."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = 0.092 + 0.006 * math.sin(math.pi * t) if t < 0.83 else lerp(0.095, 0.012, (t - 0.83) / 0.17)
        return -w, w, lerp(0.03, 0.014, t)
    rings, roles = blade_rings(stations_from(fn, 26), 0.024, True)
    f.loft("Heartwood", rings, ["timber" if r == "body" else "leaf_bright" for r in roles], "timber")
    for k, r in enumerate((0.027, 0.054, 0.081)):
        angles = [math.radians(-75 + 150 * j / 14) for j in range(15)]
        outer = [(-0.083 + (r + 0.008) * math.cos(a), (r + 0.008) * math.sin(a)) for a in angles]
        inner = [(-0.083 + (r - 0.008) * math.cos(a), (r - 0.008) * math.sin(a)) for a in reversed(angles)]
        f.prism(f"GrowthRing{k}", outer + inner, 0.043, "pale_leaf")
    for k, y in enumerate((0.15, 0.27)):
        briar_leaf(f, f"SpineSprout{k}", y, -0.079, y - 0.057, -0.113, 0.017, "lime", half_x=0.02)
    guard_bar(f, "timber", half_y=(-0.243, -0.218), half_x=0.05)
    for sign in (-1, 1):
        pts = [(-0.228 - 0.084 * math.sin(a), sign * (0.065 + 0.038 * math.cos(a)))
               for a in [j * math.pi * 1.15 / 12 for j in range(13)]]
        briar_tube(f, f"RootTendril{sign}", pts, 0.014, "timber")
    grip_bands(f, "pale_leaf", "leaf_bright", bands=2)
    rim_disc(f, "TreeRingOuter", -0.458, 0.042, 0.026, "timber", segs=24)
    for side in (-1, 1):
        for k, (r, hx, col) in enumerate(((0.032, 0.008, "pale_leaf"), (0.020, 0.008, "timber"))):
            disc = rim_disc(f, f"TreeRing{side}{k}", -0.458, r, hx, col, segs=16)
            f.orient(disc, loc=(side * (0.026 + k * 0.014), 0, 0))
    return {"design": "Heartwood Broadsword", "concept": "living heartwood with growth rings, root guard and sprouting leaves", "tier": 3,
            "calm": ["pale_leaf"], "vivid": ["timber", "leaf_bright", "lime"]}


def design_briar_billhook(f):
    """Briar Billhook -- a hedge tool with a forward beak and a lime inner cutting edge.
    A timber bar ends in lime leaves; three lime thorn nubs stand on a pale grip with timber
    bands, ending in a lime thorn pommel. A broad pale sapwood strip along the spine supplements
    the grip's calm area; the timber face and lime inner edge remain distinct.
    Calm: pale_leaf. Vivid: timber, lime."""
    outer = [(-0.21, -0.044), (0.35, -0.044), (0.455, -0.03), (0.5, 0.012),
             (0.5, 0.044), (0.465, 0.084), (0.376, 0.114), (0.334, 0.102),
             (0.391, 0.064), (0.41, 0.034), (0.38, 0.012), (-0.21, 0.039)]
    inner = [(-0.21, -0.043), (0.349, -0.043), (0.45, -0.025), (0.493, 0.014),
             (0.483, 0.042), (0.452, 0.063), (0.397, 0.083), (0.43, 0.038),
             (0.391, -0.005), (-0.21, 0.014)]
    f.prism("HookEdge", outer, 0.024, "lime")
    f.prism("HookTimber", inner, 0.031, "timber")
    f.prism("SapwoodSpine", [(-0.208, -0.042), (0.337, -0.042), (0.398, -0.032),
                             (0.355, -0.004), (-0.208, -0.004)], 0.041, "pale_leaf")
    # the bar stops inside the leaves: coplanar end faces at +-0.13 z-fought into a dark stripe,
    # so the leaf ends alone carry the flat widest faces
    guard_bar(f, "timber", half_x=0.048, half_y=(-0.247, -0.212), span=0.118)
    for sign in (-1, 1):
        poly = [(-0.242, 0.053), (-0.263, 0.09), (-0.246, 0.13),
                (-0.222, 0.13), (-0.198, 0.092), (-0.215, 0.057)]
        poly = [(y, sign * z) for y, z in poly]
        f.prism(f"LeafEnd{sign}", poly if sign > 0 else poly[::-1], 0.05, "lime")
    grip_bands(f, "pale_leaf", "timber", bands=2)
    for k, y in enumerate((-0.302, -0.362, -0.422)):
        f.prism(f"HiltThorn{k}", [(y + 0.015, -0.032), (y - 0.015, -0.032),
                                 (y - 0.025, -0.066), (y - 0.003, -0.061)], 0.017, "lime")
    f.lathe("ThornPommel", [(0.011, -0.5), (0.024, -0.483), (0.038, -0.45),
                           (0.031, -0.431), (0, -0.431)], "lime", segs=20)
    return {"design": "Briar Billhook", "concept": "a forward-beaked hedge billhook with a thorn-studded hilt", "tier": 2,
            "calm": ["pale_leaf"], "vivid": ["timber", "lime"]}


def design_hedgehog_hooksword(f):
    """Hedgehog Hooksword -- a pointed pale blade above a bristly little hedgehog. A straight
    double-edged pale blade with timber chamfered edges tapering to a normal point, twelve short
    bristles along the back of a side-on hedgehog guard with a pale snout, bloom nose and timber
    eyes, a green grip with bloom bands and a round bloom berry pommel.
    (The original returning J-hook was replaced with a normal point at Alex's request.)
    Calm: pale_leaf. Vivid: timber, leaf_bright, bloom."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.05, 0.06, smooth(t / 0.5)) if t < 0.75 else lerp(0.06, 0.008, smooth((t - 0.75) / 0.25))
        return -w, w, lerp(0.028, 0.014, t)
    rings, roles = blade_rings(stations_from(fn, 26), 0.026, True)
    f.loft("Blade", rings, ["pale_leaf" if r == "body" else "timber" for r in roles], "pale_leaf")
    guard_bar(f, "timber", half_y=(-0.254, -0.222), half_x=0.055)
    dome = [(-0.231, -0.092), (-0.231, 0.092)]
    dome += [(-0.231 + 0.063 * math.sin(a), 0.092 * math.cos(a)) for a in [math.pi * j / 16 for j in range(1, 17)]]
    f.prism("HedgehogBody", dome, 0.046, "pale_leaf")
    # a hedgehog side-on: bristles along its back (the -z end is the rump), a snout and nose
    # pointing out of the +z end, an eye on each face
    for k in range(12):
        a = math.pi * (0.32 + 0.68 * (k + 0.5) / 12)
        pos = Vector((0, -0.232 + 0.062 * math.sin(a), 0.089 * math.cos(a)))
        direction = Vector((0, math.sin(a), math.cos(a)))
        spike = f.lathe(f"Bristle{k}", [(0.012, 0), (0.013, 0.008), (0, 0.030)], "timber", segs=12)
        spike.rotation_mode = "QUATERNION"
        spike.rotation_quaternion = Vector((0, 1, 0)).rotation_difference(direction)
        spike.location = pos
        f.apply_transform(spike)
    snout = f.lathe("Snout", [(0.0, 0.0), (0.03, 0.0), (0.022, 0.022), (0.0, 0.042)], "pale_leaf", segs=16)
    f.orient(snout, rot=(math.radians(-90), 0, 0), loc=(0, -0.214, 0.066))   # lathe +Y -> +Z
    f.sphere("Nose", (0, -0.214, 0.106), 0.014, "bloom", segs=12, rings=6)
    for side in (-1, 1):
        f.sphere(f"Eye{side}", (side * 0.044, -0.206, 0.052), 0.011, "timber", segs=12, rings=6)
    grip_bands(f, "leaf_bright", "bloom", bands=2)
    f.lathe("Berry", [(0.012, -0.5), (0.03, -0.494), (0.04, -0.474), (0.036, -0.452), (0.02, -0.44), (0.0, -0.44)],
            "bloom", segs=20)
    return {"design": "Hedgehog Hooksword", "concept": "a pointed blade over a side-on hedgehog guard with a snout, eyes and back bristles", "tier": 3,
            "calm": ["pale_leaf"], "vivid": ["timber", "leaf_bright", "bloom"]}


def design_hollowbough_claymore(f):
    """Hollowbough Claymore -- the Root Warden's hollow bough, still visited by two bees.
    A parallel timber claymore with a raised pale core and an oval hollow, two striped bloom
    bees with thick pale wings, a leafed branch guard, banded timber grip and bloom honey drop.
    Calm: pale_leaf. Vivid: timber, bloom, lime."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = 0.072 if t < 0.88 else lerp(0.072, 0.018, (t - 0.88) / 0.12)
        return -w, w, lerp(0.029, 0.014, t)
    st = stations_from(fn, 22)
    rings, roles = blade_rings(st, 0.018, True)
    blade = f.loft("Bough", rings, ["timber" if r == "body" else "lime" for r in roles], "timber")
    core = briar_rib(f, "HeartwoodCore", st[:-3], 0, 0.030, "pale_leaf", extra=0.012)
    for target in (blade, core):
        c = through_cutter(f, f"Hollow{target.name}", 0, 0, 0.031, "pale_leaf", segs=24)
        f.orient(c, scale=(1, 3.1, 1), loc=(0, -0.018, 0))
        f.sync_materials()
        f.cut(target, c)
    # Each bee spans the blade, so the same two bees read from either face. Their wings are
    # thick discs; their bands are geometry, not a texture or hairline paint detail.
    for k, (y, z) in enumerate(((0.174, -0.021), (0.328, 0.021))):
        profile = [(0, -0.040), (0.016, -0.034), (0.024, -0.02), (0.024, -0.014),
                   (0.024, -0.004), (0.024, 0.006), (0.024, 0.016), (0.024, 0.018),
                   (0.016, 0.031), (0, 0.037)]
        bee_rings = [[(1.9 * r * math.cos(a), y + by, z + r * math.sin(a))
                      for a in [2 * math.pi * j / 16 for j in range(16)]] for r, by in profile]
        f.loft(f"Bee{k}", bee_rings, lambda i, j: "timber" if i in (3, 5) else "bloom", "bloom")
        for wing in (-1, 1):
            d = rim_disc(f, f"Wing{k}{wing}", 0, 0.021, 0.042, "pale_leaf", segs=12)
            f.orient(d, scale=(1, 1.35, 0.85), loc=(0, y + 0.009, z + wing * 0.033))
    # A forked branch slopes down at the outer ends; broad leaf cuffs distinguish this from
    # Grovebound Bloom's upward twig stubs and from Sapwood's leaf-shaped whole guard.
    for sign in (-1, 1):
        poly = [(-0.239, 0.022), (-0.21, 0.022), (-0.244, 0.13), (-0.272, 0.13)]
        poly = [(y, sign * z) for y, z in poly]
        f.prism(f"Branch{sign}", poly if sign > 0 else poly[::-1], 0.052, "timber")
        briar_leaf(f, f"GuardLeaf{sign}", -0.252, sign * 0.065, -0.188, sign * 0.108, 0.024, "lime", half_x=0.029)
    grip_bands(f, "timber", "pale_leaf", bands=2)
    f.lathe("HoneyDrop", [(0.013, -0.5), (0.033, -0.491), (0.041, -0.475),
                         (0.037, -0.456), (0.022, -0.43), (0.008, -0.412), (0, -0.412)], "bloom", segs=16)
    return {"design": "Hollowbough Claymore", "concept": "a hollow timber claymore with two striped bees and a honey drop", "tier": 4,
            "calm": ["pale_leaf"], "vivid": ["timber", "bloom", "lime"]}


def design_honeycomb_thorn(f):
    """Honeycomb Thorn -- a pale thorn the grove bees built a comb around. Five chunky bloom
    hex cells with shallow honey-coloured recesses wrap the lower blade, with two bloom drips.
    Lime cutting edges, a honey bar with hex ends, banded timber grip and grooved dipper pommel.
    Calm: pale_leaf. Vivid: bloom, honey (the original identity colour), lime, timber."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = 0.072 if t < 0.40 else lerp(0.072, 0.007, ((t - 0.40) / 0.60) ** 0.8)
        return -w, w, lerp(0.029, 0.013, t)
    rings, roles = blade_rings(stations_from(fn, 24), 0.017, True)
    f.loft("Thorn", rings, ["pale_leaf" if r == "body" else "lime" for r in roles], "pale_leaf")
    cells = [(y, z) for y in (-0.139, -0.067) for z in (-0.032, 0.032)] + [(0.005, 0)]
    for k, (y, z) in enumerate(cells):
        poly = [(y + 0.036 * math.cos(a), z + 0.036 * math.sin(a)) for a in [j * math.pi / 3 for j in range(6)]]
        cell = f.flat(f.prism(f"CombCell{k}", poly, 0.047, "bloom"))
        for side in (-1, 1):
            hole = [(y + 0.021 * math.cos(a), z + 0.021 * math.sin(a)) for a in [j * math.pi / 3 for j in range(6)]]
            cutter = f.prism(f"CellRecess{k}{side}", hole, 0.020, "honey", x_centre=side * 0.047)
            f.sync_materials()
            f.cut(cell, cutter)
    for k, (y, z) in enumerate(((-0.12, -0.080), (-0.025, 0.080))):
        drip = f.lathe(f"HoneyDrip{k}", [(0.009, -0.035), (0.018, -0.024), (0.017, -0.01),
                                       (0.008, 0.015), (0.007, 0.035)], "bloom", segs=12)
        f.orient(drip, loc=(0, y, z))
    guard_bar(f, "honey", half_x=0.054, half_y=(-0.25, -0.213), span=0.102)
    radius = 0.036
    for sign in (-1, 1):
        z = sign * (GUARD_HALF_SPAN - radius * math.sin(math.pi / 3))
        poly = [(-0.227 + radius * math.cos(a), z + radius * math.sin(a)) for a in [j * math.pi / 3 for j in range(6)]]
        f.flat(f.prism(f"HexGuard{sign}", poly, 0.051, "bloom"))
    grip_bands(f, "timber", "pale_leaf", bands=2)
    profile = [(0.013, -0.5), (0.031, -0.492), (0.041, -0.481), (0.041, -0.476),
               (0.031, -0.472), (0.031, -0.466), (0.042, -0.462), (0.042, -0.456),
               (0.031, -0.452), (0.031, -0.446), (0.036, -0.441), (0.024, -0.429), (0, -0.426)]
    dipper = [[(r * math.cos(a), y, r * math.sin(a)) for a in [2 * math.pi * j / 16 for j in range(16)]] for r, y in profile]
    f.loft("HoneyDipper", dipper, lambda i, j: "timber" if i in (4, 8) else "bloom", "bloom")
    return {"design": "Honeycomb Thorn", "concept": "a thorn wrapped in recessed honeycomb cells with hanging honey drips", "tier": 4,
            "calm": ["pale_leaf"], "vivid": ["bloom", "honey", "lime", "timber"]}


# key: (pool, tier, design)
DESIGNS = {
    "Sword_QuarryShank": ("IronLowlands", 1, design_quarry_shank),
    "Sword_ToolhouseCleaver": ("IronLowlands", 2, design_toolhouse_cleaver),
    "Sword_BanditsMachete": ("IronLowlands", 2, design_bandits_machete),
    "Sword_RivetsteelBlade": ("IronLowlands", 2, design_rivetsteel_blade),
    "Sword_ForemansLongsword": ("IronLowlands", 3, design_foremans_longsword),
    "Sword_LodestoneEdge": ("IronLowlands", 4, design_lodestone_edge),
    "Sword_ThornwoodDirk": ("Briarwood", 1, design_thornwood_dirk),
    "Sword_SapwoodFalchion": ("Briarwood", 2, design_sapwood_falchion),
    "Sword_BramblecutSabre": ("Briarwood", 2, design_bramblecut_sabre),
    "Sword_RangersLongblade": ("Briarwood", 3, design_rangers_longblade),
    "Sword_HeartwoodBroadsword": ("Briarwood", 3, design_heartwood_broadsword),
    "Sword_BriarBillhook": ("Briarwood", 2, design_briar_billhook),
    "Sword_HedgehogHooksword": ("Briarwood", 3, design_hedgehog_hooksword),
    "Sword_HollowboughClaymore": ("Briarwood", 4, design_hollowbough_claymore),
    "Sword_HoneycombThorn": ("Briarwood", 4, design_honeycomb_thorn),
}

# The other pools live one file per pool in tools/pool_designs/, run in this module's namespace
# (so they see every helper above) in name order: _parts.py (the shared part library) first.
# Each pool file adds its designs with DESIGNS.update({...}).
for _path in sorted((TOOLS / "pool_designs").glob("*.py")):
    exec(compile(_path.read_text(), str(_path), "exec"), globals())


# ----------------------------------------------------------------------------- checks
def slot_areas(forge, sword):
    area = {}
    for poly in sword.data.polygons:
        c = forge.slots[poly.material_index]
        area[c] = area.get(c, 0.0) + poly.area
    total = sum(area.values())
    return {c: a / total for c, a in area.items()}


def pool_checks(key, tier, sword, forge, norm):
    failed = []
    if abs(norm["length_scale"] - 1) > 0.002 or any(abs(c) > 0.002 for c in norm["centre_shift"]):
        failed.append(f"built off-scale (normalise {norm})")
    for v in sword.data.vertices:
        if abs(v.co.z) > PROTRUSION and not (-0.285 <= v.co.y <= -0.165):
            failed.append(f"protrusion |z|={abs(v.co.z):.3f} at y={v.co.y:.3f}")
            break
    shares = slot_areas(forge, sword)
    classes = {c: hsv_class(P[c]) for c in shares}
    bad = [c for c, k in classes.items() if k is None]
    if bad:
        failed.append(f"HSV rule fails for {bad}")
    if len(shares) < 3:
        failed.append(f"only {len(shares)} colour slots")
    calm = sum(s for c, s in shares.items() if classes[c] == "calm")
    vivid = sum(s for c, s in shares.items() if classes[c] == "vivid")
    if calm < 0.20:
        failed.append(f"calm area {calm:.0%} < 20%")
    if vivid < 0.15:
        failed.append(f"vivid area {vivid:.0%} < 15%")
    tiny = [c for c, s in shares.items() if s < 0.02]
    if tiny:
        failed.append(f"slots under 2% of area: {tiny}")
    tris = sum(len(p.vertices) - 2 for p in sword.data.polygons)
    lo, hi = TIERS[tier]
    if not lo <= tris <= hi:
        failed.append(f"{tris} triangles outside T{tier} budget {lo}-{hi}")
    return failed, shares, {"calm": round(calm, 3), "vivid": round(vivid, 3)}, tris


def silhouette(path, W=256, H=1024):
    """Side silhouette of a GLB: triangles projected onto glTF (Y width, Z length)."""
    from PIL import Image, ImageDraw
    gltf, binary = CHK.read_glb(path)
    prim = gltf["meshes"][0]["primitives"][0]
    Pp = CHK.accessor(gltf, binary, prim["attributes"]["POSITION"])
    idx = [i[0] for i in CHK.accessor(gltf, binary, prim["indices"])]
    img = Image.new("1", (W, H), 0)
    dr = ImageDraw.Draw(img)
    to = lambda p: ((p[1] + 0.14) / 0.28 * W, (p[2] + 0.5) * H)
    for i in range(0, len(idx), 3):
        dr.polygon([to(Pp[idx[i]]), to(Pp[idx[i + 1]]), to(Pp[idx[i + 2]])], fill=1)
    import numpy as np
    return np.asarray(img, dtype=bool)


def iou(a, b):
    return float((a & b).sum()) / max(float((a | b).sum()), 1.0)


# ----------------------------------------------------------------------------- main
def main():
    OUT.mkdir(parents=True, exist_ok=True)
    previews_dir = OUT / "previews" if KEEP_PREVIEWS else pathlib.Path(tempfile.mkdtemp(prefix="pool_previews_"))
    previews_dir.mkdir(exist_ok=True)
    manifest_path = OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    built, rows, problems = {}, {}, []
    for key, (pool, tier, build) in DESIGNS.items():
        if (ONLY and key not in ONLY) or (POOL and pool != POOL):
            continue
        forge = PoolForge(key)
        info = build(forge)
        sword, norm = forge.finish(key)
        checks, tris, verts, size = B.check(sword)
        failed = [k for k, ok in checks.items() if not ok]
        more, shares, cv, tris = pool_checks(key, tier, sword, forge, norm)
        failed += more
        atlas_path = previews_dir / f"{key}_atlas.png"
        mat = forge.material(sword, atlas_path)
        glb = OUT / f"{key}.glb"
        bpy.ops.object.select_all(action="DESELECT")
        sword.select_set(True)
        bpy.context.view_layer.objects.active = sword
        bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", export_yup=True, export_materials="EXPORT",
                                  export_image_format="AUTO", use_selection=True, export_apply=True)
        atlas_path.unlink(missing_ok=True)
        gm = B.read_glb_material(glb)
        if not (gm["materials"] == 1 and gm["images"] == 1 and gm["metallic"] == 0.0 and gm["roughness"] == 1.0):
            failed.append(f"material {gm}")
        results, _ = CHK.check(glb)
        failed += [f"check_sword_glb: {k}" for k, ok in results.items() if not ok]
        if failed:
            problems.append((key, failed))
        manifest[key] = {
            "name": info["design"], "key": key, "pool": pool, "tier": tier, "concept": info["concept"],
            "file": glb.name, "bytes": glb.stat().st_size, "triangles": int(tris), "vertices": int(verts),
            "meshSize": [round(s, 5) for s in size],
            "palette": {c: P[c] for c in forge.slots}, "areaShare": {c: round(s, 3) for c, s in shares.items()},
            "calmVivid": cv, "normalise": norm, "checks": "all passed" if not failed else failed,
        }
        built[key] = pool
        print(f"{key:30} T{tier} tris={tris:5} calm={cv['calm']:.0%} vivid={cv['vivid']:.0%} "
              f"slots={len(shares)} {'OK' if not failed else 'FAIL ' + '; '.join(failed)}")
        if PREVIEW:
            side, tq = previews_dir / f"{key}_side.png", previews_dir / f"{key}_three_quarter.png"
            B.render_previews(sword, mat, side, tq)
            rows.setdefault(pool, []).append({
                "boss": info["design"], "design": f"{key}  T{tier}", "body": P[info["vivid"][0]],
                "calm": info["calm"][0], "vivid": info["calm"][1:] + info["vivid"], "side": side, "three_quarter": tq})

    # silhouettes: every built sword against its pool, the signatures and the template
    sig = {s: silhouette(ROOT / "assets" / "swords" / f"{s}.glb") for s in SIGNATURES}
    for pool in sorted(set(built.values())):
        keys = [k for k, p in manifest.items() if p.get("pool") == pool and (OUT / f"{k}.glb").exists()]
        sil = {k: silhouette(OUT / f"{k}.glb") for k in keys}
        others = {**sil, **sig}
        with open(OUT / f"silhouette_{pool}.csv", "w", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(["sword"] + list(others))
            for k in keys:
                row = [round(iou(sil[k], sil_o), 3) if k != o else "" for o, sil_o in others.items()]
                w.writerow([k] + row)
                worst = max(((iou(sil[k], v), o) for o, v in others.items() if o != k), default=(0, None))
                manifest[k]["maxIoU"] = {"iou": round(worst[0], 3), "against": worst[1]}
                if worst[0] > 0.85:
                    problems.append((k, [f"silhouette IoU {worst[0]:.2f} with {worst[1]}"]))
                print(f"  {k:30} max IoU {worst[0]:.2f} vs {worst[1]}")
    manifest_path.write_text(json.dumps(manifest, indent=2))
    for pool, r in rows.items():
        B.contact_sheet(r, OUT / f"preview_{pool}.png")
        print(f"wrote preview_{pool}.png")
    if problems:
        for key, failed in problems:
            print(f"FAIL {key}: {failed}")
        raise SystemExit(1)
    print("all checks passed")


if __name__ == "__main__":
    # The bpy module segfaults while tearing down at interpreter exit (after all work is written);
    # leave through os._exit so the exit status is the build's own: 0 passed, 1 a check failed.
    import os
    code = 0
    try:
        main()
    except SystemExit as e:
        code = e.code if isinstance(e.code, int) else 1
    except Exception:
        import traceback
        traceback.print_exc()
        code = 2
    sys.stdout.flush()
    sys.stderr.flush()
    os._exit(code)
