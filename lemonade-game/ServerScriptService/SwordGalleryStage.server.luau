--// SwordGalleryStage  (Studio-only capture stage: the whole sword roster laid out by boss pool and rarity)
--
-- Set in edit mode, before pressing Play:
--     workspace:SetAttribute("GuiShowcase", "Motion:SwordGallery")
-- Runs only through GuiShowcase.stage, which is inert outside Studio (RunService:IsStudio()) and
-- only fires while the showcase attribute names this stage. It builds every sword in the roster
-- with the real BossSwordFactory (the same models, colours and materials a drop hands the player),
-- anchors their parts on a wall in the sky in a grid (columns = the boss whose pool it is, rows =
-- the swords of that pool, Legendary on top), labels each with its name and its base at every
-- rarity it drops at, parks the test player's character behind the camera and holds the camera on
-- the wall until the capture is taken. Nothing here touches player data: no Tool is ever given to
-- a player, no gold, XP, drop or quest state changes, and every part it spawns is tracked by the
-- stage so it is destroyed when the stage returns.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then
	return
end

local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))
local BossWeapons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BossWeapons"))
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
local BossSwordFactory = require(script.Parent:WaitForChild("BossSwordFactory"))

local HOLD = 240 -- [TUNING] seconds the wall stays up for the capture before the stage cleans up
local ORIGIN = Vector3.new(0, 600, 0) -- high above the map so nothing built there is in shot
local COL_STEP, ROW_STEP = 23, 6.6
local ROWS = 7 -- swords per pool: the Legendary on top, then the six regular swords, best first
local SWORD_SCALE, SWORD_TILT = 1.3, math.rad(-12) -- a held sword is 3.3-5.0 studs; 1.3 fills a 6.6-stud row (1.8 overflowed it)
local BOSS_LEVELS = { 10, 25, 45, 70, 100 } -- WorldLayout.ZONES, by boss tier
-- PS99 chrome (sword gauntlet round 1, 2026-09-24: four blind critics out of four named the dark
-- navy "spreadsheet" board): a pale cream card with a thick dark ink outline, pale row bands, dark
-- ink text, and saturated colour only on the swords and the rarity accents.
local BACKDROP = Color3.fromRGB(252, 248, 238) -- cream card
local OUTLINE = Color3.fromRGB(44, 48, 86) -- ink
local LEMON = Color3.fromRGB(255, 120, 40) -- headings: the timber orange accent
local DIM = Color3.fromRGB(86, 92, 128) -- body text: soft ink
local INK = Color3.fromRGB(34, 38, 70) -- sword names
local FONT = Enum.Font.GothamBold
local RARITY_HEX = {}
for rarity, color in pairs(PanelChrome.RARITY_COLORS) do
	RARITY_HEX[rarity] = string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function part(folder, size, cframe, color, material, transparency)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Parent = folder
	return p
end

local function label(folder, position, lines, widthPx, heightPx, align)
	local anchor = part(folder, Vector3.new(0.2, 0.2, 0.2), CFrame.new(position), BACKDROP, nil, 1)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(widthPx, heightPx)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 500
	gui.Parent = anchor
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = if align == Enum.TextXAlignment.Left then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Center
	list.Parent = gui
	for _, line in ipairs(lines) do
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.new(1, 0, 0, line.px)
		text.Font = FONT
		text.TextSize = line.px - 4
		text.TextColor3 = line.color or INK
		text.TextStrokeColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.55
		text.RichText = line.rich == true
		text.Text = line.text
		text.TextXAlignment = align or Enum.TextXAlignment.Center
		text.Parent = gui
	end
	return anchor
end

-- Where each sword sits: column by boss tier, row by its place in the pool (1 = Legendary, top).
local function cellCenter(tier, row)
	local col = tier - 3
	return ORIGIN + Vector3.new(col * COL_STEP, (4 - row) * ROW_STEP, 0)
end

