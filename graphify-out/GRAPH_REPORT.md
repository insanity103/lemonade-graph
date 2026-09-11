# Graph Report - lemonade-game  (2026-09-10)

## Corpus Check
- Corpus is ~26,098 words - fits in a single context window. You may not need a graph.

## Summary
- 222 nodes · 394 edges · 17 communities (12 shown, 2 thin omitted)
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 28 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- InventoryService.luau
- RemoteEvents folder
- EnemyCombat.server.luau
- AnimationController.luau
- MainMenuGui.client.luau
- LevelingSystem.server.luau
- Config folder (Sword, Items, RebirthConfig, WeaponModifiers, MerchantConfig, BossWeapons)
- SwordDropSystem.server.luau
- PlayerDataService.luau
- DayCycle.server.luau
- SwordSystem.server.luau
- MerchantGui.client.luau
- Boulder decor set (5 Models)
- Tree decor set (10 Models)

## God Nodes (most connected - your core abstractions)
1. `RemoteEvents folder` - 16 edges
2. `buildInventoryPanel()` - 10 edges
3. `createEnemyRig()` - 8 edges
4. `validateItemId()` - 8 edges
5. `InventoryService.LoadPlayer()` - 8 edges
6. `addCorner()` - 8 edges
7. `createText()` - 8 edges
8. `openTab()` - 8 edges
9. `BossSwordFactory.build()` - 7 edges
10. `connectEnemyHumanoid()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `Player SpawnLocation` --conceptually_related_to--> `setupPlayer()`  [INFERRED]
  lemonade-game/world/Workspace.md → ServerScriptService/LevelingSystem.server.luau
- `Runtime-spawned enemy rigs` --conceptually_related_to--> `connectEnemyHumanoid()`  [INFERRED]
  lemonade-game/world/Workspace.md → ServerScriptService/LevelingSystem.server.luau
- `Runtime-spawned enemy rigs` --conceptually_related_to--> `hook()`  [INFERRED]
  lemonade-game/world/Workspace.md → ServerScriptService/SwordDropSystem.server.luau
- `BossSwordFactory.build()` --calls--> `BossWeapons.Get()`  [INFERRED]
  ServerScriptService/BossSwordFactory.luau → ReplicatedStorage/Config/BossWeapons.luau
- `BossSwordFactory.build()` --calls--> `BossWeapons.GetTier()`  [INFERRED]
  ServerScriptService/BossSwordFactory.luau → ReplicatedStorage/Config/BossWeapons.luau

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Boss weapon drop + auto-sell loop** — lemonade_game_world_workspace_runtimeenemies, lemonade_game_world_serverstorage_bossswordtool, lemonade_game_world_serverstorage_swordmeshtemplate, lemonade_game_world_replicatedstorage_remoteevents_sworddrop, lemonade_game_world_replicatedstorage_remoteevents_toggleautosell, lemonade_game_world_replicatedstorage_remoteevents_autosellnotice, serverscriptservice_sworddropsystem_server, replicatedstorage_config_weaponmodifiers, replicatedstorage_config_rebirthconfig, starterplayer_starterplayerscripts_sworddroptoast_client, starterplayer_starterplayerscripts_mainmenugui_client, replicatedstorage_config_bossweapons, serverscriptservice_bossswordfactory [EXTRACTED 1.00]
- **Cross-session player save/load** — world_persistence_playerdata, serverscriptservice_playerdatastore_server, serverscriptservice_playerdataservice, replicatedstorage_config_saveconfig, serverscriptservice_inventoryservice, serverscriptservice_bossswordfactory, serverscriptservice_inventorysystem_server [EXTRACTED 1.00]
- **Day/night lighting stack** — lemonade_game_world_lighting_sky, lemonade_game_world_lighting_atmosphere, lemonade_game_world_lighting_bloom, lemonade_game_world_lighting_sunrays, lemonade_game_world_lighting_depthoffield, workspace_daycycle_server [EXTRACTED 1.00]
- **Merchant sword purchase** — lemonade_game_world_replicatedstorage_remoteevents_merchantaction, lemonade_game_world_replicatedstorage_remoteevents_sworddrop, lemonade_game_world_serverstorage_bossswordtool, serverscriptservice_merchantsystem_server, starterplayer_starterplayerscripts_merchantgui_client, replicatedstorage_config_merchantconfig, replicatedstorage_config_bossweapons, serverscriptservice_bossswordfactory [EXTRACTED 1.00]
- **Rebirth progression** — replicatedstorage_config_rebirthconfig, serverscriptservice_rebirthsystem_server, lemonade_game_world_replicatedstorage_remoteevents_rebirth, lemonade_game_world_replicatedstorage_remoteevents_rebirthresult, starterplayer_starterplayerscripts_mainmenugui_client, serverscriptservice_swordsystem_server, serverscriptservice_sworddropsystem_server [EXTRACTED 1.00]

## Communities (17 total, 2 thin omitted)

### Community 0 - "InventoryService.luau"
Cohesion: 0.19
Nodes (25): ensureDataFolder(), findOwnedTool(), findToolTemplate(), getDataFolder(), getInventorySnapshot(), getItemDefinition(), getOrCreateInventory(), InventoryService.AddItem() (+17 more)

### Community 1 - "RemoteEvents folder"
Cohesion: 0.12
Nodes (18): RemoteEvents folder, EnemyAttack (RemoteEvent), InventoryAction (RemoteEvent), InventoryUpdated (RemoteEvent), Rebirth (RemoteEvent), RebirthResult (RemoteEvent), SpendSkillPoint (RemoteEvent), ToggleAutoAttack (RemoteEvent) (+10 more)

### Community 2 - "EnemyCombat.server.luau"
Cohesion: 0.14
Nodes (19): Lemonade RPG place (root), BossSwordTool (Tool), Importer 180 deg Y flip, SwordMeshTemplate (MeshPart), Voxel Terrain, Baseplate, Runtime-spawned enemy rigs, Player SpawnLocation (+11 more)

### Community 3 - "AnimationController.luau"
Cohesion: 0.10
Nodes (13): Starter sword blade assembly, ClassicSword (Tool), ClassicSword Handle, SwordLunge sound (unused), SwordSlash sound, Unsheath sound, AnimationController.Play(), AnimationExecutor.new() (+5 more)

### Community 4 - "MainMenuGui.client.luau"
Cohesion: 0.26
Nodes (19): addCorner(), addPadding(), addStroke(), bindInventoryRefresh(), buildHomePanel(), buildInventoryPanel(), buildRebirthPanel(), buildSettingsPanel() (+11 more)

### Community 5 - "LevelingSystem.server.luau"
Cohesion: 0.18
Nodes (13): LevelUpBurst (RemoteEvent), XPGain (RemoteEvent), applyDeathGoldPenalty(), applyHealth(), awardExperience(), connectEnemyHumanoid(), getEnemyGold(), getEnemyReward() (+5 more)

### Community 6 - "Config folder (Sword, Items, RebirthConfig, WeaponModifiers, MerchantConfig, BossWeapons)"
Cohesion: 0.15
Nodes (8): Config folder (Sword, Items, RebirthConfig, WeaponModifiers, MerchantConfig, BossWeapons), BossWeapons.Get(), BossWeapons.GetTier(), WeaponModifiers.RollModifiers(), BossSwordFactory.build(), BossSwordFactory.rebuild(), CombatUtil.applyWeaponAppearance(), CombatUtil.isEnemy()

### Community 7 - "SwordDropSystem.server.luau"
Cohesion: 0.17
Nodes (12): AutoSellNotice (RemoteEvent), GoldGain (RemoteEvent), SwordDrop (RemoteEvent), ToggleAutoSell (RemoteEvent), RebirthConfig.GetEffectiveDropChance(), bindPlayer(), getEquippedWeaponSlots(), getWeaponSlots() (+4 more)

### Community 8 - "PlayerDataService.luau"
Cohesion: 0.23
Nodes (12): defaultData(), keyFor(), lockHeldByOther(), PlayerDataService.Load(), PlayerDataService.Release(), PlayerDataService.Save(), PlayerDataService.SaveAll(), PlayerDataService.Serialize() (+4 more)

### Community 9 - "DayCycle.server.luau"
Cohesion: 0.25
Nodes (10): Lighting/Atmosphere, Lighting/BloomEffect, Lighting/DepthOfFieldEffect, Lighting/Sky, Lighting/SunRaysEffect, makeDawn(), makeDay(), makeDusk() (+2 more)

### Community 10 - "SwordSystem.server.luau"
Cohesion: 0.31
Nodes (7): DamageNumber (RemoteEvent), applyDamage(), applyKnockback(), calculateDamage(), performSwing(), setupCharacter(), setupTool()

### Community 11 - "MerchantGui.client.luau"
Cohesion: 0.28
Nodes (5): MerchantAction (RemoteEvent), makePurchasedSword(), buildShopList(), formatGold(), setShopOpen()

## Knowledge Gaps
- **12 isolated node(s):** `Tree decor set (10 Models)`, `Boulder decor set (5 Models)`, `Baseplate`, `Starter sword blade assembly`, `SwordSlash sound` (+7 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 41 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `RemoteEvents folder` connect `RemoteEvents folder` to `EnemyCombat.server.luau`, `LevelingSystem.server.luau`, `SwordDropSystem.server.luau`, `SwordSystem.server.luau`, `MerchantGui.client.luau`?**
  _High betweenness centrality (0.337) - this node is a cross-community bridge._
- **Why does `InventoryUpdated (RemoteEvent)` connect `RemoteEvents folder` to `InventoryService.luau`, `MainMenuGui.client.luau`?**
  _High betweenness centrality (0.190) - this node is a cross-community bridge._
- **Why does `ClassicSword (Tool)` connect `AnimationController.luau` to `EnemyCombat.server.luau`, `SwordSystem.server.luau`, `SwordDropSystem.server.luau`?**
  _High betweenness centrality (0.182) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `InventoryService.LoadPlayer()` (e.g. with `setupPlayer()` and `PlayerDataService.Apply()`) actually correct?**
  _`InventoryService.LoadPlayer()` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Tree decor set (10 Models)`, `Boulder decor set (5 Models)`, `Baseplate` to the rest of the system?**
  _12 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `RemoteEvents folder` be split into smaller, more focused modules?**
  _Cohesion score 0.11594202898550725 - nodes in this community are weakly interconnected._
