-- LocalScript | StarterPlayerScripts.SwordHotbarGui | Single-slot hotbar for the equipped sword.
-- Replaces Roblox's default backpack strip (hidden here): one bottom-centre slot renders the
-- sword that's currently in the character's hands, and hovering it (or tapping it on a phone)
-- opens a tooltip with the sword's full stat sheet. Switching swords happens from the Inventory
-- panel's EQUIP buttons (MainMenuGui), which call Humanoid:EquipTool the same way the default
-- backpack does.
--
-- Look: the bright chunky style shared with the Inventory tiles. The slot is a big button with a
-- deep rarity gradient, a heavy dark outline, a drop shadow and a bright equipped ring. The sword
-- is a shaded 3D render turned to show both its flat and its edge, with an ink outline, a soft
-- drop shadow and a steel glint, its tips just crossing the tile's rounded corners. A slot-number
-- badge sits on the top-left corner and a green check on the bottom-right. No caption: the
-- tooltip names the sword. The tooltip is a warm cream card with a heavy outline and a drop
-- shadow (the side buttons' family) under a rarity-tinted band (heavy white-stroked name, a
-- rarity tag in the band's deeper colour), with bold icon + big number chips in sunken wells.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
local SwordValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwordValue"))
local BossWeapons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BossWeapons"))
local WeaponModifiers = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponModifiers"))
local Items = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Items"))

local BRIGHT = PanelChrome.BRIGHT
local RARITY_TILE = PanelChrome.RARITY_TILE
local HUD = PanelChrome.HUD
local corner = PanelChrome.corner

-- Icons already used by the Inventory's stat rows.
local ICONS = {
	Sword = "rbxassetid://94091032987086",
	Trophy = "rbxassetid://77830885604568",
	Star = "rbxassetid://112684829478873",
	Target = "rbxassetid://120517988406723",
	Shield = "rbxassetid://93114601642790",
	Lighting = "rbxassetid://91519647625054",
}

-- The default strip is the only thing this replaces. CoreGui can lag behind PlayerGui on join and
-- a call made too early can succeed without sticking (its "ClassicSword" text slot then showed
-- through under this one), so keep asserting it until CoreGui reports it off a few times running.
local function hideDefaultBackpack()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
end
task.spawn(function()
	local settled = 0
	for _ = 1, 60 do
		hideDefaultBackpack()
		local ok, enabled = pcall(function()
			return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
		end)
		settled = if ok and enabled == false then settled + 1 else 0
		if settled >= 6 then return end
		task.wait(0.5)
	end
end)
player.CharacterAdded:Connect(hideDefaultBackpack)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SwordHotbarGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 13 -- above the HUD (10-11), below the combat streak (15) and modals (20+)
screenGui.Parent = playerGui

local SLOT_SIZE = HUD.HotbarSize -- design-space pixels; the holder's UIScale shrinks it on phones
local SLOT_RADIUS = 22

-- "ClassicSword" -> "Classic Sword"; names that already have spaces pass through.
local function prettyName(name: string): string
	return (name:gsub("(%l)(%u)", "%1 %2"))
end

-- ── Slot ─────────────────────────────────────────────────────────────────────
-- The holder carries the HUD scale; the button inside carries the hover/press bounce, so the
-- two UIScales never fight.
local holder = Instance.new("Frame")
holder.Name = "SlotHolder"
holder.AnchorPoint = Vector2.new(0.5, 1)
holder.Position = UDim2.new(0.5, 0, 1, -HUD.HotbarLift)
holder.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
holder.BackgroundTransparency = 1
holder.Parent = screenGui
local holderScale = Instance.new("UIScale")
holderScale.Parent = holder

local slot = Instance.new("TextButton")
slot.Name = "Slot"
slot.AnchorPoint = Vector2.new(0.5, 0.5)
slot.Position = UDim2.fromScale(0.5, 0.5)
slot.Size = UDim2.fromScale(1, 1)
slot.BackgroundTransparency = 1
slot.BorderSizePixel = 0
slot.Text = ""
slot.AutoButtonColor = false
slot.Parent = holder
local bounce = Instance.new("UIScale")
bounce.Parent = slot

-- Drop shadow: the tile's outlined footprint, dropped a few pixels, so it reads as a raised key.
local shadow = Instance.new("Frame")
shadow.Name = "Shadow"
shadow.Position = UDim2.fromOffset(-4, 3)
shadow.Size = UDim2.new(1, 8, 1, 8)
shadow.BackgroundColor3 = Color3.fromRGB(8, 10, 20)
shadow.BackgroundTransparency = 0.35
shadow.BorderSizePixel = 0
shadow.ZIndex = 1
shadow.Parent = slot
corner(shadow, SLOT_RADIUS + 4)

-- Equipped ring: a bright band just outside the dark outline with a soft glow around it, so the
-- held sword's slot stands out from the stone floor. Green when equipped.
local EQUIPPED_GREEN = Color3.fromRGB(120, 255, 96)
local equippedGlow = Instance.new("Frame")
equippedGlow.Name = "EquippedGlow"
equippedGlow.Position = UDim2.fromOffset(-9, -9)
equippedGlow.Size = UDim2.new(1, 18, 1, 18)
equippedGlow.BackgroundTransparency = 1
equippedGlow.Visible = false
equippedGlow.ZIndex = 1
equippedGlow.Parent = slot
corner(equippedGlow, SLOT_RADIUS + 9)
local glowStroke = PanelChrome.stroke(equippedGlow, EQUIPPED_GREEN, 5, 0.6)

local equippedRing = Instance.new("Frame")
equippedRing.Name = "EquippedRing"
equippedRing.Position = UDim2.fromOffset(-5, -5)
equippedRing.Size = UDim2.new(1, 10, 1, 10)
equippedRing.BackgroundTransparency = 1
equippedRing.Visible = false
equippedRing.ZIndex = 1
equippedRing.Parent = slot
corner(equippedRing, SLOT_RADIUS + 5)
local ringStroke = PanelChrome.stroke(equippedRing, EQUIPPED_GREEN, 3.5)

-- Hotbar face colours: deeper and more saturated than the Inventory's pale tiles so the slot
-- reads as a solid button against a bright or grey floor. Common runs steel-grey to slate.
local HOTBAR_FILL = {
	Common = { top = Color3.fromRGB(190, 210, 240), bottom = Color3.fromRGB(70, 90, 140), rim = Color3.fromRGB(150, 174, 218), glow = Color3.fromRGB(226, 238, 255) },
}
local function fillFor(rarity: string)
	if HOTBAR_FILL[rarity] then return HOTBAR_FILL[rarity] end
	local t = RARITY_TILE[rarity] or RARITY_TILE.Common
	return { top = t.top:Lerp(t.bottom, 0.2), bottom = t.bottom:Lerp(t.rim, 0.45), rim = t.top, glow = t.top }
end

local function faceLayer(parent: Frame, name: string, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.ZIndex = z
	f.Parent = parent
	return f
end

-- The tile face is rebuilt whenever the rarity changes.
local face: Frame? = nil
local function buildFace(rarity: string?)
	if face then face:Destroy() end
	local f = Instance.new("Frame")
	f.Name = "Face"
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel = 0
	f.ZIndex = 2
	f.Parent = slot
	corner(f, SLOT_RADIUS)
	if rarity then
		local c = fillFor(rarity)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		PanelChrome.gradient(f, c.top, c.bottom)
		PanelChrome.stroke(f, BRIGHT.Outline, 4.5)
		-- Light bevel ring just inside the outline.
		local bevel = faceLayer(f, "Bevel", 2)
		bevel.BackgroundTransparency = 1
		bevel.Position = UDim2.fromOffset(3, 3)
		bevel.Size = UDim2.new(1, -6, 1, -6)
		corner(bevel, SLOT_RADIUS - 3)
		PanelChrome.stroke(bevel, c.rim, 2.5, 0.15)
		-- Soft light behind the sword: stacked translucent discs read as a radial glow.
		for i, spec in ipairs({ { 0.84, 0.84 }, { 0.56, 0.74 } }) do
			local disc = faceLayer(f, "Glow" .. i, 2)
			disc.AnchorPoint = Vector2.new(0.5, 0.5)
			disc.Position = UDim2.fromScale(0.5, 0.5)
			disc.Size = UDim2.fromScale(spec[1], spec[1])
			disc.BackgroundColor3 = c.glow
			disc.BackgroundTransparency = spec[2]
			corner(disc, 999)
		end
		-- Glossy band across the top half, like the bevel on rendered button art.
		local shine = faceLayer(f, "Shine", 2)
		shine.BackgroundTransparency = 0.5
		shine.Position = UDim2.fromOffset(7, 6)
		shine.Size = UDim2.new(1, -14, 0.3, 0)
		corner(shine, SLOT_RADIUS - 6)
		local sg = Instance.new("UIGradient")
		sg.Transparency = NumberSequence.new(0, 1)
		sg.Rotation = 90
		sg.Parent = shine
	else
		PanelChrome.emptyWell(f, { radius = SLOT_RADIUS, zIndex = 2 })
		PanelChrome.stroke(f, BRIGHT.Outline, 4.5)
		local dashes = PanelChrome.dashedOutline(f, { color = BRIGHT.Slot, radius = SLOT_RADIUS - 4, zIndex = 2, thickness = 3 })
		dashes.Position = UDim2.fromOffset(6, 6)
		dashes.Size = UDim2.new(1, -12, 1, -12)
	end
	face = f
	return f
end

-- 3D render of the equipped tool on the classic 45-degree diagonal. The render box is a hair
-- smaller than the tile, so the blade tip and pommel just cross its rounded corners the way
-- PS99 item art breaks its frame, while the body of the sword stays inside.
local PREVIEW_POS = UDim2.fromScale(0.5, 0.48)
local PREVIEW_SIZE = UDim2.new(1, 10, 1, 10)
local PREVIEW_OPTS = { tiltDeg = 45, margin = 0.98, ambient = Color3.fromRGB(150, 150, 166) }

local function previewView(name: string, offset: Vector2, z: number): ViewportFrame
	local v = Instance.new("ViewportFrame")
	v.Name = name
	v.AnchorPoint = Vector2.new(0.5, 0.5)
	v.Position = PREVIEW_POS + UDim2.fromOffset(math.round(offset.X), math.round(offset.Y))
	v.Size = PREVIEW_SIZE
	v.BackgroundTransparency = 1
	v.ZIndex = z
	v.Parent = slot
	return v
end

-- Soft drop shadow: the same render in a translucent near-black, dropped down and right.
local shadowView = previewView("PreviewShadow", Vector2.new(5, 7), 3)
shadowView.ImageColor3 = Color3.fromRGB(10, 14, 34)
shadowView.ImageTransparency = 0.55

-- Cartoon ink outline: the render tinted near-black and nudged a few pixels in eight
-- directions behind the real one, so the sword gets the heavy silhouette of PS99 item art.
local OUTLINE_PX = 3
local outlineViews = {}
for _, dir in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 0.7, 0.7 }, { -0.7, 0.7 }, { 0.7, -0.7 }, { -0.7, -0.7 } }) do
	local v = previewView("PreviewOutline", Vector2.new(dir[1] * OUTLINE_PX, dir[2] * OUTLINE_PX), 4)
	v.ImageColor3 = BRIGHT.Outline
	table.insert(outlineViews, v)
