# ReplicatedStorage

Roblox service in place `game` (PlaceId 108354544637319). 29 descendant instances.

Every instance below is a live object in the game hierarchy. Paths are Roblox instance paths; `Referenced by script(s)` lists the Luau source files that mention the instance by name.

## `ReplicatedStorage/AnimationController` — ModuleScript
Source file: `ReplicatedStorage/AnimationController.luau` (268 lines)
- Attributes: _lemonadeUniqueId = zar2gJKCzar2
- Referenced by script(s): StarterPack/ClassicSword/SwordClient

## `ReplicatedStorage/RemoteEvents` — Folder
- Attributes: _lemonadeUniqueId = 1ciW710q1ciW
- Children (17): EnemyAttack (RemoteEvent), DamageNumber (RemoteEvent), XPGain (RemoteEvent), SpendSkillPoint (RemoteEvent), GoldGain (RemoteEvent), LevelUpBurst (RemoteEvent), ToggleAutoAttack (RemoteEvent), InventoryUpdated (RemoteEvent), InventoryAction (RemoteEvent), Rebirth (RemoteEvent), RebirthResult (RemoteEvent), SwordDrop (RemoteEvent), ToggleAutoSell (RemoteEvent), AutoSellNotice (RemoteEvent), MerchantAction (RemoteEvent), SwordLostOnDeath (RemoteEvent), BossDoorNotice (RemoteEvent)
- Referenced by script(s): ServerScriptService/EnemyCombat, ServerScriptService/InventoryService, ServerScriptService/InventorySystem, ServerScriptService/LevelingSystem, ServerScriptService/MerchantSystem, ServerScriptService/RebirthSystem, ServerScriptService/SwordDropSystem, ServerScriptService/SwordSystem, StarterPlayer/StarterPlayerScripts/CombatController, StarterPlayer/StarterPlayerScripts/DamageNumbers, StarterPlayer/StarterPlayerScripts/GoldNumbers, StarterPlayer/StarterPlayerScripts/LevelUpBurst, StarterPlayer/StarterPlayerScripts/MainMenuGui, StarterPlayer/StarterPlayerScripts/MerchantGui, StarterPlayer/StarterPlayerScripts/SwordDropToast, StarterPlayer/StarterPlayerScripts/XPGainUI

### `ReplicatedStorage/RemoteEvents/EnemyAttack` — RemoteEvent
- Attributes: _lemonadeUniqueId = SpYVrcDpSpYV
- Referenced by script(s): ServerScriptService/EnemyCombat, StarterPlayer/StarterPlayerScripts/CombatController

### `ReplicatedStorage/RemoteEvents/DamageNumber` — RemoteEvent
- Attributes: _lemonadeUniqueId = ERlcsP8oERlc
- Referenced by script(s): ServerScriptService/EnemyCombat, ServerScriptService/SwordSystem, StarterPlayer/StarterPlayerScripts/DamageNumbers

### `ReplicatedStorage/RemoteEvents/XPGain` — RemoteEvent
- Attributes: _lemonadeUniqueId = Oae8Q566Oae8
- Referenced by script(s): ServerScriptService/LevelingSystem, StarterPlayer/StarterPlayerScripts/XPGainUI

### `ReplicatedStorage/RemoteEvents/SpendSkillPoint` — RemoteEvent
- Attributes: _lemonadeUniqueId = UoxsBHfDUoxs
- Referenced by script(s): ServerScriptService/LevelingSystem, StarterPlayer/StarterPlayerScripts/CombatController, StarterPlayer/StarterPlayerScripts/MainMenuGui

### `ReplicatedStorage/RemoteEvents/GoldGain` — RemoteEvent
- Attributes: _lemonadeUniqueId = ybENG74uybEN
- Referenced by script(s): ServerScriptService/LevelingSystem, ServerScriptService/SwordDropSystem, StarterPlayer/StarterPlayerScripts/GoldNumbers

