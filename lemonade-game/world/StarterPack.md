# StarterPack

Roblox service in place `game` (PlaceId 108354544637319). 16 descendant instances.

Every instance below is a live object in the game hierarchy. Paths are Roblox instance paths; `Referenced by script(s)` lists the Luau source files that mention the instance by name.

## `StarterPack/ClassicSword` — Tool
The plain starter blade every player spawns holding: a part-built sword (no mesh, no
texture) deliberately simpler than the boss's imported blade, so a boss drop reads as
an upgrade. Assembled along the Handle's -Z axis, which is the direction the tool
points out of the hand; `Grip` is identity, so the hand sits at the centre of the grip.
Total length 4.77 studs (0.88 of pommel behind the hand, 3.89 of blade in front).
- Properties: RequiresHandle: true; CanBeDropped: false; Grip: identity (hand at grip centre)
- Children (8): MouseIcon (LocalScript), SwordClient (LocalScript), Handle (Part), Pommel (Part), Guard (Part), Blade (Part), TipUpper (WedgePart), TipLower (WedgePart)
- Referenced by script(s): ServerScriptService/SwordDropSystem, ReplicatedStorage/Config/Items

### `StarterPack/ClassicSword/MouseIcon` — LocalScript
Source file: `StarterPack/ClassicSword/MouseIcon.client.luau` (29 lines)

### `StarterPack/ClassicSword/SwordClient` — LocalScript
Source file: `StarterPack/ClassicSword/SwordClient.client.luau` (31 lines)

### `StarterPack/ClassicSword/Handle` — Part
The leather grip, and the Tool's required Handle. Every other piece is welded to it.
- Properties: Size: (0.32, 0.32, 1.10); Material: SmoothPlastic; Color: rgb(92, 66, 50); Shape: Block
- Children (8): SwordSlash (Sound), SwordLunge (Sound), Unsheath (Sound), WeldPommel (Weld), WeldGuard (Weld), WeldBlade (Weld), WeldTipUpper (Weld), WeldTipLower (Weld)

#### `StarterPack/ClassicSword/Handle/SwordSlash` — Sound
- Properties: SoundId: http://www.roblox.com/asset/?id=12222216; Volume: 0.70
- Referenced by script(s): StarterPack/ClassicSword/SwordClient

#### `StarterPack/ClassicSword/Handle/SwordLunge` — Sound
- Properties: SoundId: http://www.roblox.com/asset/?id=12222208; Volume: 0.60

#### `StarterPack/ClassicSword/Handle/Unsheath` — Sound
- Properties: SoundId: http://www.roblox.com/asset/?id=12222225; Volume: 1.00
- Referenced by script(s): StarterPack/ClassicSword/SwordClient

#### `StarterPack/ClassicSword/Handle/WeldPommel` — Weld
- Properties: Part0: Handle; Part1: Pommel; C0 pos: (0.00, 0.00, 0.66)

#### `StarterPack/ClassicSword/Handle/WeldGuard` — Weld
- Properties: Part0: Handle; Part1: Guard; C0 pos: (0.00, 0.00, -0.66)

#### `StarterPack/ClassicSword/Handle/WeldBlade` — Weld
- Properties: Part0: Handle; Part1: Blade; C0 pos: (0.00, 0.00, -2.09)

#### `StarterPack/ClassicSword/Handle/WeldTipUpper` — Weld
- Properties: Part0: Handle; Part1: TipUpper; C0 pos: (0.00, 0.15, -3.64)

#### `StarterPack/ClassicSword/Handle/WeldTipLower` — Weld
- Properties: Part0: Handle; Part1: TipLower; C0 pos: (0.00, -0.15, -3.64); C0 rot: 180 deg about Z (mirrors the wedge)

### `StarterPack/ClassicSword/Pommel` — Part
Bronze counterweight ball behind the hand.
- Properties: Size: (0.44, 0.44, 0.44); Material: Metal; Color: rgb(170, 124, 60); Shape: Ball

### `StarterPack/ClassicSword/Guard` — Part
Bronze crossguard, 0.66 studs in front of the hand.
- Properties: Size: (1.30, 0.26, 0.32); Material: Metal; Color: rgb(170, 124, 60); Shape: Block

### `StarterPack/ClassicSword/Blade` — Part
Steel blade, wide in Y and thin in X to match the boss blade's proportions.
- Properties: Size: (0.22, 0.60, 2.60); Material: Metal; Color: rgb(185, 192, 200); Shape: Block

### `StarterPack/ClassicSword/TipUpper` — WedgePart
Upper half of the point. A WedgePart is full height at +Z and tapers to an edge at -Z,
so in the default orientation it collapses onto the blade centreline at the tip.
- Properties: Size: (0.22, 0.30, 0.50); Material: Metal; Color: rgb(185, 192, 200)

### `StarterPack/ClassicSword/TipLower` — WedgePart
Lower half of the point: the same wedge rolled 180 deg about Z so the two meet in a
symmetric edge.
- Properties: Size: (0.22, 0.30, 0.50); Material: Metal; Color: rgb(185, 192, 200)
