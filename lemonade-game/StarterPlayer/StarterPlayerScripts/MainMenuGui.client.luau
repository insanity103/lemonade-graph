local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local spendEvent = remotes:WaitForChild("SpendSkillPoint")
local inventoryAction = remotes:WaitForChild("InventoryAction")
local rebirthResultRemote = remotes:WaitForChild("RebirthResult")

local WeaponModifiers = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponModifiers"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local SwordValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwordValue"))
local BossWeapons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BossWeapons"))
-- The one sell price in the game, the same module the server pays out of. The button quotes the
-- number the server will pay, it does not compute a number of its own.
local SellValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SellValue"))

-- 12,400 rather than 12400, on a button that has to be read at a glance.
local function goldText(n: number): string
	local out = string.format("%d", math.floor(n + 0.5))
	local k
	repeat out, k = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
	return out
end
local RebirthConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RebirthConfig"))
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))

local ICONS = {
	Inventory = "rbxassetid://118915534669949",
	Skills = "rbxassetid://134595823778256",
	Settings = "rbxassetid://119570973950437",
	Trophy = "rbxassetid://77830885604568",
	Coin = "rbxassetid://84697600263846",
	Close = "rbxassetid://109798318511632",
	Sword = "rbxassetid://94091032987086",
	Target = "rbxassetid://120517988406723",
	Shield = "rbxassetid://93114601642790",
	Star = "rbxassetid://112684829478873",
	Lighting = "rbxassetid://91519647625054",
}

local COLORS = {
	Panel = Color3.fromRGB(12, 12, 14),
	PanelLight = Color3.fromRGB(22, 22, 26),
	PanelDark = Color3.fromRGB(16, 16, 18),
	Stroke = Color3.fromRGB(45, 45, 52),
	StrokeBright = Color3.fromRGB(70, 70, 80),
	Text = Color3.fromRGB(245, 245, 250),
	Muted = Color3.fromRGB(150, 150, 165),
	Accent = Color3.fromRGB(35, 35, 42),
	AccentBright = Color3.fromRGB(250, 250, 255),
	Success = Color3.fromRGB(90, 220, 140),
	Button = Color3.fromRGB(40, 40, 48),
	ButtonHover = Color3.fromRGB(55, 55, 65),
	ButtonDisabled = Color3.fromRGB(25, 25, 30),
	Gold = Color3.fromRGB(255, 215, 0),
}

local RARITY_COLOR = {
	Common = Color3.fromRGB(210, 210, 210),
	Uncommon = Color3.fromRGB(90, 200, 90),
	Rare = Color3.fromRGB(90, 150, 255),
	Epic = Color3.fromRGB(190, 110, 245),
	Legendary = Color3.fromRGB(255, 175, 50),
}

local SKILL_ATTRIBUTES = {
	{ name = "Strength", label = "Strength", desc = "+5 sword damage" },
	{ name = "Health", label = "Health", desc = "+20 max HP" },
	{ name = "Defense", label = "Defense", desc = "+0.3% damage reduction (max 35%)" },
	{ name = "ExperienceGain", label = "XP Gain", desc = "+0.5% XP bonus (max 35%)" },
}

-- Each side button gets its own saturated tile (top/bottom of its gradient) instead of uniform
-- gray, so the column reads as distinct categories at a glance.
local NAV_ITEMS = {
	{ id = "Inventory", icon = ICONS.Inventory, label = "Items", top = Color3.fromRGB(126, 204, 255), bottom = Color3.fromRGB(36, 116, 236) },
	{ id = "Skills", icon = ICONS.Skills, label = "Skills", top = Color3.fromRGB(160, 242, 118), bottom = Color3.fromRGB(44, 168, 60) },
	{ id = "Rebirth", icon = "rbxassetid://80234316052758", label = "Rebirth", top = Color3.fromRGB(222, 164, 255), bottom = Color3.fromRGB(134, 62, 222) },
	{ id = "Trade", icon = ICONS.Sword, label = "Trade", top = Color3.fromRGB(255, 232, 110), bottom = Color3.fromRGB(238, 150, 18) },
	{ id = "Settings", icon = ICONS.Settings, label = "Settings", top = Color3.fromRGB(236, 240, 248), bottom = Color3.fromRGB(150, 160, 182) },
}

local existing = playerGui:FindFirstChild("MainMenuGui")
if existing then existing:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainMenuGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

-- The menu overlay and panels get their own ScreenGui above the sword hotbar (13), so the
-- hotbar slot never draws over the bottom of an open panel. The HUD stays on screenGui.
local existingPanels = playerGui:FindFirstChild("MainMenuPanels")
if existingPanels then existingPanels:Destroy() end
local panelGui = Instance.new("ScreenGui")
panelGui.Name = "MainMenuPanels"
panelGui.ResetOnSpawn = false
panelGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
panelGui.DisplayOrder = 20
panelGui.Parent = playerGui

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or COLORS.Stroke
	stroke.Transparency = transparency or 0.35
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

local function addPadding(parent, top, right, bottom, left)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, top)
	padding.PaddingRight = UDim.new(0, right)
	padding.PaddingBottom = UDim.new(0, bottom)
	padding.PaddingLeft = UDim.new(0, left)
	padding.Parent = parent
	return padding
end

local function createText(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = props.font or Enum.Font.Gotham
	label.TextColor3 = props.color or COLORS.Text
	label.TextSize = props.size or 16
	label.TextXAlignment = props.xAlign or Enum.TextXAlignment.Left
	label.TextYAlignment = props.yAlign or Enum.TextYAlignment.Center
	label.Text = props.text or ""
	label.Size = props.size2 or UDim2.fromScale(1, 0)
	label.Position = props.pos or UDim2.fromOffset(0, 0)
	label.TextWrapped = props.wrap or false
	if props.zIndex then label.ZIndex = props.zIndex end
	label.Parent = parent
	return label
end

-- ── Always-on HUD: gold readout (bottom-left, over the vitals) and the side buttons ──────
-- Bright chunky style from PanelChrome: a big coin overlapping a stroked display number, and a
-- column of gradient tiles with thick outlines, stroked labels and red count badges. Both
-- scale with PanelChrome.hudScale, in step with LevelProgressGui's health/XP cluster.
local HUD = PanelChrome.HUD
local HUD_BRIGHT = PanelChrome.BRIGHT
local NAV_TILE, NAV_GAP = 70, 16

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0, 1)
topBar.Size = UDim2.fromOffset(280, HUD.GoldHeight)
topBar.BackgroundTransparency = 1
topBar.ZIndex = 5
topBar.Parent = screenGui
local topBarScale = Instance.new("UIScale")
topBarScale.Parent = topBar

local function createChip(name, icon)
	local chip = Instance.new("Frame")
	chip.Name = name
	-- Anchored left-centre so the gain punch (the Punch UIScale) grows the coin and number
	-- rightward and evenly up and down, never off the screen edge.
	chip.AnchorPoint = Vector2.new(0, 0.5)
	chip.Position = UDim2.fromScale(0, 0.5)
	chip.Size = UDim2.fromScale(1, 1)
	chip.BackgroundTransparency = 1
	chip.ZIndex = 6
	chip.Parent = topBar
	local punch = Instance.new("UIScale")
	punch.Name = "Punch"
	punch.Parent = chip
	local iconImg = Instance.new("ImageLabel")
	iconImg.Name = "Icon"
	iconImg.AnchorPoint = Vector2.new(0, 0.5)
	iconImg.Position = UDim2.new(0, 0, 0.5, 0)
	iconImg.Size = UDim2.fromOffset(64, 64)
	iconImg.Rotation = -10
	iconImg.BackgroundTransparency = 1
	iconImg.Image = icon
	iconImg.ScaleType = Enum.ScaleType.Fit
	iconImg.ZIndex = 8
	iconImg.Parent = chip
	-- Fixed text size: the short-form number (31.2K) always fits the readout.
	local value = PanelChrome.display(chip, {
		name = "Value", text = "0", size = 42, stroke = 3.5, zIndex = 7,
		xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(66, 0), size2 = UDim2.new(1, -66, 1, 0),
	})
	return value, iconImg, punch
end

-- Level lives on the bottom-left XP badge; this readout holds only gold.
local goldLabel, goldIcon, goldPunch = createChip("GoldChip", ICONS.Coin)

-- "+3,000" for gains a player can read exactly, short form ("+1.2M") past that.
local function gainText(gain)
	if gain >= 1e6 then return "+" .. NumberFormat.short(gain) end
	local digits = tostring(math.floor(gain))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "+" .. grouped
end

-- Gains roll the number up with a punch and a floating "+N" (PanelChrome.counter). The delta
-- lives on topBar, outside the punch, and starts just right of the settled number.
local goldCounter = PanelChrome.counter({
	label = goldLabel, scale = goldPunch, icon = goldIcon, format = NumberFormat.short,
	deltaParent = topBar, deltaZ = 12, deltaText = gainText,
	deltaAt = function(text)
		local w = TextService:GetTextSize(text, 42, PanelChrome.DISPLAY_FONT, Vector2.new(1e4, 1e4)).X
		-- Clear of the number at the top of its punch (the chip scales from its left edge).
		return UDim2.new(0, math.ceil((66 + w) * PanelChrome.COUNTER.Peak) + 8, 0.5, -12)
	end,
})

local navRail = Instance.new("Frame")
navRail.Name = "NavRail"
navRail.AnchorPoint = Vector2.new(1, 0.5)
navRail.Size = UDim2.fromOffset(NAV_TILE + 8, #NAV_ITEMS * NAV_TILE + (#NAV_ITEMS - 1) * NAV_GAP)
navRail.BackgroundTransparency = 1
navRail.ZIndex = 5
navRail.Parent = screenGui
local navRailScale = Instance.new("UIScale")
navRailScale.Parent = navRail
local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Vertical
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
navLayout.SortOrder = Enum.SortOrder.LayoutOrder
navLayout.Padding = UDim.new(0, NAV_GAP)
navLayout.Parent = navRail

PanelChrome.onViewport(function(viewport)
	local s = PanelChrome.hudScale(viewport)
	topBarScale.Scale = s
	navRailScale.Scale = s
	local lift = PanelChrome.hudVitalsBottom(viewport) + HUD.VitalsHeight * s + 2
	topBar.Position = UDim2.new(0, HUD.Margin, 1, -math.floor(lift))
	navRail.Position = UDim2.new(1, -HUD.Margin, 0.5, 0)
end)

-- One chunky side button: gradient tile in the tab's colour, heavy outline, glossy top, the
-- tab's icon (or glyph) and a stroked label riding the bottom edge.
-- Each button sits centred in its own fixed-size slot, so the rail's UIListLayout places the slot
-- and the press can scale the button about its centre without shoving its neighbours.
local function createNavButton(item, order)
	local slot = Instance.new("Frame")
	slot.Name = item.id .. "Slot"
	slot.Size = UDim2.fromOffset(NAV_TILE, NAV_TILE)
	slot.BackgroundTransparency = 1
	slot.LayoutOrder = order
	slot.ZIndex = 6
	slot.Parent = navRail
	local button = Instance.new("ImageButton")
	button.Name = item.id
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.5)
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.Image = ""
	button.AutoButtonColor = false
	button.LayoutOrder = order
	button.ZIndex = 6
	button.Parent = slot
	addCorner(button, 20)
	local outline = PanelChrome.stroke(button, HUD_BRIGHT.Outline, 3.5)
	outline.Name = "Outline"
	PanelChrome.gradient(button, item.top, item.bottom)

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromOffset(6, 5)
	shine.Size = UDim2.new(1, -12, 0.38, 0)
	shine.ZIndex = 6
	shine.Parent = button
	addCorner(shine, 14)
	local shineGradient = Instance.new("UIGradient")
	shineGradient.Rotation = 90
	shineGradient.Transparency = NumberSequence.new(0.45, 0.9)
	shineGradient.Parent = shine

	if item.icon then
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.44)
		icon.Size = UDim2.fromScale(0.74, 0.74)
		icon.BackgroundTransparency = 1
		icon.Image = item.icon
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = 7
		icon.Parent = button
	else
		local glyph = Instance.new("TextLabel")
		glyph.Name = "Glyph"
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.44)
		glyph.Size = UDim2.fromScale(0.7, 0.7)
		glyph.BackgroundTransparency = 1
		glyph.Text = item.text or ""
		glyph.TextScaled = true
		glyph.Font = Enum.Font.SourceSansBold
		glyph.ZIndex = 7
		glyph.Parent = button
	end

	local label = PanelChrome.display(button, {
		name = "Label", text = item.label or item.id, size = 16, stroke = 2.5, zIndex = 9, scaled = true, minSize = 10,
		anchor = Vector2.new(0.5, 0.5), pos = UDim2.new(0.5, 0, 1, -3), size2 = UDim2.new(1, 8, 0, 20),
	})
	label.Name = "Label"

	PanelChrome.pressFeedback(button, { icon = button:FindFirstChild("Icon") or button:FindFirstChild("Glyph") })
	return button
end

local navButtons = {}
local overlay = Instance.new("TextButton")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Visible = false
overlay.ZIndex = 20
overlay.Parent = panelGui

local BRIGHT = PanelChrome.BRIGHT

-- ── Panel geometry ───────────────────────────────────────────────────────────
-- The panel is laid out in design units and fitted to the screen with a UIScale. Wide screens
-- get a 5-column item grid; phones (narrow/portrait) get 3 columns and larger touch targets,
-- sized so that at 375 x 812 the scale (~0.73) still leaves every button >= 44 px.
local TILE, TILE_GAP = 104, 12
local RAIL_X, RAIL_W = -34, 78 -- tab rail straddles the panel's left edge
local WELL_LEFT, WELL_RIGHT, WELL_TOP, WELL_BOTTOM = 56, 18, 50, 18
local DETAIL_W = 290
local LAYOUTS = {
	wide = { cols = 5, H = 540, touch = 54 },
	narrow = { cols = 3, H = 660, touch = 64 },
}
for _, L in pairs(LAYOUTS) do
	L.W = WELL_LEFT + L.cols * TILE + (L.cols - 1) * TILE_GAP + 30 + WELL_RIGHT
end
local layout = LAYOUTS.wide
local layoutMode = "wide"

local chrome = PanelChrome.buildBright({
	name = "ContentPanel",
	title = "Menu",
	icon = ICONS.Inventory,
	size = UDim2.fromOffset(layout.W, layout.H),
})
local contentPanel = chrome.Frame
contentPanel.Visible = false
contentPanel.ZIndex = 21
contentPanel.Parent = panelGui
local headerTitle = chrome.TitleLabel
local headerIcon = chrome.TitleIcon
local closeBtn = chrome.CloseButton
local panelScale = Instance.new("UIScale")
panelScale.Parent = contentPanel

-- Inset well that holds each tab's content. Tabs still drawn in the dark card style get a
-- dark well so their light text stays readable; the Inventory draws straight on the panel.
local well = Instance.new("Frame")
well.Name = "Well"
well.Position = UDim2.fromOffset(WELL_LEFT, WELL_TOP)
well.Size = UDim2.new(1, -(WELL_LEFT + WELL_RIGHT), 1, -(WELL_TOP + WELL_BOTTOM))
well.BackgroundColor3 = COLORS.Panel
well.BackgroundTransparency = 1
well.BorderSizePixel = 0
well.ZIndex = 22
well.Parent = contentPanel
addCorner(well, 14)
local wellStroke = addStroke(well, BRIGHT.Outline, 1, 3)

local body = Instance.new("ScrollingFrame")
body.Name = "Body"
body.Position = UDim2.fromOffset(0, 0)
body.Size = UDim2.fromScale(1, 1)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 6
body.ScrollBarImageColor3 = COLORS.StrokeBright
body.CanvasSize = UDim2.fromOffset(0, 0)
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.ZIndex = 22
body.Parent = well
local bodyPadding = addPadding(body, 12, 14, 14, 14)
local bodyLayout = Instance.new("UIListLayout")
bodyLayout.Padding = UDim.new(0, 12)
bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
bodyLayout.Parent = body

local function setWellTheme(bright)
	well.BackgroundTransparency = bright and 1 or 0
	wellStroke.Transparency = bright and 1 or 0
	body.ScrollBarImageColor3 = bright and BRIGHT.GreyDark or COLORS.StrokeBright
	if bright then
		bodyPadding.PaddingTop, bodyPadding.PaddingLeft = UDim.new(0, 4), UDim.new(0, 4)
		bodyPadding.PaddingRight, bodyPadding.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
	else
		bodyPadding.PaddingTop, bodyPadding.PaddingLeft = UDim.new(0, 12), UDim.new(0, 14)
		bodyPadding.PaddingRight, bodyPadding.PaddingBottom = UDim.new(0, 14), UDim.new(0, 14)
	end
end

-- Vertical rail of icon tabs down the panel's left edge (mirrors the side NavRail), with red
-- count badges. Built after openTab exists; see buildPanelRail below.
local panelRail = Instance.new("Frame")
panelRail.Name = "TabRail"
panelRail.Position = UDim2.fromOffset(RAIL_X, 64)
panelRail.Size = UDim2.fromOffset(RAIL_W, 300)
panelRail.AutomaticSize = Enum.AutomaticSize.Y
panelRail.BackgroundColor3 = Color3.new(1, 1, 1)
panelRail.ZIndex = 24
panelRail.Parent = contentPanel
addCorner(panelRail, 20)
PanelChrome.stroke(panelRail, BRIGHT.Outline, 4)
PanelChrome.gradient(panelRail, Color3.fromRGB(255, 255, 255), Color3.fromRGB(222, 230, 244))
addPadding(panelRail, 10, 8, 10, 8)
local railLayout = Instance.new("UIListLayout")
railLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
railLayout.Padding = UDim.new(0, 6)
railLayout.SortOrder = Enum.SortOrder.LayoutOrder
railLayout.Parent = panelRail
local railButtons = {}

-- Fit the panel to the screen: pick the wide/narrow layout, size touch targets, set UIScale.
local onLayoutModeChanged -- assigned once the tab builders exist
local function applyPanelLayout()
	local abs = panelGui.AbsoluteSize
	if abs.X < 2 or abs.Y < 2 then return end
	local mode = (abs.X < 720 or abs.X < abs.Y) and "narrow" or "wide"
	local L = LAYOUTS[mode]
	layout = L
	contentPanel.Size = UDim2.fromOffset(L.W, L.H)
	local overhangL = math.floor((L.touch + 22) / 2) - 4 -- rail sticks out this far on the left
	local overhangR = math.floor((L.touch + 2) / 2) - 22 -- close button past the right edge
	panelRail.Size = UDim2.fromOffset(L.touch + 22, 0)
	panelRail.Position = UDim2.fromOffset(-overhangL, 70)
	for _, b in pairs(railButtons) do b.Size = UDim2.fromOffset(L.touch, L.touch) end
	closeBtn.Size = UDim2.fromOffset(L.touch + 2, L.touch + 2)
	-- Width needed: the panel plus its rail / close overhangs, and on wide screens room for the
	-- item detail card that pops out to the right. Phones centre the overhung footprint.
	local needW = if mode == "wide" then L.W + 2 * (DETAIL_W + 24) else L.W + overhangL + overhangR + 8
	local needH = L.H + 2 * 44
	local s = math.max(math.min((abs.X - 8) / needW, (abs.Y * 0.94) / needH, 1.25), 0.3)
	panelScale.Scale = s
	local shift = if mode == "wide" then 0 else (overhangL - overhangR) / 2 * s
	-- Wide screens sit the panel a little high so the bottom-centre hotbar slot stays clear.
	contentPanel.Position = UDim2.new(0.5, math.floor(shift), 0.5, if mode == "wide" then -22 else 12)
	if mode ~= layoutMode then
		layoutMode = mode
		if onLayoutModeChanged then onLayoutModeChanged() end
	end
end
panelGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyPanelLayout)
task.defer(applyPanelLayout)

local activeTab = nil
local panelOpen = false
local skillButtons = {}

-- The Inventory's open item card (a child of contentPanel, outside the scrolling body) and the
-- Tool it describes. Tapping a tile selects it; the card pops out beside the panel on wide
-- screens and over the bottom of the panel on phones.
local inventoryDetail = nil
local inventorySelection = nil
local refreshRailBadges -- assigned with the tab rail below

local function closeInventoryDetail()
	if inventoryDetail then
		inventoryDetail:Destroy()
		inventoryDetail = nil
	end
end

