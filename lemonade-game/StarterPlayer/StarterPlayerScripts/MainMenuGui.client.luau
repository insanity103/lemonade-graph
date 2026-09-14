local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local spendEvent = remotes:WaitForChild("SpendSkillPoint")
local inventoryUpdated = remotes:WaitForChild("InventoryUpdated")
local inventoryAction = remotes:WaitForChild("InventoryAction")
local toggleAutoSellRemote = remotes:WaitForChild("ToggleAutoSell")
local rebirthResultRemote = remotes:WaitForChild("RebirthResult")

local WeaponModifiers = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponModifiers"))

local ICONS = {
	Home = "rbxassetid://95064026158349",
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

local NAV_ITEMS = {
	{ id = "Home", icon = ICONS.Home },
	{ id = "Inventory", icon = ICONS.Inventory },
	{ id = "Skills", icon = ICONS.Skills },
	{ id = "Rebirth", icon = "rbxassetid://80234316052758" },
	{ id = "Settings", icon = ICONS.Settings },
}

local existing = playerGui:FindFirstChild("MainMenuGui")
if existing then existing:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainMenuGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

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

local function createIconButton(parent, props)
	local button = Instance.new("ImageButton")
	button.Name = props.name or "IconButton"
	button.Size = props.size or UDim2.fromOffset(52, 52)
	button.Position = props.pos or UDim2.fromOffset(0, 0)
	button.BackgroundColor3 = props.bg or COLORS.PanelLight
	button.BackgroundTransparency = props.bgTransparency or 0.15
	button.BorderSizePixel = 0
	button.Image = props.image or ""
	button.ScaleType = Enum.ScaleType.Fit
	button.AutoButtonColor = false
	button.ZIndex = props.zIndex or 2
	button.Parent = parent
	addCorner(button, 14)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = button
	return button
end

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(1, 1)
topBar.Position = UDim2.new(1, -12, 0.5, -166)
topBar.Size = UDim2.fromOffset(64, 88)
topBar.BackgroundColor3 = COLORS.Panel
topBar.BackgroundTransparency = 0.08
topBar.BorderSizePixel = 0
topBar.ZIndex = 5
topBar.Parent = screenGui
addCorner(topBar, 12)
addStroke(topBar, COLORS.Stroke)
local topLayout = Instance.new("UIListLayout")
topLayout.FillDirection = Enum.FillDirection.Vertical
topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
topLayout.Padding = UDim.new(0, 8)
topLayout.Parent = topBar
addPadding(topBar, 8, 8, 8, 8)

local function createChip(name, icon)
	local chip = Instance.new("Frame")
	chip.Name = name
	chip.Size = UDim2.new(1, 0, 0, 32)
	chip.BackgroundColor3 = COLORS.PanelLight
	chip.BackgroundTransparency = 0.2
	chip.BorderSizePixel = 0
	chip.ZIndex = 6
	chip.Parent = topBar
	addCorner(chip, 8)
	local iconImg = Instance.new("ImageLabel")
	iconImg.Size = UDim2.fromOffset(20, 20)
	iconImg.Position = UDim2.fromOffset(4, 6)
	iconImg.BackgroundTransparency = 1
	iconImg.Image = icon
	iconImg.ScaleType = Enum.ScaleType.Fit
	iconImg.ZIndex = 7
	iconImg.Parent = chip
	local value = createText(chip, { text = "0", font = Enum.Font.GothamBold, size = 15, pos = UDim2.fromOffset(26, 0), size2 = UDim2.new(1, -30, 1, 0), zIndex = 7 })
	value.Name = "Value"
	value.TextScaled = true
	value.TextXAlignment = Enum.TextXAlignment.Left
	return value
end

local goldLabel = createChip("GoldChip", ICONS.Coin)
local levelChipLabel = createChip("LevelChip", ICONS.Trophy)

local navRail = Instance.new("Frame")
navRail.Name = "NavRail"
navRail.AnchorPoint = Vector2.new(1, 0.5)
navRail.Position = UDim2.new(1, -12, 0.5, 58)
navRail.Size = UDim2.fromOffset(64, 340)
navRail.BackgroundColor3 = COLORS.Panel
navRail.BackgroundTransparency = 0.08
navRail.BorderSizePixel = 0
navRail.ZIndex = 5
navRail.Parent = screenGui
addCorner(navRail, 16)
addStroke(navRail, COLORS.Stroke)
addPadding(navRail, 10, 6, 10, 6)
local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Vertical
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navLayout.Padding = UDim.new(0, 8)
navLayout.Parent = navRail

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
overlay.Parent = screenGui

local contentPanel = Instance.new("Frame")
contentPanel.Name = "ContentPanel"
contentPanel.AnchorPoint = Vector2.new(0.5, 0.5)
contentPanel.Position = UDim2.fromScale(0.5, 0.5)
contentPanel.Size = UDim2.fromOffset(460, 530)
contentPanel.BackgroundColor3 = COLORS.Panel
contentPanel.BackgroundTransparency = 0.04
contentPanel.BorderSizePixel = 0
contentPanel.Visible = false
contentPanel.ZIndex = 21
contentPanel.Parent = screenGui
addCorner(contentPanel, 18)
addStroke(contentPanel, COLORS.StrokeBright, 0.2, 1.5)

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 56)
header.BackgroundTransparency = 1
header.ZIndex = 22
header.Parent = contentPanel
addPadding(header, 12, 12, 0, 16)

