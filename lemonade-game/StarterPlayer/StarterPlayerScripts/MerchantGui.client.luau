--// MerchantGui (Client shop UI for Safe Zone Relic Merchant)
-- Bright, chunky storefront: each relic is a big rarity tile with a 3D render of its blade,
-- a stroked name and a coin price button underneath. The sword models are small part-built
-- stand-ins assembled here on the client (the real boss meshes live in ServerStorage).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MerchantConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MerchantConfig"))
local REMOTES = ReplicatedStorage:WaitForChild("RemoteEvents")
local MERCHANT_ACTION = REMOTES:WaitForChild("MerchantAction")
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))

local BRIGHT = PanelChrome.BRIGHT
local RARITY_TILE = PanelChrome.RARITY_TILE
local corner = PanelChrome.corner
local COIN_ICON = "rbxassetid://84697600263846" -- the HUD gold coin

-- [TUNING] design-space sizes; the whole panel is scaled with one UIScale.
local CARD_W, TILE_H, NAME_H, BUY_H = 158, 158, 32, 54
local NAME_Y = TILE_H + 14 -- clears the rarity chip that rides the tile's bottom edge
local CARD_H = NAME_Y + NAME_H + 2 + BUY_H
local GAP = 14
local RADIUS = 24 -- the window's corner radius
local HEADER_H = 84 -- the ember header band the title, gold and close button sit in
local CLOSE = 60
local BANNER_Y, BANNER_H = HEADER_H + 14, 48 -- the "random modifiers / Blessed" ribbon
local TRAY_X, TRAY_BOTTOM = 18, 20 -- the dark inset tray the cards sit in
local TRAY_Y = BANNER_Y + BANNER_H + 14
local TRAY_INSET = 8 -- the scroll area's inset inside the tray
local SCROLL_PAD_TOP, SCROLL_PAD_BOTTOM = 18, 14 -- room for the BEST! ribbon and the hover grow
local GOLD_W_WIDE, GOLD_W_NARROW = 220, 176
local WIDE_MIN = 700 -- narrower windows move the gold pill down beside the ribbon
local SCREEN_MARGIN_X, SCREEN_MARGIN_Y = 28, 110

-- Forge palette: ember header, warm parchment body, blued-steel tray, arcane-violet ribbon.
local THEME = {
	HeaderTop = Color3.fromRGB(255, 190, 78), HeaderBottom = Color3.fromRGB(238, 104, 34),
	HeaderLip = Color3.fromRGB(176, 62, 18),
	BodyTop = Color3.fromRGB(255, 249, 234), BodyBottom = Color3.fromRGB(240, 220, 184),
	TrayTop = Color3.fromRGB(80, 92, 128), TrayBottom = Color3.fromRGB(46, 52, 78),
	RibbonTop = Color3.fromRGB(188, 126, 255), RibbonBottom = Color3.fromRGB(118, 58, 214),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MerchantGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Visible = false
overlay.ZIndex = 50
overlay.Parent = screenGui

-- The window holds the panel and its drop shadow, so one UIScale sizes both.
local window = Instance.new("Frame")
window.Name = "ShopWindow"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.5)
window.Size = UDim2.fromOffset(890, 520)
window.BackgroundTransparency = 1
window.Visible = false
window.ZIndex = 51
window.Parent = screenGui
local panelScale = Instance.new("UIScale")
panelScale.Parent = window

local dropShadow = Instance.new("Frame")
dropShadow.Name = "DropShadow"
dropShadow.AnchorPoint = Vector2.new(0.5, 0.5)
dropShadow.Position = UDim2.new(0.5, 0, 0.5, 14)
dropShadow.Size = UDim2.new(1, 14, 1, 14)
dropShadow.BackgroundColor3 = Color3.fromRGB(8, 8, 18)
dropShadow.BackgroundTransparency = 0.35
dropShadow.BorderSizePixel = 0
dropShadow.ZIndex = 50
dropShadow.Parent = window
corner(dropShadow, RADIUS + 6)

local chrome = PanelChrome.buildBright({
	name = "ShopModal",
	title = "Relic Blacksmith",
	size = UDim2.fromOffset(890, 520),
	titleSize = 48,
	closeSize = CLOSE,
})
local modal = chrome.Frame
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.Size = UDim2.fromScale(1, 1)
modal.Visible = false
modal.ZIndex = 51
modal.Parent = window
local closeBtn = chrome.CloseButton

