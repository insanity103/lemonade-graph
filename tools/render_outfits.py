#!/usr/bin/env python3
"""Render native Roblox outfit XML in Blender, without adding decorative geometry.

blender --background --factory-startup --python tools/render_outfits.py -- INPUT OUTPUT
INPUT is a .rbxmx or directory. Optional --names substring,... --rear --size 600.
Native Part/WedgePart/SpecialMesh primitives are supported. Built-in Head meshes are
approximated by rounded boxes; Roblox material textures and physics are not simulated.
"""
import argparse
import math
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

import bpy
from mathutils import Matrix, Vector

CONVERT = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def scalar(props, name, default=None):
    node = next((p for p in props if p.get('name') == name), None)
    return node.text if node is not None else default


def vector(props, name, default=(0, 0, 0)):
    node = next((p for p in props if p.get('name') == name), None)
    return Vector(default if node is None else [float(node.findtext(a)) for a in 'XYZ'])


def linear(c):
    return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4


def material(color, kind):
    name = f'{color:06x}_{kind}'
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    rgba = tuple(linear(((color >> bit) & 255) / 255) for bit in (16, 8, 0)) + (1,)
    mat.diffuse_color = rgba
    node = mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = rgba
    node.inputs['Roughness'].default_value = .46 if kind in (1088, 1040, 1072) else .8
    node.inputs['Metallic'].default_value = .55 if kind in (1088, 1040, 1072) else 0
    if kind == 288:
        node.inputs['Emission Color'].default_value = rgba
        node.inputs['Emission Strength'].default_value = .7
    return mat


def mesh_for(item):
    p = item.find('Properties')
    if float(scalar(p, 'Transparency', '0')) >= .95:
        return None
    size = vector(p, 'size', vector(p, 'Size', (1, 1, 1)))
    shape = int(scalar(p, 'shape', '1'))
    special = item.find("Item[@class='SpecialMesh']/Properties")
    wedge = item.get('class') == 'WedgePart'
    head = False
    mesh_offset = Vector((0, 0, 0))
    if special is not None:
        mt = int(scalar(special, 'MeshType', '0'))
        wedge = wedge or mt == 2
        head = mt == 0
        if mt == 3:
            shape = 0
        scale = vector(special, 'Scale', (1, 1, 1))
        size = Vector([size[i] * scale[i] for i in range(3)])
        mesh_offset = vector(special, 'Offset')
    rotation = Matrix.Identity(3)
    if wedge:
        verts = [(-1,-1,-1), (1,-1,-1), (-1,-1,1), (1,-1,1), (-1,1,1), (1,1,1)]
        faces = [(0,1,3,2), (2,3,5,4), (0,4,5,1), (0,2,4), (1,5,3)]
        mesh = bpy.data.meshes.new('NativeWedge')
        mesh.from_pydata(verts, [], faces)
        mesh.update()
        obj = bpy.data.objects.new('NativeWedge', mesh)
        bpy.context.collection.objects.link(obj)
    elif shape == 0:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=1)
        obj = bpy.context.object
    elif shape == 2:
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=1, depth=2)
        obj = bpy.context.object
        rotation = Matrix.Rotation(math.pi / 2, 3, 'Y')
        size = Vector((size.z, size.y, size.x))
    else:
        bpy.ops.mesh.primitive_cube_add(size=2)
        obj = bpy.context.object
    obj.name = scalar(p, 'Name', 'Part')
    obj.scale = size / 2
    if head:
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        mod = obj.modifiers.new('BuiltinHeadApproximation', 'BEVEL')
        mod.width = min(size) * .19
        mod.segments = 4
    cf = p.find("CoordinateFrame[@name='CFrame']")
    pos = Vector([float(cf.findtext(a)) for a in 'XYZ'])
    rot = Matrix([[float(cf.findtext(f'R{i}{j}')) for j in range(3)] for i in range(3)])
    obj.location = CONVERT @ (pos + rot @ mesh_offset)
    obj.rotation_euler = (CONVERT @ rot @ rotation).to_euler()
    color = scalar(p, 'Color3uint8')
    if color is None:
        rgb = p.find("Color3[@name='Color']")
        color = sum(round(float(rgb.findtext(a)) * 255) << bit for a,bit in zip('RGB', (16,8,0))) if rgb is not None else 0x999999
    obj.data.materials.append(material(int(color) & 0xffffff, int(scalar(p, 'Material', '256'))))
    return obj


