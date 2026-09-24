# FrostboundGlacier -- the glacier's everyday blades (brief section 8.8).
# Icicles, snowpack, window panes, meltwater, rime ferns, the blue hour and a snowglobe.
# Calm: pale_sky, snowpack, ice_white, white, estoc_ice, globe. Vivid: cyan, deep_blue, blue_hour.


def ribbon(f, name, st, centre, half_w, colour, lift=0.006, i0=1, i1=None):
    """A raised strip on both faces following the blade: centre(y, zb, ze) -> z. One loft through
    the blade (half_x = local thickness + lift), so it reads the same from either side."""
    rings = []
    for y, zb, ze, th in st[i0:i1]:
        c = centre(y, zb, ze)
        rings.append([(th + lift, y, c - half_w), (th + lift, y, c + half_w), (-th - lift, y, c + half_w), (-th - lift, y, c - half_w)])
    return f.loft(name, rings, [colour] * 4, colour)


def design_icicle_shiv(f):
    """Icicle Shiv -- an icicle with a wrapped grip; it does not melt. A round pale-sky icicle blade
    swelling in three soft bulges to a cyan tip, a deep-blue bar tied with a knot, a deep-blue
    cloth grip wound with a cyan spiral and a faceted ice-white lump pommel.
    Calm: pale_sky, ice_white. Vivid: cyan, deep_blue."""
    prof = []
    for i in range(22):
        t = i / 21
        r = (0.046 * (1 - t) + 0.004) * (1 + 0.16 * _m.sin(3 * _m.pi * t) ** 2)
        prof.append((r, lerp(BLADE_ROOT_Y, TIP_Y, t)))
    striped(f, "Icicle", prof, lambda i: "cyan" if i >= 16 else "pale_sky", segs=14)
    end_bar(f, "deep_blue", half_x=0.04)
    f.sphere("Knot", (0, (GUARD_Y0 + GUARD_Y1) / 2, 0), 0.046, "deep_blue", segs=14, rings=8)
    f.lathe("Grip", [(0.0, GRIP_Y0 - 0.002), (GRIP_R, GRIP_Y0 - 0.002), (GRIP_R, GRIP_Y1 + 0.002), (0.0, GRIP_Y1 + 0.002)], "deep_blue", segs=20)
    helix(f, "Wrap", GRIP_Y0 + 0.012, GRIP_Y1 - 0.012, 2.5, GRIP_R, 0.007, "cyan", segs=12, steps=31)
    gem_pommel(f, "ice_white", r=0.044, segs=7)
    return {"design": "Icicle Shiv", "concept": "a round bulging icicle on a wrapped cloth grip", "tier": 1,
            "calm": ["pale_sky", "ice_white"], "vivid": ["cyan", "deep_blue"]}


def design_snowpack_falchion(f):
    """Snowpack Falchion -- pressed snowpack. A snowpack-white falchion whose spine steps down in
    three soft snow-layer ledges, a cyan edge and a white snowball stuck near the tip, a deep-blue
    bar with snowballs on its faces, a deep-blue grip with white bands and a cyan mitten pommel on a
    white cuff. Calm: snowpack, white. Vivid: cyan, deep_blue."""
    def spine(t):
        return -0.052 + 0.013 * (smooth((t - 0.26) / 0.05) + smooth((t - 0.5) / 0.05) + smooth((t - 0.72) / 0.05))

    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        ze = lerp(0.05, 0.088, smooth(t / 0.72))
        if t > 0.84:
            ze = lerp(0.088, spine(1.0) + 0.012, smooth((t - 0.84) / 0.16))
        return spine(t), ze, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "snowpack", "cyan", n=40, chamfer=0.028, double=False)
    f.sphere("Snowball", (0, 0.3, zc_at(st, 0.3)), 0.03, "white", segs=16, rings=8)
    end_bar(f, "deep_blue", half_x=0.044)
    for side in (1, -1):
        for z in (-0.075, 0.075):
            f.sphere(f"Ball{side}{z}", (side * 0.044, (GUARD_Y0 + GUARD_Y1) / 2, z), 0.02, "white", segs=12, rings=6)
    grip_bands(f, "deep_blue", "white", bands=2)
    f.prism("Cuff", [(-0.5, -0.04), (-0.5, 0.04), (-0.482, 0.04), (-0.482, -0.04)], 0.034, "white")
    mitt = chaikin([(-0.484, -0.036), (-0.484, 0.036), (-0.468, 0.054), (-0.448, 0.062), (-0.44, 0.05), (-0.45, 0.04),
                    (-0.43, 0.034), (-0.418, 0.0), (-0.43, -0.036)], 2)
    f.prism("Mitten", mitt, 0.03, "cyan")
    return {"design": "Snowpack Falchion", "concept": "a falchion of pressed snow layers with a mitten pommel", "tier": 2,
            "calm": ["snowpack", "white"], "vivid": ["cyan", "deep_blue"]}


