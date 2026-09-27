-- Script | ServerScriptService.TradeSystem | Player-to-player relic sword trading.
-- Flow: Request -> Accept -> both add/remove swords from their offer -> both Confirm -> swap.
-- Any offer change clears both confirmations. The swap serializes each offered Tool with
-- PlayerDataService.SerializeTool, destroys it, and rebuilds it for the other player with
-- BossSwordFactory.rebuild (the same path saves and the vault use), so rolled stats survive.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SwordValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwordValue"))
local WeaponModifiers = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponModifiers"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local BossSwordFactory = require(script.Parent:WaitForChild("BossSwordFactory"))

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local TRADE = remotes:WaitForChild("TradeAction")
local NOTIFY = remotes:WaitForChild("Notify")

local REQUEST_TTL = 45 -- [TUNING] seconds a trade request stays open
local REQUEST_INTERVAL = 0.2
local MAX_OFFER = 6 -- [TUNING] swords per side

local sessions = {} -- [player] = session (both parties point at the same table)
local pending = {} -- [target] = { from = player, at = os.clock() }
local lastRequestAt = {}

-- ── Helpers ──────────────────────────────────────────────────────────────────
-- Offers can hold carried swords (key "c:<tool name>") and vaulted ones ("v:<index>"). Vault
-- offers keep a reference to the entry table, so index shifts from a Vaultkeeper visit mid-trade
-- cannot swap which sword is on the table.
-- ── Offers are pinned to the exact sword ─────────────────────────────────────────────
-- 2026-09-24 playtest (trade-1/2/3, R20): offers were keyed by the sword's NAME, a sword that left
-- the offer was pruned without reopening either side, and Confirm was not tied to what the player
-- saw. Selling, depositing or withdrawing an offered sword, or swapping in a worse same-named copy,
-- after the partner confirmed still completed the trade; a looped toggle beat a human Confirm 21 of
-- 30 times. Now every offer holds the sword itself plus a fingerprint of it, any change to either
-- offer reopens both sides and bumps session.version, and a Confirm must name the version the
-- player was looking at.
local toolIds = setmetatable({}, { __mode = "k" })
local nextToolId = 0
local function idOf(tool)
	local id = toolIds[tool]
	if not id then
		nextToolId += 1
		id = tostring(nextToolId)
		toolIds[tool] = id
	end
	return id
end

local function fingerprint(name, attrs)
	return table.concat({ tostring(name), tostring(attrs.Rarity), tostring(attrs.DamageMult),
		tostring(attrs.Prefixes), tostring(attrs.BaseWeaponName), tostring(attrs.PoolKey) }, "|")
end
local function toolPrint(tool)
	return fingerprint(tool.Name, tool:GetAttributes())
end
local function entryPrint(entry)
	return fingerprint(entry.name, entry.attrs or {})
end

local function describeTool(tool, equipped)
	return {
		key = "c:" .. idOf(tool),
		source = "carried",
		toolName = tool.Name,
		name = tool.Name,
		rarity = tool:GetAttribute("Rarity") or "Common",
		prefixes = tool:GetAttribute("Prefixes") or "",
		rating = SwordValue.rateTool(tool),
		equipped = equipped == true,
	}
end

local function describeEntry(entry, index)
	local attrs = entry.attrs or {}
	return {
		key = "v:" .. tostring(index),
		source = "vault",
		name = entry.name,
		rarity = attrs.Rarity or "Common",
		prefixes = attrs.Prefixes or "",
		rating = SwordValue.rateAttrs(attrs),
		equipped = false,
	}
end

local function vaultedRelics(player)
	local list = {}
	for i, entry in ipairs(PlayerDataService.GetVault(player) or {}) do
		table.insert(list, describeEntry(entry, i))
	end
	return list
end

local function carriedRelics(player)
	local list = {}
	local equippedTool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true and tool:GetAttribute("Starter") ~= true then
					table.insert(list, describeTool(tool, tool == equippedTool))
				end
			end
		end
	end
	return list
end

