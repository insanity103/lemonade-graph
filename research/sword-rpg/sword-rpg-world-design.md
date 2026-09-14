# Sword RPG World Design Reference

> Research compiled from Blox Fruits, King Legacy, Deepwoken, Grand Piece Online, and Shindo Life wiki sources. Last updated: 2026.

---

## Table of Contents

1. [Zone/Island Structure](#1-zoneisland-structure)
2. [Zone Identity & Theme](#2-zone-identity--theme)
3. [NPC Placement & Density](#3-npc-placement--density)
4. [Mob Placement](#4-mob-placement)
5. [Fast Travel & Movement](#5-fast-travel--movement)
6. [Secrets & Exploration Rewards](#6-secrets--exploration-rewards)
7. [Technical Considerations](#7-technical-considerations)
8. [World Design Template](#8-world-design-template)

---

## 1. Zone/Island Structure

### 1.1 How Many Zones Exist in Major Games?

| Game | Total Zones/Islands | Sea/Region Count | Structure Pattern |
|---|---|---|---|
| **Blox Fruits** | ~60 islands total | 3 Seas (First Sea: 15, Second Sea: 10, Third Sea: 8) + Sea Events islands | Islands in open ocean, separated by sea travel |
| **King Legacy** | ~40 islands | 3 Seas | Same sea-based structure as Blox Fruits |
| **Deepwoken** | 210+ locations | 2 Luminants + The Depths (2 layers) + Voidzones | Sailing between island clusters; Depths is underground layers |
| **Grand Piece Online** | ~35 islands | 2 Seas | Sea-based island archipelago |
| **Shindo Life** | ~20 villages/regions | Connected landmass with sub-regions | Walking between zones; Naruto-inspired villages |

**Key Finding:** The top Roblox RPGs use 25-60 primary zones organized into 2-3 major regions (seas/luminants). Each region contains 8-15 individual zones. This creates a "macro progression" (which sea you're in) and "micro progression" (which island within that sea).

### 1.2 Progression Order

**Blox Fruits First Sea (Level 1-700) — The Gold Standard:**

| Zone # | Island Name | Level Range | Theme |
|---|---|---|---|
| 1 | Pirate/Marine Starter Island | 1-10 | Tutorial beach |
| 2 | Jungle | 10-40 | Tropical forest |
| 3 | Pirate Village | 35-60 | Coastal pirate town |
| 4 | Desert | 60-90 | Arid wasteland |
| 5 | Frozen Village | 90-120 | Snowy tundra |
| 6 | Marine Fortress | 120-220 | Military stronghold |
| 7 | Lower Skylands | 150-200 | Floating sky islands |
| 8 | Prison | 220-300 | Island prison |
| 9 | Colosseum | 250-300 | Ancient arena |
| 10 | Magma Village | 300-400 | Volcanic village |
| 11 | Underwater City | 400-450 | Submerged civilization |
| 12 | Upper Skylands | 450-625 | Upper floating islands |
| 13 | Fountain City | 625-775 | Coastal city |

**Blox Fruits Second Sea (Level 700-1500):**
- Kingdom of Rose, Green Zone, Graveyard Island, Dark Arena, Snow Mountain, Hot and Cold, Cursed Ship, Ice Castle, Forgotten Island, Remote Island

**Blox Fruits Third Sea (Level 1500-2600+):**
- Port Town, Hydra Island, Great Tree, Floating Turtle, Haunted Castle, Castle on the Sea, Sea of Treats, Tiki Outpost

**Deepwoken Luminant System:**

| Region | Locations | Progression Mechanic |
|---|---|---|
| Etrean Luminant | Etris (hub), Isle of Vigils, Lower Erisia, Upper Erisia | Starting area; Power-based |
| Eastern Luminant | Aratel Island, Greathive Aratel, Summer Isle, Songseeker Wilds, The Monkey's Paw, Boatman's Watch, Voidheart | Unlocked via sailing; higher Power zones |
| The Depths (Layer 1) | Scyphozia — Lost Celtor, Castle Light | Death-based entry; high risk/reward |
| The Depths (Layer 2) | Eternal Gale — New Kyrsa, Cathedral of Ethiron | Deepest accessible layer |
| Voidzones | Random encounters in deep sea | Extreme difficulty; emergent |

### 1.3 Level Requirements Per Zone

**Blox Fruits Pattern:**
- Each island covers a level range of ~50-100 levels
- Level ranges overlap by 0-30 levels so players have choice
- Later zones have wider ranges (100-150 levels per zone) as leveling slows
- Sea transitions (First→Second, Second→Third) act as major milestones with level gates (700, 1500)
- Level cap is 2800 (can reach 3000 with Island Secrets)

**Deepwoken Pattern:**
- Uses "Power" instead of levels (Power 1-20)
- No explicit level gates per zone — danger is organic
- Players self-select zones based on combat capability
- The Depths serves as a "death penalty zone" — die twice without progression to enter

### 1.4 How Are Zones Connected?

| Connection Type | Games Using It | Pros | Cons |
|---|---|---|---|
| **Sea Travel (boats)** | Blox Fruits, King Legacy, GPO, Deepwoken | Exploration feel, Sea Events possible, large world feel | Can feel tedious, requires boat systems |
| **Walking** | Shindo Life, Deepwoken (islands) | Immersive, continuous world | Slower, harder to make large maps |
| **Portals/Teleporters** | Blox Fruits (Set Home Point), Deepwoken (Luminant teleport) | Fast, reduces travel fatigue | Breaks immersion if overused |
| **Sea Events** | Blox Fruits (ship raids, sea beasts, Mirage Island, etc.) | Dynamic encounters during travel | RNG-dependent, frustrating if blocking travel |
| **Whirlpools** | Deepwoken | Deterministic entry to sub-zones | Requires discovery |

**Blox Fruits Sea Travel Details:**
- Players purchase boats from Boat Dealers (present on most islands)
- Multiple boat tiers with increasing HP and speed
- Sea Danger Levels (1-6) increase as you sail further from safe zones
- Sea Events occur during sailing: Ship Raids, Sea Beasts, Sharks, Rough Seas, Terrorsharks
- Special islands can spawn as Sea Events: Mirage Island, Kitsune Island, Prehistoric Island, Frozen Dimension, Treasure Island

### 1.5 Zone Size Comparison

| Size Tier | Examples | Estimated Stud Size | Purpose |
|---|---|---|---|
| **Small** | Pirate Village, Frozen Village, Remote Island | 500-1000 studs | Quick quests, specific content |
| **Medium** | Jungle, Desert, Marine Fortress | 1000-2000 studs | Primary grinding zones |
| **Large** | Kingdom of Rose, Fountain City | 2000-4000 studs | Hub zones with shops + quests |
| **Extra Large** | Upper Skylands, Great Tree | 3000-5000 studs | Late-game exploration zones |
| **Sea/Overworld** | Open ocean between islands | 5000-10000+ studs | Travel corridors, Sea Events |

**Deepwoken Approach:** Uses "Luminants" as large seamless overworld maps containing multiple islands. Players sail between islands within a Luminant. Teleportation between Luminants loads a new map entirely.

---

## 2. Zone Identity & Theme

### 2.1 How Does Each Zone Feel Unique?

**Blox Fruits First Sea Theme Cycle (prevents visual fatigue):**
1. Tropical beach → Forest → Town → **Desert** → **Snow** → Military → **Sky** → Prison → Arena → **Volcano** → **Underwater** → **Upper Sky** → City

The pattern alternates between grounded biomes (forest, desert, snow) and fantastical/vertical environments (sky islands, underwater, volcanic). Every 3-4 zones introduce a dramatic environmental shift.

**Deepwoken Theme Approach:**
- Each island has unique environmental storytelling (Erisia is bandit-infested, Summer Isle is tropical, Greathive Aratel is a massive insect hive)
- The Depths uses fundamentally different aesthetics — darker, more alien
- Environmental hazards serve as natural zone identity (freezing, burning, drowning)

### 2.2 Environmental Storytelling

**Blox Fruits:**
- Each zone tells a One Piece-inspired story through NPC dialogue and environment
- Marine Fortress tells a military story; Prison tells a story of captivity
- Underwater City and Upper Skylands break the "grounded" expectation

**Deepwoken (Best-in-Class):**
- Books scattered across the world contain deep lore
- Each location has environmental details that tie into the greater narrative (Lost Celtor in the Depths, the Ministry's influence)
- NPC dialogue references world events, creating a living narrative
- Random Encounters add emergent storytelling

### 2.3 Zone-Specific Mechanics

| Game | Zone | Unique Mechanic |
|---|---|---|
| Blox Fruits | Underwater City | Underwater environment; Fish enemies |
| Blox Fruits | Skylands / Upper Skylands | Floating islands; fall damage risk |
| Blox Fruits | Magma Village | Enemies have 50% chance to spawn with Aura (counters Elemental immunity) |
| Blox Fruits | Sea (Danger Level 6) | Distorted/darkened vision, Sea Beast spawns |
| Deepwoken | The Depths | Death = character wipe; escape trial system |
| Deepwoken | Voidzones | Extreme danger; environmental hazards |
| Deepwoken | Eternal Gale (Layer 2) | Cold environment, unique enemies |
| Deepwoken | Any Luminant sea | Sailing hazards, whirlpools |

### 2.4 Hidden Areas and Secrets

**Blox Fruits:**
- Frozen Village has a secret cave housing the Ability Teacher (teaches Aura, Air Jump, Flash Step)
- Island Secrets system: complete all secrets in Sea 1 to raise level cap from 2800 to 3000
- Mirage Island spawns randomly as a Sea Event — invisible unless specific conditions are met
- Kitsune Island only spawns during Blue Moon
- Hidden bosses (The Saw spawns hourly in Middle Town with server-wide announcement)
- Jean-Luc Island: hidden island in First Sea

**Deepwoken:**
- The Understrand — hidden underwater area
- Duke Erisia's Laboratory — secret dungeon accessible through environmental puzzle
- Books scattered across 210+ locations serve as collectible lore
- Hidden NPCs that teach rare abilities
- Crypt of the Unbroken — was leaked by exploiters before official release

---

## 3. NPC Placement & Density

### 3.1 Where Are Quest Givers?

**Blox Fruits Pattern:**
- Quest givers are placed **at zone entrances/hubs** — typically near the dock or spawn point
- Each zone has 1-3 quest givers covering the zone's level range
- Quest givers reference specific enemies in the zone and direct players
- Higher zones may have quest givers scattered deeper in the zone

**Deepwoken Pattern:**
- NPCs are scattered organically throughout zones
- Some NPCs are in hub cities (Etris, Greathive Aratel), others are hidden in the wild
- Quest-like progression comes from talking to specific NPCs who give tasks
- Boss encounters are triggered by reaching certain locations or using certain items

### 3.2 Where Are Shops/Vendors?

**Blox Fruits:**
- **Sword Dealers** are on specific islands (Sword Dealer of the West in Pirate Village, Sword Dealer of the East in Frozen Village, Master Sword Dealer in Skylands)
- **Boat Dealers** on almost every island at docks
- **Blox Fruit Dealer** appears in specific locations, rotates stock
- **Fighting Style Teachers** are hidden in specific locations:
  - Dark Step Teacher: behind a fence near a tree in Pirate Village
  - Mad Scientist (Electric): at base of cloud stairs behind a floating rock in Skylands
  - Water Kung Fu: underwater in Underwater City area

**Deepwoken:**
- Shops in hub cities (Etris, Greathive Aratel)
- Blacksmith NPCs for weapon upgrades
- Trainers scattered across the world

### 3.3 NPC Dialogue Depth

**Blox Fruits:** Minimal — quest givers give 1-2 lines of dialogue directing players to kill specific enemies. Simple but effective for fast-paced grinding.

**Deepwoken:** Deep — NPCs reference world lore, have multiple dialogue options, some offer quests or sell items. Books found in the world contain extensive lore paragraphs.

### 3.4 Recommended NPC Density

| Zone Type | Quest Givers | Vendors | Trainers | Ambient NPCs |
|---|---|---|---|---|
| Starter Zone | 2-3 | 3-4 (weapons, boats, basic items) | 1 (tutorial) | 5-10 |
| Hub Zone | 3-5 | 5-8 (full shop variety) | 1-2 | 10-20 |
| Grinding Zone | 1-2 | 1-2 (boat dealer, basic vendor) | 0-1 | 3-5 |
| Boss Zone | 1 | 0-1 | 0 | 1-3 |
| Secret Zone | 0-1 | 0-1 (special vendor) | 0-1 | 0-2 |

---

## 4. Mob Placement

### 4.1 How Are Mobs Distributed?

**Blox Fruits:**
- Mobs are placed in **clusters** of 3-5 near the quest giver area
- Each zone has 2-3 enemy types (e.g., Jungle: Monkeys, Gorillas, Gorilla King boss)
- Enemy placement is designed so players can "group" them together for efficient AoE grinding
- Enemies respawn quickly (~10-15 seconds)
- Higher-level enemies in each zone are placed deeper in the zone or in separate sub-areas

### 4.2 Mob Level Scaling Per Zone

**Blox Fruits Scaling Pattern:**
- Zone enemies span ~30-60 levels within a zone
- Each zone has 2-3 enemy types, each 10-20 levels apart
- Example (First Sea leveling path):
  - Jungle: Monkeys (Lv. 14), Gorillas (Lv. 20), Gorilla King Boss (Lv. 25)
  - Desert: Desert Bandits (Lv. 60), Desert Officers (Lv. 70)
  - Marine Fortress: Chief Petty Officers (Lv. 120), Vice Admiral Boss (Lv. 130)
  - Upper Skylands: God's Guards (Lv. 450-525), Royal Soldiers (Lv. 525-625)

### 4.3 Elite/Champion Mob Placement

**Blox Fruits:**
- Each zone has 1 boss enemy
- Bosses have significantly more HP and deal more damage than regular mobs
- Bosses drop unique weapons/accessories (e.g., Gorilla King drops rare items, Chef drops Chop fruit)
- Boss respawn times are much longer than regular mobs (~minutes vs seconds)
- "Boss hopping" — players server hop to find available bosses for faster grinding

**Blox Fruits Raid Bosses (Special):**
- Greybeard (Lv. 750): spawns every 6 hours in Marine Fortress with server-wide message "Loud tremors are being heard across the seas..."
- The Saw (Lv. 100): spawns hourly in Middle Town with 15-minute timer
- These create server-wide events that bring players together

### 4.4 Boss Locations

| Boss Type | Location Pattern | Examples |
|---|---|---|
| Zone Boss | Fixed location within zone, always present | Gorilla King, Chef, Vice Admiral |
| Raid Boss | Fixed zone but timed spawn (hourly/daily) | The Saw, Greybeard |
| Sea Event Boss | Random spawn during sea travel | Sea Beast, Terrorshark, Rumbling Waters |
| World Boss | Fixed location, requires multiple players | Deepwoken's Ethiron (Cathedral of Ethiron) |
| Depths Boss | Special conditions to encounter | Deepwoken's Chaser (Second Layer) |

---

## 5. Fast Travel & Movement

### 5.1 Fast Travel Systems

**Blox Fruits:**
- **Set Home Point**: NPC on every island (except hidden ones). Players set respawn/teleport point
- **Boats**: 5 tiers with increasing speed/HP. Primary travel method between islands
- **Flight abilities**: Light fruit [F] ability provides fast flight (best early-game travel)
- **Portal Fruit**: Dimensional Rift [V] allows teleportation and event bypassing
- **No global teleport** (intentional — sea travel drives Sea Events and engagement)

**Deepwoken:**
- **Sailing**: Primary overworld travel. Players build/buy boats
- **Whirlpools**: Fixed locations that teleport to The Depths
- **Luminant Teleportation**: Loading screen between major regions (Etrean ↔ Eastern)
- **No fast travel within Luminants** — encourages exploration

### 5.2 Movement Abilities

**Blox Fruits:**
- Basic: Walk/Sprint, Dash
- Unlockable: Air Jump, Flash Step (from Ability Teacher in Frozen Village's secret cave)
- Fruit-based: Flight (Light, Buddha V2, Dragon, Kitsune, etc.)
- Race abilities: Rabbit race speed boost, Angel flight, Shark water immunity

**Deepwoken:**
- Basic: Walk/Sprint, Dodge
- Unlockable: Various Talents and Mantras for mobility
- Environmental: Climbing, swimming (with drowning risk)

### 5.3 How Long to Traverse the Full Map?

**Blox Fruits First Sea:**
- By boat (basic): ~10-15 minutes end-to-end
- By flight (Light fruit): ~3-5 minutes end-to-end
- This creates a meaningful but not frustrating travel time

**Deepwoken:**
- Sailing across a single Luminant: ~5-10 minutes
- Full map traversal (all Luminants): ~15-20 minutes
- Depths exploration: varies wildly based on skill and encounters

### 5.4 Mount/Vehicle Systems

**Blox Fruits Boats (5 tiers):**
1. Dinghy — cheap, slow, low HP
2. Sloop — moderate speed, moderate HP
3. Brigantine — good speed, good HP
4. Cutter — fast, high HP
5. Various premium/special boats

**Deepwoken:**
- Player-built/customizable boats
- Different boat sizes affect sailing speed and combat capability
- Boats can be destroyed by sea monsters

---

## 6. Secrets & Exploration Rewards

### 6.1 Hidden Bosses

| Game | Boss | Trigger | Reward |
|---|---|---|---|
| Blox Fruits | The Saw | Spawns hourly, server-wide alert | Shark Saw sword |
| Blox Fruits | Greybeard | Spawns every 6 hours in Marine Fortress | Bisento V2 upgrade |
| Blox Fruits | Mirage Island Boss | Mirage Island spawns as Sea Event | Race Awakening materials |
| Deepwoken | Duke Erisia | Access hidden laboratory | Unique loot, progression |
| Deepwoken | Chaser | Reach Second Layer of Depths | High-tier rewards |

### 6.2 Secret Rooms/Passages

**Blox Fruits:**
- Ability Teacher cave in Frozen Village (hidden behind environment)
- Various island interiors with hidden NPCs
- Dojo Vault (portal-accessible secret area)

**Deepwoken:**
- Extensive hidden dungeon systems throughout islands
- The Understrand (underwater hidden area)
- Interior floors of buildings (e.g., Etrean Luminant Inside Floor 0, 1, 2)
- Crypt of the Unbroken, Crucible of the Unbroken — hidden dungeons

### 6.3 Easter Eggs

**Blox Fruits:**
- Jean-Luc Island (hidden island in First Sea)
- Campfire island
- Various references to One Piece lore embedded in NPC names and locations

**Deepwoken:**
- Books scattered across 210+ locations with deep lore
- Random Encounters that appear/disappear
- Beloved Zofia ghost encounter

### 6.4 Exploration-Specific Rewards

**Blox Fruits Island Secrets:**
- Completing ALL Island Secrets in Sea 1 raises the level cap from 2800 to 3000
- Hidden chests (Chests give money; farming chests in Pirate Village is an early-game strategy)
- Sea Events during sailing: Treasure Island spawns with loot, Kitsune Island has exclusive items

**Blox Fruits Sea Events (exploration rewards):**

| Sea Event | Type | Reward |
|---|---|---|
| Treasure Island | Random spawn while sailing | Money and items |
| Mirage Island | Rare Sea Event spawn | Race Awakening quest materials |
| Kitsune Island | Blue Moon only spawn | Exclusive items |
| Prehistoric Island | Random spawn (Third Sea) | Prehistoric-themed rewards |
| Frozen Dimension | Random spawn (Third Sea) | Leviathan encounter, rare loot |
| Haunted Shipwreck | Random spawn (Third Sea) | Ship exploration loot |

### 6.5 Treasure/Puzzle Mechanics

**Blox Fruits:**
- Chest farming: physical chests scattered across islands that give money
- Island Secrets: puzzle-based objectives hidden on each island
- Sea Exploration Groups: party system for sea event hunting

**Deepwoken:**
- Books as collectible lore (exploration reward)
- Alchemy ingredients scattered across the world
- Ores and crafting materials found in specific locations
- Knowledge system: discovering locations/lore grants progression bonuses

---

## 7. Technical Considerations

### 7.1 StreamingEnabled for Large Worlds

**Blox Fruits Approach:**
- Uses a **server-per-sea model**: each sea (First, Second, Third) is a separate server/experience
- Within each sea, islands are relatively compact (~500-5000 studs each)
- StreamingEnabled is used to manage island loading as players travel
- Sea between islands acts as a buffer zone with minimal content (only Sea Events)

**Deepwoken Approach:**
- Each Luminant is a separate server with a large continuous map
- StreamingEnabled is essential for the large overworld
- The Depths is a separate map entirely
- Interior spaces are handled as sub-places or streaming zones

**Best Practice:**
- Enable `StreamingEnabled` with `StreamingMinRadius` and `StreamingTargetRadius` tuned per zone size
- Use separate Place files for major regions (seas/luminants) rather than one massive place
- Islands should be self-contained enough to stream in/out cleanly

### 7.2 Server Capacity

**Blox Fruits:**
- ~12-24 players per server per sea
- Private servers available (important for grinding without PvP interruptions)
- Sea Events scale with player count (more players = higher spawn rates)

**Deepwoken:**
- ~20-30 players per server
- PvP is open-world (creates organic emergent encounters)
- No private servers (intentional — PvP is core to the experience)

### 7.3 Zone Instancing for Boss Fights

**Blox Fruits:**
- No instancing — all boss fights happen in the open world
- Boss respawning on timers prevents camping
- Server hopping allows players to find available bosses

**Deepwoken:**
- Some boss encounters are in semi-instanced spaces (Duke Erisia's Manor, Cathedral of Ethiron)
- The Depths acts as a shared high-risk zone
- Dungeons can have instanced elements

### 7.4 Performance Optimization for Large Maps

**Key Patterns Across Top Games:**
1. **LOD (Level of Detail)**: Distant islands use lower-poly models
2. **Part streaming**: Only load island geometry near the player
3. **Water optimization**: Ocean is a simple plane/shader, not complex geometry
4. **Mob pooling**: Enemies respawn in-place rather than being created/destroyed
5. **Server-per-region**: Separate servers for major zones reduces per-server load
6. **Minimal ambient NPCs**: Keep non-combat NPCs low to reduce server overhead

---

## 8. World Design Template

### 8.1 Recommended Zone Count

| Game Scale | Total Zones | Regions | Zones per Region | Target Playtime to Clear |
|---|---|---|---|---|
| **Small (MVP)** | 15-20 | 2 | 7-10 | 10-20 hours |
| **Medium** | 25-40 | 3 | 8-13 | 30-60 hours |
| **Large (Blox Fruits scale)** | 40-60 | 3-4 | 10-15 | 80-150+ hours |

### 8.2 Recommended Progression Order (Medium-Scale Sword RPG)

**Region 1: Starter Sea (Levels 1-700)**

| Zone | Name | Levels | Theme | Key Features |
|---|---|---|---|---|
| 1 | Starter Island | 1-10 | Beach/tutorial | Tutorial NPCs, basic enemies |
| 2 | Forest Isle | 10-35 | Tropical forest | First real combat, Gorilla-type enemies |
| 3 | Pirate Cove | 30-60 | Coastal village | First sword vendor, Dark Step-style trainer |
| 4 | Sand Barrens | 55-90 | Desert | Environmental shift, ranged enemies |
| 5 | Frost Peak | 85-120 | Snowy mountain | Hidden cave with trainer (Aura-equivalent) |
| 6 | Fort Ironclad | 115-200 | Military base | Tankier enemies, boss with unique weapon |
| 7 | Skyreach | 180-280 | Floating islands | Vertical exploration, fall damage risk |
| 8 | The Gaol | 270-370 | Prison | Tight corridors, elite prisoners |
| 9 | Magma Forge | 350-470 | Volcanic | Aura-enemies (counter to Elemental builds) |
| 10 | Depths Below | 450-550 | Underwater city | Underwater mechanics, fish enemies |
| 11 | Cloudspire | 530-650 | Upper sky islands | Late-game hub, best shops |
| 12 | Crown City | 630-775 | Coastal metropolis | Sea gate quest to Region 2 |

**Region 2: Advanced Sea (Levels 700-1500)**

| Zone | Name | Levels | Theme | Key Features |
|---|---|---|---|---|
| 13 | Rose Kingdom | 700-850 | Grand city | New hub, upgraded shops, raid access |
| 14 | Toxic Marsh | 830-950 | Swamp | Poison mechanics, unique materials |
| 15 | Bone Yard | 930-1050 | Graveyard | Undead enemies, bone currency |
| 16 | Dark Coliseum | 1000-1100 | Arena | PvP zone, tournament rewards |
| 17 | Storm Peaks | 1080-1200 | Lightning mountain | Environmental lightning hazard |
| 18 | Dual Zone | 1180-1300 | Hot/Cold split | Half fire, half ice biome |
| 19 | Ghost Ship | 1280-1380 | Haunted vessel | Travel zone, unique boss |
| 20 | Frozen Citadel | 1360-1450 | Ice castle | End-region boss, gate to Sea 3 |

**Region 3: Endgame Sea (Levels 1500-2600)**

| Zone | Name | Levels | Theme | Key Features |
|---|---|---|---|---|
| 21 | Harbor Town | 1500-1650 | New starting hub | Endgame hub, rare vendors |
| 22 | Serpent Isle | 1630-1800 | Monster island | Large-scale enemies |
| 23 | World Tree | 1780-1950 | Giant tree | Vertical zone, climbing |
| 24 | Turtle Haven | 1930-2100 | Floating turtle island | Moving platform, rare spawns |
| 25 | Haunted Keep | 2080-2250 | Gothic castle | Bone farming, Death King NPC |
| 26 | Ocean Throne | 2230-2400 | Sea fortress | Raid boss access |
| 27 | Candy Sea | 2380-2550 | Sweet/treat theme | Lighter tone contrast, unique materials |
| 28 | Outpost Omega | 2530-2650+ | Final zone | Max-level content, endgame bosses |

**Hidden/Secret Zones (across all regions):**
- Mirage Island (rare sea event spawn)
- Hidden cave systems under starter zones
- Raid instance zones (accessible from hub cities)
- Secret boss arenas

### 8.3 Zone Size Guidelines

| Zone Role | Recommended Size (studs) | Content Density | Enemy Count |
|---|---|---|---|
| **Tutorial Zone** | 500-800 | Very High (lots of NPCs, signs) | 5-10 enemies |
| **Hub Zone** | 1500-3000 | Very High (shops, quest givers, trainers) | 0-5 enemies |
| **Standard Grinding Zone** | 1000-2000 | Medium (2-3 enemy clusters, 1-2 quest givers) | 10-20 enemies |
| **Large Exploration Zone** | 2000-4000 | Low-Medium (spread out, secrets hidden) | 15-30 enemies |
| **Boss Arena Zone** | 300-800 | Focused (boss + minions) | 1 boss + 5-10 minions |
| **Secret Zone** | 200-1000 | Variable (may have unique vendor or puzzle) | 0-10 enemies |
| **Sea/Travel Zone** | 5000-10000 | Very Low (just water + Sea Events) | Sea Event spawns only |

### 8.4 Exploration Reward Density

**Recommended ratio: 1 hidden/special reward per 2-3 "standard" zones.**

| Reward Type | Frequency | Examples |
|---|---|---|
| Hidden Trainer/Ability | 1 per region (3-4 total) | Secret fighting style teacher, Aura unlock |
| Hidden Boss | 1 per 3-4 zones | Hourly/daily spawn bosses with unique drops |
| Secret Room/Passage | 1 per 2-3 zones | Hidden caves, behind waterfalls, inside buildings |
| Easter Egg | 1-2 per region | Lore references, joke NPCs, rare encounters |
| Sea/Travel Event | 3-5 per region | Treasure Island, Mirage equivalent, mini-bosses |
| Collectible System | Throughout entire game | Books, lore items, materials (like Deepwoken's books) |
| Exploration-Gated Content | 1-2 per region | Level cap increase, race awakening, special quest lines |

### 8.5 Environmental Rhythm Pattern

**Follow a 3-zone cycle to prevent visual fatigue:**

```
Zone A: Grounded/natural biome (forest, desert, snow)
Zone B: Built environment (village, fortress, prison)  
Zone C: Fantastical/breakout zone (sky island, underwater, volcano)
→ Repeat with escalating scale
```

Every 4th zone should feel like a "milestone" — a dramatic environmental shift that signals to the player they've made real progress.

### 8.6 Sea Travel Design (for ocean-based RPGs)

**Minimum viable sea system:**
1. 3+ boat tiers (speed/HP progression)
2. Sea Danger Level system (1-6, increases distance from safe zones)
3. 2-3 Sea Event types (enemies, environmental, treasure)
4. 1 rare island spawn event per region
5. Boat dealer NPC on every island

**Sea Events (minimum set per region):**
- Common: Sharks/Piranhas, Rough Seas
- Uncommon: Ship Raid, Sea Beast
- Rare: Treasure Island spawn
- Legendary: Secret island spawn (region-exclusive)

---

## Sources

- Blox Fruits Wiki — Islands category: https://blox-fruits.fandom.com/wiki/Category:Islands
- Blox Fruits Wiki — First Sea: https://blox-fruits.fandom.com/wiki/First_Sea
- Blox Fruits Wiki — Leveling Guide: https://blox-fruits.fandom.com/wiki/Leveling_Guide
- Blox Fruits Wiki — Sea Events: https://blox-fruits.fandom.com/wiki/Sea_Events
- Blox Fruits Wiki — Locations: https://blox-fruits.fandom.com/wiki/Locations
- King Legacy Wiki — Main: https://king-legacy.fandom.com/wiki/King_Legacy_Wiki
- King Legacy Wiki — Map: https://king-legacy.fandom.com/wiki/Map
- Deepwoken Wiki — Main: https://deepwoken.fandom.com/wiki/Deepwoken_Wiki
- Deepwoken Wiki — Locations: https://deepwoken.fandom.com/wiki/Locations
- Deepwoken Wiki — The Depths: https://deepwoken.fandom.com/wiki/The_Depths
- Deepwoken Wiki — Maps: https://deepwoken.fandom.com/wiki/Maps

---

*This document is a design reference. Zone names in the template section are fictional examples inspired by patterns found in the researched games. Use the data tables and ratios as starting points; playtest and adjust based on your specific game's pacing.*
