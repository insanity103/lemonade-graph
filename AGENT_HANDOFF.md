# AI Agent Handoff Guide

> **Current task (2026-09-15):** Read [CLAUDE_IMPLEMENTATION_HANDOFF.md](CLAUDE_IMPLEMENTATION_HANDOFF.md)
> before the historical overview below. The new Legendary Swords inspired plan supersedes the
> old map direction. The active gameplay-only baseline is documented in [GAMEPLAY_ONLY.md](GAMEPLAY_ONLY.md).

> **Purpose**: This document is your onboarding when you pull `lemonade-graph`. Read it top to bottom before touching any code. It tells you what exists, where to find it, what the research says, and what rules you must never break.

---

## Quick Start

1. **Clone this repo** — it's a Rojo-compatible Roblox Studio project with Luau source code, design research, AI skills, and a knowledge graph.
2. **This is a Roblox sword RPG called "Lemonade"** inspired by *The Legendary Swords RPG* (Roblox Game ID: 60654525). The game lives in `lemonade-game/` (~8,000 lines of Luau).
3. **Skills** in `skills/` — seven Roblox-domain skill directories with `SKILL.md` and `references/` subfolders. Load any skill at prompt time for domain guidance.
4. **Research** in `research/sword-rpg/` — 24 game design analysis documents (12,000+ lines) covering combat, economy, progression, UI, anti-exploit, and the full Legendary Swords breakdown.
5. **Graph** in `graphify-out/` — pre-built knowledge graph (200 nodes, 218 edges, 38 communities). Query with the graphify skill: `graphify query "<question>"`.
6. **Read `CLAUDE.md` first** — it contains the original project instructions and graphify usage rules that guided all code generation.
7. **Read `manual_trace.md` second** — it tracks open bugs and resolved issues across rebuilds.

---

## Repository Structure

