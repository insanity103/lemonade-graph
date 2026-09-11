--// WorldLayout
-- Builds a deliberately authored RPG landscape from source. The main trail,
-- terrain silhouette, arena approaches, landmarks, and prop clusters are fixed
-- compositions; only small terrain undulations use deterministic noise.
local Workspace = game:GetService("Workspace")

local WorldLayout = {}

WorldLayout.VERSION = 3
WorldLayout.HUB = {
	Center = Vector3.new(0, 2, -178),
	SpawnPosition = Vector3.new(-8, 3.3, -181),
	MerchantPosition = Vector3.new(13, 2.8, -172),
}

-- A readable S-curve replaces the old hub-and-spoke layout. Each arena sits
-- beside the road so the player sees its landmark before reaching its gate.
WorldLayout.ROUTE = {
	{ Position = Vector3.new(0, 2, -178), Material = Enum.Material.Cobblestone, Level = 0 },
	{ Position = Vector3.new(-15, 3, -160), Material = Enum.Material.Cobblestone, Level = 0 },
	{ Position = Vector3.new(-31, 4, -143), Material = Enum.Material.Ground, Level = 1 },
	{ Position = Vector3.new(-45, 4, -130), Material = Enum.Material.Ground, Level = 1 },
	{ Position = Vector3.new(-75, 6, -145), Material = Enum.Material.Ground, Level = 1 },
	{ Position = Vector3.new(-108, 9, -122), Material = Enum.Material.Rock, Level = 10 },
	{ Position = Vector3.new(-122, 11, -88), Material = Enum.Material.Snow, Level = 15 },
	{ Position = Vector3.new(-111, 12, -57), Material = Enum.Material.Snow, Level = 15 },
	{ Position = Vector3.new(-139, 14, -72), Material = Enum.Material.Snow, Level = 15 },
	{ Position = Vector3.new(-174, 16, -54), Material = Enum.Material.Snow, Level = 15 },
	{ Position = Vector3.new(-185, 17, -15), Material = Enum.Material.Rock, Level = 22 },
	{ Position = Vector3.new(-171, 19, 20), Material = Enum.Material.Basalt, Level = 30 },
	{ Position = Vector3.new(-132, 20, 42), Material = Enum.Material.Basalt, Level = 30 },
	{ Position = Vector3.new(-106, 21, 40), Material = Enum.Material.Basalt, Level = 30 },
	{ Position = Vector3.new(-79, 24, 57), Material = Enum.Material.Rock, Level = 40 },
	{ Position = Vector3.new(-61, 27, 83), Material = Enum.Material.Slate, Level = 50 },
	{ Position = Vector3.new(-43, 29, 101), Material = Enum.Material.Slate, Level = 50 },
	{ Position = Vector3.new(-27, 30, 108), Material = Enum.Material.Slate, Level = 50 },
	{ Position = Vector3.new(-3, 33, 88), Material = Enum.Material.Slate, Level = 58 },
	{ Position = Vector3.new(26, 36, 73), Material = Enum.Material.Sandstone, Level = 68 },
	{ Position = Vector3.new(55, 39, 80), Material = Enum.Material.Sandstone, Level = 75 },
	{ Position = Vector3.new(78, 40, 91), Material = Enum.Material.Marble, Level = 75 },
}