-- Re-theme the bright shell: warm parchment body and a heavier outline.
modal:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, RADIUS)
modal:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(THEME.BodyTop, THEME.BodyBottom)
modal:FindFirstChildOfClass("UIStroke").Thickness = 5.5

-- ── Header band: rounded top, square bottom, glossy face and a dark rule under it ──
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, HEADER_H)
header.BackgroundColor3 = Color3.new(1, 1, 1)
header.BorderSizePixel = 0
header.ZIndex = 52
header.Parent = modal
corner(header, RADIUS)
PanelChrome.gradient(header, THEME.HeaderTop, THEME.HeaderBottom)
-- The lower half squares off the bottom corners; its gradient picks up exactly where the
-- header's is at the halfway line, so the seam is invisible.
local headerFill = Instance.new("Frame")
headerFill.Name = "SquareBottom"
headerFill.Position = UDim2.fromScale(0, 0.5)
headerFill.Size = UDim2.fromScale(1, 0.5)
headerFill.BackgroundColor3 = Color3.new(1, 1, 1)
headerFill.BorderSizePixel = 0
headerFill.ZIndex = 52
headerFill.Parent = header
PanelChrome.gradient(headerFill, THEME.HeaderTop:Lerp(THEME.HeaderBottom, 0.5), THEME.HeaderBottom)
local headerShine = Instance.new("Frame")
headerShine.Name = "Shine"
headerShine.Position = UDim2.fromOffset(10, 6)
headerShine.Size = UDim2.new(1, -20, 0.42, 0)
headerShine.BackgroundColor3 = Color3.new(1, 1, 1)
headerShine.BackgroundTransparency = 0.55
headerShine.BorderSizePixel = 0
headerShine.ZIndex = 53
headerShine.Parent = header
corner(headerShine, RADIUS - 8)
local shineGrad = Instance.new("UIGradient")
shineGrad.Transparency = NumberSequence.new(0, 1)
shineGrad.Rotation = 90
shineGrad.Parent = headerShine
local headerLip = Instance.new("Frame")
headerLip.Name = "Lip"
headerLip.Position = UDim2.new(0, 0, 1, -12)
headerLip.Size = UDim2.new(1, 0, 0, 10)
headerLip.BackgroundColor3 = THEME.HeaderLip
headerLip.BorderSizePixel = 0
headerLip.ZIndex = 53
headerLip.Parent = header
local lipGrad = Instance.new("UIGradient")
lipGrad.Transparency = NumberSequence.new(1, 0.35)
lipGrad.Rotation = 90
lipGrad.Parent = headerLip
local headerRule = Instance.new("Frame")
headerRule.Name = "Rule"
headerRule.Position = UDim2.new(0, 0, 1, -3)
headerRule.Size = UDim2.new(1, 0, 0, 5)
headerRule.BackgroundColor3 = BRIGHT.Outline
headerRule.BorderSizePixel = 0
headerRule.ZIndex = 54
headerRule.Parent = header

-- Title, crest and close button ride inside the band, above it.
chrome.TitleLabel.ZIndex = 60
chrome.TitleLabel.AnchorPoint = Vector2.new(0, 0.5)
closeBtn.ZIndex = 60
closeBtn.Position = UDim2.new(1, -(CLOSE / 2 + 14), 0, HEADER_H / 2)

-- ── 3D helpers ───────────────────────────────────────────────────────────────
local function part(parent, className, name, size, color, material, shape)
	local p = Instance.new(className)
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

