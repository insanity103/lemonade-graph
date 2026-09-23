--// leveling.spec  (XP, level-ups, skill points, kill gold, the death penalty, regeneration)
-- The real LevelingSystem runs with the persistence and kill-reward scripts. Kills go through the
-- engine's path (a "creator" tag, then Humanoid.Died); XP, levels and gold are read off the
-- leaderstats the game saves. Expected numbers come from the public configs (Config.XPCurve,
-- Config.GoldCurve), so a change to the curve moves the test with it, but LevelingSystem drifting
-- from the curve does not.
local Game = require("../harness/game")
local D = require("../harness/datatypes")
local Vector3 = D.Vector3

local SCRIPTS = { "RuntimeBootstrap", "PlayerDataStore", "LevelingSystem", "SwordSystem", "SwordDropSystem" }
local ARENA = Vector3.new(300, 3, 300) -- out of town
local USER = 808

local function boot(options)
	options = options or {}
	local g = Game.new({ scripts = SCRIPTS })
	local player = g:addPlayer({ userId = USER, position = ARENA, profile = options.profile })
	return g, player, g:module("ReplicatedStorage.Config.XPCurve"), g:module("ReplicatedStorage.Config.GoldCurve")
end

-- Kill a foe worth `xp` (its ExperienceReward, as EnemyCombat stamps it). Returns the model.
local function killFoe(g, player, options)
	options = options or {}
	local model = g:spawnEnemy({ zone = options.zone or "IronLowlands", level = options.level or 1,
		role = options.role, position = ARENA + Vector3.new(4, 0, 0) })
	if options.xp ~= false then model:SetAttribute("ExperienceReward", options.xp or 50) end
	g:kill(player, model)
	return model
end

local function stats(player)
	local ls = player.leaderstats
	return ls.Level.Value, ls.Experience.Value, ls.Gold.Value
end

local function lastFired(g, name, player)
	local log = g.world:fired(g:remote(name))
	for i = #log, 1, -1 do
		if log[i].player == player then return log[i].args end
	end
	return nil
end

