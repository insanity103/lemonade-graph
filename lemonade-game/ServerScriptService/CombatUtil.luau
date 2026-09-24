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

-- PS99 pass: every sword reads as matte plastic in the hand. Whatever material a look or an
-- archetype asks for (Metal, Ice, the block sword's steel) lands as WEAPON_MATERIAL, so a baked
-- blade texture (TextureID, kept) reads as painted toy plastic instead of PBR steel. Neon on a
-- sword MeshPart is honoured as a PointLight and the part goes plastic like every other (a Neon
-- fill would replace a painted texture, and blow an untextured blade out to a shapeless glow);
-- only the block sword's parts can still be Neon as a material. A SurfaceAppearance (the metalness/roughness maps
-- tools/sword_forge.py bakes into the glTF material) overrides the part material entirely, so one
-- without its own colour map is dropped; one that carries the colour map is kept, since losing the
-- paint is worse than a little sheen. The sword GLBs are not regenerated: runtime override only.
CombatUtil.WEAPON_MATERIAL = Enum.Material.SmoothPlastic
local GLOW_NAME = "BladeGlow"

local function stripPbr(part)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("SurfaceAppearance") then
			local ok, colorMap = pcall(function()
				return child.ColorMap
			end)
			if not (ok and typeof(colorMap) == "string" and colorMap ~= "") then
				child:Destroy()
			end
		end
	end
end

function CombatUtil.applyWeaponAppearance(part, color, material)
	if not (part and part:IsA("BasePart")) then
		return
	end
	if color then
		part.Color = color
	end
	stripPbr(part)
	-- Neon on a sword MeshPart is always a PointLight over matte plastic, textured or not: a flat
	-- Neon fill blows the untextured spin relics (Lodestone Edge, Blue Hour Shard, First Spark,
	-- Quiet Star, Little Dawn) out to one shapeless glow (Studio check, 2026-09-24). Block-sword
	-- parts keep Neon as a material; no block look uses it today.
	local glows = part:IsA("MeshPart")
	if material == Enum.Material.Neon and glows then
		part.Material = CombatUtil.WEAPON_MATERIAL
		local glow = part:FindFirstChild(GLOW_NAME)
		if not glow then
			glow = Instance.new("PointLight")
			glow.Name = GLOW_NAME
		end
		glow.Color = color or part.Color
		-- Round 2 of the sword gauntlet: at 2.5 / 12 the Legendary's coral light tinted its own
		-- sky-white blade pink from a hand's length away, and the critics read "a washed pink
		-- sliver". A glow, not a floodlight.
		glow.Brightness = 1.0
		glow.Range = 8
		glow.Shadows = false
		glow.Parent = part
	else
		local glow = part:FindFirstChild(GLOW_NAME)
		if glow then
			glow:Destroy()
		end
		part.Material = if material == Enum.Material.Neon then Enum.Material.Neon else CombatUtil.WEAPON_MATERIAL
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
-- One freeze per humanoid, however many hits land on it at once. The old version saved WalkSpeed,
-- set 0 and restored the saved value after `duration`, per call. One swing through two enemies calls
-- it twice in the same instant: the second call saved the 0 the first had just written, and its
-- restore -- which runs last -- put the 0 back. The player stood frozen until sprint wrote a new
-- speed (2026-09-24 playtest: "the player gets stuck and can only get unstuck by using sprint").
-- Now the first freeze remembers the real speed, later ones only push the end time out, and the
-- one whose end is the latest restores it, once.
--
-- "The real speed" skips a swing's step-in brake (SwordSystem): while it holds the character at a
-- fraction of its speed it leaves the full value in SPEED_BEFORE_BRAKE, and a freeze that starts
-- inside the brake restores that rather than the braked fraction.
CombatUtil.SPEED_BEFORE_BRAKE = "SpeedBeforeBrake"
local frozen = setmetatable({}, { __mode = "k" })

local function freeze(humanoid: Humanoid?, duration: number)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local f = frozen[humanoid]
	if not f then
		local speed = humanoid:GetAttribute(CombatUtil.SPEED_BEFORE_BRAKE) or humanoid.WalkSpeed
		if typeof(speed) ~= "number" or speed <= 0 then
			speed = game:GetService("StarterPlayer").CharacterWalkSpeed
		end
		f = { speed = speed, endsAt = 0 }
		frozen[humanoid] = f
	end
	f.endsAt = math.max(f.endsAt, os.clock() + duration)
	humanoid.WalkSpeed = 0
	task.delay(duration, function()
		if frozen[humanoid] ~= f or os.clock() < f.endsAt - 0.005 then
			return -- a later hit extended the freeze; its own timer restores
		end
		frozen[humanoid] = nil
		if humanoid.Parent and humanoid.WalkSpeed == 0 then
			humanoid.WalkSpeed = f.speed
		end
	end)
end

function CombatUtil.applyHitlag(attackerModel, victimModel, duration)
	if duration <= 0 then return end
	duration = math.clamp(duration, 0.010, 0.080) -- safety clamp
	freeze(attackerModel and attackerModel:FindFirstChildOfClass("Humanoid"), duration)
	freeze(victimModel and victimModel:FindFirstChildOfClass("Humanoid"), duration)
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
--   damage      what this hit took off the target, so the attacker's HitStreakGui can total its
--               own landed hits (the DamageNumber remote goes to every player, so it cannot).
function CombatUtil.fireHitlagToClient(player, duration, comboIndex, contact, hold, kick, damage)
	local RS = game:GetService("ReplicatedStorage")
	local remote = RS:WaitForChild("RemoteEvents"):FindFirstChild("HitlagEffect")
	if remote then
		remote:FireClient(player, duration, comboIndex or 1, contact, hold, kick, damage)
	end
end

return CombatUtil
