local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local CombatUtil = require(script.Parent:WaitForChild("CombatUtil"))
local EnemyOutfits = require(ReplicatedStorage:WaitForChild("EnemyOutfits"))
local WorldLayout = require(script.Parent:WaitForChild("WorldLayout"))
local SafeHub = require(script.Parent:WaitForChild("SafeHub"))
local ComboConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ComboConfig"))
local AudioManager = require(ReplicatedStorage:WaitForChild("AudioManager"))
local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))
WorldLayout.EnsureBuilt()

local ENEMY_TAG = CombatUtil.ENEMY_TAG
local ENEMY_ATTRIBUTE = CombatUtil.ENEMY_ATTRIBUTE
local CREATOR_TAG_NAME = "creator"

local ATTACK_RANGE = 10
-- Sword mesh sizing. Each boss carries its own mesh (CombatUtil.getSwordMesh); its
-- MeshSize aspect keeps the blade undistorted at SWORD_LENGTH * rig scale.
local SWORD_LENGTH = 4.2
local SWORD_GRIP_FRAC = 0.38 -- where along the blade the hand sits, from centre (same on every mesh)
-- Defense is a straight percentage reduction with a hard cap, so it can never trivialise an enemy.
local DEFENSE_PCT_PER_POINT = 0.003 -- each Defense point removes 0.30% of incoming damage
local DEFENSE_MAX_REDUCTION = 0.35 -- hard cap: Defense never mitigates more than 35%
-- Keep early encounters forgiving and leave room for mistakes. Players should be
-- able to clear a small group and reach the next level without repeated deaths.
local ENEMY_DAMAGE_MULTIPLIER = 0.55
-- Enemies fight in packs (WorldLayout.PACKS): many small, fast hits instead of few big ones.
-- Ordinary rigs hit for PACK_DAMAGE_SCALE of their listed damage and swing PACK_SPEED_MULT times as
-- often, so one rig's damage per second is unchanged. Bosses keep their listed cadence and damage so
-- a boss fight stays a readable duel. A crowd shares a damage budget: each hit on a player is scaled
-- by (attackers on that player) ^ -CROWD_EXPONENT, so a pack of n deals n^(1-CROWD_EXPONENT) times
-- one rig's DPS (4 rigs 2x, 6 rigs ~2.45x) -- the old flat 0.7 s per-player throttle landed ~1.9x
-- from any group while swallowing most swings; now every swing that connects shows a number.
local PACK_DAMAGE_SCALE = 0.5 -- [TUNING] per-hit damage of non-boss rigs
local PACK_SPEED_MULT = 2.0 -- [TUNING] attack-rate multiplier of non-boss rigs
local CROWD_EXPONENT = 0.5 -- [TUNING] crowd damage sharing (0 = none, 1 = a crowd deals one rig's DPS)
local CROWD_WINDOW = 1.6 -- seconds a rig counts as "on" a player after its last swing at them
local CADENCE_JITTER = 0.15 -- [TUNING] +- fraction of each swing interval, so a pack's hits stream
local PACK_CALL_RADIUS = 45 -- studs: packmates this close join a fight one of them starts
local ENEMY_HIT_INTERVAL_PER_PLAYER = 0.02 -- only stops two hits landing on the very same frame
local ATTACK_COOLDOWN = 0.4
local RESPAWN_DELAY = 5
local DROP_RESPAWN_DELAY = 1.5 -- [TUNING] a rig that just paid a sword is back this fast
-- Enemy swings telegraph before they land: damage resolves when the blade comes down, and only
-- if the target is still within reach (+ grace for movement during the swing). Heavy hitters
-- (slow attack cycles) wind up longer. Archetypes may override with `windup`.
local ENEMY_WINDUP = 0.32 -- [TUNING] seconds from raise to impact for ordinary attackers
local HEAVY_WINDUP = 0.5 -- [TUNING] attackCooldown >= HEAVY_COOLDOWN
local HEAVY_COOLDOWN = 1.6
local HIT_GRACE = 1.5 -- [TUNING] studs beyond attackReach that still count at impact
local DEFAULT_ARCHETYPE = "IronSquire"

-- Classic Shirt/Pants texture pairs per boss family, so every archetype in a zone
-- (minions, its elite alcove spawn, and the boss) reads as one faction instead of a
-- flat-colored block. Verified real Roblox catalog assets: AssetTypeId 11 = Shirt,
-- 12 = Pants, both public (5 R$, referencing them as a template needs no purchase).
local TEXTURE_SETS = {
	SterlingSilver = { shirt = 104282632152691, pants = 139353720126326 }, -- Iron Hall
	Frostbite      = { shirt = 121924965140998, pants = 99353608981343  }, -- Frost Glacier
	MagmaFiery     = { shirt = 123363908145112, pants = 96561718306565  }, -- Infernal Forge
	Darkheart      = { shirt = 139651785525579, pants = 88740990058786  }, -- Void Rift
	Golden         = { shirt = 100133588604370, pants = 92015331906060  }, -- Celestial Sanctum
	Ranger         = { shirt = 12696379800,     pants = 12696385673     }, -- Briarwood
}
-- PS99 pass: off. These catalog templates are painted armour/cloth (steel plate, fur, leather)
-- and read as a different, photoreal material next to plastic bodies and matte plastic swords;
-- the rig now reads by its plastic body colour and EnemyOutfits' accessory parts alone. The sets
-- are kept so the switch is one flag.
local CLOTHING_TEXTURES = false
local ARCHETYPE_TEXTURE_SET = {
	IronSquire = "SterlingSilver", IronBerserker = "SterlingSilver", Boss_Gorgon = "SterlingSilver",
	FrostImp = "Frostbite", GlacialGargoyle = "Frostbite", Boss_FrostRevenant = "Frostbite",
	CinderFiend = "MagmaFiery", MagmaJuggernaut = "MagmaFiery", Boss_InfernalColossus = "MagmaFiery",
	VoidShade = "Darkheart", AbyssTormentor = "Darkheart", Boss_VoidWraith = "Darkheart",
	AstralWisp = "Golden", SolarDominator = "Golden", Boss_CelestialTitan = "Golden",
	ThornStalker = "Ranger", BriarBrute = "Ranger", RootWarden = "Ranger",
	-- Sunken Marsh and Stormwatch have no verified catalog set yet; they read by body colour.
}
-- NPC decisions do not need to run at the render/frame rate. Keeping a short
-- fixed tick preserves responsive combat while avoiding work proportional to
-- enemies × players every frame.
local AI_TICK_INTERVAL = 0.15
local TARGET_SCAN_INTERVAL = 0.5
local MOVE_COMMAND_INTERVAL = 0.35
local MOVE_TARGET_EPSILON = 2

local ATTACK_REMOTE = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("EnemyAttack")
local DAMAGE_EVENT = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("DamageNumber")

local playerCooldowns = {}
local playerEnemyHitAt = {}
local playerAttackers = {} -- [player] = { [enemy model] = time of its last swing at them }

-- ==============================================================================
-- 1. ENEMY & BOSS ARCHETYPES CONFIGURATION
-- ==============================================================================
local ENEMY_ARCHETYPES = {
	-- Body colours (PS99 pass): every archetype's `color` is a full-chroma toy plastic -- the one
	-- vivid accent on the rig -- and ReplicatedStorage.EnemyOutfits lays pale, calm cloth over it
	-- with a second small pop for trims, so each enemy pairs one calm surface with one or two
	-- saturated ones instead of reading as a single muted block. Each family keeps its hue
	-- (coral quarry, cyan frost, orange cinder, violet void, gold astral, lime briar, aqua marsh,
	-- blue storm); rank steps the same hue deeper, never duller. Nothing here is grey or brown.
	-- 1. Quarry Bandits (Iron Lowlands, Lv 1-10). Looks: ReplicatedStorage.EnemyOutfits.
	IronSquire = {
		name = "Quarry Cutthroat",
		color = Color3.fromRGB(255, 88, 72),
		scale = 1.05,
		walkSpeed = 12.5,
		baseHealth = 120,
		healthGrowth = 1.20,
		baseDamage = 14,
		damageGrowth = 1.12,
		baseXP = 75,
		aggroRange = 24,
		attackReach = 6.0,
		attackCooldown = 1.3,
		patrolRadius = 12,
		leashDistance = 35,
		weapon = true, -- the shared SwordMeshTemplate falchion; no swordColor, its texture stands
	},
	IronBerserker = {
		name = "Pit Brute",
		color = Color3.fromRGB(255, 64, 56),
		scale = 1.25,
		walkSpeed = 10.0,
		baseHealth = 240,
		healthGrowth = 1.22,
		baseDamage = 22,
		damageGrowth = 1.14,
		baseXP = 140,
		aggroRange = 22,
		attackReach = 7.0,
		attackCooldown = 1.8,
		patrolRadius = 10,
		leashDistance = 32,
		weapon = true,
	},

	-- 2. Frost Revenant Minions (North-West Permafrost Glade, Lv 15-20)
	FrostImp = {
		name = "Frost Stalker",
		color = Color3.fromRGB(72, 204, 255),
		scale = 0.95,
		walkSpeed = 16.0,
		baseHealth = 450,
		healthGrowth = 1.24,
		baseDamage = 35,
		damageGrowth = 1.15,
		baseXP = 320,
		aggroRange = 28,
		attackReach = 5.5,
		attackCooldown = 1.1,
		patrolRadius = 14,
		leashDistance = 40,
	},
	GlacialGargoyle = {
		name = "Glacial Sentinel",
		color = Color3.fromRGB(36, 160, 255),
		scale = 1.35,
		walkSpeed = 11.0,
		baseHealth = 950,
		healthGrowth = 1.26,
		baseDamage = 52,
		damageGrowth = 1.16,
		baseXP = 600,
		aggroRange = 25,
		attackReach = 7.5,
		attackCooldown = 1.7,
		patrolRadius = 12,
		leashDistance = 36,
	},

	-- 3. Infernal Colossus Minions (North-East Caldera, Lv 30-38)
	CinderFiend = {
		name = "Cinder Fiend",
		color = Color3.fromRGB(255, 132, 32),
		scale = 1.05,
		walkSpeed = 15.0,
		baseHealth = 1800,
		healthGrowth = 1.28,
		baseDamage = 85,
		damageGrowth = 1.18,
		baseXP = 1200,
		aggroRange = 30,
		attackReach = 6.5,
		attackCooldown = 1.2,
		patrolRadius = 14,
		leashDistance = 42,
	},
	MagmaJuggernaut = {
		name = "Magma Juggernaut",
		color = Color3.fromRGB(255, 96, 24),
		scale = 1.45,
		walkSpeed = 11.5,
		baseHealth = 3600,
		healthGrowth = 1.30,
		baseDamage = 135,
		damageGrowth = 1.19,
		baseXP = 2200,
		aggroRange = 26,
		attackReach = 8.5,
		attackCooldown = 1.6,
		patrolRadius = 12,
		leashDistance = 38,
	},

	-- 4. Void Archon Minions (South-East Void Spire, Lv 50-60)
	VoidShade = {
		name = "Void Shade",
		color = Color3.fromRGB(168, 88, 255),
		scale = 1.1,
		walkSpeed = 17.0,
		baseHealth = 6500,
		healthGrowth = 1.32,
		baseDamage = 190,
		damageGrowth = 1.20,
		baseXP = 4500,
		aggroRange = 32,
		attackReach = 7.0,
		attackCooldown = 1.0,
		patrolRadius = 16,
		leashDistance = 46,
	},
	AbyssTormentor = {
		name = "Abyss Tormentor",
		color = Color3.fromRGB(128, 48, 255),
		scale = 1.55,
		walkSpeed = 13.0,
		baseHealth = 13000,
		healthGrowth = 1.33,
		baseDamage = 280,
		damageGrowth = 1.21,
		baseXP = 7500,
		aggroRange = 28,
		attackReach = 9.0,
		attackCooldown = 1.5,
		patrolRadius = 14,
		leashDistance = 42,
	},

	-- 5. Celestial Titan Minions (Far Astral Sanctuary, Lv 75-88)
	AstralWisp = {
		name = "Astral Emissary",
		color = Color3.fromRGB(255, 226, 64),
		scale = 1.15,
		walkSpeed = 18.0,
		baseHealth = 22000,
		healthGrowth = 1.34,
		baseDamage = 380,
		damageGrowth = 1.22,
		baseXP = 14000,
		aggroRange = 36,
		attackReach = 8.0,
		attackCooldown = 0.9,
		patrolRadius = 18,
		leashDistance = 50,
	},
	SolarDominator = {
		name = "Solar Dominator",
		color = Color3.fromRGB(255, 190, 32),
		scale = 1.7,
		walkSpeed = 14.0,
		baseHealth = 48000,
		healthGrowth = 1.35,
		baseDamage = 550,
		damageGrowth = 1.23,
		baseXP = 24000,
		aggroRange = 32,
		attackReach = 10.5,
		attackCooldown = 1.4,
		patrolRadius = 16,
		leashDistance = 48,
	},

	-- Bridge zones (WorldLayout: Briarwood Lv8, Sunken Marsh Lv23, Stormwatch Lv40). Their
	-- stats are log-interpolated between the neighbouring zones' curves at the spawn levels,
	-- so each one sits between the arena before it and the gate after it. Wardens are
	-- named elites, not bosses: no weapon, no sword drop.
	ThornStalker = {
		name = "Thorn Stalker", color = Color3.fromRGB(120, 236, 56), scale = 1.0, walkSpeed = 15,
		baseHealth = 203, healthGrowth = 1.23, baseDamage = 21, damageGrowth = 1.14, baseXP = 170,
		aggroRange = 26, attackReach = 6.0, attackCooldown = 1.2, patrolRadius = 14, leashDistance = 38,
	},
	BriarBrute = {
		name = "Briar Brute", color = Color3.fromRGB(80, 216, 48), scale = 1.35, walkSpeed = 11,
		baseHealth = 377, healthGrowth = 1.23, baseDamage = 32, damageGrowth = 1.14, baseXP = 240,
		aggroRange = 23, attackReach = 7.5, attackCooldown = 1.7, patrolRadius = 10, leashDistance = 34,
	},
	RootWarden = {
		name = "Rootbound Warden", title = "Keeper of the Grove", color = Color3.fromRGB(48, 192, 56),
		scale = 1.6, walkSpeed = 11.5, baseHealth = 724, healthGrowth = 1.23, baseDamage = 42,
		damageGrowth = 1.14, baseXP = 450, aggroRange = 30, attackReach = 9.0, attackCooldown = 1.6,
		patrolRadius = 10, leashDistance = 45, nameTag = true, tagColor = Color3.fromRGB(170, 220, 90),
	},
	BogLurker = {
		name = "Bog Lurker", color = Color3.fromRGB(48, 224, 176), scale = 1.05, walkSpeed = 14.5,
		baseHealth = 1030, healthGrowth = 1.26, baseDamage = 50, damageGrowth = 1.17, baseXP = 750,
		aggroRange = 27, attackReach = 6.5, attackCooldown = 1.2, patrolRadius = 14, leashDistance = 40,
	},
	MireHulk = {
		name = "Mire Hulk", color = Color3.fromRGB(32, 200, 150), scale = 1.45, walkSpeed = 10.5,
		baseHealth = 1915, healthGrowth = 1.26, baseDamage = 74, damageGrowth = 1.17, baseXP = 950,
		aggroRange = 24, attackReach = 8.0, attackCooldown = 1.8, patrolRadius = 11, leashDistance = 36,
	},
	DrownedBellwarden = {
		name = "Drowned Bellwarden", title = "Toller of the Sunken Bell", color = Color3.fromRGB(24, 176, 144),
		scale = 1.65, walkSpeed = 12, baseHealth = 3685, healthGrowth = 1.26, baseDamage = 99,
		damageGrowth = 1.17, baseXP = 1600, aggroRange = 32, attackReach = 9.5, attackCooldown = 1.6,
		patrolRadius = 10, leashDistance = 48, nameTag = true, tagColor = Color3.fromRGB(120, 210, 170),
	},
	Stormcaller = {
		name = "Stormcaller", color = Color3.fromRGB(88, 156, 255), scale = 1.1, walkSpeed = 17,
		baseHealth = 2750, healthGrowth = 1.31, baseDamage = 95, damageGrowth = 1.20, baseXP = 2800,
		aggroRange = 32, attackReach = 7.0, attackCooldown = 1.0, patrolRadius = 16, leashDistance = 44,
	},
	ThunderConstruct = {
		name = "Thunder Construct", color = Color3.fromRGB(64, 128, 255), scale = 1.5, walkSpeed = 12,
		baseHealth = 5100, healthGrowth = 1.31, baseDamage = 143, damageGrowth = 1.20, baseXP = 3500,
		aggroRange = 27, attackReach = 9.0, attackCooldown = 1.6, patrolRadius = 13, leashDistance = 40,
	},
	TempestWarden = {
		name = "Tempest Warden", title = "Keeper of the Observatory", color = Color3.fromRGB(48, 104, 255),
		scale = 1.7, walkSpeed = 13, baseHealth = 9800, healthGrowth = 1.31, baseDamage = 190,
		damageGrowth = 1.20, baseXP = 5500, aggroRange = 34, attackReach = 10.0, attackCooldown = 1.5,
		patrolRadius = 12, leashDistance = 50, nameTag = true, tagColor = Color3.fromRGB(130, 190, 255),
	},

	-- 5 UNIQUE SPREAD-OUT PROGRESSIVE BOSSES (High-Level & High-Stakes)
	Boss_Gorgon = {
		name = "Warden of the Pit",
		title = "Boss of the Quarry Bandits",
		color = Color3.fromRGB(255, 56, 88),
		scale = 1.5,
		walkSpeed = 12,
		baseHealth = 650,
		healthGrowth = 1.32,
		baseDamage = 32,
		damageGrowth = 1.16,
		baseXP = 600,
		aggroRange = 34,
		attackReach = 9.0,
		attackCooldown = 1.8,
		patrolRadius = 12,
		leashDistance = 55,
		weapon = true,
		boss = true,
		uniqueDrop = "Warlord Greatsword",
		swordColor = Color3.fromRGB(255, 72, 72),
		swordMaterial = Enum.Material.Metal,
		nameTag = true,
		tagColor = Color3.fromRGB(255, 90, 90),
	},
	Boss_FrostRevenant = {
		name = "Frost Revenant",
		title = "Lord of the Permafrost",
		color = Color3.fromRGB(24, 140, 255),
		scale = 1.7,
		walkSpeed = 13.5,
		baseHealth = 1600,
		healthGrowth = 1.34,
		baseDamage = 58,
		damageGrowth = 1.18,
		baseXP = 1500,
		aggroRange = 38,
		attackReach = 10.5,
		attackCooldown = 1.6,
		patrolRadius = 14,
		leashDistance = 60,
		weapon = true,
		boss = true,
		uniqueDrop = "Frostfang Cleaver",
		swordColor = Color3.fromRGB(120, 220, 255),
		swordMaterial = Enum.Material.Ice,
		nameTag = true,
		tagColor = Color3.fromRGB(100, 200, 255),
	},
	Boss_InfernalColossus = {
		name = "Infernal Colossus",
		title = "Scourge of Flame",
		color = Color3.fromRGB(255, 80, 24),
		scale = 1.9,
		walkSpeed = 12,
		baseHealth = 3600,
		healthGrowth = 1.36,
		baseDamage = 110,
		damageGrowth = 1.20,
		baseXP = 3400,
		aggroRange = 42,
		attackReach = 12.0,
		attackCooldown = 1.5,
		patrolRadius = 16,
		leashDistance = 68,
		weapon = true,
		boss = true,
		uniqueDrop = "Inferno Edge",
		swordColor = Color3.fromRGB(255, 120, 30),
		swordMaterial = Enum.Material.Neon,
		nameTag = true,
		tagColor = Color3.fromRGB(255, 140, 40),
	},
	Boss_VoidWraith = {
		name = "Void Archon",
		title = "Herald of Oblivion",
		color = Color3.fromRGB(112, 32, 240),
		scale = 2.1,
		walkSpeed = 15,
		baseHealth = 7200,
		healthGrowth = 1.38,
		baseDamage = 185,
		damageGrowth = 1.22,
		baseXP = 7000,
		aggroRange = 46,
		attackReach = 13.5,
		attackCooldown = 1.3,
		patrolRadius = 18,
		leashDistance = 75,
		weapon = true,
		boss = true,
		uniqueDrop = "Voidrend Blade",
		swordColor = Color3.fromRGB(180, 80, 255),
		swordMaterial = Enum.Material.Neon,
		nameTag = true,
		tagColor = Color3.fromRGB(210, 110, 255),
	},
	Boss_CelestialTitan = {
		name = "Celestial Titan",
		title = "God of the Astral Realm",
		color = Color3.fromRGB(255, 176, 32),
		scale = 2.4,
		walkSpeed = 14.5,
		baseHealth = 14500,
		healthGrowth = 1.40,
		baseDamage = 290,
		damageGrowth = 1.24,
		baseXP = 15000,
		aggroRange = 52,
		attackReach = 15.0,
		attackCooldown = 1.2,
		patrolRadius = 20,
		leashDistance = 85,
		weapon = true,
		boss = true,
		uniqueDrop = "Astral Eclipse",
		swordColor = Color3.fromRGB(255, 230, 100),
		swordMaterial = Enum.Material.Neon,
		nameTag = true,
		tagColor = Color3.fromRGB(255, 225, 70),
	},
}

local function getEnemyMaxHealth(archetype, level)
	if archetype.boss then
		-- Boss linear-quadratic scaling: smooth difficulty curve without numeric overflow at high levels
		return math.floor(archetype.baseHealth + (archetype.baseHealth * 0.45 * level) + (35 * level * level))
	end
	local levelDelta = math.max(0, level - 1)
	-- Soft quadratic growth keeps later zones meaningful without exponential
	-- one-shot spikes when a player reaches a new area.
	return math.floor(archetype.baseHealth * (1 + 0.14 * levelDelta + 0.008 * levelDelta * levelDelta))
end

local function getEnemyDamage(archetype, level)
	if archetype.boss then
		return math.floor(archetype.baseDamage + (archetype.baseDamage * 0.12 * level) + (2.5 * level))
	end
	local levelDelta = math.max(0, level - 1)
	return math.floor(archetype.baseDamage * (1 + 0.08 * levelDelta + 0.0015 * levelDelta * levelDelta))
end

-- Seconds between one rig's swings (before jitter): packs swing fast, bosses keep their tempo.
local function getAttackCooldown(archetype)
	if archetype.boss then
		return archetype.attackCooldown
	end
	return archetype.attackCooldown / PACK_SPEED_MULT
end

local function getEnemyXP(archetype, level)
	return math.floor(archetype.baseXP * level)
end

local function getPlayerAttackDamage(player)
	local strength = player:GetAttribute("Strength") or 0
	local weaponLevel = player:GetAttribute("WeaponLevel") or 0
	local swordMult = player:GetAttribute("SwordDamageMult") or 1
	local bonusPct = player:GetAttribute("SwordBonusDamagePct") or 0
	local critChance = (player:GetAttribute("SwordCritChance") or 0) + (player:GetAttribute("RebirthExtraCrit") or 0)
	local rebirthDmgMult = player:GetAttribute("RebirthDamageMult") or 1
	local critDamageMult = player:GetAttribute("RebirthCritDamageMult") or 1.75

	local baseDamage = 25
	local raw = (baseDamage + 5 * strength) * swordMult * (1 + bonusPct) * (1 + 0.12 * weaponLevel) * rebirthDmgMult
	
	local isCrit = math.random() <= critChance
	if isCrit then
		raw = raw * critDamageMult
	end
	return math.max(1, math.floor(raw)), isCrit
end

local isEnemy = CombatUtil.isEnemy

-- ==============================================================================
-- 2. ENEMY RIG GENERATION (R6-style humanoid model with joints & unanchored physics)
-- ==============================================================================
local function createMotor6D(name, parent, part0, part1, c0, c1)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0 or CFrame.new()
	motor.C1 = c1 or CFrame.new()
	motor.Parent = parent
	return motor
end

local function resolveGroundPosition(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local ground = { Workspace.Terrain }
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		table.insert(ground, baseplate)
	end
	local bossRooms = Workspace:FindFirstChild("BossRooms")
	if bossRooms then
		table.insert(ground, bossRooms)
	end
	-- The imported map's islands are meshes, not voxel terrain, so rigs would fall
	-- through without these. Only the collision proxies and regional terrain count as
	-- ground: decorative batches and invisible Bounds must stay out of this raycast.
	local map = Workspace:FindFirstChild(WorldLayout.MAP_MODEL_NAME)
	if map then
		local collision = map:FindFirstChild("Collision")
		if collision then
			table.insert(ground, collision)
		end
		for _, child in ipairs(map:GetChildren()) do
			if string.match(child.Name, "^Terrain_") or string.match(child.Name, "^Grounds_") then
				table.insert(ground, child)
			end
		end
	end
	params.FilterDescendantsInstances = ground
	local result = Workspace:Raycast(pos + Vector3.new(0, 80, 0), Vector3.new(0, -500, 0), params)
	if result then
		return Vector3.new(pos.X, result.Position.Y, pos.Z)
	end
	return pos
end

local function createEnemyRig(archetypeKey, spawnPosition, level, role)
	local arch = ENEMY_ARCHETYPES[archetypeKey]
	if not arch then
		warn(string.format("[EnemyCombat] Unknown archetype %s; using %s", tostring(archetypeKey), DEFAULT_ARCHETYPE))
		archetypeKey = DEFAULT_ARCHETYPE
		arch = ENEMY_ARCHETYPES[archetypeKey]
	end
	level = level or 1
	spawnPosition = resolveGroundPosition(spawnPosition)

	local model = Instance.new("Model")
	model.Name = arch.name

	local s = arch.scale

	-- Root
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2 * s, 2 * s, 1 * s)
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.Position = spawnPosition + Vector3.new(0, 3 * s, 0)
	hrp.Parent = model
	model.PrimaryPart = hrp

	-- Torso
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2 * s, 2 * s, 1 * s)
	torso.Color = arch.color
	torso.Material = arch.boss and Enum.Material.SmoothPlastic or Enum.Material.SmoothPlastic
	torso.CanCollide = true
	torso.Position = hrp.Position
	torso.Parent = model

	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2 * s, 1.2 * s, 1.2 * s)
	head.Color = arch.color
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.Position = torso.Position + Vector3.new(0, 1.5 * s, 0)
	head.Parent = model

	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = head

	-- Left Arm
	local leftArm = Instance.new("Part")
	leftArm.Name = "Left Arm"
	leftArm.Size = Vector3.new(1 * s, 2 * s, 1 * s)
	leftArm.Color = arch.color
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.CanCollide = false
	leftArm.Position = torso.Position + Vector3.new(-1.5 * s, 0, 0)
	leftArm.Parent = model

	-- Right Arm
	local rightArm = Instance.new("Part")
	rightArm.Name = "Right Arm"
	rightArm.Size = Vector3.new(1 * s, 2 * s, 1 * s)
	rightArm.Color = arch.color
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.CanCollide = false
	rightArm.Position = torso.Position + Vector3.new(1.5 * s, 0, 0)
	rightArm.Parent = model

	-- Left Leg
	local leftLeg = Instance.new("Part")
	leftLeg.Name = "Left Leg"
	leftLeg.Size = Vector3.new(1 * s, 2 * s, 1 * s)
	leftLeg.Color = arch.color
	leftLeg.Material = Enum.Material.SmoothPlastic
	leftLeg.CanCollide = false
	leftLeg.Position = torso.Position + Vector3.new(-0.5 * s, -2 * s, 0)
	leftLeg.Parent = model

	-- Right Leg
	local rightLeg = Instance.new("Part")
	rightLeg.Name = "Right Leg"
	rightLeg.Size = Vector3.new(1 * s, 2 * s, 1 * s)
	rightLeg.Color = arch.color
	rightLeg.Material = Enum.Material.SmoothPlastic
	rightLeg.CanCollide = false
	rightLeg.Position = torso.Position + Vector3.new(0.5 * s, -2 * s, 0)
	rightLeg.Parent = model

	-- Clothing: a themed Shirt/Pants pair per boss family so the rig reads as a
	-- faction instead of a flat-colored block. arch.color still tints the parts
	-- underneath, so the palette stays consistent even where the texture shows skin.
	local textureSetName = ARCHETYPE_TEXTURE_SET[archetypeKey]
	local textureSet = CLOTHING_TEXTURES and textureSetName and TEXTURE_SETS[textureSetName]
	if textureSet then
		local shirt = Instance.new("Shirt")
		shirt.Name = "Shirt"
		shirt.ShirtTemplate = "rbxassetid://" .. textureSet.shirt
		shirt.Parent = model

		local pants = Instance.new("Pants")
		pants.Name = "Pants"
		pants.PantsTemplate = "rbxassetid://" .. textureSet.pants
		pants.Parent = model
	end

	-- Joints (Motor6D)
	createMotor6D("RootJoint", hrp, hrp, torso, CFrame.new(0, 0, 0), CFrame.new(0, 0, 0))
	createMotor6D("Neck", torso, torso, head, CFrame.new(0, 1 * s, 0), CFrame.new(0, -0.5 * s, 0))
	createMotor6D("Left Shoulder", torso, torso, leftArm, CFrame.new(-1 * s, 0.5 * s, 0), CFrame.new(0.5 * s, 0.5 * s, 0))
	createMotor6D("Right Shoulder", torso, torso, rightArm, CFrame.new(1 * s, 0.5 * s, 0), CFrame.new(-0.5 * s, 0.5 * s, 0))
	createMotor6D("Left Hip", torso, torso, leftLeg, CFrame.new(-0.5 * s, -1 * s, 0), CFrame.new(0, 1 * s, 0))
	createMotor6D("Right Hip", torso, torso, rightLeg, CFrame.new(0.5 * s, -1 * s, 0), CFrame.new(0, 1 * s, 0))
	-- Joints keep their rest C0 forever: every pose (walk, swing) is a Motor6D.Transform written
	-- on each client by ReplicatedStorage.EnemyAnimator, so nothing here replicates per frame.

	-- Weapon
	if arch.weapon then
		local template = CombatUtil.getSwordMesh(archetypeKey)
		if template then
			local L = SWORD_LENGTH * s
			local sword = template:Clone()
			sword.Name = "Sword"
			sword.Anchored = false
			CombatUtil.sizeSwordMesh(sword, L)
			sword.CanCollide = false
			sword.Massless = true
			CombatUtil.applyWeaponAppearance(sword, arch.swordColor, arch.swordMaterial)
			local hand = rightArm.Position + Vector3.new(0, -1 * s, 0)
			sword.CFrame = CFrame.new(hand - Vector3.new(0, 0, L * SWORD_GRIP_FRAC))
				* CFrame.Angles(0, math.pi, 0)
			sword.Parent = model

			-- A wrist joint, not a weld, so the client animator can turn the blade in the hand
			-- (in line with the arm at the strike). At rest it holds the sword exactly as welded.
			local handCF = CFrame.new(hand)
			createMotor6D("Grip", rightArm, rightArm, sword,
				rightArm.CFrame:ToObjectSpace(handCF), sword.CFrame:ToObjectSpace(handCF))
		end
	end

	-- Outfit: welded accessory parts (rust, leather, rag for the quarry gang) on top of the
	-- shirt/pants base layer. Applied after the joints and the weapon so nothing is re-parented.
	EnemyOutfits.apply(model, archetypeKey, s, role)

	-- Humanoid setup
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.WalkSpeed = arch.walkSpeed
	-- The joints outlive the death: every client plays the collapse through them (EnemyAnimator).
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model

	local maxHp = getEnemyMaxHealth(arch, level)
	humanoid.MaxHealth = maxHp
	humanoid.Health = maxHp

	-- Boss nameplate & dynamic health bar. PS99 chrome: chunky white-faced display type with a
	-- dark outline, and a white rounded bar with the same outline, so the plate reads on the
	-- bright world instead of as a charcoal strip.
	if arch.nameTag then
		local bb = Instance.new("BillboardGui")
		bb.Name = "NameTag"
		bb.Size = UDim2.fromOffset(260, 56)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 3.2 * s, 0)
		-- Depth-tested so boss tags no longer show through hills and arena walls map-wide.
		bb.AlwaysOnTop = false
		bb.MaxDistance = 120
		bb.Parent = head

		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1, 0, 0, 24)
		lbl.Position = UDim2.fromOffset(0, 0)
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextSize = 17
		lbl.TextColor3 = arch.tagColor or Color3.fromRGB(255, 90, 90)
		lbl.TextStrokeTransparency = 0
		lbl.TextStrokeColor3 = Color3.fromRGB(30, 33, 48)
		lbl.Text = string.format("☠ %s  [Lv %d]", arch.name, level)
		lbl.Parent = bb

		-- Health bar background
		local hpBg = Instance.new("Frame")
		hpBg.Size = UDim2.new(1, 0, 0, 10)
		hpBg.Position = UDim2.fromOffset(0, 26)
		hpBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		hpBg.BorderSizePixel = 0
		hpBg.Parent = bb
		local hpCorner = Instance.new("UICorner", hpBg)
		hpCorner.CornerRadius = UDim.new(0, 5)
		local hpStroke = Instance.new("UIStroke", hpBg)
		hpStroke.Color = Color3.fromRGB(30, 33, 48)
		hpStroke.Thickness = 2

		-- Health bar fill
		local hpFill = Instance.new("Frame")
		hpFill.Size = UDim2.new(1, 0, 1, 0)
		hpFill.BackgroundColor3 = arch.tagColor or Color3.fromRGB(255, 80, 80)
		hpFill.BorderSizePixel = 0
		hpFill.Parent = hpBg
		local fillCorner = Instance.new("UICorner", hpFill)
		fillCorner.CornerRadius = UDim.new(0, 5)

		-- Health numbers label
		local hpText = Instance.new("TextLabel")
		hpText.BackgroundTransparency = 1
		hpText.Size = UDim2.new(1, 0, 0, 14)
		hpText.Position = UDim2.fromOffset(0, 38)
		hpText.Font = Enum.Font.FredokaOne
		hpText.TextSize = 12
		hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
		hpText.TextStrokeTransparency = 0
		hpText.TextStrokeColor3 = Color3.fromRGB(30, 33, 48)
		hpText.Text = string.format("%d / %d", humanoid.Health, humanoid.MaxHealth)
		hpText.Parent = bb

		humanoid.HealthChanged:Connect(function(newHp)
			local ratio = math.clamp(newHp / humanoid.MaxHealth, 0, 1)
			TweenService:Create(hpFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(ratio, 0, 1, 0)
			}):Play()
			hpText.Text = string.format("%d / %d", math.max(0, math.floor(newHp)), humanoid.MaxHealth)
		end)
	else
		-- Ordinary enemies get a compact plate too: name, level and health, readable at fighting
		-- distance and hidden beyond it so a room full of enemies stays uncluttered.
		local bb = Instance.new("BillboardGui")
		bb.Name = "NameTag"
		bb.Size = UDim2.fromOffset(150, 30)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 2.2 * s, 0)
		bb.AlwaysOnTop = false
		bb.MaxDistance = 60 -- [TUNING]
		bb.Parent = head

		local lbl = Instance.new("TextLabel")
		lbl.Name = "Title"
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1, 0, 0, 16)
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextSize = 14
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.TextStrokeTransparency = 0
		lbl.TextStrokeColor3 = Color3.fromRGB(30, 33, 48)
		lbl.Text = string.format("%s  Lv %d", arch.name, level)
		lbl.Parent = bb

		local hpBg = Instance.new("Frame")
		hpBg.Size = UDim2.new(0.7, 0, 0, 6)
		hpBg.Position = UDim2.new(0.15, 0, 0, 19)
		hpBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		hpBg.BorderSizePixel = 0
		hpBg.Parent = bb
		local hpCorner = Instance.new("UICorner", hpBg)
		hpCorner.CornerRadius = UDim.new(0, 3)
		local hpStroke = Instance.new("UIStroke", hpBg)
		hpStroke.Color = Color3.fromRGB(30, 33, 48)
		hpStroke.Thickness = 1.5

		local hpFill = Instance.new("Frame")
		hpFill.Size = UDim2.new(1, 0, 1, 0)
		hpFill.BackgroundColor3 = Color3.fromRGB(255, 72, 72)
		hpFill.BorderSizePixel = 0
		hpFill.Parent = hpBg

		humanoid.HealthChanged:Connect(function(newHp)
			hpFill.Size = UDim2.new(math.clamp(newHp / humanoid.MaxHealth, 0, 1), 0, 1, 0)
		end)
	end

	-- Attributes and tags
	model:SetAttribute(ENEMY_ATTRIBUTE, true)
	model:SetAttribute("EnemyLevel", level)
	model:SetAttribute("Archetype", archetypeKey)
	model:SetAttribute("Boss", arch.boss == true)
	model:SetAttribute("UniqueDrop", arch.uniqueDrop or nil)
	model:SetAttribute("ExperienceReward", getEnemyXP(arch, level))
	CollectionService:AddTag(model, ENEMY_TAG)

	model.Parent = Workspace
	if hrp:CanSetNetworkOwnership() then
		hrp:SetNetworkOwner(nil)
	end

	return model, humanoid, hrp, arch, spawnPosition
