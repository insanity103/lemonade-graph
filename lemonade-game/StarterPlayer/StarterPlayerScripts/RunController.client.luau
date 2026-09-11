local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local WALK_SPEED = 16
local RUN_SPEED = 26
local ACTION_NAME = "Run"

local humanoid

local function setHumanoid(character)
	humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = WALK_SPEED
end

local function handleRun(_, inputState)
	if not humanoid then
		return Enum.ContextActionResult.Pass
	end

	if inputState == Enum.UserInputState.Begin then
		humanoid.WalkSpeed = RUN_SPEED
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		humanoid.WalkSpeed = WALK_SPEED
	end

	return Enum.ContextActionResult.Sink
end

if player.Character then
	setHumanoid(player.Character)
end

player.CharacterAdded:Connect(setHumanoid)
ContextActionService:BindAction(ACTION_NAME, handleRun, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle(ACTION_NAME, "Run")
ContextActionService:SetPosition(ACTION_NAME, UDim2.fromScale(0.82, 0.72))
