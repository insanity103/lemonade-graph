# Graph Report - lemonade-graph  (2026-09-11)

## Corpus Check
- 59 files · ~59,990 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 433 nodes · 666 edges · 51 communities (22 shown, 14 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 37 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `322b4786`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- RemoteEvents folder
- sword_forge.py
- EnemyCombat.server.luau
- Boss_CelestialTitan
- SwordSlash sound
- Cross-session player save
- Config folder (Sword, Items, RebirthConfig, WeaponModifiers, MerchantConfig, BossWeapons)
- InventoryService.luau
- MainMenuGui.client.luau
- Lighting/Atmosphere
- WorldLayout.luau
- PlayerDataService.luau
- SwordDropSystem.server.luau
- ServerScriptService
- `StarterPlayer/StarterPlayerScripts` — StarterPlayerScripts
- Boulder decor set (5 Models)
- Tree decor set (10 Models)
- AnimationController.luau
- LevelingSystem.server.luau
- Boss_FrostRevenant
- Boss_Gorgon
- BossRoomGate.server.luau
- CombatController.client.luau
- SwordSystem.server.luau
- BossDoorClient.client.luau
- DayCycle.server.luau
- build_world_semantic.py
- MerchantGui.client.luau
- MouseIcon.client.luau
- CLAUDE.md
- manual_trace.md
- Lighting/BloomEffect
- Lighting/DepthOfFieldEffect
- Lighting/Sky
- Lighting/SunRaysEffect
- Unsheath sound

## God Nodes (most connected - your core abstractions)
1. `RemoteEvents folder` - 18 edges
2. `ServerScriptService` - 14 edges
3. `createPart()` - 13 edges
4. ``StarterPlayer/StarterPlayerScripts` — StarterPlayerScripts` - 12 edges
5. `Boss_Gorgon` - 11 edges
6. `Boss_FrostRevenant` - 11 edges
7. `Boss_InfernalColossus` - 11 edges
8. `Boss_VoidWraith` - 11 edges
9. `Boss_CelestialTitan` - 11 edges
10. `Part` - 11 edges

## Surprising Connections (you probably didn't know these)
- `Lemonade RPG place (root)` --references--> `Voxel Terrain`  [EXTRACTED]
  lemonade-game/world/place.json → lemonade-game/world/Terrain.md
- `Lemonade RPG place (root)` --references--> `Runtime-spawned enemy rigs`  [EXTRACTED]
  lemonade-game/world/place.json → lemonade-game/world/Workspace.md
- `Lemonade RPG place (root)` --references--> `Player SpawnLocation`  [EXTRACTED]
  lemonade-game/world/place.json → lemonade-game/world/Workspace.md
- `BossSwordFactory.build()` --calls--> `BossWeapons.Get()`  [INFERRED]
  lemonade-game/ServerScriptService/BossSwordFactory.luau → lemonade-game/ReplicatedStorage/Config/BossWeapons.luau
- `BossSwordFactory.build()` --calls--> `BossWeapons.GetTier()`  [INFERRED]
  lemonade-game/ServerScriptService/BossSwordFactory.luau → lemonade-game/ReplicatedStorage/Config/BossWeapons.luau

## Import Cycles
- None detected.

## Communities (51 total, 14 thin omitted)

### Community 0 - "RemoteEvents folder"
Cohesion: 0.07
Nodes (31): Lemonade RPG place (root), RemoteEvents folder, AutoSellNotice (RemoteEvent), BossDoorNotice (RemoteEvent), DamageNumber (RemoteEvent), EnemyAttack (RemoteEvent), GoldGain (RemoteEvent), InventoryAction (RemoteEvent) (+23 more)

### Community 1 - "sword_forge.py"
Cohesion: 0.09
Nodes (42): assemble(), assert_simple(), C(), ccw(), chaikin(), design_celestial(), design_frost(), design_gorgon() (+34 more)

### Community 2 - "EnemyCombat.server.luau"
Cohesion: 0.09
Nodes (27): BossWeapons.Get(), BossWeapons.GetByTier(), BossWeapons.GetTier(), WeaponModifiers.RollModifiers(), BossSwordFactory.build(), BossSwordFactory.rebuild(), fitBossMesh(), CombatUtil.applyWeaponAppearance() (+19 more)

### Community 3 - "Boss_CelestialTitan"
Cohesion: 0.06
Nodes (33): Boss_CelestialTitan, bytes, checks, file, gripFrac, guardZ, handleZ, meshSize (+25 more)

### Community 7 - "InventoryService.luau"
Cohesion: 0.21
Nodes (23): ensureDataFolder(), findOwnedTool(), findToolTemplate(), getDataFolder(), getInventorySnapshot(), getItemDefinition(), getOrCreateInventory(), InventoryService.AddItem() (+15 more)

### Community 8 - "MainMenuGui.client.luau"
Cohesion: 0.23
Nodes (21): addCorner(), addPadding(), addStroke(), bindInventoryContainer(), bindInventoryRefresh(), buildHomePanel(), buildInventoryPanel(), buildRebirthPanel() (+13 more)

### Community 10 - "WorldLayout.luau"
Cohesion: 0.17
Nodes (31): addSignFace(), addZoneMarker(), arenaCFrame(), buildBossRoom(), buildBoulder(), buildColumn(), buildCrystal(), buildLamp() (+23 more)

### Community 11 - "PlayerDataService.luau"
Cohesion: 0.22
Nodes (15): InventoryService.HasLoaded(), defaultData(), keyFor(), lockHeldByOther(), lockHeldByThisServer(), PlayerDataService.Apply(), PlayerDataService.Load(), PlayerDataService.Release() (+7 more)

### Community 12 - "SwordDropSystem.server.luau"
Cohesion: 0.18
Nodes (14): RebirthConfig.GetEffectiveDropChance(), RebirthConfig.GetMultipliers(), RebirthConfig.GetRequiredLevel(), CombatUtil.isEnemy(), applyRebirthAttributes(), getOrCreateIntValue(), setupPlayer(), bindPlayer() (+6 more)

### Community 13 - "ServerScriptService"
Cohesion: 0.13
Nodes (14): ServerScriptService, `ServerScriptService/BossRoomGate` — Script, `ServerScriptService/BossSwordFactory` — ModuleScript, `ServerScriptService/CombatUtil` — ModuleScript, `ServerScriptService/EnemyCombat` — Script, `ServerScriptService/InventoryService` — ModuleScript, `ServerScriptService/InventorySystem` — Script, `ServerScriptService/LevelingSystem` — Script (+6 more)

### Community 14 - "`StarterPlayer/StarterPlayerScripts` — StarterPlayerScripts"
Cohesion: 0.13
Nodes (14): StarterPlayer, `StarterPlayer/StarterCharacterScripts` — StarterCharacterScripts, `StarterPlayer/StarterPlayerScripts/BossDoorClient` — LocalScript, `StarterPlayer/StarterPlayerScripts/CombatController` — LocalScript, `StarterPlayer/StarterPlayerScripts/DamageNumbers` — LocalScript, `StarterPlayer/StarterPlayerScripts/GoldNumbers` — LocalScript, `StarterPlayer/StarterPlayerScripts/LevelProgressGui` — LocalScript, `StarterPlayer/StarterPlayerScripts/LevelUpBurst` — LocalScript (+6 more)

### Community 17 - "AnimationController.luau"
Cohesion: 0.18
Nodes (4): AnimationController.Play(), AnimationExecutor.new(), ensureExecutor(), onActivated()

### Community 18 - "LevelingSystem.server.luau"
Cohesion: 0.32
Nodes (11): applyDeathGoldPenalty(), applyHealth(), awardExperience(), connectEnemyHumanoid(), getEnemyGold(), getEnemyReward(), getKiller(), getOrCreateIntValue() (+3 more)

### Community 19 - "Boss_FrostRevenant"
Cohesion: 0.18
Nodes (11): Boss_FrostRevenant, bytes, checks, file, gripFrac, guardZ, handleZ, meshSize (+3 more)

### Community 20 - "Boss_Gorgon"
Cohesion: 0.18
Nodes (11): Boss_Gorgon, bytes, checks, file, gripFrac, guardZ, handleZ, meshSize (+3 more)

### Community 21 - "BossRoomGate.server.luau"
Cohesion: 0.36
Nodes (6): applyTier(), bindPlayer(), getLevel(), onCharacter(), tierFor(), tierGroup()

### Community 22 - "CombatController.client.luau"
Cohesion: 0.36
Nodes (5): findClosestLivingEnemy(), fireAttack(), getEquippedTool(), handleAttack(), isLivingEnemy()

### Community 23 - "SwordSystem.server.luau"
Cohesion: 0.52
Nodes (6): applyDamage(), applyKnockback(), calculateDamage(), performSwing(), setupCharacter(), setupTool()

### Community 24 - "BossDoorClient.client.luau"
Cohesion: 0.67
Nodes (5): getLevel(), paint(), repaintAll(), show(), track()

### Community 25 - "DayCycle.server.luau"
Cohesion: 0.60
Nodes (5): makeDawn(), makeDay(), makeDusk(), makeNight(), tween()

### Community 27 - "MerchantGui.client.luau"
Cohesion: 0.60
Nodes (3): buildShopList(), formatGold(), setShopOpen()

### Community 28 - "MouseIcon.client.luau"
Cohesion: 0.83
Nodes (3): OnChanged(), OnEquipped(), UpdateIcon()

## Knowledge Gaps
- **108 isolated node(s):** `name`, `file`, `bytes`, `triangles`, `vertices` (+103 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 176 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `PlayerDataService.Apply()` connect `PlayerDataService.luau` to `EnemyCombat.server.luau`, `InventoryService.luau`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Why does `BossSwordFactory.rebuild()` connect `EnemyCombat.server.luau` to `PlayerDataService.luau`?**
  _High betweenness centrality (0.028) - this node is a cross-community bridge._
- **What connects `name`, `file`, `bytes` to the rest of the system?**
  _108 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `RemoteEvents folder` be split into smaller, more focused modules?**
  _Cohesion score 0.07096774193548387 - nodes in this community are weakly interconnected._
- **Should `sword_forge.py` be split into smaller, more focused modules?**
  _Cohesion score 0.0858843537414966 - nodes in this community are weakly interconnected._
- **Should `EnemyCombat.server.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.08534850640113797 - nodes in this community are weakly interconnected._
- **Should `Boss_CelestialTitan` be split into smaller, more focused modules?**
  _Cohesion score 0.058823529411764705 - nodes in this community are weakly interconnected._