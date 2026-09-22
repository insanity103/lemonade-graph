--// RebirthSystem (Fleshed out with Config, Milestones, and Stat Multipliers)
--
-- A rebirth is BOUGHT: the server checks the cap, the level and the price, debits the price and
-- keeps the change, wipes the level and XP, scales every stat point to RebirthConfig.RETAINED_SHARE
-- and grants the next tier's multipliers. It also publishes, as player attributes, everything the
-- rebirth panel shows -- the requirement, the price, the cap, the kept share and the payback of
-- the next rung at the player's own measured income -- so the client never computes a number the
-- server did not send. Why each rule is what it is: the header of Config.RebirthConfig.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RebirthConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RebirthConfig"))

local REMOTES = ReplicatedStorage:WaitForChild("RemoteEvents")
local REBIRTH_EVENT  = REMOTES:WaitForChild("Rebirth")
local REBIRTH_RESULT = REMOTES:WaitForChild("RebirthResult")
local NOTIFY         = REMOTES:WaitForChild("Notify")

-- The stats a wipe touches. They are not zeroed: each is scaled to RETAINED_SHARE (see the wipe).
local WIPE_ATTRS = { "Strength", "Health", "Defense", "ExperienceGain" }
local REBIRTH_COOLDOWN = 1
-- How often the payback figure is refreshed from LevelingSystem's income measure.
local PAYBACK_REFRESH = 5
local lastRebirthAt = {}

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
	-- The price of the NEXT rebirth, published so anything that wants to show it can read it.
	player:SetAttribute("RebirthGoldCost", RebirthConfig.GetGoldCost(rebirths))
	-- The honest end of the ladder, and what a wipe keeps, published for the panel.
	player:SetAttribute("RebirthMaxed", RebirthConfig.IsMaxed(rebirths))
	player:SetAttribute("RebirthMaxCount", RebirthConfig.MAX_REBIRTHS)
	player:SetAttribute("RebirthKeepShare", RebirthConfig.RETAINED_SHARE)
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

-- PAYBACK, published as RebirthPayback (seconds; -1 = nothing to measure against yet, or maxed).
-- LevelingSystem measures what the player has actually been earning this session and publishes
-- it as SessionGoldPerHour; the maths (price / the extra income the next multiplier adds) is
-- RebirthConfig.PaybackSeconds, so the panel and the server can never disagree.
local function refreshPayback(player)
	local rebirths = player:GetAttribute("Rebirths") or 0
	local rate = tonumber(player:GetAttribute("SessionGoldPerHour")) or 0
	local seconds = RebirthConfig.PaybackSeconds(rebirths, rate)
	local value = seconds and math.floor(seconds) or -1
	if player:GetAttribute("RebirthPayback") ~= value then
		player:SetAttribute("RebirthPayback", value)
	end
end

local function setupPlayer(player)
	local leaderstats = player:WaitForChild("leaderstats", 10) or player:FindFirstChild("leaderstats")
	local rebirths = 0
	if leaderstats then
		local rb = getOrCreateIntValue(leaderstats, "Rebirths", player:GetAttribute("Rebirths") or 0)
		rebirths = rb.Value
		rb.Changed:Connect(function(v)
			applyRebirthAttributes(player, v)
			refreshPayback(player)
		end)
	else
		rebirths = player:GetAttribute("Rebirths") or 0
	end
	applyRebirthAttributes(player, rebirths)
	refreshPayback(player)
	player:GetAttributeChangedSignal("SessionGoldPerHour"):Connect(function()
		refreshPayback(player)
	end)
end

-- A refused rebirth answers with WHY (level / gold / maxed) so the panel can say the right thing.
local function refuse(player, rebirths, reason)
	REBIRTH_RESULT:FireClient(player, false, rebirths, RebirthConfig.GetRequiredLevel(rebirths),
		RebirthConfig.GetGoldCost(rebirths), reason)
end

