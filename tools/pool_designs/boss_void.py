# Boss_VoidWraith pool -- the Void Archon's armoury (brief section 8.4).
# Echo the Archon: halos, wings, rift eyes, crescents, magenta light in lavender and violet.
# Calm: lavender, pale_lilac. Vivid: violet, deep_violet, magenta_hot, verdict.
# Nine outlines planned up front so they cannot collide: a slim dagger, a hooked falchion, a
# seven-wave kris, a curved saber with holes, a straight sabre with star holes, a pinched-waist
# claymore, a tapering banded claymore, a leaf greatsword with a hole, and a square-tipped verdict.


def crescent(cy, cz, r, thick, facing=1, n=14):
    """A crescent outline centred at (cy, cz), horns pointing along +Y (facing=1) or -Y."""
    outer = [(cy + facing * r * _m.sin(a), cz + r * _m.cos(a)) for a in [_m.pi * k / n for k in range(n + 1)]]
    inner = [(cy + facing * (r - thick) * _m.sin(a) * 0.55, cz + (r - thick * 0.4) * _m.cos(a)) for a in [_m.pi * k / n for k in range(n, -1, -1)]]
    return outer + inner


def design_rift_dagger(f):
    """Rift Dagger -- slips between moments. A very slim straight lavender dagger with magenta
    edges and a narrow slit cut through it (magenta wall), a violet bar under a small violet
    crescent, a violet grip with lavender bands and a magenta diamond pommel.
    Calm: lavender. Vivid: magenta_hot, violet."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.042, 0.03, t) if t < 0.84 else lerp(0.03, 0.006, (t - 0.84) / 0.16)
        return -w, w, lerp(0.028, 0.013, t)
    b, st = blade(f, fn, "lavender", "magenta_hot", n=18, chamfer=0.016)
    hole(f, b, "Slit", 0.08, 0.0, 0.008, "magenta_hot", segs=16, scale=(1, 5.0, 1))
    end_bar(f, "violet", y0=GUARD_Y0, y1=GUARD_Y0 + 0.028, half_x=0.04)
    f.prism("Crescent", crescent(GUARD_Y0 + 0.028, 0.0, 0.07, 0.03), 0.03, "violet")
    grip_bands(f, "violet", "lavender", bands=2)
    gem_pommel(f, "magenta_hot", r=0.04, segs=4)
    return {"design": "Rift Dagger", "concept": "a slim slit dagger over a crescent", "tier": 1,
            "calm": ["lavender"], "vivid": ["magenta_hot", "violet"]}


def design_umbral_falchion(f):
    """Umbral Falchion -- a falchion of pressed shadow. A violet falchion with a wide lavender edge
    band and a hooked notch bitten out of its spine near the tip, two lavender crescent moons on its
    faces, flat wedge wings from a deep-violet bar, a deep-violet grip with lavender bands and a
    lavender crescent-moon pommel. Calm: lavender. Vivid: violet, deep_violet, magenta_hot."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        zb = -0.046 if t < 0.86 else lerp(-0.046, 0.02, (t - 0.86) / 0.14)
        ze = lerp(0.05, 0.09, smooth(t / 0.7)) if t < 0.8 else lerp(0.09, 0.022, (t - 0.8) / 0.2)
        return zb, ze, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "violet", "lavender", n=26, chamfer=0.034, double=False)
    hole(f, b, "Hook", 0.36, -0.05, 0.024, "magenta_hot", segs=20)
    for k, y in enumerate((-0.08, 0.1)):
        plate(f, f"Moon{k}", crescent(y, zc_at(st, y) + 0.004, 0.028, 0.014, facing=-1), "lavender", st)
    end_bar(f, "deep_violet", y0=GUARD_Y0, y1=GUARD_Y0 + 0.028, half_x=0.044)
    pair(f, "Wedge", [(GUARD_Y0 + 0.028, 0.02), (GUARD_Y0 + 0.028, 0.1), (-0.17, 0.118), (-0.19, 0.03)], 0.028, "deep_violet")
    grip_bands(f, "deep_violet", "magenta_hot", bands=2)
    f.prism("MoonPommel", crescent(-0.466, 0.0, 0.034, 0.016, facing=-1), 0.026, "lavender")
    f.lathe("MoonBase", [(0.0, -0.5), (0.02, -0.5), (0.02, -0.49), (0.0, -0.49)], "lavender", segs=16)
    return {"design": "Umbral Falchion", "concept": "a shadow falchion with a hooked spine and crescent moons", "tier": 2,
            "calm": ["lavender"], "vivid": ["violet", "deep_violet", "magenta_hot"]}


