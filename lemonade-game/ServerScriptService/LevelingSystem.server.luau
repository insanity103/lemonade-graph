local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BASE_XP_REQUIREMENT = 100
local XP_INCREASE_PER_LEVEL = 0.15
local XP_REWARD_ATTRIBUTE = "ExperienceReward"
local CombatUtil = require(script.Parent:WaitForChild("CombatUtil"))

local ENEMY_ATTRIBUTE = CombatUtil.ENEMY_ATTRIBUTE
local CREATOR_TAG_NAME = "creator"

local XP_EVENT = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("XPGain")
local SPEND_EVENT = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("SpendSkillPoint")
local GOLD_EVENT = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("GoldGain")
local LEVELUP_EVENT = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("LevelUpBurst")
local COMBAT_END_DELAY = 3 -- seconds without a kill before the combat session ends
local SKILL_SPEND_COOLDOWN = 0.1
local lastSkillSpendAt = {}

-- Skill point / attribute tuning
local SKILL_POINTS_PER_LEVEL = 8
local BASE_MAX_HEALTH = 100
local HEALTH_PER_POINT = 20
local STRENGTH_DAMAGE_PER_POINT = 5
-- Experience Gain tuning (scaled with a low hard cap similar to Defense)
local XPGAIN_PCT_PER_POINT = 0.005 -- each Experience Gain point grants +0.5% XP
local XPGAIN_MAX_BONUS = 0.35 -- hard low cap: Experience Gain skill points can never exceed +35% bonus XP
local XPGAIN_PER_POINT = XPGAIN_PCT_PER_POINT -- backwards compatibility alias

-- Gold drop tuning (scales with enemy level)
local GOLD_BASE = 5 -- gold dropped by a level 1 enemy

local ATTRIBUTE_NAMES = { "Strength", "Health", "Defense", "ExperienceGain" }

local combatXP = {} -- [player] = accumulated XP earned this combat session
local lastCombatAction = {} -- [player] = tick() of most recent kill
local lastDamageAt = setmetatable({}, { __mode = "k" })

local connectedHumanoids = setmetatable({}, { __mode = "k" })
local processedDeaths = setmetatable({}, { __mode = "k" })

local function getRequiredExperience(level)
	return math.floor(BASE_XP_REQUIREMENT * (1 + XP_INCREASE_PER_LEVEL) ^ (level - 1))
end

local function getOrCreateIntValue(parent, name, value)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("IntValue") then
		return existing
	end

	local valueObject = Instance.new("IntValue")
	valueObject.Name = name
	valueObject.Value = value
	valueObject.Parent = parent
	return valueObject
end

-- Recompute a character's max health from its Health stat plus all rebirth bonuses.
local function applyHealth(player, points)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	points = typeof(points) == "number" and math.max(0, points) or 0
	local rebirthBaseMultiplier = player:GetAttribute("RebirthHealthMult") or 1
	local rebirthFlatHealth = player:GetAttribute("RebirthFlatHealth") or 0
	if typeof(rebirthBaseMultiplier) ~= "number" then rebirthBaseMultiplier = 1 end
	if typeof(rebirthFlatHealth) ~= "number" then rebirthFlatHealth = 0 end

	-- The configured rebirth percentage applies to the base health pool; skill-point
	-- health remains a transparent +20 HP per point, and milestone health is flat.
	local newMax = math.max(1, math.floor(
		BASE_MAX_HEALTH * math.max(0, rebirthBaseMultiplier)
		+ HEALTH_PER_POINT * points
		+ math.max(0, rebirthFlatHealth)
	))
	humanoid.MaxHealth = newMax
	humanoid.Health = newMax
end

