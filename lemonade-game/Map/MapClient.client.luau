-- LocalScript | StarterPlayerScripts.MapClient | Map project only: region entry banner, waystone
-- travel menu, discovery toasts, Return to Hub button and a quest guide marker. Reads markers
-- straight from Workspace.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local map = workspace:WaitForChild("LemonadeMap", 20)
local markers = map and map:WaitForChild("Markers", 10)
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local travelRemote = markers and remotes:WaitForChild("TravelAction", 20)
if not (map and markers and travelRemote) then
	return
end

local QuestConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("QuestConfig"))
local BossWeapons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BossWeapons"))
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))

local HUB_WAYPOINT = "HubSpawn"
local REGION_POLL = 0.4
local BANNER_HOLD = 2.6
local TOAST_HOLD = 2.8
local CLOSE_ACTION = "CloseTravelMenu"

-- PS99 chrome (PanelChrome.BRIGHT): white panels, ink outline and text, sky-blue buttons, and a
-- gold accent for the quest guide's diamond and focus outline.
local COLORS = {
	panel = Color3.fromRGB(246, 249, 255),
	stroke = Color3.fromRGB(30, 33, 48),
	title = Color3.fromRGB(30, 33, 48),
	text = Color3.fromRGB(56, 62, 84),
	muted = Color3.fromRGB(128, 136, 158),
	button = Color3.fromRGB(64, 170, 255),
	buttonHot = Color3.fromRGB(30, 130, 240),
	deny = Color3.fromRGB(240, 64, 74),
	good = Color3.fromRGB(46, 164, 52),
	accent = Color3.fromRGB(255, 200, 40),
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

-- Markers are read on use rather than cached at startup: the client can start before the
-- persistent Markers model has finished replicating.
local function markerChild(folderName: string, name: string): BasePart?
	local folder = markers:FindFirstChild(folderName)
	local part = folder and folder:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
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
	Size = UDim2.new(1, 0, 0, 44), Font = Enum.Font.FredokaOne, TextSize = 40, TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0, TextTransparency = 1, TextStrokeColor3 = COLORS.stroke,
})
local bannerSubtitle = label(banner, {
	Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 22), TextSize = 17, Font = Enum.Font.GothamBold,
	TextColor3 = Color3.new(1, 1, 1), TextStrokeColor3 = COLORS.stroke, TextStrokeTransparency = 0.1, TextTransparency = 1,
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
hubButton.Size = UDim2.fromOffset(158, 38)
-- Stacks on top of the HUD's bottom-left cluster (vitals + gold readout), which scales with the
-- screen, so the two never overlap however that cluster is sized.
PanelChrome.onViewport(function(viewport)
	hubButton.Position = UDim2.new(0, PanelChrome.HUD.Margin, 1, -math.floor(PanelChrome.hudStackTop(viewport) + 8))
end)
hubButton.BackgroundColor3 = COLORS.button
hubButton.TextColor3 = COLORS.title
hubButton.Font = Enum.Font.GothamBold
hubButton.TextSize = 15
hubButton.Text = "Return to Hub"
hubButton.Visible = false
hubButton.Parent = gui
round(hubButton, 8)
local hubStroke = Instance.new("UIStroke")
hubStroke.Color = COLORS.stroke
hubStroke.Thickness = 2.5
-- Border mode outlines the button, not the 15 px letters (a 2.5 stroke on those blotted them out).
hubStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
hubStroke.Parent = hubButton

-- Travel menu: the shared modal shell (the same chrome as every other panel), with one chunky
-- button per waystone. The old hand-built frame used 16 px stroked text in fixed rows, which
-- blurred into blobs and ran past the row edge on long names (2026-09-24 recording, 1:18).
local ROW_HEIGHT = 48 -- [TUNING] pixels per waystone button
local ROW_GAP = 8
local PANEL_WIDTH = 420
local shell = PanelChrome.build({ name = "TravelMenu", title = "Waystones", size = UDim2.fromOffset(PANEL_WIDTH, 200) })
local panel = shell.Frame
panel.Visible = false
panel.Parent = gui
local closeButton = shell.CloseButton
local body = Instance.new("Frame")
body.Name = "Rows"
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(22, shell.HeaderBottom + 6)
body.Size = UDim2.new(1, -44, 1, -(shell.HeaderBottom + 24))
body.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, ROW_GAP)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = body

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
	fade(bannerTitle, { TextTransparency = 0, TextStrokeTransparency = 0 })
	fade(bannerSubtitle, { TextTransparency = 0, TextStrokeTransparency = 0.1 })
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
	local part = markerChild("Waypoints", id)
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
	local bright = PanelChrome.BRIGHT
	local waypoints = readSorted("Waypoints")
	for index, part in ipairs(waypoints) do
		local id = part.Name
		local region = markerChild("Regions", part:GetAttribute("Region") or "")
		local regionText = region and region:GetAttribute("DisplayName") or ""
		local suffix = if regionText ~= "" then " · " .. regionText else ""
		local text, usable
		if id == sourceId then
			text, usable = displayName(id) .. " (you are here)", false
		elseif known[id] then
			text, usable = displayName(id) .. suffix, true
		else
			text, usable = "Undiscovered" .. suffix, false
		end
		local button = PanelChrome.chunkyButton(body, {
			name = id, text = text, textSize = 20, radius = 12,
			color = if usable then bright.Blue else bright.Grey,
			colorDark = if usable then bright.Blue:Lerp(bright.Outline, 0.25) else bright.GreyDark,
			size = UDim2.new(1, 0, 0, ROW_HEIGHT), zIndex = 3,
		})
		button.LayoutOrder = index
		if usable then
			button.Activated:Connect(function()
				travelRemote:FireServer("Travel", id)
			end)
			firstSelectable = firstSelectable or button
		else
			button.Active, button.Selectable = false, false
		end
		table.insert(rows, button)
	end
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, shell.HeaderBottom + 30 + #waypoints * (ROW_HEIGHT + ROW_GAP))
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

