# Boss_Gorgon pool -- the Warden of the Pit's armoury (brief section 8.1).
# Echo the Warden: toy-blue iron, coral banners, rust-orange rivets, cage bars, chains, shackles.


def design_pit_shiv(f):
    """Pit Shiv -- a prisoner's blade ground from a pit shackle. A stubby sky-white single-edged
    blade with a flat oblique chisel tip and an orange edge, a toy-blue bar, a cream grip with two
    coral rag wraps, and a toy-blue shackle ring with a pin bolt for a pommel.
    Calm: sky_white, cream_grip. Vivid: orange, toy_blue, coral."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        zb = lerp(-0.05, -0.054, t) if t < 0.82 else lerp(-0.054, -0.03, (t - 0.82) / 0.18)
        ze = lerp(0.066, 0.078, t / 0.6) if t < 0.72 else lerp(0.078, -0.012, (t - 0.72) / 0.28)
        return zb, ze, lerp(0.03, 0.02, t)
    blade(f, fn, "sky_white", "orange", n=22, chamfer=0.028, double=False)
    # the shackle it was ground from, still clamped round the blade, with its pin bolt
    ring_around(f, "Shackle", -0.1, 0.082, 0.014, "toy_blue", segs=20)
    rod(f, "ShacklePin", (0, -0.1, -0.1), (0, -0.1, 0.1), 0.011, "orange", segs=12)
    end_bar(f, "toy_blue", half_x=0.046)
    grip_bands(f, "cream_grip", "coral", bands=2, band_r=0.046)
    ring_pommel(f, "toy_blue", R=0.028, r=0.012)
    rod(f, "Pin", (-0.05, -0.5 + 0.012, 0), (0.05, -0.5 + 0.012, 0), 0.01, "orange", segs=12)
    return {"design": "Pit Shiv", "concept": "a chisel-ended shiv ground from a shackle", "tier": 1,
            "calm": ["sky_white", "cream_grip"], "vivid": ["orange", "toy_blue", "coral"]}


def design_ironjaw_saber(f):
    """Ironjaw Saber -- a curved iron saber notched like a jaw. A curved sky-white saber with a
    toy-blue spine and four round bites out of the edge near the root (their walls coral, like
    gums), a jaw guard of two toy-blue tubes curling toward the blade over the bar, a cream grip
    with toy-blue bands and an orange rivet-dome pommel.
    Calm: sky_white, cream_grip. Vivid: toy_blue, coral, orange."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.055 * t * t
        w = 0.056 if t < 0.8 else lerp(0.056, 0.008, smooth((t - 0.8) / 0.2))
        return c - w, c + w, lerp(0.029, 0.014, t)

    b, st = blade(f, fn, "sky_white", "coral", n=28, chamfer=0.026, double=False, paint=lambda i, k, r: "sky_white" if r == "body" else "toy_blue")
    for k, y in enumerate((-0.13, -0.05, 0.03, 0.11)):
        hole(f, b, f"Bite{k}", y, fn(y)[1] + 0.006, 0.03, "coral", segs=20)
    end_bar(f, "toy_blue", y0=GUARD_Y0, y1=GUARD_Y0 + 0.03, half_x=0.046)
    for sign in (1, -1):
        pts = [(-0.225 + 0.05 * _m.sin(a), sign * (0.06 + 0.045 * _m.cos(a))) for a in [j * _m.pi * 1.1 / 12 for j in range(13)]]
        tube(f, f"Jaw{sign}", pts, 0.014, "toy_blue")
    grip_bands(f, "cream_grip", "coral", bands=3)
    ball_pommel(f, "orange", r=0.036)
    return {"design": "Ironjaw Saber", "concept": "a saber with jaw bites out of its edge and a jaw guard", "tier": 2,
            "calm": ["sky_white", "cream_grip"], "vivid": ["toy_blue", "coral", "orange"]}


