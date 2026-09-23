-- ModuleScript | ReplicatedStorage.PrebuiltNpcRig | Clones the rigged R15 models under
-- ReplicatedStorage.NpcModels (see NpcModels/README in the pack this was built from) and
-- prepares them for the two places that spawn NPCs: GameplayActors (server, stationary shop/quest
-- NPCs) and HubAmbience (client, walking/swinging ambient NPCs). Not every outfit has a prebuilt
-- rig yet -- callers fall back to the classic block rig + NpcOutfits when .clone returns nil.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NpcModels = ReplicatedStorage:WaitForChild("NpcModels")

local PrebuiltNpcRig = {}

PrebuiltNpcRig.RIGS = {
	Blacksmith = "blacksmith_R15",
	QuestMaster = "quest_giver_R15",
	Trainer = "swordsman_R15",
	RebirthKeeper = "sage_priest_R15",
	Vaultkeeper = "storekeeper_R15",
	Farmer = "farmer_R15",
	Baker = "villager_baker_R15",
	Gatherer = "villager_market_woman_R15",
	Elder = "villager_elder_R15",
}

-- Clones the rig for `outfit`, anchoring only the root (the pack's own instructions: leave
-- limbs unanchored so the Motor6Ds keep holding them). Places it at `position` (feet on the
-- ground, matching the block rig's HumanoidRootPart convention of +3 studs up). Returns nil if
-- this outfit has no prebuilt rig, or the model is missing from the project.
function PrebuiltNpcRig.clone(outfit: string, name: string, position: Vector3): Model?
	local rigName = PrebuiltNpcRig.RIGS[outfit]
	local source = rigName and NpcModels:FindFirstChild(rigName)
	if not source then return nil end
	local model = source:Clone()
	model.Name = name
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		warn("[PrebuiltNpcRig] " .. rigName .. " has no HumanoidRootPart")
		model:Destroy()
		return nil
	end
	model.PrimaryPart = root
	model:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	root.Anchored = true
	-- Roblox draws a Humanoid's name and health bar over its head by default; the game has its
	-- own nameplates (GameplayActors) and villagers shouldn't be labelled at all.
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	return model
end

-- Roblox's stock R15 walk animation -- the pack ships no animation of its own (see its README),
-- so ambient movement borrows this well-known public asset rather than shipping a custom one.
local WALK_ANIM_ID = "rbxassetid://913402848"

-- Bundles what HubAmbience needs to animate a prebuilt rig while walking or swinging a weapon:
-- a loopable walk AnimationTrack (for legs, while the caller CFrames the whole model along its
-- path -- no Humanoid:MoveTo involved, matching the existing anchored-root movement system) and
-- the right shoulder joint's rest C0 (there's no baked swing animation, so practice-sword and
-- hammer swings rotate this joint directly, the same way the old system rotated the whole arm
-- part). Returns nil if `model` isn't a prebuilt rig (no Humanoid) -- caller falls back to the
-- block-rig part lookup.
function PrebuiltNpcRig.rigInfo(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local anim = Instance.new("Animation")
	anim.AnimationId = WALK_ANIM_ID
	local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
	local shoulder = model:FindFirstChild("RightShoulder", true)
	return {
		kind = "rig",
		model = model,
		humanoid = humanoid,
		walkTrack = ok and track or nil,
		rightShoulder = shoulder,
		restShoulderC0 = shoulder and shoulder.C0,
		rightArmRef = model:FindFirstChild("RightHand"),
		accessories = {},
	}
end

return PrebuiltNpcRig
