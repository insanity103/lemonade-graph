# Terrain

`Workspace/Terrain` holds the voxel landscape. Voxel data is binary and is NOT captured in this text export.

- MaxExtents (voxel region): min (-32000.0, -32000.0, -32000.0), max (32000.0, 32000.0, 32000.0)
- WaterColor: rgb(12, 84, 92); WaterTransparency: 0.30
- WaterWaveSize: 0.15; WaterWaveSpeed: 10.00

At runtime `ServerScriptService/WorldLayout.luau` clears the legacy voxels and builds one continuous,
ascending RPG landscape. A hand-authored S-curve trail leads from the grass hub through Ground, Snow,
Basalt, Slate, and Sandstone regions. Overlapping terrain mounds form natural shoulders and asymmetric
ridges; deterministic noise only softens those shoulders and never places gameplay objects. Each zone's
round combat clearing branches from the main route and is framed by clustered biome decor plus a unique
long-range landmark. Boss gates, SpawnLocation, merchant, and enemy spawns consume the same layout data.

`ServerScriptService/EnemyCombat.server.luau` raycasts against Terrain, Baseplate, and BossRooms in
`resolveGroundPosition()` so runtime enemy rigs land on the rebuilt arena floors instead of spawning
buried or floating.
