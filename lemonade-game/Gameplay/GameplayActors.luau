-- ModuleScript | ServerScriptService.GameplayActors | Plain interaction characters, no scenery.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NpcOutfits = require(ReplicatedStorage:WaitForChild("NpcOutfits"))
local PrebuiltNpcRig = require(ReplicatedStorage:WaitForChild("PrebuiltNpcRig"))
local Actors = {}

local function nameplate(head: BasePart, title: string, subtitle: string?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(180, subtitle and 40 or 24)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	gui.MaxDistance = 70 -- [TUNING] Readable across the hub courtyard, hidden beyond it.
	gui.AlwaysOnTop = false
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 22)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(255, 232, 170)
	label.TextStrokeTransparency = 0.3
	label.Text = title
	label.Parent = gui
	if subtitle then
		local sub = label:Clone()
		sub.Position = UDim2.fromOffset(0, 20)
		sub.Size = UDim2.new(1, 0, 0, 16)
		sub.Font = Enum.Font.Gotham
		sub.TextSize = 14
		-- No outline: at this size a stroke fills the counters and the line reads as a smudge.
		sub.TextStrokeTransparency = 1
		sub.TextColor3 = Color3.fromRGB(215, 215, 225)
		sub.Text = subtitle
		sub.Parent = gui
	end
end

