# Economy & Currency Systems in Roblox Sword RPG Games

> Research document synthesizing economy design patterns from top Roblox action RPGs.
> Sources: Blox Fruits Wiki, Wikipedia (Virtual Economy), game design theory.
> Generated: 2026-06-01

---

## Table of Contents

1. [Currency Architecture per Game](#1-currency-architecture-per-game)
2. [Earning Rates & Progression Scaling](#2-earning-rates--progression-scaling)
3. [Currency Sinks & Inflation Control](#3-currency-sinks--inflation-control)
4. [Premium Currency & Monetization](#4-premium-currency--monetization)
5. [Economy Health Indicators](#5-economy-health-indicators)
6. [Economy Design Template](#6-economy-design-template)
7. [Sources](#7-sources)

---

## 1. Currency Architecture per Game

### Overview: Multi-Currency Pattern

Every top Roblox sword RPG uses a **multi-currency system** with at least 2-3 distinct currencies that gate different content tiers. This is the industry-standard approach to creating meaningful progression walls and multiple engagement loops.

| Game | Currencies | Type | Purpose |
|------|-----------|------|---------|
| **Blox Fruits** | Money (Beli) | Soft / Primary | General purchases: swords, guns, boats, fighting styles, fruits from dealer |
| | Fragments | Mid-tier / Earned | Endgame content: fruit awakening, race changes, fighting style unlocks, skins, aura colors |
| | Valor | Activity-specific | Sea content only: Shipwright subclass upgrades |
| | Robux | Premium (real money) | Permanent fruits, 2x boosts, gamepasses, fruit storage |
| | Event currencies | Seasonal | Limited-time shops: Bones, Candy, Confetti, Hearts, Candy Corn |
| **King Legacy** | Beli | Soft / Primary | Swords, fruits, fighting styles, boats |
| | Gems | Hard / Premium-ish | Fruit rerolls, rare items, some exclusive purchases |
| | Robux | Premium | Permanent fruits, 2x EXP, race rerolls, gamepasses |
| **Grand Piece** | Beli | Soft / Primary | Weapons, devil fruits, boats, fighting styles |
| | Gems | Premium-ish | Rare items, stat resets, cosmetics |
| | Robux | Premium | Gamepasses, boosts, exclusive items |
| **Shindo Life** | Ryo | Soft / Primary | Bloodlines, sub-abilities, companions, items |
| | Spins | Hard / Premium | Rolling for bloodlines (gacha mechanic) |
| | Robux | Premium | Spin purchases, private servers, gamepasses |
| **Anime Adventures** (tower defense RPG) | Gems / Gold | Dual soft | Summoning units, upgrades, shop purchases |
| | Robux | Premium | Premium summons, fast-track |

### Key Design Patterns

**Pattern 1: Progression-Gated Currencies**
Blox Fruits is the clearest example. Money is available from Sea 1. Fragments unlock in Sea 2. Valor unlocks in Sea 3 (and only from sea events). Each new currency represents a new progression tier and forces players to engage with different content loops.

> "Fragments are considerably more difficult to obtain, being dropped in smaller amounts and usually requiring special effort, separate from normal grinding, to gain a large amount." -- Blox Fruits Wiki

**Pattern 2: Activity-Specific Currencies**
Valor in Blox Fruits can *only* be earned from sea events and can *only* be spent at the Shipwright Teacher. This creates a contained economy that doesn't inflate the broader system.

**Pattern 3: Seasonal/Event Currencies**
Temporary currencies (Candy during Christmas, Confetti during party events) create FOMO and time-limited engagement. They vanish from the economy after the event, acting as a natural deflation mechanism.

---

## 2. Earning Rates & Progression Scaling

### Blox Fruits Earning Sources (Verified from Wiki)

#### Money (Beli) Sources

| Source | Amount | Notes |
|--------|--------|-------|
| Defeating enemies | Varies by level | Scales with quest level |
| Completing quests | Varies by level | Primary income loop |
| Chests | ~$1,000-5,000 each | Farmable via server hop exploit |
| Bosses | ~$15,000-50,000+ | With quest bonus |
| Sea Beasts | ~$225,000-450,000 | With 2x Money gamepass |
| Raid Bosses (Darkbeard, rip_indra) | High amounts | Requires rare spawn items |
| Fish (Fishing) | Variable | Via Fisherman NPC |
| Sunken Chests | Variable | Via fishing system |
| Sea Events | Variable | Completing sea encounters |

**Estimated Beli per hour by progression stage:**

| Stage | Method | Est. Beli/hr | Notes |
|-------|--------|-------------|-------|
| Early (Lv 1-100) | Quest grinding | 50K-200K | Starter islands |
| Mid (Lv 100-700) | Quest + boss farming | 200K-1M | Second Sea content |
| Late (Lv 700-1500) | Sea Beast + quests | 1M-5M | Third Sea, with 2x Money |
| Endgame (Lv 1500+) | Sea Beasts + raids | 5M-15M+ | Optimized farming routes |
| **Hard cap** | **$1,000,000,000** | -- | Maximum wallet capacity |

#### Fragments Sources

| Source | Amount | Location |
|--------|--------|----------|
| Raids (fast clear) | 1,000 | Second/Third Sea |
| Raids (slow clear) | 300-600 | Second/Third Sea |
| Darkbeard | 1,500 | Second Sea |
| rip_indra True Form | 1,500 | Third Sea |
| Dough King | 2,000 | Third Sea |
| Leviathan | 1,000 | Third Sea (requires Frozen Dimension) |
| Cake Prince | 1,000 | Third Sea (requires 500 kills) |
| Terrorshark | 300 | Third Sea |
| Sea Beast | 150-250 | Second/Third Sea |
| Ship Raid | 125-200 | Second/Third Sea |
| Elite Pirate | 100 | Third Sea |
| Fishing (Sunken Chest) | 1,000-3,000 | Second/Third Sea |
| Fragment Chests | 100-200 | Treasure/Mirage Islands |
| **Hard cap** | **1,000,000,000** | -- |

**Fragment spending total for full completion: ~686,950 fragments** (excluding rerolls/resets)

#### Valor Sources (Sea Events Only)

| Source | Valor Amount |
|--------|-------------|
| Piranha | 75 |
| Shark | 100 |
| Ship Raid (full) | 501 |
| Haunted Ship Raid | 200 |
| Sea Beast | 350 |
| Ghost Ship Raid | 600 |
| Terrorshark | 1,000 |
| Leviathan | 2,200 |
| **Hard cap** | **5,000** |

**Total Valor needed to max Shipwright: 17,300** (plus 12,800 fragments)

### Scaling Design Insights

1. **Earning rates scale exponentially with progression** -- early players earn ~50K/hr, endgame players earn ~15M/hr, a 300x difference. Prices scale similarly to maintain meaningful goals at each tier.

2. **Caps prevent hoarding** -- Money caps at1B, Fragments at 1B, Valor at only 5K. The low Valor cap forces active engagement with sea content rather than passive accumulation.

3. **Multiple earning paths per currency** prevent single-method dominance. Fragments can come from raids, bosses, sea events, or fishing, keeping gameplay varied.

4. **2x Money Gamepass** (450 Robux) is one of the most popular purchases, effectively halving the grind time for the primary currency. It stacks with Roblox Plus and enchantments.

---

## 3. Currency Sinks & Inflation Control

### What Players Spend Currency On

#### Blox Fruits Money (Beli) Sinks

| Category | Examples | Price Range |
|----------|---------|-------------|
| **Weapons** (Swords/Guns) | Saber, Shisui, Tushita, Kabucha, Acidum Rifle | $50K - $5M+ |
| **Fighting Styles** | Dark Step, Electric, Dragon Breath, Superhuman, Godhuman | $750K - $5M each |
| **Fruits** (from Dealer) | Common to Mythical (stock rotates) | $5K - $3,000,000+ |
| **Boats** | Various tiers | $1K - $500K |
| **Accessories** | Various accessories | $50K - $1M+ |
| **Raid Chips** | Microchip to start raids | $100K each |
| **Abilities** | Instinct (Observation Haki), Aura (Buso Haki) | $750K - $5M |

#### Blox Fruits Fragment Sinks

| Category | Cost |
|----------|------|
| Full fruit awakening (all fruits) | 172,800 frags |
| All Race V4 Awakenings | 187,250 frags |
| All Fighting Styles | 31,500 frags |
| All Crew Slots | 30,000 frags |
| All Aura Colors | 37,500 frags |
| All Dragon Skins | 91,000 frags |
| Shipwright Max | 15,800 frags |
| Stat Resets / Race Rerolls | 2,500 frags each (repeatable) |
| **Total to max everything** | **~686,950 frags** |

### Inflation Control Mechanisms

| Mechanism | How It Works | Effectiveness |
|-----------|-------------|---------------|
| **Hard currency caps** | Money max 1B, Fragments max 1B, Valor max 5K | **High** -- absolute ceiling on accumulation |
| **Progression-gated currencies** | Fragments only in Sea 2+, Valor only in Sea 3 | **High** -- prevents early-game currency flooding |
| **Activity-specific currencies** | Valor only from sea events | **Very High** -- contained economy, no cross-contamination |
| **Rotating stock** | Fruit Dealer inventory rotates every 4 hours | **Medium** -- creates urgency, prevents instant purchase of everything |
| **Scaling prices** | Endgame items cost millions, early items cost thousands | **High** -- always something to save for |
| **Repeatable sinks** | Stat resets (2,500 frags), Race rerolls (2,500 frags) | **Medium** -- infinite drain for min-maxers |
| **Event currencies** | Seasonal currencies disappear after events | **Very High** -- complete removal from economy |
| **Upgrade/enhancement systems** | Weapon enchantments via scrolls | **High** -- probabilistic, potentially infinite sink |
| **One-way premium** | Robux cannot convert back to real money | **Total** -- no arbitrage possible |

### Gold Sink Design: The Blox Fruits Model

Blox Fruits uses a **layered sink architecture**:

```
Layer 1: Progression Sinks (one-time)
  └─ Swords, Fighting Styles, Abilities (mandatory for progression)
  └─ Total: ~$30-50M beli + ~200K fragments

Layer 2: Optimization Sinks (repeatable)
  └─ Stat resets, Race rerolls, Enchantment scrolls
  └─ Effectively infinite

Layer 3: Collection Sinks (optional)
  └─ All skins, aura colors, crew slots
  └─ ~500K+ fragments

Layer 4: Cosmetics / Status Sinks
  └─ Titles (require $5M/$20M/$50M money held)
  └─ Rare cosmetics, limited items
```

### King Legacy Sink Pattern

King Legacy uses a similar model with Beli for general progression and Gems for premium/rare items. The key difference is that Gems serve as a harder currency that bridges soft currency and premium, creating an additional progression gate.

### Shindo Life Sink Pattern

Shindo Life is notable for its **gacha-based primary sink**: Spins. Players spend Spins to roll for bloodlines (abilities), creating a potentially infinite sink. The randomness means players may need hundreds of spins to get desired bloodlines, which directly drives spin (and therefore Robux) purchases. This is the most aggressive monetization pattern among the sword RPGs.

---

## 4. Premium Currency & Monetization

### Blox Fruits Robux Shop (Verified from Wiki)

#### Products (One-time purchases)

| Item | Robux Cost | What It Does |
|------|-----------|-------------|
| Money (Sea 1) | 50-1,499 | $10K - $500K beli |
| Money (Sea 2) | 50-1,499 | $30K - $1.5M beli |
| Money (Sea 3) | 50-1,499 | $60K - $3M beli |
| Fragments | 75-1,499 | 500 - 16,000 frags |
| Simulation Data | 50-1,499 | 200 - 10,000 SD |
| 2x EXP Boost | 25-1,499 | 15min - 24hr duration |
| Stat Reset | 75 | Reset stat points |
| Change Race | 90 | Random race change |
| +1 Fruit Storage | 400 | Permanent inventory slot |
| Respawn Bosses | 50 | One-time boss respawn |
| 5x Legendary Scrolls | 800 | 3% blessing chance each |
| 3x Mythical Scrolls | 1,500 | 10% blessing chance each |

#### Gamepasses (Permanent)

| Gamepass | Robux Cost | Effect |
|----------|-----------|--------|
| 2x Boss Drops Chance | 350 | Double boss drop rates |
| Fast Boats | 350 | Exclusive fast boats |
| 2x Money | 450 | Double all money earned |
| 2x Mastery | 450 | Double mastery EXP |
| Dark Blade | 1,200 | Mythical sword (V2 + V3 upgradeable) |
| Fruit Notifier | 2,700 | Alerts when fruits spawn |
| **Total all gamepasses** | **5,500** | -- |

#### Bundles (Limited-time)

| Bundle | Robux Cost | Contents |
|--------|-----------|----------|
| Ultimate Bundle 2025 | 9,999 | 3 Permanent Fruits + currency |
| Gamepass Bundle | 4,999 | All gamepasses + currency |
| Holiday bundles | 2,999-4,999 | 2 permanent fruits + currency |

### Conversion Rates (Blox Fruits)

| Conversion | Rate |
|-----------|------|
| Sea 1: 1 Robux = 200 Beli | R$50 = $10K |
| Sea 2: 1 Robux = 300-750 Beli | R$50 = $30K (better rate) |
| Sea 3: 1 Robux = 600-2,000 Beli | R$50 = $60K (best rate) |
| Fragments: 1 Robux = 6.67-10.67 frags | R$75 = 500 frags |

**Key insight**: The Robux-to-Beli conversion rate is intentionally worse in earlier seas, incentivizing players to wait until Third Sea (where they're more invested) before spending real money. This is a classic retention + conversion optimization.

### F2P Friendliness Assessment

| Game | F2P Rating | Notes |
|------|-----------|-------|
| Blox Fruits | **High** | All content achievable without Robux. Gamepasses speed up but don't gate content. 2x Money is convenient but not required. |
| King Legacy | **Medium-High** | Most content F2P accessible. Gems are earnable but slow. |
| Grand Piece Online | **Medium-High** | Similar to King Legacy. Devil fruits can be found in-game. |
| Shindo Life | **Medium** | Bloodline gacha creates friction. Desired bloodlines may require many spins (which cost Robux). |

### What Premium Currency Buys That Soft Currency Cannot

- **Permanent fruits** (Blox Fruits) -- never lose the fruit on death
- **Exclusive weapons** (Dark Blade)
- **Multiplier gamepasses** (2x Money, 2x Mastery, 2x Boss Drops)
- **Quality-of-life** (Fruit Notifier, Fast Boats)
- **Extra storage** (+1 Fruit Storage, very high trade value)
- **Exclusive cosmetics** (mutations in bundles)

---

## 5. Economy Health Indicators

### Signs of a Healthy Economy

| Indicator | Healthy Signal | Example |
|-----------|---------------|---------|
| **Multiple viable farming methods** | Players choose based on preference, not obligation | Blox Fruits: quests, raids, sea events, fishing, chests |
| **Always something to buy** | Players at cap still have meaningful goals | Fragments cap at 1B but total spend is ~687K -- always more to unlock |
| **Currency diversity** | No single currency dominates all purchases | Money for basics, Fragments for endgame, Valor for sea content |
| **Active player engagement** | Players spend currency, not just hoard | Repeatable sinks (resets, rerolls) keep currency flowing |
| **Premium supplements, doesn't replace** | F2P players can access all content | Blox Fruits gamepasses speed up but don't gate |
| **New content adds new sinks** | Each update introduces new purchases | New fighting styles, awakened abilities, skins |

### Signs of a Broken Economy

| Problem | Symptom | Cause |
|---------|---------|-------|
| **Hyperinflation** | Prices feel meaningless, everyone has max currency | Insufficient sinks, too-rapid earning rates |
| **Currency stagnation** | Players hit cap with nothing to buy | Sinks exhausted before new content |
| **Single-path optimization** | One farming method dominates all others | Poorly balanced earning rates |
| **Premium gate** | Meaningful content locked behind paywall | Frustrated F2P players leave |
| **Gacha frustration** | Core progression depends on random premium rolls | Shindo Life bloodline system is borderline |
| **Duplication exploits** | Currency values crash due to glitches | Security failures (has occurred in many Roblox games) |
| **New player alienation** | Inflation makes starter goals meaningless | Veterans have billions, new items priced for veterans |

### How Top Games Handle Economy Resets

**Blox Fruits does NOT do economy resets.** Instead, it uses:

1. **New currencies with each expansion** (Fragments with Sea 2, Valor with Sea 3) -- effectively a "soft reset" by introducing new currency types that start at zero
2. **Caps that prevent runaway accumulation** (1B money, 1B frags, 5K valor)
3. **Event currencies that expire** -- complete removal from economy
4. **New content tiers** that make previous "wealth" feel small

This approach is superior to hard resets because it doesn't punish veteran players while still giving new players a clean starting point in new content tiers.

---

## 6. Economy Design Template

### Recommended Currency Architecture for a Sword RPG

#### Tier Structure

```
┌─────────────────────────────────────────────────┐
│ PREMIUM (Robux / real money)                     │
│ ─ Permanent items, boosts, cosmetics             │
│ ─ NOT earnable in-game                           │
│ ─ One-way only (real money → premium)            │
├─────────────────────────────────────────────────┤
│ TIER 3: SPECIALIZED CURRENCY (Valor-style)       │
│ ─ Earned from specific activity (raids, PvP, sea)│
│ ─ Spent only at that activity's vendor            │
│ ─ Low cap (5K-10K)                                │
│ ─ Introduced in mid-late game                     │
├─────────────────────────────────────────────────┤
│ TIER 2: ADVANCED CURRENCY (Fragments-style)       │
│ ─ Earned from bosses, raids, events               │
│ ─ Spent on endgame progression                    │
│ ─ Medium cap (100K-1M)                            │
│ ─ Introduced in mid-game                          │
├─────────────────────────────────────────────────┤
│ TIER 1: BASE CURRENCY (Beli-style)                │
│ ─ Earned from all combat, quests, exploration     │
│ ─ Spent on weapons, skills, basic progression     │
│ ─ High cap (100M-1B)                              │
│ ─ Available from game start                       │
├─────────────────────────────────────────────────┤
│ SEASONAL CURRENCY (Event-specific)                │
│ ─ Earned only during events                       │
│ ─ Removed from economy when event ends            │
│ ─ Creates FOMO + natural deflation                │
└─────────────────────────────────────────────────┘
```

#### Recommended Earning Rate Progression

| Progression Phase | Base Currency/hr | Advanced Currency/hr | Specialized/hr |
|-------------------|-----------------|---------------------|----------------|
| **Early** (0-25% of max level) | 50K-200K | 0 | 0 |
| **Mid** (25-50%) | 200K-1M | 100-500 | 0 |
| **Late** (50-75%) | 1M-5M | 500-2,000 | 50-200 |
| **Endgame** (75-100%) | 5M-20M | 2,000-10,000 | 200-1,000 |
| **Post-cap / Veteran** | 10M-30M+ | 5,000-15,000 | 500-2,000 |

**Design rule**: At each tier, the player should earn roughly 3-5x the minimum cost of the next item they want within 1 hour of focused play. This creates a satisfying "almost there" loop without instant gratification.

#### Recommended Sink Ratios

| Sink Category | % of Total Spending | Examples |
|---------------|-------------------|---------|
| **Progression (mandatory)** | 40-50% | Weapons, skills, stat upgrades |
| **Optimization (repeatable)** | 15-25% | Respec costs, enchantment attempts, material conversion |
| **Collection (optional)** | 15-20% | Skins, aura effects, titles, cosmetics |
| **Social / Status** | 10-15% | Crew features, guild upgrades, display items |
| **Convenience / QoL** | 5-10% | Teleports, inventory expansion, fast travel |

#### Inflation Control Checklist

| Control | Implementation | Priority |
|---------|---------------|----------|
| Hard currency caps | Set maximum wallet per currency | **Critical** |
| Progression-gated currencies | New currency for each major content tier | **Critical** |
| Activity-specific currencies | Tie currency to specific content type | **High** |
| Repeatable sinks | Respecs, enchantments, random upgrades | **High** |
| Scaling prices | Endgame items cost 100-1000x early items | **High** |
| Seasonal currencies | Time-limited currencies that expire | **Medium** |
| Trading tax | Take % cut on any player-to-player trade | **Medium** |
| Durability/repair | Items degrade, require currency to maintain | **Low** (can frustrate players) |
| Anti-exploit security | Prevent duplication glitches | **Critical** |

#### Premium Monetization Recommendations

| Monetization Type | Player Reception | Revenue | Recommendation |
|-------------------|-----------------|---------|----------------|
| **Multiplier gamepasses** (2x Money) | Positive | High | **Do this** -- speeds up but doesn't gate |
| **Permanent items** (exclusive weapon/fruit) | Mixed -- can feel P2W | High | **Do carefully** -- ensure F2P alternatives exist |
| **Cosmetic-only premium** | Very positive | Medium | **Do this** -- safest, most sustainable |
| **Convenience** (fast boats, notifier) | Positive | Medium | **Do this** -- QoL without power |
| **Boosts** (2x EXP for limited time) | Positive | Medium | **Do this** -- temporary, fair |
| **Storage expansion** | Positive | High | **Do this** -- high value for traders |
| **Gacha/spin systems** | Negative/contested | Very High | **Use sparingly** -- drives revenue but risks player burnout |
| **Premium-only content** | Very negative | High | **Avoid** -- alienates F2P majority |

---

## 7. Sources

| Source | URL | Data Retrieved |
|--------|-----|---------------|
| Blox Fruits Wiki - Currencies Category | https://blox-fruits.fandom.com/wiki/Category:Currencies | List of all currencies (Money, Fragments, Valor, Bones, Candy, Confetti, Hearts, Candy Corn) |
| Blox Fruits Wiki - Money (Beli) | https://blox-fruits.fandom.com/wiki/Money | Obtainment methods, max cap (1B), earning tips, titles for wealth milestones |
| Blox Fruits Wiki - Fragments | https://blox-fruits.fandom.com/wiki/Fragments | All earning sources with exact amounts, full spending breakdown (686,950 total), obtainment tables |
| Blox Fruits Wiki - Valor | https://blox-fruits.fandom.com/wiki/Valor | Sea event earnings, Shipwright upgrade costs (17,300 total), max cap (5,000) |
| Blox Fruits Wiki - Shop | https://blox-fruits.fandom.com/wiki/Shop | Full Robux shop: currency prices, gamepasses, bundles, conversion rates |
| Blox Fruits Wiki - 2x Money | https://blox-fruits.fandom.com/wiki/2x_Money | Gamepass details, stacking mechanics |
| Wikipedia - Virtual Economy | https://en.wikipedia.org/wiki/Virtual_economy | Economy theory: standard vs premium currency, player-driven economies, inflation, secondary markets |

---

## Appendix A: Blox Fruits Fragment Spending Breakdown (from Wiki)

| Category | Fragment Cost |
|----------|-------------|
| All Fruit Awakenings | 172,800 |
| All Race V4 Awakenings | 187,250 |
| All Fighting Styles | 31,500 |
| All Crew Slots | 30,000 |
| All Aura Colors (Barista) | 37,500 |
| All Dragon Skins (Barista) | 91,000 |
| Dragon Seats (Dragon Tamer) | 10,000 |
| Shipwright Subclass (max) | 15,800 |
| Admin Panel fruit upgrades | 74,600 |
| All Eagle Skins (Barista) | 9,500 |
| Kabucha gun | 1,500 |
| Lantern boat | 1,500 |
| Cyborg race (first time) | 2,500 |
| Fishing Rods (3 types) | 6,000 |
| Sharkman Karate V3 upgrade | 10,000 |
| Titles (Grandfather + Jack of All Trades) | 5,500 |
| **TOTAL (non-repeatable)** | **~686,950** |
| Stat Resets (each) | 2,500 (repeatable) |
| Race Rerolls (each) | 2,500 (repeatable) |

## Appendix B: Blox Fruits Robux Conversion Rate Table

| Sea | Robux | Beli Received | Rate (Beli/R$) |
|-----|-------|---------------|----------------|
| Sea 1 | R$50 | 10,000 | 200 |
| Sea 1 | R$200 | 50,000 | 250 |
| Sea 1 | R$499 | 135,000 | 271 |
| Sea 1 | R$999 | 300,000 | 300 |
| Sea 1 | R$1,499 | 500,000 | 333 |
| Sea 2 | R$50 | 30,000 | 600 |
| Sea 2 | R$200 | 150,000 | 750 |
| Sea 2 | R$499 | 405,000 | 812 |
| Sea 2 | R$999 | 900,000 | 901 |
| Sea 2 | R$1,499 | 1,500,000 | 1,001 |
| Sea 3 | R$50 | 60,000 | 1,200 |
| Sea 3 | R$200 | 305,000 | 1,525 |
| Sea 3 | R$499 | 810,000 | 1,623 |
| Sea 3 | R$999 | 1,800,000 | 1,802 |
| Sea 3 | R$1,499 | 3,000,000 | 2,001 |

**Pattern**: Conversion rate improves 10x from Sea 1 to Sea 3, incentivizing late-game spending where players are more invested.

## Appendix C: Key Design Principles Summary

1. **Multiple currencies create multiple goals** -- never let a single currency satisfy all needs
2. **Progression gates currency access** -- new currencies unlock with new content tiers
3. **Activity-specific currencies prevent inflation spread** -- Valor only works for Shipwright
4. **Caps create urgency** -- low caps (Valor at 5K) force active spending
5. **Repeatable sinks prevent stagnation** -- respecs and enchantments are infinite drains
6. **Seasonal currencies act as deflation** -- event currencies disappear completely
7. **Premium should supplement, not replace** -- gamepasses speed up, F2P can reach same goals
8. **Scale earning AND spending exponentially** -- maintain 3-5 items-at-current-rate gap at each tier
9. **Never hard-reset the economy** -- use new currencies and content tiers instead
10. **Security is economy design** -- duplication exploits destroy economies faster than any design flaw
