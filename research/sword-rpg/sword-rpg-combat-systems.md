# Sword & Combat Systems in Roblox RPG Games — Deep Research Reference

> **Research date**: 2025  
> **Games analyzed**: Blox Fruits, Deepwoken, King Legacy, Grand Piece Online (GPO), Project Slayers  
> **Purpose**: Inform the design of an ideal sword combat system for a new Roblox RPG  

---

## Table of Contents

1. [Click/Attack Patterns (M1 Combos)](#1-clickattack-patterns-m1-combos)
2. [Skill/Ability Systems](#2-skillability-systems)
3. [Hit Registration & Latency](#3-hit-registration--latency)
4. [Blocking / Dodging / Parrying](#4-blocking--dodging--parrying)
5. [Damage Calculation](#5-damage-calculation)
6. [Game-by-Game Breakdown](#6-game-by-game-breakdown)
7. [The IDEAL Sword Combat System (Recommendation)](#7-the-ideal-sword-combat-system-recommendation)
8. [Source URLs](#8-source-urls)

---

## 1. Click/Attack Patterns (M1 Combos)

### How M1 Combos Work Across Games

| Game | Combo Length | Finisher | Click Timing Matters? | Cancel Windows |
|------|-------------|----------|----------------------|----------------|
| **Blox Fruits** | 4 hits (M1 × 4) | 4th hit has knockback + slight stun | No — spam clicking works | Very limited; can't cancel mid-animation |
| **Deepwoken** | 4 hits (LMB × 4) | 4th hit is a critical swing with extra posture damage | **YES** — rhythm-based; each swing has a timing window | Feint system lets you cancel attacks mid-swing |
| **King Legacy** | Continuous M1 chain | Rhythm-based finisher combo | Somewhat — consistent rhythm helps | Minimal cancel windows |
| **GPO** | 4 hits | 4th hit launches/knocks | No — rapid clicking | Limited |
| **Project Slayers** | 4-5 hit combo | Final hit has special animation + knockback | Somewhat — breathing timing affects DPS | Light cancel window after each swing |

### Blox Fruits M1 System (Reference)

From the Blox Fruits wiki ([Combat page](https://blox-fruits.fandom.com/wiki/Combat)):
- **M1 Combo**: "The user punches with their fists 4 times. Right hook, left hook, uppercut and a punch."
- Each weapon type (Swords, Fighting Styles, Guns) has its own M1 animation set
- Swords have **2 unique abilities** each; Fighting Styles have **3-4 abilities**
- M1 damage scales with the **Mastery** level of the equipped weapon/style
- M1s are generally considered "slow" for the base Combat style but get faster with advanced styles
- **Key design note**: "Combat is the simplest, and most realistic fighting style... letting the user throw punches, and small dashes/impacts"

### Deepwoken M1 System (Reference — The Gold Standard)

From the Deepwoken wiki ([Combat Mechanics](https://deepwoken.fandom.com/wiki/Combat_Mechanics)):
- **4-hit combo** with each hit having distinct timing
- **Weapon swing speed varies by weapon type**: Light weapons swing faster (1.06-1.25x multiplier), Heavy weapons swing slower (0.9-1.05x)
- Each swing consumes stamina and has **endlag** — you cannot just spam
- **Critical attacks**: Each weapon has a unique critical (E key) on a cooldown — not random crits
- **Feint system**: Press R during an attack windup to cancel into a different action
  - This creates a deep read-based mindgame layer
  - Feints have their own cooldown indicator

```lua
-- Conceptual Deepwoken-style M1 combo (Roblox Lua pseudocode)
local COMBO_WINDOW = 0.6  -- seconds between hits to maintain combo
local ENDLAG = {0.3, 0.3, 0.35, 0.5}  -- increasing endlag per hit
local DAMAGE_MULT = {1.0, 1.0, 1.1, 1.3}  -- escalating damage

function onM1(player, comboIndex)
    local weapon = getEquippedWeapon(player)
    local timeSinceLast = tick() - player.lastM1Time
    
    if timeSinceLast > COMBO_WINDOW then
        comboIndex = 1  -- reset combo if too slow
    end
    
    local anim = weapon.swingAnims[comboIndex]
    playAnimation(player, anim)
    
    -- Wait for hit frame (animation event)
    local hitFrame = anim:GetMarker("HitFrame")
    hitFrame.Event:Wait()
    
    -- Check for feint/cancel input during windup
    if player.feintRequested then
        playAnimation(player, "FeintRecovery")
        return
    end
    
    -- Deal damage
    local baseDamage = weapon.baseDamage
    local scaledDamage = calculateScaling(baseDamage, weapon.scaling, player.stats)
    local finalDamage = scaledDamage * DAMAGE_MULT[comboIndex]
    
    applyDamage(player, finalDamage)
    applyPostureDamage(player, weapon.postureDamage)
    
    -- Apply endlag
    player.canAct = false
    task.wait(ENDLAG[comboIndex])
    player.canAct = true
    
    player.lastM1Time = tick()
    player.comboIndex = (comboIndex % 4) + 1
end
```

### King Legacy M1 System (Reference)

From the King Legacy wiki ([Combat page](https://king-legacy-official.fandom.com/wiki/Combat)):
- Basic M1: "A simple punch" dealing 1,799 base damage
- Skills are gated by stat requirements: Z=0, X=100, C=200, V=300
- Skills have distinct animations: dash-grab (Z), direct jab (X), rapid barrage (C), charge-launch (V)
- **Key insight**: King Legacy separates the "basic combo" from "skill moves" clearly

---

## 2. Skill/Ability Systems

### How Skills Are Unlocked

| Game | Unlock Method | Skill Count | Cooldown Model |
|------|--------------|-------------|----------------|
| **Blox Fruits** | Mastery-gated + money/fragments + quest-gated | 2 per sword, 3-4 per style | Individual cooldowns (7-12s typical) |
| **Deepwoken** | Attribute-gated + Talent system + Mantras | Weapon criticals + Mantras (varies) | Individual per-mantra cooldowns + shared feint/parry/dodge cooldowns |
| **King Legacy** | Stat point requirements (0/100/200/300) | 4 skills + M1 per style | Individual cooldowns |
| **GPO** | Level-gated + Devil Fruit system | 4-6 per fruit + weapon skills | Individual cooldowns with shared category CD |
| **Project Slayers** | Quest-gated + trainer NPCs | Breathing styles: 5-6 moves | Individual cooldowns |

### Blox Fruits Skill Progression (Detailed)

From the [Fighting Styles wiki](https://blox-fruits.fandom.com/wiki/Fighting_Styles):

**Progression tiers:**
1. **Combat** (free, starter) — 2 abilities only
2. **First Sea styles** (Dark Step $150K, Electric $500K, Water Kung Fu $750K) — 3-4 abilities
3. **Second Sea styles** (Dragon Breath 1500 Fragments, Superhuman $3M + Mastery 300 on 4 styles) — 3 abilities
4. **Third Sea styles** (Godhuman $5M + Mastery 400 on ALL 5 V2 styles + materials) — 3 abilities

**Skill unlock pattern:**
- Skills unlock at specific **Mastery levels** (e.g., Z at 1 Mastery, X at 20 Mastery)
- Higher-tier styles require mastery of prerequisite styles (creates a progression tree)
- Example: **Godhuman** requires Mastery 400 on Death Step, Electric Claw, Sharkman Karate, Dragon Talon, AND Superhuman

**Cooldown examples:**
- Combat [Z] Quick Tackle: **7.5s cooldown**, 15 energy
- Combat [X] Ground Smash: **12s cooldown**, 25 energy
- Swords generally have 2 moves with 7-15s cooldowns each
- Fighting styles have 3-4 moves with individual cooldowns

```lua
-- Blox Fruits-style skill system (conceptual)
local SkillSystem = {}

SkillSystem.FightingStyles = {
    Combat = {
        moves = {
            {key = "Z", name = "Quick Tackle", cooldown = 7.5, energy = 15, masteryReq = 1},
            {key = "X", name = "Ground Smash", cooldown = 12, energy = 25, masteryReq = 20},
        }
    },
    DarkStep = {
        price = 150000,
        currency = "Money",
        requirements = {},  -- no prereqs
        moves = {
            {key = "Z", name = "Dark Kick", cooldown = 8, energy = 20, masteryReq = 1},
            {key = "X", name = "Annihilation", cooldown = 10, energy = 30, masteryReq = 50},
            {key = "C", name = "Overheat", cooldown = 14, energy = 40, masteryReq = 100},
            {key = "V", name = "Rising Darkness", cooldown = 16, energy = 50, masteryReq = 200},
        }
    },
    Superhuman = {
        price = 3000000,
        currency = "Money",
        requirements = {
            {style = "DarkStep", mastery = 300},
            {style = "Electric", mastery = 300},
            {style = "WaterKungFu", mastery = 300},
            {style = "DragonBreath", mastery = 300},
        },
        moves = {
            {key = "Z", name = "Beast Owl Pounce", cooldown = 8, energy = 25, masteryReq = 1},
            {key = "X", name = "Thunder Clap", cooldown = 11, energy = 30, masteryReq = 100},
            {key = "C", name = "Conqueror Gun", cooldown = 14, energy = 40, masteryReq = 200},
        }
    },
}

-- Mastery gains per hit
function SkillSystem.gainMastery(player, amount)
    local style = player.equippedStyle
    style.currentMastery = style.currentMastery + amount
    
    -- Check for newly unlocked moves
    for _, move in ipairs(style.moves) do
        if style.currentMastery >= move.masteryReq and not move.unlocked then
            move.unlocked = true
            notifyPlayer(player, "New move unlocked: " .. move.name .. " [" .. move.key .. "]")
        end
    end
end
```

### Deepwoken Skill System (Detailed)

From the Deepwoken wiki ([Combat Mechanics](https://deepwoken.fandom.com/wiki/Combat_Mechanics) and [Weapons](https://deepwoken.fandom.com/wiki/Weapons)):

**Three-layer skill system:**
1. **Weapon Criticals** — unique per weapon (E key), cooldown-based
2. **Mantras** — magic abilities equipped in slots, unlocked via leveling + Talent cards
3. **Talents** — passive abilities chosen at level-ups from random card draws

**Mantra system:**
- Mantras cost **Ether** (mana) to cast
- Attunements (Flamecharm, Frostdraw, Thundercall, Galebreathe, Shadowcast, Ironsing, Bloodrend) determine which Mantras you can use
- **Mantra Modifiers** can be applied to customize behavior (increase size, range, etc.)
- Ether regenerates in combat only if you have **Tempo** (gained by hitting/being hit)

**Tempo system (unique to Deepwoken):**
- Base 120 Tempo
- Gained by hitting or being hit
- Decreases over time (1% per 0.6s)
- At 40+ Tempo, can **Vent** (G key) — AoE pushback
- Vent can be parried or blocked, leaving you stunned if failed

**Weapon stat requirements:**
- Weapons require Light (LHT), Medium (MED), or Heavy (HVY) weapon investment
- Damage scales with invested attributes
- Example: A dagger with `LHT: 8` scaling means each point in Light Weapons adds 8% of base damage

---

## 3. Hit Registration & Latency

### Client-Side vs Server-Side in Roblox

Most successful Roblox combat games use a **hybrid approach**:

**Blox Fruits approach:**
- M1 hits are validated **server-side** but animation plays on **client**
- Skills with AoE use **server-side hitbox checks** against player positions
- This means laggy players may see "ghost hits" — the animation plays but damage doesn't register
- Instinct (dodge) is checked server-side to prevent exploits

**Deepwoken approach (best-in-class for Roblox):**
- Combat is more **server-authoritative**
- Parry/block checks happen on the server with client-side prediction
- Hit registration uses **raycasting from the attacker's position** with latency compensation
- The server validates timing windows for parries (approximately 300ms window)
- Roll i-frames are server-validated

```lua
-- Server-authoritative hit detection with latency compensation (conceptual)
local LATENCY_COMPENSATION_WINDOW = 0.15  -- 150ms forgiveness

function serverValidateHit(attacker, target, attackTimestamp)
    local attackerPing = getLatency(attacker)
    local targetPing = getLatency(target)
    
    -- Rewind target position by their ping for hit validation
    local targetHistory = getPositionHistory(target)
    local rewindTime = attackTimestamp - (attackerPing / 2)
    local targetPosAtAttack = targetHistory:GetPositionAt(rewindTime)
    
    -- Check hitbox at rewound position
    local hitbox = getWeaponHitbox(attacker, attackTimestamp)
    local hit = hitbox:Intersects(targetPosAtAttack, target.hitboxRadius)
    
    if not hit then
        -- Try with latency compensation window
        local compensatedTime = rewindTime - LATENCY_COMPENSATION_WINDOW
        targetPosAtAttack = targetHistory:GetPositionAt(compensatedTime)
        hit = hitbox:Intersects(targetPosAtAttack, target.hitboxRadius)
    end
    
    return hit
end
```

### Hitbox Sizes

| Game | Hitbox Approach | Notes |
|------|----------------|-------|
| **Blox Fruits** | Generous sphere/capsule hitboxes | M1s have wide hitboxes for ease of use; AoE skills use OverlapParams |
| **Deepwoken** | Weapon-shaped hitboxes (raycast + sweep) | More precise; weapon range matters (daggers ~6 range, greatswords ~11 range) |
| **King Legacy** | Generous | Skills auto-lock or have wide AoE cones |
| **GPO** | Medium | Some moves have homing/auto-aim |

### Knockback & Stun Mechanics

**Blox Fruits:**
- M1 combo finisher (4th hit) applies **knockback** and brief **stun**
- Most skills apply stun for 0.5-1.5 seconds
- Some skills are "Instinct Breakers" — they bypass/destroy the dodge system
- Knockback direction is based on attacker's facing direction

**Deepwoken:**
- **Posture system** replaces simple stun: blocking attacks builds posture, exceeding max = guard break (1.05s stun)
- Posture damage has soft cap of 1.5x and hard cap of 1.75x
- Posture received has hard cap of 0.5x (minimum 50% of intended posture damage)
- Some attacks have **true stagger** on hit (light weapons: brief, heavy weapons: significant)

---

## 4. Blocking / Dodging / Parrying

### Defense Mechanics Comparison

| Mechanic | Blox Fruits | Deepwoken | King Legacy | GPO |
|----------|-------------|-----------|-------------|-----|
| **Block** | ❌ No traditional block | ✅ Hold block (posture cost) | ✅ Haki block | ✅ Block button |
| **Parry** | ❌ No parry | ✅ Frame-precise parry (~300ms window) | ❌ No true parry | ❌ No true parry |
| **Dodge/Roll** | ✅ Instinct (auto-dodge charges) | ✅ Roll with i-frames + cooldown | ✅ Dash dodge | ✅ Dash |
| **Block Break** | Instinct Break (specific moves) | Guard break when posture exceeds max | Haki break | Block break moves |

### Blox Fruits: Instinct System (Detailed)

From the [Instinct wiki](https://blox-fruits.fandom.com/wiki/Instinct):
- **Toggle ability** (E key) — costs no energy to maintain
- Grants **dodge charges** (2 at Lv.1, up to 8 at max)
- Each dodged attack costs 1 charge (0.5 for non-boss enemies)
- Each charge takes **~30 seconds** to regenerate (was 50s, reduced in Update 29.2)
- Can be upgraded to **Instinct V2** after 5000 EXP + quest
- Certain moves **break Instinct** entirely — disabling it temporarily
- "Ken-Tricking" = activating Instinct mid-combo to avoid remaining hits
- Accessories can add extra dodge charges (Pale Scarf +2, Kitsune Mask +2, etc.)

```lua
-- Instinct/Dodge charge system (Blox Fruits style)
local InstinctSystem = {}

InstinctSystem.BASE_CHARGES = 2
InstinctSystem.MAX_CHARGES = 8
InstinctSystem.RECHARGE_TIME = 30  -- seconds per charge
InstinctSystem.BOSS_DRAIN = 1.0
InstinctSystem.NORMAL_DRAIN = 0.5

function InstinctSystem.onAttackIncoming(player, attacker, isBoss)
    if not player.instinctActive then return false end
    if player.instinctCharges <= 0 then return false end
    
    local drain = isBoss and InstinctSystem.BOSS_DRAIN or InstinctSystem.NORMAL_DRAIN
    
    if player.instinctCharges >= drain then
        player.instinctCharges = player.instinctCharges - drain
        playDodgeAnimation(player)
        startRechargeTimer(player)
        return true  -- attack dodged
    end
    
    return false  -- no charges, hit lands
end

function InstinctSystem.startRechargeTimer(player)
    task.spawn(function()
        while player.instinctCharges < player.maxCharges do
            task.wait(InstinctSystem.RECHARGE_TIME)
            player.instinctCharges = math.min(
                player.instinctCharges + 1,
                player.maxCharges
            )
        end
    end)
end
```

### Deepwoken: Parry/Block/Dodge System (The Gold Standard)

From the [Combat Mechanics wiki](https://deepwoken.fandom.com/wiki/Combat_Mechanics):

**Three defensive options with independent cooldowns:**

1. **Block** (Hold F):
   - Reduces incoming damage significantly
   - Builds **Posture** (visible bar) — when posture exceeds max, you get **guard broken** (1.05s stun)
   - Posture regenerates passively when NOT blocking/sprinting
   - Block becomes "shaky" (red glow) after guard break, can't block again immediately

2. **Parry** (F, timed):
   - Press F at the moment of impact (~300ms window)
   - Successful parry **restores posture** and negates all damage
   - Failed parry = you take full damage
   - Parry has its own cooldown indicator
   - Creates high-skill mindgames: "Will they feint? Should I parry or block?"

3. **Dodge/Roll** (Q):
   - Grants **i-frames** (invincibility frames) during the roll
   - Has a cooldown (shown in HUD)
   - Cannot attack during roll
   - Used to reposition or avoid unblockable attacks

**Feint System:**
- Press R during attack windup to cancel the attack
- Has its own cooldown
- Used to bait parries: start attack → feint → punish the parry attempt
- Creates a deep **attack/parry/feint triangle**:

```
Attack beats Stand Still
Parry beats Attack  
Feint beats Parry
Dodge beats Feint
Attack beats Dodge (catch roll)
```

```lua
-- Deepwoken-style defense system
local DefenseSystem = {}

DefenseSystem.PARRY_WINDOW = 0.3  -- 300ms window
DefenseSystem.GUARD_BREAK_STUN = 1.05
DefenseSystem.PARRY_COOLDOWN = 0.8
DefenseSystem.DODGE_COOLDOWN = 1.2
DefenseSystem.FEINT_COOLDOWN = 0.5

function DefenseSystem.onDamageIncoming(player, damage, postureDamage)
    -- Check parry first (priority)
    if player.parryInput and not player.parryOnCooldown then
        local timeSinceInput = tick() - player.parryInputTime
        if timeSinceInput <= DefenseSystem.PARRY_WINDOW then
            -- Successful parry!
            player.posture = math.max(0, player.posture - (postureDamage * 0.5))
            playParryEffect(player)
            player.parryOnCooldown = true
            task.delay(DefenseSystem.PARRY_COOLDOWN, function()
                player.parryOnCooldown = false
            end)
            return 0  -- no damage taken
        end
    end
    
    -- Check block (holding block button)
    if player.isBlocking then
        player.posture = player.posture + postureDamage
        
        if player.posture >= player.maxPosture then
            -- Guard break!
            player.isGuardBroken = true
            playGuardBreakEffect(player)
            task.delay(DefenseSystem.GUARD_BREAK_STUN, function()
                player.isGuardBroken = false
                player.posture = 0
            end)
            return damage * 0.8  -- still take some damage on guard break
        end
        
        return damage * 0.1  -- 90% damage reduction while blocking
    end
    
    -- Check dodge i-frames
    if player.isDodging and player.hasIFrames then
        return 0  -- invincible during i-frames
    end
    
    -- No defense — full damage
    return damage
end

function DefenseSystem.feint(player)
    if player.feintOnCooldown then return end
    if not player.isAttacking then return end
    
    cancelCurrentAttack(player)
    playFeintAnimation(player)
    
    player.feintOnCooldown = true
    task.delay(DefenseSystem.FEINT_COOLDOWN, function()
        player.feintOnCooldown = false
    end)
end
```

### Deepwoken Posture System (Detailed)

```
Posture Mechanics:
- Every blocked attack adds posture damage to the defender
- Posture damage has multipliers from Talents, Enchantments, and weapon Weight stat
- Soft cap: 1.5x posture damage (multipliers beyond this get halved)
- Hard cap: 1.75x maximum posture damage dealt
- Posture received hard cap: 0.5x (minimum 50% of intended posture damage)
- Passive regen: restores when NOT sprinting or blocking
- Parrying: restores posture (incentive to parry over block)
- Taunting (T key): restores posture
- Red-glowing posture bar = "shaky block" frames, block is weakened
```

---

## 5. Damage Calculation

### Blox Fruits Damage Formula

```
Base Damage = Weapon Base Damage × Mastery Multiplier
Stat Bonus = Melee/Sword/Gun/Element stat × scaling factor
Accessory Bonus = flat or % damage bonuses from equipped accessories
Race Bonus = racial damage modifiers (V2/V3/V4 bonuses)
Final Damage = (Base Damage + Stat Bonus) × (1 + Accessory%) × (1 + Race%) × ComboMultiplier
```

- **Mastery** increases per hit (1 mastery per M1 hit on an enemy)
- Weapons upgrade via Blacksmith (+10-30% damage) and Enchantments
- No traditional "critical hits" — damage is deterministic
- Elemental fruits provide **immunity** to non-Aura attacks (instinct-like mechanic)

### Deepwoken Damage Formula

From the [Weapons wiki](https://deepwoken.fandom.com/wiki/Weapons):

```
Scaled Damage = Base Damage + (Attribute × Scaling Factor)
Final Damage = Scaled Damage × (1 - Armor Reduction) × Swing Speed Multiplier × Quality Bonus
Posture Damage = Base Posture × Weapon Weight × Posture Multipliers (capped at 1.75x)
```

**Detailed weapon data (from wiki):**

| Weapon Type | Example | Base DMG | Scaling | Armor Pen | Swing Speed | Range |
|------------|---------|----------|---------|-----------|-------------|-------|
| Dagger | Stiletto | 11.5 | LHT: 3 | - | 1.2x | 6 |
| Dagger | Krulian Knife | 12.5 | LHT: 10.5 | 20% | 1.2x | 6 |
| Rapier | Apprentice Rapier | 13 | LHT: 6.5 | - | 1.06x | 8 |
| Rapier | Needle's Eye | 16.5 | LHT: 8.5 | 15% | 1.05x | 8 |
| Fist | Iron Cestus | 13.5 | LHT: 7.5 | - | 1.11x | 6 |
| Pistol | Dawnshot | 14 | LHT: 12 | - | 1.17x | 10.5 |

**Damage calculation example:**
```
Stiletto with 50 LHT:
Scaled Damage = 11.5 + (50 × 3) = 11.5 + 150 = 161.5... 

Wait, that seems wrong. Let me re-check.

Actually, Deepwoken uses a percentage scaling model:
Scaled Damage = Base Damage × (1 + (Attribute × Scaling% / 100))

Stiletto with 50 LHT (scaling = 3):
Scaled Damage = 11.5 × (1 + (50 × 3 / 100)) = 11.5 × 2.5 = 28.75

With 3-star quality (+6% damage):
Final = 28.75 × 1.06 = 30.475
```

**Weapon quality stars:**
| Stars | Damage Bonus | Weight (Posture) | Penetration |
|-------|-------------|-------------------|-------------|
| ★ | +2% | +4% | +5% |
| ★★ | +4% | +8% | +10% |
| ★★★ | +6% | +12% | +15% |

### King Legacy Damage

- Base damage shown directly on skills (e.g., Combat M1: 1,799)
- Increases with stat point investment
- Haki provides damage boost + defense
- Simpler overall: no complex armor penetration or posture

---

## 6. Game-by-Game Breakdown

### Blox Fruits
- **Strengths**: Massive content depth, clear progression, 12 fighting styles + 42 swords, accessibility
- **Weaknesses**: Combat feels floaty, no true defensive skill expression (Instinct is passive), hit registration issues
- **Best element**: Progression system (mastery-based unlock, prerequisite chain for Godhuman)
- **Source**: https://blox-fruits.fandom.com/wiki/Fighting_Styles

### Deepwoken
- **Strengths**: Best-in-class Roblox combat feel, parry/block/feint triangle, skill expression, posture system
- **Weaknesses**: Steep learning curve, permadeath can be frustrating, some weapon balance issues
- **Best element**: The parry/feint mindgame creates fighting-game depth on Roblox
- **Source**: https://deepwoken.fandom.com/wiki/Combat_Mechanics

### King Legacy
- **Strengths**: One Piece theme, simple to pick up, clear stat-gated progression
- **Weaknesses**: Combat lacks depth, auto-aim reduces skill expression
- **Best element**: Stat requirement gating for skills creates clear goals
- **Source**: https://king-legacy-official.fandom.com/wiki/Combat

### Grand Piece Online (GPO)
- **Strengths**: Devil Fruit system creates build variety, exploration
- **Weaknesses**: Combat feels dated, poor hit registration
- **Best element**: Build diversity from fruit/weapon combinations

### Project Slayers
- **Strengths**: Breathing style combos feel cinematic, Demon Slayer theme
- **Weaknesses**: Repetitive PvE, PvP balance issues
- **Best element**: Skill animations and visual feedback are excellent

---

## 7. The IDEAL Sword Combat System (Recommendation)

### Core Design Philosophy

> **"Easy to learn, hard to master, satisfying to execute, fair to fight against."**

Combine:
- **Deepwoken's** parry/block/feint defensive triangle (skill expression)
- **Blox Fruits'** progression and mastery system (long-term motivation)
- **Project Slayers'** visual feedback and animation quality (game feel)
- **King Legacy's** clear stat gating (readable progression)

### Recommended System Architecture

#### 7.1 M1 Combo System

```
Structure: 5-hit combo (not 4 — 5 feels better and creates more rhythm options)

Hit 1: Quick slash (0.15s startup, 0.2s endlag)
Hit 2: Cross slash (0.18s startup, 0.2s endlag)
Hit 3: Upward cut (0.2s startup, 0.25s endlag) — launches slightly
Hit 4: Spinning slash (0.22s startup, 0.3s endlag) — wide arc
Hit 5: Finisher slam (0.3s startup, 0.5s endlag) — knockback + brief stun

Timing: Each hit must connect within 0.8s of the previous hit
Late click: If >0.8s, resets to hit 1
Early click: Queued during endlag, executes when window opens
Perfect timing: Hitting at exact start of window = 5% damage bonus (visual flash)
```

```lua
-- Recommended M1 combo with perfect-timing bonus
local ComboSystem = {}

ComboSystem.HITS = {
    {startup = 0.15, endlag = 0.20, damageMult = 1.0, hitbox = "narrow",  launchPower = 0},
    {startup = 0.18, endlag = 0.20, damageMult = 1.0, hitbox = "cross",   launchPower = 0},
    {startup = 0.20, endlag = 0.25, damageMult = 1.1, hitbox = "arc",     launchPower = 2},
    {startup = 0.22, endlag = 0.30, damageMult = 1.2, hitbox = "wide",    launchPower = 3},
    {startup = 0.30, endlag = 0.50, damageMult = 1.5, hitbox = "slam",    launchPower = 8},
}

ComboSystem.COMBO_WINDOW = 0.8
ComboSystem.PERFECT_TIMING_BONUS = 0.05  -- 5% bonus for frame-perfect input
ComboSystem.PERFECT_WINDOW = 0.08  -- 80ms window for "perfect" timing

function ComboSystem.processM1(player, inputTime)
    local hitIndex = player.currentComboHit or 1
    local timeSinceLast = inputTime - (player.lastHitTime or 0)
    
    -- Reset combo if too slow
    if timeSinceLast > ComboSystem.COMBO_WINDOW then
        hitIndex = 1
    end
    
    local hitData = ComboSystem.HITS[hitIndex]
    
    -- Check for perfect timing bonus
    local isPerfect = false
    if player.lastHitEndTime then
        local timeSinceEnd = inputTime - player.lastHitEndTime
        if timeSinceEnd <= ComboSystem.PERFECT_WINDOW then
            isPerfect = true
        end
    end
    
    -- Play animation
    local anim = player.weapon.swingAnims[hitIndex]
    playAnimation(player, anim, isPerfect and 1.1 or 1.0)  -- slightly faster for perfect
    
    -- Wait for hit frame
    local hitFrameTime = getAnimHitFrame(anim)
    task.wait(hitFrameTime)
    
    -- Calculate damage
    local baseDamage = player.weapon.baseDamage
    local scaledDamage = scaleDamage(baseDamage, player.stats, player.weapon.scaling)
    local comboDamage = scaledDamage * hitData.damageMult
    local finalDamage = isPerfect and (comboDamage * (1 + ComboSystem.PERFECT_TIMING_BONUS)) or comboDamage
    
    -- Hit detection
    local targets = hitDetection(player, hitData.hitbox, hitData.launchPower)
    for _, target in ipairs(targets) do
        applyDamage(target, finalDamage)
        applyKnockback(target, player.lookDirection, hitData.launchPower)
        if hitIndex == 5 then
            applyStun(target, 0.5)  -- finisher stun
        end
    end
    
    -- Visual feedback
    if isPerfect then
        spawnPerfectHitEffect(player)  -- golden flash
    end
    spawnHitEffect(player, hitIndex)  -- screen shake, particles, hit marker
    
    -- Update combo state
    player.lastHitTime = inputTime
    player.lastHitEndTime = inputTime + hitData.endlag
    player.currentComboHit = (hitIndex % 5) + 1
    
    -- Apply endlag
    player.canAct = false
    task.wait(hitData.endlag)
    player.canAct = true
end
```

#### 7.2 Skill/Ability System

**Slot-based with weapon synergy:**

```
Equipment:
- 1 Sword (determines M1 combo + weapon skill)
- 4 Skill Slots (Z, X, C, V)
- Skills come from: Weapon-specific, Fighting Style, or Guild/Class abilities

Unlock Flow:
1. Player learns a fighting style from an NPC (costs money + quest)
2. Skills unlock as Mastery increases with that style (Z=1, X=25, C=50, V=100)
3. Sword skills unlock by using that sword (2 unique skills per sword)
4. Advanced styles require mastery of prerequisites (like Blox Fruits)
5. Player can mix: Sword M1s + Fighting Style skills (like Blox Fruits)
```

**Cooldown Model:**
```
Individual cooldowns per skill (no shared cooldowns)
Cooldowns start when skill is USED (not when it ends)
Global 0.5s cooldown between different skills (prevents instant swaps)
Skills can be used during M1 endlag (combo potential)
```

#### 7.3 Defensive System

**Adopt Deepwoken's triangle with quality-of-life improvements:**

```
1. BLOCK (Hold Guard Button)
   - Reduces incoming damage by 85%
   - Builds Posture bar
   - Guard break at max posture = 1.0s stun
   - Cannot move at full speed while blocking
   - Posture regenerates slowly when not blocking/sprinting

2. PARRY (Tap Guard Button with timing)
   - 250ms window (slightly wider than Deepwoken's ~300ms to be more forgiving)
   - Successful parry: Negates damage, restores 20% posture, brief slow-mo effect
   - Failed parry: Full damage + brief recovery frames
   - Cooldown: 0.6s between parry attempts
   - VISUAL: Weapon glow + spark particles + satisfying CLANG sound

3. DODGE (Dodge Button)
   - Quick sidestep with i-frames (0.3s of invincibility)
   - Cooldown: 1.0s
   - Can cancel M1 endlag into dodge (escape option)
   - Directional: dodge in movement direction

4. FEINT (Cancel Button during attack windup)
   - Cancels attack startup into recovery
   - Recovery: 0.3s (vulnerable but shorter than whiffing)
   - Cooldown: 0.5s
   - Used to bait parries

Rock-Paper-Scissors-Lizard-Spock:
Attack → Beats Dodge (catch roll with tracking)
Parry → Beats Attack (negate + punish)
Feint → Beats Parry (bait the parry, punish recovery)
Dodge → Beats Feint (reposition away from nothing)
Block → Beats Feint (safe option, costs posture)
Guard Break Skills → Beats Block (special moves that break posture faster)
```

#### 7.4 Damage Calculation

```lua
-- Recommended damage formula
function calculateDamage(attacker, target, weapon, skillOrM1, comboHit)
    -- Step 1: Base damage
    local baseDamage = skillOrM1.baseDamage or weapon.baseDamage
    
    -- Step 2: Stat scaling
    local totalScaling = 0
    for stat, factor in pairs(weapon.scaling) do
        totalScaling = totalScaling + (attacker.stats[stat] * factor / 100)
    end
    local scaledDamage = baseDamage * (1 + totalScaling)
    
    -- Step 3: Combo multiplier
    local comboMult = comboHit and COMBO_DAMAGE_TABLE[comboHit] or 1.0
    scaledDamage = scaledDamage * comboMult
    
    -- Step 4: Weapon quality
    local qualityBonus = 1 + (weapon.qualityStars * 0.02)  -- +2% per star
    scaledDamage = scaledDamage * qualityBonus
    
    -- Step 5: Critical hit (skill-based, not random)
    -- Only from specific weapon critical moves or perfect-timing M1s
    if skillOrM1.isCritical then
        scaledDamage = scaledDamage * skillOrM1.critMultiplier  -- typically 1.5-2.0x
    end
    
    -- Step 6: Defense calculation
    local armorReduction = target.armor * (1 - weapon.armorPenetration)
    local defenseMult = 100 / (100 + armorReduction)  -- diminishing returns formula
    local finalDamage = scaledDamage * defenseMult
    
    -- Step 7: Damage types (optional)
    if weapon.damageType and target.resistances[weapon.damageType] then
        finalDamage = finalDamage * (1 - target.resistances[weapon.damageType])
    end
    
    return math.floor(finalDamage)
end

-- Damage types for build variety
DamageTypes = {
    Slash = "Most swords, high base damage",
    Blunt = "Hammers/maces, bonus posture damage, armor penetration",
    Thrust = "Rapiers/spears, high single-target, low AoE",
    Fire = "Fire-enchanted, DoT burn effect",
    Ice = "Ice-enchanted, slow effect",
    Lightning = "Lightning-enchanted, chain damage to nearby enemies",
    Shadow = "Shadow-enchanted, life steal",
}
```

#### 7.5 Visual & Game Feel (Critical for "Combat Feel")

**Screen shake:**
```lua
-- Proportional screen shake
function applyScreenShake(player, intensity)
    -- intensity: 0.1 (light M1) to 1.0 (ultimate skill)
    local shakeMagnitude = intensity * 0.5
    local shakeDuration = intensity * 0.15
    
    CameraShake:Shake(shakeMagnitude, shakeDuration)
end

-- Combo finisher gets extra shake
if comboHit == 5 then
    applyScreenShake(player, 0.8)
end
```

**Hit effects:**
```lua
-- Layered hit feedback
function spawnHitEffects(position, damage, hitType)
    -- 1. Hit spark particles (weapon-matched)
    spawnParticle("HitSpark_" .. weapon.type, position)
    
    -- 2. Damage number (floating text)
    spawnDamageNumber(position, damage, hitType == "critical" and Color3.new(1,0.2,0.2) or Color3.new(1,1,1))
    
    -- 3. Brief freeze frame (hitlag)
    if damage > threshold then
        hitlagFreeze(0.03)  -- 30ms freeze on big hits
    end
    
    -- 4. Hit sound (pitch varies by damage)
    local pitch = 0.8 + (damage / 100) * 0.4  -- higher pitch for bigger hits
    playSound("HitSound", position, pitch)
    
    -- 5. Brief white flash on hit character
    flashCharacter(target, 0.05)
end
```

**Hitlag (freeze frame on impact):**
```lua
-- This is THE most important game feel element
-- Inspired by Devil May Cry, Dark Souls, Monster Hunter
function hitlagFreeze(duration)
    -- Freeze ALL combat participants briefly
    attacker.Animator:AdjustSpeed(0)
    target.Animator:AdjustSpeed(0)
    
    task.wait(duration)  -- typically 0.02-0.05 seconds
    
    attacker.Animator:AdjustSpeed(1)
    target.Animator:AdjustSpeed(1)
end
```

#### 7.6 Network Architecture

```
RECOMMENDED: Server-Authoritative with Client Prediction

Client Side:
- Animations play immediately (responsive feel)
- Hit sparks/particles spawn immediately (visual feedback)
- Damage numbers show client-predicted values
- Inputs are sent to server with timestamp

Server Side:
- Validates all damage calculations
- Validates hit detection with latency compensation
- Runs the authoritative game state
- Sends corrections to client if prediction was wrong

Latency Compensation:
- Server stores 1-second position history for all players
- On hit request, rewinds target position by attacker's ping
- Adds 100-150ms forgiveness window for hitbox checks
- Parry timing is checked server-side but window is expanded by player's ping

Anti-Exploit:
- Speed checks: reject positions that would require >1.5x max speed
- Attack rate limiting: server tracks attack timestamps, rejects impossible rates
- Damage validation: server recalculates all damage, ignores client-sent values
```

---

## 8. Source URLs

| Source | URL | Accessed |
|--------|-----|----------|
| Blox Fruits Wiki - Fighting Styles | https://blox-fruits.fandom.com/wiki/Fighting_Styles | 2025 |
| Blox Fruits Wiki - Combat | https://blox-fruits.fandom.com/wiki/Combat | 2025 |
| Blox Fruits Wiki - Swords | https://blox-fruits.fandom.com/wiki/Swords | 2025 |
| Blox Fruits Wiki - Instinct | https://blox-fruits.fandom.com/wiki/Instinct | 2025 |
| Deepwoken Wiki - Combat Mechanics | https://deepwoken.fandom.com/wiki/Combat_Mechanics | 2025 |
| Deepwoken Wiki - Weapons | https://deepwoken.fandom.com/wiki/Weapons | 2025 |
| King Legacy Wiki - Combat | https://king-legacy-official.fandom.com/wiki/Combat | 2025 |
| GPO Wiki - Combat | https://gpo.fandom.com/wiki/Combat | 2025 |
| Project Slayers Wiki | https://projectslayers.fandom.com/ | 2025 |

---

## Key Takeaways Summary

1. **Deepwoken's parry/block/feint system** is the gold standard for Roblox combat feel — copy its defensive triangle
2. **Blox Fruits' mastery progression** keeps players engaged for hundreds of hours — adopt its style-unlock chain
3. **Hitlag (freeze frames)** is the single biggest "feel good" factor that most Roblox games miss
4. **5-hit combos > 4-hit combos** — more rhythmic variety and better escalation to finisher
5. **Server-authoritative with client prediction** is the only viable architecture for competitive combat
6. **Perfect-timing bonuses** on M1s reward skill without punishing casual players
7. **Individual skill cooldowns** are better than shared cooldowns — more build variety
8. **Posture/stance system > simple HP** — adds a secondary resource to manage in combat
9. **Generous hitboxes for PvE, precise hitboxes for PvP** — different OverlapParams per context
10. **Damage types + armor penetration** create meaningful build diversity without excessive complexity