local function clearBody()
	closeInventoryDetail()
	for _, child in ipairs(body:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end
	end
end

-- Helper to find all held & backpack tools
local function getCarriedTools()
	local tools = {}
	local bp = player:FindFirstChildOfClass("Backpack")
	if bp then
		for _, t in ipairs(bp:GetChildren()) do
			if t:IsA("Tool") then table.insert(tools, { tool = t, equipped = false }) end
		end
	end
	if player.Character then
		for _, t in ipairs(player.Character:GetChildren()) do
			if t:IsA("Tool") then table.insert(tools, { tool = t, equipped = true }) end
		end
	end
	return tools
end

local function toolFacts(item)
	local tool = item.tool
	return {
		rarity = tool:GetAttribute("Rarity") or "Common",
		damageMult = tool:GetAttribute("DamageMult") or 1,
		bonusDmg = tool:GetAttribute("BonusDamagePct") or 0,
		critChance = tool:GetAttribute("CritChance") or 0,
		rangeBonus = tool:GetAttribute("RangeBonus") or 0,
		knockbackBonus = tool:GetAttribute("KnockbackBonus") or 0,
		-- One prefix slot per sword (more are a player unlock, WeaponModifiers.SlotUnlocks). A
		-- pre-rework sword can hold dormant prefixes in StoredPrefixes that wake with a new slot.
		prefixCount = #SwordValue.modifiersFromPrefixes(tool:GetAttribute("Prefixes")),
		storedCount = #SwordValue.modifiersFromPrefixes(tool:GetAttribute("StoredPrefixes") or tool:GetAttribute("Prefixes")),
		slots = WeaponModifiers.SlotsOf(player),
		bossDrop = tool:GetAttribute("BossDrop") == true,
		-- Same rule as before: only unequipped boss drops (never the starter sword) can be sold.
		sellable = tool.Name ~= "ClassicSword" and tool:GetAttribute("Starter") ~= true
			and tool:GetAttribute("BossDrop") == true and not item.equipped,
		-- ...and what it is worth, from Config.SellValue -- the same table, the same call and the
		-- same rebirth multiplier the pickup prompt quoted when this sword dropped.
		sellValue = SellValue.ForTool(tool, SellValue.GoldMultFor(player)),
	}
end

local function brightText(parent, props)
	local label = createText(parent, props)
	label.TextColor3 = props.color or BRIGHT.Ink
	return label
end

local buildInventoryPanel

local function detailStatRow(parent, order, icon, labelText, valueText, valueColor, rowH)
	local row = Instance.new("Frame")
	row.Name = "Stat_" .. labelText
	row.Size = UDim2.new(1, 0, 0, rowH or 40)
	row.BackgroundColor3 = BRIGHT.Row
	row.LayoutOrder = order
	row.ZIndex = 32
	row.Parent = parent
	addCorner(row, 12)
	PanelChrome.stroke(row, BRIGHT.RowStroke, 2)
	local ic = Instance.new("ImageLabel")
	ic.BackgroundTransparency = 1
	ic.AnchorPoint = Vector2.new(0, 0.5)
	ic.Position = UDim2.new(0, 8, 0.5, 0)
	ic.Size = UDim2.fromOffset(28, 28)
	ic.Image = icon
	ic.ScaleType = Enum.ScaleType.Fit
	ic.ZIndex = 33
	ic.Parent = row
	brightText(row, { text = labelText, font = Enum.Font.GothamBold, size = 15, pos = UDim2.fromOffset(44, 0), size2 = UDim2.new(0.55, -44, 1, 0), zIndex = 33 })
	PanelChrome.display(row, {
		text = valueText, size = 24, color = valueColor or Color3.new(1, 1, 1), stroke = 2.5,
		xAlign = Enum.TextXAlignment.Right, pos = UDim2.fromScale(0.45, 0), size2 = UDim2.new(0.55, -12, 1, 0), zIndex = 33,
	})
end

local function openInventoryDetail(item)
	closeInventoryDetail()
	local tool = item.tool
	local f = toolFacts(item)
	local tileColors = PanelChrome.RARITY_TILE[f.rarity] or PanelChrome.RARITY_TILE.Common
	local narrow = layoutMode == "narrow"

	local card = Instance.new("Frame")
	card.Name = "ItemDetail"
	if narrow then
		card.AnchorPoint = Vector2.new(0, 1)
		card.Position = UDim2.new(0, WELL_LEFT - 6, 1, -10)
		card.Size = UDim2.new(1, -(WELL_LEFT - 6) - 10, 0, 0)
	else
		card.Position = UDim2.new(1, 24, 0, 74)
		card.Size = UDim2.fromOffset(DETAIL_W, 0)
	end
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.ZIndex = 30
	card.Parent = contentPanel
	addCorner(card, 20)
	PanelChrome.gradient(card, BRIGHT.Panel, BRIGHT.PanelBottom)
	PanelChrome.stroke(card, BRIGHT.Outline, 4)
	addPadding(card, 14, 14, 14, 14)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = card
	inventoryDetail = card

	-- Name, with room on the right for the close button that overlaps the card's corner.
	local name = PanelChrome.display(card, {
		name = "ItemName", text = tool.Name, size = 28, stroke = 3, xAlign = Enum.TextXAlignment.Left, zIndex = 32,
		size2 = UDim2.new(1, -40, 0, 34),
	})
	name.TextScaled = true
	local nameCap = Instance.new("UITextSizeConstraint")
	nameCap.MaxTextSize = 28
	nameCap.MinTextSize = 14
	nameCap.Parent = name
	name.LayoutOrder = 1

	-- Rarity pill + what kind of sword it is.
	local tagRow = Instance.new("Frame")
	tagRow.BackgroundTransparency = 1
	tagRow.Size = UDim2.new(1, 0, 0, 28)
	tagRow.LayoutOrder = 2
	tagRow.ZIndex = 31
	tagRow.Parent = card
	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromOffset(0, 28)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.ZIndex = 32
	pill.Parent = tagRow
	addCorner(pill, 14)
	PanelChrome.gradient(pill, tileColors.top, tileColors.bottom)
	PanelChrome.stroke(pill, tileColors.rim, 2.5)
	addPadding(pill, 0, 12, 0, 12)
	local pillText = PanelChrome.display(pill, { text = string.upper(f.rarity), size = 17, stroke = 2, zIndex = 33 })
	pillText.Size = UDim2.fromScale(0, 1)
	pillText.AutomaticSize = Enum.AutomaticSize.X
	local kind = BossWeapons.SwordKind(tool)
	brightText(tagRow, { text = kind, font = Enum.Font.GothamBold, size = 14, color = BRIGHT.InkMuted, xAlign = Enum.TextXAlignment.Right, size2 = UDim2.new(1, 0, 1, 0), zIndex = 32 })

	-- The stats, gathered first: how many there are decides how big the hero render and the rows
	-- can be, so the card always fits the panel with its buttons on it.
	local stats = {}
	local function stat(icon, label, value, color)
		table.insert(stats, { icon, label, value, color })
	end
	stat(ICONS.Sword, "Damage", string.format("x%.2f", f.damageMult), Color3.fromRGB(255, 255, 255))
	if f.bossDrop then
		stat(ICONS.Trophy, "Rating", SwordValue.short(SwordValue.rateTool(tool)), BRIGHT.Gold)
	end
	if f.bonusDmg > 0 then stat(ICONS.Sword, "Bonus damage", string.format("+%d%%", math.round(f.bonusDmg * 100)), Color3.fromRGB(255, 120, 100)) end
	if f.critChance > 0 then stat(ICONS.Target, "Crit chance", string.format("+%d%%", math.round(f.critChance * 100)), Color3.fromRGB(255, 190, 70)) end
	if f.rangeBonus > 0 then stat(ICONS.Lighting, "Reach", string.format("+%s", tostring(f.rangeBonus)), Color3.fromRGB(120, 205, 255)) end
	if f.knockbackBonus > 0 then stat(ICONS.Shield, "Knockback", string.format("+%d", f.knockbackBonus), Color3.fromRGB(150, 240, 140)) end
	if f.bossDrop and tool:GetAttribute("Starter") ~= true then
		local dormant = math.max(f.storedCount - f.prefixCount, 0)
		stat(ICONS.Star, "Prefix slots", string.format("%d / %d%s", f.prefixCount, f.slots,
			dormant > 0 and string.format(" (+%d dormant)", dormant) or ""), BRIGHT.Gold)
	end
	local crowded = #stats > 3
	local heroH = if crowded then (narrow and 96 or 110) else (narrow and 118 or 150)
	local rowH, rowGap = if crowded then 36 else 40, if crowded then 6 else 8
	-- The card's height budget in panel units: on wide screens it hangs from y 74 and may run a
	-- little past the panel's foot (the fit leaves 44 spare below it); on phones it stands on the
	-- panel's foot and must stay under the title bar. Everything but the stats is fixed height.
	local maxCard = if narrow then layout.H - 70 else layout.H - 34
	local fixed = 28 + 34 + 28 + heroH + (layout.touch + 6) + 5 * 8 + 4 -- (+4: the stats box's padding)
	local rowsH = #stats * rowH + math.max(#stats - 1, 0) * rowGap
	local statsH = math.max(math.min(rowsH, maxCard - fixed), math.min(rowsH, rowH * 2 + rowGap))

	-- Hero render on the rarity colour.
	local hero = Instance.new("Frame")
	hero.Name = "Hero"
	hero.Size = UDim2.new(1, 0, 0, heroH)
	hero.LayoutOrder = 3
	hero.ZIndex = 31
	hero.Parent = card
	addCorner(hero, 16)
	PanelChrome.lootTile(hero, f.rarity, { radius = 16, zIndex = 31, glowY = 0.5 })
	local heroView = Instance.new("ViewportFrame")
	heroView.BackgroundTransparency = 1
	heroView.Size = UDim2.new(1, -8, 1, -8)
	heroView.Position = UDim2.fromOffset(4, 4)
	heroView.ZIndex = 32
	heroView.Parent = hero
	PanelChrome.renderTool(heroView, tool, { tiltDeg = 50, margin = 1.04 })
	if item.equipped then
		local b = PanelChrome.checkBadge(hero, 36, 34)
		b.Position = UDim2.new(1, -18, 0, 18)
	end

	-- Stats: big outlined numbers, one row each, in a box that scrolls when a sword has more rows
	-- than the card has room for (a boss drop with every bonus rolled), so EQUIP and SELL below
	-- always stay on the card instead of being pushed off the bottom of the screen.
	local scrolls = rowsH > statsH
	local statsBox = Instance.new("ScrollingFrame")
	statsBox.Name = "Stats"
	statsBox.BackgroundTransparency = 1
	statsBox.BorderSizePixel = 0
	statsBox.Size = UDim2.new(1, 0, 0, statsH + 4)
	statsBox.CanvasSize = UDim2.new()
	statsBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
	statsBox.ScrollingDirection = Enum.ScrollingDirection.Y
	statsBox.ScrollBarThickness = if scrolls then 6 else 0
	statsBox.ScrollBarImageColor3 = BRIGHT.Outline
	statsBox.ScrollingEnabled = scrolls
	statsBox.LayoutOrder = 10
	statsBox.ZIndex = 31
	statsBox.Parent = card
	addPadding(statsBox, 2, if scrolls then 10 else 2, 2, 2) -- room for the rows' strokes and the bar
	local statsList = Instance.new("UIListLayout")
	statsList.Padding = UDim.new(0, rowGap)
	statsList.SortOrder = Enum.SortOrder.LayoutOrder
	statsList.Parent = statsBox
	for i, st in ipairs(stats) do
		detailStatRow(statsBox, i, st[1], st[2], st[3], st[4], rowH)
	end

	-- Actions: EQUIP (any backpack sword) and SELL (unequipped boss drops), same as before.
	local canEquip = not item.equipped
	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.BackgroundTransparency = 1
	actions.Size = UDim2.new(1, 0, 0, layout.touch + 6)
	actions.LayoutOrder = 50
	actions.ZIndex = 31
	actions.Parent = card
	local actionsLayout = Instance.new("UIListLayout")
	actionsLayout.FillDirection = Enum.FillDirection.Horizontal
	actionsLayout.Padding = UDim.new(0, 10)
	actionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actionsLayout.Parent = actions
	local buttonCount = (canEquip and 1 or 0) + (f.sellable and 1 or 0)
	local buttonWidth = if buttonCount == 2 then UDim2.new(0.5, -5, 0, layout.touch) else UDim2.new(1, 0, 0, layout.touch)

	if canEquip then
		-- Equipping is client-side, exactly what the default backpack strip did before it was
		-- hidden by SwordHotbarGui: the client owns its own character and backpack tools.
		local equipButton = PanelChrome.chunkyButton(actions, {
			name = "EquipButton", text = "EQUIP", color = BRIGHT.Green, colorDark = BRIGHT.GreenDark,
			size = buttonWidth, textSize = 28, zIndex = 33,
		})
		equipButton.LayoutOrder = 1
		equipButton.Activated:Connect(function()
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and tool.Parent then
				humanoid:EquipTool(tool)
			end
		end)
	end

	if f.sellable then
		-- The price is on the button, because a sell button with no number on it is a guess. It
		-- is the same price the KEEP-or-SELL prompt quoted at pickup: one table, one number.
		local sellText = f.sellValue > 0 and ("SELL  " .. goldText(f.sellValue)) or "SELL"
		local sellButton, sellLabel = PanelChrome.chunkyButton(actions, {
			name = "SellButton", text = sellText, color = BRIGHT.Gold, colorDark = BRIGHT.GoldDark,
			size = buttonWidth, textSize = 24, zIndex = 33,
		})
		sellButton.LayoutOrder = 2
		sellButton.Activated:Connect(function()
			if sellLabel.Text == "SELLING..." then return end
			sellButton.Active = false
			sellLabel.Text = "SELLING..."
			inventoryAction:FireServer("Sell", tool.Name)
			task.delay(5, function()
				if sellButton and sellButton.Parent and sellLabel.Text == "SELLING..." then
					sellButton.Active = true
					sellLabel.Text = sellText
				end
			end)
		end)
	end

	if buttonCount == 0 then
		local held = Instance.new("Frame")
		held.Name = "EquippedBadge"
		held.Size = UDim2.new(1, 0, 0, layout.touch)
		held.BackgroundColor3 = Color3.new(1, 1, 1)
		held.ZIndex = 32
		held.Parent = actions
		addCorner(held, 14)
		PanelChrome.gradient(held, Color3.fromRGB(214, 246, 206), Color3.fromRGB(170, 226, 160))
		PanelChrome.stroke(held, BRIGHT.GreenDark, 3)
		PanelChrome.display(held, { text = "EQUIPPED", size = 26, color = Color3.new(1, 1, 1), strokeColor = Color3.fromRGB(28, 110, 36), stroke = 3, zIndex = 33 })
	end

	local close = PanelChrome.chunkyButton(card, {
		name = "DetailClose", text = "X", color = Color3.fromRGB(176, 186, 206), colorDark = Color3.fromRGB(118, 128, 152),
		size = UDim2.fromOffset(layout.touch - 4, layout.touch - 4), anchor = Vector2.new(0.5, 0.5),
		pos = UDim2.new(1, 0, 0, 0), textSize = 30, zIndex = 36,
	})
	close.Position = UDim2.new(1, 8, 0, -8)
	-- UIListLayout would stack the button with the rest of the card, so it lives in an
	-- unlaid-out holder pinned to the card's top-right corner.
	local closeHolder = Instance.new("Frame")
	closeHolder.Name = "CloseHolder"
	closeHolder.BackgroundTransparency = 1
	closeHolder.Size = UDim2.new(1, 0, 0, 0)
	closeHolder.LayoutOrder = 0
	closeHolder.ZIndex = 35
	closeHolder.Parent = card
	close.Parent = closeHolder
	close.Activated:Connect(function()
		inventorySelection = nil
		buildInventoryPanel()
	end)
end

-- Tile label for long rolled names ("Sour Precision Voidrend Blade"): the last one or
-- two words, which name the sword itself. The detail card always shows the full name.
local function tileName(name)
	if #name <= 14 then return name end
	local words = string.split(name, " ")
	local two = if #words >= 2 then words[#words - 1] .. " " .. words[#words] else name
	return if #two <= 15 then two else words[#words]
end

-- One owned item card: rarity gradient under a thick dark outline with a rarity ring, the
-- sword rendered large enough to break out past the card's top edge, its damage multiplier
-- as a bold stroked number, the name on a strip along the bottom and a check when equipped.
local function buildItemTile(parent, item, order)
	local tool = item.tool
	local f = toolFacts(item)
	local tileColors = PanelChrome.RARITY_TILE[f.rarity] or PanelChrome.RARITY_TILE.Common
	local selected = inventorySelection == tool

	local tile = Instance.new("TextButton")
	tile.Name = "ItemTile"
	tile.Text = ""
	tile.AutoButtonColor = false
	tile.LayoutOrder = order
	tile.ZIndex = 24
	tile.Parent = parent
	addCorner(tile, 18)
	local outline = PanelChrome.lootTile(tile, f.rarity, { radius = 18, zIndex = 24, glowY = 0.4 })
	if selected then
		outline.Thickness = 4.5
		outline.Color = BRIGHT.Blue
	end

	-- The render is bigger than the card and shifted up-right, so the blade tip pokes out
	-- past the card's edge the way PS99's item art overhangs its tile.
	local view = Instance.new("ViewportFrame")
	view.Name = "Icon"
	view.BackgroundTransparency = 1
	-- The whole sword, inside the card and above the name strip. It used to be drawn a quarter
	-- bigger than its frame (margin 0.8) and pushed up past the card's top edge, so the pommel
	-- and the tip were cut off, and the list's clipping cut the overhang off the top row too.
	view.Position = UDim2.new(0.03, 0, 0, 4)
	view.Size = UDim2.new(0.94, 0, 1, -34)
	view.ZIndex = 26
	view.Parent = tile
	PanelChrome.renderTool(view, tool, { tiltDeg = 45, margin = 1.04 })

	-- Name strip: rim-coloured band across the bottom (square top, rounded bottom).
	local strip = Instance.new("Frame")
	strip.Name = "NameStrip"
	strip.AnchorPoint = Vector2.new(0, 1)
	strip.Position = UDim2.fromScale(0, 1)
	strip.Size = UDim2.new(1, 0, 0, 28)
	strip.BackgroundColor3 = Color3.new(1, 1, 1)
	strip.BorderSizePixel = 0
	strip.ZIndex = 27
	strip.Parent = tile
	addCorner(strip, 16)
	PanelChrome.gradient(strip, tileColors.rim, tileColors.rim:Lerp(BRIGHT.Outline, 0.35))
	local stripTop = Instance.new("Frame")
	stripTop.BackgroundColor3 = tileColors.rim
	stripTop.BorderSizePixel = 0
	stripTop.Size = UDim2.new(1, 0, 0.5, 0)
	stripTop.ZIndex = 27
	stripTop.Parent = strip
	local nameLabel = PanelChrome.display(strip, { text = tileName(tool.Name), size = 17, stroke = 2, scaled = true, minSize = 11, zIndex = 28 })
	nameLabel.Size = UDim2.new(1, -10, 1, -4)
	nameLabel.Position = UDim2.fromOffset(5, 2)

	PanelChrome.display(tile, {
		name = "Mult", text = string.format("x%.1f", f.damageMult), size = 22, stroke = 3,
		xAlign = Enum.TextXAlignment.Right, yAlign = Enum.TextYAlignment.Bottom, anchor = Vector2.new(1, 1),
		pos = UDim2.new(1, -7, 1, -27), size2 = UDim2.fromOffset(70, 26), zIndex = 29,
	})

	if item.equipped then
		local check = PanelChrome.checkBadge(tile, 34, 30)
		check.Position = UDim2.fromOffset(8, 8)
	end

	local scale = Instance.new("UIScale")
	scale.Scale = selected and 1.06 or 1
	scale.Parent = tile
	tile.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.07 }):Play()
	end)
	tile.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = selected and 1.06 or 1 }):Play()
	end)
	tile.Activated:Connect(function()
		inventorySelection = if selected then nil else tool
		buildInventoryPanel()
	end)
	return tile
end

-- Empty slot: a quiet recessed well (no border, no icon) so owned loot is what stands out.
local function buildEmptySlot(parent, order)
	local slot = Instance.new("Frame")
	slot.Name = "EmptySlot"
	slot.LayoutOrder = order
	slot.ZIndex = 24
	slot.Parent = parent
	PanelChrome.emptyWell(slot, { radius = 18, zIndex = 24 })
	return slot
end

