# AI Agent Handoff Guide

> **Purpose**: This document is your onboarding when you pull `lemonade-graph`. Read it top to bottom before touching any code. It tells you what exists, where to find it, what the research says, and what rules you must never break.

---

## Quick Start

1. **This repo contains a Roblox sword RPG game + design research + AI skills + a knowledge graph.**
2. The game is in `lemonade-game/` — a Rojo-compatible Roblox Studio project (Luau source, ~8,000 lines).
3. Skills are in `skills/` — seven Roblox-domain skill directories with `references/` folders (currently empty scaffolds; load skills to inject domain guidance at prompt time).
4. Research is in `research/sword-rpg/` — game design analysis from the inspiration game (currently empty; see Legendary Swords section below for the research that was used during development).
5. Knowledge graph is in `graphify-out/` — queryable via the graphify skill. Two dated snapshots (2026-09-10, 2026-09-11) plus a live root copy.
6. **Read `CLAUDE.md` first** — it contains the original project instructions and design constraints that guided all code generation.
7. **Read `manual_trace.md` second** — it tracks open bugs and resolved issues across rebuilds.

---

## Repository Structure

```
lemonade-graph/
|
+-- CLAUDE.md                          # Master project instructions / design bible
+-- manual_trace.md                    # Bug tracker across AI rebuilds (open + resolved)
+-- default.project.json               # Rojo project config (maps folders to Roblox services)
+-- build_world_semantic.py            # Python: generates semantic world docs from place.json
+-- dump_scripts.py                    # Python: extracts script metadata
+-- .gitignore
|
+-- lemonade-game/                     # === ROBLOX GAME SOURCE (Rojo project) ===
|   +-- Workspace/
|   |   +-- DayCycle.server.luau       # Day/night cycle (228 lines)
|   |
|   +-- ServerScriptService/           # Server-authoritative game logic
|   |   +-- EnemyCombat.server.luau    # Enemy AI, hit detection, damage (1,087 lines - LARGEST)
|   |   +-- WorldLayout.luau           # World generation/layout (1,070 lines)
|   |   +-- LevelingSystem.server.luau # XP, levels, stat points (401 lines)
|   |   +-- InventoryService.luau      # Shared inventory module (339 lines)
|   |   +-- MerchantSystem.server.luau # Shop/upgrade system (263 lines)
|   |   +-- SwordDropSystem.server.luau# Loot drops, rarity, modifiers (244 lines)
|   |   +-- PlayerDataService.luau     # Cross-session save/load (306 lines)
|   |   +-- SwordSystem.server.luau    # Sword equipping, damage calc (177 lines)
|   |   +-- BossRoomGate.server.luau   # Boss arena gating (140 lines)
|   |   +-- RuntimeBootstrap.server.luau# Startup init sequence (136 lines)
|   |   +-- RebirthSystem.server.luau  # Prestige/rebirth loop (134 lines)
|   |   +-- BossSwordFactory.luau      # Boss weapon construction (201 lines)
|   |   +-- CombatUtil.luau            # Shared combat helpers (104 lines)
|   |   +-- InventorySystem.server.luau# Inventory event handler (47 lines)
|   |   +-- PlayerDataStore.server.luau# DataStore wrapper (53 lines)
|   |   +-- WorldBuilder.server.luau   # Delegates to WorldLayout (5 lines)
|   |
|   +-- ReplicatedStorage/             # Shared (server + client) modules
|   |   +-- AnimationController.luau   # Animation state machine (267 lines)
|   |   +-- Config/
|   |   |   +-- BossWeapons.luau       # Boss weapon definitions (108 lines)
|   |   |   +-- WeaponModifiers.luau   # Prefix/suffix modifier system (117 lines)
|   |   |   +-- RebirthConfig.luau     # Rebirth thresholds & perks (84 lines)
|   |   |   +-- MerchantConfig.luau    # Shop item catalog (46 lines)
|   |   |   +-- SaveConfig.luau        # Default save schema (37 lines)
|   |   |   +-- Items.luau             # General item definitions (9 lines)
|   |   |   +-- Sword.luau             # Base sword stats (8 lines)
|   |   +-- Animations/
|   |       +-- Sword Attack Animation.luau # Attack anim data (118 lines)
|   |
|   +-- StarterPlayer/StarterPlayerScripts/  # Client-side scripts
|   |   +-- MainMenuGui.client.luau    # Main menu UI (863 lines - LARGEST CLIENT)
|   |   +-- MerchantGui.client.luau    # Shop UI (328 lines)
|   |   +-- CombatController.client.luau # Client combat input (241 lines)
|   |   +-- SwordDropToast.client.luau # Loot notification popup (229 lines)
|   |   +-- LevelProgressGui.client.luau # XP bar UI (145 lines)
|   |   +-- BossDoorClient.client.luau # Boss door interaction UI (102 lines)
|   |   +-- LevelUpBurst.client.luau   # Level-up VFX (71 lines)
|   |   +-- DamageNumbers.client.luau  # Floating damage text (62 lines)
|   |   +-- XPGainUI.client.luau       # XP gain popup (59 lines)
|   |   +-- GoldNumbers.client.luau    # Gold pickup numbers (50 lines)
|   |   +-- RunController.client.luau  # Sprint/run input (37 lines)
|   |
|   +-- StarterPack/ClassicSword/      # Starter weapon tool
|   |   +-- SwordClient.client.luau    # Client sword logic (36 lines)
|   |   +-- MouseIcon.client.luau      # Custom cursor (28 lines)
|   |
|   +-- world/                         # Semantic world documentation
|       +-- place.json                 # Full place hierarchy (JSON export)
|       +-- Workspace.md               # 147 instances documented
|       +-- ServerScriptService.md     # 13 scripts documented
|       +-- ReplicatedStorage.md       # 29 instances documented
|       +-- StarterPlayer.md           # 13 instances documented
|       +-- StarterPack.md             # 16 instances documented
|       +-- ServerStorage.md           # 3 templates documented
|       +-- Lighting.md                # 5 lighting instances
|       +-- Terrain.md                 # Voxel terrain metadata
|
+-- skills/                            # === ROBLOX DOMAIN SKILLS (scaffolds) ===
|   +-- roblox-game-dev/references/    # General Roblox game dev guidance
|   +-- roblox-luau/references/        # Luau language patterns
|   +-- roblox-systems/references/     # Game systems design
|   +-- roblox-ui/references/          # UI/UX patterns
|   +-- roblox-debug/references/       # Debugging techniques
|   +-- roblox-optimize/references/    # Performance optimization
|   +-- roblox-map-design/references/  # World/level design
|
+-- research/sword-rpg/                # === DESIGN RESEARCH (empty scaffold) ===
|                                      #   Research was used during development;
|                                      #   see Legendary Swords section below.
|
+-- graphify-out/                      # === KNOWLEDGE GRAPH ===
|   +-- graph.json                     # Live graph: 437 nodes, 671 edges, 52 communities
|   +-- graph.html                     # Visual HTML rendering of the graph
|   +-- GRAPH_REPORT.md                # Latest report (2026-09-11)
|   +-- manifest.json                  # File hashes for incremental updates
|   +-- cost.json                      # Token cost tracking
|   +-- 2026-09-10/                    # Snapshot: 190 nodes, 326 edges (code-only)
|   |   +-- graph.json
|   |   +-- GRAPH_REPORT.md
|   |   +-- manifest.json
|   |   +-- cost.json
|   |   +-- .graphify_labels.json
|   +-- 2026-09-11/                    # Snapshot: 433 nodes, 666 edges (code + tools + assets)
|       +-- graph.json
|       +-- GRAPH_REPORT.md
|       +-- manifest.json
|       +-- cost.json
|       +-- .graphify_labels.json
|
+-- assets/                            # === 3D ASSETS ===
|   +-- swords/
|       +-- Boss_CelestialTitan.glb    # Celestial Titan boss sword
|       +-- Boss_FrostRevenant.glb     # Frost Revenant boss sword
|       +-- Boss_Gorgon.glb            # Gorgon/Warlord greatsword (6,220 tris)
|       +-- Boss_InfernalColossus.glb  # Infernal Colossus boss sword
|       +-- Boss_VoidWraith.glb        # Void Wraith boss sword
|       +-- manifest.json              # Mesh metadata (dimensions, grip, guard, handle)
|       +-- preview.png                # Preview render of all swords
|
+-- tools/                             # === UTILITY SCRIPTS ===
|   +-- sword_forge.py                 # Procedural sword mesh generator (Python)
|
+-- .claude/
    +-- settings.json                  # Claude Code project settings
```

