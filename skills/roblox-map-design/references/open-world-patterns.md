# Open World Spatial Patterns

Reference guide for AI agents building Roblox open-world maps. All measurements in studs.

---

## District Boundaries

Each district must be visually distinct within 3 seconds of entering it.

- **Color coding**: Assign a primary palette per district (e.g., forest = greens/browns, city = grays/blues, desert = tans/oranges). Apply to terrain, ambient lighting, and Sky instance.
- **Landmark anchoring**: Every district has 1 dominant landmark visible from adjacent districts (tower, mountain, statue, large building). Landmarks serve as navigation without minimaps.
- **Boundary markers**: Use terrain transitions (road, river, wall, bridge) — not invisible walls — to define edges. Player should feel they're crossing into a new area, not hitting a barrier.
- **Naming**: Place a `BillboardGui` or `SurfaceGui` sign at each district entrance with the district name.

---

## Travel Time

- Adjacent district centers: **30–60 seconds on foot** (default WalkSpeed 16). This translates to ~500–1000 studs center-to-center.
- Opposite ends of the map: **3–5 minutes** on foot. Use vehicles, mounts, or fast-travel to compress.
- Within a single district: **10–20 seconds** between points of interest.
- Never place a quest objective more than 2 minutes of travel from its quest giver without offering transport.

---

## Landmark Density

Per district:
- **1 major landmark**: Large, structurally complex, serves as district identity (castle, volcano, skyscraper, temple).
- **3–5 minor landmarks**: Smaller structures or natural features (well, bridge, campsite, pond, statue).
- Minimum **50 studs** between minor landmarks to avoid visual clutter.
- Major landmarks should occupy at least a 40×40 stud footprint.

---

## Vertical Layering

Three vertical zones per district:

| Layer | Access | Content |
|-------|--------|---------|
| Underground | Cave entrances, sewer grates, trapdoors | Hidden collectibles, secret NPCs, dungeon content |
| Street level | Default navigation | Quest givers, merchants, main paths |
| Rooftop | Ladders, stairs, climbable surfaces | Collectibles, vantage points, parkour routes |

- Every district must have at least 1 underground and 1 rooftop access point.
- Underground areas should be 20–40 studs below surface level.
- Rooftop access should require intentional climbing — not spawn-walkable.

---

## NPC Placement

| NPC Type | Placement Rule | Quantity |
|----------|---------------|----------|
| Quest givers | At district entrances or near landmarks | 1–2 per district |
| Merchants | Near major landmark or central plaza | 1 per district |
| Lore/dialogue NPCs | Along main paths between landmarks | 2–3 per district |
| Ambient NPCs | Fill residential/social areas | 5–10 per district |

- Quest givers face toward the player's approach direction.
- Merchants have a clear 10×10 stud interaction zone in front of them.
- All NPCs must be `Anchored = true` with a `Humanoid` for animation.
- Use `ProximityPrompt` for interaction (not ClickDetector) — consistent with modern Roblox patterns.

---

## Collectible Distribution

- **8–12 collectibles per district**.
- Mix: 60% visible (on shelves, rooftops, ledges), 40% hidden (behind objects, underground, inside buildings).
- Spacing: minimum 30 studs between collectibles to prevent "bunching."
- Use consistent visual indicator (glow, particle, floating animation) so hidden ones are findable with exploration.
- Track collection with `NumberValue` under leaderstats or a DataStore-backed system.

---

## Draw Distance Management

```lua
-- In game Settings or via script:
game:GetService("StarterService") -- not applicable

-- StreamingEnabled is set in Workspace properties:
-- Workspace.StreamingEnabled = true
-- Workspace.StreamingMinRadius = 128   (studs, always loaded)
-- Workspace.StreamingTargetRadius = 1024 (studs, streamed in)

-- LOD considerations:
-- Use MeshPart with multiple LevelOfDetail values (0 = full, 1-3 = simplified)
-- Place far-away landmark geometry in high locations so it streams early
-- Disable particle effects and small props beyond 500 studs using client-side distance checks
```

- Enable `StreamingEnabled = true` for any open world with >500 parts.
- Set `StreamingMinRadius` to cover the player's immediate district (~128–256 studs).
- Set `StreamingTargetRadius` to cover visible landmarks (~512–1024 studs).
- Use `CollectionService` tags + client script to hide non-essential details beyond streaming radius.

---

## Zone Transitions

Transition gradually between districts — no hard cuts.

- **Terrain**: Use smooth terrain painting with 20–40 stud blend zones between biome types.
- **Lighting**: Tween `Lighting.Ambient`, `Lighting.OutdoorAmbient`, and `Atmosphere` properties over a 10-stud transition zone using a `Region3` or part-based trigger.
- **Sound**: Crossfade ambient sound tracks using `Sound.RollOffMaxDistance` or a zone-triggered volume tween.
- **Props**: Gradually mix prop types — e.g., at a forest-to-desert border, transition from dense trees to sparse trees to cacti over ~100 studs.

---

## Zone Entry Detection

```lua
-- Server Script: Zone detection using a Part trigger at district boundary
local zoneTrigger = script.Parent -- invisible Part at boundary
zoneTrigger.CanCollide = false
zoneTrigger.Transparency = 1

local DISTRICT_NAME = zoneTrigger:GetAttribute("DistrictName") or "Unknown"

zoneTrigger.Touched:Connect(function(hit)
    local player = game.Players:GetPlayerFromCharacter(hit.Parent)
    if not player then return end

    local currentZone = player:GetAttribute("CurrentZone")
    if currentZone == DISTRICT_NAME then return end

    player:SetAttribute("CurrentZone", DISTRICT_NAME)

    -- Fire client event for UI/sound/lighting changes
    game.ReplicatedStorage.ZoneChanged:FireClient(player, DISTRICT_NAME)
end)
```

---

## Collectible Pickup

```lua
-- Server Script: Collectible item Part
local collectible = script.Parent
local collected = false

local function setup()
    -- Visual indicator
    collectible.Anchored = true
    collectible.CanCollide = false
    collectible.Transparency = 0.3

    -- Add glow
    local light = Instance.new("PointLight", collectible)
    light.Color = Color3.fromRGB(255, 255, 100)
    light.Range = 10
    light.Brightness = 2

    -- Floating animation
    task.spawn(function()
        local startY = collectible.Position.Y
        while not collected do
            for i = 0, 1, 0.02 do
                collectible.Position = collectible.Position
                    + Vector3.new(0, math.sin(i * math.pi * 2) * 0.05, 0)
                task.wait()
            end
        end
    end)
end

setup()

collectible.Touched:Connect(function(hit)
    if collected then return end
    local player = game.Players:GetPlayerFromCharacter(hit.Parent)
    if not player then return end

    collected = true
    collectible.Transparency = 1

    -- Update leaderstats or fire collection event
    local stats = player:FindFirstChild("leaderstats")
    if stats then
        local count = stats:FindFirstChild("Collectibles")
        if count then count.Value += 1 end
    end
end)
```

---

## General Rules

- Name parts semantically: `District_Forest_Landmark_Treehouse`, `NPC_Quest_Forest_01`.
- Group all district content under a `Model` or `Folder` named after the district.
- Place a `SpawnLocation` per district for fast-travel respawn.
- Use terrain for large-scale geography; reserve Parts for interactive or detailed structures.
- Every point of interest should be visible or hinted at from at least one other location in the same district.