def design_frostpane_sabre(f):
    """Frostpane Sabre -- window-clear glacier pane. A straight cyan pane of a sabre flaring toward the top, its tip clipped like a window corner, framed like a window: a
    raised ice-white border down both long sides, a centre mullion and three cross bars dividing the
    flat into panes, a deep-blue window-sill guard with a white sill lip, an ice-white grip with
    deep-blue bands and a white frosted knob. Calm: ice_white, white. Vivid: cyan, deep_blue."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        # a straight pane with a gently hollowed back and a clipped, window-corner tip
        # the pane flares from a narrow root to a wide square top
        w = lerp(0.05, 0.086, smooth(t / 0.84))
        zb = -w + 0.01 * _m.sin(_m.pi * min(t / 0.84, 1.0))
        ze = w if t < 0.84 else lerp(0.086, zb + 0.014, (t - 0.84) / 0.16)
        return zb, ze, lerp(0.028, 0.015, t)
    b, st = blade(f, fn, "cyan", "ice_white", n=28, chamfer=0.024, double=False,
                  paint=lambda i, k, r: "ice_white" if (r == "edge" or k == 5) else "cyan")
    last = -5
    ribbon(f, "Mullion", st, lambda y, zb, ze: (zb + ze) / 2, 0.007, "ice_white", i1=last)
    ribbon(f, "RailBack", st, lambda y, zb, ze: zb + 0.012, 0.006, "ice_white", i1=last)
    ribbon(f, "RailEdge", st, lambda y, zb, ze: ze - 0.032, 0.006, "ice_white", i1=last)
    for k, i in enumerate((1, 11, last - 1 + len(st))):
        y, zb, ze, th = st[i]
        plate(f, f"Bar{k}", [(y - 0.008, zb + 0.008), (y - 0.008, ze - 0.028), (y + 0.008, ze - 0.028), (y + 0.008, zb + 0.008)], "ice_white", st)
    end_bar(f, "deep_blue", y1=GUARD_Y1 - 0.018, half_x=0.046)
    f.prism("Sill", [(GUARD_Y1 - 0.02, -0.112), (GUARD_Y1 - 0.02, 0.112), (GUARD_Y1, 0.104), (GUARD_Y1, -0.104)], 0.036, "white")
    grip_bands(f, "ice_white", "deep_blue", bands=2)
    ball_pommel(f, "white", r=0.038)
    return {"design": "Frostpane Sabre", "concept": "a cyan sabre framed and barred like a window pane", "tier": 2,
            "calm": ["ice_white", "white"], "vivid": ["cyan", "deep_blue"]}


def design_glacierrun_longsword(f):
    """Glacierrun Longsword -- shaped by meltwater over a winter. A straight deep-blue longsword
    with ice-white edges and two long wavy raised cyan meltwater ribs braiding up each face, an
    ice-white bar under a cyan wave that curls over at both ends, an ice-white grip with deep-blue
    bands and a cyan droplet pommel. Calm: ice_white. Vivid: deep_blue, cyan."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        # slim and tapering into a long meltwater-worn point
        w = lerp(0.064, 0.046, t / 0.66) if t < 0.66 else lerp(0.046, 0.008, smooth((t - 0.66) / 0.34))
        return -w, w, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "deep_blue", "ice_white", n=26, chamfer=0.026)
    for k, sign in enumerate((1, -1)):
        ribbon(f, f"Melt{k}", st, lambda y, zb, ze, s=sign: s * (0.014 + 0.01 * _m.sin((y + 0.21) * 22)), 0.0075, "cyan", i1=-5)
    end_bar(f, "ice_white", y1=GUARD_Y0 + 0.028, half_x=0.046)
    wave = [(GUARD_Y0 + 0.042 + 0.01 * _m.sin(z * 60), z) for z in [-0.08 + 0.16 * j / 16 for j in range(17)]]
    tube(f, "Wave", wave, 0.012, "cyan")
    for sign in (1, -1):
        cy, cz = GUARD_Y0 + 0.058, sign * 0.092
        pts = [(cy - (0.024 - 0.008 * a / 5) * _m.cos(a), sign * (cz - 0.012 + (0.024 - 0.008 * a / 5) * _m.sin(a) * 0.9 + 0.012))
               for a in [5.0 * j / 16 for j in range(17)]]
        tube(f, f"Curl{sign}", [(GUARD_Y0 + 0.034, sign * 0.08)] + pts, 0.011, "cyan")
    grip_bands(f, "ice_white", "deep_blue", bands=3)
    f.lathe("Droplet", [(0.012, -0.5), (0.03, -0.493), (0.039, -0.478), (0.035, -0.46), (0.022, -0.446), (0.01, -0.432), (0.0, -0.426)], "cyan", segs=20)
    return {"design": "Glacierrun Longsword", "concept": "a longsword braided with meltwater ribs under a curling wave guard", "tier": 3,
            "calm": ["ice_white"], "vivid": ["deep_blue", "cyan"]}


