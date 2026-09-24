--// BossWeapons  (single source of truth for the whole sword roster: 13 pools, 92 swords)
-- Read by BossSwordFactory (every drop, purchase, admin gift and vault / trade rebuild),
-- DropRules (which pool a dead rig rolls on, and at what chance), SwordDropSystem (auto-sell
-- values), MerchantConfig (shop listings) and the Studio-only stages.
--
-- Two kinds of pool, one shape:
--   * BossWeapons.Pools      the five BOSS pools (the unique rigs flagged Boss by EnemyCombat).
--   * BossWeapons.NormalPools  one LESSER pool per zone of WorldLayout.ZONES: the swords every
--     ordinary enemy in that zone can drop. Five lesser swords plus the zone's Relic (the pool's
--     Legendary slot). Their bases sit under the pool of the boss that zone leads to, so a lesser
--     sword is a real step up from what you are holding and never replaces a boss sword.
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
-- Boss odds no longer run backwards: they are flat-to-rising, and what climbs with the boss is the
-- POOL (7 / 7 / 10 / 10 / 10 swords) and the level of what is in it, not the frequency. Each rate is
-- set from the measured kills/hour of that boss (see the dossier) to pay 10-13 swords/hour. [TUNING]
BossWeapons.DropChance = {
	Boss_Gorgon = { chance = 0.18, rebirthClass = "Uncommon" },
	Boss_FrostRevenant = { chance = 0.22, rebirthClass = "Rare" },
	Boss_InfernalColossus = { chance = 0.18, rebirthClass = "Epic" },
	Boss_VoidWraith = { chance = 0.16, rebirthClass = "Epic" },
	Boss_CelestialTitan = { chance = 0.15, rebirthClass = "Legendary" },
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
			sword("Slagheap Cleaver", 2.90, 27, { mesh = "Blocks", color = rgb(104, 74, 62), material = Slate, accent = rgb(255, 150, 70), length = 3.6, blade = 0.9, width = 1.3, guard = 1.0 },
				{ inherentKnockback = 20 }, "Cleaver struck from the slagheap's crust"),
			sword("Ashen Saber", 3.45, 18, { mesh = "Blocks", color = rgb(132, 122, 122), material = Slate, accent = rgb(255, 90, 30), length = 3.8, blade = 1.0, width = 1.2, guard = 1.0 },
				{ inherentCrit = 0.08 }, "Grey ash-steel saber with a glowing fuller"),
			sword("Inferno Edge", 3.86, 13, { mesh = "Boss_InfernalColossus", color = rgb(255, 110, 20), material = Neon, length = 4.2 },
				{ inherentKnockback = 50, inherentCrit = 0.15 }, "Blazing blade radiating volcanic heat"),
			sword("Vent Sabre", 3.62, 16, { mesh = "Template", textured = false, color = rgb(198, 92, 48), material = Metal, length = 4.1 },
				{ inherentCrit = 0.10, inherentRange = 1.0 }, "Sabre tempered in a steam vent"),
			sword("Emberplate Claymore", 4.10, 11, { mesh = "Boss_Gorgon", textured = false, color = rgb(146, 78, 52), material = Metal, length = 4.3 },
				{ inherentKnockback = 45 }, "Claymore plated in cooling ember-scale"),
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
			sword("Nightfall Kris", 4.28, 27, { mesh = "Blocks", color = rgb(72, 50, 112), material = Metal, accent = rgb(178, 96, 255), length = 3.5, blade = 0.8, width = 0.9, guard = 0.8 },
				{ inherentCrit = 0.12 }, "Wave-edged kris that drinks the last of the light"),
			sword("Nether Saber", 5.23, 18, { mesh = "Blocks", color = rgb(42, 32, 62), material = Enum.Material.Foil, accent = rgb(190, 80, 255), length = 3.8, blade = 1.0, width = 1.2, guard = 1.0 },
				{ inherentCrit = 0.12, inherentKnockback = 20 }, "Saber that drinks the light around it"),
			sword("Voidrend Blade", 5.97, 13, { mesh = "Boss_VoidWraith", color = rgb(190, 80, 255), material = Neon, length = 4.2 },
				{ inherentCrit = 0.25, inherentRange = 4.0, inherentKnockback = 65 }, "Dimensional cleaver vibrating with abyss energy"),
			sword("Starless Sabre", 5.58, 16, { mesh = "Template", textured = false, color = rgb(52, 40, 80), material = Enum.Material.Foil, length = 4.1 },
				{ inherentCrit = 0.14, inherentRange = 1.5 }, "Sabre from the stretch of rift where no star shows"),
			sword("Collapse Claymore", 7.30, 9, { mesh = "Boss_Gorgon", textured = false, color = rgb(96, 48, 168), material = Enum.Material.Foil, length = 4.5 },
				{ inherentCrit = 0.15, inherentKnockback = 45 }, "Claymore folded around a collapse that never finished"),
			sword("Eventide Claymore", 6.83, 11, { mesh = "Boss_Gorgon", textured = false, color = rgb(120, 60, 200), material = Metal, length = 4.4 },
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
			sword("Corona Shortsword", 6.30, 27, { mesh = "Blocks", color = rgb(255, 226, 180), material = Metal, accent = rgb(255, 190, 70), length = 3.6, blade = 0.8, width = 1.0, guard = 0.9 },
				{ inherentCrit = 0.12, inherentRange = 1.0 }, "Short blade ringed in a thin corona"),
			sword("Halo Saber", 8.10, 18, { mesh = "Blocks", color = rgb(255, 230, 150), material = Metal, accent = rgb(255, 255, 255), length = 3.9, blade = 1.0, width = 1.2, guard = 1.1 },
				{ inherentCrit = 0.20, inherentKnockback = 30 }, "Saber ringed with a soft halo"),
			sword("Meridian Blade", 9.58, 13, { mesh = "Boss_CelestialTitan", textured = false, color = rgb(255, 215, 80), material = Metal, length = 4.2 },
				{ inherentCrit = 0.20, inherentRange = 3.0, inherentKnockback = 40 }, "Blade aligned to the sky's meridian"),
			sword("Zenithguard Blade", 8.80, 16, { mesh = "Template", textured = false, color = rgb(255, 240, 200), material = Glass, length = 4.2 },
				{ inherentCrit = 0.18, inherentRange = 2.5 }, "The Zenithguard's issue blade, clear as high air"),
			sword("Aurelian Claymore", 12.30, 9, { mesh = "Boss_Gorgon", textured = false, color = rgb(255, 222, 120), material = Metal, length = 4.6 },
				{ inherentCrit = 0.22, inherentKnockback = 70 }, "Claymore leafed in Aurelian gold from the Titan's steps"),
			sword("Sunspire Claymore", 11.32, 11, { mesh = "Boss_Gorgon", textured = false, color = rgb(255, 200, 60), material = Metal, length = 4.5 },
				{ inherentCrit = 0.25, inherentRange = 4.0, inherentKnockback = 60 }, "Claymore as tall and bright as the Summit's spire"),
			sword("Titanforged Greatsword", 13.38, 6, { mesh = "Boss_Gorgon", textured = false, color = rgb(220, 225, 240), material = Metal, length = 4.7 },
				{ inherentCrit = 0.25, inherentRange = 5.0, inherentKnockback = 80 }, "Greatsword hammered on the Titan's own anvil"),
		},
		legendary = sword("Astral Eclipse", 18.00, 0, { mesh = "Boss_Gorgon", color = rgb(255, 230, 80), material = Neon, length = 5.0 },
			{ inherentCrit = 0.35, inherentRange = 6.0, inherentKnockback = 100 }, "Supreme celestial blade infused with stellar supernova power"),
	},
}

