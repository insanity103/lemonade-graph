# Horror Game Code Patterns

## Lighting Setup

```lua
-- Server Script (or in Lighting directly)
local Lighting = game:GetService("Lighting")
Lighting.Ambient = Color3.fromRGB(20, 20, 25)     -- [TUNING] very dim
Lighting.Brightness = 0.3                           -- [TUNING] low brightness
Lighting.FogEnd = 150                               -- [TUNING] short draw distance
Lighting.FogColor = Color3.fromRGB(10, 10, 15)
Lighting.ClockTime = 0                              -- midnight
Lighting.OutdoorAmbient = Color3.fromRGB(15, 15, 20)
```

### Flickering Lights (Heartbeat + math.random)

```lua
-- Script inside a PointLight or SpotLight parented to a ceiling Part
local light = script.Parent:FindFirstChildWhichIsA("Light") or script.Parent
local RunService = game:GetService("RunService")

local BASE_BRIGHTNESS = light.Brightness or 1
local FLICKER_CHANCE  = 0.03  -- [TUNING] per frame probability
local FLICKER_MIN     = 0.1   -- [TUNING] dimmest flicker value
local FLICKER_MAX     = 1.5   -- [TUNING] brightest flicker spike

RunService.Heartbeat:Connect(function()
    if math.random() < FLICKER_CHANCE then
        light.Brightness = FLICKER_MIN + math.random() * (FLICKER_MAX - FLICKER_MIN)
        light.Enabled = math.random() > 0.3 -- [TUNING] 30% chance fully off
    else
        light.Brightness = BASE_BRIGHTNESS
        light.Enabled = true
    end
end)
```

---

## Proximity-Based Sound

```lua
-- Script inside a Part that has a Sound child
local source = script.Parent
local sound = source:FindFirstChildWhichIsA("Sound")
if not sound then return end

sound.Volume = 0 -- start silent
sound.RollOffMode = Enum.RollOffMode.Linear
sound.RollOffMinDistance = 5   -- [TUNING] studs, full volume
sound.RollOffMaxDistance = 50  -- [TUNING] studs, silence

-- For more control, manually adjust volume by distance:
local RunService = game:GetService("RunService")
local MAX_DIST = 60  -- [TUNING]

RunService.Heartbeat:Connect(function()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local dist = (source.Position - camera.CFrame.Position).Magnitude
    local vol = math.clamp(1 - (dist / MAX_DIST), 0, 1)
    sound.Volume = vol * 0.8 -- [TUNING] master volume cap
end)
```

---

## NPC AI: PathfindingService + State Machine

### States

| State | Description |
|---|---|
| `Idle` | Standing still, listening for stimuli |
| `Patrol` | Following waypoints |
| `Chase` | Pursuing a detected player |
| `Attack` | Within melee range, dealing damage |
| `Return` | Returning to patrol route |

---

## Sanity System

```lua
-- Server Script: tracks sanity per player via Attribute
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DRAIN_RATE    = 5     -- [TUNING] sanity points per second in darkness
local REGEN_RATE    = 2     -- [TUNING] sanity recovery per second in light
local DARK_THRESHOLD = 0.3  -- [TUNING] ambient brightness below this = "dark"
local MAX_SANITY    = 100

Players.PlayerAdded:Connect(function(player)
    player:SetAttribute("Sanity", MAX_SANITY)
end)

-- Server-side sanity drain (or replicate to client for visual effects)
RunService.Heartbeat:Connect(function(dt)
    for _, player in Players:GetPlayers() do
        local sanity = player:GetAttribute("Sanity") or MAX_SANITY
        -- Check if player is in a "dark zone" (tagged parts)
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local inDark = false
            for _, zone in workspace.DarkZones:GetChildren() do -- [TUNING] folder of Parts
                if zone:IsA("BasePart") then
                    local rel = zone.CFrame:PointToObjectSpace(root.Position)
                    local size = zone.Size / 2
                    if math.abs(rel.X) <= size.X and math.abs(rel.Y) <= size.Y and math.abs(rel.Z) <= size.Z then
                        inDark = true
                        break
                    end
                end
            end

            if inDark then
                sanity = math.max(0, sanity - DRAIN_RATE * dt)
            else
                sanity = math.min(MAX_SANITY, sanity + REGEN_RATE * dt)
            end
            player:SetAttribute("Sanity", sanity)
        end
    end
end)
```

