local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local CombatUtil = require(script.Parent:WaitForChild("CombatUtil"))
local WorldLayout = require(script.Parent:WaitForChild("WorldLayout"))
local SafeHub = require(script.Parent:WaitForChild("SafeHub"))
local ComboConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ComboConfig"))
local AudioManager = require(ReplicatedStorage:WaitForChild("AudioManager"))
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
local ENEMY_HIT_INTERVAL_PER_PLAYER = 0.7 -- prevents several enemies landing damage on one frame
local ATTACK_COOLDOWN = 0.4
local RESPAWN_DELAY = 5
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
local TOGGLE_REMOTE = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("ToggleAutoAttack")
local DAMAGE_EVENT = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("DamageNumber")

local playerCooldowns = {}
local playerEnemyHitAt = {}
local autoAttackState = {} -- [player] = bool (auto-attack on/off)

-- ==============================================================================
-- 1. ENEMY & BOSS ARCHETYPES CONFIGURATION
-- ==============================================================================
local ENEMY_ARCHETYPES = {
	-- 1. Iron Warlord Minions (South-West Courtyard, Lv 4-8)
	IronSquire = {
		name = "Iron Vanguard",
		color = Color3.fromRGB(150, 65, 75),
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
	},
	IronBerserker = {
		name = "Iron Crusher",
		color = Color3.fromRGB(110, 35, 45),
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
	},

	-- 2. Frost Revenant Minions (North-West Permafrost Glade, Lv 15-20)
	FrostImp = {
		name = "Frost Stalker",
		color = Color3.fromRGB(90, 160, 220),
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
		color = Color3.fromRGB(30, 95, 160),
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
		color = Color3.fromRGB(240, 100, 30),
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
		color = Color3.fromRGB(180, 50, 15),
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
		color = Color3.fromRGB(130, 50, 190),
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
		color = Color3.fromRGB(65, 20, 110),
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
		color = Color3.fromRGB(255, 220, 90),
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
		color = Color3.fromRGB(220, 160, 30),
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
		name = "Thorn Stalker", color = Color3.fromRGB(120, 150, 60), scale = 1.0, walkSpeed = 15,
		baseHealth = 203, healthGrowth = 1.23, baseDamage = 21, damageGrowth = 1.14, baseXP = 170,
		aggroRange = 26, attackReach = 6.0, attackCooldown = 1.2, patrolRadius = 14, leashDistance = 38,
	},
	BriarBrute = {
		name = "Briar Brute", color = Color3.fromRGB(85, 105, 45), scale = 1.35, walkSpeed = 11,
		baseHealth = 377, healthGrowth = 1.23, baseDamage = 32, damageGrowth = 1.14, baseXP = 240,
		aggroRange = 23, attackReach = 7.5, attackCooldown = 1.7, patrolRadius = 10, leashDistance = 34,
	},
	RootWarden = {
		name = "Rootbound Warden", title = "Keeper of the Grove", color = Color3.fromRGB(60, 80, 35),
		scale = 1.6, walkSpeed = 11.5, baseHealth = 724, healthGrowth = 1.23, baseDamage = 42,
		damageGrowth = 1.14, baseXP = 450, aggroRange = 30, attackReach = 9.0, attackCooldown = 1.6,
		patrolRadius = 10, leashDistance = 45, nameTag = true, tagColor = Color3.fromRGB(170, 220, 90),
	},
	BogLurker = {
		name = "Bog Lurker", color = Color3.fromRGB(80, 110, 90), scale = 1.05, walkSpeed = 14.5,
		baseHealth = 1030, healthGrowth = 1.26, baseDamage = 50, damageGrowth = 1.17, baseXP = 750,
		aggroRange = 27, attackReach = 6.5, attackCooldown = 1.2, patrolRadius = 14, leashDistance = 40,
	},
	MireHulk = {
		name = "Mire Hulk", color = Color3.fromRGB(55, 75, 60), scale = 1.45, walkSpeed = 10.5,
		baseHealth = 1915, healthGrowth = 1.26, baseDamage = 74, damageGrowth = 1.17, baseXP = 950,
		aggroRange = 24, attackReach = 8.0, attackCooldown = 1.8, patrolRadius = 11, leashDistance = 36,
	},
	DrownedBellwarden = {
		name = "Drowned Bellwarden", title = "Toller of the Sunken Bell", color = Color3.fromRGB(40, 60, 70),
		scale = 1.65, walkSpeed = 12, baseHealth = 3685, healthGrowth = 1.26, baseDamage = 99,
		damageGrowth = 1.17, baseXP = 1600, aggroRange = 32, attackReach = 9.5, attackCooldown = 1.6,
		patrolRadius = 10, leashDistance = 48, nameTag = true, tagColor = Color3.fromRGB(120, 210, 170),
	},
	Stormcaller = {
		name = "Stormcaller", color = Color3.fromRGB(110, 130, 175), scale = 1.1, walkSpeed = 17,
		baseHealth = 2750, healthGrowth = 1.31, baseDamage = 95, damageGrowth = 1.20, baseXP = 2800,
		aggroRange = 32, attackReach = 7.0, attackCooldown = 1.0, patrolRadius = 16, leashDistance = 44,
	},
	ThunderConstruct = {
		name = "Thunder Construct", color = Color3.fromRGB(70, 85, 120), scale = 1.5, walkSpeed = 12,
		baseHealth = 5100, healthGrowth = 1.31, baseDamage = 143, damageGrowth = 1.20, baseXP = 3500,
		aggroRange = 27, attackReach = 9.0, attackCooldown = 1.6, patrolRadius = 13, leashDistance = 40,
	},
	TempestWarden = {
		name = "Tempest Warden", title = "Keeper of the Observatory", color = Color3.fromRGB(50, 60, 95),
		scale = 1.7, walkSpeed = 13, baseHealth = 9800, healthGrowth = 1.31, baseDamage = 190,
		damageGrowth = 1.20, baseXP = 5500, aggroRange = 34, attackReach = 10.0, attackCooldown = 1.5,
		patrolRadius = 12, leashDistance = 50, nameTag = true, tagColor = Color3.fromRGB(130, 190, 255),
	},

	-- 5 UNIQUE SPREAD-OUT PROGRESSIVE BOSSES (High-Level & High-Stakes)
	Boss_Gorgon = {
		name = "Iron Warlord",
		title = "Warlord of Iron",
		color = Color3.fromRGB(130, 45, 55),
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
		swordColor = Color3.fromRGB(180, 50, 50),
		swordMaterial = Enum.Material.Metal,
		nameTag = true,
		tagColor = Color3.fromRGB(255, 90, 90),
	},
	Boss_FrostRevenant = {
		name = "Frost Revenant",
		title = "Lord of the Permafrost",
		color = Color3.fromRGB(45, 120, 185),
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
		color = Color3.fromRGB(215, 75, 20),
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
		color = Color3.fromRGB(90, 35, 145),
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
		color = Color3.fromRGB(240, 190, 50),
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

local function createEnemyRig(archetypeKey, spawnPosition, level)
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
	local textureSet = textureSetName and TEXTURE_SETS[textureSetName]
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
	local rightShoulder = createMotor6D("Right Shoulder", torso, torso, rightArm, CFrame.new(1 * s, 0.5 * s, 0), CFrame.new(-0.5 * s, 0.5 * s, 0))
	rightShoulder:SetAttribute("BaseC0", rightShoulder.C0)
	createMotor6D("Left Hip", torso, torso, leftLeg, CFrame.new(-0.5 * s, -1 * s, 0), CFrame.new(0, 1 * s, 0))
	createMotor6D("Right Hip", torso, torso, rightLeg, CFrame.new(0.5 * s, -1 * s, 0), CFrame.new(0, 1 * s, 0))

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

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = rightArm
			weld.Part1 = sword
			weld.Parent = sword
		end
	end

	-- Humanoid setup
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.WalkSpeed = arch.walkSpeed
	humanoid.Parent = model

	local maxHp = getEnemyMaxHealth(arch, level)
	humanoid.MaxHealth = maxHp
	humanoid.Health = maxHp

	-- Boss nameplate & dynamic health bar
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
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 16
		lbl.TextColor3 = arch.tagColor or Color3.fromRGB(255, 90, 90)
		lbl.TextStrokeTransparency = 0.2
		lbl.TextStrokeColor3 = Color3.fromRGB(10, 10, 15)
		lbl.Text = string.format("☠ %s  [Lv %d]", arch.name, level)
		lbl.Parent = bb

		-- Health bar background
		local hpBg = Instance.new("Frame")
		hpBg.Size = UDim2.new(1, 0, 0, 10)
		hpBg.Position = UDim2.fromOffset(0, 26)
		hpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		hpBg.BorderSizePixel = 0
		hpBg.Parent = bb
		local hpCorner = Instance.new("UICorner", hpBg)
		hpCorner.CornerRadius = UDim.new(0, 5)
		local hpStroke = Instance.new("UIStroke", hpBg)
		hpStroke.Color = Color3.fromRGB(45, 45, 55)
		hpStroke.Thickness = 1

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
		hpText.Font = Enum.Font.GothamMedium
		hpText.TextSize = 11
		hpText.TextColor3 = Color3.fromRGB(210, 210, 220)
		hpText.TextStrokeTransparency = 0.4
		hpText.TextStrokeColor3 = Color3.fromRGB(10, 10, 15)
		hpText.Text = string.format("%d / %d", humanoid.Health, humanoid.MaxHealth)
		hpText.Parent = bb

		humanoid.HealthChanged:Connect(function(newHp)
			local ratio = math.clamp(newHp / humanoid.MaxHealth, 0, 1)
			TweenService:Create(hpFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(ratio, 0, 1, 0)
			}):Play()
			hpText.Text = string.format("%d / %d", math.max(0, math.floor(newHp)), humanoid.MaxHealth)
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

local function applyEnemyDamageToPlayer(enemyModel, playerChar, arch, level)
	local humanoid = playerChar:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local enemyRoot = enemyModel.PrimaryPart or enemyModel:FindFirstChild("HumanoidRootPart")
	local playerRoot = playerChar:FindFirstChild("HumanoidRootPart")
	if not enemyRoot or not playerRoot
		or not CombatUtil.hasLineOfSight(enemyRoot.Position, playerRoot.Position, { enemyModel, playerChar }) then
		return
	end
	-- The sanctuary is a hard no-damage volume, enforced on the server at the point
	-- damage is applied. Geometry and spawn distance alone are not a permission check:
	-- a pulled enemy that reaches the boundary still must not land a hit.
	if not SafeHub.canEnemyAttack(enemyRoot.Position, playerRoot.Position) then
		return
	end

	local player = Players:GetPlayerFromCharacter(playerChar)
	if player then
		local now = tick()
		if now - (playerEnemyHitAt[player] or 0) < ENEMY_HIT_INTERVAL_PER_PLAYER then
			return
		end
		playerEnemyHitAt[player] = now
	end
	local defense = player and (player:GetAttribute("Defense") or 0) or 0
	local rawDamage = getEnemyDamage(arch, level)
	local reduction = math.min(defense * DEFENSE_PCT_PER_POINT, DEFENSE_MAX_REDUCTION)
	local finalDamage = math.max(1, math.floor(rawDamage * ENEMY_DAMAGE_MULTIPLIER * (1 - reduction) + 0.5))

	humanoid:TakeDamage(finalDamage)

	local hrp = playerChar:FindFirstChild("HumanoidRootPart")
	if hrp then
		DAMAGE_EVENT:FireAllClients(hrp.Position, finalDamage, "incoming")
	end
end

local function swingWeapon(model)
	local torso = model:FindFirstChild("Torso")
	local shoulder = torso and torso:FindFirstChild("Right Shoulder")
	if not (shoulder and shoulder:IsA("Motor6D")) then
		return
	end
	local base = shoulder:GetAttribute("BaseC0")
	if not base or shoulder:GetAttribute("Swinging") then
		return
	end
	shoulder:SetAttribute("Swinging", true)

	local raise = TweenService:Create(shoulder, TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ C0 = base * CFrame.Angles(math.rad(-120), 0, 0) })
	local chop = TweenService:Create(shoulder, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ C0 = base * CFrame.Angles(math.rad(35), 0, 0) })
	local recover = TweenService:Create(shoulder, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ C0 = base })

	raise:Play()
	raise.Completed:Once(function()
		chop:Play()
		chop.Completed:Once(function()
			recover:Play()
			recover.Completed:Once(function()
				shoulder:SetAttribute("Swinging", false)
			end)
		end)
	end)