local function applyDeathGoldPenalty(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local gold = leaderstats and leaderstats:FindFirstChild("Gold")
	if not gold or not gold:IsA("IntValue") then
		return
	end

	local level = player:GetAttribute("Level") or 1
	-- Early exploration should teach the loop without deleting the player's
	-- earnings. The gold sink starts after the opening zone.
	local penaltyRate = level <= 8 and 0 or 0.15
	local lostGold = math.floor(gold.Value * penaltyRate)
	gold.Value -= lostGold
	if lostGold > 0 then
		print(string.format("[LevelingSystem] %s lost %d Gold on death (15%% of %d)", player.Name, lostGold, gold.Value + lostGold))
	end
end

local function getEnemyGold(level)
	return math.floor(GOLD_BASE * level)
end

local function trackCombatHealth(humanoid)
	lastDamageAt[humanoid] = tick()
	local previous = humanoid.Health
	humanoid.HealthChanged:Connect(function(current)
		if current < previous then
			lastDamageAt[humanoid] = tick()
		end
		previous = current
	end)
end

local function setupPlayer(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local level = getOrCreateIntValue(leaderstats, "Level", 1)
	local experience = getOrCreateIntValue(leaderstats, "Experience", 0)
	local gold = getOrCreateIntValue(leaderstats, "Gold", 0)

	player:SetAttribute("Level", level.Value)
	player:SetAttribute("Experience", experience.Value)
	player:SetAttribute("ExperienceRequired", getRequiredExperience(level.Value))
	player:SetAttribute("Gold", gold.Value)

	level.Changed:Connect(function(value)
		player:SetAttribute("Level", value)
		player:SetAttribute("ExperienceRequired", getRequiredExperience(value))
	end)

	experience.Changed:Connect(function(value)
		player:SetAttribute("Experience", value)
	end)

	gold.Changed:Connect(function(value)
		player:SetAttribute("Gold", value)
	end)

	-- Initialize the skill-point economy (player attributes replicate to the client).
	if player:GetAttribute("SkillPoints") == nil then
		player:SetAttribute("SkillPoints", 0)
	end
	if player:GetAttribute("WeaponLevel") == nil then
		player:SetAttribute("WeaponLevel", 0)
	end
	for _, name in ipairs(ATTRIBUTE_NAMES) do
		if player:GetAttribute(name) == nil then
			player:SetAttribute(name, 0)
		end
	end

	-- Health and rebirth changes all re-apply max health to the current character.
	local function refreshHealth()
		applyHealth(player, player:GetAttribute("Health"))
	end
	player:GetAttributeChangedSignal("Health"):Connect(refreshHealth)
	player:GetAttributeChangedSignal("RebirthHealthMult"):Connect(refreshHealth)
	player:GetAttributeChangedSignal("RebirthFlatHealth"):Connect(refreshHealth)

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		trackCombatHealth(humanoid)
		humanoid.Died:Connect(function()
			applyDeathGoldPenalty(player)
		end)
		applyHealth(player, player:GetAttribute("Health") or 0)
	end)

	-- Apply immediately if a character already exists.
	if player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			trackCombatHealth(humanoid)
			humanoid.Died:Connect(function()
				applyDeathGoldPenalty(player)
			end)
			applyHealth(player, player:GetAttribute("Health") or 0)
		else
			humanoid = player.Character:WaitForChild("Humanoid")
			trackCombatHealth(humanoid)
			humanoid.Died:Connect(function()
				applyDeathGoldPenalty(player)
			end)
			applyHealth(player, player:GetAttribute("Health") or 0)
		end
	end
end

local function awardExperience(player, amount)
	if not player or not player.Parent or typeof(amount) ~= "number" or amount <= 0 then
		return 0
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local level = leaderstats and leaderstats:FindFirstChild("Level")
	local experience = leaderstats and leaderstats:FindFirstChild("Experience")
	if not level or not experience then
		return 0
	end

	-- Experience Gain attribute boosts the XP earned (with a low cap similar to defense)
	local expPoints = player:GetAttribute("ExperienceGain") or 0
	local skillBonus = math.min(expPoints * XPGAIN_PCT_PER_POINT, XPGAIN_MAX_BONUS)
	local multiplier = 1 + skillBonus
	local rebirthMultiplier = player:GetAttribute("RebirthXPMult") or 1
	if typeof(rebirthMultiplier) ~= "number" then rebirthMultiplier = 1 end
	local gained = math.floor(amount * multiplier * math.max(0, rebirthMultiplier))

	local levelsGained = 0
	experience.Value += gained
	while experience.Value >= getRequiredExperience(level.Value) do
		experience.Value -= getRequiredExperience(level.Value)
		level.Value += 1
		levelsGained += 1
	end

	-- Grant skill points for each level gained.
	if levelsGained > 0 then
		-- A level-up is a safe recovery beat as well as a power increase.
		applyHealth(player, player:GetAttribute("Health") or 0)
		local newPoints = (player:GetAttribute("SkillPoints") or 0) + SKILL_POINTS_PER_LEVEL * levelsGained
		player:SetAttribute("SkillPoints", newPoints)
		print(string.format("[LevelingSystem] %s reached level %d and gained %d skill points (total %d)",
			player.Name, level.Value, SKILL_POINTS_PER_LEVEL * levelsGained, newPoints))

		-- Burst of colored balls from the player on level up.
		local root = player.Character and (player.Character.PrimaryPart or player.Character:FindFirstChild("HumanoidRootPart"))
		if root then
			LEVELUP_EVENT:FireClient(player, root.Position)
		end
	end

	return gained
end

-- Regenerate after a short, readable pause away from combat. This keeps a
-- player who barely survives an encounter moving forward without making
-- Defense or Health upgrades irrelevant.
local REGEN_DELAY = 4
local REGEN_PER_SECOND = 0.08
task.spawn(function()
	while true do
		local now = tick()
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth
				and now - (lastDamageAt[humanoid] or 0) >= REGEN_DELAY then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * REGEN_PER_SECOND * 0.5)
			end
		end
		task.wait(0.5)
	end
end)

