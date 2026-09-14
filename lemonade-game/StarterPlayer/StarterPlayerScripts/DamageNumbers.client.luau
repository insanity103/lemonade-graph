local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local ComboConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ComboConfig"))

local damageEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("DamageNumber")

local currentCombo = 0

local comboRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):FindFirstChild("ComboUpdate")
if comboRemote then
	comboRemote.OnClientEvent:Connect(function(count)
		currentCombo = count
	end)
end

local TWEEN_INFO = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function showDamage(position, amount, kind)
	local part = Instance.new("Part")
	part.Size = Vector3.new(1, 1, 1)
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Position = position + Vector3.new((math.random() - 0.5) * 1.5, 0, (math.random() - 0.5) * 1.5)
	part.Parent = Workspace

	local isCrit = (kind == "crit")
	local billboard = Instance.new("BillboardGui")
	billboard.Size = isCrit and UDim2.new(0, 160, 0, 65) or UDim2.new(0, 120, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = part
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = isCrit and Enum.Font.GothamBlack or Enum.Font.SourceSansBold
	label.TextScaled = true

	if isCrit then
		label.Text = "CRIT! -" .. tostring(math.round(amount))
		label.TextColor3 = Color3.fromRGB(255, 60, 40)
	elseif kind == "incoming" then
		label.Text = "-" .. tostring(math.round(amount))
		label.TextColor3 = Color3.fromRGB(255, 70, 70)
	else
		label.Text = "-" .. tostring(math.round(amount))
		label.TextColor3 = Color3.fromRGB(255, 215, 60)
	end

	if currentCombo >= 3 and not isCrit and kind ~= "incoming" then
		label.Text = currentCombo .. "x " .. label.Text
		label.TextColor3 = ComboConfig.HUD_COLORS[currentCombo] or Color3.fromRGB(255, 255, 255)
	end

	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = billboard

	local targetOffset = isCrit and Vector3.new(0, 8.5, 0) or Vector3.new(0, 7, 0)
	local rise = TweenService:Create(billboard, TWEEN_INFO, { StudsOffset = targetOffset })
	rise:Play()

	local fade = TweenService:Create(label, TWEEN_INFO, { TextTransparency = 1 })
	fade:Play()
	fade.Completed:Connect(function()
		part:Destroy()
	end)
end

damageEvent.OnClientEvent:Connect(function(position, amount, kind)
	-- Respect the ShowDamageNumbers setting (defaults to true)
	if player:GetAttribute("ShowDamageNumbers") == false then
		return
	end
	showDamage(position, amount, kind)
end)

print("[DamageNumbers] Floating damage numbers with CRIT styling enabled")
