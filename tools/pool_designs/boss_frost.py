# Boss_FrostRevenant pool -- the Frost Revenant's armoury (brief section 8.2).
# Echo the Revenant: antlers, icicles, a crown, cut ice gems, deep-blue cloth. Calm: ice_white,
# pale_sky, white, snow. Vivid: cyan, deep_blue (aurora colours only on the Legendary).


def icicle(f, name, top_y, z, length, r, colour, down=True):
    """A rounded cone hanging from top_y (pointing toward the pommel when down)."""
    prof = [(0.0, 0.0), (r, 0.0), (r * 0.9, length * 0.3), (r * 0.45, length * 0.7), (0.0, length)]
    ic = f.lathe(name, prof, colour, segs=12)
    return f.orient(ic, rot=(_m.pi, 0, 0) if down else (0, 0, 0), loc=(0, top_y, z))


def design_rimeguard_shortsword(f):
    """Rimeguard Shortsword -- a short frost-rimed guard's blade. A short pale-sky leaf blade with
    cyan edges and three white frost nubs along each edge near the root, a deep-blue bar with a
    snowball on each face, a deep-blue grip with white bands and a white snowball pommel.
    Calm: pale_sky, white. Vivid: cyan, deep_blue."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.056, 0.074, smooth(t / 0.4)) if t < 0.5 else lerp(0.074, 0.008, smooth((t - 0.5) / 0.5))
        return -w, w, lerp(0.03, 0.014, t)
    b, st = blade(f, fn, "pale_sky", "cyan", n=18, chamfer=0.026)
    for k, y in enumerate((-0.14, -0.06)):
        for sign in (1, -1):
            f.sphere(f"Rime{k}{sign}", (0, y, sign * fn(y)[1]), 0.017, "white", segs=12, rings=6)
    end_bar(f, "deep_blue", half_x=0.044)
    for side in (1, -1):
        f.sphere(f"Snowball{side}", (side * 0.044, (GUARD_Y0 + GUARD_Y1) / 2, 0.0), 0.022, "white", segs=14, rings=7)
    grip_bands(f, "deep_blue", "white", bands=2)
    ball_pommel(f, "white", r=0.036)
    return {"design": "Rimeguard Shortsword", "concept": "a short leaf blade rimed with frost nubs", "tier": 1,
            "calm": ["pale_sky", "white"], "vivid": ["cyan", "deep_blue"]}


def design_glacier_falchion(f):
    """Glacier Falchion -- cut from a glacier's clear heart. A faceted falchion whose flat bands
    alternate cyan and ice-white like a glacier's layers, a raised ice-white diamond 'clear heart',
    two angular shard prongs swept back from a deep-blue bar, an ice-white grip with cyan bands and
    a hexagonal cyan crystal pommel. Calm: ice_white. Vivid: cyan, deep_blue."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        zb = -0.046 if t < 0.84 else lerp(-0.046, 0.01, (t - 0.84) / 0.16)
        ze = lerp(0.05, 0.094, smooth(t / 0.7)) if t < 0.8 else lerp(0.094, 0.018, (t - 0.8) / 0.2)
        return zb, ze, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "cyan", "ice_white", n=31, chamfer=0.03, double=False, flat=True,
                  paint=lambda i, k, r: "ice_white" if r != "body" else ("cyan" if i % 3 else "ice_white"))
    y = 0.08
    plate(f, "ClearHeart", [(y - 0.06, zc_at(st, y)), (y, zc_at(st, y) + 0.03), (y + 0.06, zc_at(st, y)), (y, zc_at(st, y) - 0.03)],
          "ice_white", st, lift=0.008, flat=True)
    end_bar(f, "deep_blue", y0=GUARD_Y0, y1=GUARD_Y0 + 0.03, half_x=0.046)
    pair(f, "Shard", [(GUARD_Y0 + 0.03, 0.03), (GUARD_Y0 + 0.03, 0.07), (-0.16, 0.118), (-0.2, 0.05)], 0.03, "deep_blue")
    grip_bands(f, "ice_white", "cyan", bands=2)
    gem_pommel(f, "cyan", r=0.046, segs=6)
    return {"design": "Glacier Falchion", "concept": "a banded glacier falchion with a clear diamond heart", "tier": 2,
            "calm": ["ice_white"], "vivid": ["cyan", "deep_blue"]}