WorldLayout.ZONES = {
	{
		Name = "IronLowlands", DisplayName = "Iron Lowlands", RequiredLevel = 1,
		Center = Vector3.new(-72, 5, -104), Approach = Vector3.new(-45, 4, -130),
		TerrainMaterial = Enum.Material.Ground, FloorMaterial = Enum.Material.Slate,
		Color = Color3.fromRGB(117, 75, 67), Accent = Color3.fromRGB(205, 103, 78), Style = "Woodland",
		Landforms = {
			{ Vector3.new(-48, 7, 30), 35 }, { Vector3.new(45, 4, 33), 32 },
			{ Vector3.new(-55, 2, -25), 28 },
		},
		Trees = {
			Vector3.new(-48, 0, -12), Vector3.new(-55, 0, 18), Vector3.new(-41, 0, 36),
			Vector3.new(43, 0, 18), Vector3.new(52, 0, 37), Vector3.new(55, 0, -16),
		},
		Rocks = { Vector3.new(-46, 0, -32), Vector3.new(47, 0, 2), Vector3.new(20, 0, 48) },
		Spawns = {
			{ "Boss_Gorgon", Vector3.new(0, 0, 10), 10 },
			{ "IronSquire", Vector3.new(-15, 0, -7), 6 }, { "IronSquire", Vector3.new(15, 0, -7), 7 },
			{ "IronBerserker", Vector3.new(-14, 0, 17), 8 }, { "IronBerserker", Vector3.new(14, 0, 17), 8 },
		},
	},
	{
		Name = "FrostboundGlacier", DisplayName = "Frostbound Glacier", RequiredLevel = 15,
		Center = Vector3.new(-138, 14, -22), Approach = Vector3.new(-111, 12, -57),
		TerrainMaterial = Enum.Material.Snow, FloorMaterial = Enum.Material.Ice,
		Color = Color3.fromRGB(126, 176, 207), Accent = Color3.fromRGB(199, 239, 255), Style = "FrostPine",
		Landforms = {
			{ Vector3.new(-45, 14, 30), 38 }, { Vector3.new(42, 9, 34), 35 },
			{ Vector3.new(-48, 5, -27), 30 },
		},
		Trees = {
			Vector3.new(-48, 0, -10), Vector3.new(-54, 0, 21), Vector3.new(-38, 0, 42),
			Vector3.new(44, 0, 17), Vector3.new(54, 0, 36), Vector3.new(51, 0, -17),
		},
		Rocks = { Vector3.new(-43, 0, -35), Vector3.new(46, 0, -4), Vector3.new(18, 0, 49) },
		Spawns = {
			{ "Boss_FrostRevenant", Vector3.new(0, 0, 10), 25 },
			{ "FrostImp", Vector3.new(-15, 0, -7), 18 }, { "FrostImp", Vector3.new(15, 0, -7), 19 },
			{ "GlacialGargoyle", Vector3.new(-14, 0, 17), 21 }, { "GlacialGargoyle", Vector3.new(14, 0, 17), 22 },
		},
	},
	{
		Name = "InfernalCaldera", DisplayName = "Infernal Caldera", RequiredLevel = 30,
		Center = Vector3.new(-125, 23, 78), Approach = Vector3.new(-106, 21, 40),
		TerrainMaterial = Enum.Material.Basalt, FloorMaterial = Enum.Material.CrackedLava,
		Color = Color3.fromRGB(91, 48, 37), Accent = Color3.fromRGB(255, 112, 35), Style = "Infernal",
		Landforms = {
			{ Vector3.new(-46, 18, 28), 40 }, { Vector3.new(44, 12, 35), 36 },
			{ Vector3.new(-50, 7, -25), 31 },
		},
		Trees = {
			Vector3.new(-49, 0, -8), Vector3.new(-53, 0, 24),
			Vector3.new(47, 0, 19), Vector3.new(53, 0, 38),
		},
		Rocks = {
			Vector3.new(-44, 0, -34), Vector3.new(45, 0, -7),
			Vector3.new(-26, 0, 48), Vector3.new(24, 0, 50),
		},
		Spawns = {
			{ "Boss_InfernalColossus", Vector3.new(0, 0, 10), 45 },
			{ "CinderFiend", Vector3.new(-15, 0, -7), 34 }, { "CinderFiend", Vector3.new(15, 0, -7), 35 },
			{ "MagmaJuggernaut", Vector3.new(-14, 0, 17), 38 }, { "MagmaJuggernaut", Vector3.new(14, 0, 17), 40 },
		},
	},
	{
		Name = "VoidRift", DisplayName = "Void Rift", RequiredLevel = 50,
		Center = Vector3.new(10, 32, 132), Approach = Vector3.new(-27, 30, 108),
		TerrainMaterial = Enum.Material.Slate, FloorMaterial = Enum.Material.Basalt,
		Color = Color3.fromRGB(55, 38, 79), Accent = Color3.fromRGB(175, 77, 255), Style = "Void",
		Landforms = {
			{ Vector3.new(-45, 15, 31), 38 }, { Vector3.new(45, 11, 29), 35 },
			{ Vector3.new(50, 6, -25), 30 },
		},
		Trees = {
			Vector3.new(-49, 0, -7), Vector3.new(-52, 0, 25), Vector3.new(45, 0, 17),
			Vector3.new(51, 0, 39), Vector3.new(48, 0, -21),
		},
		Rocks = { Vector3.new(-43, 0, -34), Vector3.new(43, 0, -4), Vector3.new(-20, 0, 49) },
		Spawns = {
			{ "Boss_VoidWraith", Vector3.new(0, 0, 10), 70 },
			{ "VoidShade", Vector3.new(-15, 0, -7), 55 }, { "VoidShade", Vector3.new(15, 0, -7), 58 },
			{ "AbyssTormentor", Vector3.new(-14, 0, 17), 62 }, { "AbyssTormentor", Vector3.new(14, 0, 17), 64 },
		},
	},
	{
		Name = "CelestialSummit", DisplayName = "Celestial Summit", RequiredLevel = 75,
		Center = Vector3.new(121, 43, 70), Approach = Vector3.new(78, 40, 91),
		TerrainMaterial = Enum.Material.Sandstone, FloorMaterial = Enum.Material.Marble,
		Color = Color3.fromRGB(194, 164, 105), Accent = Color3.fromRGB(255, 230, 126), Style = "Celestial",
		Landforms = {
			{ Vector3.new(-44, 13, 35), 37 }, { Vector3.new(42, 18, 28), 41 },
			{ Vector3.new(49, 8, -25), 32 },
		},
		Trees = {
			Vector3.new(-48, 0, 2), Vector3.new(-50, 0, 31),
			Vector3.new(45, 0, 17), Vector3.new(52, 0, 39),
		},
		Rocks = { Vector3.new(-41, 0, -34), Vector3.new(43, 0, -5), Vector3.new(-17, 0, 49) },
		Spawns = {
			{ "Boss_CelestialTitan", Vector3.new(0, 0, 10), 100 },
			{ "AstralWisp", Vector3.new(-15, 0, -7), 80 }, { "AstralWisp", Vector3.new(15, 0, -7), 82 },
			{ "SolarDominator", Vector3.new(-14, 0, 17), 88 }, { "SolarDominator", Vector3.new(14, 0, 17), 90 },
		},
	},
}