local headerTitle = createText(header, { name = "Title", text = "Menu", font = Enum.Font.GothamBold, size = 20, color = COLORS.Text, size2 = UDim2.new(1, -44, 1, 0), zIndex = 23 })
local closeBtn = createIconButton(header, { name = "Close", image = ICONS.Close, size = UDim2.fromOffset(36, 36), pos = UDim2.new(1, -36, 0, 0), bg = COLORS.PanelLight, zIndex = 23 })

local body = Instance.new("ScrollingFrame")
body.Name = "Body"
body.Position = UDim2.fromOffset(0, 56)
body.Size = UDim2.new(1, 0, 1, -56)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 5
body.ScrollBarImageColor3 = COLORS.StrokeBright
body.CanvasSize = UDim2.fromOffset(0, 0)
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.ZIndex = 22
body.Parent = contentPanel
addPadding(body, 0, 16, 16, 16)
local bodyLayout = Instance.new("UIListLayout")
bodyLayout.Padding = UDim.new(0, 12)
bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
bodyLayout.Parent = body

local activeTab = nil
local panelOpen = false
local homeStatLabels = {}
local latestInventory = {}
local skillButtons = {}

local function clearBody()
	for _, child in ipairs(body:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end
	end
end

local function createStatRow(label, value, order)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 44)
	row.BackgroundColor3 = COLORS.PanelLight
	row.BackgroundTransparency = 0.15
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.ZIndex = 23
	row.Parent = body
	addCorner(row, 10)
	addStroke(row, COLORS.Stroke, 0.4, 1)
	addPadding(row, 0, 12, 0, 12)
	createText(row, { text = label, font = Enum.Font.Gotham, size = 15, color = COLORS.Muted, size2 = UDim2.new(0.55, 0, 1, 0), zIndex = 24 })
	return createText(row, { text = value, font = Enum.Font.GothamBold, size = 16, color = COLORS.Text, xAlign = Enum.TextXAlignment.Right, size2 = UDim2.new(0.45, 0, 1, 0), pos = UDim2.fromScale(0.55, 0), zIndex = 24 })
end

