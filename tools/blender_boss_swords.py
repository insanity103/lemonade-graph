#!/usr/bin/env python3
"""blender_boss_swords.py -- the five boss swords and the three wardens' relics, modelled in
Blender in the game's plastic-toy cartoon language (docs/ART_DIRECTION.md, docs/BOSS_SWORDS.md).

Run with the Blender Python module (pip install "bpy==4.2.*" numpy pillow):
    python3 tools/blender_boss_swords.py [out_dir] [--no-preview] [--only Boss_Gorgon,...]
or inside a Blender install:
    blender --background --factory-startup --python tools/blender_boss_swords.py -- [out_dir]
Writes Boss_<archetype>.glb, manifest.json and preview.png (the contact sheet) to out_dir;
--keep-previews also keeps each sword's side and three-quarter renders in out_dir/previews.

What every sword obeys (the layout the game's weld maths expects; see tools/sword_forge.py,
the earlier PBR forge, and CombatUtil.SWORD_GRIP_FRAC):
  * one mesh, one material, one embedded texture -- here a flat swatch atlas, so every face is a
    solid colour and nothing is baked: no noise, no cracks, no sparkle, no metal
  * metallicFactor 0 / roughnessFactor 1 in the glTF, so Studio imports a plain MeshPart with a
    TextureID and no SurfaceAppearance; the game then forces SmoothPlastic at runtime
  * length along Z normalised to exactly 1.0, bounding box centred on the origin, blade toward
    -Z (tip z = -0.5), grip toward +Z (pommel z = +0.5); Studio's importer turns this 180 deg
    about Y and the game corrects for that already
  * identical grip layout: crossguard band z 0.195..0.255, handle z 0.255..0.46, so the hand
    sits 0.38 of the length from centre; the pommel fills z 0.46..0.50
  * width along Y, thickness along X, bounding box symmetric about the grip axis: the guard is
    the widest feature and reaches exactly +-0.13 on both sides with a flat end face (a flat
    end survives the edge bevel unchanged, a point would not)
  * under Roblox's 10,000-triangle / 21,000-vertex MeshPart limits

Blender is Z-up and the glTF exporter maps Blender +Y -> glTF -Z, so here the sword is built
along Blender Y (tip at +0.5, pommel at -0.5), width along Blender Z, thickness along X.

The cartoon rules the designs follow: few large smooth forms; a chunky blade (thick slab,
wide, rounded by a real edge bevel); a thick handle and an oversized pommel; colour as one calm
pale surface against the boss's own vivid family; every detail as carved geometry or a flat
two-tone paint split (the cutting edge is a chamfer strip painted the accent colour, a bite is a
boolean cut, a glowing core is a raised rib), never a baked material.
"""
import json
import math
import pathlib
import struct
import sys

import bpy
import bmesh
from mathutils import Vector

# ----------------------------------------------------------------------------- arguments
if "--" in sys.argv:
    ARGS = sys.argv[sys.argv.index("--") + 1:]
else:
    ARGS = sys.argv[1:]
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "swords"
PREVIEW = True
KEEP_PREVIEWS = False
ONLY = None
for a in ARGS:
    if a == "--no-preview":
        PREVIEW = False
    elif a == "--keep-previews":
        KEEP_PREVIEWS = True
    elif a.startswith("--only"):
        ONLY = set(a.split("=", 1)[1].split(",")) if "=" in a else None
    elif not a.startswith("--"):
        OUT = pathlib.Path(a)

# ----------------------------------------------------------------------------- layout (Blender Y = length)
TIP_Y, POMMEL_Y = 0.5, -0.5
GUARD_Y0, GUARD_Y1 = -0.255, -0.195   # game z 0.195..0.255
GRIP_Y0, GRIP_Y1 = -0.46, -0.255      # game z 0.255..0.46 (hand at -0.38 here)
BLADE_ROOT_Y = -0.21                  # blade root tucked inside the guard
GUARD_HALF_SPAN = 0.13
GRIP_R = 0.038                        # thick toy handle (the PBR forge used 0.020-0.022)
BEVEL_WIDTH = 0.006                   # the rounding that makes a slab read as a moulded toy
BEVEL_ANGLE = math.radians(32)

# ----------------------------------------------------------------------------- palette (sRGB)
# Shared with the enemy bodies (EnemyCombat) and outfits (EnemyOutfits) so a boss and its sword
# come out of the same toy box. One calm pale surface + the boss's vivid family per sword.
P = {
    "sky_white": (232, 240, 255), "ice_white": (236, 248, 255), "cream": (255, 240, 220),
    "lavender": (238, 226, 255), "ivory": (255, 252, 240), "cream_grip": (255, 238, 210),
    "coral": (255, 72, 72), "toy_blue": (64, 144, 255), "orange": (255, 140, 40),
    "cyan": (72, 204, 255), "deep_blue": (24, 140, 255), "white": (255, 255, 255),
    "ember_red": (255, 96, 48), "ember_yellow": (255, 224, 64),
    "violet": (124, 56, 240), "magenta": (255, 128, 255),
    "gold": (255, 200, 40), "tangerine": (255, 150, 40),
    "pale_leaf": (236, 255, 208), "lime": (120, 236, 56), "leaf": (48, 208, 88), "timber": (255, 158, 36), "bloom": (255, 236, 96),
    "mint": (224, 255, 244), "aqua": (48, 224, 176), "aqua_blue": (32, 160, 224), "lime_yellow": (190, 255, 96),
    "cloud": (236, 240, 255), "storm_blue": (88, 156, 255), "storm_gold": (255, 200, 40), "storm_deep": (40, 80, 240), "lightning": (255, 244, 96),
}


