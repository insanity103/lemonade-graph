--// ReforgeGui  (the Reforge anvil: pick a relic sword, pay gold, watch the modifier reel spin)
-- Case-opening style: a strip of modifier cards scrolls past and decelerates onto the roll the
-- server already made; then the new sword is revealed with its rating change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local REFORGE = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("ReforgeAction")
local SwordValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwordValue"))
local WeaponModifiers = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponModifiers"))
local AudioManager = require(ReplicatedStorage:WaitForChild("AudioManager"))

local RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180), Uncommon = Color3.fromRGB(80, 200, 120), Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(180, 80, 240), Legendary = Color3.fromRGB(255, 200, 40),
}
local TIER_COLORS = {
	Color3.fromRGB(170, 170, 176), Color3.fromRGB(90, 200, 120), Color3.fromRGB(80, 150, 255),
	Color3.fromRGB(190, 90, 240), Color3.fromRGB(255, 200, 40), Color3.fromRGB(255, 80, 80),
}
local COLORS = {
	Panel = Color3.fromRGB(18, 18, 22), PanelLight = Color3.fromRGB(26, 26, 32), Dark = Color3.fromRGB(10, 10, 13),
	Stroke = Color3.fromRGB(45, 45, 55), Gold = Color3.fromRGB(255, 215, 60), Text = Color3.fromRGB(245, 245, 250),
	Muted = Color3.fromRGB(160, 160, 175), Button = Color3.fromRGB(35, 35, 45), Ember = Color3.fromRGB(232, 112, 42),
	Success = Color3.fromRGB(80, 220, 140), Error = Color3.fromRGB(255, 85, 85),
}

local CARD_W, CARD_H, CARD_GAP = 132, 150, 8
local REEL_CARDS = 48
local LAND_INDEX = 40 -- the result sits here; a few filler cards trail it
local SPIN_TIME = 4.6

-- ── Scaffolding ──────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ReforgeGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 22
screenGui.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.55
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Visible = false
overlay.Parent = screenGui

local modal = Instance.new("Frame")
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.Size = UDim2.fromOffset(800, 600)
modal.BackgroundColor3 = COLORS.Panel
modal.BorderSizePixel = 0
modal.Parent = overlay
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = modal end
do local s = Instance.new("UIStroke"); s.Color = COLORS.Ember; s.Thickness = 2; s.Transparency = 0.4; s.Parent = modal end

local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = COLORS.Text
	l.Font = Enum.Font.GothamMedium
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in pairs(props) do l[k] = v end
	l.Parent = parent
	return l
end
local function corner(inst, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = inst end

text(modal, { Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -220, 0, 32), Text = "Reforge", Font = Enum.Font.Fantasy,
	TextSize = 30, TextColor3 = COLORS.Ember })
text(modal, { Position = UDim2.fromOffset(20, 46), Size = UDim2.new(1, -220, 0, 20), TextSize = 13, TextColor3 = COLORS.Muted,
	Text = "Pay gold to re-roll a relic sword's modifiers. Rarity and Blessed slots stay; everything else is chance." })
local goldLabel = text(modal, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 18), Size = UDim2.fromOffset(180, 24),
	TextXAlignment = Enum.TextXAlignment.Right, TextSize = 16, TextColor3 = COLORS.Gold, Text = "Gold 0" })

local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -14, 0, 14)
closeBtn.Size = UDim2.fromOffset(34, 34)
closeBtn.BackgroundColor3 = COLORS.Button
closeBtn.Text = "X"
closeBtn.TextColor3 = COLORS.Text
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.Parent = modal
corner(closeBtn, 8)

-- Left: sword list. Right: the reel and the reveal.
local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(20, 76)
list.Size = UDim2.new(0, 280, 1, -96)
list.BackgroundColor3 = COLORS.PanelLight
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = modal
corner(list, 10)
do
	local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 6); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = list
	local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 8); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8); pad.Parent = list
end

local stage = Instance.new("Frame")
stage.Position = UDim2.fromOffset(316, 76)
stage.Size = UDim2.new(1, -336, 1, -96)
stage.BackgroundColor3 = COLORS.PanelLight
stage.BorderSizePixel = 0
stage.Parent = modal
corner(stage, 10)

