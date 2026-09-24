-- Sword Attack Animation — the player's M1, hand-authored in readable phases.
--
-- Replaces the old 1.867 s captured clip, which had ten linear keys, no legs and no
-- anticipation: the blade left on frame 1 and the last 1.37 s was never seen, because the
-- next swing cut it off. This one is 0.66 s long, matches the sword's real cadence, and is
-- shaped like a strike:
--
--   0.000 -> 0.150   WINDUP      the body loads. The hips counter-rotate 34 degrees off the
--                                target, the shoulders wind 26 further (a 26-degree coil),
--                                the weight sinks back onto the right foot with the knee
--                                bending under it, the chest ROLLS 24 degrees onto its right
--                                so the cocked blade stacks high over that shoulder, and the
--                                head turns back to hold the target. The blade never moves
--                                toward the target in this phase.
--   0.150 -> 0.420   THE ARC     the forward drive and its follow-through, below.
--   0.420 -> 0.640   RECOVERY    over-rotation settles, sword drawn back in, guard.
--
-- ── The arc ─────────────────────────────────────────────────────────────────────────────
--
-- The blade sweeps one wide circle in a single plane and the tip stays 4.1 to 4.9 studs out
-- from the shoulder the whole way: one circle, not an arm folding and unfolding.
--
-- That circle is tilted 25 degrees off flat IN THE CHEST'S OWN SPACE, and the chest then
-- ROLLS THROUGH 60 DEGREES under it -- +24 at the top of the windup, -36 at the first beat of
-- the follow-through -- so in the world the cut runs steeply downhill from high over the right
-- shoulder to low past the left hip. That roll is the single change that makes the arc legible
-- from a camera standing on the ground: a slash whose plane is nearly horizontal is edge-on to
-- every such camera and reads as an arm waving, however wide it really is. It also means the
-- shoulder line is never horizontal through the strike, which is the other half of reading the
-- rotation. The arm chain is not touched by it -- the blade's circle in chest space is exactly
-- the circle it was, the chest just carries it round.
--
-- WHERE THE BLADE POINTS (round 5 -- this paragraph replaces one that was wrong). Roblox welds
-- the Handle to the hand with RightGrip: C0 = RightGripAttachment.CFrame, which on the R15 rig
-- is CFrame.new(0, -0.16, 0) * Angles(-90, 0, 0), and C1 = Tool.Grip = Angles(-90, 0, 0)
-- (RuntimeBootstrap). Those two rotations CANCEL: the Handle's axes are the hand's axes, and
-- the blade, which runs down the Handle's -Z, runs down the hand's -Z -- out of the FRONT of
-- the fist, the way the fingers point, not up out of the top of it. The wrist keys used to be
-- solved for a blade along the hand's +Y. Every one of them was 90 degrees off, and the first
-- broadside strip of the swing showed what that does: the blade pointed AT the target through
-- the whole windup, stood straight UP over the head on the contact frame (tip 1.8 studs in
-- front of the root, 2 above it) and then barely moved through the follow-through while the
-- hand slid left underneath it. The body swung; the sword did not.
--
-- The wrist keys below were re-solved against the real grip on a Studio R15 rig
-- (Players:CreateHumanoidModelFromDescription, the same C0/C1 the live character carries):
-- for each key the blade is pointed along the direction listed in its comment, and the wrist
-- rotation is the SMALLEST rotation that takes the hand's -Z there, so neighbouring keys never
-- reach the same direction by opposite routes. Measured on that rig with a 4-stud blade:
--
--   T_LOAD     tip ( 3.0,  2.0,  4.0)   drawn back, climbing, over the right shoulder
--   T_COCK     tip ( 2.8,  3.8,  3.3)   cocked high and back over the shoulder
--   T_HELD     tip ( 2.4,  4.1,  3.3)   held; tip 4.6 from the shoulder
--   T_LEAD     tip ( 2.4,  4.6,  3.0)   hips fire; blade still cocked (4.9 from the shoulder)
--   T_SWEEP    tip ( 4.6,  3.8,  1.0)   the chest brings it over the top, wide to the right
--   T_CONTACT  tip (-0.3,  0.0, -5.8)   THROUGH THE TARGET: level, 5.8 studs in front
--   T_PAST     tip (-2.8, -2.5, -4.9)   driven past the target line, low, out to the left
--   T_SIDE     tip (-3.8, -2.5, -4.2)   out past the left hip, tip a hand above the ground
--   T_THROUGH  tip (-4.4, -1.8, -3.8)   furthest out, level with the body on its left
--   T_SETTLE   tip (-3.3, -0.4, -4.5)   the recoil: back up and in, 1.4 studs
--   T_DRAW     tip (-2.7,  2.1, -4.6)   drawn back in and up across the chest
--   T_HOME     tip ( 1.9,  1.9, -5.4)   almost at guard
--
-- (HRP space: +X the character's right, +Y up, -Z forward.) The tip travels from high over the
-- RIGHT shoulder, out wide to the right, through the target in front and down past the LEFT
-- hip -- 115 degrees between T_SWEEP and T_CONTACT alone -- and it stays 4.2 to 5.3 studs from
-- the shoulder the whole way round: one circle, now in fact and not just in the comments.
-- ReplicatedStorage/SwingBlade samples these same keys, so the server's hitbox moved with it:
-- the contact blade is now the 5.8-stud line in front of the character rather than a post
-- standing up out of the fist 1.8 studs ahead of it.
--
-- The blade's plane angle, measured from the line through the target, and the tip travel into
-- each key:
--
--   T_HELD    170 ms   -110 deg          cocked out and UP over the right shoulder, the chest
--                                        rolled 24 degrees onto that side under it.
--   T_LEAD    200 ms   -104 deg  1.1 st  THE HIPS LEAD. The hips have already swung 42 of
--                                        their 79 degrees (-34 -> +8) and the chest only 8,
--                                        so the coil is DEEPER here (66 degrees) than at the
--                                        top of the windup and the blade has barely moved.
--                                        The body is throwing the sword; the arm has not
--                                        started, and will not for another 50 ms.
--   T_SWEEP   224 ms    -92 deg  1.9 st  hips spent at +26; the CHEST is whipping through
--                                        and dragging the blade after it.
--   T_CONTACT 252 ms    +10 deg  7.4 st  102 DEGREES IN 28 ms, four times the step before it.
--                                        The blade is through the target, the chest has
--                                        SQUARED TO IT (+6 in the world, from -60 at the top
--                                        of the windup: 66 degrees of torso through the
--                                        strike) and is pitched 20 forward and rolled 28 over
--                                        the cut. The server's hit frame.
--   T_PAST    310 ms    +52 deg  3.2 st  FOLLOW-THROUGH 1: driven 42 degrees past the target
--                                        line, the chest keeps turning after the hit (+6 ->
--                                        +36) instead of braking on it, and the roll reaches
--                                        its deepest at -36.
--   T_SIDE    375 ms    +78 deg  1.9 st  FOLLOW-THROUGH 2: 26 degrees. Decelerating.
--   T_THROUGH 440 ms    +94 deg  1.2 st  FOLLOW-THROUGH 3: 16 degrees. The blade finishes out
--                                        to the character's LEFT and level with it rather
--                                        than wrapped round behind -- an arc that ends behind
--                                        the body is an arc no camera in front of it can
--                                        film. The chest reaches +65, its furthest, 59
--                                        degrees past contact. "ArcEnd" fires here.
--   T_SETTLE  510 ms    +76 deg  1.2 st  the OVER-ROTATION comes back: the blade RECOILS
--                                        EIGHTEEN DEGREES BACKWARDS while the chest unwinds
--                                        and the roll comes up out of -30 to -20.
--                                        Nothing is cut back to idle.
--   T_DRAW    565 ms   +120 deg          the sword is drawn back IN across the chest, on a
--                                        3.4-stud radius against the 4.8 it went out on, and
--                                        carrying ON round rather than retracing the cut.
--   T_HOME    615 ms   +168 deg          almost at guard.
--
-- ── Why these times ─────────────────────────────────────────────────────────────────────
--
-- The drive is sampled by eye at roughly 15 frames a second -- that is what a filmstrip of it
-- shows and, near enough, what a player's eye takes out of it. Read at that rate the beats are:
--
--   +133 ms   the cocked pose, blade high over the right shoulder
--   +200 ms   the hips have fired and the blade has moved SIX degrees
--   +267 ms   the blade is THROUGH, 125 degrees later: one frame, and the only fast one
--   +333 ms   41 degrees of follow-through, decelerating
--   +400 ms   23 more, nearly stopped, the chest still 59 degrees past where it hit
--   +467 ms   the recoil: the blade has come BACK off the end of the arc
--
-- One near-unreadable step flanked by a 6-degree step before it and 41 then 23 after: slow-in,
-- a single pass, a long slow-out, and THREE frames of follow-through after the fastest one
-- wherever the sampling happens to land. The follow-through was 148 ms and is now 188 ms purely
-- for that -- an overshoot that only ever falls in one frame is an overshoot nobody can see.
--
-- Per RENDERED frame at 60 fps, from the top of the windup: 1, 5, 6, 16, 94, 12, 12, 12, 9, 7,
-- 7, 7, 5, 4, 4, 4, 0, -5, -7, -4 degrees. One frame six times its neighbour, then eleven
-- frames that only ever slow down, then the recoil.
--
-- Phase times come from ReplicatedStorage/Config/SwingTiming, which the server reads too, so
-- the hitbox fires when the blade passes through, in the volume the blade sweeps, rather than
-- on the click frame in a box in front of the player's feet.
--
-- Conventions: every joint is keyed by the name of the part it drives (that is how
-- AnimationController indexes Motor6Ds), and every value is a rotation in DEGREES about the
-- character's own axes -- R15 rig attachments are axis-aligned, so joint space is character
-- space: +X pitches the limb forward (and the torso back), +Y yaws left, +Z rolls/abducts to
-- the right. "LowerTorso" is the root joint, so its rotation turns the whole body and its
-- translation moves the body over its feet -- that translation is the weight shift.
--
-- The right arm's angles are not eyeballed and are not meant to be read: they are the exact
-- solution of the shoulder/elbow/wrist chain for the tip position and blade direction named in
-- the comment above each key, picked out of all the solutions that reach it by how little the
-- shoulder and wrist have to turn since the previous key. That last part matters: the runtime
-- slerps between keys, so two neighbouring keys solved independently can reach the same place
-- by opposite routes and send the arm on a detour between them -- an earlier cut of this clip
-- had the recovery whipping the tip 6 studs in a single frame for exactly that reason.
-- Editing these by hand will break the line. Edit the line, re-solve. The chest roll added
-- above is safe precisely BECAUSE it is not an arm edit: it moves the whole chain together.
-- Each key's root height was solved so the planted feet sit where they do in the windup's
-- held pose; measured drift across the whole arc is 0.04 studs.
--
-- The roll lives entirely in UpperTorso and never in LowerTorso. LowerTorso is the root joint,
-- so both legs hang off it: rolling it tips the feet off the floor, and the swing would have to
-- buy its plane back with a leg counter-rotation that undoes the weight the legs are there to
-- carry. Rolling the chest costs nothing below the waist.
--
-- CounterRotateLegs is off: the legs are keyed on purpose here (the load onto the back foot,
-- the drive off it, and the pivot the hips make on top of it are most of what makes the
-- swing carry weight), so the runtime must not straighten them back up.
--
-- ── The step-in (round 5) ───────────────────────────────────────────────────────────────
--
-- Filmed broadside for the first time, the cut turned out to be thrown from a body that was
-- standing still under it: the pelvis moved 0.30 studs forward through contact and the front
-- foot never left where the windup put it, so the weight the windup loaded onto the back foot
-- was never SPENT -- the hips pivoted and the chest turned, but nothing went forward. The
-- reference commits the whole body: the pelvis drives forward over a front foot that steps in
-- under the cut, and the chest is bent over it by the end of the drive.
--
-- So from CONTACT to SETTLE the pelvis now goes 0.48 -> 0.56 studs forward (was 0.30 -> 0.38)
-- and 0.04 lower, the front leg pitches 14 forward (was 4) with the knee absorbing at -30 to
-- -35, and the back leg trails 19 to 23 degrees behind the hips (was 11 to 16), straightened,
-- as the leg that has finished pushing. The lean over the cut is 39 degrees at contact (chest
-- -26 on hips -13, was -20 on -9) and 42 at the first follow-through beat. The front foot
-- lands 0.4 studs ahead of where it stood in the windup -- a short step in, not a lunge; a
-- longer one has the feet skating, because nothing here moves the character. It is thirteen
-- joint transforms, and where the body is stays the server's.
--
-- The arm chain is untouched: the whole chain rides forward and down on the pelvis, so the
-- blade's circle in chest space is exactly the circle it was, and the server's derived hitbox
-- (ReplicatedStorage/SwingBlade samples this same clip) moves the ~0.4 studs with it.
--
-- ── WHICH WAY THE EDGE FACES (round 6) ──────────────────────────────────────────────────
--
-- The round-5 re-solve above got the blade POINTING right and left the twist ABOUT that line
-- free -- "the smallest rotation taking the hand's -Z to the designed direction" says nothing
-- about the roll, so it landed wherever the shortest arc happened to leave it. On this clip's
-- contact frame that was 85 degrees out: the component of the blade's sweep along the FLAT's
-- normal measured 0.99 and along the edge 0.12. The sword was being swung like a cricket bat,
-- and the owner said so on sight of a filmstrip.
--
-- So the RightHand keys below now carry a blade ROLL, written on each line as a comment and
-- solved by tools/swing_edge_resolve.py: a rotation of the hand about its own Z (which is the
-- blade's own long axis, because the grip's two rotations cancel) that puts the cutting edge
-- along the direction the blade is sweeping. Measured after it, the edge leads 1.00 of the
-- sweep on the contact frame and on every other key where the blade is moving fast enough to
-- be cutting. The roll ramps back to zero across the last three keys so this clip ends at the
-- same carry angle `Sword Guard Hold` holds and the next swing fades in from; carried instead,
-- it left the sword 131 degrees twisted out of guard and flicked back at the end of every M1.
--
-- NOTHING ELSE ON THIS CLIP CHANGED. Not a phase time, not a root, not a chest, not a leg, not
-- an easing curve, not the shoulder or elbow of the arm -- this swing won its own blind round
-- as the swing_arc piece and the only thing touched here is which way up the blade is held.
-- The tip does move about 0.4 studs on the keys carrying the biggest roll, because the wrist
-- joint sits a third of a stud off the blade's axis and turning the sword in the fist swings
-- the hand with it. That is the sword being held differently, not the swing being changed, and
-- there is no way around it: the blade is welded to the hand.

local SwingTiming = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("SwingTiming"))

