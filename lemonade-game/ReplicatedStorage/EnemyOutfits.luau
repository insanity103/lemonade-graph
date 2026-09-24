-- ModuleScript | ReplicatedStorage.EnemyOutfits | Looks for the enemy rigs built by EnemyCombat.
-- apply(model, archetypeKey, scale, role) recolours body parts and welds accessory parts onto
-- them. Enemy rigs are unanchored humanoids that walk, so unlike NpcOutfits (anchored hub NPCs)
-- every accessory is a WeldConstraint child of its body part: Massless, no collision, no query,
-- so it never bumps the rig or catches raycasts. Sizes and offsets are in unit-rig studs (R6:
-- torso 2×2×1, head 1.2³, limbs 1×2×1) and are multiplied by the archetype scale.
-- The quarry bandits (IronSquire / IronBerserker / Boss_Gorgon) share one kit family so they read
-- as one gang; role "elite" picks the "<archetype>_elite" variant when one exists.
--
-- Palette (PS99 pass, docs/ART_DIRECTION.md): the body under the outfit is the archetype's own
-- full-chroma plastic (EnemyCombat), so the big cloth pieces here -- tunic, hood, vest, cape --
-- are pale, calm tints (near-white cream / sky / mint, saturation 0.10-0.20) and only the small
-- pieces (belts, pauldrons, tool heads, eyes, sigils) carry a second saturated pop. That is the
-- calm-plus-vivid split PS99 runs on; an all-vivid or all-pastel rig reads flat. Nothing here is
-- grey, brown or muddy. Every piece is matte SmoothPlastic (see apply); Neon is kept for glows.
local EnemyOutfits = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function deg(x, y, z) return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z)) end
local FLAT = deg(0, 0, 90) -- cylinder axis vertical

-- Quarry gang: toy orange "rust" and toy blue "iron" pops over cream and near-white cloth.
local RUST = rgb(255, 140, 40) -- pick head, pauldrons, chest plate: the map's timber orange
local IRON_DARK = rgb(64, 144, 255) -- helm, chain, sledge head: the castle's full-chroma blue
local LEATHER = rgb(255, 238, 210) -- vest, belts, handles: calm cream
local RAG = rgb(255, 250, 240) -- masks, wraps: near-white
local DARK_CLOTH = rgb(188, 216, 255) -- hoods, belts, cape: pale sky blue
local SASH_RED = rgb(255, 64, 64)
local BANNER_RED = rgb(255, 84, 72)
local BONE = rgb(255, 255, 250)
local SKIN_TAN = rgb(255, 214, 170) -- peach
local SCAR = rgb(255, 120, 140) -- pink
local LANTERN = rgb(255, 214, 96)

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
			{ part = "Right Arm", name = "PickHandle", size = Vector3.new(0.25, 0.25, 2.4), offset = CFrame.new(0, -0.95, -0.9), color = LEATHER, material = "Wood", tool = true },
			{ part = "Right Arm", name = "PickHead", size = Vector3.new(1.6, 0.3, 0.3), offset = CFrame.new(0, -0.95, -2.0), color = RUST, material = "CorrodedMetal", tool = true },
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
			{ part = "Right Arm", name = "SledgeHandle", size = Vector3.new(0.3, 0.3, 3.0), offset = CFrame.new(0, -0.95, -1.1), color = LEATHER, material = "Wood", tool = true },
			{ part = "Right Arm", name = "SledgeHead", size = Vector3.new(1.5, 0.8, 0.8), offset = CFrame.new(0, -0.95, -2.5), color = IRON_DARK, material = "CorrodedMetal", tool = true },
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

-- Regional kits share a material language, while each rank changes its silhouette.
-- All pieces use the same local R6 coordinates as the quarry outfits above.
local function piece(part: string, name: string, size: Vector3, position: Vector3, color: Color3, material: string?)
	return { part = part, name = name, size = size, offset = CFrame.new(position), color = color, material = material or "Fabric" }
end

