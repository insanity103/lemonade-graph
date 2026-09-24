-- SwingTiming — one clock, and one contact geometry, for the sword attack.
--
-- Every number is seconds from the moment the player commits (the click / Tool.Activated),
-- and every part of the swing reads them from here so the picture and the damage cannot drift:
--
--   * the client's procedural clip (ReplicatedStorage/Animations/Sword Attack Animation)
--     keys its phases to WINDUP / CONTACT / SWING_END / RECOVERY_END,
--   * the client fires the whoosh and lights the blade trail on the clip's "Swing" marker at
--     WINDUP, and puts the trail out again on "ArcEnd" at SWING_END,
--   * the server (ServerScriptService/SwordSystem) runs its hitbox at CONTACT, in the volume
--     the blade actually sweeps through on that frame -- ReplicatedStorage/SwingBlade derives
--     that volume from this clock and the clip, so damage lands where the blade is instead of
--     in a fixed box in front of the player's feet.
--
-- The swing still COMMITS on the input frame: the combo advances, the endlag starts and the
-- HUD updates immediately. Only the blade's contact waits for the blade.
return {
	-- Anticipation. The body loads (weight back onto the right foot, shoulders wound away from
	-- the hips, blade cocked up behind the right shoulder, gaze held on the target) and the
	-- blade does not move toward the target until this is over. Deepwoken's light M1
	-- anticipation measures ~125 ms; this is a hair longer so the held beat reads, and the
	-- input still commits on the frame it is pressed.
	WINDUP = 0.150,

	-- The blade is through the target. This is the server's hit frame, and by a wide margin the
	-- fastest frame in the clip: the tip covers 10.2 studs in the 33 ms leading into it, against
	-- 2.0 studs in the step before that and 5.0 in the step after.
	CONTACT = 0.232,

	-- The FOLLOW-THROUGH is spent. Contact is not the end of the swing: the blade is driven on
	-- for another 188 ms and 84 degrees past the target line in three decelerating beats while
	-- the chest keeps rotating 59 degrees further than it had at contact and stays rolled over
	-- the cut. This is where that stops and the recovery begins.
	--
	-- It was 148 ms and is 188 for one reason: sampled at the ~15 frames a second an eye takes
	-- a swing in at, 148 ms of follow-through lands in two frames and, if the sampling phase is
	-- unlucky, in one. An overshoot nobody can see is an overshoot that is not there. At 188 ms
	-- there are three, whatever the phase.
	SWING_END = 0.420,

	-- The body is back at guard; the clip ends here. Between SWING_END and here the over-rotation
	-- comes BACK: the blade eases eighteen degrees backwards to a dead stop while the chest
	-- unwinds from +65 to +49, the hips from +44 to +31 and the roll lifts out of -30 to -20,
	-- and only then is the sword drawn in across
	-- the chest on a tighter radius than it went out on. It is not cut back to idle.
	RECOVERY_END = 0.640,

	-- Blend from the live pose into the clip. Short on purpose: the stock 0.10 s fade would
	-- smear most of the windup, which is the part that has to read.
	FADE_IN = 0.030,

	-- ── Where the blade is on the contact frame ─────────────────────────────────────────
	-- Not here. It is DERIVED, by ReplicatedStorage/SwingBlade, from this clock and the swing
	-- clip itself: the clip is sampled at CONTACT through the same sampler the client plays it
	-- with, walked down the character's own arm with the character's own Motor6Ds, and followed
	-- through the tool's grip weld onto the blade. All this file has to say is WHEN to look and
	-- HOW CLOSE counts.
	--
	-- It used to be a hand-copied table of CFrames. That table was right when it was measured
	-- and wrong the moment the swing was re-timed or the contact pose moved -- and the contact
	-- pose does move: the chest picked up 52 degrees of roll through the strike, which took the
	-- blade with it. A derived hitbox cannot be left behind by the animation it is supposed to
	-- be following.

	-- The blade does not sit still on the contact frame -- it is crossing 102 degrees in 28 ms,
	-- and at that speed a single segment tested once has holes either side of it the width of a
	-- player. These are the moments either side of CONTACT the blade is tested at, in seconds:
	-- just before it arrives, through, and just past. Three is enough because the gap between
	-- the first and the last is under half a stud at the tip.
	CONTACT_SAMPLES = { -0.007, 0, 0.004 },

	-- ── The chain: the other four hits' clocks ──────────────────────────────────────────
	-- The five M1s are five different swings (ReplicatedStorage/SwingChain), so they are five
	-- different clocks. HITS[n] is hit n's, and the four scalars above are HITS[1] restated --
	-- they stay because the single-swing pieces, the trail and Sword Guard Hold all read them,
	-- and because hit 1 is still what a swing that is not part of a chain plays.
	--
	-- Read the CONTACT column down: 252, 232, 200, 182, 440 ms. The first four SHORTEN, which is
	-- most of why the chain accelerates -- each hit's blade arrives sooner after its own input
	-- than the one before it -- and the fifth is nearly twice hit 1's, because the finisher's
	-- windup is 360 ms: 200 of drawing the blade up and back over the trailing shoulder and 160
	-- HELD there, coiled above the head.
	-- Combined with ComboConfig.ENDLAG {280, 250, 230, 240, 800} the contact-to-contact cadence
	-- comes out 260, 218, 212 and then 498 ms: the first four sit inside a quarter-second beat and
	-- tighten through it, and then the big one is telegraphed by a gap more than twice as long.
	--
	-- The finisher's own clock: WINDUP 360 (the release), CONTACT 440 -- an 80 ms pass, two to
	-- three times faster than hits 1-4's, so contact is a two-frame smear -- SWING_END 480, which
	-- is 26 degrees of overshoot past the target line and the frame the tip reaches the floor (the
	-- slam's ground burst fires on it), and RECOVERY_END 1310, of which 480-1030 is the body HELD
	-- in its braced forward lunge over the planted blade -- 550 ms, longer than any other hit's
	-- whole clip, so the chain is left on the slam and not on a guard -- and 1030-1310 the rise
	-- back to guard, which only plays if the player does not swing again.
	--
	-- CLIP is the module under ReplicatedStorage/Animations the client plays for that hit and
	-- the server samples for that hit's hitbox.
	HITS = {
		{ CLIP = "Sword Attack Animation", WINDUP = 0.150, CONTACT = 0.232, SWING_END = 0.420, RECOVERY_END = 0.640, FADE_IN = 0.030 },
		{ CLIP = "Sword Attack 2",         WINDUP = 0.105, CONTACT = 0.232, SWING_END = 0.330, RECOVERY_END = 0.480, FADE_IN = 0.055 },
		{ CLIP = "Sword Attack 3",         WINDUP = 0.100, CONTACT = 0.200, SWING_END = 0.320, RECOVERY_END = 0.470, FADE_IN = 0.055 },
		{ CLIP = "Sword Attack 4",         WINDUP = 0.130, CONTACT = 0.182, SWING_END = 0.360, RECOVERY_END = 0.520, FADE_IN = 0.055 },
		{ CLIP = "Sword Attack 5",         WINDUP = 0.360, CONTACT = 0.440, SWING_END = 0.480, RECOVERY_END = 1.310, FADE_IN = 0.060 },
	},

	-- ── The heavy: one charge clock, one release clock ──────────────────────────────────
	-- The charged attack is not a sixth member of the chain -- it is thrown on its own binding
	-- and it RESETS the chain -- so it has its own clock rather than an HITS[6]. Times are
	-- seconds from the moment the button is RELEASED, not from the press: the charge has no
	-- fixed length (that is the player's decision, and ReplicatedStorage/Config/HeavyConfig
	-- decides what it is worth), so the only moment both halves can key to is the release.
	--
	-- Read it against hit 1's 170 / 252 / 440 / 660. The heavy's blade arrives 67 ms SOONER
	-- after its input, because the windup already happened -- that is what a charge buys, and
	-- it is why the release reads as explosive rather than as a slower light swing.
	HEAVY = {
		-- The clip the body is in while the button is down: ReplicatedStorage/Animations/
		-- Sword Heavy Charge. It loops from LOOP_START to its end forever, so a charge held
		-- past the payoff keeps straining instead of freezing on a pose.
		CHARGE_CLIP = "Sword Heavy Charge",
		CHARGE_LOOP_START = 0.200,
		CHARGE_LENGTH = 0.620,

		CLIP = "Sword Heavy Strike",
		-- The last load. The blade is still going UP and BACK for these 100 ms while the hips
		-- fire underneath it -- it covers 0.9 studs here against 9.6 in the single frame into
		-- contact. The whoosh and the blade trail are lit on this marker.
		WINDUP = 0.100,
		-- The hit frame, and the fastest frame in any swing in the game: the tip crosses 9.6
		-- studs in the 17 ms into it, against the light M1's 6.3.
		CONTACT = 0.185,
		-- The follow-through is spent 245 ms later, 127 degrees past the target line.
		SWING_END = 0.430,
		-- Back at guard. 820 ms end to end, against hit 1's 660 and the finisher's 1180.
		RECOVERY_END = 0.820,
		-- Short: the body is already in the pose the strike starts from (the strike's first key
		-- IS the charge's peak), so there is nothing to blend away.
		FADE_IN = 0.035,
	},

	-- How far a target's root may be from one of those blade segments and still be cut. This is
	-- the hitbox, and the only generosity in it: the broad-phase box around the segments exists
	-- to hand GetPartBoundsInBox something cheap to reject, not to decide anything.
	--
	-- Reach against the old 6x5x6 box three studs in front of the root, measured as the set of
	-- standing-enemy root positions that land a hit: 45 square studs against 56, so TIGHTER
	-- overall, reaching 7.9 studs along the blade's own line against 7.6 and giving up the
	-- corners the old box had out to either side of the player. The blade decides now.
	BLADE_RADIUS = 2.3,

	-- How close the blade must come to an enemy's BODY -- any of its parts, measured to that part's
	-- real box -- to cut it, across the whole swing (SwingBlade.sweep). The blade's own half-width
	-- plus a little grace for the server seeing the enemy a frame behind the client. BLADE_RADIUS
	-- above now only pads the broad-phase box and the capture stages' contact-frame geometry.
	BLADE_TOUCH = 1.2,
}
