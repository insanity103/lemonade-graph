-- ReplicatedStorage/PanelChrome.luau
-- Shared visual chrome for modal GUI panels (Reforge, Vault, Merchant, Quest, Main Menu):
-- a consistent bordered shell with a title banner and a close button, so every panel reads
-- as one system instead of five independently-styled ones. Returns plain
-- Instances -- works from imperative scripts (set .Parent yourself) and from Fusion (drop
-- PanelChrome.build(...).Frame straight into a [Children] table).
local PanelChrome = {}

PanelChrome.COLORS = {
	Panel = Color3.fromRGB(18, 18, 22), PanelLight = Color3.fromRGB(26, 26, 32), Dark = Color3.fromRGB(10, 10, 13),
	Stroke = Color3.fromRGB(45, 45, 55), StrokeBright = Color3.fromRGB(75, 75, 90), Gold = Color3.fromRGB(255, 215, 60),
	Text = Color3.fromRGB(245, 245, 250), Muted = Color3.fromRGB(160, 160, 175), Button = Color3.fromRGB(35, 35, 45),
	ButtonHover = Color3.fromRGB(55, 55, 65), Ember = Color3.fromRGB(232, 112, 42), Success = Color3.fromRGB(80, 220, 140),
	Error = Color3.fromRGB(255, 85, 85),
}

PanelChrome.RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180), Uncommon = Color3.fromRGB(80, 200, 120), Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(180, 80, 240), Legendary = Color3.fromRGB(255, 200, 40),
}

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
	return c
end
PanelChrome.corner = corner

-- Builds a bordered modal shell: background, corner radius, accent stroke, a title banner
-- (title + optional subtitle) with a header divider, and a close button. The frame is
-- returned unparented -- parent it yourself, or hand it to Fusion.
--
-- props: { name, title, subtitle, accentColor, size }
function PanelChrome.build(props)
	local accent = props.accentColor or PanelChrome.COLORS.Ember

	local modal = Instance.new("Frame")
	modal.Name = props.name or "Modal"
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = props.size or UDim2.fromOffset(800, 600)
	modal.BackgroundColor3 = PanelChrome.COLORS.Panel
	modal.BorderSizePixel = 0
	corner(modal, 14)

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.Parent = modal

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(20, 14)
	titleLabel.Size = UDim2.new(1, -220, 0, 32)
	titleLabel.Font = Enum.Font.Fantasy
	titleLabel.TextSize = props.titleSize or 30
	titleLabel.TextColor3 = accent
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = props.title or ""
	titleLabel.Parent = modal

	local subtitleLabel
	if props.subtitle then
		subtitleLabel = Instance.new("TextLabel")
		subtitleLabel.Name = "Subtitle"
		subtitleLabel.BackgroundTransparency = 1
		subtitleLabel.Position = UDim2.fromOffset(20, 46)
		subtitleLabel.Size = UDim2.new(1, -220, 0, 20)
		subtitleLabel.Font = Enum.Font.GothamMedium
		subtitleLabel.TextSize = 13
		subtitleLabel.TextColor3 = PanelChrome.COLORS.Muted
		subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
		subtitleLabel.Text = props.subtitle
		subtitleLabel.Parent = modal
	end

	local headerBottom = props.subtitle and 74 or 52

	local divider = Instance.new("Frame")
	divider.Name = "HeaderDivider"
	divider.BackgroundColor3 = accent
	divider.BackgroundTransparency = 0.7
	divider.BorderSizePixel = 0
	divider.Position = UDim2.fromOffset(20, headerBottom - 2)
	divider.Size = UDim2.new(1, -40, 0, 1)
	divider.Parent = modal

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.Position = UDim2.new(1, -14, 0, 14)
	closeBtn.Size = UDim2.fromOffset(34, 34)
	closeBtn.BackgroundColor3 = PanelChrome.COLORS.Button
	closeBtn.Text = "X"
	closeBtn.TextColor3 = PanelChrome.COLORS.Text
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 18
	closeBtn.Parent = modal
	corner(closeBtn, 8)

	return {
		Frame = modal,
		TitleLabel = titleLabel,
		SubtitleLabel = subtitleLabel,
		CloseButton = closeBtn,
		HeaderBottom = headerBottom, -- y-offset where panel-specific body content should start
	}
end

-- ═════════════════════════════════════════════════════════════════════════════
--  Bright chrome: light, chunky, thick-outlined panels (the look the Main Menu uses).
--  Everything below is additive; build() above keeps the dark style for panels that
--  have not moved over yet.
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
	PanelChrome.stroke(label, props.strokeColor or BRIGHT.Outline, props.stroke or 2.5)
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
	local scale = Instance.new("UIScale")
	scale.Parent = btn
	btn.MouseEnter:Connect(function() scale.Scale = 1.04 end)
	btn.MouseLeave:Connect(function() scale.Scale = 1 end)
	btn.MouseButton1Down:Connect(function() scale.Scale = 0.95 end)
	btn.MouseButton1Up:Connect(function() scale.Scale = 1 end)
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
	HotbarLift = 28, -- gap under the bottom-centre sword hotbar slot, in pixels (not scaled); its drop
	-- shadow and equipped ring hang ~11 px below the tile, so this leaves ~16 px of clear screen edge
	HotbarSize = 120, -- design-space side of the hotbar slot; it scales with hudScale
	HotbarClear = 168, -- lift over the hotbar at full scale (28 lift + 120 slot + badges + gap)
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
-- gold readout). Anything else that lives bottom-left, such as MapClient's Return to Hub
-- button, stacks above this so the HUD can grow without covering it.
function PanelChrome.hudStackTop(viewport: Vector2): number
	local HUD = PanelChrome.HUD
	local s = PanelChrome.hudScale(viewport)
	return PanelChrome.hudVitalsBottom(viewport) + (HUD.VitalsHeight + HUD.GoldHeight) * s + 2
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

return PanelChrome
