--// PlayerDataService  (per-player DataStore persistence: level, XP, gold, rebirth,
--   skill/attribute points, inventory stacks, and boss swords with their rolled mods)
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SaveConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SaveConfig"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local BossSwordFactory = require(script.Parent:WaitForChild("BossSwordFactory"))

local PlayerDataService = {}

local JOB_ID = (game.JobId ~= "" and game.JobId) or ("studio-" .. tostring(os.time()))

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(SaveConfig.DATASTORE_NAME)
	end)
	store = ok and result or nil
	if not store then
		warn("[PlayerDataService] DataStore unavailable -- in Studio, tick "
			.. "Game Settings > Security > Enable Studio Access to API Services. "
			.. "Running memory-only: progress will NOT carry between sessions.")
	end
end

local profiles = {}       -- [player]  = { data = <table>, ready = bool, dirty = bool }
local memoryFallback = {}  -- [userId]  = <data>   (only when `store` is nil)

local function keyFor(userId)
	return SaveConfig.KEY_PREFIX .. tostring(userId)
end

local function defaultData()
	local data = {
		version = SaveConfig.SCHEMA_VERSION,
		leaderstats = {}, attributes = {}, inventory = {}, swords = {},
		vault = {},  -- boss swords stored with the Vaultkeeper (same entry shape as `swords`)
		reforgePity = 0,  -- consecutive reforges that did not improve the sword (ReforgeSystem)
		reforgeFreeAt = 0,  -- os.time() when the next free daily reforge unlocks
		reforgeBest = 0,  -- best rating ever produced by a reforge
		reforgeCount = 0,  -- lifetime reforges
		isNew = true,
	}
	for name, default in pairs(SaveConfig.LEADERSTATS) do data.leaderstats[name] = default end
	for name, default in pairs(SaveConfig.ATTRIBUTES) do data.attributes[name] = default end
	return data
end

local function retry(fn)
	local attempt, delayS = 0, 1
	while true do
		attempt += 1
		local ok, result = pcall(fn)
		if ok then return true, result end
		if attempt >= SaveConfig.MAX_RETRIES then return false, result end
		task.wait(delayS)
		delayS = math.min(delayS * 2, 8)
	end
end

local function lockHeldByOther(lock)
	if typeof(lock) ~= "table" then
		return false
	end
	return lock.jobId ~= JOB_ID
		and (os.time() - (tonumber(lock.time) or 0)) < SaveConfig.LOCK_STALE_AFTER
end

local function lockHeldByThisServer(lock)
	return typeof(lock) == "table" and lock.jobId == JOB_ID
end

-- ---------------------------------------------------------------- load
function PlayerDataService.Load(player)
	local userId = player.UserId
	local record

	if store then
		local ok, result = retry(function()
			return store:UpdateAsync(keyFor(userId), function(old)
				old = old or defaultData()
				if lockHeldByOther(old.__lock) then
					return nil  -- another live server owns this profile; don't claim it
				end
				old.__lock = { jobId = JOB_ID, time = os.time() }
				return old
			end)
		end)
		if ok and typeof(result) == "table" and lockHeldByThisServer(result.__lock) then
			record = result
		else
			local resultLock = typeof(result) == "table" and result.__lock or nil
			local reason = lockHeldByOther(resultLock) and "profile is active in another server" or tostring(result)
			warn(string.format("[PlayerDataService] load failed for %s (%s). "
				.. "Using safe defaults; saving disabled this session to avoid overwrite.", player.Name, reason))
			record = defaultData()
			record.__loadFailed = true
		end
	else
		record = memoryFallback[userId] or defaultData()
	end

	record.leaderstats = typeof(record.leaderstats) == "table" and record.leaderstats or {}
	record.attributes = typeof(record.attributes) == "table" and record.attributes or {}
	record.inventory = typeof(record.inventory) == "table" and record.inventory or {}
	record.swords = typeof(record.swords) == "table" and record.swords or {}

	-- Backfill any new leaderstat or attribute keys that didn't exist when
	-- this record was last saved. Existing values are preserved.
	for name, default in pairs(SaveConfig.LEADERSTATS) do
		if record.leaderstats[name] == nil then
			record.leaderstats[name] = default
		end
	end
	for name, default in pairs(SaveConfig.ATTRIBUTES) do
		if record.attributes[name] == nil then
			record.attributes[name] = default
		end
	end
	if typeof(record.vault) ~= "table" then
		record.vault = {}
	end
	for _, key in ipairs({ "reforgePity", "reforgeFreeAt", "reforgeBest", "reforgeCount" }) do
		if typeof(record[key]) ~= "number" then record[key] = 0 end
	end
	if not record.version or record.version < SaveConfig.SCHEMA_VERSION then
		record.version = SaveConfig.SCHEMA_VERSION
	end

	profiles[player] = { data = record, ready = false, dirty = false }
	return record
end

