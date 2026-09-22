-- ModuleScript | ReplicatedStorage.UpgradeShop | Client: the Upgrade Stall's panel (required by GoldNumbers).
--
-- WHEEL UPGRADES. One bright panel, one card per upgrade (Config.UpgradeConfig.ORDER). Each card
-- says everything a player needs to decide: what the upgrade does NOW and what the NEXT tier
-- does, the ladder of tiers as chips (owned ones green, the next one lit, later ones grey with
-- their level gate), a "2/6" level badge, and one price button with the gold cost. The client
-- decides nothing: the state (owned tiers, prices, gates, gold) arrives from the Upgrade Stall
-- section of Gameplay/GameplayServices, and a click only sends UpgradeAction("Buy", id).
--
-- THE PURCHASE MOMENT (on the server's "Bought"): the button sinks and springs, the gold pill
-- counts DOWN from the old total to the new with a red "-750" dropping away from it, the bought
-- chip pops green with a check and a spark burst, the level badge punches to its new number, the
-- card flashes, and an "UPGRADED!" ribbon restates the new effect on the card. Then the next
-- tier's chip starts to glow and the button shows its price: the reason to come back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local UpgradeShop = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UpgradeConfig"))
local UPGRADE_ACTION = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("UpgradeAction")

local BRIGHT = PanelChrome.BRIGHT
local corner = PanelChrome.corner
local COIN_ICON = "rbxassetid://84697600263846" -- the HUD gold coin

-- [TUNING] design-space sizes; the whole window scales with one UIScale.
local W, H = 900, 540
local CARD_X, CARD_Y, CARD_W, CARD_H, CARD_GAP = 26, 98, 848, 126, 10
local ICON = 98
local CHIP_W, CHIP_H, CHIP_GAP = 64, 42, 8
local BUY_W, BUY_H = 220, 90

local THEME = {
	BodyTop = Color3.fromRGB(255, 251, 236), BodyBottom = Color3.fromRGB(246, 230, 190),
	Card = Color3.fromRGB(255, 255, 255), CardBottom = Color3.fromRGB(236, 242, 252),
	Ribbon = Color3.fromRGB(0, 196, 180), RibbonDark = Color3.fromRGB(0, 124, 118),
	Locked = Color3.fromRGB(196, 202, 214), LockedDark = Color3.fromRGB(150, 158, 174),
	Minus = Color3.fromRGB(255, 84, 84),
}

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function tween(inst, t, goal, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function frame(parent, name, props)
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	for k, v in pairs(props) do f[k] = v end
	f.Parent = parent
	return f
end

-- ------------------------------------------------------------------ the window
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UpgradeShopGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 21
screenGui.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Visible = false
overlay.ZIndex = 50
overlay.Parent = screenGui

local window = frame(screenGui, "UpgradeWindow", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H),
	BackgroundTransparency = 1, Visible = false, ZIndex = 51,
})
local panelScale = Instance.new("UIScale")
panelScale.Parent = window

local shadow = frame(window, "DropShadow", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 12), Size = UDim2.new(1, 12, 1, 12),
	BackgroundColor3 = Color3.fromRGB(8, 8, 18), BackgroundTransparency = 0.4, ZIndex = 50,
})
corner(shadow, 30)

local chrome = PanelChrome.buildBright({ name = "UpgradeModal", title = "Wheel Upgrades!", size = UDim2.fromOffset(W, H),
	titleSize = 50, closeSize = 60 })
local modal = chrome.Frame
modal.Size = UDim2.fromScale(1, 1)
modal.ZIndex = 51
modal.Parent = window
modal:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(THEME.BodyTop, THEME.BodyBottom)
modal:FindFirstChildOfClass("UIStroke").Thickness = 5.5
chrome.TitleIcon.Visible = false
chrome.TitleLabel.Position = UDim2.fromOffset(84, -2)

