--// save_migration.spec  (a pre-spin-wheel profile: Blessed swords, four-prefix swords, reforge fields)
-- The profile is seeded into the harness DataStore and loaded through the real join path
-- (PlayerAdded -> PlayerDataStore -> PlayerDataService.Load / Apply -> BossSwordFactory.rebuild),
-- then saved back through PlayerDataService.Release (the leave path) and read from the store.
local Game = require("../harness/game")

local USER = 4242

-- A profile as the game saved it before commit 41fbab9 (reforge + Blessed era). Sword attributes are
-- the SaveConfig.SWORD_ATTRS shape of that time; stats carry every prefix's bonus.
local function oldProfile(overrides)
	local p = {
		version = 1,
		leaderstats = { Level = 40, Experience = 1234, Gold = 5000, Rebirths = 0 },
		attributes = {
			SkillPoints = 3, WeaponLevel = 2, Strength = 5, Health = 4, Defense = 1, ExperienceGain = 0,
			ForgeLuckCharges = 4,             -- removed with the Reforge anvil
			AutoSellLowerSwords = true,       -- removed with auto-sell
			CompletedQuests = "q1_first_blood,q2_prove_yourself", ActiveQuestId = "q3", QuestProgress = 2,
			DiscoveredWaypoints = "",
		},
		inventory = {},
		swords = {
			{ -- a Blessed Legendary with four prefixes, equipped
				name = "Blessed Mythic Keen Titan Quaking Pit Sovereign",
				attrs = { DamageMult = 3.1, BonusDamagePct = 0.7, CritChance = 0.08, RangeBonus = 8, KnockbackBonus = 130,
					ExtraSlot = true, Prefixes = "Mythic, Keen, Titan, Quaking", BossTier = 1, Rarity = "Legendary",
					BaseWeaponName = "Pit Sovereign", WeaponAppearanceMaterial = "Neon", PoolBase = 3.1,
					PoolKey = "Boss_Gorgon" },
				color = { 1, 0.8, 0.2 }, material = "Neon", equipped = true,
			},
			{ -- four prefixes, not Blessed, with an old rung-10 name (Squeezed) that must still parse
				name = "Squeezed Sly Long Heavy Warlord Greatsword",
				attrs = { DamageMult = 2.4, BonusDamagePct = 2.2, CritChance = 0.15, RangeBonus = 4.5, KnockbackBonus = 40,
					Prefixes = "Squeezed, Sly, Long, Heavy", BossTier = 1, Rarity = "Epic",
					BaseWeaponName = "Warlord Greatsword", WeaponAppearanceMaterial = "Metal", PoolBase = 2.4,
					PoolKey = "Boss_Gorgon" },
				color = { 0.6, 0.6, 0.6 }, material = "Metal",
			},
			{ -- an ordinary one-prefix sword: must come back exactly as saved
				name = "Honed Rivetsteel Blade",
				attrs = { DamageMult = 1.18, BonusDamagePct = 0.15, CritChance = 0, RangeBonus = 0, KnockbackBonus = 0,
					Prefixes = "Honed", BossTier = 1, Rarity = "Uncommon", BaseWeaponName = "Rivetsteel Blade",
					WeaponAppearanceMaterial = "Metal", PoolBase = 1.18, PoolKey = "IronLowlands", Lesser = true },
				color = { 0.7, 0.7, 0.8 }, material = "Metal",
			},
		},
		vault = {
			{ -- a Sour Blessed Epic with three prefixes, stored with the Vaultkeeper
				name = "Sour Blessed Godly Sly Reaching Ironjaw Saber",
				attrs = { DamageMult = 1.6, BonusDamagePct = 0.85, CritChance = 0.255, RangeBonus = 5.1, KnockbackBonus = 0,
					ExtraSlot = true, Prefixes = "Godly, Sly, Reaching", BossTier = 1, Rarity = "Epic",
					BaseWeaponName = "Ironjaw Saber", WeaponAppearanceMaterial = "Metal", PoolBase = 1.6,
					PoolKey = "Boss_Gorgon", Variant = "Sour" },
				color = { 0.5, 0.5, 0.5 }, material = "Metal",
			},
			{ -- a four-prefix Rare (never Blessed) stored with the Vaultkeeper
				name = "Nova Deadly Colossal Heavy Pit Shiv",
				attrs = { DamageMult = 1.4, BonusDamagePct = 1.2, CritChance = 0.22, RangeBonus = 6, KnockbackBonus = 40,
					Prefixes = "Nova, Deadly, Colossal, Heavy", BossTier = 1, Rarity = "Rare",
					BaseWeaponName = "Pit Shiv", WeaponAppearanceMaterial = "Metal", PoolBase = 1.4,
					PoolKey = "Boss_Gorgon" },
				color = { 0.5, 0.5, 0.5 }, material = "Metal",
			},
		},
		-- the removed Reforge anvil's counters: nothing reads them, nothing may drop them
		reforgePity = 7, reforgeFreeAt = 1789999000, reforgeBest = 812, reforgeCount = 55, reforgeTailPity = 3,
		reforgeRecent = { 4, 5, 6 },
		dropPity = 2, dropRarePity = 5, dropKills = 900,
		bossFirstDrops = { Boss_Gorgon = true },
		merchantPity = 1, merchantCount = 4, vaultSlots = 1, wealthRung = 2, wealthBest = 50000,
		isNew = false,
		-- no zoneDepth, no spinCount, no Tokens / MultiSpin / PrefixSlots: all newer than this save
	}
	for k, v in pairs(overrides or {}) do p[k] = v end
	return p
