# NPC AI System

## NPC Setup

NPC Model structure (in ServerStorage or placed in Workspace):

```
NPC (Model)
├── HumanoidRootPart (Part) — PrimaryPart
├── Head (Part)
├── Torso (Part) — or MeshParts for R15
├── Humanoid (Humanoid)
└── (optional) NPCConfig (ModuleScript) — tuning values
```

```lua
-- Spawn from ServerStorage template
local ServerStorage = game:GetService("ServerStorage")
local npcTemplate = ServerStorage:WaitForChild("NPC_Template")

local npc = npcTemplate:Clone()
npc:SetPrimaryPartCFrame(CFrame.new(0, 5, 0))
npc.Parent = workspace -- or workspace.NPCs folder
```

```lua
-- NPCConfig ModuleScript (optional, inside model)
return {
    Health = 100,            -- [TUNING]
    WalkSpeed = 16,          -- [TUNING]
    ChaseSpeed = 22,         -- [TUNING]
    AttackDamage = 15,       -- [TUNING]
    AttackCooldown = 1.5,    -- [TUNING] seconds
    AttackRange = 8,         -- [TUNING] studs
    AggroRange = 50,         -- [TUNING] studs
    DeaggroRange = 80,       -- [TUNING] studs — lose aggro beyond this
    PatrolSpeed = 8,         -- [TUNING]
    ReturnRange = 100,       -- [TUNING] max distance from spawn before forced return
    RespawnTime = 10,        -- [TUNING] seconds
    TickRate = 0.3,          -- [TUNING] AI decision interval (seconds)
}
```

## State Machine

```
         ┌──────────┐
         │   Idle   │
         └────┬─────┘
              │ player in AggroRange
         ┌────▼─────┐
    ┌────│  Patrol   │◄──────────────────────┐
    │    └────┬─────┘                        │
    │         │ player in AggroRange         │
    │    ┌────▼─────┐                  ┌─────┴────┐
    │    │  Chase   │──────────────────│  Return   │
    │    └────┬─────┘  target lost     └──────────┘
    │         │         or too far        ▲
    │    ┌────▼─────┐                     │ > 100 studs from spawn
    │    │  Attack  │─────────────────────┘
    │    └────┬─────┘
    │         │ target leaves range / dead
    └─────────┘
```

Transitions checked every `TickRate` seconds (0.2–0.5). -- [TUNING]

## Patrol

Walk waypoints array in sequence, pause at each:

```lua
local function runPatrol(npc, waypoints, index)
    if #waypoints == 0 then return 1 end
    local nextIndex = (index % #waypoints) + 1
    local humanoid = npc:FindFirstChildOfClass("Humanoid")
    humanoid.WalkSpeed = npc.Config.PatrolSpeed -- [TUNING]
    humanoid:MoveTo(waypoints[nextIndex].Position)
    -- wait until reached or timeout
    local reached = false
    local conn = humanoid.MoveToFinished:Connect(function() reached = true end)
    task.delay(3, function() reached = true end) -- [TUNING] waypoint timeout
    repeat task.wait() until reached
    conn:Disconnect()
    task.wait(1) -- [TUNING] pause at waypoint
    return nextIndex
end
```

## Chase

Use `PathfindingService:ComputeAsync` for intelligent pathing around obstacles. Recompute every ~2 seconds as target moves:

```lua
local PathService = game:GetService("PathfindingService")

local function chaseTarget(npc, targetPosition)
    local humanoid = npc:FindFirstChildOfClass("Humanoid")
    local root = npc:FindFirstChild("HumanoidRootPart")
    if not root then return end

    humanoid.WalkSpeed = npc.Config.ChaseSpeed -- [TUNING]

    local path = PathService:CreatePath({
        AgentRadius = 2,     -- [TUNING]
        AgentHeight = 5,     -- [TUNING]
        AgentCanJump = true,
    })

    local ok = pcall(path.ComputeAsync, path, root.Position, targetPosition)
    if not ok or path.Status ~= Enum.PathStatus.Success then
        humanoid:MoveTo(targetPosition) -- fallback: direct walk
        return
    end

    for _, waypoint in path:GetWaypoints() do
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end
        humanoid:MoveTo(waypoint.Position)
        humanoid.MoveToFinished:Wait()
    end
end

-- Recompute path periodically during chase:
-- task.spawn(function()
--     while state == "Chase" do
--         chaseTarget(npc, target.HumanoidRootPart.Position)
--         task.wait(2) -- [TUNING] recompute interval
--     end
-- end)
```