```
lemonade-graph/
|
+-- CLAUDE.md                              # Master project instructions / graphify rules
+-- AGENT_HANDOFF.md                       # This file — AI onboarding guide
+-- manual_trace.md                        # Bug tracker across AI rebuilds (open + resolved)
+-- default.project.json                   # Rojo project config (maps folders -> Roblox services)
+-- build_world_semantic.py                # Python: generates semantic world docs from place.json
+-- dump_scripts.py                        # Python: extracts script metadata
+-- .gitignore
|
+-- lemonade-game/                         # === ROBLOX GAME SOURCE (Rojo project) ===
|   +-- Workspace/
|   |   +-- DayCycle.server.luau           # Day/night cycle
|   |
|   +-- ServerScriptService/               # Server-authoritative game logic
|   |   +-- EnemyCombat.server.luau        # Enemy AI, hit detection, damage (LARGEST)
|   |   +-- WorldLayout.luau               # World generation/layout
|   |   +-- LevelingSystem.server.luau     # XP, levels, stat points
|   |   +-- InventoryService.luau          # Shared inventory module
|   |   +-- MerchantSystem.server.luau     # Shop/upgrade system
|   |   +-- SwordDropSystem.server.luau    # Loot drops, rarity, modifiers
|   |   +-- PlayerDataService.luau         # Cross-session save/load
|   |   +-- SwordSystem.server.luau        # Sword equipping, damage calc
|   |   +-- BossRoomGate.server.luau       # Boss arena gating
|   |   +-- RuntimeBootstrap.server.luau   # Startup init sequence
|   |   +-- RebirthSystem.server.luau      # Prestige/rebirth loop
|   |   +-- BossSwordFactory.luau          # Boss weapon construction
|   |   +-- CombatUtil.luau                # Shared combat helpers (isEnemy, etc.)
|   |   +-- InventorySystem.server.luau    # Inventory event handler
|   |   +-- PlayerDataStore.server.luau    # DataStore wrapper
|   |   +-- WorldBuilder.server.luau       # Delegates to WorldLayout
|   |
|   +-- ReplicatedStorage/                 # Shared (server + client) modules
|   |   +-- AnimationController.luau       # Animation state machine
|   |   +-- Config/
|   |   |   +-- BossWeapons.luau           # Boss weapon definitions
|   |   |   +-- WeaponModifiers.luau       # Prefix/suffix modifier system
|   |   |   +-- RebirthConfig.luau         # Rebirth thresholds & perks
|   |   |   +-- MerchantConfig.luau        # Shop item catalog
|   |   |   +-- SaveConfig.luau            # Default save schema
|   |   |   +-- Items.luau                 # General item definitions
|   |   |   +-- Sword.luau                 # Base sword stats
|   |   +-- Animations/
|   |       +-- Sword Attack Animation.luau # Attack anim data
|   |
|   +-- StarterPlayer/StarterPlayerScripts/ # Client-side scripts
|   |   +-- MainMenuGui.client.luau        # Main menu UI (LARGEST CLIENT)
|   |   +-- MerchantGui.client.luau        # Shop UI
|   |   +-- CombatController.client.luau   # Client combat input
|   |   +-- SwordDropToast.client.luau     # Loot notification popup
|   |   +-- LevelProgressGui.client.luau   # XP bar UI
|   |   +-- BossDoorClient.client.luau     # Boss door interaction UI
|   |   +-- LevelUpBurst.client.luau       # Level-up VFX
|   |   +-- DamageNumbers.client.luau      # Floating damage text
|   |   +-- XPGainUI.client.luau           # XP gain popup
|   |   +-- GoldNumbers.client.luau        # Gold pickup numbers
|   |   +-- RunController.client.luau      # Sprint/run input
|   |
|   +-- StarterPack/ClassicSword/          # Starter weapon tool
|   |   +-- SwordClient.client.luau        # Client sword logic
|   |   +-- MouseIcon.client.luau          # Custom cursor
|   |
|   +-- world/                             # Semantic world documentation
|       +-- place.json                     # Full place hierarchy (JSON export)
|       +-- Workspace.md                   # Workspace instances documented
|       +-- ServerScriptService.md         # Scripts documented
|       +-- ReplicatedStorage.md           # Shared modules documented
|       +-- StarterPlayer.md               # Client scripts documented
|       +-- StarterPack.md                 # Starter tools documented
|       +-- ServerStorage.md               # Server templates documented
|       +-- Lighting.md                    # Lighting instances
|       +-- Terrain.md                     # Voxel terrain metadata
|
+-- skills/                                # === ROBLOX DOMAIN SKILLS ===
|   +-- roblox-game-dev/SKILL.md           # Master Roblox game dev agent
|   +-- roblox-luau/SKILL.md               # Luau scripting patterns
|   +-- roblox-systems/SKILL.md            # Game systems architecture
|   +-- roblox-ui/SKILL.md                 # UI/UX design & implementation
|   +-- roblox-debug/SKILL.md              # Debugging & troubleshooting
|   +-- roblox-optimize/SKILL.md           # Performance & anti-exploit
|   +-- roblox-map-design/SKILL.md         # Map, level, and world design
|
+-- research/sword-rpg/                    # === GAME DESIGN RESEARCH (24 files) ===
|   +-- sword-rpg-INDEX.md                 # Master index & key findings
|   +-- (24 documents — see Research Index below)
|
+-- graphify-out/                          # === KNOWLEDGE GRAPH ===
|   +-- graph.json                         # Live graph (200 nodes, 218 edges, 38 communities)
|   +-- graph.html                         # Visual HTML rendering
|   +-- GRAPH_REPORT.md                    # Latest report with community hubs & god nodes
|   +-- manifest.json                      # File hashes for incremental updates
|   +-- cost.json                          # Token cost tracking
|   +-- 2026-09-10/                        # Snapshot: 190 nodes, 326 edges (code-only)
|   +-- 2026-09-11/                        # Snapshot: 433 nodes, 666 edges (code + tools + assets)
|
+-- assets/                                # === 3D ASSETS ===
|   +-- swords/
|       +-- Boss_CelestialTitan.glb        # Celestial Titan boss sword
|       +-- Boss_FrostRevenant.glb         # Frost Revenant boss sword
|       +-- Boss_Gorgon.glb                # Gorgon/Warlord greatsword
|       +-- Boss_InfernalColossus.glb      # Infernal Colossus boss sword
|       +-- Boss_VoidWraith.glb            # Void Wraith boss sword
|       +-- manifest.json                  # Mesh metadata (dimensions, grip, guard, handle)
|       +-- preview.png                    # Preview render of all swords
|
+-- tools/                                 # === UTILITY SCRIPTS ===
|   +-- sword_forge.py                     # Procedural sword mesh generator (Python)
|
+-- .claude/
    +-- settings.json                      # Claude Code project settings
```

