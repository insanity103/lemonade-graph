local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local ACTION_NAME = "Attack"
local HEAVY_ACTION_NAME = "HeavyAttack"

-- The charged heavy attack's client half: the charge pose, the blade and ground cues, the bar,
-- and the release. It owns no rule -- the server measures the charge and decides what it is
-- worth. Bound here rather than on the Tool because Tool.Activated is a click: one event, with
-- no press and no release, and a charge needs both edges.
local HeavyCharge = require(ReplicatedStorage:WaitForChild("HeavyCharge"))

local attackRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("EnemyAttack")

-- Enemy bodies (walk cycle, weapon swings) are posed on this client from replicated state.
require(ReplicatedStorage:WaitForChild("EnemyAnimator")).start()
-- The town's service NPCs (merchant, quest giver...) stand at their posts with a living idle.
require(ReplicatedStorage:WaitForChild("NpcAnimator")).start()

-- STUDIO ONLY, and it is a capture fix, not a feature. GuiShowcase's client half -- the camera
-- lock, the HUD hide and the ctx.swing / ctx.chain / ctx.hold listeners -- only exists once SOME
-- LocalScript has required that module, and the scripts that do are the GUI panels (MainMenuGui,
-- QuestGui, VaultGui, ...), each behind its own WaitForChild chain. There is no rule about when
-- they get there. Round 2 of the chain piece added a readiness handshake so the server stops
-- staging into a client that is not listening; round 3 still filmed an idle character with the
-- HUD up, because after twenty seconds the handshake gives up and stages anyway -- the panels
-- had simply not required it yet. A capture must not depend on which GUI happened to load first,
-- so this requires it outright, in a spawn so nothing below waits on it. On a live server
-- IsStudio() is false, this line never runs, and the module stays inert exactly as before.
if game:GetService("RunService"):IsStudio() then
	task.spawn(function()
		require(ReplicatedStorage:WaitForChild("GuiShowcase"))
	end)
end

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
	-- One body, one swing: a light attack thrown while the heavy is charging would draw the M1
	-- clip over the charge pose, and the server drops it anyway (a charge is open, so
	-- performComboSwing returns). Hold the heavy or throw an M1, not both.
	if HeavyCharge.charging() then
		return
	end
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

-- The heavy: HOLD to charge, RELEASE to swing.
--
-- R, ButtonY and a touch button of its own, none of which the light attack uses -- that is
-- MouseButton1 / E / ButtonX, and all three are left exactly as they were. The right mouse
-- button is deliberately not taken: holding it is how a Roblox player turns the camera, and a
-- heavy that spins the view every time it is charged is a heavy nobody will charge.
local function handleHeavy(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		HeavyCharge.press()
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		HeavyCharge.release()
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction(ACTION_NAME, handleAttack, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
ContextActionService:SetTitle(ACTION_NAME, "Attack")
ContextActionService:SetPosition(ACTION_NAME, UDim2.fromScale(0.82, 0.85))

ContextActionService:BindAction(HEAVY_ACTION_NAME, handleHeavy, true, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle(HEAVY_ACTION_NAME, "Heavy")
ContextActionService:SetPosition(HEAVY_ACTION_NAME, UDim2.fromScale(0.70, 0.82))

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		fireAttack()
	end
end)

print("[CombatController] Attack controls enabled (Left Click / E; hold R for heavy)")

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