-- The player still holds this exact sword (on the character or in the Backpack). The starter is
-- never traded away: the player always keeps one blade.
local function owns(player, tool)
	return tool ~= nil and tool.Parent ~= nil
		and (tool.Parent == player.Character or tool.Parent == player:FindFirstChildOfClass("Backpack"))
		and tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true and tool:GetAttribute("Starter") ~= true
end

local function findRelicById(player, id)
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		for _, tool in ipairs(container and container:GetChildren() or {}) do
			if toolIds[tool] == id and owns(player, tool) then
				return tool
			end
		end
	end
	return nil
end

local function alive(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function partnerOf(session, player)
	return if session.a == player then session.b else session.a
end

local function offerRows(session, player)
	local rows = {}
	local vault = PlayerDataService.GetVault(player) or {}
	for key, offer in pairs(session.offers[player]) do
		if offer.kind == "carried" then
			table.insert(rows, describeTool(offer.tool, offer.tool.Parent == player.Character))
		else
			local row = describeEntry(offer.entry, table.find(vault, offer.entry) or 0)
			row.key = key
			table.insert(rows, row)
		end
	end
	table.sort(rows, function(x, y) return x.rating > y.rating end)
	return rows
end

-- Drop every offer whose sword has left the player (sold, stored, withdrawn, traded, destroyed) or
-- changed (a reroll, a prefix change). Any drop reopens BOTH sides and bumps the version, so a
-- partner's earlier Confirm can never carry over onto a smaller or different offer.
local function validate(session)
	local changed = false
	for _, player in ipairs({ session.a, session.b }) do
		local vault = PlayerDataService.GetVault(player) or {}
		for key, offer in pairs(session.offers[player]) do
			local ok
			if offer.kind == "carried" then
				ok = owns(player, offer.tool) and toolPrint(offer.tool) == offer.print
			else
				ok = table.find(vault, offer.entry) ~= nil and entryPrint(offer.entry) == offer.print
			end
			if not ok then
				session.offers[player][key] = nil
				changed = true
			end
		end
	end
	if changed then
		session.confirmed = {}
		session.version += 1
	end
	return changed
end

local function sendSession(session)
	validate(session)
	for _, player in ipairs({ session.a, session.b }) do
		local partner = partnerOf(session, player)
		TRADE:FireClient(player, "Session", {
			partnerName = partner.DisplayName,
			partnerId = partner.UserId,
			mine = offerRows(session, player),
			theirs = offerRows(session, partner),
			carried = carriedRelics(player),
			vaulted = vaultedRelics(player),
			version = session.version,
			myConfirmed = session.confirmed[player] == true,
			theirConfirmed = session.confirmed[partner] == true,
			maxOffer = MAX_OFFER,
		})
	end
end

local function endSession(session, reason)
	for _, player in ipairs({ session.a, session.b }) do
		if sessions[player] == session then
			sessions[player] = nil
			TRADE:FireClient(player, "Ended", reason)
		end
	end
end

local function playerList(player)
	local list = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local stats = other:FindFirstChild("leaderstats")
			local level = stats and stats:FindFirstChild("Level")
			table.insert(list, {
				userId = other.UserId,
				name = other.DisplayName,
				level = level and level.Value or 1,
				wealth = other:GetAttribute("Wealth") or 0,
				busy = sessions[other] ~= nil,
			})
		end
	end
	table.sort(list, function(x, y) return x.wealth > y.wealth end)
	local incoming = pending[player]
	local incomingInfo = nil
	if incoming and os.clock() - incoming.at <= REQUEST_TTL and incoming.from.Parent then
		incomingInfo = { userId = incoming.from.UserId, name = incoming.from.DisplayName }
	else
		pending[player] = nil
	end
	return list, incomingInfo
end

local function sendPlayers(player)
	local list, incoming = playerList(player)
	TRADE:FireClient(player, "Players", list, incoming)
end

-- ── Actions ──────────────────────────────────────────────────────────────────
local function request(player, targetId)
	if sessions[player] then return end
	local target = typeof(targetId) == "number" and Players:GetPlayerByUserId(targetId)
	if not target or target == player then return end
	if sessions[target] then
		NOTIFY:FireClient(player, target.DisplayName .. " is already trading.", "error")
		return
	end
	if #carriedRelics(player) == 0 and #vaultedRelics(player) == 0 then
		NOTIFY:FireClient(player, "You have no relic swords to trade.", "error")
		return
	end
	pending[target] = { from = player, at = os.clock() }
	NOTIFY:FireClient(player, "Trade request sent to " .. target.DisplayName .. ".", "success")
	NOTIFY:FireClient(target, player.DisplayName .. " wants to trade swords. Open Menu > Trade.", "info")
	TRADE:FireClient(target, "Incoming", player.UserId, player.DisplayName)
end

local function accept(player, fromId)
	local incoming = pending[player]
	if not incoming or incoming.from.UserId ~= fromId then return end
	pending[player] = nil
	local from = incoming.from
	if not from.Parent or sessions[from] or sessions[player] then
		NOTIFY:FireClient(player, "That trade is no longer available.", "error")
		return
	end
	if os.clock() - incoming.at > REQUEST_TTL then
		NOTIFY:FireClient(player, "That trade request expired.", "error")
		return
	end
	local session = { a = from, b = player, offers = { [from] = {}, [player] = {} }, confirmed = {}, version = 1 }
	sessions[from], sessions[player] = session, session
	sendSession(session)
end

local function decline(player, fromId)
	local incoming = pending[player]
	if incoming and incoming.from.UserId == fromId then
		pending[player] = nil
		if incoming.from.Parent then
			NOTIFY:FireClient(incoming.from, player.DisplayName .. " declined the trade.", "error")
		end
	end
	sendPlayers(player)
end

local function toggleOffer(player, key)
	local session = sessions[player]
	if not session or typeof(key) ~= "string" then return end
	local offers = session.offers[player]
	if offers[key] then
		offers[key] = nil
	else
		local count = 0
		for _ in pairs(offers) do count += 1 end
		if count >= MAX_OFFER then return end
		local kind, rest = string.match(key, "^(%a):(.+)$")
		if kind == "c" then
			local tool = findRelicById(player, rest)
			if not tool then return end
			offers[key] = { kind = "carried", tool = tool, print = toolPrint(tool) }
		elseif kind == "v" then
			local vault = PlayerDataService.GetVault(player)
			local entry = vault and vault[tonumber(rest) or 0]
			if not entry then return end
			for _, existing in pairs(offers) do -- same entry under an old index key
				if existing.entry == entry then return end
			end
			offers[key] = { kind = "vault", entry = entry, print = entryPrint(entry) }
		else
			return
		end
	end
	session.confirmed = {} -- any change reopens both sides
	session.version += 1
	sendSession(session)
end

local function complete(session)
	local a, b = session.a, session.b
	-- Everything must still be there before anything moves.
	local function collect(player)
		local tools, entries = {}, {}
		local vault = PlayerDataService.GetVault(player) or {}
		for _, offer in pairs(session.offers[player]) do
			if offer.kind == "carried" then
				if not (owns(player, offer.tool) and toolPrint(offer.tool) == offer.print) then return nil end
				table.insert(tools, offer.tool)
			else
				if not (table.find(vault, offer.entry) and entryPrint(offer.entry) == offer.print) then return nil end
				table.insert(entries, offer.entry)
			end
		end
		return tools, entries
	end
	local toolsA, vaultA = collect(a)
	if not toolsA then return false, a.DisplayName .. "'s offer changed." end
	local toolsB, vaultB = collect(b)
	if not toolsB then return false, b.DisplayName .. "'s offer changed." end
	local bagA, bagB = a:FindFirstChildOfClass("Backpack"), b:FindFirstChildOfClass("Backpack")
	if not bagA or not bagB then return false, "A backpack is missing." end
	for _, player in ipairs({ a, b }) do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:UnequipTools() end
	end
	local entriesA, entriesB = {}, {}
	for _, tool in ipairs(toolsA) do table.insert(entriesA, PlayerDataService.SerializeTool(tool, false)); tool:Destroy() end
	for _, tool in ipairs(toolsB) do table.insert(entriesB, PlayerDataService.SerializeTool(tool, false)); tool:Destroy() end
	local vaultTableA, vaultTableB = PlayerDataService.GetVault(a), PlayerDataService.GetVault(b)
	for _, entry in ipairs(vaultA) do
		table.remove(vaultTableA, table.find(vaultTableA, entry))
		table.insert(entriesA, entry)
	end
	for _, entry in ipairs(vaultB) do
		table.remove(vaultTableB, table.find(vaultTableB, entry))
		table.insert(entriesB, entry)
	end
	-- A traded sword wakes up as many of its prefixes as its NEW owner has slots for.
	for _, entry in ipairs(entriesA) do
		local rebuilt = BossSwordFactory.rebuild(entry, WeaponModifiers.SlotsOf(b))
		if rebuilt then rebuilt.Parent = bagB end
	end
	for _, entry in ipairs(entriesB) do
		local rebuilt = BossSwordFactory.rebuild(entry, WeaponModifiers.SlotsOf(a))
		if rebuilt then rebuilt.Parent = bagA end
	end
	NOTIFY:FireClient(a, string.format("Trade complete: gave %d, received %d.", #entriesA, #entriesB), "success")
	NOTIFY:FireClient(b, string.format("Trade complete: gave %d, received %d.", #entriesB, #entriesA), "success")
	task.spawn(PlayerDataService.Save, a)
	task.spawn(PlayerDataService.Save, b)
	return true
end

local function confirm(player, seenVersion)
	local session = sessions[player]
	if not session then return end
	-- The Confirm must be for the offer the player was looking at. validate() first, so a sword
	-- that left an offer since then has already bumped the version.
	validate(session)
	if seenVersion ~= session.version then
		NOTIFY:FireClient(player, "The offer changed. Check it again, then confirm.", "error")
		sendSession(session)
		return
	end
	-- A sword delivered to a dead player went into the Backpack the respawn throws away.
	if not alive(session.a) or not alive(session.b) then
		NOTIFY:FireClient(player, "Both traders need to be alive to trade.", "error")
		return
	end
	session.confirmed[player] = true
	local partner = partnerOf(session, player)
	if session.confirmed[partner] then
		local ok, reason = complete(session)
		if ok then
			endSession(session, "completed")
		else
			session.confirmed = {}
			NOTIFY:FireClient(session.a, reason, "error")
			NOTIFY:FireClient(session.b, reason, "error")
			sendSession(session)
		end
	else
		sendSession(session)
	end
end

local function cancel(player)
	local session = sessions[player]
	if not session then return end
	local partner = partnerOf(session, player)
	NOTIFY:FireClient(partner, player.DisplayName .. " cancelled the trade.", "error")
	endSession(session, "cancelled")
end

TRADE.OnServerEvent:Connect(function(player, action, arg)
	local now = os.clock()
	if now - (lastRequestAt[player] or -math.huge) < REQUEST_INTERVAL then return end
	lastRequestAt[player] = now
	if player:GetAttribute("DataLoaded") ~= true then return end
	if action == "Refresh" then
		if sessions[player] then sendSession(sessions[player]) else sendPlayers(player) end
	elseif action == "Request" then request(player, arg)
	elseif action == "Accept" then accept(player, arg)
	elseif action == "Decline" then decline(player, arg)
	elseif action == "Offer" then toggleOffer(player, arg)
	elseif action == "Confirm" then confirm(player, arg)
	elseif action == "Cancel" then cancel(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	if session then
		local partner = partnerOf(session, player)
		if partner.Parent then NOTIFY:FireClient(partner, player.DisplayName .. " left; trade cancelled.", "error") end
		endSession(session, "left")
	end
	pending[player] = nil
	lastRequestAt[player] = nil
	for target, info in pairs(pending) do
		if info.from == player then pending[target] = nil end
	end
end)

print("[TradeSystem] Sword trading ready")
