-- LocalScript | StarterPlayerScripts.AdminGui | Owner-only "mod menu" for bug-testing: set
-- level, add gold, give any boss sword fully rolled. The server (AdminSystem.server.luau) is
-- the real gate -- this script only decides whether to bother building the UI, so hiding it
-- here is convenience, not security. Fully self-contained: touches no other GUI's code or
-- layout. TO REMOVE: delete this file, ServerScriptService/AdminSystem.server.luau, and the
-- "AdminAction" line in RuntimeBootstrap's REMOTE_NAMES list.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Whoever owns this place gets the menu -- true in Studio, true once published, nothing to
-- configure. Extend EXTRA_ADMIN_IDS in AdminSystem.server.luau (not here) for teammates; the
-- server enforces that list too, so editing only this file grants no real access.
local isOwner = game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
if not isOwner then
	return
end

local playerGui = player:WaitForChild("PlayerGui")
local ADMIN = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("AdminAction")
local BossWeapons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BossWeapons"))
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))

local RARITY_COLORS = PanelChrome.RARITY_COLORS
-- Local overlay: falls through to the shared palette. Accent stays red (not gold) on
-- purpose -- a visual "this is a dev tool, not part of the game" signal.
local COLORS = setmetatable({
	Accent = Color3.fromRGB(220, 90, 90),
}, { __index = PanelChrome.COLORS })

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or COLORS.Stroke
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = props.font or Enum.Font.Gotham
	l.TextSize = props.textSize or 13
	l.TextColor3 = props.color or COLORS.Text
	l.TextXAlignment = props.align or Enum.TextXAlignment.Left
	l.Text = props.text or ""
	l.Position = props.pos or UDim2.fromOffset(0, 0)
	l.Size = props.size or UDim2.new(1, 0, 0, 18)
	l.Parent = parent
	return l
end

local function button(parent, props)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = props.bg or COLORS.Button
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.TextSize = props.textSize or 13
	b.TextColor3 = props.color or COLORS.Text
	b.Text = props.text or ""
	b.Position = props.pos or UDim2.fromOffset(0, 0)
	b.Size = props.size or UDim2.fromOffset(120, 30)
	b.Parent = parent
	corner(b, 6)
	stroke(b)
	b.Activated:Connect(function()
		if props.onClick then
			props.onClick()
		end
	end)
	return b
end

local function textBox(parent, props)
	local t = Instance.new("TextBox")
	t.BackgroundColor3 = COLORS.PanelLight
	t.Font = Enum.Font.Gotham
	t.TextSize = 13
	t.TextColor3 = COLORS.Text
	t.PlaceholderText = props.placeholder or ""
	t.PlaceholderColor3 = COLORS.Muted
	t.Text = ""
	t.ClearTextOnFocus = false
	t.Position = props.pos or UDim2.fromOffset(0, 0)
	t.Size = props.size or UDim2.fromOffset(120, 30)
	t.Parent = parent
	corner(t, 6)
	stroke(t)
	return t
end

-- ── Scaffolding ──────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AdminGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 90
screenGui.Parent = playerGui

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "Toggle"
-- Top-left, under Roblox's own top bar: the bottom-left corner belongs to the player HUD
-- (gold readout, health and XP), which this dev button used to cover.
toggleBtn.AnchorPoint = Vector2.new(0, 0)
toggleBtn.Position = UDim2.new(0, 12, 0, 66)
toggleBtn.Size = UDim2.fromOffset(44, 44)
toggleBtn.BackgroundColor3 = COLORS.Panel
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 20
toggleBtn.Text = "\240\159\155\160" -- 🛠
toggleBtn.TextColor3 = COLORS.Gold
toggleBtn.Parent = screenGui
corner(toggleBtn, 22)
stroke(toggleBtn, COLORS.Accent, 1.5)

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.new(0, 12, 0, 118)
panel.Size = UDim2.fromOffset(300, 452)
panel.BackgroundColor3 = COLORS.Panel
panel.Visible = false
panel.Parent = screenGui
corner(panel, 10)
stroke(panel, COLORS.Accent, 1.5)

