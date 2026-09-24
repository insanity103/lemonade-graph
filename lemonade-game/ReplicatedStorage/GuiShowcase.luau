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
-- A camera that TRACKS the character instead of standing still. Two world-space offsets from the
-- character's root -- where the lens sits and what it looks at -- so a moment that travels (a
-- swing thrown at a run) stays framed the same way from the first frame to the last, and the
-- ground slides underneath rather than the subject sliding out of shot. The offsets are world
-- vectors, computed once by the stage from the direction it sends the character, so the camera
-- never swings around when the character turns.
local FOLLOW_FROM_ATTRIBUTE = "GuiShowcaseFollowFrom"
local FOLLOW_AT_ATTRIBUTE = "GuiShowcaseFollowAt"
local SWING_ATTRIBUTE = "GuiShowcaseSwing" -- player attribute; each change is one sword swing
local WALK_ATTRIBUTE = "GuiShowcaseWalkTo" -- player attribute; a Vector3 the character walks to
local HOLD_ATTRIBUTE = "GuiShowcaseHold"   -- player attribute; hold the sword guard pose, dead still
local CHAIN_ATTRIBUTE = "GuiShowcaseChain" -- player attribute; Vector2(nth call, hits to throw on the beat)
local HEAVY_ATTRIBUTE = "GuiShowcaseHeavy" -- player attribute; Vector2(nth call, seconds to hold the
                                           -- heavy attack's button down before letting go)
-- Player attribute, raised by the client half at the bottom of this file the moment its camera
-- lock is bound, and waited on by GuiShowcase.stage before it stages anything.
--
-- It exists because the two halves used to start on unrelated clocks and the stage lost the race.
-- The server half starts counting at DataLoaded; the client half only exists once SOME LocalScript
-- has required this module, and the scripts that do (MainMenuGui, QuestGui, VaultGui, ...) each
-- sit behind their own WaitForChild chain first. On a slow load the whole stage -- camera set, HUD
-- hidden, clapperboard, five swings, camera handed back -- could run and finish before the render
-- step that obeys the camera attribute was ever bound, and the capture came back as ordinary
-- third-person gameplay with the HUD up, with the server's own prints all correct. Nothing about
-- that was visible from the server, which is why it read as a camera bug for a round.
local READY_ATTRIBUTE = "GuiShowcaseReady"
local READY_TIMEOUT = 20 -- seconds; past this the stage runs anyway rather than hanging a capture

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
		-- Do not stage anything until the client's camera lock is actually bound (READY_ATTRIBUTE).
		local readyBy = os.clock() + READY_TIMEOUT
		while player:GetAttribute(READY_ATTRIBUTE) ~= true and os.clock() < readyBy do
			task.wait(0.1)
		end
		if player:GetAttribute(READY_ATTRIBUTE) ~= true then
			warn("[GuiShowcase] client camera lock never reported ready; staging anyway")
		end
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
		-- Track the character: the lens sits at root + `from` and looks at root + `at`, both world
		-- vectors, every frame. Pass nothing to hand the camera back.
		function ctx.follow(from: Vector3?, at: Vector3?)
			workspace:SetAttribute(FOLLOW_FROM_ATTRIBUTE, from)
			workspace:SetAttribute(FOLLOW_AT_ATTRIBUTE, at)
		end
		-- How fast the character moves on its own legs, for a stage that films motion. The server
		-- owns WalkSpeed, exactly as it does in play, and the client only obeys it.
		function ctx.speed(studsPerSecond: number)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = studsPerSecond
			end
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
		-- Throw a whole M1 chain ON THE BEAT, timed by the CLIENT.
		--
		-- ctx.swing() above is one press, and a stage that wants five presses used to make five
		-- of these calls with task.wait(ENDLAG) between them, on the server. That works and it
		-- measures nothing the server does not already own -- but every press then costs a full
		-- server -> attribute replication -> client -> Activated -> server round trip before the
		-- next wait even starts, and each of those is rounded up to a whole client frame. In a
		-- Studio play session rendering in the teens that is 100-200 ms a hit, it ACCUMULATES,
		-- and the filmed chain came out at 2.05 s against the 1.55 s the timing tables describe
		-- -- with the gaps stretched so unevenly that the one thing the cadence is built to show,
		-- 280 -> 238 -> 232 ms tightening into a 548 ms telegraph, was not in the footage at all.
		--
		-- So the client is told the whole chain once and presses it against ONE absolute clock:
		-- press i is due at t0 + sum(ENDLAG[1..i-1]), so a slow frame delays a single press
		-- instead of pushing every later press back with it, and the gaps stay the gaps. Nothing
		-- about what is measured changes -- the client still only presses, the server still
		-- times its own endlag from its own receipt and still decides every hit.
		local chains = 0
		function ctx.chain(hits: number)
			chains += 1
			player:SetAttribute(CHAIN_ATTRIBUTE, Vector2.new(chains, hits))
		end
		-- Charge the heavy attack for `hold` seconds and let go, through the REAL input path: the
		-- client calls the same HeavyCharge.press()/release() the R key calls, which sends the same
		-- two messages to the same remote, so the server measures the charge, the clip, the hitbox,
		-- the damage and every effect exactly as it would for a player holding the button.
		local heavies = 0
		function ctx.heavy(hold: number)
			heavies += 1
			player:SetAttribute(HEAVY_ATTRIBUTE, Vector2.new(heavies, hold))
		end
		-- Walk the player's character to `position` on its own legs: the client calls
		-- Humanoid:MoveTo, exactly as a click-to-move does, so it moves at its real walk speed.
		function ctx.walkTo(position: Vector3)
			player:SetAttribute(WALK_ATTRIBUTE, position)
		end
		-- Hold the sword guard pose, dead still, until something else drives the joints.
		--
		-- This is a CAPTURE device, not part of the moment being filmed. gx.py starts the
		-- filmstrip's clock at the first frame after the clapperboard that differs from the one
		-- before it; Roblox's stock idle never stops moving, so without this the clock starts on
		-- the idle's breathing and the strip runs out before the blade reaches the target -- which
		-- is exactly what the round-1 arc strip turned out to be. Held, the first thing that moves
		-- after the clapperboard is the swing.
		function ctx.hold()
			player:SetAttribute(HOLD_ATTRIBUTE, true)
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
		workspace:SetAttribute(FOLLOW_FROM_ATTRIBUTE, nil)
		workspace:SetAttribute(FOLLOW_AT_ATTRIBUTE, nil)
		player:SetAttribute(SWING_ATTRIBUTE, nil)
		player:SetAttribute(WALK_ATTRIBUTE, nil)
		player:SetAttribute(HOLD_ATTRIBUTE, nil)
		player:SetAttribute(HEAVY_ATTRIBUTE, nil)
		player:SetAttribute(CHAIN_ATTRIBUTE, nil)
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

-- Requiring the module arms NPC targets and Motion capture below. The attribute is set in edit
-- mode, before Play, so it is part of the client's very first replicated state -- but half a
-- dozen GUI LocalScripts require this module (MainMenuGui, QuestGui, VaultGui, ...) and Lua
-- caches a module's result on the FIRST require, so whichever of them runs first decides `armed`
-- for the whole client session. That first require can beat Workspace's attribute replication by
-- a frame or two, and a nil caught here is never rechecked -- the camera-lock block below only
-- ever reads this cached value. So, in Studio only, give the attribute a few frames to land
-- before deciding there is none; on a live server IsStudio() is false and this costs nothing.
local armed = target()
if not armed and RunService:IsStudio() and RunService:IsClient() then
	-- Three seconds, not ten frames. Ten frames is ten frames of whatever this session is
	-- rendering at, and a Studio client loading a town runs in the teens: the window was under a
	-- second and the attribute is replicated with the rest of Workspace's initial state, which on
	-- a slow load lands after it. A capture that silently films ordinary gameplay costs a whole
	-- round, so the window is a real one. It only ever elapses in full when nothing is armed.
	local deadline = os.clock() + 3
	repeat
		task.wait()
		armed = target()
	until armed or os.clock() > deadline
end
if RunService:IsStudio() and RunService:IsClient() then
	print("[GuiShowcase] client armed=" .. tostring(armed) .. " (first require by " .. tostring(debug.traceback():match("[%w_%.]+%.client") or "?") .. ")")
end
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
	-- The tracking camera's own smoothed position, so the character's per-step velocity ripple
	-- does not shake the lens. Seeded on the first frame, so there is no swoop into position.
	local followAt: Vector3? = nil
	RunService:BindToRenderStep("GuiShowcaseCamera", Enum.RenderPriority.Camera.Value + 1, function(delta)
		local camera = workspace.CurrentCamera
		local cframe = workspace:GetAttribute(CAMERA_ATTRIBUTE)
		local from = workspace:GetAttribute(FOLLOW_FROM_ATTRIBUTE)
		local at = workspace:GetAttribute(FOLLOW_AT_ATTRIBUTE)
		if typeof(from) == "Vector3" and typeof(at) == "Vector3" then
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local here = root.Position
				followAt = if followAt then followAt:Lerp(here, math.min(1, delta * 25)) else here
				cframe = CFrame.lookAt(followAt + from, followAt + at)
			end
		else
			followAt = nil
		end
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
	-- The lock is live from here on, so the server may stage. Until this lands, GuiShowcase.stage
	-- waits: see READY_ATTRIBUTE above.
	local player = Players.LocalPlayer
	player:SetAttribute(READY_ATTRIBUTE, true)
	-- ctx.swing: press the held sword the same way CombatController does for a click.
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
	-- ctx.chain: press the sword `hits` times on the beat, against one absolute clock (see
	-- ctx.chain on the server side above for why the server cannot do this itself). The press is
	-- the same tool:Activate() a click makes; the 35 ms is a real player's reaction margin past
	-- the endlag, inside ComboConfig.PERFECT_TIMING_WINDOW, so the chain is thrown the way a
	-- player on the beat throws it and the server grants the same perfect-timing bonus.
	player:GetAttributeChangedSignal(CHAIN_ATTRIBUTE):Connect(function()
		local ask = player:GetAttribute(CHAIN_ATTRIBUTE)
		if typeof(ask) ~= "Vector2" then
			return
		end
		task.spawn(function()
			local ComboConfig = require(script.Parent:WaitForChild("Config"):WaitForChild("ComboConfig"))
			local MARGIN = 0.035
			local start = os.clock()
			local due = 0
			for index = 1, math.floor(ask.Y) do
				while os.clock() < start + due do
					task.wait()
				end
				local character = player.Character
				local tool = character and character:FindFirstChildOfClass("Tool")
				if not tool then
					return
				end
				tool:Activate()
				due += (ComboConfig.ENDLAG[index] or 0.25) + MARGIN
			end
		end)
	end)
	-- ctx.hold: hold the guard pose through the same runtime that plays the swing, so the swing's
	-- fade-in blends out of the pose it was authored to start from and the stock idle's sway cannot
	-- be mistaken for the start of the moment being filmed.
	player:GetAttributeChangedSignal(HOLD_ATTRIBUTE):Connect(function()
		if player:GetAttribute(HOLD_ATTRIBUTE) == true then
			local AnimationController = require(script.Parent:WaitForChild("AnimationController"))
			AnimationController.Play("Sword Guard Hold")
		end
	end)
	-- ctx.heavy: hold the heavy attack's button for a while and let go, through the same two
	-- calls the R binding makes. Nothing here is a canned playback: the charge is timed by the
	-- server off the remote it sends, and the release plays the real clip and runs the real hitbox.
	player:GetAttributeChangedSignal(HEAVY_ATTRIBUTE):Connect(function()
		local ask = player:GetAttribute(HEAVY_ATTRIBUTE)
		if typeof(ask) ~= "Vector2" then
			return
		end
		task.spawn(function()
			local HeavyCharge = require(script.Parent:WaitForChild("HeavyCharge"))
			if HeavyCharge.press() then
				task.wait(ask.Y)
				HeavyCharge.release()
			end
		end)
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