---

## Skills Usage

Seven Roblox-domain skills in `skills/`. Each has a `SKILL.md` (load instructions + triggers) and a `references/` folder (domain-specific reference docs). Load the skill at prompt time to inject guidance into your context window.

### 1. `roblox-game-dev` — Master Roblox Game Dev Agent
- **When to load**: Starting any new game feature, system, or architecture decision.
- **What it covers**: Game design, scripting, map building, system architecture, debugging, and optimization as a unified agent.
- **Key references**: `skills/roblox-game-dev/SKILL.md`
- **Triggers on**: Roblox, Luau, Roblox Studio, game passes, DataStore, RemoteEvent, obby, tycoon, Roblox API classes.
- **Routes to**: `roblox-map-design`, `roblox-luau`, or `roblox-systems` when the task matches their scope.

### 2. `roblox-luau` — Luau Scripting Patterns
- **When to load**: Writing or reviewing any Luau script.
- **What it covers**: Production-quality Luau with correct script types (server `.server.luau`, client `.client.luau`, shared `.luau`), API patterns, anti-exploit validation, type annotations, and performance idioms.
- **Key references**:
  - `skills/roblox-luau/references/combat-code.md` — combat script patterns
  - `skills/roblox-luau/references/datastore-pattern.md` — DataStore save/load
  - `skills/roblox-luau/references/remote-pattern.md` — RemoteEvent communication
  - `skills/roblox-luau/references/tycoon-code.md` — tycoon scripting patterns
  - `skills/roblox-luau/references/horror-code.md` — horror game patterns
  - `skills/roblox-luau/references/obby-code.md` — obby scripting patterns
- **Triggers on**: Luau, Roblox scripting, RemoteEvent pattern, DataStore code, client/server script.

### 3. `roblox-systems` — Game Systems Architecture
- **When to load**: Designing or implementing any game system — shops, inventories, combat, NPC AI, progression, data persistence, multiplayer.
- **What it covers**: Complete system architecture with proper data flow, server authority, and anti-exploit validation.
- **Key references**:
  - `skills/roblox-systems/references/combat.md` — combat framework
  - `skills/roblox-systems/references/data-persistence.md` — DataStore + session locking
  - `skills/roblox-systems/references/inventory.md` — inventory management
  - `skills/roblox-systems/references/npc-ai.md` — NPC state machine
  - `skills/roblox-systems/references/progression.md` — XP/level/rebirth
  - `skills/roblox-systems/references/shop-economy.md` — shop + economy
  - `skills/roblox-systems/references/tycoon.md` — tycoon mechanics
- **Triggers on**: game system, shop system, inventory, combat system, tycoon builder, NPC AI, leaderboard, game pass, multiplayer system.

### 4. `roblox-ui` — UI/UX Design & Implementation
- **When to load**: Building any GUI, HUD, menu, or mobile-friendly layout.
- **What it covers**: ScreenGui/BillboardGui/SurfaceGui hierarchy, UIListLayout responsiveness, UI animation, input handling, accessibility, and mobile optimization.
- **Key references**:
  - `skills/roblox-ui/references/ui-patterns.md` — common UI patterns
  - `skills/roblox-ui/references/ui-animation.md` — tweening and animation
