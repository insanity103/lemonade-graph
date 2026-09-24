--// QuestGui  (client-side quest tracker HUD + NPC interaction)
-- Bright chunky style from PanelChrome: the Quest Master's window is a quest card (objective
-- headline, progress bar, boxed reward, chunky buttons) beside a grid of the whole quest chain,
-- and a tracker card stays on screen at the right edge, beside the side-button column.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = workspace

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local QuestConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("QuestConfig"))

-- What a reward is actually worth to THIS player right now. Gold quests are priced in kills'
-- worth at the level the quest is handed in (QuestConfig.GoldReward, the same call QuestSystem
-- makes when it pays), so the card must ask rather than print the listed figure -- otherwise the
-- number on screen is not the number the player receives.
local function rewardAmount(reward): number
	if typeof(reward) ~= "table" then return 0 end
	if reward.type == "GOLD" then
		return QuestConfig.GoldReward(reward, player:GetAttribute("Level") or 1)
	end
	return tonumber(reward.amount) or 0
end
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local QUEST_ACCEPT = remotes:WaitForChild("QuestAccept")
local QUEST_UPDATE = remotes:WaitForChild("QuestUpdate")
local QUEST_COMPLETE = remotes:WaitForChild("QuestComplete")
local QUEST_REWARD = remotes:WaitForChild("QuestReward")

-- ── Palette, icons & design-space sizes ──────────────────────────────────
local BRIGHT = PanelChrome.BRIGHT
local corner = PanelChrome.corner
local WHITE = Color3.new(1, 1, 1)

local THEME = {
	CardTop = Color3.fromRGB(126, 218, 255), CardBottom = Color3.fromRGB(52, 146, 238),
	Track = Color3.fromRGB(26, 42, 90),
	BarTop = Color3.fromRGB(255, 236, 110), BarBottom = Color3.fromRGB(246, 160, 24),
	DoneTop = Color3.fromRGB(170, 248, 120), DoneBottom = Color3.fromRGB(52, 176, 58),
	QuestGold = Color3.fromRGB(255, 214, 60),
	Shadow = Color3.fromRGB(8, 10, 24),
}

local ICONS = { -- images the HUD and tooltips already use
	Coin = "rbxassetid://84697600263846",
	Sword = "rbxassetid://94091032987086",
	Trophy = "rbxassetid://77830885604568",
	Star = "rbxassetid://112684829478873",
	Target = "rbxassetid://120517988406723",
	Lighting = "rbxassetid://91519647625054",
	Skills = "rbxassetid://134595823778256",
}

local OBJECTIVE_ICONS = {
	KILL = ICONS.Sword, KILL_ZONE = ICONS.Sword, KILL_BOSS = ICONS.Target,
	OBTAIN = ICONS.Trophy, OBTAIN_POOL = ICONS.Trophy, LEVEL = ICONS.Star,
}

local REWARD_COLORS = {
	GOLD = BRIGHT.Gold,
	XP = Color3.fromRGB(120, 236, 130),
	LEVEL = Color3.fromRGB(120, 200, 255),
	SKILL_POINTS = Color3.fromRGB(206, 140, 255),
}

local REWARD_LABELS = {
	GOLD = "Gold",
	XP = "XP",
	LEVEL = "Level(s)",
	SKILL_POINTS = "Skill Points",
}

local REWARD_UNITS = { GOLD = "Gold", XP = "XP", LEVEL = "Levels", SKILL_POINTS = "Skill Pts" }
local REWARD_ICONS = { GOLD = ICONS.Coin, XP = ICONS.Star, LEVEL = ICONS.Trophy, SKILL_POINTS = ICONS.Skills }

-- [TUNING] design-space sizes; the whole window scales with one UIScale.
local PAD, GAP = 22, 20 -- window side padding, gap between the card column and the chain grid
local TOP, BOTTOM = 54, 22 -- the title rides the top edge; content starts under it
local LEFT_W, RIGHT_W = 392, 372
local FLAVOR_H, CARD_H, REWARD_H, BUTTONS_H, STACK_GAP = 48, 204, 86, 82, 12
local CELL_W, CELL_H, CELL_GAP = 110, 122, 12
local WIDE_MIN = 700 -- narrower screens drop the chain grid and keep just the quest card
local SHORT_MAX = 430 -- shorter screens drop the flavour bubble so the buttons stay 44 px+
local TRACKER_W = PanelChrome.HUD.QuestWidth -- 324; the top-right spin popup (SpinPopup) matches it

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

-- The Quest Master's window lives in its own layer with the other modals (20+), above the
-- sword hotbar (13); the tracker and the dim stay down here on the HUD layer.
local existingDialog = playerGui:FindFirstChild("QuestDialogGui")
if existingDialog then existingDialog:Destroy() end
local dialogGui = Instance.new("ScreenGui")
dialogGui.Name = "QuestDialogGui"
dialogGui.ResetOnSpawn = false
dialogGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
dialogGui.DisplayOrder = 19
dialogGui.Parent = playerGui

local function display(parent, props)
	return PanelChrome.display(parent, props)
end

-- Flat ink text (no outline), for captions that sit on the light panel.
local function ink(parent, props)
	local label = Instance.new("TextLabel")
	label.Name = props.name or "Ink"
	label.BackgroundTransparency = 1
	label.Font = props.font or PanelChrome.DISPLAY_FONT
	label.Text = props.text or ""
	label.TextColor3 = props.color or BRIGHT.Ink
	label.TextSize = props.size or 20
	label.TextXAlignment = props.xAlign or Enum.TextXAlignment.Left
	label.Size = props.size2 or UDim2.fromScale(1, 1)
	label.Position = props.pos or UDim2.new()
	if props.anchor then label.AnchorPoint = props.anchor end
	label.ZIndex = props.zIndex or 2
	label.Parent = parent
	return label
end

local function image(parent, id, size, pos, anchor, z)
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = id or ""
	img.ScaleType = Enum.ScaleType.Fit
	img.Size = size
	img.Position = pos or UDim2.new()
	img.AnchorPoint = anchor or Vector2.new(0, 0)
	img.ZIndex = z or 2
	img.Parent = parent
	return img
end

local function shine(parent, z, radius, height)
	local s = Instance.new("Frame")
	s.Name = "Shine"
	s.BackgroundColor3 = WHITE
	s.BorderSizePixel = 0
	s.Position = UDim2.fromOffset(6, 4)
	s.Size = UDim2.new(1, -12, height or 0.4, 0)
	s.ZIndex = z
	s.Parent = parent
	corner(s, radius)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new(0.45, 0.92)
	g.Parent = s
	return s
end

