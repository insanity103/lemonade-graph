--// SwordDropToast (client): the drop reveal a kill pays out, the KEEP-or-SELL prompt it ends
-- on, and the small sword-lost toast.
--
-- The reveal is not a notification. A kill that pays drops a WRAPPED sword centre stage -- the
-- blade in black on a neutral card, a question mark over it -- and the result is withheld while a
-- rarity ladder ticks upward, tier by tier, slowing down as it climbs, with a tick per rung. On
-- about one roll in six it overshoots one rung PAST the truth and hangs there before falling back
-- (the near miss). Then it LANDS: the burst, the hold and the noise are all scaled to the tier
-- that landed, from a 150 ms pop and a 0.9 s hold on a Common up to a full-screen beam, a time
-- dip, a screen shake, a server-wide announce and a 3.5 s hold on a Legendary. Only then does the
-- silhouette resolve into the sword itself, shown big in a 340 px viewport, with its name, its
-- tier word in the tier's colour and the REAL odds of that tier on their own line. The close is a
-- next-roll hook: the luck the kill rolled at, the odds just beaten, and the next rung up.
--
-- The server rolled all of it before any of this started (SwordDropSystem -> DropRules ->
-- BossSwordFactory) and sent the whole answer in one remote; the client only holds it back for
-- the length of the theatre. Nothing flashed before the landing decides anything.
--
-- The reveal never takes input, so it never blocks play: the next swing, and the next roll, are
-- available through it. A new drop sends the one on screen away at once.
--
-- THE PROMPT. Auto-sell is gone. At the landing -- the moment the sword has a name and a tier --
-- the card also carries what it is WORTH, and a bar of two buttons comes up: KEEP and SELL for
-- that price. Nothing else on screen takes input, so the two buttons are the only pixels that do,
-- and the rest of the reveal stays as untouchable as it was: you can swing, move and kill straight
-- through it. Doing nothing is KEEP -- the sword is already in the bag and simply stays there when
-- the countdown runs out. The price is the server's (Config.SellValue), the offer id is the
-- server's, and a press is a request, not a sale: the button locks on the first press and the
-- wording only changes when the server answers. Missing the prompt costs nothing, because the
-- inventory sells the same sword for the same price.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local REMOTES = ReplicatedStorage:WaitForChild("RemoteEvents")
local DROP_EVENT = REMOTES:WaitForChild("SwordDrop")
-- The KEEP-or-SELL prompt, both ways down one remote: this client fires (offerId, "SELL" or
-- "KEEP") and the server answers (offerId, "SOLD" | "KEPT" | "DENIED", gold, reason). The client
-- decides nothing -- it prints the price the server sent and reports which button was pressed.
local PICKUP_EVENT = REMOTES:WaitForChild("SwordPickup")
local SWORD_LOST_EVENT = REMOTES:WaitForChild("SwordLostOnDeath")

local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))
local AudioManager = require(ReplicatedStorage:WaitForChild("AudioManager"))
local BossWeapons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BossWeapons"))

local BRIGHT = PanelChrome.BRIGHT
local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(14, 10, 26)

local RARITY_COLOR = {
	Common = Color3.fromRGB(210, 210, 210),
	Uncommon = Color3.fromRGB(90, 200, 90),
	Rare = Color3.fromRGB(90, 150, 255),
	Epic = Color3.fromRGB(190, 110, 245),
	Legendary = Color3.fromRGB(255, 175, 50),
}
local RARITIES = BossWeapons.Rarities -- Common .. Legendary, the ladder's own order
local RARITY_INDEX = {}
for i, name in ipairs(RARITIES) do RARITY_INDEX[name] = i end
local RUNGS = #RARITIES

local holder = Instance.new("Frame")
holder.AnchorPoint = Vector2.new(1, 0.5)
holder.Position = UDim2.new(1, -16, 0.5, 0)
holder.Size = UDim2.fromOffset(280, 420)
holder.BackgroundTransparency = 1

local gui = Instance.new("ScreenGui")
gui.Name = "SwordDropToast"
gui.ResetOnSpawn = false
-- The drop card is the one GUI a Studio capture stage wants left up while it holds the camera
-- (GuiShowcase hides every other ScreenGui so it does not cover the subject).
gui:SetAttribute("GuiShowcaseKeep", true)
gui.Parent = player:WaitForChild("PlayerGui")
holder.Parent = gui

local layout = Instance.new("UIListLayout", holder)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder

-- ═════════════════════════════════════════════════════════════════════════════
--  THE DROP REVEAL
-- ═════════════════════════════════════════════════════════════════════════════
-- [TUNING] the whole shape of the moment, in seconds and design-space pixels.
local LEAD = 0.18       -- the kill's own beat: the "+N Gold" over the corpse reads alone first
local ENTRY = 0.14      -- the wrapped sword falling into frame
local GAP_BASE = 0.035  -- the fastest tick of the climb
local GAP_SPAN = 0.185  -- ...and how much slower the last one is (cubic ramp: last ~220 ms)
local NEAR_MISS_CHANCE = 0.15 -- ordinary rolls that stop one rung short before the landing
local RESOLVE = 0.20    -- the silhouette cross-fading into the sword itself
local MOD_STEP = 0.08   -- each stat chip after the last
local EXIT = 0.22

-- Everything that scales with the tier that landed. This is what makes a Common cheap and a
-- Legendary an event: the climb is longer, the burst is bigger, the hold is longer, and only the
-- top of the ladder moves the camera, dips time or tells the whole server. [TUNING]
local TIER = {
	{ ticks = 5,  hold = 0.90, flash = 0.30, flashTime = 0.15, sparks = 8,  reach = 210, rings = 0, shake = 0,   dip = 0,    beams = 0, dim = 0.88, landHold = 0.10 },
	{ ticks = 6,  hold = 1.20, flash = 0.42, flashTime = 0.20, sparks = 14, reach = 260, rings = 1, shake = 0,   dip = 0,    beams = 0, dim = 0.82, landHold = 0.12 },
	{ ticks = 8,  hold = 1.80, flash = 0.55, flashTime = 0.26, sparks = 22, reach = 320, rings = 1, shake = 0,   dip = 0,    beams = 0, dim = 0.72, landHold = 0.14 },
	{ ticks = 10, hold = 2.60, flash = 0.70, flashTime = 0.34, sparks = 32, reach = 390, rings = 2, shake = 9,   dip = 0.18, beams = 0, dim = 0.58, landHold = 0.18 },
	{ ticks = 12, hold = 3.50, flash = 0.88, flashTime = 0.45, sparks = 44, reach = 470, rings = 2, shake = 15,  dip = 0.25, beams = 1, dim = 0.42, landHold = 0.22 },
}
local NEAR_HOLD = { 0.20, 0.20, 0.26, 0.34, 0.42 } -- the beat spent on the rung above the truth

-- The gap before the i-th tick of a climb of n: a cubic ramp, so the ladder blurs past at first
-- and ends on two readable beats (~120 ms, then ~220 ms).
local function tickGap(i: number, n: number): number
	local k = (i - 1) / math.max(n - 1, 1)
	return GAP_BASE + GAP_SPAN * k * k * k
end