local ARENA_SIZE = 68
local ARENA_HALF = ARENA_SIZE / 2
local DOOR_WIDTH = 14
local built = false

local function createPart(parent, name, size, cframe, material, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Material = material
	part.Color = color
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function arenaCFrame(zone)
	local target = Vector3.new(zone.Approach.X, zone.Center.Y, zone.Approach.Z)
	return CFrame.lookAt(zone.Center, target)
end

local function restoreBaseplate()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if not baseplate or not baseplate:IsA("BasePart") then
		if baseplate then baseplate:Destroy() end
		baseplate = Instance.new("Part")
		baseplate.Name = "Baseplate"
		baseplate.Parent = Workspace
	end
	baseplate.Size = Vector3.new(512, 20, 512)
	baseplate.CFrame = CFrame.new(0, -10, 0)
	baseplate.Anchored = true
	baseplate.CanCollide = true
	baseplate.CanTouch = true
	baseplate.CanQuery = true
	baseplate.Transparency = 0
	baseplate.Reflectance = 0
	baseplate.Material = Enum.Material.Plastic
	baseplate.BrickColor = BrickColor.new("Medium stone grey")
	baseplate.TopSurface = Enum.SurfaceType.Studs
	baseplate.BottomSurface = Enum.SurfaceType.Inlet
	return baseplate
end

local function fillTerrainMound(terrain, surfacePosition, radius, material)
	terrain:FillBall(surfacePosition - Vector3.new(0, radius, 0), radius, material)
end

local function buildTerrain()
	local terrain = Workspace.Terrain
	terrain:Clear()
	terrain.WaterColor = Color3.fromRGB(24, 95, 116)
	terrain.WaterTransparency = 0.35
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8

	-- Offset overlapping mounds give the hub a meadow silhouette while preserving
	-- a predictable center for spawning, menus, and merchant interactions.
	for _, mound in ipairs({
		{ Vector3.new(0, 2, -178), 52 }, { Vector3.new(-31, 1, -169), 38 },
		{ Vector3.new(29, 1, -163), 35 },
	}) do
		fillTerrainMound(terrain, mound[1], mound[2], Enum.Material.Grass)
	end

	-- A continuous land ribbon follows the authored road. Mild deterministic
	-- variation keeps the shoulders organic without moving gameplay landmarks.
	for index = 1, #WorldLayout.ROUTE - 1 do
		local fromNode = WorldLayout.ROUTE[index]
		local toNode = WorldLayout.ROUTE[index + 1]
		local distance = (toNode.Position - fromNode.Position).Magnitude
		local samples = math.max(2, math.ceil(distance / 12))
		for sample = 0, samples do
			local alpha = sample / samples
			local surface = fromNode.Position:Lerp(toNode.Position, alpha)
			local noise = math.noise(index * 0.71, sample * 0.37) * 2.5
			local radius = 29 + noise
			local material = alpha < 0.55 and fromNode.Material or toNode.Material
			fillTerrainMound(terrain, surface + Vector3.new(0, noise * 0.25, 0), radius, material)
		end
	end

	for _, zone in ipairs(WorldLayout.ZONES) do
		-- The combat clearing remains reliable, while overlapping shoulders hide
		-- its corners and connect it to asymmetric landmark ridges.
		terrain:FillBlock(CFrame.new(zone.Center.X, zone.Center.Y - 9, zone.Center.Z),
			Vector3.new(72, 18, 72), zone.TerrainMaterial)
		for _, offset in ipairs({
			Vector3.new(-28, 0, -24), Vector3.new(27, 1, -20),
			Vector3.new(-24, 0, 27), Vector3.new(26, 1, 25),
		}) do
			fillTerrainMound(terrain, zone.Center + offset, 47, zone.TerrainMaterial)
		end
		local frame = arenaCFrame(zone)
		for _, landform in ipairs(zone.Landforms) do
			fillTerrainMound(terrain, frame:PointToWorldSpace(landform[1]), landform[2], zone.TerrainMaterial)
		end
	end
	return terrain
end

local terrainRaycastParams = RaycastParams.new()
terrainRaycastParams.FilterType = Enum.RaycastFilterType.Include
terrainRaycastParams.FilterDescendantsInstances = { Workspace.Terrain }
terrainRaycastParams.IgnoreWater = true

local function terrainSurfaceAt(position)
	local origin = Vector3.new(position.X, position.Y + 120, position.Z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -240, 0), terrainRaycastParams)
	if result then
		return Vector3.new(position.X, result.Position.Y, position.Z)
	end
	return position
