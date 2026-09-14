"""Build/export Fivefold Sanctuary in Blender. Run with --background --python.

No existing .blend or gameplay source is read or overwritten. All authored shapes
are solid meshes; generated files live under assets/map_redesign.
"""
import argparse
import json
import math
from pathlib import Path
import random
import sys
from collections import defaultdict

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from map_redesign_spec import REGIONS, SEED, make_contract, world

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "map_redesign"
RNG = random.Random(SEED)
BUCKETS = {}
MATERIALS = {}
COLLECTIONS = {}
GROUP = "Hub"
SERIAL = 0
COLLISION_BOXES = []
COLLISION_ROADS = []

def mat(name, color, metallic=0, emission=0):
    if name in MATERIALS:
        return MATERIALS[name]
    rgb = tuple(int(color.lstrip('#')[i:i+2],16)/255 for i in (0,2,4))
    # Colors are authored in sRGB; nodes and glTF store linear components.
    linear = tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb)
    m=bpy.data.materials.new(name); m.diffuse_color=(*linear,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*linear,1)
    p.inputs['Roughness'].default_value=.75
    p.inputs['Metallic'].default_value=metallic
    if emission:
        p.inputs['Emission Color'].default_value=(*linear,1)
        p.inputs['Emission Strength'].default_value=emission
    MATERIALS[name]=m
    return m

def mesh(name, verts, faces, material, group=None):
    global SERIAL
    group=group or GROUP
    # Spatial batches preserve streaming granularity and triangle budgets.
    cx=sum(v[0] for v in verts)/len(verts); cy=sum(v[1] for v in verts)/len(verts)
    key=(group,material.name,math.floor(cx/110),math.floor(cy/110))
    bucket=BUCKETS.setdefault(key,[[],[],[]])
    start=len(bucket[0]); bucket[0].extend(verts)
    bucket[1].extend([tuple(start+i for i in f) for f in faces]); bucket[2].append(name)
    SERIAL+=1

def box(name,p,size,m,angle=0):
    x,y,z=p; a,b,c=[s/2 for s in size]; co=math.cos(angle);si=math.sin(angle)
    v=[(x+dx*co-dy*si,y+dx*si+dy*co,z+dz) for dz in (-c,c) for dy in (-b,b) for dx in (-a,a)]
    f=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(1,3,7,5),(3,2,6,7),(2,0,4,6)]
    mesh(name,v,f,m)
    if name in {'ArenaWall','Pier','Counter','QuestTable','EliteScreen','RelicLedge'} and not GROUP.startswith('Kit_'):
        COLLISION_BOXES.append(dict(Name=name,Group=GROUP,Position=[x,z,-y],
                                   Size=[size[0],size[2],size[1]],Yaw=angle))

def cone(name,p,r1,r2,h,m,n=12):
    x,y,z=p; v=[]
    for zz,r in ((z,r1),(z+h,r2)):
        v.extend([(x+r*math.cos(i*math.tau/n),y+r*math.sin(i*math.tau/n),zz) for i in range(n)])
    f=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    f.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    mesh(name,v,f,m)

def beam(name,a,b,width,m,depth=None):
    a=Vector(a);b=Vector(b); direction=(b-a).normalized()
    u=direction.cross(Vector((0,0,1)))
    if u.length<.01:u=direction.cross(Vector((0,1,0)))
    u.normalize();u*=width/2;v=direction.cross(u).normalized()*(depth or width)/2
    verts=[tuple(p+s*u+t*v) for p in (a,b) for s,t in ((-1,-1),(1,-1),(1,1),(-1,1))]
    mesh(name,verts,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],m)

def ring(name,p,inner,outer,height,m,n=64,start=0,end=math.tau):
    x,y,z=p;v=[]
    full=abs(end-start-math.tau)<.000001
    count=n if full else n+1
    for zz in (z,z+height):
        for r in (inner,outer):
            v.extend((x+r*math.cos(start+(end-start)*i/n),y+r*math.sin(start+(end-start)*i/n),zz) for i in range(count))
    k=count;f=[]
    for i in range(n):
        j=(i+1)%count
        f.extend([(i,j,k+j,k+i),(2*k+i,3*k+i,3*k+j,2*k+j),
                  (i,2*k+i,2*k+j,j),(k+i,k+j,3*k+j,3*k+i)])
    if not full:f.extend([(0,k,3*k,2*k),(n,2*k+n,3*k+n,k+n)])
    mesh(name,v,f,m)

def rock(name,p,size,m,seed=None):
    # Bevelled icosahedral silhouette, always a closed convex solid.
    x,y,z=p;sx,sy,sz=size;n=7
    rr=random.Random(seed) if seed is not None else RNG
    v=[(x,y,z-sz*.36)]
    for zz,r in ((-.18,1),(.42,.84)):
        for i in range(n):
            t=math.tau*i/n; jitter=rr.uniform(.86,1.14)
            v.append((x+sx*.5*r*math.cos(t)*jitter,y+sy*.5*r*math.sin(t)*jitter,z+sz*zz))
    v.append((x+sx*.08,y-sy*.1,z+sz*.65));f=[]
    for i in range(n):
        j=(i+1)%n
        f.extend([(0,j+1,i+1),(i+1,j+1,n+j+1),(i+1,n+j+1,n+i+1),(n+i+1,n+j+1,2*n+1)])
    mesh(name,v,f,m)

def crystal(name,p,w,h,m,lean=0):
    x,y,z=p;n=5;v=[]
    for zz,r in ((0,.8),(h*.65,1)):
        for i in range(n):
            t=math.tau*i/n;v.append((x+math.cos(t)*w*r+lean*zz/h,y+math.sin(t)*w*r,z+zz))
    v.append((x+lean,y,z+h));f=[tuple(reversed(range(n)))]
    for i in range(n):
        j=(i+1)%n;f.extend([(i,j,n+j,n+i),(n+i,n+j,2*n)])
    mesh(name,v,f,m)