-- 12,400 rather than 12400: a price has to be readable at a glance on a button.
local function comma(n: number?): string
	local out = string.format("%d", math.floor((tonumber(n) or 0) + 0.5))
	local k
	repeat out, k = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
	return out
end

local function oneInText(p: number?): string
	if typeof(p) ~= "number" or p <= 0 then return "1 IN ?" end
	local n = 1 / p
	if n >= 100 then return string.format("1 IN %d", math.floor(n + 0.5)) end
	if n >= 10 then return string.format("1 IN %.0f", n) end
	return string.format("1 IN %.1f", n)
end

-- The real rarity ladder this drop rolled on: the rig's rank decides it (DropRules.Plan), and
-- the client reads the very same published table the server rolled against.
local function ladderFor(rank: string?)
	if rank and rank ~= "boss" and BossWeapons.NormalRarityOdds[rank] then
		return BossWeapons.NormalRarityOdds[rank]
	end
	return BossWeapons.RarityOdds
end
local function oddsOf(ladder, index: number): number?
	local want = RARITIES[index]
	for _, row in ipairs(ladder) do
		if row.rarity == want then return row.p end
	end
	return nil
end

-- A client-side stand-in sword, for the card when the dropped Tool has not replicated yet.
local function standInSword(rarity)
	local t = PanelChrome.RARITY_TILE[rarity] or PanelChrome.RARITY_TILE.Common
	local tool = Instance.new("Tool")
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.44, 0.44, 1.0)
	handle.Color = Color3.fromRGB(92, 66, 50)
	handle.Parent = tool
	local function add(name, size, c0, color, material, shape, class)
		local p = Instance.new(class or "Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		if shape then (p :: any).Shape = shape end
		p.Parent = tool
		local w = Instance.new("Weld")
		w.Part0, w.Part1, w.C0 = handle, p, c0
		w.Parent = handle
	end
	local len, w, th = 2.5, 1.1, 0.26
	local bladeZ = -0.8 - len / 2
	local steel = Color3.fromRGB(216, 222, 234)
	add("Pommel", Vector3.new(0.66, 0.66, 0.66), CFrame.new(0, 0, 0.68), t.bottom, Enum.Material.Neon, Enum.PartType.Ball)
	add("Guard", Vector3.new(1.95, 0.4, 0.44), CFrame.new(0, 0, -0.6), Color3.fromRGB(226, 160, 36), Enum.Material.Metal)
	add("GuardGem", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0, -0.6), t.bottom, Enum.Material.Neon, Enum.PartType.Ball)
	add("Blade", Vector3.new(w, th, len), CFrame.new(0, 0, bladeZ), steel, Enum.Material.Metal)
	add("Fuller", Vector3.new(w * 0.3, th + 0.04, len * 0.82), CFrame.new(0, 0, bladeZ + len * 0.06), t.bottom, Enum.Material.Neon)
	local tipLen = w * 0.75
	for _, side in ipairs({ 1, -1 }) do
		add("Tip", Vector3.new(th, w / 2, tipLen), CFrame.new(side * w / 4, 0, bladeZ - len / 2 - tipLen / 2)
			* CFrame.Angles(0, 0, side == 1 and -math.pi / 2 or math.pi / 2), steel, Enum.Material.Metal, nil, "WedgePart")
	end
	return tool
end

-- The dropped Tool itself, by name, out of the bag the server just put it in.
local function droppedTool(fullName: string?): Tool?
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		local found = container and fullName and container:FindFirstChild(fullName)
		if found and found:IsA("Tool") then return found end
	end
	return nil
end

-- Stood almost upright (the card is taller than it is wide) and framed tight, so the blade fills
-- the card the way a crate's reward fills its podium. [TUNING]
local SWORD_POSE = { yawDeg = 16, tiltDeg = 18, margin = 1.12 }
local function renderSword(viewport, fullName, rarity): boolean
	local tool = droppedTool(fullName)
	if tool then
		if PanelChrome.renderTool(viewport, tool, SWORD_POSE) then return true end
	end
	local stand = standInSword(rarity)
	local ok = PanelChrome.renderTool(viewport, stand, SWORD_POSE)
	stand:Destroy()
	return ok
end

