local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local tool = script.Parent
local handle = tool:WaitForChild("Handle")
-- Boss/merchant swords use a MeshPart handle with no sounds; look these up without
-- blocking so the Activated/Equipped handlers below always get connected.
local slashSound = handle:FindFirstChild("SwordSlash")
local unsheathSound = handle:FindFirstChild("Unsheath")

local AnimationController = require(ReplicatedStorage:WaitForChild("AnimationController"))

local COOLDOWN = 0.5
local lastSwing = 0

local function onActivated()
	local now = tick()
	if now - lastSwing < COOLDOWN then
		return
	end
	lastSwing = now

	if slashSound then
		slashSound:Play()
	end
	AnimationController.Play("Sword Attack Animation")
end

local function onEquipped()
	if unsheathSound then
		unsheathSound:Play()
	end
end

tool.Activated:Connect(onActivated)
tool.Equipped:Connect(onEquipped)
