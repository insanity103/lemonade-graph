# SunkenMarsh -- the marsh folk and the Drowned Bellwarden (brief section 8.9).
# Reeds, bog iron, silt, marshlights, bells, ferries, oars, frogs, a rubber duck and lilypads.
# Calm: mint, white. Vivid: aqua, aqua_blue, lime_yellow, lime_green, duck, orange.


def lying_pad(f, name, cz, r, colour, half_y, y, notch=0.0, clip=GUARD_HALF_SPAN, n=28):
    """A disc lying flat across the sword (in the X-Z plane) centred at z=cz, trimmed to a flat face
    at |z| = clip, with an optional notch (a wedge with a flat inner edge, never an acute corner)."""
    pts = []
    for k in range(n):
        a = 2 * _m.pi * k / n
        if notch and abs(_m.atan2(_m.sin(a - _m.pi / 2), _m.cos(a - _m.pi / 2))) < notch:
            continue
        pts.append((r * _m.cos(a), max(-clip, min(clip, cz + r * _m.sin(a)))))
    if notch:
        i = next(j for j in range(len(pts)) if pts[j][1] - cz > 0 and pts[j][0] < 0)
        pts.insert(i, (-0.2 * r, cz + 0.45 * r))
        pts.insert(i, (0.2 * r, cz + 0.45 * r))
    pad = f.prism(name, pts, half_y, colour)
    return f.orient(pad, rot=(0, 0, _m.pi / 2), loc=(0, y, 0))


def squash(f, name, centre, r, colour, scale, segs=16, rings=8):
    s = f.sphere(name, (0, 0, 0), r, colour, segs=segs, rings=rings)
    return f.orient(s, scale=scale, loc=centre)


def design_reed_cutter(f):
    """Reed Cutter -- for reed and rope alike. A mint sickle-curved cutter with its aqua edge on the
    inside of the curve, a small aqua-blue bar, a grip of five bundled mint reeds bound by two
    lime-yellow bands and an aqua-blue cattail pommel on a stem.
    Calm: mint. Vivid: aqua, aqua_blue, lime_yellow."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.11 * t * t
        w = lerp(0.05, 0.036, t) if t < 0.8 else lerp(0.04, 0.006, smooth((t - 0.8) / 0.2))
        return c - w, c + w, lerp(0.028, 0.014, t)
    blade(f, fn, "mint", "aqua", n=26, chamfer=0.026, double=False)
    end_bar(f, "aqua_blue", half_x=0.04)
    for k in range(5):
        x, z = (0.0, 0.0) if k == 4 else (0.022 * _m.cos(k * _m.pi / 2 + _m.pi / 4), 0.022 * _m.sin(k * _m.pi / 2 + _m.pi / 4))
        f.lathe(f"Reed{k}", [(0.0, GRIP_Y0 - 0.004), (0.016, GRIP_Y0 - 0.004), (0.016, GRIP_Y1 + 0.002), (0.0, GRIP_Y1 + 0.002)],
                "mint", segs=12, axis_x=x, axis_z=z)
    for k, y in enumerate((-0.41, -0.31)):
        f.lathe(f"Bind{k}", [(0.03, y - 0.011), (0.044, y - 0.011), (0.044, y + 0.011), (0.03, y + 0.011)], "lime_yellow", segs=20)
    f.lathe("Cattail", [(0.012, -0.5), (0.024, -0.496), (0.028, -0.486), (0.028, -0.47), (0.022, -0.462), (0.0, -0.458)], "aqua_blue", segs=16)
    return {"design": "Reed Cutter", "concept": "a sickle cutter on a bundled reed grip with a cattail pommel", "tier": 1,
            "calm": ["mint"], "vivid": ["aqua", "aqua_blue", "lime_yellow"]}


def design_bogiron_falchion(f):
    """Bogiron Falchion -- smelted from bog iron, pitted and stubborn. A chunky aqua-blue falchion
    pitted with five round mint-walled dimples on each face, a lime-yellow edge and a mint spine, a
    lumpy aqua-blue bar with two mint knobs on each face, a mint grip with aqua bands and a faceted
    aqua nugget pommel. Calm: mint. Vivid: aqua_blue, lime_yellow, aqua."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        # a stubby bog-iron chopper: the edge bellies out late and the spine clips off early
        zb = -0.046 if t < 0.76 else lerp(-0.046, 0.04, smooth((t - 0.76) / 0.24))
        ze = lerp(0.05, 0.11, smooth(t / 0.8)) if t < 0.86 else lerp(0.11, 0.052, smooth((t - 0.86) / 0.14))
        return zb, ze, lerp(0.034, 0.018, t)
    b, st = blade(f, fn, "aqua_blue", "lime_yellow", n=26, chamfer=0.028, double=False,
                  paint=lambda i, k, r: "mint" if k == 5 else ("lime_yellow" if r == "edge" else "aqua_blue"))
    for k, (y, z) in enumerate(((-0.12, -0.012), (-0.03, 0.03), (0.06, -0.014), (0.15, 0.036), (0.24, 0.004))):
        for side in (1, -1):
            s = f.sphere(f"Pit{k}{side}", (side * (th_at(st, y) + 0.012), y, z), 0.02, "mint", segs=16, rings=8)
            f.sync_materials()
            f.cut(b, s)
    end_bar(f, "aqua_blue", half_x=0.046)
    for side in (1, -1):
        for z in (-0.08, 0.08):
            f.sphere(f"Knob{side}{z}", (side * 0.046, (GUARD_Y0 + GUARD_Y1) / 2, z), 0.022, "mint", segs=12, rings=6)
    grip_bands(f, "mint", "aqua", bands=2)
    gem_pommel(f, "aqua", r=0.046, segs=7)
    return {"design": "Bogiron Falchion", "concept": "a pitted bog-iron falchion", "tier": 2,
            "calm": ["mint"], "vivid": ["aqua_blue", "lime_yellow", "aqua"]}