end

local function startEnemyAI(model, humanoid, hrp, arch, spawnPos, level, onDeath)
	local state = {
		mode = "IDLE",
		spawnPos = spawnPos,
		nextPatrolTime = tick() + math.random(1, 3),
		lastAttackTime = 0,
		targetChar = nil,
	}
	activeEnemies[model] = state

	humanoid.Died:Connect(function()
		activeEnemies[model] = nil
		-- Play death sound
		local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
		if root then
			AudioManager.PlaySFX("enemy_death", root)
		end
		task.delay(0.2, function()
			if model and model.Parent then
				model:Destroy()
			end
		end)
		if onDeath then
			onDeath()
		end
	end)
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
				state.nextPatrolTime = now + 1
			else
				local targetDist = (targetHrp.Position - hrp.Position).Magnitude
				if targetDist > arch.aggroRange * 1.5 then
					state.mode = "RETURNING"
					state.targetChar = nil
					commandMove(state, humanoid, state.spawnPos, now)
				elseif targetDist <= arch.attackReach then
					commandMove(state, humanoid, hrp.Position, now)
					if now - state.lastAttackTime >= arch.attackCooldown then
						state.lastAttackTime = now
						-- Every enemy telegraphs its swing so the player can react before
						-- damage lands; boss weapons still use their distinct blade pose.
						swingWeapon(model)
						applyEnemyDamageToPlayer(model, state.targetChar, arch, level)
					end
				else
					commandMove(state, humanoid, targetHrp.Position, now)
				end
			end

		else
			if now >= (state.nextTargetScanTime or 0) then
				state.nextTargetScanTime = now + TARGET_SCAN_INTERVAL
				local _, pChar, pHrp = findNearestLivingPlayer(hrp.Position, arch.aggroRange)
				-- Refuse to acquire a target standing in the sanctuary, so enemies never
				-- line up on players who are shopping, questing or rebirthing.
				if pChar and pHrp and SafeHub.canEnemyAttack(hrp.Position, pHrp.Position) then
					state.mode = "CHASE"
					state.targetChar = pChar
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
	local model, humanoid, hrp, arch, groundedPos = createEnemyRig(config.archetype, config.position, config.level)
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
	startEnemyAI(model, humanoid, hrp, arch, groundedPos, config.level, function()
		task.delay(RESPAWN_DELAY, function()
			spawnEnemy(config)
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

TOGGLE_REMOTE.OnServerEvent:Connect(function(player, enabled)
	if enabled == nil then
		enabled = not autoAttackState[player]
	end
	autoAttackState[player] = enabled == true
	print(string.format("[EnemyCombat] %s auto-attack %s", player.Name, autoAttackState[player] and "ON" or "OFF"))
end)

task.spawn(function()
	while true do
		task.wait(ATTACK_COOLDOWN)
		for player, on in pairs(autoAttackState) do
			if on and player.Parent then
				-- Tool auto-attacks are driven by the equipped Tool's server script. This
				-- loop covers unarmed players only, avoiding a second hit every swing.
				tryUnarmedAttack(player)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player] = nil
	playerEnemyHitAt[player] = nil
	autoAttackState[player] = nil
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
	WorldLayout.IsImportedMap() and "imported" or "fallback"))
