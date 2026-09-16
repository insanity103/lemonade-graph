--// QuestSystem  (server-authoritative quest chain: accept, track, complete, reward)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CombatUtil = require(script.Parent:WaitForChild("CombatUtil"))
local QuestConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("QuestConfig"))
local WorldLayout = require(script.Parent:WaitForChild("WorldLayout"))

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local QUEST_ACCEPT = remotes:WaitForChild("QuestAccept")
local QUEST_UPDATE = remotes:WaitForChild("QuestUpdate")
local QUEST_COMPLETE = remotes:WaitForChild("QuestComplete")
local QUEST_REWARD = remotes:WaitForChild("QuestReward")

local ENEMY_TAG = CombatUtil.ENEMY_TAG
local CREATOR_TAG_NAME = "creator"

-- Archetype → zone mapping (derived from WorldLayout.ZONES spawns)
local ARCHETYPE_ZONE = {
	IronSquire = "IronLowlands", IronBerserker = "IronLowlands", Boss_Gorgon = "IronLowlands",
	ThornStalker = "Briarwood", BriarBrute = "Briarwood", RootWarden = "Briarwood",
	FrostImp = "FrostboundGlacier", GlacialGargoyle = "FrostboundGlacier", Boss_FrostRevenant = "FrostboundGlacier",
	BogLurker = "SunkenMarsh", MireHulk = "SunkenMarsh", DrownedBellwarden = "SunkenMarsh",
	CinderFiend = "InfernalCaldera", MagmaJuggernaut = "InfernalCaldera", Boss_InfernalColossus = "InfernalCaldera",
	Stormcaller = "Stormwatch", ThunderConstruct = "Stormwatch", TempestWarden = "Stormwatch",
	VoidShade = "VoidRift", AbyssTormentor = "VoidRift", Boss_VoidWraith = "VoidRift",
	AstralWisp = "CelestialSummit", SolarDominator = "CelestialSummit", Boss_CelestialTitan = "CelestialSummit",
}

-- Per-player quest state cache
local playerQuest = {} -- [player] = { questId, progress }

-- ── Helpers ──────────────────────────────────────────────────────────────

local function getCompletedSet(player)
	local raw = player:GetAttribute("CompletedQuests") or ""
	local set = {}
	if raw ~= "" then
		for id in string.gmatch(raw, "[^,]+") do
			set[id] = true
		end
	end
	return set
end

local function addCompleted(player, questId)
	local raw = player:GetAttribute("CompletedQuests") or ""
	if raw == "" then
		player:SetAttribute("CompletedQuests", questId)
	else
		player:SetAttribute("CompletedQuests", raw .. "," .. questId)
	end
end

local function sendUpdate(player, questId, progress, completed)
	QUEST_UPDATE:FireClient(player, questId, progress, completed)
end

-- ── Reward granting ──────────────────────────────────────────────────────

local SKILL_POINTS_PER_LEVEL = 8

local function grantReward(player, reward)
	local rtype = reward.type
	local amount = reward.amount or 0

	if rtype == "GOLD" then
		local leaderstats = player:FindFirstChild("leaderstats")
		local gold = leaderstats and leaderstats:FindFirstChild("Gold")
		if gold then gold.Value += amount end

	elseif rtype == "XP" then
		local leaderstats = player:FindFirstChild("leaderstats")
		local level = leaderstats and leaderstats:FindFirstChild("Level")
		local experience = leaderstats and leaderstats:FindFirstChild("Experience")
		if level and experience then
			local BASE_XP = 100
			local XP_INC = 0.15
			local function reqExp(lv) return math.floor(BASE_XP * (1 + XP_INC) ^ (lv - 1)) end
			experience.Value += amount
			local levelsGained = 0
			while experience.Value >= reqExp(level.Value) do
				experience.Value -= reqExp(level.Value)
				level.Value += 1
				levelsGained += 1
			end
			if levelsGained > 0 then
				local newPoints = (player:GetAttribute("SkillPoints") or 0) + SKILL_POINTS_PER_LEVEL * levelsGained
				player:SetAttribute("SkillPoints", newPoints)
			end
		end

	elseif rtype == "LEVEL" then
		local leaderstats = player:FindFirstChild("leaderstats")
		local level = leaderstats and leaderstats:FindFirstChild("Level")
		if level then
			level.Value += amount
			local newPoints = (player:GetAttribute("SkillPoints") or 0) + SKILL_POINTS_PER_LEVEL * amount
			player:SetAttribute("SkillPoints", newPoints)
		end

	elseif rtype == "SKILL_POINTS" then
		local current = player:GetAttribute("SkillPoints") or 0
		player:SetAttribute("SkillPoints", current + amount)
	end

	QUEST_REWARD:FireClient(player, rtype, amount)
end

-- ── Objective checking ───────────────────────────────────────────────────

