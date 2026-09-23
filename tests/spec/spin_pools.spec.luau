--// spin_pools.spec  (the town spin wheel: every area's pools, rolled through the real SpinService)
-- Expected odds are computed here straight from the shipped table (Config.SpinPools.Pools: each
-- entry's weight at that step over the step's total, locked entries removed), NOT from
-- SpinPools.Odds, so a bug in Odds / Pick / PoolFor / Roll shows up as a distribution mismatch.
local Game = require("../harness/game")

local SPINS_PER_STEP = 100000   -- per (area, depth step), as the brief asks
local SPINS_PER_CAP = 2000      -- per (area, step, capped level)
local Z_LIMIT = 5               -- a row fails at |z| > 5 (binomial); ~6e-7 false alarms per row

-- Weight of every entry live at `step` for a player of `level`, straight from the table.
local function expectedOdds(pool, step, level)
	local rows, total = {}, 0
	for _, entry in ipairs(pool.entries) do
		local w = entry.weights[step] or 0
		if w > 0 and level >= entry.minLevel then
			rows[entry.sword] = w
			total += w
		end
	end
	for sword, w in pairs(rows) do rows[sword] = w / total end
	return rows, total
end

-- The lowest level at which every entry of a step is unlocked (its full shipped odds).
local function fullOddsLevel(pool, step)
	local need = pool.gate
	for _, entry in ipairs(pool.entries) do
		if (entry.weights[step] or 0) > 0 then need = math.max(need, entry.minLevel) end
	end
	return need
end

-- A booted server with one loaded player and SpinService live.
local function setup()
	local g = Game.new({ scripts = { "RuntimeBootstrap", "PlayerDataStore" } })
	local SpinService = g:module("ServerScriptService.SpinService")
	local player = g:addPlayer({})
	local env = {
		g = g, player = player, SpinService = SpinService,
		SpinPools = g:module("ReplicatedStorage.Config.SpinPools"),
		PlayerDataService = g:module("ServerScriptService.PlayerDataService"),
	}
	-- Put the player at `step` of `zone` the way RecordKill would record it (best foe level, boss).
	function env.placeAt(zone, step, level)
		local d = SpinService.Depth(zone)
		local record = ({ { best = d.lo }, { best = d.mid }, { best = d.deep }, { best = d.deep, boss = true } })[step]
		env.PlayerDataService.SetField(player, "zoneDepth", { [zone] = record })
		g:setLevel(player, level)
		assert(SpinService.StepOf(player, zone) == step, "placeAt: SpinService disagrees on the step")
	end
	return env
end