-- options.facing: CFrame whose rotation the character adopts (map markers supply one).
-- options.title / options.subtitle: nameplate text; title defaults to the model name.
-- options.outfit: an NpcOutfits name (QuestMaster, Blacksmith, Trainer, RebirthKeeper, ...).
function Actors.create(name: string, position: Vector3, color: Color3, options: {}?): Model
	options = options or {}
	local model = options.outfit and PrebuiltNpcRig.clone(options.outfit, name, position)
	if model then
		if options.facing then
			model:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)) * options.facing.Rotation)
		end
		nameplate(model:FindFirstChild("Head"), options.title or name, options.subtitle)
		-- Clients give prebuilt rigs a standing idle (ReplicatedStorage.NpcAnimator): tag and job.
		model:SetAttribute("NpcRole", options.outfit)
		CollectionService:AddTag(model, "ServiceNpc")
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- the whole rig streams in at once
		model.Parent = workspace
		return model
	end

	model = Instance.new("Model")
	model.Name = name
	local pieces = {
		{"HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0)},
		{"Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0)},
		{"Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0)},
		{"Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0)},
		{"Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0)},
		{"Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0)},
		{"Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0)},
	}
	for _, spec in ipairs(pieces) do
		local part = Instance.new("Part")
		part.Name, part.Size, part.Position = spec[1], spec[2], position + spec[3]
		part.Anchored, part.CanCollide = true, false
		part.Material, part.Color = Enum.Material.SmoothPlastic, color
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Parent = model
		if part.Name == "HumanoidRootPart" then
			part.Transparency = 1
			model.PrimaryPart = part
		elseif part.Name == "Head" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Head
			mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
			mesh.Parent = part
		end
	end
	if options.outfit then
		NpcOutfits.apply(model, options.outfit) -- distinct look per character (hat, apron, staff...)
	end
	if options.facing then
		model:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)) * options.facing.Rotation)
	end
	nameplate(model:FindFirstChild("Head"), options.title or name, options.subtitle)
	model.Parent = workspace
	return model
end
function Actors.prompt(model: Model, action: string, objectText: string?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = action, objectText or model.Name
	prompt.MaxActivationDistance = 12 -- [TUNING] Same interaction range as existing services.
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	return prompt
end

-- ==============================================================================
-- THE TOWN SPIN WHEEL (a prop, not a character; SpinSystem hangs its prompts and rules on it)
-- ==============================================================================
-- A landmark in the hub's own style (cream stone, lemon yellow, the token's teal): a round plinth,
-- two teal A-frame legs, a big upright wheel ringed with marquee bulbs, a red ticker at 12 o'clock
-- and an arched "SPIN WHEEL" sign crowned with a lemon, so it reads across the plaza. The prize
-- FACE is left blank on purpose: every client paints its own pool onto the Rotor (slices sized by
-- that player's real odds, ReplicatedStorage.SpinStation), since two players can stand at different depths.
-- Returns the model; its children SpinSystem and the client look up by name:
--   Rotor (Model, pivot = hub, turned only by clients), PromptPart, BoardAnchor, Bulbs (Folder),
--   Ticker (two wedges).
local WheelGeometry = require(ReplicatedStorage:WaitForChild("WheelGeometry"))

local CREAM = Color3.fromRGB(255, 248, 228)
local CREAM_DARK = Color3.fromRGB(226, 212, 182)
local LEMON = Color3.fromRGB(255, 214, 52)
local LEMON_DARK = Color3.fromRGB(236, 160, 24)
local TEAL = Color3.fromRGB(0, 176, 166)
local TEAL_DARK = Color3.fromRGB(0, 110, 108)
local TICKER_RED = Color3.fromRGB(240, 64, 74)
local INK = Color3.fromRGB(30, 33, 48)

function Actors.spinWheel(cframe: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "SpinWheel"
	local function part(name, shape, size, at, color, material, parent, collide)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape or Enum.PartType.Block
		p.Size = size
		p.CFrame = cframe * at
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = collide == true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = parent or model
		return p
	end
	local up = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis turned vertical
	local faceOn = CFrame.Angles(0, math.pi / 2, 0) -- a cylinder's axis turned along Z (facing out)
	local C, R = WheelGeometry.CENTER, WheelGeometry.RADIUS

	-- Plinth: two round steps, cream with a lemon top and a teal lip.
	part("Plinth", Enum.PartType.Cylinder, Vector3.new(0.9, 15, 15), CFrame.new(0, 0.45, 0) * up,
		CREAM_DARK, Enum.Material.SmoothPlastic, model, true)
	part("PlinthLip", Enum.PartType.Cylinder, Vector3.new(0.3, 13.4, 13.4), CFrame.new(0, 1.05, 0) * up, TEAL,
		nil, model, true)
	part("PlinthTop", Enum.PartType.Cylinder, Vector3.new(0.5, 12.4, 12.4), CFrame.new(0, 1.3, 0) * up, LEMON,
		nil, model, true)
	-- (No PrimaryPart: a primary part would make the model's pivot that part's own frame. The pivot
	-- is the station CFrame, also published as the StationCFrame attribute for clients.)

	-- Legs: an A-frame each side of the wheel, meeting at the axle behind the hub.
	local axle = CFrame.new(C.X, C.Y, 0.9)
	for _, side in ipairs({ -1, 1 }) do
		for _, zf in ipairs({ -1, 1 }) do
			local foot = Vector3.new(side * 4.6, 1.5, 0.9 + zf * 2.2)
			local top = Vector3.new(side * 1.2, C.Y, 0.9)
			local mid = (foot + top) / 2
			local len = (top - foot).Magnitude
			part("Leg", nil, Vector3.new(0.9, len, 0.9), CFrame.lookAt(mid, top) * CFrame.Angles(math.pi / 2, 0, 0),
				TEAL, nil, model, true)
		end
		part("Foot", Enum.PartType.Cylinder, Vector3.new(0.4, 2.4, 2.4),
			CFrame.new(side * 4.6, 1.7, 0.9) * up, TEAL_DARK, nil, model, true)
	end
	part("Axle", Enum.PartType.Cylinder, Vector3.new(3.4, 1.3, 1.3), axle, TEAL_DARK)
	part("AxleCap", Enum.PartType.Cylinder, Vector3.new(1.4, 1.6, 1.6), CFrame.new(C.X, C.Y, 1.2) * faceOn, TEAL)

	-- Backing disc (behind the painted face) and the rim: a ring of cream blocks with a lemon band,
	-- and a marquee bulb between each pair.
	part("Backing", Enum.PartType.Cylinder, Vector3.new(0.4, R * 2 + 0.2, R * 2 + 0.2),
		CFrame.new(C.X, C.Y, 0.05) * faceOn, CREAM)
	local bulbs = Instance.new("Folder")
	bulbs.Name = "Bulbs"
	bulbs.Parent = model
	local SEG = 28
	local rimR = R + 0.45
	for i = 0, SEG - 1 do
		local phi = (i + 0.5) / SEG * math.pi * 2
		local at = CFrame.new(C) * CFrame.Angles(0, 0, -phi) * CFrame.new(0, rimR, -0.1)
		local chord = 2 * rimR * math.sin(math.pi / SEG) + 0.12
		part("Rim", nil, Vector3.new(chord, 0.9, 1.1), at, i % 2 == 0 and CREAM or LEMON)
		local bulbPhi = i / SEG * math.pi * 2
		local bulb = part("Bulb", Enum.PartType.Ball, Vector3.one * 0.6,
			CFrame.new(C) * CFrame.Angles(0, 0, -bulbPhi) * CFrame.new(0, rimR, -0.72),
			Color3.fromRGB(255, 244, 196), Enum.Material.Neon, bulbs)
		bulb:SetAttribute("Index", i)
	end

	-- Rotor: the hub cap turns with the face (clients add the slices and turn the whole model).
	local rotor = Instance.new("Model")
	rotor.Name = "Rotor"
	rotor.Parent = model
	part("HubRing", Enum.PartType.Cylinder, Vector3.new(0.7, 2.9, 2.9), CFrame.new(C.X, C.Y, -0.6) * faceOn,
		CREAM, nil, rotor)
	local hub = part("Hub", Enum.PartType.Cylinder, Vector3.new(0.8, 2.3, 2.3), CFrame.new(C.X, C.Y, -0.72) * faceOn,
		LEMON, nil, rotor)
	for i = 0, 2 do -- lemon-slice spokes on the hub
		part("HubSpoke", nil, Vector3.new(0.14, 1.9, 0.1),
			CFrame.new(C.X, C.Y, -1.14) * CFrame.Angles(0, 0, i * math.pi / 3), CREAM, nil, rotor)
	end
	part("HubPip", Enum.PartType.Cylinder, Vector3.new(0.12, 0.55, 0.55), CFrame.new(C.X, C.Y, -1.18) * faceOn,
		CREAM, nil, rotor)
	rotor.WorldPivot = cframe * CFrame.new(C)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 232, 170)
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = hub

	-- The ticker: a big fixed pointer at 12 o'clock, pointing down into the face, on a lemon pin: an
	-- ink outline arrow with a red one on top, so it reads against any slice colour from the plaza.
	-- (Clients flick it as the pegs pass: ReplicatedStorage.SpinStation.)
	local tipY = C.Y + R - 1.7
	local topY = C.Y + R + 1.9
	local a = cframe * Vector3.new(-1.55, topY, -1.05)
	local b = cframe * Vector3.new(1.55, topY, -1.05)
	local c = cframe * Vector3.new(0, tipY, -1.05)
	for _, w in ipairs({ WheelGeometry.triangle(a, b, c, 0.4, { Color = INK, Name = "Ticker" }) }) do
		w.Parent = model
	end
	local ia = cframe * Vector3.new(-1.2, topY - 0.22, -1.3)
	local ib = cframe * Vector3.new(1.2, topY - 0.22, -1.3)
	local ic = cframe * Vector3.new(0, tipY + 0.5, -1.3)
	for _, w in ipairs({ WheelGeometry.triangle(ia, ib, ic, 0.2, { Color = TICKER_RED, Name = "Ticker" }) }) do
		w.Parent = model
	end
	part("TickerPin", Enum.PartType.Cylinder, Vector3.new(0.9, 1.1, 1.1), CFrame.new(0, topY - 0.55, -1.25) * faceOn,
		LEMON, nil, model)

	-- The sign: an arched board over the wheel, held by the legs' extension, with a lemon on top.
	local signY = C.Y + R + 2.9
	part("SignPost", nil, Vector3.new(0.6, signY - C.Y, 0.6), CFrame.new(-5.2, (signY + C.Y) / 2, 0.9), TEAL)
	part("SignPost", nil, Vector3.new(0.6, signY - C.Y, 0.6), CFrame.new(5.2, (signY + C.Y) / 2, 0.9), TEAL)
	part("SignBack", nil, Vector3.new(12.6, 3.3, 0.5), CFrame.new(0, signY, 0.4), INK)
	local board = part("SignBoard", nil, Vector3.new(12, 2.8, 0.5), CFrame.new(0, signY, 0.15), LEMON)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "SignText"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(1200, 280)
	surface.LightInfluence = 0
	surface.Parent = board
	local grad = Instance.new("Frame")
	grad.Size = UDim2.fromScale(1, 1)
	grad.BackgroundColor3 = Color3.new(1, 1, 1)
	grad.BorderSizePixel = 0
	grad.Parent = surface
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.fromRGB(255, 236, 110), LEMON_DARK)
	g.Parent = grad
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0.8, 0)
	label.Position = UDim2.fromScale(0, 0.08)
	label.Font = Enum.Font.FredokaOne
	label.Text = "SPIN WHEEL"
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = grad
	local st = Instance.new("UIStroke")
	st.Color = INK
	st.Thickness = 14
	st.Parent = label
	part("SignLemon", Enum.PartType.Ball, Vector3.new(2.6, 2.6, 2.6), CFrame.new(0, signY + 2.3, 0.3), LEMON)
	part("SignLemonTip", Enum.PartType.Ball, Vector3.new(0.8, 0.8, 0.8), CFrame.new(1.35, signY + 2.3, 0.3), LEMON_DARK)
	local leaf = part("SignLeaf", nil, Vector3.new(1.4, 0.2, 0.7), CFrame.new(-0.5, signY + 3.65, 0.3)
		* CFrame.Angles(0, 0, math.rad(22)), Color3.fromRGB(104, 200, 84))
	leaf.Shape = Enum.PartType.Block

	-- Invisible anchors: where the prompts live (at the plinth's front edge, at chest height) and
	-- where each client hangs its pool board (beside the wheel, on a customer's right as they face it;
	-- a board over the sign would sit above a walking player's view).
	local prompt = part("PromptPart", nil, Vector3.new(1, 1, 1), CFrame.new(2, 3.2, -5.4), CREAM)
	prompt.Transparency = 1
	prompt.CanQuery = false
	local anchor = part("BoardAnchor", nil, Vector3.new(1, 1, 1), CFrame.new(-18.8, C.Y + 0.4, -1), CREAM)
	anchor.Transparency = 1
	anchor.CanQuery = false

	model.WorldPivot = cframe
	model:SetAttribute("StationCFrame", cframe) -- clients turn the rotor about cframe * CENTER
	model:SetAttribute("SpinStation", true)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- every client can always paint it
	CollectionService:AddTag(model, "SpinStation")
	model.Parent = workspace
	return model
end

-- ==============================================================================
-- THE UPGRADE STALL (the gold shop beside the wheel; GameplayServices hangs its prompt and rules on it)
-- ==============================================================================
-- A market stall in the wheel's palette: a cream counter with a lemon top, four teal posts, a
-- teal-and-cream striped awning and a lemon "UPGRADES" sign board, so it reads as the wheel's
-- companion from across the lawn. `cframe` is the stall's floor centre, its -Z facing the customer.
-- Returns the model; children looked up by name: Counter (the prompt part).
function Actors.upgradeStall(cframe: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "UpgradeStall"
	local function part(name, size, at, color, collide)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cframe * at
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = collide == true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local counter = part("Counter", Vector3.new(9, 3.2, 2.4), CFrame.new(0, 1.6, -1.2), CREAM, true)
	part("CounterTop", Vector3.new(9.6, 0.4, 3), CFrame.new(0, 3.4, -1.2), LEMON)
	part("CounterStripe", Vector3.new(9.1, 0.5, 0.1), CFrame.new(0, 2.4, -2.45), TEAL)
	for _, x in ipairs({ -4.6, 4.6 }) do
		for _, z in ipairs({ -2.6, 2.4 }) do
			part("Post", Vector3.new(0.5, 8.6, 0.5), CFrame.new(x, 4.3, z), TEAL_DARK, true)
		end
	end
	-- Awning: seven stripes tipped down toward the customer.
	local tilt = CFrame.Angles(math.rad(-16), 0, 0)
	for i = 1, 7 do
		local x = -5.4 + (i - 0.5) * (10.8 / 7)
		part("Awning", Vector3.new(10.8 / 7, 0.35, 6.4), CFrame.new(x, 9, 0) * tilt,
			if i % 2 == 1 then TEAL else CREAM)
	end
	for i = 1, 7 do -- scalloped valance along the front edge
		local x = -5.4 + (i - 0.5) * (10.8 / 7)
		part("Valance", Vector3.new(10.8 / 7 - 0.1, 0.8, 0.2), CFrame.new(x, 7.75, -3.2),
			if i % 2 == 1 then TEAL else CREAM)
	end
	local board = part("Sign", Vector3.new(8, 2, 0.4), CFrame.new(0, 11.1, -2.2), LEMON)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "SignText"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(800, 200)
	surface.LightInfluence = 0
	surface.Parent = board
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = surface
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.fromRGB(255, 236, 110), LEMON_DARK)
	g.Parent = fill
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = "UPGRADES"
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = fill
	local ls = Instance.new("UIStroke")
	ls.Color = INK
	ls.Thickness = 8
	ls.Parent = label
	model.PrimaryPart = counter
	model.WorldPivot = cframe
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = workspace
	return model
end

-- ==============================================================================
-- STUDIO-ONLY MOTION SHOWCASES (see GuiShowcase.stage; inert outside Studio)
-- ==============================================================================
-- NPC motion captures share one stage: the real service NPC at its map marker, untouched (it is
-- never moved, re-anchored or re-prompted), with the player's character standing a few steps in
-- front of it and to its left, as a player browsing the stall would, and a fixed three-quarter
-- camera from the NPC's front right that frames it large, head to feet. Nothing is spawned and
-- nothing is granted: the stage only places the player's character and holds the camera.
local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))

-- The service NPC standing at map marker `markerName` (Merchant, QuestMaster, Vaultkeeper,
-- RebirthKeeper, SkillTrainer): the actor model nearest the marker, waited for up to 15 s.
local function findServiceNpc(markerName: string): Model?
	local map = workspace:FindFirstChild("LemonadeMap")
	local markers = map and map:FindFirstChild("Markers")
	local npcs = markers and markers:FindFirstChild("NPCs")
	local marker = npcs and npcs:FindFirstChild(markerName)
	if not (marker and marker:IsA("BasePart")) then
		return nil
	end
	local deadline = os.clock() + 15
	repeat
		local best, bestDistance = nil, 8
		for _, child in ipairs(workspace:GetChildren()) do
			if child:IsA("Model") and child.PrimaryPart and child:FindFirstChild("NameTag", true) then
				local offset = child.PrimaryPart.Position - marker.Position
				local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if distance < bestDistance then
					best, bestDistance = child, distance
				end
			end
		end
		if best then
			return best
		end
		task.wait(0.5)
	until os.clock() > deadline
	return nil
end

-- Puts the player in front of the NPC and locks the camera on it. Returns the NPC model and its
-- level post facing (a CFrame at its root; -Z is the way it faces, -X its left).
-- The camera stands on the player's side (the NPC's front left), so an NPC that turns to the
-- customer turns toward the lens. `playerOffset` (in that facing's space) overrides where the
-- player's character is stood.
function Actors.stageNpc(ctx, markerName: string, playerOffset: Vector3?): (Model?, CFrame?)
	local npc = findServiceNpc(markerName)
	if not npc then
		warn("[GameplayActors] showcase: no NPC at marker " .. markerName)
		return nil
	end
	local root = npc.PrimaryPart :: BasePart
	local facing = CFrame.lookAt(root.Position, root.Position + root.CFrame.LookVector * Vector3.new(1, 0, 1))
	-- The player: out in front of the stall and to the NPC's left, turned towards it, just beyond
	-- the prompt's reach so its "Browse" card does not sit over the NPC's chest in the shot.
	local playerAt = facing:PointToWorldSpace(playerOffset or Vector3.new(-5, 0, -11.8))
	ctx.place(CFrame.lookAt(playerAt, Vector3.new(root.Position.X, playerAt.Y, root.Position.Z)))
	-- The camera: front left of the NPC, about 35 degrees off its facing, raised a little above its
	-- head and looking down over the shop counter (its top is about level with the Merchant's
	-- belt, 2.4-4.8 studs in front of him), so the head, arms, hands and chest all read, framed large.
	local focus = root.Position + Vector3.new(0, 0.7, 0)
	local distance = 5.8
	local eye = focus + facing:VectorToWorldSpace(Vector3.new(-math.sin(math.rad(35)) * distance, 1.8,
		-math.cos(math.rad(35)) * distance))
	ctx.camera(CFrame.lookAt(eye, focus))
	print(string.format("[GameplayActors] showcase NPC %s root %s camera %s", npc.Name,
		tostring(root.Position), tostring(eye)))
	return npc, facing
end

-- NPC idle: the Merchant stands at its post with the player nearby, filmed as it idles in play.
-- "ShowcaseHold" keeps HubAmbience from walking him to the anvil mid-take; "NpcIdleCue" (a server
-- time) asks NpcAnimator to land one job gesture and one glance just after the clapperboard,
-- exactly as they play when their own timers fire in normal play.
GuiShowcase.stage("NpcIdle", function(ctx)
	local npc = Actors.stageNpc(ctx, "Merchant")
	if not npc then
		return
	end
	npc:SetAttribute("ShowcaseHold", true)
	local settle = 2 -- character and camera settle
	npc:SetAttribute("NpcIdleCue", workspace:GetServerTimeNow() + settle + 0.25 + 0.15)
	task.wait(settle)
	ctx.clapper() -- 0.25 s flash, then 0.5 s
	task.wait(20)
	npc:SetAttribute("NpcIdleCue", nil)
	npc:SetAttribute("ShowcaseHold", nil)
end)

-- NPC reacts to you: the player starts off to the Merchant's left, outside the range he notices
-- players from (NpcAnimator's NOTICE_RANGE, 14 studs; ~25.6 here), and walks up (Humanoid:MoveTo,
-- at real walk speed) to stand at his front left, just outside the prompt's reach so the prompt
-- card stays off the shot. The walk starts just before the clapperboard flashes, so he notices the
-- player ~0.2-0.4 s after the flash, just into the strip. "NpcReactFresh" makes it a first meeting: a greeting from
-- before the take (the player spawning near him) does not hold this one back on its cooldown. The camera is the shared NPC camera (front left), so as he turns
-- to the player he turns toward the lens; the player's path runs behind the camera and never
-- crosses the shot. After a hold the player walks back out so he eases back to his post. Nothing
-- is spawned, cued or granted.
GuiShowcase.stage("NpcReact", function(ctx)
	local npc, facing = Actors.stageNpc(ctx, "Merchant", Vector3.new(-24, 0, -9))
	if not (npc and facing) then
		return
	end
	npc:SetAttribute("ShowcaseHold", true)
	npc:SetAttribute("NpcReactFresh", true)
	task.wait(3) -- character and camera settle; the NPC sees nobody near
	ctx.walkTo(facing:PointToWorldSpace(Vector3.new(-8.5, 0, -9))) -- ~12.4 studs from him
	task.wait(0.25)
	ctx.clapper() -- 0.25 s flash, then 0.5 s
	task.wait(12)
	ctx.walkTo(facing:PointToWorldSpace(Vector3.new(-24, 0, -9)))
	task.wait(5)
	npc:SetAttribute("NpcReactFresh", nil)
	npc:SetAttribute("ShowcaseHold", nil)
end)

return Actors
