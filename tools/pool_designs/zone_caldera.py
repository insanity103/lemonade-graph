# InfernalCaldera -- the caldera's everyday blades and treats (brief section 8.10).
# Chips of the floor, smoky glass, clinker, furnaces, craters, the first spark, kiln hooks, heat
# haze, an anvil, and two fairground treats. Calm: cream, pale_peach, marshmallow. Vivid: ember_red,
# ember_yellow, basalt, orange, furnace, spark, gold, tangerine, timber, caramel.


def table_fn(rows, th0, th1):
    """fn(y) from a table of (t, z_back, z_edge) rows, linearly interpolated: hand-cut outlines."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        for (t0, b0, e0), (t1, b1, e1) in zip(rows, rows[1:]):
            if t <= t1 + 1e-9:
                u = (t - t0) / (t1 - t0)
                return lerp(b0, b1, u), lerp(e0, e1, u), lerp(th0, th1, t)
        return rows[-1][1], rows[-1][2], th1
    return fn


def flame(cy, h, w, lean=0.0):
    """A flame in the side view, its flat base at cy and its tip h above, leaning by `lean`."""
    right = [(cy, w * 0.7), (cy + 0.2 * h, w), (cy + 0.5 * h, w * 0.75 + lean * 0.3), (cy + 0.78 * h, w * 0.35 + lean * 0.7)]
    left = [(cy + 0.78 * h, -w * 0.2 + lean * 0.7), (cy + 0.5 * h, -w * 0.7 + lean * 0.3), (cy + 0.2 * h, -w), (cy, -w * 0.7)]
    return right + [(cy + h, lean)] + left


def spiral_strip(cy, cz, r0, r1, turns, width, n=24):
    """A flat spiral strip (outer edge out, inner edge back): a smoke curl."""
    out, inn = [], []
    for k in range(n + 1):
        a = 2 * _m.pi * turns * k / n
        r = lerp(r0, r1, k / n)
        out.append((cy + r * _m.sin(a), cz + r * _m.cos(a)))
        inn.append((cy + (r - width) * _m.sin(a), cz + (r - width) * _m.cos(a)))
    return out + inn[::-1]


def design_emberchip_shiv(f):
    """Emberchip Shiv -- a chip of the caldera floor, still warm. A chunky irregular ember-red chip,
    flat-shaded with cream-lit facet edges and a glowing ember-yellow tip facet, a short basalt bar,
    a cream grip with ember-red bands and a faceted ember-yellow nugget pommel.
    Calm: cream. Vivid: ember_red, ember_yellow, basalt."""
    fn = table_fn([(0.0, -0.05, 0.048), (0.22, -0.068, 0.058), (0.45, -0.05, 0.076), (0.7, -0.028, 0.05),
                   (0.86, -0.012, 0.03), (1.0, 0.004, 0.012)], 0.032, 0.016)
    blade(f, fn, "ember_red", "cream", n=11, chamfer=0.03, flat=True,
          paint=lambda i, k, r: "ember_yellow" if i >= 8 else ("cream" if r == "edge" else "ember_red"))
    end_bar(f, "basalt", y1=GUARD_Y1 - 0.006, half_x=0.042)
    grip_bands(f, "cream", "ember_red", bands=2)
    gem_pommel(f, "ember_yellow", r=0.044, segs=5)
    return {"design": "Emberchip Shiv", "concept": "an irregular faceted chip of glowing caldera floor", "tier": 1,
            "calm": ["cream"], "vivid": ["ember_red", "ember_yellow", "basalt"]}


def design_sootglass_falchion(f):
    """Sootglass Falchion -- glass with smoke trapped inside. A faceted cream smoky-glass falchion
    with an orange glassy edge and two raised orange smoke-curl spirals through it, a guard of round
    pale-peach glass beads threaded on an ember-red bar, an ember-red grip with cream bands and a
    pale-peach smoke-puff pommel of three merged balls. Calm: cream, pale_peach. Vivid: orange, ember_red."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        zb = -0.05 if t < 0.8 else lerp(-0.05, 0.01, smooth((t - 0.8) / 0.2))
        ze = lerp(0.05, 0.088, smooth(t / 0.7)) if t < 0.82 else lerp(0.088, 0.016, smooth((t - 0.82) / 0.18))
        return zb, ze, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "cream", "orange", n=14, chamfer=0.03, double=False, flat=True)
    for k, (y, z, turns) in enumerate(((-0.06, 0.004, 1.3), (0.17, 0.014, 1.2))):
        plate(f, f"Smoke{k}", spiral_strip(y, z, 0.006, 0.036, turns, 0.009), "orange", st, lift=0.006)
    end_bar(f, "ember_red", y0=GUARD_Y0 + 0.012, y1=GUARD_Y1 - 0.012, half_x=0.02)
    for z in (-0.096, -0.058, -0.02, 0.02, 0.058, 0.096):
        f.sphere(f"Bead{z}", (0, (GUARD_Y0 + GUARD_Y1) / 2, z), 0.021, "pale_peach", segs=12, rings=6)
    grip_bands(f, "ember_red", "cream", bands=2)
    f.sphere("Puff", (0, -0.478, 0), 0.022, "pale_peach", segs=16, rings=8)
    for z in (-0.02, 0.02):
        f.sphere(f"Puff{z}", (0, -0.465, z), 0.018, "pale_peach", segs=16, rings=8)
    return {"design": "Sootglass Falchion", "concept": "a smoky-glass falchion with curls of smoke inside", "tier": 2,
            "calm": ["cream", "pale_peach"], "vivid": ["orange", "ember_red"]}