local selectedTitle = text(stage, { Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 0, 22), Font = Enum.Font.GothamBold,
	TextSize = 16, Text = "Pick a sword" })
local selectedInfo = text(stage, { Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -28, 0, 36), TextSize = 12,
	TextColor3 = COLORS.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Text = "Choose a relic sword on the left." })

-- Reel window
local reelWindow = Instance.new("Frame")
reelWindow.Position = UDim2.fromOffset(14, 84)
reelWindow.Size = UDim2.new(1, -28, 0, CARD_H + 24)
reelWindow.BackgroundColor3 = COLORS.Dark
reelWindow.BorderSizePixel = 0
reelWindow.ClipsDescendants = true
reelWindow.Parent = stage
corner(reelWindow, 10)
local strip = Instance.new("Frame")
strip.BackgroundTransparency = 1
strip.Size = UDim2.fromOffset((CARD_W + CARD_GAP) * REEL_CARDS, CARD_H)
strip.Position = UDim2.fromOffset(0, 12)
strip.Parent = reelWindow
local marker = Instance.new("Frame")
marker.AnchorPoint = Vector2.new(0.5, 0)
marker.Position = UDim2.new(0.5, 0, 0, 0)
marker.Size = UDim2.new(0, 3, 1, 0)
marker.BackgroundColor3 = COLORS.Ember
marker.BorderSizePixel = 0
marker.ZIndex = 5
marker.Parent = reelWindow
local idleHint = text(reelWindow, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 14,
	TextColor3 = COLORS.Muted, Text = "The anvil is cold. Select a sword and strike." })

-- Reveal panel under the reel
local reveal = Instance.new("Frame")
reveal.Position = UDim2.fromOffset(14, 84 + CARD_H + 36)
reveal.Size = UDim2.new(1, -28, 0, 118)
reveal.BackgroundColor3 = COLORS.Dark
reveal.BorderSizePixel = 0
reveal.Visible = false
reveal.Parent = stage
corner(reveal, 10)
local revealName = text(reveal, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 24), Font = Enum.Font.GothamBold, TextSize = 16 })
local revealMods = text(reveal, { Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 40), TextSize = 12, TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = COLORS.Text })
local revealRating = text(reveal, { Position = UDim2.fromOffset(12, 84), Size = UDim2.new(1, -24, 0, 24), Font = Enum.Font.GothamBold, TextSize = 15 })

-- Odds disclosure + pity meter (right of the reel, under the reveal) and a skip toggle.
local oddsLabel = text(stage, { Position = UDim2.fromOffset(14, 84 + CARD_H + 36 + 122), Size = UDim2.new(1, -28, 0, 48), TextSize = 11,
	TextColor3 = COLORS.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Text = "" })
local skipBtn = Instance.new("TextButton")
skipBtn.AnchorPoint = Vector2.new(1, 1)
skipBtn.Position = UDim2.new(1, -14, 1, -14)
skipBtn.Size = UDim2.fromOffset(150, 30)
skipBtn.BackgroundColor3 = COLORS.Button
skipBtn.Text = "Animation: on"
skipBtn.TextColor3 = COLORS.Muted
skipBtn.Font = Enum.Font.GothamMedium
skipBtn.TextSize = 12
skipBtn.Parent = stage
corner(skipBtn, 8)
local skipAnimation = false
skipBtn.Activated:Connect(function()
	skipAnimation = not skipAnimation
	skipBtn.Text = skipAnimation and "Animation: skipped" or "Animation: on"
end)
local oddsInfo = nil
local locked = {} -- modifier names chosen to survive the reroll (each one raises the price by its tier)

