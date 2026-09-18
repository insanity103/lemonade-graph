--// SwordDropToast (client) with Prefix & Stat Modifiers display and Auto-Sell toasts
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local REMOTES = ReplicatedStorage:WaitForChild("RemoteEvents")
local DROP_EVENT = REMOTES:WaitForChild("SwordDrop")
local AUTO_SELL_NOTICE = REMOTES:WaitForChild("AutoSellNotice")
local SWORD_LOST_EVENT = REMOTES:WaitForChild("SwordLostOnDeath")

local RARITY_COLOR = {
	Common = Color3.fromRGB(210, 210, 210),
	Uncommon = Color3.fromRGB(90, 200, 90),
	Rare = Color3.fromRGB(90, 150, 255),
	Epic = Color3.fromRGB(190, 110, 245),
	Legendary = Color3.fromRGB(255, 175, 50),
}

local gui = Instance.new("ScreenGui")
gui.Name = "SwordDropToast"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local holder = Instance.new("Frame")
holder.AnchorPoint = Vector2.new(1, 0.5)
holder.Position = UDim2.new(1, -16, 0.5, 0)
holder.Size = UDim2.fromOffset(280, 420)
holder.BackgroundTransparency = 1
holder.Parent = gui

local layout = Instance.new("UIListLayout", holder)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder

-- ═════════════════════════════════════════════════════════════════════════════
--  Sword drop reveal: a bright loot card that pops in at the top of the screen.
--
--  Timeline (ms from the drop): a white flash hits at 0 (Epic/Legendary only) and fades out by
--  280. The card grows from 0.7 to a 1.07 peak by 130 with a Back-out ease, rising 12 px and
--  fading up over the first 80, then settles to 1.0 by 220. The sword pops out of its tile from
--  50, a rarity ring bursts out behind it from 80 to 460 with sparkles flying off it, and the
--  rarity border flashes white and back from 100 to 250. The name punches in from 1.18x at 60,
--  then the damage line lands at 150 and each modifier 40 ms after the last. One bright sweep
--  crosses the card, its border and the name from 180 to 380. The card holds a few seconds
--  (longer for rarer drops) and lifts away. It never takes input, so it never blocks play; a
--  new drop sends the old card away at once.
-- ═════════════════════════════════════════════════════════════════════════════
local RunService = game:GetService("RunService")
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))
local BRIGHT = PanelChrome.BRIGHT
local WHITE = Color3.new(1, 1, 1)

local REVEAL = { -- [TUNING] design-space pixels and seconds
	Width = 500, Tile = 136, Pad = 16, ModRow = 24,
	FromScale = 0.7, Peak = 1.07, PeakAt = 0.13, SettleBy = 0.22, Rise = 12, RiseTime = 0.18, FadeTime = 0.08,
	NameAt = 0.06, NameFrom = 1.18, NameTime = 0.14, SwordAt = 0.05, SwordTime = 0.16,
	StatAt = 0.15, StatStep = 0.04, StatTime = 0.12,
	BorderFlashAt = 0.10, BorderFlashPeak = 0.16, BorderFlashEnd = 0.25,
	SweepAt = 0.18, SweepEnd = 0.38, RingAt = 0.08, RingEnd = 0.46, SparkAt = 0.10, SparkLife = 0.36,
	FlashHold = 0.033, FlashEnd = 0.28, ExitTime = 0.18, ExitFast = 0.12,
}
-- Rarer drops get a bigger card, a longer hold, a screen flash and more sparkles.
local REVEAL_TIER = {
	Common = { scale = 0.86, hold = 2.4, sparks = 0 },
	Uncommon = { scale = 0.92, hold = 2.6, sparks = 4 },
	Rare = { scale = 1.0, hold = 3.0, sparks = 6 },
	Epic = { scale = 1.18, hold = 3.4, sparks = 8, flash = 0.6 },
	Legendary = { scale = 1.34, hold = 3.8, sparks = 10, flash = 0.42 },
}
-- The name's face colour: white for common drops, the rarity's bright colour otherwise.
local NAME_COLOR = {
	Common = WHITE, Uncommon = Color3.fromRGB(150, 245, 120), Rare = Color3.fromRGB(120, 200, 255),
	Epic = Color3.fromRGB(222, 150, 255), Legendary = Color3.fromRGB(255, 214, 60),
}