-- Wrap a rendered sword: every part flat black, so the shape reads and nothing else does.
local function blacken(viewport)
	viewport.Ambient = Color3.fromRGB(0, 0, 0)
	viewport.LightColor = Color3.fromRGB(0, 0, 0)
	for _, d in ipairs(viewport:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Color = Color3.fromRGB(10, 8, 20)
			d.Material = Enum.Material.SmoothPlastic
			d.Transparency = 0
			d.Reflectance = 0
			if d:IsA("MeshPart") then pcall(function() (d :: any).TextureID = "" end) end
		elseif d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture") then
			d:Destroy()
		end
	end
end

-- The sword turns slowly inside its viewport, so it reads as an object and not a picture.
-- The turn is applied AROUND the pose renderTool built, never instead of it: a one-part sword's
-- pivot carries that part's own rotation, so pivoting to a bare CFrame would stand the blade on
-- end and point it at the camera. Keep the base pivot and rotate about the frame's own centre.
local swayBase = setmetatable({}, { __mode = "k" })
local function swayViewport(viewport, t: number)
	local world = viewport:FindFirstChildOfClass("WorldModel")
	if not world then return end
	local base = swayBase[world]
	if not base then
		base = world:GetPivot()
		swayBase[world] = base
	end
	local c = base.Position
	local turn = CFrame.Angles(0, math.sin(t * 0.7) * 0.18, 0) * CFrame.Angles(0, 0, math.sin(t * 0.47) * 0.10)
	world:PivotTo(CFrame.new(c) * turn * CFrame.new(-c) * base)
end

-- ── the stage, built once ────────────────────────────────────────────────────
local W, H = 1000, 642
local CARD_W, CARD_H, CARD_TOP = 340, 380, 40
local CARD_CX, CARD_CY = W / 2, CARD_TOP + CARD_H / 2
local NAME_Y, BAND_Y, ODDS_Y, MODS_Y, FOOT_Y = 432, 490, 550, 586, 616
local RAIL_X, RAIL_TOP, RAIL_STEP, PIP = 704, 64, 46, 30
local INFO_X, INFO_TOP, INFO_STEP = 16, 64, 32

local revealGui = Instance.new("ScreenGui")
revealGui.Name = "SwordDropReveal"
revealGui.ResetOnSpawn = false
revealGui.IgnoreGuiInset = true
revealGui.DisplayOrder = 16 -- above the HUD and combat streak, below modal panels (20+)
revealGui.Enabled = false
revealGui:SetAttribute("GuiShowcaseKeep", true)
revealGui.Parent = player:WaitForChild("PlayerGui")

-- A dim behind the reveal so the sword reads over the world. It takes no input: play goes on.
local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = DARK
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.Active = false
dim.ZIndex = 1
dim.Parent = revealGui

local screenFlash = Instance.new("Frame")
screenFlash.Name = "Flash"
screenFlash.Size = UDim2.fromScale(1, 1)
screenFlash.BackgroundColor3 = WHITE
screenFlash.BackgroundTransparency = 1
screenFlash.BorderSizePixel = 0
screenFlash.Active = false
screenFlash.ZIndex = 40
screenFlash.Parent = revealGui

local root = Instance.new("Frame")
root.Name = "Stage"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromOffset(W, H)
root.BackgroundTransparency = 1
root.Active = false
root.ZIndex = 2
root.Parent = revealGui
local rootScale = Instance.new("UIScale")
rootScale.Parent = root
PanelChrome.onViewport(function(vp)
	rootScale.Scale = math.clamp(math.min(vp.X / (W + 40), vp.Y / (H + 20)), 0.3, 1.5)
end)

-- Beams and soft discs behind the card: the live rung's colour spilling off it.
local rayHolder = Instance.new("Frame")
rayHolder.Name = "Rays"
rayHolder.AnchorPoint = Vector2.new(0.5, 0.5)
rayHolder.Position = UDim2.fromOffset(CARD_CX, CARD_CY)
rayHolder.Size = UDim2.fromOffset(1400, 1400)
rayHolder.BackgroundTransparency = 1
rayHolder.ZIndex = 2
rayHolder.Parent = root
local rayBars = {}
for i = 1, 12 do
	local ray = Instance.new("Frame")
	ray.AnchorPoint = Vector2.new(0.5, 0.5)
	ray.Position = UDim2.fromScale(0.5, 0.5)
	ray.Size = UDim2.fromOffset(22, 1400)
	ray.Rotation = (i - 1) * (180 / 12)
	ray.BackgroundColor3 = WHITE
	ray.BackgroundTransparency = 1
	ray.BorderSizePixel = 0
	ray.ZIndex = 2
	ray.Parent = rayHolder
	rayBars[i] = ray
end
local glows = {}
for i, spec in ipairs({ { 420, 0.5 }, { 560, 0.68 }, { 700, 0.84 } }) do
	local g = Instance.new("Frame")
	g.Name = "Glow" .. i
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromOffset(CARD_CX, CARD_CY)
	g.Size = UDim2.fromOffset(spec[1], spec[1])
	g.BackgroundColor3 = WHITE
	g.BackgroundTransparency = 1
	g.BorderSizePixel = 0
	g.ZIndex = 3
	g.Parent = root
	PanelChrome.corner(g, math.floor(spec[1] / 2))
	glows[i] = { frame = g, rest = spec[2], size = spec[1] }
end

-- The full-screen beam the top of the ladder fires.
local beamHolder = Instance.new("Frame")
beamHolder.Name = "Beam"
beamHolder.AnchorPoint = Vector2.new(0.5, 0.5)
beamHolder.Position = UDim2.fromOffset(CARD_CX, CARD_CY)
beamHolder.Size = UDim2.fromOffset(2400, 2400)
beamHolder.BackgroundTransparency = 1
beamHolder.Rotation = 0
beamHolder.ZIndex = 4
beamHolder.Parent = root
local beams = {}
for i = 1, 2 do
	local b = Instance.new("Frame")
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.fromScale(0.5, 0.5)
	b.Size = UDim2.fromOffset(i == 1 and 2400 or 240, i == 1 and 240 or 2400)
	b.BackgroundColor3 = WHITE
	b.BackgroundTransparency = 1
	b.BorderSizePixel = 0
	b.ZIndex = 4
	b.Parent = beamHolder
	beams[i] = b
end

local headline = PanelChrome.display(root, {
	name = "Headline", text = "", size = 34, stroke = 4, zIndex = 12, color = WHITE,
	pos = UDim2.fromOffset(0, 2), size2 = UDim2.new(1, 0, 0, 36), scaled = true, minSize = 16,
})

-- The card: the sword's own shape, wrapped in black until the landing.
local card = Instance.new("Frame")
card.Name = "MysteryCard"
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.fromOffset(CARD_CX, CARD_TOP)
card.Size = UDim2.fromOffset(CARD_W, CARD_H)
card.BackgroundColor3 = WHITE
card.BorderSizePixel = 0
card.ZIndex = 6
card.Parent = root
PanelChrome.corner(card, 30)
local cardGrad = PanelChrome.gradient(card, WHITE, WHITE)
PanelChrome.stroke(card, BRIGHT.Outline, 6)
local cardScale = Instance.new("UIScale")
cardScale.Parent = card

local qmark = PanelChrome.display(card, {
	name = "Question", text = "?", size = 250, stroke = 9, zIndex = 10, color = WHITE,
	pos = UDim2.fromOffset(0, 30), size2 = UDim2.new(1, 0, 1, -60),
})
qmark.TextTransparency = 0.45
local qmarkStroke = qmark:FindFirstChildOfClass("UIStroke")

-- The well the sword stands in: the rung's colour while the drop is wrapped (a black shape on a
-- bright field), and a dark showcase once the real blade is out (metal on dark).
local well = Instance.new("Frame")
well.Name = "Well"
well.Position = UDim2.fromOffset(14, 14)
well.Size = UDim2.fromOffset(CARD_W - 28, CARD_H - 28)
well.BackgroundColor3 = WHITE
well.BorderSizePixel = 0
well.ZIndex = 7
well.Parent = card
PanelChrome.corner(well, 22)
local wellGrad = PanelChrome.gradient(well, WHITE, WHITE)

local silView = Instance.new("ViewportFrame")
silView.Name = "Wrapped"
silView.BackgroundTransparency = 1
silView.Position = UDim2.fromOffset(18, 18)
silView.Size = UDim2.fromOffset(CARD_W - 36, CARD_H - 36) -- 304 x 344 design px
silView.ZIndex = 8
silView.Parent = card
local realView = Instance.new("ViewportFrame")
realView.Name = "Sword"
realView.BackgroundTransparency = 1
realView.ImageTransparency = 1
realView.Position = UDim2.fromOffset(18, 18)
realView.Size = UDim2.fromOffset(CARD_W - 36, CARD_H - 36)
realView.ZIndex = 9
realView.Parent = card

local cardFlash = Instance.new("Frame")
cardFlash.Name = "CardFlash"
cardFlash.BackgroundColor3 = WHITE
cardFlash.BackgroundTransparency = 1
cardFlash.BorderSizePixel = 0
cardFlash.Size = UDim2.fromScale(1, 1)
cardFlash.ZIndex = 11
cardFlash.Parent = card
PanelChrome.corner(cardFlash, 30)