def design_silt_sabre(f):
    """Silt Sabre -- polished by a century of silt. A slim curved aqua sabre crossed by three raised
    wavy mint silt bands, a lime-yellow edge, an aqua-blue bar with smooth mint river stones on its
    faces, a mint grip with aqua-blue bands and a flat mint river-pebble pommel with an aqua band.
    Calm: mint. Vivid: aqua, aqua_blue, lime_yellow."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.025 * t * t
        w = 0.048 if t < 0.82 else lerp(0.048, 0.006, smooth((t - 0.82) / 0.18))
        return c - w, c + w, lerp(0.027, 0.014, t)
    b, st = blade(f, fn, "aqua", "lime_yellow", n=22, chamfer=0.022, double=False)
    for k, y0 in enumerate((-0.12, 0.04, 0.2)):
        zs = [lerp(-1, 1, j / 6) for j in range(7)]
        lo = [(y0 + 0.012 * _m.sin(4 * u + k), lerp(fn(y0)[0] + 0.005, fn(y0)[1] - 0.012, (u + 1) / 2)) for u in zs]
        hi = [(y0 + 0.045 + 0.012 * _m.sin(4 * u + k + 1.5), lerp(fn(y0 + 0.045)[0] + 0.005, fn(y0 + 0.045)[1] - 0.012, (u + 1) / 2)) for u in zs]
        plate(f, f"Silt{k}", lo + hi[::-1], "mint", st, lift=0.006)
    end_bar(f, "aqua_blue", half_x=0.044)
    for side in (1, -1):
        for z in (-0.06, 0.06):
            squash(f, f"Stone{side}{z}", (side * 0.044, (GUARD_Y0 + GUARD_Y1) / 2, z), 0.02, "mint", (0.6, 0.8, 1.3), segs=12, rings=6)
    grip_bands(f, "mint", "aqua_blue", bands=2)
    squash(f, "Pebble", (0, -0.5 + 0.032 * 0.8, 0), 0.032, "mint", (0.6, 0.8, 1.35), segs=16, rings=8)
    band = f.lathe("PebbleBand", [(0.03, -0.482), (0.0335, -0.482), (0.0335, -0.47), (0.03, -0.47)], "aqua", segs=16)
    f.orient(band, scale=(0.62, 1, 1.35))
    return {"design": "Silt Sabre", "concept": "a slim sabre banded by wavy silt layers", "tier": 2,
            "calm": ["mint"], "vivid": ["aqua", "aqua_blue", "lime_yellow"]}


def design_marshlight_longsword(f):
    """Marshlight Longsword -- carries a marshlight in the fuller, and leads you home. A mint
    longsword with aqua edges, a long fuller slot cut through it (aqua-blue walls) and a big
    lime-yellow marshlight orb seated in a round window near the tip, an aqua-blue bar with a
    lantern-frame hub, an aqua-blue grip with mint bands and a little lantern pommel: aqua-blue
    posts and caps round a glowing lime-yellow core. Calm: mint. Vivid: aqua, lime_yellow, aqua_blue."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = 0.066 if t < 0.86 else lerp(0.066, 0.01, smooth((t - 0.86) / 0.14))
        return -w, w, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "mint", "aqua", n=26, chamfer=0.026)
    hole(f, b, "Fuller", 0.03, 0.0, 0.012, "aqua_blue", scale=(1, 12.0, 1))
    hole(f, b, "Window", 0.27, 0.0, 0.03, "aqua_blue")
    f.sphere("Marshlight", (0, 0.27, 0), 0.034, "lime_yellow", segs=20, rings=10)
    end_bar(f, "aqua_blue", half_x=0.044)
    f.prism("Frame", [(GUARD_Y0 - 0.006, -0.046), (GUARD_Y0 - 0.006, 0.046), (GUARD_Y1 + 0.02, 0.046), (GUARD_Y1 + 0.02, -0.046)], 0.05, "aqua_blue")
    f.prism("Pane", [(GUARD_Y0 + 0.006, -0.03), (GUARD_Y0 + 0.006, 0.03), (GUARD_Y1 + 0.008, 0.03), (GUARD_Y1 + 0.008, -0.03)], 0.056, "lime_yellow")
    grip_bands(f, "aqua_blue", "mint", bands=2)
    f.prism("LampBase", [(-0.5, -0.032), (-0.5, 0.032), (-0.492, 0.032), (-0.492, -0.032)], 0.032, "aqua_blue")
    f.prism("LampCore", [(-0.494, -0.022), (-0.494, 0.022), (-0.462, 0.022), (-0.462, -0.022)], 0.022, "lime_yellow")
    f.prism("LampTop", [(-0.464, -0.03), (-0.464, 0.03), (-0.454, 0.03), (-0.454, -0.03)], 0.03, "aqua_blue")
    for x in (-0.024, 0.024):
        for z in (-0.024, 0.024):
            rod(f, f"Post{x}{z}", (x, -0.494, z), (x, -0.462, z), 0.006, "aqua_blue")
    return {"design": "Marshlight Longsword", "concept": "a longsword carrying a marshlight orb, with a lantern pommel", "tier": 3,
            "calm": ["mint"], "vivid": ["aqua", "lime_yellow", "aqua_blue"]}


