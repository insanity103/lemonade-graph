-- LocalScript | StarterPlayerScripts.GlacierAmbience | Map project.
-- The Frostbound Glacier's weather and sky: soft snow drifting down round the camera, an aurora of
-- slow-waving ribbons over the northern peaks, and a glint on every crystal cluster. All of it is
-- client-side decoration, parented to the camera or to invisible anchors (no collision, no
-- queries), and all of it idles while the camera is outside the Glacier.
local RunService = game:GetService("RunService")

local map = workspace:WaitForChild("LemonadeMap", 30)
if not map then
	return
end
local glacier = map:WaitForChild("FrostboundGlacier", 60)
if not glacier then
	return
end

local function inGlacier(p: Vector3): boolean -- west of the hub's Frostbound gate, north of the desert
	return p.X < -104 and p.Z < 96
end

local holder = Instance.new("Folder")
holder.Name = "GlacierAmbience"

local function anchor(size: Vector3, cf: CFrame): BasePart
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Parent = holder
	return p
end

-- ── Snowfall: a wide sheet of emitters over the camera ─────────────────────────────────────────
local SNOW_ABOVE = 34 -- [TUNING] studs over the camera the flakes start
local snowSheet = anchor(Vector3.new(150, 1, 150), CFrame.new())
local snow = Instance.new("ParticleEmitter")
snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
snow.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
snow.LightEmission = 0.3
snow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.25) })
snow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.15),
	NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) })
snow.Lifetime = NumberRange.new(6, 9)
snow.Rate = 70 -- [TUNING]
snow.Speed = NumberRange.new(4, 7)
snow.EmissionDirection = Enum.NormalId.Bottom
snow.SpreadAngle = Vector2.new(18, 18)
snow.Acceleration = Vector3.new(1.2, 0, 0.6) -- a light wind off the peaks
snow.RotSpeed = NumberRange.new(-60, 60)
snow.Parent = snowSheet

-- ── Aurora: three curtains of thin glowing ribbons over the northern peaks ──────────────────────
local AURORA = { -- [TUNING] { from (x, z), to (x, z), height, colour }
	{ Vector2.new(-160, -300), Vector2.new(-520, -250), 190, Color3.fromRGB(120, 255, 200) },
	{ Vector2.new(-200, -340), Vector2.new(-560, -170), 215, Color3.fromRGB(150, 232, 255) },
	{ Vector2.new(-260, -380), Vector2.new(-600, -300), 240, Color3.fromRGB(190, 150, 255) },
}
local RIBBONS = 18
local ribbons = {}
for c, curtain in ipairs(AURORA) do
	for k = 1, RIBBONS do
		local t = (k - 0.5) / RIBBONS
		local at = curtain[1]:Lerp(curtain[2], t)
		local p = anchor(Vector3.new(9, 70, 1), CFrame.new(at.X, curtain[3], at.Y))
		p.Transparency = 1
		p.Color = curtain[4]
		p.Material = Enum.Material.Neon
		local along = (curtain[2] - curtain[1]).Unit
		table.insert(ribbons, { part = p, base = Vector3.new(at.X, curtain[3], at.Y), along = along,
			phase = t * 7 + c * 1.9, curtain = c })
	end
end

-- ── Crystal glints: a slow sparkle on every crystal cluster ──────────────────────────────────────
for _, slot in ipairs(glacier:GetDescendants()) do
	if slot:IsA("Model") and string.find(slot:GetAttribute("MeshKey") or "", "^CrystalCluster") then
		local scale = slot:GetAttribute("SlotScale") or 1
		local at = Vector3.new(slot:GetAttribute("SlotX") or 0, slot:GetAttribute("SlotY") or 0, slot:GetAttribute("SlotZ") or 0)
		local a = anchor(Vector3.new(5, 8, 5) * scale, CFrame.new(at))
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(220, 250, 255))
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(0.6, 1.0)
		e.Rate = 2.5
		e.Speed = NumberRange.new(0)
		e.Parent = a
	end
end

holder.Parent = workspace.CurrentCamera or workspace

-- ── The frame loop ──────────────────────────────────────────────────────────────────────────────
local active = true
local clock = 0
local function setActive(on: boolean)
	active = on
	for _, d in ipairs(holder:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			d.Enabled = on
		end
	end
	if not on then
		for _, r in ipairs(ribbons) do
			r.part.Transparency = 1
		end
	end
end
setActive(false)

local parts: { BasePart } = {}
local frames: { CFrame } = {}
RunService.Heartbeat:Connect(function(dt)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if holder.Parent ~= camera then
		holder.Parent = camera
	end
	local eye = camera.CFrame.Position
	local here = inGlacier(eye)
	if here ~= active then
		setActive(here)
	end
	if not here then
		return
	end
	clock += dt
	table.clear(parts)
	table.clear(frames)
	table.insert(parts, snowSheet)
	table.insert(frames, CFrame.new(eye + Vector3.new(0, SNOW_ABOVE, 0)))
	for _, r in ipairs(ribbons) do
		-- each ribbon sways along its curtain and breathes in and out of view, so the curtain
		-- ripples slowly from one end to the other
		local sway = math.sin(clock * 0.35 + r.phase) * 7
		local lift = math.sin(clock * 0.22 + r.phase * 0.6) * 10
		table.insert(parts, r.part)
		table.insert(frames, CFrame.new(r.base + Vector3.new(r.along.X * sway, lift, r.along.Y * sway))
			* CFrame.Angles(0, math.atan2(-r.along.Y, r.along.X), math.sin(clock * 0.3 + r.phase) * 0.12))
		r.part.Transparency = 0.62 + 0.3 * (0.5 + 0.5 * math.sin(clock * 0.5 + r.phase * 1.3))
	end
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end)