-- Title badge: a lemon coin with an up arrow (drawn, so it needs no asset).
local badge = frame(modal, "TitleBadge", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(40, -2), Size = UDim2.fromOffset(78, 78),
	BackgroundColor3 = Color3.new(1, 1, 1), Rotation = -8, ZIndex = 9,
})
corner(badge, 40)
PanelChrome.gradient(badge, Color3.fromRGB(255, 236, 110), BRIGHT.GoldDark)
PanelChrome.stroke(badge, BRIGHT.Outline, 4)
PanelChrome.display(badge, { text = "▲", size = 40, stroke = 3.5, zIndex = 10 })

local subtitle = PanelChrome.display(modal, {
	name = "Subtitle", text = "Spend gold on upgrades that last forever", size = 22, stroke = 0,
	color = BRIGHT.Ink, xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(CARD_X + 60, 38),
	size2 = UDim2.fromOffset(460, 30), zIndex = 52,
})
subtitle:FindFirstChildOfClass("UIStroke"):Destroy()

-- Gold pill (top right, left of the close button): the number that ticks down on a purchase.
local goldPill = frame(modal, "GoldPill", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -72, 0, 30), Size = UDim2.fromOffset(212, 56),
	BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 53,
})
corner(goldPill, 28)
PanelChrome.gradient(goldPill, Color3.fromRGB(255, 244, 196), Color3.fromRGB(255, 214, 110))
PanelChrome.stroke(goldPill, BRIGHT.Outline, 3.5)
local goldScale = Instance.new("UIScale")
goldScale.Parent = goldPill
local coin = Instance.new("ImageLabel")
coin.Name = "Coin"
coin.BackgroundTransparency = 1
coin.Image = COIN_ICON
coin.AnchorPoint = Vector2.new(0.5, 0.5)
coin.Position = UDim2.fromOffset(20, 28)
coin.Size = UDim2.fromOffset(58, 58)
coin.ZIndex = 55
coin.Parent = goldPill
local goldText = PanelChrome.display(goldPill, { name = "Gold", text = "0", size = 34, stroke = 3,
	xAlign = Enum.TextXAlignment.Right, pos = UDim2.fromOffset(52, 0), size2 = UDim2.new(1, -68, 1, 0), zIndex = 55 })

local footer = PanelChrome.display(modal, {
	name = "Footer", text = "Every tier is earned with gold from play. No Robux, ever.", size = 18, stroke = 0,
	color = BRIGHT.InkMuted, pos = UDim2.new(0, 0, 1, -32), size2 = UDim2.new(1, 0, 0, 24), zIndex = 52,
})
footer:FindFirstChildOfClass("UIStroke"):Destroy()

local cardsHolder = frame(modal, "Cards", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 52 })

-- ------------------------------------------------------------------ one card per upgrade
local cards = {} -- [id] = card
local state = nil
local shownGold = 0

