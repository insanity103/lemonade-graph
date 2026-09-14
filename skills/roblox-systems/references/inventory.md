# Inventory System Architecture

## Item Schema

```lua
-- each entry in the inventory array
{
	id       = "sword_iron",    -- unique string key -- [TUNING] per-item
	name     = "Iron Sword",    -- display name
	type     = "Weapon",        -- Weapon | Armor | Consumable | Cosmetic | Material
	rarity   = "Common",        -- Common | Uncommon | Rare | Epic | Legendary -- [TUNING] per-item
	stackable = false,          -- true for consumables/materials -- [TUNING] per-item
	maxStack  = 1,              -- [TUNING] ignored if stackable=false
	count     = 1,              -- current stack count
	metadata  = {},             -- arbitrary: {level=3, enchant="fire"}
	equipped  = false,          -- whether this entry is equipped
}
```

- Non-stackable items always have `count = 1` and each gets its own array slot.
- Stackable items share one slot; `count` increments up to `maxStack`.

## Storage Layout

```lua
-- DataStore per player
inventory = {
	{ id = "sword_iron", count = 1, equipped = true, metadata = {} },
	{ id = "potion_hp",  count = 5, equipped = false, metadata = {} },
}
```

Store as an ordered array. Index position is not stable (items move on remove), so always look up by `id`.

## Add Item

```lua
local function addItem(data, itemId, count)
	count = count or 1
	local def = ItemDefs[itemId]
	if not def then return false, "Unknown item" end

	if def.stackable then
		-- find existing stack with room
		for _, entry in ipairs(data.inventory) do
			if entry.id == itemId and entry.count < def.maxStack then
				local space = def.maxStack - entry.count
				local added = math.min(count, space)
				entry.count += added
				count -= added
				if count <= 0 then return true end
			end
		end
	end

	-- overflow or non-stackable: create new entries
	while count > 0 do
		local chunk = def.stackable and math.min(count, def.maxStack) or 1
		table.insert(data.inventory, {
			id = itemId,
			count = chunk,
			equipped = false,
			metadata = {},
		})
		count -= chunk
	end
	return true
end
```

## Remove Item

```lua
local function removeItem(data, itemId, count)
	count = count or 1
	for i = #data.inventory, 1, -1 do -- reverse to keep indices stable
		local entry = data.inventory[i]
		if entry.id == itemId then
			if entry.count > count then
				entry.count -= count
				return true
			elseif entry.count == count then
				table.remove(data.inventory, i)
				return true
			else
				count -= entry.count
				table.remove(data.inventory, i)
			end
		end
	end
	return false, "Not enough items"
end
```

## Equip / Unequip

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EquipEvent = Instance.new("RemoteEvent")
EquipEvent.Name = "EquipEvent"
EquipEvent.Parent = ReplicatedStorage

local function equipItem(player, slotIndex)
	local data = DataStoreManager:Get(player)
	local entry = data.inventory[slotIndex]
	if not entry then return end

	local def = ItemDefs[entry.id]
	if not def or def.type == "Consumable" or def.type == "Material" then return end

	-- unequip same type first
	for _, e in ipairs(data.inventory) do
		if e.equipped and ItemDefs[e.id] and ItemDefs[e.id].type == def.type then
			e.equipped = false
		end
	end

	entry.equipped = true
	DataStoreManager:MarkDirty(player)

	-- apply to character
	local character = player.Character
	if character then
		-- set attribute for other systems to read
		character:SetAttribute("Equipped_" .. def.type, entry.id)
	end

	EquipEvent:FireClient(player, "Equipped", slotIndex, entry.id)
end

local function unequipItem(player, slotIndex)
	local data = DataStoreManager:Get(player)
	local entry = data.inventory[slotIndex]
	if not entry then return end
	entry.equipped = false
	DataStoreManager:MarkDirty(player)

	local character = player.Character
	if character then
		local def = ItemDefs[entry.id]
		if def then character:SetAttribute("Equipped_" .. def.type, nil) end
	end

	EquipEvent:FireClient(player, "Unequipped", slotIndex)
end

