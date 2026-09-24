-- SwingBlade — where the sword's blade is, in character space, on the frames the hitbox uses.
--
-- The server's hit test has to fire on the frame the blade passes through the target and has to
-- use the blade's real position on that frame. Both of those are facts about the swing clip, so
-- this module reads them OUT of the clip rather than restating them: it samples
-- `Sword Attack Animation` at the contact frame through the same sampler the client plays it
-- with (AnimationController.SampleClip), walks the result down the character's own arm with the
-- character's own Motor6Ds, and follows the tool's grip weld onto the blade.
--
-- It replaces a hand-copied table of CFrames. That table was correct when it was written and
-- wrong the moment the clip was re-timed or the contact pose moved -- which is exactly what
-- happened when the chest picked up 52 degrees of roll through the strike and the blade came
-- down with it. Derived, the hitbox cannot be left behind by the animation.
--
-- ── Server authority ────────────────────────────────────────────────────────────────────
-- Nothing here is client input. The clip is a module the server ships and reads itself; the
-- rig data is the character as the SERVER sees it; the caller applies the result to the
-- character's root as the server sees it, at the moment the server decided the blade would be
-- there. The client cannot say where its blade is, when it swung, or what it hit.
--
-- ── The grip, which is easy to get backwards ────────────────────────────────────────────
-- Roblox welds a Tool's Handle to the right hand with a Weld named "RightGrip" whose Part0 is
-- the hand and whose C1 is Tool.Grip, so Handle.CFrame = RightHand.CFrame * C0 * C1:Inverse().
-- The classic sword stands UP out of the fist: the blade runs down the handle's -Z, away from
-- the hand, which is why BLADE_SPAN below is measured along -Z and why the animation holds the
-- wrist near 90 degrees through the arc.
--
-- ── Cost ────────────────────────────────────────────────────────────────────────────────
-- Once per character per tool PER CLIP, cached against all three (weak keys, so a respawn or a
-- dropped sword drops the entry): three clip samples, and for each one five Motor6D compositions
-- plus the grip. The chain has five clips, so a player who throws a full combo pays it five
-- times in their first chain and never again. Every swing after that is two table lookups.
-- Nothing runs per frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationController = require(ReplicatedStorage:WaitForChild("AnimationController"))
local SwingTiming = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwingTiming"))

local SwingBlade = {}

-- The arm, root first. Each entry is the part a Motor6D drives and the part it hangs off, which
-- is how the joint is found: Motor6D.Part1.Name is the key the clip uses too.
local CHAIN = {
	{ part = "LowerTorso", parent = "HumanoidRootPart" },
	{ part = "UpperTorso", parent = "LowerTorso" },
	{ part = "RightUpperArm", parent = "UpperTorso" },
	{ part = "RightLowerArm", parent = "RightUpperArm" },
	{ part = "RightHand", parent = "RightLowerArm" },
}

-- How much of the sword counts as "the blade", as a fraction of the tool's reach down the
-- handle's -Z: from just past the guard to the tip. The same span the client's trail uses, so
-- the ribbon a player watches and the segment the server tests are the same piece of steel.
local BLADE_NEAR, BLADE_FAR = 0.12, 1.00

local cache = setmetatable({}, { __mode = "k" })

