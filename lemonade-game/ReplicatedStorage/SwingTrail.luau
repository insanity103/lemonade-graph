-- SwingTrail — the streak off the outer third of the blade, shared by every swing.
--
-- It was a local in StarterPack/ClassicSword/SwordClient, which was fine while the tool script
-- was the only thing that swung. The heavy attack is bound in StarterPlayerScripts (it is a hold
-- and a release, not a Tool.Activated) and needs the same ribbon on the same blade, so the
-- ribbon is one definition both of them call rather than two that can drift apart. The ribbon's
-- span and life were narrowed by the chain piece (see ribbonEnds and MAX_LIFETIME); the colour,
-- the emission and the width falloff are the arc piece's.
--
-- Local by design, not an oversight. The swing itself is local: AnimationController drives this
-- character's Motor6Ds on this client only, so on every other client the blade is wherever the
-- stock animations left it. A replicated trail would be drawn along a blade that is not swinging,
-- and would arrive a round trip late besides. It costs no network traffic and one Trail instance
-- per sword.
local SwingTrail = {}

-- The longest a ribbon segment may linger, whatever the swing's drive lasts. The finisher's
-- drive is 300 ms, and a ribbon that lived that long drew its whole 190-degree sweep as one
-- sheet around the character, and at 0.18 s it was still a fan across a third of the frame; at
-- 0.12 s the streak is the last ~40 degrees of travel behind the tip -- enough to show the
-- direction of the cut in a frame, short enough that the frame after contact shows a blade.
SwingTrail.MAX_LIFETIME = 0.12 -- [TUNING] seconds

-- The FINISHER's ribbon, and only the finisher's. Hit 5 is one 80 ms pass through 12 studs --
-- the fastest, widest thing in the chain -- and at the narrow span above it left the same streak
-- as a 250 ms light swing, which is most of why two rounds of critics read the fifth hit as
-- "the smallest pose in the strip". This is the only swing allowed a longer ribbon, because it
-- is the only swing whose whole point is that it is bigger than the others. Hits 1-4 keep the
-- narrow streak: five of these laid over each other is the fan the arc piece removed.
SwingTrail.BIG_LIFETIME = 0.22 -- [TUNING] seconds
SwingTrail.BIG_SPAN = 0.46 -- [TUNING] fraction of the blade the ribbon spans (narrow is 0.26)

-- [tool] = Trail. Weak-keyed: a dropped or destroyed sword takes its entry with it.
local trails = setmetatable({}, { __mode = "k" })

local function ribbonEnds(tool: Tool, handle: BasePart): (Vector3, Vector3)
	-- The blade runs down the handle's -Z. Measure how far, over every welded part of this
	-- tool, so a boss sword with a different MeshPart blade gets a ribbon the right length.
	local far = -1.2
	local inverse = handle.CFrame:Inverse()
	for _, part in ipairs(tool:GetDescendants()) do
		if part:IsA("BasePart") then
			local cf = inverse * part.CFrame
			local half = part.Size * 0.5
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local corner = cf * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
						far = math.min(far, corner.Z)
					end
				end
			end
		end
	end
	-- The ribbon spans the outer 26% of the blade, about one stud. It was 70% (2.7 studs), which
	-- on a single diagonal cut drew the arc -- but a five-hit chain at 250 ms a hit lays five
	-- such sheets over each other, each wider than the character, and the chain's critics read
	-- them as "a sprite sweeping through a ball rather than a blade with mass": the fan was
	-- selling the contact instead of the cut. At one stud the ribbon is a streak off the tip,
	-- narrower than the body, and the pass is read from the blade and the torso with the streak
	-- only joining the frames up. The hand end of the blade never had a ribbon: it moves slowest
	-- and only smears the body behind it.
	return Vector3.new(0, 0, far * 0.74), Vector3.new(0, 0, far * 1.00), far
end

-- [tool] = the handle-space Z of the blade tip, measured once in ribbonEnds. `light` uses it to
-- widen the ribbon for the finisher and to hand SwordClient the tip for the slam's ground burst.
local tipZ = setmetatable({}, { __mode = "k" })

