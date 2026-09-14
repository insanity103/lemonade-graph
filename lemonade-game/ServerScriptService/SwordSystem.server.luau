local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Sword"))
local DAMAGE_EVENT = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("DamageNumber")

local CombatUtil = require(script.Parent:WaitForChild("CombatUtil"))

local ComboConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ComboConfig"))

local CREATOR_TAG_NAME = "creator"

local playerCombo = {} -- [player] = {count=0, lastHitTime=0, lastEndTime=0}
local connectedTools = setmetatable({}, { __mode = "k" })

local isEnemy = CombatUtil.isEnemy

local function calculateDamage(player, tool, comboIndex)
	local strength = player:GetAttribute("Strength") or 0
	local weaponLevel = player:GetAttribute("WeaponLevel") or 0
	
	local swordMult = player:GetAttribute("SwordDamageMult") or (tool and tool:GetAttribute("DamageMult") or 1)
	local bonusPct = player:GetAttribute("SwordBonusDamagePct") or (tool and tool:GetAttribute("BonusDamagePct") or 0)
	local critChance = (player:GetAttribute("SwordCritChance") or (tool and tool:GetAttribute("CritChance") or 0))
		+ (player:GetAttribute("RebirthExtraCrit") or 0)
	local rebirthDmgMult = player:GetAttribute("RebirthDamageMult") or 1
	local critDamageMult = player:GetAttribute("RebirthCritDamageMult") or 1.75

	local base = (Config.BaseDamage + Config.StrengthDamagePerPoint * strength)
	local comboMult = ComboConfig.COMBO_DAMAGE_MULT[comboIndex] or 1.0
	local withMults = base * swordMult * (1 + bonusPct) * (1 + Config.WeaponDamagePerLevel * weaponLevel) * rebirthDmgMult * comboMult
	
	local isCrit = math.random() < math.clamp(critChance, 0, 1)
	if isCrit then
		withMults = withMults * critDamageMult
	end

	return math.max(1, math.floor(withMults)), isCrit
end

local function applyKnockback(enemyModel, playerHrp, knockbackForce)
	if knockbackForce <= 0 then return end
	local enemyHrp = enemyModel.PrimaryPart or enemyModel:FindFirstChild("HumanoidRootPart")
	if not enemyHrp then return end
	
	local dir = (enemyHrp.Position - playerHrp.Position)
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude > 0.001 then
		dir = dir.Unit
	else
		dir = playerHrp.CFrame.LookVector
	end

	-- Apply physics impulse
	local impulse = (dir * knockbackForce + Vector3.new(0, knockbackForce * 0.25, 0)) * math.max(1, enemyHrp.AssemblyMass)
	enemyHrp:ApplyImpulse(impulse)
end

local function applyDamage(enemyModel, player, tool, playerHrp, comboIndex, character)
	local humanoid = enemyModel:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local creatorTag = humanoid:FindFirstChild(CREATOR_TAG_NAME)
	if not creatorTag then
		creatorTag = Instance.new("ObjectValue")
		creatorTag.Name = CREATOR_TAG_NAME
		creatorTag.Parent = humanoid
	end
	creatorTag.Value = player

	local damage, isCrit = calculateDamage(player, tool, comboIndex)
	humanoid:TakeDamage(damage)

	-- Apply hitlag: freeze both attacker and victim briefly
	local hitlagDuration = ComboConfig.HITLAG_DURATION[comboIndex] or ComboConfig.HITLAG_DURATION[1]
	CombatUtil.applyHitlag(character, enemyModel, hitlagDuration)
	-- Notify client for screen shake (pass comboIndex so shake scales)
	CombatUtil.fireHitlagToClient(player, hitlagDuration, comboIndex)

	local knockback = (player:GetAttribute("SwordKnockbackBonus") or (tool and tool:GetAttribute("KnockbackBonus") or 0))
		+ (player:GetAttribute("RebirthExtraKnockback") or 0)
	if playerHrp and knockback > 0 then
		applyKnockback(enemyModel, playerHrp, knockback)
	end

	local root = enemyModel.PrimaryPart or enemyModel:FindFirstChild("HumanoidRootPart")
	if root then
		DAMAGE_EVENT:FireAllClients(root.Position, damage, isCrit and "crit" or "outgoing")
	end