def design_snowdrift_saber(f):
    """Snowdrift Saber -- packed snow that never melts. A curved snow-white saber with a deep-blue
    edge and four white snow lumps heaped along its spine, a deep-blue bar with a white six-point
    snowflake on the hub, a deep-blue grip with white bands and a white snowball pommel tied with a
    cyan scarf band. Calm: snow, white. Vivid: deep_blue, cyan."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.05 * t * t
        w = 0.054 if t < 0.8 else lerp(0.054, 0.008, smooth((t - 0.8) / 0.2))
        return c - w, c + w, lerp(0.029, 0.014, t)
    b, st = blade(f, fn, "snow", "deep_blue", n=28, chamfer=0.028, double=False)
    for k, y in enumerate((-0.1, 0.02, 0.14, 0.26)):
        f.sphere(f"Drift{k}", (0, y, fn(y)[0] + 0.004), 0.026 - 0.003 * k, "white", segs=14, rings=7)
    end_bar(f, "deep_blue", half_x=0.046)
    f.prism("Snowflake", star(-0.225, 0.0, 6, 0.05, 0.02), 0.052, "white")
    grip_bands(f, "deep_blue", "white", bands=2)
    ball_pommel(f, "white", r=0.038)
    f.lathe("Scarf", [(0.03, -0.462), (0.042, -0.462), (0.042, -0.448), (0.03, -0.448)], "cyan", segs=20)
    return {"design": "Snowdrift Saber", "concept": "a packed-snow saber with drifts on its spine and a snowflake guard", "tier": 2,
            "calm": ["snow", "white"], "vivid": ["deep_blue", "cyan"]}


def design_hoarwind_claymore(f):
    """Hoarwind Claymore -- hums with the hoar wind. A long ice-white claymore with cyan edges and
    two teardrop wind holes cut through it (cyan walls), two deep-blue gust arcs curling toward the
    blade above the bar, an ice-white grip with deep-blue bands and a cyan spiral-disc pommel.
    Calm: ice_white. Vivid: cyan, deep_blue."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = 0.068 if t < 0.86 else lerp(0.068, 0.012, smooth((t - 0.86) / 0.14))
        return -w, w, lerp(0.03, 0.015, t)
    b, st = blade(f, fn, "ice_white", "cyan", n=26, chamfer=0.028)
    hole(f, b, "WindA", 0.02, -0.018, 0.018, "cyan", scale=(1, 2.2, 1))
    hole(f, b, "WindB", 0.2, 0.018, 0.016, "cyan", scale=(1, 2.2, 1))
    end_bar(f, "deep_blue", y0=GUARD_Y0, y1=GUARD_Y0 + 0.028, half_x=0.046)
    for sign in (1, -1):
        pts = [(-0.227 + 0.06 * _m.sin(a), sign * (0.07 + 0.04 * _m.cos(a))) for a in [j * _m.pi * 1.2 / 14 for j in range(15)]]
        tube(f, f"Gust{sign}", pts, 0.013, "deep_blue")
    grip_bands(f, "ice_white", "deep_blue", bands=3)
    disc_pommel(f, "white", r=0.038, half_x=0.02)
    f.torus_yz("Spiral", -0.462, 0.0, 0.02, 0.008, "cyan", seg=24, tube=12)
    return {"design": "Hoarwind Claymore", "concept": "a claymore with wind holes and curling gust guards", "tier": 3,
            "calm": ["ice_white"], "vivid": ["cyan", "deep_blue"]}