def design_nightfall_kris(f):
    """Nightfall Kris -- wave-edged, drinks the last of the light. A double-edged violet kris with
    seven small even waves and lavender edges, a magenta star at the blade root, flared deep-violet
    wings over a bar, a deep-violet grip with lavender bands and a curled lavender hook pommel.
    Calm: lavender. Vivid: violet, deep_violet, magenta_hot."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.012 * _m.sin(7 * _m.pi * t) * smooth(t / 0.1) * (1 - smooth((t - 0.85) / 0.15))
        w = lerp(0.06, 0.046, t) if t < 0.84 else lerp(0.046, 0.008, (t - 0.84) / 0.16)
        return c - w, c + w, lerp(0.029, 0.014, t)
    b, st = blade(f, fn, "violet", "lavender", n=44, chamfer=0.022)
    plate(f, "Star", star(-0.155, 0.0, 5, 0.03, 0.013), "magenta_hot", st)
    end_bar(f, "deep_violet", y0=GUARD_Y0, y1=GUARD_Y0 + 0.028, half_x=0.044)
    pair(f, "Flare", [(GUARD_Y0 + 0.028, 0.04), (GUARD_Y0 + 0.028, 0.11), (-0.176, 0.118), (-0.2, 0.07)], 0.028, "deep_violet")
    grip_bands(f, "deep_violet", "lavender", bands=2)
    f.lathe("CapBase", [(0.0, -0.5), (0.034, -0.5), (0.036, -0.478), (0.0, -0.478)], "lavender", segs=20)
    tube(f, "Curl", [(-0.478 + 0.022 * _m.sin(a), 0.02 + 0.03 * (1 - _m.cos(a))) for a in [j * _m.pi / 12 for j in range(13)]], 0.011, "lavender")
    return {"design": "Nightfall Kris", "concept": "a seven-wave kris with a star at its root", "tier": 2,
            "calm": ["lavender"], "vivid": ["violet", "deep_violet", "magenta_hot"]}


def design_nether_saber(f):
    """Nether Saber -- drinks the light around it. A curved deep-violet saber with a lavender edge
    and three shrinking round holes cut through it (magenta walls), a violet ring guard round the
    hub over a bar, a violet grip with lavender bands and a magenta orb held in a three-prong
    violet claw. Calm: lavender. Vivid: deep_violet, magenta_hot, violet."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.052 * t * t
        w = 0.058 if t < 0.8 else lerp(0.058, 0.008, smooth((t - 0.8) / 0.2))
        return c - w, c + w, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "deep_violet", "lavender", n=28, chamfer=0.03, double=False)
    for k, (y, r) in enumerate(((-0.08, 0.024), (0.06, 0.019), (0.18, 0.014))):
        hole(f, b, f"Hole{k}", y, zc_at(st, y), r, "magenta_hot", segs=20)
    end_bar(f, "violet", half_x=0.044)
    f.torus_yz("RingGuard", -0.2, 0.0, 0.06, 0.012, "violet", seg=28, tube=12)
    grip_bands(f, "violet", "lavender", bands=2)
    f.sphere("Orb", (0, -0.5 + 0.03, 0), 0.03, "magenta_hot", segs=16, rings=8)
    for k in range(3):
        a = 2 * _m.pi * k / 3
        claw = f.lathe(f"Claw{k}", [(0.0, 0.0), (0.012, 0.0), (0.008, 0.024), (0.0, 0.036)], "violet", segs=12)
        f.orient(claw, rot=(0, 0, 0), loc=(0.028 * _m.cos(a), -0.476, 0.028 * _m.sin(a)))
    return {"design": "Nether Saber", "concept": "a light-drinking saber with three holes and a clawed orb", "tier": 2,
            "calm": ["lavender"], "vivid": ["deep_violet", "magenta_hot", "violet"]}


