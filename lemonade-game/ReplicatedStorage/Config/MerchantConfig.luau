-- ModuleScript | ReplicatedStorage.Config.MerchantConfig | THE BLACKSMITH SELLS ONE THING.
--
-- WHAT THE SHOP IS. The Relic Blacksmith has exactly ONE purchasable thing: a MYSTERY BLADE.
-- It is not a named listing. It is a sword ROLLED AT THE MOMENT YOU PAY, on the server, out of
-- the same BossWeapons pools every drop in the game comes from -- the pools that belong to the
-- level the buyer is standing at. There is no second item, no restock list, no stock counter and
-- no named sword on the counter. What the counter shows is the OFFER: which pools the roll runs
-- on, the real odds of every rarity, the damage band the blade can land in, and the price.
--
-- WHY IT REPLACED THE FIVE LISTINGS. The old shop was five fixed rows (Warlord / Frostfang /
-- Inferno / Voidrend / Titanforged) at five fixed prices. Measured (blacksmith r00): 300 buys per
-- row returned ONE sword and ONE base every time, so nothing was ever rolled; the cheapest row
-- cost 0.8 of a forge strike, so buying it was not a decision; the dearest row beat 100% of the
-- endgame zone's own drops, so the shop SOLD the endgame; and after 968,200 gold the whole shop
-- was bought out forever. Five of the game's 92 swords, eight of its thirteen pools never touched.
--
-- THE THREE RULES THIS MODULE ENCODES
--   1. ONE THING.   `MerchantConfig.OfferForLevel(level)` is the whole shop. There is no item list.
--   2. YOUR LEVEL.  The pools come from `BANDS` below: the zone you are farming now (70%) and the
--      pool of the last boss you could already have beaten (30%). The shop can never sell you a
--      blade out of a zone you have not reached, and it never sells the pool you have outgrown.
--   3. YOUR PRICE.  `PriceForLevel(level)` = PRICE_STRIKES x the forge-strike cost of a MEDIAN
--      blade out of that band, priced by Config.SwordValue's own formula. So the price is a pure
--      function of level, it is quoted in the one unit the player already spends gold in, and it
--      climbs with the zone exactly as the strike and the income do.
--
-- Everything here is deterministic: no math.random lives in this module. The roll itself is
-- MerchantSystem's, server-side, at purchase time. The odds published here ARE the odds rolled.
local BossWeapons = require(script.Parent:WaitForChild("BossWeapons"))
local SwordValue = require(script.Parent:WaitForChild("SwordValue"))
local GoldCurve = require(script.Parent:WaitForChild("GoldCurve"))
local WeaponModifiers = require(script.Parent:WaitForChild("WeaponModifiers"))

local MerchantConfig = {}

-- ---------------------------------------------------------------- the offer's terms
-- [TUNING] THE SHOP'S OWN RARITY LADDER. This is what you are actually buying: a drop ladder
-- better than the one an ordinary enemy rolls (trash 62 / 27 / 9 / 1.95 / 0.05) but with a
-- thinner Legendary top than a warden's (2.0%). You pay the blacksmith for CONSISTENCY -- a
-- middling roll instead of a bad one -- not for the jackpot. The jackpot stays with the bosses.
-- Sums to 1. These are the numbers the panel prints and the numbers the server rolls.
MerchantConfig.RarityOdds = {
	{ rarity = "Common", p = 0.380 },
	{ rarity = "Uncommon", p = 0.320 },
	{ rarity = "Rare", p = 0.200 },
	{ rarity = "Epic", p = 0.085 },
	{ rarity = "Legendary", p = 0.015 },
}

