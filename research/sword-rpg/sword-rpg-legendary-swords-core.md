# The Legendary Swords RPG - Complete Game Reference

> **Last Updated**: 2026-07-09
> **Research Sources**: Roblox game page, Fandom wikis (original, remastered, restored), DuckDuckGo search results

---

## 1. Game Overview

| Field | Value |
|-------|-------|
| **Full Title** | [FXD] The Legendary Swords RPG |
| **Game ID** | 60654525 |
| **Roblox URL** | https://www.roblox.com/games/60654525/The-Legendary-Swords-RPG |
| **Creator** | Omega\_RX (Roblox User ID: 16332998) |
| **Created** | August 30, 2011 |
| **Genre** | RPG / Sword Fighting / Action |
| **Current Status** | Original game offline/low activity; "Restored" fan project active (Game ID: 129119196465909) |
| **Description** | "An RPG Original Featuring Over 65 unique weapons, can you collect them all? I have fond memories of making this game. Thank you to everyone who still plays for the Nostalgia." |

### Version History / Variants

| Version | Developer | Notes |
|---------|-----------|-------|
| **Original** (Game ID: 60654525) | Omega\_RX | Created Aug 2011. The classic version. Currently has low/no active servers. |
| **Remastered** | Terrorban | A remaster adding 25 more rebirths and new bosses. Has its own Fandom wiki. |
| **Restored** (Game ID: 129119196465909) | Saltels | Fanmade restoration based on decompile of Terrorban's remaster. Most actively maintained. Hit 1 Million+ visits as of June 2026. |
| **Legendary Swords RPG 2** | Bubbles5610 | A sequel game with its own wiki. In Open Beta. |

---

## 2. Core Gameplay Loop

The gameplay loop is simple and addictive, characteristic of early Roblox RPGs:

1. **Spawn** in the Lobby area with a basic Bronze Sword
2. **Fight enemies** by clicking to swing your sword - enemies drop XP and Gold
3. **Level up** to increase your stats (damage, health)
4. **Earn Gold** to buy better swords from shops
5. **Defeat Bosses** for rare sword drops (RNG-based)
6. **Progress through Areas** by meeting level/rebirth requirements
7. **Rebirth** (prestige) to reset progress but gain permanent multipliers
8. **Collect all 65+ weapons** across all rarities
9. **Repeat** the cycle at higher rebirth levels with faster progression

### Key Loop Characteristics
- **Grind-centric**: Core loop is kill enemies -> level up -> buy/find better sword -> kill harder enemies
- **Collection-driven**: Primary long-term motivation is collecting all swords
- **Rebirth-driven**: Rebirthing is the prestige loop that keeps players coming back
- **Social/cooperative**: Players can team up to fight bosses; last hit gets the drop
- **RNG excitement**: Boss weapon drops are chance-based, creating a gambling-like thrill

---

## 3. Combat System

### How Combat Works
- **Click-based melee**: Players click (or hold click) to swing their equipped sword
- **Hit detection**: Sword has a hitbox; enemies in range take damage on swing
- **Single weapon equip**: One sword equipped at a time (Dual Weaponry gamepass doubles this)
- **No combo system**: Pure click-spam; no complex combo chains or abilities
- **No blocking/dodging**: Combat is purely offensive - hit enemies before they hit you
- **Damage scales with weapon + level**: Higher-tier swords deal more damage; leveling increases base stats

### Combat Feel
- Very simple, arcade-style combat
- No skill trees, no abilities, no magic (swords only)
- Boss fights are essentially "everyone click the boss until it dies"
- Last player to hit a boss gets the drop reward (competitive element)

---

## 4. Progression System

### Leveling
- Players gain **XP** by killing enemies
- Leveling up increases stats (damage output, health)
- Different enemies in different areas give different XP amounts
- Higher-level areas have enemies that give more XP but are harder to kill

### Rebirth (Prestige) System
The rebirth system is the game's prestige mechanic:

