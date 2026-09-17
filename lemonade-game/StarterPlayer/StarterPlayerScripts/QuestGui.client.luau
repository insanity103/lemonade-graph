--// QuestGui  (client-side quest tracker HUD + NPC interaction)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local QuestConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("QuestConfig"))
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local QUEST_ACCEPT = remotes:WaitForChild("QuestAccept")
local QUEST_UPDATE = remotes:WaitForChild("QuestUpdate")
local QUEST_COMPLETE = remotes:WaitForChild("QuestComplete")
local QUEST_REWARD = remotes:WaitForChild("QuestReward")

-- ── Colors & constants ───────────────────────────────────────────────────
-- Local overlay: falls through to the shared palette, without mutating it.
local COLORS = setmetatable({
	XPGreen = Color3.fromRGB(80, 220, 120),
	Accent = Color3.fromRGB(200, 180, 60),
	QuestBar = Color3.fromRGB(200, 180, 60),
	QuestBarBg = Color3.fromRGB(30, 30, 36),
	Complete = Color3.fromRGB(90, 220, 140),
}, { __index = PanelChrome.COLORS })

local REWARD_COLORS = {
	GOLD = COLORS.Gold,
	XP = COLORS.XPGreen,
	LEVEL = Color3.fromRGB(120, 200, 255),
	SKILL_POINTS = Color3.fromRGB(190, 110, 245),
}

local REWARD_LABELS = {
	GOLD = "Gold",
	XP = "XP",
	LEVEL = "Level(s)",
	SKILL_POINTS = "Skill Points",
}

-- ── State ────────────────────────────────────────────────────────────────

local activeQuestId = player:GetAttribute("ActiveQuestId") or ""
local activeProgress = player:GetAttribute("QuestProgress") or 0
local activeQuestComplete = false
local npcNearby = false
local interactionOpen = false

-- ── GUI creation ─────────────────────────────────────────────────────────

local existing = playerGui:FindFirstChild("QuestGui")
if existing then existing:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QuestGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 11
screenGui.Parent = playerGui

