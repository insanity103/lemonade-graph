# Boss & PvE Design Reference — Sword RPG (Roblox)

> Compiled from live wiki data of Blox Fruits, King Legacy, Deepwoken, and game-design theory.  
> Last updated: 2026-09-11

---

## Table of Contents

1. [Industry Overview](#1-industry-overview)
2. [Boss Encounter Design](#2-boss-encounter-design)
3. [Boss Scaling](#3-boss-scaling)
4. [Loot & Rewards](#4-loot--rewards)
5. [Raid/Siege Systems](#5-raidsiege-systems)
6. [Mob Grinding Design](#6-mob-grinding-design)
7. [Anti-Farm Mechanics](#7-anti-farm-mechanics)
8. [Boss Design Template (Recommended)](#8-boss-design-template-recommended)
9. [Sources](#9-sources)

---

## 1. Industry Overview

Roblox sword RPGs (Blox Fruits, King Legacy, Grand Piece Online, Deepwoken, Shindo Life) share a common PvE skeleton: players grind mobs to level up, fight named bosses for unique drops, and engage in raids/dungeons for endgame progression. Bosses are the **primary content gate** — they reward exclusive weapons, accessories, materials, and large XP/currency payouts that mobs cannot match.

**Key design patterns observed across top Roblox RPGs:**

| Pattern | Blox Fruits | King Legacy | Deepwoken |
|---------|------------|-------------|-----------|
| Total bosses | 34+ regular + raid bosses | 20+ regular + 7 raid bosses | 10+ bosses + 5 world bosses + 20+ mini-bosses |
| Boss HP range | 5K–200K (regular), 155K+ (raid) | 10K–7.5M (raid) | Varies (souls-like, no fixed HP numbers on wiki) |
| Attack patterns per boss | 2–4 abilities (uses fruit/weapon moves) | 2–5 abilities (mimics player fruit moves) | 3–6 unique attack strings with phases |
| Phases | Rare (mainly event bosses like Tormented) | Chopper has 5 forms; most are single-phase | Multiple phases on major bosses (Chaser, Ethiron) |
| Instanced vs World | World bosses (respawn timer 20–45 min) | World bosses + Golden Arena (instanced wave) | World bosses + instanced boss rooms |
| Group scaling | Bosses have fixed HP regardless of group | Raid bosses have fixed HP, rewards split | World bosses tuned for groups |

---

## 2. Boss Encounter Design

### 2.1 HP Values Across Game Stages

| Game Stage | Blox Fruits HP Range | King Legacy HP Range | Recommended for Sword RPG |
|------------|---------------------|---------------------|--------------------------|
| **Early (Lv. 1–500)** | 5,000–15,000 | 5,000–20,000 | 8,000–25,000 |
| **Mid (Lv. 500–2000)** | 15,000–50,000 | 20,000–100,000 | 25,000–100,000 |
| **Late (Lv. 2000–5000)** | 50,000–120,000 | 100,000–500,000 | 100,000–500,000 |
| **Endgame (Lv. 5000+)** | 120,000–200,000 | 500,000–7,500,000 | 500,000–2,000,000 |
| **Raid Boss** | 155,500 | 250,000–7,500,000 | 1,000,000–5,000,000 |
| **World Boss** | N/A (uses regular) | 1,000,000 (Dragon) | 2,000,000–10,000,000 |

> **Source:** Blox Fruits wiki — Raid Boss has exactly 155,500 HP. King Legacy — Dragon (Kaido) has 1M HP; Big Mom has 7.5M HP. Tormented bosses in Blox Fruits have fixed 200,000 HP regardless of base boss.

### 2.2 Attack Patterns Per Boss

| Boss Tier | Attack Count | Examples |
|-----------|-------------|----------|
| **Mini-Boss** | 1–2 | King Legacy's King Man: 1 massive AoE punch (14K dmg). Blox Fruits' Gorilla King: M1 + 1 ability. |
| **Standard Boss** | 2–3 | King Legacy's Shark Man: Tornado Slash + Shark Style (teleport ground pound). Blox Fruits' bosses use 2 fruit abilities + M1. |
| **Raid Boss** | 3–4 | Blox Fruits raid bosses use awakened fruit Z, X, and V moves. King Legacy's Expert Swordsman: Holy Sword + horizontal slash projectile. |
| **World Boss** | 4–6 | Deepwoken's Primadon: slam, charge, ranged projectiles, AoE patterns. King Legacy's Big Mom: multiple fruit abilities. |

### 2.3 Attack Telegraphing Methods

| Method | Game | Description |
|--------|------|-------------|
| **Red circle indicator** | King Legacy | King Man flares up before punching; red circle appears on ground before AoE. Drill Headman shows dash wind-up. |
| **Animation wind-up** | All games | Expert Swordsman raises sword before Holy Sword. Bosses telegraph projectile attacks with distinct casting animations. |
| **Chat announcement** | King Legacy | "A mysterious swordsman has visited the sea…!" (dark red text) when Expert Swordsman spawns. |
| **Visual aura/color** | Blox Fruits | Tormented bosses have a red cloud above them. Pain Event bosses are visually identifiable. |
| **Stun before big hit** | King Legacy | Drill Headman uses Conqueror's Haki (3-second stun) at close range before dashing — players must maintain distance. |
| **Camera zoom out** | Deepwoken | Entering a boss combat tag allows the camera to zoom out farther, giving players more spatial awareness. |

### 2.4 Phase Systems

| Game | Phase Design | Details |
|------|-------------|---------|
| **Blox Fruits** | Mostly single-phase | Tormented bosses "revive" after initial defeat with 200K HP and Pain fruit abilities — effectively a phase 2. |
| **King Legacy** | Multi-form bosses | Chopper/Little Dear has **5 different forms** — the only multi-phase standard boss. Raid bosses are generally single-phase. |
| **Deepwoken** | True phases | Major bosses (Chaser, Ethiron, Scion) have distinct attack pattern shifts at HP thresholds. Kyrsgarde Champion has escalating difficulty. |

### 2.5 Add Spawns (Minion Summons)

| Game | Add Spawn Design |
|------|-----------------|
| **Blox Fruits** | Raid system: 5 islands with mob waves before the raid boss on island 5. Regular bosses do **not** summon adds. |
| **King Legacy** | Golden Arena: wave-based (5, 10, 15, 19, 20, 25, 30) with multiple bosses spawning simultaneously on some waves (e.g., Green Hair Man + King Man on wave 15). |
| **Deepwoken** | Some bosses summon environmental threats or additional enemies. Mudskipper Broodlord spawns mudskipper minions. |

### 2.6 Environmental Hazards

| Game | Hazard Type |
|------|------------|
| **Blox Fruits** | Flame Raid has **lava** that deals massive damage on contact (Magma users are immune). Ice Raid has freezing terrain effects. Dark Raid has cave environments that restrict dragon transformation. |
| **King Legacy** | Golden Arena has enclosed arena space. Raid bosses are fought in fixed locations with environmental features. |
| **Deepwoken** | The Depths (Scyphozia, Eternal Gale) have environmental hazards during boss encounters. Voidzones combine environmental danger with boss fights. |

---

## 3. Boss Scaling

### 3.1 Level Scaling

| Game | Scaling Approach |
|------|-----------------|
| **Blox Fruits** | **Fixed levels.** Each boss has a preset level (displayed as "Lv. ????"). Bosses have fixed HP and damage. Players must reach a sufficient level to deal meaningful damage. Elemental immunity is bypassed by bosses. |
| **King Legacy** | **Fixed levels.** Normal bosses range from Lv. 20 (Smoker) to Lv. 1400 (Leo). Raid bosses are Lv. 3000–10000. No dynamic scaling. |
| **Deepwoken** | **Fixed difficulty per location.** Boss difficulty is tied to the area (Etrean Luminant = easier, The Depths = harder). No level scaling, but player build variety creates organic difficulty curves. |

### 3.2 Difficulty Tiers

| Game | Tier System |
|------|------------|
| **Blox Fruits** | Regular → Raid Boss → Awakened Boss (Island Secrets, Update 30). Tormented bosses are event-enhanced versions of regular bosses with 200K fixed HP + Pain fruit. |
| **King Legacy** | Normal Boss → Raid Boss → Golden Arena (wave-based difficulty). Easy vs Normal Golden Arena tiers. |
| **Deepwoken** | Mini-Boss → Boss → World Boss. World bosses require multiple players and give double Resonance progression + Knowledge + Crowns. |

### 3.3 Group vs Solo Design

| Game | Group Mechanics |
|------|----------------|
| **Blox Fruits** | Most bosses are soloable at appropriate level. Raids allow up to **4 players**. Boss HP does not scale with group size. All players in range get credit. |
| **King Legacy** | Raid bosses designed for groups. Expert Swordsman: "very difficult to defeat without help." Rewards are **split between participants** based on damage dealt. Dragon (Kaido, 1M HP): "recommended to fight with multiple people." |
| **Deepwoken** | World bosses explicitly "may require multiple people." Solo bosses exist (Duke, Maestro, Ferryman). Group content (Primadon, Elder Primadon, Ethiron) requires coordination. |

### 3.4 World Boss vs Instanced Boss

| Type | Description | Examples |
|------|-------------|----------|
| **World Boss** | Spawns in the open world on a timer. Any player can engage. Competitive (multiple players fighting for credit). | Blox Fruits: all 34 bosses (respawn 20–45 min). King Legacy: Expert Swordsman (30-min despawn timer). |
| **Instanced Boss** | Requires entry condition (microchip, key, summoning item). Limited player count. Guaranteed private encounter. | Blox Fruits Raids (4-player cap). King Legacy Golden Arena (wave-based). Deepwoken: boss rooms in The Depths. |
| **Summoned Boss** | Player-triggered spawn via item/quest. World-visible announcement. | King Legacy Dragon: summoned with Dragon Gem (1% drop from Elite Skeleton) placed in skull. |

---

## 4. Loot & Rewards

### 4.1 Drop Types

| Drop Category | Blox Fruits | King Legacy | Deepwoken |
|---------------|------------|-------------|-----------|
| **Weapons (Swords)** | Swords, Guns (boss-specific) | Tashi's Blade, Shark Blade, Gold Spear, Saber, Hell Sword, Phoenix Blade | Purple Cloud, Dissonant Chimecaller, Frostthorn |
| **Accessories** | Accessories (boss-specific) | Horned Hat, Stainless Jaw, Flame Hair | Equipment, Enchantments |
| **Materials** | Materials (boss-specific) | Leather | Pluripotent Alloy, Ores |
| **Currency** | Money (scaled by sea: 165K/170K/247.5K for all bosses) | Beli (500K–750K from raids) | Crowns |
| **XP/Levels** | EXP + Bounty/Honor | EXP (1M–25M from raids) | Experience + Knowledge |
| **Special Currency** | Fragments (300–1,000 per raid, time-based) | Gems (5 from Dragon, 5 from Big Mom) | Echoes, Resonance Progress |
| **Titles** | 23+ raid-related titles | — | — |

### 4.2 Drop Rate Analysis

| Item | Drop Rate | Game | Boss |
|------|-----------|------|------|
| Jitter (Smoke fruit item) | RNG (low) | King Legacy | Smoker (Lv. 20) |
| Tashi's Blade | RNG | King Legacy | Tashi (Lv. 30) |
| Shark Blade | RNG | King Legacy | Shark Man (Lv. 230) |
| Big Mom's Sword | **15%** | King Legacy | Oars (Raid Boss) |
| Shanks Saber | **15%** | King Legacy | Expert Swordsman |
| Hell Sword | **50%** | King Legacy | King Samurai (Oden) |
| Phoenix Blade | **1%** | King Legacy | Big Mom |
| Authentic Mace | **10%** | King Legacy | Dragon (Kaido) |
| Pumpkin Smasher | **1%** | King Legacy | Jack o Lantern |
| Xmas Blade | ~15% (est.) | King Legacy | Santa |

> **Pattern:** Raid-exclusive weapons range from 1% (rarest, endgame) to 50% (mid-tier raids). Standard boss drops are generally 100% or near-100%.

### 4.3 Guaranteed vs RNG Drops

| Game | Guaranteed | RNG |
|------|-----------|-----|
| **Blox Fruits** | Money + EXP always. Bounty/Honor always. | Specific weapon/accessory/material drops vary. |
| **King Legacy** | EXP + Beli from raids (100%). All normal bosses have fixed EXP/Beli. | Weapon drops: 1%–50% chance. Materials (Leather) from Wolf/Giraffe. |
| **Deepwoken** | Knowledge (1–2), Resonance Progress, Echoes, Pluripotent Alloy on boss kill. | Specific weapon drops vary. |

### 4.4 First-Kill Bonuses

| Game | First-Kill System |
|------|------------------|
| **Blox Fruits** | No explicit first-kill bonus. Bounty/Honor caps at 2.5M from NPCs. |
| **King Legacy** | No explicit first-kill bonus, but raid rewards are large one-time payouts. |
| **Deepwoken** | Chain of Perfection system — bosses that grant this qualify as "true bosses." Ardour Manifestation granted on defeat. |

### 4.5 Contribution-Based Loot

| Game | System |
|------|--------|
| **Blox Fruits** | All players in range who deal damage get full loot. No contribution scaling. |
| **King Legacy** | Expert Swordsman: "rewards are split between whoever damages him." Dragon: rewards appear to be granted to all participants. |
| **Deepwoken** | All players who participate in a world boss kill receive rewards. |

---

## 5. Raid/Siege Systems

### 5.1 Blox Fruits Raid Structure

| Property | Value |
|----------|-------|
| **Player cap** | 4 per raid |
| **Structure** | 5 islands, each with mob waves. Must clear all mobs to advance. |
| **Final island** | Raid Boss (155,500 HP) using awakened fruit abilities (Z, X, V) |
| **Regular mob HP** | 7,200–33,750 (scaling across islands) |
| **Entry cost** | 100,000 Money or any physical Blox Fruit (Basic); 1,000 Fragments or fruit worth 1M+ (Advanced) |
| **Reward** | 300–1,000 Fragments (time-based). Awakened fruit moves if matching fruit equipped. |
| **Failure** | Partial Fragments based on how far you got. |
| **Difficulty tiers** | Basic Raids (11 themes) + Advanced Raids (Phoenix, Dough — harder, better rewards) |
| **Environmental variety** | Each raid has unique terrain (lava, ice, caves, pyramids) |

### 5.2 King Legacy Golden Arena

| Property | Value |
|----------|-------|
| **Structure** | Wave-based (30 waves) with bosses at waves 5, 10, 15, 19, 20, 25, 30 |
| **Boss damage** | Escalating: 1,000 (wave 5) → 5,000 (wave 10) → 14,000 (wave 15) → 16,000 (wave 20) |
| **Multi-boss waves** | Wave 15: Green Hair Man + King Man simultaneously |
| **Tiers** | Easy + Normal difficulty variants |
| **Strategy elements** | Players can trap normal-sized bosses. King Man can damage Green Hair Man (boss-vs-boss exploitation). |

### 5.3 Deepwoken Boss Encounters

| Property | Value |
|----------|-------|
| **Solo bosses** | Duke Ishamon, Maestro Evengarde Rest, The Ferryman, Chaser |
| **Group world bosses** | Primadon, Elder Primadon, Doom of Caeranthil, Heart of Enmity, Scion of Ethiron |
| **Rewards** | Unique weapons, Knowledge (1–2), double Resonance progression, Crowns, Echoes |
| **Death penalty** | Permadeath mechanic — dying in The Depths can lose your character entirely |
| **Difficulty** | Highest among Roblox RPGs — souls-like combat with parrying, dodging, and stamina management |

### 5.4 Recommended Raid Template for Sword RPG

| Component | Recommendation |
|-----------|---------------|
| **Party size** | 4 players (industry standard for Roblox) |
| **Structure** | 3–5 rooms/areas with escalating mob waves |
| **Time limit** | 15–20 minutes (King Legacy Expert Swordsman despawns at 30 min) |
| **Failure condition** | All players downed simultaneously OR time expires |
| **Retry** | Re-enter with same party, mobs reset. Allow checkpoint at last cleared room. |
| **Role requirements** | None enforced (Roblox audience is young; no holy trinity). Allow any build to contribute. |
| **Scaling** | Fixed difficulty per raid tier. Multiple tiers for progression. |

---

## 6. Mob Grinding Design

### 6.1 Regular Mob Design

| Property | Blox Fruits | King Legacy | Deepwoken |
|----------|------------|-------------|-----------|
| **Mob types per zone** | 2–3 enemy types | 1–2 enemy types | 5–10 enemy types (high variety) |
| **Mob abilities** | Basic M1 attacks, some use fruit moves | Basic attacks + occasional abilities | Full combat system (parry, dodge, weapons) |
| **Mob HP** | ~500–5,000 (scaling with area) | ~500–10,000 (scaling with area) | Variable (some die in 2 hits, some are dangerous) |
| **Respawn rate** | Fast (seconds) | Fast (seconds) | Moderate (area-based) |
| **Mob density** | High clusters near quest NPCs | Moderate clusters | Sparse but dangerous |

### 6.2 Zone Progression

| Game | Zone Structure |
|------|---------------|
| **Blox Fruits** | 3 seas (First → Second → Third). Each sea has 8–18 islands with level-appropriate mobs. Level gates: 700+ for Second Sea, 1500+ for Third Sea. |
| **King Legacy** | Linear island progression. Mobs scale from Lv. 1 to Lv. 10,000+. Each island has 1–3 mob types. |
| **Deepwoken** | Non-linear exploration. Etrean Luminant → Eastern Luminant → The Depths. Danger increases non-linearly. |

### 6.3 AFK Farming Prevention

| Game | Anti-AFK Mechanism |
|------|-------------------|
| **Blox Fruits** | Auto-detection of idle players (kicked after inactivity). Mob aggro requires player proximity. |
| **King Legacy** | Similar idle detection. Bosses require active engagement. |
| **Deepwoken** | Permadeath system inherently punishes AFK play. Enemies are aggressive and can kill idle players. |

### 6.4 Mob Variety Across Zones

**Recommended mob types per zone tier:**

| Zone Tier | Mob Types | Example |
|-----------|-----------|---------|
| **Starter** (Lv. 1–100) | Bandits, Wolves, Slimes | 3 types |
| **Early** (Lv. 100–500) | Pirates, Soldiers, Beasts | 3–4 types |
| **Mid** (Lv. 500–2000) | Elite soldiers, Elemental creatures, Rogue warriors | 4–5 types |
| **Late** (Lv. 2000–5000) | Demon soldiers, Corrupted knights, Sea creatures | 4–5 types |
| **Endgame** (Lv. 5000+) | Ancient beasts, Elite commanders, Void entities | 5–6 types |

---

## 7. Anti-Farm Mechanics

### 7.1 Observed Mechanisms

| Mechanism | Game | Details |
|-----------|------|---------|
| **Level-based diminishing returns** | Blox Fruits | Bounty/Honor caps at 2.5M from NPCs — after that, must PvP for more. |
| **Despawn timers** | King Legacy | Expert Swordsman despawns after 30 minutes. Forces engagement window. |
| **Respawn timers** | Blox Fruits | Bosses respawn every 20–45 minutes. Cannot be farmed continuously. |
| **Rare drop rates** | King Legacy | 1% drop rate (Phoenix Blade, Pumpkin Smasher) ensures long farming sessions. |
| **Entry costs** | Blox Fruits | Raids cost 100K Money or a physical fruit. Creates currency sink. |
| **Permadeath** | Deepwoken | Ultimate anti-farm — dying means losing your character. Forces careful play. |
| **Contribution splitting** | King Legacy | Raid rewards split by damage dealt — leeching gets reduced rewards. |

### 7.2 Recommended Anti-Farm Systems for Sword RPG

| System | Implementation |
|--------|---------------|
| **Level differential penalty** | If player level > mob level + 50, reduce XP by 50%. If > mob + 100, XP = 0. |
| **Diminishing returns** | First 10 kills of same mob: 100% XP. 11–30: 75%. 31–50: 50%. 51+: 25%. Reset daily. |
| **Boss cooldown** | 20–30 minute respawn timer. Display timer to players (like Blox Fruits' boss timer). |
| **Daily boss kill limit** | 3–5 kills per boss per day for full rewards. After that, reduced drops. |
| **Loot lockout** | After receiving a rare drop, 24-hour lockout before that specific drop can drop again. |
| **Entry cost** | Raids require a crafted key or currency (gold sink). Prevents spam. |
| **AFK detection** | If no player input for 2 minutes, stop XP/drop generation. Kick at 5 minutes. |

---

## 8. Boss Design Template (Recommended)

### 8.1 HP Curve by Level

| Boss Level | Solo HP | Group HP (×1.5 per player, max 4) | HP per Player (group) |
|------------|--------|-----------------------------------|----------------------|
| 50 | 10,000 | 15,000 | 3,750 |
| 100 | 20,000 | 30,000 | 7,500 |
| 250 | 45,000 | 67,500 | 16,875 |
| 500 | 80,000 | 120,000 | 30,000 |
| 750 | 120,000 | 180,000 | 45,000 |
| 1000 | 175,000 | 262,500 | 65,625 |
| 1500 | 250,000 | 375,000 | 93,750 |
| 2000 | 400,000 | 600,000 | 150,000 |
| 3000 | 600,000 | 900,000 | 225,000 |
| 5000 | 1,000,000 | 1,500,000 | 375,000 |
| 7500 | 1,500,000 | 2,250,000 | 562,500 |
| 10000 | 2,500,000 | 3,750,000 | 937,500 |

> **Formula:** `SoloHP = Level × 200 + 5000` (clamped minimum). Group HP applies a 1.5× multiplier per additional player.

### 8.2 Attack Pattern Count by Tier

| Boss Tier | Attack Count | Pattern Types | Cooldown Between Attacks |
|-----------|-------------|---------------|-------------------------|
| **Zone Mini-Boss** | 2 | 1 melee combo + 1 ranged/projectile | 3–5 seconds |
| **Zone Boss** | 3 | 1 melee combo + 1 AoE + 1 gap-closer/teleport | 2–4 seconds |
| **Dungeon Boss** | 4 | 1 melee + 1 AoE + 1 ranged + 1 special (stun/grab/knockback) | 1.5–3 seconds |
| **Raid Boss** | 4–5 | 2 melee variants + 1 large AoE + 1 ranged + 1 enrage ability | 1–2.5 seconds |
| **World Boss** | 5–6 | 2 melee + 2 AoE + 1 ranged + 1 summon/add phase | 0.8–2 seconds |

### 8.3 Phase Thresholds

| Boss Tier | Phases | HP Thresholds | Phase Changes |
|-----------|--------|--------------|---------------|
| **Zone Mini-Boss** | 1 | — | None |
| **Zone Boss** | 1–2 | 50% HP | Optional: speed increase or new attack |
| **Dungeon Boss** | 2 | 60% and 30% HP | New attack patterns + visual change |
| **Raid Boss** | 3 | 70%, 40%, 15% HP | New abilities + minion spawns + enrage |
| **World Boss** | 3–4 | 75%, 50%, 25% HP | Full pattern shift + environmental changes |

### 8.4 Phase Design Details

| Phase | Behavior Changes | Visual Indicators |
|-------|-----------------|-------------------|
| **Phase 1 (100%–70%)** | Standard attack patterns. Teaching phase — player learns boss moves. | Normal boss appearance. Standard arena. |
| **Phase 2 (70%–40%)** | +1 new attack. Existing attacks 20% faster. May summon 2–3 adds. | Aura color change. Boss voice line. Arena may change slightly. |
| **Phase 3 (40%–15%)** | +1 new attack. Attacks 40% faster. Enrage timer starts. Environmental hazards activate. | Red/dark aura. Screen shake on big attacks. Music intensifies. |
| **Phase 4 (<15%)** | Desperation phase. All attacks available. Highest damage. Short DPS check window. | Full visual overhaul. Boss model change or size increase. |

### 8.5 Loot Table Template

#### Zone Boss Drops

| Drop | Type | Rate | Notes |
|------|------|------|-------|
| Boss-specific weapon | Sword | 10–20% | Unique to this boss. Not tradeable. |
| Boss material ×1–3 | Crafting material | 100% | Used for upgrades. Always drops. |
| Gold | Currency | 100% | 500–2,000 based on level. |
| XP | Experience | 100% | 10,000–50,000 based on level. |
| Accessory | Equipment | 5–10% | Rare. Unique passive effect. |

#### Dungeon Boss Drops

| Drop | Type | Rate | Notes |
|------|------|------|-------|
| Boss-specific weapon | Sword | 15–25% | Higher rate than zone boss. |
| Boss material ×3–5 | Crafting material | 100% | More materials per kill. |
| Gold | Currency | 100% | 5,000–20,000 based on level. |
| XP | Experience | 100% | 50,000–200,000 based on level. |
| Rare accessory | Equipment | 5–8% | Unique to dungeon bosses. |
| Dungeon key fragment | Key item | 100% | Collect to unlock harder dungeons. |

#### Raid Boss Drops

| Drop | Type | Rate | Notes |
|------|------|------|-------|
| Raid-exclusive weapon | Sword | 1–15% | Rarest tier. Scales with difficulty. |
| Raid material ×5–10 | Crafting material | 100% | For endgame crafting. |
| Gold | Currency | 100% | 50,000–200,000. |
| XP | Experience | 100% | 500,000–5,000,000. |
| Special currency | Fragments/Gems | 100% | For awakening/special systems. |
| Title | Cosmetic | 100% on first clear | Achievement-style reward. |
| Rare accessory | Equipment | 3–5% | Unique raid-only passive. |

#### World Boss Drops

| Drop | Type | Rate | Notes |
|------|------|------|-------|
| World boss weapon | Sword | 1–5% | Extremely rare. Best-in-slot potential. |
| World boss material ×10–20 | Crafting material | 100% | Legendary crafting. |
| Gold | Currency | 100% | 200,000–1,000,000. |
| XP | Experience | 100% | 5,000,000–25,000,000. |
| Unique title | Cosmetic | 100% on first clear | Prestige marker. |
| Mount/pet | Cosmetic/companion | 1–3% | Ultra-rare flex reward. |

### 8.6 Raid Structure Template

```
┌─────────────────────────────────────────────────┐
│                RAID STRUCTURE                     │
├─────────────────────────────────────────────────┤
│                                                  │
│  Room 1: Mob Wave (10–15 enemies)               │
│  ├── Enemy HP: 5,000–10,000                      │
│  ├── Basic attack patterns                       │
│  └── Gate: Clear all to proceed                  │
│                                                  │
│  Room 2: Mob Wave (12–18 enemies)               │
│  ├── Enemy HP: 10,000–15,000                     │
│  ├── Some enemies use abilities                  │
│  └── Gate: Clear all to proceed                  │
│                                                  │
│  Room 3: Mini-Boss + Adds                        │
│  ├── Mini-Boss HP: 50,000                        │
│  ├── 6–8 add enemies (3,000 HP each)             │
│  ├── Mini-Boss has 2 attack patterns             │
│  └── Gate: Defeat mini-boss to proceed           │
│                                                  │
│  Room 4: Elite Wave (8–12 enemies)              │
│  ├── Enemy HP: 15,000–25,000                     │
│  ├── All enemies use abilities                   │
│  ├── Environmental hazard active                 │
│  └── Gate: Clear all to proceed                  │
│                                                  │
│  Room 5: RAID BOSS                               │
│  ├── Boss HP: 1,000,000–2,000,000               │
│  ├── 4–5 attack patterns                         │
│  ├── 3 phases (70%, 40%, 15% HP)                │
│  ├── Phase 2: +2 adds spawn                      │
│  ├── Phase 3: Environmental hazard intensifies   │
│  └── Time limit: 15 minutes                      │
│                                                  │
│  ENTRY COST: 50,000 Gold + Raid Key              │
│  PARTY SIZE: 2–4 players                         │
│  REWARD: Raid loot table (see 8.5)               │
│                                                  │
└─────────────────────────────────────────────────┘
```

### 8.7 Spawn & Respawn Design

| Boss Type | Spawn Method | Respawn Timer | Announcement |
|-----------|-------------|---------------|-------------|
| Zone Boss | Fixed location, always present | 3–5 minutes after defeat | None (ambient) |
| Dungeon Boss | Triggered by entering boss room | Instant on re-entry | Boss intro cutscene/animation |
| Raid Boss | Triggered by raid start | New raid requires new key | System message to party |
| World Boss | Timer-based spawn | 30–60 minutes | Server-wide chat message (like King Legacy's red text) |
| Event Boss | Random spawn chance (hourly) | 1 hour (chance-based) | Server-wide notification |

---

## 9. Sources

| Source | URL | Data Used |
|--------|-----|-----------|
| Blox Fruits Wiki — Bosses | https://bloxfruits.fandom.com/wiki/Bosses | Boss list, HP values, drop mechanics, respawn timers, Tormented bosses (200K HP), bounty cap (2.5M), 34 total bosses |
| Blox Fruits Wiki — Raids | https://bloxfruits.fandom.com/wiki/Raids | Raid structure (5 islands, 4-player cap), raid boss HP (155,500), mob HP ranges (7,200–33,750), Fragment rewards (300–1,000), environmental hazards (lava, ice, caves), entry costs, awakened fruit system |
| King Legacy Wiki — Bosses | https://king-legacy.fandom.com/wiki/Bosses | Normal boss list (Lv. 20–1400), raid boss HP (250K–7.5M), drop rates (1%–50%), Golden Arena wave structure (30 waves), Expert Swordsman mechanics (30-min despawn, 15% Saber drop), Dragon summoning (1% gem drop), reward splitting by damage |
| Deepwoken Wiki — Bosses | https://deepwoken.fandom.com/wiki/Bosses | Boss classification (Chain of Perfection criteria), World Boss rewards (Knowledge, double Resonance, Crowns), boss categories (Boss, World Boss, Mini-Boss), camera zoom mechanic, unique drops (Purple Cloud, Dissonant Chimecaller, Frostthorn) |
| Game Developer (gamedeveloper.com) | https://www.gamedeveloper.com/design | General game design articles and industry patterns (design section) |
| Blox Fruits Wiki — Tips for Bosses | Referenced from Blox Fruits Bosses page | Strategy context and boss behavior notes |

---

## Appendix: Key Design Principles (Cross-Game Analysis)

### What Makes Roblox RPG Bosses Work

1. **Readable telegraphs** — Every attack has a visible wind-up (red circles, animation, aura changes). Young players need clear visual cues.

2. **Mimic-player abilities** — Top games (Blox Fruits, King Legacy) give bosses the same abilities players can use (fruit moves, weapon skills). This makes combat feel fair and learnable.

3. **Guaranteed material drops + RNG weapon drops** — Players always get something useful (materials, XP, currency). The weapon is the chase reward.

4. **Visible respawn timers** — Blox Fruits added boss spawn timers as a QoL feature. Players appreciate knowing when to return.

5. **Server-wide announcements** — World boss spawns announced in chat create urgency and social coordination.

6. **Environmental variety in raids** — Each raid in Blox Fruits has unique terrain (lava, ice, pyramids). This keeps repeated raids feeling different.

7. **Escalating wave structure** — Golden Arena in King Legacy proves wave-based content with boss waves at intervals creates engaging progression.

8. **Group-friendly, not group-required** — Standard bosses should be soloable. Only raids and world bosses should require groups. This respects Roblox's young, often-solo player base.

9. **Boss vs Boss exploitation** — King Legacy's Golden Arena allows King Man to damage Green Hair Man. Smart players love discovering emergent strategies.

10. **Visual prestige drops** — Rare weapons (1–5% drop rate) become status symbols that drive continued play.
