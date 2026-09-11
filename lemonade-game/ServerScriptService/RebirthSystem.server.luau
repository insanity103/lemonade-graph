--// RebirthSystem (Fleshed out with Config, Milestones, and Stat Multipliers)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RebirthConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RebirthConfig"))

local REMOTES = ReplicatedStorage:WaitForChild("RemoteEvents")
local REBIRTH_EVENT  = REMOTES:WaitForChild("Rebirth")
local REBIRTH_RESULT = REMOTES:WaitForChild("RebirthResult")

local WIPE_ATTRS = { "Strength", "Health", "Defense", "ExperienceGain" }

local function getOrCreateIntValue(parent, name, value)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("IntValue") then return existing end
	local v = Instance.new("IntValue")
	v.Name = name
	v.Value = value
	v.Parent = parent
	return v
end

local function applyRebirthAttributes(player, rebirths)
	local mults = RebirthConfig.GetMultipliers(rebirths)
	player:SetAttribute("Rebirths", rebirths)
	player:SetAttribute("RebirthRequirement", RebirthConfig.GetRequiredLevel(rebirths))
	player:SetAttribute("RebirthXPMult", mults.xpMult)
	player:SetAttribute("RebirthGoldMult", mults.goldMult)
	player:SetAttribute("RebirthDamageMult", mults.damageMult)
	player:SetAttribute("RebirthHealthMult", mults.healthMult)
	
	-- Calculate milestone bonuses
	local extraKnockback = 0
	local extraHealth = 0
	local extraCrit = 0
	local extraRange = 0
	local critDamageMult = 1.75

	for reqRb, perk in pairs(RebirthConfig.Milestones) do
		if rebirths >= reqRb then
			if perk.knockbackBonus then extraKnockback += perk.knockbackBonus end
			if perk.flatHealthBonus then extraHealth += perk.flatHealthBonus end
			if perk.flatCritBonus then extraCrit += perk.flatCritBonus end
			if perk.flatRangeBonus then extraRange += perk.flatRangeBonus end
			if perk.critDamageMultiplier then critDamageMult = perk.critDamageMultiplier end
		end
	end

	player:SetAttribute("RebirthExtraKnockback", extraKnockback)
	player:SetAttribute("RebirthFlatHealth", extraHealth)
	player:SetAttribute("RebirthExtraCrit", extraCrit)
	player:SetAttribute("RebirthExtraRange", extraRange)
	player:SetAttribute("RebirthCritDamageMult", critDamageMult)
end

local function setupPlayer(player)
	local leaderstats = player:WaitForChild("leaderstats", 10) or player:FindFirstChild("leaderstats")
	local rebirths = 0
	if leaderstats then
		local rb = getOrCreateIntValue(leaderstats, "Rebirths", player:GetAttribute("Rebirths") or 0)
		rebirths = rb.Value
		rb.Changed:Connect(function(v)
			applyRebirthAttributes(player, v)
		end)
	else
		rebirths = player:GetAttribute("Rebirths") or 0
	end
	applyRebirthAttributes(player, rebirths)
end

REBIRTH_EVENT.OnServerEvent:Connect(function(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelStat = leaderstats and leaderstats:FindFirstChild("Level")
	if not levelStat then return end

	local rebirths = player:GetAttribute("Rebirths") or 0
	local need = RebirthConfig.GetRequiredLevel(rebirths)
	if levelStat.Value < need then
		REBIRTH_RESULT:FireClient(player, false, rebirths, need)
		return
	end

	-- Wipe progression
	levelStat.Value = 1
	local xp = leaderstats:FindFirstChild("Experience"); if xp then xp.Value = 0 end
	local gold = leaderstats:FindFirstChild("Gold"); if gold then gold.Value = 0 end
	
	-- Grant the rebirth
	rebirths += 1
	applyRebirthAttributes(player, rebirths)
	
	local rbStat = leaderstats:FindFirstChild("Rebirths")
	if rbStat then rbStat.Value = rebirths end

	-- Starting bonus skill points according to rebirth tier
	local startSkillPoints = RebirthConfig.BONUS_SKILL_POINTS_PER_REBIRTH * rebirths
	if rebirths >= 5 then
		startSkillPoints += 10
	end
	player:SetAttribute("SkillPoints", startSkillPoints)
	player:SetAttribute("WeaponLevel", 0)
	for _, a in ipairs(WIPE_ATTRS) do player:SetAttribute(a, 0) end

	-- Reset character so max health recalculates
	if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
		player.Character:BreakJoints()
	end

	REBIRTH_RESULT:FireClient(player, true, rebirths, RebirthConfig.GetRequiredLevel(rebirths))
	print(string.format("[RebirthSystem] %s rebirthed -> Tier %d (next at Lv %d). Multipliers: +%d%% XP, +%d%% Dmg, +%d%% HP, +%d Bonus SP",
		player.Name, rebirths, RebirthConfig.GetRequiredLevel(rebirths),
		math.floor((RebirthConfig.XP_BOOST_PER_REBIRTH * rebirths) * 100),
		math.floor((RebirthConfig.DAMAGE_BOOST_PER_REBIRTH * rebirths) * 100),
		math.floor((RebirthConfig.HEALTH_BOOST_PER_REBIRTH * rebirths) * 100),
		startSkillPoints
	))
end)

Players.PlayerAdded:Connect(setupPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(setupPlayer, p) end
print("[RebirthSystem] Enhanced Rebirth System with Milestones & Config initialized")