---

## Skills Usage

Each skill in `skills/` is a scaffold for a Roblox domain. They are designed to be loaded at prompt time by an AI agent to inject domain-specific guidance. Reference files go in the `references/` subfolder.

| Skill | When to Load | Questions It Answers |
|-------|-------------|---------------------|
| `roblox-game-dev` | Starting any new game feature or system | "How should I structure a new Roblox game system?" "What's the standard Roblox game architecture?" |
| `roblox-luau` | Writing or reviewing any Luau script | "What are Luau type annotations?" "How does Luau differ from standard Lua?" "What are Luau performance patterns?" |
| `roblox-systems` | Designing game loops, progression, economies | "How should I structure a rebirth system?" "What makes a good loot table?" "How do Roblox DataStores work?" |
| `roblox-ui` | Building any GUI, HUD, or menu | "How do I make responsive UI with UIListLayout?" "What's the right approach for Roblox UI scaling?" |
| `roblox-debug` | Diagnosing bugs, errors, or unexpected behavior | "How do I trace a RemoteEvent call chain?" "Why is my server script not firing?" |
| `roblox-optimize` | Performance work, reducing lag, optimizing loops | "How do I reduce script performance cost?" "What's cheaper: RunService or events?" |
| `roblox-map-design` | Building worlds, terrain, or level layouts | "How big should a starter island be?" "How do I make terrain that performs well?" |

