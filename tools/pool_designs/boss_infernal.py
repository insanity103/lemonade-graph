# Boss_InfernalColossus pool -- the Infernal Colossus's forge (brief section 8.3).
# Echo the Colossus: furnace horns, a molten heart, a crucible, cream and ember. Calm: cream,
# pale_peach, cream_grip. Vivid: ember_red, ember_yellow, orange, basalt and the pool's own oranges.
# Nine swords in one pool: every blade outline is chosen to differ -- stubby, dripping falchion,
# square cleaver, curved saber, straight vented sabre, spatulate claymore, hex-column claymore,
# triangular greatsword, and a waisted heart greatsword.


def zigzag(y0, y1, z0, amp, n, width):
    """A zigzag crack as one closed outline (a raised strip that bends n times)."""
    pts = [(y0 + (y1 - y0) * k / n, z0 + (amp if k % 2 else -amp)) for k in range(n + 1)]
    left = [(y, z - width) for y, z in pts]
    right = [(y, z + width) for y, z in reversed(pts)]
    return left + right


def heart(cy, cz, s):
    pts = []
    for k in range(24):
        a = 2 * _m.pi * k / 24
        x = 16 * _m.sin(a) ** 3
        y = 13 * _m.cos(a) - 5 * _m.cos(2 * a) - 2 * _m.cos(3 * a) - _m.cos(4 * a)
        pts.append((cy + y * s, cz + x * s))
    return pts


def design_cinder_shortsword(f):
    """Cinder Shortsword -- stubby, still smouldering at the edge. A stubby flickering-flame ember-red
    blade with ember-yellow edges and a raised yellow glow line near the tip, a cream bar with two
    orange smoulder bumps, a cream grip with ember-red bands and a three-puff cream smoke pommel.
    Calm: cream, cream_grip. Vivid: ember_red, ember_yellow, orange."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        # a stubby ember leaf: pinched at the guard, fattest a third of the way up, a long taper
        # a flickering flame: the width pulses twice before the point
        w = (0.05 + 0.02 * _m.sin(2.5 * _m.pi * t)) * (1 if t < 0.7 else max(1 - smooth((t - 0.7) / 0.3), 0.12))
        return -w, w, lerp(0.03, 0.016, t)
    b, st = blade(f, fn, "ember_red", "ember_yellow", n=20, chamfer=0.028)
    briar_rib(f, "Glow", st[10:16], 0, 0.009, "ember_yellow", extra=0.006)
    end_bar(f, "cream", half_x=0.046)
    for z in (-0.085, 0.085):
        f.sphere(f"Smoulder{z}", (0, GUARD_Y1 + 0.004, z), 0.02, "orange", segs=12, rings=6)
    grip_bands(f, "cream_grip", "ember_red", bands=2)
    f.sphere("Puff0", (0, -0.5 + 0.03, 0), 0.03, "cream", segs=14, rings=7)
    for z in (-0.024, 0.024):
        f.sphere(f"Puff{z}", (0, -0.456, z), 0.021, "cream", segs=12, rings=6)
    return {"design": "Cinder Shortsword", "concept": "a stubby smouldering blade with a smoke-puff pommel", "tier": 1,
            "calm": ["cream", "cream_grip"], "vivid": ["ember_red", "ember_yellow", "orange"]}


def design_magma_falchion(f):
    """Magma Falchion -- cast straight from the caldera's magma. A magma-orange falchion with three
    ember-yellow drips hanging off its edge, a cream crucible cup over a cream bar, a cream grip
    with orange bands and an ember-yellow magma-drop pommel.
    Calm: cream, cream_grip. Vivid: magma, ember_yellow, orange."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        zb = -0.044 if t < 0.84 else lerp(-0.044, 0.01, (t - 0.84) / 0.16)
        ze = lerp(0.05, 0.088, smooth(t / 0.7)) if t < 0.82 else lerp(0.088, 0.018, (t - 0.82) / 0.18)
        return zb, ze, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "magma", "ember_yellow", n=26, chamfer=0.026, double=False)
    for k, y in enumerate((-0.05, 0.08, 0.2)):
        drip = f.lathe(f"Drip{k}", [(0.0, 0.0), (0.02, 0.004), (0.022, 0.018), (0.012, 0.036), (0.0, 0.046)], "ember_yellow", segs=12)
        f.orient(drip, rot=(_m.radians(90), 0, 0), loc=(0, y, fn(y)[1] - 0.012))   # lathe +Y -> +Z: off the edge
    end_bar(f, "cream", half_x=0.046)
    f.lathe("Crucible", [(0.0, GUARD_Y1 - 0.004), (0.05, GUARD_Y1 - 0.004), (0.062, GUARD_Y1 + 0.024), (0.05, GUARD_Y1 + 0.03), (0.0, GUARD_Y1 + 0.03)], "cream", segs=20)
    grip_bands(f, "cream_grip", "orange", bands=2)
    f.lathe("MagmaDrop", [(0.012, -0.5), (0.03, -0.492), (0.038, -0.474), (0.03, -0.452), (0.012, -0.432), (0.0, -0.425)], "ember_yellow", segs=16)
    return {"design": "Magma Falchion", "concept": "a magma falchion dripping off its edge", "tier": 2,
            "calm": ["cream", "cream_grip"], "vivid": ["magma", "ember_yellow", "orange"]}


