# Shop & Economy System Architecture

## Data Schema

```lua
-- stored in DataStore per player
currency = { coins = 100, gems = 0 },
ownedItems = { ["sword_iron"] = true, ["hat_wizard"] = true },
purchaseHistory = {
	{ id = "sword_iron", cost = 50, currency = "coins", timestamp = 1700000000 },
},
```

- `currency` — key-value map; easy to add new currencies.
- `ownedItems` — set (keys = item ID, value = `true`) for O(1) ownership checks.
- `purchaseHistory` — append-only log for auditing; trim to last 100 entries.

## Purchase Flow

```
Client: RemoteEvent "RequestPurchase" → itemId
Server:
  1. Validate: item exists in catalog
  2. Validate: player does NOT already own it (non-stackable)
  3. Validate: player has enough currency
  4. Deduct currency (server-side, never from client)
  5. Add to ownedItems
  6. Append to purchaseHistory
  7. Respond success/failure via RemoteEvent
```

```lua
-- Server: handle purchase
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopEvent = Instance.new("RemoteEvent")
ShopEvent.Name = "ShopEvent"
ShopEvent.Parent = ReplicatedStorage

local function requestPurchase(player, itemId)
	local data = DataStoreManager:Get(player)
	local item = Catalog[itemId]
	if not item then return false, "Invalid item" end
	if data.ownedItems[itemId] then return false, "Already owned" end
	if (data.currency[item.currency or "coins"] or 0) < item.cost then
		return false, "Insufficient currency"
	end
	data.currency[item.currency or "coins"] -= item.cost
	data.ownedItems[itemId] = true
	table.insert(data.purchaseHistory, {
		id = itemId, cost = item.cost,
		currency = item.currency or "coins",
		timestamp = os.time(),
	})
	DataStoreManager:MarkDirty(player)
	ShopEvent:FireClient(player, "PurchaseSuccess", itemId)
	return true
end

ShopEvent.OnServerEvent:Connect(function(player, action, itemId)
	if action == "Purchase" then
		local ok, reason = requestPurchase(player, itemId)
		if not ok then
			ShopEvent:FireClient(player, "PurchaseFailed", itemId, reason)
		end
	end
end)
```

## Currency Validation — Always Server-Side

- **Never** accept `currency` or `totalSpent` from the client.
- Client sends only the item ID it wants to buy. Server looks up cost, checks balance, deducts.
- Log discrepancies: if client requests an item repeatedly without owning it, flag for review.

## Shop UI Catalog (ModuleScript)

```lua
-- ReplicatedStorage/ShopCatalog
local Catalog = {
	sword_iron = {
		name = "Iron Sword",
		description = "A sturdy iron blade.",
		cost = 50,
		currency = "coins", -- [TUNING]
		imageId = "rbxassetid://123456", -- [TUNING]
		category = "Weapons",
	},
	sword_gold = {
		name = "Gold Sword",
		description = "Forged from pure gold. Fearsome.",
		cost = 200,
		currency = "coins",
		imageId = "rbxassetid://123457",
		category = "Weapons",
	},
	hat_wizard = {
		name = "Wizard Hat",
		description = "Arcane headwear.",
		cost = 5,
		currency = "gems",
		imageId = "rbxassetid://123458",
		category = "Cosmetics",
	},
}

return Catalog
```

## Game Pass Integration

```lua
local MPS = game:GetService("MarketplaceService")
local VIP_PASS_ID = 12345678 -- [TUNING]

local function ownsVip(player)
	return pcall(MPS.UserOwnsGamePassAsync, MPS, player.UserId, VIP_PASS_ID) or false
end

Players.PlayerAdded:Connect(function(player)
	local hasVip = ownsVip(player)
	if hasVip then
		-- grant VIP perks: extra currency multiplier, exclusive shop items, etc.
	end
end)

-- Also re-check on purchase attempt (in case they buy it mid-session)
MPS.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == VIP_PASS_ID then
		-- grant VIP perks immediately
	end
end)
```

## Developer Products (One-Time Purchases)

```lua
local PROCESSABLE = {
	[111111] = { action = "grantCurrency", amount = 100, currency = "gems" }, -- [TUNING]
	[111112] = { action = "grantCurrency", amount = 1000, currency = "coins" },
}

MPS.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local product = PROCESSABLE[receiptInfo.ProductId]
	if not product then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local data = DataStoreManager:Get(player)
	if product.action == "grantCurrency" then
		data.currency[product.currency] = (data.currency[product.currency] or 0) + product.amount
		DataStoreManager:MarkDirty(player)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end
```

## Sale / Discount System

```lua
local Sales = {
	{
		itemId = "sword_iron",
		discount = 0.25, -- 25% off -- [TUNING]
		startTime = 1700000000, -- os.time()
		endTime   = 1700086400,
	},
}

local function getActivePrice(item)
	for _, sale in ipairs(Sales) do
		if sale.itemId == item.id then
			local now = os.time()
			if now >= sale.startTime and now <= sale.endTime then
				return math.floor(item.cost * (1 - sale.discount))
			end
		end
	end
	return item.cost
end
```

## Anti-Exploit Checklist

| Check | Where |
|---|---|
| Item exists in catalog | Server, before any processing |
| Player doesn't already own it | Server, before deduction |
| Currency amount is sufficient | Server, never trust client |
| Rate limit: max 10 purchases/minute | Server, timestamp table per player |
| Log every transaction (success + fail) | Server, append to purchaseHistory |
| Validate Developer Product ID | ProcessReceipt, before granting |

```lua
-- rate limit
local purchaseTimestamps = {}
local MAX_PURCHASES_PER_MIN = 10 -- [TUNING]

local function checkRateLimit(player)
	local now = os.clock()
	local ts = purchaseTimestamps[player.UserId] or {}
	-- remove entries older than 60s
	for i = #ts, 1, -1 do
		if now - ts[i] > 60 then table.remove(ts, i) end
	end
	if #ts >= MAX_PURCHASES_PER_MIN then return false end
	table.insert(ts, now)
	purchaseTimestamps[player.UserId] = ts
	return true
end
```

## Full Working Example: Client Shop UI

```lua
-- LocalScript in StarterPlayerScripts
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopEvent = ReplicatedStorage:WaitForChild("ShopEvent")
local Catalog = require(ReplicatedStorage:WaitForChild("ShopCatalog"))
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function buildShop()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopGui"
	gui.Parent = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(0.6, 0.8)
	frame.Position = UDim2.fromScale(0.2, 0.1)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.Parent = gui

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(150, 180)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.Parent = frame

	for itemId, item in pairs(Catalog) do
		local btn = Instance.new("TextButton")
		btn.Name = itemId
		btn.Text = ("%s\n%s %s"):format(item.name, item.cost, item.currency)
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 14
		btn.TextWrapped = true
		btn.Parent = frame
		btn.Activated:Connect(function()
			ShopEvent:FireServer("Purchase", itemId)
		end)
	end

	return gui
end

local shopGui = buildShop()
shopGui.Enabled = false -- hidden by default

ShopEvent.OnClientEvent:Connect(function(action, itemId, reason)
	if action == "PurchaseSuccess" then
		print("Purchased:", itemId)
	elseif action == "PurchaseFailed" then
		warn("Purchase failed:", itemId, reason)
	end
end)
```

Toggle `shopGui.Enabled` with a button or keybind to open/close the shop.
