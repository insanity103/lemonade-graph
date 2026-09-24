-- ModuleScript | ReplicatedStorage.EnemyOutfits | Looks for the enemy rigs built by EnemyCombat.
-- apply(model, archetypeKey, scale, role) recolours body parts and welds accessory parts onto
-- them. Enemy rigs are unanchored humanoids that walk, so unlike NpcOutfits (anchored hub NPCs)
-- every accessory is a WeldConstraint child of its body part: Massless, no collision, no query,
-- so it never bumps the rig or catches raycasts. Sizes and offsets are in unit-rig studs (R6:
-- torso 2×2×1, head 1.2³, limbs 1×2×1) and are multiplied by the archetype scale.
-- The quarry bandits (IronSquire / IronBerserker / Boss_Gorgon) share one kit family so they read
-- as one gang; role "elite" picks the "<archetype>_elite" variant when one exists.
--
-- Palette (PS99 pass, docs/ART_DIRECTION.md): the body under the outfit is the archetype's own
-- full-chroma plastic (EnemyCombat), so the big cloth pieces here -- tunic, hood, vest, cape --
-- are pale, calm tints (near-white cream / sky / mint, saturation 0.10-0.20) and only the small
-- pieces (belts, pauldrons, tool heads, eyes, sigils) carry a second saturated pop. That is the
-- calm-plus-vivid split PS99 runs on; an all-vivid or all-pastel rig reads flat. Nothing here is
-- grey, brown or muddy. Every piece is matte SmoothPlastic (see apply); Neon is kept for glows.
local EnemyOutfits = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function deg(x, y, z) return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z)) end
local FLAT = deg(0, 0, 90) -- cylinder axis vertical

-- Accessory: { part, name, size = Vector3, offset = CFrame in the body part's space (-Z front),
-- color, material?, shape?, transparency?, light? = {range, brightness} }
-- Kits are built further down by the per-family builders and assigned into this table.
local OUTFITS = {}

-- ── Shared tailoring helpers ─────────────────────────────────────────────────
-- Every family built the crisp way (the quarry gang and the permafrost glade) places each
-- piece by the WORLD height of its top and bottom edge off the fixed R6 rig (torso y 2..4
-- at |x| < 1, head y 3.75..5.25 once the 1.25 head mesh is counted, arms y 2..4 at |x| 1..2,
-- legs y 0..2 at |x| < 1), so a kit reads as measurements rather than as a pile of local
-- offsets. Units are unit-rig studs; apply() multiplies by the archetype scale.
local V, CF = Vector3.new, CFrame.new
local WEDGE = { class = "WedgePart" }

local function A(list, part, name, size, offset, color, material, extra)
	local spec = { part = part, name = name, size = size, offset = offset, color = color,
		material = material or "SmoothPlastic" }
	if extra then for key, value in pairs(extra) do spec[key] = value end end
	table.insert(list, spec)
end

local T_Y, H_Y, A_Y, L_Y = 3, 4.5, 3, 1
local A_X, L_X = 1.5, .5

-- A block on the torso. `lean` is {degrees forward, pivot height}: every leaning piece in a
-- kit turns about that ONE shared pivot at the waist, so a coat that stoops stays stacked
-- instead of shearing apart at the seams.
local function fT(k, tag, w, d, yBot, yTop, zc, color, mat, lean)
	local mid = (yBot + yTop) * .5
	local off = CF(0, mid - T_Y, zc)
	if lean then
		off = CF(0, lean[2] - T_Y, 0) * deg(-lean[1], 0, 0) * CF(0, mid - lean[2], zc)
	end
	A(k, "Torso", tag, V(w, yTop - yBot, d), off, color, mat)
end

-- A block on the head, same way round.
local function fH(k, tag, w, d, yBot, yTop, zc, color, mat)
	A(k, "Head", tag, V(w, yTop - yBot, d), CF(0, (yBot + yTop) * .5 - H_Y, zc), color, mat)
end

-- A sleeve, mitten, fist or claw: an upright volume placed by the world x of its INBOARD
-- face. Set that face at the arm's own inboard side and the arm is always contained, so all
-- the extra width shows as overhang outside the limb and none of it enters the chest.
local function fS(k, arm, side, tag, w, d, yBot, yTop, xIn, zc, color, mat)
	A(k, arm, tag, V(w, yTop - yBot, d),
		CF(side * (xIn + w * .5 - A_X), (yBot + yTop) * .5 - A_Y, zc or 0), color, mat)
end

-- A shoulder cap: a WEDGE quarter-turned about Y so its slope runs ACROSS the figure, which
-- is the only way a wedge shows a diagonal in a front silhouette. `fall` drops the outboard
-- end (a mantle, a hard Λ); false lifts it (a pauldron, a V). It is deliberately NOT tilted:
-- a tilted plate cuts into the arm it sits on, an upright wedge contains it, so the chamfer
-- costs nothing in clipping.
local function fCap(k, arm, side, tag, w, d, yBot, yTop, xIn, fall, color, mat)
	local yaw = (fall and -side or side) * 90
	A(k, arm, tag, V(d, yTop - yBot, w),
		CF(side * (xIn + w * .5 - A_X), (yBot + yTop) * .5 - A_Y, 0) * deg(0, yaw, 0), color, mat, WEDGE)
end

-- A leg column or a boot, placed by the world |x| of its CENTRE rather than by the rig leg it
-- hangs on, which is the whole point: the rig's legs are flush and a pair placed off them
-- leaves real daylight down the middle. `splay` tips the bottom outward into a stance.
local function fL(k, leg, side, tag, w, d, yBot, yTop, xc, zc, splay, color, mat)
	A(k, leg, tag, V(w, yTop - yBot, d),
		CF(side * (xc - L_X), (yBot + yTop) * .5 - L_Y, zc) * deg(0, 0, side * (splay or 0)), color, mat)
end

-- A hanging tatter: the same quarter-turned wedge, dropped outside a knee, placed by the
-- world x of its inboard edge so it never reaches the leg beside it.
local function fTat(k, side, tag, w, d, yBot, yTop, xIn, zc, color, mat)
	A(k, "Torso", tag, V(d, yTop - yBot, w),
		CF(side * (xIn + w * .5), (yBot + yTop) * .5 - T_Y, zc) * deg(0, -side * 90, 0), color, mat, WEDGE)
end

-- A hem flare: the same quarter-turned wedge as a mantle, stood against the coat's side with
-- its tall edge inboard and its slope falling outboard, and leaning with the coat about the
-- coat's own pivot, so the hem widens by `w` a side and stays flush with the parka.
local function fFlare(k, side, tag, w, d, yBot, yTop, xIn, zc, color, mat, lean)
	A(k, "Torso", tag, V(d, yTop - yBot, w),
		CF(0, lean[2] - T_Y, 0) * deg(-lean[1], 0, 0)
			* CF(side * (xIn + w * .5), (yBot + yTop) * .5 - lean[2], zc) * deg(0, -side * 90, 0),
		color, mat, WEDGE)
end

-- A brim, eave or crest: a wedge kept the way Roblox cuts it, tall face at the BACK (+Z)
-- and the slope falling away to the front, placed by world height and world z-centre.
local function fEave(k, part, tag, w, d, yBot, yTop, zc, color, mat)
	local base = part == "Head" and H_Y or T_Y
	A(k, part, tag, V(w, yTop - yBot, d), CF(0, (yBot + yTop) * .5 - base, zc), color, mat, WEDGE)
end

local ARMS = { { "Left Arm", -1, "L" }, { "Right Arm", 1, "R" } }
local LEGS = { { "Left Leg", -1, "L" }, { "Right Leg", 1, "R" } }

-- ── Quarry gang ──────────────────────────────────────────────────────────────
-- Scrap-iron brutes in a bright cartoon cut: FEW, LARGE, CRISP forms. Every big mass in the
-- gang is a BLOCK or a WEDGE - not one Ball, not one Cylinder in the three ranked kits -
-- because salvaged plate is flat-faced and hard-edged, and a helm is a faceted box, a
-- shoulder is a wedge, a chest is a slab. Four craft rules hold the family together.
--   1. One form per slot, and no more than eighteen forms per kit. When a shape has to read
--      harder it is made bigger, never busier: no lames, no rivet strips, no trim confetti.
--   2. NOTHING CLIPS. Torso and legs are hidden and rebuilt as garment (an R6 torso and its
--      two flush legs have no silhouette of their own), and every rebuilt piece is placed so
--      it either sits flush against its neighbour or wholly contains the limb inside it.
--      Torso pieces stay inside |x| < 1 wherever the arms hang (y 2..4); all the width the
--      gang gets at the shoulder comes from wedges sat ON the arms, and all the width at the
--      hip from a fauld hung below the hands. The clipping check over the real export is
--      zero intersecting pairs on all three.
--   3. IT IS STILL A CHARACTER. The head, its face and both arms are the bare rig on every
--      rank: no visor, no closed helm, nothing over the face, and each helm caps the crown
--      and no more. Legs are rebuilt as two columns with daylight between them and one boot
--      each, and no piece is more than about 40 percent wider than the part it hangs on.
--   4. Value first, one accent apiece. Work cloth and rust at the dark end, salvaged iron
--      at the light end, so the layering reads before the colour does, and exactly one warm
--      note per rank: a brass buckle on the cutthroat, a rust fist and fauld on the brute,
--      one coin-sized ember lamp on the elite - the only neon in the gang.
-- The ranks are told apart by outline alone with the colours off:
--   Cutthroat  LEAN. A peaked leather cap, a narrow jerkin with one scrap breastplate
--              strapped over it, one small wedge spaulder on the left shoulder only, bare
--              arms, a canvas apron and the thinnest legs in the gang. 15 pieces.
--   Pit Brute  BROAD, and lopsided. A flat low helm with a brow eave and a nape guard so
--              the head sits sunk between the shoulders; ONE huge iron shoulder cap on the
--              left of two iron-sleeved arms, the right ending in a rust fist; the widest
--              fauld in the gang flaring past everything above it; the heaviest boots.
--   Elite      TALL. A crested helm with cheek guards, BOTH shoulders capped with the
--              gang's biggest mantles, a narrow fauld, iron gauntlets, one banner falling
--              down the back and a single ember lamp in the breast.
local IRON = rgb(72, 160, 255)
local IRON_EDGE = rgb(200, 228, 255)
local IRON_DK = rgb(32, 104, 240)
local RUST_PLATE = rgb(255, 140, 40)
local LEATHER_MID = rgb(255, 238, 210)
local LEATHER_DK = rgb(255, 168, 72)
local STRAP_DK = rgb(240, 120, 32)
local CANVAS = rgb(255, 250, 236)
local CLOTH_DK = rgb(188, 216, 255)
local HOOD_DEEP = rgb(40, 96, 224)
local TROUSER = rgb(64, 144, 255)
local BRASS = rgb(255, 200, 48)
local BANNER = rgb(255, 64, 64)
local EMBER = rgb(255, 214, 96)
local SKIN = rgb(255, 214, 170)

-- The torso and both legs are hidden on every ranked kit and rebuilt as garment; what stays
-- bare is what a viewer has to keep seeing - the head and face on all three and both arms
-- on the cutthroat. The brute's arms are skin under iron sleeves; the elite's arms are
-- painted iron so its gauntlets read as the end of an armoured sleeve rather than a glove
-- on skin.
local QUARRY_HIDE = { "Torso", "Left Leg", "Right Leg" }
local QUARRY_BODY = {
	Head = SKIN, Torso = LEATHER_MID,
	["Left Arm"] = SKIN, ["Right Arm"] = SKIN,
	["Left Leg"] = TROUSER, ["Right Leg"] = TROUSER,
}
local IRON_BODY = {
	Head = SKIN, Torso = IRON_DK,
	["Left Arm"] = SKIN, ["Right Arm"] = SKIN,
	["Left Leg"] = TROUSER, ["Right Leg"] = TROUSER,
}
local ELITE_BODY = {
	Head = SKIN, Torso = IRON_DK,
	["Left Arm"] = IRON_DK, ["Right Arm"] = IRON_DK,
	["Left Leg"] = TROUSER, ["Right Leg"] = TROUSER,
}

-- The gang's legs: two trouser columns with daylight between them, rising into whatever
-- hangs from the waist, and one boot slab each, placed by the world x of its centre so the
-- pair never fuses into a plinth. `top` is where the column meets the belt or fauld above.
local function quarryLegs(k, colW, colD, top, bootW, bootD, bootH, xc, trouser, bootColor, bootMat)
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], colW, colD, bootH, top, xc, -.04, 0, trouser, "Fabric")
		fL(k, l[1], l[2], "Boot" .. l[3], bootW, bootD, 0, bootH, xc + .06, -.16, 0, bootColor, bootMat)
	end
end

-- ── The Quarry Cutthroat ─────────────────────────────────────────────────────
-- Lean. A peaked cap over an open face, a narrow leather jerkin with one slab of scrap iron
-- strapped over the chest, one wedge spaulder on the LEFT shoulder only (the rank's one
-- asymmetry), bare arms ending in leather bracers, a brass buckle, a canvas apron over the
-- narrowest legs in the gang. Fifteen pieces.
local function squireKit()
	local k = {}
	-- Cap and peak: the cap caps the crown and the peak juts off its front edge flush with
	-- it, so the head shape is a flat-topped cap with a brim, and the whole face is open.
	fH(k, "Cap", 1.62, 1.62, 5.02, 5.46, 0, LEATHER_DK, "Fabric")
	fEave(k, "Head", "Peak", 1.30, .56, 4.98, 5.24, -1.09, LEATHER_DK, "Fabric")
	fT(k, "Collar", 1.72, 1.72, 3.70, 4.06, -.02, CANVAS, "Fabric")
	-- ONE jerkin from the collar to the belt, cut 1.74 against the 2.00 torso so daylight
	-- runs between it and both arms for the whole height of the chest.
	fT(k, "Jerkin", 1.74, 1.20, 2.10, 3.70, -.06, LEATHER_MID, "Fabric")
	-- One slab of scrap iron strapped over the jerkin, flush against its front face.
	fT(k, "Breastplate", 1.30, .26, 2.50, 3.60, -.79, IRON, "Metal")
	fT(k, "Belt", 1.80, 1.28, 1.94, 2.28, -.06, STRAP_DK, "Fabric")
	-- The cutthroat's one warm note.
	fT(k, "Buckle", .40, .10, 1.98, 2.24, -.75, BRASS, "Metal")
	fT(k, "Apron", 1.10, .14, 1.24, 1.94, -.62, CANVAS, "Fabric")
	-- One small iron spaulder, a wedge falling outboard off the left shoulder.
	fCap(k, "Left Arm", -1, "SpaulderL", 1.14, 1.14, 3.98, 4.36, 1.00, true, IRON, "Metal")
	for _, a in ipairs(ARMS) do
		fS(k, a[1], a[2], "Bracer" .. a[3], 1.14, 1.14, 2.02, 2.70, 1.00, 0, LEATHER_DK, "Fabric")
	end
	quarryLegs(k, .64, .80, 1.96, .90, 1.12, .62, .58, TROUSER, LEATHER_DK, "Fabric")
	return k
end

-- ── The Pit Brute ────────────────────────────────────────────────────────────
-- Broad, and lopsided. The head is sunk: a flat low helm with a brow eave over the open face
-- and a nape guard behind, so the crown sits barely above the shoulder line. ONE huge iron
-- shoulder cap on the left arm against an uncapped right arm, both in iron sleeves, the
-- right ending in one rust fist - the lopsided read that tells the brute apart at any
-- distance. The fauld flares to 2.9 studs, wider than anything above it, and the boots are
-- the heaviest in the gang. Seventeen pieces.
local function bruteKit()
	local k = {}
	fH(k, "Helm", 1.80, 1.80, 4.90, 5.50, 0, IRON, "Metal")
	fEave(k, "Head", "Brow", 1.60, .46, 4.60, 4.90, -1.00, IRON_DK, "Metal")
	fH(k, "Nape", 1.60, .36, 4.10, 4.80, .95, IRON_DK, "Metal")
	fT(k, "Gorget", 1.80, 1.84, 3.66, 4.10, -.02, IRON_DK, "Metal")
	-- ONE cuirass from the gorget to the belt, the deepest chest in the gang.
	fT(k, "Cuirass", 1.84, 1.70, 2.20, 3.66, -.06, IRON, "Metal")
	fT(k, "Belt", 1.90, 1.80, 1.80, 2.20, -.06, LEATHER_DK, "Fabric")
	fT(k, "Buckle", .50, .10, 1.84, 2.16, -.99, BRASS, "Metal")
	-- The fauld: the widest thing on the brute, hung below the hands so it steps the outline
	-- out once at the hip and is legs from there down.
	fT(k, "Fauld", 2.90, 1.90, 1.40, 1.80, -.06, RUST_PLATE, "CorrodedMetal")
	-- One huge shoulder cap over the left arm: a short wide mantle (tall edge at the
	-- arm/torso seam, slope falling outboard) sat flush on the sleeve below so it reads as
	-- worn plate, not as a slab stood beside the head. The sleeve and fist are one 1.28
	-- column so the cap overhangs it by a hair and nothing under the cap is open air.
	fCap(k, "Left Arm", -1, "PauldronL", 1.38, 1.38, 3.98, 4.54, 1.00, true, IRON_EDGE, "Metal")
	fS(k, "Left Arm", -1, "SleeveL", 1.28, 1.28, 2.72, 3.98, 1.00, 0, IRON, "Metal")
	fS(k, "Left Arm", -1, "FistL", 1.28, 1.28, 2.00, 2.72, 1.00, 0, IRON_DK, "Metal")
	-- The right arm wears the same iron sleeve, uncapped, and the same dark iron fist as the
	-- left (Alex: the rust fist read as a bare orange block, so both hands match now).
	fS(k, "Right Arm", 1, "SleeveR", 1.28, 1.28, 2.86, 4.00, 1.00, 0, IRON, "Metal")
	fS(k, "Right Arm", 1, "FistR", 1.28, 1.28, 2.00, 2.86, 1.00, 0, IRON_DK, "Metal")
	quarryLegs(k, .72, .86, 1.80, 1.06, 1.28, .64, .64, TROUSER, IRON_DK, "Metal")
	return k
end

