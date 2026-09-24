# Stormwatch -- the observatory and the Tempest Warden (brief section 8.11).
# Wires, vanes, rods, insulators, telescopes, barometers, gusts, weathercocks, bells, pinwheels,
# bottled lightning, kites and rainbows. Calm: cloud, kite. Vivid: storm_blue, storm_gold,
# storm_deep, lightning, epee_gold, hot_pink, cyan, rainbow_pink and the rainbow bands.


def crossbar_lathe(f, name, profile, paint, segs=16):
    """A lathe lying across the sword (its axis along Z), centred on the guard: telescopes, canes.
    profile is (r, z) from -0.13 to +0.13 so the flat end caps sit on the guard's width."""
    obj = striped(f, name, profile, paint, segs=segs)
    return f.orient(obj, rot=(_m.pi / 2, 0, 0), loc=(0, (GUARD_Y0 + GUARD_Y1) / 2, 0))


def design_sparkwire_shiv(f):
    """Sparkwire Shiv -- coiled sparkwire with an edge and a bite. A short cloud leaf blade with
    storm-gold edges wound with a thick storm-gold sparkwire coil, a storm-deep bar with a storm-gold
    coil ring on its hub, a storm-deep grip with cloud bands and a lightning four-point spark pommel.
    Calm: cloud. Vivid: storm_gold, storm_deep, lightning."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.036, 0.048, smooth(t / 0.45)) if t < 0.55 else lerp(0.048, 0.006, smooth((t - 0.55) / 0.45))
        return -w, w, lerp(0.026, 0.013, t)
    blade(f, fn, "cloud", "storm_gold", n=14, chamfer=0.014)
    helix(f, "Sparkwire", -0.17, 0.16, 2.0, 0.056, 0.0075, "storm_gold", segs=12, steps=31)
    end_bar(f, "storm_deep", half_x=0.042)
    f.torus_yz("Coil", -0.225, 0.0, 0.032, 0.01, "storm_gold", seg=16, tube=12)
    grip_bands(f, "storm_deep", "cloud", bands=1)
    f.flat(f.prism("Spark", star(-0.455, 0.0, 4, 0.045, 0.014, rot=0.0), 0.02, "lightning"))
    return {"design": "Sparkwire Shiv", "concept": "a leaf blade wound in a coil of sparkwire", "tier": 1,
            "calm": ["cloud"], "vivid": ["storm_gold", "storm_deep", "lightning"]}


def design_coppervane_falchion(f):
    """Coppervane Falchion -- a copper vane off the observatory roof, re-edged. A storm-gold falchion
    flaring into a weathervane tail-fin with two notches near the tip and a cloud edge, a storm-deep
    compass bar with four cloud ball finials on its faces, a storm-deep grip with cloud bands and a
    cloud arrowhead pommel pointing down. Calm: cloud. Vivid: storm_gold, storm_deep."""
    fn = table_fn([(0.0, -0.046, 0.046), (0.5, -0.046, 0.07), (0.74, -0.044, 0.104), (0.79, -0.042, 0.082),
                   (0.83, -0.04, 0.104), (0.88, -0.036, 0.082), (0.92, -0.032, 0.1), (1.0, -0.004, 0.02)], 0.03, 0.016)
    blade(f, fn, "storm_gold", "cloud", n=51, chamfer=0.024, double=False)
    end_bar(f, "storm_deep", half_x=0.044)
    for side in (1, -1):
        for z in (-0.085, 0.085):
            f.sphere(f"Finial{side}{z}", (side * 0.044, (GUARD_Y0 + GUARD_Y1) / 2, z), 0.02, "cloud", segs=12, rings=6)
    grip_bands(f, "storm_deep", "cloud", bands=2)
    f.prism("Arrowhead", [(-0.5, 0.0), (-0.462, 0.042), (-0.466, 0.014), (-0.44, 0.014), (-0.44, -0.014), (-0.466, -0.014), (-0.462, -0.042)],
            0.02, "cloud")
    return {"design": "Coppervane Falchion", "concept": "a falchion flaring into a notched weathervane fin", "tier": 2,
            "calm": ["cloud"], "vivid": ["storm_gold", "storm_deep"]}


def design_weathervane_sabre(f):
    """Weathervane Sabre -- turns toward the next storm. A curved storm-blue sabre with a cloud edge
    and an arrow cut through it near the root (cloud walls), a storm-gold vane-arrow guard (an
    arrowhead one end, a fletched tail the other, both flat at the guard's width), a cloud grip with
    storm-blue bands and a storm-gold cup-anemometer pommel. Calm: cloud. Vivid: storm_blue, storm_gold."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.055 * t * t
        w = 0.058 if t < 0.8 else lerp(0.058, 0.008, smooth((t - 0.8) / 0.2))
        return c - w, c + w, lerp(0.029, 0.015, t)
    b, st = blade(f, fn, "storm_blue", "cloud", n=28, chamfer=0.026, double=False)
    arrow = [(-0.15, -0.008), (-0.15, 0.008), (-0.06, 0.008), (-0.06, 0.024), (-0.02, 0.0), (-0.06, -0.024), (-0.06, -0.008)]
    cutter = f.prism("ArrowCut", arrow, 0.1, "cloud")
    f.sync_materials()
    f.cut(b, cutter)
    yc = (GUARD_Y0 + GUARD_Y1) / 2
    f.prism("Shaft", [(yc - 0.011, -0.1), (yc - 0.011, 0.08), (yc + 0.011, 0.08), (yc + 0.011, -0.1)], 0.036, "storm_gold")
    f.prism("Head", [(yc - 0.03, 0.07), (yc + 0.03, 0.07), (yc + 0.009, 0.13), (yc - 0.009, 0.13)], 0.04, "storm_gold")
    f.prism("Fletch", [(yc - 0.03, -0.13), (yc + 0.03, -0.13), (yc + 0.014, -0.086), (yc - 0.014, -0.086)], 0.03, "storm_gold")
    grip_bands(f, "cloud", "storm_blue", bands=2)
    f.lathe("Post", [(0.0, -0.5), (0.011, -0.5), (0.011, -0.462), (0.0, -0.462)], "storm_gold", segs=12)
    f.sphere("Hub", (0, -0.476, 0), 0.012, "storm_gold", segs=12, rings=6)
    for k in range(3):
        a = _m.pi / 2 + 2 * _m.pi * k / 3
        x, z = 0.034 * _m.cos(a), 0.034 * _m.sin(a)
        rod(f, f"Arm{k}", (0, -0.476, 0), (x, -0.476, z), 0.004, "storm_gold")
        f.sphere(f"Cup{k}", (x, -0.476, z), 0.011, "storm_gold", segs=12, rings=6)
    return {"design": "Weathervane Sabre", "concept": "a sabre with an arrow cutout over a vane-arrow guard", "tier": 2,
            "calm": ["cloud"], "vivid": ["storm_blue", "storm_gold"]}


def design_rodsteel_longsword(f):
    """Rodsteel Longsword -- drawn from a lightning rod that has been hit twice. A narrow straight
    cloud longsword with storm-gold edges and two raised lightning-yellow zigzag scorch marks, a
    stack of three storm-blue glass insulator discs on a storm-deep bar, a storm-deep grip with cloud
    bands and a ribbed cloud insulator-bell pommel. Calm: cloud. Vivid: storm_gold, lightning, storm_blue, storm_deep."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = 0.04 if t < 0.84 else lerp(0.04, 0.007, smooth((t - 0.84) / 0.16))
        return -w, w, lerp(0.027, 0.014, t)
    b, st = blade(f, fn, "cloud", "storm_gold", n=24, chamfer=0.018)
    plate(f, "ScorchA", zigzag(-0.04, 0.14, -0.006, 0.014, 5, 0.005), "lightning", st, lift=0.006, flat=True)
    plate(f, "ScorchB", zigzag(0.18, 0.34, 0.006, 0.012, 4, 0.005), "lightning", st, lift=0.006, flat=True)
    end_bar(f, "storm_deep", y1=GUARD_Y1 - 0.008, half_x=0.044)
    for k in range(3):
        y0 = GUARD_Y1 - 0.01 + 0.026 * k
        R = 0.074 - 0.01 * k
        f.lathe(f"Insulator{k}", [(0.0, y0), (R * 0.5, y0), (R, y0 + 0.006), (R, y0 + 0.012), (R * 0.45, y0 + 0.022), (0.0, y0 + 0.022)], "storm_blue", segs=24)
    grip_bands(f, "storm_deep", "cloud", bands=2)
    f.lathe("Bell", [(0.0, -0.5), (0.036, -0.5), (0.04, -0.492), (0.03, -0.486), (0.036, -0.478), (0.026, -0.472), (0.03, -0.464),
                     (0.02, -0.456), (0.0, -0.456)], "cloud", segs=20)
    return {"design": "Rodsteel Longsword", "concept": "a lightning-rod longsword with scorch marks and insulator discs", "tier": 3,
            "calm": ["cloud"], "vivid": ["storm_gold", "lightning", "storm_blue", "storm_deep"]}


def design_observatory_broadsword(f):
    """Observatory Broadsword -- the Observatory's own standard. A storm-deep broadsword with
    lightning edges and a raised cloud constellation on each face (five star dots joined by thin
    lines), a storm-gold telescope-tube crossbar with lens rings, a cloud grip with storm-deep bands
    and a stepped storm-gold eyepiece pommel. Calm: cloud. Vivid: storm_deep, lightning, storm_gold."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.088, 0.07, t / 0.8) if t < 0.8 else lerp(0.07, 0.01, (t - 0.8) / 0.2)
        return -w, w, lerp(0.032, 0.016, t)
    b, st = blade(f, fn, "storm_deep", "lightning", n=20, chamfer=0.028)
    stars = [(-0.12, -0.03), (-0.03, 0.028), (0.07, -0.02), (0.17, 0.03), (0.28, -0.006)]
    for k, ((y0, z0), (y1, z1)) in enumerate(zip(stars, stars[1:])):
        dy, dz = y1 - y0, z1 - z0
        ll = _m.hypot(dy, dz)
        ny, nz = -dz / ll * 0.0035, dy / ll * 0.0035
        plate(f, f"Line{k}", [(y0 + ny, z0 + nz), (y1 + ny, z1 + nz), (y1 - ny, z1 - nz), (y0 - ny, z0 - nz)], "cloud", st, lift=0.005)
    for k, (y, z) in enumerate(stars):
        disc_plate(f, f"Star{k}", y, z, 0.015 if k % 2 else 0.019, "cloud", st, lift=0.009, segs=16)
    prof = [(0.022, -0.13), (0.03, -0.13), (0.03, -0.112), (0.024, -0.106), (0.024, -0.05), (0.03, -0.046), (0.03, -0.034),
            (0.026, -0.03), (0.026, 0.03), (0.03, 0.034), (0.03, 0.046), (0.024, 0.05), (0.024, 0.106), (0.03, 0.112), (0.03, 0.13), (0.022, 0.13)]
    crossbar_lathe(f, "Telescope", prof, lambda i: "storm_gold", segs=20)
    grip_bands(f, "cloud", "storm_deep", bands=2)
    f.lathe("Eyepiece", [(0.0, -0.5), (0.02, -0.5), (0.02, -0.486), (0.03, -0.482), (0.03, -0.47), (0.038, -0.466), (0.038, -0.456), (0.0, -0.456)],
            "storm_gold", segs=20)
    return {"design": "Observatory Broadsword", "concept": "a broadsword with a raised constellation over a telescope crossbar", "tier": 3,
            "calm": ["cloud"], "vivid": ["storm_deep", "lightning", "storm_gold"]}


def design_barometer_rapier(f):
    """Barometer Rapier -- a brass needle that swings toward low pressure. A thin storm-blue needle
    blade with cloud edges, a round barometer dial facing the side (a cloud face, a storm-gold rim, a
    storm-deep needle and tick marks) on a flat-ended storm-gold bar, a storm-gold grip with
    storm-blue bands and a storm-gold knob. Calm: cloud. Vivid: storm_blue, storm_gold, storm_deep."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.026, 0.005, t)
        return -w, w, lerp(0.019, 0.01, t)
    blade(f, fn, "storm_blue", "cloud", n=20, chamfer=0.02)
    dy = -0.13
    rim_disc(f, "Dial", dy, 0.088, 0.018, "cloud", segs=32)
    f.torus_yz("Rim", dy, 0.0, 0.088, 0.012, "storm_gold", seg=32, tube=12)
    f.prism("Needle", [(dy - 0.01, -0.004), (dy - 0.01, 0.004), (dy + 0.034, 0.052), (dy + 0.04, 0.046)], 0.024, "storm_deep")
    for k in range(5):
        a = _m.pi * (0.15 + 0.175 * k)
        cy, cz = dy + 0.06 * _m.sin(a), 0.06 * _m.cos(a)
        f.prism(f"Tick{k}", [(cy - 0.004, cz - 0.004), (cy - 0.004, cz + 0.004), (cy + 0.004, cz + 0.004), (cy + 0.004, cz - 0.004)], 0.022, "storm_deep")
    end_bar(f, "storm_gold", half_x=0.04)
    grip_bands(f, "storm_gold", "storm_blue", bands=2)
    ball_pommel(f, "storm_gold", r=0.034)
    return {"design": "Barometer Rapier", "concept": "a needle rapier over a round barometer dial", "tier": 3,
            "calm": ["cloud"], "vivid": ["storm_blue", "storm_gold", "storm_deep"]}


def swoosh(cy, cz, r, width, a0, a1, n=12):
    """A curved strip (an arc of a circle) as one outline: a gust line."""
    out = [(cy + r * _m.sin(a), cz + r * _m.cos(a)) for a in [a0 + (a1 - a0) * k / n for k in range(n + 1)]]
    inn = [(cy + (r - width) * _m.sin(a), cz + (r - width) * _m.cos(a)) for a in [a1 - (a1 - a0) * k / n for k in range(n + 1)]]
    return out + inn


def design_gustcutter_gladius(f):
    """Gustcutter Gladius -- short, wide and quick. A leaf-shaped cloud gladius with storm-blue
    edges and three curved raised storm-blue gust swooshes on each face, a squat storm-deep oval
    bar trimmed flat at the guard's width, a ribbed storm-blue grip and a big round cloud gladius
    ball pommel with a storm-gold band. Calm: cloud. Vivid: storm_blue, storm_deep, storm_gold."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = 0.04 + 0.042 * _m.sin(_m.pi * min(t / 0.86, 1.0)) ** 1.5 if t < 0.86 else lerp(0.04, 0.008, smooth((t - 0.86) / 0.14))
        return -w, w, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "cloud", "storm_blue", n=24, chamfer=0.024)
    for k, (y, z) in enumerate(((-0.12, -0.03), (0.0, 0.0), (0.12, -0.03))):
        plate(f, f"Gust{k}", swoosh(y, z, 0.05, 0.01, 0.2, 1.9), "storm_blue", st, lift=0.006)
    oval = [((GUARD_Y0 + GUARD_Y1) / 2 + 0.036 * _m.sin(a), max(-0.13, min(0.13, 0.16 * _m.cos(a)))) for a in [2 * _m.pi * k / 32 for k in range(32)]]
    f.prism("Oval", oval, 0.048, "storm_deep")
    rib = [(GRIP_R - 0.002 + (0.005 if k % 2 else 0.0), GRIP_Y0 - 0.002 + (GRIP_Y1 - GRIP_Y0 + 0.004) * k / 12) for k in range(13)]
    striped(f, "Grip", [(0.0, GRIP_Y0 - 0.002)] + rib + [(0.0, GRIP_Y1 + 0.002)], lambda i: "storm_blue", segs=20)
    ball_pommel(f, "cloud", r=0.044)
    f.lathe("PommelBand", [(0.04, -0.47), (0.047, -0.47), (0.047, -0.46), (0.04, -0.46)], "storm_gold", segs=20)
    return {"design": "Gustcutter Gladius", "concept": "a leaf gladius swept with gust swooshes", "tier": 2,
            "calm": ["cloud"], "vivid": ["storm_blue", "storm_deep", "storm_gold"]}


