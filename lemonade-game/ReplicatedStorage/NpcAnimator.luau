--// NpcAnimator  (client-side standing idle for the town's service NPCs)
--
-- The server builds the service NPCs (GameplayActors.create) from the prebuilt R15 rigs in
-- ReplicatedStorage.NpcModels, anchors only their HumanoidRootPart, tags them "ServiceNpc" and
-- names their job in the "NpcRole" attribute (the NpcOutfits name: Blacksmith, QuestMaster,
-- Vaultkeeper, RebirthKeeper, Trainer). Nothing about them moves on the server.
-- Each client poses their joints locally through Motor6D.Transform, every frame, in one shared
-- PreSimulation loop (the same approach EnemyAnimator uses for enemies, kept separate from it).
-- Nothing here writes C0, positions or prompts, and nothing replicates.
--
-- The idle is layered, every layer on its own randomised clock (so no two NPCs move in step and
-- none loops mechanically):
--   * stance   a job pose: the smith's fist on his hip and hammer held at the ready, the sage's
--              staff planted, the quest giver's scroll held to the chest...
--   * breath   a 3.2-4 s cycle with a quicker inhale than exhale: the chest pitches ~2 degrees,
--              the shoulders rise ~0.05 studs ~100 ms after it and the arms trail ~150 ms
--   * sway     a slow, never-repeating pelvis drift of a few hundredths of a stud
--   * weight   every few seconds the hips carry ~0.15 studs onto one leg (eased, ~0.5 s) with a
--              ~3 degree hip roll, the shoulders counter-tilt and the torso counter-turns ~3
--              degrees; the head lags the torso by 120 ms; the feet stay planted (two-bone IK)
--   * look     with a player nearby the head tracks them softly; every few seconds it glances off
--              (20-45 degrees, the eyes leading and the torso following ~5 degrees 120 ms late),
--              holds and comes back
--   * blink    every 2-5 s (sometimes twice)
--   * gesture  every 5-9 s a job beat, keyframed through the whole body (see GESTURES)
--   * react    when the local player walks within NOTICE_RANGE, the NPC notices them: the eyes
--              lead, the head snaps round in ~160 ms (a small overshoot), the chest follows ~120 ms
--              behind and the whole body turns on its planted feet (a visual turn through the Root
--              joint; each foot steps round after it), then a greeting in character (GREETINGS),
--              and it keeps tracking the player loosely while they stay. When they leave it eases
--              back to its post facing. A greeting plays at most once per GREET_COOLDOWN.
-- NPCs a HubAmbience routine has walked away from their post (attribute "AmbienceBusy") are left
-- alone until they are back.
--
-- Pose space: rotations are degrees in each joint's parent axes (+X right, +Y up, -Z forward);
-- pitch + swings a limb forward (tilts the torso or head back), yaw + turns to the NPC's left,
-- roll + tips toward the NPC's left (lifts the right side).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local NpcAnimator = {}

local TAG = "ServiceNpc"
local ROLE_ATTRIBUTE = "NpcRole"
local BUSY_ATTRIBUTE = "AmbienceBusy" -- set by HubAmbience while a routine walks the NPC away
local CUE_ATTRIBUTE = "NpcIdleCue" -- Studio showcase only: server time to play a glance + gesture
local FRESH_ATTRIBUTE = "NpcReactFresh" -- Studio showcase only: forget earlier greetings (cooldown)
local ANIMATE_RANGE = 140 -- [TUNING] studs from the camera; farther NPCs stop being posed
-- An NPC out of view holds its pose and catches the skipped time up when it comes back. "In view"
-- is generous (the view cone plus a margin and the NPC's reach, its shadow included, and anyone
-- close to the camera), so nothing on screen ever freezes.
local VIEW_MARGIN = math.rad(12) -- [TUNING] radians added around the camera's view cone
local VIEW_NEAR = 30 -- [TUNING] studs; NPCs this close always animate
local VIEW_RADIUS = 8 -- [TUNING] studs an NPC and its shadow may reach
local NOTICE_RANGE = 14 -- [TUNING] studs; a player walking this close is noticed and greeted
local LEAVE_RANGE = 18 -- [TUNING] studs; beyond this (or behind) the NPC lets them go
local NOTICE_ARC = 115 -- [TUNING] degrees either side of the NPC's facing it notices within
local GREET_COOLDOWN = { 20, 30 } -- [TUNING] seconds before the same NPC greets the player again

local rad, clamp = math.rad, math.clamp

-- ==============================================================================
-- Easing and keyed curves
-- ==============================================================================
local EASE = {
	linear = function(u) return u end,
	inQuad = function(u) return u * u end,
	outQuad = function(u) return 1 - (1 - u) * (1 - u) end,
	outCubic = function(u) local v = 1 - u return 1 - v * v * v end,
	inOutQuad = function(u)
		if u < 0.5 then return 2 * u * u end
		local v = -2 * u + 2
		return 1 - v * v / 2
	end,
	inOutCubic = function(u)
		if u < 0.5 then return 4 * u * u * u end
		local v = -2 * u + 2
		return 1 - v * v * v / 2
	end,
	inOutSine = function(u) return 0.5 - 0.5 * math.cos(math.pi * u) end,
}

