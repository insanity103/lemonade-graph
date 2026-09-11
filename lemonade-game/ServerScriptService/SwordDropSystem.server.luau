--// SwordDropSystem  (Unique Boss Weapon drops with randomized prefixes, Blessed slots, Rebirth scaling, and slot-based Auto-Sell)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local StarterPack = game:GetService("StarterPack")
local ServerStorage = game:GetService("ServerStorage")

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

-- Gold value awarded when auto-selling a sword from each boss tier
local BOSS_SELL_VALUES = {
	[1] = 50,    -- Warlord Greatsword (Uncommon)
	[2] = 150,   -- Frostfang Cleaver (Rare)
	[3] = 450,   -- Inferno Edge (Epic)
	[4] = 1200,  -- Voidrend Blade (Epic)
	[5] = 3000,  -- Astral Eclipse (Legendary)
}

-- Standardized Base Rarity Drop Chances across all bosses:
-- Legendary: 5%, Epic: 10%, Rare: 40%, Uncommon: 60%, Common: 80%
local BASE_RARITY_DROP_CHANCES = {
	Legendary = 0.05,
	Epic      = 0.10,
	Rare      = 0.40,
	Uncommon  = 0.60,
	Common    = 0.80,
}

local BOSS_WEAPONS = BossWeapons.Weapons

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
local function makeBossSword(archetypeKey, blessedBonus)
	return BossSwordFactory.build(archetypeKey, { blessedBonus = blessedBonus })
end

local function giveSword(player, archetypeKey, blessedBonus)
	local tool, mods, fullName, gotExtraSlot, weaponData = makeBossSword(archetypeKey, blessedBonus)
	local droppedTier = BOSS_TIERS[archetypeKey] or 1
	local droppedSlots = #mods + (gotExtraSlot and 1 or 0)
	local autoSellEnabled = player:GetAttribute("AutoSellLowerSwords") == true
	local equippedSlots = getEquippedWeaponSlots(player)

	-- Auto-sell only drops with fewer modifier slots than the equipped weapon.
	if autoSellEnabled and equippedSlots > droppedSlots then
		local baseValue = BOSS_SELL_VALUES[droppedTier] or 50
		if gotExtraSlot then
			baseValue = math.floor(baseValue * 1.5)
		end
		
		-- Rebirth gold bonus
		local rebirths = player:GetAttribute("Rebirths") or 0
		local goldEarned = math.floor(baseValue * (1 + 0.50 * rebirths))

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

	tool.Parent = player:FindFirstChild("Backpack") or player.Character
	
	-- Pass modifiers summary to client toast
	DROP_EVENT:FireClient(player, weaponData.rarity, weaponData.baseMult, fullName, mods, gotExtraSlot)
	print(string.format("[SwordDropSystem] %s obtained [%s] (Mult: x%.2f, Rarity: %s, Mods: %d%s)",
		player.Name, fullName, weaponData.baseMult, weaponData.rarity, #mods, gotExtraSlot and " [BLESSED!]" or ""))
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
					if math.random() < DEATH_SWORD_LOSS_CHANCE then
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
		local weaponData = BOSS_WEAPONS[archKey]
		local rarity = weaponData and weaponData.rarity or "Common"
		local baseDropRate = BASE_RARITY_DROP_CHANCES[rarity] or 0.80
		
		-- Scale drop chance with rebirths
		local effectiveDropRate = RebirthConfig.GetEffectiveDropChance(baseDropRate, rarity, rebirths)
		
		-- Scale blessed chance bonus (extra +5% at Rebirth 5+)
		local blessedBonus = (rebirths >= 5) and (RebirthConfig.REBIRTH_5_BLESSED_BONUS or 0.05) or 0

		if math.random() <= effectiveDropRate then
			giveSword(killer, archKey, blessedBonus)
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

print("[SwordDropSystem] Boss weapon drop system initialized with Rebirth rarity scaling, Rebirth 5+ Blessed bonuses, and Auto-Sell")