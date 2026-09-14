# Obby Code Patterns

## Kill Brick

```lua
-- Script inside a Part (or attached via CollectionService)
local brick = script.Parent
brick.BrickColor = BrickColor.new("Really red")
brick.Material = Enum.Material.Neon
brick.CanCollide = false -- players pass through
brick.Anchored = true

brick.Touched:Connect(function(hit)
    local character = hit.Parent
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    -- Prevent double-fire
    if humanoid:GetAttribute("RecentlyKilled") then return end
    humanoid:SetAttribute("RecentlyKilled", true)
    humanoid:TakeDamage(humanoid.MaxHealth) -- [TUNING] instant kill
    task.delay(0.5, function() humanoid:SetAttribute("RecentlyKilled", nil) end)
end)
```

---

## Checkpoint System

```lua
-- Server Script: CheckpointManager (in ServerScriptService)
local Players = game:GetService("Players")
local checkpoints = workspace:WaitForChild("Checkpoints") -- Folder of Parts named "1","2","3"...

local playerCheckpoint: {[Player]: number} = {}

local function getSpawnCF(player: Player): CFrame?
    local idx = playerCheckpoint[player] or 0
    local cp = checkpoints:FindFirstChild(tostring(idx))
    return cp and cp.CFrame + Vector3.new(0, 3, 0) -- [TUNING] spawn offset
end

for _, cp in checkpoints:GetChildren() do
    cp.Touched:Connect(function(hit)
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if not player then return end
        local idx = tonumber(cp.Name)
        if not idx then return end
        if (playerCheckpoint[player] or 0) < idx then
            playerCheckpoint[player] = idx
        end
    end)
end

-- Respawn at checkpoint
Players.PlayerAdded:Connect(function(player)
    playerCheckpoint[player] = 0
    player.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid")
        task.wait() -- let spawn finish
        local cf = getSpawnCF(player)
        if cf then
            char:PivotTo(cf)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    playerCheckpoint[player] = nil
end)
```

---

## Timer (Elapsed Time Display)

```lua
-- Server Script (stores spawn time, client reads via attribute)
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    player:SetAttribute("ObbyStartTime", os.clock())
    player:SetAttribute("ObbyFinished", false)
end)
```

```lua
-- LocalScript (StarterPlayerScripts): display timer via BillboardGui
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local gui = Instance.new("BillboardGui")
gui.Name = "TimerGui"
gui.Size = UDim2.fromOffset(120, 40) -- [TUNING]
gui.StudsOffset = Vector3.new(0, 3, 0) -- [TUNING]
gui.AlwaysOnTop = true

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.BackgroundTransparency = 0.5
label.TextColor3 = Color3.new(1, 1, 1)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Parent = gui

local function update()
    local startTime = player:GetAttribute("ObbyStartTime")
    if not startTime then return end
    local elapsed = os.clock() - startTime
    local mins = math.floor(elapsed / 60)
    local secs = math.floor(elapsed % 60)
    label.Text = string.format("%d:%02d", mins, secs)
end

local function attachGui(char)
    local head = char:WaitForChild("Head")
    gui.Parent = head
end

player.CharacterAdded:Connect(attachGui)
if player.Character then attachGui(player.Character) end

game:GetService("RunService").Heartbeat:Connect(update)
```

---

## Disappearing Platform

```lua
-- Script inside a Part
local platform = script.Parent
local DISAPPEAR_DELAY = 1.5  -- [TUNING] seconds after touch before vanishing
local RESTORE_DELAY   = 3.0  -- [TUNING] seconds invisible before reappearing

local originalTransparency = platform.Transparency
local debounce = false

platform.Touched:Connect(function(hit)
    if debounce then return end
    if not hit.Parent:FindFirstChildOfClass("Humanoid") then return end
    debounce = true

    -- Flash warning
    for _ = 1, 4 do -- [TUNING] flash count
        platform.Transparency = 0.5
        task.wait(0.15) -- [TUNING] flash speed
        platform.Transparency = originalTransparency
        task.wait(0.15)
    end

    task.wait(DISAPPEAR_DELAY)

    -- Vanish
    platform.Transparency = 1
    platform.CanCollide = false

    task.wait(RESTORE_DELAY)

    -- Restore
    platform.Transparency = originalTransparency
    platform.CanCollide = true
    debounce = false
end)
```

---

## Moving Platform (TweenService)

```lua
-- Script inside a Part (Anchored)
local TweenService = game:GetService("TweenService")
local platform = script.Parent
platform.Anchored = true

local startPos = platform.Position
local endPos   = startPos + Vector3.new(0, 0, 30) -- [TUNING] travel distance
local DURATION = 4 -- [TUNING] seconds one-way

local tweenInfo = TweenInfo.new(
    DURATION,
    Enum.EasingStyle.Linear,
    Enum.EasingDirection.InOut,
    -1,            -- repeat forever
    true,          -- reverses = PingPong
    0              -- no delay
)

local tween = TweenService:Create(platform, tweenInfo, {
    CFrame = CFrame.new(endPos),
})
tween:Play()
```

