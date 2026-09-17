local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local ACTION_NAME = "Attack"

local attackRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("EnemyAttack")

local playerGui = player:WaitForChild("PlayerGui")

local function getEquippedTool()
	local character = player.Character
	if not character then
		return nil
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			return child
		end
	end
	return nil
end

local function fireAttack()
	local tool = getEquippedTool()
	if tool then
		tool:Activate()
	else
		attackRemote:FireServer()
	end
end

local function handleAttack(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		fireAttack()
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction(ACTION_NAME, handleAttack, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
ContextActionService:SetTitle(ACTION_NAME, "Attack")
ContextActionService:SetPosition(ACTION_NAME, UDim2.fromScale(0.82, 0.85))

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		fireAttack()
	end
end)

print("[CombatController] Attack controls enabled (Left Click / E)")

-- Combo count display lives in HitStreakGui.client.luau now.

-- ===================================================================
-- HITLAG SCREEN EFFECT LISTENER
-- ===================================================================
local hitlagRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):FindFirstChild("HitlagEffect")
if hitlagRemote then
	hitlagRemote.OnClientEvent:Connect(function(duration)
		-- Screen freeze effect: brief vignette flash
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		flash.BackgroundTransparency = 0.85
		flash.BorderSizePixel = 0
		flash.ZIndex = 100
		flash.Parent = playerGui
		task.delay(duration, function()
			flash:Destroy()
		end)
	end)
end