def design_starless_sabre(f):
    """Starless Sabre -- from the stretch of rift where no star shows. A straight single-edged
    lavender sabre with a violet edge and two empty five-point star holes cut through it (violet
    walls), a violet bar with crescent-curled tips, a violet grip with magenta bands and an empty
    ring pommel. Calm: lavender. Vivid: violet, magenta_hot."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        zb = -0.052 if t < 0.9 else lerp(-0.052, 0.0, (t - 0.9) / 0.1)
        ze = 0.06 if t < 0.8 else lerp(0.06, 0.0, smooth((t - 0.8) / 0.2))
        return zb, ze, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "lavender", "violet", n=26, chamfer=0.028, double=False)
    for k, y in enumerate((-0.05, 0.15)):
        cutter = f.prism(f"StarHole{k}", star(y, 0.004, 5, 0.032, 0.014), 0.08, "violet")
        f.cut(b, cutter)
    end_bar(f, "violet", y0=GUARD_Y0, y1=GUARD_Y0 + 0.028, half_x=0.044)
    for sign in (1, -1):
        tube(f, f"Curl{sign}", [(-0.21 + 0.03 * _m.sin(a), sign * (0.105 - 0.03 * (1 - _m.cos(a)))) for a in [j * _m.pi / 12 for j in range(13)]], 0.011, "violet")
    grip_bands(f, "violet", "magenta_hot", bands=2)
    ring_pommel(f, "lavender", R=0.026, r=0.011)
    return {"design": "Starless Sabre", "concept": "a sabre with empty star-shaped holes", "tier": 2,
            "calm": ["lavender"], "vivid": ["violet", "magenta_hot"]}


def design_collapse_claymore(f):
    """Collapse Claymore -- folded around a collapse that never finished. A violet claymore with
    lavender edges pinched sharply at its waist, a magenta sphere embedded at the pinch, deep-violet
    wings folding inward toward the blade, a deep-violet grip with lavender bands and a twisted
    four-sided violet cone pommel. Calm: lavender. Vivid: violet, magenta_hot, deep_violet."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        pinch = 1 - 0.62 * _m.exp(-((t - 0.46) / 0.1) ** 2)
        w = 0.086 * pinch if t < 0.84 else lerp(0.086, 0.012, smooth((t - 0.84) / 0.16))
        return -w, w, lerp(0.031, 0.016, t)
    b, st = blade(f, fn, "violet", "lavender", n=46, chamfer=0.026)
    y = BLADE_ROOT_Y + 0.46 * (TIP_Y - BLADE_ROOT_Y)
    f.sphere("Collapse", (0, y, 0), 0.036, "magenta_hot", segs=18, rings=9)
    end_bar(f, "deep_violet", y0=GUARD_Y0, y1=GUARD_Y0 + 0.028, half_x=0.046)
    pair(f, "FoldWing", [(GUARD_Y0 + 0.028, 0.06), (GUARD_Y0 + 0.028, 0.12), (-0.15, 0.1), (-0.16, 0.086)], 0.028, "deep_violet")
    grip_bands(f, "deep_violet", "lavender", bands=2)
    cone = f.lathe("TwistCone", [(0.0, -0.5), (0.04, -0.5), (0.03, -0.476), (0.0, -0.45)], "violet", segs=4)
    f.flat(f.orient(cone, rot=(0, _m.radians(45), 0)))
    return {"design": "Collapse Claymore", "concept": "a pinched claymore with a collapse at its waist", "tier": 3,
            "calm": ["lavender"], "vivid": ["violet", "magenta_hot", "deep_violet"]}


