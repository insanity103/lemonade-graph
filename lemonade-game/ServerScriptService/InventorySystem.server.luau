local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local INVENTORY_ACTION_EVENT = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("InventoryAction")

local VALID_ACTIONS = {
	Use = true,
	Equip = true,
	Sell = true,
}

local function setupPlayer(player)
	-- PlayerDataService (PlayerDataStore) now owns inventory restore + starter items so a
	-- saved inventory is not overwritten on join. Fall back to a fresh inventory only if
	-- persistence never signals ready (its script errored).
	local waited = 0
	while player:GetAttribute("DataLoaded") ~= true and waited < 10 do
		task.wait(0.2)
		waited += 0.2
	end
	if player:GetAttribute("DataLoaded") ~= true then
		InventoryService.LoadPlayer(player, nil)
		InventoryService.GiveStarterItems(player)
	end
end

INVENTORY_ACTION_EVENT.OnServerEvent:Connect(function(player, action, itemId)
	if typeof(action) ~= "string" or typeof(itemId) ~= "string" or not VALID_ACTIONS[action] then
		return
	end

	if action == "Use" then
		InventoryService.UseItem(player, itemId)
	elseif action == "Equip" then
		InventoryService.EquipItem(player, itemId)
	elseif action == "Sell" then
		InventoryService.SellSword(player, itemId)
	end
end)

for _, player in Players:GetPlayers() do
	task.spawn(setupPlayer, player)
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
	-- Delay so PlayerDataService.Release() can serialize the live inventory first.
	task.delay(5, function()
		InventoryService.ClearPlayer(player)
	end)
end)

print("[InventorySystem] Server-side inventory enabled")