-- ── The Pit Brute, elite ─────────────────────────────────────────────────────
-- Tall. The same gorget and cuirass as the brute, but everything else goes UP: a crested
-- helm with cheek guards either side of the open face, BOTH shoulders capped with the
-- gang's biggest mantles, iron gauntlets on iron arms, a fauld pulled in narrow, one
-- banner falling down the back to the calves, and the gang's only neon - one coin-sized
-- ember lamp sunk in the breast. Eighteen pieces.
local function eliteKit()
	local k = {}
	fH(k, "Helm", 1.80, 1.80, 4.90, 5.56, 0, IRON, "Metal")
	-- The crest is one wedge stood along the crown, tall at the back and falling to the
	-- brow, so it reads as a swept fin from the side and a spike from the front.
	fEave(k, "Head", "Crest", .40, 1.40, 5.56, 6.30, .10, IRON_EDGE, "Metal")
	for _, s in ipairs({ -1, 1 }) do
		A(k, "Head", "Cheek" .. (s < 0 and "L" or "R"), V(.24, .70, .90),
			CF(s * .87, 4.55 - H_Y, -.10), IRON, "Metal")
	end
	fT(k, "Gorget", 1.80, 1.84, 3.66, 4.10, -.02, IRON_DK, "Metal")
	fT(k, "Cuirass", 1.84, 1.70, 2.20, 3.66, -.06, IRON, "Metal")
	-- The one glow in the gang: a coin-sized lamp stood on its corner in the breast.
	A(k, "Torso", "Lamp", V(.34, .34, .10), CF(0, 3.24 - T_Y, -.96) * deg(0, 0, 45), EMBER, "Neon",
		{ light = { 6, .5 } })
	fT(k, "Belt", 1.90, 1.80, 1.80, 2.20, -.06, LEATHER_DK, "Fabric")
	fT(k, "Fauld", 2.30, 1.90, 1.40, 1.80, -.06, IRON_DK, "Metal")
	-- One banner, flush against the back of the fauld, from the shoulders to the calves.
	fT(k, "Banner", 1.70, .16, .90, 3.90, .97, BANNER, "Fabric")
	-- Both shoulders capped with mantles cut like the brute's (tall edge at the seam, slope
	-- falling outboard, sat on the arm top) but deeper and taller than its one, their thin
	-- tips ending just past the gauntlet below, so the rank shows in the size of the cap
	-- rather than in wings held out beside the head.
	for _, a in ipairs(ARMS) do
		fCap(k, a[1], a[2], "Pauldron" .. a[3], 1.36, 1.48, 3.98, 4.66, 1.00, true, IRON_EDGE, "Metal")
		fS(k, a[1], a[2], "Gauntlet" .. a[3], 1.24, 1.24, 2.00, 2.72, 1.00, 0, IRON, "Metal")
	end
	quarryLegs(k, .70, .86, 1.80, 1.00, 1.22, .66, .62, TROUSER, IRON, "Metal")
	return k
end

-- ── The Warden of the Pit ────────────────────────────────────────────────────
-- The quarry gang's boss, retailored on the gang's four rules and told apart from the elite
-- by outline, not by size: the elite goes UP (a crest, shoulders lifted beside the head), the
-- boss goes OUT. Its head is a closed great helm — the rig head is hidden and rebuilt as one
-- iron block with a dark visor slit — and two iron wedges flare outboard off the helm's
-- crown, so the top of the boss is a wide T where the elite is a spike. Both shoulders fall
-- as heavy mantles, the fauld is the widest in the gang, and one banner hangs in one piece
-- from the fauld to the calves. Its one glow is the hip lantern, coin-sized, sunk into the
-- belt. The sword is welded by EnemyCombat into the right hand, below the mantle. Eighteen
-- pieces, blocks and wedges only. The boss is the DARK end of the gang: helm, cuirass and
-- gauntlets are dark iron and only the horn-and-mantle T is mid iron, so the silhouette's
-- signature is the one light thing on it, it reads heavier than the elite, and it does not
-- flash white when it stands beside the warm briar figures in a line-up.
local GORGON_HIDE = { "Torso", "Left Leg", "Right Leg", "Head" }
local GORGON_BODY = {
	Head = IRON_DK, Torso = CLOTH_DK,
	["Left Arm"] = IRON_DK, ["Right Arm"] = IRON_DK,
	["Left Leg"] = TROUSER, ["Right Leg"] = TROUSER,
}
local function gorgonKit()
	local k = {}
	-- The great helm: one block from the gorget to above the crown, and one slit for a face.
	fH(k, "Helm", 1.56, 1.56, 3.90, 5.40, -.02, IRON_DK, "Metal")
	A(k, "Head", "Visor", V(1.00, .16, .06), CF(0, 4.70 - H_Y, -.83), HOOD_DEEP, "Fabric")
	-- Two horns: wedges stood against the helm's sides, tall edge outboard, sloping down
	-- inboard onto the crown, so the helm flares wider than it is tall.
	for _, s in ipairs({ -1, 1 }) do
		A(k, "Head", "Horn" .. (s < 0 and "L" or "R"), V(.90, .70, .80),
			CF(s * 1.18, 5.35 - H_Y, -.02) * deg(0, s * 90, 0), IRON, "Metal", WEDGE)
	end
	fT(k, "Gorget", 1.84, 1.84, 3.62, 4.10, -.02, IRON_DK, "Metal")
	fT(k, "Cuirass", 1.90, 1.76, 2.20, 3.62, -.06, IRON_DK, "Metal")
	fT(k, "Belt", 1.96, 1.86, 1.80, 2.20, -.06, LEATHER_DK, "Fabric")
	-- The hip lantern survives the retailor because it is the boss's signature, as one
	-- coin-sized bead sunk into the belt.
	A(k, "Torso", "Lantern", V(.34, .40, .12), CF(-.60, 2.00 - T_Y, -1.05), EMBER, "Neon",
		{ light = { 8, .8 } })
	fT(k, "Fauld", 2.90, 1.96, 1.36, 1.80, -.06, RUST_PLATE, "CorrodedMetal")
	-- One banner, flush against the back of the fauld, in one piece to the calves.
	fT(k, "Banner", 1.70, .16, .70, 3.60, 1.02, BANNER, "Fabric")
	for _, a in ipairs(ARMS) do
		fCap(k, a[1], a[2], "Mantle" .. a[3], 1.40, 1.46, 3.98, 4.80, 1.00, true, IRON, "Metal")
		fS(k, a[1], a[2], "Gauntlet" .. a[3], 1.28, 1.28, 2.00, 2.74, 1.00, 0, IRON_DK, "Metal")
	end
	quarryLegs(k, .74, .88, 1.36, 1.08, 1.30, .66, .66, TROUSER, IRON_DK, "Metal")
	return k
end

OUTFITS.IronSquire = { colors = QUARRY_BODY, hide = QUARRY_HIDE, accessories = squireKit() }
OUTFITS.IronBerserker = { colors = IRON_BODY, hide = QUARRY_HIDE, accessories = bruteKit() }
OUTFITS.IronBerserker_elite = { colors = ELITE_BODY, hide = QUARRY_HIDE, accessories = eliteKit() }
OUTFITS.Boss_Gorgon = { colors = GORGON_BODY, hide = GORGON_HIDE, accessories = gorgonKit() }
-- Regional kits share a material language, while each rank changes its silhouette.
-- All pieces use the same local R6 coordinates as the quarry outfits above.
local function piece(part: string, name: string, size: Vector3, position: Vector3, color: Color3, material: string?)
	return { part = part, name = name, size = size, offset = CFrame.new(position), color = color, material = material or "Fabric" }
end

local function regionalKit(primary: Color3, secondary: Color3, trim: Color3, material: string, rank: number)
	local p = piece
	local kit = {
		p("Torso", "TunicFront", Vector3.new(2.08, 1.65, .16), Vector3.new(0, .1, -.54), primary),
		p("Torso", "TunicBack", Vector3.new(2.08, 1.65, .16), Vector3.new(0, .1, .54), primary),
		p("Torso", "WaistBinding", Vector3.new(2.16, .24, 1.16), Vector3.new(0, -.79, 0), secondary),
		p("Torso", "ChestSeam", Vector3.new(.12, 1.22, .05), Vector3.new(0, .19, -.65), trim),
		p("Left Arm", "LeftCuff", Vector3.new(1.08, .33, 1.08), Vector3.new(0, -.68, 0), secondary),
		p("Right Arm", "RightCuff", Vector3.new(1.08, .33, 1.08), Vector3.new(0, -.68, 0), secondary),
		p("Left Leg", "LeftGreave", Vector3.new(1.07, .65, 1.08), Vector3.new(0, -.43, -.03), secondary),
		p("Right Leg", "RightGreave", Vector3.new(1.07, .65, 1.08), Vector3.new(0, -.43, -.03), secondary),
		p("Head", "BrowBand", Vector3.new(1.26, .18, 1.24), Vector3.new(0, .42, 0), trim, material),
		p("Head", "LeftEye", Vector3.new(.17, .12, .08), Vector3.new(-.26, .08, -.84), trim, "Neon"),
		p("Head", "RightEye", Vector3.new(.17, .12, .08), Vector3.new(.26, .08, -.84), trim, "Neon"),
		p("Torso", "Collar", Vector3.new(1.54, .18, 1.1), Vector3.new(0, .89, 0), secondary),
	}
	if rank >= 2 then
		table.insert(kit, p("Torso", "BreastArmor", Vector3.new(1.85, 1.05, .23), Vector3.new(0, .31, -.65), secondary, material))
		table.insert(kit, p("Left Arm", "LeftShoulder", Vector3.new(1.35, .4, 1.35), Vector3.new(0, .89, 0), secondary, material))
		table.insert(kit, p("Right Arm", "RightShoulder", Vector3.new(1.35, .4, 1.35), Vector3.new(0, .89, 0), secondary, material))
	end
	if rank >= 3 then
		table.insert(kit, p("Torso", "MantleLeft", Vector3.new(.85, 2.55, .12), Vector3.new(-.6, -.7, .68), primary))
		table.insert(kit, p("Torso", "MantleRight", Vector3.new(.85, 2.55, .12), Vector3.new(.6, -.7, .68), primary))
		table.insert(kit, p("Head", "Crown", Vector3.new(1.48, .36, 1.42), Vector3.new(0, .68, 0), secondary, material))
		table.insert(kit, p("Torso", "ChestSigil", Vector3.new(.42, .42, .08), Vector3.new(0, .28, -.82), trim, "Neon"))
	end
	return kit
end

local function addKit(key: string, primary: Color3, secondary: Color3, trim: Color3, material: string, rank: number, extras)
	local accessories = regionalKit(primary, secondary, trim, material, rank)
	for _, spec in ipairs(extras) do table.insert(accessories, spec) end
	OUTFITS[key] = { colors = {}, accessories = accessories }
end

local p = piece

-- ── The Permafrost Glade ─────────────────────────────────────────────────────
-- Retailored 2026-09-22 (round 3). Rounds 1 and 2 both died on the same thing: the R6 rig
-- is a crate. Its two legs are flush, so together they are one 2-stud plinth exactly as wide
-- as the torso; its arms are flush against the torso's sides, so there is no underarm notch;
-- and any garment laid on top of that inherits a rectangle. Painting bands on it, or hanging
-- wider slabs off it, cannot fix a silhouette that has no holes in it.
-- So this round the outfit stops decorating the crate and REPLACES the parts of it that make
-- the crate. Torso and legs are hidden and rebuilt as garment volumes; the arms and (on the
-- gargoyle) the head stay the real rig parts, bare, so the figure is still a body wearing
-- clothes. What that buys is the three holes a character silhouette needs:
--   1. TWO LEGS WITH DAYLIGHT BETWEEN THEM. Each rank stands on two columns about a third of
--      a torso wide, centred off the rig's own leg so the pair leaves a gap of a full column
--      width down the middle, capped by a boot a step wider and a step deeper than the
--      column so the foot reads as a foot and not as the column's own end. The lowest
--      garment stops at the hip, so that gap survives in pure black silhouette.
--   2. AN UNDERARM NOTCH. The chest volume is cut NARROWER than the rig's shoulders - 1.76,
--      1.78 and 1.60 studs against a 2.00 torso - and the arms stay where R6 puts them, so
--      daylight runs down between chest and arm from the armpit to the hip. A full-width
--      collar bridges the shoulders above it, which is what turns that daylight into a
--      shoulder line instead of a detached arm.
--   3. A HEM STEP. One band below the belt, wider than everything above it and entirely
--      below the hands, so the outline steps out once at the hip and is legs from there down.
-- Two craft rules keep it clean. Every big form is a BLOCK or a WEDGE - not one Ball, not one
-- Cylinder in the three kits, because cold-weather gear is crisp. And every shoulder chamfer
-- is a wedge standing UPRIGHT (quarter-turned about Y so its slope runs across the figure)
-- rather than a plate tilted into the arm, so a chamfered shoulder contains the limb instead
-- of cutting through it: the whole family is zero intersecting pairs by construction.
-- The three body plans are different animals, not one parka at three scales:
--   Frost Imp   hunched. The entire coat - collar, parka, pack, belt, hem - is turned 12
--               degrees forward about one pivot at the waist, so the shoulders sit out over
--               the toes and the front hem dips; a squat head is pushed forward off the neck
--               under a pointed hood; one fur shoulder wrap on the left only; short stubby
--               legs with only a third of the figure's height below the hem.
--   Glacial     a wide crouch. No headgear - the bare rig head with one tall horn and one
--   Gargoyle    broken stub - sunk between two hard chamfered mantles, two stone wings off
--               the back, bare stone arms, and legs splayed 14 degrees out to a stance twice
--               the imp's, ending in two heavy slab feet outside the hips.
--   Frost       a spike, and the only one with no feet. A narrow tall skull with a single
--   Revenant    blade fin, shoulders chamfered UP where the gargoyle's fall DOWN, a chest
--               cut narrower than either of the others, and legs that taper to points above
--               the floor between two hanging tatters, so it reads as drifting.
-- One accent, one glow. White and ice over a friendly mid-navy, the cream fur kept up around
-- the face where the eye should go, and exactly one small neon per rank: the imp's eye band,
-- the gargoyle's visor slit, the revenant's rune.
local PARKA = rgb(246, 250, 255)
local PARKA_DK = rgb(200, 228, 255)
local FUR = rgb(255, 244, 222)
local COAT = rgb(72, 160, 255)
local COAT_DK = rgb(32, 104, 240)
local NIGHT = rgb(40, 72, 208)
local RIME = rgb(232, 246, 255)
local ICE = rgb(120, 216, 255)
local ICE_DK = rgb(48, 180, 255)
local ICE_DEEP = rgb(24, 140, 255)
local FACE_ICE = rgb(160, 224, 255)
local GLOW = rgb(150, 232, 255)

-- Torso and legs are hidden on every rank and rebuilt as garment, because they are the two
-- parts of an R6 rig that have no silhouette of their own. What stays bare is what a viewer
-- has to keep seeing: both arms on all three, and the gargoyle's whole head.
-- The gargoyle keeps its head: a bare 1.5-stud rig head IS a stone skull, and it is the
-- one rank whose face is meant to be a blank slab. The imp and the revenant hide theirs and
-- build a head of their own, because the hunch and the spike both live in a skull that is
-- not a cube sitting square on the neck - the imp's is squat and pushed forward over its
-- toes, the revenant's is narrow and a head taller.
local FROST_HIDE = { "Torso", "Left Leg", "Right Leg" }
local FROST_HIDE_HEAD = { "Torso", "Left Leg", "Right Leg", "Head" }
local FROST_BODY = {
	Head = FACE_ICE, Torso = PARKA,
	["Left Arm"] = NIGHT, ["Right Arm"] = NIGHT,
	["Left Leg"] = COAT, ["Right Leg"] = COAT,
}
local FROST_HEAVY_BODY = {
	Head = ICE_DK, Torso = ICE_DEEP,
	["Left Arm"] = ICE_DEEP, ["Right Arm"] = ICE_DEEP,
	["Left Leg"] = ICE_DEEP, ["Right Leg"] = ICE_DEEP,
}
local FROST_BOSS_BODY = {
	Head = ICE_DEEP, Torso = ICE_DEEP,
	["Left Arm"] = NIGHT, ["Right Arm"] = NIGHT,
	["Left Leg"] = NIGHT, ["Right Leg"] = NIGHT,
}