local revealGui = Instance.new("ScreenGui")
revealGui.Name = "SwordDropReveal"
revealGui.ResetOnSpawn = false
revealGui.IgnoreGuiInset = true
revealGui.DisplayOrder = 16 -- above the HUD and combat streak, below modal panels (20+)
revealGui.Parent = player:WaitForChild("PlayerGui")

local screenFlash = Instance.new("Frame")
screenFlash.Name = "Flash"
screenFlash.Size = UDim2.fromScale(1, 1)
screenFlash.BackgroundColor3 = WHITE
screenFlash.BackgroundTransparency = 1
screenFlash.BorderSizePixel = 0
screenFlash.Active = false
screenFlash.Parent = revealGui

-- Fits the card to the screen: full size on desktop, shrinking to leave a 16 px gutter on phones.
local viewportSize = Vector2.new(1280, 720)
local liveStages = {}
local function fitFor(tierScale)
	return math.min(tierScale * math.min(1, viewportSize.Y / 560), (viewportSize.X - 32) / REVEAL.Width)
end
PanelChrome.onViewport(function(vp)
	viewportSize = vp
	for stage, tierScale in pairs(liveStages) do
		local s = stage:FindFirstChild("Fit")
		if s then s.Scale = fitFor(tierScale) end
	end
end)

local function ease(a, style, dir)
	return TweenService:GetValue(math.clamp(a, 0, 1), style, dir)
end
local function quadOut(a) return ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
local function quadIn(a) return ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
local function backOut(a) return ease(a, Enum.EasingStyle.Back, Enum.EasingDirection.Out) end
local function cubicOut(a) return ease(a, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out) end
local function sineInOut(a) return ease(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) end
local function lerp(a, b, k) return a + (b - a) * k end

-- Fade groups: every transparency under a root, remembered at rest, driven 0 (gone) .. 1 (rest).
local FADE_PROPS = {
	Frame = { "BackgroundTransparency" },
	TextLabel = { "BackgroundTransparency", "TextTransparency" },
	ViewportFrame = { "BackgroundTransparency", "ImageTransparency" },
	UIStroke = { "Transparency" },
}
local function fadeGroup(root, skip)
	local list = {}
	local function add(inst)
		local props = FADE_PROPS[inst.ClassName]
		if not props then return end
		for _, p in ipairs(props) do
			local rest = (inst :: any)[p]
			if rest < 0.999 then table.insert(list, { inst, p, rest }) end
		end
	end
	local function walk(inst)
		if skip and skip[inst] then return end
		add(inst)
		for _, c in ipairs(inst:GetChildren()) do walk(c) end
	end
	walk(root)
	return list
end
local function setFade(list, v)
	for _, e in ipairs(list) do
		(e[1] :: any)[e[2]] = 1 - (1 - e[3]) * v
	end
end

-- A band gradient: the base colour with one white stripe, parked off the edge until the sweep.
local function sweepGradient(parent, base, rotation)
	local g = Instance.new("UIGradient")
	g.Rotation = rotation or 20
	g.Offset = Vector2.new(-1, 0)
	g.Parent = parent
	local function paint(color)
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(0.4, color),
			ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(0.6, color), ColorSequenceKeypoint.new(1, color),
		})
	end
	paint(base)
	return g, paint
end

