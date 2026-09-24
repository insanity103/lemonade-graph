# Boss_CelestialTitan pool -- the Celestial Titan's armoury (brief section 8.5).
# Echo the Titan: halos, suns, stars, the Summit's stairs, ivory and gold. Calm: ivory, starlight,
# comet, titan. Vivid: gold, tangerine, spire.
# Outlines planned up front: a starlight needle, a comet falchion, a diamond, a curved saber, a
# straight meridian blade, a blade that flares toward its tip, a bellied claymore, a tall spire
# triangle, and a squared broadsword.


def four_star(cy, cz, arm, short, waist):
    """A four-point star with long flat-ended horizontal arms (to +-arm) and short vertical points."""
    return [(cy - waist, arm), (cy + waist, arm), (cy + waist * 1.6, 0.03), (cy + short, 0.0), (cy + waist * 1.6, -0.03),
            (cy + waist, -arm), (cy - waist, -arm), (cy - waist * 1.6, -0.03), (cy - short * 0.8, 0.0), (cy - waist * 1.6, 0.03)]


def design_starlight_shortsword(f):
    """Starlight Shortsword -- carries a little starlight. A thin starlight needle with gold edges
    and a raised gold four-point star at its root, a gold four-point star guard with long
    flat-ended arms, an ivory grip with gold bands and a gold five-point star pommel on a gold base.
    Calm: starlight, ivory. Vivid: gold, tangerine."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = 0.038 if t < 0.8 else lerp(0.038, 0.006, (t - 0.8) / 0.2)
        return -w, w, lerp(0.028, 0.014, t)
    b, st = blade(f, fn, "starlight", "gold", n=16, chamfer=0.018)
    plate(f, "RootStar", star(-0.14, 0.0, 4, 0.036, 0.012, rot=0), "tangerine", st)
    f.prism("StarGuard", four_star((GUARD_Y0 + GUARD_Y1) / 2, 0.0, GUARD_HALF_SPAN, 0.052, 0.012), 0.036, "gold")
    grip_bands(f, "ivory", "gold", bands=2)
    f.lathe("StarBase", [(0.0, -0.5), (0.024, -0.5), (0.024, -0.49), (0.0, -0.49)], "gold", segs=16)
    f.prism("StarPommel", star(-0.462, 0.0, 5, 0.032, 0.014), 0.024, "gold")
    return {"design": "Starlight Shortsword", "concept": "a starlight needle over a four-point star guard", "tier": 1,
            "calm": ["starlight", "ivory"], "vivid": ["gold", "tangerine"]}


def design_comet_falchion(f):
    """Comet Falchion -- a comet's tail along the edge. A comet-blue falchion with gold edges, a gold
    comet head near the tip and three raised tail streaks (tangerine, ivory, gold) trailing back
    toward the guard, tangerine tail prongs swept back from a gold bar, a tangerine grip with ivory
    bands and a gold ball pommel. Calm: comet, ivory. Vivid: gold, tangerine."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        zb = -0.046 if t < 0.84 else lerp(-0.046, 0.012, (t - 0.84) / 0.16)
        ze = lerp(0.05, 0.092, smooth(t / 0.7)) if t < 0.8 else lerp(0.092, 0.02, (t - 0.8) / 0.2)
        return zb, ze, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "comet", "gold", n=26, chamfer=0.028, double=False)
    hy = 0.3
    f.sphere("CometHead", (0, hy, zc_at(st, hy)), 0.034, "gold", segs=18, rings=9)
    for k, (colour, off) in enumerate((("tangerine", -0.02), ("ivory", 0.0), ("gold", 0.02))):
        rings = []
        for y, zb, ze, th in st[2:17]:
            c = zc_at(st, y) + off * (y - BLADE_ROOT_Y) / (hy - BLADE_ROOT_Y)
            w = 0.004 + 0.006 * (y - BLADE_ROOT_Y) / (hy - BLADE_ROOT_Y)
            rings.append([(th + 0.006, y, c - w), (th + 0.006, y, c + w), (-th - 0.006, y, c + w), (-th - 0.006, y, c - w)])
        f.loft(f"Tail{k}", rings, [colour] * 4, colour)
    end_bar(f, "gold", y0=GUARD_Y0, y1=GUARD_Y0 + 0.028, half_x=0.044)
    pair(f, "TailProng", [(GUARD_Y0 + 0.028, 0.03), (GUARD_Y0 + 0.028, 0.09), (-0.16, 0.118), (-0.19, 0.05)], 0.028, "tangerine")
    grip_bands(f, "tangerine", "ivory", bands=2)
    ball_pommel(f, "gold", r=0.036)
    return {"design": "Comet Falchion", "concept": "a falchion with a comet and its tail along the blade", "tier": 2,
            "calm": ["comet", "ivory"], "vivid": ["gold", "tangerine"]}


