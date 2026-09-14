# Weapon Acquisition Systems in Roblox RPG Games

> Research document analyzing weapon/sword acquisition patterns across top Roblox RPGs.
> Sources: Blox Fruits Wiki, King Legacy Wiki, Deepwoken Wiki, game design theory.

---

## Table of Contents

1. [Acquisition Methods Across Games](#1-acquisition-methods-across-games)
2. [Rarity Systems Comparison](#2-rarity-systems-comparison)
3. [Weapon Progression & Enhancement](#3-weapon-progression--enhancement)
4. [Boss Farming Mechanics](#4-boss-farming-mechanics)
5. [What Makes Acquisition Feel GOOD](#5-what-makes-acquisition-feel-good)
6. [Weapon Acquisition Design Template](#6-weapon-acquisition-design-template)
7. [Source URLs](#7-source-urls)

---

## 1. Acquisition Methods Across Games

### Method Comparison Table

| Method | Blox Fruits | King Legacy | Deepwoken |
|---|---|---|---|
| **NPC Shop Purchase** | Yes (Sword Dealers, currency-gated) | Yes (NPCs, level-gated) | Yes (Shops in Etris, Isle of Vigils) |
| **Boss Drops** | Yes (primary for Rare+) | Yes (primary for Epic+) | Yes (from chests after boss kills) |
| **Crafting** | Yes (Blacksmith + materials) | Yes (Blacksmith + materials) | Yes (Crafting Stations) |
| **Quest Rewards** | Yes (e.g., Yama from 20-30 Elite Hunter quests) | Yes (Kioru from questline) | Indirect (quest unlocks access to areas) |
| **Puzzle/Secret** | Yes (Cursed Dual Katana scroll trials, Rengoku hidden key) | Yes (Kioru questline) | Yes (hidden chests, secret locations) |
| **Chest Drops** | No | No | Yes (primary loot source, quality stars + enchants) |
| **Trading** | Yes (level-gated) | Yes (Level 300+ required) | No (soulbound system) |
| **Gamepass (Robux)** | Yes (Dark Blade) | Yes (Night Blade) | No |
| **Battlepass** | No | Yes | No |
| **World Spawns** | Yes (Legendary Sword Dealer spawns) | No | Yes (random encounters) |

### Detailed Acquisition Flow by Game

#### Blox Fruits (42 total swords)
- **Common (3):** Direct purchase from Sword Dealers (1,000 - 12,000 money)
- **Uncommon (5):** Purchase or mini-boss drops
- **Rare (9):** Boss drops or expensive purchases (100,000 - 750,000 money)
- **Legendary (19):** Boss drops, material crafting, quest chains, hidden keys, Legendary Sword Dealer
- **Mythical (6):** Puzzle completion (Cursed Dual Katana scroll trials), Gamepass (Dark Blade), rare boss drops

#### King Legacy (59 total swords)
- **Common (6):** NPC purchases or mini-boss drops on Starter Island
- **Uncommon (6):** Mini-boss drops
- **Rare (6):** Second Sea bosses, first questline swords (Kioru)
- **Epic (15):** Boss drops, Battlepass tiers, Minion mode
- **Legendary (17):** Most sought-after; boss drops, crafting, high-level quests
- **Limited (4):** Event-specific (Xmas Blade, Pumpkin Smasher, etc.)
- **Mythical (5):** Lowest drop chance, most difficult acquisition

#### Deepwoken (100+ weapons)
- **No traditional rarity tiers** - instead uses attribute requirements as progression gates
- Weapons found in **chests** (primary source) with random quality stars (★/★★/★★★) and enchantments
- **Quality Stars:** +2% damage, +5% penetration, or +4% weight per star
- **Enchantments:** Random chance on chest drops; can be applied via Enchant Stones, Laplace NPC (3 enchanted items traded), or crafting
- **Alloy system:** Pluripotent Alloy transforms early weapons into endgame variants
- **Soulbound system:** Enchanted items become soulbound on equip (cannot be traded/dropped)

---

## 2. Rarity Systems Comparison

### Rarity Tier Distribution

| Tier | Blox Fruits | King Legacy | Typical Roblox RPG |
|---|---|---|---|
| **Common** | 3 (7%) | 6 (10%) | 25-30% |
| **Uncommon** | 5 (12%) | 6 (10%) | 20-25% |
| **Rare** | 9 (21%) | 6 (10%) | 15-20% |
| **Epic** | -- | 15 (25%) | 10-15% |
| **Legendary** | 19 (45%) | 17 (29%) | 8-12% |
| **Mythical** | 6 (14%) | 5 (8%) | 2-5% |
| **Limited** | -- | 4 (7%) | Event-only |

**Key Insight:** Blox Fruits has a heavy skew toward Legendary (45% of all swords), making them feel less "legendary" but ensuring most players access strong weapons. King Legacy has a more traditional pyramid with Epic as the largest tier.

### Rarity Correlation with Power

| Game | Does Rarity = Power? | Notes |
|---|---|---|
| Blox Fruits | Mostly yes | Mythicals are universally best; Legendaries dominate PvP |
| King Legacy | Yes | Clear power progression per tier |
| Deepwoken | No | Attribute requirements matter more; a low-req weapon with 3★ and good enchant can outperform a "rare" weapon |

### Recommended Rarity Distribution for New Roblox RPG

| Tier | % of Total | Drop Rate (Boss) | Drop Rate (Mob) | Design Intent |
|---|---|---|---|---|
| **Common** | 25% | Guaranteed | 50% | Tutorial weapons, always accessible |
| **Uncommon** | 20% | 80% | 15% | Early-game upgrades |
| **Rare** | 20% | 40% | 3% | Mid-game goals |
| **Epic** | 15% | 15% | 0.5% | Late-game chase items |
| **Legendary** | 12% | 5% | 0.1% | Endgame prestige |
| **Mythical** | 5% | 1% | N/A (boss-only) | Ultimate flex / hardest to obtain |
| **Exotic** | 3% | Puzzle/Quest only | N/A | Secret/hidden acquisition |

---

## 3. Weapon Progression & Enhancement

### Enhancement Systems by Game

#### Blox Fruits: Upgrade + Enchantment (2 layers)
- **Upgrading (Blacksmith):** One-time material upgrade. Grants +7% to +30% damage depending on rarity. Higher rarity = rarer materials needed. **No failure risk.**
  - Common swords: 2 material types, easy to farm
  - Legendary swords: 3 material types, rare drops needed (Dark Fragments, Dragon Scales)
- **Enchanting (Dragon Talon Sage):** Requires weapon to be upgraded first. Uses Legendary/Mythical Scrolls.
  - **Standard enchants:** 12 types (Agile, Sharp, Vampiric, etc.) with 1-6 levels
  - **Unique enchants:** 6 types (Masterpiece, Rage, Sharpshooter, Strong Grip, Unbreakable, Unreal) - rarer, trade-off design
  - **Blessings:** 3% chance with Legendary Scroll, 10% with Mythical. Add visual effects + powerful passive (Burning, Frozen, Rot, Storm)
  - **Curses:** Very rare. Powerful effect with downside (Curse of the Reaper: halved regen + life drain)

#### King Legacy: Blacksmith Upgrade + Stone Enchantment (2 layers)
- **Upgrading (Blacksmith):** Max +3 upgrades per sword. Uses materials.
- **Stone Enchantment:** Fusing stones onto swords for permanent unique effects. Stones crafted or obtained from activities.

#### Deepwoken: Quality Stars + Enchantments + Alloy (3 layers)
- **Quality Stars (1-3):** Random on acquisition. Each star adds one of: +2% damage, +5% penetration, or +4% weight. Rerolled via Smith's Alloy relic.
- **Enchantments:** Two categories - **Blessings** (positive effects, no downside) and **Curses** (positive + negative). Applied via Enchant Stones, Laplace NPC, or chest drops. Enchanted items soulbound on equip.
- **Alloy System:** Pluripotent Alloy transforms eligible early/mid weapons into endgame variants with boosted stats and requirements. Adds long-term investment value to "weaker" weapons.

### Enhancement Failure Risk Analysis

| Game | Failure Risk? | Player Sentiment |
|---|---|---|
| Blox Fruits | No | Positive - no frustration from wasted materials |
| King Legacy | No | Positive |
| Deepwoken | No (but soulbound = permanent commitment) | Mixed - love the commitment, hate losing items on character death |

**Design Recommendation:** Do NOT implement enhancement failure/destruction in Roblox RPGs. The audience (skews younger) reacts very negatively to losing progress. Instead, use material cost as the "gating" mechanism.

---

## 4. Boss Farming Mechanics

### Boss System Comparison

| Mechanic | Blox Fruits | King Legacy | Deepwoken |
|---|---|---|---|
| **Respawn Timer** | 20 min - 2 hours (varies by boss) | 30 min - 1 hour | Dynamic (zone-based) |
| **Difficulty Scaling** | Level-gated (must meet level req) | Level-gated | Attribute-gated |
| **Loot Lockout** | None (farm repeatedly) | None | None |
| **Drop Rate** | ~1-5% for top-tier drops (estimated) | Varies by rarity | Random chest contents |
| **Boss-Specific Drops** | Yes (each boss has unique loot table) | Yes | Yes |
| **Universal Drops** | Materials always drop | Materials always drop | Materials + gear from chests |
| **World Boss Events** | Yes (Cake Prince, rip_indra) | Yes | Yes (layer bosses) |

### Blox Fruits Boss Drop Examples

| Boss | Notable Drop | Acquisition Method |
|---|---|---|
| Thunder God | Pole (1st Form) - Legendary | Defeat boss (RNG drop) |
| Saber Expert | Saber - Legendary | Defeat boss |
| rip_indra True Form | Dark Dagger - Legendary | Defeat boss + Dark Fragment |
| Beautiful Pirate | Canvander - Legendary | Defeat boss |
| Longma | Tushita - Legendary | Defeat boss |
| Cake Prince/Dough King | Spikey Trident - Legendary | Defeat boss |
| Scroll Trials (Puzzle) | Cursed Dual Katana - Mythical | Complete multi-step puzzle |

### Recommended Boss Design Template

| Parameter | Early Boss | Mid Boss | Late Boss | Raid Boss |
|---|---|---|---|---|
| **Level Req** | 25+ | 100+ | 200+ | 300+ |
| **HP** | 5,000 | 50,000 | 250,000 | 1,000,000+ |
| **Respawn** | 5 min | 15 min | 30 min | 2 hours |
| **Unique Drops** | 1-2 Uncommon weapons | 1-2 Rare weapons | 1-2 Epic/Legendary | 1 Legendary/Mythical |
| **Drop Rate (best item)** | 50% | 20% | 5% | 1% |
| **Material Drops** | Always (common mats) | Always (mid mats) | Always (rare mats) | Always (legendary mats) |
| **Pity System** | After 10 kills | After 15 kills | After 20 kills | After 50 kills |
| **Solo/Group** | Solo | Solo or Group | Group recommended | Group required |

---

## 5. What Makes Acquisition Feel GOOD

### The Dopamine Loop in Roblox RPGs

The most successful Roblox RPGs trigger dopamine through a carefully designed **anticipation-reward-flex** cycle:

#### 1. Anticipation (Pre-Drop)
- **Boss HP bar draining** creates mounting tension (Blox Fruits, King Legacy)
- **Rare drop glow/particles** visible before pickup (Deepwoken chest glow)
- **Countdown timers** for boss spawns create community gathering moments
- **"You feel a strange presence..."** type environmental storytelling before rare encounters

#### 2. The Drop Moment (Reward)
- **Screen-wide announcement** for Mythical/Legendary drops (Blox Fruits server-wide messages)
- **Unique sound effects** per rarity tier (higher pitch/more complex for rarer items)
- **Item reveal animation** with rarity-colored border glow
- **Camera zoom/freeze frame** on the drop
- **Particle explosion** matching rarity color

#### 3. The Flex (Post-Acquisition)
- **Visible weapon on character model** - other players can see your sword (all 3 games)
- **Unique weapon trails/effects** - Cursed Dual Katana in Blox Fruits has distinctive visual
- **Collection tracker/progress** - percentage completion visible
- **Achievement/title unlocked** - "Mythic Swordsman" title for collecting all Mythicals
- **Trade value** - rare items have high trade value, making them currency-equivalent

#### 4. Anti-Frustration Mechanics
- **Pity systems:** Guaranteed drop after X attempts (recommended: boss kill count tracking)
- **Bad luck protection:** Incrementally increasing drop rate per failed attempt
- **Material fallback:** Even failed boss attempts give materials for crafting alternatives
- **Multiple acquisition paths:** Can't get the boss drop? Craft it with enough materials

### Visual/Audio Feedback by Rarity (Recommended)

| Rarity | Color | Sound | Screen Effect | Notification |
|---|---|---|---|---|
| Common | White/Gray | Soft chime | None | None |
| Uncommon | Green | Bright chime | None | None |
| Rare | Blue | Crystalline ring | Brief glow | Party notification |
| Epic | Purple | Deep resonance | Screen pulse | Server notification |
| Legendary | Gold/Orange | Orchestral swell | Golden particles + screen flash | Server-wide announcement |
| Mythical | Red/Crimson | Thunder crack + choir | Full screen VFX + slow-mo | Server-wide with unique message |
| Exotic | Rainbow/Prismatic | Unique per weapon | Cinematic camera + particles | Cross-server announcement |

### Collection & Tracking Systems

| Feature | Blox Fruits | King Legacy | Deepwoken |
|---|---|---|---|
| Weapon Collection UI | Yes (inventory) | Yes (inventory) | Yes (inventory) |
| % Completion Tracker | No | No | No |
| Achievement System | No | Titles system | No |
| Weapon Gallery/Museum | No | No | No |
| Kill Counter per Boss | No | No | No |
| Drop Rate Transparency | No (community-estimated) | No | No |

**Design Opportunity:** No major Roblox RPG currently has a weapon museum/collection tracker. This is a major gap that would drive engagement.

---

## 6. Weapon Acquisition Design Template

### Overview

This template provides recommended values for a Roblox Sword RPG with ~50 weapons across 7 rarity tiers.

### 6.1 Rarity Tier Definitions

| Tier | Color | Total Weapons | Primary Acquisition | Time to Acquire (avg) |
|---|---|---|---|---|
| Common | #B0B0B0 (Gray) | 12 (24%) | Shop purchase | 5 minutes |
| Uncommon | #4CAF50 (Green) | 10 (20%) | Shop + mini-boss | 30 minutes |
| Rare | #2196F3 (Blue) | 10 (20%) | Boss drops + crafting | 2-4 hours |
| Epic | #9C27B0 (Purple) | 8 (16%) | Boss drops + quest chains | 6-12 hours |
| Legendary | #FF9800 (Gold) | 6 (12%) | Raid bosses + puzzles | 1-3 days |
| Mythical | #F44336 (Red) | 3 (6%) | Secret bosses + hard puzzles | 1-2 weeks |
| Exotic | #E91E6C (Prismatic) | 1 (2%) | Hidden quest chain (server-first style) | Weeks+ |

### 6.2 Boss Drop Rate Tables

#### Standard Boss (15-min respawn)

| Drop | Rate | Pity (guaranteed after) |
|---|---|---|
| Common weapon | 75% | 2 kills |
| Uncommon weapon | 30% | 5 kills |
| Rare weapon | 10% | 12 kills |
| Epic weapon | 2% | 40 kills |
| Crafting materials | 100% | -- |
| Gold/currency | 100% | -- |

#### Raid Boss (2-hour respawn, group content)

| Drop | Rate | Pity (guaranteed after) |
|---|---|---|
| Rare weapon | 60% | 3 kills |
| Epic weapon | 20% | 8 kills |
| Legendary weapon | 5% | 25 kills |
| Mythical weapon | 0.5% | 150 kills |
| Raid-exclusive material | 100% | -- |
| Enchantment material | 40% | -- |

#### Secret Boss (hidden spawn, puzzle-triggered)

| Drop | Rate | Pity (guaranteed after) |
|---|---|---|
| Epic weapon | 40% | 5 kills |
| Legendary weapon | 15% | 10 kills |
| Mythical weapon | 3% | 30 kills |
| Unique crafting material | 100% | -- |

### 6.3 Pity System Design

```
PITY MECHANICS:
- Each failed drop attempt increments a hidden counter per weapon per player
- Drop rate increases by (base_rate * 0.5) per failed attempt
- Cap increase at 3x the base rate
- Guaranteed drop at the pity threshold
- Counter resets on successful drop
- Counter persists across sessions (saved to player data)

EXAMPLE (Epic weapon, 10% base rate):
  Attempt 1:  10.0%
  Attempt 2:  15.0%
  Attempt 3:  20.0%
  Attempt 4:  25.0%
  ...
  Attempt 8:  35.0% (cap)
  ...
  Attempt 12: GUARANTEED
```

### 6.4 Weapon Enhancement System

#### Layer 1: Upgrading (Blacksmith)

| Upgrade Level | Material Cost | Damage Bonus | Success Rate |
|---|---|---|---|
| +0 (Base) | -- | 0% | -- |
| +1 | 5 common materials | +10% | 100% |
| +2 | 10 common + 3 uncommon materials | +15% (total) | 100% |
| +3 | 15 common + 5 uncommon + 1 rare material | +20% (total) | 100% |

**No failure risk.** Material cost scales with weapon rarity (Legendary needs 2x materials of Common).

#### Layer 2: Enchanting (Enchanter NPC)

| Scroll Tier | Obtained From | Possible Results | Blessing Chance | Curse Chance |
|---|---|---|---|---|
| Basic Scroll | Mob drops, shops | 1 of 8 standard enchants | 0% | 0% |
| Rare Scroll | Boss drops | 1 of 8 + 4 unique enchants | 5% | 0% |
| Legendary Scroll | Raid bosses, puzzles | All enchants + Blessings | 10% | 3% |
| Mythical Scroll | Secret bosses, milestones | All enchants + Blessings + Curses | 20% | 10% |

#### Layer 3: Reforging (Endgame)

- Quality substats (similar to Deepwoken's ★ system): random bonuses on acquisition
- Reforge Stones allow rerolling quality substats
- Maximum 3 quality stars per weapon
- Stars persist through upgrades

### 6.5 Acquisition Path Diversity

Every weapon should have **at minimum 2 acquisition paths:**

| Weapon Rarity | Primary Path | Secondary Path | Fallback Path |
|---|---|---|---|
| Common | Shop purchase | Mob drop | -- |
| Uncommon | Mini-boss drop | Shop (expensive) | Crafting (basic mats) |
| Rare | Boss drop (10%) | Crafting (boss mats) | Quest reward |
| Epic | Boss drop (2%) | Crafting (rare mats from multiple bosses) | Trading |
| Legendary | Raid boss (5%) | Crafting (raid mats + legendary fragment) | -- |
| Mythical | Secret boss (3%) | Puzzle completion | -- |
| Exotic | Hidden quest chain | -- | -- |

### 6.6 Boss Respawn & Difficulty Template

| Boss Type | Respawn | Players | Level Req | Design Intent |
|---|---|---|---|---|
| Mini-Boss | 3-5 min | 1 | Zone-appropriate | Frequent farming, teach boss mechanics |
| Standard Boss | 15-20 min | 1-2 | 20+ above zone | Primary weapon source |
| World Boss | 45-60 min | 3-8 | 50+ above zone | Social event, rare drops |
| Raid Boss | 2-3 hours | 4-12 | Max level -50 | Endgame group content |
| Secret Boss | Puzzle-triggered | 1-4 | Hidden req | Exploration reward |

### 6.7 Material Economy Design

| Material Tier | Sources | Used For | Drop Rate |
|---|---|---|---|
| Common (Leather, Scrap Metal) | All mobs, all bosses | Common/Uncommon upgrades | 80% from mobs |
| Uncommon (Dragon Scale, Vampire Fang) | Mid-tier mobs, bosses | Rare upgrades | 30% from bosses |
| Rare (Dark Fragment, Meteorite) | Boss-only | Legendary upgrades | 5-10% from bosses |
| Legendary (Unique Boss Materials) | Specific bosses only | Mythical crafting | 100% from specific boss |
| Enchant Materials (Scrolls, Stones) | Bosses, chests, events | Enchanting | 20-40% from bosses |

---

## 7. Source URLs

### Game Wikis
- **Blox Fruits Wiki - Swords:** https://bloxfruits.fandom.com/wiki/Swords
- **Blox Fruits Wiki - Upgrading:** https://bloxfruits.fandom.com/wiki/Upgrading
- **Blox Fruits Wiki - Enchantments:** https://bloxfruits.fandom.com/wiki/Enchantments
- **King Legacy Wiki - Swords:** https://king-legacy-official.fandom.com/wiki/Swords
- **King Legacy Wiki - Blacksmith:** https://king-legacy-official.fandom.com/wiki/Blacksmith
- **Deepwoken Wiki - Weapons:** https://deepwoken.fandom.com/wiki/Weapons
- **Deepwoken Wiki - Enchantments:** https://deepwoken.fandom.com/wiki/Enchantments

### Key Data Points Sourced

| Data Point | Source | URL |
|---|---|---|
| Blox Fruits: 42 total swords, 5 rarity tiers | Blox Fruits Wiki Swords page | https://bloxfruits.fandom.com/wiki/Swords |
| Blox Fruits: Upgrading grants +7-30% damage via Blacksmith | Blox Fruits Wiki Upgrading page | https://bloxfruits.fandom.com/wiki/Upgrading |
| Blox Fruits: Blessings 3%/10% chance, Curses very rare | Blox Fruits Wiki Enchantments page | https://bloxfruits.fandom.com/wiki/Enchantments |
| Blox Fruits: 12 standard + 6 unique + 4 blessing + 2 curse enchants | Blox Fruits Wiki Enchantments page | https://bloxfruits.fandom.com/wiki/Enchantments |
| King Legacy: 59 swords, 7 rarity tiers (Common through Mythical) | King Legacy Wiki Swords page | https://king-legacy-official.fandom.com/wiki/Swords |
| King Legacy: Blacksmith upgrades max +3, stone enchantment system | King Legacy Wiki Blacksmith page | https://king-legacy-official.fandom.com/wiki/Blacksmith |
| Deepwoken: Quality stars (+2% dmg/5% pen/4% weight per star) | Deepwoken Wiki Weapons page | https://deepwoken.fandom.com/wiki/Weapons |
| Deepwoken: Blessings vs Curses enchantment system | Deepwoken Wiki Enchantments page | https://deepwoken.fandom.com/wiki/Enchantments |
| Deepwoken: Enchanted items soulbound on equip | Deepwoken Wiki Enchantments page | https://deepwoken.fandom.com/wiki/Enchantments |
| Deepwoken: Pluripotent Alloy transforms weapons into endgame variants | Deepwoken Wiki Weapons page | https://deepwoken.fandom.com/wiki/Weapons |
| Deepwoken: Enchant acquisition - chests, Laplace NPC, Enchant Stones, crafting | Deepwoken Wiki Enchantments page | https://deepwoken.fandom.com/wiki/Enchantments |

---

*Document compiled from wiki data as of 2026. Drop rates for Blox Fruits and King Legacy are community-estimated (not officially published). Deepwoken quality star values are confirmed from wiki data.*
