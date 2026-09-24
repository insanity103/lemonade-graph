--// EnemyDropStage  (Studio-only capture stage: every enemy the world spawns, and what it drops)
--
-- Set in edit mode, before pressing Play:
--     workspace:SetAttribute("GuiShowcase", "Motion:EnemyDrops")
-- Runs only through GuiShowcase.stage, which is inert outside Studio (RunService:IsStudio()) and
-- only fires while the showcase attribute names this stage.
--
-- The board is the drop table as the game actually behaves, read live, never retyped:
--   * columns are the eight zones of WorldLayout.ZONES in order, rows are the enemies that zone
--     spawns, its capstone first;
--   * each cell's name, level, max health and XP are read off the live rig standing in the world
--     (EnemyCombat's own attributes and Humanoid.MaxHealth) once every archetype has finished
--     spawning, so the board cannot drift from the game;
--   * the drop line is the real rule: the cell calls DropRules.Plan with the rig's own attributes,
--     the same call SwordDropSystem's death handler makes, and prints the plan it gets back --
--     pool, per-kill chance and rarity ladder;
--   * the sword standing in each cell is a real BossSwordFactory build from that cell's own pool,
--     so the swords on the board are the swords a drop hands the player.
-- While the board is up it also plays the real drop card: every REVEAL_EVERY seconds it rolls one
-- ordinary enemy through DropRules and fires the shipped SwordDrop remote at the viewer, so the
-- capture shows what a normal-enemy drop looks like in play. The Tool is destroyed the moment its
-- numbers have been read.
-- Nothing here touches player data: no Tool is ever given to a player, no gold, XP, drop or quest
-- state changes, and every part it spawns is tracked by the stage so it is destroyed when the
-- stage returns.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then
	return
end

local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))
local BossWeapons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BossWeapons"))
local DropRules = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("DropRules"))
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
local BossSwordFactory = require(script.Parent:WaitForChild("BossSwordFactory"))
local CombatUtil = require(script.Parent:WaitForChild("CombatUtil"))
local WorldLayout = require(script.Parent:WaitForChild("WorldLayout"))
local DROP_EVENT = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("SwordDrop")

local HOLD = 240 -- [TUNING] seconds the board stays up for the capture before the stage cleans up
local ORIGIN = Vector3.new(0, 900, 0) -- high above the map, and clear of SwordGalleryStage's wall
local COL_STEP, ROW_STEP = 27, 10.4
local COLS, ROWS = 8, 3 -- the eight zones; the enemy kinds any one of them spawns
local SPAWN_WAIT = 25 -- [TUNING] seconds to wait for EnemyCombat to finish building its rigs
local REVEAL_EVERY = 3.0 -- [TUNING] seconds between drop cards, so one is always on screen
local SWORD_SCALE, SWORD_TILT = 1.25, math.rad(-12)
local BACKDROP = Color3.fromRGB(26, 28, 44)
local LEMON = Color3.fromRGB(255, 244, 120)
local DIM = Color3.fromRGB(200, 200, 215)
local GREEN = Color3.fromRGB(150, 235, 150)
local FONT = Enum.Font.GothamBold
local RARITY_HEX = {}
for rarity, color in pairs(PanelChrome.RARITY_COLORS) do
	RARITY_HEX[rarity] = string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

-- The name EnemyCombat gives each archetype. Only ever used for a zone the map has no spawn
-- markers for yet: where a rig is standing, the board reads the name off the rig itself.
local ARCHETYPE_NAMES = {
	IronSquire = "Quarry Cutthroat", IronBerserker = "Pit Brute", ThornStalker = "Thorn Stalker",
	BriarBrute = "Briar Brute", RootWarden = "Rootbound Warden", FrostImp = "Frost Stalker",
	GlacialGargoyle = "Glacial Sentinel", BogLurker = "Bog Lurker", MireHulk = "Mire Hulk",
	DrownedBellwarden = "Drowned Bellwarden", CinderFiend = "Cinder Fiend",
	MagmaJuggernaut = "Magma Juggernaut", Stormcaller = "Stormcaller",
	ThunderConstruct = "Thunder Construct", TempestWarden = "Tempest Warden",
	VoidShade = "Void Shade", AbyssTormentor = "Abyss Tormentor", AstralWisp = "Astral Emissary",
	SolarDominator = "Solar Dominator",
}
local function enemyName(rig, key)
	return (rig and rig.displayName) or ARCHETYPE_NAMES[key] or BossWeapons.PoolName(key) or key
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
	gui.MaxDistance = 900
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
		text.TextColor3 = line.color or Color3.new(1, 1, 1)
		text.TextStrokeColor3 = Color3.fromRGB(10, 10, 20)
		text.TextStrokeTransparency = 0.35
		text.RichText = line.rich == true
		text.Text = line.text
		text.TextXAlignment = align or Enum.TextXAlignment.Center
		text.Parent = gui
	end
	return anchor
