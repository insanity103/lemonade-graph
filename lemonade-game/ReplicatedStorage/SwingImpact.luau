-- SwingImpact — what the WORLD does when the blade arrives.
--
-- Until this module the only thing at contact was on the HUD: a damage number, a 20-75 ms
-- gameplay freeze, a camera kick and a white wash. Every harsh read of the chain landed on the
-- same sentence -- "the blade passes through and a number floats up", "nothing in the world
-- reacts at contact" -- and they were right: there was no spark, no dust and no mark. A hit that
-- only exists in the UI reads as a spreadsheet event however good the swing in front of it is.
--
-- Two effects, and they are deliberately different jobs:
--
--   hit(cf, index)   every landed hit. A short spark burst thrown BACK along the blade's own
--                    travel from the point the server says the blade met the body. It is small
--                    -- twelve sparks over 0.22 s -- because it has to punctuate four hits a
--                    second without becoming the thing you watch.
--   slam(cf, scale)  the finisher's plant ONLY, on its "ArcEnd" marker, i.e. the frame the tip
--                    reaches the floor. An expanding ground disc, a low dust ring and a heavier
--                    spark throw. This is the one the chain is judged on: it is the only moment
--                    in the five where the ground itself answers, and it is what makes the fifth
--                    hit read as the finisher in a still frame rather than in the damage number.
--
-- Lemonade, not Deepwoken: white at the core warming to lemon, never smoke and never blood.
--
-- ── Cost ────────────────────────────────────────────────────────────────────────────────
-- Two anchored, massless, non-collidable rigs built ONCE per client on first use and reused for
-- the life of the session: a spark rig (2 emitters) and a slam rig (1 disc part + 2 emitters).
-- A hit is a CFrame write and two :Emit() calls -- no Instance.new, no Debris, no per-frame
-- connection. The slam additionally tweens one part's Size and Transparency for 0.62 s. Nothing
-- in here runs on a frame with no contact on it, and none of it is replicated: like the swing
-- and the trail it is local to the client that threw the swing (see SwingTrail's header).
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SwingImpact = {}

local WHITE = Color3.fromRGB(255, 255, 255)
local CREAM = Color3.fromRGB(255, 244, 206)
local LEMON = Color3.fromRGB(255, 206, 74)

local sparkRig: BasePart? = nil
local sparks: ParticleEmitter? = nil
local grit: ParticleEmitter? = nil
local flash: BasePart? = nil
local flashTween: Tween? = nil

local slamRig: BasePart? = nil
local slamDisc: BasePart? = nil
local dust: ParticleEmitter? = nil
local shards: ParticleEmitter? = nil
local slamTweens: { Tween } = {}

local function anchor(name: string): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Parent = Workspace
	return part
end

local function emitter(parent: BasePart, name: string): ParticleEmitter
	local made = Instance.new("ParticleEmitter")
	made.Name = name
	made.Rate = 0
	made.Enabled = false -- :Emit() still fires on a disabled emitter; Rate 0 keeps it idle
	made.LightInfluence = 0
	made.LightEmission = 0.8
	made.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	made.Parent = parent
	return made
end

-- ── The spark burst every landed hit gets ───────────────────────────────────────────────
local function ensureSparks()
	if sparkRig and sparkRig.Parent then
		return
	end
	local rig = anchor("SwingImpactSpark")

	local s = emitter(rig, "Sparks")
	s.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WHITE),
		ColorSequenceKeypoint.new(0.4, CREAM),
		ColorSequenceKeypoint.new(1, LEMON),
	})
	s.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.42),
		NumberSequenceKeypoint.new(0.5, 0.24),
		NumberSequenceKeypoint.new(1, 0),
	})
	s.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.7, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	s.Lifetime = NumberRange.new(0.14, 0.24)
	s.Speed = NumberRange.new(14, 26)
	-- Thrown along the rig's -Z, which `hit` points down the blade's own travel: the spray
	-- leaves the body the way the cut went, so it reads as the blade's energy and not as a
	-- firework parked on the target.
	s.EmissionDirection = Enum.NormalId.Front
	s.SpreadAngle = Vector2.new(34, 34)
	s.Drag = 9
	s.Acceleration = Vector3.new(0, -32, 0)
	s.LightEmission = 1
	sparks = s

	-- The slower half: a couple of fat cream motes that hang a beat longer, so the burst has a
	-- head and a tail instead of one uniform pop.
	local g = emitter(rig, "Grit")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, CREAM),
		ColorSequenceKeypoint.new(1, LEMON),
	})
	g.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Lifetime = NumberRange.new(0.20, 0.34)
	g.Speed = NumberRange.new(3, 8)
	g.EmissionDirection = Enum.NormalId.Front
	g.SpreadAngle = Vector2.new(70, 70)
	g.Drag = 6
	g.LightEmission = 0.5
	grit = g

	-- THE CONTACT FLASH, for a heavy only. A hit that holds both bodies dead still for 150 ms
	-- has to put something in those frames or the hold reads as the game hitching: the sparks
	-- are gone in a fifth of a second and a damage number is UI. This is a neon ball at the
	-- point the blade met the body that blows out to two and a third studs and fades over 0.42 s -- near three times
	-- the hold, so the frame in the middle of the hitstop and the frame after it both have the
	-- blade buried in a lit burst. It is deliberately SMALL -- 2.3 studs across at the biggest
	-- charge, less than half the character's height -- because the first take of it blew out to
	-- fifteen and the cell it was supposed to prove came back as a white disc with no blade, no
	-- target and no body in it. A payoff has to frame the hit, not replace it. One part, built
	-- once with the spark rig and reused; a light M1 never turns it on.
	local ball = Instance.new("Part")
	ball.Name = "SwingImpactFlash"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(0.2, 0.2, 0.2)
	ball.Color = LEMON
	ball.Material = Enum.Material.Neon
	ball.Transparency = 1
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Massless = true
	ball.Parent = Workspace
	flash = ball

	sparkRig = rig
