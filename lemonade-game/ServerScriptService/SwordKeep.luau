--// SwordKeep  (carried relics survive death, respawn and an early leave)
-- The engine REPLACES a player's Backpack on every spawn: the old one and everything in it is
-- destroyed, and a fresh one is filled from StarterPack. Nothing put the relics back, so every
-- death deleted every carried sword, and the next autosave made the loss permanent (2026-09-24
-- playtest: persistence-2, inventory-4, merchant-1, drops-pickup-1, spin-11, vault-7). The load
-- path had the same hole the other way round: saved swords waited in a local list for the first
-- spawn, so a player who left before spawning saved none of them (persistence-1).
--
-- The keep is a server-only folder per player (ServerStorage, never replicated). Relics wait in it
-- whenever the player has no live Backpack to hold them:
--   * at load, before the first character exists;
--   * from the moment the character dies (or is removed) until the next one spawns -- including
--     anything granted in that window (a purchase, a vault withdrawal, a trade, a spin);
-- and are moved into the new Backpack as soon as the character spawns. The save reads the keep
-- as well as the Backpack and the character, so a relic in it is never lost.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local SwordKeep = {}

local ROOT_NAME = "SwordKeep"
local tracked = setmetatable({}, { __mode = "k" })

local function root(): Folder
	local r = ServerStorage:FindFirstChild(ROOT_NAME)
	if not r then
		r = Instance.new("Folder")
		r.Name = ROOT_NAME
		r.Parent = ServerStorage
	end
	return r
end

-- One folder per player SESSION (keyed by the Player object, not the UserId), so a quick rejoin to
-- the same server can never find, or have cleaned up, the previous session's folder.
local folders = setmetatable({}, { __mode = "k" })
local serial = 0
local function folderFor(player: Player, create: boolean?): Folder?
	local f = folders[player]
	if f and f.Parent == nil then f = nil end
	if not f and create then
		serial += 1
		f = Instance.new("Folder")
		f.Name = string.format("%d_%d", player.UserId, serial)
		f.Parent = root()
		folders[player] = f
	end
	return f
end

local function isRelic(tool: Instance): boolean
	return tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true
end

-- Park one relic in the keep.
function SwordKeep.hold(player: Player, tool: Tool)
	local f = folderFor(player, true)
	if f and tool.Parent ~= f then
		tool.Parent = f
	end
end

-- Every relic waiting in the keep (the save reads these).
function SwordKeep.held(player: Player): { Tool }
	local out = {}
	local f = folderFor(player, false)
	for _, t in ipairs(f and f:GetChildren() or {}) do
		if isRelic(t) then table.insert(out, t) end
	end
	return out
end

-- Move every held relic into the player's current Backpack.
function SwordKeep.release(player: Player)
	local bag = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not bag or not humanoid or humanoid.Health <= 0 then
		return -- no live Backpack yet: they stay in the keep
	end
	for _, t in ipairs(SwordKeep.held(player)) do
		t.Parent = bag
	end
end

-- Sweep every relic the player is carrying into the keep.
local function sweep(player: Player, character: Model?)
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), character }) do
		if container then
			for _, t in ipairs(container:GetChildren()) do
				if isRelic(t) then SwordKeep.hold(player, t) end
			end
		end
	end
end

-- Install the death / respawn handling for one player. Idempotent.
function SwordKeep.track(player: Player)
	if tracked[player] then return end
	tracked[player] = true

	local function onCharacter(character: Model)
		-- The engine has just handed out a fresh Backpack; put the relics back once it is settled.
		task.defer(SwordKeep.release, player)
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
		if not humanoid then return end
		humanoid.Died:Once(function()
			-- Deferred so SwordDropSystem's own Died hook (the shatter roll, which moves a surviving
			-- equipped sword into the Backpack) has already run.
			task.defer(function()
				sweep(player, character)
				-- Anything granted while dead lands in the doomed Backpack or on the corpse: catch it.
				local bag = player:FindFirstChildOfClass("Backpack")
				local conns = {}
				local function catch(t: Instance)
					if isRelic(t) then SwordKeep.hold(player, t :: Tool) end
				end
				if bag then table.insert(conns, bag.ChildAdded:Connect(catch)) end
				table.insert(conns, character.ChildAdded:Connect(catch))
				-- Until the next character: then the keep empties into the new Backpack.
				player.CharacterAdded:Once(function()
					for _, c in ipairs(conns) do c:Disconnect() end
				end)
			end)
		end)
	end

	-- A character removed without dying (a reload, a teleport) loses its Backpack the same way.
	player.CharacterRemoving:Connect(function(character)
		sweep(player, character)
	end)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

-- Drop the player's keep once their last save has been written.
function SwordKeep.forget(player: Player)
	local f = folderFor(player, false)
	if f then f:Destroy() end
	folders[player] = nil
	tracked[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	-- Safety net only: PlayerDataService.Release calls forget() after its save. If that never runs
	-- (no profile loaded), drop this session's folder a minute later so it cannot leak.
	local f = folders[player]
	task.delay(60, function()
		if f and f.Parent then f:Destroy() end
	end)
end)

return SwordKeep