end

-- What the world is actually running: one entry per live enemy rig, keyed by its Archetype
-- attribute, with the values EnemyCombat gave it.
local function scanEnemies()
	local byKey = {}
	for _, model in ipairs(workspace:GetDescendants()) do
		if model:IsA("Model") and CombatUtil.isEnemy(model) then
			local key = model:GetAttribute("Archetype")
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if typeof(key) == "string" and humanoid and not byKey[key] then
				byKey[key] = {
					displayName = model.Name,
					level = model:GetAttribute("EnemyLevel"),
					health = humanoid.MaxHealth,
					xp = model:GetAttribute("ExperienceReward"),
					boss = model:GetAttribute("Boss") == true,
					zone = model:GetAttribute("Zone"),
					role = model:GetAttribute("SpawnRole"),
				}
			end
		end
	end
	return byKey
end

-- EnemyCombat builds its rigs one at a time (each one loads a rig, an outfit and a weapon), so the
-- board waits for every archetype the zones list to exist before it reads any of them. It gives up
-- after SPAWN_WAIT and says so on the cell rather than inventing a number: in the map project only
-- the zones with spawn markers are populated, and the rest stay idle.
local function liveEnemies(wanted)
	local deadline = os.clock() + SPAWN_WAIT
	local byKey = scanEnemies()
	while os.clock() < deadline do
		local missing = false
		for key in pairs(wanted) do
			if not byKey[key] then missing = true break end
		end
		if not missing then
			break
		end
		task.wait(1)
		byKey = scanEnemies()
	end
	return byKey
end

-- Every BasePart of a freshly built sword, anchored, as one Model stood on its pommel.
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

