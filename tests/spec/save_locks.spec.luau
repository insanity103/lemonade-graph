--// save_locks.spec  (a held save lock is waited out, failed saves are retried, late saves stay out)
-- Regression for the 2026-09-24 playtest's save findings: a foreign lock loaded a blank level-1
-- profile with saving silently off (persistence-5), failed saves were dropped (persistence-15), and a
-- save landing after the leave-save put the lock back (trade-6, vault-2).
local Game = require("../harness/game")

local USER = 6006

local function boot(profile)
	local g = Game.new({ scripts = true }) -- a live server (IsStudio false)
	local SaveConfig = g:module("ReplicatedStorage.Config.SaveConfig")
	local store = g.world:dataStore(SaveConfig.DATASTORE_NAME)
	local key = SaveConfig.KEY_PREFIX .. tostring(USER)
	if profile then store:Seed(key, profile) end
	return g, store, key
end

local function kicked(g)
	return #g.world:logged("^Kick%(") > 0
end

local function levelOf(p)
	local ls = p:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild("Level") and ls.Level.Value
end

return function(t)
	t.test("a lock another server releases a few seconds later is waited out, not loaded as blank", function()
		local g, store, key = boot({ leaderstats = { Level = 40, Gold = 5000 }, attributes = {}, swords = {},
			vault = {}, __lock = { jobId = "other-server", time = os.time() } })
		-- the other server's leave-save lands 6 s later
		g.world:delay(6, function()
			local rec = store:Read(key); rec.__lock = nil; store:Seed(key, rec)
		end)
		local p = g:addPlayer({ userId = USER, character = false })
		g:advance(20)
		t.eq(levelOf(p), 40, "the real profile loaded after the wait")
		t.check(not kicked(g), "the player was not kicked")
	end)

	t.test("a lock that never frees sends the player back to rejoin instead of a silent blank profile", function()
		local g, store, key = boot({ leaderstats = { Level = 40 }, attributes = {}, swords = {}, vault = {},
			__lock = { jobId = "other-server", time = 0 } })
		store:Seed(key, (function() local r = store:Read(key); r.__lock.time = os.time() + 1e6; return r end)())
		local p = g:addPlayer({ userId = USER, character = false })
		g:advance(40)
		t.check(kicked(g), "the player was asked to rejoin")
		t.eq(store:Read(key).leaderstats.Level, 40, "the stored profile was left untouched")
	end)

	t.test("a failed save is retried on its own", function()
		local g, store, key = boot()
		local p = g:addPlayer({ userId = USER })
		g:advance(2)
		p.leaderstats.Gold.Value = 777
		local PDS = g:module("ServerScriptService.PlayerDataService")
		store:FailNext(4) -- every attempt of the next save fails
		g.world:spawn(PDS.Save, p)
		g:advance(30)
		t.eq(store:Read(key).leaderstats.Gold, 777, "the retry landed the gold")
	end)

	t.test("a save that lands after the leave-save does not put the lock back", function()
		local g, store, key = boot()
		local p = g:addPlayer({ userId = USER })
		g:advance(2)
		local PDS = g:module("ServerScriptService.PlayerDataService")
		store:FailNext(1) -- a trade save hits a hiccup and retries after 1 s ...
		g.world:spawn(PDS.Save, p)
		g:removePlayer(p) -- ... while the player leaves
		g:advance(15)
		t.eq(store:Read(key).__lock, nil, "the record is unlocked after the player left")
	end)
end
