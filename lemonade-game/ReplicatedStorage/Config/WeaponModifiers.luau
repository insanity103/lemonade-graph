-- ModuleScript | ReplicatedStorage.Config.WeaponModifiers | The sword modifier ladder and its odds.
--
-- Ten rungs (tiers) per modifier category. Rungs 1-6 are the BODY: their odds depend on the
-- sword's rarity (a Legendary lives around Golden, an Uncommon around Fresh/Zesty). Rungs 7-10
-- are the LONG TAIL: a fixed 1-in-N per rolled slot that ignores rarity, so any relic can land
-- a Lemonade roll, and luck (kill streaks, boss charges, rebirth, Blessed) multiplies only the
-- tail. Every number the player sees comes from WeaponModifiers.Ladder, so the disclosure is the
-- real odds. Saved swords keep loading: rungs 1-6 keep their old names and stat values.
local WeaponModifiers = {}

-- Base chance for a weapon of any rarity to roll an extra modifier slot (Blessed)
WeaponModifiers.EXTRA_SLOT_CHANCE = 0.03 -- 3% base chance for blessed slot

WeaponModifiers.TIER_COUNT = 10
WeaponModifiers.BODY_TIERS = 6 -- rungs 1..6 are rarity-shaped; 7..10 are the fixed long tail

-- The rung names and colours the player sees on the ladder (Odds popup, reveal band, loot card).
-- The prefix names below are what lands on the sword ("Sunburst Astral Eclipse").
WeaponModifiers.Rungs = {
	{ name = "Fresh",     color = Color3.fromRGB(170, 170, 176) },
	{ name = "Zesty",     color = Color3.fromRGB(90, 200, 120) },
	{ name = "Fizzy",     color = Color3.fromRGB(80, 150, 255) },
	{ name = "Sunny",     color = Color3.fromRGB(190, 90, 240) },
	{ name = "Golden",    color = Color3.fromRGB(255, 200, 40) },
	{ name = "Radiant",   color = Color3.fromRGB(255, 80, 80) },
	{ name = "Sunburst",  color = Color3.fromRGB(255, 140, 30) },
	{ name = "Supernova", color = Color3.fromRGB(60, 230, 240) },
	{ name = "Prismatic", color = Color3.fromRGB(255, 110, 220) },
	{ name = "Lemonade",  color = Color3.fromRGB(255, 244, 90) },
}

-- Modifier definitions by category: ten tiers each, from a small nudge to a build-defining bonus.
-- Rungs 1-6 are unchanged from the six-tier ladder so every saved sword still parses by name.
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
			{ name = "Solar", bonus = 0.90, desc = "+90% Damage" },
			{ name = "Nova", bonus = 1.20, desc = "+120% Damage" },
			{ name = "Zenith", bonus = 1.60, desc = "+160% Damage" },
			{ name = "Squeezed", bonus = 2.20, desc = "+220% Damage" },
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
			{ name = "Reapers", bonus = 0.65, desc = "+65% Crit Chance" },
			{ name = "Oracles", bonus = 0.75, desc = "+75% Crit Chance" },
			{ name = "Fated", bonus = 0.85, desc = "+85% Crit Chance" },
			{ name = "Certain", bonus = 1.00, desc = "+100% Crit Chance" },
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
			{ name = "Skyline", bonus = 14, desc = "+14 Studs Reach" },
			{ name = "Stratos", bonus = 18, desc = "+18 Studs Reach" },
			{ name = "Orbital", bonus = 23, desc = "+23 Studs Reach" },
			{ name = "Boundless", bonus = 30, desc = "+30 Studs Reach" },
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
			{ name = "Comet", bonus = 240, desc = "+240 Knockback" },
			{ name = "Thunderclap", bonus = 320, desc = "+320 Knockback" },
			{ name = "Starfall", bonus = 420, desc = "+420 Knockback" },
			{ name = "Galactic", bonus = 550, desc = "+550 Knockback" },
		},
	},
}

