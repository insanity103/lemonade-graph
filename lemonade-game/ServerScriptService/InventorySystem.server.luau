local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local INVENTORY_ACTION_EVENT = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("InventoryAction")

local VALID_ACTIONS = {
	Use = true,
	Equip = true,
	Sell = true,
}
local ACTION_COOLDOWN = 0.1
local MAX_ITEM_ID_LENGTH = 100
local lastActionAt = {}

INVENTORY_ACTION_EVENT.OnServerEvent:Connect(function(player, action, itemId)
	if player:GetAttribute("DataLoaded") ~= true
		or typeof(action) ~= "string"
		or typeof(itemId) ~= "string"
		or #itemId > MAX_ITEM_ID_LENGTH
		or not VALID_ACTIONS[action] then
		return
	end
	local now = tick()
	if now - (lastActionAt[player] or 0) < ACTION_COOLDOWN then
		return
	end
	lastActionAt[player] = now

	if action == "Use" then
		InventoryService.UseItem(player, itemId)
	elseif action == "Equip" then
		InventoryService.EquipItem(player, itemId)
	elseif action == "Sell" then
		InventoryService.SellSword(player, itemId)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastActionAt[player] = nil
	-- Delay so PlayerDataService.Release() can serialize the live inventory first.
	task.delay(5, function()
		InventoryService.ClearPlayer(player)
	end)
end)

print("[InventorySystem] Server-side inventory enabled")
