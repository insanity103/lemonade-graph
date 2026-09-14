# The Legendary Swords RPG - Complete Game Mechanics Analysis

> **Game ID**: 60654525  
> **Full Title**: [FXD] The Legendary Swords RPG  
> **Developer**: Omega_RX (aka Bubbles5610) / @Omega_RX (Roblox User ID: 16332998)  
> **Created**: August 30, 2011  
> **Description**: "An RPG Original Featuring Over 65 unique weapons, can you collect them all?"  
> **Rating**: 81.8/100 (58.3K votes)  
> **Genre**: Action RPG / Sword Collector  
> **Status**: Legacy/Nostalgia game (developer has fond memories; no longer actively updated, but a "Restored" community version exists)  
> **Sequel**: Legendary Swords RPG 2 (Game ID: 413053960, by Bubbles5610)  
> **Restored Version**: The Legendary Swords RPG: Restored (Game ID: 129119196465909, by @Saltels) - adds new areas, bosses, weapons; gamepasses transfer from original  
> **Remastered Version**: The Legendary Swords RPG Remastered (by TerrorBan) - adds 25 more rebirths and new bosses  

---

## 1. COMBAT SYSTEM

### Attack Mechanic
- **Primary Attack**: Single-click melee swing (no documented M1 combo system - this is an early Roblox-era RPG, predating modern combo mechanics)
- **No M1 Combo System**: The game uses simple click-to-swing sword mechanics typical of 2011-era Roblox sword fighting. Each click performs one swing.
- **No Blocking/Dodging**: No documented blocking, parrying, or dodge mechanics. Combat is straightforward click-to-attack.
- **No Ability Slots**: Swords do not have special abilities or skill slots. The game predates ability-based combat systems.
- **Hit Registration**: Server-side hit detection via Roblox's built-in sword tool system. Players swing their equipped sword and damage enemies in melee range.