def design_clinker_sabre(f):
    """Clinker Sabre -- rough clinker with a glowing seam. A curved orange sabre with a lumpy spine,
    cut low-res and flat-shaded so its faces read rough, a raised ember-yellow seam glowing down the
    centre, a cream edge, a lumpy basalt bar, a cream grip with basalt bands and an orange clinker
    lump pommel. Calm: cream. Vivid: orange, ember_yellow, basalt."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.05 * t * t
        lump = 0.008 * _m.sin(37 * t) + 0.005 * _m.sin(83 * t + 1)
        w = 0.058 if t < 0.8 else lerp(0.058, 0.008, smooth((t - 0.8) / 0.2))
        return c - w + (lump if t < 0.85 else 0.0), c + w, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "orange", "cream", n=17, chamfer=0.026, double=False, flat=True)
    rings = []
    for y, zb, ze, th in st[1:-3]:
        c = (zb + ze) / 2
        rings.append([(th + 0.006, y, c - 0.008), (th + 0.006, y, c + 0.008), (-th - 0.006, y, c + 0.008), (-th - 0.006, y, c - 0.008)])
    f.flat(f.loft("Seam", rings, ["ember_yellow"] * 4, "ember_yellow"))
    end_bar(f, "basalt", half_x=0.044)
    for side in (1, -1):
        for z in (-0.086, -0.02, 0.05, 0.1):
            f.flat(nugget(f, f"Lump{side}{z}", 0.0, 0.018, "basalt"))
            f.orient(f.parts[-1], loc=(side * 0.044, (GUARD_Y0 + GUARD_Y1) / 2 + 0.006 * (z > 0), z))
    grip_bands(f, "cream", "basalt", bands=2)
    gem_pommel(f, "orange", r=0.046, segs=5)
    return {"design": "Clinker Sabre", "concept": "a rough flat-shaded clinker sabre with a glowing seam", "tier": 2,
            "calm": ["cream"], "vivid": ["orange", "ember_yellow", "basalt"]}


def design_furnace_longsword(f):
    """Furnace Longsword -- never quite finished cooling. A straight longsword in three hard heat
    bands root to tip (cooled cream, furnace orange, hot ember-yellow) with ember-red edges, a
    furnace-grate guard with four slots cut through (ember-yellow walls), an ember-red grip with
    cream bands and a little bellows pommel (two furnace boards, a cream pleat and a nozzle).
    Calm: cream. Vivid: furnace, ember_yellow, ember_red."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = 0.064 if t < 0.86 else lerp(0.064, 0.01, smooth((t - 0.86) / 0.14))
        return -w, w, lerp(0.03, 0.015, t)
    heat = lambda i: "cream" if i < 12 else ("furnace" if i < 21 else "ember_yellow")
    blade(f, fn, "cream", "ember_red", n=31, chamfer=0.024, paint=lambda i, k, r: "ember_red" if r == "edge" else heat(i))
    grate = end_bar(f, "furnace", half_x=0.046)
    for z in (-0.096, -0.056, 0.056, 0.096):
        hole(f, grate, f"Slot{z}", (GUARD_Y0 + GUARD_Y1) / 2, z, 0.009, "ember_yellow", segs=16, scale=(1, 2.2, 1))
    grip_bands(f, "ember_red", "cream", bands=2)
    rod(f, "Nozzle", (0, -0.5, 0), (0, -0.476, 0), 0.008, "ember_red", segs=12)
    pear = chaikin([(-0.48, -0.012), (-0.48, 0.012), (-0.466, 0.036), (-0.448, 0.036), (-0.44, 0.02), (-0.44, -0.02), (-0.448, -0.036), (-0.466, -0.036)], 1)
    for x in (-0.012, 0.012):
        f.prism(f"Board{x}", pear, 0.006, "furnace", x_centre=x)
    f.prism("Pleat", [(y, z * 0.8) for y, z in pear], 0.012, "cream")
    return {"design": "Furnace Longsword", "concept": "a heat-banded longsword over a furnace grate, with a bellows pommel", "tier": 3,
            "calm": ["cream"], "vivid": ["furnace", "ember_yellow", "ember_red"]}


