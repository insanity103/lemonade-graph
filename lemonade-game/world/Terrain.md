# Terrain

`Workspace/Terrain` holds the voxel landscape. Voxel data is binary and is NOT captured in this text export.

- MaxExtents (voxel region): min (-32000.0, -32000.0, -32000.0), max (32000.0, 32000.0, 32000.0)
- WaterColor: rgb(12, 84, 92); WaterTransparency: 0.30
- WaterWaveSize: 0.15; WaterWaveSpeed: 10.00

`ServerScriptService/EnemyCombat.server.luau` raycasts against this Terrain in `resolveGroundPosition()` so spawned enemy rigs snap to the ground surface instead of spawning buried or floating.