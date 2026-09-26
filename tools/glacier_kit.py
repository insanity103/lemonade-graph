#!/usr/bin/env python3
"""glacier_kit.py -- the Frostbound Glacier's hero kit, described once and built twice.

Every kit piece (ice cliffs, snowy firs, crystal clusters, the frozen temple, ...) is a list of
simple primitives in the piece's own frame. Two builders read the same list:

  * tools/blender_glacier_kit.py models each piece in Blender as one bevelled mesh (rounded ice
    columns with a crystalline hex section, real cones for the fir tiers and peaks, hex crystals,
    icicles, lumpy snow) and exports assets/glacier/<Key>.glb plus kit.json (each mesh's size and
    centre, measured after the bevel).
  * tools/map_forge.py builds the same piece from SmoothPlastic parts inside a `MeshSlot` model,
    so the zone is complete and playable through Rojo before any mesh is imported. When the GLBs
    are imported into ServerStorage.MapMeshes, lemonade-game/Map/MeshSlots.server.luau swaps each
    slot's parts for its mesh (docs/map/GLACIER.md).

Frame: Roblox axes, studs. The origin is the piece's foot, centred, on the ground; +Y is up and
local -Z is the piece's front (its LookVector), so map_forge turns a piece with yaw_facing().

A primitive is a dict:
  k   kind: ball | drum | block | wedge | cone | shard | icicle
  n   name (unique within the piece)
  s   size (x, y, z); a cone's and a shard's x/z is the base width, y the height
  p   centre, except cone / shard / icicle / drum-on-the-ground, whose p is the centre of the base
      (an icicle's p is its root; it hangs down)
  r   (yaw, pitch, roll) in degrees, applied yaw * pitch(X) * roll(Z); optional
  c   colour (sRGB 0-255)
  top a cone's top width as a fraction of its base (0 = a point); optional
  lumpy   Blender only: jitter the surface of a ball (rocks, snow); optional
  scallop Blender only: a cone's lower rim waves in and out (the snow drape on a fir tier)
  glow    a Neon glow that stays a part after the mesh swap (never in the mesh)
  taper   Blender only: a shard's top ring as a fraction of its base (the spire's tiers narrow)
  hifi    only in the Blender mesh (icicles, flutes, small snow drips: too many parts otherwise)

Parts versions of the richer kinds (map_forge): a cone is a rounded ellipsoid tier, a shard a
block with a turned cube for its tip (the waystones' own crystal recipe), an icicle is skipped.
"""
from __future__ import annotations

import math
import random

# ── Palette (sRGB). Calm near-white snow against saturated ice, crystal and fir accents; the temple
# wears the Frost Revenant's own colours (EnemyOutfits: PARKA 246/250/255, COAT 72/160/255, NIGHT
# 40/72/208, ICE_DEEP 24/140/255, GLOW 150/232/255). Never grey: every pale is tinted sky-blue.
SNOW = (246, 250, 255)          # walked snow and snow caps: the calm surface
SNOW_SHADE = (222, 234, 255)    # drifts and the shaded side of a cap: the same white, one step bluer
SNOW_PATH = (232, 236, 255)     # packed snow on the trails: lavender-white
ICE = (150, 222, 255)           # clear ice: the zone's signature, full chroma
ICE_PALE = (206, 242, 255)      # frosted ice
ICE_DEEP = (64, 166, 255)       # deep ice in the cracks and the column cores
ICE_WALL = (30, 95, 208)        # the glacier walls' shaded vertical faces: deep saturated blue (#1E5FD0)
ICE_WALL_LIT = (46, 116, 224)   # the wall's lit slabs: one step lighter, still deep
ICE_CRAG = (108, 160, 240)      # the crags behind: a big step paler, the first breath of haze
ICE_CRAG_LIT = (128, 176, 246)  # their lit blocks
NAVY = (11, 42, 107)            # crevasse slots cut into the walls (#0B2A6B)
RANGE = (184, 210, 252)         # the far range, hazed: paler than anything nearer, even its shaded east faces
RANGE_DEEP = (150, 186, 248)    # its shaded ridges
COBALT = (48, 110, 235)         # mid cobalt: the crevasse's middle strata
SNOW_WARM = (255, 247, 232)     # the sun on the highest caps: warm top light over the blue slot
ROCK = (200, 204, 255)          # pale periwinkle stone
ROCK_DEEP = (142, 146, 246)     # its shaded mass: the same hue deeper, never charcoal
CRYSTAL = (72, 214, 255)        # cyan crystal
CRYSTAL_VIOLET = (170, 118, 255)
CRYSTAL_PINK = (255, 132, 222)  # the rare warm crystal
FIR = (34, 204, 156)            # teal-green fir: vivid, cooled toward the ice
FIR_DEEP = (22, 170, 146)
FIR_PALE = (132, 238, 196)
BARK = (250, 160, 72)           # caramel toy bark (map_forge BARK)
TEMPLE = (236, 244, 255)        # PARKA: temple masonry, the calm surface
TEMPLE_TRIM = (72, 160, 255)    # COAT: courses, capitals, steps
TEMPLE_NIGHT = (40, 72, 208)    # NIGHT: doorway, banners, visor
GLOW = (150, 232, 255)          # GLOW: the temple's cold fire
GOLD = (255, 206, 24)

KEYS = []  # every piece key, in build order
_BUILDERS = {}


def piece(fn):
    """Register fn (returning the primitive list) under its name in CamelCase."""
    key = "".join(w.capitalize() for w in fn.__name__.split("_"))
    _BUILDERS[key] = fn
    KEYS.append(key)
    return fn


def prim(k, n, s, p, c, r=(0.0, 0.0, 0.0), **kw):
    d = {"k": k, "n": n, "s": tuple(float(v) for v in s), "p": tuple(float(v) for v in p), "c": tuple(c),
         "r": tuple(float(v) for v in r)}
    d.update(kw)
    return d


def build(key):
    return _BUILDERS[key]()


# ── Firs ───────────────────────────────────────────────────────────────────────
def _fir(h, w, tiers, seed, slim=1.0):
    rng = random.Random(seed)
    out = [prim("drum", "Trunk", (w * 0.16, h * 0.24, w * 0.16), (0, -0.4, 0), BARK)]
    for k in range(tiers):
        f = k / tiers
        y0 = h * (0.13 + 0.6 * f)
        th = h * (0.36 - 0.1 * f)
        d = w * (1.0 - 0.66 * f) * slim
        yaw = rng.uniform(0, 360)
        green = (FIR, FIR_DEEP, FIR)[k % 3]
        out.append(prim("cone", f"Tier{k}", (d, th, d), (0, y0, 0), green, (yaw, 0, 0), top=0.12))
        # the snow drape over the tier's upper half: a scalloped white cone in the mesh, a flattened
        # snow puff in parts
        out.append(prim("cone", f"Snow{k}", (d * 0.8, th * 0.56, d * 0.8), (0, y0 + th * 0.5, 0), SNOW,
                        (yaw + 15, 0, 0), top=0.1, scallop=6 + k))
    out.append(prim("ball", "Tip", (w * 0.2, h * 0.1, w * 0.2), (0, h * 0.88, 0), SNOW, (0, 4, 0)))
    return out