# ----------------------------------------------------------------------------- scene helpers
class Forge:
    """One sword's build: a fresh scene, a slot list (colour name -> material index shared by
    every part so a face's material_index means the same swatch after the join), and the parts."""

    def __init__(self, key):
        self.key = key
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.slots = []
        self.placeholders = []
        self.parts = []

    def slot(self, colour):
        if colour not in self.slots:
            self.slots.append(colour)
            self.placeholders.append(bpy.data.materials.new(f"slot_{colour}"))
        return self.slots.index(colour)

    def mesh_object(self, name, verts, faces, face_slots):
        """face_slots: one colour name per face, or a single colour name for every face."""
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([Vector(v) for v in verts], [], faces)
        if isinstance(face_slots, str):
            face_slots = [face_slots] * len(faces)
        idx = [self.slot(c) for c in face_slots]
        for m in self.placeholders:
            mesh.materials.append(m)
        mesh.update()
        for poly, i in zip(mesh.polygons, idx):
            poly.material_index = i
            poly.use_smooth = True
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        self.parts.append(obj)
        return obj

    def sync_materials(self):
        """Every part carries the full slot list in the same order (slots can be added after a
        part was made), so the join keeps every material_index meaning the same colour."""
        for obj in self.parts:
            for m in self.placeholders[len(obj.data.materials):]:
                obj.data.materials.append(m)

    # -- primitives (Blender coords: x thickness, y length, z width) --
    def prism(self, name, poly_yz, half_x, colour, x_centre=0.0):
        """A simple polygon in the (y, z) plane extruded symmetrically along X."""
        n = len(poly_yz)
        verts = [(x_centre + half_x, y, z) for y, z in poly_yz] + [(x_centre - half_x, y, z) for y, z in poly_yz]
        faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
        for i in range(n):
            j = (i + 1) % n
            faces.append((i, j, j + n, i + n))
        return self.mesh_object(name, verts, faces, colour)

    def lathe(self, name, profile, colour, segs=16, axis_z=0.0, axis_x=0.0):
        """Revolve an (r, y) profile around a line parallel to Y. Flat caps where r > 0."""
        rings = []
        verts = []
        for r, y in profile:
            ring = []
            for k in range(segs):
                a = 2 * math.pi * k / segs
                verts.append((axis_x + r * math.cos(a), y, axis_z + r * math.sin(a)))
                ring.append(len(verts) - 1)
            rings.append(ring)
        faces = []
        for i in range(len(rings) - 1):
            for k in range(segs):
                faces.append((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
        if profile[0][0] > 1e-6:
            faces.append(tuple(reversed(rings[0])))
        if profile[-1][0] > 1e-6:
            faces.append(tuple(rings[-1]))
        return self.mesh_object(name, verts, faces, colour)

    def torus_yz(self, name, centre_y, centre_z, R, r, colour, seg=32, tube=12):
        """A ring lying in the Y-Z plane (axis along X): reads as a ring from the side view."""
        verts, faces = [], []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            cy, cz = centre_y + R * math.cos(a), centre_z + R * math.sin(a)
            out = (math.cos(a), math.sin(a))
            for j in range(tube):
                b = 2 * math.pi * j / tube
                verts.append((r * math.sin(b), cy + r * math.cos(b) * out[0], cz + r * math.cos(b) * out[1]))
        for i in range(seg):
            for j in range(tube):
                a = i * tube + j
                b = i * tube + (j + 1) % tube
                c = ((i + 1) % seg) * tube + (j + 1) % tube
                d = ((i + 1) % seg) * tube + j
                faces.append((a, b, c, d))
        return self.mesh_object(name, verts, faces, colour)

    def sphere(self, name, centre, r, colour, segs=20, rings=12):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
        bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(centre))
        verts = [tuple(v.co) for v in bm.verts]
        faces = [tuple(v.index for v in f.verts) for f in bm.faces]
        bm.free()
        return self.mesh_object(name, verts, faces, colour)

    def loft(self, name, rings, strip_colours, cap_colour):
        """Rings: equal-length lists of (x, y, z) from root to tip. strip_colours[k] paints the
        strip between ring vertex k and k+1 along the whole loft (or a function (i, k) -> colour
        for a paint split along the length); caps close both ends."""
        m = len(rings[0])
        verts = [v for ring in rings for v in ring]
        faces, colours = [], []
        for i in range(len(rings) - 1):
            for k in range(m):
                a, b = i * m + k, i * m + (k + 1) % m
                faces.append((a, b, b + m, a + m))
                colours.append(strip_colours(i, k) if callable(strip_colours) else strip_colours[k])
        faces.append(tuple(reversed(range(m))))
        colours.append(cap_colour)
        base = (len(rings) - 1) * m
        faces.append(tuple(range(base, base + m)))
        colours.append(cap_colour)
        return self.mesh_object(name, verts, faces, colours)

    @staticmethod
    def fix_normals(obj):
        """The builders above do not promise a winding, and the exact boolean solver needs
        outward normals on both operands."""
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()

    @staticmethod
    def apply_transform(obj):
        bpy.context.view_layer.update()
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    def cut(self, target, cutter):
        """Boolean difference; the cutter's own colour paints the faces it leaves behind."""
        self.fix_normals(target)
        self.fix_normals(cutter)
        before = len(target.data.polygons)
        mod = target.modifiers.new("Cut", "BOOLEAN")
        mod.operation, mod.solver, mod.object = "DIFFERENCE", "EXACT", cutter
        bpy.context.view_layer.objects.active = target
        bpy.ops.object.modifier_apply(modifier=mod.name)
        if len(target.data.polygons) == before:
            raise SystemExit(f"{self.key}: boolean {cutter.name} into {target.name} cut nothing")
        self.parts.remove(cutter)
        bpy.data.objects.remove(cutter, do_unlink=True)

    # -- finishing --
    def finish(self, name):
        """Join, fix normals, bevel every hard edge (the toy rounding), smooth by angle, paint
        each face's swatch UV, collapse to one atlas material, normalise the layout."""
        self.sync_materials()
        bpy.ops.object.select_all(action="DESELECT")
        for o in self.parts:
            o.select_set(True)
        bpy.context.view_layer.objects.active = self.parts[0]
        bpy.ops.object.join()
        sword = bpy.context.active_object
        sword.name = name
        sword.data.name = name
        mesh = sword.data

        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=1e-6)
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode="OBJECT")

        bev = sword.modifiers.new("Toy", "BEVEL")
        bev.width, bev.segments, bev.profile = BEVEL_WIDTH, 2, 0.7
        bev.limit_method, bev.angle_limit = "ANGLE", BEVEL_ANGLE
        bev.use_clamp_overlap = True
        bev.harden_normals = False
        bpy.ops.object.modifier_apply(modifier=bev.name)
        bpy.ops.object.shade_smooth_by_angle(angle=BEVEL_ANGLE)

        # swatch UVs: every face points at the centre of its colour's cell
        while len(mesh.uv_layers) > 1:
            mesh.uv_layers.remove(mesh.uv_layers[-1])
        uv_layer = mesh.uv_layers[0] if mesh.uv_layers else mesh.uv_layers.new(name="UVMap")
        uv_layer.active = uv_layer.active_render = True
        n = len(self.slots)
        for poly in mesh.polygons:
            u = (poly.material_index + 0.5) / n
            for li in poly.loop_indices:
                uv_layer.data[li].uv = (u, 0.5)

        # normalise: bbox centred, length exactly 1.0 along Y
        bm = bmesh.new()
        bm.from_mesh(mesh)
        xs = [v.co.x for v in bm.verts]; ys = [v.co.y for v in bm.verts]; zs = [v.co.z for v in bm.verts]
        centre = Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, (max(zs) + min(zs)) / 2))
        scale = 1.0 / (max(ys) - min(ys))
        for v in bm.verts:
            v.co = (v.co - centre) * scale
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()
        return sword, {"centre_shift": [round(c, 5) for c in centre], "length_scale": round(scale, 5)}

    def material(self, sword, atlas_path):
        from PIL import Image
        cell = 64
        img = Image.new("RGB", (cell * len(self.slots), cell))
        for i, colour in enumerate(self.slots):
            img.paste(P[colour], (i * cell, 0, (i + 1) * cell, cell))
        img.save(atlas_path)
        atlas = bpy.data.images.load(str(atlas_path))
        atlas.colorspace_settings.name = "sRGB"
        atlas.pack()
        mat = bpy.data.materials.new(f"{sword.name}Mat")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = atlas
        tex.interpolation = "Closest"
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 1.0
        mesh = sword.data
        mesh.materials.clear()
        mesh.materials.append(mat)
        for poly in mesh.polygons:
            poly.material_index = 0
        mat.node_tree.nodes.active = tex
        return mat


