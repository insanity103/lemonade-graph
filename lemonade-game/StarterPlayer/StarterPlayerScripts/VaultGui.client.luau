--// VaultGui  (client UI for the Vaultkeeper: store and retrieve relic swords)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local VAULT_ACTION = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("VaultAction")
local SwordValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwordValue"))

local RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(80, 200, 120),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(180, 80, 240),
	Legendary = Color3.fromRGB(255, 200, 40),
}
local COLORS = {
	Panel = Color3.fromRGB(18, 18, 22), PanelLight = Color3.fromRGB(26, 26, 32),
	Stroke = Color3.fromRGB(45, 45, 55), Gold = Color3.fromRGB(255, 215, 60),
	Text = Color3.fromRGB(245, 245, 250), Muted = Color3.fromRGB(160, 160, 175),
	Button = Color3.fromRGB(35, 35, 45), Store = Color3.fromRGB(56, 92, 70), Take = Color3.fromRGB(70, 96, 150),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VaultGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 21
screenGui.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.5
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Visible = false
overlay.Parent = screenGui

local modal = Instance.new("Frame")
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.Size = UDim2.fromOffset(720, 520)
modal.BackgroundColor3 = COLORS.Panel
modal.BorderSizePixel = 0
modal.Parent = overlay
local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 14); corner.Parent = modal
local stroke = Instance.new("UIStroke"); stroke.Color = COLORS.Stroke; stroke.Thickness = 2; stroke.Parent = modal

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = COLORS.Text
	l.Font = Enum.Font.GothamMedium
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in pairs(props) do l[k] = v end
	l.Parent = parent
	return l
end

local title = label(modal, { Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -120, 0, 32), Text = "Vaultkeeper",
	Font = Enum.Font.Fantasy, TextSize = 30, TextColor3 = COLORS.Gold })
local subtitle = label(modal, { Position = UDim2.fromOffset(20, 46), Size = UDim2.new(1, -120, 0, 20), TextSize = 14,
	TextColor3 = COLORS.Muted, Text = "Relic swords stored here survive rebirths and follow you to any server." })
local wealthLabel = label(modal, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 18), Size = UDim2.fromOffset(200, 24),
	TextXAlignment = Enum.TextXAlignment.Right, TextSize = 16, TextColor3 = COLORS.Gold, Text = "Wealth 0" })

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
local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 8); cc.Parent = closeBtn

local function column(x, heading)
	local frame = Instance.new("Frame")
	frame.Position = UDim2.fromOffset(x, 76)
	frame.Size = UDim2.new(0.5, -30, 1, -96)
	frame.BackgroundColor3 = COLORS.PanelLight
	frame.BorderSizePixel = 0
	frame.Parent = modal
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = frame
	local head = label(frame, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 24), Text = heading,
		Font = Enum.Font.GothamBold, TextSize = 16 })
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(8, 40)
	list.Size = UDim2.new(1, -16, 1, -48)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return frame, head, list
end

local carriedFrame, carriedHead, carriedList = column(20, "Carrying")
local vaultFrame, vaultHead, vaultList = column(370, "In the vault")

local function row(parent, order, info, buttonText, buttonColor, onClick)
	local r = Instance.new("Frame")
	r.Size = UDim2.new(1, -6, 0, 58)
	r.BackgroundColor3 = COLORS.Panel
	r.BorderSizePixel = 0
	r.LayoutOrder = order
	r.Parent = parent
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = r
	local s = Instance.new("UIStroke"); s.Color = RARITY_COLORS[info.rarity] or COLORS.Stroke; s.Transparency = 0.5; s.Parent = r
	label(r, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -110, 0, 20), Text = info.name, Font = Enum.Font.GothamBold,
		TextSize = 14, TextColor3 = RARITY_COLORS[info.rarity] or COLORS.Text, TextTruncate = Enum.TextTruncate.AtEnd })
	local mods = info.prefixes ~= "" and info.prefixes or "No modifiers"
	label(r, { Position = UDim2.fromOffset(10, 27), Size = UDim2.new(1, -110, 0, 16), TextSize = 12, TextColor3 = COLORS.Muted,
		Text = string.format("%s · %s%s", info.rarity, mods, info.equipped and " · equipped" or ""), TextTruncate = Enum.TextTruncate.AtEnd })
	label(r, { Position = UDim2.fromOffset(10, 42), Size = UDim2.new(1, -110, 0, 14), TextSize = 12, TextColor3 = COLORS.Gold,
		Text = "Rating " .. SwordValue.short(info.rating or 0) })
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -8, 0.5, 0)
	b.Size = UDim2.fromOffset(88, 34)
	b.BackgroundColor3 = buttonColor
	b.Text = buttonText
	b.TextColor3 = COLORS.Text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.Parent = r
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 8); bc.Parent = b
	b.Activated:Connect(onClick)
end

local function clear(list)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
end

local function render(stored, carried, capacity, wealth)
	clear(carriedList); clear(vaultList)
	carriedHead.Text = string.format("Carrying (%d)", #carried)
	vaultHead.Text = string.format("In the vault (%d / %d)", #stored, capacity)
	wealthLabel.Text = "Wealth " .. SwordValue.short(wealth or 0)
	if #carried == 0 then
		label(carriedList, { Size = UDim2.new(1, 0, 0, 40), TextSize = 13, TextColor3 = COLORS.Muted, Text = "No relic swords on you." })
	end
	if #stored == 0 then
		label(vaultList, { Size = UDim2.new(1, 0, 0, 40), TextSize = 13, TextColor3 = COLORS.Muted, Text = "Nothing stored yet." })
	end
	for i, info in ipairs(carried) do
		row(carriedList, i, info, "Store", COLORS.Store, function() VAULT_ACTION:FireServer("Deposit", info.toolName) end)
	end
	for i, info in ipairs(stored) do
		row(vaultList, i, info, "Take", COLORS.Take, function() VAULT_ACTION:FireServer("Withdraw", info.index) end)
	end
end

local function close()
	overlay.Visible = false
end
closeBtn.Activated:Connect(close)
overlay.Activated:Connect(close)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape and overlay.Visible then close() end
end)

VAULT_ACTION.OnClientEvent:Connect(function(kind, stored, carried, capacity, wealth)
	if kind == "Open" then
		overlay.Visible = true
		modal.Size = UDim2.fromOffset(680, 480)
		TweenService:Create(modal, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(720, 520) }):Play()
	elseif kind == "State" then
		render(stored or {}, carried or {}, capacity or 12, wealth)
	end
end)
