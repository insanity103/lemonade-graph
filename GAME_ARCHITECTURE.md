# Lemonade Game — Roblox Studio Architecture

> **Generated**: 2026-09-14 | **PlaceId**: 108354544637319 | **GameId**: 10765853284
> **Total Source**: 44 `.luau` files, ~8,820 lines across 5 Roblox services

---

## Project Structure

```
lemonade-game/
├── Workspace/                          # 1 server script (DayCycle)
│   └── DayCycle.server.luau            # Day/night lighting cycle (228 lines)
│
├── ServerScriptService/                # 16 files — all server-authoritative logic (~4,707 lines)
│   ├── RuntimeBootstrap.server.luau    # Startup init, ordering (136 lines)
│   ├── WorldBuilder.server.luau        # Thin wrapper → WorldLayout.EnsureBuilt() (5 lines)
│   ├── WorldLayout.luau                # World generation: terrain, routes, arenas, props (1,070 lines)
│   ├── EnemyCombat.server.luau         # Enemy AI, spawn, hit detection, damage (1,087 lines) ← LARGEST
│   ├── PlayerDataStore.server.luau     # DataStore lifecycle driver (53 lines)
│   ├── PlayerDataService.luau          # Per-player save/load with session locks (306 lines)
│   ├── LevelingSystem.server.luau      # XP, levels, skill points, leaderstats (401 lines)
│   ├── SwordSystem.server.luau         # Equipped sword damage + attack handling (177 lines)
│   ├── SwordDropSystem.server.luau     # Boss kill → loot drop, rarity, modifiers, auto-sell (244 lines)
│   ├── RebirthSystem.server.luau       # Prestige/rebirth system (134 lines)
│   ├── MerchantSystem.server.luau      # NPC shop: buy boss swords for gold (263 lines)
│   ├── InventoryService.luau           # Shared inventory module (339 lines)
│   ├── InventorySystem.server.luau     # Inventory event handler (47 lines)
│   ├── BossSwordFactory.luau           # Builds equippable boss weapon Tools (201 lines)
│   ├── BossRoomGate.server.luau        # Level-gated boss room doors via collision groups (140 lines)
│   └── CombatUtil.luau                 # Shared combat helpers: isEnemy, appearance, LoS (104 lines)
│
├── ReplicatedStorage/                  # Shared modules (server + client)
│   ├── AnimationController.luau        # Animation state machine, Motor6D driver (267 lines)
│   ├── Config/
│   │   ├── Sword.luau                  # Base sword stats (9 lines)
│   │   ├── Items.luau                  # Item definitions (9 lines)
│   │   ├── BossWeapons.luau            # 5 boss weapon definitions (108 lines)
│   │   ├── WeaponModifiers.luau        # Modifier roller: 4 categories × 4 tiers (117 lines)
│   │   ├── RebirthConfig.luau          # Rebirth thresholds, multipliers, milestones (84 lines)
│   │   ├── MerchantConfig.luau         # Shop catalogue (46 lines)
│   │   └── SaveConfig.luau             # DataStore schema definition (37 lines)
│   └── Animations/
│       └── Sword Attack Animation.luau # Keyframe data (118 lines)
│
├── StarterPlayer/StarterPlayerScripts/ # 11 client scripts (~2,204 lines)
│   ├── MainMenuGui.client.luau         # Main menu: Home/Inventory/Skills/Rebirth/Settings (863 lines) ← LARGEST CLIENT
│   ├── MerchantGui.client.luau         # Shop UI modal (328 lines)
│   ├── CombatController.client.luau    # Input, auto-attack, auto-skill (241 lines)
│   ├── SwordDropToast.client.luau      # Loot/auto-sell/shatter toasts (229 lines)
│   ├── LevelProgressGui.client.luau    # XP bar + level display (145 lines)
│   ├── BossDoorClient.client.luau      # Door sign painting + eject notice (102 lines)
│   ├── LevelUpBurst.client.luau        # Neon ball burst VFX (71 lines)
│   ├── DamageNumbers.client.luau       # Floating damage text (62 lines)
│   ├── XPGainUI.client.luau            # Floating XP numbers (59 lines)
│   ├── GoldNumbers.client.luau         # Floating gold numbers (50 lines)
│   └── RunController.client.luau       # Shift = sprint (37 lines)
│
├── StarterPack/ClassicSword/           # Starter weapon Tool
│   ├── SwordClient.client.luau         # Activation → animation + sound (36 lines)
│   └── MouseIcon.client.luau           # Custom cursor (28 lines)
│
├── ServerStorage/                      # Server-only templates (not in Rojo source)
│   ├── SwordMeshTemplate               # Imported boss blade MeshPart
│   └── BossSwordTool                   # Equippable boss weapon template Tool
│
└── world/                              # Semantic world documentation
    ├── place.json                      # Place hierarchy export
    ├── Workspace.md                    # 147 instances documented
    ├── ServerScriptService.md          # 13 scripts documented
    ├── ReplicatedStorage.md            # 29 instances documented
    ├── StarterPlayer.md                # 13 instances documented
    ├── StarterPack.md                  # 16 instances documented
    ├── ServerStorage.md                # 3 templates documented
    ├── Lighting.md                     # 5 lighting instances
    └── Terrain.md                      # Voxel terrain metadata
```