-- Rarity decides how many modifier slots a sword gets and the shape of its BODY odds (rungs
-- 1-6). No rung is ever locked out: the long tail (7-10) is the same 1-in-N on every rarity.
-- body: the share of a slot's roll that lands on each of rungs 1..6, before the tail is
-- carved out (they sum to 1; the tail takes its 1-in-N off the top and the body fills the rest).
WeaponModifiers.RarityConfig = {
	Common    = { baseSlots = 0, bonusSlotChance = 0.20, body = { 0.550, 0.280, 0.110, 0.045, 0.014, 0.001 } },
	Uncommon  = { baseSlots = 1, bonusSlotChance = 0.15, body = { 0.360, 0.360, 0.170, 0.080, 0.0275, 0.0025 } },
	Rare      = { baseSlots = 2, bonusSlotChance = 0.10, body = { 0.140, 0.320, 0.320, 0.160, 0.055, 0.005 } },
	Epic      = { baseSlots = 3, bonusSlotChance = 0.05, body = { 0.050, 0.120, 0.300, 0.380, 0.140, 0.010 } },
	Legendary = { baseSlots = 4, bonusSlotChance = 0, body = { 0.020, 0.060, 0.140, 0.300, 0.460, 0.020 } },
}
-- bonusSlotChance: an ordinary extra slot (not Blessed) so even Common swords can carry a
-- modifier now and then. Blessed is on top of that and rolls its slot one rung higher.

-- The long tail, per rolled slot, at luck 1.0: 1 in N. [TUNING]
-- Sunburst 1 in 500, Supernova 1 in 5,000, Prismatic 1 in 50,000, Lemonade 1 in 500,000.
WeaponModifiers.TAIL_ONE_IN = { [7] = 500, [8] = 5000, [9] = 50000, [10] = 500000 }
-- Luck can never push a tail rung above this share of a slot (keeps 1-in-N honest at huge luck).
WeaponModifiers.TAIL_CAP = 0.25

-- Server-wide announcement: any roll whose best rung reaches this toasts every player.
WeaponModifiers.BROADCAST_TIER = 8

-- Luck: multiplies the odds of every tail rung (7-10). All of it is earned in play. [TUNING]
WeaponModifiers.Luck = {
	STREAK_PER_KILL = 0.02,  -- +0.02x per kill in the current streak...
	STREAK_MAX = 1.0,        -- ...up to +1.0x at a 50-kill streak
	STREAK_WINDOW = 25,      -- seconds between kills before the streak drops
	CHARGE_BONUS = 1.0,      -- one Lucky Charge (a boss kill) spent on a paid strike: +1.0x
	CHARGE_MAX = 9,          -- charges held at once
	REBIRTH_PER = 0.1,       -- +0.1x per rebirth...
	REBIRTH_MAX = 1.0,       -- ...up to +1.0x
	-- Standing luck earned from the wealth ladder (Config.WealthLadder rungs 4, 5, 6, 7 and 8).
	-- The whole ladder is worth +0.50x -- half of what five rebirths already give -- and it is
	-- earned by accumulating a fortune in play, never bought. TAIL_CAP still bounds the result.
	MILESTONE_MAX = 0.5,
	BLESSED_SLOT = 2.0,      -- the Blessed slot rolls its tail at twice the luck
}

-- Mutations: a whole-roll variant that multiplies every modifier's bonus. True odds: luck never
-- changes them, and they re-roll on every strike, so an Iced Golden can out-hit a plain Radiant.
WeaponModifiers.Variants = {
	{ name = "Iced",    oneIn = 40,   mult = 1.2, color = Color3.fromRGB(150, 225, 255) },
	{ name = "Sugared", oneIn = 300,  mult = 1.4, color = Color3.fromRGB(255, 225, 245) },
	{ name = "Sour",    oneIn = 2500, mult = 1.7, color = Color3.fromRGB(230, 255, 90) },
}
WeaponModifiers.VariantByName = {}
for _, v in ipairs(WeaponModifiers.Variants) do WeaponModifiers.VariantByName[v.name] = v end

