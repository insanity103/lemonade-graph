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
		sub.TextSize = 12
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
