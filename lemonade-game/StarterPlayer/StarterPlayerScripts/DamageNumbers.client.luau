-- DamageNumbers: the DamageNumber remote's pop-ups (payload: position, amount, kind).
--
-- A number punches in at the hit: it pops from small to ~1.5x in 70 ms, snaps back to size with
-- a little tilt settling out, then drifts up while its colour cools from white through pink to
-- red and it fades. It sits beside the enemy's shoulder on the side facing the attacker, so it
-- never covers the body's reaction to the blow. One shared RenderStepped loop drives every
-- live number; each is destroyed when it finishes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local ComboConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ComboConfig"))

local damageEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("DamageNumber")

local currentCombo = 0

local comboRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):FindFirstChild("ComboUpdate")
if comboRemote then
	comboRemote.OnClientEvent:Connect(function(count)
		currentCombo = count
	end)
end

local LIFE = 1.05 -- [TUNING] seconds on screen
local POP_IN = 0.07 -- small -> peak scale
local POP_OUT = 0.2 -- peak -> rest scale
local FADE_FROM = 0.72 -- starts fading here

-- Colour ramps: { time, colour } keys, held after the last one.
local WHITE = Color3.fromRGB(255, 255, 255)
local PINK = Color3.fromRGB(255, 150, 172)
local RED = Color3.fromRGB(232, 48, 62)
local STYLES = {
	outgoing = { size = Vector2.new(150, 64), peak = 1.55, font = Enum.Font.GothamBlack,
		ramp = { { 0.22, WHITE }, { 0.45, PINK }, { 0.8, RED } } },
	crit = { size = Vector2.new(210, 84), peak = 1.8, font = Enum.Font.GothamBlack,
		ramp = { { 0.25, Color3.fromRGB(255, 236, 110) }, { 0.5, Color3.fromRGB(255, 140, 50) }, { 0.8, RED } } },
	incoming = { size = Vector2.new(110, 48), peak = 1.35, font = Enum.Font.GothamBlack,
		ramp = { { 0.3, Color3.fromRGB(255, 90, 90) }, { 0.8, Color3.fromRGB(200, 30, 40) } } },
}