## Attack

Check range → deal damage on cooldown → return to Chase if target leaves range:

```lua
local function tryAttack(npc, target, config, lastAttackTime)
    if os.clock() - lastAttackTime < config.AttackCooldown then
        return lastAttackTime
    end
    local root = npc:FindFirstChild("HumanoidRootPart")
    local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not root or not targetRoot then return lastAttackTime end

    local dist = (root.Position - targetRoot.Position).Magnitude
    if dist > config.AttackRange then return lastAttackTime end -- leave Attack state

    local hum = target.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:TakeDamage(config.AttackDamage)
    end
    return os.clock()
end
```

## Aggro (Threat Table)

Maintain a threat table. Target the highest-threat player. Reset when distance > max or line-of-sight lost:

```lua
local function updateThreat(threatTable, player, damage)
    threatTable[player] = (threatTable[player] or 0) + damage
end

local function getHighestThreat(threatTable, npcRoot, deaggroRange)
    local bestPlayer, bestThreat = nil, 0
    for player, threat in pairs(threatTable) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hrp and hum and hum.Health > 0 then
            local dist = (npcRoot.Position - hrp.Position).Magnitude
            if dist > deaggroRange then
                threatTable[player] = nil -- [TUNING] reset on distance
            else
                -- line-of-sight check via raycast
                local ray = workspace:Raycast(
                    npcRoot.Position,
                    (hrp.Position - npcRoot.Position).Unit * dist,
                    RaycastParams.new() -- configure filter as needed
                )
                if ray and ray.Instance and ray.Instance:IsDescendantOf(char) then
                    if threat > bestThreat then
                        bestPlayer = player
                        bestThreat = threat
                    end
                else
                    threatTable[player] = nil -- LOS lost, reset
                end
            end
        end
    end
    return bestPlayer
end
```

## Return

If target > 100 studs from spawn, pathfind back, reset to Idle/Patrol:

```lua
local function shouldReturn(npcRoot, spawnPosition, returnRange)
    return (npcRoot.Position - spawnPosition).Magnitude > returnRange -- [TUNING] 100
end

local function returnToSpawn(npc, spawnPosition)
    local humanoid = npc:FindFirstChildOfClass("Humanoid")
    humanoid.WalkSpeed = npc.Config.PatrolSpeed
    humanoid:MoveTo(spawnPosition)
    -- or use PathfindingService:ComputeAsync for obstacle avoidance
end
```

## Respawn

On Death → cleanup → `task.delay(respawnTime)` → recreate at spawn:

```lua
local function setupRespawn(npc, spawnCFrame, template, config)
    local humanoid = npc:FindFirstChildOfClass("Humanoid")
    humanoid.Died:Connect(function()
        -- optional: drop loot, play death VFX
        task.delay(config.RespawnTime, function() -- [TUNING]
            npc:Destroy()
            local newNPC = template:Clone()
            newNPC:SetPrimaryPartCFrame(spawnCFrame)
            newNPC.Parent = workspace.NPCs
            setupRespawn(newNPC, spawnCFrame, template, config)
            runAI(newNPC, spawnCFrame.Position)
        end)
    end)
end
```

## Group Behavior

Leader NPC drives decisions; follower NPCs maintain formation offsets around the leader:

```lua
local FORMATION_OFFSETS = {
    Vector3.new(-4, 0, -4),  -- [TUNING] left-rear
    Vector3.new(4, 0, -4),   -- [TUNING] right-rear
    Vector3.new(0, 0, -8),   -- [TUNING] center-rear
}

local function getFormationPosition(leaderCFrame, offsetIndex)
    local offset = FORMATION_OFFSETS[offsetIndex] or Vector3.zero
    return leaderCFrame:PointToWorldSpace(offset)
end

-- Leader runs full state machine; followers copy leader's state
-- and MoveTo their formation position relative to the leader.
local function updateFollowers(leader, followers)
    local leaderRoot = leader:FindFirstChild("HumanoidRootPart")
    if not leaderRoot then return end
    for i, follower in ipairs(followers) do
        local hum = follower:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            local targetPos = getFormationPosition(leaderRoot.CFrame, i)
            hum:MoveTo(targetPos)
        end
    end
end
```

Group structure: one leader NPC per group, 1–3 followers. Followers share the leader's state (Patrol/Chase/Attack) but move to formation offsets instead of directly toward the target.

