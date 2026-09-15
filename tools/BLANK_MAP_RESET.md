# Apply the blank map reset

The previous reset assigned Terrain.Decoration from a server script. Roblox marks that
property NotScriptable, so the assignment could abort world initialization before creating
the baseplate. The corrected project serializes Decoration=false through Rojo and creates
Baseplate and SpawnLocation in edit mode as well as clearing terrain during Play.

For the existing place:

1. Stop Play and save a copy of the place to preserve the old terrain.
2. Sync default.project.json using Rojo.
3. Paste the complete tools/reset_map_in_studio.luau into Studio's Command Bar and run it.
   This clears saved voxel terrain and archives old Workspace map objects in ServerStorage.
4. Select Workspace > Terrain. Confirm Decoration is unchecked in Properties.
5. Save the place. Play twice: both runs should show a baseplate and spawn with no map
   regeneration or WorldLayout errors. Publish the place when ready to update the live game.

Rojo preserves unknown Studio objects in this project; sync alone does not erase saved terrain
or all manually placed map objects. Runtime cleanup alone also does not persist after Stop.
The archived objects can be restored from ServerStorage; voxel terrain can be restored from
the saved copy. The separate assets/map_redesign art source remains in the repository.