-- ── Quest guide ─────────────────────────────────────────────────────────────
-- A single always-on-top marker over wherever the active quest wants the player next.
local GUIDE_HIDE_NEAR = 14 -- [TUNING] studs: the marker fades once the player is basically there
local GUIDE_HEIGHT = 8
local LIVE_TARGET_RANGE = 90 -- [TUNING] prefer outlining a living matching enemy this close

local guideAnchor = Instance.new("Part")
guideAnchor.Name = "QuestGuideAnchor"
guideAnchor.Anchored, guideAnchor.CanCollide, guideAnchor.CanQuery, guideAnchor.CanTouch = true, false, false, false
guideAnchor.Transparency = 1
guideAnchor.Size = Vector3.one
guideAnchor.Parent = workspace.CurrentCamera -- local only, never replicated

local guide = Instance.new("BillboardGui")
guide.Name = "QuestGuide"
guide.Adornee = guideAnchor
guide.AlwaysOnTop = true
guide.LightInfluence = 0
guide.Size = UDim2.fromOffset(220, 46)
guide.Enabled = false
guide.Parent = gui
local guideIcon = Instance.new("Frame") -- a rotated square; fonts lack a reliable diamond glyph
guideIcon.AnchorPoint = Vector2.new(0.5, 0.5)
guideIcon.Position = UDim2.new(0.5, 0, 0, 12)
guideIcon.Size = UDim2.fromOffset(14, 14)
guideIcon.Rotation = 45
guideIcon.BackgroundColor3 = COLORS.accent
guideIcon.BorderSizePixel = 0
guideIcon.Parent = guide
local guideIconStroke = Instance.new("UIStroke")
guideIconStroke.Color = Color3.new(0, 0, 0)
guideIconStroke.Thickness = 1.5
guideIconStroke.Parent = guideIcon
-- 16 px under a light outline: at 14 px with a full stroke the "|" and the digits ran together
-- ("Iron Lowlands gate | 75" in the 2026-09-24 recording).
local guideText = label(guide, { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 22), TextSize = 16,
	TextStrokeTransparency = 0.45, Font = Enum.Font.FredokaOne, TextColor3 = Color3.new(1, 1, 1), TextStrokeColor3 = COLORS.stroke })

-- Yellow outline on whatever the guide points at (an NPC or the enemy to fight).
local focus = Instance.new("Highlight")
focus.Name = "QuestFocus"
focus.FillTransparency = 1
focus.OutlineColor = COLORS.accent
focus.OutlineTransparency = 0.1
focus.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
focus.Parent = gui

local function namedModel(name: string): (Vector3?, Model?)
	local model = workspace:FindFirstChild(name)
	local root = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	return root and root.Position, model
end

local function liveEnemy(objective, origin: Vector3): Model?
	local best, bestDistance = nil, LIVE_TARGET_RANGE
	for _, enemy in ipairs(CollectionService:GetTagged("Enemy")) do
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		local root = enemy:IsA("Model") and enemy.PrimaryPart
		local matches = (objective.type == "KILL")
			or (objective.type == "KILL_ZONE" and enemy:GetAttribute("Zone") == objective.zone)
			or (objective.type == "KILL_BOSS" and enemy:GetAttribute("Archetype") == objective.archetype)
		if matches and humanoid and humanoid.Health > 0 and root then
			local distance = (root.Position - origin).Magnitude
			if distance < bestDistance then
				best, bestDistance = enemy, distance
			end
		end
	end
	return best
end

local function questDone(quest, progress: number): boolean
	local objective = quest.objective
	if objective.type == "LEVEL" then
		local stats = player:FindFirstChild("leaderstats")
		local level = stats and stats:FindFirstChild("Level")
		return level ~= nil and level.Value >= (objective.target or 1)
	elseif objective.type == "OBTAIN" or objective.type == "OBTAIN_POOL" then
		return progress >= 1
	end
	return progress >= (objective.count or 1)
end