- **Triggers on**: Roblox UI, menu design, HUD, shop UI, inventory screen, dialog box, mobile UI, GuiObject.

### 5. `roblox-debug` — Debugging & Troubleshooting
- **When to load**: Diagnosing bugs, errors, unexpected behavior, or broken scripts.
- **What it covers**: Output log analysis, common Luau errors, Roblox API pitfalls, client/server debugging, and DataStore troubleshooting.
- **Key references**:
  - `skills/roblox-debug/references/error-reference.md` — error catalog
- **Triggers on**: Roblox error, script not working, debug Roblox, fix Luau error, Output log, broken Roblox script.

### 6. `roblox-optimize` — Performance & Anti-Exploit
- **When to load**: Performance work, reducing lag, hardening anti-exploit, or production-readiness review.
- **What it covers**: FPS optimization, ping reduction, memory leak detection, exploit vulnerability analysis, and script efficiency improvements.
- **Key references**:
  - `skills/roblox-optimize/references/performance-checklist.md` — optimization checklist
- **Triggers on**: Roblox optimization, reduce lag, improve FPS, anti-exploit, memory leak, performance review, slow Roblox game.

### 7. `roblox-map-design` — Map, Level & World Design
- **When to load**: Building worlds, terrain, level layouts, obbies, arenas, or dungeons.
- **What it covers**: Structured beat sheets for level flow, procedural placement scripts, terrain performance, and spatial game design.
- **Key references**:
  - `skills/roblox-map-design/references/arena-patterns.md` — arena design
  - `skills/roblox-map-design/references/open-world-patterns.md` — open world zones
  - `skills/roblox-map-design/references/obby-patterns.md` — obby course design
  - `skills/roblox-map-design/references/tycoon-patterns.md` — tycoon plot layout
- **Triggers on**: map design, level layout, obby builder, arena design, world building, spatial game design.

---

## Research Index

24 documents in `research/sword-rpg/` totaling 12,000+ lines of game design intelligence compiled from wiki data, official Roblox documentation, and community analysis across 10+ Roblox sword RPG games (Blox Fruits, King Legacy, Grand Piece Online, Deepwoken, Shindo Life, Rogue Lineage, Arcane Odyssey, Type Soul, Project Slayers, and more).

### Core Analysis (Start Here)

| # | File | Summary |
|---|------|---------|
| 1 | `sword-rpg-INDEX.md` | Master index of all 24 research documents with quick-reference table and key findings summary |
| 2 | `sword-rpg-popular-games.md` | Gameplay loops of top 5 Roblox sword RPGs, common patterns, addictive hooks, and player complaints |
| 3 | `sword-rpg-player-sentiment.md` | What players love/hate across 10+ games, opportunity gaps, and anti-patterns to avoid |
| 4 | `sword-rpg-hidden-gems.md` | 10 underrated games with stealable mechanics: Deepwoken parry, Rogue Lineage lineage system, Arcane Odyssey imbuement |

### The Big Three Systems

| # | File | Summary |
|---|------|---------|
| 5 | `sword-rpg-combat-systems.md` | M1 combos, skills, hit registration, parry/block/feint, damage calculation, and the ideal combat system (932 lines) |
| 6 | `sword-rpg-rebirth-analysis.md` | Additive vs reset rebirth, V4 awakening gold standard, cost-to-reward ratios, and critical design rules |
| 7 | `sword-rpg-progression-curves.md` | XP formulas, level caps, pacing, dead zones, 80-300hr to max level, and design templates |

### Game Systems