def design_slag_falchion(f):
    """Slag Falchion -- a wide slag-forged chopper still warm. A broad orange falchion widening to
    a clipped tip with a cream edge, three amber slag drips fused along its spine, a thick toy-blue
    crucible-lip guard, a cream grip with orange bands and a lumpy faceted amber slag-nugget pommel.
    Calm: cream, cream_grip. Vivid: orange, amber, toy_blue."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        zb = -0.046 if t < 0.9 else lerp(-0.046, -0.02, (t - 0.9) / 0.1)
        ze = lerp(0.05, 0.1, smooth(t / 0.7)) if t < 0.86 else lerp(0.1, 0.03, (t - 0.86) / 0.14)
        return zb, ze, lerp(0.03, 0.018, t)
    b, st = blade(f, fn, "orange", "cream", n=26, chamfer=0.032, double=False)
    for k, y in enumerate((0.0, 0.14, 0.28)):
        f.sphere(f"Drip{k}", (0, y, fn(y)[0]), 0.022 - 0.003 * k, "amber", segs=14, rings=7)
    end_bar(f, "toy_blue", half_x=0.05)
    tube(f, "CrucibleLip", [(-0.19, -0.1), (-0.184, -0.05), (-0.182, 0.0), (-0.184, 0.05), (-0.19, 0.1)], 0.014, "toy_blue")
    grip_bands(f, "cream_grip", "orange", bands=2)
    f.lathe("SlagBase", [(0.0, -0.5), (0.03, -0.5), (0.03, -0.486), (0.0, -0.486)], "orange", segs=20)
    nugget(f, "Slag", -0.462, 0.034, "amber")
    return {"design": "Slag Falchion", "concept": "a slag chopper with amber drips on its spine", "tier": 2,
            "calm": ["cream", "cream_grip"], "vivid": ["orange", "amber", "toy_blue"]}


def design_chainbreaker(f):
    """Chainbreaker -- the greatsword that splits chain and cage bar. A broad parallel sky-white
    greatsword with a rounded square tip and coral edges; a broken toy-blue chain link wraps the
    blade above the guard (a ring with a gap cut through it) and a second broken link lies on each
    face near the tip; a cage-bar guard with two bar stubs rising each side; a cream grip with
    toy-blue bands and an orange hex-nut pommel. Calm: sky_white, cream_grip. Vivid: coral, toy_blue, orange."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = 0.078 if t < 0.88 else lerp(0.078, 0.03, smooth((t - 0.88) / 0.12))
        return -w, w, lerp(0.031, 0.017, t)
    b, st = blade(f, fn, "sky_white", "coral", n=24, chamfer=0.028)
    link = ring_around(f, "Link", -0.12, 0.094, 0.013, "toy_blue")
    gap = f.prism("LinkGap", [(-0.16, 0.06), (-0.08, 0.06), (-0.08, 0.13), (-0.16, 0.13)], 0.2, "toy_blue")
    f.cut(link, gap)
    for k, y in enumerate((0.2, 0.3)):
        outer = [(y + 0.045 * _m.cos(a), 0.028 * _m.sin(a)) for a in [2 * _m.pi * j / 20 for j in range(20)]]
        plate(f, f"FaceLink{k}", outer, "toy_blue", st, lift=0.006)
        inner = [(y + 0.028 * _m.cos(a), 0.012 * _m.sin(a)) for a in [2 * _m.pi * j / 16 for j in range(16)]]
        plate(f, f"FaceLinkHole{k}", inner, "sky_white", st, lift=0.009)
    end_bar(f, "toy_blue", half_x=0.048)
    for sign in (1, -1):
        for z in (0.07, 0.105):
            f.prism(f"Cage{sign}{z}", [(-0.2, sign * (z - 0.009)), (-0.165, sign * (z - 0.009)), (-0.165, sign * (z + 0.009)), (-0.2, sign * (z + 0.009))][::sign], 0.02, "toy_blue")
    grip_bands(f, "cream_grip", "toy_blue", bands=2)
    nut = f.lathe("HexNut", [(0.0, -0.5), (0.042, -0.5), (0.042, -0.46), (0.0, -0.46)], "orange", segs=6)
    f.flat(nut)
    return {"design": "Chainbreaker", "concept": "a greatsword with broken chain links and a cage-bar guard", "tier": 3,
            "calm": ["sky_white", "cream_grip"], "vivid": ["coral", "toy_blue", "orange"]}


