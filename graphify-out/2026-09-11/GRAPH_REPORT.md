# Graph Report - lemonade-graph  (2026-09-11)

## Corpus Check
- 51 files · ~31,840 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 292 nodes · 418 edges · 46 communities (19 shown, 14 thin omitted)
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 29 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `2941fc41`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- RemoteEvents folder
- Cross-session player save
- SwordSlash sound
- Lemonade RPG place (root)
- InventoryService.luau
- MainMenuGui.client.luau
- EnemyCombat.server.luau
- Config folder (Sword, Items, RebirthConfig, WeaponModifiers, MerchantConfig, BossWeapons)
- PlayerDataService.luau
- Lighting/Atmosphere
- SwordDropSystem.server.luau
- ServerScriptService
- `StarterPlayer/StarterPlayerScripts` — StarterPlayerScripts
- BossSwordFactory.build
- AnimationController.luau
- Boulder decor set (5 Models)
- Tree decor set (10 Models)
- LevelingSystem.server.luau
- BossRoomGate.server.luau
- SwordSystem.server.luau
- CombatController.client.luau
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
3. ``StarterPlayer/StarterPlayerScripts` — StarterPlayerScripts` - 12 edges
4. `buildInventoryPanel()` - 10 edges
5. `validateItemId()` - 8 edges
6. `InventoryService.LoadPlayer()` - 8 edges
7. `PlayerDataService.Save()` - 8 edges
8. `addCorner()` - 8 edges
9. `createText()` - 8 edges
10. `openTab()` - 8 edges

## Surprising Connections (you probably didn't know these)
- `Lemonade RPG place (root)` --references--> `RemoteEvents folder`  [EXTRACTED]
  lemonade-game/world/place.json → lemonade-game/world/ReplicatedStorage.md
- `Lemonade RPG place (root)` --references--> `Voxel Terrain`  [EXTRACTED]
  lemonade-game/world/place.json → lemonade-game/world/Terrain.md
- `Lemonade RPG place (root)` --references--> `Runtime-spawned enemy rigs`  [EXTRACTED]
  lemonade-game/world/place.json → lemonade-game/world/Workspace.md
- `Lemonade RPG place (root)` --references--> `Player SpawnLocation`  [EXTRACTED]
  lemonade-game/world/place.json → lemonade-game/world/Workspace.md
- `BossSwordFactory.build()` --calls--> `BossWeapons.Get()`  [INFERRED]
  lemonade-game/ServerScriptService/BossSwordFactory.luau → lemonade-game/ReplicatedStorage/Config/BossWeapons.luau

## Import Cycles
- None detected.

## Communities (46 total, 14 thin omitted)

### Community 0 - "RemoteEvents folder"
Cohesion: 0.11
Nodes (18): RemoteEvents folder, AutoSellNotice (RemoteEvent), BossDoorNotice (RemoteEvent), DamageNumber (RemoteEvent), EnemyAttack (RemoteEvent), GoldGain (RemoteEvent), InventoryAction (RemoteEvent), InventoryUpdated (RemoteEvent) (+10 more)

### Community 3 - "Lemonade RPG place (root)"
Cohesion: 0.19
Nodes (13): Lemonade RPG place (root), BossSwordTool (Tool), Importer 180 deg Y flip, SwordMeshTemplate (MeshPart), Starter sword blade assembly, ClassicSword (Tool), ClassicSword Handle, SwordLunge sound (unused) (+5 more)

### Community 4 - "InventoryService.luau"
Cohesion: 0.19
Nodes (24): ensureDataFolder(), findOwnedTool(), findToolTemplate(), getDataFolder(), getInventorySnapshot(), getItemDefinition(), getOrCreateInventory(), InventoryService.AddItem() (+16 more)

### Community 5 - "MainMenuGui.client.luau"
Cohesion: 0.23
Nodes (21): addCorner(), addPadding(), addStroke(), bindInventoryContainer(), bindInventoryRefresh(), buildHomePanel(), buildInventoryPanel(), buildRebirthPanel() (+13 more)

### Community 6 - "EnemyCombat.server.luau"
Cohesion: 0.20
Nodes (15): applyEnemyDamageToPlayer(), attackEnemy(), createEnemyRig(), createMotor6D(), findNearestEnemy(), getAliveCharacter(), getEnemyDamage(), getEnemyMaxHealth() (+7 more)

### Community 8 - "PlayerDataService.luau"
Cohesion: 0.22
Nodes (15): InventoryService.HasLoaded(), defaultData(), keyFor(), lockHeldByOther(), lockHeldByThisServer(), PlayerDataService.Apply(), PlayerDataService.Load(), PlayerDataService.Release() (+7 more)

### Community 10 - "SwordDropSystem.server.luau"
Cohesion: 0.19
Nodes (13): RebirthConfig.GetEffectiveDropChance(), RebirthConfig.GetMultipliers(), RebirthConfig.GetRequiredLevel(), applyRebirthAttributes(), getOrCreateIntValue(), setupPlayer(), bindPlayer(), getEquippedWeaponSlots() (+5 more)