local function addCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function addStroke(parent, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or COLORS.Stroke
	s.Transparency = transparency or 0.35
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

-- ── Quest Tracker HUD (left side) ────────────────────────────────────────

local trackerFrame = Instance.new("Frame")
trackerFrame.Name = "QuestTracker"
trackerFrame.AnchorPoint = Vector2.new(0, 0.5)
trackerFrame.Position = UDim2.new(0, 12, 0.5, -100)
trackerFrame.Size = UDim2.fromOffset(260, 0)
trackerFrame.AutomaticSize = Enum.AutomaticSize.Y
trackerFrame.BackgroundColor3 = COLORS.Panel
trackerFrame.BackgroundTransparency = 0.08
trackerFrame.BorderSizePixel = 0
trackerFrame.Visible = false
trackerFrame.ZIndex = 5
trackerFrame.Parent = screenGui
addCorner(trackerFrame, 12)
addStroke(trackerFrame, COLORS.Gold, 0.55, 1.25)

local trackerPadding = Instance.new("UIPadding")
trackerPadding.PaddingTop = UDim.new(0, 10)
trackerPadding.PaddingRight = UDim.new(0, 12)
trackerPadding.PaddingBottom = UDim.new(0, 10)
trackerPadding.PaddingLeft = UDim.new(0, 12)
trackerPadding.Parent = trackerFrame

local trackerLayout = Instance.new("UIListLayout")
trackerLayout.Padding = UDim.new(0, 6)
trackerLayout.SortOrder = Enum.SortOrder.LayoutOrder
trackerLayout.Parent = trackerFrame

-- Quest name
local questNameLabel = Instance.new("TextLabel")
questNameLabel.Name = "QuestName"
questNameLabel.BackgroundTransparency = 1
questNameLabel.Font = Enum.Font.GothamBold
questNameLabel.TextSize = 14
questNameLabel.TextColor3 = COLORS.Accent
questNameLabel.TextXAlignment = Enum.TextXAlignment.Left
questNameLabel.Text = ""
questNameLabel.Size = UDim2.new(1, 0, 0, 18)
questNameLabel.LayoutOrder = 1
questNameLabel.ZIndex = 6
questNameLabel.Parent = trackerFrame

-- Quest description
local questDescLabel = Instance.new("TextLabel")
questDescLabel.Name = "QuestDesc"
questDescLabel.BackgroundTransparency = 1
questDescLabel.Font = Enum.Font.Gotham
questDescLabel.TextSize = 12
questDescLabel.TextColor3 = COLORS.Muted
questDescLabel.TextXAlignment = Enum.TextXAlignment.Left
questDescLabel.TextWrapped = true
questDescLabel.Text = ""
questDescLabel.Size = UDim2.new(1, 0, 0, 0)
questDescLabel.AutomaticSize = Enum.AutomaticSize.Y
questDescLabel.LayoutOrder = 2
questDescLabel.ZIndex = 6
questDescLabel.Parent = trackerFrame

-- Progress bar background
local progressBg = Instance.new("Frame")
progressBg.Name = "ProgressBg"
progressBg.Size = UDim2.new(1, 0, 0, 8)
progressBg.BackgroundColor3 = COLORS.QuestBarBg
progressBg.BorderSizePixel = 0
progressBg.LayoutOrder = 3
progressBg.ZIndex = 6
progressBg.Parent = trackerFrame
addCorner(progressBg, 4)

-- Progress bar fill
local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = COLORS.QuestBar
progressFill.BorderSizePixel = 0
progressFill.ZIndex = 7
progressFill.Parent = progressBg
addCorner(progressFill, 4)

-- Progress text
local progressLabel = Instance.new("TextLabel")
progressLabel.Name = "ProgressText"
progressLabel.BackgroundTransparency = 1
progressLabel.Font = Enum.Font.GothamMedium
progressLabel.TextSize = 11
progressLabel.TextColor3 = COLORS.Muted
progressLabel.TextXAlignment = Enum.TextXAlignment.Right
progressLabel.Text = ""
progressLabel.Size = UDim2.new(1, 0, 0, 14)
progressLabel.LayoutOrder = 4
progressLabel.ZIndex = 6
progressLabel.Parent = trackerFrame

-- ── NPC Interaction Prompt ───────────────────────────────────────────────

local promptFrame = Instance.new("Frame")
promptFrame.Name = "InteractionPrompt"
promptFrame.AnchorPoint = Vector2.new(0.5, 1)
promptFrame.Position = UDim2.new(0.5, 0, 1, -120)
promptFrame.Size = UDim2.fromOffset(300, 50)
promptFrame.BackgroundColor3 = COLORS.Panel
promptFrame.BackgroundTransparency = 0.05
promptFrame.BorderSizePixel = 0
promptFrame.Visible = false
promptFrame.ZIndex = 10
promptFrame.Parent = screenGui
addCorner(promptFrame, 10)
addStroke(promptFrame, COLORS.Accent, 0.2, 1.5)

local promptKey = Instance.new("Frame")
promptKey.Size = UDim2.fromOffset(32, 32)
promptKey.Position = UDim2.fromOffset(10, 9)
promptKey.BackgroundColor3 = COLORS.Accent
promptKey.BorderSizePixel = 0
promptKey.ZIndex = 11
promptKey.Parent = promptFrame
addCorner(promptKey, 6)

local promptKeyLabel = Instance.new("TextLabel")
promptKeyLabel.BackgroundTransparency = 1
promptKeyLabel.Size = UDim2.fromScale(1, 1)
promptKeyLabel.Font = Enum.Font.GothamBold
promptKeyLabel.TextSize = 16
promptKeyLabel.TextColor3 = Color3.fromRGB(12, 12, 14)
promptKeyLabel.Text = "E"
promptKeyLabel.ZIndex = 12
promptKeyLabel.Parent = promptKey

local promptText = Instance.new("TextLabel")
promptText.BackgroundTransparency = 1
promptText.Font = Enum.Font.Gotham
promptText.TextSize = 13
promptText.TextColor3 = COLORS.Text
promptText.TextXAlignment = Enum.TextXAlignment.Left
promptText.Text = "Talk to Quest Master"
promptText.Position = UDim2.fromOffset(50, 0)
promptText.Size = UDim2.new(1, -60, 1, 0)
promptText.ZIndex = 11
promptText.Parent = promptFrame

-- ── Quest Dialog Panel ───────────────────────────────────────────────────

local dialogOverlay = Instance.new("TextButton")
dialogOverlay.Name = "DialogOverlay"
dialogOverlay.Size = UDim2.fromScale(1, 1)
dialogOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dialogOverlay.BackgroundTransparency = 1
dialogOverlay.BorderSizePixel = 0
dialogOverlay.Text = ""
dialogOverlay.AutoButtonColor = false
dialogOverlay.Visible = false
dialogOverlay.ZIndex = 20
dialogOverlay.Parent = screenGui

local dialogChrome = PanelChrome.build({
	name = "DialogPanel",
	title = QuestConfig.GIVER_NAME,
	accentColor = COLORS.Accent,
	size = UDim2.fromOffset(380, 280),
})
local dialogPanel = dialogChrome.Frame
dialogPanel.BackgroundTransparency = 0.04
dialogPanel.Visible = false
dialogPanel.ZIndex = 21
dialogPanel.Parent = screenGui

local dialogBody = Instance.new("Frame")
dialogBody.Name = "Body"
dialogBody.Position = UDim2.fromOffset(0, 52)
dialogBody.Size = UDim2.new(1, 0, 1, -52)
dialogBody.BackgroundTransparency = 1
dialogBody.ZIndex = 22
dialogBody.Parent = dialogPanel

local dialogPadding = Instance.new("UIPadding")
dialogPadding.PaddingTop = UDim.new(0, 8)
dialogPadding.PaddingRight = UDim.new(0, 16)
dialogPadding.PaddingBottom = UDim.new(0, 16)
dialogPadding.PaddingLeft = UDim.new(0, 16)
dialogPadding.Parent = dialogBody

local dialogLayout = Instance.new("UIListLayout")
dialogLayout.Padding = UDim.new(0, 10)
dialogLayout.SortOrder = Enum.SortOrder.LayoutOrder
dialogLayout.Parent = dialogBody

-- Dialog message
local dialogMessage = Instance.new("TextLabel")
dialogMessage.BackgroundTransparency = 1
dialogMessage.Font = Enum.Font.Gotham
dialogMessage.TextSize = 14
dialogMessage.TextColor3 = COLORS.Text
dialogMessage.TextXAlignment = Enum.TextXAlignment.Left
dialogMessage.TextWrapped = true
dialogMessage.Text = ""
dialogMessage.Size = UDim2.new(1, 0, 0, 0)
dialogMessage.AutomaticSize = Enum.AutomaticSize.Y
dialogMessage.LayoutOrder = 2
dialogMessage.ZIndex = 22
dialogMessage.Parent = dialogBody

-- Objective preview
local objPreview = Instance.new("TextLabel")
objPreview.BackgroundTransparency = 1
objPreview.Font = Enum.Font.GothamMedium
objPreview.TextSize = 13
objPreview.TextColor3 = COLORS.Muted
objPreview.TextXAlignment = Enum.TextXAlignment.Left
objPreview.TextWrapped = true
objPreview.Text = ""
objPreview.Size = UDim2.new(1, 0, 0, 0)
objPreview.AutomaticSize = Enum.AutomaticSize.Y
objPreview.LayoutOrder = 3
objPreview.ZIndex = 22
objPreview.Parent = dialogBody

-- Reward preview
local rewardPreview = Instance.new("TextLabel")
rewardPreview.BackgroundTransparency = 1
rewardPreview.Font = Enum.Font.GothamBold
rewardPreview.TextSize = 13
rewardPreview.TextColor3 = COLORS.Gold
rewardPreview.TextXAlignment = Enum.TextXAlignment.Left
rewardPreview.Text = ""
rewardPreview.Size = UDim2.new(1, 0, 0, 18)
rewardPreview.LayoutOrder = 4
rewardPreview.ZIndex = 22
rewardPreview.Parent = dialogBody

-- Buttons row
local buttonRow = Instance.new("Frame")
buttonRow.BackgroundTransparency = 1
buttonRow.Size = UDim2.new(1, 0, 0, 40)
buttonRow.LayoutOrder = 5
buttonRow.ZIndex = 22
buttonRow.Parent = dialogBody

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
buttonLayout.Padding = UDim.new(0, 10)
buttonLayout.Parent = buttonRow

local function createDialogButton(text, color, textColor)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(120, 36)
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextColor3 = textColor
	btn.TextSize = 14
	btn.Text = text
	btn.ZIndex = 23
	btn.AutoButtonColor = false
	btn.Parent = buttonRow
	addCorner(btn, 8)
	addStroke(btn, COLORS.StrokeBright, 0.3, 1)
	return btn
end

local acceptBtn = createDialogButton("Accept Quest", COLORS.Accent, Color3.fromRGB(12, 12, 14))
local completeBtn = createDialogButton("Turn In", COLORS.Complete, Color3.fromRGB(12, 12, 14))
local closeBtn = createDialogButton("Close", COLORS.Button, COLORS.Text)

acceptBtn.Visible = false
completeBtn.Visible = false

-- ── Reward Toast ─────────────────────────────────────────────────────────

local function showRewardToast(rtype, amount)
	local toast = Instance.new("Frame")
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, -50)
	toast.Size = UDim2.fromOffset(280, 44)
	toast.BackgroundColor3 = COLORS.Panel
	toast.BackgroundTransparency = 0.05
	toast.BorderSizePixel = 0
	toast.ZIndex = 30
	toast.Parent = screenGui
	addCorner(toast, 10)
	addStroke(toast, REWARD_COLORS[rtype] or COLORS.Gold, 0.1, 2)

	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(36, 44)
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 18
	icon.TextColor3 = REWARD_COLORS[rtype] or COLORS.Gold
	icon.Text = "+"
	icon.ZIndex = 31
	icon.Parent = toast

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(36, 0)
	label.Size = UDim2.new(1, -36, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = COLORS.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = string.format("+%d %s!", amount, REWARD_LABELS[rtype] or rtype)
	label.ZIndex = 31
	label.Parent = toast

	-- Slide in
	TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 16)
	}):Play()

	-- Slide out after delay
	task.delay(2.5, function()
		TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -50),
			BackgroundTransparency = 1
		}):Play()
		task.delay(0.35, function()
			toast:Destroy()
		end)
	end)
