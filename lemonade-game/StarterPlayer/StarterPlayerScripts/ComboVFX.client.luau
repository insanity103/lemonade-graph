-- StarterPlayerScripts/ComboVFX.client.luau
-- The attacker's half of contact: the hitstop on their own swing, and the camera kick.
--
-- Both hang off ONE message, the server's HitlagEffect, which is fired only from the code path
-- that has already decided a blade hit a body (SwordSystem.applyDamage / EnemyCombat.attackEnemy).
-- The client cannot assert a hit, so a whiff produces none of this: on a miss the swing plays
-- through at full speed, the camera never moves and there is no flash -- which is the difference
-- a player feels between cutting air and cutting an enemy.
--
-- ── The kick ────────────────────────────────────────────────────────────────────────────
-- Aimed, not random. The server sends the point where the blade met the body and the direction
-- the blade was travelling through it; that direction is resolved into the camera's own axes
-- ONCE, at the moment of the hit, and the lens is thrown that way: a cut going down and across
-- to the left throws the camera down and left, with a little roll after it. Freezing the axis at
-- the hit matters -- recomputing it per frame against a camera that is itself being kicked makes
-- the kick swim.
--
-- Shaped like the hit, in three parts:
--   rise    0 -> peak in 18 ms, one rendered frame at 60 fps: the punch has to ARRIVE, not ramp.
--           It is also what keeps the hold readable -- the kick is already at its peak by the
--           first held frame, so every frame of the hitstop is pixel-identical to the last.
--   hold    peak, dead still, for exactly as long as the bodies hold. The camera is part of the
--           hitstop: a lens that keeps moving through a frozen frame undoes the freeze. This is
--           also why the judder below does not start until the hold lets go.
--   release a damped spring back through zero to one ~11% counter-swing and out, in ~0.26 s,
--           plus a short judder. Nothing is still moving a third of a second after a hit.
--
-- Peak is CAMERA_KICK_DEG: 1.8 degrees on the first hit of a combo to 3.2 on the fifth. Three
-- degrees is a jolt at 60 fps; ten is a camera fault and a headache.
--
-- ── Cost ────────────────────────────────────────────────────────────────────────────────
-- One RenderStep binding for the life of the client. It returns on the first line when no kick
-- is running, which is every frame except the ~20 after a landed hit; those twenty cost three
-- sines, a CFrame multiply and two property writes each.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local ComboConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ComboConfig"))
local Hitstop = require(ReplicatedStorage:WaitForChild("Hitstop"))
-- The spark burst at the point the blade met the body. It hangs off this message and not off
-- the animation for the same reason the kick and the hitstop do: the client cannot assert a
-- hit, so cutting air must stay silent.
local SwingImpact = require(ReplicatedStorage:WaitForChild("SwingImpact"))

local RISE = 0.018 -- [TUNING] seconds to the peak of the punch: one rendered frame at 60 fps
local RELEASE = 0.26 -- [TUNING] seconds the spring takes to die out after the hold
local ROLL_SHARE = 0.45 -- [TUNING] how much of the kick goes into roll rather than yaw
local SHAKE_DECAY = 26 -- [TUNING] 1/seconds; the judder is gone within ~0.12 s
local FOV_FALL = 0.22 -- [TUNING] seconds for the field of view to come back out

-- Live kick, or nil. Fields are set once per hit and only read after that.
local kick: { startedAt: number, holdEnd: number, endsAt: number,
	pitch: number, yaw: number, roll: number,
	shake: number, seed: number, fov: number }? = nil

