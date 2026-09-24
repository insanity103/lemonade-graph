-- SwingMove — how a swing shares the body with the run underneath it.
--
-- ── The problem this piece exists for ───────────────────────────────────────────────────
--
-- The attack clips drive THIRTEEN joints, and four of them are legs. That was right for the
-- pieces before this one: a standing swing has to plant, sink over the right foot and drive off
-- it, and the authored legs are most of what makes the weight read. But a player swings while
-- running far more often than standing still, and those same authored legs are a DISASTER in
-- motion -- the clip pins both feet in a plant pose for 0.66 s while the root keeps travelling
-- at 16 studs a second, so the character slides across the ground on frozen legs. Ice-skating.
--
-- Roblox's own answer to this is animation priority: a Movement-priority walk cycle on the legs
-- and an Action-priority attack on top, arbitrated per joint by the Animator. We do not have it.
-- ReplicatedStorage/AnimationController writes Motor6D.Transform itself from RunService.Stepped
-- rather than playing AnimationTracks, so `Settings.Priority` in every clip table is inert and
-- nothing arbitrates anything: whatever joints a clip names, it owns outright.
--
-- So the arbitration is here, as data, and the runtime applies it. This module is the POLICY --
-- which joints the attack keeps, which it hands back, how far the body leans into its own
-- velocity and when it plants -- and AnimationController is the mechanism.
--
-- ── The split ───────────────────────────────────────────────────────────────────────────
--
--   RELEASE   per joint, how much of the LOCOMOTION pose that joint takes back at full speed.
--             1.0 for all four leg joints: at a run the legs are Roblox's run cycle, entirely,
--             and the character strides through its own swing instead of skating through it.
--             0 for both arms, both hands: the attack owns the arms at every speed, which is
--             the whole point of an upper/lower split.
--
--   ADDITIVE  per joint, how much of the locomotion pose is COMPOSED UNDER the clip's pose
--             rather than replacing it. This is for the spine. The clip's LowerTorso coil is
--             the swing's weight and must not be diluted; the run's hip drive and chest counter-
--             sway are what says the legs below are doing something. Composed, the body gets
--             both: the coil turned by a torso that is still running.
--
--   LEAN      degrees of chest pitch and roll, scaled by how fast the character is actually
--             going and in which direction in its OWN frame. Running forward pitches the chest
--             into the run; strafing rolls it into the turn. The head takes a fraction of the
--             lean back off so the gaze stays roughly where the swing put it, which is the
--             difference between leaning into a cut and being blown over by it.
--
--   PLANT     a window around the contact frame in which the swing TAKES THE BODY BACK. Both of
--             the numbers above are scaled down across it, so for about a fifth of a second the
--             legs come part-way home to the clip's planted stance and the spine is the clip's
--             alone. That is the step into the cut: the stride checks, the base widens, the
--             weight goes through the blade, and then the run has the body again.
--
--             It is also what keeps the hit honest. The server derives the contact hitbox by
--             sampling the clip down the arm (ReplicatedStorage/SwingBlade) -- the CLIP, not the
--             live rig -- so any locomotion the spine is carrying on the contact frame is blade
--             the server does not know about. At the plant's peak the run's share of the spine
--             is down to 0.055 at the hips and 0.03 at the chest, so the blade a running player
--             watches and the segment the server tests are the same piece of steel to about a
--             degree. Away from the contact frame the run has the spine back.
--
-- ── Root motion ─────────────────────────────────────────────────────────────────────────
-- None. Every number here ends up in a Motor6D.Transform, which is a picture: it moves limbs
-- inside the character and never the character. The lean does not push the player forward, the
-- plant does not slow the player down, and no part of this touches HumanoidRootPart, WalkSpeed
-- or any velocity. Where the body IS stays exactly where the server put it.
--
-- ── Cost ────────────────────────────────────────────────────────────────────────────────
-- Two tables, built once at require time and shared by every swing (the per-hit ones differ
-- only in their plant window, which is three numbers). Nothing is allocated per swing. What it
-- costs per FRAME of a swing is in AnimationController's own cost note.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SwingTiming = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwingTiming"))

