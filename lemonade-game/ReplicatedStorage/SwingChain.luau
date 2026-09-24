-- SwingChain — the player's five-hit M1 chain, as five different swings.
--
-- Before this, MAX_COMBO was 5 and there was ONE clip: every hit of the chain replayed the same
-- right-diagonal slash, and `Combo Attack Animation` -- five labelled beats, 178 lines -- was
-- loaded by nothing. That file is gone; this replaces it.
--
-- ── The five ────────────────────────────────────────────────────────────────────────────
--
--   1  Sword Attack Animation   right diagonal, high right -> low left. Its poses, timing and
--                               stance are unchanged -- it is the swing the windup, arc and
--                               hitstop pieces built, and the circle every hit below is carried
--                               round. Only its blade ROLL was touched (see below).
--   2  Sword Attack 2           BACKHAND. Level, left -> right, at chest height, and a RIGHT-LEAD
--                               PIVOT STEP: it coils over a planted left foot with the right leg
--                               peeled back and its heel a third of a stud off the floor, then
--                               swings that leg through and PLANTS THE RIGHT FOOT 1.9 studs in
--                               FRONT of the left under the cut. The opposite lead foot to hit 1,
--                               arrived at by a step the camera watches happen.
--   3  Sword Attack 3           RISING. Chambered at the right hip out of the deepest, WIDEST
--                               base in the chain -- the feet go 3.1 studs apart and the pelvis
--                               sinks to -0.81 -- and then both legs drive and the whole body
--                               stands UP under the cut, the feet planted while the root climbs
--                               0.66 studs. Square throughout: hit 3 is told apart from its
--                               neighbours by WIDTH and HEIGHT, not by a lead foot.
--   4  Sword Attack 4           OVERHEAD, straight down the centreline, FEET TOGETHER THEN
--                               DROPPED. The feet gather to 0.8 studs apart and the legs
--                               straighten for the lift (the tallest pelvis of the first four),
--                               then the chop spreads them to 2.6 and the pelvis FALLS 0.55
--                               studs with the blade into a square brace. The only hit with no
--                               lead foot at all, on purpose: that is what makes it read as a
--                               drop rather than a turn.
--   5  Sword Attack 5           THE FINISHER, and its own move rather than a sixth pass round
--                               hit 1's circle. Both hands draw the blade UP and BACK over the
--                               trailing shoulder until the tip is 4.6 studs above the root and
--                               5.6 behind the spine -- higher and further back than anything
--                               else in the chain reaches -- with the pelvis counter-rotated 44
--                               degrees away from the target, the chest rolled 22 onto its right
--                               under the cocked blade, the body at its FULL HEIGHT on a straight
--                               back leg, the front foot 2.0 studs ahead and LIFTED off the floor
--                               and the gaze held on the target over the leading shoulder. It is
--                               HELD there for 160 ms -- the only still frame in the chain, and
--                               the rhythm break shown by the body rather than by a gap. Then the
--                               hips fire 57 degrees in 45 ms with the chest still 25 behind them,
--                               and the blade comes over the top and down the centreline in one
--                               80 ms pass -- against 150-190 ms for hits 1-4, so contact is a
--                               two-frame smear -- 6.1 studs in front of the root, the furthest
--                               reach in the chain, and on into the floor. The body follows it
--                               down into a LUNGE: the pelvis falls 0.96 studs and drives 1.46
--                               forward, and the front foot lands 3.1 studs in front of the back
--                               one -- the deepest, widest stance anywhere in the chain, arrived
--                               at in 35 ms. The finisher HOLDS that plant for 550 ms, longer
--                               than any other hit's whole clip, so what the chain leaves on
--                               screen is the slam rather than a character back at guard.
--                               1310 ms end to end against hit 1's 660, the widest arc in the
--                               chain (14.44 studs against hit 1's 11.88: 121%), and the only hit the
--                               ground itself answers -- SwordClient fires
--                               ReplicatedStorage/SwingImpact.slam on its ArcEnd marker, the
--                               frame the tip reaches the floor. Its keys are solved from a
--                               posture-and-target spec by tools/swing_finisher_solve.py; the
--                               tool's spec is the design.
--
--                               It replaces a 360-degree level sweep that coiled by dragging the
--                               blade BEHIND THE HIP. That version was the right idea and the
--                               wrong shape: a coil below the waist behind the body is hidden by
--                               the body from any lens that can see the swing, and two rounds of
--                               harsh critics read the fifth hit as the SMALLEST pose in the
--                               strip with "escalation carried by the damage number". Up beats
--                               back, because up is the one direction nothing occludes.
-- ── How they are built, and why not by hand ─────────────────────────────────────────────
--
-- Hit 1's right arm is not readable by eye: its shoulder/elbow/wrist angles are the numeric
-- solution of that chain for a chosen blade tip and blade direction at each key, picked so
-- neighbouring keys reach their poses by the same route (its own header warns that editing
-- them by hand breaks the line). Four more swings hand-authored the same way would be four more
-- chances to break it, and they would drift apart the moment hit 1 was re-solved.
--
-- So they are not re-authored. Each key here names a POSITION ON HIT 1'S CIRCLE -- `s`, a time
-- in hit 1's clip -- and the arm is read out of hit 1 at that position, with hit 1's own easing
-- ignored so `s` is a smooth place on the circle rather than a moment in its timing. The blade's
-- radius from the shoulder, the wrist's relationship to the blade, and the route between
-- neighbouring arm poses are therefore hit 1's, exactly, in every hit.
--
-- What each hit supplies for itself is everything else, and that is where the variety is:
--
--   * `q`, a rotation applied at the SHOULDER. It rotates the arm, the hand and the sword
--     rigidly about the shoulder joint, so it tilts the whole circle without changing its
--     radius or bending the chain. It is what levels hit 2's cut, stands hit 3's up into a
--     rising line and lifts hit 4's overhead straight above the head.
--
--     THE `q` COLUMN IS SOLVED, NOT AUTHORED, and was solved twice. Round 5 of the arc piece
--     found that the sword runs out of the FRONT of the fist (RightGrip's C0 and Tool.Grip
--     cancel), not up out of it as hit 1's wrist keys and this module's first solve both
--     assumed, and re-solved hit 1's wrist for the real grip. Because every hit here borrows
--     hit 1's arm, their blades followed it -- but each `q` was still compensating for the
--     old blade, so every contact landed 2.5-3 studs above where it was designed and hit 2's
--     level backhand had become a rainbow over the head. tools/swing_chain_resolve.py re-solved
--     every `q` of every key up to ArcEnd for the real grip, against the tip and blade direction
--     each key was DESIGNED to have; through the recovery `q` simply unwinds to the last key's
--     small tilt while the borrowed arm does hit 1's own recoil, draw-in and return to guard
--     (the old targets there ended at the old model's idea of guard, which was never right).
--     (That tool's LIFT table belonged to the finisher's earlier 360-degree design, which was
--     replaced whole: the finisher's `q` column now comes from tools/swing_finisher_solve.py,
--     which solves each key from a stated tip direction and blade direction instead.)
--   * the torso. The arm's circle only spans about 100 degrees in the chest's own frame; the
--     rest of every swing is the body. Hit 1 turns 125 degrees of chest through its strike --
--     so hit 2 turns the OTHER way, hit 3 rolls the opposite sign to hit 1 (which is what turns
--     a descending cut into a rising one), hit 4 barely yaws at all and folds 48 degrees of
--     pitch instead, and hit 5 puts a whole revolution through the root joint.
--   * `roll`, the blade's twist about its OWN long axis, added at the wrist. It moves neither
--     the tip nor the blade's direction -- only which way the cutting EDGE faces. Solved per
--     key by tools/swing_edge_resolve.py; see that tool's header for which axis of the sword is
--     the edge and why every swing in the game was leading with the FLAT before it existed.
--   * the root, the legs and the weight -- and this is where the four rounds of critics were
--     pointing. "Across all six hits the hips, shoulders and feet NEVER CHANGE STANCE - only the
--     right arm moves" was measurable and true: the two upper-leg pitches were within a few
--     degrees of each other in every key of every hit, so all four hits stood the same way and
--     the only thing that moved the feet was the pelvis yawing them round together. Each hit now
--     has a stance of its own, authored as WHERE THE FEET ARE in character space and solved into
--     leg angles by tools/swing_stance_resolve.py (the finisher by tools/swing_finisher_solve.py,
--     which uses the same solve). Measured, in studs, as the gap between the feet along the
--     character's forward axis (+ = left foot ahead) and across it:
--
--            hit 1   +0.8 -> +0.3 fore/aft   left-lead step-in       pelvis -0.15 -> -0.33
--            hit 2   +1.3 -> -1.9            RIGHT-lead pivot step   pelvis -0.31 -> -0.70
--            hit 3    0.0, spread 1.0 -> 3.1 wide square base        pelvis -0.81 -> -0.15
--            hit 4    0.0, spread 0.8 -> 2.6 feet together, dropped  pelvis -0.15 -> -0.70
--            hit 5   +1.9 -> +3.1            lunge, front foot flown pelvis -0.13 -> -1.08
--
--     Five different shapes: a step-in, a step across, a widening, a gathering-and-drop, and a
--     lunge. Each hit's first key restates the previous hit's stance at the frame the chain is
--     allowed to cut to it, so the feet hand over without a jump.
--
-- None of it is eyeballed either. Every key states where the blade TIP goes and what posture
-- the pose wants; the root height, root pitch/yaw, chest angles and `q` below are the bounded
-- least-squares solution that puts the tip there with the feet on the floor. `tools/
-- swing_chain_check.py` is the solver and the check: it reproduces this module, the R15 joint
-- offsets and the sword's grip in Python and prints, per key, the tip position, its distance
-- from the shoulder, the plane angle of the cut, the tip's travel per rendered frame and the
-- foot height. Run it after touching anything here.
--
-- Measured with it (real grip, real blade roll), the five contact frames put the tip at
-- (-0.1, +0.7, -5.6), (+1.7, +1.2, -4.9), (+0.8, +2.5, -4.4), (+0.1, +0.9, -4.7) and
-- (+0.7, -1.4, -6.1) -- hit 1 level and diagonal, hit 2 level at the chest, hit 3 at the head,
-- hit 4 straight down the centreline, hit 5 driven DOWN and the furthest forward of the five --
-- all 4.8 to 4.9 studs from the shoulder (so no hit is easier to land than another), with the
-- blade in front of the character on every one of them, and the feet on the floor except where
-- a foot is deliberately in the air. Arc spans 11.9 / 10.4 / 11.2 / 10.2 / 14.4 studs: the
-- finisher's is the widest in the game, ahead of the charged heavy's 13.4.
--
-- The contact tips all moved 0.3-0.6 studs when the blade roll went in, and that is expected
-- rather than drift: the wrist joint sits a third of a stud off the blade's axis, so turning
-- the sword in the fist swings the hand with it. The sword is being HELD differently; the swing
-- is the swing it was.
--
-- ── The clock ───────────────────────────────────────────────────────────────────────────
--
-- Phase times live in Config/SwingTiming.HITS, which the server reads too: the hitbox for hit
-- N fires at hit N's own contact frame, in the volume hit N's blade sweeps. Nothing here is
-- client input -- the server requires this same module and samples it itself.
--
-- ── Cost ────────────────────────────────────────────────────────────────────────────────
-- Four clips built once, at require time: 52 keys, one sample of hit 1 each. Nothing is built
-- per swing and nothing runs per frame that did not run before -- a swing plays one clip
-- whichever hit it is.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SwingTiming = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwingTiming"))
local Base = require(ReplicatedStorage:WaitForChild("Animations"):WaitForChild("Sword Attack Animation"))

local SwingChain = {}

local rad = math.rad

-- Hit 1's keys, sorted, for the linear walk below.
local BASE_TIMES = {}
for t in pairs(Base.Timestamps) do
	table.insert(BASE_TIMES, t)
end
table.sort(BASE_TIMES)

local ARM = { "RightUpperArm", "RightLowerArm", "RightHand" }

-- The right arm at position `s` on hit 1's circle. LINEAR between hit 1's keys on purpose:
-- hit 1's easing is its own timing, and reading through it would make `s` jump (its InCubic
-- into contact puts 90% of one segment into the last third of it). Ignoring it makes `s` a
-- place on the circle, which is what the hits below are steering.
local function armAt(s: number)
	local lo, hi = BASE_TIMES[1], BASE_TIMES[#BASE_TIMES]
	s = math.clamp(s, lo, hi)
	for index = 1, #BASE_TIMES - 1 do
		if s >= BASE_TIMES[index] and s <= BASE_TIMES[index + 1] then
			lo, hi = BASE_TIMES[index], BASE_TIMES[index + 1]
			break
		end
	end
	local alpha = if hi > lo then (s - lo) / (hi - lo) else 0
	local from, to = Base.Timestamps[lo], Base.Timestamps[hi]
	local pose = {}
	for _, part in ipairs(ARM) do
		pose[part] = from[part]:Lerp(to[part], alpha)
	end
	return pose
end

local function rot(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

-- One key of one hit -> the full 13-joint frame the runtime plays.
local function frame(key)
	local arm = armAt(key.s)
	local q = rot(key.q[1], key.q[2], key.q[3])
	local root, chest, head, larm, legs = key.root, key.chest, key.head, key.larm, key.legs
	return {
		-- The root joint: where the body sits over its feet, and how far round it is turned.
		["LowerTorso"] = CFrame.new(root[1], root[2], root[3]) * rot(root[4], root[5], root[6]),
		["UpperTorso"] = rot(chest[1], chest[2], chest[3]),
		["Head"] = rot(head[1], head[2], head[3]),
		-- `q` pre-multiplied: the whole arm, hand and sword turn rigidly about the shoulder.
		["RightUpperArm"] = q * arm.RightUpperArm,
		["RightLowerArm"] = arm.RightLowerArm,
		-- `roll` post-multiplied: the sword turns about its OWN long axis in the fist, so this
		-- moves neither the tip nor the blade's direction -- only which way the cutting EDGE
		-- faces. It is what stops the chain swinging with the flat of the blade leading.
		-- Solved per key by tools/swing_edge_resolve.py; see its header for the edge's axis.
		["RightHand"] = arm.RightHand * rot(0, 0, key.roll or 0),
		["LeftUpperArm"] = rot(larm[1], larm[2], larm[3]),
		["LeftLowerArm"] = rot(larm[4], 0, 0),
		["LeftHand"] = rot(0, 0, larm[5]),
		["RightUpperLeg"] = rot(legs[1], legs[2], legs[3]),
		["RightLowerLeg"] = rot(legs[4], 0, 0),
		["LeftUpperLeg"] = rot(legs[5], legs[6], legs[7]),
		["LeftLowerLeg"] = rot(legs[8], 0, 0),
	}
end

-- ── The four chained swings ─────────────────────────────────────────────────────────────
-- One line per key: t is seconds from the input frame, s is the place on hit 1's circle, q is
-- the shoulder tilt in degrees, root is {x, y, z, pitch, yaw, roll} of the root joint, chest /
-- head / larm / legs are degrees, and ease shapes the segment that STARTS here.
--
-- Read the `s` column down a hit and you can see the swing: it moves one way through the windup
-- and the other through the strike, and it never doubles back across the fast part of the
-- circle during a recovery -- two neighbouring keys on opposite sides of that region send the
-- tip on a detour, and an early cut of hit 3 whipped the blade 5.8 studs in one frame of its
-- RECOVERY, faster than its own strike, for exactly that reason.
SwingChain.HITS = {
		{ Name = "Backhand", Clip = "Sword Attack 2", Windup = 0.105, Contact = 0.232, ArcEnd = 0.330, Length = 0.480, FadeIn = 0.055,
			Keys = {
				{ t = 0, s = 0.41, q = {-22.036, 31.436, 25.263}, root = {-0.2, -0.312, -0.3, -5.334, 36.806, 0}, chest = {-13.933, 16.875, -30.544}, head = {4, -40, 2}, larm = {2, -50, -12, 18, -4}, legs = {-19.862, -0.242, -4.191, -12.32, 27.537, 0.913, 15.213, -12.798}, ease = "InOutQuad", roll = -2.7 },
				{ t = 0.055, s = 0.452, q = {9.900, 38.077, 5.868}, root = {-0.34, -0.468, -0.16, -0.401, 69.03, 0}, chest = {-18.762, 21.568, 1.959}, head = {2, -50, 1}, larm = {4, -54, -16, 22, -5}, legs = {-43.922, -0.764, -20.468, -10.24, 20.388, 1.414, 28.792, -11.985}, ease = "OutQuad", roll = -2.7 },
				{ t = 0.105, s = 0.455, q = {17.094, 35.618, -5.548}, root = {-0.38, -0.517, -0.08, 1.188, 73.985, 0}, chest = {-20.437, 19.201, 9.425}, head = {1, -52, 1}, larm = {5, -56, -18, 24, -5}, legs = {-47.023, -0.852, -22.316, -10.39, 18.646, 1.377, 31.895, -11.348}, ease = "InQuart", roll = -2.7 },
				{ t = 0.135, s = 0.44, q = {13.413, 38.212, -8.706}, root = {-0.3, -0.442, -0.06, 2.095, 51.916, 0}, chest = {-17.321, 27.768, 13.208}, head = {1, -40, 1}, larm = {4, -50, -16, 22, -4}, legs = {-34.638, -0.378, -1.793, -29.467, 26.476, 1.056, 23.468, -11.263}, ease = "InQuart", roll = -2.8 },
				{ t = 0.175, s = 0.4, q = {11.797, 32.831, -13.149}, root = {-0.1, -0.227, -0.22, 3.211, 25.507, 0}, chest = {-15.653, 26.432, 11.719}, head = {0, -18, 0}, larm = {2, -38, -12, 18, -3}, legs = {24.835, 8.501, 12.951, -73.42, 23.189, 0.333, 6.605, -11.5}, ease = "InCubic", roll = -11.5 },
				{ t = 0.232, s = 0.255, q = {-27.660, -2.248, -11.264}, root = {0.16, -0.6, -0.56, 4.957, -22.49, 0}, chest = {-4.02, 1.53, 7.562}, head = {1, 12, 0}, larm = {-2, -16, -6, 12, -1}, legs = {39.916, -0.488, -10.112, -11.3, 6.101, -0.355, -0.565, -69.844}, ease = "Linear", roll = -43.0 },
				{ t = 0.275, s = 0.205, q = {-36.422, 56.477, -28.535}, root = {0.24, -0.699, -0.66, 7.133, -25.36, 0}, chest = {4.289, 14.571, 32.232}, head = {2, 26, 0}, larm = {-4, -2, -2, 8, 0}, legs = {40.26, -0.692, -13.086, -11.909, -10.191, 1.447, 2.661, -62.681}, ease = "Linear", roll = 34.4 },
				{ t = 0.33, s = 0.165, q = {-25.082, 43.364, -35.082}, root = {0.26, -0.688, -0.62, 5.001, -48.571, 0}, chest = {6.475, -6.357, 37.067}, head = {3, 34, 0}, larm = {-5, 6, 0, 6, 1}, legs = {37.871, -0.915, -25.907, -10.135, -17.021, 4.74, 11.987, -49.594}, ease = "InOutQuad", roll = 67.9 },
				{ t = 0.39, s = 0.18, q = {-15.263, 22.218, -32.648}, root = {0.18, -0.508, -0.44, 3.779, -38.09, 0}, chest = {12.21, -2.292, 34.14}, head = {2, 24, 0}, larm = {-4, 4, 0, 8, 1}, legs = {35.692, -0.7, -17.545, -10.473, -0.185, 1.498, 3.165, -56.297}, ease = "InOutQuad", roll = 40.7 },
				{ t = 0.43, s = 0.11, q = {-3.338, 11.852, -23.108}, root = {0.1, -0.357, -0.24, 0.084, -63.144, 0}, chest = {40.222, 32.88, 50}, head = {1, 16, 0}, larm = {-2, 2, -3, 10, 0}, legs = {27.742, -0.817, -24.509, -9.85, -1.174, 1.365, 4.301, -40.936}, ease = "InOutQuad", roll = 22.6 },
				{ t = 0.48, s = 0, q = {-0.059, -0.977, -11.734}, root = {0.02, -0.173, -0.06, -0.596, -5.003, 0}, chest = {-0.349, -3.938, 1.934}, head = {0, 6, 0}, larm = {0, 0, -5, 12, 0}, legs = {19.319, 0.02, 0.327, -12.589, 12.471, -0.277, -2.368, -19.024}, ease = "InOutQuad", roll = 0.0 },
			},
		},
		{ Name = "Rising", Clip = "Sword Attack 3", Windup = 0.100, Contact = 0.200, ArcEnd = 0.320, Length = 0.470, FadeIn = 0.055,
			Keys = {
				{ t = 0, s = 0.165, q = {8.318, 36.292, -71.545}, root = {0.26, -0.689, -0.62, 4.651, -49.143, 0}, chest = {8.206, -7.23, 37.068}, head = {3, 32, 0}, larm = {-5, 6, 0, 6, 1}, legs = {38.016, -0.918, -26.379, -10.083, -16.788, 4.773, 12.067, -49.62}, ease = "InOutQuad", roll = 53.0 },
				{ t = 0.05, s = 0.17, q = {7.918, 34.152, -62.214}, root = {0.1, -0.541, -0.55, 12.64, -36.62, 0}, chest = {10.048, -33.021, -25.024}, head = {-4, 28, -2}, larm = {-6, 22, -14, 34, 2}, legs = {37.848, 0.311, 1.669, -26.778, -28.315, -0.399, -2.005, -28.172}, ease = "OutQuad", roll = 53.0 },
				{ t = 0.1, s = 0.175, q = {7.813, 36.893, -57.239}, root = {0, -0.805, -0.5, 17.345, -38.737, 0}, chest = {12.007, -29.444, -34.005}, head = {-5, 32, -2}, larm = {-8, 26, -16, 38, 3}, legs = {53.722, 7.698, 21.496, -47.492, -35.893, -2.421, -9.915, -33.478}, ease = "InQuart", roll = 53.0 },
				{ t = 0.128, s = 0.19, q = {8.457, 42.965, -58.136}, root = {0, -0.629, -0.44, 11.763, -12.451, 0}, chest = {9.387, -41.433, -29.264}, head = {-3, 18, -1}, larm = {-6, 22, -14, 34, 2}, legs = {34.193, 9.991, 26.137, -51.229, -3.885, -9.821, -24.05, -53.415}, ease = "InQuart", roll = 39.9 },
				{ t = 0.16, s = 0.215, q = {6.651, 36.237, -61.966}, root = {-0.04, -0.385, -0.36, 4.85, 13.267, 0}, chest = {9.886, -27.22, -4.786}, head = {0, 2, 0}, larm = {-2, 10, -10, 26, 1}, legs = {10.528, 5.568, 19.623, -39.024, 24.669, -6.192, -17.3, -46.615}, ease = "InCubic", roll = 32.0 },
				{ t = 0.2, s = 0.252, q = {-34.294, 23.704, -42.752}, root = {-0.08, -0.15, -0.3, 11.319, 18.328, 0}, chest = {-1.395, -30.455, 11.769}, head = {4, -14, 1}, larm = {4, -14, -4, 14, -2}, legs = {-9.597, 0.127, 2.109, -12.615, 1.6, -0.471, -3.567, -20.739}, ease = "Linear", roll = -36.9 },
				{ t = 0.245, s = 0.3, q = {-6.476, 17.774, -48.340}, root = {-0.12, -0.145, -0.26, 15.489, 33.67, 0}, chest = {10.771, -19.966, 27.503}, head = {6, -30, 1}, larm = {8, -30, -2, 8, -3}, legs = {-18.373, -0.227, -4.629, -11.324, 4.541, -0.887, -4.533, -27.855}, ease = "Linear", roll = -38.8 },
				{ t = 0.32, s = 0.355, q = {16.425, 20.320, -52.240}, root = {-0.14, -0.146, -0.22, 17.387, 36.009, 0}, chest = {20.308, 0.624, 32.055}, head = {7, -40, 1}, larm = {10, -40, 0, 6, -4}, legs = {-20.906, -0.333, -7.217, -11.032, 3.829, -1.046, -4.655, -31.064}, ease = "InOutQuad", roll = -38.8 },
				{ t = 0.38, s = 0.4, q = {7.087, 17.128, -47.284}, root = {-0.1, -0.172, -0.18, 13.223, 37.582, 0}, chest = {14.659, -10.432, 19.941}, head = {5, -30, 1}, larm = {7, -30, 0, 10, -3}, legs = {-19.03, -0.399, -7.746, -11.646, 10.397, -0.158, -0.855, -26.57}, ease = "InOutQuad", roll = -60.4 },
				{ t = 0.425, s = 0.52, q = {1.056, 18.391, -34.904}, root = {-0.06, -0.215, -0.1, 8.55, 47.236, 0}, chest = {16.973, 16.934, 10.176}, head = {2, -16, 0}, larm = {3, -16, -2, 12, -1}, legs = {-19.092, -0.582, -11.062, -11.83, 15.148, 0.372, 5.595, -13.332}, ease = "InOutQuad", roll = -57.8 },
				{ t = 0.47, s = 0.66, q = {-0.331, -1.572, -8.228}, root = {-0.02, -0.182, -0.04, 0.478, 2.326, 0}, chest = {0.661, -0.4, -4.021}, head = {1, -8, 0}, larm = {0, 0, -5, 12, 0}, legs = {-4.789, 0.128, 1.482, -15.6, 19.33, -0.011, -0.19, -12.549}, ease = "InOutQuad", roll = -0.0 },
			},
		},
		{ Name = "Overhead", Clip = "Sword Attack 4", Windup = 0.130, Contact = 0.182, ArcEnd = 0.360, Length = 0.520, FadeIn = 0.055,
			Keys = {
				{ t = 0, s = 0.345, q = {10.593, 21.807, -50.669}, root = {-0.14, -0.146, -0.22, 16.296, 38.166, 0}, chest = {21.445, 0.891, 27.74}, head = {7, -38, 1}, larm = {10, -38, 0, 6, -4}, legs = {-20.134, -0.34, -7.353, -11.035, 5.408, -0.937, -4.259, -30.542}, ease = "InOutQuad", roll = -41.5 },
				{ t = 0.06, s = 0.3, q = {14.039, 17.049, -51.552}, root = {-0.08, -0.156, -0.06, 11.149, 41.502, 0}, chest = {33.005, 1.899, 8.329}, head = {2, -18, 0}, larm = {-14, -12, -30, 52, 6}, legs = {-12.004, -0.38, -6.968, -11.981, 8.133, 0.139, 1.066, -20.534}, ease = "OutQuad", roll = -47.5 },
				{ t = 0.1, s = 0.262, q = {6.176, 14.859, -41.438}, root = {-0.02, -0.149, 0.06, 13.899, 24.648, 0}, chest = {42, -2.481, 4.797}, head = {3, -6, 0}, larm = {-24, -6, -34, 64, 8}, legs = {-9.853, -0.364, -6.283, -12.359, 1.311, 0.039, 0.393, -16.962}, ease = "InOutQuad", roll = -40.3 },
				{ t = 0.13, s = 0.25, q = {0.979, 11.421, -28.608}, root = {0, -0.151, 0.1, 15.248, -29.645, 0}, chest = {41.028, -8.592, 3.436}, head = {4, -4, 0}, larm = {-26, -4, -36, 66, 8}, legs = {2.453, 0.005, 0.049, -17.347, -11.875, 0.492, 9.043, -11.997}, ease = "InQuart", roll = -41.4 },
				{ t = 0.152, s = 0.248, q = {-4.290, 8.484, -20.312}, root = {0, -0.151, 0.06, 12.896, -29.989, 0}, chest = {42, -5.448, 8.018}, head = {2, -2, 0}, larm = {-22, -4, -34, 62, 7}, legs = {3.644, -0.059, -0.604, -16.898, -10.467, 0.476, 8.473, -12.198}, ease = "InQuart", roll = -30.2 },
				{ t = 0.182, s = 0.252, q = {-33.041, -7.096, -2.899}, root = {-0.02, -0.281, -0.14, -8.441, -5.384, 0}, chest = {4.471, -0.121, -0.296}, head = {-4, 0, 0}, larm = {-6, 4, -22, 44, 4}, legs = {32.312, 2.094, 7.64, -36.55, 29.708, -2.94, -8.751, -43.155}, ease = "Linear", roll = 43.4 },
				{ t = 0.24, s = 0.3, q = {-31.833, 6.671, 1.052}, root = {-0.03, -0.508, -0.22, -9.071, 1.362, 0}, chest = {-18.239, -17.581, -8.187}, head = {-6, 2, 0}, larm = {-2, 10, -16, 34, 2}, legs = {41.518, 8.901, 16.843, -63.278, 43.688, -7.993, -14.506, -64.795}, ease = "Linear", roll = 36.5 },
				{ t = 0.3, s = 0.35, q = {-43.107, 18.224, 9.472}, root = {-0.04, -0.7, -0.26, -9.365, 12.556, 0}, chest = {-31.834, -33.71, -4.333}, head = {-7, 4, 0}, larm = {0, 16, -12, 28, 1}, legs = {31.106, 15.977, 26.67, -72.679, 55.808, -11.413, -19.206, -69.757}, ease = "Linear", roll = 36.5 },
				{ t = 0.36, s = 0.395, q = {-63.058, 12.269, 23.744}, root = {-0.04, -0.651, -0.24, -10.542, 26.52, 0}, chest = {-21.22, -21.007, -1.381}, head = {-7, 6, 0}, larm = {0, 20, -10, 24, 1}, legs = {18.022, 13.894, 24.697, -68.676, 59.75, -5.543, -11.679, -57.264}, ease = "InOutQuad", roll = 36.5 },
				{ t = 0.42, s = 0.43, q = {-38.275, 9.007, 21.377}, root = {-0.03, -0.437, -0.18, -10.835, 27.625, 0}, chest = {-30.341, 7.598, -3.085}, head = {-5, 4, 0}, larm = {0, 16, -8, 26, 1}, legs = {22.84, 8.732, 17.94, -59.642, 47.133, -1.35, -4.226, -41.137}, ease = "InOutQuad", roll = -12.0 },
				{ t = 0.47, s = 0.54, q = {-20.870, 6.911, 14.936}, root = {-0.02, -0.274, -0.1, -3.543, 48.359, 0}, chest = {-0.195, 46.703, 36.651}, head = {-3, 2, 0}, larm = {0, 8, -6, 18, 0}, legs = {1.753, 1.543, 5.782, -35.67, 24.99, 0.368, 5.23, -13.766}, ease = "InOutQuad", roll = -24.4 },
				{ t = 0.52, s = 0.66, q = {-0.056, 0.311, 11.248}, root = {-0.01, -0.157, -0.04, 0.475, 2.3, 0}, chest = {0.646, -0.406, -3.975}, head = {-1, 2, 0}, larm = {0, 0, -5, 12, 0}, legs = {7.768, 0.147, 1.932, -14.413, 8.352, -0.085, -1.145, -14.171}, ease = "InOutQuad", roll = -0.0 },
			},
		},
		{ Name = "Finisher", Clip = "Sword Attack 5", Windup = 0.360, Contact = 0.440, ArcEnd = 0.480, Length = 1.310, FadeIn = 0.060,
			Keys = {
				{ t = 0, s = 0.3, q = {-31.833, 6.671, 1.052}, root = {-0.03, -0.439, -0.22, -9.071, 1.362, 0}, chest = {-18.239, -17.581, -8.187}, head = {-6, 2, 0}, larm = {-2, 10, -16, 34, 2}, legs = {37.353, 7.425, 16.808, -55.038, 39.491, -6.715, -14.482, -56.707}, ease = "OutQuad", roll = 10.9 },
				{ t = 0.07, s = 0.33, q = {-5.620, -56.273, -11.027}, root = {0.04, -0.341, 0.06, 2, -14, 0}, chest = {-4, -10, 10}, head = {-2, 18, -1}, larm = {-14, 18, -26, 48, 4}, legs = {7.551, 3.808, 10.409, -46.394, 29.269, -2.87, -10.051, -37.966}, ease = "InOutQuad", roll = 10.9 },
				{ t = 0.14, s = 0.32, q = {29.749, -73.844, -54.617}, root = {0.08, -0.207, 0.2, 8, -31, 0}, chest = {6, -13, 18}, head = {-4, 34, -2}, larm = {-30, 8, -30, 62, 7}, legs = {-5.947, 2.315, 17.66, -21.292, 13.642, -0.747, -13.43, -12.233}, ease = "OutQuad", roll = 22.6 },
				{ t = 0.2, s = 0.56, q = {47.471, -34.980, -39.813}, root = {0.1, -0.129, 0.44, 14, -43, 0}, chest = {14, -14, 22}, head = {-8, 48, -3}, larm = {-46, -2, -33, 78, 9}, legs = {-4.143, 1.563, 22.087, -14.359, 7.76, -0.699, -15.41, -11.077}, ease = "OutQuad", roll = 58.5 },
				{ t = 0.36, s = 0.56, q = {46.948, -34.450, -39.700}, root = {0.11, -0.153, 0.45, 15, -45, 0}, chest = {15, -15, 23}, head = {-8, 50, -3}, larm = {-48, -2, -34, 80, 9}, legs = {0.456, 3.466, 23.708, -23.646, 5.555, -0.639, -14.956, -10.76}, ease = "InQuart", roll = 58.5 },
				{ t = 0.405, s = 0.42, q = {49.430, -21.312, 1.418}, root = {0.06, -0.333, 0.04, -2, 14, 0}, chest = {-8, -26, 10}, head = {0, 12, 0}, larm = {-30, 0, -27, 64, 7}, legs = {-25.553, 0.08, 1.576, -11.524, 52.833, 0.172, 4.178, -10.424}, ease = "Linear", roll = 22.9 },
				{ t = 0.44, s = 0.252, q = {62.923, -8.683, 109.087}, root = {-0.05, -0.784, -0.7, -16, 4, 0}, chest = {-26, -6, -6}, head = {6, -2, 0}, larm = {-6, -4, -18, 34, 2}, legs = {-26.049, 0.575, 7.306, -14.753, 66.939, -0.033, -0.56, -12.34}, ease = "Linear", roll = -57.3 },
				{ t = 0.46, s = 0.29, q = {33.947, 17.021, 123.521}, root = {-0.05, -0.889, -0.85, -20, 2, 0}, chest = {-30, -2, -8}, head = {2, 0, 0}, larm = {2, -6, -14, 26, 1}, legs = {-24.87, 0.736, 8.298, -15.924, 75.349, -0.226, -2.291, -16.974}, ease = "OutQuad", roll = -66.9 },
				{ t = 0.48, s = 0.31, q = {40.636, 14.950, 125.232}, root = {-0.05, -0.978, -0.95, -19, 2, 0}, chest = {-28, 2, -8}, head = {-2, 2, 0}, larm = {4, -8, -12, 24, 1}, legs = {-28.706, 0.802, 8.256, -16.895, 83.601, -0.553, -2.496, -30.642}, ease = "OutQuad", roll = -66.9 },
				{ t = 0.57, s = 0.31, q = {35.003, 3.321, 128.738}, root = {-0.05, -1.06, -1.02, -16, 7, 0}, chest = {-22, 8, -8}, head = {-6, 8, 0}, larm = {8, -10, -10, 22, 0}, legs = {-36.639, 0.453, 5.632, -14.922, 85, 0.215, 0.777, -34.694}, ease = "OutQuad", roll = -66.9 },
				{ t = 0.77, s = 0.31, q = {32.937, -0.756, 129.937}, root = {-0.05, -1.043, -1, -15, 9, 0}, chest = {-21, 9, -8}, head = {-6, 8, 0}, larm = {8, -10, -10, 22, 0}, legs = {-37.596, 0.337, 4.404, -14.459, 82.618, 0.567, 2.335, -32.97}, ease = "InOutQuad", roll = -66.9 },
				{ t = 1.03, s = 0.31, q = {30.989, -3.296, 130.561}, root = {-0.05, -1.024, -0.98, -14, 10, 0}, chest = {-20, 10, -8}, head = {-6, 8, 0}, larm = {7, -9, -10, 22, 0}, legs = {-38.168, 0.281, 3.769, -14.228, 80.006, 0.683, 3.073, -30.747}, ease = "InOutQuad", roll = -66.9 },
				{ t = 1.18, s = 0.56, q = {15.494, -1.648, 65.281}, root = {-0.04, -0.462, -0.5, -8, 5, 0}, chest = {-9, 5, -4}, head = {-1, 4, 0}, larm = {3, -5, -7, 16, 0}, legs = {-15.063, 0.625, 4.269, -22.357, 49.721, 0.082, 0.378, -30.089}, ease = "InOutQuad", roll = -44.9 },
				{ t = 1.31, s = 0.66, q = {0.000, 0.000, 8.466}, root = {-0.02, -0.149, 0, 0.314, 2.125, 0}, chest = {0.521, -0.032, -4.158}, head = {0, -6, 0}, larm = {0, 0, -5, 12, 0}, legs = {7.366, 0.135, 1.904, -13.784, 8.505, -0.044, -0.625, -13.735}, ease = "InOutQuad", roll = -0.0 },
			},
		},
}

-- Build each hit into a clip table the runtime can play, once, at require time.
local CLIPS = {}
for index, hit in ipairs(SwingChain.HITS) do
	local timestamps, easing = {}, {}
	for _, key in ipairs(hit.Keys) do
		timestamps[key.t] = frame(key)
		easing[key.t] = key.ease
	end
	CLIPS[index] = {
		Settings = {
			Loop = false,
			Priority = Enum.AnimationPriority.Action,
			-- The legs are authored (the load, the drive off them, the pivot the hips make on
			-- top of them, and the whole of hit 5's turn); the runtime must not straighten them.
			CounterRotateLegs = false,
			FadeIn = hit.FadeIn,
		},
		Easing = easing,
		Markers = {
			{ t = hit.Windup, name = "Swing" },
			{ t = hit.Contact, name = "Contact" },
			{ t = hit.ArcEnd, name = "ArcEnd" },
		},
		Timestamps = timestamps,
	}
end

-- Hit `index` of the chain as a clip table. Hit 1 is the base swing itself, untouched.
function SwingChain.clip(index: number)
	if index <= 1 then
		return Base
	end
	return CLIPS[index - 1]
end

-- The clip NAME for hit `index`, as AnimationController.Play takes it.
function SwingChain.clipName(index: number): string
	if index <= 1 or index > #SwingChain.HITS + 1 then
		return "Sword Attack Animation"
	end
	return SwingChain.HITS[index - 1].Clip
end

-- A sanity check the module runs on itself: every hit's phase times have to match the clock the
-- server reads, or the hitbox fires on a frame the picture is not on.
--
-- It WARNS. It used to assert, and the assert cost round 3 of the chain piece most of a session:
-- a Studio sync left TWO ReplicatedStorage.Config.SwingTiming instances in the place, one of them
-- a stale copy from before the finisher was re-timed, and which one `WaitForChild` hands back is
-- not defined. The client drew the stale one, this line threw, and Luau caches a module's failure
-- -- so every later require of this module, and therefore of all four of `Sword Attack 2..5`,
-- failed with "Requested module experienced an error while loading" for the rest of the session.
-- Four of the five hits in the chain silently stopped animating while the server went on landing
-- all five, which on film is a character standing still while damage numbers climb.
--
-- That is a far worse failure than the drift the check is for: the drift moves a hitbox a frame,
-- the assert deletes the animation. Nothing else in this module reads SwingTiming -- each clip's
-- markers come from its own Windup/Contact/ArcEnd above -- so there is nothing here that has to
-- stop. It says so, loudly, and builds the clips.
for index, hit in ipairs(SwingChain.HITS) do
	local timing = SwingTiming.HITS[index + 1]
	if not (timing and timing.CONTACT == hit.Contact and timing.WINDUP == hit.Windup
		and timing.SWING_END == hit.ArcEnd and timing.RECOVERY_END == hit.Length) then
		warn("SwingChain: hit " .. (index + 1) .. " disagrees with Config/SwingTiming.HITS"
			.. " -- the hitbox and the picture will be a frame or two apart."
			.. " In Studio, check for a duplicate Config.SwingTiming left behind by a sync.")
	end
end

return SwingChain
