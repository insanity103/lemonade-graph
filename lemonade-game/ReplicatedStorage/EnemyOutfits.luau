-- ModuleScript | ReplicatedStorage.EnemyOutfits | Looks for the enemy rigs built by EnemyCombat.
-- apply(model, archetypeKey, scale, role) recolours body parts and welds accessory parts onto
-- them. Enemy rigs are unanchored humanoids that walk, so unlike NpcOutfits (anchored hub NPCs)
-- every accessory is a WeldConstraint child of its body part: Massless, no collision, no query,
-- so it never bumps the rig or catches raycasts. Sizes and offsets are in unit-rig studs (R6:
-- torso 2×2×1, head 1.2³, limbs 1×2×1) and are multiplied by the archetype scale.
-- The quarry bandits (IronSquire / IronBerserker / Boss_Gorgon) share rust, leather and rag so
-- they read as one gang; role "elite" picks the "<archetype>_elite" variant when one exists.
local EnemyOutfits = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function deg(x, y, z) return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z)) end
local FLAT = deg(0, 0, 90) -- cylinder axis vertical

local RUST = rgb(150, 82, 44)
local IRON_DARK = rgb(58, 56, 54)
local LEATHER = rgb(96, 64, 40)
local RAG = rgb(110, 96, 80)
local DARK_CLOTH = rgb(56, 48, 44)
local SASH_RED = rgb(150, 40, 40)
local BANNER_RED = rgb(110, 36, 40)
local BONE = rgb(226, 214, 190)
local SKIN_TAN = rgb(198, 156, 116)
local SCAR = rgb(120, 70, 60)
local LANTERN = rgb(255, 196, 120)