@piece
def snow_fir_a():
    return _fir(24.0, 14.0, 4, 11)


@piece
def snow_fir_b():
    return _fir(17.0, 11.0, 3, 12)


@piece
def snow_fir_c():
    return _fir(30.0, 13.0, 5, 13, slim=0.86)


# ── Rocks ──────────────────────────────────────────────────────────────────────
@piece
def snow_rock_a():  # a wide, low boulder with a thick snow cap
    return [
        prim("ball", "Body", (12, 7.4, 10), (0, 2.9, 0), ROCK, (10, 3, -2), lumpy=0.06),
        prim("ball", "Knob", (7, 5.2, 6), (4.2, 2.1, 2.2), ROCK_DEEP, (40, -4, 5), lumpy=0.07),
        prim("ball", "Cap", (8.4, 3.6, 7.2), (-0.3, 6.0, -0.2), SNOW, (12, 2, -3), lumpy=0.04),
        prim("ball", "Drift", (6, 2.2, 5), (-4.8, 0.5, -3.4), SNOW_SHADE, (30, 3, 0)),
    ]


@piece
def snow_rock_b():  # a tall stacked pair
    return [
        prim("ball", "Body", (9, 9.6, 8.4), (0, 4.2, 0), ROCK, (0, 4, 3), lumpy=0.06),
        prim("ball", "Top", (6.4, 6.2, 6), (0.8, 9.4, 0.4), ROCK_DEEP, (25, -5, 4), lumpy=0.07),
        prim("ball", "Cap", (6.2, 2.6, 5.8), (0.9, 12.2, 0.2), SNOW, (20, 3, -2), lumpy=0.03),
        prim("ball", "Ledge", (7, 2.0, 5.4), (-0.6, 7.4, -1.6), SNOW, (0, 5, 3), lumpy=0.03),
        prim("ball", "Drift", (8, 2.4, 5), (1.0, 0.6, -3.4), SNOW_SHADE, (10, 3, 0)),
    ]


@piece
def snow_rock_c():  # a cluster of three small stones: scatter along paths
    return [
        prim("ball", "Big", (6, 4.4, 5.2), (0, 1.7, 0), ROCK, (5, 4, 2), lumpy=0.07),
        prim("ball", "Mid", (4.2, 3.2, 3.8), (4.2, 1.1, 1.2), ROCK_DEEP, (50, -3, 4), lumpy=0.07),
        prim("ball", "Small", (3, 2.2, 2.8), (-3.4, 0.7, 1.8), ROCK, (80, 5, -3), lumpy=0.07),
        prim("ball", "Cap", (4.2, 2.2, 3.6), (-0.2, 3.4, -0.1), SNOW, (5, 3, -2), lumpy=0.04),
        prim("ball", "CapMid", (2.8, 1.5, 2.4), (4.3, 2.4, 1.2), SNOW, (50, 3, 2), lumpy=0.04),
    ]


# ── Ice cliffs ─────────────────────────────────────────────────────────────────
def _on(host_p, host_r, local):
    """A point in a host primitive's frame (its centre, its rotation) as a piece-frame point."""
    return _add(host_p, _apply(rotation(host_r), local))


CLIFF_D = 26.0  # a wall slab's depth


def _slot(out, name, host_p, host_r, local, w, h, roll, depth):
    """A crevasse cut into a leaning face: a NAVY strip inside a slightly wider ICE_DEEP strip,
    both lying in the host block's own frame (so they stay flush with it however it leans), sunk
    into the face with only a hair standing proud. `local` is (x, y) on the face, `depth` the
    host's depth; `roll` a small lean of the slot within the face."""
    fx, fy = local
    r = (host_r[0], host_r[1], host_r[2] + roll)
    out.append(prim("block", f"{name}Deep", (w, h, 1.6), _on(host_p, host_r, (fx, fy, -depth / 2 + 0.6)), ICE_DEEP, r))
    out.append(prim("block", name, (w * 0.42, h * 0.94, 1.6), _on(host_p, host_r, (fx, fy, -depth / 2 + 0.4)), NAVY, r))


def _ice_wall(seed, slabs):
    """A glacier wall after docs/map/glacier_refs/glacier_valley.png: two fat slabs of deep-blue
    ice (ICE_WALL) leaning back 9-16 degrees, a rounded bulge at the foot of one, a pale serac
    leaning out over each crest with its snow cap sunk into it, a snow shelf sunk into the seam
    behind it, one wide two-tone crevasse (NAVY in ICE_DEEP) flush in the upper half of each face,
    and a drift along the foot (map_forge tumbles the rubble in front on whatever floor lies
    there). Every part is chunky: 3-5 big shapes per slab, nothing thin and nothing hovering.
    `slabs` are (w, h, back, roll) per slab; the piece is their widths wide, front local -Z."""
    rng = random.Random(seed)
    total = sum(w for w, *_ in slabs)
    x = -total / 2
    out = []
    D = CLIFF_D
    for i, (w, h, back, roll) in enumerate(slabs):
        cx = x + w / 2
        x += w
        yaw = rng.uniform(-4, 4)
        dz = rng.uniform(-2, 2)
        # the slab: leaning back, its foot sunk, its top set back by the lean
        rb = (yaw, back, roll)
        pb = (cx, h / 2 - 1.5, dz + math.sin(math.radians(back)) * h * 0.25)
        tone = ICE_WALL if i % 2 == 0 else ICE_WALL_LIT
        out.append(prim("block", f"Slab{i}", (w + 1.0, h, D), pb, tone, rb, facet=True))
        if i % 2 == 0:  # a fat rounded bulge at the foot, a little proud of the face
            out.append(prim("ball", f"Bulge{i}", (w * 0.94, h * 0.46, D * 0.8), (cx + rng.uniform(-1.5, 1.5), h * 0.18, dz - D * 0.15),
                            tone, (yaw, rng.uniform(4, 9), rng.uniform(-6, 6)), lumpy=0.05))
        # one wide crevasse in the upper half of the face, clear of the bulge
        sh = h * rng.uniform(0.4, 0.52)
        _slot(out, f"Slot{i}", pb, rb, (rng.uniform(-w * 0.26, w * 0.26), h * 0.46 - sh / 2),
              w * rng.uniform(0.11, 0.16), sh, rng.choice((-1, 1)) * rng.uniform(2, 5), D)
        sx = rng.uniform(-w * 0.1, w * 0.1)
        if i % 2 == 0:
            # the serac: pale ice leaning out over the crest, its foot buried in the slab's top
            hs = h * rng.uniform(0.3, 0.4)
            ws = w * rng.uniform(0.5, 0.64)
            tilt = -rng.uniform(16, 26)
            rs = (yaw + rng.uniform(-6, 6), back + tilt, roll * 0.5 + rng.uniform(-8, 8))
            ps = _on(pb, rb, (sx, h / 2 + hs * 0.36, D * 0.08))
            out.append(prim("block", f"Serac{i}", (ws, hs, D * 0.7), ps, ICE_PALE, rs, facet=True))
            ch = ws * 0.3  # its snow cap, sunk into its top
            out.append(prim("ball", f"Cap{i}", (ws * 0.84, ch, D * 0.55), _on(ps, rs, (0, hs / 2 - ch * 0.45, 0)), SNOW, rs, lumpy=0.06))
            for j in range(2):  # icicles under the serac's lip (mesh only)
                out.append(prim("icicle", f"Icicle{i}_{j}", (1.4, rng.uniform(3, 7), 1.4),
                                _on(ps, rs, ((j - 0.5) * ws * 0.5, -hs / 2 + 0.5, -D * 0.35 + 0.6)), ICE_PALE, hifi=True))
        else:  # a pale shard standing off the crest, snow heaped round its foot
            out.append(prim("shard", f"Crest{i}", (w * 0.22, h * 0.3, D * 0.4), _on(pb, rb, (sx, h / 2 - 3, -D * 0.1)), ICE_PALE,
                            (yaw + rng.uniform(-30, 30), back - 8, roll + rng.uniform(-10, 10))))
        # a snow shelf sunk into the slab's top, behind the serac or round the shard
        out.append(prim("ball", f"Ledge{i}", (w * 0.7, 7.0, D * 0.6), _on(pb, rb, (-sx * 0.5, h / 2 - 2.6, D * 0.14)), SNOW, rb,
                        lumpy=0.06))
    out.append(prim("ball", "Drift", (total * 1.1, 9.0, 20), (0, 1.2, -D / 2 - 4.0), SNOW_SHADE, (0, 3, 0), lumpy=0.03))
    return out


