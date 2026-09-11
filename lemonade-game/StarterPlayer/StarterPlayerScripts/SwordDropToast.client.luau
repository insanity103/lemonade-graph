--// SwordDropToast (client) with Prefix & Stat Modifiers display and Auto-Sell toasts
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local REMOTES = ReplicatedStorage:WaitForChild("RemoteEvents")
local DROP_EVENT = REMOTES:WaitForChild("SwordDrop")
local AUTO_SELL_NOTICE = REMOTES:WaitForChild("AutoSellNotice")

local RARITY_COLOR = {
	Common = Color3.fromRGB(210, 210, 210),
	Uncommon = Color3.fromRGB(90, 200, 90),
	Rare = Color3.fromRGB(90, 150, 255),
	Epic = Color3.fromRGB(190, 110, 245),
	Legendary = Color3.fromRGB(255, 175, 50),
}

local gui = Instance.new("ScreenGui")
gui.Name = "SwordDropToast"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local holder = Instance.new("Frame")
holder.AnchorPoint = Vector2.new(1, 0.5)
holder.Position = UDim2.new(1, -16, 0.5, 0)
holder.Size = UDim2.fromOffset(280, 420)
holder.BackgroundTransparency = 1
holder.Parent = gui

local layout = Instance.new("UIListLayout", holder)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder

-- Handle normal sword drops
DROP_EVENT.OnClientEvent:Connect(function(rarityName, mult, fullName, mods, gotExtraSlot)
	mods = mods or {}
	local cardHeight = 52 + (#mods * 16)

	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(270, cardHeight)
	card.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Parent = holder

	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	local s = Instance.new("UIStroke", card)
	s.Color = RARITY_COLOR[rarityName] or Color3.fromRGB(255, 255, 255)
	s.Thickness = 1.5

	local goldStroke = nil
	if gotExtraSlot then
		local goldWrapper = Instance.new("Frame")
		goldWrapper.Size = UDim2.new(1, 6, 1, 6)
		goldWrapper.Position = UDim2.fromOffset(-3, -3)
		goldWrapper.BackgroundTransparency = 1
		goldWrapper.BorderSizePixel = 0
		goldWrapper.Parent = card
		Instance.new("UICorner", goldWrapper).CornerRadius = UDim.new(0, 10)
		goldStroke = Instance.new("UIStroke", goldWrapper)
		goldStroke.Color = Color3.fromRGB(255, 215, 0)
		goldStroke.Thickness = 2
		goldStroke.Transparency = 1
	end

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 4)
	title.Size = UDim2.fromOffset(246, 20)
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextSize = 14
	title.TextColor3 = RARITY_COLOR[rarityName] or Color3.fromRGB(255, 255, 255)
	title.Text = fullName or (rarityName .. " Sword")
	title.Parent = card

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(12, 24)
	desc.Size = UDim2.fromOffset(246, 16)
	desc.Font = Enum.Font.Gotham
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextSize = 12
	desc.TextColor3 = Color3.fromRGB(200, 200, 205)
	desc.Text = ("Base Mult: x%.2f Damage"):format(mult or 1)
	desc.Parent = card

	local textElements = { title, desc }
	local currY = 44

	-- Display list of modifiers
	for i, mod in ipairs(mods) do
		local modLbl = Instance.new("TextLabel")
		modLbl.BackgroundTransparency = 1
		modLbl.Position = UDim2.fromOffset(12, currY + (i - 1) * 16)
		modLbl.Size = UDim2.fromOffset(246, 14)
		modLbl.Font = Enum.Font.GothamMedium
		modLbl.TextXAlignment = Enum.TextXAlignment.Left
		modLbl.TextSize = 11
		modLbl.TextColor3 = Color3.fromRGB(130, 220, 130)
		modLbl.Text = string.format("• %s (%s)", mod.name, mod.desc)
		modLbl.Parent = card
		table.insert(textElements, modLbl)
	end

	card.BackgroundTransparency = 1
	for _, o in ipairs(textElements) do o.TextTransparency = 1 end
	s.Transparency = 1

	TweenService:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(s, TweenInfo.new(0.25), { Transparency = 0 }):Play()
	if goldStroke then
		TweenService:Create(goldStroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()
	end
	for _, o in ipairs(textElements) do
		TweenService:Create(o, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	end

	task.delay(4.0, function()
		TweenService:Create(card, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(s, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		if goldStroke then
			TweenService:Create(goldStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
		for _, o in ipairs(textElements) do
			TweenService:Create(o, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
		task.wait(0.45)
		card:Destroy()
	end)
end)

-- Handle auto-sold sword toasts
AUTO_SELL_NOTICE.OnClientEvent:Connect(function(fullName, rarityName, goldEarned)
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(270, 52)
	card.BackgroundColor3 = Color3.fromRGB(28, 26, 20)
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Parent = holder

	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	local s = Instance.new("UIStroke", card)
	s.Color = Color3.fromRGB(255, 215, 0)
	s.Thickness = 1.2

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.fromOffset(246, 20)
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextSize = 13
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.Text = "⚡ Auto-Sold Fewer-Slot Drop"
	title.Parent = card

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(12, 26)
	desc.Size = UDim2.fromOffset(246, 16)
	desc.Font = Enum.Font.Gotham
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextSize = 12
	desc.TextColor3 = Color3.fromRGB(220, 220, 230)
	desc.Text = string.format("%s (+%d Gold)", fullName, goldEarned)
	desc.Parent = card

	local textElements = { title, desc }
	card.BackgroundTransparency = 1
	for _, o in ipairs(textElements) do o.TextTransparency = 1 end
	s.Transparency = 1

	TweenService:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(s, TweenInfo.new(0.25), { Transparency = 0 }):Play()
	for _, o in ipairs(textElements) do
		TweenService:Create(o, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	end

	task.delay(3.0, function()
		TweenService:Create(card, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(s, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		for _, o in ipairs(textElements) do
			TweenService:Create(o, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
		task.wait(0.45)
		card:Destroy()
	end)
end)
