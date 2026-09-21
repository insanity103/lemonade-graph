--// VaultGui  (client UI for the Vaultkeeper: store and retrieve relic swords)
-- Bright storage window in the Inventory's family: a light thick-outlined panel with the title
-- over its top-left edge beside a rendered treasure chest, a rarity-filter rail down the left
-- with red count badges, and two trays of square sword tiles -- the Backpack and the Vault
-- (plus empty wells for the free slots). Each tile is the Inventory's loot tile: a big 3D
-- render of the sword over its rarity face, rating and multiplier as stroked numbers, the
-- name on a strip along the bottom. Tapping a tile selects it (a direction chip shows where
-- it will go); one chunky Store / Take bar under each tray, or the centre arrows, move the
-- pick. The rolled modifiers live in a hover tooltip.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local VAULT_ACTION = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("VaultAction")
local Config = ReplicatedStorage:WaitForChild("Config")
local SwordValue = require(Config:WaitForChild("SwordValue"))
local VaultConfig = require(Config:WaitForChild("VaultConfig"))
local WealthLadder = require(Config:WaitForChild("WealthLadder"))
local BossWeapons = require(Config:WaitForChild("BossWeapons"))
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))

local BRIGHT = PanelChrome.BRIGHT
local RARITY_TILE = PanelChrome.RARITY_TILE
local corner = PanelChrome.corner
local TROPHY_ICON = "rbxassetid://77830885604568" -- the Inventory's rating trophy
local BAG_ICON = "rbxassetid://118915534669949" -- the Items button's backpack

-- [TUNING] design-space sizes; the whole window is scaled with one UIScale.
local TILE = 112 -- square sword tile
local GAP, VGAP = 12, 16
local TOP_PAD = 26 -- room above the first row for blades that overhang their tile
local BAR_H = 88 -- the Store / Take bar under each tray
local BTN_W, BTN_H = 148, 58
local ROWS_VISIBLE = 3.6 -- a partial last row tells the player the backpack scrolls
local HEADER_H = 64 -- the title band; the title itself rides over the panel's top edge
local SEC_H = 54 -- a tray's heading row
local X0 = 88 -- content starts right of the rail
local EDGE = 18
local TRAY_PAD = 12
local SCROLLBAR = 12
local MID_GAP = 64 -- between the two trays on wide screens; holds the transfer arrows
local RAIL_X, RAIL_W, TAB = -22, 94, 70
local CLOSE = 60
local WEALTH_W = 210
local RARITIES = { "All", "Legendary", "Epic", "Rare", "Uncommon", "Common" }

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VaultGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 21
screenGui.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.5
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Visible = false
overlay.ZIndex = 1
overlay.Parent = screenGui

-- The window holds the panel and its drop shadow, so one UIScale sizes both.
local window = Instance.new("Frame")
window.Name = "VaultWindow"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.5)
window.Size = UDim2.fromOffset(1224, 676)
window.BackgroundTransparency = 1
window.ZIndex = 2
window.Parent = overlay
local panelScale = Instance.new("UIScale")
panelScale.Parent = window

local dropShadow = Instance.new("Frame")
dropShadow.Name = "DropShadow"
dropShadow.AnchorPoint = Vector2.new(0.5, 0.5)
dropShadow.Position = UDim2.new(0.5, 0, 0.5, 12)
dropShadow.Size = UDim2.new(1, 12, 1, 12)
dropShadow.BackgroundColor3 = Color3.fromRGB(8, 8, 18)
dropShadow.BackgroundTransparency = 0.4
dropShadow.BorderSizePixel = 0
dropShadow.ZIndex = 2
dropShadow.Parent = window
corner(dropShadow, 28)

local chrome = PanelChrome.buildBright({ name = "Modal", title = "Vault", titleSize = 50, closeSize = CLOSE })
local modal = chrome.Frame
modal.Size = UDim2.fromScale(1, 1)
modal.ZIndex = 3
modal.Parent = window
local closeBtn = chrome.CloseButton
chrome.TitleLabel.Position = UDim2.fromOffset(84, -2)

-- ── 3D helpers ───────────────────────────────────────────────────────────────
local function part(parent, className, name, size, cf, color, material, shape)
	local p = Instance.new(className)
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

-- A cartoon treasure chest built from parts: wooden body, barrel lid, gold bands and lock.
local function renderChest(viewport)
	for _, c in ipairs(viewport:GetChildren()) do c:Destroy() end
	viewport.Ambient = Color3.fromRGB(210, 206, 200)
	viewport.LightColor = Color3.fromRGB(255, 250, 235)
	viewport.LightDirection = Vector3.new(-0.6, -1, -0.8)
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local wood, woodDark = Color3.fromRGB(178, 98, 44), Color3.fromRGB(118, 60, 26)
	local gold, goldDark = Color3.fromRGB(255, 210, 56), Color3.fromRGB(214, 140, 20)
	local cyl = Enum.PartType.Cylinder
	part(world, "Part", "Body", Vector3.new(4, 2.2, 2.8), CFrame.new(0, 0, 0), wood)
	part(world, "Part", "Lid", Vector3.new(4, 2.8, 2.8), CFrame.new(0, 1.1, 0), woodDark, nil, cyl)
	part(world, "Part", "Base", Vector3.new(4.2, 0.35, 3.0), CFrame.new(0, -1.05, 0), goldDark)
	for _, x in ipairs({ -1.45, 1.45 }) do
		part(world, "Part", "Band", Vector3.new(0.42, 2.25, 2.9), CFrame.new(x, 0, 0), gold)
		part(world, "Part", "LidBand", Vector3.new(0.44, 2.92, 2.92), CFrame.new(x, 1.1, 0), gold, nil, cyl)
	end
	part(world, "Part", "LidRim", Vector3.new(4.1, 0.3, 2.95), CFrame.new(0, 1.1, 0), goldDark)
	part(world, "Part", "Lock", Vector3.new(0.9, 1.1, 0.3), CFrame.new(0, 0.85, 1.45), gold)
	part(world, "Part", "Keyhole", Vector3.new(0.22, 0.42, 0.1), CFrame.new(0, 0.78, 1.62), Color3.fromRGB(40, 24, 14))
	part(world, "Part", "Gem", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 2.55, 0.9), Color3.fromRGB(90, 220, 255), Enum.Material.Neon, Enum.PartType.Ball)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local target = Vector3.new(0, 0.7, 0)
	camera.CFrame = CFrame.lookAt(target + Vector3.new(4.6, 3.4, 8.2).Unit * 12.6, target)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

-- Title badge: the chest, big and tilted over the panel's top-left corner.
local titleIcon = chrome.TitleIcon
titleIcon.Image = ""
titleIcon.Size = UDim2.fromOffset(108, 108)
titleIcon.Position = UDim2.fromOffset(-30, -4)
titleIcon.Rotation = -6
local titleChest = Instance.new("ViewportFrame")
titleChest.Name = "Chest"
titleChest.BackgroundTransparency = 1
titleChest.Size = UDim2.fromScale(1, 1)
titleChest.ZIndex = titleIcon.ZIndex
titleChest.Parent = titleIcon
renderChest(titleChest)

