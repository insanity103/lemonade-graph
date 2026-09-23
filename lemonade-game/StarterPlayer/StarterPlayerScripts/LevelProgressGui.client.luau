-- LocalScript | StarterPlayerScripts.LevelProgressGui | Health + XP meters, bottom-left.
-- Built entirely from native UI instances (no image assets), in the bright chunky style of
-- PanelChrome: each meter is a thick-outlined pill with a dark recessed track and a solid
-- vertical-gradient fill (bright top, deeper bottom, glossy highlight), read out in stroked
-- display numbers. A big heart overlaps the health bar's left end and a round gold level
-- badge anchors the XP bar's. The cluster scales with PanelChrome.hudScale so it holds on phones.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))

local BRIGHT = PanelChrome.BRIGHT
local HUD = PanelChrome.HUD
local OUTLINE = BRIGHT.Outline

local existing = playerGui:FindFirstChild("LevelProgressGui")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LevelProgressGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Design-space geometry (unscaled pixels; the root's UIScale shrinks it on small screens).
local BAR_X, BAR_W = 42, 384
local HP_Y, HP_H = 8, 42
local XP_Y, XP_H = HP_Y + HP_H + 28, 32
local HEART_SIZE = 64
local BADGE_SIZE = 80

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(0, 1)
root.Size = UDim2.fromOffset(HUD.VitalsWidth, HUD.VitalsHeight)
root.BackgroundTransparency = 1
root.Parent = screenGui
local rootScale = Instance.new("UIScale")
rootScale.Parent = root

PanelChrome.onViewport(function(viewport)
	rootScale.Scale = PanelChrome.hudScale(viewport)
	root.Position = UDim2.new(0, HUD.Margin, 1, -PanelChrome.hudVitalsBottom(viewport))
end)

local function round(inst: GuiObject)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = inst
	return c
end

-- One meter: outlined pill shell (the dark empty track), an inset shadow along the track's top,
-- a gradient fill whose Size.X.Scale is the percentage, and a gloss band riding on the fill.
local function makeBar(name: string, y: number, height: number, track: Color3, top: Color3, bottom: Color3, textSize: number, textLeft: number)
	local shell = Instance.new("Frame")
	shell.Name = name
	shell.Position = UDim2.fromOffset(BAR_X, y)
	shell.Size = UDim2.fromOffset(BAR_W, height)
	shell.BackgroundColor3 = track
	shell.BorderSizePixel = 0
	shell.ZIndex = 2
	shell.Parent = root
	round(shell)
	PanelChrome.stroke(shell, OUTLINE, 3.5)

	local inset = Instance.new("Frame")
	inset.Name = "TrackShadow"
	inset.BackgroundColor3 = Color3.new(0, 0, 0)
	inset.BorderSizePixel = 0
	inset.Size = UDim2.new(1, 0, 0.55, 0)
	inset.ZIndex = 2
	inset.Parent = shell
	round(inset)
	local insetGradient = Instance.new("UIGradient")
	insetGradient.Rotation = 90
	insetGradient.Transparency = NumberSequence.new(0.55, 1)
	insetGradient.Parent = inset

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.ZIndex = 3
	fill.Parent = shell
	round(fill)
	PanelChrome.gradient(fill, top, bottom)

	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BorderSizePixel = 0
	gloss.Position = UDim2.new(0, 8, 0, 4)
	gloss.Size = UDim2.new(1, -16, 0.34, 0)
	gloss.ZIndex = 3
	gloss.Parent = fill
	round(gloss)
	local glossGradient = Instance.new("UIGradient")
	glossGradient.Rotation = 90
	glossGradient.Transparency = NumberSequence.new(0.35, 0.8)
	glossGradient.Parent = gloss

	local label = PanelChrome.display(shell, {
		name = "Label", text = "", size = textSize, stroke = 3, zIndex = 6,
		pos = UDim2.fromOffset(textLeft, 0), size2 = UDim2.new(1, -textLeft - 10, 1, 0),
	})
	return fill, label
end

-- Heart from two circles and a rotated square, laid out in a 100-unit box. Drawn twice (a
-- larger dark copy behind, the red copy in front) for one clean outline around the whole shape.
local function heartShape(parent: Frame, color: Color3, pad: number, z: number)
	local k = HEART_SIZE / 100
	local function piece(cx: number, cy: number, size: number, rotation: number, rounded: boolean)
		local p = Instance.new("Frame")
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Position = UDim2.fromOffset(cx * k, cy * k)
		p.Size = UDim2.fromOffset(size * k + pad, size * k + pad)
		p.Rotation = rotation
		p.BackgroundColor3 = color
		p.BorderSizePixel = 0
		p.ZIndex = z
		p.Parent = parent
		if rounded then
			round(p)
		else
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 4)
			c.Parent = p
		end
		return p
	end
	piece(30, 36, 46, 0, true)
	piece(70, 36, 46, 0, true)
	piece(50, 55, 50, 45, false)
end

