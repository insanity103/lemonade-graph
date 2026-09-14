# Graph Report - references  (2026-09-13)

## Corpus Check
- 31 files · ~115,329 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 200 nodes · 218 edges · 38 communities (14 shown, 24 thin omitted)
- Extraction: 85% EXTRACTED · 15% INFERRED · 0% AMBIGUOUS · INFERRED: 33 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Comprehensive Bug Catalog
- Parry/Block/Feint Triangle (Deepwoken gold standard)
- Retention & Community Design Template
- Layered Defense Model (5 layers: Authority, Validation, Detection, Punishment, Monitoring)
- NPC State Machine (Idle, Patrol, Chase, Attack, Return)
- XP & Level System (exponential curve, lookup table)
- Sword RPG PvP Design Template
- Roblox Sword RPG Research Library (INDEX)
- UI/UX
- Purchase Flow (server-side validation, currency deduction)
- Community & Content Research
- Weapon Acquisition Systems
- Data Persistence Architecture
- Sword RPG UI/UX Design Template
- DataStore Security (session locking, schema validation, rate limiting)
- Arcane Odyssey Magic Imbuement (weapon behavior changes, not just damage)
- OrderedDataStore Leaderboard
- Update Cadence Strategy (bi-weekly minor, monthly major, quarterly mega)
- Project Slayers (breathing technique combos, asymmetric PvP factions)
- Type Soul (asymmetric faction design, faction-specific progression)
- GPO Purely Cosmetic Monetization Model
- Bundle & Limited-Time Offers
- Common Exploits Catalog (movement, combat, economy, network)
- Server Performance Architecture (streaming, resource budget, object pooling)
- Boss Attack Patterns & Telegraphing
- Combat System Architecture
- Combat Anti-Exploit Checklist
- Health Regeneration System
- Server-Authoritative Projectile System
- Status Effects (poison, slow, stun — tick-based)
- Dual Currency Economy (Gold + Arcane Gems)
- Ninja Legends (multi-tier reset: rebirth → prestige → evolution)
- Saber Simulator (rebirth multiplier loop, pet companions, zone unlocking)
- Progression System
- Achievement/Badge System (BadgeService integration)
- Shop & Economy System Architecture
- Shop Catalog (ModuleScript, item definitions with cost/currency)
- Developer Products (Repeatable Purchase)

## God Nodes (most connected - your core abstractions)
1. `Roblox Sword RPG Research Library (INDEX)` - 17 edges
2. `Tycoon System` - 9 edges
3. `Comprehensive Bug Catalog` - 6 edges
4. `Parry/Block/Feint Triangle (Deepwoken gold standard)` - 6 edges
5. `Retention & Community Design Template` - 6 edges
6. `NPC State Machine (Idle, Patrol, Chase, Attack, Return)` - 6 edges
7. `Sword RPG PvP Design Template` - 6 edges
8. `Purchase Flow (server-side validation, currency deduction)` - 6 edges
9. `Core Gameplay Loop (Fight-Collect-Rebirth)` - 5 edges
10. `Sword Collection System (65-75+ Weapons)` - 5 edges

## Surprising Connections (you probably didn't know these)
- `NPC State Machine (Idle, Patrol, Chase, Attack, Return)` --semantically_similar_to--> `Boss Phase System (HP threshold-based behavior changes)`  [INFERRED] [semantically similar]
  npc-ai.md → sword-rpg-boss-pve-design.md
- `Tycoon Rebirth System` --semantically_similar_to--> `Prestige/Rebirth System (Level Reset)`  [INFERRED] [semantically similar]
  tycoon.md → sword-rpg-rebirth-analysis.md
- `Complete Game Reference` --semantically_similar_to--> `Community Wiki & Reference`  [INFERRED] [semantically similar]
  sword-rpg-legendary-swords-core.md → sword-rpg-legendary-swords-wiki.md
- `Complete Game Mechanics Analysis` --semantically_similar_to--> `Complete Game Reference`  [INFERRED] [semantically similar]
  sword-rpg-legendary-swords-mechanics.md → sword-rpg-legendary-swords-core.md
- `Aggro Threat Table (damage-based, LOS check, deaggro range)` --semantically_similar_to--> `Cooldown System (per-player attack rate limiting)`  [INFERRED] [semantically similar]
  npc-ai.md → combat.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Collection-Driven Engagement Loop** — concept_sword_collection, concept_rarity_tiers, concept_rebirth_system [EXTRACTED 1.00]