def design_slagheap_cleaver(f):
    """Slagheap Cleaver -- struck from the slagheap's crust. A squared cream meat-cleaver with an
    orange edge, four raised faceted orange crust plates on its faces, a hang hole near the spine
    top with an orange wall, a basalt collar and bar, an orange grip and a faceted basalt lump pommel.
    Calm: cream. Vivid: orange, basalt, ember_red."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        # a wedge: narrow at the guard, widening in a straight line to a broad square chopping end
        zb = -0.036 if t < 0.97 else -0.03
        ze = lerp(0.012, 0.112, t / 0.94) if t < 0.95 else lerp(0.112, 0.09, (t - 0.95) / 0.05)
        return zb, ze, lerp(0.029, 0.02, t)
    b, st = blade(f, fn, "cream", "orange", n=22, chamfer=0.03, double=False)
    hole(f, b, "HangHole", 0.42, -0.012, 0.018, "orange", segs=20)
    for k, (y, z) in enumerate(((-0.1, 0.02), (0.02, 0.05), (0.13, 0.0), (0.25, 0.04))):
        plate(f, f"Crust{k}", ngon(y, z, 0.03, 7, rot=k), "orange", st, flat=True)
    f.lathe("SlagCollar", [(0.0, -0.215), (0.05, -0.215), (0.05, -0.19), (0.0, -0.19)], "basalt", segs=16)
    end_bar(f, "basalt", half_x=0.046)
    grip_bands(f, "orange", "ember_red", bands=2)
    f.lathe("LumpBase", [(0.0, -0.5), (0.028, -0.5), (0.028, -0.488), (0.0, -0.488)], "basalt", segs=16)
    nugget(f, "Lump", -0.462, 0.033, "basalt")
    return {"design": "Slagheap Cleaver", "concept": "a square cleaver crusted with slag plates", "tier": 2,
            "calm": ["cream"], "vivid": ["orange", "basalt", "ember_red"]}


def design_ashen_saber(f):
    """Ashen Saber -- ash-steel with a glowing fuller. A curved pale-peach saber with an ember-red
    edge, a fuller groove cut into each face (ember-red walls) with a raised ember-yellow glow rib
    along it, an S-guard (one tube curling toward the blade, one toward the grip), an ember-red grip
    and a cream ball pommel ringed in red. Calm: pale_peach, cream. Vivid: ember_red, ember_yellow."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.045 * t * t
        w = 0.058 if t < 0.8 else lerp(0.058, 0.008, smooth((t - 0.8) / 0.2))
        return c - w, c + w, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "pale_peach", "ember_red", n=28, chamfer=0.026, double=False)
    for side in (1, -1):
        slot = [(-0.17, -0.012), (0.26, -0.012), (0.3, 0.0), (0.26, 0.012), (-0.17, 0.012)]
        c = f.prism(f"Fuller{side}", slot, 0.02, "ember_red", x_centre=side * 0.034)
        f.cut(b, c)
    briar_rib(f, "AshGlow", [(y, zb, ze, th - 0.012) for y, zb, ze, th in st[1:18]], 0, 0.005, "ember_yellow", extra=0.004)
    end_bar(f, "cream", y0=GUARD_Y0, y1=GUARD_Y0 + 0.028, half_x=0.046)
    tube(f, "SUp", [(-0.227 + 0.05 * _m.sin(a), 0.06 + 0.04 * _m.cos(a)) for a in [j * _m.pi * 1.1 / 12 for j in range(13)]], 0.013, "ember_red")
    tube(f, "SDown", [(-0.227 - 0.05 * _m.sin(a), -0.06 - 0.04 * _m.cos(a)) for a in [j * _m.pi * 1.1 / 12 for j in range(13)]], 0.013, "ember_red")
    grip_bands(f, "ember_red", "cream", bands=2)
    ball_pommel(f, "cream", r=0.036)
    f.lathe("AshRing", [(0.032, -0.476), (0.04, -0.476), (0.04, -0.464), (0.032, -0.464)], "ember_red", segs=20)
    return {"design": "Ashen Saber", "concept": "an ash saber with a glowing fuller and an S-guard", "tier": 2,
            "calm": ["pale_peach", "cream"], "vivid": ["ember_red", "ember_yellow"]}