local function nextQuestAvailable(): boolean
	local completed = {}
	for id in string.gmatch(player:GetAttribute("CompletedQuests") or "", "[^,]+") do
		completed[id] = true
	end
	for _, quest in ipairs(QuestConfig.QUESTS) do
		if not completed[quest.id] then return true end
	end
	return false
end

-- Nearest spawn marker matching the objective, preferring the region entrance while in the hub.
local function combatTarget(objective, root: BasePart, inRegion)
	local best, bestDistance
	local spawnFolder = markers:FindFirstChild("EnemySpawns")
	for _, spawnPart in ipairs(spawnFolder and spawnFolder:GetChildren() or {}) do
		local matches = (objective.type == "KILL")
			or (objective.type == "KILL_ZONE" and spawnPart:GetAttribute("Zone") == objective.zone)
			or (objective.type == "KILL_BOSS" and spawnPart:GetAttribute("Archetype") == objective.archetype)
		if matches then
			local distance = (spawnPart.Position - root.Position).Magnitude
			if not best or distance < bestDistance then
				best, bestDistance = spawnPart, distance
			end
		end
	end
	if not best then return nil end
	local regionName = best:GetAttribute("Region")
	local gate = markerChild("Gates", regionName or "")
	if inRegion and inRegion.Name == "Hub" and gate then
		local region = markerChild("Regions", regionName)
		return gate.Position, ((region and region:GetAttribute("DisplayName")) or regionName) .. " gate"
	end
	local label = if objective.type == "KILL_BOSS" then "Boss" else "Enemies"
	local enemy = liveEnemy(objective, root.Position)
	if enemy then
		return enemy.PrimaryPart.Position, label, enemy
	end
	return best.Position, label
end

local function resolveGuide(root: BasePart, inRegion)
	local activeId = player:GetAttribute("ActiveQuestId") or ""
	local quest = activeId ~= "" and QuestConfig.getQuestById(activeId)
	if not quest then
		if nextQuestAvailable() then
			local pos, model = namedModel(QuestConfig.GIVER_NAME)
			return pos, "New quest", model
		end
		return nil
	end
	if questDone(quest, player:GetAttribute("QuestProgress") or 0) then
		local pos, model = namedModel(QuestConfig.GIVER_NAME)
		return pos, "Turn in quest", model
	end
	local objective = quest.objective
	if objective.type == "OBTAIN_POOL" then
		-- Any sword of a boss's pool: earned from that boss.
		return combatTarget({ type = "KILL_BOSS", archetype = objective.poolKey }, root, inRegion)
	elseif objective.type == "OBTAIN" then
		-- A boss's unique drop is earned from that boss; only items nobody drops point at the shop.
		for archetype, weapon in pairs(BossWeapons.Weapons) do
			if weapon.name == objective.itemName then
				return combatTarget({ type = "KILL_BOSS", archetype = archetype }, root, inRegion)
			end
		end
		local pos, model = namedModel("RelicMerchantNPC")
		return pos, "Relic Blacksmith", model
	elseif objective.type == "KILL" or objective.type == "KILL_ZONE" or objective.type == "KILL_BOSS" then
		return combatTarget(objective, root, inRegion)
	end
	return nil
end

local function updateGuide(root: BasePart, inRegion)
	local target, text, model = resolveGuide(root, inRegion)
	focus.Adornee = model
	if not target or (target - root.Position).Magnitude < GUIDE_HIDE_NEAR then
		guide.Enabled = false
		return
	end
	guideAnchor.Position = target + Vector3.new(0, GUIDE_HEIGHT, 0)
	guideText.Text = string.format("%s · %dm", text, math.floor((target - root.Position).Magnitude))
	guide.Enabled = true
end

-- Sealed gates lead to regions that are not built yet; say so once per approach.
local GATE_NOTICE_RANGE, GATE_RESET_RANGE = 18, 40
local gateNoticed = {}
local function checkSealedGates(root: BasePart)
	local gates = markers:FindFirstChild("Gates")
	for _, gate in ipairs(gates and gates:GetChildren() or {}) do
		if gate:IsA("BasePart") and gate:GetAttribute("Sealed") == true then
			local distance = (gate.Position - root.Position).Magnitude
			if distance <= GATE_NOTICE_RANGE and not gateNoticed[gate] then
				gateNoticed[gate] = true
				showToast(string.format("%s is still being built - recommended Lv %d+ once it opens.",
					gate:GetAttribute("DisplayName") or gate.Name, gate:GetAttribute("RequiredLevel") or 1), COLORS.title)
			elseif distance > GATE_RESET_RANGE then
				gateNoticed[gate] = nil
			end
		end
	end
end

-- Region tracking: the highest-Order volume containing the character wins.
local currentRegion = nil
local function regionAt(position: Vector3)
	local found
	for _, part in ipairs(readSorted("Regions")) do
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
			updateGuide(root, region)
			checkSealedGates(root)
		else
			guide.Enabled = false
			focus.Adornee = nil
		end
		task.wait(REGION_POLL)
	end
end)