- **Should `EnemyCombat.server.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.1383399209486166 - nodes in this community are weakly interconnected._
## Manual Trace

Hand-traced findings, kept in `~/lemonade-graph/manual_trace.md` and re-appended after every rebuild (the report generator rewrites this file from scratch). Last verified against the 2026-09-10 sync.

**Open**

1. **The merchant duplicates the boss-sword builder.** `MerchantSystem` carries its own copy of `SwordDropSystem`'s `BOSS_WEAPONS` table and of `makeBossSword()` (rename, stat attributes, modifier prefixes, retint, SwordClient copy). The copy had already inherited the Neon texture bug below and needed the same fix separately. Any change to a boss weapon's stats or appearance must currently be made in both files. Candidate for moving into a shared module alongside `CombatUtil`.

**Resolved**

2. ~~`RebirthResult` is orphaned.~~ `RebirthSystem` fires `RebirthResult(ok, rebirths, requiredLevel)` on both the refusal and success paths, but its only listener was `RebirthGui`, which Lemonade deleted when rebirth moved into `MainMenuGui`. A refused rebirth therefore failed silently. `MainMenuGui` now subscribes to it, stores the last result, and `buildRebirthPanel()` renders it as a status line — green "Rebirth complete" or red "Not yet — level N required" — rebuilding the panel if the Rebirth tab is open when the event arrives.
3. ~~Neon hides the boss-sword texture on tiers 3–5.~~ The imported blade is a textured MeshPart, and `Enum.Material.Neon` renders a flat glow in place of the texture. All three places that dress a boss sword — the boss rig (`EnemyCombat`), the boss drop (`SwordDropSystem.makeBossSword`) and the merchant's copy (`MerchantSystem`) — now route colour/material through `CombatUtil.applyWeaponAppearance()`, which honours Neon on a textured MeshPart as Metal plus a tinted `PointLight` named `BladeGlow`. The artwork survives and the blade still reads as glowing; every other material is applied unchanged, so Metal (Iron Warlord) and Ice (Frost Revenant) are untouched. Behaviour covered by 17 edit-mode checks against the real `SwordMeshTemplate`.
4. ~~`isEnemy()` is defined three times.~~ Now one definition in `ServerScriptService/CombatUtil`, aliased by `EnemyCombat`, `LevelingSystem` and `SwordSystem`. The copies had already drifted: `LevelingSystem`'s lacked the `IsA("Model")` guard and would error when handed a non-Model. A fourth inline variant inside `SwordDropSystem.hook()` was folded in too. `ENEMY_TAG` / `ENEMY_ATTRIBUTE` now come from the module rather than being re-declared per script.
5. ~~Two overlapping melee paths fire on one left-click.~~ Fixed by Lemonade: `CombatController.fireAttack()` calls `tool:Activate()` when a sword is equipped and only fires `EnemyAttack` when unarmed. Both paths share one formula shape (+5/Strength, +12%/weapon level, sword and rebirth multipliers, crit); they differ only in base damage, 30 armed vs 25 unarmed.

**Context**

- Studio's 3D importer rotates imported meshes 180° about Y, so `SwordMeshTemplate` is grip-at−Z. Every placement of it needs `CFrame.Angles(0, math.pi, 0)`; the graph carries this as the "Importer 180 deg Y flip" node.
- `CombatUtil` is the shared server helper module. Lemonade generates scripts independently and may reintroduce local `isEnemy` copies or raw `.Material` writes on sword handles; if so, re-point them at the module rather than re-fixing by hand.