end

-- ── Completion celebration toast ─────────────────────────────────────────

local function showCompletionToast(questName)
	local toast = Instance.new("Frame")
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, -60)
	toast.Size = UDim2.fromOffset(340, 56)
	toast.BackgroundColor3 = COLORS.Panel
	toast.BackgroundTransparency = 0.02
	toast.BorderSizePixel = 0
	toast.ZIndex = 30
	toast.Parent = screenGui
	addCorner(toast, 12)
	addStroke(toast, COLORS.Complete, 0.0, 2)

	local checkLabel = Instance.new("TextLabel")
	checkLabel.BackgroundTransparency = 1
	checkLabel.Size = UDim2.fromOffset(40, 56)
	checkLabel.Font = Enum.Font.GothamBold
	checkLabel.TextSize = 24
	checkLabel.TextColor3 = COLORS.Complete
	checkLabel.Text = "✓"
	checkLabel.ZIndex = 31
	checkLabel.Parent = toast

	local titleLabel = Instance.new("TextLabel")
 titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(40, 6)
	titleLabel.Size = UDim2.new(1, -50, 0, 20)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 14
	titleLabel.TextColor3 = COLORS.Complete
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "QUEST COMPLETE"
	titleLabel.ZIndex = 31
	titleLabel.Parent = toast

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(40, 28)
	nameLabel.Size = UDim2.new(1, -50, 0, 18)
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = COLORS.Text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = questName
	nameLabel.ZIndex = 31
	nameLabel.Parent = toast

	TweenService:Create(toast, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 16)
	}):Play()

	task.delay(3, function()
		TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -60),
			BackgroundTransparency = 1
		}):Play()
		task.delay(0.35, function()
			toast:Destroy()
		end)
	end)