-- A client-side stand-in sword for the tile when the dropped Tool is not on this client.
local function standInSword(rarity)
	local t = PanelChrome.RARITY_TILE[rarity] or PanelChrome.RARITY_TILE.Common
	local tool = Instance.new("Tool")
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.44, 0.44, 1.0)
	handle.Color = Color3.fromRGB(92, 66, 50)
	handle.Parent = tool
	local function add(name, size, c0, color, material, shape, class)
		local p = Instance.new(class or "Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		if shape then (p :: any).Shape = shape end
		p.Parent = tool
		local w = Instance.new("Weld")
		w.Part0, w.Part1, w.C0 = handle, p, c0
		w.Parent = handle
	end
	local len, w, th = 2.5, 1.1, 0.26
	local bladeZ = -0.8 - len / 2
	local steel = Color3.fromRGB(216, 222, 234)
	add("Pommel", Vector3.new(0.66, 0.66, 0.66), CFrame.new(0, 0, 0.68), t.bottom, Enum.Material.Neon, Enum.PartType.Ball)
	add("Guard", Vector3.new(1.95, 0.4, 0.44), CFrame.new(0, 0, -0.6), Color3.fromRGB(226, 160, 36), Enum.Material.Metal)
	add("GuardGem", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0, -0.6), t.bottom, Enum.Material.Neon, Enum.PartType.Ball)
	add("Blade", Vector3.new(w, th, len), CFrame.new(0, 0, bladeZ), steel, Enum.Material.Metal)
	add("Fuller", Vector3.new(w * 0.3, th + 0.04, len * 0.82), CFrame.new(0, 0, bladeZ + len * 0.06), t.bottom, Enum.Material.Neon)
	local tipLen = w * 0.75
	for _, side in ipairs({ 1, -1 }) do
		add("Tip", Vector3.new(th, w / 2, tipLen), CFrame.new(side * w / 4, 0, bladeZ - len / 2 - tipLen / 2)
			* CFrame.Angles(0, 0, side == 1 and -math.pi / 2 or math.pi / 2), steel, Enum.Material.Metal, nil, "WedgePart")
	end
	return tool
end

local function renderDroppedSword(viewport, rarity, fullName)
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		local found = container and fullName and container:FindFirstChild(fullName)
		if found and found:IsA("Tool") and PanelChrome.renderTool(viewport, found, { tiltDeg = 45, margin = 0.92 }) then
			return
		end
	end
	local tool = standInSword(rarity)
	PanelChrome.renderTool(viewport, tool, { tiltDeg = 45, margin = 0.92 })
	tool:Destroy()
end

-- A four-point sparkle: two crossed white bars, rotated to a star.
local function sparkle(parent, size, z)
	local s = Instance.new("Frame")
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Size = UDim2.fromOffset(size, size)
	s.BackgroundTransparency = 1
	s.ZIndex = z
	s.Parent = parent
	for _, dims in ipairs({ { 0.22, 1 }, { 1, 0.22 } }) do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromScale(dims[1], dims[2])
		bar.BackgroundColor3 = WHITE
		bar.BorderSizePixel = 0
		bar.ZIndex = z
		bar.Parent = s
		PanelChrome.corner(bar, 99)
	end
	local sc = Instance.new("UIScale")
	sc.Scale = 0
	sc.Parent = s
	return s, sc
end

local current -- the reveal on screen, if any: { exit = function(fast) }