-- Total luck multiplier from its parts. streak/charges/rebirths are counts; milestoneLuck is the
-- standing bonus the wealth ladder granted (player attribute MilestoneLuck, set by VaultSystem).
-- Returns the total and every part, so a UI can show where each one came from.
function WeaponModifiers.LuckFrom(streak: number?, spendCharge: boolean?, rebirths: number?, milestoneLuck: number?)
	local L = WeaponModifiers.Luck
	local streakBonus = math.min((tonumber(streak) or 0) * L.STREAK_PER_KILL, L.STREAK_MAX)
	local chargeBonus = spendCharge and L.CHARGE_BONUS or 0
	local rebirthBonus = math.min((tonumber(rebirths) or 0) * L.REBIRTH_PER, L.REBIRTH_MAX)
	local milestoneBonus = math.clamp(tonumber(milestoneLuck) or 0, 0, L.MILESTONE_MAX)
	return 1 + streakBonus + chargeBonus + rebirthBonus + milestoneBonus,
		streakBonus, chargeBonus, rebirthBonus, milestoneBonus
end

-- Probability of each rung (1..10) for one rolled slot of this rarity at this luck.
-- peakShift: the Blessed slot shifts the body up one rung and doubles its tail luck.
function WeaponModifiers.TierOdds(rarityName, peakShift, luck)
	local cfg = WeaponModifiers.RarityConfig[rarityName] or WeaponModifiers.RarityConfig.Common
	luck = math.max(tonumber(luck) or 1, 0)
	if (peakShift or 0) > 0 then luck *= WeaponModifiers.Luck.BLESSED_SLOT end
	local odds = {}
	local tailMass = 0
	for tier = WeaponModifiers.TIER_COUNT, WeaponModifiers.BODY_TIERS + 1, -1 do
		local p = math.min(luck / WeaponModifiers.TAIL_ONE_IN[tier], WeaponModifiers.TAIL_CAP)
		odds[tier] = p
		tailMass += p
	end
	local body = table.clone(cfg.body)
	if (peakShift or 0) > 0 then
		-- Blessed: each rung's share moves up one rung (the top rung keeps what lands on it).
		local shifted = { 0, 0, 0, 0, 0, 0 }
		for tier = 1, WeaponModifiers.BODY_TIERS do
			local to = math.min(tier + peakShift, WeaponModifiers.BODY_TIERS)
			shifted[to] += body[tier]
		end
		body = shifted
	end
	local bodyMass = math.max(1 - tailMass, 0)
	for tier = 1, WeaponModifiers.BODY_TIERS do
		odds[tier] = body[tier] * bodyMass
	end
	return odds
end

-- 1-in-N for a probability, rounded to something a player can read (nil for zero).
function WeaponModifiers.OneIn(p: number): number?
	if not p or p <= 0 then return nil end
	local n = 1 / p
	if n < 10 then return math.floor(n * 10 + 0.5) / 10 end
	if n < 1000 then return math.floor(n + 0.5) end
	local mag = 10 ^ (math.floor(math.log10(n)) - 2)
	return math.floor(n / mag + 0.5) * mag
end

-- "1 in 5,000" style text.
function WeaponModifiers.OneInText(p: number): string
	local n = WeaponModifiers.OneIn(p)
	if not n then return "never" end
	local s = n < 10 and string.format("%.1f", n):gsub("%.0$", "") or tostring(math.floor(n))
	if n >= 1000 then
		s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	end
	return "1 in " .. s
end