-- keys = { { t, value, ease? }, ... }
local function curve(keys, t: number): number
	if t <= keys[1][1] then
		return keys[1][2]
	end
	for i = 2, #keys do
		local k = keys[i]
		if t <= k[1] then
			local p = keys[i - 1]
			local u = (t - p[1]) / (k[1] - p[1])
			return p[2] + (k[2] - p[2]) * EASE[k[3] or "linear"](u)
		end
	end
	return keys[#keys][2]
end

local function between(range): number
	return range[1] + (range[2] - range[1]) * math.random()
end

local function euler(pitch: number, yaw: number, roll: number): CFrame
	return CFrame.fromEulerAnglesYXZ(rad(pitch), rad(yaw), rad(roll))
end

-- ==============================================================================
-- Channels
-- ==============================================================================
-- hips   { x, y, z, pitch, yaw, roll }  LowerTorso about the HumanoidRootPart (studs, degrees)
-- waist  { pitch, yaw, roll }            UpperTorso on the LowerTorso
-- neck   { pitch, yaw, roll }            head on the UpperTorso (the look layer adds to this)
-- rsh/lsh { pitch, yaw, roll, twist }    shoulders; twist turns the upper arm about its own length
--                                        first (so the elbow can bend across the body)
-- rel/lel { flex, twist }                elbows: flex + bends the forearm up/forward; twist turns
--                                        the forearm about its own length (+ turns the thumb out
--                                        on the right arm... see stances for what reads)
-- rwr/lwr { pitch, yaw, roll }           wrists
-- lift   { right, left }                 shoulders raised (studs)
-- lfoot/rfoot { x, z }                   planted foot offset from its rest spot (studs)
-- look   { yaw, pitch, weight }          a gesture's own gaze (body-relative), blended in by weight
-- eyes   { x, y }                        eye offset on the face (studs)
-- brow   { y }
-- keys   { swing }                       the vaultkeeper's key ring (degrees)
-- turn   { body, lfoot, rfoot, llift, rlift } the react layer's whole-body turn about the root's
--                                        vertical axis and each planted foot's own turn (degrees)
--                                        and lift (studs) as it steps round after the body
local CHANNELS = {
	hips = 6, waist = 3, neck = 3, rsh = 4, lsh = 4, rel = 2, lel = 2, rwr = 3, lwr = 3,
	lift = 2, lfoot = 2, rfoot = 2, look = 3, eyes = 2, brow = 1, keys = 1, turn = 5,
}
local CHANNEL_NAMES = {}
for name in pairs(CHANNELS) do
	table.insert(CHANNEL_NAMES, name)
end
table.sort(CHANNEL_NAMES)

local function zeroPose()
	local pose = {}
	for name, n in pairs(CHANNELS) do
		local a = table.create(n, 0)
		pose[name] = a
	end
	return pose
end

local function copyInto(dst, src)
	for name, a in pairs(src) do
		local d = dst[name]
		for i = 1, #a do
			d[i] = a[i]
		end
	end
end

-- ==============================================================================
-- Jobs: stance, rhythms and gestures per NpcRole
-- ==============================================================================
-- Gestures are keyed poses over their own clock, ADDED to the stance and the running layers.
-- Each key: { t, ease-into-this-key, { channel = { values... } } }; a channel a key leaves out is
-- zero there. `look` is the head's own gaze during the beat (weight 1 = it wins over the idle look).
local ROLES = {}

ROLES.Blacksmith = {
	-- Planted wide, chest out, left fist on the hip, the hammer hanging from the right fist with
	-- its head forward and down by the knee, so its weight reads.
	stance = {
		hips = { 0, -0.02, 0, 0, 3, 0 },
		waist = { 3, -2, 0 },
		neck = { -3, 0, 0 },
		rsh = { 4, 0, 8, 0 },
		rel = { 10, 90 },
		rwr = { 0, 0, -60 },
		lsh = { 0, 0, -20, -90 },
		lel = { 65, 0 },
		lwr = { 0, 0, 0 },
		lfoot = { -0.14, -0.12 },
		rfoot = { 0.12, 0.1 },
	},
	breathPeriod = { 3.2, 3.5 },
	breathPitch = 1.8,
	shiftGap = { 2.5, 5 },
	shiftTime = 0.5,
	glanceGap = { 2.8, 5.5 },
	glanceYaw = { 22, 38 },
	gestureGap = { 4.5, 7 },
	gestures = { "tap", "heft" },
	cueGesture = "tap",
	cueGlance = -26,
}

ROLES.QuestMaster = {
	-- Upright and attentive, the scroll held against the chest, the free hand behind the back.
	stance = {
		hips = { 0, -0.03, 0, 0, 0, 0 },
		waist = { 1, 0, 0 },
		neck = { 2, 0, 0 },
		rsh = { 28, 18, 4 },
		rel = { 70, 90 },
		rwr = { 0, 0, 0 },
		lsh = { -18, 20, -6 },
		lel = { 40, 0 },
		lwr = { 0, 0, 0 },
		lfoot = { -0.08, -0.08 },
		rfoot = { 0.08, 0.06 },
	},
	breathPeriod = { 3.4, 3.8 },
	breathPitch = 1.6,
	shiftGap = { 3.5, 6.5 },
	shiftTime = 0.7,
	glanceGap = { 3, 6 },
	glanceYaw = { 25, 45 },
	gestureGap = { 5, 8 },
	gestures = { "read", "scan" },
	cueGesture = "read",
	cueGlance = -30,
}

ROLES.Vaultkeeper = {
	-- A careful clerk: shoulders a little hunched, head forward, the ledger held in front.
	stance = {
		hips = { 0, -0.04, 0.02, 0, 0, 0 },
		waist = { -5, 0, 0 },
		neck = { 6, 0, 0 },
		rsh = { 26, 12, 2 },
		rel = { 60, 90 },
		rwr = { 0, 0, 0 },
		lsh = { 8, 0, -4 },
		lel = { 14, 0 },
		lwr = { 0, 0, 0 },
		lfoot = { -0.05, 0 },
		rfoot = { 0.05, 0 },
	},
	breathPeriod = { 3.2, 3.6 },
	breathPitch = 1.7,
	shiftGap = { 3, 6 },
	shiftTime = 0.55,
	glanceGap = { 2.2, 4.5 },
	glanceYaw = { 20, 40 },
	gestureGap = { 4.5, 8 },
	gestures = { "keys", "ledger" },
	cueGesture = "keys",
	cueGlance = -28,
}

ROLES.RebirthKeeper = {
	-- Tall and calm, the staff planted upright beside him, the free hand resting at the sash.
	stance = {
		hips = { 0, -0.03, 0, 0, 0, 0 },
		waist = { 2, 0, 0 },
		neck = { -2, 0, 0 },
		rsh = { 10, 0, 14 },
		rel = { 80, 90 },
		rwr = { 0, 0, 0 },
		lsh = { 12, 0, -6 },
		lel = { 60, 0 },
		lwr = { 0, 0, 0 },
		lfoot = { -0.04, 0 },
		rfoot = { 0.04, 0 },
	},
	breathPeriod = { 3.8, 4.4 },
	breathPitch = 2.0,
	shiftGap = { 5, 8 },
	shiftTime = 0.9,
	glanceGap = { 4, 7 },
	glanceYaw = { 18, 32 },
	gestureGap = { 6, 10 },
	gestures = { "bow", "staff" },
	cueGesture = "staff",
	cueGlance = -24,
}

ROLES.Trainer = {
	-- An athlete's stance: feet wide, weight low, sword point down and forward.
	stance = {
		hips = { 0, -0.1, 0, 0, 6, 0 },
		waist = { -2, -3, 0 },
		neck = { 0, -3, 0 },
		rsh = { 12, 0, 8 },
		rel = { 25, 90 },
		rwr = { -45, 0, 0 },
		lsh = { 6, 0, -8 },
		lel = { 18, 0 },
		lwr = { 0, 0, 0 },
		lfoot = { -0.2, -0.2 },
		rfoot = { 0.2, 0.16 },
	},
	breathPeriod = { 3.0, 3.3 },
	breathPitch = 1.8,
	shiftGap = { 2, 4 },
	shiftTime = 0.45,
	glanceGap = { 2.5, 5 },
	glanceYaw = { 22, 40 },
	gestureGap = { 4.5, 7.5 },
	gestures = { "stretch", "blade" },
	cueGesture = "blade",
	cueGlance = -28,
}

local GESTURES = {}

-- The smith taps the hammer's head into his free palm, twice. 100 ms of anticipation (the hand
-- dips), the elbow bends ~70 degrees over 400 ms as the free hand leaves the hip to meet it, two
-- taps ~250 ms apart with a small wrist recoil on each contact, then the hammer is lowered over
-- 500 ms with a small overshoot and the fist goes back to the hip. He watches his hands.
GESTURES.tap = (function()
	-- Deltas from the stance to the hammer carried across the belly, its face against the free
	-- palm held up beside it (solved offline against the rig so the face meets the left hand).
	-- `up` (0..1) lifts the hammer's head off the palm: the elbow bends ~10 degrees more and the
	-- wrist cocks ~26; `recoil` pushes it 2 degrees past contact, and the palm gives with it.
	local function held(up: number, recoil: number?)
		local r = recoil or 0
		return {
			rsh = { -46, -7, -75, 0 }, rel = { 50 + 10 * up, 23 }, rwr = { -1 + 26 * up - 2 * r, 47, -15 },
			lsh = { 2, -88, -7, 90 }, lel = { -9, -31 }, lwr = { 7, 0, -2 + 2 * r },
			waist = { -3, 4, 0 }, look = { 20, -26, 1 },
		}
	end
	return {
		duration = 1.85,
		keys = {
			{ 0, nil, {} },
			-- anticipation: the fist dips before it lifts
			{ 0.1, "inOutQuad", { rsh = { -4, 0, 2, 0 }, rel = { -5, 0 }, hips = { 0, -0.01, 0, 0, 0, 0 },
				look = { 10, -20, 0.6 } } },
			-- the elbow bends and the hammer comes up, the free hand leaving the hip to meet it
			{ 0.45, "inOutCubic", held(1) },
			-- tap 1: down into the palm, a small recoil off it, up again
			{ 0.58, "inQuad", held(0) },
			{ 0.62, "outQuad", held(0, 1) },
			{ 0.71, "outQuad", held(0.85) },
			-- tap 2, ~250 ms after the first
			{ 0.83, "inQuad", held(0) },
			{ 0.87, "outQuad", held(0, 1) },
			{ 0.95, "inOutQuad", held(0.1) },
			-- lowered over 500 ms, overshooting a little before it settles
			{ 1.45, "inOutCubic", { rsh = { -3, 0, 1, 0 }, rel = { -4, 0 }, rwr = { 0, 0, -3 }, lsh = { -2, 0, -2, 0 },
				lel = { 4, 0 }, look = { 0, 0, 0 } } },
			{ 1.52, "outQuad", { rsh = { -1, 0, 0, 0 }, rel = { -1.5, 0 }, rwr = { 0, 0, -1 } } },
			{ 1.85, "inOutQuad", {} },
		},
	}
end)()

-- The smith hefts the hammer: raises it a little, turns it over in the wrist looking it over.
GESTURES.heft = {
	duration = 2.4,
	keys = {
		{ 0, nil, {} },
		{ 0.1, "inOutQuad", { rsh = { -3, 0, 0 }, rel = { -4, 0 } } },
		{ 0.5, "inOutCubic", { rsh = { 10, 6, 0 }, rel = { 42, 0 }, rwr = { 20, 0, 0 }, look = { -12, -18, 1 } } },
		{ 0.85, "inOutQuad", { rsh = { 10, 6, 0 }, rel = { 44, -30 }, rwr = { 22, 0, 0 }, look = { -12, -18, 1 } } },
		{ 1.25, "inOutQuad", { rsh = { 10, 6, 0 }, rel = { 44, 20 }, rwr = { 22, 0, 0 }, look = { -12, -18, 1 } } },
		{ 1.5, "inOutQuad", { rsh = { 10, 6, 0 }, rel = { 42, 0 }, rwr = { 20, 0, 0 }, look = { -6, -12, 0.6 } } },
		{ 1.95, "inOutCubic", { rsh = { -2, 0, 0 }, rel = { -4, 0 }, look = { 0, 0, 0 } } },
		{ 2.4, "inOutQuad", {} },
	},
}

