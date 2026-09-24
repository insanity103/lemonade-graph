local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local WALK_SPEED = 16
local RUN_SPEED = 26
local ACTION_NAME = "Run"

local humanoid

local running = false

local function setHumanoid(character)
	humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = WALK_SPEED
	-- The server writes WalkSpeed during combat (a hit's hitlag freezes it, then puts the walking
	-- speed back). That write replaces a sprint still being held, so the player dropped to a walk
	-- with Shift down. Take the sprint back when the server hands back plain walking speed.
	local h = humanoid
	h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if running and h == humanoid and h.WalkSpeed == WALK_SPEED then
			h.WalkSpeed = RUN_SPEED
		end
	end)
end

local function handleRun(_, inputState)
	if not humanoid then
		return Enum.ContextActionResult.Pass
	end

	if inputState == Enum.UserInputState.Begin then
		running = true
		humanoid.WalkSpeed = RUN_SPEED
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		running = false
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
