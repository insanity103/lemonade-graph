-- LocalScript | StarterPlayerScripts.HubAmbience | Map project only. Cosmetic motion in the hub:
-- the Skill Trainer walks to a training dummy, swings a practice sword and returns; the rebirth
-- hologram turns and flickers; waystone splinters orbit their crystal. Everything here is
-- client-side CFrame animation of anchored parts, so nothing replicates or affects gameplay.
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
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

-- Walk a rig along a navmesh path so it goes round props and buildings instead of through them.
-- Falls back to a straight line only when no path exists. Returns the final root CFrame.
local pathParams = { AgentRadius = 2.5, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = 4 }
local function walkPath(model: Model, parts, from: CFrame, destination: Vector3, speed: number, sword: BasePart?): CFrame
	local path = PathfindingService:CreatePath(pathParams)
	local ok = pcall(function()
		path:ComputeAsync(from.Position - Vector3.new(0, 3, 0), destination - Vector3.new(0, 3, 0))
	end)
	local points = {}
	if ok and path.Status == Enum.PathStatus.Success then
		for i, waypoint in ipairs(path:GetWaypoints()) do
			if i > 1 then
				table.insert(points, waypoint.Position + Vector3.new(0, 3, 0))
			end
		end
	end
	if #points == 0 then
		points = { destination }
	end
	local here = from
	for _, target in ipairs(points) do
		local flat = Vector3.new(target.X, here.Position.Y, target.Z)
		if (flat - here.Position).Magnitude < 0.3 then continue end
		local facing = CFrame.lookAt(here.Position, flat)
		local duration = (flat - here.Position).Magnitude / speed
		local elapsed = 0
		while elapsed < duration do
			elapsed += RunService.Heartbeat:Wait()
			local alpha = math.min(elapsed / duration, 1)
			local root = CFrame.new(here.Position:Lerp(flat, alpha)) * facing.Rotation
			local swing = math.sin(elapsed * (speed * 0.9)) * 0.55
			pose(model, parts, root, swing, swing * 0.5, sword)
		end
		here = CFrame.new(flat) * facing.Rotation
	end
	pose(model, parts, here, 0, 0, sword)
	return here
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

		-- The server never moves him, so his respec prompt stays at the post: hide it while away.
		local prompt = model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
		if prompt then prompt.Enabled = false end
		local sword = makePracticeSword()
		sword.Parent = workspace.CurrentCamera
		local arrived = walkPath(model, parts, home, standAt, WALK_SPEED, sword)
		walk(model, parts, arrived, facing, sword)

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

		sword:Destroy()
		local back = walkPath(model, parts, facing, home.Position, WALK_SPEED, nil)
		walk(model, parts, back, home, nil)
		if prompt then prompt.Enabled = true end
	end
end
task.spawn(trainerRoutine)

-- ── Villagers ───────────────────────────────────────────────────────────────
-- Client-side wanderers built from the same block rig as the hub NPCs. They stroll between
-- spots around the village, pause, and occasionally say something. Nothing replicates.
local VILLAGER_COUNT = 5
local VILLAGER_SPEED = 7
local VILLAGER_SPOTS = { -- [TUNING] x, z on grass or paving, clear of props
	Vector3.new(-30, 0, -22), Vector3.new(-12, 0, -26), Vector3.new(22, 0, -20), Vector3.new(30, 0, 12),
	Vector3.new(18, 0, 30), Vector3.new(-18, 0, 30), Vector3.new(-44, 0, 40), Vector3.new(-30, 0, 58),
	Vector3.new(-16, 0, 60), Vector3.new(-56, 0, 14), Vector3.new(56, 0, 10), Vector3.new(-30, 0, -60),
	Vector3.new(30, 0, -60), Vector3.new(-6, 0, 24), Vector3.new(8, 0, -18),
}
local CHATTER = {
	"Fine weather for the market.", "The smith's been at it since dawn.", "Mind the road south, adventurer.",
	"Fresh pears, picked this morning!", "The waystones hum louder these days.", "Heard the Warlord's back in the quarry.",
	"Lovely evening by the fire.", "Someone's been at my apples.", "Rest a while, the benches are free.",
}
local OUTFITS = {
	{ Color3.fromRGB(150, 60, 60), Color3.fromRGB(70, 60, 50) }, { Color3.fromRGB(70, 110, 160), Color3.fromRGB(60, 50, 45) },
	{ Color3.fromRGB(90, 130, 80), Color3.fromRGB(80, 70, 60) }, { Color3.fromRGB(200, 170, 110), Color3.fromRGB(60, 60, 70) },
	{ Color3.fromRGB(130, 80, 150), Color3.fromRGB(50, 45, 40) }, { Color3.fromRGB(190, 120, 70), Color3.fromRGB(65, 55, 50) },
}
local SKIN = Color3.fromRGB(226, 190, 150)

