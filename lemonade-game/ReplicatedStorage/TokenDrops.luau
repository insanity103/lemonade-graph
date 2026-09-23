--// TokenDrops  (client module, started by GoldNumbers.client: a kill's spin tokens burst out of
--   the body, get magneted in, and fly to the HUD token counter)
-- A ModuleScript under ReplicatedStorage (synced as a folder) rather than its own LocalScript, so
-- it rides the existing client script list; requiring it once on the client starts it.
-- The server has already credited the tokens when TokenDrop arrives (SwordDropSystem): this
-- script only PRESENTS a number it was handed. What it draws:
--   1. THE POP. A lemon-slice token per pickup (Config.TokenRules.Split) bursts out of the body
--      on a flipping arc, lands upright with a small hop and spins in place; a ring flashes on the
--      ground under the kill and a "+N" with the token icon pops over it.
--   2. THE MAGNET. A beat after landing, the tokens accelerate into the player one after another
--      and pop on contact (a flash and a rising pickup tick).
--   3. THE COUNTER. Each popped token leaves a 2D token that flies to the HUD readout
--      (bottom-left, over the gold) and ticks it up by its value, with the shared counter's punch
--      and floating "+N". The readout shows the saved total MINUS what is still in flight, so it
--      climbs pickup by pickup and lands exactly on the server's number.
local RunService = game:GetService("RunService")
local TokenDrops = {}
if not RunService:IsClient() then
	return TokenDrops
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local AudioManager = require(ReplicatedStorage:WaitForChild("AudioManager"))
local TOKEN_EVENT = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("TokenDrop")

local HUD = PanelChrome.HUD
local BRIGHT = PanelChrome.BRIGHT

-- The token's look: a lemon slice. Lemon-yellow rind (greener and paler than the orange-gold
-- coin, so the two purses never read as one), a white pith ring, pale flesh and white segments.
local RIND = Color3.fromRGB(255, 222, 0)
local RIND_DARK = Color3.fromRGB(226, 178, 0)
local PITH = Color3.fromRGB(255, 255, 246)
local FLESH = Color3.fromRGB(255, 238, 90)
local FLESH_DARK = Color3.fromRGB(255, 214, 60)
local TEXT_LEMON = Color3.fromRGB(255, 240, 70)
-- The token's own colour, which the gold coin never wears: a teal rim on every token (world, HUD,
-- flyers, popups) and a teal pill behind the HUD readout.
local TEAL = Color3.fromRGB(0, 176, 166)
local TEAL_DARK = Color3.fromRGB(0, 96, 100)

-- [TUNING] seconds and studs
-- The beat, from the kill: tokens are out of the body and on the ground by ~0.2 s, the magnet
-- takes them one after another (Stagger apart, counted across every body that died together, so
-- a pack streams in rather than arriving in clumps), and each one's 2D flight lands on the HUD
-- counter ~0.4 s after the kill at the earliest, the last by ~0.7 s for a three-body pack.
local T = {
	ArcTime = 0.15, ArcJitter = 0.04,     -- flight out of the body
	ArcHeight = 2.8, ArcHeightJitter = 1.0,
	SpreadMin = 2.4, SpreadMax = 4.2,   -- how far from the body a token lands
	Flips = 2,                          -- full turns a token flips through in the air
	HopTime = 0.04, HopHeight = 0.3,    -- the landing hop
	Rest = 0.0,                         -- sat on the ground before the magnet takes it
	Stagger = 0.018,                    -- between one token's magnet and the next
	SlotWindow = 0.3,                   -- bursts this close together share one stagger queue
	MagnetStart = 45, MagnetAccel = 600, MagnetMax = 160, CollectAt = 2.2,
	RestSpin = 3.2, BobHeight = 0.18, BobRate = 5,
	FlyTime = 0.14, FlyJitter = 0.03,   -- the 2D flight to the counter
	PopupTime = 1.0, PopupRise = 1.2,
	Flush = 5,                          -- any token not home by then is counted anyway
	Coin = 2.5,                         -- token diameter, studs
}