local function buildCard(index, id)
	local def = UpgradeConfig.Defs[id]
	local c = { id = id, chips = {} }
	local y = CARD_Y + (index - 1) * (CARD_H + CARD_GAP)
	c.frame = frame(cardsHolder, id, {
		Position = UDim2.fromOffset(CARD_X, y), Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 53,
	})
	corner(c.frame, 20)
	PanelChrome.gradient(c.frame, THEME.Card, THEME.CardBottom)
	c.stroke = PanelChrome.stroke(c.frame, BRIGHT.Outline, 3.5)

	-- Icon tile
	c.icon = frame(c.frame, "Icon", {
		Position = UDim2.fromOffset(16, (CARD_H - ICON) / 2), Size = UDim2.fromOffset(ICON, ICON),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 54,
	})
	corner(c.icon, 20)
	PanelChrome.gradient(c.icon, def.color:Lerp(Color3.new(1, 1, 1), 0.35), def.colorDark)
	PanelChrome.stroke(c.icon, BRIGHT.Outline, 3.5)
	local shine = frame(c.icon, "Shine", {
		Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0.3, 0), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.6, ZIndex = 55,
	})
	corner(shine, 12)
	c.glyph = PanelChrome.display(c.icon, { text = def.glyph, size = 50, stroke = 4, zIndex = 56 })

	local midX = 16 + ICON + 16
	c.name = PanelChrome.display(c.frame, { name = "Name", text = def.name, size = 32, stroke = 3,
		xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(midX, 6), size2 = UDim2.fromOffset(250, 36), zIndex = 55 })
	c.name.AutomaticSize = Enum.AutomaticSize.X
	-- Level badge ("2/6"), just right of the name.
	c.levelBadge = frame(c.frame, "Level", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(midX, 24), Size = UDim2.fromOffset(70, 30),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 56,
	})
	corner(c.levelBadge, 15)
	c.levelGrad = PanelChrome.gradient(c.levelBadge, def.color:Lerp(Color3.new(1, 1, 1), 0.2), def.colorDark)
	PanelChrome.stroke(c.levelBadge, BRIGHT.Outline, 2.5)
	c.levelScale = Instance.new("UIScale")
	c.levelScale.Parent = c.levelBadge
	c.levelText = PanelChrome.display(c.levelBadge, { text = "0/0", size = 20, stroke = 2.5, zIndex = 57 })

	-- Effect line: now -> next
	c.effect = Instance.new("TextLabel")
	c.effect.Name = "Effect"
	c.effect.BackgroundTransparency = 1
	c.effect.RichText = true
	c.effect.Font = PanelChrome.DISPLAY_FONT
	c.effect.TextSize = 22
	c.effect.TextColor3 = BRIGHT.Ink
	c.effect.TextXAlignment = Enum.TextXAlignment.Left
	c.effect.Position = UDim2.fromOffset(midX, 42)
	c.effect.Size = UDim2.fromOffset(CARD_W - midX - BUY_W - 28, 26)
	c.effect.TextTruncate = Enum.TextTruncate.AtEnd
	c.effect.ZIndex = 55
	c.effect.Parent = c.frame

	-- Tier chips
	c.chipRow = frame(c.frame, "Tiers", {
		Position = UDim2.fromOffset(midX, 68), Size = UDim2.fromOffset(CARD_W - midX - BUY_W - 28, CHIP_H + 14),
		BackgroundTransparency = 1, ZIndex = 55,
	})
	for i = 1, #def.tiers do
		local chip = frame(c.chipRow, "Tier" .. i, {
			Position = UDim2.fromOffset((i - 1) * (CHIP_W + CHIP_GAP), 0), Size = UDim2.fromOffset(CHIP_W, CHIP_H),
			BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 56,
		})
		corner(chip, 12)
		local g = PanelChrome.gradient(chip, THEME.Locked, THEME.LockedDark)
		local s = PanelChrome.stroke(chip, BRIGHT.Outline, 2.5)
		local sc = Instance.new("UIScale")
		sc.Parent = chip
		local text = PanelChrome.display(chip, { text = "", size = 22, stroke = 2.5, zIndex = 58, scaled = true, minSize = 12 })
		text.Size = UDim2.new(1, -4, 1, -4)
		text.Position = UDim2.fromOffset(2, 2)
		local sub = PanelChrome.display(chip, { text = "", size = 13, stroke = 0, color = BRIGHT.InkMuted,
			pos = UDim2.new(0, -6, 1, 1), size2 = UDim2.new(1, 12, 0, 14), zIndex = 58 })
		sub:FindFirstChildOfClass("UIStroke"):Destroy()
		local check = PanelChrome.checkBadge(chip, 20, 59)
		check.Position = UDim2.new(1, -3, 0, 3)
		check.Visible = false
		c.chips[i] = { frame = chip, grad = g, stroke = s, scale = sc, text = text, sub = sub, check = check }
	end

	-- Buy button
	local btn, label, grad = PanelChrome.chunkyButton(c.frame, {
		name = "Buy", text = "", size = UDim2.fromOffset(BUY_W, BUY_H), anchor = Vector2.new(1, 0.5),
		pos = UDim2.new(1, -16, 0.5, 0), zIndex = 56, radius = 18, strokeThickness = 3.5,
	})
	label.Visible = false
	c.buy, c.buyGrad = btn, grad
	c.buyTop = PanelChrome.display(btn, { name = "Top", text = "BUY", size = 24, stroke = 2.5,
		pos = UDim2.fromOffset(0, 6), size2 = UDim2.new(1, 0, 0, 28), zIndex = 58 })
	c.priceRow = frame(btn, "Price", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 44), ZIndex = 58 })
	local layoutList = Instance.new("UIListLayout")
	layoutList.FillDirection = Enum.FillDirection.Horizontal
	layoutList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layoutList.VerticalAlignment = Enum.VerticalAlignment.Center
	layoutList.Padding = UDim.new(0, 4)
	layoutList.Parent = c.priceRow
	c.priceCoin = Instance.new("ImageLabel")
	c.priceCoin.BackgroundTransparency = 1
	c.priceCoin.Image = COIN_ICON
	c.priceCoin.Size = UDim2.fromOffset(40, 40)
	c.priceCoin.ZIndex = 59
	c.priceCoin.Parent = c.priceRow
	c.priceText = PanelChrome.display(c.priceRow, { text = "0", size = 34, stroke = 3, zIndex = 59,
		size2 = UDim2.fromOffset(0, 40) })
	c.priceText.AutomaticSize = Enum.AutomaticSize.X
	c.buyWide = PanelChrome.display(btn, { name = "Wide", text = "", size = 28, stroke = 3, zIndex = 58,
		scaled = true, minSize = 14 })
	c.buyWide.Size = UDim2.new(1, -16, 1, -16)
	c.buyWide.Position = UDim2.fromOffset(8, 8)
	c.buyWide.Visible = false

	-- Flash overlay and the "UPGRADED!" ribbon (hidden until a purchase).
	c.flash = frame(c.frame, "Flash", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1, ZIndex = 62 })
	corner(c.flash, 20)
	c.ribbon = frame(c.frame, "Ribbon", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -16 - BUY_W / 2, 0, 10),
		Size = UDim2.fromOffset(360, 38), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 64, Visible = false,
		Rotation = -2,
	})
	corner(c.ribbon, 14)
	PanelChrome.gradient(c.ribbon, Color3.fromRGB(150, 245, 120), BRIGHT.GreenDark)
	PanelChrome.stroke(c.ribbon, BRIGHT.Outline, 3)
	c.ribbonScale = Instance.new("UIScale")
	c.ribbonScale.Parent = c.ribbon
	c.ribbonText = PanelChrome.display(c.ribbon, { text = "UPGRADED!", size = 24, stroke = 2.5, zIndex = 65,
		scaled = true, minSize = 12 })
	c.ribbonText.Size = UDim2.new(1, -16, 1, -6)
	c.ribbonText.Position = UDim2.fromOffset(8, 3)

	btn.Activated:Connect(function()
		UpgradeShop.buy(id)
	end)
	cards[id] = c
	return c
