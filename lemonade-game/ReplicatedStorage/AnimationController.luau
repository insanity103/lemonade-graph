-- ReplicatedStorage.AnimationController (Lemonade animation runtime v3)
-- Installed by Lemonade; replaced in place when a newer runtime ships.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationsFolder = ReplicatedStorage:WaitForChild("Animations")

-- Blend from whatever pose the joints are in (usually Roblox's idle or walk)
-- into the first frame, and back out to rest when a clip stops, so a clip
-- never snaps the character.
local FADE_IN = 0.1
local FADE_OUT = 0.15

-- Per-segment easing. A clip may carry `Easing = { [tStart] = "<style>" }`, naming the curve
-- used across the segment that STARTS at that key, and `Settings.Easing` as its default for
-- segments it does not name. Without either, a segment is linear, exactly as before.
--
-- Linear keys are why a hand-authored clip reads as mush: a windup has to snap into the loaded
-- pose and then hold (OutQuad/OutCubic), while the strike has to start slow and accelerate
-- through the target (InCubic). Both are the same keyframes with a different curve between them.
local EASING = {
	Linear = function(a: number): number
		return a
	end,
	InQuad = function(a: number): number
		return a * a
	end,
	OutQuad = function(a: number): number
		return 1 - (1 - a) * (1 - a)
	end,
	InCubic = function(a: number): number
		return a * a * a
	end,
	-- Sharper than InCubic: almost nothing happens for the first half of the segment and then
	-- it runs away. This is the curve the hips fire on, so the coil still reads as held while
	-- the drive has already started underneath it.
	InQuart = function(a: number): number
		return a * a * a * a
	end,
	-- The softest stop there is. A follow-through that ends on OutCubic still has visible speed
	-- in its last frames; on OutQuint the blade is already down to a crawl two frames out, which
	-- is what makes the end of the arc read as weight running out rather than as a cut-off.
	OutQuint = function(a: number): number
		local inv = 1 - a
		return 1 - inv * inv * inv * inv * inv
	end,
	OutCubic = function(a: number): number
		local inv = 1 - a
		return 1 - inv * inv * inv
	end,
	InOutQuad = function(a: number): number
		if a < 0.5 then
			return 2 * a * a
		end
		local inv = -2 * a + 2
		return 1 - (inv * inv) / 2
	end,
	InOutCubic = function(a: number): number
		if a < 0.5 then
			return 4 * a * a * a
		end
		local inv = -2 * a + 2
		return 1 - (inv * inv * inv) / 2
	end,
	-- Overshoots past the target and settles back: a recoil, a snap-back to guard.
	OutBack = function(a: number): number
		local c1 = 1.70158
		local c3 = c1 + 1
		local d = a - 1
		return 1 + c3 * d * d * d + c1 * d * d
	end,
}

-- Which two keys a clip time falls between, and how far along that segment it is once the
-- segment's easing curve has shaped it. The play loop runs on this, and so does SampleClip
-- below, so a clip has exactly one definition of "where is the body at t".
local function segmentAt(timestamps, easingByKey, defaultEase, t: number)
	local n = #timestamps
	local tStart, tEnd = timestamps[1], timestamps[n]
	for i = 1, n - 1 do
		if t >= timestamps[i] and t < timestamps[i + 1] then
			tStart, tEnd = timestamps[i], timestamps[i + 1]
			break
		end
	end
	local span = tEnd - tStart
	local alpha = (span > 0) and (t - tStart) / span or 0
	return tStart, tEnd, (EASING[easingByKey[tStart]] or defaultEase)(alpha)
end

-- Sorted key times of a clip, plus the two things segmentAt needs to shape a segment.
local function clipCurve(animTable)
	local timestamps = {}
	for t in pairs(animTable.Timestamps) do
		table.insert(timestamps, t)
	end
	table.sort(timestamps)
	return timestamps, animTable.Easing or {}, EASING[animTable.Settings.Easing or "Linear"] or EASING.Linear
end

-- Animations in this set play WITHOUT leg counter-rotation, because their leg
-- keyframes are intentional (kicks, sits, swims, etc.). Everything else gets the
-- counter-rotation applied to keep legs vertical when the torso rotates.
local SKIP_LEG_COUNTERROTATE = {
	["Leg Kick Animation"] = true,
	["Double Jump Backflip Animation"] = true,
	["Driving Steering Animation"] = true,
	["Flying Animation"] = true,
	["Gun Shooting Position Animation"] = true,
	["Injured Hurting Animation"] = true,
	["Injured Walk Animation"] = true,
	["Item Pickup Animation"] = true,
	["Level Up Celebration Animation"] = true,
	["Seating Animation"] = true,
	["Sliding Animation"] = true,
	["Sneak Walk Animation"] = true,
	["Spell Cast Fireball Animation"] = true,
	["Swimming Animation"] = true,
	["Zombie Walk Animation"] = true,
}

-- ── Blending against the locomotion underneath ──────────────────────────────────────────
--
-- Only the joints a clip mentions are driven; every other joint stays with Roblox's own
-- animations (walk, jump, idle) for the whole clip. That is a blend by PARTITION, and it is all
-- this runtime had: a joint is either 100% the clip's or 100% Roblox's, decided by whether the
-- clip's table happens to name it. There is no weight, and `Settings.Priority` is inert here
-- because nothing in this file plays an AnimationTrack for the Animator to arbitrate.
--
-- The attack clips name thirteen joints including four leg joints, so under partition blending a
-- swing thrown at a run pins both feet in a plant pose while the character keeps travelling --
-- it skates. `options.moveBlend` is the fix: a per-joint mask, applied per frame, scaled by how
-- fast the character is actually moving. ReplicatedStorage/SwingMove is the mask the sword
-- passes; this file only knows how to apply one. A clip played WITHOUT it behaves exactly as
-- every clip did before, and a clip played WITH it is unchanged at a standstill, because every
-- term below is multiplied by a speed fraction that is zero when the character is still.
--
--   Release[part]   how much of the LIVE pose the joint takes back at full speed (legs -> 1).
--   Additive[part]  how much of the live pose is composed UNDER the clip's pose (the spine).
--   Lean            degrees of pitch/roll into the character's own velocity, at Lean.Joint,
--                   with Lean.Head of it taken back off the neck.
--   Plant           a window around contact that scales BOTH of the first two back down, so the
--                   swing takes the body for the moment of the cut and then gives it back.
--   Tilt            a ceiling on how far the composed pelvis-and-chest may sit off the
--                   character's own vertical. Only the procedural layer (Lean and Drive's
--                   pitch) is scaled to meet it; the clip's own authored fold is never bent.
--
-- "The live pose" is read straight off the joint at the top of the frame. Roblox's Animator
-- evaluates and writes Motor6D.Transform during the animation phase, which runs BEFORE
-- RunService.Stepped, so a joint read here -- before this clip writes it -- is holding the walk,
-- run or idle pose for this frame. That is an assumption about frame order, so it is checked
-- rather than trusted: see LivePose below.
local MOVE_FULL_SPEED = 12 -- studs/s at which the blend is saturated, if a mask does not say
local MOVE_RATE = 9        -- how fast the speed fraction itself may move, per second

