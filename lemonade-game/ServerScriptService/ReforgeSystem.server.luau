-- Script | ServerScriptService.ReforgeSystem | The Reforge anvil: pay gold to re-roll a relic
-- sword's modifiers. Price = rarity base x current roll quality (SwordValue.rerollCost), so a
-- bare Rare is a cheap gamble and a well-rolled Legendary costs real gold.
-- Opened from the on-screen menu (no world prompt); usable anywhere.
--
-- The ladder (WeaponModifiers): ten rungs per modifier. Rungs 1-6 are shaped by rarity, rungs
-- 7-10 are a fixed long tail (Sunburst 1 in 500 ... Lemonade 1 in 500,000 per rolled slot) that
-- luck multiplies. Luck is earned in play only: the current kill streak, a Lucky Charge from a
-- boss kill (spent on a paid strike), and rebirths. Every strike tells the player the true
-- 1-in-N of what landed; a Supernova or better (rung 8+) toasts the whole server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SwordValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwordValue"))
local WeaponModifiers = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponModifiers"))
local BossSwordFactory = require(script.Parent:WaitForChild("BossSwordFactory"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local REFORGE = remotes:WaitForChild("ReforgeAction")
local NOTIFY = remotes:WaitForChild("Notify")

local REQUEST_INTERVAL = 0.3
local SAVE_COOLDOWN = 8
-- Pity: after this many reforges in a row that did not raise the rating, the next one guarantees
-- a top modifier at least this rung. Counter persists in the profile (reforgePity).
local PITY_AFTER = 5 -- [TUNING]
local PITY_MIN_TOP_TIER = 4 -- [TUNING]
-- Long-tail pity: after this many strikes without landing a Sunburst (rung 7) or better, the
-- next strike's best modifier is lifted to Sunburst. Persists as reforgeTailPity.
local TAIL_PITY_AFTER = 250 -- [TUNING]
local TAIL_PITY_TIER = 7
-- Broadcast a server-wide toast when a reforge lands this rung or better (Supernova, 1 in 5,000).
local BROADCAST_TIER = WeaponModifiers.BROADCAST_TIER
-- One free reforge every three hours keeps players coming back to the anvil.
local FREE_INTERVAL = 3 * 60 * 60 -- [TUNING] seconds
-- Locking modifiers: price grows per lock by the locked tier (SwordValue.LOCK_TIER_FACTOR).

local lastRequestAt = {}
local lastSaveAt = {}

local function describe(tool, equipped)
	return {
		toolName = tool.Name,
		name = tool.Name,
		rarity = tool:GetAttribute("Rarity") or "Common",
		prefixes = tool:GetAttribute("Prefixes") or "",
		blessed = tool:GetAttribute("ExtraSlot") == true,
		variant = tool:GetAttribute("Variant"),
		tier = tool:GetAttribute("BossTier") or 1,
		rating = SwordValue.rateTool(tool),
		cost = SwordValue.rerollCostForTool(tool),
		equipped = equipped == true,
	}
end

local function goldOf(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Gold")
end

-- The kill streak LevelingSystem keeps on the player (KillStreak / KillStreakAt), if it is
-- still alive: a streak drops once STREAK_WINDOW seconds pass without a kill.
local function liveStreak(player)
	local streak = tonumber(player:GetAttribute("KillStreak")) or 0
	local at = tonumber(player:GetAttribute("KillStreakAt")) or -math.huge
	if os.clock() - at > WeaponModifiers.Luck.STREAK_WINDOW then return 0 end
	return streak
end

local function chargesOf(player)
	return math.clamp(tonumber(player:GetAttribute("ForgeLuckCharges")) or 0, 0, WeaponModifiers.Luck.CHARGE_MAX)
end

-- The luck a strike would use right now. spendCharge: a paid strike spends one Lucky Charge.
local function luckOf(player, spendCharge)
	local streak = liveStreak(player)
	local charges = chargesOf(player)
	local rebirths = tonumber(player:GetAttribute("Rebirths")) or 0
	local total, streakBonus, chargeBonus, rebirthBonus = WeaponModifiers.LuckFrom(streak, spendCharge and charges > 0, rebirths)
	return {
		total = total, streak = streak, streakBonus = streakBonus, charges = charges, chargeBonus = chargeBonus,
		rebirths = rebirths, rebirthBonus = rebirthBonus, spendsCharge = spendCharge and charges > 0,
	}
end

local function sendState(player, highlight)
	local rows = {}
	local equippedTool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true then
					table.insert(rows, describe(tool, tool == equippedTool))
				end
			end
		end
	end
	table.sort(rows, function(a, b) return a.rating > b.rating end)
	local gold = goldOf(player)
	-- Odds disclosure: the exact ladder by rarity at the luck the next paid strike would use, so
	-- the player sees the real 1-in-N of every rung before paying. `tiers` (per-rung probability)
	-- is kept for older clients; `ladder` carries names, 1-in-N and per-strike chances.
	local luck = luckOf(player, true)
	local odds = {}
	for rarity, cfg in pairs(WeaponModifiers.RarityConfig) do
		odds[rarity] = {
			tiers = WeaponModifiers.TierOdds(rarity, 0, luck.total), slots = cfg.baseSlots,
			bonusSlotChance = cfg.bonusSlotChance or 0, ladder = WeaponModifiers.Ladder(rarity, luck.total),
		}
	end
	local rungs = {}
	for tier, rung in ipairs(WeaponModifiers.Rungs) do rungs[tier] = { name = rung.name, color = rung.color } end
	local variants = {}
	for i, v in ipairs(WeaponModifiers.Variants) do variants[i] = { name = v.name, oneIn = v.oneIn, mult = v.mult, color = v.color } end
	local pity = PlayerDataService.GetField(player, "reforgePity") or 0
	local tailPity = PlayerDataService.GetField(player, "reforgeTailPity") or 0
	local freeAt = PlayerDataService.GetField(player, "reforgeFreeAt") or 0
	REFORGE:FireClient(player, "State", rows, gold and gold.Value or 0, highlight, {
		odds = odds, pity = pity, pityAfter = PITY_AFTER, pityTier = PITY_MIN_TOP_TIER,
		tailPity = tailPity, tailPityAfter = TAIL_PITY_AFTER, tailPityTier = TAIL_PITY_TIER,
		blessedChance = WeaponModifiers.EXTRA_SLOT_CHANCE, lockTierFactor = SwordValue.LOCK_TIER_FACTOR,
		freeIn = math.max(0, freeAt - os.time()), best = PlayerDataService.GetField(player, "reforgeBest") or 0,
		count = PlayerDataService.GetField(player, "reforgeCount") or 0,
		luck = luck, rungs = rungs, variants = variants, broadcastTier = BROADCAST_TIER,
		tierCount = WeaponModifiers.TIER_COUNT, bodyTiers = WeaponModifiers.BODY_TIERS,
		luckRules = WeaponModifiers.Luck,
	})
end

local function findRelic(player, toolName)
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if container then
			local tool = container:FindFirstChild(toolName)
			if tool and tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true then
				return tool
			end
		end
	end
	return nil
end

local function reroll(player, toolName, keepNames)
	local tool = findRelic(player, toolName)
	if not tool then
		NOTIFY:FireClient(player, "That sword is not on you.", "error")
		return
	end
	-- Only modifiers actually on the sword can be locked; ignore anything else the client sent.
	local onSword = {}
	for _, mod in ipairs(SwordValue.modifiersFromPrefixes(tool:GetAttribute("Prefixes"))) do
		onSword[mod.name] = true
	end
	local locks = {}
	for _, name in ipairs(keepNames or {}) do
		if typeof(name) == "string" and onSword[name] and not table.find(locks, name) then table.insert(locks, name) end
	end
	local attrs = { Rarity = tool:GetAttribute("Rarity"), Prefixes = tool:GetAttribute("Prefixes"),
		ExtraSlot = tool:GetAttribute("ExtraSlot"), BossTier = tool:GetAttribute("BossTier"), Variant = tool:GetAttribute("Variant") }
	local cost = SwordValue.rerollCostWithLocks(attrs, locks)
	local freeAt = PlayerDataService.GetField(player, "reforgeFreeAt") or 0
	local useFree = #locks == 0 and os.time() >= freeAt
	if useFree then cost = 0 end
	local gold = goldOf(player)
	if not gold or gold.Value < cost then
		NOTIFY:FireClient(player, string.format("Reforging %s costs %d gold.", tool.Name, cost), "error")
		return
	end
	local before = SwordValue.rateTool(tool)
	local oldName = tool.Name
	local pity = PlayerDataService.GetField(player, "reforgePity") or 0
	local tailPity = PlayerDataService.GetField(player, "reforgeTailPity") or 0
	local floor = if pity >= PITY_AFTER then PITY_MIN_TOP_TIER else nil
	if tailPity >= TAIL_PITY_AFTER then floor = math.max(floor or 0, TAIL_PITY_TIER) end
	-- A paid strike spends one Lucky Charge (a boss kill); the free strike keeps them.
	local luck = luckOf(player, not useFree)
	local mods, newName, _, pityApplied, variant = BossSwordFactory.reroll(tool,
		player:GetAttribute("RebirthBlessedBonus") or 0, floor, locks, { luck = luck.total })
	if not mods then
		NOTIFY:FireClient(player, "That sword cannot be reforged.", "error")
		return
	end
	gold.Value -= cost
	if luck.spendsCharge then
		player:SetAttribute("ForgeLuckCharges", math.max(luck.charges - 1, 0))
	end
	if useFree then PlayerDataService.SetField(player, "reforgeFreeAt", os.time() + FREE_INTERVAL) end
	local after = SwordValue.rateTool(tool)
	PlayerDataService.SetField(player, "reforgePity", if after > before then 0 else pity + 1)
	PlayerDataService.SetField(player, "reforgeCount", (PlayerDataService.GetField(player, "reforgeCount") or 0) + 1)
	local best = PlayerDataService.GetField(player, "reforgeBest") or 0
	local personalBest = after > best
	if personalBest then PlayerDataService.SetField(player, "reforgeBest", after) end
	-- What landed: the best rung on the roll, its true 1-in-N per slot, and the chance a whole
	-- strike of this rarity lands that rung or better (what the reveal band prints).
	local topTier, topMod = 0, nil
	for _, mod in ipairs(mods) do
		if mod.tier > topTier then topTier, topMod = mod.tier, mod end
	end
	PlayerDataService.SetField(player, "reforgeTailPity", if topTier >= TAIL_PITY_TIER then 0 else tailPity + 1)
	local rarity = tool:GetAttribute("Rarity") or "Common"
	local ladder = WeaponModifiers.Ladder(rarity, luck.total)
	local top = ladder[topTier]
	local topRung = WeaponModifiers.Rungs[topTier]
	if topTier >= BROADCAST_TIER then
		NOTIFY:FireAllClients(string.format("%s struck %s at the anvil: %s (%s)!", player.DisplayName,
			string.upper(topRung.name), newName, top and top.oneInText or "?"), "success")
	end
	local rolled = {}
	for _, mod in ipairs(mods) do
		table.insert(rolled, { name = mod.name, category = mod.category, tier = mod.tier, desc = mod.desc,
			oneIn = mod.oneIn, oneInText = WeaponModifiers.OneInText(mod.p or 0), rung = WeaponModifiers.Rungs[mod.tier].name,
			kept = mod.kept == true, pity = mod.pity == true })
	end
	-- The client plays the case-opening reel with this, then re-lists the swords.
	REFORGE:FireClient(player, "Result", {
		toolName = newName, oldName = oldName, rarity = rarity,
		mods = rolled, blessed = tool:GetAttribute("ExtraSlot") == true, variant = variant,
		before = before, after = after, cost = cost, pityApplied = pityApplied == true,
		free = useFree, kept = #locks > 0 and table.concat(locks, ", ") or nil, personalBest = personalBest,
		topTier = topTier, topRung = topRung and topRung.name or nil, topName = topMod and topMod.name or nil,
		topOneIn = top and top.oneIn or nil, topOneInText = top and top.oneInText or nil,
		strikeOneInText = top and top.atLeastOneInText or nil, luck = luck,
		broadcast = topTier >= BROADCAST_TIER, broadcastTier = BROADCAST_TIER,
	})
	print(string.format("[ReforgeSystem] %s reforged %s -> %s for %d gold (luck %.2fx, best rung %d %s)",
		player.Name, oldName, newName, cost, luck.total, topTier, top and top.oneInText or "-"))
	PlayerDataService.MarkDirty(player)
	local now = os.clock()
	if now - (lastSaveAt[player] or -math.huge) >= SAVE_COOLDOWN then
		lastSaveAt[player] = now
		task.spawn(PlayerDataService.Save, player)
	end
	sendState(player, newName)
end

REFORGE.OnServerEvent:Connect(function(player, action, arg, keep)
	local now = os.clock()
	if now - (lastRequestAt[player] or -math.huge) < REQUEST_INTERVAL then return end
	lastRequestAt[player] = now
	if player:GetAttribute("DataLoaded") ~= true then return end
	if action == "Open" then
		player:SetAttribute("ReforgeOpen", true) -- in-memory only: luck changes refresh the open panel
		sendState(player)
		REFORGE:FireClient(player, "Open")
	elseif action == "Close" then
		player:SetAttribute("ReforgeOpen", false)
	elseif action == "Reroll" and typeof(arg) == "string" then
		reroll(player, arg, if typeof(keep) == "table" then keep else nil)
	end
end)

-- Luck changes between opens (a streak grows, a charge lands): refresh an open panel's odds.
Players.PlayerAdded:Connect(function(player)
	for _, attr in ipairs({ "KillStreak", "ForgeLuckCharges" }) do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if player:GetAttribute("DataLoaded") == true and player:GetAttribute("ReforgeOpen") == true then
				sendState(player)
			end
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequestAt[player], lastSaveAt[player] = nil, nil
end)

-- Studio-only capture stage (GuiShowcase "Reforge" / "ReforgeOdds", see GuiShowcase.luau): a test
-- player who carries no relic is lent two so the anvil has something to show. Inert outside Studio
-- (RunService:IsStudio() is false on live servers) and only while the showcase attribute names the
-- anvil. Loaners are tagged GuiShowcaseOnly, which PlayerDataService's sword serializer skips, so a
-- save (autosave, or the BindToClose save when Play stops) never writes them into the real profile.
-- The stage also sets a live 20-kill streak (KillStreak / KillStreakAt are in-memory attributes,
-- not in SaveConfig.ATTRIBUTES, so they never persist) so the odds popup shows luck at work.
-- The showcase itself only ever "Open"s the panel: no reroll, no gold, no reforge counters change.
local RunService = game:GetService("RunService")
local showcase = workspace:GetAttribute("GuiShowcase")
if RunService:IsStudio() and (showcase == "Reforge" or showcase == "ReforgeOdds") then
	local function lend(player)
		task.spawn(function()
			local deadline = os.clock() + 30
			while player:GetAttribute("DataLoaded") ~= true and os.clock() < deadline do task.wait(0.25) end
			-- The engine replaces a Backpack filled before the first spawn (see PlayerDataService.Apply),
			-- so wait for the character, then a beat, before lending.
			local _ = player.Character or player.CharacterAdded:Wait()
			task.wait(1)
			player:SetAttribute("KillStreak", 20)
			player:SetAttribute("KillStreakAt", os.clock() + 600) -- stays live for the whole capture
			local backpack = player:FindFirstChildOfClass("Backpack")
			if not backpack then return end
			for _, container in ipairs({ player.Character, backpack }) do
				if container then
					for _, tool in ipairs(container:GetChildren()) do
						if tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true then return end
					end
				end
			end
			for _, key in ipairs({ "Boss_CelestialTitan", "Boss_FrostRevenant" }) do
				local tool = BossSwordFactory.build(key)
				tool:SetAttribute("GuiShowcaseOnly", true)
				tool.Parent = backpack
			end
			print("[ReforgeSystem] GuiShowcase: lent two showcase-only relics (never saved)")
		end)
	end
	Players.PlayerAdded:Connect(lend)
	for _, p in ipairs(Players:GetPlayers()) do lend(p) end
end

print("[ReforgeSystem] Reforge ready (opened from the menu): 10-rung ladder, luck from streaks, charges and rebirths")
