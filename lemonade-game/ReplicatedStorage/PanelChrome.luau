-- ReplicatedStorage/PanelChrome.luau
-- Shared visual chrome for modal GUI panels (Vault, Merchant, Quest, Main Menu):
-- a consistent bordered shell with a title banner and a close button, so every panel reads
-- as one system instead of five independently-styled ones. Returns plain
-- Instances -- works from imperative scripts (set .Parent yourself) and from Fusion (drop
-- PanelChrome.build(...).Frame straight into a [Children] table).
local PanelChrome = {}

-- Base palette (PS99 pass, docs/ART_DIRECTION.md): bright, rounded, bold-outlined. The old
-- charcoal-and-gold "fantasy gacha" set is gone; the same keys now map onto the bright chrome
-- below (BRIGHT), so every panel still drawing from COLORS lands in the one system:
-- white-to-pale-blue panel faces, a dark ink outline and ink text, a sky-blue button with a
-- deeper blue hover, and the accent trio (gold / tangerine "ember" / green / red) at full chroma.
PanelChrome.COLORS = {
	Panel = Color3.fromRGB(246, 249, 255), PanelLight = Color3.fromRGB(232, 238, 248), Dark = Color3.fromRGB(214, 225, 242),
	Stroke = Color3.fromRGB(30, 33, 48), StrokeBright = Color3.fromRGB(56, 62, 84), Gold = Color3.fromRGB(255, 212, 60),
	Text = Color3.fromRGB(30, 33, 48), Muted = Color3.fromRGB(128, 136, 158), Button = Color3.fromRGB(64, 170, 255),
	ButtonHover = Color3.fromRGB(30, 130, 240), Ember = Color3.fromRGB(255, 122, 48), Success = Color3.fromRGB(104, 222, 84),
	Error = Color3.fromRGB(240, 64, 74),
}

PanelChrome.RARITY_COLORS = {
	Common = Color3.fromRGB(196, 206, 224), Uncommon = Color3.fromRGB(70, 196, 72), Rare = Color3.fromRGB(48, 138, 246),
	Epic = Color3.fromRGB(150, 70, 232), Legendary = Color3.fromRGB(255, 200, 40),
}

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
	return c
end
PanelChrome.corner = corner

-- Builds a modal shell in the bright chrome: a white-to-pale-blue rounded face with a thick ink
-- outline, a chunky white-faced stroked title (plus an optional subtitle), an accent bar under the
-- header, and a red chunky close button. The frame is returned unparented -- parent it yourself,
-- or hand it to Fusion. Same return shape as before, so callers built on the dark shell keep
-- working: { Frame, TitleLabel, SubtitleLabel, CloseButton, HeaderBottom }.
--
-- props: { name, title, subtitle, accentColor, size, titleSize }
function PanelChrome.build(props)
	local bright = PanelChrome.BRIGHT
	local accent = props.accentColor or bright.Blue

	local modal = Instance.new("Frame")
	modal.Name = props.name or "Modal"
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = props.size or UDim2.fromOffset(800, 600)
	modal.BackgroundColor3 = Color3.new(1, 1, 1)
	modal.BorderSizePixel = 0
	corner(modal, 22)
	PanelChrome.gradient(modal, bright.Panel, bright.PanelBottom)
	PanelChrome.stroke(modal, bright.Outline, 4.5)

	local titleLabel = PanelChrome.display(modal, {
		name = "Title", text = props.title or "", size = props.titleSize or 34, stroke = 3.5,
		xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(22, 10), size2 = UDim2.new(1, -240, 0, 40),
	})

	local subtitleLabel
	if props.subtitle then
		subtitleLabel = Instance.new("TextLabel")
		subtitleLabel.Name = "Subtitle"
		subtitleLabel.BackgroundTransparency = 1
		subtitleLabel.Position = UDim2.fromOffset(24, 52)
		subtitleLabel.Size = UDim2.new(1, -240, 0, 20)
		subtitleLabel.Font = Enum.Font.GothamBold
		subtitleLabel.TextSize = 14
		subtitleLabel.TextColor3 = bright.InkMuted
		subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
		subtitleLabel.Text = props.subtitle
		subtitleLabel.Parent = modal
	end

	local headerBottom = props.subtitle and 82 or 60

	local divider = Instance.new("Frame")
	divider.Name = "HeaderDivider"
	divider.BackgroundColor3 = accent
	divider.BorderSizePixel = 0
	divider.Position = UDim2.fromOffset(22, headerBottom - 6)
	divider.Size = UDim2.new(1, -44, 0, 4)
	divider.Parent = modal
	corner(divider, 2)

	local closeBtn = PanelChrome.chunkyButton(modal, {
		name = "CloseButton", text = "X", color = bright.Red, colorDark = bright.RedDark,
		size = UDim2.fromOffset(44, 44), anchor = Vector2.new(1, 0), pos = UDim2.new(1, -14, 0, 10),
		textSize = 26, radius = 12, strokeThickness = 3,
	})

	return {
		Frame = modal,
		TitleLabel = titleLabel,
		SubtitleLabel = subtitleLabel,
		CloseButton = closeBtn,
		HeaderBottom = headerBottom, -- y-offset where panel-specific body content should start
	}
end

-- ═════════════════════════════════════════════════════════════════════════════
--  Bright chrome: light, chunky, thick-outlined panels (the look the Main Menu uses, and
--  since the PS99 pass the only look: build() above is drawn from this palette too).
-- ═════════════════════════════════════════════════════════════════════════════
PanelChrome.BRIGHT = {
	Panel = Color3.fromRGB(246, 249, 255), PanelBottom = Color3.fromRGB(214, 225, 242),
	Outline = Color3.fromRGB(30, 33, 48), Ink = Color3.fromRGB(56, 62, 84), InkMuted = Color3.fromRGB(128, 136, 158),
	Row = Color3.fromRGB(232, 238, 248), RowStroke = Color3.fromRGB(196, 206, 224), Slot = Color3.fromRGB(168, 178, 200),
	Red = Color3.fromRGB(240, 64, 74), RedDark = Color3.fromRGB(196, 30, 46),
	Green = Color3.fromRGB(104, 222, 84), GreenDark = Color3.fromRGB(46, 164, 52),
	Gold = Color3.fromRGB(255, 212, 60), GoldDark = Color3.fromRGB(236, 150, 20),
	Blue = Color3.fromRGB(64, 170, 255), Grey = Color3.fromRGB(196, 202, 214), GreyDark = Color3.fromRGB(150, 158, 174),
	Select = Color3.fromRGB(200, 232, 255),
}
local BRIGHT = PanelChrome.BRIGHT
PanelChrome.DISPLAY_FONT = Enum.Font.FredokaOne

-- Saturated tile colours per rarity: top/bottom of the fill gradient and a darker rim.
PanelChrome.RARITY_TILE = {
	Common = { top = Color3.fromRGB(255, 255, 255), bottom = Color3.fromRGB(164, 178, 202), rim = Color3.fromRGB(112, 124, 150) },
	Uncommon = { top = Color3.fromRGB(176, 246, 142), bottom = Color3.fromRGB(70, 196, 72), rim = Color3.fromRGB(28, 124, 42) },
	Rare = { top = Color3.fromRGB(150, 214, 255), bottom = Color3.fromRGB(48, 138, 246), rim = Color3.fromRGB(20, 78, 176) },
	Epic = { top = Color3.fromRGB(226, 170, 255), bottom = Color3.fromRGB(150, 70, 232), rim = Color3.fromRGB(88, 30, 150) },
	Legendary = { top = Color3.fromRGB(255, 238, 128), bottom = Color3.fromRGB(255, 166, 28), rim = Color3.fromRGB(176, 96, 8) },
}