-- The quest giver raises the scroll and reads it, the head nodding down the lines.
GESTURES.read = {
	duration = 2.8,
	keys = {
		{ 0, nil, {} },
		{ 0.1, "inOutQuad", { rsh = { -3, 0, 0 } } },
		{ 0.55, "inOutCubic", { rsh = { 22, 8, 0 }, rel = { 10, 0 }, rwr = { 20, 0, 0 }, waist = { -2, 3, 0 },
			look = { -6, -22, 1 } } },
		{ 1.1, "inOutQuad", { rsh = { 22, 8, 0 }, rel = { 10, 0 }, rwr = { 20, 0, 0 }, waist = { -2, 3, 0 },
			look = { -4, -28, 1 } } },
		{ 1.6, "inOutQuad", { rsh = { 22, 8, 0 }, rel = { 10, 0 }, rwr = { 20, 0, 0 }, waist = { -2, 3, 0 },
			look = { -8, -24, 1 } } },
		{ 2.0, "inOutQuad", { rsh = { 22, 8, 0 }, rel = { 10, 0 }, rwr = { 20, 0, 0 }, waist = { -2, 3, 0 },
			look = { -4, -30, 1 } } },
		{ 2.5, "inOutCubic", { rsh = { -2, 0, 0 }, look = { 0, 0, 0 } } },
		{ 2.8, "inOutQuad", {} },
	},
}

-- The quest giver shades his eyes with his free hand and scans the horizon, left to right.
GESTURES.scan = {
	duration = 3.2,
	keys = {
		{ 0, nil, {} },
		{ 0.5, "inOutCubic", { lsh = { 150, -30, -10 }, lel = { 60, 0 }, lwr = { 0, 0, 0 }, waist = { 3, 0, 0 },
			look = { 25, 6, 1 } } },
		{ 1.5, "inOutSine", { lsh = { 150, -30, -10 }, lel = { 60, 0 }, waist = { 3, 0, 0 }, look = { -25, 6, 1 } } },
		{ 2.2, "inOutSine", { lsh = { 150, -30, -10 }, lel = { 60, 0 }, waist = { 3, 0, 0 }, look = { -10, 6, 1 } } },
		{ 2.75, "inOutCubic", { look = { 0, 0, 0 } } },
		{ 3.2, "inOutQuad", {} },
	},
}

-- The vaultkeeper checks his keys: the free hand goes to the ring at his belt and jingles it.
GESTURES.keys = {
	duration = 2.3,
	keys = {
		{ 0, nil, {} },
		{ 0.4, "inOutCubic", { lsh = { 16, 0, 8 }, lel = { 40, 0 }, look = { 20, -30, 1 }, waist = { -3, 5, 0 } } },
		{ 0.55, "outQuad", { lsh = { 20, 0, 8 }, lel = { 44, 0 }, keys = { 26 }, look = { 20, -30, 1 }, waist = { -3, 5, 0 } } },
		{ 0.7, "inOutQuad", { lsh = { 16, 0, 8 }, lel = { 40, 0 }, keys = { -18 }, look = { 20, -30, 1 }, waist = { -3, 5, 0 } } },
		{ 0.85, "inOutQuad", { lsh = { 20, 0, 8 }, lel = { 44, 0 }, keys = { 22 }, look = { 20, -30, 1 }, waist = { -3, 5, 0 } } },
		{ 1.0, "inOutQuad", { lsh = { 16, 0, 8 }, lel = { 40, 0 }, keys = { -14 }, look = { 20, -30, 1 }, waist = { -3, 5, 0 } } },
		{ 1.3, "inOutQuad", { lsh = { 12, 0, 6 }, lel = { 30, 0 }, keys = { 8 }, look = { 10, -15, 0.6 } } },
		{ 1.8, "inOutCubic", { keys = { -4 }, look = { 0, 0, 0 } } },
		{ 2.3, "inOutQuad", {} },
	},
}

-- The vaultkeeper opens his ledger a little, checks an entry, and closes it.
GESTURES.ledger = {
	duration = 2.6,
	keys = {
		{ 0, nil, {} },
		{ 0.5, "inOutCubic", { rsh = { 12, 6, 0 }, rel = { 12, 0 }, rwr = { 24, 0, 0 },
			lsh = { 40, -20, 10 }, lel = { 50, 0 }, look = { -6, -26, 1 } } },
		{ 1.2, "inOutQuad", { rsh = { 12, 6, 0 }, rel = { 12, 0 }, rwr = { 24, 0, 0 },
			lsh = { 40, -20, 10 }, lel = { 50, 0 }, look = { -2, -30, 1 } } },
		{ 1.7, "inOutQuad", { rsh = { 12, 6, 0 }, rel = { 12, 0 }, rwr = { 24, 0, 0 },
			lsh = { 40, -20, 10 }, lel = { 50, 0 }, look = { -8, -26, 1 } } },
		{ 2.2, "inOutCubic", { look = { 0, 0, 0 } } },
		{ 2.6, "inOutQuad", {} },
	},
}

-- The sage bows his head for a long, slow breath, then lifts it.
GESTURES.bow = {
	duration = 3.2,
	keys = {
		{ 0, nil, {} },
		{ 0.8, "inOutSine", { waist = { -4, 0, 0 }, look = { 0, -22, 1 }, brow = { -0.02 } } },
		{ 2.2, "inOutSine", { waist = { -4.5, 0, 0 }, look = { 0, -24, 1 }, brow = { -0.02 } } },
		{ 3.2, "inOutSine", {} },
	},
}

-- The sage lifts the staff an inch and sets it down again, leaning on it.
GESTURES.staff = {
	duration = 2.4,
	keys = {
		{ 0, nil, {} },
		{ 0.35, "inOutCubic", { rsh = { 6, 0, 0 }, lift = { 0.1, 0 }, rel = { 6, 0 }, look = { -8, -10, 0.7 } } },
		{ 0.6, "inQuad", { rsh = { -1, 0, 0 }, rel = { -2, 0 }, hips = { 0.05, -0.03, 0, 0, 0, 2 }, look = { -8, -10, 0.7 } } },
		{ 0.75, "outQuad", { hips = { 0.05, -0.02, 0, 0, 0, 2 }, waist = { 0, 0, -2 } } },
		{ 1.8, "inOutQuad", { hips = { 0.04, -0.02, 0, 0, 0, 1.5 }, waist = { 0, 0, -2 } } },
		{ 2.4, "inOutQuad", {} },
	},
}

-- The trainer rolls his shoulders and neck, loosening up.
GESTURES.stretch = {
	duration = 2.4,
	keys = {
		{ 0, nil, {} },
		{ 0.4, "inOutQuad", { lift = { 0.12, 0.12 }, neck = { 0, 0, 14 }, waist = { 3, 0, 0 } } },
		{ 0.8, "inOutQuad", { lift = { 0.02, 0.02 }, neck = { 10, 0, 0 }, waist = { 4, 0, 0 } } },
		{ 1.2, "inOutQuad", { lift = { 0.1, 0.1 }, neck = { 0, 0, -14 }, waist = { 3, 0, 0 } } },
		{ 1.7, "inOutQuad", { neck = { -6, 0, 0 } } },
		{ 2.4, "inOutQuad", {} },
	},
}

-- The trainer brings the sword up and sights along the blade.
GESTURES.blade = {
	duration = 2.5,
	keys = {
		{ 0, nil, {} },
		{ 0.1, "inOutQuad", { rsh = { -4, 0, 0 } } },
		{ 0.55, "inOutCubic", { rsh = { 40, 20, 0 }, rel = { 50, 0 }, rwr = { 60, 0, 0 }, waist = { 0, 8, 0 },
			look = { -12, 2, 1 } } },
		{ 1.5, "inOutQuad", { rsh = { 42, 22, 0 }, rel = { 50, 0 }, rwr = { 64, 0, 0 }, waist = { 0, 8, 0 },
			look = { -14, 4, 1 } } },
		{ 2.0, "inOutCubic", { rsh = { -3, 0, 0 }, look = { 0, 0, 0 } } },
		{ 2.5, "inOutQuad", {} },
	},
}

