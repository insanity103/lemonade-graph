--// BossWeapons  (single source of truth for the boss sword roster: five pools, 35 swords)
-- Read by BossSwordFactory (every drop, purchase, admin gift, vault / trade rebuild and reforge),
-- SwordDropSystem (per-boss drop chance, auto-sell values), MerchantConfig (shop listings) and the
-- Studio-only SwordGalleryStage.
--
-- Structure (the Dungeon Quest shape: one pool per boss, every sword at four rarities, one
-- showpiece Legendary above the rest):
--   * Each boss owns a POOL of 6 regular swords plus 1 Legendary. A regular sword drops at
--     Common / Uncommon / Rare / Epic; its base damage multiplier is `base` x RarityStep
--     (x1.00 / 1.05 / 1.10 / 1.15). The Legendary drops only as Legendary, ~17% above the
--     pool's best Epic, and carries the boss's full inherent bonus set.
--   * A drop rolls: rarity (RarityOdds, one table, sums to 1) -> if Legendary the showpiece,
--     otherwise which regular sword (`weight`, the cheaper swords are the common ones) -> the
--     base stat jitter (STAT_JITTER, +-5%). All three rolls live in BossSwordFactory.rollDrop.
--   * Between pools the floors step ~45% (x1.30 -> 1.90 -> 2.75 -> 4.00 -> 5.80) and the pool
--     widens with the boss level, so the Legendary tops sit exactly where the old single swords
--     did (x2.20 / 3.80 / 6.50 / 10.50 / 18.00): top DPS at each boss level is unchanged.
--   * Look: every sword names a mesh (a forged archetype mesh, the shared template mesh, or the
--     block-built starter sword restyled), a colour, a material, an accent and a held length, so
--     35 swords read as 35 different objects from the three meshes the place holds today. A sword
--     whose mesh is not imported yet falls back (archetype mesh -> template mesh -> blocks) and is
--     never invisible.
local BossWeapons = {}

BossWeapons.Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- Base multiplier step per rarity for a regular pool sword. [TUNING]
BossWeapons.RarityStep = { Common = 1.00, Uncommon = 1.05, Rare = 1.10, Epic = 1.15 }

-- What rarity a boss drop lands at (one roll, sums to 1). Legendary picks the pool's showpiece.
-- These are the odds the drop toast prints, so keep them the real ones. [TUNING]
BossWeapons.RarityOdds = {
	{ rarity = "Common", p = 0.535 },
	{ rarity = "Uncommon", p = 0.300 },
	{ rarity = "Rare", p = 0.120 },
	{ rarity = "Epic", p = 0.030 },
	{ rarity = "Legendary", p = 0.015 },
}

-- Every drop rolls its base stat in this band around the listed value (x0.95 - x1.05). [TUNING]
BossWeapons.STAT_JITTER = 0.05

-- Chance the boss drops anything at all per kill (unchanged from the single-sword roster), and the
-- rarity class RebirthConfig.DROP_RATE_BONUS_PER_REBIRTH scales it with. [TUNING]
BossWeapons.DropChance = {
	Boss_Gorgon = { chance = 0.60, rebirthClass = "Uncommon" },
	Boss_FrostRevenant = { chance = 0.40, rebirthClass = "Rare" },
	Boss_InfernalColossus = { chance = 0.10, rebirthClass = "Epic" },
	Boss_VoidWraith = { chance = 0.10, rebirthClass = "Epic" },
	Boss_CelestialTitan = { chance = 0.05, rebirthClass = "Legendary" },
}

-- Boss tiers ordered by level (1 to 5)
BossWeapons.Tiers = {
	Boss_Gorgon = 1,           -- Warden of the Pit (Lv 10)
	Boss_FrostRevenant = 2,    -- Frost Revenant (Lv 25)
	Boss_InfernalColossus = 3, -- Infernal Colossus (Lv 45)
	Boss_VoidWraith = 4,       -- Void Archon (Lv 70)
	Boss_CelestialTitan = 5,   -- Celestial Titan (Lv 100)
}