-- ── the HUD readout ────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "TokenHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true -- AbsolutePosition then matches Camera:WorldToViewportPoint
gui.DisplayOrder = 10
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function circle(parent, px, color, z, pos)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = pos or UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(px, px)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	f.Parent = parent
	return f
end

-- The token drawn in 2D (the HUD icon, the flyers, the popup): rind, pith, flesh, six segments.
local function tokenIcon(parent, px, z)
	local root = circle(parent, px, RIND, z)
	root.Name = "TokenIcon"
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(RIND, RIND_DARK)
	grad.Parent = root
	PanelChrome.stroke(root, TEAL_DARK, math.max(2.5, px / 12))
	circle(root, math.floor(px * 0.8), PITH, z + 1)
	local flesh = circle(root, math.floor(px * 0.66), FLESH, z + 2)
	local fg = Instance.new("UIGradient")
	fg.Rotation = 90
	fg.Color = ColorSequence.new(FLESH, FLESH_DARK)
	fg.Parent = flesh
	for i = 0, 2 do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromOffset(math.max(2, math.floor(px * 0.07)), math.floor(px * 0.66))
		bar.Rotation = i * 60
		bar.BackgroundColor3 = PITH
		bar.BorderSizePixel = 0
		bar.ZIndex = z + 3
		bar.Parent = root
	end
	circle(root, math.max(3, math.floor(px * 0.14)), PITH, z + 4)
	-- a glossy fleck, top left
	local gloss = circle(root, math.floor(px * 0.2), Color3.new(1, 1, 1), z + 5,
		UDim2.fromScale(0.3, 0.26))
	gloss.BackgroundTransparency = 0.35
	return root
end

TokenDrops.icon = tokenIcon -- the same lemon token, for the spin wheel's board and prompt (SpinStation)

local chipHolder = Instance.new("Frame")
chipHolder.Name = "TokenChip"
chipHolder.AnchorPoint = Vector2.new(0, 1)
chipHolder.Size = UDim2.fromOffset(340, HUD.TokenHeight)
chipHolder.BackgroundTransparency = 1
chipHolder.Parent = gui
local chipScale = Instance.new("UIScale")
chipScale.Parent = chipHolder

local chip = Instance.new("Frame")
chip.Name = "Chip"
chip.AnchorPoint = Vector2.new(0, 0.5)
chip.Position = UDim2.fromScale(0, 0.5)
chip.Size = UDim2.fromScale(1, 1)
chip.BackgroundTransparency = 1
chip.ZIndex = 6
chip.Parent = chipHolder
local punch = Instance.new("UIScale")
punch.Name = "Punch"
punch.Parent = chip

-- A teal pill the lemon sits on: the gold row has no backing, so the two purses never read as one.
local ICON_PX = 90
local TEXT_X = ICON_PX + 12
local pill = Instance.new("Frame")
pill.Name = "Pill"
pill.AnchorPoint = Vector2.new(0, 0.5)
pill.Position = UDim2.new(0, math.floor(ICON_PX * 0.45), 0.5, 2)
pill.Size = UDim2.fromOffset(250, 66)
pill.BackgroundColor3 = TEAL
pill.ZIndex = 6
pill.Parent = chip
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = pill
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.fromRGB(40, 206, 190), TEAL_DARK)
	g.Parent = pill
	PanelChrome.stroke(pill, BRIGHT.Outline, 3.5)
end
local iconSlot = Instance.new("Frame")
iconSlot.Name = "Icon"
iconSlot.AnchorPoint = Vector2.new(0, 0.5)
iconSlot.Position = UDim2.new(0, 0, 0.5, 0)
iconSlot.Size = UDim2.fromOffset(ICON_PX, ICON_PX)
iconSlot.BackgroundTransparency = 1
iconSlot.Rotation = -10
iconSlot.Parent = chip
tokenIcon(iconSlot, ICON_PX, 8)

local VALUE_SIZE = 60
local valueLabel = PanelChrome.display(chip, {
	name = "Value", text = "0", size = VALUE_SIZE, stroke = 4, zIndex = 7, color = TEXT_LEMON,
	xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(TEXT_X, 2), size2 = UDim2.new(1, -TEXT_X, 1, 0),
})