---

## Script Inventory

### Server Scripts (ServerScriptService)

| File | Type | Lines | Purpose | Dependencies |
|------|------|-------|---------|--------------|
| `RuntimeBootstrap.server.luau` | Server | 136 | Startup sequencing: loads systems in dependency order, creates RemoteEvents folder | All other server modules |
| `WorldBuilder.server.luau` | Server | 5 | Thin wrapper: calls `WorldLayout.EnsureBuilt()` | WorldLayout |
| `WorldLayout.luau` | Module | 1,070 | Builds entire game world: terrain, S-curve trail, 9 combat zones + 5 boss arenas, roads, lamps, signposts, trees, rocks, merchant NPC placement | Workspace.Terrain |
| `EnemyCombat.server.luau` | Server | 1,087 | Enemy spawning (per zone), AI (Humanoid:MoveTo chase), hit detection, damage calc, death handling, boss weapons, auto-attack loop, enemy scaling by level | CombatUtil, WorldLayout, Sword (config) |
| `PlayerDataStore.server.luau` | Server | 53 | Drives PlayerDataService off player lifecycle: load+apply on join, save+release on leave, autosave loop, BindToClose | PlayerDataService, SaveConfig |
| `PlayerDataService.luau` | Module | 306 | DataStore persistence: session lock, serialize/deserialize leaderstats + attributes + inventory + boss swords, retry logic | SaveConfig, InventoryService, BossSwordFactory |
| `LevelingSystem.server.luau` | Server | 401 | XP → Level progression, skill point allocation (Strength/Health/Defense/XP Gain), leaderstat management, XP curve | CombatUtil |
| `SwordSystem.server.luau` | Server | 177 | Equipped Tool sword damage path: hitbox overlap, damage formula, crit, knockback, cooldowns | CombatUtil, Sword (config) |
| `SwordDropSystem.server.luau` | Server | 244 | Boss kill → rarity roll → modifier roll → Tool creation, auto-sell lower-slot drops, death shatter (2% loss chance) | BossSwordFactory, BossWeapons, WeaponModifiers, RebirthConfig |
| `RebirthSystem.server.luau` | Server | 134 | Rebirth eligibility check, reset level/XP/attributes, apply permanent multipliers | RebirthConfig |
| `MerchantSystem.server.luau` | Server | 263 | NPC shop: validates gold, deducts, builds sword via BossSwordFactory (no Blessed rolls) | BossSwordFactory, MerchantConfig |
| `InventoryService.luau` | Module | 339 | Stack-based inventory: add/remove/transfer items, equip/unequip, sell for gold, snapshot for client | Items (config) |
| `InventorySystem.server.luau` | Server | 47 | Wires InventoryAction RemoteEvent to InventoryService | InventoryService |
| `BossSwordFactory.luau` | Module | 201 | Builds equippable boss weapon Tools: clone template, roll modifiers, stamp attributes, apply appearance, copy SwordClient | BossWeapons, WeaponModifiers, CombatUtil |
| `BossRoomGate.server.luau` | Server | 140 | Level-gated boss room doors via PhysicsService collision groups; ejects under-level players | WorldLayout, PhysicsService |
| `CombatUtil.luau` | Module | 104 | Shared helpers: `isEnemy()`, `applyWeaponAppearance()`, `hasLineOfSight()`, `getSwordMesh()`, `sizeSwordMesh()` | CollectionService, Workspace |

