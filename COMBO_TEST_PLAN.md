# Combo System Test Plan

## Test 1: Basic 5-Hit Combo
1. Equip a sword
2. Click/press E 5 times rapidly
3. Verify: combo counter shows 1x, 2x, 3x, 4x, 5x
4. Verify: each hit deals damage (check floating numbers)
5. Verify: hit 5 has visible longer recovery

## Test 2: Combo Reset
1. Hit 3 times, then wait 2 seconds
2. Attack again
3. Verify: counter resets to 1x (not 4x)

## Test 3: Endlag Enforcement
1. Click as fast as possible
2. Verify: can't attack faster than endlag allows
3. Verify: hits 1-2 are fast, hits 3-4 slower, hit 5 has longest pause

## Test 4: Hitlag Feel
1. Hit an enemy
2. Verify: brief freeze on both player and enemy
3. Verify: hit 5 has the most noticeable freeze
4. Verify: screen shake increases with combo count

## Test 5: Combo Damage Scaling
1. Hit the same enemy 5 times
2. Verify: hit 5 deals ~30% more damage than hit 1
3. Check floating numbers show increasing damage

## Test 6: Auto-Attack Integration
1. Press Q to enable auto-attack
2. Verify: auto-attack respects combo endlag
3. Verify: combo counter advances properly during auto-attack
4. Verify: auto-attack doesn't skip hits or break combo

## Test 7: Combo Reset on Death
1. Build a 5-hit combo
2. Die to an enemy
3. Respawn and attack
4. Verify: combo starts fresh at 1x

## Test 8: Unarmed Combat Hitlag
1. Unequip sword
2. Press E to punch
3. Verify: hitlag still applies (brief freeze)

## Test 9: Pity System
1. Kill many enemies without rare drops
2. Verify: after ~50 kills, a rare drop is guaranteed
3. Verify: pity counter resets after a rare drop

## Test 10: Multiplayer
1. Two players attack the same enemy
2. Verify: each player has independent combo counters
3. Verify: hitlag doesn't affect other players' movement

## Known Limitations
- Combo counter is per-player, not per-weapon
- Hitlag uses WalkSpeed freeze (not animation pause) — may feel slightly different on laggy connections
- Perfect timing bonus not yet implemented (design only)
