--// BossSwordFactory  (builds an equippable boss weapon Tool)
-- Shared by SwordDropSystem (boss drops) and MerchantSystem (purchases), which used to carry
-- near-identical copies of this function. Their one behavioural difference -- purchases never
-- roll a Blessed extra slot -- is opts.allowBlessed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")

local WeaponModifiers = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponModifiers"))
local BossWeapons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BossWeapons"))
local CombatUtil = require(script.Parent:WaitForChild("CombatUtil"))

local BossSwordFactory = {}

-- Held length of every boss sword.
local HELD_SWORD_LENGTH = 4.2

-- Replace the template's Handle with this boss's unique mesh, if one has been imported.
local function fitBossMesh(tool, archetypeKey)
	local mesh, isBossSpecific = CombatUtil.getSwordMesh(archetypeKey)
	if not mesh or not isBossSpecific then
		return
	end
	local handle = mesh:Clone()
	handle.Name = "Handle"
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	CombatUtil.sizeSwordMesh(handle, HELD_SWORD_LENGTH)
	local old = tool:FindFirstChild("Handle")
	if old then
		old:Destroy()
	end
	handle.Parent = tool
	-- Tool.Grip was set up for the block ClassicSword Handle, whose local origin already IS
	-- the grip -- the blade/guard/pommel were welded out FROM it. A boss mesh is the whole
	-- sword centred on the blade, so without this the player's hand lands on the middle of the
	-- blade instead of the grip. Slide the grip point back toward the pommel by the same
	-- fraction EnemyCombat uses to place a mesh in an enemy's hand.
	-- Idempotent (guarded by the attribute below): reroll() re-runs this on every sword so one
	-- forged before this fix self-heals, and doing that must not shift an already-fixed Grip
	-- a second time.
	if not tool:GetAttribute("MeshGripFixed") then
		tool.Grip = tool.Grip * CFrame.new(0, 0, -CombatUtil.SWORD_GRIP_FRAC * HELD_SWORD_LENGTH)
		tool:SetAttribute("MeshGripFixed", true)
	end
end

-- opts.blessedBonus  added to WeaponModifiers.EXTRA_SLOT_CHANCE (drops: +5% at rebirth 5+)
-- opts.allowBlessed  false = never roll a Blessed extra slot. Defaults to true.
-- Returns tool, mods, fullName, gotExtraSlot, weaponData (the old makeBossSword contract).
function BossSwordFactory.build(archetypeKey, opts)
	opts = opts or {}
	local allowBlessed = opts.allowBlessed ~= false
	local weaponData = BossWeapons.Get(archetypeKey)

	local template = ServerStorage:FindFirstChild("BossSwordTool")
		or StarterPack:FindFirstChild("ClassicSword")
	local tool
	if template then
		tool = template:Clone()
	else
		tool = Instance.new("Tool")
		tool.RequiresHandle = true
		local h = Instance.new("Part")
		h.Name = "Handle"
		h.Size = Vector3.new(1, 1, 4)
		h.Parent = tool
	end

	fitBossMesh(tool, archetypeKey)

	-- Roll modifiers by rarity. A bonus of -1 pushes the Blessed chance below zero,
	-- which is how purchases guarantee no extra slot.
	local mods, gotExtraSlot = WeaponModifiers.RollModifiers(weaponData.rarity,
		allowBlessed and (opts.blessedBonus or 0) or -1.0)
	if not allowBlessed then
		gotExtraSlot = false
	end

	local fullName = BossSwordFactory.applyRoll(tool, weaponData, archetypeKey, mods, gotExtraSlot)

	local handle = tool:FindFirstChild("Handle")
	if handle then
		CombatUtil.applyWeaponAppearance(handle, weaponData.color, weaponData.material)
	end

	-- The BossSwordTool template ships without the activation script or swing sounds;
	-- copy both from ClassicSword so every sword swings and sounds the same.
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

	return tool, mods, fullName, gotExtraSlot, weaponData
end

