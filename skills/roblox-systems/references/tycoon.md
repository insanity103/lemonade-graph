# Tycoon System

## Plot System

Pre-place plot pads (Parts) in a `Plots` folder in Workspace. Claim via `Touched` + player assignment; lock the claimed plot:

```lua
-- ServerScriptService/PlotManager (Script)
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local PLOTS = workspace:WaitForChild("Plots"):GetChildren()
local plotOwners = {} -- [plotPart] = Player

local function claimPlot(player, plotPart)
    if plotOwners[plotPart] then return false end -- already claimed
    plotOwners[plotPart] = player
    player.Team = game.Teams:FindFirstChild("Tycoon") -- visual team

    -- tag plot so other systems can look up the owner
    CollectionService:AddTag(plotPart, "PlayerPlot_" .. player.UserId)

    -- create leaderstats on claim
    local ls = player:FindFirstChild("leaderstats")
    if not ls then
        ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = player
    end
    if not ls:FindFirstChild("Cash") then
        local cash = Instance.new("IntValue"); cash.Name = "Cash"; cash.Value = 0; cash.Parent = ls
    end
    return true
end

-- Claim on Touched — first unclaimed plot the player steps on
for _, plot in PLOTS do
    plot.Touched:Connect(function(hit)
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if player and not plotOwners[plot] then
            claimPlot(player, plot)
        end
    end)
end

-- Release plot on player leaving
Players.PlayerRemoving:Connect(function(player)
    for plot, owner in plotOwners do
        if owner == player then
            plotOwners[plot] = nil
            CollectionService:RemoveTag(plot, "PlayerPlot_" .. player.UserId)
        end
    end
end)
```

## Building System

Purchase a button → clone instance from ServerStorage → position on plot grid → tag with CollectionService `'Building'`:

```lua
local ServerStorage = game:GetService("ServerStorage")
local Buildings = ServerStorage:WaitForChild("Buildings")

local BUILDING_COSTS = {
    Conveyor1 = 0,       -- free starter -- [TUNING]
    Dropper1  = 100,     -- [TUNING]
    Dropper2  = 500,     -- [TUNING]
    Upgrader1 = 250,     -- [TUNING]
}

local purchased = {} -- [player] = { [buildingName] = true }

local function purchaseBuilding(player, buildingName, positionOnPlot)
    local cost = BUILDING_COSTS[buildingName]
    if not cost then return false end

    local data = getPlayerData(player) -- your DataStore module
    if data.Currency < cost then return false end
    if purchased[player] and purchased[player][buildingName] then return false end

    data.Currency -= cost
    if not purchased[player] then purchased[player] = {} end
    purchased[player][buildingName] = true

    local template = Buildings:FindFirstChild(buildingName)
    if not template then return false end

    local instance = template:Clone()
    instance:SetPrimaryPartCFrame(CFrame.new(positionOnPlot))
    instance.Parent = workspace
    CollectionService:AddTag(instance, "Building")           -- generic tag
    CollectionService:AddTag(instance, "PlayerBuilding_" .. player.UserId)
    return true
end
```

## Conveyor

Move items along a belt surface. Option A: `LinearVelocity` constraint. Option B: `Heartbeat` CFrame offset (used for dropper ore flow):

```lua
local RunService = game:GetService("RunService")

-- Heartbeat approach — move unanchored parts sitting on the belt
local function setupConveyor(conveyorPart, direction, speed)
    speed = speed or 8 -- [TUNING] studs/second

    RunService.Heartbeat:Connect(function(dt)
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = { conveyorPart }

        local parts = workspace:GetPartBoundsInBox(
            conveyorPart.CFrame,
            conveyorPart.Size + Vector3.new(0, 2, 0) -- [TUNING] detection height
        )
        for _, part in parts do
            if part:IsA("BasePart") and part ~= conveyorPart and not part.Anchored then
                part.Position += direction.Unit * speed * dt
            end
        end
    end)
end
```

## Dropper

