--// ReforgeGuiFusion  (the Reforge anvil window, built with Fusion)
-- Pick a relic sword, pay gold, watch the modifier reel spin, reveal the result. Same remotes
-- and feature set as the original ReforgeGui.client.luau.
--
-- Bright window in the Inventory / Vault family: a light thick-outlined panel with the title
-- over its top-left edge beside a rendered anvil, a rarity-filter rail down the left with red
-- count badges, and a tray of square sword tiles (one 3D sword and one stat on each rarity
-- face). The stage on the right is the featured item: the picked sword big in a glowing rarity
-- tile, its name and cost in chunky display type with a lucky-roll bar, its modifiers as a
-- wrapping grid of lock chips (the reel spins in their place), and one fat Reforge button
-- between the Odds (tier chances live there) and Animation buttons. On phones the stage stacks
-- over the sword tray and the whole window is sized with one UIScale.
--
-- The reel/spin/reveal sequence stays imperative (a one-shot procedural animation isn't
-- a good fit for declarative state, and Fusion doesn't try to replace TweenService for
-- that). Everything else -- list rendering, lock chips, button text/color, the odds
-- popup, the pity status -- is Fusion state driving the UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local REFORGE = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("ReforgeAction")
local Config = ReplicatedStorage:WaitForChild("Config")
local SwordValue = require(Config:WaitForChild("SwordValue"))
local WeaponModifiers = require(Config:WaitForChild("WeaponModifiers"))
local BossWeapons = require(Config:WaitForChild("BossWeapons"))
local AudioManager = require(ReplicatedStorage:WaitForChild("AudioManager"))

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local scope = Fusion.scoped(Fusion)
local peek = Fusion.peek
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
local BRIGHT = PanelChrome.BRIGHT
local RARITY_TILE = PanelChrome.RARITY_TILE
local DISPLAY = PanelChrome.DISPLAY_FONT
local corner = PanelChrome.corner
local WHITE = Color3.new(1, 1, 1)
local COIN_ICON = "rbxassetid://84697600263846" -- the HUD's gold coin
local TROPHY_ICON = "rbxassetid://77830885604568" -- the Inventory's rating trophy

local TIER_COLORS = {
	Color3.fromRGB(170, 170, 176), Color3.fromRGB(90, 200, 120), Color3.fromRGB(80, 150, 255),
	Color3.fromRGB(190, 90, 240), Color3.fromRGB(255, 200, 40), Color3.fromRGB(255, 80, 80),
}
local RARITIES = { "All", "Legendary", "Epic", "Rare", "Uncommon", "Common" }

-- [TUNING] design-space sizes; the whole window is scaled with one UIScale.
local HEADER_H, SEC_H, EDGE = 70, 50, 18
local X0 = 90 -- content starts right of the rail
local RAIL_X, RAIL_W, TAB = -22, 94, 70
local CLOSE = 68 -- 44 px tall even at the phone scale
local TILE, GAP, VGAP = 112, 12, 18
local TOP_PAD, TRAY_PAD, SCROLLBAR = 24, 16, 10
local MID = 20 -- between the sword tray and the stage
local STAGE_W_WIDE, STAGE_W_TALL = 600, 430
-- The stage is three calm bands: the hero card, the modifier lock grid (the reel spins over it
-- while reforging) and the button row. The tier odds live behind the Odds button.
local CHIP_H, CHIP_GAP = 68, 10 -- lock chips sit two to a row; 68 keeps them 44 px on phones
local HERO_H, MODS_H, STRIKE_H, STAGE_GAP = 236, 3 * CHIP_H + 2 * CHIP_GAP, 90, 16
local STAGE_H = HERO_H + MODS_H + STRIKE_H + 2 * STAGE_GAP
local STAGE_TOP = 8 -- the stage starts level with the tray heading
local HERO_Y = 0
local MODS_Y = HERO_Y + HERO_H + STAGE_GAP
local STRIKE_Y = MODS_Y + MODS_H + STAGE_GAP
local TRAY_H_WIDE = STAGE_TOP + STAGE_H - SEC_H

local CARD_W, CARD_H, CARD_GAP = 112, 112, 8
local REEL_CARDS = 48
local LAND_INDEX = 40 -- the result sits here; a few filler cards trail it
local SPIN_TIME = 4.6

local function trayWidth(cols)
	return 2 * TRAY_PAD + cols * TILE + (cols - 1) * GAP + SCROLLBAR + 8
end
local TRAY_W_WIDE = trayWidth(3)

-- ── Reactive state ───────────────────────────────────────────────────────────
local goldValue = scope:Value(0)
local rowsValue = scope:Value({})
local selectedToolName = scope:Value(nil :: string?)
local lockedSet = scope:Value({} :: { [string]: boolean })
local spinningValue = scope:Value(false)
local skipAnimationValue = scope:Value(false)
local oddsInfoValue = scope:Value(nil :: any)
local oddsPopupVisible = scope:Value(false)
local overlayVisible = scope:Value(false)
local filterValue = scope:Value("All")
local pointerVisible = scope:Value(false)
local layout = scope:Value({
	wide = true, s = 1, stageW = STAGE_W_WIDE, trayW = TRAY_W_WIDE, trayH = TRAY_H_WIDE,
	W = X0 + TRAY_W_WIDE + MID + STAGE_W_WIDE + EDGE, H = HEADER_H + STAGE_TOP + STAGE_H + EDGE,
})
local reelShown = scope:Value(false) -- the reel covers the lock grid while it spins and reveals

local selectedC = scope:Computed(function(use)
	local rows = use(rowsValue)
	local name = use(selectedToolName)
	if not name then return nil end
	for _, info in ipairs(rows) do
		if info.toolName == name then return info end
	end
	return nil
end)

local modsC = scope:Computed(function(use)
	local info = use(selectedC)
	return SwordValue.modifiersFromPrefixes(info and info.prefixes or "")
end)

local lockNamesC = scope:Computed(function(use)
	local locked = use(lockedSet)
	local names = {}
	for _, mod in ipairs(use(modsC)) do
		if locked[mod.name] then table.insert(names, mod.name) end
	end
	return names
end)

local costC = scope:Computed(function(use)
	local info = use(selectedC)
	if not info then return 0 end
	local names = use(lockNamesC)
	if #names > 0 then
		return SwordValue.rerollCostWithLocks({ Rarity = info.rarity, Prefixes = info.prefixes, ExtraSlot = info.blessed,
			BossTier = info.tier }, names)
	end
	local odds = use(oddsInfoValue)
	if odds and (odds.freeIn or 1) <= 0 then return 0 end
	return info.cost
end)

local affordC = scope:Computed(function(use) return use(goldValue) >= use(costC) end)
local strikeReadyC = scope:Computed(function(use)
	return use(selectedC) ~= nil and not use(spinningValue) and use(affordC)
end)

local filteredRowsC = scope:Computed(function(use)
	local rows, filter = use(rowsValue), use(filterValue)
	if filter == "All" then return rows end
	local out = {}
	for _, info in ipairs(rows) do
		if info.rarity == filter then table.insert(out, info) end
	end
	return out
end)

local function goldText(n: number): string
	return n < 100000 and tostring(math.floor(n)) or SwordValue.short(n)
end

local costTextC = scope:Computed(function(use)
	local cost = use(costC)
	return cost == 0 and "FREE" or goldText(cost)
end)

-- The sword's own name without its rolled modifier words ("Blessed Mythic ... Astral Eclipse"
-- -> "Astral Eclipse"); the modifiers are listed under it as lock chips.
local function baseName(name: string?): string
	local words = {}
	for word in string.gmatch(name or "", "%S+") do
		if word ~= "Blessed" and not SwordValue.TIER_BY_NAME[word] then table.insert(words, word) end
	end
	return #words > 0 and table.concat(words, " ") or (name or "Relic Sword")
end

local selectedTitleTextC = scope:Computed(function(use)
	local info = use(selectedC)
	return info and baseName(info.name) or "Pick a sword"
end)

local strikeLabelC = scope:Computed(function(use)
	if use(spinningValue) then return "REFORGING..." end
	if not use(selectedC) then return "PICK A SWORD" end
	local n = #use(lockNamesC)
	if not use(affordC) then return "NEED MORE GOLD" end
	if n > 0 then return string.format("REFORGE, KEEP %d", n) end
	return "REFORGE"
end)

local pityFracC = scope:Computed(function(use)
	local odds = use(oddsInfoValue)
	if not odds then return 0 end
	return math.clamp((odds.pity or 0) / math.max(odds.pityAfter or 5, 1), 0, 1)
end)
local pityShortC = scope:Computed(function(use)
	local odds = use(oddsInfoValue)
	if not odds then return "" end
	local pity, after = odds.pity or 0, odds.pityAfter or 5
	if pity >= after then return "READY!" end
	return string.format("%d LEFT", after - pity)
end)

local oddsPopupTextC = scope:Computed(function(use)
	local info = use(selectedC)
	local odds = use(oddsInfoValue)
	if not info or not odds or not odds.odds or not odds.odds[info.rarity] then
		return "Pick a sword to see the exact chance of each modifier tier for its rarity."
	end
	local o = odds.odds[info.rarity]
	local parts = {}
	for tier = 1, #o.tiers do
		table.insert(parts, string.format("T%d %.1f%%", tier, o.tiers[tier] * 100))
	end
	local pity, after = odds.pity or 0, odds.pityAfter or 5
	local pityText = pity >= after
		and string.format("Guaranteed lucky roll ready: next reforge guarantees a T%d+ modifier.", odds.pityTier or 4)
		or string.format("Guaranteed lucky roll in %d / %d reforges (then a T%d+ modifier is guaranteed).", pity, after, odds.pityTier or 4)
	return string.format("%s odds per modifier: %s.  %s", info.rarity, table.concat(parts, "  "), pityText)
end)