def design_caldera_broadsword(f):
    """Caldera Broadsword -- a broad slab of caldera rock with a hilt. A wide chunky flat-shaded
    basalt slab with cream crust edges and a crater near the root dished into each face (cream
    walls) holding an ember-yellow lava pool, two glowing zigzag cracks, a blunt stepped top, a jagged basalt ridge guard, a cream grip with basalt
    bands and a faceted basalt rock pommel. Calm: cream. Vivid: basalt, ember_yellow."""
    fn = table_fn([(0.0, -0.076, 0.078), (0.3, -0.088, 0.084), (0.62, -0.08, 0.09), (0.84, -0.066, 0.07),
                   (0.93, -0.05, 0.034), (1.0, -0.03, 0.024)], 0.036, 0.018)
    b, st = blade(f, fn, "basalt", "cream", n=15, chamfer=0.034, flat=True)
    y = -0.08
    for side in (1, -1):
        s = f.sphere(f"Crater{side}", (side * (th_at(st, y) + 0.03), y, 0.0), 0.05, "cream", segs=24, rings=12)
        f.sync_materials()
        f.cut(b, s)
    rim_disc(f, "LavaPool", y, 0.026, th_at(st, y) - 0.012, "ember_yellow", segs=24)
    for k, (y0, y1, z0) in enumerate(((0.02, 0.2, -0.03), (0.16, 0.36, 0.034))):
        plate(f, f"Crack{k}", zigzag(y0, y1, z0, 0.012, 5, 0.0045), "ember_yellow", st, lift=0.006, flat=True)
    ridge = [(GUARD_Y0, -0.13), (GUARD_Y0, 0.13), (GUARD_Y1 - 0.004, 0.13), (GUARD_Y1 + 0.012, 0.09), (GUARD_Y1 - 0.002, 0.05),
             (GUARD_Y1 + 0.018, 0.0), (GUARD_Y1 - 0.002, -0.05), (GUARD_Y1 + 0.012, -0.09), (GUARD_Y1 - 0.004, -0.13)]
    f.flat(f.prism("Ridge", ridge, 0.048, "basalt"))
    grip_bands(f, "cream", "basalt", bands=2)
    gem_pommel(f, "basalt", r=0.048, segs=5)
    return {"design": "Caldera Broadsword", "concept": "a rock-slab broadsword with a lava crater in each face", "tier": 3,
            "calm": ["cream"], "vivid": ["basalt", "ember_yellow"]}


