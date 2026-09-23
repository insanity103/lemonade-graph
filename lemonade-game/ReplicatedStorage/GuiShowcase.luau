--// GuiShowcase  (Studio-only, hands-free panel opener for automated GUI screenshots)
--
-- Set in edit mode, before pressing Play:
--     workspace:SetAttribute("GuiShowcase", "Inventory")
-- Attributes set in edit mode are copied into the play session, so the client opens the named
-- panel with no keyboard or mouse, and a screen grab of the Studio window shows it. Clear the
-- attribute afterwards. Nothing here runs outside Studio: RunService:IsStudio() is false on
-- live servers, so production players never see it.
--
-- Two kinds of target:
--   * Panel targets: a GUI script calls GuiShowcase.register(name, open) with its own opener.
--   * NPC targets (NPC_TARGETS below): open the real way. The character is moved in front of the
--     NPC's map marker and its ProximityPrompt is pressed, so the server sends its normal
--     payload (shop stock, vault contents) exactly as when a player walks up.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GuiShowcase = {}

local SETTLE = 4 -- [TUNING] seconds after data loads, so HUD intro tweens finish before a capture

-- Allowlist, deliberately. The Skill Trainer's prompt spends gold on a respec, so it is never here.
local NPC_TARGETS = {
	Shop = { marker = "Merchant", action = "Browse Relic Swords" },
	Vault = { marker = "Vaultkeeper", action = "Open Vault" },
	RebirthStation = { marker = "RebirthKeeper", action = "Rebirth" },
	QuestGiver = { marker = "QuestMaster", action = "Talk" },
}

local function target(): string?
	if not RunService:IsStudio() or not RunService:IsClient() then
		return nil
	end
	local name = workspace:GetAttribute("GuiShowcase")
	return if typeof(name) == "string" and name ~= "" then name else nil
end

local function afterDataLoaded(fn: () -> ())
	local player = Players.LocalPlayer
	task.spawn(function()
		local deadline = os.clock() + 30
		while player:GetAttribute("DataLoaded") ~= true and os.clock() < deadline do
			task.wait(0.25)
		end
		task.wait(SETTLE)
		fn()
	end)
end

-- Called by each panel script with its own opener; runs once if the showcase names that panel.
function GuiShowcase.register(name: string, open: () -> ())
	if target() == name then
		afterDataLoaded(open)
	end
end

-- Motion captures: set the target to "Motion:<name>". Once the world has settled, a solid
-- magenta frame flashes full-screen for a quarter second (a clapperboard: gx.py motion finds it
-- in the recording and counts time from it), then `play` runs the animation being judged.
-- Spawning, loading and the camera settling all move the screen too, so without the flash
-- nothing marks where the animation starts. `prepare`, if given, runs before the flash to put the
-- element in the state a player would have it in just before the movement (a hovered button), so
-- that state is already settled when the strip's clock starts.
local MOTION_SETTLE = 6 -- [TUNING] extra seconds after data loads before the clapperboard
local CLAPPER = Color3.fromRGB(255, 0, 255)

function GuiShowcase.motion(name: string, play: () -> (), prepare: (() -> ())?)
	if target() ~= "Motion:" .. name then
		return
	end
	afterDataLoaded(function()
		task.wait(MOTION_SETTLE)
		if prepare then
			prepare()
			task.wait(0.3)
		end
		local gui = Instance.new("ScreenGui")
		gui.Name = "GuiShowcaseClapper"
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 10000
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = CLAPPER
		flash.BorderSizePixel = 0
		flash.Parent = gui
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		task.wait(0.25)
		gui:Destroy()
		task.wait(0.5)
		play()
	end)
end

