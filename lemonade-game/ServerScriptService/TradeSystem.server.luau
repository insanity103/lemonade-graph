-- Script | ServerScriptService.TradeSystem | Player-to-player relic sword trading.
-- Flow: Request -> Accept -> both add/remove swords from their offer -> both Confirm -> swap.
-- Any offer change clears both confirmations. The swap serializes each offered Tool with
-- PlayerDataService.SerializeTool, destroys it, and rebuilds it for the other player with
-- BossSwordFactory.rebuild (the same path saves and the vault use), so rolled stats survive.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SwordValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwordValue"))
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
local function describeTool(tool, equipped)
	return {
		key = "c:" .. tool.Name,
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
				if tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true then
					table.insert(list, describeTool(tool, tool == equippedTool))
				end
			end
		end
	end
	return list
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

local function partnerOf(session, player)
	return if session.a == player then session.b else session.a
end

local function offerRows(session, player)
	local rows = {}
	local vault = PlayerDataService.GetVault(player) or {}
	for key, offer in pairs(session.offers[player]) do
		if offer.kind == "carried" then
			local tool = findRelic(player, offer.toolName)
			if tool then
				table.insert(rows, describeTool(tool, tool.Parent == player.Character))
			else
				session.offers[player][key] = nil -- sold or lost meanwhile
			end
		else
			local index = table.find(vault, offer.entry)
			if index then
				local row = describeEntry(offer.entry, index)
				row.key = key
				table.insert(rows, row)
			else
				session.offers[player][key] = nil -- withdrawn meanwhile
			end
		end
	end
	table.sort(rows, function(x, y) return x.rating > y.rating end)
	return rows
end

local function sendSession(session)
	for _, player in ipairs({ session.a, session.b }) do
		local partner = partnerOf(session, player)
		TRADE:FireClient(player, "Session", {
			partnerName = partner.DisplayName,
			partnerId = partner.UserId,
			mine = offerRows(session, player),
			theirs = offerRows(session, partner),
			carried = carriedRelics(player),
			vaulted = vaultedRelics(player),
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
	local session = { a = from, b = player, offers = { [from] = {}, [player] = {} }, confirmed = {} }
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
			if not findRelic(player, rest) then return end
			offers[key] = { kind = "carried", toolName = rest }
		elseif kind == "v" then
			local vault = PlayerDataService.GetVault(player)
			local entry = vault and vault[tonumber(rest) or 0]
			if not entry then return end
			for _, existing in pairs(offers) do -- same entry under an old index key
				if existing.entry == entry then return end
			end
			offers[key] = { kind = "vault", entry = entry }
		else
			return
		end
	end
	session.confirmed = {} -- any change reopens both sides
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
				local tool = findRelic(player, offer.toolName)
				if not tool then return nil end
				table.insert(tools, tool)
			else
				if not table.find(vault, offer.entry) then return nil end
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
	for _, entry in ipairs(entriesA) do
		local rebuilt = BossSwordFactory.rebuild(entry)
		if rebuilt then rebuilt.Parent = bagB end
	end
	for _, entry in ipairs(entriesB) do
		local rebuilt = BossSwordFactory.rebuild(entry)
		if rebuilt then rebuilt.Parent = bagA end
	end
	NOTIFY:FireClient(a, string.format("Trade complete: gave %d, received %d.", #entriesA, #entriesB), "success")
	NOTIFY:FireClient(b, string.format("Trade complete: gave %d, received %d.", #entriesB, #entriesA), "success")
	task.spawn(PlayerDataService.Save, a)
	task.spawn(PlayerDataService.Save, b)
	return true
end

local function confirm(player)
	local session = sessions[player]
	if not session then return end
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
	elseif action == "Confirm" then confirm(player)
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