-- [TUNING] THE PRICE, in the only unit that already scales with the game: forge strikes.
-- A strike on the MEDIAN BLADE THIS BAND SELLS costs `StrikeRefForLevel(level)`, by SwordValue's
-- own formula; the blade costs this many of them.
--
-- WHY IT MOVED FROM 1.5 TO 8.0. 1.5 was fitted against a strike on the MEDIAN blade of the band.
-- That is not the sword anybody strikes. A player strikes the sword they are CARRYING, which is
-- the best of everything that zone has dropped them, and SwordValue prices a strike on the square
-- of the sword's own base -- so the strike they actually pay is 2.4x-3.4x the median reference.
-- Measured end to end (ledger r00, section 3): the blade came out CHEAPER than one strike in all
-- eight zones, an hour of the endgame bought 10 blades against 2.9 strikes, and the shop took 61%
-- of a spending player's gold while the forge -- the sink this economy is built around -- took
-- 33%. The cheapest thing on the menu was being bought first, every time, and it was the thing
-- that was supposed to be the alternative.
--
-- 8.0 is 1.5 divided by that measured 2.4x-3.4x gap and multiplied back out to land the blade at
-- roughly TWO strikes on the sword the player is really carrying, at every band. That is the
-- relationship the shop is meant to have: striking the sword in your hand is the ordinary thing
-- you do with gold, and buying a fresh roll out of the case is the occasional one you save for.
-- Section 3 of the r01 dossier prints the resulting minutes-per-purchase for both, at all eight
-- zones, so the ratio can be checked rather than believed.
MerchantConfig.PRICE_STRIKES = 8.0

-- [TUNING] Bad-luck floor. After this many purchases in a row that landed below PITY_FLOOR, the
-- next purchase is floored at PITY_FLOOR. Earned by playing, saved in the profile (merchantPity),
-- never bought. 8 was picked so the floor bites at about the 8% tail of the Common+Uncommon run
-- (0.70^8 = 5.8%): it rescues the genuinely unlucky and leaves the odds above honest.
MerchantConfig.PITY_PURCHASES = 8
MerchantConfig.PITY_FLOOR = "Rare"

-- Seconds between two purchases by one player. A remote guard, not a design gate.
MerchantConfig.PURCHASE_COOLDOWN = 1.0

-- Rolled stat jitter, as every drop gets (BossWeapons.STAT_JITTER, +-5%): a purchase is a drop.
MerchantConfig.JITTER = true