end

-- ── Helper: objective text ───────────────────────────────────────────────

local function getObjectiveText(quest, progress)
	local obj = quest.objective
	if obj.type == "KILL" then
		return string.format("Defeat %d enemies  (%d/%d)", obj.count, math.min(progress, obj.count), obj.count)
	elseif obj.type == "KILL_ZONE" then
		return string.format("Defeat %d enemies in %s  (%d/%d)", obj.count, obj.zone, math.min(progress, obj.count), obj.count)
	elseif obj.type == "KILL_BOSS" then
		return string.format("Defeat %s  (%d/%d)", obj.archetype, math.min(progress, obj.count or 1), obj.count or 1)
	elseif obj.type == "OBTAIN" then
		return string.format("Obtain: %s  (%s)", obj.itemName, progress >= 1 and "Found!" or "Not found")
	elseif obj.type == "LEVEL" then
		local level = 1
		local leaderstats = player:FindFirstChild("leaderstats")
		local lv = leaderstats and leaderstats:FindFirstChild("Level")
		if lv then level = lv.Value end
		return string.format("Reach level %d  (Lv %d)", obj.target, level)
	end
	return quest.description
end

local function getProgressFraction(quest, progress)
	local obj = quest.objective
	if obj.type == "KILL" or obj.type == "KILL_ZONE" or obj.type == "KILL_BOSS" then
		return math.clamp(progress / (obj.count or 1), 0, 1)
	elseif obj.type == "OBTAIN" then
		return progress >= 1 and 1 or 0
	elseif obj.type == "LEVEL" then
		local level = 1
		local leaderstats = player:FindFirstChild("leaderstats")
		local lv = leaderstats and leaderstats:FindFirstChild("Level")
		if lv then level = lv.Value end
		return math.clamp(level / (obj.target or 1), 0, 1)
	end
	return 0
