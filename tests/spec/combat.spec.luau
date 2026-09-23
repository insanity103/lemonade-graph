--// combat.spec  (sword swings, unarmed hits, and enemies hitting back)
-- The real combat scripts run: SwordSystem (the 5-hit combo, Tool.Activated), EnemyCombat (every
-- enemy rig from WorldLayout, its AI loop and its swings), LevelingSystem and SwordDropSystem (what a
-- kill pays). There is no physics: rigs never walk, so a test puts the player where the fight is.
-- Swing damage is checked against the public configs (Config.Sword, Config.ComboConfig); enemy
-- stats live only inside EnemyCombat, so they are read off the rigs it builds, and enemy damage is
-- checked through ratios the code promises (Defense, crowd sharing) rather than a copied formula.
local Game = require("../harness/game")
local D = require("../harness/datatypes")
local Vector3, CFrame = D.Vector3, D.CFrame

local SCRIPTS = { "RuntimeBootstrap", "PlayerDataStore", "LevelingSystem", "SwordSystem", "EnemyCombat",
	"SwordDropSystem", "GameplayServices" }
-- An open patch of baseplate: out of town and far (>200 studs) from every WorldLayout camp.
local ARENA = Vector3.new(300, 3, 300)

local function boot(options)
	options = options or {}
	local g = Game.new({ scripts = options.scripts or SCRIPTS })
	local player = g:addPlayer({ userId = 555, position = options.position or ARENA })
	return g, player
end

local function rigs(g, filter)
	local out = {}
	for _, m in ipairs(g.world.workspace:GetChildren()) do
		if m:GetAttribute("Enemy") == true and m:FindFirstChildOfClass("Humanoid") and (not filter or filter(m)) then
			table.insert(out, m)
		end
	end
	return out
end

-- A passive training target (no AI): a rig with the attributes EnemyCombat stamps and lots of health.
local function dummy(g, position, health)
	local model, humanoid = g:spawnEnemy({ zone = "IronLowlands", level = 1, position = position })
	humanoid.MaxHealth = health or 1e6
	humanoid.Health = health or 1e6
	return model, humanoid
end

-- Equip the player's starter sword (optionally re-rolled with `attrs`) and face +Z... the
-- character looks along -Z by default, so "in front" is ARENA + (0, 0, -d).
local function equip(g, player, attrs)
	local tool = player.Backpack:FindFirstChildOfClass("Tool")
	assert(tool, "no sword in the backpack")
	for k, v in pairs(attrs or {}) do tool:SetAttribute(k, v) end
	tool.Parent = player.Character
	g:flush()
	return tool
end

local function swing(g, tool)
	tool:Activate()
	g:flush()
end

local function ahead(d) return ARENA + Vector3.new(0, 0, -d) end

local function comboSent(g, player)
	local log = g.world:fired(g:remote("ComboUpdate"))
	for i = #log, 1, -1 do
		if log[i].player == player then return log[i].args[1] end
	end
	return nil
end

-- Keep only `keep` enemy rigs (others are removed without dying, so nothing respawns).
local function isolate(g, keep)
	local keepSet = {}
	for _, m in ipairs(keep) do keepSet[m] = true end
	for _, m in ipairs(rigs(g)) do
		if not keepSet[m] then m:Destroy() end
	end
	g:flush()
end

-- Every Health drop on this humanoid, in order.
local function recordHits(humanoid)
	local hits = {}
	local last = humanoid.Health
	humanoid.HealthChanged:Connect(function(now)
		if now < last then table.insert(hits, last - now) end
		last = now
	end)
	return hits
end

local function firstRig(g, archetype, level)
	for _, m in ipairs(rigs(g)) do
		if m:GetAttribute("Archetype") == archetype and (level == nil or m:GetAttribute("EnemyLevel") == level) then
			return m
		end
	end
	error("no " .. archetype .. " rig")
end