def tree(p,h,style,leaf,wood,snow=None):
    x,y,z=p
    cone('Trunk',p,h*.055,h*.032,h*.7,wood,7)
    if style=='pine':
        for lev in range(3):
            cone('PineCrown',(x,y,z+h*(.3+lev*.19)),h*(.29-lev*.055),.08,h*.44,leaf,8)
            if snow:cone('SnowCap',(x,y,z+h*(.50+lev*.19)),h*(.15-lev*.025),.08,h*.23,snow,8)
    elif style=='dead':
        for s in (-1,1):beam('BareBranch',(x,y,z+h*.5),(x+s*h*.23,y+h*.09,z+h*.86),h*.045,wood)
    else:
        for dx,dy,hh,rad in [(-.16,0,.65,.48),(.15,.06,.70,.46),(0,-.1,.9,.43)]:
            beam('Branch',(x,y,z+h*.42),(x+dx*h,y+dy*h,z+h*hh),h*.045,wood)
            rock('Canopy',(x+dx*h,y+dy*h,z+h*hh),(h*rad,h*rad,h*.34),leaf)

def label(text,p,size,m,rot=(math.pi/2,0,0),name=None):
    curve=bpy.data.curves.new('Lettering','FONT');curve.body=text;curve.align_x='CENTER';curve.align_y='CENTER'
    curve.size=size;curve.extrude=.035;curve.bevel_depth=.008;curve.resolution_u=3
    o=bpy.data.objects.new(name or text,curve);bpy.context.scene.collection.objects.link(o)
    o.location=p;o.rotation_euler=rot
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.convert(target='MESH');o=bpy.context.object
    verts=[tuple(o.matrix_world@v.co) for v in o.data.vertices]
    faces=[tuple(p.vertices) for p in o.data.polygons]
    mesh(name or text,verts,faces,m)
    bpy.data.objects.remove(o,do_unlink=True)

def bp(r,x,d,y=None):
    X,Y,Z=world(r,x,d,y);return (X,-Z,Y)

def local_box(r,name,x,d,z,size,m):
    box(name,bp(r,x,d,z),size,m,-math.radians(r['angle']))

def road(name,a,b,width,m,thickness=1):
    a=Vector(a);b=Vector(b);v=Vector((b.x-a.x,b.y-a.y,0)).normalized()
    side=Vector((-v.y,v.x,0))*width/2
    verts=[tuple(p+s*side+Vector((0,0,d))) for d in (-thickness,0) for p in (a,b) for s in (-1,1)]
    mesh(name,verts,[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)],m)
    if name not in {'RadialInlay','BridgeJoint','LavaFissure'}:
        COLLISION_ROADS.append(dict(Name=name,Group=GROUP,A=[a.x,a.z,-a.y],B=[b.x,b.z,-b.y],
                                    Width=width,Thickness=thickness))

def island(name,center,rx,ry,top,ground,cliff,phase=0):
    # Multi-ring cliff silhouette with an uninterrupted flat walkable interior.
    x,y=center;n=56;radii=[]
    for i in range(n):
        t=i*math.tau/n;radii.append(1+.045*math.sin(t*7+phase)+.035*math.cos(t*11+phase))
    v=[(x,y,top)]
    for scale,zz in ((.80,top),(1,top-4),(.93,top-24),(.78,top-58)):
        for i in range(n):
            t=i*math.tau/n
            v.append((x+rx*scale*radii[i]*math.cos(t),y+ry*scale*radii[i]*math.sin(t),zz))
    faces=[]
    for i in range(n):
        j=(i+1)%n;faces.append((0,1+i,1+j))
        faces.extend([(1+i,1+n+i,1+n+j),(1+i,1+n+j,1+j)])
    # Complete top disk as a solid down to the second ring, not a zero-thickness sheet.
    topv=v[:1+2*n]+[(x,y,top-5)]
    faces.extend((len(topv)-1,1+n+(i+1)%n,1+n+i) for i in range(n))
    mesh(name+'_Ground',topv,faces,ground)
    cv=v[1+n:]; cf=[]
    for k in range(2):
        for i in range(n):
            j=(i+1)%n;cf.extend([(k*n+i,(k+1)*n+i,(k+1)*n+j),(k*n+i,(k+1)*n+j,k*n+j)])
    cf.extend([tuple(reversed(range(2*n,3*n))),tuple(range(n))])
    mesh(name+'_Cliffs',cv,cf,cliff)

def arch(p,width,height,m,trim,angle=0):
    x,y,z=p;co=math.cos(angle);si=math.sin(angle)
    def q(a,b,c):return(x+a*co-b*si,y+a*si+b*co,z+c)
    for side in (-1,1):
        box('Pier',q(side*(width/2+2),0,height*.42),(4,5,height*.84),m,angle)
        box('PierFoot',q(side*(width/2+2),0,1),(6,7,2),trim,angle)
        box('Capital',q(side*(width/2+2),0,height*.84),(6,7,2),trim,angle)
    # Raised lintel leaves the full requested opening clear.
    box('ArchLintel',q(0,0,height*.90),(width+9,5,height*.20),m,angle)
    box('GoldInlay',q(0,-2.55,height*.90),(width+3,.16,.6),trim,angle)
    crystal('Keystone',q(0,0,height),2.4,5,trim)