-- Character motions (an enemy's attack, a hit, a death) happen in the world, so the server stages
-- them: GuiShowcase.stage(name, stage) runs `stage(ctx)` on the server once the player has loaded,
-- only in Studio and only when the target is "Motion:<name>". The ctx puts the subject in view
-- (ctx.camera locks the client camera through a workspace attribute, see the client half below),
-- fires the same magenta clapperboard (ctx.clapper, which also waits the half second before the
-- motion), and tracks anything spawned (ctx.track) so it is destroyed when the stage returns.
-- It never grants XP, gold, drops or quest progress: it only places things and waits.
local CAMERA_ATTRIBUTE = "GuiShowcaseCamera"
local SWING_ATTRIBUTE = "GuiShowcaseSwing" -- player attribute; each change is one sword swing
local WALK_ATTRIBUTE = "GuiShowcaseWalkTo" -- player attribute; a Vector3 the character walks to

local function serverTarget(): string?
	if not RunService:IsStudio() or not RunService:IsServer() then
		return nil
	end
	local name = workspace:GetAttribute("GuiShowcase")
	return if typeof(name) == "string" and name ~= "" then name else nil
end

local function showClapper(player: Player)
	local gui = Instance.new("ScreenGui")
	gui.Name = "GuiShowcaseClapper"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10000
	gui.ResetOnSpawn = false
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = CLAPPER
	flash.BorderSizePixel = 0
	flash.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	task.wait(0.25)
	gui:Destroy()
	task.wait(0.5)
end

function GuiShowcase.stage(name: string, stage: (ctx: any) -> ())
	if serverTarget() ~= "Motion:" .. name then
		return
	end
	task.spawn(function()
		local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
		local deadline = os.clock() + 30
		while player:GetAttribute("DataLoaded") ~= true and os.clock() < deadline do
			task.wait(0.25)
		end
		local character = player.Character or player.CharacterAdded:Wait()
		local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart
		task.wait(SETTLE)

		local spawned = {}
		local ctx = { player = player, character = character, root = root }
		function ctx.track(instance: Instance): Instance
			table.insert(spawned, instance)
			return instance
		end
		-- Stand the player's character at `cframe` (its root), facing along its look vector.
		function ctx.place(cframe: CFrame)
			character:PivotTo(cframe)
			root.AssemblyLinearVelocity = Vector3.zero
		end
		function ctx.camera(cframe: CFrame?)
			workspace:SetAttribute(CAMERA_ATTRIBUTE, cframe)
		end
		function ctx.clapper()
			showClapper(player)
		end
		-- Swing the player's equipped sword for real: the client presses tool:Activate(), exactly
		-- as a click does, so the swing, the hit and every hit effect run their normal code paths.
		local swings = 0
		function ctx.swing()
			swings += 1
			player:SetAttribute(SWING_ATTRIBUTE, swings)
		end
		-- Walk the player's character to `position` on its own legs: the client calls
		-- Humanoid:MoveTo, exactly as a click-to-move does, so it moves at its real walk speed.
		function ctx.walkTo(position: Vector3)
			player:SetAttribute(WALK_ATTRIBUTE, position)
		end
		-- Hold a sword (the first one in the backpack) if the character is not already holding one.
		function ctx.equipSword(): Tool?
			local held = character:FindFirstChildOfClass("Tool")
			if held then
				return held
			end
			local backpack = player:FindFirstChildOfClass("Backpack")
			local tool = backpack and backpack:FindFirstChildOfClass("Tool")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if tool and humanoid then
				humanoid:EquipTool(tool)
			end
			return tool
		end

		print("[GuiShowcase] staging " .. name)
		local ok, err = pcall(stage, ctx)
		if not ok then
			warn("[GuiShowcase] stage " .. name .. " failed: " .. tostring(err))
		end
		for _, instance in ipairs(spawned) do
			if instance.Parent then
				instance:Destroy()
			end
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = humanoid.MaxHealth
		end
		workspace:SetAttribute(CAMERA_ATTRIBUTE, nil)
		player:SetAttribute(SWING_ATTRIBUTE, nil)
		player:SetAttribute(WALK_ATTRIBUTE, nil)
		print("[GuiShowcase] stage " .. name .. " done")
	end)
end

local function findMarker(markerName: string): BasePart?
	local map = workspace:WaitForChild("LemonadeMap", 30)
	local markers = map and map:WaitForChild("Markers", 30)
	local npcs = markers and markers:WaitForChild("NPCs", 30)
	local marker = npcs and npcs:WaitForChild(markerName, 30)
	return if marker and marker:IsA("BasePart") then marker else nil
end

local function findPrompt(action: string, near: Vector3): ProximityPrompt?
	local best, bestDistance = nil, math.huge
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.ActionText == action and d.Parent and d.Parent:IsA("BasePart") then
			local distance = (d.Parent.Position - near).Magnitude
			if distance < bestDistance then
				best, bestDistance = d, distance
			end
		end
	end
	return best
end

local function pressNpcPrompt(spec)
	local marker = findMarker(spec.marker)
	if not marker then
		warn("[GuiShowcase] no NPC marker " .. spec.marker)
		return
	end
	local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	-- Stand six studs in front of the NPC, facing it: the NPC faces along the marker's LookVector.
	local front = marker.Position + marker.CFrame.LookVector * 6 + Vector3.new(0, 3, 0)
	root.CFrame = CFrame.lookAt(front, Vector3.new(marker.Position.X, front.Y, marker.Position.Z))
	task.wait(1) -- let the NPC model stream in and the prompt register as in range
	local prompt = findPrompt(spec.action, marker.Position)
	if not prompt then
		warn("[GuiShowcase] no '" .. spec.action .. "' prompt near " .. spec.marker)
		return
	end
	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.1)
	prompt:InputHoldEnd()