-- ── The Frost Imp ────────────────────────────────────────────────────────────
-- The small one, and the only rank built entirely from cloth. It keeps its own head - the
-- rank that shows a face - under a hood whose brim juts a stud and a half past the brow, and
-- ONE tall white parka, not a stack of bands, leaning 8 degrees forward about the waist
-- together with the fur pack on its back, so from the side it stoops and from the front the
-- hood sits out over its toes. The parka runs to the hem in one piece and flares there: two
-- fur wedges stood against its sides widen the bottom corners so the coat is an A-line and
-- not a square. The hood is one garment nodded forward and cocked to the side about the
-- crown, so the head hangs off-axis rather than sitting square on the neck, and one boot
-- turns out. One fur wrap over the LEFT shoulder only is the family's other asymmetry. Two
-- stubby legs with daylight between them carry the bottom third of the figure. Eighteen
-- pieces.
local function impKit()
	local k = {}
	local lean = { 8, 2.45 }
	-- The hood, its brim and its peak turn about ONE pivot at the crown of the skull: nodded
	-- 6 degrees forward and cocked 5 to the side. The hood is cut 1.80 square so that, tilted,
	-- it still swallows the whole top of the 1.5 skull.
	local function hoodCF(x, y, z)
		return CF(0, 4.95 - H_Y, -.08) * deg(-6, 0, 5) * CF(x, y - 4.95, z + .08)
	end
	-- The hood swallows the skull and the brim overhangs the face; nothing covers it.
	A(k, "Head", "Hood", V(1.80, .58, 1.80), hoodCF(0, 5.15, -.08), COAT_DK, "Fabric")
	A(k, "Head", "HoodBrim", V(1.34, .34, .58), hoodCF(0, 4.67, -1.12), COAT_DK, "Fabric", WEDGE)
	A(k, "Head", "HoodPeak", V(.86, .54, 1.12), hoodCF(0, 5.73, -.10), COAT_DK, "Fabric", WEDGE)
	-- The rank's one glow, the size of a coin, on the open face under the brim.
	fH(k, "Eyes", .58, .05, 4.24, 4.35, -.775, GLOW, "Neon")
	fT(k, "Ruff", 1.80, 1.66, 3.62, 4.12, -.05, FUR, "Fabric")
	-- ONE coat: a single tall mass from the collar to the hem, cut 1.76 against a 2.00 torso
	-- so daylight runs down between it and both arms for the whole height of the chest.
	fT(k, "Parka", 1.76, 1.34, 1.66, 3.56, -.08, PARKA, "Fabric", lean)
	fT(k, "Pack", 1.20, .58, 2.90, 3.40, .88, PARKA_DK, "Fabric", lean)
	-- The hem flare: two fur wedges on the coat's bottom corners, entirely below the hands so
	-- the step is not eaten by the arms, and the last thing above open legs.
	for _, s in ipairs({ -1, 1 }) do
		fFlare(k, s, "Flare" .. (s < 0 and "L" or "R"), .28, 1.10, 1.66, 1.92, .88, -.08, FUR, "Fabric", lean)
	end
	-- The wrap rests on the shoulder ABOVE the arm rather than being tilted into it, so a
	-- chamfered shoulder costs nothing in clipping.
	fCap(k, "Left Arm", -1, "WrapL", 1.16, 1.14, 4.02, 4.42, 1.00, true, FUR, "Fabric")
	for _, a in ipairs(ARMS) do
		fS(k, a[1], a[2], "Sleeve" .. a[3], 1.14, 1.10, 2.62, 4.00, 1.00, 0, COAT, "Fabric")
		fS(k, a[1], a[2], "Mitten" .. a[3], 1.20, 1.20, 2.00, 2.60, 1.00, 0, COAT_DK, "Fabric")
	end
	-- The leg columns rise into the coat, so they are cut to sit inside its footprint.
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], .60, .78, .54, 2.00, .58, -.04, 0, COAT_DK, "Fabric")
	end
	fL(k, "Left Leg", -1, "BootL", .86, 1.14, 0, .56, .64, -.18, 0, NIGHT, "Fabric")
	-- The right foot turns out 10 degrees: the stance is off-axis, not a pair of bollards.
	A(k, "Right Leg", "BootR", V(.86, .56, 1.14), CF(.64 - L_X, .28 - L_Y, -.18) * deg(0, -10, 0), NIGHT, "Fabric")
	return k
end

-- ── The Glacial Gargoyle ─────────────────────────────────────────────────────
-- The wide one: a crouch, not a bigger imp. No headgear at all, so the bare rig head reads as
-- a stone skull carrying one tall horn and one broken stub, sunk between two hard chamfered
-- mantles that sit ON the shoulders and jut half a stud past the arms. Two stone wings stand
-- off its back, its arms are bare stone from shoulder to fist, and its legs splay 10 degrees
-- outward onto two heavy slab feet that land outside its own hips, so it stands in a stance
-- half again the imp's. Eighteen pieces.
local function gargoyleKit()
	local k = {}
	A(k, "Head", "HornL", V(.40, .74, .86), CF(-.42, 5.62 - H_Y, .18) * deg(0, 0, 14), ICE_DEEP, "Ice", WEDGE)
	A(k, "Head", "HornR", V(.40, .44, .86), CF(.42, 5.47 - H_Y, .18) * deg(0, 0, -14), ICE_DEEP, "Ice", WEDGE)
	-- A heavy brow slab standing proud of the face, with the rank's one glow - a slit, not a
	-- pair of eyes - set in the shadow under it. It is what turns the bare rig head from a
	-- cube into a skull without covering the face.
	fH(k, "Brow", 1.10, .40, 4.62, 4.92, -.96, ICE_DK, "Ice")
	fH(k, "Visor", .88, .05, 4.46, 4.57, -.775, GLOW, "Neon")
	-- The gorget is cut to the skull's own 1.50 width, and the mantles start .08 outboard of
	-- the arm, so a slot of daylight runs down between neck and shoulder cap to the top of the
	-- cuirass: the arms hang off the shoulders instead of merging with the collar.
	fT(k, "Gorget", 1.50, 1.72, 3.56, 4.14, -.02, ICE_DEEP, "Ice")
	fT(k, "Cuirass", 1.80, 1.52, 2.04, 3.54, -.08, ICE, "Ice")
	fT(k, "Fauld", 2.76, 1.86, 1.72, 2.00, -.08, ICE_DK, "Ice")
	fT(k, "WingRoot", 1.10, .44, 3.00, 3.50, .90, ICE_DEEP, "Ice")
	for _, s in ipairs({ -1, 1 }) do
		A(k, "Torso", "Wing" .. (s < 0 and "L" or "R"), V(1.34, .42, .34),
			CF(s * .689, 3.90 - T_Y, 1.32) * deg(0, 0, -s * 35), ICE_DK, "Ice")
	end
	for _, a in ipairs(ARMS) do
		fCap(k, a[1], a[2], "Mantle" .. a[3], 1.16, 1.26, 4.02, 4.58, 1.08, true, RIME, "Ice")
		fS(k, a[1], a[2], "Fist" .. a[3], 1.24, 1.28, 2.02, 2.60, 1.00, 0, ICE_DEEP, "Ice")
	end
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], .72, .86, .56, 1.96, .90, -.04, 10, ICE_DEEP, "Ice")
		fL(k, l[1], l[2], "Foot" .. l[3], 1.10, 1.32, 0, .62, .92, -.20, 0, ICE_DK, "Ice")
	end
	return k
end

-- ── The Frost Revenant ───────────────────────────────────────────────────────
-- A spike, and the only rank with no feet. A narrow tall skull with one blade fin driven into
-- it, shoulders chamfered UP where the gargoyle's fall DOWN, the narrowest chest in the family
-- so the underarm gap is widest here, and two legs that taper to points and stop above the
-- floor between two hanging tatters. Three values of one ice blue over a near-black body, no
-- white and no cream, so it reads as a different creature. Eighteen pieces.
local function revenantKit()
	local k = {}
	fH(k, "Skull", .96, 1.00, 4.06, 5.30, -.12, ICE_DEEP, "Ice")
	-- The rank's one glow: a single rune stood on its corner where a face would be.
	A(k, "Head", "Rune", V(.30, .30, .06), CF(0, 4.74 - H_Y, -.645) * deg(0, 0, 45), GLOW, "Neon")
	A(k, "Head", "CrownFin", V(.38, .90, 1.32), CF(0, 5.77 - H_Y, .10), ICE, "Ice", WEDGE)
	fT(k, "Collar", 1.62, 1.66, 3.60, 4.14, -.05, ICE, "Ice")
	fT(k, "Chest", 1.58, 1.38, 2.06, 3.58, -.10, ICE_DEEP, "Fabric")
	fT(k, "Skirt", 1.84, 1.56, 1.72, 2.10, -.08, NIGHT, "Fabric")
	for _, s in ipairs({ -1, 1 }) do
		fTat(k, s, "Tatter" .. (s < 0 and "L" or "R"), .48, 1.10, .34, 1.60, .94, -.06, NIGHT, "Fabric")
	end
	for _, a in ipairs(ARMS) do
		fCap(k, a[1], a[2], "Spaulder" .. a[3], 1.18, 1.18, 3.86, 4.52, 1.00, false, ICE, "Ice")
		fS(k, a[1], a[2], "Sleeve" .. a[3], 1.14, 1.12, 2.62, 4.00, .98, 0, ICE_DEEP, "Fabric")
		fS(k, a[1], a[2], "Claw" .. a[3], 1.10, 1.20, 2.00, 2.60, 1.00, 0, ICE, "Ice")
	end
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], .62, .74, .66, 2.00, .60, -.04, 0, NIGHT, "Fabric")
		fL(k, l[1], l[2], "Point" .. l[3], .34, .44, .10, .68, .60, -.04, 0, ICE_DEEP, "Ice")
	end
	return k
end

OUTFITS.FrostImp = { colors = FROST_BODY, hide = FROST_HIDE, accessories = impKit() }
OUTFITS.GlacialGargoyle = { colors = FROST_HEAVY_BODY, hide = FROST_HIDE, accessories = gargoyleKit() }
OUTFITS.Boss_FrostRevenant = { colors = FROST_BOSS_BODY, hide = FROST_HIDE_HEAD, accessories = revenantKit() }

-- ── The Cinder Forge ─────────────────────────────────────────────────────────
-- Retailored 2026-09-23 (round 0 of the Cinder gauntlet). The kits this replaces were the
-- generic regional ones Alex rejected: "slabs bolted onto a blocky rig, shoulder pads wider
-- than the arms, tunic panels that read as flat boards, and glowing neon eyes doing most of
-- the character work". So this family is cut on the four rules the approved families hold:
--   1. FEW, LARGE, CRISP forms. One form per slot, eighteen forms per kit and never more.
--      Every big mass is a BLOCK or a WEDGE - not one Ball, not one Cylinder in the four
--      kits - because scorched plate splits flat and a cooling crust cracks in angles. A
--      helm is a faceted box, a pauldron is a wedge, a chest is a slab.
--   2. NOTHING CLIPS. Torso and legs are hidden and rebuilt as garment (an R6 torso and its
--      two flush legs have no silhouette of their own); every other piece either sits flush
--      against its neighbour's face or wholly contains the limb inside it. Torso pieces stay
--      inside |x| < 1 wherever the arms hang (y 2..4), so all the width at the shoulder comes
--      from forms sat ON the arms and all the width at the hip from a fauld hung entirely
--      below the hands. The clipping check over the real export is zero intersecting pairs.
--   3. IT IS STILL A CHARACTER. Every rank keeps its own head and an open face - no visor,
--      no closed helm, nothing over the eyes - and both arms are the bare rig between a
--      shoulder piece and a fist, in a colour that differs from both so the limb reads as a
--      limb. Legs are two columns with daylight between them on one boot each.
--   4. Value first, one accent apiece. Scorched basalt at the dark end, forge iron and brass
--      at the light end, so the layering reads before the colour does, and exactly one warm
--      note per rank - and exactly one coin-sized neon, never a pair of eyes.
--   5. ONE SHOULDER LEADS (round 1). No rank wears a matching pair of shoulder boxes: every
--      kit has ONE dominant shoulder on ONE side, and the other side carries either a bare
--      sleeve or something plainly smaller - a strap, a band, a ring. This is the rule the
--      approved quarry brute and frost gargoyle already hold, and it is what makes plate
--      read as worn armour rather than as a costume bolted on symmetrically. The dominant
--      side alternates down the ranks (fiend R, juggernaut L, dominator R, colossus L) and
--      NO shoulder piece approaches torso volume: each cap is cut to within .06-.08 a side
--      of the arm column beneath it, so it hugs the arm instead of shelving out over it.
-- Told apart by outline alone with the colours off, which is the whole point of a rank:
--   Cinder Fiend      SMALL AND NARROW. A soot cap with a jutting brim over an open face,
--                     one narrow tunic, the family's SMALLEST shoulder - one shallow magma
--                     plate on the right - against a left arm wearing only a soot strap,
--                     thin bare arms, and the thinnest legs in the family under a hem barely
--                     wider than the belt. Fifteen pieces - the lean one.
--   Magma Juggernaut  A WALL. Widest at the hip, and the only rank with no chamfer on it:
--                     its one shoulder is a flat-topped iron plate on the LEFT, sat on an
--                     unbroken arm column and only .06 proud of it a side, against a plain
--                     riveted band on the right. A dark anvil helm under a flat iron lid
--                     makes the head a horizontal box rather than a point, and the family's
--                     widest fauld flares past everything above it onto the heaviest boots.
--                     The wall does not give, but it no longer shelves. Eighteen.
--   Solar Dominator   A SPIKE. The tall one, and the only rank that goes UP: a crested helm
--                     whose brass fin is the family's highest point, and a shoulder line cut
--                     on the diagonal - ONE tall pauldron on the RIGHT chamfered UP into a V
--                     that carries the eye to the crest, against a thin bronze ring on the
--                     left. The narrowest waist in the family cinched between chest and
--                     fauld, bare skin forearms, one brass tabard between the legs. Eighteen.
--   Infernal Colossus MASSIVE, AND LOPSIDED. Its width is at the TOP where the Juggernaut's
--                     is at the hip: two iron horns stand off a heavy crown into a wide T
--                     three and a quarter studs across, and the family's BIGGEST cap - one
--                     magma pauldron - falls off the left arm against a plain sleeved right
--                     arm that carries the sword, both arms otherwise the same column.
--                     Deepest chest, biggest feet, narrower fauld. Eighteen.
local BASALT = rgb(224, 64, 32)
local BASALT_DK = rgb(176, 40, 24)
local SCORCH = rgb(255, 96, 64)
local FORGE_IRON = rgb(255, 240, 220)
local ASHCLOTH = rgb(255, 236, 216)
local CINDER_SKIN = rgb(255, 128, 48)
local MAGMA = rgb(255, 96, 32)
local MAGMA_DK = rgb(224, 56, 24)
local EMBER_LIT = rgb(255, 224, 64)
local BRASS_LT = rgb(255, 214, 80)
local FORGE_BRONZE = rgb(255, 176, 32)
local BRONZE_DK = rgb(224, 128, 16)
local SUN_LIT = rgb(255, 236, 140)
local SOLAR_SKIN = rgb(255, 200, 96)

-- Torso and both legs are hidden on every rank and rebuilt as garment. What stays bare is
-- what a viewer has to keep seeing: the head and its open face, and the stretch of both arms
-- between the shoulder and the fist - which is why the arm colour is never the colour of the
-- plate above it, and why nothing on a shoulder reaches higher than y 4.6 on any rank while
-- every head mass starts at 4.8 or above: the gap between those two numbers IS the neck, and
-- it is what stops a heavy rank from becoming a stack of horizontal bars.
local CINDER_HIDE = { "Torso", "Left Leg", "Right Leg" }
local FIEND_BODY = {
	Head = CINDER_SKIN, Torso = BASALT,
	["Left Arm"] = CINDER_SKIN, ["Right Arm"] = CINDER_SKIN,
	["Left Leg"] = ASHCLOTH, ["Right Leg"] = ASHCLOTH,
}
local JUGGERNAUT_BODY = {
	Head = CINDER_SKIN, Torso = BASALT,
	["Left Arm"] = SCORCH, ["Right Arm"] = SCORCH,
	["Left Leg"] = BASALT, ["Right Leg"] = BASALT,
}
local SOLAR_BODY = {
	Head = SOLAR_SKIN, Torso = FORGE_BRONZE,
	["Left Arm"] = SOLAR_SKIN, ["Right Arm"] = SOLAR_SKIN,
	["Left Leg"] = BRONZE_DK, ["Right Leg"] = BRONZE_DK,
}
local COLOSSUS_BODY = {
	Head = SCORCH, Torso = BASALT,
	["Left Arm"] = SCORCH, ["Right Arm"] = SCORCH,
	["Left Leg"] = BASALT, ["Right Leg"] = BASALT,
}

-- ── The Cinder Fiend ─────────────────────────────────────────────────────────
-- The small one, and the only rank with nothing on its shoulders but a single plate. A soot
-- cap whose front face is flush with the brow and whose brim juts a half stud past it, so the
-- head is a flat-topped cap over a wholly open face; ONE narrow tunic from collar to belt,
-- cut 1.50 against a 2.00 torso - the narrowest chest in the family - so a quarter stud of
-- daylight runs between it and each arm for the whole height of the chest; the family's
-- SMALLEST shoulder - one shallow magma plate on the RIGHT, .03 proud of the bare arm a side
-- - against a left arm carrying only a soot strap round the bicep, which is the rank's
-- asymmetry; thin bare arms in a soot wrap at the wrist; and the thinnest legs in the family
-- under a hem barely wider than the belt, because the lean rank must not step out at the hip
-- the way the heavy ones do. Fifteen pieces.
local function cinderFiendKit()
	local k = {}
	fH(k, "Cap", 1.58, 1.58, 5.00, 5.56, .04, BASALT_DK, "Slate")
	fEave(k, "Head", "Brim", 1.22, .48, 4.80, 5.06, -.99, BASALT_DK, "Slate")
	fT(k, "Collar", 1.66, 1.58, 3.66, 4.06, 0, BASALT, "Slate")
	-- The rank's one glow, the size of a coin, stood on its corner at the throat.
	A(k, "Torso", "Ember", V(.24, .24, .08), CF(0, 3.86 - T_Y, -.82) * deg(0, 0, 45), EMBER_LIT, "Neon",
		{ light = { 6, .5 } })
	fT(k, "Tunic", 1.60, 1.18, 2.16, 3.66, -.06, BASALT, "Fabric")
	fT(k, "Belt", 1.66, 1.26, 1.86, 2.16, -.06, BASALT_DK, "Slate")
	fT(k, "Hem", 1.86, 1.34, 1.44, 1.86, -.06, BASALT_DK, "Slate")
	-- The rank's shoulder line, and the family's smallest: ONE shallow magma plate on the
	-- RIGHT, a wedge falling outboard, sat on the arm's own top and cut 1.06 over the bare
	-- 1.00 arm so it barely overhangs - against a left arm wearing nothing but a soot strap
	-- around the bicep. Two different things at the same height, which is what stops the
	-- figure reading as a pair of matching boxes stuck to the chest.
	fCap(k, "Right Arm", 1, "PlateR", 1.06, 1.08, 4.00, 4.28, 1.00, true, MAGMA, "Slate")
	fS(k, "Left Arm", -1, "StrapL", 1.06, 1.08, 3.70, 3.88, 1.00, 0, BASALT_DK, "Slate")
	for _, a in ipairs(ARMS) do
		fS(k, a[1], a[2], "Wrap" .. a[3], 1.08, 1.10, 2.02, 2.62, 1.00, 0, BASALT_DK, "Slate")
	end
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], .56, .74, .44, 1.88, .53, -.04, 0, ASHCLOTH, "Fabric")
		fL(k, l[1], l[2], "Boot" .. l[3], .78, 1.02, 0, .44, .55, -.16, 0, BASALT, "Slate")
	end
	return k
end