end

local function buildTrailSegment(parent, fromNode, toNode, index, namePrefix)
	local from = fromNode.Position + Vector3.new(0, 0.5, 0)
	local to = toNode.Position + Vector3.new(0, 0.5, 0)
	local midpoint = (from + to) / 2
	local material = toNode.Material
	if material == Enum.Material.Snow or material == Enum.Material.CrackedLava then
		material = Enum.Material.Rock
	end
	local road = createPart(parent, string.format("%s%02d", namePrefix, index),
		Vector3.new(index % 3 == 0 and 12 or 10, 1, (to - from).Magnitude + 0.5),
		CFrame.lookAt(midpoint, to), material, Color3.fromRGB(105, 96, 84))
	road:SetAttribute("FromLevel", fromNode.Level)
	road:SetAttribute("ToLevel", toNode.Level)
	return road
end

local function buildRoads(parent)
	for index = 1, #WorldLayout.ROUTE - 1 do
		buildTrailSegment(parent, WorldLayout.ROUTE[index], WorldLayout.ROUTE[index + 1], index, "Trail")
	end
	for index, zone in ipairs(WorldLayout.ZONES) do
		local frame = arenaCFrame(zone)
		local entrance = frame:PointToWorldSpace(Vector3.new(0, 0, -ARENA_HALF - 1))
		buildTrailSegment(parent, {
			Position = zone.Approach, Material = zone.TerrainMaterial, Level = zone.RequiredLevel,
		}, {
			Position = entrance, Material = zone.FloorMaterial, Level = zone.RequiredLevel,
		}, index, "ArenaSpur")
	end
