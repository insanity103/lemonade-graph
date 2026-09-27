--// first_boss_reward.spec  (a boss's first kill hands over one sword from its pool, once)
-- Regression for the 2026-09-24 playtest's quest soft-lock (quests-2, quests-r2-q4lock): kills pay
-- tokens only, so "Claim the Blade" (a sword from the Warden's pool) could never be finished.
local Game = require("../harness/game")
local D = require("../harness/datatypes")
local Vector3 = D.Vector3

local function poolSwords(p, poolKey)
	local n = 0
	for _, c in ipairs({ p:FindFirstChildOfClass("Backpack"), p.Character }) do
		for _, t in ipairs(c and c:GetChildren() or {}) do
			if t:IsA("Tool") and t:GetAttribute("PoolKey") == poolKey then n += 1 end
		end
	end
	return n
end

return function(t)
	t.test("the first Warden kill gives one Warden-pool sword and records it; the next gives none", function()
		local g = Game.new({ scripts = true, studio = true })
		local p = g:addPlayer({ userId = 9009 })
		g:advance(1)
		local PDS = g:module("ServerScriptService.PlayerDataService")
		local boss = g:spawnEnemy({ archetype = "Boss_Gorgon", role = "boss", level = 10, position = Vector3.new(10, 3, 0) })
		g:advance(0.5)
		g:kill(p, boss)
		g:advance(1)
		t.eq(poolSwords(p, "Boss_Gorgon"), 1, "one Warden-pool sword after the first kill")
		local firsts = PDS.GetField(p, "bossFirstDrops")
		t.check(typeof(firsts) == "table" and firsts.Boss_Gorgon == true, "the first drop is recorded (settles Claim the Blade)")
		local again = g:spawnEnemy({ archetype = "Boss_Gorgon", role = "boss", level = 10, position = Vector3.new(12, 3, 0) })
		g:advance(0.5)
		g:kill(p, again)
		g:advance(1)
		t.eq(poolSwords(p, "Boss_Gorgon"), 1, "no second sword from a repeat kill")
	end)
end