@piece
def ice_cliff_a():
    return _ice_wall(1, ((56, 60, 12, 5), (44, 48, 9, -8)))


@piece
def ice_cliff_b():
    return _ice_wall(2, ((40, 46, 15, -5), (60, 62, 10, 6)))


@piece
def ice_cliff_c():
    return _ice_wall(3, ((52, 56, 11, 4), (34, 40, 16, -7)))


# ── Ice tiers: the corridor's flanking walls, rounded and stacked (round 4) ──
ICE_FLOOR = (168, 236, 255)     # the Frozen Lake terrace: a pale turquoise ice-river floor
RIVER = (72, 196, 255)          # open water in the frozen river: saturated cyan, never navy
MIST = (196, 244, 255)          # the fog banks between the ranks: light cyan
NAVY_FAR = (52, 96, 176)        # crevasse slots in the hazed far rank


def _ice_tier(seed, h, w, n, lean, mirror):
    """A glacier wall after docs/map/glacier_refs/glacier_valley.png, round 4: no boxes. `n` fat
    rounded tiers of deep-blue ice (ellipsoids, ICE_WALL and ICE_WALL_LIT by turns) stacked ~h
    tall at scale 1 and w wide at the foot, each tier narrower than the one under it, sunk a
    little into it, set a few studs back and turned a few degrees, the whole stack leaning
    `lean` degrees forward (local -Z, over the floor it faces) so a row of them funnels a
    corridor; a thick pure-white snow cap sunk into every tier's top (a white ledge between the
    blue tiers, seen along the wall), a snow dome on the summit, one or two two-tone crevasse
    slots (NAVY in ICE_DEEP) flush in the belly of each tier, a rounded foot and a drift.
    map_forge grows the near flanks and cuts the far ones so the walls step down toward the
    vanishing point. Front local -Z."""
    rng = random.Random(seed)
    m = -1 if mirror else 1
    D = w * 0.34
    out = [prim("ball", "Foot", (w * 1.12, h * 0.16, D * 1.15), (m * w * 0.02, h * 0.045, -D * 0.06), ICE_WALL,
                (m * 3, 4, m * 2), lumpy=0.05)]
    slope = math.tan(math.radians(lean))
    base = h * 0.02
    for k in range(n):
        f = k / max(1, n - 1)
        th = h * (0.27 - 0.02 * k)  # 0.27 .. 0.19 of h: the tiers thin a little going up
        tw = w * (1.0 - 0.12 * k)
        td = D * (1.0 - 0.05 * k)
        cy = base + th / 2
        cz = -slope * cy + 2.6 * k + rng.uniform(-1.0, 1.0)  # leaning forward, each tier a ledge back
        r = (rng.uniform(-3, 3) + m * 2.5 * k, -lean + rng.uniform(-2.0, 2.0), m * rng.uniform(-1.5, 3.0))
        p = (m * (w * 0.02 * k) + rng.uniform(-2, 2), cy, cz)
        tone = ICE_WALL if k % 2 == 0 else ICE_WALL_LIT
        out.append(prim("ball", f"Tier{k}", (tw, th, td), p, tone, r, lumpy=0.04))
        # the snow cap sunk into the tier's top: wider than the tier above, so it shows as a white
        # ledge round its foot; the summit gets a dome
        if k < n - 1:
            ch = th * 0.26
            out.append(prim("ball", f"Cap{k}", (tw * 0.96, ch, td * 0.7), _on(p, r, (0, th / 2 - ch * 0.42, -td * 0.02)),
                            SNOW, (r[0], r[1] + 1.5, r[2]), lumpy=0.05))
        else:
            ch = th * 0.5
            out.append(prim("ball", "Dome", (tw * 0.8, ch, td * 0.85), _on(p, r, (m * tw * 0.04, th / 2 - ch * 0.3, 0)), SNOW,
                            (r[0] + m * 6, r[1] + 2, r[2] - m * 3), lumpy=0.06))
        # one wide crevasse in the belly, a second narrow one on the odd tiers
        fx = m * rng.uniform(-0.12, 0.24) * tw
        _slot(out, f"Slot{k}", p, r, (fx, -th * 0.02), tw * rng.uniform(0.05, 0.07), th * 0.44,
              m * rng.uniform(2, 6), td + 1.6)
        if k % 2 == 1:
            _slot(out, f"Slit{k}", p, r, (-fx * 0.8 - m * tw * 0.12, th * 0.04), tw * 0.035, th * 0.32,
                  -m * rng.uniform(3, 8), td + 1.4)
        base += th * 0.86  # the next tier sinks into this one
    out.append(prim("ball", "Drift", (w * 0.9, h * 0.04, D * 0.6), (0, h * 0.006, -D * 0.5), SNOW_SHADE, (0, 3, 0),
                    lumpy=0.03))
    return out


@piece
def ice_tier_a():
    return _ice_tier(61, 200.0, 110.0, 5, 9.0, False)


@piece
def ice_tier_b():
    return _ice_tier(62, 175.0, 96.0, 4, 7.0, True)