def design_duneglass_edge(f):
    """Duneglass Edge -- amber desert glass honed sun-bright. A faceted amber glass blade (flat
    facets) with sky-white edges and a raised cream sun-glint stripe on each face, a cream dune-wave
    guard, an orange grip with cream bands and a faceted amber gem pommel.
    Calm: cream, sky_white. Vivid: amber, orange."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.058, 0.072, t / 0.5) if t < 0.5 else lerp(0.072, 0.008, ((t - 0.5) / 0.5) ** 1.1)
        return -w, w, lerp(0.03, 0.014, t)
    b, st = blade(f, fn, "amber", "sky_white", n=15, chamfer=0.028, flat=True)
    disc_plate(f, "Sun", -0.15, 0.0, 0.026, "cream", st)
    stud(f, "SunCore", -0.15, 0.0, 0.013, "orange", st)
    for k, (y0, y1) in enumerate(((-0.1, 0.02), (0.1, 0.2))):
        plate(f, f"Glint{k}", [(y0, -0.03), (y0 + 0.02, -0.03), (y1 + 0.02, 0.03), (y1, 0.03)], "cream", st)
    top = [(-0.195 + 0.012 * _m.sin(3 * _m.pi * (z / 0.13)), z) for z in [0.13 * (k / 8 - 1) for k in range(17)]]
    f.prism("Dune", [(GUARD_Y0, 0.13), (GUARD_Y0, -0.13)] + top, 0.046, "cream")
    grip_bands(f, "orange", "cream", bands=3)
    gem_pommel(f, "amber", r=0.044, segs=8)
    return {"design": "Duneglass Edge", "concept": "a faceted desert-glass blade over a dune guard", "tier": 3,
            "calm": ["cream", "sky_white"], "vivid": ["amber", "orange"]}


def design_pit_sovereign(f):
    """Pit Sovereign (Legendary) -- the Warden's ember-lit greatsword, king of the pit. A broad
    sky-white greatsword with gold edges and a raised ember-orange core rib, a gold crown guard (a
    bar with three crown points rising toward the blade and rivet studs), a coral banner hanging on
    each face of the grip, a cream grip with gold bands and a gold crown pommel set with coral jewels.
    Calm: sky_white. Vivid: gold, ember_orange, coral, toy_blue."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.104, 0.01, t ** 1.15)                      # a tall royal triangle, widest at the root
        return -w, w, lerp(0.031, 0.015, t)
    b, st = blade(f, fn, "sky_white", "gold", n=28, chamfer=0.028)
    briar_rib(f, "EmberCore", st[1:-6], 0, 0.016, "ember_orange", extra=0.006)
    end_bar(f, "gold", half_x=0.048)
    # three crown points: the outer two stand beyond the wide blade root so they read from the side
    for z, h in ((-0.113, 0.05), (0.113, 0.05)):
        f.prism(f"Crown{z}", [(GUARD_Y1, z - 0.009), (GUARD_Y1, z + 0.009), (GUARD_Y1 + h, z)], 0.03, "gold")
    for z in (-0.1, 0.1):
        for side in (1, -1):
            f.sphere(f"Rivet{z}{side}", (side * 0.048, (GUARD_Y0 + GUARD_Y1) / 2, z), 0.013, "coral", segs=12, rings=6)
    grip_bands(f, "cream_grip", "gold", bands=2, band_r=0.045)
    collar(f, "toy_blue")
    for side in (1, -1):
        f.prism(f"Banner{side}", [(-0.262, -0.03), (-0.262, 0.03), (-0.34, 0.03), (-0.322, 0.0), (-0.34, -0.03)], 0.006,
                "coral", x_centre=side * 0.05)
    f.lathe("CrownBand", [(0.0, -0.5), (0.04, -0.5), (0.042, -0.47), (0.0, -0.47)], "gold", segs=24)
    for k in range(6):
        a = 2 * _m.pi * k / 6
        f.sphere(f"Jewel{k}", (0.041 * _m.cos(a), -0.485, 0.041 * _m.sin(a)), 0.01, "coral", segs=12, rings=6)
    return {"design": "Pit Sovereign", "concept": "a crowned greatsword with an ember core and banners", "tier": 4,
            "calm": ["sky_white", "cream_grip"], "vivid": ["gold", "ember_orange", "coral", "toy_blue"]}


DESIGNS.update({
    "Sword_PitShiv": ("Boss_Gorgon", 1, design_pit_shiv),
    "Sword_IronjawSaber": ("Boss_Gorgon", 2, design_ironjaw_saber),
    "Sword_SlagFalchion": ("Boss_Gorgon", 2, design_slag_falchion),
    "Sword_Chainbreaker": ("Boss_Gorgon", 3, design_chainbreaker),
    "Sword_DuneglassEdge": ("Boss_Gorgon", 3, design_duneglass_edge),
    "Sword_PitSovereign": ("Boss_Gorgon", 4, design_pit_sovereign),
})