-- Internal class: drives Motor6D.Transform per frame, lerping between keyframes.
local AnimationExecutor = {}
AnimationExecutor.__index = AnimationExecutor

function AnimationExecutor.new(character: Model)
	local self = setmetatable({}, AnimationExecutor)

	self.Character = character
	self.Joints = {}
	self.Connection = nil
	self.IsPlaying = false
	-- Parts the current clip writes, and parts easing back to rest after a
	-- clip stopped or a new clip took over without them.
	self.Driven = {}
	self.Releasing = {}
	self.ReleaseElapsed = 0
	-- Hitstop: os.clock() until which the clip's own clock is stopped (see AnimationController.Hold),
	-- and the running clip's wind-back onto its contact frame (set by PlayFromTable).
	self.HoldUntil = 0
	self.SeekToContact = nil
	-- Move blend state (see LivePose and the mask notes above).
	self.MoveAlpha = 0   -- smoothed speed fraction, 0 standing
	-- The speed fraction the clip STARTED at, kept for the whole clip. It is the floor the blend
	-- may not fall through while the player is still asking to move: see the hitlag note in the
	-- per-frame step. Re-seeded on every Play.
	self.MoveSeed = 0
	self.Live = {}       -- [partName] = the last transform somebody ELSE put on that joint
	self.Wrote = {}      -- [partName] = the last transform THIS runtime put on it

	self.Humanoid = character:FindFirstChildOfClass("Humanoid")
	self.Root = character:FindFirstChild("HumanoidRootPart")

	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("Motor6D") and desc.Part1 then
			self.Joints[desc.Part1.Name] = desc
		elseif desc:IsA("AnimationConstraint") and desc.Attachment1 then
			local part = desc.Attachment1.Parent
			if part:IsA("BasePart") then
				self.Joints[part.Name] = desc
			end
		end
	end

	return self
end

function AnimationExecutor:Disconnect()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
end

-- The pose something OTHER than this runtime has the joint in right now: Roblox's walk, run,
-- jump or idle, evaluated for this frame by the Humanoid's Animator.
--
-- The Animator writes Motor6D.Transform during the animation phase and RunService.Stepped fires
-- after it, so reading the joint here -- before this frame's write -- reads the locomotion pose.
-- That is a claim about the frame order, and a wrong claim would silently read this clip's own
-- last frame back and blend the swing with itself, so it is verified instead of assumed: if the
-- value is byte-identical to what we wrote last frame then nobody else touched it, and the last
-- value that genuinely was somebody else's is used. With no such value (a joint no locomotion
-- track names) the answer is the rest pose, which is what this runtime released to before.
function AnimationExecutor:LivePose(partName: string, joint): CFrame
	local current = joint.Transform
	if current ~= self.Wrote[partName] then
		self.Live[partName] = current
	end
	return self.Live[partName] or CFrame.identity
end

