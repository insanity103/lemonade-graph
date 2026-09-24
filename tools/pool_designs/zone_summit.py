# CelestialSummit -- the Summit's everyday blades (brief section 8.13).
# Sun motes, cloud decks, sundials, daybreak, stairs, a small smiling dawn, a hamon katana, a
# ribboned nodachi, a paper crane and Lemonade's own halved-lemon sword.
# Calm: sunmote, cloud, ivory, summit, paper. Vivid: gold, tangerine, dawn, lemon, lime.


def half_disc(cy, cz, r, n=12, down=False):
    """A half disc with its flat side at cy, rounding up (or down) from it."""
    s = -1 if down else 1
    return [(cy + s * r * _m.sin(a), cz + r * _m.cos(a)) for a in [_m.pi * k / n for k in range(n + 1)]]


def lying_prism(f, name, poly_xz, half_y, colour, y):
    """A prism whose outline lies in the X-Z plane (flat across the sword) at height y."""
    return rotated_cutter(f, name, poly_xz, half_y, colour, y)


def design_sunmote_shiv(f):
    """Sunmote Shiv -- a mote of the Summit's light, small and very hot. A sunmote-cream teardrop blade
    with gold edges and a tangerine hot dot half-sunk through its root, a small gold bar with three
    short rays rising each side, a gold grip with sunmote bands and a tangerine sun-sphere pommel.
    Calm: sunmote. Vivid: gold, tangerine."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        # a teardrop of light: fat round the mote at the root, drawn out to a long point
        w = lerp(0.034, 0.058, smooth(t / 0.16)) if t < 0.16 else lerp(0.058, 0.004, (t - 0.16) / 0.84)
        return -w, w, lerp(0.026, 0.013, t)
    blade(f, fn, "sunmote", "gold", n=16, chamfer=0.018)
    f.sphere("Mote", (0, -0.15, 0), 0.034, "tangerine", segs=16, rings=8)
    end_bar(f, "gold", y1=GUARD_Y1 - 0.01, half_x=0.04)
    for sign in (1, -1):
        for z in (0.05, 0.08, 0.11):
            poly = [(GUARD_Y1 - 0.012, sign * (z - 0.009)), (GUARD_Y1 - 0.012, sign * (z + 0.009)), (GUARD_Y1 + 0.018, sign * z)]
            f.prism(f"Ray{sign}{z}", poly if sign > 0 else poly[::-1], 0.02, "gold")
    grip_bands(f, "gold", "sunmote", bands=2)
    ball_pommel(f, "tangerine", r=0.036)
    return {"design": "Sunmote Shiv", "concept": "a leaf shiv with a hot sun mote at its root", "tier": 1,
            "calm": ["sunmote"], "vivid": ["gold", "tangerine"]}


def design_cloudcut_falchion(f):
    """Cloudcut Falchion -- cut from the cloud deck below the peak. A cloud falchion whose spine is a
    row of five round cloud scallops, a gold edge, a gold bar carrying ivory cloud puffs, a
    tangerine grip with ivory bands and an ivory cloud-puff pommel.
    Calm: cloud, ivory. Vivid: gold, tangerine."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        u = min(t / 0.8, 1.0)
        zb = -0.046 - 0.016 * abs(_m.sin(5 * _m.pi * u)) ** 0.6 if t < 0.8 else lerp(-0.046, 0.008, smooth((t - 0.8) / 0.2))
        ze = lerp(0.05, 0.084, smooth(t / 0.7)) if t < 0.82 else lerp(0.084, 0.018, smooth((t - 0.82) / 0.18))
        return zb, ze, lerp(0.03, 0.015, t)
    blade(f, fn, "cloud", "gold", n=46, chamfer=0.026, double=False)
    end_bar(f, "gold", half_x=0.04)
    for side in (1, -1):
        for dz, dy, r in ((-0.07, 0.0, 0.022), (-0.045, 0.01, 0.018), (0.045, 0.01, 0.018), (0.07, 0.0, 0.022)):
            f.sphere(f"Puff{side}{dz}", (side * 0.04, (GUARD_Y0 + GUARD_Y1) / 2 + dy, dz), r, "ivory", segs=12, rings=6)
    grip_bands(f, "tangerine", "ivory", bands=2)
    f.sphere("Cloud", (0, -0.474, 0), 0.026, "ivory", segs=16, rings=8)
    for z in (-0.024, 0.024):
        f.sphere(f"Cloud{z}", (0, -0.466, z), 0.02, "ivory", segs=16, rings=8)
    return {"design": "Cloudcut Falchion", "concept": "a falchion with a scalloped cloud spine", "tier": 2,
            "calm": ["cloud", "ivory"], "vivid": ["gold", "tangerine"]}


