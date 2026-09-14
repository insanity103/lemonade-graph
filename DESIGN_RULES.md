# Design Rules — Lemonade Sword RPG

## Core Loop
Quest → Kill → Level → Unlock Zone → Boss → Rebirth → Repeat

## The 10 Non-Negotiable Rules

### 1. Server Authority
- ALL game state mutations server-side
- Never trust client for damage, currency, inventory, position
- See: sword-rpg-anti-exploit-architecture.md, combat.md

### 2. Never Reset Player Progress
- Additive stacking (Blox Fruits model) beats level-reset
- Rebirth unlocks NEW content, doesn't erase old
- See: sword-rpg-rebirth-analysis.md

### 3. Quest XP ≈ 1 Level Per Quest
- The 'one more quest' dopamine loop
- XP formula: ceil(1.5 * L^2.25 + 50)
- See: sword-rpg-progression-curves.md

### 4. No Forced Tutorials
- Soft start: 'Kill 5 Bandits' teaches combat, questing, navigation in 2 min
- See: sword-rpg-onboarding-FTUE.md

### 5. Multi-Currency (3+)
- Base (Gold), Advanced (Fragments), Specialized (Valor)
- Activity-specific currencies prevent inflation
- See: sword-rpg-economy-design.md

### 6. 5-Hit M1 Combos
- Escalating endlag (0.2s → 0.5s)
- Perfect-timing bonus: +5% damage for hitting within 80ms window
- See: sword-rpg-combat-systems.md

### 7. Hitlag (20-50ms Freeze Frames)
- Biggest 'feel good' factor most Roblox games miss
- See: sword-rpg-combat-systems.md

### 8. YouTube Codes for Growth
- Sub2[Creator] permanent codes = zero-cost marketing army
- 72-hour creator exclusivity window
- See: sword-rpg-growth-strategy.md

### 9. Starter Area Small, Death Forgiving
- Starter island reduced to avoid confusing new players
- Respawn at home, no item/currency/level loss
- See: sword-rpg-onboarding-FTUE.md

### 10. Pity Systems for RNG
- No major Roblox sword RPG has pity — first-mover advantage
- Guaranteed drop after X attempts
- See: sword-rpg-weapon-acquisition.md

## The Big Opportunity
A game with Deepwoken's combat depth + Blox Fruits' accessibility = no competitor

## Legendary Swords RPG Lessons
- Preserve: collection loop, rebirth-scaled drops, environmental secrets
- Add: combo combat, abilities, anti-exploit, trading, mobile
- Avoid: last-hit-takes-all, no QoL, pay-for-power gamepasses