def design_first_spark(f):
    """First Spark (Relic) -- the spark the caldera was lit from, kept in a blade. A slender cream
    blade with ember-red edges swelling round a window near the root that holds a big four-point
    ember-yellow spark star touching the rim, three raised spark-gold diamonds climbing to the tip,
    a flint-and-steel guard (an orange flint and a basalt striker meeting), a cream grip with
    ember-red bands and an ember-red match-head pommel on a cream collar.
    Calm: cream. Vivid: ember_red, ember_yellow, spark, orange, basalt."""
    hy = -0.1

    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.034, 0.006, t) + 0.04 * _m.exp(-((y - hy) / 0.06) ** 2)
        return -w, w, lerp(0.028, 0.014, t)
    b, st = blade(f, fn, "cream", "ember_red", n=30, chamfer=0.018)
    hole(f, b, "Window", hy, 0.0, 0.042, "ember_red", segs=28)
    f.prism("Spark", star(hy, 0.0, 4, 0.044, 0.012, rot=0.0), th_at(st, hy) - 0.004, "ember_yellow")
    for k, y in enumerate((0.08, 0.2, 0.31)):
        s = 0.024 - 0.004 * k
        plate(f, f"Glint{k}", [(y - s, 0.0), (y, s * 0.6), (y + s, 0.0), (y, -s * 0.6)], "spark", st, lift=0.007)
    f.prism("Flint", [(GUARD_Y0, -0.13), (GUARD_Y0, 0.0), (GUARD_Y1, 0.0), (GUARD_Y1, -0.1), (GUARD_Y1 - 0.02, -0.13)], 0.046, "orange")
    f.prism("Striker", [(GUARD_Y0 + 0.008, 0.004), (GUARD_Y0 + 0.008, 0.13), (GUARD_Y1 - 0.008, 0.13), (GUARD_Y1 - 0.008, 0.004)], 0.04, "basalt")
    grip_bands(f, "cream", "ember_red", bands=2)
    ball_pommel(f, "ember_red", r=0.03)
    f.lathe("Collar", [(0.0, -0.463), (0.032, -0.463), (0.032, -0.452), (0.0, -0.452)], "cream", segs=20)
    return {"design": "First Spark", "concept": "a slender blade holding the caldera's first spark in a window", "tier": 4,
            "calm": ["cream"], "vivid": ["ember_red", "ember_yellow", "spark", "orange", "basalt"]}