def design_corona_shortsword(f):
    """Corona Shortsword -- ringed in a thin corona. A short tangerine diamond blade with ivory edges
    and an ivory corona ring round it near the root set with four gold beads, a gold ray bar (one
    short ray rising each side), an ivory grip with tangerine bands and a gold sun-disc pommel.
    Calm: ivory. Vivid: tangerine, gold."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.03, 0.078, t / 0.5) if t < 0.5 else lerp(0.078, 0.008, (t - 0.5) / 0.5)
        return -w, w, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "tangerine", "ivory", n=14, chamfer=0.026)
    ring_around(f, "Corona", -0.14, 0.064, 0.012, "ivory", segs=20)
    for k in range(4):
        a = 2 * _m.pi * k / 4 + _m.pi / 4
        f.sphere(f"Bead{k}", (0.064 * _m.cos(a), -0.14, 0.064 * _m.sin(a)), 0.015, "gold", segs=12, rings=6)
    end_bar(f, "gold", half_x=0.044)
    for sign in (1, -1):
        for z in (0.1,):
            f.prism(f"Ray{sign}{z}", [(GUARD_Y1, sign * (z - 0.008)), (GUARD_Y1, sign * (z + 0.002)), (GUARD_Y1 + 0.03, sign * z)][::sign], 0.02, "gold")
    grip_bands(f, "ivory", "tangerine", bands=2)
    disc_pommel(f, "gold", r=0.036, half_x=0.022)
    return {"design": "Corona Shortsword", "concept": "a diamond shortsword ringed with a beaded corona", "tier": 1,
            "calm": ["ivory"], "vivid": ["tangerine", "gold"]}


def design_halo_saber(f):
    """Halo Saber -- ringed with a soft halo. A curved gold saber with an ivory edge and an ivory
    halo ring floating round the blade at mid-length on two short struts, small ivory feather wings
    over a gold bar, an ivory grip with gold bands and an ivory mini-halo pommel.
    Calm: ivory. Vivid: gold, tangerine."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.05 * t * t
        w = 0.056 if t < 0.8 else lerp(0.056, 0.008, smooth((t - 0.8) / 0.2))
        return c - w, c + w, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "gold", "ivory", n=28, chamfer=0.03, double=False)
    hy = 0.1
    ring_around(f, "Halo", hy, 0.084, 0.012, "ivory", segs=28)
    rod(f, "HaloStrut", (0, hy, zc_at(st, hy) - 0.08), (0, hy, zc_at(st, hy) + 0.08), 0.007, "ivory", segs=12)
    end_bar(f, "gold", y0=GUARD_Y0, y1=GUARD_Y0 + 0.028, half_x=0.044)
    for sign in (1, -1):
        leaf(f, f"Feather{sign}a", GUARD_Y0 + 0.03, sign * 0.04, -0.16, sign * 0.11, 0.016, "ivory", half_x=0.026)
    grip_bands(f, "ivory", "tangerine", bands=3)
    ring_pommel(f, "ivory", R=0.026, r=0.012)
    return {"design": "Halo Saber", "concept": "a curved saber ringed by a floating halo", "tier": 2,
            "calm": ["ivory"], "vivid": ["gold", "tangerine"]}


