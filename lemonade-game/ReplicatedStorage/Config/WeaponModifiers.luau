-- ModuleScript | ReplicatedStorage.Config.WeaponModifiers | Sword prefixes: slots, rungs and odds.
--
-- ONE PREFIX SLOT. Every sword rolls exactly WeaponModifiers.BASE_SLOTS (1) prefix. More slots are
-- a player upgrade, not a sword property: SlotUnlocks below lists the 2nd and 3rd slot (level /
-- rebirth gate + a gold price anchored to GoldCurve), the upgrade shop sells them, and the count
-- lives on the player attribute PrefixSlots (SaveConfig.ATTRIBUTES). A sword rolled while the
-- player owns N slots rolls N prefixes; a sword whose save carries more prefixes than the player
-- owns (a pre-rework Blessed or four-slot Legendary) keeps all of them in StoredPrefixes but only
-- its strongest N are active (CollapsePrefixes) -- unlocking a slot wakes the next one up.
--
-- THE ODDS. Ten rungs per category, rolled from a HAND-AUTHORED odds row: one row per sword
-- rarity for each of eight level brackets (OddsBrackets, Lv 1/5/10/18/25/35/55/80), the way every
-- zone egg carries its own pet list. A bracket is a pool: its ordinary rungs, plus its own NAMED
-- CHASE one rung above them (Lemondrop at Lv 1, Sherbet, Honeysuckle, Slushie, Limeade, Marmalade,
-- Starfizz, and the Lemonade at Lv 80). Rungs above the chase have weight exactly 0 (why a level-3
-- player cannot land a top-tier Supernova / Prismatic / Lemonade), and the plainest rung retires at
-- Lv 25, 55 and 80. Each number is set by hand: the rung a bracket opens is common early and
-- scarcer as you climb (Fizzy 3.2% on a Lv 1 Common, Prismatic 0.6% on a Lv 55 Common) -- but not on
-- a smooth slope: each pool has a mood (below), so Briarwood and the Caldera hand out their new rung
-- more freely than the pool before them, and the camps and the Marsh are stingy -- and every
-- chase is "??" on every odds display until the player's first, has a flat rate that gets rarer
-- every bracket in uneven steps set per pool (Common 1 in 400, 750, 900, 1,250, 2,000, 2,300, 3,300,
-- then the Lemonade at 1 in 6,000; Legendary 180 .. 1,200, then 3,400), and is announced to the whole
-- server (TagFor). A chase's STAT sits one notch above the NEXT pool's new Nice rung (Lemondrop +45%
-- Damage: above Lv 5's +35% Devastating, under Lv 10's +50% Godly), so it is best-in-slot for about
-- one bracket and then a plain roll overtakes it and the next pool's chase takes over the pull
-- (bestUntil). Only Starfizz and the Lemonade, past the ladder's end, are never matched. Earned luck
-- lifts ordinary rungs 7-9 a little (LUCK_WEIGHT), never the wall and never
-- a chase. Every odds number the player sees comes from TierOdds / Ladder, the same function the
-- server rolls with.
local GoldCurve = require(script.Parent:WaitForChild("GoldCurve"))

local WeaponModifiers = {}

WeaponModifiers.TIER_COUNT = 10
WeaponModifiers.TOP_TIER_FROM = 8 -- rungs 8-10 (Supernova, Prismatic, and the Limeade / Marmalade / Starfizz / Lemonade chases) are "top tier"

-- The rung names and colours the player sees on the ladder (odds table, reveal band, loot card).
-- The prefix names below are what lands on the sword ("Nova Astral Eclipse").
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
-- Names never change, so every saved sword still parses by name.
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

-- Name -> { category, tier, bonus, desc } for every prefix (saved swords store names).
WeaponModifiers.ModByName = {}
for category, data in pairs(WeaponModifiers.Categories) do
	for tier, entry in ipairs(data.Tiers) do
		WeaponModifiers.ModByName[entry.name] = {
			category = category, name = entry.name, tier = tier, bonus = entry.bonus, desc = entry.desc,
		}
	end
end

-- ---------------------------------------------------------------- prefix slots
-- [TUNING] Every sword has one prefix slot. More are unlocked per player, in order.
WeaponModifiers.BASE_SLOTS = 1
WeaponModifiers.MAX_SLOTS = 3
-- The unlock path. price = killsOfGold x GoldCurve.PerKill(minLevel): the slot costs that many
-- minion kills' worth of gold at the level it opens, so it is a goal a player saves toward in the
-- zone where it unlocks, not a Robux gate. Sold by the upgrade shop (server-checked there).
WeaponModifiers.SlotUnlocks = {
	[2] = { minLevel = 30, rebirths = 0, killsOfGold = 600 },
	[3] = { minLevel = 60, rebirths = 1, killsOfGold = 1500 },
}