-- Lock row: one small chip per modifier on the selected sword; tap to keep it.
local lockRow = Instance.new("Frame")
lockRow.Position = UDim2.fromOffset(14, 84 + CARD_H + 36 + 122 + 50)
lockRow.Size = UDim2.new(1, -28, 0, 26)
lockRow.BackgroundTransparency = 1
lockRow.Parent = stage
do local l = Instance.new("UIListLayout"); l.FillDirection = Enum.FillDirection.Horizontal; l.Padding = UDim.new(0, 6); l.Parent = lockRow end
local statsLabel = text(modal, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 42), Size = UDim2.fromOffset(300, 20),
	TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12, TextColor3 = COLORS.Muted, Text = "" })

local strikeBtn = Instance.new("TextButton")
strikeBtn.AnchorPoint = Vector2.new(0.5, 1)
strikeBtn.Position = UDim2.new(0.5, 0, 1, -14)
strikeBtn.Size = UDim2.fromOffset(260, 44)
strikeBtn.BackgroundColor3 = COLORS.Ember
strikeBtn.Text = "Select a sword"
strikeBtn.TextColor3 = Color3.fromRGB(20, 12, 8)
strikeBtn.Font = Enum.Font.GothamBold
strikeBtn.TextSize = 16
strikeBtn.AutoButtonColor = false
strikeBtn.Parent = stage
corner(strikeBtn, 10)

-- On-screen opener: bottom-left, above the level panel, beside the other left-edge HUD.
local openBtn = Instance.new("TextButton")
openBtn.Name = "OpenReforge"
openBtn.AnchorPoint = Vector2.new(0, 1)
openBtn.Position = UDim2.new(0, 12, 1, -100)
openBtn.Size = UDim2.fromOffset(158, 38)
openBtn.BackgroundColor3 = Color3.fromRGB(58, 40, 30)
openBtn.Text = "Reforge  (reroll)"
openBtn.TextColor3 = COLORS.Gold
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 15
openBtn.Parent = screenGui
corner(openBtn, 8)
do local s = Instance.new("UIStroke"); s.Color = COLORS.Ember; s.Transparency = 0.3; s.Parent = openBtn end
openBtn.Activated:Connect(function()
	REFORGE:FireServer("Open")
end)

-- ── State ────────────────────────────────────────────────────────────────────
local rows = {}
local selected = nil
local spinning = false
local gold = 0

local function lockList()
	local names = {}
	for _, mod in ipairs(SwordValue.modifiersFromPrefixes(selected and selected.prefixes or "")) do
		if locked[mod.name] then table.insert(names, mod.name) end
	end
	return names
end

local function currentCost()
	if not selected then return 0 end
	local names = lockList()
	if #names > 0 then
		return SwordValue.rerollCostWithLocks({ Rarity = selected.rarity, Prefixes = selected.prefixes, ExtraSlot = selected.blessed,
			BossTier = selected.tier }, names)
	end
	if oddsInfo and (oddsInfo.freeIn or 1) <= 0 then return 0 end
	return selected.cost
end

