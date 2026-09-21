--// BossSwordFactory  (rolls and builds an equippable boss weapon Tool from the pool roster)
-- Shared by SwordDropSystem (boss drops), MerchantSystem (purchases), AdminSystem (gifts), the
-- Vault / Trade rebuild path and the Studio-only gallery. The server owns every roll here:
--   rollDrop  rarity -> which sword of the boss's pool -> base stat jitter (BossWeapons tables)
--   build     rollDrop (or the caller's fixed sword / rarity) + modifier roll + the Tool itself
--   reroll    the Reforge anvil: new modifiers, same sword / rarity / rolled base / look
--   rebuild   a saved sword restored exactly, nothing re-rolled
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")

local WeaponModifiers = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponModifiers"))
local BossWeapons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BossWeapons"))
local CombatUtil = require(script.Parent:WaitForChild("CombatUtil"))

local BossSwordFactory = {}

-- Held length of a boss sword whose look names none.
local DEFAULT_SWORD_LENGTH = 4.2
-- The starter sword's block parts (RuntimeBootstrap builds them on StarterPack.ClassicSword).
local BLOCK_PARTS = { "Pommel", "Guard", "Blade", "TipUpper", "TipLower" }
local BLOCK_BLADE_LEN, BLOCK_GUARD_BACK = 2.60, 0.82 -- stock blade length; z where the blade starts

-- ---------------------------------------------------------------- the rolls
-- Rarity from a ladder (one roll, the odds the toast prints). A boss drop rolls
-- BossWeapons.RarityOdds; a normal enemy's drop rolls the ladder of its rig's rank, which
-- DropRules hands in as opts.rarityOdds. Both sum to 1 and both are published.
local function rollRarity(odds)
	odds = odds or BossWeapons.RarityOdds
	local r = math.random()
	local acc = 0
	for _, row in ipairs(odds) do
		acc += row.p
		if r <= acc then
			return row.rarity, row.p
		end
	end
	local last = odds[#odds]
	return last.rarity, last.p
end

-- The rarity a floor lifts a roll to (drop pity: never worse than Rare on the pitied drop).
local RARITY_INDEX = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
local function applyFloor(rarity, floor, odds)
	if not floor or (RARITY_INDEX[rarity] or 1) >= (RARITY_INDEX[floor] or 1) then
		return rarity, nil
	end
	for _, row in ipairs(odds or BossWeapons.RarityOdds) do
		if row.rarity == floor then return floor, row.p end
	end
	return floor, nil
end

-- Which regular sword of the pool, by weight.
local function rollSword(pool)
	local total = 0
	for _, def in ipairs(pool.swords) do
		total += def.weight
	end
	local r = math.random() * total
	for _, def in ipairs(pool.swords) do
		r -= def.weight
		if r <= 0 then
			return def
		end
	end
	return pool.swords[#pool.swords]
end

-- The three-stage drop roll for a boss. Returns a resolved weaponData (BossWeapons.Resolve shape)
-- whose baseMult already carries the jitter, plus the listed base and the rarity's odds.
-- opts.sword / opts.rarity fix a stage (merchant, admin, gallery); opts.jitter = false skips the
-- stat roll (merchant listings sell the listed stat).
function BossSwordFactory.rollDrop(archetypeKey, opts)
	opts = opts or {}
	local pool = BossWeapons.PoolFor(archetypeKey)
	if not pool then
		local fb = table.clone(BossWeapons.Fallback)
		fb.listedBase = fb.baseMult
		fb.rarityOdds = 1
		return fb
	end
	local odds = opts.rarityOdds or pool.rarityOdds or BossWeapons.RarityOdds
	local rarity, rarityP
	if opts.rarity then
		rarity = opts.rarity
		for _, row in ipairs(odds) do
			if row.rarity == rarity then rarityP = row.p end
		end
	else
		rarity, rarityP = rollRarity(odds)
		local floored, flooredP = applyFloor(rarity, opts.rarityFloor, odds)
		if floored ~= rarity then
			rarity, rarityP = floored, flooredP or rarityP
		end
	end
	local name = opts.sword
	if not name then
		name = if rarity == "Legendary" then pool.legendary.name else rollSword(pool).name
	end
	local data = BossWeapons.Resolve(archetypeKey, name, rarity)
	data.listedBase = data.baseMult
	data.rarityOdds = rarityP or 0
	data.poolKey = archetypeKey
	if opts.jitter ~= false then
		local j = BossWeapons.STAT_JITTER
		data.baseMult = math.floor(data.listedBase * (1 - j + math.random() * 2 * j) * 100 + 0.5) / 100
	end
	return data
end

-- ---------------------------------------------------------------- the look
local function findMesh(look)
	local wanted = look and look.mesh or "Template"
	local folder = ServerStorage:FindFirstChild(CombatUtil.SWORD_MESH_FOLDER)
	if wanted ~= "Blocks" and wanted ~= "Template" then
		local mesh = folder and folder:FindFirstChild(wanted)
		if mesh and mesh:IsA("MeshPart") then
			return mesh
		end
		wanted = "Template" -- not imported yet: the shared template stands in
	end
	if wanted == "Template" then
		local fallback = ServerStorage:FindFirstChild("SwordMeshTemplate")
		if fallback and fallback:IsA("MeshPart") then
			return fallback
		end
	end
	return nil -- "Blocks", or no mesh in the place: the starter sword's block parts
end

local function darker(color, k)
	return Color3.new(color.R * k, color.G * k, color.B * k)
end

-- The starter sword's block parts, built here if the template came without them (StarterPack's
-- ClassicSword only gets its parts from RuntimeBootstrap at run time), so a "Blocks" sword is
-- never a Tool with no Handle. Same geometry and welds as RuntimeBootstrap.
local function ensureBlockParts(tool)
	local function ensurePart(name, className, size, color, material, shape)
		local part = tool:FindFirstChild(name)
		if part and not part:IsA(className) then
			part:Destroy()
			part = nil
		end
		if not part then
			part = Instance.new(className)
			part.Name = name
			part.Size = size
			part.Color = color
			part.Material = material
			if shape and part:IsA("Part") then part.Shape = shape end
			part.Parent = tool
		end
		part.CanCollide = false
		part.CanTouch = false
		part.Massless = true
		return part
	end
	local leather = Color3.fromRGB(92, 66, 50)
	local bronze = Color3.fromRGB(170, 124, 60)
	local steel = Color3.fromRGB(185, 192, 200)
	local handle = ensurePart("Handle", "Part", Vector3.new(0.32, 0.32, 1.10), leather, Enum.Material.SmoothPlastic, Enum.PartType.Block)
	if not handle:IsA("MeshPart") then
		local pommel = ensurePart("Pommel", "Part", Vector3.new(0.44, 0.44, 0.44), bronze, Enum.Material.Metal, Enum.PartType.Ball)
		local guard = ensurePart("Guard", "Part", Vector3.new(1.30, 0.26, 0.32), bronze, Enum.Material.Metal, Enum.PartType.Block)
		local blade = ensurePart("Blade", "Part", Vector3.new(0.22, 0.60, 2.60), steel, Enum.Material.Metal, Enum.PartType.Block)
		local tipUpper = ensurePart("TipUpper", "WedgePart", Vector3.new(0.22, 0.30, 0.50), steel, Enum.Material.Metal)
		local tipLower = ensurePart("TipLower", "WedgePart", Vector3.new(0.22, 0.30, 0.50), steel, Enum.Material.Metal)
		local function ensureWeld(name, part1, c0)
			local weld = handle:FindFirstChild(name)
			if weld and not weld:IsA("Weld") then weld:Destroy(); weld = nil end
			if not weld then
				weld = Instance.new("Weld")
				weld.Name = name
				weld.Parent = handle
			end
			weld.Part0 = handle
			weld.Part1 = part1
			weld.C0 = c0
		end
		ensureWeld("WeldPommel", pommel, CFrame.new(0, 0, 0.66))
		ensureWeld("WeldGuard", guard, CFrame.new(0, 0, -0.66))
		ensureWeld("WeldBlade", blade, CFrame.new(0, 0, -2.09))
		ensureWeld("WeldTipUpper", tipUpper, CFrame.new(0, 0.15, -3.64))
		ensureWeld("WeldTipLower", tipLower, CFrame.new(0, -0.15, -3.64) * CFrame.Angles(0, 0, math.pi))
	end
	if tool.Grip == CFrame.new() then
		tool.Grip = CFrame.Angles(-math.pi / 2, 0, 0)
	end
end

-- Restyle the starter sword's block parts to this look: blade colour / material / glow, accent
-- guard and pommel, and the blade's length, width and guard span (the welds move with it).
local function restyleBlocks(tool, look)
	local handle = tool:FindFirstChild("Handle")
	if not handle then
		return
	end
	local blade, guard, pommel = tool:FindFirstChild("Blade"), tool:FindFirstChild("Guard"), tool:FindFirstChild("Pommel")
	local tipUpper, tipLower = tool:FindFirstChild("TipUpper"), tool:FindFirstChild("TipLower")
	local accent = look.accent or Color3.fromRGB(170, 124, 60)
	local bladeK, widthK, guardK = look.blade or 1, look.width or 1, look.guard or 1
	local bladeLen = BLOCK_BLADE_LEN * bladeK
	handle.Color = darker(accent, 0.45)
	handle.Material = Enum.Material.SmoothPlastic
	if blade and blade:IsA("BasePart") then
		blade.Size = Vector3.new(0.22, 0.60 * widthK, bladeLen)
		CombatUtil.applyWeaponAppearance(blade, look.color, look.material)
		local weld = handle:FindFirstChild("WeldBlade")
		if weld and weld:IsA("Weld") then
			weld.C0 = CFrame.new(0, 0, -BLOCK_GUARD_BACK - bladeLen / 2)
		end
	end
	for _, tip in ipairs({ tipUpper, tipLower }) do
		if tip and tip:IsA("BasePart") then
			tip.Size = Vector3.new(0.22, 0.30 * widthK, 0.50)
			CombatUtil.applyWeaponAppearance(tip, look.color, look.material ~= Enum.Material.Neon and look.material or Enum.Material.Metal)
		end
	end
	local tipZ = -BLOCK_GUARD_BACK - bladeLen - 0.25
	local wu, wl = handle:FindFirstChild("WeldTipUpper"), handle:FindFirstChild("WeldTipLower")
	if wu and wu:IsA("Weld") then wu.C0 = CFrame.new(0, 0.15 * widthK, tipZ) end
	if wl and wl:IsA("Weld") then wl.C0 = CFrame.new(0, -0.15 * widthK, tipZ) * CFrame.Angles(0, 0, math.pi) end
	if guard and guard:IsA("BasePart") then
		guard.Size = Vector3.new(1.30 * guardK, 0.26, 0.32)
		guard.Color = accent
		guard.Material = Enum.Material.Metal
	end
	if pommel and pommel:IsA("BasePart") then
		pommel.Color = accent
		pommel.Material = look.material == Enum.Material.Neon and Enum.Material.Neon or Enum.Material.Metal
	end
end

-- Give the tool this look: swap the Handle for the mesh the look names (or its fallback), sized
-- to the look's length, or restyle the block parts when the look is "Blocks" / no mesh exists.
-- Idempotent: reroll and rebuild re-run it on every sword.
local function fitLook(tool, look)
	look = look or BossWeapons.Fallback.look
	local mesh = findMesh(look)
	local length = look.length or DEFAULT_SWORD_LENGTH
	if not mesh then
		if not tool:GetAttribute("MeshGripFixed") then
			ensureBlockParts(tool)
		end
		restyleBlocks(tool, look)
		return
	end
	local old = tool:FindFirstChild("Handle")
	if old and old:IsA("MeshPart") and old.MeshId == mesh.MeshId then
		CombatUtil.sizeSwordMesh(old, length)
		if look.textured == false then old.TextureID = "" end
		CombatUtil.applyWeaponAppearance(old, look.color, look.material)
		return
	end
	local handle = mesh:Clone()
	handle.Name = "Handle"
	if look.textured == false then
		handle.TextureID = "" -- a painted texture would hide the colour this variant is built on
	end
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	CombatUtil.sizeSwordMesh(handle, length)
	if old then
		for _, child in ipairs(old:GetChildren()) do
			if child:IsA("Sound") then child:Clone().Parent = handle end
		end
		old:Destroy()
	end
	-- The block parts were welded to the old Handle; with it gone they would float loose.
	for _, name in ipairs(BLOCK_PARTS) do
		local part = tool:FindFirstChild(name)
		if part then part:Destroy() end
	end
	handle.Parent = tool
	CombatUtil.applyWeaponAppearance(handle, look.color, look.material)
	-- Tool.Grip was set up for the block Handle, whose local origin already IS the grip. A
	-- mesh is the whole sword centred on the blade, so slide the grip point back toward the
	-- pommel by the same fraction EnemyCombat uses to place a mesh in an enemy's hand. Guarded
	-- so a sword forged before this fix self-heals once and never shifts twice.
	if not tool:GetAttribute("MeshGripFixed") then
		tool.Grip = tool.Grip * CFrame.new(0, 0, -CombatUtil.SWORD_GRIP_FRAC * length)
		tool:SetAttribute("MeshGripFixed", true)
	end
end
BossSwordFactory.fitLook = fitLook

local function copyClassicBits(tool)
	-- The template ships without the activation script or swing sounds; copy both from
	-- ClassicSword so every sword swings and sounds the same.
	local classic = StarterPack:FindFirstChild("ClassicSword")
	local clientScript = classic and classic:FindFirstChild("SwordClient")
	if clientScript and not tool:FindFirstChild("SwordClient") then
		clientScript:Clone().Parent = tool
	end
	local classicHandle = classic and classic:FindFirstChild("Handle")
	local bossHandle = tool:FindFirstChild("Handle")
	if classicHandle and bossHandle then
		for _, sound in ipairs(classicHandle:GetChildren()) do
			if sound:IsA("Sound") and not bossHandle:FindFirstChild(sound.Name) then
				sound:Clone().Parent = bossHandle
			end
		end
	end
end

local function newTemplateTool()
	local template = ServerStorage:FindFirstChild("BossSwordTool")
		or StarterPack:FindFirstChild("ClassicSword")
	if template then
		return template:Clone()
	end
	local tool = Instance.new("Tool")
	tool.RequiresHandle = true
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = Vector3.new(1, 1, 4)
	h.Parent = tool
	return tool
end

-- ---------------------------------------------------------------- build
-- opts.sword         fix which sword of the pool (by name); default: rolled by weight
-- opts.rarity        fix the rarity; default: rolled from BossWeapons.RarityOdds
-- opts.jitter        false = the listed base, no +-5% roll (merchant). Default true.
-- opts.blessedBonus  added to WeaponModifiers.EXTRA_SLOT_CHANCE (drops: +5% at rebirth 5+)
-- opts.allowBlessed  false = never roll a Blessed extra slot. Defaults to true.
-- opts.rarityOdds    the rarity ladder to roll (DropRules hands the rig's rank ladder in)
-- opts.rarityFloor   drop pity: lift a roll below this rarity to it
-- opts.luck          long-tail luck multiplier (WeaponModifiers.LuckFrom); drops pass the killer's.
-- Returns tool, mods, fullName, gotExtraSlot, weaponData (weaponData.rarity / baseMult / name /
-- bossName / listedBase / rarityOdds / isLegendary describe what was rolled).
function BossSwordFactory.build(archetypeKey, opts)
	opts = opts or {}
	local allowBlessed = opts.allowBlessed ~= false
	local weaponData = BossSwordFactory.rollDrop(archetypeKey, opts)

	local tool = newTemplateTool()
	fitLook(tool, weaponData.look)

	-- Roll modifiers by rarity. A bonus of -1 pushes the Blessed chance below zero,
	-- which is how purchases guarantee no extra slot.
	local mods, gotExtraSlot, variant = WeaponModifiers.RollModifiers(weaponData.rarity,
		allowBlessed and (opts.blessedBonus or 0) or -1.0, false, { luck = opts.luck })
	if not allowBlessed then
		gotExtraSlot = false
	end

	local fullName = BossSwordFactory.applyRoll(tool, weaponData, archetypeKey, mods, gotExtraSlot, variant)
	copyClassicBits(tool)
	return tool, mods, fullName, gotExtraSlot, weaponData
end

-- Write a roll onto a tool: name, prefixes and the combat attributes. Shared by build (fresh
-- drops and purchases) and reroll (the Reforge anvil). weaponData.baseMult is the sword's rolled
-- base; weaponData.listedBase (optional) the pool's listed base at that rarity.
-- variant (optional): a mutation name (WeaponModifiers.Variants) that multiplies every modifier's
-- bonus and leads the name ("Sour Blessed Mythic ... Astral Eclipse"); saved as attribute Variant.
function BossSwordFactory.applyRoll(tool, weaponData, archetypeKey, mods, gotExtraSlot, variant)
	local prefixNames = {}
	local bonusDamage = weaponData.inherentBonusDmg or 0
	local critChance = weaponData.inherentCrit or 0
	local rangeBonus = weaponData.inherentRange or 0
	local knockbackBonus = weaponData.inherentKnockback or 0
	local variantData = typeof(variant) == "string" and WeaponModifiers.VariantByName[variant] or nil
	local mult = variantData and variantData.mult or 1

	for _, mod in ipairs(mods) do
		table.insert(prefixNames, mod.name)
		if mod.category == "Damage" then
			bonusDamage += mod.bonus * mult
		elseif mod.category == "CritChance" then
			critChance += mod.bonus * mult
		elseif mod.category == "Range" then
			rangeBonus += mod.bonus * mult
		elseif mod.category == "Knockback" then
			knockbackBonus += mod.bonus * mult
		end
	end

	local namePrefixes = {}
	if variantData then
		table.insert(namePrefixes, variantData.name)
	end
	if gotExtraSlot then
		table.insert(namePrefixes, "Blessed")
	end
	for _, p in ipairs(prefixNames) do
		table.insert(namePrefixes, p)
	end

	local fullName = (#namePrefixes > 0 and (table.concat(namePrefixes, " ") .. " ") or "") .. weaponData.name
	tool.Name = fullName

	tool:SetAttribute("BossTier", BossWeapons.GetTier(archetypeKey))
	-- The exact pool this sword came from. BossTier alone cannot say it any more: a zone's lesser
	-- pool carries its region's tier, so a Lodestone Edge and a Pit Sovereign are both tier 1.
	-- Saves written before this attribute existed fall back to the tier (describeTool).
	tool:SetAttribute("PoolKey", archetypeKey)
	tool:SetAttribute("Lesser", BossWeapons.IsLesserPool(archetypeKey) or nil)
	tool:SetAttribute("Rarity", weaponData.rarity)
	tool:SetAttribute("DamageMult", weaponData.baseMult)
	tool:SetAttribute("PoolBase", weaponData.listedBase or weaponData.baseMult)
	tool:SetAttribute("BonusDamagePct", bonusDamage)
	tool:SetAttribute("CritChance", critChance)
	tool:SetAttribute("RangeBonus", rangeBonus)
	tool:SetAttribute("KnockbackBonus", knockbackBonus)
	tool:SetAttribute("ExtraSlot", gotExtraSlot)
	tool:SetAttribute("Variant", variantData and variantData.name or nil)
	tool:SetAttribute("Prefixes", table.concat(prefixNames, ", "))
	tool:SetAttribute("BossDrop", true)
	tool:SetAttribute("BaseWeaponName", weaponData.name)
	tool:SetAttribute("WeaponAppearanceMaterial", weaponData.material.Name)
	return fullName
end

-- The sword a tool IS, from its attributes: its pool entry at its own rarity, keeping the base it
-- rolled when it dropped (an older save keeps the base it was saved with).
local function describeTool(tool)
	local tier = tonumber(tool:GetAttribute("BossTier")) or 1
	local poolKey = tool:GetAttribute("PoolKey")
	local archetypeKey = (typeof(poolKey) == "string" and BossWeapons.PoolFor(poolKey) and poolKey)
		or BossWeapons.ArchetypeByTier[tier]
	if not archetypeKey then
		return nil
	end
	local data = BossWeapons.Resolve(archetypeKey, tool:GetAttribute("BaseWeaponName"), tool:GetAttribute("Rarity"))
	local savedRarity = tool:GetAttribute("Rarity")
	if typeof(savedRarity) == "string" and WeaponModifiers.RarityConfig[savedRarity] then
		data.rarity = savedRarity
	end
	local rolled = tonumber(tool:GetAttribute("DamageMult"))
	if rolled and rolled > 0 then
		data.listedBase = tonumber(tool:GetAttribute("PoolBase")) or data.baseMult
		data.baseMult = rolled
	end
	return data, archetypeKey
end
BossSwordFactory.describeTool = describeTool

-- Re-roll an existing boss sword's modifiers in place (the Reforge anvil). Sword, rarity, rolled
-- base and look stay; a Blessed sword keeps its extra slot. Returns the new mods and name.
-- minTopTier (optional): the pity floor — if no rolled modifier reaches it, the best one is
-- raised to it, so a run of bad luck cannot leave the sword worse at the top end.
-- keepNames (optional): modifier names currently on the sword to lock; each survives the reroll
-- in place of one rolled slot (a locked category is never rolled twice). The slot count is
-- whatever the rarity rolled, so locks never add slots.
-- opts.luck (optional): the long-tail luck multiplier for this strike (default 1).
-- Returns mods, fullName, gotExtraSlot, pityApplied, variantName.
-- opts.luck is the whole luck the roll is made at: the player's earned luck (kill streak, Lucky
-- Charge, rebirths) already multiplied by the forge strike's blow (ReforgeSystem: PERFECT 2x,
-- GOOD 1.5x, OK 1x). It scales the ladder's long tail only, never the body, so a good blow buys
-- better odds and never a guarantee.
function BossSwordFactory.reroll(tool, blessedBonus, minTopTier, keepNames, opts)
	opts = opts or {}
	local weaponData, archetypeKey = describeTool(tool)
	if not weaponData then return nil end
	-- Self-heal: a sword forged before the Grip fix in fitLook still has the hand centred on the
	-- blade, and one forged before the pools has the starter look. Re-fitting is idempotent.
	fitLook(tool, weaponData.look)
	local mods, gotExtraSlot, variant = WeaponModifiers.RollModifiers(weaponData.rarity, blessedBonus or 0,
		tool:GetAttribute("ExtraSlot") == true, { luck = opts.luck })
	if keepNames and #keepNames > 0 then
		local rolledCount = #mods
		local kept, keptCategories = {}, {}
		for _, keepName in ipairs(keepNames) do
			for category, data in pairs(WeaponModifiers.Categories) do
				for tierIndex, entry in ipairs(data.Tiers) do
					if entry.name == keepName and not keptCategories[category] then
						keptCategories[category] = true
						table.insert(kept, { category = category, name = entry.name, bonus = entry.bonus, desc = entry.desc, tier = tierIndex, kept = true })
					end
				end
			end
		end
		for i = #mods, 1, -1 do -- drop fresh rolls in locked categories
			if keptCategories[mods[i].category] then table.remove(mods, i) end
		end
		while #mods > math.max(rolledCount, #kept) - #kept do table.remove(mods) end
		for i = #kept, 1, -1 do table.insert(mods, 1, kept[i]) end
	end
	local pityApplied = false
	if minTopTier and #mods > 0 then
		local best, bestIndex = 0, 1
		for i, mod in ipairs(mods) do
			if mod.tier > best then best, bestIndex = mod.tier, i end
		end
		if best < minTopTier then
			local category = WeaponModifiers.Categories[mods[bestIndex].category]
			local target = math.min(minTopTier, #category.Tiers)
			local tierData = category.Tiers[target]
			local odds = WeaponModifiers.TierOdds(weaponData.rarity, 0, opts.luck)
			mods[bestIndex] = { category = mods[bestIndex].category, name = tierData.name, bonus = tierData.bonus,
				desc = tierData.desc, tier = target, p = odds[target], oneIn = WeaponModifiers.OneIn(odds[target]), pity = true }
			pityApplied = true
		end
	end
	local fullName = BossSwordFactory.applyRoll(tool, weaponData, archetypeKey, mods, gotExtraSlot, variant)
	return mods, fullName, gotExtraSlot, pityApplied, variant
end

-- Rebuild a previously-saved boss sword from its serialized attribute set (see
-- PlayerDataService). Nothing is re-rolled -- the exact stats and look are restored.
function BossSwordFactory.rebuild(data)
	if typeof(data) ~= "table" then return nil end
	local template = ServerStorage:FindFirstChild("BossSwordTool")
		or StarterPack:FindFirstChild("ClassicSword")
	if not template then return nil end

	local tool = template:Clone()
	tool.Name = typeof(data.name) == "string" and data.name or "Relic Sword"
	tool:SetAttribute("BossDrop", true)
	local attrs = typeof(data.attrs) == "table" and data.attrs or {}
	for key, value in pairs(attrs) do
		tool:SetAttribute(key, value)
	end

	local weaponData = describeTool(tool)
	local look = weaponData and weaponData.look or BossWeapons.Fallback.look
	fitLook(tool, look)

	local handle = tool:FindFirstChild("Handle")
	if handle then
		-- A save made before the pools stored the rendered handle colour and material; a sword
		-- whose pool entry names a colour now wears that, so every Frostfang Cleaver matches.
		local color = look.color
		if not color and typeof(data.color) == "table"
			and typeof(data.color[1]) == "number"
			and typeof(data.color[2]) == "number"
			and typeof(data.color[3]) == "number" then
			color = Color3.new(data.color[1], data.color[2], data.color[3])
		end
		local materialName = attrs.WeaponAppearanceMaterial
		local material = look.material or (typeof(materialName) == "string" and Enum.Material[materialName]) or nil
		if not material and typeof(data.material) == "string" then
			material = Enum.Material[data.material]
		end
		if handle:IsA("MeshPart") then
			CombatUtil.applyWeaponAppearance(handle, color, material)
		end
	end

	copyClassicBits(tool)
	return tool
end

return BossSwordFactory
