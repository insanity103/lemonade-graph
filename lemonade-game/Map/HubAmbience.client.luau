-- LocalScript | StarterPlayerScripts.HubAmbience | Map project only. Cosmetic motion in the hub:
-- the Skill Trainer walks to a training dummy, swings a practice sword and returns; the rebirth
-- hologram turns and flickers; waystone splinters orbit their crystal. Everything here is
-- client-side CFrame animation of anchored parts, so nothing replicates or affects gameplay.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local map = workspace:WaitForChild("LemonadeMap", 20)
if not map then return end
local AudioManager = require(ReplicatedStorage:WaitForChild("AudioManager"))

-- ── Skill Trainer practice routine ─────────────────────────────────────────
local TRAINER_NAME = "Skill Trainer"
local WALK_SPEED = 9 -- [TUNING] studs per second, a relaxed stroll
local SWINGS_PER_VISIT = { 3, 5 } -- [TUNING] min, max
local REST_BETWEEN_VISITS = { 5, 11 } -- [TUNING] seconds idle at the post between visits
local SWING_TIME = 0.55
local STAND_OFF = 3.6 -- studs in front of a dummy

local function findDummies(): { Model }
	local list = {}
	for _, model in ipairs(map:GetDescendants()) do
		if model:IsA("Model") and model:GetAttribute("TrainingDummy") == true then
			table.insert(list, model)
		end
	end
	return list
end