end

-- A landed hit. `cf` is the contact frame the SERVER sent with HitlagEffect: its position is
-- where the blade met the body and its LookVector is the direction the blade was travelling.
-- `index` is the combo index, 1-5, and only scales how much comes out.
-- `heft` (default 1) is how big this contact is, measured by the SERVER off the charge it was
-- actually paid for and sent down with the hit. 1 is a light M1 and behaves exactly as it always
-- did -- same counts, same emitter settings, no allocation. Above it the burst grows with the
-- hit, and above 1.15 it also lights the contact flash, which is the thing that survives the
-- heavy's 150 ms hold.
function SwingImpact.hit(cf: CFrame?, index: number?, heft: number?)
	if typeof(cf) ~= "CFrame" then
		return
	end
	ensureSparks()
	local rig, s, g = sparkRig, sparks, grit
	if not (rig and s and g) then
		return
	end
	local n = math.clamp(index or 1, 1, 5)
	local k = math.clamp(if typeof(heft) == "number" then heft else 1, 1, 3)
	rig.CFrame = cf
	if k > 1 then
		-- Rewritten per landed heavy, not per frame, and only when the hit is a heavy: a bigger
		-- hit throws further, lives longer and leaves fatter sparks.
		s.Lifetime = NumberRange.new(0.14 * k, 0.24 * k)
		s.Speed = NumberRange.new(14 * k, 26 * k)
		s.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.42 * k),
			NumberSequenceKeypoint.new(0.5, 0.24 * k),
			NumberSequenceKeypoint.new(1, 0),
		})
		g.Lifetime = NumberRange.new(0.20 * k, 0.34 * k)
		g.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9 * k),
			NumberSequenceKeypoint.new(1, 0.1),
		})
	end
	s:Emit(math.floor((8 + n * 2) * k))
	g:Emit(math.floor((2 + n) * k))

	local ball = flash
	if k > 1.15 and ball and ball.Parent then
		if flashTween then
			flashTween:Cancel()
		end
		ball.CFrame = CFrame.new(cf.Position)
		ball.Size = Vector3.new(0.35 * k, 0.35 * k, 0.35 * k)
		ball.Transparency = 0.22
		local blow = TweenService:Create(ball, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.78 * k, 0.78 * k, 0.78 * k),
			Transparency = 1,
		})
		blow:Play()
		flashTween = blow
	end
	-- A light hit must not inherit a heavy's emitter settings, so they go back afterwards.
	if k > 1 then
		s.Lifetime = NumberRange.new(0.14, 0.24)
		s.Speed = NumberRange.new(14, 26)
		s.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.42),
			NumberSequenceKeypoint.new(0.5, 0.24),
			NumberSequenceKeypoint.new(1, 0),
		})
		g.Lifetime = NumberRange.new(0.20, 0.34)
		g.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9),
			NumberSequenceKeypoint.new(1, 0.1),
		})
	end
end

