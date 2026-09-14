# Combat / FPS Code Patterns

## Raycast Hit Detection

```lua
-- Server Script: fires a ray from the weapon origin
local function fireRay(origin: Vector3, direction: Vector3, range: number): RaycastResult?
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {} -- add shooter's character
    params.RespectCanCollide = true

    local result = workspace:Raycast(origin, direction.Unit * range, params)
    return result
end

local function getHumanoidFromRay(result: RaycastResult): Humanoid?
    local part = result.Instance
    local model = part:FindFirstAncestorOfClass("Model")
    return model and model:FindFirstChildOfClass("Humanoid")
end
```

---

## Region3 Hit Detection (Area Attacks)

```lua
local function getCharactersInRadius(center: Vector3, radius: number, exclude: Model?): {Model}
    local region = Region3.new(
        center - Vector3.one * radius,
        center + Vector3.one * radius
    ):ExpandToGrid(4)

    local parts = workspace:ReadVoxels(region, 4) -- not ideal for characters

    -- Better approach: spatial query
    local hits: {Model} = {}
    for _, model in workspace:GetDescendants() do
        if not model:IsA("Model") or model == exclude then continue end
        local hum = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart")
        if hum and root and hum.Health > 0 then
            if (root.Position - center).Magnitude <= radius then
                table.insert(hits, model)
            end
        end
    end
    return hits
end
```

---

## Damage System (Server Only)

```lua
local function applyDamage(target: Humanoid, amount: number, attacker: Player?)
    if target.Health <= 0 then return end
    -- Clamp to valid range
    amount = math.clamp(amount, 0, target.MaxHealth) -- [TUNING]
    target:TakeDamage(amount)
end
```

---

## Cooldown System

```lua
local cooldowns: {[Player]: {[string]: number}} = {}

local function isOnCooldown(player: Player, action: string): boolean
    local bucket = cooldowns[player]
    if not bucket then return false end
    local expiry = bucket[action]
    if not expiry then return false end
    return os.clock() < expiry
end

local function setCooldown(player: Player, action: string, duration: number)
    if not cooldowns[player] then cooldowns[player] = {} end
    cooldowns[player][action] = os.clock() + duration
end

-- Cleanup
game:GetService("Players").PlayerRemoving:Connect(function(player)
    cooldowns[player] = nil
end)
```

---

## Projectile (Server-Side)

```lua
local function fireProjectile(origin: CFrame, direction: Vector3, shooter: Player)
    local SPEED = 100 -- [TUNING] studs/sec
    local DAMAGE = 25 -- [TUNING]
    local MAX_LIFETIME = 5 -- [TUNING] seconds

    local bullet = Instance.new("Part")
    bullet.Size = Vector3.new(0.3, 0.3, 1) -- [TUNING]
    bullet.CFrame = origin
    bullet.Anchored = false
    bullet.CanCollide = false
    bullet.Material = Enum.Material.Neon
    bullet.BrickColor = BrickColor.new("New Yeller")
    bullet.Parent = workspace

    local bv = Instance.new("LinearVelocity")
    bv.MaxForce = math.huge
    bv.VectorVelocity = direction.Unit * SPEED
    bv.Attachment0 = Instance.new("Attachment", bullet)
    bv.Parent = bullet

    bullet.Touched:Connect(function(hit)
        if hit:IsDescendantOf(shooter.Character or nil) then return end
        local model = hit:FindFirstAncestorOfClass("Model")
        local hum = model and model:FindFirstChildOfClass("Humanoid")
        if hum then
            applyDamage(hum, DAMAGE, shooter)
        end
        bullet:Destroy()
    end)

    task.delay(MAX_LIFETIME, function()
        if bullet.Parent then bullet:Destroy() end
    end)
end
```

---

## Health Regeneration

```lua
-- Script inside each Character model (or server-wide)
local RunService = game:GetService("RunService")
local REGEN_RATE = 5      -- [TUNING] HP per second
local REGEN_DELAY = 4     -- [TUNING] seconds after last damage before regen starts

local function setupRegen(humanoid: Humanoid)
    local lastDamageTime = os.clock()

    humanoid.HealthChanged:Connect(function(newHealth)
        -- Detect damage (health decreased)
        if newHealth < humanoid:GetAttribute("LastHealth") or 0 then
            lastDamageTime = os.clock()
        end
        humanoid:SetAttribute("LastHealth", newHealth)
    end)

    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        if humanoid.Health <= 0 then
            connection:Disconnect()
            return
        end
        if os.clock() - lastDamageTime < REGEN_DELAY then return end
        if humanoid.Health >= humanoid.MaxHealth then return end
        humanoid.Health = math.min(humanoid.Health + REGEN_RATE * dt, humanoid.MaxHealth)
    end)
end
```

