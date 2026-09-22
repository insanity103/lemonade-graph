-- ModuleScript | ReplicatedStorage.Config.SwordValue | The sword economy's unit of account.
-- A sword's rating comes from its rarity and the tiers of the modifiers rolled on it; a
-- player's Wealth is the sum of ratings across everything they carry and have stored with
-- the Vaultkeeper. Whoever holds the best-rolled relics is the richest.
local WeaponModifiers = require(script.Parent:WaitForChild("WeaponModifiers"))

local SwordValue = {}

-- [TUNING] Base worth by rarity. Each step is roughly 2.5x so a single Legendary outweighs a
-- bag of Rares, and modifiers decide the ordering within a rarity.
SwordValue.RARITY_BASE = {
	Common = 10,
	Uncommon = 25,
	Rare = 60,
	Epic = 150,
	Legendary = 400,
}

-- [TUNING] Each active prefix adds this fraction of the base, by its rung (1..10). Every sword
-- has one prefix slot (WeaponModifiers.BASE_SLOTS), so a Radiant (6) Legendary is worth 2.8x the
-- base and a Lemonade (10) one 8x. The removed Blessed slot adds nothing: an old save's ExtraSlot
-- flag is ignored here.
SwordValue.TIER_WEIGHT = { 0.15, 0.30, 0.50, 0.80, 1.20, 1.80, 2.60, 3.60, 5.00, 7.00 }
-- A mutation (Iced / Sugared / Sour) multiplies every modifier's bonus, so it adds this much.
SwordValue.VARIANT_BONUS = { Iced = 0.30, Sugared = 0.70, Sour = 1.50 }
SwordValue.BOSS_TIER_STEP = 0.10 -- later bosses' relics carry a little more prestige per tier

-- name -> { category, tier } for every modifier prefix
local TIER_BY_NAME = {}
for category, data in pairs(WeaponModifiers.Categories) do
	for tier, entry in ipairs(data.Tiers) do
		TIER_BY_NAME[entry.name] = { category = category, tier = tier }
	end
end
-- Each bracket's named chase (Lemondrop .. Lemonade) is a prefix outside the category lists,
-- rated at the highest ordinary rung its stat meets (WeaponModifiers.Chases valueTier).
for _, chase in ipairs(WeaponModifiers.Chases) do
	TIER_BY_NAME[chase.name] = { category = chase.category, tier = chase.valueTier or chase.tier }
end
SwordValue.TIER_BY_NAME = TIER_BY_NAME

-- Prefixes attribute is the comma-joined modifier names ("Reaching, Godly"); split it.
function SwordValue.modifiersFromPrefixes(prefixes: string?): { { name: string, category: string, tier: number } }
	local list = {}
	for word in string.gmatch(prefixes or "", "[^,%s]+") do
		local info = TIER_BY_NAME[word]
		if info then
			table.insert(list, { name = word, category = info.category, tier = info.tier })
		end
	end
	return list
end

-- attrs: the sword's saved attribute table (Rarity, Prefixes, Variant, BossTier) — the same
-- keys a Tool carries as attributes, so SwordValue.rateTool wraps this.
function SwordValue.rateAttrs(attrs): number
	attrs = attrs or {}
	local base = SwordValue.RARITY_BASE[attrs.Rarity] or SwordValue.RARITY_BASE.Common
	local multiplier = 1
	for _, mod in ipairs(SwordValue.modifiersFromPrefixes(attrs.Prefixes)) do
		multiplier += SwordValue.TIER_WEIGHT[mod.tier] or 0
	end
	if typeof(attrs.Variant) == "string" then
		multiplier += SwordValue.VARIANT_BONUS[attrs.Variant] or 0
	end
	local bossTier = tonumber(attrs.BossTier) or 1
	multiplier *= 1 + SwordValue.BOSS_TIER_STEP * (bossTier - 1)
	return math.floor(base * multiplier + 0.5)
end

