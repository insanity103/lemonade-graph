--// SwordDropSystem  (Unique Boss Weapon drops with randomized prefixes, Blessed slots, Rebirth scaling, and slot-based Auto-Sell)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponModifiers = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponModifiers"))
local RebirthConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RebirthConfig"))
local CombatUtil = require(script.Parent:WaitForChild("CombatUtil"))
local BossWeapons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BossWeapons"))
local BossSwordFactory = require(script.Parent:WaitForChild("BossSwordFactory"))
local REMOTES = ReplicatedStorage:WaitForChild("RemoteEvents")
local DROP_EVENT = REMOTES:WaitForChild("SwordDrop")
local TOGGLE_AUTO_SELL = REMOTES:WaitForChild("ToggleAutoSell")
local AUTO_SELL_NOTICE = REMOTES:WaitForChild("AutoSellNotice")
local GOLD_EVENT = REMOTES:WaitForChild("GoldGain")
local SWORD_LOST_EVENT = REMOTES:WaitForChild("SwordLostOnDeath")

local BOSS_ONLY   = true   -- only rigs flagged Boss by EnemyCombat can drop a sword

-- On death you keep your swords -- the equipped one is moved to the Backpack so it
-- survives respawn -- EXCEPT this small chance it shatters instead.
local DEATH_SWORD_LOSS_CHANCE = 0.02

-- Boss tiers and weapon stats live in ReplicatedStorage/Config/BossWeapons
local BOSS_TIERS = BossWeapons.Tiers

-- Gold value awarded when auto-selling a sword from each boss tier, scaled by the rarity it
-- dropped at (RARITY_SELL_MULT) [TUNING]
local BOSS_SELL_VALUES = {
	[1] = 50,    -- Warden of the Pit pool
	[2] = 150,   -- Frost Revenant pool
	[3] = 450,   -- Infernal Colossus pool
	[4] = 1200,  -- Void Archon pool
	[5] = 3000,  -- Celestial Titan pool
}
local RARITY_SELL_MULT = { Common = 0.5, Uncommon = 1, Rare = 2, Epic = 4, Legendary = 8 }

-- Chance a boss drops anything at all per kill (BossWeapons.DropChance, unchanged from the
-- single-sword roster); rebirths add RebirthConfig's per-class bonus. What drops is then rolled
-- inside BossSwordFactory.build: rarity, which sword of the boss's pool, base stat jitter.
local DEFAULT_DROP = { chance = 0.80, rebirthClass = "Common" }

local PITY_THRESHOLD_BASE = 50 -- [TUNING] guaranteed drop after this many failures
local PITY_PER_REBIRTH = 5    -- [TUNING] threshold increases with rebirth count
local playerPityCount = {} -- [player] = consecutive failed rare drops

local function getWeaponSlots(tool)
	if not tool then return 0 end
	local rarity = tool:GetAttribute("Rarity") or "Common"
	local rarityConfig = WeaponModifiers.RarityConfig[rarity]
	local slots = rarityConfig and rarityConfig.baseSlots or 0
	if tool:GetAttribute("ExtraSlot") == true then
		slots += 1
	end
	return slots
end

local function getEquippedWeaponSlots(player)
	local char = player.Character
	if not char then return 0 end
	return getWeaponSlots(char:FindFirstChildOfClass("Tool"))
end

-- Built by the shared BossSwordFactory (MerchantSystem uses the same builder)
-- A drop rolls its long tail at the killer's live luck (kill streak + rebirths; Lucky Charges
-- are spent at the anvil, not here). Same 1-in-N ladder as the Reforge, see WeaponModifiers.
local function killerLuck(player)
	local streak = tonumber(player:GetAttribute("KillStreak")) or 0
	local at = tonumber(player:GetAttribute("KillStreakAt")) or -math.huge
	if os.clock() - at > WeaponModifiers.Luck.STREAK_WINDOW then streak = 0 end
	local luck = WeaponModifiers.LuckFrom(streak, false, tonumber(player:GetAttribute("Rebirths")) or 0)
	return luck
end

local function makeBossSword(archetypeKey, blessedBonus, luck)
	return BossSwordFactory.build(archetypeKey, { blessedBonus = blessedBonus, luck = luck })
end

