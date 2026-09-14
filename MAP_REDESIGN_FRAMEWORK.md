# Map Redesign Framework

> **Two owners, one world.** Blender owns the visual world (terrain, architecture, props). Code owns the gameplay hooks (spawns, gates, NPCs). They meet at anchor points — named positions both sides agree on.

---

## How It Works

```
┌─────────────────────────┐     ┌─────────────────────────┐
│   GPT-6 Astra (Blender) │     │  Claude Code (Luau)     │
│                         │     │                         │
│  Terrain mesh           │     │  Enemy spawn positions  │
│  Zone architecture      │     │  Level gate data        │
│  Landmarks & props      │     │  NPC positions          │
│  Boss room geometry     │     │  Zone metadata          │
│  Vegetation & rocks     │     │  Road waypoint data     │
│  Lighting & atmosphere  │     │  Quest definitions      │
│                         │     │  Day/night cycle        │
└───────────┬─────────────┘     └───────────┬─────────────┘
            │                               │
            │    ANCHOR POINTS              │
            │    (shared Vector3 data)      │
            └───────────────┬───────────────┘
                            │
                    Roblox Studio
                    (Rojo sync + import)
```

**Anchor points** are Vector3 positions both sides must agree on:
- Hub center, spawn, merchant
- Zone centers and approach directions
- Enemy spawn local offsets (within each zone)
- Road waypoints (the path connecting everything)
- NPC positions (quest giver, merchants)
- Boss room door positions and required levels

---

## Part 1: Claude Code (Scripting Side)

### What Claude Code owns

| System | File | What it does |
|--------|------|-------------|
| Zone metadata | `WorldLayout.luau` | Zone names, levels, colors, required levels |
| Enemy spawns | `WorldLayout.luau` + `EnemyCombat.server.luau` | Archetype configs, spawn positions, AI |
| Level gates | `BossRoomGate.server.luau` | Collision groups, ejection logic |
| NPC placement | `MerchantSystem.server.luau`, `QuestService.server.luau` | Merchant, quest giver positions |
| Boss room logic | `BossRoomGate.server.luau` | Door attributes, RequiredLevel |
| Day/night | `DayCycle.server.luau` | Lighting cycle (global) |
| Quests | `QuestConfig.luau` | Quest objectives, zone references |
| Road waypoints | `WorldLayout.luau` ROUTE table | Player navigation, terrain ribbon |

### What Claude Code does NOT own (Blender does)

- Terrain shape and elevation
- Zone architecture (ruins, walls, gates as meshes)
- Landmark geometry (towers, shrines, obelisks)
- Tree and rock meshes
- Boss room physical layout (floor, pillars, walls)
- Visual atmosphere (skybox, fog, particle effects)

### Data contract: What Claude Code needs from Blender

When Blender finishes a zone, Claude Code needs these values:

```lua
-- Hub anchor points
HUB.Center = Vector3.new(X, Y, Z)
HUB.SpawnPosition = Vector3.new(X, Y, Z)
HUB.MerchantPosition = Vector3.new(X, Y, Z)

-- Route waypoints (road path)
ROUTE = {
    { Position = Vector3.new(X, Y, Z), Material = Enum.Material.X, Level = N },
    -- ... one per waypoint
}

-- Per zone
ZONES[i] = {
    Name = "ZoneId",                    -- internal ID (never changes)
    DisplayName = "Zone Name",          -- player-facing
    RequiredLevel = N,                  -- level gate
    Center = Vector3.new(X, Y, Z),      -- world center of arena
    Approach = Vector3.new(X, Y, Z),    -- road point player enters from
    Color = Color3.fromRGB(R, G, B),    -- primary zone color
    Accent = Color3.fromRGB(R, G, B),   -- accent color
    Spawns = {                          -- enemy positions (local offsets)
        { "BossArchetype", Vector3.new(0, 0, 10), bossLevel },
        { "MinionA", Vector3.new(-15, 0, -7), minionLevel },
        { "MinionA", Vector3.new(15, 0, -7), minionLevel },
        { "MinionB", Vector3.new(-14, 0, 17), minionLevel },
        { "MinionB", Vector3.new(14, 0, 17), minionLevel },
    },
    Elite = { "EliteArchetype", Vector3.new(-7, 0, 26), eliteLevel },
}

-- Per NPC
QuestGiverPosition = Vector3.new(X, Y, Z)
MerchantPosition = Vector3.new(X, Y, Z)  -- from HUB
```

### Claude Code tasks (do these after Blender exports geometry)

1. **Update `WorldLayout.luau`** — new hub, route, zone anchor points
2. **Update `QuestConfig.luau`** — quest zone references if zone names change
3. **Update `EnemyCombat.server.luau`** — if adding/removing enemy archetypes
4. **Update `BossRoomGate.server.luau`** — if boss room door positions change
5. **Update `DayCycle.server.luau`** — if lighting/atmosphere changes
6. **Update `manual_trace.md`** — document what changed
7. **Run `graphify update .`** — refresh knowledge graph
8. **Commit and push**

