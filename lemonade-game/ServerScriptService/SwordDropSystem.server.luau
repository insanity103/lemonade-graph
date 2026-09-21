--// SwordDropSystem  (every enemy pays: boss pools, lesser zone pools, pity, luck, and the
--   KEEP-or-SELL prompt the drop opens with)
-- Every rig in the world drops swords now. A boss rolls its own pool; any other enemy rolls its
-- ZONE's lesser pool at the chance its archetype is worth (BossWeapons.NormalDrops). The rule
-- itself lives in ReplicatedStorage/Config/DropRules so the Studio-only measurement stage runs the
-- same code this handler does -- the numbers in the dossier are this file's behaviour, not a
-- restatement of it.
--
-- THE PICKUP PROMPT (replaces auto-sell entirely).
-- There used to be an AutoSellLowerSwords toggle: off by default, buried in the inventory tab, and
-- measured (ledger r00) at +64% lifetime income for the players who found it. A checkbox cannot be
-- worth a third of all the gold in the game. It is gone -- the toggle, the attribute, the notice
-- remote and the silent sale.
--
-- In its place: the sword ALWAYS lands in the Backpack, and the drop reveal carries an OFFER.
-- The player is shown what dropped and exactly what it is worth, and presses KEEP or SELL. The
-- rules this handler enforces, in order of how badly they would hurt if they were wrong:
--   1. THE SERVER OWNS THE DECISION. The price is computed here from Config.SellValue and sent
--      with the drop; the client never computes a payout, it renders the one it was handed.
--   2. ONE SWORD, ONE OUTCOME. Every drop gets a single-use offer id. The handler claims the
--      offer (removes it from the table) BEFORE it touches gold or the Tool, and there is no
--      yield between the claim and the payout, so a player spamming the button resolves exactly
--      once: the second press finds nothing to sell. Selling also re-checks that the Tool is
--      still the one in that player's own Backpack, so a sword cannot be sold twice from two
--      directions, nor sold after it has been vaulted, traded, shattered or handed to the forge.
--   3. IGNORING IT IS FREE. No answer means KEEP: the offer simply expires and the sword stays
--      in the bag. Nothing is ever taken from a player who did not press anything.
--   4. IT NEVER BLOCKS PLAY. Nothing here waits on the client. The Tool is in the bag before the
--      offer is even sent, so the next swing and the next roll are available through the prompt.
--   5. NOTHING IS LOST BY MISSING IT. The inventory SELL button pays the same Config.SellValue
--      price for the same sword, so a missed prompt costs the player nothing but a trip.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponModifiers = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponModifiers"))
local CombatUtil = require(script.Parent:WaitForChild("CombatUtil"))
local BossWeapons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BossWeapons"))
local BossSwordFactory = require(script.Parent:WaitForChild("BossSwordFactory"))
local DropRules = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("DropRules"))
local SellValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SellValue"))
local SwordValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwordValue"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local REMOTES = ReplicatedStorage:WaitForChild("RemoteEvents")
local DROP_EVENT = REMOTES:WaitForChild("SwordDrop")
-- The pickup prompt, both ways down one remote: the client fires (offerId, "SELL" | "KEEP") and
-- the server answers (offerId, "SOLD" | "KEPT" | "DENIED", gold, reason).
local PICKUP_EVENT = REMOTES:WaitForChild("SwordPickup")
local GOLD_EVENT = REMOTES:WaitForChild("GoldGain")
local SWORD_LOST_EVENT = REMOTES:WaitForChild("SwordLostOnDeath")
local NOTIFY = REMOTES:WaitForChild("Notify")

-- On death you keep your swords -- the equipped one is moved to the Backpack so it
-- survives respawn -- EXCEPT this small chance it shatters instead.
local DEATH_SWORD_LOSS_CHANCE = 0.02

-- [TUNING] how long the server-wide Legendary announce waits, so it arrives with the drop
-- reveal's landing (SwordDropToast: wrapped 0.18 s, climb, landing, name readable ~2.4 s).
local ANNOUNCE_DELAY = 2.4

