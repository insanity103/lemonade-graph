-- Repairs runtime instances that are not represented by ordinary Luau source files.
-- This keeps a fresh Rojo sync playable even if Studio-only instances were removed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

local REMOTE_NAMES = {
	"AdminAction", -- dev/bug-testing mod menu; see AdminSystem.server.luau + AdminGui.client.luau
	"BossDoorNotice",
	"ComboUpdate",
	"DamageNumber",
	"EnemyAttack",
	"GoldGain",
	"HeavyAttack", -- the charged heavy: client -> server, "press" / "release" / "cancel" and
	               -- nothing else. The server timestamps both edges on its own clock, so the
	               -- charge time (and therefore the damage) is never a number a client sends.
	               -- SwordSystem + ReplicatedStorage/HeavyCharge.
	"HitlagEffect",
	"InventoryAction",
	"InventoryUpdated",
	"LevelUpBurst",
	"MerchantAction",
	"Notify",
	"QuestAccept",
	"QuestComplete",
	"QuestReward",
	"QuestUpdate",
	"Rebirth",
	"RebirthResult",
	"RebirthStationOpen",
	"SpendSkillPoint",
	"SpinAction", -- the town spin wheel: client -> server ("Spin", count); server -> client
	              -- ("Result", payload) / ("Refused", reason). SpinSystem + SpinStation.client.
	"SwordDrop",
	"SwordLostOnDeath",
	"SwordPickup", -- KEEP-or-SELL at the moment a sword drops (SwordDropSystem + SwordDropToast).
	               -- Replaced ToggleAutoSell + AutoSellNotice when auto-sell was removed.
	"TokenDrop", -- server -> killer: a kill's spin tokens, already credited, split into pickups
	             -- (SwordDropSystem + TokenDrops.client). Replaced the kill's sword drop.
	"TradeAction",
	"UpgradeAction", -- the town Upgrade Stall: client -> server ("Buy", id) / ("State"); server -> client
	                 -- ("Open"|"State"|"Bought"|"Refused", payload). GameplayServices + UpgradeShop.
	"VaultAction",
	"XPGain",
}

local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "RemoteEvents"
	remotes.Parent = ReplicatedStorage
end

for _, name in ipairs(REMOTE_NAMES) do
	if not remotes:FindFirstChild(name) then
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = remotes
	end
end

local sword = StarterPack:FindFirstChild("ClassicSword")
if not sword or not sword:IsA("Tool") then
	if sword then sword:Destroy() end
	sword = Instance.new("Tool")
	sword.Name = "ClassicSword"
	sword.Parent = StarterPack
end
sword.RequiresHandle = true
sword.CanBeDropped = false
sword.Grip = CFrame.Angles(-math.pi / 2, 0, 0)

