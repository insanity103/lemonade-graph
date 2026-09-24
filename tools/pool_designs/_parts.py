# tools/pool_designs/_parts.py -- the shared part library for the pool swords.
# Run inside tools/blender_pool_swords.py's namespace (see the loader at the end of its designs), so
# Forge/PoolForge, P, the layout constants and every boss-forge helper are already in scope.
#
# What this library encodes, learned from the first two pools (Iron Lowlands, and Briarwood, which
# another model built and this pass reviewed):
#   * carry the motif in several places as real objects (blade + guard + pommel), not one decal
#   * shaped guard ends that carry the +-0.13 widest point with a flat face, not always a bar
#   * stripes by paint on a lofted lathe (a bee, a dipper) instead of stacked parts
#   * tubes along a path (vines, wires, strings, tendrils) for guards a bar cannot make
#   * raised face plates run THROUGH the blade (one prism, half_x = local thickness + lift), so the
#     emblem reads identically from either side and the bounding box stays symmetric in X
#   * never a concave outline with an acute inner corner as a flat prism cap (it folds black under the
#     bevel -- the Hedgehog's J-hook), never two parts sharing a face at the same plane (z-fighting --
#     the Billhook's guard ends), and pommels big enough to read
#   * learned building the other 100: anything round (tubes, spheres, helices, lathes) needs >= 12
#     segments or finish()'s 32-degree bevel catches every edge and triples its triangles -- and a
#     helix squeezed flat must keep a round tube (ellipse_helix), not be scaled; a flat part thinner
#     than the blade vanishes inside it (make a frog or a crane thicker than the blade); frame bars
#     stop where the cross bars begin rather than overlapping them
import math as _m

P.update({
    "ember_orange": (255, 92, 40), "aurora": (96, 232, 255), "magma": (255, 104, 32), "vent": (255, 112, 40),
    "lava": (255, 80, 30), "colossus": (255, 170, 40), "verdict": (220, 96, 255), "starlight": (240, 240, 255),
    "comet": (200, 225, 255), "spire": (255, 200, 60), "titan": (240, 244, 255), "snow": (245, 250, 255),
    "snowpack": (236, 246, 255), "blue_hour": (96, 226, 255), "estoc_ice": (200, 236, 255), "globe": (220, 245, 255),
    "spark": (255, 196, 96), "furnace": (255, 132, 48), "marshmallow": (255, 236, 208), "epee_gold": (255, 190, 48),
    "kite": (200, 236, 255), "rainbow_pink": (255, 96, 216), "quiet_star": (230, 100, 255), "sunmote": (255, 240, 206),
    "summit": (240, 244, 255), "dawn": (255, 232, 72), "paper": (255, 250, 235), "rift_pink": (255, 96, 255),
})


def th_at(st, y):
    """Blade half-thickness at y from a station list (y, z_back, z_edge, half_thickness)."""
    best = min(st, key=lambda s: abs(s[0] - y))
    return best[3]


def zc_at(st, y):
    best = min(st, key=lambda s: abs(s[0] - y))
    return (best[1] + best[2]) / 2


def blade(f, fn, body, edge, n=28, chamfer=0.026, double=True, paint=None, name="Blade", cap=None, flat=False):
    """A lofted blade from fn(y) -> (z_back, z_edge, half_thickness). paint(i, k, role) may override
    colours per station/strip for bands and splits. Returns (object, stations)."""
    st = stations_from(fn, n)
    rings, roles = blade_rings(st, chamfer, double)
    if paint:
        colours = lambda i, k: paint(i, k, roles[k])
    else:
        colours = [body if r == "body" else edge for r in roles]
    obj = f.loft(name, rings, colours, cap or body)
    if flat:
        f.flat(obj)
    return obj, st