---

## Combo System

```lua
local combos: {[Player]: { count: number, lastHit: number }} = {}
local COMBO_WINDOW = 2.0  -- [TUNING] seconds to chain hits
local COMBO_BONUS  = 0.15 -- [TUNING] 15% damage bonus per combo level
local MAX_COMBO    = 5    -- [TUNING]

local function registerHit(player: Player, baseDamage: number): number
    local now = os.clock()
    local combo = combos[player]

    if not combo or (now - combo.lastHit) > COMBO_WINDOW then
        combo = { count = 1, lastHit = now }
    else
        combo.count = math.min(combo.count + 1, MAX_COMBO)
        combo.lastHit = now
    end
    combos[player] = combo

    local multiplier = 1 + (combo.count - 1) * COMBO_BONUS
    return math.floor(baseDamage * multiplier), combo.count
end
```

---

## Anti-Exploit Checks

```lua
local MAX_FIRE_RATE = 10     -- [TUNING] shots per second
local MAX_RANGE     = 500    -- [TUNING] studs
local DAMAGE_CAP    = 100    -- [TUNING] max single-hit damage

local fireTimestamps: {[Player]: number} = {}

local function validateShot(player: Player, origin: Vector3, target: Vector3): boolean
    -- Fire rate
    local now = os.clock()
    local last = fireTimestamps[player] or 0
    if now - last < (1 / MAX_FIRE_RATE) then return false end
    fireTimestamps[player] = now

    -- Range
    if (target - origin).Magnitude > MAX_RANGE then return false end

    -- Origin sanity: must be near character
    local char = player.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    if (origin - root.Position).Magnitude > 10 then return false end -- [TUNING]

    return true
end
```

---

## Full Working Example: Server-Authoritative Raycast Weapon (~80 lines)

```lua
-- ServerScriptService/RaycastWeaponHandler
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local remotes = RS:WaitForChild("Remotes")
local fireEvent = remotes:WaitForChild("FireWeapon")
local hitEvent  = remotes:WaitForChild("NotifyHit") -- optional client feedback

-- Weapon stats
local WEAPON_DAMAGE  = 35   -- [TUNING]
local WEAPON_RANGE   = 300  -- [TUNING]
local FIRE_COOLDOWN  = 0.2  -- [TUNING] seconds
local MAX_ORIGIN_DEV = 10   -- [TUNING] max studs from character

-- State
local cooldowns: {[Player]: boolean} = {}

local function validate(player: Player, origin: Vector3, direction: Vector3): boolean
    if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then return false end
    local char = player.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    if (origin - root.Position).Magnitude > MAX_ORIGIN_DEV then return false end
    if direction.Magnitude < 0.9 or direction.Magnitude > 1.1 then return false end -- must be ~unit
    if cooldowns[player] then return false end
    return true
end

fireEvent.OnServerEvent:Connect(function(player: Player, origin: Vector3, direction: Vector3)
    if not validate(player, origin, direction) then return end
    cooldowns[player] = true
    task.delay(FIRE_COOLDOWN, function() cooldowns[player] = nil end)

    -- Exclude shooter from ray
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { player.Character }

    local result = workspace:Raycast(origin, direction * WEAPON_RANGE, params)
    if not result then return end

    local part = result.Instance
    local model = part:FindFirstAncestorOfClass("Model")
    local humanoid = model and model:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- Damage falloff based on distance
    local dist = (result.Position - origin).Magnitude
    local falloff = 1 - (dist / WEAPON_RANGE) * 0.3 -- [TUNING] 30% falloff at max range
    local damage = math.floor(WEAPON_DAMAGE * falloff)

    humanoid:TakeDamage(damage)

    -- Notify attacker for hitmarker
    hitEvent:FireClient(player, damage, model.Name)
end)

Players.PlayerRemoving:Connect(function(player)
    cooldowns[player] = nil
end)
```