local function regionalKit(primary: Color3, secondary: Color3, trim: Color3, material: string, rank: number)
	local p = piece
	local kit = {
		p("Torso", "TunicFront", Vector3.new(2.08, 1.65, .16), Vector3.new(0, .1, -.54), primary),
		p("Torso", "TunicBack", Vector3.new(2.08, 1.65, .16), Vector3.new(0, .1, .54), primary),
		p("Torso", "WaistBinding", Vector3.new(2.16, .24, 1.16), Vector3.new(0, -.79, 0), secondary),
		p("Torso", "ChestSeam", Vector3.new(.12, 1.22, .05), Vector3.new(0, .19, -.65), trim),
		p("Left Arm", "LeftCuff", Vector3.new(1.08, .33, 1.08), Vector3.new(0, -.68, 0), secondary),
		p("Right Arm", "RightCuff", Vector3.new(1.08, .33, 1.08), Vector3.new(0, -.68, 0), secondary),
		p("Left Leg", "LeftGreave", Vector3.new(1.07, .65, 1.08), Vector3.new(0, -.43, -.03), secondary),
		p("Right Leg", "RightGreave", Vector3.new(1.07, .65, 1.08), Vector3.new(0, -.43, -.03), secondary),
		p("Head", "BrowBand", Vector3.new(1.26, .18, 1.24), Vector3.new(0, .42, 0), trim, material),
		p("Head", "LeftEye", Vector3.new(.17, .12, .08), Vector3.new(-.26, .08, -.84), trim, "Neon"),
		p("Head", "RightEye", Vector3.new(.17, .12, .08), Vector3.new(.26, .08, -.84), trim, "Neon"),
		p("Torso", "Collar", Vector3.new(1.54, .18, 1.1), Vector3.new(0, .89, 0), secondary),
	}
	if rank >= 2 then
		table.insert(kit, p("Torso", "BreastArmor", Vector3.new(1.85, 1.05, .23), Vector3.new(0, .31, -.65), secondary, material))
		table.insert(kit, p("Left Arm", "LeftShoulder", Vector3.new(1.35, .4, 1.35), Vector3.new(0, .89, 0), secondary, material))
		table.insert(kit, p("Right Arm", "RightShoulder", Vector3.new(1.35, .4, 1.35), Vector3.new(0, .89, 0), secondary, material))
	end
	if rank >= 3 then
		table.insert(kit, p("Torso", "MantleLeft", Vector3.new(.85, 2.55, .12), Vector3.new(-.6, -.7, .68), primary))
		table.insert(kit, p("Torso", "MantleRight", Vector3.new(.85, 2.55, .12), Vector3.new(.6, -.7, .68), primary))
		table.insert(kit, p("Head", "Crown", Vector3.new(1.48, .36, 1.42), Vector3.new(0, .68, 0), secondary, material))
		table.insert(kit, p("Torso", "ChestSigil", Vector3.new(.42, .42, .08), Vector3.new(0, .28, -.82), trim, "Neon"))
	end
	return kit
end

local function addKit(key: string, primary: Color3, secondary: Color3, trim: Color3, material: string, rank: number, extras)
	local accessories = regionalKit(primary, secondary, trim, material, rank)
	for _, spec in ipairs(extras) do table.insert(accessories, spec) end
	OUTFITS[key] = { colors = {}, accessories = accessories }
end

local p = piece
-- Frost: cyan body; pale ice cloth, cyan pieces, white glows.
local FROST_PALE = rgb(232, 246, 255)
local FROST = rgb(72, 204, 255)
local FROST_DEEP = rgb(24, 140, 255)
local FROST_POP = rgb(255, 255, 255)
addKit("FrostImp", FROST_PALE, FROST, FROST_POP, "Ice", 1, {
	p("Head", "FrostHood", Vector3.new(1.45, .62, 1.4), Vector3.new(0, .52, .12), FROST_DEEP),
	p("Head", "IceBrow", Vector3.new(.86, .17, .26), Vector3.new(0, .3, -.64), FROST, "Ice"),
	p("Torso", "ScarfTail", Vector3.new(.32, 1.18, .1), Vector3.new(.7, -.18, .65), FROST_POP),
})
addKit("GlacialGargoyle", FROST_PALE, FROST, FROST_POP, "Ice", 2, {
	p("Head", "LeftIceHorn", Vector3.new(.28, .88, .34), Vector3.new(-.46, .89, 0), FROST_POP, "Ice"),
	p("Head", "RightIceHorn", Vector3.new(.28, .88, .34), Vector3.new(.46, .89, 0), FROST_POP, "Ice"),
	p("Torso", "BackGlacier", Vector3.new(1.36, 1.75, .42), Vector3.new(0, .2, .73), FROST, "Ice"),
})
addKit("Boss_FrostRevenant", FROST_PALE, FROST_DEEP, FROST_POP, "Ice", 3, {
	p("Head", "LeftAntler", Vector3.new(.18, 1.45, .25), Vector3.new(-.56, 1.13, 0), FROST_POP, "Ice"),
	p("Head", "RightAntler", Vector3.new(.18, 1.45, .25), Vector3.new(.56, 1.13, 0), FROST_POP, "Ice"),
	p("Torso", "FrostStole", Vector3.new(.3, 1.55, .1), Vector3.new(-.66, -.15, -.68), FROST, "Ice"),
})