end

-- ==============================================================================
-- 3. ENEMY STATE MACHINE & AI LOOP
-- ==============================================================================
local activeEnemies = {}

local function findNearestLivingPlayer(origin, maxDist)
	local bestPlayer, bestChar, bestHrp, bestDist = nil, nil, nil, maxDist
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and hrp then
				local dist = (hrp.Position - origin).Magnitude
				if dist < bestDist then
					bestPlayer = player
					bestChar = char
					bestHrp = hrp
					bestDist = dist
				end
			end
		end
	end
	return bestPlayer, bestChar, bestHrp, bestDist
end

-- Rigs that swung at `player` within CROWD_WINDOW (at least 1): the crowd sharing each hit.
local function countAttackers(player, now)
	local list = playerAttackers[player]
	if not list then
		return 1
	end
	local n = 0
	for model, at in pairs(list) do
		if now - at > CROWD_WINDOW or not model.Parent then
			list[model] = nil
		else
			n += 1
		end
	end
	return math.max(1, n)
end

local function noteAttacker(playerChar, model, now)
	local player = Players:GetPlayerFromCharacter(playerChar)
	if not player then
		return
	end
	local list = playerAttackers[player]
	if not list then
		list = setmetatable({}, { __mode = "k" })
		playerAttackers[player] = list
	end
	list[model] = now
