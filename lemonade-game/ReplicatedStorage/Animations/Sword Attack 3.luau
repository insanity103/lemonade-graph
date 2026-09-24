-- Sword Attack 3 — hit 3 of the M1 chain.
--
-- RISING — low at the right hip, up across the body to high over the left shoulder, off the
-- WIDEST BASE IN THE CHAIN.
--
-- Out of hit 2's braced lunge both feet come level and go WIDE -- 3.1 studs apart across the
-- body, with the pelvis sunk to -0.81, the deepest of the first four hits -- and then both legs
-- drive and the whole body STANDS UP under the cut: the feet stay planted while the root climbs
-- 0.66 studs, and the legs finish straight. Square throughout, with no lead foot: hit 3 is told
-- apart from its neighbours by width and height rather than by which foot is forward, which is
-- what stops it reading as another version of hit 2. The chest rolls the OPPOSITE sign to hit 1,
-- which is what turns hit 1's descending line into a rising one on the same circle. Contacts at
-- head height, tip (+0.8, +2.5, -4.4), 2.1 studs above hit 1; the EDGE leads (1.00).
--
-- The keyframes are not here. Every hit of the chain is built by ReplicatedStorage/SwingChain
-- from hit 1's own solved arm circle plus this hit's shoulder tilt, torso, weight, STANCE and
-- timing, so the five swings cannot drift apart and re-solving hit 1 re-solves all of them. The
-- spec for this one, with a comment per key, is in that module; the geometry check is
-- tools/swing_chain_check.py.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SwingChain = require(ReplicatedStorage:WaitForChild("SwingChain"))

return SwingChain.clip(3)