local function comma(n)
	local s = string.format("%d", math.floor(tonumber(n) or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function cellCenter(col, row)
	return ORIGIN + Vector3.new((col - (COLS + 1) / 2) * COL_STEP, ((ROWS + 1) / 2 - row) * ROW_STEP, 0)
end

GuiShowcase.stage("EnemyDrops", function(ctx)
	local folder = ctx.track(Instance.new("Folder"))
	folder.Name = "EnemyDropStage"
	folder.Parent = workspace

	-- One column per zone, rows = the distinct archetypes it spawns, capstone first.
	local cols, kinds, wanted = {}, 0, {}
	for _, zone in ipairs(WorldLayout.ZONES) do
		local col = { zone = zone.Name, list = {}, seen = {} }
		table.insert(cols, col)
		for _, e in ipairs(zone.Enemies) do
			local key = e[1]
			if not col.seen[key] then
				col.seen[key] = true
				wanted[key] = true
				table.insert(col.list, { key = key, level = e[2], role = e[3] or "minion", zone = zone.Name })
				kinds += 1
			end
		end
		table.sort(col.list, function(a, b) return a.level > b.level end)
	end

	-- Read the world only once every rig it lists exists.
	local live = liveEnemies(wanted)
	local unspawned = {}
	for key in pairs(wanted) do
		if not live[key] then
			table.insert(unspawned, key)
		end
	end
	table.sort(unspawned)

	-- Wall, floor and a little fill light so unlit materials still read at any world clock.
	part(folder, Vector3.new(COL_STEP * COLS + 12, ROW_STEP * ROWS + 22, 1),
		CFrame.new(ORIGIN + Vector3.new(0, 6.0, -3)), BACKDROP)
	for _, x in ipairs({ -80, 0, 80 }) do
		local lamp = part(folder, Vector3.new(0.2, 0.2, 0.2), CFrame.new(ORIGIN + Vector3.new(x, 6, 16)), BACKDROP, nil, 1)
		local light = Instance.new("PointLight")
		light.Brightness = 1.3
		light.Range = 120
		light.Shadows = false
		light.Parent = lamp
	end

	local dropping = 0
	local plans = {}
	for _, col in ipairs(cols) do
		for _, e in ipairs(col.list) do
			local rig = live[e.key]
			local plan = DropRules.Plan(e.key, (rig and rig.zone) or e.zone,
				(rig and rig.role) or e.role, (rig and rig.boss) or BossWeapons.DropChance[e.key] ~= nil)
			e.plan = plan
			if plan then
				dropping += 1
				table.insert(plans, { e = e, plan = plan })
			end
		end
	end

	label(folder, ORIGIN + Vector3.new(0, (ROWS + 1) / 2 * ROW_STEP + 5.0, 0), {
		{ text = string.format("LEMONADE  |  WHAT EVERY ENEMY DROPS  -  %d of %d enemy kinds drop a sword", dropping, kinds), px = 36, color = LEMON },
		{ text = string.format("%d lesser swords in %d zone pools (5 + the zone Relic)  +  %d boss swords in 5 pools  =  %d",
			BossWeapons.CountSwords("lesser"), #BossWeapons.ZoneOrder, BossWeapons.CountSwords("boss"), BossWeapons.CountSwords()), px = 21, color = GREEN },
		{ text = "column = zone  |  row = an enemy that spawns there  |  name, level, health and XP read off the live rig; pool and chance from DropRules.Plan", px = 18, color = DIM },
	}, 1800, 90)

	-- Row bands so the eye reads across the zones.
	for row = 1, ROWS do
		local y = ((ROWS + 1) / 2 - row) * ROW_STEP
		part(folder, Vector3.new(COL_STEP * COLS + 6, ROW_STEP - 0.7, 0.3),
			CFrame.new(ORIGIN + Vector3.new(0, y, -1.5)), row % 2 == 0 and Color3.fromRGB(70, 74, 100) or Color3.fromRGB(52, 56, 82), nil, 0.55)
	end

	local placedSwords, missing = 0, {}
	for col, entry in ipairs(cols) do
		local top = cellCenter(col, 1) + Vector3.new(0, ROW_STEP * 0.5 + 1.3, 0)
		local pool = BossWeapons.NormalPools[entry.zone]
		label(folder, top, {
			{ text = BossWeapons.ZoneNames[entry.zone] or entry.zone, px = 20, color = LEMON },
			{ text = pool and string.format("%d lesser + %s", #pool.swords, pool.legendary.name) or "no lesser pool", px = 13, color = DIM },
		}, 200, 36)

		for row, e in ipairs(entry.list) do
			local center = cellCenter(col, row)
			local rig = live[e.key] or {}
			local plan = e.plan
			local lines = {
				{ text = enemyName(rig, e.key), px = 17, color = LEMON },
				{ text = rig.health and string.format("Lv %d %s  |  %s HP", rig.level, e.role, comma(rig.health))
					or string.format("Lv %d %s  |  zone idle", e.level, e.role), px = 13, color = DIM },
			}
			if plan then
				local rows = BossWeapons.PoolRows(plan.poolKey)
				table.insert(lines, { text = string.format("%.1f%% per kill, 1 of %d", plan.chance * 100, #rows), px = 15, color = GREEN })
				-- The sword in the cell: a different one per row, so a zone's three cells show
				-- three of its pool, and the capstone shows the pool's showpiece.
				local pick = rows[math.max(1, math.min(row == 1 and #rows or (#rows - row), #rows))] or rows[1]
				local rarity = pick.legendary and "Legendary" or "Epic"
				table.insert(lines, { text = string.format('<font color="%s">%s</font> x%.2f',
					RARITY_HEX[rarity] or "#FFD700", pick.name, pick.rarities[rarity] or pick.poolBase), px = 13, rich = true })
				local tool = BossSwordFactory.build(plan.poolKey, { sword = pick.name, rarity = rarity, jitter = false })
				local model = tool and swordModel(tool)
				if tool then
					tool:Destroy()
				end
				if model then
					model.Parent = folder
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
					model:PivotTo(model:GetPivot() + (center + Vector3.new(-8.6, 0, 0) - box.Position))
					placedSwords += 1
				else
					table.insert(missing, e.key)
				end
			else
				table.insert(lines, { text = "no plan for this rig", px = 16, color = Color3.fromRGB(240, 120, 120) })
			end
			label(folder, center + Vector3.new(2.6, 0, 0.6), lines, 150, 62, Enum.TextXAlignment.Left)
		end
	end
	print(string.format("[EnemyDropStage] %d enemy kinds across %d zones; %d drop a sword, %d drop nothing; placed %d sword models%s%s",
		kinds, #cols, dropping, kinds - dropping, placedSwords,
		#missing > 0 and (" (no model: " .. table.concat(missing, ", ") .. ")") or "",
		#unspawned > 0 and (" (never spawned: " .. table.concat(unspawned, ", ") .. ")") or " (every rig read live)"))

	-- Park the character on a ledge behind the camera, out of shot, then hold the camera.
	local eye = ORIGIN + Vector3.new(0, 20, 74)
	part(folder, Vector3.new(12, 1, 12), CFrame.new(eye + Vector3.new(0, -24, 14)), BACKDROP)
	ctx.place(CFrame.new(eye + Vector3.new(0, -20, 14)))
	ctx.camera(CFrame.lookAt(eye, ORIGIN + Vector3.new(0, 20, 0)))

	-- The drop card, for real, over the board: roll an ordinary enemy through DropRules, build the
	-- sword it would hand over with BossSwordFactory, fire the shipped SwordDrop remote, destroy
	-- the Tool. The player is never given anything and nothing is saved.
	local normals = {}
	for _, row in ipairs(plans) do
		if row.plan.lesser then table.insert(normals, row) end
	end
	-- A ticker on the board, so the capture itself says whether the card is live and what fell.
	local tickerAnchor = label(folder, ORIGIN + Vector3.new(0, -((ROWS + 1) / 2) * ROW_STEP - 1.0, 0),
		{ { text = "rolling a live drop...", px = 19, color = GREEN } }, 1400, 26)
	local ticker = tickerAnchor:FindFirstChildOfClass("BillboardGui"):FindFirstChildOfClass("TextLabel")

	local deadline = os.clock() + HOLD
	local fired, lastLine = 0, ""
	while os.clock() < deadline and #normals > 0 do
		local pick = normals[math.random(#normals)]
		local ok, err = pcall(function()
			local roll = DropRules.Roll(pick.plan, { rebirths = 0, pity = 99, rarePity = 0 }) -- pity: always pays
			local tool, mods, fullName, weaponData = BossSwordFactory.build(pick.plan.poolKey,
				{ rarityOdds = pick.plan.rarityOdds, luck = 1 })
			local rig = live[pick.e.key] or {}
			for _, mod in ipairs(mods) do
				mod.oneInText = nil
				mod.p = nil
				mod.oneIn = nil
			end
			DROP_EVENT:FireClient(ctx.player, weaponData.rarity, weaponData.baseMult, fullName, mods,
				{ pool = weaponData.bossName, baseName = weaponData.name, listedBase = weaponData.listedBase,
					rarityOdds = weaponData.rarityOdds, legendary = weaponData.isLegendary, lesser = true,
					source = enemyName(rig, pick.e.key), rank = pick.plan.rank, dropChance = roll.chance })
			tool:Destroy()
			fired += 1
			lastLine = string.format("LIVE DROP CARD #%d:  %s dropped  %s  (%s, %s lesser pool, %.1f%% per kill)",
				fired, enemyName(rig, pick.e.key), fullName, weaponData.rarity, weaponData.bossName, roll.chance * 100)
			print("[EnemyDropStage] " .. lastLine)
		end)
		if not ok then
			lastLine = "drop card error: " .. tostring(err)
			warn("[EnemyDropStage] " .. lastLine)
		end
		ticker.Text = lastLine
		task.wait(REVEAL_EVERY)
	end
	task.wait(2)
end)