def design_zenith_sabre(f):
    """Zenith Sabre -- aligned to the sun at its highest. A curved gold sabre with an ivory edge and
    a raised ivory sundial-gnomon fin rising off its spine near the root, an ivory bar with a
    tangerine sun disc at its centre, an ivory grip with gold bands and an ivory sundial-disc pommel
    with a small gold gnomon. Calm: ivory. Vivid: gold, tangerine."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.05 * t * t
        w = 0.056 if t < 0.8 else lerp(0.056, 0.008, smooth((t - 0.8) / 0.2))
        return c - w, c + w, lerp(0.029, 0.015, t)
    b, st = blade(f, fn, "gold", "ivory", n=28, chamfer=0.026, double=False)
    zb0, zb1 = fn(-0.17)[0], fn(0.0)[0]
    f.prism("Gnomon", [(-0.17, zb0 + 0.01), (0.0, zb1 + 0.01), (-0.17, zb0 - 0.058)], 0.012, "ivory")
    end_bar(f, "ivory", half_x=0.042)
    rim_disc(f, "SunDisc", (GUARD_Y0 + GUARD_Y1) / 2, 0.042, 0.05, "tangerine", segs=28)
    grip_bands(f, "ivory", "gold", bands=2)
    disc_pommel(f, "ivory", r=0.04, half_x=0.018)
    f.prism("Dial", [(-0.49, -0.004), (-0.49, 0.004), (-0.47, 0.03)], 0.022, "gold")
    return {"design": "Zenith Sabre", "concept": "a gold sabre with a sundial gnomon fin", "tier": 2,
            "calm": ["ivory"], "vivid": ["gold", "tangerine"]}


def design_daybreak_longsword(f):
    """Daybreak Longsword -- the colour of the first minute of light. A tangerine longsword with
    ivory edges and a raised gold half-sun with five rays climbing the blade root, a flat ivory
    horizon bar with gold ends, a gold grip with ivory bands and a gold half-sun pommel.
    Calm: ivory. Vivid: tangerine, gold."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        # slim and straight with a clipped, angular tip like the sun's first edge
        w = 0.054 if t < 0.88 else lerp(0.054, 0.012, (t - 0.88) / 0.12)
        return -w, w, lerp(0.031, 0.015, t)
    b, st = blade(f, fn, "tangerine", "ivory", n=34, chamfer=0.024)
    cy = -0.18
    plate(f, "HalfSun", half_disc(cy, 0.0, 0.034, n=16), "gold", st, lift=0.007)
    for k in range(5):
        a = -_m.pi / 2 + _m.pi * (k + 0.5) / 5
        d = (_m.cos(a), _m.sin(a))
        r0, r1, hw = 0.042, 0.075 if k == 2 else 0.064, 0.008
        tip = (cy + r1 * d[0], r1 * d[1])
        plate(f, f"Ray{k}", [(cy + r0 * d[0] - hw * d[1], r0 * d[1] + hw * d[0]), tip, (cy + r0 * d[0] + hw * d[1], r0 * d[1] - hw * d[0])],
              "gold", st, lift=0.007)
    end_bar(f, "ivory", y1=GUARD_Y1 - 0.014, half_x=0.044, span=0.1)
    for sign in (1, -1):
        f.prism(f"End{sign}", [(GUARD_Y0 - 0.004, sign * 0.1), (GUARD_Y0 - 0.004, sign * 0.13), (GUARD_Y1 - 0.01, sign * 0.13), (GUARD_Y1 - 0.01, sign * 0.1)][::sign],
                0.05, "gold")
    grip_bands(f, "gold", "ivory", bands=2)
    f.prism("PommelSun", half_disc(-0.5, 0.0, 0.046, n=16), 0.022, "gold")
    return {"design": "Daybreak Longsword", "concept": "a tangerine longsword with a rising half-sun over a horizon bar", "tier": 3,
            "calm": ["ivory"], "vivid": ["tangerine", "gold"]}