buildInventoryPanel = function()
	clearBody()
	headerTitle.Text = "Inventory"

	local carriedTools = getCarriedTools()
	-- Equipped sword first, then the backpack in its own order.
	table.sort(carriedTools, function(a, b)
		if a.equipped ~= b.equipped then return a.equipped end
		return false
	end)
	local selectedItem = nil
	for _, item in ipairs(carriedTools) do
		if item.tool == inventorySelection then selectedItem = item end
	end
	if not selectedItem then inventorySelection = nil end

	-- ── Header row: section title + count, and the Auto-Sell toggle ───────────
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, layout.touch + 4)
	header.LayoutOrder = 1
	header.ZIndex = 23
	header.Parent = body

	local titleRow = Instance.new("Frame")
	titleRow.BackgroundTransparency = 1
	titleRow.Size = UDim2.new(0.5, 0, 1, 0)
	titleRow.ZIndex = 23
	titleRow.Parent = header
	local titleLayout = Instance.new("UIListLayout")
	titleLayout.FillDirection = Enum.FillDirection.Horizontal
	titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	titleLayout.Padding = UDim.new(0, 8)
	titleLayout.SortOrder = Enum.SortOrder.LayoutOrder
	titleLayout.Parent = titleRow
	local section = brightText(titleRow, { text = "Swords", font = PanelChrome.DISPLAY_FONT, size = 28, color = BRIGHT.Ink, size2 = UDim2.fromOffset(0, 36), zIndex = 24 })
	section.AutomaticSize = Enum.AutomaticSize.X
	section.LayoutOrder = 1
	local count = PanelChrome.display(titleRow, { text = tostring(#carriedTools), size = 28, color = BRIGHT.Blue, stroke = 3, size2 = UDim2.fromOffset(0, 36), zIndex = 24 })
	count.AutomaticSize = Enum.AutomaticSize.X
	count.LayoutOrder = 2

	-- The AUTO-SELL toggle stood here. It is gone with auto-sell itself: a drop now opens a
	-- KEEP-or-SELL prompt on the reveal (SwordDropSystem + SwordDropToast), so the decision is
	-- made once, per sword, in front of the player -- not set once in a panel they may never
	-- open and then applied silently forever.

	local caption = brightText(body, {
		text = "Every drop asks KEEP or SELL when it lands. Anything you kept sells here for the same price. Tap a sword for its stats.",
		font = Enum.Font.GothamMedium, size = 13, color = BRIGHT.Ink, xAlign = Enum.TextXAlignment.Center,
		size2 = UDim2.new(1, 0, 0, 0), wrap = true, zIndex = 23,
	})
	caption.AutomaticSize = Enum.AutomaticSize.Y
	caption.LayoutOrder = 2

	-- ── Item grid ─────────────────────────────────────────────────────────────
	local grid = Instance.new("Frame")
	grid.Name = "ItemGrid"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.LayoutOrder = 3
	grid.ZIndex = 23
	grid.Parent = body
	addPadding(grid, 14, 0, 6, 0)
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(TILE, TILE)
	gridLayout.CellPadding = UDim2.fromOffset(TILE_GAP, TILE_GAP)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.FillDirectionMaxCells = layout.cols
	gridLayout.Parent = grid

	for i, item in ipairs(carriedTools) do
		buildItemTile(grid, item, i)
	end
	local cols = layout.cols
	local minRows = layoutMode == "narrow" and 4 or 3
	local slots = math.max(cols * minRows, math.ceil((#carriedTools + 1) / cols) * cols)
	for i = #carriedTools + 1, slots do
		buildEmptySlot(grid, i)
	end

	if selectedItem then openInventoryDetail(selectedItem) end
	if refreshRailBadges then refreshRailBadges() end
end

-- ── Skills tab ───────────────────────────────────────────────────────────────
-- PS99-style upgrade rows: a big rarity-style icon tile, a stroked title, the per-point effect,
-- a bar with the stat's running total, the current level as a big gold number, and a chunky
-- green up-arrow button that costs 1 SP (greyed when there are no points to spend).
local SKILL_STYLE = {
	Strength = { tile = "Legendary", icon = ICONS.Skills, per = 5, unit = "DMG", short = "+5 sword damage" },
	Health = { tile = "Uncommon", heart = true, per = 20, unit = "HP", short = "+20 max HP" },
	Defense = { tile = "Rare", icon = ICONS.Shield, per = 0.3, cap = 35, short = "+0.3% damage blocked" },
	ExperienceGain = { tile = "Epic", icon = ICONS.Star, per = 0.5, cap = 35, short = "+0.5% bonus XP" },
}
local SKILL_GREEN = { top = Color3.fromRGB(150, 246, 88), bottom = Color3.fromRGB(64, 200, 44), lip = Color3.fromRGB(28, 128, 36) }
local SKILL_GREY = { top = Color3.fromRGB(222, 226, 236), bottom = Color3.fromRGB(166, 174, 192), lip = Color3.fromRGB(108, 116, 136) }
local SKILL_BAR = { top = Color3.fromRGB(120, 226, 255), bottom = Color3.fromRGB(34, 150, 236) }

-- Shapes drawn twice from Frames, a padded dark copy behind and the coloured copy in front, so
-- the whole silhouette gets one clean outline (same trick as LevelProgressGui's heart).
-- Each piece is { cx, cy, w, h, rotation, round } in fractions of a square holder.
local ARROW_PIECES = {
	{ 0.5, 0.64, 0.36, 0.52, 0, false },
	{ 0.30, 0.38, 0.66, 0.31, -45, true },
	{ 0.70, 0.38, 0.66, 0.31, 45, true },
}
local HEART_PIECES = {
	{ 0.30, 0.36, 0.46, 0.46, 0, true },
	{ 0.70, 0.36, 0.46, 0.46, 0, true },
	{ 0.50, 0.55, 0.50, 0.50, 45, false },
}
local GEM_PIECES = {
	{ 0.5, 0.5, 0.64, 0.64, 45, false },
}

local function shapeLayer(holder, pieces, color, pad, z)
	local parts = {}
	for _, p in ipairs(pieces) do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(p[1], p[2])
		f.Size = UDim2.new(p[3], pad, p[4], pad)
		f.Rotation = p[5]
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.ZIndex = z
		f.Parent = holder
		local c = Instance.new("UICorner")
		c.CornerRadius = if p[6] then UDim.new(0.5, 0) else UDim.new(0.14, 0)
		c.Parent = f
		table.insert(parts, f)
	end
	return parts
end

local function shapeIcon(parent, pieces, color, props)
	local holder = Instance.new("Frame")
	holder.Name = props.name or "Shape"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = props.anchor or Vector2.new(0.5, 0.5)
	holder.Position = props.pos or UDim2.fromScale(0.5, 0.5)
	holder.Size = props.size or UDim2.fromScale(1, 1)
	holder.Rotation = props.rotation or 0
	holder.ZIndex = props.zIndex
	holder.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = holder
	shapeLayer(holder, pieces, props.outline or BRIGHT.Outline, props.pad or 7, props.zIndex)
	local fill = shapeLayer(holder, pieces, color, 0, props.zIndex + 1)
	return holder, fill
end

-- The skill-point currency: a cyan gem with a lit upper face.
local function spGem(parent, size, props)
	local holder = shapeIcon(parent, GEM_PIECES, Color3.fromRGB(40, 176, 246), {
		name = "SPGem", size = UDim2.fromOffset(size, size), zIndex = props.zIndex,
		anchor = props.anchor, pos = props.pos, pad = math.max(4, math.floor(size / 9)),
	})
	local face = Instance.new("Frame")
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.42)
	face.Size = UDim2.fromScale(0.34, 0.34)
	face.Rotation = 45
	face.BackgroundColor3 = Color3.fromRGB(150, 236, 255)
	face.BorderSizePixel = 0
	face.ZIndex = props.zIndex + 2
	face.Parent = holder
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0.18, 0)
	fc.Parent = face
	if props.layoutOrder then holder.LayoutOrder = props.layoutOrder end
	return holder
end

-- Chunky upgrade button: a dark-green lip under an offset glossy face gives it a bevelled
-- bottom edge; a white outlined up-arrow and the "1 SP" cost sit on the face.
local function skillUpgradeButton(parent, w, h, z)
	local btn = Instance.new("TextButton")
	btn.Name = "Upgrade"
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.BackgroundTransparency = 1
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Size = UDim2.fromOffset(w, h)
	btn.ZIndex = z
	btn.Parent = parent

	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.Size = UDim2.fromScale(1, 1)
	lip.BackgroundColor3 = SKILL_GREEN.lip
	lip.BorderSizePixel = 0
	lip.ZIndex = z
	lip.Parent = btn
	addCorner(lip, 18)
	PanelChrome.stroke(lip, BRIGHT.Outline, 3)

	local LIP = 9
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, -LIP)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.ZIndex = z + 1
	face.Parent = btn
	addCorner(face, 18)
	local grad = PanelChrome.gradient(face, SKILL_GREEN.top, SKILL_GREEN.bottom)
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.6
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromOffset(7, 5)
	shine.Size = UDim2.new(1, -14, 0.3, 0)
	shine.ZIndex = z + 1
	shine.Parent = face
	addCorner(shine, 12)
	local sg = Instance.new("UIGradient")
	sg.Rotation = 90
	sg.Transparency = NumberSequence.new(0.2, 1)
	sg.Parent = shine

	local arrowSize = math.floor((h - LIP) * 0.66)
	shapeIcon(face, ARROW_PIECES, Color3.new(1, 1, 1), {
		name = "Arrow", size = UDim2.fromOffset(arrowSize, arrowSize), zIndex = z + 2,
		anchor = Vector2.new(0.5, 0.5), pos = UDim2.new(0.5, 0, 0, math.floor((h - LIP) * 0.37)),
		pad = math.max(6, math.floor(arrowSize / 7)),
	})
	local cost = PanelChrome.display(face, {
		name = "Cost", text = "1 SP", size = math.floor((h - LIP) * 0.3), stroke = 2.5, zIndex = z + 4,
		anchor = Vector2.new(0.5, 1), pos = UDim2.new(0.5, 0, 1, -2), size2 = UDim2.new(1, -8, 0.32, 0),
	})

	-- Shared press feedback; the face sinks onto its lip.
	PanelChrome.pressFeedback(btn, { face = face, drop = 5 })
	return { button = btn, lip = lip, grad = grad, cost = cost }
end

local function skillEffectText(attr, level)
	local style = SKILL_STYLE[attr.name]
	if style.cap then
		local pct = math.min(level * style.per, style.cap)
		return string.format("%s%% / %d%%", (string.format("%.1f", pct):gsub("%.0$", "")), style.cap), pct / style.cap
	end
	return string.format("+%s %s", NumberFormat.short(level * style.per), style.unit), nil
end

local function buildSkillRow(parent, attr, order, narrow)
	local style = SKILL_STYLE[attr.name]
	local rowH = narrow and 122 or 92
	local tileSize = narrow and 64 or 74
	local btnW, btnH = if narrow then 100 else 116, if narrow then 70 else 74
	local rightW = if narrow then btnW else btnW + 84
	local z = 24

	local row = Instance.new("Frame")
	row.Name = "Skill_" .. attr.name
	row.Size = UDim2.new(1, 0, 0, rowH)
	row.BackgroundColor3 = Color3.new(1, 1, 1)
	row.LayoutOrder = order
	row.ZIndex = 23
	row.Parent = parent
	addCorner(row, 18)
	PanelChrome.gradient(row, Color3.fromRGB(255, 255, 255), BRIGHT.Row)
	PanelChrome.stroke(row, BRIGHT.Outline, 3.5)
	addPadding(row, 9, 10, 9, 9)

	-- Icon tile
	local tile = Instance.new("Frame")
	tile.Name = "IconTile"
	tile.Size = UDim2.fromOffset(tileSize, tileSize)
	if not narrow then
		tile.AnchorPoint = Vector2.new(0, 0.5)
		tile.Position = UDim2.fromScale(0, 0.5)
	end
	tile.ZIndex = z
	tile.Parent = row
	addCorner(tile, 16)
	PanelChrome.lootTile(tile, style.tile, { radius = 16, zIndex = z, glowY = 0.5 })
	if style.heart then
		shapeIcon(tile, HEART_PIECES, Color3.fromRGB(236, 44, 70), {
			name = "Heart", size = UDim2.fromScale(0.74, 0.74), pos = UDim2.fromScale(0.5, 0.54),
			rotation = -8, zIndex = z + 2, pad = 6,
		})
	else
		local img = Instance.new("ImageLabel")
		img.Name = "Icon"
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(0.88, 0.88)
		img.Image = style.icon
		img.ScaleType = Enum.ScaleType.Fit
		img.Rotation = -6
		img.ZIndex = z + 2
		img.Parent = tile
	end

	-- Title, per-point effect and the running-total bar
	local textX = tileSize + 12
	local textW = UDim2.new(1, -(textX + rightW + 10), 0, 0)
	local title = PanelChrome.display(row, {
		name = "Title", text = attr.label, size = narrow and 26 or 30, stroke = 3, scaled = true, minSize = 16,
		xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(textX, narrow and -2 or -3),
		size2 = textW + UDim2.fromOffset(0, narrow and 30 or 32), zIndex = z + 1,
	})
	title.Name = "Title"
	local desc = brightText(row, {
		text = style.short .. " per level", font = Enum.Font.GothamBold, size = narrow and 13 or 14,
		color = BRIGHT.Ink, pos = UDim2.fromOffset(textX, narrow and 28 or 29),
		size2 = textW + UDim2.fromOffset(0, narrow and 34 or 18), wrap = narrow, zIndex = z + 1,
	})
	desc.TextYAlignment = Enum.TextYAlignment.Top

	local barH = narrow and 26 or 22
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0, 1)
	if narrow then
		bar.Position = UDim2.new(0, 0, 1, -2)
		bar.Size = UDim2.new(1, -(rightW + 10), 0, barH)
	else
		bar.Position = UDim2.new(0, textX, 1, -2)
		bar.Size = textW + UDim2.fromOffset(0, barH)
	end
	bar.BackgroundColor3 = Color3.fromRGB(96, 104, 128)
	bar.ZIndex = z + 1
	bar.Parent = row
	addCorner(bar, 12)
	PanelChrome.stroke(bar, BRIGHT.Outline, 2.5)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.ZIndex = z + 2
	fill.Parent = bar
	addCorner(fill, 12)
	PanelChrome.gradient(fill, SKILL_BAR.top, SKILL_BAR.bottom)
	if style.cap then
		-- Quarter ticks, like PS99's segmented upgrade bars.
		for i = 1, 3 do
			local tick = Instance.new("Frame")
			tick.AnchorPoint = Vector2.new(0.5, 0.5)
			tick.Position = UDim2.fromScale(i / 4, 0.5)
			tick.Size = UDim2.new(0, 3, 1, -8)
			tick.BackgroundColor3 = BRIGHT.Outline
			tick.BackgroundTransparency = 0.45
			tick.BorderSizePixel = 0
			tick.ZIndex = z + 3
			tick.Parent = bar
		end
	else
		fill.Size = UDim2.fromScale(1, 1)
		fill:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(Color3.fromRGB(255, 150, 120), Color3.fromRGB(232, 70, 60))
		if attr.name == "Strength" then
			fill:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(Color3.fromRGB(255, 214, 90), Color3.fromRGB(240, 140, 20))
		end
	end
	local barText = PanelChrome.display(bar, {
		name = "Total", text = "", size = narrow and 18 or 18, stroke = 2.5, zIndex = z + 4,
		pos = UDim2.fromOffset(0, 0), size2 = UDim2.fromScale(1, 1),
	})

	-- Level readout and the upgrade button (level sits above the button on phones)
	local levelBox = Instance.new("Frame")
	levelBox.Name = "Level"
	levelBox.BackgroundTransparency = 1
	levelBox.ZIndex = z
	levelBox.Parent = row
	if narrow then
		levelBox.AnchorPoint = Vector2.new(1, 0)
		levelBox.Position = UDim2.new(1, 0, 0, -4)
		levelBox.Size = UDim2.fromOffset(btnW, 36)
	else
		levelBox.AnchorPoint = Vector2.new(1, 0.5)
		levelBox.Position = UDim2.new(1, -(btnW + 6), 0.5, 0)
		levelBox.Size = UDim2.fromOffset(78, rowH - 18)
	end
	local lvTag = brightText(levelBox, {
		text = "LV", font = PanelChrome.DISPLAY_FONT, size = narrow and 16 or 18, color = BRIGHT.InkMuted,
		xAlign = if narrow then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		pos = if narrow then UDim2.fromOffset(2, 4) else UDim2.fromOffset(0, 2),
		size2 = if narrow then UDim2.fromOffset(28, 30) else UDim2.new(1, 0, 0, 20), zIndex = z + 1,
	})
	lvTag.Name = "Tag"
	local level = PanelChrome.display(levelBox, {
		name = "Value", text = "0", size = narrow and 32 or 42, stroke = 3.5, color = BRIGHT.Gold, scaled = true, minSize = 16,
		xAlign = if narrow then Enum.TextXAlignment.Right else Enum.TextXAlignment.Center,
		pos = if narrow then UDim2.fromOffset(28, 0) else UDim2.fromOffset(0, 18),
		size2 = if narrow then UDim2.new(1, -28, 1, 0) else UDim2.new(1, 0, 1, -18), zIndex = z + 2,
	})

	local up = skillUpgradeButton(row, btnW, btnH, z + 1)
	if narrow then
		up.button.AnchorPoint = Vector2.new(1, 1)
		up.button.Position = UDim2.new(1, 0, 1, 0)
	else
		up.button.Position = UDim2.new(1, 0, 0.5, 0)
	end
	-- Tap spends one; press and hold repeats, speeding up (1, 1, 2, 3, 5, 5 ...), so a stack of
	-- banked points is a second's hold, not a hundred clicks. The server clamps every amount.
	local holding, repeated = false, false
	up.button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		holding, repeated = true, false
		task.delay(0.45, function()
			local steps = { 1, 1, 2, 3, 5 }
			local i = 0
			while holding and (player:GetAttribute("SkillPoints") or 0) > 0 do
				i += 1
				repeated = true
				spendEvent:FireServer(attr.name, steps[math.min(i, #steps)])
				task.wait(0.15)
			end
		end)
	end)
	up.button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			holding = false
		end
	end)
	up.button.Activated:Connect(function()
		if repeated then
			repeated = false
			return -- the hold already spent; the release is not a tap
		end
		spendEvent:FireServer(attr.name, 1)
	end)
	return { value = level, bar = fill, barText = barText, up = up }
end

local function buildSkillsPanel()
	clearBody()
	headerTitle.Text = "Skills"
	skillButtons = {}
	local narrow = layoutMode == "narrow"

	-- Currency strip: the skill-point gem and a big stroked count, centred like PS99's row.
	local strip = Instance.new("Frame")
	strip.Name = "PointsStrip"
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.new(1, 0, 0, 42)
	strip.LayoutOrder = 1
	strip.ZIndex = 23
	strip.Parent = body
	local stripLayout = Instance.new("UIListLayout")
	stripLayout.FillDirection = Enum.FillDirection.Horizontal
	stripLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stripLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	stripLayout.Padding = UDim.new(0, 8)
	stripLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stripLayout.Parent = strip
	spGem(strip, 42, { zIndex = 24, layoutOrder = 1 })
	local points = PanelChrome.display(strip, { name = "Points", text = "0", size = 38, stroke = 3.5, size2 = UDim2.fromOffset(0, 44), zIndex = 25 })
	points.AutomaticSize = Enum.AutomaticSize.X
	points.LayoutOrder = 2
	local caption = brightText(strip, {
		text = "SKILL POINTS", font = PanelChrome.DISPLAY_FONT, size = narrow and 20 or 22, color = BRIGHT.Ink,
		size2 = UDim2.fromOffset(0, 44), zIndex = 24,
	})
	caption.AutomaticSize = Enum.AutomaticSize.X
	caption.LayoutOrder = 3
	skillButtons.points = points

	-- Rows sit in their own list with a tighter gap so all four fit the wide panel unscrolled.
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Size = UDim2.new(1, 0, 0, 0)
	rows.AutomaticSize = Enum.AutomaticSize.Y
	rows.LayoutOrder = 2
	rows.ZIndex = 23
	rows.Parent = body
	local rowsLayout = Instance.new("UIListLayout")
	rowsLayout.Padding = UDim.new(0, 8)
	rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowsLayout.Parent = rows
	for i, attr in ipairs(SKILL_ATTRIBUTES) do
		skillButtons[attr.name] = buildSkillRow(rows, attr, i, narrow)
	end
end

-- Last RebirthResult the server sent, rendered as a status line in the panel below.
-- The server has always fired this event; until now nothing on the client listened,
-- so a refused rebirth failed silently.
local lastRebirthResult = nil
-- Set by buildRebirthPanel: refreshes only the hero's status line (price / payback / more gold)
-- when the server's payback tick changes, so the tab is not rebuilt every few seconds.
local rebirthStatusRefresh = nil

-- ── Rebirth tab ──────────────────────────────────────────────────────────────
-- PS99 rank-rewards layout on the light panel: a blue hero card (rebirth medallion, "Rebirth N",
-- a thick level bar and the chunky REBIRTH button), a row of bonus tiles showing each multiplier
-- now -> after the next rebirth in big outlined numbers, and a grid of milestone reward cards
-- (claimed / next / locked) with 3D perk icons. Tapping a card shows its perk in the strip below.
-- All numbers come from RebirthConfig so this can't drift from the server's maths.
local REBIRTH_ICON = "rbxassetid://80234316052758"
local REBIRTH_BLUE = { top = Color3.fromRGB(128, 214, 255), bottom = Color3.fromRGB(46, 146, 240), rim = Color3.fromRGB(22, 90, 190) }
local BONUS_TILES = {
	{ key = "xpMult", label = "XP", fmt = "x%.2f", icon = ICONS.Star, top = Color3.fromRGB(222, 168, 255), bottom = Color3.fromRGB(146, 70, 230) },
	{ key = "goldMult", label = "Gold", fmt = "x%.2f", icon = ICONS.Coin, top = Color3.fromRGB(255, 236, 120), bottom = Color3.fromRGB(246, 160, 24) },
	{ key = "damageMult", label = "Damage", fmt = "x%.2f", icon = ICONS.Sword, top = Color3.fromRGB(255, 150, 130), bottom = Color3.fromRGB(226, 56, 60) },
	{ key = "healthMult", label = "Health", fmt = "x%.2f", heart = true, top = Color3.fromRGB(255, 176, 206), bottom = Color3.fromRGB(232, 80, 140) },
	{ key = "bonusSkillPoints", label = "Skill Pts", fmt = "+%d", gem = true, top = Color3.fromRGB(140, 236, 255), bottom = Color3.fromRGB(30, 168, 226) },
	{ key = "luck", label = "Luck", fmt = "+%d%%", icon = ICONS.Trophy, top = Color3.fromRGB(176, 246, 142), bottom = Color3.fromRGB(56, 186, 70) },
}
local PERK_STATE = {
	claimed = { top = Color3.fromRGB(170, 250, 110), bottom = Color3.fromRGB(62, 196, 52), rim = Color3.fromRGB(26, 128, 36), text = "Claimed!" },
	next = { top = Color3.fromRGB(255, 240, 130), bottom = Color3.fromRGB(255, 170, 24), rim = Color3.fromRGB(190, 104, 6), text = "Next!" },
	locked = { top = Color3.fromRGB(226, 230, 240), bottom = Color3.fromRGB(162, 170, 190), rim = Color3.fromRGB(116, 124, 146), text = "Locked" },
}

-- Small 3D perk icons, built from parts and framed in a ViewportFrame like PS99's rendered art.
local function perkPart(model, root, shape, size, cf, color, neon)
	local p = Instance.new("Part")
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = root * cf
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
local GOLD3D = Color3.fromRGB(255, 196, 40)
local PERK_MODELS = {
	-- Ascendant Strike: a gleaming sword with a glowing fuller, blade up.
	[1] = function(m)
		local r = CFrame.Angles(math.rad(8), math.rad(-24), 0) * CFrame.Angles(0, 0, math.rad(-38))
		perkPart(m, r, nil, Vector3.new(0.6, 3.6, 0.18), CFrame.new(0, 1.4, 0), Color3.fromRGB(226, 236, 252))
		perkPart(m, r, nil, Vector3.new(0.16, 3.2, 0.22), CFrame.new(0, 1.3, 0), Color3.fromRGB(110, 210, 255), true)
		perkPart(m, r, nil, Vector3.new(0.42, 0.42, 0.18), CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(226, 236, 252))
		perkPart(m, r, nil, Vector3.new(1.9, 0.34, 0.42), CFrame.new(0, -0.45, 0), GOLD3D)
		perkPart(m, r, BALL, Vector3.new(0.5, 0.5, 0.5), CFrame.new(-0.98, -0.45, 0), GOLD3D)
		perkPart(m, r, BALL, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0.98, -0.45, 0), GOLD3D)
		perkPart(m, r, nil, Vector3.new(0.32, 1.1, 0.32), CFrame.new(0, -1.15, 0), Color3.fromRGB(124, 72, 40))
		perkPart(m, r, BALL, Vector3.new(0.56, 0.56, 0.56), CFrame.new(0, -1.82, 0), GOLD3D)
	end,
	-- Glacial Endurance: a frozen heart with ice shards.
	[2] = function(m)
		local r = CFrame.Angles(math.rad(10), math.rad(-22), 0)
		local ice = Color3.fromRGB(96, 204, 255)
		perkPart(m, r, BALL, Vector3.new(1.7, 1.7, 1.7), CFrame.new(-0.55, 0.32, 0), ice)
		perkPart(m, r, BALL, Vector3.new(1.7, 1.7, 1.7), CFrame.new(0.55, 0.32, 0), ice)
		perkPart(m, r, nil, Vector3.new(1.55, 1.55, 1.3), CFrame.new(0, -0.36, 0) * CFrame.Angles(0, 0, math.rad(45)), ice)
		perkPart(m, r, BALL, Vector3.new(0.5, 0.5, 0.5), CFrame.new(-0.7, 0.62, 0.72), Color3.fromRGB(240, 252, 255))
		perkPart(m, r, nil, Vector3.new(0.34, 0.9, 0.34), CFrame.new(1.35, 1.05, 0) * CFrame.Angles(0, 0, math.rad(-30)), Color3.fromRGB(200, 240, 255))
		perkPart(m, r, nil, Vector3.new(0.28, 0.7, 0.28), CFrame.new(-1.45, -0.55, 0.2) * CFrame.Angles(0, 0, math.rad(35)), Color3.fromRGB(200, 240, 255))
	end,
	-- Infernal Precision: a bullseye, seen at an angle.
	[3] = function(m)
		local r = CFrame.Angles(math.rad(6), math.rad(-26), 0) * CFrame.Angles(0, math.rad(90), 0)
		local red, white = Color3.fromRGB(236, 52, 48), Color3.fromRGB(250, 250, 250)
		perkPart(m, r, CYL, Vector3.new(0.4, 3.1, 3.1), CFrame.new(0, 0, 0), red)
		perkPart(m, r, CYL, Vector3.new(0.44, 2.3, 2.3), CFrame.new(-0.03, 0, 0), white)
		perkPart(m, r, CYL, Vector3.new(0.48, 1.5, 1.5), CFrame.new(-0.06, 0, 0), red)
		perkPart(m, r, CYL, Vector3.new(0.52, 0.7, 0.7), CFrame.new(-0.09, 0, 0), Color3.fromRGB(255, 206, 40))
	end,
	-- Void Cleave: a violet cleaver with a glowing edge.
	[4] = function(m)
		local r = CFrame.Angles(math.rad(8), math.rad(-24), 0) * CFrame.Angles(0, 0, math.rad(18))
		perkPart(m, r, nil, Vector3.new(0.3, 3.4, 0.3), CFrame.new(0, -0.5, 0), Color3.fromRGB(110, 66, 40))
		perkPart(m, r, nil, Vector3.new(1.9, 1.5, 0.24), CFrame.new(0.95, 0.65, 0), Color3.fromRGB(146, 70, 236))
		perkPart(m, r, nil, Vector3.new(0.26, 1.5, 0.3), CFrame.new(1.96, 0.65, 0), Color3.fromRGB(226, 150, 255), true)
		perkPart(m, r, BALL, Vector3.new(0.56, 0.56, 0.56), CFrame.new(0, 1.28, 0), GOLD3D)
		perkPart(m, r, BALL, Vector3.new(0.46, 0.46, 0.46), CFrame.new(0, -2.25, 0), GOLD3D)
	end,
	-- Astral Supernova: a blazing star burst.
	[5] = function(m)
		local r = CFrame.Angles(math.rad(8), math.rad(-20), 0)
		for i = 0, 3 do
			local a = math.rad(i * 45)
			perkPart(m, r, nil, Vector3.new(0.5, 3.6, 0.5), CFrame.Angles(0, 0, a) * CFrame.Angles(0, math.rad(45), 0),
				if i % 2 == 0 then Color3.fromRGB(255, 150, 30) else Color3.fromRGB(255, 104, 60))
		end
		perkPart(m, r, BALL, Vector3.new(1.9, 1.9, 1.9), CFrame.new(0, 0, 0), Color3.fromRGB(255, 226, 80), true)
		perkPart(m, r, BALL, Vector3.new(0.9, 0.9, 0.9), CFrame.new(-0.25, 0.25, 0.7), Color3.fromRGB(255, 255, 236), true)
	end,
}

local function renderPerkIcon(viewport, id)
	viewport.Ambient = Color3.fromRGB(196, 196, 210)
	viewport.LightColor = Color3.fromRGB(255, 252, 240)
	viewport.LightDirection = Vector3.new(-1, -1.4, -0.9)
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local model = Instance.new("Model")
	local build = PERK_MODELS[id] or PERK_MODELS[5]
	build(model)
	local minV, maxV
	for _, part in ipairs(model:GetChildren()) do
		local h = part.Size / 2
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local p = part.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
					minV = minV and minV:Min(p) or p
					maxV = maxV and maxV:Max(p) or p
				end
			end
		end
	end
	model.Parent = world
	local fov = 30
	local centre, size = (minV + maxV) / 2, maxV - minV
	local fit = math.max(size.X, size.Y) * 0.5 * 1.04
	camera.FieldOfView = fov
	camera.CFrame = CFrame.lookAt(centre + Vector3.new(0, 0, fit / math.tan(math.rad(fov / 2)) + size.Z / 2), centre)
end

-- Padlock drawn from Frames: a two-tone shackle ring behind a gold body with a keyhole.
local function padlockIcon(parent, size, z)
	local holder = Instance.new("Frame")
	holder.Name = "Padlock"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(size, size)
	holder.ZIndex = z
	holder.Parent = parent
	local t = math.max(3, math.floor(size * 0.12))
	for i, spec in ipairs({ { BRIGHT.Outline, t + 4 }, { Color3.fromRGB(206, 212, 226), t } }) do
		local ring = Instance.new("Frame")
		ring.BackgroundTransparency = 1
		ring.AnchorPoint = Vector2.new(0.5, 0)
		ring.Position = UDim2.fromScale(0.5, 0.06)
		ring.Size = UDim2.fromScale(0.52, 0.62)
		ring.ZIndex = z + i - 1
		ring.Parent = holder
		addCorner(ring, size)
		PanelChrome.stroke(ring, spec[1], spec[2])
	end
	local lockBody = Instance.new("Frame")
	lockBody.AnchorPoint = Vector2.new(0.5, 1)
	lockBody.Position = UDim2.fromScale(0.5, 1)
	lockBody.Size = UDim2.fromScale(0.84, 0.56)
	lockBody.BackgroundColor3 = Color3.new(1, 1, 1)
	lockBody.ZIndex = z + 2
	lockBody.Parent = holder
	addCorner(lockBody, math.floor(size * 0.14))
	PanelChrome.gradient(lockBody, Color3.fromRGB(255, 226, 100), Color3.fromRGB(226, 146, 20))
	PanelChrome.stroke(lockBody, BRIGHT.Outline, 2.5)
	local hole = Instance.new("Frame")
	hole.AnchorPoint = Vector2.new(0.5, 0.5)
	hole.Position = UDim2.fromScale(0.5, 0.42)
	hole.Size = UDim2.fromScale(0.2, 0.3)
	hole.BackgroundColor3 = BRIGHT.Outline
	hole.BorderSizePixel = 0
	hole.ZIndex = z + 3
	hole.Parent = lockBody
	addCorner(hole, size)
	local slot = Instance.new("Frame")
	slot.AnchorPoint = Vector2.new(0.5, 0)
	slot.Position = UDim2.fromScale(0.5, 0.45)
	slot.Size = UDim2.fromScale(0.09, 0.34)
	slot.BackgroundColor3 = BRIGHT.Outline
	slot.BorderSizePixel = 0
	slot.ZIndex = z + 3
	slot.Parent = lockBody
	return holder
end

-- Glossy gradient card face: thick dark outline, an inner rim in the card's colour, top shine.
local function cardFace(frame, colors, radius, z)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	local g = PanelChrome.gradient(frame, colors.top, colors.bottom)
	g.Rotation = 80
	local outline = PanelChrome.stroke(frame, BRIGHT.Outline, 3.5)
	if colors.rim then
		local ring = Instance.new("Frame")
		ring.Name = "Rim"
		ring.BackgroundTransparency = 1
		ring.Position = UDim2.fromOffset(3, 3)
		ring.Size = UDim2.new(1, -6, 1, -6)
		ring.ZIndex = z
		ring.Parent = frame
		addCorner(ring, radius - 3)
		PanelChrome.stroke(ring, colors.rim, 2.5)
	end
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.55
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromOffset(6, 5)
	shine.Size = UDim2.new(1, -12, 0.26, 0)
	shine.ZIndex = z
	shine.Parent = frame
	addCorner(shine, radius - 6)
	local sg = Instance.new("UIGradient")
	sg.Transparency = NumberSequence.new(0, 1)
	sg.Rotation = 90
	sg.Parent = shine
	return outline
end

-- One bonus row: every row is the same neutral white card so only the stat icon carries colour,
-- and a single big "now -> next" line carries the change: the current value dimmed, a green
-- chevron, then the value after the next rebirth in bright green with a heavy outline.
local BONUS_ROW_STROKE = Color3.fromRGB(176, 188, 212)
local BONUS_NOW = Color3.fromRGB(150, 158, 178)
local BONUS_NEXT = Color3.fromRGB(96, 230, 76)

-- ARROW_PIECES turned a quarter clockwise (a parent's Rotation does not carry to its children).
local RIGHT_ARROW_PIECES = {
	{ 0.36, 0.5, 0.36, 0.52, 90, false },
	{ 0.62, 0.30, 0.66, 0.31, 45, true },
	{ 0.62, 0.70, 0.66, 0.31, 135, true },
}
local function chevron(parent, size, color, z, order)
	local holder = shapeIcon(parent, RIGHT_ARROW_PIECES, color, {
		name = "Chevron", size = UDim2.fromOffset(size, size), zIndex = z, pad = 5,
	})
	holder.LayoutOrder = order or 0
	return holder
end

-- One compact bonus chip (2 rows of 3 on wide screens): the stat icon on the left, a small
-- ink label, and under it one "now -> next" line, the current value dimmed and the value after
-- the next rebirth in big bright green with a heavy outline.
local function buildBonusRow(parent, spec, nowText, nextText, order)
	local z = 25
	local row = Instance.new("Frame")
	row.Name = "Bonus_" .. spec.label
	row.LayoutOrder = order
	row.BackgroundColor3 = Color3.new(1, 1, 1)
	row.ZIndex = z
	row.Parent = parent
	addCorner(row, 14)
	PanelChrome.gradient(row, Color3.fromRGB(255, 255, 255), Color3.fromRGB(234, 240, 250))
	PanelChrome.stroke(row, BONUS_ROW_STROKE, 2.5)
	local ICON = 40
	local iconBox = Instance.new("Frame")
	iconBox.Name = "Icon"
	iconBox.BackgroundTransparency = 1
	iconBox.AnchorPoint = Vector2.new(0, 0.5)
	iconBox.Position = UDim2.new(0, 5, 0.5, 0)
	iconBox.Size = UDim2.fromOffset(ICON, ICON)
	iconBox.ZIndex = z + 1
	iconBox.Parent = row
	if spec.heart then
		shapeIcon(iconBox, HEART_PIECES, Color3.fromRGB(236, 44, 70), { name = "Heart", size = UDim2.fromScale(0.86, 0.86), rotation = -8, zIndex = z + 2, pad = 5 })
	elseif spec.gem then
		spGem(iconBox, 36, { zIndex = z + 2, anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromScale(0.5, 0.5) })
	else
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = spec.icon
		img.ScaleType = Enum.ScaleType.Fit
		img.Rotation = -8
		img.ZIndex = z + 2
		img.Parent = iconBox
	end
	local textX = ICON + 10
	brightText(row, {
		text = spec.label, font = Enum.Font.GothamBlack, size = 13, color = BRIGHT.InkMuted, zIndex = z + 2,
		pos = UDim2.fromOffset(textX, 3), size2 = UDim2.new(1, -(textX + 6), 0, 15),
	}).Name = "Label"

	local values = Instance.new("Frame")
	values.Name = "Values"
	values.BackgroundTransparency = 1
	values.Position = UDim2.fromOffset(textX - 1, 17)
	values.Size = UDim2.new(1, -(textX + 4), 1, -19)
	values.ZIndex = z + 1
	values.Parent = row
	local vl = Instance.new("UIListLayout")
	vl.FillDirection = Enum.FillDirection.Horizontal
	vl.VerticalAlignment = Enum.VerticalAlignment.Center
	vl.Padding = UDim.new(0, 3)
	vl.SortOrder = Enum.SortOrder.LayoutOrder
	vl.Parent = values
	local nowLabel = PanelChrome.display(values, {
		name = "Now", text = nowText, size = 18, color = BONUS_NOW, strokeColor = Color3.new(1, 1, 1), stroke = 1.5,
		size2 = UDim2.fromOffset(0, 26), zIndex = z + 2,
	})
	nowLabel.AutomaticSize = Enum.AutomaticSize.X
	nowLabel.LayoutOrder = 1
	chevron(values, 16, BRIGHT.Green, z + 2, 2)
	local nextLabel = PanelChrome.display(values, {
		name = "Next", text = nextText, size = 27, color = BONUS_NEXT, stroke = 3,
		size2 = UDim2.fromOffset(0, 30), zIndex = z + 2,
	})
	nextLabel.AutomaticSize = Enum.AutomaticSize.X
	nextLabel.LayoutOrder = 3
	return row
end

local function buildRebirthPanel()
	clearBody()
	headerTitle.Text = "Rebirth"
	local narrow = layoutMode == "narrow"
	local level = 1
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
	if levelValue then level = levelValue.Value end
	local requirement = player:GetAttribute("RebirthRequirement") or 20
	local rebirths = player:GetAttribute("Rebirths") or 0
	-- Everything below comes from RebirthSystem's attributes: the price, the cap, the kept share
	-- and the payback at this player's own measured income. The panel renders, never computes.
	local goldValue = leaderstats and leaderstats:FindFirstChild("Gold")
	local purse = goldValue and goldValue.Value or (player:GetAttribute("Gold") or 0)
	local price = player:GetAttribute("RebirthGoldCost") or RebirthConfig.GetGoldCost(rebirths)
	local maxed = player:GetAttribute("RebirthMaxed") == true
	local maxCount = player:GetAttribute("RebirthMaxCount") or RebirthConfig.MAX_REBIRTHS
	local keepShare = player:GetAttribute("RebirthKeepShare") or RebirthConfig.RETAINED_SHARE
	local payback = tonumber(player:GetAttribute("RebirthPayback")) or -1
	local levelMet = level >= requirement
	local goldMet = purse >= price
	local ready = levelMet and goldMet and not maxed
	local function goldShort(n)
		local v = math.max(0, math.floor(tonumber(n) or 0))
		if v >= 1e6 then return string.format("%.2fM", v / 1e6) end
		if v >= 1e4 then return string.format("%.0fK", v / 1e3) end
		if v >= 1e3 then return string.format("%.1fK", v / 1e3) end
		return tostring(v)
	end
	local function hoursShort(sec)
		local m = math.floor(sec / 60 + 0.5)
		if m < 60 then return ("%dm"):format(math.max(1, m)) end
		if m < 60 * 48 then return ("%dh%02dm"):format(math.floor(m / 60), m % 60) end
		return ("%dh"):format(math.floor(m / 60))
	end

	local milestoneIds = {}
	for id in pairs(RebirthConfig.Milestones) do table.insert(milestoneIds, id) end
	table.sort(milestoneIds)
	local claimedCount = 0
	for _, id in ipairs(milestoneIds) do
		if rebirths >= id then claimedCount += 1 end
	end

	local page = Instance.new("Frame")
	page.Name = "RebirthPage"
	page.BackgroundTransparency = 1
	page.Size = UDim2.new(1, 0, 0, 0)
	page.AutomaticSize = Enum.AutomaticSize.Y
	page.LayoutOrder = 1
	page.ZIndex = 23
	page.Parent = body
	local pageLayout = Instance.new("UIListLayout")
	pageLayout.Padding = UDim.new(0, 6)
	pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pageLayout.Parent = page

	-- ── Hero: medallion, "Rebirth N", thick level bar, status line, REBIRTH button ──────
	local HERO_ROW = 78
	local BTN_W, BTN_H = 178, 78
	local hero = Instance.new("Frame")
	hero.Name = "Hero"
	hero.Size = UDim2.new(1, 0, 0, if narrow then HERO_ROW + 16 + 8 + 70 else HERO_ROW + 16)
	hero.LayoutOrder = 1
	hero.ZIndex = 24
	hero.Parent = page
	addCorner(hero, 20)
	cardFace(hero, REBIRTH_BLUE, 20, 24)
	addPadding(hero, 8, 10, 8, 8)

	local medal = Instance.new("Frame")
	medal.Name = "Medallion"
	medal.Size = UDim2.fromOffset(HERO_ROW, HERO_ROW)
	medal.BackgroundColor3 = Color3.new(1, 1, 1)
	medal.ZIndex = 25
	medal.Parent = hero
	addCorner(medal, HERO_ROW)
	PanelChrome.gradient(medal, Color3.fromRGB(255, 244, 150), Color3.fromRGB(246, 158, 20))
	PanelChrome.stroke(medal, BRIGHT.Outline, 3.5)
	local medalImg = Instance.new("ImageLabel")
	medalImg.BackgroundTransparency = 1
	medalImg.AnchorPoint = Vector2.new(0.5, 0.5)
	medalImg.Position = UDim2.fromScale(0.5, 0.48)
	medalImg.Size = UDim2.fromScale(0.86, 0.86)
	medalImg.Image = REBIRTH_ICON
	medalImg.ScaleType = Enum.ScaleType.Fit
	medalImg.ZIndex = 26
	medalImg.Parent = medal

	local textX = HERO_ROW + 12
	local rightW = if narrow then 0 else BTN_W + 12
	local titleRow = Instance.new("Frame")
	titleRow.Name = "TitleRow"
	titleRow.BackgroundTransparency = 1
	titleRow.Position = UDim2.fromOffset(textX, -2)
	titleRow.Size = UDim2.new(1, -(textX + rightW), 0, 34)
	titleRow.ZIndex = 25
	titleRow.Parent = hero
	local titleLayout = Instance.new("UIListLayout")
	titleLayout.FillDirection = Enum.FillDirection.Horizontal
	titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	titleLayout.Padding = UDim.new(0, 8)
	titleLayout.SortOrder = Enum.SortOrder.LayoutOrder
	titleLayout.Parent = titleRow
	local word = PanelChrome.display(titleRow, { name = "Word", text = "Rebirth", size = 32, stroke = 3.5, size2 = UDim2.fromOffset(0, 34), zIndex = 26 })
	word.AutomaticSize = Enum.AutomaticSize.X
	word.LayoutOrder = 1
	local count = PanelChrome.display(titleRow, { name = "Count", text = tostring(rebirths), size = 34, color = BRIGHT.Gold, stroke = 3.5, size2 = UDim2.fromOffset(0, 34), zIndex = 26 })
	count.AutomaticSize = Enum.AutomaticSize.X
	count.LayoutOrder = 2

	local bar = Instance.new("Frame")
	bar.Name = "LevelBar"
	bar.Position = UDim2.fromOffset(textX, 34)
	bar.Size = UDim2.new(1, -(textX + rightW), 0, 28)
	bar.BackgroundColor3 = Color3.fromRGB(28, 44, 92)
	bar.ZIndex = 25
	bar.Parent = hero
	addCorner(bar, 14)
	PanelChrome.stroke(bar, BRIGHT.Outline, 3)
	local frac = math.clamp(level / math.max(requirement, 1), 0, 1)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(math.max(frac, 0.08), 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.ZIndex = 26
	fill.Parent = bar
	addCorner(fill, 14)
	PanelChrome.gradient(fill, Color3.fromRGB(170, 250, 110), Color3.fromRGB(56, 190, 50))
	local fillShine = Instance.new("Frame")
	fillShine.BackgroundColor3 = Color3.new(1, 1, 1)
	fillShine.BackgroundTransparency = 0.55
	fillShine.BorderSizePixel = 0
	fillShine.Position = UDim2.fromOffset(6, 3)
	fillShine.Size = UDim2.new(1, -12, 0.3, 0)
	fillShine.ZIndex = 26
	fillShine.Parent = fill
	addCorner(fillShine, 6)
	PanelChrome.display(bar, {
		name = "Text", text = if maxed then ("MAX %d / %d"):format(rebirths, maxCount) elseif ready then "READY!" else ("Lv %d / %d"):format(level, requirement),
		size = 20, stroke = 2.5, zIndex = 27,
	})

	-- The status line is the decision, in the server's numbers: the price, what a wipe keeps, and
	-- how long the next rung's extra gold takes to pay the price back at this player's own pace.
	-- It re-reads the live attributes so the payback tick can refresh just this line.
	local function statusLine()
		local livePurse = goldValue and goldValue.Value or purse
		local livePayback = tonumber(player:GetAttribute("RebirthPayback")) or -1
		local paybackText = if livePayback >= 0 then ("pays back in ~%s"):format(hoursShort(livePayback)) else "pays back: farm a little first"
		if lastRebirthResult then
			if lastRebirthResult.ok then
				return ("Rebirth complete! Now rebirth %d"):format(lastRebirthResult.rebirths or rebirths), Color3.fromRGB(170, 255, 140)
			elseif lastRebirthResult.reason == "maxed" then
				return ("Rebirth %d is the last rung: the ladder ends here"):format(maxCount), Color3.fromRGB(255, 220, 150)
			elseif lastRebirthResult.reason == "gold" then
				return ("Not yet! %s more gold (costs %s)"):format(goldShort(price - livePurse), goldShort(price)), Color3.fromRGB(255, 150, 150)
			end
			return ("Not yet! Reach level %d"):format(lastRebirthResult.need or requirement), Color3.fromRGB(255, 150, 150)
		elseif maxed then
			return ("All %d rebirths bought. Every multiplier is yours to keep."):format(maxCount), Color3.fromRGB(255, 220, 150)
		end
		return ("Costs %s gold, keeps %d%% of your stats, %s"):format(goldShort(price), math.floor(keepShare * 100 + 0.5), paybackText), Color3.new(1, 1, 1)
	end
	local statusText, statusColor = statusLine()
	local statusLabel = PanelChrome.display(hero, {
		name = "Status", text = statusText, size = 17, color = statusColor, stroke = 2.5, scaled = true, minSize = 12,
		xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(textX + 2, 62), size2 = UDim2.new(1, -(textX + rightW + 2), 0, 20), zIndex = 26,
	})
	rebirthStatusRefresh = function()
		if not statusLabel or not statusLabel.Parent then return end
		local text, color = statusLine()
		statusLabel.Text = text
		statusLabel.TextColor3 = color
	end

	-- REBIRTH: a chunky bevelled button, green when the level requirement is met and greyed
	-- until then. It fires the same remote either way; RebirthSystem decides and replies.
	local btnH = if narrow then 70 else BTN_H
	local rebirthButton = Instance.new("TextButton")
	rebirthButton.Name = "RebirthButton"
	rebirthButton.Text = ""
	rebirthButton.AutoButtonColor = false
	rebirthButton.BackgroundTransparency = 1
	rebirthButton.ZIndex = 26
	rebirthButton.Parent = hero
	if narrow then
		rebirthButton.AnchorPoint = Vector2.new(0.5, 1)
		rebirthButton.Position = UDim2.new(0.5, 0, 1, 0)
		rebirthButton.Size = UDim2.new(1, 0, 0, btnH)
	else
		rebirthButton.AnchorPoint = Vector2.new(1, 0.5)
		rebirthButton.Position = UDim2.new(1, 0, 0.5, 0)
		rebirthButton.Size = UDim2.fromOffset(BTN_W, btnH)
	end
	local c = if ready then SKILL_GREEN else SKILL_GREY
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.Size = UDim2.fromScale(1, 1)
	lip.BackgroundColor3 = c.lip
	lip.BorderSizePixel = 0
	lip.ZIndex = 26
	lip.Parent = rebirthButton
	addCorner(lip, 18)
	PanelChrome.stroke(lip, BRIGHT.Outline, 3.5)
	local LIP = 8
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, -LIP)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.ZIndex = 27
	face.Parent = rebirthButton
	addCorner(face, 18)
	PanelChrome.gradient(face, c.top, c.bottom)
	local faceShine = Instance.new("Frame")
	faceShine.BackgroundColor3 = Color3.new(1, 1, 1)
	faceShine.BackgroundTransparency = 0.6
	faceShine.BorderSizePixel = 0
	faceShine.Position = UDim2.fromOffset(7, 5)
	faceShine.Size = UDim2.new(1, -14, 0.3, 0)
	faceShine.ZIndex = 27
	faceShine.Parent = face
	addCorner(faceShine, 12)
	local btnIcon = Instance.new("ImageLabel")
	btnIcon.BackgroundTransparency = 1
	btnIcon.AnchorPoint = Vector2.new(0, 0.5)
	btnIcon.Position = UDim2.new(0, 6, 0.5, 0)
	btnIcon.Size = UDim2.fromOffset(btnH - LIP - 14, btnH - LIP - 14)
	btnIcon.Image = REBIRTH_ICON
	btnIcon.ScaleType = Enum.ScaleType.Fit
	btnIcon.ImageTransparency = if ready then 0 else 0.35
	btnIcon.ZIndex = 28
	btnIcon.Parent = face
	local textLeft = btnH - LIP - 6
	PanelChrome.display(face, {
		name = "Label", text = if maxed then "MAXED" elseif ready then "REBIRTH!" else "REBIRTH", size = 30, stroke = 3, scaled = true, minSize = 16, zIndex = 29,
		pos = UDim2.fromOffset(textLeft, if ready then 4 else 2), size2 = UDim2.new(1, -(textLeft + 6), if ready then 1 else 0.6, if ready then -8 else 0),
	})
	if not ready then
		-- Which gate is still shut, in order: the cap, the level, then the gold.
		local needText
		if maxed then
			needText = ("%d of %d"):format(rebirths, maxCount)
		elseif not levelMet then
			needText = ("Reach Lv %d"):format(requirement)
		else
			needText = ("%s more gold"):format(goldShort(price - purse))
		end
		PanelChrome.display(face, {
			name = "Need", text = needText, size = 16, stroke = 2, scaled = true, minSize = 11, zIndex = 29,
			pos = UDim2.new(0, textLeft, 0.58, -2), size2 = UDim2.new(1, -(textLeft + 6), 0.36, 0),
		})
	end
	PanelChrome.pressFeedback(rebirthButton, { face = face, drop = 4 })
	rebirthButton.Activated:Connect(function() remotes:WaitForChild("Rebirth"):FireServer() end)

	-- ── Bonus tiles: now -> after the next rebirth ──────────────────────────────
	local now, next_ = RebirthConfig.GetMultipliers(rebirths), RebirthConfig.GetMultipliers(rebirths + 1)
	local legendaryStep = RebirthConfig.DROP_RATE_BONUS_PER_REBIRTH.Legendary * 100
	now.luck, next_.luck = math.round(legendaryStep * rebirths), math.round(legendaryStep * (rebirths + 1))

	-- Section titles are dark ink with no heavy outline, a step below the hero's white stroked
	-- type, so the blue hero is the one place the eye lands first.
	local function sectionTitle(parent, text, order)
		local row = Instance.new("Frame")
		row.Name = "Title_" .. text
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 22)
		row.LayoutOrder = order
		row.ZIndex = 24
		row.Parent = parent
		PanelChrome.display(row, {
			text = text, size = 21, color = BRIGHT.Ink, strokeColor = Color3.new(1, 1, 1), stroke = 2,
			xAlign = Enum.TextXAlignment.Left, zIndex = 25, pos = UDim2.fromOffset(4, 0),
		})
		local right = Instance.new("Frame")
		right.Name = "Right"
		right.BackgroundTransparency = 1
		right.AnchorPoint = Vector2.new(1, 0)
		right.Position = UDim2.new(1, -4, 0, 0)
		right.Size = UDim2.new(0.6, 0, 1, 0)
		right.ZIndex = 25
		right.Parent = row
		local rl = Instance.new("UIListLayout")
		rl.FillDirection = Enum.FillDirection.Horizontal
		rl.HorizontalAlignment = Enum.HorizontalAlignment.Right
		rl.VerticalAlignment = Enum.VerticalAlignment.Center
		rl.Padding = UDim.new(0, 5)
		rl.SortOrder = Enum.SortOrder.LayoutOrder
		rl.Parent = right
		return row, right
	end
	local function legendText(parent, text, color, order)
		local t = brightText(parent, { text = text, font = Enum.Font.GothamBlack, size = 15, color = color, size2 = UDim2.fromOffset(0, 22), zIndex = 26 })
		t.AutomaticSize = Enum.AutomaticSize.X
		t.LayoutOrder = order
		return t
	end

	local bonusSection = Instance.new("Frame")
	bonusSection.Name = "Bonuses"
	bonusSection.BackgroundTransparency = 1
	bonusSection.Size = UDim2.new(1, 0, 0, 0)
	bonusSection.AutomaticSize = Enum.AutomaticSize.Y
	bonusSection.LayoutOrder = 2
	bonusSection.ZIndex = 23
	bonusSection.Parent = page
	local bonusList = Instance.new("UIListLayout")
	bonusList.Padding = UDim.new(0, 4)
	bonusList.SortOrder = Enum.SortOrder.LayoutOrder
	bonusList.Parent = bonusSection
	-- The legend says which number is which: dimmed "now", then green "after Rebirth N+1".
	local _, legend = sectionTitle(bonusSection, "Next Rebirth Bonuses", 1)
	legendText(legend, "Now", BONUS_NOW, 1)
	chevron(legend, 14, BRIGHT.Green, 26, 2)
	legendText(legend, ("After Rebirth %d"):format(rebirths + 1), BRIGHT.GreenDark, 3)
	local bonusGrid = Instance.new("Frame")
	bonusGrid.Name = "Grid"
	bonusGrid.BackgroundTransparency = 1
	bonusGrid.Size = UDim2.new(1, 0, 0, 0)
	bonusGrid.AutomaticSize = Enum.AutomaticSize.Y
	bonusGrid.LayoutOrder = 2
	bonusGrid.ZIndex = 23
	bonusGrid.Parent = bonusSection
	-- Cell sizes are pixel offsets in design units: a Scale cell size is taken from the scaled
	-- AbsoluteSize and then scaled again by the panel's UIScale, so it overflows and wraps.
	local contentW = layout.W - (WELL_LEFT + WELL_RIGHT) - 14 - 6 -- body padding and scrollbar
	local bonusCols = if narrow then 2 else 3
	local bonusLayout = Instance.new("UIGridLayout")
	bonusLayout.CellSize = UDim2.fromOffset(math.floor((contentW - 8 * (bonusCols - 1)) / bonusCols), 52)
	bonusLayout.CellPadding = UDim2.fromOffset(8, 6)
	bonusLayout.FillDirection = Enum.FillDirection.Horizontal
	bonusLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bonusLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bonusLayout.Parent = bonusGrid
	for i, spec in ipairs(BONUS_TILES) do
		buildBonusRow(bonusGrid, spec, spec.fmt:format(now[spec.key]), spec.fmt:format(next_[spec.key]), i)
	end

	-- ── Milestone reward cards ──────────────────────────────────────────────────
	-- Each card is three clean bands: a clear icon area (top ~55%) with only a corner numeral,
	-- the perk name in its own strip, and a full-width status pill. The perk's description is a
	-- tooltip on the hovered / tapped card rather than a footer bar.
	local msSection = Instance.new("Frame")
	msSection.Name = "Milestones"
	msSection.BackgroundTransparency = 1
	msSection.Size = UDim2.new(1, 0, 0, 0)
	msSection.AutomaticSize = Enum.AutomaticSize.Y
	msSection.LayoutOrder = 3
	msSection.ZIndex = 24 -- above the bonus chips so a card's tooltip draws over them
	msSection.Parent = page
	local msList = Instance.new("UIListLayout")
	msList.Padding = UDim.new(0, 4)
	msList.SortOrder = Enum.SortOrder.LayoutOrder
	msList.Parent = msSection
	local _, msRight = sectionTitle(msSection, "Milestone Rewards", 1)
	local pill = Instance.new("Frame")
	pill.Name = "ClaimedPill"
	pill.Size = UDim2.fromOffset(0, 24)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.ZIndex = 26
	pill.Parent = msRight
	addCorner(pill, 12)
	PanelChrome.gradient(pill, Color3.fromRGB(170, 250, 110), Color3.fromRGB(56, 186, 50))
	PanelChrome.stroke(pill, BRIGHT.Outline, 2.5)
	addPadding(pill, 0, 10, 0, 10)
	local pillText = PanelChrome.display(pill, { text = ("%d / %d claimed"):format(claimedCount, #milestoneIds), size = 17, stroke = 2, size2 = UDim2.fromOffset(0, 24), zIndex = 27 })
	pillText.AutomaticSize = Enum.AutomaticSize.X

	local cardGrid = Instance.new("Frame")
	cardGrid.Name = "Cards"
	cardGrid.BackgroundTransparency = 1
	cardGrid.Size = UDim2.new(1, 0, 0, 0)
	cardGrid.AutomaticSize = Enum.AutomaticSize.Y
	cardGrid.LayoutOrder = 2
	cardGrid.ZIndex = 24
	cardGrid.Parent = msSection
	addPadding(cardGrid, 6, 6, 6, 6) -- room for the "next" card's glow inside the scroll clip
	local cardCols = if narrow then 3 else #milestoneIds
	local CARD_H = 166
	local cardW = math.floor((contentW - 12 - 10 * (cardCols - 1)) / cardCols)
	local cardLayout = Instance.new("UIGridLayout")
	cardLayout.CellSize = UDim2.fromOffset(cardW, CARD_H)
	cardLayout.CellPadding = UDim2.fromOffset(10, 12)
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Parent = cardGrid

	local cells, cardOutlines, tips = {}, {}, {}
	local pinned = nil
	local function showTip(id, on)
		for cid, tip in pairs(tips) do
			local visible = on and cid == id
			tip.Visible = visible
			cells[cid].ZIndex = if visible then 30 else 24
		end
	end
	local function setPinned(id)
		pinned = id
		for cid, outline in pairs(cardOutlines) do
			outline.Color = if cid == id then BRIGHT.Blue else BRIGHT.Outline
			outline.Thickness = if cid == id then 4.5 else 3.5
		end
		showTip(id, id ~= nil)
	end

	local STATUS_PILL = {
		claimed = { top = Color3.fromRGB(150, 246, 110), bottom = Color3.fromRGB(40, 170, 50), text = "CLAIMED" },
		next = { top = Color3.fromRGB(255, 246, 150), bottom = Color3.fromRGB(255, 160, 20), text = "NEXT!" },
		locked = { top = Color3.fromRGB(150, 156, 176), bottom = Color3.fromRGB(96, 102, 124), text = "LOCKED" },
	}

	for i, id in ipairs(milestoneIds) do
		local ms = RebirthConfig.Milestones[id]
		local stateName = if rebirths >= id then "claimed" elseif rebirths + 1 == id then "next" else "locked"
		local st = PERK_STATE[stateName]
		local z = 25

		local cell = Instance.new("Frame")
		cell.Name = "Perk_" .. id
		cell.BackgroundTransparency = 1
		cell.LayoutOrder = i
		cell.ZIndex = 24
		cell.Parent = cardGrid
		cells[id] = cell

		if stateName == "next" then
			-- Gold glow behind the next reward, pulsing gently.
			for j, spec in ipairs({ { 12, 0.55 }, { 6, 0.25 } }) do
				local halo = Instance.new("Frame")
				halo.Name = "Glow" .. j
				halo.AnchorPoint = Vector2.new(0.5, 0.5)
				halo.Position = UDim2.fromScale(0.5, 0.5)
				halo.Size = UDim2.new(1, spec[1], 1, spec[1])
				halo.BackgroundColor3 = Color3.fromRGB(255, 214, 40)
				halo.BackgroundTransparency = spec[2]
				halo.BorderSizePixel = 0
				halo.ZIndex = 24
				halo.Parent = cell
				addCorner(halo, 18 + spec[1] / 2)
				if j == 1 then
					TweenService:Create(halo, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.9 }):Play()
				end
			end
		end

		local card = Instance.new("TextButton")
		card.Name = "Card"
		card.Text = ""
		card.AutoButtonColor = false
		card.Size = UDim2.fromScale(1, 1)
		card.ZIndex = z
		card.Parent = cell
		addCorner(card, 18)
		cardOutlines[id] = cardFace(card, st, 18, z)

		-- Icon area: the 3D perk art, nudged right of the corner numeral so nothing sits on it.
		local ICON_H = 88
		local view = Instance.new("ViewportFrame")
		view.Name = "PerkIcon"
		view.BackgroundTransparency = 1
		view.AnchorPoint = Vector2.new(0.5, 0)
		view.Position = UDim2.new(0.5, 7, 0, 8)
		view.Size = UDim2.fromOffset(math.min(cardW - 22, ICON_H - 8), ICON_H - 8)
		view.ZIndex = z + 1
		view.Parent = card
		renderPerkIcon(view, id)
		if stateName == "locked" then
			view.ImageColor3 = Color3.fromRGB(150, 154, 168)
			view.ImageTransparency = 0.15
		end
		PanelChrome.display(card, {
			name = "Number", text = tostring(id), size = 30, stroke = 3, zIndex = z + 4,
			pos = UDim2.fromOffset(9, 3), size2 = UDim2.fromOffset(24, 32), xAlign = Enum.TextXAlignment.Left,
		})

		-- Name strip: its own band under the art; one line, shrinking only when it has to.
		local strip = Instance.new("Frame")
		strip.Name = "NameStrip"
		strip.Position = UDim2.fromOffset(5, ICON_H + 2)
		strip.Size = UDim2.new(1, -10, 0, 38)
		strip.BackgroundColor3 = st.rim
		strip.BackgroundTransparency = 0.45
		strip.BorderSizePixel = 0
		strip.ZIndex = z + 1
		strip.Parent = card
		addCorner(strip, 9)
		local nameLabel = PanelChrome.display(strip, {
			name = "PerkName", text = ms.title, size = 19, stroke = 2, scaled = true, minSize = 12, zIndex = z + 2,
			color = if stateName == "locked" then Color3.fromRGB(236, 238, 244) else Color3.new(1, 1, 1),
			pos = UDim2.fromOffset(3, 1), size2 = UDim2.new(1, -6, 1, -2),
		})
		nameLabel.TextWrapped = true
		nameLabel.LineHeight = 0.88

		-- Full-width status pill: green CLAIMED with a check, pulsing gold NEXT!, grey LOCKED
		-- with one small padlock.
		local sp = STATUS_PILL[stateName]
		local statusPill = Instance.new("Frame")
		statusPill.Name = "Status"
		statusPill.AnchorPoint = Vector2.new(0.5, 1)
		statusPill.Position = UDim2.new(0.5, 0, 1, -6)
		statusPill.Size = UDim2.new(1, -10, 0, 30)
		statusPill.BackgroundColor3 = Color3.new(1, 1, 1)
		statusPill.ZIndex = z + 2
		statusPill.Parent = card
		addCorner(statusPill, 15)
		PanelChrome.gradient(statusPill, sp.top, sp.bottom)
		PanelChrome.stroke(statusPill, BRIGHT.Outline, 2.5)
		local pillRow = Instance.new("Frame")
		pillRow.BackgroundTransparency = 1
		pillRow.Size = UDim2.fromScale(1, 1)
		pillRow.ZIndex = z + 3
		pillRow.Parent = statusPill
		local prl = Instance.new("UIListLayout")
		prl.FillDirection = Enum.FillDirection.Horizontal
		prl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		prl.VerticalAlignment = Enum.VerticalAlignment.Center
		prl.Padding = UDim.new(0, 3)
		prl.SortOrder = Enum.SortOrder.LayoutOrder
		prl.Parent = pillRow
		if stateName == "claimed" then
			local check = PanelChrome.checkBadge(pillRow, 20, z + 4)
			check.AnchorPoint = Vector2.new(0, 0)
			check.LayoutOrder = 1
		elseif stateName == "locked" then
			local lockHolder = Instance.new("Frame")
			lockHolder.BackgroundTransparency = 1
			lockHolder.Size = UDim2.fromOffset(18, 20)
			lockHolder.LayoutOrder = 1
			lockHolder.ZIndex = z + 3
			lockHolder.Parent = pillRow
			local lock = padlockIcon(lockHolder, 18, z + 4)
			lock.Position = UDim2.fromScale(0.5, 0.5)
		end
		local stateText = PanelChrome.display(pillRow, {
			name = "StateText", text = sp.text, size = if stateName == "next" then 19 else 16, stroke = 2.5, zIndex = z + 4,
			size2 = UDim2.fromOffset(0, 26),
		})
		stateText.AutomaticSize = Enum.AutomaticSize.X
		stateText.LayoutOrder = 2
		if stateName == "next" then
			local pulse = Instance.new("UIScale")
			pulse.Parent = statusPill
			TweenService:Create(pulse, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.08 }):Play()
		end

		-- Tooltip: the perk's description, floating above the card over the bonus chips. Edge
		-- cards anchor to their outer side so the bubble stays inside the panel.
		local tipW = math.min(250, contentW - 20)
		local ax = if i % cardCols == 1 then 0 elseif i % cardCols == 0 then 1 else 0.5
		local tip = Instance.new("Frame")
		tip.Name = "Tooltip"
		tip.Visible = false
		tip.AnchorPoint = Vector2.new(ax, 1)
		tip.Position = UDim2.new(ax, 0, 0, -8)
		tip.Size = UDim2.fromOffset(tipW, 0)
		tip.AutomaticSize = Enum.AutomaticSize.Y
		tip.BackgroundColor3 = Color3.new(1, 1, 1)
		tip.ZIndex = 40
		tip.Parent = cell
		addCorner(tip, 14)
		PanelChrome.gradient(tip, Color3.fromRGB(255, 255, 255), BRIGHT.Row)
		PanelChrome.stroke(tip, BRIGHT.Outline, 3)
		addPadding(tip, 6, 10, 8, 10)
		local tl = Instance.new("UIListLayout")
		tl.Padding = UDim.new(0, 2)
		tl.SortOrder = Enum.SortOrder.LayoutOrder
		tl.Parent = tip
		PanelChrome.display(tip, {
			name = "Title", text = ("Rebirth %d: %s"):format(id, ms.title), size = 18, stroke = 2.5, scaled = true, minSize = 12,
			color = if stateName == "claimed" then Color3.fromRGB(110, 226, 90) elseif stateName == "next" then BRIGHT.Gold else Color3.new(1, 1, 1),
			xAlign = Enum.TextXAlignment.Left, size2 = UDim2.new(1, 0, 0, 22), zIndex = 41,
		}).LayoutOrder = 1
		local desc = brightText(tip, {
			text = ms.desc, font = Enum.Font.GothamBlack, size = 15, color = BRIGHT.Ink, wrap = true, zIndex = 41,
			size2 = UDim2.new(1, 0, 0, 0),
		})
		desc.AutomaticSize = Enum.AutomaticSize.Y
		desc.LayoutOrder = 2
		tips[id] = tip

		local scale = Instance.new("UIScale")
		scale.Parent = card
		card.MouseEnter:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
			if pinned == nil then showTip(id, true) end
		end)
		card.MouseLeave:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
			if pinned == nil then showTip(id, false) end
		end)
		card.Activated:Connect(function() setPinned(if pinned == id then nil else id) end)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  TRADE TAB: pick a player from the lobby, then build an offer side by side. PS99-style light
--  list: chunky outlined header controls, one bright card per player (avatar with a level
--  badge, a big outlined display name, @username, wealth) and a fat green "Trade!" button. An
--  empty server gets an illustrated empty state instead of a bare sentence.
-- ═══════════════════════════════════════════════════════════════════════════
local SocialService = game:GetService("SocialService")
local tradeRemote = remotes:WaitForChild("TradeAction")
local tradeState = { players = {}, incoming = nil, session = nil }
local TRADE_RARITY = {
	Common = Color3.fromRGB(226, 230, 238), Uncommon = Color3.fromRGB(110, 226, 90), Rare = Color3.fromRGB(92, 184, 255),
	Epic = Color3.fromRGB(200, 120, 255), Legendary = Color3.fromRGB(255, 206, 50),
}
local TRADE_NAME = Color3.fromRGB(92, 204, 255)
local TRADE_GREEN = { top = Color3.fromRGB(150, 246, 88), bottom = Color3.fromRGB(56, 192, 40) }
local TRADE_BLUE = { top = Color3.fromRGB(120, 214, 255), bottom = Color3.fromRGB(34, 128, 236) }
local TRADE_RED = { top = Color3.fromRGB(255, 132, 120), bottom = Color3.fromRGB(226, 46, 60) }
local TRADE_GREY = { top = Color3.fromRGB(226, 230, 240), bottom = Color3.fromRGB(160, 168, 188) }
local TRADE_GOLD = { top = Color3.fromRGB(255, 244, 150), bottom = Color3.fromRGB(255, 188, 46) }
local tradeSearch = "" -- the lobby's search text, kept across list refreshes
-- Studio-only sample rows, set by the "Trade" GuiShowcase opener so a solo play test can show a
-- filled list. They are drawn only while the real list is empty, and their buttons never fire
-- the trade remote.
local tradeSamples = nil

-- A fat right-pointing arrow in a square holder (shaft, filled head, chevron rim) for
-- shapeIcon; TRADE_ARROW_LEFT is its mirror image.
local TRADE_ARROW_RIGHT = {
	{ 0.33, 0.5, 0.54, 0.28, 0, false },
	{ 0.60, 0.5, 0.40, 0.40, 45, false },
	{ 0.64, 0.34, 0.50, 0.20, 45, false },
	{ 0.64, 0.66, 0.50, 0.20, -45, false },
}
local TRADE_ARROW_LEFT = {}
for _, p in ipairs(TRADE_ARROW_RIGHT) do
	table.insert(TRADE_ARROW_LEFT, { 1 - p[1], p[2], p[3], p[4], -p[5], p[6] })
end

-- The trade emblem: a green arrow heading right over an orange one heading left, each with a
-- heavy outline and a lit upper face, like PS99's rendered trade icon.
local function tradeArrowsIcon(parent, size, props)
	local z = props.zIndex
	local holder = Instance.new("Frame")
	holder.Name = props.name or "TradeArrows"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = props.anchor or Vector2.new(0.5, 0.5)
	holder.Position = props.pos or UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(size, size)
	holder.Rotation = props.rotation or 0
	holder.ZIndex = z
	holder.Parent = parent
	local pad = math.max(5, math.floor(size / 11))
	local function arrow(name, pieces, base, light, pos, zz)
		local h, fill = shapeIcon(holder, pieces, base, {
			name = name, size = UDim2.fromScale(0.68, 0.68), pos = pos, zIndex = zz, pad = pad,
		})
		-- One glossy streak along the top of the shaft (a per-piece gradient would seam).
		local shine = Instance.new("Frame")
		shine.Name = "Shine"
		shine.AnchorPoint = Vector2.new(0.5, 0.5)
		shine.Position = UDim2.fromScale(pieces[1][1], 0.42)
		shine.Size = UDim2.fromScale(pieces[1][3] - 0.08, 0.07)
		shine.BackgroundColor3 = light
		shine.BorderSizePixel = 0
		shine.ZIndex = zz + 2
		shine.Parent = h
		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(0.5, 0)
		sc.Parent = shine
		local _ = fill
		return h
	end
	arrow("Left", TRADE_ARROW_LEFT, Color3.fromRGB(255, 150, 30), Color3.fromRGB(255, 214, 90), UDim2.fromScale(0.4, 0.69), z)
	arrow("Right", TRADE_ARROW_RIGHT, Color3.fromRGB(70, 206, 52), Color3.fromRGB(176, 250, 110), UDim2.fromScale(0.6, 0.31), z + 2)
	return holder
end

-- The panel's title emblem while the Trade tab is open (openTab swaps it with the image icon).
local tradeTitleIcon = tradeArrowsIcon(contentPanel, 84, {
	name = "TradeTitleIcon", anchor = Vector2.new(0, 0.5), pos = UDim2.fromOffset(-20, -2), rotation = -8, zIndex = 8,
})
tradeTitleIcon.Visible = false

-- A chunky PanelChrome button sitting on a soft drop shadow. Returns the button and its label.
local function tradeChunky(parent, props)
	local z = props.zIndex or 25
	local r = props.radius or 16
	local holder = Instance.new("Frame")
	holder.Name = (props.name or "Button") .. "Holder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = props.anchor or Vector2.zero
	holder.Position = props.pos or UDim2.new()
	holder.Size = props.size
	holder.LayoutOrder = props.order or 0
	holder.ZIndex = z
	holder.Parent = parent
	local shadow = Instance.new("Frame")
	shadow.Name = "DropShadow"
	shadow.BackgroundColor3 = BRIGHT.Outline
	shadow.BackgroundTransparency = 0.6
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(0, 6)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.ZIndex = z
	shadow.Parent = holder
	addCorner(shadow, r)
	local btn, label = PanelChrome.chunkyButton(holder, {
		name = props.name, text = props.text, color = props.colors.top, colorDark = props.colors.bottom,
		size = UDim2.fromScale(1, 1), textSize = props.textSize or 28, zIndex = z + 1, radius = r, strokeThickness = 3.5,
	})
	if props.onClick then btn.Activated:Connect(props.onClick) end
	return btn, label, holder
end

-- A bright list card: white-to-row gradient face under a heavy outline.
local function tradeBrightCard(parent, order, height, colors)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, height)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.ZIndex = 23
	card.Parent = parent
	addCorner(card, 20)
	PanelChrome.gradient(card, colors and colors.top or Color3.fromRGB(255, 255, 255), colors and colors.bottom or BRIGHT.Row)
	PanelChrome.stroke(card, BRIGHT.Outline, 3.5)
	return card
end

-- Round avatar bubble with a dark level badge on its lower left. Real players show their
-- headshot; the Studio samples get a cartoon head drawn from Frames.
local function tradeAvatar(parent, info, size, z)
	local bubble = Instance.new("Frame")
	bubble.Name = "Avatar"
	bubble.AnchorPoint = Vector2.new(0, 0.5)
	bubble.Position = UDim2.new(0, 0, 0.5, 0)
	bubble.Size = UDim2.fromOffset(size, size)
	bubble.BackgroundColor3 = Color3.new(1, 1, 1)
	bubble.ZIndex = z
	bubble.Parent = parent
	addCorner(bubble, size)
	PanelChrome.gradient(bubble, Color3.fromRGB(232, 238, 250), Color3.fromRGB(176, 188, 214))
	PanelChrome.stroke(bubble, BRIGHT.Outline, 3)
	if info.sample then
		local look = info.look
		local shoulders = Instance.new("Frame")
		shoulders.AnchorPoint = Vector2.new(0.5, 1)
		shoulders.Position = UDim2.fromScale(0.5, 0.95)
		shoulders.Size = UDim2.fromScale(0.62, 0.32)
		shoulders.BackgroundColor3 = look.shirt
		shoulders.ZIndex = z + 1
		shoulders.Parent = bubble
		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(0.45, 0)
		sc.Parent = shoulders
		PanelChrome.stroke(shoulders, BRIGHT.Outline, 2)
		local head = Instance.new("Frame")
		head.AnchorPoint = Vector2.new(0.5, 0.5)
		head.Position = UDim2.fromScale(0.5, 0.44)
		head.Size = UDim2.fromScale(0.5, 0.48)
		head.BackgroundColor3 = look.skin
		head.ZIndex = z + 2
		head.Parent = bubble
		local hc = Instance.new("UICorner")
		hc.CornerRadius = UDim.new(0.32, 0)
		hc.Parent = head
		PanelChrome.stroke(head, BRIGHT.Outline, 2)
		local hair = Instance.new("Frame")
		hair.Position = UDim2.fromScale(-0.04, -0.06)
		hair.Size = UDim2.fromScale(1.08, 0.36)
		hair.BackgroundColor3 = look.hair
		hair.ZIndex = z + 3
		hair.Parent = head
		local hrc = Instance.new("UICorner")
		hrc.CornerRadius = UDim.new(0.5, 0)
		hrc.Parent = hair
		for _, x in ipairs({ 0.33, 0.67 }) do
			local eye = Instance.new("Frame")
			eye.AnchorPoint = Vector2.new(0.5, 0.5)
			eye.Position = UDim2.fromScale(x, 0.52)
			eye.Size = UDim2.fromScale(0.13, 0.18)
			eye.BackgroundColor3 = BRIGHT.Outline
			eye.ZIndex = z + 3
			eye.Parent = head
			addCorner(eye, 10)
		end
		local smile = Instance.new("Frame")
		smile.AnchorPoint = Vector2.new(0.5, 0.5)
		smile.Position = UDim2.fromScale(0.5, 0.76)
		smile.Size = UDim2.fromScale(0.36, 0.08)
		smile.BackgroundColor3 = BRIGHT.Outline
		smile.ZIndex = z + 3
		smile.Parent = head
		addCorner(smile, 6)
	elseif typeof(info.userId) == "number" and info.userId > 0 then
		local shot = Instance.new("ImageLabel")
		shot.Name = "Headshot"
		shot.BackgroundTransparency = 1
		shot.AnchorPoint = Vector2.new(0.5, 0.5)
		shot.Position = UDim2.fromScale(0.5, 0.5)
		shot.Size = UDim2.fromScale(0.96, 0.96)
		shot.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(info.userId)
		shot.ZIndex = z + 1
		shot.Parent = bubble
		addCorner(shot, size)
	end
	if info.level then
		local d = math.floor(size * 0.44)
		local badge = Instance.new("Frame")
		badge.Name = "LevelBadge"
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.fromScale(0.1, 0.86)
		badge.Size = UDim2.fromOffset(d, d)
		badge.BackgroundColor3 = BRIGHT.Outline
		badge.ZIndex = z + 5
		badge.Parent = bubble
		addCorner(badge, d)
		PanelChrome.stroke(badge, Color3.new(1, 1, 1), 2)
		PanelChrome.display(badge, {
			name = "Level", text = tostring(info.level), size = math.floor(d * 0.62), stroke = 1.5, scaled = true, minSize = 9,
			size2 = UDim2.new(1, -4, 1, -4), pos = UDim2.fromOffset(2, 2), zIndex = z + 6,
		})
	end
	return bubble
end

-- A coin and a stroked gold number, laid out left to right (used inside list layouts).
local function tradeWealthChip(parent, wealth, textSize, z, order)
	local chip = Instance.new("Frame")
	chip.Name = "Wealth"
	chip.BackgroundTransparency = 1
	chip.Size = UDim2.new(0, 0, 1, 0)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.LayoutOrder = order or 0
	chip.ZIndex = z
	chip.Parent = parent
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Padding = UDim.new(0, 4)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = chip
	local coin = Instance.new("ImageLabel")
	coin.BackgroundTransparency = 1
	coin.Size = UDim2.fromOffset(textSize + 6, textSize + 6)
	coin.Image = ICONS.Coin
	coin.ScaleType = Enum.ScaleType.Fit
	coin.LayoutOrder = 1
	coin.ZIndex = z
	coin.Parent = chip
	local value = PanelChrome.display(chip, {
		name = "Value", text = SwordValue.short(wealth or 0), size = textSize, stroke = 2.5, color = BRIGHT.Gold,
		xAlign = Enum.TextXAlignment.Left, size2 = UDim2.new(0, 0, 1, 0), zIndex = z,
	})
	value.AutomaticSize = Enum.AutomaticSize.X
	value.LayoutOrder = 2
	return chip
end

-- One player in the lobby: avatar, outlined name, @username and wealth, and a "Trade!" button
-- (a grey "Trading..." tag while that player is busy).
local function tradePlayerRow(info, order, narrow)
	local rowH = if narrow then 118 else 98
	local z = 24
	local row = tradeBrightCard(body, order, rowH)
	row.Name = "Player_" .. tostring(info.name)
	addPadding(row, 10, 14, 10, 10)
	local avatarSize = if narrow then 84 else 76
	tradeAvatar(row, info, avatarSize, z)
	local btnW, btnH = if narrow then 124 else 158, if narrow then 66 else 62
	local textX = avatarSize + 16
	local textW = UDim2.new(1, -(textX + btnW + 10), 0, 0)
	local lineY = if narrow then 2 else 4
	PanelChrome.display(row, {
		name = "Name", text = info.name or "?", size = if narrow then 28 else 32, stroke = 3, scaled = true, minSize = 14,
		color = TRADE_NAME, xAlign = Enum.TextXAlignment.Left,
		pos = UDim2.fromOffset(textX, lineY), size2 = textW + UDim2.fromOffset(0, 38), zIndex = z + 1,
	})
	local line2 = Instance.new("Frame")
	line2.Name = "Details"
	line2.BackgroundTransparency = 1
	line2.Position = UDim2.fromOffset(textX, lineY + 40)
	line2.Size = textW + UDim2.fromOffset(0, 28)
	line2.ClipsDescendants = true
	line2.ZIndex = z
	line2.Parent = row
	local ll = Instance.new("UIListLayout")
	ll.FillDirection = if narrow then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	ll.VerticalAlignment = Enum.VerticalAlignment.Center
	ll.Padding = UDim.new(0, if narrow then 2 else 14)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = line2
	if narrow then line2.Size = textW + UDim2.fromOffset(0, 56) end
	local user = brightText(line2, {
		text = "@" .. tostring(info.username or info.name or ""), font = PanelChrome.DISPLAY_FONT, size = 20,
		color = BRIGHT.Ink, size2 = UDim2.new(0, 0, 0, 26), zIndex = z + 1,
	})
	user.AutomaticSize = Enum.AutomaticSize.X
	user.LayoutOrder = 1
	local chip = tradeWealthChip(line2, info.wealth, 22, z + 1, 2)
	chip.Size = UDim2.new(0, 0, 0, 26)

	if info.busy then
		local tag = Instance.new("Frame")
		tag.Name = "BusyTag"
		tag.AnchorPoint = Vector2.new(1, 0.5)
		tag.Position = UDim2.new(1, 0, 0.5, 0)
		tag.Size = UDim2.fromOffset(btnW, btnH - 6)
		tag.BackgroundColor3 = Color3.new(1, 1, 1)
		tag.ZIndex = z + 1
		tag.Parent = row
		addCorner(tag, 16)
		PanelChrome.gradient(tag, TRADE_GREY.top, TRADE_GREY.bottom)
		PanelChrome.stroke(tag, BRIGHT.Outline, 3)
		PanelChrome.display(tag, {
			name = "Label", text = "Trading...", size = 28, stroke = 2.5, scaled = true, minSize = 12,
			size2 = UDim2.new(1, -12, 1, -8), pos = UDim2.fromOffset(6, 4), zIndex = z + 2,
		})
	else
		local userId = info.userId
		local sample = info.sample
		tradeChunky(row, {
			name = "TradeButton", text = "Trade!", colors = TRADE_GREEN, textSize = if narrow then 28 else 32,
			size = UDim2.fromOffset(btnW, btnH), anchor = Vector2.new(1, 0.5), pos = UDim2.new(1, 0, 0.5, -3), zIndex = z + 1,
			onClick = function()
				if sample then return end -- showcase sample: never reaches the server
				tradeRemote:FireServer("Request", userId)
			end,
		})
	end
	return row
end

-- Lobby header: "Players" with a count bubble, a chunky search box and a blue Refresh button.
-- Phones put the search box on its own line.
local function tradeLobbyHeader(order, narrow, count, onSearch)
	local z = 24
	local h = if narrow then 140 else 72
	local head = Instance.new("Frame")
	head.Name = "LobbyHeader"
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, h)
	head.LayoutOrder = order
	head.ZIndex = z
	head.Parent = body

	local titleRow = Instance.new("Frame")
	titleRow.Name = "TitleRow"
	titleRow.BackgroundTransparency = 1
	titleRow.Position = UDim2.fromOffset(4, 0)
	titleRow.Size = UDim2.new(0, 0, 0, 64)
	titleRow.AutomaticSize = Enum.AutomaticSize.X
	titleRow.ZIndex = z
	titleRow.Parent = head
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.VerticalAlignment = Enum.VerticalAlignment.Center
	tl.Padding = UDim.new(0, 10)
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Parent = titleRow
	local title = PanelChrome.display(titleRow, {
		name = "Title", text = "Players", size = if narrow then 32 else 36, stroke = 3.5,
		xAlign = Enum.TextXAlignment.Left, size2 = UDim2.new(0, 0, 1, 0), zIndex = z + 1,
	})
	title.AutomaticSize = Enum.AutomaticSize.X
	title.LayoutOrder = 1
	local countBubble = Instance.new("Frame")
	countBubble.Name = "Count"
	countBubble.Size = UDim2.fromOffset(46, 42)
	countBubble.AutomaticSize = Enum.AutomaticSize.X
	countBubble.BackgroundColor3 = Color3.new(1, 1, 1)
	countBubble.LayoutOrder = 2
	countBubble.ZIndex = z + 1
	countBubble.Parent = titleRow
	addCorner(countBubble, 14)
	PanelChrome.gradient(countBubble, TRADE_BLUE.top, TRADE_BLUE.bottom)
	PanelChrome.stroke(countBubble, BRIGHT.Outline, 3)
	addPadding(countBubble, 0, 10, 0, 10)
	local countLabel = PanelChrome.display(countBubble, {
		name = "Value", text = tostring(count), size = 26, stroke = 2.5, size2 = UDim2.new(0, 26, 1, 0), zIndex = z + 2,
	})
	countLabel.AutomaticSize = Enum.AutomaticSize.X

	local refreshW, ctrlH = if narrow then 138 else 150, if narrow then 62 else 58
	tradeChunky(head, {
		name = "RefreshButton", text = "Refresh", colors = TRADE_BLUE, textSize = 26,
		size = UDim2.fromOffset(refreshW, ctrlH), anchor = Vector2.new(1, 0), pos = UDim2.new(1, -2, 0, 2), zIndex = z + 1,
		onClick = function() tradeRemote:FireServer("Refresh") end,
	})

	-- Search box: white field, heavy outline, a magnifier drawn from Frames.
	local search = Instance.new("Frame")
	search.Name = "Search"
	search.BackgroundColor3 = Color3.new(1, 1, 1)
	search.ZIndex = z + 1
	if narrow then
		search.Position = UDim2.fromOffset(2, 76)
		search.Size = UDim2.new(1, -4, 0, 60)
	else
		search.AnchorPoint = Vector2.new(1, 0)
		search.Position = UDim2.new(1, -(refreshW + 16), 0, 2)
		search.Size = UDim2.fromOffset(206, ctrlH)
	end
	search.Parent = head
	addCorner(search, 18)
	PanelChrome.gradient(search, Color3.fromRGB(226, 234, 248), Color3.fromRGB(255, 255, 255))
	PanelChrome.stroke(search, BRIGHT.Outline, 3.5)
	local glass = Instance.new("Frame")
	glass.Name = "Magnifier"
	glass.BackgroundTransparency = 1
	glass.AnchorPoint = Vector2.new(0, 0.5)
	glass.Position = UDim2.new(0, 12, 0.5, 0)
	glass.Size = UDim2.fromOffset(34, 34)
	glass.ZIndex = z + 2
	glass.Parent = search
	local lens = Instance.new("Frame")
	lens.BackgroundColor3 = Color3.fromRGB(200, 232, 255)
	lens.Position = UDim2.fromOffset(2, 2)
	lens.Size = UDim2.fromOffset(21, 21)
	lens.ZIndex = z + 3
	lens.Parent = glass
	addCorner(lens, 21)
	PanelChrome.stroke(lens, BRIGHT.Ink, 4)
	local handle = Instance.new("Frame")
	handle.AnchorPoint = Vector2.new(0.5, 0.5)
	handle.Position = UDim2.fromOffset(26, 26)
	handle.Size = UDim2.fromOffset(14, 7)
	handle.Rotation = 45
	handle.BackgroundColor3 = BRIGHT.Ink
	handle.ZIndex = z + 2
	handle.Parent = glass
	addCorner(handle, 4)
	local box = Instance.new("TextBox")
	box.Name = "SearchBox"
	box.BackgroundTransparency = 1
	box.Position = UDim2.fromOffset(54, 0)
	box.Size = UDim2.new(1, -62, 1, 0)
	box.Font = PanelChrome.DISPLAY_FONT
	box.TextSize = 24
	box.TextColor3 = BRIGHT.Ink
	box.PlaceholderText = "Search"
	box.PlaceholderColor3 = BRIGHT.InkMuted
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ClearTextOnFocus = false
	box.ClipsDescendants = true
	box.Text = tradeSearch
	box.ZIndex = z + 2
	box.Parent = search
	box:GetPropertyChangedSignal("Text"):Connect(function()
		tradeSearch = box.Text
		onSearch()
	end)
	return head