# ── Ice spires: the giants, one huge leaning shard at each corner of the valley ──
def _ice_spire(seed, h, w, lean, mirror):
    """One enormous shard of deep-blue ice leaning back `lean` degrees: three tiers of block,
    each narrower, turned a few degrees and leaning a little further than the one under it, so
    the silhouette tapers to a pale turned tip; a buttress leaning the other way off one side, a
    rounded foot, a wide two-tone crevasse in the base and one in the buttress, snow sunk into
    the top tier, a shelf on the base and a drift at the foot. ~h tall at scale 1, w wide.
    Front local -Z."""
    rng = random.Random(seed)
    m = -1 if mirror else 1
    D = w * 0.85
    out = []
    tiers = ((1.0, 0.42, ICE_WALL), (0.68, 0.32, ICE_WALL_LIT), (0.42, 0.28, ICE_WALL))
    pt = rt = th = None
    for t, (fw, fh, tone) in enumerate(tiers):
        tw, tl, td = w * fw, h * fh, D * fw
        if t == 0:
            rt = (rng.uniform(-4, 4), lean, m * rng.uniform(2, 5))
            pt = (0, tl / 2 - 2, math.sin(math.radians(lean)) * tl * 0.5 + 3)
            p1, r1, h1 = pt, rt, tl
        else:
            rt = (rt[0] + m * rng.uniform(8, 14), rt[1] + 4.0, rt[2] + m * 2.5)
            pt = _on(pt, rt, (m * w * 0.03, th / 2 + tl / 2 - tl * 0.14, 0))
        th = tl
        out.append(prim("block", f"Tier{t}", (tw, tl, td), pt, tone, rt, facet=True))
    out.append(prim("shard", "Tip", (tw * 0.66, h * 0.14, td * 0.66), _on(pt, rt, (0, th / 2 - 1.5, 0)), ICE_PALE,
                    (rt[0] + m * 8, rt[1] + 2, rt[2])))
    out.append(prim("ball", "Cap", (tw * 0.92, tw * 0.34, td * 0.8), _on(pt, rt, (0, th / 2 - tw * 0.12, 0)), SNOW, rt,
                    lumpy=0.06))
    out.append(prim("ball", "Foot", (w * 1.15, h * 0.2, D), (m * 3, h * 0.07, -D * 0.12), ICE_WALL, (0, 6, m * 3), lumpy=0.05))
    r3 = (-m * 6, lean * 0.5, -m * 14)
    p3 = (-m * w * 0.55, h * 0.16, D * 0.1)
    out.append(prim("block", "Buttress", (w * 0.7, h * 0.34, D * 0.8), p3, ICE_WALL, r3, facet=True))
    _slot(out, "Slot0", p1, r1, (m * w * 0.1, h1 * 0.06), w * 0.16, h1 * 0.6, m * 4, D)
    _slot(out, "Slot1", p3, r3, (0, 0), w * 0.12, h * 0.2, -m * 8, D * 0.8)
    out.append(prim("ball", "Shelf", (w * 0.7, 6.0, D * 0.5), _on(p1, r1, (-m * w * 0.12, h1 / 2 - 2.4, -D * 0.18)), SNOW, r1,
                    lumpy=0.06))
    out.append(prim("ball", "ButtressSnow", (w * 0.6, 6.0, D * 0.6), _on(p3, r3, (0, h * 0.17 - 2.4, 0)), SNOW, r3, lumpy=0.06))
    out.append(prim("ball", "Drift", (w * 1.6, 10, 24), (0, 1.5, -D / 2 - 6), SNOW_SHADE, (0, 3, 0), lumpy=0.03))
    return out


@piece
def ice_spire_a():
    return _ice_spire(51, 170.0, 40.0, 9.0, False)


@piece
def ice_spire_b():
    return _ice_spire(52, 150.0, 34.0, 7.0, True)


# ── Ice crags: the second rank, giants stepping back and up behind the walls ──
def _ice_crag(seed, mirror):
    """A giant of pale-blue ice (ICE_CRAG, a step hazier than the walls): a huge mass leaning
    back, a higher block leaning over it, a fat rounded shoulder, a pale serac overhanging its
    crest, wide two-tone crevasses flush in the faces, snow sunk into every shelf. ~150 tall at
    scale 1, 172 to the crest. Front local -Z."""
    rng = random.Random(seed)
    m = -1 if mirror else 1
    D = 36.0
    out = []
    r1 = (rng.uniform(-5, 5), 9.0, m * 4.0)
    p1 = (0, 48, 6)
    out.append(prim("block", "Mass", (58, 100, D), p1, ICE_CRAG, r1, facet=True))
    out.append(prim("ball", "Bulge", (56, 48, D * 0.9), (m * 4, 18, -D * 0.16), ICE_CRAG, (0, 6, m * 3), lumpy=0.05))
    r2 = (m * 8, -6.0, -m * 7.0)
    p2 = (m * 8, 112, 12)
    out.append(prim("block", "Upper", (40, 68, D * 0.8), p2, ICE_CRAG_LIT, r2, facet=True))
    r3 = (-m * 14, 4.0, m * 10.0)
    p3 = (-m * 20, 92, 4)
    out.append(prim("block", "Shoulder", (30, 56, 28), p3, ICE_CRAG, r3, facet=True))
    rs = (m * 6, -24.0, m * 8)
    ps = (m * 4, 150, 2)
    out.append(prim("block", "Serac", (30, 30, 22), ps, ICE_PALE, rs, facet=True))
    out.append(prim("shard", "Crest", (12, 22, 10), (m * 10, 160, 8), ICE_PALE, (rng.uniform(-30, 30), -6, m * 10)))
    _slot(out, "Slot0", p1, r1, (-m * 10, 8), 8.0, 50, m * 4, D)
    _slot(out, "Slot1", p2, r2, (-m * 4, -2), 6.0, 36, 5, D * 0.8)
    _slot(out, "Slot2", p3, r3, (m * 4, -2), 4.6, 26, -m * 6, 28)
    out.append(prim("ball", "Cap", (24, 10.0, 16), _on(ps, rs, (0, 15 - 4.0, 0)), SNOW, rs, lumpy=0.06))
    out.append(prim("ball", "UpperSnow", (30, 9.0, 22), _on(p2, r2, (0, 34 - 3.6, 0)), SNOW, r2, lumpy=0.06))
    out.append(prim("ball", "ShoulderSnow", (24, 8.0, 20), _on(p3, r3, (0, 28 - 3.2, 0)), SNOW, r3, lumpy=0.06))
    out.append(prim("ball", "Ledge", (36, 7.0, 14), _on(p1, r1, (m * 4, 50 - 2.6, -D / 2 + 8)), SNOW, r1, lumpy=0.06))
    out.append(prim("ball", "Drift", (70, 10, 22), (0, 1.5, -D / 2 - 5), SNOW_SHADE, (0, 3, 0), lumpy=0.03))
    return out


@piece
def ice_crag_a():
    return _ice_crag(41, False)


@piece
def ice_crag_b():
    return _ice_crag(42, True)


# ── The ridge's broken lip over the lake ───────────────────────────────────────
@piece
def ice_ledge():
    """A broken ice terrace edge, rounded like the tiers (round 4): four fat lumps 12-16 tall of
    deep-blue ice, a NAVY fissure flush in each face, short pale shards, a snow cornice sunk into
    every top, snow banked and a fallen lump at the foot. 40 wide, front -Z."""
    rng = random.Random(31)
    out = []
    for i, cx in enumerate((-14, -4, 6, 15)):
        w, h = rng.uniform(11, 14), rng.uniform(12, 16)
        r = (rng.uniform(-8, 8), -rng.uniform(2, 6), rng.uniform(-6, 6))
        c = (ICE_WALL, ICE_WALL_LIT, ICE_WALL, ICE_WALL_LIT)[i]
        p = (cx, h * 0.46, rng.uniform(-1, 1))
        out.append(prim("ball", f"Block{i}", (w, h, 11), p, c, r, lumpy=0.05))
        out.append(prim("block", f"Fissure{i}", (1.4, h * 0.5, 1.2),
                        _on(p, r, (rng.uniform(-w * 0.2, w * 0.2), -h * 0.05, -5.6)),
                        NAVY, (r[0], r[1], r[2] + rng.uniform(-18, 18))))
        if i % 2 == 0:
            out.append(prim("shard", f"Shard{i}", (4, rng.uniform(5, 8), 3.6), (cx + rng.uniform(-2, 2), h * 0.8, 0),
                            ICE_PALE, (rng.uniform(-40, 40), rng.uniform(-6, 6), rng.uniform(-16, 16))))
        out.append(prim("ball", f"Cornice{i}", (w * 0.95, 3.6, 8.5), _on(p, r, (0, h / 2 - 1.2, -0.5)), SNOW,
                        (r[0], r[1] + 2, r[2]), lumpy=0.04))
    out.append(prim("ball", "Drift", (38, 4.6, 8), (0, 0.5, -7), SNOW_SHADE, (0, 3, 0), lumpy=0.03))
    out.append(prim("ball", "Chunk", (5.6, 3.4, 4.6), (10, 1.2, -9), ICE_PALE, (20, 5, 8), lumpy=0.04))
    return out