def npc(name,p,robe,trim,skin,hood=True):
    global GROUP
    previous=GROUP;GROUP=name;x,y,z=p
    for side in (-1,1):box('Boot',(x+side*.55,y,z+.5),(.8,1.25,1),DARK)
    cone('Robe',(x,y,z+.8),1.3,.85,2.9,robe,8)
    box('Shoulders',(x,y,z+3.45),(2.1,1.1,1.4),robe)
    box('Sash',(x,y-.58,z+3),(.3,.15,2),trim)
    for side in (-1,1):
        beam('Sleeve',(x+side*.95,y,z+3.65),(x+side*1.5,y-.18,z+2.35),.7,robe)
        box('Hand',(x+side*1.5,y-.18,z+2.25),(.5,.55,.55),skin)
    box('Head',(x,y,z+4.8),(1.25,1.15,1.45),skin)
    if hood:
        cone('Hood',(x,y+.12,z+4.75),.93,.55,1.2,robe,8)
        box('Face',(x,y-.63,z+4.8),(.9,.16,.92),skin)
    for side in (-1,1):box('Eye',(x+side*.23,y-.74,z+4.96),(.12,.06,.12),DARK)
    beam('Staff',(x+1.8,y-.3,z+.1),(x+1.8,y-.3,z+6.8),.17,trim)
    crystal('StaffGem',(x+1.8,y-.3,z+6.7),.45,1.2,trim)
    GROUP=previous

def hub():
    global GROUP
    GROUP='Hub'
    island('Sanctuary',(0,0),190,190,5.3,GRASS,CLIFF)
    cone('CircularFoundation',(0,0,2),180,180,3.78,STONE,128)
    cone('PlazaPaving',(0,0,5.8),161,161,.2,CREAM,128)
    ring('OuterGold',(0,0,6.01),159.4,160.2,.12,GOLD,128)
    ring('InnerPromenade',(0,0,6.015),75,90,.14,STONE,100)
    for r in (23,66,92,154):ring('CompassInlay',(0,0,6.05),r,r+.55,.09,GOLD,100)
    # Five gates; parapet arcs deliberately leave five uninterrupted exits.
    for i,r in enumerate(REGIONS):
        t=math.radians(90-r['angle']);a=t+.11;b=t+math.tau/5-.11
        ring('GardenBed',(0,0,6),116,145,.5,GRASS,30,a+.10,b-.10)
        ring('Parapet',(0,0,6),177,180,3,STONE,30,a,b)
        for tt in [a,a+(b-a)/3,a+2*(b-a)/3,b]:
            p=(178.5*math.cos(tt),178.5*math.sin(tt),6)
            cone('BalustradeFinial',p,2.3,1.9,5,CREAM,8)
        road('RadialWalk',bp(r,0,23,6.12),bp(r,0,179,6.12),24,STONE,.15)
        for s in (-1,1):road('RadialInlay',bp(r,s*11.5,26,6.2),bp(r,s*11.5,172,6.2),.5,GOLD,.1)
        arch(bp(r,0,171,6),28,22,CREAM,ZONE_MATS[r['id']]['accent'],-math.radians(r['angle']))
        # Rotated lettering faces the hub.
        label(str(i+1).zfill(2),bp(r,0,168.35,25),3.5,INK,(math.pi/2,0,-math.radians(r['angle'])))
        for off in (.24,.52,.83):
            tt=a+(b-a)*off
            tree((133*math.cos(tt),133*math.sin(tt),6.5),RNG.uniform(15,23),'oak',LEAVES,WOOD)
        for off in (.28,.70):
            tt=a+(b-a)*off;x=102*math.cos(tt);y=102*math.sin(tt)
            box('BenchSeat',(x,y,7.8),(10,3,.6),WOOD,tt)
            for dx in (-3.5,3.5):box('BenchLeg',(x+dx*math.cos(tt),y+dx*math.sin(tt),6.9),(.8,2,1.8),STONE,tt)
    # Low central fountain preserves an open view across all branch entrances.
    cone('FountainPlinth',(0,0,6),17,17,1,STONE,64)
    ring('FountainBowl',(0,0,7),12,15,2,CREAM,64)
    cone('Water',(0,0,7.4),12,12,.35,WATER,64)
    cone('ObeliskFoot',(0,0,7.7),4.6,3.4,3,CREAM,10)
    crystal('SanctuarySunstone',(0,0,10.7),2.5,13,AMBER)
    ring('SunstoneHalo',(0,0,17),5.2,5.6,.5,GOLD,40)
    # Small plaza pavers keep scale legible without thousands of tiles.
    for radius in (42,59,98,151):
        for j in range(50):
            t=j*math.tau/50
            box('Paver',(radius*math.cos(t),radius*math.sin(t),6.07),(2,.25,.09),STONE,t)
    # Quest map stand near the spawn, merchant and rebirth face the shared commons.
    for x,title in [(-98,'REBIRTH'),(98,'RELICS')]:
        y=-32;cone('ServicePad',(x,y,5.9),21,21,.35,STONE,48)
        ring('ServiceInlay',(x,y,6.3),18.3,18.8,.12,GOLD,48)
        for sx in (-13,13):
            cone('PavilionColumn',(x+sx,y+7,6.2),1.2,1,15,CREAM,10)
            cone('ColumnCap',(x+sx,y+7,20),1.7,1.7,1.2,GOLD,10)
        arch((x,y+9,6.3),22,20,CREAM,GOLD)
        label(title,(x,y+6.35,23.5),2.8,INK)
        if x<0:
            # Open crescent pavilion; the NPC is on the level forecourt.
            ring('RebirthHalo',(x,y+10,17),7.6,8.3,.6,GOLD,48)
            crystal('RenewalCrystal',(x,y+11,7),2.7,10,AMBER)
            for sx in (-6,6):cone('OfferingBasin',(x+sx,y+5,6.3),1.7,2.2,2.5,CREAM,10)
            npc('NPC_RebirthKeeper',(x,y,6.3),IVORY,GOLD,SKIN)
            label('KEEPER OF RENEWAL',(x,y-6,6.38),1.4,INK,(0,0,0))
        else:
            # Cloth-striped stall with individually modelled goods.
            for k in range(7):box('AwningStripe',(x-12+k*4,y+3,18),(4,15,.45),TEAL if k%2 else CREAM)
            box('Counter',(x,y+1,8),(17,3,3.5),WOOD)
            for k in range(5):crystal('Relic',(x-6+k*3,y,10),.5,2,GOLD)
            npc('NPC_RelicMerchant',(x,y+5,6.3),TEAL,GOLD,SKIN,False)
    box('QuestCarpet',(-42,-12,6.12),(23,21,.2),TEAL)
    box('QuestTable',(-42,-7,8),(12,4,3.5),WOOD)
    box('Map',(-42,-8,9.82),(9,2.5,.08),CREAM)
    for sx in (-9,9):cone('QuestPost',(-42+sx,-5,6),.5,.5,14,WOOD,8)
    box('QuestSign',(-42,-5,18),(20,1.4,4),TEAL)
    label('QUESTS',(-42,-5.75,18),2.7,CREAM)
    npc('NPC_QuestGiver',(-42,-12,6.3),TEAL,GOLD,SKIN)
    label('SANCTUARY',(0,-115,6.25),7,INK,(0,0,0))
    label('REST  /  PREPARE  /  RETURN',(0,-126,6.25),2,INK,(0,0,0))
    # Lamps around the inner promenade, with no point-light cost at runtime.
    for i in range(15):
        t=(i+.5)*math.tau/15;x,y=94*math.cos(t),94*math.sin(t)
        cone('LampFoot',(x,y,6),1.5,1,1,STONE,8)
        cone('LampPost',(x,y,7),.3,.25,7,DARK,8)
        box('Lantern',(x,y,14),(1.8,1.8,2.4),AMBER)
        cone('LanternRoof',(x,y,15.2),1.6,.1,1,DARK,8)

