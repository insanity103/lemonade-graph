--// SpinService  (server: how deep each player has pushed into each area, and the spin roll itself)
-- The pool table and the odds maths are Config.SpinPools (shared with the client's odds display).
-- This module owns everything a client must never decide:
--   * DEPTH. Every kill a player lands is recorded here (SwordDropSystem calls RecordKill from the
--     one Died hook the game already has): the highest-level foe beaten per area, and whether its
--     boss or warden has fallen. Persisted in the profile as `zoneDepth`, never lowered, mirrored to
--     player attributes Depth_<Zone> (0-4), SpinZone and SpinStep for the display.
--   * THRESHOLDS. Where an area's midway and deep camps are, read once from the live spawn list
--     (WorldLayout.GetEnemySpawns), so both the baseplate layout and the map get their real camps.
--     Published on ReplicatedStorage.SpinDepth as attributes <Zone>_Mid / _Deep / _Boss.
--   * THE ROLL. Roll() picks the area (the player's furthest open one unless they name another
--     open one), reads SpinPools.Odds for that area, depth step and the player's level, and draws
--     one row. Grant() builds that exact sword through BossSwordFactory (fixed sword + rarity; the
--     prefix rolls at the player's level and slots like every other sword). The token cost and the
--     town-only gate sit in front of these in the spin station.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local SpinPools = require(Config:WaitForChild("SpinPools"))
local WeaponModifiers = require(Config:WaitForChild("WeaponModifiers"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local BossSwordFactory = require(script.Parent:WaitForChild("BossSwordFactory"))
local WorldLayout = require(script.Parent:WaitForChild("WorldLayout"))

local SpinService = {}

-- ---------------------------------------------------------------- thresholds
-- [zone] = { lo, hi, mid, deep, bossLevel }. mid = ceil((lo + hi) / 2) over the area's non-boss
-- spawns, deep = hi, bossLevel = its boss / warden spawn level (display only: step 4 is the KILL).
local depthTable = {}

local function buildDepthTable()
	local seen = {}
	local ok, spawns = pcall(WorldLayout.GetEnemySpawns)
	for _, config in ipairs(ok and spawns or {}) do
		local zone = config.zone
		local row = seen[zone] or { lo = math.huge, hi = -math.huge, bossLevel = nil }
		seen[zone] = row
		if config.role == "boss" then
			row.bossLevel = math.max(row.bossLevel or 0, config.level)
		else
			row.lo = math.min(row.lo, config.level)
			row.hi = math.max(row.hi, config.level)
		end
	end
	-- An area with no live spawns (a map zone not built yet) falls back to WorldLayout.ZONES.
	for _, zoneDef in ipairs(WorldLayout.ZONES) do
		local row = seen[zoneDef.Name]
		if not row or row.lo == math.huge then
			row = { lo = math.huge, hi = -math.huge, bossLevel = nil }
			for _, enemy in ipairs(zoneDef.Enemies) do
				if enemy[3] == "boss" then
					row.bossLevel = enemy[2]
				else
					row.lo = math.min(row.lo, enemy[2])
					row.hi = math.max(row.hi, enemy[2])
				end
			end
			seen[zoneDef.Name] = row
		end
	end
	for zone, row in pairs(seen) do
		if row.lo ~= math.huge then
			row.mid = math.ceil((row.lo + row.hi) / 2)
			row.deep = row.hi
			if row.mid >= row.deep and row.deep > row.lo then row.mid = row.deep - 1 end
			depthTable[zone] = row
		end
	end
	local folder = ReplicatedStorage:FindFirstChild("SpinDepth") or Instance.new("Folder")
	folder.Name = "SpinDepth"
	for zone, row in pairs(depthTable) do
		folder:SetAttribute(zone .. "_Mid", row.mid)
		folder:SetAttribute(zone .. "_Deep", row.deep)
		folder:SetAttribute(zone .. "_Boss", row.bossLevel or 0)
	end
	folder.Parent = ReplicatedStorage
end

function SpinService.Depth(zone)
	return depthTable[zone]
end

-- Step (0-4) from a stored record { best = level, boss = bool }.
function SpinService.StepFor(zone, record)
	if typeof(record) ~= "table" then return 0 end
	local row = depthTable[zone]
	local best = tonumber(record.best) or 0
	local step = 1
	if record.boss == true then
		return 4
	end
	if row then
		if best >= row.deep then
			step = 3
		elseif best >= row.mid then
			step = 2
		end
	end
	return step
end

-- ---------------------------------------------------------------- per-player state
local function playerLevel(player)
	local stats = player:FindFirstChild("leaderstats")
	local lv = stats and stats:FindFirstChild("Level")
	return lv and lv.Value or tonumber(player:GetAttribute("Level")) or 1
end
SpinService.PlayerLevel = playerLevel

local function depthRecord(player)
	local record = PlayerDataService.GetField(player, "zoneDepth")
	return typeof(record) == "table" and record or nil
end

function SpinService.StepOf(player, zone)
	local record = depthRecord(player)
	return SpinService.StepFor(zone, record and record[zone])
end

local function mirror(player)
	local record = depthRecord(player) or {}
	for _, zone in ipairs(SpinPools.Order) do
		player:SetAttribute(SpinPools.DepthAttr(zone), SpinService.StepFor(zone, record[zone]))
	end
	local zone, step = SpinPools.DefaultZone(function(z) return SpinService.StepFor(z, record[z]) end,
		playerLevel(player))
	player:SetAttribute("SpinZone", zone)
	player:SetAttribute("SpinStep", step)
end

-- A profile saved before the spin wheel has no `zoneDepth`. It is rebuilt, never guessed high:
-- every area whose gate the player's level meets counts as reached with its best foe at that level
-- (a Lv 40 profile has beaten Lv 40 foes), and a boss area whose boss already paid this profile
-- its first sword (bossFirstDrops, persisted since the lesser-pool update) counts as boss down.
-- Wardens never wrote a record, so their areas start at the depth the level earns.
local function migrate(player)
	local level = playerLevel(player)
	local firsts = PlayerDataService.GetField(player, "bossFirstDrops")
	if typeof(firsts) ~= "table" then firsts = {} end
	local record = {}
	for _, pool in ipairs(SpinPools.Pools) do
		if level >= pool.gate then
			record[pool.zone] = { best = level, boss = (pool.boss ~= nil and firsts[pool.boss] == true) or nil }
		end
	end
	PlayerDataService.SetField(player, "zoneDepth", record)
	return record
end

local function onDataLoaded(player)
	if not PlayerDataService.IsReady(player) then return end
	if depthRecord(player) == nil then
		local record = migrate(player)
		local count = 0
		for _ in pairs(record) do count += 1 end
		print(string.format("[SpinService] %s: pre-spin profile migrated, %d area(s) reached from Lv %d",
			player.Name, count, playerLevel(player)))
	end
	mirror(player)
end

-- Called for every enemy death with a player killer. Raises that area's record, never lowers it.
function SpinService.RecordKill(player, model)
	if not (player and player.Parent and model) then return end
	local zone = model:GetAttribute("Zone")
	if typeof(zone) ~= "string" or not SpinPools.ByZone[zone] then return end
	local record = depthRecord(player)
	if not record then return end -- profile not applied yet: nothing to write to
	local level = tonumber(model:GetAttribute("EnemyLevel")) or 1
	local isBoss = model:GetAttribute("SpawnRole") == "boss" or model:GetAttribute("Boss") == true
	local row = record[zone]
	local before = SpinService.StepFor(zone, row)
	if typeof(row) ~= "table" then
		row = { best = 0 }
		record[zone] = row
	end
	local changed = false
	if level > (tonumber(row.best) or 0) then
		row.best = level
		changed = true
	end
	if isBoss and row.boss ~= true then
		row.boss = true
		changed = true
	end
	if not changed then return end
	PlayerDataService.SetField(player, "zoneDepth", record)
	local after = SpinService.StepFor(zone, row)
	mirror(player)
	if after > before then
		print(string.format("[SpinService] %s pushed %s to step %d (%s)", player.Name, zone, after,
			SpinPools.STEP_NAMES[after]))
	end
end

-- ---------------------------------------------------------------- the roll
-- The area a spin uses: `zone` if named, reached and open at this level, else the furthest open
-- one. Returns zone, step, rows (SpinPools.Odds) or nil, reason.
function SpinService.PoolFor(player, zone)
	local level = playerLevel(player)
	local record = depthRecord(player) or {}
	local function depthOf(z) return SpinService.StepFor(z, record[z]) end
	if zone ~= nil then
		local pool = SpinPools.Get(zone)
		if not pool then return nil, "unknown area" end
		local step = depthOf(zone)
		if zone ~= SpinPools.Order[1] and step < 1 then return nil, "area not reached" end
		if level < pool.gate then return nil, "level too low" end
		local rows, used = SpinPools.Odds(zone, math.max(step, 1), level)
		return zone, used, rows
	end
	local z, step = SpinPools.DefaultZone(depthOf, level)
	local rows, used = SpinPools.Odds(z, step, level)
	return z, used or step, rows
end

-- Draw one row. rng (optional) returns a uniform in [0, 1); default math.random.
function SpinService.Roll(player, zone, rng)
	local z, step, rows = SpinService.PoolFor(player, zone)
	if not z or not rows then return nil, step end
	local row = SpinPools.Pick(rows, (rng or math.random)())
	return row, z, step, rows
end

-- Build the rolled sword (the spin station parents it). Returns tool, mods, fullName, weaponData.
function SpinService.Grant(player, row)
	local level = playerLevel(player)
	local luck = WeaponModifiers.LuckFrom(0, tonumber(player:GetAttribute("Rebirths")) or 0,
		tonumber(player:GetAttribute("MilestoneLuck")) or 0)
	return BossSwordFactory.build(row.poolKey, {
		sword = row.sword, rarity = row.rarity,
		rarityOdds = { { rarity = row.rarity, p = row.p } },
		level = level, slots = WeaponModifiers.SlotsOf(player), luck = luck,
	})
end

-- ---------------------------------------------------------------- loud rolls
-- Every freshly rolled sword's prefixes pass through here once the player owns it (the spin
-- station after the tokens are paid, the Relic Blacksmith after the gold is). A chase (each level
-- bracket's named prize, WeaponModifiers.Chases) is added to ChasesFound, which lifts its "??" on
-- this player's odds displays, and toasts the WHOLE server: the Lemonade with the biggest banner
-- (and LemonadeFound, as before), every other chase with its own. The bracket's top-tier rung
-- ("Great") gets a one-line server shout. `delay` holds the shout until the roller's own reveal has
-- landed, so nobody learns it from the chat first. A "Nice" roll is the roller's own stamp
-- (SpinPopup), not a broadcast.
local notifyRemote = nil
function SpinService.CreditPrefixes(player, mods, swordName, delay)
	if typeof(mods) ~= "table" then return end
	for _, mod in ipairs(mods) do
		local tag = mod.tag
		local chase = WeaponModifiers.ChaseByName[mod.name]
		local message, kind = nil, nil
		if chase and (mod.chase or tag == "Chase" or tag == "Lemonade") then
			local first = not WeaponModifiers.ChaseFound(player, chase.name)
			if first then
				local list = player:GetAttribute("ChasesFound")
				list = (typeof(list) == "string" and list ~= "") and (list .. "," .. chase.name) or chase.name
				player:SetAttribute("ChasesFound", list)
			end
			if chase == WeaponModifiers.Chase then
				player:SetAttribute("LemonadeFound", (tonumber(player:GetAttribute("LemonadeFound")) or 0) + 1)
				message = string.format("\u{1F34B} LEMONADE! %s squeezed the Lemonade prefix (%s): %s (%s)%s",
					player.DisplayName, chase.desc, tostring(swordName), WeaponModifiers.OneInText(mod.p or 0),
					first and " -- their first ever!" or "")
				kind = "lemonade"
			else
				message = string.format("CHASE! %s found the %s prefix (%s, %s): %s (%s)%s", player.DisplayName,
					chase.name, chase.desc, chase.flavor or "", tostring(swordName), WeaponModifiers.OneInText(mod.p or 0),
					first and " -- their first!" or "")
				kind = "chase"
			end
		elseif tag == "Great" then
			local rung = WeaponModifiers.Rungs[mod.tier or 0]
			message = string.format("%s rolled a %s prefix: %s (%s)", player.DisplayName,
				rung and rung.name or "top-tier", tostring(swordName), WeaponModifiers.OneInText(mod.p or 0))
			kind = "great"
		end
		if message then
			notifyRemote = notifyRemote or ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Notify")
			task.delay(math.max(tonumber(delay) or 0, 0), function()
				notifyRemote:FireAllClients(message, kind)
			end)
			print("[SpinService] " .. message)
		end
	end
end

-- ---------------------------------------------------------------- wiring
buildDepthTable()

local function bind(player)
	if player:GetAttribute("DataLoaded") then
		task.defer(onDataLoaded, player)
	end
	player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		if player:GetAttribute("DataLoaded") then onDataLoaded(player) end
	end)
	-- The default area follows the player's level too (a gate opening on level-up).
	local stats = player:WaitForChild("leaderstats", 30)
	local lv = stats and stats:WaitForChild("Level", 30)
	if lv then
		lv.Changed:Connect(function()
			if PlayerDataService.IsReady(player) then mirror(player) end
		end)
	end
end
Players.PlayerAdded:Connect(function(p) task.spawn(bind, p) end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(bind, p) end

do
	local parts = {}
	for _, zone in ipairs(SpinPools.Order) do
		local row = depthTable[zone]
		if row then
			table.insert(parts, string.format("%s mid Lv%d deep Lv%d boss Lv%s", zone, row.mid, row.deep,
				tostring(row.bossLevel or "-")))
		end
	end
	print("[SpinService] Spin pools live, depth camps: " .. table.concat(parts, "; "))
end

return SpinService
