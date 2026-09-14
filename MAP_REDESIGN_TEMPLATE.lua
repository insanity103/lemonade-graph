-- MAP_REDESIGN_TEMPLATE.lua
-- GPT-6 Astra: Fill in the Vector3 values below, then paste into WorldLayout.luau
-- All positions are in STUDS (Roblox units). 1 stud ≈ 1 foot.
-- Hub is at the center. Route connects hub to all zones.

-- ============================================================
-- STEP 1: HUB (Safe Zone)
-- ============================================================
WorldLayout.HUB = {
    Center = Vector3.new(0, 2, 0),              -- CHANGE: world center of hub
    SpawnPosition = Vector3.new(0, 3, 0),       -- CHANGE: where players appear
    MerchantPosition = Vector3.new(10, 3, 0),   -- CHANGE: merchant NPC location
}

-- ============================================================
-- STEP 2: ROUTE (Road connecting hub to all zones)
-- ============================================================
-- 22 waypoints minimum. Each node is a point on the road.
-- Materials: Cobblestone, Ground, Rock, Snow, Basalt, Slate, Sandstone, Marble, Mud
-- Level tags are informational (for zone transitions).

WorldLayout.ROUTE = {
    -- Hub area (level 0, cobblestone)
    { Position = Vector3.new(0, 2, 0),       Material = Enum.Material.Cobblestone, Level = 0 },
    { Position = Vector3.new(0, 2, -20),     Material = Enum.Material.Cobblestone, Level = 0 },

    -- Zone 1 approach (level 1)
    { Position = Vector3.new(0, 3, -50),     Material = Enum.Material.Ground, Level = 1 },
    { Position = Vector3.new(0, 4, -80),     Material = Enum.Material.Ground, Level = 1 },
    { Position = Vector3.new(0, 5, -110),    Material = Enum.Material.Ground, Level = 1 },

    -- Zone 2 approach (level 10)
    { Position = Vector3.new(0, 6, -140),    Material = Enum.Material.Rock, Level = 10 },

    -- Zone 3 approach (level 15)
    { Position = Vector3.new(0, 8, -170),    Material = Enum.Material.Snow, Level = 15 },
    { Position = Vector3.new(0, 10, -200),   Material = Enum.Material.Snow, Level = 15 },
    { Position = Vector3.new(0, 12, -230),   Material = Enum.Material.Snow, Level = 15 },
    { Position = Vector3.new(0, 14, -260),   Material = Enum.Material.Snow, Level = 15 },

    -- Zone 4 approach (level 22)
    { Position = Vector3.new(0, 16, -290),   Material = Enum.Material.Rock, Level = 22 },

    -- Zone 5 approach (level 30)
    { Position = Vector3.new(0, 18, -320),   Material = Enum.Material.Basalt, Level = 30 },
    { Position = Vector3.new(0, 20, -350),   Material = Enum.Material.Basalt, Level = 30 },
    { Position = Vector3.new(0, 21, -380),   Material = Enum.Material.Basalt, Level = 30 },

    -- Zone 6 approach (level 40)
    { Position = Vector3.new(0, 23, -410),   Material = Enum.Material.Rock, Level = 40 },

    -- Zone 7 approach (level 50)
    { Position = Vector3.new(0, 26, -440),   Material = Enum.Material.Slate, Level = 50 },
    { Position = Vector3.new(0, 28, -470),   Material = Enum.Material.Slate, Level = 50 },
    { Position = Vector3.new(0, 30, -500),   Material = Enum.Material.Slate, Level = 50 },
    { Position = Vector3.new(0, 32, -530),   Material = Enum.Material.Slate, Level = 58 },

    -- Zone 8 approach (level 75)
    { Position = Vector3.new(0, 35, -560),   Material = Enum.Material.Sandstone, Level = 68 },
    { Position = Vector3.new(0, 38, -590),   Material = Enum.Material.Sandstone, Level = 75 },
    { Position = Vector3.new(0, 40, -620),   Material = Enum.Material.Marble, Level = 75 },
}

-- ============================================================
-- STEP 3: ZONES (8 combat arenas)
-- ============================================================
-- Each zone needs:
--   Name/DisplayName: internal ID and player-facing name
--   RequiredLevel: level gate
--   Center: world position of the arena center
--   Approach: the road point the player enters from (one of the ROUTE nodes)
--   TerrainMaterial/FloorMaterial: ground and arena floor
--   Color/Accent: primary and accent colors
--   Style: one of "Woodland", "Briar", "FrostPine", "Marsh", "Infernal", "Storm", "Void", "Celestial"
--   Landforms: terrain mounds {Vector3, radius}
--   Trees: local positions for trees/props
--   Rocks: local positions for boulder clusters
--   Spawns: enemy configs {"ArchetypeName", Vector3(local), level}
--   Elite: optional elite enemy {"ArchetypeName", Vector3(local), level}
--   Pools: optional water blocks (only for marsh-style zones)