local freeReadyC = scope:Computed(function(use)
	local odds = use(oddsInfoValue)
	return odds ~= nil and (odds.freeIn or 0) <= 0
end)
local freeTextC = scope:Computed(function(use)
	local odds = use(oddsInfoValue)
	if not odds then return "FREE STRIKE" end
	local freeIn = odds.freeIn or 0
	if freeIn <= 0 then return "FREE STRIKE READY" end
	return string.format("FREE IN %dH %02dM", math.floor(freeIn / 3600), math.floor(freeIn % 3600 / 60))
end)
local bestTextC = scope:Computed(function(use)
	local odds = use(oddsInfoValue)
	return "BEST " .. SwordValue.short(odds and odds.best or 0)
end)
local countTextC = scope:Computed(function(use)
	local odds = use(oddsInfoValue)
	return string.format("%d FORGED", odds and odds.count or 0)
end)
-- The anvil's record (free strike, best roll, reforge count) sits in the Odds popup's footer.
local statsLineC = scope:Computed(function(use)
	local free = use(freeTextC)
	if use(freeReadyC) then free = '<font color="#2E9E34">' .. free .. "</font>" end
	return free .. "  ·  " .. use(bestTextC) .. "  ·  " .. use(countTextC)
end)

-- ── Actions ──────────────────────────────────────────────────────────────────
local function toggleLock(modName: string)
	if peek(spinningValue) then return end
	local copy = table.clone(peek(lockedSet))
	copy[modName] = (not copy[modName]) or nil
	lockedSet:set(copy)
end

local function selectTool(toolName: string)
	if peek(spinningValue) then return end
	if peek(selectedToolName) ~= toolName then
		lockedSet:set({})
	end
	reelShown:set(false)
	selectedToolName:set(toolName)
end

local function setOddsPopupVisible(visible: boolean)
	oddsPopupVisible:set(visible)
end

local reforgeMotion -- shared open/close motion (PanelChrome), set once the window exists

local function close()
	if peek(spinningValue) then return end
	setOddsPopupVisible(false)
	if not peek(overlayVisible) or not reforgeMotion then
		overlayVisible:set(false)
		return
	end
	PanelChrome.closeMotion(reforgeMotion, function() overlayVisible:set(false) end)
end

local function lockList()
	return peek(lockNamesC)
end

local function currentCost()
	return peek(costC)
end

local function strike()
	if peek(spinningValue) or not peek(selectedC) then return end
	if peek(goldValue) < currentCost() then return end
	REFORGE:FireServer("Reroll", peek(selectedToolName), lockList())
	lockedSet:set({})
end

-- ── Small helpers ────────────────────────────────────────────────────────────
local function L(fn)
	return scope:Computed(function(use) return fn(use(layout)) end)
end

local function tierColors(tier: number)
	local c = TIER_COLORS[tier] or TIER_COLORS[1]
	return c:Lerp(WHITE, 0.5), c, c:Lerp(BRIGHT.Outline, 0.45)
end

local function image(parent, img, size, props)
	local l = Instance.new("ImageLabel")
	l.BackgroundTransparency = 1
	l.Image = img
	l.ScaleType = Enum.ScaleType.Fit
	l.Size = UDim2.fromOffset(size, size)
	for k, v in pairs(props or {}) do l[k] = v end
	l.Parent = parent
	return l
end

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

-- A cartoon anvil built from parts, with a white-hot blade resting on its face.
local function renderAnvil(viewport)
	for _, c in ipairs(viewport:GetChildren()) do c:Destroy() end
	viewport.Ambient = Color3.fromRGB(200, 204, 222)
	viewport.LightColor = Color3.fromRGB(255, 244, 226)
	viewport.LightDirection = Vector3.new(-0.5, -1, -0.8)
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local iron, ironDark = Color3.fromRGB(104, 112, 142), Color3.fromRGB(58, 62, 84)
	local cyl = Enum.PartType.Cylinder
	part(world, "Part", "Base", Vector3.new(3.4, 0.7, 2.2), CFrame.new(0, -1.5, 0), ironDark)
	part(world, "Part", "Foot", Vector3.new(2.4, 0.5, 1.7), CFrame.new(0, -1.0, 0), iron)
	part(world, "Part", "Waist", Vector3.new(1.4, 1.0, 1.1), CFrame.new(0, -0.35, 0), ironDark)
	part(world, "Part", "Face", Vector3.new(3.4, 0.9, 1.7), CFrame.new(0.2, 0.55, 0), iron)
	part(world, "Part", "Horn", Vector3.new(1.4, 0.9, 0.9), CFrame.new(-2.1, 0.62, 0), iron, nil, cyl)
	part(world, "Part", "HornTip", Vector3.new(0.6, 0.6, 0.6), CFrame.new(-2.85, 0.66, 0), iron, nil, Enum.PartType.Ball)
	part(world, "Part", "Heel", Vector3.new(0.6, 0.7, 1.5), CFrame.new(2.1, 0.6, 0), ironDark)
	-- the blade being forged, glowing hot
	part(world, "Part", "Blade", Vector3.new(3.0, 0.18, 0.55), CFrame.new(0.1, 1.1, 0.1) * CFrame.Angles(0, math.rad(-12), 0),
		Color3.fromRGB(255, 160, 50), Enum.Material.Neon)
	part(world, "Part", "Guard", Vector3.new(0.22, 0.24, 1.1), CFrame.new(1.7, 1.1, 0.45) * CFrame.Angles(0, math.rad(-12), 0),
		Color3.fromRGB(255, 206, 60), Enum.Material.Metal)
	part(world, "Part", "Grip", Vector3.new(0.8, 0.26, 0.26), CFrame.new(2.2, 1.1, 0.56) * CFrame.Angles(0, math.rad(-12), 0),
		Color3.fromRGB(110, 62, 34))
	for i, spec in ipairs({ { -0.8, 1.9, 0.6, 0.32 }, { 0.4, 2.3, 0.2, 0.24 }, { 1.2, 1.8, 0.8, 0.2 } }) do
		part(world, "Part", "Spark" .. i, Vector3.new(spec[4], spec[4], spec[4]), CFrame.new(spec[1], spec[2], spec[3]),
			Color3.fromRGB(255, 230, 90), Enum.Material.Neon, Enum.PartType.Ball)
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local target = Vector3.new(0, 0.1, 0)
	camera.CFrame = CFrame.lookAt(target + Vector3.new(2.6, 3.4, 8.4).Unit * 14.2, target)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

-- Stand-in sword for a row whose Tool is not on the client: Handle grip with the blade along
-- -Z, tinted with its boss tier's colour (same build as the Vault's).
local function buildStandInSword(tier)
	local weapon = BossWeapons.GetByTier(tier or 1)
	local bladeColor = (weapon and weapon.color) or Color3.fromRGB(200, 206, 218)
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

-- Draws a row's sword: the carried Tool itself when it is on the client, else the stand-in.
local function renderSword(viewport, info, opts)
	local tool
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		local found = container and info and container:FindFirstChild(info.toolName)
		if found and found:IsA("Tool") then tool = found break end
	end
	if tool and PanelChrome.renderTool(viewport, tool, opts) then return end
	local standIn = buildStandInSword(info and info.tier)
	PanelChrome.renderTool(viewport, standIn, opts)
	standIn:Destroy()
end

-- A cut gem: a square turned 45 degrees in the rarity's gradient, with a glossy facet.
local function gemIcon(parent, size, rarity, z)
	local t = RARITY_TILE[rarity] or RARITY_TILE.Common
	local gem = Instance.new("Frame")
	gem.Name = "Gem"
	gem.AnchorPoint = Vector2.new(0.5, 0.5)
	gem.Position = UDim2.fromScale(0.5, 0.5)
	gem.Size = UDim2.fromOffset(size, size)
	gem.Rotation = 45
	gem.BackgroundColor3 = WHITE
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
	facet.BackgroundColor3 = WHITE
	facet.BackgroundTransparency = 0.2
	facet.BorderSizePixel = 0
	facet.ZIndex = z
	facet.Parent = gem
	corner(facet, 4)
	return gem
end

-- Rounded pill with a stroked display label; text may be a string or a state object.
local function pill(s, props)
	return s:New "Frame" {
		Name = props.name or "Pill",
		LayoutOrder = props.order or 0,
		Size = UDim2.fromOffset(0, props.height or 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = WHITE,
		Visible = props.visible,
		ZIndex = props.zIndex or 8,
		[Children] = {
			s:New "UICorner" { CornerRadius = UDim.new(0, (props.height or 34) / 2) },
			s:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 2.5 },
			s:New "UIGradient" { Rotation = 90, Color = props.gradient },
			s:New "UIPadding" { PaddingLeft = UDim.new(0, props.icon and 4 or 14), PaddingRight = UDim.new(0, 14) },
			s:New "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
			},
			props.icon and s:New "ImageLabel" {
				LayoutOrder = 1, BackgroundTransparency = 1, Image = props.icon, ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromOffset((props.height or 34) - 2, (props.height or 34) - 2), ZIndex = (props.zIndex or 8) + 1,
			} or nil,
			s:New "TextLabel" {
				LayoutOrder = 2, BackgroundTransparency = 1, Font = DISPLAY, TextSize = props.textSize or 18,
				TextColor3 = props.textColor or WHITE, Text = props.text,
				Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, ZIndex = (props.zIndex or 8) + 1,
				[Children] = { s:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 2 } },
			},
		},
	}
end

local function seq(top, bottom) return ColorSequence.new(top, bottom) end