end

local viewport = previewView("Preview", Vector2.zero, 5)

-- Four-point sparkle on the blade: the glint PS99 puts on shiny item art.
local sparkle = Instance.new("Frame")
sparkle.Name = "Sparkle"
sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
sparkle.Position = UDim2.fromScale(0.64, 0.3)
sparkle.Size = UDim2.fromOffset(22, 22)
sparkle.BackgroundTransparency = 1
sparkle.ZIndex = 6
sparkle.Visible = false
sparkle.Parent = slot
for i, spec in ipairs({ { 22, 4, 0 }, { 22, 4, 90 }, { 11, 3, 45 }, { 11, 3, -45 } }) do
	local ray = Instance.new("Frame")
	ray.Name = "Ray" .. i
	ray.AnchorPoint = Vector2.new(0.5, 0.5)
	ray.Position = UDim2.fromScale(0.5, 0.5)
	ray.Size = UDim2.fromOffset(spec[1], spec[2])
	ray.Rotation = spec[3]
	ray.BackgroundColor3 = Color3.new(1, 1, 1)
	ray.BorderSizePixel = 0
	ray.ZIndex = 6
	ray.Parent = sparkle
	corner(ray, 3)
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = ray
end

local allViews = { viewport, shadowView, table.unpack(outlineViews) }

