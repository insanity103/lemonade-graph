local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local goldEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("GoldGain")

local TWEEN_INFO = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function showGold(position, amount)
	local part = Instance.new("Part")
	part.Size = Vector3.new(1, 1, 1)
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Position = position
	part.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 140, 0, 50)
	-- Up and to the RIGHT of whatever paid it: dead centre is where the drop reveal lands, and
	-- a gold number and a sword reveal on the same pixels read as neither.
	billboard.StudsOffset = Vector3.new(2.6, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = part
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.SourceSansBold
	label.TextScaled = true
	label.Text = "+" .. tostring(math.round(amount)) .. " Gold"
	label.TextColor3 = Color3.fromRGB(255, 215, 0)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = billboard

	local rise = TweenService:Create(billboard, TWEEN_INFO, { StudsOffset = Vector3.new(3.4, 9, 0) })
	rise:Play()

	local fade = TweenService:Create(label, TWEEN_INFO, { TextTransparency = 1 })
	fade:Play()
	fade.Completed:Connect(function()
		part:Destroy()
	end)
end

goldEvent.OnClientEvent:Connect(function(position, amount)
	showGold(position, amount)
end)

print("[GoldNumbers] Floating gold numbers enabled")
