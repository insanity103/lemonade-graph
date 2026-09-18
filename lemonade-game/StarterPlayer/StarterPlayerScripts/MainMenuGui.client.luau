local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local spendEvent = remotes:WaitForChild("SpendSkillPoint")
local inventoryAction = remotes:WaitForChild("InventoryAction")
local toggleAutoSellRemote = remotes:WaitForChild("ToggleAutoSell")
local rebirthResultRemote = remotes:WaitForChild("RebirthResult")
local reforgeRemote = remotes:WaitForChild("ReforgeAction")

local WeaponModifiers = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponModifiers"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local SwordValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwordValue"))
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
	{ id = "Reforge", text = "🎰", label = "Reforge", top = Color3.fromRGB(255, 176, 88), bottom = Color3.fromRGB(226, 92, 22) },
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
	chip.Size = UDim2.fromScale(1, 1)
	chip.BackgroundTransparency = 1
	chip.ZIndex = 6
	chip.Parent = topBar
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
	return value
end

-- Level lives on the bottom-left XP badge; this readout holds only gold.
local goldLabel = createChip("GoldChip", ICONS.Coin)

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
local function createNavButton(item, order)
	local button = Instance.new("ImageButton")
	button.Name = item.id
	button.Size = UDim2.fromOffset(NAV_TILE, NAV_TILE)
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.Image = ""
	button.AutoButtonColor = false
	button.LayoutOrder = order
	button.ZIndex = 6
	button.Parent = navRail
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

	local scale = Instance.new("UIScale")
	scale.Name = "PressScale"
	scale.Parent = button
	button.MouseEnter:Connect(function() scale.Scale = 1.07 end)
	button.MouseLeave:Connect(function() scale.Scale = 1 end)
	button.MouseButton1Down:Connect(function() scale.Scale = 0.94 end)
	button.MouseButton1Up:Connect(function() scale.Scale = 1.07 end)
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
		blessed = tool:GetAttribute("ExtraSlot") == true,
		bossDrop = tool:GetAttribute("BossDrop") == true,
		-- Same rule as before: only unequipped boss drops (never the starter sword) can be sold.
		sellable = tool.Name ~= "ClassicSword" and tool:GetAttribute("BossDrop") == true and not item.equipped,
	}
end

local function brightText(parent, props)
	local label = createText(parent, props)
	label.TextColor3 = props.color or BRIGHT.Ink
	return label
end

local buildInventoryPanel