## Full Working Example: NPC with Patrol + Chase + Attack (< 100 lines)

```lua
-- ServerScriptService/NPCController (Script)
local PathService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local npcTemplate = ServerStorage:WaitForChild("NPC_Template")
local CONFIG = {
    Health = 100, WalkSpeed = 12, ChaseSpeed = 20, -- [TUNING]
    AttackDamage = 15, AttackCooldown = 1.5, AttackRange = 8, -- [TUNING]
    AggroRange = 40, ReturnRange = 100, RespawnTime = 10, TickRate = 0.3, -- [TUNING]
}

local WAYPOINTS = {}
local wpFolder = workspace:FindFirstChild("Waypoints")
if wpFolder then for _, w in wpFolder:GetChildren() do table.insert(WAYPOINTS, w) end end

local function nearestPlayer(pos, range)
    local best, bestDist = nil, range
    for _, p in Players:GetPlayers() do
        local c = p.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if h and hum and hum.Health > 0 then
            local d = (pos - h.Position).Magnitude
            if d < bestDist then best, bestDist = p, d end
        end
    end
    return best, bestDist
end

local function runAI(npc, spawnPos)
    local hum = npc:WaitForChild("Humanoid")
    local root = npc:WaitForChild("HumanoidRootPart")
    hum.MaxHealth, hum.Health, hum.WalkSpeed = CONFIG.Health, CONFIG.Health, CONFIG.WalkSpeed
    local state, wpIdx, lastAtk, target = "Patrol", 1, 0, nil
    hum.Died:Connect(function()
        task.delay(CONFIG.RespawnTime, function()
            local pos = npc:GetPrimaryPartCFrame()
            npc:Destroy()
            local n = npcTemplate:Clone(); n:SetPrimaryPartCFrame(pos)
            n.Parent = workspace:FindFirstChild("NPCs") or workspace
            runAI(n, spawnPos)
        end)
    end)
    while hum.Health > 0 do
        task.wait(CONFIG.TickRate)
        local pos = root.Position
        if (pos - spawnPos).Magnitude > CONFIG.ReturnRange then state = "Return" end
        if state == "Patrol" then
            local p, _ = nearestPlayer(pos, CONFIG.AggroRange)
            if p then state, target = "Chase", p
            elseif #WAYPOINTS > 0 then
                hum.WalkSpeed = CONFIG.WalkSpeed; hum:MoveTo(WAYPOINTS[wpIdx].Position)
                if (pos - WAYPOINTS[wpIdx].Position).Magnitude < 4 then
                    wpIdx = (wpIdx % #WAYPOINTS) + 1
                end
            end
        elseif state == "Chase" then
            if not target or not target.Character or target.Character.Humanoid.Health <= 0 then
                state, target = "Patrol", nil; continue
            end
            local tr = target.Character.HumanoidRootPart
            local d = (pos - tr.Position).Magnitude
            if d > CONFIG.AggroRange * 1.5 then state, target = "Patrol", nil -- [TUNING]
            elseif d <= CONFIG.AttackRange then state = "Attack"
            else hum.WalkSpeed = CONFIG.ChaseSpeed; hum:MoveTo(tr.Position) end
        elseif state == "Attack" then
            if not target or not target.Character or target.Character.Humanoid.Health <= 0 then
                state, target = "Patrol", nil; continue
            end
            local d = (pos - target.Character.HumanoidRootPart.Position).Magnitude
            if d > CONFIG.AttackRange * 1.3 then state = "Chase" -- [TUNING]
            elseif os.clock() - lastAtk >= CONFIG.AttackCooldown then
                target.Character.Humanoid:TakeDamage(CONFIG.AttackDamage); lastAtk = os.clock()
            end
        elseif state == "Return" then
            hum.WalkSpeed = CONFIG.WalkSpeed; hum:MoveTo(spawnPos)
            if (pos - spawnPos).Magnitude < 5 then state = "Patrol"; hum.Health = hum.MaxHealth end
        end
    end
end

-- Spawn NPCs at marker positions
local npcFolder = Instance.new("Folder"); npcFolder.Name = "NPCs"; npcFolder.Parent = workspace
local spawns = workspace:FindFirstChild("NPCSpawns")
if spawns then
    for _, sp in spawns:GetChildren() do
        local npc = npcTemplate:Clone(); npc:SetPrimaryPartCFrame(sp.CFrame); npc.Parent = npcFolder
        task.spawn(runAI, npc, sp.Position)
    end
end
```
