-- ModuleScript | ServerScriptService.WorldLayout | Gameplay placement only; never builds a map.
-- Two modes, chosen once at startup:
--   "map"       Workspace.LemonadeMap markers exist and the MapMarkers module is synced (map.project.json).
--   "baseplate" otherwise: the original gameplay-only placement on the existing Baseplate.
local Workspace = game:GetService("Workspace")
local WorldLayout = {
	VERSION = 2,
	GAMEPLAY_ONLY = true,
	BLANK_SLATE = false,
	MAP_MODEL_NAME = "UnusedGameplayMap",
	FIELD_SPAWNS = {},
	MODE = "baseplate",
	SAFE_ZONES = nil, -- map mode: { {Name, CFrame, Size} } replaces the circular hub radius
}

-- [TUNING] Existing enemy identities and levels, without the old map's coordinates.
WorldLayout.ZONES = {
	{ Name = "IronLowlands", Region = "IronLowlands", Enemies = {{"Boss_Gorgon",10,"boss"},{"IronSquire",1},{"IronSquire",2},{"IronBerserker",2},{"IronBerserker",3},{"IronBerserker",3,"elite"}} },
	{ Name = "Briarwood", Region = "IronLowlands", Enemies = {{"RootWarden",14,"boss"},{"ThornStalker",9},{"ThornStalker",10},{"BriarBrute",11},{"BriarBrute",12}} },
	{ Name = "FrostboundGlacier", Region = "FrostboundGlacier", Enemies = {{"Boss_FrostRevenant",25,"boss"},{"FrostImp",18},{"FrostImp",19},{"GlacialGargoyle",21},{"GlacialGargoyle",22},{"GlacialGargoyle",23,"elite"}} },
	{ Name = "SunkenMarsh", Region = "FrostboundGlacier", Enemies = {{"DrownedBellwarden",29,"boss"},{"BogLurker",24},{"BogLurker",25},{"MireHulk",26},{"MireHulk",27}} },
	{ Name = "InfernalCaldera", Region = "InfernalCaldera", Enemies = {{"Boss_InfernalColossus",45,"boss"},{"CinderFiend",34},{"CinderFiend",35},{"MagmaJuggernaut",38},{"MagmaJuggernaut",39},{"MagmaJuggernaut",41,"elite"}} },
	{ Name = "Stormwatch", Region = "InfernalCaldera", Enemies = {{"TempestWarden",48,"boss"},{"Stormcaller",41},{"Stormcaller",42},{"ThunderConstruct",44},{"ThunderConstruct",45}} },
	{ Name = "VoidRift", Region = "VoidRift", Enemies = {{"Boss_VoidWraith",70,"boss"},{"VoidShade",55},{"VoidShade",56},{"AbyssTormentor",62},{"AbyssTormentor",63},{"AbyssTormentor",66,"elite"}} },
	{ Name = "CelestialSummit", Region = "CelestialSummit", Enemies = {{"Boss_CelestialTitan",100,"boss"},{"AstralWisp",80},{"AstralWisp",81},{"SolarDominator",88},{"SolarDominator",89},{"SolarDominator",92,"elite"}} },
}

-- The marker reader only ships with the map project; the default project never loads it.
local markersModule = script.Parent:FindFirstChild("MapMarkers")
local MapMarkers = markersModule and require(markersModule)
local useMap = MapMarkers ~= nil and MapMarkers.isPresent()

function WorldLayout.GetBaseplate(): BasePart?
	local plate = Workspace:FindFirstChild("Baseplate")
	return if plate and plate:IsA("BasePart") then plate else nil
end

function WorldLayout.SurfacePosition(x: number, z: number): Vector3
	local plate = WorldLayout.GetBaseplate()
	if not plate then return Vector3.new(x, 0, z) end
	return plate.CFrame:PointToWorldSpace(Vector3.new(x, plate.Size.Y / 2, z))
end

