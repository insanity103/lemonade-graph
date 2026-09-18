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

return GuiShowcase
