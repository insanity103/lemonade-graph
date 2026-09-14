-- ModuleScript for server targeting AND damage checks. Marker geometry alone does not enforce safety.
local data = require(script.Parent:WaitForChild("MapAnchors"))
local SafeHub = {}
function SafeHub.contains(position)
	local center = data.Hub.Center
	local dx, dz = position.X - center[1], position.Z - center[3]
	return dx * dx + dz * dz <= data.Hub.SafeRadius ^ 2
		and position.Y >= data.Hub.SafeHeight[1] and position.Y <= data.Hub.SafeHeight[2]
end
function SafeHub.canEnemyAttack(attackerPosition, targetPosition)
	return not SafeHub.contains(attackerPosition) and not SafeHub.contains(targetPosition)
end
return SafeHub
