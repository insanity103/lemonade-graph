# Arena / Combat Map Spatial Patterns

Reference guide for AI agents building Roblox PvP arena maps. All measurements in studs.

---

## Symmetry Types

### Mirror Symmetry
- Split map along one axis (left/right or top/bottom).
- Each side is a mirror image: identical cover, spawn rooms, and flank routes.
- Best for: 2-team modes (TDM, CTF, Payload).

### Rotational Symmetry
- Rotate 180° for 2 teams, 120° for 3 teams, 90° for 4 teams.
- Both teams get geometrically identical layouts but different visual themes.
- Best for: 3+ team modes, king of the hill.

### Asymmetric-Balanced
- Different geometry per side, balanced by sightline length, cover count, and rotation time.
- One side gets longer sightlines, the other gets tighter flank routes.
- Best for: attack/defend, escort. Requires careful playtesting.

---

## Contested Zones

Central objective areas where teams clash most frequently.

- **Size**: 30×30 to 50×50 stud area.
- **Entry points**: minimum 3 per side to avoid spawn camping funnels.
- **Power-up spawns**: place on a 30-second respawn timer at fixed points within the zone.
- **High ground**: elevated position with partial cover overlooking the objective. Height advantage = 8–12 studs above ground level.
- **No dead ends**: every entry point must have at least 2 exit options.

---

## Flanking Routes

Every pair of major positions (spawn, objective, power-up) must have **minimum 2 paths** between them.

- **Main lane**: 10–14 studs wide, direct route. Expect heavy fire.
- **Flank route**: 6–8 studs wide, longer distance, less cover. Rewards positioning.
- **Rotation path**: connects mid-map. Allows repositioning without returning to spawn.
- Never create a route with no cover for more than 20 studs.

---

## Cover Density

| Cover Type | Spacing | Dimensions | Usage |
|------------|---------|------------|-------|
| Full cover (wall/crate) | 15–25 studs apart | 6×6×8 minimum | Blocks all fire |
| Partial cover (half-wall/pillar) | 10–15 studs apart | 4×4×4 | Blocks some angles |
| Soft cover (fence/bush) | 8–12 studs apart | Variable | Obscures vision, bullet-penetrable |

- Mix full and partial cover — never rely on one type alone.
- Cover should break sightlines every 15–25 studs along main lanes.
- No open area larger than 30×30 studs without at least 2 cover objects.

---

## Spawn Separation

- Minimum **80 studs** between team spawn points (center-to-center).
- Spawn room size: 20×20 to 30×30 studs.
- **Protected spawn**: enclosed room with a single exit or max 2 exits that face away from enemy sightlines.
- Spawn protection: 5-second invulnerability on respawn (see code below).
- Never place spawn within direct line of sight of an enemy position.

---

## Destructible Elements

Breakable cover that changes the map over the match.

```lua
-- Server Script: Destructible cover Part
local cover = script.Parent
local MAX_HEALTH = 100
local health = MAX_HEALTH

-- Use a NumberValue or Attribute to track health
cover:SetAttribute("Health", MAX_HEALTH)

local function onDamage(amount)
    local current = cover:GetAttribute("Health")
    current -= amount
    cover:SetAttribute("Health", current)

    -- Visual feedback: darken as health drops
    local ratio = current / MAX_HEALTH
    cover.Color = Color3.new(ratio, ratio, ratio)

    if current <= 0 then
        cover.CanCollide = false
        cover.Transparency = 1
        -- Respawn after 15 seconds
        task.delay(15, function()
            cover.CanCollide = true
            cover.Transparency = 0
            cover.Color = Color3.new(1, 1, 1)
            cover:SetAttribute("Health", MAX_HEALTH)
        end)
    end
end

-- Example: connect to a weapon damage event
cover.Touched:Connect(function(hit)
    -- Detect projectile or melee; call onDamage(dmgValue)
end)
```

---

## Sightline Rules

- **Max unbroken sightline**: 100 studs. Every lane must have a cover break (partial or full) within 100 studs.
- **Sniper perches**: elevated positions with long sightlines (80–100 studs), but with limited view angles and exposed flanks.
- **No cross-map sightlines**: a single position should never overlook more than 60% of the map.
- Test sightlines from every elevated position — remove or block unintended overwatch.

---

## Vertical Layering

Three layers minimum for competitive depth:

| Layer | Height | Access | Purpose |
|-------|--------|--------|---------|
| Ground | 0 | Direct | Primary combat, objectives |
| Elevated platform | 8–16 studs | Stairs/ramp | Partial advantage, medium cover |
| Sniper perch | 20–30 studs | Single ladder/zipline | Long sightlines, high risk |

- Ground layer has the most cover and widest lanes.
- Elevated platforms should be reachable from 2+ directions.
- Sniper perches have minimal cover and exposed backs — high risk, high reward.

---

## Spawn Protection

```lua
-- Server Script: Spawn room invulnerability zone
local spawnZone = script.Parent -- Part covering spawn area
local PROTECTION_TIME = 5

spawnZone.Touched:Connect(function(hit)
    local player = game.Players:GetPlayerFromCharacter(hit.Parent)
    if not player then return end

    local humanoid = hit.Parent:FindFirstChild("Humanoid")
    if not humanoid then return end

    -- Grant temporary invulnerability
    humanoid:SetAttribute("Invulnerable", true)

    task.delay(PROTECTION_TIME, function()
        humanoid:SetAttribute("Invulnerable", false)
    end)
end)

-- In your damage script, check:
-- if humanoid:GetAttribute("Invulnerable") then return end
```

---

## Power-Up Pickup

```lua
-- Server Script: Power-up pickup Part
local pickup = script.Parent
pickup.Anchored = true
pickup.CanCollide = false
pickup.Shape = Enum.PartType.Ball

local RESPAWN_TIME = 30
local collected = false

pickup.Touched:Connect(function(hit)
    if collected then return end
    local player = game.Players:GetPlayerFromCharacter(hit.Parent)
    if not player then return end

    collected = true
    pickup.Transparency = 1

    -- Apply power-up effect to player
    local humanoid = hit.Parent:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = 24 -- speed boost example
        task.delay(10, function()
            if humanoid then humanoid.WalkSpeed = 16 end
        end)
    end

    -- Respawn power-up
    task.delay(RESPAWN_TIME, function()
        pickup.Transparency = 0
        collected = false
    end)
end)
```

---

## General Rules

- All map geometry the player interacts with must be `Anchored = true`.
- Use `Teams` service for team assignment; color-code spawn rooms to match team colors.
- Test every lane for spawn trap potential — if one team can lock the other in spawn, add a third exit.
- Keep kill zones (environmental hazards) minimal in competitive maps — focus on player-vs-player.
- Name all parts semantically: `Cover_Wall_LaneA_01`, `SpawnRoom_Team1`, `PowerUp_Speed_Center`.