| # | File | Summary |
|---|------|---------|
| 8 | `sword-rpg-economy-design.md` | Multi-currency architecture, earning rates, sink ratios, inflation control, and premium currency design |
| 9 | `sword-rpg-weapon-acquisition.md` | Drop rates, boss loot tables, rarity tiers, enhancement layers, and pity system design |
| 10 | `sword-rpg-boss-pve-design.md` | Boss HP curves, attack patterns, phase thresholds, raid structure, and anti-farm mechanics |
| 11 | `sword-rpg-pvp-design.md` | PvP mode taxonomy, balance frameworks, skill vs stats, ranking systems, and anti-cheat measures |
| 12 | `sword-rpg-world-design.md` | Zone structure (60 islands/3 seas), NPC/mob placement, fast travel, secrets, and technical architecture |

### Player Experience

| # | File | Summary |
|---|------|---------|
| 13 | `sword-rpg-onboarding-FTUE.md` | First 5min/30min/1hr flow, "Kill 5 Bandits" pattern, drop-off points, and the no-forced-tutorial rule |
| 14 | `sword-rpg-ui-ux-patterns.md` | HUD layout, damage numbers, menus, mobile adaptation, and the accumulating damage counter pattern (990 lines) |
| 15 | `sword-rpg-retention-community.md` | Daily loops, crew/alliance social systems, content cadence, churn analysis, and community health |

### Growth & Monetization

| # | File | Summary |
|---|------|---------|
| 16 | `sword-rpg-monetization.md` | Game pass pricing, developer products, battle pass gap, F2P/P2W spectrum, and ethical monetization guidelines |
| 17 | `sword-rpg-growth-strategy.md` | Update cadence, YouTube code distribution, Discord community tactics, and zero-cost viral growth strategies |
| 18 | `sword-rpg-anti-exploit-architecture.md` | 5-layer server authority model, RemoteEvent security, exploit detection, punishment ladders, and Luau code patterns (2096 lines) |

### The Legendary Swords Deep Dive (Inspiration Game)

| # | File | Summary |
|---|------|---------|
| 19 | `sword-rpg-legendary-swords-SYNTHESIS.md` | Complete picture of The Legendary Swords RPG — the direct inspiration game for Lemonade. **Read this first for context.** |
| 20 | `sword-rpg-legendary-swords-mechanics.md` | Every game system documented: combat, drop rates, rebirth formulas, merchant mechanics, and boss fights |
| 21 | `sword-rpg-legendary-swords-bugs.md` | 50 known bugs cataloged from the original game so the spiritual successor can avoid them all |
| 22 | `sword-rpg-legendary-swords-core.md` | Core gameplay systems, progression, and design philosophy of The Legendary Swords RPG |
| 23 | `sword-rpg-legendary-swords-community.md` | Community analysis, player sentiment, and social features of the original Legendary Swords |
| 24 | `sword-rpg-legendary-swords-wiki.md` | Full wiki data extraction from the Legendary Swords Fandom wiki |

---

## Legendary Swords Reference

**"Sword RPG: Legendary Swords"** (Roblox Game ID: 60654525) is the direct inspiration game for Lemonade. All design decisions in this codebase trace back to research on how Legendary Swords works and what it does well.

### What to Read First

1. **`research/sword-rpg/sword-rpg-legendary-swords-SYNTHESIS.md`** — the complete picture. Start here. It distills every other Legendary Swords file into one coherent reference.
2. **`research/sword-rpg/sword-rpg-legendary-swords-bugs.md`** — 50 bugs to avoid. Every known bug from the original game and its fan projects, cataloged so Lemonade doesn't repeat them.
3. **`research/sword-rpg/sword-rpg-legendary-swords-mechanics.md`** — every system documented: combat combos, drop rates, rebirth formulas, merchant mechanics, boss fights, and stat scaling.

### Key Formulas

