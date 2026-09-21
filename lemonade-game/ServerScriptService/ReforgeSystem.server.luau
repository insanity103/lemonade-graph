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
-- How many past forges the anvil remembers for the run rail: the top rung of each, oldest
-- first, persisted as reforgeRecent so a player who comes back still sees what the last
-- session's strikes were worth.
local RECENT_MAX = 12 -- [TUNING]
-- Broadcast a server-wide toast when a reforge lands this rung or better (Supernova, 1 in 5,000).
local BROADCAST_TIER = WeaponModifiers.BROADCAST_TIER
-- One free reforge every three hours keeps players coming back to the anvil.
local FREE_INTERVAL = 3 * 60 * 60 -- [TUNING] seconds
-- ...and the wealth ladder takes time off that wait: rungs 2, 4, 6 and 8 are worth 15 minutes
-- each (Config.WealthLadder), so the richest player waits 2 h instead of 3 h. Convenience, not
-- power: the free strike rolls at the same odds it always did. Floored at a third of the
-- interval so no ladder can ever make it free.
local function freeIntervalFor(player): number
	local cut = math.max(0, tonumber(player:GetAttribute("MilestoneFreeStrike")) or 0)
	return math.max(FREE_INTERVAL / 3, FREE_INTERVAL - cut)
end
-- Locking modifiers: price grows per lock by the locked tier (SwordValue.LOCK_TIER_FACTOR).

-- Studio capture only ("Motion:ForgeRare", the stage at the foot of this file). The top rung is
-- 1 in 500,000 per slot, so waiting for a real one is not filming. The stage arms this once and
-- the very next strike forces its FIRST rolled slot to that rung through
-- WeaponModifiers.ForceNextTier; it then disarms itself, so exactly one roll is touched.
-- Everything else about that roll is the live path: the gold, the earned luck, the blow's
-- multiplier, how many slots the rarity gives, which categories they land in, what the other
-- slots roll, the mutation, the pity counters, the remotes and the server-wide broadcast. It is
-- only ever armed inside a RunService:IsStudio() block while the showcase attribute names that
-- stage, so a live server can never reach it.
local showcaseForceTopTier: number? = nil