end

-- Empty server: a big trade emblem on a soft halo, a bold headline and an Invite Friends button.
local function tradeEmptyState(order, narrow)
	local z = 24
	local h = if narrow then 424 else 372
	local card = tradeBrightCard(body, order, h)
	card.Name = "EmptyState"
	PanelChrome.stripes(card, { color = Color3.fromRGB(200, 220, 250), alpha = 0.6, bands = 9, rotation = 25, radius = 20, zIndex = 23 })
	local cy = if narrow then 104 else 98
	for i, spec in ipairs({ { 178, Color3.fromRGB(206, 232, 255), 0 }, { 140, Color3.fromRGB(236, 246, 255), 0 } }) do
		local disc = Instance.new("Frame")
		disc.Name = "Halo" .. i
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.new(0.5, 0, 0, cy)
		disc.Size = UDim2.fromOffset(spec[1], spec[1])
		disc.BackgroundColor3 = spec[2]
		disc.BackgroundTransparency = spec[3]
		disc.ZIndex = z
		disc.Parent = card
		addCorner(disc, spec[1])
		if i == 1 then PanelChrome.stroke(disc, Color3.fromRGB(150, 196, 246), 4) end
	end
	tradeArrowsIcon(card, 132, { name = "Emblem", pos = UDim2.new(0.5, 0, 0, cy), rotation = -8, zIndex = z + 1 })
	-- Little gold sparkles around the emblem.
	for _, s in ipairs({ { -92, -58, 26 }, { 96, -40, 20 }, { 82, 62, 16 }, { -84, 56, 14 } }) do
		shapeIcon(card, GEM_PIECES, BRIGHT.Gold, {
			name = "Sparkle", size = UDim2.fromOffset(s[3], s[3]), pos = UDim2.new(0.5, s[1], 0, cy + s[2]),
			zIndex = z + 4, pad = 4,
		})
	end
	local ty = cy + 98
	PanelChrome.display(card, {
		name = "Headline", text = "No one to trade with yet", size = if narrow then 30 else 38, stroke = 3.5,
		scaled = true, minSize = 18, pos = UDim2.new(0, 16, 0, ty), size2 = UDim2.new(1, -32, 0, 46), zIndex = z + 2,
	})
	local sub = brightText(card, {
		text = "Trades need another player in this server. Bring a friend!", font = PanelChrome.DISPLAY_FONT,
		size = 20, color = BRIGHT.Ink, wrap = true, xAlign = Enum.TextXAlignment.Center,
		pos = UDim2.new(0, 20, 0, ty + 48), size2 = UDim2.new(1, -40, 0, if narrow then 52 else 28), zIndex = z + 2,
	})
	sub.Name = "Sub"
	tradeChunky(card, {
		name = "InviteButton", text = "Invite Friends", colors = TRADE_GREEN, textSize = 32,
		size = UDim2.fromOffset(if narrow then 270 else 300, 70), anchor = Vector2.new(0.5, 1),
		pos = UDim2.new(0.5, 0, 1, -24), zIndex = z + 2,
		onClick = function()
			task.spawn(function()
				local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
				if ok and can then pcall(SocialService.PromptGameInvite, SocialService, player) end
			end)
		end,
	})
	return card