local function clearPreview()
	for _, v in ipairs(allViews) do
		for _, child in ipairs(v:GetChildren()) do child:Destroy() end
	end
	sparkle.Visible = false
end

-- The starter sword's blade is thin along the Handle's X (its guard crosses on X too), so the
-- default pose shows it edge-on as a grey line. Turning it 55 degrees about the blade shows the
-- flat and the edge in two different shades, and the guard still reads wide.
local function rollFor(tool: Tool): number
	local handle = tool:FindFirstChild("Handle")
	local blade = tool:FindFirstChild("Blade")
	if not (handle and blade and blade:IsA("BasePart")) then return 0 end
	for _, weld in ipairs(handle:GetChildren()) do
		if weld:IsA("Weld") and weld.Part1 == blade then
			return if blade.Size.X < blade.Size.Y then 55 else 0
		end
	end
	return 0
end

-- A bright steel stripe down the render's blade: the metal highlight the flat light leaves out.
local function addGlint(v: ViewportFrame)
	local world = v:FindFirstChildOfClass("WorldModel")
	local blade = world and world:FindFirstChild("Blade", true)
	if not (blade and blade:IsA("BasePart")) then return end
	local stripe = Instance.new("Part")
	stripe.Name = "Glint"
	stripe.Anchored = true
	stripe.CanCollide = false
	stripe.Material = Enum.Material.SmoothPlastic
	stripe.Color = Color3.fromRGB(250, 252, 255)
	stripe.Size = Vector3.new(blade.Size.X + 0.02, blade.Size.Y * 0.2, blade.Size.Z * 0.9)
	stripe.CFrame = blade.CFrame * CFrame.new(0, blade.Size.Y * 0.2, -blade.Size.Z * 0.03)
	stripe.Parent = blade.Parent
end

local function renderPreview(tool: Tool)
	local opts = table.clone(PREVIEW_OPTS)
	opts.rollDeg = rollFor(tool)
	local ok = PanelChrome.renderTool(viewport, tool, opts)
	if ok then addGlint(viewport) end
	viewport.LightColor = Color3.fromRGB(255, 250, 236)
	for _, v in ipairs({ shadowView, table.unpack(outlineViews) }) do
		PanelChrome.renderTool(v, tool, opts)
		v.Ambient = Color3.new(1, 1, 1)
	end
	sparkle.Visible = ok == true
end

local emptyLabel = PanelChrome.display(slot, {
	name = "Empty", text = "No sword", size = 20, stroke = 2.5, scaled = true, minSize = 10,
	size2 = UDim2.new(1, -20, 0, 28), pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), zIndex = 6,
})

-- Slot-number badge on the top-left corner, the way hotbar slots are numbered.
local keyBadge = Instance.new("Frame")
keyBadge.Name = "KeyBadge"
keyBadge.AnchorPoint = Vector2.new(0.5, 0.5)
keyBadge.Position = UDim2.fromOffset(6, 6)
keyBadge.Size = UDim2.fromOffset(38, 38)
keyBadge.BackgroundColor3 = Color3.new(1, 1, 1)
keyBadge.ZIndex = 7
keyBadge.Parent = slot
corner(keyBadge, 11)
PanelChrome.gradient(keyBadge, Color3.fromRGB(78, 86, 118), BRIGHT.Outline)
PanelChrome.stroke(keyBadge, Color3.new(1, 1, 1), 2.5)
PanelChrome.display(keyBadge, { name = "Key", text = "1", size = 25, stroke = 2.5, zIndex = 8 })

-- Green check on the bottom-right corner while the sword is in hand (the Inventory's equipped
-- mark). Bottom-right is the one corner the diagonal blade never reaches.
local checkBadge = PanelChrome.checkBadge(slot, 34, 7)
checkBadge.Position = UDim2.new(1, -7, 1, -7)
checkBadge.Visible = false

buildFace(nil)

-- ── Tooltip ──────────────────────────────────────────────────────────────────
-- tooltipRoot is a zero-height anchor above the slot that carries the HUD scale; the card and
-- its pointer tail hang upward from it.
local TOOLTIP_WIDTH = 290
local TOOLTIP_GAP = 22 -- design-space gap between the slot's top and the tail's tip
local TOOLTIP_FONT = PanelChrome.DISPLAY_FONT -- one rounded face for every line on the card

-- Warm cream card, the same family as the glossy side buttons: a light face that reads as
-- paper-and-candy rather than a grey form, with warm brown ink instead of cold slate.
local CREAM = {
	top = Color3.fromRGB(255, 252, 238), bottom = Color3.fromRGB(248, 234, 198),
	well = Color3.fromRGB(252, 240, 208), wellBottom = Color3.fromRGB(240, 222, 176), wellStroke = Color3.fromRGB(206, 180, 124),
	ink = Color3.fromRGB(70, 54, 38), inkSoft = Color3.fromRGB(104, 84, 60), inkMuted = Color3.fromRGB(150, 124, 88),
}

-- Header band and rarity-tag colours per rarity: a muted grey-green for Common, then the tile
-- colours (green, blue, purple, gold) up the tiers. The tag is the band's colour run deeper,
-- so the rarity reads from the chip as well as the band.
local BAND = {
	Common = {
		top = Color3.fromRGB(198, 220, 184), bottom = Color3.fromRGB(110, 146, 110),
		tagTop = Color3.fromRGB(146, 184, 134), tagBottom = Color3.fromRGB(70, 108, 72),
	},
}
local function bandFor(rarity: string)
	if BAND[rarity] then return BAND[rarity] end
	local t = RARITY_TILE[rarity] or RARITY_TILE.Common
	return { top = t.top, bottom = t.bottom, tagTop = t.bottom, tagBottom = t.rim }
end