if useMap then
	WorldLayout.MODE = "map"
	WorldLayout.MAP_MODEL_NAME = MapMarkers.MAP_NAME
	WorldLayout.SAFE_ZONES = MapMarkers.safeZones()
	local spawn = MapMarkers.playerSpawn()
	local function place(markerName)
		local cframe = MapMarkers.npc(markerName)
		return cframe and cframe.Position, cframe
	end
	local hub = { Center = spawn and spawn.Position or Vector3.zero, SafeRadius = 0 }
	hub.MerchantPosition, hub.MerchantCFrame = place("Merchant")
	hub.QuestGiverPosition, hub.QuestGiverCFrame = place("QuestMaster")
	hub.RebirthPosition, hub.RebirthCFrame = place("RebirthKeeper")
	hub.RespecPosition, hub.RespecCFrame = place("SkillTrainer")
	hub.VaultPosition, hub.VaultCFrame = place("Vaultkeeper")
	-- The town spin wheel: a SpinWheel marker when the map carries one, else the open lawn west of the
	-- plaza, north of the west road (the widest clear ground in the hub: nothing within 13 studs of
	-- (-48, 20)), turned to face the plaza's centre so it reads face-on from the plaza and the road.
	-- (Looked up quietly: the map has no SpinWheel marker yet, and MapMarkers.npc warns on a miss.)
	local markerFolder = MapMarkers.getMap() and MapMarkers.getMap():FindFirstChild("Markers")
	local npcFolder = markerFolder and markerFolder:FindFirstChild("NPCs")
	if npcFolder and npcFolder:FindFirstChild("SpinWheel") then
		hub.SpinPosition, hub.SpinCFrame = place("SpinWheel")
	end
	if not hub.SpinPosition then
		local at = Vector3.new(-48, (spawn and spawn.Position.Y or 10.5) - 0.5, 20)
		hub.SpinCFrame = CFrame.lookAt(at, Vector3.new(0, at.Y, 0))
		hub.SpinPosition = at
	end
	WorldLayout.HUB = hub
else
	local plate = WorldLayout.GetBaseplate()
	local halfSize = if plate then math.min(plate.Size.X, plate.Size.Z) / 2 else 256
	local safeRadius = math.min(40, halfSize * 0.2) -- [TUNING] Invisible safety rule, no geometry.
	WorldLayout.HUB = {
		Center = WorldLayout.SurfacePosition(0, 0), SafeRadius = safeRadius,
		MerchantPosition = WorldLayout.SurfacePosition(safeRadius * 0.6, 0),
		QuestGiverPosition = WorldLayout.SurfacePosition(-safeRadius * 0.6, 0),
		RebirthPosition = WorldLayout.SurfacePosition(0, safeRadius * 0.6),
		RespecPosition = WorldLayout.SurfacePosition(0, -safeRadius * 0.6),
		VaultPosition = WorldLayout.SurfacePosition(-safeRadius * 0.6, safeRadius * 0.6),
		SpinPosition = WorldLayout.SurfacePosition(safeRadius * 0.6, -safeRadius * 0.6),
	}
	-- The spin wheel stands in the free south-east diagonal slot, facing the hub centre.
	WorldLayout.HUB.SpinCFrame = CFrame.lookAt(WorldLayout.HUB.SpinPosition,
		WorldLayout.HUB.Center * Vector3.new(1, 0, 1) + Vector3.new(0, WorldLayout.HUB.SpinPosition.Y, 0))
end

local function getMapEnemySpawns()
	local known, covered, configs = {}, {}, {}
	for _, zone in ipairs(WorldLayout.ZONES) do known[zone.Name] = true end
	for _, config in ipairs(MapMarkers.enemySpawns()) do
		if known[config.zone] then
			covered[config.zone] = true
			table.insert(configs, config)
		else
			warn(string.format("[Gameplay] Spawn marker %s names unknown zone %s; skipped", config.id, config.zone))
		end
	end
	local idle = {}
	for _, zone in ipairs(WorldLayout.ZONES) do
		if not covered[zone.Name] then table.insert(idle, zone.Name) end
	end
	if #idle > 0 then
		print("[Gameplay] Map has no spawn markers yet for: " .. table.concat(idle, ", ") .. " (those zones stay idle)")
	end
	return configs
end

-- [TUNING] Enemies come in packs: a camp is 3-6 rigs standing loosely together that notice the
-- player together (EnemyCombat pack aggro, by PackId), so a fight is a crowd of small, fast hits
-- instead of one rig trading big blows. Packs grow the further into the world they sit.
WorldLayout.PACKS = {
	MIN = 3,
	MAX = 6,
	SPREAD = 4.2, -- studs from a pack's centre to its members' spots
	MAP_MINION = 3, -- a map minion marker stands for a pack of this many (markers are dense already)
	MAP_ELITE = 4, -- an elite marker: the elite plus escorts
}

-- Pack size for the `packIndex`-th camp (1-based) of the `zoneIndex`-th zone.
function WorldLayout.PackSize(zoneIndex: number, packIndex: number, elite: boolean?): number
	local P = WorldLayout.PACKS
	local size = P.MIN + (packIndex - 1) + math.floor((zoneIndex - 1) / 3) + (elite and 1 or 0)
	return math.clamp(size, P.MIN, P.MAX)
end