---

## Part 2: GPT-6 Astra (Blender Side)

> **September 13 redesign delivery:** See [`assets/map_redesign/README.md`](assets/map_redesign/README.md) and [`anchors.json`](assets/map_redesign/anchors.json). The new user brief supersedes the linear layout below: a 360-stud circular sanctuary, five independent boss branches, and a modeled rebirth station/NPC. All eight existing zone IDs survive as five main regions plus three secondary pockets. The delivered anchors supersede the reference positions in Parts 3 and 5. Part 1 gameplay integration remains a separate step.

### What Blender owns

| Asset | Format | Where it goes in Roblox |
|-------|--------|------------------------|
| Terrain mesh | `.glb` or Roblox terrain voxels | `Workspace.Terrain` or mesh in `Workspace` |
| Zone architecture | `.glb` per zone | `Workspace.BossRooms/<ZoneName>` |
| Landmarks | `.glb` per landmark | `Workspace` (placed by code or manually) |
| Trees & rocks | `.glb` with variants | `ServerStorage` (code clones and places) |
| Boss room geometry | `.glb` per room | `Workspace.BossRooms/<RoomName>` |
| Skybox | Cubemap texture | `Lighting.Sky` |
| Particle effects | `.rbxm` or code | `Workspace` / `Lighting` |

### Design constraints (from research)

**Zone sizing:**
- Hub: 1500-3000 studs, high content density
- Grinding zones: 1000-2000 studs, 10-20 enemies
- Boss arenas: 300-800 studs, boss + 5-10 minions
- Travel time between zones: 30-60 seconds on foot

**Level gating:**
- Each zone spans ~50-100 levels
- Adjacent zones overlap by 0-30 levels
- Every major region transition = prestige milestone

**Visual identity:**
- Each zone must be distinct within 3 seconds of entering
- Color coding per zone (terrain, lighting, props)
- 1 dominant landmark per zone, visible from adjacent zones
- Gradual biome transitions (20-40 stud blend zones)

**Environmental rhythm (3-zone cycle):**
```
Zone A: Natural biome (forest, desert, snow)
Zone B: Built environment (village, fortress, ruins)
Zone C: Fantastical (volcano, void, sky island)
→ Repeat with escalating scale
```

**Secrets:**
- 1 hidden reward per 2-3 zones
- 60% visible (on ledges, rooftops), 40% hidden (behind objects, underground)
- Every point of interest visible from at least one other location

**Boss room layout:**
- 68x68 studs (matches `ARENA_SIZE` constant in code)
- Gate opening: 14 studs wide (matches `DOOR_WIDTH`)
- Gate must have a door part with `RequiredLevel` attribute
- Interior needs: floor, walls/ruins, boss spawn point, minion spawn points
- Elite alcove in rear corner (optional)

### Blender → Roblox export workflow

1. **Model the world** in Blender (terrain, zones, props)
2. **Export meshes** as `.glb` (GLTF format)
3. **Import into Roblox Studio** via Plugins > 3D Importer
4. **Place in hierarchy:**
   - Terrain → `Workspace.Terrain` (or `Workspace` as mesh)
   - Zone architecture → `Workspace.BossRooms/<ZoneName>`
   - Props → `ServerStorage` (code will clone and place)
5. **Anchor points:** Mark zone centers and spawn positions with empty objects or comments in Blender so Claude Code can read them
6. **Deliver anchor data** as a table of Vector3 values Claude Code needs

### Blender deliverables

| # | Deliverable | Format | Notes |
|---|-------------|--------|-------|
| 1 | Terrain geometry | `.glb` or terrain voxel data | The ground, hills, valleys, water |
| 2 | Zone architecture (x8) | `.glb` per zone | Ruins, walls, gates, arena layout |
| 3 | Landmarks (x8) | `.glb` per landmark | One per zone, behind the arena |
| 4 | Boss room geometry (x8) | `.glb` per room | 68x68 arena with gate |
| 5 | Tree/rock variants | `.glb` with LOD | Multiple variants per biome style |
| 6 | Hub geometry | `.glb` | Plaza, merchant stall, quest giver area |
| 7 | Road/path mesh | `.glb` | The connecting road (optional — can be terrain) |
| 8 | Anchor point data | Text file / JSON | Vector3 positions for all anchor points |
| 9 | Skybox | Cubemap PNG | 6-face cubemap for `Lighting.Sky` |
| 10 | Color palette | Image/text | Zone color references for code |

---

## Part 3: Anchor Points (Shared Data)

Both sides must agree on these positions. Blender places geometry here; code places gameplay here.

### Hub

| Anchor | Vector3 | What Blender builds | What code places |
|--------|---------|--------------------|--------------------|
| Hub Center | `(0, 2, 0)` | Plaza, buildings | Terrain mounds |
| Spawn | `(0, 3, 0)` | Spawn platform | SpawnLocation part |
| Merchant | `(10, 3, 0)` | Merchant stall | Merchant NPC, carpet, counter |
| Quest Giver | `(5, 3, -5)` | Quest giver area | Quest NPC |