### Client Scripts (StarterPlayerScripts)

| File | Type | Lines | Purpose | Dependencies |
|------|------|-------|---------|--------------|
| `MainMenuGui.client.luau` | Client | 863 | Full menu UI: Home stats, Inventory (weapon cards + sell), Skills (point allocation), Rebirth, Settings. Press M to toggle | WeaponModifiers, Items, RemoteEvents |
| `MerchantGui.client.luau` | Client | 328 | Shop modal: lists merchant items with rarity colors, buy buttons, gold check | MerchantConfig, RemoteEvents |
| `CombatController.client.luau` | Client | 241 | Input: E/Click attack, Q toggle auto-attack, P toggle auto-skill. Auto-path toward enemies, face target, swing on interval | RemoteEvents |
| `SwordDropToast.client.luau` | Client | 229 | Toast cards for: sword drops (rarity-colored, shows modifiers), auto-sell notifications, death shatter notifications | RemoteEvents |
| `LevelProgressGui.client.luau` | Client | 145 | Bottom-left XP bar + level display with animated fill | leaderstats |
| `BossDoorClient.client.luau` | Client | 102 | Paints boss door signs OPEN/LOCKED, shows toast on locked-door touch, shows eject notices | RemoteEvents |
| `LevelUpBurst.client.luau` | Client | 71 | 36 neon ball burst VFX on level up | RemoteEvents |
| `DamageNumbers.client.luau` | Client | 62 | Floating damage numbers: red for crit, gold for normal, dark red for incoming | RemoteEvents |
| `XPGainUI.client.luau` | Client | 59 | Floating green "+N XP" text that rises and fades | RemoteEvents |
| `GoldNumbers.client.luau` | Client | 50 | Floating gold "+N Gold" text that rises and fades | RemoteEvents |
| `RunController.client.luau` | Client | 37 | LeftShift = sprint (26 speed vs 16 walk) | ContextActionService |

### Tool Scripts (StarterPack/ClassicSword)

| File | Type | Lines | Purpose | Dependencies |
|------|------|-------|---------|--------------|
| `SwordClient.client.luau` | Client | 36 | Tool activation → slash sound + AnimationController.Play("Sword Attack Animation") | AnimationController |
| `MouseIcon.client.luau` | Client | 28 | Custom cursor icon when tool is equipped | Mouse |

### Workspace Script

| File | Type | Lines | Purpose | Dependencies |
|------|------|-------|---------|--------------|
| `DayCycle.server.luau` | Server | 228 | Day/dusk/night/dawn lighting cycle using TweenService on Lighting, Atmosphere, Bloom, SunRays, ColorCorrection | Lighting, TweenService |

### Shared Modules (ReplicatedStorage)

| File | Type | Lines | Purpose | Dependencies |
|------|------|-------|---------|--------------|
| `AnimationController.luau` | Module | 267 | Animation runtime: drives Motor6D transforms per frame, lerp between keyframes, fade in/out, leg counter-rotation | Players, RunService |
| `Config/Sword.luau` | Config | 9 | Base sword stats: BaseDamage=30, StrengthPerPoint=5, WeaponDmgPerLevel=0.12, Cooldown=0.5, HitboxSize=(6,5,6) | — |
| `Config/Items.luau` | Config | 9 | Item registry: ClassicSword definition | — |
| `Config/BossWeapons.luau` | Config | 108 | 5 boss weapons: tiers, names, rarities, damage mults, colors, materials, inherent bonuses | — |
| `Config/WeaponModifiers.luau` | Config | 117 | 4 modifier categories (Damage/Crit/Range/Knockback) × 4 tiers, rarity→slot mapping, 3% Blessed chance | — |
| `Config/RebirthConfig.luau` | Config | 84 | Rebirth formula: BASE_LEVEL=20, +15/rebirth, per-rebirth multipliers, 5 milestone perks, drop rate bonuses | — |
| `Config/MerchantConfig.luau` | Config | 46 | Shop listings: 5 boss swords at 500–100K gold, stats pulled from BossWeapons | BossWeapons |
| `Config/SaveConfig.luau` | Config | 37 | DataStore schema: name "PlayerData_v1", autosave 120s, lock timeout 1200s, persisted fields | — |
| `Animations/Sword Attack Animation.luau` | Animation | 118 | Keyframe data: 9 timestamps over 1.9s, joint CFrame transforms for the sword swing | — |