function PanelChrome.stroke(inst, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or BRIGHT.Outline
	s.Thickness = thickness or 3
	s.Transparency = transparency or 0
	s.Parent = inst
	return s
end

function PanelChrome.gradient(inst, top, bottom)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = inst
	return g
end

-- Chunky display type: white rounded face with a heavy dark outline. Used for titles and
-- every number. props: { text, size, color, stroke, strokeColor, xAlign, scaled, minSize }
function PanelChrome.display(parent, props)
	local label = Instance.new("TextLabel")
	label.Name = props.name or "Display"
	label.BackgroundTransparency = 1
	label.Font = PanelChrome.DISPLAY_FONT
	label.Text = props.text or ""
	label.TextColor3 = props.color or Color3.new(1, 1, 1)
	label.TextSize = props.size or 20
	label.TextXAlignment = props.xAlign or Enum.TextXAlignment.Center
	label.TextYAlignment = props.yAlign or Enum.TextYAlignment.Center
	label.Size = props.size2 or UDim2.fromScale(1, 1)
	label.Position = props.pos or UDim2.fromOffset(0, 0)
	if props.anchor then label.AnchorPoint = props.anchor end
	if props.zIndex then label.ZIndex = props.zIndex end
	if props.scaled then
		label.TextScaled = true
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = props.size or 20
		c.MinTextSize = props.minSize or 9
		c.Parent = label
	end
	-- The outline is sized to the type, not fixed. A 2-2.5 px dark outline round 15-18 px letters
	-- fills the counters and the text turns to blobs -- the Relic Blacksmith's stat rows, "Return to
	-- Hub" (recording 2026-09-24). Small type gets a hairline, and dark ink gets none: an outline in
	-- the same dark as the letters only ever thickens them; the rule is for white display text.
	local size = props.size or 20
	local strokeWidth = props.stroke or 2.5
	local ink = props.color
	local darkInk = ink ~= nil and (0.299 * ink.R + 0.587 * ink.G + 0.114 * ink.B) < 0.5
		and props.strokeColor == nil
	if darkInk then
		strokeWidth = 0
	elseif size <= 18 then
		strokeWidth = math.min(strokeWidth, 1)
	elseif size < 24 then
		strokeWidth = math.min(strokeWidth, 1.5)
	end
	-- Always created (callers reach for label:FindFirstChildOfClass("UIStroke") to recolour it),
	-- only switched off when the rule above says none.
	local s = PanelChrome.stroke(label, props.strokeColor or BRIGHT.Outline, math.max(strokeWidth, 1))
	if s and strokeWidth <= 0 then s.Enabled = false end
	label.Parent = parent
	return label
end

-- Red notification pill with a stroked white count; parent it to the top-right of a button.
function PanelChrome.countBadge(parent, text, zIndex)
	local badge = Instance.new("Frame")
	badge.Name = "CountBadge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -6, 0, 6)
	badge.Size = UDim2.fromOffset(28, 26)
	badge.AutomaticSize = Enum.AutomaticSize.X
	badge.BackgroundColor3 = BRIGHT.Red
	badge.ZIndex = zIndex or 5
	badge.Parent = parent
	corner(badge, 13)
	PanelChrome.stroke(badge, Color3.new(1, 1, 1), 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = badge
	local label = PanelChrome.display(badge, { text = text, size = 16, stroke = 1.5, zIndex = (zIndex or 5) + 1 })
	label.Size = UDim2.fromScale(0, 1)
	label.AutomaticSize = Enum.AutomaticSize.X
	return badge, label
end

-- Green round "equipped" badge with a checkmark drawn from two rotated bars.
function PanelChrome.checkBadge(parent, diameter, zIndex)
	local d = diameter or 30
	local badge = Instance.new("Frame")
	badge.Name = "CheckBadge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Size = UDim2.fromOffset(d, d)
	badge.BackgroundColor3 = BRIGHT.Green
	badge.ZIndex = zIndex or 5
	badge.Parent = parent
	corner(badge, d)
	PanelChrome.stroke(badge, BRIGHT.Outline, 2.5)
	PanelChrome.gradient(badge, Color3.fromRGB(150, 240, 120), BRIGHT.GreenDark)
	local function bar(len, cx, cy, rot)
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromScale(cx, cy)
		b.Size = UDim2.new(len, 0, 0.16, 0)
		b.Rotation = rot
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.BorderSizePixel = 0
		b.ZIndex = (zIndex or 5) + 1
		b.Parent = badge
		corner(b, 4)
		return b
	end
	bar(0.34, 0.36, 0.58, 45)
	bar(0.56, 0.58, 0.48, -50)
	return badge
end

-- Big rounded button with a gradient face, heavy outline and stroked display label.
-- props: { name, text, color, colorDark, size, pos, anchor, textSize, zIndex }
function PanelChrome.chunkyButton(parent, props)
	local btn = Instance.new("TextButton")
	btn.Name = props.name or "ChunkyButton"
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = Color3.new(1, 1, 1)
	btn.Size = props.size or UDim2.fromOffset(160, 56)
	btn.Position = props.pos or UDim2.fromOffset(0, 0)
	if props.anchor then btn.AnchorPoint = props.anchor end
	btn.ZIndex = props.zIndex or 3
	btn.Parent = parent
	corner(btn, props.radius or 14)
	PanelChrome.stroke(btn, BRIGHT.Outline, props.strokeThickness or 3)
	local grad = PanelChrome.gradient(btn, props.color or BRIGHT.Green, props.colorDark or BRIGHT.GreenDark)
	-- A soft top highlight gives the face the glossy bevel of rendered buttons.
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.72
	shine.BorderSizePixel = 0
	shine.Position = UDim2.new(0, 5, 0, 4)
	shine.Size = UDim2.new(1, -10, 0.36, 0)
	shine.ZIndex = btn.ZIndex
	shine.Parent = btn
	corner(shine, 10)
	local label = PanelChrome.display(btn, { text = props.text or "", size = props.textSize or 24, stroke = 2.5, scaled = true, minSize = 12, zIndex = btn.ZIndex + 1 })
	label.Name = "Label"
	label.Size = UDim2.new(1, -12, 1, -6)
	label.Position = UDim2.fromOffset(6, 3)
	PanelChrome.pressFeedback(btn)
	return btn, label, grad
end

-- Fills a square tile with its rarity's saturated gradient and thick darker rim.
function PanelChrome.rarityTile(frame, rarity)
	local t = PanelChrome.RARITY_TILE[rarity] or PanelChrome.RARITY_TILE.Common
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	PanelChrome.gradient(frame, t.top, t.bottom)
	return PanelChrome.stroke(frame, t.rim, 3.5), t
end

-- Owned-loot card face: the rarity gradient under a thick dark outline, a rarity-coloured
-- ring just inside it, a soft light glow where the item sits and a diagonal gloss. Returns
-- the outer stroke (callers restyle it for selection) and the rarity colours.
-- props: { radius, zIndex, glowY }
function PanelChrome.lootTile(frame, rarity, props)
	props = props or {}
	local t = PanelChrome.RARITY_TILE[rarity] or PanelChrome.RARITY_TILE.Common
	local r = props.radius or 18
	local z = props.zIndex or frame.ZIndex
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	local g = PanelChrome.gradient(frame, t.top, t.bottom)
	g.Rotation = 70
	local outline = PanelChrome.stroke(frame, BRIGHT.Outline, 3.5)

	local ring = Instance.new("Frame")
	ring.Name = "RarityRing"
	ring.BackgroundTransparency = 1
	ring.Position = UDim2.fromOffset(3, 3)
	ring.Size = UDim2.new(1, -6, 1, -6)
	ring.ZIndex = z
	ring.Parent = frame
	corner(ring, r - 3)
	PanelChrome.stroke(ring, t.rim, 3)

	-- Soft glow: stacked translucent white discs read as a radial light behind the item.
	for i, spec in ipairs({ { 0.86, 0.72 }, { 0.62, 0.55 }, { 0.38, 0.4 } }) do
		local disc = Instance.new("Frame")
		disc.Name = "Glow" .. i
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.fromScale(0.5, props.glowY or 0.44)
		disc.Size = UDim2.fromScale(spec[1], spec[1])
		disc.BackgroundColor3 = Color3.new(1, 1, 1)
		disc.BackgroundTransparency = spec[2]
		disc.BorderSizePixel = 0
		disc.ZIndex = z
		disc.Parent = frame
		corner(disc, 999)
	end

	-- Glossy band across the top, like the bevel on rendered item art.
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.55
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromOffset(7, 6)
	shine.Size = UDim2.new(1, -14, 0.22, 0)
	shine.ZIndex = z
	shine.Parent = frame
	corner(shine, r - 6)
	local sg = Instance.new("UIGradient")
	sg.Transparency = NumberSequence.new(0, 1)
	sg.Rotation = 90
	sg.Parent = shine
	return outline, t
end

-- Empty inventory slot: a quiet recessed well a few shades darker than the panel, with a
-- rounded inner shadow along the top. No icon, no border.
function PanelChrome.emptyWell(frame, props)
	props = props or {}
	local r = props.radius or 18
	local z = props.zIndex or frame.ZIndex
	frame.BackgroundColor3 = props.color or Color3.fromRGB(212, 222, 240)
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	corner(frame, r)
	local rim = PanelChrome.stroke(frame, Color3.fromRGB(190, 202, 226), 1.5)
	pcall(function() rim.BorderStrokePosition = Enum.BorderStrokePosition.Inner end)

	local shadow = Instance.new("Frame")
	shadow.Name = "InnerShadow"
	shadow.BackgroundColor3 = Color3.fromRGB(120, 136, 172)
	shadow.BorderSizePixel = 0
	shadow.Size = UDim2.new(1, 0, 0.42, 0)
	shadow.ZIndex = z
	shadow.Parent = frame
	corner(shadow, r)
	local sg = Instance.new("UIGradient")
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.25, 0.86),
		NumberSequenceKeypoint.new(1, 1),
	})
	sg.Rotation = 90
	sg.Parent = shadow

	return frame
