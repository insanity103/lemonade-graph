# Roblox Sword RPG Research Library

Comprehensive game design research compiled from wiki data, official Roblox documentation, and community analysis across 10+ Roblox sword RPG games (Blox Fruits, King Legacy, Grand Piece Online, Deepwoken, Shindo Life, Rogue Lineage, Arcane Odyssey, Type Soul, Project Slayers, and more).

**Total**: 17 research documents, 12,000+ lines of actionable game design intelligence.

## Quick Reference — What's In Each File

### Core Analysis (Start Here)

| File | Lines | What It Covers |
|------|-------|----------------|
| [sword-rpg-popular-games.md](sword-rpg-popular-games.md) | 538 | Gameplay loops of top5 games, common patterns, addictive hooks, player complaints |
| [sword-rpg-player-sentiment.md](sword-rpg-player-sentiment.md) | 457 | What players love/hate, cross-game comparison, opportunity gaps, anti-patterns |
| [sword-rpg-hidden-gems.md](sword-rpg-hidden-gems.md) | 713 |10 underrated games with stealable mechanics (Deepwoken parry, Rogue Lineage lineage, Arcane Odyssey imbuement) |

### The Big Three Systems

| File | Lines | What It Covers |
|------|-------|----------------|
| [sword-rpg-combat-systems.md](sword-rpg-combat-systems.md) | 932 | M1 combos, skills, hit registration, parry/block/feint, damage calculation, ideal system |
| [sword-rpg-rebirth-analysis.md](sword-rpg-rebirth-analysis.md) | 554 | Additive vs reset rebirth, V4 awakening gold standard, cost-to-reward ratios, critical design rules |
| [sword-rpg-progression-curves.md](sword-rpg-progression-curves.md) | 550 | XP formulas, level caps, pacing, dead zones, 80-300hr to max, design template |

### Game Systems

| File | Lines | What It Covers |
|------|-------|----------------|
| [sword-rpg-economy-design.md](sword-rpg-economy-design.md) | 484 | Multi-currency architecture, earning rates, sink ratios, inflation control, premium currency |
| [sword-rpg-weapon-acquisition.md](sword-rpg-weapon-acquisition.md) | 405 | Drop rates, boss loot tables, rarity tiers, enhancement layers, pity systems |
| [sword-rpg-boss-pve-design.md](sword-rpg-boss-pve-design.md) | 500 | HP curves, attack patterns, phase thresholds, raid structure, anti-farm mechanics |
| [sword-rpg-pvp-design.md](sword-rpg-pvp-design.md) | 614 | Mode taxonomy, balance frameworks, skill vs stats, ranking systems, anti-cheat |
| [sword-rpg-world-design.md](sword-rpg-world-design.md) | 591 | Zone structure (60 islands/3 seas), NPC/mob placement, fast travel, secrets, technical architecture |

### Player Experience

| File | Lines | What It Covers |
|------|-------|----------------|
| [sword-rpg-onboarding-FTUE.md](sword-rpg-onboarding-FTUE.md) | 682 | First5min/30min/1hr flow, "Kill5 Bandits" pattern, drop-off points, no-forced-tutorial rule |
| [sword-rpg-ui-ux-patterns.md](sword-rpg-ui-ux-patterns.md) | 990 | HUD layout, damage numbers, menus, mobile adaptation, accumulating damage counter pattern |
| [sword-rpg-retention-community.md](sword-rpg-retention-community.md) | 777 | Daily loops, crew/alliance social systems, content cadence, churn analysis, community health |

### Growth & Monetization

| File | Lines | What It Covers |
|------|-------|----------------|
| [sword-rpg-monetization.md](sword-rpg-monetization.md) | 632 | Game pass pricing, developer products, battle pass gap, F2P/P2W spectrum, ethical guidelines |
| [sword-rpg-growth-strategy.md](sword-rpg-growth-strategy.md) | 587 | Update cadence, code distribution, YouTube ecosystem, Discord community, viral tactics |
| [sword-rpg-anti-exploit-architecture.md](sword-rpg-anti-exploit-architecture.md) | 2096 | Server authority model, RemoteEvent security, exploit detection, punishment ladders, Luau code patterns |

## Key Findings Summary

### The #1 Opportunity Gap
A game with **Deepwoken's combat depth** + **Blox Fruits' accessibility and content volume** has no competitor. This exact combination is unoccupied.

### Universal Design Rules (from 10+ games analyzed)
1. **Never reset player progress** — additive stacking beats level-reset rebirth
2. **Quest XP ≈1 level per quest** — the "one more quest" dopamine loop
3. **No forced tutorials** — learn-by-doing with "Kill5 Bandits" as the universal first quest
4. **Multi-currency (3+)** with activity-specific currencies prevents inflation
5. **Gacha/rolls are the#1 retention driver** — variable ratio reinforcement (slot machine psychology)
6. **5-hit M1 combos** with escalating endlag feel better than4-hit
7. **Hitlag (20-50ms freeze frames)** is the biggest "feel good" factor most games miss
8. **Parry/block/feint triangle** (Deepwoken) is the gold standard for skill-based combat
9. **Codes via YouTube creators** are the#1 zero-cost growth hack
10. **Starter island small, death minimally punishing** — containment and forgiveness in FTUE

### Games Analyzed
**Tier1 (200B+ visits)**: Blox Fruits
**Tier2 (10B+ visits)**: King Legacy, Shindo Life
**Tier3 (1B+ visits)**: Grand Piece Online, Deepwoken
**Hidden Gems**: Rogue Lineage, Arcane Odyssey, Type Soul, Project Slayers, Sword Burst Online

### Source Quality
Most data sourced from official Fandom wikis and Roblox Creator Documentation. Community sentiment synthesized from wiki discussion pages and documented player feedback patterns. Source URLs included in each file.

---

*Research compiled by16 parallel AI research agents. Shareable to any AI agent via skill reference loading.*
