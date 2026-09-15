--// OnboardingGui (client) — gentle first-time-player guidance
-- No forced tutorials: a welcome overlay, directional arrow, and milestone hints.
-- All client-side; no new RemoteEvents required.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Constants ──────────────────────────────────────────────────────────────

local QUEST_MASTER_FALLBACK = Vector3.new(-42, 6.3, 12) -- only used before the NPC exists

-- The Quest Master is placed at runtime (baseplate layout or map marker), so look it up.
local function getQuestMasterPosition()
	local npc = workspace:FindFirstChild("Quest Master")
	local root = npc and (npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart)
	return if root then root.Position else QUEST_MASTER_FALLBACK
end

local COLORS = {
	Panel = Color3.fromRGB(12, 12, 14),
	PanelLight = Color3.fromRGB(22, 22, 26),
	Stroke = Color3.fromRGB(45, 45, 52),
	StrokeBright = Color3.fromRGB(70, 70, 80),
	Text = Color3.fromRGB(245, 245, 250),
	Muted = Color3.fromRGB(150, 150, 165),
	Accent = Color3.fromRGB(35, 35, 42),
	Success = Color3.fromRGB(90, 220, 140),
	Gold = Color3.fromRGB(255, 215, 0),
	Arrow = Color3.fromRGB(255, 215, 0),
}

-- Onboarding milestones
local STEP_EQUIP_SWORD = 1    -- sword in backpack but not equipped
local STEP_FIND_ENEMIES = 2   -- sword is equipped
local STEP_AUTO_ATTACK = 3    -- after first XP gain (proxy for first kill)
local STEP_OPEN_MENU = 4      -- after first level up

-- ── State ──────────────────────────────────────────────────────────────────

local onboardingComplete = false
local currentStep = STEP_EQUIP_SWORD
local hasSeenWelcome = false
local welcomeDismissed = false
local firstKillTriggered = false
local firstLevelUpTriggered = false

-- ── GUI scaffolding ────────────────────────────────────────────────────────

local existing = playerGui:FindFirstChild("OnboardingGui")
if existing then existing:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OnboardingGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 12
screenGui.IgnoreGuiInset = false
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

-- ── 1. WELCOME OVERLAY ────────────────────────────────────────────────────

local welcomeOverlay = Instance.new("TextButton")
welcomeOverlay.Name = "WelcomeOverlay"
welcomeOverlay.Size = UDim2.fromScale(1, 1)
welcomeOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
welcomeOverlay.BackgroundTransparency = 1
welcomeOverlay.BorderSizePixel = 0
welcomeOverlay.Text = ""
welcomeOverlay.AutoButtonColor = false
welcomeOverlay.Visible = false
welcomeOverlay.ZIndex = 50
welcomeOverlay.Parent = screenGui

local welcomeCard = Instance.new("Frame")
welcomeCard.Name = "WelcomeCard"
welcomeCard.AnchorPoint = Vector2.new(0.5, 0.5)
welcomeCard.Position = UDim2.fromScale(0.5, 0.5)
welcomeCard.Size = UDim2.fromOffset(380, 200)
welcomeCard.BackgroundColor3 = COLORS.Panel
welcomeCard.BackgroundTransparency = 1
welcomeCard.BorderSizePixel = 0
welcomeCard.ZIndex = 51
welcomeCard.Parent = welcomeOverlay
addCorner(welcomeCard, 18)
local welcomeStroke = addStroke(welcomeCard, COLORS.StrokeBright, 1, 1.5)

local welcomeTitle = Instance.new("TextLabel")
welcomeTitle.BackgroundTransparency = 1
welcomeTitle.Font = Enum.Font.GothamBlack
welcomeTitle.TextSize = 28
welcomeTitle.TextColor3 = COLORS.Text
welcomeTitle.TextTransparency = 1
welcomeTitle.Text = "Welcome to Lemonade"
welcomeTitle.Size = UDim2.new(1, -40, 0, 40)
welcomeTitle.Position = UDim2.fromOffset(20, 30)
welcomeTitle.TextXAlignment = Enum.TextXAlignment.Center
welcomeTitle.ZIndex = 52
welcomeTitle.Parent = welcomeCard