# ── Crystals ───────────────────────────────────────────────────────────────────
def _crystals(spec, base):
    out = [prim("ball", "Base", base, (0, 0.5, 0), SNOW, (0, 3, 2), lumpy=0.04)]
    for i, (x, z, h, w, yaw, lean, c) in enumerate(spec):
        out.append(prim("shard", f"Shard{i}", (w, h, w), (x, 0.2, z), c, (yaw, lean, 0)))
    return out


@piece
def crystal_cluster_a():
    return _crystals([(0, 0, 11, 2.6, 10, 4, CRYSTAL), (-2.2, 1.0, 7.5, 2.0, 40, -16, CRYSTAL_VIOLET),
                      (2.0, -0.8, 6.5, 1.8, 75, 18, CRYSTAL), (0.6, 2.2, 4.8, 1.5, 20, 24, ICE_PALE),
                      (-1.2, -2.0, 4.0, 1.3, 60, -22, CRYSTAL_VIOLET)], (8, 2.4, 7))


@piece
def crystal_cluster_b():
    return _crystals([(0, 0, 8, 2.2, 30, -6, CRYSTAL_VIOLET), (1.8, 1.2, 6, 1.7, 5, 18, CRYSTAL_PINK),
                      (-1.8, 0.6, 5.2, 1.6, 50, -20, CRYSTAL_VIOLET), (0.4, -1.8, 4.2, 1.3, 80, 14, ICE_PALE)],
                     (6.4, 2.0, 5.6))


@piece
def crystal_cluster_c():  # a big one for the ridge
    return _crystals([(0, 0, 17, 4.0, 0, 3, CRYSTAL), (-3.4, 1.2, 12, 3.2, 35, -14, CRYSTAL),
                      (3.2, -0.8, 10, 3.0, 70, 15, CRYSTAL_VIOLET), (1.2, 3.2, 7.5, 2.4, 15, 22, ICE_PALE),
                      (-1.6, -3.2, 6.5, 2.2, 55, -24, CRYSTAL), (3.8, 2.8, 5, 1.8, 5, 30, CRYSTAL_PINK)],
                     (13, 3.2, 11))


# ── Crystal geodes and fields ──────────────────────────────────────────────────
def _geode(spec, root):
    """A crystal growth rooted in deep ice: shards fan out of the root, the biggest of them lit
    (Neon). Its origin is the root's foot, so it stands on a ledge of the crevasse wall (yawed to
    face across the slot, its shards leaning out over it: pitch < 0 leans toward the front) or on
    the ground. `spec`: (x, z, height, width, yaw, lean, colour, glow)."""
    out = [prim("ball", "Root", root, (0, root[1] * 0.3, 0), ICE_DEEP, (0, 4, 3), lumpy=0.05)]
    for i, (x, z, h, w, yaw, lean, c, glow) in enumerate(spec):
        out.append(prim("shard", "Core" if i == 0 else f"Shard{i}", (w, h, w), (x, 0.4, z), c, (yaw, lean, 0),
                        glow=glow))
    return out


@piece
def crystal_geode_a():  # a big cyan growth leaning out of a wall
    return _geode([(0, 0, 14, 3.4, 0, -36, CRYSTAL, True), (-2.6, 0.6, 9.5, 2.4, 30, -52, CRYSTAL_VIOLET, False),
                   (2.5, 0.4, 10.5, 2.6, -24, -44, CRYSTAL, True), (0.9, -1.4, 6.2, 1.8, 62, -22, ICE_PALE, False),
                   (-1.5, -1.6, 5.2, 1.6, -58, -28, CRYSTAL, False), (3.3, 1.6, 5.6, 1.7, 14, -62, CRYSTAL_PINK, False),
                   (-3.4, -0.4, 4.4, 1.4, 40, -40, ICE_PALE, False)], (8, 3.2, 6))


@piece
def crystal_geode_b():  # a violet growth, one lit heart
    return _geode([(0, 0, 10, 2.8, 20, -40, CRYSTAL, True), (2.0, 0.8, 7.5, 2.0, -30, -55, CRYSTAL_VIOLET, False),
                   (-2.0, 0.4, 8, 2.1, 45, -48, CRYSTAL_VIOLET, False), (0.6, -1.4, 5, 1.5, 70, -18, CRYSTAL_PINK, False),
                   (-1.2, 1.6, 4.4, 1.3, -60, -64, ICE_PALE, False)], (6.4, 2.6, 5))


def _field(spec, base):
    """A crystal field for the ridge: a snow bank and a forest of tall shards, three of them lit."""
    out = [prim("ball", "Base", base, (0, 0.6, 0), SNOW, (0, 3, 2), lumpy=0.04),
           prim("ball", "Bank", (base[0] * 0.6, base[1] * 0.9, base[2] * 0.6), (base[0] * 0.28, 1.4, -base[2] * 0.2),
                SNOW_SHADE, (20, 4, 3), lumpy=0.04)]
    for i, (x, z, h, w, yaw, lean, c, glow) in enumerate(spec):
        out.append(prim("shard", "Core" if i == 0 else f"Shard{i}", (w, h, w), (x, 0.3, z), c, (yaw, lean, 0),
                        glow=glow))
    return out


@piece
def crystal_field_a():
    return _field([(0, 0, 24, 5.0, 0, 3, CRYSTAL, True), (-5.2, 1.6, 16, 4.0, 35, -14, CRYSTAL, False),
                   (4.8, -1.4, 15, 3.8, 70, 15, CRYSTAL_VIOLET, False), (1.6, 4.6, 11, 3.0, 15, 22, CRYSTAL, True),
                   (-2.6, -4.6, 10, 2.8, 55, -24, ICE_PALE, False), (6.4, 3.6, 8, 2.4, 5, 30, CRYSTAL_PINK, False),
                   (-7.2, -2.0, 9, 2.6, 80, -30, CRYSTAL_VIOLET, False), (3.0, -5.4, 6.5, 2.0, 25, 28, CRYSTAL, True),
                   (-4.6, 5.0, 7, 2.2, 60, -18, ICE_PALE, False), (8.0, 0.6, 5, 1.8, 40, 34, CRYSTAL_VIOLET, False)],
                  (22, 4.4, 18))