-- Stand-in sword for a vault entry whose model is not on the client (the real boss meshes
-- live in ServerStorage): Handle grip with the blade along -Z, tinted with its tier's colour.
local function buildStandInSword(tier)
	local weapon = BossWeapons.GetByTier(tier)
	local bladeColor = weapon.color or Color3.fromRGB(200, 206, 218)
	local tool = Instance.new("Tool")
	local handle = part(tool, "Part", "Handle", Vector3.new(0.44, 0.44, 1.0), CFrame.new(), Color3.fromRGB(70, 44, 32))
	local function add(name, size, c0, color, material, shape, className)
		local p = part(tool, className or "Part", name, size, CFrame.new(), color, material, shape)
		p.Anchored = false
		local w = Instance.new("Weld")
		w.Part0 = handle
		w.Part1 = p
		w.C0 = c0
		w.Parent = handle
	end
	local len, w, t = 2.45, 1.1, 0.26
	local bladeZ = -0.8 - len / 2
	add("Pommel", Vector3.new(0.66, 0.66, 0.66), CFrame.new(0, 0, 0.68), bladeColor, Enum.Material.Neon, Enum.PartType.Ball)
	add("Guard", Vector3.new(1.95, 0.4, 0.44), CFrame.new(0, 0, -0.6), Color3.fromRGB(214, 150, 30), Enum.Material.Metal)
	add("Blade", Vector3.new(w, t, len), CFrame.new(0, 0, bladeZ), Color3.fromRGB(214, 220, 232), Enum.Material.Metal)
	add("Fuller", Vector3.new(w * 0.3, t + 0.04, len * 0.82), CFrame.new(0, 0, bladeZ + len * 0.06), bladeColor, Enum.Material.Neon)
	local tipLen = w * 0.75
	for _, side in ipairs({ 1, -1 }) do
		add("Tip", Vector3.new(t, w / 2, tipLen), CFrame.new(side * w / 4, 0, bladeZ - len / 2 - tipLen / 2)
			* CFrame.Angles(0, 0, side == 1 and -math.pi / 2 or math.pi / 2), Color3.fromRGB(214, 220, 232), Enum.Material.Metal, nil, "WedgePart")
	end
	return tool
end

local function carriedTools()
	local out = {}
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") then table.insert(out, tool) end
			end
		end
	end
	return out
end

-- The Tool to draw for a card: the carried sword itself, or for a vault entry a carried sword
-- of the same boss tier (same mesh), else the part-built stand-in.
local function toolFor(info, carried)
	if info.toolName then
		for _, tool in ipairs(carried) do
			if tool.Name == info.toolName then return tool, false end
		end
	end
	for _, tool in ipairs(carried) do
		if tool:GetAttribute("BossDrop") == true and tonumber(tool:GetAttribute("BossTier")) == tonumber(info.tier) then
			return tool, false
		end
	end
	return buildStandInSword(info.tier), true
end