> **Note**: The `references/` folders are currently empty. Populate them with domain-specific markdown files before loading the skill, or the skill will only provide its name-based context.

---

## Research Library Index

The `research/sword-rpg/` directory is currently an empty scaffold. Research content was consumed during initial development and informed the codebase design. The key research outputs are embedded in the code and documented in this handoff guide (see Legendary Swords section and Design Constraints below).

If research files are added later, they should be indexed here with:
- File path
- Line count
- One-line summary
- Key tables/data contained

| File | Lines | Summary | Key Data |
|------|-------|---------|----------|
| *(none yet)* | — | Populate this table as research files are added | — |

---

## Legendary Swords RPG Reference

**"Sword RPG: Legendary Swords"** (Roblox) is the INSPIRATION game for the lemonade-game project. All design decisions in this codebase trace back to research on how Legendary Swords works and what it does well.

### What to Read First
1. **This section** — gives you the distilled lessons.
2. **`manual_trace.md`** — shows real bugs that emerged from implementing these patterns.

### Key Formulas

| Formula | Description |
|---------|-------------|
| `rebirth_drop_rate = 1 / (base_chance - rebirth_level)` | Each rebirth makes rare drops more likely. Clamped so denominator never goes below 1. |
| `damage = (base + 5 * strength) * (1 + 0.12 * weapon_level) * sword_mult * rebirth_mult * crit_mult` | Unified damage formula used by both armed and unarmed paths. |
| `xp_for_level = floor(100 * level^1.5)` | XP curve: each level requires more XP than the last. |

### Key Lessons from Legendary Swords