def design_weathercock_epee(f):
    """Weathercock Epee -- still points into the wind. A thin gold epee, a flat cloud rooster
    weathervane standing on the axis (body, fanned tail, beak, a lightning-yellow comb) on a
    flat-ended storm-deep bar, a storm-deep grip with cloud bands and a cloud compass-ball pommel
    with four short lightning arms. Calm: cloud. Vivid: epee_gold, lightning, storm_deep."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.032, 0.005, t ** 0.7)
        return -w, w, lerp(0.02, 0.011, t)
    blade(f, fn, "epee_gold", "epee_gold", n=16, chamfer=0.018)
    rooster = chaikin([(-0.196, -0.02), (-0.196, 0.02), (-0.172, 0.018), (-0.166, 0.05), (-0.142, 0.07), (-0.118, 0.068),
                       (-0.108, 0.094), (-0.098, 0.074), (-0.09, 0.062), (-0.096, 0.042), (-0.122, 0.028), (-0.116, -0.012),
                       (-0.082, -0.058), (-0.098, -0.078), (-0.14, -0.072), (-0.166, -0.046), (-0.172, -0.016)], 1)
    big = lambda pts: [(-0.196 + (y + 0.196) * 1.5, z * 1.3) for y, z in pts]  # stands tall over the bar
    rooster = big(rooster)
    f.prism("Rooster", rooster, 0.016, "cloud")
    f.prism("Comb", big([(-0.094, 0.05), (-0.084, 0.046), (-0.078, 0.056), (-0.074, 0.066), (-0.084, 0.07), (-0.09, 0.064)]), 0.02, "lightning")
    f.prism("Wattle", big([(-0.112, 0.07), (-0.104, 0.07), (-0.108, 0.082)]), 0.02, "lightning")
    end_bar(f, "storm_deep", half_x=0.044)
    grip_bands(f, "storm_deep", "cloud", bands=2)
    f.sphere("Compass", (0, -0.474, 0), 0.026, "cloud", segs=16, rings=8)
    for a in (0, _m.pi / 2, _m.pi, 3 * _m.pi / 2):
        rod(f, f"Arm{a:.1f}", (0.02 * _m.cos(a), -0.474, 0.02 * _m.sin(a)), (0.042 * _m.cos(a), -0.474, 0.042 * _m.sin(a)), 0.006, "lightning")
    return {"design": "Weathercock Epee", "concept": "a thin gold epee under a rooster weathervane", "tier": 3,
            "calm": ["cloud"], "vivid": ["epee_gold", "lightning", "storm_deep"]}


def design_stormbell_tulwar(f):
    """Stormbell Tulwar -- a little storm bell on the pommel. A curved storm-blue tulwar with a
    cloud edge and a raised cloud emblem (three merged puffs) dropping a lightning-yellow zigzag bolt, a storm-gold tulwar
    crossguard with short langets up the blade and cloud ball finials on its faces, a cloud grip with
    storm-blue bands and a storm-gold disc pommel with a small lightning bell hanging on a link.
    Calm: cloud. Vivid: storm_blue, lightning, storm_gold."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.082 * t * t
        w = lerp(0.044, 0.056, smooth((t - 0.5) / 0.3)) if t < 0.86 else lerp(0.056, 0.008, smooth((t - 0.86) / 0.14))
        return c - w, c + w, lerp(0.029, 0.015, t)
    b, st = blade(f, fn, "storm_blue", "cloud", n=28, chamfer=0.026, double=False)
    for k, (y, z, r) in enumerate(((-0.1, -0.018, 0.02), (-0.088, 0.012, 0.024), (-0.108, 0.034, 0.017))):
        disc_plate(f, f"Puff{k}", y, z, r, "cloud", st, lift=0.006 + 0.001 * k, segs=20)
    plate(f, "Bolt", zigzag(-0.07, 0.04, 0.012, 0.012, 3, 0.006), "lightning", st, lift=0.006, flat=True)
    end_bar(f, "storm_gold", half_x=0.046)
    f.prism("Langet", [(GUARD_Y1 - 0.004, -0.02), (GUARD_Y1 - 0.004, 0.02), (GUARD_Y1 + 0.036, 0.012), (GUARD_Y1 + 0.036, -0.012)],
            th_at(st, GUARD_Y1 + 0.02) + 0.008, "storm_gold")
    for side in (1, -1):
        for z in (-0.09, 0.09):
            f.sphere(f"Finial{side}{z}", (side * 0.046, (GUARD_Y0 + GUARD_Y1) / 2, z), 0.019, "cloud", segs=12, rings=6)
    grip_bands(f, "cloud", "storm_blue", bands=2)
    rim_disc(f, "Disc", -0.44, 0.022, 0.02, "storm_gold", segs=24)
    f.torus_yz("Link", -0.466, 0.0, 0.006, 0.003, "storm_gold", seg=12, tube=8)
    f.lathe("Bell", [(0.0, -0.47), (0.012, -0.472), (0.02, -0.48), (0.026, -0.492), (0.03, -0.5), (0.0, -0.5)], "lightning", segs=20)
    return {"design": "Stormbell Tulwar", "concept": "a tulwar with a cloud emblem and a storm bell on its pommel", "tier": 3,
            "calm": ["cloud"], "vivid": ["storm_blue", "lightning", "storm_gold"]}


