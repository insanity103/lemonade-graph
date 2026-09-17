--// VaultGui  (client UI for the Vaultkeeper: store and retrieve relic swords)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local VAULT_ACTION = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("VaultAction")
local SwordValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwordValue"))
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))

local RARITY_COLORS = PanelChrome.RARITY_COLORS
-- Local overlay: falls through to the shared palette, without mutating it.
local COLORS = setmetatable({
	Store = Color3.fromRGB(56, 92, 70), Take = Color3.fromRGB(70, 96, 150),
}, { __index = PanelChrome.COLORS })

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

local chrome = PanelChrome.build({
	name = "Modal",
	title = "Vaultkeeper",
	subtitle = "Relic swords stored here survive rebirths and follow you to any server.",
	accentColor = COLORS.Gold,
	size = UDim2.fromOffset(720, 520),
})
chrome.Frame.Parent = overlay
local modal = chrome.Frame
local closeBtn = chrome.CloseButton

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

local wealthLabel = label(modal, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 18), Size = UDim2.fromOffset(200, 24),
	TextXAlignment = Enum.TextXAlignment.Right, TextSize = 16, TextColor3 = COLORS.Gold, Text = "Wealth 0" })

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