local function revealDrop(rarityName, mult, fullName, mods, gotExtraSlot)
	mods = mods or {}
	local R = REVEAL
	local tier = REVEAL_TIER[rarityName] or REVEAL_TIER.Common
	local rt = PanelChrome.RARITY_TILE[rarityName] or PanelChrome.RARITY_TILE.Common
	local rarityColor = RARITY_COLOR[rarityName] or WHITE
	if current then current.exit(true) end
	screenFlash.BackgroundTransparency = 1

	local W, T, P = R.Width, R.Tile, R.Pad
	local H = math.max(T + 2 * P + 8, 128 + #mods * R.ModRow + P)
	local colX = P + T + 18
	local colW = W - colX - P

	-- Stage: fixed rest position (never moved during the reveal) and the screen-fit scale.
	local stage = Instance.new("Frame")
	stage.Name = "Reveal"
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.3)
	stage.Size = UDim2.fromOffset(W, H)
	stage.BackgroundTransparency = 1
	stage.Active = false
	local fit = Instance.new("UIScale")
	fit.Name = "Fit"
	fit.Scale = fitFor(tier.scale)
	fit.Parent = stage

	-- The card: light panel, heavy dark outline, a rarity border just inside it.
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = WHITE
	card.BorderSizePixel = 0
	card.ZIndex = 2
	card.Parent = stage
	PanelChrome.corner(card, 22)
	PanelChrome.gradient(card, BRIGHT.Panel, BRIGHT.PanelBottom)
	PanelChrome.stroke(card, BRIGHT.Outline, 4.5)
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card

	local border = Instance.new("Frame")
	border.Name = "RarityBorder"
	border.Position = UDim2.fromOffset(5, 5)
	border.Size = UDim2.new(1, -10, 1, -10)
	border.BackgroundTransparency = 1
	border.ZIndex = 2
	border.Parent = card
	PanelChrome.corner(border, 17)
	local borderStroke = PanelChrome.stroke(border, WHITE, 4)
	local borderSweep, paintBorder = sweepGradient(borderStroke, rt.bottom, 20)

	-- The sword tile.
	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.AnchorPoint = Vector2.new(0, 0.5)
	tile.Position = UDim2.new(0, P, 0.5, 0)
	tile.Size = UDim2.fromOffset(T, T)
	tile.ZIndex = 3
	tile.Parent = card
	PanelChrome.corner(tile, 18)
	PanelChrome.lootTile(tile, rarityName, { radius = 18, zIndex = 3 })
	local view = Instance.new("ViewportFrame")
	view.Name = "Sword"
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Position = UDim2.fromScale(0.5, 0.5)
	view.Size = UDim2.new(1, -6, 1, -6)
	view.BackgroundTransparency = 1
	view.ZIndex = 4
	view.Parent = tile
	local viewScale = Instance.new("UIScale")
	viewScale.Parent = view
	renderDroppedSword(view, rarityName, fullName)

	-- Title over the card's top-left edge.
	local header = PanelChrome.display(card, {
		name = "Header", text = "NEW SWORD!", size = 30, stroke = 3.5, xAlign = Enum.TextXAlignment.Left,
		anchor = Vector2.new(0, 0.5), pos = UDim2.fromOffset(18, 2), size2 = UDim2.fromOffset(W - 90, 38), zIndex = 7,
	})
	header.Rotation = -3

	-- Rarity pill (and a Blessed pill for a bonus slot).
	local pills = Instance.new("Frame")
	pills.Name = "Pills"
	pills.Position = UDim2.fromOffset(colX, 26)
	pills.Size = UDim2.fromOffset(colW, 26)
	pills.BackgroundTransparency = 1
	pills.ZIndex = 4
	pills.Parent = card
	local pl = Instance.new("UIListLayout")
	pl.FillDirection = Enum.FillDirection.Horizontal
	pl.Padding = UDim.new(0, 6)
	pl.SortOrder = Enum.SortOrder.LayoutOrder
	pl.Parent = pills
	local function pill(text, top, bottom, order)
		local f = Instance.new("Frame")
		f.Size = UDim2.fromOffset(0, 26)
		f.AutomaticSize = Enum.AutomaticSize.X
		f.BackgroundColor3 = WHITE
		f.LayoutOrder = order
		f.ZIndex = 4
		f.Parent = pills
		PanelChrome.corner(f, 13)
		PanelChrome.gradient(f, top, bottom)
		PanelChrome.stroke(f, BRIGHT.Outline, 2.5)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = f
		local l = PanelChrome.display(f, { text = text, size = 18, stroke = 2, zIndex = 5 })
		l.Size = UDim2.fromScale(0, 1)
		l.AutomaticSize = Enum.AutomaticSize.X
	end
	pill(string.upper(rarityName or "Common"), rt.top, rt.bottom, 1)
	if gotExtraSlot then
		pill("BLESSED +1 SLOT", Color3.fromRGB(255, 246, 170), BRIGHT.GoldDark, 2)
	end

	-- The name: the rarity's bright colour under a heavy outline, carrying the sweep.
	local nameLabel = PanelChrome.display(card, {
		name = "ItemName", text = fullName or (tostring(rarityName) .. " Sword"), size = 36, stroke = 3.5,
		xAlign = Enum.TextXAlignment.Left, anchor = Vector2.new(0, 0.5),
		pos = UDim2.fromOffset(colX, 78), size2 = UDim2.fromOffset(colW, 42), zIndex = 6, scaled = true, minSize = 18,
	})
	nameLabel.TextColor3 = WHITE
	local nameSweep = sweepGradient(nameLabel, NAME_COLOR[rarityName] or WHITE, 20)
	local nameScale = Instance.new("UIScale")
	nameScale.Parent = nameLabel

	-- Stat lines: the damage multiplier, then one line per modifier.
	local stats = {}
	local multLabel = PanelChrome.display(card, {
		name = "Mult", text = ("x%.2f Damage"):format(mult or 1), size = 24, stroke = 2.5,
		xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(colX, 102), size2 = UDim2.fromOffset(colW, 28), zIndex = 5,
	})
	table.insert(stats, multLabel)
	for i, mod in ipairs(mods) do
		local l = Instance.new("TextLabel")
		l.Name = "Mod" .. i
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(colX + 2, 132 + (i - 1) * R.ModRow)
		l.Size = UDim2.fromOffset(colW - 2, R.ModRow - 2)
		l.Font = Enum.Font.GothamBold
		l.TextSize = 18
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.RichText = true
		l.TextColor3 = BRIGHT.Ink
		l.Text = string.format('<font color="#2EA434">+ %s</font>  %s', tostring(mod.name), tostring(mod.desc or ""))
		l.ZIndex = 5
		l.Parent = card
		table.insert(stats, l)
	end
	local statRest = {}
	for i, l in ipairs(stats) do statRest[i] = l.Position end

	-- One bright band across the whole card face.
	local sheen = Instance.new("Frame")
	sheen.Name = "Sheen"
	sheen.Size = UDim2.fromScale(1, 1)
	sheen.BackgroundColor3 = WHITE
	sheen.BorderSizePixel = 0
	sheen.ZIndex = 8
	sheen.Parent = card
	PanelChrome.corner(sheen, 22)
	local sheenGrad = Instance.new("UIGradient")
	sheenGrad.Rotation = 20
	sheenGrad.Offset = Vector2.new(-1, 0)
	sheenGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.38, 1), NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(0.62, 1), NumberSequenceKeypoint.new(1, 1),
	})
	sheenGrad.Parent = sheen

	-- The burst behind the sword: a rarity ring that expands and fades, and sparkles.
	local tileCentre = UDim2.fromOffset(P + T / 2, H / 2)
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = tileCentre
	ring.BackgroundColor3 = rarityColor
	ring.BackgroundTransparency = 1
	ring.ZIndex = 9
	ring.Parent = stage
	PanelChrome.corner(ring, 999)
	local ringStroke = PanelChrome.stroke(ring, rt.top, 6)
	local sparks = {}
	for i = 1, tier.sparks do
		local angle = (i / tier.sparks) * math.pi * 2 + (i % 2) * 0.3
		local size = (i % 3 == 0) and 30 or 20
		local s, sc = sparkle(stage, size, 10)
		s.Position = tileCentre
		table.insert(sparks, {
			frame = s, scale = sc, delay = R.SparkAt + (i - 1) * 0.012,
			dir = Vector2.new(math.cos(angle), math.sin(angle)), dist = 80 + (i % 3) * 22, spin = (i % 2 == 0) and 90 or -90,
		})
	end

	-- Fade groups. The body is everything that isn't staged on its own beat.
	local skip = { [nameLabel] = true, [view] = true, [sheen] = true }
	for _, l in ipairs(stats) do skip[l] = true end
	local bodyFade = fadeGroup(card, skip)
	local nameFade = fadeGroup(nameLabel)
	local viewFade = fadeGroup(view)
	local statFades = {}
	for i, l in ipairs(stats) do statFades[i] = fadeGroup(l) end

	stage.Parent = revealGui
	liveStages[stage] = tier.scale

	local t0 = os.clock()
	local exitAt = t0 + R.SettleBy + tier.hold
	local exitTime = R.ExitTime
	local conn
	local me = {}
	function me.exit(fast)
		local now = os.clock()
		if now < exitAt then
			exitAt = now
			exitTime = fast and R.ExitFast or R.ExitTime
		end
	end
	current = me

	local function step()
		local now = os.clock()
		local t = now - t0
		local out = if now >= exitAt then math.clamp((now - exitAt) / exitTime, 0, 1) else 0
		local keep = 1 - out

		-- Screen flash (rare drops): a hard white frame, then a fast fade.
		if tier.flash and current == me then
			local k = if t < R.FlashHold then 1 else 1 - quadOut((t - R.FlashHold) / (R.FlashEnd - R.FlashHold))
			screenFlash.BackgroundTransparency = 1 - (1 - tier.flash) * k
		end

		-- Card: pop to the peak, settle, rise into place, fade up.
		local s
		if t < R.PeakAt then
			s = lerp(R.FromScale, R.Peak, backOut(t / R.PeakAt))
		elseif t < R.SettleBy then
			s = lerp(R.Peak, 1, quadOut((t - R.PeakAt) / (R.SettleBy - R.PeakAt)))
		else
			s = 1
		end
		cardScale.Scale = s * (1 - 0.1 * quadIn(out))
		local dy = R.Rise * (1 - cubicOut(t / R.RiseTime)) - 16 * quadIn(out)
		card.Position = UDim2.new(0.5, 0, 0.5, math.floor(dy + 0.5))
		setFade(bodyFade, quadOut(t / R.FadeTime) * keep)

		-- Rarity border flashes white and back.
		local fk = 0
		if t >= R.BorderFlashAt and t < R.BorderFlashPeak then
			fk = quadOut((t - R.BorderFlashAt) / (R.BorderFlashPeak - R.BorderFlashAt))
		elseif t >= R.BorderFlashPeak and t < R.BorderFlashEnd then
			fk = 1 - quadIn((t - R.BorderFlashPeak) / (R.BorderFlashEnd - R.BorderFlashPeak))
		end
		paintBorder(rt.bottom:Lerp(WHITE, fk))
		borderStroke.Thickness = 4 + 2 * fk

		-- Sword pops out of its tile.
		local sa = (t - R.SwordAt) / R.SwordTime
		viewScale.Scale = if sa <= 0 then 0.4 else lerp(0.4, 1, backOut(sa))
		view.Rotation = -20 * (1 - cubicOut(sa))
		setFade(viewFade, quadOut(sa * 2.5) * keep)

		-- Name punches in and rises to a stop.
		local na = (t - R.NameAt) / R.NameTime
		nameScale.Scale = if na <= 0 then R.NameFrom else lerp(R.NameFrom, 1, cubicOut(na))
		nameLabel.Position = UDim2.fromOffset(colX, 78 + math.floor(8 * (1 - cubicOut(na)) + 0.5))
		setFade(nameFade, quadOut(na * 2) * keep)

		-- Stat lines land one after another.
		for i, l in ipairs(stats) do
			local a = (t - R.StatAt - (i - 1) * R.StatStep) / R.StatTime
			local rest = statRest[i]
			l.Position = rest + UDim2.fromOffset(0, math.floor(10 * (1 - cubicOut(a)) + 0.5))
			setFade(statFades[i], quadOut(a) * keep)
		end

		-- One sweep across the card, its border and the name.
		local sw = (t - R.SweepAt) / (R.SweepEnd - R.SweepAt)
		local off = if sw <= 0 then -1 elseif sw >= 1 then 1 else lerp(-1, 1, sineInOut(sw))
		sheenGrad.Offset = Vector2.new(off, 0)
		borderSweep.Offset = Vector2.new(off, 0)
		nameSweep.Offset = Vector2.new(off, 0)

		-- Ring bursts outward and fades.
		local ra = (t - R.RingAt) / (R.RingEnd - R.RingAt)
		if ra > 0 and ra < 1 then
			local d = T * lerp(0.9, 2.6, quadOut(ra))
			ring.Size = UDim2.fromOffset(d, d)
			ringStroke.Transparency = quadIn(ra)
			ringStroke.Thickness = lerp(8, 2, ra)
			ring.BackgroundTransparency = lerp(0.55, 1, quadOut(ra))
		else
			ringStroke.Transparency = 1
			ring.BackgroundTransparency = 1
		end

		-- Sparkles fly off the ring, grow, spin and shrink away.
		for _, sp in ipairs(sparks) do
			local a = (t - sp.delay) / R.SparkLife
			if a > 0 and a < 1 then
				local p = sp.dir * sp.dist * cubicOut(a)
				sp.frame.Position = tileCentre + UDim2.fromOffset(p.X, p.Y)
				sp.scale.Scale = if a < 0.35 then backOut(a / 0.35) else 1 - quadIn((a - 0.35) / 0.65)
				sp.frame.Rotation = 45 + sp.spin * a
			else
				sp.scale.Scale = 0
			end
		end

		if out >= 1 then
			conn:Disconnect()
			liveStages[stage] = nil
			stage:Destroy()
			if current == me then current = nil end
		end
	end
	conn = RunService.RenderStepped:Connect(step)
	step()
