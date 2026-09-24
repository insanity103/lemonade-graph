-- Sword Attack 4 — hit 4 of the M1 chain.
--
-- OVERHEAD — straight down the centreline. FEET TOGETHER, THEN DROPPED.
--
-- Both hands drawn up over the head: the tip reaches 5.1 studs above the root, the highest
-- anything gets in the first four hits, and the shoulders barely yaw at all. The chop is spine
-- folding forward, not a turn -- and the LEGS say the same thing. The feet gather to 0.8 studs
-- apart and the legs straighten for the lift (the tallest pelvis of the first four, -0.15), then
-- the chop spreads them to 2.6 and the pelvis FALLS 0.55 studs with the blade into a square
-- brace. It is the only hit in the chain with no lead foot at all, on purpose: a body dropping,
-- not a body turning. 6.8 studs of tip travel in the 30 ms into contact. Contact tip
-- (+0.1, +0.9, -4.7); the EDGE leads (1.00).
--
-- The keyframes are not here. Every hit of the chain is built by ReplicatedStorage/SwingChain
-- from hit 1's own solved arm circle plus this hit's shoulder tilt, torso, weight, STANCE and
-- timing, so the five swings cannot drift apart and re-solving hit 1 re-solves all of them. The
-- spec for this one, with a comment per key, is in that module; the geometry check is
-- tools/swing_chain_check.py.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SwingChain = require(ReplicatedStorage:WaitForChild("SwingChain"))

return SwingChain.clip(4)