-- What a sword is worth is Config.SellValue's, and only Config.SellValue's: the prompt below, the
-- inventory SELL button and the price the inventory tile quotes all read that one module, so the
-- same sword is worth the same gold whichever way the player sells it.

-- [TUNING] THE PROMPT'S CLOCK. `PROMPT_SECONDS` is what the reveal counts down on screen;
-- `OFFER_SECONDS` is how long the server will still honour the offer, and it is deliberately
-- longer so a laggy press that left the client inside the window is never punished for arriving
-- late. Past that the offer lapses and the sword is simply kept -- which is also what happens if
-- the player never touches it.
local PROMPT_SECONDS = 12
local OFFER_SECONDS = 25
-- A player can have this many offers open at once (fast farming pays faster than a reveal plays).
-- Past it the oldest lapses, kept, so the table can never grow without bound.
local MAX_OPEN_OFFERS = 10
-- Remote guard, not a design gate: presses per player per second, averaged over a short burst.
local PRESS_BURST = 12
local PRESS_WINDOW = 3

-- [player] = { [offerId] = { tool, value, name, rarity, expires } }. An offer is CLAIMED by being
-- removed from this table, which is the whole of the one-sword-one-outcome guarantee: the claim
-- and the payout happen in one uninterrupted stretch of the remote handler, with no yield between
-- them, so two presses cannot both find the same offer.
local offers = setmetatable({}, { __mode = "k" })
local pressLog = setmetatable({}, { __mode = "k" })
local offerSeq = 0

local function offerBag(player)
	local bag = offers[player]
	if not bag then
		bag = {}
		offers[player] = bag
	end
	return bag
end

-- Drop anything that has lapsed (and the oldest, if the player is over the cap). A lapsed offer
-- costs the player nothing: the Tool is already in their Backpack and stays there.
local function pruneOffers(player)
	local bag = offers[player]
	if not bag then return end
	local now = os.clock()
	local live = {}
	for id, offer in pairs(bag) do
		if now > offer.expires or typeof(offer.tool) ~= "Instance" or not offer.tool.Parent then
			bag[id] = nil
		else
			table.insert(live, { id = id, at = offer.expires })
		end
	end
	if #live > MAX_OPEN_OFFERS then
		table.sort(live, function(a, b) return a.at < b.at end)
		for i = 1, #live - MAX_OPEN_OFFERS do
			bag[live[i].id] = nil
		end
	end
end

-- The Tool this offer names, ONLY if it is still the one sitting in this player's own Backpack.
-- Anything else -- equipped, vaulted, traded away, shattered on death, already sold -- is not
-- sellable through the prompt, and the refusal is honest about why.
local function sellableTool(player, offer)
	local tool = offer.tool
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") or not tool.Parent then
		return nil, "gone"
	end
	local bag = player:FindFirstChildOfClass("Backpack")
	if not bag or tool.Parent ~= bag then
		if player.Character and tool.Parent == player.Character then
			return nil, "equipped"
		end
		return nil, "gone"
	end
	return tool
end

-- Open an offer on a sword that has just landed in the bag, and return the id and the price so
-- the drop card can print them. The price is computed HERE, server-side, from Config.SellValue.
local function openOffer(player, tool, weaponData, gotExtraSlot, fullName)
	local value = SellValue.Gold({
		DamageMult = weaponData.baseMult,
		Rarity = weaponData.rarity,
		Lesser = weaponData.lesser == true,
		ExtraSlot = gotExtraSlot == true,
	}, SellValue.GoldMultFor(player))
	if value <= 0 then
		return nil, 0
	end
	pruneOffers(player)
	offerSeq += 1
	local id = string.format("%d-%d", offerSeq, math.floor(os.clock() * 1000) % 1000000)
	offerBag(player)[id] = {
		tool = tool,
		value = value,
		name = fullName,
		rarity = weaponData.rarity,
		expires = os.clock() + OFFER_SECONDS,
	}
	return id, value
end

-- Pity lives in DropRules (the credit rule) and persists in the profile (dropPity /
-- dropRarePity), so it survives leaving the server. These tables are only the live cache for a
-- player whose profile has not finished loading.
local pityCache = {}     -- [player] = drop credit owed
local rarePityCache = {} -- [player] = drops since the last Rare or better

