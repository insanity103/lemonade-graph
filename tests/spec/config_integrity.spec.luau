--// config_integrity.spec  (the hand-tuned tables agree with each other: no dangling or orphaned keys)
-- Why these matter: BossWeapons.Resolve does not fail on a bad name. A pool row naming a sword that
-- is not in its BossWeapons pool silently becomes that pool's Legendary, and a row labelled
-- Legendary whose sword is a regular silently becomes a Common. Neither shows in a Studio playtest.
local fs = require("@lune/fs")
local Game = require("../harness/game")

local function setOf(list)
	local s = {}
	for _, v in ipairs(list) do s[v] = true end
	return s
end

local function keys(t)
	local out = {}
	for k in pairs(t) do table.insert(out, k) end
	table.sort(out)
	return out
end

return function(t)
	t.test("every sword a spin pool references exists in its BossWeapons pool, at the pool's rarity", function()
		local g = Game.new({})
		local SpinPools = g:module("ReplicatedStorage.Config.SpinPools")
		local BossWeapons = g:module("ReplicatedStorage.Config.BossWeapons")
		local rows = 0
		for _, pool in ipairs(SpinPools.Pools) do
			for _, entry in ipairs(pool.entries) do
				rows += 1
				local label = string.format("%s: %s (%s, pool %s)", pool.zone, entry.sword, entry.rarity, entry.poolKey)
				t.check(BossWeapons.PoolFor(entry.poolKey) ~= nil, "%s -- no BossWeapons pool %s", label, entry.poolKey)
				local def, key, isLegendary = BossWeapons.FindSword(entry.sword, entry.poolKey)
				if t.check(def ~= nil, "%s -- sword not found in that pool (Resolve would hand out the pool's Legendary)", label) then
					t.eq(key, entry.poolKey, label .. " resolved pool")
					if entry.rarity == "Legendary" then
						t.check(isLegendary, "%s -- labelled Legendary but is a regular sword (Resolve makes it Common)", label)
					end
				end
				local data = BossWeapons.Resolve(entry.poolKey, entry.sword, entry.rarity)
				t.eq(data.name, entry.sword, label .. " resolved name")
				t.eq(data.rarity, entry.rarity, label .. " resolved rarity")
				t.check(SpinPools.RARITY_ORDER[entry.rarity] ~= nil, "%s -- unknown rarity", label)
			end
		end
		t.note("%d pool rows checked", rows)
	end)

	t.test("every pool is well formed: 4 weights and 4 prices per row, no duplicate swords, sane levels", function()
		local g = Game.new({})
		local SpinPools = g:module("ReplicatedStorage.Config.SpinPools")
		for _, pool in ipairs(SpinPools.Pools) do
			t.eq(#pool.cost, SpinPools.STEPS, pool.zone .. " cost entries")
			for step, c in ipairs(pool.cost) do
				t.check(type(c) == "number" and c > 0 and c == math.floor(c), "%s step %d cost %s", pool.zone, step, tostring(c))
			end
			local seen = {}
			for _, entry in ipairs(pool.entries) do
				t.check(not seen[entry.sword], "%s lists %s twice", pool.zone, entry.sword)
				seen[entry.sword] = true
				t.eq(#entry.weights, SpinPools.STEPS, pool.zone .. " " .. entry.sword .. " weight entries")
				local live = false
				for _, w in ipairs(entry.weights) do
					t.check(type(w) == "number" and w >= 0, "%s %s has weight %s", pool.zone, entry.sword, tostring(w))
					if w > 0 then live = true end
				end
				t.check(live, "%s %s is in the pool but never rolls (all weights 0)", pool.zone, entry.sword)
				t.check(entry.minLevel >= 1 and entry.minLevel <= 100, "%s %s minLevel %s", pool.zone, entry.sword,
					tostring(entry.minLevel))
			end
		end
	end)

	t.test("the documented pool shape holds: one ultra per area, the border carry-in, new swords every step", function()
		local g = Game.new({})
		local SpinPools = g:module("ReplicatedStorage.Config.SpinPools")
		local previous = nil
		for _, pool in ipairs(SpinPools.Pools) do
			local ultras = {}
			for _, e in ipairs(pool.entries) do
				if e.ultra then
					table.insert(ultras, e)
					t.check(e.weights[1] == 0 and e.weights[2] == 0 and e.weights[3] == 0 and e.weights[4] > 0,
						"%s ultra %s must roll only on the boss step", pool.zone, e.sword)
				end
			end
			t.eq(#ultras, 1, pool.zone .. " ultras")
			local carried = {}
			for _, e in ipairs(pool.entries) do
				if e.from then table.insert(carried, e) end
			end
			if previous then
				local prevUltra = nil
				for _, e in ipairs(previous.entries) do if e.ultra then prevUltra = e end end
				t.eq(#carried, 1, pool.zone .. " carried-in swords")
				if carried[1] and prevUltra then
					t.eq(carried[1].sword, prevUltra.sword, pool.zone .. " carries in the previous area's ultra")
					t.eq(carried[1].from, previous.name, pool.zone .. " carry-in names where it came from")
					t.check(carried[1].weights[1] > 0, "%s: the carry-in must roll at the trailhead", pool.zone)
				end
			else
				t.eq(#carried, 0, pool.zone .. " (first area) carried-in swords")
			end
			-- "EVERY STEP IS A NEW ROSTER": each deeper step brings in a sword not seen earlier in the area
			local seen = {}
			for step = 1, SpinPools.STEPS do
				local fresh = false
				for _, e in ipairs(pool.entries) do
					if (e.weights[step] or 0) > 0 and not seen[e.sword] then fresh = true end
				end
				t.check(step == 1 or fresh, "%s step %d brings in no new sword", pool.zone, step)
				for _, e in ipairs(pool.entries) do
					if (e.weights[step] or 0) > 0 then seen[e.sword] = true end
				end
			end
			previous = pool
		end
	end)

	t.test("areas agree everywhere: spin pools, WorldLayout zones, BossWeapons zones, token scales (no orphans)", function()
		local g = Game.new({})
		local SpinPools = g:module("ReplicatedStorage.Config.SpinPools")
		local WorldLayout = g:module("ServerScriptService.WorldLayout")
		local BossWeapons = g:module("ReplicatedStorage.Config.BossWeapons")
		local TokenRules = g:module("ReplicatedStorage.Config.TokenRules")
		local zones = {}
		for _, z in ipairs(WorldLayout.ZONES) do table.insert(zones, z.Name) end
		t.eq(table.concat(SpinPools.Order, ","), table.concat(zones, ","), "spin pool order vs WorldLayout.ZONES")
		t.eq(table.concat(BossWeapons.ZoneOrder, ","), table.concat(zones, ","), "BossWeapons.ZoneOrder vs WorldLayout.ZONES")
		t.eq(table.concat(keys(TokenRules.ZONE_SCALE), ","), table.concat(keys(setOf(zones)), ","),
			"TokenRules.ZONE_SCALE keys vs WorldLayout zones")
		for _, zone in ipairs(zones) do
			t.check(BossWeapons.NormalPools[zone] ~= nil, "no BossWeapons lesser pool for %s", zone)
		end
		-- each pool's boss / warden is an enemy that really stands in that area, as its boss
		local enemies = {}
		for _, z in ipairs(WorldLayout.ZONES) do
			enemies[z.Name] = {}
			for _, e in ipairs(z.Enemies) do enemies[z.Name][e[1]] = e[3] end
		end
		for _, pool in ipairs(SpinPools.Pools) do
			local who = pool.boss or pool.warden
			if t.check(who, "%s names no boss or warden", pool.zone) then
				t.eq(enemies[pool.zone][who], "boss", pool.zone .. " step-4 foe " .. who .. " role in WorldLayout")
			end
			if pool.boss then
				t.check(BossWeapons.Pools[pool.boss] ~= nil, "%s boss %s has no BossWeapons pool", pool.zone, pool.boss)
			end
		end
		-- every token scale is positive and they climb with the world
		local prev = 0
		for _, zone in ipairs(zones) do
			local s = TokenRules.ZONE_SCALE[zone]
			t.check(type(s) == "number" and s > prev, "ZONE_SCALE %s = %s does not climb", zone, tostring(s))
			prev = s or prev
		end
	end)

	t.test("token rules: every role an enemy can be has a band, and no band is orphaned", function()
		local g = Game.new({})
		local TokenRules = g:module("ReplicatedStorage.Config.TokenRules")
		local roles = { "minion", "elite", "warden", "boss" } -- what TokenRules.RoleOf can return
		t.eq(table.concat(keys(TokenRules.PER_KILL), ","), table.concat(keys(setOf(roles)), ","), "PER_KILL roles")
		for _, role in ipairs(roles) do
			local b = TokenRules.PER_KILL[role]
			if t.check(b, "no band for %s", role) then
				t.check(b[1] >= 1 and b[2] >= b[1], "%s band %s..%s", role, tostring(b[1]), tostring(b[2]))
				t.eq(TokenRules.ForKill(role, function(lo) return lo end), b[1], role .. " lowest payout at x1")
				t.eq(TokenRules.ForKill(role, function(_, hi) return hi end), b[2], role .. " highest payout at x1")
			end
		end
		for total = 0, 200 do
			local split = TokenRules.Split(total)
			local sum = 0
			for _, v in ipairs(split) do sum += v end
			if not t.check(sum == total and #split <= TokenRules.MAX_PICKUPS, "Split(%d) sums to %d in %d pickups", total, sum,
				#split) then
				break
			end
		end
	end)

	t.test("every upgrade has a price, a value and a gate; the shop's order lists exactly the upgrades", function()
		local g = Game.new({})
		local UpgradeConfig = g:module("ReplicatedStorage.Config.UpgradeConfig")
		local WeaponModifiers = g:module("ReplicatedStorage.Config.WeaponModifiers")
		local SaveConfig = g:module("ReplicatedStorage.Config.SaveConfig")
		t.eq(table.concat(keys(setOf(UpgradeConfig.ORDER)), ","), table.concat(keys(UpgradeConfig.Defs), ","),
			"UpgradeConfig.ORDER vs Defs")
		for _, id in ipairs(UpgradeConfig.ORDER) do
			local def = UpgradeConfig.Defs[id]
			t.check(#def.tiers > 0, "%s has no tiers", id)
			t.check(type(def.attr) == "string" and SaveConfig.ATTRIBUTES[def.attr] ~= nil,
				"%s sets attribute %s, which is not persisted (SaveConfig.ATTRIBUTES)", id, tostring(def.attr))
			local prevValue = SaveConfig.ATTRIBUTES[def.attr] or 0
			local prevPrice, prevLevel = 0, 0
			for i, tier in ipairs(def.tiers) do
				local label = string.format("%s tier %d", id, i)
				t.check(type(tier.price) == "number" and tier.price > 0 and tier.price == math.floor(tier.price),
					"%s has no whole positive price (%s)", label, tostring(tier.price))
				t.check(type(tier.value) == "number" and tier.value > prevValue, "%s value %s does not raise %s past %s",
					label, tostring(tier.value), def.attr, tostring(prevValue))
				t.check((tier.price or 0) > prevPrice, "%s price %s is not above the tier before (%s)", label,
					tostring(tier.price), tostring(prevPrice))
				t.check(type(tier.minLevel) == "number" and tier.minLevel >= prevLevel, "%s level gate %s", label,
					tostring(tier.minLevel))
				prevValue, prevPrice, prevLevel = tier.value or prevValue, tier.price or prevPrice, tier.minLevel or prevLevel
			end
		end
		-- prefix slots are sold from WeaponModifiers' own table: the two must agree
		for _, tier in ipairs(UpgradeConfig.Defs.PrefixSlots.tiers) do
			local row = WeaponModifiers.SlotUnlocks[tier.value]
			if t.check(row, "PrefixSlots sells slot %d, which WeaponModifiers.SlotUnlocks does not define", tier.value) then
				t.eq(tier.minLevel, row.minLevel, "slot " .. tier.value .. " level gate")
				t.eq(tier.rebirths, row.rebirths, "slot " .. tier.value .. " rebirth gate")
				t.eq(tier.price, WeaponModifiers.SlotUnlockPrice(tier.value), "slot " .. tier.value .. " price")
			end
		end
		t.eq(UpgradeConfig.Defs.PrefixSlots.tiers[#UpgradeConfig.Defs.PrefixSlots.tiers].value, WeaponModifiers.MAX_SLOTS,
			"the last prefix slot tier reaches MAX_SLOTS")
		t.check(UpgradeConfig.BonusChance(#UpgradeConfig.Defs.LuckySpins.tiers) < 1, "Lucky Spins maxes at or above 100%")
		for _, tier in ipairs(UpgradeConfig.Defs.MultiSpin.tiers) do
			t.check(tier.value >= 2 and tier.value <= 10, "MultiSpin tier value %d (the wheel spins 2..10 per press)", tier.value)
		end
	end)

	t.test("everything the wheel, the stall and the swords write is saved", function()
		local g = Game.new({ scripts = true })
		local SaveConfig = g:module("ReplicatedStorage.Config.SaveConfig")
		local Factory = g:module("ServerScriptService.BossSwordFactory")
		for _, attr in ipairs({ "Tokens", "MultiSpin", "PrefixSlots", "BonusSpinLevel", "SwordsFound", "ChasesFound",
			"LemonadeFound" }) do
			t.check(SaveConfig.ATTRIBUTES[attr] ~= nil, "player attribute %s is not in SaveConfig.ATTRIBUTES", attr)
		end
		-- a built sword's attributes: all persisted, except the two the rebuild re-derives
		local rederived = { BossDrop = "rebuild sets it", MeshGripFixed = "fitLook sets it from the template" }
		local saved = setOf(SaveConfig.SWORD_ATTRS)
		local seen = {}
		for _, pool in ipairs({ "Boss_Gorgon", "Boss_CelestialTitan", "IronLowlands", "VoidRift" }) do
			for _ = 1, 200 do
				local tool = Factory.build(pool, { level = 100, slots = 3 })
				for attr in pairs(tool:GetAttributes()) do seen[attr] = true end
				tool:Destroy()
			end
		end
		for _, attr in ipairs(keys(seen)) do
			t.check(saved[attr] or rederived[attr], "sword attribute %s is written but not saved (SaveConfig.SWORD_ATTRS)", attr)
		end
	end)

	t.test("every remote a script waits for is created by a server script, and none is orphaned", function()
		local g = Game.new({ scripts = { "RuntimeBootstrap" } })
		local created = {}
		for _, r in ipairs(g:find("ReplicatedStorage.RemoteEvents"):GetChildren()) do created[r.Name] = "RuntimeBootstrap" end
		local waited, looked, where = {}, {}, {}
		local function scan(dir)
			for _, name in ipairs(fs.readDir(dir)) do
				local path = dir .. "/" .. name
				if fs.isDir(path) then
					if name ~= "Packages" then scan(path) end
				elseif string.match(name, "%.luau$") then
					local src = fs.readFile(path)
					-- remotes:WaitForChild("X") / REMOTES:WaitForChild("X") / ("RemoteEvents"):WaitForChild("X")
					local lead = "[Rr][Ee][Mm][Oo][Tt][Ee][SsEe][%w_]*%s*[:%)\"]*%s*:%s*"
					for remote in string.gmatch(src, lead .. "WaitForChild%(%s*\"([%w_]+)\"") do
						waited[remote] = true
						where[remote] = where[remote] or path
					end
					for remote in string.gmatch(src, lead .. "FindFirstChild%(%s*\"([%w_]+)\"") do looked[remote] = true end
					-- another server script that makes its own RemoteEvent (e.g. the map's TravelAction)
					if string.match(name, "%.server%.luau$") and string.find(src, "Instance.new(\"RemoteEvent\")", 1, true) then
						for remote in string.gmatch(src, "%.Name%s*=%s*\"([%w_]+)\"") do
							created[remote] = created[remote] or path
						end
					end
				end
			end
		end
		scan("lemonade-game")
		for remote in pairs(waited) do
			t.check(created[remote] ~= nil, "%s waits for remote %q, which no server script creates", where[remote], remote)
		end
		for remote, by in pairs(created) do
			if by == "RuntimeBootstrap" then
				t.check(waited[remote] or looked[remote], "RuntimeBootstrap creates remote %q, which no script uses", remote)
			end
		end
		t.check(#keys(waited) >= 20, "the remote scan found only %d remotes (pattern broken?)", #keys(waited))
	end)

	t.test("prefix names are unique, every category has ten rungs, and every chase parses", function()
		local g = Game.new({})
		local WM = g:module("ReplicatedStorage.Config.WeaponModifiers")
		local names = {}
		t.eq(#WM.Rungs, WM.TIER_COUNT, "rung names")
		for category, data in pairs(WM.Categories) do
			t.eq(#data.Tiers, WM.TIER_COUNT, category .. " tiers")
			for _, tier in ipairs(data.Tiers) do
				t.check(not names[tier.name], "prefix %s is used by both %s and %s", tier.name, tostring(names[tier.name]), category)
				names[tier.name] = category
			end
		end
		for _, chase in ipairs(WM.Chases) do
			t.check(not names[chase.name], "chase %s reuses the %s prefix name", chase.name, tostring(names[chase.name]))
			names[chase.name] = "chase"
			t.check(WM.Categories[chase.category] ~= nil, "chase %s has unknown category %s", chase.name, tostring(chase.category))
			local active = WM.CollapsePrefixes(chase.name, 1)
			t.eq(active[1] and active[1].name, chase.name, "a saved " .. chase.name .. " prefix parses back")
		end
	end)
end
