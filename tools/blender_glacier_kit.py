#!/usr/bin/env python3
"""blender_glacier_kit.py -- the Frostbound Glacier's hero kit, modelled in Blender.

Run with the Blender Python module (pip install "bpy==4.2.*" numpy pillow), Studio closed:
    python3 tools/blender_glacier_kit.py [--no-preview] [--only IceCliffA,SnowFirA]
Writes assets/glacier/<Key>.glb, assets/glacier/kit.json (each mesh's size, centre, triangles) and
docs/map/glacier_kit.png (the contact sheet: every mesh beside the parts version map_forge builds
from the same spec).

The pieces themselves are described in tools/glacier_kit.py; this script only decides how each
primitive becomes geometry. What the mesh adds over the parts version:
  * cones are real cones with a rounded foot; a snow drape's lower rim scallops in and out and dips
    between the scallops, as if the snow were sliding off the tier
  * ice columns and faceted blocks are chamfered on every edge (a flat cut, not a round): the
    crystalline read, where the parts version is a plain block
  * crystals and spire tiers are hex prisms under a hex pyramid
  * balls marked lumpy wobble at low frequency (rocks, snow caps); drums marked with flutes are
    fluted like a column
  * icicles hang under cornices and capitals (the parts version skips them: dozens of tiny parts)
  * the colossus's blade is a real blade: a pointed prism
Every mesh then gets the swords' toy finish (tools/blender_boss_swords.py Forge): joined into one
object, a small rounding bevel on the remaining hard edges, smooth by angle, and one swatch-atlas
material (metallic 0, roughness 1), so Studio imports a plain MeshPart with a TextureID and nothing
baked. Glow primitives are never in the mesh: they stay Neon parts beside it.

Axes: the spec is in Roblox's frame (Y up, front toward -Z). Blender is Z-up and the glTF
exporter writes Blender (x, y, z) as glTF (x, z, -y), so a Roblox point (X, Y, Z) is built at
Blender (X, -Z, Y). Studio then turns the import 180 degrees about Y (docs/BOSS_SWORDS.md, "Studio's
axes"); MeshSlots.server.luau turns it back. The origin stays at the piece's foot: 1 GLB unit is 1
stud (the importer keeps MeshSize equal to the GLB's size).
"""
import json
import math
import pathlib
import random
import sys
import tempfile
import zlib

import bpy  # before bmesh: the bpy module registers it
import bmesh
from mathutils import Vector

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
_argv, sys.argv = sys.argv, sys.argv[:1]  # the sword script reads sys.argv on import
import blender_boss_swords as bs  # noqa: E402  (its Forge, material and helpers; never its main)
sys.argv = _argv
import glacier_kit as gk  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "glacier"
SHEET = ROOT / "docs" / "map" / "glacier_kit.png"
PREVIEW = "--no-preview" not in sys.argv
ONLY = None
for a in sys.argv[1:]:
    if a.startswith("--only"):
        ONLY = set(a.split("=", 1)[1].split(","))
BEVEL = 0.18       # studs: the rounding left on hard edges after the chamfers
TRI_LIMIT = 10000  # Roblox MeshPart


def colour_name(c):
    name = "c_%d_%d_%d" % tuple(c)
    bs.P[name] = tuple(c)
    return name


def to_blender(v):
    return (v[0], -v[2], v[1])


