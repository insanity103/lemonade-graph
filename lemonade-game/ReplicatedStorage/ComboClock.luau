-- ComboClock — which hit of the chain the client is about to throw.
--
-- The five M1s are five different swings, so the client has to know which one it is playing on
-- the frame the button goes down. The combo counter is the SERVER's (SwordSystem owns it, and
-- owns the damage, the endlag and the hitbox that come off it), and the server's answer arrives
-- a round trip later -- on a live server, tens of milliseconds after the swing has already had
-- to start drawing.
--
-- So the client predicts, from the same two constants the server uses (ComboConfig.ENDLAG and
-- COMBO_RESET_TIME) and its own record of its own clicks, and the server corrects it: every
-- ComboUpdate carries the authoritative index and `sync` below snaps the counter to it. The two
-- agree unless a swing was dropped, and they re-agree on the next swing either way.
--
-- What a wrong prediction can cost is one swing drawn as the wrong member of the chain. It
-- cannot cost damage, reach, endlag, a hit or a combo step: none of those are computed here or
-- sent from here. The client asks to swing; the server decides what that swing was and what it
-- hit. Nothing in this file is ever read by the server.
--
-- The gate: `ready()` is the client's own copy of the server's endlag check, so the whoosh, the
-- clip and the trail are not spent on a swing the server is going to drop in silence. It is
-- deliberately a HAIR stricter than the server (GRACE below) -- being slightly early means the
-- picture plays for a swing that never lands, which is worse than being slightly late.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ComboConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ComboConfig"))
local SwingTiming = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwingTiming"))

-- 15 ms. The perfect-timing window is 80 ms wide, so a player hitting the beat still has 65 ms
-- of it; the cost of getting this wrong the other way is a swing that plays and does nothing.
local GRACE = 0.015

local ComboClock = {}

local count = 0
local lastSwing = 0
local lastEnd = 0

-- Have the reset and endlag rules had their say by `now`?
local function settle(now: number)
	if now - lastSwing > ComboConfig.COMBO_RESET_TIME then
		count = 0
		lastEnd = 0
	end
end

-- True when the server would accept a swing thrown now.
function ComboClock.ready(now: number): boolean
	settle(now)
	return lastEnd <= 0 or now >= lastEnd + GRACE
end

-- Advance to the next hit and return its index, its clip name and its clock. Call this only
-- when actually swinging: it moves the counter.
function ComboClock.advance(now: number): (number, string, any)
	settle(now)
	count += 1
	if count > ComboConfig.MAX_COMBO then
		count = 1
	end
	lastSwing = now
	lastEnd = now + (ComboConfig.ENDLAG[count] or 0.2)
	local timing = SwingTiming.HITS[count] or SwingTiming.HITS[1]
	return count, timing.CLIP, timing
end

-- The heavy attack is not a member of the chain: it is thrown on its own binding, it RESETS the
-- counter, and it books an endlag of its own (HeavyConfig.ENDLAG, 420-680 ms). Called by
-- ReplicatedStorage/HeavyCharge on release so the next M1 is hit 1 and cannot be drawn during the
-- heavy's recovery -- without waiting a round trip for the server's ComboUpdate, which corrects
-- both numbers when it lands.
function ComboClock.spend(endlag: number)
	count = 0
	lastSwing = tick()
	lastEnd = lastSwing + (if typeof(endlag) == "number" and endlag > 0 then endlag else 0.2)
end

-- The server's answer. It wins: the next prediction is made from its number, not ours.
function ComboClock.sync(serverCount: number, endlag: number?)
	if typeof(serverCount) ~= "number" then
		return
	end
	if serverCount <= 0 then
		count = 0
		-- A zero with an endlag attached is the heavy resetting the chain, and its recovery is
		-- still running. A bare zero is a death or an explicit HUD reset, which clears everything.
		-- Never SHORTENS a gate the client already booked: being slightly late costs nothing,
		-- being early costs a swing that plays and does nothing.
		if typeof(endlag) == "number" and endlag > 0 then
			lastEnd = math.max(lastEnd, tick() + endlag)
		else
			lastEnd = 0
		end
		return
	end
	count = math.clamp(math.floor(serverCount), 1, ComboConfig.MAX_COMBO)
	if typeof(endlag) == "number" and endlag > 0 then
		lastEnd = lastSwing + endlag
	end
end

if RunService:IsClient() then
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("RemoteEvents", 30)
		local combo = remotes and remotes:WaitForChild("ComboUpdate", 30)
		if combo then
			combo.OnClientEvent:Connect(function(serverCount, endlag)
				ComboClock.sync(serverCount, endlag)
			end)
		end
		-- A respawn clears the server's counter (SwordSystem's Died handler fires ComboUpdate
		-- with 0), but the character can also change without that arriving first.
		local player = Players.LocalPlayer
		if player then
			player.CharacterAdded:Connect(function()
				count, lastSwing, lastEnd = 0, 0, 0
			end)
		end
	end)
end

return ComboClock