def design_rimecoat_broadsword(f):
    """Rimecoat Broadsword -- under a permanent coat of rime. A broad deep-blue blade whose edges
    carry a lumpy ice-white rime crust, a raised cyan frost fern (a central rib and four pairs of
    swept ribs) through both faces, a cyan bar dotted with rime bumps, a deep-blue grip with
    ice-white bands and a cyan six-point snowflake pommel. Calm: ice_white. Vivid: deep_blue, cyan."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = 0.084 if t < 0.84 else lerp(0.084, 0.012, smooth((t - 0.84) / 0.16))
        return -w, w, lerp(0.032, 0.016, t)
    b, st = blade(f, fn, "deep_blue", "ice_white", n=24, chamfer=0.03)
    for k, y in enumerate([-0.15 + 0.074 * j for j in range(7)]):
        for sign in (1, -1):
            f.sphere(f"Rime{k}{sign}", (0, y + 0.02 * (sign > 0), sign * fn(y)[1]), 0.02 - 0.004 * (k % 2), "ice_white", segs=12, rings=6)
    plate(f, "FernRib", [(-0.14, -0.006), (-0.14, 0.006), (0.3, 0.004), (0.3, -0.004)], "cyan", st)
    for k, y in enumerate((-0.1, -0.02, 0.06, 0.14)):
        L = 0.05 - 0.007 * k
        for sign in (1, -1):
            plate(f, f"Frond{k}{sign}", [(y, 0.0), (y + 0.012, 0.0), (y + 0.012 + L, sign * 0.046), (y + L, sign * 0.046)], "cyan", st)
    end_bar(f, "cyan", half_x=0.05)
    for side in (1, -1):
        for z in (-0.09, -0.03, 0.03, 0.09):
            f.sphere(f"Bump{side}{z}", (side * 0.05, (GUARD_Y0 + GUARD_Y1) / 2 + 0.008 * (z > 0), z), 0.014, "ice_white", segs=12, rings=6)
    grip_bands(f, "deep_blue", "ice_white", bands=2)
    f.flat(f.prism("Snowflake", star(-0.448, 0.0, 6, 0.052, 0.024, rot=0.0), 0.02, "cyan"))
    return {"design": "Rimecoat Broadsword", "concept": "a broadsword crusted with rime and a frost fern", "tier": 3,
            "calm": ["ice_white"], "vivid": ["deep_blue", "cyan"]}


def design_blue_hour_shard(f):
    """Blue Hour Shard (Relic) -- the one blue hour the glacier lights up. A big faceted crystal
    shard, flat-shaded, banded root to tip in three hard blues (deep_blue, cyan, blue-hour), with
    wide ice-white facet edges, a raised ice-white crescent moon and two white stars through both
    faces, two cyan crystal shards spreading from a deep-blue hub, a deep-blue grip with ice-white
    bands and a faceted cyan gem pommel under a white cap.
    Calm: ice_white, white. Vivid: blue_hour, cyan, deep_blue."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        # lopsided facets: the edge side peaks late and wide, the back side early and narrow
        ze = lerp(0.05, 0.108, t / 0.58) if t < 0.58 else lerp(0.108, -0.02, (t - 0.58) / 0.42)
        zb = lerp(-0.05, -0.084, t / 0.3) if t < 0.3 else lerp(-0.084, -0.03, (t - 0.3) / 0.7)
        return zb, ze, lerp(0.034, 0.016, t)
    band = lambda i: "deep_blue" if i < 8 else ("cyan" if i < 15 else "blue_hour")
    b, st = blade(f, fn, "cyan", "ice_white", n=31, chamfer=0.036, flat=True,
                  paint=lambda i, k, r: "ice_white" if r == "edge" else band(i))
    plate(f, "Moon", crescent(0.12, 0.02, 0.05, 0.022, facing=1), "ice_white", st, lift=0.008, flat=True)
    for k, (y, z) in enumerate(((0.0, 0.03), (0.02, -0.04), (0.26, 0.0))):
        plate(f, f"Star{k}", star(y, z, 4, 0.024, 0.009), "white", st, lift=0.008, flat=True)
    f.flat(f.prism("Hub", [(GUARD_Y0, -0.046), (GUARD_Y0, 0.046), (GUARD_Y1 + 0.012, 0.046), (GUARD_Y1 + 0.012, -0.046)], 0.05, "deep_blue"))
    shard = [(GUARD_Y0 + 0.004, 0.03), (GUARD_Y0 + 0.004, 0.13), (GUARD_Y1, 0.13), (-0.168, 0.1), (GUARD_Y1 + 0.006, 0.03)]
    for p in (shard, mirror(shard)):
        f.flat(f.prism(f"Shard{p[0][1]}", p, 0.034, "cyan"))
    grip_bands(f, "deep_blue", "ice_white", bands=2)
    gem_pommel(f, "cyan", r=0.048, segs=8)
    f.lathe("Cap", [(0.02, -0.448), (0.044, -0.448), (0.044, -0.43), (0.02, -0.43)], "white", segs=6)
    return {"design": "Blue Hour Shard", "concept": "a banded crystal shard carrying a crescent moon and stars", "tier": 4,
            "calm": ["ice_white", "white"], "vivid": ["blue_hour", "cyan", "deep_blue"]}


