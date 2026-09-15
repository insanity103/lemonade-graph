-- ModuleScript | ServerScriptService.SafeHub | Protect players near the existing spawn.
local layout = require(script.Parent:WaitForChild("WorldLayout"))
local SafeHub = {}
function SafeHub.contains(position: Vector3): boolean
	local center = layout.HUB.Center
	local dx, dz = position.X - center.X, position.Z - center.Z
	return dx * dx + dz * dz <= layout.HUB.SafeRadius ^ 2
end
function SafeHub.canEnemyAttack(attackerPosition: Vector3, targetPosition: Vector3): boolean
	return not SafeHub.contains(attackerPosition) and not SafeHub.contains(targetPosition)
end
return SafeHub