end

local function applyEnemyDamageToPlayer(enemyModel, playerChar, arch, level)
	local humanoid = playerChar:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local enemyRoot = enemyModel.PrimaryPart or enemyModel:FindFirstChild("HumanoidRootPart")
	local playerRoot = playerChar:FindFirstChild("HumanoidRootPart")
	-- Line of sight ignores every rig, not just the attacker: in a pack the rig beside you must not
	-- "block" its packmate's blade (walls and cliffs still do).
	if not enemyRoot or not playerRoot then
		return
	end
	local ignore = CollectionService:GetTagged(ENEMY_TAG)
	table.insert(ignore, playerChar)
	if not CombatUtil.hasLineOfSight(enemyRoot.Position, playerRoot.Position, ignore) then
		return
	end
	-- The sanctuary is a hard no-damage volume, enforced on the server at the point
	-- damage is applied. Geometry and spawn distance alone are not a permission check:
	-- a pulled enemy that reaches the boundary still must not land a hit.
	if not SafeHub.canEnemyAttack(enemyRoot.Position, playerRoot.Position) then
		return
	end

	local player = Players:GetPlayerFromCharacter(playerChar)
	local crowd = 1
	if player then
		local now = tick()
		if now - (playerEnemyHitAt[player] or 0) < ENEMY_HIT_INTERVAL_PER_PLAYER then
			return
		end
		playerEnemyHitAt[player] = now
		crowd = countAttackers(player, now)
	end
	local defense = player and (player:GetAttribute("Defense") or 0) or 0
	local rawDamage = getEnemyDamage(arch, level)
	local reduction = math.min(defense * DEFENSE_PCT_PER_POINT, DEFENSE_MAX_REDUCTION)
	local scale = ENEMY_DAMAGE_MULTIPLIER * (1 - reduction)
	if not arch.boss then
		scale *= PACK_DAMAGE_SCALE * crowd ^ -CROWD_EXPONENT
	end
	-- Health takes the exact share (a crowd's small hits add up precisely); the number shown is it
	-- rounded, never below 1.
	local exactDamage = math.max(0.5, rawDamage * scale)
	local finalDamage = math.max(1, math.floor(exactDamage + 0.5))

	humanoid:TakeDamage(exactDamage)
	if player then
		-- Combat stamp: the town spin wheel refuses a spin within a few seconds of a hit (SpinSystem).
		player:SetAttribute("CombatAt", workspace:GetServerTimeNow())
	end

	local hrp = playerChar:FindFirstChild("HumanoidRootPart")
	if hrp then
		DAMAGE_EVENT:FireAllClients(hrp.Position, finalDamage, "incoming")
	end
end

-- Heavy vs ordinary is judged on the listed cadence; a pack rig's faster swing shortens its windup
-- so the whole swing (windup + ~0.44 s follow-through, EnemyAnimator.attackTimes) fits its cycle.
local MIN_PACK_WINDUP = 0.18
local function getWindup(arch)
	local windup = arch.windup or (arch.attackCooldown >= HEAVY_COOLDOWN and HEAVY_WINDUP or ENEMY_WINDUP)
	if arch.boss then
		return windup
	end
	return math.max(MIN_PACK_WINDUP, math.min(windup * 0.75, getAttackCooldown(arch) - 0.44))
end

-- Starts the swing and returns the seconds until the blade lands (when damage applies). The swing
-- itself is animated on every client by ReplicatedStorage.EnemyAnimator from this attribute:
-- (swing counter, seconds to impact). The server only publishes it; it never poses a joint.
local ATTACK_ATTRIBUTE = "EnemyAttack"

local function swingWeapon(model, arch)
	local windup = getWindup(arch)
	local previous = model:GetAttribute(ATTACK_ATTRIBUTE)
	local seq = (typeof(previous) == "Vector2" and previous.X or 0) + 1
	model:SetAttribute(ATTACK_ATTRIBUTE, Vector2.new(seq, windup))
	return windup
end

local DEATH_LINGER = 1.8 -- seconds a dead body stays (EnemyAnimator.DEATH_LINGER: collapse + shatter)

local function startEnemyAI(model, humanoid, hrp, arch, spawnPos, level, onDeath)
	local state = {
		mode = "IDLE",
		spawnPos = spawnPos,
		nextPatrolTime = tick() + math.random(1, 3),
		lastAttackTime = 0,
		nextSwingGap = 0,
		targetChar = nil,
		-- Where around its target this rig stands: its pack slot (so a pack fans out and surrounds
		-- instead of queueing behind one another), nudged a little after every swing.
		slotAngle = ((model:GetAttribute("PackIndex") or math.random(1, 6)) - 1) * 2 * math.pi
			/ (model:GetAttribute("PackSize") or 6) + math.random() * 0.6,
	}
	activeEnemies[model] = state

	-- Limb animation (walk cycle, swings) runs on each client: ReplicatedStorage.EnemyAnimator
	-- reads the rig's replicated motion and attributes, so the server writes no joints per frame.

	humanoid.Died:Connect(function()
		activeEnemies[model] = nil
		-- Play death sound
		local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
		if root then
			AudioManager.PlaySFX("enemy_death", root)
		end
		-- Presentation only: the body stays where it fell, out of every collision, raycast and
		-- hitbox, for DEATH_LINGER seconds, so each client can play the collapse and the shatter
		-- (EnemyAnimator, from Health reaching 0 and this timestamp) before the model goes.
		model:SetAttribute("EnemyDied", Workspace:GetServerTimeNow())
		if root then
			root.Anchored = true
		end
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
			end
		end
		task.delay(DEATH_LINGER, function()
			if model and model.Parent then
				model:Destroy()
			end
		end)
		if onDeath then
			onDeath()
		end
	end)
end

-- Presentation only: "EnemyAlert" carries the moment an enemy spotted a player (server time) for
-- as long as it chases, so each client can play the notice (head snap, startle, guard, the lemon
-- "!") and hold the weapon ready through the charge (ReplicatedStorage.EnemyAnimator). Set exactly
-- where the AI switches into and out of CHASE; the switch itself and its timing are unchanged.
local ALERT_ATTRIBUTE = "EnemyAlert"
local function clearAlert(model)
	if model:GetAttribute(ALERT_ATTRIBUTE) ~= nil then
		model:SetAttribute(ALERT_ATTRIBUTE, nil)
	end
end

-- Wakes the idle members of `model`'s pack standing within PACK_CALL_RADIUS onto the same target,
-- so a camp answers as one crowd. Their first swings are staggered so the hits stream in.
local function callPack(model, targetChar, now)
	local packId = model:GetAttribute("PackId")
	local root = model.PrimaryPart
	if not packId or not root then
		return
	end
	for other, otherState in pairs(activeEnemies) do
		if other ~= model and otherState.mode ~= "CHASE" and other:GetAttribute("PackId") == packId then
			local otherRoot = other.PrimaryPart
			if otherRoot and (otherRoot.Position - root.Position).Magnitude <= PACK_CALL_RADIUS then
				otherState.mode = "CHASE"
				otherState.targetChar = targetChar
				otherState.lastAttackTime = now
				otherState.nextSwingGap = math.random() * 0.5
				other:SetAttribute(ALERT_ATTRIBUTE, Workspace:GetServerTimeNow())
			end
		end
	end
end

-- The spot this rig fights from: on its slot around the target, just inside its reach.
local function slotPoint(state, targetPos, arch)
	local r = math.max(2.8, arch.attackReach * 0.6)
	return targetPos + Vector3.new(math.cos(state.slotAngle) * r, 0, math.sin(state.slotAngle) * r)
end

local function commandMove(state, humanoid, destination, now)
	local lastDestination = state.lastMoveDestination
	if not lastDestination
		or (destination - lastDestination).Magnitude >= MOVE_TARGET_EPSILON
		or (now - (state.lastMoveTime or 0)) >= MOVE_COMMAND_INTERVAL then
		state.lastMoveDestination = destination
		state.lastMoveTime = now
		humanoid:MoveTo(destination)
	end
end

task.spawn(function()
	while true do
		local now = tick()
		for model, state in pairs(activeEnemies) do
		if not model.Parent or not model.PrimaryPart then
			activeEnemies[model] = nil
			continue
		end

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end

		local hrp = model.PrimaryPart
		local archKey = model:GetAttribute("Archetype") or "Grunt"
		local arch = ENEMY_ARCHETYPES[archKey] or ENEMY_ARCHETYPES[DEFAULT_ARCHETYPE]
		local level = model:GetAttribute("EnemyLevel") or 1

		local distFromSpawn = (hrp.Position - state.spawnPos).Magnitude

		-- Field groups carry their own leash from the anchor contract so a region's
		-- roamers stay in their territory; arena enemies fall back to the archetype's.
		local leashDistance = model:GetAttribute("LeashRadius") or arch.leashDistance
		if distFromSpawn > leashDistance then
			state.mode = "RETURNING"
			state.targetChar = nil
			clearAlert(model)
			commandMove(state, humanoid, state.spawnPos, now)
		end

		if state.mode == "RETURNING" then
			if (hrp.Position - state.spawnPos).Magnitude < 4 then
				state.mode = "IDLE"
				state.nextPatrolTime = now + math.random(1, 3)
			else
				commandMove(state, humanoid, state.spawnPos, now)
			end

		elseif state.mode == "CHASE" then
			local targetHrp = state.targetChar and state.targetChar:FindFirstChild("HumanoidRootPart")
			local targetHumanoid = state.targetChar and state.targetChar:FindFirstChildOfClass("Humanoid")

			if not targetHrp or not targetHumanoid or targetHumanoid.Health <= 0 then
				state.mode = "IDLE"
				state.targetChar = nil
				clearAlert(model)
				state.nextPatrolTime = now + 1
			else
				local targetDist = (targetHrp.Position - hrp.Position).Magnitude
				if targetDist > arch.aggroRange * 1.5 then
					state.mode = "RETURNING"
					state.targetChar = nil
					clearAlert(model)
					commandMove(state, humanoid, state.spawnPos, now)
				elseif targetDist <= arch.attackReach then
					-- Pack rigs keep jostling around their slot between swings (constant motion); a rig
					-- already on its spot turns to face the target. Bosses stand their ground.
					local spot = if arch.boss then nil else slotPoint(state, targetHrp.Position, arch)
					local flat = (targetHrp.Position - hrp.Position) * Vector3.new(1, 0, 1)
					if spot and ((spot - hrp.Position) * Vector3.new(1, 0, 1)).Magnitude > 1.6 and not state.windingUp then
						commandMove(state, humanoid, spot, now)
					elseif flat.Magnitude > 0.1 and hrp.CFrame.LookVector:Dot(flat.Unit) < 0.85 then
						commandMove(state, humanoid, hrp.Position + flat.Unit * 0.3, now)
					else
						commandMove(state, humanoid, hrp.Position, now)
					end
					if now - state.lastAttackTime >= getAttackCooldown(arch) + state.nextSwingGap and not state.windingUp then
						state.lastAttackTime = now
						state.nextSwingGap = getAttackCooldown(arch) * CADENCE_JITTER * (math.random() * 2 - 1)
						state.windingUp = true
						if not arch.boss then
							state.slotAngle += (math.random() - 0.5) * 0.7
						end
						local target = state.targetChar
						noteAttacker(target, model, now)
						-- Every enemy telegraphs its swing; damage waits for the chop so a player
						-- who reads the raise can step out of reach.
						task.delay(swingWeapon(model, arch), function()
							state.windingUp = false
							local root = model.PrimaryPart
							local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
							if humanoid.Health > 0 and model.Parent and root and targetRoot
								and (targetRoot.Position - root.Position).Magnitude <= arch.attackReach + HIT_GRACE then
								applyEnemyDamageToPlayer(model, target, arch, level)
							end
						end)
					end
				else
					-- Run in toward the rig's own slot, so a pack fans out around the player.
					local spot = if arch.boss or targetDist > arch.attackReach * 2.5 then targetHrp.Position
						else slotPoint(state, targetHrp.Position, arch)
					commandMove(state, humanoid, spot, now)
				end
			end

		else
			if now >= (state.nextTargetScanTime or 0) then
				state.nextTargetScanTime = now + TARGET_SCAN_INTERVAL
				local _, pChar, pHrp = findNearestLivingPlayer(hrp.Position, arch.aggroRange)
				-- Refuse to acquire a target standing in the sanctuary, so enemies never
				-- line up on players who are shopping, questing or rebirthing.
				-- ...and only players they can actually see, so nothing aggroes through cliffs or walls.
				if pChar and pHrp and SafeHub.canEnemyAttack(hrp.Position, pHrp.Position)
					and CombatUtil.hasLineOfSight(hrp.Position, pHrp.Position, { model, pChar }) then
					state.mode = "CHASE"
					state.targetChar = pChar
					model:SetAttribute(ALERT_ATTRIBUTE, Workspace:GetServerTimeNow())
					callPack(model, pChar, now)
				end
			end
			if state.mode == "IDLE" then
				if now >= state.nextPatrolTime then
					state.nextPatrolTime = now + math.random(3, 6)
					local angle = math.random() * math.pi * 2
					local dist = math.random(3, arch.patrolRadius)
					local patrolTarget = state.spawnPos + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
					commandMove(state, humanoid, patrolTarget, now)
				end
			end
		end
	end
		task.wait(AI_TICK_INTERVAL)
	end
end)

local function spawnEnemy(config)
	local model, humanoid, hrp, arch, groundedPos = createEnemyRig(config.archetype, config.position, config.level, config.role)
	-- Carry the anchor contract's per-spawn metadata onto the rig: the leash keeps
	-- field groups in their territory, and Zone/Region let quest and drop systems ask
	-- the rig where it came from instead of inferring it from the archetype name.
	if config.leashRadius then
		model:SetAttribute("LeashRadius", config.leashRadius)
	end
	if config.zone then
		model:SetAttribute("Zone", config.zone)
	end
	if config.region then
		model:SetAttribute("Region", config.region)
	end
	if config.role then
		model:SetAttribute("SpawnRole", config.role)
	end
	if config.packId then
		model:SetAttribute("PackId", config.packId)
		model:SetAttribute("PackIndex", config.packIndex)
		model:SetAttribute("PackSize", config.packSize)
	end
	if config.role == "elite" then
		local head = model:FindFirstChild("Head")
		local tag = head and head:FindFirstChild("NameTag")
		local title = tag and tag:FindFirstChild("Title")
		if title then
			title.Text = "Elite " .. title.Text
			title.TextColor3 = Color3.fromRGB(255, 200, 90)
		end
	end
	startEnemyAI(model, humanoid, hrp, arch, groundedPos, config.level, function()
		-- A kill that PAID a sword brings its target back inside DROP_RESPAWN_DELAY instead of the
		-- usual wait, so the drop reveal ends with the next roll already standing there rather
		-- than on an empty floor. SwordDropSystem stamps DropPaid on the rig as it pays, which is
		-- a beat after this Died handler runs, so the flag is read after a short look-again.
		task.delay(0.25, function()
			local paid = model and model:GetAttribute("DropPaid") == true
			task.delay(math.max((paid and DROP_RESPAWN_DELAY or RESPAWN_DELAY) - 0.25, 0), function()
				spawnEnemy(config)
			end)
		end)
	end)
end

-- ==============================================================================
-- 5. PLAYER COMBAT & AUTO-ATTACK WIRING
-- ==============================================================================
local function attackEnemy(player, enemyModel)
	local humanoid = enemyModel:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local creatorTag = humanoid:FindFirstChild(CREATOR_TAG_NAME)
	if not creatorTag then
		creatorTag = Instance.new("ObjectValue")
		creatorTag.Name = CREATOR_TAG_NAME
		creatorTag.Parent = humanoid
	end
	creatorTag.Value = player

	local damage, isCrit = getPlayerAttackDamage(player)
	humanoid:TakeDamage(damage)

	-- Apply hitlag for unarmed attacks (use combo hit 1 duration)
	local attackerChar = player.Character
	if attackerChar then
		CombatUtil.applyHitlag(attackerChar, enemyModel, ComboConfig.HITLAG_DURATION[1])
	end
	local hitlagRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):FindFirstChild("HitlagEffect")
	if hitlagRemote then
		hitlagRemote:FireClient(player, ComboConfig.HITLAG_DURATION[1])
	end

	local char = player.Character
	local playerHrp = char and char:FindFirstChild("HumanoidRootPart")
	local knockback = (player:GetAttribute("SwordKnockbackBonus") or 0) + (player:GetAttribute("RebirthExtraKnockback") or 0)
	if playerHrp and knockback > 0 then
		local enemyHrp = enemyModel.PrimaryPart or enemyModel:FindFirstChild("HumanoidRootPart")
		if enemyHrp then
			local dir = (enemyHrp.Position - playerHrp.Position)
			dir = Vector3.new(dir.X, 0, dir.Z)
			dir = dir.Magnitude > 0.001 and dir.Unit or playerHrp.CFrame.LookVector
			local impulse = (dir * knockback + Vector3.new(0, knockback * 0.25, 0)) * math.max(1, enemyHrp.AssemblyMass)
			enemyHrp:ApplyImpulse(impulse)
		end
	end

	local root = enemyModel.PrimaryPart or enemyModel:FindFirstChild("HumanoidRootPart")
	if root then
		DAMAGE_EVENT:FireAllClients(root.Position, damage, isCrit and "crit" or "outgoing")
	end