-- Chunky progress bar: navy track, gold (or green when done) glossy fill, stroked count.
local function progressBar(parent, height, textSize, z)
	local track = Instance.new("Frame")
	track.Name = "ProgressBar"
	track.Size = UDim2.new(1, 0, 0, height)
	track.BackgroundColor3 = THEME.Track
	track.BorderSizePixel = 0
	track.ZIndex = z
	track.Parent = parent
	corner(track, height // 2)
	PanelChrome.stroke(track, BRIGHT.Outline, 3)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = WHITE
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.ZIndex = z + 1
	fill.Parent = track
	corner(fill, height // 2)
	local fillGradient = PanelChrome.gradient(fill, THEME.BarTop, THEME.BarBottom)
	local gloss = shine(fill, z + 1, height // 3, 0.42)
	gloss.Position = UDim2.fromOffset(4, 3)
	gloss.Size = UDim2.new(1, -8, 0.36, 0)

	local count = display(track, { name = "Count", text = "", size = textSize, stroke = 2.5, zIndex = z + 3 })

	local check = PanelChrome.checkBadge(track, height + 8, z + 4)
	check.Position = UDim2.new(1, -4, 0.5, 0)
	check.Visible = false

	local bar = { Frame = track, Count = count, Check = check }
	function bar.set(frac, text, complete)
		frac = math.clamp(frac or 0, 0, 1)
		count.Text = text
		fill.Visible = frac > 0
		fillGradient.Color = complete and ColorSequence.new(THEME.DoneTop, THEME.DoneBottom)
			or ColorSequence.new(THEME.BarTop, THEME.BarBottom)
		check.Visible = complete == true
		TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(frac, 0, 1, 0),
		}):Play()
	end
	return bar
end

-- A chunky button standing on a dark drop shadow; the holder is what the layouts move.
local function shadowedButton(parent, props)
	local holder = Instance.new("Frame")
	holder.Name = (props.name or "Button") .. "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = props.size
	holder.LayoutOrder = props.order or 0
	holder.ZIndex = 3
	holder.Parent = parent
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = THEME.Shadow
	shadow.BackgroundTransparency = 0.45
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(0, 7)
	shadow.Size = UDim2.new(1, 0, 1, -7)
	shadow.ZIndex = 3
	shadow.Parent = holder
	corner(shadow, 20)
	local btn, label = PanelChrome.chunkyButton(holder, {
		name = props.name, text = props.text, color = props.color, colorDark = props.colorDark,
		size = UDim2.new(1, 0, 1, -7), textSize = props.textSize or 32, zIndex = 4, radius = 20,
		strokeThickness = 3.5,
	})
	return btn, holder, label
end

-- ── Quest data helpers ───────────────────────────────────────────────────

local function currentLevel()
	local leaderstats = player:FindFirstChild("leaderstats")
	local lv = leaderstats and leaderstats:FindFirstChild("Level")
	return lv and lv.Value or 1
end

local function completedSet()
	local completed = {}
	local raw = player:GetAttribute("CompletedQuests") or ""
	if raw ~= "" then
		for id in string.gmatch(raw, "[^,]+") do completed[id] = true end
	end
	return completed
end

-- The objective as a headline: the quest's own sentence, without its full stop.
local function getObjectiveHeadline(quest)
	local text = quest.description or quest.name
	return (string.gsub(text, "%.$", ""))
end

-- Current and target counts, and the text the bars show.
local function getProgressCounts(quest, progress)
	local obj = quest.objective
	if obj.type == "KILL" or obj.type == "KILL_ZONE" or obj.type == "KILL_BOSS" then
		local target = obj.count or 1
		local cur = math.min(progress, target)
		return cur / target, string.format("%d / %d", cur, target)
	elseif obj.type == "OBTAIN" or obj.type == "OBTAIN_POOL" then
		local got = progress >= 1
		return got and 1 or 0, got and "Found!" or "0 / 1"
	elseif obj.type == "LEVEL" then
		local level = currentLevel()
		local target = obj.target or 1
		return math.clamp(level / target, 0, 1), string.format("Lv %d / %d", level, target)
	end
	return 0, ""
end

local function shortNumber(n)
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e4 then return string.format("%.1fK", n / 1e3) end
	return tostring(n)
end

-- ── Quest Tracker HUD (right edge, beside the side-button column) ────────

local trackerFrame = Instance.new("Frame")
trackerFrame.Name = "QuestTracker"
trackerFrame.AnchorPoint = Vector2.new(1, 0)
trackerFrame.Position = UDim2.new(1, -110, 0, 140)
trackerFrame.Size = UDim2.fromOffset(TRACKER_W, 0) -- height follows the body (fitTracker below)
trackerFrame.BackgroundColor3 = WHITE
trackerFrame.BorderSizePixel = 0
trackerFrame.Visible = false
trackerFrame.ZIndex = 5
trackerFrame.Parent = screenGui
corner(trackerFrame, 18)
PanelChrome.gradient(trackerFrame, BRIGHT.Panel, BRIGHT.PanelBottom)
PanelChrome.stroke(trackerFrame, BRIGHT.Outline, 3.5)
local trackerScale = Instance.new("UIScale")
trackerScale.Parent = trackerFrame

-- Gold "!" medallion riding the card's top-left corner.
local trackerBadge = Instance.new("Frame")
trackerBadge.Name = "QuestBadge"
trackerBadge.AnchorPoint = Vector2.new(0.5, 0.5)
trackerBadge.Position = UDim2.fromOffset(6, 6)
trackerBadge.Size = UDim2.fromOffset(44, 44)
trackerBadge.BackgroundColor3 = WHITE
trackerBadge.Rotation = -10
trackerBadge.ZIndex = 8
trackerBadge.Parent = trackerFrame
corner(trackerBadge, 22)
PanelChrome.gradient(trackerBadge, Color3.fromRGB(255, 236, 120), BRIGHT.GoldDark)
PanelChrome.stroke(trackerBadge, BRIGHT.Outline, 3)
display(trackerBadge, { text = "!", size = 32, stroke = 3, zIndex = 9 })
local badgeScale = Instance.new("UIScale")
badgeScale.Parent = trackerBadge

-- The card's contents live in a clipping lane so the card can fold down to its compact tab (see
-- "Minimize" below): the full body keeps its 324 px layout and is cut away as the card narrows
-- towards its top-right corner, while the tab fades in over the same corner.
local trackerClip = Instance.new("Frame")
trackerClip.Name = "Clip"
trackerClip.BackgroundTransparency = 1
trackerClip.Size = UDim2.fromScale(1, 1)
trackerClip.ClipsDescendants = true
trackerClip.ZIndex = 6
trackerClip.Parent = trackerFrame

local trackerBody = Instance.new("CanvasGroup")
trackerBody.Name = "Body"
trackerBody.BackgroundTransparency = 1
trackerBody.AnchorPoint = Vector2.new(1, 0)
trackerBody.Position = UDim2.fromScale(1, 0)
trackerBody.Size = UDim2.fromOffset(TRACKER_W, 0)
trackerBody.AutomaticSize = Enum.AutomaticSize.Y
trackerBody.ZIndex = 6
trackerBody.Parent = trackerClip

local trackerPadding = Instance.new("UIPadding")
trackerPadding.PaddingTop = UDim.new(0, 10)
trackerPadding.PaddingRight = UDim.new(0, 14)
trackerPadding.PaddingBottom = UDim.new(0, 12)
trackerPadding.PaddingLeft = UDim.new(0, 30)
trackerPadding.Parent = trackerBody

local trackerLayout = Instance.new("UIListLayout")
trackerLayout.Padding = UDim.new(0, 6)
trackerLayout.SortOrder = Enum.SortOrder.LayoutOrder
trackerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
trackerLayout.Parent = trackerBody

-- Quest name (gold, like a rank line)
local questNameLabel = display(trackerBody, {
	name = "QuestName", text = "", size = 20, stroke = 2.5, color = THEME.QuestGold,
	xAlign = Enum.TextXAlignment.Right, size2 = UDim2.new(1, 0, 0, 22), zIndex = 7,
})
questNameLabel.LayoutOrder = 1
questNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
do -- keep the name clear of the minimize button riding the card's top-right corner
	local namePad = Instance.new("UIPadding")
	namePad.PaddingRight = UDim.new(0, 30)
	namePad.Parent = questNameLabel
end

-- Objective headline
local questDescLabel = display(trackerBody, {
	name = "QuestDesc", text = "", size = 28, stroke = 3,
	xAlign = Enum.TextXAlignment.Right, size2 = UDim2.new(1, 0, 0, 0), zIndex = 7,
})
questDescLabel.TextWrapped = true
questDescLabel.AutomaticSize = Enum.AutomaticSize.Y
questDescLabel.LayoutOrder = 2

