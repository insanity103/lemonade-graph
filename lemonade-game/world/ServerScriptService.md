# ServerScriptService

Roblox service in place `game` (PlaceId 108354544637319). 12 descendant instances.

Every instance below is a live object in the game hierarchy. Paths are Roblox instance paths; `Referenced by script(s)` lists the Luau source files that mention the instance by name.

## `ServerScriptService/LevelingSystem` — Script
Source file: `ServerScriptService/LevelingSystem.server.luau` (329 lines)
- Attributes: _lemonadeUniqueId = uXjlOYyAuXjl

## `ServerScriptService/EnemyCombat` — Script
Source file: `ServerScriptService/EnemyCombat.server.luau` (952 lines)
- Attributes: _lemonadeUniqueId = sRtWeEplsRtW

## `ServerScriptService/SwordSystem` — Script
Source file: `ServerScriptService/SwordSystem.server.luau` (174 lines)
- Attributes: _lemonadeUniqueId = PaMKzy3tPaMK

## `ServerScriptService/InventoryService` — ModuleScript
Source file: `ServerScriptService/InventoryService.luau` (333 lines)
- Attributes: _lemonadeUniqueId = 44mwtRT144mw
- Referenced by script(s): ServerScriptService/InventorySystem

## `ServerScriptService/InventorySystem` — Script
Source file: `ServerScriptService/InventorySystem.server.luau` (56 lines)
- Attributes: _lemonadeUniqueId = t6i36dJ9t6i3

## `ServerScriptService/RebirthSystem` — Script
Source file: `ServerScriptService/RebirthSystem.server.luau` (122 lines)
- Attributes: _lemonadeUniqueId = v1aLM9gkv1aL

## `ServerScriptService/SwordDropSystem` — Script
Source file: `ServerScriptService/SwordDropSystem.server.luau` (233 lines)
- Attributes: _lemonadeUniqueId = OwjpQA9fOwjp

## `ServerScriptService/CombatUtil` — ModuleScript
Shared server helpers: the single `isEnemy()` definition (previously copied into three scripts) and `applyWeaponAppearance()`, which applies a weapon's colour/material but honours Neon on a textured MeshPart as Metal plus a tinted `BladeGlow` PointLight, so the sword artwork isn't erased.
Source file: `ServerScriptService/CombatUtil.luau` (52 lines)
- Referenced by script(s): ServerScriptService/EnemyCombat, ServerScriptService/LevelingSystem, ServerScriptService/SwordDropSystem, ServerScriptService/SwordSystem

## `ServerScriptService/MerchantSystem` — Script
Serves `MerchantAction` requests: checks and deducts the listed price, then builds the sword with `BossSwordFactory.build(id, { allowBlessed = false })` — purchases never roll a Blessed slot.
Source file: `ServerScriptService/MerchantSystem.server.luau` (232 lines)

## `ServerScriptService/BossSwordFactory` — ModuleScript
Builds an equippable boss weapon: clones `ServerStorage/BossSwordTool`, rolls `WeaponModifiers` prefixes, stamps the stat attributes combat reads, dresses the blade via `CombatUtil.applyWeaponAppearance()`, and copies in `SwordClient`. Shared by SwordDropSystem (boss drops, Blessed allowed) and MerchantSystem (purchases, `allowBlessed = false`), which used to carry near-identical copies of this code.
Source file: `ServerScriptService/BossSwordFactory.luau` (153 lines)
- Referenced by script(s): ServerScriptService/MerchantSystem, ServerScriptService/SwordDropSystem

## `ServerScriptService/PlayerDataService` — ModuleScript
Per-player DataStore persistence. `Load` claims a session lock and reads the profile; `Apply` writes it onto the player (leaderstats IntValues, attributes, inventory stacks via `InventoryService.LoadPlayer`, and boss swords rebuilt with `BossSwordFactory.rebuild`); `Serialize` reads current state back; `Save`/`Release` write it, verifying the lock. Falls back to memory-only with a warning when the DataStore is unavailable (Studio without API access).
Source file: `ServerScriptService/PlayerDataService.luau` (283 lines)
- Referenced by script(s): ServerScriptService/PlayerDataStore

## `ServerScriptService/PlayerDataStore` — Script
Drives `PlayerDataService` off the player lifecycle: load+apply on join (sets the `DataLoaded` attribute), save+release on `PlayerRemoving`, a periodic autosave loop, and a `BindToClose` save-all on shutdown.
Source file: `ServerScriptService/PlayerDataStore.server.luau` (48 lines)
