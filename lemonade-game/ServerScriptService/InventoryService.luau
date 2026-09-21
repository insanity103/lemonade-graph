local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Items"))
-- The one sell price in the game. This module used to carry a private BOSS_SELL_VALUES of
-- 50/150/450/1200/3000 with no rarity factor and no lesser factor, against the drop handler's
-- own 60/300/2000/13000/100000 with both -- so the same tier-5 boss Legendary was worth 3,000
-- gold here and 800,000 gold there (ledger r00, section 4). There is now exactly one table, in
-- Config.SellValue, and the pickup prompt, this button and the price the inventory tile quotes
-- all read it.
local SellValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SellValue"))
local INVENTORY_UPDATED_EVENT = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("InventoryUpdated")

local InventoryService = {}

local playerInventories = {}
local DATA_FOLDER_NAME = "InventoryData"

local function getItemDefinition(itemId)
	return ItemConfig[itemId]
end

local function validateItemId(itemId)
	return typeof(itemId) == "string" and getItemDefinition(itemId) ~= nil
end

local function getDataFolder(player)
	return player:FindFirstChild(DATA_FOLDER_NAME)
end

local function ensureDataFolder(player)
	local folder = getDataFolder(player)
	if folder then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = DATA_FOLDER_NAME
	folder.Parent = player
	return folder
end

local function setStackValue(player, itemId, count)
	local folder = ensureDataFolder(player)
	local valueObject = folder:FindFirstChild(itemId)

	if count <= 0 then
		if valueObject then
			valueObject:Destroy()
		end
		return
	end

	if not valueObject then
		valueObject = Instance.new("IntValue")
		valueObject.Name = itemId
		valueObject.Parent = folder
	end

	valueObject.Value = count
end

local function rebuildReplication(player, inventory)
	local folder = ensureDataFolder(player)
	local seen = {}

	for itemId, count in pairs(inventory) do
		if count > 0 then
			seen[itemId] = true
			setStackValue(player, itemId, count)
		end
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("IntValue") and not seen[child.Name] then
			child:Destroy()
		end
	end
end

local function getInventorySnapshot(player)
	local inventory = playerInventories[player]
	if not inventory then
		return {}
	end

	local snapshot = {}
	for itemId, count in pairs(inventory) do
		if count > 0 then
			snapshot[itemId] = count
		end
	end
	return snapshot
end

local function notifyClient(player)
	INVENTORY_UPDATED_EVENT:FireClient(player, getInventorySnapshot(player))
end

local function getOrCreateInventory(player)
	local inventory = playerInventories[player]
	if inventory then
		return inventory
	end

	inventory = {}
	playerInventories[player] = inventory
	return inventory
end

function InventoryService.GetInventory(player)
	return getInventorySnapshot(player)
end

function InventoryService.GetItemCount(player, itemId)
	if not validateItemId(itemId) then
		return 0
	end

	local inventory = playerInventories[player]
	return inventory and (inventory[itemId] or 0) or 0
end

function InventoryService.CanAddItem(player, itemId, amount)
	if not player or not player.Parent or typeof(amount) ~= "number"
		or amount ~= math.floor(amount) or amount <= 0 or not validateItemId(itemId) then
		return false
	end

	local definition = getItemDefinition(itemId)
	local inventory = getOrCreateInventory(player)
	local currentCount = inventory[itemId] or 0
	local newCount = currentCount + amount

	return newCount <= definition.MaxStack
end

function InventoryService.AddItem(player, itemId, amount)
	if not InventoryService.CanAddItem(player, itemId, amount) then
		return false
	end

	local inventory = getOrCreateInventory(player)
	inventory[itemId] = (inventory[itemId] or 0) + amount

	setStackValue(player, itemId, inventory[itemId])
	notifyClient(player)
	return true
end

function InventoryService.RemoveItem(player, itemId, amount)
	if not player or not player.Parent or typeof(amount) ~= "number"
		or amount ~= math.floor(amount) or amount <= 0 or not validateItemId(itemId) then
		return false
	end

	local inventory = playerInventories[player]
	if not inventory then
		return false
	end

	local currentCount = inventory[itemId] or 0
	if currentCount < amount then
		return false
	end

	local newCount = currentCount - amount
	inventory[itemId] = newCount > 0 and newCount or nil

	setStackValue(player, itemId, newCount)
	notifyClient(player)
	return true