end

for i, id in ipairs(UpgradeConfig.ORDER) do
	buildCard(i, id)
end

-- ------------------------------------------------------------------ drawing a state
local pulses = {} -- [chip frame] = true while its "next" glow runs

local function paintChip(c, i, tier, isNext)
	local chip = c.chips[i]
	local def = UpgradeConfig.Defs[c.id]
	chip.text.Text = tier.glyph
	chip.check.Visible = tier.status == "owned"
	chip.frame:SetAttribute("Next", isNext)
	if tier.status == "owned" then
		chip.grad.Color = ColorSequence.new(Color3.fromRGB(160, 246, 128), BRIGHT.GreenDark)
		chip.stroke.Color = BRIGHT.Outline
		chip.stroke.Thickness = 2.5
		chip.sub.Text = "OWNED"
		chip.sub.TextColor3 = BRIGHT.GreenDark
	elseif isNext then
		chip.grad.Color = ColorSequence.new(Color3.new(1, 1, 1), def.color:Lerp(Color3.new(1, 1, 1), 0.45))
		chip.stroke.Color = BRIGHT.GoldDark
		chip.stroke.Thickness = 3.5
		chip.sub.Text = if tier.status == "level" then ("LV " .. tier.minLevel)
			elseif tier.status == "rebirth" then ("R" .. tier.rebirths) else "NEXT"
		chip.sub.TextColor3 = BRIGHT.GoldDark
	else
		chip.grad.Color = ColorSequence.new(THEME.Locked, THEME.LockedDark)
		chip.stroke.Color = BRIGHT.Outline
		chip.stroke.Thickness = 2.5
		chip.sub.Text = if tier.rebirths > 0 then string.format("R%d", tier.rebirths) else ("LV " .. tier.minLevel)
		chip.sub.TextColor3 = BRIGHT.InkMuted
	end
