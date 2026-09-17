-- LocalScript | StarterPlayerScripts.LevelProgressGui | Health + XP meters, bottom-left.
-- Built entirely from native UI instances (no image assets): a pill-shaped shell holds a dark
-- "empty" track and a bright animated fill, with a tiled chevron pattern (each chevron is two
-- rotated Frames meeting at a point) sitting inside the fill so it gets revealed/cropped by
-- the fill's own clipping as the meter drains and refills. A potion or heart badge -- also
-- built from Frames -- overlaps the bar's left end.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))

local existing = playerGui:FindFirstChild("LevelProgressGui")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LevelProgressGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local OUTLINE = Color3.fromRGB(15, 12, 10)
local BAR_WIDTH, BAR_HEIGHT = 236, 28
local ICON_SIZE = 40
local BAR_GAP = 14 -- vertical gap between the two bars

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(0, 1)
-- Left margin makes room for the icon badges, which overlap past the bars' left edge.
root.Position = UDim2.new(0, 12 + ICON_SIZE / 2, 1, -12)
root.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT * 2 + BAR_GAP)
root.BackgroundTransparency = 1
root.Parent = screenGui

-- A single chevron ">": two thin Frames rotated to meet at a point on the right, tiling
-- across a bar reads as the same "flowing arrows" motif as the reference art.
local CHEVRON_W, CHEVRON_H, CHEVRON_SPACING = 10, 14, 8
local CHEVRON_LENGTH = math.sqrt(CHEVRON_W ^ 2 + (CHEVRON_H / 2) ^ 2)
local CHEVRON_ANGLE = math.deg(math.atan2(CHEVRON_H / 2, CHEVRON_W))

local function addChevrons(parent: Frame, color: Color3, barWidth: number, barHeight: number)
	local count = math.ceil(barWidth / CHEVRON_SPACING) + 2
	for i = 0, count - 1 do
		local unit = Instance.new("Frame")
		unit.Name = "Chevron"
		unit.BackgroundTransparency = 1
		unit.Size = UDim2.fromOffset(CHEVRON_W, CHEVRON_H)
		unit.Position = UDim2.fromOffset(6 + i * CHEVRON_SPACING, (barHeight - CHEVRON_H) / 2)
		unit.Parent = parent
		for _, sign in ipairs({ 1, -1 }) do
			local seg = Instance.new("Frame")
			seg.Name = "Segment"
			seg.AnchorPoint = Vector2.new(0.5, 0.5)
			seg.Position = UDim2.fromOffset(CHEVRON_W / 2, CHEVRON_H / 2 + sign * CHEVRON_H / 4)
			seg.Size = UDim2.fromOffset(CHEVRON_LENGTH, 3)
			seg.Rotation = sign * CHEVRON_ANGLE
			seg.BackgroundColor3 = color
			seg.BackgroundTransparency = 0.2
			seg.BorderSizePixel = 0
			seg.Parent = unit
		end
	end
end

-- Builds one pill-shaped meter (shell + dark track + clipped chevron fill) plus a text label.
-- Returns the fill Frame (its Size.X.Scale drives the percentage) and the label.
local function makeBar(parent: Frame, name: string, position: UDim2, trackColor: Color3, fillColor: Color3, chevronColor: Color3)
	local shell = Instance.new("Frame")
	shell.Name = name
	shell.Position = position
	shell.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT)
	shell.BackgroundColor3 = trackColor
	shell.BorderSizePixel = 0
	shell.Parent = parent
	local shellCorner = Instance.new("UICorner")
	shellCorner.CornerRadius = UDim.new(1, 0)
	shellCorner.Parent = shell
	local shellStroke = Instance.new("UIStroke")
	shellStroke.Color = OUTLINE
	shellStroke.Thickness = 3
	shellStroke.Parent = shell

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.ClipsDescendants = true
	fill.Parent = shell
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	-- Fixed absolute width so the chevrons don't stretch as the fill's own Size shrinks --
	-- they're just revealed or cropped by fill's ClipsDescendants instead.
	local chevronLayer = Instance.new("Frame")
	chevronLayer.Name = "Chevrons"
	chevronLayer.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT)
	chevronLayer.BackgroundTransparency = 1
	chevronLayer.Parent = fill
	addChevrons(chevronLayer, chevronColor, BAR_WIDTH, BAR_HEIGHT)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.fromOffset(10, 0)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.1
	label.TextSize = 14
	label.Text = ""
	label.ZIndex = 3
	label.Parent = shell

	return fill, label
end