def arena_geometry(r,x,d,spec):
    global GROUP
    GROUP='Arena_'+spec['id'];z=r['height']+2;mm=ZONE_MATS[r['id']]
    p=bp(r,x,d,z-2)
    cone('ArenaFoundation',p,36,36,1.45,mm['dark'],64)
    cone('ArenaFloor',bp(r,x,d,z-.5),34,34,.5,mm['stone'],64)
    ring('ArenaInlay',bp(r,x,d,z+.015),26.8,27.4,.04,mm['accent'],64)
    ring('BossSigil',bp(r,x,d+10,z+.02),4.5,5.1,.05,mm['accent'],24)
    road('EntryRamp',bp(r,x,d-51,r['height']+.16),bp(r,x,d-33,z+.03),14,mm['stone'])
    arch(bp(r,x,d-34,z),14,19,mm['dark'],mm['accent'],-math.radians(r['angle']))
    # Solid segmented boundary, entrance at branch-local -Z. Floor diameter stays 68.
    for j in range(17):
        t=math.radians(-163+j*326/16)
        xx=x+35*math.sin(t);dd=d+35*math.cos(t)
        box('ArenaWall',bp(r,xx,dd,z+4.5),(13.2,2.7,9),mm['dark'],-math.radians(r['angle'])-t)
        cone('RuinColumn',bp(r,xx,dd,z),2.0,1.7,12+(j%3)*2,mm['stone'],8)
        if j%3==0:crystal('Brazier',bp(r,xx,dd,z+14),1,3,mm['accent'])
    label(spec.get('title',r['title']).upper(),bp(r,x,d-36.65,z+17),1.15,CREAM,
          (math.pi/2,0,-math.radians(r['angle'])))
    if 'elite' in spec:
        # Elite screen leaves an 8-stud route and does not overlap the spawn.
        local_box(r,'EliteScreen',x+15,d+24,z+4,(3,8,8),mm['dark'])