-- A soft top highlight, the glossy bevel on rendered button art.
local function shine(parent: GuiObject, radius: number, transparency: number, inset: number?)
	local s = Instance.new("Frame")
	s.Name = "Shine"
	s.BackgroundColor3 = Color3.new(1, 1, 1)
	s.BackgroundTransparency = transparency
	s.BorderSizePixel = 0
	s.Position = UDim2.fromOffset(inset or 4, 3)
	s.Size = UDim2.new(1, -2 * (inset or 4), 0.42, 0)
	s.ZIndex = parent.ZIndex
	s.Parent = parent
	corner(s, radius)
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new(0, 1)
	fade.Rotation = 90
	fade.Parent = s
	return s
end

local tooltipRoot = Instance.new("Frame")
tooltipRoot.Name = "TooltipRoot"
tooltipRoot.AnchorPoint = Vector2.new(0.5, 1)
tooltipRoot.Size = UDim2.fromOffset(TOOLTIP_WIDTH, 0)
tooltipRoot.BackgroundTransparency = 1
tooltipRoot.Visible = false
tooltipRoot.ZIndex = 10
tooltipRoot.Parent = screenGui
local tooltipScale = Instance.new("UIScale")
tooltipScale.Parent = tooltipRoot

-- Drop shadow under the card: its footprint in translucent ink, a few pixels lower. It is the
-- card's sibling (children always draw over their parent), sized to follow the card's height.
local CARD_BOTTOM = 18 -- design-space gap under the card that the pointer tail fills
local SHADOW_DROP = 11 -- clears the card's 4 px outline, so ~7 px of shadow shows under it
local cardShadow = Instance.new("Frame")
cardShadow.Name = "CardShadow"
cardShadow.AnchorPoint = Vector2.new(0.5, 1)
cardShadow.Position = UDim2.new(0.5, 4, 1, -CARD_BOTTOM + SHADOW_DROP)
cardShadow.Size = UDim2.fromOffset(TOOLTIP_WIDTH + 8, 0)
cardShadow.BackgroundColor3 = Color3.fromRGB(26, 18, 10)
cardShadow.BackgroundTransparency = 0.4
cardShadow.BorderSizePixel = 0
cardShadow.ZIndex = 10
cardShadow.Parent = tooltipRoot
corner(cardShadow, 20)
-- The tail's own shadow, so the drop runs unbroken down to the pointer.
local tailShadow = Instance.new("Frame")
tailShadow.Name = "TailShadow"
tailShadow.AnchorPoint = Vector2.new(0.5, 0.5)
tailShadow.Position = UDim2.new(0.5, 4, 1, -10 + SHADOW_DROP)
tailShadow.Size = UDim2.fromOffset(26, 26)
tailShadow.Rotation = 45
tailShadow.BackgroundColor3 = cardShadow.BackgroundColor3
tailShadow.BackgroundTransparency = 0.4
tailShadow.BorderSizePixel = 0
tailShadow.ZIndex = 10
tailShadow.Parent = tooltipRoot
corner(tailShadow, 5)

-- Pointer tail: a rotated square half-hidden under the card, so only its lower point shows.
local tail = Instance.new("Frame")
tail.Name = "Tail"
tail.AnchorPoint = Vector2.new(0.5, 0.5)
tail.Position = UDim2.new(0.5, 0, 1, -10)
tail.Size = UDim2.fromOffset(22, 22)
tail.Rotation = 45
tail.BackgroundColor3 = CREAM.bottom
tail.BorderSizePixel = 0
tail.ZIndex = 10
tail.Parent = tooltipRoot
corner(tail, 4)
PanelChrome.stroke(tail, BRIGHT.Outline, 4)

-- Covers the card's outline where the tail meets it, so the tail reads as part of the card.
local tailSeam = Instance.new("Frame")
tailSeam.Name = "TailSeam"
tailSeam.AnchorPoint = Vector2.new(0.5, 0.5)
tailSeam.Position = UDim2.new(0.5, 0, 1, -16)
tailSeam.Size = UDim2.fromOffset(12, 7)
tailSeam.BackgroundColor3 = CREAM.bottom
tailSeam.BorderSizePixel = 0
tailSeam.ZIndex = 20
tailSeam.Parent = tooltipRoot

local tooltip = Instance.new("Frame")
tooltip.Name = "Tooltip"
tooltip.AnchorPoint = Vector2.new(0.5, 1)
tooltip.Position = UDim2.new(0.5, 0, 1, -CARD_BOTTOM)
tooltip.Size = UDim2.fromOffset(TOOLTIP_WIDTH, 0)
tooltip.AutomaticSize = Enum.AutomaticSize.Y
tooltip.BackgroundColor3 = Color3.new(1, 1, 1)
tooltip.BorderSizePixel = 0
tooltip.ZIndex = 11
tooltip.Parent = tooltipRoot
corner(tooltip, 18)
PanelChrome.gradient(tooltip, CREAM.top, CREAM.bottom)
PanelChrome.stroke(tooltip, BRIGHT.Outline, 4)

-- The shadow follows the card's height (in design space, so undo the HUD scale).
local function syncShadow()
	local s = math.max(tooltipScale.Scale, 0.01)
	cardShadow.Size = UDim2.fromOffset(TOOLTIP_WIDTH + 8, math.ceil(tooltip.AbsoluteSize.Y / s) + 8)
end
tooltip:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncShadow)

local tooltipLayout = Instance.new("UIListLayout")
tooltipLayout.SortOrder = Enum.SortOrder.LayoutOrder
tooltipLayout.Parent = tooltip