-- The tool's ribbon, built on first use. Returns nil for a tool with no Handle.
function SwingTrail.ensure(tool: Tool?): Trail?
	if not tool then
		return nil
	end
	local existing = trails[tool]
	if existing and existing.Parent then
		return existing
	end
	local handle = tool:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then
		return nil
	end
	local nearPos, farPos, far = ribbonEnds(tool, handle)
	tipZ[tool] = far

	local a0 = Instance.new("Attachment")
	a0.Name = "SwingTrailNear"
	a0.Position = nearPos
	a0.Parent = handle

	local a1 = Instance.new("Attachment")
	a1.Name = "SwingTrailFar"
	a1.Position = farPos
	a1.Parent = handle

	local made = Instance.new("Trail")
	made.Name = "SwingTrail"
	made.Attachment0 = a0
	made.Attachment1 = a1
	-- SATURATED, not white. Lemonade's palette, driven up until it survives Lemonade's own
	-- backgrounds: the ribbon leaves the edge as bright lemon and deepens to a hot amber-orange
	-- as it falls behind. It used to start at pure white and warm only to a pale lemon, which is
	-- the same read the village's sand, plaster and sky give a camera -- round 5's blind read
	-- called the whole arc unreadable at speed for exactly that reason, and the fix it named was
	-- "darken the blade or add a saturated trail". Both are done: the steel is blued (see
	-- RuntimeBootstrap) and the ribbon is now the brightest, most saturated thing in the frame,
	-- which is the pairing that makes a cut legible -- a dark edge with a hot streak behind it.
	-- It is still light off a blade rather than smoke, and it is still Lemonade's own yellow.
	made.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 244, 148)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 196, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(246, 120, 16)),
	})
	-- Still translucent, and still fading fast along its length -- the arc has to be read off the
	-- blade and the body, and the ribbon is there to join the frames up, not to be the effect.
	-- The head of it is nearly solid now though: at 0.24 the ribbon disappeared against a bright
	-- Lemonade background in exactly the frames it exists for.
	-- The head is opaque now (0.15 -> 0.02) and the mid holds longer before it goes. The ribbon
	-- only exists in the two or three rendered frames a pass occupies, and at 0.15 over a bright
	-- background those frames showed a suggestion of a streak rather than a streak.
	made.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.02),
		NumberSequenceKeypoint.new(0.45, 0.38),
		NumberSequenceKeypoint.new(1, 1),
	})
	made.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.08),
	})
	-- Each swing sets its own lifetime in `light` below: its drive length, capped at MAX_LIFETIME.
	-- A ribbon that lasted the whole follow-through drew the whole arc as a sheet; the frames after
	-- the pass are proved by the body's follow-through, not by a fan hanging in the air.
	made.Lifetime = SwingTrail.MAX_LIFETIME
	made.MinLength = 0.05
	-- Low emission, and lower than it was: emission washes a colour toward white, which is the
	-- one thing this ribbon must not do now that its whole job is to be saturated. At 0.5 it blew
	-- out to flat white over the character on contact; at 0.30 the hot amber still drifted pale.
	made.LightEmission = 0.12
	made.LightInfluence = 0
	made.FaceCamera = false
	made.Enabled = false
	made.Parent = handle

	trails[tool] = made
	return made
end

-- Light the ribbon for a drive that lasts `lifetime` seconds (the swing's WINDUP to its
-- SWING_END), so the ribbon a pass lays down is still on screen at the far end of that arc and
-- gone before the body finishes settling.
function SwingTrail.light(tool: Tool?, lifetime: number, big: boolean?): Trail?
	local trail = SwingTrail.ensure(tool)
	if trail then
		local near = trail.Attachment0
		local far = tipZ[tool]
		if near and far then
			-- Two property writes, and only when the span is not already the one this swing
			-- wants: the finisher gets the long ribbon, everything else the narrow streak.
			local want = far * (if big then 1 - SwingTrail.BIG_SPAN else 0.74)
			if math.abs(near.Position.Z - want) > 1e-3 then
				near.Position = Vector3.new(0, 0, want)
			end
		end
		trail.Lifetime = math.min(lifetime, if big then SwingTrail.BIG_LIFETIME else SwingTrail.MAX_LIFETIME)
		trail.Enabled = true
	end
	return trail
end

-- Where the blade tip is in the world right now. Measured off the same blade length the ribbon
-- was built from, so a boss sword with a longer MeshPart blade reports its own tip.
function SwingTrail.tip(tool: Tool?): Vector3?
	if not tool then
		return nil
	end
	local handle = tool:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then
		return nil
	end
	local far = tipZ[tool]
	if not far then
		local _, _, measured = ribbonEnds(tool, handle)
		far = measured
		tipZ[tool] = far
	end
	return (handle.CFrame * CFrame.new(0, 0, far)).Position
end

function SwingTrail.out(tool: Tool?)
	local trail = tool and trails[tool]
	if trail and trail.Parent then
		trail.Enabled = false
	end
end

-- Is this tool's ribbon currently lit? Used by the safety nets that put out a ribbon whose clip
-- was cut short by a respawn or by the next swing.
function SwingTrail.lit(tool: Tool?): boolean
	local trail = tool and trails[tool]
	return trail ~= nil and trail.Parent ~= nil and trail.Enabled
end

return SwingTrail
