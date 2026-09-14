-- StarterPlayer/StarterPlayerScripts/QuestGui.client.luau
-- Client-side quest HUD: tracker, progress bar, completion flash, accept notification
-- Reads quest data from QuestConfig and listens for player attribute changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local QuestConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("QuestConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===================================================================
-- CONSTANTS
-- ===================================================================
local GOLD_COLOR = Color3.fromRGB(235, 200, 60)
local DARK_BG = Color3.fromRGB(15, 15, 15)
local BAR_BG_COLOR = Color3.fromRGB(40, 40, 40)
local BAR_FILL_COLOR = Color3.fromRGB(220, 190, 50)
local WHITE = Color3.fromRGB(255, 255, 255)
local TRANSPARENCY_BG = 0.3
local CORNER_RADIUS = UDim.new(0, 8)

-- ===================================================================
-- SCREEN GUI
-- ===================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QuestHud"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ===================================================================
-- QUEST TRACKER FRAME — top-right corner
-- ===================================================================
local trackerFrame = Instance.new("Frame")
trackerFrame.Name = "QuestTracker"
trackerFrame.Size = UDim2.new(0, 250, 0, 80)
trackerFrame.Position = UDim2.new(1, -16, 0, 16)
trackerFrame.AnchorPoint = Vector2.new(1, 0)
trackerFrame.BackgroundColor3 = DARK_BG
trackerFrame.BackgroundTransparency = TRANSPARENCY_BG
trackerFrame.BorderSizePixel = 0
trackerFrame.Visible = false
trackerFrame.Parent = screenGui

local trackerCorner = Instance.new("UICorner")
trackerCorner.CornerRadius = CORNER_RADIUS
trackerCorner.Parent = trackerFrame

local trackerStroke = Instance.new("UIStroke")
trackerStroke.Color = Color3.fromRGB(60, 55, 30)
trackerStroke.Thickness = 1
trackerStroke.Transparency = 0.5
trackerStroke.Parent = trackerFrame

-- Quest name label
local questNameLabel = Instance.new("TextLabel")
questNameLabel.Name = "QuestName"
questNameLabel.Size = UDim2.new(1, -16, 0, 20)
questNameLabel.Position = UDim2.new(0, 8, 0, 6)
questNameLabel.BackgroundTransparency = 1
questNameLabel.Font = Enum.Font.GothamBold
questNameLabel.TextSize = 15
questNameLabel.TextColor3 = GOLD_COLOR
questNameLabel.TextXAlignment = Enum.TextXAlignment.Left
questNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
questNameLabel.Text = ""
questNameLabel.Parent = trackerFrame

-- Objective description label
local objectiveLabel = Instance.new("TextLabel")
objectiveLabel.Name = "Objective"
objectiveLabel.Size = UDim2.new(1, -16, 0, 16)
objectiveLabel.Position = UDim2.new(0, 8, 0, 26)
objectiveLabel.BackgroundTransparency = 1
objectiveLabel.Font = Enum.Font.Gotham
objectiveLabel.TextSize = 13
objectiveLabel.TextColor3 = WHITE
objectiveLabel.TextXAlignment = Enum.TextXAlignment.Left
objectiveLabel.TextTruncate = Enum.TextTruncate.AtEnd
objectiveLabel.Text = ""
objectiveLabel.Parent = trackerFrame

-- Progress bar background
local progressBarBg = Instance.new("Frame")
progressBarBg.Name = "ProgressBg"
progressBarBg.Size = UDim2.new(1, -16, 0, 10)
progressBarBg.Position = UDim2.new(0, 8, 0, 48)
progressBarBg.BackgroundColor3 = BAR_BG_COLOR
progressBarBg.BackgroundTransparency = 0.2
progressBarBg.BorderSizePixel = 0
progressBarBg.Parent = trackerFrame

local barBgCorner = Instance.new("UICorner")
barBgCorner.CornerRadius = UDim.new(0, 5)
barBgCorner.Parent = progressBarBg

-- Progress bar fill
local progressBarFill = Instance.new("Frame")
progressBarFill.Name = "ProgressFill"
progressBarFill.Size = UDim2.new(0, 0, 1, 0)
progressBarFill.BackgroundColor3 = BAR_FILL_COLOR
progressBarFill.BackgroundTransparency = 0
progressBarFill.BorderSizePixel = 0
progressBarFill.Parent = progressBarBg

local barFillCorner = Instance.new("UICorner")
barFillCorner.CornerRadius = UDim.new(0, 5)
barFillCorner.Parent = progressBarFill

-- Progress text label
local progressLabel = Instance.new("TextLabel")
progressLabel.Name = "ProgressText"
progressLabel.Size = UDim2.new(1, -16, 0, 14)
progressLabel.Position = UDim2.new(0, 8, 0, 62)
progressLabel.BackgroundTransparency = 1
progressLabel.Font = Enum.Font.Gotham
progressLabel.TextSize = 12
progressLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
progressLabel.TextXAlignment = Enum.TextXAlignment.Left
progressLabel.Text = ""
progressLabel.Parent = trackerFrame

-- ===================================================================
-- QUEST COMPLETION FLASH — golden overlay
-- ===================================================================
local completionOverlay = Instance.new("Frame")
completionOverlay.Name = "CompletionFlash"
completionOverlay.Size = UDim2.fromScale(1, 1)
completionOverlay.BackgroundColor3 = GOLD_COLOR
completionOverlay.BackgroundTransparency = 1
completionOverlay.BorderSizePixel = 0
completionOverlay.ZIndex = 50
completionOverlay.Visible = false
completionOverlay.Parent = screenGui

local completionText = Instance.new("TextLabel")
completionText.Name = "RewardText"
completionText.Size = UDim2.new(0.6, 0, 0, 50)
completionText.Position = UDim2.fromScale(0.5, 0.45)
completionText.AnchorPoint = Vector2.new(0.5, 0.5)
completionText.BackgroundTransparency = 1
completionText.Font = Enum.Font.GothamBold
completionText.TextSize = 32
completionText.TextColor3 = WHITE
completionText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
completionText.TextStrokeTransparency = 0.3
completionText.Text = ""
completionText.ZIndex = 51
completionText.Parent = completionOverlay

-- ===================================================================
-- QUEST ACCEPT NOTIFICATION
-- ===================================================================
local notifLabel = Instance.new("TextLabel")
notifLabel.Name = "QuestNotification"
notifLabel.Size = UDim2.new(0.5, 0, 0, 36)
notifLabel.Position = UDim2.fromScale(0.5, 0.15)
notifLabel.AnchorPoint = Vector2.new(0.5, 0.5)
notifLabel.BackgroundTransparency = 1
notifLabel.Font = Enum.Font.GothamBold
notifLabel.TextSize = 22
notifLabel.TextColor3 = GOLD_COLOR
notifLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
notifLabel.TextStrokeTransparency = 0.4
notifLabel.TextTransparency = 1
notifLabel.Text = ""
notifLabel.ZIndex = 40
notifLabel.Visible = false
notifLabel.Parent = screenGui

-- ===================================================================
-- HELPERS
-- ===================================================================

--- Build a lookup from quest id to quest definition.
local function getQuestData(questId: string)
	if questId == nil or questId == "" then
		return nil
	end
	return QuestConfig.getQuestById(questId)
end

--- Format a reward into a human-readable string (e.g. "+500 Gold").
local function formatReward(reward: { type: string, amount: number? }?): string
	if not reward then
		return ""
	end
	local rtype = reward.type
	local amount = reward.amount or 0
	if rtype == QuestConfig.REWARD_TYPES.GOLD then
		return "+" .. tostring(amount) .. " Gold"
	elseif rtype == QuestConfig.REWARD_TYPES.XP then
		return "+" .. tostring(amount) .. " XP"
	elseif rtype == QuestConfig.REWARD_TYPES.LEVEL then
		return "+" .. tostring(amount) .. (amount == 1 and " Level" or " Levels")
	elseif rtype == QuestConfig.REWARD_TYPES.SKILL_POINTS then
		return "+" .. tostring(amount) .. " Skill Points"
	end
	return "+" .. tostring(amount) .. " " .. tostring(rtype)
end

--- Compute progress fraction (0–1) and display text for a given quest + progress value.
local function computeProgress(quest, progress: number): (number, string)
	local obj = quest.objective
	local objType = obj.type

	if objType == QuestConfig.OBJECTIVE_TYPES.KILL_ZONE
		or objType == QuestConfig.OBJECTIVE_TYPES.KILL_BOSS
		or objType == QuestConfig.OBJECTIVE_TYPES.KILL then
		local count = obj.count or 1
		local current = math.min(progress, count)
		local frac = if count > 0 then current / count else 0
		return frac, tostring(current) .. "/" .. tostring(count) .. " defeated"

	elseif objType == QuestConfig.OBJECTIVE_TYPES.OBTAIN then
		-- Binary: 0 = not obtained, 1 = obtained
		if progress >= 1 then
			return 1, "Obtained"
		else
			return 0, "Not obtained"
		end

	elseif objType == QuestConfig.OBJECTIVE_TYPES.LEVEL then
		local target = obj.target or 1
		local currentLevel = player:GetAttribute("Level") or 1
		local displayLevel = math.min(currentLevel, target)
		local frac = if target > 0 then displayLevel / target else 0
		return frac, "Level " .. tostring(displayLevel) .. "/" .. tostring(target)
	end

	return 0, tostring(progress)
end

--- Tween the progress bar fill to a target fraction (0–1).
local function tweenProgress(frac: number)
	local clamped = math.clamp(frac, 0, 1)
	local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(progressBarFill, tweenInfo, {
		Size = UDim2.new(clamped, 0, 1, 0),
	})
	tween:Play()
end

-- ===================================================================
-- UPDATE DISPLAY
-- ===================================================================
local isShowingCompletion = false

local function updateQuestDisplay()
	local questId = player:GetAttribute("ActiveQuestId") or ""
	local quest = getQuestData(questId)

	if not quest then
		trackerFrame.Visible = false
		return
	end

	trackerFrame.Visible = true
	questNameLabel.Text = quest.name
	objectiveLabel.Text = quest.description

	local progress = player:GetAttribute("QuestProgress") or 0
	local frac, progressText = computeProgress(quest, progress)
	progressLabel.Text = progressText
	tweenProgress(frac)
end

-- ===================================================================
-- COMPLETION FLASH ANIMATION
-- ===================================================================
local function showCompletionFlash(rewardText: string)
	if isShowingCompletion then
		return
	end
	isShowingCompletion = true

	completionText.Text = "Quest Complete! " .. rewardText
	completionOverlay.Visible = true

	-- Fade in the golden flash
	completionOverlay.BackgroundTransparency = 1
	local fadeIn = TweenService:Create(completionOverlay, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 0.7,
	})
	fadeIn:Play()
	fadeIn.Completed:Wait()

	task.wait(1.0)

	-- Fade out
	local fadeOut = TweenService:Create(completionOverlay, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 1,
	})
	fadeOut:Play()
	fadeOut.Completed:Wait()

	completionOverlay.Visible = false
	isShowingCompletion = false