return function(t)
	t.test("every step's odds sum to 100% (table weights and SpinPools.Odds, at every level)", function()
		local env = setup()
		local SpinPools = env.SpinPools
		for _, pool in ipairs(SpinPools.Pools) do
			for step = 1, SpinPools.STEPS do
				-- the table: everything but the ultra sums to exactly 100 (the ultra rides on top)
				local base = 0
				for _, entry in ipairs(pool.entries) do
					if not entry.ultra then base += entry.weights[step] or 0 end
				end
				t.near(base, 100, 1e-9, string.format("%s step %d table weights (ultra excluded)", pool.zone, step))
				-- the odds the server rolls and the board prints, at every level that can spin here
				for level = pool.gate, 100 do
					local rows, used = SpinPools.Odds(pool.zone, step, level)
					if t.check(rows ~= nil, "%s step %d Lv %d: Odds returned nothing", pool.zone, step, level) then
						local sum = 0
						for _, row in ipairs(rows) do
							sum += row.p
							t.check(not (row.locked and row.p > 0), "%s step %d Lv %d: locked %s has p %g", pool.zone,
								step, level, row.sword, row.p)
						end
						t.near(sum, 1, 1e-9, string.format("%s step %d Lv %d: sum of p", pool.zone, step, level))
						if level >= fullOddsLevel(pool, step) then
							t.eq(used, step, string.format("%s step %d Lv %d: step used", pool.zone, step, level))
						end
					end
				end
				if pool.gate > 1 then
					t.check(SpinPools.Odds(pool.zone, step, pool.gate - 1) == nil,
						"%s step %d: Odds must refuse a player under the gate (Lv %d)", pool.zone, step, pool.gate - 1)
				end
			end
		end
	end)

	t.test("SpinPools.Odds is exactly the shipped table (what the board shows is what is rolled)", function()
		local env = setup()
		for _, pool in ipairs(env.SpinPools.Pools) do
			for step = 1, env.SpinPools.STEPS do
				local level = fullOddsLevel(pool, step)
				local want = expectedOdds(pool, step, level)
				local rows = env.SpinPools.Odds(pool.zone, step, level)
				local seen = {}
				for _, row in ipairs(rows) do
					seen[row.sword] = true
					t.near(row.p, want[row.sword] or -1, 1e-12, string.format("%s step %d %s", pool.zone, step, row.sword))
				end
				for sword in pairs(want) do
					t.check(seen[sword], "%s step %d: %s missing from Odds()", pool.zone, step, sword)
				end
			end
		end
	end)

	t.test("100,000 spins per (area, step) through SpinService.Roll land on the shipped odds", function()
		local env = setup()
		local SpinPools, SpinService = env.SpinPools, env.SpinService
		local n = t.scale(SPINS_PER_STEP)
		local worstZ, worstLabel = 0, ""
		for _, pool in ipairs(SpinPools.Pools) do
			for step = 1, SpinPools.STEPS do
				local level = fullOddsLevel(pool, step)
				env.placeAt(pool.zone, step, level)
				local want = expectedOdds(pool, step, level)
				local counts = {}
				local wrongStep = 0
				for _ = 1, n do
					local row, zone, usedStep = SpinService.Roll(env.player, pool.zone)
					if not row or zone ~= pool.zone or usedStep ~= step then
						wrongStep += 1
					else
						counts[row.sword] = (counts[row.sword] or 0) + 1
					end
				end
				t.check(wrongStep == 0, "%s step %d: %d of %d spins did not roll this pool and step", pool.zone, step,
					wrongStep, n)
				for sword, c in pairs(counts) do
					t.check(want[sword] ~= nil, "%s step %d: landed %s, which is not in this step's pool (%d times)",
						pool.zone, step, sword, c)
				end
				for sword, p in pairs(want) do
					local c = counts[sword] or 0
					local sd = math.sqrt(n * p * (1 - p))
					local z = sd > 0 and (c - n * p) / sd or 0
					if math.abs(z) > worstZ then
						worstZ = math.abs(z)
						worstLabel = string.format("%s step %d %s: %d vs %.1f expected", pool.zone, step, sword, c, n * p)
					end
					t.check(math.abs(z) <= Z_LIMIT, "%s step %d %s: landed %d of %d (%.4f%%), shipped %.4f%% (z = %.1f)",
						pool.zone, step, sword, c, n, 100 * c / n, 100 * p, z)
				end
			end
		end
		t.note("%d spins per step, 32 steps; worst row |z| = %.2f (%s)", n, worstZ, worstLabel)
	end)

	t.test("no spin lands a sword above the player's level (every area, step and capped level)", function()
		local env = setup()
		local SpinPools, SpinService = env.SpinPools, env.SpinService
		local n = t.scale(SPINS_PER_CAP)
		local checked = 0
		for _, pool in ipairs(SpinPools.Pools) do
			for step = 1, SpinPools.STEPS do
				-- every level at which the step's roster changes: the gate, each entry's last locked
				-- level, and the full-odds level
				local levels = { [pool.gate] = true, [fullOddsLevel(pool, step)] = true }
				for _, entry in ipairs(pool.entries) do
					if (entry.weights[step] or 0) > 0 and entry.minLevel - 1 >= pool.gate then
						levels[entry.minLevel - 1] = true
					end
				end
				local ordered = {}
				for level in pairs(levels) do table.insert(ordered, level) end
				table.sort(ordered)
				for _, level in ipairs(ordered) do
					env.placeAt(pool.zone, step, level)
					for _ = 1, n do
						local row = SpinService.Roll(env.player, pool.zone)
						checked += 1
						if not t.check(row ~= nil, "%s step %d Lv %d: Roll returned nothing", pool.zone, step, level) then
							break
						end
						if not t.check(row.minLevel <= level, "%s step %d Lv %d: landed %s (min Lv %d)", pool.zone, step,
							level, row.sword, row.minLevel) then
							break
						end
					end
				end
			end
		end
		t.note("%d capped spins checked", checked)
	end)

	t.test("a low-level player who reached a later area still spins the pool their level allows", function()
		local env = setup()
		local SpinService, SpinPools = env.SpinService, env.SpinPools
		-- Lv 5 with a lucky hit on a Frostbound Glacier foe: the glacier (gate 17) is not open.
		env.PlayerDataService.SetField(env.player, "zoneDepth",
			{ IronLowlands = { best = 3 }, FrostboundGlacier = { best = 18 } })
		env.g:setLevel(env.player, 5)
		local zone = SpinService.PoolFor(env.player, nil)
		t.eq(zone, "IronLowlands", "default pool for a Lv 5 who reached the glacier")
		local named, why = SpinService.PoolFor(env.player, "FrostboundGlacier")
		t.eq(named, nil, "naming the glacier at Lv 5")
		t.eq(why, "level too low", "refusal reason")
		-- A Lv 3 at Iron Lowlands step 4 (boss down) rolls only what a Lv 3 may hold.
		env.placeAt("IronLowlands", 4, 3)
		for _ = 1, t.scale(20000) do
			local row = SpinService.Roll(env.player, nil)
			if not t.check(row and row.minLevel <= 3, "Lv 3 at the Warden of the Pit's step landed %s",
				row and row.sword or "nothing") then
				break
			end
		end
		-- An area never reached cannot be named.
		local none, reason = SpinService.PoolFor(env.player, "CelestialSummit")
		t.eq(none, nil, "unreached area")
		t.check(reason == "area not reached" or reason == "level too low", "unreached area reason: %s", tostring(reason))
		t.check(SpinPools.Get("NoSuchArea") == nil, "unknown area resolves to nothing")
	end)

	t.test("a granted spin sword is the rolled sword, its rarity, with exactly one prefix", function()
		local env = setup()
		local SpinPools, SpinService = env.SpinPools, env.SpinService
		for _, pool in ipairs(SpinPools.Pools) do
			for step = 1, SpinPools.STEPS do
				local level = fullOddsLevel(pool, step)
				env.placeAt(pool.zone, step, level)
				-- one Tool per live row (forced draw at the row's midpoint), through SpinService.Grant
				local rows = SpinPools.Odds(pool.zone, step, level)
				local acc = 0
				for _, row in ipairs(rows) do
					if row.p > 0 then
						local mid = acc + row.p / 2
						acc += row.p
						local rolled = SpinService.Roll(env.player, pool.zone, function() return mid end)
						t.eq(rolled and rolled.sword, row.sword, string.format("%s step %d forced draw", pool.zone, step))
						local tool, mods, fullName = SpinService.Grant(env.player, rolled)
						t.eq(tool:GetAttribute("BaseWeaponName"), row.sword, "granted sword")
						t.eq(tool:GetAttribute("Rarity"), row.rarity, row.sword .. " rarity")
						t.eq(tool:GetAttribute("PoolKey"), row.poolKey, row.sword .. " pool key")
						t.eq(#mods, 1, row.sword .. " prefix count")
						local names = 0
						for _ in string.gmatch(tool:GetAttribute("Prefixes") or "", "[^,%s]+") do names += 1 end
						t.eq(names, 1, row.sword .. " Prefixes attribute")
						t.check(string.find(fullName, row.sword, 1, true) ~= nil, "tool name %q lacks %s", fullName, row.sword)
						tool:Destroy()
					end
				end
			end
		end
	end)
end