-- One tier tile for the odds preview: the tier number big over its colour, the chance under it.
local function tierTile(tier: number, sizeProp)
	local top, bottom, rim = tierColors(tier)
	local pctC = scope:Computed(function(use)
		local info, odds = use(selectedC), use(oddsInfoValue)
		local o = info and odds and odds.odds and odds.odds[info.rarity]
		if not (o and o.tiers[tier]) then return "?" end
		local p = o.tiers[tier] * 100
		return p >= 10 and string.format("%d%%", math.floor(p + 0.5)) or string.format("%.1f%%", p)
	end)
	local tile = scope:New "Frame" {
		Name = "Tier" .. tier, LayoutOrder = tier, Size = sizeProp, BackgroundColor3 = WHITE, ZIndex = 7,
		[Children] = {
			scope:New "UICorner" { CornerRadius = UDim.new(0, 14) },
			scope:New "UIGradient" { Rotation = 90, Color = seq(top, bottom) },
			scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 3 },
			scope:New "Frame" {
				Name = "Rim", BackgroundTransparency = 1, Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), ZIndex = 7,
				[Children] = { scope:New "UICorner" { CornerRadius = UDim.new(0, 11) }, scope:New "UIStroke" { Color = rim, Thickness = 2.5 } },
			},
		},
	}
	local shine = Instance.new("Frame")
	shine.BackgroundColor3 = WHITE
	shine.BackgroundTransparency = 0.6
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromOffset(6, 6)
	shine.Size = UDim2.new(1, -12, 0.26, 0)
	shine.ZIndex = 7
	shine.Parent = tile
	corner(shine, 9)
	PanelChrome.display(tile, { text = "T" .. tier, size = 34, stroke = 3, pos = UDim2.fromScale(0, 0.06), size2 = UDim2.fromScale(1, 0.5), scaled = true, minSize = 14, zIndex = 8 })
	local pct = PanelChrome.display(tile, { text = "", size = 20, stroke = 2.5, pos = UDim2.fromScale(0.04, 0.56), size2 = UDim2.fromScale(0.92, 0.34), scaled = true, minSize = 10, zIndex = 8 })
	scope:Hydrate(pct) { Text = pctC }
	return tile
end

-- A chunky bevelled button (PanelChrome.chunkyButton) with a dark drop shadow, in a holder the
-- layouts can size. Returns holder, button, label, gradient and the bevel lip.
local function chunky(props)
	local holder = scope:New "Frame" {
		Name = (props.name or "Button") .. "Holder", BackgroundTransparency = 1, LayoutOrder = props.order or 0,
		Size = props.size, ZIndex = 7,
	}
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Position = UDim2.fromOffset(0, 6)
	shadow.Size = UDim2.new(1, 0, 1, -6)
	shadow.BackgroundColor3 = BRIGHT.Outline
	shadow.BackgroundTransparency = 0.45
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 7
	shadow.Parent = holder
	corner(shadow, 18)
	local btn, label, grad = PanelChrome.chunkyButton(holder, {
		name = props.name, text = props.text or "", color = props.color, colorDark = props.colorDark,
		size = UDim2.new(1, 0, 1, -6), textSize = props.textSize or 26, zIndex = 8, radius = 18, strokeThickness = 3.5,
	})
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.AnchorPoint = Vector2.new(0.5, 1)
	lip.Position = UDim2.new(0.5, 0, 1, -3)
	lip.Size = UDim2.new(1, -14, 0, 7)
	lip.BackgroundColor3 = props.colorDark
	lip.BorderSizePixel = 0
	lip.ZIndex = 8
	lip.Parent = btn
	corner(lip, 4)
	return holder, btn, label, grad, lip
end

-- ── Reactive list: sword tiles ───────────────────────────────────────────────
-- One idea per tile, like the Inventory's: the sword framed big on its rarity face and a single
-- stat (its rating) under it. The name lives on the hero card.
local function decorateSwordTile(tile, info)
	local rarity = info.rarity or "Common"
	corner(tile, 18)
	PanelChrome.lootTile(tile, rarity, { radius = 18, zIndex = 6, glowY = 0.42 })
	if info.blessed then
		-- a small gold gem in the corner, so outlines stay free to mark the picked tile
		local gem = Instance.new("Frame")
		gem.Name = "BlessedGem"
		gem.AnchorPoint = Vector2.new(0.5, 0.5)
		gem.Position = UDim2.fromOffset(17, 17)
		gem.Size = UDim2.fromOffset(15, 15)
		gem.Rotation = 45
		gem.BackgroundColor3 = WHITE
		gem.BorderSizePixel = 0
		gem.ZIndex = 10
		gem.Parent = tile
		corner(gem, 4)
		PanelChrome.gradient(gem, Color3.fromRGB(255, 250, 190), BRIGHT.GoldDark)
		PanelChrome.stroke(gem, BRIGHT.Outline, 2.5)
	end

	-- The sword fills the tile's face, clear of the stat under it.
	local view = Instance.new("ViewportFrame")
	view.Name = "SwordRender"
	view.BackgroundTransparency = 1
	view.Position = UDim2.fromScale(0.03, 0.0)
	view.Size = UDim2.fromScale(0.94, 0.8)
	view.ZIndex = 8
	view.Parent = tile
	renderSword(view, info, { tiltDeg = 45, margin = 0.74 })

	-- The one stat: rating, trophy and a chunky number centred along the bottom.
	local stat = Instance.new("Frame")
	stat.Name = "Rating"
	stat.BackgroundTransparency = 1
	stat.AnchorPoint = Vector2.new(0.5, 1)
	stat.Position = UDim2.new(0.5, 0, 1, -3)
	stat.Size = UDim2.new(1, -8, 0, 30)
	stat.ZIndex = 10
	stat.Parent = tile
	local statList = Instance.new("UIListLayout")
	statList.FillDirection = Enum.FillDirection.Horizontal
	statList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	statList.VerticalAlignment = Enum.VerticalAlignment.Center
	statList.Padding = UDim.new(0, 1)
	statList.SortOrder = Enum.SortOrder.LayoutOrder
	statList.Parent = stat
	image(stat, TROPHY_ICON, 28, { LayoutOrder = 1, ZIndex = 10 })
	local value = PanelChrome.display(stat, { name = "RatingText", text = SwordValue.short(info.rating or 0), size = 24, stroke = 3, zIndex = 10 })
	value.LayoutOrder = 2
	value.Size = UDim2.fromScale(0, 1)
	value.AutomaticSize = Enum.AutomaticSize.X
	if info.equipped then
		local check = PanelChrome.checkBadge(tile, 28, 11)
		check.Position = UDim2.new(1, -10, 0, 10)
	end
end

local listRows = scope:ForPairs(filteredRowsC, function(use, innerScope, index, info)
	local isSelected = innerScope:Computed(function(use2) return use2(selectedToolName) == info.toolName end)
	local tile = innerScope:New "TextButton" {
		Name = info.toolName,
		LayoutOrder = index,
		Text = "",
		AutoButtonColor = false,
		-- the picked tile draws over its neighbours so its ring and bump are never covered
		ZIndex = innerScope:Computed(function(use2) return use2(isSelected) and 7 or 6 end),
		[OnEvent "Activated"] = function()
			if not peek(spinningValue) then selectTool(info.toolName) end
		end,
		[Children] = {
			innerScope:New "UIScale" { Scale = innerScope:Computed(function(use2) return use2(isSelected) and 1.08 or 1 end) },
			-- Selection: a thick white ring hugging the tile, edged dark so it reads on any rarity.
			innerScope:New "Frame" {
				Name = "SelectRing", BackgroundTransparency = 1, Position = UDim2.fromOffset(-3, -3), Size = UDim2.new(1, 6, 1, 6),
				ZIndex = 12, Visible = isSelected,
				[Children] = {
					innerScope:New "UICorner" { CornerRadius = UDim.new(0, 21) },
					innerScope:New "UIStroke" { Color = WHITE, Thickness = 7 },
				},
			},
			innerScope:New "Frame" {
				Name = "SelectEdge", BackgroundTransparency = 1, Position = UDim2.fromOffset(-10, -10), Size = UDim2.new(1, 20, 1, 20),
				ZIndex = 12, Visible = isSelected,
				[Children] = {
					innerScope:New "UICorner" { CornerRadius = UDim.new(0, 28) },
					innerScope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 3 },
				},
			},
		},
	}
	decorateSwordTile(tile, info)
	return index, tile
end)

