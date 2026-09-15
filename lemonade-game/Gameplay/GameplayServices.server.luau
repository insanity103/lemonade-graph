-- Script | ServerScriptService | Rebirth and skill respec through characters, without a shrine.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local layout = require(script.Parent:WaitForChild("WorldLayout"))
local actors = require(script.Parent:WaitForChild("GameplayActors"))
if layout.BLANK_SLATE then return end
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local openRebirth = remotes:WaitForChild("RebirthStationOpen")
local rebirth = actors.create("Rebirth Keeper", layout.HUB.RebirthPosition, Color3.fromRGB(80, 130, 180))
actors.prompt(rebirth, "Rebirth").Triggered:Connect(function(player)
	openRebirth:FireClient(player) -- The existing RebirthSystem validates and performs the purchase.
end)

local respec = actors.create("Skill Trainer", layout.HUB.RespecPosition, Color3.fromRGB(120, 80, 150))
local cooldowns = {}
local ATTRIBUTES = {"Strength", "Health", "Defense", "ExperienceGain"}
local BASE_COST, REBIRTH_COST, COOLDOWN = 200, 100, 2 -- [TUNING] Existing respec prices and cooldown.
actors.prompt(respec, "Reset Skills (200 + 100 per rebirth gold)").Triggered:Connect(function(player)
	if player:GetAttribute("DataLoaded") ~= true then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - respec.PrimaryPart.Position).Magnitude > 16 then return end
	local now = os.clock()
	if now - (cooldowns[player] or -math.huge) < COOLDOWN then return end
	cooldowns[player] = now
	local spent = 0
	for _, attr in ipairs(ATTRIBUTES) do spent += player:GetAttribute(attr) or 0 end
	if spent <= 0 then return end
	local stats = player:FindFirstChild("leaderstats")
	local gold = stats and stats:FindFirstChild("Gold")
	local cost = BASE_COST + REBIRTH_COST * (player:GetAttribute("Rebirths") or 0)
	if not gold or gold.Value < cost then return end
	gold.Value -= cost
	for _, attr in ipairs(ATTRIBUTES) do player:SetAttribute(attr, 0) end
	player:SetAttribute("SkillPoints", (player:GetAttribute("SkillPoints") or 0) + spent)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = 100 * (player:GetAttribute("RebirthHealthMult") or 1)
			+ (player:GetAttribute("RebirthFlatHealth") or 0)
		humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth)
	end
end)
Players.PlayerRemoving:Connect(function(player) cooldowns[player] = nil end)
print("[GameplayServices] Rebirth and skill respec ready on the existing baseplate")
