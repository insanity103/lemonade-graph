# Tycoon Code Patterns

## Conveyor Belt

```lua
-- Script inside a long Part (Anchored, oriented along desired travel direction)
local belt = script.Parent
local SPEED = 12 -- [TUNING] studs per second

-- Option A: LinearVelocity on a hidden mover part (smooth)
-- Option B: CFrame nudge each Heartbeat (simple, shown below)

local RunService = game:GetService("RunService")
local direction = belt.CFrame.LookVector

RunService.Heartbeat:Connect(function(dt)
    -- Move all touching parts forward
    local offset = direction * SPEED * dt
    -- Use a BodyVelocity or just rely on conveyor surface velocity:
    belt.AssemblyLinearVelocity = direction * SPEED
end)

-- Better: Use a VectorForce or set SurfaceVelocity on a SurfaceGui (no).
-- Best for conveyors: use a cylindrical constraint or simply set
-- belt's AssemblyLinearVelocity so physics carries riders.

belt.Anchored = true
belt:SetAttribute("ConveyorSpeed", SPEED)
```

---

## Dropper (Spawns Parts on Interval)

```lua
-- Script inside the Dropper Part (the "spout")
local dropper = script.Parent
local DROP_INTERVAL = 1.5  -- [TUNING] seconds between drops
local DROP_TEMPLATE = dropper:FindFirstChild("DropPart") -- a small Part child
local DROP_LIFETIME = 15   -- [TUNING] seconds before auto-cleanup

if not DROP_TEMPLATE then
    warn("DropPart not found inside Dropper")
    return
end
DROP_TEMPLATE.Anchored = false
DROP_TEMPLATE.CanCollide = true

while true do
    task.wait(DROP_INTERVAL)
    local drop = DROP_TEMPLATE:Clone()
    drop.CFrame = dropper.CFrame * CFrame.new(0, -2, 0) -- [TUNING] spawn offset
    drop.Parent = workspace.Drops -- organize in a folder
    -- Auto-cleanup
    task.delay(DROP_LIFETIME, function()
        if drop.Parent then drop:Destroy() end
    end)
end
```

---

## Collector (Touched → Destroy Drop + Add Cash)

```lua
-- Script inside the Collector Part (conveyor endpoint)
local collector = script.Parent
local CASH_PER_DROP = 10 -- [TUNING]
local CollectionService = game:GetService("CollectionService")

-- Tag this part so it's identifiable
CollectionService:AddTag(collector, "Collector")

-- Determine the owner of this tycoon plot (set by plot claiming system)
local owner: Player? = nil -- assigned when plot is claimed

collector.Touched:Connect(function(hit)
    if not hit:IsA("BasePart") then return end
    if not hit:GetAttribute("IsDrop") then return end -- only process dropper outputs
    if not owner then return end

    hit:Destroy()

    -- Add cash via leaderstats
    local ls = owner:FindFirstChild("leaderstats")
    if not ls then return end
    local cash = ls:FindFirstChild("Cash")
    if not cash then return end
    cash.Value += CASH_PER_DROP * (owner:GetAttribute("EarningsMultiplier") or 1)
end)
```

---

## Building Purchase (RemoteEvent → Validate → Instance)

```lua
-- Server Script: BuildingHandler
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local remotes = RS:WaitForChild("Remotes")
local purchaseBuild = remotes:WaitForChild("PurchaseBuild")

local BUILDINGS = {
    Conveyor1  = { cost = 100,  template = "Conveyor1"  },
    Dropper1   = { cost = 250,  template = "Dropper1"   },
    Upgrade1   = { cost = 500,  template = "Upgrade1"   },
}

purchaseBuild.OnServerEvent:Connect(function(player: Player, buildingId: string, plotId: string)
    -- Type check
    if typeof(buildingId) ~= "string" or typeof(plotId) ~= "string" then return end

    local build = BUILDINGS[buildingId]
    if not build then return end

    -- Check ownership of plot
    local plot = workspace.Plots:FindFirstChild(plotId)
    if not plot or plot:GetAttribute("Owner") ~= player.UserId then return end

    -- Check if already purchased
    if CollectionService:HasTag(plot, "Built_" .. buildingId) then return end

    -- Check cash
    local ls = player:FindFirstChild("leaderstats")
    local cash = ls and ls:FindFirstChild("Cash")
    if not cash or cash.Value < build.cost then return end

    -- Deduct
    cash.Value -= build.cost

    -- Instantiate from ServerStorage
    local template = SS.TycoonTemplates:FindFirstChild(build.template)
    if not template then warn("Missing template: " .. build.template) return end
    local instance = template:Clone()
    instance.Parent = plot.Buildings -- subfolder on the plot

    -- Tag as built
    CollectionService:AddTag(plot, "Built_" .. buildingId)
end)
```

---

## Upgrade Cost Formula

```lua
local function upgradeCost(baseCost: number, level: number): number
    return math.floor(baseCost * (1.5 ^ level)) -- [TUNING] exponential scaling
end

-- Example: baseCost=100 → L0=100, L1=150, L2=225, L3=338, ...
```

---

## Plot Claiming