local function detailStatRow(parent, order, icon, labelText, valueText, valueColor)
	local row = Instance.new("Frame")
	row.Name = "Stat_" .. labelText
	row.Size = UDim2.new(1, 0, 0, 40)
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
	local kind = f.bossDrop and "Boss relic" or "Starter sword"
	if f.bossDrop and tool:GetAttribute("BossTier") then kind ..= " · tier " .. tostring(tool:GetAttribute("BossTier")) end
	brightText(tagRow, { text = kind, font = Enum.Font.GothamBold, size = 14, color = BRIGHT.InkMuted, xAlign = Enum.TextXAlignment.Right, size2 = UDim2.new(1, 0, 1, 0), zIndex = 32 })

	-- Hero render on the rarity colour.
	local hero = Instance.new("Frame")
	hero.Name = "Hero"
	hero.Size = UDim2.new(1, 0, 0, narrow and 118 or 150)
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
	PanelChrome.renderTool(heroView, tool, { tiltDeg = 50, margin = 0.9 })
	if item.equipped then
		local b = PanelChrome.checkBadge(hero, 36, 34)
		b.Position = UDim2.new(1, -18, 0, 18)
	end
	if f.blessed then
		PanelChrome.display(hero, { text = "BLESSED", size = 16, color = BRIGHT.Gold, stroke = 2, anchor = Vector2.new(0, 1),
			pos = UDim2.new(0, 10, 1, -6), size2 = UDim2.fromOffset(90, 20), xAlign = Enum.TextXAlignment.Left, zIndex = 34 })
	end

	-- Stats: big outlined numbers, one row each.
	local order = 10
	local function stat(icon, label, value, color)
		detailStatRow(card, order, icon, label, value, color)
		order += 1
	end
	stat(ICONS.Sword, "Damage", string.format("x%.2f", f.damageMult), Color3.fromRGB(255, 255, 255))
	if f.bossDrop then
		stat(ICONS.Trophy, "Rating", SwordValue.short(SwordValue.rateTool(tool)), BRIGHT.Gold)
	end
	if f.bonusDmg > 0 then stat(ICONS.Sword, "Bonus damage", string.format("+%d%%", math.round(f.bonusDmg * 100)), Color3.fromRGB(255, 120, 100)) end
	if f.critChance > 0 then stat(ICONS.Target, "Crit chance", string.format("+%d%%", math.round(f.critChance * 100)), Color3.fromRGB(255, 190, 70)) end
	if f.rangeBonus > 0 then stat(ICONS.Lighting, "Reach", string.format("+%s", tostring(f.rangeBonus)), Color3.fromRGB(120, 205, 255)) end
	if f.knockbackBonus > 0 then stat(ICONS.Shield, "Knockback", string.format("+%d", f.knockbackBonus), Color3.fromRGB(150, 240, 140)) end
	if f.blessed then stat(ICONS.Star, "Blessed", "+1 slot", BRIGHT.Gold) end

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
		local sellButton, sellLabel = PanelChrome.chunkyButton(actions, {
			name = "SellButton", text = "SELL", color = BRIGHT.Gold, colorDark = BRIGHT.GoldDark,
			size = buttonWidth, textSize = 28, zIndex = 33,
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
					sellLabel.Text = "SELL"
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

-- Tile label for long rolled names ("Blessed Precision ... Voidrend Blade"): the last one or
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
	view.Position = UDim2.new(-0.02, 0, -0.2, 0)
	view.Size = UDim2.new(1.16, 0, 1.02, 0)
	view.ZIndex = 26
	view.Parent = tile
	PanelChrome.renderTool(view, tool, { tiltDeg = 45, margin = 0.8 })

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
	if f.blessed then
		local halo = Instance.new("Frame")
		halo.Name = "BlessedHalo"
		halo.BackgroundTransparency = 1
		halo.Position = UDim2.fromOffset(-4, -4)
		halo.Size = UDim2.new(1, 8, 1, 8)
		halo.ZIndex = 23
		halo.Parent = tile
		addCorner(halo, 22)
		PanelChrome.stroke(halo, BRIGHT.Gold, 3)
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

	-- Auto-Sell: a bright blue button with an ON/OFF switch pill, so it reads as pressable
	-- in both states instead of greyed out.
	local autoSellOn = player:GetAttribute("AutoSellLowerSwords") == true
	local toggleH = layout.touch - 2
	local toggleBtn, toggleLabel = PanelChrome.chunkyButton(header, {
		name = "AutoSellToggle", text = "AUTO-SELL",
		color = Color3.fromRGB(110, 196, 255), colorDark = Color3.fromRGB(36, 120, 226),
		size = UDim2.fromOffset(layoutMode == "narrow" and 190 or 220, toggleH),
		anchor = Vector2.new(1, 0.5), pos = UDim2.new(1, -4, 0.5, 0), textSize = 22, zIndex = 24,
	})
	toggleLabel.Size = UDim2.new(1, -78, 1, -6)
	local switch = Instance.new("Frame")
	switch.Name = "State"
	switch.AnchorPoint = Vector2.new(1, 0.5)
	switch.Position = UDim2.new(1, -8, 0.5, 0)
	switch.Size = UDim2.fromOffset(62, toggleH - 16)
	switch.BackgroundColor3 = Color3.new(1, 1, 1)
	switch.ZIndex = 26
	switch.Parent = toggleBtn
	addCorner(switch, 12)
	PanelChrome.stroke(switch, BRIGHT.Outline, 2.5)
	PanelChrome.gradient(switch, autoSellOn and BRIGHT.Green or BRIGHT.Red, autoSellOn and BRIGHT.GreenDark or BRIGHT.RedDark)
	PanelChrome.display(switch, { text = autoSellOn and "ON" or "OFF", size = 20, stroke = 2.5, zIndex = 27 })
	toggleBtn.Activated:Connect(function()
		toggleAutoSellRemote:FireServer()
	end)

	local caption = brightText(body, {
		text = "Auto-Sell sells new drops with fewer modifier slots than your held sword. Tap a sword for its stats.",
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

	local scale = Instance.new("UIScale")
	scale.Parent = btn
	btn.MouseEnter:Connect(function() scale.Scale = 1.05 end)
	btn.MouseLeave:Connect(function()
		scale.Scale = 1
		face.Position = UDim2.fromOffset(0, 0)
	end)
	btn.MouseButton1Down:Connect(function() face.Position = UDim2.fromOffset(0, 5) end)
	btn.MouseButton1Up:Connect(function() face.Position = UDim2.fromOffset(0, 0) end)
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
	up.button.Activated:Connect(function() spendEvent:FireServer(attr.name) end)
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
	local ready = level >= requirement

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
		name = "Text", text = if ready then "READY!" else ("Lv %d / %d"):format(level, requirement),
		size = 20, stroke = 2.5, zIndex = 27,
	})

	local statusText, statusColor
	if lastRebirthResult then
		if lastRebirthResult.ok then
			statusText = ("Rebirth complete! Now rebirth %d"):format(lastRebirthResult.rebirths or rebirths)
			statusColor = Color3.fromRGB(170, 255, 140)
		else
			statusText = ("Not yet! Reach level %d"):format(lastRebirthResult.need or requirement)
			statusColor = Color3.fromRGB(255, 150, 150)
		end
	else
		local left = #milestoneIds - claimedCount
		statusText = if left > 0 then ("%d perk%s left to unlock"):format(left, left == 1 and "" or "s") else "Every perk unlocked!"
		statusColor = Color3.new(1, 1, 1)
	end
	PanelChrome.display(hero, {
		name = "Status", text = statusText, size = 17, color = statusColor, stroke = 2.5, scaled = true, minSize = 12,
		xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(textX + 2, 62), size2 = UDim2.new(1, -(textX + rightW + 2), 0, 20), zIndex = 26,
	})

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
		name = "Label", text = if ready then "REBIRTH!" else "REBIRTH", size = 30, stroke = 3, scaled = true, minSize = 16, zIndex = 29,
		pos = UDim2.fromOffset(textLeft, if ready then 4 else 2), size2 = UDim2.new(1, -(textLeft + 6), if ready then 1 else 0.6, if ready then -8 else 0),
	})
	if not ready then
		PanelChrome.display(face, {
			name = "Need", text = ("Reach Lv %d"):format(requirement), size = 16, stroke = 2, scaled = true, minSize = 11, zIndex = 29,
			pos = UDim2.new(0, textLeft, 0.58, -2), size2 = UDim2.new(1, -(textLeft + 6), 0.36, 0),
		})
	end
	local press = Instance.new("UIScale")
	press.Parent = rebirthButton
	rebirthButton.MouseEnter:Connect(function() press.Scale = 1.04 end)
	rebirthButton.MouseLeave:Connect(function()
		press.Scale = 1
		face.Position = UDim2.fromOffset(0, 0)
	end)
	rebirthButton.MouseButton1Down:Connect(function() face.Position = UDim2.fromOffset(0, 4) end)
	rebirthButton.MouseButton1Up:Connect(function() face.Position = UDim2.fromOffset(0, 0) end)
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
--  TRADE TAB: pick a player from the lobby, then build an offer side by side
-- ═══════════════════════════════════════════════════════════════════════════
local tradeRemote = remotes:WaitForChild("TradeAction")
local tradeState = { players = {}, incoming = nil, session = nil }
local TRADE_RARITY = {
	Common = Color3.fromRGB(180, 180, 180), Uncommon = Color3.fromRGB(80, 200, 120), Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(180, 80, 240), Legendary = Color3.fromRGB(255, 200, 40),
}

