local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local existing = playerGui:FindFirstChild("LevelProgressGui")
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LevelProgressGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "ProgressPanel"
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(0, 12, 1, -24)
panel.Size = UDim2.fromOffset(320, 98)
panel.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.ZIndex = 5
panel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(45, 45, 52)
stroke.Transparency = 0.3
stroke.Thickness = 1
stroke.Parent = panel

local levelLabel = Instance.new("TextLabel")
levelLabel.Name = "LevelLabel"
levelLabel.Position = UDim2.fromOffset(14, 10)
levelLabel.Size = UDim2.new(1, -28, 0, 22)
levelLabel.BackgroundTransparency = 1
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextColor3 = Color3.fromRGB(245, 245, 250)
levelLabel.TextSize = 17
levelLabel.TextXAlignment = Enum.TextXAlignment.Left
levelLabel.Text = "Level 1"
levelLabel.Parent = panel

local barBackground = Instance.new("Frame")
barBackground.Name = "ExperienceBarBackground"
barBackground.Position = UDim2.fromOffset(14, 38)
barBackground.Size = UDim2.new(1, -28, 0, 20)
barBackground.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
barBackground.BackgroundTransparency = 0.1
barBackground.BorderSizePixel = 0
barBackground.ClipsDescendants = true
barBackground.Parent = panel

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 6)
barCorner.Parent = barBackground

local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(40, 40, 48)
barStroke.Transparency = 0.4
barStroke.Thickness = 1
barStroke.Parent = barBackground

local barFill = Instance.new("Frame")
barFill.Name = "ExperienceBarFill"
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.fromRGB(60, 110, 190)
barFill.BorderSizePixel = 0
barFill.Parent = barBackground

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 6)
fillCorner.Parent = barFill

local fillGradient = Instance.new("UIGradient")
fillGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 95, 175)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(75, 135, 225)),
})
fillGradient.Parent = barFill

local experienceLabel = Instance.new("TextLabel")
experienceLabel.Name = "ExperienceLabel"
experienceLabel.Size = UDim2.fromScale(1, 1)
experienceLabel.BackgroundTransparency = 1
experienceLabel.Font = Enum.Font.GothamBold
experienceLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
experienceLabel.TextSize = 12
experienceLabel.TextStrokeTransparency = 0.6
experienceLabel.Text = "0 / 100 XP"
experienceLabel.ZIndex = 2
experienceLabel.Parent = barBackground

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "ProgressHint"
hintLabel.Position = UDim2.fromOffset(14, 63)
hintLabel.Size = UDim2.new(1, -28, 0, 26)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextColor3 = Color3.fromRGB(175, 180, 195)
hintLabel.TextSize = 12
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Text = "Defeat enemies • spend Skill Points • follow the level gates"
hintLabel.TextTruncate = Enum.TextTruncate.AtEnd
hintLabel.Parent = panel

local NumberFormat = require(game:GetService("ReplicatedStorage"):WaitForChild("NumberFormat"))
local leaderstats = player:WaitForChild("leaderstats")
local levelValue = leaderstats:WaitForChild("Level")
local experienceValue = leaderstats:WaitForChild("Experience")

local activeBarTween

local function update()
	local level = levelValue.Value
	local experience = experienceValue.Value
	local required = player:GetAttribute("ExperienceRequired") or 100
	local progress = math.clamp(experience / math.max(required, 1), 0, 1)

	levelLabel.Text = "Level " .. tostring(level)
	experienceLabel.Text = string.format("%s / %s XP", NumberFormat.short(experience), NumberFormat.short(required))

	if activeBarTween then
		activeBarTween:Cancel()
	end
	activeBarTween = TweenService:Create(
		barFill,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(progress, 1) }
	)
	activeBarTween:Play()
end

levelValue.Changed:Connect(update)
experienceValue.Changed:Connect(update)
player:GetAttributeChangedSignal("ExperienceRequired"):Connect(update)
update()

print("[LevelProgressGui] Level and XP bar enabled")