-- The trainer is a GameplayActors rig: anchored R6-shaped parts pivoted at the HumanoidRootPart.
local function rigParts(model: Model)
	local parts = {}
	for _, name in ipairs({ "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
		parts[name] = model:FindFirstChild(name)
		if not parts[name] then return nil end
	end
	return parts
end

local OFFSETS = { Torso = Vector3.new(0, 0, 0), Head = Vector3.new(0, 1.5, 0) }

-- Pose every part from a root CFrame: legs swing about the hips, the right arm about the shoulder.
local function pose(model: Model, parts, root: CFrame, legSwing: number, armAngle: number, sword: BasePart?)
	model.PrimaryPart.CFrame = root
	parts.Torso.CFrame = root
	parts.Head.CFrame = root * CFrame.new(OFFSETS.Head)
	parts["Left Leg"].CFrame = root * CFrame.new(-0.5, -1, 0) * CFrame.Angles(legSwing, 0, 0) * CFrame.new(0, -1, 0)
	parts["Right Leg"].CFrame = root * CFrame.new(0.5, -1, 0) * CFrame.Angles(-legSwing, 0, 0) * CFrame.new(0, -1, 0)
	parts["Left Arm"].CFrame = root * CFrame.new(-1.5, 1, 0) * CFrame.Angles(-legSwing * 0.6, 0, 0) * CFrame.new(0, -1, 0)
	local rightArm = root * CFrame.new(1.5, 1, 0) * CFrame.Angles(armAngle, 0, 0) * CFrame.new(0, -1, 0)
	parts["Right Arm"].CFrame = rightArm
	if sword then
		sword.CFrame = rightArm * CFrame.new(0, -2.4, 0)
	end
end

local function makePracticeSword(): BasePart
	local blade = Instance.new("Part")
	blade.Name = "PracticeSword"
	blade.Size = Vector3.new(0.45, 3.8, 0.7)
	blade.Color = Color3.fromRGB(150, 110, 70)
	blade.Material = Enum.Material.Wood
	blade.Anchored, blade.CanCollide, blade.CanQuery, blade.CanTouch = true, false, false, false
	local guard = Instance.new("Part")
	guard.Size = Vector3.new(1.6, 0.3, 0.5)
	guard.Color = Color3.fromRGB(90, 60, 40)
	guard.Material = Enum.Material.Wood
	-- Unanchored so the weld carries it along with the (anchored, CFrame-driven) blade.
	guard.Anchored, guard.Massless = false, true
	guard.CanCollide, guard.CanQuery, guard.CanTouch = false, false, false
	guard.CFrame = blade.CFrame * CFrame.new(0, 1.3, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = blade, guard
	weld.Parent = blade
	guard.Parent = blade
	return blade
end

local function rockDummy(dummy: Model)
	local body = dummy:FindFirstChild("Body")
	local arms = dummy:FindFirstChild("Arms")
	for _, piece in ipairs({ body, arms }) do
		if piece then
			local home = piece.CFrame
			local hit = TweenService:Create(piece, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ CFrame = home * CFrame.Angles(0, 0, math.rad(9)) })
			hit.Completed:Once(function()
				TweenService:Create(piece, TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
					{ CFrame = home }):Play()
			end)
			hit:Play()
		end
	end
	if body then
		AudioManager.PlaySFX("enemy_hit", body)
	end
end

local function walk(model: Model, parts, from: CFrame, to: CFrame, sword: BasePart?)
	local distance = (to.Position - from.Position).Magnitude
	local duration = math.max(0.3, distance / WALK_SPEED)
	local elapsed = 0
	while elapsed < duration do
		elapsed += RunService.Heartbeat:Wait()
		local alpha = math.min(elapsed / duration, 1)
		local root = from:Lerp(to, alpha)
		local swing = math.sin(elapsed * 9) * 0.6
		pose(model, parts, root, swing, swing * 0.5, sword)
	end
	pose(model, parts, to, 0, 0, sword)
end

local function trainerRoutine()
	local model = workspace:WaitForChild(TRAINER_NAME, 30)
	if not model or not model:IsA("Model") or not model.PrimaryPart then return end
	local parts = rigParts(model)
	if not parts then return end
	local home = model.PrimaryPart.CFrame
	local rng = Random.new()
	while model.Parent do
		task.wait(rng:NextNumber(REST_BETWEEN_VISITS[1], REST_BETWEEN_VISITS[2]))
		local dummies = findDummies()
		if #dummies == 0 then continue end
		local dummy = dummies[rng:NextInteger(1, #dummies)]
		local body = dummy:FindFirstChild("Body")
		if not body then continue end

		-- Stand STAND_OFF studs from the dummy, on the side nearest home, facing it.
		local target = body.Position
		local away = (home.Position - target) * Vector3.new(1, 0, 1)
		away = if away.Magnitude > 0.01 then away.Unit else Vector3.new(0, 0, 1)
		local standAt = Vector3.new(target.X, home.Position.Y, target.Z) + away * STAND_OFF
		local facing = CFrame.lookAt(standAt, Vector3.new(target.X, standAt.Y, target.Z))
		local turnToward = CFrame.lookAt(home.Position, standAt)

		-- The server never moves him, so his respec prompt stays at the post: hide it while away.
		local prompt = model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
		if prompt then prompt.Enabled = false end
		local sword = makePracticeSword()
		sword.Parent = workspace.CurrentCamera
		walk(model, parts, home, turnToward, sword)
		walk(model, parts, turnToward, facing, sword)

		for _ = 1, rng:NextInteger(SWINGS_PER_VISIT[1], SWINGS_PER_VISIT[2]) do
			-- Raise, chop, recover: same shape as the enemies' telegraphed swing.
			local t = 0
			local landed = false
			while t < SWING_TIME do
				t += RunService.Heartbeat:Wait()
				local phase = t / SWING_TIME
				local angle
				if phase < 0.45 then
					angle = -math.rad(150) * (phase / 0.45)
				else
					angle = -math.rad(150) + math.rad(210) * ((phase - 0.45) / 0.55)
					if not landed and phase > 0.6 then
						landed = true
						rockDummy(dummy)
					end
				end
				pose(model, parts, facing, 0, angle, sword)
			end
			pose(model, parts, facing, 0, 0, sword)
			task.wait(rng:NextNumber(0.3, 0.7))
		end

		walk(model, parts, facing, CFrame.lookAt(standAt, home.Position), sword)
		walk(model, parts, CFrame.lookAt(standAt, home.Position), CFrame.lookAt(home.Position, home.Position + (home.Position - standAt)), sword)
		sword:Destroy()
		walk(model, parts, model.PrimaryPart.CFrame, home, nil)
		if prompt then prompt.Enabled = true end
	end
end
task.spawn(trainerRoutine)

-- ── Holograms and waystone splinters ────────────────────────────────────────
local spinners = {} -- { part, centre (Vector3), offset (Vector3 from centre), base (CFrame rotation), kind }

local function register(model: Model, attrX: string, attrY: string, attrZ: string, prefix: string, kind: string)
	local centre = Vector3.new(model:GetAttribute(attrX) or 0, model:GetAttribute(attrY) or 0, model:GetAttribute(attrZ) or 0)
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and string.sub(part.Name, 1, #prefix) == prefix then
			table.insert(spinners, {
				part = part, centre = centre, offset = part.Position - centre,
				rotation = part.CFrame.Rotation, kind = kind, baseTransparency = part.Transparency,
				phase = math.random() * math.pi * 2,
			})
		end
	end
end

for _, model in ipairs(map:GetDescendants()) do
	if model:IsA("Model") then
		if model:GetAttribute("Hologram") == true then
			register(model, "HoloX", "HoloAxisY", "HoloZ", "Holo", "hologram")
		elseif model:GetAttribute("Waystone") == true then
			register(model, "OrbitX", "OrbitY", "OrbitZ", "FloatShard", "shard")
		end
	end
end

local HOLO_SPIN = math.rad(28) -- per second
local SHARD_ORBIT = math.rad(14)
local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	for _, s in ipairs(spinners) do
		if s.kind == "hologram" then
			local bob = math.sin(clock * 1.3) * 0.35
			local spin = CFrame.Angles(0, clock * HOLO_SPIN, 0)
			local ringName = string.match(s.part.Name, "^HoloRing(%d)")
			local offset = s.offset
			if ringName then
				-- scan rings slide up the image and wrap
				local travel = (clock * 2.2 + tonumber(ringName) * 3) % 9 - 4.5
				offset = Vector3.new(0, travel, 0)
			end
			s.part.CFrame = CFrame.new(s.centre + Vector3.new(0, bob, 0)) * spin * CFrame.new(offset) * s.rotation
			-- flicker: mostly steady, occasional brief dips
			local flicker = math.max(0, math.sin(clock * 17 + s.phase) - 0.92) * 6
			s.part.Transparency = math.clamp(s.baseTransparency + flicker, 0, 1)
		else
			local orbit = CFrame.Angles(0, clock * SHARD_ORBIT + s.phase, 0)
			local bob = math.sin(clock * 0.9 + s.phase) * 0.5
			s.part.CFrame = CFrame.new(s.centre + Vector3.new(0, bob, 0)) * orbit * CFrame.new(s.offset)
				* s.rotation * CFrame.Angles(0, clock * 0.8, 0)
		end
	end
end)
