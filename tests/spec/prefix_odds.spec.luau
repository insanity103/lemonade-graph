--// prefix_odds.spec  (sword prefixes: one slot, the level wall, and odds that rise with rarity and level)
-- Rolls go through WeaponModifiers.RollModifiers (the server's only prefix roll) and, end to end,
-- through BossSwordFactory.build / SpinService.Grant (the spin wheel's sword builder).
local Game = require("../harness/game")

local Z_LIMIT = 5

local function modules()
	local g = Game.new({})
	return g, g:module("ReplicatedStorage.Config.WeaponModifiers"), g:module("ServerScriptService.BossSwordFactory"),
		g:module("ReplicatedStorage.Config.SpinPools")
end

local function meanTier(odds)
	local m = 0
	for tier, p in ipairs(odds) do m += tier * p end
	return m
end

-- P(tier >= k)
local function atLeast(odds, k)
	local s = 0
	for tier = k, #odds do s += odds[tier] end
	return s
end

local function countPrefixes(tool)
	local n = 0
	for _ in string.gmatch(tool:GetAttribute("Prefixes") or "", "[^,%s]+") do n += 1 end
	return n
end

return function(t)
	t.test("every spin-pool sword builds with exactly one prefix (one slot), at its lowest level and at Lv 100", function()
		local _, WM, Factory, SpinPools = modules()
		t.eq(WM.BASE_SLOTS, 1, "BASE_SLOTS")
		local built = 0
		for _, pool in ipairs(SpinPools.Pools) do
			for _, entry in ipairs(pool.entries) do
				for _, level in ipairs({ entry.minLevel, 100 }) do
					local tool, mods = Factory.build(entry.poolKey, {
						sword = entry.sword, rarity = entry.rarity, rarityOdds = { { rarity = entry.rarity, p = 1 } },
						level = level, slots = WM.SlotsOf(nil), luck = 1,
					})
					built += 1
					t.eq(#mods, 1, string.format("%s (%s) Lv %d: rolled prefixes", entry.sword, pool.zone, level))
					t.eq(countPrefixes(tool), 1, string.format("%s Lv %d: Prefixes attribute %q", entry.sword, level,
						tostring(tool:GetAttribute("Prefixes"))))
					t.eq(tool:GetAttribute("StoredPrefixes"), nil, entry.sword .. ": a fresh sword stores no extra prefixes")
					tool:Destroy()
				end
			end
		end
		t.note("%d swords built", built)
	end)

	t.test("100,000 rolls at one slot are all exactly one prefix; unlocked slots roll one per category", function()
		local _, WM = modules()
		local n = t.scale(100000)
		local wrong = 0
		for i = 1, n do
			local rarity = WM.RARITY_NAMES[(i % #WM.RARITY_NAMES) + 1]
			local mods = WM.RollModifiers(rarity, { level = (i % 100) + 1, luck = 1, slots = 1 })
			if #mods ~= 1 then wrong += 1 end
		end
		t.eq(wrong, 0, "rolls with a prefix count other than 1")
		for slots = 2, WM.MAX_SLOTS do
			for _ = 1, t.scale(5000) do
				local mods = WM.RollModifiers("Legendary", { level = 80, luck = 1, slots = slots })
				if not t.check(#mods == slots, "%d slots rolled %d prefixes", slots, #mods) then break end
				local cats = {}
				for _, m in ipairs(mods) do
					t.check(not cats[m.category], "%d slots: two prefixes share category %s", slots, m.category)
					cats[m.category] = true
				end
			end
		end
		-- a save claiming more slots than exist is clamped
		t.eq(#WM.RollModifiers("Rare", { level = 10, slots = 99 }), WM.MAX_SLOTS, "slots = 99 clamps to MAX_SLOTS")
		t.eq(#WM.RollModifiers("Rare", { level = 10, slots = 0 }), WM.BASE_SLOTS, "slots = 0 clamps to BASE_SLOTS")
	end)

	t.test("a level-3 player gets 0 top-tier prefixes in 100,000 rolls (even at maximum luck)", function()
		local _, WM = modules()
		local n = t.scale(100000)
		local maxLuck = WM.LuckFrom(1e6, 1e6, 1e6)
		local ceiling = WM.MaxTierForLevel(3)
		t.check(ceiling < WM.TOP_TIER_FROM, "Lv 3 ceiling %d is already top tier (TOP_TIER_FROM %d)", ceiling, WM.TOP_TIER_FROM)
		for _, case in ipairs({ { luck = 1, label = "luck x1, every rarity" }, { luck = maxLuck, label = "max luck, Legendary" } }) do
			local top, over, highest = 0, 0, 0
			for i = 1, n do
				local rarity = case.luck == 1 and WM.RARITY_NAMES[(i % 5) + 1] or "Legendary"
				local mods = WM.RollModifiers(rarity, { level = 3, luck = case.luck, slots = 1 })
				local tier = mods[1].tier
				highest = math.max(highest, tier)
				if tier >= WM.TOP_TIER_FROM then top += 1 end
				if tier > ceiling then over += 1 end
			end
			t.eq(top, 0, "top-tier prefixes at Lv 3, " .. case.label)
			t.eq(over, 0, "prefixes above the Lv 3 ceiling, " .. case.label)
			t.note("%s: %d rolls, highest rung %d (ceiling %d)", case.label, n, highest, ceiling)
		end
	end)

	t.test("a level-3 player's spin swords never carry a top-tier prefix (end to end through SpinService.Grant)", function()
		local g = Game.new({ scripts = { "RuntimeBootstrap", "PlayerDataStore" } })
		local SpinService = g:module("ServerScriptService.SpinService")
		local WM = g:module("ReplicatedStorage.Config.WeaponModifiers")
		local PDS = g:module("ServerScriptService.PlayerDataService")
		local player = g:addPlayer({})
		PDS.SetField(player, "zoneDepth", { IronLowlands = { best = 3, boss = true } })
		g:setLevel(player, 3)
		player:SetAttribute("Rebirths", 10) -- the most rebirth luck a player can hold
		player:SetAttribute("MilestoneLuck", 1)
		for _ = 1, t.scale(3000) do
			local row = SpinService.Roll(player, nil)
			local tool, mods = SpinService.Grant(player, row)
			t.eq(#mods, 1, "prefix count")
			if not t.check(mods[1].tier < WM.TOP_TIER_FROM, "Lv 3 spin rolled %s (rung %d) on %s", mods[1].name,
				mods[1].tier, row.sword) then
				break
			end
			tool:Destroy()
		end
	end)

	t.test("prefix odds rise with sword rarity at every level bracket", function()
		local _, WM = modules()
		for _, b in ipairs(WM.OddsBrackets) do
			local prev, prevName = nil, nil
			for _, rarity in ipairs(WM.RARITY_NAMES) do
				local odds = WM.TierOdds(rarity, b.level, 1)
				if prev then
					t.check(meanTier(odds) > meanTier(prev), "Lv %d: mean rung %s %.3f is not above %s %.3f", b.level, rarity,
						meanTier(odds), prevName, meanTier(prev))
					for k = 2, WM.TIER_COUNT do
						t.check(atLeast(odds, k) >= atLeast(prev, k) - 1e-12,
							"Lv %d: P(rung >= %d) falls from %s %.5f to %s %.5f", b.level, k, prevName, atLeast(prev, k),
							rarity, atLeast(odds, k))
					end
				end
				prev, prevName = odds, rarity
			end
		end
	end)

	t.test("prefix odds rise with player level for every rarity (the chase rung is the documented exception)", function()
		local _, WM = modules()
		local brackets = WM.OddsBrackets
		for _, rarity in ipairs(WM.RARITY_NAMES) do
			for i = 2, #brackets do
				local a, b = brackets[i - 1], brackets[i]
				local oa, ob = WM.TierOdds(rarity, a.level, 1), WM.TierOdds(rarity, b.level, 1)
				t.check(meanTier(ob) > meanTier(oa), "%s: mean rung Lv %d %.3f is not above Lv %d %.3f", rarity, b.level,
					meanTier(ob), a.level, meanTier(oa))
				-- Every ORDINARY threshold must not get worse. Above the new bracket's top ordinary rung
				-- only chases live, and each bracket's chase is deliberately rarer than the last
				-- (WeaponModifiers asserts it at load), so those thresholds are exempt.
				for k = 2, b.top do
					t.check(atLeast(ob, k) >= atLeast(oa, k) - 1e-12, "%s: P(rung >= %d) falls from Lv %d %.5f to Lv %d %.5f",
						rarity, k, a.level, atLeast(oa, k), b.level, atLeast(ob, k))
				end
				t.check(b.chase.oneIn[rarity] > a.chase.oneIn[rarity], "%s: Lv %d chase is not rarer than Lv %d's", rarity,
					b.level, a.level)
			end
		end
	end)

	t.test("rolled prefixes land on TierOdds (the odds players are shown) for every rarity and bracket", function()
		local _, WM = modules()
		local n = t.scale(10000)
		local means = {}
		local worst, worstLabel = 0, ""
		for _, b in ipairs(WM.OddsBrackets) do
			means[b.level] = {}
			for _, rarity in ipairs(WM.RARITY_NAMES) do
				local odds = WM.TierOdds(rarity, b.level, 1)
				local counts = table.create(WM.TIER_COUNT, 0)
				local sum = 0
				for _ = 1, n do
					local tier = WM.RollModifiers(rarity, { level = b.level, luck = 1, slots = 1 })[1].tier
					counts[tier] += 1
					sum += tier
				end
				means[b.level][rarity] = sum / n
				for tier = 1, WM.TIER_COUNT do
					local p = odds[tier]
					if p == 0 then
						t.eq(counts[tier], 0, string.format("Lv %d %s rung %d (odds 0)", b.level, rarity, tier))
					else
						local z = (counts[tier] - n * p) / math.sqrt(n * p * (1 - p))
						if math.abs(z) > worst then
							worst, worstLabel = math.abs(z), string.format("Lv %d %s rung %d", b.level, rarity, tier)
						end
						t.check(math.abs(z) <= Z_LIMIT, "Lv %d %s rung %d: %d of %d, odds %.5f (z = %.1f)", b.level, rarity,
							tier, counts[tier], n, p, z)
					end
				end
			end
		end
		-- and the rise is visible in what actually rolled, not only in the table
		for _, b in ipairs(WM.OddsBrackets) do
			t.check(means[b.level].Legendary > means[b.level].Common, "Lv %d: rolled Legendary mean %.3f <= Common %.3f",
				b.level, means[b.level].Legendary, means[b.level].Common)
		end
		t.check(means[80].Common > means[1].Common, "rolled Common mean does not rise from Lv 1 to Lv 80")
		t.note("%d rolls per (bracket, rarity); worst |z| %.2f at %s", n, worst, worstLabel)
	end)

	t.test("the level wall holds at every bracket at maximum luck; luck never moves a chase", function()
		local _, WM = modules()
		local maxLuck = WM.LuckFrom(1e6, 1e6, 1e6)
		for _, b in ipairs(WM.OddsBrackets) do
			local base = WM.TierOdds("Legendary", b.level, 1)
			local lucky = WM.TierOdds("Legendary", b.level, maxLuck)
			t.near(lucky[b.chase.tier], base[b.chase.tier], 1e-12, string.format("Lv %d chase odds under luck", b.level))
			local sum = 0
			for tier = 1, WM.TIER_COUNT do
				sum += lucky[tier]
				if tier > b.chase.tier or tier < b.floor then
					t.eq(lucky[tier], 0, string.format("Lv %d rung %d (outside floor %d..ceiling %d) at max luck", b.level,
						tier, b.floor, b.chase.tier))
				end
			end
			t.near(sum, 1, 1e-9, string.format("Lv %d odds at max luck sum", b.level))
			for _ = 1, t.scale(20000) do
				local tier = WM.RollModifiers("Legendary", { level = b.level, luck = maxLuck, slots = 1 })[1].tier
				if not t.check(tier <= b.chase.tier and tier >= b.floor, "Lv %d max luck rolled rung %d", b.level, tier) then
					break
				end
			end
		end
	end)
end
