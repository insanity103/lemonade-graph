--// exact_sword.spec  (Sell acts on the sword the player clicked, not on its name)
-- Regression for the 2026-09-24 playtest's inventory-1: Sell looked a sword up by name, Backpack
-- first, so clicking SELL on a Common could sell a same-named Legendary.
local Game = require("../harness/game")

local function relic(g, p, rarity)
	local Factory = g:module("ServerScriptService.BossSwordFactory")
	local tool = Factory.build("IronLowlands", { sword = "Quarry Shank", rarity = rarity, jitter = false })
	tool.Parent = p:FindFirstChildOfClass("Backpack")
	g:flush()
	return tool
end

return function(t)
	t.test("selling a Common never sells its same-named Legendary", function()
		local g = Game.new({ scripts = true, studio = true })
		g:runScript("InventorySystem")
		local p = g:addPlayer({ userId = 7007 })
		g:advance(1)
		local legendary = relic(g, p, "Legendary")
		local common = relic(g, p, "Common")
		common.Name = legendary.Name
		g:flush()
		g:remote("InventoryAction").OnServerEvent:Fire(p, "Sell", common)
		g:advance(1)
		t.check(legendary.Parent ~= nil, "the Legendary is still owned")
		t.check(common.Parent == nil, "the Common was the one sold")
	end)

	t.test("a sword the player does not hold cannot be sold", function()
		local g = Game.new({ scripts = true, studio = true })
		g:runScript("InventorySystem")
		local a = g:addPlayer({ userId = 7008 })
		local b = g:addPlayer({ userId = 7009 })
		g:advance(1)
		local theirs = relic(g, b, "Epic")
		local gold = a.leaderstats.Gold.Value
		g:remote("InventoryAction").OnServerEvent:Fire(a, "Sell", theirs)
		g:advance(1)
		t.check(theirs.Parent ~= nil, "B's sword was not sold")
		t.eq(a.leaderstats.Gold.Value, gold, "A was paid nothing")
	end)
end