local function makeHeart()
	local holder = Instance.new("Frame")
	holder.Name = "HeartIcon"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromOffset(BAR_X - 4, HP_Y + HP_H / 2 - 7)
	holder.Size = UDim2.fromOffset(HEART_SIZE, HEART_SIZE)
	holder.BackgroundTransparency = 1
	holder.Rotation = -8
	holder.ZIndex = 7
	holder.Parent = root
	heartShape(holder, OUTLINE, 8, 7)
	heartShape(holder, Color3.fromRGB(214, 30, 58), 0, 8)
	-- Lighter upper face over the deep base reads as a rendered, lit heart.
	local k = HEART_SIZE / 100
	for _, spec in ipairs({ { 30, 34, 38 }, { 70, 34, 38 } }) do
		local face = Instance.new("Frame")
		face.AnchorPoint = Vector2.new(0.5, 0.5)
		face.Position = UDim2.fromOffset(spec[1] * k, spec[2] * k)
		face.Size = UDim2.fromOffset(spec[3] * k, spec[3] * k)
		face.BackgroundColor3 = Color3.fromRGB(255, 78, 96)
		face.BorderSizePixel = 0
		face.ZIndex = 8
		face.Parent = holder
		round(face)
	end
	local shine = Instance.new("Frame")
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Position = UDim2.fromOffset(27 * k, 30 * k)
	shine.Size = UDim2.fromOffset(16 * k, 11 * k)
	shine.Rotation = -30
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.1
	shine.BorderSizePixel = 0
	shine.ZIndex = 9
	shine.Parent = holder
	round(shine)
end

-- Round gold level badge: gradient coin face, heavy outline, pale inner ring, "LV" over the
-- big level number.
local function makeLevelBadge()
	local badge = Instance.new("Frame")
	badge.Name = "LevelBadge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromOffset(BAR_X - 2, XP_Y + XP_H / 2)
	badge.Size = UDim2.fromOffset(BADGE_SIZE, BADGE_SIZE)
	badge.BackgroundColor3 = Color3.new(1, 1, 1)
	badge.ZIndex = 9
	badge.Parent = root
	round(badge)
	PanelChrome.stroke(badge, OUTLINE, 4)
	PanelChrome.gradient(badge, Color3.fromRGB(255, 236, 110), Color3.fromRGB(242, 140, 16))

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.new(1, -10, 1, -10)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 9
	ring.Parent = badge
	round(ring)
	PanelChrome.stroke(ring, Color3.fromRGB(255, 248, 200), 2.5, 0.15)

	PanelChrome.display(badge, {
		name = "Caption", text = "LV", size = 17, stroke = 2.5, zIndex = 11,
		anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromScale(0.5, 0.27), size2 = UDim2.fromScale(0.6, 0.26),
	})
	local number = PanelChrome.display(badge, {
		name = "Level", text = "1", size = 36, stroke = 3, zIndex = 11, scaled = true, minSize = 16,
		anchor = Vector2.new(0.5, 0.5), pos = UDim2.fromScale(0.5, 0.62), size2 = UDim2.fromScale(0.82, 0.46),
	})
	return number
end

local healthFill, healthLabel = makeBar(
	"HealthBar", HP_Y, HP_H,
	Color3.fromRGB(72, 18, 30), Color3.fromRGB(255, 108, 118), Color3.fromRGB(206, 30, 56), 27, 34
)
makeHeart()

local xpFill, xpLabel = makeBar(
	"XPBar", XP_Y, XP_H,
	Color3.fromRGB(20, 58, 34), Color3.fromRGB(156, 244, 96), Color3.fromRGB(40, 168, 60), 22, 42
)
local levelLabel = makeLevelBadge()

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
	levelLabel.Text = tostring(levelValue.Value)
	xpLabel.Text = string.format("%s / %s XP", NumberFormat.short(experience), NumberFormat.short(required))
	setProgress(xpFill, experience / math.max(required, 1))
end

levelValue.Changed:Connect(updateXP)
experienceValue.Changed:Connect(updateXP)
player:GetAttributeChangedSignal("ExperienceRequired"):Connect(updateXP)
updateXP()

-- ── Health ───────────────────────────────────────────────────────────────────
local function hookHealth(character: Model)
	local humanoid = character:WaitForChild("Humanoid")
	local function updateHealth()
		healthLabel.Text = string.format(
			"%s / %s",
			NumberFormat.short(math.max(0, math.floor(humanoid.Health))),
			NumberFormat.short(math.floor(humanoid.MaxHealth))
		)
		setProgress(healthFill, humanoid.Health / math.max(humanoid.MaxHealth, 1))
	end
	humanoid.HealthChanged:Connect(updateHealth)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealth)
	updateHealth()
end

if player.Character then
	hookHealth(player.Character)
end
player.CharacterAdded:Connect(hookHealth)

-- Studio-only screenshot hook (see GuiShowcase): the HUD is always on, so the showcase only
-- makes sure nothing covers it -- the capture shows it exactly as a player spawns in.
GuiShowcase.register("HUD", function()
	print("[GuiShowcase] HUD showcase: vitals, gold readout and side buttons on screen")
end)

print("[LevelProgressGui] Health and XP meters enabled")
