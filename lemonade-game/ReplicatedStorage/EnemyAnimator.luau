--// EnemyAnimator  (client-side body animation for every enemy rig)
--
-- The server stays authoritative for AI, timing and damage; it only publishes state:
--   * the rig itself (tagged CombatUtil.ENEMY_TAG = "Enemy", R6 Motor6Ds built by createEnemyRig,
--     plus a "Grip" Motor6D between the right arm and the sword so the wrist can turn the blade)
--   * model attribute "EnemyAttack" = Vector2.new(seq, windup): a swing started, and the blade
--     lands `windup` seconds later (the moment the server applies damage)
--   * the Humanoid's replicated Health: a drop that leaves it alive is a landed player hit, and
--     plays the layered hit reaction (flash, knockback stagger, recovery) on top of the pose
--   * model attributes "HitBlade" (a CFrame: where the blade met this body, facing the way it
--     was travelling) and "HitStop" (seconds), both set in the same server frame as the damage,
--     just before it: the impact streak is drawn on the blade rather than at the model's centre,
--     and the whole rig holds still for HitStop seconds before the stagger starts
-- Standing rigs near the camera breathe (a small idle) instead of freezing at rest.
-- Each client poses the joints locally through Motor6D.Transform, every frame, in one shared
-- PreSimulation loop. Nothing here writes C0 or replicates, so dozens of rigs cost no network.
--
-- Moving rigs run: a ground-pinned stride from their real displacement (see "Run" below).
-- Later motion pieces (idle, notice, hit, death) extend this module: add a channel to
-- `sample` and a trigger in `EnemyAnimator.start`.
--
-- Pose space: every joint's Transform is a rotation (plus, for the root, a translation) in the
-- rig's own axes: +X right, +Y up, -Z forward (toward the target). Translations are in rig-scale
-- studs (multiplied by the rig's scale, read from the Torso height).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PanelChrome = require(script.Parent:WaitForChild("PanelChrome")) -- the game's palette only
local Hitstop = require(script.Parent:WaitForChild("Hitstop")) -- the shared contact-frame hold

local EnemyAnimator = {}

local ENEMY_TAG = "Enemy" -- CombatUtil.ENEMY_TAG (CombatUtil is server-side)
local ATTACK_ATTRIBUTE = "EnemyAttack"
local ANIMATE_RANGE = 220 -- [TUNING] studs from the camera; farther rigs are left at rest
-- Off-screen rigs with nothing playing hold their pose and catch the skipped time up when they come
-- back into view. "In view" is generous: the view cone widened by a margin and the rig's size (its
-- shadow included), and every rig close to the camera counts, so nothing visible ever freezes.
local VIEW_MARGIN = math.rad(12) -- [TUNING] radians added around the camera's view cone
local VIEW_NEAR = 30 -- [TUNING] studs; rigs this close always animate (their shadows can reach into view)
local VIEW_RADIUS = 8 -- [TUNING] rig studs (times the rig's scale) a rig and its shadow may reach

local rad = math.rad
local clamp = math.clamp

-- ==============================================================================
-- Easing
-- ==============================================================================
local EASE = {
	linear = function(u) return u end,
	inQuad = function(u) return u * u end,
	outQuad = function(u) return 1 - (1 - u) * (1 - u) end,
	inCubic = function(u) return u * u * u end,
	outCubic = function(u) local v = 1 - u return 1 - v * v * v end,
	outQuart = function(u) local v = 1 - u return 1 - v * v * v * v end,
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
	-- Settles slightly past the target and back: a limb that arrives with weight.
	outBack = function(u)
		local c1 = 1.4
		local c3 = c1 + 1
		local v = u - 1
		return 1 + c3 * v * v * v + c1 * v * v
	end,
}

-- Degrees -> rotation, in the order every pose channel uses (yaw, then pitch, then roll).
local function euler(pitch, yaw, roll)
	return CFrame.fromEulerAnglesYXZ(rad(pitch), rad(yaw), rad(roll))
end

-- ==============================================================================
-- Attack: poses
-- ==============================================================================
-- Channels, degrees for angles, rig-scale studs for distances:
--   root  = { x, y, z, yaw, pitch, roll }  body about the hips (yaw + turns the torso left, i.e.
--           the sword shoulder forward; pitch + leans back)
--   neck  = { pitch, yaw, roll }
--   rarm  = { pitch, yaw, roll, grip }      sword arm about the shoulder; grip turns the blade
--           about the wrist (0 = blade forward from the fist, -90 = blade in line with the arm)
--   larm  = { pitch, yaw, roll }
--   lfoot, rfoot = { x, z, lift }           planted foot position relative to its rest spot
-- The left foot leads (steps toward the target); the right foot is the back foot.
local POSES = {
	rest = {
		root = { 0, 0, 0, 0, 0, 0 },
		neck = { 0, 0, 0 },
		rarm = { 0, 0, 0, 0 },
		larm = { 0, 0, 0 },
		lfoot = { 0, 0, 0 },
		rfoot = { 0, 0, 0 },
	},
	-- Wind-up: weight rocks onto the back leg, the torso turns the sword side away, the blade
	-- goes up over the shoulder and back, and the free hand points at the target. Held long
	-- enough to read.
	cock = {
		root = { 0.05, -0.2, 0.32, -28, 8, -4 },
		neck = { -6, 22, 0 },
		rarm = { 158, -10, 28, -30 },
		larm = { 62, 18, -12 },
		lfoot = { 0, -0.15, 0 },
		rfoot = { 0.1, 0.5, 0 },
	},
	-- End of the hold: the same pose, crept a little further so it never goes dead.
	hold = {
		root = { 0.06, -0.24, 0.36, -31, 9, -5 },
		neck = { -7, 24, 0 },
		rarm = { 166, -12, 30, -34 },
		larm = { 66, 20, -12 },
		lfoot = { 0, -0.15, 0 },
		rfoot = { 0.1, 0.52, 0 },
	},
	-- Contact: lead foot stepped in, hips driven forward and down, torso whipped through and
	-- leaning in, arm extended with the blade in line with it, level at the target.
	contact = {
		root = { -0.05, -0.3, -0.62, 44, -13, 3 },
		neck = { 8, -30, 0 },
		rarm = { 92, -40, 6, -90 },
		larm = { -28, 10, -22 },
		lfoot = { -0.05, -1.15, 0 },
		rfoot = { 0.1, 0.52, 0 },
	},
	-- Follow-through: the blade carries past the target to ~40 degrees below level, across the
	-- body toward the lead side, and holds there (hit-stop) before recovering.
	follow = {
		root = { -0.08, -0.34, -0.72, 54, -16, 5 },
		neck = { 10, -36, 0 },
		rarm = { 48, -8, -12, -88 },
		larm = { -36, 12, -26 },
		lfoot = { -0.05, -1.15, 0 },
		rfoot = { 0.1, 0.52, 0 },
	},
	settle = {
		root = { -0.08, -0.35, -0.74, 55, -16, 5 },
		neck = { 10, -37, 0 },
		rarm = { 45, -6, -13, -88 },
		larm = { -37, 12, -26 },
		lfoot = { -0.05, -1.15, 0 },
		rfoot = { 0.1, 0.52, 0 },
	},
}

local LAG = 0.035 -- [TUNING] seconds the sword arm trails the torso through the strike
local FOLLOW = 0.11 -- contact -> follow-through pose
local HITSTOP = 0.07 -- follow-through held
local RECOVER = 0.26 -- back to guard

-- Key times for a swing whose blade lands `windup` seconds in (the server's damage moment).
local function attackTimes(windup: number)
	local strike = clamp(windup * 0.27, 0.085, 0.13)
	local held = windup - strike
	local cock = held * 0.68
	local stop = windup + FOLLOW + HITSTOP
	return {
		cock = cock, held = held, contact = windup,
		follow = windup + FOLLOW, stop = stop, done = stop + RECOVER,
	}
end
EnemyAnimator.attackTimes = attackTimes

function EnemyAnimator.attackDuration(windup: number): number
	return attackTimes(windup).done
end

-- Segment list for one channel group: { tStart, tEnd, fromPose, toPose, ease }.
local function segments(k, lead: number)
	return {
		{ 0, k.cock, "rest", "cock", "outBack" },
		{ k.cock, k.held + lead, "cock", "hold", "linear" },
		{ k.held + lead, k.contact + lead, "hold", "contact", "inQuad" },
		{ k.contact + lead, k.follow, "contact", "follow", "outCubic" },
		{ k.follow, k.stop, "follow", "settle", "linear" },
		{ k.stop, k.done, "settle", "rest", "inOutCubic" },
	}
end

local function lerpChannel(a, b, u, out)
	for i = 1, #a do
		out[i] = a[i] + (b[i] - a[i]) * u
	end
	return out
end

local function sampleChannel(segs, name: string, t: number, out)
	for _, seg in ipairs(segs) do
		if t <= seg[2] then
			local span = seg[2] - seg[1]
			local u = if span > 0 then clamp((t - seg[1]) / span, 0, 1) else 1
			return lerpChannel(POSES[seg[3]][name], POSES[seg[4]][name], EASE[seg[5]](u), out)
		end
	end
	return lerpChannel(POSES.rest[name], POSES.rest[name], 0, out)
end

-- Channel values of the attack at `t` seconds into a swing that lands at `windup`.
-- The torso, head and feet lead the strike by LAG; the arms arrive LAG later.
function EnemyAnimator.sampleAttack(t: number, windup: number)
	local k = attackTimes(windup)
	local body = segments(k, -LAG)
	local arms = segments(k, 0)
	local pose = {}
	for _, name in ipairs({ "root", "neck", "lfoot", "rfoot" }) do
		pose[name] = sampleChannel(body, name, t, {})
	end
	for _, name in ipairs({ "rarm", "larm" }) do
		pose[name] = sampleChannel(arms, name, t, {})
	end
	-- The stepping foot leaves the ground on its way in and on its way back.
	local function lift(t0, t1, height)
		if t > t0 and t < t1 then
			pose.lfoot[3] = math.max(pose.lfoot[3], height * math.sin(math.pi * (t - t0) / (t1 - t0)))
		end
	end
	lift(k.held - LAG, k.contact - LAG, 0.45)
	lift(k.stop, k.stop + RECOVER * 0.8, 0.3)
	return pose
end

-- ==============================================================================
-- Hit reaction (layered on top of whatever the body is doing)
-- ==============================================================================
-- Triggered on each client when the enemy's replicated Health drops (the server applies the
-- sword's damage the moment it lands, so the reaction starts on the gameplay hit). Every value
-- here is ADDED to the base pose (rest, idle or a swing in progress), so a hit mid-swing staggers
-- the swing instead of cancelling it. Nothing here touches the server: the knockback is visual,
-- the rig's root part never moves, and the body steps back in to it once guard is up.
--
-- Beats, seconds from the hit (on the reaction's own clock, which advances at most one 30 fps
-- frame per rendered frame, so a hitch at contact delays the stagger instead of skipping it):
--   (before 0) hitstop: the whole rig -- this reaction, the idle under it, a swing of its own --
--              is held dead still for as long as the server's "HitStop" says, less the 0.04 the
--              reaction's own first beat already holds for. Nothing below starts until it ends.
--   0.00-0.04  impact: the body snaps into a first flinch and shivers (hit-stop) under a white flash
--   0.04-0.17  knockback: the root is thrown ~2.5 studs back along the blow (ease-out, most of it
--              in the first 80 ms), the back foot steps under it and dust kicks up at the feet;
--              the torso whips back ~22 degrees and twists away; the head SNAPS back 19 degrees
--              ~20 ms behind the torso; the arms fly out and back
--   0.17-0.24  stagger peak, still creeping so it never goes dead; the flash turns red and fades
--   0.20-0.55  recovery, blended: the torso rises through upright to ~5 degrees forward (0.37)
--              and settles back (0.55) while the knees dip to absorb it; the free arm follows the
--              torso by ~40 ms and the sword arm by ~70 ms; the front foot drags back under
--   0.60-1.00  two steps forward back onto the root (feet planted, never sliding)
local HIT_DURATION = 1.0
EnemyAnimator.HIT_DURATION = HIT_DURATION
local HIT_STOP = 0.04 -- [TUNING] seconds the impact pose is held
local HIT_FLASH_END = 0.3
local HIT_MAX_STEP = 1 / 30 -- [TUNING] most the reaction's clock advances in one rendered frame

-- Piecewise curve: keys = { {t, value, ease?}, ... } (ease shapes the segment ending at that key).
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

-- Studs along the blow (root), degrees for angles.
local HIT = {
	-- The shove: 2.5 studs along the blow, 2.1 of them inside the first 80 ms after the hold
	-- lets go (it was 1.85 over the same span -- the first strips of it read as a body that
	-- changed colour and stayed put). Still creeping to 0.24 so the peak never goes dead.
	push = { { 0, 0 }, { HIT_STOP, 0.4, "outCubic" }, { 0.12, 2.1, "outCubic" }, { 0.17, 2.45, "outCubic" },
		{ 0.24, 2.55 }, { 0.6, 2.5 }, { 1.0, 0, "inOutCubic" } },
	-- Hips: dropped by the blow, dipping again as the knees absorb the recovery, then rising.
	drop = { { 0, -0.05 }, { HIT_STOP, -0.08 }, { 0.12, -0.28, "outCubic" }, { 0.2, -0.31 },
		{ 0.32, -0.4, "inOutCubic" }, { 0.5, -0.12, "inOutCubic" }, { 0.64, -0.17, "inOutCubic" },
		{ 0.82, -0.03, "inOutCubic" }, { 1.0, 0, "inOutCubic" } },
	lean = { { 0, 8 }, { HIT_STOP, 9 }, { 0.11, 21, "outCubic" }, { 0.2, 22.5 },
		{ 0.37, -5, "inOutCubic" }, { 0.55, 0.6, "inOutCubic" }, { 0.72, -1.2, "inOutCubic" },
		{ 1.0, 0, "inOutCubic" } },
	twist = { { 0, 3 }, { HIT_STOP, 3.5 }, { 0.12, 10, "outCubic" }, { 0.2, 11 },
		{ 0.38, -2, "inOutCubic" }, { 0.56, 0, "inOutCubic" } },
	-- The head SNAPS: it trails the torso by ~20 ms, whips back 19 degrees in 60 ms (the torso
	-- takes 70 for its 21), overshoots, and nods forward as the body recovers. It used to trail
	-- by 35 ms and take 80 ms over 13 degrees, which is a head that follows rather than snaps.
	headPitch = { { 0, 3 }, { 0.06, 3 }, { 0.12, 19, "outCubic" }, { 0.2, 14, "inOutCubic" },
		{ 0.41, -6, "inOutCubic" }, { 0.58, 0, "inOutCubic" } },
	headRoll = { { 0, 2 }, { 0.06, 2 }, { 0.13, 9, "outCubic" }, { 0.42, -2, "inOutCubic" },
		{ 0.58, 0, "inOutCubic" } },
	-- The arms fly out and back (0..1 of the peak fling), lagging the torso: the free arm by
	-- ~40 ms, the sword arm (heavier, holding the blade) by ~70 ms, each overshooting into guard.
	larm = { { 0, 0.25 }, { HIT_STOP, 0.25 }, { 0.15, 1, "outCubic" }, { 0.24, 1.05 },
		{ 0.42, -0.12, "inOutCubic" }, { 0.58, 0, "inOutCubic" } },
	rarm = { { 0, 0.2 }, { HIT_STOP, 0.2 }, { 0.16, 1, "outCubic" }, { 0.27, 1.06 },
		{ 0.46, -0.14, "inOutCubic" }, { 0.64, 0, "inOutCubic" } },
	-- Feet, studs along the blow: the back foot steps under the thrown body at once, the front
	-- foot drags after it; both step back in to the root after guard is up.
	back = { { 0, 0 }, { 0.03, 0.05 }, { 0.13, 2.0, "outCubic" }, { 0.78, 2.0 },
		{ 0.98, 0, "inOutCubic" } },
	front = { { 0, 0 }, { 0.1, 0 }, { 0.24, 1.35, "outCubic" }, { 0.6, 1.35 },
		{ 0.8, 0, "inOutCubic" } },
}
local ARM_FLING = { pitch = -30, roll = 38, grip = 24 } -- [TUNING] degrees at the peak

local function arc(t: number, t0: number, t1: number, height: number): number
	if t > t0 and t < t1 then
		return height * math.sin(math.pi * (t - t0) / (t1 - t0))
	end
	return 0
end

-- Additive channels of the hit reaction at `t` seconds. (px, pz) is the unit direction of the
-- blow in the rig's own X/Z (normally (0, 1): straight back, away from an attacker in front).
function EnemyAnimator.sampleHit(t: number, px: number, pz: number)
	local d = curve(HIT.push, t)
	if t < HIT_STOP then
		d += 0.07 * math.sin(t * math.pi * 2 * 30) -- impact shiver
	end
	local lean = curve(HIT.lean, t)
	local a, b = curve(HIT.rarm, t), curve(HIT.larm, t)
	local back, front = curve(HIT.back, t), curve(HIT.front, t)
	local backLift = arc(t, 0.03, 0.13, 0.45) + arc(t, 0.78, 0.98, 0.35)
	local frontLift = arc(t, 0.1, 0.24, 0.3) + arc(t, 0.6, 0.8, 0.35)
	return {
		-- Leaning away from the blow: pitch for a blow from the front, roll for one from the side.
		root = { px * d, curve(HIT.drop, t), pz * d, curve(HIT.twist, t), lean * pz, -lean * px },
		neck = { curve(HIT.headPitch, t), 0, curve(HIT.headRoll, t) },
		rarm = { ARM_FLING.pitch * a, 6 * a, ARM_FLING.roll * a, ARM_FLING.grip * a },
		larm = { ARM_FLING.pitch * 0.85 * b, -8 * b, -ARM_FLING.roll * 1.1 * b },
		-- The left foot leads (front), the right foot is the back foot.
		lfoot = { px * front, pz * front, frontLift },
		rfoot = { px * back, pz * back, backLift },
	}
end

-- Whole-body flash: white through the hit-stop, then red, fading out.
local FLASH_WHITE = Color3.fromRGB(255, 255, 255)
local FLASH_RED = Color3.fromRGB(255, 38, 38)
local function flashAt(t: number): (Color3, number, number)
	if t < HIT_STOP + 0.01 then
		-- 0.5, not the 0.22 it was: at 0.22 the white beat was a solid silhouette, and it sat on
		-- exactly the frames the body starts to recoil in. The flash has to sit ON a body that
		-- moves, so the body has to show through it.
		return FLASH_WHITE, 0.5, 0
	end
	-- Translucent enough that the stagger's silhouette still reads through the tint.
	local fill = if t < 0.17 then 0.55 else 0.55 + 0.45 * clamp((t - 0.17) / (HIT_FLASH_END - 0.17), 0, 1)
	local outline = clamp((t - 0.06) / 0.18, 0, 1)
	return FLASH_RED, fill, outline
end

-- ==============================================================================
-- Death: the killing blow's recoil flowing into a collapse, then a burn into lemon embers
-- ==============================================================================
-- Triggered on each client when the enemy's replicated Health reaches 0 (or, for a client that
-- only sees the rig after it died, from the server's "EnemyDied" timestamp, skipping ahead). The
-- server anchors the dead rig's root where it stood and removes the model DEATH_LINGER seconds
-- later; everything here is local and done well before that. The pose is absolute (it replaces
-- whatever the body was doing, blended over the first few frames), built as a side view of a
-- body falling away from the blow: the feet stay on the ground while the legs tip over them, the
-- pelvis rides the legs down, and the torso tips about the pelvis.
--
-- Beats, seconds from the killing blow:
--   0.00-0.055 recoil: the torso snaps ~24 degrees back from the blade under a white flash, the
--              whole body is shoved back along the blow, the arms fling out and back, and the
--              head whips back a further ~17 degrees ~35 ms behind the torso
--   0.07       the hand opens and the sword tumbles away to clatter on the ground
--   0.07-0.26  the legs give way: the feet kick forward and the pelvis drops (a slump), the torso
--              still reclining; the flash turns red and fades
--   0.14-0.48  the whole body topples backward (gravity: slow, then fast); the legs slap down at
--              ~0.44, the back at ~0.48, the head whips onto the ground behind it; dust kicks up
--              and the nameplate goes
--   0.48-0.68  one ~8 degree bounce and a settle; the head lolls to one side, the arms flop out
--   0.80-0.98  the corpse catches: a lemon-yellow rim (a ForceField shell over every part plus a
--              lemon outline) glows up around its edges while the body underneath warms
--   0.98-1.42  it burns away from the edges inward: the rim shell tightens onto the body, the body
--              whitens to hot lemon and fades (gone by ~1.42), rising yellow-white embers stream off
--              its surface and drift up, and a gold ring runs out along the ground under a warm flare
local DEATH_LINGER = 1.8 -- seconds the server keeps the dead model (EnemyCombat's Died handler)
EnemyAnimator.DEATH_LINGER = DEATH_LINGER
local DEATH_BLEND = 0.05 -- [TUNING] seconds to blend from the live pose into the death pose
local DEATH_RELEASE = 0.07 -- the sword leaves the hand
local DEATH_LAND = 0.47 -- the back hits the ground (dust, nameplate off)
local DEATH_GLOW = 0.8 -- the lemon rim starts
local DEATH_BURN = 0.98 -- the burn starts (ring, flare, first embers)
local DEATH_FADE = 0.44 -- seconds the body takes to burn away
local DEATH_END = 1.6

local DEATH = {
	-- Torso recline from upright, about the pelvis, degrees (90 = flat on its back).
	lean = { { 0, 0 }, { 0.055, 24, "outCubic" }, { 0.14, 30, "outQuad" }, { 0.48, 90, "inQuad" },
		{ 0.53, 82, "outQuad" }, { 0.6, 90, "inQuad" }, { 0.64, 88.6, "outQuad" }, { 0.68, 90, "inQuad" } },
	-- Leg tilt over the planted feet, degrees (feet forward, pelvis back and down).
	legs = { { 0, 0 }, { 0.07, 0 }, { 0.26, 52, "outQuad" }, { 0.44, 89, "inQuad" },
		{ 0.49, 85, "outQuad" }, { 0.55, 89, "inQuad" } },
	-- The blow's shove, studs along it.
	push = { { 0, 0 }, { 0.1, 0.75, "outCubic" }, { 0.3, 0.9, "outQuad" } },
	-- A twist toward the sword side and a roll as it goes down, so it never falls like a plank.
	twist = { { 0, 0 }, { 0.06, 5, "outCubic" }, { 0.48, 16, "inOutCubic" }, { 0.68, 13, "inOutCubic" } },
	roll = { { 0, 0 }, { 0.14, -3 }, { 0.48, -9, "inOutCubic" }, { 0.68, -7, "inOutCubic" } },
	-- Head, relative to the torso: whips back behind the recoil, lags forward (chin in) through the
	-- fall, snaps back onto the ground at impact, then lolls to one side.
	headPitch = { { 0, 0 }, { 0.035, 0 }, { 0.095, 17, "outCubic" }, { 0.17, 11, "inOutCubic" },
		{ 0.46, -26, "inOutCubic" }, { 0.52, -4, "outQuad" }, { 0.58, -20, "outQuad" }, { 0.72, -16, "inOutCubic" } },
	headYaw = { { 0, 0 }, { 0.5, 0 }, { 0.78, 34, "inOutCubic" } },
	headRoll = { { 0, 0 }, { 0.095, 8, "outCubic" }, { 0.5, 3, "inOutCubic" }, { 0.78, -8, "inOutCubic" } },
	-- Arms: flung out and back by the blow, trailing up and forward as the body drops away under
	-- them, then slapping onto the ground spread wide, with a little bounce.
	rarmPitch = { { 0, 0 }, { 0.065, -52, "outCubic" }, { 0.15, -38, "inOutCubic" }, { 0.45, 58, "inOutCubic" },
		{ 0.52, -10, "inQuad" }, { 0.58, 6, "outQuad" }, { 0.66, 0, "inOutCubic" } },
	rarmRoll = { { 0, 0 }, { 0.065, 58, "outCubic" }, { 0.15, 72, "inOutCubic" }, { 0.45, 84, "inOutCubic" },
		{ 0.52, 60, "inQuad" }, { 0.58, 66, "outQuad" }, { 0.66, 62, "inOutCubic" } },
	larmPitch = { { 0, 0 }, { 0.08, -46, "outCubic" }, { 0.17, -34, "inOutCubic" }, { 0.47, 50, "inOutCubic" },
		{ 0.54, -8, "inQuad" }, { 0.6, 5, "outQuad" }, { 0.68, 2, "inOutCubic" } },
	larmRoll = { { 0, 0 }, { 0.08, -62, "outCubic" }, { 0.17, -76, "inOutCubic" }, { 0.47, -80, "inOutCubic" },
		{ 0.54, -56, "inQuad" }, { 0.6, -62, "outQuad" }, { 0.68, -58, "inOutCubic" } },
	grip = { { 0, 0 }, { DEATH_RELEASE, 35, "outCubic" } },
	-- Legs splay apart as they give way.
	splay = { { 0, 0 }, { 0.26, 12, "outQuad" }, { 0.46, 17, "inOutCubic" }, { 0.6, 15, "inOutCubic" } },
}

-- Joint Transforms of the death pose at `t` seconds. (px, pz) is the blow's direction in the rig's
-- own X/Z (normally (0, 1): straight back); `s` is the rig's scale.
function EnemyAnimator.sampleDeath(t: number, px: number, pz: number, s: number)
	local f = Vector3.new(px, 0, pz)
	local up = Vector3.yAxis
	-- Rotating about this axis by a positive angle tips "up" toward the blow.
	local axis = Vector3.new(pz, 0, -px)
	local lean, legs = curve(DEATH.lean, t), curve(DEATH.legs, t)
	local legR = rad(legs)
	-- The feet: shoved back along the blow, and (a box rocking back over its heel) lifted by half
	-- a leg's depth as the legs go flat so they lie on the ground instead of in it.
	local feet = f * (curve(DEATH.push, t) * s + 0.5 * s * (1 - math.cos(legR)))
		+ up * (-3 * s + 0.5 * s * math.sin(legR))
	local pelvis = feet + (up * math.cos(legR) + f * math.sin(legR)) * 2 * s
	local torsoRot = CFrame.fromAxisAngle(axis, rad(lean)) * euler(0, curve(DEATH.twist, t), curve(DEATH.roll, t))
	local torsoCF = CFrame.new(pelvis + torsoRot:VectorToWorldSpace(Vector3.new(0, s, 0))) * torsoRot
	local legRot = CFrame.fromAxisAngle(axis, legR)
	local splay = curve(DEATH.splay, t)
	local toTorso = torsoRot:Inverse()
	-- The right leg trails the left by a few degrees so the two do not move as one block.
	local rightLeg = CFrame.fromAxisAngle(axis, rad(math.max(0, legs - 6 * math.sin(math.pi * clamp(t / 0.5, 0, 1)))))
	return {
		RootJoint = torsoCF,
		Neck = euler(curve(DEATH.headPitch, t), curve(DEATH.headYaw, t), curve(DEATH.headRoll, t)),
		["Right Shoulder"] = euler(curve(DEATH.rarmPitch, t), 0, curve(DEATH.rarmRoll, t)),
		Grip = CFrame.Angles(rad(curve(DEATH.grip, t)), 0, 0),
		["Left Shoulder"] = euler(curve(DEATH.larmPitch, t), 0, curve(DEATH.larmRoll, t)),
		["Left Hip"] = toTorso * legRot * euler(0, 0, -splay),
		["Right Hip"] = toTorso * rightLeg * euler(0, 0, splay),
	}
end

-- ==============================================================================
-- Idle: slow breathing so a standing enemy is never dead still
-- ==============================================================================
-- Two layers. The small guard breath below runs whenever an alert rig stands (waiting to swing,
-- mid-swing); the unaware idle further down replaces it while the rig has not noticed anyone.
local IDLE_PERIOD = 2.8 -- [TUNING] seconds per breath (guard)
local IDLE_RANGE = 90 -- [TUNING] studs from the camera; farther idle rigs stay at rest (no writes)

function EnemyAnimator.sampleIdle(t: number)
	local w = t * math.pi * 2 / IDLE_PERIOD
	local b = math.sin(w)
	local lag = math.sin(w - 0.7)
	return {
		root = { 0, 0.03 * b, 0, 0, -1.3 * b, 0 },
		neck = { 1.1 * lag, 0, 0 },
		rarm = { 1.5 * lag, 0, 1.8 * b, 0 },
		larm = { 1.5 * lag, 0, -1.8 * b },
		lfoot = { 0, 0, 0 },
		rfoot = { 0, 0, 0 },
	}
end

-- Unaware idle: an enemy that has not noticed anyone, standing around. Layers on their own
-- randomised clocks (so a field of enemies never moves in step, and one enemy never loops):
--   * stance   a soft, loaded stance: the feet set wide and staggered (left foot forward), the hips
--              seated down onto them (see `pose.seat` in transforms), the torso bladed a little and
--              hunched, the weapon carried low and out from the thigh
--   * breath   ~3.3 s cycle that never stops, a quicker inhale than exhale: the chest pitches back
--              ~4 degrees peak to peak, the shoulders rise ~0.07 studs ~130 ms after it, the arms
--              follow and the blade tip trails, so no two frames of a standing enemy are the same
--   * sway     the pelvis never stops: a slow side-to-side drift (two incommensurate sines, so it
--              never loops) of ~0.05 studs with the hips rolling over the legs
--   * weight   every ~3-5.5 s the hips carry ~0.14 studs over one leg in ~1 s and settle with a small
--              overshoot; the free hip drops ~4 degrees, the torso turns a touch toward the weighted
--              leg, the arms swing to hang true ~100 ms late, the head stays level, the feet stay put
--   * glance   every ~3-6.5 s the head dips (anticipation), turns 20-34 degrees in ~350 ms with a
--              small overshoot, holds, and eases back with a small overshoot; the torso follows
--   * fidget   every ~6-10 s a staged beat that travels through the body, never a pose swap:
--              regrip  the head turns to the blade first (~400 ms, eased), the hips carry the weight
--                      onto the back leg (from ~100 ms, ~0.5 s), the hand dips as anticipation
--                      (~150 ms), then the shoulder lifts the blade over ~600 ms with the forearm and
--                      wrist trailing ~100 ms each, the tip overshoots ~6 degrees and settles over
--                      ~200 ms, held while he looks it over, then lowered back to the carry
--              swing   a lazy pendulum swing from the shoulder, the blade tip trailing the hand
-- All amplitudes are small and every segment is eased, so it reads alive without twitching.
local BREATH_PERIOD = 3.4 -- [TUNING] seconds per breath: a 1.6 s inhale, a 1.8 s exhale
local BREATH_IN = 1.6 / 3.4 -- share of the cycle spent inhaling
local BREATH_PITCH = 1.5 -- [TUNING] degrees either side of the stance the chest pitches (3 in all)
local BREATH_LIFT = 0.03 -- [TUNING] rig studs either side the shoulders rise and fall (0.06 in all)
local SWAY_HIPS = 0.05 -- [TUNING] studs of continuous pelvis drift
local SWAY_ROLL = 1.3 -- [TUNING] degrees of hip roll with it
local SHIFT_HIPS = 0.14 -- [TUNING] studs the hips carry over the weighted leg
local SHIFT_ROLL = 4 -- [TUNING] degrees the free hip drops
local SHIFT_GAP = { 3.0, 5.5 } -- seconds between weight shifts (after one lands)
local GLANCE_GAP = { 3.2, 6.5 } -- seconds between glances
local FIDGET_GAP = { 6, 10 } -- seconds between weapon fidgets
local IDLE_IN = 0.6 -- seconds for the idle to take over once a rig stands unaware
local IDLE_OUT = 0.15 -- seconds for it to let go (notice, run, swing, hit)

-- Added on top of rest. Feet: { x (out is away from the body), z (- forward), lift }.
local STANCE = {
	root = { 0, 0, 0.05, -7, -3, 0 },
	neck = { 1, 6, 0 },
	rarm = { 12, 0, 10, -18 },
	larm = { 8, 0, -9 },
	lfoot = { -0.16, -0.42, 0 },
	rfoot = { 0.16, 0.34, 0 },
}

-- Share of a weight shift over its own duration (1 = SHIFT_TIME): eased across, a little past the
-- leg, then settled onto it.
local SHIFT_CURVE = { { 0, 0 }, { 0.78, 1.06, "inOutCubic" }, { 1.0, 1, "inOutQuad" } }
local SHIFT_TIME = 1.0
-- Share of the glance's turn: a small counter-dip, the turn with overshoot, then (after the hold)
-- the return with an overshoot the other way.
local GLANCE_OUT = { { 0, 0 }, { 0.13, -0.05, "inOutQuad" }, { 0.47, 1.07, "outCubic" }, { 0.64, 1, "inOutQuad" } }
local GLANCE_BACK = { { 0, 1 }, { 0.45, -0.06, "inOutCubic" }, { 0.62, 0, "inOutQuad" } }
local GLANCE_DIP = { { 0, 0 }, { 0.13, -4, "inOutQuad" }, { 0.42, 0, "inOutQuad" } }
local GLANCE_TURNED = 0.47 -- seconds from the start to fully turned
local GLANCE_HEAD_LAG = 0.18 -- seconds the head trails the chest into (and out of) a glance

-- Each fidget is a set of curves over its own clock, degrees: `torso` (yaw, + turns the sword
-- shoulder forward), `shoulder` (arm pitch, the lift), `forearm` (the arm's twist, turning the hand
-- in) and `wrist` (the grip, tip up +), plus the head's own `lookYaw` (- is toward the sword side)
-- and `lookPitch` (- is down). `lag` delays the forearm by one step and the wrist by two, for
-- curves written in step with the shoulder; the regrip's curves carry their own stagger (lag 0).
-- `shift` (seconds) carries the weight onto the other leg at that moment, over `shiftTime`.
local FIDGETS = {
	-- Grip adjust, a chain from the hips out to the blade tip: the weight carries onto the sword
	-- (back) leg from the start (~0.9 s), the chest turns the sword shoulder forward ~5 degrees
	-- (at once), the head follows the chest ~150 ms later (25 degrees, looking the blade over), the
	-- shoulder lifts the arm over ~550 ms from ~0.3 s after a small dip, the forearm trails it
	-- ~100 ms and the wrist ~100 ms more, the tip overshooting ~5 degrees and settling over ~200 ms.
	-- All of it has settled ~1.3 s in; the blade is held there while he looks it over, then lowered.
	regrip = {
		duration = 2.7,
		lag = 0,
		shift = 0,
		shiftTime = 0.9,
		lookYaw = { { 0, 0 }, { 0.15, 0 }, { 0.62, -27, "inOutCubic" }, { 0.8, -24.5, "inOutQuad" },
			{ 1.95, -23 }, { 2.5, 0, "inOutCubic" } },
		lookPitch = { { 0, 0 }, { 0.2, 0 }, { 0.68, -8, "inOutCubic" }, { 1.1, -6, "inOutQuad" },
			{ 1.95, -6 }, { 2.5, 0, "inOutCubic" } },
		torso = { { 0, 0 }, { 0.02, 0 }, { 0.5, 5.5, "inOutQuad" }, { 0.72, 5, "inOutQuad" }, { 2.0, 4.5 },
			{ 2.6, 0, "inOutQuad" } },
		shoulder = { { 0, 0 }, { 0.2, 0 }, { 0.32, -3, "inOutQuad" }, { 0.86, 23, "inOutCubic" },
			{ 0.94, 25, "outQuad" }, { 1.1, 22, "inOutQuad" }, { 1.9, 21 }, { 2.5, 0, "inOutCubic" } },
		forearm = { { 0, 0 }, { 0.3, 0 }, { 0.42, -2, "inOutQuad" }, { 0.96, 11, "inOutCubic" },
			{ 1.04, 13, "outQuad" }, { 1.2, 10.5, "inOutQuad" }, { 2.0, 10 }, { 2.6, 0, "inOutCubic" } },
		wrist = { { 0, 0 }, { 0.4, 0 }, { 0.52, -5, "inOutQuad" }, { 1.06, 26, "inOutCubic" },
			{ 1.13, 31, "outQuad" }, { 1.3, 26, "inOutQuad" }, { 2.0, 26 }, { 2.65, 0, "inOutCubic" } },
	},
	-- Lazy swing: the shoulder swings the arm like a pendulum and the blade tip trails the hand.
	swing = {
		duration = 2.3,
		lag = 0.1,
		lookYaw = { { 0, 0 }, { 0.4, -7, "inOutQuad" }, { 1.4, -7 }, { 1.9, 0, "inOutQuad" } },
		lookPitch = { { 0, 0 }, { 0.4, -4.5, "inOutQuad" }, { 1.4, -4.5 }, { 1.9, 0, "inOutQuad" } },
		torso = { { 0, 0 }, { 0.4, 4, "inOutQuad" }, { 0.9, -3, "inOutQuad" }, { 1.4, 2, "inOutQuad" },
			{ 1.9, 0, "inOutQuad" } },
		shoulder = { { 0, 0 }, { 0.4, 16, "inOutQuad" }, { 0.9, -8, "inOutQuad" }, { 1.4, 8, "inOutQuad" },
			{ 1.85, -2, "inOutQuad" }, { 2.1, 0, "inOutQuad" } },
		forearm = { { 0, 0 }, { 0.45, 4, "inOutQuad" }, { 0.95, -3, "inOutQuad" }, { 1.45, 2, "inOutQuad" },
			{ 2.0, 0, "inOutQuad" } },
		wrist = { { 0, 0 }, { 0.45, 12, "inOutQuad" }, { 0.95, -12, "inOutQuad" }, { 1.45, 8, "inOutQuad" },
			{ 1.9, -2, "inOutQuad" }, { 2.1, 0, "inOutQuad" } },
	},
}
local FIDGET_KINDS = { "regrip", "swing" }

local function between(range): number
	return range[1] + (range[2] - range[1]) * math.random()
end

-- -1 fully out, +1 fully in; smooth at both ends.
local function breathAt(t: number): number
	local x = (t / BREATH_PERIOD) % 1
	if x < BREATH_IN then
		return -math.cos(math.pi * x / BREATH_IN)
	end
	return math.cos(math.pi * (x - BREATH_IN) / (1 - BREATH_IN))
end

-- Per-rig idle clocks, desynchronised: a random breath and sway phase, a random starting leg and
-- random first glance, shift and fidget times.
function EnemyAnimator.newIdle(now: number)
	local side = if math.random() < 0.5 then -1 else 1
	return {
		breath = math.random() * BREATH_PERIOD,
		sway = math.random() * 100,
		shiftFrom = side, shiftTo = side, shiftT0 = -math.huge, shiftDur = SHIFT_TIME,
		nextShift = now + between(SHIFT_GAP),
		nextGlance = now + between(GLANCE_GAP) * 0.6,
		nextFidget = now + between(FIDGET_GAP),
	}
end

-- Pushes every pending beat out after a pause (the rig ran, fought or was off screen), so it does
-- not fire the moment the idle resumes.
local function resumeIdle(idle, now: number)
	idle.glanceT0, idle.fidgetT0 = nil, nil
	idle.nextShift = math.max(idle.nextShift, now + between(SHIFT_GAP) * 0.5)
	idle.nextGlance = math.max(idle.nextGlance, now + between(GLANCE_GAP) * 0.5)
	if not idle.forceFidget then -- a cued beat keeps its moment (see cueIdle)
		idle.nextFidget = math.max(idle.nextFidget, now + between(FIDGET_GAP) * 0.5)
	end
end

local function shiftAt(idle, t: number): number
	local u = curve(SHIFT_CURVE, (t - idle.shiftT0) / idle.shiftDur)
	return idle.shiftFrom + (idle.shiftTo - idle.shiftFrom) * u
end

-- Starts a weight shift at `now` from wherever the hips are to `to` (-1 left leg, 1 right leg).
local function startShift(idle, now: number, to: number, duration: number)
	idle.shiftFrom, idle.shiftTo, idle.shiftT0, idle.shiftDur = shiftAt(idle, now), to, now, duration
end

-- Schedules a grip adjust at local clock `at` (head, then hips, then the arm, see FIDGETS.regrip),
-- with the hips eased to centre beforehand so it carries them onto the back leg, and the breath
-- at its lowest just before, so the whole beat plays over a rising chest. The Studio showcase uses
-- it to land the beat inside its strip; glances and shifts resume afterwards.
function EnemyAnimator.cueIdle(idle, at: number)
	local now = os.clock()
	startShift(idle, now, -0.6, math.clamp(at - now - 0.3, 0.3, 0.9))
	idle.breath = -(at - 0.2) % BREATH_PERIOD
	idle.nextShift = at + 3.2
	idle.nextGlance = at + 3.4
	idle.nextFidget = at
	idle.forceFidget = "regrip"
	idle.glanceT0, idle.fidgetT0 = nil, nil
end

local function glanceShare(idle, t: number): number
	if t <= 0 then
		return 0
	end
	local back = GLANCE_TURNED + idle.glanceHold
	if t < back then
		return curve(GLANCE_OUT, t)
	end
	return curve(GLANCE_BACK, t - back)
end

-- Continuous pelvis drift, about -1..1: two incommensurate sines, so it never repeats.
local function swayAt(t: number): number
	return 0.62 * math.sin(t * math.pi * 2 / 2.8) + 0.38 * math.sin(t * math.pi * 2 / 4.7 + 1.3)
end

-- Advances the idle's schedule to `now` and returns its additive channels (plus shoulder lifts).
function EnemyAnimator.stepIdle(idle, now: number)
	-- Weight shift: from wherever the hips are to the other leg (sometimes back to centre).
	-- A fidget carries its own shift, so none starts while one plays.
	if now >= idle.nextShift and not idle.fidgetT0 then
		local current = shiftAt(idle, now)
		local to
		if math.abs(current) < 0.5 then
			to = if math.random() < 0.5 then -1 else 1
		else
			to = if math.random() < 0.2 then 0 else -math.sign(current)
		end
		startShift(idle, now, to, SHIFT_TIME)
		idle.nextShift = now + SHIFT_TIME + between(SHIFT_GAP)
	end
	-- Glance: a look to one side, held, then back.
	if idle.glanceT0 and now - idle.glanceT0 > GLANCE_TURNED + idle.glanceHold + 0.62 + GLANCE_HEAD_LAG then
		idle.glanceT0 = nil
	end
	if not idle.glanceT0 and not idle.fidgetT0 and now >= idle.nextGlance then
		idle.glanceT0 = now
		idle.glanceYaw = (20 + 14 * math.random()) * (if math.random() < 0.5 then -1 else 1)
		idle.glancePitch = -2 + 7 * math.random()
		idle.glanceHold = 0.6 + 0.5 * math.random()
		idle.nextGlance = now + GLANCE_TURNED + idle.glanceHold + 0.62 + GLANCE_HEAD_LAG + between(GLANCE_GAP)
	end
	-- Weapon fidget: only while the head is free (the fidget turns it to the blade).
	local fidget = idle.fidgetT0 and FIDGETS[idle.fidgetKind]
	if fidget and now - idle.fidgetT0 > fidget.duration then
		idle.fidgetT0, fidget = nil, nil
	end
	if not fidget and not idle.glanceT0 and now >= idle.nextFidget then
		idle.fidgetKind = idle.forceFidget or FIDGET_KINDS[math.random(1, #FIDGET_KINDS)]
		idle.forceFidget = nil
		idle.fidgetT0 = now
		idle.fidgetShifted = false
		fidget = FIDGETS[idle.fidgetKind]
		idle.nextFidget = now + fidget.duration + between(FIDGET_GAP)
		idle.nextGlance = math.max(idle.nextGlance, now + fidget.duration + 0.8)
	end
	-- The fidget's own weight shift, onto the back (right) leg unless the hips are already there.
	if fidget and fidget.shift and not idle.fidgetShifted and now - idle.fidgetT0 >= fidget.shift then
		idle.fidgetShifted = true
		startShift(idle, now, if shiftAt(idle, now) > 0.5 then -1 else 1, fidget.shiftTime)
		idle.nextShift = math.max(idle.nextShift, now + fidget.duration + between(SHIFT_GAP) * 0.5)
	end

	local bt = now + idle.breath
	local b = breathAt(bt)
	local bsh = breathAt(bt - 0.1) -- the shoulders rise after the chest
	local barm = breathAt(bt - 0.14) -- the arms ride it ~140 ms behind the chest
	local bblade = breathAt(bt - 0.24) -- the blade tip after the hand
	local sw = swayAt(now + idle.sway)
	local swArms = swayAt(now + idle.sway - 0.12)
	local sh = shiftAt(idle, now)
	local shArms = shiftAt(idle, now - 0.1)
	local yaw, gHead, gBody, pitch = 0, 0, 0, 0
	if idle.glanceT0 then
		local t = now - idle.glanceT0
		yaw = idle.glanceYaw
		gBody = glanceShare(idle, t) -- the chest starts the turn
		gHead = glanceShare(idle, t - GLANCE_HEAD_LAG) -- and the head follows it round
		pitch = curve(GLANCE_DIP, t - GLANCE_HEAD_LAG) + idle.glancePitch * gHead
	end
	local ft, fs, ff, fw, lookYaw, lookPitch = 0, 0, 0, 0, 0, 0
	if fidget then
		local t = now - idle.fidgetT0
		local lag = fidget.lag
		ft = curve(fidget.torso, t)
		fs = curve(fidget.shoulder, t)
		ff = curve(fidget.forearm, t - lag)
		fw = curve(fidget.wrist, t - 2 * lag)
		lookYaw = curve(fidget.lookYaw, t)
		lookPitch = curve(fidget.lookPitch, t)
	end
	local lean = BREATH_PITCH * b
	local roll = SHIFT_ROLL * sh + SWAY_ROLL * sw
	local hang = -0.7 * (SHIFT_ROLL * shArms + SWAY_ROLL * swArms) -- the arms swing back to hanging true
	local st = STANCE
	return {
		root = { SHIFT_HIPS * sh + SWAY_HIPS * sw, 0, st.root[3], st.root[4] + 0.3 * yaw * gBody - 2 * sh + ft,
			st.root[5] + lean - 0.1 * fs, roll },
		-- The head keeps its line through the breath and the tipped torso; a fidget's look is in
		-- world terms (the torso's own turn is taken out of it).
		neck = { st.neck[1] - 0.6 * lean + pitch + lookPitch, st.neck[2] + yaw * gHead - 0.3 * yaw * gBody + lookYaw - ft,
			-0.6 * roll },
		rarm = { st.rarm[1] + 2.2 * barm + fs, ff, st.rarm[3] + 1.6 * barm + hang - 0.3 * ff,
			st.rarm[4] + 4 * bblade + fw },
		larm = { st.larm[1] + 2 * barm, 0, st.larm[3] - 1.6 * barm + hang },
		lfoot = st.lfoot,
		rfoot = st.rfoot,
		-- Shoulders rise on the inhale (rig studs): right, left.
		lift = { BREATH_LIFT * (bsh + 1), BREATH_LIFT * (bsh + 1) },
	}
end

local CHANNELS = { "root", "neck", "rarm", "larm", "lfoot", "rfoot" }

local function restPose()
	local pose = {}
	for _, name in ipairs(CHANNELS) do
		pose[name] = table.clone(POSES.rest[name])
	end
	return pose
end

-- pose += extra * weight, channel by channel.
local function addPose(pose, extra, weight: number)
	for _, name in ipairs(CHANNELS) do
		local a, b = pose[name], extra[name]
		for i = 1, #a do
			a[i] += (b[i] or 0) * weight
		end
	end
	return pose
end

-- ==============================================================================
-- Channels -> Motor6D Transforms
-- ==============================================================================
-- Rigid R6 leg from `hip` (rig space) aimed at the foot target; returns the hip Transform in
-- torso space. The foot keeps pointing along `yaw` so planted feet do not swivel with the torso.
local function legTransform(torsoCF: CFrame, hip: Vector3, foot: Vector3, yaw: number): CFrame
	local down = foot - hip
	if down.Magnitude < 1e-3 then
		return CFrame.identity
	end
	local up = -down.Unit
	local look = CFrame.Angles(0, rad(yaw), 0).LookVector
	local right = look:Cross(up)
	if right.Magnitude < 1e-3 then
		return CFrame.identity
	end
	right = right.Unit
	local legRot = CFrame.fromMatrix(Vector3.zero, right, up)
	return torsoCF.Rotation:Inverse() * legRot
end

-- Transforms for every joint from a channel pose. `s` is the rig's scale.
-- `pose.spin` (optional, degrees) turns the whole body, feet included, about the root's vertical
-- axis: the notice uses it to face the body somewhere other than the root while it turns.
function EnemyAnimator.transforms(pose, s: number)
	local r = pose.root
	local spin = pose.spin or 0
	local spinCF = CFrame.Angles(0, rad(spin), 0)
	-- The body turns and leans about the hips, not the torso's centre.
	local hipPivot = CFrame.new(0, -s, 0)
	local torsoCF = spinCF * CFrame.new(r[1] * s, r[2] * s, r[3] * s)
		* hipPivot * euler(r[5], r[4], r[6]) * hipPivot:Inverse()
	local out = {}
	out.RootJoint = torsoCF
	out.Neck = euler(pose.neck[1], pose.neck[2], pose.neck[3])
	local a = pose.rarm
	out["Right Shoulder"] = euler(a[1], a[2], a[3])
	out.Grip = CFrame.Angles(rad(a[4]), 0, 0)
	local b = pose.larm
	out["Left Shoulder"] = euler(b[1], b[2], b[3])
	-- `pose.lift` (optional, rig studs): the shoulders raised, as on an inhale.
	local lift = pose.lift
	if lift then
		out["Right Shoulder"] = CFrame.new(0, lift[1] * s, 0) * out["Right Shoulder"]
		out["Left Shoulder"] = CFrame.new(0, lift[2] * s, 0) * out["Left Shoulder"]
	end
	local legs = { { "Left Hip", -0.5, pose.lfoot, 0.3 }, { "Right Hip", 0.5, pose.rfoot, 0 } }
	local function footAt(side)
		local f = side[3]
		return spinCF * Vector3.new((side[2] + f[1]) * s, -3 * s + f[3] * s, f[2] * s)
	end
	-- `pose.seat` (optional, 0..1): seat the hips down onto the legs. An R6 leg is one rigid 2-stud
	-- block, so a wide or staggered stance (or hips carried over one leg) would leave both feet
	-- sunk into the ground; this lowers (or raises) the torso until the more upright leg stands
	-- exactly on its foot, and the other one, angled out, bears less weight.
	local seat = pose.seat
	if seat and seat > 0 then
		local shortest = math.huge
		for _, side in ipairs(legs) do
			local hip = (torsoCF * CFrame.new(side[2] * s, -s, 0)).Position
			shortest = math.min(shortest, (footAt(side) - hip).Magnitude)
		end
		torsoCF = CFrame.new(0, (2 * s - shortest) * seat, 0) * torsoCF
		out.RootJoint = torsoCF
	end
	for _, side in ipairs(legs) do
		local hip = (torsoCF * CFrame.new(side[2] * s, -s, 0)).Position
		out[side[1]] = legTransform(torsoCF, hip, footAt(side), r[4] * side[4] + spin)
	end
	return out
end

-- ==============================================================================
-- Run: a stride cycle pinned to the ground
-- ==============================================================================
-- Driven only by how far the rig's root actually travelled (its replicated position), never by
-- WalkSpeed or the AI, so it matches whatever the server's movement does. Each R6 leg is one rigid
-- block from the hip, so the stride is built the way a rigid-legged runner has to move:
--   * stance: the foot is pinned to a world point from touch-down to lift-off, so it cannot slide;
--     the hips ride over the planted leg (lowest at touch-down and lift-off, highest over the foot)
--   * swing: the leg kicks back past lift-off, whips through under the body while both feet are
--     off the ground (the hips rise through the flight), reaches forward, then paws back down to
--     meet the ground at the contact angle
-- Cadence rises gently with speed, and the share of each step spent on the ground is whatever keeps
-- the planted foot between +contact and -contact degrees at the current speed, so stride length
-- always matches ground speed. The torso leans into the run (further while accelerating), twists
-- against the legs, the free arm counter-swings with the opposite leg, the sword arm swings less,
-- and the head counters the lean and twist so it stays level. The first step pushes off the foot
-- already under the body. On arrival the swinging foot is put down where it is and the body skids:
-- it carries forward over its planted feet, leans back and dips, kicking up dust, while the run
-- pose hands back to whatever comes next (the swing, the idle).
local RUN_START = 1.5 -- [TUNING] studs/s of root travel that starts the cycle
local RUN_STOP = 0.6 -- [TUNING] studs/s; below this for RUN_STOP_TIME the rig has arrived
local RUN_STOP_TIME = 0.1 -- long enough to ride out a late replication packet mid-run
local RUN_SKID_AFTER = 0.35 -- seconds of running before an arrival skids
local RUN_TELEPORT = 4 -- studs in one frame: a teleport (PivotTo), not a step
local RUN_SMOOTH = 16 -- 1/s: speed estimate smoothing (also shapes the acceleration lean)
local RUN_IN = 0.07 -- seconds to blend into the run
local RUN_OUT = 0.2 -- seconds to hand the run pose back once stopped
local RUN_CYCLE = 0.6 -- [TUNING] seconds per stride (two steps) at RUN_REF rig-studs/s
local RUN_REF = 12
local RUN_CONTACT = 21 -- [TUNING] leg degrees from vertical at touch-down and lift-off, full run
local RUN_KICK = 17 -- degrees the leg swings back past lift-off
local RUN_REACH = 15 -- degrees the leg reaches forward past contact before pawing back down
local RUN_BOB = 0.34 -- rig studs the hips rise through each flight
local RUN_LEAN = 13 -- degrees of forward lean at a full run
local RUN_ACCEL_LEAN = 9 -- extra degrees leaning into a start
local LEG = 2 -- rig studs, hip to sole

-- Skid on arrival (additive, seconds from the stop; scaled by how fast it was running).
local BRACE_TIME = 0.42
local BRACE = {
	back = { { 0, 0 }, { 0.08, 14, "outCubic" }, { 0.2, 9, "inOutCubic" }, { BRACE_TIME, 0, "inOutCubic" } },
	dip = { { 0, 0 }, { 0.07, -0.32, "outCubic" }, { 0.36, 0, "inOutCubic" } },
	carry = { { 0, 0 }, { 0.07, -0.34, "outCubic" }, { 0.32, 0, "inOutCubic" } },
	arms = { { 0, 0 }, { 0.09, 1, "outCubic" }, { BRACE_TIME, 0, "inOutCubic" } },
}

local function newLeg(side: number, offset: number)
	return {
		side = side, off = offset, stance = false, anchor = nil :: Vector3?, theta = 0, theta0 = 0,
		qLift = 0, fromRest = true, forced = false, foot = Vector3.new(side, -3, 0),
	}
end

function EnemyAnimator.newRun(position: Vector3)
	return {
		P = 0, w = 0, speed = 0, moving = false, still = 0, runT = 0, lean = 0, rootY = 0, a = 0,
		liftP = 0, liftY = 0, lastPos = position, dir = Vector3.new(0, 0, -1),
		stopT = nil :: number?, stopK = 0, skid = false,
		legs = { newLeg(-0.5, 0), newLeg(0.5, 0.5) },
	}
end

-- Rig studs the sole's centre sits above the ground when a block leg tilted `theta` degrees
-- stands on its low edge (the sole is one rig stud long).
local function soleEdge(theta: number): number
	return 0.5 * math.abs(math.sin(rad(theta)))
end

local function liftLeg(run, leg, q: number)
	leg.stance = false
	leg.theta0 = leg.theta
	leg.qLift = q
	leg.fromRest = leg.theta > -6 -- a first step from a stand swings straight through, no kick
	run.liftP = run.P
	run.liftY = run.rootY
end

-- Both feet down where they stand (the rig's current rig-space feet), pinned to the world.
local function plantAll(run, cf: CFrame, s: number)
	for _, leg in ipairs(run.legs) do
		leg.stance = true
		leg.forced = false
		leg.anchor = cf:PointToWorldSpace(Vector3.new(leg.foot.X, -3 * s, leg.foot.Z))
	end
end

-- Advances the run by one frame from the root's world CFrame and returns the channel pose (full
-- weight; blend it by run.w) or nil when the run has fully handed back. `s` is the rig's scale.
function EnemyAnimator.runStep(run, cf: CFrame, s: number, dt: number)
	local pos = cf.Position
	local planar = (pos - run.lastPos) * Vector3.new(1, 0, 1)
	run.lastPos = pos
	if dt <= 0 then
		return nil
	end
	if planar.Magnitude > RUN_TELEPORT * s then
		-- Moved by a teleport: start over from a stand.
		local fresh = EnemyAnimator.newRun(pos)
		for k, v in pairs(fresh) do
			run[k] = v
		end
		return nil
	end
	local raw = planar.Magnitude / dt
	local before = run.speed
	run.speed += (raw - run.speed) * math.min(1, dt * RUN_SMOOTH)
	if raw > 0.5 then
		run.dir = planar.Unit
	end
	if run.stopT then
		run.stopT += dt
		if run.stopT > BRACE_TIME then
			run.stopT = nil
		end
	end

	if run.moving then
		run.runT += dt
		run.still = if raw < RUN_STOP then run.still + dt else 0
		if run.still >= RUN_STOP_TIME then
			-- Arrived: the swinging foot goes down where it is, and the body skids over both.
			run.moving = false
			plantAll(run, cf, s)
			run.stopK = if run.runT >= RUN_SKID_AFTER then clamp((before / s - 3) / 7, 0, 1) else 0
			run.stopT = if run.stopK > 0.05 then 0 else nil
			run.skid = run.stopK > 0.35
		end
	elseif raw > RUN_START then
		run.moving = true
		run.still = 0
		run.runT = 0
		run.stopT = nil
		if run.w < 0.05 then
			-- From a stand: both feet start where they are, the left planted under the body (it
			-- takes the first push) and the right about to swing through.
			run.P = 0.12 -- the right leg's first swing is a short one, so the first stride comes fast
			run.rootY = 0
			for _, leg in ipairs(run.legs) do
				leg.foot = Vector3.new(leg.side * s, -3 * s, 0)
				leg.theta = 0
			end
			plantAll(run, cf, s)
			-- The right leg leaves the ground on the very first frame of movement, whatever the
			-- speed estimate says yet, so the body never glides on two planted feet.
			local right = run.legs[2]
			liftLeg(run, right, (run.P + right.off) % 1)
			right.forced = true
		else
			plantAll(run, cf, s)
		end
	end

	run.w = clamp(run.w + (if run.moving then dt / RUN_IN else -dt / RUN_OUT), 0, 1)
	if run.w <= 0 then
		return nil
	end

	-- Gait for the current speed (rig studs per second).
	local v = run.speed / s
	if run.moving then
		run.a = clamp((v - 2) / 7, 0, 1)
	end
	local a = run.a
	local cycle = clamp(RUN_CYCLE * (RUN_REF / math.max(v, 1)) ^ 0.4, 0.46, 1.1)
	local thetaC = 13 + (RUN_CONTACT - 13) * a
	local duty = clamp(2 * LEG * math.sin(rad(thetaC)) / math.max(v * cycle, 0.01), 0.14, 0.62)
	if run.moving then
		run.P += dt / cycle * clamp(v / 3, 0.35, 1)
		-- Leaning into a start: the harder it is gaining speed, the further forward.
		local accel = (run.speed - before) / dt / s
		local target = clamp(accel * 0.1, 0, RUN_ACCEL_LEAN)
		run.lean += (target - run.lean) * math.min(1, dt * 10)
	else
		run.lean += (0 - run.lean) * math.min(1, dt * 10)
	end

	-- Stance and swing, per leg.
	local legs = run.legs
	local ground = -3 * s
	for _, leg in ipairs(legs) do
		local q = (run.P + leg.off) % 1
		if run.moving then
			local want = q < duty
			if leg.forced then
				if want then
					want = false
				else
					leg.forced = false
				end
			end
			if want and not leg.stance then
				-- Touch-down where the swinging foot meets the ground.
				leg.stance = true
				leg.anchor = cf:PointToWorldSpace(Vector3.new(leg.foot.X, ground, leg.foot.Z))
			elseif not want and leg.stance then
				liftLeg(run, leg, q)
			end
		end
		if leg.stance then
			local r = cf:PointToObjectSpace(leg.anchor)
			leg.theta = math.deg(math.asin(clamp(-r.Z / (LEG * s), -0.97, 0.97)))
			-- A tilted block leg rocks on its heel (touch-down) and its toe (push-off): the sole's
			-- centre rides up so the low edge, not the centre, stays on the pinned spot.
			leg.foot = Vector3.new(r.X, ground + soleEdge(leg.theta) * s, r.Z)
			-- A foot left far behind (a burst of speed) or off to the side (a sharp turn) lifts early.
			if run.moving and (leg.theta < -(thetaC + 14) or math.abs(r.X - leg.side * s) > 1.2 * s) then
				liftLeg(run, leg, q)
				leg.forced = q < duty
			end
		end
		if not leg.stance and run.moving then
			local g = clamp((q - leg.qLift) / math.max(1 - leg.qLift, 0.05), 0, 1)
			local th0 = leg.theta0
			local kick = if leg.fromRest then th0 else math.max(math.min(th0, -thetaC) - RUN_KICK * a, -42)
			local reach = thetaC + RUN_REACH * a
			leg.theta = if g < 0.1 then th0 + (kick - th0) * EASE.outQuad(g / 0.1)
				elseif g < 0.45 then kick + (reach - kick) * EASE.inOutCubic((g - 0.1) / 0.35)
				else reach + (thetaC - reach) * EASE.inOutQuad((g - 0.45) / 0.55)
		end
	end

	-- Hips: carried by the planted leg; in flight, a rise between lift-off and the next touch-down.
	local need = nil
	for _, leg in ipairs(legs) do
		if leg.stance then
			local dx, dz = (leg.foot.X - leg.side * s) / s, leg.foot.Z / s
			local y = math.sqrt(math.max(LEG * LEG - dx * dx - dz * dz, 1)) - LEG + (leg.foot.Y - ground) / s
			need = if need then math.max(need, y) else y
		end
	end
	if need then
		run.rootY = need
	elseif run.moving then
		local nextP = math.huge
		for _, leg in ipairs(legs) do
			nextP = math.min(nextP, run.P + 1 - (run.P + leg.off) % 1)
		end
		local span = nextP - run.liftP
		local f = if span > 1e-3 then clamp((run.P - run.liftP) / span, 0, 1) else 1
		local landY = LEG * math.cos(rad(thetaC)) - LEG + soleEdge(thetaC)
		run.rootY = run.liftY + (landY - run.liftY) * f + 4 * RUN_BOB * a * f * (1 - f)
	end
	local rootY = run.rootY

	-- Swinging feet hang off the hip at the leg's angle (only the direction matters to the aim).
	for _, leg in ipairs(legs) do
		if not leg.stance then
			local th = rad(leg.theta)
			leg.foot = Vector3.new(leg.side * s, (-1 + rootY) * s - LEG * s * math.cos(th), -LEG * s * math.sin(th))
		end
	end

	local left, right = legs[1], legs[2]
	local lean = RUN_LEAN * a + run.lean
	-- Shoulders turn against the hips: left leg forward brings the right (sword) shoulder forward.
	local yaw = 0.13 * (left.theta - right.theta)
	-- The torso tips a little over whichever foot is planted.
	local roll = ((if left.stance then 2.5 else 0) - (if right.stance then 2.5 else 0)) * a
	local function footChannel(leg)
		return { leg.foot.X / s - leg.side, leg.foot.Z / s, leg.foot.Y / s + 3 }
	end
	return {
		root = { 0, rootY, 0, yaw, -lean, roll },
		neck = { lean * 0.65, -yaw * 0.8, -roll },
		-- Arms pump with the opposite leg: the free arm ~30 degrees each way, the sword arm ~25 (the
		-- wrist trailing the blade a little behind it), carried forward with the blade angled down.
		rarm = { 14 + 0.7 * left.theta * a, 0, 9, -16 + 0.25 * left.theta * a },
		larm = { 8 + 0.85 * right.theta * a, 0, -9 - 3 * a },
		lfoot = footChannel(left),
		rfoot = footChannel(right),
	}
end

-- The skid on arrival, added on top of whatever the body does next.
function EnemyAnimator.sampleBrace(t: number, k: number)
	local back, arms = curve(BRACE.back, t) * k, curve(BRACE.arms, t) * k
	return {
		root = { 0, curve(BRACE.dip, t) * k, curve(BRACE.carry, t) * k, 0, back, 0 },
		neck = { -back * 0.5, 0, 0 },
		rarm = { 10 * arms, 0, 6 * arms, 0 },
		larm = { 22 * arms, 0, -10 * arms },
		lfoot = { 0, 0, 0 },
		rfoot = { 0, 0, 0 },
	}
end

-- ==============================================================================
-- Notice: the moment an enemy spots a player, flowing into the charge
-- ==============================================================================
-- Triggered by the server's "EnemyAlert" attribute (server time of the spot), set where the AI
-- switches into CHASE and cleared when the chase ends. The server issues its first chase MoveTo one
-- AI tick (~0.15 s) after the switch, so the whole beat below overlaps the chase start: nothing
-- waits for it and the root starts moving exactly when it did before. Beats, seconds from the spot:
--   0.00-0.07  the head snaps toward the player (up to HEAD_LEAD degrees ahead of the body, a small
--              overshoot) while the body is still facing where it was; the lemon "!" pops above it
--   0.03-0.07  startle: the torso flinches back ~12 degrees, the hips crouch, the arms jerk out
--   0.06-0.20  a small hop-turn: the body follows the head round to the player in the air (the feet
--              leave the ground, so the turn never skates) while the weapon snaps up into guard
--   0.19-0.45  it lands in guard and drives forward out of the flinch into the run, which pushes off
--              with the weapon held up and ready (not swinging at the hip) for the whole chase
-- The body's facing is animated independently of the root's (a whole-body spin about the root),
-- then handed back to the root, which the server's Humanoid has turned to the player by then.
local NOTICE_ATTRIBUTE = "EnemyAlert"
local NOTICE_DURATION = 1.25 -- seconds; the "!" is gone by then
local NOTICE_FRESH = 0.5 -- [TUNING] a spot older than this when first seen gets no beat (streamed in)
local NOTICE_RANGE = 110 -- [TUNING] studs from the camera; farther rigs skip the beat and the "!"
local HEAD_LEAD = 55 -- [TUNING] most degrees the head gets ahead of the body
local GUARD_IN = 0.15 -- seconds to raise the guard when the alert arrives without a beat
local GUARD_OUT = 0.35 -- seconds to lower it once the chase ends

local NOTICE = {
	-- Share of the turn: the head's lead (snaps, overshoots, settles) and the body's follow.
	head = { { 0, 0 }, { 0.07, 1.12, "outCubic" }, { 0.13, 1, "inOutQuad" }, { 0.8, 1, "linear" },
		{ 1.1, 0, "inOutQuad" } },
	body = { { 0, 0 }, { 0.06, 0 }, { 0.2, 1, "inOutCubic" } },
	-- The body's own facing hands back to the root's once the turn is done.
	hold = { { 0, 1 }, { 0.42, 1 }, { 0.66, 0, "inOutQuad" } },
	-- Hips: a crouch, the hop, the landing's dip, then up into the push-off (rig studs).
	rise = { { 0, 0 }, { 0.05, -0.18, "outQuad" }, { 0.12, 0.26, "outQuad" }, { 0.195, -0.22, "inQuad" },
		{ 0.3, -0.07, "outQuad" }, { 0.46, 0, "inOutQuad" } },
	-- Flinch back from the player, then drive forward into the charge (rig studs, + is back).
	back = { { 0, 0 }, { 0.07, 0.28, "outCubic" }, { 0.19, 0.16, "linear" }, { 0.34, -0.16, "inOutQuad" },
		{ 0.56, 0, "inOutQuad" } },
	-- Torso: rears back in surprise, then pitches forward into the push-off (degrees, + is back).
	lean = { { 0, 0 }, { 0.06, 12, "outCubic" }, { 0.16, 9, "linear" }, { 0.31, -9, "inOutQuad" },
		{ 0.62, -3, "inOutQuad" }, { 0.95, 0, "inOutQuad" } },
	-- Head: chin up in surprise (lagging the torso a frame), then down and locked on as it charges.
	headPitch = { { 0, 0 }, { 0.07, 9, "outCubic" }, { 0.2, 5, "linear" }, { 0.36, -8, "inOutQuad" },
		{ 0.95, 0, "inOutQuad" } },
	-- Weapon to guard (0..1): snaps up with a little overshoot once the flinch has fired.
	guard = { { 0, 0 }, { 0.045, 0 }, { 0.16, 1, "outBack" } },
	flinch = { { 0, 0 }, { 0.04, 1, "outCubic" }, { 0.13, 0, "inOutQuad" } },
	-- The "!": pops (scale), floats up a little (studs) and fades at the end.
	pop = { { 0, 0 }, { 0.025, 0 }, { 0.095, 1.4, "outCubic" }, { 0.16, 0.9, "inOutQuad" },
		{ 0.23, 1, "inOutQuad" } },
	float = { { 0.025, -0.3 }, { 0.2, 0.05, "outCubic" }, { NOTICE_DURATION, 0.25, "linear" } },
	fade = { { 0, 0 }, { 0.95, 0 }, { NOTICE_DURATION, 1, "inQuad" } },
	-- The surprise ticks around it: shoot out (0..1 of their travel), then fade.
	burst = { { 0.04, 0 }, { 0.16, 1, "outCubic" } },
	burstFade = { { 0, 0 }, { 0.14, 0 }, { 0.34, 1, "inQuad" } },
}

-- Guard: sword raised in front, blade angled up and forward (~45 degrees), free hand up and in.
-- Carry: the guard for running, the arm raised further to make up for the run's forward lean so
-- the blade still points up and ahead (~35 degrees) instead of flattening at the hip.
local GUARD = { rarm = { 58, 16, 6, -14 }, larm = { 42, -16, -8 } }
local CARRY = { rarm = { 72, 14, 8, -12 }, larm = { 46, -14, -10 } }

-- Additive channels of the startle at `t` seconds (the turn itself is applied as a spin).
function EnemyAnimator.sampleNotice(t: number)
	local flinch = curve(NOTICE.flinch, t)
	local lift = arc(t, 0.065, 0.19, 0.28) -- the hop: both feet leave the ground
	return {
		root = { 0, curve(NOTICE.rise, t), curve(NOTICE.back, t), 0, curve(NOTICE.lean, t), 0 },
		neck = { curve(NOTICE.headPitch, t), 0, 0 },
		rarm = { -6 * flinch, 0, 14 * flinch, 0 },
		larm = { -6 * flinch, 0, -14 * flinch },
		lfoot = { 0, 0, lift },
		rfoot = { 0, 0, lift },
	}
end

-- Shortest signed difference a - b, degrees, in (-180, 180].
local function angleDiff(a: number, b: number): number
	return (a - b + 180) % 360 - 180
end

-- World yaw of a flat direction, degrees, in the rig's convention (+ turns left, 0 faces -Z).
local function yawOf(v: Vector3): number
	return math.deg(math.atan2(-v.X, -v.Z))
end

-- The lemon "!" over the head: the game's chunky display type (FredokaOne, heavy dark outline)
-- in the Legendary lemon gradient, with four surprise ticks shooting out around it. Local-only.
local MARKER_TICKS = { -68, -34, 34, 68 } -- degrees from straight up
local function noticeMarker(state)
	local head = state.model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return nil
	end
	local s = state.scale or 1
	local tile = PanelChrome.RARITY_TILE.Legendary
	local gui = Instance.new("BillboardGui")
	gui.Name = "NoticeMarker"
	gui.Size = UDim2.fromScale(3.2 * s, 3.2 * s) -- studs, so it scales with the rig in view
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.9 * s, 0)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.MaxDistance = NOTICE_RANGE
	gui.ResetOnSpawn = false
	gui.Adornee = head
	local holder = Instance.new("Frame")
	holder.Name = "Pop"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local scaler = Instance.new("UIScale")
	scaler.Scale = 0
	scaler.Parent = holder
	local label = Instance.new("TextLabel")
	label.Name = "Bang"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.72, 0.72)
	label.Font = PanelChrome.DISPLAY_FONT
	label.Text = "!"
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = holder
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(tile.top, tile.bottom)
	gradient.Rotation = 90
	gradient.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = PanelChrome.BRIGHT.Outline
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = 3
	stroke.Parent = label
	local ticks = {}
	for i, angle in ipairs(MARKER_TICKS) do
		local mark = Instance.new("Frame")
		mark.Name = "Tick" .. i
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Size = UDim2.fromScale(0.07, 0.2)
		mark.Rotation = angle
		mark.BackgroundColor3 = PanelChrome.BRIGHT.Gold
		mark.BorderSizePixel = 0
		mark.Parent = holder
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = mark
		local tickStroke = Instance.new("UIStroke")
		tickStroke.Color = PanelChrome.BRIGHT.Outline
		tickStroke.Thickness = 2
		tickStroke.Parent = mark
		ticks[i] = { mark, tickStroke, rad(angle) }
	end
	gui.Parent = head
	return { gui = gui, scaler = scaler, label = label, stroke = stroke, ticks = ticks }
end

local function clearMarker(state)
	if state.marker then
		state.marker.gui:Destroy()
		state.marker = nil
	end
end

local function stepMarker(state, t: number)
	local m = state.marker
	if not m then
		return
	end
	if t >= NOTICE_DURATION then
		clearMarker(state)
		return
	end
	local s = state.scale or 1
	local fade = curve(NOTICE.fade, t)
	m.scaler.Scale = curve(NOTICE.pop, t)
	m.gui.StudsOffsetWorldSpace = Vector3.new(0, (2.9 + curve(NOTICE.float, t)) * s, 0)
	m.label.TextTransparency = fade
	-- The outline keeps its weight at any distance: a share of the marker's size on screen.
	local px = m.gui.AbsoluteSize.Y
	m.stroke.Thickness = math.max(1.5, px * 0.035)
	m.stroke.Transparency = fade
	local out, gone = curve(NOTICE.burst, t), math.max(fade, curve(NOTICE.burstFade, t))
	for _, entry in ipairs(m.ticks) do
		local mark, a = entry[1], entry[3]
		-- They shoot out, then shrink away (fading only at the very end, so they never go grey).
		local r = 0.3 + 0.17 * out + 0.05 * gone
		mark.Position = UDim2.fromScale(0.5 + r * math.sin(a), 0.5 - r * math.cos(a))
		mark.Size = UDim2.fromScale(0.07 * (1 - 0.4 * gone), 0.2 * (0.5 + 0.5 * out) * (1 - gone))
		local hidden = if t < 0.04 then 1 else clamp((gone - 0.7) / 0.3, 0, 1)
		mark.BackgroundTransparency = hidden
		entry[2].Thickness = math.max(1, px * 0.02)
		entry[2].Transparency = hidden
	end
end

-- The nearest player's character to `position` (the one the server's scan picked: it takes the
-- nearest living player in aggro range).
local function nearestCharacter(position: Vector3): Model?
	local best, bestDistance = nil, math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = character, distance
			end
		end
	end
	return best
end

-- ==============================================================================
-- Client loop
-- ==============================================================================
local JOINTS = { "RootJoint", "Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip", "Grip" }

local rigs = {} -- model -> state

local function resolveJoints(state)
	local model = state.model
	local hrp = model:FindFirstChild("HumanoidRootPart")
	local torso = model:FindFirstChild("Torso")
	local rightArm = model:FindFirstChild("Right Arm")
	if not (hrp and torso) then
		return false
	end
	state.hrp = hrp
	state.scale = torso.Size.Y / 2
	state.joints = {
		RootJoint = hrp:FindFirstChild("RootJoint"),
		Neck = torso:FindFirstChild("Neck"),
		["Right Shoulder"] = torso:FindFirstChild("Right Shoulder"),
		["Left Shoulder"] = torso:FindFirstChild("Left Shoulder"),
		["Right Hip"] = torso:FindFirstChild("Right Hip"),
		["Left Hip"] = torso:FindFirstChild("Left Hip"),
		Grip = rightArm and rightArm:FindFirstChild("Grip"),
	}
	state.run = nil -- the run starts over from the rig's current position
	state.trail = nil
	local sword = model:FindFirstChild("Sword")
	if sword and sword:IsA("BasePart") then
		-- Swing trail: a thin local-only streak off the outer blade, lit only through the cut
		-- itself so the arc reads without hiding the body behind it.
		local length = sword.Size.Z
		local a0 = Instance.new("Attachment")
		a0.Name = "SwingTrailBase"
		a0.Position = Vector3.new(0, 0, 0.3 * length)
		a0.Parent = sword
		local a1 = Instance.new("Attachment")
		a1.Name = "SwingTrailTip"
		a1.Position = Vector3.new(0, 0, 0.49 * length)
		a1.Parent = sword
		local trail = Instance.new("Trail")
		trail.Name = "SwingTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.1
		trail.MinLength = 0
		trail.FaceCamera = false
		trail.LightEmission = 0.7
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 215, 255))
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.WidthScale = NumberSequence.new(1, 0.25)
		trail.Enabled = false
		trail.Parent = sword
		state.trail = trail
	end
	return true
end

-- The chase started (a fresh spot plays the notice beat) or ended (the guard comes down).
local function onAlert(state)
	local value = state.model:GetAttribute(NOTICE_ATTRIBUTE)
	if typeof(value) ~= "number" then
		state.alert = false
		return
	end
	state.alert = true
	state.noticeT = nil
	local age = workspace:GetServerTimeNow() - value
	local hrp = state.hrp
	local camera = workspace.CurrentCamera
	if age > NOTICE_FRESH or not hrp or state.deathT or not camera
		or (hrp.Position - camera.CFrame.Position).Magnitude > NOTICE_RANGE then
		return -- seen late or far away: straight to the ready carry, no beat
	end
	state.noticeT = 0
	state.guardFrom = state.guardW or 0
	state.noticeTarget = nearestCharacter(hrp.Position)
	state.noticeFrom = yawOf(hrp.CFrame.LookVector)
	state.noticeFace = state.noticeFrom
	clearMarker(state)
	state.marker = noticeMarker(state)
end

-- A scheduled idle beat, `value` seconds after the change arrives: see EnemyAnimator.cueIdle. Only
-- the Studio showcase sets it, in the same replication stream as its clapperboard, so the beat
-- lands at a fixed offset from the flash whatever the client's clock sync is.
local IDLE_CUE_ATTRIBUTE = "EnemyIdleCue"
local function onIdleCue(state)
	local value = state.model:GetAttribute(IDLE_CUE_ATTRIBUTE)
	if typeof(value) == "number" then
		EnemyAnimator.cueIdle(state.idle, os.clock() + value)
	end
end

local function onAttack(state)
	local value = state.model:GetAttribute(ATTACK_ATTRIBUTE)
	if typeof(value) == "Vector2" and value.Y > 0 then
		state.attackStart = os.clock()
		state.windup = value.Y
	end
end

-- The player whose blow this was: the nearest living character in sword reach of the enemy.
local ATTACKER_RANGE = 16 -- [TUNING] studs; beyond every sword's reach plus its range bonus
local function findAttacker(position: Vector3): Model?
	local best, bestDistance = nil, ATTACKER_RANGE
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = character, distance
			end
		end
	end
	return best
end

-- Hit-stop on the attacker's side: the local player's own body holds its pose for a few frames
-- at contact, so the blade visibly bites instead of passing through.
--
-- The hold itself now lives in ReplicatedStorage/Hitstop, because the attacker's client learns
-- about the same hit twice -- here, from this rig's replicated Health dropping, and from the
-- server's HitlagEffect remote (ComboVFX), which is the one that knows the combo index. Hitstop
-- takes the longer of the two and holds once; whichever arrives first snapshots the pose. It
-- also stops the swing clip's CLOCK, which this could not: pinning the joints while the clip ran
-- on handed the blade back a third of the way further round the arc.
local function freezeAttacker(character: Model, hold: number)
	Hitstop.freeze(character, hold)
end

-- One bright slash streak across the cut and a burst where the steel met the body. Local-only
-- parts, tweened and destroyed within a quarter second.
local function fxPart(shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Size = size
	p.CFrame = cf
	p.Parent = workspace
	return p
end

-- `contact` is the server's own answer to "where did the blade meet this body, and which way was
-- it going" (SwordSystem publishes it on the model as "HitBlade" in the same frame as the
-- damage). With it, the streak is laid ON the steel along the line the steel cut; without it --
-- the unarmed path, or a hit from anything that does not carry a blade -- it falls back to the
-- diagonal across the torso this used to draw unconditionally. That fallback was the bug: a
-- burst at the middle of a model reads as the body lighting up, a burst on the blade reads as
-- the blade biting, and the two are 2 studs apart on an enemy the size of a player.
local function slashFx(torso: BasePart, blow: Vector3, contact: CFrame?)
	local up = Vector3.yAxis
	local side = blow:Cross(up)
	if side.Magnitude < 1e-3 then
		side = Vector3.xAxis
	end
	side = side.Unit
	local centre = torso.Position + up * 0.2 - blow * 0.6
	-- Diagonal, high on the blade side to low on the far side, tipped along the blow so it still
	-- reads as a cut from a camera side-on to the fight.
	local axis = (up * 0.8 + side * 0.45 + blow * 0.55).Unit
	if contact then
		centre = contact.Position
		axis = contact.LookVector
	end
	-- A cut coming straight down is parallel to lookAt's default up vector, which would make the
	-- whole streak NaN and leave an invisible part in the world.
	local cf = CFrame.lookAt(centre, centre + axis,
		if math.abs(axis.Y) > 0.95 then Vector3.zAxis else up)
	local core = fxPart(Enum.PartType.Block, Vector3.new(0.14, 0.14, 1.2), cf, Color3.new(1, 1, 1), 0)
	local glow = fxPart(Enum.PartType.Block, Vector3.new(0.5, 0.5, 1.2), cf, Color3.fromRGB(255, 70, 60), 0.35)
	local burst = fxPart(Enum.PartType.Ball, Vector3.one * 0.6, CFrame.new(centre), Color3.fromRGB(255, 245, 225), 0.1)
	local grow = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fade = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.05)
	TweenService:Create(core, grow, { Size = Vector3.new(0.14, 0.14, 6.5) }):Play()
	TweenService:Create(glow, grow, { Size = Vector3.new(0.5, 0.5, 6) }):Play()
	TweenService:Create(core, fade, { Transparency = 1, Size = Vector3.new(0.04, 0.04, 7) }):Play()
	TweenService:Create(glow, fade, { Transparency = 1 }):Play()
	TweenService:Create(burst, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * 3.4, Transparency = 1 }):Play()
	task.delay(0.25, function()
		core:Destroy()
		glow:Destroy()
		burst:Destroy()
	end)