def design_meridian_blade(f):
    """Meridian Blade -- aligned to the sky's meridian. A straight gold blade with ivory edges and a
    raised ivory meridian ridge, an armillary guard (a ring round the blade and a ring facing the
    side, both tangerine) over a gold bar, an ivory grip with gold bands and an ivory globe pommel
    circled by a gold ring. Calm: ivory. Vivid: gold, tangerine."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = 0.054 if t < 0.84 else lerp(0.054, 0.008, smooth((t - 0.84) / 0.16))
        return -w, w, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "gold", "ivory", n=24, chamfer=0.026)
    briar_rib(f, "Meridian", st[1:18], 0, 0.011, "ivory", extra=0.006)
    end_bar(f, "gold", half_x=0.044)
    f.torus_yz("ArmillaryA", -0.19, 0.0, 0.066, 0.011, "tangerine", seg=32, tube=12)
    ring_around(f, "ArmillaryB", -0.19, 0.066, 0.011, "tangerine", segs=28)
    grip_bands(f, "ivory", "gold", bands=2)
    ball_pommel(f, "ivory", r=0.036)
    f.torus_yz("GlobeRing", -0.46, 0.0, 0.031, 0.007, "gold", seg=28, tube=12)
    return {"design": "Meridian Blade", "concept": "a straight blade with a meridian ridge and an armillary guard", "tier": 3,
            "calm": ["ivory"], "vivid": ["gold", "tangerine"]}


def design_zenithguard_blade(f):
    """Zenithguard Blade -- the Zenithguard's issue blade, clear as high air. An ivory blade that
    flares wider toward its tip (rising to its zenith), gold edges, a tangerine sun emblem on a gold
    ring at the root, a gold bar with tangerine shield caps, a tangerine grip with ivory bands and an
    ivory tapering pommel. Calm: ivory. Vivid: gold, tangerine."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.04, 0.082, smooth(t / 0.8)) if t < 0.82 else lerp(0.082, 0.008, smooth((t - 0.82) / 0.18))
        return -w, w, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "ivory", "gold", n=26, chamfer=0.026)
    disc_plate(f, "SunRing", -0.15, 0.0, 0.034, "gold", st, lift=0.006)
    disc_plate(f, "Sun", -0.15, 0.0, 0.022, "tangerine", st, lift=0.01)
    end_bar(f, "gold", half_x=0.044, span=0.1)                  # the caps own the +-0.13 ends
    pair(f, "Shield", [(GUARD_Y0, 0.1), (GUARD_Y1 + 0.01, 0.1), (GUARD_Y1 - 0.005, 0.13), (GUARD_Y0 + 0.012, 0.13)], 0.05, "tangerine")
    grip_bands(f, "tangerine", "ivory", bands=2)
    f.lathe("Chevron", [(0.0, -0.5), (0.042, -0.5), (0.03, -0.476), (0.014, -0.452), (0.0, -0.448)], "ivory", segs=20)
    return {"design": "Zenithguard Blade", "concept": "a blade flaring toward its tip with a sun emblem and shield guard", "tier": 2,
            "calm": ["ivory"], "vivid": ["gold", "tangerine"]}


def design_aurelian_claymore(f):
    """Aurelian Claymore -- leafed in gold from the Titan's steps. A tangerine claymore whose width
    steps down in three stairs, ivory edges, its faces set with rows of raised gold-leaf rhombuses, a gold bar that
    steps up toward the blade in three stairs each side, an ivory grip with tangerine bands and a
    stepped gold ziggurat pommel. Calm: ivory. Vivid: tangerine, gold."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        # the Titan's steps: the width drops in three stairs toward the point
        steps = 0.094 - 0.018 * smooth((t - 0.3) / 0.04) - 0.018 * smooth((t - 0.58) / 0.04)
        w = steps if t < 0.84 else lerp(0.058, 0.01, smooth((t - 0.84) / 0.16))
        return -w, w, lerp(0.031, 0.016, t)
    b, st = blade(f, fn, "tangerine", "ivory", n=28, chamfer=0.028)
    k = 0
    for row, y in enumerate((-0.12, -0.04, 0.04, 0.12)):
        for z in ((-0.03, 0.03) if row % 2 == 0 else (0.0,)):
            plate(f, f"Leaf{k}", [(y - 0.03, z), (y, z + 0.022), (y + 0.03, z), (y, z - 0.022)], "gold", st)
            k += 1
    stairs = [(GUARD_Y0, -0.13), (GUARD_Y0, 0.13), (GUARD_Y0 + 0.02, 0.13), (GUARD_Y0 + 0.02, 0.1), (GUARD_Y0 + 0.04, 0.1),
              (GUARD_Y0 + 0.04, 0.07), (GUARD_Y0 + 0.06, 0.07), (GUARD_Y0 + 0.06, -0.07), (GUARD_Y0 + 0.04, -0.07),
              (GUARD_Y0 + 0.04, -0.1), (GUARD_Y0 + 0.02, -0.1), (GUARD_Y0 + 0.02, -0.13)]
    f.prism("Stairs", stairs, 0.044, "gold")
    grip_bands(f, "ivory", "tangerine", bands=2)
    for k2, (r, y0, y1) in enumerate(((0.046, -0.5, -0.486), (0.034, -0.486, -0.472), (0.022, -0.472, -0.458))):
        f.flat(f.lathe(f"Ziggurat{k2}", [(0.0, y0), (r, y0), (r, y1), (0.0, y1)], "gold", segs=4))
    return {"design": "Aurelian Claymore", "concept": "a gold-leafed claymore with a stair guard and ziggurat", "tier": 3,
            "calm": ["ivory"], "vivid": ["tangerine", "gold"]}


def design_sunspire_claymore(f):
    """Sunspire Claymore -- as tall and bright as the Summit's spire. A tall tapering spire-gold
    triangle with ivory edges and three raised ivory spire collars round it, an ivory bar with gold
    cone finials standing toward the blade, an ivory grip with gold bands and a tangerine sun sphere
    in a gold ring for a pommel. Calm: ivory. Vivid: spire, gold, tangerine."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.076, 0.008, t)
        return -w, w, lerp(0.031, 0.015, t)
    b, st = blade(f, fn, "spire", "ivory", n=26, chamfer=0.022)
    for k, y in enumerate((-0.09, 0.07, 0.22)):
        w = fn(y)[1]
        ring_around(f, f"Collar{k}", y, w + 0.006, 0.012, "ivory", segs=24)
    end_bar(f, "ivory", half_x=0.044)
    for z in (-0.1, 0.1):
        cone = f.lathe(f"Finial{z}", [(0.0, 0.0), (0.016, 0.0), (0.0, 0.05)], "gold", segs=12)
        f.orient(cone, loc=(0, GUARD_Y1, z))
    grip_bands(f, "ivory", "gold", bands=2)
    f.sphere("Sun", (0, -0.5 + 0.032, 0), 0.032, "tangerine", segs=16, rings=8)
    ring_around(f, "SunRing", -0.468, 0.032, 0.008, "gold", segs=24)
    return {"design": "Sunspire Claymore", "concept": "a tall spire claymore ringed with collars", "tier": 3,
            "calm": ["ivory"], "vivid": ["spire", "gold", "tangerine"]}


