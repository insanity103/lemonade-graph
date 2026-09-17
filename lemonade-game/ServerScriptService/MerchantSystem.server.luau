--// MerchantSystem (Safe Area Relic Merchant with 0% Blessed chance random rolling)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MerchantConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MerchantConfig"))
local BossSwordFactory = require(script.Parent:WaitForChild("BossSwordFactory"))
local WorldLayout = require(script.Parent:WaitForChild("WorldLayout"))
WorldLayout.EnsureBuilt()
if WorldLayout.BLANK_SLATE then return end

local REMOTES = ReplicatedStorage:WaitForChild("RemoteEvents")
local MERCHANT_ACTION = REMOTES:WaitForChild("MerchantAction")
local DROP_EVENT = REMOTES:WaitForChild("SwordDrop")

local PURCHASE_DISTANCE = 16
local PURCHASE_INTERVAL = 0.35
local merchantModel
local lastPurchaseAt = {}
local purchaseInFlight = {}

-- Built by the shared BossSwordFactory; purchases never roll a Blessed extra slot
local function makePurchasedSword(archetypeKey)
	return BossSwordFactory.build(archetypeKey, { allowBlessed = false })
end

-- ==============================================================================
-- SPAWN SAFE AREA RELIC MERCHANT NPC
-- ==============================================================================
local function setupMerchantNPC()
	if WorldLayout.GAMEPLAY_ONLY then
		local actors = require(script.Parent:WaitForChild("GameplayActors"))
		if not WorldLayout.HUB.MerchantPosition then return nil end -- map lacks the marker: shop idle
		local npc = actors.create("RelicMerchantNPC", WorldLayout.HUB.MerchantPosition, Color3.fromRGB(90, 70, 50),
			{ facing = WorldLayout.HUB.MerchantCFrame, title = "Relic Blacksmith", subtitle = "Swords for sale", outfit = "Blacksmith" })
		actors.prompt(npc, "Browse Relic Swords", "Relic Blacksmith").Triggered:Connect(function(player)
			MERCHANT_ACTION:FireClient(player, "OpenShop")
		end)
		return npc
	end
	return nil
end

merchantModel = setupMerchantNPC()

local function isNearMerchant(player)
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local merchantRoot = merchantModel and merchantModel.PrimaryPart
	return playerRoot ~= nil and merchantRoot ~= nil
		and (playerRoot.Position - merchantRoot.Position).Magnitude <= PURCHASE_DISTANCE
end

local function handlePurchase(player, swordId)
	if player:GetAttribute("DataLoaded") ~= true then
		MERCHANT_ACTION:FireClient(player, "PurchaseResult", false, "Your data is still loading.")
		return
	end
	if not isNearMerchant(player) then
		MERCHANT_ACTION:FireClient(player, "PurchaseResult", false, "Move closer to the Relic Blacksmith to buy this.")
		return
	end

	local item = MerchantConfig.GetItem(swordId)
	if not item then
		MERCHANT_ACTION:FireClient(player, "PurchaseResult", false, "Invalid weapon selection.")
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local goldStat = leaderstats and leaderstats:FindFirstChild("Gold")
	if not goldStat or not goldStat:IsA("IntValue") then
		MERCHANT_ACTION:FireClient(player, "PurchaseResult", false, "Gold data error.")
		return
	end

	if goldStat.Value < item.price then
		MERCHANT_ACTION:FireClient(player, "PurchaseResult", false, ("Not enough Gold! You need %d Gold."):format(item.price))
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		MERCHANT_ACTION:FireClient(player, "PurchaseResult", false, "Your inventory is not ready yet.")
		return
	end

	-- Build before debiting currency so an invalid template or configuration can
	-- never consume Gold without delivering a sword.
	local built, tool, mods, fullName, gotExtraSlot, weaponData = pcall(makePurchasedSword, swordId)
	if not built or not tool then
		warn(string.format("[MerchantSystem] Could not build %s for %s: %s", swordId, player.Name, tostring(tool)))
		MERCHANT_ACTION:FireClient(player, "PurchaseResult", false, "That weapon is temporarily unavailable.")
		return
	end

	-- Revalidate mutable state after building. If the builder ever yields, another
	-- purchase must not be able to spend the same balance or buy from a distance.
	if not player.Parent or not isNearMerchant(player) or goldStat.Value < item.price then
		tool:Destroy()
		MERCHANT_ACTION:FireClient(player, "PurchaseResult", false, "Purchase conditions changed. Please try again.")
		return
	end

	goldStat.Value -= item.price
	tool.Parent = backpack

	DROP_EVENT:FireClient(player, weaponData.rarity, weaponData.baseMult, fullName, mods, gotExtraSlot)
	MERCHANT_ACTION:FireClient(player, "PurchaseResult", true, ("Successfully forged [%s] for %d Gold!"):format(fullName, item.price))

	print(string.format("[MerchantSystem] %s purchased [%s] for %d Gold (0%% Blessed chance, Mods: %d)",
		player.Name, fullName, item.price, #mods))
end

-- Handle Buy Requests. Client remotes are untrusted: rate-limit them and serialize
-- purchases per player so request spam cannot run multiple builds concurrently.
MERCHANT_ACTION.OnServerEvent:Connect(function(player, action, swordId)
	if action ~= "BuySword" or typeof(swordId) ~= "string" then return end

	local now = os.clock()
	if purchaseInFlight[player] or now - (lastPurchaseAt[player] or -math.huge) < PURCHASE_INTERVAL then
		return
	end
	lastPurchaseAt[player] = now
	purchaseInFlight[player] = true

	local ok, err = pcall(handlePurchase, player, swordId)
	purchaseInFlight[player] = nil
	if not ok then
		warn(string.format("[MerchantSystem] Purchase failed for %s: %s", player.Name, tostring(err)))
		MERCHANT_ACTION:FireClient(player, "PurchaseResult", false, "The purchase failed. Please try again.")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastPurchaseAt[player] = nil
	purchaseInFlight[player] = nil
end)

print("[MerchantSystem] Server merchant system initialized")
