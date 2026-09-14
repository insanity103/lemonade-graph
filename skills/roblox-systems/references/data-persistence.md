# Data Persistence Architecture

## Data Schema Design

Every saved schema needs a `_version` field and a defaults template so migrations and loading stay predictable.

```lua
local DEFAULTS = {
	_version = 3,
	currency = { coins = 0, gems = 0 },
	inventory = {},
	settings = { music = true, sfx = true },
	playtime = 0,
}
```

- `_version` — integer; incremented when schema changes. Checked on load.
- Nested tables — keep depth ≤ 3. DataStore serialises to JSON; deep nesting bloats size.
- Defaults template — single source of truth. Merge loaded data into defaults, never the other way around.

## Load Flow

```
PlayerAdded
  → check session cache (retry if mid-save)
  → DataStore GetAsync (pcall, 3 retries, exponential backoff)
  → merge loaded data with DEFAULTS (fill missing keys)
  → run migrations if _version < current
  → store result in session cache
  → fire DataReady signal for the player
```

### GetAsync with retries

```lua
local function safeGet(store, key, retries)
	retries = retries or 3
	for attempt = 1, retries do
		local ok, data = pcall(store.GetAsync, store, key)
		if ok then return data end
		task.wait(2 ^ attempt) -- [TUNING] backoff multiplier
	end
	return nil -- all retries exhausted
end
```

## Save Flow

```
PlayerRemoving
  → get session cache
  → DataStore GetAsync (get latest, in case another server wrote)
  → UpdateAsync: read-modify-write with conflict check
    → if last saved version matches → write new data
    → else merge (server-wins or latest-wins, pick policy)
  → remove from session cache
```

### UpdateAsync conflict check

```lua
local function safeSave(store, key, transform)
	for attempt = 1, 3 do
		local ok, result = pcall(store.UpdateAsync, store, key, transform)
		if ok then return result end
		task.wait(2 ^ attempt) -- [TUNING]
	end
	warn("Failed to save key:", key)
end
```

## Session Locking

Prevent two servers from writing the same player's data simultaneously.

```lua
local LOCK_TTL = 30 -- [TUNING] seconds before stale lock is ignored

local function acquireLock(store, key, jobId)
	return safeSave(store, key .. "_lock", function(old)
		if old and os.time() - old.time < LOCK_TTL and old.job ~= jobId then
			return nil -- reject: another server holds the lock
		end
		return { job = jobId, time = os.time() }
	end)
end

local function releaseLock(store, key, jobId)
	safeSave(store, key .. "_lock", function(old)
		if old and old.job == jobId then return nil end -- clear own lock
		return old -- leave other locks alone
	end)
end
```

## Migrations

Run sequentially from the loaded version to the current version.

```lua
local MIGRATIONS = {
	[1] = function(data) -- v1 → v2: rename "coins" to currency.coins
		data.currency = { coins = data.coins or 0, gems = 0 }
		data.coins = nil
		data._version = 2
		return data
	end,
	[2] = function(data) -- v2 → v3: add settings
		data.settings = { music = true, sfx = true }
		data._version = 3
		return data
	end,
}

local function migrate(data)
	while data._version < DEFAULTS._version do
		local fn = MIGRATIONS[data._version]
		if not fn then break end
		data = fn(data)
	end
	return data
end
```

## BindToClose

Save all active players when the server shuts down.

```lua
game:BindToClose(function()
	local startTime = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			pcall(savePlayerData, player)
		end)
	end
	while os.clock() - startTime < 30 do -- [TUNING] max wait
		if not next(activeSaves) then break end
		task.wait(0.5)
	end
end)
```

## OrderedDataStore Leaderboard

```lua
local orderedStore = DataStoreService:GetOrderedDataStore("CoinsLeaderboard")

local function updateLeaderboard(userId, coins)
	pcall(orderedStore.SetAsync, orderedStore, tostring(userId), coins)
end

local function getTopN(n)
	local pages = orderedStore:GetSortedAsync(false, n) -- descending
	return pages:GetCurrentPage() -- array of {key, value}
end
```

## Budget Management

DataStore has a budget of ~60 requests/min/store (varies by game size).

