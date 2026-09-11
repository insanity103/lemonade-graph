local RebirthConfig = {}

RebirthConfig.BASE_LEVEL = 20
RebirthConfig.LEVEL_PER_REBIRTH = 15

-- Multipliers per rebirth (additive stacking)
RebirthConfig.XP_BOOST_PER_REBIRTH = 0.35      -- +35% XP Gain per rebirth
RebirthConfig.GOLD_BOOST_PER_REBIRTH = 0.50    -- +50% Gold Gain per rebirth
RebirthConfig.DAMAGE_BOOST_PER_REBIRTH = 0.25  -- +25% Global Sword Damage per rebirth
RebirthConfig.HEALTH_BOOST_PER_REBIRTH = 0.15  -- +15% Base Health per rebirth
RebirthConfig.BONUS_SKILL_POINTS_PER_REBIRTH = 5 -- +5 starting bonus skill points immediately on rebirth

-- Weapon drop rate scaling per rebirth
-- Boosts base drop chances slightly per rebirth tier (e.g. +1% to +2% flat or scaling boost)
RebirthConfig.DROP_RATE_BONUS_PER_REBIRTH = {
	Legendary = 0.010, -- +1.0% flat drop rate per rebirth (e.g. 5% -> 6% at RB1, 10% at RB5)
	Epic      = 0.015, -- +1.5% flat drop rate per rebirth (e.g. 10% -> 11.5% at RB1, 17.5% at RB5)
	Rare      = 0.025, -- +2.5% flat drop rate per rebirth (e.g. 40% -> 42.5% at RB1, 52.5% at RB5)
	Uncommon  = 0.030, -- +3.0% flat drop rate per rebirth (e.g. 60% -> 63% at RB1, 75% at RB5)
	Common    = 0.030, -- +3.0% flat drop rate per rebirth (e.g. 80% -> 83% at RB1, 95% at RB5)
}

-- Rebirth 5+ Blessed Drop Bonus
RebirthConfig.REBIRTH_5_BLESSED_BONUS = 0.05 -- +5% Blessed weapon drop chance at Rebirth 5+ (3% base -> 8% total)

-- Milestone Special Perks
RebirthConfig.Milestones = {
	[1] = {
		title = "Ascendant Strike",
		desc = "+50% Knockback, +5 Starting Skill Points, +Rarity Drop Rates",
		knockbackBonus = 50,
	},
	[2] = {
		title = "Glacial Endurance",
		desc = "+100 Max Base Health",
		flatHealthBonus = 100,
	},
	[3] = {
		title = "Infernal Precision",
		desc = "+10% Permanent Critical Strike Chance",
		flatCritBonus = 0.10,
	},
	[4] = {
		title = "Void Cleave",
		desc = "+3 Studs Extended Reach on all swords",
		flatRangeBonus = 3.0,
	},
	[5] = {
		title = "Astral Supernova",
		desc = "+100% Critical Damage, +10 Starting Skill Points, +5% Blessed Weapon Chance",
		critDamageMultiplier = 2.0,
		blessedBonus = 0.05,
	},
}

function RebirthConfig.GetRequiredLevel(rebirths)
	return RebirthConfig.BASE_LEVEL + RebirthConfig.LEVEL_PER_REBIRTH * (rebirths or 0)
end

function RebirthConfig.GetMultipliers(rebirths)
	rebirths = rebirths or 0
	local blessedBonus = 0
	if rebirths >= 5 then
		blessedBonus = RebirthConfig.REBIRTH_5_BLESSED_BONUS
	end

	return {
		xpMult = 1 + (RebirthConfig.XP_BOOST_PER_REBIRTH * rebirths),
		goldMult = 1 + (RebirthConfig.GOLD_BOOST_PER_REBIRTH * rebirths),
		damageMult = 1 + (RebirthConfig.DAMAGE_BOOST_PER_REBIRTH * rebirths),
		healthMult = 1 + (RebirthConfig.HEALTH_BOOST_PER_REBIRTH * rebirths),
		bonusSkillPoints = RebirthConfig.BONUS_SKILL_POINTS_PER_REBIRTH * rebirths,
		blessedBonus = blessedBonus,
	}
end

function RebirthConfig.GetEffectiveDropChance(baseChance, rarity, rebirths)
	rebirths = rebirths or 0
	local perRebirthBonus = RebirthConfig.DROP_RATE_BONUS_PER_REBIRTH[rarity] or 0.01
	local totalChance = baseChance + (perRebirthBonus * rebirths)
	return math.clamp(totalChance, 0, 1.0)
end

return RebirthConfig