-- Write a modifier roll onto a tool: name, prefixes and the combat attributes. Shared by
-- build (fresh drops and purchases) and reroll (the Reforge anvil).
function BossSwordFactory.applyRoll(tool, weaponData, archetypeKey, mods, gotExtraSlot)
	local prefixNames = {}
	local bonusDamage = weaponData.inherentBonusDmg or 0
	local critChance = weaponData.inherentCrit or 0
	local rangeBonus = weaponData.inherentRange or 0
	local knockbackBonus = weaponData.inherentKnockback or 0

	for _, mod in ipairs(mods) do
		table.insert(prefixNames, mod.name)
		if mod.category == "Damage" then
			bonusDamage += mod.bonus
		elseif mod.category == "CritChance" then
			critChance += mod.bonus
		elseif mod.category == "Range" then
			rangeBonus += mod.bonus
		elseif mod.category == "Knockback" then
			knockbackBonus += mod.bonus
		end
	end

	local namePrefixes = {}
	if gotExtraSlot then
		table.insert(namePrefixes, "Blessed")
	end
	for _, p in ipairs(prefixNames) do
		table.insert(namePrefixes, p)
	end

	local fullName = (#namePrefixes > 0 and (table.concat(namePrefixes, " ") .. " ") or "") .. weaponData.name
	tool.Name = fullName

	tool:SetAttribute("BossTier", BossWeapons.GetTier(archetypeKey))
	tool:SetAttribute("Rarity", weaponData.rarity)
	tool:SetAttribute("DamageMult", weaponData.baseMult)
	tool:SetAttribute("BonusDamagePct", bonusDamage)
	tool:SetAttribute("CritChance", critChance)
	tool:SetAttribute("RangeBonus", rangeBonus)
	tool:SetAttribute("KnockbackBonus", knockbackBonus)
	tool:SetAttribute("ExtraSlot", gotExtraSlot)
	tool:SetAttribute("Prefixes", table.concat(prefixNames, ", "))
	tool:SetAttribute("BossDrop", true)
	tool:SetAttribute("BaseWeaponName", weaponData.name)
	tool:SetAttribute("WeaponAppearanceMaterial", weaponData.material.Name)
	return fullName
end

-- Re-roll an existing boss sword's modifiers in place (the Reforge anvil). Rarity, base
-- damage and look stay; a Blessed sword keeps its extra slot. Returns the new mods and name.
-- minTopTier (optional): the pity floor — if no rolled modifier reaches it, the best one is
-- raised to it, so a run of bad luck cannot leave the sword worse at the top end.
-- keepNames (optional): modifier names currently on the sword to lock; each survives the reroll
-- in place of one rolled slot (a locked category is never rolled twice). The slot count is
-- whatever the rarity rolled, so locks never add slots.
function BossSwordFactory.reroll(tool, blessedBonus, minTopTier, keepNames)
	local tier = tonumber(tool:GetAttribute("BossTier")) or 1
	local archetypeKey = BossWeapons.ArchetypeByTier[tier]
	local weaponData = archetypeKey and BossWeapons.Get(archetypeKey)
	if not weaponData then return nil end
	-- Self-heal: a sword forged before the Grip fix in fitBossMesh still has the hand centred
	-- on the blade. Re-fitting is idempotent, so this is a no-op on a sword that's already fixed.
	if archetypeKey then
		fitBossMesh(tool, archetypeKey)
	end
	local mods, gotExtraSlot = WeaponModifiers.RollModifiers(weaponData.rarity, blessedBonus or 0,
		tool:GetAttribute("ExtraSlot") == true)
	if keepNames and #keepNames > 0 then
		local rolledCount = #mods
		local kept, keptCategories = {}, {}
		for _, keepName in ipairs(keepNames) do
			for category, data in pairs(WeaponModifiers.Categories) do
				for tierIndex, entry in ipairs(data.Tiers) do
					if entry.name == keepName and not keptCategories[category] then
						keptCategories[category] = true
						table.insert(kept, { category = category, name = entry.name, bonus = entry.bonus, desc = entry.desc, tier = tierIndex })
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
			mods[bestIndex] = { category = mods[bestIndex].category, name = tierData.name, bonus = tierData.bonus,
				desc = tierData.desc, tier = target }
			pityApplied = true
		end
	end
	local fullName = BossSwordFactory.applyRoll(tool, weaponData, archetypeKey, mods, gotExtraSlot)
	return mods, fullName, gotExtraSlot, pityApplied
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

	fitBossMesh(tool, BossWeapons.ArchetypeByTier[tonumber(attrs.BossTier)])

	local handle = tool:FindFirstChild("Handle")
	if handle then
		local weaponData = BossWeapons.GetByTier(attrs.BossTier)
		local color
		if typeof(data.color) == "table"
			and typeof(data.color[1]) == "number"
			and typeof(data.color[2]) == "number"
			and typeof(data.color[3]) == "number" then
			color = Color3.new(data.color[1], data.color[2], data.color[3])
		elseif weaponData then
			color = weaponData.color
		end

		-- New saves retain the requested appearance explicitly. Older saves stored the
		-- rendered material, which is Metal for textured Neon swords; the tier fallback
		-- restores their glow as well.
		local materialName = attrs.WeaponAppearanceMaterial
		local material = typeof(materialName) == "string" and Enum.Material[materialName] or nil
		if not material and weaponData then
			material = weaponData.material
		end
		if not material and typeof(data.material) == "string" then
			material = Enum.Material[data.material]
		end
		CombatUtil.applyWeaponAppearance(handle, color, material)
	end

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

	return tool
end

return BossSwordFactory