# ----------------------------------------------------------------------------- blade builder
def blade_rings(stations, chamfer, double_edged):
    """Cross-section rings for a chunky slab blade. Station: (y, z_back, z_edge, half_thick).
    One-edged: spine at z_back (rounded by the bevel), cutting edge at z_edge as a chamfer strip
    plus a small flat -- the toy 'edge'. Double-edged: chamfers on both sides.
    Returns rings and the per-strip colour roles ('body' / 'edge')."""
    rings, roles = [], None
    for y, zb, ze, t in stations:
        w = ze - zb
        ch = min(chamfer, w * 0.42)
        f = 0.28  # the edge flat is this fraction of the thickness
        if double_edged:
            ring = [(t, y, zb + ch), (t, y, ze - ch), (f * t, y, ze), (-f * t, y, ze),
                    (-t, y, ze - ch), (-t, y, zb + ch), (-f * t, y, zb), (f * t, y, zb)]
            roles = ["body", "edge", "edge", "edge", "body", "edge", "edge", "edge"]
        else:
            ring = [(t, y, zb), (t, y, ze - ch), (f * t, y, ze), (-f * t, y, ze), (-t, y, ze - ch), (-t, y, zb)]
            roles = ["body", "edge", "edge", "edge", "body", "body"]
        rings.append(ring)
    return rings, roles


def stations_from(fn, n, y0=BLADE_ROOT_Y, y1=TIP_Y):
    """fn(y) -> (z_back, z_edge, half_thick); the last station is the tip."""
    out = []
    for i in range(n):
        y = y0 + (y1 - y0) * i / (n - 1)
        zb, ze, t = fn(y)
        out.append((y, zb, ze, t))
    return out


def lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    return a + (b - a) * t


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def chaikin(poly, iters=2):
    for _ in range(iters):
        out, n = [], len(poly)
        for i in range(n):
            p, q = poly[i], poly[(i + 1) % n]
            out.append((0.75 * p[0] + 0.25 * q[0], 0.75 * p[1] + 0.25 * q[1]))
            out.append((0.25 * p[0] + 0.75 * q[0], 0.25 * p[1] + 0.75 * q[1]))
        poly = out
    return poly


def star(cy, cz, points, r_out, r_in, rot=math.pi / 2, flat=0.0):
    """Star outline in (y, z). flat > 0 truncates the +-Z points with a flat end face."""
    out = []
    for k in range(points * 2):
        r = r_out if k % 2 == 0 else r_in
        a = rot + math.pi * k / points
        out.append((cy + r * math.cos(a), cz + r * math.sin(a)))
    return out


def grip_bands(forge, colour_grip, colour_band, bands=3, r=GRIP_R, band_r=None):
    forge.lathe("Grip", [(0.0, GRIP_Y0 - 0.002), (r, GRIP_Y0 - 0.002), (r, GRIP_Y1 + 0.002), (0.0, GRIP_Y1 + 0.002)],
                colour_grip, segs=20)
    band_r = band_r or r + 0.005
    span = GRIP_Y1 - GRIP_Y0
    for k in range(bands):
        yc = GRIP_Y0 + span * (k + 1) / (bands + 1)
        forge.lathe(f"Band{k}", [(r - 0.002, yc - 0.011), (band_r, yc - 0.011), (band_r, yc + 0.011), (r - 0.002, yc + 0.011)],
                    colour_band, segs=20)


def guard_bar(forge, colour, half_y=(GUARD_Y0, GUARD_Y1), half_x=0.045, span=GUARD_HALF_SPAN):
    """A plain bar guard with flat ends at exactly +-span."""
    y0, y1 = half_y
    return forge.prism("Guard", [(y0, -span), (y0, span), (y1, span), (y1, -span)], half_x, colour)


def prong_pair(forge, name, colour, hub_z, root_y, end_y, half_x, width):
    """Two mirrored bars from the guard hub out to flat end faces at +-GUARD_HALF_SPAN, slanted
    from root_y (at the hub) to end_y (at the tip end), `width` studs across the bar."""
    for sign in (1, -1):
        poly = [(root_y[0], hub_z), (root_y[1], hub_z), (end_y[1], GUARD_HALF_SPAN), (end_y[0], GUARD_HALF_SPAN)]
        poly = [(y, sign * z) for y, z in poly]
        if sign < 0:
            poly = poly[::-1]
        forge.prism(f"{name}{'R' if sign > 0 else 'L'}", poly, half_x, colour)