-- Header band in the rarity colour: rounded top corners, square bottom, a heavy rule under it.
local HEADER_HEIGHT = 70
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
header.BackgroundColor3 = Color3.new(1, 1, 1)
header.BorderSizePixel = 0
header.LayoutOrder = 1
header.ZIndex = 12
header.Parent = tooltip
corner(header, 16)
local headerGradient = PanelChrome.gradient(header, BRIGHT.Panel, BRIGHT.Panel)
local headerSquare = Instance.new("Frame")
headerSquare.Name = "SquareBottom"
headerSquare.AnchorPoint = Vector2.new(0, 1)
headerSquare.Position = UDim2.fromScale(0, 1)
headerSquare.Size = UDim2.new(1, 0, 0.5, 0)
headerSquare.BackgroundColor3 = Color3.new(1, 1, 1)
headerSquare.BorderSizePixel = 0
headerSquare.ZIndex = 12
headerSquare.Parent = header
local headerSquareGradient = PanelChrome.gradient(headerSquare, BRIGHT.Panel, BRIGHT.Panel)
local headerShine = shine(header, 12, 0.62, 8)
headerShine.Size = UDim2.new(1, -16, 0.34, 0)
-- Light bevel just inside the band's edge: the glossy rim the side buttons carry.
local headerBevel = Instance.new("Frame")
headerBevel.Name = "Bevel"
headerBevel.BackgroundTransparency = 1
headerBevel.Position = UDim2.fromOffset(3, 3)
headerBevel.Size = UDim2.new(1, -6, 1, -3)
headerBevel.ZIndex = 13
headerBevel.Parent = header
corner(headerBevel, 13)
PanelChrome.stroke(headerBevel, Color3.new(1, 1, 1), 2, 0.45)

local titleLabel = PanelChrome.display(header, {
	name = "Title", text = "", size = 34, stroke = 3.5, scaled = true, minSize = 18,
	xAlign = Enum.TextXAlignment.Left, size2 = UDim2.new(1, -24, 0, 38), pos = UDim2.fromOffset(12, 3), zIndex = 14,
})

local tagRow = Instance.new("Frame")
tagRow.Name = "Tags"
tagRow.BackgroundTransparency = 1
tagRow.Position = UDim2.fromOffset(12, 40)
tagRow.Size = UDim2.new(1, -24, 0, 24)
tagRow.ZIndex = 13
tagRow.Parent = header
local tagLayout = Instance.new("UIListLayout")
tagLayout.FillDirection = Enum.FillDirection.Horizontal
tagLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tagLayout.Padding = UDim.new(0, 8)
tagLayout.SortOrder = Enum.SortOrder.LayoutOrder
tagLayout.Parent = tagRow

-- Rarity tag: a bright filled capsule in the tier's deep colour, heavy outline, glossy top.
local rarityPill = Instance.new("Frame")
rarityPill.Name = "RarityPill"
rarityPill.Size = UDim2.fromOffset(0, 24)
rarityPill.AutomaticSize = Enum.AutomaticSize.X
rarityPill.BackgroundColor3 = Color3.new(1, 1, 1)
rarityPill.LayoutOrder = 1
rarityPill.ZIndex = 13
rarityPill.Parent = tagRow
corner(rarityPill, 9)
local pillGradient = PanelChrome.gradient(rarityPill, BRIGHT.Slot, BRIGHT.Slot)
PanelChrome.stroke(rarityPill, BRIGHT.Outline, 3)
shine(rarityPill, 6, 0.55, 3)
local pillPad = Instance.new("UIPadding")
pillPad.PaddingLeft = UDim.new(0, 11)
pillPad.PaddingRight = UDim.new(0, 11)
pillPad.Parent = rarityPill
local rarityText = PanelChrome.display(rarityPill, { name = "Rarity", text = "", size = 16, stroke = 2, zIndex = 14 })
rarityText.Size = UDim2.fromScale(0, 1)
rarityText.AutomaticSize = Enum.AutomaticSize.X

local kindText = PanelChrome.display(tagRow, {
	name = "Kind", text = "", size = 17, stroke = 2.5, xAlign = Enum.TextXAlignment.Left, zIndex = 14,
})
kindText.Size = UDim2.fromScale(0, 1)
kindText.AutomaticSize = Enum.AutomaticSize.X
kindText.LayoutOrder = 2

local headerRule = Instance.new("Frame")
headerRule.Name = "Rule"
headerRule.Size = UDim2.new(1, 0, 0, 4)
headerRule.BackgroundColor3 = BRIGHT.Outline
headerRule.BorderSizePixel = 0
headerRule.LayoutOrder = 2
headerRule.ZIndex = 12
headerRule.Parent = tooltip

-- Body: rebuilt on every fill.
local body = Instance.new("Frame")
body.Name = "Body"
body.BackgroundTransparency = 1
body.Size = UDim2.new(1, 0, 0, 0)
body.AutomaticSize = Enum.AutomaticSize.Y
body.LayoutOrder = 3
body.ZIndex = 12
body.Parent = tooltip
local bodyPad = Instance.new("UIPadding")
bodyPad.PaddingTop = UDim.new(0, 10)
bodyPad.PaddingBottom = UDim.new(0, 8)
bodyPad.PaddingLeft = UDim.new(0, 10)
bodyPad.PaddingRight = UDim.new(0, 10)
bodyPad.Parent = body
local bodyLayout = Instance.new("UIListLayout")
bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
bodyLayout.Padding = UDim.new(0, 7)
bodyLayout.Parent = body