-- The full ladder for a rarity at a luck value, for the client's Odds popup: one row per rung
-- with its name, colour, probability and 1-in-N per slot, plus the chance that a whole strike
-- (all of the rarity's base slots) lands at least one modifier of that rung or better.
function WeaponModifiers.Ladder(rarityName, luck)
	local cfg = WeaponModifiers.RarityConfig[rarityName] or WeaponModifiers.RarityConfig.Common
	local odds = WeaponModifiers.TierOdds(rarityName, 0, luck)
	local slots = math.max(cfg.baseSlots, 1)
	local rows = {}
	local above = 0
	for tier = WeaponModifiers.TIER_COUNT, 1, -1 do
		above += odds[tier]
		local perStrike = 1 - (1 - above) ^ slots
		rows[tier] = {
			tier = tier, name = WeaponModifiers.Rungs[tier].name, p = odds[tier],
			oneIn = WeaponModifiers.OneIn(odds[tier]), oneInText = WeaponModifiers.OneInText(odds[tier]),
			atLeastPerStrike = perStrike, atLeastOneInText = WeaponModifiers.OneInText(perStrike),
		}
	end
	return rows
end

-- Studio capture only. The rare-forge capture (ReforgeSystem's "Motion:ForgeRare" stage, which
-- is gated on RunService:IsStudio()) sets this to a rung so the very next rolled slot lands
-- there, then it clears itself: one slot of one roll. Nothing outside that stage ever writes it,
-- and it changes no odds -- the slot still reports the real probability of the rung it landed on.
WeaponModifiers.ForceNextTier = nil

local function rollTier(rarityName, peakShift, luck)
	local odds = WeaponModifiers.TierOdds(rarityName, peakShift, luck)
	local forced = WeaponModifiers.ForceNextTier
	if forced then
		WeaponModifiers.ForceNextTier = nil
		return math.clamp(forced, 1, WeaponModifiers.TIER_COUNT), odds
	end
	local pick = math.random()
	-- Top down, so the tail is drawn first at exactly its 1-in-N.
	for tier = WeaponModifiers.TIER_COUNT, 1, -1 do
		pick -= odds[tier]
		if pick <= 0 then return tier, odds end
	end
	return 1, odds
end

local function rollVariant()
	-- Rarest first so a Sour is never masked by an Iced.
	for i = #WeaponModifiers.Variants, 1, -1 do
		local v = WeaponModifiers.Variants[i]
		if math.random() < 1 / v.oneIn then return v.name end
	end
	return nil
end

-- forceExtraSlot: a reroll of a Blessed sword keeps its Blessed slot instead of re-rolling it.
-- opts.luck: the luck multiplier for the tail (WeaponModifiers.LuckFrom). Defaults to 1.
-- Returns mods (each with tier, oneIn, p), gotExtraSlot, variantName.
function WeaponModifiers.RollModifiers(rarityName, blessedChanceBonus, forceExtraSlot, opts)
	opts = opts or {}
	local luck = tonumber(opts.luck) or 1
	local cfg = WeaponModifiers.RarityConfig[rarityName] or WeaponModifiers.RarityConfig.Common
	local count = cfg.baseSlots
	if math.random() < (cfg.bonusSlotChance or 0) then
		count += 1
	end
	local gotExtraSlot = false

	local bonus = typeof(blessedChanceBonus) == "number" and blessedChanceBonus or 0
	local blessedChance = math.clamp(WeaponModifiers.EXTRA_SLOT_CHANCE + bonus, 0, 1)
	if forceExtraSlot == true or math.random() < blessedChance then
		count += 1
		gotExtraSlot = true
	end

	-- Cap count at total available categories (one modifier per category)
	count = math.clamp(count, 0, 4)

	local variant = rollVariant()
	if count <= 0 then
		return {}, gotExtraSlot, variant
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
		-- The Blessed slot (last one rolled) peaks one rung higher and rolls its tail at double luck.
		local tierIdx, odds = rollTier(rarityName, (gotExtraSlot and i == count) and 1 or 0, luck)
		tierIdx = math.min(tierIdx, #catData.Tiers)
		local tierData = catData.Tiers[tierIdx]

		table.insert(rolled, {
			category = catKey,
			name = tierData.name,
			bonus = tierData.bonus,
			desc = tierData.desc,
			tier = tierIdx,
			p = odds[tierIdx],
			oneIn = WeaponModifiers.OneIn(odds[tierIdx]),
		})
	end

	return rolled, gotExtraSlot, variant
end

return WeaponModifiers