@piece
def crystal_field_b():
    return _field([(0, 0, 19, 4.2, 30, -6, CRYSTAL_VIOLET, True), (3.8, 2.0, 14, 3.4, 5, 18, CRYSTAL, True),
                   (-3.8, 1.2, 12, 3.2, 50, -20, CRYSTAL, False), (0.8, -4.0, 9, 2.6, 80, 14, CRYSTAL_PINK, False),
                   (-5.4, -2.6, 8, 2.4, 20, -30, CRYSTAL_VIOLET, False), (5.6, -2.0, 7, 2.2, 65, 26, ICE_PALE, False),
                   (-1.6, 4.8, 6, 2.0, 40, 24, CRYSTAL, True)], (17, 3.8, 15))


@piece
def ice_block_pile():
    """Tumbled ice: fallen blocks heaped on the canyon floor under a dusting of snow."""
    return [
        prim("block", "Big", (7, 5, 6), (0, 2.2, 0), ICE, (20, 12, -8), facet=True),
        prim("block", "Lean", (5, 6.5, 4), (4.6, 2.4, 1.8), ICE_DEEP, (-30, -22, 14), facet=True),
        prim("block", "Slab", (6, 2.4, 5), (-4.4, 1.0, -1.6), ICE_PALE, (50, 8, 6), facet=True),
        prim("block", "Chip", (3, 3, 2.6), (1.6, 1.2, -4.2), ICE_PALE, (75, -14, 20), facet=True),
        prim("ball", "Snow", (6.6, 2.0, 5.6), (-0.4, 5.0, 0.2), SNOW, (20, 6, -4), lumpy=0.04),
        prim("ball", "SnowLean", (3.4, 1.4, 3.0), (-4.6, 2.5, -1.8), SNOW, (50, 4, 3), lumpy=0.04),
    ]


# ── Arches and the bridge ──────────────────────────────────────────────────────
@piece
def ice_arch():
    """A free-standing arch of ice voussoirs: 28 studs clear between the feet, 23 under the crown."""
    out = []
    n = 11
    rx, ry = 17.0, 24.0
    for i in range(n):
        a0, a1 = math.pi * i / n, math.pi * (i + 1) / n
        am = (a0 + a1) / 2
        x, y = -rx * math.cos(am), ry * math.sin(am)
        seg = math.hypot(rx * (math.cos(a1) - math.cos(a0)), ry * (math.sin(a1) - math.sin(a0)))
        tangent = math.degrees(math.atan2(ry * math.cos(am), rx * math.sin(am)))
        c = ICE_DEEP if i == n // 2 else (ICE, ICE_PALE)[i % 2]
        out.append(prim("block", f"Stone{i}", (seg * 1.25 + 0.8, 6.4, 7.0 + 0.8 * (i % 2)), (x, y, 0), c, (0, 0, tangent),
                        facet=True))  # long enough to close the outer rim; alternate depths so the
        # overlapping neighbours' faces never share a plane (they would z-fight)
        # the snow rides the voussoir's outer face, pushed out along the arch's radius
        out.append(prim("ball", f"Snow{i}", (seg * 1.05, 2.2, 7.6), (x - 3.2 * math.cos(am), y + 3.2 * math.sin(am), 0),
                        SNOW, (0, 0, tangent + 2), lumpy=0.03))
    for side in (-1, 1):
        out.append(prim("block", f"Foot{side}", (7, 4, 8), (side * rx, 2.0, 0), ICE_DEEP, (0, 0, 0), facet=True))
        out.append(prim("ball", f"FootSnow{side}", (8, 3, 9), (side * rx, 0.8, -0.5), SNOW_SHADE, (0, 3, 0)))
    out.append(prim("ball", "Keystone", (3, 3, 3), (0, ry + 0.4, -3.4), GLOW, glow=True))
    return out


@piece
def ice_bridge():
    """The ornament of the 16 x 36 ice bridge (the crevasse is 35 wide). Its origin is the centre of the deck's top: the arch
    ribs hang below it, the balustrade stands on it. The walkable deck is map_forge's own floor slab.
    The span runs along local Z."""
    out = []
    half_w, half_l = 8.0, 18.0
    for side in (-1, 1):
        x = side * (half_w - 0.6)
        rib_x = side * (half_w + 0.6)  # the ribs run just outboard of the deck's edges
        n = 7
        for i in range(n):  # a shallow rib under each edge
            t0, t1 = i / n, (i + 1) / n
            tm = (t0 + t1) / 2
            span = half_l - 3.0  # the ribs spring from the crevasse's lips, 3 in from the deck's ends
            z = -span + 2 * span * tm
            u = 2 * tm - 1  # -1 .. 1 along the span: the rib hugs the deck mid-span, dives at the ends
            y = -2.0 - 5.0 * u * u
            ang = math.degrees(math.atan(10.0 * u / span))
            out.append(prim("block", f"Rib{side}_{i}", (1.8, 3.6, 2 * span / n + 0.5), (rib_x, y, z),
                            (ICE, ICE_PALE)[i % 2], (0, ang, 0), facet=True))
        for i in range(6):  # balustrade posts, each under a snow ball
            z = -half_l + 1 + i * (2 * half_l - 2) / 5
            out.append(prim("drum", f"Post{side}_{i}", (1.4, 3.6, 1.4), (x, -0.2, z), ICE_DEEP))
            out.append(prim("ball", f"PostSnow{side}_{i}", (1.9, 1.3, 1.9), (x, 3.5, z), SNOW, (0, 4, 0)))
        out.append(prim("block", f"Rail{side}", (0.9, 0.8, 2 * half_l - 1.6), (x, 2.6, 0), ICE_PALE, facet=True))
    return out


# ── The frozen temple ──────────────────────────────────────────────────────────
def _column(h, broken, seed):
    rng = random.Random(seed)
    out = [prim("block", "Plinth", (5.4, 1.6, 5.4), (0, 0.6, 0), TEMPLE_TRIM, facet=True),
           prim("drum", "Shaft", (3.6, h - 3.6, 3.6), (0, 1.2, 0), TEMPLE, flutes=12)]
    if broken:
        out.append(prim("block", "Break", (3.9, 1.8, 3.9), (0, h - 2.2, 0), TEMPLE,
                        (rng.uniform(0, 90), rng.uniform(10, 16), rng.uniform(-6, 6)), facet=True))
        out.append(prim("ball", "Snow", (4.6, 1.6, 4.4), (0, h - 1.4, 0.3), SNOW, (0, 12, 3)))
    else:
        out.append(prim("drum", "Neck", (4.4, 0.8, 4.4), (0, h - 2.8, 0), TEMPLE_TRIM))
        out.append(prim("block", "Capital", (5.6, 1.8, 5.6), (0, h - 1.1, 0), TEMPLE_TRIM, facet=True))
        out.append(prim("ball", "Snow", (6.2, 1.6, 6.0), (0, h + 0.1, 0), SNOW, (0, 3, 2)))
        for j in range(4):
            a = math.pi / 2 * j + 0.4
            out.append(prim("icicle", f"Icicle{j}", (0.9, rng.uniform(1.6, 3.2), 0.9),
                            (math.cos(a) * 2.6, h - 2.1, math.sin(a) * 2.6), ICE_PALE, hifi=True))
    return out


