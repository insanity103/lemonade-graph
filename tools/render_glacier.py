#!/usr/bin/env python3
# Render the Frostbound Glacier (LemonadeMap model.json parts) in Blender Cycles, for judging the
# zone against docs/map/glacier_refs without Studio. Parts only: what map_forge writes, lit by a
# sun and a sky-blue world; no Roblox atmosphere. Fine with Studio open.
#   python3 tools/render_glacier.py OUTPREFIX [view,view,...]
# writes OUTPREFIX_<view>.png for each view (all of VIEWS by default).
import json, math, os, sys
import bpy, bmesh

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lemonade-map", "LemonadeMap")
OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/glacier"
SAND = (255, 228, 164)
SEG = 16

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
verts, faces, fmat = [], [], []
mats = {}


def P(v):  # Roblox (x, y, z) -> Blender (x, -z, y)
    return (v[0], -v[2], v[1])


def mat_index(color, tr, neon):
    key = (tuple(round(c, 3) for c in color), round(tr, 2), neon)
    if key not in mats:
        m = bpy.data.materials.new(f"m{len(mats)}")
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        lin = [((c) / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4) for c in color]
        bsdf.inputs["Base Color"].default_value = (*lin, 1)
        bsdf.inputs["Roughness"].default_value = 0.6
        if neon:
            bsdf.inputs["Emission Color"].default_value = (*lin, 1)
            bsdf.inputs["Emission Strength"].default_value = 3.0
        if tr > 0.01:
            bsdf.inputs["Alpha"].default_value = max(0.05, 1 - tr)
            m.blend_method = "BLEND"
        mats[key] = (len(mats), m)
    return mats[key][0]


def add(local_verts, local_faces, size, pos, rot, mi):
    base = len(verts)
    for lv in local_verts:
        v = (lv[0] * size[0], lv[1] * size[1], lv[2] * size[2])
        w = tuple(sum(rot[i][k] * v[k] for k in range(3)) + pos[i] for i in range(3))
        verts.append(P(w))
    for f in local_faces:
        faces.append(tuple(base + i for i in f))
        fmat.append(mi)


CUBE_V = [(x / 2, y / 2, z / 2) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
CUBE_F = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
CYL_V = [(sx / 2, math.cos(2 * math.pi * k / SEG) / 2, math.sin(2 * math.pi * k / SEG) / 2) for sx in (-1, 1) for k in range(SEG)]
CYL_F = [tuple(range(SEG))[::-1], tuple(range(SEG, 2 * SEG))] + [(k, (k + 1) % SEG, SEG + (k + 1) % SEG, SEG + k) for k in range(SEG)]
SPH_V, SPH_F = [], []
R = 8
for i in range(R + 1):
    th = math.pi * i / R
    for k in range(SEG):
        ph = 2 * math.pi * k / SEG
        SPH_V.append((math.sin(th) * math.cos(ph) / 2, math.cos(th) / 2, math.sin(th) * math.sin(ph) / 2))
for i in range(R):
    for k in range(SEG):
        a, b = i * SEG + k, i * SEG + (k + 1) % SEG
        SPH_F.append((a, b, b + SEG, a + SEG))
WEDGE_V = [(-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, -0.5, 0.5), (-0.5, -0.5, 0.5), (0.5, 0.5, 0.5), (-0.5, 0.5, 0.5)]
WEDGE_F = [(0, 1, 2, 3), (3, 2, 4, 5), (0, 5, 4, 1), (0, 3, 5), (1, 4, 2)]


def walk(n, sand=False):
    cls = n.get("className")
    p = n.get("properties", {})
    if cls in ("Part", "WedgePart") and "Size" in p:
        tr = p.get("Transparency", 0)
        if tr < 0.95:
            size, cf = p["Size"], p["CFrame"]["CFrame"]
            pos, rot = cf["position"], cf["orientation"]
            color = [c / 255 for c in SAND] if sand else p["Color"]
            mi = mat_index(color, tr, p.get("Material") == "Neon")
            mesh = next((c["properties"].get("MeshType") for c in n.get("children", []) if c.get("className") == "SpecialMesh"), None)
            shape = p.get("Shape")
            if cls == "WedgePart":
                add(WEDGE_V, WEDGE_F, size, pos, rot, mi)
            elif mesh == "Sphere":
                add(SPH_V, SPH_F, size, pos, rot, mi)
            elif mesh == "Cylinder":
                add(CYL_V, CYL_F, size, pos, rot, mi)
            elif shape == "Ball":
                d = min(size)
                add(SPH_V, SPH_F, (d, d, d), pos, rot, mi)
            elif shape == "Cylinder":
                d = min(size[1], size[2])
                add(CYL_V, CYL_F, (size[0], d, d), pos, rot, mi)
            else:
                add(CUBE_V, CUBE_F, size, pos, rot, mi)
    for c in n.get("children", []):
        walk(c, sand)


for f in ["FrostboundGlacier", "Grounds_FrostboundGlacier", "Hub", "Grounds_Hub"]:
    walk(json.load(open(f"{ROOT}/{f}.model.json")))

me = bpy.data.meshes.new("map")
me.from_pydata(verts, [], faces)
for _, (i, m) in sorted(mats.items(), key=lambda kv: kv[1][0]):
    me.materials.append(m)
for poly, i in zip(me.polygons, fmat):
    poly.material_index = i
me.update()
obj = bpy.data.objects.new("map", me)
scene.collection.objects.link(obj)

world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.62, 1.0, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(50), 0, math.radians(-40))
scene.collection.objects.link(sun)

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
scene.view_settings.view_transform = "Standard"

VIEWS = {  # name: (eye, target) in Roblox coords
    "g_gate": ((-60, 26, 0), (-160, 14, 0)),
    "g_hollow": ((-112, 22, 40), (-170, 12, -20)),
    "g_ascent": ((-160, 24, 6), (-260, 22, -10)),
    "g_lake": ((-236, 34, 40), (-300, 20, -40)),
    "g_ridge": ((-340, 44, -40), (-420, 34, -110)),
    "g_bridge": ((-370, 42, -60), (-392, 32, 20)),
    "g_court": ((-360, 44, 70), (-450, 40, 36)),
    "g_aerial": ((-150, 260, 140), (-300, 10, -20)),
    "g_canyon": ((-363, 16, -9), (-445, 9, -15)),
    "g_bridge_down": ((-388, 43, -12), (-448, 8, -14)),
}
if len(sys.argv) > 2:
    VIEWS = {k: v for k, v in VIEWS.items() if k in sys.argv[2].split(",")}
for name, (eye, tgt) in VIEWS.items():
    cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
    cam.data.lens = 22
    cam.data.clip_end = 3000
    scene.collection.objects.link(cam)
    from mathutils import Vector
    e, t = Vector(P(eye)), Vector(P(tgt))
    cam.location = e
    cam.rotation_euler = (t - e).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = f"{OUT}_{name}.png"
    bpy.ops.render.render(write_still=True)
    print("wrote", scene.render.filepath, flush=True)
os._exit(0)