BossWeapons.ArchetypeByTier = {
	[1] = "Boss_Gorgon",
	[2] = "Boss_FrostRevenant",
	[3] = "Boss_InfernalColossus",
	[4] = "Boss_VoidWraith",
	[5] = "Boss_CelestialTitan",
}

BossWeapons.BossNames = {
	Boss_Gorgon = "Warden of the Pit",
	Boss_FrostRevenant = "Frost Revenant",
	Boss_InfernalColossus = "Infernal Colossus",
	Boss_VoidWraith = "Void Archon",
	Boss_CelestialTitan = "Celestial Titan",
}

local Metal, Neon, Glass, Ice, Slate, Basalt = Enum.Material.Metal, Enum.Material.Neon, Enum.Material.Glass,
	Enum.Material.Ice, Enum.Material.Slate, Enum.Material.Basalt
local rgb = Color3.fromRGB

-- look.mesh: "Boss_Gorgon" .. "Boss_CelestialTitan" (ServerStorage/BossSwordMeshes/<name>, forged by
-- tools/sword_forge.py), "Template" (ServerStorage/SwordMeshTemplate) or "Blocks" (the starter
-- sword's block parts, restyled: blade/guard/width/length below). Missing meshes fall back down
-- that list. length = held length in studs; blade/width/guard scale the block sword's parts.
-- textured = false strips the mesh's painted texture so the sword's own colour and material show
-- (a textured MeshPart ignores Color): the recoloured variants of a silhouette; the five signature
-- swords and the Legendaries keep their painted textures.
local function sword(name, base, weight, look, inherent, desc)
	local def = { name = name, base = base, weight = weight, look = look, desc = desc }
	for k, v in pairs(inherent or {}) do def[k] = v end
	return def
end

-- inherentBonusDmg is a pool-wide flavour (every sword of a boss shares it) so the base ladder
-- above is the whole damage ladder; per-sword inherents vary reach / crit / knockback only.
BossWeapons.Pools = {
	Boss_Gorgon = {
		inherentBonusDmg = 0.10,
		swords = {
			sword("Pit Shiv", 1.30, 30, { mesh = "Blocks", color = rgb(125, 115, 105), material = Metal, accent = rgb(140, 72, 40), length = 3.4, blade = 0.75, width = 0.8, guard = 0.8 },
				{ inherentRange = 0.5 }, "A prisoner's blade ground from a pit shackle"),
			sword("Ironjaw Saber", 1.36, 24, { mesh = "Template", textured = false, color = rgb(150, 150, 160), material = Metal, length = 4.0 },
				{ inherentKnockback = 10 }, "Curved iron saber notched like a jaw"),
			sword("Slag Falchion", 1.43, 18, { mesh = "Blocks", color = rgb(72, 62, 56), material = Slate, accent = rgb(205, 95, 40), length = 3.9, blade = 1.0, width = 1.5, guard = 1.1 },
				{ inherentKnockback = 20 }, "Wide slag-forged chopper still warm from the furnace"),
			sword("Chainbreaker", 1.49, 13, { mesh = "Boss_Gorgon", textured = false, color = rgb(112, 118, 128), material = Metal, length = 4.2 },
				{ inherentKnockback = 25, inherentRange = 1.0 }, "Dull iron greatsword that splits chain and cage bar alike"),
			sword("Warlord Greatsword", 1.56, 9, { mesh = "Boss_Gorgon", color = rgb(180, 50, 50), material = Metal, length = 4.2 },
				{ inherentRange = 1.5, inherentKnockback = 25 }, "Heavy iron greatsword forged in warlord blood"),
			sword("Duneglass Edge", 1.64, 6, { mesh = "Template", textured = false, color = rgb(235, 190, 90), material = Glass, length = 4.1 },
				{ inherentCrit = 0.06, inherentRange = 1.0 }, "Amber desert glass honed to a sun-bright edge"),
		},
		legendary = sword("Pit Sovereign", 2.20, 0, { mesh = "Boss_Gorgon", color = rgb(255, 92, 40), material = Neon, length = 4.8 },
			{ inherentRange = 1.5, inherentKnockback = 25, inherentCrit = 0.05 }, "The Warden's own ember-lit greatsword, king of the pit"),
	},
	Boss_FrostRevenant = {
		inherentBonusDmg = 0.20,
		swords = {
			sword("Rimeguard Shortsword", 1.90, 30, { mesh = "Blocks", color = rgb(205, 232, 255), material = Ice, accent = rgb(120, 160, 200), length = 3.4, blade = 0.75, width = 0.9, guard = 0.9 },
				{ inherentRange = 0.5 }, "Short frost-rimed guard's blade"),
			sword("Glacier Falchion", 2.06, 24, { mesh = "Template", textured = false, color = rgb(140, 200, 240), material = Glass, length = 4.0 },
				{ inherentCrit = 0.05 }, "Curved falchion cut from a glacier's clear heart"),
			sword("Snowdrift Saber", 2.23, 18, { mesh = "Blocks", color = rgb(245, 250, 255), material = Enum.Material.Snow, accent = rgb(100, 140, 190), length = 3.8, blade = 1.0, width = 1.2, guard = 1.0 },
				{ inherentRange = 1.0, inherentKnockback = 10 }, "Packed-snow saber that never melts"),
			sword("Frostfang Cleaver", 2.41, 13, { mesh = "Boss_FrostRevenant", color = rgb(100, 210, 255), material = Ice, length = 4.2 },
				{ inherentRange = 2.5, inherentCrit = 0.12 }, "Chilled crystalline edge that cuts with glacial bite"),
			sword("Hoarwind Claymore", 2.61, 9, { mesh = "Boss_Gorgon", textured = false, color = rgb(180, 220, 240), material = Ice, length = 4.4 },
				{ inherentRange = 2.0, inherentKnockback = 20 }, "Long claymore that hums with the hoar wind"),
			sword("Permafrost Greatsword", 2.82, 6, { mesh = "Boss_Gorgon", textured = false, color = rgb(90, 150, 220), material = Metal, length = 4.6 },
				{ inherentRange = 2.5, inherentKnockback = 30 }, "Greatsword quenched in ground that has never thawed"),
		},
		legendary = sword("Aurora Greatblade", 3.80, 0, { mesh = "Boss_Gorgon", color = rgb(140, 240, 255), material = Neon, length = 4.8 },
			{ inherentRange = 2.5, inherentCrit = 0.12, inherentKnockback = 20 }, "The Revenant's greatblade, lit from within by the northern lights"),
	},
	Boss_InfernalColossus = {
		inherentBonusDmg = 0.35,
		swords = {
			sword("Cinder Shortsword", 2.75, 30, { mesh = "Blocks", color = rgb(62, 52, 50), material = Basalt, accent = rgb(255, 120, 40), length = 3.4, blade = 0.75, width = 0.9, guard = 0.9 },
				{ inherentKnockback = 15 }, "Stubby blade still smouldering at the edge"),
			sword("Magma Falchion", 3.08, 24, { mesh = "Template", textured = false, color = rgb(230, 100, 30), material = Metal, length = 4.0 },
				{ inherentCrit = 0.05, inherentKnockback = 15 }, "Falchion cast straight from the caldera's magma"),
			sword("Ashen Saber", 3.45, 18, { mesh = "Blocks", color = rgb(132, 122, 122), material = Slate, accent = rgb(255, 90, 30), length = 3.8, blade = 1.0, width = 1.2, guard = 1.0 },
				{ inherentCrit = 0.08 }, "Grey ash-steel saber with a glowing fuller"),
			sword("Inferno Edge", 3.86, 13, { mesh = "Boss_InfernalColossus", color = rgb(255, 110, 20), material = Neon, length = 4.2 },
				{ inherentKnockback = 50, inherentCrit = 0.15 }, "Blazing blade radiating volcanic heat"),
			sword("Basalt Claymore", 4.32, 9, { mesh = "Boss_Gorgon", textured = false, color = rgb(52, 46, 46), material = Basalt, length = 4.4 },
				{ inherentKnockback = 40, inherentRange = 1.0 }, "Black basalt claymore, heavy as the mountain"),
			sword("Pyroclast Greatsword", 4.83, 6, { mesh = "Boss_Gorgon", textured = false, color = rgb(255, 80, 30), material = Enum.Material.CrackedLava, length = 4.6 },
				{ inherentKnockback = 50, inherentRange = 1.5 }, "Greatsword of cooling lava, cracks still glowing"),
		},
		legendary = sword("Colossus Heart", 6.50, 0, { mesh = "Boss_Gorgon", color = rgb(255, 170, 40), material = Neon, length = 4.9 },
			{ inherentKnockback = 50, inherentCrit = 0.15, inherentRange = 1.0 }, "The Colossus's molten heart, hammered into a greatsword"),
	},
	Boss_VoidWraith = {
		inherentBonusDmg = 0.50,
		swords = {
			sword("Rift Dagger", 4.00, 30, { mesh = "Blocks", color = rgb(92, 62, 142), material = Metal, accent = rgb(200, 80, 255), length = 3.3, blade = 0.7, width = 0.8, guard = 0.8 },
				{ inherentCrit = 0.10 }, "Slim dagger that slips between moments"),
			sword("Umbral Falchion", 4.57, 24, { mesh = "Template", textured = false, color = rgb(62, 42, 92), material = Slate, length = 4.0 },
				{ inherentCrit = 0.10, inherentRange = 1.0 }, "Falchion of pressed shadow"),
			sword("Nether Saber", 5.23, 18, { mesh = "Blocks", color = rgb(42, 32, 62), material = Enum.Material.Foil, accent = rgb(190, 80, 255), length = 3.8, blade = 1.0, width = 1.2, guard = 1.0 },
				{ inherentCrit = 0.12, inherentKnockback = 20 }, "Saber that drinks the light around it"),
			sword("Voidrend Blade", 5.97, 13, { mesh = "Boss_VoidWraith", color = rgb(190, 80, 255), material = Neon, length = 4.2 },
				{ inherentCrit = 0.25, inherentRange = 4.0, inherentKnockback = 65 }, "Dimensional cleaver vibrating with abyss energy"),
			sword("Eventide Claymore", 6.83, 9, { mesh = "Boss_Gorgon", textured = false, color = rgb(120, 60, 200), material = Metal, length = 4.4 },
				{ inherentCrit = 0.15, inherentRange = 2.0, inherentKnockback = 30 }, "Claymore the colour of the last light before the rift"),
			sword("Singularity Greatsword", 7.80, 6, { mesh = "Boss_Gorgon", textured = false, color = rgb(30, 20, 45), material = Glass, length = 4.6 },
				{ inherentCrit = 0.15, inherentRange = 3.0, inherentKnockback = 50 }, "Greatsword with a pinpoint of collapsed void at its heart"),
		},
		legendary = sword("Archon's Verdict", 10.50, 0, { mesh = "Boss_Gorgon", color = rgb(220, 120, 255), material = Neon, length = 4.9 },
			{ inherentCrit = 0.25, inherentRange = 4.0, inherentKnockback = 65 }, "The Archon's sentence, passed in a single stroke"),
	},
	Boss_CelestialTitan = {
		inherentBonusDmg = 0.85,
		swords = {
			sword("Starlight Shortsword", 5.80, 30, { mesh = "Blocks", color = rgb(240, 240, 255), material = Metal, accent = rgb(255, 215, 90), length = 3.4, blade = 0.75, width = 0.9, guard = 0.9 },
				{ inherentCrit = 0.10, inherentRange = 1.0 }, "Short blade that carries a little starlight"),
			sword("Comet Falchion", 6.86, 24, { mesh = "Template", textured = false, color = rgb(200, 225, 255), material = Glass, length = 4.0 },
				{ inherentCrit = 0.15, inherentRange = 2.0 }, "Falchion with a comet's tail along the edge"),
			sword("Halo Saber", 8.10, 18, { mesh = "Blocks", color = rgb(255, 230, 150), material = Metal, accent = rgb(255, 255, 255), length = 3.9, blade = 1.0, width = 1.2, guard = 1.1 },
				{ inherentCrit = 0.20, inherentKnockback = 30 }, "Saber ringed with a soft halo"),
			sword("Meridian Blade", 9.58, 13, { mesh = "Boss_CelestialTitan", textured = false, color = rgb(255, 215, 80), material = Metal, length = 4.2 },
				{ inherentCrit = 0.20, inherentRange = 3.0, inherentKnockback = 40 }, "Blade aligned to the sky's meridian"),
			sword("Sunspire Claymore", 11.32, 9, { mesh = "Boss_Gorgon", textured = false, color = rgb(255, 200, 60), material = Metal, length = 4.5 },
				{ inherentCrit = 0.25, inherentRange = 4.0, inherentKnockback = 60 }, "Claymore as tall and bright as the Summit's spire"),
			sword("Titanforged Greatsword", 13.38, 6, { mesh = "Boss_Gorgon", textured = false, color = rgb(220, 225, 240), material = Metal, length = 4.7 },
				{ inherentCrit = 0.25, inherentRange = 5.0, inherentKnockback = 80 }, "Greatsword hammered on the Titan's own anvil"),
		},
		legendary = sword("Astral Eclipse", 18.00, 0, { mesh = "Boss_Gorgon", color = rgb(255, 230, 80), material = Neon, length = 5.0 },
			{ inherentCrit = 0.35, inherentRange = 6.0, inherentKnockback = 100 }, "Supreme celestial blade infused with stellar supernova power"),
	},
}

-- Used when an archetype has no pool
BossWeapons.Fallback = {
	name = "Relic Sword",
	rarity = "Rare",
	baseMult = 2.00,
	color = rgb(180, 180, 200),
	material = Enum.Material.SmoothPlastic,
	look = { mesh = "Template", color = rgb(180, 180, 200), material = Enum.Material.SmoothPlastic, length = 4.2 },
}

-- ---------------------------------------------------------------- lookups
-- The sword definition (regular or Legendary) named `name` in `archetypeKey`'s pool, or, with no
-- archetype, the first pool that has it. Returns def, archetypeKey, isLegendary.
function BossWeapons.FindSword(name, archetypeKey)
	local keys = archetypeKey and { archetypeKey } or BossWeapons.ArchetypeByTier
	for _, key in ipairs(keys) do
		local pool = BossWeapons.Pools[key]
		if pool then
			if pool.legendary.name == name then
				return pool.legendary, key, true
			end
			for _, def in ipairs(pool.swords) do
				if def.name == name then
					return def, key, false
				end
			end
		end
	end
	return nil
end

-- Base damage multiplier of `def` at `rarity` (before the drop's jitter).
function BossWeapons.BaseAt(def, rarity, isLegendary)
	if isLegendary then
		return def.base
	end
	return math.floor(def.base * (BossWeapons.RarityStep[rarity] or 1) * 100 + 0.5) / 100
end

-- A concrete sword: the definition merged with its pool's flavour and a rarity, in the flat shape
-- the factory and every older reader (name / rarity / baseMult / color / material / inherent*)
-- expect. baseMult is the listed base at that rarity; the drop's jitter is applied by the factory.
function BossWeapons.Resolve(archetypeKey, name, rarity)
	local pool = BossWeapons.Pools[archetypeKey]
	if not pool then
		return BossWeapons.Fallback
	end
	local def, key, isLegendary = BossWeapons.FindSword(name, archetypeKey)
	if not def then
		def, key, isLegendary = pool.legendary, archetypeKey, true
	end
	if isLegendary then
		rarity = "Legendary"
	elseif rarity == "Legendary" or not BossWeapons.RarityStep[rarity] then
		rarity = "Common"
	end
	return {
		name = def.name,
		rarity = rarity,
		baseMult = BossWeapons.BaseAt(def, rarity, isLegendary),
		poolBase = def.base,
		isLegendary = isLegendary,
		archetype = key,
		bossName = BossWeapons.BossNames[key],
		color = def.look.color,
		material = def.look.material,
		look = def.look,
		desc = def.desc,
		inherentBonusDmg = pool.inherentBonusDmg,
		inherentRange = def.inherentRange,
		inherentKnockback = def.inherentKnockback,
		inherentCrit = def.inherentCrit,
		weight = def.weight,
	}
end

-- The pool's showpiece.
function BossWeapons.GetLegendary(archetypeKey)
	return BossWeapons.Resolve(archetypeKey, nil, "Legendary")
end

-- Every sword of a pool as resolved rows at every rarity it drops at (the gallery, the dossier).
function BossWeapons.PoolRows(archetypeKey)
	local rows = {}
	local pool = BossWeapons.Pools[archetypeKey]
	if not pool then
		return rows
	end
	for _, def in ipairs(pool.swords) do
		local row = { name = def.name, poolBase = def.base, weight = def.weight, rarities = {}, def = def }
		for _, rarity in ipairs({ "Common", "Uncommon", "Rare", "Epic" }) do
			row.rarities[rarity] = BossWeapons.BaseAt(def, rarity, false)
		end
		table.insert(rows, row)
	end
	table.insert(rows, { name = pool.legendary.name, poolBase = pool.legendary.base, weight = 0, legendary = true,
		rarities = { Legendary = pool.legendary.base }, def = pool.legendary })
	return rows
end

function BossWeapons.CountSwords()
	local total = 0
	for _, key in ipairs(BossWeapons.ArchetypeByTier) do
		local pool = BossWeapons.Pools[key]
		total += pool and (#pool.swords + 1) or 0
	end
	return total
end

-- ---------------------------------------------------------------- compatibility
-- BossWeapons.Weapons[archetype] is each boss's signature sword (the five names the quests and the
-- older readers know), resolved at the rarity the merchant sells it at. Keeps MapClient's quest
-- guide, MerchantConfig and the tier-coloured stand-ins working unchanged.
BossWeapons.Signature = {
	Boss_Gorgon = "Warlord Greatsword",
	Boss_FrostRevenant = "Frostfang Cleaver",
	Boss_InfernalColossus = "Inferno Edge",
	Boss_VoidWraith = "Voidrend Blade",
	Boss_CelestialTitan = "Astral Eclipse",
}
BossWeapons.Weapons = {}
for key, name in pairs(BossWeapons.Signature) do
	BossWeapons.Weapons[key] = BossWeapons.Resolve(key, name, "Rare")
end

function BossWeapons.Get(archetypeKey)
	return BossWeapons.Weapons[archetypeKey] or BossWeapons.Fallback
end

function BossWeapons.GetTier(archetypeKey)
	return BossWeapons.Tiers[archetypeKey] or 1
end

function BossWeapons.GetByTier(tier)
	local archetypeKey = BossWeapons.ArchetypeByTier[tonumber(tier)]
	return archetypeKey and BossWeapons.Weapons[archetypeKey] or BossWeapons.Fallback
end

return BossWeapons