-- Per-relic look: blade tint, a glowing fuller down the middle, guard, grip and pommel gem.
local SWORD_LOOKS = {
	Boss_Gorgon = { blade = Color3.fromRGB(200, 206, 218), bladeMat = Enum.Material.Metal, fuller = Color3.fromRGB(200, 44, 44),
		guard = Color3.fromRGB(120, 42, 38), grip = Color3.fromRGB(70, 34, 30), gem = Color3.fromRGB(230, 60, 50), w = 1.08, len = 2.4, guardW = 2.0 },
	Boss_FrostRevenant = { blade = Color3.fromRGB(170, 232, 255), bladeMat = Enum.Material.Glass, fuller = Color3.fromRGB(70, 170, 245),
		guard = Color3.fromRGB(226, 242, 255), grip = Color3.fromRGB(40, 74, 130), gem = Color3.fromRGB(110, 214, 255), w = 1.2, len = 2.3, guardW = 1.9 },
	Boss_InfernalColossus = { blade = Color3.fromRGB(255, 120, 30), bladeMat = Enum.Material.SmoothPlastic, fuller = Color3.fromRGB(255, 226, 90),
		guard = Color3.fromRGB(60, 44, 40), grip = Color3.fromRGB(44, 30, 28), gem = Color3.fromRGB(255, 150, 20), w = 1.12, len = 2.45, guardW = 1.95 },
	Boss_VoidWraith = { blade = Color3.fromRGB(150, 70, 235), bladeMat = Enum.Material.SmoothPlastic, fuller = Color3.fromRGB(236, 176, 255),
		guard = Color3.fromRGB(44, 30, 64), grip = Color3.fromRGB(32, 22, 44), gem = Color3.fromRGB(205, 120, 255), w = 1.08, len = 2.5, guardW = 1.95 },
	Boss_CelestialTitan = { blade = Color3.fromRGB(236, 244, 255), bladeMat = Enum.Material.Metal, fuller = Color3.fromRGB(80, 200, 255),
		guard = Color3.fromRGB(214, 132, 16), grip = Color3.fromRGB(70, 60, 120), gem = Color3.fromRGB(110, 220, 255), w = 1.16, len = 2.55, guardW = 2.35 },
}

-- Builds a Tool shaped like the game's swords (Handle grip, blade along -Z) so
-- PanelChrome.renderTool can pose it. The blade's wide face is laid along X so the icon
-- camera sees the flat of the blade.
local function buildSwordTool(item)
	local look = SWORD_LOOKS[item.id] or {
		blade = Color3.fromRGB(200, 206, 218), bladeMat = Enum.Material.Metal, fuller = item.color or Color3.new(1, 1, 1),
		guard = Color3.fromRGB(170, 124, 60), grip = Color3.fromRGB(92, 66, 50), gem = item.color or Color3.new(1, 1, 1),
		w = 1.08, len = 2.4, guardW = 1.9,
	}
	local tool = Instance.new("Tool")
	tool.Name = item.id
	local handle = part(tool, "Part", "Handle", Vector3.new(0.44, 0.44, 1.0), look.grip, Enum.Material.SmoothPlastic)
	local function weld(p, c0)
		p.Anchored = false
		local w = Instance.new("Weld")
		w.Part0 = handle
		w.Part1 = p
		w.C0 = c0
		w.Parent = handle
	end
	local t = 0.26 -- blade thickness
	local bladeZ = -0.6 - 0.2 - look.len / 2
	weld(part(tool, "Part", "Pommel", Vector3.new(0.66, 0.66, 0.66), look.gem, Enum.Material.Neon, Enum.PartType.Ball), CFrame.new(0, 0, 0.68))
	weld(part(tool, "Part", "Guard", Vector3.new(look.guardW, 0.4, 0.44), look.guard, Enum.Material.Metal), CFrame.new(0, 0, -0.6))
	weld(part(tool, "Part", "GuardGem", Vector3.new(0.5, 0.5, 0.5), look.gem, Enum.Material.Neon, Enum.PartType.Ball), CFrame.new(0, 0, -0.6))
	for _, side in ipairs({ -1, 1 }) do
		-- Guard tips curl toward the blade for a chunkier silhouette.
		weld(part(tool, "Part", "GuardTip", Vector3.new(0.4, 0.42, 0.62), look.guard, Enum.Material.Metal),
			CFrame.new(side * (look.guardW / 2 - 0.08), 0, -0.84) * CFrame.Angles(0, side * math.rad(-20), 0))
	end
	weld(part(tool, "Part", "Blade", Vector3.new(look.w, t, look.len), look.blade, look.bladeMat), CFrame.new(0, 0, bladeZ))
	weld(part(tool, "Part", "Fuller", Vector3.new(look.w * 0.3, t + 0.04, look.len * 0.82), look.fuller, Enum.Material.Neon),
		CFrame.new(0, 0, bladeZ + look.len * 0.06))
	-- The point: two wedges, their slopes turned into the blade's width (X).
	local tipLen = look.w * 0.75
	local tipZ = bladeZ - look.len / 2 - tipLen / 2
	for _, side in ipairs({ 1, -1 }) do
		weld(part(tool, "WedgePart", "Tip", Vector3.new(t, look.w / 2, tipLen), look.blade, look.bladeMat),
			CFrame.new(side * look.w / 4, 0, tipZ) * CFrame.Angles(0, 0, side == 1 and -math.pi / 2 or math.pi / 2))
	end
	return tool
