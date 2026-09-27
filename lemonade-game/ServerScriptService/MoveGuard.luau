--// MoveGuard  (the server's own record of where each player has been)
-- A player's HumanoidRootPart is owned by their client, so a hacked client can put it anywhere.
-- Every hit test reads that position, so a client that hops next to an enemy for the contact frame
-- and back again hit from 60 to 633 studs away and through walls, with nothing flagged (2026-09-24
-- playtest: combat-sword-1, combat-enemy-F2).
--
-- This samples every player's root on Heartbeat and marks a TELEPORT whenever it crosses more
-- ground in one step than anything legitimate can: walking, sprinting, knockback and flings stay far
-- under MAX_SPEED. Server moves (waystone travel, respawn) are declared with serverMoved() and are
-- exempt. Combat code asks recentlyTeleported() and refuses hits for a moment after one. It never
-- kicks: a false positive (a lag spike) only costs one hit.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MoveGuard = {}

local MAX_SPEED = 120   -- [TUNING] studs/s across the ground; sprint is 26, knockback far below this
local SLACK = 8         -- [TUNING] studs of allowance per step, for jitter and physics corrections
local HOLD = 1.0        -- [TUNING] seconds a teleport keeps a player's hits refused

local last = {}          -- [player] = { pos = Vector3, at = number }
local teleportAt = {}    -- [player] = os.clock() of the last teleport
local serverMoveAt = {}  -- [player] = os.clock() of the last server move

local FLAT = Vector3.new(1, 0, 1)

-- The server itself moved this character (a waystone, a respawn): not a teleport.
function MoveGuard.serverMoved(player: Player)
	serverMoveAt[player] = os.clock()
	last[player] = nil
end

function MoveGuard.recentlyTeleported(player: Player, window: number?): boolean
	local at = teleportAt[player]
	return at ~= nil and os.clock() - at <= (window or HOLD)
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local prev = last[player]
			local pos = root.Position
			if prev then
				local dt = math.max(now - prev.at, 1 / 60)
				local moved = ((pos - prev.pos) * FLAT).Magnitude
				local recentServerMove = serverMoveAt[player] and now - serverMoveAt[player] < 0.5
				if moved > MAX_SPEED * dt + SLACK and not recentServerMove then
					teleportAt[player] = now
				end
			end
			last[player] = { pos = pos, at = now }
		else
			last[player] = nil
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		MoveGuard.serverMoved(player) -- a spawn is a server move
	end)
end)
for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function()
		MoveGuard.serverMoved(player)
	end)
end
Players.PlayerRemoving:Connect(function(player)
	last[player], teleportAt[player], serverMoveAt[player] = nil, nil, nil
end)

return MoveGuard