end

-- ===================================================================
-- QUEST ACCEPT NOTIFICATION
-- ===================================================================
local isShowingNotif = false

local function showQuestNotification(questName: string)
	if isShowingNotif then
		return
	end
	isShowingNotif = true

	notifLabel.Text = "New Quest: " .. questName
	notifLabel.TextTransparency = 1
	notifLabel.Visible = true

	-- Fade in
	local fadeIn = TweenService:Create(notifLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		TextTransparency = 0,
	})
	fadeIn:Play()
	fadeIn.Completed:Wait()

	task.wait(2.0)

	-- Fade out
	local fadeOut = TweenService:Create(notifLabel, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
		TextTransparency = 1,
	})
	fadeOut:Play()
	fadeOut.Completed:Wait()

	notifLabel.Visible = false
	isShowingNotif = false
end

-- ===================================================================
-- ATTRIBUTE LISTENERS
-- ===================================================================

-- Active quest changed — update entire display
player:GetAttributeChangedSignal("ActiveQuestId"):Connect(function()
	local questId = player:GetAttribute("ActiveQuestId") or ""
	local quest = getQuestData(questId)

	if quest then
		-- Show accept notification for newly activated quest
		task.spawn(showQuestNotification, quest.name)
	end

	updateQuestDisplay()
end)