-- Where the blade is in the Handle's own space: the grip point it starts from, the way it points,
-- and how far it reaches, measured over every part of the tool so a longer blade gets a longer
-- segment. The block sword's Handle origin IS the grip and its blade runs down the Handle's -Z.
-- A sword MESH is the other way round (BossSwordFactory.meshGrip): centred on the whole sword,
-- tip at its own +Z, hand SWORD_GRIP_FRAC of its length back toward -Z -- which Tool.Grip's
-- translation carries. Measuring every sword down -Z from the Handle's centre put a mesh sword's
-- hitbox from mid-blade back through the fist to the pommel, so every spin, zone and boss sword
-- reached ~3.6 studs from the hand where the starter reached 5.8 (2026-09-24 playtest: "hits only
-- land when the cursor is on the enemy").
local function bladeAxis(tool: Tool, handle: BasePart): (Vector3, Vector3, number)
	local origin = if handle:IsA("MeshPart") then tool.Grip.Position else Vector3.zero
	local dir = if handle:IsA("MeshPart") then Vector3.new(0, 0, 1) else Vector3.new(0, 0, -1)
	local reach = 1.2
	local inverse = handle.CFrame:Inverse()
	for _, part in ipairs(tool:GetDescendants()) do
		if part:IsA("BasePart") then
			local cf = inverse * part.CFrame
			local half = part.Size * 0.5
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local corner = cf * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
						reach = math.max(reach, (corner - origin):Dot(dir))
					end
				end
			end
		end
	end
	return origin, dir, reach
end

-- ── Two kinds of joint ──────────────────────────────────────────────────────────────────
-- A Lemonade character is not guaranteed to be jointed with Motor6Ds. Roblox's current R15
-- rig hangs each limb off an AnimationConstraint instead: the part has no Motor6D at all, it
-- has an AnimationConstraint whose Attachment0 sits on the parent part and whose Attachment1
-- sits on the child, plus a BallSocketConstraint beside it. AnimationController already reads
-- both kinds (it indexes a Motor6D by Part1.Name and an AnimationConstraint by
-- Attachment1.Parent.Name), and it is the same clip driving the same rig here, so this has to
-- read both too. It did not, and on a constraint rig `jointsOf` came back empty, `handleAt`
-- bailed on the first link, `SwingBlade.contact` returned nil for every clip -- and the
-- caller's honest "nothing can be cut" turned into a sword that could not hit anything at
-- all. The filmstrip is what caught it: the stage's `[SwingArc] contact blade` line never
-- printed, so the capture target fell back to a fixed 4.6 studs ahead.
--
-- The two compose identically once the right fields are named:
--   Motor6D               child.CFrame = parent.CFrame * C0 * Transform * C1:Inverse()
--   AnimationConstraint   child.CFrame = parent.CFrame * A0.CFrame * Transform * A1.CFrame:Inverse()
-- so a link is read down to (parent name, C0, C1) and the chain below does not care which
-- kind it walked over.
local function linkOf(joint): (string?, CFrame?, CFrame?)
	if joint:IsA("Motor6D") then
		if not joint.Part0 then
			return nil
		end
		return joint.Part0.Name, joint.C0, joint.C1
	elseif joint:IsA("AnimationConstraint") then
		local a0, a1 = joint.Attachment0, joint.Attachment1
		local parent = a0 and a0.Parent
		if not (a0 and a1 and parent and parent:IsA("BasePart")) then
			return nil
		end
		return parent.Name, a0.CFrame, a1.CFrame
	end
	return nil
end

local function jointsOf(character: Model)
	local joints = {}
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("Motor6D") and desc.Part1 then
			joints[desc.Part1.Name] = desc
		elseif desc:IsA("AnimationConstraint") and desc.Attachment1 then
			local part = desc.Attachment1.Parent
			-- A Motor6D wins if a rig somehow carries both, because that is the one whose
			-- Transform the Animator writes.
			if part and part:IsA("BasePart") and not joints[part.Name] then
				joints[part.Name] = desc
			end
		end
	end
	return joints
end

-- The sword handle's CFrame relative to the HumanoidRootPart, with the clip's pose applied.
-- Starting from identity at the root makes every CFrame below character space.
local function handleAt(joints, grip: Weld, pose): CFrame?
	local cframe = CFrame.identity
	for _, link in ipairs(CHAIN) do
		local joint = joints[link.part]
		-- The parent is checked, not assumed. On an R6 rig, or a character still streaming in,
		-- "RightHand" either is not there or hangs off something else, and composing the chain
		-- anyway would hand the server a confident hitbox in the wrong place. Bail instead: the
		-- caller reads nil as "nothing can be cut", which is a missed swing, not a phantom hit.
		if not joint then
			return nil
		end
		local parentName, c0, c1 = linkOf(joint)
		if parentName ~= link.parent or not c0 or not c1 then
			return nil
		end
		cframe = cframe * c0 * (pose[link.part] or CFrame.identity) * c1:Inverse()
	end
	return cframe * grip.C0 * grip.C1:Inverse()
end

-- A box, oriented along the blade rather than along the world, containing every sample of the
-- blade plus `pad`. This is only the broad phase GetPartBoundsInBox needs: an axis-aligned box
-- around a blade travelling 300 studs a second is mostly empty corner, so the caller still has
-- to check each candidate against the segments themselves.
local function boxAround(segments, pad: number): (CFrame, Vector3)
	local mid = segments[math.ceil(#segments / 2)]
	local along = (mid.B - mid.A)
	along = if along.Magnitude > 1e-4 then along.Unit else Vector3.new(0, 0, -1)
	local side = along:Cross(Vector3.new(0, 1, 0))
	side = if side.Magnitude > 1e-4 then side.Unit else along:Cross(Vector3.new(1, 0, 0)).Unit
	local up = side:Cross(along)
	local axes = { side, up, along }

	local lo, hi = {}, {}
	for axis = 1, 3 do
		lo[axis], hi[axis] = math.huge, -math.huge
		for _, seg in ipairs(segments) do
			for _, point in ipairs({ seg.A, seg.B }) do
				local d = point:Dot(axes[axis])
				lo[axis] = math.min(lo[axis], d)
				hi[axis] = math.max(hi[axis], d)
			end
		end
		lo[axis] -= pad
		hi[axis] += pad
	end

	local centre = Vector3.zero
	for axis = 1, 3 do
		centre += axes[axis] * ((lo[axis] + hi[axis]) * 0.5)
	end
	return CFrame.fromMatrix(centre, side, up, -along),
		Vector3.new(hi[1] - lo[1], hi[2] - lo[2], hi[3] - lo[3])
end

-- The blade on the contact frame of `clip`, at `contactTime` into it, in character space. Each
-- hit of the chain is a different swing with a different contact frame, so each one asks for its
-- own -- that is what keeps the hitbox on the blade rather than on hit 1's blade.
--
--   Segments  { { A = guard, B = tip }, ... } at each of SwingTiming.CONTACT_SAMPLES
--   Radius    how far from one of those segments a target's root may be and still be cut
--   BoxCFrame / BoxSize   the broad-phase box, in character space, around all of them
-- Returns nil if the rig or the grip is not there yet, which the caller treats as "no hit".
function SwingBlade.contact(character: Model, tool: Tool, clip, contactTime: number?)
	contactTime = contactTime or SwingTiming.CONTACT
	local entry = cache[character]
	if entry and entry.tool ~= tool then
		entry = nil -- a different sword: different blade, different reach
	end
	if entry and entry.byClip[clip] then
		return entry.byClip[clip]
	end

	local hand = character:FindFirstChild("RightHand")
	local grip = hand and hand:FindFirstChild("RightGrip")
	local handle = tool and tool:FindFirstChild("Handle")
	if not (grip and grip:IsA("Weld") and handle and handle:IsA("BasePart")) then
		return nil
	end

	local joints = jointsOf(character)
	local origin, dir, reach = bladeAxis(tool, handle)

	local segments = {}
	for _, offset in ipairs(SwingTiming.CONTACT_SAMPLES) do
		local pose = AnimationController.SampleClip(clip, contactTime + offset)
		local cframe = handleAt(joints, grip, pose)
		if not cframe then
			return nil
		end
		table.insert(segments, {
			A = cframe * (origin + dir * (reach * BLADE_NEAR)),
			B = cframe * (origin + dir * (reach * BLADE_FAR)),
		})
	end

	local boxCFrame, boxSize = boxAround(segments, SwingTiming.BLADE_RADIUS)
	local hit = {
		Segments = segments,
		Radius = SwingTiming.BLADE_RADIUS,
		BoxCFrame = boxCFrame,
		BoxSize = boxSize,
	}
	if not entry then
		entry = { tool = tool, byClip = {} }
		cache[character] = entry
	end
	entry.byClip[clip] = hit
	return hit
end

-- The blade across the WHOLE cut, not just the contact frame: every SWEEP_STEP from `fromTime`
-- (the end of the wind-up) to `toTime` (the end of the follow-through). The contact samples above
-- cover about 11 ms of a swing whose blade is visibly cutting for 200-300 ms, so anything the
-- blade went through before or after that sliver -- off to one side, or under the arc -- took no
-- damage, and only a target square in front of the player at the contact frame could be hit.
-- Same shape as contact() (Segments / BoxCFrame / BoxSize), cached the same way.
local SWEEP_STEP = 1 / 120 -- [TUNING] seconds between blade samples; the tip moves ~2.5 studs per step at its fastest
function SwingBlade.sweep(character: Model, tool: Tool, clip, fromTime: number, toTime: number)
	local entry = cache[character]
	if entry and entry.tool ~= tool then
		entry = nil
	end
	local key = string.format("%.3f:%.3f", fromTime, toTime)
	local byClip = entry and entry.sweeps and entry.sweeps[clip]
	if byClip and byClip[key] then
		return byClip[key]
	end

	local hand = character:FindFirstChild("RightHand")
	local grip = hand and hand:FindFirstChild("RightGrip")
	local handle = tool and tool:FindFirstChild("Handle")
	if not (grip and grip:IsA("Weld") and handle and handle:IsA("BasePart")) then
		return nil
	end
	local joints = jointsOf(character)
	local origin, dir, reach = bladeAxis(tool, handle)
	local segments = {}
	local steps = math.max(1, math.ceil((toTime - fromTime) / SWEEP_STEP))
	for i = 0, steps do
		local pose = AnimationController.SampleClip(clip, fromTime + (toTime - fromTime) * i / steps)
		local cframe = handleAt(joints, grip, pose)
		if not cframe then
			return nil
		end
		table.insert(segments, {
			A = cframe * (origin + dir * (reach * BLADE_NEAR)),
			B = cframe * (origin + dir * (reach * BLADE_FAR)),
		})
	end
	-- One box around the whole arc: it is only the broad phase.
	local lo, hi
	for _, seg in ipairs(segments) do
		for _, p in ipairs({ seg.A, seg.B }) do
			lo = if lo then lo:Min(p) else p
			hi = if hi then hi:Max(p) else p
		end
	end
	local pad = Vector3.one * (SwingTiming.BLADE_RADIUS * 2)
	local hit = {
		Segments = segments,
		Radius = SwingTiming.BLADE_RADIUS,
		BoxCFrame = CFrame.new((lo + hi) / 2),
		BoxSize = (hi - lo) + pad,
	}
	if not entry then
		entry = { tool = tool, byClip = {} }
		cache[character] = entry
	end
	entry.sweeps = entry.sweeps or {}
	entry.sweeps[clip] = entry.sweeps[clip] or {}
	entry.sweeps[clip][key] = hit
	return hit
end

return SwingBlade
