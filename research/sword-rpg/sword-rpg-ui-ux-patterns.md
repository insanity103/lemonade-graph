# Sword RPG UI/UX Design Template for Roblox

> Research compiled from Blox Fruits, King Legacy, Shindo Life, Grand Piece Online, and general RPG game design best practices.

---

## Table of Contents

1. [HUD Layout — Recommended Template](#1-hud-layout--recommended-template)
2. [Health & Resource Bars](#2-health--resource-bars)
3. [Damage Numbers & Combat Feedback](#3-damage-numbers--combat-feedback)
4. [Skill Cooldown Indicators](#4-skill-cooldown-indicators)
5. [Quest Tracker](#5-quest-tracker)
6. [Minimap / Radar](#6-minimap--radar)
7. [Currency Display](#7-currency-display)
8. [Level / XP Display](#8-level--xp-display)
9. [Menu Systems](#9-menu-systems)
10. [Inventory UI](#10-inventory-ui)
11. [Stat Distribution](#11-stat-distribution)
12. [Skill / Ability System UI](#12-skill--ability-system-ui)
13. [Player Profile / Social](#13-player-profile--social)
14. [Mobile Adaptations](#14-mobile-adaptations)
15. [Visual Polish & Juice](#15-visual-polish--juice)
16. [Information Architecture](#16-information-architecture)
17. [Common UI Complaints & Solutions](#17-common-ui-complaints--solutions)
18. [Sources](#18-sources)

---

## 1. HUD Layout — Recommended Template

### Text-Based Layout Diagram (Desktop / Console)

```
+-----------------------------------------------------------------------+
|  [Lv.45] PlayerName       [Minimap 120x120]     [$ 12,500] [G 350]  |
|  ████████████████░░░░  HP                        [Quest Tracker]     |
|  ██████████░░░░░░░░░░  Energy                    > Kill 10 Bandits  |
|  [XP ████████████░░░░░░] Lv.45                   > 7/10             |
|                                                                       |
|                                                                       |
|                                                                       |
|                          (3D WORLD VIEW)                              |
|                                                                       |
|                                                                       |
|                                                                       |
|                                                                       |
|  [Combo: 12  DMG: 4,580]                                             |
|                                                                       |
|  [Skill1] [Skill2] [Skill3] [Skill4] [Skill5]    [Menu] [Bag]       |
|  [  Q  ]  [  E  ]  [  R  ]  [  F  ]  [  V  ]     [  M  ] [  I  ]   |
|  [cd:2s]  [rdy ]  [cd:5s]  [rdy ]  [cd:12s]                         |
+-----------------------------------------------------------------------+
```

### Text-Based Layout Diagram (Mobile)

```
+-----------------------------------------------------+
| [Lv.45]  ████████████░░░ HP     [Minimap 80x80]    |
|          ██████░░░░░░░░ EN      [$ 12,500]          |
| [XP ████░░░░] Lv.45                                 |
|                                      [Quest >]      |
|                                                      |
|                                                      |
|                    (3D WORLD VIEW)                   |
|                                                      |
|                                                      |
|                                                      |
|                          [Lock]                      |
|                      [Skill5]                        |
|              [Skill3]        [Skill4]                |
|          [Skill1]    [Attack]    [Skill2]            |
|     [D-Pad / Joystick]              [Jump]          |
|  [Menu]                                    [Bag]    |
+-----------------------------------------------------+
```

### HUD Element Priority Table

| Element | Always Visible? | Position | Rationale |
|---------|----------------|----------|-----------|
| Health Bar | Yes | Top-left | Most critical survival info |
| Energy/Mana Bar | Yes | Below HP | Secondary resource |
| Level + XP Bar | Yes | Top-left below bars | Progression always visible |
| Currency | Yes | Top-right corner | Players check constantly |
| Minimap | Yes (togglable) | Top-right | Navigation aid |
| Quest Tracker | Yes (togglable) | Right side | Goal-oriented play |
| Skill Slots | Yes | Bottom-center | Core combat interaction |
| Damage Counter | During combat | Bottom-left | Combat feedback |
| Combo Counter | During combat | Near damage counter | Skill expression |
| Menu/Bag buttons | Yes | Bottom corners | Quick access |

---

## 2. Health & Resource Bars

### Observed Patterns from Top Roblox RPGs

| Game | HP Bar Style | Position | Notes |
|------|-------------|----------|-------|
| Blox Fruits | Green bar above blue energy bar | Top-left, stacked vertically | On mobile, bars sit side-by-side instead |
| King Legacy | Horizontal bar with icon | Top-left | Clean gradient fill |
| Shindo Life | Horizontal bars (HP + Chakra) | Top-left area | Naruto-themed styling |
| Grand Piece Online | Simple horizontal bar | Top-left | Minimal design |

### Recommended Design

```
HP Bar:
┌──────────────────────────────┐
│ ████████████████░░░░░░░░░░░  │  1,250 / 2,000
│ [  GREEN GRADIENT FILL     ] │  
└──────────────────────────────┘
  Width: 200-250px  Height: 16-20px
  Border: 2px rounded corners
  Background: dark semi-transparent (rgba 0,0,0,0.5)
  Fill color: Green (#4CAF50) → transitions to Red (#F44336) below 30%
  Damage preview: lighter shade shows recent damage taken (0.5s linger)

Energy Bar:
┌──────────────────────────────┐
│ ████████░░░░░░░░░░░░░░░░░░░  │  450 / 1,000
│ [  BLUE GRADIENT FILL      ] │  
└──────────────────────────────┘
  Same dimensions as HP bar
  Fill color: Blue (#2196F3)
  Regen animation: subtle pulsing glow when regenerating
```

### Key Design Principles

- **Font**: Use a bold, readable sans-serif. Numbers should be `current / max` format
- **Low health warning**: Bar flashes red + vignette screen effect at <25% HP
- **Mobile placement**: Bars move to be side-by-side horizontally to save vertical space (Blox Fruits pattern)
- **Scaling**: Bar width should be relative to screen width (use Scale not Offset in Roblox)
- **Recovery preview**: Show a lighter-colored "ghost" fill for incoming heals

---

## 3. Damage Numbers & Combat Feedback

### Blox Fruits Damage Counter System (Detailed)

Source: [Blox Fruits Wiki — Damage Counter](https://blox-fruits.fandom.com/wiki/Damage_Counter)

Blox Fruits uses an **accumulating damage counter** rather than per-hit floating numbers:

- Damage **accumulates** per hit on an enemy
- A **timer bar** beneath the counter depletes over **3 seconds**
- When timer expires, both counter and combo reset to zero
- Colors shift based on total accumulated damage:

| Color | Threshold | Feeling |
|-------|-----------|---------|
| White | Base (0-?) | Neutral, normal hits |
| Yellow | Low-mid | Getting warmed up |
| Orange | Mid | Good damage |
| Red | High | Great damage |
| Purple | Very high (scales with level) | Massive — dopamine hit |

The color threshold scales with player level, so purple always feels "special" relative to what the player can do at their level.

### Recommended Floating Damage Number System

```
Design Specs:
  Font: Bold, slightly stylized (e.g., Gotham Bold or Fredoka One)
  Size: 24px base, scales up for crits (32-40px)
  
  Normal hit:     White text,   24px, float up 2 studs, fade 0.8s
  Critical hit:   Yellow text,  36px, float up 3 studs, fade 1.2s + screen shake
  Healing:        Green text,   24px, float up 1.5 studs, "+" prefix, fade 0.8s
  Miss/Dodge:     Gray text,    20px, "MISS", float up 1 stud, fade 0.6s
  Status effect:  Purple text,  22px, "BURN!", float up 2 studs, fade 1.0s

  Color palette:
  ┌─────────────────────────────────────────┐
  │  Physical:  #FFFFFF (white)             │
  │  Critical:  #FFD700 (gold)              │
  │  Fire:      #FF6B35 (orange)            │
  │  Ice:       #00BCD4 (cyan)              │
  │  Poison:    #9C27B0 (purple)            │
  │  Healing:   #4CAF50 (green)             │
  │  True Dmg:  #FF1744 (red)               │
  └─────────────────────────────────────────┘

  Animation curve: EaseOut on Y-axis (fast start, slow stop)
  Random X-offset: ±10px to prevent number stacking
```

### Combo Counter

```
┌──────────────────┐
│  COMBO: 12       │  ← Bold number, increases in size with combo
│  DMG: 4,580      │  ← Running total damage dealt
│  ████████░░      │  ← Timer bar (3 seconds)
└──────────────────┘

Combo milestones trigger visual/audio cues:
  10 hits:  Small particle burst
  25 hits:  Screen flash + sound effect
  50 hits:  Special text "UNSTOPPABLE!" + heavy screen shake
  100 hits: Legendary effect (rare, bragging rights)
```

---

## 4. Skill Cooldown Indicators

### Recommended Design

```
Skill Slot (Ready):              Skill Slot (On Cooldown):
┌─────────────┐                  ┌─────────────┐
│  ┌───────┐  │                  │  ┌───────┐  │
│  │ Icon  │  │                  │  │ Icon  │  │
│  │  ⚔️   │  │                  │  │  ⚔️   │  │
│  └───────┘  │                  │  │▓▓▓▓▓▓▓│  │  ← radial/clock wipe overlay
│   [KEY: Q]  │                  │  │▓▓2.5s▓│  │  ← countdown text
│   [READY]   │                  │  └───────┘  │
└─────────────┘                  │   [KEY: Q]  │
                                 └─────────────┘

Cooldown overlay: Clock-style radial wipe (dark semi-transparent)
Cooldown text: Centered, bold, counting down with 0.1s precision
Ready state: Brief glow pulse + "READY" text flash
Active skill: Colored border glow (element-matched color)
```

### Cooldown UX Rules

| Rule | Detail |
|------|--------|
| Show exact time | Display "2.3s" not just an opaque overlay |
| Color code states | Ready = green border, CD = gray overlay, Active = gold glow |
| Keyboard hint | Always show the bound key in the corner |
| Global cooldown | If present, show a subtle bar across all skill slots |
| Queued input | Brief flash if player presses during GCD to acknowledge input |

---

## 5. Quest Tracker

### Observed Patterns

| Game | Quest Display | Auto-Assign? | Notes |
|------|-------------|-------------|-------|
| Blox Fruits | "Recommended Quest" system highlights optimal quest for level | Yes (suggests) | Has a dedicated Recommended Quest button |
| King Legacy | Quest text appears above NPC heads + tracker sidebar | Manual accept | Progress shown in sidebar |
| Shindo Life | Mission markers on minimap | Semi-auto | Story missions are linear |

### Recommended Quest Tracker Design

```
┌──────────────────────────────┐
│  📋 QUEST TRACKER            │
│  ─────────────────────────   │
│  ▶ Kill 10 Forest Bandits   │
│    ████████░░  7/10          │
│    📍 Jungle Island          │
│  ─────────────────────────   │
│  ▶ Collect 5 Crystal Shards  │
│    ██░░░░░░░░  2/5           │
│    📍 Crystal Cave           │
│  ─────────────────────────   │
│  ▶ Defeat Boss: Iron Golem   │
│    ░░░░░░░░░░  0/1           │
│    📍 Mountain Peak          │
│  ─────────────────────────   │
│  [Open Quest Log]            │
└──────────────────────────────┘

Position: Right side of screen, vertically centered
Max visible quests: 3-4 (scrollable if more)
Opacity: 70-80% when not in combat, 50% during combat
Click/tap: Opens full quest log
Progress bar: Animated fill on completion
```

### Quest UX Rules

- **Auto-suggest**: Highlight the best quest for the player's level (Blox Fruits pattern)
- **Completion flash**: Bright animation + sound when quest objective completes
- **Waypoint arrow**: Show a directional indicator on screen edge pointing toward quest objective
- **Distance indicator**: "≈250 studs" below quest name
- **Collapse toggle**: Allow players to minimize the tracker to a small icon

---

## 6. Minimap / Radar

### Recommended Design

```
┌────────────────────┐
│    ┌──────────┐    │
│    │  N       │    │   Size: 120x120px (desktop), 80x80px (mobile)
│    │  ↑       │    │   Shape: Square with rounded corners or circle
│    │ W · · E  │    │   
│    │  ↓       │    │   Legend:
│    │  S       │    │   · = NPC (yellow dot)
│    └──────────┘    │   · = Player (green dot)
│   📍 Jungle Island │   · = Enemy (red dot)
│                    │   · = Quest target (white pulsing ring)
└────────────────────┘   ▲ = Player direction arrow
                         N/S/E/W = Cardinal directions

Features:
  - Rotates with camera OR north-locked (player preference)
  - Quest target marker with pulsing ring
  - Boss icons appear as larger, distinct markers
  - Island/zone name label below
  - Click minimap → opens full world map
```

### Minimap UX Rules

| Rule | Detail |
|------|--------|
| Player icon | Always centered, shows facing direction |
| Zoom levels | 2-3 zoom levels, toggle with scroll/pinch |
| Enemy density | Don't show every enemy — only nearby threats |
| PvP indicators | Show nearby hostile players in distinct color |
| Fog of war | Reveal areas as player explores (optional) |
| Performance | Update every 0.5s, not every frame |

---

## 7. Currency Display

### Observed Patterns

| Game | Currencies | Always Shown? | Position |
|------|-----------|---------------|----------|
| Blox Fruits | Money ($), Fragments (f), Valor | Money always, others in menu | Top area |
| King Legacy | Money, Gems | Money always | Top area |
| Shindo Life | Ryo, RELL Coins | Ryo always | HUD area |

### Recommended Currency Display

```
Desktop (top-right, near minimap):
┌──────────────────────┐
│  $ 12,500    💎 350  │
│  (primary)   (premium)│
└──────────────────────┘

Mobile (compact, top-right):
┌──────────────┐
│  $12.5K 💎350│
└──────────────┘

Rules:
  - Primary currency (gold/coins): ALWAYS visible on HUD
  - Premium currency (gems/fragments): Visible in HUD or one menu layer deep
  - Secondary currencies (raid tokens, event currency): Menu only, with notification dot
  - Format: Abbreviate large numbers (1,250,000 → 1.25M)
  - Animation: Brief green "+500" popup when earning currency
  - Sound: Coin clink on earn, subtle "ka-ching" for large amounts
```

---

## 8. Level / XP Display

### Observed Patterns

| Game | Max Level | Stat Points/Level | Display |
|------|-----------|-------------------|---------|
| Blox Fruits | 2800 (3000 with secrets) | 3 per level | Level + XP bar, always visible |
| King Legacy | ~2400+ | Varies | Level shown in HUD |
| Shindo Life | N/A (rank system) | Points from training | Level/rank shown |

### Blox Fruits Leveling System (Reference)

Source: [Blox Fruits Wiki — Levels](https://blox-fruits.fandom.com/wiki/Levels)

- 3 stat points per level, allocated to: Melee, Defense, Sword, Gun, Blox Fruit
- Max stat per category = current max level (e.g., 3000)
- XP formula: `2 × (level^2.3) + 84` for next level
- Total XP to max: ~143.8 billion EXP
- Level cap increases with major updates

### Recommended Level / XP Display

```
┌────────────────────────────────────┐
│  Lv. 45    ████████████░░░░  72%  │
│            (thin XP progress bar)  │
└────────────────────────────────────┘

Position: Top-left, below HP/Energy bars
Font: Bold, slightly larger than stats text
XP bar: Thin (4-6px), full-width of the level display area

Level-up celebration:
  1. Screen flash (white, 0.3s)
  2. "LEVEL UP!" text with particle burst
  3. "+3 Stat Points" subtitle
  4. Distinct sound effect (ascending chime)
  5. Character glow effect (2-3 seconds)
  6. Stat point notification badge on menu button
```

---

## 9. Menu Systems

### Main Menu Structure

```
┌─────────────────────────────────────────────┐
│                  MAIN MENU                  │
├─────────────────────────────────────────────┤
│                                             │
│   [⚔️ Inventory]    [📊 Stats]             │
│   [📜 Quest Log]    [🗺️ Map]               │
│   [👥 Social]       [🏪 Shop]              │
│   [⚙️ Settings]     [📖 Codex/Wiki]        │
│   [🏆 Leaderboard]  [🎁 Codes]             │
│                                             │
│              [❌ Close]                     │
└─────────────────────────────────────────────┘

Tab/Icon-based navigation — NOT a long scrolling list
Each menu opens as a modal overlay, not a new screen
Close button always visible (X or Back)
Escape key / B button closes any menu
```

### Menu Design Rules

| Rule | Detail |
|------|--------|
| Opening animation | Slide-in from right (0.2s ease-out) |
| Background | Dark semi-transparent overlay (60% opacity) |
| Close methods | X button, Escape key, click outside, B button (controller) |
| State memory | Remember last tab opened |
| Notification dots | Red dot on menu icons when something needs attention |
| Back button | Always visible in sub-menus, top-left position |
| Loading | Skeleton screens, never blank panels |

---

## 10. Inventory UI

### Observed Patterns

| Game | Layout | Tabs | Search? | Sort? |
|------|--------|------|---------|-------|
| Blox Fruits | Grid with 5 tabs (Backpack, Treasure, Wardrobe, Stash, Build) | 5 tabs with dropdown sub-filters | Yes | By rarity |
| King Legacy | Grid layout, category tabs | Fruits, Swords, Accessories, Materials | Basic | Rarity |
| Shindo Life | Card-based, categorized | Bloodline, Sub-Ability, Ninja Tools | No | Category |

### Blox Fruits Inventory System (Reference)

Source: [Blox Fruits Wiki — Inventory](https://blox-fruits.fandom.com/wiki/Inventory)

- **5 main tabs**: Backpack, Treasure, Wardrobe, Stash, Build
- **Search bar** at top of each tab
- **Dropdown menu** for sub-categories within each tab
- **Rarity sorting**: Mythical → Common (top to bottom)
- **Build tab**: Shows current loadout (equipped items, race, abilities, accessories, trinkets)
- **Single-copy items**: Swords/guns/accessories can only be owned once
- **Fruit storage**: Can store 1 of each fruit (expandable with gamepass)

### Recommended Inventory Grid

```
┌──────────────────────────────────────────────────────┐
│  INVENTORY                                           │
│  [Backpack] [Treasure] [Wardrobe] [Stash] [Build]    │
│  ─────────────────────────────────────────────────── │
│  🔍 Search items...            [Sort ▼] [Filter ▼]   │
│  ─────────────────────────────────────────────────── │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐  │
│  │ 🗡️  │ │ 🔫  │ │ 🍎  │ │ 💎  │ │ 🛡️  │ │     │  │
│  │Katana│ │Pistol│ │Apple│ │Ruby │ │Shield│ │     │  │
│  │★ ★ ★ │ │★ ★  │ │★    │ │★ ★ ★★│ │★ ★ ★ │ │     │  │
│  │Equip │ │     │ │Use  │ │     │ │Equip │ │     │  │
│  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘  │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐  │
│  │ 🧪  │ │ 📜  │ │ 🎭  │ │     │ │     │ │     │  │
│  │Potion│ │Scroll│ │Mask │ │     │ │     │ │     │  │
│  │★ ★  │ │★ ★ ★ │ │★ ★ ★★│ │     │ │     │ │     │  │
│  │Use  │ │     │ │Equip │ │     │ │     │ │     │  │
│  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘  │
│                                                      │
│  Items: 12/50                           [Page 1/3]   │
└──────────────────────────────────────────────────────┘

Grid: 5-6 columns desktop, 3-4 columns mobile
Item card: 80x100px with icon, name, rarity stars
Hover: Shows tooltip with full stats
Tap: Opens item detail panel
Rarity border glow:
  Common:    #BDBDBD (gray)
  Uncommon:  #4CAF50 (green)
  Rare:      #2196F3 (blue)
  Epic:      #9C27B0 (purple)
  Legendary: #FF9800 (orange)
  Mythical:  #F44336 (red) + shimmer animation
```

### Inventory UX Rules

| Rule | Detail |
|------|--------|
| Search | Real-time filtering as player types |
| Sort options | Rarity, name, date acquired, type |
| Bulk actions | Select multiple for mass delete/trade |
| Quick equip | Double-tap or drag to equipment slot |
| Full inventory warning | Yellow bar at 80%, red at 95% |
| Auto-sort button | One-tap organize by category + rarity |
| Tooltip delay | 0.3s hover (instant on mobile tap) |

---

## 11. Stat Distribution

### Observed Patterns

| Game | Stats | Points/Lvl | Respec? | Display |
|------|-------|-----------|---------|---------|
| Blox Fruits | Melee, Defense, Sword, Gun, Blox Fruit | 3 | Stat Reset (gamepass/code) | Slider + button interface |
| King Legacy | Strength, Defense, Sword, Fruit | Varies | Reset available | Point allocation UI |
| Shindo Life | Health, Chi, Ninjutsu, Taijutsu | Points from training | Reset available | Sliders |

### Blox Fruits Stat System (Reference)

Source: [Blox Fruits Wiki — Levels](https://blox-fruits.fandom.com/wiki/Levels)

- 5 stat categories: **Melee**, **Defense**, **Sword**, **Gun**, **Blox Fruit**
- 3 points per level
- Max points per stat = max player level (e.g., 3000)
- Can max approximately 3 categories without race awakening
- Defense directly scales HP: `S(5) + 95` where S = defense stat points
- Stat resets available via codes, gamepass, or in-game items

### Recommended Stat Distribution UI

```
┌──────────────────────────────────────────────────────┐
│  STATS                          Points: 45 remaining │
│  ─────────────────────────────────────────────────── │
│                                                      │
│  Melee        ████████████░░░░░░░░  120   [+][-]    │
│  Defense      ████████████████░░░░  160   [+][-]    │
│  Sword        ████████░░░░░░░░░░░░   80   [+][-]    │
│  Gun          ██░░░░░░░░░░░░░░░░░░   20   [+][-]    │
│  Blox Fruit   ████████████████████  200   [+][-]    │
│                                                      │
│  ─────────────────────────────────────────────────── │
│  [Reset Stats]              [Confirm Allocation]     │
│                                                      │
│  Tip: Defense increases your HP!                     │
│  Each point in Defense = +5 HP                       │
└──────────────────────────────────────────────────────┘

Bar: Proportional to max possible stat
Buttons: [+] adds 1 point, [-] removes 1, hold for rapid allocation
Preview: Show stat change effect in real-time (e.g., "HP: 1250 → 1300")
Confirm button: Required to lock in changes (prevents accidental allocation)
Reset: Prominent but requires confirmation
```

---

## 12. Skill / Ability System UI

### Observed Patterns

| Game | Ability Slots | Cooldown UI | Unlock System |
|------|-------------|-------------|---------------|
| Blox Fruits | 4 skill slots (Z, X, C, V) + fighting style moves (keys vary) | Clock-wipe overlay + timer text | Mastery-based unlock |
| King Legacy | 4 fruit abilities + fighting style | Circular cooldown overlay | Level/mastery |
| Shindo Life | Multiple ability slots with mode switching | Standard cooldown bars | Bloodline-based |

### Recommended Skill Bar Layout

```
Desktop (bottom-center):
┌─────────────────────────────────────────────────────────────┐
│  [Z: Dark Slash]  [X: Shadow Step]  [C: Void Beam]  [V: ULTIMATE]  │
│  [  cd: 3.2s   ]  [  ready       ]  [  cd: 8.0s  ]  [ cd: 25.0s ]  │
│  ██████░░░░░░░░  ████████████████  ████████░░░░░░  ████░░░░░░░░░░  │
└─────────────────────────────────────────────────────────────┘

Mobile (right side, thumb zone):
┌─────────────┐
│  [  V  ]    │  ← Ultimate (top, hardest to accidentally press)
│  [  C  ]    │
│  [  X  ]    │
│  [  Z  ]    │  ← Primary skill (most accessible)
│  [ATK ]    │  ← Basic attack (always at bottom)
└─────────────┘

Skill unlock notification:
  ┌─────────────────────────────┐
  │  ✨ NEW SKILL UNLOCKED!     │
  │  Dark Slash [Z]             │
  │  Mastery Required: 50       │
  │  [Practice]  [Assign Slot]  │
  └─────────────────────────────┘
```

---

## 13. Player Profile / Social

### Blox Fruits Player Profile (Reference)

Source: [Blox Fruits Wiki — Player Profile](https://blox-fruits.fandom.com/wiki/Player_Profile)

The profile system in Blox Fruits is a strong social feature (added Update 27.5):

- **Server Tab**: Browse all players on current server
- **Global Tab**: Search any player by username, view friends
- **Profile shows**: Character skin, display name, username, accessory, level, race, crew, hotbar, title, last seen location
- **Customizable**: Background image (12+ options from gacha/events), "Looking for..." status, fun statuses, 6 featured items, 4 showcase stats
- **Statistics tracked**: Fighting styles unlocked, swords unlocked, money, bounty, fish caught, first join date, etc.

### Recommended Player Profile

```
┌──────────────────────────────────────────────┐
│  [3D CHARACTER PREVIEW]                      │
│                                              │
│  PlayerName#1234                             │
│  Lv. 45  |  Human V3  |  "On my grind"      │
│  Crew: Shadow Knights                        │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ HOTBAR: Katana | Bomb Fruit | Pistol   │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  STATS SHOWCASE:                             │
│  Swords: 12/40  |  Bounty: 2.5M             │
│  Fish: 847      |  Joined: Oct 2023         │
│                                              │
│  LOOKING FOR: PvP                            │
│                                              │
│  [Server Tab]  [Global Tab]                  │
│  ─────────────────────────────────────────   │
│  🔍 Search players...                        │
│  [Player 1]  [Player 2]  [Player 3]         │
└──────────────────────────────────────────────┘
```

---

## 14. Mobile Adaptations

### Thumb Zone Map

```
┌─────────────────────────────────┐
│  HARD TO REACH (top edge)       │
│  ┌─────────────────────────────┐│
│  │ OK ZONE (top third)         ││
│  │  - Minimap, currency, level ││
│  │                             ││
│  │ EASY ZONE (middle)          ││
│  │  - Main game view           ││
│  │  - Quest tracker (right)    ││
│  │                             ││
│  │ THUMB ZONE (bottom third)   ││
│  │  - Skill buttons            ││
│  │  - Movement joystick        ││
│  │  - Jump, menu, inventory    ││
│  └─────────────────────────────┘│
│  EASIEST (bottom corners)       │
│  L-thumb: Move    R-thumb: Skills│
└─────────────────────────────────┘

Critical controls in bottom 35% of screen
All interactive elements: minimum 48x48px touch target
Spacing between buttons: minimum 8px (prevent mis-taps)
```

### Mobile-Specific Adaptations

| Feature | Desktop | Mobile Adaptation |
|---------|---------|-------------------|
| HP/Energy bars | Stacked vertically, top-left | Side-by-side, compact |
| Skill buttons | Keyboard keys with small UI | Large circular buttons (64-80px) |
| Movement | WASD | Virtual joystick (left thumb) |
| Camera | Mouse | Touch drag (right thumb area) |
| Inventory grid | 5-6 columns | 3-4 columns, larger items |
| Menus | Full overlay | Full-screen panels |
| Minimap | 120x120px | 80x80px, toggleable |
| Auto-target | Manual aim | Soft lock-on with visual indicator |
| Text size | 14-16px base | 18-20px base |
| Jump button | Space bar | Dedicated button, bottom-right |

### Auto-Targeting UI (Mobile)

```
When enemy is in range:
  ┌─────────────┐
  │   [Enemy]   │  ← Red bracket around targeted enemy
  │  ┌───────┐  │  ← Health bar appears above enemy
  │  │ HP ██░│  │
  │  └───────┘  │
  │  Lv.42 Bandit│
  └─────────────┘

Target switch:
  - Tap enemy to switch target
  - Swipe toward enemy to soft-lock
  - Auto-target nearest hostile when attacking
  - Visual: Pulsing red reticle on current target
```

---

## 15. Visual Polish & Juice

### Screen Effects

| Effect | Trigger | Description |
|--------|---------|-------------|
| Screen shake | Taking damage, boss attacks, critical hits | Small amplitude (2-5px), short duration (0.15-0.3s) |
| Vignette | Low health (<25%) | Red-tinted screen edges, pulsing |
| Flash | Level up, boss spawn, quest complete | White flash (0.2s), color flash for type |
| Hit marker | Landing an attack | Small X or crosshair flash near crosshair, 0.1s |
| Motion blur | Fast movement skills | Subtle directional blur (optional, performance-sensitive) |

### Level-Up Celebration

```
Sequence (total ~3 seconds):
  1. 0.0s — Screen flash (white, 0.2s)
  2. 0.1s — "LEVEL UP!" text zooms in from 0% to 120% to 100% (0.4s)
  3. 0.3s — Particle ring explosion outward from character
  4. 0.5s — "+3 Stat Points" fades in below
  5. 1.0s — Character glow aura (gold, 2s duration)
  6. 1.5s — Notification badge appears on Stats menu button
  7. 3.0s — All effects fade out
  
Sound: Ascending chime + impact bass hit
```

### Rare Item Drop Effects

```
Drop rarity tiers:
  Common:    Small white pickup text, basic sparkle
  Uncommon:  Green glow, soft chime
  Rare:      Blue pillar of light, stronger chime
  Epic:      Purple pillar + screen flash, dramatic chord
  Legendary: Orange pillar + screen shake + slow-mo (0.5s) + rare sound
  Mythical:  Red pillar + full-screen flash + slow-mo (1s) + legendary fanfare

Pillar of light:
  Visible from distance (200+ studs)
  Height: 30-50 studs above ground
  Particle: Upward-flowing sparkles matching rarity color
  Duration: 5-10 seconds (longer for rarer items)
```

### Boss Entrance Effects

```
Phase 1: Warning (3-5 seconds before spawn)
  - Screen border pulses red
  - "A powerful enemy approaches..." system message
  - Atmospheric sound rumble
  - Minimap shows skull icon at boss location

Phase 2: Entrance
  - Boss spawns with dramatic animation
  - Screen shake (medium amplitude, 1s)
  - Boss name + level + title appear in large text center-screen
  - Boss health bar appears at top-center of screen
  - Music changes to boss theme
  - All nearby players see the entrance

Phase 3: Boss HP Bar
  ┌──────────────────────────────────────────┐
  │  👹 IRON GOLEM  Lv.120  [RAGE MODE]     │
  │  ████████████████░░░░░░░░  15,000/25,000 │
  │  Phase: 2/3                               │
  └──────────────────────────────────────────┘
  
  Position: Top-center, spanning 60% of screen width
  Style: Unique boss-themed border/art
  Phase indicator: Shows current phase if multi-phase boss
```

### Loading Screen Design

```
┌──────────────────────────────────────┐
│                                      │
│      [SWORD ART / SPLASH IMAGE]     │
│                                      │
│   ████████████████░░░░░░  Loading    │
│                                      │
│   TIP: Hold [F] to block attacks     │
│   and reduce damage taken!           │
│                                      │
│   [Controls reference diagram]       │
│                                      │
└──────────────────────────────────────┘

Tips rotation: 15-20 tips, shown randomly
Content: Gameplay tips, lore snippets, update news
Art: Rotating character/equipment artwork
Progress bar: Smooth, not jerky (use fake smoothing if needed)
```

---

## 16. Information Architecture

### Always Visible vs Togglable vs Menu-Only

| Information Layer | Elements | Visibility |
|-------------------|----------|------------|
| **Always visible** | HP, Energy, Level+XP, Currency (primary), Skill bar, Quest tracker | HUD — no toggle needed |
| **Togglable HUD** | Minimap, Quest tracker, Damage numbers, Combo counter, FPS/Ping | Player can hide via settings |
| **Menu (1 tap)** | Inventory, Stats, Map, Quest Log, Settings | Open from HUD buttons |
| **Menu (2+ taps)** | Codex/Wiki, Achievements, Trading, Social features | Nested in main menu |
| **Contextual** | Boss HP bar, Event timers, PvP indicators | Only appear when relevant |

### Tutorial System Design

| Approach | Pros | Cons | Best For |
|----------|------|------|----------|
| Tooltip popups | Non-intrusive, contextual | Easy to dismiss/forget | Simple controls |
| Quest-based tutorial | Structured, progressive | Can feel forced | Complex systems |
| Sandbox area | Learn by doing | Requires dedicated space | Combat mechanics |
| Video tutorials | Visual, clear | Breaks immersion | Advanced techniques |

### Recommended: Hybrid Approach

```
Phase 1 (0-5 min):    Guided quest ("Talk to the Sword Master")
  → Teaches: Movement, basic attack, interacting with NPCs

Phase 2 (5-15 min):   Quest chain continues
  → Teaches: Skills, HP management, quest tracking

Phase 3 (15-30 min):  Optional tutorial area
  → Teaches: Stat allocation, inventory, advanced combat

Ongoing:              Contextual tooltips
  → "You leveled up! Open Stats to allocate points" (first 3 times)
  → "New skill unlocked! Press [Z] to try it" (first time per skill)
  → Tips dismissible with "Don't show again" checkbox

In-game reference:
  → Settings menu → "How to Play" section
  → Controls diagram
  → System explanations
  → NOT a separate wiki (keep it in-game)
```

### Stats Display (How Players See Their Power)

```
┌──────────────────────────────────────────────────┐
│  PLAYER STATS                                    │
│  ─────────────────────────────────────────────── │
│  Melee Damage:    1,250 - 1,480                  │
│  Defense:         800 (reduces damage by 30%)    │
│  Sword Damage:    950 - 1,120                    │
│  Gun Damage:      420 - 510                      │
│  Fruit Damage:    1,800 - 2,100                  │
│  Movement Speed:  100% (base)                    │
│  HP:              1,895                          │
│  Energy:          950                            │
│  ─────────────────────────────────────────────── │
│  Total Bounty:    2,450,000                      │
│  Current Title:   "The Undefeated One"           │
└──────────────────────────────────────────────────┘

Rules:
  - Show damage RANGES, not single numbers
  - Explain what stats DO ("reduces damage by 30%")
  - Show comparisons when hovering equipped vs unequipped items
  - Color-code: green (buffed), white (normal), red (debuffed)
```

---

## 17. Common UI Complaints & Solutions

### Top Player Complaints from Roblox RPG Communities

| Complaint | Source Game | Solution |
|-----------|-----------|----------|
| "Can't see my damage numbers clearly" | Various | Larger fonts, color-coding, accumulation system like Blox Fruits |
| "Too many menus to navigate" | King Legacy | Flatten menu hierarchy, add quick-access buttons |
| "Inventory is confusing / cluttered" | Multiple | Add search, sort, category tabs, and visual rarity borders |
| "Don't know what stats to put points in" | Blox Fruits | Add stat recommendations, preview effects, suggested builds |
| "No idea where to go next" | Multiple | Auto-quest tracker, waypoint arrows, recommended quest system |
| "UI blocks the screen on mobile" | Multiple | Auto-hide HUD during cutscenes, toggle transparency, minimize buttons |
| "Can't find the quest NPC" | Multiple | Arrow indicator, minimap marker, distance counter |
| "Damage numbers are confusing" | Various | Use Blox Fruits accumulator + color system |
| "Menu lag / slow to open" | Various | Pre-load menu assets, cache UI elements |
| "Boss HP bar is tiny/hard to read" | Various | Large centered bar at top of screen with boss name |
| "No way to compare items" | Multiple | Side-by-side comparison tooltip on hover |
| "Settings menu is bare-bones" | Various | Add: damage number toggle, HUD opacity, button size slider, camera sensitivity |

### Cluttered vs Minimal — The Right Balance

```
TOO CLUTTERED:
  - 6+ always-visible HUD elements
  - Multiple overlapping notification popups
  - Permanent chat window
  - All currencies visible at once
  - Constant tutorial popups

TOO MINIMAL:
  - No quest tracker visible
  - Health bar only visible when damaged
  - No currency display
  - Skills hidden until you remember the key
  - No minimap

THE SWEET SPOT (Recommended):
  5-7 always-visible elements:
    ✓ Health bar
    ✓ Energy bar
    ✓ Level + XP
    ✓ Primary currency
    ✓ Skill bar (5 slots)
    ✓ Quest tracker (collapsible)
    ✓ Minimap (toggleable)
  
  Everything else: 1 menu tap away
  Notification system: Stack in top-right, auto-dismiss after 5s
```

---

## 18. Sources

| Source | URL | Data Used |
|--------|-----|-----------|
| Blox Fruits Wiki — Main | https://blox-fruits.fandom.com/wiki/Blox_Fruits_Wiki | Game structure, categories |
| Blox Fruits Wiki — GUI Category | https://blox-fruits.fandom.com/wiki/Category:GUI | All GUI elements listed (14 total) |
| Blox Fruits Wiki — Damage Counter | https://blox-fruits.fandom.com/wiki/Damage_Counter | Damage accumulation system, color tiers, 3-second timer |
| Blox Fruits Wiki — Health | https://blox-fruits.fandom.com/wiki/Health | HP bar design, HP formula, max HP, Aura damage reduction |
| Blox Fruits Wiki — Inventory | https://blox-fruits.fandom.com/wiki/Inventory | 5-tab inventory, search bar, rarity sorting, Build tab |
| Blox Fruits Wiki — Levels | https://blox-fruits.fandom.com/wiki/Levels | Leveling system, stat points, XP formula, level cap |
| Blox Fruits Wiki — Player Profile | https://blox-fruits.fandom.com/wiki/Player_Profile | Social profile, customizable backgrounds, status, stats showcase |
| Blox Fruits Wiki — Settings | https://blox-fruits.fandom.com/wiki/Settings | Togglable features |
| King Legacy Wiki | https://king-legacy-official.fandom.com/wiki/King_Legacy_Wiki | Game categories, similar structure to Blox Fruits |
| Shindo Life Wiki | https://shindo-life-rell.fandom.com/wiki/Shindo_Life_Wiki | Bloodline system, ability categories, game modes |
| General RPG HUD best practices | Game design knowledge | Mobile UX, thumb zones, information hierarchy |

---

## Appendix: Color Palette Reference

```
UI Chrome Colors:
  Background (panels):    rgba(20, 20, 30, 0.85) — dark blue-black
  Border:                 rgba(255, 255, 255, 0.1) — subtle white
  Accent:                 #FFD700 (gold) — for highlights, buttons
  Text Primary:           #FFFFFF (white)
  Text Secondary:         #B0BEC5 (light gray)
  Text Muted:             #78909C (gray)
  
Health/Resource Colors:
  HP:                     #4CAF50 (green) → #F44336 (red) at low HP
  Energy:                 #2196F3 (blue)
  XP:                     #FF9800 (orange)
  Mana (if used):         #9C27B0 (purple)
  
Rarity Colors:
  Common:                 #BDBDBD
  Uncommon:               #4CAF50
  Rare:                   #2196F3
  Epic:                   #9C27B0
  Legendary:              #FF9800
  Mythical:               #F44336
  
Status Colors:
  Buff:                   #4CAF50 (green)
  Debuff:                 #F44336 (red)
  Neutral:                #FFFFFF (white)
  Special:                #FFD700 (gold)
```