---

## Data Model

### Persisted Data

DataStore name: **`PlayerData_v1`**
Key format: **`Player_{UserId}`**
Schema version: **1**
Autosave interval: **120 seconds**
Session lock timeout: **1200 seconds**
Max retries: **4**

#### Leaderstats (IntValues)

| Field | Default | Description |
|-------|---------|-------------|
| `Level` | 1 | Player level |
| `Experience` | 0 | Current XP toward next level |
| `Gold` | 0 | Primary currency |
| `Rebirths` | 0 | Number of rebirths completed |

#### Player Attributes

| Field | Default | Description |
|-------|---------|-------------|
| `SkillPoints` | 0 | Unspent skill points |
| `WeaponLevel` | 0 | Weapon upgrade level |
| `Strength` | 0 | +5 sword damage per point |
| `Health` | 0 | +20 max HP per point |
| `Defense` | 0 | +0.3% damage reduction per point (max 35%) |
| `ExperienceGain` | 0 | +0.5% XP bonus per point (max 35%) |
| `AutoSellLowerSwords` | false | Toggle: auto-sell drops with fewer modifier slots |

#### Boss Sword Attributes (per Tool in inventory)

| Field | Description |
|-------|-------------|
| `DamageMult` | Base damage multiplier (e.g., 2.20, 18.00) |
| `BonusDamagePct` | Rolled bonus damage percentage |
| `CritChance` | Rolled critical hit chance |
| `RangeBonus` | Rolled extra reach in studs |
| `KnockbackBonus` | Rolled knockback force |
| `ExtraSlot` | Boolean: has Blessed extra modifier slot |
| `Prefixes` | Comma-separated modifier names |
| `BossTier` | 1–5 tier index |
| `Rarity` | Common/Uncommon/Rare/Epic/Legendary |
| `BaseWeaponName` | Original weapon name (e.g., "Warlord Greatsword") |
| `WeaponAppearanceMaterial` | Material name for appearance restoration |

### Save Schema (SaveConfig)

```lua
SaveConfig.LEADERSTATS = { Level = 1, Experience = 0, Gold = 0, Rebirths = 0 }
SaveConfig.ATTRIBUTES = {
    SkillPoints = 0, WeaponLevel = 0, Strength = 0, Health = 0,
    Defense = 0, ExperienceGain = 0, AutoSellLowerSwords = false
}
SaveConfig.SWORD_ATTRS = {
    "DamageMult", "BonusDamagePct", "CritChance", "RangeBonus", "KnockbackBonus",
    "ExtraSlot", "Prefixes", "BossTier", "Rarity", "BaseWeaponName", "WeaponAppearanceMaterial"
}
```

---

## RemoteEvents/Functions

All communication flows through `ReplicatedStorage/RemoteEvents`. **No RemoteFunctions are used.**