def design_pinwheel_claymore(f):
    """Pinwheel Claymore (warden epic) -- the Tempest Warden's pinwheel, spun up into a blade. A
    hot-pink claymore with cyan edges and a big four-vane pinwheel at its root (vanes hot-pink,
    cyan, lightning and cloud) pinned with a storm-gold ball, a flat-ended cloud bar, a cloud
    grip with hot-pink bands and a storm-gold pin-sphere pommel.
    Calm: cloud. Vivid: hot_pink, cyan, lightning, storm_gold."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        # wide under the pinwheel, narrowing steadily to a long point
        w = lerp(0.074, 0.046, t / 0.78) if t < 0.78 else lerp(0.046, 0.008, smooth((t - 0.78) / 0.22))
        return -w, w, lerp(0.031, 0.016, t)
    b, st = blade(f, fn, "hot_pink", "cyan", n=34, chamfer=0.026)
    cy, R = -0.1, 0.108
    for k, colour in enumerate(("hot_pink", "cyan", "lightning", "cloud")):
        a = _m.pi / 4 + _m.pi / 2 * k
        tip = (cy + R * _m.sin(a), R * _m.cos(a))
        mid = (cy + 0.55 * R * _m.sin(a + _m.pi / 2), 0.55 * R * _m.cos(a + _m.pi / 2))
        f.prism(f"Vane{k}", [(cy, 0.0), tip, mid], 0.036 + 0.002 * k, colour)
    f.sphere("Pin", (0, cy, 0), 0.022, "storm_gold", segs=16, rings=8)
    f.torus_yz("PinRing", cy, 0.0, 0.03, 0.008, "storm_gold", seg=24, tube=12)
    end_bar(f, "cloud", half_x=0.044)
    grip_bands(f, "cloud", "hot_pink", bands=2)
    ball_pommel(f, "storm_gold", r=0.036)
    return {"design": "Pinwheel Claymore", "concept": "a claymore with a four-vane pinwheel spinning at its root", "tier": 4,
            "calm": ["cloud"], "vivid": ["hot_pink", "cyan", "lightning", "storm_gold"]}


BOLT = [(-0.07, -0.052), (-0.07, 0.032), (0.13, 0.102), (0.17, 0.062), (0.31, 0.102), (0.35, 0.029), (0.5, 0.0),
        (0.28, -0.042), (0.24, -0.003), (0.1, -0.042), (0.06, -0.006)]


def design_bottled_lightning(f):
    """Bottled Lightning (spin relic) -- a bolt somebody caught in a lemonade jar. The blade is one fat
    lightning bolt with two zigs, rising out of the storm-gold screw lid of a cloud jar painted with
    two storm-blue shine stripes and a storm-blue label band, the jar on a flat-ended storm-deep bar, a storm-deep grip with cloud
    bands and a lemon-slice pommel (lightning segments, cloud rind and spokes).
    Calm: cloud. Vivid: lightning, storm_blue, storm_gold, storm_deep."""
    f.flat(f.prism("Bolt", BOLT, 0.03, "lightning"))
    segs = 36
    prof = [(0.064, GUARD_Y1 - 0.004), (0.074, GUARD_Y1 + 0.006), (0.078, -0.17), (0.078, -0.11), (0.066, -0.094), (0.052, -0.088)]
    rings = [[(r * _m.cos(2 * _m.pi * j / segs), y, r * _m.sin(2 * _m.pi * j / segs)) for j in range(segs)] for r, y in prof]
    shine = {1, 2, 3, 19, 20, 21}
    f.loft("Jar", rings, lambda i, k: "storm_blue" if (k in shine and 1 <= i <= 3) else "cloud", "cloud")
    f.lathe("Label", [(0.074, -0.152), (0.081, -0.152), (0.081, -0.126), (0.074, -0.126)], "storm_blue", segs=36)
    f.lathe("Lid", [(0.0, -0.092), (0.058, -0.092), (0.062, -0.086), (0.062, -0.076), (0.058, -0.07), (0.0, -0.07)], "storm_gold", segs=20)
    end_bar(f, "storm_deep", half_x=0.046)
    grip_bands(f, "storm_deep", "cloud", bands=2)
    rim_disc(f, "Rind", -0.46, 0.04, 0.016, "cloud", segs=36)
    rim_disc(f, "Flesh", -0.46, 0.033, 0.02, "lightning", segs=36)
    for k in range(3):
        a = _m.pi * k / 3
        f.prism(f"Spoke{k}", [(-0.46 + 0.032 * _m.sin(a) - 0.003 * _m.cos(a), 0.032 * _m.cos(a) + 0.003 * _m.sin(a)),
                              (-0.46 + 0.032 * _m.sin(a) + 0.003 * _m.cos(a), 0.032 * _m.cos(a) - 0.003 * _m.sin(a)),
                              (-0.46 - 0.032 * _m.sin(a) + 0.003 * _m.cos(a), -0.032 * _m.cos(a) - 0.003 * _m.sin(a)),
                              (-0.46 - 0.032 * _m.sin(a) - 0.003 * _m.cos(a), -0.032 * _m.cos(a) + 0.003 * _m.sin(a))], 0.022, "cloud")
    return {"design": "Bottled Lightning", "concept": "a fat lightning bolt escaping a lemonade jar", "tier": 4,
            "calm": ["cloud"], "vivid": ["lightning", "storm_blue", "storm_gold", "storm_deep"]}


def bow_tie(cy, cz, w, h):
    """A bow-tie outline centred at (cy, cz): wings along z, `h` tall, pinched at the knot."""
    return [(cy + 0.2 * h, cz - 0.2 * w), (cy + 0.5 * h, cz - w), (cy - 0.5 * h, cz - w), (cy - 0.2 * h, cz - 0.2 * w),
            (cy - 0.2 * h, cz + 0.2 * w), (cy - 0.5 * h, cz + w), (cy + 0.5 * h, cz + w), (cy + 0.2 * h, cz + 0.2 * w)]


def design_kitestring_rapier(f):
    """Kitestring Rapier (spin relic) -- flew on a kite through the big storm. A pale kite-white rapier
    with storm-blue edges, a diamond kite fixed near the tip (quarters storm-blue, lightning, hot-pink
    and kite white), a storm-gold string spiralling down the blade to the guard with three hot-pink
    bow-ties along it, a storm-gold string spool on a storm-blue bar, a kite-white grip with
    storm-blue bands and a hot-pink bow-tie knot pommel.
    Calm: kite. Vivid: storm_blue, storm_gold, lightning, hot_pink."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.03, 0.006, t)
        return -w, w, lerp(0.021, 0.011, t)
    b, st = blade(f, fn, "kite", "storm_blue", n=20, chamfer=0.02)
    c, top, bot, half = (0.31, 0.0), (0.37, 0.0), (0.2, 0.0), 0.048
    right, left = (0.31, half), (0.31, -half)
    for k, (p, q, colour) in enumerate(((top, right, "storm_blue"), (right, bot, "lightning"), (bot, left, "hot_pink"), (left, top, "kite"))):
        f.prism(f"Kite{k}", [c, p, q], th_at(st, 0.3) + 0.008, colour)
    ellipse_helix(f, "String", -0.17, 0.2, 2.0, 0.04, 0.0075, "storm_gold", sx=0.6, steps=33)
    for k, u in enumerate((0.2, 0.5, 0.8)):
        a = 2 * _m.pi * 2.0 * u
        y = -0.17 + 0.37 * u
        tie = f.prism(f"Bow{k}", bow_tie(y, 0.0, 0.02, 0.024), 0.008, "hot_pink")
        f.orient(tie, rot=(0, -a, 0), loc=(0.6 * 0.04 * _m.cos(a), 0, 0.04 * _m.sin(a)))
    end_bar(f, "storm_blue", half_x=0.042)
    f.lathe("Spool", [(0.0, GUARD_Y1 - 0.004), (0.058, GUARD_Y1 - 0.004), (0.058, GUARD_Y1 + 0.006), (0.036, GUARD_Y1 + 0.008),
                      (0.036, GUARD_Y1 + 0.034), (0.058, GUARD_Y1 + 0.036), (0.058, GUARD_Y1 + 0.046), (0.0, GUARD_Y1 + 0.046)], "storm_gold", segs=24)
    grip_bands(f, "kite", "storm_blue", bands=1)
    f.prism("PommelBow", bow_tie(-0.475, 0.0, 0.042, 0.05), 0.018, "hot_pink")
    f.prism("PommelKnot", [(-0.486, -0.01), (-0.486, 0.01), (-0.464, 0.01), (-0.464, -0.01)], 0.022, "lightning")
    return {"design": "Kitestring Rapier", "concept": "a rapier with a diamond kite near the tip and its string wound down the blade", "tier": 4,
            "calm": ["kite"], "vivid": ["storm_blue", "storm_gold", "lightning", "hot_pink"]}