-- Quest progress changed — update progress bar and text
player:GetAttributeChangedSignal("QuestProgress"):Connect(function()
	updateQuestDisplay()
end)

-- Completed quests changed — show completion flash if we just completed the active quest
player:GetAttributeChangedSignal("CompletedQuests"):Connect(function()
	local activeQuestId = player:GetAttribute("ActiveQuestId") or ""
	local quest = getQuestData(activeQuestId)
	if quest then
		local rewardText = formatReward(quest.reward)
		task.spawn(showCompletionFlash, rewardText)
	end

	-- After flash, the server will typically clear or swap the active quest;
	-- update display will hide the tracker if no new quest is set.
	task.delay(2.5, function()
		updateQuestDisplay()
	end)
end)

-- Also update the LEVEL-type quest display when the player's Level attribute changes,
-- since the progress text depends on the player's current level.
player:GetAttributeChangedSignal("Level"):Connect(function()
	local questId = player:GetAttribute("ActiveQuestId") or ""
	local quest = getQuestData(questId)
	if quest and quest.objective.type == QuestConfig.OBJECTIVE_TYPES.LEVEL then
		updateQuestDisplay()
	end
end)

-- ===================================================================
-- INITIAL STATE
-- ===================================================================
updateQuestDisplay()

print("[QuestGui] Quest HUD initialized")