local function getPity(player)
	local stored = PlayerDataService.GetField(player, "dropPity")
	local credit = tonumber(stored) or pityCache[player] or 0
	local storedRare = PlayerDataService.GetField(player, "dropRarePity")
	local rare = tonumber(storedRare) or rarePityCache[player] or 0
	return credit, rare
end

local function setPity(player, credit, rare)
	pityCache[player] = credit
	rarePityCache[player] = rare
	PlayerDataService.SetField(player, "dropPity", credit)
	PlayerDataService.SetField(player, "dropRarePity", rare)
end

-- THE OPENING (DropRules rule 5). Two persisted records decide it:
--   dropKills       lifetime kills this system has rolled for. 0 = the next kill is the profile's
--                   first and pays a sword whatever the coin says; under DropRules.OPENING_KILLS
--                   the lesser pools roll at the opening ramp's multiplied chance.
--   bossFirstDrops  [poolKey] = true once a boss has paid this profile its first sword; until
--                   then that boss's kill always drops.
-- Both are nil until the profile is applied, and a kill made before that rolls as an ordinary
-- kill (no guarantee is spent, no count is written), so a slow DataStore can never eat the first
-- sword. A save written before these fields existed reads as 0 / {}: an old profile's next kill
-- pays a sword once and its next forty ride the ramp, which is a gift, not a loss.
local function openingState(player)
	if not PlayerDataService.IsReady(player) then
		return nil, nil
	end
	local kills = math.max(0, math.floor(tonumber(PlayerDataService.GetField(player, "dropKills")) or 0))
	local record = PlayerDataService.GetField(player, "bossFirstDrops")
	if typeof(record) ~= "table" then record = {} end
	return kills, record
end

-- Built by the shared BossSwordFactory (MerchantSystem uses the same builder)
-- A drop rolls its long tail at the killer's live luck (kill streak + rebirths; Lucky Charges
-- are spent at the anvil, not here). Same 1-in-N ladder as the Reforge, see WeaponModifiers.
local function killerLuck(player)
	local streak = tonumber(player:GetAttribute("KillStreak")) or 0
	local at = tonumber(player:GetAttribute("KillStreakAt")) or -math.huge
	if os.clock() - at > WeaponModifiers.Luck.STREAK_WINDOW then streak = 0 end
	local luck = WeaponModifiers.LuckFrom(streak, false, tonumber(player:GetAttribute("Rebirths")) or 0,
		tonumber(player:GetAttribute("MilestoneLuck")) or 0)
	return luck
end

local function makeBossSword(archetypeKey, blessedBonus, luck, buildOpts)
	local opts = { blessedBonus = blessedBonus, luck = luck }
	for key, value in pairs(buildOpts or {}) do opts[key] = value end
	return BossSwordFactory.build(archetypeKey, opts)
end