local function buildHomePanel()
	clearBody()
	headerTitle.Text = "SMASH SIMULATOR"
	local hero = Instance.new("Frame")
	hero.Size = UDim2.new(1, 0, 0, 96)
	hero.BackgroundColor3 = COLORS.PanelLight
	hero.BackgroundTransparency = 0.1
	hero.BorderSizePixel = 0
	hero.LayoutOrder = 1
	hero.ZIndex = 23
	hero.Parent = body
	addCorner(hero, 14)
	addStroke(hero, COLORS.StrokeBright, 0.3, 1)

	createText(hero, { text = "SMASH", font = Enum.Font.GothamBlack, size = 32, color = COLORS.Text, pos = UDim2.fromOffset(16, 12), size2 = UDim2.new(1, -32, 0, 36), zIndex = 24 })
	createText(hero, { text = "Break enemies. Level up. Get stronger.", font = Enum.Font.Gotham, size = 14, color = COLORS.Muted, pos = UDim2.fromOffset(16, 50), size2 = UDim2.new(1, -32, 0, 36), wrap = true, zIndex = 24 })

	local statsHeader = createText(body, { text = "Your Stats", font = Enum.Font.GothamBold, size = 16, color = COLORS.Text, size2 = UDim2.new(1, 0, 0, 24), zIndex = 23 })
	statsHeader.LayoutOrder = 2
	local rows = {
		{ "Level", "1" },
		{ "Gold", tostring(player:GetAttribute("Gold") or 0) },
		{ "Strength", tostring(player:GetAttribute("Strength") or 0) },
		{ "Skill Points", tostring(player:GetAttribute("SkillPoints") or 0) },
	}
	local statLabels = {}
	for i, row in ipairs(rows) do statLabels[row[1]] = createStatRow(row[1], row[2], 2 + i) end
	local tip = createText(body, { text = "Start with Iron Lowlands: defeat a few enemies, spend Skill Points, then follow the level gates. Q auto-attacks; P optionally auto-spends skills.", font = Enum.Font.Gotham, size = 13, color = COLORS.Muted, wrap = true, size2 = UDim2.new(1, 0, 0, 48), zIndex = 23 })
	tip.LayoutOrder = 20
	return statLabels
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