### Community 11 - "ServerScriptService"
Cohesion: 0.13
Nodes (14): ServerScriptService, `ServerScriptService/BossRoomGate` — Script, `ServerScriptService/BossSwordFactory` — ModuleScript, `ServerScriptService/CombatUtil` — ModuleScript, `ServerScriptService/EnemyCombat` — Script, `ServerScriptService/InventoryService` — ModuleScript, `ServerScriptService/InventorySystem` — Script, `ServerScriptService/LevelingSystem` — Script (+6 more)

### Community 12 - "`StarterPlayer/StarterPlayerScripts` — StarterPlayerScripts"
Cohesion: 0.13
Nodes (14): StarterPlayer, `StarterPlayer/StarterCharacterScripts` — StarterCharacterScripts, `StarterPlayer/StarterPlayerScripts/BossDoorClient` — LocalScript, `StarterPlayer/StarterPlayerScripts/CombatController` — LocalScript, `StarterPlayer/StarterPlayerScripts/DamageNumbers` — LocalScript, `StarterPlayer/StarterPlayerScripts/GoldNumbers` — LocalScript, `StarterPlayer/StarterPlayerScripts/LevelProgressGui` — LocalScript, `StarterPlayer/StarterPlayerScripts/LevelUpBurst` — LocalScript (+6 more)

### Community 13 - "BossSwordFactory.build"
Cohesion: 0.18
Nodes (8): BossWeapons.Get(), BossWeapons.GetByTier(), BossWeapons.GetTier(), WeaponModifiers.RollModifiers(), BossSwordFactory.build(), BossSwordFactory.rebuild(), CombatUtil.applyWeaponAppearance(), makePurchasedSword()

### Community 14 - "AnimationController.luau"
Cohesion: 0.18
Nodes (4): AnimationController.Play(), AnimationExecutor.new(), ensureExecutor(), onActivated()

### Community 17 - "LevelingSystem.server.luau"
Cohesion: 0.32
Nodes (11): applyDeathGoldPenalty(), applyHealth(), awardExperience(), connectEnemyHumanoid(), getEnemyGold(), getEnemyReward(), getKiller(), getOrCreateIntValue() (+3 more)

### Community 18 - "BossRoomGate.server.luau"
Cohesion: 0.36
Nodes (6): applyTier(), bindPlayer(), getLevel(), onCharacter(), tierFor(), tierGroup()

### Community 19 - "SwordSystem.server.luau"
Cohesion: 0.31
Nodes (8): CombatUtil.hasLineOfSight(), CombatUtil.isEnemy(), applyDamage(), applyKnockback(), calculateDamage(), performSwing(), setupCharacter(), setupTool()

### Community 20 - "CombatController.client.luau"
Cohesion: 0.36
Nodes (5): findClosestLivingEnemy(), fireAttack(), getEquippedTool(), handleAttack(), isLivingEnemy()

### Community 21 - "BossDoorClient.client.luau"
Cohesion: 0.67
Nodes (5): getLevel(), paint(), repaintAll(), show(), track()

### Community 22 - "DayCycle.server.luau"
Cohesion: 0.60
Nodes (5): makeDawn(), makeDay(), makeDusk(), makeNight(), tween()

### Community 24 - "MerchantGui.client.luau"
Cohesion: 0.60
Nodes (3): buildShopList(), formatGold(), setShopOpen()

### Community 25 - "MouseIcon.client.luau"
Cohesion: 0.83
Nodes (3): OnChanged(), OnEquipped(), UpdateIcon()

## Knowledge Gaps
- **58 isolated node(s):** `graphify`, ``ServerScriptService/LevelingSystem` — Script`, ``ServerScriptService/EnemyCombat` — Script`, ``ServerScriptService/SwordSystem` — Script`, ``ServerScriptService/InventoryService` — ModuleScript` (+53 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 109 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `PlayerDataService.Apply()` connect `PlayerDataService.luau` to `InventoryService.luau`, `BossSwordFactory.build`?**
  _High betweenness centrality (0.065) - this node is a cross-community bridge._
- **Why does `CombatUtil.applyWeaponAppearance()` connect `BossSwordFactory.build` to `SwordSystem.server.luau`, `EnemyCombat.server.luau`?**
  _High betweenness centrality (0.062) - this node is a cross-community bridge._
- **Why does `BossSwordFactory.rebuild()` connect `BossSwordFactory.build` to `PlayerDataService.luau`?**
  _High betweenness centrality (0.061) - this node is a cross-community bridge._
- **What connects `graphify`, ``ServerScriptService/LevelingSystem` — Script`, ``ServerScriptService/EnemyCombat` — Script` to the rest of the system?**
  _58 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `RemoteEvents folder` be split into smaller, more focused modules?**
  _Cohesion score 0.1111111111111111 - nodes in this community are weakly interconnected._
- **Should `ServerScriptService` be split into smaller, more focused modules?**
  _Cohesion score 0.13333333333333333 - nodes in this community are weakly interconnected._
- **Should ``StarterPlayer/StarterPlayerScripts` — StarterPlayerScripts` be split into smaller, more focused modules?**
  _Cohesion score 0.13333333333333333 - nodes in this community are weakly interconnected._