-- plan / roll come from DropRules; source is the rig's display name, for the drop card.
local function giveSword(player, archetypeKey, blessedBonus, plan, roll, source)
	if not player or not player.Parent then
		return false
	end
	local container = player:FindFirstChildOfClass("Backpack") or player.Character
	if not container then
		return false
	end

	local luck = killerLuck(player)
	local tool, mods, fullName, gotExtraSlot, weaponData = makeBossSword(archetypeKey, blessedBonus, luck,
		roll and roll.buildOpts or nil)
	local isLesser = weaponData.lesser == true

	-- The sword lands in the bag FIRST, unconditionally. Every path from here is the player's
	-- choice, and the default -- doing nothing -- is the one that already happened.
	tool.Parent = container

	-- ...and the offer opens on it: what it is, what it is worth, one id, one outcome. Only a
	-- sword that actually went to the Backpack gets one -- a player with no Backpack at all
	-- (mid-respawn) is handed the sword and no prompt rather than a prompt that would refuse.
	local offerId, offerValue = nil, 0
	if container:IsA("Backpack") then
		offerId, offerValue = openOffer(player, tool, weaponData, gotExtraSlot, fullName)
	end
	
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
			listedBase = weaponData.listedBase, rarityOdds = weaponData.rarityOdds, legendary = weaponData.isLegendary,
			lesser = isLesser or nil, source = source, rank = plan and plan.rank or nil,
			dropChance = roll and roll.chance or nil, pity = roll and roll.forced or nil,
			-- the opening: "first" (the profile's first kill), "boss" (this boss's first kill for
			-- the profile), and whether the opening ramp multiplied the chance printed above
			guaranteed = roll and roll.guaranteed or nil, opening = roll and roll.opening or nil,
			-- the KEEP-or-SELL offer: the id the client answers with, the price the server will
			-- pay for it, and the countdown the card runs. No offer id means no prompt.
			offerId = offerId, sellValue = offerValue, promptSeconds = offerId and PROMPT_SECONDS or nil })
	-- The top rung tells the whole server, the way a crate opening does. Only the Legendary of a
	-- pool earns it (1 in 2,000 on an ordinary enemy's ladder), so it stays an event. It is held
	-- back ANNOUNCE_DELAY so it lands on the reveal's landing rather than printing the answer
	-- over the owner's head while their ladder is still climbing.
	if weaponData.rarity == "Legendary" then
		local line = string.format("%s pulled %s off %s: LEGENDARY, %s!", player.DisplayName, fullName,
			tostring(source or weaponData.bossName or "a kill"),
			WeaponModifiers.OneInText(weaponData.rarityOdds or 0))
		task.delay(ANNOUNCE_DELAY, function()
			NOTIFY:FireAllClients(line, "success")
		end)
	end
	print(string.format("[SwordDropSystem] %s obtained [%s] (%s pool, %s, %s, Mult: x%.2f of listed x%.2f, Mods: %d%s%s%s)",
		player.Name, fullName, tostring(weaponData.bossName), isLesser and "lesser" or "boss", weaponData.rarity,
		weaponData.baseMult, weaponData.listedBase or weaponData.baseMult, #mods,
		gotExtraSlot and " [BLESSED!]" or "", (roll and roll.forced) and " [PITY]" or "",
		(roll and roll.guaranteed == "first") and " [FIRST KILL]" or ((roll and roll.guaranteed == "boss") and " [FIRST OF THIS BOSS]" or "")))
	return true, weaponData.rarity
end

-- Studio capture only ("Motion:DropReveal", the stage at the foot of EnemyCombat): an ordinary
-- enemy pays a sword about 2% of the time, so filming one card would mean grinding a hundred
-- corpses in front of the camera. This arms ONE forced drop, consumed by the first normal-enemy
-- kill of the session. Only the "did it drop at all" coin is skipped (the roll is re-run with an
-- rng that always pays, so it is a NATURAL drop, not a pity drop): the pool, the rarity ladder,
-- the sword, the jitter and the modifiers are the live ones, and the pity counters are left
-- exactly as they were, so the forced card is never remembered. Inert outside Studio
-- (RunService:IsStudio() is false on live servers) and only while the showcase attribute names
-- this stage; PlayerDataService.Save refuses outright while that attribute is set, so nothing the
-- stage does can reach the real profile.
local RunService = game:GetService("RunService")
local SHOWCASE_DROP_STAGE = "Motion:DropReveal"
local showcaseForceDrop = RunService:IsStudio()
	and workspace:GetAttribute("GuiShowcase") == SHOWCASE_DROP_STAGE
local function alwaysPays() return 0 end
-- ...and the capture is of the TOP of the ladder, so it is filmed with the shipped rarity floor
-- (the same opt drop pity uses) set to Legendary for that one forced roll. An ordinary enemy pays
-- a Legendary 1 in 2,000 drops; the camera cannot wait for it. The odds the card prints are still
-- the real ones (BossSwordFactory reports the rolled rarity's true p), and this is Studio-only.
local SHOWCASE_FORCE_RARITY = "Legendary"


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
					-- The starter is forgeable now (BossDrop = true, see RuntimeBootstrap) but it
					-- never shatters: a player can always be left with a sword.
					if level > 8 and tool:GetAttribute("Starter") ~= true and math.random() < DEATH_SWORD_LOSS_CHANCE then
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

-- ONE STARTER. The StarterPack hands every character a ClassicSword, and a struck starter is
-- saved and rebuilt like any other forgeable sword (PlayerDataService), so a returning player can
-- briefly hold two. Keep the best-rated one (the saved, struck one) and drop the plain copy.
local function dedupeStarter(player)
	local starters = {}
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("Starter") == true then
					table.insert(starters, tool)
				end
			end
		end
	end
	if #starters < 2 then return end
	table.sort(starters, function(a, b)
		local ra, rb = SwordValue.rateTool(a), SwordValue.rateTool(b)
		if ra ~= rb then return ra > rb end
		return (a:GetAttribute("Prefixes") or "") ~= "" and (b:GetAttribute("Prefixes") or "") == ""
	end)
	for i = 2, #starters do
		starters[i]:Destroy()
	end
end

local function bindPlayer(player)
	if player.Character then watchCharacter(player, player.Character) end
	player.CharacterAdded:Connect(function(ch)
		watchCharacter(player, ch)
		task.delay(1, dedupeStarter, player)
		local bag = player:FindFirstChildOfClass("Backpack")
		if bag then
			bag.ChildAdded:Connect(function(child)
				if child:IsA("Tool") and child:GetAttribute("Starter") == true then
					task.defer(dedupeStarter, player)
				end
			end)
		end
	end)
end

-- THE PROMPT'S ONE REMOTE. Everything that can go wrong here is a player pressing SELL more than
-- once, so read the order of the lines below as the guarantee: the offer is taken out of the
-- table (line "bag[offerId] = nil") before anything is paid or destroyed, and nothing between
-- that line and the payout yields. A second press arrives afterwards, finds no offer, and is
-- refused. Two swords are never one offer and one sword is never two payouts.
PICKUP_EVENT.OnServerEvent:Connect(function(player, offerId, choice)
	if typeof(offerId) ~= "string" or #offerId > 40 or #offerId == 0 then
		return
	end
	if choice ~= nil and choice ~= "SELL" and choice ~= "KEEP" then
		return
	end

	-- Remote guard: a held-down button or a script cannot spin this handler.
	local now = os.clock()
	local log = pressLog[player]
	if not log or now - log.at > PRESS_WINDOW then
		log = { at = now, n = 0 }
		pressLog[player] = log
	end
	log.n += 1
	if log.n > PRESS_BURST then
		return
	end

	local bag = offers[player]
	local offer = bag and bag[offerId]
	if not offer then
		PICKUP_EVENT:FireClient(player, offerId, "DENIED", 0, "gone")
		return
	end

	-- KEEP is the default and costs nothing: close the offer and say so.
	if choice ~= "SELL" then
		bag[offerId] = nil
		PICKUP_EVENT:FireClient(player, offerId, "KEPT", 0)
		return
	end

	if now > offer.expires then
		bag[offerId] = nil
		PICKUP_EVENT:FireClient(player, offerId, "DENIED", 0, "expired")
		return
	end

	-- CLAIM. From here the offer no longer exists, whatever happens next.
	bag[offerId] = nil

	local tool, why = sellableTool(player, offer)
	if not tool then
		PICKUP_EVENT:FireClient(player, offerId, "DENIED", 0, why or "gone")
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local goldStat = leaderstats and leaderstats:FindFirstChild("Gold")
	if not goldStat or not goldStat:IsA("IntValue") then
		PICKUP_EVENT:FireClient(player, offerId, "DENIED", 0, "gone")
		return
	end

	local paid = offer.value
	tool:Destroy()
	goldStat.Value += paid

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		GOLD_EVENT:FireAllClients(hrp.Position + Vector3.new(0, 3, 0), paid)
	end
	PICKUP_EVENT:FireClient(player, offerId, "SOLD", paid)
	print(string.format("[SwordDropSystem] %s sold [%s] (%s) at pickup for %d Gold",
		player.Name, tostring(offer.name), tostring(offer.rarity), paid))
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

		-- Which pool this rig pays from, and how often. Every enemy the world spawns has an
		-- answer here; a rig with no archetype at all (a test dummy) still returns nil and is
		-- skipped, which is the only way to get no roll.
		local archKey = model:GetAttribute("Archetype")
		local plan = DropRules.Plan(archKey, model:GetAttribute("Zone"),
			model:GetAttribute("SpawnRole"), model:GetAttribute("Boss") == true)
		if not plan then
			return
		end

		local rebirths = killer:GetAttribute("Rebirths") or 0
		-- Scale blessed chance bonus (set by RebirthSystem milestone 5)
		local blessedBonus = killer:GetAttribute("RebirthBlessedBonus") or 0

		local pity, rarePity = getPity(killer)
		local kills, firstDrops = openingState(killer)
		local firstOfBoss = firstDrops ~= nil and plan.rank == "boss" and firstDrops[plan.poolKey] ~= true
		local roll = DropRules.Roll(plan, { rebirths = rebirths, pity = pity, rarePity = rarePity,
			kills = kills, firstOfBoss = firstOfBoss })
		if kills then
			PlayerDataService.SetField(killer, "dropKills", kills + 1)
		end
		local showcased = false
		if showcaseForceDrop and plan.lesser and not roll.drop then
			showcaseForceDrop = false -- one only, and only in Studio
			showcased = true
			roll = DropRules.Roll(plan, { rebirths = rebirths, pity = pity, rarePity = rarePity, rng = alwaysPays })
			roll.buildOpts = roll.buildOpts or {}
			roll.buildOpts.rarityFloor = SHOWCASE_FORCE_RARITY
			print(string.format("[SwordDropSystem] GuiShowcase: forced this one %s drop for the capture (%.1f%% per kill, floored at %s; pity untouched)",
				tostring(plan.source), roll.chance * 100, SHOWCASE_FORCE_RARITY))
		end
		if not roll.drop then
			setPity(killer, roll.pity, roll.rarePity)
			return
		end

		-- The rig that paid comes back fast (EnemyCombat reads this): the reveal ends with the
		-- next roll already standing there instead of an empty floor.
		model:SetAttribute("DropPaid", true)
		local _, rarity = giveSword(killer, plan.poolKey, blessedBonus, plan, roll, model.Name)
		if showcased then
			return -- the forced card is not the player's: leave both pity counters where they were
		end
		setPity(killer, roll.pity, DropRules.AfterDrop(roll.rarePity, rarity))
		if firstDrops and plan.rank == "boss" and firstDrops[plan.poolKey] ~= true then
			firstDrops[plan.poolKey] = true
			PlayerDataService.SetField(killer, "bossFirstDrops", firstDrops)
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
	pityCache[player] = nil
	rarePityCache[player] = nil
	offers[player] = nil
	pressLog[player] = nil
end)

print(string.format("[SwordDropSystem] Drops live for every enemy: %d boss swords in 5 pools + %d lesser swords in %d zone pools = %d",
	BossWeapons.CountSwords("boss"), BossWeapons.CountSwords("lesser"), #BossWeapons.ZoneOrder, BossWeapons.CountSwords()))
print(string.format("[SwordDropSystem] Pity: %.1f drops of credit owed before a kill is forced, Rare floor after %d drops (both persisted)",
	DropRules.PITY_CREDIT, DropRules.RARE_PITY_DROPS))
print(string.format("[SwordDropSystem] Opening: first kill of a profile %s a sword, kills 1-%d roll lesser pools at x%.1f, first kill of each boss %s a sword (dropKills / bossFirstDrops persisted)",
	DropRules.FIRST_KILL_DROPS and "always pays" or "rolls normally", DropRules.OPENING_KILLS, DropRules.OPENING_CHANCE_MULT,
	DropRules.FIRST_BOSS_KILL_DROPS and "always pays" or "rolls normally"))
print(string.format("[SwordDropSystem] Pickup prompt (auto-sell is gone): every drop is kept unless SELL is pressed; %ds on the card, %ds honoured by the server; a sword sells for %.0f%% of a strike on it x%.2f if lesser (Config.SellValue, the same call the inventory sells at)",
	PROMPT_SECONDS, OFFER_SECONDS, SellValue.SELL_FRACTION * 100, BossWeapons.LESSER_SELL_FACTOR))
