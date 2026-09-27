--// daily_streak.spec  (one claim a UTC day, the week advances, a missed day starts it over)
-- Wave 1 of the 2026-09-25 fun plan (DailyConfig / DailyStreak).
local Game = require("../harness/game")

local function boot(userId, attributes)
	local g = Game.new({ scripts = true, studio = true })
	local SaveConfig = g:module("ReplicatedStorage.Config.SaveConfig")
	local store = g.world:dataStore(SaveConfig.DATASTORE_NAME)
	store:Seed(SaveConfig.KEY_PREFIX .. tostring(userId), { leaderstats = { Level = 12, Gold = 100 },
		attributes = attributes or {}, swords = {}, vault = {} })
	g:runScript("DailyStreak")
	local p = g:addPlayer({ userId = userId })
	g:advance(1)
	return g, p
end

local function relics(p)
	local n = 0
	for _, c in ipairs({ p:FindFirstChildOfClass("Backpack"), p.Character }) do
		for _, t in ipairs(c and c:GetChildren() or {}) do
			if t:IsA("Tool") and t:GetAttribute("BossDrop") == true and t:GetAttribute("Starter") ~= true then n += 1 end
		end
	end
	return n
end

return function(t)
	t.test("the day arithmetic: kept, claimed today, missed, wraps after day 7", function()
		local g = Game.new({})
		local D = g:module("ReplicatedStorage.Config.DailyConfig")
		t.eq(select(1, D.Next(0, 0, 100)), 1, "never claimed: day 1")
		t.eq(select(2, D.Next(0, 0, 100)), true, "... claimable")
		t.eq(select(1, D.Next(99, 3, 100)), 4, "claimed yesterday on day 3: day 4 today")
		t.eq(select(2, D.Next(100, 3, 100)), false, "claimed today: nothing more today")
		t.eq(select(1, D.Next(97, 5, 100)), 1, "missed a day: the week starts over")
		t.eq(select(1, D.Next(99, 7, 100)), 1, "after day 7 comes day 1")
	end)

	t.test("a first claim pays day 1 gold; a second claim the same day pays nothing", function()
		local g, p = boot(7201)
		t.eq(p:GetAttribute("StreakClaimable"), true, "claimable on a fresh profile")
		local gold0 = p.leaderstats.Gold.Value
		g:remote("DailyAction").OnServerEvent:Fire(p, "Claim")
		g:advance(0.5)
		local gained = p.leaderstats.Gold.Value - gold0
		t.check(gained > 0, "day 1 paid gold")
		t.eq(p:GetAttribute("StreakDay"), 1, "day 1 recorded")
		t.eq(p:GetAttribute("StreakClaimable"), false, "nothing more today")
		g:remote("DailyAction").OnServerEvent:Fire(p, "Claim")
		g:advance(0.5)
		t.eq(p.leaderstats.Gold.Value - gold0, gained, "the second claim paid nothing")
	end)

	t.test("claiming day 7 the day after day 6 gives an Epic-or-better sword and tokens", function()
		local probe = Game.new({})
		local D = probe:module("ReplicatedStorage.Config.DailyConfig")
		local yesterday = D.DayNumber(probe.world.epoch) - 1 -- the harness clock, not the real one
		local g, p = boot(7202, { StreakDay = 6, StreakLastClaim = yesterday })
		t.eq(p:GetAttribute("StreakNext"), 7, "day 7 is up")
		local tokens0 = p:GetAttribute("Tokens") or 0
		local swords0 = relics(p)
		g:remote("DailyAction").OnServerEvent:Fire(p, "Claim")
		g:advance(0.5)
		t.eq(relics(p) - swords0, 1, "one sword")
		local rank = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
		local best = 0
		for _, c in ipairs({ p:FindFirstChildOfClass("Backpack") }) do
			for _, tool in ipairs(c:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("Starter") ~= true then
					best = math.max(best, rank[tool:GetAttribute("Rarity")] or 0)
				end
			end
		end
		t.check(best >= rank.Epic, "the sword is Epic or better")
		t.check((p:GetAttribute("Tokens") or 0) > tokens0, "and tokens")
		t.eq(p:GetAttribute("StreakNext"), 1, "tomorrow the week starts again")
	end)
end
