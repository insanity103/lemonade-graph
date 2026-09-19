-- Script | ServerScriptService.AdminSystem | Owner-only dev/bug-testing tools: set level,
-- add gold, give any boss sword fully rolled. Everything it writes is the exact same
-- leaderstats/Backpack data normal play produces, so no other system needs to know this
-- exists. TO REMOVE: delete this file, StarterPlayerScripts/AdminGui.client.luau, and the
-- "AdminAction" line in RuntimeBootstrap's REMOTE_NAMES list -- nothing else references them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponModifiers = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponModifiers"))
local BossWeapons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BossWeapons"))
local BossSwordFactory = require(script.Parent:WaitForChild("BossSwordFactory"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local ADMIN = remotes:WaitForChild("AdminAction")
local NOTIFY = remotes:WaitForChild("Notify")

-- Whoever owns this Roblox place is an admin automatically -- true in Studio (you're testing
-- your own game) and true once published, with nothing to configure. Add a teammate's UserId
-- here to extend access for testing; leave it empty otherwise.
local EXTRA_ADMIN_IDS = {}

local function isAdmin(player)
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return table.find(EXTRA_ADMIN_IDS, player.UserId) ~= nil
end

local MAX_LEVEL = 1000000
local MAX_GOLD_GRANT = 100000000
local MAX_GOLD_TOTAL = 2000000000 -- IntValue ceiling headroom
local SKILL_POINTS_PER_LEVEL = 8 -- mirrors LevelingSystem.server.luau

local REQUEST_INTERVAL = 0.15
local lastRequestAt = {}

local function setLevel(player, amount)
	local level = math.clamp(math.floor(tonumber(amount) or 0), 1, MAX_LEVEL)
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelStat = leaderstats and leaderstats:FindFirstChild("Level")
	local expStat = leaderstats and leaderstats:FindFirstChild("Experience")
	if not levelStat then
		NOTIFY:FireClient(player, "Leaderstats aren't ready yet.", "error")
		return
	end
	levelStat.Value = level
	if expStat then
		expStat.Value = 0
	end
	-- A direct level set bypasses the per-level-up award in LevelingSystem, so grant the same
	-- total a normal climb to this level would have earned.
	player:SetAttribute("SkillPoints", SKILL_POINTS_PER_LEVEL * (level - 1))
	NOTIFY:FireClient(player, string.format("[Admin] Level set to %d.", level), "success")
	PlayerDataService.MarkDirty(player)
end

local function addGold(player, amount)
	local delta = math.clamp(math.floor(tonumber(amount) or 0), -MAX_GOLD_GRANT, MAX_GOLD_GRANT)
	local leaderstats = player:FindFirstChild("leaderstats")
	local gold = leaderstats and leaderstats:FindFirstChild("Gold")
	if not gold then
		NOTIFY:FireClient(player, "Leaderstats aren't ready yet.", "error")
		return
	end
	gold.Value = math.clamp(gold.Value + delta, 0, MAX_GOLD_TOTAL)
	NOTIFY:FireClient(player, string.format("[Admin] %+d Gold (now %d).", delta, gold.Value), "success")
end

-- Builds a fully-rolled copy of a boss's Legendary showpiece through the same factory every real
-- drop and purchase uses, then forces the best possible outcome (Blessed, every modifier
-- floored to the top tier) so the tool is a legitimate BossDrop, just always the best roll.
-- swordName (optional) picks another sword of that boss's pool instead (dropped at Epic).
local function giveSword(player, archetypeKey, swordName)
	local weaponData = BossWeapons.Pools[archetypeKey]
	if not weaponData then
		NOTIFY:FireClient(player, "Unknown weapon.", "error")
		return
	end
	local container = player:FindFirstChildOfClass("Backpack") or player.Character
	if not container then
		NOTIFY:FireClient(player, "No backpack to put it in yet.", "error")
		return
	end
	local def = swordName and BossWeapons.FindSword(swordName, archetypeKey)
	local tool = BossSwordFactory.build(archetypeKey, { blessedBonus = 1.0, sword = def and def.name or nil,
		rarity = (def and def ~= BossWeapons.Pools[archetypeKey].legendary) and "Epic" or "Legendary" })
	local _, fullName = BossSwordFactory.reroll(tool, 1.0, WeaponModifiers.TIER_COUNT, {})
	tool.Parent = container
	NOTIFY:FireClient(player, string.format("[Admin] Gave %s.", fullName or tool.Name), "success")
	PlayerDataService.MarkDirty(player)
end

ADMIN.OnServerEvent:Connect(function(player, action, arg)
	if not isAdmin(player) then
		return
	end
	local now = os.clock()
	if now - (lastRequestAt[player] or -math.huge) < REQUEST_INTERVAL then
		return
	end
	lastRequestAt[player] = now

	if action == "SetLevel" and typeof(arg) == "number" then
		setLevel(player, arg)
	elseif action == "AddGold" and typeof(arg) == "number" then
		addGold(player, arg)
	elseif action == "GiveSword" and typeof(arg) == "string" then
		local archetypeKey, swordName = string.match(arg, "^([^:]+):(.+)$")
		giveSword(player, archetypeKey or arg, swordName)
	elseif action == "GiveAllSwords" then
		for archetypeKey in pairs(BossWeapons.Pools) do
			giveSword(player, archetypeKey)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequestAt[player] = nil
end)

print("[AdminSystem] Owner-only admin tools ready (dev/bug-testing; safe to delete, see header)")