-- Tile label for long rolled names: the last one or two words, which name the sword itself
-- (same rule as the Inventory's tiles). The tooltip always shows the full name.
local function tileName(name)
	if #name <= 14 then return name end
	local words = string.split(name, " ")
	local two = if #words >= 2 then words[#words - 1] .. " " .. words[#words] else name
	return if #two <= 15 then two else words[#words]
end

-- ── Small shape icons ────────────────────────────────────────────────────────
-- A cut gem: a square turned 45 degrees in the rarity's gradient, with a glossy facet.
local function gemIcon(parent, size, rarity, z)
	local t = RARITY_TILE[rarity] or RARITY_TILE.Common
	local gem = Instance.new("Frame")
	gem.Name = "Gem"
	gem.AnchorPoint = Vector2.new(0.5, 0.5)
	gem.Position = UDim2.fromScale(0.5, 0.5)
	gem.Size = UDim2.fromOffset(size, size)
	gem.Rotation = 45
	gem.BackgroundColor3 = Color3.new(1, 1, 1)
	gem.BorderSizePixel = 0
	gem.ZIndex = z
	gem.Parent = parent
	corner(gem, math.floor(size * 0.22))
	PanelChrome.gradient(gem, t.top, t.bottom).Rotation = 45
	PanelChrome.stroke(gem, BRIGHT.Outline, 3)
	local facet = Instance.new("Frame")
	facet.Name = "Facet"
	facet.Position = UDim2.fromScale(0.16, 0.16)
	facet.Size = UDim2.fromScale(0.38, 0.38)
	facet.BackgroundColor3 = Color3.new(1, 1, 1)
	facet.BackgroundTransparency = 0.2
	facet.BorderSizePixel = 0
	facet.ZIndex = z
	facet.Parent = gem
	corner(facet, 4)
	return gem
end

local function trophy(parent, size, pos, z, anchor)
	local img = Instance.new("ImageLabel")
	img.Name = "Trophy"
	img.BackgroundTransparency = 1
	img.Image = TROPHY_ICON
	img.ScaleType = Enum.ScaleType.Fit
	img.Size = UDim2.fromOffset(size, size)
	img.AnchorPoint = anchor or Vector2.new(0, 0.5)
	img.Position = pos
	img.ZIndex = z
	img.Parent = parent
	return img
end

-- Chunky arrow in a round badge, drawn from bars: a shaft and a two-stroke head. A button
-- when `button` is set (the centre transfer arrows), else a plain badge (the tile chips).
local function arrowBadge(parent, pointRight, top, bottom, z, size, button)
	size = size or 48
	local badge = Instance.new(button and "TextButton" or "Frame")
	badge.Name = pointRight and "StoreArrow" or "TakeArrow"
	if button then
		badge.Text = ""
		badge.AutoButtonColor = false
	end
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Size = UDim2.fromOffset(size, size)
	badge.BackgroundColor3 = Color3.new(1, 1, 1)
	badge.ZIndex = z
	badge.Parent = parent
	corner(badge, size)
	local grad = PanelChrome.gradient(badge, top, bottom)
	PanelChrome.stroke(badge, BRIGHT.Outline, size >= 40 and 3 or 2.5)
	local k = size / 48
	local dir = pointRight and 1 or -1
	local function bar(len, cx, cy, rot)
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromScale(cx, cy)
		b.Size = UDim2.fromOffset(math.floor(len * k + 0.5), math.max(4, math.floor(7 * k + 0.5)))
		b.Rotation = rot
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.BorderSizePixel = 0
		b.ZIndex = z + 1
		b.Parent = badge
		corner(b, 4)
		PanelChrome.stroke(b, BRIGHT.Outline, 1.5)
	end
	bar(24, 0.46 - 0.02 * dir, 0.5, 0)
	bar(15, 0.5 + 0.1 * dir, 0.5 - 0.12, 45 * dir)
	bar(15, 0.5 + 0.1 * dir, 0.5 + 0.12, -45 * dir)
	return badge, grad
end

-- Chunky bevelled button with a dark drop shadow under it.
local function shadowedButton(parent, props)
	local shadow = Instance.new("Frame")
	shadow.Name = (props.name or "Button") .. "Shadow"
	shadow.Position = props.pos + UDim2.fromOffset(0, 5)
	shadow.Size = props.size
	shadow.BackgroundColor3 = BRIGHT.Outline
	shadow.BackgroundTransparency = 0.45
	shadow.BorderSizePixel = 0
	shadow.ZIndex = (props.zIndex or 10) - 1
	shadow.Parent = parent
	corner(shadow, props.radius or 16)
	local btn, label, grad = PanelChrome.chunkyButton(parent, props)
	-- Bevel: a darker lip along the button's bottom edge.
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.AnchorPoint = Vector2.new(0.5, 1)
	lip.Position = UDim2.new(0.5, 0, 1, -3)
	lip.Size = UDim2.new(1, -12, 0, 6)
	lip.BackgroundColor3 = props.colorDark
	lip.BorderSizePixel = 0
	lip.ZIndex = btn.ZIndex
	lip.Parent = btn
	corner(lip, 3)
	return btn, label, grad
end

-- ── Header: wealth pill and the vault's promise ──────────────────────────────
local wealthPill = Instance.new("Frame")
wealthPill.Name = "WealthPill"
wealthPill.AnchorPoint = Vector2.new(1, 0.5)
wealthPill.Position = UDim2.new(1, -(CLOSE + 26), 0, HEADER_H / 2 + 2)
wealthPill.Size = UDim2.fromOffset(WEALTH_W, 50)
wealthPill.BackgroundColor3 = Color3.new(1, 1, 1)
wealthPill.ZIndex = 8
wealthPill.Parent = modal
corner(wealthPill, 25)
PanelChrome.gradient(wealthPill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(226, 232, 246))
PanelChrome.stroke(wealthPill, BRIGHT.Outline, 3.5)
trophy(wealthPill, 60, UDim2.new(0, -20, 0.5, -2), 9)
local wealthLabel = PanelChrome.display(wealthPill, {
	name = "WealthAmount", text = "0", size = 32, stroke = 3, color = BRIGHT.Gold,
	pos = UDim2.fromOffset(44, 0), size2 = UDim2.new(1, -56, 1, 0), zIndex = 9, scaled = true, minSize = 14,
})
local wealthCaption = PanelChrome.display(wealthPill, {
	name = "Caption", text = "WEALTH", size = 14, stroke = 2, anchor = Vector2.new(0.5, 0.5),
	pos = UDim2.new(0.5, 22, 0, -1), size2 = UDim2.fromOffset(90, 16), zIndex = 10,
})
wealthCaption.TextColor3 = Color3.new(1, 1, 1)

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.BackgroundTransparency = 1
hint.AnchorPoint = Vector2.new(1, 0.5)
hint.Font = Enum.Font.GothamBold
hint.TextSize = 16
hint.TextColor3 = BRIGHT.InkMuted
hint.TextXAlignment = Enum.TextXAlignment.Right
hint.TextWrapped = true
hint.Text = "Stored swords survive rebirths and follow you to any server."
-- ...and once the server has sent a state packet this line carries the wealth ladder instead:
-- the fortune, the rung being climbed and its threshold (see the end of `render`).
hint.ZIndex = 8
hint.Parent = modal

-- ── Rarity rail ──────────────────────────────────────────────────────────────
local rail = Instance.new("Frame")
rail.Name = "RarityRail"
rail.Position = UDim2.fromOffset(RAIL_X, HEADER_H + 14)
rail.Size = UDim2.fromOffset(RAIL_W, #RARITIES * (TAB + 8) + 16)
rail.BackgroundColor3 = Color3.new(1, 1, 1)
rail.ZIndex = 6
rail.Parent = modal
corner(rail, 24)
PanelChrome.gradient(rail, BRIGHT.Panel, BRIGHT.PanelBottom)
PanelChrome.stroke(rail, BRIGHT.Outline, 4)
local railList = Instance.new("UIListLayout")
railList.Padding = UDim.new(0, 8)
railList.HorizontalAlignment = Enum.HorizontalAlignment.Center
railList.SortOrder = Enum.SortOrder.LayoutOrder
railList.Parent = rail
local railPad = Instance.new("UIPadding")
railPad.PaddingTop = UDim.new(0, 8)
railPad.Parent = rail

local filter = "All"
local tabs = {}
local lastState -- { stored, carried, capacity, wealth, meta }
local render -- forward

for i, rarity in ipairs(RARITIES) do
	local tab = Instance.new("TextButton")
	tab.Name = "Tab_" .. rarity
	tab.Text = ""
	tab.AutoButtonColor = false
	tab.LayoutOrder = i
	tab.Size = UDim2.fromOffset(TAB, TAB)
	tab.BackgroundColor3 = BRIGHT.Row
	tab.ZIndex = 7
	tab.Parent = rail
	corner(tab, 18)
	local stroke = PanelChrome.stroke(tab, BRIGHT.RowStroke, 2.5)
	if rarity == "All" then
		local view = Instance.new("ViewportFrame")
		view.Name = "Chest"
		view.BackgroundTransparency = 1
		view.Size = UDim2.fromScale(1, 1)
		view.ZIndex = 8
		view.Parent = tab
		renderChest(view)
	else
		gemIcon(tab, 34, rarity, 8)
	end
	local badge, badgeLabel = PanelChrome.countBadge(tab, "0", 9)
	badge.Position = UDim2.new(1, -4, 0, 4)
	local scale = Instance.new("UIScale")
	scale.Parent = tab
	tab.MouseEnter:Connect(function() scale.Scale = 1.06 end)
	tab.MouseLeave:Connect(function() scale.Scale = 1 end)
	tab.Activated:Connect(function()
		filter = rarity
		if lastState then render(table.unpack(lastState)) end
	end)
	tabs[rarity] = { tab = tab, stroke = stroke, badge = badge, label = badgeLabel }
end

-- ── Trays ────────────────────────────────────────────────────────────────────
-- Phones get no hover tooltip (a tap would leave it stuck over the grid); the bar shows the pick.
local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- Each tray's tiles and its current pick. A tile record is
-- { tile, outline, scale, chip, info, key, hover }.
local panes = {
	backpack = { tiles = {}, selected = nil, pickTitle = "Pick a sword", pickHint = "Tap one to store it" },
	vault = { tiles = {}, selected = nil, pickTitle = "Pick a sword", pickHint = "Tap one to take it" },
}
local STORE_COLORS = { BRIGHT.Green, BRIGHT.GreenDark }
local TAKE_COLORS = { Color3.fromRGB(96, 186, 255), Color3.fromRGB(30, 108, 226) }
local OFF_COLORS = { BRIGHT.Grey, BRIGHT.GreyDark }
local doStore, doTake -- forward

local function section(name, iconKind, verb, colors, onPress)
	local head = Instance.new("Frame")
	head.Name = name .. "Heading"
	head.BackgroundTransparency = 1
	head.ZIndex = 5
	head.Parent = modal
	local icon
	if iconKind == "chest" then
		icon = Instance.new("ViewportFrame")
		renderChest(icon)
	else
		icon = Instance.new("ImageLabel")
		icon.Image = BAG_ICON
		icon.ScaleType = Enum.ScaleType.Fit
	end
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, -4, 0.5, 0)
	icon.Size = UDim2.fromOffset(54, 54)
	icon.ZIndex = 6
	icon.Parent = head
	local title = PanelChrome.display(head, {
		name = "Title", text = name, size = 30, stroke = 3, xAlign = Enum.TextXAlignment.Left,
		pos = UDim2.fromOffset(54, 0), size2 = UDim2.new(0, 150, 1, 0), zIndex = 6,
	})
	title.TextColor3 = BRIGHT.Ink
	title:FindFirstChildOfClass("UIStroke").Color = Color3.new(1, 1, 1)
	title.AutomaticSize = Enum.AutomaticSize.X
	title.Size = UDim2.new(0, 0, 1, 0)

	-- A pale tray, close to the panel's white, so the rarity tiles are the loudest thing in it.
	local tray = Instance.new("Frame")
	tray.Name = name .. "Tray"
	tray.ZIndex = 4
	tray.Parent = modal
	PanelChrome.insetTray(tray, { top = Color3.fromRGB(230, 237, 252), bottom = Color3.fromRGB(206, 218, 242), radius = 22, zIndex = 4, strokeThickness = 3.5 })
	for _, d in ipairs(tray:GetChildren()) do
		if d.Name == "InnerShadow" then d.BackgroundColor3 = Color3.fromRGB(110, 124, 164) end
	end
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Grid"
	scroll.Position = UDim2.fromOffset(4, 4)
	scroll.Size = UDim2.new(1, -8, 1, -(8 + BAR_H))
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 10
	scroll.ScrollBarImageColor3 = BRIGHT.GreyDark
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ZIndex = 5
	scroll.Parent = tray
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, TOP_PAD)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, TRAY_PAD)
	pad.PaddingRight = UDim.new(0, SCROLLBAR)
	pad.Parent = scroll
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(TILE, TILE)
	grid.CellPadding = UDim2.fromOffset(GAP, VGAP)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroll

	-- "Nothing here" line: on the tray, not a grid cell, so it can span the tray's width.
	local note = PanelChrome.display(tray, { name = "EmptyNote", text = "", size = 24, stroke = 2.5, zIndex = 7, scaled = true, minSize = 12 })
	note.TextWrapped = true
	note.Size = UDim2.new(1, -40, 0, 64)
	note.Position = UDim2.new(0, 20, 0.28, 0)
	note.Visible = false

	-- Action bar: the pick's name and stats, and the one Store / Take button for this tray.
	local bar = Instance.new("Frame")
	bar.Name = "ActionBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -8)
	bar.Size = UDim2.new(1, -16, 0, BAR_H - 14)
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.ZIndex = 6
	bar.Parent = tray
	corner(bar, 18)
	PanelChrome.gradient(bar, Color3.fromRGB(255, 255, 255), Color3.fromRGB(226, 234, 248))
	PanelChrome.stroke(bar, BRIGHT.Outline, 3)
	local pick = PanelChrome.display(bar, {
		name = "Picked", text = "", size = 25, stroke = 2.5, scaled = true, minSize = 12, xAlign = Enum.TextXAlignment.Left,
		pos = UDim2.fromOffset(16, 7), size2 = UDim2.new(1, -(BTN_W + 40), 0, 32), zIndex = 7,
	})
	local meta = Instance.new("TextLabel")
	meta.Name = "Meta"
	meta.BackgroundTransparency = 1
	meta.Position = UDim2.fromOffset(16, 39)
	meta.Size = UDim2.new(1, -(BTN_W + 40), 0, 24)
	meta.Font = Enum.Font.GothamBold
	meta.TextSize = 20
	meta.TextScaled = true
	local metaSize = Instance.new("UITextSizeConstraint")
	metaSize.MaxTextSize = 20
	metaSize.MinTextSize = 10
	metaSize.Parent = meta
	meta.RichText = true
	meta.TextXAlignment = Enum.TextXAlignment.Left
	meta.TextColor3 = BRIGHT.InkMuted
	meta.ZIndex = 7
	meta.Parent = bar
	local btn, _, grad = shadowedButton(bar, {
		name = verb .. "Button", text = verb, color = colors[1], colorDark = colors[2],
		size = UDim2.fromOffset(BTN_W, BTN_H), pos = UDim2.new(1, -(BTN_W + 10), 0.5, -(BTN_H / 2) - 3),
		textSize = 30, zIndex = 8, radius = 16, strokeThickness = 3.5,
	})
	btn.Activated:Connect(onPress)
	return {
		head = head, title = title, tray = tray, scroll = scroll, grid = grid, note = note,
		bar = bar, pick = pick, meta = meta, btn = btn, shadow = bar:FindFirstChild(verb .. "ButtonShadow"),
		grad = grad, lip = btn:FindFirstChild("Lip"), colors = colors,
	}
