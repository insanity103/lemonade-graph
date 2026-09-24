--// SpinStation  (client module, started by GoldNumbers.client: the town spin wheel, as this player
--   sees it). A ModuleScript under ReplicatedStorage (synced as a folder) rather than its own
--   LocalScript, so it rides the existing client script list, like TokenDrops.
-- The server builds the wheel's frame and owns every rule (the Spin Wheel section of GameplayServices). This script only PRESENTS:
--   1. THE FACE. The wheel's prize face is painted for THIS player: one wedge per sword in their
--      current pool (Config.SpinPools.Odds for their area, depth step and level, the same call the
--      server rolls), each wedge's angle its real odds and its colour its rarity, with the odds
--      printed on every wedge of 5% or more. The chase is a glowing neon wedge at its true angle
--      with a "?" coin riding it; a fixed pointer at 12 o'clock flicks over 24 rim pegs.
--   2. THE BOARD. Walk near and a bubble pops in beside the wheel: the area and depth step, each
--      sword with its true odds in big type on a rarity-framed tile (the chase as a "?" silhouette
--      on a turning light burst; a locked row shows its level instead of odds), the token cost, the tokens
--      you carry, the E / F keys (F greyed with a lock until multi-spin is bought) and what rotates
--      the pool next. It hides again when you walk off.
--   3. THE KEYS. The two ProximityPrompts use a custom look: a big white key cap by the plinth.
--   4. THE SPIN. On the server's Result the wheel spins down and stops with the pointer inside a
--      slice of the sword the server rolled; the marquee bulbs chase and flash in its rarity colour
--      while a copy of the real sword pops out of the hub, turns in its rarity light and flies to the
--      player. The words (name, rarity, prefix, odds) are the top-right popup's job (SpinPopup).
local RunService = game:GetService("RunService")
local SpinStation = {}
if not RunService:IsClient() then
	return SpinStation
end

