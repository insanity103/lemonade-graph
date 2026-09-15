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
-- The Hub model streams in atomically; wait for it so every scan below sees the whole village.
local hub = map:WaitForChild("Hub", 60)
if not hub then
	warn("[HubAmbience] Hub model never streamed in; ambience idle")
	return
end
local AudioManager = require(ReplicatedStorage:WaitForChild("AudioManager"))
local NpcOutfits = require(ReplicatedStorage:WaitForChild("NpcOutfits"))

-- ── Skill Trainer practice routine ─────────────────────────────────────────
local TRAINER_NAME = "Skill Trainer"
local WALK_SPEED = 9 -- [TUNING] studs per second, a relaxed stroll
local SWINGS_PER_VISIT = { 3, 5 } -- [TUNING] min, max
local REST_BETWEEN_VISITS = { 4, 9 } -- [TUNING] seconds idle at the post between visits
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
		-- grip in the hand (arm bottom), blade continuing along the arm's -Y
		sword.CFrame = rightArm * CFrame.new(0, -1.0, 0) * CFrame.new(0, -2.0, 0)
	end
end

-- The trainer's sword: steel blade, crossguard and wrapped grip, CFrame-driven from the hand.
-- The blade is the anchored root; the other pieces are welded so they follow it. Local +Y is
-- the tip; the grip is at the top so the blade continues past the hand.
local function makePracticeSword(): BasePart
	local blade = Instance.new("Part")
	blade.Name = "TrainerSword"
	blade.Size = Vector3.new(0.3, 3.6, 0.8)
	blade.Color = Color3.fromRGB(196, 200, 206)
	blade.Material = Enum.Material.Metal
	blade.Anchored, blade.CanCollide, blade.CanQuery, blade.CanTouch = true, false, false, false
	local function piece(name, size, color, material, offset)
		local p = Instance.new("Part")
		p.Name, p.Size, p.Color = name, size, color
		p.Material = Enum.Material[material]
		p.Anchored, p.Massless = false, true
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		p.CFrame = blade.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = blade, p
		weld.Parent = p
		p.Parent = blade
	end
	piece("Fuller", Vector3.new(0.32, 2.6, 0.2), Color3.fromRGB(150, 154, 162), "Metal", CFrame.new(0, -0.2, 0))
	piece("Guard", Vector3.new(0.5, 0.3, 1.9), Color3.fromRGB(204, 168, 72), "Metal", CFrame.new(0, 1.85, 0))
	piece("Grip", Vector3.new(0.34, 1.1, 0.34), Color3.fromRGB(84, 52, 36), "Fabric", CFrame.new(0, 2.55, 0))
	piece("Pommel", Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(204, 168, 72), "Metal", CFrame.new(0, 3.2, 0))
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
	return to
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
	local model = workspace:WaitForChild(TRAINER_NAME, 60)
	if not model or not model:IsA("Model") or not model.PrimaryPart then
		warn("[HubAmbience] Skill Trainer rig not found; practice routine idle")
		return
	end
	local parts = rigParts(model)
	if not parts then
		warn("[HubAmbience] Skill Trainer rig is missing body parts; practice routine idle")
		return
	end
	local backSword = model:FindFirstChild("BackSword")
	local backGuard = model:FindFirstChild("BackSwordGuard")
	print("[HubAmbience] Skill Trainer practice routine running")
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
		-- Draw the sword from his back.
		if backSword then backSword.Transparency = 1 end
		if backGuard then backGuard.Transparency = 1 end
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
		if backSword then backSword.Transparency = 0 end
		if backGuard then backGuard.Transparency = 0 end
		local back = walkPath(model, parts, facing, home.Position, WALK_SPEED, nil)
		walk(model, parts, back, home, nil)
		if prompt then prompt.Enabled = true end
	end
end
task.spawn(function()
	local ok, err = pcall(trainerRoutine)
	if not ok then warn("[HubAmbience] trainer routine stopped: " .. tostring(err)) end
end)

