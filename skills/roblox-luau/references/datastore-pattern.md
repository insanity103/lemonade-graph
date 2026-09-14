# DataStore Persistence Patterns

## Core Operations with Retry

```lua
local DataStoreService = game:GetService("DataStoreService")
local ds = DataStoreService:GetDataStore("PlayerData_v1")

local MAX_RETRIES = 3      -- [TUNING]
local BASE_DELAY  = 1      -- [TUNING] seconds

local function retryAsync(fn, ...)
    local args = {...}
    for attempt = 1, MAX_RETRIES do
        local ok, result = pcall(function()
            return fn(ds, table.unpack(args))
        end)
        if ok then return true, result end
        warn(`DataStore attempt {attempt} failed: {result}`)
        if attempt < MAX_RETRIES then
            task.wait(BASE_DELAY * (2 ^ (attempt - 1))) -- exponential backoff
        end
    end
    return false, nil
end

-- Usage:
-- local ok, data = retryAsync(ds.GetAsync, "Player_123")
-- local ok, _   = retryAsync(ds.SetAsync, "Player_123", newData)
-- local ok, _   = retryAsync(ds.UpdateAsync, "Player_123", transformFn)
```

---

## Session Locking (Prevents Data Loss from Multi-Server)

```lua
local LOCK_TTL = 300 -- [TUNING] 5 minutes, must outlast longest possible action

local function acquireLock(key: string, jobId: string): boolean
    local ok, existing = retryAsync(ds.GetAsync, key .. "_lock")
    if ok and existing and existing ~= jobId then
        local age = os.time() - (existing.time or 0)
        if age < LOCK_TTL then return false end -- lock still held
    end
    local locked = retryAsync(ds.SetAsync, key .. "_lock", { job = jobId, time = os.time() })
    return locked
end

local function releaseLock(key: string)
    retryAsync(ds.RemoveAsync, key .. "_lock")
end

-- Use UpdateAsync for atomic read-modify-write when possible
```

---

## Data Schema Versioning

```lua
local CURRENT_VERSION = 2

local DEFAULTS = {
    version = CURRENT_VERSION,
    cash    = 0,
    level   = 1,
    inventory = {},
    rebirths  = 0,
}

-- Migration functions: one per version bump
local migrations = {
    [1] = function(data) -- v1 → v2
        data.rebirths = data.rebirths or 0
        data.version = 2
        return data
    end,
    -- [2] = function(data) ... end,
}

local function migrate(data: {[string]: any}): {[string]: any}
    for v = (data.version or 1), CURRENT_VERSION - 1 do
        if migrations[v] then
            data = migrations[v](data)
        end
    end
    data.version = CURRENT_VERSION
    return data
end

local function loadData(key: string): {[string]: any}?
    local ok, data = retryAsync(ds.GetAsync, key)
    if not ok then return nil end
    if data then
        data = migrate(data)
    else
        data = table.clone(DEFAULTS)
    end
    return data
end
```

---

## Memory Cache Pattern

```lua
local cache: {[number]: {[string]: any}} = {} -- keyed by userId

local function getPlayerData(player: Player): {[string]: any}
    if cache[player.UserId] then return cache[player.UserId] end
    local data = loadData("Player_" .. player.UserId)
    if not data then data = table.clone(DEFAULTS) end
    cache[player.UserId] = data
    return data
end

local function savePlayerData(player: Player)
    local data = cache[player.UserId]
    if not data then return end
    local ok = retryAsync(ds.SetAsync, "Player_" .. player.UserId, data)
    if not ok then
        warn(`Failed to save data for {player.Name}`)
    end
end
```

---

## Player Data Lifecycle

```lua
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    local data = getPlayerData(player) -- loads into cache

    -- Set up leaderstats
    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"
    ls.Parent = player

    local cash = Instance.new("IntValue")
    cash.Name = "Cash"
    cash.Value = data.cash
    cash.Parent = ls

    -- Sync cache back on change
    cash.Changed:Connect(function(newVal)
        data.cash = newVal
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    savePlayerData(player)
    cache[player.UserId] = nil
end)

game:BindToClose(function()
    -- Iterate all players and save with pcall
    for _, player in Players:GetPlayers() do
        pcall(function()
            savePlayerData(player)
        end)
    end
end)
```

---

## OrderedDataStore for Leaderboards

```lua
local ordered = DataStoreService:GetOrderedDataStore("CashLeaderboard")

local function updateLeaderboard(player: Player, cash: number)
    local ok = retryAsync(ordered.SetAsync, tostring(player.UserId), cash)
    if not ok then warn("Leaderboard update failed for " .. player.Name) end
end

-- Query top 10
local function getTopPlayers(count: number): {any}
    local ok, pages = retryAsync(ordered.GetSortedAsync, false, count)
    if not ok then return {} end
    local results = {}
    for _, entry in ipairs(pages:GetCurrentPage()) do
        table.insert(results, { userId = tonumber(entry.key), cash = entry.value })
    end
    return results
end
```

---

## Budget Awareness

- **60 requests/min** per game server per store (GetAsync, SetAsync, UpdateAsync).
- `GetSortedAsync` costs **1 request per call** (returns up to 100 pages).
- `OnUpdate` subscriptions are **free** (event-driven).
- Spread saves over time; don't save all players at exactly the same instant.
- Use `UpdateAsync` instead of Get+Set to halve request count.

---

## Full Working Example: Complete Player Data Module (~80 lines)

```lua
-- ModuleScript: ServerScriptService/PlayerData
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ds = DataStoreService:GetDataStore("PlayerData_v1")
local ordered = DataStoreService:GetOrderedDataStore("CashBoard")

local MAX_RETRIES = 3     -- [TUNING]
local BASE_DELAY  = 1     -- [TUNING]

local DEFAULTS = { version = 1, cash = 0, level = 1, rebirths = 0 }
local cache: {[number]: {[string]: any}} = {}

local function retry(fn, ...)
    for i = 1, MAX_RETRIES do
        local ok, res = pcall(fn, ds, ...)
        if ok then return true, res end
        warn("DS retry " .. i .. ": " .. tostring(res))
        if i < MAX_RETRIES then task.wait(BASE_DELAY * 2^(i-1)) end
    end
    return false, nil
end

local function load(key: string)
    local ok, data = retry(ds.GetAsync, key)
    if not ok then return table.clone(DEFAULTS) end
    return if data then data else table.clone(DEFAULTS)
end

local function save(key: string, data)
    local ok = retry(ds.SetAsync, key, data)
    if not ok then warn("Save failed: " .. key) end
end

local function get(player: Player)
    if cache[player.UserId] then return cache[player.UserId] end
    cache[player.UserId] = load("P_" .. player.UserId)
    return cache[player.UserId]
end

local function flush(player: Player)
    local d = cache[player.UserId]
    if not d then return end
    save("P_" .. player.UserId, d)
    pcall(function() retry(ordered.SetAsync, tostring(player.UserId), d.cash) end)
end

-- Lifecycle
Players.PlayerAdded:Connect(function(plr)
    local d = get(plr)
    local ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = plr
    local c = Instance.new("IntValue"); c.Name = "Cash"; c.Value = d.cash; c.Parent = ls
    c.Changed:Connect(function(v) d.cash = v end)
end)

Players.PlayerRemoving:Connect(function(plr)
    flush(plr)
    cache[plr.UserId] = nil
end)

game:BindToClose(function()
    for _, p in Players:GetPlayers() do pcall(flush, p) end
end)

return { get = get, flush = flush }
```