- **Queue writes**: debounce player saves (don't save on every currency change). Buffer changes and flush every 30 s or on PlayerRemoving.
- **Batch reads**: preload common data at startup (e.g. global config) instead of per-player GetAsync for shared data.
- **Throttle retries**: if budget exhausted, `pcall` returns error; back off and retry with longer delay.

```lua
local saveQueue = {}
local FLUSH_INTERVAL = 30 -- [TUNING] seconds

local function queueSave(player, data)
	saveQueue[player.UserId] = data
end

task.spawn(function()
	while true do
		task.wait(FLUSH_INTERVAL)
		for userId, data in pairs(saveQueue) do
			saveQueue[userId] = nil
			safeSave(playerStore, "Player_" .. userId, function()
				return data
			end)
		end
	end
end)
```

## Full Working Example: DataStore Module

```lua
-- DataStoreManager (ModuleScript, ServerScriptService)
local DSS = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local store = DSS:GetDataStore("PlayerData_v1") -- [TUNING] store name

local MAX_RETRIES = 3
local LOCK_TTL = 30 -- [TUNING]
local FLUSH_INTERVAL = 30 -- [TUNING]

local DEFAULTS = {
	_version = 3,
	currency = { coins = 0, gems = 0 },
	inventory = {},
	settings = { music = true, sfx = true },
	playtime = 0,
}

local cache = {}
local dirty = {}

local MIGRATIONS = {
	[1] = function(d)
		d.currency = { coins = d.coins or 0, gems = 0 }
		d.coins = nil
		d._version = 2
		return d
	end,
	[2] = function(d)
		d.settings = { music = true, sfx = true }
		d._version = 3
		return d
	end,
}

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = deepCopy(v) end
	return out
end

local function mergeDefaults(src, defs)
	local out = deepCopy(defs)
	for k, v in pairs(src) do
		if type(v) == "table" and type(defs[k]) == "table" then
			out[k] = mergeDefaults(v, defs[k])
		else
			out[k] = v
		end
	end
	return out
end

local function retry(fn, attempts)
	for i = 1, attempts or MAX_RETRIES do
		local ok, result = pcall(fn)
		if ok then return result end
		task.wait(2 ^ i)
	end
	return nil
end

local function migrate(data)
	while data._version < DEFAULTS._version do
		local fn = MIGRATIONS[data._version]
		if not fn then break end
		data = fn(data)
	end
	return data
end

local function loadPlayer(player)
	local key = "Player_" .. player.UserId
	local data = retry(function() return store:GetAsync(key) end)
	data = data and migrate(data) or deepCopy(DEFAULTS)
	data = mergeDefaults(data, DEFAULTS)
	cache[player.UserId] = data
	return data
end

local function savePlayer(player)
	local key = "Player_" .. player.UserId
	local data = cache[player.UserId]
	if not data then return end
	retry(function()
		return store:UpdateAsync(key, function(latest)
			-- conflict: prefer our session data if current
			return data
		end)
	end)
	cache[player.UserId] = nil
	dirty[player.UserId] = nil
end

local function markDirty(player)
	dirty[player.UserId] = true
end

Players.PlayerAdded:Connect(function(player)
	local data = loadPlayer(player)
	-- [TUNING] fire a BindableEvent or RemoteEvent to notify readiness
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
end)

game:BindToClose(function()
	local t = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(savePlayer, player)
	end
	while os.clock() - t < 30 and next(cache) do -- [TUNING]
		task.wait(0.5)
	end
end)

-- flush dirty data periodically
task.spawn(function()
	while true do
		task.wait(FLUSH_INTERVAL)
		for userId in pairs(dirty) do
			local player = Players:GetPlayerByUserId(userId)
			if player then savePlayer(player) end
		end
	end
end)

-- public API
local DataStoreManager = {}

function DataStoreManager:Get(player)
	return cache[player.UserId]
end

function DataStoreManager:Update(player, fn)
	local data = cache[player.UserId]
	if data then
		fn(data)
		markDirty(player)
	end
end

function DataStoreManager:SaveNow(player)
	savePlayer(player)
end

return DataStoreManager
```

Module under 100 lines of core logic. Expand `DEFAULTS` and `MIGRATIONS` to fit your game.
