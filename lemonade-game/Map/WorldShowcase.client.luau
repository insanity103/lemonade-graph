-- LocalScript | StarterPlayerScripts.WorldShowcase | Map project only, Studio only.
-- Fixed viewpoints for world-art captures (see ReplicatedStorage.GuiShowcase). Set in edit mode,
-- before pressing Play:
--     workspace:SetAttribute("GuiShowcase", "WorldDay")
-- Once the player's data has loaded, this holds the time of day the shot needs (locally, every
-- frame, so the server clock cannot drift it), stands the player's character where the shot wants
-- it, streams the view in, locks the camera and hides every HUD layer. Nothing here runs outside
-- Studio (GuiShowcase.register is inert unless RunService:IsStudio() and the attribute names the
-- view), and nothing replicates except the character's own position.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))

local STREAM_SETTLE = 3 -- [TUNING] seconds after the view is placed, for streaming and shadows
local TOUR_STEP = 6 -- seconds per stop of a framing tour (see GuiShowcaseTour below)

-- clock: Lighting.ClockTime to hold. stand: the character's root position and a point it faces.
-- camera: eye position and look-at point. fov: vertical field of view in degrees.
local VIEWS = {
	-- Hearthmere in mid afternoon, over a player's shoulder: on the main path north of the Sword Monument,
	-- the Quest stall and houses on the left, the campfire lawn on the right, and the path running
	-- out through the Iron Lowlands gate toward the far country, like Arcane Odyssey's harbour frame.
	-- The lens tilts about 5.5 degrees up, so over the level walls a band of the three far ranges and the
	-- Sunspire's wooded hill (LemonadeMap.Horizon) show, with open sky and cumulus above them.
	WorldDay = {
		clock = 15.3,
		stand = { at = Vector3.new(1, 13.4, 36), face = Vector3.new(2, 13.4, 140) },
		camera = { at = Vector3.new(-1, 20, 13), look = Vector3.new(0, 32.4, 140) },
		fov = 66,
	},
	-- Hearthmere at golden hour (WorldLook's dusk phase), framed like Arcane Odyssey's harbour at
	-- sunset: on the west road just past the plaza, looking west down the cobbles to the barred
	-- Frostbound gate with the low sun blazing through its bars and the ridge's saddle behind, the
	-- bars' long shadows striping the road toward the lens, the Sword Shop's stone front on the right
	-- catching the raking light (the reference's sunlit wall), the player on the road facing the camera.
	WorldSunset = {
		clock = 17.2,
		stand = { at = Vector3.new(-35, 13.4, -5), face = Vector3.new(-22, 13.4, -12) },
		camera = { at = Vector3.new(-22, 15, -12), look = Vector3.new(-100, 24, -4) },
		fov = 66,
	},
	-- Hearthmere's High Street at WorldDay's light, framed like Arcane Odyssey's Palo Town frame: a
	-- lens at head height at the plaza end of the street, looking north up it to the Ascension Gate.
	-- The afternoon sun comes from behind the lens's left shoulder (west-south-west), so the east
	-- row's shopfronts on the right and every face toward the lens are sunlit, while the low west row
	-- on the left throws its eaves' and gables' shadows across the cobbles. The fruit stall, signpost,
	-- waystone and spawn runes stand in the foreground, bunting crosses the street, and the gate's
	-- marble stair closes the view. The player walks the street ahead of the lens.
	WorldTown = {
		clock = 15.3,
		stand = { at = Vector3.new(4, 13.6, -46), face = Vector3.new(3, 13.6, -120) },
		camera = { at = Vector3.new(-3, 16.8, -27), look = Vector3.new(2, 21, -100) },
		fov = 50,
	},
	-- The Iron Lowlands desert oasis at WorldDay's light, framed like Alex's reference frame: a lens
	-- at a player's eye height on the rim's sand at the tent camp's open west side, looking east
	-- between the two flanking tents, across the fire and table to the adobe street, whose sunlit
	-- west fronts face the lens, the town spring's palms and water on the right, and the striped rock
	-- towers rising out of the dunes behind. The player stands by the fire in front of the houses, so
	-- the doors (about 1.5 times the player's height) and storeys read at their true scale. The
	-- afternoon sun sits behind the lens, so every face toward it is lit.
	WorldOasis = {
		clock = 15.3,
		stand = { at = Vector3.new(75, 13.6, 213), face = Vector3.new(34, 13.6, 204) },
		camera = { at = Vector3.new(32, 16.5, 203), look = Vector3.new(110, 22, 224) },
		fov = 52,
		hideEnemies = true, -- the bandits wandering the rim would stand in front of the lens
	},
	-- Three more Iron Lowlands angles (Alex, 2026-09-24: "show other angles of the area too"), so a
	-- round judges the whole zone, not one camp. Same afternoon clock, enemies hidden.
	-- The basin from the town gate: the trail dropping from the overlook into the pit, the scarp
	-- and the far mesas closing the view south.
	WorldBasin = {
		clock = 15.3,
		stand = { at = Vector3.new(6, 13.6, 150), face = Vector3.new(0, 13.6, 300) },
		camera = { at = Vector3.new(-14, 30, 118), look = Vector3.new(4, 14, 330) },
		fov = 58,
		hideEnemies = true,
	},
	-- The east mesa and the rock towers from the basin floor, the oasis palms at the foot.
	WorldMesas = {
		clock = 15.3,
		stand = { at = Vector3.new(40, 5.6, 330), face = Vector3.new(204, 5.6, 404) },
		camera = { at = Vector3.new(14, 12, 318), look = Vector3.new(190, 52, 400) },
		fov = 56,
		hideEnemies = true,
	},
	-- The Warden's pit: the spine and the gap at the south end of the basin, from the trail.
	WorldPit = {
		clock = 15.3,
		stand = { at = Vector3.new(-18, 5.6, 300), face = Vector3.new(0, 5.6, 360) },
		camera = { at = Vector3.new(-42, 18, 276), look = Vector3.new(8, 8, 372) },
		fov = 56,
		hideEnemies = true,
	},
	-- The west side: the bandits' hideout passage under its arch (x -165..-110, z 270..330) and the
	-- west mesa behind, from the basin floor.
	WorldWest = {
		clock = 15.3,
		stand = { at = Vector3.new(-30, 5.6, 300), face = Vector3.new(-160, 5.6, 300) },
		camera = { at = Vector3.new(-6, 24, 296), look = Vector3.new(-160, 34, 302) }, -- raised over the minecart on the trail
		fov = 58,
		hideEnemies = true,
	},
	-- Looking back north from the pit to the overlook and the town gate above it.
	WorldNorth = {
		clock = 15.3,
		stand = { at = Vector3.new(14, 5.6, 380), face = Vector3.new(0, 5.6, 110) },
		camera = { at = Vector3.new(24, 26, 420), look = Vector3.new(0, 30, 110) }, -- pulled back past the pit's props
		fov = 58,
		hideEnemies = true,
	},
	-- Hearthmere's boundary wall (the castle-wall gauntlet piece), framed from inside the town: a
	-- lens raised above the plaza's edge, looking north up High Street past the Sword Monument to
	-- the Ascension Gate, pulled back and up enough to read the whole north wall's height and both
	-- its corners in one shot, its crest silhouette against the sky above the rooftops -- the same
	-- kind of establishing frame the reference uses (bright afternoon light, wide enough field to
	-- show craft, colour and composition together, not a close detail crop). Checked clear of every
	-- tree canopy and the monument along the sightline. WorldDay's clock, so this round's
	-- before/after shots share one light.
	WorldWall = {
		clock = 15.3,
		stand = { at = Vector3.new(8, 13.6, 16), face = Vector3.new(-6, 13.6, -100) },
		camera = { at = Vector3.new(8, 24, 16), look = Vector3.new(-6, 42, -100) },
		fov = 66,
	},
	-- Briarwood at WorldDay's light, framed like Arcane Odyssey's Mount Othrys forest frame: a low
	-- lens in the wood beside the Old Road, south of Bramble Hollow, tilted up and looking north-west
	-- toward the afternoon sun, so trunks stand at every depth from the near verge to the deep wood
	-- and the mist behind, the oak and fir crowns close overhead with sky showing between them, and
	-- their shadows dapple the grass and leaf cover toward the lens. Like the reference, no one is
	-- in the frame: the player waits in the gate's safe zone, out of every stalker's aggro range.
	WorldForest = {
		clock = 15.3,
		stand = { at = Vector3.new(0, 5, 504), face = Vector3.new(0, 5, 560) },
		camera = { at = Vector3.new(10, 8, 690), look = Vector3.new(-15, 27, 621) },
		fov = 62,
		hideEnemies = true, -- the Old Road's thorn stalkers would stand in front of the lens
	},
}

local player = Players.LocalPlayer

local topbarHidden = false
local function hideHud()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	-- Roblox's own menu button pill (top left) stays on screen even with the topbar disabled, so
	-- world captures crop the top 64 px of the play viewport.
	if not topbarHidden then
		topbarHidden = pcall(function()
			StarterGui:SetCore("TopbarEnabled", false)
		end)
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		-- GetDescendants: a BillboardGui still draws inside a disabled ScreenGui (the quest guide
		-- marker lives in one), so the floating markers are switched off one by one.
		for _, gui in ipairs(playerGui:GetDescendants()) do
			if (gui:IsA("ScreenGui") or gui:IsA("BillboardGui")) and gui.Enabled then
				gui.Enabled = false
			end
		end
	end
	-- "Press E" interaction prompts are HUD too.
	ProximityPromptService.MaxPromptsVisible = 0
end

local function hold(view)
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if root then
		root.CFrame = CFrame.lookAt(view.stand.at, view.stand.face)
		root.AssemblyLinearVelocity = Vector3.zero
	end
	pcall(function()
		player:RequestStreamAroundAsync(view.camera.look)
	end)
	pcall(function()
		player:RequestStreamAroundAsync(view.camera.at)
	end)
	pcall(function()
		player:RequestStreamAroundAsync(view.stand.at)
	end)
	-- NPC nameplates ("Press E to talk") float in the world, not in PlayerGui; hide them locally,
	-- once a second, since NPCs can spawn after the view is placed.
	local lastSweep = -math.huge
	local function hideNameplates()
		if os.clock() - lastSweep < 1 then
			return
		end
		lastSweep = os.clock()
		for _, gui in ipairs(workspace:GetDescendants()) do
			if gui:IsA("BillboardGui") and gui.Enabled then
				gui.Enabled = false
			end
		end
		-- A world shot shows the place, not its mobs: enemies ("Enemy", CombatUtil.ENEMY_TAG) are
		-- hidden locally for views that ask, and only on this client.
		if view.hideEnemies then
			for _, enemy in ipairs(CollectionService:GetTagged("Enemy")) do
				for _, p in ipairs(enemy:GetDescendants()) do
					if p:IsA("BasePart") then
						p.LocalTransparencyModifier = 1
					elseif p:IsA("Decal") then
						p.Transparency = 1
					end
				end
			end
		end
	end
	-- Floating text spawned between sweeps (damage and gold numbers) is caught as it appears.
	workspace.DescendantAdded:Connect(function(gui)
		if gui:IsA("BillboardGui") then
			gui.Enabled = false
		end
	end)
	local cameraCFrame = CFrame.lookAt(view.camera.at, view.camera.look)
	-- Framing aid for choosing a view: set workspace attribute GuiShowcaseTour in edit mode to
	-- "x,y,z,lx,ly,lz;x,y,z,lx,ly,lz;..." (eye and look-at points) and the lens steps through the
	-- list, TOUR_STEP seconds per stop, after the view settles.
	local tour = {}
	local tourText = workspace:GetAttribute("GuiShowcaseTour")
	if typeof(tourText) == "string" then
		for stop in string.gmatch(tourText, "[^;]+") do
			local n = {}
			for v in string.gmatch(stop, "[^,]+") do
				table.insert(n, tonumber(v))
			end
			if #n == 6 then
				table.insert(tour, CFrame.lookAt(Vector3.new(n[1], n[2], n[3]), Vector3.new(n[4], n[5], n[6])))
			end
		end
	end
	local tourStart = os.clock() + STREAM_SETTLE
	local function tourCFrame(): CFrame?
		if #tour == 0 then
			return nil
		end
		local i = math.clamp(math.floor((os.clock() - tourStart) / TOUR_STEP) + 1, 1, #tour)
		return tour[i]
	end
	RunService:BindToRenderStep("WorldShowcase", Enum.RenderPriority.Camera.Value + 1, function()
		-- Only on drift: rewriting the clock every frame dirties the sun and the shadow map
		-- never settles, so the capture comes out with no cast shadows at all.
		if math.abs(Lighting.ClockTime - view.clock) > 0.01 then
			Lighting.ClockTime = view.clock
		end
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = view.fov
		camera.CFrame = tourCFrame() or cameraCFrame
		hideHud()
		hideNameplates()
	end)
	task.wait(STREAM_SETTLE)
	print("[WorldShowcase] view ready")
end

for name, view in pairs(VIEWS) do
	GuiShowcase.register(name, function()
		hold(view)
	end)
end
