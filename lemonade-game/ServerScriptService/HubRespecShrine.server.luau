--// HubRespecShrine  (stat reset NPC — spend gold to reallocate skill points)
-- Player interacts with the shrine, pays gold, and all spent skill points
-- are returned. Cost scales with rebirth count to prevent abuse.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local WorldLayout = require(script.Parent:WaitForChild("WorldLayout"))
if WorldLayout.BLANK_SLATE then return end
local hub = WorldLayout.HUB
local features = WorldLayout.HUB_FEATURES or {}

local OFFSET = features.RespecShrine or Vector3.new(-8, 0, 12)
local BASE_POS = Vector3.new(hub.Center.X + OFFSET.X, hub.Center.Y, hub.Center.Z + OFFSET.Z)

local BASE_COST = 200       -- gold cost at rebirth 0
local COST_PER_REBIRTH = 100 -- additional cost per rebirth level
local RESPEC_COOLDOWN = 2   -- seconds between respec attempts
local lastRespecAt = {}

local RESPEC_ATTRS = { "Strength", "Health", "Defense", "ExperienceGain" }

local shrine = Instance.new("Model")
shrine.Name = "RespecShrine"
shrine.Parent = Workspace

-- Shrine pedestal
local pedestal = Instance.new("Part")
pedestal.Name = "Pedestal"
pedestal.Size = Vector3.new(4, 1, 4)
pedestal.Material = Enum.Material.Marble
pedestal.Color = Color3.fromRGB(180, 170, 200)
pedestal.Anchored = true
pedestal.TopSurface = Enum.SurfaceType.Smooth
pedestal.BottomSurface = Enum.SurfaceType.Smooth
pedestal.CFrame = CFrame.new(BASE_POS + Vector3.new(0, 0.5, 0))
pedestal.Parent = shrine

-- Crystal orb (the respec focus)
local orb = Instance.new("Part")
orb.Name = "CrystalOrb"
orb.Shape = Enum.PartType.Ball
orb.Size = Vector3.new(2.5, 2.5, 2.5)
orb.Material = Enum.Material.Neon
orb.Color = Color3.fromRGB(120, 80, 255)
orb.Anchored = true
orb.CanCollide = false
orb.CFrame = CFrame.new(BASE_POS + Vector3.new(0, 3.5, 0))
orb.Parent = shrine

-- Orb glow
local orbLight = Instance.new("PointLight")
orbLight.Color = Color3.fromRGB(120, 80, 255)
orbLight.Brightness = 1.2
orbLight.Range = 12
orbLight.Parent = orb

-- Orb particles (soft purple sparkles)
local sparkle = Instance.new("ParticleEmitter")
sparkle.Texture = "rbxassetid://241685484"
sparkle.Rate = 12
sparkle.Lifetime = NumberRange.new(1, 2)
sparkle.Speed = NumberRange.new(0.5, 1.5)
sparkle.SpreadAngle = Vector2.new(180, 180)
sparkle.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.3),
	NumberSequenceKeypoint.new(0.5, 0.5),
	NumberSequenceKeypoint.new(1, 0),
})
sparkle.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.3),
	NumberSequenceKeypoint.new(1, 1),
})
sparkle.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 140, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 40, 200)),
})
sparkle.LightEmission = 0.9
sparkle.Parent = orb

-- NPC body (robed figure next to the pedestal)
local npcModel = Instance.new("Model")
npcModel.Name = "RespecNPC"
npcModel.Parent = shrine

local hrp = Instance.new("Part")
hrp.Name = "HumanoidRootPart"
hrp.Size = Vector3.new(2, 2, 1)
hrp.Transparency = 1
hrp.CanCollide = false
hrp.Anchored = true
hrp.CFrame = CFrame.new(BASE_POS + Vector3.new(3, 1, 0))
hrp.Parent = npcModel
npcModel.PrimaryPart = hrp

local torso = Instance.new("Part")
torso.Name = "Torso"
torso.Size = Vector3.new(2, 2, 1)
torso.Material = Enum.Material.SmoothPlastic
torso.Color = Color3.fromRGB(50, 30, 80)
torso.Anchored = true
torso.CanCollide = false
torso.CFrame = CFrame.new(BASE_POS + Vector3.new(3, 2, 0))
torso.Parent = npcModel