def design_icicle_estoc(f):
    """Icicle Estoc -- a long thin icicle, straight enough to thrust. A slim diamond-section spike
    in estoc ice with cyan edges and three frozen ice-white drips swelling along it, a deep-blue
    shallow cup guard whose lip is the widest point, a cyan grip with ice-white bands and a pommel
    of three hanging ice-white icicles. Calm: estoc_ice, ice_white. Vivid: cyan, deep_blue."""
    drips = (0.0, 0.16, 0.32)
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.034, 0.005, t) + sum(0.012 * _m.exp(-((y - d) / 0.03) ** 2) for d in drips)
        return -w, w, lerp(0.024, 0.012, t) + 0.3 * sum(0.012 * _m.exp(-((y - d) / 0.03) ** 2) for d in drips)
    b, st = blade(f, fn, "estoc_ice", "cyan", n=34, chamfer=0.04)
    for k, d in enumerate(drips):
        f.sphere(f"Drip{k}", (0, d - 0.03, 0), fn(d)[2] + 0.006, "ice_white", segs=14, rings=8)
    cup = f.lathe("Cup", [(0.0, GUARD_Y0), (0.05, GUARD_Y0), (0.118, GUARD_Y1 - 0.016), (0.13, GUARD_Y1), (0.118, GUARD_Y1),
                          (0.046, GUARD_Y0 + 0.014), (0.0, GUARD_Y0 + 0.014)], "deep_blue", segs=32)
    f.orient(cup, scale=(0.42, 1, 1))
    grip_bands(f, "cyan", "ice_white", bands=2)
    icicle(f, "IcicleC", -0.44, 0.0, 0.06, 0.018, "ice_white")
    for z in (-0.024, 0.024):
        icicle(f, f"Icicle{z}", -0.44, z, 0.042, 0.014, "ice_white")
    f.lathe("Knob", [(0.0, -0.446), (0.04, -0.446), (0.04, -0.43), (0.0, -0.43)], "deep_blue", segs=20)
    return {"design": "Icicle Estoc", "concept": "a thin dripping icicle thrust from a shallow cup guard", "tier": 3,
            "calm": ["estoc_ice", "ice_white"], "vivid": ["cyan", "deep_blue"]}