-- ---------------------------------------------------------------- lesser swords
-- One pool per zone of WorldLayout.ZONES: what an ORDINARY enemy in that zone drops. Same shape as
-- a boss pool, so BossSwordFactory rolls it with the same three-stage roll (rarity -> which sword
-- -> stat jitter) and the same Resolve / PoolRows lookups read it.
--   * swords    five lesser swords, dropping at Common / Uncommon / Rare / Epic (RarityStep).
--   * legendary the zone's RELIC: the pool's Legendary slot, one per zone, the chase a player
--               farming normal enemies is actually farming for.
-- Bases are capped under the pool of the boss the zone leads to (IronLowlands x0.90-x1.20 under
-- the Warden of the Pit's x1.30 floor; Briarwood and the Glacier under the Frost Revenant's x1.90;
-- the Summit's x9.90-x12.16 under the Titan's best regular x13.38 -- the Summit's normals are
-- Lv 80-92, so capping them under the Titan's FLOOR would pay the hardest ordinary enemy in the
-- game less than a Lv 45 boss). The whole ladder rises monotonically in content order. [TUNING]
-- RELICS sit above that cap on purpose: each Relic is its area's spin-wheel chase (Config.SpinPools),
-- and the next area's step 1 carries the last area's chase in as its nice pull. So every Relic beats
-- the sword its area carries in (Lodestone x1.95 < Pit Sovereign x2.20 < Grovebound x2.40 < Blue Hour
-- x2.70 < Aurora x3.80 < Drowned Chime x4.10 < First Spark x4.60 < Colossus Heart x6.50 < Thunderglass
-- x7.10 < Quiet Star x9.40 < Archon x10.50 < Little Dawn x15.80 < Astral x18.00), and the chase
-- ladder never runs backwards across a border.
BossWeapons.NormalPools = {
	IronLowlands = { -- Quarry Bandits, Lv 1-3
		lesser = true, inherentBonusDmg = 0.05,
		swords = {
			sword("Quarry Shank", 0.90, 30, { mesh = "Blocks", color = rgb(168, 150, 132), material = Enum.Material.Metal, accent = rgb(140, 96, 52), length = 3.2, blade = 0.7, width = 0.8, guard = 0.8 },
				{ inherentRange = 0.5 }, "Pit tool reground into a blade between shifts"),
			sword("Toolhouse Cleaver", 0.97, 24, { mesh = "Blocks", color = rgb(150, 140, 130), material = Enum.Material.Metal, accent = rgb(120, 110, 96), length = 3.5, blade = 0.85, width = 1.2, guard = 0.9 },
				{ inherentKnockback = 8 }, "Heavy chopper off the toolhouse wall"),
			sword("Bandit's Machete", 1.04, 18, { mesh = "Template", textured = false, color = rgb(188, 168, 120), material = Enum.Material.Metal, length = 3.9 },
				{ inherentRange = 0.8 }, "Long camp machete, the quarry's first real sword"),
			sword("Rivetsteel Blade", 1.12, 13, { mesh = "Blocks", color = rgb(196, 204, 214), material = Enum.Material.Metal, accent = rgb(178, 128, 60), length = 3.8, blade = 1.0, width = 1.0, guard = 1.0 },
				{ inherentCrit = 0.03 }, "Straight blade riveted from cart plate"),
			sword("Foreman's Longsword", 1.20, 9, { mesh = "Template", textured = false, color = rgb(214, 206, 188), material = Enum.Material.Metal, length = 4.1 },
				{ inherentRange = 1.0, inherentKnockback = 10 }, "The old foreman's own sword, kept sharp out of spite"),
		},
		legendary = sword("Lodestone Edge", 1.95, 0, { mesh = "Template", textured = false, color = rgb(255, 226, 120), material = Enum.Material.Neon, length = 4.2 },
			{ inherentCrit = 0.05, inherentRange = 1.0 }, "A splinter of the quarry's singing lodestone, edged in gold"),
	},
	Briarwood = { -- Briarwood, Lv 9-14
		lesser = true, inherentBonusDmg = 0.08,
		swords = {
			sword("Thornwood Dirk", 1.34, 30, { mesh = "Blocks", color = rgb(140, 168, 92), material = Enum.Material.Wood, accent = rgb(96, 74, 44), length = 3.3, blade = 0.7, width = 0.8, guard = 0.8 },
				{ inherentCrit = 0.04 }, "Short dirk cut from a thorn trunk"),
			sword("Sapwood Falchion", 1.41, 24, { mesh = "Template", textured = false, color = rgb(176, 196, 116), material = Enum.Material.Wood, length = 3.9 },
				{ inherentRange = 0.8 }, "Springy sapwood falchion, light as a branch"),
			sword("Bramblecut Sabre", 1.48, 18, { mesh = "Blocks", color = rgb(120, 150, 78), material = Enum.Material.Grass, accent = rgb(72, 96, 40), length = 3.8, blade = 1.0, width = 1.1, guard = 1.0 },
				{ inherentKnockback = 12 }, "Sabre that clears bramble by the armful"),
			sword("Ranger's Longblade", 1.56, 13, { mesh = "Template", textured = false, color = rgb(206, 214, 170), material = Enum.Material.Metal, length = 4.1 },
				{ inherentRange = 1.2 }, "Standard issue for the grove wardens' rangers"),
			sword("Heartwood Broadsword", 1.64, 9, { mesh = "Blocks", color = rgb(96, 122, 56), material = Enum.Material.Wood, accent = rgb(186, 150, 74), length = 4.2, blade = 1.1, width = 1.4, guard = 1.1 },
				{ inherentKnockback = 18, inherentRange = 0.8 }, "Broadsword grown, not forged, from heartwood"),
		},
		legendary = sword("Grovebound Bloom", 2.40, 0, { mesh = "Template", textured = false, color = rgb(184, 255, 150), material = Enum.Material.Neon, length = 4.3 },
			{ inherentCrit = 0.08, inherentRange = 1.2 }, "A blade that flowers along the fuller when it swings"),
	},
	FrostboundGlacier = { -- Frostbound Glacier, Lv 18-23
		lesser = true, inherentBonusDmg = 0.1,
		swords = {
			sword("Icicle Shiv", 1.52, 30, { mesh = "Blocks", color = rgb(214, 238, 255), material = Enum.Material.Ice, accent = rgb(150, 186, 216), length = 3.2, blade = 0.7, width = 0.8, guard = 0.8 },
				{ inherentCrit = 0.04 }, "An icicle with a wrapped grip; it does not melt"),
			sword("Snowpack Falchion", 1.60, 24, { mesh = "Template", textured = false, color = rgb(236, 246, 255), material = Enum.Material.Snow, length = 3.9 },
				{ inherentKnockback = 10 }, "Pressed snowpack, cold enough to hold an edge"),
			sword("Frostpane Sabre", 1.68, 18, { mesh = "Blocks", color = rgb(178, 216, 244), material = Enum.Material.Glass, accent = rgb(120, 162, 204), length = 3.8, blade = 1.0, width = 1.0, guard = 1.0 },
				{ inherentCrit = 0.06 }, "Sabre of window-clear glacier pane"),
			sword("Glacierrun Longsword", 1.77, 13, { mesh = "Template", textured = false, color = rgb(158, 202, 236), material = Enum.Material.Ice, length = 4.1 },
				{ inherentRange = 1.2 }, "Long blade shaped by meltwater over a winter"),
			sword("Rimecoat Broadsword", 1.86, 9, { mesh = "Blocks", color = rgb(132, 180, 226), material = Enum.Material.Ice, accent = rgb(200, 228, 248), length = 4.2, blade = 1.1, width = 1.4, guard = 1.1 },
				{ inherentKnockback = 20 }, "Broadsword under a permanent coat of rime"),
		},
		legendary = sword("Blue Hour Shard", 2.70, 0, { mesh = "Template", textured = false, color = rgb(150, 236, 255), material = Enum.Material.Neon, length = 4.3 },
			{ inherentCrit = 0.1, inherentRange = 1.5 }, "Kept from the one blue hour the glacier lights up"),
	},
	SunkenMarsh = { -- Sunken Marsh, Lv 24-29
		lesser = true, inherentBonusDmg = 0.12,
		swords = {
			sword("Reed Cutter", 2.30, 30, { mesh = "Blocks", color = rgb(146, 170, 128), material = Enum.Material.Grass, accent = rgb(104, 120, 88), length = 3.3, blade = 0.75, width = 0.8, guard = 0.8 },
				{ inherentRange = 0.8 }, "Curved cutter for reed and rope alike"),
			sword("Bogiron Falchion", 2.42, 24, { mesh = "Template", textured = false, color = rgb(130, 130, 112), material = Enum.Material.Metal, length = 3.9 },
				{ inherentKnockback = 14 }, "Falchion smelted from bog iron, pitted and stubborn"),
			sword("Silt Sabre", 2.55, 18, { mesh = "Blocks", color = rgb(112, 128, 116), material = Enum.Material.Slate, accent = rgb(168, 176, 148), length = 3.8, blade = 1.0, width = 1.1, guard = 1.0 },
				{ inherentCrit = 0.06 }, "Grey sabre polished by a century of silt"),
			sword("Marshlight Longsword", 2.68, 13, { mesh = "Template", textured = false, color = rgb(186, 226, 188), material = Enum.Material.Glass, length = 4.1 },
				{ inherentCrit = 0.08, inherentRange = 1.0 }, "Carries a marshlight in the fuller, and leads you home"),
			sword("Bellringer Broadsword", 2.82, 9, { mesh = "Blocks", color = rgb(96, 116, 124), material = Enum.Material.Metal, accent = rgb(198, 172, 108), length = 4.3, blade = 1.1, width = 1.5, guard = 1.1 },
				{ inherentKnockback = 24 }, "Rings like the sunken bell when it lands"),
		},
		legendary = sword("Drowned Chime", 4.10, 0, { mesh = "Template", textured = false, color = rgb(150, 255, 214), material = Enum.Material.Neon, length = 4.4 },
			{ inherentCrit = 0.1, inherentKnockback = 22 }, "The bell's own bronze, drawn out into a blade that hums"),
	},
	InfernalCaldera = { -- Infernal Caldera, Lv 34-41
		lesser = true, inherentBonusDmg = 0.15,
		swords = {
			sword("Emberchip Shiv", 3.00, 30, { mesh = "Blocks", color = rgb(92, 62, 56), material = Enum.Material.Basalt, accent = rgb(255, 138, 60), length = 3.2, blade = 0.7, width = 0.8, guard = 0.8 },
				{ inherentKnockback = 12 }, "A chip of the caldera floor, still warm"),
			sword("Sootglass Falchion", 3.16, 24, { mesh = "Template", textured = false, color = rgb(96, 88, 88), material = Enum.Material.Glass, length = 3.9 },
				{ inherentCrit = 0.06 }, "Black glass falchion, smoke trapped inside it"),
			sword("Clinker Sabre", 3.33, 18, { mesh = "Blocks", color = rgb(128, 96, 84), material = Enum.Material.Slate, accent = rgb(255, 116, 44), length = 3.9, blade = 1.0, width = 1.1, guard = 1.0 },
				{ inherentCrit = 0.08 }, "Rough clinker sabre with a glowing seam"),
			sword("Furnace Longsword", 3.50, 13, { mesh = "Template", textured = false, color = rgb(226, 128, 60), material = Enum.Material.Metal, length = 4.1 },
				{ inherentRange = 1.2, inherentKnockback = 18 }, "Longsword that never quite finished cooling"),
			sword("Caldera Broadsword", 3.68, 9, { mesh = "Blocks", color = rgb(70, 56, 54), material = Enum.Material.Basalt, accent = rgb(255, 158, 70), length = 4.3, blade = 1.1, width = 1.5, guard = 1.1 },
				{ inherentKnockback = 30 }, "Broad slab of caldera rock with a hilt"),
		},
		legendary = sword("First Spark", 4.60, 0, { mesh = "Template", textured = false, color = rgb(255, 196, 96), material = Enum.Material.Neon, length = 4.4 },
			{ inherentCrit = 0.12, inherentKnockback = 28 }, "The spark the caldera was lit from, kept in a blade"),
	},
	Stormwatch = { -- Stormwatch, Lv 41-48
		lesser = true, inherentBonusDmg = 0.18,
		swords = {
			sword("Sparkwire Shiv", 4.10, 30, { mesh = "Blocks", color = rgb(164, 178, 206), material = Enum.Material.Metal, accent = rgb(140, 200, 255), length = 3.2, blade = 0.7, width = 0.8, guard = 0.8 },
				{ inherentCrit = 0.06 }, "Coiled sparkwire with an edge and a bite"),
			sword("Coppervane Falchion", 4.32, 24, { mesh = "Template", textured = false, color = rgb(198, 140, 92), material = Enum.Material.Metal, length = 3.9 },
				{ inherentRange = 1.0 }, "Copper vane off the observatory roof, re-edged"),
			sword("Weathervane Sabre", 4.55, 18, { mesh = "Blocks", color = rgb(146, 160, 188), material = Enum.Material.Metal, accent = rgb(210, 226, 255), length = 3.9, blade = 1.0, width = 1.1, guard = 1.0 },
				{ inherentCrit = 0.08, inherentRange = 1.0 }, "Sabre that turns toward the next storm"),
			sword("Rodsteel Longsword", 4.79, 13, { mesh = "Template", textured = false, color = rgb(180, 200, 232), material = Enum.Material.Metal, length = 4.2 },
				{ inherentKnockback = 25 }, "Drawn from a lightning rod that has been hit twice"),
			sword("Observatory Broadsword", 5.04, 9, { mesh = "Blocks", color = rgb(88, 102, 138), material = Enum.Material.Metal, accent = rgb(150, 210, 255), length = 4.3, blade = 1.1, width = 1.5, guard = 1.1 },
				{ inherentKnockback = 34, inherentRange = 1.2 }, "The Observatory's own standard, broad and blue"),
		},
		legendary = sword("Thunderglass Pane", 7.10, 0, { mesh = "Template", textured = false, color = rgb(170, 224, 255), material = Enum.Material.Neon, length = 4.5 },
			{ inherentCrit = 0.14, inherentKnockback = 30 }, "Glass fused where the lightning went to ground"),
	},
	VoidRift = { -- Void Rift, Lv 55-66
		lesser = true, inherentBonusDmg = 0.25,
		swords = {
			sword("Riftsliver", 6.10, 30, { mesh = "Blocks", color = rgb(108, 80, 156), material = Enum.Material.Foil, accent = rgb(198, 120, 255), length = 3.2, blade = 0.7, width = 0.8, guard = 0.8 },
				{ inherentCrit = 0.1 }, "A sliver the rift shed, sharp on every side"),
			sword("Hushed Falchion", 6.42, 24, { mesh = "Template", textured = false, color = rgb(80, 62, 108), material = Enum.Material.Slate, length = 3.9 },
				{ inherentCrit = 0.1, inherentRange = 1.0 }, "Makes no sound at all, not even on impact"),
			sword("Gloamsteel Sabre", 6.76, 18, { mesh = "Blocks", color = rgb(62, 52, 86), material = Enum.Material.Foil, accent = rgb(176, 116, 255), length = 3.9, blade = 1.0, width = 1.1, guard = 1.0 },
				{ inherentCrit = 0.12 }, "Steel poured in the gloam between two rifts"),
			sword("Nullbrand Longsword", 7.12, 13, { mesh = "Template", textured = false, color = rgb(140, 104, 208), material = Enum.Material.Metal, length = 4.2 },
				{ inherentRange = 2.0, inherentCrit = 0.1 }, "Brand that leaves nothing behind to heal"),
			sword("Riftwalker Broadsword", 7.50, 9, { mesh = "Blocks", color = rgb(46, 36, 68), material = Enum.Material.Glass, accent = rgb(214, 140, 255), length = 4.4, blade = 1.1, width = 1.5, guard = 1.1 },
				{ inherentKnockback = 40, inherentRange = 1.5 }, "Broadsword of collapsed rift-glass, heavy as a door"),
		},
		legendary = sword("Quiet Star", 9.40, 0, { mesh = "Template", textured = false, color = rgb(226, 170, 255), material = Enum.Material.Neon, length = 4.6 },
			{ inherentCrit = 0.18, inherentRange = 2.5 }, "A star that fell through the rift and stopped shining"),
	},
	CelestialSummit = { -- Celestial Summit, Lv 80-92
		lesser = true, inherentBonusDmg = 0.4,
		swords = {
			sword("Sunmote Shiv", 9.90, 30, { mesh = "Blocks", color = rgb(255, 240, 206), material = Enum.Material.Metal, accent = rgb(255, 208, 96), length = 3.3, blade = 0.7, width = 0.8, guard = 0.8 },
				{ inherentCrit = 0.1 }, "A mote of the Summit's light, small and very hot"),
			sword("Cloudcut Falchion", 10.42, 24, { mesh = "Template", textured = false, color = rgb(226, 238, 255), material = Enum.Material.Glass, length = 4.0 },
				{ inherentRange = 1.5 }, "Falchion cut from the cloud deck below the peak"),
			sword("Zenith Sabre", 10.97, 18, { mesh = "Blocks", color = rgb(255, 234, 170), material = Enum.Material.Metal, accent = rgb(255, 255, 240), length = 4.0, blade = 1.0, width = 1.1, guard = 1.0 },
				{ inherentCrit = 0.15 }, "Sabre aligned to the sun at its highest"),
			sword("Daybreak Longsword", 11.55, 13, { mesh = "Template", textured = false, color = rgb(255, 220, 140), material = Enum.Material.Metal, length = 4.3 },
				{ inherentCrit = 0.15, inherentRange = 2.0 }, "Longsword the colour of the first minute of light"),
			sword("Summitward Broadsword", 12.16, 9, { mesh = "Blocks", color = rgb(240, 244, 255), material = Enum.Material.Metal, accent = rgb(255, 214, 110), length = 4.5, blade = 1.15, width = 1.5, guard = 1.15 },
				{ inherentKnockback = 50, inherentRange = 2.0 }, "Broad blade carried up the last stair of the Summit"),
		},
		legendary = sword("Little Dawn", 15.80, 0, { mesh = "Template", textured = false, color = rgb(255, 246, 170), material = Enum.Material.Neon, length = 4.7 },
			{ inherentCrit = 0.22, inherentRange = 3.0 }, "Not the Titan's sun: a small, stubborn dawn of your own"),
	},
}