local function inkLabel(parent, text: string, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = props.font or TOOLTIP_FONT
	label.TextSize = props.size or 16
	label.TextColor3 = props.color or CREAM.ink
	label.TextXAlignment = props.xAlign or Enum.TextXAlignment.Left
	label.TextYAlignment = props.yAlign or Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Text = text
	label.Size = props.size2 or UDim2.fromScale(1, 1)
	label.Position = props.pos or UDim2.fromOffset(0, 0)
	if props.autoY then label.AutomaticSize = Enum.AutomaticSize.Y end
	label.LayoutOrder = props.order or 0
	label.ZIndex = props.zIndex or 14
	label.Parent = parent
	return label
end

-- Stat colours: the icon badge and the number chip share one bright gradient per stat. No red:
-- on a stat sheet red reads as a penalty or an error.
local STAT_COLORS = {
	Gold = { Color3.fromRGB(255, 230, 96), Color3.fromRGB(236, 146, 18) },
	Orange = { Color3.fromRGB(255, 200, 90), Color3.fromRGB(240, 116, 28) },
	Blue = { Color3.fromRGB(136, 206, 255), Color3.fromRGB(36, 126, 230) },
	Green = { Color3.fromRGB(160, 242, 120), Color3.fromRGB(44, 160, 56) },
	Pink = { Color3.fromRGB(255, 150, 206), Color3.fromRGB(222, 64, 150) },
}

-- One stat line: a round bold icon badge, the stat's name, and the value in a big glossy chip.
local function statRow(order: number, icon: string, labelText: string, valueText: string, colors)
	local top, bottom = colors[1], colors[2]
	-- Each stat sits in a sunken cream well, the way PS99 sets its tier rows apart.
	local row = Instance.new("Frame")
	row.Name = "Stat_" .. labelText
	row.Size = UDim2.new(1, 0, 0, 52)
	row.BackgroundColor3 = Color3.new(1, 1, 1)
	row.LayoutOrder = order
	row.ZIndex = 13
	row.Parent = body
	corner(row, 16)
	PanelChrome.gradient(row, CREAM.wellBottom, CREAM.well)
	PanelChrome.stroke(row, CREAM.wellStroke, 2.5)

	local badge = Instance.new("Frame")
	badge.Name = "IconBadge"
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, 5, 0.5, 0)
	badge.Size = UDim2.fromOffset(42, 42)
	badge.BackgroundColor3 = Color3.new(1, 1, 1)
	badge.ZIndex = 14
	badge.Parent = row
	corner(badge, 21)
	PanelChrome.gradient(badge, top, bottom)
	PanelChrome.stroke(badge, BRIGHT.Outline, 3)
	shine(badge, 14, 0.5, 6)
	local ic = Instance.new("ImageLabel")
	ic.BackgroundTransparency = 1
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.5)
	ic.Size = UDim2.fromOffset(30, 30)
	ic.Image = icon
	ic.ScaleType = Enum.ScaleType.Fit
	ic.ZIndex = 15
	ic.Parent = badge

	inkLabel(row, labelText, { size = 20, pos = UDim2.fromOffset(56, 0), size2 = UDim2.new(1, -56, 1, 0), zIndex = 14 })

	-- The chip fits its number (never narrower than 84), measured so nothing in it needs a layout.
	local textWidth = TextService:GetTextSize(valueText, 29, PanelChrome.DISPLAY_FONT, Vector2.new(1000, 100)).X
	local chip = Instance.new("Frame")
	chip.Name = "ValueChip"
	chip.AnchorPoint = Vector2.new(1, 0.5)
	chip.Position = UDim2.new(1, -5, 0.5, 0)
	chip.Size = UDim2.fromOffset(math.max(84, math.ceil(textWidth) + 28), 40)
	chip.BackgroundColor3 = Color3.new(1, 1, 1)
	chip.ZIndex = 14
	chip.Parent = row
	corner(chip, 13)
	PanelChrome.gradient(chip, top, bottom)
	PanelChrome.stroke(chip, BRIGHT.Outline, 3)
	shine(chip, 9, 0.5, 5)
	PanelChrome.display(chip, { name = "Value", text = valueText, size = 29, stroke = 3, zIndex = 15 })
	return row
end

local function sectionHeading(order: number, text: string)
	return inkLabel(body, text, {
		size = 15, color = CREAM.inkMuted, order = order,
		size2 = UDim2.new(1, 0, 0, 18), zIndex = 13,
	})
end

-- A modifier: tier chip, name, and what the tier does underneath.
local function modifierRow(order: number, name: string, tier: number, desc: string)
	local row = Instance.new("Frame")
	row.Name = "Mod_" .. name
	row.Size = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.BackgroundColor3 = Color3.new(1, 1, 1)
	row.LayoutOrder = order
	row.ZIndex = 13
	row.Parent = body
	corner(row, 14)
	PanelChrome.gradient(row, CREAM.wellBottom, CREAM.well)
	PanelChrome.stroke(row, CREAM.wellStroke, 2.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 7)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = row
	local chip = Instance.new("Frame")
	chip.Name = "Tier"
	chip.Size = UDim2.fromOffset(36, 26)
	chip.BackgroundColor3 = Color3.new(1, 1, 1)
	chip.ZIndex = 14
	chip.Parent = row
	corner(chip, 9)
	PanelChrome.gradient(chip, Color3.fromRGB(130, 200, 255), BRIGHT.Blue)
	PanelChrome.stroke(chip, BRIGHT.Outline, 2)
	PanelChrome.display(chip, { text = "T" .. tostring(tier), size = 16, stroke = 1.5, zIndex = 15 })
	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.Position = UDim2.fromOffset(46, 0)
	column.Size = UDim2.new(1, -46, 0, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.ZIndex = 14
	column.Parent = row
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 1)
	list.Parent = column
	inkLabel(column, name, { size = 16, order = 1, size2 = UDim2.new(1, 0, 0, 26), autoY = true })
	inkLabel(column, desc, { size = 15, color = CREAM.inkSoft, order = 2, size2 = UDim2.new(1, 0, 0, 0), autoY = true })
	return row
end

