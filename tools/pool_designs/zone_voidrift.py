# VoidRift -- the rift's everyday blades (brief section 8.12).
# Shards, hush, gloam pours, null marks, rift doors, a sleepy star, a fang kris, a tanto and a
# wishbone comet. Calm: lavender, pale_lilac. Vivid: violet, deep_violet, magenta_hot, quiet_star.


def rotated_cutter(f, name, poly_xz, half_y, colour, y):
    """A prism whose outline lies in the X-Z plane (extruded along Y): cuts through a flat tsuba."""
    c = f.prism(name, poly_xz, half_y, colour)
    return f.orient(c, rot=(0, 0, _m.pi / 2), loc=(0, y, 0))


def design_riftsliver(f):
    """Riftsliver -- a sliver the rift shed, sharp on every side. A thin flat-shaded lavender rhombus
    shard with violet edges, two small violet shards as a crossbar, a deep-violet grip with
    lavender bands and a smaller magenta-hot shard pommel.
    Calm: lavender. Vivid: violet, deep_violet, magenta_hot."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.03, 0.058, t / 0.42) if t < 0.42 else lerp(0.058, 0.004, (t - 0.42) / 0.58)
        return -w, w, lerp(0.026, 0.013, t)
    blade(f, fn, "lavender", "violet", n=11, chamfer=0.026, flat=True)
    yc = (GUARD_Y0 + GUARD_Y1) / 2
    shard = [(yc - 0.014, 0.018), (yc + 0.02, 0.07), (yc + 0.012, 0.13), (yc - 0.02, 0.13), (yc - 0.026, 0.07)]
    for p in (shard, mirror(shard)):
        f.flat(f.prism(f"Shard{p[0][1]:.2f}", p, 0.034, "violet"))
    f.flat(f.prism("Hub", [(yc - 0.02, -0.03), (yc - 0.02, 0.03), (yc + 0.018, 0.03), (yc + 0.018, -0.03)], 0.04, "violet"))
    grip_bands(f, "deep_violet", "lavender", bands=2)
    f.flat(f.prism("Sliver", [(-0.5, 0.0), (-0.472, 0.024), (-0.436, 0.0), (-0.472, -0.024)], 0.02, "magenta_hot"))
    return {"design": "Riftsliver", "concept": "a thin rhombus shard with shard guards", "tier": 1,
            "calm": ["lavender"], "vivid": ["violet", "deep_violet", "magenta_hot"]}


def design_hushed_falchion(f):
    """Hushed Falchion -- makes no sound, not even on impact. A violet falchion with a lavender edge,
    its root wrapped in two soft bulging pale-lilac muffler bands, a soft lavender pillow bar, a
    violet grip with lavender bands and an open, clapperless magenta-hot bell pommel.
    Calm: lavender, pale_lilac. Vivid: violet, magenta_hot."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        zb = -0.048 if t < 0.82 else lerp(-0.048, 0.012, smooth((t - 0.82) / 0.18))
        ze = lerp(0.048, 0.084, smooth(t / 0.72)) if t < 0.84 else lerp(0.084, 0.018, smooth((t - 0.84) / 0.16))
        return zb, ze, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "violet", "lavender", n=26, chamfer=0.026, double=False)
    for k, y in enumerate((-0.16, -0.105)):
        m = f.lathe(f"Muffle{k}", [(0.0, y - 0.02), (0.056, y - 0.02), (0.066, y - 0.01), (0.068, y), (0.066, y + 0.01), (0.056, y + 0.02), (0.0, y + 0.02)],
                    "pale_lilac", segs=24)
        f.orient(m, scale=(0.6, 1, 1))
    pillow = [(GUARD_Y0, -0.13), (GUARD_Y0 - 0.006, -0.06), (GUARD_Y0 - 0.008, 0.0), (GUARD_Y0 - 0.006, 0.06), (GUARD_Y0, 0.13),
              (GUARD_Y1, 0.13), (GUARD_Y1 + 0.006, 0.06), (GUARD_Y1 + 0.008, 0.0), (GUARD_Y1 + 0.006, -0.06), (GUARD_Y1, -0.13)]
    f.prism("Pillow", pillow, 0.048, "lavender")
    grip_bands(f, "violet", "lavender", bands=2)
    f.lathe("HushBell", [(0.0, -0.44), (0.016, -0.444), (0.024, -0.46), (0.032, -0.482), (0.042, -0.5), (0.034, -0.5),
                         (0.024, -0.482), (0.018, -0.462), (0.0, -0.458)], "magenta_hot", segs=20)
    return {"design": "Hushed Falchion", "concept": "a falchion muffled at the root with soft cloth bands", "tier": 2,
            "calm": ["lavender", "pale_lilac"], "vivid": ["violet", "magenta_hot"]}