-- ── The finisher's ground burst ─────────────────────────────────────────────────────────
local function ensureSlam()
	if slamRig and slamRig.Parent and slamDisc and slamDisc.Parent then
		return
	end
	local rig = anchor("SwingImpactSlam")

	-- A flat disc laid on the ground that expands and fades. A Cylinder's axis is its X, so the
	-- part is turned on its side by `slam` below to stand the round face on the floor.
	local disc = Instance.new("Part")
	disc.Name = "SlamRing"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.08, 1, 1)
	-- LEMON, not white. A white neon disc on Lemonade's pale sand is a wash: it was there in
	-- round 3's strip and read as a lens flare rather than as the ground answering. Gold has
	-- somewhere to go against both the sand and the character's dark silhouette.
	disc.Color = LEMON
	disc.Material = Enum.Material.Neon
	disc.Transparency = 1
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Massless = true
	disc.Parent = Workspace
	slamDisc = disc

	local d = emitter(rig, "Dust")
	d.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WHITE),
		ColorSequenceKeypoint.new(0.35, CREAM),
		ColorSequenceKeypoint.new(1, LEMON),
	})
	d.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.35, 3.4),
		NumberSequenceKeypoint.new(1, 1.8),
	})
	d.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.55, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	d.Lifetime = NumberRange.new(0.60, 0.95)
	d.Speed = NumberRange.new(11, 21)
	-- Out along the floor, not up: a ring of dust leaving the plant reads as weight going into
	-- the ground. Straight up reads as a puff of smoke.
	d.EmissionDirection = Enum.NormalId.Top
	d.SpreadAngle = Vector2.new(88, 88)
	d.Drag = 7
	d.Acceleration = Vector3.new(0, -6, 0)
	d.LightEmission = 0.55
	dust = d

	local sh = emitter(rig, "Shards")
	sh.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WHITE),
		ColorSequenceKeypoint.new(0.3, LEMON),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(226, 140, 30)),
	})
	sh.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.75),
		NumberSequenceKeypoint.new(1, 0),
	})
	sh.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.75, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	sh.Lifetime = NumberRange.new(0.34, 0.60)
	sh.Speed = NumberRange.new(24, 46)
	sh.EmissionDirection = Enum.NormalId.Top
	sh.SpreadAngle = Vector2.new(52, 52)
	sh.Drag = 3
	sh.Acceleration = Vector3.new(0, -70, 0)
	sh.LightEmission = 1
	shards = sh

	slamRig = rig
end

-- The finisher's plant. `cf` stands at the point the tip reaches the floor, with +Y up.
-- `scale` (default 1) multiplies the disc's reach and the particle counts.
function SwingImpact.slam(cf: CFrame?, scale: number?)
	if typeof(cf) ~= "CFrame" then
		return
	end
	ensureSlam()
	local rig, disc, d, sh = slamRig, slamDisc, dust, shards
	if not (rig and disc and d and sh) then
		return
	end
	local k = math.clamp(scale or 1, 0.4, 2)
	local flat = CFrame.new(cf.Position) -- world-axis-aligned: the floor is flat, the swing is not
	rig.CFrame = flat

	for _, tween in ipairs(slamTweens) do
		tween:Cancel()
	end
	table.clear(slamTweens)

	-- The disc starts a hair above the floor so it does not z-fight with the ground it is drawn
	-- on, and lies flat (a Cylinder's round face is normal to its X).
	disc.CFrame = flat * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.rad(90))
	disc.Size = Vector3.new(0.10, 1.8 * k, 1.8 * k)
	disc.Transparency = 0.02

	local grow = TweenService:Create(disc, TweenInfo.new(0.62, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.10, 22 * k, 22 * k),
		Transparency = 1,
	})
	grow:Play()
	table.insert(slamTweens, grow)

	d:Emit(math.floor(34 * k))
	sh:Emit(math.floor(30 * k))
end

-- Drop both rigs. Only used by the Studio capture stages, which tear the world down between
-- takes; ordinary play keeps them for the session.
function SwingImpact.clear()
	if sparkRig then
		Debris:AddItem(sparkRig, 0)
	end
	if flash then
		Debris:AddItem(flash, 0)
	end
	if slamRig then
		Debris:AddItem(slamRig, 0)
	end
	if slamDisc then
		Debris:AddItem(slamDisc, 0)
	end
	sparkRig, sparks, grit, flash, flashTween = nil, nil, nil, nil, nil
	slamRig, slamDisc, dust, shards = nil, nil, nil, nil
	table.clear(slamTweens)
end

return SwingImpact