local function fillTooltip(tool: Tool)
	for _, child in ipairs(body:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	local rarity = tool:GetAttribute("Rarity") or "Common"
	local band = bandFor(rarity)
	local isBossDrop = tool:GetAttribute("BossDrop") == true
	local damageMult = tool:GetAttribute("DamageMult") or 1
	local prefixes = tool:GetAttribute("Prefixes") or ""

	-- Header: rarity gradient split across the rounded strip and its square-bottom filler.
	local mid = band.top:Lerp(band.bottom, 0.5)
	headerGradient.Color = ColorSequence.new(band.top, band.bottom)
	headerSquareGradient.Color = ColorSequence.new(mid, band.bottom)
	titleLabel.Text = prettyName(tool.Name)
	pillGradient.Color = ColorSequence.new(band.tagTop, band.tagBottom)
	rarityText.Text = string.upper(rarity)
	kindText.Text = BossWeapons.SwordKind(tool)

	local order = 1
	local info = Items[tool.Name]
	local description = tool:GetAttribute("Description") or (info and info.Description)
	if typeof(description) == "string" and description ~= "" then
		inkLabel(body, description, {
			size = 19, color = CREAM.inkSoft, order = order,
			size2 = UDim2.new(1, 0, 0, 0), autoY = true, zIndex = 13,
		})
		order += 1
	end
	-- Gold, not red: x1.00 is the baseline multiplier, and red would read as a penalty.
	statRow(order, ICONS.Sword, "Damage", string.format("x%.2f", damageMult), STAT_COLORS.Gold)
	order += 1
	if isBossDrop then
		statRow(order, ICONS.Trophy, "Rating", SwordValue.short(SwordValue.rateTool(tool)), STAT_COLORS.Gold)
		order += 1
	end

	local mods = SwordValue.modifiersFromPrefixes(prefixes)
	if #mods > 0 then
		sectionHeading(order, "MODIFIERS")
		order += 1
		for _, mod in ipairs(mods) do
			local tierData = WeaponModifiers.ModByName[mod.name] or WeaponModifiers.Categories[mod.category].Tiers[mod.tier]
			modifierRow(order, mod.name, mod.tier, tierData and tierData.desc or mod.category)
			order += 1
		end
	elseif isBossDrop then
		inkLabel(body, "No modifiers", {
			size = 16, color = CREAM.inkMuted, order = order,
			size2 = UDim2.new(1, 0, 0, 20), zIndex = 13,
		})
		order += 1
	end

	-- Combined totals, in case several modifiers stack on the same stat.
	local bonusDmg = tool:GetAttribute("BonusDamagePct") or 0
	local critChance = tool:GetAttribute("CritChance") or 0
	local rangeBonus = tool:GetAttribute("RangeBonus") or 0
	local knockbackBonus = tool:GetAttribute("KnockbackBonus") or 0
	if bonusDmg > 0 or critChance > 0 or rangeBonus > 0 or knockbackBonus > 0 then
		sectionHeading(order, "TOTALS")
		order += 1
		if bonusDmg > 0 then
			statRow(order, ICONS.Sword, "Bonus damage", string.format("+%d%%", math.round(bonusDmg * 100)), STAT_COLORS.Orange)
			order += 1
		end
		if critChance > 0 then
			statRow(order, ICONS.Target, "Crit chance", string.format("+%d%%", math.round(critChance * 100)), STAT_COLORS.Pink)
			order += 1
		end
		if rangeBonus > 0 then
			statRow(order, ICONS.Lighting, "Reach", string.format("+%s", tostring(rangeBonus)), STAT_COLORS.Blue)
			order += 1
		end
		if knockbackBonus > 0 then
			statRow(order, ICONS.Shield, "Knockback", string.format("+%d", knockbackBonus), STAT_COLORS.Green)
			order += 1
		end
	end

	-- How-to line (PS99's "Tap to activate!"): what the slot's own control does on this device.
	local hint = Instance.new("Frame")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Size = UDim2.new(1, 0, 0, 26)
	hint.LayoutOrder = order
	hint.ZIndex = 13
	hint.Parent = body
	local hintLayout = Instance.new("UIListLayout")
	hintLayout.FillDirection = Enum.FillDirection.Horizontal
	hintLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hintLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	hintLayout.Padding = UDim.new(0, 7)
	hintLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hintLayout.Parent = hint
	local touchFirst = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local hintColor = Color3.fromRGB(34, 124, 226)
	if touchFirst then
		inkLabel(hint, "Hold the slot to sheathe", { size = 17, color = hintColor, order = 1, size2 = UDim2.fromScale(0, 1), zIndex = 14 }).AutomaticSize = Enum.AutomaticSize.X
	else
		inkLabel(hint, "Press", { size = 17, color = hintColor, order = 1, size2 = UDim2.fromScale(0, 1), zIndex = 14 }).AutomaticSize = Enum.AutomaticSize.X
		local key = Instance.new("Frame")
		key.Name = "KeyChip"
		key.Size = UDim2.fromOffset(26, 26)
		key.BackgroundColor3 = Color3.new(1, 1, 1)
		key.LayoutOrder = 2
		key.ZIndex = 14
		key.Parent = hint
		corner(key, 8)
		PanelChrome.gradient(key, Color3.fromRGB(78, 86, 118), BRIGHT.Outline)
		PanelChrome.stroke(key, Color3.new(1, 1, 1), 2)
		PanelChrome.display(key, { text = "1", size = 17, stroke = 1.5, zIndex = 15 })
		inkLabel(hint, "to sheathe", { size = 17, color = hintColor, order = 3, size2 = UDim2.fromScale(0, 1), zIndex = 14 }).AutomaticSize = Enum.AutomaticSize.X
	end
end

-- ── Scaling ──────────────────────────────────────────────────────────────────
PanelChrome.onViewport(function(viewportSize: Vector2)
	local s = PanelChrome.hudScale(viewportSize)
	holderScale.Scale = s
	tooltipScale.Scale = s
	-- The tail's tip sits TOOLTIP_GAP above the slot's top edge (both scaled).
	tooltipRoot.Position = UDim2.new(0.5, 0, 1, -math.floor(HUD.HotbarLift + (SLOT_SIZE + TOOLTIP_GAP) * s))
end)

-- ── Equipped-tool tracking ───────────────────────────────────────────────────
local currentTool: Tool? = nil
local lastEquipped: Tool? = nil -- the sword the 1 key draws again after putting it away

-- With nothing in hand, the empty slot says how to draw a sword (per input device), or
-- "No sword" when the backpack really has none.
local function refreshEmptyLabel()
	local backpack = player:FindFirstChildOfClass("Backpack")
	local owned = backpack and backpack:FindFirstChildOfClass("Tool")
	local touchFirst = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	emptyLabel.Text = if not owned then "No sword" elseif touchFirst then "Hold to draw" else "Press 1"
end

-- The sword the 1 key would draw: the last one held if it is still in the backpack, else the
-- backpack's first. Nil only when the player really owns none.
local function sheathedSword(): Tool?
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return nil end
	if lastEquipped and lastEquipped.Parent == backpack then return lastEquipped end
	return backpack:FindFirstChildOfClass("Tool")
end

local SHEATHED_FADE = 0.4 -- [TUNING] how much the render dims while the sword is put away

local function setPreviewFade(fade: number)
	viewport.ImageTransparency = fade
	for _, v in ipairs(outlineViews) do v.ImageTransparency = fade end
	shadowView.ImageTransparency = 0.55 + 0.45 * fade
end

local function applyTool(tool: Tool?)
	currentTool = tool
	if tool then lastEquipped = tool end
	if not tool then
		-- Nothing in hand. If a sword is owned, the slot still shows it -- dimmed, with no equipped
		-- ring or check -- so putting it away (the 1 key, a respawn in the hub) no longer looks like
		-- losing it (recording 2026-09-24: an empty dashed "Press 1" slot at 3:54 and 6:42).
		local sheathed = sheathedSword()
		clearPreview()
		equippedRing.Visible = false
		equippedGlow.Visible = false
		checkBadge.Visible = false
		tooltipRoot.Visible = false
		if sheathed then
			buildFace(sheathed:GetAttribute("Rarity") or "Common")
			renderPreview(sheathed)
			setPreviewFade(SHEATHED_FADE)
			sparkle.Visible = false
			emptyLabel.Visible = false
		else
			buildFace(nil)
			setPreviewFade(0)
			refreshEmptyLabel()
			emptyLabel.Visible = true
		end
		return
	end
	local rarity = tool:GetAttribute("Rarity") or "Common"
	buildFace(rarity)
	setPreviewFade(0)
	emptyLabel.Visible = false
	-- The slot only ever shows the sword in hand, so it always wears the equipped ring.
	local ringColor = EQUIPPED_GREEN
	ringStroke.Color = ringColor
	glowStroke.Color = ringColor
	equippedRing.Visible = true
	equippedGlow.Visible = true
	checkBadge.Visible = true
	renderPreview(tool)
	if tooltipRoot.Visible then fillTooltip(tool) end
end

local function findEquipped(character: Model?): Tool?
	if not character then return nil end
	return character:FindFirstChildOfClass("Tool")
end

local characterConnections = {}

local function watchCharacter(character: Model)
	for _, conn in ipairs(characterConnections) do conn:Disconnect() end
	characterConnections = {}
	applyTool(findEquipped(character))
	table.insert(characterConnections, character.ChildAdded:Connect(function(child)
		-- One frame later so the tool's replicated parts and attributes have all arrived.
		if child:IsA("Tool") then
			task.defer(function()
				if child.Parent == character then applyTool(child) end
			end)
		end
	end))
	table.insert(characterConnections, character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child == currentTool then
			applyTool(findEquipped(character))
		end
	end))
	-- Saved swords reach the backpack a moment after spawn (and drops arrive any time), so an
	-- empty slot's hint follows the backpack rather than only its state at spawn.
	task.spawn(function()
		local backpack = player:WaitForChild("Backpack", 10)
		if not backpack or player.Character ~= character then return end
		local function onChange()
			if currentTool == nil then applyTool(nil) end
		end
		table.insert(characterConnections, backpack.ChildAdded:Connect(onChange))
		table.insert(characterConnections, backpack.ChildRemoved:Connect(onChange))
		onChange()
	end)
end

if player.Character then watchCharacter(player.Character) end
player.CharacterAdded:Connect(watchCharacter)

-- Sheathe the held sword, or draw the last one back out (the old backpack slot-1 behaviour).
-- Shared by the 1 key and a long press on the slot. Switching swords stays in the Inventory.
local function toggleSword()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	if findEquipped(character) then
		humanoid:UnequipTools()
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	local tool = if lastEquipped and lastEquipped.Parent == backpack then lastEquipped else backpack:FindFirstChildOfClass("Tool")
	if tool then humanoid:EquipTool(tool) end
end

-- ── Hover / tap ──────────────────────────────────────────────────────────────
-- Shared press feedback (PanelChrome.pressFeedback) on the slot's bounce scale. Its steps are
-- called from the handlers below, which also serve touch's tap/hold logic.
local press = PanelChrome.pressFeedback(slot, {
	scale = bounce, wire = false,
	fill = function() return { face } end,
})

local function showTooltip()
	if not currentTool then return end
	fillTooltip(currentTool)
	tooltipRoot.Visible = true
	task.defer(syncShadow)
end

slot.MouseEnter:Connect(function()
	showTooltip()
	press.hover(true)
end)

slot.MouseLeave:Connect(function()
	tooltipRoot.Visible = false
	press.cancel()
end)

-- Phones have no hover and no 1 key: a tap toggles the tooltip, a long press sheathes or draws.
-- The tap is decided on release so a hold never also flashes the tooltip.
local HOLD_TIME = 0.45 -- [TUNING] seconds a finger must stay down to count as a hold
local holdToken = 0
local heldThrough = false

slot.InputBegan:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.Touch then
		holdToken += 1
		local token = holdToken
		heldThrough = false
		task.delay(HOLD_TIME, function()
			-- Still the same press, and the finger never lifted (it may have slid off the slot).
			if token == holdToken and input.UserInputState ~= Enum.UserInputState.End then
				heldThrough = true
				tooltipRoot.Visible = false
				toggleSword()
				press.up() -- spring back now, so the hold registers before the finger lifts
			end
		end)
	end
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		press.down()
	end
end)
slot.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.Touch then
		holdToken += 1 -- a release before HOLD_TIME cancels the pending hold
		if not heldThrough then
			if tooltipRoot.Visible then
				tooltipRoot.Visible = false
			else
				showTooltip()
			end
		end
	end
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		press.up()
	end
end)

-- ── 1 key ────────────────────────────────────────────────────────────────────
-- Hiding the default backpack also took away its slot-1 key, so this puts it back with the
-- same behaviour: 1 puts the held sword away, and 1 again draws that same sword back out.
-- Switching to a different sword stays in the Inventory panel.
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed or input.KeyCode ~= Enum.KeyCode.One then return end
	toggleSword()
end)

-- Studio-only hands-free capture: equip the first sword, then show its tooltip as a hover would.
local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))
GuiShowcase.register("HotbarTooltip", function()
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if not findEquipped(character) then
		local backpack = player:WaitForChild("Backpack")
		local first = backpack:FindFirstChildOfClass("Tool")
		if first then humanoid:EquipTool(first) end
	end
	local deadline = os.clock() + 5
	while currentTool == nil and os.clock() < deadline do task.wait(0.1) end
	if not currentTool then
		warn("[GuiShowcase] HotbarTooltip: no sword to show")
		return
	end
	showTooltip()
	bounce.Scale = 1.07
end)

print("[SwordHotbarGui] Equipped-sword hotbar enabled (default backpack hidden)")
