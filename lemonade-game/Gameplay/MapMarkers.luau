-- ModuleScript | ServerScriptService.MapMarkers | Reads Workspace.LemonadeMap markers (docs/map/MARKERS.md).
-- Gameplay asks this module where things go instead of embedding map coordinates. Anything
-- missing warns once and returns nothing, so the feature that needed it stays idle.
local Workspace = game:GetService("Workspace")

local MapMarkers = {
	MAP_NAME = "LemonadeMap",
	SCHEMA_VERSION = 1,
	ROLES = { minion = true, elite = true, boss = true },
}

local warned = {}
local function warnOnce(key: string, message: string)
	if warned[key] then return end
	warned[key] = true
	warn("[MapMarkers] " .. message)
end

function MapMarkers.getMap(): Instance?
	return Workspace:FindFirstChild(MapMarkers.MAP_NAME)
end

function MapMarkers.isPresent(): boolean
	local map = MapMarkers.getMap()
	return map ~= nil and map:FindFirstChild("Markers") ~= nil
end

local function folder(kind: string): Instance?
	local map = MapMarkers.getMap()
	local markers = map and map:FindFirstChild("Markers")
	local found = markers and markers:FindFirstChild(kind)
	if markers and not found then
		warnOnce(kind, `Markers/{kind} missing; features that use it stay idle`)
	end
	return found
end

local function partsIn(kind: string): { BasePart }
	local list = {}
	local container = folder(kind)
	if container then
		for _, child in container:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(list, child)
			end
		end
	end
	return list
end

local function attr(part: Instance, name: string, kind: string, default: any?): any
	local value = part:GetAttribute(name)
	if typeof(value) == kind then return value end
	return default
end

function MapMarkers.pointInBox(cframe: CFrame, size: Vector3, point: Vector3): boolean
	local p = cframe:PointToObjectSpace(point)
	local half = size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

function MapMarkers.npc(name: string): CFrame?
	local container = folder("NPCs")
	local part = container and container:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part.CFrame
	end
	warnOnce("npc:" .. name, `NPC marker {name} missing; that character is not placed`)
	return nil
end

function MapMarkers.playerSpawn(): SpawnLocation?
	local map = MapMarkers.getMap()
	local markers = map and map:FindFirstChild("Markers")
	local spawn = markers and markers:FindFirstChild("PlayerSpawn")
	if spawn and spawn:IsA("SpawnLocation") then
		return spawn
	end
	warnOnce("spawn", "Markers/PlayerSpawn missing; players use the place's own SpawnLocation")
	return nil
end

function MapMarkers.safeZones()
	local zones = {}
	for _, part in partsIn("SafeZones") do
		table.insert(zones, { Name = part.Name, CFrame = part.CFrame, Size = part.Size })
	end
	return zones
end

function MapMarkers.regions()
	local regions = {}
	for _, part in partsIn("Regions") do
		table.insert(regions, {
			Name = part.Name,
			DisplayName = attr(part, "DisplayName", "string", part.Name),
			Subtitle = attr(part, "Subtitle", "string", ""),
			Order = attr(part, "Order", "number", 0),
			CFrame = part.CFrame,
			Size = part.Size,
		})
	end
	table.sort(regions, function(a, b) return a.Order < b.Order end)
	return regions
end

-- Enemy spawn configs in the shape EnemyCombat.spawnEnemy expects. Malformed markers are skipped.
function MapMarkers.enemySpawns()
	local configs = {}
	for _, part in partsIn("EnemySpawns") do
		local archetype = attr(part, "Archetype", "string")
		local level = attr(part, "Level", "number")
		local role = attr(part, "Role", "string", "minion")
		local zone = attr(part, "Zone", "string")
		if not archetype or not level or level < 1 or not zone or not MapMarkers.ROLES[role] then
			warnOnce("spawn:" .. part.Name, `Enemy spawn {part.Name} has missing or invalid attributes; skipped`)
			continue
		end
		table.insert(configs, {
			id = part.Name,
			archetype = archetype,
			level = math.floor(level),
			role = role,
			zone = zone,
			region = attr(part, "Region", "string", zone),
			position = part.Position,
			leashRadius = attr(part, "LeashRadius", "number"),
		})
	end
	table.sort(configs, function(a, b) return a.id < b.id end)
	return configs
end

function MapMarkers.waypoints()
	local list = {}
	for _, part in partsIn("Waypoints") do
		table.insert(list, {
			Id = part.Name,
			DisplayName = attr(part, "DisplayName", "string", part.Name),
			Region = attr(part, "Region", "string", ""),
			Order = attr(part, "Order", "number", 99),
			DiscoverRadius = attr(part, "DiscoverRadius", "number", 18),
			CFrame = part.CFrame,
		})
	end
	table.sort(list, function(a, b) return a.Order < b.Order end)
	return list
end

-- Waystone models anywhere under the map, each linked to a waypoint by its WaypointId attribute.
function MapMarkers.waystones()
	local list = {}
	local map = MapMarkers.getMap()
	if not map then return list end
	for _, model in map:GetDescendants() do
		if model:GetAttribute("Waystone") == true then
			local id = model:GetAttribute("WaypointId")
			-- PromptAnchor sits at player height; Core is the tall crystal itself.
			local anchor = model:FindFirstChild("PromptAnchor") or model:FindFirstChild("Core")
				or model:FindFirstChildWhichIsA("BasePart")
			if typeof(id) == "string" and anchor and anchor:IsA("BasePart") then
				table.insert(list, { WaypointId = id, Anchor = anchor, Model = model })
			end
		end
	end
	return list
end

return MapMarkers