### `ReplicatedStorage/RemoteEvents/LevelUpBurst` — RemoteEvent
- Attributes: _lemonadeUniqueId = gbPNxqcEgbPN
- Referenced by script(s): ServerScriptService/LevelingSystem, StarterPlayer/StarterPlayerScripts/LevelUpBurst

### `ReplicatedStorage/RemoteEvents/ToggleAutoAttack` — RemoteEvent
- Attributes: _lemonadeUniqueId = C8PdcglhC8Pd
- Referenced by script(s): ServerScriptService/EnemyCombat, StarterPlayer/StarterPlayerScripts/CombatController

### `ReplicatedStorage/RemoteEvents/InventoryUpdated` — RemoteEvent
- Attributes: _lemonadeUniqueId = o7yf2GG4o7yf
- Referenced by script(s): ServerScriptService/InventoryService, StarterPlayer/StarterPlayerScripts/MainMenuGui

### `ReplicatedStorage/RemoteEvents/InventoryAction` — RemoteEvent
- Attributes: _lemonadeUniqueId = xfVZjcwyxfVZ
- Referenced by script(s): ServerScriptService/InventorySystem, StarterPlayer/StarterPlayerScripts/MainMenuGui

### `ReplicatedStorage/RemoteEvents/Rebirth` — RemoteEvent
- Attributes: _lemonadeUniqueId = iFRAI3WIiFRA
- Referenced by script(s): ServerScriptService/RebirthSystem, StarterPlayer/StarterPlayerScripts/MainMenuGui

### `ReplicatedStorage/RemoteEvents/RebirthResult` — RemoteEvent
- Attributes: _lemonadeUniqueId = wGuf6dZHwGuf
- Referenced by script(s): ServerScriptService/RebirthSystem, StarterPlayer/StarterPlayerScripts/MainMenuGui

### `ReplicatedStorage/RemoteEvents/SwordDrop` — RemoteEvent
- Attributes: _lemonadeUniqueId = DycxiyxDDycx
- Referenced by script(s): ServerScriptService/MerchantSystem, ServerScriptService/SwordDropSystem, StarterPlayer/StarterPlayerScripts/SwordDropToast

### `ReplicatedStorage/RemoteEvents/ToggleAutoSell` — RemoteEvent
- Referenced by script(s): ServerScriptService/SwordDropSystem, StarterPlayer/StarterPlayerScripts/MainMenuGui

### `ReplicatedStorage/RemoteEvents/AutoSellNotice` — RemoteEvent
- Referenced by script(s): ServerScriptService/SwordDropSystem, StarterPlayer/StarterPlayerScripts/SwordDropToast

### `ReplicatedStorage/RemoteEvents/MerchantAction` — RemoteEvent
- Referenced by script(s): ServerScriptService/MerchantSystem, StarterPlayer/StarterPlayerScripts/MerchantGui

### `ReplicatedStorage/RemoteEvents/SwordLostOnDeath` — RemoteEvent
Server -> client. Fired by SwordDropSystem's death handler when the 2% roll destroys the equipped boss sword instead of sparing it; SwordDropToast shows a red "shattered" card.
- Referenced by script(s): ServerScriptService/SwordDropSystem, StarterPlayer/StarterPlayerScripts/SwordDropToast

### `ReplicatedStorage/RemoteEvents/BossDoorNotice` — RemoteEvent
Server -> client. Fired by BossRoomGate when it moves an under-level player out of a boss room; BossDoorClient shows the reason.
- Referenced by script(s): ServerScriptService/BossRoomGate, StarterPlayer/StarterPlayerScripts/BossDoorClient

## `ReplicatedStorage/Animations` — Folder
- Attributes: _lemonadeUniqueId = mMxrkPhZmMxr
- Children (1): Sword Attack Animation (ModuleScript)
- Referenced by script(s): ReplicatedStorage/AnimationController

### `ReplicatedStorage/Animations/Sword Attack Animation` — ModuleScript
Source file: `ReplicatedStorage/Animations/SwordAttackAnimation.luau` (119 lines)
- Attributes: _lemonadeUniqueId = H1EXYM4wH1EX
- Referenced by script(s): StarterPack/ClassicSword/SwordClient

