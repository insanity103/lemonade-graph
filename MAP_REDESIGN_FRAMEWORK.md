# Map Redesign Framework — GPT-6 Astra Handoff

> **Purpose:** This document gives you everything you need to redesign the Lemonade map in Blender and export it to Roblox. The scripting layer is already built — you only change data in one file (`WorldLayout.luau`) and import mesh assets.

---

## Architecture: One File Controls Everything

**`lemonade-game/ServerScriptService/WorldLayout.luau`** (1070 lines) is the single source of truth for the entire game world. It defines:

- Hub position, spawn, merchant
- 22 route waypoints (the road)
- 8 combat zones (positions, enemies, terrain, props, landmarks)
- 1 wild camp
- Boss room construction (arenas with gates)
- Terrain generation (mounds, materials, water)
- Day/night cycle lighting

**You change the map by editing the data tables in this file.** The runtime code (`WorldBuilder.server.luau`) calls `WorldLayout.EnsureBuilt()` which reads the tables and constructs everything procedurally. No Studio placement needed.

---

## What You Can Change (Data Only)

### 1. Hub

```lua
WorldLayout.HUB = {
    Center = Vector3.new(0, 2, -178),        -- world center of the hub
    SpawnPosition = Vector3.new(-8, 3.3, -181), -- where players appear
    MerchantPosition = Vector3.new(13, 2.8, -172), -- merchant NPC location
}
```

### 2. Route (the road connecting all zones)

22 waypoints forming an S-curve. Each node has:
```lua
{ Position = Vector3.new(X, Y, Z), Material = Enum.Material.Ground, Level = 1 },
```
- `Material` — terrain material for the road at this point
- `Level` — level tag (informational, used for zone transitions)

### 3. Zones (8 combat arenas)

Each zone is a table with these fields:
```lua
{
    Name = "IronLowlands",           -- internal ID (never changes after deploy)
    DisplayName = "Iron Lowlands",   -- shown on zone label BillboardGui
    RequiredLevel = 1,               -- level gate
    Center = Vector3.new(-72, 5, -104),  -- world position
    Approach = Vector3.new(-45, 4, -130), -- direction player enters from (road-facing)
    TerrainMaterial = Enum.Material.Ground,  -- terrain fill material
    FloorMaterial = Enum.Material.Slate,     -- arena floor material
    Color = Color3.fromRGB(117, 75, 67),     -- primary zone color
    Accent = Color3.fromRGB(205, 103, 78),   -- accent color (gate lights, markers)
    Style = "Woodland",              -- determines tree/rock/landmark generation
    Landforms = { ... },             -- terrain mounds (position + radius)
    Trees = { ... },                 -- local positions for trees/props
    Rocks = { ... },                 -- local positions for boulder clusters
    Spawns = { ... },                -- enemy spawn configs
    Elite = { ... },                 -- optional elite enemy spawn
    Pools = { ... },                 -- optional water pools (Sunken Marsh only)
}
```

**Zone positions are local offsets from Center, transformed through `arenaCFrame()`.**
The arena CFrame orients the zone to face its Approach point:
```lua
CFrame.lookAt(Center, Vector3.new(Approach.X, Center.Y, Approach.Z))
```

### 4. Enemy Spawns

Each spawn is: `{ "ArchetypeName", Vector3.new(localX, localY, localZ), level }`
```lua
Spawns = {
    { "Boss_Gorgon", Vector3.new(0, 0, 10), 10 },      -- boss at back center
    { "IronSquire", Vector3.new(-15, 0, -7), 1 },      -- minion left-front
    { "IronSquire", Vector3.new(15, 0, -7), 1 },       -- minion right-front
    { "IronBerserker", Vector3.new(-14, 0, 17), 2 },   -- minion left-back
    { "IronBerserker", Vector3.new(14, 0, 17), 2 },    -- minion right-back
},
Elite = { "IronBerserker", Vector3.new(-7, 0, 26), 3 }, -- hidden alcove (optional)
```

