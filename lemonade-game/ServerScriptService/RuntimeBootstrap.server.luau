-- Repairs runtime instances that are not represented by ordinary Luau source files.
-- This keeps a fresh Rojo sync playable even if Studio-only instances were removed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

local REMOTE_NAMES = {
	"AutoSellNotice",
	"BossDoorNotice",
	"ComboUpdate",
	"DamageNumber",
	"EnemyAttack",
	"GoldGain",
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
	"SwordDrop",
	"SwordLostOnDeath",
	"ToggleAutoSell",
	"ReforgeAction",
	"TradeAction",
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
local steel = Color3.fromRGB(185, 192, 200)
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
	if backpack and not backpack:FindFirstChild("ClassicSword") then
		sword:Clone().Parent = backpack
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