## `ReplicatedStorage/Config` — Folder
- Attributes: _lemonadeUniqueId = pFXij36apFXi
- Children (7): Sword (ModuleScript), Items (ModuleScript), RebirthConfig (ModuleScript), WeaponModifiers (ModuleScript), MerchantConfig (ModuleScript), BossWeapons (ModuleScript), SaveConfig (ModuleScript)
- Referenced by script(s): ServerScriptService/InventoryService, ServerScriptService/MerchantSystem, ServerScriptService/RebirthSystem, ServerScriptService/SwordDropSystem, ServerScriptService/SwordSystem, StarterPlayer/StarterPlayerScripts/MainMenuGui, StarterPlayer/StarterPlayerScripts/MerchantGui

### `ReplicatedStorage/Config/Sword` — ModuleScript
Source file: `ReplicatedStorage/Config/Sword.luau` (9 lines)
- Attributes: _lemonadeUniqueId = PCMZpdZfPCMZ
- Referenced by script(s): ServerScriptService/EnemyCombat, ServerScriptService/SwordSystem

### `ReplicatedStorage/Config/Items` — ModuleScript
Source file: `ReplicatedStorage/Config/Items.luau` (10 lines)
- Attributes: _lemonadeUniqueId = YA957FlnYA95
- Referenced by script(s): ServerScriptService/InventoryService, StarterPlayer/StarterPlayerScripts/MainMenuGui

### `ReplicatedStorage/Config/RebirthConfig` — ModuleScript
Rebirth tuning: level gate (20 + 15/rebirth), per-rebirth XP/gold/damage/health multipliers, per-rarity drop-rate bonuses, and the five milestone perks.
Source file: `ReplicatedStorage/Config/RebirthConfig.luau` (85 lines)
- Referenced by script(s): ServerScriptService/RebirthSystem, ServerScriptService/SwordDropSystem

### `ReplicatedStorage/Config/WeaponModifiers` — ModuleScript
Modifier roller for boss drops: four categories (Damage, CritChance, Range, Knockback) x four tiers, slot count set by rarity, 3% base chance of a Blessed extra slot.
Source file: `ReplicatedStorage/Config/WeaponModifiers.luau` (117 lines)
- Referenced by script(s): ServerScriptService/MerchantSystem, ServerScriptService/SwordDropSystem, StarterPlayer/StarterPlayerScripts/MainMenuGui

### `ReplicatedStorage/Config/MerchantConfig` — ModuleScript
Merchant catalogue, looked up by id through `MerchantConfig.GetItem()`. Holds only prices and shop blurbs; name, rarity, multiplier, colour and inherent bonuses are filled in from `BossWeapons` at load, so the shop always shows the stats the sword will actually have.
Source file: `ReplicatedStorage/Config/MerchantConfig.luau` (47 lines)
- Referenced by script(s): ServerScriptService/MerchantSystem, StarterPlayer/StarterPlayerScripts/MerchantGui

### `ReplicatedStorage/Config/BossWeapons` — ModuleScript
Single source of truth for the five boss weapons — tier, name, rarity, damage multiplier, colour, material and inherent bonuses — keyed by EnemyCombat archetype. Replicated so `MerchantConfig`, and through it the client `MerchantGui`, can read it. Replaces the copies that used to live in SwordDropSystem, MerchantSystem and MerchantConfig.
Source file: `ReplicatedStorage/Config/BossWeapons.luau` (96 lines)
- Referenced by script(s): ReplicatedStorage/Config/MerchantConfig, ServerScriptService/BossSwordFactory, ServerScriptService/SwordDropSystem

### `ReplicatedStorage/Config/SaveConfig` — ModuleScript
Declares what persists between sessions and how: DataStore name/version, autosave interval, session-lock timeout, retry count, and the lists of leaderstats, player attributes and per-sword attributes that `PlayerDataService` reads and writes.
Source file: `ReplicatedStorage/Config/SaveConfig.luau` (38 lines)
- Referenced by script(s): ServerScriptService/PlayerDataService, ServerScriptService/PlayerDataStore