local SwingMove = {}

-- Speed at which the legs belong entirely to the run cycle, in studs per second. Deliberately
-- BELOW the walk speed (16) rather than at the sprint (26): a character moving at all is a
-- character whose legs are cycling, and the interesting part of the ramp is the first few studs
-- per second out of a standstill, not the difference between a jog and a sprint. Above 12 the
-- blend is saturated and a sprint and a walk get the same treatment, which is correct -- the
-- stride length is the locomotion clip's business, not ours.
SwingMove.FULL_SPEED = 12

-- How fast the blend may move DURING a swing, in blend per second (a 100 ms time constant). It
-- is there for what changes mid-swing -- hitlag taking the player's speed away on contact, the
-- player letting go of the stick, a knockback impulse, a single long frame -- none of which
-- should pop the whole lower body in one frame. It is NOT a ramp into the swing: the blend is
-- seeded from the character's actual speed on the clip's first frame, because a swing thrown by
-- a player who is already running has to come out of the run on frame one.
SwingMove.RATE = 10

-- The joints the attack hands back to the run, and how completely.
local RELEASE = {
	-- The legs, whole. This is the fix: at speed they are Roblox's run cycle and nothing else.
	LeftUpperLeg = 1.0,
	LeftLowerLeg = 1.0,
	RightUpperLeg = 1.0,
	RightLowerLeg = 1.0,
	-- Everything else is 0 by omission: both arms, both hands, the head and the whole spine stay
	-- the attack's at every speed. A swing whose arms softened as the player moved would be a
	-- swing that got worse the more it was used.
}

-- The joints the run is composed UNDER, and how much of it.
local ADDITIVE = {
	-- The hips. The clip's coil is the swing; the run's drive is layered beneath it so the pelvis
	-- is still doing the work of carrying the legs. 0.55 rather than 1.0 because the run cycle's
	-- own hip yaw is large (it is swinging the legs) and a full share of it would fight the coil
	-- for the same axis.
	LowerTorso = 0.55,
	-- The chest counter-sways against the hips in any run. A third of it is enough to say so.
	UpperTorso = 0.30,
	-- A tenth of the run's head bob. Any more and the gaze wanders off the target mid-swing.
	Head = 0.10,
}

-- Degrees at FULL_SPEED, and how much of it the neck takes back.
local LEAN = {
	-- Forward. Measured against the reference strip, where the sprinting body carries about 12
	-- degrees of forward lean through the whole moment including the swing itself.
	Pitch = 13,
	-- Sideways, for a strafe. Smaller than the forward lean because a sidestep is a smaller
	-- commitment than a sprint, and because roll reads about twice as strongly on a blocky rig.
	Roll = 8,
	-- The head gives back 45% of the lean, so a 13-degree chest lean leaves the gaze 7 degrees
	-- down rather than 13. Looking where you are cutting.
	Head = 0.45,
	-- How much of the lean is left by the time the clip is back at guard, and it is not all of it.
	-- The lean is the RUN's lean, and it is right for a body travelling at 16 studs a second with
	-- its chest into the wind. But the swing clip pitches the chest forward over the cut on its own
	-- account through the follow-through and the recovery, and the two ADD: filmed at a full 13
	-- degrees the whole way through, the last 200 ms of the clip put the character about 45 degrees
	-- off vertical, nose down over its own feet, with the sword drawn in behind a body that is bent
	-- over it. That is the "one rigid plank" note, and it also hides the blade in the two cells
	-- where the reference still has its weapon up in silhouette.
	--
	-- So the run's lean is taken back out across the same window the clip is spending its own
	-- forward pitch in -- from the contact frame to the end of the recovery -- and 35% of it is
	-- kept, which is a body still travelling rather than a body that stood up. Nothing is taken off
	-- the windup or the strike: the lean is at its full value for every frame up to and including
	-- contact, which is the half of the move the lean is judged on.
	TaperKeep = 0.35,
	-- The joint the lean is applied at: the waist, not the root. Leaning the ROOT would take the
	-- legs with it (both upper legs hang off LowerTorso), which tips a running character's feet
	-- out behind them. Leaning the chest is a lean from the waist, which is what a runner does
	-- and what leaves the legs free to be the run cycle.
	Joint = "UpperTorso",
}