-- ==============================================================================
-- Greetings (the react layer's acknowledgement, one per role, re-rolled per NPC and per greeting)
-- ==============================================================================
-- Each builder takes the role and a random source and returns a gesture like the ones above,
-- starting ~180 ms after the head has snapped round to the player. The arm targets are absolute
-- poses (toward() turns them into deltas from the role's stance), so every role reaches the same
-- readable silhouette from wherever its free hand rests.
local function toward(stance, abs)
	local out = {}
	for name, values in pairs(abs) do
		local base = stance[name]
		local d = table.create(#values, 0)
		for i, v in ipairs(values) do
			d[i] = v - (base and base[i] or 0)
		end
		out[name] = d
	end
	return out
end

local function merged(...)
	local out = {}
	for _, t in ipairs({ ... }) do
		for name, values in pairs(t) do
			out[name] = table.clone(values)
		end
	end
	return out
end

-- The free (left) hand comes up beside the head, palm open to the player, and waves from the
-- elbow. 80 ms anticipation (the hand drops and the shoulder dips), the raise in ~220 ms to a
-- small overshoot with the chin lifting, then `swings` sweeps of +-amp degrees about `swing` s
-- each (a nod on the first), and the arm eased down past the rest and settled.
local function waveGreeting(role, rnd, opts)
	opts = opts or {}
	local swing = (opts.swing or 0.16) * (0.94 + 0.12 * rnd())
	local amp = (opts.amp or 24) * (0.9 + 0.2 * rnd())
	local swings = opts.swings or (if rnd() < 0.3 then 5 else 4)
	-- upper arm raised ~120 degrees out to the side and swung a little forward, rolled about its
	-- length so the elbow bends upward and the palm faces front; forearm near vertical
	local up = toward(role.stance, {
		lsh = { 0, -(22 + 8 * rnd()), -(opts.raise or 122) - 5 * rnd(), 95 },
		lel = { 66 + 8 * rnd(), 0 },
		lwr = { 0, 0, 0 },
	})
	-- on the way up the elbow is already turned to bend upward, so the hand rises beside the
	-- body instead of punching out in front
	local mid = toward(role.stance, { lsh = { 0, -14, -70, 82 }, lel = { 88, 0 }, lwr = { 0, 0, 0 } })
	local body = merged({ waist = { 1.5, 0, -3 }, hips = { 0, 0.01, 0, 0, 0, 0 } }, opts.extra or {})
	local function hold(flexOffset: number, nod: number, roll: number?)
		local k = merged(body)
		k.lsh = { up.lsh[1], up.lsh[2], up.lsh[3] + (roll or 0), up.lsh[4] }
		k.lel = { up.lel[1] + flexOffset, up.lel[2] }
		k.lwr = { up.lwr[1], up.lwr[2], up.lwr[3] - 0.25 * flexOffset }
		k.neck = { nod, 0, 0 }
		k.brow = { 0.035 }
		return k
	end
	local keys = {
		{ 0, nil, {} },
		-- anticipation: the hand drops against the hip, the shoulder dips
		{ 0.08, "inOutQuad", { lsh = { 0, 0, 7, 0 }, lel = { 8, 0 }, lift = { 0, -0.05 }, neck = { -1, 0, 0 } } },
		-- up, a little past the pose, chin up
		{ 0.18, "inQuad", merged(body, mid, { neck = { 3, 0, 0 }, brow = { 0.02 } }) },
		{ 0.3, "outCubic", hold(-6, 6, -7) },
		{ 0.38, "inOutQuad", hold(0, 4, 0) },
	}
	local t, dir = 0.38, -1
	for i = 1, swings do
		t += if i == 1 then swing * 0.5 else swing
		local nod = if i == 2 then -6 elseif i == 3 then 1 else 2
		table.insert(keys, { t, "inOutSine", hold(dir * amp, nod, -dir * 4) })
		dir = -dir
	end
	-- down past the rest, then settled
	t += 0.28
	table.insert(keys, { t, "inOutCubic", merged(opts.extraDown or {}, { lsh = { 0, 0, 5, 0 }, lel = { -7, 0 }, neck = { -1, 0, 0 } }) })
	t += 0.14
	table.insert(keys, { t, "outQuad", { lsh = { 0, 0, -1, 0 }, lel = { 1.5, 0 } } })
	t += 0.24
	table.insert(keys, { t, "inOutQuad", {} })
	return { duration = t, keys = keys }
end

local GREETINGS = {}

-- The smith: a big open-handed wave with his free hand, the hammer fist lifting in salute with it.
GREETINGS.Blacksmith = function(role, rnd)
	return waveGreeting(role, rnd, {
		extra = { rsh = { 5, 0, 3, 0 }, rel = { 12, 0 }, rwr = { -6, 0, 0 } },
		extraDown = { rsh = { -2, 0, 0, 0 }, rel = { -3, 0 } },
	})
end

-- The quest giver: a broader, slower wave, calling the player over.
GREETINGS.QuestMaster = function(role, rnd)
	return waveGreeting(role, rnd, { swing = 0.2, amp = 28, swings = if rnd() < 0.5 then 3 else 5 })
end

-- The trainer: a quick raised hand, two brisk sweeps.
GREETINGS.Trainer = function(role, rnd)
	return waveGreeting(role, rnd, { swing = 0.14, amp = 18, swings = 2, raise = 124 })
end

-- The sage: the hand lifted slowly in blessing, one slow sweep, and a bow of the head.
GREETINGS.RebirthKeeper = function(role, rnd)
	local g = waveGreeting(role, rnd, { swing = 0.3, amp = 14, swings = 2, raise = 105 })
	for _, key in ipairs(g.keys) do
		local neck = key[3].neck
		if neck and neck[1] < 0 then
			neck[1] = -12 -- the nod becomes a bow
		end
	end
	return g
end

-- The vaultkeeper: a nod with a touch to the cap. The free hand comes up to the brim as the head
-- dips, holds a beat, tips it, and goes back down.
GREETINGS.Vaultkeeper = function(role, rnd)
	local depth = 10 + 4 * rnd()
	local brim = toward(role.stance, { lsh = { 112, -38, -8, 0 }, lel = { 118, 0 }, lwr = { -20, 0, 0 } })
	local function at(nod: number, tip: number)
		local k = merged(brim)
		k.lsh[1] += tip
		k.neck = { nod, 0, 0 }
		k.waist = { -1.5, 0, 0 }
		k.brow = { 0.03 }
		return k
	end
	return {
		duration = 1.55,
		keys = {
			{ 0, nil, {} },
			{ 0.08, "inOutQuad", { lsh = { -4, 0, 2, 0 }, lel = { 6, 0 }, lift = { 0, -0.04 } } },
			{ 0.36, "outCubic", at(3, 4) },
			{ 0.44, "inOutQuad", at(1, 0) },
			{ 0.62, "inOutQuad", at(-depth, 8) },
			{ 0.82, "inOutQuad", at(2, 0) },
			{ 0.92, "inOutQuad", at(0, 0) },
			{ 1.2, "inOutCubic", { lsh = { -3, 0, 2, 0 }, lel = { -5, 0 }, neck = { -1, 0, 0 } } },
			{ 1.34, "outQuad", { lsh = { 1, 0, 0, 0 }, lel = { 1, 0 } } },
			{ 1.55, "inOutQuad", {} },
		},
	}
end

for name, role in pairs(ROLES) do
	role.greet = GREETINGS[name] or GREETINGS.Vaultkeeper
end

local DEFAULT_ROLE = ROLES.Vaultkeeper

-- Adds gesture `g` sampled at local time t into `pose`.
local function addGesture(pose, g, t: number)
	local keys = g.keys
	if t <= 0 or t >= g.duration then
		return
	end
	local i = 2
	while i < #keys and keys[i][1] < t do
		i += 1
	end
	local a, b = keys[i - 1], keys[i]
	local u = clamp((t - a[1]) / (b[1] - a[1]), 0, 1)
	u = EASE[b[2] or "linear"](u)
	local pa, pb = a[3], b[3]
	for _, name in ipairs(CHANNEL_NAMES) do
		local va, vb = pa[name], pb[name]
		if va or vb then
			local dst = pose[name]
			if name == "look" then
				-- gaze is blended, not added: carry yaw/pitch at full value and blend by weight
				local wa, wb = va and va[3] or 0, vb and vb[3] or 0
				local w = wa + (wb - wa) * u
				local ya, yb = va and va[1] or (vb and vb[1] or 0), vb and vb[1] or (va and va[1] or 0)
				local qa, qb = va and va[2] or (vb and vb[2] or 0), vb and vb[2] or (va and va[2] or 0)
				dst[1], dst[2], dst[3] = ya + (yb - ya) * u, qa + (qb - qa) * u, w
			else
				for k = 1, #dst do
					local x, y = va and va[k] or 0, vb and vb[k] or 0
					dst[k] += x + (y - x) * u
				end
			end
		end
	end
end

-- ==============================================================================
-- Rig
-- ==============================================================================
local JOINTS = {
	"Root", "Waist", "Neck",
	"LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow", "RightWrist",
	"LeftHip", "LeftKnee", "LeftAnkle", "RightHip", "RightKnee", "RightAnkle",
}

local function buildRig(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local motors = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	local rest = { [root] = CFrame.identity }
	local joints = {}
	for _, name in ipairs(JOINTS) do
		local m = motors[name]
		if not (m and m.Part0 and m.Part1 and rest[m.Part0]) then
			return nil
		end
		rest[m.Part1] = rest[m.Part0] * m.C0 * m.C1:Inverse()
		local r0 = m.C0.Rotation
		joints[name] = { motor = m, c0 = m.C0, c1 = m.C1, r0 = r0, r0inv = r0:Inverse(), identity = r0 == CFrame.identity }
	end
	local function leg(side: string)
		local hip, knee, ankle = joints[side .. "Hip"], joints[side .. "Knee"], joints[side .. "Ankle"]
		local lower = knee.motor.Part1
		local foot = ankle.motor.Part1
		return {
			hip = hip, knee = knee, ankle = ankle,
			l1 = (knee.c0.Position - hip.c1.Position).Magnitude,
			l2 = (ankle.c0.Position - knee.c1.Position).Magnitude,
			ankleRest = (rest[lower] * ankle.c0).Position,
			footRot = rest[foot].Rotation,
		}
	end
	-- Face parts (eyes lead the head, blinks, brows) and the vaultkeeper's key ring, all welded:
	-- moved by their weld's C0 locally, never replicated.
	local face = {}
	for _, name in ipairs({ "eye_left", "eye_right", "eye_glint_left", "eye_glint_right", "brow_left", "brow_right" }) do
		local part = model:FindFirstChild(name, true)
		local weld = part and part:FindFirstChildWhichIsA("JointInstance")
		if weld and weld:IsA("Weld") then
			face[name] = { part = part, weld = weld, c0 = weld.C0, size = part.Size, transparency = part.Transparency }
		end
	end
	local keyParts = {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and (string.match(part.Name, "^key_")) then
			local weld = part:FindFirstChildWhichIsA("JointInstance")
			if weld and weld:IsA("Weld") then
				table.insert(keyParts, { weld = weld, c0 = weld.C0 })
			end
		end
	end
	local keyPivot
	if #keyParts > 0 then
		local top = -math.huge
		local sum = Vector3.zero
		for _, k in ipairs(keyParts) do
			sum += k.c0.Position
			top = math.max(top, k.c0.Position.Y)
		end
		local mid = sum / #keyParts
		keyPivot = Vector3.new(mid.X, top, mid.Z)
	end
	return {
		root = root,
		joints = joints,
		legs = { leg("Left"), leg("Right") },
		face = face,
		keyParts = keyParts,
		keyPivot = keyPivot,
	}
end

local function setTransform(joint, cf: CFrame)
	if joint.identity then
		joint.motor.Transform = cf
	else
		joint.motor.Transform = joint.r0inv * cf * joint.r0
	end
end

local function resetRig(rig)
	for _, joint in pairs(rig.joints) do
		joint.motor.Transform = CFrame.identity
	end
	for _, f in pairs(rig.face) do
		f.weld.C0 = f.c0
		f.part.Size = f.size
		f.part.Transparency = f.transparency
	end
	for _, k in ipairs(rig.keyParts) do
		k.weld.C0 = k.c0
	end
end

-- Two-bone leg: hip (in root space, from the posed LowerTorso) reaches the planted ankle target;
-- the knee bends forward to take up the slack and the foot keeps its rest orientation.
local function solveLeg(leg, lowerTorso: CFrame, ankleTarget: Vector3, footRot: CFrame)
	local hip, knee, ankle = leg.hip, leg.knee, leg.ankle
	local hipFrame = lowerTorso * hip.c0
	local h = hipFrame.Position
	local d = ankleTarget - h
	local l1, l2 = leg.l1, leg.l2
	local dist = clamp(d.Magnitude, math.abs(l1 - l2) + 1e-3, l1 + l2 - 1e-4)
	local cosInner = clamp((l1 * l1 + l2 * l2 - dist * dist) / (2 * l1 * l2), -1, 1)
	local flex = math.pi - math.acos(cosInner)
	local kneeT = CFrame.Angles(-flex, 0, 0)
	-- where the ankle lands with the hip at rest and the knee bent
	local upper0 = hipFrame * hip.c1:Inverse()
	local lower0 = upper0 * knee.c0 * kneeT * knee.c1:Inverse()
	local a0 = (lower0 * ankle.c0).Position
	local v0 = a0 - h
	local hipR = CFrame.identity
	if v0.Magnitude > 1e-4 and d.Magnitude > 1e-4 then
		local axis = v0:Cross(d)
		if axis.Magnitude > 1e-6 then
			local angle = math.acos(clamp(v0.Unit:Dot(d.Unit), -1, 1))
			hipR = CFrame.fromAxisAngle(axis.Unit, angle)
		end
	end
	local hr = hipFrame.Rotation
	local hipT = hr:Inverse() * hipR * hr
	hip.motor.Transform = hipT
	knee.motor.Transform = kneeT
	local upper = hipFrame * hipT * hip.c1:Inverse()
	local lower = upper * knee.c0 * kneeT * knee.c1:Inverse()
	local ankleFrame = lower * ankle.c0
	ankle.motor.Transform = ankleFrame.Rotation:Inverse() * footRot * ankle.c1.Rotation
end

local function applyPose(rig, pose, blink: number)
	local j = rig.joints
	local h = pose.hips
	local turn = pose.turn
	-- The react layer's body turn spins everything about the root's vertical axis (the Root joint
	-- sits on it), so the stance, sway and shifts all carry round with the body.
	local rootT = CFrame.Angles(0, rad(turn[1]), 0) * CFrame.new(h[1], h[2], h[3]) * euler(h[4], h[5], h[6])
	setTransform(j.Root, rootT)
	local w = pose.waist
	setTransform(j.Waist, euler(w[1], w[2], w[3]))
	local n = pose.neck
	setTransform(j.Neck, euler(n[1], n[2], n[3]))
	local lift = pose.lift
	local r, l = pose.rsh, pose.lsh
	setTransform(j.RightShoulder, CFrame.new(0, lift[1], 0) * euler(r[1], r[2], r[3]) * CFrame.Angles(0, rad(r[4]), 0))
	setTransform(j.LeftShoulder, CFrame.new(0, lift[2], 0) * euler(l[1], l[2], l[3]) * CFrame.Angles(0, rad(l[4]), 0))
	local re, le = pose.rel, pose.lel
	setTransform(j.RightElbow, CFrame.Angles(rad(re[1]), 0, 0) * CFrame.Angles(0, rad(re[2]), 0))
	-- the left forearm twists the other way for the same number, so stances read symmetrically
	setTransform(j.LeftElbow, CFrame.Angles(rad(le[1]), 0, 0) * CFrame.Angles(0, rad(-le[2]), 0))
	local rw, lw = pose.rwr, pose.lwr
	setTransform(j.RightWrist, euler(rw[1], rw[2], rw[3]))
	setTransform(j.LeftWrist, euler(lw[1], -lw[2], -lw[3]))

	-- Legs: feet planted at their rest spots (plus the stance's offsets), each turned about the
	-- root's vertical axis by its own step (and lifted while it steps).
	local root = j.Root
	local lowerTorso = root.c0 * (if root.identity then rootT else root.r0inv * rootT * root.r0) * root.c1:Inverse()
	local lf, rf = pose.lfoot, pose.rfoot
	local left, right = rig.legs[1], rig.legs[2]
	local lTurn, rTurn = CFrame.Angles(0, rad(turn[2]), 0), CFrame.Angles(0, rad(turn[3]), 0)
	solveLeg(left, lowerTorso, lTurn * (left.ankleRest + Vector3.new(lf[1], 0, lf[2])) + Vector3.new(0, turn[4], 0),
		lTurn * left.footRot)
	solveLeg(right, lowerTorso, rTurn * (right.ankleRest + Vector3.new(rf[1], 0, rf[2])) + Vector3.new(0, turn[5], 0),
		rTurn * right.footRot)

	-- Face: the eyes lead the head, blinks squash them, brows ride up and down.
	local eyes, brow = pose.eyes, pose.brow[1]
	local eyeOffset = CFrame.new(eyes[1], eyes[2], 0)
	local squash = 1 - 0.85 * blink
	for name, f in pairs(rig.face) do
		if string.sub(name, 1, 4) == "brow" then
			f.weld.C0 = CFrame.new(0, brow - 0.03 * blink, 0) * f.c0
		elseif string.sub(name, 1, 9) == "eye_glint" then
			f.weld.C0 = eyeOffset * f.c0
			f.part.Transparency = if blink > 0.4 then 1 else f.transparency
		else
			f.weld.C0 = eyeOffset * f.c0
			f.part.Size = Vector3.new(f.size.X, f.size.Y * squash, f.size.Z)
		end
	end
	-- Key ring: swings about its clip on the belt.
	if rig.keyPivot then
		local swing = pose.keys[1]
		local pivot = rig.keyPivot
		local turn = CFrame.new(pivot) * CFrame.Angles(0, 0, rad(swing)) * CFrame.Angles(rad(swing * 0.4), 0, 0)
			* CFrame.new(-pivot)
		for _, k in ipairs(rig.keyParts) do
			k.weld.C0 = turn * k.c0
		end
	end
end

-- ==============================================================================
-- Idle state and layers
-- ==============================================================================
-- -1 fully out, +1 fully in; a quicker inhale (45% of the cycle) than exhale.
local BREATH_IN = 0.45
local function breathAt(x: number): number
	x = x % 1
	if x < BREATH_IN then
		return -math.cos(math.pi * x / BREATH_IN)
	end
	return math.cos(math.pi * (x - BREATH_IN) / (1 - BREATH_IN))
end

local function swayAt(t: number): number
	return 0.6 * math.sin(t * math.pi * 2 / 5.3) + 0.4 * math.sin(t * math.pi * 2 / 8.1 + 1.7)
end

-- Weight shift share over its own clock: eased across, a touch past the leg, settled onto it.
local SHIFT_CURVE = { { 0, 0 }, { 0.8, 1.05, "inOutCubic" }, { 1, 1, "inOutQuad" } }
-- Glance share: a tiny counter-move, the turn with a small overshoot, the hold, the return.
local GLANCE_TURN = 0.38
local GLANCE_OUT = { { 0, 0 }, { 0.06, -0.03, "inOutQuad" }, { 0.32, 1.05, "outCubic" }, { 0.42, 1, "inOutQuad" } }
local GLANCE_BACK = { { 0, 1 }, { 0.42, -0.04, "inOutCubic" }, { 0.56, 0, "inOutQuad" } }
local GLANCE_BACK_TIME = 0.56
local EYE_LEAD = 0.1 -- seconds the eyes run ahead of the head
local TORSO_LAG = 0.12 -- seconds the torso trails the head into a glance (and the head the torso in a shift)
local BLINK_TIME = 0.14
local FADE_IN = 0.6 -- seconds for the idle to take the joints over

local function newState(model: Model, rig, roleName: string?, now: number)
	local role = ROLES[roleName or ""] or DEFAULT_ROLE
	local side = if math.random() < 0.5 then -1 else 1
	local stance = zeroPose()
	for name, values in pairs(role.stance) do
		for i, v in ipairs(values) do
			stance[name][i] = v
		end
	end
	return {
		model = model,
		rig = rig,
		role = role,
		stance = stance,
		pose = zeroPose(),
		breathPeriod = between(role.breathPeriod),
		breathPhase = math.random(),
		swayPhase = math.random() * 50,
		shiftFrom = side, shiftTo = side, shiftT0 = -math.huge, shiftDur = role.shiftTime,
		nextShift = now + between(role.shiftGap) * 0.6,
		nextGlance = now + between(role.glanceGap) * 0.5,
		nextGesture = now + between(role.gestureGap) * 0.7,
		nextBlink = now + between({ 1, 4 }),
		blinkT0 = -math.huge,
		blinkTwice = false,
		lookYaw = 0, lookPitch = 0, -- the head's gaze (degrees, relative to the turned body)
		weight = 0,
		active = false,
		-- react layer: every angle is relative to the NPC's post facing (its root)
		engaged = false,
		engT0 = -math.huge,
		fromShare = { 0, 0, 0 }, -- head, chest, body shares when engaged last changed
		gazeYaw = 0, gazePitch = 0, chestAim = 0, bodyAim = 0,
		footYaw = { 0, 0 },
		steps = {}, -- [foot] = { t0, from, to } while that foot steps round
		greetReady = now, -- no greeting before this (the cooldown)
		greetAt = nil,
		greet = role.greet(role, math.random),
	}
end

local function shiftAt(s, t: number): number
	local u = curve(SHIFT_CURVE, (t - s.shiftT0) / s.shiftDur)
	return s.shiftFrom + (s.shiftTo - s.shiftFrom) * u
end

local function startShift(s, now: number, to: number, duration: number)
	s.shiftFrom, s.shiftTo, s.shiftT0, s.shiftDur = shiftAt(s, now), to, now, duration
end

-- 0..1 (with small overshoots) share of the current glance at time t.
local function glanceAt(s, t: number): number
	if not s.glanceT0 then
		return 0
	end
	local x = t - s.glanceT0
	if x <= 0 then
		return 0
	end
	local back = GLANCE_TURN + s.glanceHold
	if x < back then
		return curve(GLANCE_OUT, x)
	end
	return curve(GLANCE_BACK, x - back)
end

local function gestureDef(s)
	if not s.gestureT0 then
		return nil
	end
	return if s.gestureKind == "greet" then s.greet else GESTURES[s.gestureKind]
end

-- The weight shift's net turn of the chest (the hips turn 2 degrees onto the leg, the chest
-- counter-turns 3), at time t; the head carries it TORSO_LAG late.
local function shiftTurnAt(s, t: number): number
	return -shiftAt(s, t)
end

-- React layer ------------------------------------------------------------------
-- Shares (0..1, small overshoots) of the head, chest and body turns toward the player, over time
-- since the NPC noticed them (IN) or let them go (OUT). The eyes lead the head by EYE_LEAD, the
-- chest trails it by ~120 ms and the body (the whole figure on its feet) by ~200 ms.
local HEAD_IN = { { 0, 0 }, { 0.16, 1.12, "outCubic" }, { 0.3, 1, "inOutQuad" } }
local CHEST_IN = { { 0, 0 }, { 0.12, 0 }, { 0.46, 1.05, "inOutCubic" }, { 0.6, 1, "inOutQuad" } }
local BODY_IN = { { 0, 0 }, { 0.2, 0 }, { 0.72, 1.03, "inOutCubic" }, { 0.85, 1, "inOutQuad" } }
local HEAD_OUT = { { 0, 1 }, { 0.4, 0, "inOutCubic" } }
local CHEST_OUT = { { 0, 1 }, { 0.12, 1 }, { 0.62, 0, "inOutCubic" } }
local BODY_OUT = { { 0, 1 }, { 0.25, 1 }, { 1.0, 0, "inOutCubic" } }
local SHARE_CURVES = { { HEAD_IN, HEAD_OUT }, { CHEST_IN, CHEST_OUT }, { BODY_IN, BODY_OUT } }
local BODY_SHARE, CHEST_SHARE = 0.72, 0.9 -- of the player's bearing the body and chest turn through
local BODY_MAX, CHEST_MAX, GAZE_MAX = 55, 80, 105
local STEP_TIME, STEP_LIFT, STEP_GAP = 0.24, 0.22, 7

local function shareAt(s, which: number, t: number): number
	local from = s.fromShare[which]
	local x = t - s.engT0
	if s.engaged then
		return from + (1 - from) * curve(SHARE_CURVES[which][1], x)
	end
	return from * curve(SHARE_CURVES[which][2], x)
end

local function setEngaged(s, engaged: boolean, now: number)
	for i = 1, 3 do
		s.fromShare[i] = clamp(shareAt(s, i, now), 0, 1)
	end
	s.engaged, s.engT0 = engaged, now
end

-- Where the local player is, relative to the NPC's post facing: bearing (degrees, + to its left),
-- pitch to their head, and flat distance. `s.fakeBearing` stands in for a player in previews.
local function sensePlayer(s, root: BasePart): (number?, number, number)
	if s.fakeBearing then
		return s.fakeBearing, 0, 10
	end
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local body = character and character:FindFirstChild("HumanoidRootPart")
	if not (body and body:IsA("BasePart")) then
		return nil, 0, math.huge
	end
	local head = character:FindFirstChild("Head")
	local rel = root.CFrame:PointToObjectSpace(body.Position)
	local flat = Vector3.new(rel.X, 0, rel.Z).Magnitude
	local bearing = math.deg(math.atan2(-rel.X, -rel.Z))
	local headY = if head and head:IsA("BasePart") then root.CFrame:PointToObjectSpace(head.Position).Y else rel.Y + 1.5
	local pitch = clamp(math.deg(math.atan2(headY - 1.6, math.max(flat, 1))), -15, 10)
	return bearing, pitch, flat
end

-- Notice / let go of the player, keep the loose tracking, schedule the greeting.
local function react(s, root: BasePart, now: number, dt: number)
	local bearing, pitch, flat = sensePlayer(s, root)
	if not s.engaged then
		if bearing and flat < NOTICE_RANGE and math.abs(bearing) < NOTICE_ARC then
			setEngaged(s, true, now)
			local b = clamp(bearing, -GAZE_MAX, GAZE_MAX)
			s.gazeYaw, s.gazePitch, s.chestAim, s.bodyAim = b, pitch, b, b
			-- a glance in progress lets go quickly instead of fighting the turn
			if s.glanceT0 then
				s.glanceKill = now
			end
			s.nextGlance = math.max(s.nextGlance, now + 3.5)
			-- the weight goes onto the leg on the player's side as the body comes round
			if math.abs(b) > 12 then
				startShift(s, now + 0.1, if b > 0 then 0.8 else -0.8, 0.5)
				s.nextShift = math.max(s.nextShift, now + 2.5)
			end
			if now >= s.greetReady then
				local at = now + 0.16 + 0.08 * math.random()
				local g = gestureDef(s)
				if g then -- let a job gesture in progress finish first
					at = math.max(at, s.gestureT0 + g.duration + 0.05)
				end
				s.greetAt = at
			end
		end
	elseif not bearing or flat > LEAVE_RANGE or math.abs(bearing) > NOTICE_ARC + 10 then
		setEngaged(s, false, now)
		s.greetAt = nil
	end
	if s.engaged and bearing then
		local b = clamp(bearing, -GAZE_MAX, GAZE_MAX)
		s.gazeYaw += (b - s.gazeYaw) * (1 - math.exp(-dt / 0.25))
		s.gazePitch += (pitch - s.gazePitch) * (1 - math.exp(-dt / 0.3))
		s.chestAim += (b - s.chestAim) * (1 - math.exp(-dt / 0.55))
		s.bodyAim += (b - s.bodyAim) * (1 - math.exp(-dt / 1.1))
	end
end

-- The feet step round after the body: when a foot lags the body's turn by more than STEP_GAP, it
-- lifts and swings to where the body is heading (the foot on the turning side first); only one
-- foot is off the ground at a time.
local function stepFeet(s, now: number, bodyYaw: number, destination: number)
	local lifts = { 0, 0 }
	local busy = false
	for foot = 1, 2 do
		local st = s.steps[foot]
		if st then
			local u = (now - st.t0) / STEP_TIME
			if u >= 1 then
				s.footYaw[foot] = st.to
				s.steps[foot] = nil
			else
				busy = true
				s.footYaw[foot] = st.from + (st.to - st.from) * EASE.inOutQuad(u)
				lifts[foot] = STEP_LIFT * math.sin(math.pi * u)
			end
		end
	end
	if not busy then
		local gl, gr = bodyYaw - s.footYaw[1], bodyYaw - s.footYaw[2]
		local foot = if math.abs(gl) > math.abs(gr) + 0.5 then 1
			elseif math.abs(gr) > math.abs(gl) + 0.5 then 2
			elseif gl > 0 then 1 else 2
		local gap = if foot == 1 then gl else gr
		if math.abs(gap) > STEP_GAP then
			s.steps[foot] = { t0 = now, from = s.footYaw[foot], to = destination }
		end
	end
	return lifts
end

-- Studio showcase: land a weight shift, a blink, a glance and the role's cued gesture at `at`
-- (local clock), with the hips eased onto the other leg first and the breath starting its inhale.
local function cue(s, at: number, now: number)
	local role = s.role
	startShift(s, now, -0.8, clamp(at - now - 0.4, 0.3, 1.2))
	s.pendingShift = at
	s.breathPhase = (-(at + 0.15) / s.breathPeriod) % 1
	s.glanceT0 = nil
	s.gestureT0 = nil
	s.cueGestureAt = at
	s.cueGlanceAt = at + 1.0
	s.nextBlink = at + 1.1
	s.blinkTwice = false
	s.nextGlance = at + 6
	s.nextGesture = at + 8
	s.nextShift = at + 4
	s.cueGesture = role.cueGesture
end

local function step(s, now: number, dt: number)
	local role = s.role
	local root = s.rig.root

	-- Schedule ----------------------------------------------------------------
	if s.pendingShift and now >= s.pendingShift then
		s.pendingShift = nil
		startShift(s, now, 1, role.shiftTime * 0.9)
	end
	if now >= s.nextShift and not s.pendingShift then
		local current = shiftAt(s, now)
		local to
		if math.abs(current) < 0.4 then
			to = if math.random() < 0.5 then -1 else 1
		else
			to = if math.random() < 0.2 then 0 else -math.sign(current) * (0.7 + 0.3 * math.random())
		end
		startShift(s, now, to, role.shiftTime * (0.85 + 0.3 * math.random()))
		s.nextShift = now + role.shiftTime + between(role.shiftGap)
	end
	local gesture = gestureDef(s)
	if gesture and now - s.gestureT0 > gesture.duration then
		if s.gestureKind == "greet" then
			s.greet = role.greet(role, math.random)
		end
		s.gestureT0, gesture = nil, nil
	end
	if s.glanceT0 and now - s.glanceT0 > GLANCE_TURN + s.glanceHold + GLANCE_BACK_TIME + TORSO_LAG then
		s.glanceT0 = nil
	end
	if s.glanceKill and (not s.glanceT0 or now - s.glanceKill > 0.3) then
		s.glanceT0, s.glanceKill = nil, nil
	end
	react(s, root, now, dt)
	if s.greetAt and now >= s.greetAt and not gesture then
		-- the greeting: this NPC's own roll of its role's greeting, re-rolled for next time
		s.greetAt = nil
		s.gestureKind = "greet"
		s.gestureT0 = now
		gesture = s.greet
		s.greetReady = now + between(GREET_COOLDOWN)
		s.nextGesture = math.max(s.nextGesture, now + gesture.duration + between(role.gestureGap) * 0.6)
		s.nextGlance = math.max(s.nextGlance, now + gesture.duration + 1.2)
	end
	if s.cueGlanceAt and now >= s.cueGlanceAt then
		s.cueGlanceAt = nil
		s.glanceT0 = now
		s.glanceYaw = role.cueGlance - s.lookYaw -- from the player out across the square
		s.glancePitch = 2
		s.glanceHold = 0.8
	elseif not s.glanceT0 and not gesture and now >= s.nextGlance and not s.cueGlanceAt and not s.greetAt then
		s.glanceT0 = now
		local yaw = between(role.glanceYaw) * (if math.random() < 0.5 then -1 else 1)
		-- stay inside a comfortable neck range from wherever the idle gaze is
		if math.abs(s.lookYaw + yaw) > 55 then
			yaw = -yaw
		end
		s.glanceYaw = yaw
		s.glancePitch = -3 + 8 * math.random()
		s.glanceHold = between({ 0.8, 1.5 })
		s.nextGlance = now + GLANCE_TURN + s.glanceHold + GLANCE_BACK_TIME + between(role.glanceGap)
	end
	if s.cueGestureAt and now >= s.cueGestureAt then
		s.cueGestureAt = nil
		s.gestureKind = s.cueGesture
		s.gestureT0 = now
		gesture = GESTURES[s.gestureKind]
	elseif not gesture and not s.glanceT0 and now >= s.nextGesture and not s.cueGestureAt and not s.greetAt then
		local list = role.gestures
		local kind = list[math.random(1, #list)]
		if kind == s.gestureKind and #list > 1 and math.random() < 0.6 then
			kind = list[(table.find(list, kind) :: number) % #list + 1]
		end
		s.gestureKind = kind
		s.gestureT0 = now
		gesture = GESTURES[kind]
		s.nextGesture = now + gesture.duration + between(role.gestureGap)
		s.nextGlance = math.max(s.nextGlance, now + gesture.duration + 0.6)
	end
	if now >= s.nextBlink then
		s.blinkT0 = now
		local twice = not s.blinkTwice and math.random() < 0.2
		s.blinkTwice = twice
		s.nextBlink = now + (if twice then 0.28 else between({ 2.2, 5 }))
	end

	-- Compose -----------------------------------------------------------------
	local pose = s.pose
	copyInto(pose, s.stance)
	pose.look[1], pose.look[2], pose.look[3] = 0, 0, 0
	local stanceYaw = pose.hips[5] + pose.waist[2]

	-- Breath: the chest leads, the shoulders rise after it, the arms trail.
	local bx = now / s.breathPeriod + s.breathPhase
	local lagUnit = 1 / s.breathPeriod
	local b = breathAt(bx)
	local bShoulder = breathAt(bx - 0.1 * lagUnit)
	local bArm = breathAt(bx - 0.15 * lagUnit)
	local pitch = role.breathPitch
	pose.waist[1] += pitch * b
	pose.hips[2] += 0.012 * b
	pose.neck[1] -= 0.6 * pitch * b
	pose.lift[1] += 0.025 * (bShoulder + 1)
	pose.lift[2] += 0.025 * (bShoulder + 1)
	pose.rsh[1] -= 0.8 * bArm
	pose.lsh[1] -= 0.8 * bArm
	pose.rsh[3] += 1.3 * bArm
	pose.lsh[3] -= 1.3 * bArm
	pose.rel[1] += 1.5 * bArm
	pose.lel[1] += 1.5 * bArm

	-- Sway and weight shift: the hips carry over one leg, the free hip drops, the shoulders
	-- counter-tilt and the chest counter-turns; the arms swing back to hanging true a beat late.
	local sw = swayAt(now + s.swayPhase)
	local w = shiftAt(s, now)
	local wArms = shiftAt(s, now - 0.1)
	local hipX = -0.15 * w + 0.03 * sw
	pose.hips[1] += hipX
	pose.hips[2] -= 0.012 * math.abs(w)
	pose.hips[6] += 20 * hipX
	pose.hips[5] += 2 * w
	pose.waist[2] -= 3 * w
	pose.waist[3] += 4 * w
	local hang = -0.6 * (20 * (-0.15 * wArms) + 4 * wArms)
	pose.rsh[3] += hang
	pose.lsh[3] += hang

	-- Gesture.
	if gesture then
		addGesture(pose, gesture, now - s.gestureT0)
	end

	-- React: the body turns on its feet, the chest further, the head all the way to the player.
	local bodyShare = shareAt(s, 3, now)
	local destination = if s.engaged then clamp(BODY_SHARE * s.bodyAim, -BODY_MAX, BODY_MAX) else 0
	local bodyYaw = clamp(BODY_SHARE * s.bodyAim, -BODY_MAX, BODY_MAX) * bodyShare
	local chestYaw = clamp(CHEST_SHARE * s.chestAim, -CHEST_MAX, CHEST_MAX) * shareAt(s, 2, now)
	local headShare = shareAt(s, 1, now)
	local headWorld = s.gazeYaw * headShare
	local headLead = s.gazeYaw * shareAt(s, 1, now + EYE_LEAD)
	s.lookYaw = headWorld - bodyYaw
	s.lookPitch = s.gazePitch * headShare
	local lifts = stepFeet(s, now, bodyYaw, destination)
	local turn = pose.turn
	turn[1], turn[2], turn[3], turn[4], turn[5] = bodyYaw, s.footYaw[1], s.footYaw[2], lifts[1], lifts[2]
	-- the brows lift as it notices
	if s.engaged then
		pose.brow[1] += 0.035 * curve({ { 0, 0 }, { 0.12, 1, "outQuad" }, { 0.7, 1 }, { 1.1, 0, "inOutQuad" } }, now - s.engT0)
	end

	-- Look: the idle gaze (player or ahead), a glance on top, a gesture's own gaze blended over.
	local g = glanceAt(s, now)
	local gLead = glanceAt(s, now + EYE_LEAD)
	if s.glanceKill then
		local fade = 1 - clamp((now - s.glanceKill) / 0.25, 0, 1)
		g *= fade
		gLead *= fade
	end
	local gYaw = s.glanceYaw or 0
	local headYaw = s.lookYaw + gYaw * g
	local headPitch = s.lookPitch + (s.glancePitch or 0) * g
	local leadYaw = s.lookYaw + gYaw * gLead + (headLead - headWorld)
	local gazeWeight = pose.look[3]
	if gazeWeight > 0 then
		headYaw += (pose.look[1] - headYaw) * gazeWeight
		headPitch += (pose.look[2] - headPitch) * gazeWeight
		leadYaw += (pose.look[1] - leadYaw) * gazeWeight
	end
	-- The torso follows the glance ~20% of the way, TORSO_LAG late; with the player near, the
	-- chest is turned further toward them than the body (the react layer's chest turn).
	local follow = 0.2 * gYaw * glanceAt(s, now - TORSO_LAG) * (if s.glanceKill then 0 else 1) + (chestYaw - bodyYaw)
	pose.waist[2] += follow
	-- The head keeps its gaze through the chest's turns, except the weight shift's, which it
	-- follows TORSO_LAG late.
	local torsoTurn = pose.hips[5] + pose.waist[2] - stanceYaw
	pose.neck[2] += headYaw + shiftTurnAt(s, now - TORSO_LAG) - torsoTurn
	pose.neck[1] += headPitch
	pose.neck[3] -= 0.8 * (pose.hips[6] + pose.waist[3])
	-- Eyes run ahead of the head toward where it is going.
	pose.eyes[1] = clamp(-0.0026 * (leadYaw - headYaw), -0.07, 0.07)
	pose.brow[1] += 0.03 * clamp(math.abs(gLead - g) * 3, 0, 1)

	-- Blink.
	local bt = now - s.blinkT0
	local blink = 0
	if bt >= 0 and bt < BLINK_TIME then
		blink = math.sin(math.pi * bt / BLINK_TIME)
	end

	-- Fade in after a pause (first sight, back from a HubAmbience walk) instead of snapping.
	s.weight = math.min(1, s.weight + dt / FADE_IN)
	if s.weight < 1 then
		local k = EASE.inOutQuad(s.weight)
		for _, values in pairs(pose) do
			for i = 1, #values do
				values[i] *= k
			end
		end
		blink *= k
	end

	applyPose(s.rig, pose, blink)
end

-- ==============================================================================
-- Tracking and the loop
-- ==============================================================================
local states: { [Model]: any } = {}
local connections: { [Model]: { RBXScriptConnection } } = {}
-- Tagged NPCs whose rig has not fully streamed in yet (or streamed out and back): retried.
local pending: { [Model]: boolean } = {}
local RETRY_EVERY = 0.5
local nextRetry = 0

-- A rig is usable while every joint and part it poses is still in the model.
local function rigIntact(rig, model: Model): boolean
	if not rig.root:IsDescendantOf(model) then
		return false
	end
	for _, joint in pairs(rig.joints) do
		local m = joint.motor
		if not (m.Parent and m.Part0 and m.Part1 and m.Part1:IsDescendantOf(model)) then
			return false
		end
	end
	return true
end

local function untrack(model: Model)
	pending[model] = nil
	local s = states[model]
	states[model] = nil
	if s and s.active then
		pcall(resetRig, s.rig)
	end
	local list = connections[model]
	connections[model] = nil
	if list then
		for _, c in ipairs(list) do
			c:Disconnect()
		end
	end
end

local function track(model: Instance)
	if not model:IsA("Model") or states[model] then
		return
	end
	local rig = buildRig(model)
	if not rig then
		pending[model] = true -- streaming in: try again shortly
		return
	end
	pending[model] = nil
	local s = newState(model, rig, model:GetAttribute(ROLE_ATTRIBUTE), os.clock())
	states[model] = s
	if RunService:IsStudio() then
		print(string.format("[NpcAnimator] %s stands as %s", model.Name, tostring(model:GetAttribute(ROLE_ATTRIBUTE))))
	end
	local list = {}
	connections[model] = list
	table.insert(list, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			untrack(model)
		end
	end))
	local function onCue()
		local at = model:GetAttribute(CUE_ATTRIBUTE)
		if typeof(at) == "number" then
			local now = os.clock()
			cue(s, now + (at - workspace:GetServerTimeNow()), now)
		end
	end
	table.insert(list, model:GetAttributeChangedSignal(CUE_ATTRIBUTE):Connect(onCue))
	onCue()
	if RunService:IsStudio() then
		-- the NpcReact showcase films a first meeting: a greeting from before the take (the player
		-- spawning nearby) must not hold this one back on its cooldown
		table.insert(list, model:GetAttributeChangedSignal(FRESH_ATTRIBUTE):Connect(function()
			if model:GetAttribute(FRESH_ATTRIBUTE) ~= nil then
				-- and no job gesture starts while the player walks up, so the greeting is not held
				-- back behind one (the stage sets this ~3.4 s before he notices them)
				s.greetReady = os.clock()
				s.nextGesture = math.max(s.nextGesture, os.clock() + 6)
			end
		end))
	end
end

local function frame(dt: number)
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	local now = os.clock()
	local look, half = Vector3.zAxis, math.pi
	if camera then
		local size = camera.ViewportSize
		local aspect = if size.Y > 0 then size.X / size.Y else 16 / 9
		look = camera.CFrame.LookVector
		half = math.atan(math.tan(math.rad(camera.FieldOfView) / 2) * math.sqrt(1 + aspect * aspect)) + VIEW_MARGIN
	end
	if now >= nextRetry then
		nextRetry = now + RETRY_EVERY
		for model in pairs(pending) do
			if model:IsDescendantOf(workspace) and CollectionService:HasTag(model, TAG) then
				track(model)
			else
				pending[model] = nil
			end
		end
		-- a rig that streamed out loses its parts: forget it and rebuild when it is back
		for model, s in pairs(states) do
			if not rigIntact(s.rig, model) then
				untrack(model)
				pending[model] = true
			end
		end
	end
	for model, s in pairs(states) do
		local root = s.rig.root
		local busy = model:GetAttribute(BUSY_ATTRIBUTE) == true
		local near = eye and root.Parent and (root.Position - eye).Magnitude < ANIMATE_RANGE
		if busy or not near then
			if s.active then
				s.active = false
				resetRig(s.rig) -- hand the joints back (HubAmbience's walk track takes over)
			end
			s.heldDt = nil
		else
			if not s.active then
				s.active = true
				s.weight = 0
				-- pending beats wait a little after a pause instead of all firing at once
				s.nextGlance = math.max(s.nextGlance, now + 1)
				s.nextGesture = math.max(s.nextGesture, now + 2)
			end
			local offset = root.Position - eye
			local distance = offset.Magnitude
			local seen = distance < VIEW_NEAR + VIEW_RADIUS
				or math.acos(math.clamp(offset:Dot(look) / distance, -1, 1)) <= half + math.asin(math.min(1, VIEW_RADIUS / distance))
			if not seen then
				s.heldDt = (s.heldDt or 0) + dt
				continue
			end
			local ok, err = pcall(step, s, now, dt + (s.heldDt or 0))
			s.heldDt = nil
			if not ok then
				warn("[NpcAnimator] " .. model.Name .. ": " .. tostring(err))
				untrack(model)
			end
		end
	end
end

-- Poses `model` as `role` at `t` seconds into a showcase cue (edit-mode preview; no loop).
function NpcAnimator.preview(model: Model, role: string, t: number, lookYaw: number?)
	local rig = buildRig(model)
	if not rig then
		return false
	end
	math.randomseed(7)
	local s = newState(model, rig, role, 0)
	s.fakeBearing = lookYaw
	s.greetReady = math.huge
	s.nextBlink = math.huge
	cue(s, 2, 0)
	s.nextBlink = math.huge
	local clock = 0
	local target = 2 + t
	while clock < target do
		local dt = math.min(1 / 60, target - clock)
		clock += dt
		local saved = s.lookYaw
		step(s, clock, dt)
		s.lookYaw = saved
	end
	return true
end

-- Poses `model` as `role` at `t` seconds after it notices a player at `bearing` degrees (+ to its
-- left) and greets them (edit-mode preview; no loop).
function NpcAnimator.previewReact(model: Model, role: string, t: number, bearing: number)
	local rig = buildRig(model)
	if not rig then
		return false
	end
	math.randomseed(7)
	local s = newState(model, rig, role, 0)
	s.nextBlink, s.nextGlance, s.nextGesture, s.nextShift = math.huge, math.huge, math.huge, math.huge
	s.weight = 1
	local clock = 0
	local target = 1 + t
	while clock < target do
		local dt = math.min(1 / 60, target - clock)
		clock += dt
		s.fakeBearing = if clock >= 1 then bearing else nil
		step(s, clock, dt)
	end
	return true
end

NpcAnimator.ROLES = ROLES
NpcAnimator.GESTURES = GESTURES

local started = false
function NpcAnimator.start()
	if started or not RunService:IsClient() then
		return
	end
	started = true
	for _, model in ipairs(CollectionService:GetTagged(TAG)) do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)
	RunService.PreSimulation:Connect(frame)
end

return NpcAnimator