1. **Server-authoritative everything.** The server validates all combat, inventory, and economy actions. The client only sends intent (e.g., "I clicked attack", "I want to buy item X"). Never trust client-reported damage, gold, or XP.
2. **Never reset player progress.** Rebirth (prestige) is additive stacking — you keep your swords, your gold, your inventory. You only gain a multiplier and unlock the next tier. Players rage-quit games that wipe their inventory.
3. **Quest XP should be ~1 level per quest.** If a quest gives too little XP, players feel it's not worth doing. If it gives too much, the level system feels meaningless.
4. **No forced tutorials.** Drop players into the starter island and let them figure it out. Onboarding tooltips are fine; cutscenes that block gameplay are not.
5. **Multi-currency (3+) with activity-specific currencies.** Gold for general purchases, gems for premium, tokens for boss rewards. This prevents whales from bypassing gameplay.
6. **5-hit M1 combos with escalating endlag.** The first 2 hits are fast (low endlag), hits 3-4 get slower, and hit 5 has a big commitment window. This creates skill expression in spacing.
7. **Hitlag (20-50ms freeze frames).** On hit, briefly freeze the attacker and enemy. This makes combat feel impactful without slowing the game down.
8. **Codes via YouTube creators for growth.** Give creators exclusive codes ("CREATORNAME50" for 50 gems). Free marketing that feels like community building.
9. **Starter island small, death minimally punishing.** First 5 minutes should feel safe and explorable. Don't punish death with gold loss or teleport-to-spawn until the player is invested.
10. **Pity systems for RNG drops.** After N failed attempts at a drop, guarantee it. Players hate infinite bad luck streaks.

### Known Bugs from Legendary Swords Research
- Duplicate boss weapon construction code between merchant and drop systems.
- Neon material hides textures on imported MeshParts (use Metal + PointLight instead).
- `isEnemy()` helper duplicated across scripts (drift-prone; centralize in CombatUtil).
- Two overlapping melee paths (armed vs unarmed) can both fire on one click.

---

## Knowledge Graph Queries

The repo has a pre-built knowledge graph in `graphify-out/`. Use the **graphify** skill to query it.

### Available Snapshots

| Snapshot | Nodes | Edges | Communities | Date | Commit |
|----------|-------|-------|-------------|------|--------|
| `graphify-out/` (root, latest) | 437 | 671 | 52 | 2026-09-11 | — |
| `graphify-out/2026-09-11/` | 433 | 666 | 51 | 2026-09-11 | `322b4786` |
| `graphify-out/2026-09-10/` | 190 | 326 | 18 | 2026-09-10 | `d3bc2554` |

### God Nodes (Most Connected)
1. `RemoteEvents folder` — 18 edges (the communication backbone)
2. `ServerScriptService` — 14 edges (all server logic hub)
3. `createPart()` — 13 edges (world generation primitive)
4. `StarterPlayerScripts` — 12 edges (all client UI)
5. Boss entities (`Boss_Gorgon`, `Boss_FrostRevenant`, etc.) — 11 edges each

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
```

### Refreshing the Graph
After making code changes:
```bash
graphify update .     # Incremental update (no API cost)
graphify build .      # Full rebuild (uses API tokens)
```
Compare `git rev-parse HEAD` against the commit hash in `GRAPH_REPORT.md` to check staleness.

---

## Design Constraints

These are the **non-negotiable rules** baked into the codebase. Every line of code in `lemonade-game/` was written to honor these constraints. If you violate one, you are regressing the project.

### Architecture
1. **Server authority on all game state.** Every combat action, inventory change, gold transaction, XP gain, and level-up is computed and validated on the server. The client sends `RemoteEvent` intents only. If you add a new game mechanic, the server must own it.
2. **Never reset player progress (additive stacking).** Rebirth multipliers stack. Inventory persists across rebirths. Gold is never zeroed. The only things that "reset" are level number (back to 1) and stat points — and even those give you a permanent multiplier in return.
3. **Multi-currency (3+) with activity-specific currencies.** Gold for general shops, boss tokens for boss rewards, rebirth crystals for prestige upgrades. Never let one currency buy everything.

### Combat
4. **5-hit M1 combos with escalating endlag.** The `CombatController` runs a combo counter (1-5). Hits 1-2 are fast, hits 3-4 have increasing endlag, hit 5 has the longest recovery. This is the core skill expression.
5. **Hitlag (20-50ms freeze frames).** On successful hit, `CombatUtil` applies a brief freeze to both attacker and victim. This is NOT just animation — it's a real `task.wait()` hold on the animation timeline.
6. **Unified damage formula.** Armed and unarmed both use the same formula shape. Armed base=30, unarmed base=25. Both scale with Strength, weapon level, sword multiplier, and rebirth multiplier.

### Progression
7. **Quest XP ~ 1 level per quest.** The `LevelingSystem` is tuned so completing one quest gives approximately one level's worth of XP. If you adjust the XP curve, re-check quest rewards.
8. **No forced tutorials.** There is no tutorial script, no intro cutscene, no "press W to walk" overlay. The starter island is small enough that players discover mechanics naturally.
9. **Pity systems for RNG drops.** `SwordDropSystem` tracks consecutive failed drops. After a threshold, the next drop is guaranteed. Do not add pure-RNG drops without a pity counter.
10. **Starter island small, death minimally punishing.** The `WorldLayout` keeps the starter area compact. Death does not drop gold or inventory. The player respawns at spawn with everything intact.

### Growth
11. **Codes via YouTube creators for growth.** The code redemption system exists to support creator partnerships. Each creator gets a unique code that grants currency/items.

### Technical
12. **`CombatUtil` is the shared combat module.** All combat helper functions (`isEnemy()`, `applyWeaponAppearance()`, `ENEMY_TAG`, `ENEMY_ATTRIBUTE`) live here. Do not duplicate them in individual scripts.
13. **RemoteEvents are the only client-server bridge.** All communication flows through `ReplicatedStorage/RemoteEvents`. Never use `RemoteFunction` for fire-and-forget actions.
14. **Studio 180-degree Y rotation.** Imported GLB meshes are rotated 180 degrees about Y by Roblox's importer. Every mesh placement needs `CFrame.Angles(0, math.pi, 0)` correction.

---

## Architecture Diagrams

### Data Flow
```
[Client Input] --> CombatController.client.luau
                        |
                        | RemoteEvent: EnemyAttack / InventoryAction / etc.
                        v