- **Server Authority Pattern (combat + anti-exploit + persistence)** — anti_exploit_never_trust_client, combat_systems_network_architecture, combat_anti_exploit_checklist [EXTRACTED 1.00]
- **Communal Boss Event Social Pattern** — concept_server_event_bosses, concept_last_hit_mechanic, concept_boss_system [EXTRACTED 1.00]
- **Shared Player Data Schema (persistence ↔ inventory ↔ economy)** — data_persistence_schema_design, inventory_item_schema, shop_economy_purchase_flow [EXTRACTED 1.00]
- **Core Sword RPG Gameplay Loop (Quest-Grind-Level-Unlock)** — sword_rpg_popular_quest_grind_loop, sword_rpg_progression_xp_curve, sword_rpg_progression_sea_gates, sword_rpg_onboarding_quest_teaching, sword_rpg_popular_multi_power_stacking [EXTRACTED 1.00]
- **Retention Mechanics Stack (Gacha + Time-Gated + Social + Updates)** — sword_rpg_popular_gacha_retention, sword_rpg_retention_time_gated, sword_rpg_retention_social_systems, sword_rpg_retention_update_cadence [EXTRACTED 1.00]
- **Tycoon Production Pipeline (Dropper → Conveyor → Collector → Cash)** — tycoon_dropper, tycoon_conveyor, tycoon_collector, tycoon_cash_leaderstat [EXTRACTED 1.00]
- **XP Progression Pipeline (grant XP → level → unlock → rebirth)** — progression_xp_level, progression_unlock_system, progression_rebirth [EXTRACTED 1.00]
- **Zero-Trust Client Security Pattern** — concept_server_authoritative, concept_anti_exploit, concept_data_persistence [EXTRACTED 1.00]
- **Collection-Driven Engagement Loop** — concept_sword_collection, concept_rarity_tiers, concept_rebirth_system [EXTRACTED 1.00]
- **Communal Boss Event Social Pattern** — concept_server_event_bosses, concept_last_hit_mechanic, concept_boss_system [EXTRACTED 1.00]
- **Zero-Trust Client Security Pattern** — concept_server_authoritative, concept_anti_exploit, concept_data_persistence [EXTRACTED 1.00]

## Communities (38 total, 24 thin omitted)

### Community 0 - "Comprehensive Bug Catalog"
Cohesion: 0.15
Nodes (20): Comprehensive Bug Catalog, Anti-Exploit / Security Architecture Patterns, Area Progression via Level/Rebirth Gates, Boss System (Permanent + Server Events), Click-Based Melee Combat System, Dagon Ultimate Endgame Boss, DataStore Persistence Patterns, Design Lessons for Spiritual Successor (+12 more)

### Community 1 - "Parry/Block/Feint Triangle (Deepwoken gold standard)"
Cohesion: 0.13
Nodes (18): Combo System (hit chain, timeout, bonus multiplier), Damage Calculation (base, multiplier, armor), Hitlag & Game Feel (freeze frames, screen shake, damage numbers), Ideal Damage Formula (stat scaling, combo mult, quality, crit, armor pen), M1 Combo System (5-hit recommended, timing windows, perfect-timing bonus), Parry/Block/Feint Triangle (Deepwoken gold standard), Posture System (guard break, soft/hard caps, regen), Skill/Ability System (slot-based Z/X/C/V, mastery-gated, cooldown model) (+10 more)

### Community 2 - "Retention & Community Design Template"
Cohesion: 0.15
Nodes (14): Common Drop-Off Points, Fast First Kill Principle, Sword RPG FTUE Design Template, First Session Progression Milestones, Quest-Based Teaching, Soft Start (No Forced Tutorial), Quest-Grind-Unlock Loop, PvP Ranking & Leaderboard System (+6 more)

### Community 3 - "Layered Defense Model (5 layers: Authority, Validation, Detection, Punishment, Monitoring)"
Cohesion: 0.22
Nodes (9): Anti-Exploit Architecture (layered defense model), Behavioral Analysis (kill rate, timing consistency, bot detection), Layered Defense Model (5 layers: Authority, Validation, Detection, Punishment, Monitoring), Movement Validation (speed, teleport, fly detection), Punishment Escalation Ladder (warn → kick → temp ban → perm ban), RemoteEvent Validation Blueprint (rate limits, type schemas, gateway), Shadow Ban System (silent reward filtering for suspected exploiters), Violation Tracker (weighted scoring, escalation thresholds, decay) (+1 more)

### Community 4 - "NPC State Machine (Idle, Patrol, Chase, Attack, Return)"
Cohesion: 0.18
Nodes (13): Golden Rule: Never Trust the Client (server authority), Boss HP Curves (level-scaled, group multiplier), Boss Phase System (HP threshold-based behavior changes), Cooldown System (per-player attack rate limiting), Hit Detection Methods (Raycast, Region3, Magnitude), Hit Registration & Latency Compensation (hybrid client-server), Server-Authoritative with Client Prediction (combat network model), NPC AI System (+5 more)

### Community 5 - "XP & Level System (exponential curve, lookup table)"
Cohesion: 0.22
Nodes (9): Boss Loot Tables (zone/dungeon/raid/world boss tiers), Boss & PvE Design Reference, Raid Structure Template (rooms, waves, boss, time limit), Rogue Lineage (lineage inheritance, probability-based death, 3-life system), Battle Pass System (tiered rewards, XP-driven), Rebirth System (XP reset, multiplier, tokens), Unlock System (level-gated abilities, weapons, areas), XP & Level System (exponential curve, lookup table) (+1 more)