-- Cinder: orange body; cream cloth, coral-red pieces, yellow ember glows.
local CINDER_PALE = rgb(255, 240, 220)
local CINDER = rgb(255, 96, 48)
local CINDER_DEEP = rgb(255, 64, 40)
local EMBER = rgb(255, 224, 64)
addKit("CinderFiend", CINDER_PALE, CINDER, EMBER, "Basalt", 1, {
	p("Head", "EmberEyes", Vector3.new(.75, .14, .1), Vector3.new(0, .12, -.66), EMBER, "Neon"),
	p("Torso", "BurningSeam", Vector3.new(.12, 1.15, .07), Vector3.new(-.52, .15, -.66), EMBER, "Neon"),
	p("Right Arm", "CinderClaw", Vector3.new(.8, .45, 1.12), Vector3.new(0, -1.03, -.28), CINDER, "Basalt"),
})
addKit("MagmaJuggernaut", CINDER_PALE, CINDER, EMBER, "Basalt", 2, {
	p("Torso", "FurnaceCore", Vector3.new(.7, .65, .15), Vector3.new(0, .28, -.86), EMBER, "Neon"),
	p("Left Arm", "LeftLavaRidge", Vector3.new(.23, .75, .1), Vector3.new(0, .42, -.72), EMBER, "Neon"),
	p("Right Arm", "RightLavaRidge", Vector3.new(.23, .75, .1), Vector3.new(0, .42, -.72), EMBER, "Neon"),
})
addKit("Boss_InfernalColossus", CINDER_PALE, CINDER_DEEP, EMBER, "Basalt", 3, {
	p("Head", "LeftFurnaceHorn", Vector3.new(.34, 1.25, .4), Vector3.new(-.51, 1.04, 0), CINDER, "Basalt"),
	p("Head", "RightFurnaceHorn", Vector3.new(.34, 1.25, .4), Vector3.new(.51, 1.04, 0), CINDER, "Basalt"),
	p("Torso", "HeartVent", Vector3.new(.68, .9, .18), Vector3.new(0, .21, -.9), EMBER, "Neon"),
})

-- Void: violet body; pale lavender cloth, deep violet pieces, hot magenta glows.
local VOID_PALE = rgb(238, 226, 255)
local VOID = rgb(124, 56, 240)
local RIFT = rgb(255, 128, 255)
addKit("VoidShade", VOID_PALE, VOID, RIFT, "Slate", 1, {
	p("Head", "FacelessVeil", Vector3.new(1.05, .78, .16), Vector3.new(0, -.02, -.62), VOID),
	p("Head", "RiftEyes", Vector3.new(.62, .12, .07), Vector3.new(0, .1, -.74), RIFT, "Neon"),
	p("Torso", "SplitCape", Vector3.new(.72, 1.65, .09), Vector3.new(.59, -.62, .65), VOID),
})
addKit("AbyssTormentor", VOID_PALE, VOID, RIFT, "Slate", 2, {
	p("Head", "LeftVoidSpike", Vector3.new(.3, .96, .34), Vector3.new(-.53, .92, 0), VOID, "Slate"),
	p("Head", "RightVoidSpike", Vector3.new(.3, .96, .34), Vector3.new(.53, .92, 0), VOID, "Slate"),
	p("Torso", "BindingRune", Vector3.new(.65, .65, .08), Vector3.new(0, .28, -.83), RIFT, "Neon"),
})
addKit("Boss_VoidWraith", VOID_PALE, VOID, RIFT, "Slate", 3, {
	p("Head", "VoidHalo", Vector3.new(1.8, .17, 1.8), Vector3.new(0, 1.16, 0), RIFT, "Neon"),
	p("Torso", "LeftRiftWing", Vector3.new(.27, 2.3, .9), Vector3.new(-1.06, -.35, .9), VOID, "Slate"),
	p("Torso", "RightRiftWing", Vector3.new(.27, 2.3, .9), Vector3.new(1.06, -.35, .9), VOID, "Slate"),
})

