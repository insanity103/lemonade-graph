"""Blender-side geometry/placement and actual GLB round-trip validation.

Run with the authored .blend open. This creates a fresh temporary scene for the
round trip and never saves the checked scene over the source .blend.
"""
import json
import math
from pathlib import Path
import struct
import sys
import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets'/'map_redesign'
contract=json.loads((OUT/'anchors.json').read_text())
manifest=json.loads((OUT/'manifest.json').read_text())
issues=[];stats={};checks=[]

def check(condition,description):
    checks.append(dict(check=description,passed=bool(condition)))
    if not condition:issues.append(description)

def pos(p):return Vector((p[0],-p[2],p[1]))

meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and not o.name.startswith('Kit_')]
stats['mesh_count']=len(meshes)
stats['triangles']=sum(len(o.data.polygons) for o in meshes)
stats['max_mesh_triangles']=max(len(o.data.polygons) for o in meshes)
check(stats['max_mesh_triangles']<=20000,'Every individual mesh is at or below 20000 triangles')
check(all(len(p.vertices)==3 for o in meshes for p in o.data.polygons),'All exported polygons are triangles')
check(all(math.isfinite(c) for o in meshes for v in o.data.vertices for c in v.co),'No nonfinite vertex coordinates')
nonmanifold=[]
for o in meshes:
    bm=bmesh.new();bm.from_mesh(o.data)
    # Independent solids may meet at a surface; do not weld separate components.
    bad=sum(not e.is_manifold for e in bm.edges)
    if bad:nonmanifold.append(dict(mesh=o.name,edges=bad))
    bm.free()
stats['nonmanifold_meshes']=nonmanifold
check(not nonmanifold,'All mesh components have closed manifold surfaces')

check(len(contract['Branches'])==5,'Exactly five branches leave the hub')
check(len(contract['Zones'])==8,'Five main and three secondary arenas preserve eight zone IDs')
check(contract['Hub']['Radius']==180,'Hub is a 360-stud diameter circle')
all_spawns=contract['FieldSpawns']+[s for z in contract['Zones'] for s in z['Spawns']]
distance=min(math.hypot(s['Position'][0],s['Position'][2]) for s in all_spawns)
stats['closest_enemy_to_hub_center']=round(distance,3)
stats['enemy_anchor_count']=len(all_spawns)
check(distance-85>contract['Hub']['SafeRadius'],'Even the largest existing 85-stud leash cannot reach the safe hub')
check(all(s['Position'][1]>=6 for s in all_spawns),'Enemy spawn anchors sit on raised regional ground')
for z in contract['Zones']:
    outward=(pos(z['Center'])-pos(z['Approach']));outward.z=0;outward.normalize()
    # RightVector of CFrame.lookAt(center, approach) is opposite map-local right.
    right=Vector((-outward.y,outward.x,0))
    for s in z['Spawns']:
        dx,dy,dz=s['LocalPosition']
        expected=pos(z['Center'])+right*dx+outward*dz+Vector((0,0,dy))
        check((expected-pos(s['Position'])).length<.002,f"{z['Name']} {s['Archetype']} local/world anchor agreement")

# One BVH includes actual visual geometry, so props blocking a route are caught.
verts=[];faces=[]
for o in meshes:
    if o.name.startswith('NPC_') or o.name.startswith('Ocean_'):continue
    start=len(verts);verts.extend(o.matrix_world@v.co for v in o.data.vertices)
    faces.extend(tuple(start+i for i in p.vertices) for p in o.data.polygons)
bvh=BVHTree.FromPolygons(verts,faces,all_triangles=True)
ground_errors=[];clearance_errors=[]
for s in all_spawns:
    p=pos(s['Position']);hit,normal,_,_=bvh.ray_cast(p+Vector((0,0,7)),Vector((0,0,-1)),12)
    if hit is None or abs(hit.z-p.z)>.55:ground_errors.append(s.get('Id',s['Archetype']))
    for a in range(8):
        t=a*math.tau/8;direction=Vector((math.cos(t),math.sin(t),0))
        hit,_,_,_=bvh.ray_cast(p+Vector((0,0,3)),direction,2.5)
        if hit is not None:clearance_errors.append(s.get('Id',s['Archetype']));break