end

local function findNearestEnemy(character, origin, maxRange)
	local best, bestDist = nil, maxRange or ATTACK_RANGE
	for _, enemy in ipairs(Workspace:GetChildren()) do
		if enemy:IsA("Model") and isEnemy(enemy) then
			local humanoid = enemy:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				local root = enemy.PrimaryPart or enemy:FindFirstChild("HumanoidRootPart")
				if root then
					local dist = (root.Position - origin).Magnitude
					if dist <= (maxRange or ATTACK_RANGE) and dist < bestDist
						and CombatUtil.hasLineOfSight(origin, root.Position, { character, enemy }) then
						best, bestDist = enemy, dist
					end
				end
			end
		end
	end
	return best
end

local function getAliveCharacter(player)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not hrp then
		return nil, nil
	end
	return character, hrp
end

local function hasEquippedTool(character)
	return character:FindFirstChildOfClass("Tool") ~= nil
end

-- EnemyAttack is deliberately the unarmed combat path. Equipped tools use
-- SwordSystem instead, so clients cannot combine both paths for extra damage.
local function tryUnarmedAttack(player)
	local character, hrp = getAliveCharacter(player)
	if not character or hasEquippedTool(character) then
		return
	end
	local now = tick()
	local last = playerCooldowns[player]
	if last and (now - last) < ATTACK_COOLDOWN then
		return
	end
	playerCooldowns[player] = now

	local rangeBonus = player:GetAttribute("SwordRangeBonus") or 0
	if typeof(rangeBonus) ~= "number" then rangeBonus = 0 end
	local enemy = findNearestEnemy(character, hrp.Position, ATTACK_RANGE + rangeBonus)
	if enemy then
		attackEnemy(player, enemy)
	end
