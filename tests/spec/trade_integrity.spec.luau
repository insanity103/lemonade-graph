--// trade_integrity.spec  (a trade delivers exactly what both players confirmed)
-- Regression for the 2026-09-24 playtest's trade findings (trade-1/2/3, R20, gui-ux-2, R3-THEFT):
-- an offer could shrink or be swapped after the partner confirmed and the trade still completed.
local Game = require("../harness/game")

local A_ID, B_ID = 5001, 5002

local function boot()
	local g = Game.new({ scripts = true, studio = true })
	g:runScript("TradeSystem")
	g:runScript("InventorySystem")
	local a = g:addPlayer({ userId = A_ID })
	local b = g:addPlayer({ userId = B_ID })
	g:advance(1)
	return g, a, b
end

local function relic(g, p, rarity)
	local Factory = g:module("ServerScriptService.BossSwordFactory")
	local tool = Factory.build("IronLowlands", { sword = "Quarry Shank", rarity = rarity, jitter = false })
	tool.Parent = p:FindFirstChildOfClass("Backpack")
	g:flush()
	return tool
end

local function send(g, p, action, arg)
	g:remote("TradeAction").OnServerEvent:Fire(p, action, arg)
	g:flush()
	g:advance(0.25) -- the remote's per-player interval
end

-- The latest Session payload the server sent to `p`.
local function session(g, p)
	local last
	for _, e in ipairs(g.world:fired(g:remote("TradeAction"))) do
		if e.player == p and e.args[1] == "Session" then last = e.args[2] end
	end
	return last
end

local function keyFor(g, p, tool)
	for _, row in ipairs(session(g, p).carried) do
		if row.name == tool.Name and row.rarity == tool:GetAttribute("Rarity") then return row.key end
	end
end

local function open(g, a, b)
	send(g, a, "Request", b.UserId)
	send(g, b, "Accept", a.UserId)
end

local function bossRelics(p)
	local out = {}
	for _, c in ipairs({ p:FindFirstChildOfClass("Backpack"), p.Character }) do
		for _, t in ipairs(c and c:GetChildren() or {}) do
			if t:IsA("Tool") and t:GetAttribute("BossDrop") == true and t:GetAttribute("Starter") ~= true then
				table.insert(out, t:GetAttribute("Rarity"))
			end
		end
	end
	return out
end

return function(t)
	t.test("an offered sword that leaves after the partner confirms cancels both confirmations", function()
		local g, a, b = boot()
		local sword = relic(g, a, "Epic")
		relic(g, b, "Common")
		open(g, a, b)
		send(g, a, "Offer", keyFor(g, a, sword))
		send(g, b, "Confirm", session(g, b).version)
		t.check(session(g, a).theirConfirmed == true, "B confirmed")
		sword:Destroy() -- sold, stored in the vault, or dropped
		g:flush()
		send(g, a, "Confirm", session(g, a).version)
		t.eq(#bossRelics(b), 1, "B still has only its own sword (nothing traded)")
		t.check(session(g, b).myConfirmed ~= true, "B's confirmation was reopened")
	end)

	t.test("a Confirm for an older offer version is refused", function()
		local g, a, b = boot()
		local good = relic(g, a, "Legendary")
		local junk = relic(g, a, "Common")
		relic(g, b, "Rare")
		open(g, a, b)
		send(g, a, "Offer", keyFor(g, a, good))
		local seen = session(g, b).version -- B looks at GOOD
		send(g, a, "Offer", keyFor(g, a, good)) -- A pulls GOOD ...
		send(g, a, "Offer", keyFor(g, a, junk)) -- ... and puts JUNK in
		send(g, a, "Confirm", session(g, a).version)
		send(g, b, "Confirm", seen) -- B's click was for GOOD
		t.eq(#bossRelics(b), 1, "B did not receive the swapped offer")
		t.check(session(g, b).myConfirmed ~= true, "B's stale Confirm was refused")
	end)

	t.test("a same-named worse copy cannot replace the offered sword", function()
		local g, a, b = boot()
		local strong = relic(g, a, "Epic")
		local weak = relic(g, a, "Common")
		weak.Name = strong.Name -- two copies that roll the same prefixes share a name
		g:flush()
		relic(g, b, "Rare")
		open(g, a, b)
		send(g, a, "Offer", keyFor(g, a, strong))
		-- A equips the weak copy (it moves to the character, ahead of the Backpack by name)
		weak.Parent = a.Character
		g:flush()
		send(g, b, "Confirm", session(g, b).version)
		send(g, a, "Confirm", session(g, a).version)
		local got = bossRelics(b)
		t.check(table.find(got, "Epic") ~= nil, "B received the Epic it was shown, got: " .. table.concat(got, ","))
	end)

	t.test("an honest trade still completes", function()
		local g, a, b = boot()
		local sa = relic(g, a, "Epic")
		local sb = relic(g, b, "Rare")
		open(g, a, b)
		send(g, a, "Offer", keyFor(g, a, sa))
		send(g, b, "Offer", keyFor(g, b, sb))
		send(g, a, "Confirm", session(g, a).version)
		send(g, b, "Confirm", session(g, b).version)
		t.check(table.find(bossRelics(b), "Epic") ~= nil, "B received A's Epic")
		t.check(table.find(bossRelics(a), "Rare") ~= nil, "A received B's Rare")
	end)
end