local function checkCompletion(player, quest, progress)
	local obj = quest.objective
	if obj.type == "KILL" or obj.type == "KILL_ZONE" or obj.type == "KILL_BOSS" then
		return progress >= (obj.count or 1)
	elseif obj.type == "OBTAIN" then
		return progress >= 1
	elseif obj.type == "LEVEL" then
		local leaderstats = player:FindFirstChild("leaderstats")
		local level = leaderstats and leaderstats:FindFirstChild("Level")
		return level and level.Value >= (obj.target or 1)
	end
	return false
end

-- ── Progress increment ───────────────────────────────────────────────────

local function incrementProgress(player, amount)
	local state = playerQuest[player]
	if not state or not state.questId then return end
	local quest = QuestConfig.getQuestById(state.questId)
	if not quest then return end

	-- LEVEL objectives are checked, not accumulated
	if quest.objective.type == "LEVEL" then
		if checkCompletion(player, quest, 0) then
			state.progress = 1
			sendUpdate(player, state.questId, 1, true)
		end
		return
	end

	state.progress = state.progress + (amount or 1)
	player:SetAttribute("QuestProgress", state.progress)

	if checkCompletion(player, quest, state.progress) then
		sendUpdate(player, state.questId, state.progress, true)
	else
		sendUpdate(player, state.questId, state.progress, false)
	end
end

-- ── Remote handlers ──────────────────────────────────────────────────────

QUEST_ACCEPT.OnServerEvent:Connect(function(player, questId)
	if player:GetAttribute("DataLoaded") ~= true then return end
	if typeof(questId) ~= "string" then return end

	-- Already has an active quest
	if playerQuest[player] and playerQuest[player].questId then return end

	local quest = QuestConfig.getQuestById(questId)
	if not quest then return end

	-- Check chain prerequisite
	local completed = getCompletedSet(player)
	if quest.index > 1 then
		local prev = QuestConfig.QUESTS[quest.index - 1]
		if prev and not completed[prev.id] then return end
	end

	-- Already completed
	if completed[questId] then return end

	-- Check OBTAIN immediately in case player already has the item
	local initialProgress = 0
	if quest.objective.type == "OBTAIN" then
		local backpack = player:FindFirstChildOfClass("Backpack")
		local character = player.Character
		local itemName = quest.objective.itemName
		if backpack then
			for _, tool in ipairs(backpack:GetChildren()) do
				if tool:IsA("Tool") and tool.Name == itemName then
					initialProgress = 1
					break
				end
			end
		end
		if initialProgress == 0 and character then
			for _, tool in ipairs(character:GetChildren()) do
				if tool:IsA("Tool") and tool.Name == itemName then
					initialProgress = 1
					break
				end
			end
		end
	elseif quest.objective.type == "LEVEL" then
		local leaderstats = player:FindFirstChild("leaderstats")
		local level = leaderstats and leaderstats:FindFirstChild("Level")
		if level and level.Value >= (quest.objective.target or 1) then
			initialProgress = 1
		end
	end

	playerQuest[player] = { questId = questId, progress = initialProgress }
	player:SetAttribute("ActiveQuestId", questId)
	player:SetAttribute("QuestProgress", initialProgress)

	sendUpdate(player, questId, initialProgress, checkCompletion(player, quest, initialProgress))
end)

QUEST_COMPLETE.OnServerEvent:Connect(function(player, questId)
	if typeof(questId) ~= "string" then return end

	local state = playerQuest[player]
	if not state or state.questId ~= questId then return end

	local quest = QuestConfig.getQuestById(questId)
	if not quest then return end

	if not checkCompletion(player, quest, state.progress) then return end

	-- Grant reward
	grantReward(player, quest.reward)

	-- Mark completed
	addCompleted(player, questId)

	-- Clear active quest
	playerQuest[player] = nil
	player:SetAttribute("ActiveQuestId", "")
	player:SetAttribute("QuestProgress", 0)

	-- Notify client
	QUEST_COMPLETE:FireClient(player, questId)
end)

-- ── Enemy kill tracking ──────────────────────────────────────────────────

local function onEnemyDeath(model, killer)
	if not killer then return end
	local archetype = model:GetAttribute("Archetype")
	if not archetype then return end

	local state = playerQuest[killer]
	if not state or not state.questId then return end
	local quest = QuestConfig.getQuestById(state.questId)
	if not quest then return end
	local obj = quest.objective

	if obj.type == "KILL_BOSS" then
		if archetype == obj.archetype then
			incrementProgress(killer, 1)
		end
	elseif obj.type == "KILL_ZONE" then
		local enemyZone = ARCHETYPE_ZONE[archetype]
		if enemyZone == obj.zone then
			incrementProgress(killer, 1)
		end
	elseif obj.type == "KILL" then
		incrementProgress(killer, 1)
	end