def design_summitward_broadsword(f):
    """Summitward Broadsword -- carried up the last stair of the Summit. A summit-white broadsword
    whose root shoulders step out in three stairs each side and then slope like a mountain to
    its point, a gold edge, a gold stepped bar, a
    tangerine grip with ivory bands and a gold mountain-peak pommel pointing down with an ivory
    snowcap at its peak. Calm: summit, ivory. Vivid: gold, tangerine."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        # three stairs at the root, then one long mountain slope to the summit point
        w = 0.05 + 0.012 * sum(smooth((t - s) / 0.012) for s in (0.07, 0.14, 0.21))
        if t > 0.24:
            w = lerp(0.086, 0.01, (t - 0.24) / 0.76)
        return -w, w, lerp(0.032, 0.016, t)
    blade(f, fn, "summit", "gold", n=48, chamfer=0.024)
    stairs = [(GUARD_Y0, -0.13), (GUARD_Y0, 0.13), (GUARD_Y1 - 0.024, 0.13), (GUARD_Y1 - 0.024, 0.1), (GUARD_Y1 - 0.012, 0.1),
              (GUARD_Y1 - 0.012, 0.07), (GUARD_Y1, 0.07), (GUARD_Y1, -0.07), (GUARD_Y1 - 0.012, -0.07), (GUARD_Y1 - 0.012, -0.1),
              (GUARD_Y1 - 0.024, -0.1), (GUARD_Y1 - 0.024, -0.13)]
    f.prism("Stairs", stairs, 0.046, "gold")
    grip_bands(f, "tangerine", "ivory", bands=2)
    f.prism("Peak", [(-0.5, 0.0), (-0.44, 0.05), (-0.44, -0.05)], 0.022, "gold")
    f.prism("Snowcap", [(-0.5, 0.0), (-0.48, 0.017), (-0.476, 0.008), (-0.472, 0.012), (-0.472, -0.012), (-0.476, -0.008), (-0.48, -0.017)], 0.026, "ivory")
    return {"design": "Summitward Broadsword", "concept": "a broadsword with stair-stepped shoulders", "tier": 3,
            "calm": ["summit", "ivory"], "vivid": ["gold", "tangerine"]}


def design_little_dawn(f):
    """Little Dawn (Relic) -- not the Titan's sun: a small, stubborn dawn of your own. A sunny dawn
    blade with ivory edges and a small smiling sun at its root (an ivory face in a tangerine rim,
    eight short rounded tangerine rays, tangerine eye dots and smile), a gold bar with two cloud
    puffs, an ivory grip with gold bands and a gold rising half-sun pommel.
    Calm: ivory, cloud. Vivid: dawn, tangerine, gold."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        # flaring like light spreading, to a round sunny tip
        w = lerp(0.05, 0.088, smooth(t / 0.76))
        if t > 0.8:
            w = 0.088 * _m.sqrt(max(0.0, 1 - ((t - 0.8) / 0.2) ** 2)) + 0.006
        return -w, w, lerp(0.031, 0.015, t)
    b, st = blade(f, fn, "dawn", "ivory", n=24, chamfer=0.026)
    cy = -0.11
    t0 = th_at(st, cy) + 0.008
    rim_disc(f, "Face", cy, 0.048, t0, "ivory", segs=32)
    f.torus_yz("Rim", cy, 0.0, 0.05, 0.009, "tangerine", seg=32, tube=12)
    for k in range(8):
        a = 2 * _m.pi * k / 8
        d = (_m.cos(a), _m.sin(a))
        ray = chaikin([(cy + 0.064 * d[0] - 0.008 * d[1], 0.064 * d[1] + 0.008 * d[0]), (cy + 0.09 * d[0] - 0.006 * d[1], 0.09 * d[1] + 0.006 * d[0]),
                       (cy + 0.09 * d[0] + 0.006 * d[1], 0.09 * d[1] - 0.006 * d[0]), (cy + 0.064 * d[0] + 0.008 * d[1], 0.064 * d[1] - 0.008 * d[0])], 1)
        f.prism(f"Ray{k}", ray, t0 - 0.002, "tangerine")
    for side in (1, -1):
        for z in (-0.016, 0.016):
            f.sphere(f"Eye{side}{z}", (side * t0, cy + 0.012, z), 0.007, "tangerine", segs=12, rings=6)
    f.prism("Smile", swoosh(cy + 0.006, 0.0, 0.024, 0.006, _m.pi * 0.65, _m.pi * 1.35, n=10), t0 + 0.003, "tangerine")
    end_bar(f, "gold", half_x=0.044)
    for side in (1, -1):
        for dz, dy, r in ((-0.07, 0.0, 0.022), (-0.048, 0.012, 0.017), (0.048, 0.012, 0.017), (0.07, 0.0, 0.022)):
            f.sphere(f"Puff{side}{dz}", (side * 0.044, (GUARD_Y0 + GUARD_Y1) / 2 + dy, dz), r, "cloud", segs=12, rings=6)
    grip_bands(f, "ivory", "gold", bands=2)
    f.prism("PommelSun", half_disc(-0.5, 0.0, 0.046, n=16), 0.022, "gold")
    return {"design": "Little Dawn", "concept": "a sunny blade with a small smiling sun at its root", "tier": 4,
            "calm": ["ivory", "cloud"], "vivid": ["dawn", "tangerine", "gold"]}