end

-- Soft diagonal stripe texture laid over a frame: one UIGradient whose transparency
-- alternates, so it needs no image asset and never escapes the frame's rounded corners.
-- props: { color, alpha (strongest stripe transparency), bands, rotation, radius, zIndex }
function PanelChrome.stripes(parent, props)
	props = props or {}
	local overlay = Instance.new("Frame")
	overlay.Name = "Stripes"
	overlay.BackgroundColor3 = props.color or Color3.new(1, 1, 1)
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = props.zIndex or parent.ZIndex
	overlay.Parent = parent
	if props.radius then corner(overlay, props.radius) end
	local bands = math.clamp(props.bands or 9, 2, 9)
	local alpha = props.alpha or 0.88
	local keys = {}
	local n = bands * 2
	for i = 0, n do
		table.insert(keys, NumberSequenceKeypoint.new(i / n, i % 2 == 0 and alpha or 1))
	end
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new(keys)
	g.Rotation = props.rotation or 20
	g.Parent = overlay
	return overlay
end

-- Recessed tray that item grids sit in: a darker fill than its panel, a heavy outline, a soft
-- inner shadow under the top lip, a faint highlight along the bottom and a stripe texture.
-- props: { top, bottom, radius, zIndex, stripes }
function PanelChrome.insetTray(frame, props)
	props = props or {}
	local r = props.radius or 18
	local z = props.zIndex or frame.ZIndex
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	corner(frame, r)
	PanelChrome.gradient(frame, props.top or Color3.fromRGB(78, 88, 118), props.bottom or Color3.fromRGB(50, 56, 80))
	PanelChrome.stroke(frame, BRIGHT.Outline, props.strokeThickness or 3.5)
	if props.stripes ~= false then
		PanelChrome.stripes(frame, { alpha = 0.93, bands = 9, rotation = 25, radius = r, zIndex = z })
	end
	local shadow = Instance.new("Frame")
	shadow.Name = "InnerShadow"
	shadow.BackgroundColor3 = Color3.fromRGB(10, 12, 22)
	shadow.BorderSizePixel = 0
	shadow.Size = UDim2.new(1, 0, 0, 34)
	shadow.ZIndex = z
	shadow.Parent = frame
	corner(shadow, r)
	local sg = Instance.new("UIGradient")
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.35, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	sg.Rotation = 90
	sg.Parent = shadow
	local lip = Instance.new("Frame")
	lip.Name = "BottomLight"
	lip.AnchorPoint = Vector2.new(0.5, 1)
	lip.Position = UDim2.new(0.5, 0, 1, -2)
	lip.Size = UDim2.new(1, -2 * r, 0, 2)
	lip.BackgroundColor3 = Color3.new(1, 1, 1)
	lip.BackgroundTransparency = 0.75
	lip.BorderSizePixel = 0
	lip.ZIndex = z
	lip.Parent = frame
	return frame
end

-- A dashed rounded-square outline built from Frames (Roblox has no dashed stroke), for
-- "empty slot" placeholders. Straight dashes run along each side; each corner is a quarter
-- ring clipped out of a stroked circle.
function PanelChrome.dashedOutline(parent, props)
	props = props or {}
	local color = props.color or BRIGHT.Slot
	local thick = props.thickness or 3
	local r = props.radius or 16
	local dash, gap = props.dash or 9, props.gap or 7
	local z = props.zIndex or 2
	local holder = Instance.new("Frame")
	holder.Name = "DashedOutline"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = z
	holder.Parent = parent
	local function seg(pos, size)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.Position = pos
		f.Size = size
		f.ZIndex = z
		f.Parent = holder
		corner(f, 2)
	end
	-- Dashes are laid out in scale along each straight run (r .. size - r), so they hold at
	-- any tile size: a dash starting at fraction a of the run sits at a*size + r - 2r*a.
	local n = props.dashes or 4
	local unit = 1 / (n * (dash + gap) - gap)
	for i = 0, n - 1 do
		local a = i * (dash + gap) * unit
		local len = dash * unit
		seg(UDim2.new(0, r, 0, 0) + UDim2.new(a, -2 * r * a, 0, 0), UDim2.new(len, -2 * r * len, 0, thick))
		seg(UDim2.new(0, r, 1, -thick) + UDim2.new(a, -2 * r * a, 0, 0), UDim2.new(len, -2 * r * len, 0, thick))
		seg(UDim2.new(0, 0, 0, r) + UDim2.new(0, 0, a, -2 * r * a), UDim2.new(0, thick, len, -2 * r * len))
		seg(UDim2.new(1, -thick, 0, r) + UDim2.new(0, 0, a, -2 * r * a), UDim2.new(0, thick, len, -2 * r * len))
	end
	for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		local clip = Instance.new("Frame")
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.AnchorPoint = Vector2.new(c[1], c[2])
		clip.Position = UDim2.fromScale(c[1], c[2])
		clip.Size = UDim2.fromOffset(r - 3, r - 3)
		clip.ZIndex = z
		clip.Parent = holder
		local ring = Instance.new("Frame")
		ring.BackgroundTransparency = 1
		ring.AnchorPoint = Vector2.new(c[1], c[2])
		ring.Position = UDim2.fromScale(c[1], c[2])
		ring.Size = UDim2.fromOffset(2 * r, 2 * r)
		ring.ZIndex = z
		ring.Parent = clip
		corner(ring, r)
		local s = PanelChrome.stroke(ring, color, thick)
		pcall(function() s.BorderStrokePosition = Enum.BorderStrokePosition.Inner end)
	end
	return holder
end