-- Progress bar + reward, right-aligned on one row
local trackerBarRow = Instance.new("Frame")
trackerBarRow.Name = "ProgressRow"
trackerBarRow.BackgroundTransparency = 1
trackerBarRow.Size = UDim2.new(1, 0, 0, 34)
trackerBarRow.LayoutOrder = 3
trackerBarRow.ZIndex = 7
trackerBarRow.Parent = trackerBody

local trackerBarHolder = Instance.new("Frame")
trackerBarHolder.BackgroundTransparency = 1
trackerBarHolder.Size = UDim2.new(1, -124, 1, -4)
trackerBarHolder.Position = UDim2.fromOffset(0, 2)
trackerBarHolder.ZIndex = 7
trackerBarHolder.Parent = trackerBarRow
local trackerBar = progressBar(trackerBarHolder, 30, 20, 7)

local trackerRewardIcon = image(trackerBarRow, ICONS.Coin, UDim2.fromOffset(36, 36),
	UDim2.new(1, -60, 0.5, 0), Vector2.new(1, 0.5), 8)
trackerRewardIcon.Rotation = -10
local trackerRewardAmount = display(trackerBarRow, {
	name = "RewardAmount", text = "", size = 22, stroke = 2.5, xAlign = Enum.TextXAlignment.Left,
	anchor = Vector2.new(1, 0.5), pos = UDim2.new(1, 0, 0.5, 0), size2 = UDim2.fromOffset(58, 30), zIndex = 8,
	scaled = true, minSize = 12,
})

-- Hint line: what to do next
local progressLabel = display(trackerBody, {
	name = "ProgressText", text = "", size = 17, stroke = 2, color = THEME.QuestGold,
	xAlign = Enum.TextXAlignment.Right, size2 = UDim2.new(1, 0, 0, 20), zIndex = 7,
})
progressLabel.LayoutOrder = 4

-- ── Minimize: the card folds into a compact tab that still shows progress ─
-- A round chunky button rides the card's top-right corner (mirroring the "!" medallion on the
-- left). Pressing it folds the card towards that corner into a small tab: quest name over a
-- mini progress bar with the live count. The button stays under the pointer (the card is
-- anchored top-right), turns into a "+", and pressing it or anywhere on the tab restores the card.
-- The state lasts the whole session (a client-side player attribute, so it survives respawns);
-- there is no settings field in the save to persist it further.
local TAB_W, TAB_H = PanelChrome.HUD.QuestTabWidth, PanelChrome.HUD.QuestTabHeight
local MIN_ATTR = "QuestTrackerMinimized"
local FOLD_TIME, UNFOLD_TIME = 0.26, 0.30 -- [TUNING] seconds
local minimized = player:GetAttribute(MIN_ATTR) == true
local folding = false -- a fold/unfold is running; it drives the card's size itself

local trackerTab = Instance.new("CanvasGroup")
trackerTab.Name = "Tab"
trackerTab.BackgroundTransparency = 1
trackerTab.AnchorPoint = Vector2.new(1, 0)
trackerTab.Position = UDim2.fromScale(1, 0)
trackerTab.Size = UDim2.fromOffset(TAB_W, TAB_H)
trackerTab.GroupTransparency = 1
trackerTab.Visible = false
trackerTab.ZIndex = 6
trackerTab.Parent = trackerClip

local tabName = display(trackerTab, {
	name = "QuestName", text = "", size = 19, stroke = 2.5, color = THEME.QuestGold,
	xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(32, 6), size2 = UDim2.new(1, -76, 0, 22), zIndex = 7,
})
tabName.TextTruncate = Enum.TextTruncate.AtEnd
local tabBarHolder = Instance.new("Frame")
tabBarHolder.Name = "ProgressRow"
tabBarHolder.BackgroundTransparency = 1
tabBarHolder.Position = UDim2.fromOffset(14, 31)
tabBarHolder.Size = UDim2.new(1, -30, 0, 22)
tabBarHolder.ZIndex = 7
tabBarHolder.Parent = trackerTab
local tabBar = progressBar(tabBarHolder, 22, 16, 7)

-- The whole tab is a restore target (a big, easy hit on a phone).
local tabHit = Instance.new("TextButton")
tabHit.Name = "RestoreArea"
tabHit.BackgroundTransparency = 1
tabHit.Text = ""
tabHit.Size = UDim2.fromScale(1, 1)
tabHit.ZIndex = 12
tabHit.Visible = false
tabHit.Parent = trackerTab

-- Minimize / restore button: a 36 px face inside a 60 px invisible hit area (39 px at the
-- smallest phone HUD scale), so it is easy to hit without crowding the card.
local minHit = Instance.new("TextButton")
minHit.Name = "MinimizeButton"
minHit.BackgroundTransparency = 1
minHit.Text = ""
minHit.AnchorPoint = Vector2.new(0.5, 0.5)
minHit.Position = UDim2.new(1, -22, 0, 2)
minHit.Size = UDim2.fromOffset(60, 60)
minHit.ZIndex = 14
minHit.Parent = trackerFrame
local minFace = Instance.new("Frame")
minFace.Name = "Face"
minFace.AnchorPoint = Vector2.new(0.5, 0.5)
minFace.Position = UDim2.fromScale(0.5, 0.5)
minFace.Size = UDim2.fromOffset(36, 36)
minFace.BackgroundColor3 = WHITE
minFace.ZIndex = 14
minFace.Parent = minHit
corner(minFace, 18)
PanelChrome.gradient(minFace, Color3.fromRGB(150, 214, 255), Color3.fromRGB(48, 138, 246))
PanelChrome.stroke(minFace, BRIGHT.Outline, 3)
local minFaceScale = Instance.new("UIScale")
minFaceScale.Parent = minFace
local minGloss = shine(minFace, 14, 10, 0.4)
minGloss.Position = UDim2.fromOffset(6, 3)
minGloss.Size = UDim2.new(1, -12, 0.38, 0)
local function glyphBar(name)
	local b = Instance.new("Frame")
	b.Name = name
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.fromScale(0.5, 0.5)
	b.BackgroundColor3 = WHITE
	b.BorderSizePixel = 0
	b.ZIndex = 16
	b.Parent = minFace
	corner(b, 3)
	PanelChrome.stroke(b, BRIGHT.Outline, 2)
	return b
end
local glyphH = glyphBar("Minus") -- the "-" (always shown)
glyphH.Size = UDim2.fromOffset(18, 6)
local glyphV = glyphBar("Plus") -- grows in to make the "+" when folded
glyphV.Size = UDim2.fromOffset(6, 0)
PanelChrome.pressFeedback(minHit, { scale = minFaceScale, face = minFace })

local function bodyHeight(): number
	local s = trackerScale.Scale
	if s <= 0 then s = 1 end
	return math.max(trackerBody.AbsoluteSize.Y / s, TAB_H)
end

-- a: 0 = full card, 1 = tab. Places every piece of the fold for one moment of it.
local function poseFold(a: number, bodyFade: number, tabFade: number)
	local h = bodyHeight()
	trackerFrame.Size = UDim2.fromOffset(
		math.floor(TRACKER_W + (TAB_W - TRACKER_W) * a + 0.5), math.floor(h + (TAB_H - h) * a + 0.5))
	trackerBody.GroupTransparency = 1 - bodyFade
	trackerTab.GroupTransparency = 1 - tabFade
	trackerTab.Visible = tabFade > 0
	glyphV.Size = UDim2.fromOffset(6, math.floor(18 * math.clamp(a, 0, 1) + 0.5))
	glyphV.Visible = a > 0.02
	badgeScale.Scale = 1 - 0.14 * a
end

