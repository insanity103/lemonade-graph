--// WheelGeometry  (the town spin wheel's shared measurements and its flat-triangle helper)
-- The server builds the wheel's frame (GameplayActors.spinWheel) and every client paints its own
-- prize face onto it (ReplicatedStorage.SpinStation: one slice per sword in THAT player's pool, each slice's
-- angle equal to its real odds). Both read the numbers below so the face always sits in the rim.
-- All positions are in the station's own space: origin on the ground at the wheel's foot, -Z the
-- way the wheel faces (a CFrame.lookAt station CFrame), +Y up.
local WheelGeometry = {}

WheelGeometry.CENTER = Vector3.new(0, 10.4, 0) -- wheel hub, studs above the ground
WheelGeometry.RADIUS = 6.2                     -- prize face radius (the rim ring sits just outside)
WheelGeometry.FACE_Z = -0.35                   -- the prize face's plane (in front of the backing disc)
WheelGeometry.FACE_THICK = 0.3
WheelGeometry.POINTER_ANGLE = 0                -- the ticker sits at 12 o'clock

-- A point on the wheel's face at angle `phi` (radians, 0 = 12 o'clock) and radius `r`, in the
-- rotor's own 2D space (X, Y) at depth z.
function WheelGeometry.facePoint(phi: number, r: number, z: number?): Vector3
	return Vector3.new(math.sin(phi) * r, math.cos(phi) * r, z or WheelGeometry.FACE_Z)
end

-- A flat triangle a-b-c (world or model space, whatever the caller works in) of thickness
-- `thick`, drawn as two WedgeParts (Roblox has no triangle part). Returns the two wedges, not
-- parented; `props` (Color, Material, ...) is applied to both.
function WheelGeometry.triangle(a: Vector3, b: Vector3, c: Vector3, thick: number, props: { [string]: any }?)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local wedges = {}
	for i = 1, 2 do
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.CastShadow = false
		w.TopSurface, w.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		for key, value in pairs(props or {}) do
			(w :: any)[key] = value
		end
		wedges[i] = w
	end
	wedges[1].Size = Vector3.new(thick, math.max(0.05, height), math.max(0.05, math.abs(ab:Dot(back))))
	wedges[1].CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)
	wedges[2].Size = Vector3.new(thick, math.max(0.05, height), math.max(0.05, math.abs(ac:Dot(back))))
	wedges[2].CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
	return wedges[1], wedges[2]
end

return WheelGeometry
