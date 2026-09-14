# Obby (Obstacle Course) Spatial Patterns

Reference guide for AI agents building Roblox obby maps. All measurements in studs unless noted.

---

## Platform Sizing

| Difficulty | Platform Width | Gap Distance | Jump Arc Notes |
|------------|---------------|--------------|----------------|
| Easy | 10–12 | 3–5 | Single jump, generous landing |
| Medium | 6–8 | 6–8 | Running jump required |
| Hard | 4–5 | 9–12 | Tight timing, edge-to-edge |
| Extreme | 3–4 | 12–15 | Long jump or wrap-around |

- Default platform thickness: 1 stud (visual) + anchored Part beneath for collision safety.
- All platforms must be `Anchored = true`.
- Use consistent `Material` per stage section (e.g., Grass for stage 1, Neon for stage 5) for visual wayfinding.

---

## Kill Brick Setup

Properties:
```
CanCollide = false
Material = Enum.Material.Neon
Color = Color3.fromRGB(255, 0, 0)
Transparency = 0.3
Anchored = true
```

Behavior: Respawn player at last checkpoint on touch.

```lua
-- Server Script inside KillBrick part
local brick = script.Parent
brick.Touched:Connect(function(hit)
    local player = game.Players:GetPlayerFromCharacter(hit.Parent)
    if not player then return end
    local checkpoint = player:GetAttribute("CheckpointCFrame")
    if checkpoint then
        hit.Parent:PivotTo(checkpoint)
    else
        hit.Parent:PivotTo(workspace.SpawnLocation.CFrame)
    end
end)
```

---

## Checkpoint System

Place invisible `Part` (CanCollide=false, Transparency=1) at each stage boundary. When touched, save the player's spawn CFrame.

```lua
-- Server Script inside Checkpoint part (one per checkpoint)
local checkpoint = script.Parent
local debounce = {}

checkpoint.Touched:Connect(function(hit)
    local player = game.Players:GetPlayerFromCharacter(hit.Parent)
    if not player or debounce[player] then return end
    debounce[player] = true
    task.delay(2, function() debounce[player] = nil end)

    player:SetAttribute("CheckpointCFrame", checkpoint.CFrame + Vector3.new(0, 5, 0))
    -- Optional: visual feedback
    checkpoint.BrickColor = BrickColor.new("Lime green")
end)
```

---

## Timer System

Track elapsed time from spawn, display via ScreenGui.

```lua
-- LocalScript in StarterPlayerScripts
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui", player.PlayerGui)
local label = Instance.new("TextLabel", gui)
label.Size = UDim2.new(0, 200, 0, 40)
label.Position = UDim2.new(1, -210, 0, 10)
label.BackgroundTransparency = 0.5
label.TextScaled = true

local startTime = os.clock()

game:GetService("RunService").Heartbeat:Connect(function()
    local elapsed = os.clock() - startTime
    local mins = math.floor(elapsed / 60)
    local secs = math.floor(elapsed % 60)
    label.Text = string.format("%d:%02d", mins, secs)
end)
```

---

## Rebirth System

On rebirth: multiply difficulty (wider gaps, smaller platforms), reset player position, increment rebirth counter on leaderstats.

```lua
-- Server Script: Rebirth pad
local pad = script.Parent
local REBIRTH_MULTIPLIER = 1.25

pad.Touched:Connect(function(hit)
    local player = game.Players:GetPlayerFromCharacter(hit.Parent)
    if not player then return end

    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then return end

    local stage = leaderstats:FindFirstChild("Stage")
    if not stage or stage.Value < 10 then return end -- require completion

    local rebirths = leaderstats:FindFirstChild("Rebirths")
    rebirths.Value += 1
    stage.Value = 1

    -- Reset position
    player.Character:PivotTo(workspace.SpawnLocation.CFrame)
    player:SetAttribute("CheckpointCFrame", nil)
end)
```

---

## Stage Spacing

- Vertical distance between stages: **20–40 studs** (easy) up to **60–80 studs** (hard).
- Use a consistent upward flow — never require the player to backtrack downward.
- Place a visible stage number Part or BillboardGui at each stage start.
- Total map height budget for a 10-stage obby: ~400–600 studs.

---

## Recovery Zones

After every 2–3 difficult stages, place a wide (16–20 stud) safe platform with no hazards.

- Recovery zones signal "rest point" to the player.
- Optional: place a checkpoint here.
- Use contrasting Material or Color to visually distinguish recovery from challenge areas.
- Minimum 2 recovery zones per 10-stage obby.

---

## Moving Platforms

Use `TweenService` for predictable motion. Avoid physics-based movement for reliability.

```lua
-- Server Script inside moving platform Part
local platform = script.Parent
platform.Anchored = true

local TweenService = game:GetService("TweenService")
local tweenInfo = TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true)

local goal = {Position = platform.Position + Vector3.new(0, 0, 20)}
local tween = TweenService:Create(platform, tweenInfo, goal)
tween:Play()
```

Alternative: `AlignPosition` + `AlignOrientation` for physics-aware platforms that carry riders naturally.

---

## Disappearing Platforms

Platform fades out and disables collision after a delay when stepped on.

```lua
-- Server Script inside disappearing platform
local platform = script.Parent
platform.Anchored = true
local TOUCH_DELAY = 1.5
local GONE_TIME = 2
local debounce = false

platform.Touched:Connect(function(hit)
    if debounce then return end
    if not game.Players:GetPlayerFromCharacter(hit.Parent) then return end
    debounce = true

    -- Warning flash
    task.delay(TOUCH_DELAY, function()
        local tween = game:GetService("TweenService")
            :Create(platform, TweenInfo.new(0.5), {Transparency = 1})
        tween:Play()
        tween.Completed:Wait()
        platform.CanCollide = false

        task.wait(GONE_TIME)
        platform.CanCollide = true
        platform.Transparency = 0
        debounce = false
    end)
end)
```

---

## General Rules

- Every Part the player stands on must be `Anchored = true`.
- Never place hazards directly on a checkpoint platform.
- Test all jumps at R15 default height (5.5 studs tall, jump height ~7.2 studs).
- Use `SpawnLocation` for the initial spawn; set `Neutral = true` for FFA obbys.
- Group stage parts under `Model` or `Folder` instances named `Stage1`, `Stage2`, etc.