-- ── The Magma Juggernaut ─────────────────────────────────────────────────────
-- A wall: widest at the hip, and the one rank with no taper anywhere on it, because a wedge
-- reads as a shoulder that gives and this one does not. Each arm is ONE unbroken 1.20 column
-- from fist to shoulder, and the weight sits on the LEFT of it alone - a flat-topped iron
-- plate cut 1.32, only .06 proud of that column a side, so it hugs the arm rather than
-- shelving out over it - against a plain riveted iron band on the right a quarter as tall.
-- The plate stops dead at y 4.54, well below the helm, so the head still stands clear and the
-- rank has a neck. The helm is the family's dark anvil box under one flat iron cap, so the
-- top of the figure is a horizontal lid and not a point. The fauld flares to 2.66, entirely
-- below the hands, so the outline steps out once at the hip and is legs from there down onto
-- the heaviest boots. Iron on the brow, the plate, the band, the cap and the boots is the one
-- light thing on a dark body; the fauld is the one warm note and the furnace slit the one
-- glow. Eighteen pieces.
local function magmaJuggernautKit()
	local k = {}
	fH(k, "Helm", 1.74, 1.74, 4.84, 5.56, .12, BASALT, "Metal")
	fH(k, "Cap", 1.52, 1.52, 5.56, 5.74, .12, FORGE_IRON, "Metal")
	fEave(k, "Head", "Brow", 1.58, .46, 4.52, 4.84, -.98, FORGE_IRON, "Metal")
	fT(k, "Gorget", 1.78, 1.80, 3.58, 4.14, .02, BASALT_DK, "Metal")
	fT(k, "Cuirass", 1.70, 1.66, 2.28, 3.58, -.06, BASALT, "Metal")
	-- The rank's one glow: a furnace slit across the breast, flush on the cuirass face.
	A(k, "Torso", "Furnace", V(.80, .16, .10), CF(0, 3.04 - T_Y, -.94), EMBER_LIT, "Neon",
		{ light = { 8, .7 } })
	fT(k, "Belt", 1.84, 1.74, 1.96, 2.28, -.06, BASALT_DK, "Slate")
	fT(k, "Fauld", 2.66, 1.90, 1.30, 1.96, -.06, MAGMA, "Slate")
	-- Both arms are ONE unbroken 1.20 column from fist to shoulder, and the rank's weight sits
	-- on the LEFT of it alone: a flat-topped iron plate cut 1.32, which is .06 proud of that
	-- column a side - it hugs the arm instead of shelving out over it - and it is still the
	-- only shoulder in the family with no chamfer, because the wall does not give. The right
	-- shoulder wears a plain riveted band a quarter as tall, so the two sides never match.
	for _, a in ipairs(ARMS) do
		fS(k, a[1], a[2], "Sleeve" .. a[3], 1.20, 1.26, 2.66, 4.10, 1.00, 0, SCORCH, "Metal")
		fS(k, a[1], a[2], "Fist" .. a[3], 1.20, 1.26, 2.00, 2.66, 1.00, 0, BASALT_DK, "Metal")
	end
	fS(k, "Left Arm", -1, "PlateL", 1.32, 1.38, 4.10, 4.54, 1.00, 0, FORGE_IRON, "Metal")
	fS(k, "Right Arm", 1, "BandR", 1.26, 1.32, 4.10, 4.26, 1.00, 0, FORGE_IRON, "Metal")
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], .76, .90, .54, 1.84, .60, -.04, 0, BASALT_DK, "Metal")
		fL(k, l[1], l[2], "Boot" .. l[3], 1.00, 1.26, 0, .54, .62, -.20, 0, FORGE_IRON, "Metal")
	end
	return k
end

-- ── The Solar Dominator ──────────────────────────────────────────────────────
-- The spike, and the only rank that goes UP where the others go out. A bronze helm caps the
-- crown, leaves the whole face open below 4.60, and carries a brass fin that is the family's
-- highest point; its shoulder line is cut on the DIAGONAL, one tall pauldron on the RIGHT
-- chamfered UP into a V that carries the eye to the crest - the steepest cap in the family,
-- and only .08 proud of the bare arm a side - against one thin bronze ring on the left bicep
-- and nothing above it. The pauldron stops at 4.54 so the helm above it is unmistakably a
-- head. The chest is cut to 1.48 - a quarter stud of daylight each side, the widest underarm
-- notch in the family - and cinched narrower still at a sash before a fauld that stays
-- deliberately narrow, so this rank has a waist in the silhouette and not only in the colour,
-- and one brass tabard hangs from that fauld between the legs. The forearms are bare skin for
-- more than a stud between shoulder and gauntlet, which is the whole reason the arms read as
-- arms. Brass on crest and tabard is the one light note on scorched bronze; the sun bead is
-- the one glow. Eighteen pieces.
local function solarDominatorKit()
	local k = {}
	fH(k, "Helm", 1.56, 1.58, 4.60, 5.30, .04, FORGE_BRONZE, "Metal")
	fEave(k, "Head", "Crest", .34, 1.30, 5.30, 6.06, .18, BRASS_LT, "Metal")
	-- Two cheek plates flush on the skull's own sides, from the gorget up to the helm: they
	-- frame the open face and make the head tall and narrow, which is the spike's read.
	for _, s in ipairs({ -1, 1 }) do
		A(k, "Head", "Cheek" .. (s < 0 and "L" or "R"), V(.22, .48, .88),
			CF(s * .86, 4.36 - H_Y, -.04), BRONZE_DK, "Metal")
	end
	fT(k, "Gorget", 1.70, 1.70, 3.56, 4.12, 0, BRONZE_DK, "Metal")
	fT(k, "Cuirass", 1.48, 1.38, 2.42, 3.56, -.08, FORGE_BRONZE, "Metal")
	-- The rank's one glow: a sun bead stood on its corner, flush on the cuirass face.
	A(k, "Torso", "Sun", V(.32, .32, .08), CF(0, 3.02 - T_Y, -.81) * deg(0, 0, 45), SUN_LIT, "Neon",
		{ light = { 8, .7 } })
	fT(k, "Sash", 1.32, 1.32, 2.00, 2.42, -.08, BRONZE_DK, "Metal")
	fT(k, "Fauld", 2.00, 1.56, 1.32, 2.00, -.08, FORGE_BRONZE, "Metal")
	fT(k, "Tabard", .58, .14, .78, 1.32, -.93, BRASS_LT, "Fabric")
	-- The spike's shoulder line is a diagonal, not a pair. ONE tall pauldron on the RIGHT,
	-- the chamfer LIFTING outboard so the V carries the eye up to the crest, cut 1.16 over a
	-- bare 1.00 arm - the family's steepest cap and the opposite of the wall - against a left
	-- shoulder wearing one thin bronze ring around the bicep and nothing above it.
	fCap(k, "Right Arm", 1, "PauldronR", 1.16, 1.24, 4.00, 4.54, 1.00, false, BRONZE_DK, "Metal")
	fS(k, "Left Arm", -1, "RingL", 1.10, 1.16, 3.82, 3.98, 1.00, 0, BRONZE_DK, "Metal")
	for _, a in ipairs(ARMS) do
		fS(k, a[1], a[2], "Gauntlet" .. a[3], 1.18, 1.22, 2.00, 2.74, 1.00, 0, BRONZE_DK, "Metal")
	end
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], .62, .80, .50, 1.92, .57, -.04, 0, BRONZE_DK, "Metal")
		fL(k, l[1], l[2], "Greave" .. l[3], .82, 1.10, 0, .50, .59, -.18, 0, FORGE_BRONZE, "Metal")
	end
	return k
end

-- ── The Infernal Colossus ────────────────────────────────────────────────────
-- The family's boss, told apart from the Juggernaut by WHERE its mass is rather than by how
-- much of it there is: the Juggernaut is widest at the hip and flat on top, the Colossus is
-- widest at the TOP and pulled in at the hip. Two iron horns stand flush on the crown's own
-- sides and rise past it, so the head is a wide T three and a quarter studs across - the one
-- light thing on the darkest body in the family. Both arms are the SAME plain 1.22 column
-- from fist to shoulder and only the LEFT carries a cap: the family's biggest, one magma
-- wedge falling outboard off the top of that column and .06 proud of it a side, against a
-- bare sleeved right arm. That is the one big asymmetry, it is the size of that single wedge
-- against nothing that reads as rank, and it keeps the sword hand clear, since EnemyCombat
-- welds the blade into that hand. Deepest chest and biggest feet in the family, and one heart
-- vent cracked down the breast for its one glow. Eighteen pieces.
local function infernalColossusKit()
	local k = {}
	fH(k, "Brow", 1.22, .42, 4.56, 4.92, -.96, BASALT_DK, "Slate")
	fH(k, "Crown", 1.60, 1.60, 4.92, 5.56, .05, BASALT, "Slate")
	-- The horns: wedges quarter-turned about Y so the slope runs across the figure, tall at
	-- the outboard end and falling in onto the crown, stood with their inboard faces flush on
	-- the crown's own sides, so the top of the boss is a wide T and nothing enters the crown.
	for _, s in ipairs({ -1, 1 }) do
		A(k, "Head", "Horn" .. (s < 0 and "L" or "R"), V(.62, .94, .58),
			CF(s * 1.09, 5.36 - H_Y, .05) * deg(0, s * 90, 0), BASALT_DK, "Metal", WEDGE)
	end
	fT(k, "Gorget", 1.80, 1.82, 3.52, 4.14, .02, BASALT_DK, "Metal")
	fT(k, "Chest", 1.76, 1.74, 2.30, 3.52, -.06, BASALT, "Metal")
	-- The boss's one glow: a vent cracked down the breast, flush on the chest face.
	A(k, "Torso", "HeartVent", V(.28, .86, .10), CF(0, 2.94 - T_Y, -.98), EMBER_LIT, "Neon",
		{ light = { 10, .9 } })
	fT(k, "Belt", 1.88, 1.82, 1.96, 2.30, -.06, BASALT_DK, "Slate")
	fT(k, "Fauld", 2.42, 1.92, 1.32, 1.96, -.06, BASALT_DK, "Metal")
	-- The one big asymmetry, cut the way the quarry brute cuts its: both arms are the SAME
	-- plain 1.22 column from fist to shoulder, and only the LEFT carries a cap - the family's
	-- biggest, one magma wedge falling outboard off the top of that column and .06 proud of
	-- it a side. The right shoulder is a bare sleeve, which is what keeps the sword hand
	-- clear, and it is the size of that one wedge against nothing that reads as rank.
	fS(k, "Left Arm", -1, "SleeveL", 1.22, 1.28, 2.70, 4.02, 1.00, 0, SCORCH, "Metal")
	fS(k, "Left Arm", -1, "FistL", 1.22, 1.28, 2.00, 2.70, 1.00, 0, BASALT_DK, "Metal")
	-- The sword arm's cuff rides .16 higher, so even with nothing on that shoulder the right
	-- column is banded differently from the left instead of mirroring it.
	fS(k, "Right Arm", 1, "SleeveR", 1.22, 1.28, 2.86, 4.02, 1.00, 0, SCORCH, "Metal")
	fS(k, "Right Arm", 1, "FistR", 1.22, 1.28, 2.00, 2.86, 1.00, 0, BASALT_DK, "Metal")
	fCap(k, "Left Arm", -1, "PauldronL", 1.34, 1.40, 4.02, 4.54, 1.00, true, MAGMA, "Slate")
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], .82, .98, .54, 1.84, .62, -.04, 0, BASALT, "Metal")
		fL(k, l[1], l[2], "Foot" .. l[3], 1.08, 1.40, 0, .54, .64, -.22, 0, BASALT_DK, "Metal")
	end
	return k
end

OUTFITS.CinderFiend = { colors = FIEND_BODY, hide = CINDER_HIDE, accessories = cinderFiendKit() }
OUTFITS.MagmaJuggernaut = { colors = JUGGERNAUT_BODY, hide = CINDER_HIDE, accessories = magmaJuggernautKit() }
OUTFITS.SolarDominator = { colors = SOLAR_BODY, hide = CINDER_HIDE, accessories = solarDominatorKit() }
OUTFITS.Boss_InfernalColossus = { colors = COLOSSUS_BODY, hide = CINDER_HIDE, accessories = infernalColossusKit() }

-- ── The Void Reach ───────────────────────────────────────────────────────────
-- Retailored 2026-09-23. Until now these four were the LAST kits still on the legacy
-- regionalKit() path, and they are the exact thing Alex rejected: a flat TunicFront and
-- TunicBack panel bolted on either side of the rig, a 1.35 shoulder puck floating on a
-- 1.00 arm, and two neon eyes doing all of the character work. They are rebuilt here the
-- way the approved quarry, permafrost, briar and storm families are cut.
--
-- The reference is a hooded reaper on a plain field: ONE big angular hood-and-cloak
-- silhouette, a near-black palette, a bone mask as the focal point, and one accent. Four
-- craft rules, the same ones the approved families hold:
--   1. One form per slot, and no more than eighteen forms per kit. When a shape has to read
--      harder it is made BIGGER, never busier.
--   2. NOTHING CLIPS. Torso and legs are hidden and rebuilt as garment; the head and both
--      arms stay the real rig parts. Every piece sits flush against its neighbour or wholly
--      contains the limb inside it. Torso pieces stay inside |x| < 1 wherever the arms hang
--      (y 2..4), so all the width at the shoulder comes from a form sat ON an arm and all
--      the width at the hip from a cloak hung below the hands at y < 2.00. Every hood is cut
--      wide and deep enough to CONTAIN the head's own 1.5 box rather than to cut across it,
--      and it caps past the crown at 5.25 so nothing stood on its roof reaches the skull.
--      Every mask sits flush on the face, floored on the collar and ceilinged on the hood.
--      The clipping check over the real export is zero intersecting pairs on all four.
--   3. IT IS STILL A CHARACTER, and an arm is a LIMB rather than a slab. Round 0's render
--      failed on exactly this: the two light ranks carried nothing at all on their arms, so
--      each arm rendered as one bare 1x2x1 box in a pale colour beside a dark body - the
--      "slabs bolted onto a blocky rig" complaint arriving by the back door. Every rank now
--      bands its arms, so a limb reads as shoulder, sleeve and hand rather than as one
--      brick: the two light ranks get a soft sleeve and no cap at all (which is still what
--      makes them read light), and the two heavy ranks get a cap over theirs.
--   4. VALUE FIRST, and ONE glow each. Round 0's other failure was a monochrome one - four
--      figures in a single mid-violet, so no form could be told from its neighbour. The
--      family now runs four steps the way the approved storm ranks do: a near-black violet,
--      a mid violet, a light lilac and BONE, with the bone doing the focal work the neon
--      was standing in for. The whole family's neon budget is one slit or mote per rank,
--      none wider than .52.
--   5. A HOOD AND A CLOAK, because that is what the brief asks for and round 2 had neither.
--      Every rank wears a genuine hood - an angular crown block over the skull, a wedge peak
--      or crest off its roof, and a brim jutting past the brow - and a cloak cut as ONE big
--      slab off the back with ONE torn wedge hem under it. Two shapes, never a scatter of
--      small ones, and both hung at z .79 or deeper so they fall behind both arms.
--   6. ONE SHOULDER LEADS, on ALTERNATING SIDES. Round 2 put a matching pair of near
--      torso-sized boxes on every figure, which is the exact fault that cost the cinder
--      family a round. No rank wears a matching pair now: each has ONE dominant cap (Shade
--      LEFT, Wisp RIGHT, Tormentor LEFT, Wraith RIGHT), and the off side is plainly lesser -
--      a narrower, lower sleeve with nothing above it. Every cap is cut to within .05-.06 a
--      side of the sleeve beneath it and no more than .12 a side of the 1.00 arm, so it hugs
--      the limb instead of shelving out over it, and every cap floors at 3.94 - inside the
--      arm's own top at 4.00, NEVER above it - with the sleeve running continuously up to
--      exactly that floor. That is the storm seating rule, unchanged.
-- Told apart by outline alone, with the colours off:
--   Void Shade     SMALL AND NARROW, and the shortest. A hood whose peak is swept BACK and
--                  low, one small pauldron FALLING off the LEFT against a narrower bare
--                  right shoulder, a long coat torn into two tails, and pale boots. 17 pieces.
--   Astral Wisp    A SPIKE, and the only rank with no feet. The thinnest chest and the
--                  narrowest cloak in the family under a veil carrying one tall blade fin,
--                  one fin RISING off the RIGHT shoulder, and two columns that stop clear of
--                  the floor so it reads as drifting. 17 pieces.
--   Abyss          BROAD AND LOW, and lopsided. The widest, lowest hood in the family with
--   Tormentor      ONE blunt horn off the LEFT of its roof and the deepest brim; ONE huge
--                  pauldron FALLING outboard over a sleeved LEFT arm against a plain right
--                  sleeve and fist; the widest fauld flaring past everything above it, a
--                  widest coat and tails in the family, and the heaviest feet. 17 pieces.
--   Void Wraith    TALL AND CROWNED, and the most threatening in outline. The family's
--                  highest point by a quarter of a head: a crested hood with ONE full horn
--                  off the right and ONE broken stub off the left, a brim jutting over the
--                  tallest bone mask, ONE big fin RISING off the RIGHT shoulder where the
--                  Tormentor's falls, and the family's biggest cloak over one long unbroken
--                  robe onto two greaves. 18 pieces.
local VOID_DEEP = rgb(124, 56, 240)
local VOID_CLOTH = rgb(238, 226, 255)
local VOID_LILAC = rgb(200, 168, 255)
local VOID_BONE = rgb(255, 250, 240)
local VOID_BONE_DK = rgb(236, 222, 255)
local RIFT = rgb(255, 128, 255)
local WISP_PALE = rgb(240, 232, 255)
local WISP_DEEP = rgb(120, 96, 255)

-- The shoulder seat the storm family settled on and Alex approved: a cap floors AT or a
-- hair BELOW the arm's own top so it swallows the shoulder instead of shelving above it,
-- the piece under it runs up to exactly that floor, and the cap is at most .10 wider than
-- that piece. Collars top level with the cap floor so the shoulder line is unbroken.
local V_SEAT, V_ARMTOP = .98, 4.00

