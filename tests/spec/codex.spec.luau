--// codex.spec  (the Codex counts kills and swords, pays its page rewards once, and saves)
-- Wave 1 of the 2026-09-25 fun plan (CodexConfig / CodexSystem).
local Game = require("../harness/game")
local D = require("../harness/datatypes")
local Vector3 = D.Vector3

local function newGame()
	local g = Game.new({ scripts = true, studio = true })
	g:runScript("CodexSystem")
	return g
end

local function killN(g, p, archetype, role, n)
	for i = 1, n do
		local e = g:spawnEnemy({ archetype = archetype, role = role, level = 5, position = Vector3.new(20 + i % 7, 3, 0) })
		g:kill(p, e)
	end
	g:advance(0.2)
end

return function(t)
	t.test("kills are counted per archetype; enemies with no page are ignored", function()
		local g = newGame()
		local p = g:addPlayer({ userId = 7101 })
		g:advance(1)
		local Codex = g:module("ReplicatedStorage.Config.CodexConfig")
		killN(g, p, "IronSquire", "minion", 3)
		killN(g, p, "CinderFiend", "minion", 2) -- Infernal Caldera has no page yet
		local kills = Codex.DecodeKills(p:GetAttribute("CodexKills"))
		t.eq(kills.IronSquire, 3, "three Quarry Cutthroats")
		t.eq(kills.CinderFiend, nil, "an unbuilt zone's enemy is not counted")
		local announced = 0
		for _, f in ipairs(g.world:fired(g:remote("Notify"))) do
			if f.player == p and string.find(tostring(f.args[1]), "New Codex entry", 1, true) then announced += 1 end
		end
		t.eq(announced, 1, "only the first kill announces a new entry")
	end)

	t.test("mastering every enemy on a page pays +2% damage once, and it survives a rejoin", function()
		local g = newGame()
		local p = g:addPlayer({ userId = 7102 })
		g:advance(1)
		local Codex = g:module("ReplicatedStorage.Config.CodexConfig")
		killN(g, p, "IronSquire", "minion", Codex.MASTERY.minion)
		killN(g, p, "IronBerserker", "minion", Codex.MASTERY.minion)
		t.eq(p:GetAttribute("CodexDamageMult"), 1, "two of three mastered: no bonus yet")
		killN(g, p, "Boss_Gorgon", "boss", Codex.MASTERY.boss)
		t.check(math.abs((p:GetAttribute("CodexDamageMult") or 0) - (1 + Codex.HUNTER_DAMAGE)) < 1e-6, "page mastered: +2% damage")
		killN(g, p, "IronSquire", "minion", 5)
		t.eq(select(2, string.gsub(p:GetAttribute("CodexClaims"), "IronLowlands:hunter", "")), 1, "claimed exactly once")

		g:removePlayer(p)
		g:advance(2)
		local back = g:addPlayer({ userId = 7102 })
		g:advance(2)
		t.eq(Codex.DecodeKills(back:GetAttribute("CodexKills")).IronSquire, Codex.MASTERY.minion + 5, "kills saved")
		t.check(math.abs((back:GetAttribute("CodexDamageMult") or 0) - (1 + Codex.HUNTER_DAMAGE)) < 1e-6, "bonus back after rejoin")
	end)

	t.test("holding a sword marks it found; a full sword page pays its tokens once", function()
		local g = newGame()
		local p = g:addPlayer({ userId = 7103 })
		g:advance(1)
		local Codex = g:module("ReplicatedStorage.Config.CodexConfig")
		local page = Codex.PageFor("IronLowlands")
		local tokens0 = p:GetAttribute("Tokens") or 0
		local bag = p:FindFirstChildOfClass("Backpack")
		for _, s in ipairs(page.swords) do
			local tool = g.world:newInstance("Tool")
			tool.Name = s.name
			tool:SetAttribute("BaseWeaponName", s.name)
			tool.Parent = bag
			g:flush()
		end
		g:advance(0.2)
		local found = Codex.DecodeSet(p:GetAttribute("CodexSwords"))
		t.check(found[page.swords[1].name] == true, "the first sword is found")
		t.eq((p:GetAttribute("Tokens") or 0) - tokens0, Codex.CollectorTokens(page), "the collector reward was paid")
		local extra = g.world:newInstance("Tool")
		extra:SetAttribute("BaseWeaponName", page.swords[1].name)
		extra.Parent = bag
		g:advance(0.2)
		t.eq((p:GetAttribute("Tokens") or 0) - tokens0, Codex.CollectorTokens(page), "a duplicate pays nothing more")
	end)
end