-- Two overlapping circles + a rotated square approximate a heart; drawing the same composite
-- twice (a slightly larger dark copy behind, the true-size colored copy in front) gives a
-- clean single outline instead of each piece showing its own seam where they overlap.
local function heartComposite(parent: Frame, color: Color3, pad: number)
	local function lobe(x: number, y: number, size: number)
		local c = Instance.new("Frame")
		c.Size = UDim2.fromOffset(size, size)
		c.Position = UDim2.fromOffset(x, y)
		c.BackgroundColor3 = color
		c.BorderSizePixel = 0
		c.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = c
	end
	lobe(4 - pad / 2, 8 - pad / 2, 14 + pad)
	lobe(16 - pad / 2, 8 - pad / 2, 14 + pad)

	local point = Instance.new("Frame")
	point.AnchorPoint = Vector2.new(0.5, 0.5)
	point.Position = UDim2.fromOffset(17, 20)
	point.Size = UDim2.fromOffset(16 + pad, 16 + pad)
	point.Rotation = 45
	point.BackgroundColor3 = color
	point.BorderSizePixel = 0
	point.Parent = parent
end

local function makeHeartIcon(parent: Frame, position: UDim2)
	local holder = Instance.new("Frame")
	holder.Name = "HeartIcon"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = position
	holder.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	heartComposite(holder, OUTLINE, 4)
	heartComposite(holder, Color3.fromRGB(222, 62, 82), 0)
	return holder
end

local function makePotionIcon(parent: Frame, position: UDim2)
	local holder = Instance.new("Frame")
	holder.Name = "PotionIcon"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = position
	holder.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local function piece(x, y, w, h, color, radius)
		local p = Instance.new("Frame")
		p.Size = UDim2.fromOffset(w, h)
		p.Position = UDim2.fromOffset(x, y)
		p.BackgroundColor3 = color
		p.BorderSizePixel = 0
		p.Parent = holder
		if radius then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, radius)
			corner.Parent = p
		end
		local stroke = Instance.new("UIStroke")
		stroke.Color = OUTLINE
		stroke.Thickness = 2
		stroke.Parent = p
		return p
	end

	piece(11, 2, 12, 6, Color3.fromRGB(120, 84, 52), 2) -- cork
	piece(12, 7, 10, 9, Color3.fromRGB(205, 222, 214), 2) -- neck
	local body = piece(6, 14, 22, 20, Color3.fromRGB(70, 190, 96), 6) -- body

	local shine = Instance.new("Frame")
	shine.AnchorPoint = Vector2.new(0.5, 0)
	shine.Position = UDim2.fromOffset(11, 3)
	shine.Size = UDim2.fromOffset(4, 14)
	shine.BackgroundColor3 = Color3.fromRGB(170, 235, 180)
	shine.BackgroundTransparency = 0.35
	shine.BorderSizePixel = 0
	shine.Parent = body
	local shineCorner = Instance.new("UICorner")
	shineCorner.CornerRadius = UDim.new(1, 0)
	shineCorner.Parent = shine

	return holder
end

local healthShell, healthLabel = makeBar(
	root, "HealthBar", UDim2.fromOffset(0, 0),
	Color3.fromRGB(60, 18, 22), Color3.fromRGB(196, 48, 64), Color3.fromRGB(240, 130, 140)
)
makeHeartIcon(root, UDim2.fromOffset(0, BAR_HEIGHT / 2))

local xpShell, xpLabel = makeBar(
	root, "XPBar", UDim2.fromOffset(0, BAR_HEIGHT + BAR_GAP),
	Color3.fromRGB(20, 56, 28), Color3.fromRGB(64, 176, 84), Color3.fromRGB(160, 235, 160)
)
makePotionIcon(root, UDim2.fromOffset(0, BAR_HEIGHT + BAR_GAP + BAR_HEIGHT / 2))

local function setProgress(fill: Frame, progress: number)
	local tween = TweenService:Create(
		fill,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1) }
	)
	tween:Play()
end

-- ── XP ───────────────────────────────────────────────────────────────────────
local leaderstats = player:WaitForChild("leaderstats")
local levelValue = leaderstats:WaitForChild("Level")
local experienceValue = leaderstats:WaitForChild("Experience")

local function updateXP()
	local experience = experienceValue.Value
	local required = player:GetAttribute("ExperienceRequired") or 100
	xpLabel.Text = string.format("Lv.%d   %s / %s", levelValue.Value, NumberFormat.short(experience), NumberFormat.short(required))
	setProgress(xpShell, experience / math.max(required, 1))
end

levelValue.Changed:Connect(updateXP)
experienceValue.Changed:Connect(updateXP)
player:GetAttributeChangedSignal("ExperienceRequired"):Connect(updateXP)
updateXP()

-- ── Health ───────────────────────────────────────────────────────────────────
local function hookHealth(character: Model)
	local humanoid = character:WaitForChild("Humanoid")
	local function updateHealth()
		healthLabel.Text = string.format("%d / %d", math.max(0, math.floor(humanoid.Health)), humanoid.MaxHealth)
		setProgress(healthShell, humanoid.Health / math.max(humanoid.MaxHealth, 1))
	end
	humanoid.HealthChanged:Connect(updateHealth)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealth)
	updateHealth()
end

if player.Character then
	hookHealth(player.Character)
end
player.CharacterAdded:Connect(hookHealth)

print("[LevelProgressGui] Health and XP meters enabled")