local floorY = 10
do
	local grounds = map:FindFirstChild("Grounds_Hub")
	local floor = grounds and grounds:FindFirstChild("HubFloor")
	if floor then floorY = floor.Position.Y + floor.Size.Y / 2 end
end

local function makeVillager(index: number, outfit)
	local model = Instance.new("Model")
	model.Name = "Villager"
	local pieces = {
		{ "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), nil },
		{ "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), outfit[1] },
		{ "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0), SKIN },
		{ "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0), SKIN },
		{ "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0), SKIN },
		{ "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), outfit[2] },
		{ "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0), outfit[2] },
	}
	for _, spec in ipairs(pieces) do
		local part = Instance.new("Part")
		part.Name, part.Size = spec[1], spec[2]
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = spec[4] or SKIN
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if spec[1] == "HumanoidRootPart" then
			part.Transparency = 1
			model.PrimaryPart = part
		elseif spec[1] == "Head" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Head
			mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
			mesh.Parent = part
		end
		part.Parent = model
	end
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "Chatter"
	bubble.Size = UDim2.fromOffset(220, 30)
	bubble.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	bubble.MaxDistance = 45
	bubble.Enabled = false
	bubble.Parent = model.Head
	local text = Instance.new("TextLabel")
	text.BackgroundColor3 = Color3.fromRGB(24, 22, 20)
	text.BackgroundTransparency = 0.25
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.Gotham
	text.TextSize = 13
	text.TextColor3 = Color3.fromRGB(236, 230, 218)
	text.Text = ""
	text.Parent = bubble
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = text
	model.Parent = workspace.CurrentCamera
	return model, text, bubble
end

local function villagerRoutine(index: number)
	local rng = Random.new(index * 7919)
	local model, text, bubble = makeVillager(index, OUTFITS[(index - 1) % #OUTFITS + 1])
	local parts = rigParts(model)
	local spot = VILLAGER_SPOTS[rng:NextInteger(1, #VILLAGER_SPOTS)]
	local here = CFrame.new(spot.X, floorY + 3, spot.Z)
	pose(model, parts, here, 0, 0, nil)
	while model.Parent do
		task.wait(rng:NextNumber(2, 7))
		if rng:NextNumber() < 0.35 then
			text.Text = CHATTER[rng:NextInteger(1, #CHATTER)]
			bubble.Enabled = true
			task.wait(3)
			bubble.Enabled = false
		end
		local nextSpot = VILLAGER_SPOTS[rng:NextInteger(1, #VILLAGER_SPOTS)]
		if (nextSpot - spot).Magnitude < 4 then continue end
		here = walkPath(model, parts, here, Vector3.new(nextSpot.X, floorY + 3, nextSpot.Z), VILLAGER_SPEED, nil)
		spot = nextSpot
	end
end
for i = 1, VILLAGER_COUNT do
	task.spawn(villagerRoutine, i)
end

-- ── Blacksmith hammer ───────────────────────────────────────────────────────
local function smithRoutine(forge: Model)
	local head = forge:FindFirstChild("SmithHammerHead")
	local handle = forge:FindFirstChild("SmithHammerHandle")
	local anvilPos = Vector3.new(forge:GetAttribute("AnvilX") or 0, forge:GetAttribute("AnvilY") or 0, forge:GetAttribute("AnvilZ") or 0)
	local pivot = Vector3.new(forge:GetAttribute("HammerX") or 0, forge:GetAttribute("HammerY") or 0, forge:GetAttribute("HammerZ") or 0)
	if not (head and handle) then return end
	local rng = Random.new()
	local function place(angle: number)
		-- rotate the hammer about the hand pivot; handle points up from the hand, head at its end
		local frame = CFrame.new(pivot) * CFrame.Angles(angle, 0, 0)
		handle.CFrame = frame * CFrame.new(0, 1.3, 0)
		head.CFrame = frame * CFrame.new(0, 2.6, 0)
	end
	local function spark()
		for _ = 1, 4 do
			local bit = Instance.new("Part")
			bit.Size = Vector3.new(0.18, 0.18, 0.18)
			bit.Color = Color3.fromRGB(255, 200, 90)
			bit.Material = Enum.Material.Neon
			bit.Anchored, bit.CanCollide, bit.CanQuery, bit.CanTouch = true, false, false, false
			bit.Position = anvilPos
			bit.Parent = workspace.CurrentCamera
			local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.6, 1.4), rng:NextNumber(-1, 1)) * 5
			local t = 0
			task.spawn(function()
				while t < 0.45 do
					local dt = RunService.Heartbeat:Wait()
					t += dt
					bit.Position = anvilPos + dir * t - Vector3.new(0, 12 * t * t, 0)
					bit.Transparency = t / 0.45
				end
				bit:Destroy()
			end)
		end
	end
	while forge.Parent do
		task.wait(rng:NextNumber(4, 9))
		for _ = 1, rng:NextInteger(3, 5) do
			local t = 0
			local struck = false
			while t < 0.5 do
				t += RunService.Heartbeat:Wait()
				local phase = math.min(t / 0.5, 1)
				local angle
				if phase < 0.6 then
					angle = math.rad(-95) * (phase / 0.6) -- raise back
				else
					angle = math.rad(-95) + math.rad(115) * ((phase - 0.6) / 0.4)
					if not struck and phase > 0.95 then
						struck = true
						spark()
						AudioManager.PlaySFX("crit_hit", head)
					end
				end
				place(angle)
			end
			place(math.rad(20))
			task.wait(rng:NextNumber(0.25, 0.45))
		end
		place(0)
	end
end
for _, model in ipairs(map:GetDescendants()) do
	if model:IsA("Model") and model:GetAttribute("Forge") == true then
		task.spawn(smithRoutine, model)
	end
end

-- ── Butterflies, birds, waterfall ───────────────────────────────────────────
local flutters = {}
for _, model in ipairs(map:GetDescendants()) do
	if model:IsA("Model") and model:GetAttribute("FlowerBed") == true and #flutters < 12 and math.random() < 0.6 then
		local centre = Vector3.new(model:GetAttribute("BedX"), model:GetAttribute("BedY"), model:GetAttribute("BedZ"))
		local wing = Instance.new("Part")
		wing.Size = Vector3.new(0.9, 0.08, 0.6)
		wing.Color = ({ Color3.fromRGB(255, 190, 60), Color3.fromRGB(120, 170, 255), Color3.fromRGB(255, 255, 255) })[math.random(3)]
		wing.Material = Enum.Material.SmoothPlastic
		wing.Anchored, wing.CanCollide, wing.CanQuery, wing.CanTouch, wing.CastShadow = true, false, false, false, false
		wing.Parent = workspace.CurrentCamera
		table.insert(flutters, { part = wing, centre = centre, phase = math.random() * 6.28, radius = 2.5 + math.random() * 2 })
	end
end
local birds = {}
for k = 1, 3 do
	local body = Instance.new("Part")
	body.Size = Vector3.new(1.6, 0.25, 0.7)
	body.Color = Color3.fromRGB(40, 38, 42)
	body.Anchored, body.CanCollide, body.CanQuery, body.CanTouch, body.CastShadow = true, false, false, false, false
	body.Parent = workspace.CurrentCamera
	table.insert(birds, { part = body, phase = k * 2.1, radius = 24 + k * 6, height = floorY + 36 + k * 4 })
end
local sheets = {}
for _, model in ipairs(map:GetDescendants()) do
	if model:IsA("Model") and model:GetAttribute("Waterfall") == true then
		for _, sheet in ipairs(model:GetChildren()) do
			if sheet:IsA("BasePart") and string.match(sheet.Name, "^WaterSheet") then
				table.insert(sheets, { part = sheet, base = sheet.Transparency, phase = #sheets * 2.1 })
			end
		end
	end
end

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
	for _, f in ipairs(flutters) do
		local a = clock * 0.9 + f.phase
		local pos = f.centre + Vector3.new(math.cos(a) * f.radius, math.sin(clock * 5 + f.phase) * 0.5 + 0.8,
			math.sin(a * 1.3) * f.radius * 0.6)
		f.part.CFrame = CFrame.new(pos) * CFrame.Angles(0, -a, math.sin(clock * 22 + f.phase) * 0.9)
	end
	for _, b in ipairs(birds) do
		local a = clock * 0.25 + b.phase
		local pos = Vector3.new(math.cos(a) * b.radius, b.height + math.sin(clock * 0.7 + b.phase) * 2, math.sin(a) * b.radius)
		b.part.CFrame = CFrame.new(pos) * CFrame.Angles(0, -a - math.pi / 2, 0) * CFrame.Angles(0, 0, math.sin(clock * 9 + b.phase) * 0.5)
	end
	for _, w in ipairs(sheets) do
		w.part.Transparency = w.base + math.sin(clock * 3.1 + w.phase) * 0.08
	end
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
