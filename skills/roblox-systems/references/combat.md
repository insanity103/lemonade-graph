# Combat System Architecture

## Hit Detection Methods

| Method | Use case | Precision |
|---|---|---|
| **Raycast** | Melee swings, bullets, line-of-sight | High — pixel-perfect along a ray |
| **Region3** | AOE explosions, area buffs | Medium — axis-aligned box |
| **Magnitude** | Quick proximity checks, touch-range | Low — sphere radius only |

## Raycast Pattern

```lua
local function raycastHit(origin, direction, ignoreList, maxRange)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList or {}

	local result = workspace:Raycast(origin, direction.Unit * maxRange, params)
	if not result then return nil end

	-- walk up to find Humanoid in ancestor
	local part = result.Instance
	local model = part:FindFirstAncestorOfClass("Model")
	if not model then return nil end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end

	return humanoid, result.Position, part
end
```

## Damage Calculation

```lua
local BASE_DAMAGE = 10    -- [TUNING]
local ARMOR_FACTOR = 0.5  -- [TUNING] damage reduction per armor point

local function calculateDamage(baseDmg, weaponMultiplier, comboBonus, armor)
	local raw = baseDmg * weaponMultiplier * (1 + comboBonus)
	local reduced = raw - (armor * ARMOR_FACTOR)
	return math.max(math.floor(reduced), 1)
end
```

## Cooldown System

```lua
local cooldowns = {} -- [playerId] = os.clock() of last hit

local function isOnCooldown(player, cooldownTime)
	local last = cooldowns[player.UserId] or 0
	if os.clock() - last < cooldownTime then return true end -- [TUNING] cooldownTime per weapon
	cooldowns[player.UserId] = os.clock()
	return false
end
```

## Projectile System

Server-authoritative projectiles: create a Part, apply velocity, detect `Touched`.

```lua
local function fireProjectile(player, origin, direction, speed, damage)
	local bullet = Instance.new("Part")
	bullet.Size = Vector3.new(0.5, 0.5, 1) -- [TUNING]
	bullet.CFrame = CFrame.new(origin, origin + direction)
	bullet.Anchored = false
	bullet.CanCollide = false
	bullet.Material = Enum.Material.Neon
	bullet.Color = Color3.fromRGB(255, 100, 50)
	bullet.Parent = workspace

	local bv = Instance.new("BodyVelocity")
	bv.Velocity = direction.Unit * speed -- [TUNING] speed e.g. 200
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.Parent = bullet

	local touched = false
	bullet.Touched:Connect(function(hit)
		if touched then return end
		local model = hit:FindFirstAncestorOfClass("Model")
		if not model or model == player.Character then return end
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return end
		touched = true
		hum:TakeDamage(damage)
		bullet:Destroy()
	end)

	-- auto-cleanup after 5 seconds
	task.delay(5, function() -- [TUNING]
		if bullet.Parent then bullet:Destroy() end
	end)
end
```

## Combo System

```lua
local comboData = {} -- [playerId] = { hits = number, lastHitTime = number }
local COMBO_TIMEOUT = 1.5 -- [TUNING] seconds before combo resets
local COMBO_BONUS   = 0.1 -- [TUNING] bonus multiplier per combo hit

local function getComboMultiplier(player)
	local data = comboData[player.UserId]
	if not data then return 1 end
	if os.clock() - data.lastHitTime > COMBO_TIMEOUT then
		comboData[player.UserId] = { hits = 0, lastHitTime = os.clock() }
		return 1
	end
	return 1 + (data.hits * COMBO_BONUS)
end

local function registerComboHit(player)
	local data = comboData[player.UserId]
	if not data or os.clock() - data.lastHitTime > COMBO_TIMEOUT then
		data = { hits = 0, lastHitTime = os.clock() }
	end
	data.hits += 1
	data.lastHitTime = os.clock()
	comboData[player.UserId] = data
	return 1 + (data.hits * COMBO_BONUS)
end
```

## Health Regeneration

```lua
local REGEN_RATE = 2   -- [TUNING] HP per second
local REGEN_DELAY = 5  -- [TUNING] seconds after last damage before regen starts

local regenTracker = {} -- [playerId] = lastDamageTime

game:GetService("RunService").Heartbeat:Connect(function(dt)
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if not char then continue end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then continue end

		local lastDmg = regenTracker[player.UserId] or 0
		if os.clock() - lastDmg < REGEN_DELAY then continue end

		if hum.Health < hum.MaxHealth then
			hum.Health = math.min(hum.Health + REGEN_RATE * dt, hum.MaxHealth)
		end
	end
end)
```

## Status Effects

Debuff table per player, tick-based processing.