-- ---------------------------------------------------------------- spin-wheel-only swords
-- Swords only the town spin wheel gives (Config.SpinPools). They live in their zone's pool so
-- Resolve / FindSword / a saved sword's rebuild find them like any other, but no enemy drops them:
--   * WARDEN EPICS join the zone's `swords` at weight 0 (rollSword never picks a 0-weight sword), so
--     the three warden areas' boss steps bring a real new sword: Hollowbough, Frogsong, Pinwheel.
--   * SPIN REGULARS give every area's wheel its own weapon family instead of one Shiv / Falchion /
--     Sabre trio repeated eight times (billhooks in Briarwood, an estoc on the Glacier, cutlass and
--     oar in the Marsh, khopesh / flamberge / chopper in the Caldera, rapier / gladius / epee /
--     tulwar at Stormwatch, kris and tanto in the Void, katana and nodachi on the Summit). They also
--     join the zone's `swords` at weight 0, and their bases sit inside the zone's existing band.
--   * SPIN RELICS are extra named Legendaries (`spinRelics`, resolved as Legendary like the Relic):
--     the warden areas' own chase (Honeycomb Thorn, Lilypad Lantern, Kitestring Rapier, and the
--     Stormwatch midway camp's Bottled Lightning), the GREAT
--     pull of the Caldera, Stormwatch and Summit boss steps (Caramelt Claymore, Double Rainbow,
--     Sunsqueeze Blade), and five TRAILHEAD chases so a new area has its own hunt from the first
--     spin (Snowglobe Sabre, Rubber Duck Rapier, Toasted Marshmallow Brand, Wishbone Comet,
--     Origami Crane Blade). Each sits between the sword the area carries in and its ultra. [TUNING]
local wardenEpics = {
	Briarwood = sword("Hollowbough Claymore", 1.72, 0, { mesh = "Blocks", color = rgb(118, 92, 54), material = Enum.Material.Wood, accent = rgb(255, 214, 92), length = 4.4, blade = 1.15, width = 1.5, guard = 1.15 },
		{ inherentKnockback = 20, inherentRange = 1.0 }, "Carved from the hollow bough the Root Warden sleeps in; bees still visit it"),
	SunkenMarsh = sword("Frogsong Greatsword", 3.20, 0, { mesh = "Blocks", color = rgb(92, 170, 96), material = Enum.Material.Metal, accent = rgb(230, 255, 170), length = 4.5, blade = 1.15, width = 1.5, guard = 1.15 },
		{ inherentKnockback = 26, inherentCrit = 0.06 }, "Croaks a little tune on every swing; the whole marsh sings back"),
	Stormwatch = sword("Pinwheel Claymore", 5.61, 0, { mesh = "Blocks", color = rgb(255, 140, 170), material = Enum.Material.Metal, accent = rgb(140, 220, 255), length = 4.5, blade = 1.15, width = 1.5, guard = 1.15 },
		{ inherentKnockback = 36, inherentRange = 1.2 }, "The Tempest Warden's pinwheel, spun up into a blade by the big storm"),
}
local spinRegulars = {
	Briarwood = {
		sword("Briar Billhook", 1.41, 0, { mesh = "Blocks", color = rgb(150, 120, 70), material = Enum.Material.Wood, accent = rgb(120, 168, 80), length = 3.6, blade = 1.2, width = 1.3, guard = 0.7 },
			{ inherentKnockback = 10 }, "A hedge billhook with a thorn for a hilt; it clears a path and then some"),
		sword("Hedgehog Hooksword", 1.48, 0, { mesh = "Blocks", color = rgb(168, 132, 96), material = Enum.Material.Metal, accent = rgb(96, 70, 44), length = 3.9, blade = 0.9, width = 1.0, guard = 1.3 },
			{ inherentCrit = 0.04, inherentRange = 0.6 }, "Hooked tip, bristly guard; it curls up if you drop it"),
	},
	FrostboundGlacier = {
		sword("Icicle Estoc", 1.89, 0, { mesh = "Template", textured = false, color = rgb(200, 236, 255), material = Enum.Material.Ice, length = 4.4 },
			{ inherentRange = 1.4 }, "A long, thin icicle that set straight enough to thrust with"),
	},
	SunkenMarsh = {
		sword("Ferryman's Cutlass", 2.42, 0, { mesh = "Blocks", color = rgb(120, 108, 84), material = Enum.Material.Metal, accent = rgb(200, 170, 90), length = 3.6, blade = 1.1, width = 1.2, guard = 1.3 },
			{ inherentKnockback = 14 }, "The old ferryman's cutlass; still smells a little of river"),
		sword("Oarblade", 2.55, 0, { mesh = "Blocks", color = rgb(150, 118, 80), material = Enum.Material.Wood, accent = rgb(110, 150, 120), length = 4.4, blade = 1.3, width = 1.6, guard = 0.7 },
			{ inherentRange = 1.2, inherentKnockback = 12 }, "A flat oar with an edge on it; rows and cuts equally well"),
	},
	InfernalCaldera = {
		sword("Kilnhook Khopesh", 3.00, 0, { mesh = "Blocks", color = rgb(110, 70, 52), material = Enum.Material.Basalt, accent = rgb(255, 150, 60), length = 3.5, blade = 1.2, width = 1.4, guard = 0.8 },
			{ inherentKnockback = 16 }, "Sickle-backed blade the kiln-keepers hook the hot trays out with"),
		sword("Cinderwave Flamberge", 3.16, 0, { mesh = "Template", textured = false, color = rgb(210, 90, 40), material = Enum.Material.Metal, length = 4.3 },
			{ inherentCrit = 0.07, inherentRange = 1.0 }, "Wavy flamberge that flickers like a heat haze"),
		sword("Anvilback Chopper", 3.33, 0, { mesh = "Blocks", color = rgb(80, 74, 72), material = Enum.Material.Metal, accent = rgb(255, 120, 50), length = 3.7, blade = 1.3, width = 1.7, guard = 0.9 },
			{ inherentKnockback = 26 }, "A chopper with an anvil for a spine; mind your toes"),
	},
	Stormwatch = {
		sword("Barometer Rapier", 4.10, 0, { mesh = "Template", textured = false, color = rgb(210, 190, 140), material = Enum.Material.Metal, length = 4.3 },
			{ inherentCrit = 0.07 }, "A brass needle that swings toward low pressure"),
		sword("Gustcutter Gladius", 4.32, 0, { mesh = "Blocks", color = rgb(170, 188, 214), material = Enum.Material.Metal, accent = rgb(120, 190, 255), length = 3.3, blade = 1.1, width = 1.2, guard = 1.0 },
			{ inherentKnockback = 20 }, "Short, wide and quick, like the first gust of a storm"),
		sword("Weathercock Epee", 4.45, 0, { mesh = "Template", textured = false, color = rgb(226, 176, 90), material = Enum.Material.Metal, length = 4.4 },
			{ inherentRange = 1.2, inherentCrit = 0.05 }, "Off the top of the tallest roof; it still points into the wind"),
		sword("Stormbell Tulwar", 4.55, 0, { mesh = "Blocks", color = rgb(120, 136, 170), material = Enum.Material.Metal, accent = rgb(255, 230, 140), length = 3.9, blade = 1.1, width = 1.3, guard = 1.2 },
			{ inherentKnockback = 22, inherentRange = 0.8 }, "Curved tulwar with a little storm bell on the pommel"),
	},
	VoidRift = {
		sword("Hushfang Kris", 6.42, 0, { mesh = "Blocks", color = rgb(86, 64, 124), material = Enum.Material.Foil, accent = rgb(210, 140, 255), length = 3.4, blade = 0.8, width = 0.9, guard = 0.9 },
			{ inherentCrit = 0.12 }, "A wavy kris that bites without a sound"),
		sword("Gloam Tanto", 6.76, 0, { mesh = "Blocks", color = rgb(50, 42, 72), material = Enum.Material.Metal, accent = rgb(170, 110, 255), length = 3.0, blade = 0.8, width = 0.9, guard = 0.6 },
			{ inherentCrit = 0.14, inherentRange = 0.5 }, "Short and straight, drawn from the gloam between two rifts"),
	},
	CelestialSummit = {
		sword("Cloudstep Katana", 9.90, 0, { mesh = "Template", textured = false, color = rgb(240, 244, 255), material = Enum.Material.Metal, length = 4.3 },
			{ inherentCrit = 0.12, inherentRange = 1.5 }, "Light enough to carry up every stair of the Summit"),
		sword("Highwind Nodachi", 10.97, 0, { mesh = "Template", textured = false, color = rgb(255, 236, 190), material = Enum.Material.Glass, length = 4.8 },
			{ inherentRange = 2.5, inherentCrit = 0.12 }, "A very long blade for the very high wind"),
	},
}
local spinRelics = {
	FrostboundGlacier = {
		sword("Snowglobe Sabre", 2.60, 0, { mesh = "Template", textured = false, color = rgb(220, 245, 255), material = Enum.Material.Neon, length = 4.3 },
			{ inherentCrit = 0.09, inherentRange = 1.2 }, "Shake it and it snows on whoever you hit"),
	},
	Briarwood = {
		sword("Honeycomb Thorn", 2.25, 0, { mesh = "Template", textured = false, color = rgb(255, 204, 72), material = Enum.Material.Neon, length = 4.3 },
			{ inherentCrit = 0.07, inherentRange = 1.0 }, "A thorn the grove bees built a comb around; it drips a little when it hits"),
	},
	SunkenMarsh = {
		sword("Rubber Duck Rapier", 3.95, 0, { mesh = "Template", textured = false, color = rgb(255, 226, 80), material = Enum.Material.Neon, length = 4.3 },
			{ inherentCrit = 0.1, inherentKnockback = 18 }, "Squeaks on every hit. Nobody knows who made it; everybody wants it"),
		sword("Lilypad Lantern", 3.85, 0, { mesh = "Template", textured = false, color = rgb(190, 255, 150), material = Enum.Material.Neon, length = 4.4 },
			{ inherentCrit = 0.09, inherentRange = 1.2 }, "A lantern-bright blade that floats if you drop it in the marsh"),
	},
	InfernalCaldera = {
		sword("Toasted Marshmallow Brand", 5.20, 0, { mesh = "Template", textured = false, color = rgb(255, 222, 170), material = Enum.Material.Neon, length = 4.5 },
			{ inherentCrit = 0.11, inherentKnockback = 24 }, "Golden outside, gooey inside, held over the caldera just long enough"),
		sword("Caramelt Claymore", 5.60, 0, { mesh = "Template", textured = false, color = rgb(255, 160, 60), material = Enum.Material.Neon, length = 4.6 },
			{ inherentKnockback = 30, inherentCrit = 0.1 }, "Molten sugar that set as hard as basalt; smells like a fair"),
	},
	Stormwatch = {
		sword("Bottled Lightning", 6.10, 0, { mesh = "Template", textured = false, color = rgb(255, 244, 150), material = Enum.Material.Neon, length = 4.4 },
			{ inherentCrit = 0.13, inherentKnockback = 22 }, "A bolt somebody caught in a lemonade jar; it hums whenever a storm is near"),
		sword("Kitestring Rapier", 6.70, 0, { mesh = "Template", textured = false, color = rgb(200, 236, 255), material = Enum.Material.Neon, length = 4.5 },
			{ inherentCrit = 0.14, inherentRange = 1.5 }, "Flew on a kite through the big storm and came down charged"),
		sword("Double Rainbow", 6.90, 0, { mesh = "Template", textured = false, color = rgb(255, 150, 230), material = Enum.Material.Neon, length = 4.6 },
			{ inherentCrit = 0.15, inherentKnockback = 30 }, "Two rainbows after the storm, and one of them came down as a sword"),
	},
	VoidRift = {
		sword("Wishbone Comet", 9.95, 0, { mesh = "Template", textured = false, color = rgb(250, 210, 255), material = Enum.Material.Neon, length = 4.7 },
			{ inherentCrit = 0.18, inherentRange = 2.0 }, "A comet split like a wishbone; you got the bigger half"),
	},
	CelestialSummit = {
		sword("Origami Crane Blade", 14.50, 0, { mesh = "Template", textured = false, color = rgb(255, 250, 235), material = Enum.Material.Neon, length = 4.6 },
			{ inherentCrit = 0.2, inherentRange = 2.5 }, "Folded from one sheet of Summit cloud: a thousand folds, one edge"),
		sword("Sunsqueeze Blade", 16.90, 0, { mesh = "Template", textured = false, color = rgb(255, 236, 90), material = Enum.Material.Neon, length = 4.8 },
			{ inherentCrit = 0.22, inherentRange = 3.0 }, "Squeezed from the first sun over the Summit, like the best lemon in the bowl"),
	},
}
for zone, def in pairs(wardenEpics) do
	table.insert(BossWeapons.NormalPools[zone].swords, def)
