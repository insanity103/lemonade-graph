-- StarterPlayerScripts/HitStreakGui.client.luau
-- Escalating on-screen hit-streak banner: "{N} HITS" + a tier callout (GREAT, SAVAGE,
-- BRUTAL, GODLIKE) and a running total-damage readout. This counts every landed hit
-- without wrapping, unlike SwordSystem's 5-hit endlag/damage-mult cycle -- it exists
-- purely to make a long run of hits feel escalating on screen.
-- It counts on HitlagEffect, the one message the server sends only for a hit that landed, and
-- only to the attacker (with that hit's damage). It used to count ComboUpdate, which fires on
-- every swing, so cutting air in the safe hub read "3 HITS / TOTAL DAMAGE: 0", and it totalled
-- DamageNumber, which goes to every player, so a friend's hits were added to yours.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ComboConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ComboConfig"))
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local comboRemote = remotes:FindFirstChild("ComboUpdate")
local hitlagRemote = remotes:WaitForChild("HitlagEffect")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HitStreakGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Parent = playerGui

-- Just left of the crosshair, vertically centred. It used to sit left of the right-edge nav rail,
-- which is where the quest tracker hangs (QuestGui, top-right, down to ~y 400), so a long streak
-- drew its "27 HITS / SAVAGE" straight over the quest text (recording 2026-09-24, 0:03 and 3:39).
local holder = Instance.new("Frame")
holder.AnchorPoint = Vector2.new(1, 0.5)
holder.Position = UDim2.new(0.5, -90, 0.5, -60)
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
	if totalDamage <= 0 then
		return -- nothing has landed yet: no banner for air
	end
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

-- ComboUpdate is kept for one thing: the server's reset. It sends (0, 0) on death; a heavy
-- release also sends a 0 count but with its endlag as the second value, and must not wipe a run.
if comboRemote then
	comboRemote.OnClientEvent:Connect(function(count, endlag)
		if (not count or count <= 0) and (not endlag or endlag <= 0) then
			streak, totalDamage = 0, 0
			holder.Visible = false
		end
	end)
end

hitlagRemote.OnClientEvent:Connect(function(_duration, _comboIndex, _contact, _hold, _kick, damage)
	local now = tick()
	if now - lastHitAt > ComboConfig.COMBO_RESET_TIME then
		streak, totalDamage = 0, 0
	end
	lastHitAt = now
	streak += 1
	if typeof(damage) == "number" then
		totalDamage += damage
	end
	if streak >= ComboConfig.STREAK_MIN_DISPLAY then
		refresh()
	end
end)

print("[HitStreakGui] Escalating hit-streak banner enabled")