class KitForge(bs.Forge):
    """A Forge whose primitives take the kit's Roblox-frame primitives."""

    def place(self, name, verts, faces, colour, q, local_centre=(0.0, 0.0, 0.0)):
        """verts in the primitive's own frame (Roblox axes) around local_centre -> world -> Blender."""
        R = gk.rotation(q["r"])
        p = q["p"]
        world = []
        for v in verts:
            w = gk._apply(R, (v[0] + local_centre[0], v[1] + local_centre[1], v[2] + local_centre[2]))
            world.append(to_blender((w[0] + p[0], w[1] + p[1], w[2] + p[2])))
        obj = self.mesh_object(name, world, faces, colour_name(colour) if isinstance(colour, tuple) else
                               [colour_name(c) for c in colour])
        self.fix_normals(obj)
        return obj

    # -- geometry in the primitive's own frame --
    @staticmethod
    def ring_mesh(rings, cap_bottom=True, cap_top=True):
        """rings: lists of equal length of (x, y, z); quads between rings, fan caps."""
        m = len(rings[0])
        verts = [v for r in rings for v in r]
        faces = []
        for i in range(len(rings) - 1):
            for k in range(m):
                a, b = i * m + k, i * m + (k + 1) % m
                faces.append((a, b, b + m, a + m))
        if cap_bottom:
            faces.append(tuple(reversed(range(m))))
        if cap_top:
            base = (len(rings) - 1) * m
            faces.append(tuple(range(base, base + m)))
        return verts, faces

    def ball(self, q):
        sx, sy, sz = q["s"]
        segs = 28 if max(q["s"]) > 12 else 20
        rings_n = segs // 2
        lump = q.get("lumpy", 0.0)
        rng = random.Random(zlib.crc32((self.key + q["n"]).encode()))
        waves = [(Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized(),
                  rng.uniform(1.6, 3.2), rng.uniform(0, math.tau)) for _ in range(4)]
        rings = []
        for i in range(1, rings_n):
            th = math.pi * i / rings_n
            ring = []
            for k in range(segs):
                ph = math.tau * k / segs
                d = Vector((math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph)))
                f = 1.0 + lump * sum(math.sin(fr * d.dot(ax) * math.pi + ph0) for ax, fr, ph0 in waves) / 2
                ring.append((d.x * sx / 2 * f, d.y * sy / 2 * f, d.z * sz / 2 * f))
            rings.append(ring)
        verts, faces = self.ring_mesh(rings, cap_bottom=False, cap_top=False)
        top, bottom = len(verts), len(verts) + 1
        verts += [(0, sy / 2, 0), (0, -sy / 2, 0)]
        m = segs
        for k in range(m):
            faces.append((top, (k + 1) % m, k))
            base = (len(rings) - 1) * m
            faces.append((bottom, base + k, base + (k + 1) % m))
        return self.place(q["n"], verts, faces, q["c"], q)

    def drum(self, q):
        sx, h, sz = q["s"]
        flutes = q.get("flutes", 0)
        segs = flutes * 2 if flutes else 24
        rings = []
        for y in (0.0, h):
            ring = []
            for k in range(segs):
                a = math.tau * k / segs
                r = 1.0 if not flutes or k % 2 == 0 else 0.9
                ring.append((math.cos(a) * sx / 2 * r, y, math.sin(a) * sz / 2 * r))
            rings.append(ring)
        verts, faces = self.ring_mesh(rings)
        return self.place(q["n"], verts, faces, q["c"], q)

    def block(self, q):
        sx, sy, sz = q["s"]
        if q.get("blade"):  # a pointed blade: pentagon in X-Y, thickness along Z
            w, h, t = sx / 2, sy / 2, sz / 2
            poly = [(-w, -h), (w, -h), (w, h - sx * 0.9), (0, h), (-w, h - sx * 0.9)]
            rings = [[(x, y, -t) for x, y in poly], [(x, y, t) for x, y in poly]]
            verts, faces = self.ring_mesh(rings)
            obj = self.place(q["n"], verts, faces, q["c"], q)
        else:
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            for v in bm.verts:
                v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
            if q.get("facet"):  # a flat chamfer on every edge: cut ice, not moulded plastic
                bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(sx, sy, sz) * 0.16, segments=1,
                                affect="EDGES", profile=0.5)
            verts = [tuple(v.co) for v in bm.verts]
            faces = [tuple(v.index for v in f.verts) for f in bm.faces]
            bm.free()
            obj = self.place(q["n"], verts, faces, q["c"], q)
        return obj

    def wedge(self, q):
        sx, sy, sz = q["s"]
        v = [(-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, -0.5, 0.5), (-0.5, -0.5, 0.5), (0.5, 0.5, 0.5), (-0.5, 0.5, 0.5)]
        verts = [(a * sx, b * sy, c * sz) for a, b, c in v]
        faces = [(0, 1, 2, 3), (3, 2, 4, 5), (0, 5, 4, 1), (0, 3, 5), (1, 4, 2)]
        return self.place(q["n"], verts, faces, q["c"], q)

    def cone(self, q):
        sx, h, sz = q["s"]
        top = q.get("top", 0.1)
        scallop = q.get("scallop", 0)
        segs = 40 if scallop else 28
        # profile (radius fraction, height fraction): a rounded foot, a straight flank, a round shoulder
        prof = [(0.0, 0.0), (0.9, 0.0), (1.0, 0.05), (0.97, 0.12), (0.5 + 0.47 * (1 - 0.35), 0.45),
                (top + (1 - top) * 0.28, 0.8), (top * 1.1, 0.97), (top * 0.5, 1.0)]
        rings = []
        for r_f, y_f in prof:
            ring = []
            for k in range(segs):
                a = math.tau * k / segs
                rr, yy = r_f, y_f * h
                if scallop and y_f <= 0.12:  # the drape's rim: bulges out and dips down at each scallop
                    wave = 0.5 + 0.5 * math.cos(scallop * a)
                    rr *= 1.0 + 0.07 * wave
                    yy -= h * 0.16 * wave
                ring.append((math.cos(a) * sx / 2 * rr, yy, math.sin(a) * sz / 2 * rr))
            rings.append(ring)
        verts, faces = self.ring_mesh(rings[1:], cap_bottom=True, cap_top=True)
        return self.place(q["n"], verts, faces, q["c"], q)

    def shard(self, q):
        w, h, _ = q["s"]
        tip = (0.3 if q.get("flat") else 0.5) * w
        r = w / 2 / math.cos(math.pi / 6)  # hex across flats = w
        hexa = [(math.cos(math.pi / 3 * k + math.pi / 6) * r, math.sin(math.pi / 3 * k + math.pi / 6) * r) for k in range(6)]
        t = q.get("taper", 1.0)
        rings = [[(x, 0.0, z) for x, z in hexa], [(x * t, h - tip, z * t) for x, z in hexa]]
        verts, faces = self.ring_mesh(rings, cap_top=False)
        apex = len(verts)
        verts.append((0.0, h + 0.1 * w, 0.0))
        for k in range(6):
            faces.append((6 + k, 6 + (k + 1) % 6, apex))
        return self.place(q["n"], verts, faces, q["c"], q)

    def icicle(self, q):
        d, length, _ = q["s"]
        segs = 8
        rings = [[(math.cos(math.tau * k / segs) * d / 2, 0.0, math.sin(math.tau * k / segs) * d / 2) for k in range(segs)],
                 [(math.cos(math.tau * k / segs) * d * 0.3, -length * 0.55, math.sin(math.tau * k / segs) * d * 0.3)
                  for k in range(segs)]]
        verts, faces = self.ring_mesh(rings, cap_top=False, cap_bottom=True)
        apex = len(verts)
        verts.append((0.0, -length, 0.0))
        for k in range(segs):
            faces.append((segs + k, segs + (k + 1) % segs, apex))
        return self.place(q["n"], verts, faces, q["c"], q)

    # -- finish: the swords' toy finish, without their length normalisation --
    def finish_piece(self, name):
        self.sync_materials()
        bpy.ops.object.select_all(action="DESELECT")
        for o in self.parts:
            o.select_set(True)
        bpy.context.view_layer.objects.active = self.parts[0]
        bpy.ops.object.join()
        obj = bpy.context.active_object
        obj.name = obj.data.name = name
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=1e-5)
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        bev = obj.modifiers.new("Toy", "BEVEL")
        bev.width, bev.segments, bev.profile = BEVEL, 2, 0.7
        bev.limit_method, bev.angle_limit = "ANGLE", math.radians(40)
        bev.use_clamp_overlap = True
        bpy.ops.object.modifier_apply(modifier=bev.name)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(38))
        mesh = obj.data
        while len(mesh.uv_layers) > 1:
            mesh.uv_layers.remove(mesh.uv_layers[-1])
        uv = mesh.uv_layers[0] if mesh.uv_layers else mesh.uv_layers.new(name="UVMap")
        uv.active = uv.active_render = True
        n = len(self.slots)
        for poly in mesh.polygons:
            u = (poly.material_index + 0.5) / n
            for li in poly.loop_indices:
                uv.data[li].uv = (u, 0.5)
        return obj