end

local function addZoneMarker(parent, zone, frame)
	local markerPosition = frame:PointToWorldSpace(Vector3.new(0, 5, -ARENA_HALF - 8))
	local marker = createPart(parent, "ZoneMarker", Vector3.new(1, 1, 1), CFrame.new(markerPosition),
		Enum.Material.SmoothPlastic, zone.Accent)
	marker.Transparency = 1
	marker.CanCollide = false
	marker.CanTouch = false

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(280, 60)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 150
	billboard.Parent = marker

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.2
	label.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = zone.Accent
	label.TextStrokeTransparency = 0.5
	label.Text = string.format("%s  •  LEVEL %d+", string.upper(zone.DisplayName), zone.RequiredLevel)
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function buildBossRoom(parent, zone)
	local model = Instance.new("Model")
	model.Name = zone.Name
	model:SetAttribute("DisplayName", zone.DisplayName)
	local frame = arenaCFrame(zone)
	local floor = createPart(model, "Floor", Vector3.new(1, ARENA_SIZE, ARENA_SIZE),
		frame * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), zone.FloorMaterial, zone.Color)
	floor.Shape = Enum.PartType.Cylinder
	model.PrimaryPart = floor

	local ruinColor = zone.Color:Lerp(Color3.new(0, 0, 0), 0.24)
	local ringRadius = ARENA_HALF - 1
	local pillarPositions = {}
	for pillarIndex, angleDegrees in ipairs({ -120, -90, -60, -30, 0, 30, 60, 90, 120 }) do
		local angle = math.rad(angleDegrees)
		local localPosition = Vector3.new(math.sin(angle) * ringRadius, 0, math.cos(angle) * ringRadius)
		pillarPositions[pillarIndex] = frame:PointToWorldSpace(localPosition)
		local height = 10 + (pillarIndex % 3) * 2
		createPart(model, "RuinPillar" .. pillarIndex, Vector3.new(4, height, 4),
			CFrame.new(pillarPositions[pillarIndex] + Vector3.new(0, height / 2, 0)), Enum.Material.Rock, ruinColor)
	end
	for wallIndex = 1, #pillarPositions - 1 do
		local from = pillarPositions[wallIndex]
		local to = pillarPositions[wallIndex + 1]
		local midpoint = (from + to) / 2 + Vector3.new(0, 2.5, 0)
		createPart(model, "LowRuinWall" .. wallIndex, Vector3.new(3, 5, (to - from).Magnitude),
			CFrame.lookAt(midpoint, to + Vector3.new(0, 2.5, 0)), Enum.Material.Rock, ruinColor)
	end

	local gateY = 9
	local gateZ = -ARENA_HALF
	for _, side in ipairs({ -1, 1 }) do
		createPart(model, side < 0 and "GatePostLeft" or "GatePostRight", Vector3.new(4, 18, 4),
			frame * CFrame.new(side * (DOOR_WIDTH / 2 + 2), gateY, gateZ), Enum.Material.Rock, ruinColor)
	end
	createPart(model, "GateLintel", Vector3.new(DOOR_WIDTH + 8, 4, 4),
		frame * CFrame.new(0, 16, gateZ), Enum.Material.Rock, ruinColor)
	local door = createPart(model, "Door", Vector3.new(DOOR_WIDTH, 14, 1.5),
		frame * CFrame.new(0, 7, gateZ), Enum.Material.ForceField, zone.Accent)
	door.Transparency = 0.3
	door:SetAttribute("RequiredLevel", zone.RequiredLevel)

	local bounds = createPart(model, "Bounds", Vector3.new(ARENA_SIZE - 6, 22, ARENA_SIZE - 6),
		frame * CFrame.new(0, 11, 0), Enum.Material.SmoothPlastic, zone.Color)
	bounds.Transparency = 1
	bounds.CanCollide = false
	bounds.CanTouch = false
	local exit = createPart(model, "Exit", Vector3.new(4, 1, 4),
		frame * CFrame.new(0, 0.5, -ARENA_HALF - 9), Enum.Material.SmoothPlastic, zone.Accent)
	exit.Transparency = 1
	exit.CanCollide = false
	exit.CanTouch = false

	for brazierIndex, x in ipairs({ -13, 13 }) do
		local flame = createPart(model, "GateLight" .. brazierIndex, Vector3.new(2, 2, 2),
			frame * CFrame.new(x, 5, gateZ - 1), Enum.Material.Neon, zone.Accent)
		flame.Shape = Enum.PartType.Ball
		flame.CanCollide = false
	end
	addZoneMarker(model, zone, frame)
	model.Parent = parent
