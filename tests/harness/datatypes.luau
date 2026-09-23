--// tests/harness/datatypes.luau  (headless stand-ins for Roblox value types)
-- Vector3, Vector2, CFrame and Color3 do real maths (the spin station measures distances, the
-- sword factory multiplies grips, WorldLayout places the hub with CFrame.lookAt). The rest are
-- plain records that remember their constructor arguments: game code builds them for looks the
-- tests never read. Every value carries a metatable __type so the harness's typeof() answers
-- "Vector3", "CFrame", ... exactly as Roblox does.
local D = {}

local function typed(name, mt)
	mt.__type = name
	return mt
end

-- ---------------------------------------------------------------- Vector3
local Vector3 = {}
local V3 = typed("Vector3", {})
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
local function isV3(v)
	return type(v) == "table" and getmetatable(v) == V3
end
V3.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif key == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		if m == 0 then return v3(0 / 0, 0 / 0, 0 / 0) end
		return v3(self.X / m, self.Y / m, self.Z / m)
	elseif key == "x" then return self.X
	elseif key == "y" then return self.Y
	elseif key == "z" then return self.Z
	end
	return Vector3[key]
end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	if type(a) == "number" then return v3(a / b.X, a / b.Y, a / b.Z) end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__idiv = function(a, b)
	local q = V3.__div(a, b)
	return v3(math.floor(q.X), math.floor(q.Y), math.floor(q.Z))
end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(a) return string.format("%g, %g, %g", a.X, a.Y, a.Z) end

function Vector3.new(x, y, z) return v3(x, y, z) end
function Vector3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function Vector3.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function Vector3.Lerp(a, b, t) return a + (b - a) * t end
function Vector3.Abs(a) return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z)) end
function Vector3.Floor(a) return v3(math.floor(a.X), math.floor(a.Y), math.floor(a.Z)) end
function Vector3.Ceil(a) return v3(math.ceil(a.X), math.ceil(a.Y), math.ceil(a.Z)) end
function Vector3.Sign(a) return v3(math.sign(a.X), math.sign(a.Y), math.sign(a.Z)) end
function Vector3.Max(a, b) return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
function Vector3.Min(a, b) return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
function Vector3.Angle(a, b)
	local d = Vector3.Dot(a, b) / (a.Magnitude * b.Magnitude)
	return math.acos(math.clamp(d, -1, 1))
end
function Vector3.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	return math.abs(a.X - b.X) <= eps and math.abs(a.Y - b.Y) <= eps and math.abs(a.Z - b.Z) <= eps
end
function Vector3.FromNormalId(id)
	local map = { Top = v3(0, 1, 0), Bottom = v3(0, -1, 0), Front = v3(0, 0, -1), Back = v3(0, 0, 1),
		Right = v3(1, 0, 0), Left = v3(-1, 0, 0) }
	return map[id.Name] or v3()
end
function Vector3.FromAxis(axis) return Vector3.FromNormalId(axis) end
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)
D.Vector3 = Vector3
D.isVector3 = isV3

-- ---------------------------------------------------------------- Vector2
local Vector2 = {}
local V2 = typed("Vector2", {})
local function v2(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end
V2.__index = function(self, key)
	if key == "Magnitude" then return math.sqrt(self.X * self.X + self.Y * self.Y) end
	if key == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y)
		return v2(self.X / m, self.Y / m)
	end
	return Vector2[key]
end
V2.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b)
	if type(a) == "number" then return v2(a * b.X, a * b.Y) end
	if type(b) == "number" then return v2(a.X * b, a.Y * b) end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	if type(b) == "number" then return v2(a.X / b, a.Y / b) end
	return v2(a.X / b.X, a.Y / b.Y)
end
V2.__unm = function(a) return v2(-a.X, -a.Y) end
V2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
V2.__tostring = function(a) return string.format("%g, %g", a.X, a.Y) end
function Vector2.new(x, y) return v2(x, y) end
function Vector2.Dot(a, b) return a.X * b.X + a.Y * b.Y end
function Vector2.Lerp(a, b, t) return a + (b - a) * t end
function Vector2.Cross(a, b) return a.X * b.Y - a.Y * b.X end
function Vector2.Max(a, b) return v2(math.max(a.X, b.X), math.max(a.Y, b.Y)) end
function Vector2.Min(a, b) return v2(math.min(a.X, b.X), math.min(a.Y, b.Y)) end
Vector2.zero = v2(0, 0)
Vector2.one = v2(1, 1)
Vector2.xAxis = v2(1, 0)
Vector2.yAxis = v2(0, 1)
D.Vector2 = Vector2