end
for zone, list in pairs(spinRegulars) do
	for _, def in ipairs(list) do
		table.insert(BossWeapons.NormalPools[zone].swords, def)
	end
end
for zone, list in pairs(spinRelics) do
	BossWeapons.NormalPools[zone].spinRelics = list
end

-- ---------------------------------------------------------------- what a normal enemy pays
-- Which zone pool a rig rolls on comes from its own Zone attribute (EnemyCombat sets it); this
-- table says HOW OFTEN, per enemy archetype, and which rarity ladder it uses.
--   rank "trash"  the zone's fast minion          rank "mid"    the zone's heavier minion
--   rank "warden" a zone capstone that is not one of the five unique bosses (EnemyCombat gives it
--                 role "boss" but no Boss attribute, so it used to drop nothing at all)
-- An "elite" SPAWN of any archetype (WorldLayout role "elite") multiplies the chance by
-- ELITE_CHANCE_MULT and rolls the elite ladder instead of its archetype's own.
-- Every chance is set from that enemy's MEASURED kills/hour (dossier, section "per hour") so that
-- each row pays 7.5-12 swords/hour: no enemy in the game is worth zero. [TUNING]
BossWeapons.NormalDrops = {
	IronSquire        = { chance = 0.020, rank = "trash", zone = "IronLowlands" }, -- Quarry Cutthroat,  ~400 kills/h
	IronBerserker     = { chance = 0.025, rank = "mid", zone = "IronLowlands" },  -- Pit Brute,         ~305 kills/h
	ThornStalker      = { chance = 0.020, rank = "trash", zone = "Briarwood" },   -- Thorn Stalker,     ~397 kills/h
	BriarBrute        = { chance = 0.025, rank = "mid", zone = "Briarwood" },     -- Briar Brute,       ~298 kills/h
	RootWarden        = { chance = 0.080, rank = "warden", zone = "Briarwood" },  -- Rootbound Warden,  ~123 kills/h
	FrostImp          = { chance = 0.025, rank = "trash", zone = "FrostboundGlacier" }, -- Frost Stalker,     ~347 kills/h
	GlacialGargoyle   = { chance = 0.035, rank = "mid", zone = "FrostboundGlacier" }, -- Glacial Sentinel,  ~234 kills/h
	BogLurker         = { chance = 0.030, rank = "trash", zone = "SunkenMarsh" }, -- Bog Lurker,        ~297 kills/h
	MireHulk          = { chance = 0.040, rank = "mid", zone = "SunkenMarsh" },   -- Mire Hulk,         ~199 kills/h
	DrownedBellwarden = { chance = 0.100, rank = "warden", zone = "SunkenMarsh" }, -- Drowned Bellwarden, ~87 kills/h
	CinderFiend       = { chance = 0.030, rank = "trash", zone = "InfernalCaldera" }, -- Cinder Fiend,      ~255 kills/h
	MagmaJuggernaut   = { chance = 0.050, rank = "mid", zone = "InfernalCaldera" }, -- Magma Juggernaut,  ~155 kills/h
	Stormcaller       = { chance = 0.035, rank = "trash", zone = "Stormwatch" },  -- Stormcaller,       ~229 kills/h
	ThunderConstruct  = { chance = 0.055, rank = "mid", zone = "Stormwatch" },    -- Thunder Construct, ~143 kills/h
	TempestWarden     = { chance = 0.140, rank = "warden", zone = "Stormwatch" }, -- Tempest Warden,     ~64 kills/h
	VoidShade         = { chance = 0.050, rank = "trash", zone = "VoidRift" },    -- Void Shade,        ~165 kills/h
	AbyssTormentor    = { chance = 0.090, rank = "mid", zone = "VoidRift" },      -- Abyss Tormentor,    ~89 kills/h
	AstralWisp        = { chance = 0.090, rank = "trash", zone = "CelestialSummit" }, -- Astral Emissary,    ~91 kills/h
	SolarDominator    = { chance = 0.190, rank = "mid", zone = "CelestialSummit" }, -- Solar Dominator,    ~42 kills/h
}