end

ATTACK_REMOTE.OnServerEvent:Connect(tryUnarmedAttack)

Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player] = nil
	playerEnemyHitAt[player] = nil
	playerAttackers[player] = nil
end)

-- Spawn positions come from the anchor contract that also places the arenas and
-- gates, so enemies cannot end up buried, floating, or inside the sanctuary.
local spawnConfigs = WorldLayout.GetEnemySpawns()

local spawned, skipped = 0, 0
for _, cfg in ipairs(spawnConfigs) do
	-- Belt and braces: the contract keeps every spawn well outside the safe radius,
	-- but a bad edit should drop the spawn rather than put an enemy in the hub.
	if SafeHub.contains(cfg.position) then
		warn(string.format("[EnemyCombat] Skipped %s spawn inside the sanctuary at %s",
			tostring(cfg.archetype), tostring(cfg.position)))
		skipped += 1
	else
		spawnEnemy(cfg)
		spawned += 1
	end
end

print(string.format("[EnemyCombat] %d enemies across %d arenas and %d field groups (%d skipped) | world: %s",
	spawned, #WorldLayout.ZONES, #WorldLayout.FIELD_SPAWNS, skipped,
	WorldLayout.MODE or (WorldLayout.IsImportedMap() and "imported" or "fallback")))

-- ==============================================================================
-- 6. STUDIO-ONLY MOTION SHOWCASES (see GuiShowcase.stage; inert outside Studio)
-- ==============================================================================
-- Enemy motion captures share one stage: an empty stretch of baseplate west of the map, well
-- clear of every spawn, with the player's character standing in reach of one enemy and a fixed
-- side-on, three-quarter camera. The enemy is a normal rig from createEnemyRig; its AI is only
-- started (startEnemyAI, exactly as in real play) once the clapperboard has fired, so nothing
-- moves before the strip's clock starts. The enemy has no respawn and is destroyed afterwards.
local SHOWCASE_STAGE = Vector3.new(-400, 0, 150) -- [TUNING] open baseplate, far from all spawns
local SHOWCASE_GAP = 4.8 -- studs between the enemy's root and the player's (inside every reach)