local function giveSword(player, archetypeKey, blessedBonus)
	if not player or not player.Parent then
		return false
	end
	local container = player:FindFirstChildOfClass("Backpack") or player.Character
	if not container then
		return false
	end

	local luck = killerLuck(player)
	local tool, mods, fullName, gotExtraSlot, weaponData = makeBossSword(archetypeKey, blessedBonus, luck)
	local droppedTier = BOSS_TIERS[archetypeKey] or 1
	local droppedSlots = #mods + (gotExtraSlot and 1 or 0)
	local autoSellEnabled = player:GetAttribute("AutoSellLowerSwords") == true
	local equippedSlots = getEquippedWeaponSlots(player)

	-- Auto-sell only drops with fewer modifier slots than the equipped weapon.
	if autoSellEnabled and equippedSlots > droppedSlots then
		local baseValue = math.floor((BOSS_SELL_VALUES[droppedTier] or 50) * (RARITY_SELL_MULT[weaponData.rarity] or 1))
		if gotExtraSlot then
			baseValue = math.floor(baseValue * 1.5)
		end
		
		-- Rebirth gold bonus
		local rebirthGoldMultiplier = player:GetAttribute("RebirthGoldMult") or 1
		if typeof(rebirthGoldMultiplier) ~= "number" then rebirthGoldMultiplier = 1 end
		local goldEarned = math.floor(baseValue * math.max(0, rebirthGoldMultiplier))

		local leaderstats = player:FindFirstChild("leaderstats")
		local goldStat = leaderstats and leaderstats:FindFirstChild("Gold")
		if goldStat then
			goldStat.Value += goldEarned
		end

		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			GOLD_EVENT:FireAllClients(hrp.Position + Vector3.new(0, 3, 0), goldEarned)
		end

		AUTO_SELL_NOTICE:FireClient(player, fullName, weaponData.rarity, goldEarned)
		print(string.format("[SwordDropSystem] Auto-sold [%s] for %s (%d Gold awarded) [Equipped Slots %d > Dropped Slots %d]",
			fullName, player.Name, goldEarned, equippedSlots, droppedSlots))
		
		tool:Destroy()
		return
	end

	tool.Parent = container
	
	-- Pass modifiers summary to client toast
	-- Each mod carries its true 1-in-N (oneInText) for the loot card; the whole-roll extras ride
	-- in a sixth argument so older clients keep working.
	for _, mod in ipairs(mods) do
		mod.oneInText = WeaponModifiers.OneInText(mod.p or 0)
		mod.rung = WeaponModifiers.Rungs[mod.tier] and WeaponModifiers.Rungs[mod.tier].name or nil
	end
	-- The sixth argument tells the loot card which pool the sword came from, which rarity variant it
	-- landed as (with the real odds of that rarity) and the base it rolled against the listed one.
	DROP_EVENT:FireClient(player, weaponData.rarity, weaponData.baseMult, fullName, mods, gotExtraSlot,
		{ variant = tool:GetAttribute("Variant"), luck = luck, pool = weaponData.bossName, baseName = weaponData.name,
			listedBase = weaponData.listedBase, rarityOdds = weaponData.rarityOdds, legendary = weaponData.isLegendary })
	print(string.format("[SwordDropSystem] %s obtained [%s] (%s pool, %s, Mult: x%.2f of listed x%.2f, Mods: %d%s)",
		player.Name, fullName, tostring(weaponData.bossName), weaponData.rarity, weaponData.baseMult,
		weaponData.listedBase or weaponData.baseMult, #mods, gotExtraSlot and " [BLESSED!]" or ""))
	return true
end

-- Watch equipped tool -> expose its stats as player attributes for combat systems
local function watchCharacter(player, character)
	local function refresh()
		local tool = character:FindFirstChildWhichIsA("Tool")
		if tool then
			player:SetAttribute("SwordDamageMult", tool:GetAttribute("DamageMult") or 1)
			player:SetAttribute("SwordBonusDamagePct", tool:GetAttribute("BonusDamagePct") or 0)
			player:SetAttribute("SwordCritChance", tool:GetAttribute("CritChance") or 0)
			player:SetAttribute("SwordRangeBonus", tool:GetAttribute("RangeBonus") or 0)
			player:SetAttribute("SwordKnockbackBonus", tool:GetAttribute("KnockbackBonus") or 0)
			player:SetAttribute("EquippedBossTier", tool:GetAttribute("BossTier") or 0)
		else
			player:SetAttribute("SwordDamageMult", 1)
			player:SetAttribute("SwordBonusDamagePct", 0)
			player:SetAttribute("SwordCritChance", 0)
			player:SetAttribute("SwordRangeBonus", 0)
			player:SetAttribute("SwordKnockbackBonus", 0)
			player:SetAttribute("EquippedBossTier", 0)
		end
	end
	character.ChildAdded:Connect(function(c) if c:IsA("Tool") then refresh() end end)
	character.ChildRemoved:Connect(function(c) if c:IsA("Tool") then task.defer(refresh) end end)
	refresh()

	-- On death: the equipped boss sword normally dies with the character. Move it to the
	-- Backpack so it survives -- unless it loses the DEATH_SWORD_LOSS_CHANCE roll, in which
	-- case it shatters for good. Backpack swords are untouched.
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Once(function()
			local bag = player:FindFirstChildOfClass("Backpack")
			if not bag then return end
			for _, tool in ipairs(character:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true then
					local level = player:GetAttribute("Level") or 1
					if level > 8 and math.random() < DEATH_SWORD_LOSS_CHANCE then
						local lostName, lostRarity = tool.Name, tool:GetAttribute("Rarity")
						tool:Destroy()
						SWORD_LOST_EVENT:FireClient(player, lostName, lostRarity)
						print(string.format("[SwordDropSystem] %s died -- equipped sword [%s] shattered (%.0f%% roll)",
							player.Name, lostName, DEATH_SWORD_LOSS_CHANCE * 100))
					else
						tool.Parent = bag
					end
				end
			end
		end)
	end
end

local function bindPlayer(player)
	if player:GetAttribute("AutoSellLowerSwords") == nil then
		player:SetAttribute("AutoSellLowerSwords", false)
	end
	if player.Character then watchCharacter(player, player.Character) end
	player.CharacterAdded:Connect(function(ch) watchCharacter(player, ch) end)
end

-- Toggle Auto-Sell Remote
TOGGLE_AUTO_SELL.OnServerEvent:Connect(function(player, requestedState)
	if requestedState ~= nil and typeof(requestedState) ~= "boolean" then
		return
	end
	local current = player:GetAttribute("AutoSellLowerSwords") == true
	local newState = (requestedState ~= nil) and (requestedState == true) or (not current)
	player:SetAttribute("AutoSellLowerSwords", newState)
	print(string.format("[SwordDropSystem] %s set AutoSellLowerSwords to %s", player.Name, tostring(newState)))
end)

-- Hook enemy deaths (enemies carry Attribute "Enemy" or CollectionService tag "Enemy")
local hooked = setmetatable({}, { __mode = "k" })
local function hook(model)
	if not CombatUtil.isEnemy(model) then return end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or hooked[humanoid] then return end
	hooked[humanoid] = true
	local claimed = false
	humanoid.Died:Connect(function()
		if claimed then return end
		claimed = true
		local creatorTag = humanoid:FindFirstChild("creator")
		local killer = creatorTag and creatorTag.Value
		if not (killer and killer:IsA("Player")) then
			return
		end
		if BOSS_ONLY and model:GetAttribute("Boss") ~= true then
			return
		end

		local rebirths = killer:GetAttribute("Rebirths") or 0
		local archKey = model:GetAttribute("Archetype") or "Boss_Gorgon"
		local dropCfg = BossWeapons.DropChance[archKey] or DEFAULT_DROP
		local rarity = dropCfg.rebirthClass
		local baseDropRate = dropCfg.chance
		
		-- Scale drop chance with rebirths
		local effectiveDropRate = RebirthConfig.GetEffectiveDropChance(baseDropRate, rarity, rebirths)
		
		-- Scale blessed chance bonus (set by RebirthSystem milestone 5)
		local blessedBonus = killer:GetAttribute("RebirthBlessedBonus") or 0

		local rollSuccess = (math.random() <= effectiveDropRate)
		local isRarePlus = (rarity == "Rare" or rarity == "Epic" or rarity == "Legendary")

		if rollSuccess and isRarePlus then
			-- Natural rare+ drop: reset pity and give sword
			playerPityCount[killer] = 0
			giveSword(killer, archKey, blessedBonus)
		else
			-- Failed to produce a rare+ drop
			if rollSuccess then
				-- Still give the non-rare drop
				giveSword(killer, archKey, blessedBonus)
			end

			-- Pity tracking: increment on failed rare drops
			local pity = playerPityCount[killer] or 0
			pity = pity + 1
			playerPityCount[killer] = pity

			local pityRebirths = killer:GetAttribute("Rebirths") or 0
			local pityThreshold = PITY_THRESHOLD_BASE + (pityRebirths * PITY_PER_REBIRTH)

			-- Force a rare drop at pity threshold
			if pity >= pityThreshold then
				-- Override rarity to Rare
				rarity = "Rare"
				playerPityCount[killer] = 0 -- reset pity
				if not rollSuccess then
					-- Roll failed but pity triggered: force the drop
					giveSword(killer, archKey, blessedBonus)
				end
			end
		end
	end)
end

for _, m in ipairs(workspace:GetChildren()) do hook(m) end
workspace.ChildAdded:Connect(function(c) task.defer(hook, c) end)
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Humanoid") then
		local m = d:FindFirstAncestorOfClass("Model")
		if m then task.defer(hook, m) end
	end
end)

Players.PlayerAdded:Connect(bindPlayer)
for _, p in ipairs(Players:GetPlayers()) do bindPlayer(p) end

Players.PlayerRemoving:Connect(function(player)
	playerPityCount[player] = nil
end)

print("[SwordDropSystem] Pity system enabled (base threshold: " .. PITY_THRESHOLD_BASE .. ")")
print("[SwordDropSystem] Boss weapon drop system initialized with Rebirth rarity scaling, Rebirth 5+ Blessed bonuses, and Auto-Sell")