-- An elite spawn of an ordinary archetype. [TUNING]
BossWeapons.ELITE_CHANCE_MULT = 1.5

-- Per-kill chance grows with rebirths by this much of itself, per rebirth (a 2% trash roll is
-- 2.16% at rebirth 1 and 3.2% at rebirth 8). Flat-per-rebirth scaling, which the boss rolls use,
-- would turn a 2% roll into 5% after one rebirth. [TUNING]
BossWeapons.NORMAL_REBIRTH_BONUS = 0.08

-- What a lesser drop lands at, by the rank of the rig that dropped it. Same five names and colours
-- as the boss ladder; a higher rank shifts mass up it, so an elite or a warden is not just more
-- often, it is better. The Legendary slot is the zone Relic. Each row sums to 1 and these are the
-- odds the drop card prints. [TUNING]
BossWeapons.NormalRarityOdds = {
	trash = {
		{ rarity = "Common", p = 0.6200 }, { rarity = "Uncommon", p = 0.2700 },
		{ rarity = "Rare", p = 0.0900 }, { rarity = "Epic", p = 0.0195 }, { rarity = "Legendary", p = 0.0005 },
	},
	mid = {
		{ rarity = "Common", p = 0.5400 }, { rarity = "Uncommon", p = 0.3000 },
		{ rarity = "Rare", p = 0.1200 }, { rarity = "Epic", p = 0.0375 }, { rarity = "Legendary", p = 0.0025 },
	},
	elite = {
		{ rarity = "Common", p = 0.4400 }, { rarity = "Uncommon", p = 0.3200 },
		{ rarity = "Rare", p = 0.1700 }, { rarity = "Epic", p = 0.0630 }, { rarity = "Legendary", p = 0.0070 },
	},
	warden = {
		{ rarity = "Common", p = 0.3000 }, { rarity = "Uncommon", p = 0.3300 },
		{ rarity = "Rare", p = 0.2400 }, { rarity = "Epic", p = 0.1100 }, { rarity = "Legendary", p = 0.0200 },
	},
}