local VOID_HIDE = { "Torso", "Left Leg", "Right Leg" }
-- The bare stretch of arm below a sleeve is a colour choice, not a leftover: it has to
-- differ from the sleeve above it or the whole limb flattens back into one slab.
-- Every rank's ARMS are the darkest value in its kit. Round 2's arms were bone, and the
-- half stud of bare limb standing above a sleeve rendered as a bright cream lid on top of
-- each shoulder - which is most of why the two shoulders read as a matching pair of slabs.
-- Dark arms make that sliver disappear and let the ONE pale band on a limb be a choice.
local SHADE_BODY = {
	Head = VOID_BONE, Torso = VOID_DEEP,
	["Left Arm"] = VOID_DEEP, ["Right Arm"] = VOID_DEEP,
	["Left Leg"] = VOID_DEEP, ["Right Leg"] = VOID_DEEP,
}
local WISP_BODY = {
	Head = VOID_BONE, Torso = WISP_DEEP,
	["Left Arm"] = WISP_DEEP, ["Right Arm"] = WISP_DEEP,
	["Left Leg"] = WISP_DEEP, ["Right Leg"] = WISP_DEEP,
}
local TORMENTOR_BODY = {
	Head = VOID_DEEP, Torso = VOID_DEEP,
	["Left Arm"] = VOID_DEEP, ["Right Arm"] = VOID_DEEP,
	["Left Leg"] = VOID_DEEP, ["Right Leg"] = VOID_DEEP,
}
local WRAITH_BODY = {
	Head = VOID_DEEP, Torso = VOID_DEEP,
	["Left Arm"] = VOID_DEEP, ["Right Arm"] = VOID_DEEP,
	["Left Leg"] = VOID_DEEP, ["Right Leg"] = VOID_DEEP,
}

-- ── The Void Shade ───────────────────────────────────────────────────────────
local function voidShadeKit()
	local k = {}
	-- THE HOOD, and it is a real hood rather than a box: a deep angular crown cut wider and
	-- deeper than the head's own 1.5 box so it CONTAINS the skull, a wedge PEAK swept back
	-- off its roof, and a brim jutting a half stud past the brow. Three forms, one shape.
	fH(k, "Hood", 1.62, 1.74, 4.44, 5.30, .06, VOID_DEEP, "Fabric")
	-- Swept BACK and low, so the Shade's point falls away behind it: what keeps this the
	-- smallest, least threatening outline in the family.
	fEave(k, "Head", "Peak", .84, 1.50, 5.30, 5.62, .28, VOID_DEEP, "Fabric")
	fEave(k, "Head", "Brim", 1.34, .62, 4.22, 4.44, -1.06, VOID_CLOTH, "Fabric")
	-- The rank's one glow, in the open face under the brim. One, and nothing else lit.
	fH(k, "Eyes", .48, .06, 4.00, 4.10, -.78, RIFT, "Neon")
	fT(k, "Cowl", V_SEAT * 2, 1.58, 3.42, 3.94, 0, VOID_DEEP, "Fabric")
	fT(k, "Shroud", 1.24, 1.10, 2.00, 3.42, -.04, VOID_CLOTH, "Fabric")
	-- THE CLOAK, in THREE large shapes and no small ones, cut so that it is actually SEEN:
	-- round 2's fell only down the back, inboard of two arms that stand at |x| 1..2, and the
	-- arms hid every stud of it. A cloak can only show where an arm is not, so the weight of
	-- it hangs BELOW the hands at y < 2.00, where it is free to flare past everything above
	-- it - one wide coat, one torn wedge hem under that - and the back slab is what carries
	-- the line up to the shoulder behind the arms.
	fT(k, "Coat", 2.06, 1.54, .80, 2.00, -.04, VOID_DEEP, "Fabric")
	A(k, "Torso", "Cloak", V(1.74, 2.92, .26), CF(0, 2.51 - T_Y, .92), VOID_CLOTH, "Fabric")
	-- The torn hem, and it is TWO big shapes rather than a scatter: one wedge hung off each
	-- side of the coat, flush on its own face so neither enters it, angled outboard and falling
	-- to the shin. This is the part of the cloak an arm can never hide.
	for _, t in ipairs({ -1, 1 }) do
		fTat(k, t, "Tail" .. (t < 0 and "L" or "R"), .46, 1.10, .34, 1.30, 1.03, -.04, VOID_DEEP, "Fabric")
	end
	-- ONE dominant shoulder, on the LEFT, and the family's smallest: a wedge falling
	-- outboard, floored at 3.94 - a hair inside the arm's own top at 4.00, never above it -
	-- with the sleeve beneath running continuously UP to exactly that floor and .06 narrower
	-- a side, so the cap hugs the arm instead of shelving over it. The RIGHT shoulder carries
	-- nothing and its sleeve is narrower and starts higher. Neither arm is ONE box any more:
	-- every limb is a dark upper sleeve over a pale forearm, which is what stops a 1.1 x 1.6
	-- sleeve from reading as a slab the size of the chest.
	fS(k, "Left Arm", -1, "SleeveL", 1.08, 1.12, 2.60, 3.94, V_SEAT, 0, VOID_DEEP, "Fabric")
	fCap(k, "Left Arm", -1, "PauldronL", 1.20, 1.26, 3.94, 4.38, V_SEAT, true, VOID_CLOTH, "Fabric")
	fS(k, "Left Arm", -1, "ForearmL", 1.12, 1.16, 2.00, 2.60, V_SEAT, 0, VOID_LILAC, "Fabric")
	fS(k, "Right Arm", 1, "SleeveR", 1.02, 1.06, 2.74, 3.98, V_SEAT, 0, VOID_DEEP, "Fabric")
	fS(k, "Right Arm", 1, "ForearmR", 1.06, 1.10, 2.00, 2.74, V_SEAT, 0, VOID_LILAC, "Fabric")
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Boot" .. l[3], .60, .92, 0, 1.05, .48, -.06, 0, VOID_LILAC, "Fabric")
	end
	return k
end

-- ── The Astral Wisp ──────────────────────────────────────────────────────────
local function astralWispKit()
	local k = {}
	-- The rank keeps its LIGHTER value - it is the ghost-light one - but it is cut in the
	-- family's own violets, not in an ivory-and-bronze of its own, so the four read as one
	-- reach. What separates it from its neighbours is VALUE and OUTLINE, never hue.
	fH(k, "Veil", 1.54, 1.62, 4.46, 5.32, .04, WISP_DEEP, "Fabric")
	-- The hood's point is one tall blade fin: the thinnest form in the family and most of
	-- its height, which is the whole read of the spike.
	fEave(k, "Head", "Fin", .30, 1.34, 5.32, 5.98, .18, VOID_LILAC, "Fabric")
	fEave(k, "Head", "Brim", 1.12, .54, 4.24, 4.46, -1.02, WISP_DEEP, "Fabric")
	-- The rank's one glow: a single mote on the open face, smaller than any eye slit.
	fH(k, "Mote", .30, .06, 4.02, 4.10, -.78, RIFT, "Neon")
	fT(k, "Collar", V_SEAT * 2, 1.56, 3.48, 3.94, 0, WISP_DEEP, "Fabric")
	-- The narrowest chest in the family, so the underarm daylight is widest here.
	fT(k, "Shroud", 1.10, 1.00, 2.00, 3.48, -.04, VOID_LILAC, "Fabric")
	-- The family's narrowest cloak, cut the same three ways: a coat hung below the hands, a
	-- torn wedge hem under it and a back slab up to the collar - all of it stopping clear of
	-- the floor, because this is the rank that drifts.
	fT(k, "Coat", 1.78, 1.38, .72, 2.00, -.04, VOID_CLOTH, "Fabric")
	A(k, "Torso", "Cloak", V(1.50, 2.90, .24), CF(0, 2.03 - T_Y, .90), WISP_DEEP, "Fabric")
	-- The torn hem, and it is TWO big shapes rather than a scatter: one wedge hung off each
	-- side of the coat, flush on its own face so neither enters it, angled outboard and falling
	-- to the shin. This is the part of the cloak an arm can never hide.
	for _, t in ipairs({ -1, 1 }) do
		fTat(k, t, "Tail" .. (t < 0 and "L" or "R"), .40, .96, .30, 1.24, .89, -.04, WISP_DEEP, "Fabric")
	end
	-- ONE dominant shoulder, and it is on the RIGHT - the opposite side to the Shade's, so
	-- no two ranks in the family lean the same way. It RISES outboard where the Shade's
	-- falls, seated at 3.94 inside the arm's own 4.00 with the sleeve running up to exactly
	-- that floor. The left shoulder is bare and its sleeve is narrower and starts higher, and
	-- both limbs are banded sleeve-over-wrap so neither is one box.
	fS(k, "Right Arm", 1, "SleeveR", 1.08, 1.12, 2.60, 3.94, V_SEAT, 0, VOID_LILAC, "Fabric")
	fCap(k, "Right Arm", 1, "FinR", 1.20, 1.28, 3.94, 4.40, V_SEAT, false, WISP_DEEP, "Fabric")
	fS(k, "Right Arm", 1, "WrapR", 1.12, 1.16, 2.00, 2.60, V_SEAT, 0, WISP_DEEP, "Fabric")
	fS(k, "Left Arm", -1, "SleeveL", 1.02, 1.06, 2.74, 3.98, V_SEAT, 0, VOID_LILAC, "Fabric")
	fS(k, "Left Arm", -1, "WrapL", 1.06, 1.10, 2.00, 2.74, V_SEAT, 0, WISP_DEEP, "Fabric")
	-- No feet: two columns that stop clear of the floor, so the rank reads as drifting.
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Trail" .. l[3], .48, .76, .30, 1.14, .46, -.04, 0, VOID_CLOTH, "Fabric")
	end
	return k
end

-- ── The Abyss Tormentor ──────────────────────────────────────────────────────
local function abyssTormentorKit()
	local k = {}
	-- No neck to speak of: the family's WIDEST and LOWEST hood, dropped over the crown so the
	-- head sits sunk between the shoulders. It tops at 5.26, past the head's own crown at
	-- 5.25, so the cowl contains the skull instead of cutting across it, and its brim is the
	-- deepest in the family - the heavy angular brow that makes this rank read as a hood
	-- rather than as a helmet.
	fH(k, "Cowl", 1.78, 1.76, 4.42, 5.26, .04, VOID_CLOTH, "Slate")
	-- ONE blunt horn, on the LEFT only, quarter-turned so it rises outboard: the head end of
	-- the same asymmetry the shoulders carry. Flush on the cowl's own roof, and low, because
	-- this rank's mass is at the shoulder and the hip and never at the top.
	A(k, "Head", "Horn", V(1.06, .52, .52), CF(-.50, 5.52 - H_Y, .04) * deg(0, -90, 0),
		VOID_LILAC, "Slate", WEDGE)
	fEave(k, "Head", "Brim", 1.46, .64, 4.16, 4.42, -1.08, VOID_DEEP, "Slate")
	-- The focal point, and it is VALUE not neon: a face-sized bone plate flush on the head,
	-- held between the gorget's roof and the cowl's floor.
	fH(k, "Mask", 1.00, .14, 3.92, 4.42, -.82, VOID_BONE, "SmoothPlastic")
	-- The rank's one glow, a slit on the mask's own front face.
	fH(k, "Eyes", .38, .06, 4.06, 4.16, -.92, RIFT, "Neon")
	fT(k, "Gorget", V_SEAT * 2, 1.58, 3.42, 3.92, 0, VOID_DEEP, "Slate")
	-- The chest is cut narrower than the shoulder seat (half-width .81 against 1.00) so a
	-- real underarm notch of dark shows and the arm never welds itself to the body.
	fT(k, "Chest", 1.60, 1.44, 2.00, 3.42, -.06, VOID_CLOTH, "Slate")
	-- THE CLOAK, and on this rank it is the family's heaviest: one COAT 2.44 across hung
	-- entirely below the hands at y < 2.00, where it is free to flare past everything above
	-- it; one torn wedge hem 2.60 across beneath that, the widest form on any of the four;
	-- and one back slab carrying the line up to the gorget behind both arms. Three large
	-- shapes, no small ones.
	fT(k, "Coat", 2.44, 1.78, .62, 2.00, -.06, VOID_DEEP, "Slate")
	A(k, "Torso", "Cloak", V(1.96, 2.78, .30), CF(0, 2.53 - T_Y, .99), VOID_DEEP, "Slate")
	-- The torn hem, and it is TWO big shapes rather than a scatter: one wedge hung off each
	-- side of the coat, flush on its own face so neither enters it, angled outboard and falling
	-- to the shin. This is the part of the cloak an arm can never hide.
	for _, t in ipairs({ -1, 1 }) do
		fTat(k, t, "Tail" .. (t < 0 and "L" or "R"), .54, 1.20, .18, 1.30, 1.22, -.06, VOID_DEEP, "Slate")
	end
	-- ONE huge shoulder, on the LEFT, and it FALLS outboard - the heavy sloping-down line.
	-- It floors at 3.94, a hair under the arm's own top at 4.00 and never above it, and the
	-- sleeve under it runs continuously UP to exactly that floor and is only .06 narrower a
	-- side, so the overhang is a hair rather than a shelf with open air beneath it. Nothing
	-- on the right shoulder at all, that sleeve is cut narrower and starts higher, and the
	-- left forearm is bare where the right wears a fist - so the two sides of the figure are
	-- different SHAPES at three separate heights and not a matching pair of boxes.
	fS(k, "Left Arm", -1, "SleeveL", 1.10, 1.18, 2.62, 3.94, V_SEAT, 0, VOID_CLOTH, "Slate")
	fCap(k, "Left Arm", -1, "PauldronL", 1.22, 1.30, 3.94, 4.44, V_SEAT, true, VOID_LILAC, "Slate")
	fS(k, "Right Arm", 1, "SleeveR", 1.02, 1.08, 2.60, 3.98, V_SEAT, 0, VOID_CLOTH, "Slate")
	fS(k, "Right Arm", 1, "FistR", 1.08, 1.14, 2.00, 2.60, V_SEAT, 0, VOID_DEEP, "Slate")
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Foot" .. l[3], 1.00, 1.30, 0, 1.20, .56, -.14, 0, VOID_LILAC, "Slate")
	end
	return k
end

-- ── The Void Wraith ──────────────────────────────────────────────────────────
local function voidWraithKit()
	local k = {}
	-- The boss's hood is the family's TALLEST and the only one crowned: a deep angular crown,
	-- a thin crest fin along it, and an ASYMMETRIC pair of horns - one full horn rising off
	-- the right of the roof to the family's highest point at 6.32, one broken stub off the
	-- left - so even the head is lopsided and the outline is unmistakably this rank's.
	fH(k, "Hood", 1.72, 1.76, 4.60, 5.46, .04, VOID_DEEP, "Fabric")
	fEave(k, "Head", "Crest", .32, 1.44, 5.46, 6.04, .18, VOID_CLOTH, "Fabric")
	A(k, "Head", "HornR", V(.86, .88, .62), CF(.54, 5.90 - H_Y, .06) * deg(0, 90, 0),
		VOID_LILAC, "Slate", WEDGE)
	A(k, "Head", "HornL", V(.56, .44, .52), CF(-.52, 5.68 - H_Y, .06) * deg(0, -90, 0),
		VOID_LILAC, "Slate", WEDGE)
	-- The brim juts a full half stud past the mask, flush under the hood: the angular brow
	-- that keeps a boss hood from being a bucket.
	fEave(k, "Head", "Brim", 1.48, .64, 4.34, 4.60, -1.08, VOID_CLOTH, "Fabric")
	-- The family's other bone face, and the tallest.
	fH(k, "Mask", 1.04, .14, 3.92, 4.34, -.82, VOID_BONE, "SmoothPlastic")
	-- The whole family's brightest note, and it is the size of a coin. One, and no more.
	fH(k, "Eyes", .42, .06, 4.04, 4.14, -.92, RIFT, "Neon")
	-- The gorget tops at 3.92, level with the fin's floor. A RISING cap is paper thin at its
	-- inboard end, so a collar standing above that end leaves a wedge of open air beside the
	-- neck; cut level, the collar's roof and the fin's floor are one unbroken shoulder line.
	fT(k, "Gorget", V_SEAT * 2, 1.58, 3.40, 3.92, 0, VOID_CLOTH, "Fabric")
	fT(k, "Chest", 1.66, 1.50, 2.00, 3.40, -.04, VOID_DEEP, "Fabric")
	-- THE CLOAK, and it is the largest on any of the four: one coat 2.30 across hung entirely
	-- below the hands, one torn wedge hem 2.52 across beneath it, and one back slab up to the
	-- gorget behind both arms. It is what makes the boss threatening in OUTLINE rather than
	-- in detail, and every stud of it lives where an arm is not, so it costs no clip and -
	-- unlike round 2's - it is actually visible from the front.
	fT(k, "Coat", 2.30, 1.72, .58, 2.00, -.04, VOID_DEEP, "Fabric")
	A(k, "Torso", "Cloak", V(2.06, 2.80, .30), CF(0, 2.52 - T_Y, .99), VOID_DEEP, "Fabric")
	-- The torn hem, and it is TWO big shapes rather than a scatter: one wedge hung off each
	-- side of the coat, flush on its own face so neither enters it, angled outboard and falling
	-- to the shin. This is the part of the cloak an arm can never hide.
	for _, t in ipairs({ -1, 1 }) do
		fTat(k, t, "Tail" .. (t < 0 and "L" or "R"), .52, 1.16, .14, 1.34, 1.15, -.04, VOID_DEEP, "Fabric")
	end
	-- ONE dominant shoulder, on the RIGHT, and the family's biggest: it RISES outboard where
	-- the Tormentor's single pauldron FALLS, so the two heavy ranks never share an outline.
	-- It floors at 3.94, inside the arm's own top at 4.00, with the sleeve beneath running up
	-- to exactly that floor. The left shoulder carries nothing and its sleeve is narrower and
	-- starts higher, so the boss's two arms differ in cap, in width and in banding at once.
	fS(k, "Right Arm", 1, "SleeveR", 1.10, 1.16, 2.62, 3.94, V_SEAT, 0, VOID_CLOTH, "Fabric")
	fCap(k, "Right Arm", 1, "FinR", 1.22, 1.32, 3.94, 4.50, V_SEAT, false, VOID_LILAC, "Slate")
	fS(k, "Left Arm", -1, "SleeveL", 1.02, 1.08, 2.74, 3.98, V_SEAT, 0, VOID_CLOTH, "Fabric")
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Greave" .. l[3], .88, 1.18, 0, 1.16, .56, -.08, 0, VOID_DEEP, "Fabric")
	end
	return k
end

OUTFITS.VoidShade = { colors = SHADE_BODY, hide = VOID_HIDE, accessories = voidShadeKit() }
OUTFITS.AstralWisp = { colors = WISP_BODY, hide = VOID_HIDE, accessories = astralWispKit() }
OUTFITS.AbyssTormentor = { colors = TORMENTOR_BODY, hide = VOID_HIDE, accessories = abyssTormentorKit() }
OUTFITS.Boss_VoidWraith = { colors = WRAITH_BODY, hide = VOID_HIDE, accessories = voidWraithKit() }
-- SolarDominator is tailored with the Cinder Forge above.
-- Boss_CelestialTitan is tailored with the Storm family further down.