local function getEnemyReward(model)
	local reward = model:GetAttribute(XP_REWARD_ATTRIBUTE)
	if typeof(reward) == "number" then
		return math.max(0, math.floor(reward))
	end
	return 50
end

local isEnemy = CombatUtil.isEnemy

local function getKiller(humanoid)
	local creatorTag = humanoid:FindFirstChild(CREATOR_TAG_NAME)
	if creatorTag and creatorTag:IsA("ObjectValue") and creatorTag.Value and creatorTag.Value:IsA("Player") then
		return creatorTag.Value
	end
	return nil
end

local function connectEnemyHumanoid(humanoid)
	if connectedHumanoids[humanoid] then
		return
	end

	local model = humanoid:FindFirstAncestorOfClass("Model")
	if not model or not isEnemy(model) then
		return
	end

	connectedHumanoids[humanoid] = true
	humanoid.Died:Connect(function()
		if processedDeaths[humanoid] then
			return
		end
		processedDeaths[humanoid] = true

		local killer = getKiller(humanoid)
		if killer then
			local reward = getEnemyReward(model)
			local gained = awardExperience(killer, reward)
			combatXP[killer] = (combatXP[killer] or 0) + gained
			lastCombatAction[killer] = tick()

			-- Drop gold scaled by the enemy's level.
			local enemyLevel = model:GetAttribute("EnemyLevel") or 1
			local rebirthGoldMultiplier = killer:GetAttribute("RebirthGoldMult") or 1
			if typeof(rebirthGoldMultiplier) ~= "number" then rebirthGoldMultiplier = 1 end
			local gold = math.floor(getEnemyGold(enemyLevel) * math.max(0, rebirthGoldMultiplier))
			local goldStat = killer:FindFirstChild("leaderstats") and killer.leaderstats:FindFirstChild("Gold")
			if goldStat then
				goldStat.Value += gold
			end
			local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
			if root then
				GOLD_EVENT:FireAllClients(root.Position, gold)
			end
		end
	end)
end

local function inspect(instance)
	if instance:IsA("Humanoid") then
		connectEnemyHumanoid(instance)
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("Humanoid") then
			connectEnemyHumanoid(descendant)
		end
	end
end

-- Spend one skill point on an attribute. Authoritative on the server.
SPEND_EVENT.OnServerEvent:Connect(function(player, attributeName)
	if player:GetAttribute("DataLoaded") ~= true
		or typeof(attributeName) ~= "string"
		or not table.find(ATTRIBUTE_NAMES, attributeName) then
		return
	end
	local now = tick()
	if now - (lastSkillSpendAt[player] or 0) < SKILL_SPEND_COOLDOWN then
		return
	end
	lastSkillSpendAt[player] = now
	local points = player:GetAttribute("SkillPoints") or 0
	if points <= 0 then
		return
	end
	player:SetAttribute("SkillPoints", points - 1)
	player:SetAttribute(attributeName, (player:GetAttribute(attributeName) or 0) + 1)
	print(string.format("[LevelingSystem] %s spent a skill point on %s (now %d, %d remaining)",
		player.Name, attributeName, player:GetAttribute(attributeName), player:GetAttribute("SkillPoints")))
	if attributeName == "Health" then
		applyHealth(player, player:GetAttribute("Health"))
	end
end)

for _, player in Players:GetPlayers() do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	combatXP[player] = nil
	lastCombatAction[player] = nil
	lastSkillSpendAt[player] = nil
	for humanoid in pairs(processedDeaths) do
		local creatorTag = humanoid:FindFirstChild(CREATOR_TAG_NAME)
		if creatorTag and creatorTag:IsA("ObjectValue") and creatorTag.Value == player then
			creatorTag:Destroy()
		end
	end
end)

for _, instance in workspace:GetChildren() do
	inspect(instance)
end
workspace.ChildAdded:Connect(inspect)

-- When a player's combat session ends (no kill for COMBAT_END_DELAY seconds),
-- show the accumulated +XP at their feet.
RunService.Heartbeat:Connect(function()
	for player, xp in pairs(combatXP) do
		if xp > 0 and lastCombatAction[player] and (tick() - lastCombatAction[player]) >= COMBAT_END_DELAY then
			local character = player.Character
			local root = character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))
			if root then
				XP_EVENT:FireClient(player, root.Position, xp)
			end
			combatXP[player] = 0
			lastCombatAction[player] = nil
		end
	end
end)

print("[LevelingSystem] Experience, leveling, skill points, and gold enabled")
