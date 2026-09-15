-- ModuleScript | ReplicatedStorage.NpcOutfits | Distinct looks for the block-rig NPCs.
-- apply(model, outfitName) recolours the rig and welds accessory parts (hats, aprons, beards,
-- tools) onto it. Accessories are unanchored and welded, so they follow when a script moves the
-- anchored body parts (HubAmbience walks the trainer and villagers by setting CFrames).
-- Works for GameplayActors rigs (server) and the client-built villagers alike.
local NpcOutfits = {}

local SKIN = Color3.fromRGB(226, 190, 150)
local SKIN_TAN = Color3.fromRGB(198, 156, 116)
local LEATHER = Color3.fromRGB(110, 72, 42)
local DARK_WOOD = Color3.fromRGB(72, 48, 32)
local IRON = Color3.fromRGB(92, 94, 100)
local GOLD = Color3.fromRGB(204, 168, 72)
local CREAM = Color3.fromRGB(236, 224, 196)

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function deg(x, y, z) return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z)) end
local FLAT = deg(0, 0, 90) -- cylinder axis turned vertical (a disc / drum)

-- Accessory: { part = body part name, name, size = Vector3, offset = CFrame (in the body part's
-- space; -Z is the front), color, material?, shape?, transparency?, light? = {range, brightness} }
local OUTFITS = {
	QuestMaster = {
		colors = { Torso = rgb(150, 110, 60), ["Left Arm"] = rgb(150, 110, 60), ["Right Arm"] = rgb(150, 110, 60),
			["Left Leg"] = rgb(70, 55, 45), ["Right Leg"] = rgb(70, 55, 45) },
		accessories = {
			{ part = "Head", name = "HatBrim", size = Vector3.new(0.15, 2.7, 2.7), offset = CFrame.new(0, 0.62, 0) * FLAT,
				color = DARK_WOOD, material = "Fabric", shape = "Cylinder" },
			{ part = "Head", name = "HatCrown", size = Vector3.new(0.9, 1.3, 1.3), offset = CFrame.new(0, 1.1, 0) * FLAT,
				color = DARK_WOOD, material = "Fabric", shape = "Cylinder" },
			{ part = "Head", name = "HatBand", size = Vector3.new(0.2, 1.4, 1.4), offset = CFrame.new(0, 0.85, 0) * FLAT,
				color = GOLD, material = "Fabric", shape = "Cylinder" },
			{ part = "Head", name = "Beard", size = Vector3.new(0.9, 0.7, 0.45), offset = CFrame.new(0, -0.55, -0.42),
				color = rgb(190, 180, 170), material = "Fabric" },
			{ part = "Torso", name = "Sash", size = Vector3.new(0.55, 2.4, 1.08), offset = CFrame.new(0, 0, 0) * deg(0, 0, 32),
				color = rgb(70, 120, 80), material = "Fabric" },
			{ part = "Torso", name = "Satchel", size = Vector3.new(1.0, 1.0, 0.5), offset = CFrame.new(1.1, -0.75, 0.45),
				color = LEATHER, material = "Fabric" },
			{ part = "Right Arm", name = "Scroll", size = Vector3.new(0.35, 1.3, 0.35), offset = CFrame.new(0, -1.05, -0.35) * deg(90, 0, 0),
				color = CREAM, material = "SmoothPlastic", shape = "Cylinder" },
		},
	},
	Blacksmith = {
		colors = { Torso = rgb(60, 55, 55), ["Left Arm"] = SKIN_TAN, ["Right Arm"] = SKIN_TAN,
			["Left Leg"] = rgb(55, 50, 50), ["Right Leg"] = rgb(55, 50, 50) },
		accessories = {
			{ part = "Torso", name = "Apron", size = Vector3.new(1.9, 2.3, 0.22), offset = CFrame.new(0, -0.3, -0.58),
				color = LEATHER, material = "Fabric" },
			{ part = "Torso", name = "ApronStrap", size = Vector3.new(0.35, 1.2, 1.08), offset = CFrame.new(0, 0.5, 0) * deg(0, 0, 40),
				color = LEATHER, material = "Fabric" },
			{ part = "Torso", name = "Belt", size = Vector3.new(2.15, 0.35, 1.12), offset = CFrame.new(0, -0.85, 0),
				color = DARK_WOOD, material = "Fabric" },
			{ part = "Head", name = "Bandana", size = Vector3.new(0.35, 1.36, 1.36), offset = CFrame.new(0, 0.42, 0) * FLAT,
				color = rgb(170, 50, 45), material = "Fabric", shape = "Cylinder" },
			{ part = "Head", name = "Beard", size = Vector3.new(1.05, 0.9, 0.6), offset = CFrame.new(0, -0.6, -0.4),
				color = rgb(70, 45, 30), material = "Fabric" },
			{ part = "Left Arm", name = "Glove", size = Vector3.new(1.08, 0.75, 1.08), offset = CFrame.new(0, -0.7, 0),
				color = rgb(50, 40, 35), material = "Fabric" },
			{ part = "Right Arm", name = "Glove", size = Vector3.new(1.08, 0.75, 1.08), offset = CFrame.new(0, -0.7, 0),
				color = rgb(50, 40, 35), material = "Fabric" },
			{ part = "Right Arm", name = "HammerHandle", size = Vector3.new(0.3, 1.7, 0.3), offset = CFrame.new(0, -1.1, -0.45) * deg(90, 0, 0),
				color = rgb(120, 84, 50), material = "Wood" },
			{ part = "Right Arm", name = "HammerHead", size = Vector3.new(0.9, 0.5, 0.5), offset = CFrame.new(0, -1.1, -1.35),
				color = IRON, material = "Metal" },
		},
	},
	Trainer = {
		colors = { Torso = SKIN_TAN, ["Left Arm"] = SKIN_TAN, ["Right Arm"] = SKIN_TAN,
			["Left Leg"] = rgb(70, 60, 60), ["Right Leg"] = rgb(70, 60, 60) },
		accessories = {
			{ part = "Torso", name = "ChestWrap", size = Vector3.new(2.1, 1.1, 1.1), offset = CFrame.new(0, 0.25, 0),
				color = rgb(120, 80, 150), material = "Fabric" },
			{ part = "Torso", name = "Sash", size = Vector3.new(2.15, 0.4, 1.12), offset = CFrame.new(0, -0.85, 0),
				color = rgb(190, 60, 50), material = "Fabric" },
			{ part = "Torso", name = "BackSword", size = Vector3.new(0.35, 3.8, 0.6), offset = CFrame.new(0.2, 0.3, 0.68) * deg(0, 0, 25),
				color = rgb(150, 110, 70), material = "Wood" },
			{ part = "Torso", name = "BackSwordGuard", size = Vector3.new(1.3, 0.25, 0.5), offset = CFrame.new(-0.45, 1.65, 0.68) * deg(0, 0, 25),
				color = DARK_WOOD, material = "Wood" },
			{ part = "Head", name = "Headband", size = Vector3.new(0.25, 1.36, 1.36), offset = CFrame.new(0, 0.32, 0) * FLAT,
				color = rgb(240, 236, 226), material = "Fabric", shape = "Cylinder" },
			{ part = "Head", name = "HeadbandTail", size = Vector3.new(0.25, 1.4, 0.12), offset = CFrame.new(0.3, -0.3, 0.7) * deg(0, 0, 15),
				color = rgb(240, 236, 226), material = "Fabric" },
			{ part = "Left Arm", name = "Bracer", size = Vector3.new(1.12, 0.7, 1.12), offset = CFrame.new(0, -0.5, 0),
				color = IRON, material = "Metal" },
			{ part = "Right Arm", name = "Bracer", size = Vector3.new(1.12, 0.7, 1.12), offset = CFrame.new(0, -0.5, 0),
				color = IRON, material = "Metal" },
		},
	},
	RebirthKeeper = {
		colors = { Torso = rgb(50, 70, 120), ["Left Arm"] = rgb(50, 70, 120), ["Right Arm"] = rgb(50, 70, 120),
			["Left Leg"] = rgb(40, 56, 100), ["Right Leg"] = rgb(40, 56, 100) },
		accessories = {
			{ part = "Torso", name = "Robe", size = Vector3.new(2.4, 2.3, 1.35), offset = CFrame.new(0, -2.05, 0),
				color = rgb(50, 70, 120), material = "Fabric" },
			{ part = "Torso", name = "RobeTrim", size = Vector3.new(2.45, 0.3, 1.4), offset = CFrame.new(0, -3.05, 0),
				color = GOLD, material = "Fabric" },
			{ part = "Torso", name = "Cord", size = Vector3.new(2.15, 0.28, 1.12), offset = CFrame.new(0, -0.8, 0),
				color = GOLD, material = "Fabric" },
			{ part = "Head", name = "HoodTop", size = Vector3.new(1.6, 0.55, 1.6), offset = CFrame.new(0, 0.72, 0.05),
				color = rgb(35, 50, 90), material = "Fabric" },
			{ part = "Head", name = "HoodBack", size = Vector3.new(1.6, 1.5, 0.45), offset = CFrame.new(0, 0.05, 0.72),
				color = rgb(35, 50, 90), material = "Fabric" },
			{ part = "Head", name = "HoodL", size = Vector3.new(0.35, 1.5, 1.4), offset = CFrame.new(-0.7, 0.05, 0.15),
				color = rgb(35, 50, 90), material = "Fabric" },
			{ part = "Head", name = "HoodR", size = Vector3.new(0.35, 1.5, 1.4), offset = CFrame.new(0.7, 0.05, 0.15),
				color = rgb(35, 50, 90), material = "Fabric" },
			{ part = "Left Arm", name = "Staff", size = Vector3.new(0.32, 6.2, 0.32), offset = CFrame.new(-0.55, 0.5, -0.35),
				color = DARK_WOOD, material = "Wood" },
			{ part = "Left Arm", name = "StaffCrystal", size = Vector3.new(0.95, 0.95, 0.95), offset = CFrame.new(-0.55, 3.9, -0.35),
				color = rgb(150, 220, 255), material = "Neon", shape = "Ball", transparency = 0.15, light = { 12, 1.0 } },
		},
	},
	-- Villagers
	Farmer = {
		colors = { Torso = rgb(90, 130, 80), ["Left Arm"] = SKIN, ["Right Arm"] = SKIN,
			["Left Leg"] = rgb(80, 70, 60), ["Right Leg"] = rgb(80, 70, 60) },
		accessories = {
			{ part = "Head", name = "StrawBrim", size = Vector3.new(0.14, 2.9, 2.9), offset = CFrame.new(0, 0.6, 0) * FLAT * deg(0, 0, 4),
				color = rgb(214, 186, 96), material = "Grass", shape = "Cylinder" },
			{ part = "Head", name = "StrawCrown", size = Vector3.new(0.8, 1.4, 1.4), offset = CFrame.new(0, 1.05, 0) * FLAT,
				color = rgb(214, 186, 96), material = "Grass", shape = "Cylinder" },
			{ part = "Torso", name = "Overalls", size = Vector3.new(1.6, 1.3, 0.2), offset = CFrame.new(0, -0.35, -0.58),
				color = rgb(60, 80, 130), material = "Fabric" },
		},
	},
	Baker = {
		colors = { Torso = rgb(200, 170, 110), ["Left Arm"] = SKIN, ["Right Arm"] = SKIN,
			["Left Leg"] = rgb(60, 60, 70), ["Right Leg"] = rgb(60, 60, 70) },
		accessories = {
			{ part = "Torso", name = "Apron", size = Vector3.new(1.9, 2.3, 0.2), offset = CFrame.new(0, -0.3, -0.58),
				color = rgb(240, 236, 226), material = "Fabric" },
			{ part = "Head", name = "Cap", size = Vector3.new(0.7, 1.5, 1.5), offset = CFrame.new(0, 0.85, 0) * FLAT,
				color = rgb(240, 236, 226), material = "Fabric", shape = "Cylinder" },
			{ part = "Left Arm", name = "Loaf", size = Vector3.new(0.6, 0.5, 1.2), offset = CFrame.new(0, -1.15, -0.4),
				color = rgb(190, 140, 80), material = "SmoothPlastic" },
		},
	},
	Gatherer = {
		colors = { Torso = rgb(150, 60, 60), ["Left Arm"] = SKIN, ["Right Arm"] = SKIN,
			["Left Leg"] = rgb(70, 60, 50), ["Right Leg"] = rgb(70, 60, 50) },
		accessories = {
			{ part = "Head", name = "Hair", size = Vector3.new(1.34, 0.6, 1.34), offset = CFrame.new(0, 0.42, 0.05),
				color = rgb(96, 60, 36), material = "Fabric" },
			{ part = "Head", name = "HairBack", size = Vector3.new(1.3, 1.4, 0.45), offset = CFrame.new(0, -0.2, 0.62),
				color = rgb(96, 60, 36), material = "Fabric" },
			{ part = "Torso", name = "Skirt", size = Vector3.new(2.3, 1.6, 1.3), offset = CFrame.new(0, -1.7, 0),
				color = rgb(130, 50, 50), material = "Fabric" },
			{ part = "Left Arm", name = "Basket", size = Vector3.new(1.0, 1.0, 1.0), offset = CFrame.new(0, -1.3, 0) * FLAT,
				color = rgb(150, 110, 60), material = "Wood", shape = "Cylinder" },
		},
	},
	Elder = {
		colors = { Torso = rgb(130, 80, 150), ["Left Arm"] = rgb(130, 80, 150), ["Right Arm"] = rgb(130, 80, 150),
			["Left Leg"] = rgb(50, 45, 40), ["Right Leg"] = rgb(50, 45, 40) },
		accessories = {
			{ part = "Head", name = "Beard", size = Vector3.new(1.0, 1.1, 0.5), offset = CFrame.new(0, -0.75, -0.4),
				color = rgb(215, 210, 200), material = "Fabric" },
			{ part = "Head", name = "FlatCap", size = Vector3.new(1.5, 0.3, 1.5), offset = CFrame.new(0, 0.7, 0.1),
				color = rgb(80, 70, 60), material = "Fabric" },
			{ part = "Right Arm", name = "Cane", size = Vector3.new(0.25, 3.2, 0.25), offset = CFrame.new(0.1, -1.7, -0.35),
				color = DARK_WOOD, material = "Wood" },
			{ part = "Right Arm", name = "CaneHandle", size = Vector3.new(0.6, 0.25, 0.25), offset = CFrame.new(0.25, -0.1, -0.35),
				color = DARK_WOOD, material = "Wood" },
		},
	},
}