def bell_outline(cy, cz, h, w):
    """A bell in the side view: crown at cy + h, lip at cy, a clapper bead below."""
    half = [(cy, w), (cy + 0.1 * h, w * 0.92), (cy + 0.45 * h, w * 0.62), (cy + 0.8 * h, w * 0.55), (cy + h, w * 0.3)]
    return [(y, cz - z) for y, z in half] + [(y, cz + z) for y, z in half[::-1]]


def design_bellringer_broadsword(f):
    """Bellringer Broadsword -- rings like the sunken bell when it lands. An aqua-blue broadsword
    flaring toward a rounded bell-mouth tip, mint edges, a raised lime-yellow bell emblem on the
    blade root, a mint bell-yoke guard arching toward the blade with flat ends, a mint grip with
    aqua bands and a small lime-yellow hanging bell pommel with its clapper.
    Calm: mint. Vivid: aqua_blue, lime_yellow, aqua."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.058, 0.09, smooth(t / 0.78))
        if t > 0.82:
            w = 0.09 * _m.sqrt(max(0.0, 1 - ((t - 0.82) / 0.18) ** 2)) + 0.008
        return -w, w, lerp(0.031, 0.016, t)
    b, st = blade(f, fn, "aqua_blue", "mint", n=28, chamfer=0.028)
    plate(f, "Bell", chaikin(bell_outline(-0.13, 0.0, 0.1, 0.044), 1), "lime_yellow", st, lift=0.008)
    disc_plate(f, "Clapper", -0.142, 0.0, 0.014, "lime_yellow", st, lift=0.008, segs=16)
    yoke = [(GUARD_Y1 - 0.052, -0.13), (GUARD_Y1 - 0.02, -0.13)]
    yoke += [(GUARD_Y1 - 0.02 + 0.03 * _m.cos(z / 0.13 * _m.pi / 2), z) for z in [-0.12 + 0.24 * j / 12 for j in range(13)]]
    yoke += [(GUARD_Y1 - 0.02, 0.13), (GUARD_Y1 - 0.052, 0.13)]
    yoke += [(GUARD_Y1 - 0.052 + 0.03 * _m.cos(z / 0.13 * _m.pi / 2), z) for z in [0.12 - 0.24 * j / 12 for j in range(13)]]
    f.prism("Yoke", yoke, 0.046, "mint")
    grip_bands(f, "mint", "aqua", bands=2)
    f.lathe("PommelBell", [(0.0, -0.44), (0.016, -0.444), (0.024, -0.46), (0.03, -0.478), (0.04, -0.49), (0.034, -0.49),
                           (0.024, -0.478), (0.018, -0.462), (0.0, -0.458)], "lime_yellow", segs=20)
    f.sphere("Clapper", (0, -0.49, 0), 0.01, "lime_yellow", segs=16, rings=8)
    return {"design": "Bellringer Broadsword", "concept": "a bell-mouthed broadsword with a bell emblem and a yoke guard", "tier": 3,
            "calm": ["mint"], "vivid": ["aqua_blue", "lime_yellow", "aqua"]}


def design_ferrymans_cutlass(f):
    """Ferryman's Cutlass -- still smells a little of river. A broad curved mint cutlass with a
    lime-yellow edge, an aqua-blue scallop-shell fan guard with raised aqua ribs, flat-ended at the
    guard's width, a mint grip wound with an aqua rope and an aqua-blue rope-knot ball pommel.
    Calm: mint. Vivid: lime_yellow, aqua, aqua_blue."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.1 * t * t - 0.02 * t
        zb = c - 0.05 if t < 0.86 else lerp(c - 0.05, c + 0.02, smooth((t - 0.86) / 0.14))
        ze = c + lerp(0.05, 0.072, smooth(t / 0.75)) if t < 0.8 else lerp(c + 0.072, c + 0.024, smooth((t - 0.8) / 0.2))
        return zb, ze, lerp(0.03, 0.015, t)
    blade(f, fn, "mint", "lime_yellow", n=28, chamfer=0.028, double=False)
    shell = [(GUARD_Y0 - 0.012, -0.03), (GUARD_Y0 - 0.012, 0.03), (GUARD_Y0 + 0.004, 0.13), (GUARD_Y1 - 0.012, 0.13)]
    shell += [(GUARD_Y1 + 0.014 * _m.cos(a) + 0.008 * abs(_m.sin(5 * a)), 0.118 * _m.sin(a)) for a in [_m.pi / 2 - _m.pi * j / 20 for j in range(1, 20)]]
    shell += [(GUARD_Y1 - 0.012, -0.13), (GUARD_Y0 + 0.004, -0.13)]
    f.prism("Shell", shell, 0.04, "aqua_blue")
    for k in range(5):
        a = _m.pi * (k + 1) / 6 - _m.pi / 2
        tube(f, f"Rib{k}", [(GUARD_Y0 - 0.004 + 0.06 * s * _m.cos(a), 0.11 * s * _m.sin(a)) for s in (0.15, 0.55, 0.95)], 0.006, "aqua", segs=12)
    f.lathe("Grip", [(0.0, GRIP_Y0 - 0.002), (GRIP_R, GRIP_Y0 - 0.002), (GRIP_R, GRIP_Y1 + 0.002), (0.0, GRIP_Y1 + 0.002)], "mint", segs=20)
    helix(f, "Rope", GRIP_Y0 + 0.014, GRIP_Y1 - 0.014, 4, GRIP_R, 0.008, "aqua", segs=12, steps=49)
    ball_pommel(f, "aqua_blue", r=0.038)
    return {"design": "Ferryman's Cutlass", "concept": "a broad cutlass over a scallop-shell guard", "tier": 2,
            "calm": ["mint"], "vivid": ["lime_yellow", "aqua", "aqua_blue"]}


