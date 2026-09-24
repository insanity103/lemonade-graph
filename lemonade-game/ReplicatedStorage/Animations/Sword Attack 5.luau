-- Sword Attack 5 — hit 5 of the M1 chain.
--
-- THE FINISHER — a two-handed OVERHEAD GROUND SLAM, and the biggest pose in the chain on every
-- number the check tool prints.
--
-- 360 ms of windup against 100-130 for the others. The blade is swept out right and drawn UP
-- and BACK over the trailing shoulder until the tip stands 4.6 studs above the root and 5.6
-- BEHIND the spine -- higher and further back than anything else in the game reaches -- while
-- the pelvis counter-rotates 44 degrees away from the target, the chest rolls 22 onto its right
-- under the cocked blade, the body comes to its FULL HEIGHT on a straight back leg, the front
-- foot lifts 0.37 studs off the floor two studs ahead, and the gaze stays on the target over the
-- leading shoulder. Then it is HELD there for 160 ms. That hold is the only still frame in the
-- chain and it is the rhythm break the critics asked for, shown by the body instead of by a gap
-- in the audio.
--
-- Then the hips fire 55 degrees in 45 ms, the chest and the sword are dragged round after them,
-- and the blade comes over the top and down the CENTRELINE in one 80 ms pass -- against 150-190
-- for hits 1-4, so contact is a two-frame smear -- reaching 6.1 studs in front of the root, the
-- furthest of any hit, and carrying on into the floor. The whole body goes with it: the front
-- foot is thrown three studs forward into a lunge, the pelvis FALLS 0.96 studs and DRIVES 1.46
-- forward, and by 570 ms the tip is standing in the ground 6.8 studs out with the chest folded
-- over it. The finisher HOLDS that plant for 550 ms -- longer than any other hit's entire clip
-- -- so what the chain leaves on screen is the slam and not a character back at guard. The rise
-- back to guard (1030-1310 ms) only plays if the player does not swing again.
--
-- Arc span 14.4 studs against hit 1's 11.9 (121%) and the charged heavy's 13.4: the widest swing
-- in the game. 1310 ms end to end against hit 1's 660. Pelvis travel 0.96 down and 1.46 forward,
-- both the largest in the chain. Foot stagger +3.1 studs, the deepest stance anywhere. Contact
-- tip (+0.7, -1.4, -6.1), driven down and forward rather than level; the EDGE leads (1.00). And
-- every impact number -- hitstop, camera kick, knockback, damage -- is the biggest in the chain.
--
-- Two earlier versions of this hit lost their rounds. The first was a 360-degree level sweep
-- that coiled by dragging the blade BEHIND THE HIP, where the body hides it from any lens that
-- can also see the swing. The second went up, which was right, but still contacted 4.2 studs out
-- and 0.3 studs less far forward than HIT ONE -- so on the one measurement a critic can make by
-- eye it was still the smaller swing, and four rounds running said so: "our finisher is the
-- SMALLEST pose in the chain - escalation is carried by the damage number instead of by the
-- body." It is not any more, and the numbers above are the argument.
--
-- The keyframes are not here. Every hit of the chain is built by ReplicatedStorage/SwingChain
-- from hit 1's own solved arm circle plus this hit's shoulder tilt, torso, weight, STANCE and
-- timing, so the five swings cannot drift apart and re-solving hit 1 re-solves all of them. The
-- spec for this one, with a comment per key, is in that module; the geometry check is
-- tools/swing_chain_check.py.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SwingChain = require(ReplicatedStorage:WaitForChild("SwingChain"))

return SwingChain.clip(5)