end

local backpack = section("Backpack", "bag", "Store", STORE_COLORS, function() doStore() end)
local vault = section("Vault", "chest", "Take", TAKE_COLORS, function() doTake() end)
local sections = { backpack = backpack, vault = vault }

-- Backpack count: a blue stroked number beside the heading, like the Inventory's "Swords 39".
local backpackCount = PanelChrome.display(backpack.head, {
	name = "Count", text = "0", size = 30, stroke = 3, color = BRIGHT.Blue, xAlign = Enum.TextXAlignment.Left,
	size2 = UDim2.new(0, 80, 1, 0), zIndex = 6,
})
backpackCount:FindFirstChildOfClass("UIStroke").Color = Color3.new(1, 1, 1)
backpackCount.Position = UDim2.fromOffset(170, 0)
backpack.title:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	local s = panelScale.Scale > 0 and panelScale.Scale or 1
	backpackCount.Position = UDim2.fromOffset(54 + backpack.title.AbsoluteSize.X / s + 10, 0)
end)

-- Vault capacity: a gold fill bar with the stored / capacity count on it.
local capBar = Instance.new("Frame")
capBar.Name = "Capacity"
capBar.AnchorPoint = Vector2.new(1, 0.5)
capBar.Position = UDim2.new(1, -4, 0.5, 0)
capBar.Size = UDim2.new(0.48, 0, 0, 36)
capBar.BackgroundColor3 = Color3.fromRGB(62, 70, 96)
capBar.ZIndex = 6
capBar.Parent = vault.head
corner(capBar, 18)
PanelChrome.stroke(capBar, BRIGHT.Outline, 3)
local capFill = Instance.new("Frame")
capFill.Name = "Fill"
capFill.Size = UDim2.fromScale(0, 1)
capFill.BackgroundColor3 = Color3.new(1, 1, 1)
capFill.ZIndex = 7
capFill.Parent = capBar
corner(capFill, 18)
PanelChrome.gradient(capFill, BRIGHT.Gold, BRIGHT.GoldDark)
local capLabel = PanelChrome.display(capBar, { name = "Count", text = "0 / 12", size = 24, stroke = 2.5, zIndex = 8 })

-- Transfer arrows between the trays (wide layout only): they move the tray's current pick,
-- and grey out while that tray has nothing picked.
local ARROW = 58
local arrows = Instance.new("Frame")
arrows.Name = "TransferArrows"
arrows.BackgroundTransparency = 1
arrows.AnchorPoint = Vector2.new(0.5, 0.5)
arrows.Size = UDim2.fromOffset(ARROW, ARROW * 2 + 24)
arrows.ZIndex = 6
arrows.Parent = modal
local storeArrow, storeArrowGrad = arrowBadge(arrows, true, BRIGHT.Green, BRIGHT.GreenDark, 7, ARROW, true)
storeArrow.Position = UDim2.fromScale(0.5, 0.25)
local takeArrow, takeArrowGrad = arrowBadge(arrows, false, TAKE_COLORS[1], TAKE_COLORS[2], 7, ARROW, true)
takeArrow.Position = UDim2.fromScale(0.5, 0.75)
storeArrow.Activated:Connect(function() doStore() end)
takeArrow.Activated:Connect(function() doTake() end)
for _, a in ipairs({ storeArrow, takeArrow }) do
	local s = Instance.new("UIScale")
	s.Parent = a
	a.MouseEnter:Connect(function() s.Scale = 1.08 end)
	a.MouseLeave:Connect(function() s.Scale = 1 end)
end

