--// CodexPanel  (draws the Codex tab of the Main Menu into its scrolling body)
-- Reads only the player's replicated attributes (CodexKills / CodexSwords / CodexClaims) and
-- Config.CodexConfig; CodexSystem on the server owns every number. Wave 1 of the 2026-09-25 plan.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CodexConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CodexConfig"))
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))

local BRIGHT = PanelChrome.BRIGHT
local CodexPanel = {}

local selectedZone = CodexConfig.Pages[1].zone

local function frame(parent, name, size, order, z)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = size
	f.LayoutOrder = order or 0
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function card(parent, name, size, order, z, color)
	local f = frame(parent, name, size, order, z)
	f.BackgroundTransparency = 0
	f.BackgroundColor3 = color or BRIGHT.Row
	PanelChrome.corner(f, 14)
	PanelChrome.stroke(f, BRIGHT.Outline, 3)
	return f
end

-- A grid tile: rounded, filled with a rarity's gradient and rim (one UIStroke only).
local function tile(parent, name, order, z, rarity)
	local f = frame(parent, name, UDim2.new(), order, z)
	f.BackgroundTransparency = 0
	PanelChrome.corner(f, 14)
	if rarity then
		PanelChrome.rarityTile(f, rarity)
	else
		f.BackgroundColor3 = BRIGHT.Grey
		PanelChrome.stroke(f, BRIGHT.GreyDark, 3)
	end
	return f
end

local function label(parent, text, size, color, props)
	props = props or {}
	props.text, props.size, props.color = text, size, color or BRIGHT.Ink
	props.scaled = props.scaled ~= false
	return PanelChrome.display(parent, props)
end

local function grid(parent, name, cell, order, z)
	local g = frame(parent, name, UDim2.new(1, 0, 0, 0), order, z)
	g.AutomaticSize = Enum.AutomaticSize.Y
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = cell
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = g
	return g
end

-- A thin fill bar, 0..1.
local function bar(parent, fraction, pos, size, z, color)
	local track = Instance.new("Frame")
	track.Name = "Bar"
	track.Position, track.Size = pos, size
	track.BackgroundColor3 = BRIGHT.Slot
	track.ZIndex = z
	track.Parent = parent
	PanelChrome.corner(track, 6)
	PanelChrome.stroke(track, BRIGHT.Outline, 2)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	fill.BackgroundColor3 = color or BRIGHT.Green
	fill.BorderSizePixel = 0
	fill.ZIndex = z + 1
	fill.Parent = track
	PanelChrome.corner(fill, 6)
	return track
end