end

local function paintCard(c, u)
	local def = UpgradeConfig.Defs[c.id]
	c.levelText.Text = string.format("%d/%d", u.owned, u.max)
	-- badge sits just right of the name text
	local nameW = TextService:GetTextSize(c.name.Text, 32, PanelChrome.DISPLAY_FONT, Vector2.new(1000, 100)).X
	c.levelBadge.Position = UDim2.fromOffset(c.name.Position.X.Offset + nameW + 12, 24)
	if u.nextText then
		c.effect.Text = string.format('%s  <font color="#2ea434">▶ %s</font>', u.now, u.nextShort or u.nextText)
	else
		c.effect.Text = string.format('<font color="#2ea434">%s</font>  (maxed)', u.now)
	end
	for i, tier in ipairs(u.tiers) do
		paintChip(c, i, tier, i == u.owned + 1)
	end
	-- the button
	local st = u.status
	c.buy:SetAttribute("Status", st)
	if st == "max" then
		c.buyTop.Visible, c.priceRow.Visible, c.buyWide.Visible = false, false, true
		c.buyWide.Text = "MAXED!"
		c.buyGrad.Color = ColorSequence.new(BRIGHT.Gold, BRIGHT.GoldDark)
	elseif st == "level" or st == "rebirth" or st == "order" then
		c.buyTop.Visible, c.priceRow.Visible, c.buyWide.Visible = true, true, false
		c.buyTop.Text = string.upper(u.reason or "Locked")
		c.priceText.Text = commas(u.price or 0)
		c.buyGrad.Color = ColorSequence.new(THEME.Locked, THEME.LockedDark)
	elseif st == "gold" then
		c.buyTop.Visible, c.priceRow.Visible, c.buyWide.Visible = true, true, false
		local need = (u.price or 0) - (state and state.gold or 0)
		c.buyTop.Text = "NEED " .. commas(math.max(need, 0)) .. " MORE"
		c.priceText.Text = commas(u.price or 0)
		c.buyGrad.Color = ColorSequence.new(THEME.Locked, THEME.LockedDark)
	else
		c.buyTop.Visible, c.priceRow.Visible, c.buyWide.Visible = true, true, false
		c.buyTop.Text = "BUY"
		c.priceText.Text = commas(u.price or 0)
		c.buyGrad.Color = ColorSequence.new(BRIGHT.Green, BRIGHT.GreenDark)
	end
	c.buyTop.TextSize = if #c.buyTop.Text > 12 then 18 else 24
	c.name.TextColor3 = Color3.new(1, 1, 1)
	c.icon.BackgroundTransparency = 0
	c.glyph.Text = def.glyph
end

local function applyState(newState, animateGold)
	if typeof(newState) ~= "table" or typeof(newState.upgrades) ~= "table" then return end
	state = newState
	for _, u in ipairs(newState.upgrades) do
		local c = cards[u.id]
		if c then paintCard(c, u) end
	end
	if not animateGold then
		shownGold = newState.gold or 0
		goldText.Text = commas(shownGold)
	end
end

-- The next-tier chips breathe (a slow scale and a gold stroke pulse) while the panel is open.
RunService.RenderStepped:Connect(function()
	if not window.Visible then return end
	local t = os.clock()
	for _, c in pairs(cards) do
		for _, chip in ipairs(c.chips) do
			if chip.frame:GetAttribute("Next") and not chip.popping then
				local k = (math.sin(t * 5) + 1) / 2
				chip.scale.Scale = 1 + 0.07 * k
				chip.stroke.Transparency = 0.35 * (1 - k)
			elseif not chip.popping then
				chip.scale.Scale = 1
				chip.stroke.Transparency = 0
			end
		end
	end
end)