-- The starter is a real pool sword (see BossWeapons.Starter): a Common of the opening zone's tier
-- at x1.00 with no prefix. Stamped on the StarterPack template so every copy the engine
-- hands out carries it; a copy already in a Backpack (Studio's first test player) is stamped by
-- repairPlayerSword below. Only attributes the copy does not already carry are written, so a
-- saved starter rebuilt by PlayerDataService keeps its roll.
local STARTER_ATTRS = {
	BossDrop = true, Starter = true, Rarity = "Common", DamageMult = 1.0, PoolBase = 1.0, BossTier = 1,
	PoolKey = "IronLowlands", Lesser = true, BaseWeaponName = "Classic Sword", Prefixes = "",
	BonusDamagePct = 0, CritChance = 0, RangeBonus = 0, KnockbackBonus = 0,
}
local function stampStarter(tool)
	for key, value in pairs(STARTER_ATTRS) do
		if tool:GetAttribute(key) == nil then
			tool:SetAttribute(key, value)
		end
	end
end
stampStarter(sword)

local function ensurePart(name, className, size, color, material, shape)
	local part = sword:FindFirstChild(name)
	if part and not part:IsA(className) then
		part:Destroy()
		part = nil
	end
	if not part then
		part = Instance.new(className)
		part.Name = name
		part.Parent = sword
	end
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	if shape and part:IsA("Part") then part.Shape = shape end
	return part
end

local leather = Color3.fromRGB(92, 66, 50)
local bronze = Color3.fromRGB(170, 124, 60)
-- THE BLADE IS DARK, and that is a legibility decision, not a mood one. Round 5's blind read of
-- the chain said it straight: "the blade is pale against pale sand, white sky and white buildings,
-- so the arc does not read at speed". Pale steel (185, 192, 200) was within a few points of the
-- village's sand, its plaster and its sky in every filmed frame, so the one thing a fighting game
-- has to show -- where the edge is, right now -- washed out at exactly the speeds the swing is
-- judged at. Deepwoken's greatsword is near-black for the same reason. Blued steel reads as a
-- dark, hard silhouette against every bright surface in Lemonade, and the sword keeps its identity
-- in the parts that carry it: the bronze guard and pommel and the lemon ribbon off the tip are
-- untouched, so the weapon is still a warm, friendly one -- it is only the cutting edge that is
-- now visible.
local steel = Color3.fromRGB(56, 64, 78)
local handle = ensurePart("Handle", "Part", Vector3.new(0.32, 0.32, 1.10), leather, Enum.Material.SmoothPlastic, Enum.PartType.Block)
local pommel = ensurePart("Pommel", "Part", Vector3.new(0.44, 0.44, 0.44), bronze, Enum.Material.Metal, Enum.PartType.Ball)
local guard = ensurePart("Guard", "Part", Vector3.new(1.30, 0.26, 0.32), bronze, Enum.Material.Metal, Enum.PartType.Block)
local blade = ensurePart("Blade", "Part", Vector3.new(0.22, 0.60, 2.60), steel, Enum.Material.Metal, Enum.PartType.Block)
local tipUpper = ensurePart("TipUpper", "WedgePart", Vector3.new(0.22, 0.30, 0.50), steel, Enum.Material.Metal)
local tipLower = ensurePart("TipLower", "WedgePart", Vector3.new(0.22, 0.30, 0.50), steel, Enum.Material.Metal)

local function ensureWeld(name, part1, c0)
	local weld = handle:FindFirstChild(name)
	if weld and not weld:IsA("Weld") then weld:Destroy(); weld = nil end
	if not weld then
		weld = Instance.new("Weld")
		weld.Name = name
		weld.Parent = handle
	end
	weld.Part0 = handle
	weld.Part1 = part1
	weld.C0 = c0
end

ensureWeld("WeldPommel", pommel, CFrame.new(0, 0, 0.66))
ensureWeld("WeldGuard", guard, CFrame.new(0, 0, -0.66))
ensureWeld("WeldBlade", blade, CFrame.new(0, 0, -2.09))
ensureWeld("WeldTipUpper", tipUpper, CFrame.new(0, 0.15, -3.64))
ensureWeld("WeldTipLower", tipLower, CFrame.new(0, -0.15, -3.64) * CFrame.Angles(0, 0, math.pi))

local sounds = {
	SwordSlash = { 12222216, 0.7 },
	SwordLunge = { 12222208, 0.6 },
	Unsheath = { 12222225, 1.0 },
}
for name, settings in pairs(sounds) do
	local sound = handle:FindFirstChild(name)
	if not sound or not sound:IsA("Sound") then
		if sound then sound:Destroy() end
		sound = Instance.new("Sound")
		sound.Name = name
		sound.Parent = handle
	end
	sound.SoundId = "rbxassetid://" .. settings[1]
	sound.Volume = settings[2]
end

-- Studio can create the first test player before this script repairs StarterPack.
local function repairPlayerSword(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	local held = backpack:FindFirstChild("ClassicSword")
	if not held then
		sword:Clone().Parent = backpack
	elseif held:IsA("Tool") then
		stampStarter(held)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.defer(repairPlayerSword, player)
	end)
	task.defer(repairPlayerSword, player)
end)
for _, player in ipairs(Players:GetPlayers()) do repairPlayerSword(player) end

print("[RuntimeBootstrap] Required remotes and starter sword are ready")