def design_gloamsteel_sabre(f):
    """Gloamsteel Sabre -- poured in the gloam between two rifts. A curved deep-violet sabre with a
    magenta-hot edge, its upper blade poured over in raised lavender with a wavy boundary and two
    long drips, two lavender rift crescents on a magenta-hot bar, a lavender grip with deep-violet
    bands and a magenta-hot drop pommel. Calm: lavender. Vivid: deep_violet, magenta_hot."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.085 * t * t
        w = 0.05 if t < 0.8 else lerp(0.05, 0.008, smooth((t - 0.8) / 0.2))
        return c - w, c + w, lerp(0.029, 0.015, t)
    b, st = blade(f, fn, "deep_violet", "magenta_hot", n=28, chamfer=0.026, double=False)
    top = 0.4
    bottom = []
    for j in range(15):
        u = j / 14
        y0 = 0.12 + 0.014 * _m.sin(u * 3 * _m.pi)
        y0 -= 0.1 * _m.exp(-((u - 0.3) / 0.07) ** 2) + 0.06 * _m.exp(-((u - 0.72) / 0.06) ** 2)
        zb, ze, _ = fn(y0)
        bottom.append((y0, lerp(zb + 0.006, ze - 0.03, u)))
    ys = [bottom[-1][0] + (top - bottom[-1][0]) * k / 10 for k in range(1, 11)]
    edge_side = [(y, fn(y)[1] - 0.03) for y in ys]
    back_side = [(y, fn(y)[0] + 0.006) for y in reversed([bottom[0][0] + (top - bottom[0][0]) * k / 10 for k in range(1, 11)])]
    plate(f, "Pour", bottom + edge_side + back_side, "lavender", st, lift=0.005)
    end_bar(f, "magenta_hot", y1=GUARD_Y1 - 0.016, half_x=0.042)
    for sign in (1, -1):
        f.prism(f"Crescent{sign}", crescent(GUARD_Y1 - 0.02, sign * 0.08, 0.034, 0.014, facing=1), 0.032, "lavender")
    grip_bands(f, "lavender", "deep_violet", bands=2)
    f.lathe("Drop", [(0.012, -0.5), (0.03, -0.493), (0.039, -0.478), (0.035, -0.46), (0.022, -0.446), (0.01, -0.432), (0.0, -0.426)], "magenta_hot", segs=20)
    return {"design": "Gloamsteel Sabre", "concept": "a sabre half-poured in dripping lavender gloam", "tier": 2,
            "calm": ["lavender"], "vivid": ["deep_violet", "magenta_hot"]}


def half_ring(cy, cz, R, r, a0, n=12):
    """Half an annulus (a C) from angle a0 through pi more: rings built from two halves never need a hole."""
    out = [(cy + R * _m.sin(a), cz + R * _m.cos(a)) for a in [a0 + _m.pi * k / n for k in range(n + 1)]]
    inn = [(cy + r * _m.sin(a), cz + r * _m.cos(a)) for a in [a0 + _m.pi * k / n for k in range(n, -1, -1)]]
    return out + inn


def design_nullbrand_longsword(f):
    """Nullbrand Longsword -- leaves nothing behind to heal. A straight lavender longsword with violet
    edges and a raised violet null symbol (a ring with a diagonal slash) through the root, a violet
    bar with square hollow frame ends, a violet grip with magenta-hot bands and a hollow magenta-hot
    ring pommel. Calm: lavender. Vivid: violet, magenta_hot."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = 0.064 if t < 0.86 else lerp(0.064, 0.01, smooth((t - 0.86) / 0.14))
        return -w, w, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "lavender", "violet", n=26, chamfer=0.026)
    cy = -0.06
    for k in range(2):
        plate(f, f"Null{k}", half_ring(cy, 0.0, 0.04, 0.028, k * _m.pi), "violet", st, lift=0.006)
    a = _m.radians(40)
    dy, dz, ny, nz = 0.05 * _m.cos(a), 0.05 * _m.sin(a), -0.006 * _m.sin(a), 0.006 * _m.cos(a)
    plate(f, "Slash", [(cy - dy + ny, -dz + nz), (cy + dy + ny, dz + nz), (cy + dy - ny, dz - nz), (cy - dy - ny, -dz - nz)], "magenta_hot", st, lift=0.009)
    yc = (GUARD_Y0 + GUARD_Y1) / 2
    end_bar(f, "violet", y0=yc - 0.014, y1=yc + 0.014, half_x=0.04, span=0.08)
    for sign in (1, -1):
        for name, (za, zb2, ya, yb) in {"In": (0.08, 0.09, -0.018, 0.018), "Out": (0.12, 0.13, -0.018, 0.018),
                                         "Top": (0.08, 0.13, 0.018, 0.028), "Bot": (0.08, 0.13, -0.028, -0.018)}.items():
            poly = [(yc + ya, sign * za), (yc + ya, sign * zb2), (yc + yb, sign * zb2), (yc + yb, sign * za)]
            f.prism(f"Frame{name}{sign}", poly, 0.042, "violet")
    grip_bands(f, "violet", "magenta_hot", bands=2)
    ring_pommel(f, "magenta_hot", R=0.028, r=0.011)
    return {"design": "Nullbrand Longsword", "concept": "a longsword branded with a null ring and slash", "tier": 3,
            "calm": ["lavender"], "vivid": ["violet", "magenta_hot"]}