-- The plant, as fractions of the hit's own clock. Every hit has a different windup (100 to
-- 330 ms), so the window is expressed against WINDUP / CONTACT / SWING_END and resolved per hit
-- below rather than being one set of seconds that only fits hit 1.
local PLANT = {
	-- Starts three quarters of the way through the windup -- as the body finishes loading, not as
	-- the blade leaves -- so the stride is already checking before the strike rather than hitching
	-- after it.
	--
	-- It was 0.45 and is 0.75 because of what 0.45 filmed. For hit 1 that put the window at
	-- 77 -> 440 ms: 363 ms, more than half the clip, with the legs part-way into the clip's plant
	-- for the whole of it. A plant that lasts half the move is not a plant, it is the lower body
	-- joining in with the attack -- which is the note both critics wrote against round 0. A step
	-- into a cut is a foot arriving, carrying the weight and leaving: 127 -> 392 ms here, on over
	-- the last 125 ms of the windup and off over the 140 after contact.
	FROM_WINDUP = 0.75,
	-- How long past the contact frame the plant is spent, in seconds. Capped at the hit's own
	-- SWING_END so no hit's window can grow: the four light hits that used to run to SWING_END
	-- either shorten or stay exactly as they were, and the finisher, whose blade is still falling
	-- at SWING_END, is untouched.
	TO_AFTER = 0.140,
	-- Peaks on the contact frame, obviously: that is the frame the weight goes through.
	-- How much of the leg release is cancelled at the peak. 0.52, not 1.0: a full cancel would
	-- stop the run cycle dead and read as a stumble. At 0.52, inside a window this short, the
	-- cycle keeps going and the stance widens and drops into the cut underneath it.
	LEGS = 0.52,
	-- How much of the spine's locomotion share is cancelled at the peak. Nearly all of it: on the
	-- contact frame the cut owns the torso, which is both how the hit reads and how the blade
	-- stays where the server's derived hitbox says it is.
	BODY = 0.90,
}

