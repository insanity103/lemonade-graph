--// SpinPopup  (client module, started by GoldNumbers.client: the spin result, told in a small card
--   at the top right). A ModuleScript under ReplicatedStorage (synced as a folder) rather than its
--   own LocalScript, so it rides the existing client script list, like SpinStation and TokenDrops.
--
-- Driven only by the server's SpinAction "Result" (the Spin Wheel section of GameplayServices owns
-- the roll; nothing here decides anything). The card is exactly the quest tracker's width
-- (PanelChrome.HUD.QuestWidth) and shorter than it, wears the same chrome, and sits in the screen's
-- top-right corner, clear above the tracker (stacking flush on the tracker only on short screens).
-- It captures no input (every frame is inactive), has no buttons, never dims the screen, and
-- dismisses itself.
--
-- The reveal runs in step with the wheel (payload.seconds):
--   1. IN + SPIN. The card slides in from the right edge the moment the wheel starts. The tile
--      cycles through the REAL pool this spin rolled from (result.pool: every sword it could land,
--      each with its own real odds): a rarity-tinted sword glyph, the sword's name and its % odds,
--      one step every ~80 ms slowing to ~250 ms. No rarity pill is shown until the spin lands.
--   2. LAND. The result's name, rarity pill, 1-in-N odds and prefix (with the prefix rung's own
--      1-in-N) pop in, and the real sword render replaces the glyph. Impact is tiered by rarity:
--      Common/Uncommon a 120 ms card pop to 1.08x; Rare adds a rarity-coloured border pulse, rays
--      and a shimmer; Epic and up get a 200 ms white flash inside the card, a 1.15x overshoot, a
--      rarity glow ring behind the sword for 600 ms, a pulse on the odds and a sound stinger.
--   3. HOLD, OUT. A bar along the bottom drains while the card holds (2.5 s), then the card slides off the right edge on its own. A new result replaces it.
local RunService = game:GetService("RunService")
local SpinPopup = {}
if not RunService:IsClient() then
	return SpinPopup
end

