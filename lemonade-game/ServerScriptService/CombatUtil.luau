--// CombatUtil  (shared server helpers: enemy identification + weapon appearance)
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local CombatUtil = {}

CombatUtil.ENEMY_TAG = "Enemy"
CombatUtil.ENEMY_ATTRIBUTE = "Enemy"

-- The single definition of "is this model an enemy?". EnemyCombat, LevelingSystem and
-- SwordSystem each used to carry their own copy, and they had drifted: LevelingSystem's
-- lacked the Model type-check and would error when handed a non-Model instance.
function CombatUtil.isEnemy(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return false
	end
	return model:GetAttribute(CombatUtil.ENEMY_ATTRIBUTE) == true
		or CollectionService:HasTag(model, CombatUtil.ENEMY_TAG)
end

-- Boss blades are textured MeshParts, and Enum.Material.Neon replaces the texture with a
-- flat glow -- which threw away the sword artwork on the three highest boss tiers. A Neon
-- request is honoured as a PointLight instead: the texture survives and the blade still
-- reads as glowing. Any other material is applied as asked.
local GLOW_NAME = "BladeGlow"

function CombatUtil.applyWeaponAppearance(part, color, material)
	if not (part and part:IsA("BasePart")) then
		return
	end
	if color then
		part.Color = color
	end
	local textured = part:IsA("MeshPart") and part.TextureID ~= ""
	if material == Enum.Material.Neon and textured then
		part.Material = Enum.Material.Metal
		local glow = part:FindFirstChild(GLOW_NAME)
		if not glow then
			glow = Instance.new("PointLight")
			glow.Name = GLOW_NAME
		end
		glow.Color = color or part.Color
		glow.Brightness = 2.5
		glow.Range = 12
		glow.Shadows = false
		glow.Parent = part
	elseif material then
		local glow = part:FindFirstChild(GLOW_NAME)
		if glow then
			glow:Destroy()
		end
		part.Material = material
	end
end

-- Server combat systems use this before applying damage so a wall or locked boss
-- room door cannot be bypassed by attacking through it. The caller supplies the
-- two combat models to exclude from the raycast.
function CombatUtil.hasLineOfSight(origin, target, ignoredInstances)
	if typeof(origin) ~= "Vector3" or typeof(target) ~= "Vector3" then
		return false
	end

	local direction = target - origin
	if direction.Magnitude < 0.001 then
		return true
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoredInstances or {}
	return Workspace:Raycast(origin, direction, params) == nil
end

return CombatUtil