end

local function boot(profile)
	local g = Game.new({ scripts = true })
	local player = g:addPlayer({ userId = USER, profile = profile })
	g:advance(1.5) -- the starter de-dupe (SwordDropSystem) runs a second after spawn
	return g, player
end

local function swordsByBase(player)
	local out = {}
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		for _, tool in ipairs(container and container:GetChildren() or {}) do
			if tool:IsA("Tool") and tool:GetAttribute("BaseWeaponName") then
				out[tool:GetAttribute("BaseWeaponName")] = tool
			end
		end
	end
	return out
end

local function savedRecord(g)
	local SaveConfig = g:module("ReplicatedStorage.Config.SaveConfig")
	return g.world:dataStore(SaveConfig.DATASTORE_NAME):Read(SaveConfig.KEY_PREFIX .. USER)
end

return function(t)
	t.test("an old profile with Blessed and four-prefix swords loads", function()
		local g, player = boot(oldProfile())
		t.expect(player:GetAttribute("DataLoaded") == true, "DataLoaded is %s", tostring(player:GetAttribute("DataLoaded")))
		t.eq(#g.world:logged("setup failed"), 0, "PlayerDataStore setup failures")
		t.eq(#g.world:logged("load failed"), 0, "PlayerDataService load failures")
		local stats = player:FindFirstChild("leaderstats")
		t.eq(stats.Level.Value, 40, "Level")
		t.eq(stats.Gold.Value, 5000, "Gold")
		t.eq(player:GetAttribute("CompletedQuests"), "q1_first_blood,q2_prove_yourself", "CompletedQuests")
		t.eq(player:GetAttribute("PrefixSlots"), 1, "PrefixSlots backfilled")
		t.eq(player:GetAttribute("Tokens"), 0, "Tokens backfilled")
		local swords = swordsByBase(player)
		for _, name in ipairs({ "Pit Sovereign", "Warlord Greatsword", "Rivetsteel Blade" }) do
			t.check(swords[name] ~= nil, "saved sword %s was not restored to the player", name)
		end
	end)

	t.test("extra prefixes collapse to the player's one owned slot, strongest first, stats re-derived", function()
		local g, player = boot(oldProfile())
		local BossWeapons = g:module("ReplicatedStorage.Config.BossWeapons")
		local swords = swordsByBase(player)
		local cases = {
			{ base = "Pit Sovereign", pool = "Boss_Gorgon", active = "Mythic", stored = "Mythic, Keen, Titan, Quaking",
				name = "Mythic Pit Sovereign", damage = 0.70 },
			{ base = "Warlord Greatsword", pool = "Boss_Gorgon", active = "Squeezed", stored = "Squeezed, Sly, Long, Heavy",
				name = "Squeezed Warlord Greatsword", damage = 2.20 },
		}
		for _, c in ipairs(cases) do
			local tool = swords[c.base]
			if t.check(tool, "%s missing", c.base) then
				t.eq(tool:GetAttribute("Prefixes"), c.active, c.base .. " active Prefixes")
				t.eq(tool:GetAttribute("StoredPrefixes"), c.stored, c.base .. " StoredPrefixes")
				t.eq(tool.Name, c.name, c.base .. " tool name")
				t.check(not string.find(tool.Name, "Blessed", 1, true), "%s still named Blessed: %s", c.base, tool.Name)
				-- stats now carry only the active prefix (plus the sword's own inherent bonuses)
				local data = BossWeapons.Resolve(c.pool, c.base, tool:GetAttribute("Rarity"))
				t.near(tool:GetAttribute("BonusDamagePct"), c.damage + (data.inherentBonusDmg or 0), 1e-9, c.base .. " BonusDamagePct")
				t.near(tool:GetAttribute("CritChance"), data.inherentCrit or 0, 1e-9, c.base .. " CritChance (Keen / Sly dropped)")
				t.near(tool:GetAttribute("KnockbackBonus"), data.inherentKnockback or 0, 1e-9, c.base .. " KnockbackBonus")
				t.eq(tool:GetAttribute("DamageMult"), g.world.typeof(tool:GetAttribute("DamageMult")) == "number"
					and tool:GetAttribute("DamageMult") or nil, c.base .. " DamageMult kept")
			end
		end
		t.eq(swords["Pit Sovereign"]:GetAttribute("DamageMult"), 3.1, "rolled base kept, not re-rolled")
		-- a one-prefix sword is not touched at all: it comes back exactly as saved
		local plain = swords["Rivetsteel Blade"]
		if t.check(plain, "Rivetsteel Blade missing") then
			t.eq(plain.Name, "Honed Rivetsteel Blade", "unchanged sword name")
			t.eq(plain:GetAttribute("Prefixes"), "Honed", "unchanged sword Prefixes")
			t.eq(plain:GetAttribute("StoredPrefixes"), nil, "unchanged sword StoredPrefixes")
			t.eq(plain:GetAttribute("BonusDamagePct"), 0.15, "unchanged sword BonusDamagePct")
			t.eq(plain:GetAttribute("DamageMult"), 1.18, "unchanged sword DamageMult")
		end
	end)

	t.test("a player who owns two slots keeps two; unlocking a third wakes the next stored prefix", function()
		local profile = oldProfile()
		profile.attributes.PrefixSlots = 2
		local g, player = boot(profile)
		local sword = swordsByBase(player)["Pit Sovereign"]
		-- Mythic (6) then the tie Titan / Quaking (5) broken by saved order: Titan
		t.eq(sword:GetAttribute("Prefixes"), "Mythic, Titan", "two slots")
		player:SetAttribute("PrefixSlots", 3)
		g:flush()
		t.eq(sword:GetAttribute("Prefixes"), "Mythic, Titan, Quaking", "after unlocking slot 3")
		t.eq(sword:GetAttribute("StoredPrefixes"), "Mythic, Keen, Titan, Quaking", "stored list unchanged")
		local vault = g:module("ServerScriptService.PlayerDataService").GetVault(player)
		-- Godly (5), then the tie Sly / Reaching (2) broken by saved order: Sly
		t.eq(vault[1].attrs.Prefixes, "Godly, Sly", "vault entry collapsed to two slots at load")
	end)

	t.test("saving keeps every stored field of the old profile and writes the collapsed swords", function()
		local g, player = boot(oldProfile())
		g:removePlayer(player) -- PlayerRemoving -> PlayerDataService.Release -> Save(releaseLock)
		local rec = savedRecord(g)
		t.expect(rec ~= nil, "nothing was saved")
		t.eq(rec.__lock, nil, "session lock released on leave")
		for key, value in pairs({ reforgePity = 7, reforgeFreeAt = 1789999000, reforgeBest = 812, reforgeCount = 55,
			reforgeTailPity = 3, dropPity = 2, dropRarePity = 5, dropKills = 900, merchantPity = 1, merchantCount = 4,
			vaultSlots = 1, wealthRung = 2, wealthBest = 50000 }) do
			t.eq(rec[key], value, "record." .. key)
		end
		t.eq(rec.reforgeRecent and table.concat(rec.reforgeRecent, ","), "4,5,6", "record.reforgeRecent")
		t.eq(rec.bossFirstDrops and rec.bossFirstDrops.Boss_Gorgon, true, "record.bossFirstDrops")
		t.eq(rec.attributes.ForgeLuckCharges, 4, "attributes.ForgeLuckCharges (removed, carried along)")
		t.eq(rec.attributes.AutoSellLowerSwords, true, "attributes.AutoSellLowerSwords (removed, carried along)")
		t.eq(rec.attributes.Strength, 5, "attributes.Strength")
		t.eq(rec.leaderstats.Level, 40, "leaderstats.Level")
		t.eq(rec.leaderstats.Gold, 5000, "leaderstats.Gold")
		t.eq(rec.attributes.Tokens, 0, "attributes.Tokens added")
		t.eq(rec.attributes.PrefixSlots, 1, "attributes.PrefixSlots added")
		t.eq(type(rec.zoneDepth), "table", "zoneDepth rebuilt for the spin wheel")
		local saved = {}
		for _, entry in ipairs(rec.swords) do saved[entry.attrs.BaseWeaponName] = entry end
		local pit = saved["Pit Sovereign"]
		if t.check(pit, "Pit Sovereign not saved") then
			t.eq(pit.attrs.Prefixes, "Mythic", "saved Pit Sovereign Prefixes")
			t.eq(pit.attrs.StoredPrefixes, "Mythic, Keen, Titan, Quaking", "saved Pit Sovereign StoredPrefixes")
			t.eq(pit.name, "Mythic Pit Sovereign", "saved Pit Sovereign name")
		end
		t.check(saved["Warlord Greatsword"] and saved["Rivetsteel Blade"], "every sword saved")
		t.eq(rec.vault[1].attrs.StoredPrefixes, "Godly, Sly, Reaching", "vault StoredPrefixes")
		t.eq(rec.vault[1].attrs.Prefixes, "Godly", "vault Prefixes")
		t.eq(rec.vault[2].attrs.StoredPrefixes, "Nova, Deadly, Colossal, Heavy", "vault #2 StoredPrefixes")
		t.eq(rec.vault[2].attrs.Prefixes, "Nova", "vault #2 Prefixes")
	end)

	t.test("the collapsed save reloads identically (the migration is idempotent)", function()
		local g1, p1 = boot(oldProfile())
		g1:removePlayer(p1)
		local first = savedRecord(g1)
		local g2, p2 = boot(first)
		local swords = swordsByBase(p2)
		t.eq(swords["Pit Sovereign"]:GetAttribute("Prefixes"), "Mythic", "reloaded Prefixes")
		t.eq(swords["Pit Sovereign"]:GetAttribute("StoredPrefixes"), "Mythic, Keen, Titan, Quaking", "reloaded StoredPrefixes")
		t.eq(swords["Pit Sovereign"].Name, "Mythic Pit Sovereign", "reloaded name")
		g2:removePlayer(p2)
		local second = savedRecord(g2)
		local a, b = {}, {}
		for _, e in ipairs(first.swords) do a[e.attrs.BaseWeaponName] = e end
		for _, e in ipairs(second.swords) do b[e.attrs.BaseWeaponName] = e end
		for base, e in pairs(a) do
			t.eq(b[base] and b[base].name, e.name, base .. " name across a second load")
			t.eq(b[base] and b[base].attrs.Prefixes, e.attrs.Prefixes, base .. " Prefixes across a second load")
			t.eq(b[base] and b[base].attrs.BonusDamagePct, e.attrs.BonusDamagePct, base .. " BonusDamagePct across a second load")
		end
		t.eq(second.vault[1].name, first.vault[1].name, "vault name across a second load")
	end)

	-- Backpack swords collapse inside BossSwordFactory.rebuild. Vault entries are collapsed earlier,
	-- in PlayerDataService.Load, which rewrites attrs.Prefixes / StoredPrefixes and drops "Blessed"
	-- from the name but leaves the stat attributes and the other prefix words in the name. On
	-- withdrawal, rebuild -> applySlots then finds the active list unchanged and returns early.
	t.test("a migrated multi-prefix vault sword is withdrawn collapsed (name and stats)", function()
		local g, player = boot(oldProfile())
		local PDS = g:module("ServerScriptService.PlayerDataService")
		local Factory = g:module("ServerScriptService.BossSwordFactory")
		local WM = g:module("ReplicatedStorage.Config.WeaponModifiers")
		local BossWeapons = g:module("ReplicatedStorage.Config.BossWeapons")
		local SwordValue = g:module("ReplicatedStorage.Config.SwordValue")
		local cases = {
			{ base = "Ironjaw Saber", active = "Godly", name = "Sour Godly Ironjaw Saber", damage = 0.50 * 1.7 },
			{ base = "Pit Shiv", active = "Nova", name = "Nova Pit Shiv", damage = 1.20 },
		}
		local byBase = {}
		for _, entry in ipairs(PDS.GetVault(player)) do byBase[entry.attrs.BaseWeaponName] = entry end
		for _, c in ipairs(cases) do
			local entry = byBase[c.base]
			if t.check(entry, "vault entry %s missing", c.base) then
				local withdrawn = Factory.rebuild(entry, WM.SlotsOf(player)) -- what VaultSystem's withdraw does
				local data = BossWeapons.Resolve("Boss_Gorgon", c.base, entry.attrs.Rarity)
				t.eq(withdrawn:GetAttribute("Prefixes"), c.active, c.base .. " withdrawn Prefixes")
				t.eq(withdrawn.Name, c.name, c.base .. " withdrawn sword name")
				t.near(withdrawn:GetAttribute("BonusDamagePct"), c.damage + (data.inherentBonusDmg or 0), 1e-9,
					c.base .. " withdrawn BonusDamagePct (only the active prefix)")
				t.near(withdrawn:GetAttribute("CritChance"), data.inherentCrit or 0, 1e-9,
					c.base .. " withdrawn CritChance (inactive crit prefix must not count)")
				t.near(withdrawn:GetAttribute("RangeBonus"), data.inherentRange or 0, 1e-9,
					c.base .. " withdrawn RangeBonus (inactive range prefix must not count)")
				t.eq(entry.name, withdrawn.Name, c.base .. " vault card name vs the sword withdrawn")
				t.eq(SwordValue.rateAttrs(entry.attrs), SwordValue.rateTool(withdrawn), c.base .. " vault card rating")
			end
		end
	end, { knownIssue = "vault swords migrated in PlayerDataService.Load keep every old prefix's stats and "
		.. "their old prefix words in the name when withdrawn (applySlots sees Prefixes already collapsed and "
		.. "returns early)" })

	t.test("the pre-spin profile gets a spin depth from its level and first boss kill", function()
		local g, player = boot(oldProfile())
		local SpinService = g:module("ServerScriptService.SpinService")
		local SpinPools = g:module("ReplicatedStorage.Config.SpinPools")
		for _, pool in ipairs(SpinPools.Pools) do
			local step = SpinService.StepOf(player, pool.zone)
			if pool.gate <= 40 then
				t.check(step >= 1, "%s (gate %d) should be reached at Lv 40, step %d", pool.zone, pool.gate, step)
			else
				t.eq(step, 0, pool.zone .. " (gate " .. pool.gate .. ") step at Lv 40")
			end
		end
		t.eq(SpinService.StepOf(player, "IronLowlands"), 4, "Iron Lowlands: the Warden of the Pit already paid a first sword")
		t.eq(player:GetAttribute("SpinZone"), "Stormwatch", "default spin area at Lv 40")
		t.eq(#g.world:logged("pre%-spin profile migrated"), 1, "migration logged once")
	end)

	t.test("a DataStore hiccup on join is retried; a profile that cannot load is never overwritten", function()
		-- one failed UpdateAsync, then success after the retry's back-off
		local g = Game.new({ scripts = true })
		local SaveConfig = g:module("ReplicatedStorage.Config.SaveConfig")
		local store = g.world:dataStore(SaveConfig.DATASTORE_NAME)
		store:FailNext(1)
		local player = g:addPlayer({ userId = USER, profile = oldProfile() })
		t.check(player:GetAttribute("DataLoaded") ~= true, "loaded before the retry back-off elapsed")
		g:advance(2)
		t.eq(player:GetAttribute("DataLoaded"), true, "DataLoaded after one retried failure")
		t.eq(player.leaderstats.Level.Value, 40, "Level after retry")

		-- every attempt fails: safe defaults, and the stored profile is left untouched on leave
		local g2 = Game.new({ scripts = true })
		local store2 = g2.world:dataStore(SaveConfig.DATASTORE_NAME)
		store2:Seed(SaveConfig.KEY_PREFIX .. USER, oldProfile())
		store2:FailNext(SaveConfig.MAX_RETRIES)
		local p2 = g2:addPlayer({ userId = USER })
		g2:advance(30)
		t.eq(#g2.world:logged("load failed"), 1, "load failure reported")
		p2:SetAttribute("Tokens", 999)
		g2:removePlayer(p2)
		local rec = store2:Read(SaveConfig.KEY_PREFIX .. USER)
		t.eq(rec.leaderstats.Level, 40, "stored Level survives a failed load")
		t.eq(rec.attributes.Tokens, nil, "nothing from the failed session was written")
		t.eq(#rec.swords, 3, "stored swords survive a failed load")
		t.eq(#rec.vault, 2, "stored vault survives a failed load")
	end)
end
