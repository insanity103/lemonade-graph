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
local RebirthConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RebirthConfig"))
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))

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

-- Each tab gets its own accent color (per NAV_ITEMS) instead of uniform gray, so the
-- rail reads as distinct categories at a glance.
local NAV_ITEMS = {
	{ id = "Reforge", text = "🎰", accent = Color3.fromRGB(232, 112, 42) },
	{ id = "Inventory", icon = ICONS.Inventory, accent = Color3.fromRGB(90, 150, 255) },
	{ id = "Skills", icon = ICONS.Skills, accent = Color3.fromRGB(90, 220, 140) },
	{ id = "Rebirth", icon = "rbxassetid://80234316052758", accent = Color3.fromRGB(190, 110, 245) },
	{ id = "Trade", icon = ICONS.Sword, accent = Color3.fromRGB(255, 175, 50) },
	{ id = "Settings", icon = ICONS.Settings, accent = Color3.fromRGB(150, 150, 165) },
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
	if props.text then
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = props.text
		label.TextScaled = true
		label.Font = Enum.Font.SourceSansBold
		label.ZIndex = button.ZIndex + 1
		label.Parent = button
	end
	return button
end

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(1, 1)
topBar.Position = UDim2.new(1, -12, 0.5, -166)
topBar.Size = UDim2.fromOffset(136, 56)
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
	chip.Size = UDim2.new(1, 0, 0, 40)
	chip.BackgroundColor3 = COLORS.PanelLight
	chip.BackgroundTransparency = 0.2
	chip.BorderSizePixel = 0
	chip.ZIndex = 6
	chip.Parent = topBar
	addCorner(chip, 8)
	local iconImg = Instance.new("ImageLabel")
	iconImg.Size = UDim2.fromOffset(26, 26)
	iconImg.Position = UDim2.fromOffset(7, 7)
	iconImg.BackgroundTransparency = 1
	iconImg.Image = icon
	iconImg.ScaleType = Enum.ScaleType.Fit
	iconImg.ZIndex = 7
	iconImg.Parent = chip
	-- Fixed text size: TextScaled shrank long values to nothing; the short-form number fits.
	local value = createText(chip, { text = "0", font = Enum.Font.GothamBold, size = 22, pos = UDim2.fromOffset(40, 0), size2 = UDim2.new(1, -44, 1, 0), zIndex = 7 })
	value.Name = "Value"
	value.TextXAlignment = Enum.TextXAlignment.Left
	return value
end

-- Level lives on the bottom-left XP bar; the top-right holds only gold.
local goldLabel = createChip("GoldChip", ICONS.Coin)

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
local navAccents = {}
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

local chrome = PanelChrome.build({
	name = "ContentPanel",
	title = "Menu",
	accentColor = COLORS.Gold,
	titleSize = 22,
	size = UDim2.fromOffset(460, 530),
})
local contentPanel = chrome.Frame
contentPanel.BackgroundTransparency = 0.04
contentPanel.Visible = false
contentPanel.ZIndex = 21
contentPanel.Parent = screenGui
local headerTitle = chrome.TitleLabel
local closeBtn = chrome.CloseButton

local body = Instance.new("ScrollingFrame")
body.Name = "Body"
body.Position = UDim2.fromOffset(0, 60)
body.Size = UDim2.new(1, 0, 1, -60)
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
local skillButtons = {}

local function clearBody()
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

local function buildInventoryPanel()
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

			-- Title bar with Rarity tint. Right side holds up to two buttons: EQUIP (any backpack
			-- sword) and SELL (unequipped boss drops), so the title shrinks to make room.
			local canEquip = not item.equipped
			local buttonCount = (canEquip and 1 or 0) + (isSellable and 1 or 0)
			local titleScale = if buttonCount == 2 then 0.40 elseif buttonCount == 1 then 0.52 else 0.65
			local title = createText(card, {
				text = tool.Name,
				font = Enum.Font.GothamBold,
				size = 15,
				color = RARITY_COLOR[rarity] or COLORS.Text,
				size2 = UDim2.new(titleScale, 0, 0, 20),
				zIndex = 24
			})

			-- Equipping is client-side, exactly what the default backpack strip did before it was
			-- hidden by SwordHotbarGui: the client owns its own character and backpack tools.
			if canEquip then
				local equipButton = Instance.new("TextButton")
				equipButton.Name = "EquipButton"
				equipButton.Size = UDim2.fromOffset(76, 26)
				equipButton.Position = UDim2.new(1, isSellable and -(76 + 82) or -76, 0, -1)
				equipButton.BackgroundColor3 = COLORS.Success
				equipButton.BorderSizePixel = 0
				equipButton.Font = Enum.Font.GothamBold
				equipButton.Text = "EQUIP"
				equipButton.TextColor3 = Color3.fromRGB(15, 30, 20)
				equipButton.TextSize = 12
				equipButton.AutoButtonColor = false
				equipButton.ZIndex = 25
				equipButton.Parent = card
				addCorner(equipButton, 7)
				addStroke(equipButton, Color3.fromRGB(150, 245, 190), 0.2, 1)
				equipButton.MouseEnter:Connect(function()
					equipButton.BackgroundColor3 = Color3.fromRGB(120, 240, 170)
				end)
				equipButton.MouseLeave:Connect(function()
					equipButton.BackgroundColor3 = COLORS.Success
				end)
				equipButton.Activated:Connect(function()
					local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid and tool.Parent then
						humanoid:EquipTool(tool)
					end
				end)
			end

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
					task.delay(5, function()
						if sellButton and sellButton.Parent and sellButton.Text == "SELLING..." then
							sellButton.Active = true
							sellButton.Text = "SELL"
						end
					end)
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

	-- Benefits: what every rebirth adds, where your bonuses stand now versus after the next one,
	-- and the milestone perks. All numbers come from RebirthConfig so this can't drift from the
	-- server's maths.
	local function benefitCard(order, height)
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, height)
		card.BackgroundColor3 = COLORS.PanelLight
		card.BackgroundTransparency = 0.08
		card.BorderSizePixel = 0
		card.LayoutOrder = order
		card.ZIndex = 23
		card.Parent = body
		addCorner(card, 12)
		addStroke(card, COLORS.Stroke, 0.35, 1)
		addPadding(card, 8, 12, 8, 12)
		return card
	end
	local function cardLine(card, y, text, props)
		return createText(card, {
			text = text, font = props.font or Enum.Font.Gotham, size = props.size or 12,
			color = props.color or COLORS.Text, pos = UDim2.fromOffset(props.x or 0, y),
			size2 = UDim2.new(props.w or 1, props.wOffset or 0, 0, 18), xAlign = props.xAlign, zIndex = 24,
		})
	end

	local now, next_ = RebirthConfig.GetMultipliers(rebirths), RebirthConfig.GetMultipliers(rebirths + 1)
	local rows = {
		{ "XP gain", now.xpMult, next_.xpMult, "x%.2f" },
		{ "Gold gain", now.goldMult, next_.goldMult, "x%.2f" },
		{ "Sword damage", now.damageMult, next_.damageMult, "x%.2f" },
		{ "Base health", now.healthMult, next_.healthMult, "x%.2f" },
		{ "Bonus skill points", now.bonusSkillPoints, next_.bonusSkillPoints, "+%d" },
	}
	local statsCard = benefitCard(4, 34 + #rows * 20 + 24)
	cardLine(statsCard, 0, "Your bonuses", { font = Enum.Font.GothamBold, size = 14 })
	cardLine(statsCard, 0, "now", { font = Enum.Font.GothamBold, size = 12, color = COLORS.Muted, x = 0, w = 0.62, xAlign = Enum.TextXAlignment.Right })
	cardLine(statsCard, 0, "after next", { font = Enum.Font.GothamBold, size = 12, color = COLORS.Success, w = 1, xAlign = Enum.TextXAlignment.Right })
	for i, row in ipairs(rows) do
		local y = 24 + (i - 1) * 20
		cardLine(statsCard, y, row[1], { color = COLORS.Muted })
		cardLine(statsCard, y, row[4]:format(row[2]), { font = Enum.Font.GothamMedium, w = 0.62, xAlign = Enum.TextXAlignment.Right })
		cardLine(statsCard, y, row[4]:format(row[3]), { font = Enum.Font.GothamBold, color = COLORS.Success, w = 1, xAlign = Enum.TextXAlignment.Right })
	end
	local dropNote = ("Boss drop rates rise every rebirth (Legendary +%d%%, Epic +%.1f%%, Rare +%.1f%%); Blessed +%d%% from rebirth 5."):format(
		math.round(RebirthConfig.DROP_RATE_BONUS_PER_REBIRTH.Legendary * 100), RebirthConfig.DROP_RATE_BONUS_PER_REBIRTH.Epic * 100,
		RebirthConfig.DROP_RATE_BONUS_PER_REBIRTH.Rare * 100, math.round(RebirthConfig.REBIRTH_5_BLESSED_BONUS * 100))
	local note = cardLine(statsCard, 24 + #rows * 20 + 2, dropNote, { size = 11, color = COLORS.Muted })
	note.TextWrapped = true
	note.Size = UDim2.new(1, 0, 0, 30)

	local milestoneIds = {}
	for id in pairs(RebirthConfig.Milestones) do table.insert(milestoneIds, id) end
	table.sort(milestoneIds)
	local msCard = benefitCard(5, 26 + #milestoneIds * 34)
	cardLine(msCard, 0, "Milestone perks", { font = Enum.Font.GothamBold, size = 14 })
	for i, id in ipairs(milestoneIds) do
		local ms = RebirthConfig.Milestones[id]
		local y = 24 + (i - 1) * 34
		local reached, isNext = rebirths >= id, rebirths + 1 == id
		local titleColor = reached and COLORS.Success or (isNext and COLORS.Gold or COLORS.Muted)
		local marker = reached and "✓" or (isNext and "▸" or "•")
		cardLine(msCard, y, ("%s  Rebirth %d — %s"):format(marker, id, ms.title), { font = Enum.Font.GothamBold, size = 13, color = titleColor })
		cardLine(msCard, y + 16, ms.desc, { size = 11, color = reached and COLORS.Text or COLORS.Muted, x = 18, wOffset = -18 })
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
	rebirthButton.LayoutOrder = 6
	rebirthButton.Parent = body
	addCorner(rebirthButton, 10)
	addStroke(rebirthButton, level >= requirement and Color3.fromRGB(120, 255, 170) or COLORS.StrokeBright, 0.3, 1)
	rebirthButton.Activated:Connect(function() remotes:WaitForChild("Rebirth"):FireServer() end)
end

-- ═══════════════════════════════════════════════════════════════════════════
--  TRADE TAB: pick a player from the lobby, then build an offer side by side
-- ═══════════════════════════════════════════════════════════════════════════
local tradeRemote = remotes:WaitForChild("TradeAction")
local SwordValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwordValue"))
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

local function openTab(tabId)
	activeTab = tabId
	for id, btn in pairs(navButtons) do
		local selected = id == tabId
		local accent = navAccents[id] or COLORS.ButtonHover
		btn.BackgroundColor3 = selected and accent or COLORS.PanelLight
		btn.BackgroundTransparency = selected and 0.35 or 0.15
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Transparency = selected and 0.1 or 0.6 end
	end
	if tabId == 'Inventory' then buildInventoryPanel()
	elseif tabId == 'Skills' then buildSkillsPanel(); refreshSkills()
	elseif tabId == 'Rebirth' then buildRebirthPanel()
	elseif tabId == 'Trade' then buildTradePanel(); tradeRemote:FireServer("Refresh")
	elseif tabId == 'Settings' then buildSettingsPanel() end
end


local function setMenuOpen(open)
	if panelOpen == open then return end
	panelOpen = open
	overlay.Visible = open
	contentPanel.Visible = open
	TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = open and 0.5 or 1 }):Play()
	if open and not activeTab then openTab('Inventory') end
	if open and activeTab == 'Inventory' then buildInventoryPanel() end
end

local function toggleMenu() setMenuOpen(not panelOpen) end

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
	local btn = createIconButton(navRail, { name = item.id, image = item.icon, text = item.text, size = UDim2.fromOffset(52, 52), bg = COLORS.PanelLight })
	btn.LayoutOrder = i
	navAccents[item.id] = item.accent
	addStroke(btn, item.accent, 0.6, 1.5)
	btn.MouseEnter:Connect(function()
		if activeTab ~= item.id then
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = item.accent, BackgroundTransparency = 0.6 }):Play()
		end
	end)
	btn.MouseLeave:Connect(function()
		if activeTab ~= item.id then
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = COLORS.PanelLight, BackgroundTransparency = 0.15 }):Play()
		end
	end)
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