def landmark(r):
    global GROUP
    GROUP='Landmark_'+r['id'];mm=ZONE_MATS[r['id']];z=r['height']
    if r['id']=='IronLowlands':
        # Twin broken watchtowers and an enormous carved guardian gate.
        for s in (-1,1):
            p=bp(r,s*28,614,z);cone('CitadelTower',p,12,10,65,mm['stone'],10)
            cone('Crown',bp(r,s*28,614,z+62),14,14,7,mm['dark'],10)
            for i in range(6):
                t=i*math.tau/6;box('Battlement',(p[0]+12*math.cos(t),p[1]+12*math.sin(t),z+71),(5,5,8),mm['stone'])
        arch(bp(r,0,614,z),37,40,mm['stone'],mm['accent'])
        rock('GorgonMask',bp(r,0,611,z+38),(16,6,13),mm['dark'])
        for s in (-1,1):beam('GorgonHorn',bp(r,s*6,611,z+40),bp(r,s*13,611,z+53),3,mm['accent'])
    elif r['id']=='FrostboundGlacier':
        for i,(x,d,h) in enumerate([(-43,619,60),(-21,634,89),(2,638,114),(30,627,80),(53,612,57)]):
            crystal('GlacialCrown',bp(r,x,d,z),13,h,mm['accent'] if i%2 else mm['stone'],(-1)**i*7)
        arch(bp(r,0,603,z),38,37,mm['dark'],mm['accent'],-math.radians(r['angle']))
    elif r['id']=='InfernalCaldera':
        p=bp(r,0,655,z);n=24;v=[]
        for rad,zz in [(65,0),(49,35),(32,92),(24,96),(19,74)]:
            for i in range(n):
                t=i*math.tau/n;v.append((p[0]+rad*math.cos(t),p[1]+rad*math.sin(t),z+zz+(math.sin(i*4)*3 if zz>0 else 0)))
        f=[]
        for k in range(4):
            for i in range(n):f.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
        f.extend([tuple(reversed(range(n))),tuple(range(4*n,5*n))]);mesh('Volcano',v,f,mm['dark'])
        cone('LavaCrater',(p[0],p[1],z+76),20,20,1,LAVA,32)
        for off in (-.7,.9,2.2):
            a=(p[0]+28*math.cos(off),p[1]+28*math.sin(off),z+94)
            b=(p[0]+65*math.cos(off),p[1]+65*math.sin(off),z+25)
            beam('LavaFalls',a,b,4,LAVA,1)
        for s in (-1,1):cone('ForgeStack',bp(r,s*30,585,z),7,6,40,mm['stone'],8)
    elif r['id']=='VoidRift':
        # Vertical ring built as closed beams, visibly open through the center.
        n=18;p=bp(r,0,628,z+54)
        a=math.radians(r['angle']);u=Vector((math.cos(a),-math.sin(a),0));p=Vector(p)
        for j in range(n):
            t=j*math.tau/n;tt=(j+1)*math.tau/n
            beam('RiftFrame',p+u*(40*math.cos(t))+Vector((0,0,40*math.sin(t))),
                 p+u*(40*math.cos(tt))+Vector((0,0,40*math.sin(tt))),5,mm['dark'])
            beam('RiftCore',p+u*(35*math.cos(t))+Vector((0,0,35*math.sin(t))),
                 p+u*(35*math.cos(tt))+Vector((0,0,35*math.sin(tt))),1.4,mm['accent'])
        for x,d,h in [(-55,620,65),(51,622,77),(-26,647,100),(29,650,108)]:
            crystal('RiftObelisk',bp(r,x,d,z),7,h,mm['dark'],7)
            crystal('FloatingShard',bp(r,x,d,z+h+12),4,12,mm['accent'],2)
    else:
        p=bp(r,0,642,z);cone('TempleBase',p,48,48,4,mm['stone'],48)
        for j in range(10):
            t=(j+.5)*math.tau/10
            if math.sin(t)<-.75:continue
            pp=(p[0]+38*math.cos(t),p[1]+38*math.sin(t),z+4)
            cone('TempleColumn',pp,3.3,2.6,46,mm['stone'],12)
            cone('GildedCapital',(pp[0],pp[1],z+47),4.3,4.3,3,GOLD,12)
        ring('TempleCornice',(p[0],p[1],z+50),32,45,5,mm['stone'],48)
        ring('TempleGold',(p[0],p[1],z+56),34,42,1,GOLD,48)
        crystal('SolarSpire',(p[0],p[1],z+55),6,48,GOLD)
        # Two swept wings make the final region silhouette distinct from the hub.
        for s in (-1,1):
            for j in range(6):
                a=bp(r,s*(13+j*4),611,z+56+j*3)
                b=bp(r,s*(27+j*6),617,z+84+j*2)
                beam('SunWing',a,b,4,mm['stone'],2)

