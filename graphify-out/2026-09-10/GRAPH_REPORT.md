# Graph Report - lemonade-game  (2026-09-10)

## Corpus Check
- Corpus is ~18,988 words - fits in a single context window. You may not need a graph.

## Summary
- 190 nodes · 326 edges · 18 communities (12 shown, 3 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 10 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Inventory Service
- Main Menu UI
- Enemy AI, Terrain & Spawning
- XP, Gold & Leveling
- WeaponSmith Shop & Upgrades
- Client Combat & Skill Points
- Day/Night Lighting
- ClassicSword Tool & Audio
- Sword Animation Playback
- Sword Hitbox & Damage Numbers
- Rebirth System
- Sword Rarity Drops
- Shared Config Tables
- Boulder Decor
- Tree Decor

## God Nodes (most connected - your core abstractions)
1. `RemoteEvents folder` - 15 edges
2. `openTab()` - 10 edges
3. `addCorner()` - 9 edges
4. `createText()` - 9 edges
5. `validateItemId()` - 8 edges
6. `connectEnemyHumanoid()` - 8 edges
7. `createEnemyRig()` - 7 edges
8. `InventoryService.UseItem()` - 7 edges
9. `InventoryService.LoadPlayer()` - 7 edges
10. `clearBody()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `Player SpawnLocation` --conceptually_related_to--> `setupPlayer()`  [INFERRED]
  lemonade-game/world/Workspace.md → ServerScriptService/LevelingSystem.server.luau
- `Runtime-spawned enemy rigs` --conceptually_related_to--> `connectEnemyHumanoid()`  [INFERRED]
  lemonade-game/world/Workspace.md → ServerScriptService/LevelingSystem.server.luau
- `Runtime-spawned enemy rigs` --conceptually_related_to--> `hook()`  [INFERRED]
  lemonade-game/world/Workspace.md → ServerScriptService/SwordDropSystem.server.luau
- `Voxel Terrain` --references--> `resolveGroundPosition()`  [EXTRACTED]
  lemonade-game/world/Terrain.md → ServerScriptService/EnemyCombat.server.luau
- `Runtime-spawned enemy rigs` --references--> `createEnemyRig()`  [EXTRACTED]
  lemonade-game/world/Workspace.md → ServerScriptService/EnemyCombat.server.luau

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Day/night lighting stack** — lemonade_game_world_lighting_sky, lemonade_game_world_lighting_atmosphere, lemonade_game_world_lighting_bloom, lemonade_game_world_lighting_sunrays, lemonade_game_world_lighting_depthoffield, workspace_daycycle_server [EXTRACTED 1.00]
- **Sword rarity drop loop** — lemonade_game_world_workspace_runtimeenemies, lemonade_game_world_starterpack_classicsword, lemonade_game_world_starterpack_handle, lemonade_game_world_replicatedstorage_remoteevents_sworddrop, serverscriptservice_sworddropsystem_server, starterplayer_starterplayerscripts_sworddroptoast_client [EXTRACTED 1.00]
- **WeaponSmith gold-upgrade flow** — lemonade_game_world_workspace_weaponsmith, lemonade_game_world_workspace_weaponsmith_clickdetector, serverscriptservice_weaponsmithnpc_server, lemonade_game_world_replicatedstorage_remoteevents_openweaponupgrade, lemonade_game_world_replicatedstorage_remoteevents_upgradeweapon, starterplayer_starterplayerscripts_weaponupgradegui_client, serverscriptservice_weaponupgrade_server [EXTRACTED 1.00]

## Communities (18 total, 3 thin omitted)

### Community 0 - "Inventory Service"
Cohesion: 0.22
Nodes (23): ensureDataFolder(), findToolTemplate(), getDataFolder(), getInventorySnapshot(), getItemDefinition(), getOrCreateInventory(), healPlayer(), InventoryService.AddItem() (+15 more)

### Community 1 - "Main Menu UI"
Cohesion: 0.24
Nodes (19): addCorner(), addPadding(), buildHomePanel(), buildInventoryPanel(), buildSettingsPanel(), buildShopPanel(), buildSkillsPanel(), buildUpgradesPanel() (+11 more)

### Community 2 - "Enemy AI, Terrain & Spawning"
Cohesion: 0.16
Nodes (17): Lemonade RPG place (root), Voxel Terrain, Baseplate, Runtime-spawned enemy rigs, applyEnemyDamageToPlayer(), attackEnemy(), createEnemyRig(), createMotor6D() (+9 more)

### Community 3 - "XP, Gold & Leveling"
Cohesion: 0.16
Nodes (14): LevelUpBurst (RemoteEvent), XPGain (RemoteEvent), Player SpawnLocation, applyHealth(), awardExperience(), connectEnemyHumanoid(), getEnemyGold(), getEnemyReward() (+6 more)

### Community 4 - "WeaponSmith Shop & Upgrades"
Cohesion: 0.14
Nodes (11): RemoteEvents folder, GoldGain (RemoteEvent), InventoryAction (RemoteEvent), InventoryUpdated (RemoteEvent), OpenWeaponUpgrade (RemoteEvent), UpgradeWeapon (RemoteEvent), WeaponSmith NPC (Model), WeaponSmith ClickDetector (+3 more)

### Community 5 - "Client Combat & Skill Points"
Cohesion: 0.19
Nodes (8): EnemyAttack (RemoteEvent), SpendSkillPoint (RemoteEvent), ToggleAutoAttack (RemoteEvent), findClosestLivingEnemy(), fireAttack(), getEquippedTool(), handleAttack(), isLivingEnemy()

### Community 6 - "Day/Night Lighting"
Cohesion: 0.25
Nodes (10): Lighting/Atmosphere, Lighting/BloomEffect, Lighting/DepthOfFieldEffect, Lighting/Sky, Lighting/SunRaysEffect, makeDawn(), makeDay(), makeDusk() (+2 more)

### Community 7 - "ClassicSword Tool & Audio"
Cohesion: 0.22
Nodes (8): ClassicSword (Tool), ClassicSword Handle, SwordLunge sound (unused), SwordSlash sound, Unsheath sound, OnChanged(), OnEquipped(), UpdateIcon()

### Community 8 - "Sword Animation Playback"
Cohesion: 0.22
Nodes (4): AnimationController.Play(), AnimationExecutor.new(), ensureExecutor(), onActivated()

### Community 9 - "Sword Hitbox & Damage Numbers"
Cohesion: 0.31
Nodes (7): DamageNumber (RemoteEvent), applyDamage(), getDamage(), isEnemy(), performSwing(), setupCharacter(), setupTool()

### Community 10 - "Rebirth System"
Cohesion: 0.29
Nodes (7): Rebirth (RemoteEvent), RebirthResult (RemoteEvent), getOrCreateIntValue(), requiredLevel(), setupPlayer(), currentLevel(), refresh()

### Community 11 - "Sword Rarity Drops"
Cohesion: 0.33
Nodes (7): SwordDrop (RemoteEvent), bindPlayer(), giveSword(), hook(), makeSword(), rollRarity(), watchCharacter()

## Knowledge Gaps
- **12 isolated node(s):** `WeaponSmith Dialog (unused)`, `Tree decor set (10 Models)`, `Boulder decor set (5 Models)`, `Baseplate`, `SwordSlash sound` (+7 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 41 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `RemoteEvents folder` connect `WeaponSmith Shop & Upgrades` to `Enemy AI, Terrain & Spawning`, `XP, Gold & Leveling`, `Client Combat & Skill Points`, `Sword Hitbox & Damage Numbers`, `Rebirth System`, `Sword Rarity Drops`?**
  _High betweenness centrality (0.456) - this node is a cross-community bridge._
- **Why does `InventoryUpdated (RemoteEvent)` connect `WeaponSmith Shop & Upgrades` to `Inventory Service`, `Main Menu UI`?**
  _High betweenness centrality (0.211) - this node is a cross-community bridge._
- **Why does `Lemonade RPG place (root)` connect `Enemy AI, Terrain & Spawning` to `XP, Gold & Leveling`, `WeaponSmith Shop & Upgrades`, `ClassicSword Tool & Audio`?**
  _High betweenness centrality (0.193) - this node is a cross-community bridge._
- **What connects `WeaponSmith Dialog (unused)`, `Tree decor set (10 Models)`, `Boulder decor set (5 Models)` to the rest of the system?**
  _12 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `WeaponSmith Shop & Upgrades` be split into smaller, more focused modules?**
  _Cohesion score 0.13725490196078433 - nodes in this community are weakly interconnected._