-- Every token that lands kicks the readout on its own: up to 1.35x in 35 ms, back by ~120 ms.
local PUNCH = { Peak = 1.35, RiseTime = 0.035, CountTime = 0.08, HoldTo = 1.2, SettleTime = 0.07,
	FlashFade = 0.12, IconKick = -14, Rekick = 1.12, DeltaTime = 0.9, DeltaRise = 34 }

local function gainText(gain)
	return "+" .. NumberFormat.short(gain)
end

local counter = PanelChrome.counter({
	label = valueLabel, scale = punch, icon = iconSlot, format = NumberFormat.short,
	deltaParent = chipHolder, deltaZ = 12, deltaText = gainText, tuning = PUNCH,
	deltaColor = TEXT_LEMON, deltaStroke = TEAL_DARK, deltaSize = 40,
	deltaAt = function(text)
		local w = TextService:GetTextSize(text, VALUE_SIZE, PanelChrome.DISPLAY_FONT, Vector2.new(1e4, 1e4)).X
		return UDim2.new(0, math.ceil((TEXT_X + w) * 1.12) + 10, 0.5, -16)
	end,
})

PanelChrome.onViewport(function(viewport)
	local s = PanelChrome.hudScale(viewport)
	chipScale.Scale = s
	-- Directly over the gold readout: vitals, then gold, then this.
	local lift = PanelChrome.hudVitalsBottom(viewport) + (HUD.VitalsHeight + HUD.GoldHeight) * s + 2
	chipHolder.Position = UDim2.new(0, HUD.Margin, 1, -math.floor(lift))
end)

-- Tokens the server has credited that have not flown home yet. The readout shows the saved
-- total minus these, so it climbs one pickup at a time and ends on the server's number.
local inFlight = 0
local lastSaved, lastShown = nil, 0
local function refresh()
	local saved = math.max(0, math.floor(tonumber(player:GetAttribute("Tokens")) or 0))
	local show = math.max(0, saved - inFlight)
	-- A total that did not fall (nothing was spent) never makes the readout fall either: however
	-- the new total and the TokenDrop packet interleave, the number only climbs as tokens land.
	if lastSaved ~= nil and saved >= lastSaved then
		show = math.max(show, math.min(lastShown, saved))
	end
	lastSaved, lastShown = saved, show
	counter.set(show, player:GetAttribute("DataLoaded") == true)
end
player:GetAttributeChangedSignal("Tokens"):Connect(function()
	-- A beat later, so a TokenDrop that crossed the wire alongside the new total has already been
	-- counted in flight whichever of the two arrived first.
	task.delay(0.25, refresh)
end)
player:GetAttributeChangedSignal("DataLoaded"):Connect(refresh)
refresh()

-- ── the world pickups ──────────────────────────────────────────────────────────────────
local folder = Instance.new("Folder")
folder.Name = "TokenPickups"
folder.Parent = Workspace

local function newPart(shape, size, color, material)
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- One 3D token: parts plus their offsets from the token's centre. A Cylinder's axis is its X, so
-- the coin's face looks along the token CFrame's X axis.
local function buildToken(scale)
	local d = T.Coin * scale
	local parts, offsets = {}, {}
	local function add(part, offset)
		part.Parent = folder
		table.insert(parts, part)
		table.insert(offsets, offset)
	end
	add(newPart(Enum.PartType.Cylinder, Vector3.new(0.34 * scale, d * 1.1, d * 1.1), TEAL), CFrame.identity)
	add(newPart(Enum.PartType.Cylinder, Vector3.new(0.42 * scale, d, d), RIND), CFrame.identity)
	add(newPart(Enum.PartType.Cylinder, Vector3.new(0.48 * scale, d * 0.84, d * 0.84), PITH), CFrame.identity)
	add(newPart(Enum.PartType.Cylinder, Vector3.new(0.54 * scale, d * 0.7, d * 0.7), FLESH), CFrame.identity)
	for i = 0, 2 do
		add(newPart(Enum.PartType.Block, Vector3.new(0.58 * scale, 0.1 * scale, d * 0.7), PITH),
			CFrame.Angles(math.rad(i * 60), 0, 0))
	end
	add(newPart(Enum.PartType.Cylinder, Vector3.new(0.62 * scale, d * 0.15, d * 0.15), PITH), CFrame.identity)
	return parts, offsets
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundAt(pos)
	local exclude = { folder }
	if player.Character then table.insert(exclude, player.Character) end
	rayParams.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), rayParams)
	return if hit then hit.Position else pos - Vector3.new(0, 3, 0)