### Damage Formula
- **Base damage is determined by the equipped sword**. Each sword has a Base Damage range (e.g., The Devil's Blade: 2.50M - 9.00M base damage)
- **Physical Damage stat** adds additional flat damage via the Upgrade Stats system
- **Damage Output** = Sword Base Damage + Physical Damage Stat Bonus
- **PvP Damage** differs from PvE (e.g., The Devil's Blade: 47.0K - 50.0K PvP damage vs. 2.5M-9.0M PvE)

### Combat Flow
1. Player equips a sword from inventory
2. Walk up to an enemy
3. Click to swing sword
4. Enemy takes damage based on sword + stat modifiers
5. Kill enemy to earn XP and Gold
6. Fight bosses for rare sword drops

---

## 2. PROGRESSION SYSTEM

### Level System
- **Level-based progression** with level gates for accessing new areas
- **Max Level**: Not explicitly documented in wiki sources, but the game references level 900+ in rebirth route videos ("Full Rebirth Route Level 1 - 900")
- **In the sequel (LS2)**: Level 1,000 is a badge milestone
- **XP Sources**: Killing enemies (primary source), killing bosses (higher XP), game passes can multiply XP gain
- **Level scaling**: Enemy levels vary by area (e.g., Forest: levels 50-200, Upper Mountain: level 20+ enemies with boss at level 53)

### Level Gates for Areas
| Area | Level Requirement |
|------|------------------|
| Lobby / Spawn | Level 1 |
| Outer Caves | Low level |
| Caves | Low-mid level |
| Upper Mountain | ~Level 20+ |
| Forest | ~Level 50+ |
| Maxos Temple | Level 100 |
| Legendary Mines | Higher levels |
| Deep Mines | Endgame |
| Mysterious Portal / Angelic Temple | Endgame |
| Black Hole | Endgame |
| Floating Fortress | Endgame |
| Legendary Tower | Endgame |

### Upgrade Stats System
Access via Menu > Upgrade Stats. Stats are upgraded using **Upgrade Points** earned through leveling.

| Stat | Description | Limit | Rate |
|------|-------------|-------|------|
| Health | Player durability (HP pool) | Unlimited | — |
| Physical Damage | Additional flat damage per hit | Unlimited | — |
| Defense | Damage reduction | 50% cap | — |
| Gold Gained | Bonus gold from kills | — | +100% per point |

**Known Bug**: Floating point display errors (e.g., shows "44.999..." instead of "45")

---

## 3. SWORD SYSTEM

### Overview
- **65+ unique weapons** (per game description)
- All weapons function as "swords" regardless of name (axes, hammers, scythes are all mechanically swords)
- Swords are the only weapon type in the game
- **No sword upgrades/enhancement system** documented for the original game
- Each sword has fixed base damage stats

### Sword Rarity Tiers

The game uses a tiered rarity system where higher-tier swords drop from higher-tier bosses at increasingly rare rates.

| Rarity | Drop Rate | Rebirth Reduction Variable (y) | Source |
|--------|-----------|-------------------------------|--------|
| **Common** | N/A (purchased) | — | Sword Shop, starter |
| **Uncommon** | N/A (purchased) | — | Sword Shop, Forest Shop |
| **Rare** | 1 in 30 | y = 1.2 | Rare Boss drops |
| **Ultra** | 1 in 40 | y = 1.6 | Ultra Boss drops |
| **Legendary** | 1 in 50 | y = 2.0 | Legendary Boss drops |
| **Omega** | 1 in 55 | y = 2.2 | Omega Boss drops |
| **God** | 1 in 100 | y = 4.0 | God Boss drops |
| **Mythical** | 1 in 150 | — | Endgame bosses (Remastered) |

**Drop Rate Rebirth Formula**: `new_drop_rate = y(rarity) / x(rebirths)` (where y varies by tier). Drop rates improve with more rebirths.

### Common Swords (Shop-Purchased)

**Starter/Default:**
- Bronze Sword

**Main Sword Shop:**
| Sword | Price |
|-------|-------|
| Steel Sword | Gold |
| Iron Sword | Gold |
| Gold Sword | Gold |
| Diamond Sword | Gold |
| Dark Axe | Gold |
| Serpentine Axe | Gold |
| Dragon Axe | Gold |

**Forest Sword Shop:**
- Ice Sword, Bone Sword, Frostbrand
- Scaled Sword, Blizzard Striker, Cleaver Blade
- Morrow Sword, Nefertiti Sword, Mythic Sword
- Winged Sword, Laser Scythe, Overseer Axe

**Sky Sword Shop (Ultra tier, purchased):**
- Bat Scythe, Dark Steel Blade, Spider Slasher
- Dark Katana, Blusteel Sword, Polished Blade

**Arcane Gem Sword Shop (Omega tier, purchased with Arcane Gems):**
- Oblivion, Fire Arcane, Snake Arcane, Crimson Arcane, Vilethorn

### Boss Drop Swords (by Tier)

**Rare (1/30 drop):**
| Sword | Boss Source |
|-------|-------------|
| Bandit Sword | Bandit Leader |
| Slicer | Bandit Overlord |
| Knight Blade | Forest bosses |
| Singularity Scythe | Forest bosses |
| Ancient Blade | Deep Mines |

**Ultra (1/40 drop):**
| Sword | Source Area |
|-------|------------|
| Split Dagger | Outer Caves |
| The Sorcus | Forest |
| Ice Hammer | Forest |
| Fire Blade | Maxos Temple |
| Lava Blade | Maxos Temple |
| Fallen Blade | Legendary Mines |
| Angelic Hammer | Mysterious Portal |
| Element Sword | Legendary Tower |
| Flame Hammer | Legendary Tower |
| Emerald Hammer | Legendary Tower |

**Legendary (1/50 drop):**
| Sword | Notes |
|-------|-------|
| Lightning Blade | Lightning God boss |
| Fire Dagger | — |
| Crimson Blade | Deep Mines boss |
| Phoenix Blade | — |
| Heavenly Blade | Angelic Temple |
| Sword of Darkness | — |
| Chaotic Blade | — |
| Magma Sword | — |
| Emerald Edge | — |
| Chaos Arcane | Chaotic Guardian (server event boss) |

**Dragon's Landing Legendary Boss Drops:**
- Titan's Hammer, Warlord's Wrath, Skull Basher

**Omega (1/55 drop):**
| Sword | Boss Source |
|-------|-------------|
| Volcanic Slicer | Volcanic God (server event) |
| Dragon Blade | Dragon Lord (server event) |
| Omega Slicer | Spectrum (server event) |
| Chaotic Hammer | Chaotic Alien (server event) |
| Omega Blade | Spectrum Destroyer (server event) |
| Space Omega Sword | Alien Leader (server event) |
| Alien Hammer | Angelic Alien (server event) |
| Diamond Edge | Floating Fortress boss |
| Blood Stained Katana | Floating Fortress boss |
| Mystic Arcane | Floating Fortress boss |

**God (1/100 drop):**
| Sword | Boss Source |
|-------|-------------|
| **The Devil's Blade** | **Omega_RX boss** (strongest sword: 2.5M-9.0M damage) |
| Sun Axe | Sun God (server event) |
| Sword of Behemoth | — |
| Void Slicer | — |
| Periastron Mu | — |
| Periastron Beta | — |
| Periastron Gamma | — |
| Periastron Alpha | — |

**Mythical (1/150 drop, Remastered/Restored only):**
- Exo Slasher
- Decay Heart
- Serpent's Coronation

### Notable Sword Details

**The Devil's Blade** (Strongest Sword)
- Tier: God
- Dropped by: Omega_RX (boss behind giant statue in Floating Fortress)
- Base Damage: 2.50M - 9.00M
- PvP Damage: 47.0K - 50.0K
- Drop Chance: 1 in 100
- Not For Sale (boss drop only)
- Sell Price: 50 Gold
- Uses the "Crescendo, The Soul Stealer" Roblox catalog model
- **Note**: While The Devil's Blade has highest max damage, the Vilethorn can out-DPS it due to higher minimum damage

### Sword Acquisition Methods
1. **Shop Purchase**: Common and Uncommon swords from various shops (using Gold)
2. **Arcane Gem Shop**: Omega-tier swords purchasable with Arcane Gems at Floating Fortress
3. **Boss Drops**: Rare through God tier swords from killing bosses (RNG-based)
4. **Server Event Boss Drops**: Omega and God tier swords from timed server events
5. **Sky Sword Shop**: Ultra-tier swords purchased with higher currency

---

## 4. BOSS SYSTEM

### Boss Tiers
Bosses come in multiple rarity tiers matching the sword rarity system:
- **Regular Bosses** (e.g., Camp Leader, Bandit Overlord)
- **Rare Bosses** (1/30 sword drop)
- **Ultra Bosses** (1/40 sword drop)
- **Legendary Bosses** (1/50 sword drop) - e.g., Lightning God
- **Omega Bosses** (1/55 sword drop) - server event bosses
- **God Bosses** (1/100 sword drop) - Omega_RX, Sun God
- **Hidden Bosses** - secret bosses in hidden areas (e.g., Forest God behind bushes)

### Notable Bosses

| Boss | Tier | Location | HP | Drop |
|------|------|----------|-----|------|
| Bandit Overlord | Regular | Upper Mountain | — | Slicer |
| Camp Leader | Rare | Forest | — | — |
| Undead God | Ultra | Forest | — | — |
| Summoner | Ultra | Forest | — | — |
| Forest God (Hidden) | Ultra | Forest (hidden area) | — | — |
| Lightning God | Legendary | Maxos Temple | — | Lightning Blade |
| Temple God | Ultra | Maxos Temple (hidden) | — | — |
| Temple Lord | — | Maxos Temple | — | — |
| Mine Lord (Hidden) | Ultra | Legendary Mines (false rock) | — | Fallen Blade |
| Celestial God | — | Angelic Temple (hidden room) | — | — |
| Omega_RX | God | Floating Fortress | — | The Devil's Blade |

### Server Events (Timed Boss Spawns)
- **Spawn frequency**: Every 30 seconds (a new event triggers)
- **Duration**: Each event boss lasts 4 minutes before despawning
- **Total event bosses**: 9 (1 Legendary, 7 Omega, 1 God)
- **Reward mechanic**: Last player to hit the boss gets the reward
- **Drop chance**: All event bosses have respective tier drop rates

| Event Boss | Tier | Location | HP | Drop |
|-----------|------|----------|-----|------|
| Chaotic Guardian | Legendary | Floating Fortress | 45M | Chaos Arcane |
| Volcanic God | Omega | Maxos Temple (hidden room) | 2.6M | Volcanic Slicer |
| Dragon Lord | Omega | Legendary Tower area | — | Dragon Blade |
| Spectrum | Omega | Forest (near Ghost Trainer) | 3M | Omega Slicer |
| Spectrum Destroyer | Omega | Forest (Undead God room) | — | Omega Blade |
| Alien Leader | Omega | Spawn (top of Sword Shop) | 3.4M | Space Omega Sword |
| Chaotic Alien | Omega | Black Hole (ledge) | — | Chaotic Hammer |
| Angelic Alien | Omega | Angelic Temple (hidden room) | 3.5M | Alien Hammer |
| Sun God | God | Maxos Temple | — | Sun Axe |

---

## 5. WORLD DESIGN

### All Areas (12+ zones)

| # | Area | Type | Notes |
|---|------|------|-------|
| 1 | **Lobby/Spawn** | Hub | Starting area, main sword shop, NPC trainers |
| 2 | **Outer Caves** | Dungeon | Early game area |
| 3 | **Caves** | Dungeon | Early-mid game |
| 4 | **Upper Mountain** | Open area | Bandit enemies (level 20+), Bandit Overlord boss (level 53) |
| 5 | **Forest** | Multi-zone | Levels 50-200, 3+ bosses, hidden Forest God boss |
| 6 | **Maxos Temple** | Dungeon | Requires Level 100, Lightning God, Temple God, server event bosses |
| 7 | **Legendary Mines** | Dungeon | Miner enemies, hidden Mine Lord boss (false rock) |
| 8 | **Deep Mines** | Sub-area | Expert Miners, Ancient Boss, Crimson Overlord, Ancient God |
| 9 | **Mysterious Portal** | Teleport | Gateway to Angelic Temple |
| 10 | **Angelic Temple** | Hidden area | Celestial God boss (hidden room), Angelic Alien server event |
| 11 | **Black Hole** | Hidden area | Chaotic Alien server event boss |
| 12 | **Legendary Tower** | Tower | Endgame, Dragon Lord server event, highest-tier regular bosses |
| 13 | **Floating Fortress** | Endgame | Omega_RX boss, Arcane Gem shop, forge, God-tier content |
| 14 | **Dragon's Landing** | Area | Titan's Hammer, Warlord's Wrath, Skull Basher boss drops |

### Hidden Areas & Secrets
- **Forest God**: Behind bushes near Undead God spawn in Forest
- **Mine Lord**: Through a false rock on the left side of Legendary Mines
- **Temple God**: Hidden in the back right pillar of Maxos Temple
- **Temple Lord**: Hidden bosses in bottom-left and top-right corners
- **Angelic Temple**: Through Mysterious Portal, hidden room with Celestial God
- **Black Hole**: Contains ledge with Chaotic Alien spawn
- **Fake walls**: Multiple areas use walkable walls to hide bosses/content

### World Progression Path
```
Lobby/Spawn → Outer Caves → Caves → Upper Mountain → Forest → Maxos Temple (Lv100) → Legendary Mines → Deep Mines → Mysterious Portal → Angelic Temple → Black Hole → Legendary Tower → Floating Fortress
```

### Additional Locations (Remastered/Restored)
- **Void Pocket** (Remastered)
- **Serpent's Coronation** area (Remastered)
- New bosses and weapons hidden around the map (Restored)

---

## 6. ECONOMY SYSTEM

### Currency Types
1. **Gold** - Primary currency, earned from killing enemies and bosses
2. **Arcane Gems** - Premium in-game currency for the Arcane Gem Sword Shop at Floating Fortress
3. **Skyshards** - Premium currency (in sequel LS2; status in original unclear)

### Earning Methods
- **Killing enemies**: Primary gold income
- **Killing bosses**: Higher gold rewards
- **Upgrade Stats**: Gold Gained stat can increase gold earned by up to +100%
- **Game passes**: Double/Triple EXP & Gold multiplicatively increase earnings

### Spending Sinks
- **Sword Shop purchases**: Common/Uncommon swords cost gold
- **Sky Sword Shop**: Ultra-tier swords
- **Arcane Gem Shop**: Omega-tier swords at Floating Fortress
- **Upgrade Stats**: Upgrade points (earned per level, not a currency sink per se)
- **Wayshrine usage**: Costs gold to use (Fast Pass gamepass removes this cost)

### Trading System
- **No documented trading system** in the original game. This is a solo/collect-focused RPG, not a player-to-player trading game.

---

## 7. MONETIZATION (Game Passes)

### Original Game Gamepasses
Gamepasses are permanent and persist through rebirths.

| Game Pass | Price (R$) | Effect |
|-----------|-----------|--------|
| **Double EXP & Gold** | 275 | Doubles XP and Gold earned |
| **Triple EXP & Gold** | 595 | Triples XP and Gold (stacks with Double for 4x) |
| **Dual Wield** | 399 | Equip 2 swords, strike with both simultaneously = essentially 2x damage |
| **Fast Pass** | 75 | Removes gold cost for wayshrine, +20% walk speed |
| **Legendary Pass** | 299 | +1 stat point & skyshard per level, knockback effect, 2x health regen, +10% walk speed |
| **Double Drop Rate** | 379 | Doubles boss sword drop rates |

### Sequel (LS2) Gamepasses (Reference)
| Game Pass | Price (R$) | Effect |
|-----------|-----------|--------|
| Double EXP & Gold | 275 | 2x XP and Gold |
| Triple EXP & Gold | 595 | 3x XP and Gold |
| Dual Wield | 399 | Wield 2 swords = 2x damage |
| Fast Pass | 75 | Free wayshrine use + 20% walk speed |
| Legendary Pass | 299 | +1 stat/skyshard per level, knockback, 2x regen, +10% speed |
| Double Drop Rate | 379 | 2x boss drop rate |

### Community Assessment of Value (from LS2 wiki)
1. **Best value**: Double EXP & Gold (cheapest, doubles all progress)
2. **Second**: Triple EXP & Gold (stacks to 4x with Double)
3. **Third**: Dual Wield (flat 2x damage for stable price)
4. **Fourth**: Fast Pass (walk speed helps fast farming)
5. **Fifth**: Legendary Pass (many effects but individually minor)
6. **Worst value**: Double Drop Rate ("extremely overpriced for negligible effect")

### Free vs. Paid
- **Free**: Full game is playable without gamepasses. All content accessible through grinding.
- **Paid**: Gamepasses provide convenience multipliers (XP, gold, speed, damage) but do not unlock exclusive content.
- **Private Servers**: Available; in the Restored version, private servers give 10% less gold and XP.

---

## 8. REBIRTH SYSTEM

### Core Rebirth Mechanic
Rebirthing is the **central endgame loop** of Legendary Swords RPG.

- **What it is**: A prestige/prestige-like system where you reset your progress for permanent benefits
- **Core gameplay loop**: "Players fighting enemies to level up and get better weapons, then rebirthing to get more rebirths even faster"
- **Rebirth count persists** across resets (the primary long-term progression metric)

### What Resets on Rebirth
- Player level (back to Level 1)
- Presumably: Upgrade stat points
- Access to high-level areas temporarily lost until re-leveled

### What Persists Through Rebirth
- Rebirth count (incremented by 1)
- Swords/inventory (presumably)
- Game passes (confirmed permanent)
- Collected boss drop swords

### Rebirth Benefits
1. **Improved drop rates**: Boss sword drop rates decrease (improve) based on rebirth count
   - Formula: `new_drop_chance = y(rarity) / x(rebirths) * 3.333`
   - Each rarity has a different y value (Rare: 1.2, Ultra: 1.6, Legendary: 2.0, Omega: 2.2, God: 4.0)
   - In LS2: At rebirth 25+, all drop rates become 1/5
2. **Faster leveling**: Higher rebirths allow faster progression through content
3. **Additional skyshards**: In LS2, rebirthing grants skyshards

### Rebirth Route
- Video documentation shows a full rebirth route from Level 1 to Level 900
- The Remastered version added 25 additional rebirths beyond the original cap

---

## 9. ADDITIONAL SYSTEMS

### Gem System
- Referenced in community discussions ("somebody please make a gem guide")
- **Arcane Gems**: Used to purchase Omega-tier swords at the Floating Fortress Arcane Gem Shop
- Gem earning method not well-documented on wiki

### Dual Wield System
- Available via gamepass (399 R$)
- Allows equipping two swords simultaneously
- Both swords strike at the same time
- Even if only one hits, deals 2x damage
- Effectively a flat damage multiplier

### PvP
- Swords have separate PvP damage values (e.g., Devil's Blade: 47K-50K PvP vs 2.5M-9M PvE)
- PvP mechanics not extensively documented
- Likely simple melee hits between players

### NPC Trainers
- Ghost Trainer referenced in Forest area
- Various NPCs in hub/spawn area
- Function not well-documented

### Forging System
- Forge referenced at Floating Fortress (opposite side from Chaotic Guardian spawn)
- Specific forging mechanics not documented on wiki

---

## 10. RELATED GAMES & VERSIONS

| Version | Game ID | Developer | Status |
|---------|---------|-----------|--------|
| **The Legendary Swords RPG** (Original) | 60654525 | Omega_RX | Legacy (still playable, nostalgic) |
| **The Legendary Swords RPG 2** (LS2) | 413053960 | Bubbles5610 (Omega_RX) | Open Beta (sequel with expanded systems) |
| **The Legendary Swords RPG Remastered** | — | TerrorBan | Community remaster, +25 rebirths, new bosses |
| **The Legendary Swords RPG: Restored** | 129119196465909 | Saltels | Community restoration with new content, gamepasses transfer |

### Sequel (LS2) New Systems (Reference)
- **Ores & Armor**: New equipment system beyond just swords
- **Enchantments & Upgrades**: Sword enhancement system
- **Guilds**: Social/group system
- **Events**: Timed in-game events
- **6 Areas**: Overworld, Mines, Temple, Devil's Fortress, Legendary Boss Tower, Ice Realm
- **5 Sword Rarities**: Common, Uncommon, Rare, Ultra, Legendary (Omega has unknown drop rate)

---

## 11. DESIGN PATTERNS & ANALYSIS

### Core Loop
```
Kill Enemies → Earn XP/Gold → Level Up → Access New Areas → 
Fight Stronger Enemies → Get Better Swords → Fight Bosses → 
Collect Rare Swords → Reach Max Level → REBIRTH → Repeat Faster
```

### Key Design Observations

1. **Collection-driven motivation**: The 65+ sword collection goal creates long-term engagement
2. **RNG-based boss drops**: Creates excitement and repeated boss farming
3. **Rebirth as infinite progression**: No true "max level" - rebirth count is the real leaderboard
4. **Server events create social moments**: 9 timed bosses that require awareness and speed
5. **Hidden content rewards exploration**: Fake walls, hidden rooms, bushes conceal bosses
6. **Last-hit-takes-all**: Server event boss rewards go to the last player who hit the boss, creating competitive PvE
7. **Area progression via levels**: Simple level-gate system keeps players on an intended path
8. **Legacy game design**: Pre-2015 Roblox simplicity - no complex UI, no ability trees, pure grinding loop
9. **Community preservation**: Multiple community versions (Remastered, Restored) show strong nostalgic attachment

### Monetization Assessment
- Non-exploitative for its era: gamepasses provide convenience, not exclusive content
- Dual Wield (399 R$) is essentially mandatory for efficient play (2x damage)
- Triple + Double XP stacking (595 + 275 = 870 R$) provides 4x progression speed
- No documented developer products or microtransaction currencies beyond game passes

---

## SOURCES

| Source | URL |
|--------|-----|
| Roblox Game Page | https://www.roblox.com/games/60654525/The-Legendary-Swords-RPG |
| Roblox Restored Version | https://www.roblox.com/games/129119196465909/The-Legendary-Swords-RPG-Restored |
| Original Wiki (Fandom) | https://legendary-swords-rpg.fandom.com/wiki/Legendary_Swords_RPG_Wikia |
| Original Wiki - Server Events | https://legendary-swords-rpg.fandom.com/wiki/Server_Events |
| Original Wiki - Level Areas | https://legendary-swords-rpg.fandom.com/wiki/Level_Areas |
| Original Wiki - Boss Item Chances | https://legendary-swords-rpg.fandom.com/wiki/Boss_item_chances |
| Original Wiki - Areas | https://legendary-swords-rpg.fandom.com/wiki/Areas |
| Original Wiki - Upgrade Stats | https://legendary-swords-rpg.fandom.com/wiki/Upgrade_Stats |
| Original Wiki - The Devil's Blade | https://legendary-swords-rpg.fandom.com/wiki/The_Devil%27s_Blade |
| Original Wiki - All Pages | https://legendary-swords-rpg.fandom.com/wiki/Special:AllPages |
| Remastered Wiki (Fandom) | https://the-legendary-swords-rpg-remastered-new.fandom.com/wiki/The_Legendary_Swords_RPG_Remastered_Wiki |
| Remastered Wiki - Swords | https://the-legendary-swords-rpg-remastered-new.fandom.com/wiki/Swords |
| Sequel Wiki (Fandom) | https://legendary-swords-rpg-2.fandom.com/wiki/Legendary_Swords_Rpg_2_Wiki |
| Sequel Wiki - Swords | https://legendary-swords-rpg-2.fandom.com/wiki/Swords |
| Sequel Wiki - Badges & Gamepasses | https://legendary-swords-rpg-2.fandom.com/wiki/Badges_%26_Gamepasses |
| Reddit Discussion | https://www.reddit.com/r/roblox/comments/6zxphs/the_legendary_swords_rpg/ |
| ScriptBlox (game analysis via exploit scripts) | https://scriptblox.com/script/The-Legendary-Swords-RPG-Unlimited-gold-3351 |
| YouTube - Full Rebirth Route | https://www.youtube.com/watch?v=KZl65QKo570 |
| YouTube - All Swords Locations (Restored) | https://www.youtube.com/watch?v=3zY3HWj0UII |
| YouTube - Restored Version Review | https://www.youtube.com/watch?v=heVJOsIxeCE |
| YouTube - Hastur Boss Guide | https://www.youtube.com/watch?v=AepTPU4RGao |
| YouTube - Boss Swords Guide | https://www.youtube.com/watch?v=QIdT9c1aaco |
| YouTube - Restored Version Playthrough | https://www.youtube.com/watch?v=e8pZIv5rwUo |
| Roblox Developer Profile | https://www.roblox.com/users/16332998/profile |

---

*Document compiled from wiki data, game pages, community discussions, and video documentation. Some mechanics (exact max level, exact gold costs for shop items, specific XP tables) are not documented in available sources and would require in-game verification.*