-- Renders a Tool as a 3D icon inside a ViewportFrame. Every sword's blade runs along its
-- Handle's local -Z with the flat facing +-Y, so posing the Handle to a fixed orientation
-- gives a consistent icon. tiltDeg leans the blade (45 = the classic diagonal item icon).
local ICON_POSE = CFrame.Angles(math.pi / 2, 0, 0)
function PanelChrome.renderTool(viewport, tool, opts)
	opts = opts or {}
	for _, child in ipairs(viewport:GetChildren()) do child:Destroy() end
	viewport.Ambient = opts.ambient or Color3.fromRGB(200, 200, 212)
	viewport.LightColor = Color3.fromRGB(255, 252, 240)
	viewport.LightDirection = Vector3.new(-1, -1.4, -0.9)
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local ok, copy = pcall(function() return tool:Clone() end)
	if not ok or not copy then return false end
	-- Strip anything that could run or interfere inside the viewport copy (before parenting).
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Light") then
			d:Destroy()
		end
	end
	local handle = copy:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then
		copy:Destroy()
		return false
	end
	-- rollDeg (default 0) turns the sword about its own blade axis, for a caller that wants to
	-- show a blade whose flat faces the Handle's local X rather than Y.
	local pose = CFrame.Angles(0, math.rad(opts.yawDeg or 18), 0) * CFrame.Angles(0, 0, math.rad(-(opts.tiltDeg or 45))) * ICON_POSE
		* CFrame.Angles(0, 0, math.rad(opts.rollDeg or 0))
	-- A sword mesh has its tip at its own +Z (BossSwordFactory.meshGrip), the block sword along -Z;
	-- turn a mesh end for end so every icon points its tip the same way, up and to the right.
	if handle:IsA("MeshPart") then
		pose *= CFrame.Angles(0, math.pi, 0)
	end
	-- Welded parts are placed from their weld's C0/C1: a freshly equipped sword may not have
	-- had its welds simulated yet, so its current CFrames can't be trusted.
	local transform = pose * handle.CFrame:Inverse()
	local weldedPose = {}
	local attached = { [handle] = true }
	for _, weld in ipairs(copy:GetDescendants()) do
		if weld:IsA("Weld") and weld.Part0 == handle and weld.Part1 then
			weldedPose[weld.Part1] = pose * weld.C0 * weld.C1:Inverse()
		end
		if (weld:IsA("JointInstance") or weld:IsA("WeldConstraint")) and (weld.Part0 == handle or weld.Part1 == handle) then
			if weld.Part0 then attached[weld.Part0] = true end
			if weld.Part1 then attached[weld.Part1] = true end
		end
	end
	-- A boss sword swaps the template's block Handle for one whole-sword mesh, which leaves the
	-- template's blade/guard parts behind with no joint and stale positions. They are not part
	-- of the sword and would blow up the framing, so only parts joined to the Handle are drawn.
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BasePart") and not attached[part] then part:Destroy() end
	end
	local minV, maxV
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CFrame = if part == handle then pose else (weldedPose[part] or transform * part.CFrame)
			part.Anchored = true
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
	end
	copy.Parent = world
	if not minV then return false end
	local fov = 30
	local centre, size = (minV + maxV) / 2, maxV - minV
	local fit = math.max(size.X, size.Y) * 0.5 * (opts.margin or 1.08)
	local distance = fit / math.tan(math.rad(fov / 2)) + size.Z / 2
	camera.FieldOfView = fov
	camera.CFrame = CFrame.lookAt(centre + Vector3.new(0, 0, distance), centre)
	return true
end

-- Light, thick-outlined modal shell: a title that sits over the top-left edge beside an icon
-- badge, and a red rounded-square close button overlapping the top-right corner.
-- props: { name, title, icon, size, titleSize, closeSize }
function PanelChrome.buildBright(props)
	local modal = Instance.new("Frame")
	modal.Name = props.name or "Modal"
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = props.size or UDim2.fromOffset(640, 520)
	modal.BackgroundColor3 = Color3.new(1, 1, 1)
	modal.BorderSizePixel = 0
	corner(modal, 22)
	PanelChrome.gradient(modal, BRIGHT.Panel, BRIGHT.PanelBottom)
	PanelChrome.stroke(modal, BRIGHT.Outline, 4.5)

	local iconBadge = Instance.new("ImageLabel")
	iconBadge.Name = "TitleIcon"
	iconBadge.AnchorPoint = Vector2.new(0, 0.5)
	iconBadge.Position = UDim2.fromOffset(-18, -2)
	iconBadge.Size = UDim2.fromOffset(78, 78)
	iconBadge.BackgroundTransparency = 1
	iconBadge.Image = props.icon or ""
	iconBadge.ScaleType = Enum.ScaleType.Fit
	iconBadge.Rotation = -8
	iconBadge.ZIndex = 8
	iconBadge.Parent = modal

	local title = PanelChrome.display(modal, {
		name = "Title", text = props.title or "", size = props.titleSize or 46, stroke = 4,
		xAlign = Enum.TextXAlignment.Left, anchor = Vector2.new(0, 0.5),
		pos = UDim2.fromOffset(66, -4), size2 = UDim2.new(0.62, 0, 0, 58), zIndex = 8,
	})
	title.TextScaled = true
	local tc = Instance.new("UITextSizeConstraint")
	tc.MaxTextSize = props.titleSize or 46
	tc.MinTextSize = 20
	tc.Parent = title

	local closeSize = props.closeSize or 56
	local closeBtn = PanelChrome.chunkyButton(modal, {
		name = "CloseButton", text = "X", color = BRIGHT.Red, colorDark = BRIGHT.RedDark,
		size = UDim2.fromOffset(closeSize, closeSize), anchor = Vector2.new(0.5, 0.5),
		pos = UDim2.new(1, -24, 0, 2), textSize = 36, zIndex = 9, radius = 14, strokeThickness = 3.5,
	})
	closeBtn.Rotation = 0

	return { Frame = modal, TitleLabel = title, TitleIcon = iconBadge, CloseButton = closeBtn }
end

-- ═════════════════════════════════════════════════════════════════════════════
--  Always-on HUD layout, shared by LevelProgressGui (vitals) and MainMenuGui (gold readout
--  and side buttons) so the bottom-left stack and the right button column scale together.
-- ═════════════════════════════════════════════════════════════════════════════
PanelChrome.HUD = {
	Margin = 14, -- screen-edge gutter, in unscaled pixels
	VitalsWidth = 430, -- design-space footprint of the health/XP cluster
	VitalsHeight = 134,
	GoldHeight = 66, -- the gold readout that sits on top of the vitals
	TokenHeight = 100, -- the spin-token readout (about 1.5x the gold row: the currency a kill pays) that sits on top of the gold (TokenDrops.client)
	HotbarLift = 28, -- gap under the bottom-centre sword hotbar slot, in pixels (not scaled); its drop
	-- shadow and equipped ring hang ~11 px below the tile, so this leaves ~16 px of clear screen edge
	HotbarSize = 120, -- design-space side of the hotbar slot; it scales with hudScale
	HotbarClear = 168, -- lift over the hotbar at full scale (28 lift + 120 slot + badges + gap)
	QuestWidth = 324, -- design-space width of the right-edge quest tracker card (QuestGui)
	QuestTabWidth = 236, -- design-space size of the quest card folded to its compact tab (QuestGui's
	QuestTabHeight = 60, -- minimize button): quest name over a mini progress bar
	PopupHeight = 136, -- design-space height of the top-right spin result popup (SpinPopup): never
	-- wider than the quest card, and never taller than it is at its smallest (~150 px)
	PopupGap = 12, -- design-space gap between the spin popup and the quest card it stacks on
}

-- One UIScale value for every HUD element: 1 on a desktop window, shrinking on phones but
-- never below 0.65, so a 70 px side button still stays a 45 px tap target.
function PanelChrome.hudScale(viewport: Vector2): number
	return math.clamp(math.min(viewport.X / 1100, viewport.Y / 700), 0.65, 1)