end

local function getRewardText(reward)
	local rtype = reward.type
	local amount = reward.amount or 0
	if rtype == "GOLD" then
		return string.format("Reward: %d Gold", amount)
	elseif rtype == "XP" then
		return string.format("Reward: %d XP", amount)
	elseif rtype == "LEVEL" then
		return string.format("Reward: %d Free Level(s)", amount)
	elseif rtype == "SKILL_POINTS" then
		return string.format("Reward: %d Skill Points", amount)
	end
	return "Reward: ???"
end

-- ── Tracker update ───────────────────────────────────────────────────────

local function updateTracker()
	if activeQuestId == "" then
		trackerFrame.Visible = false
		return
	end

	local quest = QuestConfig.getQuestById(activeQuestId)
	if not quest then
		trackerFrame.Visible = false
		return
	end

	trackerFrame.Visible = true
	questNameLabel.Text = quest.name
	questDescLabel.Text = quest.description

	local objText = getObjectiveText(quest, activeProgress)
	progressLabel.Text = objText

	local frac = getProgressFraction(quest, activeProgress)
	TweenService:Create(progressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(frac, 0, 1, 0)
	}):Play()

	if activeQuestComplete then
		progressFill.BackgroundColor3 = COLORS.Complete
		progressLabel.Text = "✓ Ready to turn in!"
	else
		progressFill.BackgroundColor3 = COLORS.QuestBar
	end
end

-- ── Dialog management ────────────────────────────────────────────────────

local function closeDialog()
	interactionOpen = false
	dialogOverlay.Visible = false
	dialogPanel.Visible = false
end

