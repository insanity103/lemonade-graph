--// WorldLayout
-- The map's shape is owned by the Blender side (assets/map_redesign, GPT-6 Astra) and
-- reaches gameplay through MapAnchors -- the generated anchor contract. This module is
-- the gameplay adapter for that contract: zone metadata, spawn resolution, level gates.
--
-- Three modes, chosen at runtime:
--   BlankSlate -- the current design reset: clears all terrain and imported visuals,
--                then leaves only a clean plastic baseplate and spawn.
--   Imported -- Workspace.FivefoldSanctuary exists with a matching MapRedesignVersion.
--               The imported meshes own every visual; this module places no geometry
--               and only resolves gameplay anchors.
--   Fallback -- the imported map is absent (pre-import, or a fresh Rojo sync into an
--               empty place). The procedural builder below recreates a playable world
--               at the SAME anchor positions, so spawns, gates and quests line up
--               either way and nothing 404s while the art is still in Blender.
--
-- Anchors are the single source of truth. Never hand-copy positions into this file:
-- regenerate assets/map_redesign and re-copy MapAnchors.luau instead.
local Workspace = game:GetService("Workspace")

local MapAnchors = require(script.Parent:WaitForChild("MapAnchors"))

local WorldLayout = {}

WorldLayout.VERSION = 7
WorldLayout.MAP_MODEL_NAME = "FivefoldSanctuary"
WorldLayout.ANCHOR_VERSION = MapAnchors.Version
-- [DESIGN] Keep the place as a clean level-design starting point until a new map is authored.
WorldLayout.BLANK_SLATE = true

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

local function hexColor(hex, fallback)
	if typeof(hex) ~= "string" then return fallback end
	local r, g, b = string.match(hex, "^#?(%x%x)(%x%x)(%x%x)$")
	if not r then return fallback end
	return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end

-- Decor is code-owned (the framework's split: Blender ships geometry, code ships the
-- fallback dressing). Keyed by the Style the anchor contract assigns each zone, so a
-- new zone inherits a coherent look without another hand-authored table.
local STYLE_PRESETS = {
	Woodland   = { terrain = Enum.Material.Ground,     floor = Enum.Material.Slate,       color = Color3.fromRGB(117, 75, 67),   accent = Color3.fromRGB(205, 103, 78) },
	Briar      = { terrain = Enum.Material.LeafyGrass, floor = Enum.Material.Pebble,      color = Color3.fromRGB(74, 98, 52),    accent = Color3.fromRGB(170, 220, 90) },
	FrostPine  = { terrain = Enum.Material.Snow,       floor = Enum.Material.Ice,         color = Color3.fromRGB(126, 176, 207), accent = Color3.fromRGB(199, 239, 255) },
	Marsh      = { terrain = Enum.Material.Mud,        floor = Enum.Material.Slate,       color = Color3.fromRGB(70, 86, 70),    accent = Color3.fromRGB(120, 210, 170),
		pools = { { Vector3.new(-50, -2, 4), Vector3.new(22, 4, 34) }, { Vector3.new(48, -2, 8), Vector3.new(20, 4, 28) }, { Vector3.new(0, -2, 52), Vector3.new(40, 4, 16) } } },
	Infernal   = { terrain = Enum.Material.Basalt,     floor = Enum.Material.CrackedLava, color = Color3.fromRGB(91, 48, 37),    accent = Color3.fromRGB(255, 112, 35) },
	Storm      = { terrain = Enum.Material.Rock,       floor = Enum.Material.Granite,     color = Color3.fromRGB(84, 92, 110),   accent = Color3.fromRGB(130, 190, 255) },
	Void       = { terrain = Enum.Material.Slate,      floor = Enum.Material.Basalt,      color = Color3.fromRGB(55, 38, 79),    accent = Color3.fromRGB(175, 77, 255) },
	Celestial  = { terrain = Enum.Material.Sandstone,  floor = Enum.Material.Marble,      color = Color3.fromRGB(194, 164, 105), accent = Color3.fromRGB(255, 230, 126) },
}
local DEFAULT_STYLE = STYLE_PRESETS.Woodland