local function buildInventoryPanel(snapshot)
	clearBody()
	headerTitle.Text = "Inventory & Equipment"
	
	local order = 1

	-- Auto-Sell Toggle Banner
	local autoSellOn = player:GetAttribute("AutoSellLowerSwords") == true
	local autoSellBanner = Instance.new("Frame")
	autoSellBanner.Size = UDim2.new(1, 0, 0, 56)
	autoSellBanner.BackgroundColor3 = autoSellOn and Color3.fromRGB(30, 48, 36) or COLORS.PanelLight
	autoSellBanner.BackgroundTransparency = 0.08
	autoSellBanner.BorderSizePixel = 0
	autoSellBanner.LayoutOrder = order
	autoSellBanner.ZIndex = 23
	autoSellBanner.Parent = body
	addCorner(autoSellBanner, 12)
	addStroke(autoSellBanner, autoSellOn and Color3.fromRGB(90, 220, 140) or COLORS.Stroke, 0.25, 1.2)
	addPadding(autoSellBanner, 6, 12, 6, 12)
	order += 1

	local bannerIcon = Instance.new("ImageLabel")
	bannerIcon.Size = UDim2.fromOffset(24, 24)
	bannerIcon.Position = UDim2.fromOffset(2, 10)
	bannerIcon.BackgroundTransparency = 1
	bannerIcon.Image = ICONS.Coin
	bannerIcon.ScaleType = Enum.ScaleType.Fit
	bannerIcon.ZIndex = 24
	bannerIcon.Parent = autoSellBanner

	createText(autoSellBanner, {
		text = "Auto-Sell Fewer-Slot Drops",
		font = Enum.Font.GothamBold,
		size = 14,
		color = COLORS.Text,
		pos = UDim2.fromOffset(34, 4),
		size2 = UDim2.new(1, -145, 0, 18),
		zIndex = 24
	})

	createText(autoSellBanner, {
		text = "Auto sells drops with fewer modifier slots than your held sword",
		font = Enum.Font.Gotham,
		size = 11,
		color = COLORS.Muted,
		pos = UDim2.fromOffset(34, 24),
		size2 = UDim2.new(1, -145, 0, 18),
		wrap = true,
		zIndex = 24
	})

	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Size = UDim2.fromOffset(100, 32)
	toggleBtn.Position = UDim2.new(1, -100, 0.5, -16)
	toggleBtn.BackgroundColor3 = autoSellOn and COLORS.Success or COLORS.Button
	toggleBtn.BorderSizePixel = 0
	toggleBtn.Font = Enum.Font.GothamBold
	toggleBtn.TextColor3 = autoSellOn and Color3.fromRGB(15, 20, 15) or COLORS.Text
	toggleBtn.TextSize = 13
	toggleBtn.Text = autoSellOn and "ON (ACTIVE)" or "OFF"
	toggleBtn.ZIndex = 24
	toggleBtn.Parent = autoSellBanner
	addCorner(toggleBtn, 8)
	addStroke(toggleBtn, autoSellOn and Color3.fromRGB(120, 255, 170) or COLORS.StrokeBright, 0.3, 1)

	toggleBtn.Activated:Connect(function()
		toggleAutoSellRemote:FireServer()
	end)

	local carriedTools = getCarriedTools()

	-- Section 1: Weapons & Equipment
	if #carriedTools > 0 then
		local eqHeader = createText(body, { text = "Equipped & Carried Weapons", font = Enum.Font.GothamBold, size = 16, color = COLORS.Text, size2 = UDim2.new(1, 0, 0, 24), zIndex = 23 })
		eqHeader.LayoutOrder = order
		order += 1

		for _, item in ipairs(carriedTools) do
			local tool = item.tool
			local rarity = tool:GetAttribute("Rarity") or "Common"
			local damageMult = tool:GetAttribute("DamageMult") or 1
			local bonusDmg = tool:GetAttribute("BonusDamagePct") or 0
			local critChance = tool:GetAttribute("CritChance") or 0
			local rangeBonus = tool:GetAttribute("RangeBonus") or 0
			local knockbackBonus = tool:GetAttribute("KnockbackBonus") or 0
			local isExtraSlot = tool:GetAttribute("ExtraSlot") == true
			local prefixes = tool:GetAttribute("Prefixes") or ""

			-- Count modifiers for dynamic card sizing
			local modLines = 0
			if bonusDmg > 0 then modLines += 1 end
			if critChance > 0 then modLines += 1 end
			if rangeBonus > 0 then modLines += 1 end
			if knockbackBonus > 0 then modLines += 1 end

			local cardH = 68 + (modLines * 22)
			local isSellable = tool.Name ~= "ClassicSword" and tool:GetAttribute("BossDrop") == true and not item.equipped

			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, 0, 0, cardH)
			card.BackgroundColor3 = COLORS.PanelLight
			card.BackgroundTransparency = 0.08
			card.BorderSizePixel = 0
			card.LayoutOrder = order
			card.ZIndex = 23
			card.Parent = body
			addCorner(card, 12)
			addPadding(card, 8, 10, 8, 10)
			order += 1

			local stroke = addStroke(card, RARITY_COLOR[rarity] or COLORS.Stroke, 0.25, 1.5)

			-- If blessed, add an outer gold halo/border surrounding the rarity border
			if isExtraSlot then
				local goldWrapper = Instance.new("Frame")
				goldWrapper.Size = UDim2.new(1, 6, 1, 6)
				goldWrapper.Position = UDim2.fromOffset(-3, -3)
				goldWrapper.BackgroundTransparency = 1
				goldWrapper.BorderSizePixel = 0
				goldWrapper.ZIndex = 23
				goldWrapper.Parent = card
				addCorner(goldWrapper, 14)
				addStroke(goldWrapper, Color3.fromRGB(255, 215, 0), 0.1, 2)
			end

			-- Title bar with Rarity tint
			local title = createText(card, {
				text = tool.Name,
				font = Enum.Font.GothamBold,
				size = 15,
				color = RARITY_COLOR[rarity] or COLORS.Text,
				size2 = UDim2.new(isSellable and 0.52 or 0.65, 0, 0, 20),
				zIndex = 24
			})

			if isSellable then
				local sellButton = Instance.new("TextButton")
				sellButton.Name = "SellButton"
				sellButton.Size = UDim2.fromOffset(76, 26)
				sellButton.Position = UDim2.new(1, -76, 0, -1)
				sellButton.BackgroundColor3 = COLORS.Gold
				sellButton.BorderSizePixel = 0
				sellButton.Font = Enum.Font.GothamBold
				sellButton.Text = "SELL"
				sellButton.TextColor3 = Color3.fromRGB(35, 28, 0)
				sellButton.TextSize = 12
				sellButton.AutoButtonColor = false
				sellButton.ZIndex = 25
				sellButton.Parent = card
				addCorner(sellButton, 7)
				addStroke(sellButton, Color3.fromRGB(255, 235, 120), 0.2, 1)
				sellButton.MouseEnter:Connect(function()
					sellButton.BackgroundColor3 = Color3.fromRGB(255, 230, 80)
				end)
				sellButton.MouseLeave:Connect(function()
					sellButton.BackgroundColor3 = COLORS.Gold
				end)
				sellButton.Activated:Connect(function()
					sellButton.Active = false
					sellButton.Text = "SELLING..."
					inventoryAction:FireServer("Sell", tool.Name)
				end)
			end

			-- Equipped Badge
			if item.equipped then
				local eqBadge = Instance.new("Frame")
				eqBadge.Size = UDim2.fromOffset(76, 20)
				eqBadge.Position = UDim2.new(1, -76, 0, 0)
				eqBadge.BackgroundColor3 = COLORS.Success
				eqBadge.BorderSizePixel = 0
				eqBadge.ZIndex = 24
				eqBadge.Parent = card
				addCorner(eqBadge, 6)
				
				local eqLabel = Instance.new("TextLabel")
				eqLabel.BackgroundTransparency = 1
				eqLabel.Size = UDim2.fromScale(1, 1)
				eqLabel.Position = UDim2.fromOffset(0, 0)
				eqLabel.Font = Enum.Font.GothamBold
				eqLabel.TextSize = 10
				eqLabel.TextColor3 = Color3.fromRGB(15, 15, 15)
				eqLabel.TextXAlignment = Enum.TextXAlignment.Center
				eqLabel.TextYAlignment = Enum.TextYAlignment.Center
				eqLabel.Text = "EQUIPPED"
				eqLabel.ZIndex = 25
				eqLabel.Parent = eqBadge
			end

			-- Base Mult Row with sword icon
			local multRow = Instance.new("Frame")
			multRow.Size = UDim2.new(1, 0, 0, 18)
			multRow.Position = UDim2.fromOffset(0, 22)
			multRow.BackgroundTransparency = 1
			multRow.ZIndex = 24
			multRow.Parent = card

			local swIcon = Instance.new("ImageLabel")
			swIcon.Size = UDim2.fromOffset(16, 16)
			swIcon.Position = UDim2.fromOffset(0, 1)
			swIcon.BackgroundTransparency = 1
			swIcon.Image = ICONS.Sword
			swIcon.ScaleType = Enum.ScaleType.Fit
			swIcon.ZIndex = 25
			swIcon.Parent = multRow

			createText(multRow, {
				text = string.format("Rarity: %s  •  Base Multiplier: x%.2f", rarity, damageMult),
				font = Enum.Font.Gotham,
				size = 12,
				color = COLORS.Muted,
				pos = UDim2.fromOffset(22, 0),
				size2 = UDim2.new(1, -22, 1, 0),
				zIndex = 25
			})

			-- Stat Modifier Details Section
			local currentY = 44
			local function addModifierBadge(icon, statText, badgeColor)
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 20)
				row.Position = UDim2.fromOffset(0, currentY)
				row.BackgroundColor3 = COLORS.PanelDark
				row.BackgroundTransparency = 0.2
				row.BorderSizePixel = 0
				row.ZIndex = 24
				row.Parent = card
				addCorner(row, 6)
				addPadding(row, 0, 6, 0, 6)

				local ic = Instance.new("ImageLabel")
				ic.Size = UDim2.fromOffset(14, 14)
				ic.Position = UDim2.fromOffset(4, 3)
				ic.BackgroundTransparency = 1
				ic.Image = icon
				ic.ScaleType = Enum.ScaleType.Fit
				ic.ZIndex = 25
				ic.Parent = row

				createText(row, {
					text = statText,
					font = Enum.Font.GothamMedium,
					size = 11,
					color = badgeColor or COLORS.Text,
					pos = UDim2.fromOffset(24, 0),
					size2 = UDim2.new(1, -24, 1, 0),
					zIndex = 25
				})
				currentY += 22
			end

			if bonusDmg > 0 then
				addModifierBadge(ICONS.Sword, string.format("+%d%% Bonus Damage", math.round(bonusDmg * 100)), Color3.fromRGB(255, 120, 100))
			end
			if critChance > 0 then
				addModifierBadge(ICONS.Target, string.format("+%d%% Critical Strike Chance", math.round(critChance * 100)), Color3.fromRGB(255, 180, 70))
			end
			if rangeBonus > 0 then
				addModifierBadge(ICONS.Lighting, string.format("+%d Studs Extended Reach", rangeBonus), Color3.fromRGB(120, 200, 255))
			end
			if knockbackBonus > 0 then
				addModifierBadge(ICONS.Shield, string.format("+%d Impact Knockback", knockbackBonus), Color3.fromRGB(160, 240, 160))
			end
		end
	end