def design_vent_sabre(f):
    """Vent Sabre -- tempered in a steam vent. A straight vent-orange sabre with three long steam
    slots cut near the root (cream walls) and a cream pipe running along its spine, a pipe-elbow
    guard (cream tubes turning down toward the grip at the ends), a cream grip and an ember-red valve
    wheel pommel. Calm: cream, cream_grip. Vivid: vent, ember_red, ember_yellow."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        zb = -0.05 + 0.01 * t
        ze = 0.058 if t < 0.84 else lerp(0.058, -0.02, (t - 0.84) / 0.16)
        return zb, ze, lerp(0.03, 0.016, t)
    b, st = blade(f, fn, "vent", "ember_yellow", n=18, chamfer=0.026, double=False)
    for k, y in enumerate((-0.12, -0.02, 0.08)):
        hole(f, b, f"Vent{k}", y, 0.01, 0.012, "cream", segs=16, scale=(1, 3.2, 1))
    tube(f, "Pipe", [(y, fn(y)[0] + 0.004) for y in [BLADE_ROOT_Y + 0.62 * k / 12 for k in range(13)]], 0.013, "cream")
    end_bar(f, "cream", y0=GUARD_Y0 + 0.01, y1=GUARD_Y1, half_x=0.04, span=0.1)
    for sign in (1, -1):
        pts = [(-0.21 - 0.04 * (1 - _m.cos(a)), sign * (0.1 + 0.018 * _m.sin(a))) for a in [j * _m.pi / 2 / 8 for j in range(9)]]
        tube(f, f"Elbow{sign}", pts, 0.012, "cream")
    pair(f, "ElbowEnd", [(-0.262, 0.105), (-0.232, 0.105), (-0.232, 0.13), (-0.262, 0.13)], 0.02, "ember_red")
    grip_bands(f, "cream_grip", "vent", bands=1)
    wy = -0.5 + 0.034
    f.torus_yz("Valve", wy, 0.0, 0.026, 0.008, "ember_red", seg=24, tube=12)
    rod(f, "SpokeA", (0, wy - 0.026, 0), (0, wy + 0.026, 0), 0.007, "ember_red", segs=12)
    rod(f, "SpokeB", (0, wy, -0.026), (0, wy, 0.026), 0.007, "ember_red", segs=12)
    return {"design": "Vent Sabre", "concept": "a steam-vented sabre with a spine pipe and a valve-wheel pommel", "tier": 2,
            "calm": ["cream", "cream_grip"], "vivid": ["vent", "ember_red", "ember_yellow"]}


def design_emberplate_claymore(f):
    """Emberplate Claymore -- plated in cooling ember-scale. A cream claymore that widens toward
    its tip, its faces covered in rows of raised rounded orange scales, ember-yellow edges, two
    ember-red scaled prongs swept back from the bar, an ember-red grip with cream bands and an
    orange scale-disc pommel. Calm: cream. Vivid: orange, ember_yellow, ember_red."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.058, 0.094, smooth(t / 0.8)) if t < 0.84 else lerp(0.094, 0.012, smooth((t - 0.84) / 0.16))
        return -w, w, lerp(0.031, 0.016, t)
    b, st = blade(f, fn, "cream", "ember_yellow", n=28, chamfer=0.026)
    k = 0
    for row, y in enumerate((-0.14, -0.06, 0.02, 0.1, 0.18)):
        for z in ((-0.024, 0.024) if row % 2 == 0 else (0.0,)):
            scale = [(y + 0.03 * _m.sin(a), z + 0.022 * _m.cos(a)) for a in [_m.pi * j / 10 for j in range(11)]] + [(y - 0.012, z - 0.022), (y - 0.012, z + 0.022)]
            plate(f, f"Scale{k}", scale, "orange", st)
            k += 1
    end_bar(f, "ember_red", y0=GUARD_Y0, y1=GUARD_Y0 + 0.028, half_x=0.046)
    pair(f, "Prong", [(GUARD_Y0 + 0.028, 0.03), (GUARD_Y0 + 0.028, 0.08), (-0.172, 0.118), (-0.19, 0.06)], 0.03, "ember_red")
    grip_bands(f, "ember_red", "cream", bands=2)
    disc_pommel(f, "orange", r=0.038, half_x=0.022)
    return {"design": "Emberplate Claymore", "concept": "a claymore armoured in ember scales", "tier": 3,
            "calm": ["cream"], "vivid": ["orange", "ember_yellow", "ember_red"]}


