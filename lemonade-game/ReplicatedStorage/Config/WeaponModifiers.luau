local WeaponModifiers = {}

-- Base chance for a weapon of any rarity to drop with an extra modifier slot (Blessed)
WeaponModifiers.EXTRA_SLOT_CHANCE = 0.03 -- 3% base chance for blessed slot

-- Modifier definitions by category
WeaponModifiers.Categories = {
	Damage = {
		Name = "Damage",
		Tiers = {
			{ name = "Sharp", bonus = 0.10, desc = "+10% Damage" },
			{ name = "Brutal", bonus = 0.20, desc = "+20% Damage" },
			{ name = "Devastating", bonus = 0.35, desc = "+35% Damage" },
			{ name = "Godly", bonus = 0.50, desc = "+50% Damage" },
		},
	},
	CritChance = {
		Name = "CritChance",
		Tiers = {
			{ name = "Keen", bonus = 0.10, desc = "+10% Crit Chance" },
			{ name = "Deadly", bonus = 0.20, desc = "+20% Crit Chance" },
			{ name = "Precision", bonus = 0.30, desc = "+30% Crit Chance" },
			{ name = "Assassins", bonus = 0.45, desc = "+45% Crit Chance" },
		},
	},
	Range = {
		Name = "Range",
		Tiers = {
			{ name = "Extended", bonus = 2, desc = "+2 Studs Reach" },
			{ name = "Reaching", bonus = 4, desc = "+4 Studs Reach" },
			{ name = "Colossal", bonus = 6, desc = "+6 Studs Reach" },
			{ name = "Titan", bonus = 9, desc = "+9 Studs Reach" },
		},
	},
	Knockback = {
		Name = "Knockback",
		Tiers = {
			{ name = "Forceful", bonus = 25, desc = "+25 Knockback" },
			{ name = "Heavy", bonus = 50, desc = "+50 Knockback" },
			{ name = "Impactful", bonus = 80, desc = "+80 Knockback" },
			{ name = "Shattering", bonus = 120, desc = "+120 Knockback" },
		},
	},
}

-- Each rarity increases the base modifier slot by 1
WeaponModifiers.RarityConfig = {
	Common = {
		baseSlots = 0,
		maxTier = 1,
	},
	Uncommon = {
		baseSlots = 1,
		maxTier = 2,
	},
	Rare = {
		baseSlots = 2,
		maxTier = 3,
	},
	Epic = {
		baseSlots = 3,
		maxTier = 4,
	},
	Legendary = {
		baseSlots = 4,
		maxTier = 4,
	},
}

function WeaponModifiers.RollModifiers(rarityName, blessedChanceBonus)
	local cfg = WeaponModifiers.RarityConfig[rarityName] or WeaponModifiers.RarityConfig.Common
	local count = cfg.baseSlots
	local gotExtraSlot = false
	
	local blessedChance = WeaponModifiers.EXTRA_SLOT_CHANCE + (blessedChanceBonus or 0)
	if math.random() <= blessedChance then
		count += 1
		gotExtraSlot = true
	end

	-- Cap count at total available categories
	count = math.clamp(count, 0, 4)

	if count <= 0 then
		return {}, gotExtraSlot
	end

	-- Pick unique categories
	local catKeys = { "Damage", "CritChance", "Range", "Knockback" }
	-- Fisher-Yates shuffle
	for i = #catKeys, 2, -1 do
		local j = math.random(1, i)
		catKeys[i], catKeys[j] = catKeys[j], catKeys[i]
	end

	local rolled = {}
	for i = 1, count do
		local catKey = catKeys[i]
		local catData = WeaponModifiers.Categories[catKey]
		local availableTiers = math.min(cfg.maxTier, #catData.Tiers)
		local tierIdx = math.random(1, availableTiers)
		local tierData = catData.Tiers[tierIdx]

		table.insert(rolled, {
			category = catKey,
			name = tierData.name,
			bonus = tierData.bonus,
			desc = tierData.desc,
			tier = tierIdx,
		})
	end

	return rolled, gotExtraSlot
end

return WeaponModifiers
