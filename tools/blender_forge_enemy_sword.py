"""blender_forge_enemy_sword.py -- models the Iron Lowlands bandits' sword (Blender, headless).

Run:  blender --background --factory-startup --python tools/blender_forge_enemy_sword.py -- \
          <out.glb> [preview.png]

A crude quarry-gang falchion: a wide single-edged blade with a clipped point and a carved
fuller, a plain iron crossbar, a cord-wrapped grip and a round iron pommel. Built to the
boss-sword mesh layout the game's weld maths expects (EnemyCombat / CombatUtil): one mesh,
one material (flat colours baked into a swatch atlas), length normalised to 1.0 along Z with
the tip at z = -0.5 and the pommel at z = +0.5, bounding box centred, width along Y,
thickness along X. Import the GLB with Studio's 3D Importer, name the MeshPart
`SwordMeshTemplate` and put it in ServerStorage: every weapon-carrying enemy picks it up.

Blender is Z-up and the exporter maps Blender +Y -> glTF -Z, so here the sword is built along
Blender Y (tip at +Y), width along Blender Z, thickness along X.
"""
import math
import sys

import bpy
import bmesh
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out_path = argv[0]
preview_path = argv[1] if len(argv) > 1 else None

bpy.ops.wm.read_factory_settings(use_empty=True)

# ── Layout (pipeline units; tip +Y here, exported as -Z) ─────────────────────
TIP_Y, POMMEL_Y = 0.5, -0.5
GUARD_Y0, GUARD_Y1 = -0.255, -0.195   # crossguard band (game: z 0.195..0.255)
GRIP_Y0, GRIP_Y1 = -0.46, -0.255      # grip band (game: z 0.255..0.46), hand at -0.38
BLADE_ROOT_Y = -0.21                  # blade root tucked inside the guard
THICK = 0.009                         # blade half-thickness at the spine
GUARD_HALF_SPAN = 0.12                # under the 0.13 cap so it stays in proportion

COLOURS = {
    "iron":    (0.55, 0.56, 0.60),
    "dark":    (0.26, 0.26, 0.30),
    "leather": (0.30, 0.19, 0.12),
    "brass":   (0.62, 0.47, 0.22),
}
SLOT = {name: i for i, name in enumerate(COLOURS)}
# One placeholder material per colour, added to every part's mesh in the same order, so a
# face's material_index means the same swatch everywhere and survives the final join.
PLACEHOLDERS = [bpy.data.materials.new(f"slot_{name}") for name in COLOURS]


def new_object(name, verts, faces, material_index):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([Vector(v) for v in verts], [], faces)
    for m in PLACEHOLDERS:
        mesh.materials.append(m)
    mesh.update()
    for poly in mesh.polygons:
        poly.material_index = material_index
        poly.use_smooth = False
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def lathe(name, profile, segments, material_index, y0=0.0):
    """Revolve an (r, y) profile around the Y axis."""
    verts, faces = [], []
    for r, y in profile:
        for k in range(segments):
            a = 2 * math.pi * k / segments
            verts.append((r * math.cos(a), y + y0, r * math.sin(a)))
    rings = len(profile)
    for i in range(rings - 1):
        for k in range(segments):
            a, b = i * segments + k, i * segments + (k + 1) % segments
            c, d = a + segments, b + segments
            faces.append((a, b, d, c))
    # caps
    faces.append(tuple(range(segments))[::-1])
    faces.append(tuple(range((rings - 1) * segments, rings * segments)))
    return new_object(name, verts, faces, material_index)


# ── Blade: single-edged falchion, stations along Y ───────────────────────────
# Each station: (y, spine_half_width_z, edge_half_width_z, spine_thickness_x).
# The cutting edge is the +Z side (pinched to a sliver); the spine (-Z) keeps the thickness.
stations = [
    (BLADE_ROOT_Y, 0.040, 0.040, THICK),
    (-0.10, 0.042, 0.048, THICK),
    (0.05, 0.043, 0.056, THICK * 0.95),
    (0.20, 0.042, 0.064, THICK * 0.9),
    (0.34, 0.038, 0.070, THICK * 0.8),
    (0.43, 0.024, 0.062, THICK * 0.6),   # clipped point begins
    (TIP_Y, -0.004, 0.002, THICK * 0.2), # tip: spine and edge converge
]
verts, faces = [], []
for y, spine_w, edge_w, t in stations:
    edge_t = t * 0.12
    # 4 verts per station: spine-front, spine-back, edge-back, edge-front (x = thickness)
    verts += [(t, y, -spine_w), (-t, y, -spine_w), (-edge_t, y, edge_w), (edge_t, y, edge_w)]
for i in range(len(stations) - 1):
    b = i * 4
    for a, c in ((0, 1), (1, 2), (2, 3), (3, 0)):
        faces.append((b + a, b + c, b + c + 4, b + a + 4))
faces.append((0, 1, 2, 3))                       # root cap (inside the guard)
n = (len(stations) - 1) * 4
faces.append((n + 3, n + 2, n + 1, n + 0))       # tip cap (tiny)
blade = new_object("Blade", verts, faces, SLOT["iron"])

# ── Fuller: carve a shallow channel into both faces (real geometry, not a decal) ─
cutters = []
for side in (1, -1):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=1.0)
    cutter = bpy.context.active_object
    for m in PLACEHOLDERS:
        cutter.data.materials.append(m)
    for poly in cutter.data.polygons:
        poly.material_index = SLOT["iron"]  # the groove's new faces stay steel
    depth, r = THICK * 0.55, THICK * 0.8
    cutter.scale = (r, 0.24, 0.012)
    cutter.location = (side * (THICK + r - depth), 0.10, -0.012)
    cutters.append(cutter)