local function openDialog(quest, mode)
	-- mode: "accept", "turnin", "info"
	interactionOpen = true
	dialogOverlay.Visible = true
	dialogPanel.Visible = true

	TweenService:Create(dialogOverlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.5 }):Play()

	acceptBtn.Visible = false
	completeBtn.Visible = false

	if mode == "accept" then
		dialogMessage.Text = string.format("I have a task for you, adventurer.\n\n%s", quest.description)
		objPreview.Text = getObjectiveText(quest, 0)
		rewardPreview.Text = getRewardText(quest.reward)
		acceptBtn.Visible = true
	elseif mode == "turnin" then
		dialogMessage.Text = "Well done! Here is your reward."
		objPreview.Text = getObjectiveText(quest, activeProgress)
		rewardPreview.Text = getRewardText(quest.reward)
		completeBtn.Visible = true
	elseif mode == "info" then
		dialogMessage.Text = string.format("You're working on:\n\n%s", quest.description)
		objPreview.Text = getObjectiveText(quest, activeProgress)
		rewardPreview.Text = getRewardText(quest.reward)
	end
end

-- ── NPC interaction logic ────────────────────────────────────────────────

local INTERACT_RANGE = QuestConfig.INTERACT_RANGE

local function getQuestMasterPosition()
	-- Find Quest Master in workspace
	local npc = Workspace:FindFirstChild(QuestConfig.GIVER_NAME)
	if npc then
		local hrp = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
		if hrp then return hrp.Position end
	end
	return QuestConfig.GIVER_POSITION
end

-- Talking uses a ProximityPrompt on the Quest Master: prompts take their key before the
-- ContextActionService Attack binding on E, and they work for touch and gamepad too.
local questPrompt = nil
local interactWithNPC -- defined below; the prompt callback runs later, once it exists
local function ensureQuestPrompt()
	local npc = Workspace:FindFirstChild(QuestConfig.GIVER_NAME)
	local root = npc and (npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart)
	if not root or (questPrompt and questPrompt.Parent == root) then return end
	questPrompt = Instance.new("ProximityPrompt")
	questPrompt.Name = "QuestPrompt"
	questPrompt.ActionText = "Talk"
	questPrompt.ObjectText = QuestConfig.GIVER_NAME
	questPrompt.HoldDuration = 0
	questPrompt.MaxActivationDistance = INTERACT_RANGE
	questPrompt.RequiresLineOfSight = false
	questPrompt.Parent = root
	questPrompt.Triggered:Connect(function()
		if not interactionOpen then
			npcNearby = true
			interactWithNPC()
		end
	end)
end

local function checkProximity()
	local character = player.Character
	if not character then
		if npcNearby then npcNearby = false; promptFrame.Visible = false end
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		if npcNearby then npcNearby = false; promptFrame.Visible = false end
		return
	end

	local npcPos = getQuestMasterPosition()
	local dist = (hrp.Position - npcPos).Magnitude
	local wasNear = npcNearby
	npcNearby = dist <= INTERACT_RANGE

	if npcNearby and not wasNear then
		ensureQuestPrompt()
	elseif not npcNearby and wasNear then
		promptFrame.Visible = false
		if interactionOpen then closeDialog() end
	end
end

function interactWithNPC()
	if not npcNearby or interactionOpen then return end

	-- Determine what to show
	if activeQuestId == "" then
		-- No active quest — offer next in chain
		local nextQuest = nil
		local completed = {}
		local raw = player:GetAttribute("CompletedQuests") or ""
		if raw ~= "" then
			for id in string.gmatch(raw, "[^,]+") do completed[id] = true end
		end
		for _, q in ipairs(QuestConfig.QUESTS) do
			if not completed[q.id] then
				nextQuest = q
				break
			end
		end
		if nextQuest then
			openDialog(nextQuest, "accept")
		else
			-- All quests done
			dialogMessage.Text = "You have completed all my tasks. You are a true legend!"
			objPreview.Text = ""
			rewardPreview.Text = ""
			interactionOpen = true
			dialogOverlay.Visible = true
			dialogPanel.Visible = true
		end
	elseif activeQuestComplete then
		-- Ready to turn in
		local quest = QuestConfig.getQuestById(activeQuestId)
		if quest then openDialog(quest, "turnin") end
	else
		-- Quest in progress
		local quest = QuestConfig.getQuestById(activeQuestId)
		if quest then openDialog(quest, "info") end
	end