end

local function buildSkillsPanel()
	clearBody()
	headerTitle.Text = "Skills"
	skillButtons = {}
	local pointsLabel = createText(body, { text = "Skill Points: 0", font = Enum.Font.GothamBold, size = 17, color = COLORS.Text, size2 = UDim2.new(1, 0, 0, 28), zIndex = 23 })
	pointsLabel.LayoutOrder = 1
	skillButtons.points = pointsLabel
	for i, attr in ipairs(SKILL_ATTRIBUTES) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 64)
		row.BackgroundColor3 = COLORS.PanelLight
		row.BackgroundTransparency = 0.08
		row.BorderSizePixel = 0
		row.LayoutOrder = i + 1
		row.ZIndex = 23
		row.Parent = body
		addCorner(row, 10)
		addStroke(row, COLORS.Stroke, 0.4, 1)
		addPadding(row, 8, 8, 8, 12)
		createText(row, { text = attr.label, font = Enum.Font.GothamBold, size = 16, size2 = UDim2.new(0.6, 0, 0, 22), zIndex = 24 })
		local valLabel = createText(row, { text = "0", font = Enum.Font.GothamBold, size = 16, color = COLORS.Text, xAlign = Enum.TextXAlignment.Right, pos = UDim2.fromScale(0.6, 0), size2 = UDim2.new(0.4, -50, 0, 22), zIndex = 24 })
		createText(row, { text = attr.desc, font = Enum.Font.Gotham, size = 12, color = COLORS.Muted, pos = UDim2.fromOffset(0, 24), size2 = UDim2.new(1, -50, 0, 20), zIndex = 24 })
		local plus = Instance.new("TextButton")
		plus.Size = UDim2.fromOffset(40, 40)
		plus.Position = UDim2.new(1, -40, 0.5, -20)
		plus.BackgroundColor3 = COLORS.Button
		plus.BorderSizePixel = 0
		plus.Font = Enum.Font.GothamBold
		plus.Text = "+"
		plus.TextColor3 = COLORS.Text
		plus.TextSize = 22
		plus.ZIndex = 24
		plus.Parent = row
		addCorner(plus, 10)
		addStroke(plus, COLORS.StrokeBright, 0.3, 1)
		plus.Activated:Connect(function() spendEvent:FireServer(attr.name) end)
		skillButtons[attr.name] = { value = valLabel, plus = plus }
	end