-- opts: { player, narrow, rebuild = function() }  (rebuild redraws the tab after a zone pick)
function CodexPanel.build(body: ScrollingFrame, opts)
	local player = opts.player
	local narrow = opts.narrow
	local z = 23
	local kills = CodexConfig.DecodeKills(player:GetAttribute("CodexKills"))
	local found = CodexConfig.DecodeSet(player:GetAttribute("CodexSwords"))
	local claims = CodexConfig.DecodeSet(player:GetAttribute("CodexClaims"))

	-- ── Zone chips ──
	local chips = frame(body, "ZoneChips", UDim2.new(1, 0, 0, narrow and 46 or 54), 1, z)
	local chipLayout = Instance.new("UIListLayout")
	chipLayout.FillDirection = Enum.FillDirection.Horizontal
	chipLayout.Padding = UDim.new(0, 8)
	chipLayout.SortOrder = Enum.SortOrder.LayoutOrder -- route order, not alphabetical
	chipLayout.Parent = chips
	local chipW = 1 / #CodexConfig.Pages
	for i, page in ipairs(CodexConfig.Pages) do
		local p = CodexConfig.Progress(page, kills, found)
		local selected = page.zone == selectedZone
		local done = p.hunter and p.collector
		local btn = PanelChrome.chunkyButton(chips, {
			name = "Chip_" .. page.zone, text = page.name .. (done and " ✓" or ""),
			size = UDim2.new(chipW, -8, 1, 0), textSize = narrow and 18 or 22, zIndex = z + 1,
			color = selected and BRIGHT.Blue or BRIGHT.Grey, colorDark = selected and Color3.fromRGB(30, 110, 220) or BRIGHT.GreyDark,
		})
		btn.LayoutOrder = i
		btn.Activated:Connect(function()
			if selectedZone ~= page.zone then
				selectedZone = page.zone
				opts.rebuild()
			end
		end)
	end

	local page = CodexConfig.PageFor(selectedZone)
	local progress = CodexConfig.Progress(page, kills, found)

	-- ── Rewards summary ──
	local summary = card(body, "Summary", UDim2.new(1, 0, 0, narrow and 92 or 100), 2, z)
	local function rewardLine(y, title, have, total, reward, earned)
		label(summary, title, narrow and 20 or 24, BRIGHT.Ink, {
			size2 = UDim2.new(0.34, -12, 0, 30), pos = UDim2.fromOffset(14, y), xAlign = Enum.TextXAlignment.Left, zIndex = z + 1 })
		bar(summary, total > 0 and have / total or 0, UDim2.new(0.34, 0, 0, y + 8), UDim2.new(0.3, 0, 0, 16), z + 1,
			earned and BRIGHT.Gold or BRIGHT.Green)
		label(summary, string.format("%d/%d", have, total), 18, BRIGHT.Ink, {
			size2 = UDim2.new(0.08, 0, 0, 30), pos = UDim2.new(0.65, 4, 0, y), zIndex = z + 1 })
		label(summary, earned and ("✓ " .. reward) or reward, narrow and 16 or 20, earned and BRIGHT.GreenDark or BRIGHT.InkMuted, {
			size2 = UDim2.new(0.26, -14, 0, 30), pos = UDim2.new(0.74, 0, 0, y), xAlign = Enum.TextXAlignment.Right, zIndex = z + 1,
			stroke = 0 })
	end
	rewardLine(12, "Hunter", progress.mastered, progress.enemies,
		string.format("+%d%% damage", math.round(CodexConfig.HUNTER_DAMAGE * 100)), claims[page.zone .. ":hunter"] == true)
	rewardLine(narrow and 50 or 56, "Collector", progress.swords, progress.swordsTotal,
		string.format("+%d tokens", CodexConfig.CollectorTokens(page)), claims[page.zone .. ":collector"] == true)

	-- ── Bestiary ──
	label(frame(body, "BestiaryTitle", UDim2.new(1, 0, 0, 30), 3, z), "Bestiary", 26, BRIGHT.Ink,
		{ xAlign = Enum.TextXAlignment.Left, zIndex = z + 1, size2 = UDim2.fromScale(1, 1) })
	local beasts = grid(body, "Bestiary", UDim2.new(1 / 3, -7, 0, narrow and 110 or 120), 4, z)
	for i, e in ipairs(page.enemies) do
		local key, name, role = e[1], e[2], e[3]
		local n = kills[key] or 0
		local target = CodexConfig.Mastery(role)
		local t = tile(beasts, key, i, z + 1, n == 0 and "Common" or (role == "boss" and "Legendary" or "Rare"))
		label(t, n > 0 and name or "???", 22, Color3.new(1, 1, 1), {
			size2 = UDim2.new(1, -16, 0, 30), pos = UDim2.fromOffset(8, 10), zIndex = z + 2, stroke = 2.5 })
		label(t, role == "boss" and "Boss" or "Enemy", 15, Color3.new(1, 1, 1), {
			size2 = UDim2.new(1, -16, 0, 18), pos = UDim2.fromOffset(8, 40), zIndex = z + 2, stroke = 1 })
		bar(t, n / target, UDim2.new(0, 10, 1, -34), UDim2.new(1, -20, 0, 14), z + 2, n >= target and BRIGHT.Gold or BRIGHT.Green)
		label(t, string.format("%d/%d", math.min(n, target), target), 16, Color3.new(1, 1, 1), {
			size2 = UDim2.new(1, -20, 0, 18), pos = UDim2.new(0, 10, 1, -56), zIndex = z + 2, stroke = 1 })
		if n >= target then
			local check = PanelChrome.checkBadge(t, 30, z + 3)
			check.Position = UDim2.new(1, -8, 0, 8)
		end
	end

	-- ── Swords ──
	label(frame(body, "SwordsTitle", UDim2.new(1, 0, 0, 30), 5, z), "Swords", 26, BRIGHT.Ink,
		{ xAlign = Enum.TextXAlignment.Left, zIndex = z + 1, size2 = UDim2.fromScale(1, 1) })
	local swords = grid(body, "Swords", UDim2.new(narrow and 1 / 3 or 1 / 4, -8, 0, narrow and 96 or 104), 6, z)
	for i, s in ipairs(page.swords) do
		local have = found[s.name] == true
		local t = tile(swords, "Sword" .. i, i, z + 1, have and s.rarity or nil)
		label(t, have and s.name or "??", have and 17 or 34, have and Color3.new(1, 1, 1) or BRIGHT.GreyDark, {
			size2 = UDim2.new(1, -12, 0.62, 0), pos = UDim2.fromOffset(6, 6), zIndex = z + 2, stroke = have and 1.5 or 0,
			minSize = 10 })
		label(t, (s.ultra and "★ " or "") .. s.rarity, 14, have and Color3.new(1, 1, 1) or BRIGHT.GreyDark, {
			size2 = UDim2.new(1, -12, 0, 18), pos = UDim2.new(0, 6, 1, -26), zIndex = z + 2, stroke = have and 1 or 0 })
	end
end

return CodexPanel
