local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local xpEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("XPGain")

local RISE_INFO = TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PULSE_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true)

local function showXP(position, amount)
	local part = Instance.new("Part")
	part.Size = Vector3.new(1, 1, 1)
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Position = position
	part.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 150, 0, 60)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = part
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.SourceSansBold
	label.TextScaled = true
	label.Text = "+" .. tostring(math.round(amount)) .. " XP"
	label.TextColor3 = Color3.new(0.4, 1, 0.5)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = billboard

	-- pulse as combat ends
	local pulse = TweenService:Create(label, PULSE_INFO, { Size = UDim2.new(1.25, 0, 1.25, 0) })
	pulse:Play()

	-- rise from the feet
	local rise = TweenService:Create(billboard, RISE_INFO, { StudsOffset = Vector3.new(0, 5, 0) })
	rise:Play()

	-- fade out once it has risen
	task.delay(1.0, function()
		local fade = TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 })
		fade:Play()
		fade.Completed:Connect(function()
			part:Destroy()
		end)
	end)
end

xpEvent.OnClientEvent:Connect(function(position, amount)
	showXP(position, amount)
end)

print("[XPGainUI] XP gain numbers enabled")
