-- LocalScript | StarterPlayerScripts.OasisAmbience | Map project.
-- The Iron Lowlands oasis, alive without townsfolk (it is an enemy zone, so no villagers): parrots
-- wheeling over the pools, butterflies working the flower beds, dragonflies darting over the water,
-- tumbleweeds bowling across the pit, palms and banners swaying, sparkles on the water and wisps
-- of sand off the dunes. Everything here is client-side decoration: made on this client, parented
-- to the camera or to invisible anchors, no collision, no queries, and all of it idles while the
-- camera is away from the basin.
local RunService = game:GetService("RunService")

local map = workspace:WaitForChild("LemonadeMap", 30)
if not map then
	return
end
local il = map:WaitForChild("IronLowlands", 60)
if not il then
	return
end

-- The basin, and how near the camera must be for any of this to move.
local BASIN_MIN, BASIN_MAX = Vector2.new(-180, 100), Vector2.new(140, 480) -- [TUNING] x/z
local NEAR = 140 -- [TUNING] studs beyond the basin's edge before everything idles
local SWAY_RANGE = 220 -- [TUNING] studs: palms and banners farther than this hold still
local POOLS = { -- { centre, water top, radius }: the spring pool and the town spring (WorldTerrain POOLS)
	{ Vector3.new(94, 4, 348), 15 },
	{ Vector3.new(73, 8, 284), 9 },
}

local function inBasin(p: Vector3): boolean
	local x = math.clamp(p.X, BASIN_MIN.X, BASIN_MAX.X)
	local z = math.clamp(p.Z, BASIN_MIN.Y, BASIN_MAX.Y)
	return Vector2.new(p.X - x, p.Z - z).Magnitude <= NEAR
end

local function piece(size: Vector3, color: Color3, parent: Instance, shape: Enum.PartType?, transparency: number?): BasePart
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Transparency = transparency or 0
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Parent = parent
	return p
end

local holder = Instance.new("Folder")
holder.Name = "OasisAmbience"
holder.Parent = workspace.CurrentCamera

-- ── What the map offers: flower beds, and models tagged Sway ───────────────────────────────────
-- IronLowlands may stream in piece by piece, so the list is refreshed every few seconds.
local beds: { Vector3 } = {}
local swayers = {} -- Model -> { parts, offsets, pivot, amp, phase, speed }
local function scan()
	table.clear(beds)
	for _, m in ipairs(il:GetChildren()) do
		if not m:IsA("Model") then
			continue
		end
		if m:GetAttribute("FlowerBed") == true then
			table.insert(beds, Vector3.new(m:GetAttribute("BedX"), m:GetAttribute("BedY"), m:GetAttribute("BedZ")))
		end
		if m:GetAttribute("Sway") == true and not swayers[m] then
			local parts, offsets = {}, {}
			local lowest = math.huge
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					table.insert(parts, d)
					lowest = math.min(lowest, d.Position.Y - d.Size.Y / 2)
				end
			end
			if #parts > 0 then
				local c = m:GetPivot().Position
				local pivot = CFrame.new(c.X, lowest, c.Z) -- rock about the foot
				for i, p in ipairs(parts) do
					offsets[i] = pivot:ToObjectSpace(p.CFrame)
				end
				local tall = m:GetExtentsSize().Y
				swayers[m] = {
					parts = parts, offsets = offsets, pivot = pivot,
					-- a tall palm leans a degree or two; a banner pole less
					amp = math.rad(if tall > 20 then 1.6 else 0.8),
					phase = math.random() * math.pi * 2, speed = 0.7 + math.random() * 0.4,
				}
			end
		end
	end
	for m in pairs(swayers) do
		if not m.Parent then
			swayers[m] = nil
		end
	end
end
scan()
task.spawn(function()
	while true do
		task.wait(5)
		scan()
	end
end)

-- ── Butterflies ─────────────────────────────────────────────────────────────────────────────────
local WING_COLORS = { Color3.fromRGB(255, 96, 150), Color3.fromRGB(255, 212, 48), Color3.fromRGB(72, 204, 255),
	Color3.fromRGB(200, 120, 255), Color3.fromRGB(255, 150, 40) }