local function restPose()
	if minimized then poseFold(1, 0, 1) else poseFold(0, 1, 0) end
	tabHit.Visible = minimized
end

-- The card follows the body's height at rest (a longer objective wraps to two lines).
local function fitTracker()
	if not folding then restPose() end
end
trackerBody:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitTracker)
trackerScale:GetPropertyChangedSignal("Scale"):Connect(fitTracker)

local foldToken = 0
local function ease(t, style)
	return TweenService:GetValue(math.clamp(t, 0, 1), style, Enum.EasingDirection.Out)
end
local function setMinimized(on: boolean)
	if on == minimized and not folding then return end
	minimized = on
	player:SetAttribute(MIN_ATTR, on)
	tabHit.Visible = on
	foldToken += 1
	local token = foldToken
	folding = true
	-- Start from wherever the card is now, so a second press mid-fold reverses smoothly.
	local s = trackerScale.Scale > 0 and trackerScale.Scale or 1
	local w0 = trackerFrame.AbsoluteSize.X / s
	local a0 = math.clamp((TRACKER_W - w0) / (TRACKER_W - TAB_W), 0, 1)
	local a1 = on and 1 or 0
	local bodyFade0 = 1 - trackerBody.GroupTransparency
	local tabFade0 = trackerTab.Visible and (1 - trackerTab.GroupTransparency) or 0
	local duration = (on and FOLD_TIME or UNFOLD_TIME) * math.max(math.abs(a1 - a0), 0.35)
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if token ~= foldToken then conn:Disconnect(); return end
		local t = math.clamp((os.clock() - start) / duration, 0, 1)
		local a = a0 + (a1 - a0) * ease(t, Enum.EasingStyle.Quart)
		local bodyFade, tabFade
		if on then -- the full card fades out early; the tab fades in as the fold lands
			bodyFade = bodyFade0 * (1 - math.clamp(t / 0.4, 0, 1))
			tabFade = tabFade0 + (1 - tabFade0) * math.clamp((t - 0.35) / 0.5, 0, 1)
		else -- the tab clears first; the card's contents fade in as it opens out
			tabFade = tabFade0 * (1 - math.clamp(t / 0.3, 0, 1))
			bodyFade = bodyFade0 + (1 - bodyFade0) * math.clamp((t - 0.3) / 0.6, 0, 1)
		end
		poseFold(a, bodyFade, tabFade)
		if t >= 1 then
			conn:Disconnect()
			folding = false
			restPose()
		end
	end)
end

minHit.Activated:Connect(function() setMinimized(not minimized) end)
tabHit.Activated:Connect(function() setMinimized(false) end)
restPose()

-- Sits just left of the Main Menu's side-button column, level with its top, and scales with it.
local navRail = nil
local function placeTracker()
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local s = PanelChrome.hudScale(viewport)
	trackerScale.Scale = s
	if navRail and navRail.Parent and navRail.AbsoluteSize.Y > 0 then
		trackerFrame.Position = UDim2.fromOffset(
			math.floor(navRail.AbsolutePosition.X - 16 * s),
			math.floor(navRail.AbsolutePosition.Y + 6 * s))
	else
		local railH = (6 * 70 + 5 * 16) * s -- MainMenuGui's six 70 px tiles with 16 px gaps
		trackerFrame.Position = UDim2.new(1, -math.floor(PanelChrome.HUD.Margin + 94 * s), 0.5, -math.floor(railH / 2))
	end
end
PanelChrome.onViewport(placeTracker)
task.spawn(function()
	local menu = playerGui:WaitForChild("MainMenuGui", 30)
	navRail = menu and menu:WaitForChild("NavRail", 30)
	if navRail then
		navRail:GetPropertyChangedSignal("AbsolutePosition"):Connect(placeTracker)
		navRail:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeTracker)
	end
	placeTracker()
end)

-- ── NPC Interaction Prompt ───────────────────────────────────────────────
-- Legacy on-screen prompt, kept hidden: the Quest Master's ProximityPrompt does the talking.

local promptFrame = Instance.new("Frame")
promptFrame.Name = "InteractionPrompt"
promptFrame.AnchorPoint = Vector2.new(0.5, 1)
promptFrame.Position = UDim2.new(0.5, 0, 1, -120)
promptFrame.Size = UDim2.fromOffset(300, 50)
promptFrame.BackgroundTransparency = 1
promptFrame.Visible = false
promptFrame.ZIndex = 10
promptFrame.Parent = screenGui

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
dialogOverlay.ZIndex = 3 -- under the tracker, so the tracker stays bright while the dialog is up
dialogOverlay.Parent = screenGui

-- The window holds the panel and its drop shadow, so one UIScale sizes both.
local dialogPanel = Instance.new("Frame")
dialogPanel.Name = "DialogPanel"
dialogPanel.AnchorPoint = Vector2.new(0.5, 0.5)
dialogPanel.Position = UDim2.fromScale(0.5, 0.5)
dialogPanel.Size = UDim2.fromOffset(PAD * 2 + LEFT_W, 520)
dialogPanel.BackgroundTransparency = 1
dialogPanel.Visible = false
dialogPanel.ZIndex = 20
dialogPanel.Parent = dialogGui
local panelScale = Instance.new("UIScale")
panelScale.Parent = dialogPanel

local dropShadow = Instance.new("Frame")
dropShadow.Name = "DropShadow"
dropShadow.AnchorPoint = Vector2.new(0.5, 0.5)
dropShadow.Position = UDim2.new(0.5, 0, 0.5, 12)
dropShadow.Size = UDim2.new(1, 12, 1, 12)
dropShadow.BackgroundColor3 = THEME.Shadow
dropShadow.BackgroundTransparency = 0.4
dropShadow.BorderSizePixel = 0
dropShadow.ZIndex = 20
dropShadow.Parent = dialogPanel
corner(dropShadow, 28)

local dialogChrome = PanelChrome.buildBright({
	name = "QuestModal",
	title = QuestConfig.GIVER_NAME,
	size = UDim2.fromScale(1, 1),
	titleSize = 50,
	closeSize = 64,
})
local modal = dialogChrome.Frame
modal.Size = UDim2.fromScale(1, 1)
modal.ZIndex = 21
modal.Parent = dialogPanel
modal:FindFirstChildOfClass("UIStroke").Thickness = 5

-- Title badge: a round sticker with a glossy gold "!" rendered in 3D.
local titleIcon = dialogChrome.TitleIcon
titleIcon.Image = ""
titleIcon.Size = UDim2.fromOffset(88, 88)
titleIcon.Position = UDim2.fromOffset(-24, 2)
titleIcon.Rotation = -10
titleIcon.BackgroundColor3 = WHITE
titleIcon.BackgroundTransparency = 0
corner(titleIcon, 44)
PanelChrome.gradient(titleIcon, Color3.fromRGB(255, 132, 92), Color3.fromRGB(214, 44, 64))
PanelChrome.stroke(titleIcon, BRIGHT.Outline, 4)
do
	local view = Instance.new("ViewportFrame")
	view.Name = "Exclaim"
	view.BackgroundTransparency = 1
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Position = UDim2.fromScale(0.5, 0.5)
	view.Size = UDim2.fromScale(1.1, 1.1)
	view.Ambient = Color3.fromRGB(196, 184, 160)
	view.LightColor = Color3.fromRGB(255, 250, 235)
	view.LightDirection = Vector3.new(-1, -1.3, -1.2)
	view.ZIndex = 9
	view.Parent = titleIcon
	local model = Instance.new("Model")
	local function piece(shape, size, cf, color, material)
		local p = Instance.new("Part")
		p.Shape = shape
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.Parent = model
		return p
	end
	local up = CFrame.Angles(0, 0, math.pi / 2)
	local gold, rim = Color3.fromRGB(255, 208, 48), BRIGHT.Outline
	-- The dark copies sit a little behind and a little larger: from the camera they read as an outline.
	for _, spec in ipairs({ { rim, 0.42, -0.9 }, { gold, 0, 0 } }) do
		local color, grow, z = spec[1], spec[2], spec[3]
		piece(Enum.PartType.Cylinder, Vector3.new(2.3 + grow, 1.25 + grow, 1.25 + grow), CFrame.new(0, 1.05, z) * up, color)
		piece(Enum.PartType.Ball, Vector3.one * (1.25 + grow), CFrame.new(0, 2.2, z), color)
		piece(Enum.PartType.Ball, Vector3.one * (0.9 + grow), CFrame.new(0, -0.05, z), color)
		piece(Enum.PartType.Ball, Vector3.one * (1.2 + grow), CFrame.new(0, -1.55, z), color)
	end
	model.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.3, 13), Vector3.new(0, 0.3, 0))
	camera.Parent = view
	view.CurrentCamera = camera