Spawn parts at an interval → fall onto conveyor or directly into collector:

```lua
local function setupDropper(dropperPart, ownerPlayer, valuePerDrop)
    valuePerDrop = valuePerDrop or 5 -- [TUNING] currency per ore

    task.spawn(function()
        while dropperPart.Parent do
            task.wait(2) -- [TUNING] drop interval (seconds)

            local ore = Instance.new("Part")
            ore.Name = "Ore"
            ore.Size = Vector3.new(1, 1, 1)
            ore.Color = Color3.fromRGB(255, 170, 0)
            ore.Material = Enum.Material.SmoothPlastic
            ore.CFrame = dropperPart.CFrame * CFrame.new(0, -3, 0)
            ore.Anchored = false
            ore:SetAttribute("Value", valuePerDrop)
            ore.Parent = workspace

            -- auto-cleanup if not collected
            task.delay(15, function() -- [TUNING] ore lifetime
                if ore.Parent then ore:Destroy() end
            end)
        end
    end)
end
```

## Collector

`Touched` on collector pad → Destroy ore → add currency to owner:

```lua
local function setupCollector(collectorPart, ownerPlayer, multiplier)
    multiplier = multiplier or 1 -- [TUNING] upgrade multiplier

    collectorPart.Touched:Connect(function(hit)
        if hit.Name ~= "Ore" then return end
        local value = hit:GetAttribute("Value") or 5 -- [TUNING] default ore value

        local data = getPlayerData(ownerPlayer)
        if not data then return end

        data.Currency += math.floor(value * multiplier)
        local ls = ownerPlayer:FindFirstChild("leaderstats")
        if ls and ls:FindFirstChild("Cash") then
            ls.Cash.Value = data.Currency
        end
        hit:Destroy()
    end)
end
```

## Upgrade Flow

DataStore stores building level. Cost = `base * multiplier ^ level`. Swap visual tier on upgrade:

```lua
local COST_MULTIPLIER = 1.5 -- [TUNING] cost scaling per level

local function getUpgradeCost(baseCost, level)
    return math.floor(baseCost * COST_MULTIPLIER ^ level)
end

local function upgradeBuilding(player, buildingName)
    local data = getPlayerData(player)
    local level = data.BuildingLevels and data.BuildingLevels[buildingName] or 0
    local baseCost = BUILDING_COSTS[buildingName]
    if not baseCost then return false end

    local cost = getUpgradeCost(baseCost, level + 1)
    if data.Currency < cost then return false end

    data.Currency -= cost
    if not data.BuildingLevels then data.BuildingLevels = {} end
    data.BuildingLevels[buildingName] = level + 1

    -- visual tier swap: find the player's building and swap model
    local tagged = CollectionService:GetTagged("PlayerBuilding_" .. player.UserId)
    for _, obj in tagged do
        if obj.Name == buildingName then
            -- swap mesh/model to higher tier variant
            -- e.g., obj.MeshId = "rbxassetid://TIER2_MESH"
        end
    end
    return true
end
```

## Rebirth

Wipe plot buildings, reset DataStore, multiply base earnings, award permanent token:

```lua
local REBIRTH_COST = 10000        -- [TUNING] currency threshold to rebirth
local EARNINGS_MULTIPLIER = 0.25  -- [TUNING] +25% per rebirth

local function rebirth(player)
    local data = getPlayerData(player)
    if data.Currency < REBIRTH_COST then return false end

    data.Rebirths = (data.Rebirths or 0) + 1
    data.Currency = 0
    data.BuildingLevels = {}
    data.PurchasedBuildings = {}

    -- permanent earnings multiplier
    data.EarningsMultiplier = 1 + (data.Rebirths * EARNINGS_MULTIPLIER)

    -- destroy all buildings on this player's plot
    for _, obj in CollectionService:GetTagged("PlayerBuilding_" .. player.UserId) do
        obj:Destroy()
    end

    -- award permanent rebirth token (IntValue or custom attribute)
    data.RebirthTokens = (data.RebirthTokens or 0) + 1

    savePlayerData(player) -- persist immediately
    return true
end
```