-- ---------------------------------------------------------------- CFrame
-- Stored as a position and a row-major 3x3 rotation (R00 .. R22), Roblox's own layout.
local CFrame = {}
local CF = typed("CFrame", {})
local function cf(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	return setmetatable({
		X = x, Y = y, Z = z,
		R00 = r00, R01 = r01, R02 = r02,
		R10 = r10, R11 = r11, R12 = r12,
		R20 = r20, R21 = r21, R22 = r22,
	}, CF)
end
local function isCF(v) return type(v) == "table" and getmetatable(v) == CF end
local function rotApply(c, x, y, z)
	return c.R00 * x + c.R01 * y + c.R02 * z,
		c.R10 * x + c.R11 * y + c.R12 * z,
		c.R20 * x + c.R21 * y + c.R22 * z
end
local function rotApplyT(c, x, y, z)
	return c.R00 * x + c.R10 * y + c.R20 * z,
		c.R01 * x + c.R11 * y + c.R21 * z,
		c.R02 * x + c.R12 * y + c.R22 * z
end
local function cfMul(a, b)
	local x, y, z = rotApply(a, b.X, b.Y, b.Z)
	return cf(x + a.X, y + a.Y, z + a.Z,
		a.R00 * b.R00 + a.R01 * b.R10 + a.R02 * b.R20,
		a.R00 * b.R01 + a.R01 * b.R11 + a.R02 * b.R21,
		a.R00 * b.R02 + a.R01 * b.R12 + a.R02 * b.R22,
		a.R10 * b.R00 + a.R11 * b.R10 + a.R12 * b.R20,
		a.R10 * b.R01 + a.R11 * b.R11 + a.R12 * b.R21,
		a.R10 * b.R02 + a.R11 * b.R12 + a.R12 * b.R22,
		a.R20 * b.R00 + a.R21 * b.R10 + a.R22 * b.R20,
		a.R20 * b.R01 + a.R21 * b.R11 + a.R22 * b.R21,
		a.R20 * b.R02 + a.R21 * b.R12 + a.R22 * b.R22)
end
local function cfInverse(c)
	local x, y, z = rotApplyT(c, c.X, c.Y, c.Z)
	return cf(-x, -y, -z, c.R00, c.R10, c.R20, c.R01, c.R11, c.R21, c.R02, c.R12, c.R22)
end
local function fromColumns(pos, right, up, back)
	return cf(pos.X, pos.Y, pos.Z, right.X, up.X, back.X, right.Y, up.Y, back.Y, right.Z, up.Z, back.Z)
end
local function rx(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(0, 0, 0, 1, 0, 0, 0, c, -s, 0, s, c)
end
local function ry(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(0, 0, 0, c, 0, s, 0, 1, 0, -s, 0, c)
end
local function rz(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(0, 0, 0, c, -s, 0, s, c, 0, 0, 0, 1)
end

CF.__index = function(self, key)
	if key == "Position" or key == "p" then return v3(self.X, self.Y, self.Z)
	elseif key == "Rotation" then
		return cf(0, 0, 0, self.R00, self.R01, self.R02, self.R10, self.R11, self.R12, self.R20, self.R21, self.R22)
	elseif key == "LookVector" then return v3(-self.R02, -self.R12, -self.R22)
	elseif key == "RightVector" or key == "XVector" then return v3(self.R00, self.R10, self.R20)
	elseif key == "UpVector" or key == "YVector" then return v3(self.R01, self.R11, self.R21)
	elseif key == "ZVector" then return v3(self.R02, self.R12, self.R22)
	elseif key == "x" then return self.X
	elseif key == "y" then return self.Y
	elseif key == "z" then return self.Z
	end
	return CFrame[key]
end
CF.__mul = function(a, b)
	if isCF(b) then return cfMul(a, b) end
	if isV3(b) then
		local x, y, z = rotApply(a, b.X, b.Y, b.Z)
		return v3(x + a.X, y + a.Y, z + a.Z)
	end
	error("CFrame * " .. typeof(b) .. " is not supported", 2)
end
CF.__add = function(a, b)
	return cf(a.X + b.X, a.Y + b.Y, a.Z + b.Z, a.R00, a.R01, a.R02, a.R10, a.R11, a.R12, a.R20, a.R21, a.R22)
end
CF.__sub = function(a, b)
	return cf(a.X - b.X, a.Y - b.Y, a.Z - b.Z, a.R00, a.R01, a.R02, a.R10, a.R11, a.R12, a.R20, a.R21, a.R22)
end
CF.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z and a.R00 == b.R00 and a.R01 == b.R01 and a.R02 == b.R02
		and a.R10 == b.R10 and a.R11 == b.R11 and a.R12 == b.R12 and a.R20 == b.R20 and a.R21 == b.R21
		and a.R22 == b.R22
end
CF.__tostring = function(c)
	return string.format("%g, %g, %g, %g, %g, %g, %g, %g, %g, %g, %g, %g", c.X, c.Y, c.Z,
		c.R00, c.R01, c.R02, c.R10, c.R11, c.R12, c.R20, c.R21, c.R22)
end

function CFrame.new(...)
	local n = select("#", ...)
	local a, b, c = ...
	if n == 0 then return cf(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1) end
	if n == 1 then return cf(a.X, a.Y, a.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1) end
	if n == 2 then return CFrame.lookAt(a, b) end
	if n == 3 then return cf(a, b, c, 1, 0, 0, 0, 1, 0, 0, 0, 1) end
	if n == 7 then
		local x, y, z, qx, qy, qz, qw = ...
		return cf(x, y, z,
			1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw),
			2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw),
			2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy))
	end
	if n == 12 then return cf(...) end
	error("CFrame.new: unsupported argument count " .. n, 2)
end
function CFrame.lookAt(at, target, up)
	up = up or Vector3.yAxis
	local look = target - at
	if look.Magnitude < 1e-9 then return cf(at.X, at.Y, at.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1) end
	look = look.Unit
	local right = Vector3.Cross(look, up)
	if right.Magnitude < 1e-9 then right = Vector3.Cross(look, Vector3.zAxis) end
	right = right.Unit
	local up2 = Vector3.Cross(right, look)
	return fromColumns(at, right, up2, -look)
end
function CFrame.fromMatrix(pos, vx, vy, vz)
	vz = vz or Vector3.Cross(vx, vy).Unit
	return fromColumns(pos, vx, vy, vz)
end
function CFrame.Angles(a, b, c) return cfMul(cfMul(rx(a or 0), ry(b or 0)), rz(c or 0)) end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(a, b, c) return cfMul(cfMul(ry(b or 0), rx(a or 0)), rz(c or 0)) end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
function CFrame.fromEulerAngles(a, b, c) return CFrame.Angles(a, b, c) end
function CFrame.fromAxisAngle(axis, angle)
	local u = axis.Unit
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c
	return cf(0, 0, 0,
		t * u.X * u.X + c, t * u.X * u.Y - s * u.Z, t * u.X * u.Z + s * u.Y,
		t * u.X * u.Y + s * u.Z, t * u.Y * u.Y + c, t * u.Y * u.Z - s * u.X,
		t * u.X * u.Z - s * u.Y, t * u.Y * u.Z + s * u.X, t * u.Z * u.Z + c)
end
function CFrame.Inverse(c) return cfInverse(c) end
function CFrame.PointToWorldSpace(c, v) return c * v end
function CFrame.PointToObjectSpace(c, v) return cfInverse(c) * v end
function CFrame.VectorToWorldSpace(c, v) return v3(rotApply(c, v.X, v.Y, v.Z)) end
function CFrame.VectorToObjectSpace(c, v) return v3(rotApplyT(c, v.X, v.Y, v.Z)) end
function CFrame.ToWorldSpace(c, o) return cfMul(c, o) end
function CFrame.ToObjectSpace(c, o) return cfMul(cfInverse(c), o) end
function CFrame.Lerp(a, b, t)
	-- Position is interpolated; rotation snaps at the halfway point (no test reads a mid-turn).
	local r = t < 0.5 and a or b
	return cf(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t,
		r.R00, r.R01, r.R02, r.R10, r.R11, r.R12, r.R20, r.R21, r.R22)
end
function CFrame.GetComponents(c)
	return c.X, c.Y, c.Z, c.R00, c.R01, c.R02, c.R10, c.R11, c.R12, c.R20, c.R21, c.R22
end
CFrame.components = CFrame.GetComponents
function CFrame.ToEulerAnglesXYZ(c)
	local y = math.asin(math.clamp(c.R02, -1, 1))
	local x = math.atan2(-c.R12, c.R22)
	local z = math.atan2(-c.R01, c.R00)
	return x, y, z
end
function CFrame.ToEulerAnglesYXZ(c)
	local x = math.asin(math.clamp(-c.R12, -1, 1))
	local y = math.atan2(c.R02, c.R22)
	local z = math.atan2(c.R10, c.R11)
	return x, y, z
end
CFrame.ToOrientation = CFrame.ToEulerAnglesYXZ
function CFrame.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	local ca, cb = { CFrame.GetComponents(a) }, { CFrame.GetComponents(b) }
	for i = 1, 12 do
		if math.abs(ca[i] - cb[i]) > eps then return false end
	end
	return true
end
CFrame.identity = CFrame.new()
D.CFrame = CFrame
D.isCFrame = isCF

-- ---------------------------------------------------------------- Color3
local Color3 = {}
local C3 = typed("Color3", {})
local function c3(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3) end
C3.__index = function(self, key)
	if key == "r" then return self.R elseif key == "g" then return self.G elseif key == "b" then return self.B end
	return Color3[key]
end
C3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
C3.__tostring = function(c) return string.format("%g, %g, %g", c.R, c.G, c.B) end
function Color3.new(r, g, b) return c3(r, g, b) end
function Color3.fromRGB(r, g, b) return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then return c3(v, t, p) elseif i == 1 then return c3(q, v, p) elseif i == 2 then return c3(p, v, t)
	elseif i == 3 then return c3(p, q, v) elseif i == 4 then return c3(t, p, v) end
	return c3(v, p, q)
end
function Color3.fromHex(hex)
	hex = hex:gsub("#", "")
	return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end
function Color3.Lerp(a, b, t) return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
function Color3.ToHSV(c)
	local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == c.R then h = ((c.G - c.B) / d) % 6
		elseif mx == c.G then h = (c.B - c.R) / d + 2
		else h = (c.R - c.G) / d + 4 end
		h /= 6
	end
	return h, mx == 0 and 0 or d / mx, mx
end
function Color3.ToHex(c)
	return string.format("%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5))
end
D.Color3 = Color3

-- ---------------------------------------------------------------- UDim / UDim2
local UDim, UDim2 = {}, {}
local UD = typed("UDim", {})
local UD2 = typed("UDim2", {})
local function ud(s, o) return setmetatable({ Scale = s or 0, Offset = o or 0 }, UD) end
UD.__index = UDim
UD.__add = function(a, b) return ud(a.Scale + b.Scale, a.Offset + b.Offset) end
UD.__sub = function(a, b) return ud(a.Scale - b.Scale, a.Offset - b.Offset) end
UD.__eq = function(a, b) return a.Scale == b.Scale and a.Offset == b.Offset end
function UDim.new(s, o) return ud(s, o) end
local function ud2(xs, xo, ys, yo) return setmetatable({ X = ud(xs, xo), Y = ud(ys, yo) }, UD2) end
UD2.__index = function(self, key)
	if key == "Width" then return self.X elseif key == "Height" then return self.Y end
	return UDim2[key]
end
UD2.__add = function(a, b) return ud2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset) end
UD2.__sub = function(a, b) return ud2(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset) end
UD2.__unm = function(a) return ud2(-a.X.Scale, -a.X.Offset, -a.Y.Scale, -a.Y.Offset) end
UD2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
function UDim2.new(xs, xo, ys, yo)
	if type(xs) == "table" then return ud2(xs.Scale, xs.Offset, xo.Scale, xo.Offset) end
	return ud2(xs, xo, ys, yo)
end
function UDim2.fromOffset(x, y) return ud2(0, x, 0, y) end
function UDim2.fromScale(x, y) return ud2(x, 0, y, 0) end
function UDim2.Lerp(a, b, t)
	return ud2(a.X.Scale + (b.X.Scale - a.X.Scale) * t, a.X.Offset + (b.X.Offset - a.X.Offset) * t,
		a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t, a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t)
end
D.UDim, D.UDim2 = UDim, UDim2

-- ---------------------------------------------------------------- records
-- Types game code only constructs and hands to the engine. Fields are kept for anyone who looks.
local function record(typeName, fields)
	local lib = {}
	local mt = typed(typeName, { __index = lib })
	function lib.new(...)
		local args = table.pack(...)
		local obj = { __args = args }
		for i, field in ipairs(fields) do obj[field] = args[i] end
		return setmetatable(obj, mt)
	end
	return lib, mt
end
D.NumberRange = record("NumberRange", { "Min", "Max" })
do
	local new = D.NumberRange.new
	D.NumberRange.new = function(a, b) return new(a, b or a) end
end
D.NumberSequenceKeypoint = record("NumberSequenceKeypoint", { "Time", "Value", "Envelope" })
D.ColorSequenceKeypoint = record("ColorSequenceKeypoint", { "Time", "Value" })
D.NumberSequence = record("NumberSequence", { "Keypoints" })
D.ColorSequence = record("ColorSequence", { "Keypoints" })
D.TweenInfo = record("TweenInfo", { "Time", "EasingStyle", "EasingDirection", "RepeatCount", "Reverses", "DelayTime" })
D.Rect = record("Rect", { "Min", "Max" })
D.Ray = record("Ray", { "Origin", "Direction" })
D.PhysicalProperties = record("PhysicalProperties", { "Density", "Friction", "Elasticity", "FrictionWeight", "ElasticityWeight" })
D.Region3 = record("Region3", { "Min", "Max" })
D.Faces = record("Faces", {})
D.Axes = record("Axes", {})
D.Font = record("Font", { "Family", "Weight", "Style" })
D.Font.fromEnum = function(item) return D.Font.new(item) end
D.Font.fromName = function(name, ...) return D.Font.new(name, ...) end
D.Font.fromId = function(id, ...) return D.Font.new(id, ...) end
D.Vector3int16 = record("Vector3int16", { "X", "Y", "Z" })
D.Vector2int16 = record("Vector2int16", { "X", "Y" })
D.PathWaypoint = record("PathWaypoint", { "Position", "Action", "Label" })

local function params(typeName)
	local lib = {}
	local mt = typed(typeName, { __index = lib })
	function lib.new()
		return setmetatable({ FilterDescendantsInstances = {}, FilterType = nil, IgnoreWater = false,
			CollisionGroup = "Default", RespectCanCollide = false, MaxParts = 0 }, mt)
	end
	function lib.AddToFilter(self, list)
		if type(list) ~= "table" or getmetatable(list) ~= nil then list = { list } end
		for _, item in ipairs(list) do table.insert(self.FilterDescendantsInstances, item) end
	end
	return lib
end
D.RaycastParams = params("RaycastParams")
D.OverlapParams = params("OverlapParams")

do
	local BrickColor = {}
	local mt = typed("BrickColor", { __index = BrickColor })
	local function make(name) return setmetatable({ Name = name, Color = c3(0.64, 0.64, 0.64), Number = 194 }, mt) end
	function BrickColor.new(name) return make(tostring(name)) end
	function BrickColor.random() return make("Medium stone grey") end
	function BrickColor.palette() return make("Medium stone grey") end
	for _, n in ipairs({ "White", "Gray", "DarkGray", "Black", "Red", "Yellow", "Green", "Blue" }) do
		BrickColor[n] = function() return make(n) end
	end
	D.BrickColor = BrickColor
end

do
	local DateTime = {}
	local mt = typed("DateTime", { __index = DateTime })
	function DateTime.fromUnixTimestamp(t) return setmetatable({ UnixTimestamp = t, UnixTimestampMillis = t * 1000 }, mt) end
	function DateTime.fromUnixTimestampMillis(t) return setmetatable({ UnixTimestamp = t // 1000, UnixTimestampMillis = t }, mt) end
	function DateTime.now() return DateTime.fromUnixTimestamp(os.time()) end
	function DateTime.ToIsoDate(self) return os.date("!%Y-%m-%dT%H:%M:%SZ", self.UnixTimestamp) end
	function DateTime.FormatUniversalTime(self) return os.date("!%Y-%m-%d %H:%M:%S", self.UnixTimestamp) end
	DateTime.FormatLocalTime = DateTime.FormatUniversalTime
	function DateTime.ToUniversalTime(self)
		return os.date("!*t", self.UnixTimestamp)
	end
	D.DateTime = DateTime
end

-- ---------------------------------------------------------------- Random
-- A seeded, deterministic generator (xorshift-style over 32 bits), so Random.new(seed) in game code
-- repeats run to run. Random.new() with no seed draws its seed from math.random, which the test
-- runner seeds, so it is deterministic too.
do
	local Random = {}
	local mt = typed("Random", { __index = Random })
	local function step(self)
		-- 32-bit xorshift; floats keep it portable across the Luau number type.
		local s = self._s
		s = bit32.bxor(s, bit32.lshift(s, 13))
		s = bit32.bxor(s, bit32.rshift(s, 17))
		s = bit32.bxor(s, bit32.lshift(s, 5))
		self._s = s
		return s
	end
	function Random.new(seed)
		seed = seed and math.floor(seed) or math.random(1, 2 ^ 31 - 1)
		local s = bit32.bxor(seed % 4294967296, 0x9E3779B9)
		if s == 0 then s = 0x9E3779B9 end
		local self = setmetatable({ _s = s }, mt)
		for _ = 1, 4 do step(self) end
		return self
	end
	function Random.NextNumber(self, lo, hi)
		local u = step(self) / 4294967296
		if lo == nil then return u end
		return lo + (hi - lo) * u
	end
	function Random.NextInteger(self, lo, hi)
		return lo + math.floor(Random.NextNumber(self) * (hi - lo + 1))
	end
	function Random.NextUnitVector(self)
		local v = v3(Random.NextNumber(self, -1, 1), Random.NextNumber(self, -1, 1), Random.NextNumber(self, -1, 1))
		return v.Magnitude > 0 and v.Unit or Vector3.xAxis
	end
	function Random.Shuffle(self, t)
		for i = #t, 2, -1 do
			local j = Random.NextInteger(self, 1, i)
			t[i], t[j] = t[j], t[i]
		end
	end
	function Random.Clone(self) return setmetatable({ _s = self._s }, mt) end
	D.Random = Random
end

-- ---------------------------------------------------------------- Enum
-- Enum.<Type>.<Item> is created on first use and cached, so two reads compare equal. No list of
-- valid names is kept: game code may name any enum item.
do
	local itemMt = typed("EnumItem", {})
	itemMt.__tostring = function(self) return "Enum." .. self.EnumType.Name .. "." .. self.Name end
	itemMt.__index = function(self, key)
		if key == "IsA" then
			return function(item, name) return item.EnumType.Name == name end
		end
		return nil
	end
	local enumMt = typed("Enum", {})
	enumMt.__tostring = function(self) return self.Name end
	local enumLib = {}
	enumMt.__index = function(self, key)
		if key == "GetEnumItems" then
			return function(e)
				local out = {}
				for _, item in pairs(rawget(e, "_items")) do table.insert(out, item) end
				table.sort(out, function(a, b) return a.Value < b.Value end)
				return out
			end
		elseif key == "FromName" then
			return function(e, name) return e[name] end
		elseif key == "FromValue" then
			return function(e, value)
				for _, item in pairs(rawget(e, "_items")) do
					if item.Value == value then return item end
				end
				return nil
			end
		end
		local items = rawget(self, "_items")
		local item = items[key]
		if not item then
			local count = rawget(self, "_count") + 1
			rawset(self, "_count", count)
			item = setmetatable({ Name = key, Value = count - 1, EnumType = self }, itemMt)
			items[key] = item
		end
		return item
	end
	local enumsMt = typed("Enums", {})
	enumsMt.__index = function(self, key)
		if key == "GetEnums" then
			return function() local out = {} for _, e in pairs(enumLib) do table.insert(out, e) end return out end
		end
		local e = enumLib[key]
		if not e then
			e = setmetatable({ Name = key, _items = {}, _count = 0 }, enumMt)
			enumLib[key] = e
		end
		return e
	end
	D.Enum = setmetatable({}, enumsMt)
end

-- typeof() that knows the stand-ins (and Instances, whose metatable says "Instance").
local nativeTypeof = typeof
function D.typeof(value)
	if type(value) == "table" then
		local mt = getmetatable(value)
		if type(mt) == "table" then
			local name = rawget(mt, "__type")
			if name then return name end
		end
	end
	return nativeTypeof(value)
end

return D