end
dialogChrome.TitleLabel.Position = UDim2.fromOffset(76, -2)

-- ── Left column: flavour bubble, quest card, reward chip, buttons ────────
local mainColumn = Instance.new("Frame")
mainColumn.Name = "QuestColumn"
mainColumn.BackgroundTransparency = 1
mainColumn.Position = UDim2.fromOffset(PAD, TOP)
mainColumn.Size = UDim2.new(0, LEFT_W, 1, -(TOP + BOTTOM))
mainColumn.ZIndex = 2
mainColumn.Parent = modal
local mainLayout = Instance.new("UIListLayout")
mainLayout.Padding = UDim.new(0, STACK_GAP)
mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
mainLayout.Parent = mainColumn

-- NPC flavour: one italic line in a speech bubble whose tail points up at the title.
local flavorHolder = Instance.new("Frame")
flavorHolder.Name = "Flavor"
flavorHolder.BackgroundTransparency = 1
flavorHolder.Size = UDim2.new(1, 0, 0, FLAVOR_H)
flavorHolder.LayoutOrder = 1
flavorHolder.ZIndex = 2
flavorHolder.Parent = mainColumn
local bubbleTail = Instance.new("Frame")
bubbleTail.Name = "Tail"
bubbleTail.AnchorPoint = Vector2.new(0.5, 0.5)
bubbleTail.Position = UDim2.fromOffset(46, 2)
bubbleTail.Size = UDim2.fromOffset(18, 18)
bubbleTail.Rotation = 45
bubbleTail.BackgroundColor3 = WHITE
bubbleTail.BorderSizePixel = 0
bubbleTail.ZIndex = 2
bubbleTail.Parent = flavorHolder
PanelChrome.stroke(bubbleTail, BRIGHT.Outline, 3)
local bubble = Instance.new("Frame")
bubble.Name = "Bubble"
bubble.BackgroundColor3 = WHITE
bubble.BorderSizePixel = 0
bubble.Size = UDim2.fromScale(1, 1)
bubble.ZIndex = 3
bubble.Parent = flavorHolder
corner(bubble, 16)
PanelChrome.stroke(bubble, BRIGHT.Outline, 3)
local bubbleCover = Instance.new("Frame") -- hides the tail's stroke where it meets the bubble
bubbleCover.BackgroundColor3 = WHITE
bubbleCover.BorderSizePixel = 0
bubbleCover.Position = UDim2.fromOffset(34, 0)
bubbleCover.Size = UDim2.fromOffset(24, 6)
bubbleCover.ZIndex = 4
bubbleCover.Parent = bubble
local dialogMessage = ink(bubble, {
	name = "Message", text = "", size = 24, font = Enum.Font.SourceSansItalic,
	pos = UDim2.fromOffset(16, 0), size2 = UDim2.new(1, -28, 1, 0), zIndex = 5,
})
dialogMessage.TextScaled = true
do
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 25
	c.MinTextSize = 14
	c.Parent = dialogMessage
end

-- Quest card: the blue pane with the quest's name, objective headline and progress.
local questCard = Instance.new("Frame")
questCard.Name = "QuestCard"
questCard.BackgroundColor3 = WHITE
questCard.BorderSizePixel = 0
questCard.Size = UDim2.new(1, 0, 0, CARD_H)
questCard.LayoutOrder = 2
questCard.ZIndex = 2
questCard.Parent = mainColumn
corner(questCard, 20)
PanelChrome.gradient(questCard, THEME.CardTop, THEME.CardBottom)
PanelChrome.stroke(questCard, BRIGHT.Outline, 3.5)
PanelChrome.stripes(questCard, { alpha = 0.93, bands = 7, rotation = 25, radius = 20, zIndex = 2 })
do
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 10)
	p.PaddingBottom = UDim.new(0, 12)
	p.PaddingLeft = UDim.new(0, 14)
	p.PaddingRight = UDim.new(0, 14)
	p.Parent = questCard
end
local cardBody = Instance.new("Frame")
cardBody.BackgroundTransparency = 1
cardBody.Size = UDim2.fromScale(1, 1)
cardBody.ZIndex = 3
cardBody.Parent = questCard
local cardLayout = Instance.new("UIListLayout")
cardLayout.Padding = UDim.new(0, 8)
cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
cardLayout.Parent = cardBody

local cardHeader = Instance.new("Frame")
cardHeader.BackgroundTransparency = 1
cardHeader.Size = UDim2.new(1, 0, 0, 26)
cardHeader.LayoutOrder = 1
cardHeader.ZIndex = 3
cardHeader.Parent = cardBody
local questTitle = display(cardHeader, {
	name = "QuestName", text = "", size = 24, stroke = 2.5, color = THEME.QuestGold,
	xAlign = Enum.TextXAlignment.Left, size2 = UDim2.new(1, -96, 1, 0), zIndex = 4, scaled = true, minSize = 14,
})
local questNumberPill = Instance.new("Frame")
questNumberPill.Name = "QuestNumber"
questNumberPill.AnchorPoint = Vector2.new(1, 0.5)
questNumberPill.Position = UDim2.new(1, 2, 0.5, 0)
questNumberPill.Size = UDim2.fromOffset(88, 28)
questNumberPill.BackgroundColor3 = THEME.Track
questNumberPill.BackgroundTransparency = 0.25
questNumberPill.ZIndex = 4
questNumberPill.Parent = cardHeader
corner(questNumberPill, 14)
local questNumber = display(questNumberPill, { text = "", size = 18, stroke = 2, zIndex = 5 })

local objectiveRow = Instance.new("Frame")
objectiveRow.BackgroundTransparency = 1
objectiveRow.Size = UDim2.new(1, 0, 0, 72)
objectiveRow.LayoutOrder = 2
objectiveRow.ZIndex = 3
objectiveRow.Parent = cardBody
local objectiveTile = Instance.new("Frame")
objectiveTile.Name = "ObjectiveIcon"
objectiveTile.AnchorPoint = Vector2.new(0, 0.5)
objectiveTile.Position = UDim2.fromScale(0, 0.5)
objectiveTile.Size = UDim2.fromOffset(70, 70)
objectiveTile.ZIndex = 4
objectiveTile.Parent = objectiveRow
corner(objectiveTile, 16)
PanelChrome.lootTile(objectiveTile, "Legendary", { radius = 16, zIndex = 4, glowY = 0.5 })
local objectiveIcon = image(objectiveTile, ICONS.Star, UDim2.fromScale(0.78, 0.78), UDim2.fromScale(0.5, 0.5),
	Vector2.new(0.5, 0.5), 5)
