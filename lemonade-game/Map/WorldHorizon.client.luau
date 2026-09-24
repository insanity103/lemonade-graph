-- LocalScript | StarterPlayerScripts.WorldHorizon | Map project.
-- Carries LemonadeMap.Horizon (the far mountain ranges and the Sunspire's wooded hill) along with the
-- camera, like a 3D skybox. map_forge.py builds the Horizon in "sky space": every far layer is
-- shrunk toward the model's SkyEye point until it stands 400-650 studs out, inside the distance
-- parts still render on lower graphics settings, while covering exactly the part of the sky it
-- would at its true distance. Moving it by the camera's offset from SkyEye (translation only, no
-- rotation) keeps it at that apparent distance from anywhere in the map, which is how anything
-- far away behaves: it never gets closer as you walk. Purely visual and local: the parts have no
-- collision, queries or shadows, and the server's copy never moves.
local RunService = game:GetService("RunService")

local MOVE_EPSILON = 0.25 -- [TUNING] studs the camera must move before the ranges follow
-- The south country (its ranges, the Sunspire's wooded hill and foothills) is framed for
-- the town's view through the Iron Lowlands gate. Seen from inside the Lowlands it would hang over
-- the desert basin in front of the basin's own mesas, so it fades out as the camera walks south
-- through the pass, and back in past the Briarwood gate. The east, west and north rings stay.
local DESERT_FADE = { 140, 180, 462, 492 } -- [TUNING] Z: fade out from..to, fade back in from..to

local map = workspace:WaitForChild("LemonadeMap", 60)
local horizon = map and map:WaitForChild("Horizon", 60)
if not horizon then
	return
end

-- Scrapped: Alex asked to drop the background mountains entirely now that the castle wall
-- (tools/map_forge.py) is Hearthmere's visible boundary. The baked far ranges kept reading as
-- naturalistic/desaturated no matter how they were re-hued (see WorldLook's recolorHorizon, which
-- is now a no-op with nothing left to colour), so instead of another recolour pass this whole
-- layer is hidden and its camera-following render step never starts.
for _, d in ipairs(horizon:GetDescendants()) do
	if d:IsA("BasePart") then
		d.Transparency = 1
		d.CanCollide = false
		d.CanQuery = false
	end
end
return