end

local function playerRoot()
	local ch = player.Character
	return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function ease(a, style, dir)
	return TweenService:GetValue(math.clamp(a, 0, 1), style, dir)
end

-- A flash where a token was taken, and the rising pickup tick.
local streak, streakAt = 0, 0
local function pickupFx(pos)
	local flash = newPart(Enum.PartType.Ball, Vector3.one * 0.8, Color3.fromRGB(255, 252, 200), Enum.Material.Neon)
	flash.CastShadow = false
	flash.Position = pos
	flash.Transparency = 0.1
	flash.Parent = folder
	local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(flash, info, { Size = Vector3.one * 3, Transparency = 1 }):Play()
	task.delay(0.22, function() flash:Destroy() end)
	local now = os.clock()
	streak = if now - streakAt < 0.6 then streak + 1 else 0
	streakAt = now
	AudioManager.PlaySFX("gold_pickup", SoundService, {
		PlaybackSpeed = math.min(1.15 + streak * 0.06, 2.0), Volume = 0.32,
	})
end

-- The ring that flashes on the ground under a kill as it bursts.
local function burstRing(ground, role)
	local big = role == "boss" or role == "warden"
	local ring = newPart(Enum.PartType.Cylinder, Vector3.new(0.12, 2, 2), RIND, Enum.Material.Neon)
	ring.CastShadow = false
	ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Transparency = 0.35
	ring.Parent = folder
	local size = if big then 16 else 9
	local info = TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = Vector3.new(0.12, size, size), Transparency = 1 }):Play()
	task.delay(0.34, function() ring:Destroy() end)
end

-- "+N" and the token icon, popping over the body and rising away.
local function popup(origin, total)
	local anchor = newPart(Enum.PartType.Block, Vector3.one * 0.2, RIND)
	anchor.Transparency = 1
	anchor.Position = origin
	anchor.Parent = folder
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(190, 64)
	-- Right on the drop point, just over the burst (a kill no longer pops a gold number).
	bb.StudsOffset = Vector3.new(0, 0.6, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Adornee = anchor
	bb.Parent = anchor
	local group = Instance.new("CanvasGroup")
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.Parent = bb
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = group
	local iconSlot2 = Instance.new("Frame")
	iconSlot2.BackgroundTransparency = 1
	iconSlot2.Size = UDim2.fromOffset(50, 50)
	iconSlot2.AnchorPoint = Vector2.new(0, 0.5)
	iconSlot2.Position = UDim2.new(0, 10, 0.5, 0)
	iconSlot2.Parent = group
	tokenIcon(iconSlot2, 48, 2)
	PanelChrome.display(group, {
		name = "Amount", text = "+" .. NumberFormat.short(total), size = 46, stroke = 4, color = TEXT_LEMON,
		strokeColor = TEAL_DARK,
		xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(66, 0), size2 = UDim2.new(1, -66, 1, 0),
		zIndex = 3,
	})
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local popT = 0.18
		scale.Scale = if t < popT then 0.2 + 1.15 * ease(t / popT, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			else 1.35 - 0.35 * ease((t - popT) / 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local k = t / T.PopupTime
		bb.StudsOffset = Vector3.new(0, 0.6 + T.PopupRise * ease(k, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), 0)
		group.GroupTransparency = if k > 0.6 then (k - 0.6) / 0.4 else 0
		if k >= 1 then
			conn:Disconnect()
			anchor:Destroy()
		end
	end)
end

-- A teal ring bursting off the HUD icon as a token is absorbed into it.
local function absorbRing()
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 5
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = ring
	local st = PanelChrome.stroke(ring, Color3.fromRGB(255, 250, 190), 5)
	ring.Parent = iconSlot
	local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = UDim2.fromScale(1.9, 1.9) }):Play()
	TweenService:Create(st, info, { Transparency = 1, Thickness = 1 }):Play()
	task.delay(0.22, function() ring:Destroy() end)