local function tradeCard(order, height)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, height)
	card.BackgroundColor3 = COLORS.PanelLight
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.ZIndex = 23
	card.Parent = body
	addCorner(card, 12)
	addStroke(card, COLORS.Stroke, 0.4, 1)
	addPadding(card, 8, 12, 8, 12)
	return card
end

local function tradeButton(parent, text, color, pos, size, onClick)
	local btn = Instance.new("TextButton")
	btn.Size = size or UDim2.fromOffset(92, 30)
	btn.Position = pos
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.TextColor3 = COLORS.Text
	btn.Text = text
	btn.ZIndex = 24
	btn.Parent = parent
	addCorner(btn, 8)
	btn.Activated:Connect(onClick)
	return btn
end

local function swordLine(card, info, y, withButton, buttonText, buttonColor, onClick)
	createText(card, { text = info.name, font = Enum.Font.GothamBold, size = 13, color = TRADE_RARITY[info.rarity] or COLORS.Text,
		pos = UDim2.fromOffset(0, y), size2 = UDim2.new(1, -110, 0, 16), zIndex = 24 })
	createText(card, { text = string.format("%s · %s · rating %s", info.rarity, info.prefixes ~= "" and info.prefixes or "no modifiers",
		SwordValue.short(info.rating or 0)), font = Enum.Font.Gotham, size = 11, color = COLORS.Muted,
		pos = UDim2.fromOffset(0, y + 16), size2 = UDim2.new(1, -110, 0, 14), zIndex = 24 })
	if withButton then
		tradeButton(card, buttonText, buttonColor, UDim2.new(1, 0, 0, y + 15), UDim2.fromOffset(84, 28), onClick)
	end