### 5. Styles (determine visual generation)

| Style | Trees | Rocks | Landmark |
|-------|-------|-------|----------|
| `Woodland` | Full trunks + 3-ball canopies (Grass) | 3-sphere clusters | Twin watchtowers + beam |
| `Briar` | Full trunks + canopies (LeafyGrass) | 3-sphere clusters | Root shrine (hollow stump, heartstone) |
| `FrostPine` | Trunks + snow canopies | 3-sphere clusters | Crystal spires |
| `Marsh` | Full trunks + canopies (Mud) | 3-sphere clusters | Flooded bell tower |
| `Infernal` | Bare trunks (no canopy) | 3-sphere clusters | Basalt fangs + lava heart |
| `Storm` | Bare lightning-struck snags | 3-sphere clusters | Cracked observatory dome |
| `Void` | Crystal pillars (neon) | 3-sphere clusters | Rift obelisk + floating motes |
| `Celestial` | Marble ruin columns | 3-sphere clusters | Marble columns + sun beacon |

---

## What You Cannot Change (Game Systems)

These are hardcoded in other files and must NOT be moved:

| System | File | Why |
|--------|------|-----|
| Enemy archetypes (HP, damage, XP) | `EnemyCombat.server.luau` | Combat balance — separate from map |
| Boss weapons (stats, drops) | `BossWeapons.luau` | Loot system — separate from map |
| Quest definitions | `QuestConfig.luau` | References zone names, not positions |
| Merchant items | `MerchantConfig.luau` | Shop system — separate from map |
| Boss room gate logic | `BossRoomGate.server.luau` | Reads `RequiredLevel` from door attributes |
| Day/night cycle | `DayCycle.server.luau` | Lighting — applies globally |
| Rebirth config | `RebirthConfig.luau` | Progression — separate from map |

---

## Blender Workflow

### Step 1: Design the Map in Blender

Use Blender to create the visual world. Design decisions:

1. **World layout** — Where does the hub sit? What's the road path? Where are zones?
2. **Zone geometry** — Each zone is a 68x68 arena with ruins, props, and a gate
3. **Landmarks** — One per zone, behind the arena, 50+ studs from road
4. **Terrain** — Use Blender's terrain tools to sculpt the ground, then convert to Roblox terrain voxels
5. **Props** — Trees, rocks, boulders, campfires, logs, banners

### Step 2: Export for Roblox

Two approaches:

**A. Terrain (recommended):** Don't model terrain in Blender. Instead, design the terrain layout on paper/2D, then encode it as `Landforms` data in `WorldLayout.luau`. The runtime generates terrain voxels from this data.

**B. Meshes (for props/landmarks):** Model in Blender, export as `.glb`, import into Roblox Studio via the 3D importer. Then reference the mesh in `WorldLayout.luau` or `CombatUtil.luau`.

### Step 3: Update WorldLayout.luau

Translate your Blender design into the data tables:

1. Update `HUB.Center`, `HUB.SpawnPosition`, `HUB.MerchantPosition`
2. Update all 22 `ROUTE` nodes with new positions
3. Update all 8 `ZONES` with new centers, approaches, and local spawn positions
4. Update `Landforms`, `Trees`, `Rocks` per zone
5. Update `WILD_CAMPS` if adding/moving camps
6. Bump `WorldLayout.VERSION`

### Step 4: Test in Studio

1. `rojo serve` from the project root
2. Connect Studio to Rojo
3. Hit Play — `WorldBuilder.server.luau` will construct the new world automatically
4. Walk the road, visit each zone, verify enemies spawn correctly

---

## Current Map (for reference)

### Hub
- Center: `(0, 2, -178)`, Spawn: `(-8, 3.3, -181)`, Merchant: `(13, 2.8, -172)`
- 52-stud diameter cobblestone plaza with 3 grass mounds