-- Astral: gold body; ivory cloth, tangerine pieces, sun-yellow glows.
local ASTRAL_PALE = rgb(255, 252, 240)
local ASTRAL = rgb(255, 150, 40)
local ASTRAL_DEEP = rgb(255, 120, 32)
local SUN = rgb(255, 232, 80)
addKit("AstralWisp", ASTRAL_PALE, ASTRAL, SUN, "Metal", 1, {
	p("Head", "StarDiadem", Vector3.new(.68, .3, .15), Vector3.new(0, .65, -.58), SUN, "Neon"),
	p("Torso", "StarTabard", Vector3.new(.75, 1.3, .11), Vector3.new(0, -.11, -.67), ASTRAL_PALE),
	p("Torso", "StarMark", Vector3.new(.22, .22, .06), Vector3.new(0, .4, -.74), SUN, "Neon"),
})
addKit("SolarDominator", ASTRAL_PALE, ASTRAL, SUN, "Metal", 2, {
	p("Head", "SolarCrest", Vector3.new(.32, .96, .5), Vector3.new(0, 1.02, 0), SUN, "Neon"),
	p("Torso", "SunDisk", Vector3.new(.71, .71, .16), Vector3.new(0, .26, -.84), SUN, "Neon"),
	p("Torso", "BackStandard", Vector3.new(.23, 2.5, .22), Vector3.new(0, 1.02, .7), ASTRAL, "Metal"),
})
addKit("Boss_CelestialTitan", ASTRAL_PALE, ASTRAL_DEEP, SUN, "Metal", 3, {
	p("Head", "CelestialHalo", Vector3.new(2.2, .22, 2.2), Vector3.new(0, 1.21, 0), SUN, "Neon"),
	p("Torso", "SolarHeart", Vector3.new(.82, .82, .14), Vector3.new(0, .24, -.9), SUN, "Neon"),
	p("Torso", "BackSunray", Vector3.new(.3, 2.55, .18), Vector3.new(0, .78, .78), SUN, "Metal"),
})

-- Briarwood: lime body; pale leaf cloth, timber-orange pieces, yellow glows, a leaf-green hood.
local THORN_PALE = rgb(236, 255, 208)
local TIMBER = rgb(255, 158, 36)
local LEAF = rgb(48, 208, 88)
local THORN_POP = rgb(255, 236, 96)
addKit("ThornStalker", THORN_PALE, TIMBER, THORN_POP, "Wood", 1, {
	p("Head", "LeafHood", Vector3.new(1.48, .63, 1.45), Vector3.new(0, .52, .09), LEAF, "Grass"),
	p("Left Arm", "LeftThorn", Vector3.new(.2, .68, .35), Vector3.new(-.53, .27, -.35), TIMBER, "Wood"),
	p("Right Arm", "RightThorn", Vector3.new(.2, .68, .35), Vector3.new(.53, .27, -.35), TIMBER, "Wood"),
})
addKit("BriarBrute", THORN_PALE, TIMBER, THORN_POP, "Wood", 2, {
	p("Torso", "BriarSpine", Vector3.new(.48, 1.8, .44), Vector3.new(0, .22, .73), TIMBER, "Wood"),
	p("Left Arm", "LeftBriar", Vector3.new(.25, .93, .47), Vector3.new(-.51, .35, .02), TIMBER, "Wood"),
	p("Right Arm", "RightBriar", Vector3.new(.25, .93, .47), Vector3.new(.51, .35, .02), TIMBER, "Wood"),
})
addKit("RootWarden", THORN_PALE, TIMBER, THORN_POP, "Wood", 3, {
	p("Head", "LeftBranch", Vector3.new(.28, 1.43, .42), Vector3.new(-.48, 1.15, 0), TIMBER, "Wood"),
	p("Head", "RightBranch", Vector3.new(.28, 1.43, .42), Vector3.new(.48, 1.15, 0), TIMBER, "Wood"),
	p("Torso", "GroveHeart", Vector3.new(.7, .7, .12), Vector3.new(0, .27, -.85), THORN_POP, "Neon"),
})