@piece
def temple_column():
    return _column(20.0, False, 5)


@piece
def temple_column_broken():
    return _column(11.0, True, 6)


@piece
def temple_facade():
    """The Revenant's temple front: a stepped platform, six columns under an entablature and a
    pediment, a tall glowing doorway, a snowflake crest. 44 wide, the front at local -Z."""
    out = []
    for k, (w, d, y0, h) in enumerate(((46, 24, 0.0, 1.6), (42, 21, 1.2, 1.6), (38, 18, 2.4, 1.6))):
        out.append(prim("block", f"Step{k}", (w, h, d), (0, y0 + h / 2 - 0.4, 1.0 + 1.5 * k), TEMPLE_TRIM
                        if k % 2 == 0 else TEMPLE, facet=True))
    out.append(prim("block", "Cella", (34, 24, 14), (0, 3.6 + 12 - 0.4, 4.0), TEMPLE, facet=True))
    for i in range(6):
        x = -15 + i * 6
        out.append(prim("block", f"ColBase{i}", (4.2, 1.2, 4.2), (x, 4.0, -5.2), TEMPLE_TRIM, facet=True))
        out.append(prim("drum", f"Col{i}", (3.2, 18.4, 3.2), (x, 4.2, -5.2), TEMPLE, flutes=12))
        out.append(prim("block", f"ColCap{i}", (4.4, 1.4, 4.4), (x, 23.1, -5.2), TEMPLE_TRIM, facet=True))
    out.append(prim("block", "Entablature", (38, 3.4, 18), (0, 25.4, -0.6), TEMPLE, facet=True))
    out.append(prim("block", "Frieze", (38.6, 1.0, 18.6), (0, 24.0, -0.6), TEMPLE_TRIM, facet=True))
    for side in (-1, 1):  # the pediment as two wedges, rising to the crest
        out.append(prim("wedge", f"Pediment{side}", (18, 7, 18.8), (side * -9.5, 30.6, -0.6), TEMPLE,
                        (90 * side, 0, 0)))
    slope = math.degrees(math.atan2(7, 19))
    for side in (-1, 1):  # snow lying on each roof slope, the gable's own pitch
        a = math.radians(slope) * -side
        out.append(prim("block", f"RoofSnow{side}", (20.6, 1.0, 19.6),
                        (side * 9.5 - math.sin(a) * 0.45, 30.6 + math.cos(a) * 0.45, -0.6), SNOW, (0, 0, -side * slope)))
    out.append(prim("block", "Door", (8, 14, 1.2), (0, 10.6, -3.2), TEMPLE_NIGHT, facet=True))
    out.append(prim("block", "DoorGlow", (9.4, 15.2, 0.6), (0, 10.6, -2.8), GLOW, glow=True))
    for j in range(3):  # the snowflake crest over the door: three crossed bars and a hub
        out.append(prim("block", f"Crest{j}", (0.9, 6.4, 0.8), (0, 29.0, -9.8), GLOW, (0, 0, 60 * j), glow=True))
    out.append(prim("ball", "CrestHub", (2.2, 2.2, 1.2), (0, 29.0, -10.0), TEMPLE_TRIM, (0, 0, 5)))
    return out


@piece
def temple_spire():
    """A frozen spire behind the temple: stacked hex ice columns narrowing to a glowing point."""
    out = []
    y = 0.0
    for k, (w, h) in enumerate(((16, 16), (13, 15), (10, 14), (7.5, 12), (5, 10))):
        c = (ICE_PALE, ICE, ICE_PALE, ICE, CRYSTAL)[k]
        out.append(prim("shard", f"Tier{k}", (w, h + w * 0.35, w), (0, y, 0), c, (30 * k, 0, 0), flat=True, taper=0.78))
        out.append(prim("ball", f"Ring{k}", (w * 1.05, 1.6, w * 1.05), (0, y + h - 0.2, 0), SNOW, (0, 4, 0)))
        y += h
    out.append(prim("shard", "Tip", (3.2, 12, 3.2), (0, y - 0.4, 0), GLOW, glow=True))
    return out


@piece
def frozen_colossus():
    """A giant ice knight half sunk in the glacier, one arm raising his sword: the ridge's
    milestone, seen from the ascent. He faces local -Z."""
    out = [
        prim("ball", "Mound", (30, 8, 24), (0, 1.0, 0), SNOW_SHADE, (0, 2, 0), lumpy=0.05),
        prim("block", "Chest", (18, 14, 10), (0, 7.0, 0.6), ICE, (0, -6, 0), facet=True),
        prim("ball", "PauldronL", (11, 8.4, 11), (-9.6, 13.4, 0.4), ICE_PALE, (0, 0, 14), lumpy=0.02),
        prim("ball", "PauldronR", (11, 8.4, 11), (9.6, 13.4, 0.4), ICE_PALE, (0, 0, -14), lumpy=0.02),
        prim("ball", "SnowL", (8.4, 2.6, 8.2), (-10.2, 17.1, 0.4), SNOW, (0, 3, 12), lumpy=0.03),
        prim("block", "Neck", (6, 4, 6), (0, 15.4, 0.8), ICE_DEEP, facet=True),
        prim("ball", "Helm", (11.5, 12.5, 11.5), (0, 21.6, 0.2), ICE_PALE, (0, -4, 0)),
        prim("block", "Visor", (8.4, 1.6, 2.0), (0, 21.4, -5.2), TEMPLE_NIGHT, (0, -4, 0), facet=True),
        prim("block", "VisorGlow", (7.2, 0.7, 0.6), (0, 21.4, -6.1), GLOW, (0, -4, 0), glow=True),
        prim("wedge", "Crest", (2.0, 7, 10), (0, 29.4, 1.6), ICE_DEEP, (180, 0, 0)),
        prim("ball", "HelmSnow", (8.6, 2.6, 8.4), (0.4, 27.0, 1.0), SNOW, (0, -2, 4), lumpy=0.03),
        prim("ball", "Forearm", (6, 12, 6), (10.6, 22.0, -1.6), ICE, (0, -8, -10)),
        prim("ball", "Fist", (6.4, 6.0, 6.4), (11.6, 28.6, -2.4), ICE_PALE, (0, 0, 0)),
        prim("block", "Guard", (11, 2.0, 2.6), (11.6, 31.8, -2.4), GOLD, (0, 0, 0), facet=True),
        prim("block", "Blade", (4.2, 22, 1.4), (11.6, 43.8, -2.4), ICE_PALE, blade=True),
        prim("block", "Fuller", (1.0, 17, 1.6), (11.6, 42.4, -2.4), GLOW, glow=True),
        prim("ball", "Pommel", (2.6, 2.6, 2.6), (11.6, 25.2, -2.4), GOLD),
    ]
    return out


