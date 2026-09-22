-- tools/sim_prefix_odds.luau | Studio-only measurement of the shipped prefix roll.
-- Run on the SERVER of a Studio play session (Roblox Studio MCP run_script_in_play_mode,
-- mode run_server). It drives the real code, never a copy. Set PART before running ("A" or "B";
-- the two halves fit the MCP call time limit):
--   A1. WeaponModifiers.RollModifiers (the server's only prefix roll; BossSwordFactory.build calls
--       it for every spin, purchase and admin gift) N times per (rarity, level) bucket at luck 1
--       and 1 slot, at every odds bracket's entry level (plus Lv 3), counting rung, tag and chase.
--   A2. BossSwordFactory.build end to end (a real Tool) for a smaller sample: exactly one prefix,
--       the level wall holds, and a chase-rung roll lands as the bracket's named chase prefix.
--   A3. Old saves through BossSwordFactory.rebuild (Blessed four-prefix, old rung-10 name).
--   B.  Every bracket's named chase alone: CHASE_N rolls each for a Common and a Legendary at the
--       bracket's entry level, and the Lv 80 Legendary again at the most luck a player can earn
--       (a chase rate must not move).
-- Prints one line "SIMJSON <json>".
local PART = PART or "A"
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local WM = require(RS.Config.WeaponModifiers)
local Factory = require(game:GetService("ServerScriptService").BossSwordFactory)

local N = 100000
local CHASE_N = 1000000
local BUILD_N = 2000
local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local LEVELS = { 3, 5, 10, 18, 25, 35, 55, 80 }

local out = { part = PART, n = N, chaseN = CHASE_N, buckets = {}, chase = {}, builds = {}, legacy = {}, config = {} }
local t0 = os.clock()
local total = 0

