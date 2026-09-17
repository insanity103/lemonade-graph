"""blender_delete_objects.py -- drop named objects from a GLB (Blender, headless).

Run:  blender --background --factory-startup --python tools/blender_delete_objects.py -- \
          <in.glb> <out.glb> <prefix> [prefix...]

Deletes every object whose name starts with one of the prefixes (e.g. `scratch scuff rust`
to strip the wear decals off a blade), then re-exports. Pair with blender_extend_grip.py and
finish with tools/convert_sword_glb.py.
"""
import sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst, prefixes = argv[0], argv[1], argv[2:]
if not prefixes:
    sys.exit("give at least one object-name prefix to delete")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

removed = []
for obj in list(bpy.data.objects):
    if obj.type == "MESH" and any(obj.name.startswith(p) for p in prefixes):
        removed.append(obj.name)
        bpy.data.objects.remove(obj, do_unlink=True)

bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_apply=True,
                          export_yup=True, export_materials="EXPORT")
print(f"removed {len(removed)}: {', '.join(sorted(removed))}; wrote {dst}")