-- Sunken Marsh: aqua body; pale mint cloth, deep aqua-blue pieces, lime-yellow reed pops.
local BOG_PALE = rgb(224, 255, 244)
local BOG = rgb(32, 160, 224)
local BOG_POP = rgb(200, 255, 120)
addKit("BogLurker", BOG_PALE, BOG, BOG_POP, "CorrodedMetal", 1, {
	p("Head", "MarshCowl", Vector3.new(1.45, .57, 1.46), Vector3.new(0, .5, .09), BOG),
	p("Torso", "ReedStrap", Vector3.new(.22, 1.73, .09), Vector3.new(-.54, .07, -.67), BOG_POP, "Grass"),
	p("Torso", "SiltSatchel", Vector3.new(.62, .56, .36), Vector3.new(.85, -.69, -.53), BOG),
})
addKit("MireHulk", BOG_PALE, BOG, BOG_POP, "CorrodedMetal", 2, {
	p("Torso", "RustedCage", Vector3.new(1.7, .34, .28), Vector3.new(0, .65, -.72), BOG, "CorrodedMetal"),
	p("Left Arm", "LeftReedMass", Vector3.new(1.26, .52, 1.23), Vector3.new(0, .77, 0), BOG_POP, "Grass"),
	p("Right Arm", "RightReedMass", Vector3.new(1.26, .52, 1.23), Vector3.new(0, .77, 0), BOG_POP, "Grass"),
})
addKit("DrownedBellwarden", BOG_PALE, BOG, BOG_POP, "CorrodedMetal", 3, {
	p("Head", "BellHelm", Vector3.new(1.56, .92, 1.5), Vector3.new(0, .47, 0), BOG, "CorrodedMetal"),
	p("Head", "BellClapper", Vector3.new(.22, .69, .22), Vector3.new(0, -.31, -.65), BOG_POP, "Metal"),
	p("Torso", "BellChain", Vector3.new(.23, 1.4, .18), Vector3.new(.75, -.12, -.76), BOG_POP, "CorrodedMetal"),
})

-- Stormwatch: blue body; pale cloud cloth, gold pieces, deep-blue hood and crest, pale lightning glows.
local STORM_PALE = rgb(236, 240, 255)
local STORM_GOLD = rgb(255, 200, 40)
local STORM_DEEP = rgb(40, 80, 240)
local LIGHTNING = rgb(255, 248, 140)
addKit("Stormcaller", STORM_PALE, STORM_GOLD, LIGHTNING, "Metal", 1, {
	p("Head", "StormHood", Vector3.new(1.43, .62, 1.43), Vector3.new(0, .5, .1), STORM_DEEP),
	p("Left Arm", "ConductingBracer", Vector3.new(1.13, .7, 1.13), Vector3.new(0, -.54, 0), STORM_GOLD, "Metal"),
	p("Torso", "StormBolt", Vector3.new(.2, .79, .08), Vector3.new(.3, .17, -.7), LIGHTNING, "Neon"),
})
addKit("ThunderConstruct", STORM_PALE, STORM_GOLD, LIGHTNING, "Metal", 2, {
	p("Torso", "PowerCore", Vector3.new(.67, .67, .17), Vector3.new(0, .27, -.85), LIGHTNING, "Neon"),
	p("Left Arm", "LeftConductor", Vector3.new(.27, 1.17, .25), Vector3.new(0, .11, -.64), LIGHTNING, "Neon"),
	p("Right Arm", "RightConductor", Vector3.new(.27, 1.17, .25), Vector3.new(0, .11, -.64), LIGHTNING, "Neon"),
})
addKit("TempestWarden", STORM_PALE, STORM_GOLD, LIGHTNING, "Metal", 3, {
	p("Head", "ObservatoryCrest", Vector3.new(.28, 1.26, .64), Vector3.new(0, 1.09, 0), STORM_DEEP, "Metal"),
	p("Torso", "LightningHeart", Vector3.new(.65, .87, .18), Vector3.new(0, .28, -.9), LIGHTNING, "Neon"),
	p("Torso", "BackAntenna", Vector3.new(.2, 2.27, .2), Vector3.new(0, 1.1, .69), STORM_DEEP, "Metal"),
})

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
	-- A rig that was handed a real sword (EnemyCombat welds it before the outfit goes on)
	-- doesn't also carry its pick or sledge in that hand.
	local armed = model:FindFirstChild("Sword") ~= nil
	for _, spec in ipairs(specsFor(key)) do
		if spec.tool and armed then continue end
		local body = model:FindFirstChild(spec.part)
		if not (body and body:IsA("BasePart")) then continue end
		local acc = Instance.new("Part")
		acc.Name = spec.name
		acc.Size = spec.size * scale
		acc.Color = spec.color
		-- PS99 pass: every accessory is matte plastic. A spec's material string is kept as the
		-- designer's note of what the piece is (ice, wood, metal), but Roblox's Fabric / Wood /
		-- CorrodedMetal / Ice / Basalt / Slate / Grass / Metal are photoreal textures that fight
		-- the toy look; only Neon (glows) is honoured.
		acc.Material = if spec.material == "Neon" then Enum.Material.Neon else Enum.Material.SmoothPlastic
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