# ----------------------------------------------------------------------------- the five designs
def design_gorgon(f):
    """Warden of the Pit: a quarry cleaver. Broad squared slab with a cage-bar bite carved out of
    the spine near the tip, a riveted toy-iron guard, an orange-banded cream grip and a shackle
    ring for a pommel. Calm: the pale sky-white blade. Vivid: coral edge, toy-blue iron, rust orange."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        zb = lerp(-0.055, -0.060, smooth(t / 0.3)) if t < 0.85 else lerp(-0.060, -0.010, smooth((t - 0.85) / 0.15))
        ze = lerp(0.058, 0.108, smooth(t / 0.55)) if t < 0.92 else lerp(0.108, 0.075, smooth((t - 0.92) / 0.08))
        th = lerp(0.031, 0.024, t)
        return zb, ze, th
    rings, roles = blade_rings(stations_from(fn, 26), 0.032, False)
    colours = ["sky_white" if r == "body" else "coral" for r in roles]
    blade = f.loft("Blade", rings, colours, "sky_white")
    # the cage-bar bite: a round notch carved out of the spine near the tip (a cylinder along X)
    bite = f.lathe("Bite", [(0.0, -0.08), (0.042, -0.08), (0.042, 0.08), (0.0, 0.08)], "sky_white", segs=28)
    bite.rotation_euler = (0, 0, math.radians(90))      # lathe axis Y -> X
    bite.location = (0.0, 0.36, -0.062)
    f.apply_transform(bite)
    f.cut(blade, bite)
    guard_bar(f, "toy_blue", half_x=0.048)
    for z in (-0.085, 0.0, 0.085):
        for side in (1, -1):
            f.sphere(f"Rivet{z}{side}", (side * 0.046, (GUARD_Y0 + GUARD_Y1) / 2, z), 0.017, "orange", segs=14, rings=8)
    grip_bands(f, "cream_grip", "orange", bands=3)
    f.lathe("Collar", [(0.0, GRIP_Y0 - 0.016), (0.044, GRIP_Y0 - 0.016), (0.044, GRIP_Y0 + 0.004), (0.0, GRIP_Y0 + 0.004)], "toy_blue", segs=20)
    f.torus_yz("Shackle", POMMEL_Y + 0.044, 0.0, 0.030, 0.014, "toy_blue")
    return {"design": "Pit Warden's Cleaver", "calm": "sky_white", "vivid": ["coral", "toy_blue", "orange"]}


def design_frost(f):
    """Frost Revenant: an icicle cleaver. Pale ice slab with a swept point, three chunky icicles
    hanging off the spine, an antler guard, deep-blue grip and a cut cyan gem pommel."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        zb = lerp(-0.052, -0.060, smooth(t / 0.35)) if t < 0.72 else lerp(-0.060, 0.030, smooth((t - 0.72) / 0.28))
        ze = lerp(0.055, 0.104, smooth(t / 0.6)) if t < 0.8 else lerp(0.104, 0.048, smooth((t - 0.8) / 0.2))
        th = lerp(0.029, 0.014, t)
        return zb, ze, th
    rings, roles = blade_rings(stations_from(fn, 26), 0.032, False)
    colours = ["ice_white" if r == "body" else "cyan" for r in roles]
    f.loft("Blade", rings, colours, "ice_white")
    # icicles: fat rounded cones hanging off the spine (-Z), leaning back toward the pommel
    # (lengths keep the tips inside the guard's +-0.13: the guard must stay the widest feature)
    for i, (yc, ln) in enumerate(((0.0, 0.08), (0.15, 0.09), (0.30, 0.075))):
        prof = [(0.0, -0.01), (0.03, -0.01), (0.032, 0.014), (0.018, ln * 0.62), (0.0, ln)]
        ic = f.lathe(f"Icicle{i}", prof, "ice_white", segs=16)
        ic.rotation_euler = (math.radians(-(90 + 35)), 0, 0)   # lathe +Y -> -Z, leaning back toward the pommel
        ic.location = (0.0, yc, -0.050)
        f.apply_transform(ic)
    # antler guard: a hub and two prongs sweeping toward the blade, each with a short tine
    f.prism("Hub", [(GUARD_Y0, -0.05), (GUARD_Y0, 0.05), (GUARD_Y1 + 0.01, 0.05), (GUARD_Y1 + 0.01, -0.05)], 0.04, "deep_blue")
    prong_pair(f, "Antler", "deep_blue", 0.04, (GUARD_Y0, GUARD_Y1), (-0.205, -0.165), 0.028, 0.04)
    for sign in (1, -1):
        tine = [(-0.20, 0.085), (-0.185, 0.085), (-0.145, 0.10), (-0.16, 0.10)]
        tine = [(y, sign * z) for y, z in tine]
        f.prism(f"Tine{sign}", tine if sign > 0 else tine[::-1], 0.018, "deep_blue")
    grip_bands(f, "deep_blue", "ice_white", bands=2)
    f.lathe("Collar", [(0.0, GRIP_Y0 - 0.012), (0.044, GRIP_Y0 - 0.012), (0.044, GRIP_Y0 + 0.004), (0.0, GRIP_Y0 + 0.004)], "cyan", segs=20)
    # the gem: a six-sided cut stone, flat facets (kept flat by the smooth-by-angle threshold)
    gem = f.lathe("Gem", [(0.0, POMMEL_Y), (0.03, POMMEL_Y + 0.014), (0.05, POMMEL_Y + 0.034),
                           (0.05, POMMEL_Y + 0.048), (0.028, POMMEL_Y + 0.066), (0.0, POMMEL_Y + 0.066)], "cyan", segs=6)
    for poly in gem.data.polygons:
        poly.use_smooth = False
    return {"design": "Frostfang Cleaver", "calm": "ice_white", "vivid": ["cyan", "deep_blue"]}