end

local function buildTree(parent, name, position, zone, variant)
	local model = Instance.new("Model")
	model.Name = name
	local height = 10 + (variant % 3) * 2
	local trunkColor = zone.Style == "Infernal" and Color3.fromRGB(58, 42, 37) or Color3.fromRGB(91, 63, 43)
	local trunk = createPart(model, "Trunk", Vector3.new(2.2, height, 2.2),
		CFrame.new(position + Vector3.new(0, height / 2, 0)), Enum.Material.Wood, trunkColor)
	model.PrimaryPart = trunk
	if zone.Style == "Infernal" then
		for branchIndex, side in ipairs({ -1, 1 }) do
			createPart(model, "Branch" .. branchIndex, Vector3.new(1.2, 6, 1.2),
				CFrame.new(position + Vector3.new(side * 2, height - 1, 0)) * CFrame.Angles(0, 0, math.rad(side * 42)),
				Enum.Material.Wood, trunkColor)
		end
	else
		local canopyColor = zone.Accent:Lerp(zone.Color, zone.Style == "FrostPine" and 0.2 or 0.45)
		local canopyMaterial = zone.Style == "FrostPine" and Enum.Material.Snow or Enum.Material.Grass
		for canopyIndex, canopy in ipairs({
			{ Vector3.new(0, height + 1, 0), Vector3.new(8, 7, 8) },
			{ Vector3.new(-2.5, height - 0.5, 1), Vector3.new(6, 6, 6) },
			{ Vector3.new(2.3, height, -1.2), Vector3.new(6.5, 6.5, 6.5) },
		}) do
			local crown = createPart(model, "Canopy" .. canopyIndex, canopy[2],
				CFrame.new(position + canopy[1]), canopyMaterial, canopyColor)
			crown.Shape = Enum.PartType.Ball
			crown.CanCollide = false
		end
	end
	model.Parent = parent
end

local function buildBoulder(parent, name, position, zone, variant)
	local model = Instance.new("Model")
	model.Name = name
	for rockIndex, offset in ipairs({
		Vector3.new(0, 2.7, 0), Vector3.new(2.8, 1.8, 1.2), Vector3.new(-2.2, 1.5, -1.5),
	}) do
		local scale = 1 + ((variant + rockIndex) % 3) * 0.09
		local rock = createPart(model, "Rock" .. rockIndex, Vector3.new(6.5, 5, 6) * scale,
			CFrame.new(position + offset) * CFrame.Angles(math.rad(rockIndex * 7), math.rad(variant * 19), math.rad(rockIndex * 11)),
			zone.FloorMaterial, zone.Color:Lerp(Color3.new(0, 0, 0), 0.2))
		rock.Shape = Enum.PartType.Ball
		if rockIndex == 1 then model.PrimaryPart = rock end
	end
	model.Parent = parent
end