-- ---------------------------------------------------------------- what your level buys
-- [TUNING] THE BANDS. `minLevel` is the first level of the band. `pools` is the weighted set the
-- roll runs on, and it is the same sentence at every band:
--
--     THE ZONE YOU ARE STANDING IN (70%) AND THE BOSS THAT ZONE LEADS TO (30%).
--
-- So the blacksmith's pitch is "a piece of the boss you cannot kill yet" -- and it is bounded, by
-- construction. The boss pool's REGULAR swords sit under or across the zone's own lesser pool at
-- every band (Titan x5.80-13.38 against the Summit's x9.90-13.98), so buying can never hand a
-- player a frontier they have not reached. The only thing above the zone is that pool's Legendary,
-- at 1.5% x 30% = 0.45% a purchase -- slower than farming the boss himself for it. The opening
-- band has no boss pool at all: the first zone stays an on-ramp, not a lottery.
--
-- Level bands follow WorldLayout.ZONES' own spawn levels, so the shop and the map agree:
--   Iron Lowlands 1-3 | Briarwood 9-12, warden 14 | Frostbound 18-23, boss 25 | Marsh 24-27,
--   warden 29 | Caldera 34-41, boss 45 | Stormwatch 41-45, warden 48 | Void Rift 55-66, boss 70
--   | Celestial Summit 80-92, boss 100.
MerchantConfig.BANDS = {
	{ minLevel = 1, name = "Iron Lowlands", pools = {
		{ key = "IronLowlands", weight = 1.00 } } },
	{ minLevel = 9, name = "Briarwood", pools = {
		{ key = "Briarwood", weight = 0.70 }, { key = "Boss_Gorgon", weight = 0.30 } } },
	{ minLevel = 18, name = "Frostbound Glacier", pools = {
		{ key = "FrostboundGlacier", weight = 0.70 }, { key = "Boss_FrostRevenant", weight = 0.30 } } },
	{ minLevel = 24, name = "Sunken Marsh", pools = {
		{ key = "SunkenMarsh", weight = 0.70 }, { key = "Boss_FrostRevenant", weight = 0.30 } } },
	{ minLevel = 34, name = "Infernal Caldera", pools = {
		{ key = "InfernalCaldera", weight = 0.70 }, { key = "Boss_InfernalColossus", weight = 0.30 } } },
	{ minLevel = 41, name = "Stormwatch", pools = {
		{ key = "Stormwatch", weight = 0.70 }, { key = "Boss_InfernalColossus", weight = 0.30 } } },
	{ minLevel = 55, name = "Void Rift", pools = {
		{ key = "VoidRift", weight = 0.70 }, { key = "Boss_VoidWraith", weight = 0.30 } } },
	{ minLevel = 80, name = "Celestial Summit", pools = {
		{ key = "CelestialSummit", weight = 0.70 }, { key = "Boss_CelestialTitan", weight = 0.30 } } },
	{ minLevel = 100, name = "The Titan's Anvil", pools = {
		{ key = "CelestialSummit", weight = 0.50 }, { key = "Boss_CelestialTitan", weight = 0.50 } } },
}

MerchantConfig.MAX_LEVEL = 999

function MerchantConfig.BandForLevel(level: number?)
	local lv = math.clamp(math.floor(tonumber(level) or 1), 1, MerchantConfig.MAX_LEVEL)
	local band, index = MerchantConfig.BANDS[1], 1
	for i, row in ipairs(MerchantConfig.BANDS) do
		if lv >= row.minLevel then
			band, index = row, i
		end
	end
	return band, index, lv
end

-- ---------------------------------------------------------------- pool arithmetic (deterministic)
-- Every number below is read out of BossWeapons and Config.SwordValue. Nothing is a design figure.

-- Weight-normalised rows of a pool's regular swords, plus its Legendary.
local function poolParts(poolKey)
	local pool = BossWeapons.PoolFor(poolKey)
	if not pool then return nil end
	local total = 0
	for _, def in ipairs(pool.swords) do total += def.weight end
	return pool, total
end

-- Expected value of f(listedBase) over one pool at the shop's rarity ladder. `f` sees the base the
-- blade actually lists at that rarity (BossWeapons.BaseAt), which is what the factory stamps.
local function expectOverPool(poolKey, f)
	local pool, totalWeight = poolParts(poolKey)
	if not pool or totalWeight <= 0 then return 0 end
	local acc = 0
	for _, row in ipairs(MerchantConfig.RarityOdds) do
		if row.rarity == "Legendary" then
			acc += row.p * f(pool.legendary.base, "Legendary", pool.legendary)
		else
			for _, def in ipairs(pool.swords) do
				acc += row.p * (def.weight / totalWeight) * f(BossWeapons.BaseAt(def, row.rarity, false), row.rarity, def)
			end
		end
	end
	return acc
end

-- The damage band a pool can land in at the shop's ladder: the cheapest sword at Common, up to
-- the pool's Legendary. Stat jitter (+-5%) is applied on top by the factory, so the printed band
-- is the listed one and the dossier says so.
local function poolBaseRange(poolKey)
	local pool = poolParts(poolKey)
	if not pool then return 0, 0 end
	local lo, hi = math.huge, 0
	for _, def in ipairs(pool.swords) do
		if def.weight > 0 then -- 0-weight swords are spin-wheel only
			lo = math.min(lo, BossWeapons.BaseAt(def, "Common", false))
			hi = math.max(hi, BossWeapons.BaseAt(def, "Epic", false))
		end
	end
	hi = math.max(hi, pool.legendary.base)
	return lo, hi
end

-- What a forge strike costs on a sword of this listed base at this rarity, by SwordValue's own
-- formula, with a bare roll (quality 1). Measured against the shipped forge this lands within 7%
-- of the median strike the player is actually paying in that zone (dossier, r01).
local function strikeCost(baseMult, rarity)
	local base = SwordValue.PRICE_UNIT[rarity] or SwordValue.PRICE_UNIT.Common
	return base * SwordValue.powerFactor(baseMult)
end

local offerCache = {}

-- The expected forge-strike cost of a MEDIAN blade out of this band: the price's reference unit.
function MerchantConfig.StrikeRefForLevel(level: number?): number
	local band = MerchantConfig.BandForLevel(level)
	local acc, weightSum = 0, 0
	for _, entry in ipairs(band.pools) do
		weightSum += entry.weight
		acc += entry.weight * expectOverPool(entry.key, strikeCost)
	end
	if weightSum <= 0 then return 0 end
	return acc / weightSum
end

-- THE PRICE, as a pure function of level. Rounded to 10 gold, like every other price in the game,
-- and never lower than the band below it. The floor matters exactly once: the last band sells half
-- the Titan's own pool, whose CHEAP end (x5.80) sits under the Summit's lesser pool (x9.90), so
-- its raw reference comes out a shade below band 8's. A shop that got CHEAPER the moment you beat
-- the Titan would read as a bug, so the price is a running maximum down the band ladder.
local priceByBand = nil
local function buildPriceLadder()
	local ladder, running = {}, 0
	for i, band in ipairs(MerchantConfig.BANDS) do
		local raw = MerchantConfig.PRICE_STRIKES * MerchantConfig.StrikeRefForLevel(band.minLevel)
		running = math.max(running, math.floor(raw / 10 + 0.5) * 10)
		ladder[i] = running
	end
	return ladder
end

function MerchantConfig.PriceForLevel(level: number?): number
	priceByBand = priceByBand or buildPriceLadder()
	local _, index = MerchantConfig.BandForLevel(level)
	return math.max(10, priceByBand[index] or 10)
end

-- ---------------------------------------------------------------- the offer the player is shown
-- The whole shop, as one table. The server sends this; the client only renders it. Every field is
-- derived here from shipped config, so the panel cannot print an odd the server does not roll.
function MerchantConfig.OfferForLevel(level: number?)
	local band, index, lv = MerchantConfig.BandForLevel(level)
	local cached = offerCache[lv]
	if cached then return cached end

	local price = MerchantConfig.PriceForLevel(lv)
	local strikeRef = MerchantConfig.StrikeRefForLevel(lv)

	local pools, weightSum, swordCount = {}, 0, 0
	local minBase, maxBase, expectedBase = math.huge, 0, 0
	for _, entry in ipairs(band.pools) do
		local pool = BossWeapons.PoolFor(entry.key)
		if pool then
			weightSum += entry.weight
			local lo, hi = poolBaseRange(entry.key)
			minBase, maxBase = math.min(minBase, lo), math.max(maxBase, hi)
			expectedBase += entry.weight * expectOverPool(entry.key, function(b) return b end)
			-- a 0-weight sword is spin-wheel only (BossWeapons wardenEpics): the shop never sells it
			local sellable = 0
			for _, def in ipairs(pool.swords) do
				if def.weight > 0 then sellable += 1 end
			end
			swordCount += sellable + 1
			table.insert(pools, {
				key = entry.key,
				name = BossWeapons.PoolName(entry.key),
				lesser = BossWeapons.IsLesserPool(entry.key),
				weight = entry.weight,
				swords = sellable + 1,
				minBase = lo,
				maxBase = hi,
				legendaryName = pool.legendary.name,
				legendaryBase = pool.legendary.base,
			})
		end
	end
	if weightSum > 0 then expectedBase /= weightSum end
	if minBase == math.huge then minBase = 0 end

	-- Per-rarity rows: the real odds, and the damage band that rarity can land in across the band.
	local rarityRows = {}
	for _, row in ipairs(MerchantConfig.RarityOdds) do
		local lo, hi = math.huge, 0
		for _, entry in ipairs(band.pools) do
			local pool = poolParts(entry.key)
			if pool then
				if row.rarity == "Legendary" then
					lo, hi = math.min(lo, pool.legendary.base), math.max(hi, pool.legendary.base)
				else
					for _, def in ipairs(pool.swords) do
						local b = BossWeapons.BaseAt(def, row.rarity, false)
						lo, hi = math.min(lo, b), math.max(hi, b)
					end
				end
			end
		end
		table.insert(rarityRows, {
			rarity = row.rarity, p = row.p,
			minBase = lo == math.huge and 0 or lo, maxBase = hi,
			oneIn = row.p > 0 and math.floor(1 / row.p + 0.5) or 0,
		})
	end

	local perKill = GoldCurve.PerKill(lv, "minion")
	local offer = {
		level = lv,
		bandIndex = index,
		bandName = band.name,
		bandMinLevel = band.minLevel,
		bandMaxLevel = MerchantConfig.BANDS[index + 1] and (MerchantConfig.BANDS[index + 1].minLevel - 1) or nil,
		price = price,
		priceStrikes = MerchantConfig.PRICE_STRIKES,
		strikeRef = math.floor(strikeRef + 0.5),
		priceKills = perKill > 0 and math.ceil(price / perKill) or 0,
		goldPerKill = perKill,
		pools = pools,
		rarityOdds = rarityRows,
		minBase = minBase,
		maxBase = maxBase,
		expectedBase = expectedBase,
		swordCount = swordCount,
		rosterCount = BossWeapons.CountSwords(),
		prefixSlots = WeaponModifiers.BASE_SLOTS, -- every blade rolls the buyer's own slots (1 by default)
		prefixCeiling = WeaponModifiers.MaxTierForLevel(lv),
		prefixCeilingName = WeaponModifiers.CeilingName(lv), -- the bracket's chase; MerchantSystem hides it as "??"
		jitter = BossWeapons.STAT_JITTER,
		pityPurchases = MerchantConfig.PITY_PURCHASES,
		pityFloor = MerchantConfig.PITY_FLOOR,
	}
	offerCache[lv] = offer
	return offer
end

-- Pick a pool by weight. `rng` is math.random by default; the server passes its own so the roll
-- stays server-side and a harness can drive it deterministically.
function MerchantConfig.RollPool(level: number?, rng): string
	local band = MerchantConfig.BandForLevel(level)
	local total = 0
	for _, entry in ipairs(band.pools) do total += entry.weight end
	local r = ((rng or math.random)()) * total
	for _, entry in ipairs(band.pools) do
		r -= entry.weight
		if r <= 0 then return entry.key end
	end
	return band.pools[#band.pools].key
end

-- THE PURCHASE, as one pair of arguments. MerchantSystem hands these straight to
-- BossSwordFactory.build, and so does every measurement harness, so a measured roll can never be
-- a copy of the shipped roll -- it IS the shipped roll.
-- slots: the buyer's prefix slots (WeaponModifiers.SlotsOf); the blade's prefix rolls at `level`.
function MerchantConfig.RollArgs(level: number?, pityCount: number?, rng, slots: number?)
	local poolKey = MerchantConfig.RollPool(level, rng)
	local floor = nil
	if (tonumber(pityCount) or 0) >= MerchantConfig.PITY_PURCHASES then
		floor = MerchantConfig.PITY_FLOOR
	end
	return poolKey, {
		level = tonumber(level) or 1,
		slots = WeaponModifiers.ClampSlots(slots),
		rarityOdds = MerchantConfig.RarityOdds,
		rarityFloor = floor,
		jitter = MerchantConfig.JITTER,
	}, floor
end

return MerchantConfig