-- Shared fallback dressing, in arena-local studs. Every arena is the same 68-stud
-- circle, so one composition reads correctly in all of them.
local DECOR_LANDFORMS = { { Vector3.new(-46, 10, 30), 36 }, { Vector3.new(45, 6, 32), 33 }, { Vector3.new(-50, 3, -25), 29 } }
local DECOR_TREES = {
	Vector3.new(-48, 0, -12), Vector3.new(-55, 0, 18), Vector3.new(-41, 0, 36),
	Vector3.new(43, 0, 18), Vector3.new(52, 0, 37), Vector3.new(55, 0, -16),
}
local DECOR_ROCKS = { Vector3.new(-46, 0, -32), Vector3.new(47, 0, 2), Vector3.new(20, 0, 48) }

WorldLayout.HUB = {
	Center = v3(MapAnchors.Hub.Center),
	Radius = MapAnchors.Hub.Radius,
	SafeRadius = MapAnchors.Hub.SafeRadius,
	SpawnPosition = v3(MapAnchors.Hub.SpawnPosition),
	MerchantPosition = v3(MapAnchors.Hub.MerchantPosition),
	QuestGiverPosition = v3(MapAnchors.Hub.QuestGiverPosition),
	RebirthPosition = v3(MapAnchors.Hub.RebirthPosition),
}

-- Hub feature positions (offsets from HUB.Center, used by Hub* scripts)
WorldLayout.HUB_FEATURES = {
	Campfire       = Vector3.new(45, 0, 20),    -- south-east of spawn
	Leaderboard    = Vector3.new(-35, 0, -25),  -- north-west of spawn
	RespecShrine   = Vector3.new(-20, 0, 40),   -- south of spawn
	-- Ambient NPCs wander around the hub using their own waypoint tables
}

-- Five independent branches radiate from the sanctuary at 72-degree spacing. The
-- anchor contract is explicit that these must never be concatenated into one
-- polyline: joining them would draw roads across open water and through unrelated
-- territory. Each is its own road, walked out and back.
WorldLayout.BRANCHES = {}
for _, branch in ipairs(MapAnchors.Branches) do
	local waypoints = {}
	local color = hexColor(branch.Color, DEFAULT_STYLE.color)
	for index, point in ipairs(branch.Waypoints) do
		-- Material grades from worked stone near the hub to the region's own ground.
		waypoints[index] = {
			Position = v3(point),
			Material = index <= 2 and Enum.Material.Cobblestone or Enum.Material.Ground,
			Level = branch.RequiredLevel,
		}
	end
	WorldLayout.BRANCHES[#WorldLayout.BRANCHES + 1] = {
		Id = branch.Id,
		DisplayName = branch.DisplayName,
		AngleDegrees = branch.AngleDegrees,
		RequiredLevel = branch.RequiredLevel,
		Waypoints = waypoints,
		Width = branch.Width,
		GroundY = branch.GroundY,
		Color = color,
		Accent = hexColor(branch.Accent, DEFAULT_STYLE.accent),
		Landmark = v3(branch.Landmark),
		CombatEntry = v3(branch.CombatEntry),
		ReturnAnchor = v3(branch.ReturnAnchor),
		TerritoryCenter = v3(branch.EnemyTerritory.Center),
		TerritorySize = v3(branch.EnemyTerritory.Size),
		MainArena = branch.MainArena,
		SecondaryArena = branch.SecondaryArena,
	}
end

