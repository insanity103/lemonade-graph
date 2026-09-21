-- LocalScript | StarterPlayerScripts.Notifications | Short feedback toasts for actions that succeed
-- or are refused (server fires RemoteEvents.Notify with message, kind). Every refused action
-- should say why instead of silently doing nothing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local notify = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Notify")

local LIFETIME = 3 -- [TUNING] seconds a toast stays readable
local FADE = 0.25
local MAX_VISIBLE = 4
local STYLES = {
	info = { text = Color3.fromRGB(236, 232, 222), stroke = Color3.fromRGB(110, 104, 96) },
	success = { text = Color3.fromRGB(160, 240, 170), stroke = Color3.fromRGB(70, 150, 90), sound = 0.9 },
	error = { text = Color3.fromRGB(255, 150, 135), stroke = Color3.fromRGB(170, 70, 60), sound = 0.6 },
}
local SOUND_ID = "rbxassetid://6042053626" -- the game's existing UI click, pitched per kind

local gui = Instance.new("ScreenGui")
gui.Name = "Notifications"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
-- A server-wide announce (a Legendary drop, a top-rung forge) is part of the moment a Studio
-- capture is filming, not chrome in the way of it, so it stays up while the camera is held.
gui:SetAttribute("GuiShowcaseKeep", true)
gui.Parent = player:WaitForChild("PlayerGui")

local stack = Instance.new("Frame")
stack.AnchorPoint = Vector2.new(0.5, 1)
stack.Position = UDim2.new(0.5, 0, 1, -120)
stack.Size = UDim2.fromOffset(420, 200)
stack.BackgroundTransparency = 1
stack.Parent = gui
local layout = Instance.new("UIListLayout")
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)
layout.Parent = stack

local order = 0

local function playSound(speed: number)
	local sound = Instance.new("Sound")
	sound.SoundId = SOUND_ID
	sound.PlaybackSpeed = speed
	sound.Volume = 0.5
	sound.Parent = gui
	sound:Play()
	sound.Ended:Once(function() sound:Destroy() end)
end

local function show(message: string, kind: string?)
	if typeof(message) ~= "string" or message == "" then return end
	local style = STYLES[kind or "info"] or STYLES.info
	order += 1

	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 34)
	label.BackgroundColor3 = Color3.fromRGB(22, 20, 18)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 16
	label.TextColor3 = style.text
	label.TextTransparency = 1
	label.Text = message
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	padding.Parent = label
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = style.stroke
	stroke.Transparency = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = label
	label.Parent = stack

	local toasts = {}
	for _, child in ipairs(stack:GetChildren()) do
		if child:IsA("TextLabel") then table.insert(toasts, child) end
	end
	table.sort(toasts, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	for i = 1, #toasts - MAX_VISIBLE do
		toasts[i]:Destroy()
	end

	local info = TweenInfo.new(FADE)
	TweenService:Create(label, info, { TextTransparency = 0, BackgroundTransparency = 0.15 }):Play()
	TweenService:Create(stroke, info, { Transparency = 0.2 }):Play()
	if style.sound then playSound(style.sound) end

	task.delay(LIFETIME, function()
		if not label.Parent then return end
		local out = TweenService:Create(label, info, { TextTransparency = 1, BackgroundTransparency = 1 })
		TweenService:Create(stroke, info, { Transparency = 1 }):Play()
		out.Completed:Once(function() label:Destroy() end)
		out:Play()
	end)
end

notify.OnClientEvent:Connect(show)