def diamond_wrap(f, colour, turns=2.0, r=0.006):
    """A grip wrap of two opposite helices crossing into diamonds."""
    steps = int(14 * turns) + 1
    for k, sgn in enumerate((1, -1)):
        h = helix(f, f"Wrap{k}", GRIP_Y0 + 0.014, GRIP_Y1 - 0.014, turns, GRIP_R, r, colour, segs=12, steps=steps)
        if sgn < 0:
            f.orient(h, scale=(-1, 1, 1))


def design_cloudstep_katana(f):
    """Cloudstep Katana -- light enough to carry up every stair. A long gently curved summit-white
    katana with a wavy gold hamon (the edge chamfer's width rippling along its length), a round
    tangerine tsuba with three round cut-outs (cloud walls), an ivory grip with a gold diamond wrap
    and a gold kashira cap. Calm: summit, ivory, cloud. Vivid: gold, tangerine."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.06 * t * t
        w = 0.036 if t < 0.88 else lerp(0.036, 0.004, smooth((t - 0.88) / 0.12))
        return c - w, c + w, lerp(0.024, 0.012, t)
    st = stations_from(fn, 40)
    rings = []
    for i, (y, zb, ze, t) in enumerate(st):
        ch = min(0.024 + 0.008 * _m.sin(i * 1.3), (ze - zb) * 0.6)
        rings.append([(t, y, zb), (t, y, ze - ch), (0.28 * t, y, ze), (-0.28 * t, y, ze), (-t, y, ze - ch), (-t, y, zb)])
    f.loft("Blade", rings, ["summit", "gold", "gold", "gold", "summit", "summit"], "summit")
    yc = (GUARD_Y0 + GUARD_Y1) / 2
    tsuba = f.lathe("Tsuba", [(0.0, yc - 0.012), (0.13, yc - 0.012), (0.13, yc + 0.012), (0.0, yc + 0.012)], "tangerine", segs=32)
    for k in range(3):
        a = _m.pi / 2 + 2 * _m.pi * k / 3
        c = f.lathe(f"Hole{k}", [(0.0, yc - 0.05), (0.018, yc - 0.05), (0.018, yc + 0.05), (0.0, yc + 0.05)], "cloud", segs=16,
                    axis_x=0.088 * _m.cos(a), axis_z=0.088 * _m.sin(a))
        f.sync_materials()
        f.cut(tsuba, c)
    f.lathe("Grip", [(0.0, GRIP_Y0 - 0.002), (GRIP_R, GRIP_Y0 - 0.002), (GRIP_R, GRIP_Y1 + 0.002), (0.0, GRIP_Y1 + 0.002)], "ivory", segs=20)
    diamond_wrap(f, "gold")
    f.lathe("Kashira", [(0.0, -0.5), (0.03, -0.5), (0.04, -0.49), (0.042, -0.47), (0.0, -0.47)], "gold", segs=20)
    return {"design": "Cloudstep Katana", "concept": "a curved katana with a wavy gold hamon and a cloud-cut tsuba", "tier": 3,
            "calm": ["summit", "ivory", "cloud"], "vivid": ["gold", "tangerine"]}


def design_highwind_nodachi(f):
    """Highwind Nodachi -- a very long blade for the very high wind. A long narrow curved ivory
    nodachi with a tangerine edge, two tangerine ribbons knotted at the guard and streaming up
    either side of the blade, a square gold tsuba, an ivory grip with gold bands and a gold cap with
    a small two-cone tangerine tassel. Calm: ivory. Vivid: tangerine, gold."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.07 * t * t
        w = 0.034 if t < 0.9 else lerp(0.034, 0.004, smooth((t - 0.9) / 0.1))
        return c - w, c + w, lerp(0.022, 0.012, t)
    blade(f, fn, "ivory", "tangerine", n=34, chamfer=0.02, double=False)
    for sign in (1, -1):
        rings = []
        for j in range(22):
            y = -0.19 + 0.34 * j / 21
            c = fn(y)
            zc = (c[1] if sign > 0 else c[0]) + sign * (0.022 + 0.014 * _m.sin(14 * y + (0 if sign > 0 else 1.6)) + 0.008 * j / 21)
            rings.append([(0.007, y, zc - 0.009), (0.007, y, zc + 0.009), (-0.007, y, zc + 0.009), (-0.007, y, zc - 0.009)])
        f.loft(f"Ribbon{sign}", rings, ["tangerine"] * 4, "tangerine")
    f.sphere("Knot", (0, GUARD_Y1 + 0.006, 0), 0.024, "tangerine", segs=16, rings=8)
    lying_prism(f, "Tsuba", [(-0.1, -0.13), (-0.1, 0.13), (0.1, 0.13), (0.1, -0.13)], 0.012, "gold", (GUARD_Y0 + GUARD_Y1) / 2)
    grip_bands(f, "ivory", "gold", bands=3)
    f.lathe("Cap", [(0.0, -0.472), (0.036, -0.472), (0.04, -0.464), (0.04, -0.456), (0.0, -0.456)], "gold", segs=20)
    for z in (-0.012, 0.012):
        icicle(f, f"Tassel{z}", -0.472, z, 0.028, 0.011, "tangerine")
    return {"design": "Highwind Nodachi", "concept": "a long nodachi with ribbons streaming up the blade", "tier": 3,
            "calm": ["ivory"], "vivid": ["tangerine", "gold"]}