function WeaponModifiers.SlotUnlockPrice(slot: number): number?
	local row = WeaponModifiers.SlotUnlocks[slot]
	if not row then return nil end
	local raw = row.killsOfGold * GoldCurve.PerKill(row.minLevel, "minion")
	local mag = 10 ^ math.max(math.floor(math.log10(raw)) - 1, 0)
	return math.floor(raw / mag + 0.5) * mag
end

-- The slot count a player owns (attribute PrefixSlots, persisted), clamped to the real range.
function WeaponModifiers.ClampSlots(slots: any): number
	return math.clamp(math.floor(tonumber(slots) or WeaponModifiers.BASE_SLOTS), WeaponModifiers.BASE_SLOTS,
		WeaponModifiers.MAX_SLOTS)
end

function WeaponModifiers.SlotsOf(player: Instance?): number
	if typeof(player) ~= "Instance" then return WeaponModifiers.BASE_SLOTS end
	return WeaponModifiers.ClampSlots(player:GetAttribute("PrefixSlots"))
end

-- The next slot a player could unlock and whether they may buy it now. The server re-checks
-- every field before charging; the client only displays this. Returns nil at MAX_SLOTS.
function WeaponModifiers.NextSlotUnlock(slotsNow: number?, level: number?, rebirths: number?, gold: number?)
	local slot = WeaponModifiers.ClampSlots(slotsNow) + 1
	local row = WeaponModifiers.SlotUnlocks[slot]
	if not row then return nil end
	local price = WeaponModifiers.SlotUnlockPrice(slot)
	local lv, rb, g = tonumber(level) or 1, tonumber(rebirths) or 0, tonumber(gold) or 0
	local reason = nil
	if lv < row.minLevel then
		reason = string.format("Reach level %d", row.minLevel)
	elseif rb < row.rebirths then
		reason = string.format("Rebirth %d required", row.rebirths)
	elseif g < price then
		reason = "Not enough gold"
	end
	return { slot = slot, minLevel = row.minLevel, rebirths = row.rebirths, price = price,
		ready = reason == nil, reason = reason }
end

-- Keep a sword's strongest `slots` prefixes active. prefixes: the comma list saved on the sword
-- (StoredPrefixes if present, else Prefixes). Returns the active mod list (strongest first, ties
-- keep their saved order) and the full list as a comma string (what StoredPrefixes holds).
function WeaponModifiers.CollapsePrefixes(prefixes: string?, slots: number?)
	local all = {}
	for word in string.gmatch(prefixes or "", "[^,%s]+") do
		local info = WeaponModifiers.ModByName[word]
		if info then table.insert(all, info) end
	end
	local fullNames = {}
	for _, m in ipairs(all) do table.insert(fullNames, m.name) end
	local ranked = table.clone(all)
	for i, m in ipairs(ranked) do m = table.clone(m); m.order = i; ranked[i] = m end
	table.sort(ranked, function(a, b)
		if a.tier ~= b.tier then return a.tier > b.tier end
		return a.order < b.order
	end)
	local keep = WeaponModifiers.ClampSlots(slots)
	local active, seen = {}, {}
	for _, m in ipairs(ranked) do
		if #active >= keep then break end
		if not seen[m.category] then -- one prefix per category, as rolled
			seen[m.category] = true
			m.order = nil
			table.insert(active, m)
		end
	end
	return active, table.concat(fullNames, ", ")
end