| Formula | Description | Location |
|---------|-------------|----------|
| `drop_rate = 1 / (base_chance - rebirth_level)` | Each rebirth makes rare drops more likely. Clamped so denominator never goes below 1. | `sword-rpg-legendary-swords-mechanics.md` |
| `damage = (base + 5 * strength) * (1 + 0.12 * weapon_level) * sword_mult * rebirth_mult * crit_mult` | Unified damage formula used by both armed and unarmed paths. | `lemonade-game/ServerScriptService/CombatUtil.luau` |
| `xp_for_level = floor(100 * level^1.5)` | XP curve: each level requires more XP than the last. | `lemonade-game/ServerScriptService/LevelingSystem.server.luau` |
| `rebirth_cost = 1000 * rebirth_level^2` | Rebirth cost scales quadratically. | `lemonade-game/ReplicatedStorage/Config/RebirthConfig.luau` |

### Key Lessons from Legendary Swords (Distilled)

These lessons are embedded in the Lemonade codebase and enforced by the Design Constraints below:

1. Server-authoritative everything — client sends intent, server validates.
2. Never reset player progress — additive stacking beats level-reset rebirth.
3. Quest XP ~ 1 level per quest — the "one more quest" dopamine loop.
4. No forced tutorials — learn-by-doing with "Kill 5 Bandits" as the universal first quest.
5. Multi-currency (3+) with activity-specific currencies prevents inflation.
6. 5-hit M1 combos with escalating endlag create skill expression.
7. Hitlag (20-50ms freeze frames) is the biggest "feel good" factor most games miss.
8. Parry/block/feint triangle (Deepwoken) is the gold standard for skill-based combat.
9. Codes via YouTube creators are the #1 zero-cost growth hack.
10. Pity systems for RNG drops prevent infinite bad luck streaks.

### Games Analyzed in Research

- **Tier 1 (200B+ visits)**: Blox Fruits
- **Tier 2 (10B+ visits)**: King Legacy, Shindo Life
- **Tier 3 (1B+ visits)**: Grand Piece Online, Deepwoken
- **Hidden Gems**: Rogue Lineage, Arcane Odyssey, Type Soul, Project Slayers, Sword Burst Online

---

## Graph Queries

The repo has a pre-built knowledge graph in `graphify-out/`. Use the **graphify** skill to query it. The graph covers both code and research — 200 nodes, 218 edges, 38 communities.

### God Nodes (Most Connected)

1. `Roblox Sword RPG Research Library (INDEX)` — 17 edges (cross-community bridge)
2. `Tycoon System` — 9 edges
3. `Comprehensive Bug Catalog` — 6 edges
4. `Parry/Block/Feint Triangle (Deepwoken gold standard)` — 6 edges
5. `Retention & Community Design Template` — 6 edges
6. `NPC State Machine (Idle, Patrol, Chase, Attack, Return)` — 6 edges
7. `Sword RPG PvP Design Template` — 6 edges
8. `Purchase Flow (server-side validation, currency deduction)` — 6 edges
9. `Core Gameplay Loop (Fight-Collect-Rebirth)` — 5 edges
10. `Sword Collection System (65-75+ Weapons)` — 5 edges

### Community Hubs (Navigation)

Key communities in the graph: Combat System Architecture, Progression System, Shop & Economy System Architecture, Data Persistence Architecture, DataStore Security, Layered Defense Model (5 layers), NPC State Machine, Boss Attack Patterns & Telegraphing, Server Performance Architecture, Weapon Acquisition Systems, UI/UX, and more.

### Example Queries

```bash
# Find all code related to the rebirth system
graphify query 'rebirth system design'

# Find anti-exploit and server-authority patterns
graphify query 'anti-exploit patterns'

# Trace the path between two concepts in the codebase
graphify path 'Never Trust the Client' 'Damage Calculation'

# Find all combat-related code
graphify query 'combat damage formula'

# Find all inventory interactions
graphify query 'inventory validation'

# Check how enemy spawning works
graphify query 'enemy spawn rig'

# Find all RemoteEvent usage
graphify query 'RemoteEvent communication'

# Trace the save/load pipeline
graphify query 'player data persistence'

# Explain a specific concept in detail
graphify explain 'pity system'

# Find Legendary Swords mechanics
graphify query 'legendary swords drop rate formula'
```