def region(r):
    global GROUP
    mm=ZONE_MATS[r['id']];z=r['height'];GROUP='Terrain_'+r['id']
    # Build in branch-local space, rotate all terrain vertices into world space.
    island(r['id'],(0,500),159,230,z,mm['ground'],mm['dark'],r['angle'])
    # Transform just-created terrain buckets from local x/d to Blender world XY.
    for key in list(BUCKETS):
        if key[0]==GROUP:
            vs,fs,names=BUCKETS.pop(key)
            # Shoreline stays below the sloping causeway until it meets the ground.
            mesh('TerrainBatch',[bp(r,x,d,min(zz,6+(z-6)*(d-178)/128-.3) if d<306 else zz)
                                 for x,d,zz in vs],fs,mm['ground'] if key[1]==mm['ground'].name else mm['dark'])
    GROUP='Branch_'+r['id']
    road('StoneBridge',bp(r,0,178,6.12),bp(r,0,306,z+.12),28,STONE,4)
    for side in (-1,1):
        road('BridgeCoping',bp(r,side*14.5,178,8.6),bp(r,side*14.5,306,z+2.6),1.3,CREAM,2.5)
        for d in range(184,307,15):
            y=6+(z-6)*(d-178)/128
            cone('BridgePost',bp(r,side*14.5,d,y),1.5,1.2,5,CREAM,8)
        for d in (206,248,288):
            y=6+(z-6)*(d-178)/128
            cone('BridgePier',bp(r,side*10,d,-35),4,3,y+35,STONE,10)
    for d in range(182,305,6):
        y=6+(z-6)*(d-178)/128
        local_box(r,'BridgeJoint',0,d,y+.18,(27,.35,.06),GOLD)
    arch(bp(r,0,310,z),30,23,mm['dark'],mm['accent'],-math.radians(r['angle']))
    label(r['title'].upper(),bp(r,0,307.4,z+20.3),1.65,CREAM,(math.pi/2,0,-math.radians(r['angle'])))
    GROUP='Grounds_'+r['id']
    for d1,d2 in [(306,367),(367,433),(433,498)]:
        road('MainTrail',bp(r,0,d1,z+.13),bp(r,0,d2,z+.13),18,mm['path'],.3)
    # Two linked farming clearings, intentionally offset from the central walk.
    for sx,dd in [(-58,359),(54,362),(-63,425),(28,432)]:
        cone('EnemyClearing',bp(r,sx,dd,z-.06),28,28,.15,mm['path'],32)
        road('ClearingPath',bp(r,0,dd,z+.16),bp(r,sx,dd,z+.16),10,mm['path'],.18)
    if 'pocket' in r:
        road('SecondaryPath',bp(r,0,392,z+.15),bp(r,91,394,z+.15),12,mm['path'],.2)
        road('SecondaryApproach',bp(r,91,394,z+.15),bp(r,91,405,z+.15),12,mm['path'],.2)
    # Margins provide biome identity and sightline breaks; every spawn area stays clear.
    for i,(x,d) in enumerate([(-115,381),(-120,420),(-116,466),(-109,512),(-80,571),
                              (117,365),(136,398),(139,489),(113,545),(89,578)]):
        rock('BoundaryBoulder',bp(r,x,d,z+3),(RNG.uniform(13,24),RNG.uniform(15,25),RNG.uniform(13,24)),mm['dark'])
    for side in (-1,1):
        rock('OuterRidge',bp(r,side*112,549,z+8),(40,51,38),mm['dark'])
    # Small abandoned outposts make the farming grounds feel inhabited.
    for d in (388,473):
        x=-91
        if r['style'] in ('Woodland','Celestial'):
            local_box(r,'OutpostBase',x,d,z+1,(15,12,2),mm['stone'])
            local_box(r,'OutpostWall',x-6,d,z+5,(2,12,8),mm['stone'])
            local_box(r,'OutpostWall',x,d+5,z+5,(14,2,8),mm['stone'])
            # Pitched canopy, two solid slabs meeting along the ridge.
            beam('Canopy',bp(r,x-9,d,z+10),bp(r,x,d,z+15),1.1,mm['leaf'],14)
            beam('Canopy',bp(r,x,d,z+15),bp(r,x+9,d,z+10),1.1,mm['leaf'],14)
        elif r['style']=='FrostPine':
            for dx in (-5,5):crystal('FrostOutpost',bp(r,x+dx,d,z),3,17,mm['stone'])
            arch(bp(r,x,d,z),8,12,mm['dark'],mm['accent'],-math.radians(r['angle']))
        elif r['style']=='Infernal':
            cone('ForgeBasin',bp(r,x,d,z),5,6,5,mm['dark'],10)
            cone('ForgeEmber',bp(r,x,d,z+4.7),4.8,4.8,.4,LAVA,10)
        else:
            for dx in (-6,6):crystal('BrokenArchive',bp(r,x+dx,d,z),2,18,mm['dark'])
            ring('ArchiveRunes',bp(r,x,d,z+.07),7,7.7,.08,mm['accent'],20)
    for i in range(30):
        side=-1 if i%2 else 1;d=340+(i//2)*17+RNG.uniform(-5,5)
        width=159*math.sqrt(max(.03,1-((d-500)/230)**2))
        x=side*(width*.85+RNG.uniform(-5,7))
        if r['style'] in ('Woodland','FrostPine','Celestial'):
            tree(bp(r,x,d,z),RNG.uniform(19,34),'pine' if r['style']=='FrostPine' else 'oak',
                 mm['leaf'],WOOD,CREAM if r['style']=='FrostPine' else None)
        elif r['style']=='Infernal':
            if i%3:tree(bp(r,x,d,z),RNG.uniform(14,23),'dead',mm['leaf'],mm['dark'])
            else:crystal('BasaltColumn',bp(r,x,d,z),5,RNG.uniform(18,34),mm['dark'])
        else:
            crystal('Amethyst',bp(r,x,d,z),RNG.uniform(2,4),RNG.uniform(9,23),mm['accent'])
    # Details sit away from player movement and make the ground read at human scale.
    for i in range(45):
        x=RNG.choice((-1,1))*RNG.uniform(94,111);d=RNG.uniform(348,553)
        if r['style']=='Infernal':
            rock('Ember',bp(r,x,d,z+.2),(1.5,1.5,1.2),LAVA)
        else:
            cone('GrassTuft',bp(r,x,d,z),.45,.08,RNG.uniform(1.2,2.5),mm['leaf'],4)
    # Regional set pieces flank combat; main lanes never cross water/lava/void.
    if r['id']=='FrostboundGlacier':
        cone('FrozenPool',bp(r,-89,490,z+.05),23,23,.12,mm['accent'],32)
        for i in range(5):crystal('IceShard',bp(r,-107+i*8,502,z),2,8+i,mm['stone'])
    if r['id']=='InfernalCaldera':
        for side in (-1,1):
            road('LavaFissure',bp(r,side*94,481,z+.08),bp(r,side*76,551,z+.08),5,LAVA,.15)
    if r['id']=='VoidRift':
        cone('RiftSummitSteps',bp(r,86,449,z-.1),28,28,.22,mm['path'],32)
        road('StepsApproach',bp(r,0,392,z+.18),bp(r,86,412,z+.18),12,mm['path'],.2)
        road('StepsEntry',bp(r,86,412,z+.18),bp(r,86,435,z+.18),12,mm['path'],.2)
        for sx in (-12,12):crystal('ArchiveScreen',bp(r,-92+sx,488,z),3,16,mm['dark'])
        box('ArchiveChest',bp(r,-92,475,z+1.5),(4,3,3),GOLD)
    if r['id']=='IronLowlands':
        # A reachable optional ledge: 16-stud rise over 50 studs.
        road('RelicLedgeRamp',bp(r,-90,438,z+.2),bp(r,-98,488,22),8,mm['stone'],2)
        local_box(r,'RelicLedge',-98,492,21,(17,14,2),mm['stone'])
        box('BriarRelicChest',bp(r,-98,492,23.5),(4,3,3),GOLD)
    arena_geometry(r,0,550,r)
    if 'pocket' in r:
        p=r['pocket'];arena_geometry(r,91,445,p);GROUP='Pocket_'+p['id']
        if p['id']=='Briarwood':
            tree(bp(r,92,493,z),44,'oak',LEAVES,WOOD)
            for s in (-1,1):beam('ElderRoot',bp(r,92,493,z+10),bp(r,92+s*18,486,z),4,WOOD)
        elif p['id']=='SunkenMarsh':
            cone('MarshPool',bp(r,113,494,z+.06),20,20,.18,TEAL,32)
            arch(bp(r,91,493,z),12,29,mm['dark'],TEAL,-math.radians(r['angle']))
            cone('DrownedBell',bp(r,91,493,z+18),4.5,2,6,GOLD,10)
            tree(bp(r,123,475,z),23,'dead',TEAL,WOOD)
        else:
            for k in range(4):cone('StormTower',bp(r,97,500,z+k*12),10-k,9-k,12,mm['stone'],8)
            crystal('StormConductor',bp(r,97,500,z+48),3,20,ICE)
    landmark(r)

def flush():
    for (group,material,cx,cy),(verts,faces,names) in BUCKETS.items():
        c=COLLECTIONS.get(group)
        if c is None:
            c=bpy.data.collections.new(group);bpy.context.scene.collection.children.link(c);COLLECTIONS[group]=c
            if group.startswith('Kit_'):c.hide_render=True
        m=bpy.data.meshes.new(f'{group}_{material}_{cx}_{cy}')
        m.from_pydata(verts,[],faces);m.update()
        o=bpy.data.objects.new(m.name,m);c.objects.link(o);m.materials.append(MATERIALS[material])
        o['role']='visual';o['authored_studs']=True;o['source_shapes']=len(names)
        # Blender validates polygon winding and triangulates for importer consistency.
        mod=o.modifiers.new('ExportTriangulation','TRIANGULATE')
        bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.modifier_apply(modifier=mod.name);o.select_set(False)

def prop_library():
    global GROUP
    for r in REGIONS:
        mm=ZONE_MATS[r['id']]
        for lod in (0,1):
            GROUP=f'Kit_{r["id"]}_Tree_LOD{lod}'
            style='pine' if r['style']=='FrostPine' else 'dead' if r['style']=='Infernal' else 'oak'
            if lod==0:
                if r['style']=='Void':crystal('Amethyst',(0,0,0),3,21,mm['accent'])
                else:tree((0,0,0),24,style,mm['leaf'],WOOD,CREAM if style=='pine' else None)
            else:
                cone('Trunk',(0,0,0),1.3,.6,18,WOOD,5)
                if style=='dead':beam('Branch',(-4,0,19),(0,0,11),.8,WOOD)
                else:cone('Canopy',(0,0,9),7,.2,15,mm['accent'] if r['style']=='Void' else mm['leaf'],5)
            GROUP=f'Kit_{r["id"]}_Rock_LOD{lod}'
            if lod==0:rock('Rock',(0,0,2),(9,7,8),mm['dark'],seed=SEED+r['angle'])
            else:cone('Rock',(0,0,0),4.5,1.5,6,mm['dark'],5)
    GROUP='Kit_ScaleReference'
    box('TenStudReference',(5,0,.5),(10,1,1),GOLD)

def anchors(contract):
    c=bpy.data.collections.new('ANCHORS_DO_NOT_IMPORT_AS_VISUALS');bpy.context.scene.collection.children.link(c)
    def empty(name,p,role):
        o=bpy.data.objects.new(name,None);o.empty_display_type='PLAIN_AXES';o.empty_display_size=3
        o.location=(p[0],-p[2],p[1]);o['roblox_position']=p;o['role']=role;c.objects.link(o)
    for k in ['Center','SpawnPosition','QuestGiverPosition','MerchantPosition','RebirthPosition','RebirthPromptPosition']:
        empty('Hub_'+k,contract['Hub'][k],'safe_zone_npc' if 'Position' in k else 'safe_zone')
    for z in contract['Zones']:
        for k in ('Center','Approach','Door','Exit','BoundsCenter'):empty(z['Name']+'_'+k,z[k],k)
        for i,s in enumerate(z['Spawns']):empty(z['Name']+'_'+s['Archetype']+f'_{i}',s['Position'],s['Role'])
    for s in contract['FieldSpawns']:empty(s['Id'],s['Position'],'field_enemy')

def camera(name,p,target,ortho=None,lens=45):
    data=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,data);bpy.context.scene.collection.objects.link(o)
    o.location=p;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    data.clip_end=6000
    if ortho:data.type='ORTHO';data.ortho_scale=ortho
    else:data.lens=lens
    return o