-- ── Reactive list: lock chips (one per modifier on the selected sword) ──────
-- Calm white chips like the Inventory's slots: the tier's colour lives only in the padlock
-- badge on the left and the tier line, so the stage keeps one focal point (the hero). A locked
-- chip turns gold.
local LOCKED_TOP, LOCKED_BOTTOM = Color3.fromRGB(255, 246, 196), Color3.fromRGB(255, 212, 90)
local lockChips = scope:ForPairs(modsC, function(use, innerScope, index, mod)
	local isLocked = innerScope:Computed(function(use2) return use2(lockedSet)[mod.name] == true end)
	local top, bottom, deep = tierColors(mod.tier)
	local chip = innerScope:New "TextButton" {
		Name = "Lock_" .. mod.name,
		LayoutOrder = index, -- sized by the lock grid, two chips to a row
		BackgroundColor3 = WHITE,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 7,
		[OnEvent "Activated"] = function() toggleLock(mod.name) end,
		[Children] = {
			innerScope:New "UICorner" { CornerRadius = UDim.new(0, 16) },
			innerScope:New "UIGradient" {
				Rotation = 90,
				Color = innerScope:Computed(function(use2)
					return use2(isLocked) and seq(LOCKED_TOP, LOCKED_BOTTOM) or seq(WHITE, Color3.fromRGB(226, 233, 247))
				end),
			},
			innerScope:New "UIStroke" {
				Color = innerScope:Computed(function(use2) return use2(isLocked) and BRIGHT.GoldDark or BRIGHT.Outline end),
				Thickness = innerScope:Computed(function(use2) return use2(isLocked) and 5 or 3.5 end),
			},
			innerScope:New "UIScale" { Scale = innerScope:Computed(function(use2) return use2(isLocked) and 1.04 or 1 end) },
			-- Tier badge: a rounded square in the tier's colour holding the padlock (the shackle
			-- lifts open when unlocked).
			innerScope:New "Frame" {
				Name = "TierBadge", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0),
				Size = UDim2.fromOffset(50, 50), BackgroundColor3 = WHITE, ZIndex = 8,
				[Children] = {
					innerScope:New "UICorner" { CornerRadius = UDim.new(0, 13) },
					innerScope:New "UIGradient" { Rotation = 90, Color = seq(top, bottom) },
					innerScope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 3 },
					innerScope:New "Frame" {
						Name = "Padlock", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 40), ZIndex = 8,
						[Children] = {
							innerScope:New "Frame" {
								Name = "Shackle", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), ZIndex = 8,
								Position = innerScope:Computed(function(use2)
									return use2(isLocked) and UDim2.new(0.5, 0, 0, 4) or UDim2.new(0.5, 5, 0, -2)
								end),
								Size = UDim2.fromOffset(19, 24),
								[Children] = {
									innerScope:New "UICorner" { CornerRadius = UDim.new(0, 10) },
									innerScope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 4.5 },
								},
							},
							innerScope:New "Frame" {
								Name = "Body", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2),
								Size = UDim2.fromOffset(28, 22), ZIndex = 9,
								BackgroundColor3 = innerScope:Computed(function(use2) return use2(isLocked) and BRIGHT.Gold or WHITE end),
								[Children] = {
									innerScope:New "UICorner" { CornerRadius = UDim.new(0, 6) },
									innerScope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 2.5 },
									innerScope:New "Frame" {
										AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(5, 9),
										BackgroundColor3 = BRIGHT.Outline, ZIndex = 10,
										[Children] = { innerScope:New "UICorner" { CornerRadius = UDim.new(0, 3) } },
									},
								},
							},
						},
					},
				},
			},
			innerScope:New "TextLabel" {
				Name = "ModName", BackgroundTransparency = 1, Position = UDim2.fromOffset(70, 6), Size = UDim2.new(1, -80, 0, 32),
				Font = DISPLAY, Text = mod.name, TextColor3 = BRIGHT.Ink, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
				[Children] = {
					innerScope:New "UITextSizeConstraint" { MaxTextSize = 26, MinTextSize = 16 },
				},
			},
			innerScope:New "TextLabel" {
				Name = "ModInfo", BackgroundTransparency = 1, Position = UDim2.fromOffset(70, 38), Size = UDim2.new(1, -80, 0, 22),
				Font = DISPLAY, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
				TextColor3 = innerScope:Computed(function(use2) return use2(isLocked) and Color3.fromRGB(150, 86, 6) or deep end),
				Text = innerScope:Computed(function(use2)
					local odds = use2(oddsInfoValue)
					local factors = (odds and odds.lockTierFactor) or SwordValue.LOCK_TIER_FACTOR
					local pct = math.floor((factors[mod.tier] or 0) * 100 + 0.5)
					return use2(isLocked) and string.format("LOCKED  +%d%%", pct) or string.format("T%d  ·  lock +%d%%", mod.tier, pct)
				end),
				[Children] = {
					innerScope:New "UITextSizeConstraint" { MaxTextSize = 18, MinTextSize = 14 },
				},
			},
		},
	}
	return index, chip
end)
local modsHintC = scope:Computed(function(use)
	if not use(selectedC) then return "Its modifiers show here. Tap one to lock it before you strike." end
	return #use(modsC) == 0 and "No modifiers yet. Strike to roll some!" or ""
end)

-- ── Scaffolding ──────────────────────────────────────────────────────────────
local screenGui = scope:New "ScreenGui" {
	Name = "ReforgeGuiFusion",
	ResetOnSpawn = false,
	DisplayOrder = 22,
	Parent = playerGui,
}

local panelScale = Instance.new("UIScale")
local popupScale = Instance.new("UIScale")

local chrome = PanelChrome.buildBright({ name = "Modal", title = "Reforge", titleSize = 50, closeSize = CLOSE })
local modal = chrome.Frame
modal.Size = UDim2.fromScale(1, 1)
modal.Active = true
modal.ZIndex = 3
chrome.CloseButton.Activated:Connect(close)
chrome.TitleLabel.Position = UDim2.fromOffset(86, -2)

-- Title badge: the anvil, big and tilted over the panel's top-left corner.
do
	local titleIcon = chrome.TitleIcon
	titleIcon.Image = ""
	titleIcon.Size = UDim2.fromOffset(112, 112)
	titleIcon.Position = UDim2.fromOffset(-32, -4)
	titleIcon.Rotation = -6
	local titleAnvil = Instance.new("ViewportFrame")
	titleAnvil.Name = "Anvil"
	titleAnvil.BackgroundTransparency = 1
	titleAnvil.Size = UDim2.fromScale(1, 1)
	titleAnvil.ZIndex = titleIcon.ZIndex
	titleAnvil.Parent = titleIcon
	renderAnvil(titleAnvil)
end

-- ── Header: gold pill and the anvil's promise ────────────────────────────────
local GOLD_W_WIDE, GOLD_W_TALL = 210, 150
local goldPill = scope:New "Frame" {
	Name = "GoldPill", AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -(CLOSE + 26), 0, HEADER_H / 2 + 2),
	Size = L(function(l) return UDim2.fromOffset(l.wide and GOLD_W_WIDE or GOLD_W_TALL, 52) end),
	BackgroundColor3 = WHITE, ZIndex = 8,
	[Children] = {
		scope:New "UICorner" { CornerRadius = UDim.new(0, 26) },
		scope:New "UIGradient" { Rotation = 90, Color = seq(Color3.fromRGB(255, 255, 255), Color3.fromRGB(226, 232, 246)) },
		scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 3.5 },
	},
}
image(goldPill, COIN_ICON, 64, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -22, 0.5, -2), ZIndex = 9 })
do
	local goldLabel = PanelChrome.display(goldPill, {
		name = "GoldAmount", text = "0", size = 34, stroke = 3, color = BRIGHT.Gold,
		pos = UDim2.fromOffset(44, 0), size2 = UDim2.new(1, -56, 1, 0), zIndex = 9, scaled = true, minSize = 14,
	})
	scope:Hydrate(goldLabel) { Text = scope:Computed(function(use) return goldText(use(goldValue)) end) }
end
goldPill.Parent = modal

scope:Hydrate(chrome.TitleLabel) {
	Size = L(function(l)
		return UDim2.new(0, math.max(120, l.W - 86 - (CLOSE + 26 + (l.wide and GOLD_W_WIDE or GOLD_W_TALL) + 16)), 0, 58)
	end),
}

-- ── Rarity rail ──────────────────────────────────────────────────────────────
local rail = scope:New "Frame" {
	Name = "RarityRail", Parent = modal,
	Position = UDim2.fromOffset(RAIL_X, HEADER_H + 14),
	Size = UDim2.fromOffset(RAIL_W, #RARITIES * (TAB + 8) + 16),
	BackgroundColor3 = WHITE, ZIndex = 6,
	[Children] = {
		scope:New "UICorner" { CornerRadius = UDim.new(0, 24) },
		scope:New "UIGradient" { Rotation = 90, Color = seq(BRIGHT.Panel, BRIGHT.PanelBottom) },
		scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 4 },
		scope:New "UIListLayout" {
			Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
		},
		scope:New "UIPadding" { PaddingTop = UDim.new(0, 8) },
	},
}
for i, rarity in ipairs(RARITIES) do
	local isActive = scope:Computed(function(use) return use(filterValue) == rarity end)
	local countC = scope:Computed(function(use)
		local n = 0
		for _, info in ipairs(use(rowsValue)) do
			if rarity == "All" or info.rarity == rarity then n += 1 end
		end
		return n
	end)
	local tab = scope:New "TextButton" {
		Name = "Tab_" .. rarity, Parent = rail, LayoutOrder = i, Text = "", AutoButtonColor = false,
		Size = UDim2.fromOffset(TAB, TAB), ZIndex = 7,
		BackgroundColor3 = scope:Computed(function(use) return use(isActive) and BRIGHT.Select or BRIGHT.Row end),
		[OnEvent "Activated"] = function() filterValue:set(rarity) end,
		[Children] = {
			scope:New "UICorner" { CornerRadius = UDim.new(0, 18) },
			scope:New "UIStroke" {
				Color = scope:Computed(function(use) return use(isActive) and BRIGHT.Blue or BRIGHT.RowStroke end),
				Thickness = scope:Computed(function(use) return use(isActive) and 3.5 or 2.5 end),
			},
		},
	}
	if rarity == "All" then
		local view = Instance.new("ViewportFrame")
		view.Name = "Anvil"
		view.BackgroundTransparency = 1
		view.Position = UDim2.fromScale(-0.05, 0)
		view.Size = UDim2.fromScale(1.1, 1.1)
		view.ZIndex = 8
		view.Parent = tab
		renderAnvil(view)
	else
		gemIcon(tab, 34, rarity, 8)
	end
	local badge, badgeLabel = PanelChrome.countBadge(tab, "0", 9)
	scope:Hydrate(badge) { Visible = scope:Computed(function(use) return use(countC) > 0 end) }
	scope:Hydrate(badgeLabel) { Text = scope:Computed(function(use) return tostring(use(countC)) end) }
end

-- ── Sword tray ───────────────────────────────────────────────────────────────
local trayHeadPos = L(function(l)
	return l.wide and UDim2.fromOffset(X0 + 6, HEADER_H) or UDim2.fromOffset(X0 + 6, HEADER_H + STAGE_TOP + STAGE_H + 14)
end)
scope:New "Frame" {
	Name = "TrayHead", Parent = modal, BackgroundTransparency = 1, ZIndex = 7,
	Position = trayHeadPos,
	Size = L(function(l) return UDim2.fromOffset((l.wide and l.trayW or l.stageW) - 6, SEC_H) end),
	[Children] = {
		scope:New "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder,
		},
		scope:New "TextLabel" {
			LayoutOrder = 1, BackgroundTransparency = 1, Font = DISPLAY, TextSize = 30, TextColor3 = BRIGHT.Ink,
			Text = "Relic Swords", Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 7,
		},
		scope:New "TextLabel" {
			LayoutOrder = 2, BackgroundTransparency = 1, Font = DISPLAY, TextSize = 30, TextColor3 = BRIGHT.Blue,
			Text = scope:Computed(function(use) return tostring(#use(filteredRowsC)) end),
			Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 7,
			[Children] = { scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 2.5 } },
		},
	},
}