---

## Jump Scare

```lua
-- Server Script inside a Trigger Part
local trigger = script.Parent
local SCARE_SOUND_ID = "rbxassetid://0000000000" -- [TUNING] your scary sound ID
local COOLDOWN = 10 -- [TUNING] seconds between triggers

local debounce = false

trigger.Touched:Connect(function(hit)
    if debounce then return end
    local player = game.Players:GetPlayerFromCharacter(hit.Parent)
    if not player then return end
    debounce = true

    -- Fire scare event to this client only
    local scareEvent = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("JumpScare")
    scareEvent:FireClient(player, SCARE_SOUND_ID)

    task.delay(COOLDOWN, function() debounce = false end)
end)
```

```lua
-- LocalScript (StarterPlayerScripts): receives and displays jump scare
local RS = game:GetService("ReplicatedStorage")
local scareEvent = RS:WaitForChild("Remotes"):WaitForChild("JumpScare")

local SCARE_IMAGE = "rbxassetid://0000000000" -- [TUNING] scary face image
local FLASH_DURATION = 0.3 -- [TUNING] seconds

scareEvent.OnClientEvent:Connect(function(soundId: string)
    -- Play sound
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = 1
    sound.PlayOnRemove = false
    sound.Parent = workspace
    sound:Play()
    game:GetService("Debris"):AddItem(sound, 5)

    -- Flash image on screen
    local player = game.Players.LocalPlayer
    local gui = Instance.new("ScreenGui")
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 100
    gui.Parent = player.PlayerGui

    local img = Instance.new("ImageLabel")
    img.Size = UDim2.fromScale(1, 1)
    img.Image = SCARE_IMAGE
    img.BackgroundTransparency = 1
    img.Parent = gui

    task.wait(FLASH_DURATION) -- [TUNING]
    gui:Destroy()
end)
```

---

## Darkness: PointLight with Battery Drain

```lua
-- LocalScript: flashlight with battery
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local BATTERY_MAX      = 100   -- [TUNING]
local DRAIN_RATE       = 2     -- [TUNING] per second
local RECHARGE_RATE    = 5     -- [TUNING] per second when off
local LIGHT_RANGE      = 40    -- [TUNING] studs
local LIGHT_BRIGHTNESS = 2     -- [TUNING]

local battery = BATTERY_MAX
local flashlightOn = false

local light = Instance.new("PointLight")
light.Range = LIGHT_RANGE
light.Brightness = 0
light.Color = Color3.fromRGB(255, 240, 200) -- warm flashlight
light.Parent = camera

RunService.Heartbeat:Connect(function(dt)
    if flashlightOn and battery > 0 then
        battery = math.max(0, battery - DRAIN_RATE * dt)
        light.Brightness = LIGHT_BRIGHTNESS * (battery / BATTERY_MAX)
        if battery <= 0 then
            flashlightOn = false
        end
    else
        battery = math.min(BATTERY_MAX, battery + RECHARGE_RATE * dt)
        light.Brightness = 0
    end

    -- Toggle input
    -- (Connect UIS.InputBegan separately to avoid per-frame cost)
end)

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F then -- [TUNING] toggle key
        if battery > 0 then
            flashlightOn = not flashlightOn
        end
    end
end)
```

---

## Full Working Example: Horror NPC with PathfindingService (~80 lines)