def design_origami_crane_blade(f):
    """Origami Crane Blade (spin relic) -- a thousand folds, one edge. A flat-shaded paper diamond-
    section blade with crisp folds and pleated zigzag edges up to mid-blade, its valley faces cloud against the paper white, a tangerine
    origami crane (diamond body, spread wings, neck and tail spikes, all flat facets) perched on the
    hub of a gold pleated-fan bar, an ivory grip with gold bands and a low-poly gold paper-ball pommel.
    Calm: paper, cloud, ivory. Vivid: tangerine, gold."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.104, 0.004, t)  # one long paper-plane triangle
        return -w, w, lerp(0.034, 0.016, t)
    # pleated: every other station steps the edges out, so the outline zigzags like folded paper
    st = [(y, zb - 0.016 * (i % 2) * (y < 0.18), ze + 0.016 * (i % 2) * (y < 0.18), th) for i, (y, zb, ze, th) in enumerate(stations_from(fn, 55))]
    rings = [[(0.0, y, ze), (th, y, 0.0), (0.0, y, zb), (-th, y, 0.0)] for y, zb, ze, th in st]
    f.flat(f.loft("Blade", rings, lambda i, k: ("paper" if (k + i) % 2 == 0 else "cloud"), "paper"))
    # body, neck and tail as separate facets of different thickness (no shared face planes), all
    # thicker than the blade so the crane stands proud of both faces
    f.flat(f.prism("Body", [(-0.19, 0.0), (-0.155, 0.04), (-0.12, 0.0), (-0.155, -0.04)], 0.052, "tangerine"))
    f.flat(f.prism("Neck", [(-0.16, 0.012), (-0.14, 0.0), (-0.074, 0.074), (-0.068, 0.088), (-0.082, 0.08)], 0.046, "tangerine"))
    f.flat(f.prism("Tail", [(-0.16, -0.012), (-0.14, 0.0), (-0.085, -0.072), (-0.095, -0.074)], 0.046, "tangerine"))
    for sign in (1, -1):
        wing = f.prism(f"Wing{sign}", [(-0.17, 0.0), (-0.1, sign * 0.085), (-0.13, sign * 0.018)], 0.006, "tangerine")
        f.flat(f.orient(wing, rot=(0, _m.pi / 2, 0)))
        f.flat(f.prism(f"Fold{sign}", [(-0.165, 0.0), (-0.11, sign * 0.056), (-0.13, sign * 0.012)], 0.058, "tangerine"))
    zs = [-0.13 + 0.26 * j / 20 for j in range(21)]
    fan = [(GUARD_Y0, -0.13), (GUARD_Y0, 0.13)] + [(GUARD_Y1 - (0.0 if j % 2 else 0.016), z) for j, z in reversed(list(enumerate(zs)))]
    f.flat(f.prism("Fan", fan, 0.04, "gold"))
    grip_bands(f, "ivory", "gold", bands=2)
    ball = [(0.0, -0.5)] + [(0.04 * _m.sin(_m.pi * k / 7), -0.5 + 0.04 * (1 - _m.cos(_m.pi * k / 7))) for k in range(1, 7)] + [(0.0, -0.42)]
    f.flat(f.lathe("PaperBall", ball, "gold", segs=10))
    return {"design": "Origami Crane Blade", "concept": "a folded-paper blade with an origami crane on the guard", "tier": 4,
            "calm": ["paper", "cloud", "ivory"], "vivid": ["tangerine", "gold"]}


def design_sunsqueeze_blade(f):
    """Sunsqueeze Blade (spin relic) -- squeezed from the first sun over the Summit, like the best
    lemon in the bowl: Lemonade's own sword. A lemon blade with an ivory pith edge and a raised ivory
    juice drop near the tip, over a halved lemon (a lemon dome with its cut face toward the blade:
    eight lemon segments on an ivory pith disc) ringed by six short gold sun rays on a flat-ended gold
    bar, a tangerine grip with ivory bands and a whole gold mini-lemon pommel with two lime leaves.
    Calm: ivory. Vivid: lemon, gold, tangerine, lime."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        # a lemon wedge: narrow at both ends, full in the middle
        w = 0.006 + 0.07 * _m.sin(_m.pi * (0.12 + 0.88 * t)) ** 0.8
        return -w, w, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "lemon", "ivory", n=28, chamfer=0.028)
    drop = [(0.3 - 0.018 * _m.cos(a) + 0.03 * max(0.0, _m.cos(a)) ** 3, 0.018 * _m.sin(a)) for a in [_m.pi + 2 * _m.pi * k / 16 for k in range(16)]]
    plate(f, "Juice", drop, "ivory", st, lift=0.007)
    top = -0.172
    f.lathe("Dome", [(0.0, top - 0.068), (0.05, top - 0.064), (0.08, top - 0.05), (0.096, top - 0.028), (0.1, top - 0.006), (0.1, top)], "lemon", segs=32)
    f.lathe("Pith", [(0.0, top - 0.002), (0.1, top - 0.002), (0.1, top + 0.004), (0.0, top + 0.004)], "ivory", segs=32)
    for k in range(8):
        a0 = 2 * _m.pi * k / 8 + 0.06
        a1 = 2 * _m.pi * (k + 1) / 8 - 0.06
        wedge = [(0.012 * _m.cos((a0 + a1) / 2), 0.012 * _m.sin((a0 + a1) / 2))] + [(0.084 * _m.cos(a), 0.084 * _m.sin(a)) for a in [a0 + (a1 - a0) * j / 4 for j in range(5)]]
        lying_prism(f, f"Segment{k}", wedge, 0.004, "lemon", top + 0.006)
    for k in range(6):
        a = 2 * _m.pi * k / 6 + _m.pi / 6
        ray = [(0.1 * _m.cos(a - 0.12), 0.1 * _m.sin(a - 0.12)), (0.124 * _m.cos(a), 0.124 * _m.sin(a)), (0.1 * _m.cos(a + 0.12), 0.1 * _m.sin(a + 0.12))]
        lying_prism(f, f"SunRay{k}", ray, 0.008, "gold", top - 0.01)
    end_bar(f, "gold", y1=GUARD_Y0 + 0.02, half_x=0.044)
    grip_bands(f, "tangerine", "ivory", bands=2)
    f.lathe("MiniLemon", [(0.0, -0.5), (0.008, -0.498), (0.012, -0.492), (0.026, -0.486), (0.034, -0.474), (0.034, -0.46), (0.026, -0.448),
                          (0.012, -0.442), (0.0, -0.44)], "gold", segs=20)
    for sign in (1, -1):
        leaf(f, f"Leaf{sign}", -0.47, sign * 0.028, -0.43, sign * 0.09, 0.02, "lime", half_x=0.014)
    return {"design": "Sunsqueeze Blade", "concept": "a lemon blade rising from a halved lemon ringed by sun rays", "tier": 4,
            "calm": ["ivory"], "vivid": ["lemon", "gold", "tangerine", "lime"]}


DESIGNS.update({
    "Sword_SunmoteShiv": ("CelestialSummit", 1, design_sunmote_shiv),
    "Sword_CloudcutFalchion": ("CelestialSummit", 2, design_cloudcut_falchion),
    "Sword_ZenithSabre": ("CelestialSummit", 2, design_zenith_sabre),
    "Sword_DaybreakLongsword": ("CelestialSummit", 3, design_daybreak_longsword),
    "Sword_SummitwardBroadsword": ("CelestialSummit", 3, design_summitward_broadsword),
    "Sword_LittleDawn": ("CelestialSummit", 4, design_little_dawn),
    "Sword_CloudstepKatana": ("CelestialSummit", 3, design_cloudstep_katana),
    "Sword_HighwindNodachi": ("CelestialSummit", 3, design_highwind_nodachi),
    "Sword_OrigamiCraneBlade": ("CelestialSummit", 4, design_origami_crane_blade),
    "Sword_SunsqueezeBlade": ("CelestialSummit", 4, design_sunsqueeze_blade),
})
