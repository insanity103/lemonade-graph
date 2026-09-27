--// sword_keep.spec  (carried relics survive death, respawn and an early leave)
-- Regression for the 2026-09-24 playtest's worst finding: the engine replaces the Backpack on every
-- spawn and nothing put the relics back, so a death deleted every carried sword and the next save
-- made it permanent. The engine respawn is modelled the way Roblox documents it: CharacterRemoving
-- on the old character, the old Backpack destroyed, a fresh one filled from StarterPack, then the
-- new character and CharacterAdded.
local Game = require("../harness/game")
local D = require("../harness/datatypes")
local Vector3 = D.Vector3

local USER = 4242

local function relics(p)
	local n = 0
	for _, c in ipairs({ p:FindFirstChildOfClass("Backpack"), p.Character }) do
		for _, t in ipairs(c and c:GetChildren() or {}) do
			if t:IsA("Tool") and t:GetAttribute("BossDrop") == true then n += 1 end
		end
	end
	return n
end

local function engineRespawn(g, p)
	local old = p.Character
	if old then p.CharacterRemoving:Fire(old); g:flush() end
	local bag = p:FindFirstChildOfClass("Backpack")
	if bag then bag:Destroy() end
	if old then old:Destroy() end
	local nb = g.world:newInstance("Backpack"); nb.Name = "Backpack"
	for _, t in ipairs(g.world:service("StarterPack"):GetChildren()) do t:Clone().Parent = nb end
	nb.Parent = p
	g:spawnCharacter(p, Vector3.new(0, 3, 0))
end

local function giveRelics(g, p, count)
	local Factory = g:module("ServerScriptService.BossSwordFactory")
	for i = 1, count do
		local tool = Factory.build("IronLowlands", { rarity = "Common", jitter = false })
		tool.Parent = p:FindFirstChildOfClass("Backpack")
	end
	g:flush()
end

local function savedSwords(g)
	local SaveConfig = g:module("ReplicatedStorage.Config.SaveConfig")
	local rec = g.world:dataStore(SaveConfig.DATASTORE_NAME):Read(SaveConfig.KEY_PREFIX .. tostring(USER))
	return rec and rec.swords and #rec.swords or 0
end

return function(t)
	t.test("carried relics come back after a death and a respawn, and the save keeps them", function()
		local g = Game.new({ scripts = true, studio = true })
		local p = g:addPlayer({ userId = USER })
		g:advance(1)
		local base = relics(p)
		giveRelics(g, p, 3)
		t.eq(relics(p), base + 3, "relics given")
		-- equip one, then die
		local bag = p:FindFirstChildOfClass("Backpack")
		for _, tool in ipairs(bag:GetChildren()) do
			if tool:GetAttribute("BossDrop") == true and tool:GetAttribute("Starter") ~= true then
				tool.Parent = p.Character; break
			end
		end
		g:flush()
		p.Character:FindFirstChildOfClass("Humanoid").Health = 0
		g:advance(1)
		-- while dead, a save must still see every relic
		local PDS = g:module("ServerScriptService.PlayerDataService")
		t.eq(#PDS.Serialize(p).swords, base + 3, "a save while dead keeps every relic")
		engineRespawn(g, p)
		g:advance(1)
		t.eq(relics(p), base + 3, "every relic is back in the new Backpack after the respawn")
		g:removePlayer(p); g:advance(2)
		t.eq(savedSwords(g), base + 3, "the leave-save keeps every relic")
	end)

	t.test("a relic granted while the player is dead survives the respawn", function()
		local g = Game.new({ scripts = true, studio = true })
		local p = g:addPlayer({ userId = USER })
		g:advance(1)
		local base = relics(p)
		p.Character:FindFirstChildOfClass("Humanoid").Health = 0
		g:advance(1)
		-- a purchase, vault withdrawal or trade delivered into the doomed Backpack
		giveRelics(g, p, 1)
		g:advance(1)
		engineRespawn(g, p)
		g:advance(1)
		t.eq(relics(p), base + 1, "the relic granted while dead is in the new Backpack")
	end)

	t.test("leaving before the first spawn keeps every saved relic", function()
		local g = Game.new({ scripts = true, studio = true })
		local p = g:addPlayer({ userId = USER })
		g:advance(1)
		local base = relics(p)
		giveRelics(g, p, 2)
		g:removePlayer(p); g:advance(2)
		local saved = savedSwords(g)
		t.eq(saved, base + 2, "first session saved its relics")
		-- rejoin, never spawn, leave
		local p2 = g:addPlayer({ userId = USER, character = false })
		g:advance(2)
		g:removePlayer(p2); g:advance(2)
		t.eq(savedSwords(g), saved, "a session that never spawned kept every saved relic")
	end)
end
