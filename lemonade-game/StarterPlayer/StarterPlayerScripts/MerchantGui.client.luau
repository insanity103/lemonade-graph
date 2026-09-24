--// MerchantGui | THE RELIC BLACKSMITH'S COUNTER. One blade, rolled for your level.
-- The shop sells exactly ONE thing and the panel is built to say so: a single MYSTERY BLADE tile
-- on the left with one price button under it, and on the right the three things the player needs
-- to decide -- WHAT IT ROLLS (the pools and the real odds), WHAT IT COSTS (the price as a
-- function of level, quoted in kills and in minutes of the player's own measured gold/hour), and
-- THE TERMS (server-rolled, one prefix slot and its level ceiling, the bad-luck floor, no Robux).
-- The client NEVER decides anything: the offer table, every odd and the price all arrive from
-- MerchantSystem, which recomputes them from the player's own level before it takes any gold.
-- The sword model in the tile is a small part-built stand-in (the real meshes live in ServerStorage).
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
local RADIUS = 24 -- the window's corner radius
local HEADER_H = 84 -- the ember header band the title, gold and close button sit in
local CLOSE = 60
local BANNER_Y, BANNER_H = HEADER_H + 14, 48 -- the "one blade, rolled when you pay" ribbon
local TRAY_X, TRAY_BOTTOM = 18, 20 -- the dark inset tray the two columns sit in
local TRAY_Y = BANNER_Y + BANNER_H + 14
local TRAY_INSET = 10
local COL_GAP = 14
local BLADE_W = 296 -- the left column: the one thing the shop sells
local TILE_H = 208 -- its 3D tile
local BUY_H = 62 -- its one price button
local GOLD_W_WIDE, GOLD_W_NARROW = 220, 176
local WIDE_MIN = 760 -- narrower windows move the gold pill down beside the ribbon
local SCREEN_MARGIN_X, SCREEN_MARGIN_Y = 28, 110
local PANEL_W_WIDE, PANEL_H_WIDE = 952, 588
local PANEL_W_NARROW, PANEL_H_NARROW = 452, 760

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
window.Size = UDim2.fromOffset(PANEL_W_WIDE, PANEL_H_WIDE)
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
	size = UDim2.fromOffset(PANEL_W_WIDE, PANEL_H_WIDE),
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
-- Two crossed blades, the shop's crest. They are decoration, not listings: the blacksmith sells
-- one thing and it has no name until it is rolled.
for i, spec in ipairs({ { id = "Boss_Gorgon", tilt = -45 }, { id = "Boss_CelestialTitan", tilt = 45 } }) do
	local view = Instance.new("ViewportFrame")
	view.Name = "CrossedSword" .. i
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromScale(1, 1)
	view.ZIndex = titleIcon.ZIndex
	view.Parent = titleIcon
	PanelChrome.renderTool(view, buildSwordTool({ id = spec.id }), { tiltDeg = spec.tilt, yawDeg = 0, margin = 1.0 })
end
local TITLE_X = 90
chrome.TitleLabel.Position = UDim2.fromOffset(TITLE_X, HEADER_H / 2 - 1)

-- ── Gold balance (in the header) and the shop's terms (a ribbon under it) ────
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

local slotChip = Instance.new("Frame")
slotChip.Name = "PrefixSlotChip"
slotChip.AnchorPoint = Vector2.new(1, 0.5)
slotChip.Position = UDim2.new(1, -7, 0.5, 0)
slotChip.Size = UDim2.new(0, 190, 1, -12)
slotChip.BackgroundColor3 = Color3.new(1, 1, 1)
slotChip.ZIndex = 55
slotChip.Parent = banner
corner(slotChip, (BANNER_H - 12) / 2)
PanelChrome.gradient(slotChip, BRIGHT.Gold, BRIGHT.GoldDark)
PanelChrome.stroke(slotChip, BRIGHT.Outline, 3)
local slotChipLabel = PanelChrome.display(slotChip, {
	name = "PrefixSlots", text = "1 PREFIX SLOT", size = 22, stroke = 2.5, scaled = true, minSize = 12, zIndex = 56,
	pos = UDim2.fromOffset(8, 2), size2 = UDim2.new(1, -16, 1, -4),
})

local infoLabel = PanelChrome.display(banner, {
	name = "Info", text = "", size = 22, stroke = 2.5, scaled = true, minSize = 11,
	xAlign = Enum.TextXAlignment.Left, zIndex = 55,
	pos = UDim2.fromOffset(52, 3), size2 = UDim2.new(1, -52 - 190 - 18, 1, -6),
})
infoLabel.TextWrapped = true
local DEFAULT_INFO = "ONE BLADE \u{2014} ROLLED WHEN YOU PAY, FROM YOUR LEVEL'S POOLS"
infoLabel.Text = DEFAULT_INFO

-- Notice for a refused purchase (not enough gold, too far away): a pill just BELOW the panel. It
-- used to ride the panel's bottom edge, straight across the buy button (2026-09-24 recording).
local noticeLabel = Instance.new("TextLabel")
noticeLabel.Name = "NoticeLabel"
noticeLabel.AnchorPoint = Vector2.new(0.5, 0)
noticeLabel.Position = UDim2.new(0.5, 0, 1, 14)
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

-- ══════════════════════════════════════════════════════════════════════════════
-- THE COUNTER. Two columns on one dark tray: the ONE thing on the left, the terms
-- of the roll on the right. Nothing here is a list.
-- ══════════════════════════════════════════════════════════════════════════════
local tray = Instance.new("Frame")
tray.Name = "Tray"
tray.Position = UDim2.fromOffset(TRAY_X, TRAY_Y)
tray.Size = UDim2.new(1, -TRAY_X * 2, 1, -(TRAY_Y + TRAY_BOTTOM))
tray.ZIndex = 52
tray.Parent = modal
PanelChrome.insetTray(tray, { top = THEME.TrayTop, bottom = THEME.TrayBottom, radius = 20, zIndex = 52 })

local function formatGold(num)
	return tostring(math.floor(num or 0)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function currentGold()
	local leaderstats = player:FindFirstChild("leaderstats")
	return (leaderstats and leaderstats:FindFirstChild("Gold")) and leaderstats.Gold.Value or (player:GetAttribute("Gold") or 0)
end

local function currentLevel()
	local leaderstats = player:FindFirstChild("leaderstats")
	return (leaderstats and leaderstats:FindFirstChild("Level")) and leaderstats.Level.Value or (player:GetAttribute("Level") or 1)
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

-- ── LEFT COLUMN: the one purchasable thing ───────────────────────────────────
local bladeCol = Instance.new("Frame")
bladeCol.Name = "TheOneThing"
bladeCol.BackgroundTransparency = 1
bladeCol.Position = UDim2.fromOffset(TRAY_INSET, TRAY_INSET)
bladeCol.Size = UDim2.fromOffset(BLADE_W, 100)
bladeCol.ZIndex = 53
bladeCol.Parent = tray

local tile = Instance.new("Frame")
tile.Name = "MysteryTile"
tile.Size = UDim2.new(1, 0, 0, TILE_H)
tile.ZIndex = 53
tile.Parent = bladeCol
corner(tile, 20)
PanelChrome.lootTile(tile, "Epic", { radius = 20, zIndex = 53, glowY = 0.5 })
local tileScale = Instance.new("UIScale")
tileScale.Parent = tile

local bladeView = Instance.new("ViewportFrame")
bladeView.Name = "BladeRender"
bladeView.BackgroundTransparency = 1
bladeView.Position = UDim2.fromOffset(6, 10)
bladeView.Size = UDim2.new(1, -12, 1, -16)
bladeView.ZIndex = 54
bladeView.Parent = tile
PanelChrome.renderTool(bladeView, buildSwordTool({ id = "Mystery" }),
	{ tiltDeg = 45, yawDeg = 0, margin = 0.9, ambient = Color3.fromRGB(205, 205, 218) })

-- The blade is unknown until the gold leaves: the tile wears a question mark, not a name.
PanelChrome.display(tile, {
	name = "Question", text = "?", size = 110, stroke = 5, zIndex = 56,
	pos = UDim2.fromOffset(0, 0), size2 = UDim2.fromScale(1, 1),
})

-- "1 of N swords" -- the roster this one roll reaches into.
local reachChip = Instance.new("Frame")
reachChip.Name = "Reach"
reachChip.AnchorPoint = Vector2.new(0.5, 0.5)
reachChip.Position = UDim2.new(0.5, 0, 1, -4)
reachChip.Size = UDim2.fromOffset(0, 28)
reachChip.AutomaticSize = Enum.AutomaticSize.X
reachChip.BackgroundColor3 = Color3.new(1, 1, 1)
reachChip.ZIndex = 57
reachChip.Parent = tile
corner(reachChip, 14)
PanelChrome.gradient(reachChip, BRIGHT.Gold, BRIGHT.GoldDark)
PanelChrome.stroke(reachChip, BRIGHT.Outline, 2.5)
local reachPad = Instance.new("UIPadding")
reachPad.PaddingLeft = UDim.new(0, 12)
reachPad.PaddingRight = UDim.new(0, 12)
reachPad.Parent = reachChip
local reachText = PanelChrome.display(reachChip, { text = "1 OF ? SWORDS", size = 16, stroke = 2, zIndex = 58 })
reachText.Size = UDim2.fromScale(0, 1)
reachText.AutomaticSize = Enum.AutomaticSize.X

local bladeName = PanelChrome.display(bladeCol, {
	name = "BladeName", text = "MYSTERY BLADE", size = 30, stroke = 3, scaled = true, minSize = 14,
	pos = UDim2.fromOffset(0, TILE_H + 10), size2 = UDim2.new(1, 0, 0, 36), zIndex = 54,
})
bladeName.TextColor3 = Color3.new(1, 1, 1)

local bladeSub = PanelChrome.display(bladeCol, {
	name = "BladeSub", text = "rolled at the moment you pay", size = 19, stroke = 2.5, scaled = true, minSize = 11,
	pos = UDim2.fromOffset(0, TILE_H + 46), size2 = UDim2.new(1, 0, 0, 26), zIndex = 54,
})
bladeSub.TextColor3 = Color3.fromRGB(255, 238, 190)

local bandLabel = PanelChrome.display(bladeCol, {
	name = "Band", text = "", size = 22, stroke = 2.5, scaled = true, minSize = 12,
	pos = UDim2.fromOffset(0, TILE_H + 74), size2 = UDim2.new(1, 0, 0, 30), zIndex = 54,
})
bandLabel.TextColor3 = Color3.fromRGB(190, 240, 255)

local rangeLabel = PanelChrome.display(bladeCol, {
	name = "Range", text = "", size = 30, stroke = 3, scaled = true, minSize = 13,
	pos = UDim2.fromOffset(0, TILE_H + 106), size2 = UDim2.new(1, 0, 0, 38), zIndex = 54,
})

local BUY_Y = TILE_H + 152
local buyBtn, buyLabel, buyGrad = PanelChrome.chunkyButton(bladeCol, {
	name = "BuyButton", text = "---", size = UDim2.new(1, 0, 0, BUY_H),
	pos = UDim2.fromOffset(0, BUY_Y), textSize = 32, zIndex = 54, radius = 18, strokeThickness = 3.5,
})
buyLabel.Position = UDim2.fromOffset(52, 3)
buyLabel.Size = UDim2.new(1, -62, 1, -6)
coinIcon(buyBtn, 52, UDim2.new(0, 2, 0.5, 0), nil, 56)

local buyHint = PanelChrome.display(bladeCol, {
	name = "BuyHint", text = "", size = 17, stroke = 2, scaled = true, minSize = 10,
	pos = UDim2.fromOffset(0, BUY_Y + BUY_H + 4), size2 = UDim2.new(1, 0, 0, 24), zIndex = 54,
})
buyHint.TextColor3 = Color3.fromRGB(226, 234, 250)
local BLADE_COL_H = BUY_Y + BUY_H + 30
bladeCol.Size = UDim2.fromOffset(BLADE_W, BLADE_COL_H)

-- ── RIGHT COLUMN: what it rolls, what it costs, the terms ────────────────────
local terms = Instance.new("ScrollingFrame")
terms.Name = "Terms"
terms.BackgroundTransparency = 1
terms.BorderSizePixel = 0
terms.Position = UDim2.fromOffset(TRAY_INSET + BLADE_W + COL_GAP, TRAY_INSET)
terms.Size = UDim2.new(1, -(TRAY_INSET * 2 + BLADE_W + COL_GAP), 1, -TRAY_INSET * 2)
terms.ScrollBarThickness = 8
terms.ScrollBarImageColor3 = Color3.fromRGB(214, 222, 240)
terms.CanvasSize = UDim2.fromOffset(0, 0)
terms.AutomaticCanvasSize = Enum.AutomaticSize.Y
terms.ScrollingDirection = Enum.ScrollingDirection.Y
terms.ZIndex = 53
terms.Parent = tray

local termsList = Instance.new("UIListLayout")
termsList.Padding = UDim.new(0, 12)
termsList.SortOrder = Enum.SortOrder.LayoutOrder
termsList.Parent = terms
local termsPad = Instance.new("UIPadding")
termsPad.PaddingRight = UDim.new(0, 10)
termsPad.Parent = terms

-- A parchment card with a stroked heading and a column of rows under it.
local function card(order, heading)
	local frame = Instance.new("Frame")
	frame.Name = heading:gsub("%W", "")
	frame.Size = UDim2.new(1, 0, 0, 40)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	frame.LayoutOrder = order
	frame.ZIndex = 54
	frame.Parent = terms
	corner(frame, 16)
	PanelChrome.gradient(frame, Color3.fromRGB(255, 251, 240), Color3.fromRGB(238, 226, 200))
	PanelChrome.stroke(frame, BRIGHT.Outline, 3)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = frame

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame

	local title = PanelChrome.display(frame, {
		name = "Heading", text = heading, size = 22, stroke = 2.5,
		xAlign = Enum.TextXAlignment.Left, size2 = UDim2.new(1, 0, 0, 28), zIndex = 55,
	})
	title.LayoutOrder = 0
	title.TextColor3 = Color3.fromRGB(255, 244, 214)
	return frame
end

-- One row: a left label, a right value, optional colour chip at the far left.
local function row(parent, order, left, right, opts)
	opts = opts or {}
	local frame = Instance.new("Frame")
	frame.Name = "Row"
	frame.Size = UDim2.new(1, 0, 0, opts.height or 26)
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = order
	frame.ZIndex = 55
	frame.Parent = parent

	local x = 0
	if opts.chip then
		local chip = Instance.new("Frame")
		chip.Name = "Chip"
		chip.AnchorPoint = Vector2.new(0, 0.5)
		chip.Position = UDim2.new(0, 0, 0.5, 0)
		chip.Size = UDim2.fromOffset(96, 22)
		chip.BackgroundColor3 = opts.chip
		chip.ZIndex = 56
		chip.Parent = frame
		corner(chip, 11)
		PanelChrome.stroke(chip, BRIGHT.Outline, 2)
		PanelChrome.display(chip, { text = left, size = 15, stroke = 2, zIndex = 57 })
		x = 104
	else
		-- A row with no value on the right (a note, a spacer) gives the label the whole width.
		local split = (right == nil or right == "") and 1 or 0.55
		-- The ink goes in as `color`, so PanelChrome.display leaves dark text unoutlined. Set after
		-- the fact, it drew brown text inside a dark outline, and at this size that is a smudge.
		local l = PanelChrome.display(frame, {
			name = "Left", text = left, size = opts.size or 19, stroke = opts.stroke or 2,
			color = opts.leftColor or Color3.fromRGB(70, 52, 34),
			xAlign = Enum.TextXAlignment.Left, yAlign = Enum.TextYAlignment.Center,
			size2 = UDim2.new(split, -6, 1, 0), zIndex = 56,
		})
		l.TextColor3 = opts.leftColor or Color3.fromRGB(70, 52, 34)
		l.TextWrapped = opts.wrap == true
		x = -1
	end

	if right ~= nil and right ~= "" then
		local r = PanelChrome.display(frame, {
			name = "Right", text = right, size = opts.size or 19, stroke = opts.stroke or 2,
			color = opts.rightColor or Color3.fromRGB(28, 32, 54),
			xAlign = x >= 0 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
			yAlign = Enum.TextYAlignment.Center,
			pos = x >= 0 and UDim2.fromOffset(x, 0) or UDim2.fromScale(0.55, 0),
			size2 = x >= 0 and UDim2.new(1, -x, 1, 0) or UDim2.new(0.45, 0, 1, 0), zIndex = 56,
		})
		r.TextColor3 = opts.rightColor or Color3.fromRGB(28, 32, 54)
	end
	return frame
end

local rollsCard = card(1, "WHAT IT ROLLS")
local costCard = card(2, "WHAT IT COSTS")
local termsCard = card(3, "THE TERMS")

local RARITY_CHIP = {
	Common = Color3.fromRGB(150, 158, 176), Uncommon = Color3.fromRGB(96, 196, 108),
	Rare = Color3.fromRGB(78, 152, 246), Epic = Color3.fromRGB(176, 108, 240),
	Legendary = Color3.fromRGB(255, 184, 54),
}

local function clearRows(frame)
	for _, child in ipairs(frame:GetChildren()) do
		if child.Name == "Row" then child:Destroy() end
	end
end

local function pct(p)
	if p >= 0.1 then return string.format("%.0f%%", p * 100) end
	if p >= 0.01 then return string.format("%.1f%%", p * 100) end
	return string.format("%.2f%%", p * 100)
end

local function minutes(m)
	if m < 1 then return "under a minute" end
	if m < 90 then return string.format("%.0f min", m) end
	return string.format("%.1f h", m / 60)
end

-- ── The offer: everything the panel shows comes from this one server table ───
local offer = nil

local function applyOffer(newOffer)
	if typeof(newOffer) ~= "table" then return end
	offer = newOffer

	bandLabel.Text = string.format("LEVEL %d  \u{2022}  %s", offer.level or 1, offer.bandName or "?")
	rangeLabel.Text = string.format("x%.2f  \u{2013}  x%.2f", offer.minBase or 0, offer.maxBase or 0)
	rangeLabel.TextColor3 = Color3.fromRGB(255, 226, 140)
	reachText.Text = string.format("1 OF %d SWORDS", offer.swordCount or 0)
	buyLabel.Text = formatGold(offer.price or 0)

	-- WHAT IT ROLLS: the pools, then the real rarity ladder with the band each rarity can land in.
	clearRows(rollsCard)
	local n = 0
	for _, pool in ipairs(offer.pools or {}) do
		n += 1
		row(rollsCard, n, string.format("%s pool", pool.name),
			string.format("%s  \u{2022}  %d swords  \u{2022}  x%.2f-x%.2f",
				pct(pool.weight), pool.swords, pool.minBase, pool.maxBase), { size = 17 })
	end
	n += 1
	row(rollsCard, n, "", "", { height = 6 })
	n += 1
	row(rollsCard, n, "RARITY", "CHANCE   (1 IN)   DAMAGE BAND",
		{ size = 15, leftColor = Color3.fromRGB(120, 100, 70), rightColor = Color3.fromRGB(120, 100, 70) })
	for _, odd in ipairs(offer.rarityOdds or {}) do
		n += 1
		row(rollsCard, n, string.upper(odd.rarity),
			string.format("%s   (1 in %d)   x%.2f-x%.2f", pct(odd.p), odd.oneIn, odd.minBase, odd.maxBase),
			{ chip = RARITY_CHIP[odd.rarity] or RARITY_CHIP.Common, size = 17 })
	end
	n += 1
	row(rollsCard, n, string.format("Stat jitter \u{00B1}%.0f%% on the rolled base, as every drop gets.",
		(offer.jitter or 0) * 100), "", { size = 15, leftColor = Color3.fromRGB(120, 100, 70) })

	-- WHAT IT COSTS: the price as a function of level, in four units the player already spends in.
	clearRows(costCard)
	local c = 0
	c += 1
	row(costCard, c, string.format("Price at level %d", offer.level or 1),
		formatGold(offer.price) .. " gold", { size = 20, stroke = 2.5, rightColor = Color3.fromRGB(196, 92, 20) })
	c += 1
	row(costCard, c, "  = price units at this tier",
		string.format("%.1f x %s", offer.priceStrikes or 0, formatGold(offer.strikeRef or 0)), { size = 17 })
	c += 1
	row(costCard, c, "  = kills at your level",
		string.format("%d kills x %s gold", offer.priceKills or 0, formatGold(offer.goldPerKill or 0)), { size = 17 })
	c += 1
	if offer.goldPerHour and offer.goldPerHour > 0 then
		row(costCard, c, "  = your gold per hour (measured)",
			string.format("%s /h  \u{2192}  %s", formatGold(offer.goldPerHour), minutes((offer.price or 0) / offer.goldPerHour * 60)),
			{ size = 17 })
	else
		row(costCard, c, "  = your gold per hour", "measuring\u{2026} (farm a little)",
			{ size = 17, rightColor = Color3.fromRGB(120, 100, 70) })
	end
	c += 1
	row(costCard, c, "", "", { height = 4 })
	c += 1
	row(costCard, c, "The price is a function of your level only. It is read off your Level the moment you press buy \u{2014} the client never sends a price.",
		"", { size = 15, leftColor = Color3.fromRGB(120, 100, 70), wrap = true, height = 38 })

	-- THE TERMS.
	clearRows(termsCard)
	local slotCount = offer.prefixSlots or 1
	slotChipLabel.Text = string.format("%d PREFIX SLOT%s", slotCount, slotCount == 1 and "" or "S")
	local t = 0
	t += 1
	row(termsCard, t, "Rolled", "on the server, when the gold leaves", { size = 17 })
	t += 1
	row(termsCard, t, "Re-rolls", "per purchase \u{2014} never on a timer or a visit", { size = 17 })
	t += 1
	row(termsCard, t, "Prefix slots", string.format("%d \u{2014} best rung at your level: %s",
		offer.prefixSlots or 1, tostring(offer.prefixCeilingName or "?")), { size = 17 })
	t += 1
	row(termsCard, t, "Bad-luck floor",
		string.format("%s guaranteed within %d buys", offer.pityFloor or "Rare", offer.pityIn or offer.pityPurchases or 0), { size = 17 })
	t += 1
	row(termsCard, t, "Robux", "none, anywhere on this counter", { size = 17 })
	t += 1
	row(termsCard, t, string.format("The same %d swords the drops give, from the pools of the zone you are in now.", offer.swordCount or 0),
		"", { size = 15, leftColor = Color3.fromRGB(120, 100, 70), wrap = true, height = 34 })

	-- Affordable goes green; the rest stays grey (still pressable: the server answers).
	local gold = currentGold()
	goldLabel.Text = formatGold(gold)
	local afford = gold >= (offer.price or math.huge)
	buyGrad.Color = ColorSequence.new(afford and BRIGHT.Green or BRIGHT.Grey, afford and BRIGHT.GreenDark or BRIGHT.GreyDark)
	if afford then
		buyHint.Text = "BUY THE BLADE"
		buyHint.TextColor3 = Color3.fromRGB(180, 255, 190)
	else
		local short = (offer.price or 0) - gold
		buyHint.Text = string.format("%s gold short", formatGold(short))
		buyHint.TextColor3 = Color3.fromRGB(255, 196, 186)
	end
end

-- Until the server answers, the panel shows the shipped offer for the level the client can see.
-- Same module, same numbers; the server's copy replaces it the moment it arrives.
local function fallbackOffer()
	local ok, result = pcall(MerchantConfig.OfferForLevel, currentLevel())
	if ok then return result end
	return nil
end

buyBtn.Activated:Connect(function()
	MERCHANT_ACTION:FireServer("BuyBlade")
end)
tile.MouseEnter:Connect(function()
	tileScale.Scale = 1.04
	infoLabel.Text = "THE BLADE HAS NO NAME UNTIL YOU PAY FOR IT"
end)
tile.MouseLeave:Connect(function()
	tileScale.Scale = 1
	infoLabel.Text = DEFAULT_INFO
end)

-- ── Responsive layout: side by side when there is room, stacked when there is not ──
local baseScale = 1
local function applyLayout(viewport)
	local wideS = math.min(1, (viewport.X - SCREEN_MARGIN_X) / PANEL_W_WIDE,
		(viewport.Y - SCREEN_MARGIN_Y) / PANEL_H_WIDE)
	local narrowS = math.min(1, (viewport.X - SCREEN_MARGIN_X) / PANEL_W_NARROW,
		(viewport.Y - SCREEN_MARGIN_Y) / PANEL_H_NARROW)
	local stacked = narrowS > wideS + 0.02
	local W = stacked and PANEL_W_NARROW or PANEL_W_WIDE
	local H = stacked and PANEL_H_NARROW or PANEL_H_WIDE
	window.Size = UDim2.fromOffset(W, H)
	baseScale = math.max(stacked and narrowS or wideS, 0.3)
	panelScale.Scale = baseScale

	if stacked then
		bladeCol.Position = UDim2.fromOffset(TRAY_INSET, TRAY_INSET)
		bladeCol.Size = UDim2.new(1, -TRAY_INSET * 2, 0, BLADE_COL_H)
		terms.Position = UDim2.fromOffset(TRAY_INSET, TRAY_INSET + BLADE_COL_H + COL_GAP)
		terms.Size = UDim2.new(1, -TRAY_INSET * 2, 1, -(TRAY_INSET * 2 + BLADE_COL_H + COL_GAP))
	else
		bladeCol.Position = UDim2.fromOffset(TRAY_INSET, TRAY_INSET)
		bladeCol.Size = UDim2.fromOffset(BLADE_W, BLADE_COL_H)
		terms.Position = UDim2.fromOffset(TRAY_INSET + BLADE_W + COL_GAP, TRAY_INSET)
		terms.Size = UDim2.new(1, -(TRAY_INSET * 2 + BLADE_W + COL_GAP), 1, -TRAY_INSET * 2)
	end

	local wide = W >= WIDE_MIN
	local goldW = wide and GOLD_W_WIDE or GOLD_W_NARROW
	goldPill.Size = UDim2.fromOffset(goldW, 50)
	if wide then
		goldPill.AnchorPoint = Vector2.new(1, 0.5)
		goldPill.Position = UDim2.new(1, -(CLOSE + 34), 0, HEADER_H / 2)
		banner.Position = UDim2.fromOffset(TRAY_X, BANNER_Y)
		banner.Size = UDim2.new(1, -TRAY_X * 2, 0, BANNER_H)
		chrome.TitleLabel.Size = UDim2.new(0, W - TITLE_X - goldW - CLOSE - 62, 0, 58)
	else
		goldPill.AnchorPoint = Vector2.new(0, 0.5)
		goldPill.Position = UDim2.fromOffset(TRAY_X + 22, BANNER_Y + BANNER_H / 2)
		local bx = TRAY_X + 22 + goldW + 12
		banner.Position = UDim2.fromOffset(bx, BANNER_Y)
		banner.Size = UDim2.new(1, -(bx + TRAY_X), 0, BANNER_H)
		chrome.TitleLabel.Size = UDim2.new(0, W - TITLE_X - CLOSE - 34, 0, 58)
	end
	infoLabel.Visible = wide
	bannerSparkle.Visible = wide
	slotChip.AnchorPoint = wide and Vector2.new(1, 0.5) or Vector2.new(0.5, 0.5)
	slotChip.Position = wide and UDim2.new(1, -7, 0.5, 0) or UDim2.fromScale(0.5, 0.5)
	slotChip.Size = wide and UDim2.new(0, 190, 1, -12) or UDim2.new(1, -12, 1, -12)
end
PanelChrome.onViewport(applyLayout)

local isOpen = false

local motion = {
	frame = window, scale = panelScale, dim = overlay, dimTo = 0.5,
	tiles = function() return { bladeCol, terms } end,
}

local function setShopOpen(open)
	isOpen = open
	if open then
		overlay.Visible = true
		window.Visible = true
		modal.Visible = true
		applyOffer(offer or fallbackOffer())
		MERCHANT_ACTION:FireServer("RequestOffer")
		PanelChrome.openMotion(motion)
	else
		noticeLabel.Visible = false
		PanelChrome.closeMotion(motion, function()
			overlay.Visible = false
			window.Visible = false
			modal.Visible = false
		end)
	end
end

closeBtn.Activated:Connect(function() setShopOpen(false) end)
overlay.Activated:Connect(function() setShopOpen(false) end)

MERCHANT_ACTION.OnClientEvent:Connect(function(action, param1, param2, param3)
	if action == "OpenShop" then
		applyOffer(param1 or fallbackOffer())
		setShopOpen(true)
	elseif action == "Offer" then
		applyOffer(param1)
	elseif action == "PurchaseResult" then
		applyOffer(param3 or offer)
		if param1 then
			-- Bought: get out of the way. The reveal (SwordDropToast) draws below modal panels, so with
			-- the counter left open every sword was rolled, named and graded behind it, and the only
			-- sign of what you got was a pill over the buy button. E at the counter opens it again.
			if isOpen then setShopOpen(false) end
		else
			showNotice(param2, false)
		end
	end
end)

local leaderstats = player:WaitForChild("leaderstats", 10)
if leaderstats then
	for _, statName in ipairs({ "Gold", "Level" }) do
		local stat = leaderstats:WaitForChild(statName, 5)
		if stat then
			stat.Changed:Connect(function()
				if isOpen then MERCHANT_ACTION:FireServer("RequestOffer") end
			end)
		end
	end
end

print("[MerchantGui] Relic Blacksmith counter enabled: one blade, rolled for your level")
