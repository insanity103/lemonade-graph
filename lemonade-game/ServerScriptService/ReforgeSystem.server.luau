-- Script | ServerScriptService.ReforgeSystem | The Reforge anvil: pay gold to re-roll a relic
-- sword's modifiers. Price = rarity base x current roll quality (SwordValue.rerollCost), so a
-- bare Rare is a cheap gamble and a well-rolled Legendary costs real gold.
-- Opened from the on-screen menu (no world prompt); usable anywhere.
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
-- a top modifier at least this tier. Counter persists in the profile (reforgePity).
local PITY_AFTER = 5 -- [TUNING]
local PITY_MIN_TOP_TIER = 4 -- [TUNING]
-- Broadcast a server-wide toast when a reforge lands the top tier.
local BROADCAST_TIER = 6
-- One free reforge per day keeps players coming back to the anvil.
local FREE_INTERVAL = 24 * 60 * 60 -- [TUNING] seconds
-- Locking one modifier (it survives the reroll) costs this many times the normal price.
local LOCK_MULTIPLIER = 2.5 -- [TUNING]

local lastRequestAt = {}
local lastSaveAt = {}

local function describe(tool, equipped)
	return {
		toolName = tool.Name,
		name = tool.Name,
		rarity = tool:GetAttribute("Rarity") or "Common",
		prefixes = tool:GetAttribute("Prefixes") or "",
		blessed = tool:GetAttribute("ExtraSlot") == true,
		rating = SwordValue.rateTool(tool),
		cost = SwordValue.rerollCostForTool(tool),
		equipped = equipped == true,
	}
end

local function goldOf(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Gold")
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
	-- Odds disclosure: exact per-tier chances by rarity, so the player sees them before paying.
	local odds = {}
	for rarity in pairs(WeaponModifiers.RarityConfig) do
		odds[rarity] = { tiers = WeaponModifiers.TierOdds(rarity, 0), slots = WeaponModifiers.RarityConfig[rarity].baseSlots,
			bonusSlotChance = WeaponModifiers.RarityConfig[rarity].bonusSlotChance or 0 }
	end
	local pity = PlayerDataService.GetField(player, "reforgePity") or 0
	local freeAt = PlayerDataService.GetField(player, "reforgeFreeAt") or 0
	REFORGE:FireClient(player, "State", rows, gold and gold.Value or 0, highlight, {
		odds = odds, pity = pity, pityAfter = PITY_AFTER, pityTier = PITY_MIN_TOP_TIER,
		blessedChance = WeaponModifiers.EXTRA_SLOT_CHANCE, lockMultiplier = LOCK_MULTIPLIER,
		freeIn = math.max(0, freeAt - os.time()), best = PlayerDataService.GetField(player, "reforgeBest") or 0,
		count = PlayerDataService.GetField(player, "reforgeCount") or 0,
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

local function reroll(player, toolName, keepName)
	local tool = findRelic(player, toolName)
	if not tool then
		NOTIFY:FireClient(player, "That sword is not on you.", "error")
		return
	end
	if keepName ~= nil then
		local onSword = false
		for _, mod in ipairs(SwordValue.modifiersFromPrefixes(tool:GetAttribute("Prefixes"))) do
			if mod.name == keepName then onSword = true end
		end
		if not onSword then keepName = nil end
	end
	local cost = SwordValue.rerollCostForTool(tool)
	if keepName then cost = math.floor(cost * LOCK_MULTIPLIER / 10 + 0.5) * 10 end
	local freeAt = PlayerDataService.GetField(player, "reforgeFreeAt") or 0
	local useFree = keepName == nil and os.time() >= freeAt
	if useFree then cost = 0 end
	local gold = goldOf(player)
	if not gold or gold.Value < cost then
		NOTIFY:FireClient(player, string.format("Reforging %s costs %d gold.", tool.Name, cost), "error")
		return
	end
	local before = SwordValue.rateTool(tool)
	local oldName = tool.Name
	local pity = PlayerDataService.GetField(player, "reforgePity") or 0
	local floor = if pity >= PITY_AFTER then PITY_MIN_TOP_TIER else nil
	local mods, newName, _, pityApplied = BossSwordFactory.reroll(tool, player:GetAttribute("RebirthBlessedBonus") or 0, floor, keepName)
	if not mods then
		NOTIFY:FireClient(player, "That sword cannot be reforged.", "error")
		return
	end
	gold.Value -= cost
	if useFree then PlayerDataService.SetField(player, "reforgeFreeAt", os.time() + FREE_INTERVAL) end
	local after = SwordValue.rateTool(tool)
	PlayerDataService.SetField(player, "reforgePity", if after > before then 0 else pity + 1)
	PlayerDataService.SetField(player, "reforgeCount", (PlayerDataService.GetField(player, "reforgeCount") or 0) + 1)
	local best = PlayerDataService.GetField(player, "reforgeBest") or 0
	local personalBest = after > best
	if personalBest then PlayerDataService.SetField(player, "reforgeBest", after) end
	local topTier = 0
	for _, mod in ipairs(mods) do topTier = math.max(topTier, mod.tier) end
	if topTier >= BROADCAST_TIER then
		NOTIFY:FireAllClients(string.format("%s reforged a %s!", player.DisplayName, newName), "success")
	end
	local rolled = {}
	for _, mod in ipairs(mods) do
		table.insert(rolled, { name = mod.name, category = mod.category, tier = mod.tier, desc = mod.desc })
	end
	-- The client plays the case-opening reel with this, then re-lists the swords.
	REFORGE:FireClient(player, "Result", {
		toolName = newName, oldName = oldName, rarity = tool:GetAttribute("Rarity") or "Common",
		mods = rolled, blessed = tool:GetAttribute("ExtraSlot") == true,
		before = before, after = after, cost = cost, pityApplied = pityApplied == true,
		free = useFree, kept = keepName, personalBest = personalBest,
	})
	print(string.format("[ReforgeSystem] %s reforged %s -> %s for %d gold", player.Name, oldName, newName, cost))
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
		sendState(player)
		REFORGE:FireClient(player, "Open")
	elseif action == "Reroll" and typeof(arg) == "string" then
		reroll(player, arg, if typeof(keep) == "string" then keep else nil)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequestAt[player], lastSaveAt[player] = nil, nil
end)

print("[ReforgeSystem] Reforge ready (opened from the menu)")
