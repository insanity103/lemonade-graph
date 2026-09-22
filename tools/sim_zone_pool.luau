-- tools/sim_zone_pool.luau | Studio-only measurement of the shipped spin pools.
-- Run on the SERVER of a Studio play session WITH a player (Roblox Studio MCP
-- run_script_in_play_mode, mode start_play). It drives the real code, never a copy:
--   1. For every (area, depth step) it writes the player's real profile record `zoneDepth` the way
--      SpinService.RecordKill would, sets their level, and calls SpinService.Roll(player, zone)
--      N times, counting the sword that lands.
--   2. The level cap: a Lv 1 and a Lv 3 player at every Iron Lowlands step; a Lv 5 player who has
--      "reached" the Frostbound Glacier (default pool must stay the lowlands).
--   3. RecordKill on live rigs, and SpinService.Grant building real Tools for a sample of rolls.
--   4. A pre-spin profile (no zoneDepth) re-applied at Lv 40 with the Warden of the Pit beaten.
-- Saving is refused while workspace.GuiShowcase is set, so nothing here reaches the DataStore.
-- Prints "SIMZ <json>" lines.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local SpinPools = require(RS.Config.SpinPools)
local SpinService = require(SSS.SpinService)
local PDS = require(SSS.PlayerDataService)
local BossWeapons = require(RS.Config.BossWeapons)

local N = 20000         -- spins per (area, step) on steps 1-3, and for the cap checks
local N_BOSS = 200000   -- spins per boss step (run the deep areas in 250k chunks, several per step: the
                        -- ultras are 1 in 201 .. 1 in 5,001, so the Summit needs ~1M spins for ~200 hits)
local N_CAP = 10000
local BUILD_N = 40
-- Chunked runs (a single 2M-spin run crashed Studio): set workspace attribute SimJobs to a JSON list
-- of {"zone":..,"step":..,"n":..} before this script and it rolls only those jobs, emitting one
-- "step" line each (a boss step split over several chunks is summed afterwards), and runs the
-- extra checks (caps, tokens, veil, builds, migration) only when SimExtras is true. SimSeed sets the
-- seed so split chunks of one step draw different spins. With no SimJobs it runs everything.
local JOBS_JSON = workspace:GetAttribute("SimJobs")
local JOBS = (typeof(JOBS_JSON) == "string" and JOBS_JSON ~= "") and HttpService:JSONDecode(JOBS_JSON) or nil
local RUN_EXTRAS = JOBS == nil or workspace:GetAttribute("SimExtras") == true
workspace:SetAttribute("GuiShowcase", "SimZonePool") -- no stage has this name: only the save guard reads it
math.randomseed(workspace:GetAttribute("SimSeed") or 20260921)

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local t = os.clock()
while not PDS.IsReady(player) and os.clock() - t < 30 do task.wait(0.2) end
local lvStat = player.leaderstats.Level

local function recordFor(zone, step)
	local d = SpinService.Depth(zone)
	if step == 1 then return { best = d.lo } end
	if step == 2 then return { best = d.mid } end
	if step == 3 then return { best = d.deep } end
	return { best = d.deep, boss = true }
end

-- Optional collector: set workspace attribute SimPostUrl (e.g. a local listener on 127.0.0.1) before
-- play and every SIMZ line is also POSTed there, so long runs are not lost to console truncation.
local POST_URL = workspace:GetAttribute("SimPostUrl")
local function emit(tag, obj)
	local line = HttpService:JSONEncode({ tag = tag, data = obj })
	print("SIMZ " .. line)
	if typeof(POST_URL) == "string" and POST_URL ~= "" then
		pcall(HttpService.PostAsync, HttpService, POST_URL, line, Enum.HttpContentType.ApplicationJson)
	end
end