local function buildCrystal(parent, name, position, color, scale)
	local model = Instance.new("Model")
	model.Name = name
	for index, data in ipairs({
		{ Vector3.new(0, 5, 0), Vector3.new(3, 10, 3), 0 },
		{ Vector3.new(-3, 3, 1), Vector3.new(2, 7, 2), -18 },
		{ Vector3.new(3, 2.7, -1), Vector3.new(2, 6, 2), 20 },
	}) do
		local crystal = createPart(model, "Shard" .. index, data[2] * scale,
			CFrame.new(position + data[1] * scale) * CFrame.Angles(0, 0, math.rad(data[3])), Enum.Material.Neon, color)
		crystal.CanCollide = index == 1
		if index == 1 then model.PrimaryPart = crystal end
	end
	model.Parent = parent
end

local function buildColumn(parent, name, position, zone, height)
	local model = Instance.new("Model")
	model.Name = name
	local column = createPart(model, "Column", Vector3.new(height, 4, 4),
		CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Enum.Material.Marble, zone.Color:Lerp(Color3.new(1, 1, 1), 0.22))
	column.Shape = Enum.PartType.Cylinder
	model.PrimaryPart = column
	createPart(model, "Base", Vector3.new(7, 2, 7), CFrame.new(position + Vector3.new(0, 1, 0)),
		Enum.Material.Marble, zone.Color)
	model.Parent = parent
end