-- Moves every driven part (and any part still easing out) into the release
-- set, starting from where it is now, so a stop or a clip switch never leaves
-- a joint frozen.
function AnimationExecutor:BeginRelease(keep)
	local releasing = {}
	for partName in pairs(self.Releasing) do
		if not keep[partName] then releasing[partName] = self.Joints[partName].Transform end
	end
	for partName in pairs(self.Driven) do
		if not keep[partName] then releasing[partName] = self.Joints[partName].Transform end
	end
	self.Releasing = releasing
	self.ReleaseElapsed = 0
	self.Driven = {}
end

-- One step of the ease back to rest; returns true while parts are still easing.
function AnimationExecutor:StepRelease(dt)
	if next(self.Releasing) == nil then return false end
	self.ReleaseElapsed += dt
	local alpha = math.min(1, self.ReleaseElapsed / FADE_OUT)
	for partName, start in pairs(self.Releasing) do
		local joint = self.Joints[partName]
		-- Ease back to whatever is driving the joint NOW, not to the rest pose. Releasing to rest
		-- was invisible while standing (the idle pose is nearly rest) and wrong the moment the
		-- character was moving: the legs of a swing that ended at a run were handed back through
		-- 0.15 s of straightening out of the run cycle before Roblox's cycle picked them up again.
		local live = self:LivePose(partName, joint)
		local target = start:Lerp(live, alpha)
		joint.Transform = target
		self.Wrote[partName] = target
	end
	if alpha >= 1 then
		self.Releasing = {}
		return false
	end
	return true
end

function AnimationExecutor:Stop()
	if not self.IsPlaying then return end
	self.IsPlaying = false
	self:Disconnect()
	self:BeginRelease({})
	self.Connection = RunService.Stepped:Connect(function(_, dt)
		if not self:StepRelease(dt) then self:Disconnect() end
	end)
end

