# Sword RPG Progression & Leveling Curves
## Research Document — Roblox One-Piece-Style RPGs

> **Last Updated:** 2026-09-14
> **Games Analyzed:** Blox Fruits, King Legacy, Grand Piece Online
> **Purpose:** Reference for designing progression systems in new Roblox sword RPGs

---

## Table of Contents

1. [Level Caps & XP Requirements (By Game)](#1-level-caps--xp-requirements-by-game)
2. [XP Curve Shape Analysis](#2-xp-curve-shape-analysis)
3. [XP Sources & Efficiency](#3-xp-sources--efficiency)
4. [Progression Gates](#4-progression-gates)
5. [Mid-Game & End-Game Retention](#5-mid-game--end-game-retention)
6. [Optimal Pacing Benchmarks](#6-optimal-pacing-benchmarks)
7. [XP Multiplier Systems](#7-xp-multiplier-systems)
8. [PROGRESSION DESIGN TEMPLATE](#8-progression-design-template)
9. [Sources](#9-sources)

---

## 1. Level Caps & XP Requirements (By Game)

### Comparison Table

| Game             | Max Level | Total Seas/Worlds | Total XP to Max    | XP Curve Type      | Est. Hours to Max |
|------------------|-----------|-------------------|--------------------|--------------------|-------------------|
| Blox Fruits      | 2,800 (3,000*) | 3 Seas          | ~143.8 billion     | Exponential (L^2.3)| 150–300+          |
| King Legacy      | 5,000     | 3 Seas (21+ islands) | ~1.8 trillion (est.) | Exponential       | 200–400+          |
| Grand Piece Online | 675     | 2 Seas            | ~15 million (est.) | Polynomial         | 80–150            |

*\*Blox Fruits level cap raised to 3,000 by completing all Island Secrets in Sea 1.*

### Blox Fruits — Confirmed XP Formula

The XP needed per level follows:

```
XP_to_next_level = ⌈2 × L^2.3 + 84⌉
```

The cumulative XP to reach level L follows (approximate):

```
Total_XP ≈ 115.275 × 1.16771^L - 71
```

**Key milestones (Blox Fruits):**

| Level | Cumulative XP    | XP for Next Level | Approx. Hours Played |
|-------|------------------|-------------------|----------------------|
| 1     | 86               | 86                | 0                    |
| 50    | ~50,000          | ~1,700            | 0.5–1                |
| 100   | ~350,000         | ~6,300            | 2–3                  |
| 250   | ~5,000,000       | ~56,000           | 6–10                 |
| 500   | ~55,000,000      | ~270,000          | 20–30                |
| 700   | ~200,000,000     | ~600,000          | 35–50                |
| 1,000 | ~1,200,000,000   | ~1,400,000        | 50–80                |
| 1,500 | ~10,000,000,000  | ~4,000,000        | 80–120               |
| 2,000 | ~45,000,000,000  | ~10,000,000       | 100–160              |
| 2,500 | ~100,000,000,000 | ~20,000,000       | 130–200              |
| 2,800 | ~143,840,871,332 | (max)             | 150–300              |

### King Legacy — Quest XP Progression

| Level Range | Quest XP (typical) | Island              |
|-------------|-------------------|---------------------|
| 0–50        | 350 → 5,440       | Starter Island      |
| 50–150      | 9,070 → 113,400   | Pirate/Soldier Island |
| 150–500     | 140,000 → 964,687 | Shark Island → Snow |
| 500–1,000   | 1,157,187 → 3,858,750 | Sand Kingdom → Bubble |
| 1,000–2,000 | 4,235,000 → 14,000,000 | Lobby → War Island |
| 2,000–3,000 | 14,708,750 → 29,739,531 | Fishman → Wano |
| 3,000–4,000 | 30,730,781 → 52,000,000 | Onigashima → Dressrosa |
| 4,000–5,000 | 24,603,750 → 57,675,000+ | Third Sea (Unearthly+) |

### Grand Piece Online — Level Progression

| Level Range | Island                  | Est. Time in Zone |
|-------------|-------------------------|-------------------|
| 1–15        | Town of Beginnings      | 15–30 min         |
| 15–20       | Sandora                 | 15–20 min         |
| 20–40       | Shell's Town            | 30–45 min         |
| 40–75       | Baratie                 | 45–60 min         |
| 75–110      | Arlong Park             | 60–90 min         |
| 110–160     | Sky Castle              | 2–3 hours         |
| 160–190     | Gravito's Fort          | 1–2 hours         |
| 190–325     | Fishman Island          | 3–5 hours         |
| 325–425     | Thriller Bark / Sea 2   | 4–6 hours         |
| 425–575     | Rose Kingdom            | 5–8 hours         |
| 575–675     | Second Sea endgame      | 5–10 hours        |

---

## 2. XP Curve Shape Analysis

### All Three Games Use Exponential/Polynomial Curves

```
XP Required Per Level (Visual Approximation)

XP
 ▲
 │                                          ████
 │                                      ████
 │                                  ████
 │                              ████
 │                          ████
 │                      ████
 │                 █████
 │            █████
 │       █████
 │  █████
 │██
 └──────────────────────────────────────────────► Level
 1    100   300   500  700  1000  1500  2000  2800

         Early: Fast          Mid: Moderate       Late: Very Slow
```

**Blox Fruits exact formula:** `XP(L) = ⌈2 × L^2.3 + 84⌉`

This is **polynomial with exponent 2.3**, which creates a steeper curve than simple quadratic but gentler than pure exponential. The result:

- Levels 1–100: ~350K total XP (tutorial phase)
- Levels 100–700: ~200M total XP (first sea progression)
- Levels 700–1500: ~10B total XP (second sea, exponential ramp)
- Levels 1500–2800: ~143B total XP (third sea, extreme endgame grind)

**Why this works:** The early levels fly by (minutes per level), creating an addictive "just one more" loop. By the time progression slows, the player is invested in the world and chasing new unlocks.

---

## 3. XP Sources & Efficiency

### Primary XP Sources (All Games)

| Source           | % of Total XP | Blox Fruits Details                    | Notes                              |
|------------------|---------------|----------------------------------------|------------------------------------|
| **Questing**     | 70–85%        | Kill 5–9 enemies or 1 boss per quest  | By far the dominant source         |
| **Mob Grinding** | 10–20%        | Small XP per kill (negligible alone)  | Supplements questing               |
| **Boss Kills**   | 3–8%          | Bonus levels (1–6 per raid boss)      | Gate content, not grinding source  |
| **Fishing**      | 1–3%          | 25% of current level XP per catch     | Niche, not recommended for speed   |
| **Praying**      | <1%           | 49% chance at Gravestone (Sea 3)      | RNG-based, unreliable              |
| **PvP**          | 0%            | No XP from PvP in any major game      | Bounty/Honor system only           |

### Blox Fruits — Sample Quest XP Values

| Level Req | Quest Target         | Quest XP         | Money      | Location          |
|-----------|---------------------|------------------|------------|-------------------|
| 0         | Kill 5 Bandits      | 300              | $350       | Starter Island    |
| 10        | Kill 5 Monkeys      | 2,300            | $800       | Jungle            |
| 20        | Kill Gorilla King   | 9,500            | $2,000     | Jungle (Boss)     |
| 60        | Kill Desert Bandits | 45,000           | $4,000     | Desert            |
| 120       | Kill CPO            | 225,000          | $6,000     | Marine Fortress   |
| 300       | Kill Military       | 1,700,000        | $8,250     | Magma Village     |
| 700       | Kill Raiders        | 8,750,000        | $10,250    | Kingdom of Rose   |
| 1,000     | Kill Snow Troopers  | 22,500,000       | $12,250    | Snow Mountain     |
| 1,500     | Kill Pirate Million.| 53,000,000       | $13,000    | Port Town         |
| 2,000     | Kill Living Zombies | 93,500,000       | $13,250    | Haunted Castle    |
| 2,500     | Kill Baking Staff   | 115,000,000      | $14,400    | Sea of Treats     |
| 2,800     | (near max quests)   | 120,000,000+     | $14,600+   | Tiki Outpost      |

### Efficiency Tier List

| Method                          | XP/Hour (relative) | When to Use              |
|---------------------------------|--------------------|--------------------------|
| Quest cycling (optimal mobs)    | ★★★★★              | Always (primary method)  |
| Quest cycling with 2x XP       | ★★★★★+             | During events/codes      |
| Boss hopping (server hop)       | ★★★★               | Mid-game for bonus levels|
| Fishing                         | ★★                 | AFK sessions (not optimal)|
| Raw mob grinding (no quest)     | ★                  | Never if quests available|
| PvP                             | ☆                  | End-game only (no XP)    |

---

## 4. Progression Gates

### Sea/World Level Gates

| Gate               | Blox Fruits | King Legacy | Grand Piece Online |
|--------------------|-------------|-------------|-------------------|
| Sea 1 → Sea 2     | Level 700   | Level 2,250 | Level ~325        |
| Sea 2 → Sea 3     | Level 1,500 | Level 4,000 | N/A (2 seas only) |
| Sea 3 → Endgame    | Level 2,500+| Level 5,000 | Level 675 (max)   |

### Content Unlock Gates

| Unlock Type             | Example (Blox Fruits)              | Level Required |
|------------------------|------------------------------------|----------------|
| Sea Travel             | Second Sea access                  | 700            |
| Sea Travel             | Third Sea access                   | 1,500          |
| Fighting Style         | Dark Step (basic)                  | ~15            |
| Fighting Style         | Superhuman (advanced)              | 300+           |
| Fighting Style         | Godhuman (top tier)                | 1,500+         |
| Fruit Awakening        | Raid access                        | 1,100+         |
| Race V2 Upgrade        | Alchemist quest                    | ~700           |
| Race V3 Upgrade        | Arowe quest                        | ~1,500         |
| Haki/Aura              | Aura (basic)                       | ~300           |
| Haki/Aura              | Instinct V2                        | 1,500+         |
| Secret Level Cap Raise | All Island Secrets (Sea 1)         | Completion-based|

### What Gates Look Like in Practice

```
                    PROGRESSION GATE MAP
                    
Level 1     ──► Tutorial Island (learn controls)
Level 10    ──► First quest hub (Jungle)
Level 700   ──► ★ MAJOR GATE: Second Sea opens ★
                (new world, new enemies, new fruits, new styles)
Level 1,100 ──► Raids unlock (co-op content)
Level 1,500 ──► ★ MAJOR GATE: Third Sea opens ★
                (final world, endgame bosses, PvP meta)
Level 2,000 ──► PvP becomes primary focus
Level 2,800 ──► Base max level reached
Level 3,000 ──► True max (Island Secrets completed)
```

---

## 5. Mid-Game & End-Game Retention

### The "Dead Zone" — Where Players Quit

| Game             | Dead Zone         | Why Players Quit                              |
|------------------|-------------------|-----------------------------------------------|
| Blox Fruits      | Level 700–900     | Transition to Sea 2 is jarring; new grind starts |
| Blox Fruits      | Level 1,500–1,700 | Sea 3 opening; enemies become much harder     |
| King Legacy      | Level 1,000–2,000 | Long grind between islands; slow quest XP     |
| King Legacy      | Level 3,500–4,000 | Diminishing returns on quest XP               |
| Grand Piece Online | Level 300–400    | Fishman Island grind wall                     |

### What Keeps Endgame Players Engaged

| Retention Hook        | Description                                          | Example Game     |
|-----------------------|------------------------------------------------------|------------------|
| **PvP / Bounty**      | Bounty/Honor system with leaderboards                | All three        |
| **Boss Raids**        | Co-op raid bosses with rare drops                    | Blox Fruits      |
| **Fruit Hunting**     | Rare devil fruit gacha (1% legendary)                | All three        |
| **Fighting Style Mastery** | Level up each style to mastery rank              | All three        |
| **Race Upgrades**     | V2 → V3 → V4 race evolutions                       | Blox Fruits      |
| **Cosmetic Collection** | Rare accessories, titles, skins                     | All three        |
| **Sea Events**        | Random ocean encounters (Sea Beast, Leviathan)       | Blox Fruits      |
| **Trading Economy**   | Player-to-player item/fruit trading                  | GPO, King Legacy |
| **Dungeon Content**   | Repeatable dungeon runs for loot                     | GPO, King Legacy |
| **Level Cap Extensions** | Updates raise max level, adding new grind          | All three        |
| **Bounty Leaderboard** | Top bounties displayed server-wide                  | All three        |
| **Island Secrets**    | Hidden puzzles/completionists content                | Blox Fruits      |

### Retention Timeline

```
Player Retention Curve (Typical Roblox Sword RPG)

Players
  │
  │████
  │████████
  │████████████
  │████████████████
  │██████████████████████
  │██████████████████████████████
  │████████████████████████████████████████
  │████████████████████████████████████████████████████████
  └──────────────────────────────────────────────────────────► Time
  Day 1    Week 1    Week 2    Month 1    Month 3    Month 6+

  [HOOK PHASE] [GRIND]  [FIRST GATE] [ENDGAME]  [HARDCORE]
  (fast levels) (moderate) (Sea 2 opens) (PvP focus) (collection)
```

**Key insight:** Blox Fruits has maintained 500K–1M+ concurrent players for years. The secret is the **three-sea structure** with hard gates that create aspirational content ("I want to reach Sea 3") and the **gacha system** for rare fruits that gives endless chasing.

---

## 6. Optimal Pacing Benchmarks

### Recommended Pacing (Derived from Top Games)

| Phase              | Level Range | Time Target     | Levels/Hour | Key Feel         |
|--------------------|-------------|-----------------|-------------|------------------|
| **Tutorial**       | 1–50        | 30–60 minutes   | 50–100      | Rapid, exciting  |
| **Early Game**     | 50–200      | 2–4 hours       | 30–50       | Exploring, learning |
| **Early-Mid**      | 200–500     | 4–8 hours       | 20–40       | Building power   |
| **Mid Game**       | 500–1,000   | 8–15 hours      | 10–25       | Steady progress  |
| **Mid-Late**       | 1,000–2,000 | 15–30 hours     | 5–15        | Slowing down     |
| **Late Game**      | 2,000–2,500 | 20–40 hours     | 3–8         | Grinding focus   |
| **Endgame**        | 2,500–2,800 | 20–50 hours     | 1–5         | Prestige, PvP    |
| **Beyond Max**     | 2,800–3,000 | 20–50+ hours    | <1          | Completionist    |

**Total estimated time to max level: 100–300 hours** (depending on optimization and multipliers)

### The "Feel Good" Formula

```
TUTORIAL SPEED (Levels 1–50):
  → Level every 1–2 minutes
  → Player should think "This game is fast and fun!"
  
FIRST SLOWDOWN (Levels 200–500):
  → Level every 3–5 minutes
  → New areas unlock every 30–50 levels
  → Player should think "There's so much to explore!"
  
MID-GAME WALL (Levels 700–1,500):
  → Level every 5–10 minutes
  → MAJOR world transition (Sea 2) resets the excitement
  → Player should think "I just got to a whole new world!"

LATE GRIND (Levels 2,000–2,800):
  → Level every 10–20 minutes
  → PvP and rare items become primary motivators
  → Player should think "I'm almost there, and I want that rare drop"
```

---

## 7. XP Multiplier Systems

### Blox Fruits Multiplier Stack

| Multiplier Source        | Value  | Cost/Source                    |
|--------------------------|--------|--------------------------------|
| Base XP                  | 1.0x   | —                              |
| 2x EXP (Shop)            | 2.0x   | 25 R$ (15 min) to 1,499 R$ (24hr) |
| 2x EXP (Codes)           | 2.0x   | Free (limited availability)    |
| Roblox Premium            | 1.1x   | Roblox subscription            |
| Party Hat accessory      | 1.1x   | Limited event item             |
| Curse of Thief enchant   | 2.5x   | Rare in-game enchant           |
| Efficient 4 enchant      | 1.6x   | Rare in-game enchant           |

**Maximum theoretical stack:** ~6.7x multiplier (Premium + Party Hat + 2x EXP + Curse of Thief)

### Design Insight: Why Multipliers Matter

- **Codes/events** create urgency ("Log in now for 2x XP weekend!")
- **Game pass multipliers** monetize impatience without breaking balance
- **Stacking** encourages engagement with multiple systems (enchanting, accessories)
- **Time-limited boosts** create FOMO and daily login habits

---

## 8. PROGRESSION DESIGN TEMPLATE

### For a New Roblox Sword RPG

Use this as a starting framework. Adjust numbers based on your game's scope and content volume.

---

### 8.1 Core Parameters

```
MAX LEVEL:              2,500
SEAS/WORLDS:            3
ISLANDS PER SEA:        8–12
TOTAL ISLANDS:          ~30
XP CURVE FORMULA:       XP(L) = ⌈A × L^B + C⌉
  Recommended:          A = 1.5, B = 2.25, C = 50
  (Slightly gentler than Blox Fruits' 2.3 exponent)
TOTAL XP TO MAX:        ~80–100 billion
HOURS TO MAX (casual):  150–200
HOURS TO MAX (optimal): 80–120
```

### 8.2 Sea Gate Levels

```
SEA 1 (Starter World):
  Level Range:    1–700
  Islands:        10
  Purpose:        Tutorial → Core Loop establishment
  Time to clear:  20–40 hours
  
SEA 2 (Mid Game):
  Level Range:    700–1,500
  Islands:        10
  Purpose:        Power scaling, awakening systems, raids
  Time to clear:  30–60 hours
  
SEA 3 (End Game):
  Level Range:    1,500–2,500
  Islands:        10
  Purpose:        PvP meta, rare collection, prestige
  Time to clear:  40–80 hours
```

### 8.3 XP Values Per Quest (Template)

| Level Range | Quest XP (approx) | Enemies per Quest | Location Tier |
|-------------|-------------------|-------------------|---------------|
| 0–50        | 100–5,000         | 3–5               | Starter       |
| 50–150      | 5,000–80,000      | 4–6               | Early         |
| 150–300     | 80,000–500,000    | 5–7               | Mid-Early     |
| 300–500     | 500,000–3,000,000 | 5–8               | Mid           |
| 500–700     | 3,000,000–8,000,000| 5–8              | Mid-Late (S1) |
| 700–1,000   | 8,000,000–20,000,000| 5–8             | Sea 2 Start   |
| 1,000–1,500 | 20,000,000–60,000,000| 5–9            | Sea 2 Late    |
| 1,500–2,000 | 60,000,000–120,000,000| 5–9           | Sea 3 Start   |
| 2,000–2,500 | 120,000,000–200,000,000| 6–10         | Sea 3 End     |

### 8.4 Progression Gate Checklist

```
□ Level 1:      Tutorial island → Learn basic combat
□ Level 10:     First real quest hub
□ Level 50:     First boat/travel unlock
□ Level 100:    First fighting style unlock
□ Level 200:    Aura/Haki system unlock
□ Level 300:    First boss raid accessible
□ Level 500:    Fruit/Power awakening possible
□ Level 700:    ★ SEA 2 GATE — New world opens ★
□ Level 700:    Race V2 upgrade available
□ Level 1,000:  Advanced fighting style unlock
□ Level 1,100:  Co-op raid system unlock
□ Level 1,300:  Race V3 upgrade available
□ Level 1,500:  ★ SEA 3 GATE — Final world opens ★
□ Level 1,500:  Top-tier fighting style unlock
□ Level 2,000:  Full PvP meta accessible
□ Level 2,200:  Race V4 / ultimate upgrade
□ Level 2,500:  ★ MAX LEVEL — Prestige/endgame begins ★
```

### 8.5 Endgame Retention Systems

Include at least 3–4 of these for a robust endgame:

```
1. PVP BOUNTY SYSTEM
   - Kill players to gain Bounty/Honor
   - Leaderboard display (top 50 per server)
   - Bounty milestones unlock cosmetics
   - Max bounty cap: 30M

2. RARE DROP CHASING
   - 1–5% drop rate boss weapons
   - Legendary power/fruit gacha (~1% rate)
   - Trading system for player economy

3. MASTERY SYSTEM
   - Each fighting style has independent mastery level
   - Mastery unlocks bonus abilities/cosmetics
   - Mastery XP earned through use (not separate grind)

4. RACE EVOLUTION
   - V1 (default) → V2 (quest) → V3 (hard quest) → V4 (raid)
   - Each evolution adds meaningful power + cosmetic change
   - Race affects playstyle (tank vs speed vs utility)

5. SEASONAL/EVENT CONTENT
   - Limited-time bosses with exclusive drops
   - 2x XP weekends (every 2–4 weeks)
   - Holiday events with unique cosmetics

6. COLLECTION SYSTEM
   - Titles for achievements
   - Accessory gallery
   - Fruit/Power encyclopedia
   - Island Secrets (hidden collectibles)
```

### 8.6 Stat System Template

```
STAT POINTS PER LEVEL:  3
MAX STAT CAP:           Equal to current level cap (2,500)
MAX STATS AT CAP:       3 out of 5 categories

STAT CATEGORIES:
  ┌─────────────────┬──────────────────────────────────┐
  │ Melee/Strength  │ Increases physical damage         │
  │ Defense/HP      │ Increases health pool             │
  │ Sword/Weapon    │ Increases weapon damage           │
  │ Fruit/Magic     │ Increases ability damage           │
  │ Gun/Ranged      │ Increases ranged damage            │
  └─────────────────┴──────────────────────────────────┘

DESIGN RULE: Player can max 3 of 5 stats, forcing build choices.
  → Total points at cap: 2,500 × 3 = 7,500
  → Max per stat: 2,500
  → 3 × 2,500 = 7,500 (exact fit)

STAT RESPECT: Available via premium currency or rare item
  → Monetization opportunity
  → Allows build experimentation
```

### 8.7 Recommended Timing Per Session

| Session Length | Expected Progress | Feeling               |
|----------------|-------------------|-----------------------|
| 15 minutes     | 3–10 levels       | Quick dopamine hit     |
| 30 minutes     | 8–20 levels       | Meaningful progress    |
| 1 hour         | 15–40 levels      | Good session, new area |
| 2 hours        | 25–60 levels      | Satisfying marathon    |
| 4+ hours       | 40–100 levels     | Hardcore session       |

**Design target:** A player should ALWAYS feel like they made progress in a 15-minute session. If they can't level up at least once in 15 minutes, the curve is too steep.

---

## 9. Sources

| Source | URL | Data Retrieved |
|--------|-----|----------------|
| Blox Fruits Wiki — Experience | https://blox-fruits.fandom.com/wiki/Experience | XP formula, multiplier stack, total XP to max |
| Blox Fruits Wiki — Levels | https://blox-fruits.fandom.com/wiki/Levels | Level cap history, stat system, level gain from bosses |
| Blox Fruits Wiki — Leveling Guide | https://blox-fruits.fandom.com/wiki/Leveling_Guide | Optimal grinding routes, build recommendations, Sea 1/2/3 paths |
| Blox Fruits Wiki — Quests | https://blox-fruits.fandom.com/wiki/Quests | Complete quest XP table for all 3 seas, level requirements |
| King Legacy Wiki — Home | https://king-legacy.fandom.com/wiki/King_Legacy_Wiki | Game overview, max level 5000, 21 islands |
| King Legacy Wiki — Quests | https://king-legacy.fandom.com/wiki/Quests | Full quest XP data for all 3 seas (Level 0–5000+) |
| King Legacy Wiki — Beginners Guide | https://king-legacy.fandom.com/wiki/Beginners_Guide | Stat system, progression flow, devil fruit system |
| GPO Wiki — Home | https://grand-piece-online.fandom.com/wiki/Grand_Piece_Online_Wiki | Game overview, max level 675, 2 seas |
| GPO Wiki — Grinding for Beginners | https://grand-piece-online.fandom.com/wiki/Grinding_for_Beginners | Level ranges per island, EXP mechanics, race system |

---

## Appendix: Blox Fruits Level Cap History

The level cap has been raised **20+ times** since launch, showing the importance of extending progression for veteran players:

| Update | Level Cap | Increase |
|--------|-----------|----------|
| Update 1 (Jan 2019) | 300 | Launch |
| Update 2 | 500 | +200 |
| Update 3 | 650 | +150 |
| Update 5 | 750 | +100 |
| Update 8 | 1,000 | +250 |
| Update 9 | 1,100 | +100 |
| Update 10 | 1,250 | +150 |
| Update 12 | 1,350 | +100 |
| Update 13 | 1,450 | +100 |
| Update 14 | 1,525 | +75 |
| Update 15 | 2,000 | +475 |
| Update 16 | 2,100 | +100 |
| Update 17.1 | 2,200 | +100 |
| Update 17.2 | 2,300 | +100 |
| Update 17.3 | 2,400 | +100 |
| Update 17.3.5 | 2,450 | +50 |
| Update 20 | 2,550 | +100 |
| Update 24 | 2,600 | +50 |
| Update 26 | 2,650 | +50 |
| Update 27.0 | 2,750 | +100 |
| Update 27.4 | 2,800 | +50 |
| Update 30 | 3,000 | +200 (secrets) |

**Design lesson:** Plan for level cap increases from day one. Each update raises the cap by 50–250 levels, giving veteran players a reason to return and keeping the grind fresh.