local function buildLandmark(parent, zone)
	local frame = arenaCFrame(zone)
	local rear = terrainSurfaceAt(frame:PointToWorldSpace(Vector3.new(0, 0, ARENA_HALF + 18)))
	local model = Instance.new("Model")
	model.Name = zone.Name .. "Landmark"
	model.Parent = parent
	if zone.Style == "Woodland" then
		for index, x in ipairs({ -7, 7 }) do
			createPart(model, "WatchPost" .. index, Vector3.new(4, 24, 4),
				CFrame.new(rear + Vector3.new(x, 12, 0)), Enum.Material.WoodPlanks, zone.Color)
		end
		createPart(model, "WatchBeam", Vector3.new(20, 4, 6), CFrame.new(rear + Vector3.new(0, 22, 0)),
			Enum.Material.WoodPlanks, zone.Accent)
	elseif zone.Style == "FrostPine" then
		buildCrystal(model, "GlacierSpire", rear, zone.Accent, 2.2)
		buildCrystal(model, "GlacierSpireLeft", rear + Vector3.new(-13, 0, 5), zone.Color, 1.4)
	elseif zone.Style == "Infernal" then
		for index, x in ipairs({ -10, 10 }) do
			local height = 29 - index * 3
			createPart(model, "BasaltFang" .. index, Vector3.new(7, height, 7),
				CFrame.new(rear + Vector3.new(x, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(x / 2)),
				Enum.Material.Basalt, zone.Color)
		end
		local heart = createPart(model, "LavaHeart", Vector3.new(7, 7, 7),
			CFrame.new(rear + Vector3.new(0, 18, 1)), Enum.Material.Neon, zone.Accent)
		heart.Shape = Enum.PartType.Ball
	elseif zone.Style == "Void" then
		buildCrystal(model, "RiftObelisk", rear, zone.Accent, 2.7)
		for index, x in ipairs({ -13, 13 }) do
			local mote = createPart(model, "FloatingMote" .. index, Vector3.new(4, 4, 4),
				CFrame.new(rear + Vector3.new(x, 18 + index * 4, 0)), Enum.Material.Neon, zone.Accent)
			mote.Shape = Enum.PartType.Ball
			mote.CanCollide = false
		end
	else
		buildColumn(model, "SummitColumnLeft", rear + Vector3.new(-12, 0, 0), zone, 25)
		buildColumn(model, "SummitColumnRight", rear + Vector3.new(12, 0, 0), zone, 21)
		local beacon = createPart(model, "SunBeacon", Vector3.new(8, 8, 8),
			CFrame.new(rear + Vector3.new(0, 29, 0)), Enum.Material.Neon, zone.Accent)
		beacon.Shape = Enum.PartType.Ball
		beacon.CanCollide = false
	end
end

local function rebuildDecor()
	for _, name in ipairs({ "Trees", "Boulders", "Landmarks" }) do
		local existing = Workspace:FindFirstChild(name)
		if existing then existing:Destroy() end
	end
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = Workspace
	local boulders = Instance.new("Folder")
	boulders.Name = "Boulders"
	boulders.Parent = Workspace
	local landmarks = Instance.new("Folder")
	landmarks.Name = "Landmarks"
	landmarks.Parent = Workspace

	for zoneIndex, zone in ipairs(WorldLayout.ZONES) do
		local frame = arenaCFrame(zone)
		for variant, localPosition in ipairs(zone.Trees) do
			local worldPosition = terrainSurfaceAt(frame:PointToWorldSpace(localPosition))
			if zone.Style == "Void" then
				buildCrystal(trees, string.format("%sCrystal%d", zone.Name, variant),
					worldPosition, zone.Accent, 0.7 + variant * 0.04)
			elseif zone.Style == "Celestial" then
				buildColumn(trees, string.format("%sRuin%d", zone.Name, variant),
					worldPosition, zone, 8 + (variant % 3) * 3)
			else
				buildTree(trees, string.format("%sTree%d", zone.Name, variant), worldPosition, zone, variant)
			end
		end
		for variant, localPosition in ipairs(zone.Rocks) do
			buildBoulder(boulders, string.format("%sBoulder%d", zone.Name, variant),
				terrainSurfaceAt(frame:PointToWorldSpace(localPosition)), zone, zoneIndex + variant)
		end
		buildLandmark(landmarks, zone)
	end
end

local function resetSpawn()
	local spawn = Workspace:FindFirstChild("SpawnLocation")
	if not spawn or not spawn:IsA("SpawnLocation") then
		if spawn then spawn:Destroy() end
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "SpawnLocation"
		spawn.Parent = Workspace
	end
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(WorldLayout.HUB.SpawnPosition)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Enabled = true
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(255, 226, 112)
	spawn.Transparency = 0.15
end

local function relocateLoosePlacedPart(generated)
	local loose = Workspace:FindFirstChild("Part")
	if not loose or not loose:IsA("BasePart") then return end
	loose.Name = "PlacedItem"
	loose.Anchored = true
	loose.CFrame = CFrame.new(Vector3.new(-18, WorldLayout.HUB.MerchantPosition.Y + loose.Size.Y / 2, -169))
	loose.Parent = generated
end

function WorldLayout.GetEnemySpawns()
	local configs = {}
	for _, zone in ipairs(WorldLayout.ZONES) do
		local frame = arenaCFrame(zone)
		for _, entry in ipairs(zone.Spawns) do
			configs[#configs + 1] = {
				archetype = entry[1], position = frame:PointToWorldSpace(entry[2]), level = entry[3],
			}
		end
	end
	return configs
end

function WorldLayout.EnsureBuilt()
	if built then return end
	Workspace:SetAttribute("WorldReady", false)
	restoreBaseplate()
	buildTerrain()

	local previousGenerated = Workspace:FindFirstChild("WorldGenerated")
	if previousGenerated then previousGenerated:Destroy() end
	local generated = Instance.new("Folder")
	generated.Name = "WorldGenerated"
	generated.Parent = Workspace

	local previousRooms = Workspace:FindFirstChild("BossRooms")
	if previousRooms then previousRooms:Destroy() end
	local rooms = Instance.new("Folder")
	rooms.Name = "BossRooms"
	rooms.Parent = Workspace

	local roads = Instance.new("Folder")
	roads.Name = "Causeways"
	roads.Parent = generated
	buildRoads(roads)
	for _, zone in ipairs(WorldLayout.ZONES) do buildBossRoom(rooms, zone) end

	local plaza = createPart(generated, "HubPlaza", Vector3.new(1, 52, 52),
		CFrame.new(WorldLayout.HUB.Center + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Enum.Material.Cobblestone, Color3.fromRGB(127, 119, 103))
	plaza.Shape = Enum.PartType.Cylinder
	plaza.CanCollide = true

	resetSpawn()
	relocateLoosePlacedPart(generated)
	rebuildDecor()
	built = true
	Workspace:SetAttribute("WorldLayoutVersion", WorldLayout.VERSION)
	Workspace:SetAttribute("WorldReady", true)
end

return WorldLayout