## Cash Leaderstat

Server-side only — never trust the client for currency:

```lua
local function setupLeaderstats(player)
    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"
    ls.Parent = player

    local cash = Instance.new("IntValue")
    cash.Name = "Cash"
    cash.Value = getPlayerData(player).Currency
    cash.Parent = ls
end

Players.PlayerAdded:Connect(setupLeaderstats)
```

## Auto-Save

`task.spawn` loop saves all players every 60 seconds:

```lua
task.spawn(function()
    while true do
        task.wait(60) -- [TUNING] save interval (seconds)
        for _, player in Players:GetPlayers() do
            task.spawn(pcall, savePlayerData, player) -- pcall to isolate errors
        end
    end
end)

-- Also save on leave and shutdown
Players.PlayerRemoving:Connect(function(player)
    savePlayerData(player)
end)
game:BindToClose(function()
    for _, player in Players:GetPlayers() do
        savePlayerData(player)
    end
end)
```

## Full Working Example: Dropper + Collector + Cash with Rebirth (< 100 lines)

```lua
-- ServerScriptService/TycoonCore (Script)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local rebirthEvent = Instance.new("RemoteEvent", RS); rebirthEvent.Name = "Rebirth"
local playerData = {}
local REBIRTH_THRESHOLD = 10000 -- [TUNING]
local REBIRTH_MULT = 0.25      -- [TUNING]
local DROP_VALUE = 5            -- [TUNING]
local DROP_INTERVAL = 2         -- [TUNING]

local function getData(uid)
    if not playerData[uid] then playerData[uid] = { Currency = 0, Rebirths = 0, Mult = 1 } end
    return playerData[uid]
end

local function updateCash(player)
    local ls = player:FindFirstChild("leaderstats")
    if ls and ls:FindFirstChild("Cash") then ls.Cash.Value = getData(player.UserId).Currency end
end

Players.PlayerAdded:Connect(function(player)
    local data = getData(player.UserId)
    local ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = player
    local cash = Instance.new("IntValue"); cash.Name = "Cash"; cash.Value = data.Currency; cash.Parent = ls
end)

local function initDropper(dropperPart, ownerUid)
    task.spawn(function()
        while dropperPart.Parent do
            task.wait(DROP_INTERVAL)
            local ore = Instance.new("Part"); ore.Name = "Ore"; ore.Size = Vector3.new(1,1,1)
            ore.Color = Color3.fromRGB(255,170,0); ore.Material = Enum.Material.Neon
            ore.CFrame = dropperPart.CFrame * CFrame.new(0,-3,0); ore.Anchored = false
            ore:SetAttribute("Value", DROP_VALUE); ore.Parent = workspace
            task.delay(15, function() if ore.Parent then ore:Destroy() end end) -- [TUNING]
        end
    end)
end

local function initCollector(collectorPart, ownerPlayer, ownerUid)
    collectorPart.Touched:Connect(function(hit)
        if hit.Name ~= "Ore" then return end
        local val = hit:GetAttribute("Value") or DROP_VALUE
        local data = getData(ownerUid)
        data.Currency += math.floor(val * data.Mult)
        updateCash(ownerPlayer); hit:Destroy()
    end)
end

rebirthEvent.OnServerEvent:Connect(function(player)
    local data = getData(player.UserId)
    if data.Currency < REBIRTH_THRESHOLD then return end
    data.Rebirths += 1; data.Currency = 0
    data.Mult = 1 + data.Rebirths * REBIRTH_MULT
    updateCash(player)
end)

Players.PlayerRemoving:Connect(function(player) playerData[player.UserId] = nil end)

task.spawn(function()
    while true do task.wait(60) -- [TUNING]
        for _, p in Players:GetPlayers() do pcall(savePlayerData, p) end -- replace with real save
    end
end)
```