end

-- 2D flight from where a token was taken to the HUD icon; `done` ticks the counter on arrival.
local function flyHome(worldPos, done)
	local camera = Workspace.CurrentCamera
	local screen, onScreen = camera:WorldToViewportPoint(worldPos)
	local targetAbs = iconSlot.AbsolutePosition + iconSlot.AbsoluteSize / 2
	if not onScreen or screen.Z <= 0 then
		done()
		return
	end
	local s = chipScale.Scale
	local from = Vector2.new(screen.X, screen.Y)
	local to = targetAbs
	-- Bow the path up and away from the straight line, so the stream arcs into the counter.
	local mid = (from + to) / 2
	local ctrl = mid + Vector2.new((from.X - to.X) * 0.15, -math.abs(from.Y - to.Y) * 0.35 - 90 * s)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(54, 54)
	holder.Position = UDim2.fromOffset(from.X, from.Y)
	holder.ZIndex = 20
	holder.Parent = gui
	local us = Instance.new("UIScale")
	us.Parent = holder
	tokenIcon(holder, 54, 21)
	local dur = T.FlyTime + math.random() * T.FlyJitter
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - t0) / dur, 0, 1)
		local e = ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local p = from:Lerp(ctrl, e):Lerp(ctrl:Lerp(to, e), e)
		holder.Position = UDim2.fromOffset(p.X, p.Y)
		holder.Rotation = -10 + 30 * (1 - a)
		us.Scale = s * (if a < 0.25 then 0.8 + 0.5 * (a / 0.25) else 1.3 - 0.35 * ((a - 0.25) / 0.75))
		if a >= 1 then
			conn:Disconnect()
			holder:Destroy()
			absorbRing()
			done()
		end
	end)
end

-- Every live token, stepped from one RenderStepped loop.
local tokens = {}

-- One stagger queue shared by every burst in the same beat (a pack dying to one swing).
local slot, slotAt = 0, -math.huge
local function nextSlot()
	local now = os.clock()
	if now - slotAt > T.SlotWindow then slot = 0 end
	slotAt = now
	slot += 1
	return slot
end

local function spawnToken(origin, ground, index, count, value, role, drop, t0)
	local scale = if role == "boss" or role == "warden" then 1.25 elseif value > 1 then 1.12 else 1
	local parts, offsets = buildToken(scale)
	local angle = (index / count) * math.pi * 2 + (math.random() - 0.5) * 0.9
	local reach = T.SpreadMin + math.random() * (T.SpreadMax - T.SpreadMin)
	if role == "boss" or role == "warden" then reach *= 1.35 end
	local landXZ = origin + Vector3.new(math.cos(angle), 0, math.sin(angle)) * reach
	local land = groundAt(landXZ) + Vector3.new(0, T.Coin * scale / 2 + 0.12, 0)
	local arc = T.ArcTime + math.random() * T.ArcJitter
	table.insert(tokens, {
		parts = parts, offsets = offsets,
		from = origin + Vector3.new(0, 0.6, 0), land = land, pos = origin,
		height = T.ArcHeight + math.random() * T.ArcHeightJitter,
		arc = arc, t0 = t0, yaw = angle + math.pi / 2, spinDir = if math.random() < 0.5 then -1 else 1,
		magnetAt = arc + T.HopTime + T.Rest + (nextSlot() - 1) * T.Stagger,
		speed = T.MagnetStart, value = value, drop = drop, scale = scale,
	})
end

local function arrive(token)
	local drop = token.drop
	if drop.remaining <= 0 then return end -- already flushed
	local v = math.min(token.value, drop.remaining)
	drop.remaining -= v
	inFlight = math.max(0, inFlight - v)
	refresh()
end

