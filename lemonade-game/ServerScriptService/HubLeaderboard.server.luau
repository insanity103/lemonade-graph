--// HubLeaderboard  (stone pillar showing top players by rebirth count)
-- Queries all in-memory profiles every 30 seconds and displays the top 10.
-- Purely read-only — no gameplay interaction.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local WorldLayout = require(script.Parent:WaitForChild("WorldLayout"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local hub = WorldLayout.HUB

-- Offset from hub center (north-west of spawn)
local OFFSET = Vector3.new(-14, 0, -10)
local BASE_POS = Vector3.new(hub.Center.X + OFFSET.X, hub.Center.Y, hub.Center.Z + OFFSET.Z)
local REFRESH_INTERVAL = 30

local leaderboard = Instance.new("Model")
leaderboard.Name = "HubLeaderboard"
leaderboard.Parent = Workspace

-- Pillar base
local pillar = Instance.new("Part")
pillar.Name = "Pillar"
pillar.Size = Vector3.new(6, 10, 1.5)
pillar.Material = Enum.Material.Marble
pillar.Color = Color3.fromRGB(200, 195, 180)
pillar.Anchored = true
pillar.TopSurface = Enum.SurfaceType.Smooth
pillar.BottomSurface = Enum.SurfaceType.Smooth
pillar.CFrame = CFrame.new(BASE_POS + Vector3.new(0, 5, 0))
pillar.Parent = leaderboard

-- Decorative cap
local cap = Instance.new("Part")
cap.Name = "Cap"
cap.Size = Vector3.new(7, 0.8, 2)
cap.Material = Enum.Material.Marble
cap.Color = Color3.fromRGB(180, 175, 160)
cap.Anchored = true
cap.TopSurface = Enum.SurfaceType.Smooth
cap.BottomSurface = Enum.SurfaceType.Smooth
cap.CFrame = CFrame.new(BASE_POS + Vector3.new(0, 10.4, 0))
cap.Parent = leaderboard

-- Title plaque
local titleGui = Instance.new("SurfaceGui")
titleGui.Name = "TitleGui"
titleGui.Face = Enum.NormalId.Front
titleGui.CanvasSize = Vector2.new(300, 80)
titleGui.Parent = pillar

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 1)
title.BackgroundTransparency = 1
title.Text = "LEADERBOARD"
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextColor3 = Color3.fromRGB(60, 50, 40)
title.TextStrokeTransparency = 0.8
title.Parent = titleGui

-- Leaderboard surface
local boardGui = Instance.new("SurfaceGui")
boardGui.Name = "BoardGui"
boardGui.Face = Enum.NormalId.Front
boardGui.CanvasSize = Vector2.new(300, 500)
boardGui.Parent = pillar

local boardFrame = Instance.new("Frame")
boardFrame.Size = UDim2.fromScale(1, 1)
boardFrame.Position = UDim2.fromScale(0, 0)
boardFrame.BackgroundColor3 = Color3.fromRGB(40, 35, 30)
boardFrame.BackgroundTransparency = 0.1
boardFrame.BorderSizePixel = 0
boardFrame.Parent = boardGui

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 2)
layout.Parent = boardFrame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 5)
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = boardFrame

-- Create 10 entry labels
local entries = {}
for i = 1, 10 do
	local row = Instance.new("TextLabel")
	row.Name = "Entry" .. i
	row.Size = UDim2.new(1, 0, 0, 42)
	row.BackgroundTransparency = 1
	row.Font = Enum.Font.GothamMedium
	row.TextSize = 15
	row.TextColor3 = i <= 3 and Color3.fromRGB(255, 220, 100) or Color3.fromRGB(180, 175, 165)
	row.TextStrokeTransparency = 0.7
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Text = ""
	row.LayoutOrder = i
	row.Parent = boardFrame
	entries[i] = row
end

-- Collect top players by rebirth count
local function getTopPlayers()
	local players = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local rebirths = player:GetAttribute("Rebirths") or 0
		if rebirths > 0 then
			table.insert(players, { name = player.Name, rebirths = rebirths })
		end
	end
	table.sort(players, function(a, b) return a.rebirths > b.rebirths end)
	return players
end

-- Update display
local function refresh()
	local top = getTopPlayers()
	for i = 1, 10 do
		if top[i] then
			local medal = ""
			if i == 1 then medal = "🥇 "
			elseif i == 2 then medal = "🥈 "
			elseif i == 3 then medal = "🥉 "
			end
			entries[i].Text = string.format("  %s#%d  %s  —  RB %d", medal, i, top[i].name, top[i].rebirths)
		else
			entries[i].Text = string.format("  #%d  —  —", i)
		end
	end
end

-- Initial + periodic refresh
refresh()
task.spawn(function()
	while true do
		task.wait(REFRESH_INTERVAL)
		refresh()
	end
end)

-- Billboard label
local labelGui = Instance.new("BillboardGui")
labelGui.Name = "LeaderboardLabel"
labelGui.Size = UDim2.fromOffset(200, 30)
labelGui.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
labelGui.AlwaysOnTop = false
labelGui.MaxDistance = 60
labelGui.Parent = cap

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "Leaderboard"
label.Font = Enum.Font.GothamBold
label.TextSize = 18
label.TextColor3 = Color3.fromRGB(255, 220, 100)
label.TextStrokeTransparency = 0.5
label.Parent = labelGui

print("[HubLeaderboard] Leaderboard pillar placed in hub")