def design_titanforged_greatsword(f):
    """Titanforged Greatsword -- hammered on the Titan's own anvil. A massive titan-white broadsword
    with hammered flat facets, a squared chisel tip and tangerine edges, two raised gold rivet bands
    across the blade, a gold anvil guard (flat top, horned outline), a tangerine grip with ivory
    bands and a gold hammer-head pommel set crosswise. Calm: titan, ivory. Vivid: gold, tangerine."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        zb = -0.098 if t < 0.84 else lerp(-0.098, 0.03, (t - 0.84) / 0.16)
        ze = 0.098 if t < 0.97 else 0.08
        return zb, ze, lerp(0.032, 0.018, t)
    b, st = blade(f, fn, "titan", "tangerine", n=24, chamfer=0.028, flat=True)
    for k, y in enumerate((-0.08, 0.14)):
        plate(f, f"Band{k}", [(y - 0.014, -0.09), (y + 0.014, -0.09), (y + 0.014, 0.09), (y - 0.014, 0.09)], "gold", st)
        for z in (-0.06, 0.0, 0.06):
            stud(f, f"Rivet{k}{z}", y, z, 0.012, "tangerine", st)
    anvil = [(GUARD_Y0, -0.08), (GUARD_Y0, 0.08), (GUARD_Y0 + 0.02, 0.08), (GUARD_Y0 + 0.03, 0.13), (GUARD_Y1 + 0.01, 0.13),
             (GUARD_Y1 + 0.01, -0.13), (GUARD_Y0 + 0.042, -0.13), (GUARD_Y0 + 0.02, -0.08)]
    f.prism("Anvil", anvil, 0.05, "gold")
    grip_bands(f, "tangerine", "ivory", bands=2)
    f.prism("HammerHead", [(-0.5, -0.06), (-0.5, 0.06), (-0.458, 0.06), (-0.458, -0.06)], 0.03, "gold")
    return {"design": "Titanforged Greatsword", "concept": "a hammered broadsword with rivet bands and an anvil guard", "tier": 3,
            "calm": ["titan", "ivory"], "vivid": ["gold", "tangerine"]}


DESIGNS.update({
    "Sword_StarlightShortsword": ("Boss_CelestialTitan", 1, design_starlight_shortsword),
    "Sword_CometFalchion": ("Boss_CelestialTitan", 2, design_comet_falchion),
    "Sword_CoronaShortsword": ("Boss_CelestialTitan", 1, design_corona_shortsword),
    "Sword_HaloSaber": ("Boss_CelestialTitan", 2, design_halo_saber),
    "Sword_MeridianBlade": ("Boss_CelestialTitan", 3, design_meridian_blade),
    "Sword_ZenithguardBlade": ("Boss_CelestialTitan", 2, design_zenithguard_blade),
    "Sword_AurelianClaymore": ("Boss_CelestialTitan", 3, design_aurelian_claymore),
    "Sword_SunspireClaymore": ("Boss_CelestialTitan", 3, design_sunspire_claymore),
    "Sword_TitanforgedGreatsword": ("Boss_CelestialTitan", 3, design_titanforged_greatsword),
})
