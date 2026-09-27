--// world_events.spec  (a world event multiplies kill tokens in its zone only, champions pay more)
-- Wave 1 of the 2026-09-25 fun plan (WorldEventConfig / WorldEvents / TokenRules.KillMultiplier).
local Game = require("../harness/game")
local D = require("../harness/datatypes")
local Vector3 = D.Vector3

local function boot(userId)
	local g = Game.new({ scripts = true, studio = true })
	g:runScript("WorldEvents")
	local p = g:addPlayer({ userId = userId })
	g:advance(1)
	return g, p
end

local function tokensFor(g, p, options)
	local before = p:GetAttribute("Tokens") or 0
	local e = g:spawnEnemy(options)
	g:advance(0.1)
	g:kill(p, e)
	g:advance(0.2)
	return (p:GetAttribute("Tokens") or 0) - before, e
end

return function(t)
	t.test("the multiplier: its zone only, and a champion's own on top", function()
		local g = Game.new({})
		local TokenRules = g:module("ReplicatedStorage.Config.TokenRules")
		local ws = g.world.workspace
		local glacier = g:spawnEnemy({ archetype = "FrostImp", zone = "FrostboundGlacier" })
		local iron = g:spawnEnemy({ archetype = "IronSquire", zone = "IronLowlands" })
		t.eq(TokenRules.KillMultiplier(glacier), 1, "no event, no bonus")
		ws:SetAttribute("WorldEvent", "FrostMoon")
		ws:SetAttribute("WorldEventZone", "FrostboundGlacier")
		ws:SetAttribute("WorldEventMult", 3)
		t.eq(TokenRules.KillMultiplier(glacier), 3, "x3 in the Glacier")
		t.eq(TokenRules.KillMultiplier(iron), 1, "nothing elsewhere")
		glacier:SetAttribute("EventTokenMult", 5)
		t.eq(TokenRules.KillMultiplier(glacier), 15, "a champion stacks on the event")
	end)

	t.test("a forced Frost Moon triples Glacier kill tokens, then ends and clears everything", function()
		local g, p = boot(7301)
		local ws = g.world.workspace
		local calm = 0
		for _ = 1, 6 do calm += tokensFor(g, p, { archetype = "FrostImp", zone = "FrostboundGlacier", level = 18 }) end
		ws:SetAttribute("WorldEventForce", "FrostMoon")
		g:advance(0.5)
		t.eq(ws:GetAttribute("WorldEvent"), "FrostMoon", "running")
		local moon = 0
		for _ = 1, 6 do moon += tokensFor(g, p, { archetype = "FrostImp", zone = "FrostboundGlacier", level = 18 }) end
		t.check(moon >= calm * 2, string.format("event kills paid far more (%d vs %d)", moon, calm))
		local elsewhere = tokensFor(g, p, { archetype = "IronSquire", zone = "IronLowlands", level = 2 })
		t.check(elsewhere <= 10, "an Iron Lowlands kill is untouched")
		ws:SetAttribute("WorldEventForce", "stop")
		g:advance(0.5)
		t.eq(ws:GetAttribute("WorldEvent"), nil, "ended")
		t.eq(ws:GetAttribute("WorldEventMult"), nil, "multiplier cleared")
	end)

	t.test("a Sandstorm gilds up to three Iron Lowlands enemies, and they pay 5x on top", function()
		local g, p = boot(7302)
		local ws = g.world.workspace
		local rigs = {}
		for i = 1, 6 do
			rigs[i] = g:spawnEnemy({ archetype = "IronSquire", zone = "IronLowlands", level = 3, position = Vector3.new(i * 4, 3, 40) })
		end
		ws:SetAttribute("WorldEventForce", "Sandstorm")
		g:advance(0.5)
		local gilded = 0
		for _, r in ipairs(rigs) do
			if r:GetAttribute("EventTitle") == "Gilded" then gilded += 1 end
		end
		t.eq(gilded, 3, "three Gilded")
		ws:SetAttribute("WorldEventForce", "stop")
		g:advance(0.5)
		for _, r in ipairs(rigs) do
			t.eq(r:GetAttribute("EventTokenMult"), nil, "champion bonus cleared")
		end
	end)
end