def point_at(obj, point):
    obj.rotation_euler = (Vector(point) - obj.location).to_track_quat('-Z', 'Y').to_euler()


def bounds(path):
    """Roblox-space (floor, top, width) of one model, matching render()'s framing."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    objects = [mesh_for(item) for item in ET.parse(path).iter('Item') if item.get('class') in ('Part','WedgePart')]
    objects = [obj for obj in objects if obj is not None]
    bpy.context.view_layer.update()
    corners = [obj.matrix_world @ Vector(c) for obj in objects for c in obj.bound_box]
    return (min(c.z for c in corners), max(c.z for c in corners),
            max(c.x for c in corners) - min(c.x for c in corners))


def render(path, out, rear=False, size=600, frame=None, yaw=18.4, lift=4.0):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    objects = [mesh_for(item) for item in ET.parse(path).iter('Item') if item.get('class') in ('Part','WedgePart')]
    objects = [obj for obj in objects if obj is not None]
    bpy.context.view_layer.update()
    corners = [obj.matrix_world @ Vector(c) for obj in objects for c in obj.bound_box]
    floor_z = min(c.z for c in corners)
    top_z = max(c.z for c in corners)
    if frame is not None:
        floor_z, top_z, forced_width = frame
    center = Vector((0, 0, (floor_z + top_z) / 2))
    height = top_z - floor_z
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 6
    scene.render.resolution_x = size
    scene.render.resolution_y = int(size * 1.15)
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.world = bpy.data.worlds.new('NeutralPreviewWorld')
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value = (.55, .59, .65, 1)
    bg.inputs['Strength'].default_value = .95
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'Medium High Contrast' if 'Medium High Contrast' in [i.name for i in scene.view_settings.bl_rna.properties['look'].enum_items] else 'None'
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,floor_z-.015))
    bpy.context.object.data.materials.append(material(0x798187, 256))
    for name, loc, energy, area in [('Key', (7,10,13), 1700, 8), ('Fill', (-7,3,7), 1000, 7), ('Rim', (2,-7,10), 1300, 5)]:
        data = bpy.data.lights.new(name, 'AREA')
        data.energy = energy
        data.shape = 'DISK'
        data.size = area
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.location = loc
        point_at(obj, center)
    data = bpy.data.cameras.new('ReviewCamera')
    camera = bpy.data.objects.new('ReviewCamera', data)
    scene.collection.objects.link(camera)
    sign = -1 if rear else 1
    # yaw is degrees off dead-front; lift is how far above the figure's middle the camera
    # sits. A near-front, near-level view is what a reference screenshot looks like, and it
    # is the view a silhouette has to survive.
    span = 16.0
    camera.location = center + Vector((span * math.sin(math.radians(yaw)) * sign,
                                       span * math.cos(math.radians(yaw)) * sign, lift))
    point_at(camera, center)
    data.type = 'ORTHO'
    width = forced_width if frame is not None else max(c.x for c in corners) - min(c.x for c in corners)
    data.ortho_scale = max(height * 1.2, width * 1.38)
    scene.camera = camera
    scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)
    print(f'OUTFIT_PREVIEW {path.name}: {len(objects)} visible parts -> {out}', flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('input', type=Path)
    ap.add_argument('output', type=Path)
    ap.add_argument('--names', default='')
    ap.add_argument('--rear', action='store_true')
    ap.add_argument('--size', type=int, default=600)
    # --uniform frames every model in the run identically, so a set of ranks can be
    # laid side by side without one of them coming out at a different scale.
    ap.add_argument('--uniform', action='store_true')
    ap.add_argument('--yaw', type=float, default=18.4)
    ap.add_argument('--lift', type=float, default=4.0)
    args = ap.parse_args(sys.argv[sys.argv.index('--') + 1:])
    args.output.mkdir(parents=True, exist_ok=True)
    paths = [args.input] if args.input.is_file() else sorted(args.input.glob('*.rbxmx'))
    if args.names:
        paths = [p for p in paths if any(n in p.stem for n in args.names.split(','))]
    assert paths, 'No models found'
    frame = None
    if args.uniform:
        measured = [bounds(path) for path in paths]
        frame = (min(m[0] for m in measured), max(m[1] for m in measured), max(m[2] for m in measured))
    for path in paths:
        render(path, args.output / (path.stem + ('_rear' if args.rear else '') + '.png'), args.rear, args.size, frame, args.yaw, args.lift)


if __name__ == '__main__':
    main()
