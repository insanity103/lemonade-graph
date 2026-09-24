-- Sword Guard Hold — one pose, held, for as long as it is playing.
--
-- This exists for the Studio capture stage and nothing else (GuiShowcase.stage's ctx.hold),
-- and it is here rather than in the stage because the stage runs on the SERVER and the pose
-- has to be written on the client, by the same runtime that plays the swing.
--
-- Why a capture needs it: gx.py finds the start of the filmed moment by looking for the first
-- frame after the clapperboard that differs from the one before it. Roblox's stock idle is
-- always moving -- the chest breathes, the arms sway, the head drifts -- so the detector fires
-- on the idle and the strip's clock starts a sixth of a second before the swing does. Eight
-- frames later the strip has run out before the blade reaches the target, and the arc and the
-- whole follow-through are off the end of it. That is exactly what happened to the round-1
-- strip: its damage number lands in the last frame, which is contact, so every frame the piece
-- is judged on was in fact windup.
--
-- Holding this pose makes the character dead still until the swing moves it, so the detector
-- can only fire on the swing, and the strip starts where the swing starts.
--
-- The pose is the attack clip's own T_START, so the swing's fade-in blends out of the pose it
-- was authored to start from. It is Studio-only: nothing on a live server plays it.
--
-- Two identical keys because the runtime interpolates between neighbouring keys and a single
-- key has no neighbour; looping across them holds the pose forever at the cost of one lerp
-- between two equal CFrames per joint per frame.

local rad = math.rad

local function rot(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

local function root(px: number, py: number, pz: number, x: number, y: number, z: number): CFrame
	return CFrame.new(px, py, pz) * CFrame.Angles(rad(x), rad(y), rad(z))
end

local GUARD = {
	["LowerTorso"] = root(0, -0.02, 0, 0, -2, 0),
	["UpperTorso"] = rot(0, -3, 0),
	["Head"] = rot(0, 2, 0),
	["RightUpperArm"] = rot(0, 0, 6),
	["RightLowerArm"] = rot(18, 0, 0),
	["RightHand"] = rot(0, 0, 0),
	["LeftUpperArm"] = rot(0, 0, -5),
	["LeftLowerArm"] = rot(12, 0, 0),
	["LeftHand"] = rot(0, 0, 0),
	["RightUpperLeg"] = rot(0, 0, 0),
	["RightLowerLeg"] = rot(0, 0, 0),
	["LeftUpperLeg"] = rot(0, 0, 0),
	["LeftLowerLeg"] = rot(0, 0, 0),
}

local function copy(pose)
	local out = {}
	for part, cframe in pairs(pose) do
		out[part] = cframe
	end
	return out
end

return {
	Settings = {
		Loop = true,
		Priority = Enum.AnimationPriority.Action,
		CounterRotateLegs = false,
		FadeIn = 0.12,
	},
	Timestamps = {
		[0] = copy(GUARD),
		[0.5] = copy(GUARD),
	},
}