### Refreshing the Graph

After making code changes:
```bash
graphify update .     # Incremental update (AST-only, no API cost)
graphify build .      # Full rebuild (uses API tokens)
```

Compare `git rev-parse HEAD` against the commit hash in `graphify-out/GRAPH_REPORT.md` to check staleness.

### Available Snapshots

| Snapshot | Nodes | Edges | Communities | Date |
|----------|-------|-------|-------------|------|
| `graphify-out/` (root, latest) | 200 | 218 | 38 | 2026-09-13 |
| `graphify-out/2026-09-11/` | 433 | 666 | 51 | 2026-09-11 |
| `graphify-out/2026-09-10/` | 190 | 326 | 18 | 2026-09-10 |

---

## Design Constraints (Non-Negotiable)

These are the rules baked into the codebase. Every line of code in `lemonade-game/` was written to honor these constraints. **Violating any of them is a regression.**

### 1. Server Authority
Every combat action, inventory change, gold transaction, XP gain, and level-up is computed and validated on the server. The client sends `RemoteEvent` intents only. Never trust client-reported damage, gold, or XP. If you add a new game mechanic, the server must own it.

> **Implementation**: `ServerScriptService/` handles all game state. `ReplicatedStorage/` contains only shared config and the animation controller. Client scripts in `StarterPlayerScripts/` send intents; server scripts validate and respond.

### 2. Never Reset Progress (Additive Stacking)
Rebirth multipliers stack. Inventory persists across rebirths. Gold is never zeroed. The only things that "reset" are level number (back to 1) and stat points — and even those give a permanent multiplier in return. Players rage-quit games that wipe their inventory.

> **Implementation**: `RebirthSystem.server.luau` applies additive multipliers. `PlayerDataService.luau` preserves all data across sessions. `RebirthConfig.luau` defines stacking perks.

### 3. Quest XP ~ 1 Level per Quest
The `LevelingSystem` is tuned so completing one quest gives approximately one level's worth of XP. If you adjust the XP curve (`xp_for_level = floor(100 * level^1.5)`), re-check quest rewards to maintain this ratio. Too little XP = quests feel worthless. Too much = levels feel meaningless.

> **Implementation**: `LevelingSystem.server.luau` with XP curve in the same file.

### 4. No Forced Tutorials
There is no tutorial script, no intro cutscene, no "press W to walk" overlay. The starter island is small enough that players discover mechanics naturally. Onboarding tooltips are fine; cutscenes that block gameplay are not. The universal first quest pattern is "Kill 5 Bandits."

### 5. Multi-Currency (3+)
Gold for general shops, boss tokens for boss rewards, rebirth crystals for prestige upgrades. Never let one currency buy everything. This prevents whales from bypassing gameplay and creates targeted engagement loops.

> **Implementation**: `MerchantConfig.luau` defines item costs per currency. `MerchantSystem.server.luau` validates currency on purchase.

### 6. 5-Hit M1 Combos
The `CombatController` runs a combo counter (1-5). Hits 1-2 are fast (low endlag), hits 3-4 have increasing endlag, hit 5 has the longest recovery window. This creates skill expression in spacing and commitment.

> **Implementation**: `CombatController.client.luau` manages combo state. `SwordClient.client.luau` in `StarterPack/ClassicSword/` handles tool activation.

### 7. Hitlag (20-50ms)
On successful hit, `CombatUtil` applies a brief freeze to both attacker and victim. This is NOT just animation — it's a real `task.wait()` hold on the animation timeline. This is the single biggest "feel good" factor most Roblox sword games miss.

> **Implementation**: `CombatUtil.luau` — shared combat helper module.

### 8. YouTube Codes for Growth
The code redemption system exists to support creator partnerships. Each creator gets a unique code (e.g., "CREATORNAME50" for 50 gems). Free marketing that feels like community building. This is the #1 zero-cost growth strategy in the Roblox sword RPG space.

