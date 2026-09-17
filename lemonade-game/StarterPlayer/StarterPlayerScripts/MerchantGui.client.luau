--// MerchantGui (Client shop UI for Safe Zone Relic Merchant)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MerchantConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MerchantConfig"))
local REMOTES = ReplicatedStorage:WaitForChild("RemoteEvents")
local MERCHANT_ACTION = REMOTES:WaitForChild("MerchantAction")
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))

local RARITY_COLORS = PanelChrome.RARITY_COLORS
-- Local overlay: falls through to the shared palette, without mutating it.
local COLORS = setmetatable({
	Overlay = Color3.fromRGB(0, 0, 0),
	PanelDark = Color3.fromRGB(12, 12, 15),
	ButtonHover = Color3.fromRGB(50, 50, 65),
}, { __index = PanelChrome.COLORS })

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MerchantGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = COLORS.Overlay
overlay.BackgroundTransparency = 1
overlay.Text = ""
overlay.Visible = false
overlay.ZIndex = 50
overlay.Parent = screenGui

local chrome = PanelChrome.build({
	name = "ShopModal",
	title = "★ RELIC BLACKSMITH",
	subtitle = "Forges boss relic swords with random modifiers (0% Blessed chance)",
	accentColor = COLORS.Gold,
	size = UDim2.fromOffset(540, 580),
})
local modal = chrome.Frame
modal.BackgroundTransparency = 0.04
modal.Visible = false
modal.ZIndex = 51
modal.Parent = screenGui
local closeBtn = chrome.CloseButton

-- Toast notice for purchase result
local noticeLabel = Instance.new("TextLabel")
noticeLabel.Name = "NoticeLabel"
noticeLabel.Position = UDim2.new(0, 18, 0, 78)
noticeLabel.Size = UDim2.new(1, -36, 0, 26)
noticeLabel.BackgroundTransparency = 1
noticeLabel.Font = Enum.Font.GothamMedium
noticeLabel.TextSize = 13
noticeLabel.TextColor3 = COLORS.Success
noticeLabel.Text = ""
noticeLabel.ZIndex = 53
noticeLabel.Visible = false
noticeLabel.Parent = modal

-- Scroll list
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "ItemList"
scroll.Position = UDim2.fromOffset(0, 108)
scroll.Size = UDim2.new(1, 0, 1, -113)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5
scroll.ScrollBarImageColor3 = COLORS.StrokeBright
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ZIndex = 52
scroll.Parent = modal

local scrollPad = Instance.new("UIPadding")
scrollPad.PaddingLeft = UDim.new(0, 18)
scrollPad.PaddingRight = UDim.new(0, 18)
scrollPad.PaddingBottom = UDim.new(0, 16)
scrollPad.Parent = scroll

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scroll

local function formatGold(num)
	return tostring(num):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function showNotice(text, isSuccess)
	noticeLabel.Text = text
	noticeLabel.TextColor3 = isSuccess and COLORS.Success or COLORS.Error
	noticeLabel.Visible = true
	task.delay(4, function()
		if noticeLabel.Text == text then
			noticeLabel.Visible = false
		end
	end)
end