local function setStrike()
	if spinning then
		strikeBtn.Text = "Reforging..."
		strikeBtn.BackgroundColor3 = COLORS.Button
		strikeBtn.TextColor3 = COLORS.Muted
	elseif selected then
		local cost = currentCost()
		local afford = gold >= cost
		local names = lockList()
		if cost == 0 then
			strikeBtn.Text = "Strike the anvil  ·  FREE"
		elseif #names > 0 then
			strikeBtn.Text = string.format("Strike, keeping %d  ·  %d gold", #names, cost)
		else
			strikeBtn.Text = string.format("Strike the anvil  ·  %d gold", cost)
		end
		strikeBtn.BackgroundColor3 = afford and COLORS.Ember or COLORS.Button
		strikeBtn.TextColor3 = afford and Color3.fromRGB(20, 12, 8) or COLORS.Muted
	else
		strikeBtn.Text = "Select a sword"
		strikeBtn.BackgroundColor3 = COLORS.Button
		strikeBtn.TextColor3 = COLORS.Muted
	end
end

local function describeMods(prefixes: string, blessed: boolean)
	local parts = {}
	if blessed then table.insert(parts, "Blessed slot") end
	for _, mod in ipairs(SwordValue.modifiersFromPrefixes(prefixes)) do
		local tierData = WeaponModifiers.Categories[mod.category].Tiers[mod.tier]
		table.insert(parts, string.format("%s (T%d %s)", mod.name, mod.tier, tierData and tierData.desc or mod.category))
	end
	return #parts > 0 and table.concat(parts, "  ·  ") or "No modifiers"
end

local function describeOdds(rarity)
	if not oddsInfo or not oddsInfo.odds or not oddsInfo.odds[rarity] then return "" end
	local o = oddsInfo.odds[rarity]
	local parts = {}
	for tier = 1, #o.tiers do
		table.insert(parts, string.format("T%d %.1f%%", tier, o.tiers[tier] * 100))
	end
	local pity = oddsInfo.pity or 0
	local pityText = pity >= (oddsInfo.pityAfter or 5)
		and string.format("Pity ready: next reforge guarantees a T%d+ modifier.", oddsInfo.pityTier or 4)
		or string.format("Pity %d / %d (then a T%d+ modifier is guaranteed).", pity, oddsInfo.pityAfter or 5, oddsInfo.pityTier or 4)
	return string.format("%s odds per modifier: %s.  Slots: %d (+1 at %.0f%%, Blessed +1 at %.0f%%).  %s", rarity,
		table.concat(parts, "  "), o.slots, (o.bonusSlotChance or 0) * 100, (oddsInfo.blessedChance or 0) * 100, pityText)
end

local function rebuildLockRow()
	for _, c in ipairs(lockRow:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
	end
	if not selected then return end
	local mods = SwordValue.modifiersFromPrefixes(selected.prefixes)
	if #mods == 0 then return end
	text(lockRow, { Size = UDim2.fromOffset(52, 26), TextSize = 11, TextColor3 = COLORS.Muted, Text = "Lock:" })
	local factors = (oddsInfo and oddsInfo.lockTierFactor) or SwordValue.LOCK_TIER_FACTOR
	for _, mod in ipairs(mods) do
		local on = locked[mod.name] == true
		local chip = Instance.new("TextButton")
		chip.Size = UDim2.fromOffset(math.max(84, #mod.name * 8 + 34), 26)
		chip.BackgroundColor3 = on and COLORS.Ember or COLORS.Button
		chip.Text = string.format("%s T%d  +%d%%", mod.name, mod.tier, math.floor((factors[mod.tier] or 0) * 100 + 0.5))
		chip.TextColor3 = on and Color3.fromRGB(20, 12, 8) or TIER_COLORS[mod.tier]
		chip.Font = Enum.Font.GothamBold
		chip.TextSize = 11
		chip.Parent = lockRow
		corner(chip, 6)
		chip.Activated:Connect(function()
			if spinning then return end
			locked[mod.name] = (not on) or nil
			rebuildLockRow()
			setStrike()
		end)
	end
end

local function selectRow(info)
	if not selected or selected.toolName ~= info.toolName then locked = {} end
	selected = info
	oddsLabel.Text = describeOdds(info.rarity)
	rebuildLockRow()
	selectedTitle.Text = info.name
	selectedTitle.TextColor3 = RARITY_COLORS[info.rarity] or COLORS.Text
	selectedInfo.Text = string.format("%s  ·  rating %s  ·  %s", info.rarity, SwordValue.short(info.rating), describeMods(info.prefixes, info.blessed))
	for _, r in ipairs(list:GetChildren()) do
		if r:IsA("Frame") then
			local stroke = r:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Transparency = (r.Name == info.toolName) and 0 or 0.6 end
		end
	end
	setStrike()
end

local function render(stateRows, goldValue, highlight, disclosure)
	rows = stateRows
	gold = goldValue
	if disclosure then
		oddsInfo = disclosure
		local freeIn = disclosure.freeIn or 0
		local freeText = freeIn <= 0 and "Free reforge ready" or string.format("Free reforge in %dh %02dm", math.floor(freeIn / 3600), math.floor(freeIn % 3600 / 60))
		statsLabel.Text = string.format("%s  ·  best roll %s  ·  %d reforges", freeText, SwordValue.short(disclosure.best or 0), disclosure.count or 0)
	end
	goldLabel.Text = "Gold " .. tostring(gold)
	for _, r in ipairs(list:GetChildren()) do
		if r:IsA("Frame") then r:Destroy() end
	end
	local stillSelected = nil
	for i, info in ipairs(rows) do
		local r = Instance.new("Frame")
		r.Name = info.toolName
		r.Size = UDim2.new(1, -6, 0, 66)
		r.BackgroundColor3 = COLORS.Panel
		r.BorderSizePixel = 0
		r.LayoutOrder = i
		r.Parent = list
		corner(r, 8)
		local s = Instance.new("UIStroke"); s.Color = RARITY_COLORS[info.rarity] or COLORS.Stroke; s.Transparency = 0.6; s.Parent = r
		text(r, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 18), Font = Enum.Font.GothamBold, TextSize = 13,
			TextColor3 = RARITY_COLORS[info.rarity] or COLORS.Text, Text = info.name, TextTruncate = Enum.TextTruncate.AtEnd })
		text(r, { Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 16), TextSize = 11, TextColor3 = COLORS.Muted,
			Text = string.format("%s · rating %s%s", info.rarity, SwordValue.short(info.rating), info.equipped and " · equipped" or ""), TextTruncate = Enum.TextTruncate.AtEnd })
		text(r, { Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 0, 16), TextSize = 12, TextColor3 = COLORS.Gold,
			Text = string.format("Reforge: %d gold", info.cost) })
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromScale(1, 1)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.Parent = r
		btn.Activated:Connect(function() if not spinning then selectRow(info) end end)
		if selected and info.toolName == (highlight or selected.toolName) then stillSelected = info end
	end
	if highlight then
		for _, info in ipairs(rows) do if info.toolName == highlight then stillSelected = info end end
	end
	if stillSelected then selectRow(stillSelected) else selected = nil; setStrike() end