end

function InventoryService.HasItem(player, itemId, amount)
	amount = amount or 1
	return InventoryService.GetItemCount(player, itemId) >= amount
end

local function findToolTemplate(templateName)
	local starterPack = game:GetService("StarterPack")
	local replicatedStorage = ReplicatedStorage

	return starterPack:FindFirstChild(templateName)
		or replicatedStorage:FindFirstChild(templateName)
		or replicatedStorage:FindFirstChild("ItemTemplates") and ReplicatedStorage.ItemTemplates:FindFirstChild(templateName)
end

function InventoryService.EquipItem(player, itemId)
	if not validateItemId(itemId) then
		return false
	end

	local definition = getItemDefinition(itemId)
	if definition.Type ~= "Weapon" then
		return false
	end

	if not InventoryService.HasItem(player, itemId, 1) then
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return false
	end

	local templateName = definition.TemplateName or itemId
	local template = findToolTemplate(templateName)
	if not template or not template:IsA("Tool") then
		warn(string.format("[InventoryService] Missing tool template for %s", templateName))
		return false
	end

	for _, child in ipairs(backpack:GetChildren()) do
		if child:IsA("Tool") and child.Name == templateName then
			child:Destroy()
		end
	end

	local tool = template:Clone()
	tool.Parent = backpack
	return true
end

function InventoryService.UseItem(player, itemId)
	if not validateItemId(itemId) or not InventoryService.HasItem(player, itemId, 1) then
		return false
	end

	local definition = getItemDefinition(itemId)

	if definition.Type == "Weapon" then
		return InventoryService.EquipItem(player, itemId)
	end

	return false
end

local function findOwnedTool(player, toolName)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local containers = { backpack, character }

	for _, container in ipairs(containers) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child.Name == toolName then
					return child
				end
			end
		end
	end

	return nil
end

function InventoryService.SellSword(player, toolName)
	if not player or not player.Parent or typeof(toolName) ~= "string" or toolName == "" then
		return false
	end

	local tool = findOwnedTool(player, toolName)
	if not tool or tool.Name == "ClassicSword" or tool:GetAttribute("BossDrop") ~= true then
		return false
	end

	-- You can't sell the sword you're holding. An equipped Tool is parented to the
	-- character; one in the Backpack is not. Refuse, and refresh so the client's
	-- "SELLING..." button resets.
	if player.Character and tool.Parent == player.Character then
		notifyClient(player)
		return false
	end

	-- One price, from one module: tier x rarity x the lesser-pool factor x Blessed x the player's
	-- rebirth gold multiplier -- the same call the pickup prompt made when this sword dropped, and
	-- the same call the inventory tile made to print the number on this button.
	local sellValue = SellValue.ForTool(tool, SellValue.GoldMultFor(player))
	if sellValue <= 0 then
		notifyClient(player)
		return false
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local gold = leaderstats and leaderstats:FindFirstChild("Gold")
	if not gold or not gold:IsA("IntValue") then
		return false
	end

	tool:Destroy()
	gold.Value += sellValue
	notifyClient(player)
	print(string.format("[InventoryService] %s sold [%s] for %d Gold", player.Name, toolName, sellValue))
	return true, sellValue
end

function InventoryService.LoadPlayer(player, savedInventory)
	local inventory = getOrCreateInventory(player)
	table.clear(inventory)

	if typeof(savedInventory) == "table" then
		for itemId, count in pairs(savedInventory) do
			if validateItemId(itemId) and typeof(count) == "number"
				and count == count and math.abs(count) < math.huge and count > 0 then
				local definition = getItemDefinition(itemId)
				inventory[itemId] = math.min(math.floor(count), definition.MaxStack)
			end
		end
	end

	rebuildReplication(player, inventory)
	notifyClient(player)
end

function InventoryService.HasLoaded(player)
	return playerInventories[player] ~= nil
end

function InventoryService.ClearPlayer(player)
	playerInventories[player] = nil

	local folder = getDataFolder(player)
	if folder then
		folder:Destroy()
	end
end

function InventoryService.GiveStarterItems(player)
	InventoryService.AddItem(player, "ClassicSword", 1)
end

return InventoryService