| Rebirth Level | Unlocks / Benefits |
|---------------|--------------------|
| Rebirth 1 | Access to Assassin's Hideout |
| Rebirth 2+ | Access to Verdant Den and subsequent areas |
| Rebirth 4 | Access to Rebirth 4 Portal area |
| Rebirth 5+ | Dungeon, Floating Fortress |
| Rebirth 9 | Sand Dunes area (added June 2026) |
| Rebirth 12+ | Void Pocket, Metal Facility, Templar Valley, Basement |
| Rebirth 16 | Dragon's Landing area |
| Rebirth 20 | Azure Kingdom, Deeper Well, Gehenna; Required for Dagon boss |
| Rebirth 22 | Gehenna area (added June 2026) |
| Rebirth 25+ | Maximum; all drop chances improved significantly (e.g., 26/250 for Dagon drops) |

**Rebirth effects:**
- Resets level and progress back to start
- Grants permanent multipliers to XP and Gold earned
- Improves boss drop rates (formula: `1/original_drop_chance - rebirth_level`)
- At Rebirth 25+, all drops become guaranteed (100% chance)
- Unlocks access to higher-tier rebirth-exclusive areas

### Drop Rate System
Drop chances decrease (improve) with rebirth level:
```
Effective drop chance = 1 / (original_drop_chance - rebirth_level)
```
At Rebirth 25+, drop rates are effectively 100%.

---

## 5. Weapon / Sword System

### Weapon Acquisition Methods
1. **Shop Purchase** - Buy with Gold from various shop NPCs
2. **Boss Drops** - Kill bosses for RNG weapon drops
3. **Hidden/Ultra Swords** - Found in secret locations throughout the map
4. **Gem Crafting** - Craft certain Omega-tier weapons using Arcane Gems
5. **Server Events** - Special timed bosses that spawn across the server

### Complete Weapon Rarity Tiers