-- ── Tooltip (mouse hover) ────────────────────────────────────────────────────
local TIP_W = 270
local tip = Instance.new("Frame")
tip.Name = "Tooltip"
tip.Size = UDim2.fromOffset(TIP_W, 0)
tip.AutomaticSize = Enum.AutomaticSize.Y
tip.BackgroundColor3 = Color3.new(1, 1, 1)
tip.Visible = false
tip.ZIndex = 40
tip.Parent = modal
corner(tip, 18)
PanelChrome.gradient(tip, BRIGHT.Panel, BRIGHT.PanelBottom)
PanelChrome.stroke(tip, BRIGHT.Outline, 3.5)
local tipPad = Instance.new("UIPadding")
tipPad.PaddingTop = UDim.new(0, 12)
tipPad.PaddingBottom = UDim.new(0, 14)
tipPad.PaddingLeft = UDim.new(0, 14)
tipPad.PaddingRight = UDim.new(0, 14)
tipPad.Parent = tip
local tipList = Instance.new("UIListLayout")
tipList.Padding = UDim.new(0, 6)
tipList.HorizontalAlignment = Enum.HorizontalAlignment.Center
tipList.SortOrder = Enum.SortOrder.LayoutOrder
tipList.Parent = tip
local tipName = PanelChrome.display(tip, { name = "Name", text = "", size = 24, stroke = 2.5, zIndex = 41 })
tipName.LayoutOrder = 1
tipName.TextWrapped = true
tipName.Size = UDim2.new(1, 0, 0, 0)
tipName.AutomaticSize = Enum.AutomaticSize.Y
local tipRarity = PanelChrome.display(tip, { name = "Rarity", text = "", size = 20, stroke = 2, zIndex = 41 })
tipRarity.LayoutOrder = 2
tipRarity.Size = UDim2.new(1, 0, 0, 22)
local tipMods = Instance.new("TextLabel")
tipMods.Name = "Modifiers"
tipMods.LayoutOrder = 3
tipMods.BackgroundTransparency = 1
tipMods.Size = UDim2.new(1, 0, 0, 0)
tipMods.AutomaticSize = Enum.AutomaticSize.Y
tipMods.Font = Enum.Font.GothamBold
tipMods.TextSize = 17
tipMods.TextColor3 = BRIGHT.Ink
tipMods.TextWrapped = true
tipMods.ZIndex = 41
tipMods.Parent = tip
local tipStats = Instance.new("Frame")
tipStats.Name = "Stats"
tipStats.LayoutOrder = 4
tipStats.Size = UDim2.new(1, 0, 0, 40)
tipStats.BackgroundColor3 = BRIGHT.Row
tipStats.ZIndex = 41
tipStats.Parent = tip
corner(tipStats, 14)
PanelChrome.stroke(tipStats, BRIGHT.RowStroke, 2)
trophy(tipStats, 34, UDim2.new(0, 4, 0.5, 0), 42)
local tipRating = PanelChrome.display(tipStats, {
	name = "Rating", text = "", size = 24, stroke = 2.5, color = BRIGHT.Gold, xAlign = Enum.TextXAlignment.Left,
	pos = UDim2.fromOffset(42, 0), size2 = UDim2.new(0.5, -42, 1, 0), zIndex = 42,
})
local tipMult = PanelChrome.display(tipStats, {
	name = "Damage", text = "", size = 24, stroke = 2.5, xAlign = Enum.TextXAlignment.Right,
	pos = UDim2.new(0.5, 0, 0, 0), size2 = UDim2.new(0.5, -10, 1, 0), zIndex = 42,
})
local tipWhere = Instance.new("TextLabel")
tipWhere.Name = "Where"
tipWhere.LayoutOrder = 5
tipWhere.BackgroundTransparency = 1
tipWhere.Size = UDim2.new(1, 0, 0, 18)
tipWhere.Font = Enum.Font.GothamBold
tipWhere.TextSize = 14
tipWhere.TextColor3 = BRIGHT.InkMuted
tipWhere.ZIndex = 41
tipWhere.Parent = tip

local tipOwner -- the tile the tooltip is showing for

local function showTip(tile, info, inVault)
	local t = RARITY_TILE[info.rarity] or RARITY_TILE.Common
	tipName.Text = info.name or "Relic Sword"
	tipRarity.Text = info.rarity or "Common"
	tipRarity.TextColor3 = t.bottom
	local mods = {}
	for _, m in ipairs(string.split(info.prefixes or "", ",")) do
		m = string.gsub(m, "^%s+", "")
		m = string.gsub(m, "%s+$", "")
		if m ~= "" then table.insert(mods, "+ " .. m) end
	end
	tipMods.Text = #mods > 0 and table.concat(mods, "\n") or "No modifiers"
	tipRating.Text = SwordValue.short(info.rating or 0)
	tipMult.Text = string.format("x%.1f", info.damageMult or 1)
	tipWhere.Text = inVault and "Safe in your vault" or (info.equipped and "Equipped - in your hand" or "In your backpack")
	tipOwner = tile
	tip.Visible = true
	-- Place it beside the tile, in the modal's unscaled space; flip left if it would overflow.
	local k = modal.AbsoluteSize.X / math.max(window.Size.X.Offset, 1)
	if k <= 0 then return end
	local rel = (tile.AbsolutePosition - modal.AbsolutePosition) / k
	local size = tile.AbsoluteSize / k
	local W, H = window.Size.X.Offset, window.Size.Y.Offset
	local x = rel.X + size.X + 14
	if x + TIP_W > W + 10 then x = rel.X - TIP_W - 14 end
	local tipH = tip.AbsoluteSize.Y / k
	local y = math.clamp(rel.Y - 6, 10, math.max(10, H - tipH - 10))
	tip.Position = UDim2.fromOffset(x, y)
end

local function hideTip(tile)
	if tile == nil or tipOwner == tile then
		tip.Visible = false
		tipOwner = nil
	end
end

-- ── Tiles ────────────────────────────────────────────────────────────────────
-- A four-point sparkle: two crossed rounded bars.
local function sparkle(parent, x, y, size, z)
	local s = Instance.new("Frame")
	s.Name = "Sparkle"
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Position = UDim2.fromScale(x, y)
	s.Size = UDim2.fromOffset(size, size)
	s.BackgroundTransparency = 1
	s.ZIndex = z
	s.Parent = parent
	-- A small diamond core makes the cross read as a twinkle, not a plus sign.
	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromScale(0.38, 0.38)
	core.Rotation = 45
	core.BackgroundColor3 = Color3.new(1, 1, 1)
	core.BorderSizePixel = 0
	core.ZIndex = z
	core.Parent = s
	for _, rot in ipairs({ 0, 90 }) do
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromScale(0.5, 0.5)
		b.Size = UDim2.fromScale(0.16, 1)
		b.Rotation = rot
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.BorderSizePixel = 0
		b.ZIndex = z
		b.Parent = s
		corner(b, 99)
	end
	return s
end

-- Rarity flair behind the sword, so tiers read apart at a glance and not only by colour:
-- Legendary gets a bright sunburst and three sparkles, Epic a softer burst and two, Rare one.
local SPARKLES = {
	Legendary = { { 0.15, 0.6, 20 }, { 0.88, 0.5, 16 }, { 0.6, 0.14, 12 } },
	Epic = { { 0.15, 0.6, 17 }, { 0.88, 0.5, 13 } },
	Rare = { { 0.88, 0.52, 14 } },
}
local function rarityFlair(tile, rarity, z)
	local t = RARITY_TILE[rarity] or RARITY_TILE.Common
	if rarity == "Legendary" or rarity == "Epic" then
		local legendary = rarity == "Legendary"
		local rays = Instance.new("Frame")
		rays.Name = "Rays"
		rays.BackgroundTransparency = 1
		rays.AnchorPoint = Vector2.new(0.5, 0.5)
		rays.Position = UDim2.fromScale(0.5, 0.44)
		rays.Size = UDim2.fromScale(0.9, 0.9)
		rays.ZIndex = z
		rays.Parent = tile
		for i = 0, 3 do
			local ray = Instance.new("Frame")
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			ray.Position = UDim2.fromScale(0.5, 0.5)
			ray.Size = UDim2.new(0, legendary and 18 or 13, 1, 0)
			ray.Rotation = i * 45 + 22.5
			ray.BackgroundColor3 = t.bottom
			ray.BorderSizePixel = 0
			ray.ZIndex = z
			ray.Parent = rays
			corner(ray, 8)
			local g = Instance.new("UIGradient")
			g.Rotation = 90
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, legendary and 0.45 or 0.6),
				NumberSequenceKeypoint.new(1, 1),
			})
			g.Parent = ray
		end
	end
	for _, spec in ipairs(SPARKLES[rarity] or {}) do
		sparkle(tile, spec[1], spec[2], spec[3], z)
	end
end

local function styleTile(rec, selected)
	rec.outline.Color = selected and BRIGHT.Blue or BRIGHT.Outline
	rec.outline.Thickness = selected and 5 or 3.5
	rec.chip.Visible = selected or rec.hover
	rec.scale.Scale = if selected then 1.07 elseif rec.hover then 1.04 else 1
end