return function(t)
	t.test("every WorldLayout spawn becomes an enemy rig with the stats its level and role promise", function()
		local g = Game.new({ scripts = SCRIPTS })
		local WorldLayout = g:module("ServerScriptService.WorldLayout")
		local SafeHub = g:module("ServerScriptService.SafeHub")
		local spawns = WorldLayout.GetEnemySpawns()
		local all = rigs(g)
		t.eq(#all, #spawns, "rigs spawned vs WorldLayout.GetEnemySpawns()")
		local perLevelXP, healthByLevel = {}, {}
		for _, m in ipairs(all) do
			local arch, level = m:GetAttribute("Archetype"), m:GetAttribute("EnemyLevel")
			local hum = m:FindFirstChildOfClass("Humanoid")
			local label = string.format("%s Lv %s", tostring(arch), tostring(level))
			t.check(typeof(arch) == "string" and typeof(level) == "number" and level >= 1, "%s: missing Archetype / EnemyLevel", label)
			t.check(typeof(m:GetAttribute("Zone")) == "string", "%s: no Zone attribute (tokens and depth read it)", label)
			t.check(m:HasTag("Enemy"), "%s: not tagged Enemy", label)
			t.check(hum.MaxHealth > 0 and hum.Health == hum.MaxHealth, "%s: spawns at %s / %s HP", label, hum.Health, hum.MaxHealth)
			t.check(not SafeHub.contains(m.PrimaryPart.Position), "%s: spawned inside town", label)
			local xp = m:GetAttribute("ExperienceReward")
			if t.check(typeof(xp) == "number" and xp > 0, "%s: ExperienceReward %s", label, tostring(xp)) then
				-- XP is linear in level for every archetype (EnemyCombat: baseXP x level)
				local per = xp / level
				perLevelXP[arch] = perLevelXP[arch] or per
				t.check(math.abs(per - perLevelXP[arch]) < 1, "%s pays %d XP: not the archetype's %.1f per level", label, xp,
					perLevelXP[arch])
			end
			healthByLevel[arch] = healthByLevel[arch] or {}
			healthByLevel[arch][level] = hum.MaxHealth
			-- a Boss_ archetype is a real boss; a warden is SpawnRole boss without the Boss attribute
			local isBossArch = string.sub(arch, 1, 5) == "Boss_"
			t.eq(m:GetAttribute("Boss"), isBossArch, label .. " Boss attribute")
			if m:GetAttribute("SpawnRole") == "boss" and not isBossArch then
				t.eq(m:GetAttribute("Boss"), false, label .. " (warden) Boss attribute")
			end
		end
		-- health never falls as level rises within an archetype
		for arch, byLevel in pairs(healthByLevel) do
			local levels = {}
			for lv in pairs(byLevel) do table.insert(levels, lv) end
			table.sort(levels)
			for i = 2, #levels do
				t.check(byLevel[levels[i]] >= byLevel[levels[i - 1]], "%s: Lv %d has %d HP, less than Lv %d's %d", arch,
					levels[i], byLevel[levels[i]], levels[i - 1], byLevel[levels[i - 1]])
			end
		end
		t.note("%d rigs, %d archetypes", #all, #(function() local n = {} for k in pairs(perLevelXP) do table.insert(n, k) end return n end)())
	end)

	t.test("a sword's 5-hit combo deals Config.Sword damage times each hit's ComboConfig multiplier", function()
		local g, player = boot()
		local Sword = g:module("ReplicatedStorage.Config.Sword")
		local Combo = g:module("ReplicatedStorage.Config.ComboConfig")
		local _, target = dummy(g, ahead(3))
		player:SetAttribute("Strength", 4)
		player:SetAttribute("WeaponLevel", 2)
		player:SetAttribute("RebirthDamageMult", 1.1)
		local tool = equip(g, player, { DamageMult = 1.5, BonusDamagePct = 0.2, CritChance = 0 })
		local base = (Sword.BaseDamage + Sword.StrengthDamagePerPoint * 4) * 1.5 * 1.2 * (1 + Sword.WeaponDamagePerLevel * 2) * 1.1
		for hit = 1, Combo.MAX_COMBO + 1 do
			local index = (hit - 1) % Combo.MAX_COMBO + 1
			local before = target.Health
			swing(g, tool)
			t.eq(comboSent(g, player), index, "combo index sent to the client on swing " .. hit)
			t.eq(before - target.Health, math.max(1, math.floor(base * Combo.COMBO_DAMAGE_MULT[index])),
				string.format("swing %d (combo hit %d) damage", hit, index))
			g:advance(Combo.ENDLAG[index] + 0.01)
		end
		t.check(player:GetAttribute("CombatAt") ~= nil, "a landed hit stamps CombatAt (the spin wheel's combat lock)")
	end)

	t.test("endlag swallows an early swing, and the combo resets after COMBO_RESET_TIME", function()
		local g, player = boot()
		local Combo = g:module("ReplicatedStorage.Config.ComboConfig")
		local _, target = dummy(g, ahead(3))
		local tool = equip(g, player, { CritChance = 0 })
		swing(g, tool)
		local afterFirst = target.Health
		swing(g, tool) -- inside hit 1's endlag
		t.eq(target.Health, afterFirst, "a swing during endlag deals nothing")
		g:advance(Combo.ENDLAG[1] + 0.01)
		swing(g, tool)
		t.eq(comboSent(g, player), 2, "the next swing after endlag is combo hit 2")
		g:advance(Combo.COMBO_RESET_TIME + 0.1)
		swing(g, tool)
		t.eq(comboSent(g, player), 1, "after COMBO_RESET_TIME the combo starts over")
	end)

	t.test("a crit multiplies the hit by 1.75, or by the rebirth crit multiplier", function()
		local g, player = boot()
		local Sword = g:module("ReplicatedStorage.Config.Sword")
		local _, target = dummy(g, ahead(3))
		local tool = equip(g, player, { CritChance = 1 })
		local before = target.Health
		swing(g, tool)
		t.eq(before - target.Health, math.floor(Sword.BaseDamage * 1.75), "crit damage at the default 1.75x")
		local log = g.world:fired(g:remote("DamageNumber"))
		t.eq(log[#log].args[3], "crit", "damage number kind")
		g:advance(2)
		player:SetAttribute("RebirthCritDamageMult", 2.5)
		before = target.Health
		swing(g, tool)
		t.eq(before - target.Health, math.floor(Sword.BaseDamage * 2.5), "crit damage with RebirthCritDamageMult 2.5")
	end)

	t.test("the sword hitbox reaches what is in front, not what is behind; RangeBonus extends it", function()
		local g, player = boot()
		local _, front = dummy(g, ahead(3))
		local _, behind = dummy(g, ARENA + Vector3.new(0, 0, 6))
		local _, far = dummy(g, ahead(13))
		local tool = equip(g, player, { CritChance = 0 })
		swing(g, tool)
		t.check(front.Health < front.MaxHealth, "a target 3 studs in front was not hit")
		t.eq(behind.Health, behind.MaxHealth, "a target 6 studs behind")
		t.eq(far.Health, far.MaxHealth, "a target 13 studs in front, no range bonus")
		g:advance(2)
		tool.Parent = player.Backpack
		g:flush()
		equip(g, player, { RangeBonus = 10 })
		swing(g, tool)
		t.check(far.Health < far.MaxHealth, "RangeBonus 10 did not reach a target 13 studs in front")
	end)

	t.test("killing a real rig with the sword pays the swinger its XP, gold and tokens", function()
		local g, player = boot()
		local GoldCurve = g:module("ReplicatedStorage.Config.GoldCurve")
		local TokenRules = g:module("ReplicatedStorage.Config.TokenRules")
		local SpinService = g:module("ServerScriptService.SpinService")
		local rig = firstRig(g, "IronSquire", 1)
		isolate(g, { rig })
		local xp = rig:GetAttribute("ExperienceReward")
		local rigHum = rig:FindFirstChildOfClass("Humanoid")
		-- stand 3 studs from the rig, facing it
		local at = rig.PrimaryPart.Position + Vector3.new(0, 0, 3)
		player.Character.HumanoidRootPart.CFrame = CFrame.lookAt(at, rig.PrimaryPart.Position)
		local tool = equip(g, player, { CritChance = 0 })
		local swings = 0
		while rigHum.Health > 0 and swings < 30 do
			swing(g, tool)
			swings += 1
			g:advance(0.6)
		end
		t.expect(rigHum.Health <= 0, "the rig survived %d swings", swings)
		t.eq(player.leaderstats.Experience.Value, xp, "XP after the kill (Lv 1 needs 100, so no level-up)")
		t.eq(player.leaderstats.Gold.Value, GoldCurve.PerKill(1, "minion"), "gold after the kill")
		local tokens = player:GetAttribute("Tokens")
		local band = TokenRules.PER_KILL.minion
		t.check(tokens >= band[1] and tokens <= band[2], "tokens after the kill: %d (band %d-%d)", tokens, band[1], band[2])
		t.eq(SpinService.StepOf(player, "IronLowlands"), 1, "the kill records depth in the Iron Lowlands")
		g:advance(10)
		t.eq(#rigs(g, function(m) return m:GetAttribute("Archetype") == "IronSquire" end) >= 1, true,
			"the dead rig respawns (EnemyCombat RESPAWN_DELAY)")
	end)

	t.test("unarmed attacks hit the nearest enemy in range, respect the cooldown, and yield to a held sword", function()
		local g, player = boot()
		local remote = g:remote("EnemyAttack")
		local _, near = dummy(g, ahead(5))
		local _, farther = dummy(g, ahead(8))
		player:SetAttribute("Strength", 2)
		remote.OnServerEvent:Fire(player)
		g:flush()
		t.eq(near.MaxHealth - near.Health, 25 + 5 * 2, "unarmed damage to the nearest enemy (25 + 5 per Strength)")
		t.eq(farther.Health, farther.MaxHealth, "only the nearest enemy is hit")
		remote.OnServerEvent:Fire(player) -- inside the 0.4 s cooldown
		g:flush()
		t.eq(near.MaxHealth - near.Health, 35, "a second press inside the cooldown")
		g:advance(0.5)
		equip(g, player)
		remote.OnServerEvent:Fire(player)
		g:flush()
		t.eq(near.MaxHealth - near.Health, 35, "no unarmed hit while a sword is held (SwordSystem owns that)")
	end)

	t.test("enemy hits: Defense cuts 0.3% a point up to a 35% cap, and a crowd shares its damage", function()
		local function perHit(defense, crowd)
			local g, player = boot()
			local rig = firstRig(g, "IronSquire", 1)
			-- the rig and (for a crowd) packmates standing within reach of the player
			local keep = { rig }
			for _, m in ipairs(rigs(g)) do
				if #keep < crowd and m ~= rig and m:GetAttribute("PackId") == rig:GetAttribute("PackId") then
					table.insert(keep, m)
				end
			end
			isolate(g, keep)
			local center = rig.PrimaryPart.Position
			for i, m in ipairs(keep) do
				-- a camp mixes levels (WorldLayout cycles {1, 2} through it); the AI reads EnemyLevel on
				-- every tick, so the crowd is put on the lone rig's level to compare like with like
				m:SetAttribute("EnemyLevel", rig:GetAttribute("EnemyLevel"))
				-- packmates stand in a tight ring (well inside their leash, within reach of the player)
				local a = i * 2 * math.pi / #keep
				m:PivotTo(CFrame.new(center + Vector3.new(math.cos(a) * 2.5, 0, math.sin(a) * 2.5)))
			end
			player:SetAttribute("Defense", defense)
			g:moveTo(player, center)
			local hits = recordHits(player.Character:FindFirstChildOfClass("Humanoid"))
			g:advance(8)
			return hits, #keep
		end
		local base = perHit(0, 1)
		t.expect(#base >= 3, "a lone Lv 1 rig landed only %d hits in 8 s", #base)
		for i = 2, #base do t.near(base[i], base[1], 1e-9, "a lone rig's hit " .. i) end
		local armored = perHit(50, 1)
		t.expect(#armored >= 1, "no hits against Defense 50")
		t.near(armored[1] / base[1], 1 - 50 * 0.003, 1e-9, "Defense 50: damage ratio")
		local capped = perHit(1000, 1)
		t.expect(#capped >= 1, "no hits against Defense 1000")
		t.near(capped[1] / base[1], 1 - 0.35, 1e-9, "Defense 1000: damage ratio (35% cap)")
		local crowd, n = perHit(0, 6) -- the whole camp (the first Lowlands camp is a pack of 3)
		t.expect(n >= 2, "the camp has only %d rig", n)
		t.expect(#crowd >= 2 * n, "a crowd of %d landed only %d hits in 8 s", n, #crowd)
		-- each hit is a lone hit x k^-0.5, k = the rigs that swung inside the crowd window (1..n; the
		-- AI's swing jitter decides k hit by hit), and the whole crowd is sharing at some point
		local smallest = math.huge
		for i, hit in ipairs(crowd) do
			local ratio = hit / base[1]
			local k = math.floor(ratio ^ -2 + 0.5)
			t.check(k >= 1 and k <= n and math.abs(ratio - k ^ -0.5) < 1e-9,
				"a crowd hit %d is %.4f x a lone hit: not 1/sqrt(k) for any crowd size k <= %d", i, ratio, n)
			smallest = math.min(smallest, ratio)
		end
		t.near(smallest, n ^ -0.5, 1e-9, string.format("a crowd of %d sharing: smallest per-hit damage ratio", n))
		t.note("lone Lv 1 Quarry Cutthroat hit %.3f; %d hits in 8 s", base[1], #base)
	end)

	t.test("stepping out of reach during an enemy's windup dodges the hit; hits taken stamp CombatAt", function()
		local g, player = boot()
		local rig = firstRig(g, "IronSquire", 1)
		isolate(g, { rig })
		local pos = rig.PrimaryPart.Position
		g:moveTo(player, pos + Vector3.new(3, 0, 0))
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		local swings = 0
		rig:GetAttributeChangedSignal("EnemyAttack"):Connect(function()
			swings += 1
			g:moveTo(player, pos + Vector3.new(25, 0, 0)) -- out of reach before the blade lands
		end)
		g:advance(3)
		t.check(swings >= 1, "the rig never swung")
		t.eq(humanoid.Health, humanoid.MaxHealth, "health after dodging every swing")
		-- stand still and take one
		local g2, p2 = boot()
		local rig2 = firstRig(g2, "IronSquire", 1)
		isolate(g2, { rig2 })
		g2:moveTo(p2, rig2.PrimaryPart.Position + Vector3.new(3, 0, 0))
		g2:advance(3)
		t.check(p2.Character:FindFirstChildOfClass("Humanoid").Health < 100, "a player who stays is hit")
		t.check(p2:GetAttribute("CombatAt") ~= nil, "taking a hit stamps CombatAt")
	end)

	t.test("no enemy acquires or hits a player standing in town", function()
		local g, player = boot({ position = Vector3.new(0, 3, 0) })
		g:advance(15)
		t.eq(player.Character:FindFirstChildOfClass("Humanoid").Health, 100, "health in town after 15 s")
		for _, m in ipairs(rigs(g)) do
			if m:GetAttribute("EnemyAlert") ~= nil then
				t.check(false, "%s is chasing someone while the only player is in town", m.Name)
				break
			end
		end
	end)
end