def design_infernal(f):
    """Infernal Colossus: a furnace flamberge. Coral-red double-edged blade waving in three big
    lobes with an ember-yellow raised core, a cream crucible guard cupping the root, a cream grip
    with coral bands and a fat ember-yellow flame for a pommel."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.020 * math.sin(t * math.pi * 3.0) * smooth(t / 0.15) * (1 - smooth((t - 0.8) / 0.2))
        w = lerp(0.062, 0.084, smooth(t / 0.45)) if t < 0.78 else lerp(0.084, 0.016, smooth((t - 0.78) / 0.22))
        th = lerp(0.030, 0.014, t)
        return c - w, c + w, th
    st = stations_from(fn, 34)
    rings, roles = blade_rings(st, 0.026, True)
    tongue_from = int(len(st) * 0.74)   # the last quarter of the blade is the hot yellow tongue

    def paint(i, k):
        return "ember_yellow" if (roles[k] == "edge" or i >= tongue_from) else "ember_red"
    f.loft("Blade", rings, paint, "ember_yellow")
    # crucible guard: full-width bar with a bowl rising round the blade root
    bowl = [(GUARD_Y0, -GUARD_HALF_SPAN), (GUARD_Y0, GUARD_HALF_SPAN), (GUARD_Y0 + 0.04, GUARD_HALF_SPAN),
            (-0.20, 0.085), (-0.175, 0.055), (-0.16, 0.03), (-0.16, -0.03), (-0.175, -0.055), (-0.20, -0.085),
            (GUARD_Y0 + 0.04, -GUARD_HALF_SPAN)]
    f.prism("Guard", bowl, 0.042, "cream")
    grip_bands(f, "cream_grip", "ember_red", bands=3)
    f.lathe("Collar", [(0.0, GRIP_Y0 - 0.012), (0.044, GRIP_Y0 - 0.012), (0.044, GRIP_Y0 + 0.004), (0.0, GRIP_Y0 + 0.004)], "ember_red", segs=20)
    flame = chaikin([(POMMEL_Y, -0.036), (POMMEL_Y, 0.036), (POMMEL_Y + 0.035, 0.05), (POMMEL_Y + 0.065, 0.016),
                     (POMMEL_Y + 0.078, 0.0), (POMMEL_Y + 0.062, -0.026), (POMMEL_Y + 0.035, -0.05)], 2)
    ymin = min(y for y, _ in flame)
    flame = [(y - ymin + POMMEL_Y, z) for y, z in flame]
    f.prism("Flame", flame, 0.034, "ember_yellow")
    return {"design": "Inferno Edge", "calm": "cream", "vivid": ["ember_red", "ember_yellow"]}


def design_void(f):
    """Void Archon: a rift crescent. Pale lavender scimitar curving to a hooked point, a round rift
    cut clean through the blade (its inner wall hot magenta), a deep-violet spine rib and wing guard,
    a violet grip with lavender bands and a magenta orb pommel."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.050 * t * t
        w = lerp(0.056, 0.082, smooth(t / 0.55)) if t < 0.78 else lerp(0.082, 0.014, smooth((t - 0.78) / 0.22))
        th = lerp(0.028, 0.013, t)
        return c - w, c + w, th
    st = stations_from(fn, 30)
    rings, roles = blade_rings(st, 0.032, False)
    colours = ["lavender" if r == "body" else "magenta" for r in roles]
    blade = f.loft("Blade", rings, colours, "lavender")
    # the spine rib: a violet band along the back edge, proud of both faces
    rib = []
    for y, zb, ze, th in st[:-4]:
        tt = th + 0.005
        rib.append([(tt, y, zb - 0.002), (tt, y, zb + 0.024), (-tt, y, zb + 0.024), (-tt, y, zb - 0.002)])
    f.loft("Rib", rib, ["violet"] * 4, "violet")
    # the rift: a cylinder along X through the blade, its wall painted magenta by the cutter
    eye_y = 0.20
    t = (eye_y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
    eye = f.lathe("Rift", [(0.0, -0.08), (0.034, -0.08), (0.034, 0.08), (0.0, 0.08)], "magenta", segs=28)
    eye.rotation_euler = (0, 0, math.radians(90))      # lathe axis Y -> X, through the flat of the blade
    eye.location = (0.0, eye_y, 0.050 * t * t + 0.004)
    f.apply_transform(eye)
    f.cut(blade, eye)
    # wing guard: hub plus two prongs swept toward the tip, like a crescent
    f.prism("Hub", [(GUARD_Y0, -0.05), (GUARD_Y0, 0.05), (GUARD_Y1 + 0.012, 0.05), (GUARD_Y1 + 0.012, -0.05)], 0.038, "violet")
    prong_pair(f, "Wing", "violet", 0.04, (GUARD_Y0 + 0.005, GUARD_Y1 + 0.005), (-0.215, -0.172), 0.026, 0.04)
    grip_bands(f, "violet", "lavender", bands=2)
    f.lathe("Collar", [(0.0, GRIP_Y0 - 0.012), (0.044, GRIP_Y0 - 0.012), (0.044, GRIP_Y0 + 0.004), (0.0, GRIP_Y0 + 0.004)], "magenta", segs=20)
    f.sphere("Orb", (0.0, POMMEL_Y + 0.04, 0.0), 0.04, "magenta", segs=22, rings=12)
    return {"design": "Voidrend Blade", "calm": "lavender", "vivid": ["magenta", "violet"]}


def design_celestial(f):
    """Celestial Titan: a sun-halo greatsword. Ivory leaf blade with gold chamfered edges and a
    tangerine centre ridge, a big gold halo ring round the root with a tangerine eclipse disc peeking
    behind the blade, a four-point star guard, an ivory grip with gold bands and a five-point star pommel."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.050, 0.070, smooth(t / 0.3)) if t < 0.3 else (lerp(0.070, 0.092, smooth((t - 0.3) / 0.35)) if t < 0.65 else lerp(0.092, 0.012, smooth((t - 0.65) / 0.35)))
        th = lerp(0.028, 0.013, t)
        return -w, w, th
    st = stations_from(fn, 30)
    rings, roles = blade_rings(st, 0.026, True)
    colours = ["ivory" if r == "body" else "gold" for r in roles]
    f.loft("Blade", rings, colours, "ivory")
    ridge = []
    for y, zb, ze, th in st[:-4]:
        hw = min(0.014, (ze - zb) * 0.2)
        tt = th + 0.005
        ridge.append([(tt, y, -hw), (tt, y, hw), (-tt, y, hw), (-tt, y, -hw)])
    f.loft("Ridge", ridge, ["tangerine"] * 4, "tangerine")
    # the halo and the eclipse disc behind the blade
    halo_y = BLADE_ROOT_Y + 0.215
    f.torus_yz("Halo", halo_y, 0.0, 0.104, 0.014, "gold", seg=40, tube=12)
    f.lathe("Eclipse", [(0.0, -0.011), (0.086, -0.011), (0.086, 0.011), (0.0, 0.011)], "tangerine", segs=40)
    disc = f.parts[-1]
    disc.rotation_euler = (0, 0, math.radians(90))     # lathe axis Y -> X: a disc in the Y-Z plane
    disc.location = (0.0, halo_y + 0.012, 0.0)
    f.apply_transform(disc)
    # four-point star guard: long flat-ended horizontal points, short vertical ones
    gy = (GUARD_Y0 + GUARD_Y1) / 2
    guard = [(gy - 0.012, GUARD_HALF_SPAN), (gy + 0.012, GUARD_HALF_SPAN), (gy + 0.03, 0.034), (gy + 0.06, 0.0),
             (gy + 0.03, -0.034), (gy + 0.012, -GUARD_HALF_SPAN), (gy - 0.012, -GUARD_HALF_SPAN), (gy - 0.03, -0.034),
             (gy - 0.05, 0.0), (gy - 0.03, 0.034)]
    f.prism("Guard", guard, 0.036, "gold")
    grip_bands(f, "ivory", "gold", bands=3)
    f.lathe("Collar", [(0.0, GRIP_Y0 - 0.012), (0.044, GRIP_Y0 - 0.012), (0.044, GRIP_Y0 + 0.004), (0.0, GRIP_Y0 + 0.004)], "gold", segs=20)
    f.prism("Star", star(POMMEL_Y + 0.048, 0.0, 5, 0.048, 0.022, rot=-math.pi / 2), 0.034, "gold")
    return {"design": "Astral Eclipse", "calm": "ivory", "vivid": ["gold", "tangerine"]}


def design_root_warden(f):
    """Rootbound Warden (Briarwood): Grovebound Bloom. A pale-leaf leaf-shaped blade with lime
    chamfered edges and a raised leaf-green midrib, two timber thorns on the spine, a branch guard
    (two timber prongs with a stub twig each), a timber grip with pale bands and the grove heart:
    a fat six-petal yellow bloom for a pommel. Calm: pale leaf. Vivid: lime, leaf, timber, bloom."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        w = lerp(0.048, 0.066, smooth(t / 0.25)) if t < 0.25 else (lerp(0.066, 0.098, smooth((t - 0.25) / 0.35)) if t < 0.6 else lerp(0.098, 0.012, smooth((t - 0.6) / 0.4)))
        th = lerp(0.028, 0.012, t)
        return -w, w, th
    st = stations_from(fn, 30)
    rings, roles = blade_rings(st, 0.028, True)
    colours = ["pale_leaf" if r == "body" else "lime" for r in roles]
    f.loft("Blade", rings, colours, "pale_leaf")
    rib = []
    for y, zb, ze, th in st[:-4]:
        hw = min(0.013, (ze - zb) * 0.18)
        tt = th + 0.005
        rib.append([(tt, y, -hw), (tt, y, hw), (-tt, y, hw), (-tt, y, -hw)])
    f.loft("Midrib", rib, ["leaf"] * 4, "leaf")
    # two thorns curling back off the spine (-Z side), timber
    for i, yc in enumerate((0.08, 0.26)):
        w_here = fn(yc)[1]
        # short enough that the tips stay inside the guard's +-0.13 (the guard must stay widest)
        prof = [(0.0, -0.01), (0.022, -0.01), (0.024, 0.01), (0.012, 0.032), (0.0, 0.05)]
        th_ = f.lathe(f"Thorn{i}", prof, "timber", segs=14)
        th_.rotation_euler = (math.radians(-(90 + 45)), 0, 0)
        th_.location = (0.0, yc, -w_here + 0.012)
        f.apply_transform(th_)
    # branch guard: hub, two prongs, a twig stub on each
    f.prism("Hub", [(GUARD_Y0, -0.05), (GUARD_Y0, 0.05), (GUARD_Y1 + 0.01, 0.05), (GUARD_Y1 + 0.01, -0.05)], 0.04, "timber")
    prong_pair(f, "Branch", "timber", 0.04, (GUARD_Y0, GUARD_Y1), (-0.23, -0.19), 0.028, 0.04)
    for sign in (1, -1):
        twig = [(-0.215, 0.08), (-0.2, 0.08), (-0.165, 0.095), (-0.18, 0.1)]
        twig = [(y, sign * z) for y, z in twig]
        f.prism(f"Twig{sign}", twig if sign > 0 else twig[::-1], 0.016, "timber")
    grip_bands(f, "timber", "pale_leaf", bands=2)
    f.lathe("Collar", [(0.0, GRIP_Y0 - 0.012), (0.044, GRIP_Y0 - 0.012), (0.044, GRIP_Y0 + 0.004), (0.0, GRIP_Y0 + 0.004)], "leaf", segs=20)
    # the grove heart: a six-petal bloom, petals rounded, a leaf-green centre disc
    petals = chaikin(star(POMMEL_Y + 0.05, 0.0, 6, 0.05, 0.028, rot=math.pi / 2), 2)
    ymin = min(y for y, _ in petals)
    petals = [(y - ymin + POMMEL_Y, z) for y, z in petals]
    f.prism("Bloom", petals, 0.026, "bloom")
    for side in (1, -1):
        f.sphere(f"Heart{side}", (side * 0.024, POMMEL_Y + 0.05, 0.0), 0.016, "leaf", segs=14, rings=8)
    return {"design": "Grovebound Bloom", "calm": "pale_leaf", "vivid": ["lime", "leaf", "timber", "bloom"]}


def design_bellwarden(f):
    """Drowned Bellwarden (Sunken Marsh): Drowned Chime. A wide mint cutlass with an aqua cutting
    edge and a scalloped wave along the spine, a deep aqua-blue bell for a guard (a flared cup
    round the blade root, its lip the widest point), an aqua-blue grip with mint bands and a
    bell clapper pommel: a lime-yellow ball on a short stem. Calm: mint. Vivid: aqua, aqua-blue, lime-yellow."""
    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = 0.028 * t * t
        w = lerp(0.055, 0.085, smooth(t / 0.6)) if t < 0.8 else lerp(0.085, 0.014, smooth((t - 0.8) / 0.2))
        scallop = 0.008 * abs(math.sin(t * math.pi * 4)) * smooth(t / 0.15) * (1 - smooth((t - 0.75) / 0.25))
        th = lerp(0.028, 0.013, t)
        return c - w + scallop, c + w, th
    st = stations_from(fn, 34)
    rings, roles = blade_rings(st, 0.032, False)
    colours = ["mint" if r == "body" else "aqua" for r in roles]
    f.loft("Blade", rings, colours, "mint")
    # the bell: a lathe cup opening toward the blade, lip at +-0.13 (a flat ring face), on the grip axis
    # (the lip sits just past the guard band so the widest point still counts as the guard)
    bell = [(0.0, GUARD_Y0 - 0.01), (0.05, GUARD_Y0 - 0.01), (0.062, GUARD_Y0 + 0.015), (0.092, GUARD_Y1 - 0.012),
            (GUARD_HALF_SPAN, GUARD_Y1 + 0.006), (GUARD_HALF_SPAN, GUARD_Y1 + 0.028), (0.105, GUARD_Y1 + 0.028),
            (0.078, GUARD_Y1 - 0.004), (0.052, GUARD_Y0 + 0.028), (0.0, GUARD_Y0 + 0.028)]
    b = f.lathe("Bell", bell, "aqua_blue", segs=28)
    # squash the bell flat-ish in X so it stays a sword guard, not a cup wider than the blade is thick
    b.scale = (0.42, 1.0, 1.0)
    f.apply_transform(b)
    grip_bands(f, "aqua_blue", "mint", bands=2)
    f.lathe("Collar", [(0.0, GRIP_Y0 - 0.012), (0.044, GRIP_Y0 - 0.012), (0.044, GRIP_Y0 + 0.004), (0.0, GRIP_Y0 + 0.004)], "aqua", segs=20)
    f.lathe("Stem", [(0.0, POMMEL_Y + 0.04), (0.014, POMMEL_Y + 0.04), (0.014, GRIP_Y0), (0.0, GRIP_Y0)], "aqua_blue", segs=12)
    f.sphere("Clapper", (0.0, POMMEL_Y + 0.04, 0.0), 0.04, "lime_yellow", segs=22, rings=12)
    return {"design": "Drowned Chime", "calm": "mint", "vivid": ["aqua", "aqua_blue", "lime_yellow"]}


def design_tempest_warden(f):
    """Tempest Warden (Stormwatch): Thunderglass Pane. A lightning-bolt blade: a pale cloud slab
    that zigzags three times to the tip, gold chamfered edges, a deep-blue observatory-dome guard
    (a half-disc with a gold rim, its flat ends the widest point), a deep-blue grip with gold
    bands and an antenna pommel: a gold ball on a blue stem. Calm: cloud. Vivid: gold, deep blue, lightning."""
    kinks = [(0.0, 0.0), (0.22, 0.045), (0.5, -0.03), (0.78, 0.035), (1.0, 0.0)]

    def zig(t):
        for (t0, c0), (t1, c1) in zip(kinks, kinks[1:]):
            if t <= t1:
                return lerp(c0, c1, (t - t0) / (t1 - t0))
        return 0.0

    def fn(y):
        t = (y - BLADE_ROOT_Y) / (TIP_Y - BLADE_ROOT_Y)
        c = zig(t)
        w = lerp(0.055, 0.072, smooth(t / 0.3)) if t < 0.8 else lerp(0.072, 0.012, smooth((t - 0.8) / 0.2))
        th = lerp(0.028, 0.013, t)
        return c - w, c + w, th
    st = stations_from(fn, 40)
    rings, roles = blade_rings(st, 0.026, True)
    colours = ["cloud" if r == "body" else "storm_gold" for r in roles]
    f.loft("Blade", rings, colours, "cloud")
    # a lightning-yellow bolt rib down the middle, proud of both faces
    rib = []
    for y, zb, ze, th in st[:-5]:
        c, hw = (zb + ze) / 2, min(0.012, (ze - zb) * 0.16)
        tt = th + 0.005
        rib.append([(tt, y, c - hw), (tt, y, c + hw), (-tt, y, c + hw), (-tt, y, c - hw)])
    f.loft("Bolt", rib, ["lightning"] * 4, "lightning")
    # observatory dome guard: a half-disc (axis X) sitting on the guard band, flat ends at +-0.13
    dome = [(GUARD_Y0, -GUARD_HALF_SPAN), (GUARD_Y0, GUARD_HALF_SPAN), (GUARD_Y0 + 0.022, GUARD_HALF_SPAN)]
    for k in range(1, 12):
        a = math.pi * k / 12
        dome.append((GUARD_Y0 + 0.022 + 0.075 * math.sin(a), GUARD_HALF_SPAN * math.cos(a)))
    dome.append((GUARD_Y0 + 0.022, -GUARD_HALF_SPAN))
    f.prism("Dome", dome, 0.036, "storm_deep")
    rim = [(GUARD_Y0, -GUARD_HALF_SPAN), (GUARD_Y0, GUARD_HALF_SPAN), (GUARD_Y0 + 0.022, GUARD_HALF_SPAN), (GUARD_Y0 + 0.022, -GUARD_HALF_SPAN)]
    f.prism("Rim", rim, 0.04, "storm_gold")
    grip_bands(f, "storm_deep", "storm_gold", bands=2)
    f.lathe("Collar", [(0.0, GRIP_Y0 - 0.012), (0.044, GRIP_Y0 - 0.012), (0.044, GRIP_Y0 + 0.004), (0.0, GRIP_Y0 + 0.004)], "storm_gold", segs=20)
    f.lathe("Mast", [(0.0, POMMEL_Y + 0.036), (0.012, POMMEL_Y + 0.036), (0.012, GRIP_Y0), (0.0, GRIP_Y0)], "storm_deep", segs=12)
    f.sphere("Antenna", (0.0, POMMEL_Y + 0.036, 0.0), 0.036, "storm_gold", segs=20, rings=12)
    return {"design": "Thunderglass Pane", "calm": "cloud", "vivid": ["storm_gold", "storm_deep", "lightning"]}


DESIGNS = {
    "Boss_Gorgon": design_gorgon,
    "Boss_FrostRevenant": design_frost,
    "Boss_InfernalColossus": design_infernal,
    "Boss_VoidWraith": design_void,
    "Boss_CelestialTitan": design_celestial,
    # the three wardens: named elites that carry (and their zones drop) the zone Relic
    "RootWarden": design_root_warden,
    "DrownedBellwarden": design_bellwarden,
    "TempestWarden": design_tempest_warden,
}


# ----------------------------------------------------------------------------- checks + export
def check(sword):
    mesh = sword.data
    xs = [v.co.x for v in mesh.vertices]; ys = [v.co.y for v in mesh.vertices]; zs = [v.co.z for v in mesh.vertices]
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    checks = {
        "tris<=10000": tris <= 10000,
        "verts<=21000": len(mesh.vertices) <= 21000,
        "length==1": abs((max(ys) - min(ys)) - 1.0) < 1e-5,
        "tip at +0.5 (glTF z=-0.5)": abs(max(ys) - TIP_Y) < 1e-5,
        "pommel at -0.5 (glTF z=+0.5)": abs(min(ys) - POMMEL_Y) < 1e-5,
        "x symmetric": abs(max(xs) + min(xs)) < 1e-4,
        "width symmetric": abs(max(zs) + min(zs)) < 1e-4,
        "guard widest (+-0.13)": abs(max(zs) - GUARD_HALF_SPAN) < 2e-3,
        "hand on handle": GRIP_Y0 < -0.38 < GRIP_Y1,
    }
    return checks, tris, len(mesh.vertices), (max(xs) - min(xs), max(zs) - min(zs), max(ys) - min(ys))


def read_glb_material(path):
    data = path.read_bytes()
    assert data[:4] == b"glTF"
    jlen = struct.unpack_from("<I", data, 12)[0]
    j = json.loads(data[20:20 + jlen])
    mat = j["materials"][0]["pbrMetallicRoughness"]
    return {"materials": len(j["materials"]), "meshes": len(j["meshes"]), "images": len(j.get("images", [])),
            "metallic": mat.get("metallicFactor", 1.0), "roughness": mat.get("roughnessFactor", 1.0),
            "hasNormalMap": "normalTexture" in j["materials"][0],
            "hasMetalRoughMap": "metallicRoughnessTexture" in mat}


# ----------------------------------------------------------------------------- preview
def look_at(cam, location, target=(0.0, 0.0, 0.0), up=(0.0, 1.0, 0.0)):
    """Aim a camera so its view axis runs to `target` and the frame's up is world `up`
    (world +Y here: the sword's length, so the tip is at the top of the frame)."""
    from mathutils import Matrix
    cam.location = location
    forward = (Vector(target) - Vector(location)).normalized()
    right = forward.cross(Vector(up)).normalized()
    true_up = right.cross(forward)
    m = Matrix((right, true_up, -forward)).transposed()   # columns: local X, Y, -Z(view)
    cam.rotation_euler = m.to_euler()


def render_previews(sword, mat, out_side, out_three_quarter):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "Standard"   # honest colours, no filmic desaturation
    scene.render.film_transparent = False
    # World: a neutral near-white environment lights the sword (so cream stays cream and red
    # stays red), while camera rays alone see the PS99 sky blue as the backdrop.
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputWorld")
    light_bg = nodes.new("ShaderNodeBackground")
    light_bg.inputs["Color"].default_value = (0.9, 0.92, 1.0, 1.0)
    light_bg.inputs["Strength"].default_value = 0.85
    cam_bg = nodes.new("ShaderNodeBackground")
    cam_bg.inputs["Color"].default_value = (0.13, 0.46, 1.0, 1.0)   # PS99 sky, linear
    cam_bg.inputs["Strength"].default_value = 1.0
    mix = nodes.new("ShaderNodeMixShader")
    path = nodes.new("ShaderNodeLightPath")
    links.new(path.outputs["Is Camera Ray"], mix.inputs["Fac"])
    links.new(light_bg.outputs["Background"], mix.inputs[1])
    links.new(cam_bg.outputs["Background"], mix.inputs[2])
    links.new(mix.outputs["Shader"], out.inputs["Surface"])
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 2.6
    sun_data.angle = math.radians(12)
    sun = bpy.data.objects.new("Sun", sun_data)
    scene.collection.objects.link(sun)
    look_at(sun, (2.0, 1.6, -1.2))   # a sun pointing at the sword from the camera's upper left

    def shoot(path_out, location, ortho, res):
        cam_data = bpy.data.cameras.new("Cam")
        if ortho:
            cam_data.type = "ORTHO"
            cam_data.ortho_scale = 1.12
        else:
            cam_data.lens = 55
        cam = bpy.data.objects.new("Cam", cam_data)
        scene.collection.objects.link(cam)
        look_at(cam, location)
        scene.camera = cam
        scene.render.resolution_x, scene.render.resolution_y = res
        scene.render.filepath = str(path_out)
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(cam, do_unlink=True)

    # side: looking along -X at the flat of the blade, tip up
    shoot(out_side, (3.0, 0.0, 0.0), True, (440, 960))
    # three-quarter: from the front-left, above, so thickness and the carved details read
    shoot(out_three_quarter, (2.4, 0.9, -1.5), False, (520, 960))


def contact_sheet(rows, path):
    from PIL import Image, ImageDraw, ImageFont
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 22)
        small = ImageFont.truetype("DejaVuSans.ttf", 16)
    except OSError:
        font = ImageFont.load_default(size=22)
        small = ImageFont.load_default(size=16)
    tiles = []
    for r in rows:
        side = Image.open(r["side"])
        tq = Image.open(r["three_quarter"])
        tiles.append((r, side, tq))
    gap, top, chip, per_row = 28, 118, 26, 4
    tile_w = max(s.width + q.width + 12 for _, s, q in tiles)
    tile_h = max(s.height for _, s, q in tiles)
    rows_n = (len(tiles) + per_row - 1) // per_row
    W = gap + min(len(tiles), per_row) * (tile_w + gap)
    H = rows_n * (top + tile_h + 40)
    sheet = Image.new("RGB", (W, H), (96, 180, 255))
    dr = ImageDraw.Draw(sheet)
    for i, (r, s, q) in enumerate(tiles):
        x = gap + (i % per_row) * (tile_w + gap)
        y = (i // per_row) * (top + tile_h + 40)
        dr.text((x, y + 14), r["boss"], fill=(30, 33, 48), font=font)
        dr.text((x, y + 44), r["design"], fill=(30, 33, 48), font=small)
        cx = x
        for label, colour in [("body", r["body"])] + [(c, P[c]) for c in [r["calm"]] + r["vivid"]]:
            dr.rounded_rectangle((cx, y + 70, cx + chip, y + 70 + chip), radius=6, fill=colour, outline=(30, 33, 48), width=2)
            cx += chip + 8
        sheet.paste(s, (x, y + top))
        sheet.paste(q, (x + s.width + 12, y + top))
    sheet.save(path)


BOSS = {
    "Boss_Gorgon": ("Warden of the Pit", (255, 56, 88)),
    "Boss_FrostRevenant": ("Frost Revenant", (24, 140, 255)),
    "Boss_InfernalColossus": ("Infernal Colossus", (255, 80, 24)),
    "Boss_VoidWraith": ("Void Archon", (112, 32, 240)),
    "Boss_CelestialTitan": ("Celestial Titan", (255, 176, 32)),
    "RootWarden": ("Rootbound Warden", (48, 192, 56)),
    "DrownedBellwarden": ("Drowned Bellwarden", (24, 176, 144)),
    "TempestWarden": ("Tempest Warden", (48, 104, 255)),
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    import tempfile
    previews_dir = OUT / "previews" if KEEP_PREVIEWS else pathlib.Path(tempfile.mkdtemp(prefix="sword_previews_"))
    previews_dir.mkdir(exist_ok=True)
    manifest_path = OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    rows = []
    for key, build in DESIGNS.items():
        if ONLY and key not in ONLY:
            continue
        forge = Forge(key)
        info = build(forge)
        sword, norm = forge.finish(key)
        checks, tris, verts, size = check(sword)
        failed = [k for k, ok in checks.items() if not ok]
        if failed:
            raise SystemExit(f"{key}: rule check failed: {failed} (size {size})")
        atlas_path = previews_dir / f"{key}_atlas.png"
        mat = forge.material(sword, atlas_path)
        glb = OUT / f"{key}.glb"
        bpy.ops.object.select_all(action="DESELECT")
        sword.select_set(True)
        bpy.context.view_layer.objects.active = sword
        bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", export_yup=True,
                                  export_materials="EXPORT", export_image_format="AUTO", use_selection=True,
                                  export_apply=True)
        atlas_path.unlink(missing_ok=True)
        gm = read_glb_material(glb)
        assert gm["materials"] == 1 and gm["meshes"] == 1 and gm["images"] == 1, gm
        assert gm["metallic"] == 0.0 and gm["roughness"] == 1.0 and not gm["hasNormalMap"] and not gm["hasMetalRoughMap"], gm
        boss_name, body = BOSS[key]
        manifest[key] = {
            "name": info["design"], "boss": boss_name, "file": glb.name, "bytes": glb.stat().st_size,
            "triangles": int(tris), "vertices": int(verts),
            "meshSize": [round(size[0], 5), round(size[1], 5), round(size[2], 5)],
            "gripFrac": 0.38, "guardZ": [-GUARD_Y1, -GUARD_Y0], "handleZ": [-GRIP_Y1, -GRIP_Y0],
            "style": "plastic-toy: flat swatch colours, metallic 0, roughness 1, edge bevel",
            "palette": {"calm": P[info["calm"]], "vivid": [P[c] for c in info["vivid"]]},
            "normalise": norm, "checks": "all passed",
        }
        print(f"{key:23} {info['design']:22} tris={tris:5} verts={verts:5} "
              f"size=({size[0]:.3f}, {size[1]:.3f}, {size[2]:.3f}) {glb.stat().st_size / 1024:.0f} KB")
        if PREVIEW:
            side = previews_dir / f"{key}_side.png"
            tq = previews_dir / f"{key}_three_quarter.png"
            render_previews(sword, mat, side, tq)
            rows.append({"boss": boss_name, "design": info["design"], "body": body, "calm": info["calm"],
                         "vivid": info["vivid"], "side": side, "three_quarter": tq})
    manifest_path.write_text(json.dumps(manifest, indent=2))
    if PREVIEW and rows:
        contact_sheet(rows, OUT / "preview.png")
        print(f"wrote preview.png ({len(rows)} swords)")
    print(f"wrote manifest.json to {OUT}")


if __name__ == "__main__":
    main()