```lua
local statusEffects = {} -- [playerId] = { poison = {dmg, endTime}, slow = {factor, endTime}, stun = {endTime} }
local TICK_RATE = 1 -- [TUNING] seconds between debuff ticks

local function applyStatus(player, effectType, params)
	if not statusEffects[player.UserId] then
		statusEffects[player.UserId] = {}
	end
	local effects = statusEffects[player.UserId]
	if effectType == "poison" then
		effects.poison = { dmg = params.dmg, endTime = os.time() + params.duration } -- [TUNING]
	elseif effectType == "slow" then
		effects.slow = { factor = params.factor, endTime = os.time() + params.duration }
	elseif effectType == "stun" then
		effects.stun = { endTime = os.time() + params.duration }
	end
end

task.spawn(function()
	while true do
		task.wait(TICK_RATE)
		for _, player in ipairs(Players:GetPlayers()) do
			local effects = statusEffects[player.UserId]
			if not effects then continue end
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hum then continue end
			local now = os.time()

			if effects.poison and now < effects.poison.endTime then
				hum:TakeDamage(effects.poison.dmg)
			elseif effects.poison then
				effects.poison = nil
			end

			if effects.slow and now < effects.slow.endTime then
				hum.WalkSpeed = 16 * effects.slow.factor -- [TUNING] base walkspeed
			elseif effects.slow then
				hum.WalkSpeed = 16 -- [TUNING] reset to default
				effects.slow = nil
			end

			if effects.stun and now < effects.stun.endTime then
				hum.WalkSpeed = 0
			elseif effects.stun then
				hum.WalkSpeed = 16
				effects.stun = nil
			end
		end
	end
end)
```

## Anti-Exploit Checklist

| Check | Implementation |
|---|---|
| Max fire rate | Cooldown table per player (see above) |
| Max range | Reject raycast if `(origin - playerPos).Magnitude > weaponRange * 1.1` |
| Damage cap | Server calculates damage; never read from client |
| Hit verification | Server-side raycast from player's weapon origin, not client-supplied position |
| Rate limit attacks | Count attacks per second; kick if > threshold for 5+ seconds |

```lua
local MAX_ATTACKS_PER_SEC = 10 -- [TUNING]
local attackCounts = {}

local function checkAttackRate(player)
	local now = os.clock()
	local data = attackCounts[player.UserId] or { count = 0, window = now }
	if now - data.window > 1 then
		data.count = 0
		data.window = now
	end
	data.count += 1
	attackCounts[player.UserId] = data
	if data.count > MAX_ATTACKS_PER_SEC * 3 then -- sustained abuse
		player:Kick("Attack rate exceeded") -- [TUNING] threshold
	end
	return data.count <= MAX_ATTACKS_PER_SEC
end
```

## Full Working Example: Raycast Weapon Handler

```lua
-- MeleeWeaponHandler (ServerScript, ServerScriptService)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BASE_DAMAGE = 15        -- [TUNING]
local WEAPON_RANGE = 6        -- [TUNING]
local COOLDOWN = 0.4          -- [TUNING]
local COMBO_TIMEOUT = 1.5     -- [TUNING]
local COMBO_BONUS = 0.1       -- [TUNING]
local MAX_ATTACKS_SEC = 10    -- [TUNING]

local cooldowns = {}
local combos = {}
local rateLimits = {}

local AttackEvent = Instance.new("RemoteEvent")
AttackEvent.Name = "AttackEvent"
AttackEvent.Parent = game.ReplicatedStorage

local function isCoolingDown(player)
	local last = cooldowns[player.UserId] or 0
	if os.clock() - last < COOLDOWN then return true end
	cooldowns[player.UserId] = os.clock()
	return false
end

local function checkRate(player)
	local now = os.clock()
	local d = rateLimits[player.UserId] or { count = 0, t = now }
	if now - d.t > 1 then d = { count = 0, t = now } end
	d.count += 1
	rateLimits[player.UserId] = d
	return d.count <= MAX_ATTACKS_SEC
end

local function getCombo(player)
	local c = combos[player.UserId]
	if not c or os.clock() - c.last > COMBO_TIMEOUT then
		c = { hits = 0, last = 0 }
	end
	c.hits += 1
	c.last = os.clock()
	combos[player.UserId] = c
	return 1 + c.hits * COMBO_BONUS
end

local function swing(player)
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end

	local origin = root.Position
	local direction = root.CFrame.LookVector

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }

	local result = workspace:Raycast(origin, direction * WEAPON_RANGE, params)
	if not result then return end

	local part = result.Instance
	local model = part:FindFirstAncestorOfClass("Model")
	if not model or model == char then return end
	local targetHum = model:FindFirstChildOfClass("Humanoid")
	if not targetHum or targetHum.Health <= 0 then return end

	-- distance check
	if (origin - result.Position).Magnitude > WEAPON_RANGE * 1.2 then return end -- [TUNING] tolerance

	local multiplier = getCombo(player)
	local dmg = math.max(math.floor(BASE_DAMAGE * multiplier), 1)
	targetHum:TakeDamage(dmg)
end

AttackEvent.OnServerEvent:Connect(function(player, action)
	if action ~= "Swing" then return end
	if not checkRate(player) then return end
	if isCoolingDown(player) then return end
	swing(player)
end)
```

Module under 80 lines of core logic. Add weapon types by swapping `BASE_DAMAGE`, `WEAPON_RANGE`, and `COOLDOWN` from a weapon definition table.