| RemoteEvent | Direction | Purpose | Server Handler | Client Handler |
|-------------|-----------|---------|----------------|----------------|
| `EnemyAttack` | Client → Server | Unarmed attack intent | EnemyCombat | CombatController |
| `ToggleAutoAttack` | Client → Server | Toggle auto-attack on/off | EnemyCombat | CombatController |
| `DamageNumber` | Server → Client | Show floating damage text | EnemyCombat, SwordSystem | DamageNumbers |
| `XPGain` | Server → Client | Show floating XP gain | LevelingSystem | XPGainUI |
| `GoldGain` | Server → Client | Show floating gold gain | LevelingSystem, SwordDropSystem | GoldNumbers |
| `LevelUpBurst` | Server → Client | Trigger level-up VFX | LevelingSystem | LevelUpBurst |
| `SpendSkillPoint` | Client → Server | Allocate 1 point to attribute | LevelingSystem | CombatController, MainMenuGui |
| `InventoryUpdated` | Server → Client | Push inventory snapshot | InventoryService | MainMenuGui |
| `InventoryAction` | Client → Server | Equip/unequip/sell actions | InventorySystem | MainMenuGui |
| `SwordDrop` | Server → Client | Show sword drop toast card | SwordDropSystem, MerchantSystem | SwordDropToast |
| `SwordLostOnDeath` | Server → Client | Show "sword shattered" toast | SwordDropSystem | SwordDropToast |
| `AutoSellNotice` | Server → Client | Show auto-sell notification | SwordDropSystem | SwordDropToast |
| `ToggleAutoSell` | Client → Server | Toggle auto-sell setting | SwordDropSystem | MainMenuGui |
| `Rebirth` | Client → Server | Request rebirth | RebirthSystem | MainMenuGui |
| `RebirthResult` | Server → Client | Rebirth success/failure result | RebirthSystem | MainMenuGui |
| `MerchantAction` | Client → Server | Buy sword from merchant | MerchantSystem | MerchantGui |
| `BossDoorNotice` | Server → Client | Notify player ejected from boss room | BossRoomGate | BossDoorClient |
| `ComboUpdate` | Server → Client | Push current combo count to client HUD | SwordSystem | CombatController, ComboVFX |
| `HitlagEffect` | Server → Client | Trigger hitlag freeze on both attacker and victim | CombatUtil | CombatController |

**Total: 19 RemoteEvents, 0 RemoteFunctions**

---

## Game Systems Currently Implemented

### ✅ Working Systems

| System | Status | Notes |
|--------|--------|-------|
| **World Generation** | ✅ Complete | Procedural terrain with S-curve trail, 9 zones (5 boss + 4 bridge), road lamps, signposts, tree/rock clusters, merchant NPC placement |
| **Enemy Spawning** | ✅ Complete | Per-zone spawn configs from WorldLayout, 5 boss archetypes + regular enemies, ground-raycast positioning |
| **Combat (Armed)** | ✅ Complete | SwordSystem: overlap hitbox, damage formula, crit, knockback, cooldowns, weapon attributes |
| **Combat (Unarmed)** | ✅ Complete | EnemyCombat: unarmed path with separate base damage (25 vs 30), shares formula shape |
| **Auto-Attack** | ✅ Complete | Q toggle, client pathfinding to nearest enemy, auto-swing on interval, server-side auto-attack loop |
| **Auto-Skill Allocation** | ✅ Complete | P toggle, distributes points to lowest attribute, round-robin balancing |
| **Leveling / XP** | ✅ Complete | XP curve, level-up skill points, leaderstat management, XP gain UI |
| **Skill Points** | ✅ Complete | 4 attributes (Strength/Health/Defense/XP Gain), manual + auto allocation |
| **Rebirth System** | ✅ Complete | Additive stacking, 5 milestones with perks, multiplier scaling, level gate formula |
| **Boss Weapons** | ✅ Complete | 5 tiers (Warlord → Astral Eclipse), rarity system, modifier rolling, appearance, blessed slots |
| **Weapon Modifiers** | ✅ Complete | 4 categories × 4 tiers, rarity→slot count, 3% base Blessed chance |
| **Sword Drops** | ✅ Complete | Boss kill → rarity roll → modifier roll → Tool build, rebirth-scaled drop rates |
| **Auto-Sell** | ✅ Complete | Toggle to auto-sell drops with fewer modifier slots than current sword |
| **Death Shatter** | ✅ Complete | 2% chance to lose equipped boss sword on death |
| **Merchant Shop** | ✅ Complete | 5 boss swords at escalating prices (500–100K gold), no Blessed rolls |
| **Inventory** | ✅ Complete | Stack-based, equip/unequip, sell, snapshot push to client |
| **Data Persistence** | ✅ Complete | DataStore v1 with session locks, autosave, retry logic, memory fallback |
| **Boss Room Gates** | ✅ Complete | PhysicsService collision groups, level-gated doors, eject safety loop |
| **Day/Night Cycle** | ✅ Complete | 4-phase cycle (day/dusk/night/dawn), tweened lighting effects |
| **UI: Main Menu** | ✅ Complete | 5-tab modal (Home/Inventory/Skills/Rebirth/Settings), nav rail, stat display |
| **UI: Merchant** | ✅ Complete | Shop modal with rarity colors, gold validation, buy buttons |
| **UI: Combat HUD** | ✅ Complete | Auto-attack status, floating damage/XP/gold numbers, crit styling |
| **UI: Level Progress** | ✅ Complete | Bottom-left XP bar with animated fill |
| **UI: Loot Toasts** | ✅ Complete | Rarity-colored drop cards, auto-sell toasts, death shatter notifications |
| **UI: Boss Doors** | ✅ Complete | OPEN/LOCKED sign painting, touch warnings, eject notices |
| **Animation System** | ✅ Complete | Custom Motor6D keyframe driver, fade in/out, leg counter-rotation |
| **Sprint** | ✅ Complete | LeftShift = 26 speed vs 16 walk |