def design_eventide_claymore(f):
    """Eventide Claymore -- the colour of the last light before the rift. A tapering claymore in
    three hard bands root to tip (magenta, violet, deep violet) with lavender edges, a raised
    setting half-sun at the root (magenta on a lavender rim), a lavender horizon bar with violet end
    caps, a violet grip with lavender bands and a magenta half-sun pommel.
    Calm: lavender. Vivid: magenta_hot, violet, deep_violet."""
    n = 42

    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.092, 0.05, t / 0.84) if t < 0.84 else lerp(0.05, 0.008, smooth((t - 0.84) / 0.16))
        return -w, w, lerp(0.031, 0.016, t)
    b, st = blade(f, fn, "violet", "lavender", n=n, chamfer=0.028,
                  paint=lambda i, k, r: "lavender" if r != "body" else ("magenta_hot" if i < n / 3 else ("violet" if i < 2 * n / 3 else "deep_violet")))
    half = lambda cy, r: [(cy, -r)] + [(cy + r * _m.sin(a), -r * _m.cos(a)) for a in [_m.pi * k / 12 for k in range(1, 12)]] + [(cy, r)]
    plate(f, "SunRim", half(-0.19, 0.05), "lavender", st, lift=0.006)
    plate(f, "Sun", half(-0.19, 0.036), "magenta_hot", st, lift=0.01)
    end_bar(f, "lavender", half_x=0.046, span=0.1)       # the caps own the +-0.13 ends: no shared end face
    pair(f, "Cap", [(GUARD_Y0, 0.1), (GUARD_Y1, 0.1), (GUARD_Y1, 0.13), (GUARD_Y0, 0.13)], 0.05, "violet")
    grip_bands(f, "violet", "lavender", bands=2)
    f.prism("HalfSunPommel", [(-0.5, -0.04), (-0.5, 0.04)] + [(-0.5 + 0.04 * _m.sin(a), 0.04 * _m.cos(a)) for a in [_m.pi * k / 12 for k in range(1, 12)]], 0.024, "magenta_hot")
    return {"design": "Eventide Claymore", "concept": "a sunset-banded claymore with a setting sun", "tier": 3,
            "calm": ["lavender"], "vivid": ["magenta_hot", "violet", "deep_violet"]}