end

local function buildTradeLobby(order)
	if tradeState.incoming then
		local card = tradeCard(order, 64); order += 1
		createText(card, { text = tradeState.incoming.name .. " wants to trade with you", font = Enum.Font.GothamBold, size = 14,
			color = COLORS.Gold, size2 = UDim2.new(1, -200, 0, 24), zIndex = 24 })
		createText(card, { text = "Accept to open the trade window.", font = Enum.Font.Gotham, size = 11, color = COLORS.Muted,
			pos = UDim2.fromOffset(0, 24), size2 = UDim2.new(1, -200, 0, 16), zIndex = 24 })
		local fromId = tradeState.incoming.userId
		tradeButton(card, "Accept", COLORS.Success, UDim2.new(1, -96, 0.5, 0), UDim2.fromOffset(88, 30), function()
			tradeRemote:FireServer("Accept", fromId)
		end)
		tradeButton(card, "Decline", COLORS.Button, UDim2.new(1, 0, 0.5, 0), UDim2.fromOffset(88, 30), function()
			tradeRemote:FireServer("Decline", fromId)
		end)
	end
	local head = tradeCard(order, 40); order += 1
	createText(head, { text = "Players in this server", font = Enum.Font.GothamBold, size = 14, color = COLORS.Text,
		size2 = UDim2.new(1, -100, 1, 0), zIndex = 24 })
	tradeButton(head, "Refresh", COLORS.Button, UDim2.new(1, 0, 0.5, 0), UDim2.fromOffset(84, 26), function()
		tradeRemote:FireServer("Refresh")
	end)
	if #tradeState.players == 0 then
		local card = tradeCard(order, 48); order += 1
		createText(card, { text = "Nobody else is here yet. Trades need another player in the server.", font = Enum.Font.Gotham,
			size = 12, color = COLORS.Muted, wrap = true, size2 = UDim2.new(1, 0, 1, 0), zIndex = 24 })
	end
	for _, info in ipairs(tradeState.players) do
		local card = tradeCard(order, 56); order += 1
		createText(card, { text = info.name, font = Enum.Font.GothamBold, size = 14, color = COLORS.Text,
			size2 = UDim2.new(1, -110, 0, 20), zIndex = 24 })
		createText(card, { text = string.format("Level %d · Wealth %s%s", info.level, SwordValue.short(info.wealth or 0),
			info.busy and " · trading" or ""), font = Enum.Font.Gotham, size = 11, color = COLORS.Muted,
			pos = UDim2.fromOffset(0, 22), size2 = UDim2.new(1, -110, 0, 16), zIndex = 24 })
		if not info.busy then
			local userId = info.userId
			tradeButton(card, "Trade", COLORS.Success, UDim2.new(1, 0, 0.5, 0), UDim2.fromOffset(84, 30), function()
				tradeRemote:FireServer("Request", userId)
			end)
		end
	end
	return order
end