stats['spawn_ground_errors']=ground_errors;stats['spawn_clearance_errors']=clearance_errors
check(not ground_errors,'All enemy anchors hit the intended floor within 0.55 studs')
check(not clearance_errors,'Every enemy anchor has 2.5 studs of horizontal body clearance')
route_errors=[];slope_max=0
for branch in contract['Branches']:
    points=[pos(p) for p in branch['Waypoints']]
    for a,b in zip(points,points[1:]):
        horizontal=math.hypot(b.x-a.x,b.y-a.y)
        slope_max=max(slope_max,math.degrees(math.atan2(abs(b.z-a.z),horizontal)))
        count=math.ceil((b-a).length/2)
        for i in range(count+1):
            p=a.lerp(b,i/count)
            hit,_,_,_=bvh.ray_cast(p+Vector((0,0,6)),Vector((0,0,-1)),10)
            if hit is None or abs(hit.z-p.z)>.6:
                route_errors.append(dict(branch=branch['Id'],point=list(p),floor=list(hit) if hit else None));break
        # A 5-stud wide corridor at chest height must stay clear along the segment.
        direction=(b-a).normalized();side=Vector((-direction.y,direction.x,0)).normalized()
        for offset in (-2.5,0,2.5):
            hit,_,_,_=bvh.ray_cast(a+side*offset+Vector((0,0,3)),direction,(b-a).length)
            if hit is not None:route_errors.append(dict(branch=branch['Id'],obstruction=list(hit)));break
stats['route_errors']=route_errors;stats['max_main_route_slope_degrees']=round(slope_max,3)
check(not route_errors,'All five hub-to-boss approach routes have continuous floors and clear 5-stud corridors')
check(slope_max<12,'No main-route ramp is steeper than 12 degrees')

# Read actual exported GLB indices, not just Blender metadata.
for entry in manifest['files']:
    path=OUT/entry['file'];data=path.read_bytes()
    magic,version,size=struct.unpack_from('<III',data)
    check(magic==0x46546c67 and version==2 and size==len(data),path.name+' valid GLB container')
    length,kind=struct.unpack_from('<II',data,12);doc=json.loads(data[20:20+length])
    tris=sum(doc['accessors'][p['indices']]['count']//3 for m in doc.get('meshes',[]) for p in m['primitives'])
    check(tris==entry['triangles'],path.name+' exported triangle count matches manifest')

original_bounds=[min((o.matrix_world@v.co)[i] for o in meshes for v in o.data.vertices) for i in range(3)]+[
    max((o.matrix_world@v.co)[i] for o in meshes for v in o.data.vertices) for i in range(3)]
scene=bpy.data.scenes.new('GLB validation only');bpy.context.window.scene=scene
bpy.ops.import_scene.gltf(filepath=str(OUT/'FivefoldSanctuary.glb'))
imported=[o for o in scene.objects if o.type=='MESH']
roundtrip_bounds=[min((o.matrix_world@v.co)[i] for o in imported for v in o.data.vertices) for i in range(3)]+[
    max((o.matrix_world@v.co)[i] for o in imported for v in o.data.vertices) for i in range(3)]
stats['roundtrip_bounds_delta']=max(abs(a-b) for a,b in zip(original_bounds,roundtrip_bounds))
check(stats['roundtrip_bounds_delta']<.01,'Full GLB reimports into Blender with matching scale, orientation and bounds')
report=dict(status='passed' if not issues else 'failed',stats=stats,checks=checks,issues=issues,
            limitations=['Roblox Studio import, collision fidelity, streaming, combat and prompts require live Studio playtesting'])
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
print('MAP_VALIDATION',json.dumps(dict(status=report['status'],issues=issues,stats=stats)),flush=True)
if issues:raise RuntimeError('Map validation failed; see assets/map_redesign/validation.json')