### Route (22 nodes, ~29 studs wide)
- Starts at hub `(0, 2, -178)`, ends at `(78, 40, 91)`
- Total distance: ~400 studs (2-3 min walk)
- Materials: Cobblestone → Ground → Rock → Snow → Basalt → Rock → Slate → Sandstone → Marble

### 8 Zones

| # | Name | Level | Center | Style | Enemies |
|---|------|-------|--------|-------|---------|
| 1 | Iron Lowlands | 1 | `(-72, 5, -104)` | Woodland | IronSquire, IronBerserker, Boss_Gorgon |
| 2 | Briarwood | 8 | `(-166, 11, -126)` | Briar | ThornStalker, BriarBrute, RootWarden |
| 3 | Frostbound Glacier | 15 | `(-138, 14, -22)` | FrostPine | FrostImp, GlacialGargoyle, Boss_FrostRevenant |
| 4 | Sunken Marsh | 23 | `(-217, 20, 39)` | Marsh | BogLurker, MireHulk, DrownedBellwarden |
| 5 | Infernal Caldera | 30 | `(-125, 23, 78)` | Infernal | CinderFiend, MagmaJuggernaut, Boss_InfernalColossus |
| 6 | Stormwatch | 40 | `(-33, 26, 35)` | Storm | Stormcaller, ThunderConstruct, TempestWarden |
| 7 | Void Rift | 50 | `(10, 32, 132)` | Void | VoidShade, AbyssTormentor, Boss_VoidWraith |
| 8 | Celestial Summit | 75 | `(121, 43, 70)` | Celestial | AstralWisp, SolarDominator, Boss_CelestialTitan |

### Boss Arenas (generated at each zone)
- 68x68 studs, 9 ruin pillars, 8 low walls
- ForceField gate with `RequiredLevel` attribute
- Elite alcove in rear corner (5 of 8 zones)
- Zone label BillboardGui

### Design Constraints (from research)

1. **Zone sizing:** 500-2000 studs for grinding zones, 300-800 for boss arenas
2. **Travel time:** 30-60 seconds between adjacent zones, 3-5 min across the full map
3. **Level gates:** Each zone spans ~50-100 levels, with 0-30 overlap
4. **Landmark anchoring:** 1 dominant landmark per zone, visible from adjacent zones
5. **Visual identity:** Each zone must be distinct within 3 seconds of entering
6. **Environmental rhythm:** Alternate natural/built/fantastical every 3 zones
7. **Secrets:** 1 hidden reward per 2-3 zones (bushes, false walls, multi-step chains)

---

## Files GPT-6 Astra Should Read

| File | Purpose |
|------|---------|
| `lemonade-game/ServerScriptService/WorldLayout.luau` | **THE file to edit** — all map data |
| `lemonade-game/ServerScriptService/WorldBuilder.server.luau` | How the data gets built into the world |
| `lemonade-game/ServerScriptService/EnemyCombat.server.luau` | Enemy archetypes and spawn logic |
| `lemonade-game/ServerScriptService/BossRoomGate.server.luau` | Boss room gate system |
| `lemonade-game/Workspace/DayCycle.server.luau` | Lighting cycle |
| `lemonade-game/ReplicatedStorage/Config/QuestConfig.luau` | Quest zone references |
| `research/sword-rpg/sword-rpg-world-design.md` | World design best practices |
| `skills/roblox-map-design/SKILL.md` | Map design framework |
| `assets/swords/manifest.json` | Boss sword mesh metadata |

---

## Deliverables for GPT-6 Astra

1. **Updated `WorldLayout.luau`** — new positions, zones, routes, terrain data
2. **Blender files** — zone geometry, landmarks, props (export as .glb)
3. **Updated `assets/swords/`** — if boss sword meshes change
4. **Updated `DayCycle.server.luau`** — if lighting/atmosphere changes
5. **Updated `QuestConfig.luau`** — if zone names change
6. **Updated `manual_trace.md`** — document what changed and why