local function updateBar(paneKey)
	local pane, sec = panes[paneKey], sections[paneKey]
	local sel = pane.selected
	local c = sel and sec.colors or OFF_COLORS
	sec.grad.Color = ColorSequence.new(c[1], c[2])
	if sec.lip then sec.lip.BackgroundColor3 = c[2] end
	if sel then
		local info = sel.info
		local rarity = info.rarity or "Common"
		local t = RARITY_TILE[rarity] or RARITY_TILE.Common
		sec.pick.Text = tileName(info.name or "Relic Sword")
		sec.meta.Text = string.format('<font color="#%s">%s</font>  ·  x%.1f  ·  %s', t.rim:ToHex(), rarity,
			info.damageMult or 1, SwordValue.short(info.rating or 0))
	else
		sec.pick.Text = pane.pickTitle
		sec.meta.Text = pane.pickHint
	end
	local arrowGrad = paneKey == "backpack" and storeArrowGrad or takeArrowGrad
	local ac = sel and (paneKey == "backpack" and STORE_COLORS or TAKE_COLORS) or OFF_COLORS
	arrowGrad.Color = ColorSequence.new(ac[1], ac[2])
end

local function applySelection(paneKey)
	local pane = panes[paneKey]
	for _, rec in ipairs(pane.tiles) do
		styleTile(rec, pane.selected == rec)
	end
	updateBar(paneKey)
end

doStore = function()
	local sel = panes.backpack.selected
	if not sel then return end
	panes.backpack.selected = nil
	applySelection("backpack")
	VAULT_ACTION:FireServer("Deposit", sel.info.toolName)
end
doTake = function()
	local sel = panes.vault.selected
	if not sel then return end
	panes.vault.selected = nil
	applySelection("vault")
	VAULT_ACTION:FireServer("Withdraw", sel.info.index)
end