def plate(f, name, poly, colour, st, lift=0.007, flat=False):
    """A raised emblem on both faces: one prism through the blade, proud of each face by `lift`."""
    ys = [p[0] for p in poly]
    t = max(th_at(st, y) for y in (min(ys), (min(ys) + max(ys)) / 2, max(ys)))
    obj = f.prism(name, poly, t + lift, colour)
    return f.flat(obj) if flat else obj


def disc_plate(f, name, y, z, r, colour, st, lift=0.007, segs=24):
    d = rim_disc(f, name, y, r, th_at(st, y) + lift, colour, segs=segs)
    return f.orient(d, loc=(0, 0, z))


def stud(f, name, y, z, r, colour, st, segs=12, rings=6):
    """A pair of domes, one on each face (spheres centred on the faces)."""
    t = th_at(st, y)
    for side in (1, -1):
        f.sphere(f"{name}{side}", (side * t, y, z), r, colour, segs=segs, rings=rings)


def hole(f, target, name, y, z, r, colour, segs=24, scale=(1, 1, 1)):
    c = through_cutter(f, name, 0, 0, r, colour, segs=segs)
    f.orient(c, scale=scale, loc=(0, y, z))
    f.sync_materials()
    f.cut(target, c)


def tube(f, name, pts, r, colour, segs=12):
    """A round tube along a path in the Y-Z plane (x = 0)."""
    rings = []
    for i, (y, z) in enumerate(pts):
        a, b = pts[max(0, i - 1)], pts[min(len(pts) - 1, i + 1)]
        dy, dz = b[0] - a[0], b[1] - a[1]
        ll = _m.hypot(dy, dz) or 1.0
        rings.append([(r * _m.cos(2 * _m.pi * k / segs), y - dz / ll * r * _m.sin(2 * _m.pi * k / segs),
                       z + dy / ll * r * _m.sin(2 * _m.pi * k / segs)) for k in range(segs)])
    return f.loft(name, rings, [colour] * segs, colour)


def helix(f, name, y0, y1, turns, R, r, colour, segs=12, steps=None):
    """A tube wound round the length axis (a vine, a wire, a rope): Astra's grip-vine technique."""
    steps = steps or int(20 * turns) + 1
    rings = []
    for k in range(steps):
        a = 2 * _m.pi * turns * k / (steps - 1)
        y = y0 + (y1 - y0) * k / (steps - 1)
        rings.append([((R + r * _m.cos(b)) * _m.cos(a), y + r * _m.sin(b), (R + r * _m.cos(b)) * _m.sin(a))
                      for b in [2 * _m.pi * j / segs for j in range(segs)]])
    return f.loft(name, rings, [colour] * segs, colour)


def ellipse_helix(f, name, y0, y1, turns, R, r, colour, sx=0.5, segs=12, steps=None):
    """A helix on an elliptical path (x squeezed by sx to hug a flat blade) whose tube stays round,
    so it never picks up the bevel the way a scaled helix does."""
    steps = steps or int(14 * turns) + 1
    rings = []
    for k in range(steps):
        a = 2 * _m.pi * turns * k / (steps - 1)
        y = y0 + (y1 - y0) * k / (steps - 1)
        cx, cz = sx * R * _m.cos(a), R * _m.sin(a)
        nx, nz = _m.cos(a) / sx, _m.sin(a)
        ll = _m.hypot(nx, nz)
        nx, nz = nx / ll, nz / ll
        rings.append([(cx + r * _m.cos(b) * nx, y + r * _m.sin(b), cz + r * _m.cos(b) * nz)
                      for b in [2 * _m.pi * j / segs for j in range(segs)]])
    return f.loft(name, rings, [colour] * segs, colour)


def striped(f, name, profile, paint, segs=16, flat=False):
    """A lathe as a loft so each ring band can take its own colour: paint(i) -> colour."""
    rings = [[(r * _m.cos(a), y, r * _m.sin(a)) for a in [2 * _m.pi * j / segs for j in range(segs)]] for r, y in profile]
    obj = f.loft(name, rings, lambda i, j: paint(i), paint(0))
    return f.flat(obj) if flat else obj