local trayScroll = scope:New "ScrollingFrame" {
	Name = "SwordScroll", BackgroundTransparency = 1, BorderSizePixel = 0,
	Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), ZIndex = 5,
	ScrollBarThickness = SCROLLBAR, ScrollBarImageColor3 = BRIGHT.GreyDark, ScrollingDirection = Enum.ScrollingDirection.Y,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	[Children] = {
		scope:New "UIPadding" {
			PaddingTop = UDim.new(0, TOP_PAD), PaddingBottom = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, TRAY_PAD - 4), PaddingRight = UDim.new(0, SCROLLBAR + 2),
		},
		scope:New "UIGridLayout" {
			CellSize = UDim2.fromOffset(TILE, TILE), CellPadding = UDim2.fromOffset(GAP, VGAP),
			FillDirectionMaxCells = 3, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		listRows,
	},
}
local tray = scope:New "Frame" {
	Name = "SwordTray", Parent = modal, ZIndex = 4, ClipsDescendants = false,
	Position = L(function(l)
		return l.wide and UDim2.fromOffset(X0, HEADER_H + SEC_H) or UDim2.fromOffset(X0, HEADER_H + STAGE_TOP + STAGE_H + 14 + SEC_H)
	end),
	Size = L(function(l)
		return UDim2.fromOffset(l.wide and l.trayW or l.stageW, l.trayH)
	end),
}
PanelChrome.insetTray(tray, { top = Color3.fromRGB(230, 237, 252), bottom = Color3.fromRGB(206, 218, 242), radius = 22, zIndex = 4, strokeThickness = 3.5 })
trayScroll.Parent = tray
scope:New "TextLabel" {
	Name = "EmptyNote", Parent = tray, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.new(1, -40, 0, 80), ZIndex = 6,
	Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = BRIGHT.InkMuted, TextWrapped = true,
	Visible = scope:Computed(function(use) return #use(filteredRowsC) == 0 end),
	Text = scope:Computed(function(use)
		local f = use(filterValue)
		return f == "All" and "No relic swords yet. Boss drops can be reforged here." or ("No " .. f .. " relic swords.")
	end),
}

-- ── Stage ────────────────────────────────────────────────────────────────────
local stage = scope:New "Frame" {
	Name = "Stage", Parent = modal, BackgroundTransparency = 1, ZIndex = 4,
	Position = L(function(l)
		return UDim2.fromOffset(l.wide and (X0 + l.trayW + MID) or X0, HEADER_H + STAGE_TOP)
	end),
	Size = L(function(l) return UDim2.fromOffset(l.stageW, STAGE_H) end),
}

-- Hero card: one calm featured item, like the Inventory's. A white card; the rarity shows only as
-- the glow ring behind the sword and the rim of its framed tile, so every label stays readable.
local HERO_RING = 1.44 -- the glow ring's diameter, as a multiple of the framed tile
local heroTileSize = L(function(l) return l.wide and 150 or 122 end)
local heroRingSize = scope:Computed(function(use) return math.floor(use(heroTileSize) * HERO_RING) end)
local heroInfoX = scope:Computed(function(use) return 14 + use(heroRingSize) + 22 end)
local heroTintC = scope:Computed(function(use)
	local info = use(selectedC)
	return info and (RARITY_TILE[info.rarity] or RARITY_TILE.Common) or false
end)
local EMPTY_GLOW, EMPTY_RIM = Color3.fromRGB(214, 222, 240), Color3.fromRGB(168, 180, 206)

local heroCard = scope:New "Frame" {
	Name = "HeroCard", Parent = stage, Position = UDim2.fromOffset(0, HERO_Y), Size = UDim2.new(1, 0, 0, HERO_H),
	BackgroundColor3 = WHITE, ZIndex = 5, ClipsDescendants = false,
	[Children] = {
		scope:New "UICorner" { CornerRadius = UDim.new(0, 24) },
		scope:New "UIGradient" { Rotation = 90, Color = seq(WHITE, Color3.fromRGB(229, 236, 250)) },
		scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 4 },
	},
}

-- Light burst behind the item: a slowly turning fan of rarity-tinted rays over a soft glow disc
-- ringed in the rarity's colour, with a thin white ring inside it like the Inventory's.
local heroCentre = scope:Computed(function(use)
	return UDim2.fromOffset(14 + use(heroRingSize) / 2, HERO_H / 2)
end)
local function ringSize(extra)
	return scope:Computed(function(use) local s = use(heroRingSize) + extra return UDim2.fromOffset(s, s) end)
end
local rays = scope:New "Frame" {
	Name = "Rays", Parent = heroCard, AnchorPoint = Vector2.new(0.5, 0.5), Position = heroCentre,
	Size = ringSize(10), BackgroundTransparency = 1, ZIndex = 5,
}
local rayList = {}
for i = 0, 5 do
	local ray = Instance.new("Frame")
	ray.AnchorPoint = Vector2.new(0.5, 0.5)
	ray.Position = UDim2.fromScale(0.5, 0.5)
	ray.Size = UDim2.new(0, 30, 1, 0)
	ray.Rotation = i * 30
	ray.BackgroundColor3 = EMPTY_GLOW
	ray.BorderSizePixel = 0
	ray.ZIndex = 5
	ray.Parent = rays
	corner(ray, 12)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 0.75),
	})
	g.Parent = ray
	table.insert(rayList, ray)
end
scope:New "Frame" {
	Name = "GlowRing", Parent = heroCard, AnchorPoint = Vector2.new(0.5, 0.5), Position = heroCentre, Size = ringSize(-14),
	BackgroundColor3 = scope:Computed(function(use) local t = use(heroTintC) return t and t.top or EMPTY_GLOW end),
	BackgroundTransparency = 0.35, ZIndex = 5,
	[Children] = {
		scope:New "UICorner" { CornerRadius = UDim.new(1, 0) },
		scope:New "UIStroke" {
			Color = scope:Computed(function(use) local t = use(heroTintC) return t and t.bottom or EMPTY_RIM end),
			Thickness = 5, Transparency = 0.2,
		},
		scope:New "Frame" {
			Name = "Core", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8),
			BackgroundColor3 = WHITE, BackgroundTransparency = 0.45, ZIndex = 5,
			[Children] = {
				scope:New "UICorner" { CornerRadius = UDim.new(1, 0) },
				scope:New "UIStroke" { Color = WHITE, Thickness = 3, Transparency = 0.1 },
			},
		},
	},
}
scope:Observer(heroTintC):onBind(function()
	local t = peek(heroTintC)
	for _, ray in ipairs(rayList) do ray.BackgroundColor3 = t and t.bottom or EMPTY_GLOW end
end)

local heroTile = scope:New "Frame" {
	Name = "HeroTile", Parent = heroCard, AnchorPoint = Vector2.new(0.5, 0.5), Position = heroCentre,
	Size = scope:Computed(function(use) local s = use(heroTileSize) return UDim2.fromOffset(s, s) end),
	BackgroundColor3 = WHITE, ZIndex = 6,
}

local heroPulse -- the empty slot's breathing prompt
local function renderHero()
	if heroPulse then heroPulse:Cancel() heroPulse = nil end
	for _, c in ipairs(heroTile:GetChildren()) do c:Destroy() end
	local info = peek(selectedC)
	heroTile.BackgroundTransparency = 0
	if info then
		-- A white frame with a thick rarity rim: the icon's colour comes from the glow behind it.
		local t = RARITY_TILE[info.rarity or "Common"] or RARITY_TILE.Common
		corner(heroTile, 24)
		PanelChrome.gradient(heroTile, WHITE, t.top:Lerp(WHITE, 0.45)).Rotation = 70
		PanelChrome.stroke(heroTile, BRIGHT.Outline, 4)
		local rim = Instance.new("Frame")
		rim.Name = "RarityRim"
		rim.BackgroundTransparency = 1
		rim.Position = UDim2.fromOffset(4, 4)
		rim.Size = UDim2.new(1, -8, 1, -8)
		rim.ZIndex = 6
		rim.Parent = heroTile
		corner(rim, 20)
		PanelChrome.stroke(rim, t.bottom, 5)
		local shine = Instance.new("Frame")
		shine.Name = "Shine"
		shine.BackgroundColor3 = WHITE
		shine.BackgroundTransparency = 0.35
		shine.BorderSizePixel = 0
		shine.Position = UDim2.fromOffset(10, 10)
		shine.Size = UDim2.new(1, -20, 0.22, 0)
		shine.ZIndex = 6
		shine.Parent = heroTile
		corner(shine, 12)
		if info.blessed then
			local halo = Instance.new("Frame")
			halo.Name = "BlessedHalo"
			halo.BackgroundTransparency = 1
			halo.Position = UDim2.fromOffset(-7, -7)
			halo.Size = UDim2.new(1, 14, 1, 14)
			halo.ZIndex = 6
			halo.Parent = heroTile
			corner(halo, 30)
			PanelChrome.stroke(halo, BRIGHT.Gold, 4)
		end
		-- The sword is drawn bigger than its frame so it breaks out of it, like rendered item art.
		local view = Instance.new("ViewportFrame")
		view.Name = "SwordRender"
		view.BackgroundTransparency = 1
		view.AnchorPoint = Vector2.new(0.5, 0.5)
		view.Position = UDim2.fromScale(0.5, 0.47)
		view.Size = UDim2.fromScale(1.36, 1.36)
		view.ZIndex = 8
		view.Parent = heroTile
		renderSword(view, info, { tiltDeg = 45, margin = 0.8 })
		if info.equipped then
			local check = PanelChrome.checkBadge(heroTile, 36, 10)
			check.Position = UDim2.new(1, -6, 0, 6)
		end
	else
		-- Empty slot: a recessed well with a dashed rim, a ghosted sword and a breathing prompt.
		PanelChrome.emptyWell(heroTile, { radius = 24, zIndex = 6, color = Color3.fromRGB(226, 234, 250) })
		PanelChrome.dashedOutline(heroTile, { color = BRIGHT.GreyDark, radius = 24, thickness = 4, dashes = 4, zIndex = 7 })
		local ghost = Instance.new("ViewportFrame")
		ghost.Name = "Silhouette"
		ghost.BackgroundTransparency = 1
		ghost.Position = UDim2.fromScale(0.08, 0.02)
		ghost.Size = UDim2.fromScale(0.84, 0.72)
		ghost.ImageColor3 = Color3.fromRGB(112, 124, 156)
		ghost.ImageTransparency = 0.35
		ghost.ZIndex = 7
		ghost.Parent = heroTile
		local standIn = buildStandInSword(1)
		PanelChrome.renderTool(ghost, standIn, { tiltDeg = 45, margin = 0.9, ambient = Color3.new(0, 0, 0) })
		standIn:Destroy()
		local prompt = PanelChrome.display(heroTile, {
			name = "Prompt", text = "Pick a sword", size = 22, stroke = 2.5, anchor = Vector2.new(0.5, 0.5),
			pos = UDim2.fromScale(0.5, 0.82), size2 = UDim2.new(1, -16, 0, 30), scaled = true, minSize = 12, zIndex = 9,
		})
		local ps = Instance.new("UIScale")
		ps.Parent = prompt
		heroPulse = TweenService:Create(ps, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.12 })
		heroPulse:Play()
	end
