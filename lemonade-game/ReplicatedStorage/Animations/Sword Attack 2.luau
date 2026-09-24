-- Sword Attack 2 — hit 2 of the M1 chain.
--
-- BACKHAND — level, left to right, at chest height, thrown off a RIGHT-LEAD PIVOT STEP.
--
-- The return cut off hit 1. Hit 1's follow-through IS this swing's windup: the blade carries
-- on to the left and up while the body coils over the LEFT foot -- the right leg peels back and
-- out behind it with the heel a third of a stud off the floor -- then the hips fire the other
-- way, the right leg swings through, and the blade comes back level through the target at chest
-- height while THE RIGHT FOOT PLANTS 1.9 STUDS IN FRONT OF THE LEFT. The stagger between the
-- feet runs +1.3 (left ahead) to -1.9 (right ahead): 3.2 studs of change, the biggest in the
-- chain, and the opposite lead foot to hit 1's. The pelvis drops from -0.31 to -0.70 into the
-- brace. Contact tip (+1.7, +1.2, -4.9), 4.9 studs from the shoulder; the blade's EDGE leads
-- the cut (1.00 of the sweep).
--
-- The keyframes are not here. Every hit of the chain is built by ReplicatedStorage/SwingChain
-- from hit 1's own solved arm circle plus this hit's shoulder tilt, torso, weight, STANCE and
-- timing, so the five swings cannot drift apart and re-solving hit 1 re-solves all of them. The
-- spec for this one, with a comment per key, is in that module; the geometry check is
-- tools/swing_chain_check.py.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SwingChain = require(ReplicatedStorage:WaitForChild("SwingChain"))

return SwingChain.clip(2)