-- ------------------------------------------------------------------ the purchase moment
local function sparks(parent: GuiObject, color: Color3, count: number)
	local at = parent.AbsolutePosition + parent.AbsoluteSize / 2 - modal.AbsolutePosition
	local s = panelScale.Scale
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + math.random() * 0.5
		local dist = (46 + math.random() * 40)
		local size = 8 + math.random() * 8
		local p = frame(modal, "Spark", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(at.X / s, at.Y / s),
			Size = UDim2.fromOffset(size, size), BackgroundColor3 = if i % 3 == 0 then Color3.new(1, 1, 1) else color,
			Rotation = math.random(0, 90), ZIndex = 70,
		})
		corner(p, 3)
		local goal = UDim2.fromOffset(at.X / s + math.cos(a) * dist, at.Y / s + math.sin(a) * dist)
		tween(p, 0.45, { Position = goal, Rotation = p.Rotation + 120, BackgroundTransparency = 1,
			Size = UDim2.fromOffset(size * 0.4, size * 0.4) })
		task.delay(0.5, function() p:Destroy() end)
	end
end

local goldConn = nil
local function countGoldDown(from: number, to: number)
	if goldConn then goldConn:Disconnect() end
	local t0 = os.clock()
	local dur = 0.55
	goldText.TextColor3 = THEME.Minus
	goldScale.Scale = 1.14
	tween(goldScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	coin.Rotation = -14
	tween(coin, 0.4, { Rotation = 0 }, Enum.EasingStyle.Back)
	goldConn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - t0) / dur, 0, 1)
		local e = 1 - (1 - a) ^ 3
		shownGold = from + (to - from) * e
		goldText.Text = commas(shownGold)
		if a >= 1 then
			goldConn:Disconnect()
			goldConn = nil
			shownGold = to
			goldText.Text = commas(to)
			tween(goldText, 0.25, { TextColor3 = Color3.new(1, 1, 1) })
		end
	end)
	-- the spent amount drops away from the pill in red
	local delta = PanelChrome.display(modal, { name = "Spent", text = "-" .. commas(from - to), size = 34, stroke = 3,
		color = THEME.Minus, anchor = Vector2.new(1, 0.5), pos = UDim2.new(1, -296, 0, 50),
		size2 = UDim2.fromOffset(200, 40), xAlign = Enum.TextXAlignment.Right, zIndex = 70 })
	local us = Instance.new("UIScale")
	us.Scale = 0.5
	us.Parent = delta
	tween(us, 0.14, { Scale = 1.25 })
	task.delay(0.14, function() tween(us, 0.2, { Scale = 1 }) end)
	tween(delta, 1.0, { Position = UDim2.new(1, -296, 0, 74) })
	task.delay(0.6, function()
		tween(delta, 0.4, { TextTransparency = 1 })
		local st = delta:FindFirstChildOfClass("UIStroke")
		if st then tween(st, 0.4, { Transparency = 1 }) end
	end)
	task.delay(1.1, function() delta:Destroy() end)
end