-- ── Briarwood ────────────────────────────────────────────────────────────────
-- Overgrown clothes cut the way the quarry gang and the Permafrost Glade are cut: FEW,
-- LARGE, CRISP forms. Two briar attempts died before this one. The first was slabs bolted
-- onto the rig with neon eyes and a litter of pencil thorns; the second went the other way
-- and turned every rank into a stack of balls and barrels, which Alex rejected as clipping
-- and "too round". So this family is BLOCKS and WEDGES only - not one Ball, not one
-- Cylinder - because bark splits flat and roots grow in angles, and the four rules the
-- approved families hold are held here:
--   1. One form per slot, no more than eighteen forms per kit, and every form BIG: one hood,
--      one collar, one tunic, one belt, one hem, one thorn, one boot per leg. Nothing thin.
--   2. NOTHING CLIPS. Torso and legs are hidden and rebuilt as garment; every piece sits on
--      the body or flush against its neighbour, or wholly contains the limb inside it.
--      Torso pieces stay inside |x| < 1 wherever the arms hang, so all the width at the
--      shoulder comes from wedges sat ON the arms and all the width at the hip from a fauld
--      hung below the hands. The clipping check over the real export is zero pairs.
--   3. IT IS STILL A CHARACTER. Both arms are the bare rig on every rank, ending in a bark
--      bracer or a root fist; the stalker and the brute keep the rig's own head and open
--      face; legs are two columns with daylight between them and one boot each.
--   4. Warm, friendly colour, one accent per rank. Honey bark and bright leaf, teal cloth on
--      the stalker, one amber seed on the stalker's sash, one pale heartwood shoulder on the
--      brute, and the family's whole neon budget is one coin-sized sap knot on the warden.
-- Told apart by outline alone, with the colours off:
--   Thorn Stalker    LIGHT AND LOW. A pointed leaf hood swept back off an open face, the
--                    whole tunic stooped 8 degrees forward about the waist, the narrowest
--                    chest and thinnest legs in the family, one thorn rising off the left
--                    shoulder and nothing on the right, and a leaf hem that flares past the
--                    tunic at the bottom corners. Sixteen pieces.
--   Briar Brute      HEAVY AND WIDE. No neck: a moss cap and a heavy bark brow sunk straight
--                    into a wide collar over a dark eye band, the whole trunk stooped 8
--                    degrees forward about the waist, ONE flat heartwood shoulder slab sat
--                    on the left arm over a bark plate hung on its outer face against a bare
--                    right arm ending in a root fist, a hump on its back, root hips flaring
--                    past everything above them, and the heaviest boots. Sixteen pieces.
--   Rootbound Warden A TREE. The tallest: the rig head is hidden under a tall stump of a
--                    skull carrying one sap knot, two leaf canopy slabs and a tip above it,
--                    the whole crown cocked 6 degrees to one side like a crooked tree, a
--                    full-width collar bridging both shoulders over a trunk cut in beneath
--                    it, both shoulders as branches lifted UP where the brute's is flat, and
--                    one fall of vine down the back to the calves. Eighteen pieces.
-- Round 1 (2026-09-23) fixed what the critics named on round 0: the brute's tan wedge that
-- read as a roof beside its head is now a low flat slab with a plate under it; the warden's
-- arms no longer hover, because its collar spans the full shoulder width and the trunk is
-- wider; the stalker's tunic is an A-line instead of a square; and the brute stoops.
local BARK = rgb(240, 136, 56)
local BARK_DK = rgb(192, 96, 32)
local BARK_PALE = rgb(255, 232, 192)
local LEAF = rgb(120, 224, 64)
local LEAF_DK = rgb(48, 168, 64)
local TEAL = rgb(32, 200, 168)
local TEAL_DK = rgb(16, 144, 128)
local MOSS = rgb(200, 240, 120)
local BLOOM = rgb(255, 208, 64)
local SAP = rgb(192, 255, 128)
local FACE = rgb(255, 214, 170)
local SHADE = rgb(152, 64, 16)

-- Torso and legs are hidden on every rank and rebuilt as garment. The stalker and the brute
-- keep their heads (the stalker's is a face, the brute's is bark); the warden hides its head
-- and builds a taller stump of one, because a tree's height lives in its crown.
local BRIAR_HIDE = { "Torso", "Left Leg", "Right Leg" }
local BRIAR_HIDE_HEAD = { "Torso", "Left Leg", "Right Leg", "Head" }
local STALKER_BODY = {
	Head = FACE, Torso = TEAL,
	["Left Arm"] = TEAL_DK, ["Right Arm"] = TEAL_DK,
	["Left Leg"] = TEAL_DK, ["Right Leg"] = TEAL_DK,
}
local BRUTE_BODY = {
	Head = BARK, Torso = BARK,
	["Left Arm"] = BARK, ["Right Arm"] = BARK,
	["Left Leg"] = BARK_DK, ["Right Leg"] = BARK_DK,
}
local WARDEN_BODY = {
	Head = BARK_DK, Torso = BARK,
	["Left Arm"] = BARK, ["Right Arm"] = BARK,
	["Left Leg"] = BARK_DK, ["Right Leg"] = BARK_DK,
}

-- ── The Thorn Stalker ────────────────────────────────────────────────────────
-- The light one. A pointed leaf hood - one block swallowing the crown and one wedge swept
-- back off it to a point - over the only open face in the family, with one dark eye band.
-- The tunic, sash and seed are ONE garment stooped 8 degrees forward about the waist, so
-- the shoulders sit out over the toes. The chest is cut 1.66 against a 2.00 torso so
-- daylight runs between it and both arms, one thorn wedge rises off the LEFT shoulder only,
-- both arms end in a bark bracer, and two thin columns carry the bottom third of the figure
-- with one boot turned out. Two leaf wedges stood against the tunic's bottom corners flare
-- the hem below the sash, so the tunic is an A-line and not a square. Sixteen pieces.
local function stalkerKit()
	local k = {}
	local lean = { 8, 2.45 }
	local function leanCF(x, y, z)
		return CF(0, lean[2] - T_Y, 0) * deg(-lean[1], 0, 0) * CF(x, y - lean[2], z)
	end
	-- The hood and its point turn about ONE pivot at the crown: nodded 4 degrees and
	-- cocked 6, so the head hangs off-axis rather than sitting square on the neck.
	local function hoodCF(x, y, z)
		return CF(0, 4.95 - H_Y, -.04) * deg(-4, 0, 6) * CF(x, y - 4.95, z + .04)
	end
	A(k, "Head", "Hood", V(1.80, .52, 1.80), hoodCF(0, 5.20, -.04), LEAF, "Grass")
	A(k, "Head", "HoodPoint", V(.90, .58, 1.60), hoodCF(0, 5.75, .06), LEAF_DK, "Grass", WEDGE)
	-- One dark band where the eyes are: a face, not a lamp.
	fH(k, "Eyes", .56, .05, 4.30, 4.42, -.775, BARK_DK, "SmoothPlastic")
	fT(k, "Collar", 1.76, 1.64, 3.60, 4.10, -.05, LEAF_DK, "Grass")
	-- ONE tunic from the collar to the hem, stooped with its sash and seed.
	fT(k, "Tunic", 1.66, 1.30, 1.66, 3.56, -.08, TEAL, "Fabric", lean)
	fT(k, "Sash", 1.74, 1.40, 2.14, 2.44, -.08, BARK, "Wood", lean)
	-- The rank's one warm note: an amber seed stood on its corner in the sash.
	A(k, "Torso", "Seed", V(.30, .30, .10), leanCF(0, 2.29, -.83) * deg(0, 0, 45), BLOOM, "Metal")
	-- The hem flare: two leaf wedges on the tunic's bottom corners, below the sash and below
	-- the hands, leaning with the tunic, so the coat widens once at the hem.
	for _, s in ipairs({ -1, 1 }) do
		fFlare(k, s, "Flare" .. (s < 0 and "L" or "R"), .30, 1.10, 1.60, 1.90, .83, -.08, LEAF_DK, "Grass", lean)
	end
	-- One thorn: a wedge on the left shoulder with its tall edge outboard, rising past the
	-- collar, and nothing on the right.
	fCap(k, "Left Arm", -1, "Thorn", 1.00, .90, 3.98, 4.90, 1.00, false, BARK_DK, "Wood")
	for _, a in ipairs(ARMS) do
		fS(k, a[1], a[2], "Bracer" .. a[3], 1.12, 1.12, 2.02, 2.72, 1.00, 0, BARK_DK, "Wood")
	end
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], .56, .78, .54, 2.00, .54, -.04, 0, TEAL_DK, "Fabric")
	end
	fL(k, "Left Leg", -1, "BootL", .84, 1.12, 0, .56, .62, -.18, 0, BARK_DK, "Wood")
	A(k, "Right Leg", "BootR", V(.84, .56, 1.12), CF(.62 - L_X, .28 - L_Y, -.18) * deg(0, -10, 0), BARK_DK, "Wood")
	return k
end

-- ── The Briar Brute ──────────────────────────────────────────────────────────
-- The wide one: a stump. The bare bark head is sunk - a moss cap on the crown, a heavy bark
-- brow jutting over the open face, and a collar as wide as the cap right under the chin, so
-- there is no neck at all, and one dark eye band under the brow makes it a face. The trunk,
-- hump, belt and fauld are ONE garment stooped 8 degrees forward about the waist under the
-- upright collar, so the chest thrusts out under the chin and the brute leans into you. ONE
-- flat heartwood slab sits on the left shoulder - a low block, not a rising wedge, so it
-- reads as a shoulder and never as a roof beside the head - over a bark plate hung flush on
-- the outer face of the upper arm, against a bare right arm that ends in one root fist; a
-- hump stands off the back; the root fauld flares to 2.9, wider than anything above it, and
-- the boots are the heaviest in the family. Sixteen pieces.
local function bruteKit()
	local k = {}
	local lean = { 8, 1.90 }
	fH(k, "Cap", 1.90, 1.70, 4.92, 5.46, 0, MOSS, "Grass")
	fEave(k, "Head", "Brow", 1.70, .50, 4.62, 4.92, -1.02, BARK_DK, "Wood")
	-- One dark band in the shadow under the brow: a face, not a lamp.
	fH(k, "Eyes", .64, .05, 4.34, 4.48, -.775, SHADE, "SmoothPlastic")
	fT(k, "Collar", 1.90, 1.90, 3.64, 4.10, -.02, LEAF_DK, "Grass")
	-- The trunk top sits .10 under the collar so its back corner, lifted by the stoop, stays
	-- flush with the collar's underside instead of rising into it.
	fT(k, "Trunk", 1.84, 1.72, 2.22, 3.54, -.06, BARK, "Wood", lean)
	fT(k, "Hump", 1.50, .50, 2.80, 3.44, 1.05, BARK_DK, "Wood", lean)
	fT(k, "Belt", 1.92, 1.82, 1.82, 2.22, -.06, LEAF_DK, "Grass", lean)
	fT(k, "Fauld", 2.92, 1.94, 1.40, 1.82, -.06, BARK_DK, "Wood", lean)
	-- The one shoulder: a flat slab on top of the arm overhanging a plate on its outer face.
	fS(k, "Left Arm", -1, "PauldronL", 1.40, 1.40, 3.98, 4.40, 1.00, 0, BARK_PALE, "Wood")
	fS(k, "Left Arm", -1, "PlateL", .36, 1.20, 3.06, 3.98, 2.00, 0, BARK_DK, "Wood")
	fS(k, "Left Arm", -1, "FistL", 1.24, 1.24, 2.00, 2.72, 1.00, 0, LEAF_DK, "Grass")
	fS(k, "Right Arm", 1, "FistR", 1.36, 1.36, 2.00, 2.86, 1.00, 0, LEAF_DK, "Grass")
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], .74, .88, .64, 1.40, .66, -.04, 0, BARK_DK, "Wood")
		fL(k, l[1], l[2], "Boot" .. l[3], 1.06, 1.28, 0, .64, .72, -.16, 0, BARK_DK, "Wood")
	end
	return k
end

-- ── The Rootbound Warden ─────────────────────────────────────────────────────
-- A tree, and deliberately not a bigger brute. The rig head is hidden under a tall narrow
-- stump of a skull with one sap knot for a face - the family's only neon - and the crown
-- is two leaf canopy slabs and a tip stacked above it, so all the width is up in the
-- canopy. The whole crown - skull, knot, canopy, top and tip - is cocked 6 degrees to one
-- side about the base of the neck, so it grows crooked instead of standing square on the
-- collar. That collar spans the full 2.00 shoulder width, flush against both arms, so the
-- arms hang off a shoulder line, and the trunk is cut in .14 a side beneath it for the
-- underarm notch. Both shoulders are branches lifted UP as wedges, one fall of vine hangs
-- from the belt down the back to the calves, and the legs are tall columns on two root feet.
-- Eighteen pieces.
local function wardenKit()
	local k = {}
	local function crownCF(x, y, z)
		return CF(0, 4.06 - H_Y, 0) * deg(0, 0, 6) * CF(x, y - 4.06, z)
	end
	A(k, "Head", "Skull", V(1.06, 1.40, 1.06), crownCF(0, 4.70, -.06), BARK_DK, "Wood")
	A(k, "Head", "Knot", V(.30, .30, .06), crownCF(0, 4.78, -.62) * deg(0, 0, 45), SAP, "Neon",
		{ light = { 7, .7 } })
	A(k, "Head", "Canopy", V(2.60, .48, 1.90), crownCF(0, 5.64, 0), LEAF_DK, "Grass")
	A(k, "Head", "CanopyTop", V(1.70, .36, 1.30), crownCF(0, 6.06, 0), LEAF, "Grass")
	A(k, "Head", "Tip", V(.70, .32, 1.00), crownCF(0, 6.40, .10), LEAF, "Grass", WEDGE)
	fT(k, "Collar", 2.00, 1.70, 3.60, 4.06, -.02, LEAF_DK, "Grass")
	fT(k, "Trunk", 1.72, 1.36, 2.06, 3.60, -.10, BARK, "Wood")
	fT(k, "Belt", 1.78, 1.46, 1.80, 2.08, -.06, BARK_DK, "Wood")
	fT(k, "Roots", 2.04, 1.60, 1.36, 1.80, -.06, BARK_DK, "Wood")
	fT(k, "Vine", 1.50, .16, .70, 3.58, .84, TEAL_DK, "Grass")
	for _, a in ipairs(ARMS) do
		fCap(k, a[1], a[2], "Branch" .. a[3], 1.18, 1.18, 3.90, 4.60, 1.00, false, LEAF_DK, "Grass")
		fS(k, a[1], a[2], "Claw" .. a[3], 1.12, 1.16, 2.00, 2.64, 1.00, 0, BARK_DK, "Wood")
	end
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], .62, .76, .56, 1.36, .62, -.04, 0, BARK_DK, "Wood")
		fL(k, l[1], l[2], "Foot" .. l[3], .90, 1.18, 0, .56, .66, -.18, 0, BARK_DK, "Wood")
	end
	return k
end

OUTFITS.ThornStalker = { colors = STALKER_BODY, hide = BRIAR_HIDE, accessories = stalkerKit() }
OUTFITS.BriarBrute = { colors = BRUTE_BODY, hide = BRIAR_HIDE, accessories = bruteKit() }
OUTFITS.RootWarden = { colors = WARDEN_BODY, hide = BRIAR_HIDE_HEAD, accessories = wardenKit() }

-- ── The Sunken Marsh ─────────────────────────────────────────────────────────
-- Waterlogged clothes cut the way the approved families are cut: FEW, LARGE, CRISP forms,
-- bright and friendly, blocks and wedges everywhere a thing is flat and ONE cylinder in the
-- whole family, for the one thing in it that is actually round: the boss's bell. Retailored
-- 2026-09-23 after Alex rejected the first marsh kits as slabs bolted onto a blocky rig with
-- neon eyes doing the character work. The same four rules the quarry, frost and briar
-- families hold are held here:
--   1. One form per slot, no more than eighteen forms per kit, and every form BIG: one hat,
--      one collar, one chest, one belt, ONE hanging hide or cloth slab per rank, one foot
--      per leg. No straps, no seams, no reed confetti.
--   2. NOTHING CLIPS. Torso and legs are hidden and rebuilt as garment; every piece sits on
--      the body or flush against its neighbour, or wholly contains the limb inside it.
--      Torso pieces stay inside |x| < 1 wherever the arms hang, so all the width at the
--      shoulder comes from pieces sat ON the arms. The clipping check over the real export
--      is zero intersecting pairs on all three.
--   3. IT IS STILL A CHARACTER. Every rank keeps the rig's own head and open face under
--      headgear that caps the crown and no more; the lurker's arms are bare skin with one
--      reed wrap, the warden's hands are bare below its sleeves; legs are two columns with
--      daylight between them and one foot each.
--   4. Marsh colour, kept friendly, one accent apiece. Teal brine and olive mud at the dark
--      end, pale reed and lily at the light end, so the layering reads before the colour
--      does. The lurker's accent is a bronze buckle, the hulk's a verdigris skullcap, the
--      warden's the bronze bell. The family's whole neon budget is ZERO: no glowing eyes,
--      every face is a dark eye band in the shadow of a brim.
-- Told apart by outline alone, with the colours off:
--   Bog Lurker    LOW AND LEAN. A wide flat reed hat - the widest thing on the figure - over
--                 an open face sunk to the chin in its collar, the shortest figure and the
--                 narrowest chest in the family, ONE wet hide slab thrown over the LEFT
--                 shoulder and hanging down the outside of the arm to the elbow, nothing on
--                 the right but a reed wrap, a loincloth flap down the front, thin legs and
--                 two long flat paddle feet. Sixteen pieces.
--   Mire Hulk     MASSIVE AND SQUARE. No neck: a flat verdigris skullcap and a heavy brow sunk
--                 straight into a full-width collar, two SQUARE shoulder blocks sat on the
--                 arms (the left one bigger, with a hide hanging under it down the arm),
--                 mud sleeves ending in big flat fists, ONE waterlogged tarp hanging square
--                 down the front from the collar to the knees, the thickest legs and the
--                 heaviest square feet. Eighteen pieces.
--   Drowned       TALL AND NARROW, with a bell. The rig's pale drowned face under a cowl,
--   Bellwarden    sloped shoulders falling as wedges where the hulk's are square, the
--                 narrowest sleeves over bare hands, a long pale tabard hanging down the
--                 front to the shins between long legs on bare feet, and the role prop:
--                 a gallows post up the back carrying a bronze BELL out over the left
--                 shoulder, the one round form in the family. Seventeen pieces.
local BRINE = rgb(32, 192, 160)
local BRINE_DK = rgb(16, 136, 128)
local MUD = rgb(208, 184, 40)
local MUD_DK = rgb(152, 128, 24)
local REED = rgb(255, 232, 160)
local LILY = rgb(240, 255, 224)
local MOSS_WET = rgb(96, 208, 80)
local VERDIGRIS = rgb(96, 224, 176)
local BRONZE = rgb(255, 184, 48)
local FACE_MARSH = rgb(216, 255, 176)
local FACE_MUD = rgb(224, 200, 96)
local FACE_DROWNED = rgb(176, 240, 232)
local SHADE = rgb(152, 64, 16)