-- The ladder, beside the card: every rarity this kill could have paid, in its own colour, with
-- the true odds of each rung, and the live one lit.
local pips = {}
for index = RUNGS, 1, -1 do
	local row = RUNGS - index
	local holderFrame = Instance.new("Frame")
	holderFrame.Name = "Rung" .. index
	holderFrame.Position = UDim2.fromOffset(RAIL_X, RAIL_TOP + row * RAIL_STEP)
	holderFrame.Size = UDim2.fromOffset(W - RAIL_X - 14, PIP)
	holderFrame.BackgroundTransparency = 1
	holderFrame.ZIndex = 10
	holderFrame.Parent = root
	local s = Instance.new("UIScale")
	s.Parent = holderFrame
	local c = RARITY_COLOR[RARITIES[index]] or WHITE
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Position = UDim2.fromOffset(0, PIP / 2)
	dot.Size = UDim2.fromOffset(PIP, PIP)
	dot.Rotation = 45
	dot.BackgroundColor3 = c
	dot.BorderSizePixel = 0
	dot.ZIndex = 11
	dot.Parent = holderFrame
	PanelChrome.corner(dot, 7)
	PanelChrome.gradient(dot, c:Lerp(WHITE, 0.45), c)
	local dotStroke = PanelChrome.stroke(dot, BRIGHT.Outline, 2.5)
	local nameLabel = PanelChrome.display(holderFrame, {
		name = "Name", text = string.upper(RARITIES[index]), size = 22, stroke = 3, zIndex = 11,
		color = c:Lerp(WHITE, 0.5), xAlign = Enum.TextXAlignment.Left,
		pos = UDim2.fromOffset(PIP + 12, 0), size2 = UDim2.fromOffset(150, PIP),
	})
	local oddsLabel = PanelChrome.display(holderFrame, {
		name = "Odds", text = "", size = 19, stroke = 2.5, zIndex = 11,
		color = Color3.fromRGB(246, 238, 214), xAlign = Enum.TextXAlignment.Left,
		pos = UDim2.fromOffset(PIP + 168, 0), size2 = UDim2.fromOffset(110, PIP),
	})
	pips[index] = { holder = holderFrame, scale = s, dot = dot, stroke = dotStroke, name = nameLabel, odds = oddsLabel }
end

-- The left column: where the drop came from and what it cost to get.
local infoRows = {}
for i = 1, 4 do
	infoRows[i] = PanelChrome.display(root, {
		name = "Info" .. i, text = "", size = 20, stroke = 2.5, zIndex = 10,
		color = Color3.fromRGB(248, 240, 214), xAlign = Enum.TextXAlignment.Left,
		pos = UDim2.fromOffset(INFO_X, INFO_TOP + (i - 1) * INFO_STEP), size2 = UDim2.fromOffset(300, INFO_STEP - 4),
		scaled = true, minSize = 11,
	})
end

local nameLabel = PanelChrome.display(root, {
	name = "SwordName", text = "", size = 46, stroke = 5, zIndex = 12, color = WHITE,
	pos = UDim2.fromOffset(0, NAME_Y), size2 = UDim2.new(1, 0, 0, 50), scaled = true, minSize = 20,
})
local nameScale = Instance.new("UIScale")
nameScale.Parent = nameLabel

-- The tier band: the one strip that always carries this roll's colour and its word.
local band = Instance.new("Frame")
band.Name = "TierBand"
band.AnchorPoint = Vector2.new(0.5, 0)
band.Position = UDim2.fromOffset(W / 2, BAND_Y)
band.Size = UDim2.fromOffset(520, 54)
band.BackgroundColor3 = WHITE
band.BorderSizePixel = 0
band.ZIndex = 10
band.Parent = root
PanelChrome.corner(band, 27)
local bandGrad = PanelChrome.gradient(band, WHITE, WHITE)
PanelChrome.stroke(band, BRIGHT.Outline, 5)
local bandScale = Instance.new("UIScale")
bandScale.Parent = band
local bandWord = PanelChrome.display(band, {
	name = "Tier", text = "", size = 36, stroke = 4.5, zIndex = 11, color = WHITE,
	pos = UDim2.fromOffset(0, 0), size2 = UDim2.fromScale(1, 1), scaled = true, minSize = 18,
})

-- The odds of the rung that landed, on their own line. These are the server's own numbers.
local oddsLabel = PanelChrome.display(root, {
	name = "Odds", text = "", size = 30, stroke = 4, zIndex = 12, color = WHITE,
	pos = UDim2.fromOffset(0, ODDS_Y), size2 = UDim2.new(1, 0, 0, 32), scaled = true, minSize = 16,
})

-- The stat chips: the damage the sword rolled, each modifier with its true 1-in-N, Blessed.
local chipRow = Instance.new("Frame")
chipRow.Name = "Chips"
chipRow.AnchorPoint = Vector2.new(0.5, 0)
chipRow.Position = UDim2.fromOffset(W / 2, MODS_Y)
chipRow.Size = UDim2.fromOffset(W - 60, 28)
chipRow.BackgroundTransparency = 1
chipRow.ZIndex = 10
chipRow.Parent = root
local chipLayout = Instance.new("UIListLayout")
chipLayout.FillDirection = Enum.FillDirection.Horizontal
chipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
chipLayout.VerticalAlignment = Enum.VerticalAlignment.Center
chipLayout.Padding = UDim.new(0, 8)
chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
chipLayout.Parent = chipRow
local chips = {}
for i = 1, 5 do
	local f = Instance.new("Frame")
	f.Name = "Chip" .. i
	f.Size = UDim2.fromOffset(0, 28)
	f.AutomaticSize = Enum.AutomaticSize.X
	f.BackgroundColor3 = WHITE
	f.LayoutOrder = i
	f.Visible = false
	f.ZIndex = 10
	f.Parent = chipRow
	PanelChrome.corner(f, 14)
	local grad = PanelChrome.gradient(f, WHITE, WHITE)
	PanelChrome.stroke(f, BRIGHT.Outline, 2.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = f
	local l = PanelChrome.display(f, { text = "", size = 20, stroke = 2.5, zIndex = 11, color = BRIGHT.Ink })
	l.Size = UDim2.fromScale(0, 1)
	l.AutomaticSize = Enum.AutomaticSize.X
	local s = Instance.new("UIScale")
	s.Parent = f
	chips[i] = { frame = f, grad = grad, label = l, scale = s }
end

-- The close: why to go and kill the next one.
local footLabel = PanelChrome.display(root, {
	name = "NextRoll", text = "", size = 24, stroke = 3.5, zIndex = 12, color = Color3.fromRGB(255, 238, 178),
	pos = UDim2.fromOffset(0, FOOT_Y), size2 = UDim2.new(1, 0, 0, 24), scaled = true, minSize = 12,
})

local sparkHolder = Instance.new("Frame")
sparkHolder.Name = "Sparks"
sparkHolder.Size = UDim2.fromScale(1, 1)
sparkHolder.BackgroundTransparency = 1
sparkHolder.ZIndex = 20
sparkHolder.Parent = root

-- ── effects ─────────────────────────────────────────────────────────────────
local function sparkBurst(count: number, tint: Color3, reach: number)
	for i = 1, count do
		local s = Instance.new("Frame")
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.fromOffset(CARD_CX, CARD_CY)
		local size = math.random(12, 38)
		s.Size = UDim2.fromOffset(size, size)
		s.Rotation = math.random(0, 90)
		s.BackgroundColor3 = if i % 3 == 0 then Color3.fromRGB(255, 252, 226)
			elseif i % 3 == 1 then tint else tint:Lerp(WHITE, 0.55)
		s.BorderSizePixel = 0
		s.ZIndex = 21
		s.Parent = sparkHolder
		PanelChrome.corner(s, math.floor(size / 3))
		local angle = math.rad(math.random(0, 359))
		local r = reach * math.random(50, 135) / 100
		local life = math.random(50, 110) / 100
		TweenService:Create(s, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(CARD_CX + math.cos(angle) * r, CARD_CY + math.sin(angle) * r + r * 0.16),
			BackgroundTransparency = 1, Rotation = s.Rotation + math.random(-280, 280), Size = UDim2.fromOffset(4, 4),
		}):Play()
		task.delay(life + 0.06, function() s:Destroy() end)
	end