local function run()
	local Players = game:GetService("Players")
	local ProximityPromptService = game:GetService("ProximityPromptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TweenService = game:GetService("TweenService")
	local Workspace = game:GetService("Workspace")

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local Config = ReplicatedStorage:WaitForChild("Config")
	local SpinPools = require(Config:WaitForChild("SpinPools"))
	local WeaponModifiers = require(Config:WaitForChild("WeaponModifiers"))
	local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
	local WheelGeometry = require(ReplicatedStorage:WaitForChild("WheelGeometry"))
	local TokenDrops = require(ReplicatedStorage:WaitForChild("TokenDrops"))
	local AudioManager = require(ReplicatedStorage:WaitForChild("AudioManager"))
	local SPIN_ACTION = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("SpinAction")

	local BRIGHT = PanelChrome.BRIGHT
	local RARITY_TILE = PanelChrome.RARITY_TILE
	local TEAL = Color3.fromRGB(0, 176, 166)
	local TEAL_DARK = Color3.fromRGB(0, 96, 100)
	local CREAM = Color3.fromRGB(255, 248, 228)

	local station = Workspace:WaitForChild("SpinWheel", 120)
	if not station then
		return
	end
	local rotor = station:WaitForChild("Rotor") :: Model
	local bulbsFolder = station:WaitForChild("Bulbs")
	local promptPart = station:WaitForChild("PromptPart") :: BasePart
	local boardAnchor = station:WaitForChild("BoardAnchor") :: BasePart
	local hubPart = rotor:WaitForChild("Hub") :: BasePart
	local singlePrompt = promptPart:WaitForChild("SpinOne") :: ProximityPrompt
	local multiPrompt = promptPart:WaitForChild("SpinMulti") :: ProximityPrompt

	-- The hub's frame at angle 0 (the server never turns the rotor). Every rotor part is moved from
	-- its offset in this frame, so nothing depends on how a model's pivot replicated.
	local stationCFrame = station:GetAttribute("StationCFrame")
	if typeof(stationCFrame) ~= "CFrame" then
		stationCFrame = station:GetPivot()
	end
	local basePivot = stationCFrame * CFrame.new(WheelGeometry.CENTER)
	local angle = 0
	local rotorParts, rotorOffsets = {}, {}
	local function trackRotorPart(part: BasePart)
		table.insert(rotorParts, part)
		table.insert(rotorOffsets, (basePivot * CFrame.Angles(0, 0, angle)):ToObjectSpace(part.CFrame))
	end
	for _, d in ipairs(rotor:GetDescendants()) do
		if d:IsA("BasePart") then trackRotorPart(d) end
	end
	local R = WheelGeometry.RADIUS
	local TAU = math.pi * 2

	-- ---------------------------------------------------------------- the pool (the display's copy of the server's read)
	local function levelOf(): number
		local stats = player:FindFirstChild("leaderstats")
		local lv = stats and stats:FindFirstChild("Level")
		return lv and lv.Value or tonumber(player:GetAttribute("Level")) or 1
	end

	local function currentPool()
		local zone = player:GetAttribute("SpinZone")
		if typeof(zone) ~= "string" or not SpinPools.Get(zone) then
			zone = SpinPools.Order[1]
		end
		local step = tonumber(player:GetAttribute("SpinStep")) or 1
		local rows, used = SpinPools.Odds(zone, math.max(1, step), levelOf())
		return zone, used or step, rows
	end

	-- Tokens one spin costs at the pool the board shows (the same SpinPools.CostFor the server charges).
	local function spinCost(): number
		local zone, step = currentPool()
		return SpinPools.CostFor(zone, step)
	end

	local function tokens(): number
		return math.max(0, math.floor(tonumber(player:GetAttribute("Tokens")) or 0))
	end
	local function multiCount(): number
		local n = math.floor(tonumber(player:GetAttribute("MultiSpin")) or 0)
		return n >= 2 and n or 0
	end
	local function combatLeft(): number
		local at = tonumber(player:GetAttribute("CombatAt"))
		if not at then return 0 end
		return math.max(0, SpinPools.COMBAT_LOCK - (Workspace:GetServerTimeNow() - at))
	end

	local function pct(p: number): string
		local v = p * 100
		if v <= 0 then return "0%" end
		if v >= 10 then return string.format("%d%%", math.floor(v + 0.5)) end
		if v >= 1 then return (string.format("%.1f%%", v):gsub("%.0%%", "%%")) end
		return (string.format("%.2f%%", v):gsub("0%%$", "%%"))
	end

	-- ---------------------------------------------------------------- 1. the face
	-- ONE WEDGE PER SWORD, sized by its real odds and painted in its rarity colour (the same colour
	-- as its tile's frame on the board), biggest first from the pointer, clockwise. The chase is a
	-- glowing neon wedge at its true angle with a "?" badge riding on it, so a player can find the
	-- rare wedge before paying and watch the pointer brush past it. Every big wedge prints its odds.
	local SLIVER_MIN = math.rad(2.2) -- the thinnest a wedge is drawn (the board prints the exact figure)
	local LABEL_MIN = 0.05           -- wedges of at least this share print their percent on the face
	local PEG_COUNT = 24             -- rim pegs the pointer clicks over (evenly spaced)
	local faceFolder: Folder? = nil
	local faceSlices = {}            -- { { a0, a1, row } } in the rotor's own angles (0 = 12 o'clock, clockwise)
	local faceBoundaries = {}        -- peg angles, for the ticker's clicks
	local faceKey = ""

	-- Wedge colour: every sword its own bright colour (the board's tile swatch shows the same colour,
	-- so the face reads as a legend). Uncommon and up wear their rarity's colour; commons take warm
	-- candy colours that never clash with a rarity; the chase is neon in its rarity colour.
	local swatch = {} -- [sword] = Color3, for the current pool
	local COMMON_COLORS = {
		Color3.fromRGB(255, 120, 164), -- strawberry
		Color3.fromRGB(255, 156, 52),  -- orange
		Color3.fromRGB(0, 196, 184),   -- mint teal
		Color3.fromRGB(255, 208, 64),  -- lemon
	}
	local function wedgeColor(rarity: string, n: number): Color3
		local t = RARITY_TILE[rarity] or RARITY_TILE.Common
		if rarity == "Common" then
			return COMMON_COLORS[(n - 1) % #COMMON_COLORS + 1]
		end
		return n % 2 == 1 and t.bottom or t.bottom:Lerp(t.rim, 0.45)
	end
	local function assignColors(rows)
		table.clear(swatch)
		local seen = {}
		for _, row in ipairs(rows or {}) do
			if not row.locked then
				seen[row.rarity] = (seen[row.rarity] or 0) + 1
				swatch[row.sword] = wedgeColor(row.rarity, seen[row.rarity])
			end
		end
	end

	-- Face labels stay UPRIGHT as the wheel turns (each rides its wedge like a Ferris-wheel car), so
	-- no percent ever reads upside down: they are moved every frame, not with the rotor's parts.
	local faceLabels = {} -- { { part, phi, r, z } }
	local function placeLabel(entry, frame, rotorAngle)
		return frame * CFrame.Angles(0, 0, -entry.phi) * CFrame.new(0, entry.r, entry.z)
			* CFrame.Angles(0, 0, entry.phi - rotorAngle)
	end
	local function faceLabel(folder, pivot, phi, r, text, size, color, strokeColor, z)
		local holder = Instance.new("Part")
		holder.Name = "FaceLabel"
		holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.CastShadow = true, false, false, false, false
		holder.Transparency = 1
		holder.Size = Vector3.new(size * 2.4, size, 0.05)
		local entry = { part = holder, phi = phi, r = r,
			z = z or (WheelGeometry.FACE_Z - WheelGeometry.FACE_THICK / 2 - 0.06) }
		holder.CFrame = placeLabel(entry, pivot, angle)
		table.insert(faceLabels, entry)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(240, 100)
		gui.LightInfluence = 0
		gui.Parent = holder
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = color
		label.Parent = gui
		local st = Instance.new("UIStroke")
		st.Color = strokeColor
		st.Thickness = 7
		st.Parent = label
		holder.Parent = folder
		return holder
	end

	local function paintFace(rows)
		if faceFolder then
			faceFolder:Destroy()
			-- drop the old face's parts from the rotor's move list
			for i = #rotorParts, 1, -1 do
				if not rotorParts[i]:IsDescendantOf(rotor) then
					table.remove(rotorParts, i)
					table.remove(rotorOffsets, i)
				end
			end
		end
		table.clear(faceSlices)
		table.clear(faceBoundaries)
		table.clear(faceLabels)
		local live = {}
		for _, row in ipairs(rows or {}) do
			if row.p > 0 then table.insert(live, row) end
		end
		if #live == 0 then return end
		-- Odds() is sorted biggest first; the chase (rarest) is last.
		-- Angles: thin wedges at their true angle (never thinner than SLIVER_MIN); the rest share what
		-- is left in proportion to their odds, so every wedge's angle is its real chance.
		local thinAngle, thickP = 0, 0
		for _, row in ipairs(live) do
			if row.p * TAU < SLIVER_MIN then thinAngle += SLIVER_MIN else thickP += row.p end
		end
		local folder = Instance.new("Folder")
		folder.Name = "Face"
		local pivot = basePivot * CFrame.Angles(0, 0, angle)
		local function divider(phi, width)
			local d = Instance.new("Part")
			d.Name = "Divider"
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
			d.Size = Vector3.new(width or 0.22, R - 1.2, WheelGeometry.FACE_THICK + 0.08)
			d.Color = BRIGHT.Outline
			d.Material = Enum.Material.SmoothPlastic
			d.CFrame = pivot * CFrame.Angles(0, 0, -phi) * CFrame.new(0, 1.2 + (R - 1.2) / 2, WheelGeometry.FACE_Z - 0.03)
			d.Parent = folder
		end
		local a = 0
		local seen = {}
		for _, row in ipairs(live) do
			local width = if row.p * TAU < SLIVER_MIN then SLIVER_MIN else (TAU - thinAngle) * row.p / thickP
			local a0, a1 = a, a + width
			a = a1
			seen[row.rarity] = (seen[row.rarity] or 0) + 1
			local color = swatch[row.sword] or wedgeColor(row.rarity, seen[row.rarity])
			local material = Enum.Material.SmoothPlastic
			local chase = row.tag == "Chase"
			if chase then
				color = (RARITY_TILE[row.rarity] or RARITY_TILE.Legendary).bottom:Lerp(Color3.new(1, 1, 1), 0.15)
				material = Enum.Material.Neon
			end
			local steps = math.max(1, math.ceil((a1 - a0) / math.rad(10)))
			for s = 0, steps - 1 do
				local t0 = a0 + (a1 - a0) * s / steps
				local t1 = a0 + (a1 - a0) * (s + 1) / steps
				local p0 = pivot * WheelGeometry.facePoint(0, 0)
				local p1 = pivot * WheelGeometry.facePoint(t0, R)
				local p2 = pivot * WheelGeometry.facePoint(t1, R)
				for _, w in ipairs({ WheelGeometry.triangle(p0, p1, p2, WheelGeometry.FACE_THICK,
					{ Color = color, Material = material, Name = chase and "ChaseSlice" or "Slice" }) }) do
					w.Parent = folder
				end
			end
			table.insert(faceSlices, { a0 = a0, a1 = a1, row = row })
			divider(a0)
			local mid = (a0 + a1) / 2
			if not chase and row.p >= LABEL_MIN then
				local big = row.p >= 0.2
				faceLabel(folder, pivot, mid, big and R * 0.58 or R * 0.66, pct(row.p), big and 1.6 or 1.05,
					Color3.new(1, 1, 1), BRIGHT.Outline)
			end
			if chase then
				-- the "?" badge: a glowing coin riding the chase wedge near the rim, with a thin ink ring
				local badge = Instance.new("Part")
				badge.Name = "ChaseBadge"
				badge.Shape = Enum.PartType.Cylinder
				badge.Anchored, badge.CanCollide, badge.CanQuery, badge.CanTouch, badge.CastShadow = true, false, false, false, false
				badge.Size = Vector3.new(0.2, 2.3, 2.3)
				badge.Color = BRIGHT.Outline
				badge.CFrame = pivot * CFrame.Angles(0, 0, -mid) * CFrame.new(0, R - 1.35, WheelGeometry.FACE_Z - 0.22)
					* CFrame.Angles(0, math.pi / 2, 0)
				badge.Parent = folder
				local coin = badge:Clone()
				coin.Name = "ChaseCoin"
				coin.Size = Vector3.new(0.24, 1.95, 1.95)
				coin.Color = color
				coin.Material = Enum.Material.Neon
				coin.CFrame = badge.CFrame * CFrame.new(0.08, 0, 0) -- the badge's +X faces the plaza
				coin.Parent = folder
				local q = faceLabel(folder, pivot, mid, R - 1.35, "?", 1.6, Color3.new(1, 1, 1), BRIGHT.Outline,
					WheelGeometry.FACE_Z - 0.22 - 0.3)
				q.Size = Vector3.new(1.6, 1.6, 0.05)
				q:FindFirstChildOfClass("SurfaceGui").CanvasSize = Vector2.new(100, 100)
				local light = Instance.new("PointLight")
				light.Color = color
				light.Range = 7
				light.Brightness = 2
				light.Parent = coin
			end
		end
		-- rim pegs (the pointer clicks over these), evenly spaced
		for i = 0, PEG_COUNT - 1 do
			local phi = i / PEG_COUNT * TAU
			local peg = Instance.new("Part")
			peg.Name = "Peg"
			peg.Shape = Enum.PartType.Ball
			peg.Anchored, peg.CanCollide, peg.CanQuery, peg.CanTouch = true, false, false, false
			peg.Size = Vector3.one * 0.42
			peg.Color = Color3.fromRGB(255, 214, 52)
			peg.Material = Enum.Material.SmoothPlastic
			peg.CFrame = pivot * CFrame.Angles(0, 0, -phi) * CFrame.new(0, R - 0.3, WheelGeometry.FACE_Z - 0.22)
			peg.Parent = folder
			table.insert(faceBoundaries, phi)
		end
		folder.Parent = rotor
		local upright = {}
		for _, entry in ipairs(faceLabels) do upright[entry.part] = true end
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("BasePart") and not upright[d] then trackRotorPart(d) end
		end
		faceFolder = folder
	end

	-- ---------------------------------------------------------------- 2. the board
	local BOARD_W, BOARD_H = 600, 400 -- the bubble's design size in pixels (the last 40 are the prefix strip)
	local BOARD_STUDS = 24            -- how wide the board stands in the world (it scales with distance,
	                                  -- like a sign: it never covers the wheel it sits beside)
	local SHOW_WITHIN, HIDE_BEYOND = 15, 21 -- studs from the wheel's plinth (hysteresis)

	local board = Instance.new("BillboardGui")
	board.Name = "SpinBoard"
	board.Adornee = boardAnchor
	board.Size = UDim2.fromScale(BOARD_STUDS, BOARD_STUDS * (BOARD_H + 40) / (BOARD_W + 40))
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.MaxDistance = 400
	board.ResetOnSpawn = false
	board.ClipsDescendants = false
	board.Enabled = false
	board.Parent = playerGui

	local root = Instance.new("CanvasGroup")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(BOARD_W + 40, BOARD_H + 40) -- room for the pop's overshoot
	root.Parent = board
	local fitScale = Instance.new("UIScale") -- design pixels -> the board's size on screen this frame
	fitScale.Parent = root
	local function fitBoard()
		fitScale.Scale = math.clamp(board.AbsoluteSize.X / (BOARD_W + 40), 0.2, 1.4)
	end
	board:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBoard)

	local bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.AnchorPoint = Vector2.new(0.5, 0.5)
	bubble.Position = UDim2.fromScale(0.5, 0.5)
	bubble.Size = UDim2.fromOffset(BOARD_W - 24, BOARD_H - 24)
	bubble.BackgroundColor3 = Color3.new(1, 1, 1)
	bubble.Parent = root
	local rootScale = Instance.new("UIScale") -- the pop in / out
	rootScale.Parent = bubble
	PanelChrome.corner(bubble, 26)
	PanelChrome.gradient(bubble, BRIGHT.Panel, BRIGHT.PanelBottom)
	PanelChrome.stroke(bubble, BRIGHT.Outline, 4.5)
	-- the tail pointing left, at the wheel
	local tail = Instance.new("Frame")
	tail.Name = "Tail"
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.new(0, 2, 0.5, 0)
	tail.Size = UDim2.fromOffset(30, 30)
	tail.Rotation = 45
	tail.BackgroundColor3 = Color3.fromRGB(232, 238, 250)
	tail.ZIndex = 0
	tail.Parent = bubble
	PanelChrome.stroke(tail, BRIGHT.Outline, 4.5)

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(20, 10)
	header.Size = UDim2.new(1, -40, 0, 42)
	header.ZIndex = 2
	header.Parent = bubble
	local areaLabel = PanelChrome.display(header, { text = "", size = 30, stroke = 3, xAlign = Enum.TextXAlignment.Left,
		zIndex = 3 })
	areaLabel.Size = UDim2.new(0.62, 0, 1, 0)
	local stepLabel = PanelChrome.display(header, { text = "", size = 20, stroke = 2.5,
		xAlign = Enum.TextXAlignment.Right, zIndex = 3, color = Color3.fromRGB(255, 236, 110) })
	stepLabel.AnchorPoint = Vector2.new(1, 0)
	stepLabel.Position = UDim2.new(1, -96, 0, 0)
	stepLabel.Size = UDim2.new(0.38, -96, 1, 0)
	local pips = {}
	for i = 1, SpinPools.STEPS do
		local pip = Instance.new("Frame")
		pip.AnchorPoint = Vector2.new(1, 0.5)
		pip.Position = UDim2.new(1, -(SpinPools.STEPS - i) * 23, 0.5, 0)
		pip.Size = UDim2.fromOffset(18, 18)
		pip.BackgroundColor3 = BRIGHT.Grey
		pip.ZIndex = 3
		pip.Parent = header
		PanelChrome.corner(pip, 9)
		PanelChrome.stroke(pip, BRIGHT.Outline, 2.5)
		pips[i] = pip
	end

	local tileRow = Instance.new("Frame")
	tileRow.Name = "Tiles"
	tileRow.BackgroundTransparency = 1
	tileRow.Position = UDim2.fromOffset(14, 56)
	tileRow.Size = UDim2.new(1, -28, 0, 170)
	tileRow.ZIndex = 2
	tileRow.Parent = bubble
	local tileLayout = Instance.new("UIListLayout")
	tileLayout.FillDirection = Enum.FillDirection.Horizontal
	tileLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tileLayout.Padding = UDim.new(0, 8)
	tileLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tileLayout.Parent = tileRow

	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.Position = UDim2.fromOffset(16, 232)
	footer.Size = UDim2.new(1, -32, 0, 70)
	footer.BackgroundColor3 = BRIGHT.Row
	footer.ZIndex = 2
	footer.Parent = bubble
	PanelChrome.corner(footer, 18)
	PanelChrome.stroke(footer, BRIGHT.RowStroke, 2.5)

	local costIcon = TokenDrops.icon and TokenDrops.icon(footer, 50, 4)
	if costIcon then
		costIcon.AnchorPoint = Vector2.new(0, 0.5)
		costIcon.Position = UDim2.new(0, 10, 0.5, 0)
	end
	local costLabel = PanelChrome.display(footer, { text = "", size = 36, stroke = 3, xAlign = Enum.TextXAlignment.Left,
		zIndex = 4 })
	costLabel.Position = UDim2.fromOffset(68, 4)
	costLabel.Size = UDim2.fromOffset(80, 40)
	local perLabel = Instance.new("TextLabel")
	perLabel.BackgroundTransparency = 1
	perLabel.Font = Enum.Font.GothamBold
	perLabel.TextSize = 15
	perLabel.TextColor3 = BRIGHT.Ink
	perLabel.TextXAlignment = Enum.TextXAlignment.Left
	perLabel.Text = "per spin"
	perLabel.Position = UDim2.fromOffset(68, 42)
	perLabel.Size = UDim2.fromOffset(90, 20)
	perLabel.ZIndex = 4
	perLabel.Parent = footer
	local haveLabel = Instance.new("TextLabel")
	haveLabel.BackgroundTransparency = 1
	haveLabel.Font = Enum.Font.GothamBold
	haveLabel.TextSize = 17
	haveLabel.TextColor3 = BRIGHT.Ink
	haveLabel.TextXAlignment = Enum.TextXAlignment.Left
	haveLabel.RichText = true
	haveLabel.Position = UDim2.fromOffset(160, 8)
	haveLabel.Size = UDim2.fromOffset(140, 54)
	haveLabel.TextWrapped = true
	haveLabel.ZIndex = 4
	haveLabel.Parent = footer

	-- A key chip: key cap + label. Returns frame, set(state, text).
	local function keyChip(x, key)
		local chip = Instance.new("Frame")
		chip.AnchorPoint = Vector2.new(1, 0.5)
		chip.Position = UDim2.new(1, x, 0.5, 0)
		chip.Size = UDim2.fromOffset(128, 54)
		chip.BackgroundColor3 = Color3.new(1, 1, 1)
		chip.ZIndex = 4
		chip.Parent = footer
		PanelChrome.corner(chip, 14)
		PanelChrome.stroke(chip, BRIGHT.Outline, 3)
		local grad = PanelChrome.gradient(chip, BRIGHT.Green, BRIGHT.GreenDark)
		local cap = Instance.new("Frame")
		cap.AnchorPoint = Vector2.new(0, 0.5)
		cap.Position = UDim2.new(0, 6, 0.5, 0)
		cap.Size = UDim2.fromOffset(40, 40)
		cap.BackgroundColor3 = Color3.new(1, 1, 1)
		cap.ZIndex = 5
		cap.Parent = chip
		PanelChrome.corner(cap, 10)
		PanelChrome.stroke(cap, BRIGHT.Outline, 2.5)
		local capText = PanelChrome.display(cap, { text = key, size = 26, stroke = 0, color = BRIGHT.Outline, zIndex = 6 })
		capText:FindFirstChildOfClass("UIStroke"):Destroy()
		local label = PanelChrome.display(chip, { text = "", size = 22, stroke = 2.5, zIndex = 6, scaled = true, minSize = 12 })
		label.Position = UDim2.fromOffset(50, 4)
		label.Size = UDim2.new(1, -56, 1, -8)
		local lock = Instance.new("TextLabel")
		lock.BackgroundTransparency = 1
		lock.Text = "🔒"
		lock.TextSize = 22
		lock.AnchorPoint = Vector2.new(0.5, 0.5)
		lock.Position = UDim2.new(1, -4, 0, 4)
		lock.Size = UDim2.fromOffset(28, 28)
		lock.ZIndex = 7
		lock.Visible = false
		lock.Parent = chip
		local function set(state, text)
			label.Text = text
			lock.Visible = state == "locked"
			if state == "ready" then
				grad.Color = ColorSequence.new(BRIGHT.Green, BRIGHT.GreenDark)
			elseif state == "short" then
				grad.Color = ColorSequence.new(Color3.fromRGB(255, 196, 90), BRIGHT.GoldDark)
			else
				grad.Color = ColorSequence.new(BRIGHT.Grey, BRIGHT.GreyDark)
			end
		end
		local button = Instance.new("TextButton")
		button.BackgroundTransparency = 1
		button.Text = ""
		button.Size = UDim2.fromScale(1, 1)
		button.ZIndex = 8
		button.Parent = chip
		return chip, set, button
	end
	local oneChip, setOne, oneButton = keyChip(-146, "E")
	local multiChip, setMulti, multiButton = keyChip(-8, "F")

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "Info"
	infoLabel.BackgroundTransparency = 1
	infoLabel.Font = Enum.Font.GothamBold
	infoLabel.TextSize = 16
	infoLabel.TextColor3 = BRIGHT.InkMuted
	infoLabel.RichText = true
	infoLabel.Position = UDim2.fromOffset(20, 306)
	infoLabel.Size = UDim2.new(1, -40, 0, 24)
	infoLabel.ZIndex = 2
	infoLabel.Parent = bubble

	-- The prefix strip: the rung this player's level bracket just opened with its real odds from a
	-- Common to a Legendary sword (WeaponModifiers.TierOdds at their own luck, the server's numbers),
	-- the bracket's own named chase ("??" until they have rolled it) at its real 1-in-N, and what
	-- opens at the next bracket.
	local prefixStrip = Instance.new("Frame")
	prefixStrip.Name = "PrefixStrip"
	prefixStrip.Position = UDim2.fromOffset(16, 334)
	prefixStrip.Size = UDim2.new(1, -32, 0, 30)
	prefixStrip.BackgroundColor3 = BRIGHT.Row
	prefixStrip.ZIndex = 2
	prefixStrip.Parent = bubble
	PanelChrome.corner(prefixStrip, 12)
	PanelChrome.stroke(prefixStrip, BRIGHT.RowStroke, 2)
	local prefixLabel = Instance.new("TextLabel")
	prefixLabel.Name = "PrefixOdds"
	prefixLabel.BackgroundTransparency = 1
	prefixLabel.Font = Enum.Font.GothamBold
	prefixLabel.TextSize = 15
	prefixLabel.TextColor3 = BRIGHT.Ink
	prefixLabel.RichText = true
	prefixLabel.TextScaled = true
	prefixLabel.Position = UDim2.fromOffset(10, 3)
	prefixLabel.Size = UDim2.new(1, -20, 1, -6)
	prefixLabel.ZIndex = 3
	prefixLabel.Parent = prefixStrip
	local prefixCap = Instance.new("UITextSizeConstraint")
	prefixCap.MaxTextSize = 15
	prefixCap.MinTextSize = 9
	prefixCap.Parent = prefixLabel
	local function refreshPrefixStrip()
		local level = levelOf()
		local b = WeaponModifiers.BracketFor(level)
		local luck = WeaponModifiers.LuckFrom(0, tonumber(player:GetAttribute("Rebirths")) or 0,
			tonumber(player:GetAttribute("MilestoneLuck")) or 0)
		local lo = WeaponModifiers.TierOdds("Common", level, luck)
		local hi = WeaponModifiers.TierOdds("Legendary", level, luck)
		local function rungText(tier, label)
			local rung = WeaponModifiers.Rungs[tier]
			return string.format("<font color=\"#%s\">%s</font>", rung.color:Lerp(Color3.new(0, 0, 0), 0.25):ToHex(), label or rung.name)
		end
		local parts = { "<b>PREFIX</b>" }
		-- the bracket's top ordinary rung: "new" when this bracket opened it, "top" at Lv 80 (which
		-- opens only the Lemonade)
		local prevB = b.level > 1 and WeaponModifiers.BracketFor(b.level - 1) or nil
		local isNew = not prevB or prevB.top < b.top
		table.insert(parts, string.format("%s %s %s\u{2013}%s", isNew and "new" or "top",
			rungText(b.top), pct(lo[b.top]), pct(hi[b.top])))
		-- the bracket's own named chase, "??" until this player has rolled it
		local chase = b.chase
		local chaseName = WeaponModifiers.ChaseLabel(player, chase)
		table.insert(parts, string.format("chase <font color=\"#%s\"><b>%s</b></font> %s\u{2013}%s",
			chase.color:Lerp(Color3.new(0, 0, 0), 0.3):ToHex(), chaseName,
			WeaponModifiers.OneInText(lo[chase.tier]), WeaponModifiers.OneInText(hi[chase.tier])))
		-- the collection: how many of the eight named chases this player has found so far
		local found = 0
		for _, c in ipairs(WeaponModifiers.Chases) do
			if WeaponModifiers.ChaseFound(player, c.name) then found += 1 end
		end
		table.insert(parts, string.format("<b>%d/%d</b> found", found, #WeaponModifiers.Chases))
		local nextB = WeaponModifiers.NextBracket(level)
		if nextB then
			table.insert(parts, string.format("next Lv %d: %s", nextB.level,
				nextB.newRung and (rungText(nextB.tier) .. " + ??") or "??"))
		end
		prefixLabel.Text = table.concat(parts, "  \u{00B7}  ")
	end

	-- The stand-in sword each tile shows (the tile colour is the rarity).
	local function standInSword(rarity)
		local t = RARITY_TILE[rarity] or RARITY_TILE.Common
		local tool = Instance.new("Tool")
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.44, 0.44, 1.0)
		handle.Color = Color3.fromRGB(92, 66, 50)
		handle.Parent = tool
		local function add(name, size, c0, color, material, shape, class)
			local p = Instance.new(class or "Part")
			p.Name = name
			p.Size = size
			p.Color = color
			p.Material = material
			if shape then (p :: any).Shape = shape end
			p.Parent = tool
			local w = Instance.new("Weld")
			w.Part0, w.Part1, w.C0 = handle, p, c0
			w.Parent = handle
		end
		local len, w, th = 2.5, 1.1, 0.26
		local bladeZ = -0.8 - len / 2
		local steel = Color3.fromRGB(226, 232, 244)
		add("Pommel", Vector3.new(0.66, 0.66, 0.66), CFrame.new(0, 0, 0.68), t.rim, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		add("Guard", Vector3.new(1.95, 0.4, 0.44), CFrame.new(0, 0, -0.6), Color3.fromRGB(236, 170, 40), Enum.Material.SmoothPlastic)
		add("Blade", Vector3.new(w, th, len), CFrame.new(0, 0, bladeZ), steel, Enum.Material.SmoothPlastic)
		add("Fuller", Vector3.new(w * 0.3, th + 0.04, len * 0.82), CFrame.new(0, 0, bladeZ + len * 0.06), t.rim, Enum.Material.SmoothPlastic)
		local tipLen = w * 0.75
		for _, side in ipairs({ 1, -1 }) do
			add("Tip", Vector3.new(th, w / 2, tipLen), CFrame.new(side * w / 4, 0, bladeZ - len / 2 - tipLen / 2)
				* CFrame.Angles(0, 0, side == 1 and -math.pi / 2 or math.pi / 2), steel, Enum.Material.SmoothPlastic, nil, "WedgePart")
		end
		return tool
	end
	local SWORD_POSE = { yawDeg = 12, tiltDeg = 42, margin = 1.05 }

	local chaseSpinners = {} -- UIGradients behind chase tiles, turned every frame

	local function buildTile(row, order)
		local t = RARITY_TILE[row.rarity] or RARITY_TILE.Common
		local chase = row.tag == "Chase"
		-- an unpulled chase is a mystery ("??"); once this player has pulled it, it shows its name
		local hidden = chase and not SpinPools.SwordFound(player, row.sword)
		local slot = Instance.new("Frame")
		slot.Name = "Tile" .. order
		slot.LayoutOrder = order
		slot.BackgroundTransparency = 1
		slot.Size = UDim2.fromOffset(104, 170)
		slot.ZIndex = 3
		slot.Parent = tileRow
		-- the odds, big: the number a player reads from across the plaza
		local oddsText = PanelChrome.display(slot, { text = row.locked and ("Lv " .. row.minLevel) or pct(row.p),
			size = row.locked and 28 or 38, stroke = 3.5, zIndex = 6,
			color = row.locked and BRIGHT.Grey or (chase and Color3.fromRGB(255, 236, 110) or Color3.new(1, 1, 1)) })
		oddsText.Position = UDim2.fromOffset(-6, -6)
		oddsText.Size = UDim2.new(1, 12, 0, 40)
		-- a thick rarity-coloured frame round the tile
		local frame = Instance.new("Frame")
		frame.Name = "RarityFrame"
		frame.Position = UDim2.fromOffset(2, 32)
		frame.Size = UDim2.fromOffset(100, 100)
		frame.BackgroundColor3 = t.bottom
		frame.ZIndex = 3
		frame.Parent = slot
		PanelChrome.corner(frame, 22)
		PanelChrome.stroke(frame, BRIGHT.Outline, 3)
		local tile = Instance.new("Frame")
		tile.Position = UDim2.fromOffset(6, 36)
		tile.Size = UDim2.fromOffset(92, 92)
		tile.ZIndex = 4
		tile.ClipsDescendants = false
		tile.Parent = slot
		PanelChrome.corner(tile, 18)
		PanelChrome.lootTile(tile, row.locked and "Common" or row.rarity, { zIndex = 4 })
		if chase then
			-- a turning light burst behind the chase: a rarity-coloured sunburst gradient on the frame
			local burst = Instance.new("UIGradient")
			burst.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(0.25, t.bottom),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 236, 110)),
				ColorSequenceKeypoint.new(0.75, t.bottom),
				ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
			})
			burst.Parent = frame
			frame.BackgroundColor3 = Color3.new(1, 1, 1)
			table.insert(chaseSpinners, burst)
		end
		if swatch[row.sword] and not chase then -- the colour of this sword's wedge on the wheel
			local dot = Instance.new("Frame")
			dot.Name = "Swatch"
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.new(1, -6, 1, -6)
			dot.Size = UDim2.fromOffset(26, 26)
			dot.BackgroundColor3 = swatch[row.sword]
			dot.ZIndex = 9
			dot.Parent = tile
			PanelChrome.corner(dot, 13)
			PanelChrome.stroke(dot, BRIGHT.Outline, 3)
		end
		local vp = Instance.new("ViewportFrame")
		vp.BackgroundTransparency = 1
		vp.Size = UDim2.fromScale(1, 1)
		vp.ZIndex = 6
		vp.Parent = tile
		local sword = standInSword(row.rarity)
		PanelChrome.renderTool(vp, sword, SWORD_POSE)
		sword:Destroy()
		if hidden then
			-- the chase is a mystery: an ink silhouette with a big "?", the way an egg hides its best pet
			vp.ImageColor3 = Color3.fromRGB(24, 22, 40)
			local q = PanelChrome.display(tile, { text = "?", size = 58, stroke = 4, zIndex = 8,
				color = Color3.fromRGB(255, 236, 110) })
			q.Size = UDim2.fromScale(1, 1)
		elseif row.locked then
			vp.ImageColor3 = Color3.fromRGB(40, 40, 50)
		end
		if row.locked then
			local lock = Instance.new("TextLabel")
			lock.BackgroundTransparency = 1
			lock.Text = "🔒"
			lock.TextSize = 30
			lock.AnchorPoint = Vector2.new(1, 1)
			lock.Position = UDim2.new(1, 0, 1, 0)
			lock.Size = UDim2.fromOffset(34, 34)
			lock.ZIndex = 9
			lock.Parent = tile
		end
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextSize = 14
		name.TextWrapped = true
		name.TextColor3 = BRIGHT.Ink
		name.Text = hidden and "??" or row.sword
		name.Position = UDim2.fromOffset(-2, 134)
		name.Size = UDim2.new(1, 4, 0, 20)
		name.TextScaled = true
		name.TextYAlignment = Enum.TextYAlignment.Top
		name.ZIndex = 5
		name.Parent = slot
		local rarity = PanelChrome.display(slot, { text = row.ultra and "ULTRA" or (row.great and "GREAT" or string.upper(row.rarity)), size = 15, stroke = 2, zIndex = 5,
			color = t.bottom:Lerp(Color3.new(1, 1, 1), row.rarity == "Common" and 0 or 0.1) })
		rarity.Position = UDim2.fromOffset(0, 153)
		rarity.Size = UDim2.new(1, 0, 0, 17)
		return slot
	end

	local notice: string? = nil -- a refusal shown in the info line for a moment
	local noticeUntil = 0
	local spinning = false
	local tilesKey = ""

	local function refreshBoard()
		local zone, step, rows = currentPool()
		assignColors(rows)
		local pool = SpinPools.Get(zone)
		areaLabel.Text = pool and pool.name or zone
		stepLabel.Text = SpinPools.STEP_NAMES[step] or ""
		for i, pip in ipairs(pips) do
			pip.BackgroundColor3 = i <= step and BRIGHT.Gold or BRIGHT.Grey
		end
		-- tiles (rebuilt only when the pool changes)
		local key = zone .. ":" .. tostring(step) .. ":"
		for _, row in ipairs(rows or {}) do
			key ..= row.sword .. (row.locked and "L" or "") .. (row.tag == "Chase" and SpinPools.SwordFound(player, row.sword) and "F" or "") .. ","
		end
		if key ~= tilesKey then
			tilesKey = key
			for _, child in ipairs(tileRow:GetChildren()) do
				if child:IsA("Frame") then child:Destroy() end
			end
			table.clear(chaseSpinners)
			for i, row in ipairs(rows or {}) do
				if i > 5 then break end
				buildTile(row, i)
			end
		end
		local have = tokens()
		local cost = SpinPools.CostFor(zone, step)
		costLabel.Text = tostring(cost)
		haveLabel.Text = string.format("You have\n<font size=\"24\" color=\"#%s\">%d</font> tokens",
			(have >= cost and TEAL or BRIGHT.Red):ToHex(), have)
		local lock = combatLeft()
		if spinning then
			setOne("off", "Spinning")
		elseif lock > 0 then
			setOne("off", "Wait " .. math.ceil(lock) .. "s")
		elseif have < cost then
			setOne("short", "Spin")
		else
			setOne("ready", "Spin")
		end
		local n = multiCount()
		if n < 2 then
			setMulti("locked", "Spin x" .. SpinPools.MULTI_DEFAULT)
		elseif have < cost * n then
			setMulti("short", "Spin x" .. n)
		else
			setMulti(spinning and "off" or "ready", "Spin x" .. n)
		end
		-- info line: a refusal, the combat lock, or what rotates the pool next
		if notice and os.clock() < noticeUntil then
			infoLabel.Text = string.format("<font color=\"#%s\">%s</font>", BRIGHT.RedDark:ToHex(), notice)
		elseif lock > 0 then
			infoLabel.Text = string.format("<font color=\"#%s\">Just fought: the wheel turns in %d s</font>",
				BRIGHT.RedDark:ToHex(), math.ceil(lock))
		elseif step < SpinPools.STEPS then
			infoLabel.Text = string.format("Next pool: %s  ·  spins in town only", SpinPools.STEP_HOW[step + 1])
		else
			infoLabel.Text = "Deepest pool for this area  ·  spins in town only"
		end
		refreshPrefixStrip()
		-- the face follows the pool (never mid-spin)
		if not spinning and key ~= faceKey then
			faceKey = key
			paintFace(rows)
		end
	end

	oneButton.Activated:Connect(function() SPIN_ACTION:FireServer("Spin", "one") end)
	multiButton.Activated:Connect(function() SPIN_ACTION:FireServer("Spin", "multi") end)

	-- board pop in / out with distance
	local boardShown = false
	local boardTween: Tween? = nil
	local function showBoard(on: boolean)
		if on == boardShown then return end
		boardShown = on
		-- The board stands on the customer's right, which on screen is where the quest tracker
		-- sits (2026-09-24 recording, 4:12). The other side of the wheel is the upgrade stall, so
		-- the board stays put and QuestGui steps the tracker aside while this is set.
		player:SetAttribute("SpinBoardOpen", on)
		if boardTween then boardTween:Cancel() end
		if on then
			refreshBoard()
			board.Enabled = true
			fitBoard()
			rootScale.Scale = 0.55
			root.GroupTransparency = 1
			boardTween = TweenService:Create(rootScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 })
			boardTween:Play()
			TweenService:Create(root, TweenInfo.new(0.16), { GroupTransparency = 0 }):Play()
		else
			boardTween = TweenService:Create(rootScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Scale = 0.6 })
			boardTween:Play()
			TweenService:Create(root, TweenInfo.new(0.18), { GroupTransparency = 1 }):Play()
			task.delay(0.2, function()
				if not boardShown then board.Enabled = false end
			end)
		end
	end

	for _, attr in ipairs({ "SpinZone", "SpinStep", "Tokens", "MultiSpin", "CombatAt", "LemonadeFound", "ChasesFound", "SwordsFound", "Rebirths",
		"MilestoneLuck" }) do
		player:GetAttributeChangedSignal(attr):Connect(refreshBoard)
	end
	task.spawn(function()
		local stats = player:WaitForChild("leaderstats", 30)
		local lv = stats and stats:WaitForChild("Level", 30)
		if lv then lv.Changed:Connect(refreshBoard) end
	end)

	-- ---------------------------------------------------------------- 3. the key caps (custom prompt look)
	local caps = {} -- [prompt] = BillboardGui
	local function keyCap(prompt: ProximityPrompt)
		local isMulti = prompt.Name == "SpinMulti"
		local gui = Instance.new("BillboardGui")
		gui.Name = "SpinKey"
		gui.Adornee = prompt.Parent
		gui.AlwaysOnTop = true
		gui.Size = UDim2.fromOffset(300, 110)
		gui.SizeOffset = Vector2.new(-0.3, isMulti and -1.05 or 0) -- the pill runs toward the wheel's centre
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1)
		holder.Parent = gui
		local scale = Instance.new("UIScale")
		scale.Scale = 0.3
		scale.Parent = holder
		local cap = Instance.new("TextButton")
		cap.Name = "Cap"
		cap.AutoButtonColor = false
		cap.Text = ""
		cap.AnchorPoint = Vector2.new(0, 0.5)
		cap.Position = UDim2.new(0, 6, 0.5, 0)
		cap.Size = UDim2.fromOffset(96, 96)
		cap.BackgroundColor3 = Color3.new(1, 1, 1)
		cap.Parent = holder
		PanelChrome.corner(cap, 20)
		PanelChrome.stroke(cap, BRIGHT.Outline, 5)
		local capGrad = PanelChrome.gradient(cap, Color3.new(1, 1, 1), Color3.fromRGB(214, 222, 238))
		local letter = PanelChrome.display(cap, { text = (prompt.KeyboardKeyCode.Name), size = 64, stroke = 0,
			color = BRIGHT.Outline })
		letter:FindFirstChildOfClass("UIStroke"):Destroy()
		local capScale = Instance.new("UIScale")
		capScale.Parent = cap
		local pill = Instance.new("Frame")
		pill.AnchorPoint = Vector2.new(0, 0.5)
		pill.Position = UDim2.new(0, 94, 0.5, 0)
		pill.Size = UDim2.fromOffset(190, 58)
		pill.BackgroundColor3 = Color3.new(1, 1, 1)
		pill.ZIndex = 0
		pill.Parent = holder
		PanelChrome.corner(pill, 29)
		PanelChrome.stroke(pill, BRIGHT.Outline, 4)
		PanelChrome.gradient(pill, Color3.fromRGB(40, 206, 190), TEAL_DARK)
		local count = isMulti and multiCount() or 1
		local text = PanelChrome.display(pill, { text = (isMulti and ("Spin x" .. count) or "Spin") .. "  ", size = 28,
			stroke = 3, xAlign = Enum.TextXAlignment.Left })
		text.Position = UDim2.fromOffset(18, 0)
		text.Size = UDim2.new(1, -18, 1, 0)
		local costText = PanelChrome.display(pill, { text = tostring(spinCost() * count), size = 26, stroke = 3,
			xAlign = Enum.TextXAlignment.Right, color = Color3.fromRGB(255, 240, 70) })
		costText.Position = UDim2.fromOffset(0, 0)
		costText.Size = UDim2.new(1, -52, 1, 0)
		local icon = TokenDrops.icon and TokenDrops.icon(pill, 38, 3)
		if icon then
			icon.AnchorPoint = Vector2.new(1, 0.5)
			icon.Position = UDim2.new(1, -8, 0.5, 0)
		end
		cap.Activated:Connect(function()
			prompt:InputHoldBegin()
			task.defer(function() prompt:InputHoldEnd() end)
		end)
		gui.Parent = playerGui
		TweenService:Create(scale, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		return { gui = gui, scale = scale, cap = cap, capScale = capScale, capGrad = capGrad }
	end

	ProximityPromptService.PromptShown:Connect(function(prompt)
		if not prompt:GetAttribute("SpinPrompt") or caps[prompt] then return end
		caps[prompt] = keyCap(prompt)
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		local c = caps[prompt]
		if not c then return end
		caps[prompt] = nil
		TweenService:Create(c.scale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.2 }):Play()
		task.delay(0.15, function() c.gui:Destroy() end)
	end)
	local function pressed(prompt)
		local c = caps[prompt]
		if not c then return end
		-- a real key press: the cap sinks and greys, then springs back
		c.capGrad.Color = ColorSequence.new(Color3.fromRGB(200, 206, 220), Color3.fromRGB(150, 158, 174))
		TweenService:Create(c.capScale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.84 }):Play()
		task.delay(0.12, function()
			TweenService:Create(c.capScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			task.delay(0.12, function()
				if c.capGrad.Parent then
					c.capGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(214, 222, 238))
				end
			end)
		end)
		AudioManager.PlaySFX("ui_click", promptPart)
	end
	singlePrompt.Triggered:Connect(function() pressed(singlePrompt) end)
	multiPrompt.Triggered:Connect(function() pressed(multiPrompt) end)

	-- The multi prompt stays hidden for this player until multi-spin is bought (the board shows it
	-- greyed with a lock meanwhile); both hide while the wheel turns.
	local function syncPrompts()
		singlePrompt.Enabled = not spinning
		multiPrompt.Enabled = (not spinning) and multiCount() >= 2
	end
	player:GetAttributeChangedSignal("MultiSpin"):Connect(syncPrompts)
	syncPrompts()

	-- ---------------------------------------------------------------- 4. the spin
	local spinFrom, spinTo, spinStart, spinDur = 0, 0, 0, 0
	local lastTickEdge = 0
	local bulbs = {}
	for _, b in ipairs(bulbsFolder:GetChildren()) do
		if b:IsA("BasePart") then table.insert(bulbs, b) end
	end
	table.sort(bulbs, function(a, b) return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0) end)
	local BULB_ON = Color3.fromRGB(255, 244, 196)
	local BULB_OFF = Color3.fromRGB(196, 150, 70)
	local flashColor: Color3? = nil
	local flashUntil = 0

	local function easeOut(t: number): number
		return 1 - (1 - t) ^ 4
	end
	local function easeBack(t: number): number
		t = math.clamp(t, 0, 1)
		local c = 1.9
		return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
	end

	-- Which slice edge sits under the pointer right now (for the ticker's click).
	local function edgeIndex(a: number): number
		local phi = a % TAU
		local idx = 0
		for i, edge in ipairs(faceBoundaries) do
			if edge <= phi then idx = i end
		end
		return idx + math.floor(a / TAU) * (#faceBoundaries + 1)
	end

	-- The result itself (name, rarity, prefix, odds) is told by the top-right spin popup
	-- (ReplicatedStorage.SpinPopup), which runs its reveal in step with this wheel; the station's
	-- own answer is the landed slice, the bulb flash and the sword popping out of the hub.

	-- The pointer: the station's Ticker wedges and pin, flicked (on this client only) as each rim
	-- peg passes under it, then sprung back.
	local tickerParts, tickerBase = {}, {}
	for _, child in ipairs(station:GetChildren()) do
		if child:IsA("BasePart") and (child.Name == "Ticker" or child.Name == "TickerPin") then
			table.insert(tickerParts, child)
			table.insert(tickerBase, child.CFrame)
		end
	end
	local tickerPivot = stationCFrame * CFrame.new(0, WheelGeometry.CENTER.Y + R + 1.35, -1.2)
	local tickerKick, tickerAngle = 0, 0
	local function setTicker(rot: number)
		if #tickerParts == 0 or math.abs(rot - tickerAngle) < 1e-4 then return end
		tickerAngle = rot
		local turn = tickerPivot * CFrame.Angles(0, 0, rot) * tickerPivot:Inverse()
		local cfs = table.create(#tickerParts)
		for i, base in ipairs(tickerBase) do cfs[i] = turn * base end
		Workspace:BulkMoveTo(tickerParts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end

	-- THE PAYOFF: the sword the server built pops out of the wheel's hub towards the player, big,
	-- turning in a rarity-coloured light with a burst of sparkles, hangs there a beat, then shrinks
	-- and flies into the player's backpack. It is a copy of the real Tool the server just put in the
	-- backpack (the stand-in blade only if that has not replicated yet).
	local pop = nil
	local function clearPop()
		if pop then pop.model:Destroy(); pop = nil end
	end
	local function popSword(result)
		clearPop()
		local backpack = player:FindFirstChildOfClass("Backpack")
		local source = backpack and backpack:FindFirstChild(result.fullName or "")
		if not (source and source:IsA("Tool")) then
			source = standInSword(result.rarity)
		end
		local copy = source:Clone()
		if source.Parent == nil then source:Destroy() end
		local model = Instance.new("Model")
		model.Name = "SpinPop"
		local handle
		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("TouchTransmitter") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
				d.Massless = true
				if d.Name == "Handle" then handle = d end
			end
		end
		for _, child in ipairs(copy:GetChildren()) do child.Parent = model end
		copy:Destroy()
		model.WorldPivot = handle and handle.CFrame or model:GetBoundingBox()
		model:PivotTo(CFrame.Angles(math.pi / 2, 0, 0)) -- blade up
		local _, size = model:GetBoundingBox()
		local height = math.max(size.X, size.Y, size.Z)
		pcall(function() model:ScaleTo(model:GetScale() * (8.5 / math.max(0.5, height))) end)
		model:PivotTo(CFrame.Angles(math.pi / 2, 0, 0))
		local center, box = model:GetBoundingBox()
		local offset = center.Position
		-- which way the blade's flat side faces: the box's thinner cross axis (in the pivot's frame the
		-- handle's Y points world +Z, its X stays X) is turned towards the plaza
		local _, stationYaw = stationCFrame:ToOrientation()
		local faceYaw = stationYaw + (box.X < box.Y and math.pi / 2 or 0)
		local t = RARITY_TILE[result.rarity] or RARITY_TILE.Common
		local glowColor = result.rarity == "Common" and Color3.fromRGB(255, 214, 52) or t.bottom
		-- light: a soft rarity beam behind the blade and a sparkle burst
		local beam = Instance.new("Part")
		beam.Name = "Beam"
		beam.Shape = Enum.PartType.Cylinder
		beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch, beam.CastShadow = true, false, false, false, false
		beam.Material = Enum.Material.SmoothPlastic
		beam.Color = glowColor:Lerp(Color3.new(1, 1, 1), 0.25)
		beam.Transparency = 0.1
		beam.Size = Vector3.new(0.2, 5, 5)
		beam.Parent = model
		local rim = beam:Clone() -- an ink rim round the medallion
		rim.Name = "BeamRim"
		rim.Color = BRIGHT.Outline
		rim.Transparency = 0
		rim.Size = Vector3.new(0.16, 5.5, 5.5)
		rim.Parent = model
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(Color3.new(1, 1, 1), glowColor)
		sparkles.LightEmission = 1
		sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
		sparkles.Speed = NumberRange.new(10, 18)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Lifetime = NumberRange.new(0.5, 0.9)
		sparkles.Drag = 3
		sparkles.Rate = 0
		sparkles.Parent = beam
		-- a thick ink outline so the blade reads against the wheel's colours, like the board's art
		local outline = Instance.new("Highlight")
		outline.FillTransparency = 1
		outline.OutlineColor = BRIGHT.Outline
		outline.OutlineTransparency = 0
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Adornee = model
		outline.Parent = model
		model.Parent = Workspace
		sparkles:Emit(result.rarity == "Common" and 30 or 60)
		pop = { model = model, beam = beam, rim = rim, offset = offset, start = os.clock(),
			from = basePivot.Position + stationCFrame.LookVector * 1.5,
			to = (basePivot * CFrame.new(-1.5, -0.4, -5)).Position, yaw = faceYaw }
	end
	local POP_OUT, POP_HOLD, POP_HOME = 0.35, 1.7, 0.4
	local function stepPop(now)
		if not pop then return end
		local e = now - pop.start
		local pos, scale
		if e < POP_OUT then
			local k = easeBack(e / POP_OUT)
			pos = pop.from:Lerp(pop.to, math.clamp(k, 0, 1.2))
			scale = 0.2 + 0.8 * k
		elseif e < POP_OUT + POP_HOLD then
			pos = pop.to + Vector3.new(0, math.sin((e - POP_OUT) * 3) * 0.25, 0)
			scale = 1
		elseif e < POP_OUT + POP_HOLD + POP_HOME then
			local k = (e - POP_OUT - POP_HOLD) / POP_HOME
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local home = hrp and hrp.Position or pop.to
			pos = pop.to:Lerp(home, k * k)
			scale = 1 - 0.9 * k
		else
			clearPop()
			return
		end
		-- flat side to the plaza, swaying (a full turn would show the blade edge-on half the time)
		local sway = math.sin(e * 3.2) * math.rad(28) * (e < POP_OUT and 3 * (1 - e / POP_OUT) + 1 or 1)
		local cf = CFrame.new(pos) * CFrame.Angles(0, pop.yaw + sway, 0)
		pop.model:PivotTo(cf * CFrame.new(-pop.offset * scale) * CFrame.Angles(math.pi / 2, 0, 0))
		-- shrink by moving parts toward the centre is costly; scale the whole model instead
		local want = scale
		if math.abs((pop.lastScale or 1) - want) > 0.02 then
			pcall(function() pop.model:ScaleTo(pop.model:GetScale() * (want / (pop.lastScale or 1))) end)
			pop.lastScale = want
			pop.model:PivotTo(cf * CFrame.new(-pop.offset * scale) * CFrame.Angles(math.pi / 2, 0, 0))
		end
		pop.beam.CFrame = CFrame.lookAt(pos - stationCFrame.LookVector * 0.9, pos + stationCFrame.LookVector * 2)
			* CFrame.Angles(0, math.pi / 2, 0)
		pop.rim.CFrame = pop.beam.CFrame * CFrame.new(-0.1, 0, 0)
	end

	local pendingResult = nil
	local function startSpin(payload)
		local result = payload.results and payload.results[1]
		if not result then return end
		-- A multi-spin lands the wheel on the batch's best pull (the one the top-right card celebrates).
		for _, r in ipairs(payload.results) do
			local ra, rb = SpinPools.RARITY_ORDER[r.rarity] or 0, SpinPools.RARITY_ORDER[result.rarity] or 0
			if ra > rb or (ra == rb and (r.p or 1) < (result.p or 1)) then result = r end
		end
		-- The face shows the pool the server rolled (repaint first if it moved since the last paint).
		refreshBoard()
		-- Land inside a random slice of the rolled sword, never on its edge.
		local candidates = {}
		for _, s in ipairs(faceSlices) do
			if s.row.sword == result.sword and s.row.rarity == result.rarity then table.insert(candidates, s) end
		end
		local target
		if #candidates > 0 then
			local s = candidates[math.random(1, #candidates)]
			local margin = math.min((s.a1 - s.a0) * 0.2, math.rad(3))
			target = s.a0 + margin + math.random() * math.max(0, (s.a1 - s.a0) - 2 * margin)
		else
			target = math.random() * TAU -- a pool the face does not show (should not happen)
		end
		local turns = 4
		local current = angle
		local delta = (target - current) % TAU
		spinFrom = current
		spinTo = current + turns * TAU + delta
		spinStart = os.clock()
		spinDur = math.max(1.2, (tonumber(payload.seconds) or SpinPools.SPIN_SECONDS) - 0.2)
		lastTickEdge = edgeIndex(current)
		spinning = true
		pendingResult = result
		syncPrompts()
		refreshBoard()
	end

	local function finishSpin()
		spinning = false
		local result = pendingResult
		pendingResult = nil
		syncPrompts()
		if result then
			local t = RARITY_TILE[result.rarity] or RARITY_TILE.Common
			flashColor = result.rarity == "Common" and Color3.fromRGB(255, 255, 255) or t.bottom
			flashUntil = os.clock() + 1.6
			popSword(result)
			AudioManager.PlaySFX("reveal_land", hubPart)
		end
		refreshBoard()
	end

	SPIN_ACTION.OnClientEvent:Connect(function(kind, payload)
		if kind == "Result" and typeof(payload) == "table" then
			startSpin(payload)
		elseif kind == "Refused" and typeof(payload) == "table" then
			notice = tostring(payload.message or "")
			noticeUntil = os.clock() + 3.5
			refreshBoard()
			-- the board shakes its head
			local base = bubble.Position
			task.spawn(function()
				for i = 1, 6 do
					bubble.Position = base + UDim2.fromOffset((i % 2 == 0 and 1 or -1) * (10 - i), 0)
					task.wait(0.035)
				end
				bubble.Position = base
			end)
			task.delay(3.6, refreshBoard)
		end
	end)

	-- Every frame: turn the rotor, chase the bulbs, show/hide the board, tick the combat countdown.
	local IDLE_SPEED = math.rad(7)
	local lastRefresh = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		if spinning then
			local t = math.clamp((now - spinStart) / spinDur, 0, 1)
			angle = spinFrom + (spinTo - spinFrom) * easeOut(t)
			local edge = edgeIndex(angle)
			if edge ~= lastTickEdge then
				lastTickEdge = edge
				tickerKick = 1
				AudioManager.PlaySFX("reveal_tick", promptPart, { PlaybackSpeed = 1.2 + (1 - t) * 0.8, Volume = 0.25 })
			end
			if t >= 1 then finishSpin() end
		elseif now > flashUntil then
			angle += IDLE_SPEED * dt
		end
		-- the pointer springs back from each peg's flick
		tickerKick = math.max(0, tickerKick - dt * 9)
		setTicker(-math.rad(26) * tickerKick * tickerKick)
		for _, burst in ipairs(chaseSpinners) do burst.Rotation = (now * 120) % 360 end
		stepPop(now)
		local camera = Workspace.CurrentCamera
		if spinning or (camera and (camera.CFrame.Position - hubPart.Position).Magnitude < 300) then
			local frame = basePivot * CFrame.Angles(0, 0, angle)
			local cfs = table.create(#rotorParts)
			for i, off in ipairs(rotorOffsets) do cfs[i] = frame * off end
			local n = #rotorParts
			local parts = table.clone(rotorParts)
			for i, entry in ipairs(faceLabels) do
				parts[n + i] = entry.part
				cfs[n + i] = placeLabel(entry, frame, angle)
			end
			Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
		-- bulbs: a slow chase at rest, a fast one while spinning, a rarity flash on the result
		local n = #bulbs
		if n > 0 then
			if flashColor and now < flashUntil then
				local on = math.floor(now * 8) % 2 == 0
				for _, b in ipairs(bulbs) do b.Color = on and flashColor or BULB_OFF end
			else
				local phase = math.floor(now * (spinning and 18 or 5))
				for i, b in ipairs(bulbs) do
					b.Color = ((i + phase) % 3 == 0) and BULB_ON or BULB_OFF
				end
			end
		end
		-- the board appears as the player comes near the wheel
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local offset = hrp.Position - promptPart.Position
			local d = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if boardShown and d > HIDE_BEYOND then
				showBoard(false)
			elseif not boardShown and d < SHOW_WITHIN then
				showBoard(true)
			end
		end
		if boardShown and now - lastRefresh > 0.5 and (combatLeft() > 0 or (notice and now > noticeUntil)) then
			lastRefresh = now
			if notice and now > noticeUntil then notice = nil end
			refreshBoard()
		end
	end)

	refreshBoard()

	-- ---------------------------------------------------------------- Studio capture ("Motion:SpinStation")
	-- The stage (the Spin Wheel section of GameplayServices) walks the player up and then asks for the E press; it is pressed here, on
	-- the real prompt, so the server's real Triggered handler runs. The camera is held for the shot,
	-- which hides every ScreenGui not marked kept: the HUD (the token purse) is context for this
	-- capture, so for this one stage every ScreenGui is kept.
	-- "Motion:SpinPopup" reuses the same walk-up and press with the live follow camera and HUD.
	local showcase = RunService:IsStudio() and Workspace:GetAttribute("GuiShowcase") or nil
	if showcase == "Motion:SpinStation" or showcase == "Motion:SpinPopup" or showcase == "Motion:MultiSpin" then
		local function keep(child)
			if child:IsA("ScreenGui") then child:SetAttribute("GuiShowcaseKeep", true) end
		end
		for _, child in ipairs(playerGui:GetChildren()) do keep(child) end
		playerGui.ChildAdded:Connect(keep)
		player:GetAttributeChangedSignal("GuiShowcaseSpinPress"):Connect(function()
			if player:GetAttribute("GuiShowcaseSpinPress") == nil then return end
			-- "Motion:MultiSpin" presses the F (multi-spin) prompt instead of E.
			local prompt = player:GetAttribute("GuiShowcaseSpinWhich") == "multi" and multiPrompt or singlePrompt
			prompt:InputHoldBegin()
			task.wait(0.05)
			prompt:InputHoldEnd()
		end)
	end

	print("[SpinStation] Spin Wheel board and face live")
end

-- The wheel may still be streaming in when the client starts: wait for it off the caller's thread.
task.spawn(run)

return SpinStation