WorldLayout.ZONES = {
    -- ZONE 1: IRON LOWLANDS (Level 1, Starter)
    {
        Name = "IronLowlands",
        DisplayName = "Iron Lowlands",
        RequiredLevel = 1,
        Center = Vector3.new(-50, 5, -120),        -- CHANGE
        Approach = Vector3.new(0, 4, -80),          -- CHANGE (must match a ROUTE node)
        TerrainMaterial = Enum.Material.Ground,
        FloorMaterial = Enum.Material.Slate,
        Color = Color3.fromRGB(117, 75, 67),
        Accent = Color3.fromRGB(205, 103, 78),
        Style = "Woodland",
        Landforms = {
            { Vector3.new(-30, 0, 15), 35 },
            { Vector3.new(30, 0, 20), 30 },
            { Vector3.new(0, 0, -25), 28 },
        },
        Trees = {
            Vector3.new(-20, 0, -10), Vector3.new(20, 0, -10),
            Vector3.new(-25, 0, 15), Vector3.new(25, 0, 15),
            Vector3.new(-15, 0, 30), Vector3.new(15, 0, 30),
        },
        Rocks = {
            Vector3.new(-30, 0, -20), Vector3.new(30, 0, -20), Vector3.new(0, 0, 35),
        },
        Spawns = {
            { "Boss_Gorgon", Vector3.new(0, 0, 10), 10 },
            { "IronSquire", Vector3.new(-15, 0, -7), 1 },
            { "IronSquire", Vector3.new(15, 0, -7), 1 },
            { "IronBerserker", Vector3.new(-14, 0, 17), 2 },
            { "IronBerserker", Vector3.new(14, 0, 17), 2 },
        },
        Elite = { "IronBerserker", Vector3.new(-7, 0, 26), 3 },
    },

    -- ZONE 2: BRIARWOOD (Level 8, Bridge)
    -- ... repeat pattern for zones 3-8 ...

    -- ZONE 3: FROSTBOUND GLACIER (Level 15, Boss)
    -- Boss: Boss_FrostRevenant (Lv25)
    -- Enemies: FrostImp, GlacialGargoyle

    -- ZONE 4: SUNKEN MARSH (Level 23, Bridge)
    -- Has water pools (Pools field)
    -- Boss: DrownedBellwarden (Named Elite, Lv29)
    -- Enemies: BogLurker, MireHulk

    -- ZONE 5: INFERNAL CALDERA (Level 30, Boss)
    -- Boss: Boss_InfernalColossus (Lv45)
    -- Enemies: CinderFiend, MagmaJuggernaut

    -- ZONE 6: STORMWATCH (Level 40, Bridge)
    -- Boss: TempestWarden (Named Elite, Lv48)
    -- Enemies: Stormcaller, ThunderConstruct

    -- ZONE 7: VOID RIFT (Level 50, Boss)
    -- Boss: Boss_VoidWraith (Lv70)
    -- Enemies: VoidShade, AbyssTormentor

    -- ZONE 8: CELESTIAL SUMMIT (Level 75, Boss)
    -- Boss: Boss_CelestialTitan (Lv100)
    -- Enemies: AstralWisp, SolarDominator
}

-- ============================================================
-- STEP 4: WILD CAMPS (Roadside level-gap fillers)
-- ============================================================
-- Camps fill level gaps between zones. Each camp is positioned
-- at a ROUTE node with a side offset (-1 = left, 1 = right).

WorldLayout.WILD_CAMPS = {
    {
        Name = "RiftSummitSteps",
        RouteIndex = 20,                        -- which ROUTE node
        Side = -1,                              -- -1 = left, 1 = right
        Zone = "VoidRift",                      -- which zone's enemies
        Spawns = {
            { "AbyssTormentor", 70 },
            { "VoidShade", 72 },
            { "AstralWisp", 74 },
        },
    },
    -- Add more camps as needed to fill level gaps
}

-- ============================================================
-- CONSTANTS (don't change unless you know what you're doing)
-- ============================================================
WorldLayout.ARENA_SIZE = 68        -- boss arena diameter in studs
WorldLayout.DOOR_WIDTH = 14        -- boss room gate width
WorldLayout.CAMP_OFFSET = 17       -- camp distance from road centerline
WorldLayout.CAMP_SPAWN_RING = 6    -- camp enemy spawn ring radius
