-- ReplicatedStorage/Config/ComboConfig.luau
-- 5-hit M1 combo system constants with escalating endlag per research
-- See: sword-rpg-combat-systems.md, DESIGN_RULES.md rule #6

return {
	-- Combo hit count
	MAX_COMBO = 5,

	-- ── Endlag per hit (seconds): the soonest the NEXT swing may be thrown ───────────────
	-- This is the cadence, and it is the one number that decides whether a chain BUILDS or just
	-- repeats. It used to be {0.20, 0.20, 0.35, 0.35, 0.50}: flat, then abruptly slower, so the
	-- chain got heavier to throw exactly as it should have been tightening.
	--
	-- Now the first four sit at 280, 250, 230, 240 ms, and each hit's blade also arrives sooner
	-- after its own input than the last one's did (SwingTiming.HITS: contact at 252, 232, 200,
	-- 182 ms). The two together put the contact-to-contact cadence at 280, 238 and 232 ms: one
	-- quarter-second beat, tightening through it. (They were 300/250/210/220: hit 3's 210 cut
	-- hit 3's own follow-through 110 ms after contact, so the chain's middle read as a flicker,
	-- and the 192 ms gap into hit 4 was under the 220-260 ms a swing needs to be SEEN as a swing
	-- at all. Hit 1's 280 cannot go lower without re-timing hit 1 itself: its contact is at 252.)
	--
	-- Then the fifth. Its endlag is 800 ms, and the beat before it is not dead air -- hit 5's own
	-- windup is 380 ms, 260 of them HELD coiled with the blade behind the hip, so the gap from
	-- hit 4's contact to hit 5's is 548 ms of a body visibly loading rather than of waiting.
	-- The 800 covers the finisher's own settle (contact 470, follow-through spent at 680, planted
	-- low by 780): a finisher the player can cancel out of before it has landed its weight is
	-- not a finisher. Deepwoken's greatsword M1 chain measures ~270 ms between hits; hits 1-4
	-- here average 250, and the finisher is what spends the difference.
	ENDLAG = { 0.28, 0.25, 0.23, 0.24, 0.80 },

	-- Damage multiplier per combo hit — later hits deal slightly more
	COMBO_DAMAGE_MULT = { 1.0, 1.0, 1.10, 1.15, 1.30 },

	-- ── Knockback the swing itself carries, by combo index (impulse studs/s) ─────────────
	-- Hits 1-4 are zero, which is what every hit used to be: knockback came only from a sword's
	-- KnockbackBonus roll, and the starter sword rolls 0, so nothing the player hit ever moved.
	-- The finisher throws. It is the one hit that does, on purpose -- a chain whose last blow
	-- visibly launches what it lands on reads as a finisher without needing a caption, and
	-- keeping the first four at zero means the pacing of ordinary fights is untouched and the
	-- enemy cannot be shoved out of reach mid-chain.
	-- This ADDS to the sword's own roll rather than replacing it.
	COMBO_KNOCKBACK = { 0, 0, 0, 0, 18 },

	-- Combo reset window — if no attack within this time, combo resets to 0
	COMBO_RESET_TIME = 1.5, -- [TUNING]

	-- Hitlag duration (seconds) — the GAMEPLAY freeze on a landed hit: both fighters' WalkSpeed
	-- goes to zero for this long (ServerScriptService/CombatUtil.applyHitlag), so neither can
	-- walk out of the moment of contact.
	-- Research: "20-50ms freeze frames — biggest feel-good factor"
	-- The fifth is 75 ms rather than 50: the finisher's gameplay freeze is half again as long as
	-- any other hit's, and it is the number the animation hold below is built on, so raising it
	-- raises both. CombatUtil clamps this to 80 ms, which is where it is aimed.
	HITLAG_DURATION = { 0.020, 0.025, 0.030, 0.040, 0.075 },

	-- ── Hitstop: the ANIMATION hold on the contact frame ────────────────────────────────
	-- The gameplay freeze above stops the feet. This stops the picture: the attacker's swing
	-- clip and the victim's rig both hold, dead still, on the frame the blade passes through,
	-- which is what makes a hit read as force instead of as a blade sliding through a body.
	-- (ReplicatedStorage/Hitstop drives it on the attacker, EnemyAnimator on the victim.)
	--
	-- It is HITLAG_DURATION + this, and the extra is not decoration. 20 ms is 1.2 frames at
	-- 60 fps: a hold that lands inside one rendered frame is a hold nobody can see. The extra
	-- puts the floor at 80 ms (4.8 frames at 60 fps, and two to three whole frames at the
	-- 30 fps a capture or a phone runs at -- at the old 60 ms the hold fell in ONE 30 fps frame
	-- as often as two) and lets the hold still SCALE with the combo: 80, 85, 90, 100, then 135
	-- on the finisher, which is where Deepwoken's heavy sits.
	HITSTOP_EXTRA = 0.060, -- [TUNING] seconds added to HITLAG_DURATION for the animation hold
	-- 150 ms: the finisher holds 135 (75 + 60) and nothing else comes near it.
	HITSTOP_MAX = 0.150,   -- safety clamp: nothing may hold the body longer than this

	-- Hitlag scale — brief scale pulse on the enemy model during freeze.
	-- Still unread by anything, deliberately: on an R6 enemy rig the skeleton's joint offsets
	-- and the leg IK targets are the only thing a scale can act on (the parts themselves cannot
	-- be resized without tearing the joints), and scaling those lifts the feet off the ground.
	-- The pop it was standing in for is delivered by the hitstop hold and the white hit flash.
	HITLAG_SCALE_MULT = 1.08, -- [TUNING]

	-- ── Camera kick on a landed hit ─────────────────────────────────────────────────────
	-- Peak degrees the camera is punched, by combo index. The punch is aimed ALONG the blade's
	-- travel at contact (the server sends the direction, see SwordSystem), split across the
	-- camera's pitch, yaw and roll, so the lens is thrown the way the sword went.
	--
	-- A few degrees is the whole budget. At 60 fps a 3-degree punch that arrives in two frames
	-- and springs back over a fifth of a second is a jolt; ten degrees is a camera fault, and
	-- anything that keeps moving after a quarter of a second is motion sickness.
	-- The fifth was raised to 5.0 while the kick was silently accumulating into the camera's own
	-- orientation (ComboVFX, fixed 2026-09-24): what players saw was far more than 5 degrees, so
	-- that tuning was judged against a bug. Back to 3.2 until it is re-judged with a kick that
	-- actually springs back.
	CAMERA_KICK_DEG = { 1.8, 2.0, 2.3, 2.7, 3.2 }, -- [TUNING]
	-- Positional judder on top of the punch, in studs, by combo index. Small on purpose: the
	-- rotation carries the impact, this only roughens the first few frames of it.
	CAMERA_SHAKE_STUDS = { 0.10, 0.11, 0.13, 0.16, 0.32 }, -- [TUNING]
	-- Field-of-view punch (degrees, pulled IN) at the moment of contact, by combo index.
	CAMERA_FOV_DEG = { 0.8, 0.9, 1.1, 1.3, 2.6 }, -- [TUNING]

	-- ── Perfect timing ──────────────────────────────────────────────────────────────────
	-- Swing again within this long of your endlag expiring and the hit is worth PERFECT_TIMING_
	-- BONUS more. Declared since the combo system was written and read by nothing until now:
	-- SwordSystem measures the gap between endlag expiry and the next Activated, applies the
	-- bonus server-side, and passes a flag out on ComboUpdate so the HUD can say so.
	--
	-- It is the mechanic the new cadence is FOR. The window is a flat 80 ms while the gaps it
	-- sits at the end of shorten 300 -> 250 -> 210 ms, so a chain thrown on the beat is worth
	-- progressively more of the chain's total damage the further into it you get, and the
	-- reward for reading the animation goes up exactly as the animation gets faster.
	--
	-- Nothing about it is client-side: the client cannot ask for the bonus, only swing.
	PERFECT_TIMING_WINDOW = 0.080, -- [TUNING] seconds
	PERFECT_TIMING_BONUS = 0.05,   -- [TUNING] +5% damage

	-- Combo HUD display
	HUD_COLORS = {
		Color3.fromRGB(255, 255, 255),  -- Hit 1: white
		Color3.fromRGB(255, 255, 200),  -- Hit 2: warm white
		Color3.fromRGB(255, 200, 80),   -- Hit 3: gold
		Color3.fromRGB(255, 120, 50),   -- Hit 4: orange
		Color3.fromRGB(255, 50, 50),    -- Hit 5: red
	},

	-- Hit-streak banner (HitStreakGui): counts consecutive landed hits for on-screen
	-- feedback, separate from the 5-hit endlag/damage-mult cycle above. Shares the same
	-- reset window as the swing combo so the banner drops exactly when the combo would.
	STREAK_MIN_DISPLAY = 3, -- hits before the banner appears at all
	STREAK_TIERS = {
		{ min = 3,  label = "",         color = Color3.fromRGB(255, 255, 255) },
		{ min = 10, label = "GREAT",    color = Color3.fromRGB(255, 210, 90) },
		{ min = 20, label = "SAVAGE",   color = Color3.fromRGB(255, 140, 60) },
		{ min = 35, label = "BRUTAL",   color = Color3.fromRGB(255, 80, 60) },
		{ min = 50, label = "GODLIKE",  color = Color3.fromRGB(210, 90, 255) },
	},
}