RAINBOW = ["coral", "orange", "lightning", "lime", "cyan", "violet"]


def design_double_rainbow(f):
    """Double Rainbow (spin relic) -- two rainbows after the storm; one came down as a sword. The blade
    is a rainbow: each face carries five strips running the length (violet, cyan, lime, lightning,
    orange) with a coral edge and a cloud spine. The guard is the second rainbow, six banded
    half-rings arching over the grip top with a cloud puff at each foot over a hidden flat-ended
    cloud bar. A cloud grip with rainbow-pink bands and a cloud-puff pommel.
    Calm: cloud. Vivid: the six rainbow bands, rainbow_pink."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.03 * _m.sin(_m.pi * t)
        w = 0.07 if t < 0.84 else lerp(0.07, 0.01, smooth((t - 0.84) / 0.16))
        return c - w, c + w, lerp(0.03, 0.016, t)
    st = stations_from(fn, 24)
    rings = []
    for y, zb, ze, th in st:
        front = [(th, y, lerp(zb, ze, j / 5)) for j in range(6)]
        back = [(-th, y, lerp(zb, ze, j / 5)) for j in range(5, -1, -1)]
        rings.append(front + back)
    face = ["violet", "cyan", "lime", "lightning", "orange"]
    strips = face + ["coral"] + face[::-1] + ["cloud"]
    f.loft("Blade", rings, strips, "cloud")
    for k, colour in enumerate(RAINBOW):
        R = 0.104 - 0.012 * k
        tube(f, f"Arch{k}", [(GUARD_Y0 + R * _m.sin(a), R * _m.cos(a)) for a in [_m.pi * j / 12 for j in range(13)]], 0.0062, colour)
    end_bar(f, "cloud", y1=GUARD_Y0 + 0.02, half_x=0.02)
    for sign in (1, -1):
        for dy, dz, r in ((0.0, 0.0, 0.026), (0.018, -0.016, 0.019), (0.012, 0.018, 0.017)):
            f.sphere(f"Puff{sign}{dy}", (0, GUARD_Y0 + 0.006 + dy, sign * (0.094 + dz)), r, "cloud", segs=16, rings=8)
    grip_bands(f, "cloud", "rainbow_pink", bands=3)
    f.sphere("Cloud", (0, -0.474, 0), 0.026, "cloud", segs=16, rings=8)
    for z in (-0.024, 0.024):
        f.sphere(f"Cloud{z}", (0, -0.466, z), 0.02, "cloud", segs=16, rings=8)
    return {"design": "Double Rainbow", "concept": "a rainbow blade under a second rainbow arch", "tier": 4,
            "calm": ["cloud"], "vivid": RAINBOW + ["rainbow_pink"]}


DESIGNS.update({
    "Sword_SparkwireShiv": ("Stormwatch", 1, design_sparkwire_shiv),
    "Sword_CoppervaneFalchion": ("Stormwatch", 2, design_coppervane_falchion),
    "Sword_WeathervaneSabre": ("Stormwatch", 2, design_weathervane_sabre),
    "Sword_RodsteelLongsword": ("Stormwatch", 3, design_rodsteel_longsword),
    "Sword_ObservatoryBroadsword": ("Stormwatch", 3, design_observatory_broadsword),
    "Sword_BarometerRapier": ("Stormwatch", 3, design_barometer_rapier),
    "Sword_GustcutterGladius": ("Stormwatch", 2, design_gustcutter_gladius),
    "Sword_WeathercockEpee": ("Stormwatch", 3, design_weathercock_epee),
    "Sword_StormbellTulwar": ("Stormwatch", 3, design_stormbell_tulwar),
    "Sword_PinwheelClaymore": ("Stormwatch", 4, design_pinwheel_claymore),
    "Sword_BottledLightning": ("Stormwatch", 4, design_bottled_lightning),
    "Sword_KitestringRapier": ("Stormwatch", 4, design_kitestring_rapier),
    "Sword_DoubleRainbow": ("Stormwatch", 4, design_double_rainbow),
})