def design_snowglobe_sabre(f):
    """Snowglobe Sabre (spin relic) -- shake it and it snows on whoever you hit. An ice-white sabre
    with a cyan edge and five raised white snowflake dots rising out of a snowglobe at its root: a
    clear-blue globe on a deep-blue base, a round window cut through both sides showing a little
    leaf-bright tree and a white snowman inside, a deep-blue bar, a deep-blue grip with leaf-bright
    bands and a cyan wind-up key ring pommel.
    Calm: globe, ice_white, white. Vivid: cyan, deep_blue, leaf_bright."""
    gy, gr = -0.118, 0.074

    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.04 * t * t
        w = 0.054 if t < 0.82 else lerp(0.054, 0.008, smooth((t - 0.82) / 0.18))
        return c - w, c + w, lerp(0.028, 0.015, t)
    st = stations_from(fn, 26, y0=gy + gr - 0.02)
    rings, roles = blade_rings(st, 0.026, False)
    f.loft("Blade", rings, ["ice_white" if r == "body" else "cyan" for r in roles], "ice_white")
    for k, y in enumerate((0.02, 0.1, 0.18, 0.26, 0.34)):
        stud(f, f"Flake{k}", y, zc_at(st, y), 0.011, "white", st, segs=12, rings=6)
    g = f.sphere("Globe", (0, gy, 0), gr, "globe", segs=28, rings=16)
    hole(f, g, "Window", gy, 0.0, 0.046, "globe", segs=28)
    f.prism("Snowbank", [(gy - 0.047, -0.05), (gy - 0.047, 0.05), (gy - 0.032, 0.05), (gy - 0.032, -0.05)], 0.05, "white")
    f.flat(f.prism("Tree", [(gy - 0.034, -0.036), (gy - 0.034, -0.002), (gy + 0.03, -0.019)], 0.012, "leaf_bright"))
    f.sphere("SnowmanBase", (0, gy - 0.02, 0.02), 0.014, "white", segs=12, rings=6)
    f.sphere("SnowmanHead", (0, gy + 0.001, 0.02), 0.01, "white", segs=12, rings=6)
    f.lathe("Base", [(0.0, GUARD_Y1 - 0.004), (0.062, GUARD_Y1 - 0.004), (0.058, GUARD_Y1 + 0.014), (0.042, gy - gr + 0.012), (0.0, gy - gr + 0.012)], "deep_blue", segs=24)
    end_bar(f, "deep_blue", half_x=0.044)
    grip_bands(f, "deep_blue", "leaf_bright", bands=3)
    ring_pommel(f, "cyan", R=0.03, r=0.011)
    return {"design": "Snowglobe Sabre", "concept": "a sabre rising out of a snowglobe with a tree and snowman inside", "tier": 4,
            "calm": ["globe", "ice_white", "white"], "vivid": ["cyan", "deep_blue", "leaf_bright"]}


DESIGNS.update({
    "Sword_IcicleShiv": ("FrostboundGlacier", 1, design_icicle_shiv),
    "Sword_SnowpackFalchion": ("FrostboundGlacier", 2, design_snowpack_falchion),
    "Sword_FrostpaneSabre": ("FrostboundGlacier", 2, design_frostpane_sabre),
    "Sword_GlacierrunLongsword": ("FrostboundGlacier", 3, design_glacierrun_longsword),
    "Sword_RimecoatBroadsword": ("FrostboundGlacier", 3, design_rimecoat_broadsword),
    "Sword_BlueHourShard": ("FrostboundGlacier", 4, design_blue_hour_shard),
    "Sword_IcicleEstoc": ("FrostboundGlacier", 3, design_icicle_estoc),
    "Sword_SnowglobeSabre": ("FrostboundGlacier", 4, design_snowglobe_sabre),
})