local MARSH_HIDE = { "Torso", "Left Leg", "Right Leg" }
local LURKER_BODY = {
	Head = FACE_MARSH, Torso = BRINE,
	["Left Arm"] = FACE_MARSH, ["Right Arm"] = FACE_MARSH,
	["Left Leg"] = MUD_DK, ["Right Leg"] = MUD_DK,
}
local HULK_BODY = {
	Head = FACE_MUD, Torso = BRINE_DK,
	["Left Arm"] = FACE_MUD, ["Right Arm"] = FACE_MUD,
	["Left Leg"] = MUD_DK, ["Right Leg"] = MUD_DK,
}
local BELLWARDEN_BODY = {
	Head = FACE_DROWNED, Torso = BRINE_DK,
	["Left Arm"] = FACE_DROWNED, ["Right Arm"] = FACE_DROWNED,
	["Left Leg"] = MUD_DK, ["Right Leg"] = MUD_DK,
}

-- ── The Bog Lurker ───────────────────────────────────────────────────────────
-- The light one, and the low one. A wide flat reed hat - brim, crown and a nape flap down
-- the back - is the widest thing on the figure, over the open face with one dark eye band
-- sunk to the chin in a collar; the chest is cut 1.66 against a 2.00 torso so daylight
-- runs between it and both bare arms, and stands upright (a stoop is a side-view feature,
-- and from the front it only opened a slit under the collar). ONE wet hide slab is thrown
-- over the LEFT shoulder - a cap on top of the arm and a fall down its outer face to the
-- elbow - and the right arm is bare but for a reed wrap. A belt with a bronze buckle, a
-- loincloth flap down the front, thin legs and two long flat paddle feet. Sixteen pieces.
local function lurkerKit()
	local k = {}
	fH(k, "Brim", 2.10, 2.10, 5.14, 5.38, 0, REED, "Fabric")
	fH(k, "Crown", 1.40, 1.40, 5.38, 5.80, 0, REED, "Fabric")
	fH(k, "Nape", 1.50, .40, 3.90, 5.14, .95, REED, "Fabric")
	-- One dark band where the eyes are: a face in the shadow of the brim, not a lamp.
	fH(k, "Eyes", .56, .05, 4.30, 4.42, -.775, SHADE, "SmoothPlastic")
	fT(k, "Collar", 1.70, 1.60, 3.60, 4.16, -.05, MUD, "Fabric")
	fT(k, "Chest", 1.66, 1.30, 2.02, 3.60, 0, BRINE_DK, "Fabric")
	fT(k, "Belt", 1.74, 1.38, 1.72, 2.02, 0, MUD_DK, "Fabric")
	-- The rank's one warm note: a bronze buckle stood on its corner in the belt.
	A(k, "Torso", "Buckle", V(.28, .28, .08), CF(0, 1.87 - T_Y, -.73) * deg(0, 0, 45), BRONZE, "Metal")
	fT(k, "Flap", .90, .12, .96, 1.72, -.75, BRINE, "Fabric")
	-- The one hide: a cap over the left shoulder and a fall down the outside of that arm.
	fS(k, "Left Arm", -1, "HideCap", 1.34, 1.24, 4.00, 4.36, 1.00, 0, MUD, "Fabric")
	fS(k, "Left Arm", -1, "HideFall", .34, 1.24, 2.30, 4.00, 2.00, 0, MUD, "Fabric")
	fS(k, "Right Arm", 1, "WrapR", 1.14, 1.14, 2.02, 2.70, 1.00, 0, REED, "Fabric")
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], .54, .66, .30, 2.02, .54, -.02, 0, MUD_DK, "Fabric")
		fL(k, l[1], l[2], "Foot" .. l[3], .78, 1.10, 0, .30, .58, -.22, 0, MOSS_WET, "Fabric")
	end
	return k
end

-- ── The Mire Hulk ────────────────────────────────────────────────────────────
-- The wide one: a block. No neck at all - a flat verdigris skullcap and a heavy brow eave
-- over the open face and its dark eye band, sunk straight into a collar as wide as the
-- shoulders. One square chest over one square belt, and ONE waterlogged tarp hung flat down
-- the front from the collar to the knees, wider than the head and longer than the chest, so
-- the whole front is one slab. Two SQUARE shoulder blocks sit on the arms - the left one
-- bigger, with a hide hanging under it down the outside of the arm, the rank's one
-- asymmetry - over mud sleeves that end in big flat fists. The thickest legs in the family
-- on the heaviest square feet. Eighteen pieces.
local function hulkKit()
	local k = {}
	fH(k, "Cap", 1.72, 1.72, 5.00, 5.40, 0, VERDIGRIS, "Metal")
	fEave(k, "Head", "Brow", 1.72, .50, 4.66, 5.00, -1.00, VERDIGRIS, "Metal")
	fH(k, "Eyes", .64, .05, 4.30, 4.46, -.775, SHADE, "SmoothPlastic")
	fT(k, "Collar", 2.00, 1.80, 3.60, 4.20, 0, MUD, "Fabric")
	fT(k, "Chest", 1.80, 1.50, 2.30, 3.60, 0, BRINE_DK, "Fabric")
	fT(k, "Belt", 1.92, 1.50, 2.00, 2.30, 0, MUD_DK, "Fabric")
	fT(k, "Tarp", 1.60, .22, 1.10, 3.60, -.86, MUD, "Fabric")
	fS(k, "Left Arm", -1, "ShoulderL", 1.50, 1.44, 4.00, 4.60, 1.00, 0, MUD_DK, "Fabric")
	fS(k, "Right Arm", 1, "ShoulderR", 1.40, 1.44, 4.00, 4.50, 1.00, 0, MUD_DK, "Fabric")
	fS(k, "Left Arm", -1, "HideL", .30, 1.30, 2.70, 4.00, 2.20, 0, MUD, "Fabric")
	for _, a in ipairs(ARMS) do
		fS(k, a[1], a[2], "Sleeve" .. a[3], 1.20, 1.20, 2.70, 4.00, 1.00, 0, BRINE_DK, "Fabric")
		fS(k, a[1], a[2], "Fist" .. a[3], 1.30, 1.30, 2.00, 2.70, 1.00, 0, MUD, "Fabric")
	end
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], .80, .90, .50, 2.00, .62, -.04, 0, MUD_DK, "Fabric")
		fL(k, l[1], l[2], "Foot" .. l[3], 1.00, 1.26, 0, .50, .70, -.18, 0, MUD_DK, "Fabric")
	end
	return k
end

-- ── The Drowned Bellwarden ───────────────────────────────────────────────────
-- Tall and narrow, and the only rank with a prop. The rig's pale drowned face under a cowl
-- that caps the crown, a collar bridging both shoulders over the narrowest chest in the
-- family, shoulders that FALL as wedges where the hulk's are square blocks, sleeves over
-- bare hands, a belt and a short skirt, and ONE long pale tabard hanging flat down the front
-- to the shins between two long legs on bare feet. The bell: a gallows post up the back,
-- a beam out over the LEFT shoulder, and a bronze bell hanging from it beside the head -
-- the one cylinder in the family, because a bell is round. Seventeen pieces.
local function bellwardenKit()
	local k = {}
	fH(k, "Cowl", 1.66, 1.66, 5.00, 5.46, 0, BRINE_DK, "Fabric")
	fH(k, "Eyes", .56, .05, 4.30, 4.42, -.775, SHADE, "SmoothPlastic")
	fT(k, "Collar", 1.90, 1.60, 3.60, 4.10, 0, BRINE, "Fabric")
	fT(k, "Chest", 1.56, 1.30, 2.30, 3.60, 0, BRINE_DK, "Fabric")
	fT(k, "Belt", 1.70, 1.44, 2.00, 2.30, 0, MUD_DK, "Fabric")
	fT(k, "Skirt", 1.80, 1.50, 1.40, 2.00, 0, MUD, "Fabric")
	fT(k, "Tabard", 1.00, .14, .50, 2.00, -.82, LILY, "Fabric")
	-- The gallows: a post up the back flush behind the collar, a beam across its top out past
	-- the left shoulder, and the bell hanging from the beam's outer end beside the head, clear
	-- of the cowl, so it reads as a carried bell and never as a hat.
	A(k, "Torso", "Post", V(.40, 4.20, .40), CF(-.75, 4.40 - T_Y, 1.05), MUD_DK, "Wood")
	A(k, "Torso", "Beam", V(1.10, .30, 1.80), CF(-1.10, 6.65 - T_Y, .35), MUD_DK, "Wood")
	A(k, "Torso", "Bell", V(1.00, 1.20, 1.20), CF(-1.30, 6.00 - T_Y, -.05) * deg(0, 0, 90), BRONZE, "Metal",
		{ shape = "Cylinder" })
	for _, a in ipairs(ARMS) do
		fCap(k, a[1], a[2], "Mantle" .. a[3], 1.16, 1.16, 4.00, 4.50, 1.02, true, BRINE, "Fabric")
		fS(k, a[1], a[2], "Sleeve" .. a[3], 1.12, 1.12, 2.60, 4.00, 1.00, 0, BRINE_DK, "Fabric")
	end
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], .60, .74, .40, 1.40, .60, -.04, 0, MUD_DK, "Fabric")
		fL(k, l[1], l[2], "Foot" .. l[3], .84, 1.12, 0, .40, .62, -.18, 0, FACE_DROWNED, "Fabric")
	end
	return k
end

OUTFITS.BogLurker = { colors = LURKER_BODY, hide = MARSH_HIDE, accessories = lurkerKit() }
OUTFITS.MireHulk = { colors = HULK_BODY, hide = MARSH_HIDE, accessories = hulkKit() }
OUTFITS.DrownedBellwarden = { colors = BELLWARDEN_BODY, hide = MARSH_HIDE, accessories = bellwardenKit() }

-- ── The Storm Reach ──────────────────────────────────────────────────────────
-- Retailored 2026-09-23. Rounds 0-2 kept losing the same fight, and the round-2 critics
-- both named the same thing: the shoulders. "Flat, detached rectangular boxes stuck off
-- each shoulder with a visible gap to the arm... even hollow/open-topped, showing black
-- negative space inside" and "an open rectangular trough bolted to the torso box... it's
-- unclear an arm even lives inside it."
--
-- Both faults had one mechanical cause, and round 3 fixes the cause rather than the symptom:
--   * THE GAP. Round 2's clipping checker was satisfied by lifting every shoulder piece
--     clear of the limb it belongs to - the Construct's pauldron ran y 4.10-4.55 on an arm
--     whose top is y 4.00, so it hovered a tenth of a stud above the shoulder with daylight
--     all round it, and the Warden's spaulder floated .6 clear. A pauldron is supposed to
--     OVERLAP the shoulder it caps; that overlap is the "intentional seat where a piece
--     rests on the body", not a clip. Every shoulder piece here now starts BELOW y 4.00 and
--     ends ABOVE it, so it swallows the top of the arm, and its inboard face is set at
--     x .98 - a hair inside the arm's own inboard face at x 1.00 - so the arm is contained
--     rather than abutted. The torso pieces at shoulder height are cut to exactly that same
--     half-width .98, so collar and shoulder meet face to face with no slot between them.
--   * THE BLACK HOLE. Round 2's sleeves topped out at y 4.00, exactly level with the arm's
--     own top face. Two upward-facing surfaces in the same plane z-fight, and Cycles
--     rendered the shared plane black - which is the "hollow, open-topped box" the critic
--     saw. The rule now: no accessory face may be coplanar with a SAME-FACING face of the
--     body part under it. Shoulder pieces always cap past y 4.00; head pieces always cap
--     past the head's own top at y 5.25; brims and visors stop exactly ON a face rather
--     than a hair short of it.
-- A second consequence of the same audit: a WEDGE pauldron can never cap an arm on its own.
-- A wedge's low edge is at its floor, so wherever its slope has dropped below y 4.00 the
-- arm's top corner pokes straight through it - which is what round 2 was really showing.
-- So a shoulder is TWO forms now: a block that seats on and contains the arm's top, and a
-- wedge (or, on the Titan, a flat plate) sitting on the block's flat roof, above y 4.00,
-- where it can slope freely. That is also what finally gives the ranks different shoulders.
--
-- The rest of round 1-2 holds: few, large, crisp forms, one shared blue palette with gold as
-- the single accent, one small glow a rank, torso and legs hidden and rebuilt as garment (an
-- R6 torso and its two flush legs have no silhouette of their own), arms left VISIBLE so a
-- bare forearm and a hand still read, and the titan's sun disk as the family's one round
-- shape because a sun is round. Four body plans, told apart by outline alone:
--   Stormcaller  the CASTER, light. Tallest thin point in the family (a hood peaked at 6.0)
--                over the narrowest body: a wide soft cowl, a 1.30 bodice, a gold cinch and
--                a flared skirt to the knee on two thin shins. No pauldrons at all - soft
--                sleeves - and the family's asymmetry, ONE steel conductor forearm, left only.
--   Thunder      the CONSTRUCT, heavy. The shortest and by far the widest: a flat brow-ridged
--   Construct    helm topping out at 5.32 sunk between the family's broadest shoulders
--                (span 4.64), whose caps are wedges FALLING outboard, over a short flared
--                fauld and two stubby pillar legs. Reads as a box with a head pressed into it.
--   Tempest      the WARDEN, tall and lean. A gold fin crest to 6.42, the narrowest chest and
--   Warden       shoulders in the family (span 4.16) whose caps are wedges RISING outboard,
--                two wing panels standing off the spine in a V past the head, a long tabard
--                and the longest, thinnest legs. An exclamation mark next to the Construct.
--   Celestial    the TITAN, monumental. A gold crown gate (two prongs rising outboard) to
--   Titan        6.24, flat SLAB shoulder plates instead of any wedge, the deepest chest with
--                the sun disk, and a long navy kilt over short thick legs in ivory greaves.
--                Tall like the Warden, broad like the Construct, square where both taper.
local STORM_BLUE = rgb(48, 120, 255)
local STORM_NAVY = rgb(32, 72, 224)
local STORM_STEEL = rgb(160, 200, 255)
local STORM_IVORY = rgb(240, 246, 255)
local STORM_GOLD = rgb(255, 208, 48)
local STORM_GLOW = rgb(255, 238, 160)
local STORM_FACE = rgb(216, 232, 255)
local STORM_SHADE = rgb(24, 48, 168)