local function playBought(payload)
	local c = cards[payload.id]
	if not c then return end
	local def = UpgradeConfig.Defs[payload.id]
	countGoldDown(tonumber(payload.goldBefore) or shownGold, tonumber(payload.goldAfter) or shownGold)
	-- repaint to the new state, then dress the moment on top of it
	applyState(payload.state, true)
	local chip = c.chips[payload.tier]
	if chip then
		chip.popping = true
		chip.scale.Scale = 1.5
		tween(chip.scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(0.4, function() chip.popping = false end)
		sparks(chip.frame, BRIGHT.Green, 16)
	end
	c.levelScale.Scale = 1.5
	tween(c.levelScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	c.flash.BackgroundTransparency = 0.25
	tween(c.flash, 0.45, { BackgroundTransparency = 1 })
	c.stroke.Color = BRIGHT.GreenDark
	c.stroke.Thickness = 5
	task.delay(0.6, function()
		tween(c.stroke, 0.4, { Color = BRIGHT.Outline, Thickness = 3.5 })
	end)
	c.ribbonText.Text = string.format("UPGRADED!  %s", payload.effect or "")
	c.ribbon.Visible = true
	c.ribbonScale.Scale = 0.3
	tween(c.ribbonScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	sparks(c.icon, def.color, 12)
	c.glyph.Rotation = -12
	tween(c.glyph, 0.45, { Rotation = 0 }, Enum.EasingStyle.Back)
	local token = {}
	c.ribbonToken = token
	task.delay(2.4, function()
		if c.ribbonToken ~= token then return end
		tween(c.ribbonScale, 0.2, { Scale = 0 })
		task.delay(0.2, function()
			if c.ribbonToken == token then c.ribbon.Visible = false end
		end)
	end)
end

-- ------------------------------------------------------------------ open / close
local isOpen = false
local motion = {
	frame = window, scale = panelScale, dim = overlay, dimTo = 0.45,
	tiles = function() return { cardsHolder } end,
}

local restScale = 1
local function fit(viewport: Vector2)
	restScale = math.clamp(math.min(viewport.X * 0.94 / W, (viewport.Y - 36) * 0.97 / H), 0.45, 1.3)
	panelScale.Scale = restScale
end
PanelChrome.onViewport(fit)

local function setOpen(open: boolean)
	if open == isOpen then return end
	isOpen = open
	if open then
		overlay.Visible = true
		window.Visible = true
		PanelChrome.openMotion(motion)
	else
		PanelChrome.closeMotion(motion, function()
			overlay.Visible = false
			window.Visible = false
		end)
	end
end

function UpgradeShop.buy(id: string)
	if not isOpen then return end
	UPGRADE_ACTION:FireServer("Buy", id)
end

chrome.CloseButton.Activated:Connect(function() setOpen(false) end)
overlay.Activated:Connect(function() setOpen(false) end)

UPGRADE_ACTION.OnClientEvent:Connect(function(kind, payload)
	if typeof(payload) ~= "table" then return end
	if kind == "Open" then
		applyState(payload, false)
		setOpen(true)
	elseif kind == "State" then
		applyState(payload, false)
	elseif kind == "Bought" then
		playBought(payload)
	elseif kind == "Refused" then
		applyState(payload.state, false) -- the server's Notify says why
	end
end)

-- Walking away from the stall closes the shop; gold changes while open refresh it.
task.spawn(function()
	while true do
		task.wait(0.4)
		if isOpen then
			local stall = Workspace:FindFirstChild("UpgradeStall")
			local counter = stall and stall:FindFirstChild("Counter")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if counter and root and ((root.Position - counter.Position) * Vector3.new(1, 0, 1)).Magnitude
				> UpgradeConfig.RANGE + 6 then
				setOpen(false)
			end
		end
	end
end)
task.spawn(function()
	local ls = player:WaitForChild("leaderstats", 30)
	local gold = ls and ls:WaitForChild("Gold", 10)
	local level = ls and ls:WaitForChild("Level", 10)
	for _, stat in ipairs({ gold, level }) do
		if stat then
			stat.Changed:Connect(function()
				if isOpen and not goldConn then UPGRADE_ACTION:FireServer("State") end
			end)
		end
	end
end)

-- ------------------------------------------------------------------ Studio capture ("Motion:UpgradeShop")
-- The server stage walks the player up and opens the shop through the prompt's own handler, then
-- asks (player attribute) for the buy click; it happens here on the real button and remote.
if RunService:IsStudio() and Workspace:GetAttribute("GuiShowcase") == "Motion:UpgradeShop" then
	UPGRADE_ACTION:FireServer("State", "showcase")
	player:GetAttributeChangedSignal("GuiShowcaseUpgradeBuy"):Connect(function()
		local id = player:GetAttribute("GuiShowcaseUpgradeBuy")
		local c = typeof(id) == "string" and cards[id]
		if not c then return end
		local h = PanelChrome.pressHandle(c.buy)
		if h then
			h.hover(true)
			task.wait(0.15)
			h.down()
			task.wait(0.12)
			h.up()
		end
		UpgradeShop.buy(id)
	end)
end

print("[UpgradeShop] Upgrade Stall panel ready")

return UpgradeShop