-- ---------------------------------------------------------------- the odds brackets
-- [TUNING] HAND-AUTHORED, like a zone egg's pet list: one odds row per sword rarity for each level
-- bracket, not a formula. Each bracket is the pool a player of that level rolls from:
--   * top    the strongest ordinary rung in the pool. The bracket's CHASE sits one rung above it
--            (top + 1) and everything higher has weight exactly 0 (the hard wall: a level-3 player's
--            pool has Fresh / Zesty / Fizzy and the Lemondrop chase, never Supernova / Prismatic /
--            Lemonade).
--   * floor  the weakest rung still in the pool. The plainest rung RETIRES at Lv 25, 55 and 80, so
--            every bracket is a new pool, not the old one with a longer tail.
--   * rows   percent odds per rarity for the ordinary rungs, floor rung first, summing to exactly
--            100. Each is its own number, set by hand: the rung a bracket OPENS starts high near the
--            start of the game and gets scarcer as you climb (Fizzy 3.2% on a Common at Lv 1, the
--            first top-tier Supernova 1.2% at Lv 35, Prismatic 0.6% at Lv 55), the one the bracket
--            before opened steps up, and the top tier stays loud (Lv 80: 5% Common .. 8% Legendary).
--   * chase  the bracket's own named prize, "??" on every odds display until the player's first:
--            one prefix with its own name, stat and colour, a flat 1 in N per rarity that gets
--            rarer every bracket (Lemondrop 1 in 400 on a Lv 1 Common .. Lemonade 1 in 6,000 on a
--            Lv 80 Common), announced to the whole server. Its odds come out of the floor rung.
--            Luck never moves a chase. The last two steps are steep on purpose (Legendary: Marmalade
--            1 in 700 -> Starfizz 1 in 1,200 -> Lemonade 1 in 3,400), and the Lemonade on ANY rarity
--            is rarer than every earlier chase on ANY rarity, so the final prize always costs the most.
--            Its stat sits one notch above the next pool's new Nice rung and under the rung after it
--            (checked below): it beats the next zone's Nice roll, then is overtaken a bracket later,
--            so every zone's spins stay worth it. Its flavor line says what the drink does.
--   * mood   why this pool's numbers are what they are (a design note; the table is the truth).
--            GENEROUS pools (Briarwood Lv 10, Infernal Caldera Lv 35) open their new rung MORE
--            freely than the pool before and take only a small step on the chase (x1.2 / x1.15);
--            STINGY pools (the camps Lv 5, Sunken Marsh Lv 25) open theirs sparingly and jump the
--            chase (x1.9 / x1.6). So a new zone can feel like a windfall or a grind, never the same
--            slope twice; the last step to the Lemonade is the biggest (x1.8 on a Common, x2.8 on a
--            Legendary) and it is still under ~4,200 spins of the Summit wheel.
WeaponModifiers.OddsBrackets = {
	{ level = 1, where = "Iron Lowlands", mood = "first", floor = 1, top = 3, rows = {
		Common    = { 71.8, 25, 3.2 },
		Uncommon  = { 66.2, 30, 3.8 },
		Rare      = { 60.5, 35, 4.5 },
		Epic      = { 55.5, 39, 5.5 },
		Legendary = { 50, 43, 7 },
	}, chase = { name = "Lemondrop", category = "Damage", bonus = 0.45, desc = "+45% Damage",
		flavor = "a sour candy punch in every swing", color = Color3.fromRGB(225, 250, 110),
		oneIn = { Common = 400, Uncommon = 340, Rare = 300, Epic = 240, Legendary = 180 } } },
	{ level = 5, where = "Iron Lowlands camps", mood = "stingy", floor = 1, top = 4, rows = {
		Common    = { 67.8, 23, 7, 2.2 },
		Uncommon  = { 61.4, 26, 10, 2.6 },
		Rare      = { 55.8, 29, 12, 3.2 },
		Epic      = { 50.1, 32, 14, 3.9 },
		Legendary = { 44.2, 36, 15, 4.8 },
	}, chase = { name = "Sherbet", category = "CritChance", bonus = 0.45, desc = "+45% Crit Chance",
		flavor = "fizzes on contact: sherbet-sharp crits", color = Color3.fromRGB(255, 165, 150),
		oneIn = { Common = 750, Uncommon = 600, Rare = 520, Epic = 380, Legendary = 300 } } },
	{ level = 10, where = "Briarwood", mood = "generous", floor = 1, top = 5, rows = {
		Common    = { 61.6, 22, 8, 6, 2.4 },
		Uncommon  = { 55.1, 24, 10, 8, 2.9 },
		Rare      = { 48.5, 26, 12, 10, 3.5 },
		Epic      = { 41.7, 28, 14, 12, 4.3 },
		Legendary = { 34.8, 30, 16, 14, 5.2 },
	}, chase = { name = "Honeysuckle", category = "Range", bonus = 12, desc = "+12 Studs Reach",
		flavor = "honey vines stretch your swing", color = Color3.fromRGB(255, 215, 120),
		oneIn = { Common = 900, Uncommon = 720, Rare = 560, Epic = 450, Legendary = 320 } } },
	{ level = 18, where = "Frostbound Glacier", mood = "steady", floor = 1, top = 6, rows = {
		Common    = { 57.5, 20, 9, 7, 5, 1.5 },
		Uncommon  = { 50.1, 22, 11, 8.5, 6.5, 1.9 },
		Rare      = { 43.2, 24, 12.5, 10, 8, 2.3 },
		Epic      = { 36.6, 25, 14, 12, 9.5, 2.9 },
		Legendary = { 29.5, 26, 15, 14, 12, 3.5 },
	}, chase = { name = "Slushie", category = "Knockback", bonus = 280, desc = "+280 Knockback",
		flavor = "a brain-freeze blast that sends them sliding", color = Color3.fromRGB(140, 220, 255),
		oneIn = { Common = 1250, Uncommon = 1000, Rare = 800, Epic = 640, Legendary = 450 } } },
	{ level = 25, where = "Sunken Marsh", mood = "stingy", floor = 2, top = 7, rows = { -- Fresh retires
		Common    = { 54.9, 19, 10, 9, 6, 1.1 },
		Uncommon  = { 48.65, 21, 12, 10.5, 6.5, 1.35 },
		Rare      = { 42.3, 22, 13.5, 12, 8.5, 1.7 },
		Epic      = { 35.8, 23, 15, 13.5, 10.5, 2.2 },
		Legendary = { 29.2, 23, 17, 15, 13, 2.8 },
	}, chase = { name = "Limeade", category = "CritChance", bonus = 0.80, desc = "+80% Crit Chance",
		flavor = "a tart lime twist on nearly every hit", color = Color3.fromRGB(150, 240, 90),
		oneIn = { Common = 2000, Uncommon = 1500, Rare = 1200, Epic = 900, Legendary = 620 } } },
	{ level = 35, where = "Infernal Caldera", mood = "generous", floor = 2, top = 8, rows = { -- first top-tier rung
		Common    = { 48.8, 18, 11, 9.5, 6.5, 5, 1.2 },
		Uncommon  = { 42, 20, 12.5, 11, 7.5, 5.5, 1.5 },
		Rare      = { 35.1, 21, 14, 12.5, 9, 6.5, 1.9 },
		Epic      = { 28.05, 21.5, 15.5, 14, 11, 7.5, 2.45 },
		Legendary = { 22, 20, 17.5, 15.5, 13.5, 8.5, 3 },
	}, chase = { name = "Marmalade", category = "Damage", bonus = 1.90, desc = "+190% Damage",
		flavor = "thick-cut and heavy: every hit lands like a jar", color = Color3.fromRGB(255, 130, 40),
		oneIn = { Common = 2300, Uncommon = 1800, Rare = 1400, Epic = 1100, Legendary = 700 } } },
	{ level = 55, where = "Void Rift", mood = "steady", floor = 3, top = 9, rows = { -- Zesty retires
		Common    = { 52.2, 16, 12, 9, 8, 2.2, 0.6 },
		Uncommon  = { 46.55, 17.5, 13, 10.5, 9, 2.7, 0.75 },
		Rare      = { 40.3, 18.5, 14.5, 12.5, 10, 3.2, 1 },
		Epic      = { 34.6, 19, 16, 14, 11.5, 3.6, 1.3 },
		Legendary = { 29.4, 19.5, 17, 15.5, 13, 3.9, 1.7 },
	}, chase = { name = "Starfizz", category = "Knockback", bonus = 760, desc = "+760 Knockback",
		flavor = "pops foes clean into orbit", color = Color3.fromRGB(190, 150, 255),
		oneIn = { Common = 3300, Uncommon = 2700, Rare = 2200, Epic = 1700, Legendary = 1200 } } },
	{ level = 80, where = "Celestial Summit", mood = "last", floor = 4, top = 9, rows = { -- Fizzy retires; Lemonade is the chase
		Common    = { 57, 16.5, 12, 9.5, 3.2, 1.8 },
		Uncommon  = { 53.7, 17, 13, 10.5, 3.7, 2.1 },
		Rare      = { 49.4, 17.5, 14.5, 12, 4.1, 2.5 },
		Epic      = { 45.3, 18, 16, 13.5, 4.4, 2.8 },
		Legendary = { 41.5, 18.5, 17, 15, 4.8, 3.2 },
	}, chase = { name = "Lemonade", category = "Damage", bonus = 3.50, desc = "+350% Damage",
		flavor = "the whole squeeze: nothing hits harder", color = Color3.fromRGB(255, 244, 90),
		oneIn = { Common = 6000, Uncommon = 5000, Rare = 4200, Epic = 3800, Legendary = 3400 } } },
}
WeaponModifiers.RARITY_NAMES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- Every row is checked once at load: the right length, exactly 100%, and a chase that fits inside
-- its floor rung and gets rarer every bracket; every chase's stat one notch above the next pool's new
-- Nice rung (past the ladder's end, above rung 10); and the last chase rarer on every
-- rarity than every earlier chase on any rarity. A typo in a hand-tuned table fails loudly here
-- instead of quietly skewing the odds the player is shown.
function WeaponModifiers.RungBonus(category: string, tier: number): number
	local tiers = WeaponModifiers.Categories[category].Tiers
	local n = #tiers
	if tier <= n then return tiers[tier].bonus end
	return tiers[n].bonus * (tiers[n].bonus / tiers[n - 1].bonus) ^ (tier - n)
end
do
	local lastOneIn = {}
	local brackets = WeaponModifiers.OddsBrackets
	local earliestHardest = 0
	for i, b in ipairs(brackets) do
		-- The chase's stat sits one notch above the NEXT pool's new Nice rung and below the rung after
		-- it: best-in-slot through the next bracket, then overtaken when that rung opens. Where no
		-- ordinary rung can follow (the ladder ends), it sits above rung 10 and is never matched.
		local nb, cat = brackets[i + 1], b.chase.category
		local nextNew = nb and nb.top > b.top and nb.top or nil
		if nextNew and nextNew < WeaponModifiers.TIER_COUNT then
			assert(b.chase.bonus > WeaponModifiers.RungBonus(cat, nextNew)
				and b.chase.bonus < WeaponModifiers.RungBonus(cat, nextNew + 1),
				string.format("OddsBrackets Lv %d: chase %s must sit between the next pool's Nice rung and the one after",
					b.level, b.chase.name))
		else
			assert(b.chase.bonus > WeaponModifiers.RungBonus(cat, WeaponModifiers.TIER_COUNT),
				string.format("OddsBrackets Lv %d: last chase %s must beat rung 10", b.level, b.chase.name))
		end
		for _, n in pairs(b.chase.oneIn) do
			if i < #brackets then earliestHardest = math.max(earliestHardest, n) end
		end
	end
	for _, n in pairs(brackets[#brackets].chase.oneIn) do
		assert(n > earliestHardest, "OddsBrackets: the last chase must be the rarest on every rarity")
	end
	for _, b in ipairs(brackets) do
		assert(b.chase and b.top + 1 <= WeaponModifiers.TIER_COUNT, string.format("OddsBrackets Lv %d: chase", b.level))
		for _, rarity in ipairs(WeaponModifiers.RARITY_NAMES) do
			local row = b.rows[rarity]
			assert(row and #row == b.top - b.floor + 1, string.format("OddsBrackets Lv %d %s: wrong length", b.level, rarity))
			local sum = 0
			for _, v in ipairs(row) do sum += v end
			assert(math.abs(sum - 100) < 1e-6, string.format("OddsBrackets Lv %d %s sums to %.4f", b.level, rarity, sum))
			local n = b.chase.oneIn[rarity]
			assert(n and n > 100 and 100 / n < row[1], string.format("OddsBrackets Lv %d %s: chase rate", b.level, rarity))
			assert(n > (lastOneIn[rarity] or 0), string.format("OddsBrackets Lv %d %s: chase not rarer", b.level, rarity))
			lastOneIn[rarity] = n
		end
	end
end

-- The bracket a player of this level rolls from.
function WeaponModifiers.BracketFor(level: number?)
	local lv = math.max(1, math.floor(tonumber(level) or 1))
	local pick = WeaponModifiers.OddsBrackets[1]
	for _, b in ipairs(WeaponModifiers.OddsBrackets) do
		if lv >= b.level then pick = b end
	end
	return pick
end

-- ---------------------------------------------------------------- the chases
-- One named chase per bracket (above). A chase is a prefix of its own, outside the category lists:
-- it lands on its own category whatever the category shuffle said, sits one rung above its
-- bracket's top in the odds (so it is the rarest thing that pool can give) with a stat one notch above
-- the next pool's new Nice rung (the strongest roll for about a bracket), is shown as "??" until this player
-- has rolled it (player attribute ChasesFound, saved; the Lemonade also counts LemonadeFound as it
-- always has), and every one is announced to the whole server. The old rung-10 names (Squeezed,
-- Certain, Boundless, Galactic) stay in Categories so every saved sword still parses.
WeaponModifiers.CHASE_HIDDEN = "??"
WeaponModifiers.Chases = {}
WeaponModifiers.ChaseByName = {}
for _, b in ipairs(WeaponModifiers.OddsBrackets) do
	local c = b.chase
	c.tier = b.top + 1
	c.level = b.level
	c.where = b.where
	c.hidden = WeaponModifiers.CHASE_HIDDEN
	-- the highest ordinary rung its stat meets: what a sword's value rates it at
	c.valueTier = 1
	for t = 1, WeaponModifiers.TIER_COUNT do
		if WeaponModifiers.RungBonus(c.category, t) <= c.bonus then c.valueTier = t end
	end
	-- bestUntil: the first level whose pool can give a first-slot prefix of the same category that
	-- beats this chase's stat (its ordinary top rung, or its own chase); nil = never. The chase is
	-- best-in-slot until then -- and then the next pool's chase takes over the pull.
	c.bestUntil = nil
	for _, nb in ipairs(WeaponModifiers.OddsBrackets) do
		if nb.level > b.level and (WeaponModifiers.RungBonus(c.category, nb.top) > c.bonus
			or (nb.chase.category == c.category and nb.chase.bonus > c.bonus)) then
			c.bestUntil = nb.level
			break
		end
	end
	table.insert(WeaponModifiers.Chases, c)
	WeaponModifiers.ChaseByName[c.name] = c
	WeaponModifiers.ModByName[c.name] = {
		category = c.category, name = c.name, tier = c.tier, bonus = c.bonus, desc = c.desc, chase = true,
	}
end
-- The last and rarest chase, the Lemonade (kept under its old name for every older reader).
WeaponModifiers.Chase = WeaponModifiers.ChaseByName.Lemonade

-- The chase in this level's pool.
function WeaponModifiers.ChaseFor(level: number?)
	return WeaponModifiers.BracketFor(level).chase
end

-- Has this player rolled this chase yet? found: a Player (reads ChasesFound / LemonadeFound), the
-- ChasesFound comma string itself, or a plain boolean (already decided by the caller).
function WeaponModifiers.ChaseFound(found: any, chaseName: string): boolean
	if typeof(found) == "boolean" then return found end
	local list = found
	if typeof(found) == "Instance" then
		if chaseName == WeaponModifiers.Chase.name and (tonumber(found:GetAttribute("LemonadeFound")) or 0) > 0 then
			return true
		end
		list = found:GetAttribute("ChasesFound")
	end
	if typeof(list) ~= "string" then return false end
	for word in string.gmatch(list, "[^,%s]+") do
		if word == chaseName then return true end
	end
	return false
end

-- What an odds display calls this chase for this player: its name once found, "??" until then.
function WeaponModifiers.ChaseLabel(found: any, chase): string
	return WeaponModifiers.ChaseFound(found, chase.name) and chase.name or chase.hidden
end

-- The level ceiling: the highest rung a player of this level can roll (their bracket's chase).
WeaponModifiers.LevelCeiling = {}
for _, b in ipairs(WeaponModifiers.OddsBrackets) do
	table.insert(WeaponModifiers.LevelCeiling, { level = b.level, tier = b.chase.tier })
end

function WeaponModifiers.MaxTierForLevel(level: number?): number
	return WeaponModifiers.BracketFor(level).chase.tier
end

-- The name of that ceiling (the chase's real name; displays hide it with ChaseLabel).
function WeaponModifiers.CeilingName(level: number?): string
	return WeaponModifiers.BracketFor(level).chase.name
end

-- The level an ordinary rung first opens (for "unlocks at Lv 35" labels).
function WeaponModifiers.LevelForTier(tier: number): number
	for _, b in ipairs(WeaponModifiers.OddsBrackets) do
		if b.top >= tier then return b.level end
	end
	return math.huge
end

-- The pull toward the next bracket: what opens next and when. nil at the last bracket.
-- newRung is false when the next bracket opens no new ordinary rung (Lv 80 opens only the Lemonade).
function WeaponModifiers.NextBracket(level: number?)
	local now = WeaponModifiers.BracketFor(level)
	for _, b in ipairs(WeaponModifiers.OddsBrackets) do
		if b.level > now.level then
			return { level = b.level, where = b.where, tier = b.top, name = WeaponModifiers.Rungs[b.top].name,
				newRung = b.top > now.top, chase = b.chase,
				retires = b.floor > now.floor and WeaponModifiers.Rungs[now.floor].name or nil }
		end
	end
	return nil
end

-- Kept for callers that validate a saved rarity name (BossSwordFactory.describeTool).
WeaponModifiers.RarityConfig = {}
for _, name in ipairs(WeaponModifiers.RARITY_NAMES) do
	WeaponModifiers.RarityConfig[name] = { name = name }
end

-- How loud a rolled rung is at this level (the rare-roll tag):
--   "Lemonade"  the Lemonade chase: the biggest server-wide banner, every time.
--   "Chase"     any other bracket's chase: a server-wide banner, every time.
--   "Great"     the bracket's top ordinary rung when it is top tier (Supernova Lv 35-54, Prismatic
--               Lv 55+): a one-line server shout.
--   "Nice"      the bracket's top ordinary rung below that: a stamp on your own reveal.
--   nil         anything else.
function WeaponModifiers.TagFor(tier: number?, level: number?): string?
	tier = tonumber(tier) or 0
	local b = WeaponModifiers.BracketFor(level)
	if tier == b.chase.tier then
		return b.chase == WeaponModifiers.Chase and "Lemonade" or "Chase"
	end
	if tier == b.top then
		return tier >= WeaponModifiers.TOP_TIER_FROM and "Great" or "Nice"
	end
	return nil
end

-- Luck: earned in play (rebirths, wealth milestones, kill streak) and never bought. It lifts
-- rungs LUCK_FROM_TIER..9 by LUCK_WEIGHT of the luck above 1 (luck x2.5 = x1.6 on those rungs), each
-- capped at LUCK_CAP of the rung below it, and pays for it out of the plain rungs under LUCK_FROM_TIER.
-- It never lifts the level wall and never moves any chase's rate. [TUNING]
WeaponModifiers.LUCK_FROM_TIER = 7
WeaponModifiers.LUCK_WEIGHT = 0.4
WeaponModifiers.LUCK_CAP = 0.85 -- a lifted rung never passes 85% of the rung below it: the ladder always thins as it climbs
WeaponModifiers.Luck = {
	STREAK_PER_KILL = 0.02,  -- +0.02x per kill in the current streak...
	STREAK_MAX = 1.0,        -- ...up to +1.0x at a 50-kill streak
	STREAK_WINDOW = 25,      -- seconds between kills before the streak drops
	REBIRTH_PER = 0.1,       -- +0.1x per rebirth...
	REBIRTH_MAX = 1.0,       -- ...up to +1.0x
	-- Standing luck earned from the wealth ladder (Config.WealthLadder), never bought.
	MILESTONE_MAX = 0.5,
}

-- Server-wide announcement: every chase toasts every player (see TagFor); this is the Lemonade's rung.
WeaponModifiers.BROADCAST_TIER = WeaponModifiers.Chase.tier

-- Mutations: a whole-roll variant that multiplies every modifier's bonus. True odds: luck and
-- level never change them.
WeaponModifiers.Variants = {
	{ name = "Iced",    oneIn = 40,   mult = 1.2, color = Color3.fromRGB(150, 225, 255) },
	{ name = "Sugared", oneIn = 300,  mult = 1.4, color = Color3.fromRGB(255, 225, 245) },
	{ name = "Sour",    oneIn = 2500, mult = 1.7, color = Color3.fromRGB(230, 255, 90) },
}
WeaponModifiers.VariantByName = {}
for _, v in ipairs(WeaponModifiers.Variants) do WeaponModifiers.VariantByName[v.name] = v end

-- Total luck multiplier from its parts. streak/rebirths are counts; milestoneLuck is the standing
-- bonus the wealth ladder granted (player attribute MilestoneLuck, set by VaultSystem).
-- Returns the total and every part, so a UI can show where each one came from.
function WeaponModifiers.LuckFrom(streak: number?, rebirths: number?, milestoneLuck: number?)
	local L = WeaponModifiers.Luck
	local streakBonus = math.min((tonumber(streak) or 0) * L.STREAK_PER_KILL, L.STREAK_MAX)
	local rebirthBonus = math.min((tonumber(rebirths) or 0) * L.REBIRTH_PER, L.REBIRTH_MAX)
	local milestoneBonus = math.clamp(tonumber(milestoneLuck) or 0, 0, L.MILESTONE_MAX)
	return 1 + streakBonus + rebirthBonus + milestoneBonus, streakBonus, rebirthBonus, milestoneBonus
end

-- Probability of each rung (1..10) for one rolled prefix of this rarity, at this player level and
-- luck: the bracket's hand-authored row, its chase at a flat 1 in N (taken out of the floor rung),
-- then the luck lift on the ordinary rungs. Rungs outside the bracket are exactly 0. Sums to 1.
-- The server rolls with this; every display prints it.
function WeaponModifiers.TierOdds(rarityName: string?, level: number?, luck: number?)
	local b = WeaponModifiers.BracketFor(level)
	local rarity = b.rows[rarityName or ""] and rarityName or "Common"
	local row = b.rows[rarity]
	local odds = table.create(WeaponModifiers.TIER_COUNT, 0)
	for i, pct in ipairs(row) do
		odds[b.floor + i - 1] = pct / 100
	end
	local chaseP = 1 / b.chase.oneIn[rarity]
	odds[b.floor] -= chaseP
	odds[b.chase.tier] = chaseP
	local lift = 1 + (math.max(tonumber(luck) or 1, 1) - 1) * WeaponModifiers.LUCK_WEIGHT
	if lift > 1 then
		local added = 0
		for tier = WeaponModifiers.LUCK_FROM_TIER, b.top do -- ordinary rungs only: never the chase
			if odds[tier] > 0 then
				local lifted = math.min(odds[tier] * lift, odds[tier - 1] * WeaponModifiers.LUCK_CAP)
				if lifted > odds[tier] then
					added += lifted - odds[tier]
					odds[tier] = lifted
				end
			end
		end
		if added > 0 then
			local plain = 0
			for tier = 1, WeaponModifiers.LUCK_FROM_TIER - 1 do
				if tier ~= b.chase.tier then plain += odds[tier] end
			end
			local keep = math.max(plain - added, 0) / math.max(plain, 1e-9)
			for tier = 1, WeaponModifiers.LUCK_FROM_TIER - 1 do
				if tier ~= b.chase.tier then odds[tier] *= keep end
			end
		end
	end
	local total = 0
	for tier = 1, WeaponModifiers.TIER_COUNT do total += odds[tier] end
	for tier = 1, WeaponModifiers.TIER_COUNT do odds[tier] /= total end
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

-- "1 in 5,000" style text ("locked" for a rung above the ceiling).
function WeaponModifiers.OneInText(p: number): string
	local n = WeaponModifiers.OneIn(p)
	if not n then return "locked" end
	local s = n < 10 and string.format("%.1f", n):gsub("%.0$", "") or tostring(math.floor(n))
	if n >= 1000 then
		s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	end
	return "1 in " .. s
end

-- The full ladder for a rarity at a level and luck, for any odds display: one row per rung with
-- its name, colour, probability, 1-in-N, its rare-roll tag, and (for a locked rung) the level that
-- opens it. The bracket's chase row carries the chase's own name and colour. found: has this
-- player rolled that chase yet (a Player, the ChasesFound string, or a boolean; see ChaseFound)?
-- Until they have, the chase shows its name as "??" -- its odds are always the real ones.
function WeaponModifiers.Ladder(rarityName: string?, level: number?, luck: number?, found: any)
	local odds = WeaponModifiers.TierOdds(rarityName, level, luck)
	local b = WeaponModifiers.BracketFor(level)
	local rows = {}
	local above = 0
	for tier = WeaponModifiers.TIER_COUNT, 1, -1 do
		above += odds[tier]
		local isChase = tier == b.chase.tier
		local hidden = isChase and not WeaponModifiers.ChaseFound(found, b.chase.name)
		rows[tier] = {
			tier = tier,
			name = isChase and (hidden and b.chase.hidden or b.chase.name) or WeaponModifiers.Rungs[tier].name,
			color = isChase and b.chase.color or WeaponModifiers.Rungs[tier].color,
			chase = isChase or nil, hidden = hidden or nil,
			p = odds[tier], atLeast = above, oneIn = WeaponModifiers.OneIn(odds[tier]),
			oneInText = WeaponModifiers.OneInText(odds[tier]),
			tag = odds[tier] > 0 and WeaponModifiers.TagFor(tier, level) or nil,
			retired = odds[tier] <= 0 and tier < b.floor or nil,
			locked = odds[tier] <= 0 and tier > b.chase.tier or nil,
			unlockLevel = (odds[tier] <= 0 and tier > b.chase.tier) and WeaponModifiers.LevelForTier(tier) or nil,
		}
	end
	return rows
end

local function rollTier(rarityName, level, luck)
	local odds = WeaponModifiers.TierOdds(rarityName, level, luck)
	local pick = math.random()
	for tier = WeaponModifiers.TIER_COUNT, 1, -1 do
		if odds[tier] > 0 then
			pick -= odds[tier]
			if pick <= 0 then return tier, odds end
		end
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

-- Roll a sword's prefixes. The server's only prefix roll: drops, the spin wheel, the shop, admin.
-- opts.level  the player's level (picks the odds bracket). Defaults to 1.
-- opts.luck   the earned luck multiplier (WeaponModifiers.LuckFrom). Defaults to 1.
-- opts.slots  prefix slots the player owns (WeaponModifiers.SlotsOf). Defaults to BASE_SLOTS.
-- opts.minTier (admin/showcase only) lift each rolled rung to at least this, still under the ceiling.
-- Returns mods (each { category, name, bonus, desc, tier, rung, p, oneIn, tag, chase? }), variantName.
function WeaponModifiers.RollModifiers(rarityName: string?, opts)
	opts = opts or {}
	local level = tonumber(opts.level) or 1
	local luck = tonumber(opts.luck) or 1
	local count = WeaponModifiers.ClampSlots(opts.slots)
	local variant = rollVariant()
	local b = WeaponModifiers.BracketFor(level)
	local chase = b.chase
	local ceiling = chase.tier

	-- The rungs first, one per slot.
	local tiers, odds = {}, nil
	for i = 1, count do
		local tierIdx
		tierIdx, odds = rollTier(rarityName, level, luck)
		if opts.minTier then
			tierIdx = math.max(tierIdx, math.min(opts.minTier, ceiling))
		end
		tiers[i] = math.min(tierIdx, ceiling)
	end

	-- Then one category per slot: shuffle, and hand the chase's own category to the first chase
	-- roll (a chase is always its own prefix, whatever the shuffle said), swapping with whoever
	-- drew it. A second chase-rung roll on a multi-slot sword keeps its category's ordinary name.
	local catKeys = { "Damage", "CritChance", "Range", "Knockback" }
	for i = #catKeys, 2, -1 do
		local j = math.random(1, i)
		catKeys[i], catKeys[j] = catKeys[j], catKeys[i]
	end
	local chaseSlot = nil
	for i = 1, count do
		if tiers[i] == chase.tier then chaseSlot = i break end
	end
	if chaseSlot then
		local d = table.find(catKeys, chase.category)
		catKeys[chaseSlot], catKeys[d] = catKeys[d], catKeys[chaseSlot]
	end

	local rolled = {}
	for i = 1, count do
		local catKey = catKeys[i]
		local tierIdx = tiers[i]
		local isChase = i == chaseSlot
		local entry = isChase and chase or WeaponModifiers.Categories[catKey].Tiers[tierIdx]
		table.insert(rolled, {
			category = catKey,
			name = entry.name,
			bonus = entry.bonus,
			desc = entry.desc,
			tier = tierIdx,
			rung = isChase and (chase.where .. " chase") or WeaponModifiers.Rungs[tierIdx].name,
			p = odds[tierIdx],
			oneIn = WeaponModifiers.OneIn(odds[tierIdx]),
			tag = isChase and WeaponModifiers.TagFor(tierIdx, level)
				or (tierIdx == chase.tier and "Great" or WeaponModifiers.TagFor(tierIdx, level)),
			chase = isChase or nil,
		})
	end
	return rolled, variant
end

return WeaponModifiers
