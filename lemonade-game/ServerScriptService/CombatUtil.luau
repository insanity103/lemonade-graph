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

-- Hitlag: the GAMEPLAY half of contact. Both fighters' WalkSpeed goes to zero for `duration`, so
-- neither can walk out of the moment the blade lands. Authoritative, and nothing else.
--
-- It does NOT pause any animation, and used to claim it did. The animation half of contact --
-- the attacker's swing clip and the victim's rig both held dead still on the contact frame -- is
-- client work, because that is where the clip's clock and the rig's joints are:
-- ReplicatedStorage/Hitstop holds the attacker (told by fireHitlagToClient below), and
-- EnemyAnimator holds the victim (told by the "HitStop" attribute SwordSystem publishes). The
-- scale pulse that used to be stubbed out here is gone with it; see ComboConfig.HITLAG_SCALE_MULT
-- for why an R6 enemy rig cannot be scaled without lifting its feet off the ground.
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
	local origVictimSpeed = 0
	if victimHumanoid then
		origVictimSpeed = victimHumanoid.WalkSpeed
		victimHumanoid.WalkSpeed = 0
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

-- The one message that tells an attacker's client a hit landed. Everything the client does at
-- contact hangs off it, so a whiff -- which never reaches here -- can never produce any of it.
--
--   duration    the gameplay hitlag, for the existing hit flash (CombatController)
--   comboIndex  scales the camera kick, the shake and the hold (ComboVFX)
--   contact     where the blade met the body, facing the way the blade was travelling; the
--               camera is punched along it. nil for the unarmed path, which has no blade.
--   hold        how long to hold this client's own swing animation. Sent rather than recomputed
--               so the attacker and the victim let go on the same frame.
--   kick        { deg, studs, fov } for the camera punch, or nil to use the combo index's own
--               row of ComboConfig. Only the heavy sends it: its payoff scales with a charge the
--               client cannot see the server's measurement of, and it is bigger than anything
--               in the combo table (7.2 degrees at a full charge against the finisher's 5.0).
function CombatUtil.fireHitlagToClient(player, duration, comboIndex, contact, hold, kick)
	local RS = game:GetService("ReplicatedStorage")
	local remote = RS:WaitForChild("RemoteEvents"):FindFirstChild("HitlagEffect")
	if remote then
		remote:FireClient(player, duration, comboIndex or 1, contact, hold, kick)
	end
end

return CombatUtil
