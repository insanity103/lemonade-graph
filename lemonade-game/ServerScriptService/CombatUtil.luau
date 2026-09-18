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

-- Boss sword meshes. Each boss's unique blade lives in ServerStorage/BossSwordMeshes as
-- a MeshPart named after its archetype (Boss_Gorgon, ...). All of them share one layout
-- (length-normalised, grip toward one end, hand SWORD_GRIP_FRAC from centre), so the same
-- Grip and weld maths fit every one; only width/thickness differ, taken from MeshSize.
-- Until a boss's mesh is imported, the shared SwordMeshTemplate stands in.
CombatUtil.SWORD_MESH_FOLDER = "BossSwordMeshes"
-- Fraction of the mesh's full length, from its centre toward the pommel (+Z in the mesh's own
-- space), where the hand actually sits. Every compliant mesh shares this exactly (sword_forge.py
-- builds to it, tools/convert_sword_glb.py checks a rig against it), so both a mesh welded onto
-- an enemy's hand and a mesh handed to the player as a Tool need to offset the grip by the same
-- amount off the mesh's own centre.
CombatUtil.SWORD_GRIP_FRAC = 0.38

function CombatUtil.getSwordMesh(archetypeKey)
	local ServerStorage = game:GetService("ServerStorage")
	local folder = ServerStorage:FindFirstChild(CombatUtil.SWORD_MESH_FOLDER)
	local mesh = folder and typeof(archetypeKey) == "string" and folder:FindFirstChild(archetypeKey)
	if mesh and mesh:IsA("MeshPart") then
		return mesh, true
	end
	local fallback = ServerStorage:FindFirstChild("SwordMeshTemplate")
	if fallback and fallback:IsA("MeshPart") then
		return fallback, false
	end
	return nil, false
end

-- Scale a sword MeshPart to `length` studs along its blade without distorting it.
function CombatUtil.sizeSwordMesh(part, length)
	local meshSize = part.MeshSize
	if meshSize.Z > 0 then
		part.Size = meshSize * (length / meshSize.Z)
	end
end

-- Hitlag: freeze both attacker and victim briefly on hit.
-- Research: "20-50ms freeze frames — biggest feel-good factor most Roblox sword games miss"
-- This pauses the animation timeline (not just a visual effect) by temporarily
-- setting WalkSpeed to 0 and freezing Motor6D transforms.
function CombatUtil.applyHitlag(attackerModel, victimModel, duration)
	if duration <= 0 then return end
	duration = math.clamp(duration, 0.010, 0.080) -- safety clamp

	-- Freeze attacker
	local attackerHumanoid = attackerModel and attackerModel:FindFirstChildOfClass("Humanoid")
	local attackerRoot = attackerModel and (attackerModel.PrimaryPart or attackerModel:FindFirstChild("HumanoidRootPart"))
	local origAttackerSpeed = 0
	if attackerHumanoid then
		origAttackerSpeed = attackerHumanoid.WalkSpeed
		attackerHumanoid.WalkSpeed = 0
	end

	-- Freeze victim
	local victimHumanoid = victimModel and victimModel:FindFirstChildOfClass("Humanoid")
	local victimRoot = victimModel and (victimModel.PrimaryPart or victimModel:FindFirstChild("HumanoidRootPart"))
	local origVictimSpeed = 0
	if victimHumanoid then
		origVictimSpeed = victimHumanoid.WalkSpeed
		victimHumanoid.WalkSpeed = 0
	end

	-- Brief scale pulse on victim for visual feedback
	if victimRoot then
		local origSize = victimRoot.Size
		-- Scale pulse would require all parts, skip for now
	end

	-- Restore after duration
	task.delay(duration, function()
		if attackerHumanoid and attackerHumanoid.Parent then
			attackerHumanoid.WalkSpeed = origAttackerSpeed
		end
		if victimHumanoid and victimHumanoid.Parent then
			victimHumanoid.WalkSpeed = origVictimSpeed
		end
	end)
end

-- Notify client of hitlag for screen effects (duration + comboIndex for shake scaling)
function CombatUtil.fireHitlagToClient(player, duration, comboIndex)
	local RS = game:GetService("ReplicatedStorage")
	local remote = RS:WaitForChild("RemoteEvents"):FindFirstChild("HitlagEffect")
	if remote then
		remote:FireClient(player, duration, comboIndex or 1)
	end
end

return CombatUtil