end

-- Distance from the screen bottom to the bottom of the vitals cluster. On narrow screens the
-- cluster would run under the centred hotbar, so it lifts clear of it.
function PanelChrome.hudVitalsBottom(viewport: Vector2): number
	local HUD = PanelChrome.HUD
	local s = PanelChrome.hudScale(viewport)
	local right = HUD.Margin + HUD.VitalsWidth * s
	if right > viewport.X / 2 - (HUD.HotbarSize / 2 + 8) * s then
		-- The slot scales with the HUD, so clear its scaled height (HotbarClear at full size).
		return math.ceil(HUD.HotbarLift + (HUD.HotbarClear - HUD.HotbarLift) * s)
	end
	return HUD.Margin
end

-- Distance from the screen bottom to the top of the whole bottom-left stack (vitals, then the
-- gold readout, then the token readout). Anything else that lives bottom-left, such as MapClient's Return to Hub
-- button, stacks above this so the HUD can grow without covering it.
function PanelChrome.hudStackTop(viewport: Vector2): number
	local HUD = PanelChrome.HUD
	local s = PanelChrome.hudScale(viewport)
	return PanelChrome.hudVitalsBottom(viewport) + (HUD.VitalsHeight + HUD.GoldHeight + HUD.TokenHeight) * s + 2
end

-- Calls fn(viewport) now and whenever the camera's viewport changes size.
function PanelChrome.onViewport(fn: (Vector2) -> ())
	local connection
	local function bind()
		if connection then connection:Disconnect() end
		local camera = workspace.CurrentCamera
		if not camera then return end
		connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			fn(camera.ViewportSize)
		end)
		fn(camera.ViewportSize)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bind)
	bind()
end

-- ═════════════════════════════════════════════════════════════════════════════
--  Panel open / close motion, shared by every modal window so they all move the same way.
--
--  Open: the window grows from 0.88 to a 1.03 peak at 130 ms and settles to 1.0 by 200 ms,
--  rising 12 px into place and fading up over 120 ms while the backdrop dims in parallel.
--  Its tiles then land row by row, 22 ms apart, each a 120 ms fade and a 0.92 -> 1.0 grow,
--  so the whole open is done in about a quarter second. Close is a quick 110 ms shrink-fade.
--
--  Every value animates relative to its rest value. If other code writes a property while a
--  motion runs (a tab switch selecting a rail button, a viewport resize refitting the window),
--  that write becomes the new rest value, so the motion never undoes it when it finishes.
-- ═════════════════════════════════════════════════════════════════════════════
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

PanelChrome.MOTION = { -- [TUNING] seconds and scale factors
	OpenFrom = 0.88, Peak = 1.03, PeakAt = 0.13, SettleBy = 0.20,
	Rise = 12, RiseTime = 0.18, FadeTime = 0.12, DimTime = 0.12,
	TileDelay = 0.05, TileRowStep = 0.022, TileTime = 0.12, TileFrom = 0.92, TileMaxRows = 6,
	CloseTime = 0.11, CloseTo = 0.94, CloseDrop = 8,
}

local TEXT_FADE = { "BackgroundTransparency", "TextTransparency", "TextStrokeTransparency" }
local IMAGE_FADE = { "BackgroundTransparency", "ImageTransparency" }
local FADE_PROPS = {
	Frame = { "BackgroundTransparency" },
	ScrollingFrame = { "BackgroundTransparency", "ScrollBarImageTransparency" },
	TextLabel = TEXT_FADE, TextButton = TEXT_FADE, TextBox = TEXT_FADE,
	ImageLabel = IMAGE_FADE, ImageButton = IMAGE_FADE, ViewportFrame = IMAGE_FADE,
	UIStroke = { "Transparency" },
}

local function ease(a: number, style: Enum.EasingStyle, dir: Enum.EasingDirection): number
	return TweenService:GetValue(math.clamp(a, 0, 1), style, dir)
end
local function quadOut(a) return ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
local function quadIn(a) return ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end

-- A track drives one property relative to its rest value.
local function newTrack(inst: Instance, prop: string, rest: any?)
	return { inst = inst, prop = prop, rest = if rest ~= nil then rest else (inst :: any)[prop], last = nil }
end
local function same(a, b)
	if type(a) == "number" and type(b) == "number" then return math.abs(a - b) < 1e-3 end
	return a == b
end
local function drive(tr, f)
	local inst = tr.inst :: any
	local cur = inst[tr.prop]
	if tr.last ~= nil and not same(cur, tr.last) then tr.rest = cur end -- adopt an outside write
	local v = f(tr.rest)
	inst[tr.prop] = v
	tr.last = v
end
local function settle(tr)
	local inst = tr.inst :: any
	if tr.last == nil or same(inst[tr.prop], tr.last) then inst[tr.prop] = tr.rest end
	tr.last = nil
end
local function fadeTo(tr, visible: number) -- visible: 0 = invisible, 1 = at rest
	drive(tr, function(rest) return 1 - (1 - rest) * visible end)
end

local function collectFades(root: Instance, out, skip)
	local function add(inst)
		if skip and skip[inst] then return end
		local props = FADE_PROPS[inst.ClassName]
		if not props then return end
		for _, p in ipairs(props) do
			if (inst :: any)[p] < 0.999 then table.insert(out, newTrack(inst, p)) end
		end
	end
	add(root)
	for _, d in ipairs(root:GetDescendants()) do add(d) end
end

local motions = setmetatable({}, { __mode = "k" }) -- [frame] = running motion

local function stopMotion(frame)
	local st = motions[frame]
	if not st then return nil end
	motions[frame] = nil
	if st.conn then st.conn:Disconnect() end
	st.settleAll()
	return st.kind
end

local function runMotion(frame, st, duration: number, step: (number) -> ())
	local t0 = os.clock()
	step(0)
	st.conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t < duration then
			step(t)
			return
		end
		st.conn:Disconnect()
		st.conn = nil
		if motions[frame] == st then motions[frame] = nil end
		step(duration)
		if st.onDone then st.onDone() end
		st.settleAll()
	end)
end