```lua
-- Script inside an NPC Model (must have Humanoid + HumanoidRootPart)
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local npc = script.Parent
local humanoid = npc:WaitForChild("Humanoid")
local root = npc:WaitForChild("HumanoidRootPart")

-- State machine
local STATE_IDLE    = "Idle"
local STATE_PATROL  = "Patrol"
local STATE_CHASE   = "Chase"
local STATE_ATTACK  = "Attack"
local STATE_RETURN  = "Return"

local state = STATE_PATROL
local patrolIndex = 1
local patrolWaypoints: {Vector3} = {}

-- Tuning
local DETECT_RANGE  = 35    -- [TUNING] studs to start chase
local ATTACK_RANGE  = 5     -- [TUNING] studs to deal damage
local ATTACK_DAMAGE = 25    -- [TUNING]
local ATTACK_COOLDOWN = 2   -- [TUNING] seconds between attacks
local PATROL_SPEED  = 8     -- [TUNING]
local CHASE_SPEED   = 18    -- [TUNING]
local LOSE_RANGE    = 50    -- [TUNING] studs to lose target
local PATROL_WAIT   = 2     -- [TUNING] seconds at each waypoint

local lastAttackTime = 0
local target: Player? = nil
local homePos = root.Position

-- Collect patrol points from a Folder named "PatrolPoints" in workspace
local pointsFolder = workspace:FindFirstChild("PatrolPoints")
if pointsFolder then
    for _, p in pointsFolder:GetChildren() do
        if p:IsA("BasePart") then
            table.insert(patrolWaypoints, p.Position)
        end
    end
end
if #patrolWaypoints == 0 then
    patrolWaypoints = { homePos } -- fallback: stay in place
end

-- Pathfinding helper
local function moveToPosition(goalPos: Vector3): boolean
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
    })
    local ok = pcall(function()
        path:ComputeAsync(root.Position, goalPos)
    end)
    if not ok or path.Status ~= Enum.PathStatus.Success then return false end

    local waypoints = path:GetWaypoints()
    for _, wp in waypoints do
        if wp.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end
        humanoid:MoveTo(wp.Position)
        local reached = humanoid.MoveToFinished:Wait()
        if not reached then return false end
        -- Re-check if we should abort (e.g., spotted player)
        if state == STATE_CHASE or state == STATE_ATTACK then return false end
    end
    return true
end

-- Find nearest visible player
local function findTarget(): Player?
    local closest, closestDist = nil, DETECT_RANGE
    for _, player in Players:GetPlayers() do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hrp and hum and hum.Health > 0 then
            local dist = (hrp.Position - root.Position).Magnitude
            if dist < closestDist then
                -- Line-of-sight check
                local rayResult = workspace:Raycast(
                    root.Position,
                    (hrp.Position - root.Position),
                    RaycastParams.new() -- default includes all
                )
                if rayResult and rayResult.Instance:IsDescendantOf(char) then
                    closest = player
                    closestDist = dist
                end
            end
        end
    end
    return closest
end

-- Main AI loop
while humanoid.Health > 0 do
    if state == STATE_PATROL then
        humanoid.WalkSpeed = PATROL_SPEED
        local goal = patrolWaypoints[patrolIndex]
        moveToPosition(goal)
        patrolIndex = patrolIndex % #patrolWaypoints + 1
        task.wait(PATROL_WAIT) -- [TUNING]
        target = findTarget()
        if target then state = STATE_CHASE end

    elseif state == STATE_CHASE then
        humanoid.WalkSpeed = CHASE_SPEED
        local char = target and target.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or not target then
            state = STATE_RETURN
            continue
        end
        local dist = (hrp.Position - root.Position).Magnitude
        if dist > LOSE_RANGE then
            state = STATE_RETURN
            continue
        end
        if dist <= ATTACK_RANGE then
            state = STATE_ATTACK
            continue
        end
        humanoid:MoveTo(hrp.Position)
        humanoid.MoveToFinished:Wait()

    elseif state == STATE_ATTACK then
        local char = target and target.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp or hum.Health <= 0 then
            state = STATE_PATROL
            target = nil
            continue
        end
        local dist = (hrp.Position - root.Position).Magnitude
        if dist > ATTACK_RANGE then
            state = STATE_CHASE
            continue
        end
        local now = os.clock()
        if now - lastAttackTime >= ATTACK_COOLDOWN then
            hum:TakeDamage(ATTACK_DAMAGE)
            lastAttackTime = now
        end
        task.wait(0.1) -- [TUNING] attack check interval

    elseif state == STATE_RETURN then
        humanoid.WalkSpeed = PATROL_SPEED
        moveToPosition(patrolWaypoints[patrolIndex])
        state = STATE_PATROL
    end

    task.wait(0.1) -- [TUNING] main loop tick
end
```
