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

-- [TUNING] Each modifier adds this fraction of the base, by its tier (1..6). A four-slot
-- Legendary with all tier-6 rolls is worth (1 + 4 * 1.8) = 8.2x the base.
SwordValue.TIER_WEIGHT = { 0.15, 0.30, 0.50, 0.80, 1.20, 1.80 }
SwordValue.BLESSED_BONUS = 0.25 -- extra slot rolled: +25% on top
SwordValue.BOSS_TIER_STEP = 0.10 -- later bosses' relics carry a little more prestige per tier

-- name -> { category, tier } for every modifier prefix
local TIER_BY_NAME = {}
for category, data in pairs(WeaponModifiers.Categories) do
	for tier, entry in ipairs(data.Tiers) do
		TIER_BY_NAME[entry.name] = { category = category, tier = tier }
	end
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

-- attrs: the sword's saved attribute table (Rarity, Prefixes, ExtraSlot, BossTier) — the same
-- keys a Tool carries as attributes, so SwordValue.rateTool wraps this.
function SwordValue.rateAttrs(attrs): number
	attrs = attrs or {}
	local base = SwordValue.RARITY_BASE[attrs.Rarity] or SwordValue.RARITY_BASE.Common
	local multiplier = 1
	for _, mod in ipairs(SwordValue.modifiersFromPrefixes(attrs.Prefixes)) do
		multiplier += SwordValue.TIER_WEIGHT[mod.tier] or 0
	end
	if attrs.ExtraSlot == true then
		multiplier += SwordValue.BLESSED_BONUS
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
		ExtraSlot = tool:GetAttribute("ExtraSlot"),
		BossTier = tool:GetAttribute("BossTier"),
	})
end

-- [TUNING] Reforge (reroll) price: a rarity base scaled by how good the current roll is,
-- so a plain Rare is cheap to gamble on and a near-perfect Legendary costs real gold.
SwordValue.REROLL_BASE = {
	Common = 40,
	Uncommon = 120,
	Rare = 400,
	Epic = 1500,
	Legendary = 6000,
}

function SwordValue.rerollCost(attrs): number
	attrs = attrs or {}
	local rarity = attrs.Rarity or "Common"
	local base = SwordValue.REROLL_BASE[rarity] or SwordValue.REROLL_BASE.Common
	local quality = SwordValue.rateAttrs(attrs) / (SwordValue.RARITY_BASE[rarity] or SwordValue.RARITY_BASE.Common)
	return math.floor(base * quality / 10 + 0.5) * 10
end

function SwordValue.rerollCostForTool(tool: Instance): number
	return SwordValue.rerollCost({
		Rarity = tool:GetAttribute("Rarity"),
		Prefixes = tool:GetAttribute("Prefixes"),
		ExtraSlot = tool:GetAttribute("ExtraSlot"),
		BossTier = tool:GetAttribute("BossTier"),
	})
end

-- Short label for HUD use: 1.2K, 34K, 2.1M
function SwordValue.short(value: number): string
	if value >= 1e6 then return string.format("%.1fM", value / 1e6) end
	if value >= 1e4 then return string.format("%.0fK", value / 1e3) end
	if value >= 1e3 then return string.format("%.1fK", value / 1e3) end
	return tostring(math.floor(value))
end

return SwordValue