end

-- Requiring the module arms NPC targets; panel targets wait for their script to register.
local armed = target()
if armed and NPC_TARGETS[armed] then
	afterDataLoaded(function()
		pressNpcPrompt(NPC_TARGETS[armed])
	end)
end

-- Client half of GuiShowcase.stage: while the server publishes a camera CFrame, hold the camera
-- there every frame (after the default camera scripts) so it cannot drift; hand it back after.
if armed and string.sub(armed, 1, 7) == "Motion:" then
	-- While the camera is held, the HUD is hidden too (it would cover the subject); every screen GUI
	-- hidden here is re-enabled when the stage hands the camera back.
	local locked = false
	local hidden = {}
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	RunService:BindToRenderStep("GuiShowcaseCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		local cframe = workspace:GetAttribute(CAMERA_ATTRIBUTE)
		if typeof(cframe) == "CFrame" then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.FieldOfView = 70
			camera.CFrame = cframe
			locked = true
			for _, gui in ipairs(playerGui:GetChildren()) do
				-- A GUI that sets the attribute GuiShowcaseKeep stays up while the camera is held:
				-- it is the thing being captured, not chrome in the way of it (the drop card).
				if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "GuiShowcaseClapper"
					and gui:GetAttribute("GuiShowcaseKeep") ~= true then
					gui.Enabled = false
					hidden[gui] = true
				end
			end
		elseif locked then
			camera.CameraType = Enum.CameraType.Custom
			locked = false
			for gui in pairs(hidden) do
				if gui.Parent then
					gui.Enabled = true
				end
			end
			table.clear(hidden)
		end
	end)
	-- ctx.swing: press the held sword the same way CombatController does for a click.
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal(SWING_ATTRIBUTE):Connect(function()
		if player:GetAttribute(SWING_ATTRIBUTE) == nil then
			return
		end
		local character = player.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		if tool then
			tool:Activate()
		end
	end)
	-- ctx.walkTo: walk the character there on its own legs.
	player:GetAttributeChangedSignal(WALK_ATTRIBUTE):Connect(function()
		local position = player:GetAttribute(WALK_ATTRIBUTE)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if typeof(position) == "Vector3" and humanoid then
			humanoid:MoveTo(position)
		end
	end)
end

return GuiShowcase