local welcomeDesc = Instance.new("TextLabel")
welcomeDesc.BackgroundTransparency = 1
welcomeDesc.Font = Enum.Font.Gotham
welcomeDesc.TextSize = 15
welcomeDesc.TextColor3 = COLORS.Muted
welcomeDesc.TextTransparency = 1
welcomeDesc.TextWrapped = true
welcomeDesc.Text = "Defeat enemies, collect swords, and grow stronger.\nExplore the world at your own pace."
welcomeDesc.Size = UDim2.new(1, -40, 0, 50)
welcomeDesc.Position = UDim2.fromOffset(20, 80)
welcomeDesc.TextXAlignment = Enum.TextXAlignment.Center
welcomeDesc.ZIndex = 52
welcomeDesc.Parent = welcomeCard

local welcomeHint = Instance.new("TextLabel")
welcomeHint.BackgroundTransparency = 1
welcomeHint.Font = Enum.Font.Gotham
welcomeHint.TextSize = 12
welcomeHint.TextColor3 = COLORS.StrokeBright
welcomeHint.TextTransparency = 1
welcomeHint.Text = "click anywhere or wait to continue"
welcomeHint.Size = UDim2.new(1, -40, 0, 18)
welcomeHint.Position = UDim2.fromOffset(20, 155)
welcomeHint.TextXAlignment = Enum.TextXAlignment.Center
welcomeHint.ZIndex = 52
welcomeHint.Parent = welcomeCard

local welcomeTweenIn = function()
	welcomeOverlay.Visible = true
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(welcomeOverlay, tweenInfo, { BackgroundTransparency = 0.55 }):Play()
	TweenService:Create(welcomeCard, tweenInfo, { BackgroundTransparency = 0.04 }):Play()
	TweenService:Create(welcomeStroke, tweenInfo, { Transparency = 0.2 }):Play()
	TweenService:Create(welcomeTitle, tweenInfo, { TextTransparency = 0 }):Play()
	TweenService:Create(welcomeDesc, tweenInfo, { TextTransparency = 0 }):Play()
	TweenService:Create(welcomeHint, tweenInfo, { TextTransparency = 0.3 }):Play()
end

