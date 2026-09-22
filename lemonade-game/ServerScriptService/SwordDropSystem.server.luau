--// SwordDropSystem  (every kill pays SPIN TOKENS; the equipped-sword stat mirror; the one-starter
--   rule; and the KEEP-or-SELL offer machinery)
-- Enemies do not drop swords any more. A kill pays spin tokens (Config.TokenRules): the server
-- credits them to the killer's saved `Tokens` attribute the instant the kill lands, then tells
-- that player's client how the payout splits into pickups (remote TokenDrop) so it can burst them
-- out of the body, magnet them in and fly them to the HUD counter. The count is the server's; the
-- client only animates a number it was handed. Tokens are spent at the spin wheel in town, which
-- is where swords come from now (SpinService rolls the area- and depth-appropriate pool).
--
-- THE KEEP-OR-SELL OFFER (below) predates the tokens: a sword that lands in the Backpack can be
-- offered for sale once, server-priced by Config.SellValue, one id and one outcome. Kills no
-- longer open offers; the machinery stays for whatever hands a player a sword next.
--   1. THE SERVER OWNS THE DECISION. The price is computed here from Config.SellValue.
--   2. ONE SWORD, ONE OUTCOME. The offer is claimed (removed) before any gold moves, no yield.
--   3. IGNORING IT IS FREE. No answer means KEEP.
--   4. IT NEVER BLOCKS PLAY. The Tool is in the bag before the offer is sent.
--   5. NOTHING IS LOST BY MISSING IT. The inventory SELL button pays the same price.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatUtil = require(script.Parent:WaitForChild("CombatUtil"))
local BossWeapons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BossWeapons"))
local TokenRules = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("TokenRules"))
local SellValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SellValue"))
local SwordValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwordValue"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
-- Depth into each area (the spin pool's rotation step) is recorded from this same Died hook.
local SpinService = require(script.Parent:WaitForChild("SpinService"))
local REMOTES = ReplicatedStorage:WaitForChild("RemoteEvents")
local TOKEN_EVENT = REMOTES:WaitForChild("TokenDrop")
-- The pickup prompt, both ways down one remote: the client fires (offerId, "SELL" | "KEEP") and
-- the server answers (offerId, "SOLD" | "KEPT" | "DENIED", gold, reason).
local PICKUP_EVENT = REMOTES:WaitForChild("SwordPickup")
local GOLD_EVENT = REMOTES:WaitForChild("GoldGain")
local SWORD_LOST_EVENT = REMOTES:WaitForChild("SwordLostOnDeath")

-- On death you keep your swords -- the equipped one is moved to the Backpack so it
-- survives respawn -- EXCEPT this small chance it shatters instead.
local DEATH_SWORD_LOSS_CHANCE = 0.02

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
local function openOffer(player, tool, weaponData, fullName)
	local value = SellValue.Gold({
		DamageMult = weaponData.baseMult,
		Rarity = weaponData.rarity,
		Lesser = weaponData.lesser == true,
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

-- A kill's tokens (the Died hook at the foot of this file). Credited to the saved attribute
-- first, then the killer's client is told where the body fell and how the payout splits into
-- pickups. The event is fired BEFORE the attribute moves, so the client has already counted the
-- tokens as "in flight" when the new total arrives and its counter ticks up pickup by pickup
-- instead of jumping.
local function payTokens(player, model)
	-- Before the profile is applied the saved total would overwrite this credit on load, so a
	-- kill in that first second is not paid rather than paid and then silently taken back.
	if not PlayerDataService.IsReady(player) then
		return 0, nil
	end
	local role = TokenRules.RoleOf(model)
	local zone = model:GetAttribute("Zone")
	local total = TokenRules.ForKill(role, nil, typeof(zone) == "string" and zone or nil)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	local origin = root and root.Position or model:GetPivot().Position
	TOKEN_EVENT:FireClient(player, origin, TokenRules.Split(total), total, role)
	local after = math.max(0, math.floor(tonumber(player:GetAttribute("Tokens")) or 0)) + total
	player:SetAttribute("Tokens", after)
	print(string.format("[SwordDropSystem] %s +%d tokens off %s (%s) -> %d", player.Name, total, model.Name, role, after))
	return total, role
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
					-- The starter is a pool sword now (BossDrop = true, see RuntimeBootstrap) but it
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
-- saved and rebuilt like any other pool sword (PlayerDataService), so a returning player can
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
		SpinService.RecordKill(killer, model)
		-- Every enemy pays tokens; a rig with no archetype (a test dummy) pays nothing.
		if model:GetAttribute("Archetype") == nil then
			return
		end
		payTokens(killer, model)
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
	offers[player] = nil
	pressLog[player] = nil
end)

print(string.format("[SwordDropSystem] Kills pay spin tokens (no sword drops): minion %d-%d, elite %d-%d, warden %d-%d, boss %d-%d, burst into up to %d pickups",
	TokenRules.PER_KILL.minion[1], TokenRules.PER_KILL.minion[2], TokenRules.PER_KILL.elite[1], TokenRules.PER_KILL.elite[2],
	TokenRules.PER_KILL.warden[1], TokenRules.PER_KILL.warden[2], TokenRules.PER_KILL.boss[1], TokenRules.PER_KILL.boss[2],
	TokenRules.MAX_PICKUPS))
print(string.format("[SwordDropSystem] KEEP-or-SELL offers: %ds on the card, %ds honoured by the server; a sword sells for %.0f%% x%.2f if lesser (Config.SellValue)",
	PROMPT_SECONDS, OFFER_SECONDS, SellValue.SELL_FRACTION * 100, BossWeapons.LESSER_SELL_FACTOR))
