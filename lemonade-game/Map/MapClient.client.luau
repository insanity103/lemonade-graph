-- LocalScript | StarterPlayerScripts.MapClient | Map project only: region entry banner, waystone
-- travel menu, discovery toasts and a Return to Hub button. Reads markers straight from Workspace.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local map = workspace:WaitForChild("LemonadeMap", 20)
local markers = map and map:WaitForChild("Markers", 10)
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local travelRemote = markers and remotes:WaitForChild("TravelAction", 20)
if not (map and markers and travelRemote) then
	return
end

local HUB_WAYPOINT = "HubSpawn"
local REGION_POLL = 0.4
local BANNER_HOLD = 2.6
local TOAST_HOLD = 2.8
local CLOSE_ACTION = "CloseTravelMenu"

local COLORS = {
	panel = Color3.fromRGB(24, 22, 20),
	stroke = Color3.fromRGB(120, 96, 64),
	title = Color3.fromRGB(255, 226, 160),
	text = Color3.fromRGB(236, 230, 218),
	muted = Color3.fromRGB(140, 134, 124),
	button = Color3.fromRGB(58, 48, 38),
	buttonHot = Color3.fromRGB(92, 72, 44),
	deny = Color3.fromRGB(255, 140, 120),
	good = Color3.fromRGB(150, 230, 200),
}

-- ── Marker data ─────────────────────────────────────────────────────────────
local function readSorted(folderName: string)
	local list = {}
	local folder = markers:FindFirstChild(folderName)
	for _, part in ipairs(folder and folder:GetChildren() or {}) do
		if part:IsA("BasePart") then
			table.insert(list, part)
		end
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
	end)
	return list
end

local regionParts = readSorted("Regions")
local waypointParts = readSorted("Waypoints")
local regionByName = {}
for _, part in ipairs(regionParts) do
	regionByName[part.Name] = part
end

-- ── GUI scaffolding ─────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "MapTravelGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = COLORS.text
	l.Font = Enum.Font.GothamMedium
	for key, value in pairs(props) do
		l[key] = value
	end
	l.Parent = parent
	return l
end

local function round(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

-- Region banner.
local banner = Instance.new("Frame")
banner.Name = "RegionBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 64)
banner.Size = UDim2.fromOffset(460, 70)
banner.BackgroundTransparency = 1
banner.Parent = gui
local bannerTitle = label(banner, {
	Size = UDim2.new(1, 0, 0, 44), Font = Enum.Font.Fantasy, TextSize = 38, TextColor3 = COLORS.title,
	TextStrokeTransparency = 0.4, TextTransparency = 1, TextStrokeColor3 = Color3.new(0, 0, 0),
})
local bannerSubtitle = label(banner, {
	Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 22), TextSize = 17,
	TextStrokeTransparency = 0.5, TextTransparency = 1,
})

-- Toast.
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 142)
toast.Size = UDim2.fromOffset(380, 36)
toast.BackgroundColor3 = COLORS.panel
toast.BackgroundTransparency = 1
toast.TextTransparency = 1
toast.Font = Enum.Font.GothamMedium
toast.TextSize = 15
toast.TextColor3 = COLORS.text
toast.Parent = gui
round(toast, 8)

-- Return to Hub.
local hubButton = Instance.new("TextButton")
hubButton.Name = "ReturnToHub"
hubButton.AnchorPoint = Vector2.new(0, 1)
hubButton.Position = UDim2.new(0, 12, 1, -150)
hubButton.Size = UDim2.fromOffset(158, 38)
hubButton.BackgroundColor3 = COLORS.button
hubButton.TextColor3 = COLORS.title
hubButton.Font = Enum.Font.GothamBold
hubButton.TextSize = 15
hubButton.Text = "⌂  Return to Hub"
hubButton.Visible = false
hubButton.Parent = gui
round(hubButton, 8)
local hubStroke = Instance.new("UIStroke")
hubStroke.Color = COLORS.stroke
hubStroke.Parent = hubButton

-- Travel menu.
local panel = Instance.new("Frame")
panel.Name = "TravelMenu"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(340, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = COLORS.panel
panel.BackgroundTransparency = 0.05
panel.Visible = false
panel.Parent = gui
round(panel, 12)
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COLORS.stroke
panelStroke.Thickness = 2
panelStroke.Parent = panel
local padding = Instance.new("UIPadding")
padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 14), UDim.new(0, 14)
padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
padding.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel

local header = Instance.new("Frame")
header.BackgroundTransparency = 1
header.Size = UDim2.new(1, 0, 0, 34)
header.LayoutOrder = 0
header.Parent = panel
label(header, { Size = UDim2.new(1, -40, 1, 0), Text = "Waystones", Font = Enum.Font.Fantasy, TextSize = 28,
	TextColor3 = COLORS.title, TextXAlignment = Enum.TextXAlignment.Left })
local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, 0, 0, 0)
closeButton.Size = UDim2.fromOffset(34, 34)
closeButton.BackgroundColor3 = COLORS.button
closeButton.Text = "✕"
closeButton.TextColor3 = COLORS.text
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.Parent = header
round(closeButton, 8)

