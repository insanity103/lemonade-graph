local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local tool = script.Parent
local handle = tool:WaitForChild("Handle")
local slashSound = handle:WaitForChild("SwordSlash")
local unsheathSound = handle:WaitForChild("Unsheath")

local AnimationController = require(ReplicatedStorage:WaitForChild("AnimationController"))

local COOLDOWN = 0.5
local lastSwing = 0

local function onActivated()
	local now = tick()
	if now - lastSwing < COOLDOWN then
		return
	end
	lastSwing = now

	slashSound:Play()
	AnimationController.Play("Sword Attack Animation")
end

local function onEquipped()
	unsheathSound:Play()
end

tool.Activated:Connect(onActivated)
tool.Equipped:Connect(onEquipped)