-- One sword tile, in the Inventory's style: the sword rendered big enough to break out past
-- the tile's top edge, rating and multiplier as stroked numbers, the name on a rim-coloured
-- strip along the bottom. The whole tile is the control: tap to pick it for Store / Take.
local function buildTile(parent, order, info, carried, paneKey, key)
	local pane = panes[paneKey]
	local inVault = paneKey == "vault"
	local rarity = info.rarity or "Common"
	local t = RARITY_TILE[rarity] or RARITY_TILE.Common

	local tile = Instance.new("TextButton")
	tile.Name = "SwordTile"
	tile.Text = ""
	tile.AutoButtonColor = false
	tile.LayoutOrder = order
	tile.ZIndex = 6
	tile.Parent = parent
	corner(tile, 18)
	local outline = PanelChrome.lootTile(tile, rarity, { radius = 18, zIndex = 6, glowY = 0.42 })
	rarityFlair(tile, rarity, 7)

	if string.find(info.name or "", "Blessed", 1, true) then
		local halo = Instance.new("Frame")
		halo.Name = "BlessedHalo"
		halo.BackgroundTransparency = 1
		halo.Position = UDim2.fromOffset(-5, -5)
		halo.Size = UDim2.new(1, 10, 1, 10)
		halo.ZIndex = 6
		halo.Parent = tile
		corner(halo, 23)
		PanelChrome.stroke(halo, BRIGHT.Gold, 3)
	end

	local view = Instance.new("ViewportFrame")
	view.Name = "SwordRender"
	view.BackgroundTransparency = 1
	view.Position = UDim2.new(-0.02, 0, -0.2, 0)
	view.Size = UDim2.new(1.16, 0, 1.02, 0)
	view.ZIndex = 8
	view.Parent = tile
	local tool, standIn = toolFor(info, carried)
	PanelChrome.renderTool(view, tool, { tiltDeg = 45, margin = 0.8 })
	if standIn then tool:Destroy() end

	-- Name strip: rim-coloured band across the bottom (square top, rounded bottom).
	local strip = Instance.new("Frame")
	strip.Name = "NameStrip"
	strip.AnchorPoint = Vector2.new(0, 1)
	strip.Position = UDim2.fromScale(0, 1)
	strip.Size = UDim2.new(1, 0, 0, 26)
	strip.BackgroundColor3 = Color3.new(1, 1, 1)
	strip.BorderSizePixel = 0
	strip.ZIndex = 9
	strip.Parent = tile
	corner(strip, 16)
	PanelChrome.gradient(strip, t.rim, t.rim:Lerp(BRIGHT.Outline, 0.35))
	local stripTop = Instance.new("Frame")
	stripTop.BackgroundColor3 = t.rim
	stripTop.BorderSizePixel = 0
	stripTop.Size = UDim2.new(1, 0, 0.5, 0)
	stripTop.ZIndex = 9
	stripTop.Parent = strip
	local nameLabel = PanelChrome.display(strip, { name = "SwordName", text = tileName(info.name or "Relic Sword"), size = 17, stroke = 2, scaled = true, minSize = 10, zIndex = 10 })
	nameLabel.Size = UDim2.new(1, -10, 1, -4)
	nameLabel.Position = UDim2.fromOffset(5, 2)

	-- Rating (the sword's value) top-left, damage multiplier bottom-right above the strip.
	trophy(tile, 28, UDim2.fromOffset(2, 16), 10)
	PanelChrome.display(tile, {
		name = "Rating", text = SwordValue.short(info.rating or 0), size = 20, stroke = 2.5, xAlign = Enum.TextXAlignment.Left,
		pos = UDim2.fromOffset(28, 3), size2 = UDim2.fromOffset(70, 26), zIndex = 10,
	})
	PanelChrome.display(tile, {
		name = "Mult", text = string.format("x%.1f", info.damageMult or 1), size = 20, stroke = 2.5,
		xAlign = Enum.TextXAlignment.Right, yAlign = Enum.TextYAlignment.Bottom, anchor = Vector2.new(1, 1),
		pos = UDim2.new(1, -6, 1, -25), size2 = UDim2.fromOffset(70, 24), zIndex = 10,
	})
	if info.equipped then
		local check = PanelChrome.checkBadge(tile, 26, 11)
		check.Position = UDim2.new(0, 16, 1, -42)
	end

	-- Direction chip on the side the sword will travel toward: shown on hover and when picked.
	local chip = arrowBadge(tile, not inVault, (inVault and TAKE_COLORS or STORE_COLORS)[1], (inVault and TAKE_COLORS or STORE_COLORS)[2], 12, 34)
	chip.Name = "DirectionChip"
	chip.Position = if inVault then UDim2.new(0, 8, 0.42, 0) else UDim2.new(1, -8, 0.42, 0)
	chip.Visible = false

	local scale = Instance.new("UIScale")
	scale.Parent = tile
	local rec = { tile = tile, outline = outline, scale = scale, chip = chip, info = info, key = key, hover = false }

	tile.MouseEnter:Connect(function()
		rec.hover = true
		styleTile(rec, pane.selected == rec)
		if not touchOnly then showTip(tile, info, inVault) end
	end)
	tile.MouseLeave:Connect(function()
		rec.hover = false
		styleTile(rec, pane.selected == rec)
		hideTip(tile)
	end)
	tile.Activated:Connect(function()
		pane.selected = if pane.selected == rec then nil else rec
		if touchOnly then hideTip() end
		applySelection(paneKey)
	end)
	table.insert(pane.tiles, rec)
	return rec
end

-- THE SHOP TILE. Slots past the free shelf are bought with gold, and the price of the next one
-- climbs with how many this player has already bought (Config.VaultConfig). It lives in the vault
-- grid itself, as the tile after the last empty well, so the price is in front of the player at
-- the exact moment the shelf is the thing they are looking at -- and it is the only way to buy
-- one. The server owns the price and the purchase; this tile sends the word "BuySlot" and nothing
-- else, then re-renders from whatever the server sends back.
local function buildBuySlotTile(parent, order, meta)
	local price = meta and meta.slotPrice
	local tile = Instance.new("TextButton")
	tile.Name = "BuySlot"
	tile.Text = ""
	tile.AutoButtonColor = false
	tile.LayoutOrder = order
	tile.BackgroundColor3 = price and Color3.fromRGB(255, 249, 228) or Color3.fromRGB(240, 242, 248)
	tile.ZIndex = 6
	tile.Parent = parent
	corner(tile, 18)
	PanelChrome.stroke(tile, price and BRIGHT.Gold or BRIGHT.RowStroke, 3.5)
	local plus = PanelChrome.display(tile, {
		name = "Plus", text = price and "+1" or "MAX", size = price and 40 or 26, stroke = 2.5,
		color = BRIGHT.Gold, pos = UDim2.fromOffset(0, 8), size2 = UDim2.new(1, 0, 0, 40), zIndex = 7,
	})
	plus.TextXAlignment = Enum.TextXAlignment.Center
	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.BackgroundTransparency = 1
	caption.Position = UDim2.fromOffset(4, 46)
	caption.Size = UDim2.new(1, -8, 0, 18)
	caption.Font = Enum.Font.GothamBold
	caption.TextSize = 14
	caption.TextColor3 = BRIGHT.InkMuted
	caption.Text = price and "VAULT SLOT" or "EVERY SLOT OWNED"
	caption.TextScaled = false
	caption.TextWrapped = true
	caption.ZIndex = 7
	caption.Parent = tile
	local priceLabel = PanelChrome.display(tile, {
		name = "Price", text = price and (VaultConfig.short(price) .. "  GOLD") or "--",
		size = 24, stroke = 2.5, color = price and BRIGHT.Gold or BRIGHT.InkMuted,
		pos = UDim2.fromOffset(0, 64), size2 = UDim2.new(1, 0, 0, 28), zIndex = 7, scaled = true, minSize = 12,
	})
	priceLabel.TextXAlignment = Enum.TextXAlignment.Center
	local owned = Instance.new("TextLabel")
	owned.Name = "Owned"
	owned.BackgroundTransparency = 1
	owned.Position = UDim2.new(0, 4, 1, -22)
	owned.Size = UDim2.new(1, -8, 0, 18)
	owned.Font = Enum.Font.GothamBold
	owned.TextSize = 13
	owned.TextColor3 = BRIGHT.InkMuted
	owned.TextWrapped = true
	owned.ZIndex = 7
	owned.Text = meta and string.format("%d free + %d bought + %d earned / %d", meta.freeSlots or 0,
		meta.boughtSlots or 0, meta.grantedSlots or 0, meta.maxSlots or 0) or ""
	owned.Parent = tile
	if price then
		local scale = Instance.new("UIScale")
		scale.Parent = tile
		tile.MouseEnter:Connect(function() scale.Scale = 1.05 end)
		tile.MouseLeave:Connect(function() scale.Scale = 1 end)
		tile.Activated:Connect(function() VAULT_ACTION:FireServer("BuySlot") end)
	end
	return tile
end

local function buildEmptyWell(parent, order)
	local well = Instance.new("Frame")
	well.Name = "EmptySlot"
	well.LayoutOrder = order
	well.ZIndex = 6
	well.Parent = parent
	PanelChrome.emptyWell(well, { radius = 18, zIndex = 6, color = Color3.fromRGB(236, 241, 252) })
	local dashes = PanelChrome.dashedOutline(well, { color = Color3.fromRGB(176, 190, 218), thickness = 3, radius = 18, zIndex = 7, dashes = 3 })
	dashes.Name = "Dashes"
	local plus = PanelChrome.display(well, { name = "Plus", text = "+", size = 46, stroke = 0, zIndex = 7 })
	plus.TextColor3 = Color3.fromRGB(190, 202, 226)
	plus:FindFirstChildOfClass("UIStroke").Enabled = false
	return well
end

local function clear(scroll)
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

render = function(stored, carried, capacity, wealth, meta)
	lastState = { stored, carried, capacity, wealth, meta }
	hideTip()
	-- Keep each tray's pick across refreshes when that sword is still there.
	local keep = {}
	for paneKey, pane in pairs(panes) do
		keep[paneKey] = pane.selected and pane.selected.key
		pane.selected = nil
		table.clear(pane.tiles)
	end
	clear(backpack.scroll)
	clear(vault.scroll)
	local tools = carriedTools()

	local counts = { All = #stored + #carried }
	for _, list in ipairs({ stored, carried }) do
		for _, info in ipairs(list) do
			local r = info.rarity or "Common"
			counts[r] = (counts[r] or 0) + 1
		end
	end
	for rarity, tabInfo in pairs(tabs) do
		local n = counts[rarity] or 0
		tabInfo.label.Text = tostring(n)
		tabInfo.badge.Visible = n > 0
		local on = rarity == filter
		tabInfo.tab.BackgroundColor3 = on and BRIGHT.Select or BRIGHT.Row
		tabInfo.stroke.Color = on and BRIGHT.Blue or BRIGHT.RowStroke
		tabInfo.stroke.Thickness = on and 3.5 or 2.5
	end

	local function shown(info)
		return filter == "All" or (info.rarity or "Common") == filter
	end

	-- Backpack: equipped first, then best rating first.
	local sorted = table.clone(carried)
	table.sort(sorted, function(a, b)
		if (a.equipped == true) ~= (b.equipped == true) then return a.equipped == true end
		return (a.rating or 0) > (b.rating or 0)
	end)
	local n = 0
	for _, info in ipairs(sorted) do
		if shown(info) then
			n += 1
			local rec = buildTile(backpack.scroll, n, info, tools, "backpack", info.toolName)
			if keep.backpack ~= nil and rec.key == keep.backpack then panes.backpack.selected = rec end
		end
	end
	backpack.note.Text = #carried == 0 and "No relic swords on you." or "No " .. filter .. " swords on you."
	backpack.note.Visible = n == 0
	backpackCount.Text = tostring(#carried)

	local shownStored = 0
	for i, info in ipairs(stored) do
		if shown(info) then
			shownStored += 1
			local rec = buildTile(vault.scroll, i, info, tools, "vault", tostring(info.index) .. "|" .. tostring(info.name))
			if keep.vault ~= nil and rec.key == keep.vault then panes.vault.selected = rec end
		end
	end
	for i = #stored + 1, capacity do
		buildEmptyWell(vault.scroll, i)
	end
	-- ...and then the shop tile: the price of slot capacity+1, always visible, always last.
	buildBuySlotTile(vault.scroll, capacity + 1, meta)
	vault.note.Text = "No " .. filter .. " swords stored."
	vault.note.Visible = #stored > 0 and shownStored == 0 and #stored >= capacity
	panes.vault.pickHint = #stored == 0 and "Your vault is empty" or "Tap one to take it"
	applySelection("backpack")
	applySelection("vault")
	capLabel.Text = string.format("%d / %d", #stored, capacity)
	capFill.Size = UDim2.fromScale(capacity > 0 and math.clamp(#stored / capacity, 0, 1) or 0, 1)
	capFill.Visible = #stored > 0
	wealthLabel.Text = SwordValue.short(wealth or 0)
	-- The wealth ladder, in the header: the title this player has earned over the pill, and the
	-- rung they are climbing towards -- with the threshold and how far along they are -- where the
	-- vault's promise line used to sit. Fortune is net worth IN GOLD, so it reads against a price.
	local title = meta and meta.title or ""
	wealthCaption.Text = title ~= "" and string.upper(title) or "WEALTH"
	if meta and meta.fortune then
		local line = string.format("Fortune %s gold  (%s carried + %s stored x%.2f + purse)",
			WealthLadder.short(meta.fortune), WealthLadder.short(meta.carriedGold or 0),
			WealthLadder.short(meta.storedGold or 0), meta.appraisal or 1)
		if meta.nextThreshold then
			line ..= string.format("   ·   next: %s at %s  (%.0f%%)", meta.nextName,
				WealthLadder.short(meta.nextThreshold),
				math.clamp(meta.fortune / meta.nextThreshold * 100, 0, 100))
		else
			line ..= string.format("   ·   %s -- every rung earned", title)
		end
		hint.Text = line
	end
end

-- ── Responsive layout: side by side when it fits, stacked on phones ──────────
local function trayWidth(cols)
	return 8 + TRAY_PAD + cols * TILE + (cols - 1) * GAP + SCROLLBAR + 8
end
local function rowsHeight(rows)
	return rows * (TILE + VGAP) - VGAP
end
-- A tray's height beyond its visible rows: insets, the overhang room, bottom padding, the bar.
local TRAY_EXTRA = 8 + TOP_PAD + 14 + BAR_H

-- Fit the bar's button (and so its text column) to the tray's width.
local function sizeBar(sec, trayW)
	local bw = math.clamp(math.floor(trayW * 0.42), 116, BTN_W)
	local pos = UDim2.new(1, -(bw + 10), 0.5, -(BTN_H / 2) - 3)
	sec.btn.Size = UDim2.fromOffset(bw, BTN_H)
	sec.btn.Position = pos
	if sec.shadow then
		sec.shadow.Size = UDim2.fromOffset(bw, BTN_H)
		sec.shadow.Position = pos + UDim2.fromOffset(0, 5)
	end
	sec.pick.Size = UDim2.new(1, -(bw + 36), 0, 32)
	sec.meta.Size = UDim2.new(1, -(bw + 36), 0, 24)
end

local baseScale = 1
local function applyLayout(viewport)
	local availY = viewport.Y - 110
	local stackBase = HEADER_H + 2 * SEC_H + 14 + EDGE
	local best
	for _, spec in ipairs({ { 6, 4 }, { 5, 4 }, { 5, 3 }, { 4, 3 }, { 3, 3 }, { 3, 2 }, { 4 }, { 3 }, { 2 } }) do
		local W, H
		if spec[2] then
			W = X0 + trayWidth(spec[1]) + MID_GAP + trayWidth(spec[2]) + EDGE
			H = HEADER_H + SEC_H + TRAY_EXTRA + rowsHeight(ROWS_VISIBLE) + EDGE
		else
			W = X0 + trayWidth(spec[1]) + EDGE
			H = nil
		end
		local s = math.min(1, (viewport.X - 16) / (W + 26))
		if H then
			s = math.min(s, availY / H)
		else
			H = math.min(availY / s, stackBase + 2 * (TRAY_EXTRA + rowsHeight(2.5)))
			H = math.max(H, stackBase + 2 * (TRAY_EXTRA + rowsHeight(1)))
			s = math.min(s, availY / H)
		end
		if not best or s > best.s + 0.02 then
			best = { spec = spec, W = W, H = H, s = s }
		end
	end
	local W, H = best.W, best.H
	window.Size = UDim2.fromOffset(W, H)
	window.Position = UDim2.new(0.5, math.floor(10 * best.s), 0.5, 8)
	baseScale = math.max(best.s, 0.3)
	panelScale.Scale = baseScale
	local wide = best.spec[2] ~= nil
	local trayTop = HEADER_H + SEC_H
	if wide then
		local lw, rw = trayWidth(best.spec[1]), trayWidth(best.spec[2])
		local rx = X0 + lw + MID_GAP
		backpack.head.Position = UDim2.fromOffset(X0 + 6, HEADER_H)
		backpack.head.Size = UDim2.fromOffset(lw - 6, SEC_H)
		backpack.tray.Position = UDim2.fromOffset(X0, trayTop)
		backpack.tray.Size = UDim2.new(0, lw, 1, -(trayTop + EDGE))
		vault.head.Position = UDim2.fromOffset(rx + 6, HEADER_H)
		vault.head.Size = UDim2.fromOffset(rw - 6, SEC_H)
		vault.tray.Position = UDim2.fromOffset(rx, trayTop)
		vault.tray.Size = UDim2.new(0, rw, 1, -(trayTop + EDGE))
		backpack.grid.FillDirectionMaxCells = best.spec[1]
		vault.grid.FillDirectionMaxCells = best.spec[2]
		sizeBar(backpack, lw)
		sizeBar(vault, rw)
		arrows.Visible = true
		-- Centred on the tile grids, above the action bars.
		arrows.Position = UDim2.new(0, X0 + lw + MID_GAP / 2, 0.5, (trayTop - EDGE - BAR_H) / 2)
	else
		local tw = trayWidth(best.spec[1])
		local trays = H - stackBase
		local vh = math.floor(trays * 0.46)
		vault.head.Position = UDim2.fromOffset(X0 + 6, HEADER_H)
		vault.head.Size = UDim2.fromOffset(tw - 6, SEC_H)
		vault.tray.Position = UDim2.fromOffset(X0, trayTop)
		vault.tray.Size = UDim2.fromOffset(tw, vh)
		local by = trayTop + vh + 14
		backpack.head.Position = UDim2.fromOffset(X0 + 6, by)
		backpack.head.Size = UDim2.fromOffset(tw - 6, SEC_H)
		backpack.tray.Position = UDim2.fromOffset(X0, by + SEC_H)
		backpack.tray.Size = UDim2.new(0, tw, 1, -(by + SEC_H + EDGE))
		backpack.grid.FillDirectionMaxCells = best.spec[1]
		vault.grid.FillDirectionMaxCells = best.spec[1]
		sizeBar(backpack, tw)
		sizeBar(vault, tw)
		arrows.Visible = false
	end
	-- Header: the promise line fits between the title and the wealth pill on wide windows.
	-- Phones get a slimmer wealth pill so it never runs into the title.
	local wealthW = wide and WEALTH_W or 140
	wealthPill.Size = UDim2.fromOffset(wealthW, 50)
	local hintW = W - (CLOSE + 26 + wealthW + 24) - 290
	hint.Visible = wide and hintW > 200
	hint.Position = UDim2.new(1, -(CLOSE + 26 + wealthW + 24), 0, HEADER_H / 2 + 2)
	hint.Size = UDim2.fromOffset(math.max(hintW, 0), 40)
	chrome.TitleLabel.Size = UDim2.new(0, math.max(96, W - 84 - (CLOSE + 26 + wealthW + 16)), 0, 58)
	rail.Size = UDim2.fromOffset(RAIL_W, #RARITIES * (TAB + 8) + 16)
end
PanelChrome.onViewport(applyLayout)
updateBar("backpack")
updateBar("vault")

-- Shared open/close motion (PanelChrome): the window grows in while the backdrop dims, then
-- the sword tiles in both trays land row by row.
local motion = {
	frame = window, scale = panelScale, dim = overlay, dimTo = 0.5,
	tiles = function() return { backpack.scroll, vault.scroll } end,
}

local function close()
	hideTip()
	if not overlay.Visible then return end
	PanelChrome.closeMotion(motion, function() overlay.Visible = false end)
end
closeBtn.Activated:Connect(close)
overlay.Activated:Connect(close)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape and overlay.Visible then close() end
end)

VAULT_ACTION.OnClientEvent:Connect(function(kind, stored, carried, capacity, wealth, meta)
	if kind == "Open" then
		overlay.Visible = true
		PanelChrome.openMotion(motion)
	elseif kind == "State" then
		render(stored or {}, carried or {}, capacity or VaultConfig.STARTING_SLOTS, wealth, meta)
	end
end)

-- Showcase: the NPC target presses the Vaultkeeper's prompt; once the vault is open, pick the
-- top backpack sword and the first stored one, as a player about to move them would see it.
GuiShowcase.register("Vault", function()
	local deadline = os.clock() + 25
	while not (overlay.Visible and (#panes.backpack.tiles > 0 or #panes.vault.tiles > 0)) and os.clock() < deadline do
		task.wait(0.25)
	end
	task.wait(0.8)
	if not overlay.Visible then return end
	for _, paneKey in ipairs({ "backpack", "vault" }) do
		local first = panes[paneKey].tiles[1]
		if first then
			panes[paneKey].selected = first
			applySelection(paneKey)
		end
	end
end)