local rad = math.rad

-- A joint rotation, in degrees.
local function rot(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

-- The root joint: where the body sits over its feet, plus how it is turned.
local function root(px: number, py: number, pz: number, x: number, y: number, z: number): CFrame
	return CFrame.new(px, py, pz) * CFrame.Angles(rad(x), rad(y), rad(z))
end

-- Phase boundaries (seconds from the input frame).
local T_START = 0
local T_LOAD = 0.066           -- the blade is drawn in and starts to climb
local T_COCK = 0.115           -- deepest point of the coil
local T_HELD = SwingTiming.WINDUP        -- 0.150 — held coil; last frame before the drive
local T_LEAD = 0.180           -- hips fired; the blade has not
local T_SWEEP = 0.204          -- chest whipping through; blade still trailing
local T_CONTACT = SwingTiming.CONTACT    -- 0.232 — blade through the target, fastest frame
local T_PAST = 0.290           -- follow-through 1: driven on past the target line
local T_SIDE = 0.355           -- follow-through 2: decelerating, out on the left
local T_THROUGH = SwingTiming.SWING_END  -- 0.420 — follow-through 3: furthest point
local T_SETTLE = 0.490         -- over-rotation eases back; the blade stops dead
local T_DRAW = 0.545           -- the sword is drawn back in across the chest
local T_HOME = 0.595           -- almost at guard
local T_END = SwingTiming.RECOVERY_END   -- 0.640

return {
	Settings = {
		Loop = false,
		Priority = Enum.AnimationPriority.Action,
		-- The legs are authored; do not counter-rotate them back to vertical.
		CounterRotateLegs = false,
		-- Blend in fast. The stock 0.10 s fade would smear most of the windup.
		FadeIn = SwingTiming.FADE_IN,
	},

	-- Curve across the segment that STARTS at each key. The key spacing already carries most of
	-- the timing; these shape it further. Slow into the strike, then the whole drive and
	-- follow-through are LINEAR and the deceleration comes from the KEY SPACING instead.
	--
	-- That last part is deliberate and was got wrong first. Easing is per segment, so a curve
	-- that ends slow is followed by the next curve starting fast, and the blade's speed jumps
	-- back UP at every key: three OutQuads in a row down the follow-through measured 12, 12, 12,
	-- 12, 10, 6, 3, then 5, 6, 4 degrees per rendered frame -- it slowed down, sped up again and
	-- slowed down again, which is the small hitch that makes motion read as mush. Linear
	-- segments whose keys are spaced 42, 26 then 16 degrees apart measure 12, 12, 12, 9, 7, 7,
	-- 7, 5, 4, 4, 4, 0: one direction, always slowing, to a dead stop.
	Easing = {
		[T_START] = "InOutQuad",  -- the body builds into the load ...
		[T_LOAD] = "OutQuad",     -- ... the blade swings up and decelerates into the coil ...
		[T_COCK] = "InOutQuad",   -- ... then barely moves: the held beat that reads as "loaded"
		[T_HELD] = "InQuart",     -- the hips fire under a coil that still looks held
		[T_LEAD] = "InQuart",     -- the chest catches up and begins to drag the arm
		[T_SWEEP] = "InCubic",    -- still accelerating right up to the moment of contact: this
		                          -- one curve is what puts 94 of the 102 degrees into one frame
		[T_CONTACT] = "Linear",   -- through, at speed: the blade carries past the target
		[T_PAST] = "Linear",      -- the follow-through slows on its key spacing, not on a curve
		[T_SIDE] = "Linear",
		[T_THROUGH] = "InOutQuad", -- the recoil eases in FROM the dead stop and back out to one
		[T_SETTLE] = "InOutQuad",
		[T_DRAW] = "InOutQuad",
		[T_HOME] = "InOutQuad",
	},

	-- Fired by AnimationController as the clip passes them.
	Markers = {
		{ t = T_HELD, name = "Swing" },      -- blade starts forward: whoosh and trail go here
		{ t = T_CONTACT, name = "Contact" }, -- the server's hit frame, on the client's clock
		{ t = T_THROUGH, name = "ArcEnd" },  -- follow-through spent: the trail stops being drawn
	},

	Timestamps = {
		-- ── guard ───────────────────────────────────────────────────────────────────
		[T_START] = {
			["LowerTorso"] = root(0, -0.02, 0, 0, -2, 0),
			["UpperTorso"] = rot(0, -3, 0),
			["Head"] = rot(0, 2, 0),
			["RightUpperArm"] = rot(0, 0, 6),
			["RightLowerArm"] = rot(18, 0, 0),
			["RightHand"] = rot(-0.0, 0.0, -0.0),   -- blade roll 0.0 deg (tools/swing_edge_resolve.py)
			["LeftUpperArm"] = rot(0, 0, -5),
			["LeftLowerArm"] = rot(12, 0, 0),
			["LeftHand"] = rot(0, 0, 0),
			["RightUpperLeg"] = rot(0, 0, 0),
			["RightLowerLeg"] = rot(0, 0, 0),
			["LeftUpperLeg"] = rot(0, 0, 0),
			["LeftLowerLeg"] = rot(0, 0, 0),
		},

		-- ── WINDUP 1/3: the weight drops back and the blade is already climbing ─────
		-- The hips counter-rotate FIRST and the chest follows them: hips -16, chest -33,
		-- and the chest has begun to roll onto its right (+12) to stack the blade up.
		[T_LOAD] = {
			["LowerTorso"] = root(0.05, -0.16, 0.13, 5, -16, 0),
			["UpperTorso"] = rot(5, -17, 12),
			["Head"] = rot(-3, 26, -2),   -- net gaze only 7 deg off the target while the body turns 33
			["RightUpperArm"] = rot(5, -50, 0),
			["RightLowerArm"] = rot(50, 0, 0),
			["RightHand"] = rot(8.0, -45.2, 3.3),   -- blade roll 0.0 deg (tools/swing_edge_resolve.py)
			["LeftUpperArm"] = rot(-12, 18, -28),
			["LeftLowerArm"] = rot(55, 0, 0),
			["LeftHand"] = rot(0, 0, 8),
			["RightUpperLeg"] = rot(7, -5, -4),   -- back leg starts taking it
			["RightLowerLeg"] = rot(-26, 0, 0),
			["LeftUpperLeg"] = rot(10, 5, 5),
			["LeftLowerLeg"] = rot(-5, 0, 0),
		},

		-- ── WINDUP 2/3: deepest coil ────────────────────────────────────────────────
		-- Hips -29, chest -24 further, rolled +20 onto the right: a coil with the blade
		-- cocked HIGH over that shoulder rather than out beside it. The arm angles are
		-- unchanged from the windup piece; the extra counter-rotation is paid for out of
		-- the waist and the extra height out of the roll, so the arm sits where it did.
		[T_COCK] = {
			["LowerTorso"] = root(0.08, -0.24, 0.20, 7, -29, 0),
			["UpperTorso"] = rot(8, -24, 20),
			["Head"] = rot(-5, 42, -3),        -- gaze stays on the target while the body turns off it
			["RightUpperArm"] = rot(40, -35, 0),
			["RightLowerArm"] = rot(80, 0, 0),
			["RightHand"] = rot(-48.5, -19.4, -8.8),   -- blade roll 0.0 deg (tools/swing_edge_resolve.py)
			["LeftUpperArm"] = rot(-18, 28, -40),
			["LeftLowerArm"] = rot(76, 0, 0),
			["LeftHand"] = rot(0, 0, 12),
			["RightUpperLeg"] = rot(11, -8, -6),  -- back leg carries the weight ...
			["RightLowerLeg"] = rot(-38, 0, 0),   -- ... and the knee sinks under it
			["LeftUpperLeg"] = rot(15, 8, 8),     -- front leg light, nearly straight
			["LeftLowerLeg"] = rot(-8, 0, 0),
		},

		-- ── WINDUP 3/3: held. Hips -34, chest -26 further and rolled +24: the coil holds
		-- for 40 ms so a watcher can read it, and the shoulder line is already 24 degrees
		-- off horizontal, which is where the steep plane of the cut comes from. Blade at
		-- plane angle -110, stacked over the right shoulder. Last frame before the drive.
		[T_HELD] = {
			["LowerTorso"] = root(0.11, -0.26, 0.26, 8, -34, 0),
			["UpperTorso"] = rot(9, -26, 24),
			["Head"] = rot(-5, 48, -3),
			["RightUpperArm"] = rot(38, -33, 0),
			["RightLowerArm"] = rot(84, 0, 0),
			["RightHand"] = rot(-53.7, -17.5, -8.9),   -- blade roll 0.0 deg (tools/swing_edge_resolve.py)
			["LeftUpperArm"] = rot(-19, 30, -42),
			["LeftLowerArm"] = rot(78, 0, 0),
			["LeftHand"] = rot(0, 0, 12),
			["RightUpperLeg"] = rot(12, -9, -7),
			["RightLowerLeg"] = rot(-40, 0, 0),
			["LeftUpperLeg"] = rot(16, 9, 9),
			["LeftLowerLeg"] = rot(-7, 0, 0),
		},

		-- ── ARC 1/7 — THE HIPS LEAD ─────────────────────────────────────────────────
		-- Blade at plane angle -104: it has moved six degrees and 1.1 studs. The HIPS have
		-- moved FORTY-TWO (-34 -> +8), thrown by the back knee coming from -40 to -28, and
		-- the chest only eight, so the coil is DEEPER here (66 degrees) than at the top of
		-- the windup. The roll has not started to come over yet either. The hand does not
		-- start for another 50 ms. Body first, sword last.
		[T_LEAD] = {
			["LowerTorso"] = root(0.07, -0.21, 0.14, 2, 8, 0),
			["UpperTorso"] = rot(4, -58, 22),
			["Head"] = rot(-2, 39, -2),
			["RightUpperArm"] = rot(71.6, -28.8, 17.4),
			["RightLowerArm"] = rot(107.3, 0, 0),
			["RightHand"] = rot(-97.1, -30.4, -34.2),   -- blade roll 0.0 deg (tools/swing_edge_resolve.py)
			["LeftUpperArm"] = rot(-16, 20, -38),
			["LeftLowerArm"] = rot(70, 0, 0),
			["LeftHand"] = rot(0, 0, 11),
			["RightUpperLeg"] = rot(4, -8, -6),   -- the back leg is what threw the hips
			["RightLowerLeg"] = rot(-28, 0, 0),
			["LeftUpperLeg"] = rot(12, 8, 8),
			["LeftLowerLeg"] = rot(-12, 0, 0),
		},

		-- ── ARC 2/7 — THE CHEST WHIPS ───────────────────────────────────────────────
		-- Blade at plane angle -92. Hips nearly spent at +26; the chest has covered 30
		-- degrees in 24 ms, is pitching into the cut and has begun to roll over the top of
		-- it (+22 -> +6), and it is dragging the blade after it, which has still only
		-- travelled 1.9 studs. The back leg is extending as it pushes off.
		[T_SWEEP] = {
			["LowerTorso"] = root(0, -0.18, -0.04, -4, 26, 0),
			["UpperTorso"] = rot(-6, -46, 6),
			["Head"] = rot(1, 17, 0),
			["RightUpperArm"] = rot(88.1, -32.5, 37.3),
			["RightLowerArm"] = rot(102.9, 0, 0),
			["RightHand"] = rot(-114.8, -28.3, -8.2),   -- blade roll 34.8 deg (tools/swing_edge_resolve.py)
			["LeftUpperArm"] = rot(-10, 2, -28),
			["LeftLowerArm"] = rot(56, 0, 0),
			["LeftHand"] = rot(0, 0, 8),
			["RightUpperLeg"] = rot(-4, -8, -7),
			["RightLowerLeg"] = rot(-14, 0, 0),
			["LeftUpperLeg"] = rot(8, 8, 7),
			["LeftLowerLeg"] = rot(-18, 0, 0),
		},

		-- ── ARC 3/7 — CONTACT ───────────────────────────────────────────────────────
		-- Blade at plane angle +10, tip 4.85 out -- the widest the arc ever gets. 102
		-- degrees and 7.4 studs of tip travel in the 28 ms since the last key, four times
		-- the step before it. The CHEST HAS SQUARED TO THE TARGET here (+6 in the world,
		-- from -60 at the top of the windup: 66 degrees of torso through the strike), and
		-- it is pitched 20 forward and rolled 28 OVER the cut -- the shoulder line is 28
		-- degrees off horizontal in the opposite direction to the windup's, which is the
		-- 52 degrees of roll that turn a flat slash into a downhill one. The weight has
		-- crossed onto the front foot, which has STEPPED IN 0.4 studs under the cut with the
		-- knee absorbing at -30, the pelvis 0.48 forward and the body bent 39 degrees over the
		-- blade; the back leg trails straight behind it. The server's hit frame.
		[T_CONTACT] = {
			["LowerTorso"] = root(-0.16, -0.33, -0.48, -13, 33, 0),
			["UpperTorso"] = rot(-26, -27, -28),
			["Head"] = rot(4, -5, 2),
			["RightUpperArm"] = rot(66.3, -32.7, -21.3),
			["RightLowerArm"] = rot(74.7, 0, 0),
			["RightHand"] = rot(-139.9, 48.9, -174.4),   -- blade roll 83.1 deg (tools/swing_edge_resolve.py)
			["LeftUpperArm"] = rot(-4, -22, -18),
			["LeftLowerArm"] = rot(40, 0, 0),
			["LeftHand"] = rot(0, 0, 4),
			["RightUpperLeg"] = rot(-19, -7, -8),  -- back leg straight and TRAILING: it has pushed through
			["RightLowerLeg"] = rot(-4, 0, 0),
			["LeftUpperLeg"] = rot(14, 7, 6),     -- front leg steps IN under the cut
			["LeftLowerLeg"] = rot(-30, 0, 0),
		},

		-- ── ARC 4/7 — FOLLOW-THROUGH 1 ─────────────────────────────────────────────
		-- Plane angle +52: the blade is driven 42 degrees PAST the target line, 3.2 studs
		-- of tip travel, and the chest keeps turning after the hit (+6 -> +36 in the world)
		-- and keeps rolling OVER it (-28 -> -36, the deepest of the clip) instead of braking
		-- on it. Lowest point of the arc, out past the left hip.
		[T_PAST] = {
			["LowerTorso"] = root(-0.22, -0.38, -0.56, -12, 43, 0),
			["UpperTorso"] = rot(-30, -7, -36),
			["Head"] = rot(5, -23, 2),
			["RightUpperArm"] = rot(56.6, -25.7, -20.8),
			["RightLowerArm"] = rot(64.5, 0, 0),
			["RightHand"] = rot(-131.9, 30.5, 155.6),   -- blade roll 92.8 deg (tools/swing_edge_resolve.py)
			["LeftUpperArm"] = rot(0, -38, -14),  -- the left arm opens the other way
			["LeftLowerArm"] = rot(28, 0, 0),
			["LeftHand"] = rot(0, 0, 0),
			["RightUpperLeg"] = rot(-23, -6, -8),
			["RightLowerLeg"] = rot(-6, 0, 0),
			["LeftUpperLeg"] = rot(14, 7, 6),
			["LeftLowerLeg"] = rot(-34, 0, 0),    -- front knee still absorbing
		},

		-- ── ARC 5/7 — FOLLOW-THROUGH 2 ─────────────────────────────────────────────
		-- Plane angle +78, 1.9 studs: decelerating, arms opening out, chest at +53 in the
		-- world and still going, still rolled 34 over. The front knee reaches its deepest
		-- absorb of the whole clip.
		[T_SIDE] = {
			["LowerTorso"] = root(-0.24, -0.38, -0.54, -10, 45, 0),
			["UpperTorso"] = rot(-26, 8, -34),
			["Head"] = rot(5, -36, 2),
			["RightUpperArm"] = rot(50.8, -25.7, -18.1),
			["RightLowerArm"] = rot(64.8, 0, 0),
			["RightHand"] = rot(-121.7, 27.4, 140.0),   -- blade roll 92.8 deg (tools/swing_edge_resolve.py)
			["LeftUpperArm"] = rot(2, -48, -14),
			["LeftLowerArm"] = rot(20, 0, 0),
			["LeftHand"] = rot(0, 0, -3),
			["RightUpperLeg"] = rot(-23, -6, -8),
			["RightLowerLeg"] = rot(-8, 0, 0),
			["LeftUpperLeg"] = rot(13, 6, 6),
			["LeftLowerLeg"] = rot(-35, 0, 0),
		},

		-- ── ARC 6/7 — FOLLOW-THROUGH 3 ─────────────────────────────────────────────
		-- Plane angle +94, 1.2 studs: the blade is nearly stopped, finishing out to the
		-- LEFT of the body and level with it, and the CHEST reaches +65 in the world, its
		-- furthest, 59 degrees past where it was at contact and still rolled 30 over.
		-- "ArcEnd" fires here and the trail stops being drawn.
		[T_THROUGH] = {
			["LowerTorso"] = root(-0.23, -0.35, -0.48, -8, 44, 0),
			["UpperTorso"] = rot(-21, 21, -30),
			["Head"] = rot(4, -45, 2),
			["RightUpperArm"] = rot(54.1, -26.4, -9.6),
			["RightLowerArm"] = rot(63.1, 0, 0),
			["RightHand"] = rot(-116.3, 32.3, 142.8),   -- blade roll 92.8 deg (tools/swing_edge_resolve.py)
			["LeftUpperArm"] = rot(3, -52, -12),
			["LeftLowerArm"] = rot(16, 0, 0),
			["LeftHand"] = rot(0, 0, -4),
			["RightUpperLeg"] = rot(-20, -6, -8),
			["RightLowerLeg"] = rot(-10, 0, 0),
			["LeftUpperLeg"] = rot(11, 6, 5),
			["LeftLowerLeg"] = rot(-32, 0, 0),
		},

		-- ── SETTLE: the over-rotation comes back ────────────────────────────────────
		-- Plane angle +76: the blade RECOILS EIGHTEEN DEGREES BACKWARDS off the end of the
		-- follow-through while the chest unwinds, the hips come back from +44 to +31 and the
		-- roll lifts out of -30 to -20, and the front knee comes up out of its absorb. The
		-- base catches up under a body that has stopped throwing, and the sword, having been
		-- thrown past where the body can hold it, comes back. Nothing is cut to idle.
		[T_SETTLE] = {
			["LowerTorso"] = root(-0.15, -0.25, -0.28, -5, 31, 0),
			["UpperTorso"] = rot(-12, 18, -20),
			["Head"] = rot(3, -37, 1),
			["RightUpperArm"] = rot(90.4, -35.9, 14.4),
			["RightLowerArm"] = rot(29.9, 0, 0),
			["RightHand"] = rot(-124.7, 44.7, 169.0),   -- blade roll 92.8 deg (tools/swing_edge_resolve.py)
			["LeftUpperArm"] = rot(1, -44, -10),
			["LeftLowerArm"] = rot(18, 0, 0),
			["LeftHand"] = rot(0, 0, -3),
			["RightUpperLeg"] = rot(-14, -5, -6),
			["RightLowerLeg"] = rot(-11, 0, 0),
			["LeftUpperLeg"] = rot(7, 5, 4),
			["LeftLowerLeg"] = rot(-25, 0, 0),
		},

		-- ── DRAW: the sword comes back IN across the chest ──────────────────────────
		-- On a 3.4-stud radius against the 4.8 it went out on, and carrying ON round the
		-- circle rather than retracing the cut backwards, so the recovery never reads as a
		-- second slash. Nothing here moves faster than 1.6 studs in a rendered frame.
		[T_DRAW] = {
			["LowerTorso"] = root(-0.10, -0.17, -0.16, -2, 22, 0),
			["UpperTorso"] = rot(-5, 13, -10),
			["Head"] = rot(2, -27, 1),
			["RightUpperArm"] = rot(69.1, -28.4, -28.4),
			["RightLowerArm"] = rot(27.4, 0, 0),
			["RightHand"] = rot(-79.1, 19.5, 78.9),   -- blade roll 62.8 deg (tools/swing_edge_resolve.py)
			["LeftUpperArm"] = rot(0, -32, -9),
			["LeftLowerArm"] = rot(22, 0, 0),
			["LeftHand"] = rot(0, 0, -3),
			["RightUpperLeg"] = rot(-10, -5, -6),
			["RightLowerLeg"] = rot(-14, 0, 0),
			["LeftUpperLeg"] = rot(3, 5, 4),
			["LeftLowerLeg"] = rot(-19, 0, 0),
		},

		-- ── HOME: almost at guard, the body still 10 deg round ──────────────────────
		[T_HOME] = {
			["LowerTorso"] = root(-0.05, -0.08, -0.04, -1, 10, 0),
			["UpperTorso"] = rot(-2, 7, -4),
			["Head"] = rot(1, -13, 0),
			["RightUpperArm"] = rot(63.0, -39.7, -19.7),
			["RightLowerArm"] = rot(90.5, 0, 0),
			["RightHand"] = rot(-123.0, -2.2, 31.4),   -- blade roll 35.5 deg (tools/swing_edge_resolve.py)
			["LeftUpperArm"] = rot(-1, -16, -7),
			["LeftLowerArm"] = rot(16, 0, 0),
			["LeftHand"] = rot(0, 0, -1),
			["RightUpperLeg"] = rot(-4, -3, -4),
			["RightLowerLeg"] = rot(-8, 0, 0),
			["LeftUpperLeg"] = rot(0, 3, 3),
			["LeftLowerLeg"] = rot(-11, 0, 0),
		},

		[T_END] = {
			["LowerTorso"] = root(0, -0.02, 0, 0, -1, 0),
			["UpperTorso"] = rot(0, -1, 0),
			["Head"] = rot(0, 1, 0),
			["RightUpperArm"] = rot(2, 2, 6),
			["RightLowerArm"] = rot(20, 0, 0),
			["RightHand"] = rot(-0.0, 0.0, -0.0),   -- blade roll 0.0 deg (tools/swing_edge_resolve.py)
			["LeftUpperArm"] = rot(0, 0, -5),
			["LeftLowerArm"] = rot(12, 0, 0),
			["LeftHand"] = rot(0, 0, 0),
			["RightUpperLeg"] = rot(0, 0, 0),
			["RightLowerLeg"] = rot(0, 0, 0),
			["LeftUpperLeg"] = rot(0, 0, 0),
			["LeftLowerLeg"] = rot(0, 0, 0),
		},
	},
}
