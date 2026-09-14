-- ServerScriptService/QuestService.server.luau
-- Server-side quest logic: acceptance, progress tracking, completion, and rewards.
-- Integrates with QuestConfig, LevelingSystem leaderstats pattern, SaveConfig, and EnemyCombat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("QuestConfig"))
local CombatUtil = require(script.Parent:WaitForChild("CombatUtil"))

local ENEMY_ATTRIBUTE = CombatUtil.ENEMY_ATTRIBUTE
local CREATOR_TAG_NAME = "creator"
local isEnemy = CombatUtil.isEnemy

-- ==============================================================================
-- REMOTE EVENTS
-- ==============================================================================
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local QUEST_ACCEPT = remotes:WaitForChild("QuestAccept")
local QUEST_COMPLETE = remotes:WaitForChild("QuestComplete")
local QUEST_REWARD = remotes:WaitForChild("QuestReward")
local QUEST_UPDATE = remotes:WaitForChild("QuestUpdate")
local LEVELUP_EVENT = remotes:WaitForChild("LevelUpBurst")

-- ==============================================================================
-- CONSTANTS (mirror LevelingSystem tuning for XP grants)
-- ==============================================================================
local SKILL_POINTS_PER_LEVEL = 8
local BASE_XP_REQUIREMENT = 100
local XP_INCREASE_PER_LEVEL = 0.15
local XPGAIN_PCT_PER_POINT = 0.005
local XPGAIN_MAX_BONUS = 0.35

local AUTO_ACCEPT_DELAY = 2 -- seconds after completion before auto-accepting next quest
local OBTAIN_CHECK_INTERVAL = 2 -- seconds between inventory scans for OBTAIN quests

-- ==============================================================================
-- ZONE MAPPING  (archetype → quest zone identifier)
-- WorldLayout zone names don't always match QuestConfig zone IDs, so we map
-- archetypes directly to the zone strings used in quest definitions.
-- ==============================================================================
local ARCHETYPE_TO_ZONE = {
	-- Iron Lowlands
	IronSquire = "IronLowlands",
	IronBerserker = "IronLowlands",
	Boss_Gorgon = "IronLowlands",
	-- Frostbound Glacier (QuestConfig: "FrostGlacier")
	FrostImp = "FrostGlacier",
	GlacialGargoyle = "FrostGlacier",
	Boss_FrostRevenant = "FrostGlacier",
	-- Infernal Caldera (QuestConfig: "InfernalForge")
	CinderFiend = "InfernalForge",
	MagmaJuggernaut = "InfernalForge",
	Boss_InfernalColossus = "InfernalForge",
	-- Void Rift
	VoidShade = "VoidRift",
	AbyssTormentor = "VoidRift",
	Boss_VoidWraith = "VoidRift",
	-- Celestial Summit
	AstralWisp = "CelestialSummit",
	SolarDominator = "CelestialSummit",
	Boss_CelestialTitan = "CelestialSummit",
}

-- ==============================================================================
-- XP / LEVEL-UP LOGIC  (duplicated from LevelingSystem since awardExperience is local)
-- ==============================================================================
local function getRequiredExperience(level)
	return math.floor(BASE_XP_REQUIREMENT * (1 + XP_INCREASE_PER_LEVEL) ^ (level - 1))
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

	-- Apply Experience Gain skill bonus with cap
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

	if levelsGained > 0 then
		-- Recompute max health (same as LevelingSystem)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local healthPoints = player:GetAttribute("Health") or 0
			local rebirthBaseMultiplier = player:GetAttribute("RebirthHealthMult") or 1
			local rebirthFlatHealth = player:GetAttribute("RebirthFlatHealth") or 0
			if typeof(rebirthBaseMultiplier) ~= "number" then rebirthBaseMultiplier = 1 end
			if typeof(rebirthFlatHealth) ~= "number" then rebirthFlatHealth = 0 end
			local newMax = math.max(1, math.floor(
				100 * math.max(0, rebirthBaseMultiplier) + 20 * healthPoints + math.max(0, rebirthFlatHealth)
			))
			humanoid.MaxHealth = newMax
			humanoid.Health = newMax
		end

		local newPoints = (player:GetAttribute("SkillPoints") or 0) + SKILL_POINTS_PER_LEVEL * levelsGained
		player:SetAttribute("SkillPoints", newPoints)
		print(string.format("[QuestService] %s reached level %d from quest reward (gained %d skill points)",
			player.Name, level.Value, SKILL_POINTS_PER_LEVEL * levelsGained))

		local root = player.Character and (player.Character.PrimaryPart or player.Character:FindFirstChild("HumanoidRootPart"))
		if root then
			LEVELUP_EVENT:FireClient(player, root.Position)
		end
	end

	return gained