-- Every BasePart of a freshly built boss sword, anchored, as one Model stood on its pommel with the
-- broad face toward the camera. The tool was never in the workspace, so its welded parts are still
-- at the origin: place each one from its Weld (Handle = Part0) the way physics would.
local function swordModel(tool)
	local handle = tool:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = tool:GetAttribute("BaseWeaponName") or tool.Name
	handle.CFrame = CFrame.new()
	for _, weld in ipairs(handle:GetChildren()) do
		if weld:IsA("Weld") and weld.Part0 == handle and weld.Part1 then
			weld.Part1.CFrame = handle.CFrame * weld.C0 * weld.C1:Inverse()
		end
	end
	for _, d in ipairs(tool:GetChildren()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Parent = model
		end
	end
	model.PrimaryPart = handle
	return model
end

local function fmtOdds(p)
	return string.format("%g%%", p * 100)
end

GuiShowcase.stage("SwordGallery", function(ctx)
	local folder = ctx.track(Instance.new("Folder"))
	folder.Name = "SwordGalleryStage"
	folder.Parent = workspace

	-- Wall, floor and a little fill light so unlit materials still read at any world clock.
	local wallCenter = ORIGIN + Vector3.new(-2, 3.0, -3)
	part(folder, Vector3.new(COL_STEP * 5 + 14, ROW_STEP * ROWS + 20, 1), CFrame.new(wallCenter), BACKDROP)
	-- The thick ink outline: a slightly larger ink slab just behind the card.
	part(folder, Vector3.new(COL_STEP * 5 + 15.6, ROW_STEP * ROWS + 21.6, 1), CFrame.new(wallCenter + Vector3.new(0, 0, -0.6)), OUTLINE)
	for _, x in ipairs({ -40, 0, 40 }) do
		local lamp = part(folder, Vector3.new(0.2, 0.2, 0.2), CFrame.new(ORIGIN + Vector3.new(x, 4, 16)), BACKDROP, nil, 1)
		local light = Instance.new("PointLight")
		light.Brightness = 0.5 -- a pale card needs far less fill than the old dark wall
		light.Range = 70
		light.Shadows = false
		light.Parent = lamp
	end

	-- Title and the boss columns.
	local odds = {}
	for _, row in ipairs(BossWeapons.RarityOdds) do
		table.insert(odds, string.format('<font color="%s">%s %s</font>', RARITY_HEX[row.rarity] or "#FFFFFF", row.rarity, fmtOdds(row.p)))
	end
	label(folder, ORIGIN + Vector3.new(-2, 4 * ROW_STEP + 2.6, 0), {
		{ text = string.format("LEMONADE  |  BOSS SWORD POOLS  -  %d boss swords in 5 pools (+%d lesser swords in %d zone pools)", BossWeapons.CountSwords("boss"), BossWeapons.CountSwords("lesser"), #BossWeapons.ZoneOrder), px = 32, color = LEMON },
		{ text = "column = the boss whose pool it is  |  row = the sword  |  C / U / R / E = its base damage multiplier at Common / Uncommon / Rare / Epic (+5% a step)  |  Legendary = the boss showpiece, +17% over the best Epic", px = 17, color = DIM },
		{ text = "a drop rolls its rarity first:  " .. table.concat(odds, "   ") .. "   then which sword (weight below)   then its base at x0.95 - x1.05", px = 17, color = DIM, rich = true },
	}, 1500, 72)
	for tier = 1, 5 do
		local key = BossWeapons.ArchetypeByTier[tier]
		local top = cellCenter(tier, 1) + Vector3.new(0, ROW_STEP * 0.5 + 1.6, 0)
		local drop = BossWeapons.DropChance[key]
		label(folder, top, {
			{ text = BossWeapons.BossNames[key], px = 23, color = LEMON },
			{ text = string.format("Lv %d boss  |  drops a sword %s of kills", BOSS_LEVELS[tier], fmtOdds(drop and drop.chance or 0)), px = 16, color = DIM },
		}, 300, 42)
	end

	-- Row bands: gold for the Legendary row, alternating pale sky and pale lavender for the rest.
	for row = 1, ROWS do
		local y = (4 - row) * ROW_STEP
		local color = row == 1 and PanelChrome.RARITY_COLORS.Legendary or (row % 2 == 0 and Color3.fromRGB(226, 238, 255) or Color3.fromRGB(240, 234, 255))
		part(folder, Vector3.new(COL_STEP * 5 + 4, ROW_STEP - 0.5, 0.3), CFrame.new(ORIGIN + Vector3.new(-2, y, -1.5)), color, nil, row == 1 and 0.55 or 0)
	end

	-- The roster itself: one real build per pool sword, straight from BossSwordFactory.
	local placed, missing = 0, {}
	for tier = 1, 5 do
		local key = BossWeapons.ArchetypeByTier[tier]
		local rows = BossWeapons.PoolRows(key)
		-- Legendary first, then the regular swords best first.
		table.sort(rows, function(a, b)
			if (a.legendary or false) ~= (b.legendary or false) then return a.legendary == true end
			return a.poolBase > b.poolBase
		end)
		for row, entry in ipairs(rows) do
			local tool, _, _, data = BossSwordFactory.build(key, { sword = entry.name, rarity = entry.legendary and "Legendary" or "Epic",
				jitter = false })
			local model = tool and swordModel(tool)
			if tool then
				tool:Destroy()
			end
			local center = cellCenter(tier, row)
			if model then
				model.Parent = folder
				-- Stand it up: tip (-Z in the sword's own space) up, broad face (X) toward the camera.
				local upright = CFrame.new(center) * CFrame.Angles(0, 0, SWORD_TILT)
					* CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, -1, 0))
				-- A sword MeshPart as Studio imports it has its tip at +Z (the block sword's is at -Z), so
				-- turn a mesh end for end, or it stands on its tip (Studio check, 2026-09-24).
				if model.PrimaryPart and model.PrimaryPart:IsA("MeshPart") then
					upright = upright * CFrame.Angles(0, math.pi, 0)
				end
				model:PivotTo(upright)
				model:ScaleTo(SWORD_SCALE)
				local box = model:GetBoundingBox()
				model:PivotTo(model:GetPivot() + (center + Vector3.new(-10.3, 0, 0) - box.Position))
				-- The item tile (sword gauntlet round 2: "no outlined tile per row", and white blades lost on
				-- the cream card): a pale sky-blue slot with an ink outline behind each sword, gold-tinted
				-- on the Legendary row, so every pale blade has a colour to stand against.
				local tile = center + Vector3.new(-10.3, 0, -0.7)
				part(folder, Vector3.new(5.6, ROW_STEP - 1.0, 0.2), CFrame.new(tile + Vector3.new(0, 0, -0.15)), OUTLINE)
				part(folder, Vector3.new(5.0, ROW_STEP - 1.6, 0.2), CFrame.new(tile),
					row == 1 and Color3.fromRGB(255, 226, 150) or Color3.fromRGB(190, 222, 255))
				placed += 1
			else
				table.insert(missing, entry.name)
			end
			local lines
			if entry.legendary then
				lines = {
					{ text = entry.name, px = 21, color = PanelChrome.RARITY_COLORS.Legendary },
					{ text = string.format('<font color="%s">LEGENDARY  x%.2f</font>', RARITY_HEX.Legendary, entry.poolBase), px = 17, rich = true },
					{ text = string.format("%s of drops  |  %s", fmtOdds(BossWeapons.RarityOdds[5].p), data and data.look and (data.look.mesh == "Blocks" and "block build" or "mesh") or ""), px = 15, color = DIM },
				}
			else
				local r = entry.rarities
				lines = {
					{ text = entry.name, px = 21, color = INK },
					{ text = string.format('<font color="%s">C %.2f</font>  <font color="%s">U %.2f</font>  <font color="%s">R %.2f</font>  <font color="%s">E %.2f</font>',
						RARITY_HEX.Common, r.Common, RARITY_HEX.Uncommon, r.Uncommon, RARITY_HEX.Rare, r.Rare, RARITY_HEX.Epic, r.Epic), px = 17, rich = true },
					{ text = string.format("weight %d of 100 regular drops", entry.weight), px = 15, color = DIM },
				}
			end
			-- A 245 px billboard is ~16.6 studs wide from this camera, so its left edge sits ~5.7 studs left of centre.
			-- Narrower and a little right of centre so the text clears the sword: the new blades are
			-- chunkier than the ones this board was spaced for (Studio check, 2026-09-24).
			label(folder, center + Vector3.new(3.6, 0, 0.6), lines, 235, 58, Enum.TextXAlignment.Left)
		end
	end
	print(string.format("[SwordGalleryStage] placed %d of %d swords%s", placed, BossWeapons.CountSwords(),
		#missing > 0 and (" (missing: " .. table.concat(missing, ", ") .. ")") or ""))

	-- Park the character on a ledge behind the camera, out of shot, then hold the camera on the wall.
	local eye = ORIGIN + Vector3.new(-2, 3.6, 42)
	part(folder, Vector3.new(12, 1, 12), CFrame.new(eye + Vector3.new(0, -6, 14)), BACKDROP)
	ctx.place(CFrame.new(eye + Vector3.new(0, -2, 14)))
	ctx.camera(CFrame.lookAt(eye, ORIGIN + Vector3.new(-2, 3.6, 0)))
	task.wait(HOLD)
end)
