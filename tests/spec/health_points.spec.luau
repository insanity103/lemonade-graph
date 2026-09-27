--// health_points.spec  (a Health skill point raises the pool, it does not refill it)
-- Regression for the 2026-09-24 playtest's leveling-skills-1: spending a Health point mid-fight set
-- Health to the new maximum, a free full heal on every point.
local Game = require("../harness/game")

return function(t)
	t.test("spending a Health point at low health adds its HP, not a full heal", function()
		local g = Game.new({ scripts = true, studio = true })
		g:runScript("LevelingSystem")
		local p = g:addPlayer({ userId = 9109 })
		g:advance(1)
		p:SetAttribute("SkillPoints", 5)
		g:flush()
		local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
		humanoid.Health = 30
		local maxBefore = humanoid.MaxHealth
		g:remote("SpendSkillPoint").OnServerEvent:Fire(p, "Health", 1)
		g:advance(0.5)
		local gained = humanoid.MaxHealth - maxBefore
		t.check(gained > 0, "the pool grew")
		t.check(humanoid.Health <= 30 + gained + 1, string.format("health %.0f is 30 plus the new points, not full (%.0f)",
			humanoid.Health, humanoid.MaxHealth))
	end)
end