def design_kilnhook_khopesh(f):
    """Kilnhook Khopesh -- the kiln-keepers hook the hot trays out with it. A cream khopesh, straight
    at the root then swinging out in a big C with an ember-red edge on the outside of the curve, a
    tray-hook notch at the tip, three orange rivets at the root, a guard of three ember-red kiln bricks set in pale-peach mortar, a
    cream grip with orange bands and an orange kiln-shelf peg pommel.
    Calm: cream, pale_peach. Vivid: ember_red, orange."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        u = max(0.0, (t - 0.32) / 0.68)
        c = 0.064 * _m.sin(_m.pi * u) - 0.02 * u
        w = lerp(0.03, 0.048, smooth(u / 0.4)) if t < 0.9 else lerp(0.048, 0.012, (t - 0.9) / 0.1)
        return c - w, c + w, lerp(0.028, 0.015, t)
    b, st = blade(f, fn, "cream", "ember_red", n=36, chamfer=0.026, double=False)
    for k, y in enumerate((-0.14, -0.08, -0.02)):
        stud(f, f"Rivet{k}", y, 0.0, 0.012, "orange", st)
    zb = fn(0.47)[0]
    f.prism("Hook", [(0.43, zb + 0.006), (0.49, zb + 0.006), (0.49, zb - 0.032), (0.47, zb - 0.032), (0.47, zb - 0.012), (0.43, zb - 0.012)],
            th_at(st, 0.46), "cream")
    f.prism("Mortar", [(GUARD_Y0 + 0.006, -0.124), (GUARD_Y0 + 0.006, 0.124), (GUARD_Y1 - 0.006, 0.124), (GUARD_Y1 - 0.006, -0.124)], 0.036, "pale_peach")
    for z0, z1 in ((-0.13, -0.047), (-0.041, 0.041), (0.047, 0.13)):
        f.prism(f"Brick{z0}", [(GUARD_Y0, z0), (GUARD_Y0, z1), (GUARD_Y1, z1), (GUARD_Y1, z0)], 0.044, "ember_red")
    grip_bands(f, "cream", "orange", bands=2)
    f.lathe("Peg", [(0.0, -0.5), (0.022, -0.5), (0.022, -0.476), (0.038, -0.47), (0.038, -0.457), (0.0, -0.457)], "orange", segs=20)
    return {"design": "Kilnhook Khopesh", "concept": "a C-curved khopesh with a tray hook and a kiln-brick guard", "tier": 3,
            "calm": ["cream", "pale_peach"], "vivid": ["ember_red", "orange"]}


def design_cinderwave_flamberge(f):
    """Cinderwave Flamberge -- flickers like a heat haze. A narrow ember-red flamberge rippling in six
    small waves with cream edges and two thin wavy raised orange haze ribs running with it, an
    ember-yellow bar with two flame tips curling up, a cream grip with ember-red bands and a small
    two-tone flame pommel. Calm: cream. Vivid: ember_red, orange, ember_yellow."""
    def wave(y):
        return 0.013 * _m.sin(6 * 2 * _m.pi * (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y))

    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = 0.046 if t < 0.86 else lerp(0.046, 0.008, smooth((t - 0.86) / 0.14))
        c = wave(y) * (1 - smooth((t - 0.9) / 0.1))
        return c - w, c + w, lerp(0.028, 0.014, t)
    b, st = blade(f, fn, "ember_red", "cream", n=34, chamfer=0.022)
    for k, off in enumerate((-0.016, 0.016)):
        rings = []
        for y, zb, ze, th in st[1:-6]:
            c = (zb + ze) / 2 + off
            rings.append([(th + 0.006, y, c - 0.0045), (th + 0.006, y, c + 0.0045), (-th - 0.006, y, c + 0.0045), (-th - 0.006, y, c - 0.0045)])
        f.loft(f"Haze{k}", rings, ["orange"] * 4, "orange")
    end_bar(f, "ember_yellow", y1=GUARD_Y1 - 0.012, half_x=0.044)
    for sign in (1, -1):
        poly = [(y, sign * 0.092 + sign * z) for y, z in flame(GUARD_Y1 - 0.014, 0.06, 0.022, lean=0.02)]
        f.prism(f"Tongue{sign}", poly if sign > 0 else poly[::-1], 0.03, "ember_yellow")
    grip_bands(f, "cream", "ember_red", bands=2)
    f.prism("FlameOuter", flame(-0.5, 0.054, 0.032), 0.018, "orange")
    f.prism("FlameInner", flame(-0.5, 0.034, 0.018), 0.024, "ember_yellow")
    return {"design": "Cinderwave Flamberge", "concept": "a narrow flamberge rippling like heat haze", "tier": 3,
            "calm": ["cream"], "vivid": ["ember_red", "orange", "ember_yellow"]}


def design_anvilback_chopper(f):
    """Anvilback Chopper -- a chopper with an anvil for a spine; mind your toes. A square-ended basalt
    chopper with a cream edge and a gold anvil (base, waist, face and horn in profile) built into
    its spine near the tip, gold rivets along the spine, a gold mallet-head crossbar with squared, larger ends, a cream grip with
    basalt bands and a little gold hammer head set crosswise as the pommel.
    Calm: cream. Vivid: basalt, gold."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        ze = lerp(0.05, 0.094, smooth(t / 0.6))
        return -0.04, ze, lerp(0.032, 0.02, t)
    b, st = blade(f, fn, "basalt", "cream", n=28, chamfer=0.03, double=False)
    for k, y in enumerate((-0.14, -0.04, 0.06, 0.16)):
        stud(f, f"Rivet{k}", y, -0.018, 0.012, "gold", st)
    anvil = [(0.3, -0.03), (0.43, -0.03), (0.415, -0.058), (0.43, -0.074), (0.47, -0.09), (0.43, -0.1), (0.28, -0.1), (0.28, -0.082), (0.318, -0.058)]
    f.prism("Anvil", anvil, 0.03, "gold")
    f.prism("Bar", [(GUARD_Y0 + 0.012, -0.1), (GUARD_Y0 + 0.012, 0.1), (GUARD_Y1 - 0.012, 0.1), (GUARD_Y1 - 0.012, -0.1)], 0.036, "gold")
    for sign in (1, -1):
        f.prism(f"Head{sign}", [(GUARD_Y0 - 0.012, sign * 0.084), (GUARD_Y0 - 0.012, sign * 0.13), (GUARD_Y1 + 0.012, sign * 0.13), (GUARD_Y1 + 0.012, sign * 0.084)][::sign], 0.05, "gold")
    grip_bands(f, "cream", "basalt", bands=2)
    f.prism("Hammer", [(-0.5, -0.05), (-0.5, 0.05), (-0.472, 0.05), (-0.472, -0.05)], 0.026, "gold")
    f.lathe("Neck", [(0.0, -0.476), (0.016, -0.476), (0.016, -0.456), (0.0, -0.456)], "gold", segs=16)
    return {"design": "Anvilback Chopper", "concept": "a square chopper with an anvil built into its spine", "tier": 3,
            "calm": ["cream"], "vivid": ["basalt", "gold"]}


