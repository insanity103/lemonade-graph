--// elite_affixes.spec  (who rolls a trait, the shield soaks three hits, affixed kills pay double)
-- Wave 1 of the 2026-09-25 fun plan (EliteAffixConfig, CombatUtil.absorbHit, TokenRules.KillMultiplier).
local Game = require("../harness/game")

return function(t)
	t.test("bosses never roll; leaders and elites can; ordinary members cannot", function()
		local g = Game.new({})
		local A = g:module("ReplicatedStorage.Config.EliteAffixConfig")
		local always = function() return 0 end
		local first = function() return 1 end
		t.eq(A.Roll("boss", 1, true, always, first), nil, "a boss never")
		t.eq(A.Roll("minion", 2, false, always, first), nil, "a pack member that is not the leader never")
		t.check(A.Roll("minion", 1, false, always, first) ~= nil, "a pack leader can")
		t.check(A.Roll("elite", 3, false, always, first) ~= nil, "an elite can")
		t.eq(A.Roll("minion", 1, false, function() return 0.99 end, first), nil, "a failed roll gives nothing")
	end)

	t.test("a Frost-shield soaks exactly three hits, then gives the torso back", function()
		local g = Game.new({})
		local CombatUtil = g:module("ServerScriptService.CombatUtil")
		local e = g:spawnEnemy({ archetype = "GlacialGargoyle", zone = "FrostboundGlacier" })
		local torso = g.world:newInstance("Part")
		torso.Name = "Torso"
		torso.Parent = e
		e:SetAttribute("ShieldCharges", 3)
		e:SetAttribute("ShieldMaterial", "SmoothPlastic")
		local absorbed = 0
		for _ = 1, 5 do
			if CombatUtil.absorbHit(e) then absorbed += 1 end
		end
		t.eq(absorbed, 3, "three hits absorbed, the rest land")
		t.eq(e:GetAttribute("ShieldCharges"), 0, "shield spent")
	end)

	t.test("an affixed kill pays double, and stacks with an event", function()
		local g = Game.new({})
		local TokenRules = g:module("ReplicatedStorage.Config.TokenRules")
		local e = g:spawnEnemy({ archetype = "IronBerserker", zone = "IronLowlands" })
		e:SetAttribute("AffixTokenMult", 2)
		t.eq(TokenRules.KillMultiplier(e), 2, "x2 for the affix")
		g.world.workspace:SetAttribute("WorldEvent", "Sandstorm")
		g.world.workspace:SetAttribute("WorldEventZone", "IronLowlands")
		g.world.workspace:SetAttribute("WorldEventMult", 2)
		t.eq(TokenRules.KillMultiplier(e), 4, "x4 during a Sandstorm")
	end)
end
