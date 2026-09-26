#!/usr/bin/env python3
# Render the Frostbound Glacier (LemonadeMap model.json parts) in Blender Cycles, for judging the
# zone against docs/map/glacier_refs without Studio. Parts only: what map_forge writes, lit the way
# the game lights the Glacier: a deep dusk-blue world (ZoneAir's FROST_AIR), a low warm sun from the
# west, Neon parts glowing, and a warm point light wherever the map carries a PointLight, so the
# hamlet's windows and fires throw amber pools onto blue-shadowed snow. No Roblox atmosphere. Fine
# with Studio open.
#   python3 tools/render_glacier.py OUTPREFIX [view,view,...]
# writes OUTPREFIX_<view>.png for each view (all of VIEWS by default). QUICK=1 in the environment
# renders small and noisy for iteration.
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
lights = []  # (world pos, colour, range, brightness) for every PointLight the map carries


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
            bsdf.inputs["Emission Strength"].default_value = 6.0
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
                if c.get("className") == "PointLight":
                    lp = c.get("properties", {})
                    lights.append((P(pos), lp.get("Color", [1, 0.75, 0.25]), lp.get("Range", 16), lp.get("Brightness", 1.2)))
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
# A bright afternoon under a saturated blue sky: one strong, slightly warm sun low in the west, so
# every sunlit face goes near-white and every shaded face a deep ultramarine (the critic's ask:
# walls only read as walls with a light direction). The hamlet's Neon and lamp pools still carry.
# The sky is a gradient (deep saturated blue at the zenith, pale cyan at the horizon), and the
# world light comes from it, so shade stays cool while snow reads white.
_wn, _wl = world.node_tree.nodes, world.node_tree.links
_bg = _wn["Background"]
_bg.inputs["Strength"].default_value = 0.9
_tex = _wn.new("ShaderNodeTexCoord")
_map = _wn.new("ShaderNodeSeparateXYZ")
_ramp = _wn.new("ShaderNodeValToRGB")
_ramp.color_ramp.elements[0].position = 0.0
_ramp.color_ramp.elements[0].color = (0.62, 0.86, 1.0, 1)   # horizon: pale cyan
_ramp.color_ramp.elements[1].position = 0.55
_ramp.color_ramp.elements[1].color = (0.08, 0.32, 0.95, 1)  # zenith: deep blue
_wl.new(_tex.outputs["Generated"], _map.inputs["Vector"])
_wl.new(_map.outputs["Z"], _ramp.inputs["Fac"])
_wl.new(_ramp.outputs["Color"], _bg.inputs["Color"])
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 4.2
sun.data.color = (1.0, 0.94, 0.86)
sun.data.angle = math.radians(3)
# a sun points down its -Z; tilted (90 - elevation) about X it shines toward +Y, and -90 about Z
# turns that to shine toward +X: from the west (Roblox -X is Blender -X)
sun.rotation_euler = (math.radians(90 - 32), 0, math.radians(-90 + 35))  # west-south-west, 32 up
scene.collection.objects.link(sun)
# the map's own PointLights: warm pools on the snow at the lodge door, the fires, the string lights
for k, (pos, col, rng_, br) in enumerate(lights):
    lamp = bpy.data.lights.new(f"pl{k}", "POINT")
    lamp.energy = 80.0 * rng_ * br
    lamp.color = tuple(col[:3])
    lamp.shadow_soft_size = 1.0
    o = bpy.data.objects.new(f"pl{k}", lamp)
    o.location = pos
    scene.collection.objects.link(o)

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
if os.environ.get("QUICK"):
    scene.cycles.samples = 12
    scene.render.resolution_x, scene.render.resolution_y = 960, 540
scene.view_settings.view_transform = "Standard"
scene.view_settings.exposure = -0.15  # snow just under white; Neon and the lamp pools above it