end

local function shockRing(tint: Color3, to: number, time: number)
	local r = Instance.new("Frame")
	r.AnchorPoint = Vector2.new(0.5, 0.5)
	r.Position = UDim2.fromOffset(CARD_CX, CARD_CY)
	r.Size = UDim2.fromOffset(180, 180)
	r.BackgroundTransparency = 1
	r.BorderSizePixel = 0
	r.ZIndex = 19
	r.Parent = sparkHolder
	PanelChrome.corner(r, 600)
	local stroke = PanelChrome.stroke(r, tint, 16)
	TweenService:Create(r, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(to, to) }):Play()
	TweenService:Create(stroke, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = 1, Thickness = 2 }):Play()
	task.delay(time + 0.05, function() r:Destroy() end)
end

-- Screen shake: the top of the ladder only, and never long enough to cost a swing.
local shakeMag, shakeUntil = 0, 0
RunService.RenderStepped:Connect(function()
	if os.clock() > shakeUntil then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	local k = shakeMag / 180
	camera.CFrame = camera.CFrame * CFrame.new(math.random(-100, 100) / 100 * k, math.random(-100, 100) / 100 * k, 0)
end)

-- Paint the whole stage in one rung's colour: the card, its glow, the rays, the band and the
-- rung lit on the ladder. This is the only thing a tick of the climb does.
local litIndex = nil
local function setTint(index: number, pop: number?)
	local rarity = RARITIES[index] or RARITIES[1]
	local c = RARITY_COLOR[rarity] or WHITE
	cardGrad.Color = ColorSequence.new(c:Lerp(WHITE, 0.32), c:Lerp(DARK, 0.3))
	wellGrad.Color = ColorSequence.new(c:Lerp(WHITE, 0.6), c:Lerp(WHITE, 0.2))
	bandGrad.Color = ColorSequence.new(c:Lerp(WHITE, 0.28), c:Lerp(DARK, 0.32))
	bandWord.Text = string.upper(rarity)
	for _, g in ipairs(glows) do g.frame.BackgroundColor3 = c end
	for _, ray in ipairs(rayBars) do ray.BackgroundColor3 = c:Lerp(WHITE, 0.5) end
	if litIndex and pips[litIndex] then
		pips[litIndex].scale.Scale = 1
		pips[litIndex].stroke.Thickness = 2.5
		pips[litIndex].name.TextTransparency = 0.45
		pips[litIndex].odds.TextTransparency = 0.5
	end
	litIndex = index
	local pip = pips[index]
	if pip then
		pip.scale.Scale = 1.24
		pip.stroke.Thickness = 5
		pip.name.TextTransparency = 0
		pip.odds.TextTransparency = 0
	end
	if pop then
		cardScale.Scale = pop
		TweenService:Create(cardScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

-- ── the reveal itself ───────────────────────────────────────────────────────
local playToken = 0
local liveUntil = 0 -- while the stage is up, the RenderStepped loop keeps the sword turning

RunService.RenderStepped:Connect(function(dt)
	if not revealGui.Enabled then return end
	rayHolder.Rotation = (rayHolder.Rotation + dt * 12) % 360
	local t = os.clock()
	swayViewport(if realView.ImageTransparency < 0.5 then realView else silView, t)
end)

-- ═════════════════════════════════════════════════════════════════════════════
--  THE PICKUP PROMPT  --  KEEP or SELL, once, on the sword that just landed
-- ═════════════════════════════════════════════════════════════════════════════
-- It lives in its OWN ScreenGui, in real screen pixels rather than in the reveal's design-space
-- stage, for one reason: the stage is scaled to fit the viewport, and on a phone that scale turns
-- a comfortable button into a 20-pixel one. A thing the player has to hit with a thumb is sized
-- in the units their thumb is in.
--
-- Where it sits: bottom centre, held clear of the two places a phone already owns -- the movement
-- stick at the bottom left and the jump button at the bottom right -- by capping the bar's width
-- and lifting it off the bottom edge. Nothing in it is modal, and the bar's own frame takes no
-- input; only the two buttons do.
local PROMPT_SECONDS_FALLBACK = 12   -- used only if the server sent no window with the offer
local PROMPT_BAR_H = 112
local PROMPT_BTN_H = 58              -- comfortably over the 44 px a thumb needs

local promptGui = Instance.new("ScreenGui")
promptGui.Name = "SwordPickupPrompt"
promptGui.ResetOnSpawn = false
promptGui.IgnoreGuiInset = true
promptGui.DisplayOrder = 17 -- just above the reveal, still below modal panels (20+)
promptGui.Enabled = false
promptGui:SetAttribute("GuiShowcaseKeep", true)
promptGui.Parent = player:WaitForChild("PlayerGui")

local promptBar = Instance.new("Frame")
promptBar.Name = "Bar"
promptBar.AnchorPoint = Vector2.new(0.5, 1)
promptBar.BackgroundColor3 = DARK
promptBar.BackgroundTransparency = 0.08
promptBar.BorderSizePixel = 0
promptBar.Active = false -- the bar itself never swallows a click; only the buttons do
promptBar.Size = UDim2.fromOffset(460, PROMPT_BAR_H)
promptBar.Position = UDim2.new(0.5, 0, 1, -130)
promptBar.Parent = promptGui
PanelChrome.corner(promptBar, 18)
PanelChrome.stroke(promptBar, BRIGHT.Outline, 3)

-- Width and height off the bottom, per viewport: narrow enough on a phone that the movement
-- stick and the jump button are never underneath it.
PanelChrome.onViewport(function(vp)
	local w = math.clamp(vp.X * 0.56, 300, 480)
	promptBar.Size = UDim2.fromOffset(math.floor(w), PROMPT_BAR_H)
	promptBar.Position = UDim2.new(0.5, 0, 1, -math.floor(math.max(120, vp.Y * 0.16)))
end)

local promptTitle = PanelChrome.display(promptBar, {
	name = "What", text = "", size = 19, stroke = 2.5, zIndex = 12, color = WHITE,
	pos = UDim2.fromOffset(12, 8), size2 = UDim2.new(1, -24, 0, 22), scaled = true, minSize = 11,
})
local promptSub = PanelChrome.display(promptBar, {
	name = "Worth", text = "", size = 15, stroke = 2, zIndex = 12, color = Color3.fromRGB(246, 230, 180),
	pos = UDim2.fromOffset(12, 28), size2 = UDim2.new(1, -24, 0, 18), scaled = true, minSize = 10,
})

local function promptButton(name, text, color, colorDark, xScale)
	local btn, label = PanelChrome.chunkyButton(promptBar, {
		name = name, text = text, color = color, colorDark = colorDark,
		size = UDim2.new(0.5, -14, 0, PROMPT_BTN_H), textSize = 24, zIndex = 13,
		anchor = Vector2.new(0, 1), pos = UDim2.new(xScale, xScale == 0 and 10 or 4, 1, -8),
	})
	return btn, label
end
local keepBtn, keepLabel = promptButton("Keep", "KEEP", BRIGHT.Green, BRIGHT.GreenDark, 0)
local sellBtn, sellLabel = promptButton("Sell", "SELL", BRIGHT.Gold, BRIGHT.GoldDark, 0.5)

-- The countdown: a hairline under the title that runs out rather than a number ticking down.
local promptTimer = Instance.new("Frame")
promptTimer.Name = "Timer"
promptTimer.BackgroundColor3 = BRIGHT.Gold
promptTimer.BorderSizePixel = 0
promptTimer.Position = UDim2.fromOffset(12, 48)
promptTimer.Size = UDim2.new(1, -24, 0, 3)
promptTimer.ZIndex = 12
promptTimer.Parent = promptBar
PanelChrome.corner(promptTimer, 2)

-- The one piece of state: which offer the bar is showing, and whether a press is in flight. The
-- server is the authority on all of it -- this only stops the same button being fired twice.
local promptOffer = nil   -- the offer id on screen, or nil
local promptSent = false  -- a press is awaiting the server's answer
local promptToken = 0

local function hidePrompt(delaySeconds: number?)
	local token = promptToken
	if (delaySeconds or 0) <= 0 then
		promptOffer, promptSent = nil, false
		promptGui.Enabled = false
		return
	end
	task.delay(delaySeconds, function()
		if promptToken ~= token then return end
		promptOffer, promptSent = nil, false
		promptGui.Enabled = false
	end)
end

local function showPrompt(offerId: string, value: number, fullName: string?, rarityName: string?, seconds: number?)
	promptToken += 1
	local token = promptToken
	promptOffer, promptSent = offerId, false
	local window = tonumber(seconds) or PROMPT_SECONDS_FALLBACK

	promptTitle.Text = string.upper(tostring(fullName or "A SWORD"))
	promptTitle.TextColor3 = RARITY_COLOR[rarityName] or WHITE
	promptSub.Text = string.format("%s  ·  KEEP IT, OR SELL IT FOR %s GOLD", string.upper(tostring(rarityName or "")),
		comma(value))
	keepLabel.Text = "KEEP"
	sellLabel.Text = "SELL  " .. comma(value)
	keepBtn.Active, sellBtn.Active = true, true
	keepBtn.Visible, sellBtn.Visible = true, true
	promptTimer.Size = UDim2.new(1, -24, 0, 3)
	promptTimer.BackgroundColor3 = BRIGHT.Gold
	promptGui.Enabled = true
	AudioManager.PlaySFX("reveal_lock", promptGui, { PlaybackSpeed = 0.9, Volume = 0.25 })

	-- The countdown. Running out is KEEP: the sword is in the bag already and stays there.
	task.spawn(function()
		local t0 = os.clock()
		while promptToken == token and promptGui.Enabled do
			local left = 1 - (os.clock() - t0) / window
			if left <= 0 then break end
			promptTimer.Size = UDim2.new(left, -24 * left, 0, 3)
			RunService.RenderStepped:Wait()
		end
		if promptToken ~= token then return end
		if not promptSent then
			promptTitle.Text = "KEPT"
			promptSub.Text = "IT IS IN YOUR BACKPACK. THE INVENTORY SELLS IT FOR THE SAME PRICE."
			promptTitle.TextColor3 = WHITE
			keepBtn.Visible, sellBtn.Visible = false, false
			hidePrompt(1.2)
		end
	end)
end

-- A press is a request. The button locks here so a second tap cannot even leave the client, and
-- the server's own one-sword-one-outcome rule catches anything that does.
local function answer(choice: string)
	local offerId = promptOffer
	if not offerId or promptSent then return end
	promptSent = true
	keepBtn.Active, sellBtn.Active = false, false
	if choice == "SELL" then
		sellLabel.Text = "SELLING..."
	else
		keepLabel.Text = "KEPT"
	end
	PICKUP_EVENT:FireServer(offerId, choice)
end
keepBtn.Activated:Connect(function() answer("KEEP") end)
sellBtn.Activated:Connect(function() answer("SELL") end)

-- The server's answer. Only ever the last word: nothing above this changed a purse.
PICKUP_EVENT.OnClientEvent:Connect(function(offerId, result, gold, reason)
	if offerId ~= promptOffer then return end
	promptToken += 1 -- stop the countdown; this offer is decided
	keepBtn.Visible, sellBtn.Visible = false, false
	promptTimer.Size = UDim2.new(0, 0, 0, 3)
	if result == "SOLD" then
		promptTitle.Text = "SOLD"
		promptTitle.TextColor3 = BRIGHT.Gold
		promptSub.Text = string.format("+%s GOLD", comma(tonumber(gold) or 0))
		AudioManager.PlaySFX("reveal_lock", promptGui, { PlaybackSpeed = 1.3, Volume = 0.45 })
	elseif result == "KEPT" then
		promptTitle.Text = "KEPT"
		promptTitle.TextColor3 = WHITE
		promptSub.Text = "IT IS IN YOUR BACKPACK."
	else
		promptTitle.Text = "NOT SOLD"
		promptTitle.TextColor3 = Color3.fromRGB(255, 130, 130)
		promptSub.Text = if reason == "equipped" then "UNEQUIP IT FIRST, THEN SELL IT FROM THE INVENTORY."
			elseif reason == "expired" then "THE OFFER RAN OUT -- IT IS YOURS. SELL IT FROM THE INVENTORY."
			else "THAT SWORD IS NO LONGER IN YOUR BACKPACK."
	end
	promptOffer, promptSent = nil, false
	local token = promptToken
	task.delay(1.6, function()
		if promptToken ~= token then return end
		promptGui.Enabled = false
	end)
end)

-- extras (sixth argument, from the server): pool = the pool it came from (a boss, or the zone
-- whose lesser pool an ordinary enemy rolls), source = the enemy that dropped it, lesser = true
-- for a lesser (normal-enemy) sword, dropChance = that enemy's real per-kill chance, pity = true
-- if the drop was the pity credit paying out, rank = the rig's rank (which rarity ladder it
-- rolled), luck = the killer's live luck, listedBase = the pool's listed base at this rarity,
-- rarityOdds = the REAL chance of this rarity variant, legendary = the pool's showpiece.
local function revealDrop(rarityName, mult, fullName, mods, gotExtraSlot, extras)
	mods = mods or {}
	extras = typeof(extras) == "table" and extras or {}
	playToken += 1
	local token = playToken
	local landIndex = RARITY_INDEX[rarityName] or 1
	local spec = TIER[landIndex]
	local landColor = RARITY_COLOR[rarityName] or WHITE
	local ladder = ladderFor(extras.rank)
	local landOdds = extras.rarityOdds or oddsOf(ladder, landIndex)

	task.spawn(function()
		local t0 = os.clock()
		-- The kill's own beat: the corpse, its burst and the "+N Gold" over it read alone before
		-- anything of the drop is on screen.
		task.wait(LEAD)
		if playToken ~= token then return end

		-- Fill the rail with the real ladder this kill rolled on.
		for index = 1, RUNGS do
			local p = oddsOf(ladder, index)
			pips[index].odds.Text = if p then oneInText(p) else ""
			pips[index].scale.Scale = 1
			pips[index].stroke.Thickness = 2.5
			pips[index].name.TextTransparency = 0.45
			pips[index].odds.TextTransparency = 0.5
		end
		litIndex = nil

		-- The left column: the kill that paid, and at what rate.
		local info = {}
		table.insert(info, string.upper(tostring(extras.source or extras.pool or "A KILL")) .. " DROPPED IT")
		if typeof(extras.dropChance) == "number" and extras.dropChance > 0 then
			table.insert(info, string.format("%.1f%% PER KILL  ·  %s", extras.dropChance * 100, oneInText(extras.dropChance)))
		end
		if typeof(extras.luck) == "number" then
			table.insert(info, string.format("LUCK  %.2fx", extras.luck))
		end
		if extras.pity then table.insert(info, "PITY PAID OUT") end
		if typeof(extras.sellValue) == "number" and extras.sellValue > 0 then
			table.insert(info, string.format("WORTH %s GOLD", comma(extras.sellValue)))
		end
		for i, row in ipairs(infoRows) do
			row.Text = info[i] or ""
			row.Visible = info[i] ~= nil
		end

		-- The wrapped sword: the drop's own shape, in black, with nothing named yet.
		renderSword(silView, fullName, rarityName)
		blacken(silView)
		silView:SetAttribute("Posed", true)
		silView.ImageTransparency = 0
		realView.ImageTransparency = 1
		for _, chip in ipairs(chips) do chip.frame.Visible = false end
		qmark.Visible = true
		qmark.TextTransparency = 0.45
		if qmarkStroke then qmarkStroke.Transparency = 0 end
		cardFlash.BackgroundTransparency = 1
		headline.Text = "SOMETHING DROPPED"
		headline.TextColor3 = WHITE
		nameLabel.Text = "? ? ?"
		nameScale.Scale = 1
		oddsLabel.Text = "1 IN ?"
		oddsLabel.TextColor3 = WHITE
		footLabel.Text = ""
		bandScale.Scale = 1
		setTint(1)
		for _, g in ipairs(glows) do
			g.frame.Size = UDim2.fromOffset(g.size, g.size)
			g.frame.BackgroundTransparency = g.rest
		end
		for _, ray in ipairs(rayBars) do ray.BackgroundTransparency = 0.9 end
		for _, b in ipairs(beams) do b.BackgroundTransparency = 1 end
		screenFlash.BackgroundTransparency = 1
		dim.BackgroundTransparency = 1
		revealGui.Enabled = true

		-- It falls into frame.
		cardScale.Scale = 0.55
		TweenService:Create(cardScale, TweenInfo.new(ENTRY + 0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(dim, TweenInfo.new(0.22), { BackgroundTransparency = 0.9 }):Play()
		AudioManager.PlaySFX("sword_drop", revealGui, { PlaybackSpeed = 0.75, Volume = 0.5 })
		task.wait(ENTRY)
		if playToken ~= token then return end

		-- THE CLIMB. The ladder runs upward, wrapping, slowing as it goes. A rung flashed here
		-- decides nothing: the server rolled before the first frame of this.
		-- The near miss: about one roll in six, and ALWAYS at the top two rungs, where the beat
		-- spent one rung short is the whole payoff ("...Epic. no -- LEGENDARY").
		local nearMiss = landIndex >= 4 or math.random() < NEAR_MISS_CHANCE
		local nearIndex = if landIndex >= RUNGS then landIndex - 1 else landIndex + 1
		local endIndex = if nearMiss then nearIndex else landIndex
		local ticks = spec.ticks
		local climbStart = os.clock()
		for i = 1, ticks do
			if playToken ~= token then return end
			local rung = ((endIndex - (ticks - i) - 1) % RUNGS) + 1
			setTint(rung, 1.05)
			AudioManager.PlaySFX("reveal_tick", revealGui, { PlaybackSpeed = 1.1 + 0.075 * i, Volume = 0.2 + 0.02 * i })
			-- Every gap is waited out, the last one included: the ladder arrives at its answer and
			-- HANGS there a beat before the burst, so even a Common is withheld ~460 ms.
			task.wait(tickGap(i, ticks))
		end
		local climbMs = (os.clock() - climbStart) * 1000

		-- The near miss: a beat spent one rung ABOVE the truth, with the card shivering.
		local nearMs = 0
		if nearMiss then
			AudioManager.PlaySFX("reveal_tick", revealGui, { PlaybackSpeed = 0.7, Volume = 0.45 })
			local until_ = os.clock() + (NEAR_HOLD[landIndex] or 0.2)
			while os.clock() < until_ do
				if playToken ~= token then return end
				card.Rotation = math.sin((until_ - os.clock()) * 44) * 1.6
				RunService.RenderStepped:Wait()
			end
			card.Rotation = 0
			nearMs = (NEAR_HOLD[landIndex] or 0.2) * 1000
		end

		-- THE LANDING. Everything from here is the server's answer, and all of it is scaled to it.
		if playToken ~= token then return end
		local landAt = os.clock() - t0
		setTint(landIndex, 1.2)
		local heat = landIndex / RUNGS
		AudioManager.PlaySFX("reveal_land", revealGui, { PlaybackSpeed = 0.8 + 0.5 * heat, Volume = 0.55 + 0.5 * heat })
		sparkBurst(spec.sparks, landColor, spec.reach)
		for i = 1, spec.rings do
			shockRing(if i == 1 then landColor else WHITE, 420 + landIndex * 130, 0.34 + 0.05 * landIndex)
		end
		if spec.shake > 0 then
			shakeMag = spec.shake
			shakeUntil = os.clock() + 0.14 + 0.03 * landIndex
		end
		screenFlash.BackgroundColor3 = landColor:Lerp(WHITE, 0.55)
		screenFlash.BackgroundTransparency = 1 - spec.flash
		TweenService:Create(screenFlash, TweenInfo.new(spec.flashTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }):Play()
		TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = spec.dim }):Play()
		for _, ray in ipairs(rayBars) do
			ray.BackgroundTransparency = math.max(0.86 - 0.11 * landIndex, 0.3)
			TweenService:Create(ray, TweenInfo.new(0.8), { BackgroundTransparency = math.max(0.92 - 0.07 * landIndex, 0.55) }):Play()
		end
		for _, g in ipairs(glows) do
			g.frame.BackgroundTransparency = math.max(g.rest - 0.32, 0)
			g.frame.Size = UDim2.fromOffset(g.size * 1.22, g.size * 1.22)
			TweenService:Create(g.frame, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundTransparency = math.max(g.rest - 0.14, 0), Size = UDim2.fromOffset(g.size * 1.06, g.size * 1.06) }):Play()
		end
		if spec.beams > 0 then
			for _, b in ipairs(beams) do
				b.BackgroundColor3 = landColor:Lerp(WHITE, 0.7)
				b.BackgroundTransparency = 0.25
				TweenService:Create(b, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundTransparency = 1 }):Play()
			end
		end
		headline.Text = string.upper(rarityName or "") .. "!"
		headline.TextColor3 = landColor:Lerp(WHITE, 0.45)
		-- ...and this is where the choice arrives: the tier is known, so the price means
		-- something. A second drop landing while this one is still open simply replaces it --
		-- the sword it was offering stays in the bag, kept, and sells for the same price there.
		if typeof(extras.offerId) == "string" and typeof(extras.sellValue) == "number" and extras.sellValue > 0 then
			showPrompt(extras.offerId, extras.sellValue, fullName, rarityName, extras.promptSeconds)
		end
		oddsLabel.Text = oneInText(landOdds)
		oddsLabel.TextColor3 = landColor:Lerp(WHITE, 0.35)
		bandScale.Scale = 1.16
		TweenService:Create(bandScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		-- The time dip: the top of the ladder holds the landing frame before the sword resolves.
		task.wait(spec.landHold + spec.dip)
		if playToken ~= token then return end

		-- The wrapping comes off: the sword itself, big, turning, named.
		renderSword(realView, fullName, rarityName)
		realView.ImageTransparency = 1
		wellGrad.Color = ColorSequence.new(landColor:Lerp(DARK, 0.62), DARK)
		cardFlash.BackgroundTransparency = 0.15
		TweenService:Create(cardFlash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(silView, TweenInfo.new(RESOLVE), { ImageTransparency = 1 }):Play()
		TweenService:Create(realView, TweenInfo.new(RESOLVE), { ImageTransparency = 0 }):Play()
		TweenService:Create(qmark, TweenInfo.new(0.16), { TextTransparency = 1 }):Play()
		if qmarkStroke then TweenService:Create(qmarkStroke, TweenInfo.new(0.16), { Transparency = 1 }):Play() end
		AudioManager.PlaySFX("reveal_lock", revealGui, { PlaybackSpeed = 1.05, Volume = 0.5 })
		nameLabel.Text = string.upper(tostring(fullName or (tostring(rarityName) .. " SWORD")))
		nameScale.Scale = 1.14
		TweenService:Create(nameScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.wait(RESOLVE)
		if playToken ~= token then return end
		local readableAt = os.clock() - t0

		-- ...and the stats lock in one at a time.
		local chipData = {}
		table.insert(chipData, { text = string.format("x%.2f DAMAGE", mult or 1), top = WHITE, bottom = Color3.fromRGB(232, 228, 214) })
		for _, mod in ipairs(mods) do
			local odds = mod.oneInText and ("  ·  " .. string.upper(tostring(mod.oneInText))) or ""
			table.insert(chipData, { text = string.format("+%s %s%s", tostring(mod.name), tostring(mod.desc or ""), odds),
				top = Color3.fromRGB(198, 248, 176), bottom = Color3.fromRGB(104, 206, 104) })
		end
		if gotExtraSlot then
			table.insert(chipData, { text = "BLESSED +1 SLOT", top = Color3.fromRGB(255, 246, 170), bottom = BRIGHT.GoldDark })
		end
		for i, chip in ipairs(chips) do
			local data = chipData[i]
			chip.frame.Visible = data ~= nil
			if data then
				chip.label.Text = data.text
				chip.grad.Color = ColorSequence.new(data.top, data.bottom)
				chip.scale.Scale = 0.6
			end
		end
		for i, chip in ipairs(chips) do
			if not chip.frame.Visible then break end
			if playToken ~= token then return end
			TweenService:Create(chip.scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			AudioManager.PlaySFX("reveal_lock", revealGui, { PlaybackSpeed = 1.15 + 0.08 * i, Volume = 0.3 })
			task.wait(MOD_STEP)
		end

		-- The close: what the next kill is rolling for.
		local nextIndex = math.min(landIndex + 1, RUNGS)
		local foot
		if nextIndex > landIndex then
			foot = string.format("BEAT %s  ·  NEXT RUNG UP: %s AT %s  ·  KEEP THE STREAK, KEEP THE LUCK",
				oneInText(landOdds), string.upper(RARITIES[nextIndex]), oneInText(oddsOf(ladder, nextIndex)))
		else
			foot = string.format("BEAT %s  ·  TOP OF THE LADDER  ·  NOTHING THIS ZONE DROPS IS RARER", oneInText(landOdds))
		end
		footLabel.Text = foot
		local settledAt = os.clock() - t0
		print(string.format("[SwordDropReveal] %s %s: wrapped at %d ms, climb %d ms (%d ticks%s), landed %d ms, readable %d ms, settled %d ms, hold %d ms",
			tostring(rarityName), tostring(fullName), math.floor(LEAD * 1000), math.floor(climbMs), ticks,
			nearMiss and string.format(" + %d ms near miss", math.floor(nearMs)) or "", math.floor(landAt * 1000),
			math.floor(readableAt * 1000), math.floor(settledAt * 1000), math.floor(spec.hold * 1000)))

		task.wait(spec.hold)
		if playToken ~= token then return end
		-- Away, with no dead tail: the next enemy is already back up.
		TweenService:Create(cardScale, TweenInfo.new(EXIT, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.86 }):Play()
		TweenService:Create(dim, TweenInfo.new(EXIT), { BackgroundTransparency = 1 }):Play()
		for _, g in ipairs(glows) do
			TweenService:Create(g.frame, TweenInfo.new(EXIT), { BackgroundTransparency = 1 }):Play()
		end
		for _, ray in ipairs(rayBars) do
			TweenService:Create(ray, TweenInfo.new(EXIT), { BackgroundTransparency = 1 }):Play()
		end
		task.wait(EXIT)
		if playToken ~= token then return end
		revealGui.Enabled = false
		print(string.format("[SwordDropReveal] gone %d ms after the kill", math.floor((os.clock() - t0) * 1000)))
	end)
end

DROP_EVENT.OnClientEvent:Connect(revealDrop)

-- Studio-only motion capture hook (see GuiShowcase.motion): plays the reveal for one made-up
-- Legendary drop. Nothing is sent to the server; the sword exists only in this card.
GuiShowcase.motion("RewardReveal", function()
	revealDrop("Legendary", 4.25, "Sunforged Dawnbreaker", {
		{ name = "Keen", desc = "+12% Crit Chance", oneInText = "1 in 40" },
		{ name = "Swift", desc = "+8% Attack Speed", oneInText = "1 in 12" },
	}, true, { source = "Quarry Cutthroat", rank = "trash", rarityOdds = 0.0005, dropChance = 0.02, luck = 1.2 })
end)

-- Handle sword-lost toasts
SWORD_LOST_EVENT.OnClientEvent:Connect(function(fullName, rarityName)
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(270, 52)
	card.BackgroundColor3 = Color3.fromRGB(32, 20, 20)
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Parent = holder
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	local s = Instance.new("UIStroke", card)
	s.Color = Color3.fromRGB(230, 70, 70)
	s.Thickness = 1.4
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.fromOffset(246, 20)
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextSize = 13
	title.TextColor3 = Color3.fromRGB(255, 110, 110)
	title.Text = "\u{1F4A5} Sword Shattered on Death"
	title.Parent = card
	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(12, 26)
	desc.Size = UDim2.fromOffset(246, 16)
	desc.Font = Enum.Font.Gotham
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextSize = 12
	desc.TextColor3 = Color3.fromRGB(220, 180, 180)
	desc.Text = tostring(fullName or "Your sword") .. " is gone."
	desc.Parent = card
	task.delay(4.5, function()
		if card and card.Parent then card:Destroy() end
	end)
end)