def design_oarblade(f):
    """Oarblade -- a flat oar with an edge on it. A narrow aqua shaft widening into a broad rounded
    paddle with a mint rim and a painted mint band across it, an aqua-blue oarlock (a U opening
    toward the blade) on a flat-ended bar, a mint grip with an aqua-blue band and a mint oar-knob
    pommel. Calm: mint. Vivid: aqua, aqua_blue."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = 0.026 + 0.066 * smooth((t - 0.3) / 0.24)
        if t > 0.8:
            w = 0.092 * _m.sqrt(max(0.0, 1 - ((t - 0.8) / 0.2) ** 2)) + 0.008
        return -w, w, lerp(0.026, 0.016, t)
    band = lambda i: 17 <= i <= 19
    blade(f, fn, "aqua", "mint", n=32, chamfer=0.02,
          paint=lambda i, k, r: "mint" if (r == "edge" or band(i)) else "aqua")
    end_bar(f, "aqua_blue", y1=GUARD_Y1 - 0.01, half_x=0.044)
    lock = [(GUARD_Y1 - 0.012, -0.052), (GUARD_Y1 - 0.012, 0.052), (GUARD_Y1 + 0.05, 0.052), (GUARD_Y1 + 0.05, 0.036),
            (GUARD_Y1 + 0.006, 0.036), (GUARD_Y1 + 0.006, -0.036), (GUARD_Y1 + 0.05, -0.036), (GUARD_Y1 + 0.05, -0.052)]
    f.prism("Oarlock", lock, 0.034, "aqua_blue")
    ring_around(f, "Binding", 0.0, 0.03, 0.009, "aqua_blue")
    grip_bands(f, "mint", "aqua_blue", bands=1)
    ball_pommel(f, "mint", r=0.038)
    return {"design": "Oarblade", "concept": "an oar-shaped blade in an oarlock guard", "tier": 3,
            "calm": ["mint"], "vivid": ["aqua", "aqua_blue"]}


def note(cy, cz, s=1.0):
    """A quaver in the side view: an oval head, a stem up and a flag, as one outline."""
    head = [(cy + 0.011 * s * _m.sin(a) - 0.004 * s * _m.cos(a), cz + 0.016 * s * _m.cos(a)) for a in [_m.pi * 2 * k / 12 for k in range(12)]]
    stem = [(cy + 0.004 * s, cz + 0.016 * s), (cy + 0.06 * s, cz + 0.016 * s), (cy + 0.046 * s, cz + 0.034 * s),
            (cy + 0.04 * s, cz + 0.03 * s), (cy + 0.046 * s, cz + 0.026 * s), (cy + 0.004 * s, cz + 0.026 * s)]
    return head, stem


def design_frogsong_greatsword(f):
    """Frogsong Greatsword (warden epic) -- croaks a tune; the whole marsh sings back. A broad aqua
    greatsword with lime-yellow edges and two raised mint music notes on each face, a lime-yellow
    frog squatting on the guard hub (mint eyes with aqua-blue pupils on both sides, an aqua-blue
    mouth band), two notched lime-yellow lilypads lying flat on an aqua-blue bar and trimmed at the
    guard's width, a mint grip with aqua-blue bands and a mint lilypad-bud pommel.
    Calm: mint. Vivid: aqua, lime_yellow, aqua_blue."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = 0.094 if t < 0.84 else lerp(0.094, 0.012, smooth((t - 0.84) / 0.16))
        return -w, w, lerp(0.032, 0.016, t)
    b, st = blade(f, fn, "aqua", "lime_yellow", n=26, chamfer=0.03)
    for k, (y, z, s) in enumerate(((0.0, -0.036, 1.5), (0.2, 0.0, 1.3))):
        head, stem = note(y, z, s)
        plate(f, f"NoteHead{k}", head, "mint", st, lift=0.007)
        plate(f, f"NoteStem{k}", stem, "mint", st, lift=0.007)
    end_bar(f, "aqua_blue", y0=GUARD_Y0, y1=GUARD_Y0 + 0.022, half_x=0.05)
    for sign in (1, -1):
        lying_pad(f, f"Pad{sign}", sign * 0.082, 0.052, "lime_yellow", 0.014, GUARD_Y0 + 0.036, notch=0.35)
    # the frog is thicker than the blade so it stands proud of both faces
    squash(f, "Frog", (0, -0.16, 0), 0.058, "lime_yellow", (1.05, 0.7, 1.0), segs=20, rings=10)
    mouth = f.lathe("Mouth", [(0.052, -0.168), (0.059, -0.168), (0.059, -0.16), (0.052, -0.16)], "aqua_blue", segs=20)
    f.orient(mouth, scale=(1.05, 1, 1.0))
    for z in (-0.03, 0.03):
        f.sphere(f"Eye{z}", (0, -0.118, z), 0.036, "mint", segs=16, rings=8)
        for side in (1, -1):
            f.sphere(f"Pupil{z}{side}", (side * 0.03, -0.114, z), 0.013, "aqua_blue", segs=12, rings=6)
    grip_bands(f, "mint", "aqua_blue", bands=2)
    f.lathe("Bud", [(0.012, -0.5), (0.03, -0.492), (0.036, -0.478), (0.03, -0.462), (0.016, -0.448), (0.0, -0.44)], "mint", segs=20)
    return {"design": "Frogsong Greatsword", "concept": "a greatsword with music notes and a frog on lilypads", "tier": 4,
            "calm": ["mint"], "vivid": ["aqua", "lime_yellow", "aqua_blue"]}


