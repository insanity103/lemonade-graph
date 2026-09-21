-- Script | ServerScriptService.VaultSystem | The Vaultkeeper: store boss swords in the profile's
-- vault so they survive rebirths and server hops, and take them back out later.
--
-- This script also owns the two numbers the sword economy is scored on and everything that
-- reacts to them:
--   * WEALTH   -- the sum of SwordValue ratings across everything carried and stored. A
--                 collection score: how good the relics are, in the game's own unit.
--   * FORTUNE  -- net worth IN GOLD: the purse, plus what every carried relic would sell for,
--                 plus what every STORED relic would sell for at the Vaultkeeper's appraisal
--                 (WealthLadder.STORED_APPRAISAL). This is the number the wealth milestones are
--                 hung on, because a rung has to be comparable with a price.
-- Both are server-computed, on a tick and on every vault change; the client only renders them.
-- Slots beyond the free shelf are BOUGHT here, server-side, from the player's Gold leaderstat.
-- The vault holds save entries (never Tools); withdrawing rebuilds the Tool with
-- BossSwordFactory.rebuild, exactly as a saved backpack sword is restored on join.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local SwordValue = require(Config:WaitForChild("SwordValue"))
local SellValue = require(Config:WaitForChild("SellValue"))
local VaultConfig = require(Config:WaitForChild("VaultConfig"))
local WealthLadder = require(Config:WaitForChild("WealthLadder"))
local WorldLayout = require(script.Parent:WaitForChild("WorldLayout"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local BossSwordFactory = require(script.Parent:WaitForChild("BossSwordFactory"))
local actors = require(script.Parent:WaitForChild("GameplayActors"))

if WorldLayout.BLANK_SLATE then return end

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local VAULT_ACTION = remotes:WaitForChild("VaultAction")
local NOTIFY = remotes:WaitForChild("Notify")

local INTERACT_RANGE = 16 -- [TUNING] studs from the keeper for any vault action
local REQUEST_INTERVAL = 0.25
local SAVE_COOLDOWN = 8 -- [TUNING] seconds between DataStore writes triggered by vault edits

local keeper = nil
local lastRequestAt = {}
local lastSaveAt = {}

-- ── State sent to the client ─────────────────────────────────────────────────
local function describe(entry)
	local attrs = entry.attrs or {}
	return {
		name = entry.name,
		rarity = attrs.Rarity or "Common",
		prefixes = attrs.Prefixes or "",
		damageMult = attrs.DamageMult or 1,
		tier = attrs.BossTier or 1,
		rating = SwordValue.rateAttrs(attrs),
	}
end

-- ── Slots: the free shelf, the bought ones, the granted ones ─────────────────
-- Exactly one place decides how many swords a player can store, and it is the server.
local function boughtSlots(player): number
	return math.max(0, math.floor(tonumber(PlayerDataService.GetField(player, "vaultSlots")) or 0))
end

local function earnedRung(player): number
	return math.clamp(math.floor(tonumber(PlayerDataService.GetField(player, "wealthRung")) or 0),
		0, WealthLadder.RUNG_COUNT)
end

local function grantedSlots(player): number
	return WealthLadder.PerksFor(earnedRung(player)).slots
end

local function capacityOf(player): number
	return VaultConfig.CapacityFor(boughtSlots(player), grantedSlots(player))
end

local function goldStat(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Gold") or nil
end

-- ── Wealth and Fortune: the sword economy's two scores ───────────────────────
-- Wealth  = sum of SwordValue RATINGS for every relic carried or vaulted (a collection score).
-- Fortune = NET WORTH IN GOLD: purse + what the carried relics would sell for + what the stored
--           ones would sell for at the Vaultkeeper's appraisal. Prices come from SellValue, the
--           same module the pickup prompt and the inventory SELL button pay out of, quoted at
--           goldMult 1 so a rebirth multiplier can never inflate a milestone.
-- Both are derived, never saved; recomputed on vault changes and on a slow tick so drops, buys
-- and sells show up without every system having to call in.
local WEALTH_TICK = 4 -- [TUNING] seconds

-- Ratings, carried gold worth and stored gold worth, in one pass over the same containers.
local function tally(player)
	local rating, carriedGold, storedGold = 0, 0, 0
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				local value = SwordValue.rateTool(tool)
				if value > 0 then
					rating += value
					carriedGold += SellValue.ForTool(tool, 1)
				end
			end
		end
	end
	local vault = PlayerDataService.GetVault(player)
	for _, entry in ipairs(vault or {}) do
		rating += SwordValue.rateAttrs(entry.attrs)
		storedGold += SellValue.Gold(entry.attrs, 1)
	end
	return rating, carriedGold, storedGold
end

-- ── The wealth ladder: what being rich is worth ──────────────────────────────
-- Perks are recomputed from the earned rung every time it changes, so they are always exactly
-- what the profile says and never drift. They are published as attributes because the systems
-- that consume them live elsewhere: ReforgeSystem reads MilestoneLuck and MilestoneFreeStrike,
-- SwordDropSystem reads MilestoneLuck, VaultGui reads WealthTitle and VaultTrim, and the
-- overhead plate below reads WealthTitle.
local function applyPerks(player)
	local perks = WealthLadder.PerksFor(earnedRung(player))
	player:SetAttribute("WealthRung", perks.rung)
	player:SetAttribute("WealthTitle", perks.title or "")
	player:SetAttribute("VaultTrim", perks.trim or "")
	player:SetAttribute("MilestoneLuck", perks.luck)
	player:SetAttribute("MilestoneFreeStrike", perks.freeStrike)
	player:SetAttribute("MilestoneSlots", perks.slots)
end

-- A plate over the player's head carrying the title they earned, so a rung is something other
-- players can read. Nothing is drawn until a rung is actually earned.
local TITLE_PLATE = "WealthTitlePlate"

local function refreshTitlePlate(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end
	local title = player:GetAttribute("WealthTitle")
	local plate = head:FindFirstChild(TITLE_PLATE)
	if typeof(title) ~= "string" or title == "" then
		if plate then plate:Destroy() end
		return
	end
	if not plate then
		plate = Instance.new("BillboardGui")
		plate.Name = TITLE_PLATE
		plate.Size = UDim2.fromOffset(240, 34)
		plate.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		plate.AlwaysOnTop = false
		plate.MaxDistance = 120
		plate.Parent = head
		local label = Instance.new("TextLabel")
		label.Name = "Title"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 226, 120)
		label.Parent = plate
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Color = Color3.fromRGB(40, 30, 10)
		stroke.Parent = label
	end
	local label = plate:FindFirstChild("Title")
	if label then label.Text = title end
end

-- Grant every rung the fortune has reached but the profile has not yet banked. Earned once:
-- `wealthRung` only ever goes up, so spending the money afterwards keeps the title and its perks.
local function grantMilestones(player, fortune)
	local best = math.max(tonumber(PlayerDataService.GetField(player, "wealthBest")) or 0, fortune)
	if best ~= PlayerDataService.GetField(player, "wealthBest") then
		PlayerDataService.SetField(player, "wealthBest", best)
	end
	local held = earnedRung(player)
	local reached = WealthLadder.RungFor(best)
	if reached <= held then
		return false
	end
	for index = held + 1, reached do
		local rung = WealthLadder.Rungs[index]
		PlayerDataService.SetField(player, "wealthRung", index)
		applyPerks(player)
		refreshTitlePlate(player)
		local rewards = {}
		if rung.slots then table.insert(rewards, string.format("+%d vault slot%s", rung.slots,
			rung.slots == 1 and "" or "s")) end
		if rung.luck then table.insert(rewards, string.format("+%.2f standing luck", rung.luck)) end
		if rung.freeStrike then table.insert(rewards, string.format("-%d min on the free forge strike",
			math.floor(rung.freeStrike / 60))) end
		if rung.trim then table.insert(rewards, rung.trim .. " vault trim") end
		NOTIFY:FireClient(player, string.format("WEALTH MILESTONE -- %s (%s fortune): %s",
			rung.name, WealthLadder.short(rung.threshold), table.concat(rewards, ", ")), "success")
		-- The back half of the ladder is rare enough to be worth the whole server hearing about.
		if index >= WealthLadder.RUNG_COUNT - 2 then
			NOTIFY:FireAllClients(string.format("%s reached %s -- %s fortune!", player.DisplayName,
				rung.name, WealthLadder.short(rung.threshold)), "success")
		end
	end
	PlayerDataService.MarkDirty(player)
	return true
end

-- Wealth is both a player attribute (menus, vault, trade read it) and a leaderstat, so the
-- Roblox leaderboard shows it beside Level and Rebirths. It is derived from the swords each
-- time, never saved (SaveConfig.LEADERSTATS does not list it). Fortune rides along beside it as
-- an attribute, and every refresh is the moment a milestone can be earned.
local function refreshWealth(player)
	-- Idempotent perk repair: if the attributes do not match what the profile says (a player who
	-- was already in the server when this script loaded, or a respawn that raced the grant), put
	-- them back. Costs one attribute read on a four-second tick.
	if player:GetAttribute("WealthRung") ~= earnedRung(player) then
		applyPerks(player)
		refreshTitlePlate(player)
	end
	local rating, carriedGold, storedGold = tally(player)
	if player:GetAttribute("Wealth") ~= rating then
		player:SetAttribute("Wealth", rating)
	end
	local gold = goldStat(player)
	local fortune = WealthLadder.Fortune(gold and gold.Value or 0, carriedGold, storedGold)
	if player:GetAttribute("Fortune") ~= fortune then
		player:SetAttribute("Fortune", fortune)
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local stat = stats:FindFirstChild("Wealth")
		if not stat then
			stat = Instance.new("IntValue")
			stat.Name = "Wealth"
			stat.Parent = stats
		end
		if stat.Value ~= rating then stat.Value = rating end
	end
	return grantMilestones(player, fortune)
end

task.spawn(function()
	while true do
		task.wait(WEALTH_TICK)
		for _, player in ipairs(Players:GetPlayers()) do
			if player:GetAttribute("DataLoaded") == true then
				refreshWealth(player)
			end
		end
	end
end)

-- Perks and the overhead plate are restored the moment a profile is ready and on every respawn,
-- so a returning player keeps what they earned without having to earn it again.
Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		local deadline = os.clock() + 30
		while player.Parent and player:GetAttribute("DataLoaded") ~= true and os.clock() < deadline do
			task.wait(0.5)
		end
		if player.Parent and player:GetAttribute("DataLoaded") == true then
			applyPerks(player)
			refreshTitlePlate(player)
		end
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		refreshTitlePlate(player)
	end)
end)

local function sendState(player)
	local vault = PlayerDataService.GetVault(player)
	if not vault then return end
	local stored = {}
	for i, entry in ipairs(vault) do
		local row = describe(entry)
		row.index = i
		stored[i] = row
	end
	local carried = {}
	local equippedTool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true and tool:GetAttribute("Starter") ~= true then
					local row = describe(PlayerDataService.SerializeTool(tool, tool == equippedTool))
					row.toolName = tool.Name
					row.equipped = tool == equippedTool
					table.insert(carried, row)
				end
			end
		end
	end
	-- The client is told the price of the next slot BEFORE it can ask to buy one, and the whole
	-- ladder it is climbing, so nothing about either is a surprise or a client guess.
	local bought, granted = boughtSlots(player), grantedSlots(player)
	local rung = earnedRung(player)
	local nextRung = WealthLadder.NextRung(rung)
	local rating, carriedGold, storedGold = tally(player)
	local gold = goldStat(player)
	local meta = {
		capacity = VaultConfig.CapacityFor(bought, granted),
		freeSlots = VaultConfig.STARTING_SLOTS,
		boughtSlots = bought,
		grantedSlots = granted,
		maxSlots = VaultConfig.MAX_SLOTS,
		slotsLeft = VaultConfig.PurchasableLeft(bought, granted),
		slotPrice = VaultConfig.PriceForNext(bought, granted),
		nextFivePrice = VaultConfig.PriceRange(bought, bought + 5),
		gold = gold and gold.Value or 0,
		wealth = rating,
		carriedGold = carriedGold,
		storedGold = storedGold,
		appraisal = WealthLadder.STORED_APPRAISAL,
		fortune = WealthLadder.Fortune(gold and gold.Value or 0, carriedGold, storedGold),
		rung = rung,
		rungCount = WealthLadder.RUNG_COUNT,
		title = rung > 0 and WealthLadder.Rungs[rung].name or "",
		trim = WealthLadder.PerksFor(rung).trim or "",
		nextName = nextRung and nextRung.name or nil,
		nextThreshold = nextRung and nextRung.threshold or nil,
	}
	VAULT_ACTION:FireClient(player, "State", stored, carried, meta.capacity, rating, meta)
end

local function saveSoon(player)
	PlayerDataService.MarkDirty(player)
	local now = os.clock()
	if now - (lastSaveAt[player] or -math.huge) < SAVE_COOLDOWN then return end
	lastSaveAt[player] = now
	task.spawn(PlayerDataService.Save, player)
end

-- ── Validation ───────────────────────────────────────────────────────────────
local function nearKeeper(player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return keeper ~= nil and root ~= nil and (root.Position - keeper.PrimaryPart.Position).Magnitude <= INTERACT_RANGE
end

local function findCarriedTool(player, toolName)
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if container then
			local tool = container:FindFirstChild(toolName)
			if tool and tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true and tool:GetAttribute("Starter") ~= true then
				return tool -- the starter is never shelved: the player always keeps one blade
			end
		end
	end
	return nil
end

-- ── Actions ──────────────────────────────────────────────────────────────────
local function deposit(player, toolName)
	local vault = PlayerDataService.GetVault(player)
	if not vault then return end
	local capacity = capacityOf(player)
	if #vault >= capacity then
		local price = VaultConfig.PriceForNext(boughtSlots(player), grantedSlots(player))
		NOTIFY:FireClient(player, price
			and string.format("The vault is full (%d swords). Another slot costs %d gold.", capacity, price)
			or string.format("The vault is full (%d swords) -- every slot in the game is yours.", capacity),
			"error")
		return
	end
	local tool = findCarriedTool(player, toolName)
	if not tool then
		NOTIFY:FireClient(player, "Only relic swords can be stored.", "error")
		return
	end
	if tool.Parent == player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:UnequipTools() end
	end
	table.insert(vault, PlayerDataService.SerializeTool(tool, false))
	tool:Destroy()
	NOTIFY:FireClient(player, string.format("%s stored with the Vaultkeeper.", toolName), "success")
	saveSoon(player)
	refreshWealth(player)
	sendState(player)
end

local function withdraw(player, index)
	local vault = PlayerDataService.GetVault(player)
	if not vault or typeof(index) ~= "number" then return end
	index = math.floor(index)
	local entry = vault[index]
	if not entry then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	local tool = BossSwordFactory.rebuild(entry)
	if not tool then
		NOTIFY:FireClient(player, "That sword could not be restored.", "error")
		return
	end
	table.remove(vault, index)
	tool.Parent = backpack
	NOTIFY:FireClient(player, string.format("%s returned to your backpack.", tool.Name), "success")
	saveSoon(player)
	refreshWealth(player)
	sendState(player)
end

-- ── Buying a slot ────────────────────────────────────────────────────────────
-- Server-authoritative end to end: the price comes from VaultConfig on the server, the gold is
-- debited from the leaderstat the server owns, the count that decides the NEXT price is the
-- persisted profile field, and the client is told the new price immediately. The client sends no
-- number at all -- "BuySlot" is the whole request.
local function buySlot(player)
	local vault = PlayerDataService.GetVault(player)
	if not vault then return end
	local bought, granted = boughtSlots(player), grantedSlots(player)
	local price = VaultConfig.PriceForNext(bought, granted)
	if not price then
		NOTIFY:FireClient(player, string.format("The Vaultkeeper has no more room: %d slots is every one in the game.",
			VaultConfig.MAX_SLOTS), "error")
		return
	end
	local gold = goldStat(player)
	if not gold then return end
	if gold.Value < price then
		NOTIFY:FireClient(player, string.format("Slot %d costs %d gold -- you have %d.",
			VaultConfig.CapacityFor(bought, granted) + 1, price, gold.Value), "error")
		sendState(player)
		return
	end
	gold.Value -= price
	PlayerDataService.SetField(player, "vaultSlots", bought + 1)
	local capacity = capacityOf(player)
	local nextPrice = VaultConfig.PriceForNext(bought + 1, granted)
	NOTIFY:FireClient(player, nextPrice
		and string.format("Vault slot %d bought for %d gold. The next one is %d.", capacity, price, nextPrice)
		or string.format("Vault slot %d bought for %d gold -- that is every slot in the game.", capacity, price),
		"success")
	saveSoon(player)
	refreshWealth(player)
	sendState(player)
end

VAULT_ACTION.OnServerEvent:Connect(function(player, action, arg)
	local now = os.clock()
	if now - (lastRequestAt[player] or -math.huge) < REQUEST_INTERVAL then return end
	lastRequestAt[player] = now
	if player:GetAttribute("DataLoaded") ~= true or not nearKeeper(player) then return end
	if action == "Open" then
		sendState(player)
	elseif action == "Deposit" and typeof(arg) == "string" then
		deposit(player, arg)
	elseif action == "Withdraw" then
		withdraw(player, arg)
	elseif action == "BuySlot" then
		buySlot(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequestAt[player], lastSaveAt[player] = nil, nil
end)

-- ── The keeper ───────────────────────────────────────────────────────────────
if not WorldLayout.HUB.VaultPosition then
	warn("[VaultSystem] No Vaultkeeper position; the vault stays idle")
	return
end
keeper = actors.create("Vaultkeeper", WorldLayout.HUB.VaultPosition, Color3.fromRGB(56, 92, 70),
	{ facing = WorldLayout.HUB.VaultCFrame, subtitle = "Stores your relic swords", outfit = "Vaultkeeper" })
actors.prompt(keeper, "Open Vault", "Vaultkeeper").Triggered:Connect(function(player)
	if player:GetAttribute("DataLoaded") ~= true then return end
	sendState(player)
	VAULT_ACTION:FireClient(player, "Open")
end)
print(string.format("[VaultSystem] Vaultkeeper ready (%d free slots, %d buyable to a cap of %d; "
	.. "first slot %d gold, last %d gold, whole ladder %d gold; %d wealth rungs from %s to %s fortune)",
	VaultConfig.STARTING_SLOTS, VaultConfig.MAX_SLOTS - VaultConfig.STARTING_SLOTS, VaultConfig.MAX_SLOTS,
	VaultConfig.PriceForNext(0, 0) or 0,
	VaultConfig.PriceForNext(VaultConfig.MAX_SLOTS - VaultConfig.STARTING_SLOTS - 1, 0) or 0,
	VaultConfig.PriceRange(0, VaultConfig.MAX_SLOTS - VaultConfig.STARTING_SLOTS),
	WealthLadder.RUNG_COUNT, WealthLadder.short(WealthLadder.Rungs[1].threshold),
	WealthLadder.short(WealthLadder.Rungs[WealthLadder.RUNG_COUNT].threshold)))