EquipEvent.OnServerEvent:Connect(function(player, action, slotIndex)
	if action == "Equip" then equipItem(player, slotIndex)
	elseif action == "Unequip" then unequipItem(player, slotIndex)
	end
end)
```

## Stacking

Stacking logic is built into `addItem` above. Key rules:

1. Scan existing entries for the same `id` with `count < maxStack`.
2. Fill partial stacks first before creating new entries.
3. Overflow into new stack entries automatically.

## Sorting (Client-Side)

```lua
-- LocalScript: sort inventory for display
local SORTS = {
	ByType = function(a, b)
		if a.type ~= b.type then return a.type < b.type end
		return a.name < b.name
	end,
	ByRarity = function(a, b)
		local order = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 } -- [TUNING] rarity sort order
		local ra, rb = order[a.rarity] or 0, order[b.rarity] or 0
		if ra ~= rb then return ra > rb end
		return a.name < b.name
	end,
	ByName = function(a, b) return a.name < b.name end,
}

local function sortInventory(inventory, method)
	local sorted = table.clone(inventory)
	table.sort(sorted, SORTS[method] or SORTS.ByType)
	return sorted
end
```

## Trading

Two-player atomic swap, both must confirm.

```lua
local TradeRequest = Instance.new("RemoteFunction")
TradeRequest.Name = "TradeRequest"
TradeRequest.Parent = ReplicatedStorage

local ConfirmTrade = Instance.new("RemoteEvent")
ConfirmTrade.Name = "ConfirmTrade"
ConfirmTrade.Parent = ReplicatedStorage

local pendingTrades = --[[
	[tradeId] = {
		playerA = userId, playerB = userId,
		offerA = { {slot = 1, count = 1} },
		offerB = { {slot = 3, count = 2} },
		confirmedA = false, confirmedB = false,
	}
]]

local function executeTrade(trade)
	local playerA = Players:GetPlayerByUserId(trade.playerA)
	local playerB = Players:GetPlayerByUserId(trade.playerB)
	if not playerA or not playerB then return false end

	local dataA = DataStoreManager:Get(playerA)
	local dataB = DataStoreManager:Get(playerB)

	-- validate both offers still valid
	for _, offer in ipairs(trade.offerA) do
		local entry = dataA.inventory[offer.slot]
		if not entry or entry.count < offer.count then return false end
	end
	for _, offer in ipairs(trade.offerB) do
		local entry = dataB.inventory[offer.slot]
		if not entry or entry.count < offer.count then return false end
	end

	-- atomic swap: remove then add (server-side only)
	for _, offer in ipairs(trade.offerA) do
		local entry = dataA.inventory[offer.slot]
		removeItem(dataA, entry.id, offer.count)
		addItem(dataB, entry.id, offer.count)
	end
	for _, offer in ipairs(trade.offerB) do
		local entry = dataB.inventory[offer.slot]
		removeItem(dataB, entry.id, offer.count)
		addItem(dataA, entry.id, offer.count)
	end

	DataStoreManager:MarkDirty(playerA)
	DataStoreManager:MarkDirty(playerB)
	return true
end
```

## Full Working Example: Inventory Module

```lua
-- InventoryManager (ModuleScript, ServerScriptService)
local ItemDefs = require(game.ReplicatedStorage.ItemDefinitions)

local InventoryManager = {}

function InventoryManager:Add(data, itemId, count)
	count = count or 1
	local def = ItemDefs[itemId]
	if not def then return false end
	if def.stackable then
		for _, entry in ipairs(data.inventory) do
			if entry.id == itemId and entry.count < def.maxStack then
				local added = math.min(count, def.maxStack - entry.count)
				entry.count += added
				count -= added
				if count <= 0 then return true end
			end
		end
	end
	while count > 0 do
		local chunk = def.stackable and math.min(count, def.maxStack) or 1
		table.insert(data.inventory, { id = itemId, count = chunk, equipped = false, metadata = {} })
		count -= chunk
	end
	return true
end

function InventoryManager:Remove(data, itemId, count)
	count = count or 1
	for i = #data.inventory, 1, -1 do
		local e = data.inventory[i]
		if e.id == itemId then
			if e.count > count then e.count -= count return true
			elseif e.count == count then table.remove(data.inventory, i) return true
			else count -= e.count table.remove(data.inventory, i) end
		end
	end
	return false
end

function InventoryManager:Equip(data, slot)
	local entry = data.inventory[slot]
	if not entry then return end
	local def = ItemDefs[entry.id]
	if not def then return end
	for _, e in ipairs(data.inventory) do
		if e.equipped and ItemDefs[e.id] and ItemDefs[e.id].type == def.type then e.equipped = false end
	end
	entry.equipped = true
end

function InventoryManager:HasItem(data, itemId, count)
	count = count or 1
	local total = 0
	for _, e in ipairs(data.inventory) do
		if e.id == itemId then total += e.count end
	end
	return total >= count
end

return InventoryManager
```