def star_prism(f, name, cy, cz, points, ro, ri, half_x, colour, rot=_m.pi / 2):
    return f.prism(name, star(cy, cz, points, ro, ri, rot=rot), half_x, colour)


def ngon(cy, cz, r, n, rot=0.0):
    return [(cy + r * _m.cos(rot + 2 * _m.pi * k / n), cz + r * _m.sin(rot + 2 * _m.pi * k / n)) for k in range(n)]


def leaf(f, name, y0, z0, y1, z1, width, colour, half_x=0.014, x=0.0):
    return briar_leaf(f, name, y0, z0, y1, z1, width, colour, half_x=half_x, x=x)


def collar(f, colour, r=0.044):
    f.lathe("Collar", [(0.0, GRIP_Y0 - 0.012), (r, GRIP_Y0 - 0.012), (r, GRIP_Y0 + 0.004), (0.0, GRIP_Y0 + 0.004)], colour, segs=20)


def mirror(poly):
    """Return the outline mirrored across the length axis (z -> -z), wound the same way."""
    return [(y, -z) for y, z in poly][::-1]


def pair(f, name, poly, half_x, colour):
    """A shape and its mirror on the other side of the axis."""
    f.prism(f"{name}R", poly, half_x, colour)
    f.prism(f"{name}L", mirror(poly), half_x, colour)


def end_bar(f, colour, y0=GUARD_Y0, y1=GUARD_Y1, half_x=0.046, span=GUARD_HALF_SPAN):
    return guard_bar(f, colour, half_y=(y0, y1), half_x=half_x, span=span)


# ---- pommels (the lowest point is exactly Blender y = -0.5; a flat bottom survives the bevel)
def ball_pommel(f, colour, r=0.036, name="Pommel"):
    return f.lathe(name, [(0.012, -0.5), (r * 0.8, -0.5 + r * 0.25), (r, -0.5 + r * 0.8), (r * 0.9, -0.5 + r * 1.35),
                          (r * 0.5, -0.5 + r * 1.75), (0.0, -0.5 + r * 1.85)], colour, segs=20)


def gem_pommel(f, colour, r=0.044, segs=6, name="Gem"):
    g = f.lathe(name, [(0.0, -0.5), (r * 0.6, -0.5 + 0.014), (r, -0.5 + 0.034), (r, -0.5 + 0.048),
                       (r * 0.6, -0.5 + 0.066), (0.0, -0.5 + 0.066)], colour, segs=segs)
    return f.flat(g)


def disc_pommel(f, colour, r=0.04, half_x=0.022, name="Disc", segs=24):
    """A disc facing the side view, its lowest point on -0.5."""
    return rim_disc(f, name, -0.5 + r, r, half_x, colour, segs=segs)


def ring_pommel(f, colour, R=0.03, r=0.011, name="Ring"):
    return f.torus_yz(name, -0.5 + R + r, 0.0, R, r, colour, seg=24, tube=12)


def ring_around(f, name, y, R, r, colour, zscale=1.0, segs=28):
    """A ring round the blade (axis along the length): a lathe of a small circle at radius R."""
    prof = [(R + r * _m.cos(a), y + r * _m.sin(a)) for a in [2 * _m.pi * k / 12 for k in range(13)]]
    ring = f.lathe(name, prof, colour, segs=segs)
    if zscale != 1.0:
        f.orient(ring, scale=(1.0 / zscale * 0.6 + 0.4, 1, zscale))
    return ring


def nugget(f, name, y, r, colour, sub=1):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    bmesh.ops.scale(bm, vec=Vector((1.0, 0.8, 1.0)), verts=bm.verts)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((0, y, 0)))
    verts = [tuple(v.co) for v in bm.verts]
    faces = [tuple(v.index for v in fc.verts) for fc in bm.faces]
    bm.free()
    return f.flat(f.mesh_object(name, verts, faces, colour))