-- A lesser sword auto-sells for this share of a boss sword of the same region tier and rarity.
BossWeapons.LESSER_SELL_FACTOR = 0.35

-- Region tier of each zone, so a lesser sword carries the same BossTier a boss sword of its region
-- does (SwordValue, the Vault, the hotbar tint and every older reader keep working unchanged).
BossWeapons.ZoneTier = {
	IronLowlands = 1, Briarwood = 1, FrostboundGlacier = 2, SunkenMarsh = 2,
	InfernalCaldera = 3, Stormwatch = 3, VoidRift = 4, CelestialSummit = 5,
}

BossWeapons.ZoneOrder = { "IronLowlands", "Briarwood", "FrostboundGlacier", "SunkenMarsh",
	"InfernalCaldera", "Stormwatch", "VoidRift", "CelestialSummit" }

-- Every pool key in the game, bosses first, then zones: the roster order for the gallery,
-- the dossier and FindSword's unqualified lookup.
BossWeapons.PoolKeyOrder = {}
for tier = 1, 5 do table.insert(BossWeapons.PoolKeyOrder, BossWeapons.ArchetypeByTier[tier]) end
for _, zone in ipairs(BossWeapons.ZoneOrder) do table.insert(BossWeapons.PoolKeyOrder, zone) end