### Community 6 - "Sword RPG PvP Design Template"
Cohesion: 0.21
Nodes (12): M1 + Ability (Z/X/C) Combat Pattern, Anti-Cheat & Fair Play Systems, PvP Balance Framework, PvP Combat Core Mechanics (Block/Parry/Dodge/Posture), Sword RPG PvP Design Template, PvP Mode Taxonomy, Additive Awakening Model (Dominant Pattern), Rebirth / Reset Systems Analysis (+4 more)

### Community 7 - "Roblox Sword RPG Research Library (INDEX)"
Cohesion: 0.10
Nodes (26): Boss & PvE Design Reference, Sword & Combat Systems Deep Research, Economy & Currency Systems Deep Research, Sword RPG Fair Monetization Pledge (10 rules), Sword RPG Growth Strategy Playbook, Sword RPG Hidden Gems (10 underrated games), Roblox Sword RPG Research Library (INDEX), Battle Pass / Season Pass (+18 more)

### Community 8 - "UI/UX"
Cohesion: 0.36
Nodes (10): Tycoon Auto-Save System, Tycoon Building System, Tycoon Cash Leaderstat, Tycoon Collector System, Tycoon Conveyor System, Tycoon Dropper System, Tycoon Plot System, Tycoon Rebirth System (+2 more)

### Community 9 - "Purchase Flow (server-side validation, currency deduction)"
Cohesion: 0.15
Nodes (13): Sequential Data Migrations (version-based), Data Schema Design (_version, defaults, merge), Earning Rate Progression (scale 300x from early to endgame), Inflation Control Mechanisms (caps, progression gates, sinks, seasonal currencies), Multi-Currency Architecture (base/advanced/specialized/premium/seasonal), Premium Monetization Strategy (gamepasses, cosmetics, F2P-first), Currency Sink Ratios (progression 40-50%, optimization 15-25%, collection 15-20%), Item Schema (id, type, rarity, stackable, metadata, equipped) (+5 more)

### Community 11 - "Community & Content Research"
Cohesion: 0.32
Nodes (8): Community & Content Research, Community-Driven Preservation & Fan Restoration, Nostalgia as Primary Retention Driver, Game Version Lineage (Original/Remastered/Restored), Complete Game Reference, Complete Game Mechanics Analysis, Comprehensive Synthesis Document, Community Wiki & Reference

### Community 12 - "Weapon Acquisition Systems"
Cohesion: 0.38
Nodes (7): Permanent Fruit Purchases, Multi-System Power Stacking, Weapon Acquisition Systems, Boss Farming Mechanics, Weapon Enhancement System (Upgrade + Enchant + Reforge), Pity System (Bad Luck Protection), Weapon Rarity Tier System

### Community 13 - "Data Persistence Architecture"
Cohesion: 0.40
Nodes (5): Data Persistence Architecture, DataStore Budget Management (queue writes, batch reads), Inventory System Architecture, Equip/Unequip System (slot-based, type conflict resolution), Two-Player Atomic Swap Trading

### Community 14 - "Sword RPG UI/UX Design Template"
Cohesion: 0.67
Nodes (4): Damage Counter (Accumulating System), HUD Layout Template, Mobile UI Adaptations, Sword RPG UI/UX Design Template

## Knowledge Gaps
- **75 isolated node(s):** `Area Progression via Level/Rebirth Gates`, `10-Tier Weapon Rarity System`, `Posture System (guard break, soft/hard caps, regen)`, `Skill/Ability System (slot-based Z/X/C/V, mastery-gated, cooldown model)`, `Deepwoken Resonance System (rare awakened abilities with normal/corrupted/legendary variants)` (+70 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 85 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **24 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Roblox Sword RPG Research Library (INDEX)` connect `Roblox Sword RPG Research Library (INDEX)` to `Retention & Community Design Template`, `Layered Defense Model (5 layers: Authority, Validation, Detection, Punishment, Monitoring)`, `Sword RPG PvP Design Template`, `Weapon Acquisition Systems`, `Sword RPG UI/UX Design Template`?**
  _High betweenness centrality (0.233) - this node is a cross-community bridge._
- **Why does `Anti-Exploit Architecture (layered defense model)` connect `Layered Defense Model (5 layers: Authority, Validation, Detection, Punishment, Monitoring)` to `Comprehensive Bug Catalog`, `Roblox Sword RPG Research Library (INDEX)`?**
  _High betweenness centrality (0.132) - this node is a cross-community bridge._
- **Why does `Comprehensive Bug Catalog` connect `Comprehensive Bug Catalog` to `Layered Defense Model (5 layers: Authority, Validation, Detection, Punishment, Monitoring)`, `Data Persistence Architecture`?**
  _High betweenness centrality (0.105) - this node is a cross-community bridge._
- **What connects `Area Progression via Level/Rebirth Gates`, `10-Tier Weapon Rarity System`, `Posture System (guard break, soft/hard caps, regen)` to the rest of the system?**
  _75 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Parry/Block/Feint Triangle (Deepwoken gold standard)` be split into smaller, more focused modules?**
  _Cohesion score 0.13071895424836602 - nodes in this community are weakly interconnected._
- **Should `Roblox Sword RPG Research Library (INDEX)` be split into smaller, more focused modules?**
  _Cohesion score 0.09846153846153846 - nodes in this community are weakly interconnected._