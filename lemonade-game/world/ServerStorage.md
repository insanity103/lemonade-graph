# ServerStorage

Roblox service in place `game` (PlaceId 108354544637319). 3 descendant instances.

Server-only templates. Nothing here replicates to clients; scripts clone out of it.

## `ServerStorage/SwordMeshTemplate` — MeshPart
The imported boss blade, kept unparented as a sizing template. `EnemyCombat` clones it
for any archetype with `weapon = true` and sets `Size = SWORD_ASPECT * SWORD_LENGTH * scale`,
so a scale-1.5 boss carries a 6.3-stud version of the same undistorted mesh.

**Orientation caveat:** Studio's 3D importer rotates the source model 180 deg about Y.
The mesh is therefore grip-at--Z / tip-at-+Z, with the crossguard at local
`z = -0.245 * L`, the opposite of the OBJ it was built from. Anything that places this
mesh must apply `CFrame.Angles(0, math.pi, 0)` or it ends up held by the blade.
- Properties: Size: (0.45, 0.85, 4.20); MeshId: rbxassetid://138954940874089; TextureID: rbxassetid://94815539554065
- Referenced by script(s): ServerScriptService/EnemyCombat

## `ServerStorage/BossSwordTool` — Tool
The same mesh wrapped as an equippable Tool. This is what `SwordDropSystem` clones for
a rare boss drop, so the sword the player wins is visibly the one the boss was swinging
— not the plain starter blade in StarterPack.

`Grip` folds in both the importer's 180 deg flip and the 0.38*L offset that puts the
hand in the handle. Verified against the engine's weld maths
(`Handle = Arm * C0 * Grip:Inverse()`): crossguard lands 0.6 studs in front of the hand,
pommel 0.5 studs behind it, tip 3.6 studs forward.
- Properties: RequiresHandle: true; CanBeDropped: false; Grip pos: (0.00, 0.00, -1.60); Grip yaw: 180 deg
- Children (1): Handle (MeshPart)
- Referenced by script(s): ServerScriptService/SwordDropSystem

### `ServerStorage/BossSwordTool/Handle` — MeshPart
- Properties: Size: (0.45, 0.85, 4.20); Material: Plastic; MeshId: rbxassetid://138954940874089; TextureID: rbxassetid://94815539554065