end

-- Last RebirthResult the server sent, rendered as a status line in the panel below.
-- The server has always fired this event; until now nothing on the client listened,
-- so a refused rebirth failed silently.
local lastRebirthResult = nil

local function buildRebirthPanel()
	clearBody()
	headerTitle.Text = "Rebirth"
	local level = 1
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
	if levelValue then level = levelValue.Value end
	local requirement = player:GetAttribute("RebirthRequirement") or 20
	local rebirths = player:GetAttribute("Rebirths") or 0
	createText(body, { text = ("Current Rebirths: %d"):format(rebirths), font = Enum.Font.GothamBold, size = 17, color = COLORS.Text, size2 = UDim2.new(1, 0, 0, 28), zIndex = 23 }).LayoutOrder = 1
	createText(body, { text = ("Level %d / %d required"):format(level, requirement), font = Enum.Font.Gotham, size = 14, color = COLORS.Muted, size2 = UDim2.new(1, 0, 0, 26), zIndex = 23 }).LayoutOrder = 2
	if lastRebirthResult then
		local ok = lastRebirthResult.ok
		createText(body, {
			text = ok and ("Rebirth complete — you are now at rebirth %d"):format(lastRebirthResult.rebirths or rebirths)
				or ("Not yet — level %d required"):format(lastRebirthResult.need or requirement),
			font = Enum.Font.GothamBold, size = 14,
			color = ok and Color3.fromRGB(120, 255, 170) or Color3.fromRGB(255, 120, 120),
			size2 = UDim2.new(1, 0, 0, 24), zIndex = 23,
		}).LayoutOrder = 3
	end

	local rebirthButton = Instance.new("TextButton")
	rebirthButton.Size = UDim2.new(1, 0, 0, 48)
	rebirthButton.BackgroundColor3 = level >= requirement and COLORS.Success or COLORS.Button
	rebirthButton.BorderSizePixel = 0
	rebirthButton.Font = Enum.Font.GothamBold
	rebirthButton.TextColor3 = level >= requirement and Color3.fromRGB(15, 20, 15) or COLORS.Text
	rebirthButton.TextSize = 16
	rebirthButton.Text = level >= requirement and "REBIRTH NOW" or "LEVEL UP TO REBIRTH"
	rebirthButton.ZIndex = 24
	rebirthButton.LayoutOrder = 4
	rebirthButton.Parent = body
	addCorner(rebirthButton, 10)
	addStroke(rebirthButton, level >= requirement and Color3.fromRGB(120, 255, 170) or COLORS.StrokeBright, 0.3, 1)
	rebirthButton.Activated:Connect(function() remotes:WaitForChild("Rebirth"):FireServer() end)