---

## Rebirth System

```lua
-- Server Script: RebirthHandler
local RS = game:GetService("ReplicatedStorage")
local remotes = RS:WaitForChild("Remotes")
local rebirthEvent = remotes:WaitForChild("RequestRebirth")

local REBIRTH_THRESHOLD = 1000 -- [TUNING] cash needed to rebirth
local EARNINGS_MULTIPLIER = 1.5 -- [TUNING] per rebirth

rebirthEvent.OnServerEvent:Connect(function(player)
    local data = _G.PlayerData.get(player) -- wire to your data module
    if data.cash < REBIRTH_THRESHOLD then return end
    data.cash = 0
    data.level = 1
    data.rebirths = (data.rebirths or 0) + 1
    -- Apply multiplier to future earnings
    player:SetAttribute("EarningsMultiplier", EARNINGS_MULTIPLIER ^ data.rebirths)
    -- Reset leaderstats
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local cashVal = ls:FindFirstChild("Cash")
        if cashVal then cashVal.Value = 0 end
    end
    _G.PlayerData.flush(player)
end)
```

---

## Win Zone

```lua
-- Server Script inside the win zone Part
local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")
local TPS = game:GetService("TeleportService")

local WIN_BADGE_ID = 0000000000 -- [TUNING] your badge ID
local LOBBY_PLACE_ID = 0000000000 -- [TUNING] lobby place ID

local winZone = script.Parent
winZone.Anchored = true
winZone.CanCollide = false
winZone.Transparency = 0.5

local debounce: {[Player]: boolean} = {}

winZone.Touched:Connect(function(hit)
    local player = Players:GetPlayerFromCharacter(hit.Parent)
    if not player then return end
    if debounce[player] then return end
    debounce[player] = true

    -- Record finish time
    local startTime = player:GetAttribute("ObbyStartTime")
    local elapsed = if startTime then os.clock() - startTime else 0
    player:SetAttribute("ObbyFinished", true)

    -- Award badge
    pcall(function()
        BadgeService:AwardBadge(player.UserId, WIN_BADGE_ID)
    end)

    -- Teleport to lobby after a moment
    task.delay(3, function() -- [TUNING] delay before teleport
        pcall(function()
            TPS:Teleport(LOBBY_PLACE_ID, player)
        end)
        debounce[player] = nil
    end)
end)
```

---

## Full Working Example: Obby Checkpoint Manager (~80 lines)

```lua
-- ServerScriptService/ObbyCheckpointManager
local Players = game:GetService("Players")

local checkpoints = workspace:WaitForChild("Checkpoints") -- Folder; children named "0","1","2"...
local progress: {[Player]: number} = {}

local function respawnAtCheckpoint(player: Player, character: Model)
    local idx = progress[player] or 0
    local cp = checkpoints:FindFirstChild(tostring(idx))
    if cp then
        character:PivotTo(cp.CFrame + Vector3.new(0, 3, 0)) -- [TUNING] spawn offset
    end
end

local function onCheckpointTouched(hit: BasePart)
    local character = hit.Parent
    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end
    local idx = tonumber(script.Parent.Name)
    if not idx then return end
    if idx <= (progress[player] or 0) then return end -- already passed
    progress[player] = idx
end

-- Wire up all checkpoints
for _, cp in checkpoints:GetChildren() do
    cp.Touched:Connect(onCheckpointTouched)
end

-- Handle player join and respawn
Players.PlayerAdded:Connect(function(player)
    progress[player] = 0
    player.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid")
        -- Small delay so default spawn finishes
        task.defer(function()
            task.wait()
            respawnAtCheckpoint(player, char)
        end)
        hum.Died:Connect(function()
            -- Auto-respawn is built-in; CharacterAdded fires again
        end)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    progress[player] = nil
end)

-- Kill brick helper (drop into any Part)
local function setupKillBrick(part: BasePart)
    part.CanCollide = false
    part.Anchored = true
    part.BrickColor = BrickColor.new("Really red")
    part.Material = Enum.Material.Neon
    part.Touched:Connect(function(hit)
        local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
        if hum then
            if hum:GetAttribute("KillCooldown") then return end
            hum:SetAttribute("KillCooldown", true)
            hum:TakeDamage(hum.MaxHealth) -- [TUNING]
            task.delay(1, function() hum:SetAttribute("KillCooldown", nil) end)
        end
    end)
end

return { setupKillBrick = setupKillBrick }
```
