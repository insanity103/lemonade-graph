--// CombatUtil  (shared server helpers: enemy identification + weapon appearance)
local CollectionService = game:GetService("CollectionService")

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
		part.Material = material
	end
end

return CombatUtil
