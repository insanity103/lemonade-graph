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
-- SPAWN SAFE AREA RELIC MERCHANT NPC & STALL
-- ==============================================================================
-- The imported map ships a modeled NPC_RelicMerchant standing on the merchant anchor,
-- but a mesh carries no interaction. Give it the same prompt the block-part stall has,
-- so shopping works identically in both worlds.
local function attachPromptToImportedMerchant(importedMap)
	local existing = Workspace:FindFirstChild("RelicMerchantNPC")
	if existing then existing:Destroy() end

	local anchorPoint = WorldLayout.HUB.MerchantPosition
	local host = Instance.new("Part")
	host.Name = "RelicMerchantPrompt"
	host.Size = Vector3.new(4, 6, 4)
	host.Position = anchorPoint + Vector3.new(0, 3, 0)
	host.Anchored = true
	host.Transparency = 1
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Parent = importedMap

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MerchantPrompt"
	prompt.ActionText = "Browse Relic Swords"
	prompt.ObjectText = "Relic Blacksmith"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = host
	prompt.Triggered:Connect(function(player)
		MERCHANT_ACTION:FireClient(player, "OpenShop")
	end)
	print("[MerchantSystem] Prompt attached to the imported Relic Blacksmith")
	return host
end

local function setupMerchantNPC()
	if WorldLayout.GAMEPLAY_ONLY then
		local actors = require(script.Parent:WaitForChild("GameplayActors"))
		if not WorldLayout.HUB.MerchantPosition then return nil end -- map lacks the marker: shop idle
		local npc = actors.create("RelicMerchantNPC", WorldLayout.HUB.MerchantPosition, Color3.fromRGB(90, 70, 50),
			{ facing = WorldLayout.HUB.MerchantCFrame, title = "Relic Blacksmith", subtitle = "Swords for sale" })
		actors.prompt(npc, "Browse Relic Swords", "Relic Blacksmith").Triggered:Connect(function(player)
			MERCHANT_ACTION:FireClient(player, "OpenShop")
		end)
		return npc
	end
	-- Two bodies on one anchor reads as a bug, so the block-part stall only stands in
	-- while the world is still the procedural fallback.
	local importedMap = Workspace:FindFirstChild("FivefoldSanctuary")
	if importedMap and importedMap:FindFirstChild("NPC_RelicMerchant", true) then
		return attachPromptToImportedMerchant(importedMap)
	end

	local existing = Workspace:FindFirstChild("RelicMerchantNPC")
	if existing then existing:Destroy() end

	local merchantModel = Instance.new("Model")
	merchantModel.Name = "RelicMerchantNPC"

	-- WorldLayout owns both the safe-zone ground height and merchant position.
	local basePos = WorldLayout.HUB.MerchantPosition

	-- Safe Zone Pavilion / Carpet
	local carpet = Instance.new("Part")
	carpet.Name = "Carpet"
	carpet.Size = Vector3.new(14, 0.4, 14)
	carpet.Position = basePos + Vector3.new(0, 0.2, 0)
	carpet.Color = Color3.fromRGB(35, 30, 50)
	carpet.Material = Enum.Material.Fabric
	carpet.Anchored = true
	carpet.CanCollide = true
	carpet.Parent = merchantModel

	-- Counter Table
	local tablePart = Instance.new("Part")
	tablePart.Name = "Counter"
	tablePart.Size = Vector3.new(8, 3, 2)
	tablePart.Position = basePos + Vector3.new(0, 1.5, -2)
	tablePart.Color = Color3.fromRGB(60, 45, 35)
	tablePart.Material = Enum.Material.WoodPlanks
	tablePart.Anchored = true
	tablePart.CanCollide = true
	tablePart.Parent = merchantModel

	-- Anvil decoration
	local anvil = Instance.new("Part")
	anvil.Name = "Anvil"
	anvil.Size = Vector3.new(2, 2.5, 2)
	anvil.Position = basePos + Vector3.new(4.5, 1.25, 0)
	anvil.Color = Color3.fromRGB(40, 40, 45)
	anvil.Material = Enum.Material.DiamondPlate
	anvil.Anchored = true
	anvil.CanCollide = true
	anvil.Parent = merchantModel

	-- NPC Humanoid Model (Blacksmith / Merchant)
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Position = basePos + Vector3.new(0, 3, 0)
	hrp.Transparency = 1
	hrp.Anchored = true
	hrp.CanCollide = false
	hrp.Parent = merchantModel
	merchantModel.PrimaryPart = hrp

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Position = hrp.Position
	torso.Color = Color3.fromRGB(75, 55, 45) -- Leather vest
	torso.Material = Enum.Material.SmoothPlastic
	torso.Anchored = true
	torso.CanCollide = true
	torso.Parent = merchantModel

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.25, 1.25, 1.25)
	head.Position = torso.Position + Vector3.new(0, 1.6, 0)
	head.Color = Color3.fromRGB(220, 180, 140)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.Parent = merchantModel

	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = head

	local leftArm = Instance.new("Part")
	leftArm.Name = "Left Arm"
	leftArm.Size = Vector3.new(1, 2, 1)
	leftArm.Position = torso.Position + Vector3.new(-1.5, 0, 0)
	leftArm.Color = Color3.fromRGB(75, 55, 45)
	leftArm.Anchored = true
	leftArm.CanCollide = false
	leftArm.Parent = merchantModel

	local rightArm = Instance.new("Part")
	rightArm.Name = "Right Arm"
	rightArm.Size = Vector3.new(1, 2, 1)
	rightArm.Position = torso.Position + Vector3.new(1.5, 0, 0)
	rightArm.Color = Color3.fromRGB(75, 55, 45)
	rightArm.Anchored = true
	rightArm.CanCollide = false
	rightArm.Parent = merchantModel

	local leftLeg = Instance.new("Part")
	leftLeg.Name = "Left Leg"
	leftLeg.Size = Vector3.new(1, 2, 1)
	leftLeg.Position = torso.Position + Vector3.new(-0.5, -2, 0)
	leftLeg.Color = Color3.fromRGB(40, 40, 50)
	leftLeg.Anchored = true
	leftLeg.CanCollide = false
	leftLeg.Parent = merchantModel

	local rightLeg = Instance.new("Part")
	rightLeg.Name = "Right Leg"
	rightLeg.Size = Vector3.new(1, 2, 1)
	rightLeg.Position = torso.Position + Vector3.new(0.5, -2, 0)
	rightLeg.Color = Color3.fromRGB(40, 40, 50)
	rightLeg.Anchored = true
	rightLeg.CanCollide = false
	rightLeg.Parent = merchantModel

	-- Overhead Title Tag
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MerchantTag"
	billboard.Size = UDim2.fromOffset(260, 50)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 60
	billboard.Parent = head

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 24)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 16
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
	titleLabel.TextStrokeColor3 = Color3.fromRGB(15, 15, 20)
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.Text = "★ RELIC BLACKSMITH ★"
	titleLabel.Parent = billboard

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0, 18)
	subLabel.Position = UDim2.fromOffset(0, 22)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.GothamMedium
	subLabel.TextSize = 12
	subLabel.TextColor3 = Color3.fromRGB(200, 200, 215)
	subLabel.TextStrokeColor3 = Color3.fromRGB(15, 15, 20)
	subLabel.TextStrokeTransparency = 0.4
	subLabel.Text = "Mystic Boss Swords (Random Mods)"
	subLabel.Parent = billboard

	-- Proximity Prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MerchantPrompt"
	prompt.ActionText = "Browse Relic Swords"
	prompt.ObjectText = "Relic Blacksmith"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = tablePart

	prompt.Triggered:Connect(function(player)
		MERCHANT_ACTION:FireClient(player, "OpenShop")
	end)

	merchantModel.Parent = Workspace
	print("[MerchantSystem] Relic Blacksmith NPC spawned at safe area")
	return merchantModel
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