end

-- ── The reel ─────────────────────────────────────────────────────────────────
local function makeCard(index, label, sub, color, big)
	local card = Instance.new("Frame")
	card.Position = UDim2.fromOffset((index - 1) * (CARD_W + CARD_GAP), 0)
	card.Size = UDim2.fromOffset(CARD_W, CARD_H)
	card.BackgroundColor3 = COLORS.PanelLight
	card.BorderSizePixel = 0
	card.Parent = strip
	corner(card, 8)
	local edge = Instance.new("Frame")
	edge.Size = UDim2.new(1, 0, 0, 5)
	edge.Position = UDim2.new(0, 0, 1, -5)
	edge.BackgroundColor3 = color
	edge.BorderSizePixel = 0
	edge.Parent = card
	text(card, { Position = UDim2.fromOffset(8, 14), Size = UDim2.new(1, -16, 0, big and 70 or 60), TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBold, TextSize = big and 15 or 14, TextColor3 = color, TextWrapped = true, Text = label })
	text(card, { Position = UDim2.fromOffset(8, big and 88 or 80), Size = UDim2.new(1, -16, 0, 40), TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 11, TextColor3 = COLORS.Muted, TextWrapped = true, Text = sub })
	return card
end

local function randomFillerCard(index, rarity)
	local odds = WeaponModifiers.TierOdds(rarity, 0)
	local pick, tier = math.random(), 1
	for t = 1, WeaponModifiers.TIER_COUNT do
		pick -= odds[t]
		if pick <= 0 then tier = t break end
	end
	local categories = { "Damage", "CritChance", "Range", "Knockback" }
	local category = categories[math.random(#categories)]
	local entry = WeaponModifiers.Categories[category].Tiers[tier]
	makeCard(index, entry.name, entry.desc, TIER_COLORS[tier])
end

local function spin(result)
	spinning = true
	setStrike()
	idleHint.Visible = false
	reveal.Visible = false
	for _, c in ipairs(strip:GetChildren()) do c:Destroy() end
	for i = 1, REEL_CARDS do
		if i == LAND_INDEX then
			local topTier = 1
			for _, m in ipairs(result.mods) do topTier = math.max(topTier, m.tier) end
			local names = {}
			for _, m in ipairs(result.mods) do table.insert(names, m.name) end
			if result.blessed then table.insert(names, 1, "Blessed") end
			makeCard(i, #names > 0 and table.concat(names, "\n") or "Plain", result.rarity, RARITY_COLORS[result.rarity] or COLORS.Text, true)
		else
			randomFillerCard(i, result.rarity)
		end
	end
	-- Land the result card under the marker, with a little random offset so it never looks scripted.
	local windowW = reelWindow.AbsoluteSize.X
	local landX = (LAND_INDEX - 1) * (CARD_W + CARD_GAP) + CARD_W / 2 + math.random(-40, 40)
	strip.Position = UDim2.fromOffset(windowW / 2 - CARD_W / 2, 12)
	local tween = TweenService:Create(strip, TweenInfo.new(skipAnimation and 0.35 or SPIN_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(windowW / 2 - landX, 12) })
	local lastIndex = 0
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local passing = math.floor((windowW / 2 - strip.Position.X.Offset) / (CARD_W + CARD_GAP))
		if passing ~= lastIndex then
			lastIndex = passing
			AudioManager.PlaySFX("ui_click", screenGui)
		end
	end)
	tween:Play()
	tween.Completed:Wait()
	conn:Disconnect()
	AudioManager.PlaySFX(result.after >= result.before and "quest_complete" or "enemy_hit", screenGui)
	-- Reveal
	reveal.Visible = true
	revealName.Text = result.toolName
	revealName.TextColor3 = RARITY_COLORS[result.rarity] or COLORS.Text
	local parts = {}
	if result.blessed then table.insert(parts, "Blessed slot") end
	for _, m in ipairs(result.mods) do table.insert(parts, string.format("%s (T%d %s)", m.name, m.tier, m.desc or m.category)) end
	revealMods.Text = (#parts > 0 and table.concat(parts, "  ·  ") or "No modifiers this time.")
		.. (result.pityApplied and "   (pity floor applied)" or "") .. (result.kept and ("   (kept " .. result.kept .. ")") or "")
	if result.personalBest then
		revealName.Text = revealName.Text .. "   NEW PERSONAL BEST"
	end
	local delta = result.after - result.before
	revealRating.Text = string.format("Rating %s  ->  %s   (%s%d)   %s", SwordValue.short(result.before), SwordValue.short(result.after),
		delta >= 0 and "+" or "", delta, result.free and "free" or ("-" .. result.cost .. " gold"))
	revealRating.TextColor3 = delta > 0 and COLORS.Success or (delta < 0 and COLORS.Error or COLORS.Muted)
	reveal.BackgroundColor3 = delta > 0 and Color3.fromRGB(18, 40, 26) or (delta < 0 and Color3.fromRGB(44, 18, 18) or COLORS.Dark)
	TweenService:Create(reveal, TweenInfo.new(1.2), { BackgroundColor3 = COLORS.Dark }):Play()
	spinning = false
	setStrike()
end

strikeBtn.Activated:Connect(function()
	if spinning or not selected then return end
	if gold < currentCost() then return end
	REFORGE:FireServer("Reroll", selected.toolName, lockList())
	locked = {}
end)

local function close()
	if spinning then return end
	overlay.Visible = false
end
closeBtn.Activated:Connect(close)
overlay.Activated:Connect(close)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape and overlay.Visible then close() end
end)

local pendingState = nil
REFORGE.OnClientEvent:Connect(function(kind, a, b, c, d)
	if kind == "Open" then
		overlay.Visible = true
		reveal.Visible = false
		idleHint.Visible = true
		for _, card in ipairs(strip:GetChildren()) do card:Destroy() end
	elseif kind == "Result" then
		pendingState = nil
		task.spawn(function()
			spin(a)
			if pendingState then render(pendingState[1], pendingState[2], pendingState[3], pendingState[4]) pendingState = nil end
		end)
	elseif kind == "State" then
		if spinning then
			pendingState = { a, b, c, d } -- apply after the reel lands so the list does not jump mid-spin
		else
			render(a, b, c, d)
		end
	end
end)