### Per Zone (8 zones)

| Anchor | What Blender builds | What code places |
|--------|--------------------|--------------------|
| Zone Center | Arena floor, ruins, walls | Enemy spawns, zone label |
| Approach | Road entrance to zone | Terrain ribbon, lamps |
| Boss Spawn (local `0,0,10`) | Boss pedestal/platform | Boss enemy |
| Minion Spawns (local `±15,0,-7` and `±14,0,17`) | Minion patrol areas | Minion enemies |
| Elite Alcove (local `-7,0,26` or `7,0,26`) | Hidden alcove geometry | Elite enemy |
| Gate | Physical gate/door model | ForceField door with RequiredLevel |
| Landmark | Unique zone landmark | BillboardGui label |

### Road

| Anchor | What Blender builds | What code places |
|--------|--------------------|--------------------|
| Each of 22 ROUTE nodes | Road mesh, kerbs, lamps | Terrain ribbon, lamp parts |

---

## Part 4: Files to Read

### Claude Code reads these:

| File | Purpose |
|------|---------|
| `lemonade-game/ServerScriptService/WorldLayout.luau` | **Primary edit target** — all map data |
| `lemonade-game/ServerScriptService/WorldBuilder.server.luau` | How data becomes world |
| `lemonade-game/ServerScriptService/EnemyCombat.server.luau` | Enemy archetypes |
| `lemonade-game/ServerScriptService/BossRoomGate.server.luau` | Boss room gates |
| `lemonade-game/ServerScriptService/MerchantSystem.server.luau` | Merchant NPC |
| `lemonade-game/ServerScriptService/QuestService.server.luau` | Quest NPC |
| `lemonade-game/ReplicatedStorage/Config/QuestConfig.luau` | Quest definitions |
| `lemonade-game/Workspace/DayCycle.server.luau` | Lighting cycle |
| `MAP_REDESIGN_TEMPLATE.lua` | Fill-in data template |

### GPT-6 Astra reads these:

| File | Purpose |
|------|---------|
| This file (`MAP_REDESIGN_FRAMEWORK.md`) | Full architecture and constraints |
| `MAP_REDESIGN_TEMPLATE.lua` | Anchor point format and current values |
| `lemonade-game/ServerScriptService/WorldLayout.luau` | Current zone positions and sizes |
| `research/sword-rpg/sword-rpg-world-design.md` | World design best practices |
| `skills/roblox-map-design/SKILL.md` | Map design framework |
| `assets/swords/manifest.json` | Boss sword mesh metadata |

---

## Part 5: Current Map (Reference)

### Hub
- Center: `(0, 2, -178)`, Spawn: `(-8, 3.3, -181)`, Merchant: `(13, 2.8, -172)`
- 52-stud diameter cobblestone plaza

### Route
- 22 waypoints, ~400 studs total, ~29 studs wide
- Materials: Cobblestone → Ground → Rock → Snow → Basalt → Rock → Slate → Sandstone → Marble

### 8 Zones

| # | Name | Level | Center | Style | Boss |
|---|------|-------|--------|-------|------|
| 1 | Iron Lowlands | 1 | `(-72, 5, -104)` | Woodland | Boss_Gorgon (Lv10) |
| 2 | Briarwood | 8 | `(-166, 11, -126)` | Briar | RootWarden (Lv14) |
| 3 | Frostbound Glacier | 15 | `(-138, 14, -22)` | FrostPine | Boss_FrostRevenant (Lv25) |
| 4 | Sunken Marsh | 23 | `(-217, 20, 39)` | Marsh | DrownedBellwarden (Lv29) |
| 5 | Infernal Caldera | 30 | `(-125, 23, 78)` | Infernal | Boss_InfernalColossus (Lv45) |
| 6 | Stormwatch | 40 | `(-33, 26, 35)` | Storm | TempestWarden (Lv48) |
| 7 | Void Rift | 50 | `(10, 32, 132)` | Void | Boss_VoidWraith (Lv70) |
| 8 | Celestial Summit | 75 | `(121, 43, 70)` | Celestial | Boss_CelestialTitan (Lv100) |

### Constants (code-side, don't change without updating code)
- `ARENA_SIZE = 68` studs
- `DOOR_WIDTH = 14` studs
- `CAMP_OFFSET = 17` studs from road centerline
- `RESPAWN_DELAY = 5` seconds for enemy respawn

---

## Part 6: Execution Order

1. **GPT-6 Astra** designs the new map in Blender
2. **GPT-6 Astra** exports geometry as `.glb` files
3. **GPT-6 Astra** delivers anchor point data (Vector3 table) to Claude Code
4. **Claude Code** imports `.glb` into Roblox Studio
5. **Claude Code** updates `WorldLayout.luau` with new anchor points
6. **Claude Code** updates related files (QuestConfig, DayCycle, etc.)
7. **Claude Code** runs `rojo serve` and tests in Studio
8. **Claude Code** runs `graphify update .` and commits
9. Both sides iterate until it feels right
