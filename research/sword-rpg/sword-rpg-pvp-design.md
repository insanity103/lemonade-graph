# Sword RPG PvP Design Template

> Reference document for PvP systems in Roblox sword/anime RPG games.  
> Synthesized from Blox Fruits, Deepwoken, Grand Piece Online, King Legacy, and Shindo Life.  
> Last updated: 2026-09-14

---

## Table of Contents

1. [PvP Mode Taxonomy](#1-pvp-mode-taxonomy)
2. [Combat Core Mechanics](#2-combat-core-mechanics)
3. [Balance Framework](#3-balance-framework)
4. [Build Tier Lists (Cross-Game)](#4-build-tier-lists-cross-game)
5. [Skill vs Stats Analysis](#5-skill-vs-stats-analysis)
6. [Ranking & Leaderboard Systems](#6-ranking--leaderboard-systems)
7. [PvP Reward Structure](#7-pvp-reward-structure)
8. [Anti-Cheat & Fair Play](#8-anti-cheat--fair-play)
9. [Community Pain Points & Solutions](#9-community-pain-points--solutions)
10. [Recommended Sword RPG PvP Template](#10-recommended-sword-rpg-pvp-template)
11. [Sources](#11-sources)

---

## 1. PvP Mode Taxonomy

Every successful Roblox sword RPG implements multiple PvP modes to serve different player motivations. Here is the full taxonomy observed across the top games:

### Mode Comparison Table

| Mode | Blox Fruits | Deepwoken | Grand Piece Online | King Legacy | Shindo Life | Recommendation |
|------|:-----------:|:---------:|:------------------:|:-----------:|:-----------:|:--------------:|
| **Open World PvP** | Yes (toggle at Lv.20) | Yes (always-on) | Yes (always-on) | Yes (toggle) | Yes (RPG mode) | **Required** |
| **Arena / Duel** | No official | Voidzones / Chime of Dwelling | Arena + Colosseum | No official | Arena X + Competitive | **Required** |
| **Team / Faction PvP** | Pirate vs Marine | Guild wars | Crew battles | Pirate vs Marine | Conquest mode | **High priority** |
| **Battle Royale** | No | No | Yes (BR mode) | No | Shindo Storm | **Optional** |
| **Tournament / Bracket** | No | No | No | No | Competitive Arena X | **High priority** |
| **Bounty System** | Yes (Bounty/Honor) | No | No | No | Ranking system | **Required** |

### Detailed Mode Descriptions

#### 1.1 Open World PvP
The lifeblood of emergent gameplay. All top games feature some form of open-world PvP.

- **Blox Fruits**: PvP unlocks at Level 20. Toggle-based — players opt in. Safe zones exist in spawn areas. "In Combat" flag prevents logging. Killing gives bounty/honor; 25% level difference blocks rewards.
  - *Source*: https://blox-fruits.fandom.com/wiki/PvP_mechanics
- **Deepwoken**: Always-on PvP with no toggle. The Depths serves as a high-stakes PvP zone where death means permanent character loss (wipe). Voidzones are dedicated PvP areas.
  - *Source*: https://deepwoken.fandom.com/wiki/Combat_Mechanics
- **Grand Piece Online**: Open-world PvP is always enabled. Players can fight anywhere. Colosseum provides structured 1v1 arena.
  - *Source*: https://grand-piece-online.fandom.com/wiki/Grand_Piece_Online_Wiki

**Design Recommendation**: Open world PvP with a toggle system is the safest default. Always-on creates tension (Deepwoken) but risks scaring casual players. Implement safe zones around spawn/tutorial areas.

#### 1.2 Arena / Duel Systems
Structured 1v1 or small-team combat with matchmaking.

- **Shindo Life**: Arena X mode (1v1 matchmaking) + Competitive Arena X (ranked). Also has Shindo Storm (team-based) and Competitive Shindo Storm.
  - *Source*: https://shindo-life-rell.fandom.com/wiki/Game_Modes
- **Grand Piece Online**: Arena mode for 1v1 duels. Colosseum of Arc for organized fights. Also has Battle Royale mode.
  - *Source*: https://grand-piece-online.fandom.com/wiki/Arena
- **Deepwoken**: Chime of Dwelling artifact for dueling. Voidzones serve as organic PvP arenas with specific rulesets.
  - *Source*: https://deepwoken.fandom.com/wiki/Combat_Mechanics

**Design Recommendation**: A dedicated arena with MMR-based matchmaking is essential for competitive PvP. Include both ranked and unranked queues.

#### 1.3 Faction / Team PvP
PvP driven by group identity.

- **Blox Fruits**: Pirate vs Marine faction system. Bounty/Honor tracks faction-specific progression.
- **King Legacy**: Pirate vs Marine factions with faction-specific quests and PvP incentives.
- **Shindo Life**: Conquest mode — team-based territory control.
  - *Source*: https://shindo-life-rell.fandom.com/wiki/Game_Modes

**Design Recommendation**: Faction systems create natural PvP rivalries. Pair with guild/clan support for 5v5 or larger team modes.

#### 1.4 Bounty / Hunter Systems
Persistent PvP objectives that reward hunting specific players.

- **Blox Fruits**: The gold standard. Bounty and Honor system tracks PvP kills. Every 500K bounty grants damage/defense buffs. At 10M bounty, players unlock Sea Beast summoning. "No Reward, Suspicious Kill" anti-exploit flag when kills are too clean (M1-only, no damage received). Combat logging penalty.
  - *Source*: https://blox-fruits.fandom.com/wiki/PvP_mechanics

**Design Recommendation**: Bounty systems create emergent "boss player" dynamics. The top bounty players become server celebrities and targets, driving organic PvP content.

---

## 2. Combat Core Mechanics

### 2.1 Deepwoken — The Skill-Based Gold Standard

Deepwoken has the most mechanically deep combat system among Roblox RPGs. Key systems:

| Mechanic | Description | Design Insight |
|----------|-------------|----------------|
| **Block** | Holding block reduces damage but builds posture | Creates risk/reward — passive defense has a cost |
| **Parry** | Frame-perfect block negates all damage, restores posture | The highest-skill defensive option; rewards timing |
| **Dodge/Roll** | I-frame dodge with cooldown | Standard evasive option with resource cost |
| **Posture System** | Blocking builds posture; exceeding threshold = guard break (1.05s stun) | Prevents infinite turtling; aggressive play rewarded |
| **Tempo** | Gained by hitting/being hit; enables Vent at 40+ | Comeback mechanic; losing player builds tempo for escape |
| **Feint** | Cancel attack animation to bait parry | Mind-game layer; prediction vs reaction |
| **Vent (G key)** | Push away nearby players when at 40+ tempo; can be parried/blocked | Anti-pressure escape tool with counterplay |
| **Critical Attacks** | Weapon-specific heavy attack on cooldown | Adds variety per weapon class |
| **Ether (Mana)** | Required for Mantras (spells); regens during combat with tempo | Resource management layer |
| **Armor Durability** | Armor degrades; when broken, no damage reduction | Prevents permanent tank advantage; encourages aggression |
| **Health affects speed** | Lower HP = slower movement | Comeback pressure; losing player can't easily flee |

- *Source*: https://deepwoken.fandom.com/wiki/Combat_Mechanics

### 2.2 Blox Fruits — Combo-Focused Combat

Blox Fruits emphasizes ability combos and build synergy:

| Mechanic | Description | Design Insight |
|----------|-------------|----------------|
| **Instinct (Observation Haki)** | Dodge mechanic — auto-dodge attacks while active, limited uses | Resource-based defense; can be broken by specific moves |
| **Instinct Breaking** | Certain attacks disable opponent's Instinct | Creates attack sequencing strategy |
| **Instinct Trick (Ken Trick)** | Activate Instinct during opponent's combo to dodge specific hits | High-skill expression; timing-dependent |
| **Stun Types** | Soft (limits one action), Medium (limits two), Hard (full lockdown) | Combo design space — chain stun types for combos |
| **End-Lag** | Forced delay after certain moves prevents spam | Anti-spam; creates punish windows |
| **Attack Cancel** | Taking damage during attack startup cancels the attack | Rewards defensive play; punishes predictable aggression |
| **Held Skill Interruption** | Holding a charged skill + getting hit = forced release | Counter to charge attacks |
| **Bounty Buffs** | Every 500K bounty = damage/defense % increase | Endgame progression; incentivizes PvP |
| **Safe Zones** | Spawn areas are PvP-free; "In Combat" flag prevents safe-zone abuse | New player protection |

- *Source*: https://blox-fruits.fandom.com/wiki/PvP_mechanics

### 2.3 Grand Piece Online — Fruit/Weapon Hybrid

| Mechanic | Description |
|----------|-------------|
| **Logia Intangibility** | Logia-type Devil Fruits make users immune to non-Haki physical attacks |
| **Haki System** | Busoshoku (Armament) Haki bypasses Logia intangibility; Kenbunshoku (Observation) for dodging |
| **Fighting Styles** | 10 distinct styles (Black Leg, Rokushiki, Electro, Fishman Karate, etc.) |
| **Weapon + Fruit Builds** | Players equip both a fruit and a weapon, creating 2-axis build variety |
| **Racial Passives** | Skypian (glide), Mink (Electro bonus), Fishman (water strength), Cyborg (tank) |

- *Source*: https://grand-piece-online.fandom.com/wiki/Grand_Piece_Online_Wiki

### 2.4 Shindo Life — Bloodline/Element Combo System

| Mechanic | Description |
|----------|-------------|
| **Bloodline Slots** | 3 bloodline slots + element slot + sub-ability + ninja tools |
| **Global Cooldown** | Shared cooldown between abilities prevents instant-combo one-shots |
| **Combat Arts** | Melee styles (Boxing, Muay Thai, MMA, Jeet Kune Do) for close-range |
| **Kenjutsu** | Sword styles (Wind, Water, Thunder, Flame, etc.) for weapon combat |
| **Modes/Awakenings** | Transformation states that buff all abilities temporarily |

- *Source*: https://shindo-life-rell.fandom.com/wiki/Shindo_Life_Wiki

---

## 3. Balance Framework

### 3.1 Balance Levers Overview

| Balance Lever | Description | Used By | Impact |
|--------------|-------------|---------|--------|
| **Cooldown Timers** | Per-ability cooldowns prevent spam | All games | High — primary pacing control |
| **Global Cooldown** | Shared CD between all abilities | Shindo Life | Very High — prevents one-shot combos |
| **End-Lag** | Forced delay after abilities | Blox Fruits | Medium — creates punish windows |
| **Posture/Guard Break** | Defensive play has a cost | Deepwoken | High — prevents infinite turtling |
| **Level Brackets** | PvP restricted by level range | Blox Fruits (25% diff) | Medium — protects low-level players |
| **Stat Normalization** | Equalize stats in PvP context | None currently (opportunity) | Very High — makes skill matter more |
| **Bounty Scaling** | Higher bounty = stronger stats | Blox Fruits | High — endgame progression |
| **Racial Counters** | Races have strengths/weaknesses | GPO, Blox Fruits | Medium — adds build variety |
| **Fruit/Element Counters** | Some abilities counter others | All games | High — creates meta rotation |

### 3.2 Rock-Paper-Scissors vs Linear Power

Most Roblox RPGs use a **hybrid model**:

```
Rock-Paper-Scissors Layer (type advantages):
  Fruit A > Fruit B > Fruit C > Fruit A
  
Linear Power Layer (stat scaling):
  Higher level + better gear = strictly stronger

Combined:
  A lower-level player with type advantage CAN beat a higher-level player
  But raw stats still matter ~60-70% of the time
```

**Deepwoken** is the exception — its combat is ~80% skill-based due to:
- Parry/feint mind-games
- Posture system punishing passive play
- Health affecting speed (losing player gets slower)
- No direct stat-to-damage scaling like Blox Fruits' bounty system

### 3.3 Nerf Cycle Patterns

How top Roblox games handle overpowered builds:

| Pattern | Description | Example |
|---------|-------------|---------|
| **Buff other options** | Rather than nerfing the best, buff everything else | Preferred by community; avoids "fun removal" |
| **Targeted cooldown increase** | Increase CD on the specific broken ability | Blox Fruits approach — surgical |
| **Mechanic interaction fix** | Fix unintended combo interactions | Deepwoken — fix tech that bypasses intended counterplay |
| **New counter introduction** | Add a new ability/item that specifically counters the meta | GPO adding Haki to counter Logia |
| **Tiered rarity gating** | Make powerful options harder to obtain | Blox Fruits fruit rarity (Mythical = rarest) |

### 3.4 Stat Normalization Decision Matrix

| Scenario | Normalize? | Reasoning |
|----------|:----------:|-----------|
| Arena/Ranked PvP | **Yes** | Skill should determine rank, not grind |
| Open World PvP | **Partial** | Some advantage for progression, but cap the gap |
| Tournament PvP | **Yes** | Competitive integrity requires even playing field |
| Bounty Hunting | **No** | Bounty system is about power fantasy + progression |
| Faction Wars | **Partial** | Group coordination matters more than individual stats |

---

## 4. Build Tier Lists (Cross-Game)

### 4.1 Blox Fruits PvP Fruit Tier List (Community Consensus)

| Tier | Fruits | Why |
|------|--------|-----|
| **S** | Kitsune, Dragon (awakened), Dough (awakened), Portal | Combos, mobility, Instinct break, range |
| **A** | Buddha (awakened), Dark (awakened), Ice (awakened), Spider, Spirit, Leopard | Strong combos, good utility |
| **B** | Magma (awakened), Flame (awakened), Light, Quake, Control | Solid but counterable |
| **C** | Bomb, Spring, Chop, Spike, Smoke | Niche or outclassed |

- *Source*: https://blox-fruits.fandom.com/wiki/Blox_Fruits_Wiki (community tier votes)

### 4.2 Blox Fruits Fighting Style Tier List (PvP)

| Tier | Style | Key Strength |
|------|-------|-------------|
| **S** | Sanguine Art, Godhuman | Best combo starters, high damage, Instinct break |
| **A** | Electric Claw, Dragon Talon, Sharkman Karate | Fast, good range, combo extenders |
| **B** | Superhuman, Death Step | Solid all-rounders |
| **C** | Dark Step, Electric, Water Kung Fu | Early-game; outclassed late |
| **D** | Combat (base) | Worst style — only 2 moves, no combo potential |

- *Source*: https://blox-fruits.fandom.com/wiki/Combat

### 4.3 Deepwoken Build Archetypes (PvP)

| Archetype | Core | Strength | Weakness |
|-----------|------|----------|----------|
| **Lght / Dagger** | Agility + Lght (Galebreathe) | Speed, chip damage, feint-heavy | Low HP, punished on mistakes |
| **Heavy / Flamecharm** | Heavy weapon + Flamecharm | Burst damage, posture break | Slow, predictable |
| **Medium / Shadowcast** | Medium weapon + Shadowcast | Balanced, mixup potential | Jack of all trades, master of none |
| **Tank / Ironsing** | Heavy armor + Ironsing | Armor stacking, sustain | Low mobility, out-playable |
| **Glass Cannon / Thundercall** | Low HP + Thundercall | One-combo potential | Dies to one mistake |

- *Source*: https://deepwoken.fandom.com/wiki/Combat_Mechanics, https://deepwoken.co (build planner)

### 4.4 Grand Piece Online PvP Tier List

| Tier | Build | Notes |
|------|-------|-------|
| **S** | Magu Magu (Logia) + Black Leg + Haki V2 | Best fruit + best style + Haki = dominant |
| **S** | Goro Goro (Logia) + Rokushiki + Haki V2 | Lightning range + mobility + observation |
| **A** | Pika Pika, Mera Mera, Gura Gura | Strong Logia/Paramecia with good kits |
| **A** | Yami Yami + Sword build | Blackbeard fruit — unique gravity pull |
| **B** | Gomu Gomu, Bomu Bomu, Kilo Kilo | Viable but outclassed |
| **C** | Spin Spin, Kilo Kilo, Spring Spring | Low-tier fruits |

- *Source*: https://grand-piece-online.fandom.com/wiki/Devil_Fruits

### 4.5 Shindo Life PvP Bloodline Tier Structure

| Tier | Examples | Why |
|------|----------|-----|
| **S** | Bankai Akuma, Shindai Akuma, Ashen Storm | Best combo starters, high damage, modes |
| **A** | Ryuji Kenichi, Dio Senko, Satori Akuma | Strong kits with good sub-ability synergy |
| **B** | Shiver Akuma, Kaijin, Ghost Korashi | Solid but predictable |
| **C** | Common bloodlines, starter elements | Strictly outclassed |

- *Source*: https://shindo-life-rell.fandom.com/wiki/Bloodline

---

## 5. Skill vs Stats Analysis

### 5.1 Skill-Stat Ratio by Game

| Game | Skill Weight | Stats Weight | Can Low-Level Beat High-Level? |
|------|:-----------:|:------------:|:-----------------------------:|
| **Deepwoken** | **80%** | 20% | Yes — parry/feint mastery beats raw stats |
| **Blox Fruits** | 30% | **70%** | Rarely — bounty buffs + level advantage too strong |
| **Grand Piece Online** | 40% | **60%** | Sometimes — Logia intangibility creates hard counters |
| **King Legacy** | 25% | **75%** | Very rarely — linear stat scaling |
| **Shindo Life** | 35% | **65%** | Rare — bloodline rarity = power ceiling |

### 5.2 Skill Expression Mechanics

The more of these a game implements, the higher the skill ceiling:

| Mechanic | Skill Impact | Games Using It |
|----------|:------------:|----------------|
| **Parry / Perfect Block** | Very High | Deepwoken |
| **Feint / Cancel** | Very High | Deepwoken |
| **Instinct Trick / Dodge Timing** | High | Blox Fruits, GPO |
| **Combo Sequencing** | High | All games |
| **End-Lag Punishment** | Medium | Blox Fruits |
| **Positioning / Spacing** | Medium | Deepwoken, GPO |
| **Build Counter-Picking** | Medium | GPO, Blox Fruits |
| **Cooldown Tracking** | Medium | Shindo Life |
| **Resource Management (Tempo/Ether)** | Medium | Deepwoken |

### 5.3 Recommendations for Skill-Stat Balance

1. **Implement at least 2 high-skill mechanics** (parry + feint recommended)
2. **Use stat normalization in ranked modes** — keep raw stats in open world
3. **Create "outplay potential"** — a skilled player should beat a higher-stat player ~30-40% of the time
4. **Avoid one-shot combos** — if a combo kills from full HP with no counterplay, the skill ceiling is effectively zero for the victim
5. **Add escape mechanics** — every player needs at least one "get off me" tool (Deepwoken's Vent, Blox Fruits' Flash Step)

---

## 6. Ranking & Leaderboard Systems

### 6.1 Ranking System Design

| Component | Blox Fruits Approach | Recommended Approach |
|-----------|---------------------|---------------------|
| **Rating System** | Bounty/Honor (flat accumulation) | **Elo/Glicko-2** (win/loss based) |
| **Tiers** | None (raw number) | **Bronze → Silver → Gold → Diamond → Master → Legend** |
| **Decay** | None | **Yes** — inactive players lose rating slowly |
| **Seasons** | None | **Yes** — 4-6 week seasons with reset |
| **Display** | Bounty number above head | **Tier badge + number** |

### 6.2 Recommended Ranking Tiers

| Tier | Rating Range | % of Players | Rewards |
|------|-------------|:------------:|---------|
| Bronze | 0-999 | 40% | Basic PvP currency |
| Silver | 1000-1499 | 25% | + title |
| Gold | 1500-1999 | 18% | + exclusive accessory |
| Platinum | 2000-2499 | 10% | + weapon skin |
| Diamond | 2500-2999 | 5% | + aura effect |
| Master | 3000+ | 1.5% | + exclusive mount/pet |
| Legend | Top 100 | 0.5% | + leaderboard display + unique title |

### 6.3 Leaderboard Types

| Type | Tracks | Display |
|------|--------|---------|
| **Global PvP Rating** | Top players by Elo | Persistent board in hub area |
| **Seasonal Wins** | Most wins this season | Resets each season |
| **Win Streak** | Current consecutive wins | Highlights active hot streaks |
| **Kill Leader** | Most PvP kills (open world) | Real-time server broadcast |
| **Bounty Board** | Highest bounty players | Server-wide — marks them as targets |

---

## 7. PvP Reward Structure

### 7.1 Reward Types

| Reward Type | Source | Purpose |
|-------------|--------|---------|
| **PvP Currency** (e.g., "Valor Points") | Arena wins, bounty kills | Spend on PvP-exclusive items |
| **Bounty/Honor** | Open world kills | Progression stat + damage buffs |
| **Ranked Points** | Ranked arena wins | Tier advancement |
| **Titles** | Achievements (kill count, win streak, tier) | Cosmetic prestige |
| **Weapon Skins** | Seasonal rank rewards | Visual distinction |
| **Aura Effects** | High-tier rank rewards | Status symbol |
| **Exclusive Accessories** | Tournament wins, seasonal top % | Rare collectibles |
| **XP/Currency Boosts** | Win streaks | Accelerate PvE progress |

### 7.2 PvP Shop Items

| Item Category | Examples | Currency Cost |
|--------------|----------|:-------------:|
| Weapon Skins | Glowing sword trails, elemental effects | 500-2000 VP |
| Accessories | PvP-themed hats, capes, auras | 1000-5000 VP |
| Titles | "Undefeated", "Bounty Hunter", "Duelist" | 200-1000 VP |
| Emotes | Victory poses, taunts | 100-500 VP |
| Consumables | Temporary XP/currency boosters | 300-800 VP |
| Enchantments | PvP-specific weapon upgrades | 2000-10000 VP |

### 7.3 Blox Fruits Bounty/Honor Progression (Reference)

| Bounty Threshold | Reward |
|-----------------|--------|
| 500,000 | First damage/defense buff tier |
| 1,000,000 | Second buff tier |
| 2,500,000 | "Bounty at Risk" system activates |
| 5,000,000 | Notable PvP status |
| 10,000,000 | Sea Beast summon unlocked |
| 20,000,000 | High-tier PvP player |
| 30,000,000 | Max buff tier — significant damage/defense increase |

- *Source*: https://blox-fruits.fandom.com/wiki/PvP_mechanics

---

## 8. Anti-Cheat & Fair Play

### 8.1 Common Exploits in Roblox PvP

| Exploit Type | Description | Detection Method |
|-------------|-------------|-----------------|
| **Speed Hacks** | Player moves faster than intended | Server-side velocity validation |
| **Damage Hacks** | Modified damage values | Server-authoritative damage calculation |
| **Auto-Parry/Auto-Dodge** | Scripted perfect defense | Timing analysis — impossibly consistent reactions |
| **Combo Macros** | Pre-programmed combo execution | Input pattern detection — too-fast, too-consistent |
| **Teleport Hacks** | Instant position changes | Server-side position reconciliation |
| **Infinite Stamina/Ether** | No resource depletion | Server-side resource validation |
| **Hitbox Expansion** | Larger attack hitboxes | Server-side hitbox validation |

### 8.2 Anti-Cheat Strategies by Game

| Strategy | Description | Used By |
|----------|-------------|---------|
| **"Suspicious Kill" Detection** | Flag kills where attacker took 0 damage + M1-only | Blox Fruits |
| **Server-Authoritative Combat** | All damage calc on server, not client | Deepwoken |
| **Combat Logging Penalty** | Leaving during PvP = bounty loss | Blox Fruits |
| **Input Rate Limiting** | Cap actions per second | Shindo Life (Global Cooldown) |
| **Post-Game Replay Validation** | Analyze match data for anomalies | Recommended |

### 8.3 Recommended Anti-Cheat Stack

1. **Server-authoritative damage** — never trust the client for damage values
2. **Input rate limiting** — cap actions per second based on ability cooldowns
3. **Velocity validation** — flag players exceeding max movement speed
4. **Statistical anomaly detection** — flag impossibly high win rates, reaction times, or damage output
5. **Player reporting system** — community-assisted moderation
6. **Replay recording** — save last N matches for review
7. **"Suspicious Kill" flags** — Blox Fruits' approach of denying rewards for M1-only 0-damage-taken kills is elegant

---

## 9. Community Pain Points & Solutions

### 9.1 Top PvP Complaints Across Roblox RPGs

| Complaint | Frequency | Games Affected | Solution |
|-----------|:---------:|----------------|----------|
| **"X fruit/weapon is broken"** | Very High | All | Regular balance patches; community feedback channels |
| **"Combos are too long / one-shot combos"** | High | Blox Fruits, Shindo Life | Combo breaker mechanics; max stun duration caps |
| **"Level/gear gap is too large"** | High | Blox Fruits, King Legacy | Stat normalization in arena; level brackets |
| **"Exploiters ruin PvP"** | High | All | Anti-cheat investment; server-authoritative combat |
| **"Lag determines the winner"** | High | All | Favor the defender on ping disputes; prediction netcode |
| **"No reason to PvP"** | Medium | Deepwoken, GPO | Reward systems; PvP-exclusive cosmetics |
| **"Safe zone abuse"** | Medium | Blox Fruits | Extend combat tag duration; prevent safe-zone entry while in combat |
| **"Spam builds take no skill"** | Medium | Blox Fruits, Shindo Life | End-lag; global cooldowns; cooldown increase on repeat use |

### 9.2 Meta Health Indicators

A healthy PvP meta should have:
- **At least 5-8 viable builds** in top-tier play
- **No single build winning >15%** of tournament matches
- **Rock-paper-scissors dynamics** — every S-tier build should have at least one hard counter
- **Skill expression** — the best player should beat a meta-slave ~40% of the time even with a weaker build
- **Regular rotation** — meta should shift every 4-6 weeks through balance patches or new content

---

## 10. Recommended Sword RPG PvP Template

### 10.1 Core PvP Modes (Priority Order)

```
MUST HAVE:
├── 1. Open World PvP (toggle, safe zones, combat tag)
├── 2. Arena (1v1, ranked + unranked, MMR matchmaking)
├── 3. Bounty System (accumulating PvP score, buffs at thresholds)

SHOULD HAVE:
├── 4. Team Arena (2v2, 3v3)
├── 5. Faction Wars (Pirate vs Marine / Guild vs Guild)
├── 6. Tournament Mode (bracket elimination, scheduled events)

NICE TO HAVE:
├── 7. Battle Royale (last-man-standing, queue-based)
├── 8. Conquest Mode (territory control)
└── 9. Bounty Hunting Contracts (targeted player bounties)
```

### 10.2 Combat Mechanics Stack

```
DEFENSE:
├── Block (hold to reduce damage; builds posture)
├── Parry (frame-perfect; negates damage + restores posture)
├── Dodge (I-frames, cooldown-gated)
└── Escape Tool (Vent / Flash Step / Break-Free — one "get off me" per combo)

OFFENSE:
├── M1 Attacks (basic melee chain, 3-4 hits)
├── Weapon Skills (2-4 per weapon, cooldown-gated)
├── Fruit/Element Abilities (3-4 per fruit, varied cooldowns)
├── Fighting Style Moves (2-3 per style)
├── Critical Attack (weapon-specific heavy, long cooldown)
└── Ultimate / Awakening (transformation, long cooldown, high impact)

SYSTEMS:
├── Posture (blocking too much = guard break)
├── Stun Types (Soft → Medium → Hard; chain limits)
├── End-Lag (punish window after abilities)
├── Cooldowns (per-ability + optional global cooldown)
├── Resource (Ether/Chi/Mana for abilities)
└── Tempo / Momentum (builds from combat; enables escape tools)
```

### 10.3 Balance Levers (Priority Tuning)

| Lever | When to Adjust | Impact |
|-------|---------------|--------|
| **Ability Cooldowns** | Ability is too spammy | Low risk, immediate effect |
| **Damage Values** | Ability kills too fast | Low risk, test thoroughly |
| **Stun Duration** | Combo locks players too long | Medium risk, affects combo meta |
| **Hitbox Size** | Ability hits when it shouldn't | Medium risk, affects feel |
| **End-Lag** | Ability has no punish window | Medium risk |
| **New Counter** | Build has no counterplay | High risk, but creates depth |
| **Mechanic Rework** | System fundamentally broken | Last resort |

### 10.4 Ranking System Specification

```yaml
Rating System: Modified Elo (K-factor 32 for new players, 16 after 50 games)
Tiers:
  - Bronze:    0-999    (participation rewards)
  - Silver:    1000-1499 (basic cosmetics)
  - Gold:      1500-1999 (accessory reward)
  - Platinum:  2000-2499 (weapon skin)
  - Diamond:   2500-2999 (aura effect)
  - Master:    3000+     (exclusive mount)
  - Legend:    Top 100   (leaderboard + unique title)

Seasons: 4-week cycles with soft reset (carry 50% of rating)
Placement: 5 placement games to seed initial rating

Anti-Smurf: Win-streak detection accelerates rating gain
Duo Queue: Allowed in 2v2; separate rating from solo
```

### 10.5 Reward Structure

```
PER MATCH:
├── Win:  +50 PvP Currency + Elo gain
├── Loss: +10 PvP Currency (consolation) + Elo loss
└── Draw: +25 PvP Currency (no Elo change)

PER BOUNTY KILL (Open World):
├── Same-level kill: +100 PvP Currency + Bounty points
├── Higher-level kill: +200 PvP Currency + bonus Bounty
└── Lower-level kill: +25 PvP Currency (reduced to prevent farming)

SEASONAL:
├── Tier Rewards: Cosmetic items at season end based on highest tier
├── Top 100 Rewards: Exclusive title + weapon skin
├── Participation: Minimum 20 games for seasonal rewards (prevents camping)
└── Win Streak Bonus: 3+ wins = +25% PvP Currency per win
```

### 10.6 Anti-Cheat Priority

```
CRITICAL (implement before launch):
├── Server-authoritative damage calculation
├── Input rate limiting (max actions/second)
├── Velocity validation (flag speed hacks)
├── Combat logging penalty (bounty loss on disconnect)

HIGH (implement within first month):
├── Statistical anomaly detection
├── "Suspicious Kill" flagging (M1-only, 0 damage taken)
├── Player reporting system

MEDIUM (ongoing):
├── Replay recording for review
├── Auto-parry timing analysis
├── Periodic ban waves
└── Community moderator tools
```

---

## 11. Sources

### Game Wikis

| Game | Wiki URL |
|------|----------|
| Blox Fruits | https://blox-fruits.fandom.com/wiki/Blox_Fruits_Wiki |
| Blox Fruits PvP Mechanics | https://blox-fruits.fandom.com/wiki/PvP_mechanics |
| Blox Fruits Combat (Fighting Style) | https://blox-fruits.fandom.com/wiki/Combat |
| Blox Fruits Fighting Styles | https://blox-fruits.fandom.com/wiki/Fighting_Styles |
| Deepwoken | https://deepwoken.fandom.com/wiki/Deepwoken_Wiki |
| Deepwoken Combat Mechanics | https://deepwoken.fandom.com/wiki/Combat_Mechanics |
| Grand Piece Online | https://grand-piece-online.fandom.com/wiki/Grand_Piece_Online_Wiki |
| Grand Piece Online Arena | https://grand-piece-online.fandom.com/wiki/Arena |
| Grand Piece Online Gamemodes | https://grand-piece-online.fandom.com/wiki/Gamemodes |
| King Legacy | https://king-legacy-official.fandom.com/wiki/King_Legacy_Wiki |
| Shindo Life | https://shindo-life-rell.fandom.com/wiki/Shindo_Life_Wiki |
| Shindo Life Game Modes | https://shindo-life-rell.fandom.com/wiki/Game_Modes |
| Shindo Life Bloodlines | https://shindo-life-rell.fandom.com/wiki/Bloodline |

### Roblox Game Links

| Game | Roblox URL |
|------|-----------|
| Blox Fruits | https://www.roblox.com/games/2753915549 |
| Grand Piece Online | https://www.roblox.com/games/1730877806 |
| Shindo Life | https://www.roblox.com/games/4616652839 |

### External Tools

| Resource | URL |
|----------|-----|
| Deepwoken Build Planner | https://deepwoken.co |
| Deepwoken Builder | https://deepwoken.co/builder |

---

> **Document Purpose**: This template provides a data-driven PvP design framework for Roblox sword RPG games. All tier lists reflect community consensus as of 2024-2026 and will shift with balance patches. Use the recommended template in Section 10 as a starting architecture, and the balance levers in Section 3 for ongoing tuning.
