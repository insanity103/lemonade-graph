# Lemonade Graph — Complete Roblox Game Design Knowledge Base

## What This Repo Contains

- **lemonade-game/** — Roblox Studio sword RPG game (the product)
- **skills/** — 7 AI-agent skills for Roblox development (28 .md files, 8,707 lines)
- **research/** — 24 sword RPG research documents (15,030 lines)
- **graphify-out/** — Interactive knowledge graph (273 nodes, 285 links, 38 communities)

**Total knowledge base**: 52 markdown files, 23,737 lines of actionable Roblox game design intelligence.

---

## Skills Directory (skills/)

7 skills with 7 SKILL.md router files (1,223 lines) + 21 reference files (7,484 lines).

### Skill Overview

| Skill | Purpose | Refs | Key Topics |
|-------|---------|------|------------|
| roblox-game-dev | Master router | 0 | Routes to sub-skills by domain |
| roblox-map-design | Map/level design | 4 | Obby, arena, open-world, tycoon patterns |
| roblox-luau | Luau scripting | 6 | RemoteEvent, DataStore, obby/combat/tycoon/horror code |
| roblox-systems | Game systems | 7 | Persistence, shop, inventory, combat, NPC AI, tycoon, progression |
| roblox-ui | UI/UX design | 2 | UI patterns, UI animation |
| roblox-debug | Debugging | 1 | 30+ error-to-fix reference |
| roblox-optimize | Performance | 1 | 40-item audit checklist |

### Detailed File Inventory

#### SKILL.md Files (Router/Dispatcher)

| File | Lines |
|------|-------|
| roblox-game-dev/SKILL.md | 87 |
| roblox-map-design/SKILL.md | 54 |
| roblox-luau/SKILL.md | 101 |
| roblox-systems/SKILL.md | 57 |
| roblox-ui/SKILL.md | 395 |
| roblox-debug/SKILL.md | 163 |
| roblox-optimize/SKILL.md | 366 |
| **Total** | **1,223** |

#### Reference Files (Deep Technical Content)

| Skill | File | Lines | Content |
|-------|------|-------|---------|
| roblox-debug | error-reference.md | 135 | 30+ Roblox error-to-fix patterns |
| roblox-luau | combat-code.md | 292 | Sword combat Luau scripts |
| roblox-luau | datastore-pattern.md | 274 | DataStore save/load patterns |
| roblox-luau | horror-code.md | 410 | Horror game Luau scripts |
| roblox-luau | obby-code.md | 345 | Obby checkpoint/spawn code |
| roblox-luau | remote-pattern.md | 226 | RemoteEvent security patterns |
| roblox-luau | tycoon-code.md | 332 | Tycoon purchase/build code |
| roblox-map-design | arena-patterns.md | 214 | Arena layout patterns |
| roblox-map-design | obby-patterns.md | 215 | Obby level design patterns |
| roblox-map-design | open-world-patterns.md | 199 | Open-world zone design |
| roblox-map-design | tycoon-patterns.md | 176 | Tycoon map layout patterns |
| roblox-optimize | performance-checklist.md | 829 | 40-item performance audit |
| roblox-systems | combat.md | 327 | Combat system architecture |
| roblox-systems | data-persistence.md | 341 | DataStore persistence layer |
| roblox-systems | inventory.md | 309 | Inventory system design |
| roblox-systems | npc-ai.md | 364 | NPC state machine & AI |
| roblox-systems | progression.md | 298 | XP/level/rebirth progression |
| roblox-systems | shop-economy.md | 270 | Shop & economy architecture |
| roblox-systems | tycoon.md | 362 | Tycoon system (dropper→conveyor→collector) |
| roblox-ui | ui-animation.md | 738 | Tween/UI animation library |
| roblox-ui | ui-patterns.md | 828 | HUD, menus, mobile UI patterns |
| | **Total** | **7,484** | |

---

## Research Library (research/sword-rpg/)

24 documents, 15,030 total lines. Comprehensive game design research compiled from wiki data, official Roblox documentation, and community analysis across 10+ Roblox sword RPG games.

### Core Analysis (Start Here)

| File | Lines | Content |
|------|-------|---------|
| sword-rpg-INDEX.md | 79 | Master index — read this first for navigation |
| sword-rpg-popular-games.md | 538 | Gameplay loops of top 5 games, common patterns, addictive hooks, player complaints |
| sword-rpg-player-sentiment.md | 457 | What players love/hate, cross-game comparison, opportunity gaps, anti-patterns |
| sword-rpg-hidden-gems.md | 713 | 10 underrated games with stealable mechanics (Deepwoken parry, Rogue Lineage lineage, Arcane Odyssey imbuement) |

### The Big Three Systems

| File | Lines | Content |
|------|-------|---------|
| sword-rpg-combat-systems.md | 932 | M1 combos, skills, hit registration, parry/block/feint, damage calculation, ideal system |
| sword-rpg-rebirth-analysis.md | 554 | Additive vs reset rebirth, V4 awakening gold standard, cost-to-reward ratios, critical design rules |
| sword-rpg-progression-curves.md | 550 | XP formulas, level caps, pacing, dead zones, 80-300hr to max, design template |

### Game Systems

| File | Lines | Content |
|------|-------|---------|
| sword-rpg-economy-design.md | 484 | Multi-currency architecture, earning rates, sink ratios, inflation control, premium currency |
| sword-rpg-weapon-acquisition.md | 405 | Drop rates, boss loot tables, rarity tiers, enhancement layers, pity systems |
| sword-rpg-boss-pve-design.md | 500 | HP curves, attack patterns, phase thresholds, raid structure, anti-farm mechanics |
| sword-rpg-pvp-design.md | 614 | Mode taxonomy, balance frameworks, skill vs stats, ranking systems, anti-cheat |
| sword-rpg-world-design.md | 591 | Zone structure (60 islands/3 seas), NPC/mob placement, fast travel, secrets, technical architecture |
| sword-rpg-anti-exploit-architecture.md | 2,096 | Server authority model, RemoteEvent security, exploit detection, punishment ladders, Luau code patterns |

### Player Experience

| File | Lines | Content |
|------|-------|---------|
| sword-rpg-onboarding-FTUE.md | 682 | First 5min/30min/1hr flow, "Kill 5 Bandits" pattern, drop-off points, no-forced-tutorial rule |
| sword-rpg-ui-ux-patterns.md | 990 | HUD layout, damage numbers, menus, mobile adaptation, accumulating damage counter pattern |
| sword-rpg-retention-community.md | 777 | Daily loops, crew/alliance social systems, content cadence, churn analysis, community health |

### Growth & Monetization

| File | Lines | Content |
|------|-------|---------|
| sword-rpg-monetization.md | 632 | Game pass pricing, developer products, battle pass gap, F2P/P2W spectrum, ethical guidelines |
| sword-rpg-growth-strategy.md | 587 | Update cadence, code distribution, YouTube ecosystem, Discord community, viral tactics |

### Legendary Swords RPG Deep Dive (6 files)

The INSPIRATION game. **Read sword-rpg-legendary-swords-SYNTHESIS.md first** for the complete picture.

| File | Lines | Content |
|------|-------|---------|
| sword-rpg-legendary-swords-SYNTHESIS.md | 597 | Comprehensive synthesis — start here |
| sword-rpg-legendary-swords-core.md | 563 | Complete game mechanics analysis |
| sword-rpg-legendary-swords-mechanics.md | 529 | Core gameplay systems breakdown |
| sword-rpg-legendary-swords-community.md | 435 | Community-driven preservation & fan restoration |
| sword-rpg-legendary-swords-wiki.md | 428 | Community wiki & reference |
| sword-rpg-legendary-swords-bugs.md | 297 | Comprehensive bug catalog |

---

## The 10 Universal Design Rules (from 10+ games analyzed)

1. **Never reset player progress** — additive stacking beats level-reset rebirth
2. **Quest XP ≈ 1 level per quest** — the "one more quest" dopamine loop
3. **No forced tutorials** — learn-by-doing with "Kill 5 Bandits" as the universal first quest
4. **Multi-currency (3+)** with activity-specific currencies prevents inflation
5. **Gacha/rolls are the #1 retention driver** — variable ratio reinforcement (slot machine psychology)
6. **5-hit M1 combos** with escalating endlag feel better than 4-hit
7. **Hitlag (20-50ms freeze frames)** is the biggest "feel good" factor most games miss
8. **Parry/block/feint triangle** (Deepwoken) is the gold standard for skill-based combat
9. **Codes via YouTube creators** are the #1 zero-cost growth hack
10. **Starter island small, death minimally punishing** — containment and forgiveness in FTUE

### The #1 Opportunity Gap
A game with **Deepwoken's combat depth** + **Blox Fruits' accessibility and content volume** has no competitor. This exact combination is unoccupied.

### Games Analyzed
- **Tier 1 (200B+ visits)**: Blox Fruits
- **Tier 2 (10B+ visits)**: King Legacy, Shindo Life
- **Tier 3 (1B+ visits)**: Grand Piece Online, Deepwoken
- **Hidden Gems**: Rogue Lineage, Arcane Odyssey, Type Soul, Project Slayers, Sword Burst Online

---

## Knowledge Graph (graphify-out/)

**273 nodes, 285 links, 38 communities** — interactive visualization of every concept, system, and connection across the entire knowledge base.

### Files

| File | Purpose |
|------|---------|
| graph.html | Open in browser for interactive exploration |
| graph.json | Raw graph data (nodes + edges) |
| GRAPH_REPORT.md | Full audit report with communities, god nodes, gaps |

### God Nodes (Most Connected — Core Abstractions)

| Node | Edges | Role |
|------|-------|------|
| Roblox Sword RPG Research Library (INDEX) | 17 | Cross-community bridge |
| Tycoon System | 9 | Game mode hub |
| Comprehensive Bug Catalog | 6 | Debugging anchor |
| Parry/Block/Feint Triangle (Deepwoken gold standard) | 6 | Combat design anchor |
| Retention & Community Design Template | 6 | Player experience anchor |
| NPC State Machine (Idle, Patrol, Chase, Attack, Return) | 6 | AI systems anchor |
| Sword RPG PvP Design Template | 6 | PvP design anchor |
| Purchase Flow (server-side validation, currency deduction) | 6 | Economy anchor |
| Core Gameplay Loop (Fight-Collect-Rebirth) | 5 | Loop design anchor |
| Sword Collection System (65-75+ Weapons) | 5 | Content anchor |

### Key Communities

| # | Community Name | Cohesion | Nodes |
|---|---------------|----------|-------|
| 0 | Comprehensive Bug Catalog | 0.15 | 20 |
| 1 | Parry/Block/Feint Triangle (Deepwoken gold standard) | 0.13 | 18 |
| 2 | Retention & Community Design Template | 0.15 | 14 |
| 3 | Layered Defense Model (5 layers) | 0.22 | 9 |
| 4 | NPC State Machine (Idle, Patrol, Chase, Attack, Return) | 0.18 | 13 |
| 5 | XP & Level System (exponential curve, lookup table) | 0.22 | 9 |
| 6 | Sword RPG PvP Design Template | 0.21 | 12 |
| 7 | Roblox Sword RPG Research Library (INDEX) | 0.10 | 26 |
| 8 | UI/UX (Tycoon subsystems) | 0.36 | 10 |
| 9 | Purchase Flow (server-side validation) | 0.15 | 13 |
| 11 | Community & Content Research | 0.32 | 8 |
| 12 | Weapon Acquisition Systems | 0.38 | 7 |
| 13 | Data Persistence Architecture | 0.40 | 5 |
| 14 | Sword RPG UI/UX Design Template | 0.67 | 4 |

### Hyperedges (Group Relationships)

- **Collection-Driven Engagement Loop** — sword collection + rarity tiers + rebirth system
- **Server Authority Pattern** — combat + anti-exploit + persistence (zero-trust client)
- **Communal Boss Event Social Pattern** — server event bosses + last-hit mechanic + boss system
- **Shared Player Data Schema** — persistence ↔ inventory ↔ economy
- **Core Sword RPG Gameplay Loop** — quest → grind → level → unlock
- **Retention Mechanics Stack** — gacha + time-gated + social + updates
- **Tycoon Production Pipeline** — dropper → conveyor → collector → cash
- **XP Progression Pipeline** — grant XP → level → unlock → rebirth

---

## Source Quality

Most data sourced from official Fandom wikis and Roblox Creator Documentation. Community sentiment synthesized from wiki discussion pages and documented player feedback patterns. Source URLs included in each research file. Research compiled by 16 parallel AI research agents.
