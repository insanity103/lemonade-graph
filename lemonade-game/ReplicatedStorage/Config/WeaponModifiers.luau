local WeaponModifiers = {}

-- Base chance for a weapon of any rarity to drop with an extra modifier slot (Blessed)
WeaponModifiers.EXTRA_SLOT_CHANCE = 0.03 -- 3% base chance for blessed slot

-- Modifier definitions by category: six tiers each, from a small nudge to a build-defining bonus.
WeaponModifiers.Categories = {
	Damage = {
		Name = "Damage",
		Tiers = {
			{ name = "Sharp", bonus = 0.08, desc = "+8% Damage" },
			{ name = "Honed", bonus = 0.15, desc = "+15% Damage" },
			{ name = "Brutal", bonus = 0.25, desc = "+25% Damage" },
			{ name = "Devastating", bonus = 0.35, desc = "+35% Damage" },
			{ name = "Godly", bonus = 0.50, desc = "+50% Damage" },
			{ name = "Mythic", bonus = 0.70, desc = "+70% Damage" },
		},
	},
	CritChance = {
		Name = "CritChance",
		Tiers = {
			{ name = "Keen", bonus = 0.08, desc = "+8% Crit Chance" },
			{ name = "Sly", bonus = 0.15, desc = "+15% Crit Chance" },
			{ name = "Deadly", bonus = 0.22, desc = "+22% Crit Chance" },
			{ name = "Precision", bonus = 0.30, desc = "+30% Crit Chance" },
			{ name = "Assassins", bonus = 0.40, desc = "+40% Crit Chance" },
			{ name = "Executioners", bonus = 0.55, desc = "+55% Crit Chance" },
		},
	},
	Range = {
		Name = "Range",
		Tiers = {
			{ name = "Extended", bonus = 1.5, desc = "+1.5 Studs Reach" },
			{ name = "Reaching", bonus = 3, desc = "+3 Studs Reach" },
			{ name = "Long", bonus = 4.5, desc = "+4.5 Studs Reach" },
			{ name = "Colossal", bonus = 6, desc = "+6 Studs Reach" },
			{ name = "Titan", bonus = 8, desc = "+8 Studs Reach" },
			{ name = "Horizon", bonus = 11, desc = "+11 Studs Reach" },
		},
	},
	Knockback = {
		Name = "Knockback",
		Tiers = {
			{ name = "Forceful", bonus = 20, desc = "+20 Knockback" },
			{ name = "Heavy", bonus = 40, desc = "+40 Knockback" },
			{ name = "Impactful", bonus = 65, desc = "+65 Knockback" },
			{ name = "Shattering", bonus = 90, desc = "+90 Knockback" },
			{ name = "Quaking", bonus = 130, desc = "+130 Knockback" },
			{ name = "Cataclysmic", bonus = 180, desc = "+180 Knockback" },
		},
	},
}

-- Rarity decides how many modifier slots a sword gets and where the odds peak on the tier
-- ladder. No tier is ever locked out: any sword can roll any tier of any category, higher
-- rarities are simply far more likely to land the top ones (see WeaponModifiers.TierOdds).
WeaponModifiers.RarityConfig = {
	Common    = { baseSlots = 0, bonusSlotChance = 0.20, peakTier = 1 },
	Uncommon  = { baseSlots = 1, bonusSlotChance = 0.15, peakTier = 1.5 },
	Rare      = { baseSlots = 2, bonusSlotChance = 0.10, peakTier = 2.5 },
	Epic      = { baseSlots = 3, bonusSlotChance = 0.05, peakTier = 4 },
	Legendary = { baseSlots = 4, bonusSlotChance = 0, peakTier = 5 },
}
-- bonusSlotChance: an ordinary extra slot (not Blessed) so even Common swords can carry a
-- modifier now and then. Blessed is on top of that and rolls its slot one tier higher.

-- Each tier away from the rarity's peak is this much less likely than the one before it.
WeaponModifiers.TIER_FALLOFF = 0.45 -- [TUNING]
WeaponModifiers.TIER_COUNT = 6

-- Probability of each tier for a rarity (peak shift lets Blessed slots roll higher).
function WeaponModifiers.TierOdds(rarityName, peakShift)
	local cfg = WeaponModifiers.RarityConfig[rarityName] or WeaponModifiers.RarityConfig.Common
	local peak = math.min(cfg.peakTier + (peakShift or 0), WeaponModifiers.TIER_COUNT)
	local weights, total = {}, 0
	for tier = 1, WeaponModifiers.TIER_COUNT do
		local w = WeaponModifiers.TIER_FALLOFF ^ math.abs(tier - peak)
		weights[tier] = w
		total += w
	end
	for tier = 1, WeaponModifiers.TIER_COUNT do
		weights[tier] /= total
	end
	return weights
end

local function rollTier(rarityName, peakShift)
	local odds = WeaponModifiers.TierOdds(rarityName, peakShift)
	local pick = math.random()
	for tier = 1, WeaponModifiers.TIER_COUNT do
		pick -= odds[tier]
		if pick <= 0 then return tier end
	end
	return WeaponModifiers.TIER_COUNT
end

function WeaponModifiers.RollModifiers(rarityName, blessedChanceBonus)
	local cfg = WeaponModifiers.RarityConfig[rarityName] or WeaponModifiers.RarityConfig.Common
	local count = cfg.baseSlots
	if math.random() < (cfg.bonusSlotChance or 0) then
		count += 1
	end
	local gotExtraSlot = false

	local bonus = typeof(blessedChanceBonus) == "number" and blessedChanceBonus or 0
	local blessedChance = math.clamp(WeaponModifiers.EXTRA_SLOT_CHANCE + bonus, 0, 1)
	if math.random() < blessedChance then
		count += 1
		gotExtraSlot = true
	end

	-- Cap count at total available categories (one modifier per category)
	count = math.clamp(count, 0, 4)

	if count <= 0 then
		return {}, gotExtraSlot
	end

	-- Any combination of categories: shuffle and take the first `count`
	local catKeys = { "Damage", "CritChance", "Range", "Knockback" }
	for i = #catKeys, 2, -1 do
		local j = math.random(1, i)
		catKeys[i], catKeys[j] = catKeys[j], catKeys[i]
	end

	local rolled = {}
	for i = 1, count do
		local catKey = catKeys[i]
		local catData = WeaponModifiers.Categories[catKey]
		-- The Blessed slot (last one rolled) peaks one tier higher so it feels special.
		local tierIdx = math.min(rollTier(rarityName, (gotExtraSlot and i == count) and 1 or 0), #catData.Tiers)
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