local moveParts, moveCFrames = {}, {}
RunService.RenderStepped:Connect(function(dt)
	if #tokens == 0 then return end
	local now = os.clock()
	local root = playerRoot()
	table.clear(moveParts)
	table.clear(moveCFrames)
	for i = #tokens, 1, -1 do
		local tk = tokens[i]
		local t = now - tk.t0
		local cf
		local collected = false
		if t < tk.arc then
			local a = t / tk.arc
			local pos = tk.from:Lerp(tk.land, a) + Vector3.new(0, tk.height * 4 * a * (1 - a), 0)
			-- flips end-over-end, landing upright (face horizontal)
			local flip = T.Flips * math.pi * 2 * ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			tk.pos = pos
			cf = CFrame.new(pos) * CFrame.Angles(0, tk.yaw, 0) * CFrame.Angles(0, 0, flip)
		elseif t < tk.magnetAt then
			local since = t - tk.arc
			local hop = if since < T.HopTime then T.HopHeight * math.sin(math.pi * since / T.HopTime) else 0
			local bob = T.BobHeight * math.sin(since * T.BobRate)
			local pos = tk.land + Vector3.new(0, hop + bob, 0)
			tk.pos = pos
			tk.yaw += T.RestSpin * dt * tk.spinDir
			cf = CFrame.new(pos) * CFrame.Angles(0, tk.yaw, 0)
		else
			local target = if root then root.Position + Vector3.new(0, 0.4, 0) else tk.pos
			local toward = target - tk.pos
			local dist = toward.Magnitude
			tk.speed = math.min(tk.speed + T.MagnetAccel * dt, T.MagnetMax)
			local stepLen = tk.speed * dt
			if not root or dist <= T.CollectAt or stepLen >= dist or t > T.Flush then
				collected = true
			else
				tk.pos += toward.Unit * stepLen
				tk.yaw += 14 * dt * tk.spinDir
				cf = CFrame.new(tk.pos) * CFrame.Angles(0, tk.yaw, 0)
			end
		end
		if collected then
			for _, p in ipairs(tk.parts) do p:Destroy() end
			table.remove(tokens, i)
			pickupFx(tk.pos)
			flyHome(tk.pos, function() arrive(tk) end)
		else
			for j, part in ipairs(tk.parts) do
				table.insert(moveParts, part)
				table.insert(moveCFrames, cf * tk.offsets[j])
			end
		end
	end
	if #moveParts > 0 then
		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

TOKEN_EVENT.OnClientEvent:Connect(function(origin, values, total, role)
	if typeof(origin) ~= "Vector3" or typeof(values) ~= "table" then return end
	total = math.max(0, math.floor(tonumber(total) or 0))
	if total <= 0 then return end
	local drop = { remaining = total }
	inFlight += total -- no refresh here: the readout holds until each token lands
	-- Whatever is not home by then (the player ran off, the camera looked away) is counted anyway.
	task.delay(T.Flush + 1, function()
		if drop.remaining > 0 then
			inFlight = math.max(0, inFlight - drop.remaining)
			drop.remaining = 0
			refresh()
		end
	end)
	local ground = groundAt(origin)
	burstRing(ground, role)
	popup(origin, total)
	local t0 = os.clock()
	local count = #values
	for i, v in ipairs(values) do
		spawnToken(origin, ground, i, count, math.max(1, math.floor(tonumber(v) or 1)), role, drop, t0)
	end
end)

-- Studio capture only: the TokenDrop stage (EnemyCombat) holds the camera, which hides every
-- ScreenGui that is not marked kept. The counter is the subject of this capture and the rest of
-- the HUD is its context, so for this one stage every ScreenGui is kept.
if RunService:IsStudio() and Workspace:GetAttribute("GuiShowcase") == "Motion:TokenDrop" then
	local function keep(child)
		if child:IsA("ScreenGui") then child:SetAttribute("GuiShowcaseKeep", true) end
	end
	for _, child in ipairs(playerGui:GetChildren()) do keep(child) end
	playerGui.ChildAdded:Connect(keep)
end

print("[TokenDrops] Token pickups and HUD counter live")

return TokenDrops