local function buildTradeSession(order)
	local st = tradeState.session
	local status = tradeCard(order, 60); order += 1
	createText(status, { text = "Trading with " .. st.partnerName, font = Enum.Font.GothamBold, size = 15, color = COLORS.Gold,
		size2 = UDim2.new(1, -110, 0, 22), zIndex = 24 })
	local mine = st.myConfirmed and "You: confirmed" or "You: not confirmed"
	local theirs = st.theirConfirmed and (st.partnerName .. ": confirmed") or (st.partnerName .. ": waiting")
	createText(status, { text = mine .. "  ·  " .. theirs, font = Enum.Font.Gotham, size = 11, color = COLORS.Muted,
		pos = UDim2.fromOffset(0, 24), size2 = UDim2.new(1, -110, 0, 16), zIndex = 24 })
	tradeButton(status, "Cancel", COLORS.Error, UDim2.new(1, 0, 0.5, 0), UDim2.fromOffset(84, 30), function()
		tradeRemote:FireServer("Cancel")
	end)

	local function section(title, rows, emptyText, withButton, buttonText, buttonColor, action)
		local card = tradeCard(order, 30 + math.max(#rows, 1) * 36 + 6); order += 1
		createText(card, { text = title, font = Enum.Font.GothamBold, size = 13, color = COLORS.Text,
			size2 = UDim2.new(1, 0, 0, 20), zIndex = 24 })
		if #rows == 0 then
			createText(card, { text = emptyText, font = Enum.Font.Gotham, size = 11, color = COLORS.Muted,
				pos = UDim2.fromOffset(0, 24), size2 = UDim2.new(1, 0, 0, 16), zIndex = 24 })
		end
		for i, info in ipairs(rows) do
			local key = info.key
			swordLine(card, info, 22 + (i - 1) * 36, withButton, buttonText, buttonColor, function()
				tradeRemote:FireServer(action, key)
			end)
		end
	end
	-- Your side shows everything you own (carried and vaulted); theirs shows only their offer.
	section(string.format("Your offer (%d / %d)", #st.mine, st.maxOffer or 6), st.mine,
		"Add swords from your inventory or vault below.", true, "Remove", COLORS.Button, "Offer")
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
	section("Your inventory", unoffered(st.carried), "No relic swords on you.", true, "Add", COLORS.Success, "Offer")
	section("Your vault", unoffered(st.vaulted), "Nothing stored with the Vaultkeeper.", true, "Add", COLORS.Success, "Offer")

	local confirmCard = tradeCard(order, 52); order += 1
	createText(confirmCard, { text = st.myConfirmed and "Waiting for " .. st.partnerName .. " to confirm..." or
		"Check both offers, then confirm.", font = Enum.Font.Gotham, size = 12, color = COLORS.Muted,
		size2 = UDim2.new(1, -120, 1, 0), zIndex = 24 })
	if not st.myConfirmed then
		tradeButton(confirmCard, "Confirm", COLORS.Success, UDim2.new(1, 0, 0.5, 0), UDim2.fromOffset(100, 34), function()
			tradeRemote:FireServer("Confirm")
		end)
	end
	return order
end

local function buildTradePanel()
	clearBody()
	headerTitle.Text = "Trade"
	local order = 1
	if tradeState.session then
		buildTradeSession(order)
	else
		buildTradeLobby(order)
	end
end

local function buildSettingsPanel()
	clearBody()
	headerTitle.Text = "Settings"
	local order = 0

	-- ── helper: create a row with label on top, description below ──
	local function createSettingRow(height, layoutOrder)
		order += 1
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, height)
		row.BackgroundColor3 = COLORS.PanelLight
		row.BackgroundTransparency = 0.08
		row.BorderSizePixel = 0
		row.LayoutOrder = layoutOrder
		row.ZIndex = 23
		row.Parent = body
		addCorner(row, 12)
		addStroke(row, COLORS.Stroke, 0.4, 1)
		return row
	end

	-- ═══════════════════════════════════════════════
	--  2. MUSIC VOLUME SLIDER
	-- ═══════════════════════════════════════════════
	local musicVolume = player:GetAttribute("MusicVolume")
	if musicVolume == nil then musicVolume = 0.5 end
	local volRow = createSettingRow(72, 2)
	addPadding(volRow, 6, 12, 6, 12)

	local volIcon = Instance.new("ImageLabel")
	volIcon.Size = UDim2.fromOffset(24, 24)
	volIcon.Position = UDim2.fromOffset(2, 10)
	volIcon.BackgroundTransparency = 1
	volIcon.Image = ICONS.Lighting
	volIcon.ScaleType = Enum.ScaleType.Fit
	volIcon.ZIndex = 24
	volIcon.Parent = volRow

	createText(volRow, {
		text = "Music Volume",
		font = Enum.Font.GothamBold,
		size = 14,
		color = COLORS.Text,
		pos = UDim2.fromOffset(34, 4),
		size2 = UDim2.new(1, -50, 0, 18),
		zIndex = 24
	})

	local volValueLabel = createText(volRow, {
		text = tostring(math.round(musicVolume * 100)) .. "%",
		font = Enum.Font.GothamBold,
		size = 14,
		color = COLORS.Muted,
		xAlign = Enum.TextXAlignment.Right,
		pos = UDim2.fromOffset(0, 4),
		size2 = UDim2.new(1, -12, 0, 18),
		zIndex = 24
	})

	-- Slider track
	local sliderTrack = Instance.new("Frame")
	sliderTrack.Name = "SliderTrack"
	sliderTrack.Size = UDim2.new(1, -32, 0, 8)
	sliderTrack.Position = UDim2.fromOffset(0, 40)
	sliderTrack.BackgroundColor3 = COLORS.Accent
	sliderTrack.BorderSizePixel = 0
	sliderTrack.ZIndex = 24
	sliderTrack.Parent = volRow
	addCorner(sliderTrack, 4)

	-- Slider fill
	local sliderFill = Instance.new("Frame")
	sliderFill.Name = "SliderFill"
	sliderFill.Size = UDim2.new(musicVolume, 0, 1, 0)
	sliderFill.BackgroundColor3 = COLORS.Success
	sliderFill.BorderSizePixel = 0
	sliderFill.ZIndex = 25
	sliderFill.Parent = sliderTrack
	addCorner(sliderFill, 4)

	-- Slider knob
	local sliderKnob = Instance.new("Frame")
	sliderKnob.Name = "SliderKnob"
	sliderKnob.Size = UDim2.fromOffset(18, 18)
	sliderKnob.Position = UDim2.new(musicVolume, -9, 0.5, -9)
	sliderKnob.BackgroundColor3 = COLORS.Text
	sliderKnob.BorderSizePixel = 0
	sliderKnob.ZIndex = 26
	sliderKnob.Parent = sliderTrack
	addCorner(sliderKnob, 9)

	-- Invisible drag target wider than the track for easier clicking
	local sliderHitArea = Instance.new("TextButton")
	sliderHitArea.Name = "SliderHitArea"
	sliderHitArea.Size = UDim2.new(1, 16, 0, 28)
	sliderHitArea.Position = UDim2.fromOffset(-8, -10)
	sliderHitArea.BackgroundTransparency = 1
	sliderHitArea.Text = ""
	sliderHitArea.BorderSizePixel = 0
	sliderHitArea.ZIndex = 27
	sliderHitArea.Parent = sliderTrack
	sliderHitArea.AutoButtonColor = false

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
		sliderFill.Size = UDim2.new(musicVolume, 0, 1, 0)
		sliderKnob.Position = UDim2.new(musicVolume, -9, 0.5, -9)
		volValueLabel.Text = tostring(math.round(musicVolume * 100)) .. "%"
	end

	-- Drag handling
	local dragging = false
	local function updateSliderFromMouse(inputX)
		local absPos = sliderTrack.AbsolutePosition.X
		local absSize = sliderTrack.AbsoluteSize.X
		if absSize <= 0 then return end
		local fraction = math.clamp((inputX - absPos) / absSize, 0, 1)
		applyVolume(fraction)
	end

	sliderHitArea.MouseButton1Down:Connect(function(x)
		dragging = true
		updateSliderFromMouse(x)
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateSliderFromMouse(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	-- ═══════════════════════════════════════════════
	--  3. SHOW DAMAGE NUMBERS TOGGLE
	-- ═══════════════════════════════════════════════
	local showDmgOn = player:GetAttribute("ShowDamageNumbers")
	if showDmgOn == nil then showDmgOn = true end
	local dmgRow = createSettingRow(56, 3)
	addPadding(dmgRow, 6, 12, 6, 12)

	local dmgIcon = Instance.new("ImageLabel")
	dmgIcon.Size = UDim2.fromOffset(24, 24)
	dmgIcon.Position = UDim2.fromOffset(2, 10)
	dmgIcon.BackgroundTransparency = 1
	dmgIcon.Image = ICONS.Sword
	dmgIcon.ScaleType = Enum.ScaleType.Fit
	dmgIcon.ZIndex = 24
	dmgIcon.Parent = dmgRow

	createText(dmgRow, {
		text = "Show Damage Numbers",
		font = Enum.Font.GothamBold,
		size = 14,
		color = COLORS.Text,
		pos = UDim2.fromOffset(34, 4),
		size2 = UDim2.new(1, -145, 0, 18),
		zIndex = 24
	})

	createText(dmgRow, {
		text = "Floating combat text above enemies",
		font = Enum.Font.Gotham,
		size = 11,
		color = COLORS.Muted,
		pos = UDim2.fromOffset(34, 24),
		size2 = UDim2.new(1, -145, 0, 18),
		wrap = true,
		zIndex = 24
	})

	local dmgToggleBtn = Instance.new("TextButton")
	dmgToggleBtn.Size = UDim2.fromOffset(100, 32)
	dmgToggleBtn.Position = UDim2.new(1, -100, 0.5, -16)
	dmgToggleBtn.BackgroundColor3 = showDmgOn and COLORS.Success or COLORS.Button
	dmgToggleBtn.BorderSizePixel = 0
	dmgToggleBtn.Font = Enum.Font.GothamBold
	dmgToggleBtn.TextColor3 = showDmgOn and Color3.fromRGB(15, 20, 15) or COLORS.Text
	dmgToggleBtn.TextSize = 13
	dmgToggleBtn.Text = showDmgOn and "ON (ACTIVE)" or "OFF"
	dmgToggleBtn.ZIndex = 24
	dmgToggleBtn.Parent = dmgRow
	dmgToggleBtn.AutoButtonColor = false
	addCorner(dmgToggleBtn, 8)
	addStroke(dmgToggleBtn, showDmgOn and Color3.fromRGB(120, 255, 170) or COLORS.StrokeBright, 0.3, 1)

	dmgToggleBtn.MouseEnter:Connect(function()
		dmgToggleBtn.BackgroundColor3 = showDmgOn and Color3.fromRGB(100, 230, 155) or COLORS.ButtonHover
	end)
	dmgToggleBtn.MouseLeave:Connect(function()
		dmgToggleBtn.BackgroundColor3 = showDmgOn and COLORS.Success or COLORS.Button
	end)

	local function updateDmgToggleVisual(on)
		dmgToggleBtn.Text = on and "ON (ACTIVE)" or "OFF"
		dmgToggleBtn.TextColor3 = on and Color3.fromRGB(15, 20, 15) or COLORS.Text
		dmgToggleBtn.BackgroundColor3 = on and COLORS.Success or COLORS.Button
		addStroke(dmgToggleBtn, on and Color3.fromRGB(120, 255, 170) or COLORS.StrokeBright, 0.3, 1)
	end

	dmgToggleBtn.Activated:Connect(function()
		showDmgOn = not showDmgOn
		player:SetAttribute("ShowDamageNumbers", showDmgOn)
		updateDmgToggleVisual(showDmgOn)
	end)

	-- ═══════════════════════════════════════════════
	--  4. KEYBOARD SHORTCUTS REFERENCE
	-- ═══════════════════════════════════════════════
	local shortcuts = {
		{ key = "M", desc = "Open / close menu" },
		{ key = "E", desc = "Attack" },
		{ key = "Click", desc = "Attack" },
		{ key = "Esc", desc = "Close the open panel" },
	}

	local shortcutsHeader = createText(body, {
		text = "Keyboard Shortcuts",
		font = Enum.Font.GothamBold,
		size = 16,
		color = COLORS.Text,
		size2 = UDim2.new(1, 0, 0, 24),
		zIndex = 23,
	})
	shortcutsHeader.LayoutOrder = 4

	for i, sc in ipairs(shortcuts) do
		local scRow = Instance.new("Frame")
		scRow.Size = UDim2.new(1, 0, 0, 32)
		scRow.BackgroundColor3 = COLORS.PanelLight
		scRow.BackgroundTransparency = 0.15
		scRow.BorderSizePixel = 0
		scRow.LayoutOrder = 4 + i
		scRow.ZIndex = 23
		scRow.Parent = body
		addCorner(scRow, 8)
		addPadding(scRow, 0, 10, 0, 10)

		local keyBadge = Instance.new("Frame")
		keyBadge.Size = UDim2.fromOffset(52, 22)
		keyBadge.Position = UDim2.fromOffset(0, 5)
		keyBadge.BackgroundColor3 = COLORS.Accent
		keyBadge.BorderSizePixel = 0
		keyBadge.ZIndex = 24
		keyBadge.Parent = scRow
		addCorner(keyBadge, 6)
		addStroke(keyBadge, COLORS.StrokeBright, 0.3, 1)

		local keyLabel = Instance.new("TextLabel")
		keyLabel.BackgroundTransparency = 1
		keyLabel.Size = UDim2.fromScale(1, 1)
		keyLabel.Font = Enum.Font.GothamBold
		keyLabel.TextSize = 13
		keyLabel.TextColor3 = COLORS.Text
		keyLabel.TextXAlignment = Enum.TextXAlignment.Center
		keyLabel.TextYAlignment = Enum.TextYAlignment.Center
		keyLabel.Text = sc.key
		keyLabel.ZIndex = 25
		keyLabel.Parent = keyBadge

		createText(scRow, {
			text = sc.desc,
			font = Enum.Font.Gotham,
			size = 13,
			color = COLORS.Muted,
			pos = UDim2.fromOffset(62, 0),
			size2 = UDim2.new(1, -62, 1, 0),
			zIndex = 24,
		})
	end
end

local function refreshTopBar()
	-- Short form (31.2K) so a big purse never shrinks the TextScaled chip into unreadable digits.
	goldLabel.Text = NumberFormat.short(player:GetAttribute('Gold') or 0)
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
	for id, btn in pairs(railButtons) do
		local selected = id == tabId
		btn.BackgroundTransparency = selected and 0 or 1
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Transparency = selected and 0 or 1 end
	end
	setWellTheme(tabId == 'Inventory' or tabId == 'Skills' or tabId == 'Rebirth')
	if tabId ~= 'Inventory' then inventorySelection = nil end
	if tabId == 'Inventory' then buildInventoryPanel()
	elseif tabId == 'Skills' then buildSkillsPanel(); refreshSkills()
	elseif tabId == 'Rebirth' then buildRebirthPanel()
	elseif tabId == 'Trade' then buildTradePanel(); tradeRemote:FireServer("Refresh")
	elseif tabId == 'Settings' then buildSettingsPanel() end
end


local function setMenuOpen(open)
	if panelOpen == open then return end
	panelOpen = open
	refreshNavSelection()
	overlay.Visible = open
	contentPanel.Visible = open
	TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = open and 0.5 or 1 }):Play()
	if not open then
		inventorySelection = nil
		closeInventoryDetail()
	end
	if open and not activeTab then openTab('Inventory') end
	if open and activeTab == 'Inventory' then buildInventoryPanel() end
end

local function toggleMenu() setMenuOpen(not panelOpen) end

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
for _, tab in ipairs({ "Skills", "Rebirth", "Trade", "Settings" }) do
	GuiShowcase.register(tab, function()
		setMenuOpen(true)
		openTab(tab)
	end)
end

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

-- Talking to the Keeper of Renewal at the hub's rebirth pavilion opens this panel on
-- the Rebirth tab. It only opens the panel: the existing confirm button and
-- RebirthSystem keep sole authority over requirements and the rebirth itself.
task.spawn(function()
	local stationOpen = remotes:WaitForChild("RebirthStationOpen", 30)
	if not stationOpen then return end
	stationOpen.OnClientEvent:Connect(function()
		setMenuOpen(true)
		openTab("Rebirth")
		headerTitle.Text = "Keeper of Renewal"
	end)
end)

for i, item in ipairs(NAV_ITEMS) do
	local btn = createNavButton(item, i)
	btn.Activated:Connect(function()
		if item.id == "Reforge" then
			setMenuOpen(false)
			reforgeRemote:FireServer("Open")
			return
		end
		if panelOpen and activeTab == item.id then setMenuOpen(false)
		else setMenuOpen(true); openTab(item.id) end
	end)
	navButtons[item.id] = btn
end
refreshNavSelection()
refreshRailBadges()

closeBtn.Activated:Connect(function() setMenuOpen(false) end)
overlay.Activated:Connect(function() setMenuOpen(false) end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.M then toggleMenu() end
end)

local attrsToWatch = { 'Gold', 'SkillPoints', 'Strength', 'Health', 'Defense', 'ExperienceGain', 'AutoSellLowerSwords', 'Rebirths', 'RebirthRequirement', 'ShowDamageNumbers', 'MusicVolume' }
for _, attr in ipairs(attrsToWatch) do
	player:GetAttributeChangedSignal(attr):Connect(function()
		refreshTopBar(); refreshSkills()
		if attr == 'SkillPoints' then refreshRailBadges() end
		if attr == 'AutoSellLowerSwords' and activeTab == 'Inventory' and panelOpen then
			buildInventoryPanel()
		elseif (attr == 'Rebirths' or attr == 'RebirthRequirement') and activeTab == 'Rebirth' and panelOpen then
			buildRebirthPanel()
		elseif (attr == 'ShowDamageNumbers' or attr == 'MusicVolume') and activeTab == 'Settings' and panelOpen then
			buildSettingsPanel()
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
rebirthResultRemote.OnClientEvent:Connect(function(ok, rebirths, need)
	lastRebirthResult = { ok = ok, rebirths = rebirths, need = need }
	if panelOpen and activeTab == "Rebirth" then
		buildRebirthPanel()
	end
end)
