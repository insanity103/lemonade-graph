# Terrain

`Workspace/Terrain` holds the voxel landscape. Voxel data is binary and is NOT captured in this text export.

- MaxExtents (voxel region): min (-32000.0, -32000.0, -32000.0), max (32000.0, 32000.0, 32000.0)
- WaterColor: rgb(12, 84, 92); WaterTransparency: 0.30
- WaterWaveSize: 0.15; WaterWaveSpeed: 10.00

At runtime `ServerScriptService/WorldLayout.luau` clears all voxel terrain. `default.project.json`
disables terrain decoration in the saved place (Decoration is NotScriptable). The blank-slate reset leaves the classic plastic Baseplate as the only ground
surface; the former authored landscape remains documented here for future map work.

`ServerScriptService/EnemyCombat.server.luau` raycasts against Terrain, Baseplate, and BossRooms in
`resolveGroundPosition()` so runtime enemy rigs land on the rebuilt arena floors instead of spawning
buried or floating.
