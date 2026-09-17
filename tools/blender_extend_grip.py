"""blender_extend_grip.py -- lengthen a sword's grip toward the pommel (Blender, headless).

Run:  blender --background --factory-startup --python tools/blender_extend_grip.py -- \
          <in.glb> <out.glb> <delta> [grip_name] [lower_names...]

Moves every object named in `lower_names` (pommel assembly, bottom collar, strap...) down the
sword's long axis by `delta`, stretches the grip mesh's bottom end down by the same amount so it
stays attached, and re-spaces any `wrap_*` rings over the longer grip. Blender's glTF importer
maps glTF +Y (this project's sword long axis) onto Blender +Z, so all of that happens along Z
and the exporter converts it back. Convert the result with tools/convert_sword_glb.py.
"""
import sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst, delta = argv[0], argv[1], float(argv[2])
grip_name = argv[3] if len(argv) > 3 else "grip"
lower_names = argv[4:] if len(argv) > 4 else [
    "pommel", "pommel_rim", "pommel_neck", "rivet", "rivet_back", "pommel_rust",
    "collar_bottom", "loose_strap",
]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

objects = {o.name: o for o in bpy.data.objects}
missing = [n for n in [grip_name] + lower_names if n not in objects]
if missing:
    sys.exit(f"missing objects: {missing}")

# Bake object transforms into the meshes so vertex edits below are in world space.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.select_all(action="DESELECT")

grip = objects[grip_name]
zs = [v.co.z for v in grip.data.vertices]
grip_top, grip_bottom = max(zs), min(zs)
height = grip_top - grip_bottom
mid = (grip_top + grip_bottom) / 2

# Stretch: everything on the bottom half of the grip cylinder drops by delta.
for v in grip.data.vertices:
    if v.co.z < mid:
        v.co.z -= delta
grip.data.update()

# Lower assembly just slides down.
for name in lower_names:
    for v in objects[name].data.vertices:
        v.co.z -= delta
    objects[name].data.update()

# Wrap rings keep their proportional spacing along the (now longer) grip.
new_height = height + delta
for name, obj in objects.items():
    if name.startswith("wrap"):
        wz = [v.co.z for v in obj.data.vertices]
        centre = (max(wz) + min(wz)) / 2
        frac = (grip_top - centre) / height
        shift = (frac * new_height) - (grip_top - centre)
        for v in obj.data.vertices:
            v.co.z -= shift
        obj.data.update()

bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_apply=True,
                          export_yup=True, export_materials="EXPORT")
print(f"grip {grip_bottom:.3f}..{grip_top:.3f} -> {grip_bottom - delta:.3f}..{grip_top:.3f}; wrote {dst}")
