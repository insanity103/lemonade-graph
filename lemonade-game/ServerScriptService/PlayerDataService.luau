--// PlayerDataService  (per-player DataStore persistence: level, XP, gold, rebirth,
--   skill/attribute points, inventory stacks, and boss swords with their rolled mods)
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SaveConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SaveConfig"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local BossSwordFactory = require(script.Parent:WaitForChild("BossSwordFactory"))
local WeaponModifiers = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponModifiers"))
local SwordKeep = require(script.Parent:WaitForChild("SwordKeep"))

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
		-- reforgePity / reforgeFreeAt / reforgeBest / reforgeCount / reforgeTailPity / reforgeRecent
		-- belonged to the removed Reforge anvil. New profiles no longer get them; an old profile
		-- keeps its values untouched in the record (nothing reads them, nothing drops them).
		dropPity = 0,  -- drop credit owed: kills that paid nothing, each worth its own chance (DropRules)
		dropRarePity = 0,  -- drops since the last Rare or better (DropRules)
		dropKills = 0,  -- lifetime kills the drop system has rolled for: 0 means the next kill is the
		                -- profile's FIRST and is guaranteed a sword; under DropRules.OPENING_KILLS the
		                -- opening ramp applies (DropRules rule 5)
		bossFirstDrops = {},  -- [poolKey] = true once this boss has paid the profile its first sword
		                      -- (a boss's first kill always drops; the "claim a sword" quests read it)
		zoneDepth = {},  -- [zone] = { best = highest foe level beaten there, boss = true once its boss or
		                 -- warden fell }: how deep the player has pushed, the spin pool's depth step
		                 -- (SpinService). A save without it is rebuilt from level + bossFirstDrops.
		spinCount = 0,  -- lifetime spins at the town Spin Wheel (SpinSystem); older saves read as 0
		merchantPity = 0,  -- blacksmith purchases in a row below MerchantConfig.PITY_FLOOR
		merchantCount = 0,  -- lifetime blades bought from the Relic Blacksmith
		vaultSlots = 0,  -- vault shelves BOUGHT with gold (Config.VaultConfig owns the price ladder);
		                 -- the free shelf is SaveConfig.VAULT_CAPACITY and milestone shelves come
		                 -- from wealthRung, so this counts purchases only and nothing else
		wealthRung = 0,  -- highest Config.WealthLadder rung ever reached. Earned once, never lost:
		                 -- spending the fortune afterwards does not take the title or its perks back
		wealthBest = 0,  -- the highest FORTUNE (net worth in gold) this profile has ever held
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
	-- In Studio, a lock left by an earlier Studio session (a crash, a stopped test, a killed Studio)
	-- is always stale: Studio runs one session at a time. Without this, one crash locked the owner
	-- out of their own save for LOCK_STALE_AFTER (20 minutes). Live servers never take this branch.
	if RunService:IsStudio() and typeof(lock.jobId) == "string" and string.sub(lock.jobId, 1, 7) == "studio-" then
		return false
	end
	return lock.jobId ~= JOB_ID
		and (os.time() - (tonumber(lock.time) or 0)) < SaveConfig.LOCK_STALE_AFTER
end

-- [userId] = true while this server is still writing a leaving session's save. A rejoin to the same
-- server waits for it: the lock check cannot tell the two sessions apart (same JobId), so without
-- this a quick rejoin could load the record from before the leave-save landed (persistence-10).
local releasing = {}
local LOCK_WAIT_ATTEMPTS = 6 -- [TUNING] tries at a profile another server still holds
local LOCK_WAIT_SECONDS = 5  -- [TUNING] between them: ~25 s for that server's leave-save to land

local function kick(player, message)
	pcall(function() player:Kick(message) end)
end

local function lockHeldByThisServer(lock)
	return typeof(lock) == "table" and lock.jobId == JOB_ID
end

-- ---------------------------------------------------------------- load
function PlayerDataService.Load(player)
	local userId = player.UserId
	local record

	if store then
		local waited = 0
		while releasing[userId] and waited < 30 do
			task.wait(0.5)
			waited += 0.5
		end
		-- Claim the profile. A lock held by another live server is WAITED out (it is normally that
		-- server's leave-save still landing) rather than failing on the first try; if it never
		-- frees, or the DataStore itself is failing, the player is sent back to rejoin instead of
		-- playing a blank level-1 profile that silently never saves (persistence-5).
		local reason = "unknown"
		for attempt = 1, LOCK_WAIT_ATTEMPTS do
			local blocked = false
			local ok, result = retry(function()
				return store:UpdateAsync(keyFor(userId), function(old)
					old = old or defaultData()
					if lockHeldByOther(old.__lock) then
						blocked = true
						return nil  -- another live server owns this profile; don't claim it
					end
					blocked = false
					old.__lock = { jobId = JOB_ID, time = os.time() }
					return old
				end)
			end)
			if ok and typeof(result) == "table" and lockHeldByThisServer(result.__lock) then
				record = result
				break
			end
			if not ok then
				reason = "DataStore error: " .. tostring(result)
				break
			end
			reason = if blocked then "profile is still open on another server" else "unexpected load result"
			if attempt < LOCK_WAIT_ATTEMPTS and player.Parent then
				task.wait(LOCK_WAIT_SECONDS)
			else
				break
			end
		end
		if not record then
			warn(string.format("[PlayerDataService] load failed for %s (%s); asking them to rejoin.", player.Name, reason))
			record = defaultData()
			record.__loadFailed = true
			task.defer(kick, player, "Your progress could not be loaded yet (it is still being saved on another server). Please rejoin in a minute.")
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
	-- vaultSlots / wealthRung / wealthBest were added with the paid vault and the wealth ladder;
	-- a profile saved before them simply arrives with none and is backfilled to 0 here, exactly
	-- the way every earlier counter was. Nothing is renamed and nothing is dropped.
	for _, key in ipairs({ "dropPity", "dropRarePity", "vaultSlots", "wealthRung", "wealthBest" }) do
		if typeof(record[key]) ~= "number" then record[key] = 0 end
	end
	-- One prefix slot per sword (WeaponModifiers.BASE_SLOTS; more are a player unlock). A vault
	-- entry saved before the rework can carry a Blessed slot and up to five prefixes. Such an entry
	-- is rebuilt here exactly as a withdrawal would rebuild it (BossSwordFactory.rebuild: every name
	-- kept in StoredPrefixes, only the owner's strongest N active, stats and name re-derived from
	-- those) and stored back, so its card, its rating and the sword you withdraw all agree. An entry
	-- already carrying StoredPrefixes is rebuilt too: that heals entries an older version of this
	-- loop collapsed without re-deriving their stats or name. One-prefix entries are left untouched.
	local slots = WeaponModifiers.ClampSlots(record.attributes.PrefixSlots)
	for _, entry in ipairs(record.vault) do
		local attrs = typeof(entry) == "table" and typeof(entry.attrs) == "table" and entry.attrs or nil
		if attrs then
			local stored = typeof(attrs.StoredPrefixes) == "string" and attrs.StoredPrefixes ~= ""
			local source = stored and attrs.StoredPrefixes or attrs.Prefixes
			local stale = stored
				or (attrs.ExtraSlot == true and typeof(entry.name) == "string" and string.find(entry.name, "Blessed", 1, true) ~= nil)
			if not stale and typeof(source) == "string" then
				local active = WeaponModifiers.CollapsePrefixes(source, slots)
				local names = {}
				for _, m in ipairs(active) do table.insert(names, m.name) end
				stale = table.concat(names, ", ") ~= attrs.Prefixes
			end
			if stale then
				local tool = BossSwordFactory.rebuild(entry, slots)
				if tool then
					local fresh = PlayerDataService.SerializeTool(tool, entry.equipped == true)
					tool:Destroy()
					entry.name = fresh.name
					entry.attrs = fresh.attrs
					entry.color = fresh.color or entry.color
					entry.material = fresh.material or entry.material
				end
			end
		end
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

	-- Rebuild the saved boss swords now and park them in the SwordKeep until the character has a
	-- live Backpack (a Backpack populated before the first spawn is replaced by the engine). They
	-- wait in the keep rather than in a local list, so the save still sees them if the player leaves
	-- before spawning (2026-09-24 playtest, persistence-1), and the keep also carries every relic
	-- through each later death and respawn (see SwordKeep).
	SwordKeep.track(player)
	for _, entry in ipairs(data.swords) do
		local tool = BossSwordFactory.rebuild(entry, WeaponModifiers.SlotsOf(player))
		if tool then SwordKeep.hold(player, tool) end
	end
	task.defer(SwordKeep.release, player)

	if data.isNew == true then
		InventoryService.GiveStarterItems(player)
	end

	-- A prefix slot unlock (the upgrade shop raises PrefixSlots) wakes the next stored prefix on
	-- every sword the player is carrying; vault swords pick it up when they are withdrawn.
	player:GetAttributeChangedSignal("PrefixSlots"):Connect(function()
		local slotsNow = WeaponModifiers.SlotsOf(player)
		for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
			for _, tool in ipairs(container and container:GetChildren() or {}) do
				BossSwordFactory.applySlots(tool, slotsNow)
			end
		end
	end)

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
	-- Everything the player owns as a Tool: the Backpack, the character, and the SwordKeep (relics
	-- waiting out a death or the first spawn).
	local tools = SwordKeep.held(player)
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				table.insert(tools, tool)
			end
		end
	end
	-- One starter only. Before the first spawn the engine puts a stock starter in the Backpack while
	-- the saved one (possibly struck with stats) waits in the keep; the keep is listed first, so the
	-- saved starter is the one kept. SwordDropSystem makes the same one-starter rule on spawn.
	local haveStarter = false
	for _, tool in ipairs(tools) do
		-- GuiShowcaseOnly: a loaner relic a Studio-only capture stage put in the backpack;
		-- it must never reach the profile.
		if tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true
			and tool:GetAttribute("GuiShowcaseOnly") ~= true then
			local starter = tool:GetAttribute("Starter") == true
			if not (starter and haveStarter) then
				out[#out + 1] = PlayerDataService.SerializeTool(tool, tool == equippedTool)
			end
			haveStarter = haveStarter or starter
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

-- True once the profile has loaded and been applied (GetField answers nil before that, and
-- also for a field an older save never had, so callers that must tell the two apart ask this).
function PlayerDataService.IsReady(player)
	local profile = profiles[player]
	return profile ~= nil and profile.ready == true
end

-- Small persisted counters (drop pity and the like). nil until the profile is applied.
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
-- A Studio capture stage (GuiShowcase) lends relics, tops up gold and fires real rolls so the
-- camera sees the real code path. None of that is the player's: while the showcase attribute is
-- set in Studio, saving is refused outright, so a staged session can never reach the DataStore.
-- Live servers never take this branch (RunService:IsStudio() is false there).
local function showcaseActive(): boolean
	if not RunService:IsStudio() then return false end
	local name = workspace:GetAttribute("GuiShowcase")
	return typeof(name) == "string" and name ~= ""
end

local warnedShowcase = false

function PlayerDataService.Save(player, releaseLock)
	local profile = profiles[player]
	if not profile then return false end

	if showcaseActive() then
		if not warnedShowcase then
			warnedShowcase = true
			warn("[PlayerDataService] GuiShowcase is staging in Studio: saves are refused for this session")
		end
		-- The staged data never goes in, but the session lock this server took at load must still come
		-- off when the player leaves. Refusing that too left the lock on the record, and every Play for
		-- the next LOCK_STALE_AFTER seconds loaded "safe defaults" with saving disabled (2026-09-24).
		if releaseLock and store and not profile.data.__loadFailed then
			pcall(function()
				store:UpdateAsync(keyFor(player.UserId), function(old)
					if typeof(old) == "table" and lockHeldByThisServer(old.__lock) then
						old.__lock = nil
						return old
					end
					return nil
				end)
			end)
		end
		return false
	end

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
			-- An ordinary save (a trade's, the vault's, a retry) that lands after the player's
			-- leave-save must not write: it would put back stale data AND the session lock the
			-- leave-save just released (trade-6, vault-2, R108).
			if not releaseLock and profiles[player] ~= profile then
				return nil
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
		-- A failed save is tried again instead of dropped (persistence-15). This is also what keeps a
		-- trade from leaving a sword on both accounts: the two post-trade saves are separate writes,
		-- and a failed one now lands within seconds rather than at the next 120 s autosave.
		profile.dirty = true
		if not releaseLock and not profile.retryPending then
			profile.retryPending = true
			task.delay(10, function()
				profile.retryPending = false
				if profiles[player] == profile and player.Parent then
					PlayerDataService.Save(player)
				end
			end)
		end
	end
	return saved
end

function PlayerDataService.Release(player)
	releasing[player.UserId] = true
	local profile = profiles[player]
	local saved = PlayerDataService.Save(player, true)
	-- The leave-save is the last chance: try it again a couple of times if the DataStore refused it
	-- (a save refused on purpose -- a failed load, a Studio capture -- is not retried).
	local tries = 1
	while not saved and tries < 3 and profile and not profile.data.__loadFailed and not showcaseActive() do
		task.wait(3)
		tries += 1
		saved = PlayerDataService.Save(player, true)
	end
	profiles[player] = nil
	SwordKeep.forget(player)
	releasing[player.UserId] = nil
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
-- Setup failed after the profile was claimed (Apply threw). Hand the lock back WITHOUT saving (the
-- half-applied state must not overwrite the real record) and send the player back to rejoin, instead
-- of leaving them in a blank session that never saves while the lock sits on their record
-- (persistence-4).
function PlayerDataService.Abandon(player, message)
	local profile = profiles[player]
	profiles[player] = nil
	if store and profile and not profile.data.__loadFailed then
		pcall(function()
			store:UpdateAsync(keyFor(player.UserId), function(old)
				if typeof(old) == "table" and lockHeldByThisServer(old.__lock) then
					old.__lock = nil
					return old
				end
				return nil
			end)
		end)
	end
	kick(player, message or "Something went wrong loading your progress. Please rejoin.")
end

function PlayerDataService.StartFallback(player)
	local data = defaultData()
	data.__loadFailed = true
	profiles[player] = { data = data, ready = false, dirty = false }
	PlayerDataService.Apply(player)
end

return PlayerDataService