end

DROP_EVENT.OnClientEvent:Connect(revealDrop)

-- Studio-only motion capture hook (see GuiShowcase.motion): plays the reveal for one made-up
-- Legendary drop. Nothing is sent to the server; the sword exists only in this card.
GuiShowcase.motion("RewardReveal", function()
	revealDrop("Legendary", 4.25, "Sunforged Dawnbreaker", {
		{ name = "Keen", desc = "+12% Crit Chance" },
		{ name = "Swift", desc = "+8% Attack Speed" },
	}, true)
end)

-- Handle auto-sold sword toasts
SWORD_LOST_EVENT.OnClientEvent:Connect(function(fullName, rarityName)
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(270, 52)
	card.BackgroundColor3 = Color3.fromRGB(32, 20, 20)
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Parent = holder
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	local s = Instance.new("UIStroke", card)
	s.Color = Color3.fromRGB(230, 70, 70)
	s.Thickness = 1.4
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.fromOffset(246, 20)
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextSize = 13
	title.TextColor3 = Color3.fromRGB(255, 110, 110)
	title.Text = "\u{1F4A5} Sword Shattered on Death"
	title.Parent = card
	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(12, 26)
	desc.Size = UDim2.fromOffset(246, 16)
	desc.Font = Enum.Font.Gotham
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextSize = 12
	desc.TextColor3 = Color3.fromRGB(220, 180, 180)
	desc.Text = tostring(fullName or "Your sword") .. " is gone."
	desc.Parent = card
	task.delay(4.5, function()
		if card and card.Parent then card:Destroy() end
	end)
end)

