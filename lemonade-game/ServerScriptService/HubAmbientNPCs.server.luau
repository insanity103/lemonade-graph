--// HubAmbientNPCs  (non-interactive villagers that make the hub feel alive)
-- Each NPC walks between waypoints, idles for a bit, then walks to the next.
-- No ProximityPrompt, no gameplay interaction. Pure atmosphere.
local Workspace = game:GetService("Workspace")

local WorldLayout = require(script.Parent:WaitForChild("WorldLayout"))
if WorldLayout.BLANK_SLATE then return end
local hub = WorldLayout.HUB

local BASE = hub.Center

-- NPC definitions: name, color, waypoints (local offsets from hub center)
local NPC_DEFS = {
	{
		Name = "Wandering Villager",
		Color = Color3.fromRGB(140, 120, 100),
		ShirtColor = Color3.fromRGB(80, 60, 40),
		Waypoints = {
			Vector3.new(-5, 0, -5),
			Vector3.new(8, 0, -3),
			Vector3.new(3, 0, 8),
			Vector3.new(-8, 0, 5),
		},
		IdleTime = { 3, 6 },
		WalkSpeed = 6,
	},
	{
		Name = "Sitting Farmer",
		Color = Color3.fromRGB(120, 100, 80),
		ShirtColor = Color3.fromRGB(60, 80, 50),
		Waypoints = {
			Vector3.new(-12, 0, -10),
			Vector3.new(-12, 0, -10),
		},
		IdleTime = { 8, 15 },
		WalkSpeed = 0,
	},
	{
		Name = "Pacing Guard",
		Color = Color3.fromRGB(100, 100, 110),
		ShirtColor = Color3.fromRGB(50, 50, 60),
		Waypoints = {
			Vector3.new(15, 0, -12),
			Vector3.new(15, 0, 5),
			Vector3.new(10, 0, 5),
			Vector3.new(10, 0, -12),
		},
		IdleTime = { 1, 3 },
		WalkSpeed = 8,
	},
	{
		Name = "Blacksmith Apprentice",
		Color = Color3.fromRGB(160, 130, 100),
		ShirtColor = Color3.fromRGB(90, 50, 30),
		Waypoints = {
			Vector3.new(16, 0, -8),
			Vector3.new(18, 0, -6),
			Vector3.new(16, 0, -4),
		},
		IdleTime = { 4, 8 },
		WalkSpeed = 4,
	},
}

local function createBodyPart(name, size, parent, offset, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Anchored = false
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent

	local w = Instance.new("Motor6D")
	w.Name = name .. "Weld"
	w.Part0 = parent.PrimaryPart
	w.Part1 = p
	w.C0 = offset
	w.Parent = parent.PrimaryPart
	return p
end

local function spawnNPC(def)
	local model = Instance.new("Model")
	model.Name = def.Name

	-- HumanoidRootPart
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.Anchored = false
	hrp.Parent = model
	model.PrimaryPart = hrp

	-- Torso
	local torso = createBodyPart("Torso", Vector3.new(2, 2, 1), model,
		CFrame.new(0, 0, 0), def.ShirtColor)

	-- Head
	local head = createBodyPart("Head", Vector3.new(1.2, 1.2, 1.2), model,
		CFrame.new(0, 1.5, 0), def.Color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head

	-- Eyes (simple)
	for _, xOff in ipairs({ -0.2, 0.2 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.15, 0.15, 0.05)
		eye.Material = Enum.Material.Neon
		eye.Color = Color3.fromRGB(30, 30, 30)
		eye.Anchored = false
		eye.CanCollide = false
		eye.Parent = model
		local ew = Instance.new("Motor6D")
		ew.Part0 = head
		ew.Part1 = eye
		ew.C0 = CFrame.new(xOff, 0.1, -0.55)
		ew.Parent = head
	end

	-- Arms
	createBodyPart("Left Arm", Vector3.new(1, 2, 1), model,
		CFrame.new(-1.5, 0, 0), def.Color)
	createBodyPart("Right Arm", Vector3.new(1, 2, 1), model,
		CFrame.new(1.5, 0, 0), def.Color)

	-- Legs
	createBodyPart("Left Leg", Vector3.new(1, 2, 1), model,
		CFrame.new(-0.5, -2, 0), def.ShirtColor)
	createBodyPart("Right Leg", Vector3.new(1, 2, 1), model,
		CFrame.new(0.5, -2, 0), def.ShirtColor)

	-- Humanoid (for walking animation)
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = def.WalkSpeed
	humanoid.MaxHealth = 999999
	humanoid.Health = 999999
	humanoid.Parent = model

	model.Parent = Workspace

	-- NPC behavior loop
	local waypoints = def.Waypoints
	local currentIndex = 1

	task.spawn(function()
		-- Position at first waypoint
		local startPos = Vector3.new(BASE.X + waypoints[1].X, BASE.Y, BASE.Z + waypoints[1].Z)
		hrp.CFrame = CFrame.new(startPos)
		task.wait(1)

		while model.Parent do
			-- Idle phase
			local idleTime = math.random(def.IdleTime[1] * 10, def.IdleTime[2] * 10) / 10
			task.wait(idleTime)

			if not model.Parent then break end

			-- Move to next waypoint
			currentIndex = (currentIndex % #waypoints) + 1
			local target = Vector3.new(BASE.X + waypoints[currentIndex].X, BASE.Y, BASE.Z + waypoints[currentIndex].Z)

			if def.WalkSpeed > 0 then
				humanoid:MoveTo(target)
				local reached = humanoid.MoveToFinished:Wait(10)
				if not reached then
					-- Teleport if stuck
					hrp.CFrame = CFrame.new(target)
				end
			end
		end
	end)

	return model
end

-- Spawn all NPCs
for _, def in ipairs(NPC_DEFS) do
	spawnNPC(def)
end

print(string.format("[HubAmbientNPCs] %d ambient NPCs spawned in hub", #NPC_DEFS))
