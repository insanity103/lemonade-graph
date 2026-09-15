local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local ACTION_NAME = "Attack"

local attackRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("EnemyAttack")

-- Combo state tracking
local comboCount = 0
local comboEndTime = 0
local COMBO_RESET_TIME = 1.5

-- Combo counter HUD
local playerGui = player:WaitForChild("PlayerGui")
local combatGui = Instance.new("ScreenGui")
combatGui.Name = "CombatHud"
combatGui.ResetOnSpawn = false
combatGui.Parent = playerGui

local comboLabel = Instance.new("TextLabel")
comboLabel.Name = "ComboLabel"
comboLabel.Size = UDim2.new(0, 120, 0, 40)
comboLabel.Position = UDim2.fromScale(0.5, 0.09)
comboLabel.AnchorPoint = Vector2.new(0.5, 0)
comboLabel.BackgroundTransparency = 1
comboLabel.Font = Enum.Font.GothamBold
comboLabel.TextSize = 28
comboLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
comboLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
comboLabel.TextStrokeTransparency = 0.3
comboLabel.Text = ""
comboLabel.Visible = false
comboLabel.Parent = combatGui

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

-- ===================================================================
-- COMBO UPDATE LISTENER
-- ===================================================================
local comboRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):FindFirstChild("ComboUpdate")
if comboRemote then
	comboRemote.OnClientEvent:Connect(function(count)
		comboCount = count
		comboEndTime = tick() + COMBO_RESET_TIME

		local colors = {
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(255, 255, 200),
			Color3.fromRGB(255, 200, 80),
			Color3.fromRGB(255, 120, 50),
			Color3.fromRGB(255, 50, 50),
		}
		comboLabel.Text = tostring(count) .. "x COMBO"
		comboLabel.TextColor3 = colors[count] or colors[1]
		comboLabel.Visible = true

		-- Brief scale pulse animation
		comboLabel.TextSize = 36
		task.delay(0.1, function()
			comboLabel.TextSize = 28
		end)
	end)
end

-- Hide the counter once the combo window lapses.
RunService.Heartbeat:Connect(function()
	if comboCount > 0 and tick() > comboEndTime then
		comboCount = 0
		comboLabel.Visible = false
	end
end)

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