local head = Instance.new("Part")
head.Name = "Head"
head.Size = Vector3.new(1.2, 1.2, 1.2)
head.Material = Enum.Material.SmoothPlastic
head.Color = Color3.fromRGB(160, 140, 120)
head.Anchored = true
head.CanCollide = false
head.CFrame = CFrame.new(BASE_POS + Vector3.new(3, 3.5, 0))
head.Parent = npcModel
local headMesh = Instance.new("SpecialMesh")
headMesh.MeshType = Enum.MeshType.Head
headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
headMesh.Parent = head

-- Robe (wide body piece)
local robe = Instance.new("Part")
robe.Name = "Robe"
robe.Size = Vector3.new(3, 3.5, 2)
robe.Material = Enum.Material.SmoothPlastic
robe.Color = Color3.fromRGB(40, 20, 70)
robe.Anchored = true
robe.CanCollide = false
robe.CFrame = CFrame.new(BASE_POS + Vector3.new(3, 1.75, 0))
robe.Parent = npcModel

-- Overhead tag
local tagGui = Instance.new("BillboardGui")
tagGui.Size = UDim2.fromOffset(200, 50)
tagGui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
tagGui.AlwaysOnTop = false
tagGui.MaxDistance = 50
tagGui.Parent = head

local tagTitle = Instance.new("TextLabel")
tagTitle.Size = UDim2.new(1, 0, 0.5, 0)
tagTitle.BackgroundTransparency = 1
tagTitle.Text = "MYSTIC SHRINE"
tagTitle.Font = Enum.Font.GothamBold
tagTitle.TextSize = 14
tagTitle.TextColor3 = Color3.fromRGB(180, 140, 255)
tagTitle.TextStrokeTransparency = 0.5
tagTitle.Parent = tagGui

local tagSubtitle = Instance.new("TextLabel")
tagSubtitle.Size = UDim2.new(1, 0, 0.5, 0)
tagSubtitle.Position = UDim2.new(0, 0, 0.5, 0)
tagSubtitle.BackgroundTransparency = 1
tagSubtitle.Text = "Reset Skill Points"
tagSubtitle.Font = Enum.Font.GothamMedium
tagSubtitle.TextSize = 12
tagSubtitle.TextColor3 = Color3.fromRGB(180, 175, 165)
tagSubtitle.TextStrokeTransparency = 0.7
tagSubtitle.Parent = tagGui

-- ProximityPrompt (on the pedestal)
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "RespecPrompt"
prompt.ActionText = "Respec Skills"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = false
prompt.Parent = pedestal

prompt.Triggered:Connect(function(player)
	if player:GetAttribute("DataLoaded") ~= true then return end

	local now = tick()
	if now - (lastRespecAt[player] or 0) < RESPEC_COOLDOWN then return end
	lastRespecAt[player] = now

	-- Count spent points
	local totalSpent = 0
	for _, attr in ipairs(RESPEC_ATTRS) do
		totalSpent = totalSpent + (player:GetAttribute(attr) or 0)
	end

	if totalSpent <= 0 then
		-- Nothing to reset
		return
	end

	-- Check gold
	local rebirths = player:GetAttribute("Rebirths") or 0
	local cost = BASE_COST + COST_PER_REBIRTH * rebirths
	local leaderstats = player:FindFirstChild("leaderstats")
	local gold = leaderstats and leaderstats:FindFirstChild("Gold")
	if not gold or gold.Value < cost then
		return
	end

	-- Deduct gold
	gold.Value = gold.Value - cost

	-- Reset all skill attributes to 0
	for _, attr in ipairs(RESPEC_ATTRS) do
		player:SetAttribute(attr, 0)
	end

	-- Return spent points as skill points
	local currentPoints = player:GetAttribute("SkillPoints") or 0
	player:SetAttribute("SkillPoints", currentPoints + totalSpent)

	-- Recompute max health (defense reset also needed but handled by LevelingSystem on next tick)
	-- Force health recalculation by setting Health attribute to 0 then immediately to current
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local baseHealth = 100
		local rebirthHealthMult = player:GetAttribute("RebirthHealthMult") or 1
		local flatHealth = player:GetAttribute("RebirthFlatHealth") or 0
		humanoid.MaxHealth = baseHealth * rebirthHealthMult + flatHealth
		humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth)
	end

	print(string.format("[HubRespecShrine] %s respecced: %d points returned for %d Gold (RB%d)",
		player.Name, totalSpent, cost, rebirths))
end)

-- Cleanup on player leave
Players.PlayerRemoving:Connect(function(player)
	lastRespecAt[player] = nil
end)

print("[HubRespecShrine] Stat respec shrine placed in hub")