def presentation():
    scene=bpy.context.scene;scene.world=bpy.data.worlds.new('Clear warm daylight');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.35,.48,.65,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55
    data=bpy.data.lights.new('Afternoon sun','SUN');data.energy=3;data.angle=.18
    o=bpy.data.objects.new('Afternoon sun',data);scene.collection.objects.link(o);o.rotation_euler=(.45,-.55,-.6)
    scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
    scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
    scene.view_settings.view_transform='AgX'
    scene.render.film_transparent=False
    cameras={
        '01_world_overview':camera('01_world_overview',(1150,-1570,1520),(0,10,0),1800),
        '02_top_down':camera('02_top_down',(0,0,2100),(0,0,0),1580),
        '03_sanctuary':camera('03_sanctuary',(260,-345,325),(0,0,6),485),
        '04_rebirth_pavilion':camera('04_rebirth_pavilion',(-133,-90,32),(-98,-27,14),None,43),
        '05_spawn_view':camera('05_spawn_view',(2,-68,12),(-8,24,12),None,25),
    }
    for i,r in enumerate(REGIONS):
        cameras[f'{6+i:02}_{r["id"]}']=camera(r['title'],bp(r,-205,260,r['height']+245),bp(r,0,496,r['height']+13),470)
    scene.camera=cameras['01_world_overview']
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_perspective='CAMERA'
                area.spaces.active.clip_end=6000
    return cameras

