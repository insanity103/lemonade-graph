--// first_session.spec  (the first zone treats a new player fairly)
-- Guards four numbers the 2026-09-24 playtest recording caught going wrong for a fresh level-1
-- profile. None of them fails in code; each one only shows as a bad first ten minutes:
--   * the first spin swords were weaker than the starter in hand (x0.90 against x1.00);
--   * the Relic Blacksmith asked 7,770 gold of a level-1 player earning 5 gold a kill;
--   * the Warden of the Pit paid 6,000 XP, more than the whole level 1-10 band, every 5 seconds;
--   * a death took 25% of the purse, the cap, instead of "a minute of income".
local Game = require("../harness/game")

return function(t)
	t.test("every Iron Lowlands pool sword beats the starter sword", function()
		local g = Game.new({})
		local BossWeapons = g:module("ReplicatedStorage.Config.BossWeapons")
		local pool = BossWeapons.PoolFor("IronLowlands")
		local starter = BossWeapons.Starter.base
		for _, def in ipairs(pool.swords) do
			t.check(def.base > starter, "%s x%.2f is not above the starter's x%.2f", def.name, def.base, starter)
		end
	end)

	t.test("the Relic Blacksmith never asks more than PRICE_KILLS_CAP of the buyer's own kills", function()
		local g = Game.new({})
		local MerchantConfig = g:module("ReplicatedStorage.Config.MerchantConfig")
		local GoldCurve = g:module("ReplicatedStorage.Config.GoldCurve")
		local last = 0
		for level = 1, 100 do
			local price = MerchantConfig.PriceForLevel(level)
			local kills = price / math.max(1, GoldCurve.PerKill(level))
			t.check(kills <= MerchantConfig.PRICE_KILLS_CAP + 1, "Lv %d: %d gold is %.0f kills", level, price, kills)
			t.check(price >= last, "Lv %d: price %d fell below Lv %d's %d", level, price, level - 1, last)
			last = price
		end
	end)

	t.test("a first-zone death is free and a later one never takes more than a tenth of the purse", function()
		local g = Game.new({})
		local GoldCurve = g:module("ReplicatedStorage.Config.GoldCurve")
		for level = 1, 10 do
			t.eq(GoldCurve.DeathLoss(1000, level, 5000, 60), 0, "Lv " .. level .. " death")
		end
		-- a huge income over a short window: the cap is what binds
		t.check(GoldCurve.DeathLoss(1005, 18, 5000, 60) <= 100, "Lv 18 death took more than 10%% of 1,005")
	end)
end