objectiveIcon.Rotation = -8
local objPreview = display(objectiveRow, {
	name = "Objective", text = "", size = 34, stroke = 3.5, xAlign = Enum.TextXAlignment.Left,
	pos = UDim2.fromOffset(84, 0), size2 = UDim2.new(1, -84, 1, 0), zIndex = 4, scaled = true, minSize = 18,
})
objPreview.TextWrapped = true

local cardBarHolder = Instance.new("Frame")
cardBarHolder.BackgroundTransparency = 1
cardBarHolder.Size = UDim2.new(1, -8, 0, 38)
cardBarHolder.LayoutOrder = 3
cardBarHolder.ZIndex = 3
cardBarHolder.Parent = cardBody
local cardBar = progressBar(cardBarHolder, 38, 26, 4)

local statusLabel = display(cardBody, {
	name = "Status", text = "", size = 19, stroke = 2.5, xAlign = Enum.TextXAlignment.Left,
	size2 = UDim2.new(1, 0, 0, 22), zIndex = 4,
})
statusLabel.LayoutOrder = 4

-- Reward chip: a boxed light plate with a big icon, a big stroked number and the unit.
local rewardHolder = Instance.new("Frame")
rewardHolder.Name = "Reward"
rewardHolder.BackgroundTransparency = 1
rewardHolder.Size = UDim2.new(1, 0, 0, REWARD_H)
rewardHolder.LayoutOrder = 3
rewardHolder.ZIndex = 2
rewardHolder.Parent = mainColumn
local rewardChip = Instance.new("Frame")
rewardChip.Name = "RewardChip"
rewardChip.BackgroundColor3 = WHITE
rewardChip.BorderSizePixel = 0
rewardChip.Position = UDim2.fromOffset(0, 8)
rewardChip.Size = UDim2.new(1, 0, 1, -8)
rewardChip.ZIndex = 2
rewardChip.Parent = rewardHolder
corner(rewardChip, 20)
PanelChrome.gradient(rewardChip, Color3.fromRGB(255, 250, 220), Color3.fromRGB(255, 222, 140))
local rewardStroke = PanelChrome.stroke(rewardChip, BRIGHT.Outline, 3.5)
local rewardContent = Instance.new("Frame")
rewardContent.BackgroundTransparency = 1
rewardContent.Size = UDim2.fromScale(1, 1)
rewardContent.ZIndex = 3
rewardContent.Parent = rewardChip
local rewardLayout = Instance.new("UIListLayout")
rewardLayout.FillDirection = Enum.FillDirection.Horizontal
rewardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rewardLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rewardLayout.Padding = UDim.new(0, 8)
rewardLayout.SortOrder = Enum.SortOrder.LayoutOrder
rewardLayout.Parent = rewardContent
local rewardIcon = image(rewardContent, ICONS.Coin, UDim2.fromOffset(66, 66), nil, nil, 4)
rewardIcon.Name = "RewardIcon"
rewardIcon.Rotation = -10
rewardIcon.LayoutOrder = 1
local rewardPreview = display(rewardContent, {
	name = "Amount", text = "", size = 48, stroke = 3.5, size2 = UDim2.new(0, 0, 1, 0), zIndex = 4,
})
rewardPreview.AutomaticSize = Enum.AutomaticSize.X
rewardPreview.LayoutOrder = 2
local rewardUnit = display(rewardContent, {
	name = "Unit", text = "", size = 30, stroke = 3, color = BRIGHT.Gold, size2 = UDim2.new(0, 0, 1, -4), zIndex = 4,
})
rewardUnit.AutomaticSize = Enum.AutomaticSize.X
rewardUnit.LayoutOrder = 3
-- "REWARD" tab riding the chip's top-left edge
local rewardTab = Instance.new("Frame")
rewardTab.Name = "RewardTab"
rewardTab.AnchorPoint = Vector2.new(0, 0.5)
rewardTab.Position = UDim2.fromOffset(14, 8)
rewardTab.Size = UDim2.fromOffset(92, 26)
rewardTab.BackgroundColor3 = WHITE
rewardTab.ZIndex = 5
rewardTab.Parent = rewardHolder
corner(rewardTab, 13)
PanelChrome.gradient(rewardTab, Color3.fromRGB(255, 176, 88), Color3.fromRGB(226, 92, 22))
PanelChrome.stroke(rewardTab, BRIGHT.Outline, 2.5)
display(rewardTab, { text = "REWARD", size = 17, stroke = 2, zIndex = 6 })

-- Buttons: full width, chunky, Accept dominant.
local buttonRow = Instance.new("Frame")
buttonRow.Name = "Buttons"
buttonRow.BackgroundTransparency = 1
buttonRow.Size = UDim2.new(1, 0, 0, BUTTONS_H)
buttonRow.LayoutOrder = 5
buttonRow.ZIndex = 2
buttonRow.Parent = mainColumn

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonLayout.Padding = UDim.new(0, 12)
buttonLayout.Parent = buttonRow

local acceptBtn, acceptHolder = shadowedButton(buttonRow, {
	name = "AcceptButton", text = "Accept Quest", color = BRIGHT.Green, colorDark = BRIGHT.GreenDark,
	size = UDim2.new(0.64, -6, 1, 0), order = 1, textSize = 34,
})
local completeBtn, completeHolder = shadowedButton(buttonRow, {
	name = "TurnInButton", text = "Turn In", color = Color3.fromRGB(255, 226, 90), colorDark = BRIGHT.GoldDark,
	size = UDim2.new(0.64, -6, 1, 0), order = 2, textSize = 34,
})
local closeBtn, closeHolder = shadowedButton(buttonRow, {
	name = "CloseDialogButton", text = "Close", color = Color3.fromRGB(226, 232, 244), colorDark = BRIGHT.GreyDark,
	size = UDim2.new(0.36, -6, 1, 0), order = 3, textSize = 30,
})

acceptBtn.Visible = false
completeBtn.Visible = false

-- ── Right column: the whole quest chain as a grid of reward tiles ────────
local chainPane = Instance.new("Frame")
chainPane.Name = "QuestChain"
chainPane.BackgroundTransparency = 1
chainPane.Position = UDim2.fromOffset(PAD + LEFT_W + GAP, TOP - 8)
chainPane.Size = UDim2.new(0, RIGHT_W, 1, -(TOP - 8 + BOTTOM))
chainPane.ZIndex = 2
chainPane.Parent = modal
local chainHeader = Instance.new("Frame")
chainHeader.BackgroundTransparency = 1
chainHeader.Size = UDim2.new(1, 0, 0, 36)
chainHeader.ZIndex = 2
chainHeader.Parent = chainPane
local chainTitle = ink(chainHeader, { text = "Quest Chain", size = 28, zIndex = 3, size2 = UDim2.new(0.62, 0, 1, 0) })
chainTitle.Position = UDim2.fromOffset(6, 0)
local chainCount = ink(chainHeader, {
	text = "", size = 28, color = BRIGHT.Blue, xAlign = Enum.TextXAlignment.Right, zIndex = 3,
	anchor = Vector2.new(1, 0), pos = UDim2.new(1, -14, 0, 0), size2 = UDim2.new(0.38, 0, 1, 0),
})

local chainScroll = Instance.new("ScrollingFrame")
chainScroll.Name = "Grid"
chainScroll.BackgroundTransparency = 1
chainScroll.BorderSizePixel = 0
chainScroll.Position = UDim2.fromOffset(0, 40)
chainScroll.Size = UDim2.new(1, 0, 1, -40)
chainScroll.CanvasSize = UDim2.new()
chainScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
chainScroll.ScrollingDirection = Enum.ScrollingDirection.Y
chainScroll.ScrollBarThickness = 10
chainScroll.ScrollBarImageColor3 = BRIGHT.Slot
chainScroll.ZIndex = 2
chainScroll.Parent = chainPane
do
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 4)
	p.PaddingLeft = UDim.new(0, 4)
	p.PaddingRight = UDim.new(0, 4)
	p.PaddingBottom = UDim.new(0, 6)
	p.Parent = chainScroll
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(CELL_W, CELL_H)
	grid.CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.FillDirectionMaxCells = 3
	grid.Parent = chainScroll