def export(contract,cameras,render):
    (OUT/'exports').mkdir(parents=True,exist_ok=True);(OUT/'previews').mkdir(exist_ok=True)
    (OUT/'anchors.json').write_text(json.dumps(contract,indent=2)+'\n')
    # A compact, standalone Luau module is the scripting-side handoff, not a replacement WorldLayout.
    def lua(v):
        if v is None:return 'nil'
        if isinstance(v,bool):return str(v).lower()
        if isinstance(v,(int,float)):return str(v)
        if isinstance(v,str):return json.dumps(v)
        if isinstance(v,list):return '{'+', '.join(lua(x) for x in v)+'}'
        return '{\n'+',\n'.join('['+json.dumps(k)+'] = '+lua(val) for k,val in v.items())+'\n}'
    (OUT/'MapAnchors.luau').write_text('-- Generated by tools/build_map_redesign.py; XYZ arrays are Roblox studs.\nreturn '+lua(contract)+'\n')
    collision=dict(Boxes=COLLISION_BOXES,Roads=COLLISION_ROADS)
    (OUT/'CollisionLayout.luau').write_text('-- Generated structural collision data; Roblox XYZ studs.\nreturn '+lua(collision)+'\n')
    manifest={'name':contract['Name'],'version':1,'seed':SEED,'files':[],
              'coordinate_system':contract['BlenderMapping'],'import_scale_unit':'Stud',
              'scene_position':[0,0,0],'anchor_file':'anchors.json','source_shapes':SERIAL}
    bpy.ops.object.select_all(action='DESELECT')
    for name,c in COLLECTIONS.items():
        objs=[o for o in c.objects if o.type=='MESH']
        if not objs:continue
        for o in objs:o.select_set(True)
        path=OUT/'exports'/f'{name}.glb'
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
            export_yup=True,export_apply=True,export_extras=True,export_cameras=False,export_lights=False)
        manifest['files'].append(dict(file='exports/'+path.name,collection=name,meshes=len(objs),
            triangles=sum(len(o.data.polygons) for o in objs),
            max_mesh_triangles=max(len(o.data.polygons) for o in objs),bytes=path.stat().st_size,
            position=[0,0,0],npc_visual=name.startswith('NPC_'),prop_library=name.startswith('Kit_')))
        for o in objs:o.select_set(False)
    # Full scene for review; modular GLBs above are the intended Studio imports.
    for name,c in COLLECTIONS.items():
        if name.startswith('Kit_'):continue
        for o in c.objects:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/'FivefoldSanctuary.glb'),export_format='GLB',use_selection=True,
        export_yup=True,export_apply=True,export_extras=True,export_cameras=False,export_lights=False)
    bpy.ops.object.select_all(action='DESELECT')
    manifest['total_triangles']=sum(x['triangles'] for x in manifest['files'])
    manifest['total_meshes']=sum(x['meshes'] for x in manifest['files'])
    manifest['map_triangles']=sum(x['triangles'] for x in manifest['files'] if not x['prop_library'])
    manifest['map_meshes']=sum(x['meshes'] for x in manifest['files'] if not x['prop_library'])
    manifest['previews']=[f'previews/{name}.png' for name in cameras]
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    bpy.context.scene.camera=cameras['01_world_overview']
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'FivefoldSanctuary.blend'))
    print('MAP_EXPORTED',json.dumps({k:manifest[k] for k in ['total_triangles','total_meshes','source_shapes']}),flush=True)
    if render:
        for name,cam in cameras.items():
            bpy.context.scene.camera=cam
            bpy.context.scene.render.resolution_x=1600
            bpy.context.scene.render.resolution_y=1600 if 'top_down' in name else 1100 if 'world' in name else 1000
            bpy.context.scene.render.filepath=str(OUT/'previews'/f'{name}.png')
            print('RENDERING',name,flush=True);bpy.ops.render.render(write_still=True)
    print('MAP_BUILD_COMPLETE',str(OUT),flush=True)

def main():
    global STONE,CREAM,GOLD,GRASS,LEAVES,WOOD,CLIFF,DARK,WATER,AMBER,TEAL,IVORY,SKIN,INK,LAVA,ICE,ZONE_MATS
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system='NONE';bpy.context.scene.unit_settings.scale_length=1
    STONE=mat('Sanctuary limestone','#b7b8a8');CREAM=mat('Warm ivory','#eee3c9')
    GOLD=mat('Aged gold','#c5a365',.35);GRASS=mat('Sanctuary turf','#6f915e');LEAVES=mat('Laurel leaves','#48785d')
    WOOD=mat('Warm timber','#715744');CLIFF=mat('Cliff strata','#526975');DARK=mat('Ironwork','#34454b')
    WATER=mat('Still water','#408c96',.2);AMBER=mat('Living amber','#ffd58a',.1,.7)
    TEAL=mat('Sanctuary teal','#357d7a');IVORY=mat('Keeper robes','#f7edd4');SKIN=mat('Warm skin','#b98466')
    INK=mat('Lettering','#394c51');LAVA=mat('Lava glow','#ff873b',0,1);ICE=mat('Stormlight','#9fe5f5',0,.65)
    ZONE_MATS={}
    for r in REGIONS:
        path={'Woodland':'#a99e7a','FrostPine':'#b7d1d5','Infernal':'#857265','Void':'#8c7a9e','Celestial':'#d5c9ad'}[r['style']]
        leaf={'Woodland':'#608458','FrostPine':'#4b7c88','Infernal':'#754d44','Void':'#887da7','Celestial':'#d2a8a1'}[r['style']]
        ZONE_MATS[r['id']]={k:mat(r['id']+'_'+k,col,0,.3 if k=='accent' and r['style'] in ('Void','FrostPine') else 0)
             for k,col in [('ground',r['color']),('stone',r['stone']),('dark',r['dark']),('accent',r['accent']),('path',path),('leaf',leaf)]}
    hub()
    for r in REGIONS:region(r)
    prop_library()
    # Solid ocean slab is presentation context and an optional visual-only import.
    global GROUP
    GROUP='Ocean_VisualOnly';box('Ocean',(0,0,-63),(2400,2400,2),WATER)
    flush();contract=make_contract();anchors(contract);cameras=presentation()
    export(contract,cameras,'--no-render' not in sys.argv)

if __name__=='__main__':main()