function NpcOutfits.list()
	local names = {}
	for name in pairs(OUTFITS) do table.insert(names, name) end
	table.sort(names)
	return names
end

function NpcOutfits.apply(model: Model, outfitName: string)
	local outfit = OUTFITS[outfitName]
	if not outfit then
		warn("[NpcOutfits] Unknown outfit " .. tostring(outfitName))
		return
	end
	for partName, color in pairs(outfit.colors) do
		local body = model:FindFirstChild(partName)
		if body and body:IsA("BasePart") then body.Color = color end
	end
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		head.Color = SKIN
		if not head:FindFirstChildOfClass("Decal") then
			local face = Instance.new("Decal")
			face.Name = "face"
			face.Texture = "rbxasset://textures/face.png" -- the built-in classic smile, no upload needed
			face.Face = Enum.NormalId.Front
			face.Parent = head
		end
	end
	for _, spec in ipairs(outfit.accessories) do
		local body = model:FindFirstChild(spec.part)
		if not (body and body:IsA("BasePart")) then continue end
		local acc = Instance.new("Part")
		acc.Name = spec.name
		acc.Size = spec.size
		acc.Color = spec.color
		acc.Material = Enum.Material[spec.material or "SmoothPlastic"]
		if spec.shape then acc.Shape = Enum.PartType[spec.shape] end
		acc.Transparency = spec.transparency or 0
		acc.CanCollide, acc.CanQuery, acc.CanTouch, acc.CastShadow = false, false, false, false
		acc.Massless = true
		acc.Anchored = false
		acc.TopSurface, acc.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		acc.CFrame = body.CFrame * spec.offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = body, acc
		weld.Parent = acc
		if spec.light then
			local light = Instance.new("PointLight")
			light.Range, light.Brightness, light.Color = spec.light[1], spec.light[2], spec.color
			light.Parent = acc
		end
		acc.Parent = model
	end
end

return NpcOutfits
