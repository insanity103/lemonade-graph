--// DailyStreakGui  (the 7-day login calendar: pops up when today's reward is waiting)
-- Server: ServerScriptService.DailyStreak (every number and the claim itself). This draws the
-- week from the player's StreakNext / StreakClaimable attributes and the server's "Preview"
-- payload, and sends "Claim". A "Daily" button over Return to Hub reopens it any time.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
local DailyConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("DailyConfig"))
local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))

local player = Players.LocalPlayer
local DAILY = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("DailyAction")
local BRIGHT = PanelChrome.BRIGHT

local gui = Instance.new("ScreenGui")
gui.Name = "DailyStreakGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 12
gui.Parent = player:WaitForChild("PlayerGui")

-- ── Reopen button, stacked over Return to Hub ──
local openBtn, openLabel = PanelChrome.chunkyButton(gui, {
	name = "DailyButton", text = "Daily", size = UDim2.fromOffset(158, 38), anchor = Vector2.new(0, 1),
	color = BRIGHT.Gold, colorDark = BRIGHT.GoldDark, textSize = 20, zIndex = 5,
})
PanelChrome.onViewport(function(viewport)
	openBtn.Position = UDim2.new(0, PanelChrome.HUD.Margin, 1, -math.floor(PanelChrome.hudStackTop(viewport) + 8 + 38 + 8))
end)

-- ── The calendar ──
local shell = PanelChrome.build({ name = "DailyCalendar", title = "Daily Rewards",
	subtitle = "Log in every day. Miss one and the week starts over.", size = UDim2.fromOffset(760, 330),
	accentColor = BRIGHT.Gold })
local modal = shell.Frame
modal.Visible = false
modal.ZIndex = 10
modal.Parent = gui
local scale = Instance.new("UIScale")
scale.Parent = modal
PanelChrome.onViewport(function(viewport)
	scale.Scale = math.min(1, (viewport.X - 24) / 760, (viewport.Y - 24) / 330)
end)

local row = Instance.new("Frame")
row.Name = "Days"
row.BackgroundTransparency = 1
row.Position = UDim2.fromOffset(22, shell.HeaderBottom + 10)
row.Size = UDim2.new(1, -44, 0, 150)
row.Parent = modal
local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.Padding = UDim.new(0, 8)
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Parent = row

local claimBtn, claimLabel, claimGrad = PanelChrome.chunkyButton(modal, {
	name = "ClaimButton", text = "CLAIM", size = UDim2.fromOffset(260, 56), anchor = Vector2.new(0.5, 1),
	pos = UDim2.new(0.5, 0, 1, -14), textSize = 28,
})

local preview = nil -- the server's numbers for each day (rewardFor), refreshed on open

local function rewardText(r)
	if not r then return "..." end
	local parts = {}
	if r.sword then table.insert(parts, r.sword .. "+ sword") end
	if r.gold and r.gold > 0 then table.insert(parts, string.format("%d gold", r.gold)) end
	if r.tokens and r.tokens > 0 then table.insert(parts, string.format("%d tokens", r.tokens)) end
	return table.concat(parts, "\n")
end

local function draw()
	for _, c in ipairs(row:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	local nextDay = player:GetAttribute("StreakNext") or 1
	local claimable = player:GetAttribute("StreakClaimable") == true
	for day = 1, #DailyConfig.Days do
		local done = day < nextDay
		local today = day == nextDay
		local tile = Instance.new("Frame")
		tile.Name = "Day" .. day
		tile.Size = UDim2.new(1 / #DailyConfig.Days, -7, 1, 0)
		tile.LayoutOrder = day
		tile.ZIndex = 11
		tile.Parent = row
		PanelChrome.corner(tile, 14)
		PanelChrome.rarityTile(tile, day == #DailyConfig.Days and "Legendary" or (today and claimable) and "Rare"
			or done and "Uncommon" or "Common")
		PanelChrome.display(tile, { text = "Day " .. day, size = 22, stroke = 2.5, zIndex = 12,
			size2 = UDim2.new(1, -8, 0, 28), pos = UDim2.fromOffset(4, 8), scaled = true })
		PanelChrome.display(tile, { text = rewardText(preview and preview[day]), size = 15, stroke = 1, zIndex = 12,
			size2 = UDim2.new(1, -10, 0, 70), pos = UDim2.fromOffset(5, 44), scaled = true, minSize = 9 })
		if done then
			local check = PanelChrome.checkBadge(tile, 34, 13)
			check.Position = UDim2.new(0.5, 0, 1, -24)
		end
	end
	claimLabel.Text = claimable and string.format("CLAIM DAY %d", nextDay) or "COME BACK TOMORROW"
	if claimGrad then
		local top, bottom = claimable and BRIGHT.Green or BRIGHT.Grey, claimable and BRIGHT.GreenDark or BRIGHT.GreyDark
		claimGrad.Color = ColorSequence.new(top, bottom)
	end
	openLabel.Text = claimable and "Daily  !" or "Daily"
end

local function open()
	modal.Visible = true
	DAILY:FireServer("Preview")
	draw()
end
local function close() modal.Visible = false end

openBtn.Activated:Connect(function() if modal.Visible then close() else open() end end)
shell.CloseButton.Activated:Connect(close)
claimBtn.Activated:Connect(function()
	if player:GetAttribute("StreakClaimable") == true then DAILY:FireServer("Claim") end
end)

DAILY.OnClientEvent:Connect(function(kind, payload)
	if kind == "Preview" then
		preview = payload
		if modal.Visible then draw() end
	elseif kind == "Claimed" then
		task.delay(1.2, close)
	end
end)

for _, attr in ipairs({ "StreakNext", "StreakClaimable" }) do
	player:GetAttributeChangedSignal(attr):Connect(function()
		draw()
		-- A new day arriving (join, or midnight UTC mid-session) opens the calendar by itself.
		if attr == "StreakClaimable" and player:GetAttribute("StreakClaimable") == true then open() end
	end)
end
if player:GetAttribute("StreakClaimable") == true then open() else draw() end

GuiShowcase.register("Daily", function() open() end)
