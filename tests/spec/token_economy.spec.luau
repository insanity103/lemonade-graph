--// token_economy.spec  (kills pay tokens into the saved currency; the wheel and the stall charge the config)
-- Everything goes through the shipped entry points: an enemy Humanoid dying with a "creator" tag
-- (SwordDropSystem's hook), the SpinAction / UpgradeAction remotes (GameplayServices), and the leave
-- path (PlayerDataService.Release) for what reaches the DataStore.
local Game = require("../harness/game")
local D = require("../harness/datatypes")
local Vector3 = D.Vector3

local USER = 777

local function boot(options)
	options = options or {}
	local g = Game.new({ scripts = true, templates = options.templates })
	local player = g:addPlayer({ userId = USER, profile = options.profile })
	local env = {
		g = g, player = player,
		TokenRules = g:module("ReplicatedStorage.Config.TokenRules"),
		SpinPools = g:module("ReplicatedStorage.Config.SpinPools"),
		SpinService = g:module("ServerScriptService.SpinService"),
		PDS = g:module("ServerScriptService.PlayerDataService"),
		SaveConfig = g:module("ReplicatedStorage.Config.SaveConfig"),
		UpgradeConfig = g:module("ReplicatedStorage.Config.UpgradeConfig"),
	}
	return env
end

local function band(TokenRules, role, zone)
	local b = TokenRules.PER_KILL[role]
	local scale = TokenRules.ZONE_SCALE[zone] or 1
	-- the configured band scaled by the area, allowing for rounding to whole tokens
	return math.max(1, b[1] * scale - 0.5), b[2] * scale + 0.5
end

-- The prompt part a station's ProximityPrompt hangs off (built by GameplayActors at boot).
local function promptPart(g, promptName)
	for _, d in ipairs(g.world.workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Name == promptName then return d.Parent end
	end
	error("no ProximityPrompt " .. promptName .. " in the workspace")
end

local function standAt(g, player, part)
	g:moveTo(player, part.Position + Vector3.new(2, 3, 2))
end

local function lastFired(g, remote, player)
	local log = g.world:fired(remote)
	for i = #log, 1, -1 do
		if log[i].player == player then return log[i].args end
	end
	return nil
end

local function tools(player)
	local out = {}
	for _, tool in ipairs(player.Backpack:GetChildren()) do
		if tool:IsA("Tool") and tool:GetAttribute("Starter") ~= true then table.insert(out, tool) end
	end
	return out
end

-- Put the player at `step` of `zone`, at a level where every row of that step is unlocked.
local function placeAt(env, zone, step)
	local d = env.SpinService.Depth(zone)
	local record = ({ { best = d.lo }, { best = d.mid }, { best = d.deep }, { best = d.deep, boss = true } })[step]
	env.PDS.SetField(env.player, "zoneDepth", { [zone] = record })
	local pool = env.SpinPools.Get(zone)
	local level = pool.gate
	for _, e in ipairs(pool.entries) do
		if (e.weights[step] or 0) > 0 then level = math.max(level, e.minLevel) end
	end
	env.g:setLevel(env.player, level)
end

local function spin(env, which)
	local remote = env.g:remote("SpinAction")
	env.g.world:clearFired(remote)
	remote.OnServerEvent:Fire(env.player, "Spin", which or "one")
	env.g:flush()
	return lastFired(env.g, remote, env.player)
end

return function(t)
	t.test("every kill pays tokens into the saved Tokens attribute, in its role and area's configured band", function()
		local env = boot()
		local g, player, TokenRules = env.g, env.player, env.TokenRules
		local tokenDrop = g:remote("TokenDrop")
		local kills = 0
		for _, zone in ipairs(env.SpinPools.Order) do
			for _, role in ipairs({ "minion", "elite", "warden", "boss" }) do
				local lo, hi = band(TokenRules, role, zone)
				local seenLo, seenHi = math.huge, -math.huge
				for _ = 1, t.scale(60) do
					local before = player:GetAttribute("Tokens")
					local model = g:spawnEnemy({ zone = zone, role = role, level = 5 })
					g.world:clearFired(tokenDrop)
					g:kill(player, model)
					kills += 1
					local paid = player:GetAttribute("Tokens") - before
					seenLo, seenHi = math.min(seenLo, paid), math.max(seenHi, paid)
					t.check(paid >= lo and paid <= hi, "%s %s kill paid %d tokens, config band %.1f..%.1f", zone, role, paid, lo, hi)
					local args = lastFired(g, tokenDrop, player)
					if t.check(args, "%s %s kill: no TokenDrop sent to the killer", zone, role) then
						local split, total, sentRole = args[2], args[3], args[4]
						local sum = 0
						for _, v in ipairs(split) do sum += v end
						t.eq(total, paid, zone .. " " .. role .. " TokenDrop total vs credited")
						t.eq(sum, total, zone .. " " .. role .. " pickups sum")
						t.check(#split <= TokenRules.MAX_PICKUPS, "%d pickups > MAX_PICKUPS", #split)
						t.eq(sentRole, role, zone .. " role reported to the client")
					end
				end
			end
		end
		t.note("%d kills across %d areas x 4 roles", kills, #env.SpinPools.Pools)
	end)

	t.test("earned tokens reach the DataStore on leave and on autosave, and come back on rejoin", function()
		local env = boot()
		local g, player = env.g, env.player
		for _ = 1, 5 do g:kill(player, g:spawnEnemy({ zone = "Briarwood", role = "elite", level = 11 })) end
		local earned = player:GetAttribute("Tokens")
		t.check(earned >= 5 * 14, "5 Briarwood elite kills paid only %d", earned)
		local key = env.SaveConfig.KEY_PREFIX .. USER
		local store = g.world:dataStore(env.SaveConfig.DATASTORE_NAME)
		g:advance(env.SaveConfig.AUTOSAVE_INTERVAL + 1)
		t.eq(store:Read(key).attributes.Tokens, earned, "Tokens in the autosaved record")
		g:kill(player, g:spawnEnemy({ zone = "Briarwood", role = "boss", level = 14 }))
		local final = player:GetAttribute("Tokens")
		g:removePlayer(player)
		local rec = store:Read(key)
		t.eq(rec.attributes.Tokens, final, "Tokens in the record saved on leave")
		local again = boot({ profile = rec })
		t.eq(again.player:GetAttribute("Tokens"), final, "Tokens after rejoining")
	end)

	t.test("no tokens for a kill before the profile loads, a dummy, a kill with no player, or a second Died", function()
		local env = boot()
		local g, player = env.g, env.player
		-- a dummy rig (no Archetype) pays nothing but still records depth
		local dummy = g:spawnEnemy({ zone = "IronLowlands", level = 3 })
		dummy:SetAttribute("Archetype", nil)
		g:kill(player, dummy)
		t.eq(player:GetAttribute("Tokens"), 0, "tokens after killing a dummy")
		-- no creator tag: nobody is paid
		local _, hum = g:spawnEnemy({ zone = "IronLowlands" })
		hum.Health = 0
		g:flush()
		t.eq(player:GetAttribute("Tokens"), 0, "tokens after an untagged death")
		-- Died firing twice pays once
		local model, humanoid = g:spawnEnemy({ zone = "IronLowlands", role = "boss", level = 10 })
		g:kill(player, model)
		local once = player:GetAttribute("Tokens")
		humanoid.Died:Fire()
		g:flush()
		t.eq(player:GetAttribute("Tokens"), once, "tokens after a repeated Died")
		-- a kill landed before the profile applied is not paid (the load would overwrite it)
		local g2 = Game.new({ scripts = true })
		local SaveConfig = g2:module("ReplicatedStorage.Config.SaveConfig")
		g2.world:dataStore(SaveConfig.DATASTORE_NAME):FailNext(1) -- the load waits for a retry
		local early = g2:addPlayer({ userId = USER + 1 })
		g2:kill(early, g2:spawnEnemy({ zone = "IronLowlands" }))
		g2:advance(2)
		t.eq(early:GetAttribute("DataLoaded"), true, "loaded after the retry")
		t.eq(early:GetAttribute("Tokens"), 0, "a pre-load kill is not paid")
	end)

	t.test("kills record how deep the player has pushed (the spin pool's step)", function()
		local env = boot()
		local g, player, SpinService = env.g, env.player, env.SpinService
		g:setLevel(player, 12)
		local d = SpinService.Depth("Briarwood")
		t.eq(SpinService.StepOf(player, "Briarwood"), 0, "Briarwood before any kill")
		g:kill(player, g:spawnEnemy({ zone = "Briarwood", level = d.lo }))
		t.eq(SpinService.StepOf(player, "Briarwood"), 1, "after a trailhead kill")
		g:kill(player, g:spawnEnemy({ zone = "Briarwood", level = d.mid }))
		t.eq(SpinService.StepOf(player, "Briarwood"), 2, "after a midway kill")
		g:kill(player, g:spawnEnemy({ zone = "Briarwood", level = d.deep }))
		t.eq(SpinService.StepOf(player, "Briarwood"), 3, "after a deep-camp kill")
		g:kill(player, g:spawnEnemy({ zone = "Briarwood", level = d.lo }))
		t.eq(SpinService.StepOf(player, "Briarwood"), 3, "an easier kill never lowers the step")
		g:kill(player, g:spawnEnemy({ zone = "Briarwood", role = "warden", level = 14, archetype = "RootWarden" }))
		t.eq(SpinService.StepOf(player, "Briarwood"), 4, "after the Root Warden")
		t.eq(player:GetAttribute("Depth_Briarwood"), 4, "mirrored Depth_Briarwood attribute")
		t.eq(player:GetAttribute("SpinZone"), "Briarwood", "default spin area follows the push")
	end)

	t.test("a spin costs exactly the config's price at every area and step, and pays out one sword", function()
		local env = boot()
		local g, player, SpinPools = env.g, env.player, env.SpinPools
		standAt(g, player, promptPart(g, "SpinOne"))
		for _, pool in ipairs(SpinPools.Pools) do
			for step = 1, SpinPools.STEPS do
				placeAt(env, pool.zone, step)
				local price = pool.cost[step]
				t.eq(SpinPools.CostFor(pool.zone, step), price, pool.zone .. " CostFor step " .. step)
				player:SetAttribute("Tokens", price + 7)
				local before = #tools(player)
				local args = spin(env, "one")
				if t.check(args and args[1] == "Result", "%s step %d: spin was %s (%s)", pool.zone, step,
					args and tostring(args[1]) or "not answered", args and args[2] and tostring(args[2].code) or "") then
					t.eq(player:GetAttribute("Tokens"), 7, pool.zone .. " step " .. step .. " tokens left")
					t.eq(args[2].cost, price, pool.zone .. " step " .. step .. " cost reported")
					t.eq(args[2].results[1].zone, pool.zone, "spin rolled the player's area")
					t.eq(args[2].results[1].step, step, "spin rolled the player's step")
					t.eq(#tools(player) - before, 1, pool.zone .. " step " .. step .. " swords handed over")
				end
				g:advance(SpinPools.SPIN_SECONDS + 1.1)
			end
		end
	end)

	t.test("prices climb: every step costs more than the last, and every area more than the one before", function()
		local env = boot()
		local prev = 0
		for _, pool in ipairs(env.SpinPools.Pools) do
			for step = 1, env.SpinPools.STEPS do
				local c = env.SpinPools.CostFor(pool.zone, step)
				t.check(c > prev, "%s step %d costs %d, not above the previous step's %d", pool.zone, step, c, prev)
				prev = c
			end
		end
		t.eq(env.SpinPools.CostFor(nil, 1), env.SpinPools.TOKEN_COST, "unknown area falls back to TOKEN_COST")
	end)

	t.test("a spin costs 5-13 ordinary kills where you are (SpinPools / TokenRules design note)", function()
		local env = boot()
		local TokenRules = env.TokenRules
		local lowest, highest = math.huge, 0
		for _, pool in ipairs(env.SpinPools.Pools) do
			local m = TokenRules.PER_KILL.minion
			local scale = TokenRules.ZONE_SCALE[pool.zone] or 1
			local lo = math.max(1, math.floor(m[1] * scale + 0.5))
			local hi = math.max(lo, math.floor(m[2] * scale + 0.5))
			local mean = (lo + hi) / 2
			for step = 1, env.SpinPools.STEPS do
				local kills = env.SpinPools.CostFor(pool.zone, step) / mean
				lowest, highest = math.min(lowest, kills), math.max(highest, kills)
				t.check(kills >= 4.5 and kills <= 13.5, "%s step %d: a spin costs %.1f minion kills", pool.zone, step, kills)
			end
		end
		t.note("a spin costs %.2f .. %.2f minion kills", lowest, highest)
	end)

	t.test("multi-spin is refused until bought, then costs count x price (Lucky Spins bonus swords are free)", function()
		local env = boot()
		local g, player, SpinPools = env.g, env.player, env.SpinPools
		standAt(g, player, promptPart(g, "SpinOne"))
		placeAt(env, "IronLowlands", 2)
		local price = SpinPools.CostFor("IronLowlands", 2)
		player:SetAttribute("Tokens", price * 10)
		local refused = spin(env, "multi")
		t.eq(refused and refused[1], "Refused", "multi-spin while locked")
		t.eq(refused and refused[2].code, "multi", "refusal code")
		t.eq(player:GetAttribute("Tokens"), price * 10, "tokens after a refused multi-spin")
		player:SetAttribute("MultiSpin", 3)
		player:SetAttribute("BonusSpinLevel", 6) -- 30% bonus odds per paid spin
		local totalBonus = 0
		for _ = 1, 6 do
			player:SetAttribute("Tokens", price * 3 + 1)
			local before = #tools(player)
			local args = spin(env, "multi")
			if t.check(args and args[1] == "Result", "multi-spin result: %s", args and tostring(args[1]) or "none") then
				t.eq(player:GetAttribute("Tokens"), 1, "tokens after a x3 multi-spin")
				t.eq(args[2].cost, price * 3, "multi-spin cost reported")
				t.eq(#tools(player) - before, 3 + args[2].bonus, "swords handed over (3 paid + bonus)")
				totalBonus += args[2].bonus
			end
			g:advance(SpinPools.SPIN_SECONDS + 1.1)
		end
		t.note("bonus swords over 6 presses: %d", totalBonus)
	end)

	t.test("a refused spin takes nothing: short of tokens, out of town, too far, mid-fight, wheel busy", function()
		local env = boot()
		local g, player, SpinPools = env.g, env.player, env.SpinPools
		local part = promptPart(g, "SpinOne")
		standAt(g, player, part)
		placeAt(env, "IronLowlands", 1)
		local price = SpinPools.CostFor("IronLowlands", 1)
		local function refusedWith(code, tokens)
			player:SetAttribute("Tokens", tokens)
			local before = #tools(player)
			local args = spin(env, "one")
			t.eq(args and args[1], "Refused", code .. ": answer")
			t.eq(args and args[2].code, code, code .. ": refusal code")
			t.eq(player:GetAttribute("Tokens"), tokens, code .. ": tokens untouched")
			t.eq(#tools(player), before, code .. ": no sword")
		end
		refusedWith("tokens", price - 1)
		g:moveTo(player, Vector3.new(500, 3, 500))
		refusedWith("town", price * 2)
		local hub = g:module("ServerScriptService.WorldLayout").HUB
		g:moveTo(player, hub.Center + Vector3.new(-20, 3, 20)) -- in town, far from the wheel
		refusedWith("far", price * 2)
		standAt(g, player, part)
		player:SetAttribute("CombatAt", g.world.workspace:GetServerTimeNow())
		refusedWith("combat", price * 2)
		g:advance(SpinPools.COMBAT_LOCK + 0.1)
		player:SetAttribute("Tokens", price * 2)
		t.eq(spin(env, "one")[1], "Result", "spin once the combat lock has passed")
		refusedWith("busy", price * 2)
		g:advance(SpinPools.SPIN_SECONDS + 0.1)
		player:SetAttribute("Tokens", price)
		t.eq(spin(env, "one")[1], "Result", "spin once the wheel has stopped")
		t.eq(player:GetAttribute("Tokens"), 0, "the last token spent")
	end)

	t.test("gold upgrades charge exactly their configured price and set the saved attribute", function()
		local env = boot()
		local g, player, UpgradeConfig = env.g, env.player, env.UpgradeConfig
		standAt(g, player, promptPart(g, "UpgradePrompt"))
		local remote = g:remote("UpgradeAction")
		local gold = player.leaderstats.Gold
		for _, id in ipairs(UpgradeConfig.ORDER) do
			local def = UpgradeConfig.Defs[id]
			for index, tier in ipairs(def.tiers) do
				g:setLevel(player, tier.minLevel)
				player.leaderstats.Rebirths.Value = tier.rebirths or 0
				player:SetAttribute("Rebirths", tier.rebirths or 0)
				-- one gold short: refused, nothing moves
				gold.Value = tier.price - 1
				g:advance(0.3)
				remote.OnServerEvent:Fire(player, "Buy", id)
				g:flush()
				t.eq(gold.Value, tier.price - 1, string.format("%s tier %d: gold after a refused buy", id, index))
				t.eq(UpgradeConfig.LevelOf(id, player), index - 1, string.format("%s tier %d: owned after refusal", id, index))
				-- exactly enough
				gold.Value = tier.price
				g:advance(0.3)
				remote.OnServerEvent:Fire(player, "Buy", id)
				g:flush()
				t.eq(gold.Value, 0, string.format("%s tier %d: gold after buying at %d", id, index, tier.price))
				t.eq(player:GetAttribute(def.attr), tier.value, string.format("%s tier %d: %s", id, index, def.attr))
				t.check(env.SaveConfig.ATTRIBUTES[def.attr] ~= nil, "%s writes %s, which SaveConfig does not persist", id, def.attr)
			end
			-- maxed: refused
			gold.Value = 10 ^ 9
			g:advance(0.3)
			remote.OnServerEvent:Fire(player, "Buy", id)
			g:flush()
			t.eq(gold.Value, 10 ^ 9, id .. ": gold after buying past the last tier")
		end
		-- the multi-spin bought here is what the wheel then spins
		t.eq(player:GetAttribute("MultiSpin"), UpgradeConfig.Defs.MultiSpin.tiers[#UpgradeConfig.Defs.MultiSpin.tiers].value,
			"MultiSpin after buying every tier")
	end)

	t.test("spin swords on a fresh Rojo sync (no ServerStorage templates) are not starter swords", function()
		local env = boot({ templates = false })
		local g, player, SpinPools = env.g, env.player, env.SpinPools
		standAt(g, player, promptPart(g, "SpinOne"))
		placeAt(env, "IronLowlands", 2)
		for i = 1, 3 do
			player:SetAttribute("Tokens", SpinPools.CostFor("IronLowlands", 2))
			local args = spin(env, "one")
			t.eq(args and args[1], "Result", "spin " .. i)
			g:advance(SpinPools.SPIN_SECONDS + 1.1)
		end
		local spun = {}
		for _, tool in ipairs(player.Backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("BaseWeaponName") ~= "Classic Sword" then
				table.insert(spun, tool)
				t.check(tool:GetAttribute("Starter") ~= true, "spun %s carries Starter = true (from the ClassicSword template)",
					tool.Name)
			end
		end
		t.eq(#spun, 3, "spun swords still in the backpack after 3 spins")
	end)

	t.test("saved swords rebuilt on a fresh Rojo sync keep what they are (starter or not)", function()
		local g = Game.new({ scripts = true, templates = false })
		local Factory = g:module("ServerScriptService.BossSwordFactory")
		-- a boss sword: must not pick up the starter template's Starter / Lesser / PoolKey stamp
		local boss = Factory.rebuild({ name = "Nova Pit Shiv", attrs = { DamageMult = 1.4, Prefixes = "Nova", BossTier = 1,
			Rarity = "Rare", BaseWeaponName = "Pit Shiv", PoolKey = "Boss_Gorgon", PoolBase = 1.4 } }, 1)
		t.eq(boss:GetAttribute("Starter"), nil, "rebuilt boss sword Starter")
		t.eq(boss:GetAttribute("Lesser"), nil, "rebuilt boss sword Lesser")
		t.eq(boss:GetAttribute("PoolKey"), "Boss_Gorgon", "rebuilt boss sword PoolKey")
		t.eq(boss:GetAttribute("BaseWeaponName"), "Pit Shiv", "rebuilt boss sword BaseWeaponName")
		-- the saved starter still comes back as the starter
		local starter = Factory.rebuild({ name = "Classic Sword", attrs = { DamageMult = 1, Prefixes = "", BossTier = 1,
			Rarity = "Common", BaseWeaponName = "Classic Sword", PoolKey = "IronLowlands", Lesser = true, Starter = true,
			PoolBase = 1 } }, 1)
		t.eq(starter:GetAttribute("Starter"), true, "rebuilt starter keeps Starter")
		-- the StarterPack template itself is untouched (new players still get a real starter)
		t.eq(g:find("StarterPack.ClassicSword"):GetAttribute("Starter"), true, "StarterPack template Starter")
	end)
end
