# Tycoon Map Spatial Patterns

Reference guide for AI agents building Roblox tycoon maps. All measurements in studs.

---

## Plot Layout

Each player owns one plot. Layout determines the entire game feel.

| Shape | Dimensions | Best For |
|-------|-----------|----------|
| Rectangular | 80×100 to 100×120 | Grid-based building, linear conveyors |
| Circular | Radius 50–60 | Radial expansion, organic layouts |

- Plot surface: flat, single terrain material or a Baseplate Part.
- All plots must be identical in shape and starting features.
- Visual boundary: 1-stud-high wall or colored terrain border. Player can walk across but buildable area is clearly defined.
- Place a **Tycoon Door** (claim pad) at the entrance of each plot.

---

## Building Placement Grid

Snap all player-placed buildings to a consistent grid for clean layouts.

```lua
-- ModuleScript: Grid snapping utility
local GRID_SIZE = 8 -- studs

local function snapToGrid(position: Vector3): Vector3
    return Vector3.new(
        math.round(position.X / GRID_SIZE) * GRID_SIZE,
        position.Y, -- keep vertical free
        math.round(position.Z / GRID_SIZE) * GRID_SIZE
    )
end

return { snapToGrid = snapToGrid, GRID_SIZE = GRID_SIZE }
```

- Grid size of 8 studs aligns with standard Roblox building increments.
- Buildings occupy multiples of the grid: 8×8, 16×16, 16×24, etc.
- Show a ghost/preview of the building at the snapped position before confirming placement.
- Prevent placement if the grid cell is occupied (raycast or region overlap check).

---

## Conveyor Paths

Conveyors move items from droppers to collectors.

- **Width**: 4 studs (belt surface). Place two Parts: one invisible `CanCollide=true` base, one visible belt with `Velocity` property for movement.
- **Straight runs**: 16–32 studs long standard segments.
- **Junctions**: T-splits or Y-splits at 90° or 45° using wedge Parts.
- **Speed**: `BasePart.AssemblyLinearVelocity` or `LinearVelocity` — standard belt speed ~8–12 studs/sec.
- Items are small `Part` or `MeshPart` instances parented to a `Folder` in Workspace.

```lua
-- Server Script: Conveyor belt Part
local belt = script.Parent
belt.Anchored = true

-- Surface velocity moves objects on top
belt.CustomPhysicalProperties = PhysicalProperties.new(0.1, 0.3, 0, 1, 1)
-- Use a VectorForce or set AssemblyLinearVelocity on touching items
belt.Touched:Connect(function(hit)
    if hit:IsDescendantOf(belt.Parent) then return end
    if hit.Anchored then return end
    hit.AssemblyLinearVelocity = belt.CFrame.LookVector * 10
end)
```

---

## Collection Zones

The economy pipeline: **Dropper → Conveyor → Collector → Cash**

1. **Dropper**: Object that spawns items on a timer (e.g., every 1–2 seconds). Part falls from dropper onto conveyor.
2. **Conveyor**: Moves items from dropper to collector (see above).
3. **Collector**: Part at conveyor end that destroys items and adds cash.

```lua
-- Server Script: Collector Part
local collector = script.Parent
collector.Anchored = true

local CASH_PER_ITEM = 5

collector.Touched:Connect(function(hit)
    if hit.Name ~= "DroppedItem" then return end
    local owner = collector:GetAttribute("Owner")
    if not owner then return end

    local player = game.Players:GetPlayerByUserId(owner)
    if not player then return end

    local cash = player:FindFirstChild("leaderstats")
        and player.leaderstats:FindFirstChild("Cash")
    if cash then
        cash.Value += CASH_PER_ITEM
    end

    hit:Destroy()
end)
```

---

## Upgrade Area

As players upgrade, their plot footprint expands.

- **Tier 1**: 80×80 stud buildable area.
- **Tier 2**: 100×100 stud (unlock perimeter strip).
- **Tier 3**: 120×120 stud (full plot).
- Visual tier indicator: change floor color or material per tier (e.g., dirt → concrete → marble).
- Expand by enabling pre-placed invisible boundary Parts on upgrade purchase.
- New buildable area appears with a brief tween (Transparency 1→0) for feedback.

---

## Plot Separation

- Minimum **40 studs** between adjacent plot boundaries (edge-to-edge).
- This gap serves as a walkway/road between plots so players can visit each other.
- Place decorative props (streetlights, hedges, fences) in the gap to prevent it from feeling empty.
- No player should be able to build into the gap or another player's plot.

---

## Plot Claiming

```lua
-- Server Script: Tycoon door / claim pad
local door = script.Parent
local claimed = false

door.Touched:Connect(function(hit)
    if claimed then return end
    local player = game.Players:GetPlayerFromCharacter(hit.Parent)
    if not player then return end

    -- Check if player already owns a plot
    for _, plot in pairs(workspace.Plots:GetChildren()) do
        if plot:GetAttribute("Owner") == player.UserId then return end
    end

    claimed = true
    door:SetAttribute("Owner", player.UserId)
    door.Parent:SetAttribute("Owner", player.UserId)

    -- Tag all buildable parts on this plot
    for _, part in pairs(door.Parent:GetDescendants()) do
        if part:IsA("BasePart") then
            part:SetAttribute("Owner", player.UserId)
        end
    end

    -- Visual feedback
    door.BrickColor = BrickColor.new("Bright green")
    door.SurfaceGui.TextLabel.Text = player.Name .. "'s Tycoon"
end)
```

---

## General Rules

- All plot parts must be `Anchored = true`.
- Use `Folder` or `Model` per plot: `Plot_1`, `Plot_2`, etc. Group all plot children inside.
- Pre-build all possible upgrade positions on each plot at start; toggle visibility. This prevents needing to clone complex geometry at runtime.
- Name economy parts semantically: `Dropper_Iron_Plot1`, `Conveyor_Main_Plot1`, `Collector_Plot1`.
- Store player cash in `leaderstats.Cash` (NumberValue) for automatic leaderboard display.
- Test conveyor item physics — dropped items should not clip through belts or fly off at junctions.