def design_riftwalker_broadsword(f):
    """Riftwalker Broadsword -- collapsed rift-glass, heavy as a door. A wide flat-shaded violet
    door of a broadsword with a flat, corner-cut top, with lavender edges and a raised lavender door-panel frame with a magenta-hot knob on
    each face, a lavender door-hinge bar with two deep-violet hinge barrels on each face, a
    deep-violet grip with magenta-hot bands and a lavender keyhole-plate pommel.
    Calm: lavender. Vivid: violet, magenta_hot, deep_violet."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        # a door: straight sides and a flat top with its corners bevelled off
        w = 0.086 if t < 0.93 else lerp(0.086, 0.056, (t - 0.93) / 0.07)
        return -w, w, lerp(0.034, 0.017, t)
    b, st = blade(f, fn, "violet", "lavender", n=13, chamfer=0.032, flat=True)
    y0, y1, z0 = -0.15, 0.18, 0.05
    # the uprights stop at the cross bars so no two plates share a face (a z-fight reads black)
    for name, poly in {"Left": [(y0 + 0.01, -z0), (0.01, -z0), (0.01, -z0 + 0.01), (y0 + 0.01, -z0 + 0.01)],
                       "LeftUp": [(0.02, -z0), (y1 - 0.01, -z0), (y1 - 0.01, -z0 + 0.01), (0.02, -z0 + 0.01)],
                       "Right": [(y0 + 0.01, z0 - 0.01), (0.01, z0 - 0.01), (0.01, z0), (y0 + 0.01, z0)],
                       "RightUp": [(0.02, z0 - 0.01), (y1 - 0.01, z0 - 0.01), (y1 - 0.01, z0), (0.02, z0)],
                       "Top": [(y1 - 0.01, -z0), (y1, -z0), (y1, z0), (y1 - 0.01, z0)],
                       "Bottom": [(y0, -z0), (y0 + 0.01, -z0), (y0 + 0.01, z0), (y0, z0)],
                       "Rail": [(0.01, -z0), (0.02, -z0), (0.02, z0), (0.01, z0)]}.items():
        plate(f, f"Panel{name}", poly, "lavender", st, lift=0.006, flat=True)
    stud(f, "Knob", 0.0, 0.03, 0.02, "magenta_hot", st, segs=16, rings=8)
    end_bar(f, "lavender", half_x=0.044)
    for side in (1, -1):
        for z in (-0.07, 0.07):
            rod(f, f"Hinge{side}{z}", (side * 0.048, GUARD_Y0 - 0.006, z), (side * 0.048, GUARD_Y1 + 0.006, z), 0.012, "deep_violet", segs=16)
    grip_bands(f, "deep_violet", "magenta_hot", bands=2)
    plate_ = rim_disc(f, "KeyPlate", -0.46, 0.04, 0.018, "lavender", segs=28)
    hole(f, plate_, "Keyhole", -0.452, 0.0, 0.009, "deep_violet", segs=16)
    slot = f.prism("KeySlot", [(-0.476, -0.005), (-0.476, 0.005), (-0.452, 0.004), (-0.452, -0.004)], 0.1, "deep_violet")
    f.sync_materials()
    f.cut(plate_, slot)
    return {"design": "Riftwalker Broadsword", "concept": "a faceted rift-glass door of a broadsword", "tier": 3,
            "calm": ["lavender"], "vivid": ["violet", "magenta_hot", "deep_violet"]}


def design_quiet_star(f):
    """Quiet Star (Relic) -- a star that fell through the rift and stopped shining. A quiet-star violet
    blade with lavender edges, a big lavender five-point star with a sleepy violet face (two closed
    eyes, a small mouth) at the root inside a magenta-hot rift ring, two small lavender stars
    trailing up the blade, a violet crescent-moon bar, a deep-violet grip with lavender bands and a
    small lavender star pommel. Calm: lavender. Vivid: quiet_star, violet, magenta_hot, deep_violet."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.04, 0.068, smooth(t / 0.5)) if t < 0.84 else lerp(0.068, 0.01, smooth((t - 0.84) / 0.16))
        return -w, w, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "quiet_star", "lavender", n=26, chamfer=0.026)
    cy = -0.1
    f.torus_yz("RiftRing", cy, 0.0, 0.09, 0.014, "magenta_hot", seg=32, tube=12)
    t0 = th_at(st, cy) + 0.008
    f.prism("Star", star(cy, 0.0, 5, 0.078, 0.034), t0, "lavender")
    for sign in (1, -1):
        f.prism(f"Eye{sign}", swoosh(cy + 0.01, sign * 0.018, 0.013, 0.005, _m.pi * 0.6, _m.pi * 1.4, n=8), t0 + 0.004, "violet")
    f.prism("Mouth", swoosh(cy - 0.004, 0.0, 0.01, 0.004, _m.pi * 0.7, _m.pi * 1.3, n=6), t0 + 0.004, "violet")
    for k, (y, r) in enumerate(((0.07, 0.028), (0.19, 0.02))):
        plate(f, f"Trail{k}", star(y, 0.0, 5, r, r * 0.44), "lavender", st, lift=0.007)
    zs = [-0.13 + 0.26 * j / 16 for j in range(17)]
    moon = [(GUARD_Y0 + 0.03 * (z / 0.13) ** 2, z) for z in zs] + [(GUARD_Y1 - 0.02 + 0.048 * (z / 0.13) ** 2, z) for z in reversed(zs)]
    f.prism("Moon", moon, 0.044, "violet")
    grip_bands(f, "deep_violet", "lavender", bands=2)
    f.prism("PommelStar", star(-0.5 + 0.034, 0.0, 5, 0.034, 0.015, rot=_m.pi), 0.02, "lavender")
    return {"design": "Quiet Star", "concept": "a sleepy fallen star at the root of a violet blade", "tier": 4,
            "calm": ["lavender"], "vivid": ["quiet_star", "violet", "magenta_hot", "deep_violet"]}


