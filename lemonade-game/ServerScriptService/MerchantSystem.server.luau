--// MerchantSystem | THE RELIC BLACKSMITH. One purchasable thing: a blade rolled when you pay.
--
-- The shop has no listings. `Config.MerchantConfig.OfferForLevel(level)` is the entire shop: the
-- pools the roll runs on, the real rarity odds, the damage band, and a price that is a function
-- of the buyer's level. This script owns the roll, the gold and the pity; the client only draws
-- what it is sent and presses a button.
--
-- WHEN THE BLADE IS ROLLED: AT PURCHASE. Not on a timer, not per visit. If a named sword sat on
-- the counter and re-rolled on a timer or on each visit, the cheapest play would be to close and
-- reopen the shop until a Legendary showed -- a free reroll loop that makes the price meaningless
-- and turns every published odd into a lie. Rolling at the instant the gold is debited means the
-- odds on the panel ARE the odds, the server is the only thing that ever sees the roll, and the
-- decision the player makes is about gold, not about patience. The OFFER (band, pools, odds,
-- price) changes only when the player's level changes, so it is stable enough to plan against.
--
-- Everything is server-authoritative: level, price, pool choice, rarity, sword, jitter, modifiers.
-- No Robux path of any kind: nothing here touches a marketplace service, a game pass or a
-- developer product. The pity counter is earned in play and saved with the profile.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local MerchantConfig = require(Config:WaitForChild("MerchantConfig"))
local SwordValue = require(Config:WaitForChild("SwordValue"))
local BossSwordFactory = require(script.Parent:WaitForChild("BossSwordFactory"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local WorldLayout = require(script.Parent:WaitForChild("WorldLayout"))
WorldLayout.EnsureBuilt()
if WorldLayout.BLANK_SLATE then return end

local REMOTES = ReplicatedStorage:WaitForChild("RemoteEvents")
local MERCHANT_ACTION = REMOTES:WaitForChild("MerchantAction")
local DROP_EVENT = REMOTES:WaitForChild("SwordDrop")

local PURCHASE_DISTANCE = 16
-- The window the player's own gold-per-hour is measured over. Short enough to read what they are
-- farming NOW, long enough that one boss kill does not swing it.
local EARN_WINDOW = 600
local merchantModel

-- ==============================================================================
-- THE PLAYER'S OWN INCOME, MEASURED (not a table of design figures)
-- Every increase of the Gold leaderstat is income: kill gold (LevelingSystem), auto-sell
-- (SwordDropSystem), quests. Decreases are the player spending, and are ignored. The rate is
-- what the panel prints as "your gold per hour", so the price can be quoted in minutes of the
-- player's OWN farming rather than in a figure from a spreadsheet.
-- ==============================================================================
local earn = {} -- [player] = { events = { {t, amount} }, last = <gold>, since = <clock> }

local function pruneEarn(record, now)
	local cutoff = now - EARN_WINDOW
	while record.events[1] and record.events[1].t < cutoff do
		table.remove(record.events, 1)
	end
end

local function goldPerHour(player): number
	local record = earn[player]
	if not record then return 0 end
	local now = os.clock()
	pruneEarn(record, now)
	local total = 0
	for _, e in ipairs(record.events) do total += e.amount end
	local elapsed = math.min(now - record.since, EARN_WINDOW)
	if elapsed < 30 or total <= 0 then return 0 end -- too early to claim a rate
	return math.floor(total / elapsed * 3600 + 0.5)
end

local function watchGold(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local goldStat = leaderstats and leaderstats:FindFirstChild("Gold")
	if not goldStat or not goldStat:IsA("IntValue") then return end
	local record = { events = {}, last = goldStat.Value, since = os.clock() }
	earn[player] = record
	goldStat.Changed:Connect(function(value)
		local delta = value - record.last
		record.last = value
		if delta > 0 then
			local now = os.clock()
			table.insert(record.events, { t = now, amount = delta })
			pruneEarn(record, now)
		end
	end)
end

local function onPlayer(player)
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats", 30)
		if leaderstats and leaderstats:WaitForChild("Gold", 10) then
			watchGold(player)
		end
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do onPlayer(player) end
Players.PlayerRemoving:Connect(function(player)
	earn[player] = nil
end)

-- ==============================================================================
-- THE OFFER
-- ==============================================================================
local function levelOf(player): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelStat = leaderstats and leaderstats:FindFirstChild("Level")
	return math.max(1, (levelStat and levelStat.Value) or player:GetAttribute("Level") or 1)
end

local function goldOf(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local goldStat = leaderstats and leaderstats:FindFirstChild("Gold")
	if goldStat and goldStat:IsA("IntValue") then return goldStat end
	return nil
end

-- The sword the player is holding, or the best one in their pack: the thing a forge strike would
-- actually be spent on, so the panel can put the two prices side by side.
local function carriedSword(player): Instance?
	local best, bestRating
	local function consider(tool)
		if tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true then
			local rating = SwordValue.rateTool(tool)
			if not bestRating or rating > bestRating then best, bestRating = tool, rating end
		end
	end
	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do consider(child) end
		if best then return best end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do consider(child) end
	end
	return best
end

-- The offer as the client receives it: the shipped table plus the three live, per-player numbers
-- that make the price readable -- what the player has, what they earn, and what a strike on their
-- own sword costs right now.
local function offerFor(player)
	local level = levelOf(player)
	local offer = table.clone(MerchantConfig.OfferForLevel(level))

	local goldStat = goldOf(player)
	offer.gold = goldStat and goldStat.Value or 0
	offer.goldPerHour = goldPerHour(player)
	offer.minutesToAfford = offer.goldPerHour > 0
		and math.max(0, (offer.price - offer.gold) / offer.goldPerHour * 60) or nil

	local tool = carriedSword(player)
	if tool then
		local attrs = SwordValue.attrsOfTool(tool)
		offer.yourSword = tool:GetAttribute("BaseWeaponName") or tool.Name
		offer.yourSwordBase = tonumber(attrs.BaseMult) or 0
		offer.yourStrike = SwordValue.rerollCost(attrs)
		offer.priceInYourStrikes = offer.yourStrike > 0 and offer.price / offer.yourStrike or nil
	end

	offer.pity = PlayerDataService.GetField(player, "merchantPity") or 0
	offer.purchases = PlayerDataService.GetField(player, "merchantCount") or 0
	offer.pityIn = math.max(0, MerchantConfig.PITY_PURCHASES - offer.pity)
	return offer
end

-- ==============================================================================
-- THE MERCHANT NPC
-- ==============================================================================
local function setupMerchantNPC()
	if WorldLayout.GAMEPLAY_ONLY then
		local actors = require(script.Parent:WaitForChild("GameplayActors"))
		if not WorldLayout.HUB.MerchantPosition then return nil end -- map lacks the marker: shop idle
		local npc = actors.create("RelicMerchantNPC", WorldLayout.HUB.MerchantPosition, Color3.fromRGB(90, 70, 50),
			{ facing = WorldLayout.HUB.MerchantCFrame, title = "Relic Blacksmith", subtitle = "One blade, rolled for your level", outfit = "Blacksmith" })
		actors.prompt(npc, "Buy a Mystery Blade", "Relic Blacksmith").Triggered:Connect(function(player)
			MERCHANT_ACTION:FireClient(player, "OpenShop", offerFor(player))
		end)
		return npc
	end
	return nil
end

merchantModel = setupMerchantNPC()

local function isNearMerchant(player)
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local merchantRoot = merchantModel and merchantModel.PrimaryPart
	return playerRoot ~= nil and merchantRoot ~= nil
		and (playerRoot.Position - merchantRoot.Position).Magnitude <= PURCHASE_DISTANCE
end

-- ==============================================================================
-- THE ROLL. One place, server-side, at the moment the gold leaves.
-- ==============================================================================
local RARITY_INDEX = {}
for i, name in ipairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary" }) do RARITY_INDEX[name] = i end

-- Rolls one blade for `level`, honouring the pity floor. Returns tool, mods, fullName, extraSlot,
-- weaponData, poolKey. Exposed so a Studio-only harness measures the SHIPPED roll, not a copy.
local function rollBlade(level, pityCount)
	local poolKey, opts, floor = MerchantConfig.RollArgs(level, pityCount)
	local tool, mods, fullName, gotExtraSlot, weaponData = BossSwordFactory.build(poolKey, opts)
	return tool, mods, fullName, gotExtraSlot, weaponData, poolKey, floor
end
-- A Studio-only harness drives the SHIPPED roll through this handle, so a measurement can never
-- be a copy of the roll. It does not exist on a live server.
if game:GetService("RunService"):IsStudio() then
	_G.MerchantRollBlade = rollBlade
end

local lastPurchase = {} -- [player] = os.clock()

local function fail(player, message)
	MERCHANT_ACTION:FireClient(player, "PurchaseResult", false, message, offerFor(player))
end

MERCHANT_ACTION.OnServerEvent:Connect(function(player, action)
	if action == "RequestOffer" then
		MERCHANT_ACTION:FireClient(player, "Offer", offerFor(player))
		return
	end
	if action ~= "BuySword" and action ~= "BuyBlade" then
		return
	end
	if player:GetAttribute("DataLoaded") ~= true then
		return fail(player, "Your data is still loading.")
	end
	if not isNearMerchant(player) then
		return fail(player, "Move closer to the Relic Blacksmith to buy this.")
	end
	local now = os.clock()
	if lastPurchase[player] and now - lastPurchase[player] < MerchantConfig.PURCHASE_COOLDOWN then
		return fail(player, "The anvil is still hot. One blade at a time.")
	end

	local goldStat = goldOf(player)
	if not goldStat then
		return fail(player, "Gold data error.")
	end

	-- The price is recomputed here from the player's OWN level: the client never sends a price.
	local level = levelOf(player)
	local price = MerchantConfig.PriceForLevel(level)
	if goldStat.Value < price then
		return fail(player, ("Not enough Gold! A blade at level %d costs %d Gold."):format(level, price))
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return fail(player, "Your inventory is not ready yet.")
	end

	local pity = PlayerDataService.GetField(player, "merchantPity") or 0

	-- Built before the gold is debited, so a bad template can never take payment for nothing.
	local ok, tool, mods, fullName, gotExtraSlot, weaponData, poolKey, floor = pcall(rollBlade, level, pity)
	if not ok or not tool then
		warn(string.format("[MerchantSystem] Could not roll a blade for %s at level %d: %s",
			player.Name, level, tostring(tool)))
		return fail(player, "The forge is cold. Try again in a moment.")
	end

	lastPurchase[player] = now
	goldStat.Value -= price
	tool.Parent = backpack

	-- Pity: purchases in a row below the floor. Reset the moment the floor rarity or better lands.
	local reached = (RARITY_INDEX[weaponData.rarity] or 1) >= (RARITY_INDEX[MerchantConfig.PITY_FLOOR] or 3)
	PlayerDataService.SetField(player, "merchantPity", reached and 0 or (pity + 1))
	PlayerDataService.SetField(player, "merchantCount",
		(PlayerDataService.GetField(player, "merchantCount") or 0) + 1)
	PlayerDataService.MarkDirty(player)

	DROP_EVENT:FireClient(player, weaponData.rarity, weaponData.baseMult, fullName, mods, gotExtraSlot,
		{ pool = "Relic Blacksmith", baseName = weaponData.name, listedBase = weaponData.listedBase })
	MERCHANT_ACTION:FireClient(player, "PurchaseResult", true,
		("The blacksmith rolled [%s] for %d Gold!"):format(fullName, price), offerFor(player))

	print(string.format("[MerchantSystem] %s bought a mystery blade at level %d for %d Gold -> [%s] %s x%.2f from %s%s",
		player.Name, level, price, fullName, weaponData.rarity, weaponData.baseMult, poolKey,
		floor and (" (pity floor " .. floor .. ")") or ""))
end)

print("[MerchantSystem] Relic Blacksmith online: one blade, rolled for your level, at purchase")
