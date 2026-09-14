--// HubCampfire  (social gathering spot in the hub safe zone)
-- Creates a campfire with fire/smoke particles, ambient light, and seating.
-- Purely cosmetic — no gameplay function. Players sit on the benches.
local Workspace = game:GetService("Workspace")

local WorldLayout = require(script.Parent:WaitForChild("WorldLayout"))
local hub = WorldLayout.HUB
local features = WorldLayout.HUB_FEATURES or {}

-- Offset from hub center (campfire sits south-east of spawn)
local OFFSET = features.Campfire or Vector3.new(18, 0, 8)
local BASE_POS = Vector3.new(hub.Center.X + OFFSET.X, hub.Center.Y, hub.Center.Z + OFFSET.Z)

local function createPart(properties)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(properties) do
		p[k] = v
	end
	return p
end

local campfire = Instance.new("Model")
campfire.Name = "HubCampfire"
campfire.Parent = Workspace

-- Fire pit (dark stone ring)
local pit = createPart({
	Name = "FirePit",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.8, 4, 4),
	Material = Enum.Material.Slate,
	Color = Color3.fromRGB(50, 45, 40),
	CFrame = CFrame.new(BASE_POS) * CFrame.Angles(0, 0, math.rad(90)),
	Parent = campfire,
})

-- Inner glow (neon core)
local glow = createPart({
	Name = "FireGlow",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.4, 3, 3),
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(255, 100, 20),
	CFrame = CFrame.new(BASE_POS + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	Parent = campfire,
})

-- Fire particles
local fire = Instance.new("ParticleEmitter")
fire.Name = "Fire"
fire.Texture = "rbxassetid://241685484"
fire.Rate = 40
fire.Lifetime = NumberRange.new(0.5, 1.0)
fire.Speed = NumberRange.new(3, 6)
fire.SpreadAngle = Vector2.new(15, 15)
fire.RotSpeed = NumberRange.new(-60, 60)
fire.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1.5),
	NumberSequenceKeypoint.new(0.5, 2.0),
	NumberSequenceKeypoint.new(1, 0),
})
fire.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.2),
	NumberSequenceKeypoint.new(0.7, 0.5),
	NumberSequenceKeypoint.new(1, 1),
})
fire.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 50)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 120, 20)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 50, 10)),
})
fire.LightEmission = 0.8
fire.Parent = glow

-- Smoke particles
local smoke = Instance.new("ParticleEmitter")
smoke.Name = "Smoke"
smoke.Texture = "rbxassetid://241685484"
smoke.Rate = 8
smoke.Lifetime = NumberRange.new(2, 4)
smoke.Speed = NumberRange.new(1, 3)
smoke.SpreadAngle = Vector2.new(20, 20)
smoke.RotSpeed = NumberRange.new(-30, 30)
smoke.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.5),
	NumberSequenceKeypoint.new(0.5, 2.0),
	NumberSequenceKeypoint.new(1, 3.0),
})
smoke.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.5),
	NumberSequenceKeypoint.new(0.5, 0.7),
	NumberSequenceKeypoint.new(1, 1),
})
smoke.Color = ColorSequence.new(Color3.fromRGB(80, 80, 80))
smoke.LightEmission = 0
smoke.Parent = glow

-- Ambient light
local light = Instance.new("PointLight")
light.Name = "CampfireLight"
light.Color = Color3.fromRGB(255, 150, 50)
light.Brightness = 1.5
light.Range = 20
light.Parent = glow

-- Seating (4 benches around the fire)
local BENCH_OFFSETS = {
	{ Vector3.new(0, 0, 4.5), CFrame.Angles(0, 0, 0) },
	{ Vector3.new(0, 0, -4.5), CFrame.Angles(0, math.rad(180), 0) },
	{ Vector3.new(4.5, 0, 0), CFrame.Angles(0, math.rad(90), 0) },
	{ Vector3.new(-4.5, 0, 0), CFrame.Angles(0, math.rad(-90), 0) },
}

for i, bench in ipairs(BENCH_OFFSETS) do
	local seat = createPart({
		Name = "Bench" .. i,
		Size = Vector3.new(4, 0.6, 1.5),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(90, 65, 45),
		CFrame = CFrame.new(BASE_POS + bench[1] + Vector3.new(0, 0.3, 0)) * bench[2],
		Parent = campfire,
	})
	-- Seat back
	local back = createPart({
		Name = "BenchBack" .. i,
		Size = Vector3.new(4, 2, 0.4),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(90, 65, 45),
		CFrame = CFrame.new(BASE_POS + bench[1] + Vector3.new(0, 1.3, -0.75)) * bench[2],
		Parent = campfire,
	})
	-- SeatSurface (invisible Seat instance for sitting)
	local seatSurface = Instance.new("Seat")
	seatSurface.Name = "SitSpot" .. i
	seatSurface.Size = Vector3.new(3.5, 0.4, 1.2)
	seatSurface.Transparency = 1
	seatSurface.Anchored = true
	seatSurface.CanCollide = false
	seatSurface.CFrame = CFrame.new(BASE_POS + bench[1] + Vector3.new(0, 0.7, 0)) * bench[2]
	seatSurface.Parent = campfire
end

-- Log props (2 decorative logs near the fire)
for i, offset in ipairs({ Vector3.new(-1.5, 0.2, 1.5), Vector3.new(1.2, 0.2, -1.8) }) do
	createPart({
		Name = "Log" .. i,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 0.5, 2.5),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(70, 50, 30),
		CFrame = CFrame.new(BASE_POS + offset) * CFrame.Angles(0, math.rad(i * 45), math.rad(90)),
		Parent = campfire,
	})
end

-- Billboard label
local labelGui = Instance.new("BillboardGui")
labelGui.Name = "CampfireLabel"
labelGui.Size = UDim2.fromOffset(200, 30)
labelGui.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
labelGui.AlwaysOnTop = false
labelGui.MaxDistance = 50
labelGui.Parent = glow

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "Campfire"
label.Font = Enum.Font.GothamMedium
label.TextSize = 16
label.TextColor3 = Color3.fromRGB(200, 180, 140)
label.TextStrokeTransparency = 0.5
label.Parent = labelGui

print("[HubCampfire] Social campfire placed in hub")