function SwordValue.rateTool(tool: Instance): number
	if not tool:IsA("Tool") or tool:GetAttribute("BossDrop") ~= true then
		return 0
	end
	return SwordValue.rateAttrs({
		Rarity = tool:GetAttribute("Rarity"),
		Prefixes = tool:GetAttribute("Prefixes"),
		BossTier = tool:GetAttribute("BossTier"),
		Variant = tool:GetAttribute("Variant"),
	})
end

-- [TUNING] THE PRICE UNIT by rarity: what the shop's mystery blade and the sell price are quoted
-- against (MerchantConfig.StrikeRefForLevel, SellValue.StrikeReference), times the power factor
-- below. The values are the ones the removed forge strike used, so no shop or sell price moved
-- when the anvil went away. A Legendary's unit is about 7x a Common's OF THE SAME TIER.
SwordValue.PRICE_UNIT = {
	Common = 60,
	Uncommon = 105,
	Rare = 170,
	Epic = 260,
	Legendary = 400,
}

-- [TUNING] THE POWER FACTOR -- the thing that makes every sword price a CURVE instead of a flat fee.
--
-- Rarity and roll quality say how good a sword is FOR ITS TIER; they say nothing about which tier
-- it is. A Common out of the Celestial Summit pool and a Common out of the Iron Lowlands pool used
-- to strike for the same 40 gold, which is why the strike price sat at 40-190 gold on the sword
-- actually carried in six zones of eight and an hour of play bought hundreds of strikes.
--
-- A sword's rolled base damage multiplier (the DamageMult attribute BossSwordFactory stamps) IS
-- its tier: the lesser pools run x0.90-1.95 in the Iron Lowlands up to x9.90-15.80 on the
-- Celestial Summit, and the boss pools x1.30-2.20 up to x5.80-18.00. Pricing the strike on that
-- makes the sink climb with the zone the player is standing in, at the same time as the income
-- from that zone climbs -- so a stretch of farming buys roughly the same bounded number of
-- strikes at every tier, from the first zone to the last, rather than going trivially cheap the
-- moment the player leaves the opening zone.
--
-- powerFactor(base) = (base / POWER_REF) ^ POWER_EXP. Fitted so that an hour of the zone you are
-- in buys 10-25 strikes on the median sword that zone drops, at every one of the eight zones.
SwordValue.POWER_REF = 0.40
SwordValue.POWER_EXP = 2.0
SwordValue.POWER_MIN_BASE = 0.40 -- a base below this prices as this (no free strikes on oddities)
SwordValue.POWER_MAX_FACTOR = 5000 -- guard rail: nothing prices past this, whatever it claims

-- attrs.BaseMult is the sword's rolled DamageMult. A sword whose base is unknown (an older save,
-- a hand-made tool) prices at x1.00 base, which is the opening zone's own tier.
function SwordValue.powerFactor(baseMult: number?): number
	local base = tonumber(baseMult) or 1
	base = math.max(base, SwordValue.POWER_MIN_BASE)
	local factor = (base / SwordValue.POWER_REF) ^ SwordValue.POWER_EXP
	return math.clamp(factor, 0, SwordValue.POWER_MAX_FACTOR)
end

-- The attribute table this module prices, read off a live Tool. One place, so the server, the
-- panels and any measurement harness all price the same sword the same way.
function SwordValue.attrsOfTool(tool: Instance)
	return {
		Rarity = tool:GetAttribute("Rarity"),
		Prefixes = tool:GetAttribute("Prefixes"),
		BossTier = tool:GetAttribute("BossTier"),
		Variant = tool:GetAttribute("Variant"),
		BaseMult = tool:GetAttribute("DamageMult"),
		Starter = tool:GetAttribute("Starter"),
	}
end

-- Short label for HUD use: 1.2K, 34K, 2.1M
function SwordValue.short(value: number): string
	if value >= 1e6 then return string.format("%.1fM", value / 1e6) end
	if value >= 1e4 then return string.format("%.0fK", value / 1e3) end
	if value >= 1e3 then return string.format("%.1fK", value / 1e3) end
	return tostring(math.floor(value))
end

return SwordValue