# ── The frozen waterfall ───────────────────────────────────────────────────────
@piece
def frozen_fall():
    """A waterfall caught mid-pour: a curtain of rounded ice columns spilling over a cornice into
    a frozen plunge mound. 22 wide, 34 tall; it leans on a cliff, front at local -Z."""
    rng = random.Random(9)
    out = []
    n = 8
    for i in range(n):
        x = -9.5 + i * 19 / (n - 1)
        h = 34 - abs(i - (n - 1) / 2) * 1.6 + rng.uniform(-1.5, 1.5)
        d = rng.uniform(2.6, 3.6)
        out.append(prim("drum", f"Pour{i}", (d, h, d * 0.9), (x, 0, rng.uniform(-0.8, 0.8)),
                        (ICE_PALE, ICE, SNOW, ICE_PALE)[i % 4]))
        out.append(prim("ball", f"Bulge{i}", (d * 1.35, 4.4, d * 1.3), (x, h * rng.uniform(0.45, 0.7), -0.6),
                        (ICE, ICE_PALE)[i % 2], (0, 5, 0)))
    out.append(prim("ball", "Lip", (26, 6, 9), (0, 33.6, 1.4), SNOW, (0, 2, 0), lumpy=0.04))
    out.append(prim("ball", "Plunge", (28, 5, 14), (0, 0.8, -4.4), ICE, (0, 2, 0)))
    out.append(prim("ball", "PlungeSnow", (32, 3.4, 16), (0, 0.2, -3.2), SNOW_SHADE, (0, 1, 0)))
    return out


# ── Vista peaks (outside the walls) ────────────────────────────────────────────
def _ridge(out, n, cx, cz, yaw, W, H, Dh, y0, c):
    """A ridge prism: two wedges back to back along local X, crest at y0 + H over (cx, cz)."""
    R = rotation((yaw, 0, 0))
    for k, sgn in enumerate((1, -1)):
        off = _apply(R, (0, 0, sgn * Dh / 2))
        out.append(prim("wedge", f"{n}{k}", (W, H, Dh), (cx + off[0], y0 + H / 2, cz + off[2]), c,
                        (yaw + (180 if sgn > 0 else 0), 0, 0)))


def _peak(h, w, seed):
    """A far mountain, hazed pale blue: a rounded mass with one sharp ridge and a crossing spur
    rising out of it, snow riding their upper slopes, a lower shoulder summit to one side. Simpler
    and paler than the crags, so the range recedes."""
    rng = random.Random(seed)
    yaw = rng.uniform(-25, 25)
    out = [prim("cone", "Body", (w, h * 0.66, w * 0.9), (0, 0, 0), RANGE, (rng.uniform(0, 90), 0, 0), top=0.1,
                scallop=9)]
    _ridge(out, "Ridge", 0, 0, yaw, w * 0.78, h, w * 0.42, 0, RANGE_DEEP)
    cross = yaw + 90 + rng.uniform(-15, 15)
    _ridge(out, "Cross", w * 0.05, w * 0.03, cross, w * 0.56, h * 0.76, w * 0.34, 0, RANGE)
    _ridge(out, "Snow", 0, 0, yaw, w * 0.76, h * 0.58, w * 0.3, h * 0.46, SNOW)
    _ridge(out, "CrossSnow", w * 0.05, w * 0.03, cross, w * 0.54, h * 0.4, w * 0.24, h * 0.4, SNOW)
    sx, sz = w * 0.36, w * 0.1
    sy = yaw + rng.uniform(20, 50)
    _ridge(out, "ShoulderRidge", sx, sz, sy, w * 0.4, h * 0.56, w * 0.14, 0, RANGE_DEEP)
    _ridge(out, "ShoulderSnow", sx, sz, sy, w * 0.38, h * 0.3, w * 0.1, h * 0.3, SNOW)
    return out


@piece
def snow_peak_a():
    return _peak(240.0, 150.0, 21)


@piece
def snow_peak_b():
    return _peak(200.0, 125.0, 22)


@piece
def snow_peak_c():  # a broad massif: chunky, for the notch's vanishing point
    return _peak(210.0, 230.0, 23)


# ── The parts version ──────────────────────────────────────────────────────────
def _rx(d):
    c, s = math.cos(math.radians(d)), math.sin(math.radians(d))
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def _ry(d):
    c, s = math.cos(math.radians(d)), math.sin(math.radians(d))
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def _rz(d):
    c, s = math.cos(math.radians(d)), math.sin(math.radians(d))
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def _mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def _apply(m, v):
    return tuple(sum(m[i][k] * v[k] for k in range(3)) for i in range(3))


def rotation(r):
    yaw, pitch, roll = r
    return _mul(_ry(yaw), _mul(_rx(pitch), _rz(roll)))


def _add(a, b):
    return tuple(a[i] + b[i] for i in range(3))


def lofi(prims):
    """The primitives as Roblox parts, in the piece's frame: a list of dicts
    {name, kind: ball|cyl|block|wedge, size, pos, rot (3x3), color, glow}. map_forge builds exactly
    these (ball = Part + Sphere SpecialMesh, cyl = Cylinder part, wedge = WedgePart), and the Blender
    script renders them beside each mesh for the contact sheet."""
    out = []
    for q in prims:
        if q.get("hifi"):
            continue
        k, n, s, p, c = q["k"], q["n"], q["s"], q["p"], q["c"]
        R = rotation(q["r"])
        glow = bool(q.get("glow"))
        if k == "ball":
            if abs(q["r"][1]) < 1 and abs(q["r"][2]) < 1:  # an ellipsoid always gets a small tilt:
                R = _mul(R, _rx(3.0))  # a level one reads to the validator as a flat top
            out.append({"name": n, "kind": "ball", "size": s, "pos": p, "rot": R, "color": c, "glow": glow})
        elif k == "drum":
            out.append({"name": n, "kind": "cyl", "size": (s[1], s[0], s[2]), "pos": _add(p, _apply(R, (0, s[1] / 2, 0))),
                        "rot": _mul(R, _rz(90)), "color": c, "glow": glow})
        elif k in ("block", "wedge"):
            out.append({"name": n, "kind": k, "size": s, "pos": p, "rot": R, "color": c, "glow": glow})
        elif k == "cone":  # a rounded tier: the mesh's cone, as a plastic puff
            out.append({"name": n, "kind": "ball", "size": (s[0], s[1] * 0.94, s[2]),
                        "pos": _add(p, _apply(R, (0, s[1] * 0.46, 0))), "rot": _mul(R, _rx(3.0)), "color": c,
                        "glow": glow})
        elif k == "shard":  # the waystones' crystal: a block, a turned cube for the tip
            w = s[0]
            hb = s[1] - (0.3 if q.get("flat") else 0.5) * w
            out.append({"name": n, "kind": "block", "size": (w, hb, s[2]), "pos": _add(p, _apply(R, (0, hb / 2, 0))),
                        "rot": R, "color": c, "glow": glow})
            out.append({"name": n + "Tip", "kind": "block", "size": (w * 0.72,) * 3,
                        "pos": _add(p, _apply(R, (0, hb + 0.05 * w, 0))), "rot": _mul(R, _mul(_rx(45), _rz(45))),
                        "color": c, "glow": glow})
        elif k == "icicle":
            continue
        else:
            raise ValueError(f"unknown primitive kind {k}")
    return out


def kit():
    """{key: [primitive, ...]} for every piece."""
    return {k: build(k) for k in KEYS}


if __name__ == "__main__":
    for key, prims in kit().items():
        print(f"{key:20s} {len(prims):3d} primitives, {sum(1 for p in prims if not p.get('hifi')):3d} parts")
