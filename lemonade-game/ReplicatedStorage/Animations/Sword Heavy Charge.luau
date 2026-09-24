-- Sword Heavy Charge — the body while the heavy attack's button is held.
--
-- 620 ms, LOOPING FROM 200 ms: the entrance into the coil plays once and the strain cycle
-- repeats for as long as the charge lasts, so a held charge keeps breathing instead of freezing.
--
-- The keyframes are not here. Both heavy clips are built by ReplicatedStorage/SwingHeavy from
-- hit 1's own solved arm circle plus this pose's shoulder tilt, torso, weight and timing, so the
-- heavy cannot drift away from the swings it shares a rig with. The spec, with a comment per
-- key, is in that module; the geometry check is tools/swing_chain_check.py.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SwingHeavy = require(ReplicatedStorage:WaitForChild("SwingHeavy"))

return SwingHeavy.chargeClip()