-- ---------------------------------------------------------------- apply
function PlayerDataService.Apply(player)
	local profile = profiles[player]
	if not profile then return end
	local data = profile.data

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	for name, default in pairs(SaveConfig.LEADERSTATS) do
		local iv = leaderstats:FindFirstChild(name)
		if not iv then
			iv = Instance.new("IntValue")
			iv.Name = name
			iv.Parent = leaderstats
		end
		iv.Value = tonumber(data.leaderstats[name]) or default
	end

	for name, default in pairs(SaveConfig.ATTRIBUTES) do
		local v = data.attributes[name]
		if typeof(v) ~= typeof(default) then v = default end
		player:SetAttribute(name, v)
	end
	player:SetAttribute("Rebirths", tonumber(data.leaderstats.Rebirths) or 0)

	InventoryService.LoadPlayer(player, data.inventory)

	-- Rebuild the saved boss swords now, but only drop them into the Backpack once the
	-- character has spawned. A Backpack populated before the first spawn gets replaced
	-- by the engine, which was silently eating restored swords.
	local rebuiltSwords = {}
	for _, entry in ipairs(data.swords) do
		local tool = BossSwordFactory.rebuild(entry)
		if tool then rebuiltSwords[#rebuiltSwords + 1] = tool end
	end
	local function giveSwords()
		local bag = player:FindFirstChildOfClass("Backpack")
		if not bag then return end
		for _, tool in ipairs(rebuiltSwords) do
			if tool.Parent == nil then
				tool.Parent = bag
			end
		end
	end
	if #rebuiltSwords > 0 then
		if player.Character then
			task.defer(giveSwords)
		else
			player.CharacterAdded:Once(function()
				task.defer(giveSwords)
			end)
		end
	end

	if data.isNew == true then
		InventoryService.GiveStarterItems(player)
	end

	profile.ready = true
	player:SetAttribute("DataLoaded", true)
end

-- ---------------------------------------------------------------- serialize
-- One boss sword Tool as a save entry (the shape BossSwordFactory.rebuild accepts).
function PlayerDataService.SerializeTool(tool, equipped)
	local attrs = {}
	for _, key in ipairs(SaveConfig.SWORD_ATTRS) do
		attrs[key] = tool:GetAttribute(key)
	end
	local handle = tool:FindFirstChild("Handle")
	local color, material
	if handle then
		color = { handle.Color.R, handle.Color.G, handle.Color.B }
		material = handle.Material.Name
	end
	return { name = tool.Name, attrs = attrs, color = color, material = material, equipped = equipped == true }
end

local function serializeSwords(player)
	local out = {}
	local equippedTool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true then
					out[#out + 1] = PlayerDataService.SerializeTool(tool, tool == equippedTool)
				end
			end
		end
	end
	return out
end

-- The vault lives only in the profile data (never as Tools), so VaultSystem edits it in place.
function PlayerDataService.GetVault(player)
	local profile = profiles[player]
	if not profile or not profile.ready then return nil end
	return profile.data.vault
end

-- Small persisted counters (reforge pity and the like). nil until the profile is applied.
function PlayerDataService.GetField(player, key)
	local profile = profiles[player]
	if not profile or not profile.ready then return nil end
	return profile.data[key]
end

function PlayerDataService.SetField(player, key, value)
	local profile = profiles[player]
	if not profile or not profile.ready then return end
	profile.data[key] = value
	profile.dirty = true
end

function PlayerDataService.MarkDirty(player)
	local profile = profiles[player]
	if profile then profile.dirty = true end
end

function PlayerDataService.Serialize(player)
	local profile = profiles[player]
	if not profile then return nil end
	if not profile.ready then return profile.data end  -- never applied: keep what we loaded

	local data = profile.data
	local leaderstats = player:FindFirstChild("leaderstats")
	for name in pairs(SaveConfig.LEADERSTATS) do
		local iv = leaderstats and leaderstats:FindFirstChild(name)
		if iv then data.leaderstats[name] = iv.Value end
	end
	for name in pairs(SaveConfig.ATTRIBUTES) do
		local v = player:GetAttribute(name)
		if v ~= nil then data.attributes[name] = v end
	end

	-- Only serialize a live inventory cache. This preserves a genuinely empty
	-- inventory while still avoiding a late PlayerRemoving cleanup race.
	local liveInv = InventoryService.GetInventory(player)
	if InventoryService.HasLoaded(player) then
		data.inventory = liveInv
	end

	data.swords = serializeSwords(player)
	data.isNew = false
	data.version = SaveConfig.SCHEMA_VERSION
	return data
end

-- ---------------------------------------------------------------- save / release
function PlayerDataService.Save(player, releaseLock)
	local profile = profiles[player]
	if not profile then return false end

	local data = PlayerDataService.Serialize(player)
	if not data or data.__loadFailed then return false end

	if not store then
		memoryFallback[player.UserId] = data
		profile.dirty = false
		return true
	end

	local payload = {}
	for k, v in pairs(data) do
		if k ~= "__lock" and k ~= "__loadFailed" then payload[k] = v end
	end
	if not releaseLock then
		payload.__lock = { jobId = JOB_ID, time = os.time() }
	end

	local ok, result = retry(function()
		return store:UpdateAsync(keyFor(player.UserId), function(old)
			if old and lockHeldByOther(old.__lock) then
				return nil  -- another server owns it now; don't stomp
			end
			return payload
		end)
	end)

	local saved = ok and typeof(result) == "table"
	if saved then
		if releaseLock then
			saved = result.__lock == nil
		else
			saved = lockHeldByThisServer(result.__lock)
		end
	end
	if saved then
		profile.dirty = false
	else
		warn(string.format("[PlayerDataService] save failed for %s: %s", player.Name, tostring(result)))
	end
	return saved
end

function PlayerDataService.Release(player)
	PlayerDataService.Save(player, true)
	profiles[player] = nil
end

function PlayerDataService.SaveAll(releaseLock)
	for _, player in ipairs(Players:GetPlayers()) do
		if profiles[player] then
			PlayerDataService.Save(player, releaseLock)
		end
	end
end

function PlayerDataService.IsReady(player)
	local p = profiles[player]
	return p ~= nil and p.ready
end

-- Used only if the lifecycle wrapper itself throws. It gives the player a fully
-- initialized, memory-only profile instead of leaving them without starter items.
function PlayerDataService.StartFallback(player)
	local data = defaultData()
	data.__loadFailed = true
	profiles[player] = { data = data, ready = false, dirty = false }
	PlayerDataService.Apply(player)
end

return PlayerDataService