end

-- Someone asked to trade: a gold card with their avatar, and Accept / Decline.
local function tradeIncomingCard(order, narrow)
	local z = 24
	local incoming = tradeState.incoming
	local card = tradeBrightCard(body, order, if narrow then 178 else 104, TRADE_GOLD)
	card.Name = "IncomingRequest"
	addPadding(card, 10, 14, 10, 10)
	local avatar = tradeAvatar(card, { userId = incoming.userId }, if narrow then 72 else 80, z)
	if narrow then
		avatar.AnchorPoint = Vector2.zero
		avatar.Position = UDim2.fromOffset(0, 0)
	end
	local textX = (if narrow then 72 else 80) + 14
	local textW = if narrow then UDim2.new(1, -textX, 0, 0) else UDim2.new(1, -(textX + 290), 0, 0)
	PanelChrome.display(card, {
		name = "Title", text = tostring(incoming.name) .. " wants to trade!", size = if narrow then 26 else 30, stroke = 3,
		scaled = true, minSize = 14, xAlign = Enum.TextXAlignment.Left,
		pos = UDim2.fromOffset(textX, if narrow then 0 else 8), size2 = textW + UDim2.fromOffset(0, 40), zIndex = z + 1,
	})
	brightText(card, {
		text = "Accept to open the trade window.", font = PanelChrome.DISPLAY_FONT, size = 19, color = BRIGHT.Ink,
		pos = UDim2.fromOffset(textX, if narrow then 40 else 48), size2 = textW + UDim2.fromOffset(0, 26), zIndex = z + 1,
	})
	local fromId = incoming.userId
	local bw, bh = if narrow then 0 else 136, if narrow then 62 else 60
	local accept, decline = {
		name = "AcceptButton", text = "Accept", colors = TRADE_GREEN, textSize = 28, zIndex = z + 1,
		onClick = function() tradeRemote:FireServer("Accept", fromId) end,
	}, {
		name = "DeclineButton", text = "Decline", colors = TRADE_RED, textSize = 28, zIndex = z + 1,
		onClick = function() tradeRemote:FireServer("Decline", fromId) end,
	}
	if narrow then
		accept.size, accept.anchor, accept.pos = UDim2.new(0.5, -6, 0, bh), Vector2.new(0, 1), UDim2.new(0, 0, 1, -6)
		decline.size, decline.anchor, decline.pos = UDim2.new(0.5, -6, 0, bh), Vector2.new(1, 1), UDim2.new(1, 0, 1, -6)
	else
		accept.size, accept.anchor, accept.pos = UDim2.fromOffset(bw, bh), Vector2.new(1, 0.5), UDim2.new(1, -(bw + 12), 0.5, -3)
		decline.size, decline.anchor, decline.pos = UDim2.fromOffset(bw, bh), Vector2.new(1, 0.5), UDim2.new(1, 0, 0.5, -3)
	end
	tradeChunky(card, accept)
	tradeChunky(card, decline)
	return card