### ✅ Combo System (Added 2026-09-14)

| Component | File | Purpose |
|-----------|------|--------|
| ComboConfig | ReplicatedStorage/Config/ComboConfig.luau | Combo constants: endlag, damage mult, hitlag duration, timing |
| SwordSystem | ServerScriptService/SwordSystem.server.luau | Server-side combo tracking, escalating endlag, combo damage multiplier |
| CombatUtil | ServerScriptService/CombatUtil.luau | applyHitlag() — freeze both attacker + victim on hit |
| CombatController | StarterPlayerScripts/CombatController.client.luau | Combo HUD counter, endlag-respecting auto-attack |
| ComboVFX | StarterPlayerScripts/ComboVFX.client.luau | Screen shake scaling with combo count |
| DamageNumbers | StarterPlayerScripts/DamageNumbers.client.luau | Combo multiplier prefix on floating damage text |
| Combo Animation | ReplicatedStorage/Animations/Combo Attack Animation.luau | 5 distinct swing arcs (horizontal, overhead, spin) |

### 🚧 Partially Implemented / Known Issues

| Item | Status | Details |
|------|--------|---------|
| **Merchant duplicates BossSwordFactory** | 🐛 Known Bug | `manual_trace.md` item #1 (OPEN): MerchantSystem carries its own copy of weapon construction logic. BossSwordFactory was extracted but merchant still has inline code. |
| **CombatController pathfinding** | 🚧 Basic | Auto-attack uses `Humanoid:MoveTo()` — functional but no obstacle avoidance or path computation |
| **5-hit combo system** | ✅ Implemented — see ComboConfig.luau | 5-hit M1 combos with escalating endlag, damage multiplier, hitlag integration |
| **Hitlag** | ✅ Implemented — see CombatUtil.applyHitlag() | 20-50ms freeze frames on hit — freezes both attacker and victim |
| **Pity system for drops** | ✅ Implemented — see SwordDropSystem.server.luau | Pity counters track consecutive failed drops per rarity, guaranteed at threshold |

### ❌ Missing Systems (Not Yet Built)

| System | Priority | Research Source |
|--------|----------|----------------|
| **Quest System** | High | No quest giver, quest tracking, or quest rewards exist |
| **Multi-Currency** | Medium | DESIGN_RULES: 3+ activity-specific currencies (only Gold exists) |
| **PvP System** | Medium | sword-rpg-pvp-design.md: ELO ranking, tier floors, PvP zones |
| **Trading System** | Medium | sword-rpg-retention-community.md: player-to-player trading |
| **Procedural Dungeons** | Medium | Research identifies this as #1 unmet player demand |
| **Daily Login / Codes** | Medium | sword-rpg-growth-strategy.md: "Sub2Creator" code system |
| **Minimap / HUD** | Medium | sword-rpg-ui-ux-patterns.md: minimap, health bar, hotbar |
| **Mobile UI** | Medium | 60%+ Roblox players on mobile — no touch optimization |
| **Battle Pass** | Low | sword-rpg-monetization.md: open market opportunity |
| **Tutorial / FTUE** | Low | By design (no forced tutorials) — but onboarding tooltips missing |

---

## Integration Points for Research