label(panel, { text = "Admin  (dev / bug-testing)", font = Enum.Font.GothamBold, textSize = 15,
	color = COLORS.Gold, pos = UDim2.fromOffset(14, 12), size = UDim2.new(1, -28, 0, 20) })

local closeBtn = button(panel, { text = "x", pos = UDim2.new(1, -34, 0, 10), size = UDim2.fromOffset(24, 24),
	bg = COLORS.PanelLight, onClick = function() panel.Visible = false end })

toggleBtn.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)

-- Level -------------------------------------------------------------------
label(panel, { text = "Level", font = Enum.Font.GothamBold, pos = UDim2.fromOffset(14, 44), size = UDim2.new(1, -28, 0, 16) })
local levelBox = textBox(panel, { placeholder = "1000", pos = UDim2.fromOffset(14, 64), size = UDim2.fromOffset(180, 30) })
button(panel, { text = "Set Level", pos = UDim2.fromOffset(200, 64), size = UDim2.fromOffset(86, 30), bg = COLORS.PanelLight,
	onClick = function()
		local n = tonumber(levelBox.Text)
		if n then
			ADMIN:FireServer("SetLevel", math.floor(n))
		end
	end })

-- Gold ----------------------------------------------------------------------
label(panel, { text = "Gold", font = Enum.Font.GothamBold, pos = UDim2.fromOffset(14, 104), size = UDim2.new(1, -28, 0, 16) })
local goldBox = textBox(panel, { placeholder = "custom amount", pos = UDim2.fromOffset(14, 124), size = UDim2.fromOffset(180, 30) })
button(panel, { text = "Add Gold", pos = UDim2.fromOffset(200, 124), size = UDim2.fromOffset(86, 30), bg = COLORS.PanelLight,
	onClick = function()
		local n = tonumber(goldBox.Text)
		if n then
			ADMIN:FireServer("AddGold", math.floor(n))
		end
	end })
local quickAmounts = { 1000, 10000, 100000 }
for i, amount in ipairs(quickAmounts) do
	button(panel, { text = "+" .. tostring(amount), pos = UDim2.fromOffset(14 + (i - 1) * 92, 160), size = UDim2.fromOffset(86, 26),
		textSize = 12, onClick = function()
			ADMIN:FireServer("AddGold", amount)
		end })
end

-- Swords ----------------------------------------------------------------------
label(panel, { text = "Give sword (best roll)", font = Enum.Font.GothamBold, pos = UDim2.fromOffset(14, 200), size = UDim2.new(1, -28, 0, 16) })

local swordList = {}
for archetypeKey in pairs(BossWeapons.Pools) do
	local weaponData = BossWeapons.GetLegendary(archetypeKey)
	table.insert(swordList, { key = archetypeKey, name = weaponData.name, rarity = weaponData.rarity, tier = BossWeapons.GetTier(archetypeKey) })
end
table.sort(swordList, function(a, b) return a.tier < b.tier end)

local y = 222
for _, entry in ipairs(swordList) do
	local row = button(panel, { text = "", pos = UDim2.fromOffset(14, y), size = UDim2.fromOffset(272, 30), bg = COLORS.PanelLight,
		onClick = function()
			ADMIN:FireServer("GiveSword", entry.key)
		end })
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Position = UDim2.fromOffset(10, 15)
	dot.Size = UDim2.fromOffset(8, 8)
	dot.BackgroundColor3 = RARITY_COLORS[entry.rarity] or COLORS.Muted
	dot.Parent = row
	corner(dot, 4)
	label(row, { text = entry.name, pos = UDim2.fromOffset(26, 0), size = UDim2.new(1, -34, 1, 0), color = COLORS.Text })
	y += 36
end

button(panel, { text = "Give All Swords", pos = UDim2.fromOffset(14, y + 4), size = UDim2.fromOffset(272, 30), bg = COLORS.Button,
	color = COLORS.Gold, onClick = function()
		ADMIN:FireServer("GiveAllSwords")
	end })

-- Toggle with a keybind too (Studio playtest often has no HUD room to spare).
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.P then
		panel.Visible = not panel.Visible
	end
end)

print("[AdminGui] Owner admin menu ready (bottom-left, or P)")