end

local function buildTradeLobby(order)
	local narrow = layoutMode == "narrow"
	if tradeState.incoming then
		tradeIncomingCard(order, narrow); order += 1
	end
	local list = tradeState.players
	if #list == 0 and tradeSamples then list = tradeSamples end
	-- Usernames come from the local Players list; the server payload carries display names.
	for _, info in ipairs(list) do
		if not info.username and typeof(info.userId) == "number" then
			local p = Players:GetPlayerByUserId(info.userId)
			if p then info.username = p.Name end
		end
	end
	local rows = {}
	local noMatch
	local function applySearch()
		local q = string.lower(tradeSearch or "")
		local shown = 0
		for _, r in ipairs(rows) do
			r.frame.Visible = q == "" or string.find(r.key, q, 1, true) ~= nil
			if r.frame.Visible then shown += 1 end
		end
		if noMatch then noMatch.Visible = #rows > 0 and shown == 0 end
	end
	tradeLobbyHeader(order, narrow, #list, applySearch); order += 1
	if #list == 0 then
		tradeEmptyState(order, narrow); order += 1
		return order
	end
	for _, info in ipairs(list) do
		local row = tradePlayerRow(info, order, narrow); order += 1
		table.insert(rows, { frame = row, key = string.lower(tostring(info.name) .. " " .. tostring(info.username or "")) })
	end
	noMatch = tradeBrightCard(body, order, 84); order += 1
	noMatch.Name = "NoMatch"
	PanelChrome.display(noMatch, {
		name = "Text", text = "No players match your search", size = 26, stroke = 3, scaled = true, minSize = 14,
		pos = UDim2.fromOffset(12, 0), size2 = UDim2.new(1, -24, 1, 0), zIndex = 24,
	})
	applySearch()
	return order
end

-- ── Trade session (both offers side by side), in the same bright card style ──
local function tradeCard(order, height)
	local card = tradeBrightCard(body, order, height)
	addPadding(card, 10, 14, 10, 14)
	return card
end

local function tradeButton(parent, text, colors, pos, size, onClick)
	local btn = tradeChunky(parent, {
		name = text .. "Button", text = text, colors = colors, textSize = 24, size = size, pos = pos,
		anchor = Vector2.new(1, 0.5), zIndex = 25, onClick = onClick,
	})
	return btn
end

local function swordLine(card, info, y, lineH, withButton, buttonText, buttonColors, onClick)
	local narrow = layoutMode == "narrow"
	local reserve = if withButton then 130 else 0
	PanelChrome.display(card, {
		text = info.name, size = 22, stroke = 2.5, scaled = true, minSize = 12, color = TRADE_RARITY[info.rarity] or Color3.new(1, 1, 1),
		xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(0, y), size2 = UDim2.new(1, -reserve, 0, 28), zIndex = 24,
	})
	brightText(card, { text = string.format("%s · %s · rating %s", info.rarity, info.prefixes ~= "" and info.prefixes or "no modifiers",
		SwordValue.short(info.rating or 0)), font = Enum.Font.GothamBold, size = 14, color = BRIGHT.Ink, wrap = narrow,
		pos = UDim2.fromOffset(0, y + 28), size2 = UDim2.new(1, -reserve, 0, lineH - 32), zIndex = 24,
		yAlign = Enum.TextYAlignment.Top })
	if withButton then
		tradeButton(card, buttonText, buttonColors, UDim2.new(1, 0, 0, y + math.floor(lineH / 2) - 4),
			UDim2.fromOffset(118, lineH - 12), onClick)
	end
end

local function buildTradeSession(order)
	local narrow = layoutMode == "narrow"
	local st = tradeState.session
	local status = tradeCard(order, 92); order += 1
	PanelChrome.display(status, { text = "Trading with " .. st.partnerName, size = 28, stroke = 3, scaled = true, minSize = 14,
		color = BRIGHT.Gold, xAlign = Enum.TextXAlignment.Left, size2 = UDim2.new(1, -140, 0, 38), zIndex = 24 })
	local mine = st.myConfirmed and "You: confirmed" or "You: not confirmed"
	local theirs = st.theirConfirmed and (st.partnerName .. ": confirmed") or (st.partnerName .. ": waiting")
	brightText(status, { text = mine .. "  ·  " .. theirs, font = PanelChrome.DISPLAY_FONT, size = 18, color = BRIGHT.Ink,
		wrap = true, pos = UDim2.fromOffset(0, 40), size2 = UDim2.new(1, -140, 0, 30), zIndex = 24 })
	tradeButton(status, "Cancel", TRADE_RED, UDim2.new(1, 0, 0.5, -3), UDim2.fromOffset(124, 62), function()
		tradeRemote:FireServer("Cancel")
	end)

	local lineH = if narrow then 76 else 64
	local function section(title, rows, emptyText, withButton, buttonText, buttonColors, action)
		local card = tradeCard(order, 66 + math.max(#rows, 1) * lineH); order += 1
		PanelChrome.display(card, { text = title, size = 24, stroke = 3, xAlign = Enum.TextXAlignment.Left,
			size2 = UDim2.new(1, 0, 0, 34), zIndex = 24 })
		if #rows == 0 then
			brightText(card, { text = emptyText, font = PanelChrome.DISPLAY_FONT, size = 18, color = BRIGHT.InkMuted, wrap = true,
				pos = UDim2.fromOffset(0, 44), size2 = UDim2.new(1, 0, 0, lineH - 12), zIndex = 24 })
		end
		for i, info in ipairs(rows) do
			local key = info.key
			swordLine(card, info, 42 + (i - 1) * lineH, lineH, withButton, buttonText, buttonColors, function()
				tradeRemote:FireServer(action, key)
			end)
		end
	end
	-- Your side shows everything you own (carried and vaulted); theirs shows only their offer.
	section(string.format("Your offer (%d / %d)", #st.mine, st.maxOffer or 6), st.mine,
		"Add swords from your inventory or vault below.", true, "Remove", TRADE_GREY, "Offer")
	section(st.partnerName .. "'s offer", st.theirs, "They have not offered anything yet.", false)
	local offered = {}
	for _, info in ipairs(st.mine) do offered[info.key] = true end
	local function unoffered(list)
		local out = {}
		for _, info in ipairs(list or {}) do
			if not offered[info.key] then table.insert(out, info) end
		end
		return out
	end
	section("Your inventory", unoffered(st.carried), "No relic swords on you.", true, "Add", TRADE_GREEN, "Offer")
	section("Your vault", unoffered(st.vaulted), "Nothing stored with the Vaultkeeper.", true, "Add", TRADE_GREEN, "Offer")

	local confirmCard = tradeCard(order, 88); order += 1
	brightText(confirmCard, { text = st.myConfirmed and "Waiting for " .. st.partnerName .. " to confirm..." or
		"Check both offers, then confirm.", font = PanelChrome.DISPLAY_FONT, size = 20, color = BRIGHT.Ink, wrap = true,
		size2 = UDim2.new(1, -160, 1, 0), zIndex = 24 })
	if not st.myConfirmed then
		tradeButton(confirmCard, "Confirm", TRADE_GREEN, UDim2.new(1, 0, 0.5, -3), UDim2.fromOffset(148, 62), function()
			tradeRemote:FireServer("Confirm")
		end)
	end
	return order
end

local function buildTradePanel()
	clearBody()
	headerTitle.Text = "Trading!"
	local order = 1
	if tradeState.session then
		buildTradeSession(order)
	else
		buildTradeLobby(order)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  SETTINGS TAB: PS99-style light rows at game scale. Each setting is one chunky card (a big
--  icon tile, a stroked display label, and a thick bevelled control); the keyboard shortcuts
--  are demoted to a small keycap footer. Controls update in place (settingsSync) so dragging
--  the slider never rebuilds the panel under the player's finger.
-- ═══════════════════════════════════════════════════════════════════════════
local SETTINGS_RED = { top = Color3.fromRGB(255, 132, 120), bottom = Color3.fromRGB(234, 58, 66), lip = Color3.fromRGB(150, 24, 40) }
local SETTINGS_KEY = { top = Color3.fromRGB(255, 255, 255), bottom = Color3.fromRGB(212, 220, 238), lip = Color3.fromRGB(146, 156, 182) }
local SETTINGS_TRACK = { top = Color3.fromRGB(158, 166, 188), bottom = Color3.fromRGB(208, 214, 230) }
-- A beamed pair of eighth notes, in fractions of a square holder (see shapeIcon).
local NOTE_PIECES = {
	{ 0.32, 0.77, 0.34, 0.25, -20, true },
	{ 0.76, 0.67, 0.34, 0.25, -20, true },
	{ 0.445, 0.45, 0.085, 0.62, 0, false },
	{ 0.885, 0.35, 0.085, 0.62, 0, false },
	{ 0.665, 0.12, 0.52, 0.14, -13, false },
}
local SHORTCUTS = {
	{ key = "M", desc = "Menu" },
	{ key = "1", desc = "Sword" }, -- sheathe / draw (SwordHotbarGui)
	{ key = "E", desc = "Attack" },
	{ key = "Click", desc = "Attack" },
	{ key = "Esc", desc = "Close" },
}
local settingsSync = nil -- set while the Settings tab is built; refreshes its controls in place

-- A 3D block: a dark lip under an offset glossy face gives it a bevelled bottom edge.
local function bevelBlock(parent, colors, props)
	local z = props.zIndex
	local r = props.radius or 16
	local block = Instance.new("Frame")
	block.Name = props.name or "Block"
	block.BackgroundColor3 = colors.lip
	block.BorderSizePixel = 0
	block.AnchorPoint = props.anchor or Vector2.zero
	block.Position = props.pos or UDim2.new()
	block.Size = props.size
	block.ZIndex = z
	block.Parent = parent
	addCorner(block, r)
	PanelChrome.stroke(block, BRIGHT.Outline, props.stroke or 3.5)
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.Size = UDim2.new(1, 0, 1, -(props.lip or 7))
	face.ZIndex = z + 1
	face.Parent = block
	addCorner(face, r)
	local grad = PanelChrome.gradient(face, colors.top, colors.bottom)
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.5
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromOffset(6, 4)
	shine.Size = UDim2.new(1, -12, 0.34, 0)
	shine.ZIndex = z + 1
	shine.Parent = face
	addCorner(shine, math.max(r - 5, 4))
	local sg = Instance.new("UIGradient")
	sg.Rotation = 90
	sg.Transparency = NumberSequence.new(0.1, 1)
	sg.Parent = shine
	return block, face, grad
end

-- Soft dark shape offset under a control, so it reads as sitting on the card.
local function dropShadow(parent, radius, z, offset)
	local shadow = Instance.new("Frame")
	shadow.Name = "DropShadow"
	shadow.BackgroundColor3 = BRIGHT.Outline
	shadow.BackgroundTransparency = 0.62
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(0, offset or 7)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.ZIndex = z
	shadow.Parent = parent
	addCorner(shadow, radius)
	return shadow
end

-- Recessed groove shading along the top of a track.
local function grooveShadow(parent, radius, z)
	local s = Instance.new("Frame")
	s.Name = "Groove"
	s.BackgroundColor3 = Color3.fromRGB(40, 46, 70)
	s.BorderSizePixel = 0
	s.Size = UDim2.new(1, 0, 0.55, 0)
	s.ZIndex = z
	s.Parent = parent
	addCorner(s, radius)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new(0.55, 1)
	g.Parent = s
end

-- One setting card: gradient face, heavy outline, a big loot-style icon tile, a stroked
-- display label with a sub line under it, and a control slot (right side, or along the
-- bottom on phones).
local function settingsRow(order, spec, narrow)
	local rowH = narrow and 176 or 140
	local tileSize = narrow and 72 or 100
	local controlW = narrow and 0 or 250
	local z = 24
	local row = Instance.new("Frame")
	row.Name = "Setting_" .. spec.name
	row.Size = UDim2.new(1, 0, 0, rowH)
	row.BackgroundColor3 = Color3.new(1, 1, 1)
	row.LayoutOrder = order
	row.ZIndex = 23
	row.Parent = body
	addCorner(row, 22)
	PanelChrome.gradient(row, Color3.fromRGB(255, 255, 255), BRIGHT.Row)
	PanelChrome.stroke(row, BRIGHT.Outline, 3.5)
	addPadding(row, 12, 14, 12, 12)

	local tile = Instance.new("Frame")
	tile.Name = "IconTile"
	tile.Size = UDim2.fromOffset(tileSize, tileSize)
	if not narrow then
		tile.AnchorPoint = Vector2.new(0, 0.5)
		tile.Position = UDim2.fromScale(0, 0.5)
	end
	tile.ZIndex = z
	tile.Parent = row
	addCorner(tile, 18)
	PanelChrome.lootTile(tile, spec.tile, { radius = 18, zIndex = z, glowY = 0.5 })
	spec.icon(tile, z + 2)

	local textX = tileSize + 16
	local textW = if narrow then UDim2.new(1, -textX, 0, 0) else UDim2.new(1, -(textX + controlW + 14), 0, 0)
	local textY = if narrow then 0 else math.floor((rowH - 24 - 88) / 2)
	local title = PanelChrome.display(row, {
		name = "Title", text = spec.title, size = narrow and 32 or 36, stroke = 3.5, scaled = true, minSize = 18,
		xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(textX, textY),
		size2 = textW + UDim2.fromOffset(0, 44), zIndex = z + 1,
	})
	local sub = Instance.new("Frame")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(textX, textY + 44)
	sub.Size = textW + UDim2.fromOffset(0, narrow and 30 or 44)
	sub.ZIndex = z
	sub.Parent = row

	local control = Instance.new("Frame")
	control.Name = "Control"
	control.BackgroundTransparency = 1
	control.ZIndex = z
	control.Parent = row
	if narrow then
		control.AnchorPoint = Vector2.new(0.5, 1)
		control.Position = UDim2.new(0.5, 0, 1, 0)
		control.Size = UDim2.new(1, 0, 0, 76)
	else
		control.AnchorPoint = Vector2.new(1, 0.5)
		control.Position = UDim2.new(1, 0, 0.5, 0)
		control.Size = UDim2.fromOffset(controlW, 80)
	end
	return row, title, sub, control
end

-- Fat slider: a recessed grey groove, a thick green fill and a big bevelled green knob. The
-- whole control strip is the hit area, so it stays easy to grab on a phone.
local function settingsSlider(control, value, z)
	local KNOB = 60
	local track = Instance.new("Frame")
	track.Name = "SliderTrack"
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, KNOB / 2, 0.5, 0)
	track.Size = UDim2.new(1, -KNOB, 0, 38)
	track.BackgroundColor3 = Color3.new(1, 1, 1)
	track.BorderSizePixel = 0
	track.ZIndex = z
	track.Parent = control
	addCorner(track, 19)
	PanelChrome.gradient(track, SETTINGS_TRACK.top, SETTINGS_TRACK.bottom)
	PanelChrome.stroke(track, BRIGHT.Outline, 3.5)
	grooveShadow(track, 19, z)

	local fill = Instance.new("Frame")
	fill.Name = "SliderFill"
	fill.Size = UDim2.new(value, 0, 1, 0)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.ZIndex = z + 1
	fill.Parent = track
	addCorner(fill, 19)
	PanelChrome.gradient(fill, SKILL_GREEN.top, SKILL_GREEN.bottom)
	local fillShine = Instance.new("Frame")
	fillShine.BackgroundColor3 = Color3.new(1, 1, 1)
	fillShine.BackgroundTransparency = 0.55
	fillShine.BorderSizePixel = 0
	fillShine.Position = UDim2.fromOffset(8, 5)
	fillShine.Size = UDim2.new(1, -16, 0, 7)
	fillShine.ZIndex = z + 1
	fillShine.Parent = fill
	addCorner(fillShine, 4)

	local knobHolder = Instance.new("Frame")
	knobHolder.Name = "SliderKnob"
	knobHolder.BackgroundTransparency = 1
	knobHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	knobHolder.Position = UDim2.new(value, 0, 0.5, 0)
	knobHolder.Size = UDim2.fromOffset(KNOB, KNOB)
	knobHolder.ZIndex = z + 2
	knobHolder.Parent = track
	dropShadow(knobHolder, 18, z + 2, 6)
	local _, knobFace = bevelBlock(knobHolder, SKILL_GREEN, {
		name = "Knob", size = UDim2.fromScale(1, 1), radius = 18, lip = 9, zIndex = z + 3,
	})
	for i = -1, 1 do
		local grip = Instance.new("Frame")
		grip.AnchorPoint = Vector2.new(0.5, 0.5)
		grip.Position = UDim2.new(0.5, i * 11, 0.54, 0)
		grip.Size = UDim2.new(0, 5, 0.46, 0)
		grip.BackgroundColor3 = SKILL_GREEN.lip
		grip.BackgroundTransparency = 0.15
		grip.BorderSizePixel = 0
		grip.ZIndex = z + 5
		grip.Parent = knobFace
		addCorner(grip, 3)
	end
	local knobScale = Instance.new("UIScale")
	knobScale.Parent = knobHolder

	local hit = Instance.new("TextButton")
	hit.Name = "SliderHitArea"
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = z + 8
	hit.Parent = control
	hit.MouseEnter:Connect(function() knobScale.Scale = 1.08 end)
	hit.MouseLeave:Connect(function() knobScale.Scale = 1 end)

	local function show(v)
		fill.Size = UDim2.new(v, 0, 1, 0)
		knobHolder.Position = UDim2.new(v, 0, 0.5, 0)
	end
	return { track = track, hit = hit, knobScale = knobScale, show = show }
end

-- Big two-state switch: a recessed grey track with a bevelled thumb that slides across,
-- green "On" on the right, red "Off" on the left, over a drop shadow.
local function settingsToggle(control, on, z)
	local btn = Instance.new("TextButton")
	btn.Name = "Toggle"
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.BackgroundTransparency = 1
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = UDim2.fromScale(0.5, 0.5)
	btn.Size = UDim2.fromOffset(212, 70)
	btn.ZIndex = z
	btn.Parent = control
	dropShadow(btn, 22, z, 7)
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Color3.new(1, 1, 1)
	track.BorderSizePixel = 0
	track.Size = UDim2.fromScale(1, 1)
	track.ZIndex = z + 1
	track.Parent = btn
	addCorner(track, 22)
	PanelChrome.gradient(track, SETTINGS_TRACK.top, SETTINGS_TRACK.bottom)
	PanelChrome.stroke(track, BRIGHT.Outline, 3.5)
	grooveShadow(track, 22, z + 1)
	-- Ghost of the other state, so the empty half still says what a tap will do.
	local ghost = brightText(track, {
		text = "", font = PanelChrome.DISPLAY_FONT, size = 24, color = Color3.fromRGB(96, 104, 130),
		xAlign = Enum.TextXAlignment.Center, size2 = UDim2.new(0.42, 0, 1, 0), zIndex = z + 2,
	})

	local thumb, face, grad = bevelBlock(track, SKILL_GREEN, {
		name = "Thumb", anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.58, 0, 1, 0),
		radius = 22, lip = 9, zIndex = z + 3,
	})
	local label = PanelChrome.display(face, {
		name = "State", text = "", size = 34, stroke = 3.5, zIndex = z + 6,
		pos = UDim2.fromOffset(0, 1), size2 = UDim2.fromScale(1, 1),
	})
	local scale = Instance.new("UIScale")
	scale.Parent = btn
	btn.MouseEnter:Connect(function() scale.Scale = 1.05 end)
	btn.MouseLeave:Connect(function() scale.Scale = 1 end)
	btn.MouseButton1Down:Connect(function() scale.Scale = 0.96 end)
	btn.MouseButton1Up:Connect(function() scale.Scale = 1.05 end)

	local function show(state, animate)
		local c = if state then SKILL_GREEN else SETTINGS_RED
		thumb.BackgroundColor3 = c.lip
		grad.Color = ColorSequence.new(c.top, c.bottom)
		label.Text = if state then "On" else "Off"
		ghost.Text = if state then "Off" else "On"
		ghost.Position = if state then UDim2.fromScale(0.01, 0) else UDim2.fromScale(0.57, 0)
		local target = UDim2.fromScale(if state then 0.71 else 0.29, 0.5)
		if animate then
			TweenService:Create(thumb, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = target }):Play()
		else
			thumb.Position = target
		end
	end
	show(on, false)
	return { button = btn, show = show }
end

local function buildSettingsPanel()
	clearBody()
	headerTitle.Text = "Settings"
	local narrow = layoutMode == "narrow"
	local z = 24

	-- ── Music volume ──
	local musicVolume = player:GetAttribute("MusicVolume")
	if musicVolume == nil then musicVolume = 0.5 end
	local _, _, volSub, volControl = settingsRow(1, {
		name = "Music", title = "Music Volume", tile = "Epic",
		icon = function(tile, iz)
			shapeIcon(tile, NOTE_PIECES, Color3.fromRGB(255, 222, 72), {
				name = "Note", size = UDim2.fromScale(0.7, 0.7), pos = UDim2.fromScale(0.5, 0.52),
				rotation = -8, zIndex = iz, pad = 7,
			})
		end,
	}, narrow)
	local volValueLabel = PanelChrome.display(volSub, {
		name = "Value", text = tostring(math.round(musicVolume * 100)) .. "%", size = narrow and 28 or 34,
		stroke = 3.5, color = BRIGHT.Gold, xAlign = Enum.TextXAlignment.Left, zIndex = z + 1,
	})
	local slider = settingsSlider(volControl, musicVolume, z + 1)
	local sliderTrack = slider.track

	-- Apply volume to SoundService sounds and persist
	local function applyVolume(vol)
		musicVolume = math.clamp(vol, 0, 1)
		player:SetAttribute("MusicVolume", musicVolume)
		for _, sound in ipairs(SoundService:GetDescendants()) do
			if sound:IsA("Sound") then
				local base = sound:GetAttribute("BaseVolume")
				if not base then
					base = sound.Volume
					sound:SetAttribute("BaseVolume", base)
				end
				sound.Volume = base * musicVolume
			end
		end
		slider.show(musicVolume)
		volValueLabel.Text = tostring(math.round(musicVolume * 100)) .. "%"
	end

	-- Drag handling (mouse and touch). The input connections die with the slider.
	local dragging = false
	local function updateSliderFromMouse(inputX)
		local absPos = sliderTrack.AbsolutePosition.X
		local absSize = sliderTrack.AbsoluteSize.X
		if absSize <= 0 then return end
		local fraction = math.clamp((inputX - absPos) / absSize, 0, 1)
		applyVolume(fraction)
	end

	slider.hit.MouseButton1Down:Connect(function(x)
		dragging = true
		slider.knobScale.Scale = 1.12
		updateSliderFromMouse(x)
	end)
	local conns = {}
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateSliderFromMouse(input.Position.X)
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then slider.knobScale.Scale = 1 end
			dragging = false
		end
	end))
	slider.hit.Destroying:Connect(function()
		for _, c in ipairs(conns) do c:Disconnect() end
	end)

	-- ── Show damage numbers ──
	local showDmgOn = player:GetAttribute("ShowDamageNumbers")
	if showDmgOn == nil then showDmgOn = true end
	local _, _, dmgSub, dmgControl = settingsRow(2, {
		name = "DamageNumbers", title = "Damage Numbers", tile = "Legendary",
		icon = function(tile, iz)
			local img = Instance.new("ImageLabel")
			img.Name = "Icon"
			img.BackgroundTransparency = 1
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.fromScale(0.44, 0.56)
			img.Size = UDim2.fromScale(0.82, 0.82)
			img.Image = ICONS.Sword
			img.ScaleType = Enum.ScaleType.Fit
			img.Rotation = -6
			img.ZIndex = iz
			img.Parent = tile
			local hitNum = PanelChrome.display(tile, {
				name = "HitNumber", text = "-99", size = narrow and 24 or 32, stroke = 3,
				color = Color3.fromRGB(255, 70, 70), anchor = Vector2.new(1, 0),
				pos = UDim2.new(1, 8, 0, -6), size2 = UDim2.fromScale(0.8, 0.4), zIndex = iz + 2,
			})
			hitNum.Rotation = 10
		end,
	}, narrow)
	local caption = brightText(dmgSub, {
		text = "Hits pop up over enemies", font = PanelChrome.DISPLAY_FONT, size = narrow and 16 or 19,
		color = BRIGHT.Ink, size2 = UDim2.fromScale(1, 1), wrap = true, zIndex = z + 1,
	})
	caption.TextYAlignment = Enum.TextYAlignment.Top
	local toggle = settingsToggle(dmgControl, showDmgOn, z + 1)
	local dmgToggleBtn = toggle.button

	dmgToggleBtn.Activated:Connect(function()
		showDmgOn = not showDmgOn
		player:SetAttribute("ShowDamageNumbers", showDmgOn)
		toggle.show(showDmgOn, true)
	end)

	-- Attribute changes from elsewhere refresh the controls without rebuilding the panel.
	settingsSync = function()
		local v = player:GetAttribute("MusicVolume")
		if v ~= nil and not dragging then
			musicVolume = v
			slider.show(v)
			volValueLabel.Text = tostring(math.round(v * 100)) .. "%"
		end
		local d = player:GetAttribute("ShowDamageNumbers")
		if d == nil then d = true end
		if d ~= showDmgOn then
			showDmgOn = d
			toggle.show(d, true)
		end
	end

	-- ── Keyboard shortcuts: a small keycap footer ──
	local footer = Instance.new("Frame")
	footer.Name = "Shortcuts"
	-- Header 36 + padding 20, then keycap rows: one row of all keys on desktop, two per row on phones.
	local keyRows = if narrow then math.ceil(#SHORTCUTS / 2) else 1
	local keyRowH = if narrow then 62 else 90
	footer.Size = UDim2.new(1, 0, 0, 56 + keyRows * keyRowH + (keyRows - 1) * 8)
	footer.BackgroundColor3 = Color3.fromRGB(222, 230, 244)
	footer.BorderSizePixel = 0
	footer.LayoutOrder = 3
	footer.ZIndex = 23
	footer.Parent = body
	addCorner(footer, 20)
	PanelChrome.stroke(footer, BRIGHT.RowStroke, 3)
	addPadding(footer, 8, 14, 12, 14)
	local head = PanelChrome.display(footer, {
		name = "Header", text = "Controls", size = 24, stroke = 3, xAlign = Enum.TextXAlignment.Left,
		size2 = UDim2.new(1, 0, 0, 30), zIndex = z,
	})
	head.Name = "Header"
	local grid = Instance.new("Frame")
	grid.Name = "Keys"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(0, 36)
	grid.Size = UDim2.new(1, 0, 1, -36)
	grid.ZIndex = z
	grid.Parent = footer
	local gl = Instance.new("UIGridLayout")
	gl.CellPadding = UDim2.fromOffset(10, 8)
	gl.CellSize = if narrow then UDim2.new(0.5, -5, 0, 62) else UDim2.new(1 / #SHORTCUTS, -8, 0, 90)
	gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid
	for i, sc in ipairs(SHORTCUTS) do
		local cell = Instance.new("Frame")
		cell.Name = "Key_" .. sc.key
		cell.BackgroundTransparency = 1
		cell.LayoutOrder = i
		cell.ZIndex = z
		cell.Parent = grid
		local capW = if #sc.key > 1 then 86 else 62
		local _, capFace = bevelBlock(cell, SETTINGS_KEY, {
			name = "Keycap", size = UDim2.fromOffset(capW, 58), radius = 14, lip = 8, stroke = 3, zIndex = z + 1,
			anchor = if narrow then Vector2.new(0, 0.5) else Vector2.new(0.5, 0),
			pos = if narrow then UDim2.fromScale(0, 0.5) else UDim2.fromScale(0.5, 0),
		})
		PanelChrome.display(capFace, {
			name = "Key", text = sc.key, size = #sc.key > 1 and 24 or 30, stroke = 3, zIndex = z + 4,
		})
		brightText(cell, {
			text = sc.desc, font = PanelChrome.DISPLAY_FONT, size = 19, color = BRIGHT.Ink,
			xAlign = if narrow then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			pos = if narrow then UDim2.fromOffset(capW + 10, 0) else UDim2.fromOffset(0, 62),
			size2 = if narrow then UDim2.new(1, -(capW + 10), 1, 0) else UDim2.new(1, 0, 0, 26),
			zIndex = z + 1,
		})
	end
end

local function refreshTopBar()
	-- Short form (31.2K) so a big purse never shrinks the TextScaled chip into unreadable digits.
	-- Once the save has loaded, a rise in gold is a gain and animates; the first fill snaps.
	goldCounter.set(player:GetAttribute('Gold') or 0, player:GetAttribute("DataLoaded") == true)
end

local function refreshSkills()
	local points = player:GetAttribute('SkillPoints') or 0
	if skillButtons.points then skillButtons.points.Text = NumberFormat.short(points) end
	local canSpend = points > 0
	for _, attr in ipairs(SKILL_ATTRIBUTES) do
		local refs = skillButtons[attr.name]
		if refs then
			local level = player:GetAttribute(attr.name) or 0
			refs.value.Text = NumberFormat.short(level)
			local text, frac = skillEffectText(attr, level)
			refs.barText.Text = text
			if frac then refs.bar.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1) end
			refs.bar.Visible = frac == nil or frac > 0
			-- Greyed only when there is nothing to spend; a capped stat reads MAX.
			local maxed = frac ~= nil and frac >= 1
			local c = if canSpend and not maxed then SKILL_GREEN else SKILL_GREY
			refs.up.grad.Color = ColorSequence.new(c.top, c.bottom)
			refs.up.lip.BackgroundColor3 = c.lip
			refs.up.cost.Text = if maxed then "MAX" else "1 SP"
		end
	end
end

-- The side button for the open tab gets a white outline while the menu is up.
local function refreshNavSelection()
	for id, btn in pairs(navButtons) do
		local stroke = btn:FindFirstChild("Outline")
		if stroke then
			local selected = panelOpen and id == activeTab
			stroke.Color = selected and Color3.new(1, 1, 1) or BRIGHT.Outline
			stroke.Thickness = selected and 4.5 or 3.5
		end
	end
end

local function openTab(tabId)
	activeTab = tabId
	refreshNavSelection()
	-- Panel chrome follows the tab: title icon, the in-panel rail's selection, and the well
	-- (light for the Inventory, dark for tabs still drawn as dark cards).
	for _, item in ipairs(NAV_ITEMS) do
		if item.id == tabId and item.icon then headerIcon.Image = item.icon end
	end
	headerIcon.Visible = tabId ~= 'Trade'
	tradeTitleIcon.Visible = tabId == 'Trade'
	for id, btn in pairs(railButtons) do
		local selected = id == tabId
		btn.BackgroundTransparency = selected and 0 or 1
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Transparency = selected and 0 or 1 end
	end
	setWellTheme(tabId == 'Inventory' or tabId == 'Skills' or tabId == 'Rebirth' or tabId == 'Trade' or tabId == 'Settings')
	if tabId ~= 'Inventory' then inventorySelection = nil end
	if tabId == 'Inventory' then buildInventoryPanel()
	elseif tabId == 'Skills' then buildSkillsPanel(); refreshSkills()
	elseif tabId == 'Rebirth' then buildRebirthPanel()
	elseif tabId == 'Trade' then buildTradePanel(); tradeRemote:FireServer("Refresh")
	elseif tabId == 'Settings' then buildSettingsPanel() end
end


-- contentReady: the caller has just built the active tab's contents (openMenuOn), so opening
-- does not build the Inventory grid a second time.
local function setMenuOpen(open, contentReady: boolean?)
	if panelOpen == open then return end
	panelOpen = open
	refreshNavSelection()
	if open then
		overlay.Visible = true
		contentPanel.Visible = true
	else
		inventorySelection = nil
		closeInventoryDetail()
	end
	if open and not activeTab then openTab('Inventory')
	elseif open and not contentReady and activeTab == 'Inventory' then buildInventoryPanel() end
	-- Shared open/close motion (PanelChrome): the panel grows in with a small overshoot while
	-- the backdrop dims, then the tiles (or a tab's rows) and the tab rail's icons cascade in
	-- from the top down.
	local motion = {
		frame = contentPanel, scale = panelScale, dim = overlay, dimTo = 0.5,
		tiles = function()
			local grid = body:FindFirstChild("ItemGrid")
			return { grid or body, panelRail }
		end,
	}
	if open then
		PanelChrome.openMotion(motion)
	else
		PanelChrome.closeMotion(motion, function()
			overlay.Visible = false
			contentPanel.Visible = false
		end)
	end
end

local function toggleMenu() setMenuOpen(not panelOpen) end

-- Opens the menu on one tab, building that tab's contents once before the panel's open motion
-- starts (opening and then switching tab used to build the Inventory grid two or three times in
-- the same frame, a long hitch that froze the pressed button and the panel's entrance).
local function openMenuOn(tabId)
	if panelOpen then openTab(tabId) return end
	openTab(tabId)
	setMenuOpen(true, true)
end

-- Runs fn once the released button's spring is on screen and nearly at its overshoot. Building
-- a tab (the Inventory's 3D sword renders above all) holds up one frame for ~150 ms; built in
-- the click's own frame, that hitch froze the button fully pressed, so the release never read
-- as a click. After this lead the hitch lands near the spring's peak and the settle follows it.
local RELEASE_LEAD = 0.7 -- [TUNING] fraction of PanelChrome.PRESS.UpPeakAt
local function afterReleaseShows(fn)
	task.spawn(function()
		local lead = PanelChrome.PRESS.UpPeakAt * RELEASE_LEAD
		local waited, frames = 0, 0
		while waited < lead or frames < 2 do
			waited += RunService.RenderStepped:Wait()
			frames += 1
		end
		fn()
	end)
end

-- In-panel tab rail: one icon tab per menu tab, selected state set by openTab, with red
-- count badges (swords carried, unspent skill points).
local RAIL_TABS = { "Inventory", "Skills", "Rebirth", "Trade", "Settings" }
for i, id in ipairs(RAIL_TABS) do
	local icon = ICONS.Inventory
	for _, item in ipairs(NAV_ITEMS) do
		if item.id == id and item.icon then icon = item.icon end
	end
	local b = Instance.new("TextButton")
	b.Name = "Rail_" .. id
	b.Text = ""
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(layout.touch, layout.touch)
	b.BackgroundColor3 = BRIGHT.Select
	b.BackgroundTransparency = 1
	b.LayoutOrder = i
	b.ZIndex = 25
	b.Parent = panelRail
	addCorner(b, 14)
	PanelChrome.stroke(b, BRIGHT.Blue, 3, 1)
	local img = Instance.new("ImageLabel")
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromScale(0.84, 0.84)
	img.BackgroundTransparency = 1
	img.Image = icon
	img.ScaleType = Enum.ScaleType.Fit
	img.ZIndex = 26
	img.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = img
	b.MouseEnter:Connect(function() scale.Scale = 1.12 end)
	b.MouseLeave:Connect(function() scale.Scale = 1 end)
	b.Activated:Connect(function()
		if activeTab ~= id then openTab(id) end
	end)
	railButtons[id] = b
end

refreshRailBadges = function()
	local counts = {
		Inventory = #getCarriedTools(),
		Skills = player:GetAttribute("SkillPoints") or 0,
	}
	for id, btn in pairs(railButtons) do
		local old = btn:FindFirstChild("CountBadge")
		if old then old:Destroy() end
		local n = counts[id]
		if n and n > 0 then
			local badge = PanelChrome.countBadge(btn, tostring(n), 28)
			badge.Position = UDim2.new(1, -4, 0, 4)
		end
	end
	-- The same counts ride the always-on side buttons, PS99-style.
	for id, btn in pairs(navButtons) do
		local old = btn:FindFirstChild("CountBadge")
		if old then old:Destroy() end
		local n = counts[id]
		if n and n > 0 then
			local badge = PanelChrome.countBadge(btn, tostring(n), 10)
			badge.Position = UDim2.new(1, -4, 0, 4)
		end
	end
end
refreshRailBadges()

onLayoutModeChanged = function()
	if panelOpen and activeTab == "Inventory" then buildInventoryPanel() end
	if panelOpen and activeTab == "Skills" then buildSkillsPanel(); refreshSkills() end
	if panelOpen and activeTab == "Rebirth" then buildRebirthPanel() end
	if panelOpen and activeTab == "Settings" then buildSettingsPanel() end
	if panelOpen and activeTab == "Trade" then buildTradePanel() end
end
applyPanelLayout()

-- Studio-only screenshot hook (see GuiShowcase): opens the named tab hands-free. The
-- Inventory showcase equips the first sword (as the EQUIP button would) and opens its card.
GuiShowcase.register("Inventory", function()
	setMenuOpen(true)
	openTab("Inventory")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if humanoid and backpack and not character:FindFirstChildOfClass("Tool") then
		local first = backpack:FindFirstChildOfClass("Tool")
		if first then humanoid:EquipTool(first) end
	end
	task.wait(0.8)
	local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
	if held then
		inventorySelection = held
		buildInventoryPanel()
	end
end)
for _, tab in ipairs({ "Skills", "Rebirth", "Settings" }) do
	GuiShowcase.register(tab, function()
		setMenuOpen(true)
		openTab(tab)
	end)
end
-- A solo play test has nobody to list, so the Trade showcase seeds made-up sample rows. They
-- live only on this client (GuiShowcase runs in Studio only), are drawn only while the real
-- list is empty, and their buttons never fire the trade remote.
GuiShowcase.register("Trade", function()
	local function sample(name, username, level, wealth, busy, skin, hair, shirt)
		return {
			sample = true, name = name, username = username, level = level, wealth = wealth, busy = busy,
			look = { skin = skin, hair = hair, shirt = shirt },
		}
	end
	tradeSamples = {
		sample("SirSlicesALot", "sirslices_07", 42, 186400, false,
			Color3.fromRGB(255, 214, 92), Color3.fromRGB(86, 58, 40), Color3.fromRGB(64, 150, 255)),
		sample("NovaBlade", "novablade", 27, 64200, false,
			Color3.fromRGB(240, 190, 150), Color3.fromRGB(250, 214, 90), Color3.fromRGB(236, 64, 90)),
		sample("MangoKnight", "mangoknight22", 18, 21800, true,
			Color3.fromRGB(196, 140, 100), Color3.fromRGB(30, 30, 40), Color3.fromRGB(90, 200, 90)),
		sample("PixelPaladin", "pixel_paladin", 9, 5400, false,
			Color3.fromRGB(255, 214, 92), Color3.fromRGB(170, 90, 230), Color3.fromRGB(255, 160, 40)),
	}
	setMenuOpen(true)
	openTab("Trade")
end)
-- The genuine empty lobby a solo player sees, with no sample rows.
GuiShowcase.register("TradeEmpty", function()
	setMenuOpen(true)
	openTab("Trade")
end)

-- Trade tab events (after setMenuOpen so an incoming request can open the menu).
tradeRemote.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Players" then
		tradeState.players = a or {}
		tradeState.incoming = b
	elseif kind == "Incoming" then
		tradeState.incoming = { userId = a, name = b }
		if not panelOpen then
			setMenuOpen(true)
			openTab("Trade")
			return
		end
	elseif kind == "Session" then
		tradeState.session = a
		tradeState.incoming = nil
		if not panelOpen then setMenuOpen(true) end
		if activeTab ~= "Trade" then openTab("Trade") return end
	elseif kind == "Ended" then
		tradeState.session = nil
		tradeRemote:FireServer("Refresh")
	end
	if panelOpen and activeTab == "Trade" then buildTradePanel() end
end)

-- Talking to the Rebirth Keeper at the hub's rebirth pavilion opens this panel on
-- the Rebirth tab. It only opens the panel: the existing confirm button and
-- RebirthSystem keep sole authority over requirements and the rebirth itself.
task.spawn(function()
	local stationOpen = remotes:WaitForChild("RebirthStationOpen", 30)
	if not stationOpen then return end
	stationOpen.OnClientEvent:Connect(function()
		setMenuOpen(true)
		openTab("Rebirth")
		headerTitle.Text = "Rebirth Keeper"
	end)
end)

for i, item in ipairs(NAV_ITEMS) do
	local btn = createNavButton(item, i)
	btn.Activated:Connect(function()
		afterReleaseShows(function()
			if panelOpen and activeTab == item.id then setMenuOpen(false)
			else openMenuOn(item.id) end
		end)
	end)
	navButtons[item.id] = btn
end
refreshNavSelection()
refreshRailBadges()

closeBtn.Activated:Connect(function() setMenuOpen(false) end)
overlay.Activated:Connect(function() setMenuOpen(false) end)

-- Studio-only motion capture hook (see GuiShowcase.motion): opens the Inventory panel exactly
-- as pressing the Items hotbar button does.
GuiShowcase.motion("PanelOpen", function()
	if panelOpen and activeTab == "Inventory" then return end
	openMenuOn("Inventory")
end)

-- Studio-only motion capture hook: replays a mouse press on the Items button. Scripts cannot fire
-- a GuiButton's input events, so this steps the button's own hover/down/up states in the order a
-- mouse fires them, then opens the Inventory as the button's Activated handler does. The pointer
-- is already resting on the button (hover settled before the clapperboard), so the strip opens on
-- the press itself.
local function itemsPress()
	return navButtons.Inventory and PanelChrome.pressHandle(navButtons.Inventory)
end
GuiShowcase.motion("ButtonPress", function()
	local press = itemsPress()
	if not press then return end
	press.down() -- MouseButton1Down
	task.wait(0.12)
	press.up() -- MouseButton1Up, then Activated
	afterReleaseShows(function()
		if not (panelOpen and activeTab == "Inventory") then
			openMenuOn("Inventory")
		end
	end)
end, function()
	local press = itemsPress()
	if press then press.hover(true) end -- MouseEnter
end)

-- Studio-only motion capture hook: a gold gain through the real path. Setting Gold on the local
-- player is client-only (it never replicates, and the next server update overwrites it), and it
-- fires the same attribute watcher a real gain does.
GuiShowcase.motion("CounterTick", function()
	local player = Players.LocalPlayer
	player:SetAttribute("Gold", (player:GetAttribute("Gold") or 0) + 3000)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.M then toggleMenu() end
end)

local attrsToWatch = { 'Gold', 'SkillPoints', 'Strength', 'Health', 'Defense', 'ExperienceGain', 'Rebirths', 'RebirthRequirement', 'RebirthPayback', 'RebirthGoldCost', 'ShowDamageNumbers', 'MusicVolume' }
for _, attr in ipairs(attrsToWatch) do
	player:GetAttributeChangedSignal(attr):Connect(function()
		refreshTopBar(); refreshSkills()
		if attr == 'SkillPoints' then refreshRailBadges() end
		-- A rebirth changes the gold multiplier, and so changes every sell price on every
		-- inventory tile: rebuild the panel if it is the one on screen. The Rebirth tab also
		-- follows the server's payback tick (every few seconds at most) so its price line and
		-- "more gold" figure never go stale while it is open.
		if (attr == 'Rebirths' or attr == 'RebirthRequirement') and activeTab == 'Inventory' and panelOpen then
			buildInventoryPanel()
		elseif attr == 'RebirthPayback' and activeTab == 'Rebirth' and panelOpen then
			if rebirthStatusRefresh then rebirthStatusRefresh() end
		elseif (attr == 'Rebirths' or attr == 'RebirthRequirement' or attr == 'RebirthGoldCost') and activeTab == 'Rebirth' and panelOpen then
			buildRebirthPanel()
		elseif (attr == 'ShowDamageNumbers' or attr == 'MusicVolume') and activeTab == 'Settings' and panelOpen then
			if settingsSync then settingsSync() else buildSettingsPanel() end
		end
	end)
end

-- Refresh inventory view when tools change in backpack/character
local inventoryRefreshBound = setmetatable({}, { __mode = "k" })
local function refreshInventoryIfVisible()
	if activeTab == "Inventory" and panelOpen then
		buildInventoryPanel()
	end
end

local function bindInventoryContainer(container)
	if not container or inventoryRefreshBound[container] then
		return
	end
	inventoryRefreshBound[container] = true
	container.ChildAdded:Connect(refreshInventoryIfVisible)
	container.ChildRemoved:Connect(refreshInventoryIfVisible)
	-- Keep the side Inventory button's sword count current while the menu is closed.
	container.ChildAdded:Connect(function() refreshRailBadges() end)
	container.ChildRemoved:Connect(function() refreshRailBadges() end)
end

local function bindInventoryRefresh()
	local bp = player:WaitForChild("Backpack", 5)
	bindInventoryContainer(bp)
	bindInventoryContainer(player.Character)
end

player.CharacterAdded:Connect(function(ch)
	bindInventoryRefresh()
end)
bindInventoryRefresh()

refreshTopBar()

print('[MainMenuGui] Smash Simulator menu enabled (press M or use side buttons)')
-- RebirthSystem fires RebirthResult(ok, rebirths, requiredLevel). Its original listener
-- lived in RebirthGui, which was removed when rebirth moved into this menu.
-- It now also carries the price and WHY a refusal happened ("level" / "gold" / "maxed").
rebirthResultRemote.OnClientEvent:Connect(function(ok, rebirths, need, price, reason)
	lastRebirthResult = { ok = ok, rebirths = rebirths, need = need, price = price, reason = reason }
	if panelOpen and activeTab == "Rebirth" then
		buildRebirthPanel()
	end
end)