REBIRTH_EVENT.OnServerEvent:Connect(function(player)
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end
	local now = tick()
	if now - (lastRebirthAt[player] or 0) < REBIRTH_COOLDOWN then
		return
	end
	lastRebirthAt[player] = now
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelStat = leaderstats and leaderstats:FindFirstChild("Level")
	if not levelStat then return end

	local rebirths = player:GetAttribute("Rebirths") or 0
	-- The ladder ends. The handler is the only thing that decides that, and it says so.
	if RebirthConfig.IsMaxed(rebirths) then
		NOTIFY:FireClient(player, string.format("Rebirth %d is the last one. The ladder ends here.", RebirthConfig.MAX_REBIRTHS), "error")
		refuse(player, rebirths, "maxed")
		return
	end
	local need = RebirthConfig.GetRequiredLevel(rebirths)
	if levelStat.Value < need then
		refuse(player, rebirths, "level")
		return
	end

	-- A rebirth is BOUGHT, not confiscated: the price is debited and whatever is left over stays
	-- in the purse. The server is the only thing that reads or writes the price.
	local goldCost = RebirthConfig.GetGoldCost(rebirths)
	local gold = leaderstats:FindFirstChild("Gold")
	local purse = (gold and gold:IsA("IntValue")) and gold.Value or 0
	if purse < goldCost then
		NOTIFY:FireClient(player, string.format("Rebirth %d costs %d Gold. You have %d.",
			rebirths + 1, goldCost, purse), "error")
		refuse(player, rebirths, "gold")
		return
	end
	if gold and gold:IsA("IntValue") then
		gold.Value = purse - goldCost
	end

	-- THE WIPE. Level and XP go; the gold left after the price is the player's; and every stat
	-- point -- spent or not -- is scaled to RETAINED_SHARE rather than zeroed, so the reborn
	-- player can stand in the zones they already own (RebirthConfig explains the share).
	levelStat.Value = 1
	local xp = leaderstats:FindFirstChild("Experience"); if xp then xp.Value = 0 end
	local keep = math.clamp(tonumber(RebirthConfig.RETAINED_SHARE) or 0, 0, 1)
	local keptPoints = 0
	for _, a in ipairs(WIPE_ATTRS) do
		local before = math.max(0, math.floor(tonumber(player:GetAttribute(a)) or 0))
		local after = math.floor(before * keep)
		keptPoints += after
		player:SetAttribute(a, after)
	end
	local unspentBefore = math.max(0, math.floor(tonumber(player:GetAttribute("SkillPoints")) or 0))
	local unspentKept = math.floor(unspentBefore * keep)
	keptPoints += unspentKept

	-- Grant the rebirth
	rebirths += 1
	applyRebirthAttributes(player, rebirths)

	local rbStat = leaderstats:FindFirstChild("Rebirths")
	if rbStat then rbStat.Value = rebirths end

	-- Starting points: the kept share of what was unspent, plus the tier's flat bonus.
	local startSkillPoints = unspentKept + RebirthConfig.StartingSkillPoints(rebirths)
	player:SetAttribute("SkillPoints", startSkillPoints)
	player:SetAttribute("WeaponLevel", 0)
	refreshPayback(player)

	-- Reset character so max health recalculates
	if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
		player.Character:BreakJoints()
	end

	REBIRTH_RESULT:FireClient(player, true, rebirths, RebirthConfig.GetRequiredLevel(rebirths),
		RebirthConfig.GetGoldCost(rebirths), "ok")
	if RebirthConfig.IsMaxed(rebirths) then
		NOTIFY:FireClient(player, string.format("Rebirth %d bought for %d Gold. That was the last rung: the ladder ends here.",
			rebirths, goldCost), "success")
	else
		NOTIFY:FireClient(player, string.format("Rebirth %d bought for %d Gold. Next rebirth: Lv %d, %d Gold.",
			rebirths, goldCost, RebirthConfig.GetRequiredLevel(rebirths), RebirthConfig.GetGoldCost(rebirths)), "success")
	end
	print(string.format("[RebirthSystem] %s rebirthed -> Tier %d for %d gold (next at Lv %d; kept %d%% of the build = %d points). Multipliers: +%d%% XP, +%d%% Dmg, +%d%% HP, +%d Bonus SP",
		player.Name, rebirths, goldCost, RebirthConfig.GetRequiredLevel(rebirths),
		math.floor(keep * 100 + 0.5), keptPoints,
		math.floor((RebirthConfig.XP_BOOST_PER_REBIRTH * rebirths) * 100),
		math.floor((RebirthConfig.DAMAGE_BOOST_PER_REBIRTH * rebirths) * 100),
		math.floor((RebirthConfig.HEALTH_BOOST_PER_REBIRTH * rebirths) * 100),
		startSkillPoints
	))
end)

Players.PlayerAdded:Connect(setupPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(setupPlayer, p) end
Players.PlayerRemoving:Connect(function(player)
	lastRebirthAt[player] = nil
end)

-- The income measure only changes when gold arrives; a player who stops earning would otherwise
-- keep a stale payback on screen, so it is also re-read on a slow tick.
task.spawn(function()
	while true do
		task.wait(PAYBACK_REFRESH)
		for _, player in ipairs(Players:GetPlayers()) do
			refreshPayback(player)
		end
	end
end)
print("[RebirthSystem] Enhanced Rebirth System with Milestones & Config initialized")