-- The torso and the two legs are rebuilt as garment; the ARMS stay visible on every rank so
-- the bare stretch between a shoulder piece and the hand still reads as an arm. Which colour
-- that bare stretch is matters as much as any accessory: it has to differ from the piece
-- above it or the whole limb flattens into one slab (round 2's Titan), and it has to match
-- its own rank's metal or the hand reads as a floating brick.
local STORM_HIDE = { "Torso", "Left Leg", "Right Leg" }
local CALLER_BODY = {
	Head = STORM_FACE, Torso = STORM_NAVY,
	["Left Arm"] = STORM_FACE, ["Right Arm"] = STORM_FACE,
	["Left Leg"] = STORM_NAVY, ["Right Leg"] = STORM_NAVY,
}
local CONSTRUCT_BODY = {
	Head = STORM_STEEL, Torso = STORM_NAVY,
	["Left Arm"] = STORM_STEEL, ["Right Arm"] = STORM_STEEL,
	["Left Leg"] = STORM_NAVY, ["Right Leg"] = STORM_NAVY,
}
local WARDEN_STORM_BODY = {
	Head = STORM_FACE, Torso = STORM_NAVY,
	["Left Arm"] = STORM_STEEL, ["Right Arm"] = STORM_STEEL,
	["Left Leg"] = STORM_NAVY, ["Right Leg"] = STORM_NAVY,
}
local TITAN_BODY = {
	Head = STORM_IVORY, Torso = STORM_NAVY,
	["Left Arm"] = STORM_NAVY, ["Right Arm"] = STORM_NAVY,
	["Left Leg"] = STORM_NAVY, ["Right Leg"] = STORM_NAVY,
}

-- A chamfer under a chest plate: the same wedge turned upside down about Z so its flat
-- face sits flush under the plate, its tall face is the plate's back, and its slope runs
-- from the plate's front edge in to the waist. It is what stops a chest from being a box.
-- NOTE: this bevels the FRONT face only (Y/Z), it never narrows the left-right silhouette -
-- that cut has to come from an actual narrower piece (see the waist bands below).
local function fChamfer(k, w, d, yBot, yTop, zc, color, mat)
	A(k, "Torso", "Chamfer", V(w, yTop - yBot, d), CF(0, (yBot + yTop) * .5 - T_Y, zc) * deg(0, 0, 180),
		color, mat, WEDGE)
end

-- The shoulder seat shared by every armoured rank, re-cut in round 4 after four straight
-- losses to one complaint: "a flat rectangular slab hanging out to the side with a visible
-- air gap between it and the torso, sitting at or below the collar line". Round 3 built the
-- whole assembly ABOVE the limb - the Construct's cap ran 4.14..4.62 on an arm whose top is
-- 4.00 - so the cap was a shelf at collar height and the arm hung out from under it. The
-- approved quarry pauldron does the opposite and is the rule now:
--   * the CAP's floor sits AT or a hair BELOW the arm's top (y 3.9..4.0), so the cap swallows
--     the limb's top corner instead of perching over it, exactly as quarry's 3.98 does;
--   * the piece directly under it - SHOULDER block, bicep, sleeve, or on the Warden the bare
--     arm itself - runs up to EXACTLY that floor, so the column is continuous with no open
--     air under the overhang;
--   * and it is at most .10 narrower than the cap, so the overhang is a hair (quarry: a 1.38
--     cap over a 1.28 sleeve) rather than a projecting shelf.
-- Every piece still keeps its inboard face at x .98, inside the arm's own face at 1.00, so
-- the limb is contained rather than abutted, and the torso's collar is cut to half-width .98
-- so it meets SHOULDER face to face. Only the SEATING changed in round 4: the Construct's cap
-- still falls outboard, the Warden's still rises, the Titan's is still a flat slab.
local SEAT_X, ARM_TOP = .98, 4.00

-- ── The Stormcaller ──────────────────────────────────────────────────────────
local function stormcallerKit()
	local k = {}
	-- The hood swallows the crown (past the head's own top at 5.25, so no face of the head
	-- is left coplanar with it), its brim juts over the open face, and its peak sweeps back
	-- to the family's highest point: a caster read from the neck up, nothing over the face.
	fH(k, "Hood", 1.62, 1.66, 4.66, 5.46, .04, STORM_NAVY, "Fabric")
	fEave(k, "Head", "Peak", .92, 1.40, 5.46, 6.10, .18, STORM_NAVY, "Fabric")
	fEave(k, "Head", "Brim", 1.30, .56, 4.46, 4.66, -1.03, STORM_NAVY, "Fabric")
	-- The rank's one glow: a slit where the eyes are, in the open face under the brim.
	fH(k, "Eyes", .62, .06, 4.22, 4.32, -.78, STORM_GLOW, "Neon")
	-- A soft cowl, cut to the shoulder seat's own half-width so the sleeves meet it flush, and
	-- topped at 4.06 - the sleeve's own roof - so collar and shoulder make ONE unbroken line
	-- across the figure instead of stepping past each other by a couple of hundredths.
	fT(k, "Cowl", SEAT_X * 2, 1.58, 3.48, 4.06, 0, STORM_NAVY, "Fabric")
	-- The robe is three pieces: a genuinely narrow bodice, a gold cinch thinner than both its
	-- neighbours, and a flared skirt - a waist cut in the silhouette, not just in colour.
	fT(k, "Bodice", 1.30, 1.14, 2.44, 3.48, -.06, STORM_BLUE, "Fabric")
	fT(k, "Sash", 1.14, 1.20, 2.12, 2.44, -.06, STORM_GOLD, "Fabric")
	fT(k, "Skirt", 1.62, 1.30, 1.12, 2.12, -.06, STORM_NAVY, "Fabric")
	for _, s in ipairs({ -1, 1 }) do
		fFlare(k, s, "Flare" .. (s < 0 and "L" or "R"), .28, 1.10, 1.12, 1.74, .81, -.06, STORM_NAVY, "Fabric", { 0, 2 })
	end
	-- No pauldron on the caster - soft sleeves that cap the shoulder and stop, so the rank
	-- reads light beside three armoured ones. The family's asymmetry is ONE steel conductor
	-- forearm on the left, and the right forearm and both hands stay bare.
	-- A sleeve is a long form, not a cube: it runs most of the limb and is the robe's blue
	-- against the navy cowl, so the arm is a shape of its own instead of a slab of the body.
	-- Round 4: the sleeve used to top out at 4.12, a hair PROUD of the cowl's own 4.10, which
	-- is what made a soft sleeve read as a slab stood up beside the neck. It now caps the arm
	-- by .06 and tucks just under the cowl line instead of standing above it.
	for _, a in ipairs(ARMS) do
		fS(k, a[1], a[2], "Sleeve" .. a[3], 1.08, 1.10, 2.62, ARM_TOP + .06, SEAT_X, 0, STORM_BLUE, "Fabric")
	end
	fS(k, "Left Arm", -1, "Conductor", 1.22, 1.22, 2.06, 2.62, SEAT_X, 0, STORM_STEEL, "Metal")
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], .56, .80, .30, 1.12, .54, -.04, 0, STORM_NAVY, "Fabric")
		fL(k, l[1], l[2], "Boot" .. l[3], .76, 1.06, 0, .30, .54, -.14, 0, STORM_STEEL, "Fabric")
	end
	return k
end

-- ── The Thunder Construct ────────────────────────────────────────────────────
local function constructKit()
	local k = {}
	-- A sealed helm: the head is enclosed from the gorget up, the brow ridge juts off its
	-- front face and the visor bar glows under it. The helm caps past the head's top at 5.25.
	fH(k, "Helm", 1.58, 1.60, 4.10, 5.32, .02, STORM_STEEL, "Metal")
	fEave(k, "Head", "Brow", 1.58, .54, 4.70, 4.98, -1.05, STORM_STEEL, "Metal")
	-- The rank's one glow.
	fH(k, "Eyes", .96, .08, 4.44, 4.60, -.81, STORM_GLOW, "Neon")
	fT(k, "Gorget", SEAT_X * 2, 1.58, 3.40, 4.10, 0, STORM_NAVY, "Metal")
	-- ONE steel chest, floor to collar, with a raised blue core panel on its face. Round 3's
	-- earlier passes put a chamfer and a narrow waist band under the chest; a downward-facing
	-- slope catches no light in this lighting rig, so both of them rendered as a dark
	-- trapezoid and read as an open drawer cut into the body. Detail on a chest belongs on
	-- its FRONT FACE, where the key light hits it, never as a shadowed underside. The chest
	-- is also cut narrower than the shoulder seat (half-width .83 against 1.00) so a real
	-- underarm notch of dark shows and the arm never welds itself to the chest.
	fT(k, "Chest", 1.66, 1.52, 2.00, 3.40, -.06, STORM_STEEL, "Metal")
	fT(k, "Core", .86, .14, 2.36, 3.06, -.89, STORM_BLUE, "Metal")
	fT(k, "Fauld", 2.34, 1.80, 1.40, 2.00, -.06, STORM_NAVY, "Metal")
	for _, a in ipairs(ARMS) do
		-- The family's broadest shoulder, and still a wedge FALLING outboard - the heavy,
		-- sloping-down shoulder line. Round 4 drops the whole assembly onto the limb: the cap
		-- now floors at 3.94, a hair UNDER the arm's top at 4.00 (quarry seats its pauldron at
		-- 3.98), so it swallows the shoulder instead of shelving above it, and the block and
		-- bicep under it run up to that floor in .08 steps - 1.26, 1.34, 1.34 - so the column
		-- is continuous from the elbow to the cap with no daylight beneath the overhang.
		fS(k, a[1], a[2], "Shoulder" .. a[3], 1.34, 1.36, 3.34, ARM_TOP - .06, SEAT_X, 0, STORM_BLUE, "Metal")
		fCap(k, a[1], a[2], "Cap" .. a[3], 1.34, 1.36, ARM_TOP - .06, 4.52, SEAT_X, true, STORM_BLUE, "Metal")
		fS(k, a[1], a[2], "Bicep" .. a[3], 1.26, 1.26, 2.76, 3.34, SEAT_X, 0, STORM_STEEL, "Metal")
	end
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], .84, 1.00, .46, 1.40, .58, -.04, 0, STORM_NAVY, "Metal")
		fL(k, l[1], l[2], "Foot" .. l[3], 1.04, 1.30, 0, .46, .58, -.20, 0, STORM_STEEL, "Metal")
	end
	return k
end

-- ── The Tempest Warden ───────────────────────────────────────────────────────
local function tempestKit()
	local k = {}
	fH(k, "Helm", 1.54, 1.56, 4.46, 5.32, 0, STORM_STEEL, "Metal")
	-- The family's highest point and thinnest: a gold fin swept back off the crown.
	fEave(k, "Head", "Crest", .30, 1.26, 5.32, 6.42, .20, STORM_GOLD, "Metal")
	fH(k, "Eyes", .66, .06, 4.16, 4.26, -.78, STORM_GLOW, "Neon")
	-- The gorget tops at 3.94, level with the shoulder block's roof. A RISING cap is paper
	-- thin at its inboard end, so any collar standing above that end leaves a wedge of open
	-- air beside the neck - the same gap the critics kept naming, arriving by the back door.
	-- Cut level, the collar's top face and the fin's floor are one continuous shoulder line
	-- across the whole figure and the fin lifts off it. (The Construct and the Titan need no
	-- such cut: a FALLING wedge and a flat slab are both full height at the inboard end.)
	fT(k, "Gorget", SEAT_X * 2, 1.58, 3.52, 3.94, 0, STORM_STEEL, "Metal")
	-- The narrowest chest in the family, cut again at a gold belt narrower than itself.
	fT(k, "Chest", 1.48, 1.40, 2.44, 3.52, .02, STORM_BLUE, "Metal")
	fT(k, "Belt", 1.22, 1.24, 2.12, 2.44, -.02, STORM_GOLD, "Metal")
	fT(k, "Kilt", 1.60, 1.44, 1.32, 2.12, -.04, STORM_NAVY, "Metal")
	fT(k, "Tabard", .56, .12, 1.34, 2.08, -.82, STORM_IVORY, "Fabric")
	-- Two wing panels: quarter-turned wedges with the tall edge at the spine, stood against
	-- the gorget's own back face and rolled 28 degrees so the tips rise outboard past the
	-- head. This is the rank's silhouette - a tall figure standing inside a V.
	for _, s in ipairs({ -1, 1 }) do
		A(k, "Torso", "Wing" .. (s < 0 and "L" or "R"), V(.26, 2.00, .98),
			CF(s * 1.08, 4.05 - T_Y, .92) * deg(0, 0, -s * 34) * deg(0, -s * 90, 0), STORM_NAVY, "Metal", WEDGE)
	end
	for _, a in ipairs(ARMS) do
		-- The narrowest shoulder in the family, and its cap RISES outboard - the exact
		-- opposite slope to the Construct's, so the two heavies never share an outline.
		-- Round 4 seats it the same way: the fin floors at 3.94, under the arm's top, and the
		-- block runs from 3.28 up to exactly that floor. The block is 1.10 over a bare 1.00
		-- arm, so this rank's whole overhang is .05 a side - there is no shelf to gap under.
		fS(k, a[1], a[2], "Shoulder" .. a[3], 1.10, 1.18, 3.28, ARM_TOP - .06, SEAT_X, 0, STORM_BLUE, "Metal")
		fCap(k, a[1], a[2], "Fin" .. a[3], 1.10, 1.18, ARM_TOP - .06, 4.52, SEAT_X, false, STORM_BLUE, "Metal")
	end
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], .60, .86, .40, 1.32, .54, -.04, 0, STORM_NAVY, "Metal")
		fL(k, l[1], l[2], "Greave" .. l[3], .80, 1.12, 0, .40, .54, -.16, 0, STORM_STEEL, "Metal")
	end
	return k
end

-- ── The Celestial Titan ──────────────────────────────────────────────────────
local function titanKit()
	local k = {}
	fH(k, "Crown", 1.62, 1.62, 4.82, 5.42, 0, STORM_GOLD, "Metal")
	-- Two prongs on the crown's outer edges, tall outboard and falling inboard: a gate.
	for _, s in ipairs({ -1, 1 }) do
		A(k, "Head", "Prong" .. (s < 0 and "L" or "R"), V(1.24, .82, .58),
			CF(s * .52, 5.83 - H_Y, .02) * deg(0, s * 90, 0), STORM_GOLD, "Metal", WEDGE)
	end
	fH(k, "Eyes", .98, .06, 4.30, 4.44, -.78, STORM_SHADE, "SmoothPlastic")
	fT(k, "Gorget", SEAT_X * 2, 1.58, 3.56, 4.16, 0, STORM_NAVY, "Metal")
	fT(k, "Chest", 1.90, 1.58, 2.46, 3.56, -.04, STORM_IVORY, "Metal")
	-- The family's one round form and this rank's one glow: a sun disk on the chest.
	A(k, "Torso", "Sun", V(.12, .62, .62), CF(0, 3.00 - T_Y, -.89) * deg(0, 90, 0), STORM_GLOW, "Neon",
		{ shape = "Cylinder" })
	fT(k, "Belt", 1.46, 1.66, 2.00, 2.46, -.04, STORM_GOLD, "Metal")
	fT(k, "Kilt", 2.00, 1.84, 1.30, 2.00, -.04, STORM_NAVY, "Fabric")
	fT(k, "Tabard", .54, .14, .86, 1.94, -1.03, STORM_GOLD, "Fabric")
	for _, a in ipairs(ARMS) do
		-- No wedge on this rank: a flat SLAB plate, square where the Construct falls and the
		-- Warden rises. Monumental, not tapered. This was the family's worst offender in
		-- round 3 - a 1.40 plate floored at 4.16 over a 1.18 block, so it projected .22 a
		-- side with its whole underside in shadow, .16 clear of the arm, at collar height:
		-- the literal flat slab the critics kept naming. The plate now floors at 3.92, inside
		-- the arm's own top, and the block under it is widened to 1.32 so the overhang is .04
		-- a side and the shoulder reads as one continuous column with a lid.
		fS(k, a[1], a[2], "Shoulder" .. a[3], 1.32, 1.38, 3.00, ARM_TOP - .08, SEAT_X, 0, STORM_BLUE, "Metal")
		fS(k, a[1], a[2], "Plate" .. a[3], 1.40, 1.46, ARM_TOP - .08, 4.44, SEAT_X, 0, STORM_BLUE, "Metal")
	end
	for _, l in ipairs(LEGS) do
		fL(k, l[1], l[2], "Leg" .. l[3], .90, 1.06, .50, 1.30, .58, -.04, 0, STORM_BLUE, "Metal")
		fL(k, l[1], l[2], "Greave" .. l[3], 1.06, 1.40, 0, .50, .60, -.20, 0, STORM_IVORY, "Metal")
	end
	return k
end

OUTFITS.Stormcaller = { colors = CALLER_BODY, hide = STORM_HIDE, accessories = stormcallerKit() }
OUTFITS.ThunderConstruct = { colors = CONSTRUCT_BODY, hide = STORM_HIDE, accessories = constructKit() }
OUTFITS.TempestWarden = { colors = WARDEN_STORM_BODY, hide = STORM_HIDE, accessories = tempestKit() }
OUTFITS.Boss_CelestialTitan = { colors = TITAN_BODY, hide = STORM_HIDE, accessories = titanKit() }

EnemyOutfits.OUTFITS = OUTFITS

local function scaledOffset(offset: CFrame, scale: number): CFrame
	return CFrame.new(offset.Position * scale) * (offset - offset.Position)
end

local function specsFor(key: string): { any }
	local outfit = OUTFITS[key]
	if not outfit then return {} end
	local list = {}
	if outfit.inherit then
		for _, spec in ipairs(specsFor(outfit.inherit)) do table.insert(list, spec) end
	end
	for _, spec in ipairs(outfit.accessories) do table.insert(list, spec) end
	return list
end

function EnemyOutfits.has(archetypeKey: string): boolean
	return OUTFITS[archetypeKey] ~= nil
end

-- Call after the rig's body parts and Motor6Ds exist. Idempotent per rig (tagged Outfit attribute).
function EnemyOutfits.apply(model: Model, archetypeKey: string, scale: number, role: string?)
	local key = archetypeKey
	if role and OUTFITS[archetypeKey .. "_" .. role] then key = archetypeKey .. "_" .. role end
	local outfit = OUTFITS[key]
	if not outfit or model:GetAttribute("Outfit") then return end
	scale = scale or 1
	for partName, color in pairs(outfit.colors) do
		local body = model:FindFirstChild(partName)
		if body and body:IsA("BasePart") then body.Color = color end
	end
	-- `hide` makes a rig part invisible so the outfit can rebuild that volume as garment.
	-- It is appearance only: the part, its size, its Motor6D and its collisions are
	-- untouched, so the humanoid still walks, EnemyCombat still finds every part by name,
	-- and hit detection is unchanged. It exists because an R6 torso and its two flush legs
	-- have no silhouette of their own - the legs together are one plinth exactly as wide as
	-- the torso - and a garment laid over that can only ever be a rectangle.
	if outfit.hide then
		for _, partName in ipairs(outfit.hide) do
			local body = model:FindFirstChild(partName)
			if body and body:IsA("BasePart") then body.Transparency = 1 end
		end
	end
	-- A rig that was handed a real sword (EnemyCombat welds it before the outfit goes on)
	-- doesn't also carry its pick or sledge in that hand.
	local armed = model:FindFirstChild("Sword") ~= nil
	for _, spec in ipairs(specsFor(key)) do
		if spec.tool and armed then continue end
		local body = model:FindFirstChild(spec.part)
		if not (body and body:IsA("BasePart")) then continue end
		-- class = "WedgePart" gives a tapered piece; plain Parts take shape = Block/Cylinder/Ball.
		local acc = Instance.new(spec.class or "Part")
		acc.Name = spec.name
		acc.Size = spec.size * scale
		acc.Color = spec.color
		-- PS99 pass: every accessory is matte plastic. A spec's material string is kept as the
		-- designer's note of what the piece is (ice, wood, metal), but Roblox's Fabric / Wood /
		-- CorrodedMetal / Ice / Basalt / Slate / Grass / Metal are photoreal textures that fight
		-- the toy look; only Neon (glows) is honoured.
		acc.Material = if spec.material == "Neon" then Enum.Material.Neon else Enum.Material.SmoothPlastic
		if spec.shape and acc:IsA("Part") then acc.Shape = Enum.PartType[spec.shape] end
		acc.Transparency = spec.transparency or 0
		acc.Reflectance = spec.reflectance or 0
		acc.CanCollide, acc.CanQuery, acc.CanTouch, acc.CastShadow = false, false, false, false
		acc.Massless = true
		acc.Anchored = false
		acc.TopSurface, acc.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		acc.CFrame = body.CFrame * scaledOffset(spec.offset, scale)
		if spec.light then
			local light = Instance.new("PointLight")
			light.Range, light.Brightness, light.Color, light.Shadows = spec.light[1], spec.light[2], spec.color, false
			light.Parent = acc
		end
		acc.Parent = body
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = acc
		weld.Parent = acc
	end
	model:SetAttribute("Outfit", key)
end

return EnemyOutfits
