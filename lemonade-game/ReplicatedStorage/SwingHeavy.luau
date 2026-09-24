-- SwingHeavy — the charged heavy attack, as two procedural clips.
--
-- There was no heavy attack of any kind: no binding, no hold, no charge state, no clip. This is
-- the picture half of one. The rules half is ServerScriptService/SwordSystem plus
-- ReplicatedStorage/Config/HeavyConfig; the clock both halves key to is Config/SwingTiming.HEAVY.
--
-- ── The two clips ───────────────────────────────────────────────────────────────────────
--
--   Sword Heavy Charge   620 ms, LOOPING FROM 200 ms. Played the instant the button goes down.
--                        0-200 ms the body drops into the coil and the blade is drawn up behind
--                        the right shoulder; 200-620 ms is the STRAIN, and it loops back to 200
--                        rather than to 0, so a charge held for four seconds keeps breathing
--                        instead of replaying its own entrance or freezing on a pose. Across one
--                        strain cycle the hips coil from 40 to 76 degrees and back, the root
--                        sinks another 0.29 studs and rises again, and the blade is drawn 64
--                        degrees further round and 32 higher: the pose is never still and never
--                        unwinds. Those figures are 1.7x what they were a round ago, because a
--                        harsh read of the filmed strip said the charge "sits at essentially the
--                        same overhead angle" across three cells 167 ms apart -- and it was
--                        right about the picture even though the pose underneath it was moving.
--                        A strain the camera cannot measure is a frozen pose. (AnimationController.Settings.LoopStart is what makes the seam
--                        possible; the key at 620 ms is the key at 200 ms restated exactly.)
--
--   Sword Heavy Strike   820 ms. Played on release. Its FIRST KEY IS THE CHARGE'S PEAK, copied
--                        value for value, so the release cannot pop the arm however long the
--                        charge ran.
--
-- ── Why the release reads as explosive ──────────────────────────────────────────────────
-- Measured off these keys by tools/swing_chain_check.py, against the light M1 (hit 1):
--
--                        heavy      light hit 1
--   input -> contact     185 ms     252 ms      the blade arrives SOONER, because the windup
--                                               has already been paid for
--   fastest frame       10.2 st     7.4 st      at 60 fps, per rendered frame (138%)
--   arc span            12.9 st    11.8 st      and 12.9 against the finisher's 11.8 (110%)
--   degrees swept        346        204         the cock is 12 degrees PAST the spine
--   tip height range     9.4 st     7.1 st      +6.3 behind the head to -3.1 at the floor
--   root travel          0.93 st    0.71 st     the weight, from back-right-down to
--                                               forward-left-down
--
-- The shape of it: 158 ms in which the blade barely moves (4.2 studs of fidget round the top of
-- the coil) while the hips swing 74 degrees underneath it -- the body throwing the sword, with
-- the arm not started yet -- and then one frame of 10.2 studs, and then five decelerating frames
-- of follow-through that end with the tip on the floor.
--
-- WHERE THE BLADE IS AIMED, and why it is not authored here by hand. Round 0 of the heavy piece
-- was built against hit 1 as it stood BEFORE the combo_chain piece re-solved it. Hit 1 then grew
-- to an 11.79-stud arc and the heavy, at 11.18, became the SMALLER swing -- which is the one
-- thing this move is judged on. The cause was geometry: the heavy cocked nearly STRAIGHT UP (74
-- to 78 degrees of elevation) at the shortest radius on hit 1's arm circle, and finished LEVEL
-- with the body instead of down at the floor. Straight up is also the one direction that reads
-- the same from every lens standing on the ground. tools/swing_heavy_solve.py now states, per
-- key, where the tip should POINT from the shoulder (elevation and azimuth) and which place on
-- hit 1's circle to borrow the arm from -- `s`, which is also the lever on the RADIUS, since hit
-- 1's reach runs 3.7 to 5.4 studs -- and least-squares-solves `q` for it against the real grip.
-- The coil now sits at 5.37 studs of reach, 12 degrees past the spine and behind the head; the
-- cut crosses the target level instead of clipping its shoulder; and the follow-through is
-- driven down to a tip height of -3.0, which is exactly where the feet are.
--
-- ── How the keys are built, and why not by hand ─────────────────────────────────────────
-- Exactly as ReplicatedStorage/SwingChain builds the other four hits, and for the same reason:
-- hit 1's shoulder/elbow/wrist angles are a numeric solution, not readable by eye, and a second
-- hand-authored arm would drift away from it the moment hit 1 was re-solved.
--
-- So each key below names a POSITION ON HIT 1'S CIRCLE (`s`, a time in hit 1's clip, read with
-- hit 1's easing ignored so `s` is a place rather than a moment) and the arm is read out of hit
-- 1 there. `q` is a rotation applied AT THE SHOULDER, which tilts that whole circle -- arm, hand
-- and sword together -- without changing its radius or bending the chain. Everything else (the
-- root, the chest, the head, the left arm, the legs) is this swing's own, and is where all the
-- difference lives.
--
-- None of it is eyeballed. Every key states where the blade should POINT from the shoulder
-- (a plane angle and an elevation) and how the body should be standing; `q`, the chest and the
-- root's yaw are the bounded least-squares solution that points it there, and the legs are
-- solved with it so both feet stay within 0.03 studs of the floor through a crouch that drops
-- the body 0.47 studs. tools/swing_chain_check.py reproduces this module, the R15 joint offsets
-- and the sword's grip in Python and prints the tip, the reach, the plane angle, the per-frame
-- travel and the foot height for every key. Run it after touching anything here.
--
-- ── The blade's ROLL (round 6) ──────────────────────────────────────────────────────────
-- `roll` is the sword's twist about its OWN long axis, added at the wrist, and it decides which
-- way the cutting EDGE faces. It moves neither the tip nor the blade's direction, so it is the
-- one column here that can be re-solved without re-litigating any of the geometry above -- and
-- it was, by tools/swing_edge_resolve.py, after the owner spotted the whole game swinging with
-- the flat of the blade leading. The heavy release happened to be the one swing already right
-- (its edge led 1.00 of the sweep before the pass and 1.00 after); the charge never cuts, so it
-- simply holds the carry angle. NOTHING ELSE IN THIS MODULE CHANGED in that pass: the heavy won
-- its own blind round, and its poses, timing and stance are exactly what won it. The two seams
-- this module checks for itself -- the charge's 620 ms key restating its 200 ms key, and the
-- strike's first key BEING the charge's 470 ms peak -- are enforced on the roll column too, by
-- that tool, or the sword would flick on every loop and on every release.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SwingTiming = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwingTiming"))
local Base = require(ReplicatedStorage:WaitForChild("Animations"):WaitForChild("Sword Attack Animation"))