if PART == "A" then
	math.randomseed(20260923)
	for _, level in ipairs(LEVELS) do
		for _, rarity in ipairs(RARITIES) do
			local counts = table.create(WM.TIER_COUNT, 0)
			local tags = { Nice = 0, Great = 0, Chase = 0, Lemonade = 0 }
			local chaseNames = {}
			local slotsSeen = {}
			for _ = 1, N do
				local mods = WM.RollModifiers(rarity, { level = level, luck = 1, slots = 1 })
				slotsSeen[#mods] = (slotsSeen[#mods] or 0) + 1
				local m = mods[1]
				counts[m.tier] += 1
				if m.tag then tags[m.tag] += 1 end
				if m.chase then chaseNames[m.name .. "/" .. m.category] = (chaseNames[m.name .. "/" .. m.category] or 0) + 1 end
			end
			total += N
			table.insert(out.buckets, { rarity = rarity, level = level, counts = counts, odds = WM.TierOdds(rarity, level, 1),
				tags = tags, chaseNames = chaseNames, ceiling = WM.MaxTierForLevel(level), floor = WM.BracketFor(level).floor,
				top = WM.BracketFor(level).top, oneSlotRolls = slotsSeen[1] or 0 })
			task.wait()
		end
	end
	out.rollSeconds = os.clock() - t0
	out.totalRolls = total

	-- End to end through the Tool builder.
	for _, case in ipairs({ { "IronLowlands", 3 }, { "Boss_Gorgon", 3 }, { "VoidRift", 60 }, { "Boss_CelestialTitan", 100 } }) do
		local pool, level = case[1], case[2]
		local maxTier, prefixCounts, top, chases = 0, {}, 0, {}
		for _ = 1, BUILD_N do
			local tool, mods = Factory.build(pool, { level = level, slots = 1, luck = 1 })
			local n = 0
			for _ in string.gmatch(tool:GetAttribute("Prefixes") or "", "[^,%s]+") do n += 1 end
			prefixCounts[n] = (prefixCounts[n] or 0) + 1
			maxTier = math.max(maxTier, mods[1] and mods[1].tier or 0)
			if mods[1] and mods[1].tier >= WM.TOP_TIER_FROM then top += 1 end
			if mods[1] and mods[1].chase then chases[mods[1].name] = (chases[mods[1].name] or 0) + 1 end
			tool:Destroy()
		end
		table.insert(out.builds, { pool = pool, level = level, n = BUILD_N, prefixCounts = prefixCounts,
			maxTier = maxTier, topTier = top, chases = chases, ceiling = WM.MaxTierForLevel(level) })
	end
	-- A forced chase-rung Tool (the admin minTier path) at every bracket, and Lv 80 with 3 slots.
	out.chaseTools = {}
	for _, case in ipairs({ { 1, 1 }, { 18, 1 }, { 35, 1 }, { 55, 1 }, { 80, 1 }, { 80, 3 } }) do
		local level, slots = case[1], case[2]
		local tool, mods = Factory.build("Boss_CelestialTitan", { level = level, slots = slots, luck = 1, minTier = 10 })
		local list = {}
		for _, m in ipairs(mods) do table.insert(list, string.format("%s/%s/%d/%s", m.name, m.category, m.tier, tostring(m.tag))) end
		table.insert(out.chaseTools, { level = level, slots = slots, name = tool.Name, prefixes = tool:GetAttribute("Prefixes"),
			bonusDamage = tool:GetAttribute("BonusDamagePct"), crit = tool:GetAttribute("CritChance"),
			range = tool:GetAttribute("RangeBonus"), knockback = tool:GetAttribute("KnockbackBonus"), mods = list,
			rating = require(RS.Config.SwordValue).rateTool(tool) })
		tool:Destroy()
	end

	-- A pre-rework save: Blessed, four prefixes (rungs 6, 4, 2, 5), rebuilt at each slot count.
	local legacyEntry = { name = "Blessed Mythic Precision Reaching Quaking Astral Eclipse", attrs = {
		BossTier = 5, PoolKey = "Boss_CelestialTitan", Rarity = "Legendary", DamageMult = 9.1, PoolBase = 9.1,
		Prefixes = "Mythic, Precision, Reaching, Quaking", ExtraSlot = true,
		BonusDamagePct = 0.85, CritChance = 0.30, RangeBonus = 8, KnockbackBonus = 0,
		BaseWeaponName = "Astral Eclipse", WeaponAppearanceMaterial = "Neon" } }
	for slots = 1, 3 do
		local tool = Factory.rebuild(legacyEntry, slots)
		table.insert(out.legacy, { slots = slots, loaded = tool ~= nil, name = tool and tool.Name,
			prefixes = tool and tool:GetAttribute("Prefixes"), stored = tool and tool:GetAttribute("StoredPrefixes") })
		if tool then tool:Destroy() end
	end
	-- Old saves: a pre-chase rung-10 name, and a round-1 Lemonade sword, still load.
	out.oldSaves = {}
	for _, pref in ipairs({ "Squeezed", "Lemonade" }) do
		local tool = Factory.rebuild({ name = pref .. " Astral Eclipse", attrs = {
			BossTier = 5, PoolKey = "Boss_CelestialTitan", Rarity = "Legendary", DamageMult = 9.1, PoolBase = 9.1,
			Prefixes = pref, BonusDamagePct = pref == "Lemonade" and 2.5 or 2.2, BaseWeaponName = "Astral Eclipse",
			WeaponAppearanceMaterial = "Neon" } }, 1)
		table.insert(out.oldSaves, { prefix = pref, loaded = tool ~= nil, name = tool and tool.Name,
			prefixes = tool and tool:GetAttribute("Prefixes") })
		if tool then tool:Destroy() end
	end

	local brackets = {}
	for _, b in ipairs(WM.OddsBrackets) do
		table.insert(brackets, { level = b.level, where = b.where, mood = b.mood, floor = b.floor, top = b.top, rows = b.rows,
			chase = { name = b.chase.name, desc = b.chase.desc, category = b.chase.category, tier = b.chase.tier,
				oneIn = b.chase.oneIn } })
	end
	local maxLuck = WM.LuckFrom(999, 99, 99)
	out.config = {
		baseSlots = WM.BASE_SLOTS, maxSlots = WM.MAX_SLOTS, topTierFrom = WM.TOP_TIER_FROM, brackets = brackets,
		slot2 = WM.SlotUnlocks[2], slot2Price = WM.SlotUnlockPrice(2),
		slot3 = WM.SlotUnlocks[3], slot3Price = WM.SlotUnlockPrice(3),
		rungs = (function() local r = {} for i, x in ipairs(WM.Rungs) do r[i] = x.name end return r end)(),
		luckFromTier = WM.LUCK_FROM_TIER, luckWeight = WM.LUCK_WEIGHT, luckMax = maxLuck,
		lv35LegendaryMaxLuck = WM.TierOdds("Legendary", 35, maxLuck),
		lv80CommonLuck25 = WM.TierOdds("Common", 80, 2.5),
		lv80LegendaryMaxLuck = WM.TierOdds("Legendary", 80, maxLuck),
		lv3LegendaryMaxLuck = WM.TierOdds("Legendary", 3, maxLuck),
		ladderLv1Hidden = WM.Ladder("Common", 1, 1, "")[4].name,
		ladderLv1Found = WM.Ladder("Common", 1, 1, "Lemondrop")[4].name,
		ladderLv80Hidden = WM.Ladder("Legendary", 80, 1, false)[10].name,
		ladderLv80Found = WM.Ladder("Legendary", 80, 1, true)[10].name,
		ladderLv55Starfizz = WM.Ladder("Legendary", 55, 1, "Lemondrop,Starfizz")[10].name,
		next3 = WM.NextBracket(3), next55 = WM.NextBracket(55),
		ceilingName3 = WM.CeilingName(3),
	}
	-- Each chase's edge: its stat against its pool's best ordinary roll in the same category, the
	-- next bracket's newly opened (Nice) rung, and the first level an ordinary first-slot roll
	-- matches it (nil = never).
	out.config.chaseEdge = {}
	for i, b in ipairs(WM.OddsBrackets) do
		local c = b.chase
		local nextB = WM.OddsBrackets[i + 1]
		local caughtAt = nil
		for _, later in ipairs(WM.OddsBrackets) do
			if later.level >= b.level and WM.RungBonus(c.category, later.top) >= c.bonus - 1e-9 then
				caughtAt = later.level
				break
			end
		end
		table.insert(out.config.chaseEdge, { name = c.name, level = b.level, category = c.category, bonus = c.bonus,
			poolTop = WM.RungBonus(c.category, b.top), flavor = c.flavor, bestUntil = c.bestUntil,
			nextNice = nextB and WM.RungBonus(c.category, nextB.top) or nil,
			nextAfter = (nextB and nextB.top < WM.TIER_COUNT) and WM.RungBonus(c.category, nextB.top + 1) or nil,
			caughtAt = caughtAt, valueTier = c.valueTier })
	end
	-- The server banner each chase prints, through the real SpinService.CreditPrefixes, on a
	-- stand-in player object (attributes in a table; nothing saved, no real profile touched).
	out.config.banners = {}
	local SpinService = require(game:GetService("ServerScriptService").SpinService)
	local attrs = {}
	local fake = { DisplayName = "Tester", GetAttribute = function(_, k) return attrs[k] end,
		SetAttribute = function(_, k, v) attrs[k] = v end }
	local LogService = game:GetService("LogService")
	local lines = {}
	local conn = LogService.MessageOut:Connect(function(msg) if string.find(msg, "[SpinService]", 1, true) then table.insert(lines, msg) end end)
	for _, b in ipairs(WM.OddsBrackets) do
		local mods = WM.RollModifiers("Common", { level = b.level, luck = 1, slots = 1, minTier = 10 })
		SpinService.CreditPrefixes(fake, mods, mods[1].name .. " Corona Shortsword", 0)
	end
	task.wait(0.2)
	conn:Disconnect()
	out.config.banners = lines
	out.config.bannerFound = attrs.ChasesFound
	do
	end
	-- Pacing from the real wheel: the player at each bracket's entry level spins the deepest area
	-- their level opens (SpinPools gate), at each of its four depth steps. A spin's sword rarity
	-- comes from SpinPools.Odds (the list the server rolls), so tokens per chase =
	-- SpinPools.CostFor(zone, step) / sum over rows of p(row) / chase.oneIn[row.rarity].
	local SpinPools = require(RS.Config.SpinPools)
	local TokenRules = require(RS.Config.TokenRules)
	out.config.wheelPacing = {}
	for _, b in ipairs(WM.OddsBrackets) do
		local pool = nil
		for _, pl in ipairs(SpinPools.Pools) do
			if pl.gate <= b.level then pool = pl end
		end
		local steps = {}
		for step = 1, SpinPools.STEPS do
			local rows = SpinPools.Odds(pool.zone, step, b.level)
			local pChase, mix = 0, {}
			for _, row in ipairs(rows or {}) do
				if row.p > 0 then
					pChase += row.p / b.chase.oneIn[row.rarity]
					mix[row.rarity] = (mix[row.rarity] or 0) + row.p
				end
			end
			table.insert(steps, { step = step, mix = mix, oneIn = pChase > 0 and 1 / pChase or nil,
				tokens = pChase > 0 and SpinPools.CostFor(pool.zone, step) / pChase or nil,
				cost = SpinPools.CostFor(pool.zone, step) })
		end
		-- the same chase in ordinary kills of that area: tokens / the mean minion payout there
		-- (TokenRules.ForKill's rounded band x ZONE_SCALE)
		local band, scale = TokenRules.PER_KILL.minion, TokenRules.ZONE_SCALE[pool.zone] or 1
		local lo = math.max(1, math.floor(band[1] * scale + 0.5))
		local hi = math.max(lo, math.floor(band[2] * scale + 0.5))
		for _, st in ipairs(steps) do
			st.minionTokens = (lo + hi) / 2
			st.kills = st.tokens and st.tokens / st.minionTokens or nil
		end
		table.insert(out.config.wheelPacing, { level = b.level, chase = b.chase.name, zone = pool.zone, mood = b.mood,
			steps = steps })
	end
	out.config.tokenCost = SpinPools.TOKEN_COST -- the cheapest spin; each step's own price is steps[i].cost
	out.config.next3.chase = out.config.next3.chase.name
	out.config.next55.chase = out.config.next55.chase.name
else
	-- B: every bracket's chase alone.
	math.randomseed(20260924)
	local maxLuck = WM.LuckFrom(999, 99, 99)
	local cases = {}
	for _, b in ipairs(WM.OddsBrackets) do
		table.insert(cases, { b.level, "Common", 1 })
		table.insert(cases, { b.level, "Legendary", 1 })
	end
	table.insert(cases, { 80, "Legendary", maxLuck })
	for _, case in ipairs(cases) do
		local level, rarity, luck = case[1], case[2], case[3]
		local chase = WM.ChaseFor(level)
		local hits, names = 0, {}
		for i = 1, CHASE_N do
			local mods = WM.RollModifiers(rarity, { level = level, luck = luck, slots = 1 })
			if mods[1].tier == chase.tier then
				hits += 1
				local k = mods[1].name .. "/" .. mods[1].category .. "/" .. tostring(mods[1].tag)
				names[k] = (names[k] or 0) + 1
			end
			if i % 100000 == 0 then task.wait() end
		end
		total += CHASE_N
		table.insert(out.chase, { level = level, rarity = rarity, luck = luck, n = CHASE_N, chase = chase.name,
			configOneIn = chase.oneIn[rarity], hits = hits, names = names })
	end
	out.rollSeconds = os.clock() - t0
	out.totalRolls = total
end
print("SIMJSON " .. HttpService:JSONEncode(out))