-- All eight zone identifiers survive the redesign: five main arenas plus three
-- secondary pockets folded into their parent region. Quest objectives and
-- SwordDropSystem key off these names, so they are contract, not cosmetics.
WorldLayout.ZONES = {}
for _, zone in ipairs(MapAnchors.Zones) do
	local style = STYLE_PRESETS[zone.Style] or DEFAULT_STYLE
	local spawns, elite = {}, nil
	for _, spawn in ipairs(zone.Spawns) do
		-- Absolute Position is authoritative (the generator already applied the arena
		-- frame); LocalPosition is kept so the fallback builder can dress around it.
		local entry = {
			spawn.Archetype, v3(spawn.LocalPosition), spawn.Level,
			Position = v3(spawn.Position), Role = spawn.Role,
		}
		if spawn.Role == "elite" then
			elite = entry
		else
			spawns[#spawns + 1] = entry
		end
	end
	WorldLayout.ZONES[#WorldLayout.ZONES + 1] = {
		Name = zone.Name,
		DisplayName = zone.DisplayName,
		Region = zone.Region,
		RequiredLevel = zone.RequiredLevel,
		Center = v3(zone.Center),
		Approach = v3(zone.Approach),
		DoorPosition = v3(zone.Door),
		DoorSize = v3(zone.DoorSize),
		ExitPosition = v3(zone.Exit),
		BoundsCenter = v3(zone.BoundsCenter),
		BoundsSize = v3(zone.BoundsSize),
		FloorDiameter = zone.FloorDiameter,
		Style = zone.Style,
		TerrainMaterial = style.terrain,
		FloorMaterial = style.floor,
		Color = style.color,
		Accent = style.accent,
		Landforms = DECOR_LANDFORMS,
		Trees = DECOR_TREES,
		Rocks = DECOR_ROCKS,
		Pools = style.pools,
		Spawns = spawns,
		Elite = elite,
	}
end

-- Roaming groups outside the arenas -- the farming population that fills the levels
-- between each gate. These replace the old roadside WILD_CAMPS, which were pinned to
-- indices in the single ROUTE table that the branch redesign removed.
WorldLayout.FIELD_SPAWNS = {}
for _, field in ipairs(MapAnchors.FieldSpawns) do
	WorldLayout.FIELD_SPAWNS[#WorldLayout.FIELD_SPAWNS + 1] = {
		Id = field.Id,
		Region = field.Region,
		Archetype = field.Archetype,
		Level = field.Level,
		Position = v3(field.Position),
		LeashRadius = field.LeashRadius,
	}
end

WorldLayout.SECRETS = {}
for _, secret in ipairs(MapAnchors.Secrets or {}) do
	WorldLayout.SECRETS[#WorldLayout.SECRETS + 1] = {
		Id = secret.Id, Region = secret.Region, Kind = secret.Kind, Position = v3(secret.Position),
	}
end

-- Kept so older callers that walked a single road still resolve; it is the first
-- branch, not a join of all five.
WorldLayout.ROUTE = WorldLayout.BRANCHES[1].Waypoints

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
		{ Vector3.new(0, 6, 0), 195 }, { Vector3.new(-65, 3, -45), 80 },
		{ Vector3.new(55, 3, 50), 70 },
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
		for _, pool in ipairs(zone.Pools or {}) do
			terrain:FillBlock(frame * CFrame.new(pool[1]), pool[2], Enum.Material.Water)
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
	local width = index % 3 == 0 and 12 or 10
	local length = (to - from).Magnitude + 0.5
	local frame = CFrame.lookAt(midpoint, to)
	local road = createPart(parent, string.format("%s%02d", namePrefix, index),
		Vector3.new(width, 1, length), frame, material, Color3.fromRGB(105, 96, 84))
	road:SetAttribute("FromLevel", fromNode.Level)
	road:SetAttribute("ToLevel", toNode.Level)
	-- Low kerbs frame the paving so the route reads from a distance. They rise only
	-- 0.4 above the road, so players and enemies step over them at junctions.
	for side = -1, 1, 2 do
		local kerb = createPart(parent, road.Name .. (side < 0 and "KerbL" or "KerbR"),
			Vector3.new(1.2, 1.4, length), frame * CFrame.new(side * (width / 2 + 0.6), 0.2, 0),
			Enum.Material.Slate, Color3.fromRGB(72, 68, 64))
		kerb.CanQuery = false
	end
	return road
end

local LAMP_WOOD = Color3.fromRGB(52, 44, 38)
local LAMP_GLOW = Color3.fromRGB(255, 205, 120)

local function buildLamp(parent, name, position)
	local base = terrainSurfaceAt(position)
	local model = Instance.new("Model")
	model.Name = name
	local post = createPart(model, "Post", Vector3.new(0.6, 9, 0.6), CFrame.new(base + Vector3.new(0, 4.5, 0)),
		Enum.Material.Wood, LAMP_WOOD)
	model.PrimaryPart = post
	createPart(model, "Arm", Vector3.new(0.4, 0.4, 2.2), CFrame.new(base + Vector3.new(0, 8.8, 0.9)),
		Enum.Material.Wood, LAMP_WOOD)
	local lantern = createPart(model, "Lantern", Vector3.new(1.1, 1.4, 1.1),
		CFrame.new(base + Vector3.new(0, 8, 1.8)), Enum.Material.Neon, LAMP_GLOW)
	lantern.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = LAMP_GLOW
	light.Brightness = 1.4
	light.Range = 16
	light.Parent = lantern
	model.Parent = parent
end

-- Destination sign beside each arena spur, facing the main trail. SurfaceGuis on both
-- faces are depth-tested like any part, so unlike billboards they never show through
-- terrain.
local function addSignFace(board, face, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.PixelsPerStud = 40
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
end

local function buildSignpost(parent, zone)
	local frame = arenaCFrame(zone)
	local entrance = frame:PointToWorldSpace(Vector3.new(0, 0, -ARENA_HALF - 1))
	local spurDirection = Vector3.new(entrance.X - zone.Approach.X, 0, entrance.Z - zone.Approach.Z).Unit
	local across = Vector3.new(-spurDirection.Z, 0, spurDirection.X)
	local base = terrainSurfaceAt(zone.Approach + spurDirection * 11 + across * 8.5)
	local model = Instance.new("Model")
	model.Name = zone.Name .. "Signpost"
	local post = createPart(model, "Post", Vector3.new(0.7, 7, 0.7), CFrame.new(base + Vector3.new(0, 3.5, 0)),
		Enum.Material.Wood, LAMP_WOOD)
	model.PrimaryPart = post
	local boardCenter = base + Vector3.new(0, 6, 0)
	local facing = Vector3.new(zone.Approach.X, boardCenter.Y, zone.Approach.Z)
	local board = createPart(model, "Board", Vector3.new(7, 2.6, 0.35),
		CFrame.lookAt(boardCenter, facing), Enum.Material.WoodPlanks, zone.Color:Lerp(Color3.new(0, 0, 0), 0.35))
	local text = string.format("%s\nLEVEL %d+", string.upper(zone.DisplayName), zone.RequiredLevel)
	addSignFace(board, Enum.NormalId.Front, text, zone.Accent)
	addSignFace(board, Enum.NormalId.Back, text, zone.Accent)
	model.Parent = parent
end

local function buildRoads(parent)
	-- One road per branch, each walked independently. Joining them would cut across
	-- open water between regions.
	for branchIndex, branch in ipairs(WorldLayout.BRANCHES) do
		local waypoints = branch.Waypoints
		for index = 1, #waypoints - 1 do
			buildTrailSegment(parent, waypoints[index], waypoints[index + 1], index,
				string.format("Trail_%s_", branch.Id))
		end
		-- Lamps on every other node, alternating shoulders, just outside the kerb.
		for index = 2, #waypoints, 2 do
			local before = waypoints[index - 1].Position
			local after = waypoints[math.min(#waypoints, index + 1)].Position
			local along = Vector3.new(after.X - before.X, 0, after.Z - before.Z)
			if along.Magnitude > 0.001 then
				along = along.Unit
				local across = Vector3.new(-along.Z, 0, along.X) * ((index / 2) % 2 == 0 and 1 or -1)
				buildLamp(parent, string.format("Lamp_%s_%02d", branch.Id, index),
					waypoints[index].Position + across * (branch.Width / 2 - 5))
			end
		end
		local _ = branchIndex
	end
	for index, zone in ipairs(WorldLayout.ZONES) do
		local frame = arenaCFrame(zone)
		local entrance = frame:PointToWorldSpace(Vector3.new(0, 0, -ARENA_HALF - 1))
		buildTrailSegment(parent, {
			Position = zone.Approach, Material = zone.TerrainMaterial, Level = zone.RequiredLevel,
		}, {
			Position = entrance, Material = zone.FloorMaterial, Level = zone.RequiredLevel,
		}, index, "ArenaSpur")
		buildSignpost(parent, zone)
	end
end

local function addZoneMarker(parent, zone, frame)
	local markerPosition = frame:PointToWorldSpace(Vector3.new(0, 5, -ARENA_HALF - 8))
	local marker = createPart(parent, "ZoneMarker", Vector3.new(1, 1, 1), CFrame.new(markerPosition),
		Enum.Material.SmoothPlastic, zone.Accent)
	marker.Transparency = 1
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(280, 60)
	-- Not AlwaysOnTop: that drew every zone sign through hills and ruin walls from
	-- across the map. Hidden by terrain now, it only reads when the gate is in view.
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = 110
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
	-- BossRooms is in EnemyCombat's ground-raycast list; without this every rig in
	-- the room snapped to the top of this invisible 22-stud box and dropped in.
	-- BossRoomGate tests Bounds with its own maths, so it needs no query.
	bounds.CanQuery = false
	local exit = createPart(model, "Exit", Vector3.new(4, 1, 4),
		frame * CFrame.new(0, 0.5, -ARENA_HALF - 9), Enum.Material.SmoothPlastic, zone.Accent)
	exit.Transparency = 1
	exit.CanCollide = false
	exit.CanTouch = false
	exit.CanQuery = false

	for brazierIndex, x in ipairs({ -13, 13 }) do
		local flame = createPart(model, "GateLight" .. brazierIndex, Vector3.new(2, 2, 2),
			frame * CFrame.new(x, 5, gateZ - 1), Enum.Material.Neon, zone.Accent)
		flame.Shape = Enum.PartType.Ball
		flame.CanCollide = false
	end
	-- Hidden alcove: a rear-corner pocket screened (not sealed) by two ruin slabs,
	-- holding one elite a level above the room's minions. It rewards players who
	-- look past the boss instead of fighting straight down the middle.
	if zone.Elite then
		local alcove = zone.Elite[2]
		local towardCenter = Vector3.new(-alcove.X, 0, -alcove.Z).Unit
		local across = Vector3.new(-towardCenter.Z, 0, towardCenter.X)
		for slabIndex, side in ipairs({ -1, 1 }) do
			local slabPosition = alcove + towardCenter * 4 + across * (side * 4.5)
			createPart(model, "AlcoveScreen" .. slabIndex, Vector3.new(5, 9, 6),
				frame * CFrame.lookAt(slabPosition + Vector3.new(0, 4.5, 0),
					slabPosition + Vector3.new(0, 4.5, 0) + towardCenter),
				Enum.Material.Rock, ruinColor)
		end
		local glow = createPart(model, "AlcoveMarker", Vector3.new(1.5, 4, 1.5),
			frame * CFrame.new(alcove + across * 2.5 + Vector3.new(0, 2, 0)), Enum.Material.Neon,
			Color3.fromRGB(255, 210, 90))
		glow.CanCollide = false
		glow.CanQuery = false -- EnemyCombat's ground raycast must land on the floor, not this
		local light = Instance.new("PointLight")
		light.Color = glow.Color
		light.Brightness = 4
		light.Range = 18
		light.Parent = glow
	end
	addZoneMarker(model, zone, frame)
	model.Parent = parent
end

local function buildTree(parent, name, position, zone, variant)
	local model = Instance.new("Model")
	model.Name = name
	local height = 10 + (variant % 3) * 2
	-- Infernal deadwood and Stormwatch's lightning-struck snags are bare; others leaf out.
	local bare = zone.Style == "Infernal" or zone.Style == "Storm"
	local trunkColor = bare and Color3.fromRGB(58, 42, 37) or Color3.fromRGB(91, 63, 43)
	if zone.Style == "Marsh" then trunkColor = Color3.fromRGB(62, 58, 44) end
	local trunk = createPart(model, "Trunk", Vector3.new(2.2, height, 2.2),
		CFrame.new(position + Vector3.new(0, height / 2, 0)), Enum.Material.Wood, trunkColor)
	model.PrimaryPart = trunk
	if bare then
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

local function flatDistanceToSegment(point, a, b)
	local p, s, e = Vector3.new(point.X, 0, point.Z), Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
	local span = e - s
	local t = span.Magnitude > 0 and math.clamp((p - s):Dot(span) / span:Dot(span), 0, 1) or 0
	return (p - (s + span * t)).Magnitude
end

local function distanceToRoute(point)
	local best = math.huge
	for _, branch in ipairs(WorldLayout.BRANCHES) do
		local waypoints = branch.Waypoints
		for index = 1, #waypoints - 1 do
			best = math.min(best,
				flatDistanceToSegment(point, waypoints[index].Position, waypoints[index + 1].Position))
		end
	end
	return best
end

local function distanceToOtherArena(point, zone)
	local best = math.huge
	for _, other in ipairs(WorldLayout.ZONES) do
		if other ~= zone then
			best = math.min(best, (Vector3.new(point.X - other.Center.X, 0, point.Z - other.Center.Z)).Magnitude)
		end
	end
	return best
end

-- Landmarks prefer the point straight behind the arena, but two of the original
-- sites (Iron, Frost) landed on the trail itself. Swing around the back until the
-- site clears the road and every other arena.
local LANDMARK_ANGLES = { 0, 30, -30, 60, -60, 90, -90 }
local function landmarkSite(zone, frame)
	local distance = ARENA_HALF + 18
	for _, degrees in ipairs(LANDMARK_ANGLES) do
		local angle = math.rad(degrees)
		local site = frame:PointToWorldSpace(Vector3.new(math.sin(angle) * distance, 0, math.cos(angle) * distance))
		if distanceToRoute(site) >= 20 and distanceToOtherArena(site, zone) >= 50 then
			return site
		end
	end
	return frame:PointToWorldSpace(Vector3.new(0, 0, distance))
end

local function buildLandmark(parent, zone)
	local frame = arenaCFrame(zone)
	local rear = terrainSurfaceAt(landmarkSite(zone, frame))
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
	elseif zone.Style == "Briar" then
		-- Ancient root shrine: a vast hollow stump, arching roots, a glowing heartstone.
		local stump = createPart(model, "ShrineStump", Vector3.new(14, 12, 12),
			CFrame.new(rear + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Enum.Material.Wood, Color3.fromRGB(78, 56, 38))
		stump.Shape = Enum.PartType.Cylinder
		for rootIndex = 1, 6 do
			local angle = math.rad(rootIndex * 60 + 15)
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			createPart(model, "Root" .. rootIndex, Vector3.new(2.4, 2.4, 11),
				CFrame.lookAt(rear + out * 7 + Vector3.new(0, 2, 0), rear + out * 13 - Vector3.new(0, 1.5, 0)),
				Enum.Material.Wood, Color3.fromRGB(70, 50, 34))
		end
		for archIndex, x in ipairs({ -5, 5 }) do
			createPart(model, "RootArch" .. archIndex, Vector3.new(2, 16, 2),
				CFrame.new(rear + Vector3.new(x, 16, -2)) * CFrame.Angles(0, 0, math.rad(-x * 4)),
				Enum.Material.Wood, Color3.fromRGB(70, 50, 34))
		end
		local heart = createPart(model, "Heartstone", Vector3.new(3.5, 3.5, 3.5),
			CFrame.new(rear + Vector3.new(0, 15, 0)), Enum.Material.Neon, zone.Accent)
		heart.Shape = Enum.PartType.Ball
		heart.CanCollide = false
	elseif zone.Style == "Marsh" then
		-- Flooded bell tower: a leaning brick tower half-sunk in its own pool.
		local lean = CFrame.new(rear + Vector3.new(0, 11, 0)) * CFrame.Angles(math.rad(6), 0, math.rad(-8))
		model.PrimaryPart = createPart(model, "BellTower", Vector3.new(9, 26, 9), lean,
			Enum.Material.Brick, zone.Color:Lerp(Color3.fromRGB(110, 100, 90), 0.5))
		createPart(model, "Belfry", Vector3.new(11, 1.5, 11), lean * CFrame.new(0, 12, 0),
			Enum.Material.WoodPlanks, Color3.fromRGB(60, 52, 44))
		for pillarIndex, offset in ipairs({
			Vector3.new(-4.5, 15.5, -4.5), Vector3.new(4.5, 15.5, -4.5),
			Vector3.new(-4.5, 15.5, 4.5), Vector3.new(4.5, 15.5, 4.5),
		}) do
			createPart(model, "BelfryPost" .. pillarIndex, Vector3.new(1.2, 6, 1.2), lean * CFrame.new(offset),
				Enum.Material.Brick, zone.Color)
		end
		createPart(model, "BelfryRoof", Vector3.new(11, 1.5, 11), lean * CFrame.new(0, 19, 0),
			Enum.Material.Slate, Color3.fromRGB(45, 50, 48))
		local bell = createPart(model, "SunkenBell", Vector3.new(4, 4, 4), lean * CFrame.new(0, 15.5, 0),
			Enum.Material.CorrodedMetal, Color3.fromRGB(90, 130, 110))
		bell.Shape = Enum.PartType.Ball
		local glow = Instance.new("PointLight")
		glow.Color = zone.Accent
		glow.Range = 20
		glow.Parent = bell
		Workspace.Terrain:FillBlock(CFrame.new(rear + Vector3.new(0, -1.5, 0)), Vector3.new(26, 3, 26),
			Enum.Material.Water)
	elseif zone.Style == "Storm" then
		-- Broken storm observatory: cracked drum walls, a split dome and a tilted
		-- telescope, with a lit lightning rod still standing.
		for wallIndex = 1, 7 do
			local angle = math.rad(wallIndex * 45)
			local height = 8 + (wallIndex % 3) * 3
			local at = rear + Vector3.new(math.cos(angle) * 9, height / 2, math.sin(angle) * 9)
			createPart(model, "ObservatoryWall" .. wallIndex, Vector3.new(7, height, 1.6),
				CFrame.lookAt(at, Vector3.new(rear.X, at.Y, rear.Z)), Enum.Material.Granite, zone.Color)
		end
		local dome = createPart(model, "BrokenDome", Vector3.new(15, 15, 15),
			CFrame.new(rear + Vector3.new(2, 12, 1)), Enum.Material.Metal, zone.Color:Lerp(Color3.new(1, 1, 1), 0.3))
		dome.Shape = Enum.PartType.Ball
		dome.Transparency = 0.35
		local scope = createPart(model, "Telescope", Vector3.new(15, 2.6, 2.6),
			CFrame.new(rear + Vector3.new(0, 16, 0)) * CFrame.Angles(0, math.rad(30), math.rad(35)),
			Enum.Material.Metal, Color3.fromRGB(150, 130, 90))
		scope.Shape = Enum.PartType.Cylinder
		local rod = createPart(model, "LightningRod", Vector3.new(0.6, 16, 0.6),
			CFrame.new(rear + Vector3.new(-7, 26, -4)), Enum.Material.Neon, zone.Accent)
		rod.CanCollide = false
		local spark = Instance.new("PointLight")
		spark.Color = zone.Accent
		spark.Brightness = 3
		spark.Range = 24
		spark.Parent = rod
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
	local spawnPosition = WorldLayout.BLANK_SLATE
		and Vector3.new(WorldLayout.HUB.Center.X, 0.5, WorldLayout.HUB.Center.Z)
		or WorldLayout.HUB.SpawnPosition
	spawn.CFrame = CFrame.new(spawnPosition)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Enabled = true
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(255, 226, 112)
	spawn.Transparency = 0.15
end

local function buildBlankSlate()
	local terrain = Workspace.Terrain
	terrain:Clear()
	-- Decoration is NotScriptable; default.project.json sets it in the saved place.
	restoreBaseplate()

	for _, name in ipairs({ "WorldGenerated", "BossRooms", "Trees", "Boulders", "Landmarks", "Causeways",
		"HubCampfire", "HubLeaderboard", "RespecShrine", "RelicMerchantNPC",
		"Wandering Villager", "Sitting Farmer", "Pacing Guard" }) do
		local existing = Workspace:FindFirstChild(name)
		if existing then existing:Destroy() end
	end

	-- Keep the folder available for systems that wait for boss-room collision geometry.
	local rooms = Instance.new("Folder")
	rooms.Name = "BossRooms"
	rooms.Parent = Workspace
	resetSpawn()
end

local function relocateLoosePlacedPart(generated)
	local loose = Workspace:FindFirstChild("Part")
	if not loose or not loose:IsA("BasePart") then return end
	loose.Name = "PlacedItem"
	loose.Anchored = true
	loose.CFrame = CFrame.new(Vector3.new(-18, WorldLayout.HUB.MerchantPosition.Y + loose.Size.Y / 2, -169))
	loose.Parent = generated
end

-- The imported map, when present, owns every visual. Version-matched so a stale or
-- partial import falls back rather than leaving the world half-built.
function WorldLayout.GetImportedMap()
	local map = Workspace:FindFirstChild(WorldLayout.MAP_MODEL_NAME)
	if map and map:GetAttribute("MapRedesignVersion") == WorldLayout.ANCHOR_VERSION then
		return map
	end
	return nil
end

function WorldLayout.IsImportedMap()
	return WorldLayout.GetImportedMap() ~= nil
end

-- Every enemy the world spawns: the eight arenas (boss, minions, elite) plus the
-- roaming field groups that fill the levels between gates. Arena positions come
-- straight from the anchor contract, which already applied the arena frame -- applying
-- it a second time here would mirror every minion to the wrong side of its boss.
function WorldLayout.GetEnemySpawns()
	if WorldLayout.BLANK_SLATE then return {} end
	local configs = {}
	for _, zone in ipairs(WorldLayout.ZONES) do
		local entries = table.clone(zone.Spawns)
		if zone.Elite then
			entries[#entries + 1] = zone.Elite
		end
		for _, entry in ipairs(entries) do
			configs[#configs + 1] = {
				archetype = entry[1],
				position = entry.Position,
				level = entry[3],
				zone = zone.Name,
				region = zone.Region,
				role = entry.Role,
			}
		end
	end
	for _, field in ipairs(WorldLayout.FIELD_SPAWNS) do
		configs[#configs + 1] = {
			archetype = field.Archetype,
			position = field.Position,
			level = field.Level,
			zone = field.Region,
			region = field.Region,
			role = "field",
			leashRadius = field.LeashRadius,
		}
	end
	return configs
end

function WorldLayout.EnsureBuilt()
	if built then return end
	built = true
	Workspace:SetAttribute("WorldReady", false)

	if WorldLayout.BLANK_SLATE then
		local imported = Workspace:FindFirstChild(WorldLayout.MAP_MODEL_NAME)
		if imported then imported:Destroy() end
		buildBlankSlate()
		Workspace:SetAttribute("WorldLayoutVersion", WorldLayout.VERSION)
		Workspace:SetAttribute("WorldSource", "BlankSlate")
		Workspace:SetAttribute("WorldReady", true)
		return
	end

	local imported = WorldLayout.GetImportedMap()
	if imported then
		-- Hands off the visuals: the meshes are the world. Only the gameplay anchors
		-- (arena floors, ForceField doors, Bounds, Exit markers, hub NPC anchors) get
		-- built, and they are built HERE rather than from a separate Script so they
		-- exist before any service that waits on them resumes.
		local installed = require(script.Parent:WaitForChild("MapAnchorInstaller")).install(imported)
		if not installed then
			warn("[WorldLayout] Imported map present but anchors failed to install")
		end
		Workspace:SetAttribute("WorldLayoutVersion", WorldLayout.VERSION)
		Workspace:SetAttribute("WorldSource", "Imported")
		Workspace:SetAttribute("WorldReady", true)
		return
	end

	-- Fallback: no imported map yet, so stand up a playable stand-in at the same
	-- anchor positions. Everything below is replaced wholesale once the GLBs land.
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

	-- The sanctuary is 360 studs across in the redesign, not the old 52-stud plaza.
	local plaza = createPart(generated, "HubPlaza", Vector3.new(1, WorldLayout.HUB.Radius * 2, WorldLayout.HUB.Radius * 2),
		CFrame.new(WorldLayout.HUB.Center + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Enum.Material.Cobblestone, Color3.fromRGB(127, 119, 103))
	plaza.Shape = Enum.PartType.Cylinder
	plaza.CanCollide = true

	resetSpawn()
	relocateLoosePlacedPart(generated)
	rebuildDecor()
	Workspace:SetAttribute("WorldLayoutVersion", WorldLayout.VERSION)
	Workspace:SetAttribute("WorldSource", "Fallback")
	Workspace:SetAttribute("WorldReady", true)
end

return WorldLayout