-- Accessory: { part, name, size = Vector3, offset = CFrame in the body part's space (-Z front),
-- color, material?, shape?, transparency?, light? = {range, brightness} }
local OUTFITS = {
	-- Lean, fast, hooded: cloth mask, leather vest, wrapped forearms, a rusty pick.
	IronSquire = {
		colors = { ["Left Arm"] = SKIN_TAN, ["Right Arm"] = SKIN_TAN },
		accessories = {
			{ part = "Head", name = "Hood", size = Vector3.new(1.4, 1.05, 1.35), offset = CFrame.new(0, 0.25, 0.12), color = DARK_CLOTH, material = "Fabric" },
			{ part = "Head", name = "HoodPeak", size = Vector3.new(1.0, 0.5, 0.8), offset = CFrame.new(0, 0.6, -0.35) * deg(-25, 0, 0), color = DARK_CLOTH, material = "Fabric" },
			{ part = "Head", name = "Mask", size = Vector3.new(1.05, 0.5, 0.22), offset = CFrame.new(0, -0.28, -0.6), color = RAG, material = "Fabric" },
			{ part = "Torso", name = "VestFront", size = Vector3.new(2.06, 1.5, 0.26), offset = CFrame.new(0, 0.15, -0.5), color = LEATHER, material = "Fabric" },
			{ part = "Torso", name = "VestBack", size = Vector3.new(2.06, 1.5, 0.26), offset = CFrame.new(0, 0.15, 0.5), color = LEATHER, material = "Fabric" },
			{ part = "Torso", name = "Belt", size = Vector3.new(2.12, 0.3, 1.12), offset = CFrame.new(0, -0.85, 0), color = DARK_CLOTH, material = "Fabric" },
			{ part = "Torso", name = "Pouch", size = Vector3.new(0.55, 0.5, 0.3), offset = CFrame.new(0.7, -0.95, -0.6), color = LEATHER, material = "Fabric" },
			{ part = "Left Arm", name = "WrapL", size = Vector3.new(1.08, 0.85, 1.08), offset = CFrame.new(0, -0.5, 0), color = RAG, material = "Fabric" },
			{ part = "Right Arm", name = "WrapR", size = Vector3.new(1.08, 0.85, 1.08), offset = CFrame.new(0, -0.5, 0), color = RAG, material = "Fabric" },
			-- Pick in the right hand: handle forward from the fist, head across the tip.
			{ part = "Right Arm", name = "PickHandle", size = Vector3.new(0.25, 0.25, 2.4), offset = CFrame.new(0, -0.95, -0.9), color = LEATHER, material = "Wood" },
			{ part = "Right Arm", name = "PickHead", size = Vector3.new(1.6, 0.3, 0.3), offset = CFrame.new(0, -0.95, -2.0), color = RUST, material = "CorrodedMetal" },
		},
	},
	-- Broad, slow: cart-plate pauldron, chain belt, chest plate, scars, a heavy sledge.
	IronBerserker = {
		colors = { ["Left Arm"] = SKIN_TAN, ["Right Arm"] = SKIN_TAN },
		accessories = {
			{ part = "Left Arm", name = "Pauldron", size = Vector3.new(1.4, 0.55, 1.4), offset = CFrame.new(0, 0.95, 0), color = RUST, material = "CorrodedMetal" },
			{ part = "Left Arm", name = "PauldronRim", size = Vector3.new(1.5, 0.2, 1.5), offset = CFrame.new(0, 0.72, 0), color = IRON_DARK, material = "CorrodedMetal" },
			{ part = "Torso", name = "ChestPlate", size = Vector3.new(2.1, 1.2, 0.3), offset = CFrame.new(0, 0.3, -0.58), color = RUST, material = "CorrodedMetal" },
			{ part = "Torso", name = "ChainBelt", size = Vector3.new(2.16, 0.36, 1.16), offset = CFrame.new(0, -0.8, 0), color = IRON_DARK, material = "CorrodedMetal" },
			{ part = "Torso", name = "ChainTail", size = Vector3.new(0.18, 1.1, 0.18), offset = CFrame.new(0.9, -1.4, -0.4) * deg(0, 0, -12), color = IRON_DARK, material = "CorrodedMetal" },
			{ part = "Left Arm", name = "ScarL", size = Vector3.new(0.12, 0.7, 0.14), offset = CFrame.new(0.2, 0.1, -0.52) * deg(0, 0, 22), color = SCAR },
			{ part = "Right Arm", name = "ScarR", size = Vector3.new(0.12, 0.55, 0.14), offset = CFrame.new(-0.15, 0.25, -0.52) * deg(0, 0, -18), color = SCAR },
			{ part = "Head", name = "Brow", size = Vector3.new(1.25, 0.28, 0.3), offset = CFrame.new(0, 0.3, -0.5), color = LEATHER, material = "Fabric" },
			-- Sledge in the right hand (two-handed weight, one weld): long handle, block head.
			{ part = "Right Arm", name = "SledgeHandle", size = Vector3.new(0.3, 0.3, 3.0), offset = CFrame.new(0, -0.95, -1.1), color = LEATHER, material = "Wood" },
			{ part = "Right Arm", name = "SledgeHead", size = Vector3.new(1.5, 0.8, 0.8), offset = CFrame.new(0, -0.95, -2.5), color = IRON_DARK, material = "CorrodedMetal" },
		},
	},
	-- Elite brute: same kit plus a red sash and a bone mask.
	IronBerserker_elite = {
		colors = { ["Left Arm"] = SKIN_TAN, ["Right Arm"] = SKIN_TAN },
		inherit = "IronBerserker",
		accessories = {
			{ part = "Torso", name = "Sash", size = Vector3.new(0.55, 2.4, 1.1), offset = CFrame.new(0, 0, 0) * deg(0, 0, 32), color = SASH_RED, material = "Fabric" },
			{ part = "Head", name = "SkullMask", size = Vector3.new(1.05, 0.95, 0.25), offset = CFrame.new(0, 0, -0.62), color = BONE },
			{ part = "Head", name = "EyeL", size = Vector3.new(0.22, 0.18, 0.1), offset = CFrame.new(-0.25, 0.12, -0.78), color = IRON_DARK },
			{ part = "Head", name = "EyeR", size = Vector3.new(0.22, 0.18, 0.1), offset = CFrame.new(0.25, 0.12, -0.78), color = IRON_DARK },
		},
	},
	-- The Warden: scavenged plate, crested helmet, cape of stitched banners, a lantern on the hip.
	-- The sword comes from the boss weapon weld in EnemyCombat (unchanged).
	Boss_Gorgon = {
		colors = {},
		accessories = {
			{ part = "Head", name = "Helm", size = Vector3.new(1.35, 0.95, 1.35), offset = CFrame.new(0, 0.32, 0), color = IRON_DARK, material = "CorrodedMetal" },
			{ part = "Head", name = "HelmNose", size = Vector3.new(0.22, 0.7, 0.16), offset = CFrame.new(0, -0.1, -0.68), color = IRON_DARK, material = "CorrodedMetal" },
			{ part = "Head", name = "Crest", size = Vector3.new(0.25, 0.6, 1.4), offset = CFrame.new(0, 1.05, 0.1), color = SASH_RED, material = "Fabric" },
			{ part = "Torso", name = "BreastPlate", size = Vector3.new(2.16, 1.7, 0.36), offset = CFrame.new(0, 0.15, -0.6), color = IRON_DARK, material = "CorrodedMetal" },
			{ part = "Torso", name = "PlateRivets", size = Vector3.new(1.6, 0.2, 0.1), offset = CFrame.new(0, 0.75, -0.8), color = RUST, material = "CorrodedMetal" },
			{ part = "Torso", name = "BackPlate", size = Vector3.new(2.16, 1.7, 0.3), offset = CFrame.new(0, 0.15, 0.58), color = IRON_DARK, material = "CorrodedMetal" },
			{ part = "Torso", name = "WarBelt", size = Vector3.new(2.2, 0.4, 1.2), offset = CFrame.new(0, -0.85, 0), color = LEATHER, material = "Fabric" },
			{ part = "Torso", name = "CapeA", size = Vector3.new(0.9, 3.2, 0.14), offset = CFrame.new(-0.6, -0.9, 0.8) * deg(6, 0, 0), color = BANNER_RED, material = "Fabric" },
			{ part = "Torso", name = "CapeB", size = Vector3.new(0.9, 3.0, 0.14), offset = CFrame.new(0.35, -0.8, 0.82) * deg(6, 0, 0), color = RAG, material = "Fabric" },
			{ part = "Torso", name = "CapeC", size = Vector3.new(0.6, 2.7, 0.14), offset = CFrame.new(1.0, -0.65, 0.84) * deg(6, 0, 0), color = DARK_CLOTH, material = "Fabric" },
			{ part = "Left Arm", name = "PauldronL", size = Vector3.new(1.45, 0.5, 1.45), offset = CFrame.new(0, 0.95, 0), color = RUST, material = "CorrodedMetal" },
			{ part = "Right Arm", name = "PauldronR", size = Vector3.new(1.45, 0.5, 1.45), offset = CFrame.new(0, 0.95, 0), color = RUST, material = "CorrodedMetal" },
			{ part = "Left Arm", name = "GauntletL", size = Vector3.new(1.1, 0.7, 1.1), offset = CFrame.new(0, -0.6, 0), color = IRON_DARK, material = "CorrodedMetal" },
			{ part = "Torso", name = "HipLantern", size = Vector3.new(0.5, 0.7, 0.5), offset = CFrame.new(-1.25, -0.75, 0.1), color = LANTERN, material = "Neon", transparency = 0.15, light = { 9, 0.8 } },
			{ part = "Torso", name = "LanternHook", size = Vector3.new(0.14, 0.5, 0.14), offset = CFrame.new(-1.15, -0.25, 0.1), color = IRON_DARK, material = "CorrodedMetal" },
		},
	},
}