### Combat System
- **Research**: `sword-rpg-combat-systems.md` (932 lines) recommends Deepwoken's Posture+Parry+Feint triangle
- **Current Code**: `SwordSystem.server.luau` + `EnemyCombat.server.luau` — basic overlap hitbox, no combo system
- **Gap**: Need 5-hit combo counter with escalating endlag, hitlag (20-50ms freeze), parry/iframe mechanics
- **Integration Point**: `CombatController.client.luau` (combo input), `SwordSystem.server.luau` (damage + hitlag), `AnimationController.luau` (endlag animations)

### Rebirth System
- **Research**: `sword-rpg-rebirth-analysis.md` (554 lines): "Never reset player progress, 80% new content / 20% multiplier"
- **Current Code**: `RebirthSystem.server.luau` + `RebirthConfig.luau` — additive stacking with 5 milestones ✅
- **Well Implemented**: Matches research recommendations. Level resets to 1 but all multipliers stack.
- **Enhancement**: Consider adding Blox Fruits-style V4 Race Awakening (raid bosses + puzzles + fragment investment)

### Progression Curves
- **Research**: `sword-rpg-progression-curves.md` (550 lines): formula `⌈2 × L^2.3 + 84⌉`
- **Current Code**: `LevelingSystem.server.luau` — XP formula embedded in leveling logic
- **Gap**: Verify current formula matches research recommendation; check for dead zones at zone transitions

### Weapon Acquisition / Pity
- **Research**: `sword-rpg-weapon-acquisition.md` (405 lines): "No major RPG has transparent drop rates or pity"
- **Current Code**: `SwordDropSystem.server.luau` — pure RNG with rebirth scaling
- **Gap**: Add pity counter: `drop_rate = base_rate × (1 + rebirth_count × 0.15)`, `pity_threshold = 50 + (rebirth_count × 5)`

### Boss / PvE Design
- **Research**: `sword-rpg-boss-pve-design.md` (500 lines): NPC State Machine, Boss Phase System, aggro tables
- **Current Code**: `EnemyCombat.server.luau` — enemies use simple Humanoid:MoveTo chase, no phase transitions
- **Gap**: Add boss phases (HP thresholds trigger new attack patterns), aggro threat tables for multiplayer PvE

### Anti-Exploit
- **Research**: `sword-rpg-anti-exploit-architecture.md` (2,096 lines): "Never Trust the Client"
- **Current Code**: Server-authoritative combat ✅, DataStore session locks ✅
- **Gap**: Add token bucket rate limiting on RemoteEvents, server-side position validation, shadow banning system

### Economy
- **Research**: `sword-rpg-economy-design.md` (484 lines): multi-currency (3+), activity-specific sinks
- **Current Code**: Single currency (Gold) only
- **Gap**: Add boss tokens (from boss kills), rebirth crystals (from rebirth), exploration fragments (from zone discovery)

### UI/UX
- **Research**: `sword-rpg-ui-ux-patterns.md` (990 lines): mobile-first, health bar + hotbar + minimap
- **Current Code**: Desktop-centric UI, no mobile touch optimization, no minimap
- **Gap**: Add health bar HUD, minimap, hotbar for abilities, mobile touch controls

### Player Retention
- **Research**: `sword-rpg-retention-community.md` (777 lines): daily login, guilds, trading
- **Current Code**: No daily rewards, no social systems
- **Gap**: Daily login streaks, creator code system, trading economy

---

## Next Steps (Prioritized)

### P0 — Core Combat Feel (Blocks Player Satisfaction)
1. **Implement 5-hit combo system** in `SwordSystem.server.luau` + `CombatController.client.luau`
   - Hits 1-2: fast (0.2s endlag), Hits 3-4: medium (0.35s), Hit 5: heavy (0.5s)
   - Per research: "5-hit M1 > 4-hit" for combat feel
2. **Add hitlag (20-50ms freeze)** — per research, this is the #1 "feel good" factor
   - Freeze both attacker and victim briefly on hit
   - `CombatUtil.hasLineOfSight()` already exists; add `CombatUtil.applyHitlag()`
3. **Implement pity system** in `SwordDropSystem.server.luau`
   - Track consecutive failed drops per player per rarity
   - Guaranteed drop at threshold: `50 + (rebirth_count × 5)`

