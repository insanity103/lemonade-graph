local BossWeapons = require(script.Parent:WaitForChild("BossWeapons"))

local MerchantConfig = {}

-- 5 Boss sword listings available from the Mystic Blacksmith NPC: one regular sword of each
-- boss's pool, sold as its Rare variant at the listed base (no stat jitter, never Blessed).
-- Legendaries are boss-only. Only merchant-specific fields live here; name, rarity, baseMult,
-- colour and the inherent bonuses are filled in from BossWeapons so the shop always shows the
-- stats the sword will actually have.
local LISTINGS = {
	{ id = "Boss_Gorgon", sword = "Warlord Greatsword", rarity = "Rare", price = 500,
		desc = "Heavy iron greatsword. High physical reach and baseline power." },
	{ id = "Boss_FrostRevenant", sword = "Frostfang Cleaver", rarity = "Rare", price = 2000,
		desc = "Chilled crystalline edge. Built-in crit and frost damage bonus." },
	{ id = "Boss_InfernalColossus", sword = "Inferno Edge", rarity = "Rare", price = 8000,
		desc = "Blazing volcanic cleaver with explosive knockback and crit chance." },
	{ id = "Boss_VoidWraith", sword = "Voidrend Blade", rarity = "Rare", price = 25000,
		desc = "Abyssal relic vibrating with dimensional cleave power." },
	{ id = "Boss_CelestialTitan", sword = "Titanforged Greatsword", rarity = "Rare", price = 100000,
		desc = "Greatsword hammered on the Titan's own anvil. The Titan's Legendary drops only from the Titan." },
}

local STAT_FIELDS = { "name", "rarity", "baseMult", "color", "material",
	"inherentRange", "inherentKnockback", "inherentBonusDmg", "inherentCrit" }

MerchantConfig.Items = {}
for _, listing in ipairs(LISTINGS) do
	local item = { id = listing.id, sword = listing.sword, price = listing.price, desc = listing.desc }
	local weapon = BossWeapons.Resolve(listing.id, listing.sword, listing.rarity)
	if weapon then
		for _, field in ipairs(STAT_FIELDS) do
			item[field] = weapon[field]
		end
	end
	table.insert(MerchantConfig.Items, item)
end

function MerchantConfig.GetItem(id)
	for _, item in ipairs(MerchantConfig.Items) do
		if item.id == id then
			return item
		end
	end
	return nil
end

return MerchantConfig