local flutters = {}
for k = 1, 6 do -- [TUNING] how many
	local body = piece(Vector3.new(0.18, 0.18, 0.55), Color3.fromRGB(60, 44, 70), holder)
	local wings = {}
	for side = -1, 1, 2 do
		table.insert(wings, { part = piece(Vector3.new(0.7, 0.05, 0.55), WING_COLORS[(k % #WING_COLORS) + 1], holder), side = side })
	end
	local start = POOLS[(k % #POOLS) + 1][1] + Vector3.new(0, 3, 0)
	table.insert(flutters, { body = body, wings = wings, pos = start, target = start, phase = k * 1.7,
		speed = 4 + math.random() * 3, linger = 0 })
end
local function pickFlutterTarget(f)
	if #beds > 0 and math.random() < 0.7 then
		local bed = beds[math.random(#beds)]
		f.target = bed + Vector3.new((math.random() - 0.5) * 4, 0.3 + math.random() * 1.4, (math.random() - 0.5) * 3)
		f.linger = 1.5 + math.random() * 3
	else
		local pool = POOLS[math.random(#POOLS)]
		local a, d = math.random() * math.pi * 2, pool[2] + math.random() * 10
		f.target = pool[1] + Vector3.new(math.cos(a) * d, 2 + math.random() * 3, math.sin(a) * d)
		f.linger = math.random() * 1.5
	end
end
for _, f in ipairs(flutters) do
	pickFlutterTarget(f)
end

-- ── Parrots: bright birds wheeling over the pools and the basin, wings beating ──────────────────
local PARROTS = { -- [TUNING] { body, wing, centre, radius, height, speed }
	{ Color3.fromRGB(255, 72, 90), Color3.fromRGB(72, 160, 255), Vector3.new(94, 0, 348), 26, 34, 0.32 },
	{ Color3.fromRGB(72, 190, 255), Color3.fromRGB(255, 212, 48), Vector3.new(94, 0, 348), 38, 42, -0.26 },
	{ Color3.fromRGB(255, 212, 48), Color3.fromRGB(120, 230, 90), Vector3.new(73, 0, 284), 22, 38, 0.36 },
	{ Color3.fromRGB(120, 230, 90), Color3.fromRGB(255, 96, 150), Vector3.new(0, 0, 300), 70, 58, -0.18 },
}
local parrots = {}
for k, p in ipairs(PARROTS) do
	local body = piece(Vector3.new(0.9, 0.9, 2.0), p[1], holder)
	local head = piece(Vector3.new(0.8, 0.8, 0.8), p[1], holder, Enum.PartType.Ball)
	local beak = piece(Vector3.new(0.35, 0.3, 0.45), Color3.fromRGB(255, 190, 60), holder)
	local tail = piece(Vector3.new(0.5, 0.12, 1.4), p[2], holder)
	local wings = {}
	for side = -1, 1, 2 do
		table.insert(wings, { part = piece(Vector3.new(2.0, 0.12, 1.0), p[2], holder), side = side })
	end
	table.insert(parrots, { body = body, head = head, beak = beak, tail = tail, wings = wings, spec = p, phase = k * 1.9 })
end

-- ── Dragonflies: darting over the water ─────────────────────────────────────────────────────────
local darters = {}
for k = 1, 5 do -- [TUNING]
	local pool = POOLS[(k % #POOLS) + 1]
	local color = if k % 2 == 0 then Color3.fromRGB(72, 204, 255) else Color3.fromRGB(200, 120, 255)
	local body = piece(Vector3.new(0.14, 0.14, 1.1), color, holder)
	local wings = {}
	for side = -1, 1, 2 do
		table.insert(wings, { part = piece(Vector3.new(0.9, 0.03, 0.22), Color3.fromRGB(235, 250, 255), holder, nil, 0.45), side = side })
	end
	local start = pool[1] + Vector3.new(0, 1.8, 0)
	table.insert(darters, { body = body, wings = wings, pool = pool, pos = start, target = start, wait = math.random() })
end
local function pickDart(d)
	local pool = d.pool
	local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * pool[2] * 0.9
	d.target = pool[1] + Vector3.new(math.cos(a) * r, 1.2 + math.random() * 2, math.sin(a) * r)
	d.wait = 0.4 + math.random() * 1.6
end

-- ── Tumbleweeds: bowling across the open pit on the wind, bouncing on the sand ─────────────────
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { workspace.Terrain }
local LANES = { -- [TUNING] { from, to }: the open sand between the oasis's places, west to east (the wind's way)
	{ Vector2.new(-44, 232), Vector2.new(12, 266) }, -- the mid bench, between the date grove and the trail
	{ Vector2.new(-30, 196), Vector2.new(46, 214) }, -- across the rim below the overlook
	{ Vector2.new(-46, 330), Vector2.new(40, 344) }, -- the top of the pit, over the trail
}
local weeds = {}
for k, lane in ipairs(LANES) do
	local r = 1.4 + k * 0.15
	local core = piece(Vector3.new(r * 2, r * 2, r * 2), Color3.fromRGB(232, 184, 110), holder, Enum.PartType.Ball)
	local shell = piece(Vector3.new(r * 2.3, r * 2.3, r * 2.3), Color3.fromRGB(250, 214, 150), holder, Enum.PartType.Ball, 0.55)
	table.insert(weeds, { core = core, shell = shell, lane = lane, r = r, t = (k - 1) / #LANES, spin = 0, speed = 7 + k })
end

-- ── Sparkles on the water, wisps of sand off the dunes ──────────────────────────────────────────
local function emitterAnchor(pos: Vector3, size: Vector3): BasePart
	local a = piece(size, Color3.new(1, 1, 1), holder, nil, 1)
	a.CFrame = CFrame.new(pos)
	return a
end
for _, pool in ipairs(POOLS) do
	local anchor = emitterAnchor(pool[1] + Vector3.new(0, 0.3, 0), Vector3.new(pool[2] * 1.6, 0.2, pool[2] * 1.6))
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	e.LightEmission = 0.8
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.2)
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Rate = 7
	e.Speed = NumberRange.new(0)
	e.Parent = anchor
end
for _, at in ipairs({ Vector3.new(-120, 24, 230), Vector3.new(120, 24, 420), Vector3.new(-120, 20, 440) }) do
	local anchor = emitterAnchor(at, Vector3.new(4, 1, 40))
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(255, 226, 170))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(2.5, 4)
	e.Rate = 3
	e.Speed = NumberRange.new(6, 10)
	e.EmissionDirection = Enum.NormalId.Right
	e.Acceleration = Vector3.new(4, 0.5, 0)
	e.Parent = anchor
end

-- ── The frame loop ──────────────────────────────────────────────────────────────────────────────
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}
local n = 0
local function move(part: BasePart, cf: CFrame)
	n += 1
	moveParts[n] = part
	moveCFrames[n] = cf
end
local clock, swayClock = 0, 0
local wasActive = true
RunService.Heartbeat:Connect(function(dt)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local active = inBasin(eye)
	if active ~= wasActive then
		wasActive = active
		for _, d in ipairs(holder:GetDescendants()) do
			if d:IsA("ParticleEmitter") then
				d.Enabled = active
			end
		end
	end
	if not active then
		return
	end
	clock += dt
	table.clear(moveParts)
	table.clear(moveCFrames)
	n = 0

	for _, f in ipairs(flutters) do
		local toTarget = f.target - f.pos
		if toTarget.Magnitude < 1.2 then
			if f.linger > 0 then
				f.linger -= dt
				f.pos += Vector3.new(math.sin(clock * 3 + f.phase), math.sin(clock * 5 + f.phase) * 0.6, math.cos(clock * 2.6 + f.phase)) * dt * 0.8
			else
				pickFlutterTarget(f)
			end
		else
			local forward = toTarget.Unit
			local sideways = Vector3.new(-forward.Z, 0, forward.X)
			local wobble = sideways * math.sin(clock * 2.4 + f.phase) * 1.6 + Vector3.new(0, math.sin(clock * 4.1 + f.phase) * 1.1, 0)
			f.pos += (forward * f.speed + wobble) * dt
		end
		local look = if toTarget.Magnitude > 0.5 then toTarget.Unit else Vector3.new(1, 0, 0)
		local frame = CFrame.lookAt(f.pos, f.pos + Vector3.new(look.X, 0, look.Z))
		move(f.body, frame)
		local flap = math.sin(clock * 24 + f.phase) * 1.1
		for _, w in ipairs(f.wings) do
			move(w.part, frame * CFrame.Angles(0, 0, flap * w.side) * CFrame.new(w.side * 0.4, 0, 0))
		end
	end

	for _, b in ipairs(parrots) do
		local s = b.spec
		local a = clock * s[6] + b.phase
		local pos = s[3] + Vector3.new(math.cos(a) * s[4], s[5] + math.sin(clock * 0.6 + b.phase) * 3, math.sin(a) * s[4])
		local dir = Vector3.new(-math.sin(a), 0, math.cos(a)) * math.sign(s[6])
		local bank = CFrame.Angles(0, 0, -0.3 * math.sign(s[6]))
		local frame = CFrame.lookAt(pos, pos + dir) * bank
		move(b.body, frame)
		move(b.head, frame * CFrame.new(0, 0.35, -1.2))
		move(b.beak, frame * CFrame.new(0, 0.25, -1.75))
		move(b.tail, frame * CFrame.new(0, -0.05, 1.5) * CFrame.Angles(0.15, 0, 0))
		local flap = math.sin(clock * 7 + b.phase) * 0.7
		for _, w in ipairs(b.wings) do
			move(w.part, frame * CFrame.new(w.side * 0.4, 0.2, 0) * CFrame.Angles(0, 0, flap * w.side) * CFrame.new(w.side * 1.0, 0, 0))
		end
	end

	for _, d in ipairs(darters) do
		local to = d.target - d.pos
		if to.Magnitude < 0.3 then
			d.wait -= dt
			if d.wait <= 0 then
				pickDart(d)
			end
		else
			d.pos += to.Unit * math.min(to.Magnitude, 14 * dt) -- quick straight darts, then a hover
		end
		local look = if to.Magnitude > 0.2 then Vector3.new(to.X, 0, to.Z) else Vector3.new(1, 0, 0)
		if look.Magnitude < 0.05 then
			look = Vector3.new(1, 0, 0)
		end
		local frame = CFrame.lookAt(d.pos, d.pos + look.Unit)
		move(d.body, frame)
		local buzz = math.sin(clock * 60) * 0.5
		for _, w in ipairs(d.wings) do
			move(w.part, frame * CFrame.new(0, 0.08, -0.2) * CFrame.Angles(0, 0, buzz * w.side) * CFrame.new(w.side * 0.45, 0, 0))
		end
	end

	for _, w in ipairs(weeds) do
		local a, b = w.lane[1], w.lane[2]
		local length = (b - a).Magnitude
		w.t += w.speed * (0.8 + 0.4 * math.sin(clock * 0.7 + w.r)) * dt / length
		if w.t > 1 then
			w.t -= 1 -- blown off the far end: a new one comes in at the start
		end
		local p2 = a:Lerp(b, w.t)
		local hit = workspace:Raycast(Vector3.new(p2.X, 60, p2.Y), Vector3.new(0, -80, 0), rayParams)
		local ground = if hit then hit.Position.Y else 2
		local hop = math.abs(math.sin(clock * 2.8 + w.r * 3)) * 1.4
		local pos = Vector3.new(p2.X, ground + w.r + hop, p2.Y)
		w.spin += w.speed * dt / w.r
		local dir = (b - a).Unit
		local roll = CFrame.fromAxisAngle(Vector3.new(dir.Y, 0, -dir.X), -w.spin)
		move(w.core, CFrame.new(pos) * roll)
		move(w.shell, CFrame.new(pos) * roll * CFrame.Angles(0.7, 0.4, 0))
	end

	-- Palms and banners: a slow rock about the foot, at 30 Hz, near the camera only.
	swayClock += dt
	if swayClock >= 1 / 30 then
		swayClock = 0
		for _, s in pairs(swayers) do
			if (s.pivot.Position - eye).Magnitude > SWAY_RANGE then
				continue
			end
			local t = clock * s.speed + s.phase
			local tilt = CFrame.Angles(math.sin(t) * s.amp, 0, math.sin(t * 0.73 + 1.1) * s.amp)
			local base = s.pivot * tilt
			for i, p in ipairs(s.parts) do
				move(p, base * s.offsets[i])
			end
		end
	end

	if n > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