end
scope:Observer(selectedC):onBind(renderHero)

-- Hero info column: three things with room around them, like the Inventory's featured item --
-- the sword's name in big display type, its rarity and power on one line, and the lucky-roll
-- bar. The cost and the free strike live on the Reforge button; the stats behind Odds.
local heroInfo = scope:New "Frame" {
	Name = "HeroInfo", Parent = heroCard, BackgroundTransparency = 1, ZIndex = 7,
	Position = scope:Computed(function(use) return UDim2.fromOffset(use(heroInfoX), 14) end),
	Size = scope:Computed(function(use) return UDim2.new(1, -(use(heroInfoX) + 18), 1, -28) end),
	[Children] = {
		scope:New "UIListLayout" {
			Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
		},
	},
}
local heroName = PanelChrome.display(heroInfo, {
	name = "HeroName", text = "Pick a sword", size = 48, stroke = 4.5, xAlign = Enum.TextXAlignment.Left,
	size2 = UDim2.new(1, 0, 0, 54), scaled = true, minSize = 20, zIndex = 8,
})
heroName.LayoutOrder = 1
scope:Hydrate(heroName) { Text = selectedTitleTextC }

local hasSelectionC = scope:Computed(function(use) return use(selectedC) ~= nil end)
do
	-- One rarity pill, then the sword's power: a big trophy and a chunky number.
	local rarityRow = scope:New "Frame" {
		Name = "RarityPower", Parent = heroInfo, LayoutOrder = 2, BackgroundTransparency = 1, ZIndex = 7,
		Size = UDim2.new(1, 0, 0, 46), Visible = hasSelectionC,
		[Children] = {
			scope:New "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder,
			},
			pill(scope, {
				name = "Rarity", order = 1, height = 38, textSize = 21,
				text = scope:Computed(function(use) local info = use(selectedC) return info and string.upper(info.rarity) or "" end),
				gradient = scope:Computed(function(use)
					local info = use(selectedC)
					local t = RARITY_TILE[info and info.rarity or "Common"] or RARITY_TILE.Common
					return seq(t.bottom, t.rim)
				end),
			}),
		},
	}
	local power = scope:New "Frame" {
		Name = "Power", Parent = rarityRow, LayoutOrder = 2, BackgroundTransparency = 1, ZIndex = 7,
		Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X,
		[Children] = {
			scope:New "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
			},
		},
	}
	image(power, TROPHY_ICON, 44, { LayoutOrder = 1, ZIndex = 8 })
	local powerLabel = PanelChrome.display(power, { name = "PowerValue", text = "", size = 40, stroke = 4, zIndex = 8 })
	powerLabel.LayoutOrder = 2
	powerLabel.Size = UDim2.fromScale(0, 1)
	powerLabel.AutomaticSize = Enum.AutomaticSize.X
	scope:Hydrate(powerLabel) {
		Text = scope:Computed(function(use) local info = use(selectedC) return info and SwordValue.short(info.rating or 0) or "" end),
	}
end

-- Lucky roll: one thick level bar with its caption and count inside it.
do
	local LUCKY_H = 38
	scope:New "Frame" {
		Name = "LuckyRoll", Parent = heroInfo, LayoutOrder = 3, ZIndex = 8,
		Size = UDim2.new(1, -4, 0, LUCKY_H), BackgroundColor3 = Color3.fromRGB(58, 64, 96), Visible = hasSelectionC,
		[Children] = {
			scope:New "UICorner" { CornerRadius = UDim.new(1, 0) },
			scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 3.5 },
			scope:New "Frame" {
				Name = "Fill", ZIndex = 9, BackgroundColor3 = WHITE,
				Size = scope:Computed(function(use) return UDim2.fromScale(math.max(use(pityFracC), 0.1), 1) end),
				[Children] = {
					scope:New "UICorner" { CornerRadius = UDim.new(1, 0) },
					scope:New "UIGradient" { Rotation = 90, Color = seq(Color3.fromRGB(150, 228, 255), Color3.fromRGB(34, 142, 236)) },
				},
			},
			scope:New "TextLabel" {
				Name = "LuckyText", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0),
				ZIndex = 10, Font = DISPLAY, TextScaled = true, TextColor3 = WHITE,
				Text = scope:Computed(function(use)
					local short = use(pityShortC)
					return short == "" and "LUCKY ROLL" or ("LUCKY ROLL  ·  " .. short)
				end),
				[Children] = {
					scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 2.5 },
					scope:New "UITextSizeConstraint" { MaxTextSize = 21, MinTextSize = 14 },
				},
			},
		},
	}
end

scope:New "TextLabel" {
	Name = "EmptyHint", Parent = heroInfo, LayoutOrder = 6, BackgroundTransparency = 1, ZIndex = 8,
	Size = UDim2.new(1, 0, 0, 96), Visible = scope:Computed(function(use) return not use(hasSelectionC) end),
	Font = DISPLAY, TextSize = 22, TextColor3 = BRIGHT.Ink, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	Text = L(function(l)
		return (l.wide and "Tap a relic sword on the left" or "Tap a relic sword below") .. " to set it on the anvil, then strike to re-roll its modifiers."
	end),
}

-- Modifier lock chips: a two-column grid that wraps, so every name shows in full.
local modsGrid = scope:New "Frame" {
	Name = "Mods", Parent = stage, BackgroundTransparency = 1, ZIndex = 5,
	Position = UDim2.fromOffset(0, MODS_Y), Size = UDim2.new(1, 0, 0, MODS_H),
	Visible = scope:Computed(function(use) return not use(reelShown) end),
	[Children] = {
		scope:New "UIPadding" { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) },
		scope:New "UIGridLayout" {
			CellSize = UDim2.new(0.5, -CHIP_GAP / 2, 0, CHIP_H), CellPadding = UDim2.fromOffset(CHIP_GAP, CHIP_GAP),
			FillDirectionMaxCells = 2, VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		lockChips,
	},
}
scope:New "TextLabel" {
	Name = "ModsHint", Parent = modsGrid, BackgroundTransparency = 1, ZIndex = 6,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -40, 0, 70),
	Font = DISPLAY, TextSize = 24, TextColor3 = BRIGHT.InkMuted, TextWrapped = true,
	Text = modsHintC, Visible = scope:Computed(function(use) return use(modsHintC) ~= "" end),
}

-- The reel: a recessed slot-machine window that takes the lock grid's place while reforging. A
-- strip of modifier cards spins past two gold pointers, then the result is revealed under it.
local strip = scope:New "Frame" {
	Name = "Strip", BackgroundTransparency = 1, ZIndex = 6,
	Size = UDim2.fromOffset((CARD_W + CARD_GAP) * REEL_CARDS, CARD_H),
	Position = UDim2.fromOffset(0, 12),
}
local function pointer(y, rot)
	return scope:New "Frame" {
		Name = "Pointer", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.fromOffset(26, 26), Rotation = rot, BackgroundColor3 = WHITE, ZIndex = 9, Visible = pointerVisible,
		[Children] = {
			scope:New "UICorner" { CornerRadius = UDim.new(0, 5) },
			scope:New "UIGradient" { Rotation = 90, Color = seq(Color3.fromRGB(255, 240, 140), BRIGHT.GoldDark) },
			scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 3 },
		},
	}
end
local BAND_Y = 12 + CARD_H + 10

local reveal = scope:New "Frame" {
	Name = "Reveal", Position = UDim2.fromOffset(12, BAND_Y), Size = UDim2.new(1, -24, 0, MODS_H - BAND_Y - 12),
	BackgroundColor3 = Color3.fromRGB(26, 28, 48), Visible = false, ZIndex = 10,
	[Children] = {
		scope:New "UICorner" { CornerRadius = UDim.new(0, 14) },
		scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 2.5 },
	},
}
local revealRating = PanelChrome.display(reveal, {
	name = "RevealRating", text = "", size = 28, stroke = 3, xAlign = Enum.TextXAlignment.Left,
	pos = UDim2.fromOffset(14, 0), size2 = UDim2.new(0.6, -14, 1, 0), scaled = true, minSize = 14, zIndex = 11,
})
local revealName = PanelChrome.display(reveal, {
	name = "RevealName", text = "", size = 24, stroke = 2.5, color = Color3.fromRGB(255, 226, 110), xAlign = Enum.TextXAlignment.Right,
	anchor = Vector2.new(1, 0), pos = UDim2.new(1, -12, 0, 6), size2 = UDim2.new(0.4, -12, 0.5, -6), scaled = true, minSize = 14, zIndex = 11,
})
local revealMods = scope:New "TextLabel" {
	Name = "RevealNotes", Parent = reveal, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -6), Size = UDim2.new(0.4, -12, 0.5, -6), ZIndex = 11,
	Font = DISPLAY, TextScaled = true, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Right,
	[Children] = {
		scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 2 },
		scope:New "UITextSizeConstraint" { MaxTextSize = 18, MinTextSize = 14 },
	},
}