local rows = {}

-- ── Behaviour ───────────────────────────────────────────────────────────────
local bannerToken, toastToken = 0, 0

local function fade(instance, props, time)
	TweenService:Create(instance, TweenInfo.new(time or 0.35), props):Play()
end

local function showBanner(title: string, subtitle: string)
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text, bannerSubtitle.Text = title, subtitle
	fade(bannerTitle, { TextTransparency = 0, TextStrokeTransparency = 0.4 })
	fade(bannerSubtitle, { TextTransparency = 0, TextStrokeTransparency = 0.5 })
	task.delay(BANNER_HOLD, function()
		if token ~= bannerToken then return end
		fade(bannerTitle, { TextTransparency = 1, TextStrokeTransparency = 1 }, 0.8)
		fade(bannerSubtitle, { TextTransparency = 1, TextStrokeTransparency = 1 }, 0.8)
	end)
end

local function showToast(text: string, color: Color3?)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.TextColor3 = color or COLORS.text
	fade(toast, { TextTransparency = 0, BackgroundTransparency = 0.2 }, 0.2)
	task.delay(TOAST_HOLD, function()
		if token ~= toastToken then return end
		fade(toast, { TextTransparency = 1, BackgroundTransparency = 1 }, 0.5)
	end)
end

local function displayName(id: string): string
	local part = markers.Waypoints:FindFirstChild(id)
	return part and part:GetAttribute("DisplayName") or id
end

local function closeMenu()
	panel.Visible = false
	ContextActionService:UnbindAction(CLOSE_ACTION)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then
		GuiService.SelectedObject = nil
	end
end

local function openMenu(sourceId: string, discovered: { string })
	for _, row in ipairs(rows) do
		row:Destroy()
	end
	table.clear(rows)
	local known = {}
	for _, id in ipairs(typeof(discovered) == "table" and discovered or {}) do
		known[id] = true
	end
	known[HUB_WAYPOINT] = true
	local firstSelectable
	for index, part in ipairs(waypointParts) do
		local id = part.Name
		local button = Instance.new("TextButton")
		button.Name = id
		button.LayoutOrder = index
		button.Size = UDim2.new(1, 0, 0, 46)
		button.BackgroundColor3 = COLORS.button
		button.AutoButtonColor = true
		button.Font = Enum.Font.GothamBold
		button.TextSize = 16
		button.TextXAlignment = Enum.TextXAlignment.Left
		round(button, 8)
		local inset = Instance.new("UIPadding")
		inset.PaddingLeft = UDim.new(0, 12)
		inset.Parent = button
		local region = regionByName[part:GetAttribute("Region") or ""]
		local regionText = region and region:GetAttribute("DisplayName") or ""
		if id == sourceId then
			button.Text = "◆  " .. displayName(id) .. "   (you are here)"
			button.TextColor3 = COLORS.muted
			button.Active, button.AutoButtonColor, button.Selectable = false, false, false
		elseif known[id] then
			button.Text = "➜  " .. displayName(id) .. (regionText ~= "" and ("   ·  " .. regionText) or "")
			button.TextColor3 = COLORS.text
			button.Activated:Connect(function()
				travelRemote:FireServer("Travel", id)
			end)
			firstSelectable = firstSelectable or button
		else
			button.Text = "?  Undiscovered waystone" .. (regionText ~= "" and ("   ·  " .. regionText) or "")
			button.TextColor3 = COLORS.muted
			button.Active, button.AutoButtonColor, button.Selectable = false, false, false
		end
		button.Parent = panel
		table.insert(rows, button)
	end
	panel.Visible = true
	ContextActionService:BindAction(CLOSE_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			closeMenu()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
	if UserInputService.GamepadEnabled and firstSelectable then
		GuiService.SelectedObject = firstSelectable
	end
end

closeButton.Activated:Connect(closeMenu)
hubButton.Activated:Connect(function()
	travelRemote:FireServer("Travel", HUB_WAYPOINT)
end)

travelRemote.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Open" then
		openMenu(a, b)
	elseif kind == "Discovered" then
		showToast("Waystone discovered: " .. displayName(a), COLORS.good)
	elseif kind == "Denied" then
		showToast(tostring(a), COLORS.deny)
	elseif kind == "Arrived" then
		closeMenu()
	end
end)

-- Region tracking: the highest-Order volume containing the character wins.
local currentRegion = nil
local function regionAt(position: Vector3)
	local found
	for _, part in ipairs(regionParts) do
		local p = part.CFrame:PointToObjectSpace(position)
		local half = part.Size / 2
		if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
			found = part
		end
	end
	return found
end

task.spawn(function()
	while gui.Parent do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local region = regionAt(root.Position)
			if region and region ~= currentRegion then
				currentRegion = region
				showBanner(region:GetAttribute("DisplayName") or region.Name, region:GetAttribute("Subtitle") or "")
			end
			hubButton.Visible = region ~= nil and region.Name ~= "Hub"
		end
		task.wait(REGION_POLL)
	end
end)