| Rarity | Drop Rate (Base) | Acquisition | Count (approx.) |
|--------|-----------------|-------------|-----------------|
| **Common** | N/A (purchased) | Starter + Sword Shop | ~10 |
| **Uncommon** | N/A (purchased) | Sword Shop + Forest Shop | ~12 |
| **Rare** | 1 in 30 | Boss drops | ~6 |
| **Ultra** | 1 in 40 | Boss drops + Hidden locations + Mysterious Portal Shop | ~15 |
| **Legendary** | 1 in 50 | Boss drops + Dragon's Landing | ~14 |
| **Omega** | 1 in 55 | Server events + Floating Fortress + Gem Crafting | ~15 |
| **God** | 1 in 100 | Boss drops (most are static bosses) | ~11 |
| **Mythical** | 1 in 150 | Late-game boss drops | ~15+ |
| **Eternal** | Very rare | End-game server event bosses | 2+ (Dagon's Lament, etc.) |
| **Event** | Special | Limited-time events | Varies |
| **scary** | Special | Secret category | Varies |

### Notable Weapons

| Weapon | Rarity | Notes |
|--------|--------|-------|
| Bronze Sword | Common (Starter) | Default weapon everyone begins with |
| The Devil's Blade | God | Described as "currently the strongest sword" in original wiki |
| Dagon's Lament | Eternal | Strongest obtainable sword in Restored version (1/250 drop from Dagon boss) |
| Periastron series (Mu, Beta, Gamma, Alpha) | God | Nod to classic Roblox Periastron gear series |
| The Sorcus | Ultra | Hidden in Forest - through a bush behind the tent |
| Polished Blade | Ultra | Most expensive Mysterious Portal shop sword (~1.675M Gold) |

### Complete Sword Lists by Source

#### Common Weapons (Shop-Purchasable with Gold)
- Bronze Sword (starter)
- Steel Sword, Iron Sword, Gold Sword, Diamond Sword
- Dark Axe, Serpentine Axe, Dragon Axe

#### Uncommon Weapons (Forest Shop)
- Ice Sword, Bone Sword, Frostbrand
- Scaled Sword, Blizzard Striker, Cleaver Blade
- Morrow Sword, Nefertiti Sword, Mythic Sword
- Winged Sword, Laser Scythe, Overseer Axe

#### Rare Weapons (Boss Drops - 1/30)
- Bandit Sword, Slicer, Knight Blade, Singularity Scythe, Ancient Blade, Annoyingly Purple Blade

#### Ultra Weapons (Boss Drops - 1/40 + Hidden + Shop)
- **Hidden/Ultra swords found in secret map locations:**
  - The Sorcus (Forest - bush behind tent)
  - Ice Hammer (Forest - through bush or hatch atop shrine)
  - Fire Blade (Maxos Temple - left bottom corner through pillar)
  - Lava Blade (Maxos Temple - top right through pillar)
  - Fallen Blade (Legendary Mines - through cracked wall)
  - Split Dagger (Outer Caves)
  - Angelic Hammer (Mysterious Portal)
  - Element Sword, Flame Hammer, Emerald Hammer (Legendary Tower)
- **Mysterious Portal Shop (Gold):**
  - Bat Scythe (455,000G), Dark Steel Blade (665,000G), Spider Slasher (875,000G)
  - Dark Katana (1,025,000G), Bluesteel Sword (1,215,000G), Polished Blade (1,675,000G)

#### Legendary Weapons (Boss Drops - 1/50)
- Lightning Blade, Fire Dagger, Crimson Blade, Phoenix Blade
- Heavenly Blade, Sword of Darkness, Grass Legend
- Chaotic Blade, Magma Sword, Emerald Edge, Chaos Arcane, Sand Cutlass
- **Dragon's Landing drops:** Titan's Hammer, Warlord's Wrath, Skull Basher

#### Omega Weapons (Server Events + Crafting - 1/55)
- **Server event drops:** Volcanic Slicer, Dragon Blade, Omega Slicer, Chaotic Hammer
- **Floating Fortress drops:** Diamond Edge, Blood Stained Katana, Mystic Arcane, Cobalt Saber
- **Gem Crafting:** Oblivion, Fire Arcane, Snake Arcane, Crimson Arcane, Vilethorn
- Space Omega, Alien Hammer

#### God Weapons (Boss Drops - 1/100)
- Sun Axe, Sword of the Behemoth, Void Slicer, The Devil's Blade
- Periastron Mu, Periastron Beta, Periastron Gamma, Periastron Alpha
- Searing Edge, Lost Desert Scimitar, Silencer

#### Mythical Weapons (Boss Drops - 1/150)
- Exo Slasher, Decayheart, Serpent's Coronation
- Azure Flame Staff, Sparkling Arachnid, Reaver Fang
- Temple Claymore, Ancient Hammer, Divine Glory, Osiris' Judgement
- Slate War Axe, Slate Serpent

#### Eternal Weapons
- Dagon's Lament (from Dagon server event boss, 1/250 drop)

---

## 6. Boss Fights

### Boss Title System
Bosses in the game use a title/tier system with 8 titles:
1. Common
2. Uncommon
3. **Legendary** - Lightning God, Ancient Overlord, Ancient God, Sky God, Celestial God, Dark Overlord, Overgrown Beast, Chaotic God, Magma God, Hammerfall, Emerald Skygod, Emerald Warlord, Chaotic Guardian, Dragon Tamer
4. Ultra
5. Omega
6. God
7. Mythical
8. Eternal

### Boss List by Area (Restored Version)

#### Outer Caves
| Boss | Type | Notable Drop |
|------|------|-------------|
| Bandit Leader | Area Boss | Bandit Sword (Rare) |

#### Upper Mountain
| Boss | Type | Notable Drop |
|------|------|-------------|
| Bandit Overlord | Area Boss | Slicer (Rare) |
| Watcher | Area Boss | - |

#### Forest
| Boss | Type | Notable Drop |
|------|------|-------------|
| Summoner | Area Boss | Knight Blade (Rare) |
| Forest God | Area Boss | - |
| Undead God | Area Boss | Singularity Scythe (Rare) |
| Spectrum | Server Event | Omega weapons |
| Spectrum Destroyer | Server Event | Omega weapons |

#### Maxos Temple
| Boss | Type | Notable Drop |
|------|------|-------------|
| Temple Lord | Area Boss | Lightning Blade (Legendary) |
| Temple God | Area Boss | - |
| Lightning God | Area Boss (Legendary tier) | Legendary drops |
| Star Destroyer | Server Event | - |
| Volcanic God | Server Event | Volcanic Slicer (Omega) |

#### Legendary Mines
| Boss | Type | Notable Drop |
|------|------|-------------|
| MineLord | Area Boss | - |
| Ancient Lord | - | - |
| Ancient God | Legendary tier | - |
| Ancient Overlord | Legendary tier | - |

#### Mysterious Portal / Black Hole
| Boss | Type | Notable Drop |
|------|------|-------------|
| Sky God | Legendary tier | - |
| Dark Overlord | Legendary tier | - |
| Angelic Alien | Server Event | - |

#### Legendary Tower
| Boss | Type | Notable Drop |
|------|------|-------------|
| Celestial God | Legendary tier | - |
| Chaotic God | Legendary tier | - |
| Chaotic Alien | Server Event | - |

#### Floating Fortress
| Boss | Type | Notable Drop |
|------|------|-------------|
| Bubbles5610 | Boss | - |
| Chaotic Guardian | Server Event / Legendary tier | - |
| Dragon Lord | Server Event | Dragon Blade (Omega) |

#### Dragon's Landing
| Boss | Type | Notable Drop |
|------|------|-------------|
| Emerald Warlord | Legendary tier | - |
| HammerFall | Legendary tier | - |
| Dragon Tamer | Legendary tier | - |
| OUROBOROS | - | - |

#### Azure Kingdom
| Boss | Type | Notable Drop |
|------|------|-------------|
| Azurewrath, Voidwalker | Mythical tier | Mythical weapons |
| Voidspeaker | - | - |
| Spider Queen | - | - |
| Hastur | Server Event | - |

#### Gehenna (Added June 2026)
| Boss | Type | Notable Drop |
|------|------|-------------|
| Sand Dunes bosses (5 new) | Area Bosses | - |
| Gehenna bosses (5 new) | Area Bosses | - |

#### Dagon (Server Event Boss)
| Stat | Value |
|------|-------|
| Level | 1,525,000 |
| Health | 55.3 Billion |
| Rarity | ETERNAL |
| Gold Drop | 234 Million |
| XP Drop | 333,333 |
| Weapon Drop | Dagon's Lament (1/250, guaranteed at R25) |
| Event Duration | 8 minutes |
| Location | Rebirth 20 / Slate Forest (hidden cave) |
| Requirements | Rebirth 20 + Level 880 |

**How to find Dagon:**
1. Go to Legendary Mines 175+
2. Find hidden wall #1 near MineLord boss
3. Enter hidden wall #2 on boss's left
4. Click the pickaxe on the rock (only visible during Dagon event)
5. Go to Rebirth 20 area, find cave entrance in Slate Forest
6. Enter tunnel to find Dagon surrounded by deadly pits

---

## 7. Map / World Design

### Areas Overview

The game world consists of interconnected areas, with progression gated by level and rebirth requirements.

#### Base Areas (No Rebirth Required)

| Area | Theme | Enemies |
|------|-------|---------|
| **Lobby** | Starter area | Dummy, Alien Leader |
| **Outer Caves** | Cave/underground | Bandits (regular, strong, guard), Bandit Leader boss |
| **Upper Mountain** | Mountain/rocky | Bandit Soldiers, Paladins, Defenders, Bandit Overlord boss |
| **Forest** | Woodland | Camp Soldiers, Ghostly Undead, Summoner boss, Forest/Undead Gods, Spectrum |
| **Maxos Temple** | Ancient temple | Temple Guardians, Trainers, Paladins, Defenders, Temple Lord/God, Lightning God |
| **Legendary Mines** | Underground mines | Miners, Strong/Expert Miners, MineLord boss, Ancient Lord/God/Overlord |
| **Mysterious Portal** | Angelic/sky | Angelic Defenders, Guardians, Lords, Sky God, Dark Overlord, Celestial God |
| **Black Hole** | Chaotic/void | Chaotic God, Chaotic Alien, Water God, Flame/Earth Overlords, Magma God |
| **Legendary Tower** | Tower ascent | Various tower enemies |

#### Rebirth-Gated Areas (Early Game)

| Area | Rebirth Req | Theme | Notable Enemies |
|------|-------------|-------|-----------------|
| **Assassin's Hideout** | Rebirth 1 | Shadowy hideout | Bandit Assassins, Bandit Executioner |
| **Verdant Den** | Rebirth 2 | Green/grassy | Grass Titan, XP Spirit, Gold Spirit, Overgrown Beast |
| **Rebirth 4 Portal** | Rebirth 4 | Portal area | Emerald Skygod, Emerald Warlord |
| **Dungeon** | Rebirth 5 | Underground prison | Dungeon Dwellers, Guardians, Prisoners, Disgraced Deity |
| **Floating Fortress** | Rebirth 5 | Sky fortress | Wrath, Surge, Juggernaut, Bubbles5610, Chaotic Guardian |

#### Rebirth-Gated Areas (Mid Game)

| Area | Rebirth Req | Theme | Notable Enemies |
|------|-------------|-------|-----------------|
| **Void Pocket** | Rebirth 12 | Void/dark | Omega Darkness, Alpha Darkness |
| **Sand Dunes** | Rebirth 9 | Desert (new June 2026) | Sand Monster, Desert Monster, Granite Warrior, Gra-Knight, Desert God, Death God, Desert Tyrant |
| **Metal Facility** | Rebirth 12 | Sci-fi facility | Abandoned Droid, Guard Droid, Ares, Elite Droids, Apollo, Artemis, Thanatos |
| **Templar Valley** | Rebirth 12 | Templar/cathedral | Mechanical God |
| **Basement** | Rebirth 12 | Dark basement | OUROBOROS |

#### Rebirth-Gated Areas (Late Game)

| Area | Rebirth Req | Theme | Notable Enemies |
|------|-------------|-------|-----------------|
| **Dragon's Landing** | Rebirth 16 | Dragon-themed | Dragon Servants, Keepers, Emerald Warlord, HammerFall, Dragon Tamer |
| **Rebirth 16 Portal** | Rebirth 16 | Portal | Reluctant Guard, Annoying Prince, Azure Apprentice, Dark Caster |
| **Azure Kingdom** | Rebirth 20 | Azure/magical | Lil' Spitter, Spider Queen, Voidspeaker, Azurewrath Voidwalker, Hastur |
| **Deeper Well** | Rebirth 20 | Deep underground | Deep well enemies |
| **Gehenna** | Rebirth 22 | Hell/demonic (new June 2026) | Gehenna enemies |

### Area Design Philosophy
- Each area has a distinct visual theme (forest, cave, temple, sky, void, etc.)
- Areas are physically connected in the world (not instanced dungeons)
- Hidden paths and secret locations are a core exploration mechanic (e.g., Ultra Swords hidden behind bushes, through pillars)
- Boss areas are often in remote/hard-to-reach parts of the map
- The "Slate Forest" area for Dagon requires finding hidden walls in Legendary Mines

---

## 8. Economy

### Currency: Gold
- **Primary currency** earned by killing enemies
- Used to purchase swords from shops
- Shop swords range from hundreds of Gold (early) to 1,675,000+ Gold (late Ultra tier)
- Gold earning rate increases with:
  - Higher-level enemies
  - Rebirth multipliers
  - Double XP and Gold gamepass
  - Legendary Pack gamepass (200% Gold gain)

### Economy Characteristics
- **Simple single-currency system** (Gold only, no secondary currencies mentioned for original)
- **No player trading** in the original game
- **No marketplace/auction house**
- Gold sinks are purely NPC shops
- Economy is entirely PvE-driven

---

## 9. Game Passes & Monetization

### Game Passes (Restored Version)

| Game Pass | Price | Effect |
|-----------|-------|--------|
| **Double XP and Gold** | 175 Robux | Doubles all XP and Gold earned |
| **Dual Weaponry** | 200 Robux | Doubles damage output (dual-wield swords) |
| **25% Drop Rate Increase** | 100 Robux | Flat +25% to all boss drop rates (works at 0 rebirths) |
| **Legendary Pack + Devil Armour** | 150 Robux | Pet dragon (+150% life regen), 200% Gold gain, max walkspeed |
| **Teleportation** | 200 Robux | Reality Dislocator tool to teleport to unlocked areas |

**Total cost for all passes: 825 Robux**

### Monetization Philosophy
- Relatively fair monetization - all passes are convenience/power boosts
- No paywall-exclusive content (all swords are obtainable through gameplay)
- Game passes speed up progression rather than gate it
- "Legendary Pack" was merged from two separate passes because "they didn't do very much on their own" - shows developer awareness of value

---

## 10. Player Count & Popularity

### Current State
- **Original Game (ID: 60654525)**: No active servers as of research date. The Roblox page shows "There are currently no running experiences."
- **Restored Version (ID: 129119196465909)**: Active with 1 Million+ visits (acknowledged in June 2026 update log)
- **Wiki Activity**: Multiple active Fandom wikis with regular edits, suggesting dedicated community

### Historical Context
- Created in August 2011, making it one of the earliest Roblox RPGs
- The game predates many modern Roblox RPG conventions
- Referenced as a nostalgic classic by players ("i just got back into the game for nostalgia" - wiki comment from April 2024)
- Listed on the Roblox Wiki's notable game communities

---

## 11. Community Sentiment

### What Players Love
- **Nostalgia factor**: Strong nostalgic appeal for long-time Roblox players
- **Simplicity**: Easy to understand gameplay loop - no complex tutorials needed
- **Collection satisfaction**: Over 65+ weapons across 10 rarity tiers creates strong collector motivation
- **Secret hunting**: Hidden Ultra Swords and secret areas reward exploration
- **Server event excitement**: Timed boss events create communal excitement
- **Rebirth system**: The prestige loop keeps progression feeling rewarding
- **Nostalgic developer**: Omega\_RX's personal note about "fond memories" resonates with players

### What Players Dislike / Pain Points
- **Dual Wield bug**: Wiki discussion (April 2024) notes "Anyone know why dual wield isn't working?"
- **Lack of guides**: Wiki request "Somebody please make a gem guide here thanks" - indicates missing documentation
- **Simple combat**: Click-based combat lacks depth for modern players
- **RNG frustration**: 1/150+ drop rates for Mythical weapons can be demoralizing
- **Rebirth grind**: Having to replay early content after each rebirth
- **Low player count in original**: Original game has no active servers

### Community Characteristics
- Dedicated wiki editors maintaining documentation across multiple Fandom wikis
- Restoration/modding community (Saltels creating "Restored" version from decompiled code)
- Active Discord server for the Restored version
- The game has spawned a sequel (LSRPG 2) and multiple fan projects

---

## 12. What Makes This Game Unique vs. Modern Sword RPGs

| Aspect | Legendary Swords RPG | Modern Roblox Sword RPGs |
|--------|---------------------|-------------------------|
| **Era** | 2011 - one of the earliest | 2020s - mature ecosystem |
| **Combat** | Pure click-to-swing, no abilities | Combo systems, skills, dodging, blocking |
| **Weapons** | 65+ swords, visual variety only | Weapons with unique abilities, stats, scaling |
| **Progression** | Level + Rebirth only | Skill trees, classes, gear sets, enchantments |
| **World** | Single persistent world | Instanced dungeons, procedural generation |
| **Bosses** | Simple HP sponges, click to kill | Mechanic-heavy, phases, patterns |
| **Economy** | Gold-only, NPC shops | Trading, auction houses, multiple currencies |
| **Monetization** | 5 simple game passes | Battle passes, gacha, premium currencies |
| **Aesthetic** | Classic Roblox blocky style | Anime-inspired, custom meshes, VFX |
| **Social** | Organic co-op boss fights | Guilds, parties, matchmaking |

### Unique Strengths of LSRPG
1. **Simplicity as virtue**: No barrier to entry, immediate fun
2. **Exploration rewards**: Hidden swords in secret map locations
3. **Shared world boss events**: Server-wide events create communal moments
4. **Clear rarity hierarchy**: 10-tier rarity system is easy to understand and motivating
5. **Rebirth done right**: Rebirthing feels rewarding because drop rates literally improve
6. **Nostalgic identity**: The game has a clear, distinctive character that modern generic RPGs lack

---

## 13. Mechanics to Preserve in a Modern Remake

### Must-Preserve Core Mechanics
1. **Weapon collection loop** - 65+ weapons across distinct rarity tiers is the game's identity
2. **Rebirth with drop rate improvement** - The formula `1/(base_chance - rebirth)` is elegant
3. **Hidden/secret weapons** - Ultra Swords hidden behind environmental puzzles
4. **Server event bosses** - Timed, server-wide events with rare drops
5. **Area progression** - New areas unlocked via rebirth levels
6. **Gold economy** - Simple, understandable, no confusing currencies
7. **"Last hit gets the drop"** boss mechanic - Creates exciting competitive moments
8. **Boss title/tier system** - Creates visual hierarchy and prestige

### Signature Elements
- The title "Legendary" for bosses (not just a sword rarity - it's a boss classification)
- Periastron swords as God-tier (homage to classic Roblox gear)
- Hidden paths behind bushes, through walls, and atop shrines
- The escalating rarity names: Common -> Ultra -> Legendary -> Omega -> God -> Mythical -> Eternal

---

## 14. What Needs Improvement for Modern Audience

### Critical Improvements
1. **Combat depth**: Add combo system, special abilities, blocking, dodging, or skill rotations
2. **Visual modernization**: Upgrade from classic Roblox blocks to modern mesh/VFX standards
3. **Quality of life**: Auto-collect drops, damage numbers, HP bars on enemies, minimap
4. **Anti-grind measures**: Make rebirthing less tedious (keep some progress, faster early game)
5. **Boss mechanics**: Add attack patterns, phases, telegraphed attacks instead of HP sponges
6. **Social features**: Party system, guilds, trading between players
7. **Tutorial/guidance**: Better onboarding for new players
8. **Leaderboards**: Track and display collection completion, rebirth level, etc.
9. **Pity system**: Bad luck protection for rare drops (don't let players go 100+ kills without a 1/50 drop)
10. **Content variety**: Add non-combat activities (trading, crafting, achievements, quests)

### Secondary Improvements
- **Weapon abilities**: Give rare swords unique passive/active effects
- **Loadout system**: Allow quick weapon swapping for different situations
- **Seasonal content**: Regular updates with new areas, bosses, limited weapons
- **Sound design**: Iconic sword swing sounds, boss music, ambient world audio
- **Mobile optimization**: Ensure smooth play on mobile devices
- **Data persistence**: Robust save system (original had data loss issues)
- **Private server improvements**: Currently private servers have 10% reward deficit

---

## Source URLs

| Source | URL |
|--------|-----|
| Original Roblox Game Page | https://www.roblox.com/games/60654525/The-Legendary-Swords-RPG |
| Restored Version Roblox Page | https://www.roblox.com/games/129119196465909/The-Legendary-Swords-RPG-Restored |
| Omega\_RX Profile | https://www.roblox.com/users/16332998/profile |
| Original Wiki (Fandom) | https://legendary-swords-rpg.fandom.com/wiki/Legendary_Swords_RPG_Wikia |
| Restored Wiki (Fandom) | https://the-legendary-swords-rpg-restored.fandom.com/wiki/The_Legendary_Swords_RPG:_Restored_Wiki |
| Remastered Wiki (Fandom) | https://the-legendary-swords-rpg-remastered-new.fandom.com/wiki/The_Legendary_Swords_RPG_Remastered_Wiki |
| LS RPG 2 Wiki | https://legendary-swords-rpg-2.fandom.com/wiki/Legendary_Swords_Rpg_2_Wiki |
| Restored Wiki - Areas | https://the-legendary-swords-rpg-restored.fandom.com/wiki/Areas |
| Restored Wiki - Weapons | https://the-legendary-swords-rpg-restored.fandom.com/wiki/Weapons |
| Restored Wiki - Enemies | https://the-legendary-swords-rpg-restored.fandom.com/wiki/Enemies |
| Restored Wiki - Gamepasses | https://the-legendary-swords-rpg-restored.fandom.com/wiki/Gamepasses |
| Restored Wiki - Weapon Rarities | https://the-legendary-swords-rpg-restored.fandom.com/wiki/Weapon_Rarities |
| Remastered Wiki - Swords | https://the-legendary-swords-rpg-remastered-new.fandom.com/wiki/Swords |
| Remastered Wiki - Bosses | https://the-legendary-swords-rpg-remastered-new.fandom.com/wiki/Bosses |
| Original Wiki - Ultra Swords | https://legendary-swords-rpg.fandom.com/wiki/Ultra_Swords |
| Restored Wiki - Dagon Boss | https://the-legendary-swords-rpg-restored.fandom.com/wiki/Dagon |
| Restored Wiki - Legendary (Title) | https://the-legendary-swords-rpg-restored.fandom.com/wiki/Legendary |
| Restored Wiki - Boss Item Chances | https://legendary-swords-rpg.fandom.com/wiki/Boss_item_chances |
| Miraheze Restored Wiki | https://lsrpg.miraheze.org/wiki/Main_Page |
| RobloxGo Stats (Restored) | https://www.robloxgo.com/game/129119196465909/The-Legendary-Swords-RPG-Restored |
| Roblox Wiki (Fandom) Mention | https://roblox.fandom.com/wiki/Player:Jeannecca |
