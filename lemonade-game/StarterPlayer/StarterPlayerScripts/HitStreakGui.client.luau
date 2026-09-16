-- StarterPlayerScripts/HitStreakGui.client.luau
-- Escalating on-screen hit-streak banner: "{N} HITS" + a tier callout (GREAT, SAVAGE,
-- BRUTAL, GODLIKE) and a running total-damage readout. This counts every landed swing
-- without wrapping, unlike SwordSystem's 5-hit endlag/damage-mult cycle -- it exists
-- purely to make a long run of hits feel escalating on screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ComboConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ComboConfig"))
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local comboRemote = remotes:FindFirstChild("ComboUpdate")
local damageEvent = remotes:WaitForChild("DamageNumber")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HitStreakGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Parent = playerGui

-- Sits left of the right-edge nav rail (see MainMenuGui's NavRail), vertically centered.
local holder = Instance.new("Frame")
holder.AnchorPoint = Vector2.new(1, 0.5)
holder.Position = UDim2.new(1, -100, 0.5, -60)
holder.Size = UDim2.fromOffset(340, 120)
holder.BackgroundTransparency = 1
holder.Visible = false
holder.Parent = screenGui

local countLabel = Instance.new("TextLabel")
countLabel.AnchorPoint = Vector2.new(1, 0)
countLabel.Position = UDim2.new(1, 0, 0, 0)
countLabel.Size = UDim2.new(1, 0, 0, 56)
countLabel.BackgroundTransparency = 1
countLabel.Font = Enum.Font.GothamBlack
countLabel.TextScaled = true
countLabel.TextXAlignment = Enum.TextXAlignment.Right
countLabel.TextColor3 = Color3.new(1, 1, 1)
countLabel.TextStrokeTransparency = 0
countLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
countLabel.Text = ""
countLabel.Parent = holder
local countScale = Instance.new("UIScale")
countScale.Parent = countLabel

local tierLabel = Instance.new("TextLabel")
tierLabel.AnchorPoint = Vector2.new(1, 0)
tierLabel.Position = UDim2.new(1, 0, 0, 54)
tierLabel.Size = UDim2.new(1, 0, 0, 34)
tierLabel.BackgroundTransparency = 1
tierLabel.Font = Enum.Font.GothamBlack
tierLabel.TextScaled = true
tierLabel.TextXAlignment = Enum.TextXAlignment.Right
tierLabel.TextColor3 = Color3.fromRGB(255, 210, 90)
tierLabel.TextStrokeTransparency = 0
tierLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
tierLabel.Text = ""
tierLabel.Parent = holder

local totalLabel = Instance.new("TextLabel")
totalLabel.AnchorPoint = Vector2.new(1, 0)
totalLabel.Position = UDim2.new(1, 0, 0, 92)
totalLabel.Size = UDim2.new(1, 0, 0, 20)
totalLabel.BackgroundTransparency = 1
totalLabel.Font = Enum.Font.GothamBold
totalLabel.TextSize = 16
totalLabel.TextXAlignment = Enum.TextXAlignment.Right
totalLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
totalLabel.TextStrokeTransparency = 0.3
totalLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
totalLabel.Text = ""
totalLabel.Parent = holder

local ALL_LABELS = { countLabel, tierLabel, totalLabel }

local streak = 0
local totalDamage = 0
local lastHitAt = 0
local hideGeneration = 0

local function currentTier()
	local tiers = ComboConfig.STREAK_TIERS
	local picked = tiers[1]
	for _, tier in ipairs(tiers) do
		if streak >= tier.min then picked = tier end
	end
	return picked
end

local function scheduleHide()
	hideGeneration += 1
	local myGeneration = hideGeneration
	task.delay(ComboConfig.COMBO_RESET_TIME, function()
		if myGeneration ~= hideGeneration then return end
		streak, totalDamage = 0, 0
		for _, label in ipairs(ALL_LABELS) do
			TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		end
		task.delay(0.3, function()
			if myGeneration ~= hideGeneration then return end
			holder.Visible = false
			for _, label in ipairs(ALL_LABELS) do label.TextTransparency = 0 end
		end)
	end)
end

local function refresh()
	local tier = currentTier()
	countLabel.Text = string.format("%d HITS", streak)
	countLabel.TextColor3 = tier.color
	tierLabel.Text = tier.label
	tierLabel.TextColor3 = tier.color
	totalLabel.Text = "TOTAL DAMAGE: " .. tostring(math.floor(totalDamage + 0.5))
	holder.Visible = true
	for _, label in ipairs(ALL_LABELS) do label.TextTransparency = 0 end
	countScale.Scale = 1.35
	TweenService:Create(countScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	scheduleHide()
end

if comboRemote then
	comboRemote.OnClientEvent:Connect(function(count)
		local now = tick()
		if not count or count <= 0 then
			streak, totalDamage = 0, 0
			holder.Visible = false
			return
		end
		if now - lastHitAt > ComboConfig.COMBO_RESET_TIME then
			streak, totalDamage = 0, 0
		end
		lastHitAt = now
		streak += 1
		if streak >= ComboConfig.STREAK_MIN_DISPLAY then
			refresh()
		end
	end)
end

damageEvent.OnClientEvent:Connect(function(_position, amount, kind)
	if kind == "incoming" then return end
	totalDamage += amount
	if streak >= ComboConfig.STREAK_MIN_DISPLAY then
		totalLabel.Text = "TOTAL DAMAGE: " .. tostring(math.floor(totalDamage + 0.5))
	end
end)

print("[HitStreakGui] Escalating hit-streak banner enabled")