### P1 — Content & Progression (Blocks Retention)
4. **Quest system** — Create `QuestSystem.server.luau` + `QuestGui.client.luau`
   - NPC quest givers in each zone, quest tracking, XP/gold rewards
   - "Kill 5 Bandits" = universal first quest per research
5. **Multi-currency** — Add boss tokens + rebirth crystals
   - Update `SaveConfig.luau` with new currency fields
   - Update `MerchantConfig.luau` to accept different currencies
6. **Boss phase system** — Add HP-threshold phase transitions in `EnemyCombat.server.luau`
   - Phase 1: Basic attacks, Phase 2: AoE at 50% HP, Phase 3: Enrage at 25% HP

### P2 — Social & Growth (Blocks Viral Growth)
7. **Creator code system** — "Sub2CreatorName" permanent codes for free items/currency
8. **Daily login rewards** — 7-day cycle with escalating rewards
9. **Trading system** — Player-to-player sword trading with UI

### P3 — Polish & Mobile (Blocks Reach)
10. **Mobile UI optimization** — Touch controls, thumb-sized buttons, responsive layout
11. **Minimap + HUD** — Health bar, minimap showing zone layout, hotbar
12. **Procedural dungeons** — Per research: "#1 unmet player demand across all games"

### P4 — Anti-Exploit Hardening
13. **Rate limiting** — Token bucket on all RemoteEvents (research: `sword-rpg-anti-exploit-architecture.md`)
14. **Server position validation** — Check player movement speed, teleport detection
15. **Shadow banning** — Suspected cheaters get silently moved to shadow lobbies

---

## Key Formulas

| Formula | Location | Notes |
|---------|----------|-------|
| **Damage (Armed)** | `SwordSystem.server.luau` | `(30 + 5×Strength) × (1 + 0.12×WeaponLevel) × SwordMult × RebirthMult × CritMult` |
| **Damage (Unarmed)** | `EnemyCombat.server.luau` | `(25 + 5×Strength) × (1 + 0.12×WeaponLevel) × RebirthMult × CritMult` |
| **Rebirth Gate** | `RebirthConfig.luau` | `RequiredLevel = 20 + 15 × rebirth_count` |
| **Rebirth Multipliers** | `RebirthConfig.luau` | XP: +35%/rb, Gold: +50%/rb, Damage: +25%/rb, Health: +15%/rb |
| **Drop Rate Scaling** | `RebirthConfig.luau` | `chance = base + (per_rebirth_bonus × rebirths)` per rarity |
| **Modifier Slots** | `WeaponModifiers.luau` | Rarity determines base slots (Common=0, Uncommon=1, ..., Legendary=4) + 3% Blessed chance for +1 |
| **Defense Reduction** | `LevelingSystem.server.luau` | `0.3% per point, max 35%` |
| **XP Gain Bonus** | `LevelingSystem.server.luau` | `0.5% per point, max 35%` |

---

## Architecture Patterns

### Server Authority
Every game state mutation flows through server scripts. Client sends intent via RemoteEvent; server validates, computes, and replicates results back. No RemoteFunctions used.

### Module Separation
- **Config modules** (ReplicatedStorage/Config): Shared constants, read by both server and client
- **Service modules** (ServerScriptService/*.luau): Server-only business logic
- **Controller scripts** (StarterPlayerScripts/*.client.luau): Client-side input handling and UI

### Data Flow
```
Client Input → RemoteEvent → Server Validation → State Mutation → RemoteEvent → Client Feedback
```

### Script Dependency Graph
```
RuntimeBootstrap
  ├── PlayerDataStore → PlayerDataService → SaveConfig
  ├── WorldBuilder → WorldLayout
  ├── LevelingSystem → CombatUtil
  ├── EnemyCombat → CombatUtil, WorldLayout, Sword
  ├── SwordSystem → CombatUtil, Sword
  ├── SwordDropSystem → BossSwordFactory → BossWeapons, WeaponModifiers, CombatUtil
  ├── MerchantSystem → BossSwordFactory, MerchantConfig
  ├── RebirthSystem → RebirthConfig
  ├── InventorySystem → InventoryService → Items
  └── BossRoomGate → WorldLayout, PhysicsService
```