EnemyOutfits.OUTFITS = OUTFITS

local function scaledOffset(offset: CFrame, scale: number): CFrame
	return CFrame.new(offset.Position * scale) * (offset - offset.Position)
end

local function specsFor(key: string): { any }
	local outfit = OUTFITS[key]
	if not outfit then return {} end
	local list = {}
	if outfit.inherit then
		for _, spec in ipairs(specsFor(outfit.inherit)) do table.insert(list, spec) end
	end
	for _, spec in ipairs(outfit.accessories) do table.insert(list, spec) end
	return list
end

function EnemyOutfits.has(archetypeKey: string): boolean
	return OUTFITS[archetypeKey] ~= nil
end

-- Call after the rig's body parts and Motor6Ds exist. Idempotent per rig (tagged Outfit attribute).
function EnemyOutfits.apply(model: Model, archetypeKey: string, scale: number, role: string?)
	local key = archetypeKey
	if role and OUTFITS[archetypeKey .. "_" .. role] then key = archetypeKey .. "_" .. role end
	local outfit = OUTFITS[key]
	if not outfit or model:GetAttribute("Outfit") then return end
	scale = scale or 1
	for partName, color in pairs(outfit.colors) do
		local body = model:FindFirstChild(partName)
		if body and body:IsA("BasePart") then body.Color = color end
	end
	for _, spec in ipairs(specsFor(key)) do
		local body = model:FindFirstChild(spec.part)
		if not (body and body:IsA("BasePart")) then continue end
		local acc = Instance.new("Part")
		acc.Name = spec.name
		acc.Size = spec.size * scale
		acc.Color = spec.color
		acc.Material = Enum.Material[spec.material or "SmoothPlastic"]
		if spec.shape then acc.Shape = Enum.PartType[spec.shape] end
		acc.Transparency = spec.transparency or 0
		acc.CanCollide, acc.CanQuery, acc.CanTouch, acc.CastShadow = false, false, false, false
		acc.Massless = true
		acc.Anchored = false
		acc.TopSurface, acc.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		acc.CFrame = body.CFrame * scaledOffset(spec.offset, scale)
		if spec.light then
			local light = Instance.new("PointLight")
			light.Range, light.Brightness, light.Color, light.Shadows = spec.light[1], spec.light[2], spec.color, false
			light.Parent = acc
		end
		acc.Parent = body
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = acc
		weld.Parent = acc
	end
	model:SetAttribute("Outfit", key)
end

return EnemyOutfits
