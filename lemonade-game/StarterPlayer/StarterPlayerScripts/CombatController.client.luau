local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local ACTION_NAME = "Attack"

local attackRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("EnemyAttack")
local toggleRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("ToggleAutoAttack")
local spendEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("SpendSkillPoint")

local autoAttackOn = false
local autoSkillOn = false
local autoAllocateSkillPoints

-- HUD showing auto-attack state
local playerGui = player:WaitForChild("PlayerGui")
local autoGui = Instance.new("ScreenGui")
autoGui.Name = "AutoAttackHud"
autoGui.ResetOnSpawn = false
autoGui.Parent = playerGui

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 200, 0, 30)
statusLabel.Position = UDim2.fromScale(0.5, 0.02)
statusLabel.AnchorPoint = Vector2.new(0.5, 0)
statusLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
statusLabel.BackgroundTransparency = 0.4
statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
statusLabel.Font = Enum.Font.SourceSans
statusLabel.TextSize = 18
statusLabel.Text = "Auto-Attack: OFF (Q)"
statusLabel.Parent = autoGui

local skillStatusLabel = Instance.new("TextLabel")
skillStatusLabel.Size = UDim2.new(0, 260, 0, 24)
skillStatusLabel.Position = UDim2.fromScale(0.5, 0.055)
skillStatusLabel.AnchorPoint = Vector2.new(0.5, 0)
skillStatusLabel.BackgroundTransparency = 1
skillStatusLabel.TextColor3 = Color3.fromRGB(180, 185, 200)
skillStatusLabel.Font = Enum.Font.SourceSans
skillStatusLabel.TextSize = 15
skillStatusLabel.Text = "Skill Points: manual (P to auto)"
skillStatusLabel.Parent = autoGui

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

local function setAutoAttack(on)
	autoAttackOn = on
	toggleRemote:FireServer(autoAttackOn)
	statusLabel.Text = autoAttackOn and "Auto-Attack: ON (Q)" or "Auto-Attack: OFF (Q)"
	statusLabel.TextColor3 = autoAttackOn and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 80, 80)
	print("[CombatController] Auto-attack " .. (autoAttackOn and "enabled" or "disabled"))
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
	if input.KeyCode == Enum.KeyCode.Q then
		setAutoAttack(not autoAttackOn)
	end
	if input.KeyCode == Enum.KeyCode.P then
		autoSkillOn = not autoSkillOn
		skillStatusLabel.Text = autoSkillOn and "Skill Points: auto (P)" or "Skill Points: manual (P to auto)"
		if autoSkillOn and (player:GetAttribute("SkillPoints") or 0) > 0 then
			task.spawn(autoAllocateSkillPoints)
		end
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		fireAttack()
	end
end)

print("[CombatController] Attack controls enabled (Left Click / E / Q)")

-- ===================================================================
-- OPTIONAL AUTO SKILL POINT ALLOCATION
-- Press P to distribute available points evenly across all attributes.
-- ===================================================================
local ALLOCATE_ATTRIBUTES = { "Strength", "Health", "Defense", "ExperienceGain" }
local isAllocating = false

autoAllocateSkillPoints = function()
	if isAllocating then
		return
	end
	isAllocating = true

	local points = player:GetAttribute("SkillPoints") or 0
	while points > 0 do
		if not autoSkillOn then
			break
		end
		local lowestAttr = ALLOCATE_ATTRIBUTES[1]
		local lowestVal = player:GetAttribute(lowestAttr) or 0

		for i = 2, #ALLOCATE_ATTRIBUTES do
			local attrName = ALLOCATE_ATTRIBUTES[i]
			local val = player:GetAttribute(attrName) or 0
			if val < lowestVal then
				lowestVal = val
				lowestAttr = attrName
			end
		end

		spendEvent:FireServer(lowestAttr)
		task.wait(0.05)
		points = player:GetAttribute("SkillPoints") or 0
	end

	isAllocating = false
end

player:GetAttributeChangedSignal("SkillPoints"):Connect(function()
	local points = player:GetAttribute("SkillPoints") or 0
	if points > 0 then
		if autoSkillOn then task.spawn(autoAllocateSkillPoints) end
	end
end)

-- ===================================================================
-- AUTO-ATTACK MOVEMENT & TARGETING CONTROLLER
-- Smoothly paths/moves player towards the closest living enemy,
-- faces them, and activates equipped weapon / attacks automatically.
-- ===================================================================
local TARGET_SEARCH_RANGE = 70
local ATTACK_REACH_DISTANCE = 6.5
local lastAutoSwingTime = 0
local AUTO_SWING_INTERVAL = 0.45

local function isLivingEnemy(model)
	if not model or not model:IsA("Model") then
		return false
	end
	if not (model:GetAttribute("Enemy") == true or CollectionService:HasTag(model, "Enemy")) then
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid.Health > 0
end

local function findClosestLivingEnemy(origin)
	local bestEnemy = nil
	local bestDist = TARGET_SEARCH_RANGE

	for _, enemy in ipairs(workspace:GetChildren()) do
		if isLivingEnemy(enemy) then
			local root = enemy.PrimaryPart or enemy:FindFirstChild("HumanoidRootPart")
			if root then
				local dist = (root.Position - origin).Magnitude
				if dist < bestDist then
					bestEnemy = enemy
					bestDist = dist
				end
			end
		end
	end

	return bestEnemy, bestDist
end

RunService.RenderStepped:Connect(function()
	if not autoAttackOn then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid or humanoid.Health <= 0 then
		return
	end

	local targetEnemy, dist = findClosestLivingEnemy(hrp.Position)
	if not targetEnemy then
		return
	end

	local targetHrp = targetEnemy.PrimaryPart or targetEnemy:FindFirstChild("HumanoidRootPart")
	if not targetHrp then
		return
	end

	-- Move towards enemy
	if dist > ATTACK_REACH_DISTANCE then
		humanoid:MoveTo(targetHrp.Position)
	else
		-- In attack distance: face enemy and stop sliding past
		humanoid:MoveTo(hrp.Position)
		local lookAtCFrame = CFrame.lookAt(hrp.Position, Vector3.new(targetHrp.Position.X, hrp.Position.Y, targetHrp.Position.Z))
		hrp.CFrame = lookAtCFrame
	end

	-- Trigger attacks on interval when within reach
	if dist <= (ATTACK_REACH_DISTANCE + 2) then
		local now = tick()
		if now - lastAutoSwingTime >= AUTO_SWING_INTERVAL then
			lastAutoSwingTime = now
			fireAttack()
		end
	end
end)
