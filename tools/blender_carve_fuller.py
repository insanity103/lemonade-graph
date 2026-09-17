"""blender_carve_fuller.py -- replace a flat decal fuller with a real carved groove (Blender).

Run:  blender --background --factory-startup --python tools/blender_carve_fuller.py -- \
          <in.glb> <out.glb> [blade=blade] [z0=0.34] [z1=0.78] [half_width=0.0065] \
          [depth=0.002] [delete=fuller_front,fuller_back]

Deletes the flat "fuller" decal objects, then boolean-subtracts a long thin ellipsoid from
each face of the blade so the fuller is an actual concave channel: it shades from the
geometry (a real groove catches light along its edges) and tapers away at both ends
instead of stopping in a hard rectangle. The cutter carries the blade's own material, so the
groove stays steel. Blender's glTF importer puts the sword's long axis on Blender Z and its
thickness on Y, so z0/z1 are positions along the blade and the cutters sit at +-Y.
Finish with tools/convert_sword_glb.py.
"""
import math
import sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
opts = dict(a.split("=", 1) for a in argv[2:])
blade_name = opts.get("blade", "blade")
z0, z1 = float(opts.get("z0", 0.34)), float(opts.get("z1", 0.78))
half_width = float(opts.get("half_width", 0.0065))
depth = float(opts.get("depth", 0.002))
delete_names = opts.get("delete", "fuller_front,fuller_back").split(",")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

objects = {o.name: o for o in bpy.data.objects}
blade = objects.get(blade_name)
if blade is None:
    sys.exit(f"no object named {blade_name!r}; have {sorted(objects)}")

for name in delete_names:
    obj = objects.get(name)
    if obj:
        bpy.data.objects.remove(obj, do_unlink=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.select_all(action="DESELECT")

# Blade thickness: half the Y extent (thickness axis after the importer's Y-up conversion).
ys = [v.co.y for v in blade.data.vertices]
half_thick = (max(ys) - min(ys)) / 2
y_mid = (max(ys) + min(ys)) / 2
before = (len(blade.data.vertices), len(blade.data.polygons))

# The groove's cross-section is the arc of an ellipse (horizontal radius half_width, vertical
# radius r) sunk `depth` into the face. r = 1.5 * depth makes the arc break the surface at
# ~0.94 * half_width, so the visible groove is about the requested width.
r = depth * 1.5
cutters = []
for side in (1, -1):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=1.0)
    cutter = bpy.context.active_object
    cutter.name = f"fuller_cutter_{'front' if side > 0 else 'back'}"
    cutter.scale = (half_width, r, (z1 - z0) / 2)
    cutter.location = (0.0, y_mid + side * (half_thick + r - depth), (z0 + z1) / 2)
    if blade.data.materials:
        cutter.data.materials.append(blade.data.materials[0])
    cutters.append(cutter)

bpy.ops.object.select_all(action="DESELECT")
for cutter in cutters:
    mod = blade.modifiers.new(name=f"Fuller_{cutter.name}", type="BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    bpy.context.view_layer.objects.active = blade
    blade.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
for cutter in cutters:
    bpy.data.objects.remove(cutter, do_unlink=True)

# Smooth the groove's shading without softening the blade's real edges.
bpy.context.view_layer.objects.active = blade
blade.select_set(True)
try:
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
except Exception:
    bpy.ops.object.shade_smooth()
blade.select_set(False)

after = (len(blade.data.vertices), len(blade.data.polygons))
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_apply=True,
                          export_yup=True, export_materials="EXPORT")
print(f"blade verts/faces {before} -> {after}; groove z {z0}..{z1}, half-width {half_width}, depth {depth}; wrote {dst}")