local SwingHeavy = {}

local rad = math.rad

-- Hit 1's keys, sorted, for the linear walk below.
local BASE_TIMES = {}
for t in pairs(Base.Timestamps) do
	table.insert(BASE_TIMES, t)
end
table.sort(BASE_TIMES)

local ARM = { "RightUpperArm", "RightLowerArm", "RightHand" }

-- The right arm at position `s` on hit 1's circle. Linear between hit 1's keys on purpose; see
-- SwingChain.armAt, which is the same function for the same reason.
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

-- One key -> the full 13-joint frame the runtime plays. Identical in shape to SwingChain.frame,
-- so a pose authored for one is readable as a pose for the other.
local function frame(key)
	local arm = armAt(key.s)
	local q = rot(key.q[1], key.q[2], key.q[3])
	local root, chest, head, larm, legs = key.root, key.chest, key.head, key.larm, key.legs
	return {
		["LowerTorso"] = CFrame.new(root[1], root[2], root[3]) * rot(root[4], root[5], root[6]),
		["UpperTorso"] = rot(chest[1], chest[2], chest[3]),
		["Head"] = rot(head[1], head[2], head[3]),
		["RightUpperArm"] = q * arm.RightUpperArm,
		["RightLowerArm"] = arm.RightLowerArm,
		-- `roll` post-multiplied: the sword turns about its OWN long axis in the fist, so the
		-- tip and the blade's direction are untouched and only the cutting EDGE's facing
		-- changes. Solved per key by tools/swing_edge_resolve.py.
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

-- ── The charge ──────────────────────────────────────────────────────────────────────────
-- One line per key: t is seconds from the press, s is the place on hit 1's circle, q is the
-- shoulder tilt in degrees, root is {x, y, z, pitch, yaw, roll} of the root joint, chest / head /
-- larm / legs are degrees, and ease shapes the segment that STARTS here.
--
-- Read the root's y column down the strain: -0.37, -0.50, -0.61, -0.66, -0.52, -0.37. That is
-- the breath, and the y column is not authored -- it is whatever puts the lower foot on the
-- floor under the knees the key folds, so the sink is the crouch and not a number typed in.
-- Read the root's yaw beside it: -40, -55, -69, -76, -57, -40 -- the coil winding against it.
-- Neither ever rests, and at 620 ms the pair is exactly back where it was at 200, which is
-- where the loop rejoins.
--
-- And the blade draws WITH them rather than hanging still above the pose: across one strain
-- cycle the tip climbs from 42 degrees of elevation to 74 and crosses 64 degrees of azimuth,
-- from 140 (behind the right shoulder) round past the spine to -156, which is 1.3 to 2.3 studs
-- of tip between neighbouring keys -- about a third of a stud per rendered frame at the fastest
-- point of it. Visibly alive, nowhere near the speed of a swing (the release's own fastest frame
-- is 10.1), which is the difference between a pose being HELD under load and a pose being
-- frozen. Both halves of that -- the body and the blade -- are 1.7x the last round's, and for
-- the reason given at the top of the file.
SwingHeavy.CHARGE = {
	Name = "Charge", Clip = "Sword Heavy Charge", LoopStart = 0.200, Length = 0.620, FadeIn = 0.050,
	Keys = {
		-- Guard. The pose every other swing starts and ends on, so a charge can be begun out of
		-- an idle, a walk or the tail of an M1 without a step.
		{ t = 0, s = 0.66, q = {8.288, -10.913, -8.009}, root = {0, -0.146, 0, 0, 1.996, 0}, chest = {0.178, -4.312, 2.405}, head = {0, 6, 0}, larm = {0, 0, -5, 12, 0}, legs = {-0.038, 0, 0, -8.037, -0.038, 0, 0, -8.037}, ease = "InOutQuad", roll = -0.0 },
		-- The sword comes off the guard and swings out to the character's right at chest height
		-- (30 degrees up, 58 round) while the knees give 0.07 studs. The body is already sinking.
		{ t = 0.045, s = 0.3, q = {-18.075, -58.666, 0.186}, root = {0.05, -0.202, 0.09, 6, -9.096, 0}, chest = {0.851, -15.317, 52.917}, head = {-1, 12, -1}, larm = {-4, 4, -10, 22, 2}, legs = {11.266, -3.228, -5.675, -17.735, 8.461, 2.945, 4.472, -12.097}, ease = "InOutQuad", roll = -92.8 },
		-- Rising behind: 40 up and 130 round, past the right shoulder. The weight is 0.10 back
		-- and 0.15 down, the hips 18 degrees off the target, and the left hand is on its way
		-- across to the grip.
		{ t = 0.095, s = 0.42, q = {27.734, -46.822, -12.047}, root = {0.1, -0.284, 0.18, 10, -18.295, 0}, chest = {19.914, -39.661, 7.984}, head = {-2, 22, -1}, larm = {-10, 8, -18, 34, 3}, legs = {17.22, -6.528, -9.031, -30.567, 13.06, 6.325, 7.933, -18.652}, ease = "InOutQuad", roll = -92.8 },
		-- Climbing behind the head: 47 up and 152 round, both knees folded 40 and 25, the gaze
		-- turned back onto the target over the leading shoulder.
		{ t = 0.15, s = 0.52, q = {19.890, -63.164, -19.596}, root = {0.17, -0.348, 0.26, 15, -31.999, 0}, chest = {12.842, -24.905, 21.001}, head = {-4, 38, -2}, larm = {-26, -2, -34, 62, 8}, legs = {19.77, -7.899, -9.139, -39.934, 13.753, 7.901, 7.838, -24.5}, ease = "OutCubic", roll = -73.9 },
		-- THE COIL IS FORMED, and this is the loop point. Blade 140 degrees round and 42 up --
		-- behind the right shoulder, tip 4.1 studs above the root and 5.0 behind the spine --
		-- hips 40 off the target, chest rolled 24 onto the right under it, weight 0.28 back and
		-- 0.22 down. It is also the BOTTOM of the strain cycle. Everything from here is strain.
		{ t = 0.2, s = 0.56, q = {7.066, -62.710, -17.686}, root = {0.19, -0.37, 0.28, 17, -40.003, 0}, chest = {14.461, -28.893, 23.921}, head = {-5, 45, -2}, larm = {-31, -5, -39, 71, 9}, legs = {20.535, -8.178, -8.899, -42.943, 13.207, 8.199, 7.498, -26.705}, ease = "InOutQuad", roll = -56.9 },
		-- Pushing. Fifteen more degrees of coil, 0.13 more of sink, and the blade drawn twelve
		-- degrees higher and eighteen further round: 1.9 studs of tip since the loop point.
		{ t = 0.3, s = 0.56, q = {24.198, -47.575, -14.660}, root = {0.241, -0.504, 0.365, 22.1, -55.28, 0}, chest = {19.403, -34.325, 32.424}, head = {-6, 50, -2}, larm = {-36.1, -8.4, -44.1, 79.5, 10.7}, legs = {28.42, -9.975, -7.923, -62.428, 19.869, 13.267, 11.85, -38.495}, ease = "InOutQuad", roll = -56.9 },
		-- Still pushing. This is roughly where a charge that reaches HeavyConfig.FULL_CHARGE
		-- (450 ms) is caught, with the next key 20 ms further on.
		{ t = 0.4, s = 0.56, q = {40.272, -36.554, -10.503}, root = {0.292, -0.612, 0.433, 25.5, -68.83, 0}, chest = {25.37, -39.771, 38.762}, head = {-7, 54, -3}, larm = {-41.2, -11.8, -49.2, 86.3, 12.4}, legs = {36.071, -10.47, -6.68, -78.274, 26.899, 18.251, 16.017, -49.023}, ease = "InOutQuad", roll = -56.9 },
		-- THE PEAK of the cycle: 24 degrees PAST the spine, 74 up -- the tip 5.4 above the root
		-- and 3.1 behind it -- hips 76 off, knees 85 and 54, the body 0.51 studs lower than it
		-- stands. The heavy strike's first key is this key, value for value.
		{ t = 0.47, s = 0.56, q = {54.108, -33.212, -7.889}, root = {0.326, -0.656, 0.467, 27.2, -75.59, 0}, chest = {29.043, -42.85, 42.492}, head = {-7, 57, -3}, larm = {-44.6, -13.5, -52.6, 91.4, 14.1}, legs = {39.553, -10.296, -5.968, -84.693, 29.745, 20.346, 17.582, -53.864}, ease = "InOutQuad", roll = -56.9 },
		-- Giving a little back -- a body cannot hold its own maximum. This is the half of the
		-- breath that makes the other half read as effort rather than as a pose.
		{ t = 0.545, s = 0.56, q = {33.290, -50.607, -3.779}, root = {0.241, -0.519, 0.382, 22.1, -56.97, 0}, chest = {20.704, -35.52, 34.798}, head = {-6, 50, -2}, larm = {-37.8, -8.4, -45.8, 81.2, 10.7}, legs = {29.615, -10.233, -8.001, -64.805, 21.471, 14.146, 12.664, -39.832}, ease = "InOutQuad", roll = -56.9 },
		-- The key at 200 ms, restated exactly, so the loop has no seam.
		{ t = 0.62, s = 0.56, q = {14.799, -68.198, 0.047}, root = {0.19, -0.37, 0.28, 17, -40.003, 0}, chest = {14.461, -28.893, 23.921}, head = {-5, 45, -2}, larm = {-31, -5, -39, 71, 9}, legs = {20.535, -8.178, -8.899, -42.943, 13.207, 8.199, 7.498, -26.705}, ease = "InOutQuad", roll = -56.9 },
	},
}

-- ── The release ─────────────────────────────────────────────────────────────────────────
SwingHeavy.STRIKE = {
	Name = "Strike", Clip = "Sword Heavy Strike",
	Windup = SwingTiming.HEAVY.WINDUP, Contact = SwingTiming.HEAVY.CONTACT,
	ArcEnd = SwingTiming.HEAVY.SWING_END, Length = SwingTiming.HEAVY.RECOVERY_END,
	FadeIn = SwingTiming.HEAVY.FADE_IN,
	Keys = {
		-- The charge's peak, value for value. Nothing moves at the moment of release.
		{ t = 0, s = 0.56, q = {54.108, -33.212, -7.889}, root = {0.326, -0.656, 0.467, 27.2, -75.59, 0}, chest = {29.043, -42.85, 42.492}, head = {-7, 57, -3}, larm = {-44.6, -13.5, -52.6, 91.4, 14.1}, legs = {39.553, -10.296, -5.968, -84.693, 29.745, 20.346, 17.582, -53.864}, ease = "InQuart", roll = -56.9 },
		-- THE LAST LOAD, and the "Swing" marker. The body EXTENDS -- the root comes up 0.50
		-- studs, both knees come most of the way out of the crouch (85 to 30, 54 to 22) -- and
		-- the blade goes another ten degrees round and four higher, to 78 up and 34 past the
		-- spine: its highest point,
		-- 6.3 studs above the root and behind the head, the highest the tip reaches anywhere in
		-- the game. The sword is still travelling AWAY from the target here.
		{ t = 0.07, s = 0.56, q = {41.055, -56.984, 17.700}, root = {0.19, -0.152, 0.33, -3, -85, 0}, chest = {33, -47, 43}, head = {-7, 60, -3}, larm = {-48, -15, -56, 95, 15}, legs = {12, -2, -4, -30, 8, 3, 3, -22}, ease = "InQuart", roll = -50.6 },
		-- THE HIPS FIRE. The root yaw crosses 91 degrees in 60 ms, from -85 to +6, and the chest
		-- counter-rotates to -62 so the coil DEEPENS while the hips are already turning. The
		-- blade has moved 1.6 studs in that time -- the body is throwing the sword, and the arm
		-- has not started.
		{ t = 0.13, s = 0.56, q = {70.752, -48.967, 9.920}, root = {0.05, -0.201, 0.22, -2, 5.997, 0}, chest = {24.173, -61.994, 29.96}, head = {-4, 34, -2}, larm = {-36, -6, -44, 78, 10}, legs = {1.565, -2.384, -4.94, -23.474, -2.738, 2.187, 4.362, -18.498}, ease = "InQuart", roll = 26.1 },
		-- The chest whips through and the blade finally comes over the top: 178 round and 62 up,
		-- 1.2 studs of travel, weight 0.13 forward of where it was. The last frame before
		-- contact, and the blade is still behind the head.
		{ t = 0.158, s = 0.56, q = {90.679, -37.201, 8.968}, root = {-0.08, -0.267, 0.02, -8, 33.978, 0}, chest = {20.25, -46.346, 18.548}, head = {-2, 10, -1}, larm = {-28, 2, -36, 64, 8}, legs = {6.959, -4.706, -8.797, -32.377, 0.665, 4.006, 4.114, -22.625}, ease = "InQuart", roll = 39.5 },
		-- CONTACT. 202 DEGREES IN 27 ms and 11.7 studs of tip -- one rendered frame of 10.2, the
		-- single fastest frame in the game (the light M1's is 7.4, the finisher's 4.5). The blade
		-- comes through LEVEL (5 degrees of elevation, tip 6.5 studs in front of the root) rather
		-- than clipping the target's shoulder, the chest has squared to it and rolled 36 over the
		-- cut, and the whole body has dropped: the root is 0.43 below where it stands and 0.34
		-- forward of where the charge held it. The server's hit frame.
		{ t = 0.185, s = 0.375, q = {18.926, -32.770, 32.227}, root = {-0.2, -0.559, -0.34, -20, 57.146, 0}, chest = {25.829, -7.463, -36.199}, head = {6, -30, 2}, larm = {6, -14, -8, 22, -2}, legs = {-0.062, 9.38, 10.595, -58.663, 37.084, -6.573, 0.828, -59.06}, ease = "Linear", roll = 441.2 },
		-- FOLLOW-THROUGH 1: 36 degrees past the target line and DOWN, 4.5 studs, the tip landing
		-- at -3.06 -- the floor line, where the feet are. The chest keeps turning after the hit
		-- instead of braking on it, and the roll reaches its deepest at -46.
		{ t = 0.25, s = 0.375, q = {8.388, -60.187, 40.438}, root = {-0.26, -0.595, -0.36, -24, 72.908, 0}, chest = {29.583, 13.64, -45.91}, head = {8, -44, 3}, larm = {10, -26, -4, 16, -3}, legs = {-0.824, 8.458, 6.785, -64.469, 37.088, -4.067, 7.015, -59.554}, ease = "Linear", roll = 436.9 },
		-- FOLLOW-THROUGH 2: 32 more degrees, 3.3 studs, the tip skimming the floor out past the
		-- left hip. Decelerating.
		{ t = 0.33, s = 0.375, q = {4.292, -68.676, 44.347}, root = {-0.22, -0.533, -0.28, -21, 85.275, 0}, chest = {24.853, 34.344, -50.465}, head = {8, -52, 3}, larm = {11, -34, -2, 12, -3}, legs = {-3.785, 7.007, 2.213, -59.944, 30.52, -4.682, 6.244, -54.852}, ease = "InOutQuad", roll = 436.9 },
		-- ARC END, 94 degrees past contact and 346 from where the blade started. It comes back up
		-- out of the floor to the character's LEFT and level with it, rather than wrapping round
		-- behind, so a camera in front of the character can still see it. "ArcEnd" fires here and
		-- the trail goes out.
		{ t = 0.43, s = 0.38, q = {11.398, -40.622, 41.343}, root = {-0.14, -0.413, -0.16, -15, 91.643, 0}, chest = {12.003, 48.678, -40.432}, head = {6, -56, 2}, larm = {10, -40, 0, 10, -4}, legs = {-6.67, 5.81, -1.08, -47.535, 22.316, -5.62, 1.653, -44.778}, ease = "InOutQuad", roll = 436.9 },
		-- The over-rotation comes BACK: the blade recoils 14 degrees to a dead stop while the
		-- hips unwind from 92 to 72 and the body starts to stand up out of the cut.
		{ t = 0.54, s = 0.43, q = {15.708, -13.744, 33.101}, root = {-0.08, -0.318, -0.06, -10, 71.796, 0}, chest = {5.877, 34.44, -28.233}, head = {4, -42, 1}, larm = {6, -30, -2, 12, -3}, legs = {-6.604, 4.687, 1.018, -35.005, 16.471, -5.437, -2.821, -34.652}, ease = "InOutQuad", roll = 436.9 },
		-- Drawn in across the chest on a tighter radius than it went out on (3.0 studs against
		-- 4.7): the arm folding back up, not the arc continuing.
		{ t = 0.66, s = 0.575, q = {-4.639, 26.879, 12.433}, root = {-0.03, -0.203, 0.02, -5, 29.977, 0}, chest = {1.651, 13.015, -12.381}, head = {2, -22, 0}, larm = {2, -14, -4, 14, -1}, legs = {-3.895, 2.112, 2.035, -18.915, 4.633, -2.461, -3.733, -20.496}, ease = "InOutQuad", roll = 47.3 },
		-- Guard: hit 1's own, so the heavy hands the body back exactly where every other swing
		-- picks it up.
		{ t = 0.82, s = 0.66, q = {2.080, 25.975, 17.056}, root = {0, -0.146, 0, 0, 2, 0}, chest = {0.156, -4.017, 2.043}, head = {0, 6, 0}, larm = {0, 0, -5, 12, 0}, legs = {-0.038, 0, 0, -8.037, -0.038, 0, 0, -8.037}, ease = "InOutQuad", roll = -0.0 },
	},
}

-- Build both clips once, at require time. 21 keys, one sample of hit 1 each; nothing is built
-- per swing and nothing runs per frame that did not run before.
local function build(spec, markers, loopStart: number?)
	local timestamps, easing = {}, {}
	for _, key in ipairs(spec.Keys) do
		timestamps[key.t] = frame(key)
		easing[key.t] = key.ease
	end
	return {
		Settings = {
			Loop = loopStart ~= nil,
			-- The loop rejoins HERE and not at 0, so the charge's entrance plays once and the
			-- strain cycle repeats. Ignored by every clip that does not set it.
			LoopStart = loopStart,
			Priority = Enum.AnimationPriority.Action,
			-- Both clips author the legs (the crouch, the extension out of it, the lunge the cut
			-- lands on); the runtime must not straighten them.
			CounterRotateLegs = false,
			FadeIn = spec.FadeIn,
		},
		Easing = easing,
		Markers = markers,
		Timestamps = timestamps,
	}
end

local CHARGE_CLIP = build(SwingHeavy.CHARGE, {
	-- Fires once, when the coil is formed and the strain begins; the client uses it to start the
	-- blade's gather cue on the pose rather than on the button.
	{ t = SwingHeavy.CHARGE.LoopStart, name = "Coil" },
}, SwingHeavy.CHARGE.LoopStart)

-- 280 ms: the frame the follow-through's tip reaches the FLOOR (-3.0 in root space, which is
-- where the feet are), between the two keys that drive it down there. The client hangs the
-- heavy's ground gouge on this, the way the finisher hangs its slam on its own ArcEnd. It is a
-- marker and not a key so that re-solving the follow-through cannot silently move the burst off
-- the ground: tools/swing_chain_check.py prints the tip height at 250 and 330 ms, and both are
-- -3.0.
SwingHeavy.STRIKE.Plow = 0.28