-- Members of one pack around `center`: a loose ring (one rig in the middle once there are 5+), each
-- spot a little jittered but deterministic, so camps look gathered rather than drilled in rows.
local function packSpots(center: Vector3, size: number, seed: number): { Vector3 }
	local spots = {}
	local spread = WorldLayout.PACKS.SPREAD
	local ringCount = if size >= 5 then size - 1 else size
	if size >= 5 then table.insert(spots, center) end
	for i = 1, ringCount do
		local a = (i - 1) * 2 * math.pi / ringCount + seed * 0.7
		local r = spread * (0.85 + 0.3 * ((i * 37 + seed * 11) % 7) / 6)
		table.insert(spots, center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
	end
	return spots
end

-- Expands one camp config into its members. `levels` is cycled over the members; members after the
-- first of an elite camp are its minion escorts. Every member carries packId / packIndex / packSize.
local function expandPack(base, center: Vector3, size: number, levels: { number }, packId: string, seed: number, out)
	for index, spot in ipairs(packSpots(center, size, seed)) do
		local member = table.clone(base)
		member.position = spot
		member.level = levels[((index - 1) % #levels) + 1]
		if base.role == "elite" and index > 1 then member.role = "minion" end
		member.packId = packId
		member.packIndex = index
		member.packSize = size
		if base.id then member.id = base.id .. "_" .. index end
		table.insert(out, member)
	end
end

local function packMapSpawns(configs)
	local out, zoneOrder = {}, {}
	for index, zone in ipairs(WorldLayout.ZONES) do zoneOrder[zone.Name] = index end
	for _, config in ipairs(configs) do
		if config.role == "boss" then
			table.insert(out, config)
		else
			local elite = config.role == "elite"
			local size = if elite then WorldLayout.PACKS.MAP_ELITE else WorldLayout.PACKS.MAP_MINION
			local seed = #out + (zoneOrder[config.zone] or 1)
			expandPack(config, config.position, size, { config.level }, config.id or ("P" .. #out), seed, out)
		end
	end
	return out
end

function WorldLayout.GetEnemySpawns()
	if WorldLayout.BLANK_SLATE then return {} end
	if useMap then return packMapSpawns(getMapEnemySpawns()) end
	local baseplate = WorldLayout.GetBaseplate()
	if not baseplate then
		warn("[Gameplay] No Baseplate found; automatic enemy placement is idle")
		return {}
	end
	local half = math.min(baseplate.Size.X, baseplate.Size.Z) / 2
	if half < 128 then
		warn("[Gameplay] Baseplate too small for all enemy groups; leaving it unchanged")
		return {}
	end
	local radius = half * 0.65 -- [TUNING] Gameplay characters on existing ground.
	local configs = {}
	for index, zone in ipairs(WorldLayout.ZONES) do
		local angle = (index - 1) * 2 * math.pi / #WorldLayout.ZONES
		-- Consecutive entries of one archetype and role form one camp (their levels mixed through
		-- it); the boss stands alone. Camps sit on a ring around the zone's centre, spaced so two
		-- camps are never pulled by the same step.
		local camps = {}
		for _, enemy in ipairs(zone.Enemies) do
			local role = enemy[3] or "minion"
			local last = camps[#camps]
			if last and role ~= "boss" and last.archetype == enemy[1] and last.role == role then
				table.insert(last.levels, enemy[2])
			else
				table.insert(camps, { archetype = enemy[1], role = role, levels = { enemy[2] } })
			end
		end
		local packIndex = 0
		for slot, camp in ipairs(camps) do
			local offset = (slot - 1) * 2 * math.pi / #camps
			local ring = 32 -- [TUNING] camps ~45 studs apart: a boss never joins a pack's fight
			local x = math.sin(angle) * radius + math.sin(offset) * ring
			local z = -math.cos(angle) * radius + math.cos(offset) * ring
			local base = { archetype = camp.archetype, level = camp.levels[1], role = camp.role,
				zone = zone.Name, region = zone.Region, position = WorldLayout.SurfacePosition(x, z),
				leashRadius = 24 }
			if camp.role == "boss" then
				table.insert(configs, base)
			else
				packIndex += 1
				local size = WorldLayout.PackSize(index, packIndex, camp.role == "elite")
				local center = WorldLayout.SurfacePosition(x, z)
				-- Surface points are lifted back onto the plate by EnemyCombat's ground raycast.
				expandPack(base, center, size, camp.levels, zone.Name .. "_P" .. packIndex, index * 5 + slot, configs)
			end
		end
	end
	return configs
end

function WorldLayout.EnsureBuilt() end -- Compatibility: deliberately creates and clears nothing.
function WorldLayout.GetImportedMap() return nil end
function WorldLayout.IsImportedMap() return false end
return WorldLayout