end

local function buildSettingsPanel()
	clearBody()
	headerTitle.Text = "Settings"
	createText(body, { text = "Press M to open/close this menu.", font = Enum.Font.Gotham, size = 13, color = COLORS.Muted, size2 = UDim2.new(1, 0, 0, 30), zIndex = 23 }).LayoutOrder = 1
end

local function refreshTopBar()
	goldLabel.Text = tostring(player:GetAttribute('Gold') or 0)
	local level = 1
	local leaderstats = player:FindFirstChild('leaderstats')
	if leaderstats then
		local lv = leaderstats:FindFirstChild('Level')
		if lv then level = lv.Value end
	end
	levelChipLabel.Text = 'Lv ' .. tostring(level)
end

local function refreshSkills()
	local points = player:GetAttribute('SkillPoints') or 0
	if skillButtons.points then skillButtons.points.Text = 'Skill Points: ' .. tostring(points) end
	local canSpend = points > 0
	for _, attr in ipairs(SKILL_ATTRIBUTES) do
		local refs = skillButtons[attr.name]
		if refs then
			refs.value.Text = tostring(player:GetAttribute(attr.name) or 0)
			refs.plus.BackgroundColor3 = canSpend and COLORS.ButtonHover or COLORS.ButtonDisabled
		end
	end
end

local function refreshHomeStats()
	if activeTab ~= 'Home' then return end
	for label, textLabel in pairs(homeStatLabels) do
		if label == 'Level' then
			local leaderstats = player:FindFirstChild('leaderstats')
			local lv = leaderstats and leaderstats:FindFirstChild('Level')
			textLabel.Text = tostring(lv and lv.Value or 1)
		elseif label == 'Gold' then
			textLabel.Text = tostring(player:GetAttribute('Gold') or 0)
		elseif label == 'Strength' then
			textLabel.Text = tostring(player:GetAttribute('Strength') or 0)
		elseif label == 'Skill Points' then
			textLabel.Text = tostring(player:GetAttribute('SkillPoints') or 0)
		end
	end
