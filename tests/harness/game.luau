--// tests/harness/game.luau  (the lemonade-graph server, booted headless)
-- Game.new() mounts default.project.json into a fresh harness world, lays down the baseplate the
-- default project plays on, and (optionally) runs real server Scripts. Players, characters and
-- enemy kills are made here the way the engine / EnemyCombat would make them, so a test drives
-- the shipped code through its real entry points (PlayerAdded, Humanoid.Died, remote events).
local World = require("./world")
local Project = require("./project")

local D = require("./datatypes")
local Vector3, CFrame = D.Vector3, D.CFrame

local Game = {}
Game.__index = Game

-- The repo root, found from the working directory tests/run.sh sets (the repo root).
Game.ROOT = "."

-- The server Scripts a full boot runs, in a safe order: RuntimeBootstrap first (it creates the
-- RemoteEvents every other script waits for), then persistence, then gameplay.
Game.SERVER_SCRIPTS = {
	"RuntimeBootstrap", "PlayerDataStore", "SwordDropSystem", "GameplayServices",
}

-- options.studio      RunService:IsStudio() (default false: a live server)
-- options.scripts     server Script names to run (default none; true = Game.SERVER_SCRIPTS)
-- options.baseplate   false to leave the workspace empty
-- options.templates   false to leave out the place's Studio-only ServerStorage templates (below)
function Game.new(options)
	options = options or {}
	local self = setmetatable({}, Game)
	local world = World.new({ studio = options.studio })
	self.world = world
	Project.mount(world, Game.ROOT, "default.project.json")
	if options.baseplate ~= false then
		-- Roblox's stock Baseplate template: 2048 x 16 x 2048, top face at y = 0.
		local plate = world:newInstance("Part")
		plate.Name = "Baseplate"
		plate.Size = Vector3.new(2048, 16, 2048)
		plate.CFrame = CFrame.new(0, -8, 0)
		plate.Anchored = true
		plate.Parent = world.workspace
	end
	if options.templates ~= false then
		-- The place file carries two server templates that are not in the Rojo source
		-- (GAME_ARCHITECTURE.md, "ServerStorage/  # Server-only templates (not in Rojo source)"):
		-- BossSwordTool, the Tool every boss / spin sword is cloned from, and SwordMeshTemplate, the
		-- shared blade mesh. Stand-ins with the same names and classes.
		local ServerStorage = world:service("ServerStorage")
		local tool = world:newInstance("Tool")
		tool.Name = "BossSwordTool"
		tool.RequiresHandle = true
		tool.CanBeDropped = false
		local handle = world:newInstance("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.3, 0.3, 1.1)
		handle.Parent = tool
		tool.Parent = ServerStorage
		local mesh = world:newInstance("MeshPart")
		mesh.Name = "SwordMeshTemplate"
		mesh.MeshId = "rbxassetid://harness-sword-mesh"
		mesh.Size = Vector3.new(0.4, 1, 4.2)
		mesh.MeshSize = Vector3.new(0.4, 1, 4.2)
		mesh.Parent = ServerStorage
	end
	local scripts = options.scripts
	if scripts == true then scripts = Game.SERVER_SCRIPTS end
	for _, name in ipairs(scripts or {}) do
		self:runScript(name)
	end
	return self
end

function Game:find(path) return self.world:find(path) end

function Game:module(path)
	return self.world:load(self.world:find(path))
end

function Game:runScript(name)
	local inst = self.world:find("ServerScriptService." .. name)
	self.world:runScript(inst)
	self.world:flush()
	return inst
end

function Game:remote(name)
	return self.world:find("ReplicatedStorage.RemoteEvents." .. name)
end

function Game:flush() self.world:flush() end
function Game:advance(seconds) self.world:advance(seconds) end

-- ---------------------------------------------------------------- players
-- options.userId / name
-- options.profile   a saved record to seed in the DataStore before the player joins (PlayerDataService
--                   loads it through the real UpdateAsync path)
-- options.level     sets leaderstats.Level after the profile applies (default: whatever the save says)
-- options.position  where the character stands (default: the hub centre, in town)
-- options.character false to join without a character
function Game:addPlayer(options)
	options = options or {}
	local world = self.world
	local userId = options.userId or 1001
	if options.profile then
		local SaveConfig = self:module("ReplicatedStorage.Config.SaveConfig")
		world:dataStore(SaveConfig.DATASTORE_NAME):Seed(SaveConfig.KEY_PREFIX .. tostring(userId), options.profile)
	end
	local player = world:newInstance("Player")
	player.Name = options.name or ("Player" .. userId)
	player.DisplayName = player.Name
	player.UserId = userId
	local backpack = world:newInstance("Backpack")
	backpack.Name = "Backpack"
	backpack.Parent = player
	player.Parent = world:service("Players")
	world:service("Players").PlayerAdded:Fire(player)
	world:flush()
	if options.character ~= false then
		self:spawnCharacter(player, options.position)
	end
	if options.level then
		self:setLevel(player, options.level)
	end
	world:flush()
	return player
end

function Game:spawnCharacter(player, position)
	local world = self.world
	local character = world:newInstance("Model")
	character.Name = player.Name
	local root = world:newInstance("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(position or Vector3.new(0, 3, 0))
	root.Parent = character
	local humanoid = world:newInstance("Humanoid")
	humanoid.Parent = character
	character.PrimaryPart = root
	player.Character = character
	character.Parent = world.workspace
	player.CharacterAdded:Fire(character)
	world:flush()
	return character
end

-- Move a player's character (the spin wheel and the upgrade stall measure the distance).
function Game:moveTo(player, position)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	assert(root, "player has no character")
	root.CFrame = CFrame.new(position)
end

function Game:setLevel(player, level)
	local stats = player:FindFirstChild("leaderstats")
	local lv = stats and stats:FindFirstChild("Level")
	assert(lv, "setLevel: the profile has not applied (no leaderstats.Level)")
	lv.Value = level
	player:SetAttribute("Level", level)
	self.world:flush()
end

function Game:removePlayer(player)
	self.world:service("Players").PlayerRemoving:Fire(player)
	self.world:flush()
	player.Parent = nil
	self.world:flush()
end

-- ---------------------------------------------------------------- enemies
-- An enemy rig carrying exactly the attributes EnemyCombat stamps on a spawned foe
-- (createEnemyRig + spawnEnemy): Enemy, EnemyLevel, Archetype, Boss, Zone, Region, SpawnRole, plus
-- the Enemy tag. role: "minion" | "elite" | "warden" (SpawnRole boss, Boss false) | "boss".
function Game:spawnEnemy(options)
	local world = self.world
	local model = world:newInstance("Model")
	model.Name = options.archetype or "IronSquire"
	local root = world:newInstance("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(options.position or Vector3.new(300, 3, 300))
	root.Parent = model
	model.PrimaryPart = root
	local humanoid = world:newInstance("Humanoid")
	humanoid.Parent = model
	local role = options.role or "minion"
	model:SetAttribute("Enemy", true)
	model:SetAttribute("EnemyLevel", options.level or 1)
	model:SetAttribute("Archetype", options.archetype or "IronSquire")
	model:SetAttribute("Boss", role == "boss")
	model:SetAttribute("Zone", options.zone or "IronLowlands")
	if role ~= "minion" then
		model:SetAttribute("SpawnRole", (role == "warden" or role == "boss") and "boss" or role)
	else
		model:SetAttribute("SpawnRole", "minion")
	end
	model:AddTag("Enemy")
	model.Parent = world.workspace
	world:flush()
	return model, humanoid
end

-- Kill an enemy the way combat does: the killer's "creator" ObjectValue on the Humanoid, then
-- Health to 0 (Humanoid.Died fires, SwordDropSystem's hook runs).
function Game:kill(player, model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local tag = self.world:newInstance("ObjectValue")
	tag.Name = "creator"
	tag.Value = player
	tag.Parent = humanoid
	humanoid.Health = 0
	self.world:flush()
end

return Game