AUTO_SELL_NOTICE.OnClientEvent:Connect(function(fullName, rarityName, goldEarned)
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(270, 52)
	card.BackgroundColor3 = Color3.fromRGB(28, 26, 20)
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Parent = holder

	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	local s = Instance.new("UIStroke", card)
	s.Color = Color3.fromRGB(255, 215, 0)
	s.Thickness = 1.2

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.fromOffset(246, 20)
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextSize = 13
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.Text = "⚡ Auto-Sold Fewer-Slot Drop"
	title.Parent = card

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(12, 26)
	desc.Size = UDim2.fromOffset(246, 16)
	desc.Font = Enum.Font.Gotham
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextSize = 12
	desc.TextColor3 = Color3.fromRGB(220, 220, 230)
	desc.Text = string.format("%s (+%d Gold)", fullName, goldEarned)
	desc.Parent = card

	local textElements = { title, desc }
	card.BackgroundTransparency = 1
	for _, o in ipairs(textElements) do o.TextTransparency = 1 end
	s.Transparency = 1

	TweenService:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(s, TweenInfo.new(0.25), { Transparency = 0 }):Play()
	for _, o in ipairs(textElements) do
		TweenService:Create(o, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	end

	task.delay(3.0, function()
		TweenService:Create(card, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(s, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		for _, o in ipairs(textElements) do
			TweenService:Create(o, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
		task.wait(0.45)
		card:Destroy()
	end)
end)
