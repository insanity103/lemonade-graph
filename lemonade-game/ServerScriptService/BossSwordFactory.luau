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

	-- Roll modifiers by rarity. A bonus of -1 pushes the Blessed chance below zero,
	-- which is how purchases guarantee no extra slot.
	local mods, gotExtraSlot = WeaponModifiers.RollModifiers(weaponData.rarity,
		allowBlessed and (opts.blessedBonus or 0) or -1.0)
	if not allowBlessed then
		gotExtraSlot = false
	end

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