def design_toasted_marshmallow_brand(f):
    """Toasted Marshmallow Brand (spin relic) -- golden outside, gooey inside. A timber skewer
    sharpened to the sword's tip carrying four stacked marshmallows, each toasted with gold and
    tangerine rims, a campfire ring of orange stones round the skewer on a timber log bar, a timber
    grip with ember-red bands and a two-tone flame pommel (ember-red outside, ember-yellow core).
    Calm: marshmallow. Vivid: gold, tangerine, timber, ember_red, orange, ember_yellow."""
    f.lathe("Skewer", [(0.0, BLADE_ROOT_Y), (0.013, BLADE_ROOT_Y), (0.013, 0.4), (0.0, TIP_Y)], "timber", segs=16)
    for k in range(4):
        y0 = -0.18 + 0.1 * k
        h, r = 0.082, 0.058 - 0.003 * k
        prof = [(0.012, y0), (r - 0.012, y0), (r - 0.003, y0 + 0.004), (r, y0 + 0.014), (r, y0 + 0.03), (r, y0 + h - 0.03),
                (r, y0 + h - 0.014), (r - 0.003, y0 + h - 0.004), (r - 0.012, y0 + h), (0.012, y0 + h)]
        rims = {0: "tangerine", 1: "tangerine", 7: "gold", 8: "gold"}
        striped(f, f"Mallow{k}", prof, lambda i, rims=rims: rims.get(i, "marshmallow"), segs=20)
    end_bar(f, "timber", half_x=0.042)
    for k in range(8):
        a = 2 * _m.pi * k / 8
        f.sphere(f"Stone{k}", (0.05 * _m.cos(a), GUARD_Y1 + 0.004, 0.05 * _m.sin(a)), 0.016, "orange", segs=12, rings=6)
    grip_bands(f, "timber", "ember_red", bands=2)
    f.prism("FlameOuter", flame(-0.5, 0.056, 0.034), 0.02, "ember_red")
    f.prism("FlameInner", flame(-0.5, 0.046, 0.026), 0.028, "ember_yellow")
    return {"design": "Toasted Marshmallow Brand", "concept": "a skewer of four toasted marshmallows over a campfire ring", "tier": 4,
            "calm": ["marshmallow"], "vivid": ["gold", "tangerine", "timber", "ember_red", "orange", "ember_yellow"]}


