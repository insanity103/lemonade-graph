-- Integration snippet, NOT a standalone LocalScript.
-- Insert in MainMenuGui.client.luau after the local setMenuOpen function.
-- It intentionally has access to that script's existing openTab/setMenuOpen locals.
task.spawn(function()
	local stationOpen = remotes:WaitForChild("RebirthStationOpen")
	stationOpen.OnClientEvent:Connect(function()
		setMenuOpen(true)
		openTab("Rebirth")
		headerTitle.Text = "Keeper of Renewal"
	end)
end)