end

-- ==============================================================================
-- PER-PLAYER QUEST STATE
-- ==============================================================================
local playerState = {} -- [player] = { connections = {}, obtainCheckThread = nil }

-- Serialize comma-separated completed quest IDs into a set for fast lookup
local function parseCompleted(str)
	local set = {}
	if typeof(str) ~= "string" or str == "" then
		return set
	end
	for id in string.gmatch(str, "[^,]+") do
		set[id] = true
	end
	return set
end

local function serializeCompleted(set)
	local parts = {}
	for id in pairs(set) do
		parts[#parts + 1] = id
	end
	return table.concat(parts, ",")
end

-- Determine which quest a player should receive next, based on completed quests.
-- Returns the first quest whose ID is not in the completed set, or nil if chain is done.
local function getNextAvailableQuest(completedSet)
	for _, quest in ipairs(QuestConfig.QUESTS) do
		if not completedSet[quest.id] then
			return quest
		end
	end
	return nil
end

-- ==============================================================================
-- REWARD GRANTING
-- ==============================================================================
local function grantReward(player, reward)
	if not reward then return end

	local rtype = reward.type
	local amount = reward.amount or 0

	if rtype == "GOLD" then
		local goldStat = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Gold")
		if goldStat then
			goldStat.Value += amount
		end
		print(string.format("[QuestService] %s received %d Gold", player.Name, amount))

	elseif rtype == "XP" then
		local gained = awardExperience(player, amount)
		print(string.format("[QuestService] %s received %d XP (%d after bonuses)", player.Name, amount, gained))

	elseif rtype == "LEVEL" then
		local leaderstats = player:FindFirstChild("leaderstats")
		local levelStat = leaderstats and leaderstats:FindFirstChild("Level")
		if levelStat then
			levelStat.Value += amount
			local sp = (player:GetAttribute("SkillPoints") or 0) + SKILL_POINTS_PER_LEVEL * amount
			player:SetAttribute("SkillPoints", sp)
			print(string.format("[QuestService] %s received %d free level(s) + %d skill points",
				player.Name, amount, SKILL_POINTS_PER_LEVEL * amount))
		end

	elseif rtype == "SKILL_POINTS" then
		local current = player:GetAttribute("SkillPoints") or 0
		player:SetAttribute("SkillPoints", current + amount)
		print(string.format("[QuestService] %s received %d skill points (now %d)",
			player.Name, amount, current + amount))
	end

	-- Notify the client of the reward
	QUEST_REWARD:FireClient(player, rtype, amount)
end

-- ==============================================================================
-- QUEST COMPLETION
-- ==============================================================================
local function completeQuest(player, quest)
	local activeId = player:GetAttribute("ActiveQuestId") or ""
	if activeId ~= quest.id then return end

	-- Grant reward
	grantReward(player, quest.reward)

	-- Update completed quests attribute
	local completedSet = parseCompleted(player:GetAttribute("CompletedQuests") or "")
	completedSet[quest.id] = true
	player:SetAttribute("CompletedQuests", serializeCompleted(completedSet))

	-- Clear active quest
	player:SetAttribute("ActiveQuestId", "")
	player:SetAttribute("QuestProgress", 0)

	-- Notify client
	QUEST_COMPLETE:FireClient(player, quest.id)

	print(string.format("[QuestService] %s completed quest '%s' (%s)", player.Name, quest.name, quest.id))

	-- Auto-accept the next quest after a short delay
	task.delay(AUTO_ACCEPT_DELAY, function()
		if not player or not player.Parent then return end
		if (player:GetAttribute("ActiveQuestId") or "") ~= "" then return end

		local newCompleted = parseCompleted(player:GetAttribute("CompletedQuests") or "")
		local nextQuest = getNextAvailableQuest(newCompleted)
		if nextQuest then
			player:SetAttribute("ActiveQuestId", nextQuest.id)
			player:SetAttribute("QuestProgress", 0)
			QUEST_UPDATE:FireClient(player, nextQuest.id, 0)
			print(string.format("[QuestService] %s auto-accepted quest '%s' (%s)",
				player.Name, nextQuest.name, nextQuest.id))
			-- Reconnect progress listeners for the new quest
			trackQuestProgress(player)
		end
	end)
end

-- ==============================================================================
-- QUEST PROGRESS TRACKING
-- ==============================================================================

-- Check if a model matches a specific boss archetype
local function isBossArchetype(model, archetype)
	return model:GetAttribute("Archetype") == archetype
end

-- Check if the killer player has the matching creator tag
local function getKiller(humanoid)
	local creatorTag = humanoid:FindFirstChild(CREATOR_TAG_NAME)
	if creatorTag and creatorTag:IsA("ObjectValue") and creatorTag.Value and creatorTag.Value:IsA("Player") then
		return creatorTag.Value
	end
	return nil
end

-- Check player's inventory (Backpack + Character) for a tool with the given name
local function hasItemInInventory(player, itemName)
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child.Name == itemName then
					return true
				end
			end
		end
	end
	return false
end

local function disconnectPlayerState(player)
	local state = playerState[player]
	if not state then return end

	for _, conn in ipairs(state.connections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	state.connections = {}

	if state.obtainCheckThread then
		task.cancel(state.obtainCheckThread)
		state.obtainCheckThread = nil
	end

	playerState[player] = nil
end

-- Main progress-tracking entry point. Sets up listeners based on the active quest's
-- objective type. Called on quest accept, on auto-accept, and on rejoin.
function trackQuestProgress(player)
	local state = playerState[player]
	if not state then
		state = { connections = {}, obtainCheckThread = nil }
		playerState[player] = state
	else
		-- Clean up any prior listeners
		for _, conn in ipairs(state.connections) do
			if conn and conn.Connected then
				conn:Disconnect()
			end
		end
		state.connections = {}
		if state.obtainCheckThread then
			task.cancel(state.obtainCheckThread)
			state.obtainCheckThread = nil
		end
	end

	local activeId = player:GetAttribute("ActiveQuestId") or ""
	if activeId == "" then return end

	local quest = QuestConfig.getQuestById(activeId)
	if not quest then return end

	local objective = quest.objective
	local otype = objective.type

	-- ------------------------------------------------------------------
	-- KILL / KILL_ZONE / KILL_BOSS — hook into enemy Humanoid.Died
	-- ------------------------------------------------------------------
	if otype == "KILL" or otype == "KILL_ZONE" or otype == "KILL_BOSS" then
		-- We need to scan workspace for existing enemy humanoids AND connect to new ones.
		-- Same pattern as LevelingSystem: connect to Humanoid.Died on enemy models.
		local processed = setmetatable({}, { __mode = "k" })

		local function onEnemyDied(model, humanoid)
			if processed[humanoid] then return end
			processed[humanoid] = true

			local killer = getKiller(humanoid)
			if killer ~= player then return end

			-- Check if this kill matches the quest objective
			local matches = false

			if otype == "KILL" then
				matches = true -- any enemy kill counts

			elseif otype == "KILL_ZONE" then
				local archetype = model:GetAttribute("Archetype")
				if archetype then
					local zone = ARCHETYPE_TO_ZONE[archetype]
					matches = (zone == objective.zone)
				end

			elseif otype == "KILL_BOSS" then
				matches = isBossArchetype(model, objective.archetype)
			end

			if not matches then return end

			-- Check quest is still active
			if (player:GetAttribute("ActiveQuestId") or "") ~= quest.id then return end

			local progress = (player:GetAttribute("QuestProgress") or 0) + 1
			player:SetAttribute("QuestProgress", progress)

			QUEST_UPDATE:FireClient(player, quest.id, progress)
			print(string.format("[QuestService] %s progress on '%s': %d/%d",
				player.Name, quest.name, progress, objective.count))

			if progress >= objective.count then
				completeQuest(player, quest)
			end
		end

		local function connectEnemy(model)
			if not model:IsA("Model") or not isEnemy(model) then return end
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end

			local conn = humanoid.Died:Connect(function()
				onEnemyDied(model, humanoid)
			end)
			state.connections[#state.connections + 1] = conn
		end

		-- Connect to existing enemies in workspace
		for _, child in ipairs(workspace:GetChildren()) do
			if child:IsA("Model") and isEnemy(child) then
				local humanoid = child:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					connectEnemy(child)
				end
			end
		end

		-- Connect to newly added enemies
		local addedConn = workspace.ChildAdded:Connect(function(child)
			if child:IsA("Model") and isEnemy(child) then
				-- Wait for humanoid to be ready
				task.defer(function()
					if not child or not child.Parent then return end
					connectEnemy(child)
				end)
			end
		end)
		state.connections[#state.connections + 1] = addedConn

	-- ------------------------------------------------------------------
	-- OBTAIN — periodically check inventory for the named item
	-- ------------------------------------------------------------------
	elseif otype == "OBTAIN" then
		local itemName = objective.itemName

		-- Check immediately on accept
		if hasItemInInventory(player, itemName) then
			if (player:GetAttribute("ActiveQuestId") or "") == quest.id then
				local progress = (player:GetAttribute("QuestProgress") or 0)
				if progress < 1 then
					player:SetAttribute("QuestProgress", 1)
					QUEST_UPDATE:FireClient(player, quest.id, 1)
					print(string.format("[QuestService] %s obtained '%s' for quest '%s'",
						player.Name, itemName, quest.name))
				end
				completeQuest(player, quest)
				return
			end
		end

		-- Also listen for inventory changes (tools added to backpack or character)
		local function checkAndProgress()
			if (player:GetAttribute("ActiveQuestId") or "") ~= quest.id then return end
			if hasItemInInventory(player, itemName) then
				player:SetAttribute("QuestProgress", 1)
				QUEST_UPDATE:FireClient(player, quest.id, 1)
				completeQuest(player, quest)
				return true
			end
			return false
		end

		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			local conn = backpack.ChildAdded:Connect(function(child)
				if child:IsA("Tool") and child.Name == itemName then
					checkAndProgress()
				end
			end)
			state.connections[#state.connections + 1] = conn
		end

		-- Also check on character respawn (tool might be in character)
		local charAddedConn = player.CharacterAdded:Connect(function(character)
			task.defer(function()
				if checkAndProgress() then return end
				-- Also connect to backpack changes after respawn
				task.wait(0.5)
				local bag = player:FindFirstChildOfClass("Backpack")
				if bag then
					local conn2 = bag.ChildAdded:Connect(function(child)
						if child:IsA("Tool") and child.Name == itemName then
							checkAndProgress()
						end
					end)
					state.connections[#state.connections + 1] = conn2
				end
			end)
		end)
		state.connections[#state.connections + 1] = charAddedConn

		-- Periodic fallback check
		state.obtainCheckThread = task.spawn(function()
			while player and player.Parent do
				task.wait(OBTAIN_CHECK_INTERVAL)
				if (player:GetAttribute("ActiveQuestId") or "") ~= quest.id then break end
				if checkAndProgress() then break end
			end
		end)

	-- ------------------------------------------------------------------
	-- LEVEL — check leaderstats.Level for reaching a target
	-- ------------------------------------------------------------------
	elseif otype == "LEVEL" then
		local target = objective.target

		-- Check immediately
		local levelStat = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Level")
		if levelStat and levelStat.Value >= target then
			if (player:GetAttribute("ActiveQuestId") or "") == quest.id then
				player:SetAttribute("QuestProgress", 1)
				QUEST_UPDATE:FireClient(player, quest.id, 1)
				completeQuest(player, quest)
				return
			end
		end

		-- Listen for level changes
		if levelStat then
			local conn = levelStat.Changed:Connect(function(newValue)
				if (player:GetAttribute("ActiveQuestId") or "") ~= quest.id then return end
				if newValue >= target then
					player:SetAttribute("QuestProgress", 1)
					QUEST_UPDATE:FireClient(player, quest.id, 1)
					completeQuest(player, quest)
				end
			end)
			state.connections[#state.connections + 1] = conn
		end
	end
end

-- ==============================================================================
-- QUEST ACCEPT HANDLER
-- ==============================================================================
local function acceptQuest(player)
	-- Player must have data loaded
	if player:GetAttribute("DataLoaded") ~= true then return end

	-- Must not already have an active quest
	local activeId = player:GetAttribute("ActiveQuestId") or ""
	if activeId ~= "" then return end

	-- Determine next quest in chain
	local completedSet = parseCompleted(player:GetAttribute("CompletedQuests") or "")
	local quest = getNextAvailableQuest(completedSet)
	if not quest then
		print(string.format("[QuestService] %s has completed all quests", player.Name))
		return
	end

	-- Accept the quest
	player:SetAttribute("ActiveQuestId", quest.id)
	player:SetAttribute("QuestProgress", 0)

	-- Notify client
	QUEST_UPDATE:FireClient(player, quest.id, 0)

	print(string.format("[QuestService] %s accepted quest '%s' (%s)", player.Name, quest.name, quest.id))

	-- Start tracking progress
	trackQuestProgress(player)
end

-- RemoteEvent path (client-initiated via GUI or other client scripts)
QUEST_ACCEPT.OnServerEvent:Connect(function(player)
	acceptQuest(player)
end)

-- ==============================================================================
-- QUEST GIVER NPC (placeholder Part with BillboardGui + ProximityPrompt)
-- ==============================================================================
local function createQuestGiver()
	local container = Instance.new("Model")
	container.Name = "QuestGiver"

	-- Main block
	local part = Instance.new("Part")
	part.Name = "QuestGiverPart"
	part.Size = Vector3.new(4, 6, 4)
	part.Color = QuestConfig.GIVER_COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = true
	part.Position = QuestConfig.GIVER_POSITION
	part.Parent = container

	-- Head decoration (sphere on top)
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(3, 3, 3)
	head.Color = QuestConfig.GIVER_COLOR
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.Position = part.Position + Vector3.new(0, 4.5, 0)
	head.Parent = container

	container.PrimaryPart = part
	container.Parent = workspace

	-- BillboardGui with dynamic quest indicator
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "QuestIndicator"
	billboard.Size = UDim2.fromOffset(80, 80)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 60
	billboard.Parent = head

	local indicator = Instance.new("TextLabel")
	indicator.Name = "Indicator"
	indicator.BackgroundTransparency = 1
	indicator.Size = UDim2.new(1, 0, 1, 0)
	indicator.Font = Enum.Font.GothamBold
	indicator.TextSize = 48
	indicator.TextStrokeTransparency = 0.2
	indicator.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
	indicator.Text = "?"
	indicator.TextColor3 = Color3.fromRGB(255, 220, 50)
	indicator.Parent = billboard

	-- Name label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0, 24)
	nameLabel.Position = UDim2.new(0, 0, 1, 4)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
	nameLabel.Text = QuestConfig.GIVER_NAME
	nameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	nameLabel.Parent = billboard

	-- ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "QuestPrompt"
	prompt.ActionText = "Talk"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = QuestConfig.INTERACT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(function(triggerPlayer)
		acceptQuest(triggerPlayer)
	end)

	-- Update the indicator based on the nearest player's quest state.
	-- '?' = quest available, '!' = quest ready to turn in (completed), nothing = no quests left.
	task.spawn(function()
		while container and container.Parent do
			-- Determine what to show based on the closest player in range
			local anyAvailable = false
			local anyComplete = false

			for _, p in ipairs(Players:GetPlayers()) do
				local character = p.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if hrp and (hrp.Position - QuestConfig.GIVER_POSITION).Magnitude <= QuestConfig.INTERACT_RANGE + 10 then
					local activeId = p:GetAttribute("ActiveQuestId") or ""
					local completedSet = parseCompleted(p:GetAttribute("CompletedQuests") or "")
					if activeId ~= "" then
						local quest = QuestConfig.getQuestById(activeId)
						if quest then
							local progress = p:GetAttribute("QuestProgress") or 0
							local count = quest.objective.count or 1
							if progress >= count then
								anyComplete = true
							end
						end
					else
						local nextQuest = getNextAvailableQuest(completedSet)
						if nextQuest then
							anyAvailable = true
						end
					end
				end
			end

			if anyComplete then
				indicator.Text = "!"
				indicator.TextColor3 = Color3.fromRGB(80, 255, 80)
			elseif anyAvailable then
				indicator.Text = "?"
				indicator.TextColor3 = Color3.fromRGB(255, 220, 50)
			else
				indicator.Text = ""
			end

			task.wait(0.5)
		end
	end)

	return container
end

-- ==============================================================================
-- PLAYER LIFECYCLE
-- ==============================================================================
local function onPlayerAdded(player)
	-- Wait for data to be loaded by PlayerDataService
	local function onDataReady()
		-- Ensure quest attributes exist (backfill for existing players)
		if player:GetAttribute("CompletedQuests") == nil then
			player:SetAttribute("CompletedQuests", "")
		end
		if player:GetAttribute("ActiveQuestId") == nil then
			player:SetAttribute("ActiveQuestId", "")
		end
		if player:GetAttribute("QuestProgress") == nil then
			player:SetAttribute("QuestProgress", 0)
		end

		-- If the player has an active quest, re-connect progress listeners
		local activeId = player:GetAttribute("ActiveQuestId") or ""
		if activeId ~= "" then
			local quest = QuestConfig.getQuestById(activeId)
			if quest then
				print(string.format("[QuestService] %s has active quest '%s' — reconnecting listeners", player.Name, quest.name))
				trackQuestProgress(player)
			else
				-- Quest ID no longer valid — clear it
				player:SetAttribute("ActiveQuestId", "")
				player:SetAttribute("QuestProgress", 0)
			end
		end
	end

	-- Wait for DataLoaded attribute to become true
	if player:GetAttribute("DataLoaded") == true then
		onDataReady()
	else
		local conn
		conn = player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
			if player:GetAttribute("DataLoaded") == true then
				if conn then conn:Disconnect() end
				onDataReady()
			end
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	disconnectPlayerState(player)
end)

-- ==============================================================================
-- INITIALIZATION
-- ==============================================================================
createQuestGiver()

print("[QuestService] Quest system initialized — " .. #QuestConfig.QUESTS .. " quests in chain")