end

-- ── Button handlers ──────────────────────────────────────────────────────

acceptBtn.Activated:Connect(function()
	local nextQuest = nil
	local completed = {}
	local raw = player:GetAttribute("CompletedQuests") or ""
	if raw ~= "" then
		for id in string.gmatch(raw, "[^,]+") do completed[id] = true end
	end
	for _, q in ipairs(QuestConfig.QUESTS) do
		if not completed[q.id] then
			nextQuest = q
			break
		end
	end
	if nextQuest then
		QUEST_ACCEPT:FireServer(nextQuest.id)
	end
	closeDialog()
end)

completeBtn.Activated:Connect(function()
	if activeQuestId ~= "" then
		QUEST_COMPLETE:FireServer(activeQuestId)
	end
	closeDialog()
end)

closeBtn.Activated:Connect(closeDialog)
dialogChrome.CloseButton.Activated:Connect(closeDialog)
dialogOverlay.Activated:Connect(closeDialog)

-- ── Input ────────────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape and interactionOpen then
		closeDialog()
	end
end)

-- ── Remote listeners ─────────────────────────────────────────────────────

QUEST_UPDATE.OnClientEvent:Connect(function(questId, progress, completed)
	activeQuestId = questId
	activeProgress = progress
	activeQuestComplete = completed
	player:SetAttribute("ActiveQuestId", questId)
	player:SetAttribute("QuestProgress", progress)
	updateTracker()
end)

QUEST_COMPLETE.OnClientEvent:Connect(function(questId)
	local quest = QuestConfig.getQuestById(questId)
	if quest then
		showCompletionToast(quest.name)
	end
	activeQuestId = ""
	activeProgress = 0
	activeQuestComplete = false
	player:SetAttribute("ActiveQuestId", "")
	player:SetAttribute("QuestProgress", 0)
	updateTracker()
end)

QUEST_REWARD.OnClientEvent:Connect(function(rtype, amount)
	showRewardToast(rtype, amount)
end)

-- ── Sync from attributes on join ─────────────────────────────────────────

local function syncFromAttributes()
	activeQuestId = player:GetAttribute("ActiveQuestId") or ""
	activeProgress = player:GetAttribute("QuestProgress") or 0
	if activeQuestId ~= "" then
		local quest = QuestConfig.getQuestById(activeQuestId)
		if quest then
			activeQuestComplete = false
			-- Check if complete
			local obj = quest.objective
			if obj.type == "KILL" or obj.type == "KILL_ZONE" or obj.type == "KILL_BOSS" then
				activeQuestComplete = activeProgress >= (obj.count or 1)
			elseif obj.type == "OBTAIN" then
				activeQuestComplete = activeProgress >= 1
			elseif obj.type == "LEVEL" then
				local leaderstats = player:FindFirstChild("leaderstats")
				local lv = leaderstats and leaderstats:FindFirstChild("Level")
				if lv then activeQuestComplete = lv.Value >= (obj.target or 1) end
			end
		end
	end
	updateTracker()
end

player:GetAttributeChangedSignal("ActiveQuestId"):Connect(syncFromAttributes)
player:GetAttributeChangedSignal("QuestProgress"):Connect(syncFromAttributes)

-- Initial sync
syncFromAttributes()

-- ── Proximity loop ───────────────────────────────────────────────────────

RunService.Heartbeat:Connect(function()
	checkProximity()
end)

-- ── Player attribute watcher for LEVEL quests ────────────────────────────

local leaderstats = player:WaitForChild("leaderstats", 15)
if leaderstats then
	local levelVal = leaderstats:WaitForChild("Level", 10)
	if levelVal then
		levelVal.Changed:Connect(function()
			if activeQuestId ~= "" and not activeQuestComplete then
				local quest = QuestConfig.getQuestById(activeQuestId)
				if quest and quest.objective.type == "LEVEL" then
					syncFromAttributes()
				end
			end
		end)
	end
end

print("[QuestGui] Quest tracker and NPC interaction enabled")
