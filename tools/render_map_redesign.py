"""Render saved map cameras without rebuilding/exporting geometry."""
from pathlib import Path
import sys
import bpy

out = Path(__file__).resolve().parents[1] / 'assets' / 'map_redesign'
args = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
cameras = [o for o in scene.objects if o.type == 'CAMERA']
for cam in cameras:
    # Named regions use their numbered output filename from the saved order.
    order = ['Iron Lowlands','Frostbound Glacier','Infernal Caldera','Void Rift','Celestial Summit']
    ids = ['IronLowlands','FrostboundGlacier','InfernalCaldera','VoidRift','CelestialSummit']
    name = cam.name
    if name in order:
        i=order.index(name);name=f'{6+i:02}_{ids[i]}'
    if args and not any(a in name for a in args):
        continue
    scene.camera = cam
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1600 if 'top_down' in name else 1100 if 'world' in name else 1000
    scene.render.filepath = str(out / 'previews' / (name + '.png'))
    print('RENDER_START',name,flush=True)
    bpy.ops.render.render(write_still=True)
    print('RENDER_SAVED',name,flush=True)
