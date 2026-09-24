-- Hitstop — hold a character's animation dead still on the frame a blow lands.
--
-- The single feel-good trick every good fighting game runs and most Roblox sword games miss: on
-- contact, BOTH bodies stop moving for a few frames. The attacker's blade stops in the target
-- instead of sliding through it (it reads as the steel being resisted), the victim is caught at
-- the instant it is hit, and then everything lets go at once into the flinch. Without it a hit
-- is a number and a sound played over an animation that never noticed.
--
-- ── What "hold" has to mean here ───────────────────────────────────────────────────────
-- Three things write a player character's joints, and a hold that misses any one of them is a
-- body that keeps sliding under a frozen arm:
--   1. ReplicatedStorage/AnimationController — the procedural swing, writing Motor6D.Transform
--      from RunService.Stepped. Its CLOCK is paused (AnimationController.Hold), not just its
--      output: pinning the joints while the clip's clock ran on would hand the blade back 60 ms
--      further round the arc, and the fastest frame of the swing covers 102 degrees in 28 ms.
--      A hold that teleports the sword on release is worse than no hold.
--      And the clock is first wound BACK onto the clip's contact frame: the server's "hit
--      landed" arrives a round trip after the contact frame, by which time the blade is
--      already in its follow-through, past the body. Held there, nothing is resisted. Wound
--      back (up to 90 ms), the held frame is the blade in the target, and the whole
--      follow-through plays after the release instead of the part the latency left.
--   2. Roblox's stock Animate script, through the Humanoid's Animator — the legs, which the
--      swing clip does not drive on a walking player. Its tracks are set to speed 0.
--   3. Anything else that writes a Motor6D this frame. Covered by re-applying the snapshot
--      after simulation and again before render, which is after every writer in the frame.
--
-- ── Extendable, never stacked ──────────────────────────────────────────────────────────
-- A landed hit reaches the attacker's client twice on purpose: the server's HitlagEffect remote
-- (which carries the combo index, so the hold can scale with it) and the victim's replicated
-- Health drop (which is what every OTHER client sees). Whichever arrives first starts the hold
-- and the other one only extends it; a second freeze never re-snapshots the pose, so two
-- notifications of one hit can never double-freeze or restore the wrong pose.
--
-- ── Cost ───────────────────────────────────────────────────────────────────────────────
-- Per landed hit: one pass over the character's descendants (~20 Motor6Ds on an R15) and two
-- RunService connections held for the 60-90 ms of the hold, each re-writing those transforms.
-- About 2,600 CFrame property writes over a tenth of a second, then both connections are
-- dropped. Nothing runs between hits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ComboConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ComboConfig"))
local AnimationController = require(ReplicatedStorage:WaitForChild("AnimationController"))

local Hitstop = {}

-- Nothing may hold a body longer than this, wherever the number came from.
Hitstop.MAX = ComboConfig.HITSTOP_MAX

-- The hold for a hit at `comboIndex`: the gameplay hitlag plus the margin that makes it visible.
-- One definition, so the attacker's client, the victim's rig and the server all hold for the
-- same span and let go on the same frame.
function Hitstop.duration(comboIndex: number?): number
	local index = comboIndex or 1
	local lag = ComboConfig.HITLAG_DURATION[index] or ComboConfig.HITLAG_DURATION[1]
	return math.clamp(lag + ComboConfig.HITSTOP_EXTRA, 0, ComboConfig.HITSTOP_MAX)
end

local active = setmetatable({}, { __mode = "k" }) -- [character] = { endsAt = os.clock() }

local function isLocalCharacter(character: Model): boolean
	local player = Players.LocalPlayer
	return player ~= nil and player.Character == character
end

-- Hold `character`'s whole body where it is for `duration` seconds. Safe to call again while a
-- hold is running: the later call only pushes the end time out.
function Hitstop.freeze(character: Model?, duration: number?): ()
	-- Client only: this is a picture, not a rule, and PreRender does not exist on a server.
	if not RunService:IsClient() then
		return
	end
	if not (character and character.Parent) or typeof(duration) ~= "number" then
		return
	end
	duration = math.clamp(duration, 0, ComboConfig.HITSTOP_MAX)
	if duration <= 0 then
		return
	end

	-- The swing's own clock stops first, and stops for the whole hold however many times this is
	-- called: AnimationController.Hold takes the later of the two end times. It is also wound
	-- back onto the contact frame, which is written there and then, before anything below can
	-- snapshot the pose.
	local rewound = false
	if isLocalCharacter(character) then
		rewound = AnimationController.Hold(duration, true)
	end

	local running = active[character]
	if running then
		running.endsAt = math.max(running.endsAt, os.clock() + duration)
		if rewound then
			-- The pose this hold snapshotted is past contact; the next pin takes the new one.
			running.held = nil
		end
		return
	end

	local hold = { endsAt = os.clock() + duration, held = nil }
	active[character] = hold

	-- The pose is snapshotted on the first pin, not now: this runs from a remote handler or a
	-- HealthChanged signal, which fire between frames, and the pose that should be held is the
	-- one the frame's animation writers have finished with.
	local function pin()
		local held = hold.held
		if not held then
			held = {}
			for _, descendant in ipairs(character:GetDescendants()) do
				if descendant:IsA("Motor6D") then
					held[descendant] = descendant.Transform
				end
			end
			hold.held = held
		end
		for motor, transform in pairs(held) do
			if motor.Parent then
				motor.Transform = transform
			end
		end
	end

	-- After physics and again before render: between them they land after every other writer in
	-- the frame, including AnimationController's Stepped pass and the Animator's own evaluation.
	local afterSimulation = RunService.PostSimulation:Connect(pin)
	local beforeRender = RunService.PreRender:Connect(pin)

	-- Roblox's stock walk/idle tracks are not Motor6D writes we can out-order reliably, so they
	-- are stopped at the source and handed back their own speed afterwards.
	local paused = {}
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			paused[track] = track.Speed
			track:AdjustSpeed(0)
		end
	end

	task.spawn(function()
		while os.clock() < hold.endsAt do
			task.wait()
		end
		afterSimulation:Disconnect()
		beforeRender:Disconnect()
		for track, speed in pairs(paused) do
			if track.IsPlaying then
				track:AdjustSpeed(speed)
			end
		end
		active[character] = nil
	end)
end

return Hitstop
