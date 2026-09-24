-- Sword Heavy Strike — the heavy attack's release.
--
-- 820 ms. Its first key is the charge's peak, value for value, so letting go cannot pop the arm;
-- then 100 ms in which the body EXTENDS and the blade goes further back still while the hips
-- fire underneath it, one frame of 11.1 studs through the target, and five decelerating frames
-- of follow-through 127 degrees past it.
--
-- The keyframes are not here; see ReplicatedStorage/SwingHeavy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SwingHeavy = require(ReplicatedStorage:WaitForChild("SwingHeavy"))

return SwingHeavy.strikeClip()