local function rampColor(ramp, t: number): Color3
	if t <= ramp[1][1] then
		return ramp[1][2]
	end
	for i = 2, #ramp do
		if t <= ramp[i][1] then
			local a, b = ramp[i - 1], ramp[i]
			return a[2]:Lerp(b[2], (t - a[1]) / (b[1] - a[1]))
		end
	end
	return ramp[#ramp][2]
end

local function outQuad(u: number): number
	return 1 - (1 - u) * (1 - u)
end

local function scaleAt(t: number, peak: number): number
	if t < POP_IN then
		return 0.35 + (peak - 0.35) * outQuad(t / POP_IN)
	elseif t < POP_OUT then
		local u = (t - POP_IN) / (POP_OUT - POP_IN)
		return peak + (1 - peak) * (u * u * (3 - 2 * u))
	end
	return 1 - 0.1 * math.clamp((t - POP_OUT) / (LIFE - POP_OUT), 0, 1)
end

local active = {}

-- How far apart two hits count as "the same body" for stacking, and how many steps the fan is
-- allowed before it stops climbing (past five it would walk off the top of the screen).
local STACK_RADIUS = 6 -- studs
local STACK_MAX = 4
local STACK_RISE = 0.85 -- studs of extra height per step
local STACK_OUT = 0.10 -- extra outward SizeOffset per step

-- A killing blow hands the screen to the kill's token payout (TokenDrops): every number near a
-- body that just paid tokens shrinks and fades out within QUENCH seconds, so the "+N" tokens are
-- the brightest text on screen. Numbers that land a moment after the payout packet are caught too.
local QUENCH = 0.22 -- [TUNING] seconds
local QUENCH_RADIUS = 7 -- studs
local quenchSpots = {} -- { pos, at }
local function quenchNear(position: Vector3, now: number)
	for _, n in ipairs(active) do
		if not n.quenchAt and (n.part.Position - position).Magnitude <= QUENCH_RADIUS then
			n.quenchAt = now
		end
	end
end

-- -1 puts the number left of the hit on screen, +1 right: toward the local character, so it
-- floats over the gap between the fighters rather than over the body being knocked away.
local function screenSide(position: Vector3): number
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if camera and root and (root.Position - position).Magnitude > 1 then
		local a = camera:WorldToViewportPoint(position)
		local b = camera:WorldToViewportPoint(root.Position)
		if math.abs(b.X - a.X) > 4 then
			return if b.X > a.X then 1 else -1
		end
	end
	return if math.random() < 0.5 then -1 else 1
end

local function showDamage(position, amount, kind)
	local isCrit = (kind == "crit")
	local style = STYLES[if isCrit then "crit" elseif kind == "incoming" then "incoming" else "outgoing"]

	local part = Instance.new("Part")
	part.Size = Vector3.new(1, 1, 1)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Position = position
	part.Parent = Workspace

	local side = screenSide(position)
	local billboard = Instance.new("BillboardGui")
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Adornee = part
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = style.font
	label.TextScaled = true
	label.Text = (if isCrit then "CRIT! " else "") .. "-" .. tostring(math.round(amount))
	label.TextStrokeTransparency = 1
	label.Rotation = side * -8
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(20, 10, 14)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label

	local ramp = style.ramp
	if currentCombo >= 3 and not isCrit and kind ~= "incoming" then
		label.Text = currentCombo .. "x " .. label.Text
		local combo = ComboConfig.HUD_COLORS[currentCombo] or WHITE
		ramp = { { 0.22, combo }, { 0.5, combo:Lerp(RED, 0.5) }, { 0.8, RED } }
	end

	local born = os.clock()
	-- STACK INDEX. A number lives 1.05 s and an M1 chain lands five of them on one body inside
	-- 1.6 s, so up to five used to be drawn at the same offset from the same point: they piled
	-- into one unreadable clot ON TOP of the fighters. Round 5's blind read counted the damage
	-- text covering the action in four of eight frames, and that is what it was seeing. Each new
	-- number now counts the live ones near it and stacks a step higher and a little further out,
	-- so a chain fans its numbers up and away from the bodies instead of over them. The count is
	-- over `active`, which is at most a handful of entries, once per hit.
	local stack = 0
	for _, n in ipairs(active) do
		if (n.part.Position - position).Magnitude <= STACK_RADIUS then
			stack += 1
		end
	end
	local entry = {
		part = part, billboard = billboard, label = label, stroke = stroke,
		style = style, ramp = ramp, side = side, born = born,
		stack = math.min(stack, STACK_MAX),
	}
	for _, q in ipairs(quenchSpots) do
		if born - q.at < 0.25 and (q.pos - position).Magnitude <= QUENCH_RADIUS then
			entry.quenchAt = born
		end
	end
	table.insert(active, entry)
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for i = #active, 1, -1 do
		local n = active[i]
		local t = now - n.born
		if t >= LIFE or not n.part.Parent then
			n.part:Destroy()
			table.remove(active, i)
			continue
		end
		local q = if n.quenchAt then math.clamp((now - n.quenchAt) / QUENCH, 0, 1) else 0
		if q >= 1 then
			n.part:Destroy()
			table.remove(active, i)
			continue
		end
		local s = scaleAt(t, n.style.peak) * (1 - 0.45 * q)
		n.billboard.Size = UDim2.fromOffset(n.style.size.X * s, n.style.size.Y * s)
		-- Above the shoulder, drifting up and a little outward as it cools, and stepped clear of
		-- whatever numbers were already there. The base height went 1.7 -> 2.4 studs at the same
		-- time as the stacking: even a single number at 1.7 sat across the top of a man-sized
		-- body from a side-on lens, and the body is the thing a fighting game is judged on.
		local rise = 1 - (1 - math.min(1, t / LIFE)) ^ 2
		local step = (n.stack or 0)
		n.billboard.StudsOffset = Vector3.new(0, 2.4 + STACK_RISE * step + 1.5 * rise, 0)
		n.billboard.SizeOffset = Vector2.new(n.side * (0.42 + STACK_OUT * step + 0.12 * rise), 0)
		n.label.Rotation = n.side * -8 * math.max(0, 1 - t / POP_OUT)
		n.label.TextColor3 = rampColor(n.ramp, t)
		local fade = math.max(q, math.clamp((t - FADE_FROM) / (LIFE - FADE_FROM), 0, 1))
		n.label.TextTransparency = fade
		n.stroke.Transparency = fade
		n.stroke.Thickness = 3.2 * s
	end
end)

damageEvent.OnClientEvent:Connect(function(position, amount, kind)
	-- Respect the ShowDamageNumbers setting (defaults to true)
	if player:GetAttribute("ShowDamageNumbers") == false then
		return
	end
	showDamage(position, amount, kind)
end)

local tokenEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("TokenDrop")
tokenEvent.OnClientEvent:Connect(function(origin)
	if typeof(origin) ~= "Vector3" then return end
	local now = os.clock()
	for i = #quenchSpots, 1, -1 do
		if now - quenchSpots[i].at > 0.25 then table.remove(quenchSpots, i) end
	end
	table.insert(quenchSpots, { pos = origin, at = now })
	quenchNear(origin, now)
end)

print("[DamageNumbers] Floating damage numbers with CRIT styling enabled")
