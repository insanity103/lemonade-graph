--// IronFightStage  (Studio-only capture stage: an Iron Lowlands fight with a boss sword in hand)
--
-- Set in edit mode, before pressing Play:
--     workspace:SetAttribute("GuiShowcase", "Motion:IronFight")
--     workspace:SetAttribute("GuiShowcaseSword", "Boss_Gorgon/Pit Sovereign")   -- optional
-- Runs only through GuiShowcase.stage, which is inert outside Studio and unless the showcase
-- attribute names this stage.
--
-- Stands the player in front of a live quarry bandit where the world spawned it (the real desert,
-- the real light), puts a sword built by the real BossSwordFactory in their hand in the guard
-- pose, and frames both from the sword side. GuiShowcaseSword is "<pool key>/<sword name>"; the
-- default is the Warden of the Pit's Legendary. Nothing touches player data: the Tool is tracked
-- and destroyed when the stage returns, and the bandit is only held still for the capture.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then
	return
end

local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))
local BossSwordFactory = require(script.Parent:WaitForChild("BossSwordFactory"))

local HOLD = 90 -- [TUNING] seconds the frame stays up for the capture
local GAP = 7 -- [TUNING] studs between the player and the bandit
local DEFAULT_SWORD = "Boss_Gorgon/Pit Sovereign"
local FOES = { IronBerserker = true, IronSquire = true }

-- The bandit nearest this point in the open basin, so every run frames the same spot (round 2
-- picked whichever rig came first and landed in the oasis reeds).
local FIGHT_AT = Vector3.new(0, 0, 300) -- [TUNING]
local function findFoe(): Model?
	local best, bestY = nil, -math.huge
	for _, model in ipairs(workspace:GetDescendants()) do
		if model:IsA("Model") and FOES[model:GetAttribute("Archetype") or ""] then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local hrp = model:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and hrp then
				-- Prefer a Berserker (the bigger silhouette), then the one nearest FIGHT_AT.
				local score = (model:GetAttribute("Archetype") == "IronBerserker" and 1000 or 0)
					- (hrp.Position * Vector3.new(1, 0, 1) - FIGHT_AT).Magnitude
				if score > bestY then
					best, bestY = model, score
				end
			end
		end
	end
	return best
end

GuiShowcase.stage("IronFight", function(ctx)
	local foe = findFoe()
	if not foe then
		warn("[IronFightStage] no live quarry bandit found")
		return
	end
	local hrp = foe.HumanoidRootPart :: BasePart
	-- Hold the bandit and its pack still for the capture (round 1: the pack walked into the lens
	-- and killed the player before the frame), and shield the player: enemy hits go through
	-- Humanoid:TakeDamage, which an (invisible) ForceField blocks.
	local held = {}
	for _, model in ipairs(workspace:GetDescendants()) do
		local root = model:IsA("Model") and model:GetAttribute("Archetype") and model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - hrp.Position).Magnitude < 60 and not root.Anchored then
			root.Anchored = true
			table.insert(held, root)
		end
	end
	local shield = Instance.new("ForceField")
	shield.Visible = false
	shield.Parent = ctx.character
	ctx.track(shield)

	-- The player: GAP studs in front of the bandit, facing it.
	local foeAt = hrp.Position
	local facing = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	facing = if facing.Magnitude > 0.01 then facing.Unit else Vector3.new(0, 0, -1)
	local playerAt = foeAt + facing * GAP + Vector3.new(0, 0.5, 0)
	ctx.place(CFrame.lookAt(playerAt, Vector3.new(foeAt.X, playerAt.Y, foeAt.Z)))
	hrp.CFrame = CFrame.lookAt(foeAt, Vector3.new(playerAt.X, foeAt.Y, playerAt.Z))

	-- The sword: built by the real factory, equipped through the Humanoid.
	local spec = workspace:GetAttribute("GuiShowcaseSword")
	spec = if typeof(spec) == "string" and spec ~= "" then spec else DEFAULT_SWORD
	local poolKey, swordName = string.match(spec, "^([^/]+)/(.+)$")
	local tool = BossSwordFactory.build(poolKey or "Boss_Gorgon", { sword = swordName, rarity = "Legendary", jitter = false })
	if tool then
		ctx.track(tool)
		local humanoid = ctx.character:FindFirstChildOfClass("Humanoid")
		for _, held in ipairs(ctx.character:GetChildren()) do
			if held:IsA("Tool") then held.Parent = ctx.player:FindFirstChildOfClass("Backpack") end
		end
		tool.Parent = ctx.player:FindFirstChildOfClass("Backpack")
		if humanoid then humanoid:EquipTool(tool) end
	end
	task.wait(0.6)
	ctx.hold()

	-- The frame: from the sword side (the player's right), a little behind and above, aimed
	-- between the two so the blade, the hand and the bandit are all in shot.
	local root = ctx.root.CFrame
	local mid = (root.Position + foeAt) / 2 + Vector3.new(0, 1.2, 0)
	ctx.camera(CFrame.lookAt(mid + root.RightVector * 9 + root.LookVector * -2.5 + Vector3.new(0, 2.6, 0), mid))
	print(string.format("[IronFightStage] %s vs %s, sword %s", ctx.player.Name, foe:GetAttribute("Archetype"), spec))

	task.wait(HOLD)
	ctx.camera(nil)
	for _, root in ipairs(held) do
		if root.Parent then root.Anchored = false end
	end
end)