```lua
-- Script inside each Plot's ClaimPad Part
local claimPad = script.Parent
local plot = claimPad.Parent -- the Plot Model
local CollectionService = game:GetService("CollectionService")

local LOCK_RADIUS = 20 -- [TUNING] studs — no other player can claim nearby

claimPad.Touched:Connect(function(hit)
    local player = game.Players:GetPlayerFromCharacter(hit.Parent)
    if not player then return end

    -- Already claimed?
    if plot:GetAttribute("Owner") then return end

    -- Check player doesn't already own another plot
    for _, otherPlot in CollectionService:GetTagged("TycoonPlot") do
        if otherPlot:GetAttribute("Owner") == player.UserId then return end
    end

    plot:SetAttribute("Owner", player.UserId)
    plot:SetAttribute("OwnerName", player.Name)
    CollectionService:AddTag(plot, "TycoonPlot")

    -- Visual feedback
    claimPad.BrickColor = BrickColor.new("Bright green")
end)
```

---

## Rebirth (Reset Data, Multiply Earnings)

```lua
-- Server Script
local REBIRTH_COST = 10000  -- [TUNING] cash needed
local MULTIPLIER   = 1.5    -- [TUNING] earnings multiplier per rebirth

local function rebirth(player: Player)
    local data = _G.PlayerData.get(player) -- wire to your data module
    if data.cash < REBIRTH_COST then return end

    data.cash = 0
    data.rebirths = (data.rebirths or 0) + 1

    local mult = MULTIPLIER ^ data.rebirths
    player:SetAttribute("EarningsMultiplier", mult)

    -- Reset leaderstats
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local cashVal = ls:FindFirstChild("Cash")
        if cashVal then cashVal.Value = 0 end
    end

    -- Reset plot buildings
    for _, plot in game:GetService("CollectionService"):GetTagged("TycoonPlot") do
        if plot:GetAttribute("Owner") == player.UserId then
            for _, child in plot.Buildings:GetChildren() do child:Destroy() end
            plot:SetAttribute("Owner", nil)
            -- Remove build tags
            for _, tag in plot:GetTags() do
                if string.match(tag, "^Built_") then
                    game:GetService("CollectionService"):RemoveTag(plot, tag)
                end
            end
        end
    end

    _G.PlayerData.flush(player)
end
```

---

## Cash Display via Leaderstats

```lua
-- Server Script (PlayerAdded)
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"
    ls.Parent = player

    local cash = Instance.new("IntValue")
    cash.Name = "Cash"
    cash.Value = 0
    cash.Parent = ls

    -- Update from DataStore on load
    -- local data = PlayerData.get(player)
    -- cash.Value = data.cash

    cash.Changed:Connect(function(newVal)
        -- Sync back to data module
        -- local data = PlayerData.get(player)
        -- data.cash = newVal
    end)
end)
```

---

## Full Working Example: Dropper + Collector + Cash System (~80 lines)

```lua
-- ServerScriptService/TycoonCore
local Players = game:GetService("Players")
local SS = game:GetService("ServerStorage")

local CASH_PER_DROP   = 10   -- [TUNING]
local DROP_INTERVAL   = 1.5  -- [TUNING]
local DROP_LIFETIME   = 15   -- [TUNING]
local CONVEYOR_SPEED  = 12   -- [TUNING]

-- Setup leaderstats
Players.PlayerAdded:Connect(function(player)
    local ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = player
    local c = Instance.new("IntValue"); c.Name = "Cash"; c.Value = 0; c.Parent = ls
end)

-- Conveyor: nudge touching parts
local function setupConveyor(belt: BasePart)
    local dir = belt.CFrame.LookVector
    belt:SetAttribute("ConveyorSpeed", CONVEYOR_SPEED)
    game:GetService("RunService").Heartbeat:Connect(function(dt)
        belt.AssemblyLinearVelocity = dir * CONVEYOR_SPEED
    end)
end

-- Dropper: spawn parts
local function setupDropper(spout: BasePart, owner: Player, collector: BasePart)
    local template = spout:FindFirstChild("DropPart")
    if not template then return end
    template.Anchored = false
    template:SetAttribute("IsDrop", true)

    local dropsFolder = Instance.new("Folder")
    dropsFolder.Name = "Drops_" .. owner.UserId
    dropsFolder.Parent = workspace

    -- Collector: absorb drops
    collector.Touched:Connect(function(hit)
        if not hit:GetAttribute("IsDrop") then return end
        if not hit:IsDescendantOf(dropsFolder) then return end
        hit:Destroy()
        local ls = owner:FindFirstChild("leaderstats")
        local cash = ls and ls:FindFirstChild("Cash")
        if cash then
            cash.Value += CASH_PER_DROP * (owner:GetAttribute("EarningsMultiplier") or 1)
        end
    end)

    -- Spawn loop
    task.spawn(function()
        while spout.Parent do
            task.wait(DROP_INTERVAL)
            local drop = template:Clone()
            drop.CFrame = spout.CFrame * CFrame.new(0, -2, 0)
            drop.Parent = dropsFolder
            task.delay(DROP_LIFETIME, function()
                if drop.Parent then drop:Destroy() end
            end)
        end
    end)
end

return { setupConveyor = setupConveyor, setupDropper = setupDropper }
```