local reelWindow = scope:New "Frame" {
	Name = "ReelWindow", Parent = stage, Position = UDim2.fromOffset(0, MODS_Y), Size = UDim2.new(1, 0, 0, MODS_H),
	ZIndex = 4, ClipsDescendants = true, Visible = reelShown,
}
PanelChrome.insetTray(reelWindow, { top = Color3.fromRGB(78, 88, 132), bottom = Color3.fromRGB(44, 50, 84), radius = 22, zIndex = 4, strokeThickness = 4 })
strip.Parent = reelWindow
pointer(0, 45).Parent = reelWindow
pointer(12 + CARD_H + 4, 45).Parent = reelWindow
reveal.Parent = reelWindow

-- Button row: Odds, the big Reforge button, Animation toggle.
local ODDS_W = L(function(l) return l.wide and 108 or 92 end)
local ANIM_W = L(function(l) return l.wide and 118 or 100 end)
local strikeRow = scope:New "Frame" {
	Name = "StrikeRow", Parent = stage, BackgroundTransparency = 1, ZIndex = 5,
	Position = UDim2.fromOffset(0, STRIKE_Y), Size = UDim2.new(1, 0, 0, STRIKE_H),
	[Children] = {
		scope:New "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder,
		},
	},
}

local oddsHolder, oddsBtn, oddsLabel = chunky({
	name = "OddsButton", order = 1, text = "ODDS", textSize = 18, color = Color3.fromRGB(110, 196, 255), colorDark = Color3.fromRGB(30, 110, 220),
	size = scope:Computed(function(use) return UDim2.fromOffset(use(ODDS_W), STRIKE_H) end),
})
oddsLabel.Position = UDim2.new(0, 6, 1, -32)
oddsLabel.Size = UDim2.new(1, -12, 0, 24)
PanelChrome.display(oddsBtn, { name = "Glyph", text = "?", size = 40, stroke = 3.5, pos = UDim2.fromOffset(0, 2), size2 = UDim2.new(1, 0, 0, 44), zIndex = 9 })
oddsBtn.Activated:Connect(function() setOddsPopupVisible(not peek(oddsPopupVisible)) end)
oddsHolder.Parent = strikeRow

local strikeHolder, strikeBtn, strikeLabel, strikeGrad, strikeLip = chunky({
	name = "StrikeButton", order = 2, text = "REFORGE", textSize = 32, color = BRIGHT.Green, colorDark = BRIGHT.GreenDark,
	size = scope:Computed(function(use)
		return UDim2.fromOffset(use(layout).stageW - use(ODDS_W) - use(ANIM_W) - 24, STRIKE_H)
	end),
})
strikeBtn.Activated:Connect(strike)
local showCostC = scope:Computed(function(use) return use(selectedC) ~= nil and not use(spinningValue) end)
scope:Hydrate(strikeLabel) {
	Text = strikeLabelC,
	Position = scope:Computed(function(use) return use(showCostC) and UDim2.fromOffset(8, 4) or UDim2.fromOffset(8, 10) end),
	Size = scope:Computed(function(use) return use(showCostC) and UDim2.new(1, -16, 0, 38) or UDim2.new(1, -16, 1, -26) end),
}
scope:Observer(strikeReadyC):onBind(function()
	local ready = peek(strikeReadyC)
	strikeGrad.Color = ready and seq(BRIGHT.Green, BRIGHT.GreenDark) or seq(BRIGHT.Grey, BRIGHT.GreyDark)
	strikeLip.BackgroundColor3 = ready and Color3.fromRGB(30, 128, 40) or Color3.fromRGB(124, 132, 150)
end)
do
	local strikeCost = scope:New "Frame" {
		Name = "Cost", Parent = strikeBtn, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.new(1, -16, 0, 28), ZIndex = 10, Visible = showCostC,
		[Children] = {
			scope:New "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
			},
		},
	}
	local strikeCoin = image(strikeCost, COIN_ICON, 30, { LayoutOrder = 1, ZIndex = 10 })
	scope:Hydrate(strikeCoin) { Visible = scope:Computed(function(use) return use(costC) > 0 end) }
	local strikeCostLabel = PanelChrome.display(strikeCost, { name = "CostAmount", text = "", size = 26, stroke = 2.5, zIndex = 10 })
	strikeCostLabel.LayoutOrder = 2
	strikeCostLabel.Size = UDim2.fromScale(0, 1)
	strikeCostLabel.AutomaticSize = Enum.AutomaticSize.X
	scope:Hydrate(strikeCostLabel) {
		Text = costTextC,
		TextColor3 = scope:Computed(function(use)
			if use(costC) > 0 and not use(affordC) then return Color3.fromRGB(255, 150, 150) end
			return use(costC) == 0 and Color3.fromRGB(200, 255, 170) or Color3.fromRGB(255, 230, 110)
		end),
	}
	strikeHolder.Parent = strikeRow
end

do
	local animHolder, animBtn, animLabel = chunky({
		name = "AnimationToggle", order = 3, text = "ANIM", textSize = 18,
		color = Color3.fromRGB(206, 150, 255), colorDark = Color3.fromRGB(130, 60, 220),
		size = scope:Computed(function(use) return UDim2.fromOffset(use(ANIM_W), STRIKE_H) end),
	})
	animLabel.Position = UDim2.new(0, 6, 1, -32)
	animLabel.Size = UDim2.new(1, -12, 0, 24)
	local animState = PanelChrome.display(animBtn, { name = "State", text = "ON", size = 32, stroke = 3, pos = UDim2.fromOffset(4, 6), size2 = UDim2.new(1, -8, 0, 38), zIndex = 9 })
	scope:Hydrate(animState) {
		Text = scope:Computed(function(use) return use(skipAnimationValue) and "SKIP" or "ON" end),
		TextColor3 = scope:Computed(function(use) return use(skipAnimationValue) and Color3.fromRGB(255, 226, 110) or Color3.fromRGB(190, 255, 160) end),
	}
	animBtn.Activated:Connect(function() skipAnimationValue:set(not peek(skipAnimationValue)) end)
	animHolder.Parent = strikeRow
end

-- ── Window, overlay and the odds popup ───────────────────────────────────────
local window = scope:New "Frame" {
	Name = "ReforgeWindow", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 2,
	Position = L(function(l) return UDim2.new(0.5, math.floor(11 * l.s), 0.5, math.floor(14 * l.s)) end),
	Size = L(function(l) return UDim2.fromOffset(l.W, l.H) end),
	[Children] = {
		panelScale,
		scope:New "Frame" {
			Name = "DropShadow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 12),
			Size = UDim2.new(1, 12, 1, 12), BackgroundColor3 = Color3.fromRGB(8, 8, 18), BackgroundTransparency = 0.4, ZIndex = 2,
			[Children] = { scope:New "UICorner" { CornerRadius = UDim.new(0, 28) } },
		},
		modal,
	},
}

local popup = scope:New "Frame" {
	Name = "OddsPopup", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(500, 380), BackgroundColor3 = WHITE, ZIndex = 30, Visible = oddsPopupVisible, Active = true,
	[Children] = {
		popupScale,
		scope:New "UICorner" { CornerRadius = UDim.new(0, 22) },
		scope:New "UIGradient" { Rotation = 90, Color = seq(BRIGHT.Panel, BRIGHT.PanelBottom) },
		scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 4.5 },
		scope:New "Frame" {
			Name = "Tiers", BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 44), Size = UDim2.new(1, -40, 0, 104), ZIndex = 31,
			[Children] = {
				scope:New "UIListLayout" { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder },
			},
		},
		scope:New "TextLabel" {
			Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 164), Size = UDim2.new(1, -44, 1, -226),
			TextSize = 17, TextColor3 = BRIGHT.Ink, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, ZIndex = 31, Text = oddsPopupTextC,
		},
		scope:New "TextLabel" {
			Name = "Record", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 22, 1, -16),
			Size = UDim2.new(1, -44, 0, 34), TextScaled = true, RichText = true, TextColor3 = BRIGHT.Ink,
			TextXAlignment = Enum.TextXAlignment.Left, Font = DISPLAY, ZIndex = 31, Text = statsLineC,
			[Children] = { scope:New "UITextSizeConstraint" { MaxTextSize = 22, MinTextSize = 14 } },
		},
	},
}
for tier = 1, WeaponModifiers.TIER_COUNT do
	tierTile(tier, UDim2.new(1 / WeaponModifiers.TIER_COUNT, -7, 1, 0)).Parent = popup:FindFirstChild("Tiers")
end
do
	local popupTitle = PanelChrome.display(popup, {
		name = "Title", text = "Reforge Odds", size = 38, stroke = 3.5, xAlign = Enum.TextXAlignment.Left,
		anchor = Vector2.new(0, 0.5), pos = UDim2.fromOffset(22, -2), size2 = UDim2.new(0.7, 0, 0, 48), zIndex = 32,
	})
	local popupClose = PanelChrome.chunkyButton(popup, {
		name = "CloseButton", text = "X", color = BRIGHT.Red, colorDark = BRIGHT.RedDark,
		size = UDim2.fromOffset(CLOSE, CLOSE), anchor = Vector2.new(0.5, 0.5), pos = UDim2.new(1, -22, 0, 2),
		textSize = 36, zIndex = 33, radius = 14, strokeThickness = 3.5,
	})
	popupClose.Activated:Connect(function() setOddsPopupVisible(false) end)
end

local overlay = scope:New "TextButton" {
	Name = "Overlay",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.5,
	Text = "",
	AutoButtonColor = false,
	Visible = overlayVisible,
	Parent = screenGui,
	[OnEvent "Activated"] = close,
	[Children] = {
		window,
		scope:New "TextButton" {
			Name = "PopupBackdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35,
			Text = "", AutoButtonColor = false, ZIndex = 29,
			Visible = oddsPopupVisible,
			[OnEvent "Activated"] = function() setOddsPopupVisible(false) end,
		},
		popup,
	},
}

-- The window grows in while the backdrop dims, then the sword tray's tiles land row by row.
reforgeMotion = {
	frame = window, scale = panelScale, dim = overlay, dimTo = 0.5,
	tiles = function() return { trayScroll } end,
}