-- `gap` (optional) puts the enemy further off along the same line, for motions that need room.
local function stageEnemy(ctx, archetypeKey, gap)
	gap = gap or SHOWCASE_GAP
	local ground = resolveGroundPosition(SHOWCASE_STAGE)
	local enemyAt = ground + Vector3.new(-gap / 2, 0, 0)
	local playerAt = ground + Vector3.new(gap / 2, 0, 0)
	ctx.place(CFrame.lookAt(playerAt + Vector3.new(0, 3, 0), enemyAt + Vector3.new(0, 3, 0)))
	local model, humanoid, hrp, arch, groundedPos = createEnemyRig(archetypeKey, enemyAt, 1)
	ctx.track(model)
	model:PivotTo(CFrame.lookAt(hrp.Position, Vector3.new(playerAt.X, hrp.Position.Y, playerAt.Z)))
	-- Side-on from the enemy's sword arm (its right, +Z), above its shoulder, aimed between the two
	-- fighters so the enemy stands left of the hotbar and its legs stay in view.
	local focus = hrp.Position + Vector3.new(2.2, 0.6 * arch.scale, 0)
	ctx.camera(CFrame.lookAt(focus + Vector3.new(2.6, 1.9, 9.4), focus))
	local stage = { model = model, humanoid = humanoid, hrp = hrp, arch = arch }
	-- Hand the rig to the real AI. With a target it starts chasing, which in reach means attacking.
	function stage.wake(target)
		startEnemyAI(model, humanoid, hrp, arch, groundedPos, 1, nil)
		local state = activeEnemies[model]
		if state and target then
			state.mode = "CHASE"
			state.targetChar = target
		end
	end
	-- Give the rig its real death handling (startEnemyAI's Died handler: the sound and the cleanup)
	-- while keeping it out of the AI loop, so it stands at guard and never attacks. No respawn.
	function stage.armDeath()
		startEnemyAI(model, humanoid, hrp, arch, groundedPos, 1, nil)
		activeEnemies[model] = nil
	end
	-- Hand the rig to the real AI with no target, so it idles and scans exactly as in play, but
	-- hold off its idle wander so it stands still for the shot.
	function stage.wakeIdle()
		stage.wake(nil)
		local state = activeEnemies[model]
		if state then
			state.nextPatrolTime = math.huge
		end
	end
	return stage
end

-- An upper bound on one of this player's sword hits (combo, crit and a margin folded in), so a
-- staged enemy can be given health that one swing can never take to zero.
local function showcaseHitBound(p: Player): number
	return (30 + 5 * (p:GetAttribute("Strength") or 0)) * (p:GetAttribute("SwordDamageMult") or 1)
		* (1 + (p:GetAttribute("SwordBonusDamagePct") or 0)) * (p:GetAttribute("RebirthDamageMult") or 1)
		* (1 + 0.12 * (p:GetAttribute("WeaponLevel") or 0)) * 4
end

GuiShowcase.stage("EnemyAttack", function(ctx)
	local stage = stageEnemy(ctx, DEFAULT_ARCHETYPE) -- Quarry Cutthroat with the falchion
	task.wait(2.5) -- rig and camera settle
	ctx.clapper()
	stage.wake(ctx.character)
	task.wait(8)
end)

-- Enemy run: one enemy wakes 22 studs from the player (inside its aggro range, well inside its
-- leash) and the real AI chases across the frame to arrive and attack. The camera is fixed
-- side-on and wide, low enough to see the feet against the ground, so stride and foot plant read.
local RUN_GAP = 22 -- [TUNING] studs between the enemy's root and the player's at the start

GuiShowcase.stage("EnemyRun", function(ctx)
	local stage = stageEnemy(ctx, DEFAULT_ARCHETYPE, RUN_GAP)
	-- Centred on the enemy's path (start to arrival), close enough that the body is large, level
	-- with the hips and a little above so the feet read against the ground grid.
	local focus = SHOWCASE_STAGE * Vector3.new(1, 0, 1) + Vector3.new(-3, stage.hrp.Position.Y - 0.9, 0)
	ctx.camera(CFrame.lookAt(focus + Vector3.new(0, 1.0, 8.2), focus))
	task.wait(2.5) -- rig and camera settle
	ctx.clapper()
	stage.wake(ctx.character)
	task.wait(6)
end)

-- Enemy hit reaction: the player's real sword swing lands on one staged enemy, side-on so the
-- knockback reads across the screen. The enemy is not handed to the AI (it stands at guard, the
-- way a hit enemy looks in play, without an attack muddying the reaction) and its health is
-- raised well above one hit, so it survives: nothing dies, so no XP, gold, drop or quest credit.
GuiShowcase.stage("EnemyHit", function(ctx)
	local stage = stageEnemy(ctx, DEFAULT_ARCHETYPE)
	local health = math.max(stage.humanoid.MaxHealth, math.ceil(showcaseHitBound(ctx.player) * 10))
	stage.humanoid.MaxHealth = health
	stage.humanoid.Health = health
	ctx.equipSword()
	-- Side-on, level with the enemy's chest, framing it large with the player's blade coming in.
	local focus = stage.hrp.Position + Vector3.new(0.9, 0.2 * stage.arch.scale, 0)
	ctx.camera(CFrame.lookAt(focus + Vector3.new(0.6, 1.2, 10.5), focus))
	task.wait(2.5) -- rig, sword and camera settle
	ctx.clapper()
	ctx.swing()
	task.wait(4)
end)

-- Enemy death: the player's real sword swing lands on a staged enemy with low remaining health,
-- and the server finishes it the instant that hit registers, so the swing reads as the killing
-- blow and the death plays through the real Died handler, seen by every client. REWARD SAFETY:
-- the remaining health is above any single hit, so the swing itself can never kill (and so never
-- kills with the player's "creator" tag on it); the finishing damage destroys every "creator"
-- tag first, so XP, gold, sword drops and quest progress (all keyed off that tag) never fire.
-- What a kill could pay out, for the showcase's reward-safety log (before and after the kill).
local function showcaseRewards(p: Player): string
	local stats = p:FindFirstChild("leaderstats")
	local function stat(name)
		local v = stats and stats:FindFirstChild(name)
		return v and v.Value
	end
	local tools = 0
	for _, holder in ipairs({ p:FindFirstChildOfClass("Backpack"), p.Character }) do
		for _, item in ipairs(holder and holder:GetChildren() or {}) do
			if item:IsA("Tool") then
				tools += 1
			end
		end
	end
	return string.format("Level=%s XP=%s Gold=%s tools=%d quest=%s/%s", tostring(stat("Level")),
		tostring(stat("Experience")), tostring(stat("Gold")), tools, tostring(p:GetAttribute("ActiveQuestId")),
		tostring(p:GetAttribute("QuestProgress")))
end

GuiShowcase.stage("EnemyDeath", function(ctx)
	local stage = stageEnemy(ctx, DEFAULT_ARCHETYPE)
	local humanoid = stage.humanoid
	stage.armDeath()
	local bound = math.ceil(showcaseHitBound(ctx.player))
	humanoid.MaxHealth = math.max(humanoid.MaxHealth, bound * 5)
	humanoid.Health = bound
	ctx.equipSword()
	-- Side-on and wider than the hit, centred behind the enemy (it falls away from the blade, to
	-- screen left) and looking a little down, so the swing, the fall and the body on the ground
	-- all stay in frame.
	local s = stage.arch.scale
	local focus = stage.hrp.Position + Vector3.new(-1.1, -1.5 * s, 0)
	ctx.camera(CFrame.lookAt(focus + Vector3.new(0.4, 3.4, 10.5), focus))
	task.wait(2.5) -- rig, sword and camera settle
	print("[GuiShowcase] EnemyDeath rewards before: " .. showcaseRewards(ctx.player))
	local before = humanoid.Health
	local finisher
	finisher = humanoid.HealthChanged:Connect(function(health)
		if health > 0 and health < before - 0.01 then
			finisher:Disconnect()
			for _, child in ipairs(humanoid:GetChildren()) do
				if child.Name == CREATOR_TAG_NAME then
					child:Destroy()
				end
			end
			humanoid.Health = 0
		end
	end)
	ctx.clapper()
	ctx.swing()
	task.wait(5)
	finisher:Disconnect()
	print("[GuiShowcase] EnemyDeath rewards after: " .. showcaseRewards(ctx.player))
end)

-- Token drop: a pack of ordinary enemies stands in the player's sword reach on the open stage
-- and ONE real sword swing (SwordSystem's hitbox, damage and "creator" tag) kills the lot, so
-- every body goes down through the shipped Died handlers and SwordDropSystem pays each kill's
-- spin tokens exactly as in play: TokenRules' real roll, the saved Tokens attribute, the TokenDrop
-- remote and the client burst, magnet and HUD counter. Nothing is forced; the only staging is
-- where the rigs stand, that their AI is held (they stand at guard) and their health is set to 1
-- so the single swing is the killing blow for all of them. One of the pack is an elite (a bigger
-- burst). The camera is a fixed third-person shot from behind the player, and the whole HUD stays
-- up (TokenDrops.client marks it kept for this stage only), because the counter is the subject.
-- Saves are refused for the whole session while the showcase attribute is set (PlayerDataService),
-- so the tokens, gold and XP die with the Play session.
-- { angle (degrees off the player's facing), distance, role }: an arc at one radius, spread wide
-- enough that no rig stands between the player and another (the swing checks line of sight).
local TOKEN_PACK = { -- [TUNING]
	{ -44, 3.3, nil },
	{ 0, 3.4, "elite" },
	{ 44, 3.3, nil },
}

GuiShowcase.stage("TokenDrop", function(ctx)
	local ground = resolveGroundPosition(SHOWCASE_STAGE)
	local forward, side = Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1)
	-- A fresh Studio profile is level 1, and three kills would level it up mid-shot: the level-up
	-- confetti would bury the tokens. Lift this session's level (never saved, see above) so the
	-- kills' XP stays under the next level and the drop is the only thing on screen.
	local stats = ctx.player:FindFirstChild("leaderstats")
	local levelValue = stats and stats:FindFirstChild("Level")
	local xpValue = stats and stats:FindFirstChild("Experience")
	if levelValue and levelValue.Value < 12 then
		levelValue.Value = 12
		if xpValue then xpValue.Value = 0 end
	end
	ctx.place(CFrame.lookAt(ground + Vector3.new(0, 3, 0), ground + forward * 10 + Vector3.new(0, 3, 0)))
	local pack = {}
	for _, spot in ipairs(TOKEN_PACK) do
		local a = math.rad(spot[1])
		local at = ground + (forward * math.cos(a) + side * math.sin(a)) * spot[2]
		local model, humanoid, hrp, arch, groundedPos = createEnemyRig(DEFAULT_ARCHETYPE, at, 1, spot[3])
		ctx.track(model)
		model:SetAttribute("Zone", "IronLowlands")
		if spot[3] then
			model:SetAttribute("SpawnRole", spot[3])
		end
		model:PivotTo(CFrame.lookAt(hrp.Position, Vector3.new(ground.X, hrp.Position.Y, ground.Z)))
		-- The real death handling (sound, collapse, cleanup) without the AI loop.
		startEnemyAI(model, humanoid, hrp, arch, groundedPos, 1, nil)
		activeEnemies[model] = nil
		humanoid.MaxHealth = math.max(humanoid.MaxHealth, math.ceil(showcaseHitBound(ctx.player)) * 5)
		humanoid.Health = 1
		table.insert(pack, model)
	end
	ctx.equipSword()
	-- Behind and above the player's right shoulder, looking past them into the pack, wide enough
	-- that the burst, the pickups streaming back and the bottom-left counter share the frame.
	local focus = ground + forward * 2.6 + Vector3.new(0, 0.6, 0)
	ctx.camera(CFrame.lookAt(ground - forward * 9 + side * 2.4 + Vector3.new(0, 6.4, 0), focus))
	task.wait(2.5) -- rigs, sword and camera settle
	print("[GuiShowcase] TokenDrop before: Tokens=" .. tostring(ctx.player:GetAttribute("Tokens")) .. " " .. showcaseRewards(ctx.player))
	ctx.clapper()
	ctx.swing()
	task.wait(6) -- the kills, the burst, the magnet, the flights and the counter settling
	local dead = 0
	for _, model in ipairs(pack) do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not model.Parent or (humanoid and humanoid.Health <= 0) then dead += 1 end
	end
	print(string.format("[GuiShowcase] TokenDrop after: %d/%d killed, Tokens=%s %s", dead, #pack,
		tostring(ctx.player:GetAttribute("Tokens")), showcaseRewards(ctx.player)))
end)

-- Combat packs: a real camp of five Quarry Cutthroats (one pack, PackId stamped exactly as
-- WorldLayout's spawns stamp it) stands eight studs ahead of the player on the open stage. The
-- real AI does everything after the clapperboard: one rig spots the player, calls its pack
-- (callPack), they fan out onto their slots around the player and swing at pack cadence, each hit
-- running applyEnemyDamageToPlayer with the crowd share and the shipped DamageNumber remote. The
-- player swings the real sword every half second at the nearest rig (turning to face it), so hits
-- land both ways and kills pay tokens through the shipped Died path. Studio-only staging: the rigs'
-- spots, the session level lifted to 40 (so level-up confetti stays out of the shot) and the
-- session MaxHealth raised to 400 so the character outlives the whole take. Nothing is saved
-- (PlayerDataService refuses saves while the showcase attribute is set). The measured hit rate,
-- damage per hit and DPS taken are printed to the output.
local PACK_STAGE_SIZE = 5 -- [TUNING]
local PACK_STAGE_LEVEL = 6 -- deep enough in the Lowlands that the camp survives a few seconds of swings
local PACK_STAGE_HEALTH = 400

GuiShowcase.stage("CombatPacks", function(ctx)
	local ground = resolveGroundPosition(SHOWCASE_STAGE)
	local forward, side = Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1)
	local stats = ctx.player:FindFirstChild("leaderstats")
	local levelValue = stats and stats:FindFirstChild("Level")
	local xpValue = stats and stats:FindFirstChild("Experience")
	if levelValue and levelValue.Value < 40 then
		levelValue.Value = 40
		if xpValue then xpValue.Value = 0 end
	end
	ctx.place(CFrame.lookAt(ground + Vector3.new(0, 3, 0), ground + forward * 10 + Vector3.new(0, 3, 0)))
	local humanoid = ctx.character:FindFirstChildOfClass("Humanoid")
	task.wait(0.5)
	if humanoid then
		humanoid.MaxHealth = PACK_STAGE_HEALTH
		humanoid.Health = PACK_STAGE_HEALTH
	end
	local center = ground + forward * 8.5
	local pack = {}
	for index = 1, PACK_STAGE_SIZE do
		local a = (index - 1) * 2 * math.pi / PACK_STAGE_SIZE
		local at = center + (forward * math.cos(a) + side * math.sin(a)) * 3.6
		local model, rigHumanoid, hrp, arch, groundedPos = createEnemyRig(DEFAULT_ARCHETYPE, at, PACK_STAGE_LEVEL, "minion")
		ctx.track(model)
		model:SetAttribute("Zone", "IronLowlands")
		model:SetAttribute("SpawnRole", "minion")
		model:SetAttribute("PackId", "ShowcasePack")
		model:SetAttribute("PackIndex", index)
		model:SetAttribute("PackSize", PACK_STAGE_SIZE)
		model:PivotTo(CFrame.lookAt(hrp.Position, hrp.Position + forward:Cross(Vector3.yAxis) * (index % 2 == 0 and 1 or -1)))
		table.insert(pack, { model = model, humanoid = rigHumanoid, hrp = hrp, arch = arch, groundedPos = groundedPos })
	end
	ctx.equipSword()
	-- High behind the player's shoulder, looking down past them into the camp, wide enough that
	-- the whole crowd stays in frame once it closes around the player.
	local focus = ground + forward * 2.5 + Vector3.new(0, 1.2, 0)
	ctx.camera(CFrame.lookAt(ground - forward * 7.5 + side * 2.2 + Vector3.new(0, 6.8, 0), focus))
	task.wait(2.5)
	ctx.clapper()
	-- Hand the camp to the real AI: idle, scanning, exactly as a field spawn. The first rig's scan
	-- finds the player (inside its 24-stud aggro range) and calls the rest.
	for _, rig in ipairs(pack) do
		startEnemyAI(rig.model, rig.humanoid, rig.hrp, rig.arch, rig.groundedPos, PACK_STAGE_LEVEL, nil)
		local state = activeEnemies[rig.model]
		if state then state.nextPatrolTime = math.huge end
	end
	-- Measure what the player takes: every health drop is one landed enemy hit.
	-- Only drops while 4+ rigs are on the player count (the crowd the piece is judged on), and a drop
	-- bigger than any pack hit (a MaxHealth reset) is ignored.
	local hits, taken, firstHit, lastHit = 0, 0, nil, nil
	local maxCrowd = 0
	local lastHealth = humanoid and humanoid.Health or 0
	local conn = humanoid and humanoid.HealthChanged:Connect(function(h)
		local drop = lastHealth - h
		lastHealth = h
		if drop > 0.01 and drop < 40 then
			local crowd = countAttackers(ctx.player, tick())
			maxCrowd = math.max(maxCrowd, crowd)
			if crowd >= 4 then
				hits += 1
				taken += drop
				firstHit = firstHit or os.clock()
				lastHit = os.clock()
			end
		end
	end)
	local swings = 0
	for _, rig in ipairs(pack) do
		rig.model:GetAttributeChangedSignal(ATTACK_ATTRIBUTE):Connect(function()
			swings += 1
		end)
	end
	local root = ctx.root
	local stopAt = os.clock() + 24
	while os.clock() < stopAt do
		local nearest, best = nil, math.huge
		for _, rig in ipairs(pack) do
			if rig.model.Parent and rig.humanoid.Health > 0 then
				local d = (rig.hrp.Position - root.Position).Magnitude
				if d < best then nearest, best = rig, d end
			end
		end
		if nearest and best < 9 then
			local look = (nearest.hrp.Position - root.Position) * Vector3.new(1, 0, 1)
			if look.Magnitude > 0.1 then
				ctx.place(CFrame.lookAt(root.Position, root.Position + look))
			end
			ctx.swing()
		end
		task.wait(0.5)
		if firstHit and lastHit and lastHit > firstHit then
			-- Readable from Studio's command bar during play (the play session's output is not kept).
			workspace:SetAttribute("GuiShowcaseStats", string.format("hits %d in %.1fs, %.2f dmg/hit, crowd %d, swings %d",
				hits, lastHit - firstHit, taken / hits, maxCrowd, swings))
		end
	end
	if conn then conn:Disconnect() end
	local span = (firstHit and lastHit and lastHit > firstHit) and (lastHit - firstHit) or 1
	local dead = 0
	for _, rig in ipairs(pack) do
		if not rig.model.Parent or rig.humanoid.Health <= 0 then dead += 1 end
	end
	print(string.format("[GuiShowcase] CombatPacks: pack %d, hits taken (4+ on the player) %d over %.1fs = %.2f hits/s, avg %.2f dmg/hit, %.1f DPS taken, max crowd %d, %d enemy swings total, %d/%d rigs killed",
		PACK_STAGE_SIZE, hits, span, hits / span, hits > 0 and taken / hits or 0, taken / span, maxCrowd, swings, dead, #pack))
end)

-- Enemy notice: one enemy stands idle side-on to the player, who stands just outside its aggro
-- range and then walks in on their own legs (ctx.walkTo, a real Humanoid:MoveTo). The real AI
-- scan spots them and turns the enemy into its chase: nothing forces the mode or the target.
-- The enemy's idle wander is held off only so it stands still for the shot. The camera is fixed
-- in front of the enemy's left shoulder, so its face reads both before the turn (three-quarter)
-- and after it (facing the player, off screen to the right, behind the camera's side).
local NOTICE_START = 28 -- [TUNING] studs apart at the start: outside the Cutthroat's 24 aggro range
local NOTICE_STOP = 19 -- [TUNING] studs apart where the player stops: well inside it

GuiShowcase.stage("EnemyNotice", function(ctx)
	local stage = stageEnemy(ctx, DEFAULT_ARCHETYPE, NOTICE_START)
	local hrp = stage.hrp
	-- Side-on: facing +Z, so the player (at +X) is on its left and must be turned to.
	stage.model:PivotTo(CFrame.lookAt(hrp.Position, hrp.Position + Vector3.new(0, 0, 1)))
	local s = stage.arch.scale
	-- Framed with room above the head for the lemon "!" the notice pops.
	local focus = hrp.Position + Vector3.new(1.4, 0.8 * s, 0)
	ctx.camera(CFrame.lookAt(focus + Vector3.new(3.6, 1.7, 8.0), focus))
	stage.wakeIdle()
	task.wait(2.5) -- rig and camera settle
	ctx.clapper()
	ctx.walkTo(Vector3.new(hrp.Position.X + NOTICE_STOP, ctx.root.Position.Y, hrp.Position.Z))
	task.wait(6)
end)

-- Enemy idle: one enemy stands unaware, the player far outside its aggro range (behind the
-- camera), and the real AI idles it with the wander held off. The camera is a fixed, close
-- three-quarter view from the enemy's front right (its sword side), level with the chest, so
-- breathing, weight shifts, head glances and weapon fidgets all read. Long enough to catch
-- several breaths and glances.
local IDLE_GAP = 70 -- [TUNING] studs apart: far outside every archetype's aggro range

GuiShowcase.stage("EnemyIdle", function(ctx)
	local stage = stageEnemy(ctx, DEFAULT_ARCHETYPE, IDLE_GAP)
	local s = stage.arch.scale
	-- Head to feet in view, so the hips' weight shift reads against the planted feet.
	local focus = stage.hrp.Position + Vector3.new(0, -0.55 * s, 0)
	ctx.camera(CFrame.lookAt(focus + Vector3.new(6.6, 1.1 * s, 4.6), focus))
	stage.wakeIdle()
	task.wait(1.5) -- rig and camera settle
	-- The client's idle schedules a grip adjust (weight onto the sword leg, the chest turning, the
	-- head following it, then the arm, forearm and wrist) over a rising breath, IDLE_CUE_AT seconds
	-- after this change reaches it: it rides the same replication stream as the clapperboard one
	-- second later, so the beat starts just after the flash, inside the strip. Everything after is
	-- random. Presentation only: EnemyAnimator reads it, nothing on the server does.
	local IDLE_CUE_LEAD = 1.0
	local IDLE_CUE_AT = IDLE_CUE_LEAD + 0.3
	stage.model:SetAttribute("EnemyIdleCue", IDLE_CUE_AT)
	task.wait(IDLE_CUE_LEAD)
	ctx.clapper()
	task.wait(20)
end)
