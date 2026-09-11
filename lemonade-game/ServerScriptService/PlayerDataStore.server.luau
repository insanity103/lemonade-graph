--// PlayerDataStore  (drives PlayerDataService off the player lifecycle:
--   load+apply on join, save+release on leave, periodic autosave, save-all on shutdown)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local SaveConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("SaveConfig"))

local function onPlayerAdded(player)
	player:SetAttribute("DataLoaded", false)
	local ok, err = pcall(function()
		PlayerDataService.Load(player)
		if player.Parent then
			PlayerDataService.Apply(player)
		end
	end)
	if not ok then
		warn(string.format("[PlayerDataStore] setup failed for %s: %s", player.Name, tostring(err)))
		local recovered, fallbackErr = pcall(function()
			PlayerDataService.StartFallback(player)
		end)
		if not recovered then
			warn(string.format("[PlayerDataStore] fallback failed for %s: %s", player.Name, tostring(fallbackErr)))
			player:SetAttribute("DataLoaded", false)
		end
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataService.Release(player)
end)

task.spawn(function()
	while true do
		task.wait(SaveConfig.AUTOSAVE_INTERVAL)
		PlayerDataService.SaveAll(false)
	end
end)

game:BindToClose(function()
	PlayerDataService.SaveAll(true)
	if not RunService:IsStudio() then
		task.wait(3)
	end
end)

print(string.format("[PlayerDataStore] persistence online (store %s, autosave %ds)",
	SaveConfig.DATASTORE_NAME, SaveConfig.AUTOSAVE_INTERVAL))