def design_caramelt_claymore(f):
    """Caramelt Claymore (spin relic) -- molten sugar set as hard as basalt; smells like a fair. A
    caramel claymore with a cream candy edge and rounded caramel drips hanging along both edges, a
    cream frosting ribbon spiralling round the lower blade, a candy-cane guard striped cream and
    ember-red, a pale-peach grip with caramel bands and a candy-apple pommel (an ember-red apple with a
    caramel drip ring). Calm: cream, pale_peach. Vivid: caramel, ember_red."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        # slim at the root, swelling like poured sugar, then a long drawn-out point
        w = lerp(0.05, 0.072, smooth(t / 0.55)) if t < 0.66 else lerp(0.072, 0.008, smooth((t - 0.66) / 0.34))
        return -w, w, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "caramel", "cream", n=26, chamfer=0.026)
    for k, y in enumerate((-0.02, 0.1, 0.22, 0.33)):
        for sign in (1, -1):
            yy = y + 0.05 * (sign > 0)
            d = f.lathe(f"Drip{k}{sign}", [(0.0, -0.034), (0.008, -0.03), (0.012, -0.02), (0.012, 0.0), (0.0, 0.004)], "caramel", segs=12)
            f.orient(d, loc=(0, yy, sign * (fn(yy)[1] - 0.004)))
    h = helix(f, "Frosting", -0.17, 0.08, 1.5, 0.08, 0.009, "cream", segs=12, steps=37)
    f.orient(h, scale=(0.45, 1, 1))
    cane = striped(f, "Cane", [(0.024, -0.13 + 0.26 * j / 12) for j in range(13)], lambda i: "ember_red" if i % 2 else "cream", segs=16)
    f.orient(cane, rot=(_m.pi / 2, 0, 0), loc=(0, (GUARD_Y0 + GUARD_Y1) / 2, 0))
    grip_bands(f, "pale_peach", "caramel", bands=2)
    f.sphere("Apple", (0, -0.468, 0), 0.032, "ember_red", segs=20, rings=10)
    f.lathe("Coat", [(0.028, -0.462), (0.036, -0.46), (0.036, -0.448), (0.022, -0.442)], "caramel", segs=20)
    return {"design": "Caramelt Claymore", "concept": "a dripping caramel claymore on a candy-cane guard", "tier": 4,
            "calm": ["cream", "pale_peach"], "vivid": ["caramel", "ember_red"]}


DESIGNS.update({
    "Sword_EmberchipShiv": ("InfernalCaldera", 1, design_emberchip_shiv),
    "Sword_SootglassFalchion": ("InfernalCaldera", 2, design_sootglass_falchion),
    "Sword_ClinkerSabre": ("InfernalCaldera", 2, design_clinker_sabre),
    "Sword_FurnaceLongsword": ("InfernalCaldera", 3, design_furnace_longsword),
    "Sword_CalderaBroadsword": ("InfernalCaldera", 3, design_caldera_broadsword),
    "Sword_FirstSpark": ("InfernalCaldera", 4, design_first_spark),
    "Sword_KilnhookKhopesh": ("InfernalCaldera", 3, design_kilnhook_khopesh),
    "Sword_CinderwaveFlamberge": ("InfernalCaldera", 3, design_cinderwave_flamberge),
    "Sword_AnvilbackChopper": ("InfernalCaldera", 3, design_anvilback_chopper),
    "Sword_ToastedMarshmallowBrand": ("InfernalCaldera", 4, design_toasted_marshmallow_brand),
    "Sword_CarameltClaymore": ("InfernalCaldera", 4, design_caramelt_claymore),
})
