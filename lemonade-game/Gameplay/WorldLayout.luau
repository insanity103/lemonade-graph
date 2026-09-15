-- ModuleScript | ServerScriptService.WorldLayout | Gameplay placement only; never builds a map.
local Workspace = game:GetService("Workspace")
local WorldLayout = {
	VERSION = 1,
	GAMEPLAY_ONLY = true,
	BLANK_SLATE = false,
	MAP_MODEL_NAME = "UnusedGameplayMap",
	FIELD_SPAWNS = {},
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

function WorldLayout.GetBaseplate(): BasePart?
	local plate = Workspace:FindFirstChild("Baseplate")
	return if plate and plate:IsA("BasePart") then plate else nil
end

function WorldLayout.SurfacePosition(x: number, z: number): Vector3
	local plate = WorldLayout.GetBaseplate()
	if not plate then return Vector3.new(x, 0, z) end
	return plate.CFrame:PointToWorldSpace(Vector3.new(x, plate.Size.Y / 2, z))
end

local plate = WorldLayout.GetBaseplate()
local halfSize = if plate then math.min(plate.Size.X, plate.Size.Z) / 2 else 256
local safeRadius = math.min(40, halfSize * 0.2) -- [TUNING] Invisible safety rule, no geometry.
WorldLayout.HUB = {
	Center = WorldLayout.SurfacePosition(0, 0), SafeRadius = safeRadius,
	MerchantPosition = WorldLayout.SurfacePosition(safeRadius * 0.6, 0),
	QuestGiverPosition = WorldLayout.SurfacePosition(-safeRadius * 0.6, 0),
	RebirthPosition = WorldLayout.SurfacePosition(0, safeRadius * 0.6),
	RespecPosition = WorldLayout.SurfacePosition(0, -safeRadius * 0.6),
}

function WorldLayout.GetEnemySpawns()
	if WorldLayout.BLANK_SLATE then return {} end
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
		for slot, enemy in ipairs(zone.Enemies) do
			local offset = (slot - 1) * 2 * math.pi / #zone.Enemies
			local x = math.sin(angle) * radius + math.sin(offset) * 22
			local z = -math.cos(angle) * radius + math.cos(offset) * 22
			table.insert(configs, { archetype = enemy[1], level = enemy[2],
				role = enemy[3] or "minion", zone = zone.Name, region = zone.Region,
				position = WorldLayout.SurfacePosition(x, z), leashRadius = 24 })
		end
	end
	return configs
end

function WorldLayout.EnsureBuilt() end -- Compatibility: deliberately creates and clears nothing.
function WorldLayout.GetImportedMap() return nil end
function WorldLayout.IsImportedMap() return false end
return WorldLayout
