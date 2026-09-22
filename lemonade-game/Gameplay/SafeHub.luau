-- ModuleScript | ServerScriptService.SafeHub | Protect players near the spawn (map: every SafeZones volume).
local layout = require(script.Parent:WaitForChild("WorldLayout"))
local SafeHub = {}
function SafeHub.contains(position: Vector3): boolean
	local zones = layout.SAFE_ZONES
	if zones then
		for _, zone in ipairs(zones) do
			local p = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				return true
			end
		end
		return false
	end
	local center = layout.HUB.Center
	local dx, dz = position.X - center.X, position.Z - center.Z
	return dx * dx + dz * dz <= layout.HUB.SafeRadius ^ 2
end
-- Is this player's living character standing in town? The spin wheel spends tokens only here
-- (SpinSystem): tokens are earned out in the field and spent in town, never both at once.
function SafeHub.playerInside(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root ~= nil and humanoid ~= nil and humanoid.Health > 0 and SafeHub.contains(root.Position)
end
function SafeHub.canEnemyAttack(attackerPosition: Vector3, targetPosition: Vector3): boolean
	return not SafeHub.contains(attackerPosition) and not SafeHub.contains(targetPosition)
end
return SafeHub
