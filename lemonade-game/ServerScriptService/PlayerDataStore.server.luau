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
		-- Hand the save lock back and send the player to rejoin, rather than a blank session that
		-- silently never saves (2026-09-24 playtest, persistence-4).
		warn(string.format("[PlayerDataStore] setup failed for %s: %s", player.Name, tostring(err)))
		player:SetAttribute("DataLoaded", false)
		PlayerDataService.Abandon(player)
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