def design_hushfang_kris(f):
    """Hushfang Kris -- a wavy kris that bites without a sound. A violet kris rippling in five waves
    into a curved fang tip, a magenta-hot edge, a magenta-hot bar with two lavender fang teeth
    pointing up the blade, a lavender grip with violet bands and a lavender fang-cone pommel.
    Calm: lavender. Vivid: violet, magenta_hot."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.016 * _m.sin(5 * 2 * _m.pi * t / 0.8) if t < 0.8 else 0.0
        c += 0.07 * ((t - 0.78) / 0.22) ** 2 if t > 0.78 else 0.0
        w = lerp(0.05, 0.04, t) if t < 0.8 else lerp(0.04, 0.006, smooth((t - 0.8) / 0.2))
        return c - w, c + w, lerp(0.028, 0.014, t)
    blade(f, fn, "violet", "magenta_hot", n=40, chamfer=0.022)
    end_bar(f, "magenta_hot", half_x=0.042)
    for z in (-0.08, 0.08):
        icicle(f, f"Fang{z}", GUARD_Y1 - 0.004, z, 0.05, 0.016, "lavender", down=False)
    grip_bands(f, "lavender", "violet", bands=2)
    icicle(f, "FangPommel", -0.44, 0.0, 0.06, 0.022, "lavender")
    return {"design": "Hushfang Kris", "concept": "a five-wave kris with a curved fang tip", "tier": 2,
            "calm": ["lavender"], "vivid": ["violet", "magenta_hot"]}


def design_gloam_tanto(f):
    """Gloam Tanto -- short and straight, drawn from the gloam. A straight deep-violet tanto with an
    angled chisel tip and a lavender edge, a round magenta-hot tsuba (its rim the guard's width) with
    two crescent cut-outs (lavender walls), a lavender grip with violet bands and a violet kashira cap.
    Calm: lavender. Vivid: deep_violet, magenta_hot, violet."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        ze = 0.044 if t < 0.82 else lerp(0.044, -0.036, (t - 0.82) / 0.18)
        return -0.042, ze, lerp(0.03, 0.017, t)
    blade(f, fn, "deep_violet", "lavender", n=16, chamfer=0.024, double=False)
    yc = (GUARD_Y0 + GUARD_Y1) / 2
    tsuba = f.lathe("Tsuba", [(0.0, yc - 0.012), (0.13, yc - 0.012), (0.13, yc + 0.012), (0.0, yc + 0.012)], "magenta_hot", segs=32)
    for sign in (1, -1):
        cut = rotated_cutter(f, f"Moon{sign}", crescent(0.0, sign * 0.085, 0.026, 0.012, facing=1), 0.05, "lavender", yc)
        f.sync_materials()
        f.cut(tsuba, cut)
    grip_bands(f, "lavender", "violet", bands=2)
    f.lathe("Kashira", [(0.0, -0.5), (0.03, -0.5), (0.04, -0.49), (0.042, -0.47), (0.0, -0.47)], "violet", segs=20)
    return {"design": "Gloam Tanto", "concept": "a chisel-tipped tanto with a crescent-cut tsuba", "tier": 1,
            "calm": ["lavender"], "vivid": ["deep_violet", "magenta_hot", "violet"]}


def design_wishbone_comet(f):
    """Wishbone Comet (spin relic) -- a comet split like a wishbone; you got the bigger half. A pale-
    lilac blade with magenta-hot edges forking at mid-length into a Y: the bigger tine runs on to the
    tip, a smaller tine branches off and ends short. A magenta-hot comet head sits at the fork with
    three lavender tail streaks, over a violet bar with lavender wishbone knob ends, a violet grip
    with lavender bands and a magenta-hot comet pommel with a lavender cone tail.
    Calm: pale_lilac, lavender. Vivid: magenta_hot, violet."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.03 * smooth((t - 0.3) / 0.5)
        w = lerp(0.056, 0.04, t) if t < 0.86 else lerp(0.04, 0.007, smooth((t - 0.86) / 0.14))
        return c - w, c + w, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "pale_lilac", "magenta_hot", n=26, chamfer=0.024)

    def tine(y):
        u = (y - 0.0) / 0.3
        c = -0.012 - 0.07 * u ** 1.3
        w = lerp(0.032, 0.005, smooth(u))
        return c - w, c + w, lerp(0.024, 0.014, u)
    st2 = stations_from(tine, 16, y0=0.0, y1=0.3)
    rings, roles = blade_rings(st2, 0.02, True)
    f.loft("Tine", rings, ["pale_lilac" if r == "body" else "magenta_hot" for r in roles], "pale_lilac")
    f.sphere("CometHead", (0, 0.02, -0.004), 0.036, "magenta_hot", segs=20, rings=10)
    for k, z in enumerate((-0.03, 0.0, 0.03)):
        plate(f, f"Streak{k}", [(0.0, z - 0.006), (0.0, z + 0.006), (-0.12 + 0.02 * abs(k - 1), z + 0.002), (-0.12 + 0.02 * abs(k - 1), z - 0.002)],
              "lavender", st, lift=0.006)
    end_bar(f, "violet", span=0.11, half_x=0.04)
    for z in (-0.11, 0.11):
        f.sphere(f"Knob{z}", (0, (GUARD_Y0 + GUARD_Y1) / 2, z), 0.02, "lavender", segs=16, rings=8)
    grip_bands(f, "violet", "lavender", bands=2)
    f.sphere("Comet", (0, -0.47, 0), 0.03, "magenta_hot", segs=16, rings=8)
    tail = f.lathe("Tail", [(0.0, 0.0), (0.02, 0.0), (0.0, 0.05)], "lavender", segs=16)
    f.orient(tail, rot=(_m.pi / 2, 0, 0), loc=(0, -0.47, 0.018))
    return {"design": "Wishbone Comet", "concept": "a blade forked like a wishbone with a comet at the fork", "tier": 4,
            "calm": ["pale_lilac", "lavender"], "vivid": ["magenta_hot", "violet"]}


DESIGNS.update({
    "Sword_Riftsliver": ("VoidRift", 1, design_riftsliver),
    "Sword_HushedFalchion": ("VoidRift", 2, design_hushed_falchion),
    "Sword_GloamsteelSabre": ("VoidRift", 2, design_gloamsteel_sabre),
    "Sword_NullbrandLongsword": ("VoidRift", 3, design_nullbrand_longsword),
    "Sword_RiftwalkerBroadsword": ("VoidRift", 3, design_riftwalker_broadsword),
    "Sword_QuietStar": ("VoidRift", 4, design_quiet_star),
    "Sword_HushfangKris": ("VoidRift", 2, design_hushfang_kris),
    "Sword_GloamTanto": ("VoidRift", 1, design_gloam_tanto),
    "Sword_WishboneComet": ("VoidRift", 4, design_wishbone_comet),
})
