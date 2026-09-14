"""Optional original clear-day sky cubemap and Roblox lighting handoff."""
import json
import math
from pathlib import Path
import bpy
from mathutils import Vector

out=Path(__file__).resolve().parents[1]/'assets'/'map_redesign'/'sky'
out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=12
scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
world=bpy.data.worlds.new('Sanctuary clear sky');world.use_nodes=True;scene.world=world
nodes=world.node_tree.nodes
sky=nodes.new('ShaderNodeTexSky');sky.sky_type='MULTIPLE_SCATTERING';sky.sun_elevation=math.radians(34)
sky.sun_rotation=math.radians(135);sky.sun_size=math.radians(1);sky.air_density=1;sky.aerosol_density=.6
world.node_tree.links.new(sky.outputs['Color'],nodes['Background'].inputs['Color'])
nodes['Background'].inputs['Strength'].default_value=.4
data=bpy.data.cameras.new('Cubemap');data.type='PERSP';data.angle=math.pi/2
cam=bpy.data.objects.new('Cubemap',data);scene.collection.objects.link(cam);scene.camera=cam
# Directions are explicitly named in Roblox coordinates. Upload as Sky textures
# and verify face rotation in Studio; the included JSON records each convention.
faces={'SkyboxFt':(0,1,0),'SkyboxBk':(0,-1,0),'SkyboxLf':(-1,0,0),
       'SkyboxRt':(1,0,0),'SkyboxUp':(0,0,1),'SkyboxDn':(0,0,-1)}
for name,direction in faces.items():
    cam.rotation_euler=Vector(direction).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/(name+'.png'))
    bpy.ops.render.render(write_still=True)
    print('SKY_FACE',name,flush=True)
config=dict(Description='Optional original procedural clear-day cubemap, rendered in Blender.',
    Faces={name:name+'.png' for name in faces},
    FaceLookDirectionsRoblox={name:[v[0],v[2],-v[1]] for name,v in faces.items()},
    Lighting=dict(ClockTime=14.5,Brightness=2.3,Ambient=[108,116,128],OutdoorAmbient=[142,156,167],
                  EnvironmentDiffuseScale=.8,EnvironmentSpecularScale=.35,GlobalShadows=True),
    Atmosphere=dict(Density=.18,Offset=.1,Color=[194,218,231],Decay=[138,154,177],Glare=.08,Haze=1.2),
    IntegrationNotes=['Upload PNGs to obtain asset IDs; local paths are not rbxassetid URLs.',
      'Choose this sky OR the existing dynamic sky; DayCycle may overwrite global lighting settings.',
      'Check sky face rotation/seams in Studio. Emissive materials do not create Roblox point lights automatically.',
      'Keep bridge and boss gate visibility legible when testing night lighting.'])
(out/'lighting.json').write_text(json.dumps(config,indent=2)+'\n')