[Server Validation] --> EnemyCombat.server.luau / InventorySystem.server.luau
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
    --> MerchantSystem.server.luau (NOTE: duplicates some BossSwordFactory logic)
    --> RebirthSystem.server.luau --> RebirthConfig.luau
    --> InventorySystem.server.luau --> InventoryService.luau
    --> BossRoomGate.server.luau
    --> WorldBuilder.server.luau --> WorldLayout.luau
```

---

## Gotchas & Anti-Patterns

These are things that have bitten previous agents working on this repo:

1. **Do NOT duplicate `isEnemy()`.** It's in `CombatUtil.luau`. Import it. The manual_trace.md documents what happened when it was duplicated 4 times.
2. **Do NOT set `Material = Enum.Material.Neon` on textured MeshParts.** It hides the texture. Use `CombatUtil.applyWeaponAppearance()` which applies Metal + PointLight for the glow effect.
3. **Do NOT let the merchant and drop system have separate weapon definitions.** `manual_trace.md` tracks the known bug where `MerchantSystem` and `SwordDropSystem` have duplicate boss weapon construction. Changes to one must be mirrored in the other.
4. **Do NOT fire both armed and unarmed combat paths on one click.** `CombatController.fireAttack()` handles this: it calls `tool:Activate()` when a sword is equipped and only fires `EnemyAttack` when unarmed.
5. **Do NOT forget the 180-degree Y flip on imported meshes.** Every `CFrame` placement of an imported GLB needs the Y rotation correction.
6. **Do NOT use `RemoteFunction` for one-way communication.** Use `RemoteEvent`. RemoteFunctions block the calling thread.
7. **Do NOT add pure-RNG without pity.** Every RNG drop system must have a pity counter.

---

## How to Verify Your Changes

1. **Syntax check**: All `.luau` files must parse without errors. Run a Luau linter if available.
2. **Graph staleness**: After code changes, run `graphify update .` to keep the knowledge graph current.
3. **manual_trace.md**: If your change fixes a bug, mark it resolved. If it introduces a known tradeoff, add it to the open section.
4. **No duplicate helpers**: Grep for `isEnemy`, `applyWeaponAppearance`, `ENEMY_TAG` — they should only appear in `CombatUtil.luau` and its importers, not re-defined elsewhere.
5. **Server authority**: Every new game mechanic must have server-side validation. If you add a new RemoteEvent, the server handler must validate all inputs.

---

*Last updated: 2026-09-11. Generated from graphify-out snapshot at commit 322b4786.*