def design_basalt_claymore(f):
    """Basalt Claymore -- heavy as the mountain. A faceted basalt claymore with a squared chisel
    tip whose last stretch is cream (cooled), three raised ember-yellow zigzag cracks, a basalt bar
    stacked with hexagonal column ends, a cream grip and a basalt hex-column pommel.
    Calm: cream, pale_peach. Vivid: basalt, ember_yellow."""
    n = 26

    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        zb = -0.074 if t < 0.84 else lerp(-0.074, 0.02, (t - 0.84) / 0.16)
        return zb, 0.074 if t < 0.97 else 0.06, lerp(0.032, 0.018, t)
    b, st = blade(f, fn, "basalt", "pale_peach", n=n, chamfer=0.03, flat=True,
                  paint=lambda i, k, r: "cream" if i >= n - 4 else ("basalt" if r == "body" else "pale_peach"))
    for k, (y0, y1, z) in enumerate(((-0.15, 0.0, -0.03), (-0.02, 0.14, 0.025), (0.12, 0.26, -0.01))):
        plate(f, f"Crack{k}", zigzag(y0, y1, z, 0.012, 4, 0.008), "ember_yellow", st, lift=0.006)
    end_bar(f, "basalt", half_x=0.046)
    for z in (-0.1, 0.1):
        col = f.lathe(f"Column{z}", [(0.0, -0.265), (0.03, -0.265), (0.03, -0.185), (0.0, -0.185)], "basalt", segs=6)
        f.flat(f.orient(col, loc=(0, 0, z)))
    grip_bands(f, "cream", "basalt", bands=2)
    f.flat(f.lathe("HexStub", [(0.0, -0.5), (0.044, -0.5), (0.044, -0.456), (0.0, -0.456)], "basalt", segs=6))
    return {"design": "Basalt Claymore", "concept": "a faceted basalt-column claymore with glowing cracks", "tier": 3,
            "calm": ["cream", "pale_peach"], "vivid": ["basalt", "ember_yellow"]}