local function buildShopList()
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local currentGold = (leaderstats and leaderstats:FindFirstChild("Gold")) and leaderstats.Gold.Value or (player:GetAttribute("Gold") or 0)

	for index, item in ipairs(MerchantConfig.Items) do
		local card = Instance.new("Frame")
		card.Name = "Item_" .. item.id
		card.Size = UDim2.new(1, 0, 0, 84)
		card.BackgroundColor3 = COLORS.PanelLight
		card.BorderSizePixel = 0
		card.LayoutOrder = index
		card.ZIndex = 53
		card.Parent = scroll

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 10)
		cardCorner.Parent = card

		local rarityCol = RARITY_COLORS[item.rarity] or COLORS.StrokeBright
		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = rarityCol
		cardStroke.Transparency = 0.5
		cardStroke.Thickness = 1.2
		cardStroke.Parent = card

		local cardPad = Instance.new("UIPadding")
		cardPad.PaddingLeft = UDim.new(0, 14)
		cardPad.PaddingRight = UDim.new(0, 14)
		cardPad.PaddingTop = UDim.new(0, 10)
		cardPad.PaddingBottom = UDim.new(0, 10)
		cardPad.Parent = card

		-- Sword Icon / Color Badge
		local badge = Instance.new("Frame")
		badge.Size = UDim2.fromOffset(40, 64)
		badge.BackgroundColor3 = item.color
		badge.BorderSizePixel = 0
		badge.ZIndex = 54
		badge.Parent = card
		local badgeCorner = Instance.new("UICorner", badge)
		badgeCorner.CornerRadius = UDim.new(0, 6)

		-- Info Column
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Position = UDim2.fromOffset(52, 2)
		nameLabel.Size = UDim2.new(1, -170, 0, 20)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 15
		nameLabel.TextColor3 = rarityCol
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = item.name .. string.format(" [x%.1f DMG]", item.baseMult)
		nameLabel.ZIndex = 54
		nameLabel.Parent = card

		local descLabel = Instance.new("TextLabel")
		descLabel.Position = UDim2.fromOffset(52, 24)
		descLabel.Size = UDim2.new(1, -170, 0, 36)
		descLabel.BackgroundTransparency = 1
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextSize = 11
		descLabel.TextColor3 = COLORS.Muted
		descLabel.TextWrapped = true
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.Text = item.desc
		descLabel.ZIndex = 54
		descLabel.Parent = card

		-- Buy Button
		local canAfford = currentGold >= item.price
		local buyBtn = Instance.new("TextButton")
		buyBtn.AnchorPoint = Vector2.new(1, 0.5)
		buyBtn.Position = UDim2.new(1, 0, 0.5, 0)
		buyBtn.Size = UDim2.fromOffset(110, 42)
		buyBtn.BackgroundColor3 = canAfford and COLORS.Gold or COLORS.Button
		buyBtn.BorderSizePixel = 0
		buyBtn.Font = Enum.Font.GothamBold
		buyBtn.TextSize = 13
		buyBtn.TextColor3 = canAfford and Color3.fromRGB(20, 20, 25) or COLORS.Muted
		buyBtn.Text = ("%s G"):format(formatGold(item.price))
		buyBtn.ZIndex = 54
		buyBtn.Parent = card

		local btnCorner = Instance.new("UICorner", buyBtn)
		btnCorner.CornerRadius = UDim.new(0, 8)

		local btnStroke = Instance.new("UIStroke", buyBtn)
		btnStroke.Color = canAfford and Color3.fromRGB(255, 235, 120) or COLORS.Stroke
		btnStroke.Thickness = 1

		buyBtn.Activated:Connect(function()
			MERCHANT_ACTION:FireServer("BuySword", item.id)
		end)
	end
end

local isOpen = false

local function setShopOpen(open)
	isOpen = open
	overlay.Visible = open
	modal.Visible = open
	if open then
		buildShopList()
		TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.5 }):Play()
	else
		TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		noticeLabel.Visible = false
	end
end

closeBtn.Activated:Connect(function() setShopOpen(false) end)
overlay.Activated:Connect(function() setShopOpen(false) end)

MERCHANT_ACTION.OnClientEvent:Connect(function(action, param1, param2)
	if action == "OpenShop" then
		setShopOpen(true)
	elseif action == "PurchaseResult" then
		local isSuccess = param1
		local message = param2
		showNotice(message, isSuccess)
		if isOpen then
			buildShopList()
		end
	end
end)

local leaderstats = player:WaitForChild("leaderstats", 10)
if leaderstats then
	local goldVal = leaderstats:WaitForChild("Gold", 5)
	if goldVal then
		goldVal.Changed:Connect(function()
			if isOpen then buildShopList() end
		end)
	end
end

print("[MerchantGui] Safe area relic merchant UI enabled")
