--// move_guard.spec  (a hit right after a teleport does not land)
-- Regression for the 2026-09-24 playtest's combat-enemy-F2 / combat-sword-1: the hit test reads the
-- client-owned root, so a hacked client teleported next to an enemy, hit it, and teleported back.
local Game = require("../harness/game")
local D = require("../harness/datatypes")
local Vector3, CFrame = D.Vector3, D.CFrame

-- The harness does not tick Heartbeat on its own: step the clock in frames and fire it, as the
-- engine would.
local function run(g, seconds)
	local hb = g.world:service("RunService").Heartbeat
	local frames = math.max(1, math.floor(seconds * 30 + 0.5))
	for _ = 1, frames do
		g:advance(1 / 30)
		hb:Fire(1 / 30)
		g:flush()
	end
end

local function setup()
	local g = Game.new({ scripts = true, studio = true })
	g:runScript("EnemyCombat")
	local p = g:addPlayer({ userId = 8008, position = Vector3.new(0, 3, 0) })
	g:advance(1)
	-- the starter is equipped by default in some flows; the unarmed attack needs empty hands
	local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
	humanoid:UnequipTools()
	local enemy = g:spawnEnemy({ position = Vector3.new(300, 3, 0) })
	run(g, 1)
	return g, p, enemy
end

local function hp(enemy)
	return enemy:FindFirstChildOfClass("Humanoid").Health
end

return function(t)
	t.test("teleporting next to an enemy and attacking deals nothing", function()
		local g, p, enemy = setup()
		local before = hp(enemy)
		p.Character.HumanoidRootPart.CFrame = CFrame.new(Vector3.new(297, 3, 0)) -- 297 studs in one step
		run(g, 0.1)
		g:remote("EnemyAttack").OnServerEvent:Fire(p)
		g:advance(0.5)
		t.eq(hp(enemy), before, "no damage from a teleport-hit")
	end)

	t.test("a player standing next to an enemy still hits it", function()
		local g, p, enemy = setup()
		p.Character.HumanoidRootPart.CFrame = CFrame.new(Vector3.new(297, 3, 0))
		run(g, 2) -- the teleport mark has worn off: now just standing there
		local before = hp(enemy)
		g:remote("EnemyAttack").OnServerEvent:Fire(p)
		g:advance(0.5)
		t.check(hp(enemy) < before, "the standing player's hit landed")
	end)

	t.test("an enemy walking home after a leash takes no damage (no free leash-kiting)", function()
		local g, p, enemy = setup()
		p.Character.HumanoidRootPart.CFrame = CFrame.new(Vector3.new(297, 3, 0))
		run(g, 2)
		enemy:SetAttribute("Returning", true) -- what EnemyCombat's RETURNING state stamps
		local before = hp(enemy)
		g:remote("EnemyAttack").OnServerEvent:Fire(p)
		g:advance(0.5)
		t.eq(hp(enemy), before, "the returning enemy took nothing")
	end)
end