end

-- Title badge: two relic blades crossed, rendered like the shop tiles.
local titleIcon = chrome.TitleIcon
titleIcon.Image = ""
titleIcon.Size = UDim2.fromOffset(104, 104)
titleIcon.AnchorPoint = Vector2.new(0, 0.5)
titleIcon.Position = UDim2.fromOffset(-30, HEADER_H / 2 - 10)
titleIcon.Rotation = 0
titleIcon.ZIndex = 60
local items = MerchantConfig.Items
for i, spec in ipairs({ { item = items[#items - 1], tilt = -45 }, { item = items[#items], tilt = 45 } }) do
	if spec.item then
		local view = Instance.new("ViewportFrame")
		view.Name = "CrossedSword" .. i
		view.BackgroundTransparency = 1
		view.Size = UDim2.fromScale(1, 1)
		view.ZIndex = titleIcon.ZIndex
		view.Parent = titleIcon
		PanelChrome.renderTool(view, buildSwordTool(spec.item), { tiltDeg = spec.tilt, yawDeg = 0, margin = 1.0 })
	end
end
local TITLE_X = 90
chrome.TitleLabel.Position = UDim2.fromOffset(TITLE_X, HEADER_H / 2 - 1)

-- ── Gold balance (in the header) and the forge's terms (a ribbon under it) ────
local function coinIcon(parent, size, pos, anchor, z)
	local img = Instance.new("ImageLabel")
	img.Name = "Coin"
	img.BackgroundTransparency = 1
	img.Image = COIN_ICON
	img.ScaleType = Enum.ScaleType.Fit
	img.Size = UDim2.fromOffset(size, size)
	img.Position = pos
	img.AnchorPoint = anchor or Vector2.new(0, 0.5)
	img.ZIndex = z
	img.Parent = parent
	return img
end

local goldPill = Instance.new("Frame")
goldPill.Name = "GoldPill"
goldPill.AnchorPoint = Vector2.new(1, 0.5)
goldPill.Size = UDim2.fromOffset(GOLD_W_WIDE, 50)
goldPill.BackgroundColor3 = Color3.new(1, 1, 1)
goldPill.ZIndex = 56
goldPill.Parent = modal
corner(goldPill, 25)
PanelChrome.gradient(goldPill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(226, 232, 246))
PanelChrome.stroke(goldPill, BRIGHT.Outline, 3.5)
coinIcon(goldPill, 64, UDim2.new(0, -22, 0.5, 0), nil, 57)
local goldLabel = PanelChrome.display(goldPill, {
	name = "GoldAmount", text = "0", size = 34, stroke = 3, xAlign = Enum.TextXAlignment.Center,
	pos = UDim2.fromOffset(44, 0), size2 = UDim2.new(1, -56, 1, 0), zIndex = 57, scaled = true, minSize = 14,
})

-- A cut gem: a gold square turned 45 degrees, with a glossy upper facet.
local function sparkle(parent, size, pos, color, z)
	local holder = Instance.new("Frame")
	holder.Name = "Gem"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = pos
	holder.Size = UDim2.fromOffset(size, size)
	holder.Rotation = 45
	holder.BackgroundColor3 = Color3.new(1, 1, 1)
	holder.BorderSizePixel = 0
	holder.ZIndex = z
	holder.Parent = parent
	corner(holder, 5)
	PanelChrome.gradient(holder, color, BRIGHT.GoldDark).Rotation = 45
	PanelChrome.stroke(holder, BRIGHT.Outline, 2.5)
	local facet = Instance.new("Frame")
	facet.Name = "Facet"
	facet.Position = UDim2.fromScale(0.16, 0.16)
	facet.Size = UDim2.fromScale(0.4, 0.4)
	facet.BackgroundColor3 = Color3.new(1, 1, 1)
	facet.BackgroundTransparency = 0.25
	facet.BorderSizePixel = 0
	facet.ZIndex = z
	facet.Parent = holder
	corner(facet, 3)
	return holder
end

local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.Size = UDim2.new(1, -TRAY_X * 2, 0, BANNER_H)
banner.Position = UDim2.fromOffset(TRAY_X, BANNER_Y)
banner.BackgroundColor3 = Color3.new(1, 1, 1)
banner.BorderSizePixel = 0
banner.ZIndex = 53
banner.Parent = modal
corner(banner, BANNER_H / 2)
PanelChrome.gradient(banner, THEME.RibbonTop, THEME.RibbonBottom)
PanelChrome.stroke(banner, BRIGHT.Outline, 3.5)
PanelChrome.stripes(banner, { alpha = 0.9, bands = 9, rotation = 30, radius = BANNER_H / 2, zIndex = 53 })
local bannerShine = Instance.new("Frame")
bannerShine.Name = "Shine"
bannerShine.Position = UDim2.fromOffset(14, 4)
bannerShine.Size = UDim2.new(1, -28, 0.38, 0)
bannerShine.BackgroundColor3 = Color3.new(1, 1, 1)
bannerShine.BackgroundTransparency = 0.6
bannerShine.BorderSizePixel = 0
bannerShine.ZIndex = 53
bannerShine.Parent = banner
corner(bannerShine, 10)
local bannerSparkle = sparkle(banner, 22, UDim2.new(0, 28, 0.5, 0), Color3.fromRGB(255, 236, 120), 55)

local blessedChip = Instance.new("Frame")
blessedChip.Name = "BlessedChip"
blessedChip.AnchorPoint = Vector2.new(1, 0.5)
blessedChip.Position = UDim2.new(1, -7, 0.5, 0)
blessedChip.Size = UDim2.new(0, 190, 1, -12)
blessedChip.BackgroundColor3 = Color3.new(1, 1, 1)
blessedChip.ZIndex = 55
blessedChip.Parent = banner
corner(blessedChip, (BANNER_H - 12) / 2)
PanelChrome.gradient(blessedChip, BRIGHT.Gold, BRIGHT.GoldDark)
PanelChrome.stroke(blessedChip, BRIGHT.Outline, 3)
PanelChrome.display(blessedChip, {
	name = "Blessed", text = "0% BLESSED", size = 22, stroke = 2.5, scaled = true, minSize = 12, zIndex = 56,
	pos = UDim2.fromOffset(8, 2), size2 = UDim2.new(1, -16, 1, -4),
})

local infoLabel = PanelChrome.display(banner, {
	name = "Info", text = "", size = 22, stroke = 2.5, scaled = true, minSize = 11,
	xAlign = Enum.TextXAlignment.Left, zIndex = 55,
	pos = UDim2.fromOffset(52, 3), size2 = UDim2.new(1, -52 - 190 - 18, 1, -6),
})
infoLabel.TextWrapped = true
local DEFAULT_INFO = "Every relic is forged with random modifiers"
infoLabel.Text = DEFAULT_INFO

-- Toast notice for purchase result: a pill riding the panel's bottom edge.
local noticeLabel = Instance.new("TextLabel")
noticeLabel.Name = "NoticeLabel"
noticeLabel.AnchorPoint = Vector2.new(0.5, 0.5)
noticeLabel.Position = UDim2.fromScale(0.5, 1)
noticeLabel.Size = UDim2.fromOffset(0, 44)
noticeLabel.AutomaticSize = Enum.AutomaticSize.X
noticeLabel.BackgroundColor3 = BRIGHT.Green
noticeLabel.Font = PanelChrome.DISPLAY_FONT
noticeLabel.TextSize = 22
noticeLabel.TextColor3 = Color3.new(1, 1, 1)
noticeLabel.Text = ""
noticeLabel.ZIndex = 60
noticeLabel.Visible = false
noticeLabel.Parent = modal
corner(noticeLabel, 22)
-- One stroke outlines the pill (Border), the other outlines the text (Contextual).
PanelChrome.stroke(noticeLabel, BRIGHT.Outline, 3).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
PanelChrome.stroke(noticeLabel, BRIGHT.Outline, 2)
local noticePad = Instance.new("UIPadding")
noticePad.PaddingLeft = UDim.new(0, 22)
noticePad.PaddingRight = UDim.new(0, 22)
noticePad.Parent = noticeLabel

-- ── Card grid, on a dark inset tray ──────────────────────────────────────────
local tray = Instance.new("Frame")
tray.Name = "Tray"
tray.Position = UDim2.fromOffset(TRAY_X, TRAY_Y)
tray.Size = UDim2.new(1, -TRAY_X * 2, 1, -(TRAY_Y + TRAY_BOTTOM))
tray.ZIndex = 52
tray.Parent = modal
PanelChrome.insetTray(tray, { top = THEME.TrayTop, bottom = THEME.TrayBottom, radius = 20, zIndex = 52 })

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "ItemList"
scroll.Position = UDim2.fromOffset(TRAY_INSET, TRAY_INSET)
scroll.Size = UDim2.new(1, -TRAY_INSET * 2, 1, -TRAY_INSET * 2)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 8
scroll.ScrollBarImageColor3 = Color3.fromRGB(214, 222, 240)
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.ZIndex = 53
scroll.Parent = tray

local scrollPad = Instance.new("UIPadding")
scrollPad.PaddingLeft = UDim.new(0, 6)
scrollPad.PaddingRight = UDim.new(0, 6)
scrollPad.PaddingTop = UDim.new(0, SCROLL_PAD_TOP)
scrollPad.PaddingBottom = UDim.new(0, SCROLL_PAD_BOTTOM)
scrollPad.Parent = scroll

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(CARD_W, CARD_H)
grid.CellPadding = UDim2.fromOffset(GAP, GAP)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.Parent = scroll

local function formatGold(num)
	return tostring(num):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function currentGold()
	local leaderstats = player:FindFirstChild("leaderstats")
	return (leaderstats and leaderstats:FindFirstChild("Gold")) and leaderstats.Gold.Value or (player:GetAttribute("Gold") or 0)
end

local function showNotice(text, isSuccess)
	noticeLabel.Text = text
	noticeLabel.BackgroundColor3 = isSuccess and BRIGHT.Green or BRIGHT.Red
	noticeLabel.Visible = true
	task.delay(4, function()
		if noticeLabel.Text == text then
			noticeLabel.Visible = false
		end
	end)
end

local cards = {} -- { item, grad, label } per listing, built once

local function buildCard(index, item)
	local rarity = item.rarity or "Common"
	local t = RARITY_TILE[rarity] or RARITY_TILE.Common

	local card = Instance.new("Frame")
	card.Name = "Item_" .. item.id
	card.BackgroundTransparency = 1
	card.LayoutOrder = index
	card.ZIndex = 53
	card.Parent = scroll

	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.Size = UDim2.fromOffset(CARD_W, TILE_H)
	tile.ZIndex = 53
	tile.Parent = card
	corner(tile, 20)
	PanelChrome.lootTile(tile, rarity, { radius = 20, zIndex = 53, glowY = 0.5 })
	local tileScale = Instance.new("UIScale")
	tileScale.Parent = tile

	local view = Instance.new("ViewportFrame")
	view.Name = "SwordRender"
	view.BackgroundTransparency = 1
	view.Position = UDim2.fromOffset(4, 6)
	view.Size = UDim2.new(1, -8, 1, -8)
	view.ZIndex = 54
	view.Parent = tile
	PanelChrome.renderTool(view, buildSwordTool(item), { tiltDeg = 45, yawDeg = 0, margin = 0.96, ambient = Color3.fromRGB(205, 205, 218) })

	-- The top relic gets a tilted ribbon, like a storefront's "best value" tag.
	if index == #MerchantConfig.Items then
		local tag = Instance.new("Frame")
		tag.Name = "BestTag"
		tag.AnchorPoint = Vector2.new(0.5, 0.5)
		tag.Position = UDim2.fromOffset(30, 10)
		tag.Size = UDim2.fromOffset(70, 28)
		tag.Rotation = -12
		tag.BackgroundColor3 = Color3.new(1, 1, 1)
		tag.ZIndex = 58
		tag.Parent = tile
		corner(tag, 10)
		PanelChrome.gradient(tag, BRIGHT.Red, BRIGHT.RedDark)
		PanelChrome.stroke(tag, BRIGHT.Outline, 2.5)
		PanelChrome.display(tag, { text = "BEST!", size = 19, stroke = 2, zIndex = 59 })
	end

	-- Damage multiplier: the big stroked number in the corner, like a stack count.
	PanelChrome.display(tile, {
		name = "Mult", text = string.format("x%.1f", item.baseMult or 1), size = 28, stroke = 3,
		xAlign = Enum.TextXAlignment.Right, yAlign = Enum.TextYAlignment.Top,
		pos = UDim2.fromOffset(-10, 6), size2 = UDim2.new(1, 0, 0, 30), zIndex = 56,
	})
	local rarityChip = Instance.new("Frame")
	rarityChip.Name = "Rarity"
	rarityChip.AnchorPoint = Vector2.new(0.5, 0.5)
	rarityChip.Position = UDim2.new(0.5, 0, 1, -2)
	rarityChip.Size = UDim2.fromOffset(0, 24)
	rarityChip.AutomaticSize = Enum.AutomaticSize.X
	rarityChip.BackgroundColor3 = t.rim
	rarityChip.ZIndex = 56
	rarityChip.Parent = tile
	corner(rarityChip, 12)
	PanelChrome.stroke(rarityChip, BRIGHT.Outline, 2.5)
	local chipPad = Instance.new("UIPadding")
	chipPad.PaddingLeft = UDim.new(0, 10)
	chipPad.PaddingRight = UDim.new(0, 10)
	chipPad.Parent = rarityChip
	local chipText = PanelChrome.display(rarityChip, { text = string.upper(rarity), size = 15, stroke = 2, zIndex = 57 })
	chipText.Size = UDim2.fromScale(0, 1)
	chipText.AutomaticSize = Enum.AutomaticSize.X

	local nameLabel = PanelChrome.display(card, {
		name = "ItemName", text = item.name or item.id, size = 20, stroke = 2.5, scaled = true, minSize = 12,
		pos = UDim2.fromOffset(0, NAME_Y), size2 = UDim2.fromOffset(CARD_W, NAME_H), zIndex = 54,
	})
	nameLabel.TextWrapped = false
	nameLabel.TextColor3 = Color3.new(1, 1, 1)

	local buyBtn, buyLabel, buyGrad = PanelChrome.chunkyButton(card, {
		name = "BuyButton", text = formatGold(item.price), size = UDim2.fromOffset(CARD_W, BUY_H),
		pos = UDim2.fromOffset(0, CARD_H - BUY_H), textSize = 28, zIndex = 54, radius = 16, strokeThickness = 3.5,
	})
	buyLabel.Position = UDim2.fromOffset(46, 3)
	buyLabel.Size = UDim2.new(1, -54, 1, -6)
	coinIcon(buyBtn, 46, UDim2.new(0, 2, 0.5, 0), nil, 56)

	buyBtn.Activated:Connect(function()
		MERCHANT_ACTION:FireServer("BuySword", item.id)
	end)

	local function hover(on)
		tileScale.Scale = on and 1.05 or 1
		infoLabel.Text = on and (item.desc or DEFAULT_INFO) or DEFAULT_INFO
	end
	tile.MouseEnter:Connect(function() hover(true) end)
	tile.MouseLeave:Connect(function() hover(false) end)
	buyBtn.MouseEnter:Connect(function() hover(true) end)
	buyBtn.MouseLeave:Connect(function() hover(false) end)

	cards[index] = { item = item, grad = buyGrad }
end

-- Affordable prices go green; the rest stay grey (still pressable: the server answers).
local function refreshPrices()
	local gold = currentGold()
	goldLabel.Text = formatGold(gold)
	for _, c in ipairs(cards) do
		local afford = gold >= c.item.price
		c.grad.Color = ColorSequence.new(afford and BRIGHT.Green or BRIGHT.Grey, afford and BRIGHT.GreenDark or BRIGHT.GreyDark)
	end
end

local function buildShopList()
	if #cards == 0 then
		for index, item in ipairs(MerchantConfig.Items) do
			buildCard(index, item)
		end
	end
	refreshPrices()
end

-- ── Responsive layout: pick the column count that keeps the panel biggest ────
local baseScale = 1
local function applyLayout(viewport)
	local best
	-- Everything outside the card rows: header, ribbon, tray lips and scroll padding.
	local chromeH = TRAY_Y + TRAY_INSET * 2 + SCROLL_PAD_TOP + SCROLL_PAD_BOTTOM + TRAY_BOTTOM
	for _, cols in ipairs({ 5, 3, 2 }) do
		local rows = math.ceil(#MerchantConfig.Items / cols)
		local W = TRAY_X * 2 + TRAY_INSET * 2 + 12 + cols * CARD_W + (cols - 1) * GAP + 8
		local naturalH = chromeH + rows * CARD_H + (rows - 1) * GAP
		local minH = chromeH + CARD_H
		local s = math.min(1, (viewport.X - SCREEN_MARGIN_X) / W)
		local H = naturalH
		if H * s > viewport.Y - SCREEN_MARGIN_Y then
			H = math.max(minH, (viewport.Y - SCREEN_MARGIN_Y) / s)
			s = math.min(s, (viewport.Y - SCREEN_MARGIN_Y) / H)
		end
		if not best or s > best.s + 0.01 then
			best = { cols = cols, W = W, H = H, s = s }
		end
	end
	grid.FillDirectionMaxCells = best.cols
	window.Size = UDim2.fromOffset(best.W, best.H)
	baseScale = math.max(best.s, 0.3)
	panelScale.Scale = baseScale

	local wide = best.W >= WIDE_MIN
	local goldW = wide and GOLD_W_WIDE or GOLD_W_NARROW
	goldPill.Size = UDim2.fromOffset(goldW, 50)
	if wide then
		-- Gold rides in the header, just left of the close button; the ribbon spans the width.
		goldPill.AnchorPoint = Vector2.new(1, 0.5)
		goldPill.Position = UDim2.new(1, -(CLOSE + 34), 0, HEADER_H / 2)
		banner.Position = UDim2.fromOffset(TRAY_X, BANNER_Y)
		banner.Size = UDim2.new(1, -TRAY_X * 2, 0, BANNER_H)
		chrome.TitleLabel.Size = UDim2.new(0, best.W - TITLE_X - goldW - CLOSE - 62, 0, 58)
	else
		-- Narrow: the header keeps just the title; gold drops beside a chip-only ribbon.
		goldPill.AnchorPoint = Vector2.new(0, 0.5)
		goldPill.Position = UDim2.fromOffset(TRAY_X + 22, BANNER_Y + BANNER_H / 2)
		local bx = TRAY_X + 22 + goldW + 12
		banner.Position = UDim2.fromOffset(bx, BANNER_Y)
		banner.Size = UDim2.new(1, -(bx + TRAY_X), 0, BANNER_H)
		chrome.TitleLabel.Size = UDim2.new(0, best.W - TITLE_X - CLOSE - 34, 0, 58)
	end
	infoLabel.Visible = wide
	bannerSparkle.Visible = wide
	blessedChip.AnchorPoint = wide and Vector2.new(1, 0.5) or Vector2.new(0.5, 0.5)
	blessedChip.Position = wide and UDim2.new(1, -7, 0.5, 0) or UDim2.fromScale(0.5, 0.5)
	blessedChip.Size = wide and UDim2.new(0, 190, 1, -12) or UDim2.new(1, -12, 1, -12)
end
PanelChrome.onViewport(applyLayout)

local isOpen = false

local function setShopOpen(open)
	isOpen = open
	overlay.Visible = open
	window.Visible = open
	modal.Visible = open
	if open then
		buildShopList()
		TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.5 }):Play()
		panelScale.Scale = baseScale * 0.9
		TweenService:Create(panelScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = baseScale }):Play()
	else
		TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		noticeLabel.Visible = false
	end
end

closeBtn.Activated:Connect(function() setShopOpen(false) end)
overlay.Activated:Connect(function() setShopOpen(false) end)

MERCHANT_ACTION.OnClientEvent:Connect(function(action, param1, param2)
	if action == "OpenShop" then
		setShopOpen(true)
	elseif action == "PurchaseResult" then
		local isSuccess = param1
		local message = param2
		showNotice(message, isSuccess)
		if isOpen then
			buildShopList()
		end
	end
end)

local leaderstats = player:WaitForChild("leaderstats", 10)
if leaderstats then
	local goldVal = leaderstats:WaitForChild("Gold", 5)
	if goldVal then
		goldVal.Changed:Connect(function()
			if isOpen then buildShopList() end
		end)
	end
end

print("[MerchantGui] Safe area relic merchant UI enabled")