def design_singularity_greatsword(f):
    """Singularity Greatsword -- a pinpoint of collapsed void at its heart. A deep-violet leaf
    greatsword with lavender edges and a big round hole at mid-blade, a magenta sphere suspended in
    it on two lavender struts and a raised lavender ring round the hole, a violet accretion ring
    round the guard over a bar, a violet grip with lavender bands and a magenta orb pommel.
    Calm: lavender. Vivid: deep_violet, magenta_hot, violet."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.06, 0.1, smooth(t / 0.45)) if t < 0.45 else lerp(0.1, 0.01, smooth((t - 0.45) / 0.55))
        return -w, w, lerp(0.032, 0.016, t)
    b, st = blade(f, fn, "deep_violet", "lavender", n=30, chamfer=0.028)
    yc = BLADE_ROOT_Y + 0.45 * (TIP_Y - BLADE_ROOT_Y)
    hole(f, b, "EventHorizon", yc, 0.0, 0.042, "violet", segs=28)
    f.torus_yz("HorizonRing", yc, 0.0, 0.048, 0.012, "lavender", seg=32, tube=12)
    f.sphere("Singularity", (0, yc, 0), 0.02, "magenta_hot", segs=14, rings=7)
    rod(f, "Strut", (0, yc, -0.05), (0, yc, 0.05), 0.007, "lavender", segs=12)
    end_bar(f, "violet", half_x=0.046)
    f.torus_yz("Accretion", -0.19, 0.0, 0.062, 0.012, "violet", seg=32, tube=12)
    grip_bands(f, "violet", "lavender", bands=2)
    ball_pommel(f, "magenta_hot", r=0.036)
    return {"design": "Singularity Greatsword", "concept": "a greatsword with a suspended singularity in a hole", "tier": 3,
            "calm": ["lavender"], "vivid": ["deep_violet", "magenta_hot", "violet"]}


def design_archons_verdict(f):
    """Archon's Verdict (Legendary) -- the sentence, passed in a single stroke. A tall straight
    lavender blade with a squared-off point, verdict-violet edges and a raised violet rune rib, a
    magenta halo round its upper third, two-tier feathered violet wings over the bar, a violet grip
    with lavender bands and an all-seeing eye pommel (lavender ball, violet iris, magenta pupil).
    Calm: lavender. Vivid: verdict, violet, magenta_hot."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        zb = -0.074 if t < 0.9 else lerp(-0.074, -0.03, (t - 0.9) / 0.1)
        ze = 0.074 if t < 0.9 else lerp(0.074, 0.03, (t - 0.9) / 0.1)
        return zb, ze, lerp(0.031, 0.016, t)
    b, st = blade(f, fn, "lavender", "verdict", n=24, chamfer=0.026)
    briar_rib(f, "Rune", st[1:18], 0, 0.012, "violet", extra=0.006)
    ring_around(f, "Halo", 0.3, 0.092, 0.013, "magenta_hot", segs=28)
    end_bar(f, "violet", half_x=0.046)
    pair(f, "FeatherHigh", [(GUARD_Y1, 0.05), (GUARD_Y1, 0.11), (-0.14, 0.118), (-0.16, 0.08)], 0.026, "violet")
    pair(f, "FeatherLow", [(GUARD_Y0, 0.1), (GUARD_Y0, 0.118), (-0.3, 0.118), (-0.29, 0.1)], 0.026, "verdict")
    grip_bands(f, "violet", "lavender", bands=2)
    ball_pommel(f, "lavender", r=0.038)
    for side in (1, -1):
        iris = rim_disc(f, f"Iris{side}", -0.47, 0.02, 0.007, "violet", segs=20)
        f.orient(iris, loc=(side * 0.034, 0, 0))
        pupil = rim_disc(f, f"Pupil{side}", -0.47, 0.01, 0.007, "magenta_hot", segs=16)
        f.orient(pupil, loc=(side * 0.041, 0, 0))
    return {"design": "Archon's Verdict", "concept": "a square-tipped verdict blade under a halo, winged, with an eye", "tier": 4,
            "calm": ["lavender"], "vivid": ["verdict", "violet", "magenta_hot"]}


DESIGNS.update({
    "Sword_RiftDagger": ("Boss_VoidWraith", 1, design_rift_dagger),
    "Sword_UmbralFalchion": ("Boss_VoidWraith", 2, design_umbral_falchion),
    "Sword_NightfallKris": ("Boss_VoidWraith", 2, design_nightfall_kris),
    "Sword_NetherSaber": ("Boss_VoidWraith", 2, design_nether_saber),
    "Sword_StarlessSabre": ("Boss_VoidWraith", 2, design_starless_sabre),
    "Sword_CollapseClaymore": ("Boss_VoidWraith", 3, design_collapse_claymore),
    "Sword_EventideClaymore": ("Boss_VoidWraith", 3, design_eventide_claymore),
    "Sword_SingularityGreatsword": ("Boss_VoidWraith", 3, design_singularity_greatsword),
    "Sword_ArchonsVerdict": ("Boss_VoidWraith", 4, design_archons_verdict),
})