end

local function openTab(tabId)
	activeTab = tabId
	for id, btn in pairs(navButtons) do
		local selected = id == tabId
		btn.BackgroundColor3 = selected and COLORS.ButtonHover or COLORS.PanelLight
		btn.BackgroundTransparency = selected and 0.05 or 0.15
	end
	if tabId == 'Home' then homeStatLabels = buildHomePanel()
	elseif tabId == 'Inventory' then buildInventoryPanel(latestInventory)
	elseif tabId == 'Skills' then buildSkillsPanel(); refreshSkills()
	elseif tabId == 'Rebirth' then buildRebirthPanel()
	elseif tabId == 'Settings' then buildSettingsPanel() end
end

local function setMenuOpen(open)
	if panelOpen == open then return end
	panelOpen = open
	overlay.Visible = open
	contentPanel.Visible = open
	TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = open and 0.5 or 1 }):Play()
	if open and not activeTab then openTab('Home') end
	if open and activeTab == 'Inventory' then buildInventoryPanel(latestInventory) end
end

local function toggleMenu() setMenuOpen(not panelOpen) end

for i, item in ipairs(NAV_ITEMS) do
	local btn = createIconButton(navRail, { name = item.id, image = item.icon, size = UDim2.fromOffset(52, 52), bg = COLORS.PanelLight })
	btn.LayoutOrder = i
	btn.MouseEnter:Connect(function()
		if activeTab ~= item.id then
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = COLORS.ButtonHover }):Play()
		end
	end)
	btn.MouseLeave:Connect(function()
		if activeTab ~= item.id then
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = COLORS.PanelLight }):Play()
		end
	end)
	btn.Activated:Connect(function()
		if panelOpen and activeTab == item.id then setMenuOpen(false)
		else setMenuOpen(true); openTab(item.id) end
	end)
	navButtons[item.id] = btn
end

closeBtn.Activated:Connect(function() setMenuOpen(false) end)
overlay.Activated:Connect(function() setMenuOpen(false) end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.M then toggleMenu() end
end)

inventoryUpdated.OnClientEvent:Connect(function(snapshot)
	latestInventory = snapshot or {}
	if activeTab == 'Inventory' and panelOpen then buildInventoryPanel(latestInventory) end
end)

local attrsToWatch = { 'Gold', 'SkillPoints', 'Strength', 'Health', 'Defense', 'ExperienceGain', 'AutoSellLowerSwords', 'Rebirths', 'RebirthRequirement' }
for _, attr in ipairs(attrsToWatch) do
	player:GetAttributeChangedSignal(attr):Connect(function()
		refreshTopBar(); refreshSkills(); refreshHomeStats()
		if attr == 'AutoSellLowerSwords' and activeTab == 'Inventory' and panelOpen then
			buildInventoryPanel(latestInventory)
		elseif (attr == 'Rebirths' or attr == 'RebirthRequirement') and activeTab == 'Rebirth' and panelOpen then
			buildRebirthPanel()
		end
	end)
end

-- Refresh inventory view when tools change in backpack/character
local inventoryRefreshBound = setmetatable({}, { __mode = "k" })
local function refreshInventoryIfVisible()
	if activeTab == "Inventory" and panelOpen then
		buildInventoryPanel(latestInventory)
	end
end

local function bindInventoryContainer(container)
	if not container or inventoryRefreshBound[container] then
		return
	end
	inventoryRefreshBound[container] = true
	container.ChildAdded:Connect(refreshInventoryIfVisible)
	container.ChildRemoved:Connect(refreshInventoryIfVisible)
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

local leaderstats = player:WaitForChild('leaderstats', 10)
if leaderstats then
	local levelVal = leaderstats:WaitForChild('Level', 5)
	if levelVal then levelVal.Changed:Connect(function() refreshTopBar(); refreshHomeStats() end) end
end

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
