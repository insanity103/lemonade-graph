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
function SafeHub.canEnemyAttack(attackerPosition: Vector3, targetPosition: Vector3): boolean
	return not SafeHub.contains(attackerPosition) and not SafeHub.contains(targetPosition)
end
return SafeHub