end

local TILE_STATES = {
	done = { rarity = "Uncommon", text = "Done!" },
	active = { rarity = "Legendary", text = "Active" },
	ready = { rarity = "Legendary", text = "Ready!" },
	offered = { rarity = "Legendary", text = "New!" },
	locked = { rarity = "Common", text = "Locked" },
}

local function buildChainTile(quest, state)
	local spec = TILE_STATES[state]
	local tile = Instance.new("Frame")
	tile.Name = "Quest" .. quest.index
	tile.LayoutOrder = quest.index
	tile.ZIndex = 3
	tile.Parent = chainScroll
	corner(tile, 16)
	local outline = PanelChrome.lootTile(tile, spec.rarity, { radius = 16, zIndex = 3, glowY = 0.42 })
	if state == "active" or state == "ready" or state == "offered" then
		outline.Thickness = 4.5
	end
	display(tile, {
		name = "Number", text = tostring(quest.index), size = 26, stroke = 2.5, xAlign = Enum.TextXAlignment.Right,
		anchor = Vector2.new(1, 0), pos = UDim2.new(1, -8, 0, 2), size2 = UDim2.fromOffset(40, 30), zIndex = 5,
	})
	local reward = quest.reward
	local icon = image(tile, REWARD_ICONS[reward.type] or ICONS.Star, UDim2.fromOffset(56, 56),
		UDim2.fromScale(0.44, 0.42), Vector2.new(0.5, 0.5), 4)
	icon.Rotation = -8
	if state == "locked" then
		icon.ImageTransparency = 0.35
	end
	display(tile, {
		name = "Amount", text = "x" .. shortNumber(rewardAmount(reward)), size = 17, stroke = 2,
		xAlign = Enum.TextXAlignment.Right, anchor = Vector2.new(1, 0.5), pos = UDim2.new(1, -8, 0.66, 0),
		size2 = UDim2.fromOffset(70, 20), zIndex = 5,
	})
	local stateLabel = display(tile, {
		name = "State", text = spec.text, size = 23, stroke = 2.5, anchor = Vector2.new(0.5, 1),
		pos = UDim2.new(0.5, 0, 1, -5), size2 = UDim2.new(1, -8, 0, 26), zIndex = 5,
	})
	if state == "locked" then
		stateLabel.TextColor3 = Color3.fromRGB(232, 236, 246)
	end
	return tile
end

local function rebuildChain(focusQuest, focusState)
	for _, child in ipairs(chainScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local completed = completedSet()
	local doneCount = 0
	local focusTile = nil
	for _, quest in ipairs(QuestConfig.QUESTS) do
		local state = "locked"
		if completed[quest.id] then
			state = "done"
			doneCount += 1
		elseif focusQuest and quest.id == focusQuest.id then
			state = focusState
		end
		local tile = buildChainTile(quest, state)
		if focusQuest and quest.id == focusQuest.id then focusTile = tile end
	end
	chainCount.Text = string.format("%d/%d", doneCount, #QuestConfig.QUESTS)
	-- Scroll so the focused quest's row sits near the top.
	task.defer(function()
		if focusTile and focusTile.Parent then
			local s = panelScale.Scale > 0 and panelScale.Scale or 1
			local rowIndex = math.floor((focusTile.LayoutOrder - 1) / 3)
			local y = math.max(0, rowIndex - 1) * (CELL_H + CELL_GAP) * s
			chainScroll.CanvasPosition = Vector2.new(0, y)
		end
	end)
end

-- ── Layout: size the window to its content and fit it to the screen ──────
local baseScale = 1
local showFlavor = true

local function applyLayout(viewport)
	local inset = GuiService:GetGuiInset()
	local areaY = viewport.Y - inset.Y
	local wide = viewport.X >= WIDE_MIN
	showFlavor = areaY >= SHORT_MAX
	flavorHolder.Visible = showFlavor
	local columnH = CARD_H + BUTTONS_H + STACK_GAP
		+ (rewardHolder.Visible and (REWARD_H + STACK_GAP) or 0)
		+ (showFlavor and (FLAVOR_H + STACK_GAP) or 0)
	local W = wide and (PAD * 2 + LEFT_W + GAP + RIGHT_W) or (PAD * 2 + LEFT_W)
	local H = TOP + columnH + BOTTOM
	chainPane.Visible = wide
	dialogPanel.Size = UDim2.fromOffset(W, H)
	-- The title and close button overhang the top edge by ~30 px: leave room for them.
	baseScale = math.min(1.1, (viewport.X - 24) / (W + 24), (areaY - 16) / (H + 40))
	baseScale = math.max(baseScale, 0.3)
	panelScale.Scale = baseScale
	-- Keep the corner close button a 46 px+ tap target however far the window shrinks.
	local closeSide = math.max(64, math.ceil(46 / baseScale))
	dialogChrome.CloseButton.Size = UDim2.fromOffset(closeSide, closeSide)
	dialogPanel.Position = UDim2.new(0.5, 0, 0.5, math.floor(14 * baseScale))
end

local function relayout()
	local camera = Workspace.CurrentCamera
	if camera then applyLayout(camera.ViewportSize) end
end
PanelChrome.onViewport(applyLayout)

-- ── Reward Toast ─────────────────────────────────────────────────────────

local function toastShell(width, height, top, bottom)
	local toast = Instance.new("Frame")
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, -height - 20)
	toast.Size = UDim2.fromOffset(width, height)
	toast.BackgroundColor3 = WHITE
	toast.BorderSizePixel = 0
	toast.ZIndex = 40
	toast.Parent = screenGui
	corner(toast, 18)
	PanelChrome.gradient(toast, top, bottom)
	PanelChrome.stroke(toast, BRIGHT.Outline, 3.5)
	local scale = Instance.new("UIScale")
	scale.Parent = toast
	local camera = Workspace.CurrentCamera
	if camera then scale.Scale = PanelChrome.hudScale(camera.ViewportSize) end
	return toast
end

local function slideToast(toast, height, hold)
	TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 16)
	}):Play()
	task.delay(hold, function()
		TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -height - 20),
		}):Play()
		task.delay(0.35, function()
			toast:Destroy()
		end)
	end)
end

local function showRewardToast(rtype, amount)
	local toast = toastShell(300, 64, BRIGHT.Panel, BRIGHT.PanelBottom)
	local icon = image(toast, REWARD_ICONS[rtype] or ICONS.Star, UDim2.fromOffset(62, 62),
		UDim2.new(0, -8, 0.5, 0), Vector2.new(0, 0.5), 42)
	icon.Rotation = -10
	local label = display(toast, {
		text = string.format("+%s %s!", shortNumber(amount), REWARD_LABELS[rtype] or rtype),
		size = 30, stroke = 3, color = REWARD_COLORS[rtype] or BRIGHT.Gold, xAlign = Enum.TextXAlignment.Left,
		pos = UDim2.fromOffset(62, 0), size2 = UDim2.new(1, -72, 1, 0), zIndex = 41, scaled = true, minSize = 14,
	})
	label.Name = "RewardText"
	slideToast(toast, 64, 2.5)
end

-- ── Completion celebration toast ─────────────────────────────────────────