local welcomeTweenOut = function()
	local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(welcomeOverlay, tweenInfo, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(welcomeCard, tweenInfo, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(welcomeStroke, tweenInfo, { Transparency = 1 }):Play()
	TweenService:Create(welcomeTitle, tweenInfo, { TextTransparency = 1 }):Play()
	TweenService:Create(welcomeDesc, tweenInfo, { TextTransparency = 1 }):Play()
	TweenService:Create(welcomeHint, tweenInfo, { TextTransparency = 1 }):Play()
	task.delay(0.4, function()
		welcomeOverlay.Visible = false
		welcomeDismissed = true
	end)
end

local function dismissWelcome()
	if welcomeDismissed then return end
	welcomeDismissed = true
	welcomeTweenOut()
end

welcomeOverlay.Activated:Connect(dismissWelcome)

local function showWelcome()
	if hasSeenWelcome then return end
	hasSeenWelcome = true
	welcomeTweenIn()
	-- Auto-dismiss after 5 seconds
	task.delay(5, function()
		dismissWelcome()
	end)
end

-- ── 2. DIRECTIONAL ARROW HUD ──────────────────────────────────────────────

local arrowVisible = false

local arrowFrame = Instance.new("Frame")
arrowFrame.Name = "QuestArrow"
arrowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
arrowFrame.Position = UDim2.new(0.5, 0, 0, 80)
arrowFrame.Size = UDim2.fromOffset(48, 48)
arrowFrame.BackgroundTransparency = 1
arrowFrame.Visible = false
arrowFrame.ZIndex = 8
arrowFrame.Parent = screenGui

-- Chevron arrow built from a rotated square + clipping to create a ">" shape
local arrowImage = Instance.new("ImageLabel")
arrowImage.Name = "ArrowChevron"
arrowImage.Size = UDim2.fromOffset(40, 40)
arrowImage.Position = UDim2.fromOffset(4, 4)
arrowImage.BackgroundTransparency = 1
arrowImage.Image = "rbxassetid://3926305904" -- Roblox built-in chevron/arrow
arrowImage.ImageRectOffset = Vector2.new(364, 232)
arrowImage.ImageRectSize = Vector2.new(72, 72)
arrowImage.ImageColor3 = COLORS.Arrow
arrowImage.ScaleType = Enum.ScaleType.Fit
arrowImage.ZIndex = 8
arrowImage.Parent = arrowFrame

-- Pulsing glow effect
local arrowGlow = Instance.new("ImageLabel")
arrowGlow.Name = "ArrowGlow"
arrowGlow.Size = UDim2.fromOffset(56, 56)
arrowGlow.Position = UDim2.fromOffset(-4, -4)
arrowGlow.BackgroundTransparency = 1
arrowGlow.Image = "rbxassetid://3926305904"
arrowGlow.ImageRectOffset = Vector2.new(364, 232)
arrowGlow.ImageRectSize = Vector2.new(72, 72)
arrowGlow.ImageColor3 = COLORS.Arrow
arrowGlow.ImageTransparency = 0.6
arrowGlow.ScaleType = Enum.ScaleType.Fit
arrowGlow.ZIndex = 7
arrowGlow.Parent = arrowFrame

local arrowLabel = Instance.new("TextLabel")
arrowLabel.BackgroundTransparency = 1
arrowLabel.Font = Enum.Font.GothamBold
arrowLabel.TextSize = 11
arrowLabel.TextColor3 = COLORS.Arrow
arrowLabel.Text = "Quest Master"
arrowLabel.Size = UDim2.fromOffset(100, 16)
arrowLabel.Position = UDim2.fromOffset(-26, 48)
arrowLabel.TextXAlignment = Enum.TextXAlignment.Center
arrowLabel.ZIndex = 8
arrowLabel.Visible = false
arrowLabel.Parent = arrowFrame

local function setArrowVisible(visible)
	if arrowVisible == visible then return end
	arrowVisible = visible
	arrowFrame.Visible = visible
	if visible then
		arrowFrame.BackgroundTransparency = 1
		TweenService:Create(arrowFrame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	end
end

-- Arrow rotation update on RenderStepped
local arrowPulseTime = 0
RunService.RenderStepped:Connect(function(dt)
	if not arrowVisible then return end

	local camera = workspace.CurrentCamera
	if not camera then return end

	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Calculate screen-space direction to quest master
	local screenPos, onScreen = camera:WorldToScreenPoint(getQuestMasterPosition())

	if onScreen then
		-- Point arrow toward the NPC on screen
		local arrowCenter = Vector2.new(
			arrowFrame.AbsolutePosition.X + arrowFrame.AbsoluteSize.X / 2,
			arrowFrame.AbsolutePosition.Y + arrowFrame.AbsoluteSize.Y / 2
		)
		local delta = Vector2.new(screenPos.X - arrowCenter.X, screenPos.Y - arrowCenter.Y)
		local angle = math.atan2(delta.Y, delta.X)
		arrowFrame.Rotation = math.deg(angle)
	else
		-- When NPC is off-screen, rotate toward the screen edge direction
		local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
		local clampedX = math.clamp(screenPos.X, 0, camera.ViewportSize.X)
		local clampedY = math.clamp(screenPos.Y, 0, camera.ViewportSize.Y)
		local delta = Vector2.new(clampedX - screenCenter.X, clampedY - screenCenter.Y)
		local angle = math.atan2(delta.Y, delta.X)
		arrowFrame.Rotation = math.deg(angle)
	end

	-- Pulse effect
	arrowPulseTime += dt
	local pulse = 0.85 + 0.15 * math.sin(arrowPulseTime * 3)
	arrowImage.Size = UDim2.fromOffset(40 * pulse, 40 * pulse)
	arrowImage.Position = UDim2.fromOffset(4 + (40 - 40 * pulse) / 2, 4 + (40 - 40 * pulse) / 2)
end)

-- ── 3. MILESTONE HINT TOASTS ──────────────────────────────────────────────

local hintQueue = {}
local hintShowing = false

local function showToast(message, duration)
	duration = duration or 3

	local toast = Instance.new("Frame")
	toast.Name = "OnboardingToast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, -50)
	toast.Size = UDim2.fromOffset(320, 48)
	toast.BackgroundColor3 = COLORS.Panel
	toast.BackgroundTransparency = 1
	toast.BorderSizePixel = 0
	toast.ZIndex = 40
	toast.Parent = screenGui
	addCorner(toast, 10)
	local toastStroke = addStroke(toast, COLORS.StrokeBright, 1, 1.2)

	local iconBadge = Instance.new("Frame")
	iconBadge.Size = UDim2.fromOffset(28, 28)
	iconBadge.Position = UDim2.fromOffset(10, 10)
	iconBadge.BackgroundColor3 = COLORS.Accent
	iconBadge.BackgroundTransparency = 1
	iconBadge.BorderSizePixel = 0
	iconBadge.ZIndex = 41
	iconBadge.Parent = toast
	addCorner(iconBadge, 6)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.BackgroundTransparency = 1
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextSize = 14
	iconLabel.TextColor3 = COLORS.Gold
	iconLabel.TextTransparency = 1
	iconLabel.Text = "!"
	iconLabel.ZIndex = 42
	iconLabel.Parent = iconBadge

	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.Gotham
	textLabel.TextSize = 14
	textLabel.TextColor3 = COLORS.Text
	textLabel.TextTransparency = 1
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.Text = message
	textLabel.Position = UDim2.fromOffset(46, 0)
	textLabel.Size = UDim2.new(1, -56, 1, 0)
	textLabel.ZIndex = 41
	textLabel.Parent = toast

	-- Slide in
	local tweenIn = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(toast, tweenIn, { Position = UDim2.new(0.5, 0, 0, 16), BackgroundTransparency = 0.08 }):Play()
	TweenService:Create(toastStroke, tweenIn, { Transparency = 0.25 }):Play()
	TweenService:Create(iconBadge, tweenIn, { BackgroundTransparency = 0.15 }):Play()
	TweenService:Create(iconLabel, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
	TweenService:Create(textLabel, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()

	task.delay(duration, function()
		local tweenOut = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(toast, tweenOut, {
			Position = UDim2.new(0.5, 0, 0, -50),
			BackgroundTransparency = 1
		}):Play()
		TweenService:Create(toastStroke, tweenOut, { Transparency = 1 }):Play()
		TweenService:Create(iconBadge, tweenOut, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(iconLabel, tweenOut, { TextTransparency = 1 }):Play()
		TweenService:Create(textLabel, tweenOut, { TextTransparency = 1 }):Play()
		task.delay(0.35, function()
			toast:Destroy()
		end)
	end)
end

local function queueHint(message)
	table.insert(hintQueue, message)
	if not hintShowing then
		hintShowing = true
		while #hintQueue > 0 do
			local msg = table.remove(hintQueue, 1)
			showToast(msg, 3)
			task.wait(3.5) -- slight gap between queued toasts
		end
		hintShowing = false
	end
end

-- ── 4. STEP MANAGEMENT ────────────────────────────────────────────────────

local function getEquippedTool()
	local character = player.Character
	if not character then return nil end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then return child end
	end
	return nil
end

local function hasSwordInBackpack()
	local bp = player:FindFirstChildOfClass("Backpack")
	if not bp then return false end
	for _, child in ipairs(bp:GetChildren()) do
		if child:IsA("Tool") then return true end
	end
	return false
end

local function advanceStep(step)
	if step <= currentStep then return end
	currentStep = step

	if step == STEP_FIND_ENEMIES then
		queueHint("Sword equipped! Find enemies in Iron Lowlands")
	elseif step == STEP_AUTO_ATTACK then
		queueHint("Tip: Press Q for auto-attack")
	elseif step == STEP_OPEN_MENU then
		queueHint("Press M to open the menu")
		-- After showing the menu hint, onboarding is effectively done
		task.delay(4, function()
			onboardingComplete = true
		end)
	end
end

-- ── 5. MAIN MONITORING LOOP ───────────────────────────────────────────────

local function waitForDataLoaded()
	if player:GetAttribute("DataLoaded") == true then return true end
	local signal = player:GetAttributeChangedSignal("DataLoaded")
	-- Wait up to 30 seconds for data
	local timeout = tick() + 30
	while tick() < timeout do
		if player:GetAttribute("DataLoaded") == true then return true end
		signal:Wait()
	end
	return false
end

local function initOnboarding()
	-- Wait for data to load before deciding whether to show welcome
	local dataReady = waitForDataLoaded()
	if not dataReady then return end

	-- Check if the player has already completed onboarding on a previous session
	-- We use a local flag plus a level check: if level > 1 or has quests, skip welcome
	local level = 1
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelVal = leaderstats and leaderstats:FindFirstChild("Level")
	if levelVal then level = levelVal.Value end

	local hasCompletedQuests = (player:GetAttribute("CompletedQuests") or "") ~= ""
	local activeQuest = player:GetAttribute("ActiveQuestId") or ""

	-- Player is NOT brand-new if they already have levels, completed quests, or an active quest
	if level > 1 or hasCompletedQuests or activeQuest ~= "" then
		onboardingComplete = true
		return
	end

	-- Brand new player: show welcome overlay
	showWelcome()

	-- Wait for welcome to be dismissed before starting milestone tracking
	while not welcomeDismissed do
		task.wait(0.2)
	end

	-- Brief pause after welcome before first hint
	task.wait(1)
end

-- ── 6. MILESTONE WATCHERS ─────────────────────────────────────────────────

local function startMilestoneTracking()
	-- Step 1: Equip your sword
	-- Show hint when sword is in backpack but not equipped
	local function checkEquipState()
		if onboardingComplete then return end
		if currentStep >= STEP_FIND_ENEMIES then return end

		local equipped = getEquippedTool()
		if equipped then
			-- Player has equipped something — advance
			advanceStep(STEP_FIND_ENEMIES)
			setArrowVisible(false)
		elseif hasSwordInBackpack() and currentStep < STEP_EQUIP_SWORD + 1 then
			-- Sword in backpack, not yet equipped — hint shown once
			if currentStep == STEP_EQUIP_SWORD then
				queueHint("Equip your sword from your backpack")
				setArrowVisible(true) -- Show arrow pointing to quest master as a general guide
			end
		end
	end

	-- Step 3: First kill (detected via XP gain on leaderstats)
	local experienceValue = nil
	if player:FindFirstChild("leaderstats") then
		experienceValue = player.leaderstats:FindFirstChild("Experience")
	end
	if experienceValue then
		local startXP = experienceValue.Value
		experienceValue.Changed:Connect(function(newVal)
			if onboardingComplete then return end
			if not firstKillTriggered and newVal > startXP then
				firstKillTriggered = true
				advanceStep(STEP_AUTO_ATTACK)
			end
		end)
	end

	-- Step 4: First level up
	local levelValue = nil
	if player:FindFirstChild("leaderstats") then
		levelValue = player.leaderstats:FindFirstChild("Level")
	end
	if levelValue then
		local startLevel = levelValue.Value
		levelValue.Changed:Connect(function(newVal)
			if onboardingComplete then return end
			if not firstLevelUpTriggered and newVal > startLevel then
				firstLevelUpTriggered = true
				advanceStep(STEP_OPEN_MENU)
			end
		end)
	end

	-- Watch for quest accepted (hide arrow, mark onboarding advancement)
	player:GetAttributeChangedSignal("ActiveQuestId"):Connect(function()
		local questId = player:GetAttribute("ActiveQuestId") or ""
		if questId ~= "" then
			setArrowVisible(false)
			-- If player got a quest before equipping, skip ahead
			if currentStep < STEP_FIND_ENEMIES then
				advanceStep(STEP_FIND_ENEMIES)
			end
		end
	end)

	-- Character respawn: re-check equip state
	player.CharacterAdded:Connect(function()
		task.wait(1)
		checkEquipState()
	end)

	-- Backpack child changes: detect new swords appearing
	local function bindBackpack()
		local bp = player:FindFirstChildOfClass("Backpack")
		if not bp then return end
		bp.ChildAdded:Connect(function()
			task.defer(checkEquipState)
		end)
	end

	local function bindCharacter()
		local ch = player.Character
		if not ch then return end
		ch.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				task.defer(checkEquipState)
			end
		end)
	end

	bindBackpack()
	bindCharacter()
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		bindCharacter()
		checkEquipState()
	end)

	-- Initial check
	checkEquipState()
end

-- ── 7. BOOT ───────────────────────────────────────────────────────────────

task.spawn(function()
	initOnboarding()
	if not onboardingComplete then
		startMilestoneTracking()
	end
end)

print("[OnboardingGui] Onboarding guidance enabled")