-- The window's scale over the open, as a factor of its rest scale: a quick grow that
-- overshoots to Peak, then an ease back to rest.
local function openScaleAt(t: number): number
	local M = PanelChrome.MOTION
	if t < M.PeakAt then
		return M.OpenFrom + (M.Peak - M.OpenFrom) * quadOut(t / M.PeakAt)
	elseif t < M.SettleBy then
		local a = ease((t - M.PeakAt) / (M.SettleBy - M.PeakAt), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		return M.Peak + (1 - M.Peak) * a
	end
	return 1
end

local function tilesOf(container: Instance): { GuiObject }
	local list = {}
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then table.insert(list, child) end
	end
	return list
end

-- opts: {
--   frame: GuiObject      the window that grows, rises and fades (its whole subtree fades)
--   scale: UIScale?       the window's UIScale (its current Scale is the rest scale)
--   dim: GuiObject?       backdrop whose BackgroundTransparency fades from 1 to dimTo
--   dimTo: number?        the backdrop's rest transparency (default 0.5)
--   tiles: (() -> {Instance})?   containers whose visible children land row by row
-- }
-- Call it after making the window visible. The start pose is set now; the fade and tile
-- stagger start once the caller's content for this frame has been built.
function PanelChrome.openMotion(opts)
	local M = PanelChrome.MOTION
	local frame = opts.frame
	stopMotion(frame)
	local scaleTr = opts.scale and newTrack(opts.scale, "Scale")
	local posTr = newTrack(frame, "Position")
	local dimTr = opts.dim and newTrack(opts.dim, "BackgroundTransparency", opts.dimTo or 0.5)
	local rise = math.floor(M.Rise * math.clamp(scaleTr and scaleTr.rest or 1, 0.6, 1.2) + 0.5)
	local function pose(t)
		if scaleTr then drive(scaleTr, function(rest) return rest * openScaleAt(t) end) end
		drive(posTr, function(rest)
			local dy = math.floor(rise * (1 - ease(t / M.RiseTime, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)) + 0.5)
			return rest + UDim2.fromOffset(0, dy)
		end)
		if dimTr then fadeTo(dimTr, quadOut(t / M.DimTime)) end
	end
	local st = { kind = "open" }
	local fades, tiles = {}, {}
	st.settleAll = function()
		if scaleTr then settle(scaleTr) end
		settle(posTr)
		if dimTr then settle(dimTr) end
		for _, tr in ipairs(fades) do settle(tr) end
		for _, tile in ipairs(tiles) do
			settle(tile.scale)
			for _, tr in ipairs(tile.fades) do settle(tr) end
			if tile.made then tile.made:Destroy() end
		end
	end
	motions[frame] = st
	pose(0)

	task.defer(function()
		if motions[frame] ~= st then return end
		-- Tiles, grouped into rows by their on-screen position. Each container counts its own
		-- rows, so a side rail cascades alongside a grid instead of slowing it down.
		local skip = {}
		for _, container in ipairs(opts.tiles and opts.tiles() or {}) do
			local found = tilesOf(container)
			table.sort(found, function(a, b)
				if math.abs(a.AbsolutePosition.Y - b.AbsolutePosition.Y) > 4 then
					return a.AbsolutePosition.Y < b.AbsolutePosition.Y
				end
				return a.AbsolutePosition.X < b.AbsolutePosition.X
			end)
			local row, lastY = 0, nil
			for _, gui in ipairs(found) do
				local y = gui.AbsolutePosition.Y
				if lastY and y - lastY > 4 then row += 1 end
				lastY = y
				local uiScale = gui:FindFirstChildOfClass("UIScale")
				local made = nil
				if not uiScale then
					made = Instance.new("UIScale")
					made.Name = "OpenScale"
					made.Parent = gui
					uiScale = made
				end
				local tile = { scale = newTrack(uiScale, "Scale"), fades = {}, made = made, delay = M.TileDelay + math.min(row, M.TileMaxRows - 1) * M.TileRowStep }
				collectFades(gui, tile.fades)
				skip[gui] = true
				for _, d in ipairs(gui:GetDescendants()) do skip[d] = true end
				table.insert(tiles, tile)
			end
		end
		collectFades(frame, fades, skip)

		local duration = math.max(M.SettleBy, M.FadeTime, M.DimTime, M.RiseTime)
		for _, tile in ipairs(tiles) do duration = math.max(duration, tile.delay + M.TileTime) end
		runMotion(frame, st, duration, function(t)
			pose(t)
			local a = quadOut(t / M.FadeTime)
			for _, tr in ipairs(fades) do fadeTo(tr, a) end
			for _, tile in ipairs(tiles) do
				local e = quadOut((t - tile.delay) / M.TileTime)
				drive(tile.scale, function(rest) return rest * (M.TileFrom + (1 - M.TileFrom) * e) end)
				for _, tr in ipairs(tile.fades) do fadeTo(tr, e) end
			end
		end)
	end)
end

-- Same opts as openMotion. Shrinks and fades the window and lifts the dim, then calls onDone
-- (which hides the window) and puts every property back to rest for the next open.
-- A second close while one is running is ignored; an open cancels a running close.
function PanelChrome.closeMotion(opts, onDone: () -> ())
	local M = PanelChrome.MOTION
	local frame = opts.frame
	local running = motions[frame]
	if running and running.kind == "close" then return end
	stopMotion(frame)
	local scaleTr = opts.scale and newTrack(opts.scale, "Scale")
	local posTr = newTrack(frame, "Position")
	local dimTr = opts.dim and newTrack(opts.dim, "BackgroundTransparency", opts.dimTo)
	local fades = {}
	collectFades(frame, fades)
	local st = { kind = "close", onDone = onDone }
	st.settleAll = function()
		if scaleTr then settle(scaleTr) end
		settle(posTr)
		if dimTr then settle(dimTr) end
		for _, tr in ipairs(fades) do settle(tr) end
	end
	motions[frame] = st
	runMotion(frame, st, M.CloseTime, function(t)
		local a = t / M.CloseTime
		local e = quadIn(a)
		if scaleTr then drive(scaleTr, function(rest) return rest * (1 - (1 - M.CloseTo) * e) end) end
		drive(posTr, function(rest) return rest + UDim2.fromOffset(0, math.floor(M.CloseDrop * e + 0.5)) end)
		if dimTr then fadeTo(dimTr, 1 - quadOut(a)) end
		for _, tr in ipairs(fades) do fadeTo(tr, 1 - a) end
	end)
end

-- True while a close motion is playing on this window.
function PanelChrome.isClosing(frame: GuiObject): boolean
	local st = motions[frame]
	return st ~= nil and st.kind == "close"
end

-- ═════════════════════════════════════════════════════════════════════════════
--  Button press feedback, shared by every chunky button.
--
--  Hover grows the button 5% over 75 ms. Pressing sinks it: it shrinks to 0.92 over 55 ms
--  (Quad out), drops 2 px and its fill darkens 10%, and it holds there while the button is
--  held. Releasing springs it back past rest with a Back-out ease to 1.06 by 120 ms, then
--  settles to 1.0 by 220 ms. A button's icon, if it has one, lags the spring by 30 ms and
--  overshoots a little further, so the art follows through after the tile.
--  The button scales about its centre whatever its AnchorPoint. A button placed by a
--  UIListLayout/UIGridLayout cannot scale without shoving its neighbours, so there the tile
--  holds its size and its contents sink instead (same drop, same darken).
-- ═════════════════════════════════════════════════════════════════════════════
local UserInputService = game:GetService("UserInputService")

PanelChrome.PRESS = { -- [TUNING] seconds, scale factors and pixels
	HoverScale = 1.05, HoverTime = 0.075,
	DownScale = 0.90, DownTime = 0.055, Drop = 2, Darken = 0.10,
	UpPeak = 1.06, UpPeakAt = 0.11, SettleBy = 0.22,
	MaxStep = 1 / 24, -- a stage never advances more than this per frame, so a hitch cannot skip it
	IconDown = 0.94, IconPeak = 1.05, IconLag = 0.03,
}

local BLACK = Color3.new(0, 0, 0)
local function backOut(a) return ease(a, Enum.EasingStyle.Back, Enum.EasingDirection.Out) end
local function sineInOut(a) return ease(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) end

local function layoutManaged(inst: Instance): boolean
	local parent = inst.Parent
	return parent ~= nil and parent:FindFirstChildWhichIsA("UIGridStyleLayout") ~= nil
end

local presses = setmetatable({}, { __mode = "k" }) -- [button] = press handle
local held = {} -- [handle] = true while pressed; any mouse/touch release lets them go

-- Begin a stretch of motion away from rest: capture every rest value the press drives.
local function openTracks(h)
	if h.tracks then return end
	local P = PanelChrome.PRESS
	local btn = h.button
	local tr = { fills = {}, drops = {} }
	h.lite = layoutManaged(btn)
	local restScale = if h.scale.Scale > 0 then h.scale.Scale else 1
	tr.restAbs = btn.AbsoluteSize / restScale
	if not h.lite then tr.pos = newTrack(btn, "Position") end
	local face = h.face
	if h.lite then
		for _, c in ipairs(btn:GetChildren()) do
			if c:IsA("GuiObject") and c.Name ~= "CountBadge" then table.insert(tr.drops, newTrack(c, "Position")) end
		end
	elseif face and face ~= btn then
		table.insert(tr.drops, newTrack(face, "Position"))
	end
	local fills = if h.fill then h.fill() else { face or btn }
	for _, f in ipairs(fills) do
		if f and f.Parent and f.BackgroundTransparency < 0.999 then table.insert(tr.fills, newTrack(f, "BackgroundColor3")) end
	end
	tr.drop = h.drop or P.Drop
	h.tracks = tr
end

local function closeTracks(h)
	local tr = h.tracks
	if not tr then return end
	h.tracks = nil
	if tr.pos then settle(tr.pos) end
	for _, t in ipairs(tr.drops) do settle(t) end
	for _, t in ipairs(tr.fills) do settle(t) end
	h.scale.Scale = 1
	if h.iconScale then h.iconScale.Scale = 1 end
end

-- Writes one pose: s = tile scale, d = drop (0..1), k = darken (0..1), i = icon scale.
local function pose(h, s, d, k, i)
	local tr = h.tracks
	if not tr then return end
	local dropPx = math.floor(tr.drop * d + 0.5)
	if h.lite then
		for _, t in ipairs(tr.drops) do drive(t, function(rest) return rest + UDim2.fromOffset(0, dropPx) end) end
	else
		h.scale.Scale = s
		local btn = h.button
		local parent = btn.Parent
		local px, py = 0, 0
		if parent and parent:IsA("GuiBase2d") then
			-- UIScale grows a button about its AnchorPoint; shift it so it grows about its centre.
			local pa = parent.AbsoluteSize
			local a = btn.AnchorPoint
			if pa.X > 0 then px = (0.5 - a.X) * tr.restAbs.X * (1 - s) / pa.X end
			if pa.Y > 0 then py = (0.5 - a.Y) * tr.restAbs.Y * (1 - s) / pa.Y end
		end
		local bodyDrop = if #tr.drops > 0 then 0 else dropPx
		drive(tr.pos, function(rest) return rest + UDim2.new(px, 0, py, bodyDrop) end)
		for _, t in ipairs(tr.drops) do drive(t, function(rest) return rest + UDim2.fromOffset(0, dropPx) end) end
	end
	for _, t in ipairs(tr.fills) do drive(t, function(rest) return rest:Lerp(BLACK, PanelChrome.PRESS.Darken * k) end) end
	if h.iconScale then h.iconScale.Scale = i end
	h.s, h.d, h.k, h.i = s, d, k, i
end

-- Runs step(t) every frame for duration seconds; a new stage replaces the running one.
local function stage(h, duration: number, step: (number) -> (), atRest: boolean)
	if h.conn then h.conn:Disconnect(); h.conn = nil end
	openTracks(h)
	-- Time advances by each frame's delta, capped at PRESS.MaxStep: when the frame that fires the
	-- button's action is a slow one (a panel building its contents), the press still plays through
	-- its dip, spring and settle on the frames after it instead of jumping straight to the end.
	local t = 0
	local maxStep = PanelChrome.PRESS.MaxStep
	step(0)
	h.conn = RunService.RenderStepped:Connect(function(dt)
		t += math.min(dt, maxStep)
		if t < duration then step(t) return end
		h.conn:Disconnect()
		h.conn = nil
		step(duration)
		if atRest then closeTracks(h) end
	end)
end

local function hover(h, on: boolean)
	if h.pressed then return end
	local P = PanelChrome.PRESS
	h.hovered = on
	local s0, d0, k0, i0 = h.s, h.d, h.k, h.i
	local target = if on then P.HoverScale else 1
	if not on and s0 == 1 and d0 == 0 and not h.tracks then return end
	stage(h, P.HoverTime, function(t)
		local e = quadOut(t / P.HoverTime)
		pose(h, s0 + (target - s0) * e, d0 * (1 - e), k0 * (1 - e), i0 + (1 - i0) * e)
	end, not on)
end

local function down(h)
	local P = PanelChrome.PRESS
	h.pressed = true
	held[h] = true
	local s0, d0, k0, i0 = h.s, h.d, h.k, h.i
	stage(h, P.DownTime, function(t)
		local e = quadOut(t / P.DownTime)
		pose(h, s0 + (P.DownScale - s0) * e, d0 + (1 - d0) * e, k0 + (1 - k0) * e, i0 + (P.IconDown - i0) * e)
	end, false)
end

local function up(h)
	if not h.pressed then return end
	local P = PanelChrome.PRESS
	h.pressed = false
	h.hovered = false
	held[h] = nil
	local s0, d0, k0, i0 = h.s, h.d, h.k, h.i
	local total = P.SettleBy + P.IconLag
	stage(h, total, function(t)
		local s
		if t < P.UpPeakAt then
			s = s0 + (P.UpPeak - s0) * backOut(t / P.UpPeakAt)
		else
			s = P.UpPeak + (1 - P.UpPeak) * sineInOut((t - P.UpPeakAt) / (P.SettleBy - P.UpPeakAt))
		end
		local r = 1 - quadOut(t / P.UpPeakAt)
		local ti = t - P.IconLag
		local i
		if ti < 0 then
			i = i0
		elseif ti < P.UpPeakAt then
			i = i0 + (P.IconPeak - i0) * backOut(ti / P.UpPeakAt)
		else
			i = P.IconPeak + (1 - P.IconPeak) * sineInOut((ti - P.UpPeakAt) / (P.SettleBy - P.UpPeakAt))
		end
		pose(h, s, d0 * r, k0 * r, i)
	end, true)
end

-- The pointer left while the button was held: ease back to rest with no spring (no click).
local function cancel(h)
	if not h.pressed then return hover(h, false) end
	h.pressed = false
	held[h] = nil
	return hover(h, false)
end

UserInputService.InputEnded:Connect(function(input)
	local t = input.UserInputType
	if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
	for h in pairs(held) do up(h) end
end)

-- Wires hover/press feedback onto a button and returns its handle, whose hover(on), down() and
-- up() steps can also be called directly (the Studio motion capture plays them as a mouse would).
-- opts: {
--   scale: UIScale?     the UIScale to drive (default: the button's "PressScale", made if missing)
--   face: GuiObject?    the part that sinks and darkens (default: the button itself)
--   fill: (() -> {GuiObject})?  what darkens, looked up on each press (default: { face })
--   drop: number?       pixels the face sinks (default PRESS.Drop)
--   icon: GuiObject?    art that follows through after the tile on release
--   wire: boolean?      false to call the steps yourself instead of wiring mouse events
-- }
function PanelChrome.pressFeedback(button: GuiButton, opts)
	opts = opts or {}
	local existing = presses[button]
	if existing then return existing end
	local scale = opts.scale or button:FindFirstChild("PressScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "PressScale"
		scale.Parent = button
	end
	local h = {
		button = button, scale = scale, face = opts.face, fill = opts.fill, drop = opts.drop,
		s = 1, d = 0, k = 0, i = 1, pressed = false, hovered = false,
	}
	if opts.icon then
		local is = Instance.new("UIScale")
		is.Name = "PressIconScale"
		is.Parent = opts.icon
		h.iconScale = is
	end
	h.hover = function(on: boolean) hover(h, on) end
	h.down = function() down(h) end
	h.up = function() up(h) end
	h.cancel = function() cancel(h) end
	if opts.wire ~= false then
		button.MouseEnter:Connect(function() hover(h, true) end)
		button.MouseLeave:Connect(function() cancel(h) end)
		button.MouseButton1Down:Connect(function() down(h) end)
		button.MouseButton1Up:Connect(function() up(h) end)
	end
	button.Destroying:Connect(function()
		held[h] = nil
		if h.conn then h.conn:Disconnect(); h.conn = nil end
	end)
	presses[button] = h
	return h
end

-- The press handle wired onto a button, if any.
function PanelChrome.pressHandle(button: Instance)
	return presses[button]
end

-- ═════════════════════════════════════════════════════════════════════════════
--  Currency counter motion: a gain never just swaps the text.
--
--  The icon and number punch up to 1.15x in 60 ms and flash warm gold, the displayed value
--  rolls from the old total to the new one with a cubic ease-out (so the tenths of 588.4K
--  visibly tick up), the punch eases down while it counts and snaps home with a small
--  back-out overshoot the moment the count lands, and the gold tint fades back to white.
--  A green "+3,000" pops in beside the number and floats up, so even a gain too small to
--  move the short-form text is readable. Gains that arrive mid-count keep rolling from the
--  value on screen and add onto the floating delta. Losses and the first fill snap.
-- ═════════════════════════════════════════════════════════════════════════════
PanelChrome.COUNTER = { -- [TUNING] seconds, scale factors, degrees and pixels
	CountTime = 0.38, Peak = 1.15, RiseTime = 0.06, HoldTo = 1.08, SettleTime = 0.17,
	FlashFade = 0.2, IconKick = -9,
	DeltaTime = 0.8, DeltaRise = 40, DeltaFadeFrom = 0.5, DeltaPopPeak = 1.2, DeltaPopTime = 0.12,
	MaxStep = 1 / 30, -- one frame never advances the motion further than this, so a hitch cannot skip the punch
}
local FLASH_GOLD = Color3.fromRGB(255, 222, 70)

local function cubicOut(a) return ease(a, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out) end

-- opts = {
--   label: TextLabel            the number
--   scale: UIScale              punches the icon and number together (scale about their left edge)
--   icon: GuiObject?            gets a small rotation kick in step with the punch
--   format: (number) -> string  how the number is written (NumberFormat.short)
--   deltaParent: GuiObject?     where the floating gain lives (outside the punch, so it does not scale)
--   deltaAt: ((text) -> UDim2)? where the floating gain starts, given the final number text
--   deltaText: ((number) -> string)?  how the gain is written (default "+" .. format(gain))
--   deltaZ: number?
--   deltaColor: Color3?         colour of the floating gain (default BRIGHT.Green)
--   deltaSize: number?, deltaStroke: Color3?   its text size (default 30) and outline colour
--   tuning: {[string]: number}? overrides of PanelChrome.COUNTER for this counter only. With
--                               Rekick set, every gain restarts the punch from at most that
--                               scale, so gains landing one after another each read as a kick.
-- }
-- Returns { set = function(value, animate) }. set with animate false (or a loss) snaps.
function PanelChrome.counter(opts)
	local C = PanelChrome.COUNTER
	if opts.tuning then
		local merged = table.clone(C)
		for k, v in pairs(opts.tuning) do merged[k] = v end
		C = merged
	end
	local label, scale, icon = opts.label, opts.scale, opts.icon
	local format = opts.format or function(v) return tostring(math.floor(v)) end
	local restColor = label.TextColor3
	local iconRest = if icon then icon.Rotation else 0
	local shown, target, from = nil, nil, 0
	local t, s0, conn = 0, 1, nil
	local delta = nil -- { label, uiScale, stroke, t, total, conn }

	local function stop()
		if conn then conn:Disconnect(); conn = nil end
	end
	local function rest()
		scale.Scale = 1
		label.TextColor3 = restColor
		if icon then icon.Rotation = iconRest end
	end

	local function scaleAt(x: number): number
		if x < C.RiseTime then return s0 + (C.Peak - s0) * quadOut(x / C.RiseTime) end
		if x < C.CountTime then
			return C.Peak + (C.HoldTo - C.Peak) * sineInOut((x - C.RiseTime) / (C.CountTime - C.RiseTime))
		end
		local k = (x - C.CountTime) / C.SettleTime
		if k < 1 then return C.HoldTo + (1 - C.HoldTo) * backOut(k) end
		return 1
	end
	local function colorAt(x: number): Color3
		if x < C.RiseTime then return restColor:Lerp(FLASH_GOLD, x / C.RiseTime) end
		if x < C.CountTime then return FLASH_GOLD end
		local k = (x - C.CountTime) / C.FlashFade
		if k < 1 then return FLASH_GOLD:Lerp(restColor, quadIn(k)) end
		return restColor
	end

	local function step(dt: number)
		t += math.min(dt, C.MaxStep)
		local a = math.clamp(t / C.CountTime, 0, 1)
		shown = if a >= 1 then target else from + (target - from) * cubicOut(a)
		label.Text = format(math.floor(shown))
		local s = scaleAt(t)
		scale.Scale = s
		label.TextColor3 = colorAt(t)
		if icon then icon.Rotation = iconRest + C.IconKick * math.clamp((s - 1) / (C.Peak - 1), -0.3, 1) end
		if t >= C.CountTime + math.max(C.SettleTime, C.FlashFade) then
			stop()
			shown = target
			label.Text = format(target)
			rest()
		end
	end

	local function deltaStep(dt: number)
		local d = delta
		if not d then return end
		d.t += math.min(dt, C.MaxStep)
		local k = d.t / C.DeltaTime
		if k >= 1 then
			d.conn:Disconnect()
			d.label:Destroy()
			delta = nil
			return
		end
		local pop = if d.t < C.DeltaPopTime
			then 0.4 + (C.DeltaPopPeak - 0.4) * quadOut(d.t / C.DeltaPopTime)
			else C.DeltaPopPeak + (1 - C.DeltaPopPeak) * quadOut(math.min((d.t - C.DeltaPopTime) / C.DeltaPopTime, 1))
		d.uiScale.Scale = pop
		d.label.Position = d.start + UDim2.fromOffset(0, -C.DeltaRise * quadOut(k))
		local fade = if k > C.DeltaFadeFrom then (k - C.DeltaFadeFrom) / (1 - C.DeltaFadeFrom) else 0
		d.label.TextTransparency = fade
		if d.stroke then d.stroke.Transparency = fade end
	end

	local function showDelta(gain: number)
		local parent = opts.deltaParent
		if not parent or gain <= 0 then return end
		local start = if opts.deltaAt then opts.deltaAt(format(target)) else UDim2.new(1, 8, 0.5, 0)
		local total = gain + (if delta then delta.total else 0)
		local text = if opts.deltaText then opts.deltaText(total) else "+" .. format(total)
		if not delta then
			local l = PanelChrome.display(parent, {
				name = "GainDelta", text = text, size = opts.deltaSize or 30, stroke = 3, color = opts.deltaColor or BRIGHT.Green,
				strokeColor = opts.deltaStroke,
				xAlign = Enum.TextXAlignment.Left, anchor = Vector2.new(0, 0.5),
				size2 = UDim2.fromOffset(0, (opts.deltaSize or 30) + 4), zIndex = opts.deltaZ or 12,
			})
			l.AutomaticSize = Enum.AutomaticSize.X
			local us = Instance.new("UIScale")
			us.Parent = l
			delta = { label = l, uiScale = us, stroke = l:FindFirstChildOfClass("UIStroke"), total = total, t = 0 }
			delta.conn = RunService.RenderStepped:Connect(deltaStep)
		end
		delta.total = total
		delta.label.Text = text
		delta.start = start
		delta.t = 0
		deltaStep(0)
	end

	local counter = {}
	function counter.set(value: number, animate: boolean?)
		value = tonumber(value) or 0
		if shown ~= nil and value == target then return end -- unrelated refresh: let a count finish
		if shown == nil or not animate or value < (target or 0) then
			stop()
			shown, target = value, value
			label.Text = format(value)
			rest()
			return
		end
		local gain = value - target
		from = shown
		target = value
		s0 = if C.Rekick then math.min(scale.Scale, C.Rekick) else scale.Scale
		t = 0
		showDelta(gain)
		if not conn then conn = RunService.RenderStepped:Connect(step) end
		step(0)
	end
	return counter
end

return PanelChrome