-- ── The forge strike ────────────────────────────────────────────────────────
-- Paying no longer rolls straight away: it lights a timing meter at the anvil. A marker sweeps
-- a bar, the player times a hammer blow, and the quality of that blow multiplies the luck the
-- roll uses (PERFECT 2x, GOOD 1.5x, OK 1x).
--
-- The server owns the meter. It picks the sweet zone and the moment the marker starts, sends
-- that plan to the client, and when the client reports the instant it pressed, recomputes the
-- marker position from its OWN clock and its OWN plan -- the client's quality word is never
-- trusted, only a timestamp, and even that is clamped into a window no wider than the slack
-- this player's measured ping already costs them. A forged timestamp can move the marker by no
-- more than honest lag would.
--
-- There IS a way to fail. Most of the bar is a MISS: the blow glances off, the roll still
-- happens, but at plain base luck with the gold already spent -- so a lazy tap costs a whole
-- reforge's price and buys nothing. MISS is the floor and the floor is exactly base luck: a
-- blow can never roll a player BELOW the luck they earned in play, and it is never a guarantee
-- either -- luck multiplies the long tail of the ladder (WeaponModifiers), it does not hand out
-- rungs. Every band and its price is printed on the meter before the marker moves.
local STRIKE_SWEEP = 1.15         -- [TUNING] seconds for the marker to cross the bar once
local STRIKE_LEAD = 0.25          -- [TUNING] wind-up seconds before the marker starts moving
-- The four bands, as +/- of the bar around the sweet centre. PERFECT is a genuinely tight slice
-- (11% of the bar) but still 127 ms of marker travel, which is over 7 frames at 60 fps and a
-- comfortable tap on a phone. Everything past STRIKE_OK_HALF -- 55% of the bar -- is a MISS.
local STRIKE_SWEET_HALF = 0.055   -- [TUNING] PERFECT: 11.0% of the bar = 127 ms of travel
local STRIKE_GOOD_HALF = 0.125    -- [TUNING] GOOD: a 7.0% shoulder = 81 ms either side of that
local STRIKE_OK_HALF = 0.225      -- [TUNING] OK: a 10.0% shoulder = 115 ms either side of that
local STRIKE_CENTER_MIN = 0.33    -- [TUNING] the sweet centre never sits closer than this to an
local STRIKE_CENTER_SPAN = 0.34   -- [TUNING] end, so both MISS tails are always >= 121 ms wide
local STRIKE_WINDOW = 6.0         -- [TUNING] seconds of meter before the blow misses on its own
local STRIKE_SLACK_MAX = 0.35     -- [TUNING] the most clock slack a reported press may ever claim
-- [TUNING] luck multiplier by blow. MISS = 1.0 is base luck exactly: the floor, never a penalty.
local STRIKE_MULT = { MISS = 1.0, OK = 1.15, GOOD = 1.5, PERFECT = 2.0 }
local STRIKE_ORDER = { "MISS", "OK", "GOOD", "PERFECT" }

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
		-- The sword's rolled base damage multiplier. The forge prices a strike on it (SwordValue's
		-- power factor), so the panel has to be told it or its preview would quote the wrong price.
		baseMult = tonumber(tool:GetAttribute("DamageMult")) or 1,
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
	local milestoneLuck = tonumber(player:GetAttribute("MilestoneLuck")) or 0
	local total, streakBonus, chargeBonus, rebirthBonus, milestoneBonus =
		WeaponModifiers.LuckFrom(streak, spendCharge and charges > 0, rebirths, milestoneLuck)
	return {
		total = total, streak = streak, streakBonus = streakBonus, charges = charges, chargeBonus = chargeBonus,
		rebirths = rebirths, rebirthBonus = rebirthBonus, spendsCharge = spendCharge and charges > 0,
		milestoneBonus = milestoneBonus, rung = tonumber(player:GetAttribute("WealthRung")) or 0,
		title = player:GetAttribute("WealthTitle") or "",
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
	local recent = PlayerDataService.GetField(player, "reforgeRecent")
	if typeof(recent) ~= "table" then recent = {} end
	REFORGE:FireClient(player, "State", rows, gold and gold.Value or 0, highlight, {
		recent = recent, recentMax = RECENT_MAX,
		odds = odds, pity = pity, pityAfter = PITY_AFTER, pityTier = PITY_MIN_TOP_TIER,
		tailPity = tailPity, tailPityAfter = TAIL_PITY_AFTER, tailPityTier = TAIL_PITY_TIER,
		blessedChance = WeaponModifiers.EXTRA_SLOT_CHANCE, lockTierFactor = SwordValue.LOCK_TIER_FACTOR,
		freeIn = math.max(0, freeAt - os.time()), best = PlayerDataService.GetField(player, "reforgeBest") or 0,
		count = PlayerDataService.GetField(player, "reforgeCount") or 0,
		luck = luck, rungs = rungs, variants = variants, broadcastTier = BROADCAST_TIER,
		tierCount = WeaponModifiers.TIER_COUNT, bodyTiers = WeaponModifiers.BODY_TIERS,
		luckRules = WeaponModifiers.Luck,
		strike = { sweep = STRIKE_SWEEP, lead = STRIKE_LEAD, sweetHalf = STRIKE_SWEET_HALF,
			goodHalf = STRIKE_GOOD_HALF, okHalf = STRIKE_OK_HALF, window = STRIKE_WINDOW,
			mult = STRIKE_MULT, order = STRIKE_ORDER },
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

local pendingStrike = {} -- player -> the armed plan; exactly one meter is live at a time
local strikeSeq = 0

-- Where the marker sits (0..1 along the bar) at server time `t`. The plan is all it takes, so
-- the server can answer this for any instant without having watched the meter run.
local function markerAt(plan, t: number): number
	local elapsed = math.max(t - plan.startAt - plan.lead, 0)
	local phase = (elapsed % (2 * plan.sweep)) / plan.sweep
	return if phase <= 1 then phase else 2 - phase
end

local function strikeQuality(plan, pos: number): string
	local d = math.abs(pos - plan.sweetCenter)
	if d <= plan.sweetHalf then return "PERFECT" end
	if d <= plan.goodHalf then return "GOOD" end
	if d <= plan.okHalf then return "OK" end
	return "MISS"
end

-- The roll itself, once the blow has landed (or the meter ran out). The plan was paid for when
-- the meter was armed, so nothing here can fail for gold; if the sword has left the player
-- since, the gold goes back.
local function finishStrike(player, plan, quality: string, pos: number, timedOut: boolean?)
	local mult = STRIKE_MULT[quality] or 1
	local luck = plan.luck
	local effective = luck.total * mult
	local strike = {
		seq = plan.seq, quality = quality, mult = mult, pos = pos, sweetCenter = plan.sweetCenter,
		sweetHalf = plan.sweetHalf, goodHalf = plan.goodHalf, okHalf = plan.okHalf,
		timedOut = timedOut == true, cost = plan.cost, free = plan.free,
		baseLuck = luck.total, luck = effective,
	}
	-- Say so at once: the hammer lands, the sparks fly and PERFECT/GOOD/OK stamps while the roll
	-- is still being made. The reel waits for the impact to finish before it spins.
	REFORGE:FireClient(player, "Struck", strike)

	local function refund(message: string)
		local gold = goldOf(player)
		if gold and plan.cost > 0 then gold.Value += plan.cost end
		NOTIFY:FireClient(player, message, "error")
		sendState(player)
	end
	local tool = findRelic(player, plan.toolName)
	if not tool then
		refund("That sword left your hands, so the gold is back.")
		return
	end
	-- Re-check the locks against the sword as it stands now, not as it stood when we armed.
	local onSword = {}
	for _, mod in ipairs(SwordValue.modifiersFromPrefixes(tool:GetAttribute("Prefixes"))) do
		onSword[mod.name] = true
	end
	local locks = {}
	for _, name in ipairs(plan.locks) do
		if onSword[name] then table.insert(locks, name) end
	end

	local before = SwordValue.rateTool(tool)
	local oldName = tool.Name
	local pity = PlayerDataService.GetField(player, "reforgePity") or 0
	local tailPity = PlayerDataService.GetField(player, "reforgeTailPity") or 0
	local floor = if pity >= PITY_AFTER then PITY_MIN_TOP_TIER else nil
	if tailPity >= TAIL_PITY_AFTER then floor = math.max(floor or 0, TAIL_PITY_TIER) end
	-- The blow's multiplier rides on the earned luck: this is the only number the strike changes.
	if showcaseForceTopTier then
		WeaponModifiers.ForceNextTier = showcaseForceTopTier
		showcaseForceTopTier = nil
		print(string.format("[ReforgeSystem] GuiShowcase: forcing this one roll's first slot to rung %d (Studio capture only)",
			WeaponModifiers.ForceNextTier))
	end
	local mods, newName, _, pityApplied, variant = BossSwordFactory.reroll(tool,
		player:GetAttribute("RebirthBlessedBonus") or 0, floor, locks, { luck = effective })
	if not mods then
		refund("That sword cannot be reforged.")
		return
	end
	local after = SwordValue.rateTool(tool)
	PlayerDataService.SetField(player, "reforgePity", if after > before then 0 else pity + 1)
	PlayerDataService.SetField(player, "reforgeCount", (PlayerDataService.GetField(player, "reforgeCount") or 0) + 1)
	local best = PlayerDataService.GetField(player, "reforgeBest") or 0
	local personalBest = after > best
	if personalBest then PlayerDataService.SetField(player, "reforgeBest", after) end
	-- What landed: the best rung on the roll, its true 1-in-N per slot at the luck this blow
	-- actually bought, and the chance a whole strike lands that rung or better.
	local topTier, topMod = 0, nil
	for _, mod in ipairs(mods) do
		if mod.tier > topTier then topTier, topMod = mod.tier, mod end
	end
	PlayerDataService.SetField(player, "reforgeTailPity", if topTier >= TAIL_PITY_TIER then 0 else tailPity + 1)
	-- The rung this strike was worth, kept for the run rail. Oldest first, capped at RECENT_MAX.
	local recent = PlayerDataService.GetField(player, "reforgeRecent")
	if typeof(recent) ~= "table" then recent = {} end
	table.insert(recent, math.max(topTier, 1))
	while #recent > RECENT_MAX do table.remove(recent, 1) end
	PlayerDataService.SetField(player, "reforgeRecent", recent)
	local rarity = tool:GetAttribute("Rarity") or "Common"
	local ladder = WeaponModifiers.Ladder(rarity, effective)
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
		before = before, after = after, cost = plan.cost, pityApplied = pityApplied == true,
		free = plan.free, kept = #locks > 0 and table.concat(locks, ", ") or nil, personalBest = personalBest,
		topTier = topTier, topRung = topRung and topRung.name or nil, topName = topMod and topMod.name or nil,
		topOneIn = top and top.oneIn or nil, topOneInText = top and top.oneInText or nil,
		strikeOneInText = top and top.atLeastOneInText or nil, luck = luck, strike = strike,
		broadcast = topTier >= BROADCAST_TIER, broadcastTier = BROADCAST_TIER,
	})
	print(string.format("[ReforgeSystem] %s struck %s -> %s for %d gold (%s x%.1f, luck %.2f -> %.2f, best rung %d %s)",
		player.Name, oldName, newName, plan.cost, quality, mult, luck.total, effective, topTier, top and top.oneInText or "-"))
	PlayerDataService.MarkDirty(player)
	local now = os.clock()
	if now - (lastSaveAt[player] or -math.huge) >= SAVE_COOLDOWN then
		lastSaveAt[player] = now
		task.spawn(PlayerDataService.Save, player)
	end
	sendState(player, newName)
end

-- Pay, then light the meter. `instant` (the legacy "Reroll" action, still answered for any older
-- client) skips the meter and resolves at OK, which is base luck -- never a penalty.
local function beginStrike(player, toolName, keepNames, instant: boolean?)
	if pendingStrike[player] then return end -- one meter at a time
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
	local attrs = SwordValue.attrsOfTool(tool)
	local cost = SwordValue.rerollCostWithLocks(attrs, locks)
	local freeAt = PlayerDataService.GetField(player, "reforgeFreeAt") or 0
	local useFree = #locks == 0 and os.time() >= freeAt
	if useFree then cost = 0 end
	local gold = goldOf(player)
	if not gold or gold.Value < cost then
		NOTIFY:FireClient(player, string.format("Reforging %s costs %d gold.", tool.Name, cost), "error")
		return
	end
	local luck = luckOf(player, not useFree)
	-- Paid up front: the strike happens after paying, and someone who walks away from a lit meter
	-- still gets the roll they paid for when it runs out.
	gold.Value -= cost
	if luck.spendsCharge then
		player:SetAttribute("ForgeLuckCharges", math.max(luck.charges - 1, 0))
	end
	if useFree then PlayerDataService.SetField(player, "reforgeFreeAt", os.time() + freeIntervalFor(player)) end

	strikeSeq += 1
	local plan = {
		seq = strikeSeq, toolName = tool.Name, locks = locks, cost = cost, free = useFree, luck = luck,
		rarity = tool:GetAttribute("Rarity") or "Common",
		startAt = workspace:GetServerTimeNow(), lead = STRIKE_LEAD, sweep = STRIKE_SWEEP,
		sweetHalf = STRIKE_SWEET_HALF, goodHalf = STRIKE_GOOD_HALF, okHalf = STRIKE_OK_HALF,
		-- The sweet zone moves every strike, so the meter has to be read rather than memorised.
		-- It stays clear of the ends so a MISS tail always survives on BOTH sides of the bar.
		sweetCenter = STRIKE_CENTER_MIN + math.random() * STRIKE_CENTER_SPAN,
	}
	if instant then
		-- Legacy "Reroll" (an older client with no meter): resolve at MISS, which is exactly the
		-- base luck that client always had. It is never worse off than before the meter existed.
		finishStrike(player, plan, "MISS", markerAt(plan, plan.startAt), false)
		return
	end
	pendingStrike[player] = plan
	sendState(player) -- the gold is already spent: show it before the meter lights
	REFORGE:FireClient(player, "Armed", {
		seq = plan.seq, startAt = plan.startAt, lead = plan.lead, sweep = plan.sweep,
		sweetCenter = plan.sweetCenter, sweetHalf = plan.sweetHalf, goodHalf = plan.goodHalf,
		okHalf = plan.okHalf, window = STRIKE_WINDOW, mult = STRIKE_MULT, order = STRIKE_ORDER,
		toolName = plan.toolName, rarity = plan.rarity, cost = cost, free = useFree, luck = luck,
	})
	-- Nobody swings: the heat fades, the blow misses and the roll happens anyway, at base luck.
	task.delay(plan.lead + STRIKE_WINDOW + STRIKE_SLACK_MAX + 0.2, function()
		if pendingStrike[player] ~= plan then return end
		pendingStrike[player] = nil
		finishStrike(player, plan, "MISS", markerAt(plan, workspace:GetServerTimeNow()), true)
	end)
end

-- The client reports the instant it pressed, on the shared clock (workspace:GetServerTimeNow).
-- The server checks that against its own clock and its own plan: a stale, early, late or absurd
-- timestamp is clamped, never trusted, and the slack it may claim is the slack this player's
-- measured ping already costs them.
local function reportStrike(player, seq, pressTime)
	local plan = pendingStrike[player]
	if not plan or plan.seq ~= seq then return end
	local now = workspace:GetServerTimeNow()
	local slack = math.clamp(player:GetNetworkPing() * 2 + 0.08, 0.08, STRIKE_SLACK_MAX)
	local claimed = now
	if typeof(pressTime) == "number" and pressTime == pressTime and math.abs(pressTime) ~= math.huge then
		claimed = pressTime
	end
	local t = math.clamp(claimed, now - slack, now)
	t = math.clamp(t, plan.startAt + plan.lead, plan.startAt + plan.lead + STRIKE_WINDOW)
	pendingStrike[player] = nil
	local pos = markerAt(plan, t)
	finishStrike(player, plan, strikeQuality(plan, pos), pos, false)
end

REFORGE.OnServerEvent:Connect(function(player, action, arg, keep)
	if player:GetAttribute("DataLoaded") ~= true then return end
	-- The strike report is gated by the armed plan itself (one shot, then the plan is gone), not
	-- by the request clock: a meter timed in tenths must not be swallowed by the open/close limit.
	if action == "Strike" then
		if pendingStrike[player] then reportStrike(player, arg, keep) end
		return
	end
	local now = os.clock()
	if now - (lastRequestAt[player] or -math.huge) < REQUEST_INTERVAL then return end
	lastRequestAt[player] = now
	if action == "Open" then
		player:SetAttribute("ReforgeOpen", true) -- in-memory only: luck changes refresh the open panel
		sendState(player)
		REFORGE:FireClient(player, "Open")
	elseif action == "Close" then
		player:SetAttribute("ReforgeOpen", false)
	elseif action == "Arm" and typeof(arg) == "string" then
		beginStrike(player, arg, if typeof(keep) == "table" then keep else nil, false)
	elseif action == "Reroll" and typeof(arg) == "string" then
		-- Legacy path (older clients): pay and resolve straight away, at base luck.
		beginStrike(player, arg, if typeof(keep) == "table" then keep else nil, true)
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
	lastRequestAt[player], lastSaveAt[player], pendingStrike[player] = nil, nil, nil
end)

-- Studio-only capture stage (GuiShowcase "Reforge" / "ReforgeOdds", see GuiShowcase.luau): a test
-- player who carries no relic is lent two so the anvil has something to show. Inert outside Studio
-- (RunService:IsStudio() is false on live servers) and only while the showcase attribute names the
-- anvil. Loaners are tagged GuiShowcaseOnly, which PlayerDataService's sword serializer skips, so a
-- save (autosave, or the BindToClose save when Play stops) never writes them into the real profile.
-- The stage also sets a live 20-kill streak (KillStreak / KillStreakAt are in-memory attributes,
-- not in SaveConfig.ATTRIBUTES, so they never persist) so the odds popup shows luck at work.
-- The panel stages only ever "Open" the panel: no reroll, no gold, no reforge counters change.
-- "Motion:ForgeStrike", "Motion:ForgeReveal", "Motion:ForgeRare" and "Motion:ForgeLoop" are the
-- stages that strike for real, so they also top the test player's gold up to STAGE_GOLD --
-- otherwise the strike is refused for being unaffordable. ("Motion:ForgeReveal" films what comes
-- after the blow, and "Motion:ForgeLoop" films several whole forges in a row, so both need the
-- same Legendary loaner and the same gold to get there.) Nothing here
-- can reach the real profile: PlayerDataService.Save refuses outright while the showcase
-- attribute is set in Studio, so the gold, the loaners and the reforge counters die with the
-- session.
local RunService = game:GetService("RunService")
local showcase = workspace:GetAttribute("GuiShowcase")
local STAGE_GOLD = 500000 -- [TUNING] Studio-only: covers a locked Legendary strike
local SHOWCASE_TARGETS = { Reforge = true, ReforgeOdds = true, ["Motion:ForgeStrike"] = true, ["Motion:ForgeReveal"] = true, ["Motion:ForgeRare"] = true, ["Motion:ForgeLoop"] = true }
if RunService:IsStudio() and SHOWCASE_TARGETS[showcase] then
	local strikes = showcase == "Motion:ForgeStrike" or showcase == "Motion:ForgeReveal"
		or showcase == "Motion:ForgeRare" or showcase == "Motion:ForgeLoop"
	if showcase == "Motion:ForgeRare" then
		-- The rare moment is the one the whole server is told about, so the capture needs a roll
		-- that reaches the top of the ladder. Armed here, consumed by the next strike, Studio only.
		showcaseForceTopTier = WeaponModifiers.TIER_COUNT
	end
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
			if strikes then
				local gold = goldOf(player)
				if gold and gold.Value < STAGE_GOLD then
					gold.Value = STAGE_GOLD
					print("[ReforgeSystem] GuiShowcase: granted test gold for the strike (never saved)")
				end
			end
			local backpack = player:FindFirstChildOfClass("Backpack")
			if not backpack then return end
			-- The strike capture always gets its loaners: the anvil has to be filmed with a relic
			-- worth striking, not with whatever junk sword this Studio profile happens to carry.
			if not strikes then
				for _, container in ipairs({ player.Character, backpack }) do
					if container then
						for _, tool in ipairs(container:GetChildren()) do
							if tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true then return end
						end
					end
				end
			end
			-- A boss drop rolls its own rarity (BossSwordFactory.rollDrop), so a loaner is usually a
			-- Common with no modifiers to re-roll. The strike capture re-rolls the loan until the
			-- wanted rarity comes up: Studio-only staging of what is on the anvil, not of the
			-- strike itself, which still uses the live RNG.
			local function lendRelic(key, wantRarity)
				local tool = BossSwordFactory.build(key)
				if wantRarity then
					for _ = 1, 500 do
						if tool:GetAttribute("Rarity") == wantRarity then break end
						tool:Destroy()
						tool = BossSwordFactory.build(key)
					end
				end
				tool:SetAttribute("GuiShowcaseOnly", true)
				tool.Parent = backpack
				return tool
			end
			local titan = lendRelic("Boss_CelestialTitan", if strikes then "Legendary" else nil)
			lendRelic("Boss_FrostRevenant", nil)
			print(string.format("[ReforgeSystem] GuiShowcase: lent two showcase-only relics (never saved); anvil relic %s (%s, rating %d)",
				titan.Name, tostring(titan:GetAttribute("Rarity")), SwordValue.rateTool(titan)))
		end)
	end
	Players.PlayerAdded:Connect(lend)
	for _, p in ipairs(Players:GetPlayers()) do lend(p) end
end

print(string.format("[ReforgeSystem] Reforge ready: 10-rung ladder, luck from streaks, charges and rebirths, and a server-timed forge strike (PERFECT %.0f ms x%.1f / GOOD %.0f ms x%.1f / OK %.0f ms x%.1f / MISS %.0f%% of the bar x%.1f, gold spent)",
	2 * STRIKE_SWEET_HALF * STRIKE_SWEEP * 1000, STRIKE_MULT.PERFECT,
	(STRIKE_GOOD_HALF - STRIKE_SWEET_HALF) * STRIKE_SWEEP * 1000, STRIKE_MULT.GOOD,
	(STRIKE_OK_HALF - STRIKE_GOOD_HALF) * STRIKE_SWEEP * 1000, STRIKE_MULT.OK,
	(1 - 2 * STRIKE_OK_HALF) * 100, STRIKE_MULT.MISS))