end

-- Dust kicked up at the feet as the knockback drives them back: puffs that travel with the slide
-- along the blow, swell and fade. Local-only, destroyed within half a second.
local DUST = Color3.fromRGB(214, 202, 184)
local function dustFx(hrp: BasePart, blow: Vector3, s: number)
	local right = hrp.CFrame.RightVector
	local feet = hrp.Position - Vector3.yAxis * 2.8 * s
	local slide = TweenInfo.new(0.13, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	local fade = TweenInfo.new(0.36, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.08)
	local puffs = {}
	for i, side in ipairs({ -0.55, 0.55, 0 }) do
		local at = feet + right * side * s + blow * (0.2 * i - 0.3)
		local p = fxPart(Enum.PartType.Ball, Vector3.one * 0.55 * s, CFrame.new(at), DUST, 0.25)
		p.Material = Enum.Material.SmoothPlastic
		local to = at + blow * (1.3 + 0.3 * i) * s + Vector3.yAxis * 0.25 * s
		TweenService:Create(p, slide, { CFrame = CFrame.new(to) }):Play()
		TweenService:Create(p, fade, {
			Size = Vector3.one * (1.9 + 0.35 * i) * s,
			Transparency = 1,
			CFrame = CFrame.new(to + blow * 0.5 * s + Vector3.yAxis * 0.55 * s),
		}):Play()
		puffs[i] = p
	end
	task.delay(0.5, function()
		for _, p in ipairs(puffs) do
			p:Destroy()
		end
	end)
end

local function clearFlash(state)
	if state.flash then
		state.flash:Destroy()
		state.flash = nil
	end
end

-- How far the shove is bent from "away from the attacker" toward the way the blade was travelling
-- through the body (the server's "HitBlade"), as a share added to the unit away-vector. Away
-- stays the larger part: a cut's travel at contact is mostly ACROSS the attacker's front, and a
-- victim shoved purely sideways reads as stepping out of the way rather than as hit.
local BLOW_ALONG_BLADE = 0.45 -- [TUNING]

-- The blow's direction: world (flat, unit) and in the rig's own X/Z, plus the attacker, if found.
-- With `contact` (where the blade met the body, facing its travel), the blow is bent toward the
-- travel, so the body goes the way the steel was going rather than straight back every time.
local function blowOf(hrp: BasePart, contact: CFrame?): (Vector3, number, number, Model?)
	local attacker = findAttacker(hrp.Position)
	local attackerRoot = attacker and attacker:FindFirstChild("HumanoidRootPart")
	local blow = if attackerRoot then (hrp.Position - attackerRoot.Position) * Vector3.new(1, 0, 1) else Vector3.zero
	if blow.Magnitude < 1e-3 then
		blow = -hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	if blow.Magnitude < 1e-3 then
		blow = Vector3.xAxis
	end
	blow = blow.Unit
	if contact then
		local travel = contact.LookVector * Vector3.new(1, 0, 1)
		if travel.Magnitude > 1e-3 then
			blow = (blow + travel.Unit * BLOW_ALONG_BLADE).Unit
		end
	end
	local lx = hrp.CFrame.RightVector:Dot(blow)
	local lz = -hrp.CFrame.LookVector:Dot(blow) -- rig space: -Z is forward, +Z back
	local m = math.sqrt(lx * lx + lz * lz)
	if m > 1e-3 then
		return blow, lx / m, lz / m, attacker
	end
	return blow, 0, 1, attacker
end

-- What the server published about this hit on the model itself, in the same frame as the damage
-- (SwordSystem.publishContact): where the blade met the body and how long everything holds.
local HIT_BLADE_ATTRIBUTE = "HitBlade"
local HIT_STOP_ATTRIBUTE = "HitStop"

local function onHit(state)
	local model, hrp = state.model, state.hrp
	-- A hit landing on a reaction still in progress starts a new one; the old one's offsets are
	-- carried and faded so the body never snaps.
	if state.hitT and state.hitT < HIT_DURATION then
		state.hitCarry = EnemyAnimator.sampleHit(state.hitT, state.hitPX, state.hitPZ)
	else
		state.hitCarry = nil
	end
	local published = model:GetAttribute(HIT_STOP_ATTRIBUTE)
	local stop = if typeof(published) == "number" then clamp(published, 0, Hitstop.MAX) else Hitstop.duration(1)
	local contact = model:GetAttribute(HIT_BLADE_ATTRIBUTE)
	contact = if typeof(contact) == "CFrame" then contact else nil

	local blow, px, pz, attacker = blowOf(hrp, contact)
	state.hitPX, state.hitPZ = px, pz
	state.hitT = 0

	-- Hitstop, the victim's half. The whole rig -- the reaction's clock AND whatever it was doing
	-- underneath, idle breath or a swing of its own -- holds dead still on the frame it was hit.
	--
	-- Only the part of the hold the reaction does not already do itself: sampleHit's own first
	-- beat is a HIT_STOP-long plateau with the impact shiver on it, so holding for the full span
	-- here as well would hold twice and the stagger would arrive late. Together they come to
	-- exactly the span the server sent, which is the span the attacker holds for.
	state.hitHold = math.max(0, stop - HIT_STOP)

	if not state.flash then
		local flash = Instance.new("Highlight")
		flash.Name = "HitFlash"
		flash.DepthMode = Enum.HighlightDepthMode.Occluded
		flash.FillColor = FLASH_WHITE
		flash.OutlineColor = FLASH_WHITE
		flash.FillTransparency = 0.22
		flash.OutlineTransparency = 0
		flash.Adornee = model
		flash.Parent = model
		state.flash = flash
	end
	local torso = model:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		slashFx(torso, blow, contact)
	end
	dustFx(hrp, blow, state.scale or 1)
	local localCharacter = Players.LocalPlayer and Players.LocalPlayer.Character
	if attacker and attacker == localCharacter then
		freezeAttacker(attacker, stop)
	end
end

-- The killing blow: everything the hit gives (flash, slash, dust, the attacker's hit-stop), then
-- the absolute death pose takes over the body. `age` skips ahead for a rig first seen already dead.
local function onDeath(state, age: number)
	if state.deathT then
		return
	end
	local model, hrp = state.model, state.hrp
	local deathContact = model:GetAttribute(HIT_BLADE_ATTRIBUTE)
	local blow, px, pz, attacker = blowOf(hrp, if typeof(deathContact) == "CFrame" then deathContact else nil)
	state.deathT = age
	state.deathPX, state.deathPZ, state.deathBlow = px, pz, blow
	state.deathFrom = state.lastTransforms or {}
	state.deathFired = {}
	state.deathFade = 0
	state.hitT, state.hitCarry, state.attackStart, state.hitHold = nil, nil, nil, nil
	state.noticeT, state.alert = nil, false
	clearMarker(state)
	if state.trail then
		state.trail.Enabled = false
	end
	-- Everything visible that burns away (the sword is swapped for a dropped copy).
	local parts, decals = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			if d ~= hrp and d.Name ~= "Sword" and d.Transparency < 1 then
				-- A FileMesh keeps its own scale, so the burn shrinks it alongside the part.
				local mesh = d:FindFirstChildOfClass("SpecialMesh")
				if mesh and mesh.MeshType ~= Enum.MeshType.FileMesh then
					mesh = nil
				end
				table.insert(parts, { d, d.Transparency, d.Color, size = d.Size, mesh = mesh, scale = mesh and mesh.Scale })
			end
		elseif d:IsA("Decal") then
			table.insert(decals, { d, d.Transparency })
		end
	end
	state.deathParts, state.deathDecals = parts, decals

	clearFlash(state)
	local flash = Instance.new("Highlight")
	flash.Name = "DeathFlash"
	flash.DepthMode = Enum.HighlightDepthMode.Occluded
	flash.FillColor = FLASH_WHITE
	flash.OutlineColor = FLASH_WHITE
	flash.FillTransparency = 1
	flash.OutlineTransparency = 1
	flash.Adornee = model
	flash.Parent = model
	state.flash = flash

	if age < 0.2 then
		-- The killing blow gets exactly what a landed hit gets, from the same two attributes the
		-- server published with the damage: the streak on the steel, and a hold of the same
		-- length on the attacker. (The body itself is not held -- the death pose takes it over
		-- and starts with its own recoil.)
		local published = model:GetAttribute(HIT_STOP_ATTRIBUTE)
		local stop = if typeof(published) == "number" then clamp(published, 0, Hitstop.MAX) else Hitstop.duration(1)
		local contact = model:GetAttribute(HIT_BLADE_ATTRIBUTE)
		local torso = model:FindFirstChild("Torso")
		if torso and torso:IsA("BasePart") then
			slashFx(torso, blow, if typeof(contact) == "CFrame" then contact else nil)
		end
		dustFx(hrp, blow, state.scale or 1)
		local localCharacter = Players.LocalPlayer and Players.LocalPlayer.Character
		if attacker and attacker == localCharacter then
			freezeAttacker(attacker, stop)
		end
	end
end

local function track(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local state = { model = model, atRest = false, idlePhase = math.random() * IDLE_PERIOD,
		idle = EnemyAnimator.newIdle(os.clock()) }
	rigs[model] = state
	state.cueConn = model:GetAttributeChangedSignal(IDLE_CUE_ATTRIBUTE):Connect(function()
		onIdleCue(state)
	end)
	state.attrConn = model:GetAttributeChangedSignal(ATTACK_ATTRIBUTE):Connect(function()
		onAttack(state)
	end)
	state.alertConn = model:GetAttributeChangedSignal(NOTICE_ATTRIBUTE):Connect(function()
		onAlert(state)
	end)
	onAlert(state)
end

-- Health watch, hooked once the rig's humanoid has replicated: a drop that leaves it alive is a
-- hit; a drop to zero is the killing blow and starts the death. A rig first seen already dead
-- joins its death where the server's "EnemyDied" timestamp says it is.
local DIED_ATTRIBUTE = "EnemyDied"
local function watchHealth(state)
	local humanoid = state.model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local last = humanoid.Health
	state.healthConn = humanoid.HealthChanged:Connect(function(health)
		if health <= 0 and state.hrp then
			onDeath(state, 0)
		elseif health < last - 0.01 and state.hrp then
			onHit(state)
		end
		last = health
	end)
	local diedAt = state.model:GetAttribute(DIED_ATTRIBUTE)
	if humanoid.Health <= 0 or typeof(diedAt) == "number" then
		local age = if typeof(diedAt) == "number" then workspace:GetServerTimeNow() - diedAt else 0
		onDeath(state, if age > 0.3 then age else 0)
	end
end

local function untrack(model: Instance)
	local state = rigs[model]
	if state then
		state.attrConn:Disconnect()
		state.alertConn:Disconnect()
		state.cueConn:Disconnect()
		clearMarker(state)
		if state.healthConn then
			state.healthConn:Disconnect()
		end
		clearFlash(state)
		if state.swordClone then
			state.swordClone:Destroy()
			state.swordClone = nil
		end
		if state.shells then
			for _, entry in ipairs(state.shells) do
				entry[1]:Destroy()
			end
			state.shells = nil
		end
		rigs[model] = nil
	end
end

local function writeTransforms(state, transforms)
	for _, name in ipairs(JOINTS) do
		local joint = state.joints[name]
		if joint then
			joint.Transform = transforms[name] or CFrame.identity
		end
	end
	state.lastTransforms = transforms
end

-- Death, local effects ---------------------------------------------------------
-- Lemon embers: the game's own yellow (PanelChrome's Gold), from a white-hot core out to amber.
local LEMON = PanelChrome.BRIGHT.Gold -- (255, 212, 60)
local LEMON_LIGHT = PanelChrome.RARITY_COLORS.Legendary:Lerp(Color3.new(1, 1, 1), 0.55)
local LEMON_HOT = Color3.fromRGB(255, 251, 222) -- yellow-white, the ember core
local SWORD_GRAVITY = 90 -- [TUNING] studs/s^2 on the dropped sword (snappier than the world's)

-- The sword leaves the hand: the real one hides and a local copy tumbles away along the blow and
-- clatters flat on the ground.
local function releaseSword(state)
	local sword = state.model:FindFirstChild("Sword")
	if not (sword and sword:IsA("BasePart")) then
		return
	end
	local s = state.scale or 1
	if state.deathT < DEATH_BURN then
		local clone = sword:Clone()
		for _, c in ipairs(clone:GetChildren()) do
			if c:IsA("Trail") or c:IsA("Attachment") or c:IsA("JointInstance") then
				c:Destroy()
			end
		end
		clone.Name = "DroppedSword"
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.CFrame = sword.CFrame
		clone.Parent = workspace
		local right = state.hrp.CFrame.RightVector
		state.swordClone = clone
		state.swordOrig = clone.Transparency
		state.swordVel = (state.deathBlow * 4 + Vector3.yAxis * 10 + right * 3) * s
		state.swordSpin = right * 14
		state.swordGround = state.hrp.Position.Y - 3 * s
	end
	sword.Transparency = 1
end

local function stepSword(state, dt: number, t: number)
	local clone = state.swordClone
	if not clone then
		return
	end
	if not state.swordLanded then
		state.swordVel -= Vector3.yAxis * SWORD_GRAVITY * dt
		local spin = state.swordSpin
		local cf = CFrame.new(clone.Position + state.swordVel * dt)
			* CFrame.fromAxisAngle(spin.Unit, spin.Magnitude * dt) * clone.CFrame.Rotation
		local half = clone.Size.Z / 2
		local ground = state.swordGround
		if cf.Position.Y - math.abs(cf.LookVector.Y) * half <= ground and state.swordVel.Y < 0 then
			local dir = cf.LookVector * Vector3.new(1, 0, 1)
			if dir.Magnitude < 1e-3 then
				dir = state.deathBlow
			end
			local size = clone.Size
			local rest = Vector3.new(cf.Position.X, ground + math.min(size.X, size.Y) / 2 + 0.02, cf.Position.Z)
			local flat = CFrame.lookAt(rest, rest + dir.Unit)
			if size.X < size.Y then
				flat *= CFrame.Angles(0, 0, math.pi / 2) -- the thin side down
			end
			state.swordLanded = t
			state.swordLandCF = cf
			state.swordFlat = flat
			state.swordSlide = state.swordVel * Vector3.new(1, 0, 1) * 0.3
		end
		clone.CFrame = cf
	else
		local u = t - state.swordLanded
		if u < 0.35 then
			local k = EASE.outQuad(clamp(u / 0.1, 0, 1))
			clone.CFrame = state.swordLandCF:Lerp(state.swordFlat, k)
				+ state.swordSlide * math.min(u, 0.2) + Vector3.yAxis * arc(u, 0.06, 0.2, 0.28)
		end
	end
	if state.deathFade > 0 then
		-- It burns with the body: whitening toward lemon, glowing, then gone.
		-- (Same curves as the body in deathStep; the texture goes so the lemon heat shows.)
		local fade = state.deathFade
		if not state.swordColor then
			state.swordColor, state.swordSize = clone.Color, clone.Size
			clone.Material = Enum.Material.Neon
			if clone:IsA("MeshPart") then
				clone.TextureID = ""
			end
		end
		clone.Color = state.swordColor:Lerp(LEMON:Lerp(LEMON_HOT, fade), EASE.outQuad(clamp(fade / 0.7, 0, 1)))
		clone.Size = state.swordSize * (1 - 0.62 * EASE.inOutQuad(fade))
		clone.Transparency = state.swordOrig + (1 - state.swordOrig) * EASE.inQuad(clamp((fade - 0.3) / 0.7, 0, 1))
	end
end

-- The back hits the ground: dust spreads out low around it.
local function landFx(state)
	local torso = state.model:FindFirstChild("Torso")
	if not (torso and torso:IsA("BasePart")) then
		return
	end
	local s = state.scale or 1
	local ground = state.hrp.Position.Y - 3 * s
	local at = Vector3.new(torso.Position.X, ground + 0.25 * s, torso.Position.Z)
	local spread = TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local puffs = {}
	for i = 1, 7 do
		local a = (i / 7) * math.pi * 2 + math.random() * 0.5
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = fxPart(Enum.PartType.Ball, Vector3.one * 0.7 * s, CFrame.new(at + dir * 0.8 * s), DUST, 0.2)
		p.Material = Enum.Material.SmoothPlastic
		TweenService:Create(p, spread, {
			CFrame = CFrame.new(at + dir * (2.2 + math.random()) * s + Vector3.yAxis * 0.35 * s),
			Size = Vector3.one * (1.8 + 0.6 * math.random()) * s,
			Transparency = 1,
		}):Play()
		puffs[i] = p
	end
	task.delay(0.5, function()
		for _, p in ipairs(puffs) do
			p:Destroy()
		end
	end)
end

-- The lemon rim: a ForceField-material shell over every visible part (its fresnel shimmer is
-- brightest at the silhouette, so it reads as a glow creeping in from the edges, not a flat tint).
-- Local, anchored copies of each part's shape that follow the corpse; destroyed when it is gone.
local SHELL_GROW = 1.1 -- [TUNING] shell size over the part's, at full glow
local function rimShells(state)
	local shells = {}
	local sources = {}
	for _, entry in ipairs(state.deathParts) do
		table.insert(sources, entry[1])
	end
	if state.swordClone then
		table.insert(sources, state.swordClone)
	end
	for _, part in ipairs(sources) do
		local ok, shell = pcall(function()
			return part:Clone()
		end)
		if not (ok and shell) then
			continue
		end
		local fileMesh
		for _, c in ipairs(shell:GetChildren()) do
			if c:IsA("SpecialMesh") and c.MeshType == Enum.MeshType.FileMesh then
				fileMesh = c
			elseif not c:IsA("DataModelMesh") then
				c:Destroy()
			end
		end
		shell.Name = "LemonRim"
		shell.Anchored = true
		shell.CanCollide = false
		shell.CanQuery = false
		shell.CanTouch = false
		shell.CastShadow = false
		shell.Massless = true
		shell.Material = Enum.Material.ForceField
		shell.Color = LEMON
		shell.Transparency = 1
		if shell:IsA("MeshPart") then
			shell.TextureID = ""
		end
		if fileMesh then
			fileMesh.TextureId = ""
		end
		shell.CFrame = part.CFrame
		shell.Parent = workspace
		table.insert(shells, { shell, part, part.Size, fileMesh, fileMesh and fileMesh.Scale })
	end
	state.shells = shells
end

local function setShells(state, transparency: number, grow: number)
	for _, entry in ipairs(state.shells) do
		local shell, part = entry[1], entry[2]
		shell.Transparency = transparency
		local k = part.Size.Magnitude / entry[3].Magnitude -- the part's own burn shrink
		if entry[4] then
			entry[4].Scale = entry[5] * grow * k
		else
			shell.Size = part.Size * grow
		end
		shell.CFrame = part.CFrame
	end
end

local function clearShells(state)
	if state.shells then
		for _, entry in ipairs(state.shells) do
			entry[1]:Destroy()
		end
		state.shells = nil
	end
end

-- Embers stream off the burning body: small glowing motes spawned on the surface of the visible
-- parts (bigger parts shed more), white-hot at birth, cooling through lemon to amber as they
-- rise, drift and shrink away.
local function emberFx(state, count: number)
	local s = state.scale or 1
	local sources, total = {}, 0
	for _, entry in ipairs(state.deathParts) do
		local size = entry[1].Size
		local w = size.X * size.Y + size.Y * size.Z + size.X * size.Z -- surface, roughly
		total += w
		table.insert(sources, { entry[1], total })
	end
	if state.swordClone then
		local size = state.swordClone.Size
		total += (size.X * size.Y + size.Y * size.Z + size.X * size.Z) * 0.5
		table.insert(sources, { state.swordClone, total })
	end
	if total <= 0 then
		return
	end
	local embers = {}
	local longest = 0
	for _ = 1, count do
		local pick = math.random() * total
		local part = sources[#sources][1]
		for _, src in ipairs(sources) do
			if pick <= src[2] then
				part = src[1]
				break
			end
		end
		-- A point on the part's surface: random inside, then pushed out to one face.
		local size = part.Size
		local local_ = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
		local axis = math.random(1, 3)
		local face = if math.random() < 0.5 then -0.5 else 0.5
		local_ = Vector3.new(if axis == 1 then face else local_.X, if axis == 2 then face else local_.Y,
			if axis == 3 then face else local_.Z)
		local at = (part.CFrame * CFrame.new(size * local_)).Position
		local d = (0.2 + 0.2 * math.random()) * s
		local ember = fxPart(Enum.PartType.Ball, Vector3.one * d, CFrame.new(at), LEMON_HOT, 0)
		local rise = (2.4 + 2.4 * math.random()) * s
		local sway = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 1.6 * s
		local life = 0.6 + 0.4 * math.random()
		local delay = 0.06 * math.random()
		longest = math.max(longest, life + delay)
		TweenService:Create(ember, TweenInfo.new(life, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, delay), {
			CFrame = CFrame.new(at + sway + Vector3.yAxis * rise),
		}):Play()
		TweenService:Create(ember, TweenInfo.new(life * 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay), {
			Color = if math.random() < 0.5 then LEMON else LEMON_LIGHT,
		}):Play()
		TweenService:Create(ember, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, delay), {
			Size = Vector3.one * d * 0.25,
			Transparency = 1,
		}):Play()
		table.insert(embers, ember)
	end
	task.delay(longest + 0.05, function()
		for _, p in ipairs(embers) do
			p:Destroy()
		end
	end)
end

-- The burn starts: a gold ring (short glowing segments, so it is a true ring, not a disc) runs out
-- along the ground from under the body, under a warm flare of light.
local RING_SEGMENTS = 20 -- [TUNING]
local function ringFx(state)
	local s = state.scale or 1
	local torso = state.model:FindFirstChild("Torso")
	local centre = if torso and torso:IsA("BasePart") then torso.Position else state.hrp.Position
	local ground = state.hrp.Position.Y - 3 * s
	local at = Vector3.new(centre.X, ground + 0.06, centre.Z)
	local grow = TweenInfo.new(0.46, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local fadeOut = TweenInfo.new(0.46, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local r0, r1 = 1.0 * s, 4.6 * s
	local made = {}
	for i = 1, RING_SEGMENTS do
		local a = (i / RING_SEGMENTS) * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local function segment(r: number): (CFrame, Vector3)
			local len = 2 * math.pi * r / RING_SEGMENTS * 1.08
			return CFrame.lookAt(at + dir * r, at + dir * r + dir:Cross(Vector3.yAxis)),
				Vector3.new(0.22 * s, 0.07, len)
		end
		local cf, size = segment(r0)
		local seg = fxPart(Enum.PartType.Block, size, cf, LEMON_LIGHT, 0)
		local cf1, size1 = segment(r1)
		TweenService:Create(seg, grow, { CFrame = cf1, Size = Vector3.new(0.1 * s, 0.07, size1.Z), Color = LEMON }):Play()
		TweenService:Create(seg, fadeOut, { Transparency = 1 }):Play()
		table.insert(made, seg)
	end
	local light = Instance.new("PointLight")
	light.Color = LEMON
	light.Range = 12 * s
	light.Brightness = 0
	light.Shadows = false
	local lamp = fxPart(Enum.PartType.Block, Vector3.one * 0.1, CFrame.new(centre + Vector3.yAxis * 1.2 * s), LEMON, 1)
	light.Parent = lamp
	TweenService:Create(light, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 3 }):Play()
	TweenService:Create(light, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.12),
		{ Brightness = 0 }):Play()
	table.insert(made, lamp)
	task.delay(0.72, function()
		for _, p in ipairs(made) do
			p:Destroy()
		end
	end)
end

-- Ember waves, seconds from the killing blow, and how many motes each sheds.
local EMBER_WAVES = { { DEATH_BURN - 0.04, 6 }, { DEATH_BURN + 0.02, 14 }, { DEATH_BURN + 0.12, 12 },
	{ DEATH_BURN + 0.22, 10 }, { DEATH_BURN + 0.32, 8 } }

-- One frame of a death in progress: the pose, the timed effects, the flash and the burn.
local function deathStep(state, dt: number)
	local t = state.deathT + math.min(dt, HIT_MAX_STEP)
	state.deathT = t
	local pose = EnemyAnimator.sampleDeath(t, state.deathPX, state.deathPZ, state.scale)
	if t < DEATH_BLEND then
		local w = EASE.outCubic(t / DEATH_BLEND)
		for name, cf in pairs(pose) do
			pose[name] = (state.deathFrom[name] or CFrame.identity):Lerp(cf, w)
		end
	end
	writeTransforms(state, pose)

	local fired = state.deathFired
	if t >= DEATH_RELEASE and not fired.release then
		fired.release = true
		releaseSword(state)
	end
	if t >= DEATH_LAND and not fired.land then
		fired.land = true
		local head = state.model:FindFirstChild("Head")
		local tag = head and head:FindFirstChild("NameTag")
		if tag and tag:IsA("BillboardGui") then
			tag.Enabled = false
		end
		if t < DEATH_LAND + 0.3 then
			landFx(state)
		end
	end
	if t >= DEATH_GLOW and not fired.glow then
		fired.glow = true
		if t < DEATH_BURN + 0.2 then
			rimShells(state)
		end
	end
	if t >= DEATH_BURN and not fired.ring then
		fired.ring = true
		if t < DEATH_BURN + 0.3 then
			ringFx(state)
		end
	end
	for i, wave in ipairs(EMBER_WAVES) do
		if t >= wave[1] and not fired["ember" .. i] then
			fired["ember" .. i] = true
			if t < wave[1] + 0.3 then
				emberFx(state, wave[2])
			end
		end
	end

	-- glow: the rim coming up (0-1); fade: the burn (0-1, the body gone at 1).
	local glow = EASE.outQuad(clamp((t - DEATH_GLOW) / (DEATH_BURN - DEATH_GLOW), 0, 1))
	local fade = clamp((t - DEATH_BURN) / DEATH_FADE, 0, 1)

	-- Flash (the hit's white-then-red), then nothing, then the lemon outline and inward glow.
	local flash = state.flash
	if flash then
		if t < HIT_FLASH_END then
			local color, fill, outline = flashAt(t)
			flash.FillColor = color
			flash.OutlineColor = if t < HIT_STOP + 0.01 then FLASH_WHITE else Color3.fromRGB(255, 200, 190)
			flash.FillTransparency = fill
			flash.OutlineTransparency = outline
		elseif t < DEATH_GLOW then
			flash.FillTransparency = 1
			flash.OutlineTransparency = 1
		elseif fade < 1 then
			-- The outline leads; the fill only creeps in once the burn is eating inward, then
			-- everything goes with the body.
			local inward = EASE.inOutQuad(clamp(fade / 0.55, 0, 1))
			local gone = EASE.inQuad(clamp((fade - 0.6) / 0.4, 0, 1))
			flash.FillColor = LEMON
			flash.OutlineColor = LEMON
			flash.FillTransparency = 1 - (0.06 * glow + 0.16 * inward) * (1 - gone)
			flash.OutlineTransparency = 1 - glow * (1 - gone)
		else
			clearFlash(state)
		end
	end

	-- The rim shell: up with the glow, then tightening inward onto the body as it burns, and gone
	-- just after it.
	if state.shells then
		local shellGone = clamp((t - DEATH_BURN - 0.06) / DEATH_FADE, 0, 1)
		if shellGone >= 1 then
			clearShells(state)
		else
			local grow = 1 + (SHELL_GROW - 1) * glow - 0.18 * EASE.inQuad(shellGone)
			setShells(state, 1 - 0.92 * glow + 0.92 * EASE.inQuad(shellGone), grow)
		end
	end

	-- The body: barely warmed under the rim (it keeps its own colours, so the glow reads as an
	-- edge), then eaten from the edges inward as it burns: every part shrinks toward its own centre
	-- (the joints hold, so the silhouette crumbles in place) while it turns white-hot lemon and
	-- glows, and the last of it fades out.
	local heat = 0.12 * glow + 0.88 * EASE.outQuad(clamp(fade / 0.7, 0, 1))
	if heat ~= state.deathHeat or fade ~= state.deathFade then
		state.deathHeat = heat
		state.deathFade = fade
		local vanish = EASE.inQuad(clamp((fade - 0.3) / 0.7, 0, 1))
		local shrink = 1 - 0.62 * EASE.inOutQuad(fade)
		local target = LEMON:Lerp(LEMON_HOT, fade)
		local neon = fade >= 0.25
		for _, entry in ipairs(state.deathParts) do
			local part = entry[1]
			part.Transparency = entry[2] + (1 - entry[2]) * vanish
			part.Color = entry[3]:Lerp(target, heat)
			if fade > 0 then
				part.Size = entry.size * shrink
				if entry.mesh then
					entry.mesh.Scale = entry.scale * shrink
				end
			end
			if neon and not entry.neon then
				entry.neon = true
				part.Material = Enum.Material.Neon
			end
		end
		for _, entry in ipairs(state.deathDecals) do
			entry[1].Transparency = entry[2] + (1 - entry[2]) * vanish
		end
	end
	stepSword(state, math.min(dt, HIT_MAX_STEP), t)
end

local viewLook, viewHalf = Vector3.zAxis, math.pi
local function inView(offset: Vector3, distance: number, radius: number): boolean
	if distance < VIEW_NEAR + radius then
		return true
	end
	local angle = math.acos(clamp(offset:Dot(viewLook) / distance, -1, 1))
	return angle <= viewHalf + math.asin(math.min(1, radius / distance))
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	local now = os.clock()
	if camera then
		local size = camera.ViewportSize
		local aspect = if size.Y > 0 then size.X / size.Y else 16 / 9
		viewLook = camera.CFrame.LookVector
		viewHalf = math.atan(math.tan(rad(camera.FieldOfView) / 2) * math.sqrt(1 + aspect * aspect)) + VIEW_MARGIN
	else
		viewHalf = math.pi
	end
	for model, state in pairs(rigs) do
		if not model.Parent then
			continue
		end
		if not state.joints or not state.joints.RootJoint then
			if not resolveJoints(state) or not state.joints.RootJoint then
				continue
			end
		end
		if not state.healthConn then
			watchHealth(state)
		end
		local hrp = state.hrp
		local distance = (hrp.Position - eye).Magnitude

		if state.deathT then
			if state.deathT < DEATH_END and distance <= ANIMATE_RANGE then
				deathStep(state, dt)
			end
			continue
		end

		-- Off screen with no hit, notice or swing playing: hold the pose, bank the time.
		if not (state.hitT or state.noticeT or state.attackStart)
			and not inView(hrp.Position - eye, distance, VIEW_RADIUS * state.scale) then
			state.heldDt = (state.heldDt or 0) + dt
			continue
		end
		local dt = dt + (state.heldDt or 0)
		state.heldDt = nil

		-- Hitstop, the victim's half: for the first few frames after a blow lands, this rig does
		-- not animate at all. Not the reaction, not the idle breath under it, not a swing of its
		-- own that was in flight -- the whole body is caught at the instant it was hit and holds
		-- there, under the white flash, while the attacker holds too. Then everything lets go at
		-- once into the stagger, and the release is what reads as force.
		--
		-- The pose is simply re-written, so nothing else can creep it, and no time is banked: the
		-- reaction starts from zero when the hold ends rather than jumping over its first beat.
		if state.hitHold and state.hitHold > 0 then
			state.hitHold -= dt
			if state.lastTransforms then
				writeTransforms(state, state.lastTransforms)
			end
			continue
		end

		-- The reaction runs on its own clock, capped at one 30 fps frame per rendered frame: a
		-- hitch at the moment of impact (effects spawning, the damage number) then delays the
		-- stagger by a frame or two instead of jumping over its in-betweens.
		local hitT = state.hitT and (state.hitT + math.min(dt, HIT_MAX_STEP))
		state.hitT = hitT
		local hitting = hitT ~= nil and hitT < HIT_DURATION
		if not hitting then
			state.hitT = nil
			state.hitCarry = nil
		end
		if state.flash then
			if hitting and hitT < HIT_FLASH_END then
				local color, fill, outline = flashAt(hitT)
				state.flash.FillColor = color
				state.flash.OutlineColor = if hitT < HIT_STOP + 0.01 then FLASH_WHITE else Color3.fromRGB(255, 200, 190)
				state.flash.FillTransparency = fill
				state.flash.OutlineTransparency = outline
			else
				clearFlash(state)
			end
		end

		-- The notice runs on its own capped clock too, and the guard follows the alert.
		local noticeT = state.noticeT and (state.noticeT + math.min(dt, HIT_MAX_STEP))
		if noticeT and noticeT >= NOTICE_DURATION then
			noticeT = nil
			clearMarker(state)
		end
		state.noticeT = noticeT
		if noticeT then
			stepMarker(state, noticeT)
		end
		local guardW = state.guardW or 0
		if noticeT then
			guardW = math.max(curve(NOTICE.guard, noticeT), state.guardFrom or 0)
		elseif state.alert then
			guardW = math.min(1, guardW + dt / GUARD_IN)
		else
			guardW = math.max(0, guardW - dt / GUARD_OUT)
		end
		state.guardW = guardW

		if distance > ANIMATE_RANGE then
			state.run = nil -- far rigs are left at rest; the run starts over when they come back
			state.idleW = 0 -- and the idle eases back in
			continue
		end

		-- Gait from the root's real displacement (MoveDirection is only trustworthy on the
		-- simulating machine), pinned to the ground by the run itself.
		local run = state.run
		if not run then
			run = EnemyAnimator.newRun(hrp.Position)
			state.run = run
		end
		local runPose = EnemyAnimator.runStep(run, hrp.CFrame, state.scale, dt)
		if run.skid then
			run.skid = false
			if distance <= IDLE_RANGE then
				dustFx(hrp, run.dir, state.scale)
			end
		end
		local bracing = run.stopT ~= nil

		local attackT = state.attackStart and (now - state.attackStart)
		local attacking = attackT ~= nil and attackT < EnemyAnimator.attackDuration(state.windup)
		if not attacking then
			state.attackStart = nil
		end
		local standing = runPose == nil and not run.moving
		local idling = standing and distance <= IDLE_RANGE

		-- Unaware idle weight: takes over gently once the rig stands with nobody noticed, lets go
		-- quickly for the notice, the run, a swing or a hit.
		local unaware = idling and not attacking and not hitting and not noticeT and not state.alert
			and guardW <= 0 and not bracing
		local idleW = state.idleW or 0
		if unaware then
			if idleW <= 0 then
				resumeIdle(state.idle, now)
			end
			idleW = math.min(1, idleW + dt / IDLE_IN)
		else
			idleW = math.max(0, idleW - dt / IDLE_OUT)
		end
		state.idleW = idleW

		if not attacking and not hitting and not idling and not runPose and not bracing and not noticeT
			and guardW <= 0 and idleW <= 0 then
			if not state.atRest then
				writeTransforms(state, {})
				state.atRest = true
			end
			if state.trail then
				state.trail.Enabled = false
			end
			continue
		end
		state.atRest = false

		if state.trail then
			local k = attacking and attackTimes(state.windup)
			state.trail.Enabled = k and attackT >= k.held + LAG and attackT <= k.follow - 0.03 or false
		end

		-- Channel pose: the swing (or rest), plus breathing when standing, blended with the run,
		-- plus the arrival skid, plus the hit on top.
		local pose = if attacking then EnemyAnimator.sampleAttack(attackT, state.windup) else restPose()
		if runPose then
			-- A swing that starts while still running keeps its own arms and head.
			local w = EASE.inOutCubic(run.w)
			for _, name in ipairs(CHANNELS) do
				if not (attacking and (name == "rarm" or name == "larm" or name == "neck")) then
					local a, b = pose[name], runPose[name]
					for i = 1, #a do
						a[i] += (b[i] - a[i]) * w
					end
				end
			end
		end
		-- Alert: the weapon held up in guard (standing) or carried ready (running), pumping only a
		-- little with the stride. A swing takes the arms over and hands them back at its end.
		local g = guardW
		if g > 0 and attacking then
			local k = attackTimes(state.windup)
			g *= math.max(1 - clamp(attackT / 0.1, 0, 1), clamp((attackT - (k.done - 0.16)) / 0.16, 0, 1))
		end
		if g > 0 then
			local rw = if runPose then EASE.inOutCubic(run.w) else 0
			for _, name in ipairs({ "rarm", "larm" }) do
				local guard, carry, a = GUARD[name], CARRY[name], pose[name]
				for i = 1, #a do
					a[i] += (guard[i] + (carry[i] - guard[i]) * rw - a[i]) * g
				end
			end
			if runPose then
				pose.rarm[1] += (runPose.rarm[1] - 14) * 0.3 * g * rw
				pose.larm[1] += (runPose.larm[1] - 8) * 0.35 * g * rw
			end
		end
		local idleK = EASE.inOutQuad(idleW)
		if standing and idleK < 1 then
			addPose(pose, EnemyAnimator.sampleIdle(now + state.idlePhase), 1 - idleK)
		end
		if idleK > 0 then
			local idle = EnemyAnimator.stepIdle(state.idle, now)
			addPose(pose, idle, idleK)
			pose.lift = { idle.lift[1] * idleK, idle.lift[2] * idleK }
		pose.seat = idleK
		end
		-- Notice: the startle on top, the body's facing spun from where it was to the player (the
		-- root's own turn is taken out of it), and the head leading the body round.
		if noticeT then
			addPose(pose, EnemyAnimator.sampleNotice(noticeT), 1)
			local target = state.noticeTarget
			local targetRoot = target and target.Parent and target:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				local toward = (targetRoot.Position - hrp.Position) * Vector3.new(1, 0, 1)
				if toward.Magnitude > 0.1 then
					state.noticeFace = yawOf(toward)
				end
			end
			local from, face = state.noticeFrom, state.noticeFace
			local body = from + angleDiff(face, from) * curve(NOTICE.body, noticeT)
			local rootYaw = yawOf(hrp.CFrame.LookVector)
			pose.spin = angleDiff(body, rootYaw) * curve(NOTICE.hold, noticeT)
			local shown = rootYaw + pose.spin
			pose.neck[2] += clamp(angleDiff(face, shown), -HEAD_LEAD, HEAD_LEAD) * curve(NOTICE.head, noticeT)
		end
		if bracing then
			addPose(pose, EnemyAnimator.sampleBrace(run.stopT, run.stopK), 1)
		end
		if hitting then
			addPose(pose, EnemyAnimator.sampleHit(hitT, state.hitPX, state.hitPZ), 1)
			if state.hitCarry then
				addPose(pose, state.hitCarry, 1 - EASE.outCubic(clamp(hitT / 0.12, 0, 1)))
			end
		end
		writeTransforms(state, EnemyAnimator.transforms(pose, state.scale))
	end
end

local started = false
function EnemyAnimator.start()
	if started or not RunService:IsClient() then
		return
	end
	started = true
	for _, model in ipairs(CollectionService:GetTagged(ENEMY_TAG)) do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal(ENEMY_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(ENEMY_TAG):Connect(untrack)
	RunService.PreSimulation:Connect(step)
end

return EnemyAnimator