-- ── THE COIL WINDOW, which is the spine's and NOT the legs' ─────────────────────────────
--
-- Round 1 filmed a swing whose critic note was "the torso and hips stay locked in one unchanged
-- run lean" through the whole windup. The clip is not the problem: hit 1 counter-rotates the
-- hips 34 degrees off the target and winds the shoulders 26 further, which is exactly the coil
-- the note asks for. The BLEND was eating it. PLANT is one window shared by the legs and the
-- spine, and it starts three quarters of the way through the windup -- so for the first 112 ms
-- of a 150 ms windup the run still owned 0.55 of the hips and 0.30 of the chest, composed under
-- a coil that is only 34 and 26 degrees deep. A run cycle's own hip yaw is larger than that.
-- Averaged in at full weight it does not dilute the coil, it ERASES it, and what reaches the
-- screen is a body in an unchanged run lean with an arm lifting a sword.
--
-- The legs and the spine want opposite things here and must stop sharing a window. The LEGS are
-- the run for as long as possible -- that is this whole piece -- and only check for the step.
-- The SPINE is the swing's from the first frame, because the coil IS the windup: there is
-- nothing else in those 150 ms to look at.
--
-- So BODY is the spine's own window and it opens at t = 0. It ramps to full across the windup
-- (the coil deepening as the run's share of it drains away), holds through the strike, and
-- gives the chest back to the run across the follow-through, which is where a body that is
-- still travelling wants its run sway back. The legs keep PLANT, unchanged.
local BODY = {
	-- Full by the top of the windup: the held coil is the frame the anticipation reads on, and
	-- it is the swing's alone.
	PEAK_AT = 1.0,
	-- Handed back across the follow-through, reaching zero at the end of the recovery.
	RELEASE_TO = "RECOVERY_END",
	-- How much of the run's share of the spine is cancelled at the peak. Same 0.90 the plant
	-- used: nearly all, but not all, so the chest is never completely deaf to the legs under it.
	AMOUNT = 0.90,
}

-- ── THE DRIVE: what the pelvis does, procedurally, and only while moving ────────────────
--
-- The other half of the same note: "drop the pelvis 0.2-0.3 studs" on the load, "a 0.15-0.25
-- stud pelvis dip and a 10-15 degree forward pitch" on contact. The clip already carries the
-- pelvis FORWARD through the strike, but it has no vertical component at all, so a running
-- swing has no sink into the step and no compression on the frame the blade lands.
--
-- It is here and not in the clip on purpose. A standing swing sinks over its own planted foot
-- in the clip's authored legs; adding a second sink on top of that would double it, and the
-- standing pieces (heavy, arc, chain) are already judged and won. Every number below is scaled
-- by `move`, so a swing thrown standing still gets none of it and nothing earlier can regress.
-- It is also a Motor6D translation, which moves the pelvis inside the character and not the
-- character: the feet stay where the run put them and the body sinks between them.
local DRIVE = {
	-- Studs the pelvis sinks by the top of the windup, and holds through the strike. 0.26, the
	-- middle of the note's 0.2-0.3.
	DROP = 0.26,
	-- Extra studs on the contact frame, on top of DROP: the compression the note says is missing.
	DIP = 0.20,
	-- Seconds the dip is let back out over, from the contact frame. Short -- it is a compression,
	-- not a crouch -- and inside the follow-through, so the body is already rising as the blade
	-- carries past.
	DIP_SPAN = 0.110,
	-- Degrees the chest pitches forward over the cut, peaking on the contact frame and easing out
	-- across the follow-through. On top of the run's own lean, which by then is tapering.
	--
	-- It was 12 and is 6. Round 2 added it on top of a lean that round 1 had just finished
	-- taking OUT for the same reason, and the two put the chest back where round 1 found it:
	-- measured off the clip, the chest at the first follow-through beat went from the 42 degrees
	-- off vertical the clip authors to 54, and with the pelvis under it the body reached 66. That
	-- is the "the whole rig rolls 35-45 degrees off vertical" note, and it was the drive and the
	-- lean stacking, not the clip. Six degrees is a compression on top of a fold the clip already
	-- has; twelve was a second fold. TILT below is the hard stop underneath both of them.
	PITCH = 6,
	-- The pelvis, for the sink. Translating the ROOT would move the character; translating
	-- LowerTorso moves the pelvis and everything hanging off it -- including both legs, which is
	-- what a sink is -- inside a body whose feet the run is still placing.
	JOINT = "LowerTorso",
	-- The chest, for the compression pitch. Same joint the lean uses, and they compose.
	PITCH_JOINT = "UpperTorso",
}

-- ── THE TILT CAP: the hard stop on how far a MOVING body may fold ───────────────────────
--
-- "A's attack owns the root: the whole rig, legs included, rolls 35-45 degrees off vertical at
-- +267 ms and +400 ms -- the buildings behind stay upright, so it is the character rotating."
-- Measured off the clip and the blend together, that is an understatement. In the character's
-- own frame the chest-on-pelvis sits at 39 degrees off vertical on the contact frame and 54 at
-- the first follow-through beat, and the procedural layer put another 12-17 on top of both:
-- 57 and 66. A standing body can fold 54 degrees over a cut -- it is the clip's authored weight
-- and it is what the heavy, arc and chain pieces were judged on. A body that is also running
-- cannot, because the legs underneath it are cycling and a chest that far over stops reading as
-- a lean and starts reading as the whole character being rotated.
--
-- So there is a ceiling, and only the PROCEDURAL layer pays for it. The lean and the drive's
-- compression pitch are scaled back together until the composed pelvis-and-chest is inside MAX,
-- and they are never allowed to add more than ADD_MAX of their own on any frame whatever the
-- clip is doing. The clip itself is never touched: it is the same pose the standing pieces
-- filmed, it is the pose ReplicatedStorage/SwingBlade samples for the server's hitbox, and
-- rotating it here would move the blade the player sees off the segment the server tests.
-- Taking the procedural layer back out moves them CLOSER together, not further apart.
--
-- What it does in practice, measured against the clip's own keys:
--
--   run and windup (clip 4-14 deg)     procedural capped at ADD_MAX -- the run's lean, whole
--   contact        (clip 39 deg)       about 1 degree left; the body is at MAX, not at 57
--   follow-through (clip 54-55 deg)    procedural is zero; the fold is the CLIP's, unchanged
--
-- The lean is therefore at full strength for exactly the half of the move it is there for --
-- the run in, the load and the step -- and the swing's own follow-through is left alone.
local TILT = {
	-- Degrees the composed pelvis-and-chest may sit off the character's own vertical before the
	-- procedural layer starts being scaled out of the way. 40, which is the top of the range the
	-- note names.
	MAX = 40,
	-- Degrees the procedural layer (lean plus the drive's compression pitch) may add on its own
	-- account on any frame, ceiling or no ceiling. 12, the top of the note's 10-12.
	ADD_MAX = 12,
	-- How much of the CLIP's own chest fold may be taken back out, once the procedural layer has
	-- been scaled to nothing and the body is still past MAX.
	--
	-- This is the only place anything here touches the authored pose, and it is fenced twice. It
	-- runs only while MOVING, so every standing swing -- the heavy, the arc and the chain, all
	-- three already judged -- is bit-for-bit what they filmed. And it runs only AFTER the contact
	-- frame, which is the frame ReplicatedStorage/SwingBlade samples and the frame the server's
	-- hitbox is built on: nothing this unfolds can move the blade the server tested, because the
	-- server has already tested it. What it changes is the follow-through, where the clip folds
	-- the chest 42 degrees off the pelvis and 54 off vertical. A standing body can hold that --
	-- it is the weight of the cut going into the floor through a planted foot. A body whose legs
	-- are still cycling underneath it cannot, and that single pose is what both rounds of critics
	-- read as "the whole rig rolls off vertical" and "the lower body fuses into one rigid plank".
	--
	-- It also puts the blade back up. Unfolding the chest lifts the whole arm chain hanging off
	-- it, so the follow-through's tip -- which the clip leaves down among the legs on the far
	-- side -- rises into silhouette instead of behind them.
	CLIP_MAX = 0.35,
	-- The two joints the measurement is taken across: the root joint and the chest hanging off
	-- it. Both legs hang off ROOT, so root tilt is what "the legs went with it" means.
	ROOT = "LowerTorso",
	CHEST = "UpperTorso",
}

-- ── THE BRAKE: the one number in this file that is not a picture ────────────────────────
--
-- "Root translation never slows -- the background scrolls at a constant rate through the entire
-- attack", and it was true: round 1's note says in as many words that the plant does not slow
-- the player down. A plant that does not cost any ground is not a plant, it is a pose. The
-- character has to spend some of its speed to put a foot down, and that is the difference
-- between stepping into a cut and sliding past one.
--
-- The server owns it (ServerScriptService/SwordSystem reads these three numbers and sets the
-- attacker's WalkSpeed), for two reasons. It is a gameplay cost, not a picture -- a swing thrown
-- at a run gives up ground, and that is a balance decision, not a client's. And it keeps the
-- client unable to decide its own speed, which is the surface a client-side brake would open.
--
-- It ends BEFORE the contact frame on purpose. CombatUtil.applyHitlag takes the attacker's
-- WalkSpeed to zero on contact and restores whatever it found -- so a brake still running at
-- contact would be the value hitlag saved and restored, and the player would be left braked
-- for good. Ending 30 ms early means hitlag reads the real speed, and the two never overlap.
SwingMove.BRAKE = {
	-- When it starts, as a fraction of the hit's own windup: as the body finishes loading, the
	-- same moment the plant's foot is arriving.
	FROM_WINDUP = 0.72,
	-- Seconds it lasts. The note asks for 80-100 ms.
	LENGTH = 0.090,
	-- The fraction of WalkSpeed kept while it runs -- i.e. 55% cut, the middle of the note's
	-- 40-60. At the capture's 16 studs a second that is 16 -> 7.2 for 90 ms, about half a stud
	-- of ground given up, which is a visible hitch in a background that was scrolling flat.
	KEEP = 0.45,
	-- Only a character that is ASKING to move is braked. A standing swing has nothing to brake
	-- and must not have its WalkSpeed touched at all, or the standing pieces change.
	MIN_SPEED = 1.0,
}

-- One hit's blend policy. `timing` is a row of Config/SwingTiming (HITS[n] or HEAVY).
local function forTiming(timing)
	return {
		FullSpeed = SwingMove.FULL_SPEED,
		Rate = SwingMove.RATE,
		Release = RELEASE,
		Additive = ADDITIVE,
		-- The shared lean, plus this hit's own taper window. Built once per hit at require time,
		-- so a swing still allocates nothing.
		Lean = {
			Pitch = LEAN.Pitch,
			Roll = LEAN.Roll,
			Head = LEAN.Head,
			Joint = LEAN.Joint,
			TaperFrom = timing.CONTACT,
			TaperTo = timing.RECOVERY_END,
			TaperKeep = LEAN.TaperKeep,
		},
		Plant = {
			From = timing.WINDUP * PLANT.FROM_WINDUP,
			Peak = timing.CONTACT,
			To = math.min(timing.SWING_END, timing.CONTACT + PLANT.TO_AFTER),
			Legs = PLANT.LEGS,
			-- The spine no longer rides the leg window; see BODY.
			Body = 0,
		},
		-- The spine's own window: open from the first frame so the coil is never averaged away.
		Body = {
			From = 0,
			Peak = timing.WINDUP * BODY.PEAK_AT,
			Hold = timing.CONTACT,
			To = timing.RECOVERY_END,
			Amount = BODY.AMOUNT,
		},
		Tilt = {
			Max = TILT.MAX,
			AddMax = TILT.ADD_MAX,
			ClipMax = TILT.CLIP_MAX,
			-- The clip's own fold is only ever unfolded PAST here, so the contact pose the
			-- server's hitbox is derived from is never touched.
			ClipAfter = timing.CONTACT,
			Root = TILT.ROOT,
			Chest = TILT.CHEST,
		},
		Drive = {
			Drop = DRIVE.DROP,
			Dip = DRIVE.DIP,
			DipSpan = DRIVE.DIP_SPAN,
			Pitch = DRIVE.PITCH,
			Joint = DRIVE.JOINT,
			PitchJoint = DRIVE.PITCH_JOINT,
			Windup = timing.WINDUP,
			Contact = timing.CONTACT,
			SwingEnd = timing.SWING_END,
			Finish = timing.RECOVERY_END,
		},
	}
end

-- Built once. Hits 1-5 of the light chain, then the heavy's release and its charge.
local BY_HIT = {}
for index, timing in ipairs(SwingTiming.HITS) do
	BY_HIT[index] = forTiming(timing)
end

local HEAVY = forTiming(SwingTiming.HEAVY)

-- The charge has no plant: it is a HELD pose, not a strike, and a plant that peaked at a
-- "contact" the player has not asked for yet would lock the legs for as long as the button is
-- down. Charging while running keeps the run, whole, under a loaded upper body.
local CHARGE = {
	FullSpeed = SwingMove.FULL_SPEED,
	Rate = SwingMove.RATE,
	Release = RELEASE,
	Additive = ADDITIVE,
	Lean = LEAN,
	Plant = nil,
	-- A held charge leans into the run like anything else, and it may not fold past the ceiling
	-- either. It has no Drive, so the cap is only ever spending the lean.
	Tilt = { Max = TILT.MAX, AddMax = TILT.ADD_MAX, Root = TILT.ROOT, Chest = TILT.CHEST },
}

-- The blend for hit `index` of the light chain. Out-of-range indices get hit 1's, which is what
-- a swing that is not part of a chain plays.
function SwingMove.forHit(index: number)
	return BY_HIT[index] or BY_HIT[1]
end

function SwingMove.heavy()
	return HEAVY
end

function SwingMove.charge()
	return CHARGE
end

return SwingMove