def build_mesh(key, prims):
    f = KitForge(key)
    for q in prims:
        if q.get("glow"):
            continue
        getattr(f, q["k"])(q)
    obj = f.finish_piece(key)
    return f, obj


def measure(obj):
    """Size and centre in Roblox axes (studs), triangles, vertices."""
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    # Blender (x, y, z) = Roblox (X, -Z, Y)
    size = (max(xs) - min(xs), max(zs) - min(zs), max(ys) - min(ys))
    centre = ((max(xs) + min(xs)) / 2, (max(zs) + min(zs)) / 2, -(max(ys) + min(ys)) / 2)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    return size, centre, tris, len(obj.data.vertices)


def parts_object(key, prims, offset):
    """The map_forge parts version, for the side-by-side preview (no bevel: parts have none)."""
    mats = {}
    verts, faces, fmat = [], [], []
    cube = [(x / 2, y / 2, z / 2) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    cube_f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    seg = 20
    cyl_v = [(sx / 2, math.cos(math.tau * k / seg) / 2, math.sin(math.tau * k / seg) / 2) for sx in (-1, 1) for k in range(seg)]
    cyl_f = [tuple(range(seg))[::-1], tuple(range(seg, 2 * seg))] + [(k, (k + 1) % seg, seg + (k + 1) % seg, seg + k) for k in range(seg)]
    sph_v, sph_f = [], []
    rn = 10
    for i in range(rn + 1):
        th = math.pi * i / rn
        for k in range(seg):
            ph = math.tau * k / seg
            sph_v.append((math.sin(th) * math.cos(ph) / 2, math.cos(th) / 2, math.sin(th) * math.sin(ph) / 2))
    for i in range(rn):
        for k in range(seg):
            a, b = i * seg + k, i * seg + (k + 1) % seg
            sph_f.append((a, b, b + seg, a + seg))
    wedge_v = [(-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, -0.5, 0.5), (-0.5, -0.5, 0.5), (0.5, 0.5, 0.5), (-0.5, 0.5, 0.5)]
    wedge_f = [(0, 1, 2, 3), (3, 2, 4, 5), (0, 5, 4, 1), (0, 3, 5), (1, 4, 2)]
    shapes = {"block": (cube, cube_f), "ball": (sph_v, sph_f), "cyl": (cyl_v, cyl_f), "wedge": (wedge_v, wedge_f)}
    for pt in gk.lofi(prims):
        lv, lf = shapes[pt["kind"]]
        key_c = (pt["color"], pt["glow"])
        if key_c not in mats:
            m = bpy.data.materials.new(f"p{len(mats)}")
            m.use_nodes = True
            bsdf = m.node_tree.nodes["Principled BSDF"]
            lin = [((c / 255) / 12.92 if c / 255 <= 0.04045 else ((c / 255 + 0.055) / 1.055) ** 2.4) for c in pt["color"]]
            bsdf.inputs["Base Color"].default_value = (*lin, 1)
            bsdf.inputs["Roughness"].default_value = 1.0
            if pt["glow"]:
                bsdf.inputs["Emission Color"].default_value = (*lin, 1)
                bsdf.inputs["Emission Strength"].default_value = 2.0
            mats[key_c] = (len(mats), m)
        base = len(verts)
        s = pt["size"]
        for v in lv:
            w = gk._apply(pt["rot"], (v[0] * s[0], v[1] * s[1], v[2] * s[2]))
            verts.append(to_blender((w[0] + pt["pos"][0] + offset[0], w[1] + pt["pos"][1] + offset[1],
                                     w[2] + pt["pos"][2] + offset[2])))
        for f in lf:
            faces.append(tuple(base + i for i in f))
            fmat.append(mats[key_c][0])
    me = bpy.data.meshes.new(key + "_parts")
    me.from_pydata(verts, [], faces)
    for _, (i, m) in sorted(mats.items(), key=lambda kv: kv[1][0]):
        me.materials.append(m)
    for poly, i in zip(me.polygons, fmat):
        poly.material_index = i
        poly.use_smooth = False
    me.update()
    obj = bpy.data.objects.new(key + "_parts", me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def glow_object(key, prims):
    """The glow primitives beside the mesh, as they will stand in the game (Neon parts)."""
    glows = [q for q in prims if q.get("glow")]
    if not glows:
        return None
    return parts_object(key + "_glow", glows, (0, 0, 0))


def render_pair(key, prims, obj, size, centre, path):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputWorld")
    light_bg = nodes.new("ShaderNodeBackground")
    light_bg.inputs["Color"].default_value = (0.86, 0.9, 1.0, 1.0)
    light_bg.inputs["Strength"].default_value = 0.8
    cam_bg = nodes.new("ShaderNodeBackground")
    cam_bg.inputs["Color"].default_value = (0.13, 0.46, 1.0, 1.0)
    mix = nodes.new("ShaderNodeMixShader")
    lp = nodes.new("ShaderNodeLightPath")
    links.new(lp.outputs["Is Camera Ray"], mix.inputs["Fac"])
    links.new(light_bg.outputs["Background"], mix.inputs[1])
    links.new(cam_bg.outputs["Background"], mix.inputs[2])
    links.new(mix.outputs["Shader"], out.inputs["Surface"])

    # the mesh's material: the atlas, as Studio will show it
    gap = max(size[0], size[2]) * 0.3 + 4
    glow_object(key, prims)
    parts_object(key, prims, (-(size[0] + gap), 0, 0))  # the view mirrors X: parts land on the right
    ground = bpy.data.meshes.new("ground")
    span = (size[0] * 2 + gap) * 1.6 + 40
    cx = -(size[0] + gap) / 2
    ground.from_pydata([to_blender((cx - span, -0.05, -span)), to_blender((cx + span, -0.05, -span)),
                        to_blender((cx + span, -0.05, span)), to_blender((cx - span, -0.05, span))], [], [(0, 1, 2, 3)])
    gm = bpy.data.materials.new("snowground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.9, 0.94, 1.0, 1)
    ground.materials.append(gm)
    gobj = bpy.data.objects.new("ground", ground)
    scene.collection.objects.link(gobj)

    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(10)
    scene.collection.objects.link(sun)
    bs.look_at(sun, (-0.6, -1.0, 1.2), up=(0, 0, 1))
    sun.location = (0, 0, 0)
    # look at the pair from the front-left and above (the pieces' fronts face Roblox -Z = Blender +Y)
    tgt = Vector(to_blender((cx, size[1] * 0.45, 0)))
    dist = max(size[0] * 2 + gap, size[1] * 1.5) * 1.25 + 10
    eye = tgt + Vector((-0.35, 1.0, 0.45)).normalized() * dist
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 50
    cam.data.clip_end = 5000
    scene.collection.objects.link(cam)
    bs.look_at(cam, tuple(eye), tuple(tgt), up=(0, 0, 1))
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = 720, 460
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def contact_sheet(rows, path):
    from PIL import Image, ImageDraw, ImageFont
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 20)
        small = ImageFont.truetype("DejaVuSans.ttf", 14)
    except OSError:
        font = small = ImageFont.load_default()
    per_row, gap, head = 4, 16, 56
    tiles = [(r, Image.open(r["img"])) for r in rows]
    tw, th = tiles[0][1].size
    n_rows = (len(tiles) + per_row - 1) // per_row
    W = gap + per_row * (tw + gap)
    H = 70 + n_rows * (th + head + gap)
    sheet = Image.new("RGB", (W, H), (236, 244, 255))
    dr = ImageDraw.Draw(sheet)
    dr.text((gap, 18), "Frostbound Glacier kit: Blender mesh (left) beside the map_forge parts version (right)",
            fill=(40, 72, 208), font=font)
    for i, (r, img) in enumerate(tiles):
        x = gap + (i % per_row) * (tw + gap)
        y = 70 + (i // per_row) * (th + head + gap)
        dr.text((x, y + 4), r["key"], fill=(24, 40, 120), font=font)
        dr.text((x, y + 30), f"{r['size'][0]:.0f} x {r['size'][1]:.0f} x {r['size'][2]:.0f} studs, {r['tris']} tris",
                fill=(60, 80, 150), font=small)
        sheet.paste(img, (x, y + head))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="glacier_kit_"))
    manifest_path = OUT / "kit.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    rows = []
    for key in gk.KEYS:
        if ONLY and key not in ONLY:
            continue
        prims = gk.build(key)
        forge, obj = build_mesh(key, prims)
        size, centre, tris, verts = measure(obj)
        if tris > TRI_LIMIT:
            raise SystemExit(f"{key}: {tris} triangles (limit {TRI_LIMIT})")
        atlas = tmp / f"{key}_atlas.png"
        forge.material(obj, atlas)
        glb = OUT / f"{key}.glb"
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", export_yup=True, export_materials="EXPORT",
                                  export_image_format="AUTO", use_selection=True, export_apply=True)
        gm = bs.read_glb_material(glb)
        assert gm["materials"] == 1 and gm["meshes"] == 1 and gm["images"] == 1, gm
        assert gm["metallic"] == 0.0 and gm["roughness"] == 1.0, gm
        manifest[key] = {"file": glb.name, "size": [round(v, 3) for v in size], "centre": [round(v, 3) for v in centre],
                         "triangles": tris, "vertices": verts,
                         "glows": [q["n"] for q in prims if q.get("glow")]}
        print(f"{key:20s} tris={tris:5d} size=({size[0]:6.1f}, {size[1]:6.1f}, {size[2]:6.1f}) "
              f"centre=({centre[0]:5.1f}, {centre[1]:5.1f}, {centre[2]:5.1f}) {glb.stat().st_size / 1024:.0f} KB", flush=True)
        if PREVIEW:
            img = tmp / f"{key}.png"
            render_pair(key, prims, obj, size, centre, img)
            rows.append({"key": key, "img": img, "size": size, "tris": tris})
    manifest_path.write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n")
    if rows:
        contact_sheet(rows, SHEET)
        print(f"wrote {SHEET.relative_to(ROOT)}")
    print(f"wrote {len(manifest)} pieces to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