local function showCompletionToast(questName)
	local toast = toastShell(360, 76, THEME.DoneTop, THEME.DoneBottom)
	local check = PanelChrome.checkBadge(toast, 56, 42)
	check.Position = UDim2.new(0, 14, 0.5, 0)
	display(toast, {
		name = "Title", text = "QUEST COMPLETE!", size = 30, stroke = 3, xAlign = Enum.TextXAlignment.Left,
		pos = UDim2.fromOffset(54, 6), size2 = UDim2.new(1, -64, 0, 36), zIndex = 41, scaled = true, minSize = 14,
	})
	display(toast, {
		name = "QuestName", text = questName, size = 20, stroke = 2.5, color = Color3.fromRGB(255, 244, 170),
		xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(54, 42), size2 = UDim2.new(1, -64, 0, 24),
		zIndex = 41, scaled = true, minSize = 12,
	})
	slideToast(toast, 76, 3)
end

-- ── Tracker update ───────────────────────────────────────────────────────

local function setRewardVisual(reward, icon, amountLabel, unitLabel)
	icon.Image = REWARD_ICONS[reward.type] or ICONS.Star
	amountLabel.Text = shortNumber(rewardAmount(reward))
	if unitLabel then
		unitLabel.Text = REWARD_UNITS[reward.type] or ""
		unitLabel.TextColor3 = REWARD_COLORS[reward.type] or BRIGHT.Gold
	end
end

local function updateTracker()
	local quest, hint, hintColor
	local progress = activeProgress
	if activeQuestId ~= "" then
		quest = QuestConfig.getQuestById(activeQuestId)
		if quest and activeQuestComplete then
			hint, hintColor = "Ready! Turn in at the Quest Master", Color3.fromRGB(150, 245, 120)
		end
	end
	-- No quest running: nothing on the tracker. A quest shows once the Quest Master has given it,
	-- not before (2026-09-24 playtest); the map's guide marker still points new players at him.
	if not quest then
		trackerFrame.Visible = false
		return
	end

	-- Stepped aside while the spin board or a drop reveal is up: both use the right of the screen
	-- (the reveal's rarity ladder sat under the tracker in the 2026-09-24 blacksmith recording).
	trackerFrame.Visible = player:GetAttribute("SpinBoardOpen") ~= true and player:GetAttribute("DropRevealOpen") ~= true
	questNameLabel.Text = string.format("Quest %d · %s", quest.index, quest.name)
	questDescLabel.Text = getObjectiveHeadline(quest)
	local frac, countText = getProgressCounts(quest, progress)
	local complete = (activeQuestId ~= "" and activeQuestComplete) or (activeQuestId == "" and frac >= 1)
	trackerBar.set(frac, countText, complete)
	tabName.Text = quest.name
	tabBar.set(frac, countText, complete)
	setRewardVisual(quest.reward, trackerRewardIcon, trackerRewardAmount)
	progressLabel.Visible = hint ~= nil
	progressLabel.Text = hint or ""
	progressLabel.TextColor3 = hintColor or THEME.QuestGold
end

-- ── Dialog management ────────────────────────────────────────────────────

local FLAVOR = {
	accept = "“I have a task for you, adventurer.”",
	turnin = "“Well done! Here is your reward.”",
	info = "“You're not done yet. Keep at it!”",
	done = "“You have completed all my tasks. A true legend!”",
}

-- Shared open/close motion (PanelChrome): the dialog grows in while the backdrop dims.
local dialogMotion = { frame = dialogPanel, scale = panelScale, dim = dialogOverlay, dimTo = 0.6 }

local function closeDialog()
	interactionOpen = false
	if not dialogPanel.Visible then return end
	PanelChrome.closeMotion(dialogMotion, function()
		dialogOverlay.Visible = false
		dialogPanel.Visible = false
	end)
end

local function setButtons(primary)
	-- primary: "accept", "turnin" or nil (Close alone fills the row)
	acceptBtn.Visible = primary == "accept"
	completeBtn.Visible = primary == "turnin"
	acceptHolder.Visible = primary == "accept"
	completeHolder.Visible = primary == "turnin"
	closeHolder.Size = primary and UDim2.new(0.36, -6, 1, 0) or UDim2.new(1, 0, 1, 0)
end

local function openDialog(quest, mode)
	-- mode: "accept", "turnin", "info", "done" (quest is nil when mode is "done")
	interactionOpen = true
	dialogOverlay.Visible = true
	dialogPanel.Visible = true

	dialogMessage.Text = FLAVOR[mode] or FLAVOR.accept
	if quest then
		local progress = mode == "accept" and 0 or activeProgress
		local frac, countText = getProgressCounts(quest, progress)
		local complete = mode == "turnin" or frac >= 1
		questTitle.Text = quest.name
		questNumber.Text = string.format("%d / %d", quest.index, #QuestConfig.QUESTS)
		objPreview.Text = getObjectiveHeadline(quest)
		objectiveIcon.Image = OBJECTIVE_ICONS[quest.objective.type] or ICONS.Star
		cardBar.set(frac, countText, complete)
		if mode == "accept" then
			statusLabel.Text = complete and "Already done! Accept to claim it" or "Accept to start tracking"
		elseif mode == "turnin" then
			statusLabel.Text = "Complete! Claim your reward"
		else
			statusLabel.Text = "In progress. Keep going!"
		end
		rewardHolder.Visible = true
		setRewardVisual(quest.reward, rewardIcon, rewardPreview, rewardUnit)
		setButtons(mode == "accept" and "accept" or mode == "turnin" and "turnin" or nil)
		local state = mode == "accept" and "offered" or mode == "turnin" and "ready" or "active"
		rebuildChain(quest, state)
	else
		questTitle.Text = "Quest chain complete"
		questNumber.Text = string.format("%d / %d", #QuestConfig.QUESTS, #QuestConfig.QUESTS)
		objPreview.Text = "All quests done!"
		objectiveIcon.Image = ICONS.Trophy
		cardBar.set(1, "All done", true)
		statusLabel.Text = "Check back when new quests arrive"
		rewardHolder.Visible = false
		setButtons(nil)
		rebuildChain(nil, nil)
	end
	relayout()

	PanelChrome.openMotion(dialogMotion)
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
			openDialog(nil, "done")
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
			elseif obj.type == "OBTAIN" or obj.type == "OBTAIN_POOL" then
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
player:GetAttributeChangedSignal("CompletedQuests"):Connect(updateTracker)
player:GetAttributeChangedSignal("SpinBoardOpen"):Connect(updateTracker)
player:GetAttributeChangedSignal("DropRevealOpen"):Connect(updateTracker)

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
			elseif activeQuestId == "" then
				updateTracker() -- the next-quest preview shows the level too
			end
		end)
		updateTracker()
	end
end

-- Studio-only motion capture hook (see GuiShowcase.motion): replays a mouse press on the tracker's
-- minimize button. Scripts cannot fire a GuiButton's input events, so this steps the button's own
-- hover/down/up states in the order a mouse fires them, then folds the card as its Activated
-- handler does. The card shows the player's real quest and progress. Two seconds later the same
-- press on the "+" restores it.
local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))
local function pressMinimize(after)
	local press = PanelChrome.pressHandle(minHit)
	if press then
		press.down() -- MouseButton1Down
		task.wait(0.1)
		press.up() -- MouseButton1Up, then Activated
	end
	after()
end
GuiShowcase.motion("QuestMinimize", function()
	pressMinimize(function() setMinimized(true) end)
	task.wait(2)
	pressMinimize(function() setMinimized(false) end)
end, function()
	if minimized then setMinimized(false) end
	local press = PanelChrome.pressHandle(minHit)
	if press then press.hover(true) end -- MouseEnter
end)

print("[QuestGui] Quest tracker and NPC interaction enabled")