for cutter in cutters:
    mod = blade.modifiers.new("Fuller", "BOOLEAN")
    mod.operation, mod.solver, mod.object = "DIFFERENCE", "EXACT", cutter
    bpy.context.view_layer.objects.active = blade
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)
for poly in blade.data.polygons:
    poly.material_index = SLOT["iron"]

# ── Guard: plain iron bar, slightly swept toward the blade at the tips ───────
gx, gy0, gy1, gz = 0.022, GUARD_Y0, GUARD_Y1, GUARD_HALF_SPAN
guard_verts = [
    (-gx, gy0, -gz), (gx, gy0, -gz), (gx, gy0, gz), (-gx, gy0, gz),
    (-gx, gy1, -gz), (gx, gy1, -gz), (gx, gy1, gz), (-gx, gy1, gz),
]
guard_faces = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
guard = new_object("Guard", guard_verts, guard_faces, SLOT["dark"])
# collar where the blade meets the guard
lathe("Collar", [(0.0, GUARD_Y1), (0.03, GUARD_Y1), (0.03, GUARD_Y1 + 0.012), (0.0, GUARD_Y1 + 0.012)], 16, SLOT["dark"])

# ── Grip: cord wrap as a ribbed lathe, then the pommel ───────────────────────
profile = [(0.0, GRIP_Y0)]
y = GRIP_Y0
ribs = 9
step = (GRIP_Y1 - GRIP_Y0) / ribs
for k in range(ribs):
    profile += [(0.019, y + step * 0.08), (0.024, y + step * 0.5), (0.019, y + step * 0.92)]
    y += step
profile += [(0.0, GRIP_Y1)]
lathe("Grip", profile, 14, SLOT["leather"])
lathe("Pommel", [(0.0, POMMEL_Y), (0.028, POMMEL_Y), (0.036, POMMEL_Y + 0.016), (0.036, POMMEL_Y + 0.03),
                 (0.02, GRIP_Y0 + 0.002), (0.0, GRIP_Y0 + 0.002)], 16, SLOT["brass"])

# ── Join, single material with a swatch atlas ────────────────────────────────
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = blade
bpy.ops.object.join()
sword = bpy.context.active_object
sword.name = "SwordMeshTemplate"
sword.data.name = "SwordMeshTemplate"

cell = 16
atlas = bpy.data.images.new("SwordAtlas", width=cell * len(COLOURS), height=cell, alpha=False)
pixels = []
for _ in range(cell):
    for name in COLOURS:
        r, g, b = COLOURS[name]
        pixels += [r, g, b, 1.0] * cell
atlas.pixels = pixels
atlas.pack()

mat = bpy.data.materials.new("SwordMaterial")
mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = atlas
tex.interpolation = "Closest"
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Metallic"].default_value = 0.3
bsdf.inputs["Roughness"].default_value = 0.55

# Per-face UVs point at the swatch of the material slot the face was built with, then the
# whole mesh collapses onto the one atlas material.
mesh = sword.data
# The fuller cutters (UV spheres) leave a UV layer behind after the boolean; write into the
# first layer rather than adding a second one the exporter would ignore.
while len(mesh.uv_layers) > 1:
    mesh.uv_layers.remove(mesh.uv_layers[-1])
uv_layer = mesh.uv_layers[0] if mesh.uv_layers else mesh.uv_layers.new(name="UVMap")
uv_layer.active = True
uv_layer.active_render = True
count = len(COLOURS)
for poly in mesh.polygons:
    u = (poly.material_index + 0.5) / count
    for li in poly.loop_indices:
        uv_layer.data[li].uv = (u, 0.5)
mesh.materials.clear()
mesh.materials.append(mat)
for poly in mesh.polygons:
    poly.material_index = 0

# Recentre on the bounding box and confirm the length is exactly 1.0 along Y.
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

bpy.ops.object.select_all(action="DESELECT")
sword.select_set(True)
bpy.context.view_layer.objects.active = sword
try:
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(32))
except Exception:
    bpy.ops.object.shade_flat()

bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_yup=True,
                          export_materials="EXPORT", export_image_format="AUTO", use_selection=True)
print(f"tris={sum(len(p.vertices) - 2 for p in mesh.polygons)} verts={len(mesh.vertices)} wrote {out_path}")

# ── Preview render (Workbench: no GPU needed) ────────────────────────────────
if preview_path:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x, scene.render.resolution_y = 520, 1100
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("World"); scene.world = world
    world.color = (0.10, 0.10, 0.12)
    cam_data = bpy.data.cameras.new("Cam"); cam_data.type = "ORTHO"; cam_data.ortho_scale = 1.15
    cam = bpy.data.objects.new("Cam", cam_data); scene.collection.objects.link(cam)
    # Look along -X at the flat of the blade with the length (Y) running up the frame.
    cam.location = (3.0, 0.0, 0.0)
    cam.rotation_euler = (0.0, math.radians(90), 0.0)
    scene.camera = cam
    mat.node_tree.nodes.active = tex  # Workbench "TEXTURE" colouring reads the active image node
    scene.render.filepath = preview_path
    bpy.ops.render.render(write_still=True)
    print(f"preview {preview_path}")