local function run()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TweenService = game:GetService("TweenService")
	local Workspace = game:GetService("Workspace")

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local Config = ReplicatedStorage:WaitForChild("Config")
	local SpinPools = require(Config:WaitForChild("SpinPools"))
	local WeaponModifiers = require(Config:WaitForChild("WeaponModifiers"))
	local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
	local AudioManager = require(ReplicatedStorage:WaitForChild("AudioManager"))
	local SPIN_ACTION = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("SpinAction")

	local BRIGHT = PanelChrome.BRIGHT
	local RARITY_TILE = PanelChrome.RARITY_TILE
	local HUD = PanelChrome.HUD
	local W, H = HUD.QuestWidth, HUD.PopupHeight
	local TILE = 104
	local COL_X = 14 + TILE + 12 -- right column's left edge
	local COL_W = W - COL_X - 14
	local SWORD_POSE = { yawDeg = 12, tiltDeg = 42, margin = 1.02 }

	-- [TUNING] per rarity: sparkles on landing, and extra seconds of hold
	local IMPACT = {
		Common = { sparks = 5, hold = 0 },
		Uncommon = { sparks = 7, hold = 0 },
		Rare = { sparks = 11, hold = 0 },
		Epic = { sparks = 18, hold = 0 },
		Legendary = { sparks = 24, hold = 0 },
	}
	local HOLD = 2.5 -- base seconds the landed card stays up (a draining bar shows it)
	local OUT_SECONDS = 0.3 -- the slide off the right edge when the hold runs out
	local FLICK_FAST, FLICK_SLOW = 0.08, 0.25 -- seconds per pool step at the start / end of the spin

	local function rank(rarity: string?): number
		return SpinPools.RARITY_ORDER[rarity or ""] or 1
	end
	local function tileOf(rarity: string?)
		return RARITY_TILE[rarity or ""] or RARITY_TILE.Common
	end
	local function pctText(p: number): string
		local v = p * 100
		if v >= 10 then return string.format("%d%%", math.floor(v + 0.5)) end
		if v >= 1 then return (string.format("%.1f", v):gsub("%.0$", "")) .. "%" end
		return (string.format("%.2f", v):gsub("0$", "")) .. "%"
	end
	local function oddsText(p: number?): string
		if not p or p <= 0 then return "?" end
		return WeaponModifiers.OneInText(p) .. "  ·  " .. pctText(p)
	end
	local function tween(inst, seconds, props, style, dir)
		local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad,
			dir or Enum.EasingDirection.Out), props)
		t:Play()
		return t
	end

	-- ---------------------------------------------------------------- layer and placement
	local existing = playerGui:FindFirstChild("SpinPopupGui")
	if existing then existing:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpinPopupGui"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 12 -- just over the quest tracker (11), under every modal (19+)
	gui.Parent = playerGui

	-- The holder is the card's slot on screen; the card slides inside it.
	local holder = Instance.new("Frame")
	holder.Name = "Slot"
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(W, H)
	holder.Visible = false
	holder.Active = false
	holder.Parent = gui
	local holderScale = Instance.new("UIScale")
	holderScale.Parent = holder

	local tracker: GuiObject? = nil
	local cardH = H -- the live card's design height (a multi-spin card is a little taller, never over the quest card)
	local MIN_TOP = 6 -- in inset space (IgnoreGuiInset off): already under the top bar
	-- The card's home is the screen's own top-right corner (right gutter, just under the top bar),
	-- clear above the quest tracker, which sits beside the side-button rail lower down. Only when
	-- the screen is too short for both does it fall back to stacking flush on the tracker.
	local function place()
		local camera = Workspace.CurrentCamera
		if not camera then return end
		local viewport = camera.ViewportSize
		local s = PanelChrome.hudScale(viewport)
		holderScale.Scale = s
		local h, gap = cardH * s, HUD.PopupGap * s
		local cornerX = viewport.X - math.floor(HUD.Margin * s)
		local cornerY = MIN_TOP
		if tracker and tracker.Parent and tracker.AbsoluteSize.X > 0 and tracker.Visible then
			local top = tracker.AbsolutePosition.Y
			local left = tracker.AbsolutePosition.X
			-- (the tracker's "!" medallion rides its top-left, left of the corner card, so the gap is enough)
			local clashes = cornerY + h + gap > top and cornerX - W * s < left + tracker.AbsoluteSize.X
			if clashes then
				-- too short a screen for the corner: stack on the tracker instead (above, else below)
				local right = left + tracker.AbsoluteSize.X
				local y = top - gap - 22 * s - h -- 22: clear of the tracker's "!" medallion
				if y < MIN_TOP then
					y = top + tracker.AbsoluteSize.Y + gap
				end
				holder.Position = UDim2.fromOffset(math.floor(right), math.floor(y))
				return
			end
		end
		holder.Position = UDim2.fromOffset(cornerX, cornerY)
	end
	PanelChrome.onViewport(function() place() end)
	task.spawn(function()
		local questGui = playerGui:WaitForChild("QuestGui", 30)
		tracker = questGui and questGui:WaitForChild("QuestTracker", 30) :: GuiObject?
		if tracker then
			tracker:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
			tracker:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
			tracker:GetPropertyChangedSignal("Visible"):Connect(place)
		end
		place()
	end)

	-- ---------------------------------------------------------------- the card
	local function frame(parent, name, props)
		local f = Instance.new("Frame")
		f.Name = name
		f.BorderSizePixel = 0
		f.Active = false
		for k, v in pairs(props) do (f :: any)[k] = v end
		f.Parent = parent
		return f
	end
	local function text(parent, name, props)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Active = false
		for k, v in pairs(props) do (l :: any)[k] = v end
		l.Parent = parent
		return l
	end

	local current = nil -- the live card's state table; a new result retires it
	local showMulti -- the multi-spin reveal (defined below the single one)

	local function buildCard()
		local c = {}
		c.card = frame(holder, "SpinPopup", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2,
		})
		PanelChrome.corner(c.card, 18)
		PanelChrome.gradient(c.card, BRIGHT.Panel, BRIGHT.PanelBottom)
		c.outline = PanelChrome.stroke(c.card, BRIGHT.Outline, 3.5)
		c.scale = Instance.new("UIScale")
		c.scale.Parent = c.card

		-- Rarity ring just inside the outline (lit on landing from Uncommon up).
		c.ring = frame(c.card, "RarityRing", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), ZIndex = 3,
		})
		PanelChrome.corner(c.ring, 14)
		c.ringStroke = PanelChrome.stroke(c.ring, BRIGHT.Outline, 3, 1)

		-- Shimmer lane: a clipped strip inside the rounded corners that a light band sweeps across.
		c.lane = frame(c.card, "Shimmer", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 1, -12),
			ClipsDescendants = true, ZIndex = 4,
		})
		c.band = frame(c.lane, "Band", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, -60, 0.5, 0), Size = UDim2.new(0, 46, 2, 0),
			Rotation = 20, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 4,
		})
		local bandFade = Instance.new("UIGradient")
		bandFade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1),
		})
		bandFade.Parent = c.band

		-- Glow ring behind the sword tile (Epic and up, 600 ms on landing), kept inside the card.
		c.haloRing = frame(c.card, "Halo", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(14 + TILE / 2, H / 2 - 2),
			Size = UDim2.fromOffset(TILE, TILE), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
			ZIndex = 4,
		})
		PanelChrome.corner(c.haloRing, 26)
		c.haloStroke = PanelChrome.stroke(c.haloRing, BRIGHT.Outline, 6, 1)

		-- The sword tile.
		c.tileSlot = frame(c.card, "TileSlot", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(14 + TILE / 2, H / 2 - 2),
			Size = UDim2.fromOffset(TILE, TILE), BackgroundTransparency = 1, ZIndex = 5,
		})
		c.tileScale = Instance.new("UIScale")
		c.tileScale.Parent = c.tileSlot
		c.tile = frame(c.tileSlot, "Tile", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5, ClipsDescendants = true,
		})
		PanelChrome.corner(c.tile, 18)
		c.tileGradient = PanelChrome.gradient(c.tile, tileOf("Common").top, tileOf("Common").bottom)
		c.tileGradient.Rotation = 70
		PanelChrome.stroke(c.tile, BRIGHT.Outline, 3.5)
		c.tileRing = frame(c.tile, "RarityRing", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), ZIndex = 5,
		})
		PanelChrome.corner(c.tileRing, 15)
		c.tileRingStroke = PanelChrome.stroke(c.tileRing, tileOf("Common").rim, 3)
		-- Light rays behind the sword (Rare and up), faded toward their ends so the tile's square
		-- clip never shows at the rounded corners.
		c.rays = frame(c.tile, "Rays", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1, ZIndex = 5, Visible = false,
		})
		for i = 0, 5 do
			local ray = frame(c.rays, "Ray", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 16, 1.1, 0),
				Rotation = i * 30, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25, ZIndex = 5,
			})
			local g = Instance.new("UIGradient")
			g.Rotation = 90
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1),
			})
			g.Parent = ray
		end
		-- Soft glow disc where the sword sits.
		c.glow = frame(c.tile, "Glow", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromScale(0.72, 0.72),
			BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, ZIndex = 5,
		})
		PanelChrome.corner(c.glow, 999)
		c.vp = Instance.new("ViewportFrame")
		c.vp.Name = "Sword"
		c.vp.BackgroundTransparency = 1
		c.vp.Size = UDim2.fromScale(1, 1)
		c.vp.ZIndex = 6
		c.vp.Active = false
		c.vp.Parent = c.tile
		c.vp.ImageTransparency = 1 -- the real render only shows once the spin lands
		-- Four ink-coloured copies of the render, nudged 2 px each way, draw a crisp outline round
		-- the sword so a pale blade still reads against a bright Legendary tile and its glow.
		c.vpOutline = {}
		for _, o in ipairs({ { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 } }) do
			local v = Instance.new("ViewportFrame")
			v.Name = "SwordOutline"
			v.BackgroundTransparency = 1
			v.Position = UDim2.fromOffset(o[1], o[2])
			v.Size = UDim2.fromScale(1, 1)
			v.ZIndex = 6
			v.Active = false
			v.ImageColor3 = BRIGHT.Outline
			v.ImageTransparency = 1
			v.Parent = c.tile
			table.insert(c.vpOutline, v)
		end
		c.vp.ZIndex = 7
		-- A stylised sword glyph that cycles through the pool while the wheel spins: blade, tip,
		-- guard, grip and pommel, tinted per sword's rarity (the real sword's look stays hidden).
		c.glyph = frame(c.tile, "Glyph", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(76, 76),
			BackgroundTransparency = 1, Rotation = 45, ZIndex = 7,
		})
		c.glyphScale = Instance.new("UIScale")
		c.glyphScale.Parent = c.glyph
		local function part(name, props, radius)
			local f = frame(c.glyph, name, props)
			PanelChrome.corner(f, radius)
			PanelChrome.stroke(f, BRIGHT.Outline, 2.5)
			return f
		end
		c.glyphTip = part("Tip", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 11),
			Size = UDim2.fromOffset(13, 13), Rotation = 45, ZIndex = 7 }, 2)
		c.glyphBlade = part("Blade", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(18, 40), ZIndex = 8 }, 3)
		c.glyphGuard = part("Guard", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 52),
			Size = UDim2.fromOffset(40, 9), ZIndex = 9 }, 4)
		c.glyphGrip = part("Grip", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56),
			Size = UDim2.fromOffset(9, 13), BackgroundColor3 = Color3.fromRGB(122, 78, 48), ZIndex = 8 }, 2)
		c.glyphPommel = part("Pommel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 71),
			Size = UDim2.fromOffset(12, 12), ZIndex = 9 }, 99)

		-- Right column.
		c.header = text(c.card, "Header", {
			Position = UDim2.fromOffset(COL_X, 10), Size = UDim2.fromOffset(COL_W, 16), Font = Enum.Font.GothamBlack,
			TextSize = 15, TextColor3 = BRIGHT.InkMuted, TextXAlignment = Enum.TextXAlignment.Left, Text = "SPINNING",
			ZIndex = 6,
		})
		c.name = PanelChrome.display(c.card, { name = "SwordName", text = "? ? ?", size = 24, stroke = 2.5,
			xAlign = Enum.TextXAlignment.Left, scaled = true, minSize = 12, zIndex = 6,
			pos = UDim2.fromOffset(COL_X, 27), size2 = UDim2.fromOffset(COL_W, 30) })
		c.name.Active = false
		c.nameScale = Instance.new("UIScale")
		c.nameScale.Parent = c.name

		-- The odds pill has this row to itself (the rarity rides the sword tile).
		c.pillRow = frame(c.card, "Pills", {
			Position = UDim2.fromOffset(COL_X, 62), Size = UDim2.fromOffset(COL_W, 26), BackgroundTransparency = 1,
			ZIndex = 6,
		})
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.Padding = UDim.new(0, 6)
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = c.pillRow
		-- The rarity is a ribbon across the foot of the sword tile (hidden until the spin lands), so
		-- the odds get the whole pill row to themselves and never run past the card's edge.
		c.rarityPill = frame(c.tileSlot, "Rarity", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -2),
			Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 9,
		})
		PanelChrome.corner(c.rarityPill, 12)
		c.rarityGradient = PanelChrome.gradient(c.rarityPill, tileOf("Common").top, tileOf("Common").bottom)
		c.rarityStroke = PanelChrome.stroke(c.rarityPill, BRIGHT.Outline, 2.5)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = c.rarityPill
		c.rarityText = PanelChrome.display(c.rarityPill, { name = "Text", text = "COMMON", size = 14, stroke = 2,
			size2 = UDim2.new(0, 0, 1, 0), zIndex = 10 })
		c.rarityText.AutomaticSize = Enum.AutomaticSize.X
		c.rarityText.Active = false
		c.rarityScale = Instance.new("UIScale")
		c.rarityScale.Parent = c.rarityPill
		c.oddsPill = frame(c.pillRow, "Odds", {
			Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = BRIGHT.Row,
			LayoutOrder = 2, ZIndex = 6,
		})
		PanelChrome.corner(c.oddsPill, 13)
		PanelChrome.stroke(c.oddsPill, BRIGHT.RowStroke, 2)
		local pad2 = pad:Clone()
		pad2.PaddingLeft = UDim.new(0, 9)
		pad2.PaddingRight = UDim.new(0, 9)
		pad2.Parent = c.oddsPill
		c.oddsText = text(c.oddsPill, "Text", {
			Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Font = Enum.Font.GothamBlack,
			TextSize = 18, TextColor3 = BRIGHT.Ink, Text = "?", ZIndex = 7,
		})
		c.oddsScale = Instance.new("UIScale")
		c.oddsScale.Parent = c.oddsPill

		-- Prefix line: a rung-coloured gem, the prefix word, then its rung and the rung's own odds.
		c.prefixRow = frame(c.card, "Prefix", {
			Position = UDim2.fromOffset(COL_X, 94), Size = UDim2.fromOffset(COL_W, 24), BackgroundTransparency = 1,
			ZIndex = 6,
		})
		c.gem = frame(c.prefixRow, "Gem", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 9, 0.5, 0), Size = UDim2.fromOffset(13, 13),
			Rotation = 45, BackgroundColor3 = BRIGHT.Grey, ZIndex = 7,
		})
		PanelChrome.corner(c.gem, 3)
		PanelChrome.stroke(c.gem, BRIGHT.Outline, 2)
		c.prefixText = text(c.prefixRow, "Text", {
			Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 1, 0), Font = Enum.Font.GothamBold,
			TextSize = 17, TextColor3 = BRIGHT.InkMuted, TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
			TextScaled = true, Text = "", ZIndex = 7,
		})
		local fit = Instance.new("UITextSizeConstraint")
		fit.MaxTextSize = 17
		fit.MinTextSize = 10
		fit.Parent = c.prefixText
		c.prefixScale = Instance.new("UIScale")
		c.prefixScale.Parent = c.prefixRow

		-- Hold timer along the bottom.
		c.timerTrack = frame(c.card, "Timer", {
			Position = UDim2.fromOffset(COL_X, H - 15), Size = UDim2.fromOffset(COL_W, 7), BackgroundColor3 = BRIGHT.Row,
			ZIndex = 6, BackgroundTransparency = 1,
		})
		PanelChrome.corner(c.timerTrack, 3)
		c.timerFill = frame(c.timerTrack, "Fill", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = BRIGHT.GreyDark, ZIndex = 7, BackgroundTransparency = 1,
		})
		PanelChrome.corner(c.timerFill, 3)

		-- Flash over the whole card on landing.
		c.flash = frame(c.card, "Flash", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 20,
		})
		PanelChrome.corner(c.flash, 18)

		-- Everything that pops in on landing starts hidden.
		for _, sc in ipairs({ c.rarityScale, c.oddsScale, c.prefixScale }) do sc.Scale = 1 end
		c.prefixRow.Visible = false
		return c
	end

	local function setTileRarity(c, rarity)
		local t = tileOf(rarity)
		c.tileGradient.Color = ColorSequence.new(t.top, t.bottom)
		c.tileRingStroke.Color = t.rim
		c.rarityGradient.Color = ColorSequence.new(t.top, t.bottom)
		c.rarityText.Text = string.upper(rarity)
		c.rarityText.TextSize = #rarity > 6 and 14 or 17 -- short tiers read bigger; long ones stay on the tile
		c.rarityText.TextColor3 = rarity == "Common" and BRIGHT.Ink or Color3.new(1, 1, 1)
		local stroke = c.rarityText:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = rarity == "Common" and Color3.new(1, 1, 1) or BRIGHT.Outline
		end
	end

	local function pulse(sc: UIScale, peak: number, seconds: number)
		sc.Scale = peak
		tween(sc, seconds, { Scale = 1 }, Enum.EasingStyle.Back)
	end

	local function popIn(sc: UIScale, seconds: number)
		sc.Scale = 0.2
		tween(sc, seconds, { Scale = 1 }, Enum.EasingStyle.Back)
	end

	local function sparkBurst(c, rarity, count)
		local t = tileOf(rarity)
		local centre = Vector2.new(14 + TILE / 2, H / 2 - 2)
		for i = 1, count do
			local a = (i / count) * math.pi * 2 + math.random() * 0.4
			local dist = 46 + math.random() * 60
			local size = 7 + math.random() * 7
			local s = frame(c.card, "Spark", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(centre.X, centre.Y),
				Size = UDim2.fromOffset(size, size), Rotation = 45,
				BackgroundColor3 = (i % 3 == 0) and Color3.new(1, 1, 1) or t.bottom, ZIndex = 15,
			})
			PanelChrome.corner(s, 2)
			PanelChrome.stroke(s, BRIGHT.Outline, 1.5)
			local target = centre + Vector2.new(math.cos(a), math.sin(a) * 0.7) * dist
			target = Vector2.new(math.clamp(target.X, 8, W - 8), math.clamp(target.Y, 8, H - 8))
			local life = 0.45 + math.random() * 0.3
			tween(s, life, { Position = UDim2.fromOffset(target.X, target.Y), Rotation = 45 + math.random(-90, 90),
				Size = UDim2.fromOffset(2, 2) }, Enum.EasingStyle.Quart)
			task.delay(life, function() s:Destroy() end)
		end
	end

	local function retire(c, fast)
		if c.retired then return end
		c.retired = true
		local out
		if fast then
			-- replaced by a newer result: get out of the way at once
			out = tween(c.card, 0.12, { Position = UDim2.new(0, W * 0.35, 0, 0) }, Enum.EasingStyle.Quad,
				Enum.EasingDirection.In)
			for _, d in ipairs(c.card:GetDescendants()) do
				if d:IsA("TextLabel") then tween(d, 0.1, { TextTransparency = 1 }) end
			end
			tween(c.card, 0.12, { BackgroundTransparency = 1 })
			tween(c.outline, 0.12, { Transparency = 1 })
		else
			-- the timer ran out: the whole card slides off the right edge of the screen, intact
			out = tween(c.card, OUT_SECONDS, { Position = UDim2.new(0, W + 60, 0, 0) }, Enum.EasingStyle.Quad,
				Enum.EasingDirection.In)
		end
		out.Completed:Connect(function()
			c.card:Destroy()
			if current == c then
				current = nil
				holder.Visible = false
			end
		end)
	end

	local function tintGlyph(c, rarity)
		local t = tileOf(rarity)
		c.glyphBlade.BackgroundColor3 = t.top:Lerp(Color3.new(1, 1, 1), 0.35)
		c.glyphTip.BackgroundColor3 = c.glyphBlade.BackgroundColor3
		c.glyphGuard.BackgroundColor3 = t.bottom
		c.glyphPommel.BackgroundColor3 = t.bottom
	end

	-- The whole reveal for one Result payload.
	local function show(payload)
		local results = payload.results
		if typeof(results) ~= "table" or #results == 0 then return end
		-- A multi-spin lands its best pull on the card (rarest rarity, then the longest odds).
		local best = results[1]
		for _, r in ipairs(results) do
			if rank(r.rarity) > rank(best.rarity) or (rank(r.rarity) == rank(best.rarity) and (r.p or 1) < (best.p or 1)) then
				best = r
			end
		end
		if current then retire(current, true) end
		cardH = H
		holder.Size = UDim2.fromOffset(W, H)
		place()
		local c = buildCard()
		current = c
		holder.Visible = true
		local count = #results
		local impact = IMPACT[best.rarity] or IMPACT.Common
		local landAt = math.max(1.2, (tonumber(payload.seconds) or SpinPools.SPIN_SECONDS) - 0.2)

		-- IN: slide from the right edge.
		c.card.Position = UDim2.new(0, W * 0.6, 0, 0)
		c.scale.Scale = 0.9
		tween(c.card, 0.3, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)
		tween(c.scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		c.header.Text = count > 1 and string.format("SPINNING x%d ...", count) or "SPINNING ..."
		-- No rarity is claimed until the spin lands: the rarity pill stays hidden while spinning.
		c.rarityPill.Visible = false

		-- The real sword's render loads behind the glyph (it reaches the backpack with the result).
		task.spawn(function()
			local backpack = player:FindFirstChildOfClass("Backpack")
			local tool = backpack and backpack:WaitForChild(best.fullName or "", 1.5)
			if c.retired then return end
			if tool and tool:IsA("Tool") then
				PanelChrome.renderTool(c.vp, tool, SWORD_POSE)
				for _, v in ipairs(c.vpOutline) do
					PanelChrome.renderTool(v, tool, SWORD_POSE)
					v.Ambient = Color3.new(1, 1, 1)
				end
				c.hasRender = true
			end
		end)

		-- THE SPIN: cycle through the real pool this spin rolled from (every sword it could land,
		-- each with its own real odds), fast at first (~80 ms a step) and slowing to ~250 ms, then land.
		local pool = {}
		for _, entry in ipairs(typeof(best.pool) == "table" and best.pool or {}) do
			if typeof(entry) == "table" and RARITY_TILE[entry.rarity] and entry.sword then table.insert(pool, entry) end
		end
		if #pool == 0 then
			for _, entry in ipairs(typeof(best.poolRarities) == "table" and best.poolRarities or {}) do
				if typeof(entry) == "table" and RARITY_TILE[entry.rarity] then
					table.insert(pool, { sword = entry.rarity .. " sword", rarity = entry.rarity, p = entry.p })
				end
			end
		end
		if #pool == 0 then pool = { { sword = best.sword or "?", rarity = best.rarity, p = best.p } } end
		local function showEntry(entry)
			local t = tileOf(entry.rarity)
			c.tileGradient.Color = ColorSequence.new(t.top, t.bottom)
			c.tileRingStroke.Color = t.rim
			tintGlyph(c, entry.rarity)
			c.name.Text = tostring(entry.sword)
			c.oddsText.Text = pctText(entry.p or 0)
			-- slot-reel roll: each new name drops in from above the row, like a reel ticking over
			c.name.Position = UDim2.fromOffset(COL_X, 17)
			c.name.TextTransparency = 0.45
			tween(c.name, 0.07, { Position = UDim2.fromOffset(COL_X, 27), TextTransparency = 0 })
		end
		task.spawn(function()
			local start = os.clock()
			local i = math.random(1, #pool)
			local nextAt = 0
			local tilt = 0
			while not c.retired do
				local e = os.clock() - start
				if e >= landAt then break end
				if e >= nextAt then
					i = (i % #pool) + 1
					showEntry(pool[i])
					local slow = math.clamp(e / landAt, 0, 1)
					nextAt = e + FLICK_FAST + (FLICK_SLOW - FLICK_FAST) * slow * slow
					tilt = -tilt + (tilt == 0 and 10 or 0)
					c.glyph.Rotation = 45 + tilt
					pulse(c.tileScale, 1.05, 0.1)
					pulse(c.glyphScale, 1.14, 0.12)
				end
				RunService.RenderStepped:Wait()
			end
			if c.retired then return end

			-- LAND.
			local tile = tileOf(best.rarity)
			local r = rank(best.rarity)
			setTileRarity(c, best.rarity)
			c.glyph.Rotation = 45
			tintGlyph(c, best.rarity)
			if c.hasRender then
				c.glyph.Visible = false
				c.vp.ImageTransparency = 0
				for _, v in ipairs(c.vpOutline) do v.ImageTransparency = 0 end
				-- a bright tile's glow would wash a pale blade out: soften it behind the render
				c.glow.BackgroundTransparency = 0.8
			end
			c.header.Text = count > 1 and string.format("BEST OF %d SPINS", count) or "YOU GOT"
			c.name.Position = UDim2.fromOffset(COL_X, 27)
			c.name.TextTransparency = 0
			c.name.Text = best.fullName or best.sword or "?"
			c.rarityPill.Visible = true
			c.oddsText.Text = oddsText(best.p)
			c.oddsText.TextSize = #c.oddsText.Text > 16 and 15 or 18 -- long odds still fit the row
			pulse(c.tileScale, 1.18, 0.3)
			pulse(c.nameScale, 1.2, 0.26)
			popIn(c.rarityScale, 0.28)
			task.delay(0.06, function() popIn(c.oddsScale, 0.28) end)
			-- Tiered card impact.
			if r >= 4 then
				-- Epic and up: a 200 ms white flash inside the card, a 1.15x overshoot, a stinger.
				c.flash.BackgroundTransparency = 0
				tween(c.flash, 0.2, { BackgroundTransparency = 1 }, Enum.EasingStyle.Linear)
				c.scale.Scale = 1.15
				tween(c.scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
				AudioManager.PlayGlobal("reveal_land")
				AudioManager.PlayGlobal("level_up")
			else
				-- Common to Rare: a 120 ms pop to 1.08x.
				tween(c.scale, 0.06, { Scale = 1.08 }).Completed:Connect(function()
					if not c.retired then tween(c.scale, 0.12, { Scale = 1 }) end
				end)
				AudioManager.PlayGlobal("reveal_land")
			end
			if r >= 3 then
				-- Rare and up: the card's border pulses in the rarity's colour.
				c.outline.Color = tile.bottom
				task.spawn(function()
					for _ = 1, 3 do
						if c.retired then return end
						c.outline.Thickness = 8
						tween(c.outline, 0.22, { Thickness = 4 })
						task.wait(0.24)
					end
				end)
				c.ringStroke.Color = tile.top
				c.ringStroke.Transparency = 0
			elseif r == 2 then
				c.ringStroke.Color = tile.bottom
				c.ringStroke.Transparency = 0.2
			end
			if r >= 4 then
				-- Glow ring behind the sword for 600 ms (two waves), and the odds pulse.
				c.haloStroke.Color = tile.bottom
				c.haloRing.BackgroundColor3 = tile.top
				for wave = 0, 1 do
					task.delay(wave * 0.25, function()
						if c.retired then return end
						c.haloRing.Size = UDim2.fromOffset(TILE, TILE)
						c.haloRing.BackgroundTransparency = 0.25
						c.haloStroke.Transparency = 0
						tween(c.haloRing, 0.35, { Size = UDim2.fromOffset(TILE + 26, TILE + 26), BackgroundTransparency = 1 })
						tween(c.haloStroke, 0.35, { Transparency = 1 })
					end)
				end
				task.delay(0.12, function()
					if c.retired then return end
					pulse(c.oddsScale, 1.35, 0.3)
					c.oddsText.TextColor3 = tile.rim
					task.delay(0.35, function() pulse(c.oddsScale, 1.2, 0.25) end)
				end)
			end
			-- Prefix, with its rung and the rung's own odds.
			-- the strongest prefix the sword rolled (a chase always wins the line: it is its bracket's top rung)
			local mod = nil
			for _, m in ipairs(typeof(best.mods) == "table" and best.mods or {}) do
				if not mod or (m.tier or 0) > (mod.tier or 0) or ((m.tier or 0) == (mod.tier or 0) and m.chase and not mod.chase) then
					mod = m
				end
			end
			task.delay(0.14, function()
				if c.retired then return end
				c.prefixRow.Visible = true
				if mod then
					local rung = WeaponModifiers.Rungs[mod.tier or 1]
					local chaseDef = WeaponModifiers.ChaseByName[tostring(mod.name)]
					local rungColor = (chaseDef and chaseDef.color) or (rung and rung.color) or BRIGHT.Grey
					c.gem.BackgroundColor3 = rungColor
					local oneIn = (mod.p and mod.p > 0) and (" · " .. WeaponModifiers.OneInText(mod.p)) or ""
					-- the rare-roll tag (WeaponModifiers.TagFor): NICE! for the rung your bracket just
					-- opened, GREAT! for a newest top-tier rung, CHASE! for the bracket's named chase,
					-- LEMONADE! for the last one
					local TAGS = { Nice = { "NICE!", BRIGHT.GoldDark }, Great = { "GREAT!", Color3.fromRGB(0, 150, 170) },
						Chase = { "CHASE!", Color3.fromRGB(215, 50, 140) },
						Lemonade = { "LEMONADE!", Color3.fromRGB(230, 150, 0) } }
					local tag = mod.tag and TAGS[mod.tag]
					local tagText = tag and string.format("  <font color=\"#%s\"><b>%s</b></font>", tag[2]:ToHex(), tag[1]) or ""
					-- a chase names what it does and how long it stays your best roll (bestUntil)
					local what = chaseDef and string.format(" %s%s", chaseDef.desc,
						chaseDef.bestUntil and string.format(", best to Lv %d", chaseDef.bestUntil) or ", never beaten") or ""
					c.prefixText.Text = string.format("<font color=\"#%s\"><b>%s</b></font> prefix%s · %s%s%s",
						BRIGHT.Ink:ToHex(), tostring(mod.name), what, tostring(mod.rung or (rung and rung.name) or ""), oneIn, tagText)
					if mod.tag == "Lemonade" or mod.tag == "Chase" or mod.tag == "Great" then
						task.delay(0.3, function() if not c.retired then pulse(c.prefixScale, 1.3, 0.3) end end)
					end
				else
					c.gem.BackgroundColor3 = BRIGHT.Grey
					c.prefixText.Text = "No prefix"
				end
				popIn(c.prefixScale, 0.28)
			end)
			sparkBurst(c, best.rarity, impact.sparks)
			if r >= 3 then
				c.rays.Visible = true
				c.band.BackgroundTransparency = 0
				task.spawn(function()
					while not c.retired do
						c.band.Position = UDim2.new(0, -60, 0.5, 0)
						tween(c.band, 0.7, { Position = UDim2.new(1, 60, 0.5, 0) }, Enum.EasingStyle.Sine)
						task.wait(1.4)
					end
				end)
				task.spawn(function()
					while not c.retired do
						c.rays.Rotation = (c.rays.Rotation + RunService.RenderStepped:Wait() * 50) % 360
					end
				end)
			end
			if best.tag == "Chase" or best.tag == "Nice" then
				local stamp = frame(c.card, "Stamp", {
					-- sits in the header row's free right end, inside the card (the card never grows)
					AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, 18),
					Size = UDim2.fromOffset(best.ultra and 104 or ((best.tag == "Chase" or best.great) and 80 or 62), 24), Rotation = 6,
					BackgroundColor3 = best.tag == "Chase" and BRIGHT.Red or BRIGHT.Gold, ZIndex = 16,
				})
				PanelChrome.corner(stamp, 15)
				PanelChrome.stroke(stamp, BRIGHT.Outline, 2.5)
				local label = PanelChrome.display(stamp, { text = best.ultra and "JACKPOT!" or (best.tag == "Chase" and "CHASE!" or (best.great and "GREAT!" or "NICE!")), size = 16,
					stroke = 2, zIndex = 17 })
				label.Active = false
				local sc = Instance.new("UIScale")
				sc.Scale = 1.6
				sc.Parent = stamp
				task.delay(0.18, function() tween(sc, 0.22, { Scale = 1 }, Enum.EasingStyle.Back) end)
			end

			-- HOLD (a draining bar says how long), then OUT by itself.
			local hold = HOLD + impact.hold
			c.timerTrack.BackgroundTransparency = 0
			c.timerFill.BackgroundTransparency = 0
			c.timerFill.BackgroundColor3 = r >= 2 and tile.bottom or BRIGHT.GreyDark
			tween(c.timerFill, hold, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)
			task.wait(hold)
			retire(c, false)
		end)
	end

	-- ================================================================ MULTI-SPIN
	-- One press, several swords: the same card (quest width, never taller than the quest card)
	-- holds one row per sword. Every row reels through the real pool on its own phase; the rows
	-- land one after another, and the best pull (rarest rarity, then the longest odds) is held
	-- back and lands last with the whole card's celebration: its row lights up in its rarity, the
	-- card flashes and pulses, sparks fly off its tile and a BEST!/CHASE! stamp drops. Then the
	-- bar drains and the card slides away by itself. Nothing on it takes input.
	local MULTI_H = H -- same footprint as the single card: it keeps the corner slot clear of the quest card
	local MULTI_ROWS = 5 -- the most rows the card shows (a bigger batch lists its best five)
	local MULTI_HOLD = 3.4 -- seconds the landed batch stays up (more to read than a single pull)
	local MULTI_TOP, MULTI_FOOT, MULTI_GAP, MULTI_PAD = 29, 14, 3, 10

	local function pickBest(results)
		local best = results[1]
		for _, r in ipairs(results) do
			if rank(r.rarity) > rank(best.rarity) or (rank(r.rarity) == rank(best.rarity) and (r.p or 1) < (best.p or 1)) then
				best = r
			end
		end
		return best
	end

	local function buildMultiCard(n)
		local c = { rows = {} }
		c.card = frame(holder, "SpinPopupMulti", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2,
		})
		PanelChrome.corner(c.card, 18)
		PanelChrome.gradient(c.card, BRIGHT.Panel, BRIGHT.PanelBottom)
		c.outline = PanelChrome.stroke(c.card, BRIGHT.Outline, 3.5)
		c.scale = Instance.new("UIScale")
		c.scale.Parent = c.card
		c.header = text(c.card, "Header", {
			Position = UDim2.fromOffset(MULTI_PAD + 4, 7), Size = UDim2.fromOffset(W - 2 * MULTI_PAD - 92, 18),
			Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = BRIGHT.InkMuted,
			TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true, Text = "SPINNING", ZIndex = 6,
		})
		local fit = Instance.new("UITextSizeConstraint")
		fit.MaxTextSize = 15
		fit.MinTextSize = 10
		fit.Parent = c.header
		-- A count badge on the header's right end: x3 while spinning.
		c.countBadge = frame(c.card, "Count", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -MULTI_PAD, 0, 16), Size = UDim2.fromOffset(44, 22),
			BackgroundColor3 = BRIGHT.Gold, ZIndex = 7,
		})
		PanelChrome.corner(c.countBadge, 11)
		PanelChrome.stroke(c.countBadge, BRIGHT.Outline, 2.5)
		c.countText = PanelChrome.display(c.countBadge, { text = "x" .. n, size = 16, stroke = 2, zIndex = 8 })
		c.countText.Active = false

		local rowW = W - 2 * MULTI_PAD
		local rowH = math.floor((MULTI_H - MULTI_TOP - MULTI_FOOT - (n - 1) * MULTI_GAP) / n)
		local tileS = rowH - 4
		for i = 1, n do
			local row = {}
			local y = MULTI_TOP + (i - 1) * (rowH + MULTI_GAP)
			-- Each row sits in its own slot so it can pop (scale) without nudging its neighbours.
			row.slot = frame(c.card, "Row" .. i, {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, y + rowH / 2),
				Size = UDim2.fromOffset(rowW, rowH), BackgroundTransparency = 1, ZIndex = 5,
			})
			row.scale = Instance.new("UIScale")
			row.scale.Parent = row.slot
			row.bg = frame(row.slot, "Bg", {
				Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5, ClipsDescendants = true,
			})
			PanelChrome.corner(row.bg, 10)
			row.bgGradient = PanelChrome.gradient(row.bg, BRIGHT.Row, BRIGHT.Row)
			row.bgStroke = PanelChrome.stroke(row.bg, BRIGHT.RowStroke, 2)
			-- a light band that sweeps the best row (Rare and up)
			row.band = frame(row.bg, "Band", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, -40, 0.5, 0), Size = UDim2.new(0, 34, 2.4, 0),
				Rotation = 22, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 5,
			})
			local bandFade = Instance.new("UIGradient")
			bandFade.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 1),
			})
			bandFade.Parent = row.band
			-- mini sword tile
			row.tileSlot = frame(row.slot, "TileSlot", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(2 + tileS / 2, rowH / 2),
				Size = UDim2.fromOffset(tileS, tileS), BackgroundTransparency = 1, ZIndex = 6,
			})
			row.tileScale = Instance.new("UIScale")
			row.tileScale.Parent = row.tileSlot
			row.tile = frame(row.tileSlot, "Tile", {
				Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 6, ClipsDescendants = true,
			})
			PanelChrome.corner(row.tile, 8)
			row.tileGradient = PanelChrome.gradient(row.tile, tileOf("Common").top, tileOf("Common").bottom)
			row.tileGradient.Rotation = 70
			row.tileStroke = PanelChrome.stroke(row.tile, BRIGHT.Outline, 2)
			row.vp = Instance.new("ViewportFrame")
			row.vp.Name = "Sword"
			row.vp.BackgroundTransparency = 1
			row.vp.Size = UDim2.fromScale(1, 1)
			row.vp.ZIndex = 7
			row.vp.Active = false
			row.vp.ImageTransparency = 1
			row.vp.Parent = row.tile
			row.mark = PanelChrome.display(row.tile, { name = "Mark", text = "?", size = math.min(22, tileS - 6), stroke = 2,
				zIndex = 8 })
			row.mark.Active = false
			-- A little sword glyph stands in if the real render cannot be drawn (tinted on landing).
			row.glyph = frame(row.tile, "Glyph", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1, Rotation = 45, ZIndex = 8, Visible = false,
			})
			row.glyphBlade = frame(row.glyph, "Blade", {
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.1, 0), Size = UDim2.new(0.22, 0, 0.55, 0),
				BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 8,
			})
			PanelChrome.corner(row.glyphBlade, 2)
			PanelChrome.stroke(row.glyphBlade, BRIGHT.Outline, 1.5)
			row.glyphGuard = frame(row.glyph, "Guard", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.66, 0), Size = UDim2.new(0.56, 0, 0.14, 0),
				BackgroundColor3 = BRIGHT.Grey, ZIndex = 9,
			})
			PanelChrome.corner(row.glyphGuard, 2)
			PanelChrome.stroke(row.glyphGuard, BRIGHT.Outline, 1.5)
			local grip = frame(row.glyph, "Grip", {
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.72, 0), Size = UDim2.new(0.14, 0, 0.2, 0),
				BackgroundColor3 = Color3.fromRGB(122, 78, 48), ZIndex = 8,
			})
			PanelChrome.stroke(grip, BRIGHT.Outline, 1.5)
			-- name
			local nameX = 2 + tileS + 8
			row.name = PanelChrome.display(row.slot, { name = "SwordName", text = "? ? ?", size = math.min(18, rowH - 10),
				stroke = 2, xAlign = Enum.TextXAlignment.Left, scaled = true, minSize = 10, zIndex = 7,
				pos = UDim2.fromOffset(nameX, 1), size2 = UDim2.new(1, -(nameX + 86), 1, -2) })
			row.name.Active = false
			row.nameX = nameX
			-- rarity pill on the right end
			local pillH = math.min(22, rowH - 8)
			row.pill = frame(row.slot, "Rarity", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0), Size = UDim2.fromOffset(78, pillH),
				BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 7,
			})
			PanelChrome.corner(row.pill, pillH / 2)
			row.pillGradient = PanelChrome.gradient(row.pill, BRIGHT.Grey, BRIGHT.GreyDark)
			PanelChrome.stroke(row.pill, BRIGHT.Outline, 2)
			row.pillText = PanelChrome.display(row.pill, { name = "Text", text = "?", size = math.min(14, pillH - 6),
				stroke = 1.8, scaled = true, minSize = 9, zIndex = 8, pos = UDim2.fromOffset(5, 0),
				size2 = UDim2.new(1, -10, 1, 0) })
			row.pillText.Active = false
			row.pillScale = Instance.new("UIScale")
			row.pillScale.Parent = row.pill
			c.rows[i] = row
		end

		c.timerTrack = frame(c.card, "Timer", {
			Position = UDim2.fromOffset(MULTI_PAD + 4, MULTI_H - 10), Size = UDim2.fromOffset(W - 2 * MULTI_PAD - 8, 5),
			BackgroundColor3 = BRIGHT.Row, ZIndex = 6, BackgroundTransparency = 1,
		})
		PanelChrome.corner(c.timerTrack, 3)
		c.timerFill = frame(c.timerTrack, "Fill", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = BRIGHT.GreyDark, ZIndex = 7, BackgroundTransparency = 1,
		})
		PanelChrome.corner(c.timerFill, 3)
		c.flash = frame(c.card, "Flash", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 20,
		})
		PanelChrome.corner(c.flash, 18)
		return c
	end

	local function setPill(row, rarity)
		local t = tileOf(rarity)
		row.pillGradient.Color = ColorSequence.new(t.top, t.bottom)
		row.pillText.Text = string.upper(rarity)
		row.pillText.TextColor3 = rarity == "Common" and BRIGHT.Ink or Color3.new(1, 1, 1)
		local stroke = row.pillText:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color = rarity == "Common" and Color3.new(1, 1, 1) or BRIGHT.Outline end
	end

	local function rowSparks(c, row, rarity, count)
		local t = tileOf(rarity)
		local ts = row.tileSlot.AbsolutePosition
		local cs = c.card.AbsolutePosition
		local scale = holderScale.Scale > 0 and holderScale.Scale or 1
		local centre = (ts - cs) / scale + row.tileSlot.AbsoluteSize / (2 * scale)
		local cardH2 = MULTI_H
		for i = 1, count do
			local a = (i / count) * math.pi * 2 + math.random() * 0.5
			local dist = 26 + math.random() * 44
			local size = 6 + math.random() * 6
			local s = frame(c.card, "Spark", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(centre.X, centre.Y),
				Size = UDim2.fromOffset(size, size), Rotation = 45,
				BackgroundColor3 = (i % 3 == 0) and Color3.new(1, 1, 1) or t.bottom, ZIndex = 15,
			})
			PanelChrome.corner(s, 2)
			PanelChrome.stroke(s, BRIGHT.Outline, 1.5)
			local target = centre + Vector2.new(math.cos(a) * 1.6, math.sin(a) * 0.6) * dist
			target = Vector2.new(math.clamp(target.X, 8, W - 8), math.clamp(target.Y, 8, cardH2 - 8))
			local life = 0.45 + math.random() * 0.3
			tween(s, life, { Position = UDim2.fromOffset(target.X, target.Y), Rotation = 45 + math.random(-90, 90),
				Size = UDim2.fromOffset(2, 2) }, Enum.EasingStyle.Quart)
			task.delay(life, function() s:Destroy() end)
		end
	end

	showMulti = function(payload)
		local all = payload.results
		local best = pickBest(all)
		-- A batch bigger than the card lists its best rows (best first kept), in the order rolled.
		local shown = {}
		if #all <= MULTI_ROWS then
			shown = table.clone(all)
		else
			local sorted = table.clone(all)
			table.sort(sorted, function(a, b)
				if rank(a.rarity) ~= rank(b.rarity) then return rank(a.rarity) > rank(b.rarity) end
				return (a.p or 1) < (b.p or 1)
			end)
			local keep = {}
			for i = 1, MULTI_ROWS do keep[sorted[i]] = true end
			for _, r in ipairs(all) do
				if keep[r] then table.insert(shown, r) end
			end
		end
		local n = #shown
		local bestIndex = table.find(shown, best) or 1

		if current then retire(current, true) end
		cardH = MULTI_H
		holder.Size = UDim2.fromOffset(W, MULTI_H)
		place()
		local c = buildMultiCard(n)
		current = c
		holder.Visible = true
		local landAt = math.max(1.4, (tonumber(payload.seconds) or SpinPools.SPIN_SECONDS) - 0.2)

		-- IN
		c.card.Position = UDim2.new(0, W * 0.6, 0, 0)
		c.scale.Scale = 0.9
		tween(c.card, 0.3, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)
		tween(c.scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		-- Lucky Spins (gold upgrade): the server may add free bonus swords to a paid spin; say so.
		local bonusN = math.max(0, math.floor(tonumber(payload.bonus) or 0))
		c.header.Text = if bonusN > 0 then string.format("SPINNING %d  ·  +%d BONUS!", #all, bonusN)
			else string.format("SPINNING %d SWORDS ...", #all)

		-- Real renders: each row finds its own sword (backpack, or in hand if it was equipped at once);
		-- duplicates get distinct tools. A tool whose Handle has not replicated yet is retried.
		task.spawn(function()
			local used = {}
			local deadline = os.clock() + 6
			local pending = n
			local found = {}
			while pending > 0 and os.clock() < deadline and not c.retired do
				local tools = {}
				for _, holderInst in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
					if holderInst then
						for _, t in ipairs(holderInst:GetChildren()) do
							if t:IsA("Tool") then table.insert(tools, t) end
						end
					end
				end
				for i, r in ipairs(shown) do
					if not found[i] then
						for _, tool in ipairs(tools) do
							if not used[tool] and tool.Name == r.fullName and tool:FindFirstChild("Handle") then
								if PanelChrome.renderTool(c.rows[i].vp, tool, SWORD_POSE) then
									used[tool] = true
									found[i] = true
									pending -= 1
									c.rows[i].hasRender = true
									if c.rows[i].landed then
										c.rows[i].vp.ImageTransparency = 0
										c.rows[i].mark.Visible = false
										c.rows[i].glyph.Visible = false
									end
								end
								break
							end
						end
					end
				end
				if pending > 0 then task.wait(0.1) end
			end
		end)

		-- Land order: every other row first, top to bottom, then the best last.
		local order = {}
		for i = 1, n do
			if i ~= bestIndex then table.insert(order, i) end
		end
		local landTimes = {}
		local firstLand = landAt - 0.3 * (n - 1) - 0.25
		for k, i in ipairs(order) do
			landTimes[i] = math.max(0.9, firstLand + (k - 1) * 0.3)
		end
		landTimes[bestIndex] = landAt + 0.1

		-- The pool each row reels through: the real pool its own result rolled from.
		local function poolOf(r)
			local pool = {}
			for _, entry in ipairs(typeof(r.pool) == "table" and r.pool or {}) do
				if typeof(entry) == "table" and RARITY_TILE[entry.rarity] and entry.sword then table.insert(pool, entry) end
			end
			if #pool == 0 then pool = { { sword = r.sword or "?", rarity = r.rarity, p = r.p } } end
			return pool
		end

		local landed = 0
		local function landRow(i)
			local row, r = c.rows[i], shown[i]
			local isBest = i == bestIndex
			local t = tileOf(r.rarity)
			row.tileGradient.Color = ColorSequence.new(t.top, t.bottom)
			row.tileStroke.Color = BRIGHT.Outline
			row.landed = true
			if row.hasRender then
				row.vp.ImageTransparency = 0
				row.mark.Visible = false
			else
				-- the render swaps in the moment the sword replicates; until then a tinted glyph
				row.mark.Visible = false
				row.glyph.Visible = true
				row.glyphBlade.BackgroundColor3 = t.top:Lerp(Color3.new(1, 1, 1), 0.5)
				row.glyphGuard.BackgroundColor3 = t.rim
			end
			row.name.Position = UDim2.fromOffset(row.nameX, 1)
			row.name.TextTransparency = 0
			row.name.Text = r.fullName or r.sword or "?"
			setPill(row, r.rarity)
			row.bgGradient.Color = ColorSequence.new(t.top:Lerp(Color3.new(1, 1, 1), 0.72), t.bottom:Lerp(Color3.new(1, 1, 1), 0.6))
			row.bgStroke.Color = rank(r.rarity) >= 2 and t.bottom or BRIGHT.RowStroke
			popIn(row.pillScale, 0.26)
			pulse(row.tileScale, 1.25, 0.28)
			landed += 1
			if not isBest then
				pulse(row.scale, 1.06, 0.2)
				rowSparks(c, row, r.rarity, 4 + rank(r.rarity))
				AudioManager.PlayGlobal("reveal_tick")
				return
			end

			-- THE BEST: its row lights up in its rarity and the whole card celebrates.
			local rr = rank(r.rarity)
			row.bgGradient.Color = ColorSequence.new(t.top, t.bottom)
			row.bgStroke.Color = BRIGHT.Outline
			row.bgStroke.Thickness = 3
			row.slot.ZIndex = 9
			for _, d in ipairs(row.slot:GetDescendants()) do
				if d:IsA("GuiObject") then d.ZIndex += 4 end
			end
			row.scale.Scale = 1.16
			tween(row.scale, 0.4, { Scale = 1.03 }, Enum.EasingStyle.Back)
			-- the other rows step back a little so the best one reads first
			for j, other in ipairs(c.rows) do
				if j ~= i then
					tween(other.scale, 0.25, { Scale = 0.96 })
					tween(other.name, 0.25, { TextTransparency = 0.25 })
				end
			end
			c.flash.BackgroundTransparency = rr >= 4 and 0 or 0.45
			tween(c.flash, rr >= 4 and 0.22 or 0.16, { BackgroundTransparency = 1 }, Enum.EasingStyle.Linear)
			c.scale.Scale = rr >= 4 and 1.12 or 1.06
			tween(c.scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			rowSparks(c, row, r.rarity, 8 + rr * 3)
			AudioManager.PlayGlobal("reveal_land")
			if rr >= 4 then AudioManager.PlayGlobal("level_up") end
			if rr >= 3 then
				c.outline.Color = t.bottom
				task.spawn(function()
					for _ = 1, 3 do
						if c.retired then return end
						c.outline.Thickness = 8
						tween(c.outline, 0.22, { Thickness = 4 })
						task.wait(0.24)
					end
				end)
				row.band.BackgroundTransparency = 0
				task.spawn(function()
					while not c.retired do
						row.band.Position = UDim2.new(0, -40, 0.5, 0)
						tween(row.band, 0.6, { Position = UDim2.new(1, 40, 0.5, 0) }, Enum.EasingStyle.Sine)
						task.wait(1.3)
					end
				end)
			end
			-- Header: how many, and the best pull's real odds.
			c.header.Text = string.format("%d SWORDS  ·  BEST %s", #all, oddsText(r.p))
			c.header.TextColor3 = rr >= 2 and t.rim or BRIGHT.Ink
			-- Stamp over the count badge: CHASE! for the pool's chase, BEST! otherwise.
			local isChase = r.tag == "Chase"
			local stampColor = isChase and BRIGHT.Red or (r.tag == "Nice" and BRIGHT.Gold or t.bottom)
			c.countBadge.Size = UDim2.fromOffset(r.ultra and 104 or ((isChase or r.great) and 84 or 70), 24)
			c.countBadge.BackgroundColor3 = stampColor
			c.countBadge.Rotation = 6
			c.countText.Text = r.ultra and "JACKPOT!" or isChase and "CHASE!" or (r.great and "GREAT!" or (r.tag == "Nice" and "NICE!" or "BEST!"))
			local sc = Instance.new("UIScale")
			sc.Scale = 1.7
			sc.Parent = c.countBadge
			tween(sc, 0.24, { Scale = 1 }, Enum.EasingStyle.Back)
		end

		task.spawn(function()
			local start = os.clock()
			local pools, idx, nextAt, done = {}, {}, {}, {}
			for i, r in ipairs(shown) do
				pools[i] = poolOf(r)
				idx[i] = math.random(1, #pools[i])
				nextAt[i] = (i - 1) * 0.03
			end
			while not c.retired do
				local e = os.clock() - start
				local left = 0
				for i = 1, n do
					if not done[i] then
						if e >= landTimes[i] then
							done[i] = true
							landRow(i)
						else
							left += 1
							if e >= nextAt[i] then
								local row = c.rows[i]
								idx[i] = (idx[i] % #pools[i]) + 1
								local entry = pools[i][idx[i]]
								local t = tileOf(entry.rarity)
								row.tileGradient.Color = ColorSequence.new(t.top, t.bottom)
								row.name.Text = tostring(entry.sword)
								row.name.Position = UDim2.fromOffset(row.nameX, -7)
								row.name.TextTransparency = 0.45
								tween(row.name, 0.07, { Position = UDim2.fromOffset(row.nameX, 1), TextTransparency = 0 })
								pulse(row.tileScale, 1.08, 0.1)
								local slow = math.clamp(e / landTimes[i], 0, 1)
								nextAt[i] = e + FLICK_FAST + (FLICK_SLOW - FLICK_FAST) * slow * slow
							end
						end
					end
				end
				if left == 0 then break end
				RunService.RenderStepped:Wait()
			end
			if c.retired then return end
			-- HOLD, then OUT by itself.
			local bestTile = tileOf(best.rarity)
			c.timerTrack.BackgroundTransparency = 0
			c.timerFill.BackgroundTransparency = 0
			c.timerFill.BackgroundColor3 = rank(best.rarity) >= 2 and bestTile.bottom or BRIGHT.GreyDark
			tween(c.timerFill, MULTI_HOLD, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)
			task.wait(MULTI_HOLD)
			retire(c, false)
		end)
	end

	SPIN_ACTION.OnClientEvent:Connect(function(kind, payload)
		if kind == "Result" and typeof(payload) == "table" then
			if typeof(payload.results) == "table" and #payload.results >= 2 then
				showMulti(payload)
			else
				show(payload)
			end
		end
	end)

	print("[SpinPopup] top-right spin result popup live")
end

task.spawn(run)

return SpinPopup
