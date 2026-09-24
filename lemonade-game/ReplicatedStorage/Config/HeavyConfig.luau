-- HeavyConfig — the charged heavy attack's gameplay numbers.
--
-- SwingTiming.HEAVY says WHEN the heavy's blade is where; this says HOW MUCH the charge is
-- worth. Every number here is read on the SERVER (ServerScriptService/SwordSystem): the client
-- reads the thresholds too, but only to decide which picture to draw and how bright to make the
-- blade. It cannot ask for damage, a charge level, or a hit.
--
-- ── How a charge is measured ────────────────────────────────────────────────────────────
-- The client sends exactly two messages, "pressed" and "released", and nothing else. The server
-- timestamps both on its own clock, and `held` is the gap between them. There is no number in
-- either message, so there is nothing for a client to inflate: the worst a modified client can
-- do is hold the button for the same time an honest one does.
--
--   held < MIN_CHARGE              a SLIP. The blade was released before the body finished
--                                  loading, so it plays the light M1's own clip and does
--                                  SLIP_DAMAGE of a light hit -- strictly worse than just
--                                  throwing an M1, which is the point of a charge having a floor.
--   MIN_CHARGE .. FULL_CHARGE      charge = 0 .. 1, and every payoff below is lerped across it.
--   held > FULL_CHARGE             charge = 1. Holding longer is not worth more.
--   held > HOLD_LIMIT              the server lets it go itself, so a charge can never be parked.
--
-- The pairs below are {at charge 0, at charge 1}.
return {
	-- Seconds. FULL_CHARGE is 2.6x the light M1's whole windup (SwingTiming.HITS[1].WINDUP,
	-- 170 ms) and 1.4x the finisher's (330 ms): long enough that the held, straining pose is a
	-- decision the player watches themselves make, short enough that it belongs in a fight.
	-- Deepwoken's greatsword heavy charges for ~650 ms; this is a brighter, faster game and its
	-- light chain contacts every ~230 ms, so the heavy is pitched against that cadence, not
	-- against Deepwoken's.
	MIN_CHARGE = 0.12,
	FULL_CHARGE = 0.45,
	HOLD_LIMIT = 2.00,

	-- Damage, as a multiplier in the place ComboConfig.COMBO_DAMAGE_MULT holds for an M1. The
	-- light chain runs 1.00 to 1.30; a full heavy is 2.70, so it is worth a little over two M1s
	-- and costs about three M1s' worth of time (450 ms of charge plus 680 ms of endlag against
	-- three hits' 760 ms). It is the harder, more committal way to spend the same second.
	DAMAGE = { 1.55, 2.70 },
	SLIP_DAMAGE = 0.70, -- of a light hit 1, for a release inside MIN_CHARGE

	-- Knockback impulse, added to whatever the sword itself rolls, exactly as
	-- ComboConfig.COMBO_KNOCKBACK is for the finisher. The finisher throws for 18; a full heavy
	-- throws for 46, which is the only thing in the game that moves a body that far.
	KNOCKBACK = { 12, 46 },

	-- Endlag, the soonest anything may be thrown next. The light chain's is 210-550 ms; a heavy
	-- is 420-680, so a whiffed full heavy is the most punishing thing a player can do.
	ENDLAG = { 0.42, 0.68 },
	SLIP_ENDLAG = 0.34,

	-- The GAMEPLAY freeze on a landed hit (both fighters' WalkSpeed). CombatUtil clamps at
	-- 80 ms, which is where the full charge sits; the light chain runs 20-75.
	HITLAG = { 0.055, 0.080 },

	-- The ANIMATION hold on the contact frame, for the attacker's own swing and the victim's
	-- rig. The light chain holds 60-115 ms; a heavy holds 105-150, and 150 is
	-- ComboConfig.HITSTOP_MAX -- nothing in the game is allowed to hold a body longer.
	-- At 60 fps that is 6.3 to 9 rendered frames of two bodies stopped dead.
	HITSTOP = { 0.105, 0.150 },

	-- The camera kick, aimed along the blade's travel (ComboVFX). The light chain peaks at
	-- 1.8-5.0 degrees; a full heavy is 7.2, which is as far as this game goes -- ten degrees is
	-- a camera fault and a headache, and the kick still springs back inside a third of a second.
	KICK_DEG = { 3.4, 7.2 },
	KICK_STUDS = { 0.20, 0.42 }, -- positional judder after the hold lets go
	KICK_FOV = { 1.8, 3.6 },     -- degrees the field of view is pulled in on contact

	-- How big the WORLD's half of contact is (SwingImpact.hit): the spark burst's count, size,
	-- reach and life, and above 1.15 a short contact FLASH at the point the blade met the body.
	-- A light hit is 1 by definition. Two harsh reads of the heavy said the same thing about its
	-- contact -- "the only evidence of a hit is a floating -81", "no impact VFX" -- and they were
	-- reading a burst tuned to punctuate four M1s a second, which is the wrong size for the one
	-- hit in the game that stops both bodies dead for 150 ms. The flash outlives the hitstop by
	-- design: a hold with nothing drawn in it is a dropped frame, not a payoff.
	HEFT = { 1.9, 3.0 },

	-- ── The charge's own cues (client-side picture only) ────────────────────────────────
	-- Lemonade, not Deepwoken: the blade gathers warm light and lemon motes are drawn IN toward
	-- it, instead of grey wind rings being thrown out. Both ramp with the charge and both stop
	-- the instant it is released or cancelled.
	CUE_LIGHT_BRIGHTNESS = 3.4, -- PointLight brightness at full charge
	CUE_LIGHT_RANGE = 13,       -- studs at full charge
	CUE_BLADE_RATE = 46,        -- particles/second into the blade at full charge
	CUE_GATHER_RATE = 34,       -- particles/second gathering at the feet at full charge
	-- The strain tremble: degrees of high-frequency shake laid on the chest, forearm, hand and
	-- head over the charge clip, scaled by the charge. Small -- a tremble you can NAME is a
	-- glitch -- but it is the difference between a pose that is being held and a pose that has
	-- stopped.
	CUE_TREMBLE_DEG = 1.15,
}