end

local connectedHumanoids = setmetatable({}, { __mode = "k" })
local processedDeaths = setmetatable({}, { __mode = "k" })

local function connectEnemyHumanoid(humanoid)
	if connectedHumanoids[humanoid] then return end
	local model = humanoid:FindFirstAncestorOfClass("Model")
	if not model or not CombatUtil.isEnemy(model) then return end

	connectedHumanoids[humanoid] = true
	humanoid.Died:Connect(function()
		if processedDeaths[humanoid] then return end
		processedDeaths[humanoid] = true

		local creatorTag = humanoid:FindFirstChild(CREATOR_TAG_NAME)
		local killer = nil
		if creatorTag and creatorTag:IsA("ObjectValue") and creatorTag.Value and creatorTag.Value:IsA("Player") then
			killer = creatorTag.Value
		end
		if killer then
			onEnemyDeath(model, killer)
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

for _, instance in workspace:GetChildren() do inspect(instance) end
workspace.ChildAdded:Connect(inspect)

-- ── Level-up listener (for LEVEL objectives) ─────────────────────────────

Players.PlayerAdded:Connect(function(player)
	local leaderstats = player:WaitForChild("leaderstats", 15)
	if not leaderstats then return end
	local levelVal = leaderstats:WaitForChild("Level", 10)
	if levelVal then
		levelVal.Changed:Connect(function()
			local state = playerQuest[player]
			if not state or not state.questId then return end
			local quest = QuestConfig.getQuestById(state.questId)
			if quest and quest.objective.type == "LEVEL" then
				incrementProgress(player, 0)
			end
		end)
	end
end)

-- ── Inventory listener (for OBTAIN objectives) ───────────────────────────

local function checkObtainQuest(player)
	local state = playerQuest[player]
	if not state or not state.questId then return end
	local quest = QuestConfig.getQuestById(state.questId)
	if not quest or quest.objective.type ~= "OBTAIN" then return end

	local itemName = quest.objective.itemName
	local found = false
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == itemName then
				found = true
				break
			end
		end
	end
	if not found and player.Character then
		for _, tool in ipairs(player.Character:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == itemName then
				found = true
				break
			end
		end
	end

	if found and state.progress < 1 then
		state.progress = 1
		player:SetAttribute("QuestProgress", 1)
		sendUpdate(player, state.questId, 1, true)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			checkObtainQuest(player)
			-- Watch for tool additions in backpack
			local backpack = player:FindFirstChildOfClass("Backpack")
			if backpack then
				backpack.ChildAdded:Connect(function()
					task.defer(checkObtainQuest, player)
				end)
			end
		end)
	end)
end)

-- ── Load quest state on join ─────────────────────────────────────────────

local function loadQuestState(player)
	local activeId = player:GetAttribute("ActiveQuestId") or ""
	local progress = player:GetAttribute("QuestProgress") or 0

	if activeId ~= "" and QuestConfig.getQuestById(activeId) then
		playerQuest[player] = { questId = activeId, progress = progress }
		-- Send initial state to client
		task.defer(function()
			local quest = QuestConfig.getQuestById(activeId)
			if quest then
				sendUpdate(player, activeId, progress, checkCompletion(player, quest, progress))
			end
		end)
	end
end

-- Wait for data to load before restoring quest state
Players.PlayerAdded:Connect(function(player)
	player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		if player:GetAttribute("DataLoaded") == true then
			loadQuestState(player)
		end
	end)
	if player:GetAttribute("DataLoaded") == true then
		loadQuestState(player)
	end
end)

-- ── Cleanup on leave ─────────────────────────────────────────────────────

Players.PlayerRemoving:Connect(function(player)
	playerQuest[player] = nil
	for humanoid in pairs(processedDeaths) do
		local tag = humanoid:FindFirstChild(CREATOR_TAG_NAME)
		if tag and tag:IsA("ObjectValue") and tag.Value == player then
			tag:Destroy()
		end
	end
end)

-- ── NPC Quest Giver ──────────────────────────────────────────────────────

task.defer(function()
	if WorldLayout.BLANK_SLATE then return end
	if WorldLayout.GAMEPLAY_ONLY then
		local actors = require(script.Parent:WaitForChild("GameplayActors"))
		if not WorldLayout.HUB.QuestGiverPosition then return end -- map lacks the marker: quest giver idle
		actors.create(QuestConfig.GIVER_NAME, WorldLayout.HUB.QuestGiverPosition, QuestConfig.GIVER_COLOR,
			{ facing = WorldLayout.HUB.QuestGiverCFrame, subtitle = "Press E to talk", outfit = "QuestMaster" })
		return
	end
end)

print("[QuestSystem] Quest system initialized (" .. #QuestConfig.QUESTS .. " quests)")
