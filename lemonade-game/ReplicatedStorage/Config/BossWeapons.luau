--// BossWeapons  (single source of truth for the five boss weapons)
-- Read by BossSwordFactory (boss drops + merchant purchases), SwordDropSystem (drop rates,
-- auto-sell tiers) and MerchantConfig (shop listings rendered by the client MerchantGui).
-- SwordDropSystem and MerchantSystem each used to carry a copy of this table, and
-- MerchantConfig a third copy of the stats.
local BossWeapons = {}

-- Boss tiers ordered by level (1 to 5)
BossWeapons.Tiers = {
	Boss_Gorgon = 1,           -- Iron Warlord (Lv 10)
	Boss_FrostRevenant = 2,    -- Frost Revenant (Lv 25)
	Boss_InfernalColossus = 3, -- Infernal Colossus (Lv 45)
	Boss_VoidWraith = 4,       -- Void Archon (Lv 70)
	Boss_CelestialTitan = 5,   -- Celestial Titan (Lv 100)
}

-- Stats and look of each boss's unique weapon, keyed by EnemyCombat archetype
BossWeapons.Weapons = {
	Boss_Gorgon = {
		name = "Warlord Greatsword",
		rarity = "Uncommon",
		baseMult = 2.20,
		color = Color3.fromRGB(180, 50, 50),
		material = Enum.Material.Metal,
		desc = "Heavy iron greatsword forged in warlord blood",
		inherentRange = 1.5,
		inherentKnockback = 25,
		inherentBonusDmg = 0.10,
	},
	Boss_FrostRevenant = {
		name = "Frostfang Cleaver",
		rarity = "Rare",
		baseMult = 3.80,
		color = Color3.fromRGB(100, 210, 255),
		material = Enum.Material.Ice,
		desc = "Chilled crystalline edge that cuts with glacial bite",
		inherentRange = 2.5,
		inherentCrit = 0.12,
		inherentBonusDmg = 0.20,
	},
	Boss_InfernalColossus = {
		name = "Inferno Edge",
		rarity = "Epic",
		baseMult = 6.50,
		color = Color3.fromRGB(255, 110, 20),
		material = Enum.Material.Neon,
		desc = "Blazing blade radiating volcanic heat",
		inherentBonusDmg = 0.35,
		inherentKnockback = 50,
		inherentCrit = 0.15,
	},
	Boss_VoidWraith = {
		name = "Voidrend Blade",
		rarity = "Epic",
		baseMult = 10.50,
		color = Color3.fromRGB(190, 80, 255),
		material = Enum.Material.Neon,
		desc = "Dimensional cleaver vibrating with abyss energy",
		inherentCrit = 0.25,
		inherentRange = 4.0,
		inherentBonusDmg = 0.50,
		inherentKnockback = 65,
	},
	Boss_CelestialTitan = {
		name = "Astral Eclipse",
		rarity = "Legendary",
		baseMult = 18.00,
		color = Color3.fromRGB(255, 230, 80),
		material = Enum.Material.Neon,
		desc = "Supreme celestial blade infused with stellar supernova power",
		inherentBonusDmg = 0.85,
		inherentCrit = 0.35,
		inherentRange = 6.0,
		inherentKnockback = 100,
	},
}

-- Used when an archetype has no entry above
BossWeapons.Fallback = {
	name = "Relic Sword",
	rarity = "Rare",
	baseMult = 2.00,
	color = Color3.fromRGB(180, 180, 200),
	material = Enum.Material.SmoothPlastic,
}

function BossWeapons.Get(archetypeKey)
	return BossWeapons.Weapons[archetypeKey] or BossWeapons.Fallback
end

function BossWeapons.GetTier(archetypeKey)
	return BossWeapons.Tiers[archetypeKey] or 1
end

return BossWeapons