end

local function performSwingWithCombo(player, character, tool, comboIndex)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local rangeBonus = (player:GetAttribute("SwordRangeBonus") or (tool and tool:GetAttribute("RangeBonus") or 0))
		+ (player:GetAttribute("RebirthExtraRange") or 0)
	local hitboxSize = Config.HitboxSize + Vector3.new(rangeBonus, rangeBonus * 0.5, rangeBonus)
	local hitboxOffset = Config.HitboxOffset * CFrame.new(0, 0, -rangeBonus * 0.5)

	local params = OverlapParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local parts = Workspace:GetPartBoundsInBox(
		rootPart.CFrame * hitboxOffset,
		hitboxSize,
		params
	)

	local damaged = {}
	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		local enemyRoot = model and (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart"))
		if model and enemyRoot and isEnemy(model) and not damaged[model]
			and CombatUtil.hasLineOfSight(rootPart.Position, enemyRoot.Position, { character, model }) then
			damaged[model] = true
			applyDamage(model, player, tool, rootPart, comboIndex, character)
		end
	end
end

local function performComboSwing(player, character, tool)
	local now = tick()
	local state = playerCombo[player]
	if not state then
		state = {count=0, lastHitTime=0, lastEndTime=0}
		playerCombo[player] = state
	end

	-- Check if combo should reset
	if now - state.lastHitTime > ComboConfig.COMBO_RESET_TIME then
		state.count = 0
	end

	-- Check endlag — player must wait for current endlag to finish
	if state.lastEndTime > 0 and now < state.lastEndTime then
		return -- still in endlag
	end

	-- Advance combo
	state.count = state.count + 1
	if state.count > ComboConfig.MAX_COMBO then
		state.count = 1
	end
	state.lastHitTime = now

	-- Calculate endlag for this hit
	local endlag = ComboConfig.ENDLAG[state.count] or 0.2
	state.lastEndTime = now + endlag

	-- Fire combo update to client
	local comboRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):FindFirstChild("ComboUpdate")
	if comboRemote then
		comboRemote:FireClient(player, state.count, endlag)
	end

	-- Perform the actual swing with combo index
	performSwingWithCombo(player, character, tool, state.count)
end

local function setupTool(character, tool)
	if connectedTools[tool] then
		return
	end
	connectedTools[tool] = true
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local handle = tool:FindFirstChild("Handle")
	if handle then
		handle.CanTouch = false
	end

	tool.Activated:Connect(function()
		performComboSwing(player, character, tool)
	end)
end

local function setupCharacter(character)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			setupTool(character, child)
		end
	end

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			setupTool(character, child)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		setupCharacter(player.Character)
	end
	player.CharacterAdded:Connect(setupCharacter)
end
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(setupCharacter)
end)

Players.PlayerRemoving:Connect(function(player)
	playerCombo[player] = nil
end)

-- Reset combo on death/respawn
local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Connect(function()
			if playerCombo[player] then
				playerCombo[player].count = 0
				playerCombo[player].lastHitTime = 0
				playerCombo[player].lastEndTime = 0
			end
			-- Notify client to reset combo HUD
			local comboRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):FindFirstChild("ComboUpdate")
			if comboRemote then
				comboRemote:FireClient(player, 0, 0)
			end
		end)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		task.spawn(onCharacterAdded, player, char)
	end)
end
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		task.spawn(onCharacterAdded, player, char)
	end)
end)

print("[SwordSystem] 5-hit combo system with hitlag enabled")