### 9. Starter Area Small, Death Forgiving
The `WorldLayout` keeps the starter area compact. Death does not drop gold or inventory. The player respawns at spawn with everything intact. First 5 minutes should feel safe and explorable. Don't punish death until the player is invested.

> **Implementation**: `WorldLayout.luau` — starter island is the first area generated.

### 10. Pity Systems for RNG
`SwordDropSystem` tracks consecutive failed drops. After a threshold, the next drop is guaranteed. Do not add pure-RNG drops without a pity counter. Players hate infinite bad luck streaks. The key formula: `drop_rate = 1 / (base_chance - rebirth_level)`.

> **Implementation**: `SwordDropSystem.server.luau` with drop tables and pity tracking. `BossSwordFactory.luau` constructs boss weapon instances.

---

## Architecture Quick Reference

### Data Flow
```
[Client Input]  -->  CombatController.client.luau
                          |
                          | RemoteEvent: EnemyAttack / InventoryAction / etc.
                          v
[Server Validate] --> EnemyCombat.server.luau / InventorySystem.server.luau
                          |
                          | RemoteEvent: DamageNumber / GoldGain / XPGain / etc.
                          v
[Client Feedback] --> DamageNumbers.client.luau / GoldNumbers.client.luau / XPGainUI.client.luau
```

### Script Dependency Graph (Key Paths)
```
RuntimeBootstrap.server.luau
    --> PlayerDataStore.server.luau --> PlayerDataService.luau
    --> LevelingSystem.server.luau
    --> EnemyCombat.server.luau --> CombatUtil.luau
    --> SwordSystem.server.luau --> CombatUtil.luau
    --> SwordDropSystem.server.luau --> BossSwordFactory.luau --> BossWeapons.luau
    --> MerchantSystem.server.luau
    --> RebirthSystem.server.luau --> RebirthConfig.luau
    --> InventorySystem.server.luau --> InventoryService.luau
    --> BossRoomGate.server.luau
    --> WorldBuilder.server.luau --> WorldLayout.luau
```

### Gotchas & Anti-Patterns
1. **Do NOT duplicate `isEnemy()`.** It's in `CombatUtil.luau`. Import it.
2. **Do NOT set `Material = Enum.Material.Neon` on textured MeshParts.** It hides the texture. Use `CombatUtil.applyWeaponAppearance()` which applies Metal + PointLight for the glow effect.
3. **Do NOT let the merchant and drop system have separate weapon definitions.** Changes to `BossSwordFactory.luau` must be mirrored in `MerchantSystem.server.luau`.
4. **Do NOT fire both armed and unarmed combat paths on one click.** `CombatController.fireAttack()` handles routing.
5. **Do NOT forget the 180-degree Y flip on imported GLB meshes.** Every `CFrame` placement needs `CFrame.Angles(0, math.pi, 0)` correction.
6. **Do NOT use `RemoteFunction` for one-way communication.** Use `RemoteEvent`. RemoteFunctions block the calling thread.
7. **Do NOT add pure-RNG without pity.** Every RNG drop system must have a pity counter.

---

## How to Verify Your Changes

1. **Syntax check**: All `.luau` files must parse without errors.
2. **Graph staleness**: After code changes, run `graphify update .` to keep the knowledge graph current.
3. **`manual_trace.md`**: If your change fixes a bug, mark it resolved. If it introduces a known tradeoff, add it to the open section.
4. **No duplicate helpers**: Grep for `isEnemy`, `applyWeaponAppearance`, `ENEMY_TAG` — they should only appear in `CombatUtil.luau` and its importers.
5. **Server authority**: Every new game mechanic must have server-side validation. If you add a new RemoteEvent, the server handler must validate all inputs.

---

*Last updated: 2026-09-13. Based on graphify-out snapshot (200 nodes, 218 edges, 38 communities).*