def design_pyroclast_greatsword(f):
    """Pyroclast Greatsword -- cooling lava, cracks still glowing. A tall triangular lava-red
    greatsword, widest at the root, with a network of raised ember-yellow crack strips and cream
    rock chunks on its faces, a basalt volcano guard with an ember-yellow crater, a cream grip with
    lava bands and a lava-bomb pommel banded with cream crust.
    Calm: cream. Vivid: lava, ember_yellow, basalt."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.1, 0.01, t ** 1.2)
        return -w, w, lerp(0.032, 0.016, t)
    b, st = blade(f, fn, "lava", "cream", n=26, chamfer=0.026)
    for k, (y0, y1, z) in enumerate(((-0.16, -0.02, -0.04), (-0.12, 0.04, 0.036), (0.02, 0.18, 0.0), (0.16, 0.3, 0.0))):
        plate(f, f"Crack{k}", zigzag(y0, y1, z, 0.01, 4, 0.007), "ember_yellow", st, lift=0.006)
    for k, (y, z) in enumerate(((-0.09, 0.0), (0.08, -0.03), (0.1, 0.03))):
        stud(f, f"Rock{k}", y, z, 0.016, "cream", st)
    end_bar(f, "basalt", half_x=0.048)
    f.prism("Volcano", [(GUARD_Y1, -0.08), (GUARD_Y1, 0.08), (GUARD_Y1 + 0.03, 0.04), (GUARD_Y1 + 0.03, -0.04)], 0.05, "basalt")
    f.prism("Crater", [(GUARD_Y1 + 0.024, -0.03), (GUARD_Y1 + 0.024, 0.03), (GUARD_Y1 + 0.034, 0.03), (GUARD_Y1 + 0.034, -0.03)], 0.052, "ember_yellow")
    grip_bands(f, "cream", "lava", bands=2)
    striped(f, "LavaBomb", [(0.012, -0.5), (0.03, -0.494), (0.04, -0.478), (0.04, -0.46), (0.03, -0.444), (0.0, -0.438)],
            lambda i: "cream" if i in (0, 4) else "lava", segs=16)
    return {"design": "Pyroclast Greatsword", "concept": "a cracked lava greatsword over a volcano guard", "tier": 3,
            "calm": ["cream"], "vivid": ["lava", "ember_yellow", "basalt"]}


def design_colossus_heart(f):
    """Colossus Heart (Legendary) -- the Colossus's molten heart, hammered into a greatsword. A
    greatsword with broad shoulders, a waist and a leaf point, split in two hard bands (ember red
    below, orange above) with ember-yellow edges; a big ember-yellow heart gem in a cream bezel at
    the root; two cream furnace horns curving up from the bar; a cream grip with ember-red bands and
    a little cream furnace pommel glowing yellow through its grate.
    Calm: cream, cream_grip. Vivid: ember_red, orange, ember_yellow, colossus."""
    n = 30

    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        if t < 0.25:
            w = lerp(0.1, 0.06, smooth(t / 0.25))
        elif t < 0.7:
            w = lerp(0.06, 0.084, smooth((t - 0.25) / 0.45))
        else:
            w = lerp(0.084, 0.01, smooth((t - 0.7) / 0.3))
        return -w, w, lerp(0.032, 0.016, t)
    b, st = blade(f, fn, "ember_red", "ember_yellow", n=n, chamfer=0.026,
                  paint=lambda i, k, r: "ember_yellow" if r != "body" else ("ember_red" if i < n * 0.45 else "orange"))
    plate(f, "Bezel", heart(-0.13, 0.0, 0.0042), "cream", st, lift=0.006)
    plate(f, "HeartGem", heart(-0.131, 0.0, 0.0031), "colossus", st, lift=0.011)
    end_bar(f, "cream", y0=GUARD_Y0, y1=GUARD_Y0 + 0.03, half_x=0.048)
    for sign in (1, -1):
        pts = [(-0.224 + 0.07 * _m.sin(a), sign * (0.104 - 0.03 * (1 - _m.cos(a)))) for a in [j * _m.pi / 2 / 10 for j in range(11)]]
        tube(f, f"Horn{sign}", pts, 0.015, "cream")
    grip_bands(f, "cream_grip", "ember_red", bands=2)
    f.flat(f.lathe("Furnace", [(0.0, -0.5), (0.046, -0.5), (0.046, -0.452), (0.0, -0.452)], "cream", segs=4))
    f.prism("Grate", [(-0.49, -0.018), (-0.49, 0.018), (-0.462, 0.018), (-0.462, -0.018)], 0.036, "ember_yellow")
    return {"design": "Colossus Heart", "concept": "a banded greatsword set with a molten heart, horns and a furnace", "tier": 4,
            "calm": ["cream", "cream_grip"], "vivid": ["ember_red", "orange", "ember_yellow", "colossus"]}


DESIGNS.update({
    "Sword_CinderShortsword": ("Boss_InfernalColossus", 1, design_cinder_shortsword),
    "Sword_MagmaFalchion": ("Boss_InfernalColossus", 2, design_magma_falchion),
    "Sword_SlagheapCleaver": ("Boss_InfernalColossus", 2, design_slagheap_cleaver),
    "Sword_AshenSaber": ("Boss_InfernalColossus", 2, design_ashen_saber),
    "Sword_VentSabre": ("Boss_InfernalColossus", 2, design_vent_sabre),
    "Sword_EmberplateClaymore": ("Boss_InfernalColossus", 3, design_emberplate_claymore),
    "Sword_BasaltClaymore": ("Boss_InfernalColossus", 3, design_basalt_claymore),
    "Sword_PyroclastGreatsword": ("Boss_InfernalColossus", 3, design_pyroclast_greatsword),
    "Sword_ColossusHeart": ("Boss_InfernalColossus", 4, design_colossus_heart),
})