-- The pool a key names, boss or zone, and whether it is a lesser (normal-enemy) pool.
function BossWeapons.PoolFor(key)
	local pool = BossWeapons.Pools[key]
	if pool then return pool, false end
	pool = BossWeapons.NormalPools[key]
	if pool then return pool, true end
	return nil, false
end

function BossWeapons.IsLesserPool(key)
	return BossWeapons.NormalPools[key] ~= nil
end

-- Display name of a pool: the boss who drops it, or the zone it is farmed in.
BossWeapons.ZoneNames = {
	IronLowlands = "Iron Lowlands", Briarwood = "Briarwood", FrostboundGlacier = "Frostbound Glacier",
	SunkenMarsh = "Sunken Marsh", InfernalCaldera = "Infernal Caldera", Stormwatch = "Stormwatch",
	VoidRift = "Void Rift", CelestialSummit = "Celestial Summit",
}
function BossWeapons.PoolName(key)
	return BossWeapons.BossNames[key] or BossWeapons.ZoneNames[key] or key
end

-- THE STARTER. The ClassicSword every profile begins with is a real sword to the rest of the
-- game now: it is a Common lesser sword of the Iron Lowlands' tier at x1.00 (RuntimeBootstrap
-- stamps the attributes on the StarterPack template), so it saves, rebuilds and rates like any
-- other pool sword. It is in NO drop pool: FindSword
-- resolves it by name only, so nothing ever drops it and it never appears in a pool's roster.
-- It is worth nothing at a sale (SellValue) and never shatters on death (SwordDropSystem).
BossWeapons.STARTER_POOL = "IronLowlands"
BossWeapons.Starter = sword("Classic Sword", 1.00, 0,
	{ mesh = "Blocks", color = rgb(236, 244, 255), material = Enum.Material.SmoothPlastic, accent = rgb(255, 200, 48) },
	{}, "The sword you came in with. It has a lot left to learn.")

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
	if name == BossWeapons.Starter.name then
		return BossWeapons.Starter, archetypeKey or BossWeapons.STARTER_POOL, false
	end
	local keys = archetypeKey and { archetypeKey } or BossWeapons.PoolKeyOrder
	for _, key in ipairs(keys) do
		local pool = BossWeapons.PoolFor(key)
		if pool then
			if pool.legendary.name == name then
				return pool.legendary, key, true
			end
			for _, def in ipairs(pool.spinRelics or {}) do
				if def.name == name then
					return def, key, true
				end
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
	local pool, isLesser = BossWeapons.PoolFor(archetypeKey)
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
		poolKey = key,
		lesser = isLesser == true,
		bossName = BossWeapons.PoolName(key),
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
	local pool = BossWeapons.PoolFor(archetypeKey)
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

-- Swords in the roster. scope "boss" counts the five boss pools, "lesser" the eight zone pools,
-- anything else counts both.
function BossWeapons.CountSwords(scope)
	local total = 0
	if scope ~= "lesser" then
		for _, key in ipairs(BossWeapons.ArchetypeByTier) do
			local pool = BossWeapons.Pools[key]
			total += pool and (#pool.swords + 1) or 0
		end
	end
	if scope ~= "boss" then
		for _, zone in ipairs(BossWeapons.ZoneOrder) do
			local pool = BossWeapons.NormalPools[zone]
			total += pool and (#pool.swords + 1) or 0
		end
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
	return BossWeapons.Tiers[archetypeKey] or BossWeapons.ZoneTier[archetypeKey] or 1
end

function BossWeapons.GetByTier(tier)
	local archetypeKey = BossWeapons.ArchetypeByTier[tonumber(tier)]
	return archetypeKey and BossWeapons.Weapons[archetypeKey] or BossWeapons.Fallback
end

return BossWeapons