def design_rubber_duck_rapier(f):
    """Rubber Duck Rapier (spin relic) -- squeaks on every hit; everybody wants it. A thin mint rapier
    with an aqua edge, a rubber duck (duck-yellow body, raised tail, head, orange bill, aqua-blue eye
    beads) sitting on a flat-ended aqua-blue bar and facing along the width, a mint grip with
    aqua-blue bands and a duckling-head pommel with an orange bill.
    Calm: mint. Vivid: duck, orange, aqua, aqua_blue."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.03, 0.006, t)
        return -w, w, lerp(0.02, 0.011, t)
    blade(f, fn, "mint", "aqua", n=20, chamfer=0.024)
    end_bar(f, "aqua_blue", half_x=0.042)
    squash(f, "DuckBody", (0, -0.158, -0.012), 0.05, "duck", (0.78, 0.72, 1.18), segs=20, rings=10)
    f.prism("Tail", [(-0.17, -0.05), (-0.13, -0.078), (-0.118, -0.066), (-0.15, -0.036)], 0.018, "duck")
    f.sphere("DuckHead", (0, -0.104, 0.024), 0.03, "duck", segs=18, rings=10)
    squash(f, "Bill", (0, -0.108, 0.06), 0.022, "orange", (0.9, 0.5, 1.05), segs=16, rings=8)
    for side in (1, -1):
        squash(f, f"Foot{side}", (side * 0.03, -0.19, 0.01), 0.024, "orange", (0.7, 0.35, 1.2), segs=16, rings=8)
    for side in (1, -1):
        f.sphere(f"Eye{side}", (side * 0.024, -0.096, 0.032), 0.007, "aqua_blue", segs=12, rings=6)
    grip_bands(f, "mint", "aqua_blue", bands=2)
    f.sphere("Duckling", (0, -0.47, 0), 0.03, "duck", segs=16, rings=8)
    squash(f, "DucklingBill", (0, -0.472, 0.03), 0.016, "orange", (0.8, 0.45, 1.0), segs=12, rings=6)
    return {"design": "Rubber Duck Rapier", "concept": "a thin rapier with a rubber duck riding the guard", "tier": 4,
            "calm": ["mint"], "vivid": ["duck", "orange", "aqua", "aqua_blue"]}


def design_lilypad_lantern(f):
    """Lilypad Lantern (spin relic) -- a lantern-bright blade that floats. A leaf-shaped lime-green
    blade with mint edges and a raised lime-yellow glowing core rib, a big notched aqua-blue lilypad
    lying flat as the guard (trimmed at the guard's width) under a white water lily of crossed petal
    stars with a lime-yellow heart, an aqua-blue grip with mint bands and a ribbed lime-yellow paper
    lantern pommel with aqua-blue caps. Calm: mint, white. Vivid: lime_green, lime_yellow, aqua_blue."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = 0.024 + 0.05 * _m.sin(_m.pi * min(t / 0.94, 1.0)) ** 1.4
        return -w, w, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "lime_green", "mint", n=28, chamfer=0.034)
    rings = []
    for y, zb, ze, th in st[2:-3]:
        rings.append([(th + 0.006, y, -0.007), (th + 0.006, y, 0.007), (-th - 0.006, y, 0.007), (-th - 0.006, y, -0.007)])
    f.loft("CoreRib", rings, ["lime_yellow"] * 4, "lime_yellow")
    lying_pad(f, "Pad", 0.0, 0.14, "aqua_blue", 0.016, (GUARD_Y0 + GUARD_Y1) / 2, notch=0.3, n=36)
    f.lathe("Stem", [(0.0, GUARD_Y0), (0.03, GUARD_Y0), (0.03, GUARD_Y1), (0.0, GUARD_Y1)], "aqua_blue", segs=16)
    for k, rot in enumerate((0.0, _m.pi / 2)):
        s = f.prism(f"Petals{k}", star(-0.15, 0.0, 6, 0.076, 0.034, rot=0.0), 0.016, "white")
        f.orient(s, rot=(0, rot, 0))
    f.sphere("Heart", (0, -0.15, 0), 0.03, "lime_yellow", segs=16, rings=8)
    grip_bands(f, "aqua_blue", "mint", bands=2)
    prof = [(0.018, -0.5), (0.03, -0.496)]
    for k in range(7):
        y = -0.492 + 0.042 * k / 6
        prof.append(((0.036 if k % 2 else 0.031) * (1 - 0.3 * ((k - 3) / 3) ** 2), y))
    prof += [(0.03, -0.446), (0.018, -0.442)]
    striped(f, "Lantern", prof, lambda i: "aqua_blue" if i in (0, len(prof) - 2) else "lime_yellow", segs=16)
    return {"design": "Lilypad Lantern", "concept": "a glowing leaf blade over a lilypad and water lily", "tier": 4,
            "calm": ["mint", "white"], "vivid": ["lime_green", "lime_yellow", "aqua_blue"]}


DESIGNS.update({
    "Sword_ReedCutter": ("SunkenMarsh", 1, design_reed_cutter),
    "Sword_BogironFalchion": ("SunkenMarsh", 2, design_bogiron_falchion),
    "Sword_SiltSabre": ("SunkenMarsh", 2, design_silt_sabre),
    "Sword_MarshlightLongsword": ("SunkenMarsh", 3, design_marshlight_longsword),
    "Sword_BellringerBroadsword": ("SunkenMarsh", 3, design_bellringer_broadsword),
    "Sword_FerrymansCutlass": ("SunkenMarsh", 2, design_ferrymans_cutlass),
    "Sword_Oarblade": ("SunkenMarsh", 3, design_oarblade),
    "Sword_FrogsongGreatsword": ("SunkenMarsh", 4, design_frogsong_greatsword),
    "Sword_RubberDuckRapier": ("SunkenMarsh", 4, design_rubber_duck_rapier),
    "Sword_LilypadLantern": ("SunkenMarsh", 4, design_lilypad_lantern),
})
