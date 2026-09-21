-- ModuleScript | ReplicatedStorage.Config.WealthLadder | BEING RICH HAS TO BE WORTH SOMETHING.
--
-- WHY THIS EXISTS. The game already computed a Wealth number (VaultSystem sums SwordValue ratings
-- across everything carried and stored, and publishes it as a leaderstat). Measured (r00): 171
-- scripts in the DataModel, ZERO of them reacted to it. Nothing was earned by being rich; the
-- number was a private score on a leaderboard.
--
-- Blox Fruits hangs money titles off its purse -- The Rich at 5M, Unlimited Money at 20M, The
-- Richest in the World at 50M -- so a big number is a thing other players can see. Dungeon Quest
-- does the same job with gear: what you are holding IS your standing. This ladder is ours, in our
-- own voice, and it is hung on a number that means the same thing as a price.
--
-- ── FORTUNE: ONE NUMBER, IN GOLD ─────────────────────────────────────────────────────────────
-- The Wealth pill is a rating sum, and a rating point was measured to be worth 4.5 gold in
-- Briarwood and 148.0 gold on the Celestial Summit -- a x33 spread (r00, section 2). A rung
-- threshold written in rating points would therefore mean something different in every zone, and
-- could not be compared with a slot price, a forge strike or an hour of income.
--
-- So the ladder runs on FORTUNE, which is net worth in gold and nothing else:
--
--     Fortune = gold in the purse
--             + what every carried relic would sell for      (SellValue.Gold, the game's one price)
--             + what every STORED relic would sell for, x STORED_APPRAISAL
--
-- Two properties this has on purpose:
--
--   * IT IS COMPARABLE WITH A PRICE. "Golden Grove at 1,000,000" sits beside "this slot costs
--     46,800" and "a Summit forge strike costs 82,570" in the same unit, so the ladder can be
--     checked against the income curve instead of taken on faith.
--   * STORING BEATS SELLING. A sword counts at its exact sale price while carried, so selling it
--     is Fortune-neutral -- but the Vaultkeeper APPRAISES what she holds at STORED_APPRAISAL of
--     that, so the same sword is worth a quarter more once it is on her shelf. That is the whole
--     answer to "why keep it": selling converts a sword into gold at par, keeping it and storing
--     it is the only way to hold more than par, and it keeps the sword. No gold is created by
--     this -- the appraisal moves a score, never a purse.
--
-- ── THE RULES OF THE LADDER ──────────────────────────────────────────────────────────────────
--   * Rungs are earned ONCE, at the moment the server sees the fortune, and persist in the
--     profile (`wealthRung`). Spending the money afterwards never takes a rung back -- that is
--     the point: it must be safe to spend, or a title would be a reason not to play.
--   * Every rung is reachable without paying anything. There is no Robux path to any of this.
--   * The rewards are status and convenience, never damage: titles other players can read over
--     your head, free vault shelves, a shorter wait on the anvil's free strike, and a small
--     standing luck that only ever multiplies the long tail (WeaponModifiers.TAIL_CAP still
--     bounds it). The full ladder is worth +0.50 luck -- half of what five rebirths already give
--     for free, and a quarter of a single Lucky Charge plus a full kill streak.
local WealthLadder = {}

-- [TUNING] The Vaultkeeper's appraisal on what she is holding. 1.25 was picked so that storing a
-- sword beats selling it by a clear quarter without making the vault a gold printer (it is a
-- score, not a purse) and without making a full vault dominate the ladder: a 60-slot vault of
-- Summit Legendaries appraises at about 1.25 x 60 x 13,487 = 1.01M, which is rung 4 of 8.
WealthLadder.STORED_APPRAISAL = 1.25

-- [TUNING] THE RUNGS.
--
-- thresholds are FORTUNE in gold. They were fitted against the measured net worth of a player at
-- each band (r00 section 4, one hour in a zone carrying that zone's own gear): Iron Lowlands
-- 12,690 | Briarwood 24,922 | Frostbound 61,844 | Sunken Marsh 70,624 | Infernal Caldera 164,044
-- | Stormwatch 171,212 | Void Rift 501,258 | Celestial Summit 1,035,131 -- and against measured
-- income 7,721/h -> 778,639/h. Section 4 of the r01 dossier prints which rung a typical player
-- holds at low, mid and high level, and what each reward is worth in gold.
--
-- reward fields, all optional:
--   slots        free vault shelves granted (they count against VaultConfig.MAX_SLOTS and skip
--                the player past the dearest rungs of the slot ladder)
--   luck         standing long-tail luck added to every drop roll and every forge strike
--   freeStrike   seconds off the anvil's free-strike wait (ReforgeSystem.FREE_INTERVAL)
--   trim         the Vaultkeeper's chest cosmetic this rung unlocks (VaultGui reads it)
WealthLadder.Rungs = {
	{
		id = "first_jar", name = "First Jar", threshold = 10000,
		blurb = "Your first proper pile. The Vaultkeeper opens a shelf for you.",
		slots = 1, trim = "Copper",
	},
	{
		id = "full_pitcher", name = "Full Pitcher", threshold = 50000,
		blurb = "Enough put by that the stand stays open in the rain.",
		trim = "Brass", freeStrike = 15 * 60,
	},
	{
		id = "sweet_stand", name = "Sweet Stand", threshold = 250000,
		blurb = "A name worth painting on the awning.",
		slots = 1, trim = "Silver",
	},
	{
		id = "golden_grove", name = "Golden Grove", threshold = 1000000,
		blurb = "A million. The grove behind the stand is yours.",
		trim = "Gold", freeStrike = 15 * 60, luck = 0.10,
	},
	{
		id = "sunlit_reserve", name = "Sunlit Reserve", threshold = 5000000,
		blurb = "Five million on the shelf and the keeper calls you by name.",
		slots = 1, trim = "Sunlit", luck = 0.10,
	},
	{
		id = "orchard_keeper", name = "Orchard Keeper", threshold = 15000000,
		blurb = "Every tree on the bright coast has your mark on it.",
		slots = 1, trim = "Amber", luck = 0.10, freeStrike = 15 * 60,
	},
	{
		id = "bright_coast_baron", name = "Baron of the Bright Coast", threshold = 40000000,
		blurb = "The harbour prices its lemons by what you paid last.",
		slots = 1, trim = "Regal", luck = 0.10,
	},
	{
		id = "sun_vault", name = "The Sun Vault", threshold = 100000000,
		blurb = "A hundred million. They built a second door just for your shelf.",
		trim = "Sun", luck = 0.10, freeStrike = 15 * 60,
	},
}

WealthLadder.RUNG_COUNT = #WealthLadder.Rungs

-- The highest rung index a fortune of this size has reached (0 = none yet).
function WealthLadder.RungFor(fortune: number?): number
	local value = tonumber(fortune) or 0
	local rung = 0
	for index, entry in ipairs(WealthLadder.Rungs) do
		if value >= entry.threshold then rung = index else break end
	end
	return rung
end

-- Everything a player who has reached `rung` has earned from the ladder, summed.
function WealthLadder.PerksFor(rung: number?)
	local top = math.clamp(math.floor(tonumber(rung) or 0), 0, WealthLadder.RUNG_COUNT)
	local perks = { slots = 0, luck = 0, freeStrike = 0, trim = nil, title = nil, rung = top }
	for index = 1, top do
		local entry = WealthLadder.Rungs[index]
		perks.slots += entry.slots or 0
		perks.luck += entry.luck or 0
		perks.freeStrike += entry.freeStrike or 0
		if entry.trim then perks.trim = entry.trim end
		perks.title = entry.name
	end
	return perks
end

-- The rung a player is climbing towards, or nil when the ladder is finished.
function WealthLadder.NextRung(rung: number?)
	local top = math.clamp(math.floor(tonumber(rung) or 0), 0, WealthLadder.RUNG_COUNT)
	return WealthLadder.Rungs[top + 1]
end

-- FORTUNE, from parts the caller has already summed. Kept here so the server, the vault UI and
-- any measurement harness all add net worth up the same way.
--   gold     the purse
--   carried  what the carried relics would sell for, at goldMult 1
--   stored   what the stored relics would sell for, at goldMult 1
function WealthLadder.Fortune(gold: number?, carried: number?, stored: number?): number
	local purse = math.max(0, tonumber(gold) or 0)
	local onHand = math.max(0, tonumber(carried) or 0)
	local shelf = math.max(0, tonumber(stored) or 0)
	return math.floor(purse + onHand + shelf * WealthLadder.STORED_APPRAISAL)
end

-- Short label, same style as the rest of the HUD.
function WealthLadder.short(value: number?): string
	local v = math.max(0, math.floor(tonumber(value) or 0))
	if v >= 1e9 then return string.format("%.2fB", v / 1e9) end
	if v >= 1e6 then return string.format("%.2fM", v / 1e6) end
	if v >= 1e4 then return string.format("%.0fK", v / 1e3) end
	if v >= 1e3 then return string.format("%.1fK", v / 1e3) end
	return tostring(v)
end

return WealthLadder
