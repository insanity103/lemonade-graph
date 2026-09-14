# Sword RPG Onboarding & FTUE Design Template
## Research-Based Guide for Roblox Anime/Sword RPG Games

> **Scope:** New player onboarding patterns analyzed from Blox Fruits, King Legacy, Grand Piece Online, and official Roblox game design documentation. Designed as a reusable template for sword-RPG FTUE design.

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [First 5 Minutes Analysis](#first-5-minutes-analysis)
3. [First 30 Minutes Analysis](#first-30-minutes-analysis)
4. [First Session (1-2 Hours) Analysis](#first-session-1-2-hours-analysis)
5. [Common Drop-Off Points](#common-drop-off-points)
6. [Onboarding Best Practices](#onboarding-best-practices)
7. [Retention Hooks in First Session](#retention-hooks-in-first-session)
8. [Onboarding Design Template: Minute-by-Minute Flow](#onboarding-design-template-minute-by-minute-flow)
9. [Text Flowcharts](#text-flowcharts)
10. [Timing Tables](#timing-tables)
11. [Source URLs](#source-urls)

---

## Executive Summary

Roblox sword RPG games (Blox Fruits, King Legacy, Grand Piece Online) share a common onboarding pattern: players spawn on a starter island with minimal or no tutorial, receive basic melee combat, and are expected to self-direct through quest-grinding loops. **None of the top games have a forced tutorial.** The FTUE success depends on three pillars: (1) fast first kill, (2) visible progression feedback, and (3) early exposure to aspirational content. The most successful games follow Roblox's official FTUE framework: *Teach the Essentials → Get to the Fun Quickly → Leave Players Wanting More.*

---

## First 5 Minutes Analysis

### What Happens the Moment a Player Joins?

| Game | Spawn Behavior | Tutorial | First Visual Hook |
|------|---------------|----------|-------------------|
| **Blox Fruits** | Player chooses Pirate or Marine team via UI menu, then spawns on respective Starter Island (Pirate Starter / Marine Starter). No cutscene. | **No forced tutorial.** Player is placed directly into the world. | Starter island with windmills, grassy areas, docks. Small safe-zone island. Background music: "Explorer" track. |
| **King Legacy** | Player spawns on Starter Island (level 0+). Character customization happens before spawn. | **No forced tutorial.** Player is dropped into the world. | Starter island with NPCs visible, a Black Market, Gacha machine nearby. |
| **Grand Piece Online** | Player spawns in Town of Beginnings (level 0-10). Character creation with race selection (74% Human, 15% Skypian, 5% Fishman/Mink/Vampire, 1% Cyborg). | **No forced tutorial.** Audio dialogues from NPCs on Town of Beginnings. | Town setting with NPCs, boat dealer, shops. PvP disabled on starter island. |

**Key Finding:** All three games use a "soft start" — no forced tutorial, no cutscene. The player is immediately in control. This is deliberate: Roblox players have extremely low tolerance for tutorial walls and will leave instantly.

### First Action the Player Takes

| Game | First Action | Starter Weapon |
|------|-------------|---------------|
| **Blox Fruits** | Talk to Bandit Quest Giver NPC, accept "Defeat 5 Bandits" quest. Fight with bare fists (Combat fighting style). | Default Combat (melee fists). Swords available for purchase at Sword Dealer on island ($5,000 Katana equivalent). |
| **King Legacy** | Option A: Kill 6 Soldiers quest. Option B: Find 3 Fried Chicken quest. Fight with bare fists. | Default melee. Katana available for $5,000 from NPC. |
| **Grand Piece Online** | Find Necklace quest (collect quest, 5 XP), then Defeat 5 Bandits quest (60 XP, 50 Peli). | Default melee fists. Pistol/Rifle available from Lily NPC on starter island. |

**Design Insight:** The first action is ALWAYS a simple kill quest against weak enemies. This teaches the core loop (Fight → Get Reward → Progress) within 60 seconds of gameplay.

### What Does the Player See First? (Visual Hook)

- **Blox Fruits:** Small, contained starter island. Circular layout with central grassy area. Designed intentionally small "to avoid confusing new players" (wiki trivia). Safe zone — no PvP.
- **King Legacy:** Starter island with visible progression markers: Black Market NPC, Gacha machine, nearby quest NPCs. Multiple currencies visible.
- **Grand Piece Online:** Town of Beginnings with 7 scattered chests to discover. Audio dialogues from NPCs. Has a "Your Adventure awaits..." description. PvP disabled.

---

## First 30 Minutes Analysis

### First Quest Design

| Game | First Quest | Time to Complete | Reward |
|------|------------|-----------------|--------|
| **Blox Fruits** | Defeat 5 Bandits (level 0) | 2-3 minutes | $350 Beli + 300 EXP |
| **King Legacy** | Kill 6 Soldiers (level 0+) | 2-3 minutes | $250 + 540 EXP |
| **Grand Piece Online** | Find Necklace + Defeat 5 Bandits | 3-5 minutes | 5 XP + 25 Peli (necklace), 60 XP + 50 Peli (bandits) |

**Pattern:** First quest takes under 5 minutes. Reward is immediate and tangible. No multi-step quest chains in the first 5 minutes.

### What the Player Learns in the First 30 Minutes

| Learning Moment | Blox Fruits | King Legacy | Grand Piece Online |
|----------------|------------|------------|-------------------|
| **Movement** | WASD + jump (built-in Roblox) | WASD + jump | WASD + double-tap W to run, Q to dash, CTRL to wall climb |
| **Combat** | Click to punch, basic combo | Click to punch | Click to punch, basic combo |
| **Quest System** | Talk to NPC → Accept → Kill enemies → Return for reward | Talk to NPC → Accept → Kill/Collect → Auto-complete | Talk to NPC → Accept → Kill/Collect → Return |
| **Stats** | Stat points gained on level up (Melee, Defense, Fruit, Sword, Gun) | 4 stats: Defense, Power Fruit, Sword, Melee | Stats allocated per level (damage, health, mastery) |
| **Shops** | Sword Dealer visible on island, Blox Fruit Dealer nearby | Black Market, Gacha machine, Katana seller | Lily sells Pistol/Rifle, Lion Pride sells Potions, Boat Dealer |
| **Death** | Respawn at home point (set at island). Lost time, no lost items. | Respawn at island. | Respawn at island. Mild punishment. |
| **Progression** | Level-up popup, stat point allocation | Level-up, stat points | Level-up notification |

### First Death — How Punishing?

All three games use the same pattern: **death is minimally punishing in early game.** Player respawns at their home/starter point. No item loss, no currency loss, no level loss. The only punishment is lost time walking back. This is critical — punishing death in the first session causes immediate quits.

### First Level-Up Feedback

| Game | Level-Up Experience |
|------|-------------------|
| **Blox Fruits** | Screen notification, stat points to allocate. Immediate sense of progression. Early levels are fast (Bandits give 300 EXP each, first level needs ~100 EXP). |
| **King Legacy** | Level notification. Stat points to distribute. First levels very fast with Soldier quest. |
| **Grand Piece Online** | Level-up notification. Stats to allocate. Early levels come quickly from bandit kills (60 XP for 5 bandits). |

**Critical Design Principle (from Roblox docs):** "Keeping thresholds low for a player's early levels allows them to level up quickly and feel the fun of progression immediately."

---

## First Session (1-2 Hours) Analysis

### How Far Does a Player Progress in One Sitting?

| Game | First Session Progression | Approximate Level |
|------|--------------------------|-------------------|
| **Blox Fruits** | Starter Island (Lv 1-10) → Jungle (Lv 10-25) → Pirate Village (Lv 25-55). First boss fight: Gorilla King (Lv 25). | Level 20-40 |
| **King Legacy** | Starter Island (Lv 0-50) → first island hop. Soldier quest → Clown Pirates → Smoky boss. | Level 30-50 |
| **Grand Piece Online** | Town of Beginnings (Lv 0-15) → Sandora (Lv 15-20) → Shell's Town (Lv 20-30). First boss: Axe Hand Logan (Lv 20-30). | Level 20-30 |

### What Hooks Keep Them Playing Past the First Hour?

1. **Visible New Islands on the Map:** Players can see there's more world to explore. The map shows destinations they haven't reached yet.
2. **Fruit/Power Aspirational Content:** Seeing other players with Devil Fruits / special powers creates desire. Blox Fruits has a Fruit Dealer and Gacha visible on the starter island.
3. **Equipment Progression:** Sword dealers are visible but expensive — creates a short-term money goal.
4. **Boss Fights:** First boss appears within 30 minutes. Gorilla King (Blox Fruits Lv 25), Smoky (King Legacy Lv 20), Bandit Boss (GPO Lv 5).
5. **Codes System:** All three games have redeemable codes visible in UI. Free 2x EXP boosts make the player feel they're progressing faster.
6. **Social Proof:** Other players in the server are fighting, leveling up, and showing off abilities.

### First "Wow" Moment

| Game | First Wow Moment | Timing |
|------|-----------------|--------|
| **Blox Fruits** | First Blox Fruit obtained (eating a fruit from the Dealer or Gacha). Suddenly you have elemental powers. OR seeing a high-level player fly/use abilities. | 20-60 minutes |
| **King Legacy** | First Devil Fruit from Gacha or Black Market. OR seeing a high-level player showcase abilities. | 30-60 minutes |
| **Grand Piece Online** | First Devil Fruit drop or seeing a Logia user (immune to damage from low-level NPCs). Sailing a boat for the first time. | 30-90 minutes |

### Social Interaction Timing

- **Blox Fruits:** Immediate — other players are on the starter island. PvP is disabled in safe zone, so interaction is cooperative by default. Players naturally see others fighting.
- **King Legacy:** Immediate — other players visible on Starter Island. Ally system accessible from menu.
- **Grand Piece Online:** Immediate — PvP disabled on Town of Beginnings. Party system and crew formation visible. Trading Hub accessible from title screen.

### Shop/Monetization Introduction

| Game | First Shop Exposure | First Premium Prompt |
|------|-------------------|---------------------|
| **Blox Fruits** | Sword Dealer and Blox Fruit Dealer on starter island (in-game currency). Robux fruit purchase visible in Fruit Dealer UI immediately. | Fruit Dealer shows Robux prices alongside Beli prices. Permanent fruits shown. ~5 minutes. |
| **King Legacy** | Black Market on Starter Island. Gacha machine visible. | Gacha costs 250k Beli. Gems (premium) needed for better fruits. Shop visible from start. |
| **Grand Piece Online** | Lily sells guns, Lion Pride sells potions, Boat Dealer on Town of Beginnings. | Gamepass boats, Devil Fruit notifier gamepass visible from title screen. |

---

## Common Drop-Off Points

### When Do Most New Players Quit?

Based on community analysis and game structure:

| Drop-Off Point | Timing | Reason |
|----------------|--------|--------|
| **Minutes 0-2** | Immediate | No tutorial → confused about what to do. UI overwhelm. |
| **Minutes 5-15** | After first few kills | Combat feels repetitive/dull without a fruit. "Is this all the game is?" |
| **Level 10-20** | 15-30 minutes | Grinding feels slow without 2x EXP codes. Don't know codes exist. |
| **First Death** | Varies | Died to an enemy and spawned far away. Lost motivation to walk back. |
| **Level 20-40** | 30-60 minutes | Hit a wall where enemies get harder. Don't have a fruit yet. Stats poorly allocated. |
| **Between Islands** | 45-90 minutes | Don't know where to go next. No navigation guidance. Lost at sea (GPO/Blox Fruits). |

### Top Complaints from New Players

1. **"I don't know what to do"** — No tutorial or guidance system
2. **"Grinding is boring"** — Combat without abilities feels repetitive
3. **"I keep dying"** — Stats poorly allocated, no fruit, fighting wrong-level enemies
4. **"Where do I go?"** — No quest markers, no navigation arrows, no map guidance
5. **"How do I get a fruit?"** — Fruit acquisition is confusing (spawn mechanics, dealer rotation, gacha)
6. **"Other players kill me"** — PvP griefing in non-safe zones (Blox Fruits, GPO)
7. **"I wasted my stat points"** — No respec available early, bad stat allocation ruins experience

### What Confuses New Players Most?

- **Stat Allocation:** All three games have stat systems that require strategic allocation. New players waste points evenly or on wrong stats.
- **Fruit/Power System:** How to obtain, what rarities mean, which fruits are good for beginners.
- **Quest Navigation:** Finding the next quest giver, knowing which island to go to.
- **Controls:** GPO has advanced controls (dash, wall climb, carry, execute) that are never explained.
- **Multiple Currencies:** Beli/Gems (King Legacy), Beli/Fragments (Blox Fruits), Peli (GPO).

### What Makes New Players Feel Overwhelmed?

- **Too many NPCs at once:** Starter islands have multiple quest givers, dealers, recruiters.
- **Full inventory of UI buttons:** Stats, inventory, codes, shop, settings all visible immediately.
- **High-level players with flashy abilities:** Creates FOMO but also makes the gap feel insurmountable.
- **Wiki dependency:** All three games require external wiki/guide knowledge for optimal play.

---

## Onboarding Best Practices

### Tooltip vs Quest-Based Teaching

| Method | Effectiveness | Example |
|--------|--------------|---------|
| **Tooltip/Popup** | Low engagement. Players dismiss without reading. | Blox Fruits: minimal tooltips. Players must discover UI themselves. |
| **Quest-Based** | High engagement. Players learn by doing. | All three games use kill quests as the teaching mechanism. "Kill 5 Bandits" teaches combat + quest loop. |
| **NPC Dialogue** | Medium. Brief, contextual. | GPO: Audio dialogues on Town of Beginnings add atmosphere. |
| **Video/Visual Demo** | High but interruptive. | None of the top games use video tutorials. |

**Winner: Quest-based teaching with minimal text.** The quest "Kill 5 Bandits" simultaneously teaches: (1) how to fight, (2) how quests work, (3) how to navigate, (4) how rewards work. One quest = four lessons.

### How Top Games Teach Combat Without a Text Wall

1. **Enemies are passive or slow:** Bandits on starter islands have low HP and deal minimal damage. Players can experiment freely.
2. **Safe zones for practice:** PvP disabled on starter islands. Players can practice without fear.
3. **Progressive difficulty:** Enemies scale up from Bandits (Lv 5) → Monkeys (Lv 14) → Gorillas (Lv 20). Each tier teaches slightly more.
4. **Environmental teaching:** GPO's "Cheesing" — hiding behind walls to avoid boss attacks — teaches players about positioning through level design, not text.
5. **First boss is cheesable:** Gorilla King (Blox Fruits) can be fought from an elevated ledge. Axe Hand Logan (GPO) can be kited. This teaches players that strategy matters.

### Starter Fruit/Weapon Balance

| Game | Starter Balance | Problem | Solution Used |
|------|----------------|---------|---------------|
| **Blox Fruits** | No fruit at start. Basic Combat style only. | Combat feels weak; first 20 minutes are dull. | 2x EXP codes available immediately. Blade fruit purchasable early ($30,000). |
| **King Legacy** | No fruit at start. Basic melee. | Same problem — early grind feels slow. | Gacha machine on Starter Island (250k Beli). Fried Chicken quest gives fast early EXP. |
| **Grand Piece Online** | No fruit at start. Basic melee. | Early game very grindy. | Gun (Pistol/Rifle) available immediately for ranged combat. Race abilities provide passive bonuses. |

**Design Rule:** Too weak is boring (no fruit, basic punches only). Too strong skips content (give a Mythical fruit at spawn). **Optimal: Give a Common/Uncommon fruit or equivalent power boost within the first 15-20 minutes.**

### Social Proof: Showing Other Players Having Fun

- **Blox Fruits:** Server shows 12+ players all fighting on various islands. High-level players visible flying, using fruits.
- **King Legacy:** Players visible on Starter Island. Bounty leaderboard shows active competitive players.
- **Grand Piece Online:** Town of Beginnings shows other new players. Title screen shows game updates and new content.
- **GPO's "2x Logia Weekends":** Visible timer on wiki/homepage creates urgency.

### Progression Milestones in First Session

| Milestone | Blox Fruits | King Legacy | Grand Piece Online |
|-----------|------------|------------|-------------------|
| **Level 5** | ~2 minutes. First stat allocation. | ~3 minutes. | ~5 minutes. |
| **Level 10** | ~5-8 minutes. Leave starter island. | ~8 minutes. | ~10 minutes. |
| **First Boss** | Lv 25 Gorilla King (~20 min) | Lv 20 Smoky (~15 min) | Lv 5 Bandit Boss (~5 min) |
| **First New Zone** | Jungle (~8 min) | Pirate Island (~25 min) | Sandora (~15 min) |
| **First Fruit/Power** | Variable (depends on money/rng) | Variable (250k Beli gacha) | Variable (fruit spawn rng) |
| **First Weapon Purchase** | Katana/Dual Katana (~10 min) | Katana $5,000 (~5 min) | Pistol/Rifle (~2 min) |

---

## Retention Hooks in First Session

### Login Rewards Visible Immediately?

| Game | Daily Login Rewards | Visibility |
|------|-------------------|-----------|
| **Blox Fruits** | No daily login system. Codes provide equivalent boosts. | Codes visible in Settings menu. |
| **King Legacy** | No explicit daily login. | Codes available. |
| **Grand Piece Online** | No daily login system. | Codes visible. |

**Gap Identified:** None of the top three games have daily login rewards. This is a missed retention opportunity.

### Codes Redeemable Immediately?

**Yes — all three games allow code redemption from the moment of joining.**

- **Blox Fruits:** Settings → Redeem. Available codes give 20 min of 2x EXP (EASTEREXP, LIGHTNINGABUSE, Sub2CaptainMaui, Axiore, etc.) and stat resets (KITT_RESET, Sub2UncleKizaru).
- **King Legacy:** Codes for Beli, Gems, stat resets.
- **Grand Piece Online:** Codes for Peli, stat resets, race rerolls.

**Design Insight:** Codes are the primary "boost" mechanism. Players who know about codes progress 2-3x faster. **Codes should be surfaced prominently in the first 5 minutes, not hidden in a settings menu.**

### Daily Quest System Introduced Early?

- **Blox Fruits:** No daily quest system for new players. Quests are level-gated.
- **King Legacy:** Quests are level-gated by island.
- **Grand Piece Online:** No daily quest system. Sequential island progression.

**Gap Identified:** None use daily quests in early game. A simple daily quest ("Kill 10 enemies today for bonus EXP") would add a retention loop.

### Friend/Social Features Introduced When?

- **Blox Fruits:** No explicit friend tutorial. Join friends through Roblox's native system.
- **King Legacy:** Ally system explained in wiki only. Not taught in-game.
- **Grand Piece Online:** Party system, crew system, and Trading Hub accessible from title screen but never explained to new players.

**Gap Identified:** Social features are available but never taught. A prompt like "Team up with nearby players for bonus EXP!" at level 10 would increase engagement.

### First Taste of Endgame Content

| Game | Endgame Preview in First Session |
|------|--------------------------------|
| **Blox Fruits** | Seeing high-level players use Devil Fruits, fly, use Haki. Second/Third Sea visible on map. Fruit Dealer shows Legendary/Mythical prices. |
| **King Legacy** | High-level players visible. Awakening system mentioned. Dragon Fruit shown in Gacha preview. |
| **Grand Piece Online** | Title screen shows new Mythical fruits (Leopard), new Dungeons (Dragon Emperor), new islands (Blossom Falls). Race system visible at character creation. |

---

## Onboarding Design Template: Minute-by-Minute Flow

### Phase 1: THE HOOK (Minutes 0-2) — "Am I Interested?"

```
MINUTE 0:00 — GAME LOAD
├── Title screen with active player count, recent updates, aspirational imagery
├── Character creation (if applicable) — RACE SELECTION adds replayability
└── "Play" button → teleport to world

MINUTE 0:30 — SPAWN
├── Spawn on small, contained starter island (safe zone, PvP disabled)
├── SEE: Other players fighting, NPCs with visible quest markers (!)
├── HEAR: Ambient music, combat sounds from other players
└── UI: Minimal. Compass, health bar, ONE quest prompt

MINUTE 1:00 — FIRST INTERACTION
├── NPC with (!) marker auto-greets player: "Welcome, warrior! Defeat 5 Bandits nearby!"
├── Arrow/glow indicator pointing toward first enemies
├── Enemies visible within 30 seconds of spawn
└── No text walls. No tutorial popups. Just DO.

MINUTE 1:30 — FIRST COMBAT
├── Basic attack (click/tap) kills enemy in 2-3 hits
├── Satisfying hit feedback: screen shake, sound, damage numbers
├── Enemy drops: visible loot on ground (currency glow)
├── Kill counter appears: "Bandits defeated: 1/5"
└── Combat feels GOOD even with basic fists
```

### Phase 2: THE LOOP (Minutes 2-10) — "I Understand the Game"

```
MINUTE 2:00 — FIRST QUEST COMPLETE
├── Return to NPC or auto-complete notification
├── REWARD: Currency + EXP with celebratory UI animation
├── LEVEL UP: "Level 2!" popup with stat point allocation
├── Stat allocation: Simple 3-4 choice panel (Melee/Defense/Sword/Fruit)
└── Immediate second quest: "Defeat 8 Bandits" or "Find [item]"

MINUTE 3:00 — FIRST SHOP EXPOSURE
├── Visible shop NPC near quest area (Sword Dealer)
├── Weapon prices visible but not affordable yet (creates money goal)
├── "Come back when you have $5,000!" dialogue
└── Player thinks: "I need to earn more money" → loop reinforced

MINUTE 5:00 — CODE PROMPT (CRITICAL)
├── Toast notification: "💡 Tip: Redeem codes for FREE 2x EXP boost! Check Settings > Codes"
├── OR: NPC near spawn: "Use code STARTERXP for a free boost!"
├── Player redeems → 20 min of 2x EXP activates
└── Progression speed DOUBLES → immediate dopamine hit

MINUTE 7:00 — SECOND QUEST CHAIN
├── Defeat harder enemies OR collect items
├── Introduce quest distance: enemies are now a short walk away
├── Maybe introduce a simple boss enemy (Bandit Boss, Lv 5-10)
├── Boss has a health bar UI — first "boss fight" experience
└── Boss drops: rare item (50% chance for cosmetic/equipment)

MINUTE 10:00 — FIRST MILESTONE: LEVEL 5-10
├── "You've grown stronger! New island unlocked: [Jungle/Forest]"
├── Map indicator shows next destination
├── Boat dealer or travel NPC now highlighted
└── Player leaves starter island for the first time → WORLD OPENS UP
```

### Phase 3: THE EXPANSION (Minutes 10-30) — "There's So Much More"

```
MINUTE 10:00 — ZONE TRANSITION
├── Travel to next island (boat, walking, or fast travel)
├── ENVIRONMENTAL SHIFT: new biome, new music, new enemy types
├── First enemy in new zone is slightly challenging (teaches difficulty ramp)
└── New quest giver NPC with new quest chain

MINUTE 15:00 — FRUIT/POWER EXPOSURE
├── Visible NPC: Blox Fruit Dealer / Devil Fruit Shop
├── OR: A fruit spawns on the map near the player (timed event)
├── OR: Another player demonstrates fruit powers nearby
├── Player learns: "There are special powers in this game"
└── Fruit prices visible → aspirational goal set

MINUTE 20:00 — FIRST DIFFICULTY SPIKE
├── Enemies now require 4-5 hits to kill
├── Player may die for the first time
├── Death = respawn at home point (minimal punishment)
├── "Tip: Allocate more stats to [Melee/Defense]!" tooltip
└── Player adjusts strategy → learns stat importance

MINUTE 25:00 — FIRST BOSS ENCOUNTER
├── Named boss enemy with unique moveset
├── Health bar displayed prominently
├── Boss is beatable solo but challenging
├── Boss drops: weapon/accessory/cosmetic with visible rarity
└── VICTORY: large XP reward, celebratory UI, possible rare drop

MINUTE 30:00 — FIRST SESSION MILESTONE
├── Player is Level 15-25
├── Has earned first weapon purchase
├── Has completed 5-10 quests
├── Has died 0-2 times
├── Has seen fruit/power system
├── Has at least one piece of equipment beyond starter
└── NEXT GOAL VISIBLE: "Reach Level 50 to unlock [new island/feature]"
```

### Phase 4: THE SINK (Minutes 30-60) — "I'm Invested"

```
MINUTE 30-45: PROGRESSION ACCELERATION
├── 2x EXP code still active (from minute 5)
├── Killing enemies faster with better weapon + stat allocation
├── Level-ups coming every 3-5 minutes (feels rewarding)
├── New quests push player to explore slightly further
└── Currency accumulating toward fruit/weapon purchase

MINUTE 45-60: THE DECISION POINT
├── Player has enough currency for a basic fruit OR weapon upgrade
├── Fruit purchase → POWER SPIKE → "This game is awesome"
├── OR: Player finds fruit under tree (spawn mechanic)
├── New abilities feel transformative (elemental powers, flight, AoE)
└── Core loop solidified: Fight → Level → Get Stronger → New Content
```

### Phase 5: THE COMMIT (Minutes 60-120) — "I'm Coming Back Tomorrow"

```
MINUTE 60-90: SOCIAL + ASPIRATIONAL
├── Encountered other players in meaningful combat/cooperation
├── Seen high-level player with rare fruit/weapon → aspiration
├── Discovered first "secret" (chest, hidden NPC, rare spawn)
├── Explored 2-3 distinct zones with different aesthetics
└── First clear goal for next session: "Reach [island] / Get [fruit]"

MINUTE 90-120: SESSION END HOOKS
├── "Daily Reward available tomorrow!" (if daily login system exists)
├── "New code available: [code] for free rewards!"
├── Progress bar showing next unlock/milestone
├── Social: "Invite friends for bonus EXP!"
└── Player logs out with: LEVEL, ITEMS, CURRENCY, and a CLEAR NEXT GOAL
```

---

## Text Flowcharts

### New Player Decision Flow

```
[PLAYER JOINS GAME]
        │
        ▼
[Character Creation / Team Select]
        │
        ▼
[Spawn on Starter Island] ◄──── Safe Zone (PvP Disabled)
        │
        ├─── Sees NPC with (!) marker
        │           │
        │           ▼
        │    [Accept First Quest: "Kill 5 Enemies"]
        │           │
        │           ▼
        │    [Fight with basic melee] ──── 2-3 hits per kill
        │           │
        │           ├─── Success → Reward + Level Up
        │           │                    │
        │           │                    ▼
        │           │         [Allocate Stat Points]
        │           │                    │
        │           │                    ▼
        │           │         [Next Quest: "Kill 8 Enemies"]
        │           │                    │
        │           │                    ▼
        │           │         [Notice: Code Redemption Toast]
        │           │                    │
        │           │                    ▼
        │           │         [Redeem 2x EXP Code]
        │           │                    │
        │           │                    ▼
        │           │         [Progression Doubles → Dopamine]
        │           │
        │           └─── Death → Respawn (minimal loss) → Retry
        │
        ├─── Sees Sword Dealer NPC
        │           │
        │           ▼
        │    [Browse Weapons → Can't Afford Yet]
        │           │
        │           ▼
        │    [Sets Money Goal: "Earn $5,000 for Katana"]
        │
        ├─── Sees Fruit Dealer / Gacha NPC
        │           │
        │           ▼
        │    [Browse Fruits → Sees Prices]
        │           │
        │           ▼
        │    [Aspirational Goal: "Save for a Devil Fruit"]
        │
        └─── Sees Other Players
                    │
                    ▼
           [Social Proof: "This game is active and fun"]
                    │
                    ▼
           [Sees high-level player use powers]
                    │
                    ▼
           [Aspirational: "I want THAT"]
```

### Core Onboarding Loop

```
         ┌──────────────────────────────────────────────────┐
         │                                                  │
         ▼                                                  │
   [KILL ENEMIES]                                           │
         │                                                  │
         ├──► [Earn EXP] ──► [LEVEL UP] ──► [Allocate Stats]──┐
         │                                                      │
         ├──► [Earn Currency] ──► [Buy Equipment] ─────────────┤
         │                                                      │
         └──► [Complete Quest] ──► [Unlock New Zone] ──────────┘
                                                                    │
                                                                    ▼
                                                          [HARDER ENEMIES]
                                                                    │
                                                                    ▼
                                                          [NEED BETTER GEAR]
                                                                    │
                                                                    ▼
                                                        [GRIND / BUY FRUIT]
                                                                    │
                                                                    ▼
                                                           [POWER SPIKE]
                                                                    │
                                                                    ▼
                                                        [NEW ABILITIES]
                                                                    │
                                                                    └──► REPEAT
```

### Drop-Off Prevention Flow

```
[PLAYER AT RISK OF QUITTING]
        │
        ├─── "I don't know what to do"
        │           │
        │           ▼
        │    [Quest arrow/glow indicator on NPC]
        │    [Compass marker for next objective]
        │    [Auto-hint: "Talk to the Bandit Leader!"]
        │
        ├─── "Combat is boring"
        │           │
        │           ▼
        │    [Surface code for 2x EXP]
        │    [Trigger fruit spawn near player]
        │    [Introduce first boss encounter]
        │
        ├─── "I keep dying"
        │           │
        │           ▼
        │    [Show stat allocation tip]
        │    [Suggest lower-level enemies]
        │    [Free basic fruit/weapon after 3 deaths]
        │
        ├─── "Where do I go?"
        │           │
        │           ▼
        │    [Waypoint system active]
        │    [Zone recommendation based on level]
        │    [NPC dialogue: "The Jungle awaits to the East!"]
        │
        └─── "This is too slow"
                    │
                    ▼
            [Auto-detect slow progression → offer 2x EXP code]
            [Bonus EXP event trigger for underperforming servers]
```

---

## Timing Tables

### Minute-by-Minute First Session Timing

| Time | Event | Player Emotion | Teaching Moment |
|------|-------|---------------|----------------|
| 0:00 | Game loads, title screen | Curiosity | "This game looks active" |
| 0:30 | Spawn on starter island | Wonder/Confusion | "Where am I? What do I do?" |
| 1:00 | See NPC with (!), accept quest | Direction | "OK, I have a goal" |
| 1:30 | First kill | Empowerment | "I can fight! Combat feels good" |
| 2:00 | Quest complete, first reward | Satisfaction | "Killing things = progress" |
| 2:30 | First level up, stat allocation | Investment | "My choices matter" |
| 3:00 | Second quest accepted | Motivation | "I know the loop now" |
| 5:00 | Code notification / redemption | Excitement | "FREE boost! I'm progressing faster" |
| 7:00 | First mini-boss / rare enemy | Challenge | "Not all enemies are the same" |
| 10:00 | Leave starter island | Discovery | "The world is bigger than I thought" |
| 15:00 | See Fruit Dealer / power system | Aspiration | "I want those powers" |
| 20:00 | First death (likely) | Frustration → Resilience | "Death isn't that punishing" |
| 25:00 | First real boss fight | Excitement | "Bosses are beatable solo!" |
| 30:00 | Level 15-25 milestone | Achievement | "I've made real progress" |
| 45:00 | Enough currency for first purchase | Anticipation | "What should I buy?" |
| 60:00 | First fruit/power acquired | **Peak Joy** | "This changes everything" |
| 90:00 | Explored 2-3 zones, social encounters | Belonging | "I'm part of this world" |
| 120:00 | Session end with clear next goal | **Commitment** | "I know what I'm doing tomorrow" |

### First Session KPI Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Tutorial completion (first quest) | >95% | Players who complete "Kill 5 Bandits" |
| 5-minute retention | >80% | Players still active at minute 5 |
| Level 5 reached | >75% | Players who reach level 5 |
| First zone transition | >60% | Players who leave starter island |
| First boss defeated | >40% | Players who kill first boss |
| Code redemption | >30% | Players who use at least one code |
| First power/fruit acquired | >20% | Players who eat/use a fruit |
| 30-minute retention | >40% | Players still active at minute 30 |
| 60-minute retention | >25% | Players still active at minute 60 |
| Day 1 return | >15% | Players who come back next day |

### Level Progression Speed Comparison (First Session)

| Level | Blox Fruits (Time) | King Legacy (Time) | Grand Piece Online (Time) |
|-------|--------------------|--------------------|--------------------------|
| 1 | 0 min | 0 min | 0 min |
| 5 | 2 min | 3 min | 5 min |
| 10 | 5-8 min | 8 min | 10 min |
| 15 | 10 min | 12 min | 15 min |
| 20 | 15 min | 18 min | 20 min |
| 25 | 20 min | 25 min | 30 min |
| 30 | 30 min | 35 min | 40 min |
| 40 | 45 min | 50 min | 60+ min |
| 50 | 60 min | 70 min | 90+ min |

*Note: With 2x EXP codes active, all times approximately halved.*

---

## Source URLs

### Game Wikis (Primary Research Sources)
- Blox Fruits Wiki: https://blox-fruits.fandom.com/wiki/Blox_Fruits_Wiki
- Blox Fruits Leveling Guide: https://blox-fruits.fandom.com/wiki/Leveling_Guide
- Blox Fruits Pirate Starter Island: https://blox-fruits.fandom.com/wiki/Pirate_Starter_Island
- Blox Fruits Blox Fruits (Mechanic): https://blox-fruits.fandom.com/wiki/Blox_Fruits
- King Legacy Wiki: https://king-legacy.fandom.com/wiki/King_Legacy_Wiki
- King Legacy Beginners Guide: https://king-legacy.fandom.com/wiki/Beginners_Guide
- Grand Piece Online Wiki: https://grand-piece-online.fandom.com/wiki/Grand_Piece_Online_Wiki
- GPO Grinding for Beginners: https://grand-piece-online.fandom.com/wiki/Grinding_for_Beginners
- GPO Town of Beginnings: https://grand-piece-online.fandom.com/wiki/Town_of_Beginnings

### Official Roblox Documentation
- Roblox Onboarding (FTUE) Guide: https://create.roblox.com/docs/production/game-design/onboarding
- Roblox Core Loops: https://create.roblox.com/docs/production/game-design/core-loops

### Code/Freebie Resources
- Blox Fruits Codes (Pocket Tactics): https://www.pockettactics.com/blox-fruits/codes
- Blox Fruits Codes (Wiki): https://blox-fruits.fandom.com/wiki/Codes

### Game Links
- Blox Fruits: https://www.roblox.com/games/2753915549
- King Legacy: https://www.roblox.com/games/4520749081
- Grand Piece Online: https://www.roblox.com/games/1730877806

---

## Appendix: Sword RPG Onboarding Checklist

Use this checklist when designing onboarding for a new sword RPG:

- [ ] **Spawn:** Player spawns on a contained safe-zone island (PvP disabled)
- [ ] **First NPC:** Visible quest marker (!) within 15 seconds of spawn
- [ ] **First Quest:** "Kill 5 [enemy]" — completable in under 2 minutes
- [ ] **First Kill:** Satisfying feedback (sound, VFX, damage numbers)
- [ ] **First Reward:** Currency + EXP + celebratory UI animation
- [ ] **First Level Up:** Within 3 minutes of spawning. Stat allocation.
- [ ] **Code System:** Redemption available AND surfaced within 5 minutes
- [ ] **First Shop:** Visible but aspirational (can't afford yet = goal setting)
- [ ] **First Boss:** Within 15-20 minutes. Health bar UI. Beatable solo.
- [ ] **Zone Transition:** Within 10 minutes. New biome = "wow" moment.
- [ ] **Power System Exposure:** Within 15 minutes. Fruit Dealer visible.
- [ ] **Death System:** Minimal punishment. Respawn at home point.
- [ ] **First Power Acquisition:** Within 30-60 minutes (fruit, weapon, ability)
- [ ] **Social Proof:** Other players visible from spawn
- [ ] **Clear Next Goal:** Always visible — next level, next zone, next item
- [ ] **Session End Hook:** Daily reward preview, code hint, progress bar
- [ ] **Navigation Help:** Waypoint/compass system for quest objectives
- [ ] **Stats Guidance:** Tooltip suggesting stat allocation for new players
- [ ] **Anti-Frustration:** Detect 3+ deaths → offer help/bonus
- [ ] **Monetization Timing:** First Robux/premium prompt after player is invested (~15+ min)

---

*Document compiled from research conducted on Blox Fruits, King Legacy, Grand Piece Online wikis, and Roblox Creator Hub official documentation. Analysis reflects game states as of September 2026.*