-- ── Villagers ───────────────────────────────────────────────────────────────
-- Client-side wanderers built from the same block rig as the hub NPCs. Each owns one of the
-- houses (models with the House attribute): they stroll between spots, chat, and now and then
-- go home, opening and closing their door. Nothing replicates.
local VILLAGER_COUNT = 4
local HOME_STAY = { 20, 45 } -- [TUNING] seconds indoors
local TRIPS_BEFORE_HOME = { 2, 4 }
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
local VILLAGER_OUTFITS = { "Farmer", "Baker", "Gatherer", "Elder" } -- NpcOutfits names, one per villager
local SKIN = Color3.fromRGB(226, 190, 150)

local floorY = 10
do
	local grounds = map:FindFirstChild("Grounds_Hub")
	local floor = grounds and grounds:FindFirstChild("HubFloor")
	if floor then floorY = floor.Position.Y + floor.Size.Y / 2 end
end

local function makeVillager(index: number, outfit: string)
	local model = Instance.new("Model")
	model.Name = "Villager"
	local pieces = {
		{ "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), nil },
		{ "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), SKIN },
		{ "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0), SKIN },
		{ "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0), SKIN },
		{ "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0), SKIN },
		{ "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), SKIN },
		{ "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0), SKIN },
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
	NpcOutfits.apply(model, outfit)
	return model, text, bubble
end

local houses = {}
for _, model in ipairs(map:GetDescendants()) do
	if model:IsA("Model") and model:GetAttribute("House") == true then
		table.insert(houses, model)
	end
end
table.sort(houses, function(a, b) return a.Name < b.Name end)

-- Swing a house door (and its bands and handle) about its hinge edge. Client-side only; the
-- door's collision never changes, so players cannot slip inside while it stands open.
local function doorSwing(house: Model, open: boolean)
	local door = house:FindFirstChild("Door")
	if not door then return end
	if not door:GetAttribute("ClosedCFrame") then
		door:SetAttribute("ClosedCFrame", door.CFrame)
		for _, piece in ipairs({ house:FindFirstChild("DoorBand0"), house:FindFirstChild("DoorBand1"), house:FindFirstChild("DoorHandle") }) do
			if piece then piece:SetAttribute("ClosedCFrame", piece.CFrame) end
		end
	end
	local closed = door:GetAttribute("ClosedCFrame")
	local alongX = door.Size.X > door.Size.Z
	local hinge = closed * CFrame.new(if alongX then -door.Size.X / 2 else 0, 0, if alongX then 0 else -door.Size.Z / 2)
	local pieces = { door, house:FindFirstChild("DoorBand0"), house:FindFirstChild("DoorBand1"), house:FindFirstChild("DoorHandle") }
	local t = 0
	while t < 0.6 do
		t += RunService.Heartbeat:Wait()
		local alpha = math.min(t / 0.6, 1)
		alpha = alpha * alpha * (3 - 2 * alpha)
		local angle = math.rad(105) * (if open then alpha else 1 - alpha)
		local swing = CFrame.new(hinge.Position) * CFrame.Angles(0, angle, 0) * CFrame.new(-hinge.Position)
		for _, piece in ipairs(pieces) do
			local base = piece and piece:GetAttribute("ClosedCFrame")
			if base then piece.CFrame = swing * base end
		end
	end
end

-- Players can open doors too: a local prompt swings the door and lifts its collision for this
-- client only; it closes itself after a while.
local DOOR_AUTO_CLOSE = 8
for _, house in ipairs(houses) do
	local door = house:FindFirstChild("Door")
	if not door then continue end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DoorPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Door"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = door
	local open, busy, closeToken = false, false, 0
	local function setOpen(state: boolean)
		if busy or open == state then return end
		busy = true
		open = state
		prompt.ActionText = if state then "Close" else "Open"
		door.CanCollide = not state
		doorSwing(house, state)
		busy = false
	end
	prompt.Triggered:Connect(function()
		setOpen(not open)
		closeToken += 1
		local token = closeToken
		if open then
			task.delay(DOOR_AUTO_CLOSE, function()
				if token == closeToken and open then setOpen(false) end
			end)
		end
	end)
end

local function villagerRoutine(index: number)
	local rng = Random.new(index * 7919)
	local model, text, bubble = makeVillager(index, VILLAGER_OUTFITS[(index - 1) % #VILLAGER_OUTFITS + 1])
	local parts = rigParts(model)
	local house = houses[((index - 1) % math.max(#houses, 1)) + 1]
	local doorstep, inside, doorway, floor
	if house then
		floor = (house:GetAttribute("FloorY") or floorY) + 3
		doorstep = Vector3.new(house:GetAttribute("OutsideX"), floorY + 3, house:GetAttribute("OutsideZ"))
		doorway = Vector3.new(house:GetAttribute("DoorX"), floor, house:GetAttribute("DoorZ"))
		inside = Vector3.new(house:GetAttribute("InsideX"), floor, house:GetAttribute("InsideZ"))
	end
	local atHome = house ~= nil and index % 2 == 0 -- half start indoors
	local spot = VILLAGER_SPOTS[rng:NextInteger(1, #VILLAGER_SPOTS)]
	local here = if atHome then CFrame.lookAt(inside, doorway) else CFrame.new(spot.X, floorY + 3, spot.Z)
	pose(model, parts, here, 0, 0, nil)

	local function goHome()
		here = walkPath(model, parts, here, doorstep, VILLAGER_SPEED, nil)
		doorSwing(house, true)
		here = walk(model, parts, here, CFrame.lookAt(doorstep, doorway), nil) or CFrame.lookAt(doorstep, doorway)
		local step = CFrame.lookAt(doorway, inside)
		walk(model, parts, here, CFrame.new(doorway) * step.Rotation, nil)
		walk(model, parts, CFrame.new(doorway) * step.Rotation, CFrame.new(inside) * step.Rotation, nil)
		here = CFrame.lookAt(inside, doorway)
		pose(model, parts, here, 0, 0, nil)
		doorSwing(house, false)
		task.wait(rng:NextNumber(HOME_STAY[1], HOME_STAY[2]))
		doorSwing(house, true)
		local out = CFrame.lookAt(doorway, doorstep)
		walk(model, parts, here, CFrame.new(inside) * out.Rotation, nil)
		walk(model, parts, CFrame.new(inside) * out.Rotation, CFrame.new(doorway) * out.Rotation, nil)
		walk(model, parts, CFrame.new(doorway) * out.Rotation, CFrame.new(doorstep) * out.Rotation, nil)
		here = CFrame.new(doorstep) * out.Rotation
		doorSwing(house, false)
	end

	while model.Parent do
		if atHome then
			task.wait(rng:NextNumber(HOME_STAY[1], HOME_STAY[2]))
			doorSwing(house, true)
			local out = CFrame.lookAt(doorway, doorstep)
			walk(model, parts, here, CFrame.new(inside) * out.Rotation, nil)
			walk(model, parts, CFrame.new(inside) * out.Rotation, CFrame.new(doorway) * out.Rotation, nil)
			walk(model, parts, CFrame.new(doorway) * out.Rotation, CFrame.new(doorstep) * out.Rotation, nil)
			here = CFrame.new(doorstep) * out.Rotation
			doorSwing(house, false)
			atHome = false
		end
		for _ = 1, rng:NextInteger(TRIPS_BEFORE_HOME[1], TRIPS_BEFORE_HOME[2]) do
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
		if house then
			goHome()
		end
	end
end
for i = 1, VILLAGER_COUNT do
	task.spawn(function()
		local ok, err = pcall(villagerRoutine, i)
		if not ok then warn("[HubAmbience] villager " .. i .. " stopped: " .. tostring(err)) end
	end)
end

-- ── Blacksmith hammer ───────────────────────────────────────────────────────
-- The Relic Blacksmith leaves his counter between customers, walks to the anvil and hammers
-- the workpiece (his hammer accessory is welded to his right arm, so the swing carries it).
local function smithRoutine(forge: Model)
	local anvilPos = Vector3.new(forge:GetAttribute("AnvilX") or 0, forge:GetAttribute("AnvilY") or 0, forge:GetAttribute("AnvilZ") or 0)
	local stand = Vector3.new(forge:GetAttribute("AnvilStandX") or 0, (forge:GetAttribute("AnvilStandY") or floorY) + 3,
		forge:GetAttribute("AnvilStandZ") or 0)
	local model = workspace:WaitForChild("RelicMerchantNPC", 60)
	if not model or not model:IsA("Model") or not model.PrimaryPart then
		warn("[HubAmbience] Relic Blacksmith rig not found; forge idle")
		return
	end
	local parts = rigParts(model)
	if not parts then return end
	local home = model.PrimaryPart.CFrame
	local prompt = model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
	local rng = Random.new()
	local function spark()
		for _ = 1, 5 do
			local bit = Instance.new("Part")
			bit.Size = Vector3.new(0.18, 0.18, 0.18)
			bit.Color = Color3.fromRGB(255, 200, 90)
			bit.Material = Enum.Material.Neon
			bit.Anchored, bit.CanCollide, bit.CanQuery, bit.CanTouch = true, false, false, false
			bit.Position = anvilPos
			bit.Parent = workspace.CurrentCamera
			local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.6, 1.4), rng:NextNumber(-1, 1)) * 5
			task.spawn(function()
				local t = 0
				while t < 0.45 do
					t += RunService.Heartbeat:Wait()
					bit.Position = anvilPos + dir * t - Vector3.new(0, 12 * t * t, 0)
					bit.Transparency = t / 0.45
				end
				bit:Destroy()
			end)
		end
	end
	print("[HubAmbience] Relic Blacksmith forge routine running")
	while model.Parent do
		task.wait(rng:NextNumber(8, 16))
		if prompt then prompt.Enabled = false end
		local arrived = walkPath(model, parts, home, stand, WALK_SPEED, nil)
		local facing = CFrame.lookAt(stand, Vector3.new(anvilPos.X, stand.Y, anvilPos.Z))
		walk(model, parts, arrived, facing, nil)
		for _ = 1, rng:NextInteger(4, 7) do
			local t, struck = 0, false
			while t < 0.5 do
				t += RunService.Heartbeat:Wait()
				local phase = math.min(t / 0.5, 1)
				local angle
				if phase < 0.55 then
					angle = -math.rad(140) * (phase / 0.55)
				else
					angle = -math.rad(140) + math.rad(175) * ((phase - 0.55) / 0.45)
					if not struck and phase > 0.92 then
						struck = true
						spark()
						AudioManager.PlaySFX("crit_hit", parts["Right Arm"])
					end
				end
				pose(model, parts, facing, 0, angle, nil)
			end
			pose(model, parts, facing, 0, math.rad(20), nil)
			task.wait(rng:NextNumber(0.25, 0.5))
		end
		pose(model, parts, facing, 0, 0, nil)
		task.wait(0.6)
		local back = walkPath(model, parts, facing, home.Position, WALK_SPEED, nil)
		walk(model, parts, back, home, nil)
		if prompt then prompt.Enabled = true end
	end
end
for _, model in ipairs(map:GetDescendants()) do
	if model:IsA("Model") and model:GetAttribute("Forge") == true then
		task.spawn(function()
			local ok, err = pcall(smithRoutine, model)
			if not ok then warn("[HubAmbience] smith routine stopped: " .. tostring(err)) end
		end)
	end
end

-- ── Butterflies, birds, waterfall ───────────────────────────────────────────
-- Butterflies roam the whole village: each picks a destination (usually a flower bed, sometimes
-- anywhere on the green), flies there on a wavering line, lingers, then picks another.
local BUTTERFLY_COUNT = 4
local BUTTERFLY_SPEED = { 4, 7 }
local HUB_ROAM = 84
local beds = {}
for _, model in ipairs(map:GetDescendants()) do
	if model:IsA("Model") and model:GetAttribute("FlowerBed") == true then
		table.insert(beds, Vector3.new(model:GetAttribute("BedX"), model:GetAttribute("BedY"), model:GetAttribute("BedZ")))
	end
end
-- Tree canopies are the other favourite; butterflies flit round their edges.
local canopies = {}
for _, model in ipairs(map:GetDescendants()) do
	if model:IsA("Model") and string.match(model.Name, "^Tree") then
		local canopy = model:FindFirstChild("Canopy")
		if canopy then table.insert(canopies, { pos = canopy.Position, radius = canopy.Size.X / 2 }) end
	end
end
-- A point on the green: off the roads (|x| or |z| under 10) and outside the paved plaza.
local function grassPoint(): Vector3
	for _ = 1, 12 do
		local a, r = math.random() * math.pi * 2, 30 + math.sqrt(math.random()) * (HUB_ROAM - 30)
		local x, z = math.cos(a) * r, math.sin(a) * r
		if math.abs(x) > 12 and math.abs(z) > 12 then
			return Vector3.new(x, floorY + 1.5 + math.random() * 2.5, z)
		end
	end
	return Vector3.new(-40, floorY + 2, -40)
end
local WING_COLORS = { Color3.fromRGB(255, 190, 60), Color3.fromRGB(120, 170, 255), Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 120, 150), Color3.fromRGB(180, 220, 90) }
local flutters = {}
local function newButterfly(k: number)
	local body = Instance.new("Part")
	body.Size = Vector3.new(0.18, 0.18, 0.55)
	body.Color = Color3.fromRGB(40, 36, 40)
	body.Anchored, body.CanCollide, body.CanQuery, body.CanTouch, body.CastShadow = true, false, false, false, false
	body.Parent = workspace.CurrentCamera
	local wings = {}
	for side = -1, 1, 2 do
		local wing = Instance.new("Part")
		wing.Size = Vector3.new(0.6, 0.05, 0.5)
		wing.Color = WING_COLORS[(k % #WING_COLORS) + 1]
		wing.Material = Enum.Material.SmoothPlastic
		wing.Anchored, wing.CanCollide, wing.CanQuery, wing.CanTouch, wing.CastShadow = true, false, false, false, false
		wing.Parent = workspace.CurrentCamera
		table.insert(wings, { part = wing, side = side })
	end
	local start = if #beds > 0 then beds[(k % #beds) + 1] else Vector3.new(0, floorY + 3, 0)
	return { body = body, wings = wings, pos = start + Vector3.new(0, 1, 0), target = start, phase = k * 1.7,
		speed = BUTTERFLY_SPEED[1] + math.random() * (BUTTERFLY_SPEED[2] - BUTTERFLY_SPEED[1]), linger = 0 }
end
local function pickButterflyTarget(f)
	local roll = math.random()
	if #beds > 0 and roll < 0.45 then
		local bed = beds[math.random(#beds)]
		f.target = bed + Vector3.new((math.random() - 0.5) * 3, 0.4 + math.random() * 1.2, (math.random() - 0.5) * 3)
		f.linger = 1.5 + math.random() * 3
	elseif #canopies > 0 and roll < 0.75 then
		local tree = canopies[math.random(#canopies)]
		local a = math.random() * math.pi * 2
		local d = tree.radius + 0.5 + math.random() * 2
		f.target = tree.pos + Vector3.new(math.cos(a) * d, (math.random() - 0.3) * tree.radius, math.sin(a) * d)
		f.linger = 0.5 + math.random() * 2
	else
		f.target = grassPoint()
		f.linger = if math.random() < 0.5 then 1 + math.random() * 2 else 0
	end
end
for k = 1, BUTTERFLY_COUNT do
	local f = newButterfly(k)
	pickButterflyTarget(f)
	table.insert(flutters, f)
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
		local toTarget = f.target - f.pos
		if toTarget.Magnitude < 1.2 then
			if f.linger > 0 then
				f.linger -= dt
				-- hover in place with a small drift
				f.pos += Vector3.new(math.sin(clock * 3 + f.phase), math.sin(clock * 5 + f.phase) * 0.6,
					math.cos(clock * 2.6 + f.phase)) * dt * 0.8
			else
				pickButterflyTarget(f)
			end
		else
			-- wavering flight: forward plus a sideways/vertical wobble
			local forward = toTarget.Unit
			local sideways = Vector3.new(-forward.Z, 0, forward.X)
			local wobble = sideways * math.sin(clock * 2.4 + f.phase) * 1.6 + Vector3.new(0, math.sin(clock * 4.1 + f.phase) * 1.1, 0)
			f.pos += (forward * f.speed + wobble) * dt
		end
		local look = toTarget.Magnitude > 0.5 and toTarget.Unit or Vector3.new(1, 0, 0)
		local frame = CFrame.lookAt(f.pos, f.pos + Vector3.new(look.X, 0, look.Z))
		f.body.CFrame = frame
		local flap = math.sin(clock * 24 + f.phase) * 1.1
		for _, w in ipairs(f.wings) do
			w.part.CFrame = frame * CFrame.Angles(0, 0, flap * w.side) * CFrame.new(w.side * 0.36, 0, 0)
		end
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