def snowfall(cam_obj, eye, tgt, count=170, seed=7):
    """Falling snow between the camera and the houses: small pale flakes scattered 6-40 studs ahead
    of the eye, inside its view. Returns the object, to delete after the view is rendered."""
    import random as _r
    from mathutils import Matrix, Vector
    rnd = _r.Random(seed)
    e, t = Vector(P(eye)), Vector(P(tgt))
    f = (t - e).normalized()
    up = Vector((0, 0, 1))
    right = f.cross(up).normalized()
    up2 = right.cross(f).normalized()
    bm = bmesh.new()
    for _ in range(count):
        d = rnd.uniform(6, 40)
        w = d * 0.9  # a little wider than the 18 mm lens' half-width
        c = e + f * d + right * rnd.uniform(-w, w) + up2 * rnd.uniform(-w * 0.6, w * 0.6)
        r = rnd.uniform(0.05, 0.11) * (d / 12) ** 0.5
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r, matrix=Matrix.Translation(c))
    me_ = bpy.data.meshes.new("snow")
    bm.to_mesh(me_)
    bm.free()
    m = bpy.data.materials.new("snowflake")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.9, 0.95, 1.0, 1)
    b.inputs["Emission Color"].default_value = (0.9, 0.95, 1.0, 1)
    b.inputs["Emission Strength"].default_value = 0.25
    b.inputs["Alpha"].default_value = 0.6
    m.blend_method = "BLEND"
    me_.materials.append(m)
    o = bpy.data.objects.new("snow", me_)
    scene.collection.objects.link(o)
    return o

VIEWS = {  # name: (eye, target) in Roblox coords
    "g_gate": ((-60, 26, 0), (-160, 14, 0)),
    "g_hollow": ((-112, 22, 40), (-170, 12, -20)),
    "g_village": ((-97, 19, 5), (-172, 13, 3), 17, True),  # up the street from the gate's arch: the pond and the
    # skaters' fire lower-left, the lodge right, the ice arch and the far roofs beyond (wide lens, snow falling)
    "g_pond": ((-114, 17, 12), (-150, 11, 46)),  # from the fingerpost, across the pond and the south cabins
    "g_ceiling": ((-122, 15, 12), (-168, 34, -40)),  # from the pond's edge, up at the lodge and the ice overhead
    "g_ascent": ((-160, 24, 6), (-260, 22, -10)),
    "g_lake": ((-236, 34, 40), (-300, 20, -40)),
    "g_ridge": ((-340, 44, -40), (-420, 34, -110)),
    "g_bridge": ((-370, 42, -60), (-392, 32, 20)),
    "g_court": ((-360, 44, 70), (-450, 40, 36)),
    "g_aerial": ((-150, 260, 140), (-300, 10, -20)),
    "g_canyon": ((-363, 16, -6), (-445, 9, -12)),  # eye height at the mouth, west along the floor to the landmark and the cleft
    "g_bridge_down": ((-388, 43, -8), (-448, 8, -10)),
    "g_canyon_up": ((-360, 5, -9.5), (-440, 62, -9.5), 15),  # from the floor at the mouth, up the slot: the sky slit over the bridge, the towers and the lit landmark (wide lens)
    "g_river": ((-244, 25, -6), (-395, 88, -128)),  # eye height, the lake's east shore: along the river to the notch
    "g_skyline": ((-262, 25, 24), (-300, 110, -180)),  # from the lake's south shore, up over the fall to the range
    "g_corridor": ((-232, 25, 4), (-340, 30, -70)),  # eye height at the ascent's top: west along the river to the stair and the notch
    "g_player": ((-232, 25, 4), (-340, 30, -70), 14.6),  # the same, through the game camera's own 70-degree vertical field
}
if len(sys.argv) > 2:
    VIEWS = {k: v for k, v in VIEWS.items() if k in sys.argv[2].split(",")}
for name, spec in VIEWS.items():
    eye, tgt = spec[0], spec[1]
    cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
    cam.data.lens = spec[2] if len(spec) > 2 else 22
    cam.data.clip_end = 3000
    flakes = snowfall(cam, eye, tgt) if len(spec) > 3 and spec[3] else None
    scene.collection.objects.link(cam)
    from mathutils import Vector
    e, t = Vector(P(eye)), Vector(P(tgt))
    cam.location = e
    cam.rotation_euler = (t - e).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = f"{OUT}_{name}.png"
    bpy.ops.render.render(write_still=True)
    print("wrote", scene.render.filepath, flush=True)
    if flakes:
        bpy.data.objects.remove(flakes, do_unlink=True)
os._exit(0)