return function(t)
	t.test("the XP curve: 100 to reach Lv 2, the opening hump only on Lv 2-10, the 15% body after", function()
		local _, _, XPCurve = boot()
		t.eq(XPCurve.Required(1), 100, "XP from Lv 1 to 2")
		t.eq(XPCurve.OpeningExtra(1), 0, "hump at Lv 1")
		t.eq(XPCurve.OpeningExtra(XPCurve.OPENING_UNTIL + 1), 0, "hump just past the opening zone")
		local hump = 0
		for lv = 2, XPCurve.OPENING_UNTIL do
			t.check(XPCurve.OpeningExtra(lv) > 0, "no hump at Lv %d", lv)
			hump += XPCurve.OpeningExtra(lv)
		end
		t.eq(hump, 165 * XPCurve.OPENING_K, "total opening hump (documented as 165 K)")
		for lv = XPCurve.OPENING_UNTIL + 1, 150 do
			t.eq(XPCurve.Required(lv), math.floor(100 * 1.15 ^ (lv - 1)), "Lv " .. lv .. " is the untouched exponential body")
		end
		for lv = 1, 150 do
			t.check(XPCurve.Required(lv) > 0, "Lv %d requires %d XP", lv, XPCurve.Required(lv))
			t.eq(XPCurve.Cumulative(lv + 1) - XPCurve.Cumulative(lv), XPCurve.Required(lv), "Cumulative step at Lv " .. lv)
		end
	end)

	t.test("the XP bar the client reads (ExperienceRequired) is XPCurve.Required at every level", function()
		local g, player, XPCurve = boot()
		for lv = 1, 120 do
			g:setLevel(player, lv)
			if not t.eq(player:GetAttribute("ExperienceRequired"), XPCurve.Required(lv), "ExperienceRequired at Lv " .. lv) then
				break
			end
		end
	end)

	t.test("a kill pays the foe's ExperienceReward, boosted by Experience Gain (capped at +35%) and rebirth", function()
		local g, player = boot()
		g:setLevel(player, 60) -- a deep level so none of these kills levels up
		local function gain(xp, expGain, rebirthMult)
			player:SetAttribute("ExperienceGain", expGain or 0)
			player:SetAttribute("RebirthXPMult", rebirthMult)
			local _, before = stats(player)
			killFoe(g, player, { xp = xp })
			local _, after = stats(player)
			return after - before
		end
		t.eq(gain(1000), 1000, "plain kill")
		t.eq(gain(1000, 20), 1100, "Experience Gain 20 (+10%)")
		t.eq(gain(1000, 70), 1350, "Experience Gain 70 (+35%, the cap)")
		t.eq(gain(1000, 5000), 1350, "Experience Gain 5000 (still capped at +35%)")
		t.eq(gain(1000, 0, 2), 2000, "RebirthXPMult 2")
		t.eq(gain(999, 20, 1.5), math.floor(999 * 1.1 * 1.5), "rounding down")
		t.eq(gain(false), 50, "a rig with no ExperienceReward pays 50")
	end)

	t.test("XP carries over, one big kill levels up several times, 8 skill points a level, health refills", function()
		local g, player, XPCurve = boot()
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		humanoid.Health = 30
		killFoe(g, player, { xp = XPCurve.Cumulative(5) + 37 })
		local level, xp = stats(player)
		t.eq(level, 5, "level after a kill worth Cumulative(5) + 37")
		t.eq(xp, 37, "XP carried into Lv 5")
		t.eq(player:GetAttribute("SkillPoints"), 4 * 8, "skill points for 4 level-ups")
		t.eq(humanoid.Health, humanoid.MaxHealth, "a level-up refills health")
		t.check(lastFired(g, "LevelUpBurst", player) ~= nil, "the level-up burst was sent to the player")
		-- exactly enough for the next level lands on it with 0 left over
		killFoe(g, player, { xp = XPCurve.Required(5) - 37 })
		level, xp = stats(player)
		t.eq(level, 6, "level after topping up exactly")
		t.eq(xp, 0, "XP left after landing exactly on a level")
		-- one short of the next does not level
		killFoe(g, player, { xp = XPCurve.Required(6) - 1 })
		level, xp = stats(player)
		t.eq(level, 6, "one XP short of Lv 7")
		t.eq(xp, XPCurve.Required(6) - 1, "XP one short")
	end)

	t.test("levels, XP, gold and skill points reach the DataStore and come back on rejoin", function()
		local g, player, XPCurve = boot()
		killFoe(g, player, { xp = XPCurve.Cumulative(12) + 55, level = 12 })
		local level, xp, gold = stats(player)
		local points = player:GetAttribute("SkillPoints")
		g:removePlayer(player)
		local SaveConfig = g:module("ReplicatedStorage.Config.SaveConfig")
		local rec = g.world:dataStore(SaveConfig.DATASTORE_NAME):Read(SaveConfig.KEY_PREFIX .. USER)
		t.eq(rec.leaderstats.Level, level, "saved Level")
		t.eq(rec.leaderstats.Experience, xp, "saved Experience")
		t.eq(rec.leaderstats.Gold, gold, "saved Gold")
		t.eq(rec.attributes.SkillPoints, points, "saved SkillPoints")
		local g2, p2, XP2 = boot({ profile = rec })
		local l2, x2, gold2 = stats(p2)
		t.eq(l2, level, "Level after rejoining")
		t.eq(x2, xp, "Experience after rejoining")
		t.eq(gold2, gold, "Gold after rejoining")
		t.eq(p2:GetAttribute("ExperienceRequired"), XP2.Required(level), "the XP bar after rejoining")
		t.eq(p2:GetAttribute("SkillPoints"), points, "SkillPoints after rejoining")
	end)

	t.test("a kill pays GoldCurve.PerKill(level, role) gold, times the rebirth gold multiplier", function()
		local g, player, _, GoldCurve = boot()
		g:setLevel(player, 100)
		local cases = {
			{ level = 1, role = nil, as = "minion" }, { level = 10, role = "elite", as = "elite" },
			{ level = 25, role = "boss", as = "boss" }, { level = 14, role = "warden", as = "warden" },
			{ level = 70, role = nil, as = "minion" },
		}
		for _, c in ipairs(cases) do
			for _, mult in ipairs({ 1, 1.75 }) do
				player:SetAttribute("RebirthGoldMult", mult)
				local _, _, before = stats(player)
				killFoe(g, player, { level = c.level, role = c.role, xp = 1 })
				local _, _, after = stats(player)
				t.eq(after - before, math.floor(GoldCurve.PerKill(c.level, c.as) * mult),
					string.format("Lv %d %s kill at gold x%.2f", c.level, c.as, mult))
			end
		end
	end)

	t.test("the kill streak counts kills inside the streak window and resets on death", function()
		local g, player = boot()
		local WM = g:module("ReplicatedStorage.Config.WeaponModifiers")
		for i = 1, 4 do
			killFoe(g, player)
			t.eq(player:GetAttribute("KillStreak"), i, "streak after kill " .. i)
			g:advance(WM.Luck.STREAK_WINDOW - 1)
		end
		g:advance(WM.Luck.STREAK_WINDOW + 1)
		killFoe(g, player)
		t.eq(player:GetAttribute("KillStreak"), 1, "a kill after the window starts a new streak")
		killFoe(g, player)
		player.Character:FindFirstChildOfClass("Humanoid").Health = 0
		g:flush()
		t.eq(player:GetAttribute("KillStreak"), 0, "streak after dying")
	end)

	t.test("dying costs 60 s of the player's own recent income, capped at 25% of the purse, free to Lv 8", function()
		local function deathLoss(level, killAt, dieAt, purse)
			-- the purse arrives with the saved profile: gold restored on join is not income
			local g, player, _, GoldCurve = boot({ profile = { leaderstats = { Level = level, Gold = purse or 0 } } })
			local start = g.world.clock
			local earned = 0
			for _, at in ipairs(killAt) do
				g:advance(at - (g.world.clock - start))
				local _, _, before = stats(player)
				killFoe(g, player, { level = level, xp = 1 })
				local _, _, after = stats(player)
				earned += after - before
			end
			g:advance(dieAt - (g.world.clock - start))
			local _, _, before = stats(player)
			player.Character:FindFirstChildOfClass("Humanoid").Health = 0
			g:flush()
			local _, _, after = stats(player)
			return before - after, before, earned, g.world.clock - start, GoldCurve
		end
		-- Lv 20: ten kills over 100 s, then death at 120 s
		local kills = {}
		for i = 1, 10 do kills[i] = i * 10 end
		local lost, purse, earned, elapsed, GoldCurve = deathLoss(20, kills, 120)
		t.check(lost > 0, "a Lv 20 death with income cost nothing")
		t.eq(lost, GoldCurve.DeathLoss(purse, 20, earned, elapsed), "Lv 20 death loss vs GoldCurve.DeathLoss")
		t.check(lost <= purse * GoldCurve.DEATH_PURSE_CAP, "loss %d is over %d%% of the %d purse", lost,
			GoldCurve.DEATH_PURSE_CAP * 100, purse)
		-- income older than the window no longer counts
		local stale = deathLoss(20, { 5 }, GoldCurve.DEATH_INCOME_WINDOW + 60)
		t.eq(stale, 0, "a death long after the last income")
		-- the opening zone is free
		local free = deathLoss(GoldCurve.DEATH_FREE_MAX_LEVEL, kills, 120)
		t.eq(free, 0, "a death at Lv " .. GoldCurve.DEATH_FREE_MAX_LEVEL)
		-- a big purse with a little income: the income sets the price, not the purse
		local rich, richPurse = deathLoss(30, { 10 }, 100, 1000000)
		t.check(rich < richPurse * GoldCurve.DEATH_PURSE_CAP, "a rich player lost %d of %d: priced on the purse", rich, richPurse)
	end)

	t.test("a death keeps the equipped sword (back to the backpack) below the shatter level", function()
		local g, player = boot()
		local tool = player.Backpack:FindFirstChildOfClass("Tool")
		tool.Parent = player.Character
		g:flush()
		player.Character:FindFirstChildOfClass("Humanoid").Health = 0
		g:flush()
		t.eq(tool.Parent, player.Backpack, "the equipped sword after a Lv 1 death")
	end)

	t.test("spending skill points: one point per press, valid stats only, Health adds 20 max HP", function()
		local g, player = boot()
		local remote = g:remote("SpendSkillPoint")
		player:SetAttribute("SkillPoints", 3)
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		remote.OnServerEvent:Fire(player, "Strength")
		g:flush()
		t.eq(player:GetAttribute("Strength"), 1, "Strength after spending")
		t.eq(player:GetAttribute("SkillPoints"), 2, "points after spending")
		remote.OnServerEvent:Fire(player, "Strength") -- inside the 0.1 s cooldown
		g:flush()
		t.eq(player:GetAttribute("Strength"), 1, "a second press inside the cooldown")
		g:advance(0.2)
		remote.OnServerEvent:Fire(player, "WeaponLevel") -- not a spendable stat
		remote.OnServerEvent:Fire(player, 42)
		g:flush()
		t.eq(player:GetAttribute("SkillPoints"), 2, "points after invalid requests")
		g:advance(0.2)
		remote.OnServerEvent:Fire(player, "Health")
		g:flush()
		t.eq(humanoid.MaxHealth, 100 + 20, "MaxHealth after one Health point")
		t.eq(humanoid.Health, humanoid.MaxHealth, "health refilled to the new max")
		g:advance(0.2)
		remote.OnServerEvent:Fire(player, "Defense")
		g:advance(0.2)
		remote.OnServerEvent:Fire(player, "Defense")
		g:flush()
		t.eq(player:GetAttribute("Defense"), 1, "Defense: the second press had no point to spend")
		t.eq(player:GetAttribute("SkillPoints"), 0, "points at the end")
	end)

	t.test("health regenerates only after 4 s without taking damage", function()
		local g, player = boot()
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		g:advance(1)
		humanoid.Health = 50
		g:advance(3.4)
		t.eq(humanoid.Health, 50, "health 3.4 s after a hit")
		g:advance(2)
		t.check(humanoid.Health > 50, "no regeneration 5.4 s after a hit (health %s)", tostring(humanoid.Health))
		humanoid.Health = 40 -- hit again: the clock restarts
		g:advance(3)
		t.eq(humanoid.Health, 40, "health 3 s after a second hit")
		g:advance(30)
		t.eq(humanoid.Health, humanoid.MaxHealth, "fully regenerated")
	end)

	t.test("after a fight the player's client is told the XP it earned (once, 3 s after the last kill)", function()
		local g, player = boot()
		g:setLevel(player, 60)
		killFoe(g, player, { xp = 120 })
		g:advance(1)
		killFoe(g, player, { xp = 80 })
		g:advance(1)
		t.eq(lastFired(g, "XPGain", player), nil, "XP toast while still fighting")
		g:advance(3)
		local args = lastFired(g, "XPGain", player)
		t.eq(args and args[2], 200, "XP toast total")
		g.world:clearFired(g:remote("XPGain"))
		g:advance(5)
		t.eq(lastFired(g, "XPGain", player), nil, "the toast is sent once")
	end)
end