function AnimationExecutor:PlayFromTable(animTable, options)
	self:Disconnect()
	self.IsPlaying = true
	self.HoldUntil = 0 -- a new clip is never born inside the last hit's hitstop

	options = options or {}
	local counterRotateLegs = options.counterRotateLegs ~= false  -- default true
	local onMarker = options.onMarker
	-- The locomotion mask, if the caller passes one (ReplicatedStorage/SwingMove). Absent, the
	-- clip drives every joint it names outright, exactly as before.
	local moveBlend = options.moveBlend
	local moveFull = moveBlend and tonumber(moveBlend.FullSpeed) or MOVE_FULL_SPEED
	local moveRate = moveBlend and tonumber(moveBlend.Rate) or MOVE_RATE
	-- A new clip starts from a clean view of what the rest of the rig is doing.
	table.clear(self.Live)
	table.clear(self.Wrote)

	-- Per-clip blend-in, easing and markers. All three are optional: a clip without them plays
	-- exactly as clips did before (0.1 s fade, linear segments, no events).
	local fadeInTime = tonumber(animTable.Settings.FadeIn) or FADE_IN
	if fadeInTime <= 0 then fadeInTime = 1e-6 end
	local easingByKey = animTable.Easing or {}
	local defaultEase = EASING[animTable.Settings.Easing or "Linear"] or EASING.Linear

	-- Markers: { { t = 0.13, name = "Swing" }, ... }, sorted, each fired once as clipTime passes
	-- it. This is how the swing tells the client when the blade starts moving and when it is
	-- through the target, without anything having to re-derive the clip's timing.
	local markers = {}
	for _, marker in ipairs(animTable.Markers or {}) do
		if marker.name and tonumber(marker.t) then
			table.insert(markers, { t = tonumber(marker.t), name = marker.name })
		end
	end
	table.sort(markers, function(a, b) return a.t < b.t end)
	local nextMarker = 1

	local timestamps = select(1, clipCurve(animTable))

	local maxTime = timestamps[#timestamps]
	local isLooping = animTable.Settings.Loop
	-- Where a looping clip rejoins itself. Absent (or 0) it rejoins at the start, which is what
	-- every clip before the heavy charge wanted. The heavy's charge has an ENTRANCE -- the body
	-- dropping into the coil -- followed by a strain cycle that has to repeat for as long as the
	-- button is down, and replaying the entrance every cycle would make a held charge look like
	-- the character drawing the sword over and over.
	local loopStart = math.clamp(tonumber(animTable.Settings.LoopStart) or 0, 0, maxTime)
	-- The first marker at or after the loop point: the ones before it belong to the entrance and
	-- must not fire again on every pass.
	local firstLoopMarker = #markers + 1
	for index, marker in ipairs(markers) do
		if marker.t >= loopStart then
			firstLoopMarker = index
			break
		end
	end

	-- Driven set: every part any frame mentions. Library clips are sparse
	-- (a frame may omit a part it drives elsewhere), so a missing part holds
	-- the last value this clip wrote for it.
	local driven = {}
	local startTransforms = {}
	for _, frame in pairs(animTable.Timestamps) do
		for partName in pairs(frame) do
			local joint = self.Joints[partName]
			if joint and not driven[partName] then
				driven[partName] = true
				startTransforms[partName] = joint.Transform
			end
		end
	end
	-- Parts the previous clip drove and this one does not ease back to rest.
	self:BeginRelease(driven)
	self.Driven = driven
	local last = {}

	local clipTime = 0
	local elapsed = 0

	-- The clip's own contact frame, if it declares one (a "Contact" marker: every sword swing
	-- does). A hitstop hold snaps the clock BACK to it -- see SeekToContact below.
	local contactTime = nil
	for _, marker in ipairs(markers) do
		if marker.name == "Contact" then
			contactTime = marker.t
			break
		end
	end

	-- One frame of the clip: advance the clock by `dt` (0 re-writes the current frame) and
	-- write every driven joint.
	local function step(dt: number)
		clipTime += dt
		elapsed += dt

		local ended = false
		if clipTime >= maxTime then
			if isLooping then
				local span = maxTime - loopStart
				clipTime = if span > 0 then loopStart + (clipTime - loopStart) % span else loopStart
				nextMarker = firstLoopMarker -- a looping clip fires its markers again on every pass
			else
				clipTime = maxTime
				ended = true
			end
		end

		-- Which segment, and how far along it once that segment's curve has shaped it.
		local tStart, tEnd, alpha = segmentAt(timestamps, easingByKey, defaultEase, clipTime)
		-- Blend in from the pose the joints had at Play; wall time, so a loop
		-- wrapping clipTime does not restart the blend.
		local fadeIn = math.min(1, elapsed / fadeInTime)

		local dataStart = animTable.Timestamps[tStart]
		local dataEnd = animTable.Timestamps[tEnd]

		-- ── This frame's share of the body ──────────────────────────────────────────────
		-- move: 0 standing, 1 at moveFull studs/s, smoothed. plant: how much of the clip the
		-- swing is taking back around its contact frame. lean/neck: the chest's lean into the
		-- character's own velocity and the head's share of it back.
		local move, plantLegs, plantBody = 0, 0, 0
		-- The pelvis sink and the chest's compression pitch (ReplicatedStorage/SwingMove's DRIVE).
		local driveDrop, drivePitch = 0, 0
		local lean, neck = nil, nil
		-- The lean's raw angles, in radians, before the tilt cap has had a look at them.
		local leanPitch, leanRoll = 0, 0
		-- How much of the CLIP's own chest fold the tilt cap is taking back out this frame, and
		-- which joint it comes off. Zero everywhere except a moving swing past its contact frame.
		local chestUnfold, chestUnfoldJoint = 0, nil
		if moveBlend then
			local humanoid, root = self.Humanoid, self.Root
			local wanted = 0
			local planar = Vector3.zero
			if humanoid and root and root.Parent and humanoid.Health > 0 then
				local velocity = root.AssemblyLinearVelocity
				planar = Vector3.new(velocity.X, 0, velocity.Z)
				wanted = math.clamp(planar.Magnitude / moveFull, 0, 1)
				-- The floor for the rest of the clip, taken from the raw speed on the clip's first
				-- frame, before any of the logic below can touch it.
				if elapsed <= dt then
					self.MoveSeed = wanted
				end
				-- Velocity is the fact, MoveDirection is the intent, and the blend wants both: a
				-- character carried by knockback, a conveyor or a falling lift is not running, and
				-- its legs should stay with the swing rather than break into a stride.
				local intent = humanoid.MoveDirection
				if intent.Magnitude < 0.1 then
					wanted = math.min(wanted, 0.15)
				else
					-- STILL ASKING TO RUN, SO THIS IS A BRAKE AND NOT A STOP.
					--
					-- Contact sets the attacker's WalkSpeed to 0 for the hitlag (ServerScriptService/
					-- CombatUtil), so on the frame the blade lands the running player's velocity
					-- collapses to nothing and does not come back for 100-200 ms while the humanoid
					-- re-accelerates. Read as speed, that is a character who stopped running: the
					-- blend hands the legs back to the CLIP, whose legs are a 0.66 s plant, and the
					-- lower body freezes into a squat for the whole follow-through and recovery --
					-- which is exactly what the move_blend round-0 capture filmed, the run cycle
					-- dying on the contact frame and only returning after the clip ended.
					--
					-- The player never let go of the stick, so the legs must not be taken off the
					-- run. While the intent is live the blend holds the floor it started the clip
					-- at; a player who genuinely stops falls through the branch above instead, and
					-- a knockback with no input still keeps its legs in the swing.
					wanted = math.max(wanted, self.MoveSeed)
					-- The lean reads velocity too, so give it the intent to lean into while the
					-- real velocity is braked away, rather than snapping the chest upright.
					if planar.Magnitude < 0.05 then
						planar = intent.Unit * (moveFull * wanted)
					end
				end
			end
			-- Seeded, not smoothed, on the clip's first frame. The smoothing exists to stop a
			-- one-frame velocity spike popping the lower body DURING a swing; carrying it across
			-- the start of a swing would be a quarter second of a running player's legs still in
			-- the clip's plant, which is the exact skate this piece exists to remove. Between
			-- swings nothing plays and nothing updates this, so the value it starts from is stale
			-- by definition: the speed on the input frame is the fact, and it is taken as read.
			if elapsed <= dt then
				self.MoveAlpha = wanted
			else
				self.MoveAlpha += (wanted - self.MoveAlpha) * math.min(1, dt * moveRate)
			end
			move = self.MoveAlpha

			local plant = moveBlend.Plant
			if plant and clipTime > plant.From and clipTime < plant.To then
				local shape
				if clipTime <= plant.Peak then
					-- On over the back half of the windup: the stride checks before the blade
					-- leaves, not after it lands.
					local a = (clipTime - plant.From) / math.max(plant.Peak - plant.From, 1e-6)
					shape = 1 - (1 - a) * (1 - a)
				else
					-- Off across the follow-through, smoothstepped, so the run picks the legs back
					-- up instead of snatching them.
					local a = (clipTime - plant.Peak) / math.max(plant.To - plant.Peak, 1e-6)
					shape = 1 - a * a * (3 - 2 * a)
				end
				plantLegs = (plant.Legs or 0) * shape
				plantBody = (plant.Body or 0) * shape
			end

			-- THE SPINE'S OWN WINDOW, which is not the legs'. It opens on the clip's first frame,
			-- because the coil IS the windup and a run composed under it at full weight erases it
			-- (SwingMove's BODY note). Ramps across the windup, HOLDS through the strike, and is
			-- handed back across the follow-through and the recovery, where a body still moving
			-- wants its run sway again. Whichever of this and the leg window is deeper wins, so the
			-- plant can still take the chest if it ever asks for more.
			local body = moveBlend.Body
			if body and clipTime >= body.From and clipTime < body.To then
				local shape
				if clipTime <= body.Peak then
					local a = (clipTime - body.From) / math.max(body.Peak - body.From, 1e-6)
					shape = a * a * (3 - 2 * a)
				elseif clipTime <= body.Hold then
					shape = 1
				else
					local a = (clipTime - body.Hold) / math.max(body.To - body.Hold, 1e-6)
					shape = 1 - a * a * (3 - 2 * a)
				end
				plantBody = math.max(plantBody, (body.Amount or 0) * shape)
			end

			-- THE DRIVE. Both numbers are scaled by `move`, so a standing swing gets none of this
			-- and the clip's own authored plant is left exactly as the standing pieces filmed it.
			local drive = moveBlend.Drive
			if drive and move > 0.01 then
				local W, C, SE, FIN = drive.Windup, drive.Contact, drive.SwingEnd, drive.Finish
				-- The sink: down across the load, held through the strike, out across the recovery.
				local base = 0
				if clipTime <= W then
					local a = clipTime / math.max(W, 1e-6)
					base = (drive.Drop or 0) * a * a * (3 - 2 * a)
				elseif clipTime <= SE then
					base = drive.Drop or 0
				elseif clipTime < FIN then
					local a = (clipTime - SE) / math.max(FIN - SE, 1e-6)
					base = (drive.Drop or 0) * (1 - a * a * (3 - 2 * a))
				end
				-- The compression: an extra dip that arrives ON the contact frame and is let back
				-- out over DipSpan, so the body is already rising as the blade carries past.
				local dip, comp = 0, 0
				if clipTime > W and clipTime <= C then
					local a = (clipTime - W) / math.max(C - W, 1e-6)
					dip = (drive.Dip or 0) * a * a
					comp = a * a
				elseif clipTime > C then
					local span = drive.DipSpan or 0.1
					if clipTime < C + span then
						local a = (clipTime - C) / span
						dip = (drive.Dip or 0) * (1 - a * a * (3 - 2 * a))
					end
					if clipTime < SE then
						local a = (clipTime - C) / math.max(SE - C, 1e-6)
						comp = 1 - a * a * (3 - 2 * a)
					end
				end
				driveDrop = (base + dip) * move
				drivePitch = math.rad(drive.Pitch or 0) * comp * move
			end

			local leanSpec = moveBlend.Lean
			if leanSpec and move > 0.01 and self.Root then
				-- Velocity in the character's OWN frame: -Z is forward, +X is its right. So a
				-- forward run pitches the chest forward and a right strafe rolls it right, whatever
				-- direction the character happens to be facing in the world.
				local localVel = self.Root.CFrame:VectorToObjectSpace(planar) / moveFull
				-- The run's lean is taken back out across the window the CLIP spends its own forward
				-- pitch in, because otherwise the two add and the recovery ends up nose-down over its
				-- own feet with the sword hidden behind the body. Full value up to the taper's start
				-- (which is the contact frame), easing to TaperKeep by its end. See SwingMove's note.
				local scale = 1
				local from, to = leanSpec.TaperFrom, leanSpec.TaperTo
				if from and to and to > from and clipTime > from then
					local a = math.clamp((clipTime - from) / (to - from), 0, 1)
					a = a * a * (3 - 2 * a)
					scale = 1 + ((leanSpec.TaperKeep or 1) - 1) * a
				end
				local forward = math.clamp(-localVel.Z, -1, 1) * move * scale
				local sideways = math.clamp(localVel.X, -1, 1) * move * scale
				-- Negative about X tips the chest's top forward; negative about Z rolls it right.
				-- Kept as ANGLES rather than a CFrame because the tilt cap below has to be able to
				-- scale them, and scaling a rotation is only cheap if you still have its source.
				leanPitch = math.rad(-(leanSpec.Pitch or 0) * forward)
				leanRoll = math.rad(-(leanSpec.Roll or 0) * sideways)
			end

			-- ── THE TILT CAP ────────────────────────────────────────────────────────────
			-- The clip folds the chest over its own cut -- 42 degrees off the pelvis at the first
			-- follow-through beat -- and that fold is authored weight the standing pieces were
			-- judged on. The lean and the drive's compression pitch used to be ADDED to it with
			-- nothing watching the total, which took a running body to 66 degrees off vertical
			-- and read as the whole character being rotated rather than as a lean.
			--
			-- So the total is watched, and only the procedural half pays. Measure the composed
			-- pelvis-and-chest twice -- the clip alone, then the clip with the lean and the drive
			-- pitch on it -- and if the second is past Max, scale the procedural angles by the
			-- fraction that lands exactly on Max. The clip is never rotated: its pose is what
			-- SwingBlade samples for the server's hitbox, so bending it here would move the blade
			-- the player watches off the segment the server tests. Scaling the procedural layer
			-- back moves the two closer together.
			--
			-- Cost: two CFrame multiplies and two dot products a frame, only while moving.
			local tilt = moveBlend.Tilt
			if tilt and (leanPitch ~= 0 or leanRoll ~= 0 or drivePitch ~= 0) then
				-- This frame's CLIP pose for the two joints, with no blending on them at all:
				-- the same two lines the joint loop below runs, inlined rather than put behind a
				-- local function so a swing still allocates nothing per frame.
				local rootA = dataStart[tilt.Root] or last[tilt.Root] or startTransforms[tilt.Root]
				local chestA = dataStart[tilt.Chest] or last[tilt.Chest] or startTransforms[tilt.Chest]
				if rootA and chestA then
					local rootPose = rootA:Lerp(dataEnd[tilt.Root] or rootA, alpha)
					local chestPose = chestA:Lerp(dataEnd[tilt.Chest] or chestA, alpha)
					local k = 1
					-- The procedural layer's own size, whatever the clip is doing.
					local addMax = math.rad(tilt.AddMax or 180)
					local added = CFrame.Angles(-drivePitch, 0, 0) * CFrame.Angles(leanPitch, 0, leanRoll)
					local addAngle = math.acos(math.clamp(added.UpVector.Y, -1, 1))
					if addAngle > addMax then
						k = addMax / addAngle
					end
					-- The composed body against the ceiling.
					local maxTilt = math.rad(tilt.Max or 180)
					local base = math.acos(math.clamp((rootPose * chestPose).UpVector.Y, -1, 1))
					local full = math.acos(math.clamp((rootPose * added * chestPose).UpVector.Y, -1, 1))
					if full > maxTilt and full > base then
						k = math.min(k, math.clamp((maxTilt - base) / (full - base), 0, 1))
					end
					leanPitch, leanRoll, drivePitch = leanPitch * k, leanRoll * k, drivePitch * k
					-- The procedural layer is gone and the body is STILL past the ceiling, which
					-- means the clip's own fold is what is over it. Past the contact frame -- and
					-- only past it, because that frame is the one the server's hitbox is derived
					-- from -- take up to ClipMax of that fold back out, enough to land on Max.
					local clipMax = tilt.ClipMax or 0
					local after = tilt.ClipAfter
					if clipMax > 0 and after and clipTime > after and k < 0.02 and base > maxTilt then
						chestUnfold = math.min(clipMax, 1 - maxTilt / base) * move
						chestUnfoldJoint = tilt.Chest
					end
				end
			end

			if leanPitch ~= 0 or leanRoll ~= 0 then
				lean = CFrame.Angles(leanPitch, 0, leanRoll)
				local giveBack = moveBlend.Lean and moveBlend.Lean.Head or 0
				neck = if giveBack > 0 then CFrame.identity:Lerp(lean:Inverse(), giveBack) else nil
			end
		end
		local leanJoint = lean and moveBlend.Lean.Joint or nil

		for partName in pairs(self.Driven) do
			local joint = self.Joints[partName]
			local cfA = dataStart[partName] or last[partName] or startTransforms[partName]
			local cfB = dataEnd[partName] or cfA
			local target = cfA:Lerp(cfB, alpha)
			-- `last` is the CLIP's pose, before any blending: it is what a later sparse frame
			-- carries forward, and blending it back in would compound frame after frame.
			last[partName] = target
			if fadeIn < 1 then
				target = startTransforms[partName]:Lerp(target, fadeIn)
			end

			if move > 0.005 then
				-- The tilt cap's last resort, applied to the CLIP pose before anything is
				-- composed on it: the chest's fold eased back toward upright, which lifts the
				-- whole arm chain hanging off it with it. `last` above already holds the
				-- untouched clip pose, so nothing here compounds frame to frame.
				if chestUnfold > 0 and partName == chestUnfoldJoint then
					target = CFrame.new(target.Position) * target.Rotation:Lerp(CFrame.identity, chestUnfold)
				end
				local live = self:LivePose(partName, joint)
				local add = moveBlend.Additive and moveBlend.Additive[partName]
				if add then
					-- The run composed UNDER the clip, not mixed with it: the swing's coil is kept
					-- whole and the locomotion turns the frame it sits in.
					target = target:Lerp(live * target, add * move * (1 - plantBody))
				end
				if partName == leanJoint then
					target = lean * target
				elseif neck and partName == "Head" then
					target = neck * target
				end
				-- The drive, composed on top of whatever the lean did: the pelvis sinks in the
				-- character's own vertical and the chest folds forward over the cut.
				if moveBlend.Drive then
					if driveDrop > 1e-4 and partName == moveBlend.Drive.Joint then
						target = CFrame.new(0, -driveDrop, 0) * target
					end
					if drivePitch > 1e-4 and partName == moveBlend.Drive.PitchJoint then
						target = CFrame.Angles(-drivePitch, 0, 0) * target
					end
				end
				local release = moveBlend.Release and moveBlend.Release[partName]
				if release then
					target = target:Lerp(live, release * move * (1 - plantLegs))
				end
			end

			joint.Transform = target
			self.Wrote[partName] = target
		end

		-- Markers fire after the frame's pose is written, so a listener that reads the rig
		-- (a trail, a sound, a camera kick) sees the pose the marker is talking about. A
		-- listener that errors must not kill the clip, so each call is pcall'd.
		while nextMarker <= #markers and clipTime >= markers[nextMarker].t do
			local marker = markers[nextMarker]
			nextMarker += 1
			if onMarker then
				local ok, err = pcall(onMarker, marker.name, marker.t)
				if not ok then
					warn("AnimationController: marker handler failed for " .. marker.name .. ": " .. tostring(err))
				end
			end
		end

		self:StepRelease(dt)

		-- Counter-rotate legs against LowerTorso (only when caller asks for it)
		if counterRotateLegs then
			local lowerTorso = self.Joints["LowerTorso"]
			if lowerTorso then
				local lt = lowerTorso.Transform
				local invRot = (lt - lt.Position):Inverse()
				for _, legName in ipairs({"LeftUpperLeg", "RightUpperLeg"}) do
					local legJoint = self.Joints[legName]
					if legJoint then
						local turned = invRot * legJoint.Transform
						legJoint.Transform = turned
						-- Still ours, so LivePose must not mistake it for the Animator's.
						self.Wrote[legName] = turned
					end
				end
			end
		end

		if ended then self:Stop() end
	end

	self.Connection = RunService.Stepped:Connect(function(_, dt)
		if not self.IsPlaying then return end

		-- Hitstop. The clip's clock stops dead, so the blade is handed back exactly where it
		-- was: the frame it is held on is the fastest in the swing (102 degrees in 28 ms), and
		-- letting the clock run under a held pose would teleport the sword a third of the way
		-- round the arc the moment the hold let go. Nothing is written while held either --
		-- ReplicatedStorage/Hitstop is pinning every Motor6D after this pass anyway, and the
		-- joints this clip drives keep the transform it wrote on the contact frame.
		if os.clock() < self.HoldUntil then return end

		step(dt)
	end)

	-- Hitstop, the other half: the hold has to land on the CONTACT frame, and the news that a
	-- blow landed never arrives on it. The server fires the hitbox on the clip's contact frame,
	-- and its HitlagEffect reaches this client a round trip later -- one to three rendered
	-- frames in Studio, more on a live server -- during which this clock has run on past
	-- contact into the follow-through, where the blade moves 42 degrees in the next 58 ms. So
	-- a hold that simply stopped the clock held the blade PAST the body it had just cut, with
	-- nothing resisting it, which is exactly the frame the first hitstop strips showed.
	--
	-- If the clock is inside `window` seconds past the contact frame, it is wound back onto it
	-- and that frame is written now, synchronously, so whoever pins the joints next (Hitstop,
	-- on PostSimulation / PreRender) pins the blade IN the target. The follow-through then plays
	-- in full when the hold lets go, instead of the part of it the latency ate. Markers never
	-- re-fire (the marker cursor only moves forward), so the whoosh and the trail are untouched.
	-- Returns whether it wound back, so the caller can drop a snapshot it took of the old pose.
	self.SeekToContact = function(window: number): boolean
		if not (self.IsPlaying and contactTime) then
			return false
		end
		local past = clipTime - contactTime
		if past <= 0 or past > window then
			return false
		end
		clipTime = contactTime
		step(0)
		return true
	end
end

-- Public API
local AnimationController = {}

local executor = nil
local currentCharacter = nil

local function ensureExecutor()
	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()

	-- Re-create the executor if the character changed (respawn, R6/R15 swap, etc.)
	if character ~= currentCharacter then
		currentCharacter = character
		executor = AnimationExecutor.new(character)
	end
	return executor
end

-- Reset on respawn so we don't reuse joints from the old character.
-- Guarded because this module is now required on the SERVER too, for SampleClip below, and
-- LocalPlayer is nil there. Everything else that touches LocalPlayer already sits inside a
-- function the server never calls.
if Players.LocalPlayer then
	Players.LocalPlayer.CharacterAdded:Connect(function()
		executor = nil
		currentCharacter = nil
	end)
end

-- Where a clip puts every joint it drives at clip time `t`, as { [partName] = CFrame }, without
-- a rig, a character or a frame of playback -- the same key search, the same easing curve and
-- the same lerp the play loop above runs on, because it is literally the same two functions.
--
-- This is how the SERVER knows where the sword is. The player's hitbox has to fire on the frame
-- the blade passes through the target, from where the blade actually is on that frame, and the
-- blade's position is a property of this clip. Reading it out of the clip means the hitbox and
-- the picture cannot drift apart: re-time the swing or move the contact pose and the hitbox
-- moves with it, with nothing to copy by hand and nothing to forget. Nothing here is client
-- input -- the server reads the same module file it ships.
function AnimationController.SampleClip(animTable, t: number)
	local timestamps, easingByKey, defaultEase = clipCurve(animTable)
	local first, last = timestamps[1], timestamps[#timestamps]
	if animTable.Settings.Loop and last > first then
		t = first + (t - first) % (last - first)
	else
		t = math.clamp(t, first, last)
	end
	local tStart, tEnd, alpha = segmentAt(timestamps, easingByKey, defaultEase, t)
	local from, to = animTable.Timestamps[tStart], animTable.Timestamps[tEnd]
	local pose = {}
	for partName, cfA in pairs(from) do
		pose[partName] = cfA:Lerp(to[partName] or cfA, alpha)
	end
	return pose
end

-- Play(name) plays a clip. Play(name, { onMarker = function(markerName, t) end }) also hands
-- back the clip's markers as they pass, which is how the swing lines its whoosh, its VFX and
-- the rest of the client up with the blade instead of with the click.
--
-- Play(name, { moveBlend = <mask> }) shares the body with whatever locomotion is running under
-- the clip: see the mask notes above and ReplicatedStorage/SwingMove for the sword's. Costs, per
-- frame of a clip that passes one: one velocity read, one exponential smooth, at most one
-- VectorToObjectSpace and two CFrame.Angles for the lean, and per driven joint one table lookup,
-- one CFrame comparison and up to two extra Lerps -- about 30 extra CFrame operations a frame on
-- a 13-joint swing, against the ~40 the clip itself already does. It runs only while a swing is
-- playing (0.47-0.98 s) and only on the swinging player's own client.
function AnimationController.Play(animationName, options)
	local animModule = AnimationsFolder:FindFirstChild(animationName)
	if not animModule then
		warn("AnimationController: no animation named", animationName)
		return
	end
	local exec = ensureExecutor()
	local animTable = require(animModule)
	if animTable.Rigs then
		local humanoid = exec.Character:WaitForChild("Humanoid")
		animTable = animTable.Rigs[humanoid.RigType.Name]
	end
	local skipLegFix = SKIP_LEG_COUNTERROTATE[animationName] == true
		or animTable.Settings.CounterRotateLegs == false
	exec:PlayFromTable(animTable, {
		counterRotateLegs = not skipLegFix,
		onMarker = options and options.onMarker or nil,
		moveBlend = options and options.moveBlend or nil,
	})
end

-- How far past its contact frame a clip may be and still be wound back onto it for the hold.
-- 90 ms covers any latency a hit is playable at and stops short of the "ArcEnd" marker on every
-- swing (the nearest is hit 3's, 120 ms after its contact), so a wind-back never crosses a
-- marker. Past it the hold stays where the clock is: a blade snatched back from the end of its
-- follow-through would read as a glitch, not a bite.
local HOLD_REWIND_WINDOW = 0.090 -- [TUNING] seconds

-- Hitstop: stop the running clip's clock for `duration` seconds, then carry on from exactly the
-- frame it stopped on. Called by ReplicatedStorage/Hitstop when a blow lands; extending an
-- existing hold rather than restarting it, so two notifications of one hit hold once.
-- With `onContact`, the clock is first wound back onto the clip's contact frame if it has run
-- up to HOLD_REWIND_WINDOW past it (see SeekToContact), and the contact pose is written at
-- once. Returns whether that happened.
-- No-op when nothing is playing, and on the server (there is no executor there).
function AnimationController.Hold(duration: number, onContact: boolean?): boolean
	if not executor or typeof(duration) ~= "number" or duration <= 0 then
		return false
	end
	executor.HoldUntil = math.max(executor.HoldUntil or 0, os.clock() + duration)
	if onContact and executor.SeekToContact then
		return executor.SeekToContact(HOLD_REWIND_WINDOW)
	end
	return false
end

function AnimationController.Stop()
	if executor then executor:Stop() end
end

return AnimationController
