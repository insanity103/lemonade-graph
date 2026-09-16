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
local merchantModel


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

-- Handle Buy Requests
MERCHANT_ACTION.OnServerEvent:Connect(function(player, action, swordId)
	if action ~= "BuySword" or typeof(swordId) ~= "string" then
		return
	end
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

	-- Deduct gold
	goldStat.Value -= item.price

	-- Purchases never roll Blessed; the builder applies all other randomized mods.
	tool.Parent = backpack

	-- Notify client with sword drop animation toast & purchase result
	DROP_EVENT:FireClient(player, weaponData.rarity, weaponData.baseMult, fullName, mods, gotExtraSlot)
	MERCHANT_ACTION:FireClient(player, "PurchaseResult", true, ("Successfully forged [%s] for %d Gold!"):format(fullName, item.price))

	print(string.format("[MerchantSystem] %s purchased [%s] for %d Gold (0%% Blessed chance, Mods: %d)",
		player.Name, fullName, item.price, #mods))
end)

print("[MerchantSystem] Server merchant system initialized")