-- The field of view we wrote last frame, and by how much, so this frame can take it back off
-- before adding its own -- otherwise the punch accumulates against anything else that owns the
-- FOV. It is only taken back off if the value is still the one we wrote: if the camera module
-- (or GuiShowcase's capture lock, which pins FOV 70 every frame) has set it since, that value is
-- the new truth and our delta is simply forgotten.
local fovWrote: number? = nil
local fovDelta = 0

local function outQuad(u: number): number
	return 1 - (1 - u) * (1 - u)
end

-- 1 at the peak, 0 at rest: rise, hold, then a damped spring with one counter-swing.
local function envelope(t: number, holdEnd: number): number
	if t < RISE then
		return outQuad(t / RISE)
	end
	if t < holdEnd then
		return 1
	end
	local u = t - holdEnd
	return math.exp(-14 * u) * math.cos(20 * u)
end

-- `sized` is the server's own peak for this hit -- { deg, studs, fov } -- sent only by the heavy,
-- whose payoff scales with a charge length only the server measured and goes past anything in the
-- combo table. Absent, the kick is the combo index's row, exactly as it was.
local function beginKick(comboIndex: number, contact: CFrame?, hold: number, sized)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local index = math.clamp(comboIndex, 1, #ComboConfig.CAMERA_KICK_DEG)
	local sizedOk = typeof(sized) == "table" and typeof(sized.deg) == "number"
	local peak = math.rad(if sizedOk then math.clamp(sized.deg, 0, 9) else ComboConfig.CAMERA_KICK_DEG[index])

	-- The blade's travel, in the camera's axes: +X is screen right, +Y is screen up. Only the
	-- part of it across the screen can be seen, so that is the part that aims the kick.
	local tx, ty = 0, -1
	if contact then
		local inCamera = camera.CFrame:VectorToObjectSpace(contact.LookVector)
		local across = math.sqrt(inCamera.X * inCamera.X + inCamera.Y * inCamera.Y)
		if across > 1e-3 then
			tx, ty = inCamera.X / across, inCamera.Y / across
		end
	end

	local now = os.clock()
	kick = {
		startedAt = now,
		holdEnd = math.max(RISE, hold),
		endsAt = now + math.max(RISE, hold) + RELEASE,
		-- A positive pitch tilts the view up and a positive yaw turns it left, so a blade coming
		-- down and to the right throws the lens down and right after it.
		pitch = ty * peak,
		yaw = -tx * peak,
		roll = tx * peak * ROLL_SHARE,
		shake = if sizedOk and typeof(sized.studs) == "number"
			then math.clamp(sized.studs, 0, 0.6)
			else (ComboConfig.CAMERA_SHAKE_STUDS[index] or 0.1),
		seed = math.random() * 6.28,
		fov = if sizedOk and typeof(sized.fov) == "number"
			then math.clamp(sized.fov, 0, 5)
			else (ComboConfig.CAMERA_FOV_DEG[index] or 1),
	}
end

-- After the default camera module (RenderPriority.Camera) and after GuiShowcase's capture lock
-- (Camera + 1), so the kick is applied to whatever CFrame they settled on. It is a DELTA on that
-- CFrame and never a source of truth, so it cannot drift or fight either of them.
RunService:BindToRenderStep("ComboVFXKick", Enum.RenderPriority.Camera.Value + 2, function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if fovWrote ~= nil then
		if math.abs(camera.FieldOfView - fovWrote) < 1e-4 then
			camera.FieldOfView -= fovDelta
		end
		fovWrote, fovDelta = nil, 0
	end
	if not kick then
		return
	end

	local now = os.clock()
	if now >= kick.endsAt then
		kick = nil
		return
	end
	local t = now - kick.startedAt

	local f = envelope(t, kick.holdEnd)

	-- The judder is the hold letting go, so it does not exist until it does.
	local sx, sy = 0, 0
	if t > kick.holdEnd then
		local u = t - kick.holdEnd
		local decay = math.exp(-SHAKE_DECAY * u)
		sx = math.sin(u * 230 + kick.seed) * kick.shake * decay
		sy = math.sin(u * 310 + kick.seed * 1.7) * kick.shake * 0.75 * decay
	end

	camera.CFrame = camera.CFrame
		* CFrame.new(sx, sy, 0)
		* CFrame.Angles(kick.pitch * f, kick.yaw * f, kick.roll * f)

	-- The field of view is pulled IN on impact and eased back out; it is taken off again at the
	-- top of the next frame, so nothing accumulates.
	local fovFall = math.clamp(1 - (t - kick.holdEnd) / FOV_FALL, 0, 1)
	local delta = -kick.fov * math.max(f, 0) * (if t < kick.holdEnd then 1 else fovFall)
	if delta ~= 0 then
		camera.FieldOfView += delta
		fovWrote, fovDelta = camera.FieldOfView, delta
	end
end)

-- A landed hit, confirmed by the server. Hold this character's own swing on the contact frame
-- (ReplicatedStorage/Hitstop stops the clip's clock, pins the joints and pauses the stock walk
-- tracks) and throw the camera along the blade.
local hitlagRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):FindFirstChild("HitlagEffect")
if hitlagRemote then
	hitlagRemote.OnClientEvent:Connect(function(duration, comboIndex, contact, hold, kick)
		local index = comboIndex or 1
		local stop = if typeof(hold) == "number" then hold else Hitstop.duration(index)
		Hitstop.freeze(player.Character, stop)
		beginKick(index, if typeof(contact) == "CFrame" then contact else nil, stop, kick)
		-- and the world's half of it: sparks thrown back along the blade's own travel from the
		-- point the server says it met the body, sized by the server's own `heft` for this hit
		-- (absent on an M1, which leaves the burst exactly the size it has always been).
		local heft = if typeof(kick) == "table" and typeof(kick.heft) == "number" then kick.heft else 1
		SwingImpact.hit(if typeof(contact) == "CFrame" then contact else nil, index, heft)
	end)
end

-- Only on HitlagEffect: it fires once per landed hit. ComboUpdate fires on every swing, hit or
-- miss, so reacting to it too meant whiffs kicked the screen and hits kicked twice.

print("[ComboVFX] Contact hitstop and camera kick enabled")