-- ── Responsive layout: side by side when it fits, stacked on phones ──────────
local function applyLayout(viewport: Vector2)
	local availX, availY = viewport.X - 8, viewport.Y - 100
	local wideW = X0 + TRAY_W_WIDE + MID + STAGE_W_WIDE + EDGE
	local wideH = HEADER_H + STAGE_TOP + STAGE_H + EDGE
	local sWide = math.min(1, availX / (wideW + 26), availY / wideH)
	local tallW = X0 + STAGE_W_TALL + EDGE
	local tallBase = HEADER_H + STAGE_TOP + STAGE_H + 14 + SEC_H + EDGE
	local rowH = TILE + VGAP
	local sTall = math.min(1, availX / (tallW + 22))
	local tallH = math.clamp(availY / sTall, tallBase + TOP_PAD + 2 * rowH + 16, tallBase + TOP_PAD + 3.4 * rowH)
	sTall = math.min(sTall, availY / tallH)
	if sWide >= sTall * 0.92 then
		layout:set({ wide = true, s = math.max(sWide, 0.3), W = wideW, H = wideH, stageW = STAGE_W_WIDE, trayW = TRAY_W_WIDE, trayH = TRAY_H_WIDE })
	else
		layout:set({
			wide = false, s = math.max(sTall, 0.3), W = tallW, H = math.floor(tallH), stageW = STAGE_W_TALL, trayW = STAGE_W_TALL,
			trayH = math.floor(tallH) - (tallBase - EDGE),
		})
	end
end
scope:Observer(layout):onBind(function()
	local s = peek(layout).s
	panelScale.Scale = s
	popupScale.Scale = math.min(s * 1.1, 1)
end)
PanelChrome.onViewport(applyLayout)

-- Rays behind the hero turn slowly while the window is open.
RunService.RenderStepped:Connect(function(dt)
	if peek(overlayVisible) then
		rays.Rotation = (rays.Rotation + dt * 12) % 360
	end
end)

-- ── The reel (kept imperative -- see file header) ───────────────────────────
local function makeCard(index, label, sub, color, big)
	local card = Instance.new("Frame")
	card.Name = "ReelCard"
	card.Position = UDim2.fromOffset((index - 1) * (CARD_W + CARD_GAP), 0)
	card.Size = UDim2.fromOffset(CARD_W, CARD_H)
	card.BackgroundColor3 = WHITE
	card.BorderSizePixel = 0
	card.ZIndex = 6
	card.Parent = strip
	corner(card, 16)
	PanelChrome.gradient(card, color:Lerp(WHITE, 0.5), color)
	PanelChrome.stroke(card, big and BRIGHT.Gold or BRIGHT.Outline, big and 5 or 3)
	local shine = Instance.new("Frame")
	shine.BackgroundColor3 = WHITE
	shine.BackgroundTransparency = 0.6
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromOffset(6, 6)
	shine.Size = UDim2.new(1, -12, 0.24, 0)
	shine.ZIndex = 6
	shine.Parent = card
	corner(shine, 10)
	local title = PanelChrome.display(card, {
		text = label, size = big and 22 or 20, stroke = 2.5, pos = UDim2.fromOffset(6, 8), size2 = UDim2.new(1, -12, 0, 62),
		scaled = true, minSize = 10, zIndex = 8,
	})
	title.TextWrapped = true
	local subLabel = PanelChrome.display(card, {
		text = sub, size = 15, stroke = 2, pos = UDim2.new(0, 6, 1, -40), size2 = UDim2.new(1, -12, 0, 34),
		scaled = true, minSize = 8, zIndex = 8,
	})
	subLabel.TextWrapped = true
	return card
end

local function randomFillerCard(index, rarity)
	local odds = WeaponModifiers.TierOdds(rarity, 0)
	local pick, tier = math.random(), 1
	for t = 1, WeaponModifiers.TIER_COUNT do
		pick -= odds[t]
		if pick <= 0 then tier = t break end
	end
	local categories = { "Damage", "CritChance", "Range", "Knockback" }
	local category = categories[math.random(#categories)]
	local entry = WeaponModifiers.Categories[category].Tiers[tier]
	makeCard(index, entry.name, entry.desc, TIER_COLORS[tier])
end

local REVEAL_REST = Color3.fromRGB(26, 28, 48)
local REVEAL_HOLD = 3.5 -- seconds the result stays up before the lock grid returns
local spinToken = 0
local function spin(result)
	spinToken += 1
	local token = spinToken
	spinningValue:set(true)
	reelShown:set(true)
	reveal.Visible = false
	pointerVisible:set(true)
	for _, c in ipairs(strip:GetChildren()) do c:Destroy() end
	for i = 1, REEL_CARDS do
		if i == LAND_INDEX then
			local names = {}
			for _, m in ipairs(result.mods) do table.insert(names, m.name) end
			if result.blessed then table.insert(names, 1, "Blessed") end
			local t = RARITY_TILE[result.rarity]
			makeCard(i, #names > 0 and table.concat(names, "\n") or "Plain", result.rarity, t and t.bottom or TIER_COLORS[1], true)
		else
			randomFillerCard(i, result.rarity)
		end
	end
	local windowW = peek(layout).stageW
	local landX = (LAND_INDEX - 1) * (CARD_W + CARD_GAP) + CARD_W / 2 + math.random(-40, 40)
	strip.Position = UDim2.fromOffset(windowW / 2 - CARD_W / 2, 12)
	local tween = TweenService:Create(strip, TweenInfo.new(peek(skipAnimationValue) and 0.35 or SPIN_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(windowW / 2 - landX, 12) })
	local lastIndex = 0
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local passing = math.floor((windowW / 2 - strip.Position.X.Offset) / (CARD_W + CARD_GAP))
		if passing ~= lastIndex then
			lastIndex = passing
			AudioManager.PlaySFX("ui_click", screenGui)
		end
	end)
	tween:Play()
	tween.Completed:Wait()
	conn:Disconnect()
	AudioManager.PlaySFX(result.after >= result.before and "quest_complete" or "enemy_hit", screenGui)

	reveal.Visible = true
	revealName.Text = result.personalBest and "NEW PERSONAL BEST!" or string.upper(result.rarity or "")
	revealName.TextColor3 = result.personalBest and Color3.fromRGB(255, 226, 110) or ((RARITY_TILE[result.rarity] or RARITY_TILE.Common).top)
	local notes = {}
	if result.blessed then table.insert(notes, "Blessed slot") end
	if result.pityApplied then table.insert(notes, "pity floor applied") end
	if result.kept then table.insert(notes, "kept " .. tostring(result.kept)) end
	if #result.mods == 0 then table.insert(notes, "no modifiers this time") end
	revealMods.Text = table.concat(notes, "  ·  ")
	local delta = result.after - result.before
	revealRating.Text = string.format("%s -> %s  (%s%s)  %s", SwordValue.short(result.before), SwordValue.short(result.after),
		delta >= 0 and "+" or "-", SwordValue.short(math.abs(delta)), result.free and "FREE" or ("-" .. SwordValue.short(result.cost) .. " gold"))
	revealRating.TextColor3 = delta > 0 and Color3.fromRGB(150, 255, 120) or (delta < 0 and Color3.fromRGB(255, 130, 130) or WHITE)
	reveal.BackgroundColor3 = delta > 0 and Color3.fromRGB(40, 150, 70) or (delta < 0 and Color3.fromRGB(170, 40, 50) or REVEAL_REST)
	TweenService:Create(reveal, TweenInfo.new(1.2), { BackgroundColor3 = REVEAL_REST }):Play()
	spinningValue:set(false)
	task.delay(REVEAL_HOLD, function()
		if spinToken == token and not peek(spinningValue) then reelShown:set(false) end
	end)
end

-- ── Wiring ───────────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape and peek(overlayVisible) then
		if peek(oddsPopupVisible) then setOddsPopupVisible(false) else close() end
	end
end)

local function applyState(stateRows, goldVal, highlight, disclosure)
	rowsValue:set(stateRows)
	goldValue:set(goldVal)
	if disclosure then oddsInfoValue:set(disclosure) end
	if highlight then
		if peek(selectedToolName) ~= highlight then lockedSet:set({}) end
		selectedToolName:set(highlight)
	elseif peek(selectedToolName) then
		local stillExists = false
		for _, info in ipairs(stateRows) do
			if info.toolName == peek(selectedToolName) then stillExists = true break end
		end
		if not stillExists then selectedToolName:set(nil) end
	end
end

local pendingState = nil
REFORGE.OnClientEvent:Connect(function(kind, a, b, c, d)
	if kind == "Open" then
		overlayVisible:set(true)
		reveal.Visible = false
		reelShown:set(false)
		pointerVisible:set(false)
		setOddsPopupVisible(false)
		for _, card in ipairs(strip:GetChildren()) do card:Destroy() end
		PanelChrome.openMotion(reforgeMotion)
	elseif kind == "Result" then
		pendingState = nil
		task.spawn(function()
			spin(a)
			if pendingState then applyState(pendingState[1], pendingState[2], pendingState[3], pendingState[4]) pendingState = nil end
		end)
	elseif kind == "State" then
		if peek(spinningValue) then
			pendingState = { a, b, c, d } -- apply after the reel lands so the list does not jump mid-spin
		else
			applyState(a, b, c, d)
		end
	end
end)

-- Showcase: open the anvil exactly as the HUD's Reforge button does, then tap the top sword
-- as a player would (a local pick only). Only ever "Open": never "Reroll", which spends gold.
local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))
GuiShowcase.register("Reforge", function()
	REFORGE:FireServer("Open")
	local deadline = os.clock() + 20
	while not (peek(overlayVisible) and #peek(rowsValue) > 0) and os.clock() < deadline do
		task.wait(0.25)
	end
	task.wait(0.6)
	local rows = peek(rowsValue)
	if peek(overlayVisible) and rows[1] and not peek(selectedToolName) then
		selectTool(rows[1].toolName)
	end
end)

print("[ReforgeGuiFusion] Fusion-based Reforge panel enabled")
