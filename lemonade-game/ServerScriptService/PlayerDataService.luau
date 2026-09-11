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
	return lock ~= nil
		and lock.jobId ~= JOB_ID
		and (os.time() - (lock.time or 0)) < SaveConfig.LOCK_STALE_AFTER
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
		if ok and typeof(result) == "table" then
			record = result
		else
			warn(string.format("[PlayerDataService] load failed for %s (%s). "
				.. "Using safe defaults; saving disabled this session to avoid overwrite.",
				player.Name, tostring(result)))
			record = defaultData()
			record.__loadFailed = true
		end
	else
		record = memoryFallback[userId] or defaultData()
	end

	record.leaderstats = record.leaderstats or {}
	record.attributes = record.attributes or {}
	record.inventory = record.inventory or {}
	record.swords = record.swords or {}
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
		if v == nil then v = default end
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

	if data.isNew and not data.__loadFailed then
		InventoryService.GiveStarterItems(player)
	end

	profile.ready = true
	player:SetAttribute("DataLoaded", true)
end

-- ---------------------------------------------------------------- serialize
local function serializeSwords(player)
	local out = {}
	local equippedTool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true then
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
					out[#out + 1] = {
						name = tool.Name, attrs = attrs, color = color, material = material,
						equipped = (tool == equippedTool),
					}
				end
			end
		end
	end
	return out
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

	-- Guard the PlayerRemoving race: if InventorySystem has already wiped its cache,
	-- GetInventory returns {}. Only overwrite when the live snapshot has content, or
	-- when we never had any.
	local liveInv = InventoryService.GetInventory(player)
	if next(liveInv) ~= nil or next(data.inventory) == nil then
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

	local ok, err = retry(function()
		return store:UpdateAsync(keyFor(player.UserId), function(old)
			if old and lockHeldByOther(old.__lock) then
				return nil  -- another server owns it now; don't stomp
			end
			return payload
		end)
	end)
	if ok then
		profile.dirty = false
	else
		warn(string.format("[PlayerDataService] save failed for %s: %s", player.Name, tostring(err)))
	end
	return ok
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

return PlayerDataService