def design_permafrost_greatsword(f):
    """Permafrost Greatsword -- quenched in ground that never thawed. A broad deep-blue greatsword
    with cyan edges whose root is sealed in a chunky faceted ice-white frost block, a thick
    deep-blue slab guard with two white icicles hanging toward the grip, a deep-blue grip with ice
    bands and a bevelled ice-cube pommel. Calm: ice_white, white. Vivid: deep_blue, cyan."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.08, 0.072, t) if t < 0.86 else lerp(0.072, 0.012, smooth((t - 0.86) / 0.14))
        return -w, w, lerp(0.031, 0.016, t)
    b, st = blade(f, fn, "deep_blue", "cyan", n=26, chamfer=0.028)
    block = [(-0.2, -0.1), (-0.2, 0.1), (-0.12, 0.108), (-0.04, 0.096), (0.0, 0.07), (0.01, 0.0), (0.0, -0.07), (-0.05, -0.1), (-0.12, -0.108)]
    f.flat(f.prism("FrostBlock", block, 0.05, "ice_white"))
    end_bar(f, "deep_blue", half_x=0.052)
    for z in (-0.095, 0.095):
        icicle(f, f"GuardIcicle{z}", GUARD_Y0 + 0.004, z, 0.05, 0.016, "ice_white")
    for k, y in enumerate((0.07, 0.15, 0.23, 0.31)):
        stud(f, f"Frozen{k}", y, 0.0, 0.017 - 0.002 * k, "white", st)
    grip_bands(f, "deep_blue", "ice_white", bands=2)
    f.flat(f.lathe("IceCube", [(0.0, -0.5), (0.05, -0.5), (0.05, -0.455), (0.0, -0.455)], "ice_white", segs=4))
    return {"design": "Permafrost Greatsword", "concept": "a greatsword frozen into a block of permafrost", "tier": 3,
            "calm": ["ice_white", "white"], "vivid": ["deep_blue", "cyan"]}


def design_aurora_greatblade(f):
    """Aurora Greatblade (Legendary) -- lit from within by the northern lights. A wide ice-white
    greatblade with three raised wavy aurora ribbons (aurora cyan, aqua, violet) running up each
    face, an antler crown guard (four deep-blue tines rising from the bar), a deep-blue grip with
    cyan bands and a faceted white gem pommel. Calm: ice_white, white. Vivid: aurora, aqua, violet, deep_blue."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        # narrow at the root, fanning wide toward the tip like a curtain of light
        w = lerp(0.044, 0.104, smooth(t / 0.8)) if t < 0.84 else lerp(0.104, 0.012, smooth((t - 0.84) / 0.16))
        return -w, w, lerp(0.031, 0.015, t)
    b, st = blade(f, fn, "ice_white", "aurora", n=30, chamfer=0.026)
    for k, (colour, off) in enumerate((("aurora", -0.036), ("aqua", 0.0), ("violet", 0.036))):
        rings = []
        for y, zb, ze, th in st[2:-6]:
            c = off + 0.012 * _m.sin(y * 18 + k * 1.3)
            rings.append([(th + 0.007, y, c - 0.009), (th + 0.007, y, c + 0.009), (-th - 0.007, y, c + 0.009), (-th - 0.007, y, c - 0.009)])
        f.loft(f"Aurora{k}", rings, [colour] * 4, colour)
    end_bar(f, "deep_blue", half_x=0.048)
    for z, h in ((-0.112, 0.06), (-0.1, 0.035), (0.1, 0.035), (0.112, 0.06)):
        f.prism(f"Tine{z}{h}", [(GUARD_Y1, z - 0.008), (GUARD_Y1, z + 0.008), (GUARD_Y1 + h, z + (0.004 if z > 0 else -0.004))], 0.022, "deep_blue")
    grip_bands(f, "deep_blue", "aurora", bands=2)
    gem_pommel(f, "white", r=0.046, segs=8)
    return {"design": "Aurora Greatblade", "concept": "a greatblade streaked with raised aurora ribbons under an antler crown", "tier": 4,
            "calm": ["ice_white", "white"], "vivid": ["aurora", "aqua", "violet", "deep_blue"]}


DESIGNS.update({
    "Sword_RimeguardShortsword": ("Boss_FrostRevenant", 1, design_rimeguard_shortsword),
    "Sword_GlacierFalchion": ("Boss_FrostRevenant", 2, design_glacier_falchion),
    "Sword_SnowdriftSaber": ("Boss_FrostRevenant", 2, design_snowdrift_saber),
    "Sword_HoarwindClaymore": ("Boss_FrostRevenant", 3, design_hoarwind_claymore),
    "Sword_PermafrostGreatsword": ("Boss_FrostRevenant", 3, design_permafrost_greatsword),
    "Sword_AuroraGreatblade": ("Boss_FrostRevenant", 4, design_aurora_greatblade),
})