-- 1. every area x step, at a level that unlocks the whole pool
local function rollStep(pool, step, n, maxLv)
	PDS.SetField(player, "zoneDepth", { [pool.zone] = recordFor(pool.zone, step) })
	local seenStep = SpinService.StepOf(player, pool.zone)
	local counts = {}
	for i = 1, n do
		local row = SpinService.Roll(player, pool.zone)
		counts[row.sword] = (counts[row.sword] or 0) + 1
		if i % 20000 == 0 then task.wait() end
	end
	local odds = SpinPools.Odds(pool.zone, step, maxLv)
	local rows = {}
	local sumBase = 0
	for _, r in ipairs(odds) do
		local base = BossWeapons.Resolve(r.poolKey, r.sword, r.rarity).baseMult
		sumBase += base * (counts[r.sword] or 0)
		table.insert(rows, { s = r.sword, r = r.rarity, lv = r.minLevel, p = r.p, n = counts[r.sword] or 0,
			tag = r.tag, from = r.from, base = base, pk = r.poolKey, ultra = r.ultra, great = r.great })
	end
	local _, _, poolRows = SpinService.PoolFor(player, pool.zone)
	return { step = step, stepSeen = seenStep, rows = rows, meanBase = sumBase / n, n = n,
		cost = SpinPools.CostFor(pool.zone, step), serverRows = poolRows and #poolRows or 0 }
end
local function poolMaxLv(pool)
	local maxLv = 1
	for _, e in ipairs(pool.entries) do maxLv = math.max(maxLv, e.minLevel) end
	return maxLv
end
if JOBS then
	for _, job in ipairs(JOBS) do
		local pool = SpinPools.ByZone and SpinPools.ByZone[job.zone]
		if not pool then
			for _, p in ipairs(SpinPools.Pools) do if p.zone == job.zone then pool = p end end
		end
		local maxLv = poolMaxLv(pool)
		lvStat.Value = maxLv
		local d = SpinService.Depth(pool.zone)
		emit("step", { zone = pool.zone, gateLv = pool.gate, level = maxLv, lo = d.lo, mid = d.mid, deep = d.deep,
			bossLevel = d.bossLevel, st = rollStep(pool, job.step, job.n, maxLv) })
		task.wait()
	end
end
for _, pool in ipairs(JOBS and {} or SpinPools.Pools) do
	local maxLv = 1
	for _, e in ipairs(pool.entries) do maxLv = math.max(maxLv, e.minLevel) end
	lvStat.Value = maxLv
	local d = SpinService.Depth(pool.zone)
	local steps = {}
	for step = 1, SpinPools.STEPS do
		PDS.SetField(player, "zoneDepth", { [pool.zone] = recordFor(pool.zone, step) })
		local seenStep = SpinService.StepOf(player, pool.zone)
		local counts = {}
		local n = step == SpinPools.STEPS and N_BOSS or N
		for i = 1, n do
			local row = SpinService.Roll(player, pool.zone)
			counts[row.sword] = (counts[row.sword] or 0) + 1
			if i % 20000 == 0 then task.wait() end
		end
		local odds = SpinPools.Odds(pool.zone, step, maxLv)
		local rows = {}
		local sumBase = 0
		for _, r in ipairs(odds) do
			-- the listed base damage multiplier the factory builds this row at (base x rarity step)
			local base = BossWeapons.Resolve(r.poolKey, r.sword, r.rarity).baseMult
			sumBase += base * (counts[r.sword] or 0)
			table.insert(rows, { s = r.sword, r = r.rarity, lv = r.minLevel, p = r.p, n = counts[r.sword] or 0,
				tag = r.tag, from = r.from, base = base, pk = r.poolKey, ultra = r.ultra, great = r.great })
		end
		local _, _, poolRows = SpinService.PoolFor(player, pool.zone)
		table.insert(steps, { step = step, stepSeen = seenStep, rows = rows, meanBase = sumBase / n, n = n,
			cost = SpinPools.CostFor(pool.zone, step), serverRows = poolRows and #poolRows or 0 })
		task.wait()
	end
	emit("zone", { zone = pool.zone, gateLv = pool.gate, level = maxLv, n = N, nBoss = N_BOSS, steps = steps,
		mid = d.mid, deep = d.deep, lo = d.lo, bossLevel = d.bossLevel })
end

if not RUN_EXTRAS then
	print("SIMZ_DONE " .. string.format("%.1f", os.clock() - t))
	return
end

-- 2. level caps
for _, lv in ipairs({ 1, 3 }) do
	lvStat.Value = lv
	for step = 1, 4 do
		PDS.SetField(player, "zoneDepth", { IronLowlands = recordFor("IronLowlands", step) })
		local counts, above = {}, 0
		for _ = 1, N_CAP do
			local row = SpinService.Roll(player, "IronLowlands")
			counts[row.sword] = (counts[row.sword] or 0) + 1
			if row.minLevel > lv then above += 1 end
		end
		emit("cap", { level = lv, step = step, n = N_CAP, counts = counts, aboveLevel = above })
	end
end
lvStat.Value = 5
PDS.SetField(player, "zoneDepth", { IronLowlands = { best = 6 }, FrostboundGlacier = { best = 18 } })
do
	local counts = {}
	local zoneUsed
	for _ = 1, N_CAP do
		local row, z = SpinService.Roll(player)
		zoneUsed = z
		counts[row.sword] = (counts[row.sword] or 0) + 1
	end
	local _, reason = SpinService.PoolFor(player, "FrostboundGlacier")
	emit("earlyReach", { level = 5, defaultZone = zoneUsed, counts = counts, namedGlacier = reason })
end

-- 2b. token pacing: what one kill pays in each area (real TokenRules.ForKill, 2,000 minion kills
-- and 500 boss/warden kills per area) against what a spin costs there (SpinPools.CostFor).
do
	local TokenRules = require(RS.Config.TokenRules)
	local out = {}
	for _, pool in ipairs(SpinPools.Pools) do
		local sumM, lo, hi = 0, math.huge, 0
		for _ = 1, 2000 do
			local v = TokenRules.ForKill("minion", nil, pool.zone)
			sumM += v; lo = math.min(lo, v); hi = math.max(hi, v)
		end
		local role = pool.boss and "boss" or "warden"
		local sumB = 0
		for _ = 1, 500 do sumB += TokenRules.ForKill(role, nil, pool.zone) end
		local costs = {}
		for step = 1, SpinPools.STEPS do costs[step] = SpinPools.CostFor(pool.zone, step) end
		table.insert(out, { zone = pool.zone, minionMean = sumM / 2000, minionLo = lo, minionHi = hi,
			bossRole = role, bossMean = sumB / 500, costs = costs })
	end
	emit("tokens", out)
end

-- 2c. the "??" veil: SwordFound reads the saved SwordsFound list the spin station writes.
do
	local before = player:GetAttribute("SwordsFound")
	player:SetAttribute("SwordsFound", "")
	local a = SpinPools.SwordFound(player, "Pit Sovereign")
	player:SetAttribute("SwordsFound", "Slag Falchion,Pit Sovereign")
	local b = SpinPools.SwordFound(player, "Pit Sovereign")
	local c = SpinPools.SwordFound(player, "Pit")
	player:SetAttribute("SwordsFound", before)
	emit("veil", { emptyFound = a, afterFound = b, partialNameFound = c })
end

-- 2d. what the board and the shout read: every ultra / GREAT / Chase row of every step, straight out of
-- SpinPools.Odds() at a level that unlocks the pool, with whether GameplayServices would call it
-- SERVER NEWS (p <= NEWS_P) and whether it is hidden as "??" for a player who has found nothing.
do
	local rows = {}
	local before = player:GetAttribute("SwordsFound")
	player:SetAttribute("SwordsFound", "")
	for _, pool in ipairs(SpinPools.Pools) do
		for step = 1, SpinPools.STEPS do
			local odds = SpinPools.Odds(pool.zone, step, 200)
			for _, r in ipairs(odds or {}) do
				if r.ultra or r.great or r.tag == "Chase" then
					table.insert(rows, { zone = pool.zone, step = step, s = r.sword, p = r.p, tag = r.tag,
						ultra = r.ultra or nil, great = r.great or nil,
						news = r.ultra and r.p <= SpinPools.NEWS_P or nil,
						hidden = r.tag == "Chase" and not SpinPools.SwordFound(player, r.sword) or nil })
				end
			end
		end
	end
	player:SetAttribute("SwordsFound", before)
	emit("news", { NEWS_P = SpinPools.NEWS_P, rows = rows })
end

-- 3. RecordKill on live rigs + Grant
lvStat.Value = 10
PDS.SetField(player, "zoneDepth", {})
local killLog = {}
local rigs = {}
for _, m in ipairs(workspace:GetDescendants()) do
	if m:IsA("Model") and m:GetAttribute("Zone") == "IronLowlands" and m:GetAttribute("EnemyLevel") then
		table.insert(rigs, m)
	end
end
table.sort(rigs, function(a, b) return (a:GetAttribute("EnemyLevel") or 0) < (b:GetAttribute("EnemyLevel") or 0) end)
for _, m in ipairs(rigs) do
	SpinService.RecordKill(player, m)
	table.insert(killLog, { level = m:GetAttribute("EnemyLevel"), role = m:GetAttribute("SpawnRole"),
		step = player:GetAttribute("Depth_IronLowlands"), spinStep = player:GetAttribute("SpinStep") })
end
emit("kills", killLog)

local builds = {}
PDS.SetField(player, "zoneDepth", { IronLowlands = { best = 6, boss = true } })
local mismatch = 0
for _ = 1, BUILD_N do
	local row = SpinService.Roll(player, "IronLowlands")
	local tool, mods, fullName, data = SpinService.Grant(player, row)
	if data.name ~= row.sword or data.rarity ~= row.rarity or tool:GetAttribute("PoolKey") ~= row.poolKey then
		mismatch += 1
	end
	table.insert(builds, { sword = row.sword, rarity = tool:GetAttribute("Rarity"), name = fullName,
		prefixes = #mods, mult = tool:GetAttribute("DamageMult") })
	tool:Destroy()
end
emit("builds", { n = BUILD_N, mismatch = mismatch, sample = { builds[1], builds[2], builds[3], builds[4], builds[5] } })

-- 3b. every entry of every pool, built once as a real Tool (carried-in swords keep their home pool)
do
	local n, bad, badList = 0, 0, {}
	for _, pool in ipairs(SpinPools.Pools) do
		for _, e in ipairs(pool.entries) do
			lvStat.Value = math.max(e.minLevel, pool.gate)
			local tool, _, _, data = SpinService.Grant(player, { sword = e.sword, rarity = e.rarity, poolKey = e.poolKey, p = 0.01 })
			n += 1
			if data.name ~= e.sword or data.rarity ~= e.rarity or tool:GetAttribute("PoolKey") ~= e.poolKey then
				bad += 1
				table.insert(badList, e.sword .. "/" .. tostring(data.name) .. "/" .. tostring(data.rarity))
			end
			tool:Destroy()
		end
	end
	emit("allBuilds", { n = n, mismatch = bad, bad = badList })
end

-- 4. migration of a pre-spin profile
lvStat.Value = 40
PDS.SetField(player, "zoneDepth", nil)
PDS.SetField(player, "bossFirstDrops", { Boss_Gorgon = true })
player:SetAttribute("DataLoaded", false)
player:SetAttribute("DataLoaded", true)
task.wait(0.2)
local mig = {}
for _, z in ipairs(SpinPools.Order) do mig[z] = player:GetAttribute(SpinPools.DepthAttr(z)) end
emit("migrate", { level = 40, depth = mig, spinZone = player:GetAttribute("SpinZone"), spinStep = player:GetAttribute("SpinStep") })

-- GuiShowcase stays set: the play session ends with saving refused, so no test value is kept.
print("SIMZ_DONE " .. string.format("%.1f", os.clock() - t))