local STRIKE_CLIP = build(SwingHeavy.STRIKE, {
	{ t = SwingHeavy.STRIKE.Windup, name = "Swing" },
	{ t = SwingHeavy.STRIKE.Contact, name = "Contact" },
	{ t = SwingHeavy.STRIKE.Plow, name = "Plow" },
	{ t = SwingHeavy.STRIKE.ArcEnd, name = "ArcEnd" },
})

function SwingHeavy.chargeClip()
	return CHARGE_CLIP
end

-- The clip the server samples for the heavy's hitbox and the client plays on release.
function SwingHeavy.strikeClip()
	return STRIKE_CLIP
end

-- The same self-check SwingChain runs: the clip's phase times have to be the clock the server
-- reads, or the hitbox fires on a frame the picture is not on.
do
	-- It WARNS, for the reason SwingChain's matching check warns (see its header): a Studio place
	-- can end up holding TWO Config.SwingTiming instances, WaitForChild picks whichever, and Luau
	-- caches a module's failure -- so an assert here does not report drift, it DELETES the heavy's
	-- animation for the rest of the session while the server goes on landing the hit. Drift moves
	-- a hitbox by one frame; the assert moved the whole picture. Nothing else in this module reads
	-- SwingTiming: every marker below comes from SwingHeavy.STRIKE's own Windup/Contact/ArcEnd.
	local heavy = SwingTiming.HEAVY
	if not (heavy.CONTACT == SwingHeavy.STRIKE.Contact and heavy.WINDUP == SwingHeavy.STRIKE.Windup
		and heavy.SWING_END == SwingHeavy.STRIKE.ArcEnd and heavy.RECOVERY_END == SwingHeavy.STRIKE.Length
		and heavy.CHARGE_LOOP_START == SwingHeavy.CHARGE.LoopStart
		and heavy.CHARGE_LENGTH == SwingHeavy.CHARGE.Length) then
		warn("SwingHeavy: the clips disagree with Config/SwingTiming.HEAVY."
			.. " In Studio, check for a duplicate Config.SwingTiming left behind by a sync.")
	end
	local last = SwingHeavy.CHARGE.Keys[#SwingHeavy.CHARGE.Keys]
	if last.t ~= SwingHeavy.CHARGE.Length then
		warn("SwingHeavy: the charge's last key is not its length, so the loop will jump")
	end
	-- The strike's first key must BE the charge's peak, value for value, or letting go of the
	-- button pops the arm. The peak is named by TIME, not found by matching `s`: the whole strain
	-- cycle now sits at the same place on hit 1's circle (s = 0.56, its longest radius), so a
	-- search for "the charge key with the strike's s" matches six keys and keeps the last of them
	-- -- which is the loop's restatement of the 200 ms key, not the peak. That is what this check
	-- did, and as an assert it did not report the mismatch: it threw, Luau cached the failure, and
	-- every later require of SwingHeavy failed -- taking SwordSystem, every Studio capture stage
	-- and the whole heavy attack down with it for the rest of the session. So: named by time, and
	-- a warn. (The same lesson as SwingChain's SwingTiming check above it.)
	local PEAK_T = 0.47
	local strikeFirst = SwingHeavy.STRIKE.Keys[1]
	local peak
	for _, key in ipairs(SwingHeavy.CHARGE.Keys) do
		if key.t == PEAK_T then
			peak = key
		end
	end
	if not (peak and peak.s == strikeFirst.s and peak.root[2] == strikeFirst.root[2]
		and peak.q[1] == strikeFirst.q[1] and peak.q[2] == strikeFirst.q[2]
		and peak.q[3] == strikeFirst.q[3]) then
		warn("SwingHeavy: the strike's first key is no longer the charge's peak at "
			.. PEAK_T .. " s, so the release will pop")
	end
end

return SwingHeavy
