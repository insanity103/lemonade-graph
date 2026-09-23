-- Script | ServerScriptService.WorldTerrain | Map project.
-- Builds Hearthmere's ground in voxel Terrain: the canyon walls that ring the town, and the lawn
-- the town stands on. The fill is seeded, so every server builds the same place.
--
-- The walls are sculpted rock, not parts (tools/map_forge.py makes no visible wall parts; its
-- invisible cliff proxies, which reach Y110, are what hold players in):
--   * a solid rock body from the wall line 34 studs outward, whose crest rises and falls along each
--     wall -- taller crags at the corners, deliberate dips beside the Iron Lowlands gate and further
--     along each side where the far ranges and the Sunspire show through, a notch the waterfall
--     spills from on the east wall, and a broad low saddle in the west wall the setting sun shines
--     through at golden hour;
--   * the inner face stepped back in two ledges, run by run, with undercuts that leave overhanging
--     lips, deep vertical crevices, and crags, boulders and leaning spires on the crest;
--   * painted in horizontal strata, one material per band with crisp boundaries (dark slate at the
--     foot, rust rock, cream limestone caprock, ochre, tan sandstone, a slate seam), grass only on
--     flat ledge and crest tops, and gravel scree with dark boulders heaped at the foot.
-- Guard rails, applied before painting: nothing reaches more than PAD studs into the hub; the four
-- gate openings, the Iron Lowlands pass and overlook, the desert basin and the waterfall face stay clear.
-- Scree skirts slope onto the lawn only where no hub part or gameplay marker stands near the wall.
local HUB_Y = 10 -- lawn top (map_forge HUB_Y)
local LINE = 100 -- the walls' inner faces sit on x = +-100 and z = +-100
local GATE_HALF = 19.5 -- the wall meets each gate pillar's outer face this far from its centre line
local PAD = 0.75 -- [TUNING] how far rock may stand proud of the wall line into the hub
local BACK = 34 -- [TUNING] how deep the rock body runs behind the wall line
local SKIRT = 5 -- [TUNING] how far the scree foot may slope onto the lawn where it is clear
local SEED = 20260918

local map = workspace:WaitForChild("LemonadeMap", 30)
local hub = map and map:WaitForChild("Hub", 30)
if not hub then
	warn("[WorldTerrain] LemonadeMap.Hub not found; terrain not built")
	return
end

local terrain = workspace.Terrain
local rng = Random.new(SEED)
local M = Enum.Material
local started = os.clock()

-- ── Palette ──────────────────────────────────────────────────────────────────
-- Terrain colours are per material, so each stratum is its own material. Warm and saturated, so the
-- afternoon sun turns the rock golden while its shaded faces go cool under the blue sky fill.
-- Round-5 fix (root cause, not lighting): Rock/Limestone/Sandstone were a naturalistic tan/cream tint
-- on Terrain's own normal-mapped surface -- Atmosphere/Lighting alone can never flatten that fully
-- into cartoon, and the cream Limestone in particular was already pale before any haze touched it.
-- All three are retinted directly, brighter and higher-saturation, in one warm gold/rust/orange
-- family (Pet Simulator 99 storybook rock, not desaturated real stone); WorldLook's haze/decay is
-- re-tuned below to fade toward this same family instead of toward grey.
-- Round-10 fix (named gap): Rock/Limestone/Sandstone were already vivid, but Slate/Basalt/Asphalt --
-- the foot band, the mid-height seam, the scree and the fallen boulders, all directly in the canyon
-- face -- were a near-grey, low-saturation brown (Slate/Basalt sat ~0.25-0.28). Sitting inside the
-- otherwise-saturated rust/gold rock, that muddy brown is exactly what read as a naturalistic
-- "brown-to-rust sediment gradient with dark umber shadow banding": a real dark-umber tone banded
-- through storybook-bright rock. All three are retinted to darker, still-saturated cousins of the
-- same warm rust hue (never grey), per the target language's own rule that shadow is a darker
-- version of the same hue, not a muted one.
-- Round-11 fix: the whole family still sat on an earthy orange-brown hue (Rock ~24 degrees) that
-- critics read as "naturalistic canyon", not storybook; every band was pushed toward coral/tangerine.
-- Round-12 fix (named gap): coral/tangerine was still, in the critics' words, "realistic orange-red" --
-- a single warm hue family reads as a sun-baked real canyon (however saturated) rather than a candy-
-- coated storybook one. The family is rebuilt across three deliberately unrelated candy hues instead
-- of shades of one: magenta for the main cliff face (Rock, by far the largest band), gold for the
-- caprock (Limestone/Sandstone), and teal for the foot/scree/seam (Slate/Pavement/Asphalt) and the
-- fallen boulders (a dark magenta-purple cousin of the cliff face, per the target language's rule
-- that shadow is a darker version of the same hue, never grey). This is the Iron Lowlands' whole rock
-- family, so it also matches WorldLook's new pink-purple sky/haze below instead of fighting it.
-- Round-14 fix (HARD RULE, named gap): rounds 5-13 chased "more saturated" with no hue ceiling and
-- walked this whole family off warm terracotta and through candy magenta into a broken-texture
-- hot-pink/cyan palette (Rock hit literal Color3.fromRGB(255, 55, 170)). Rock and Basalt were already
-- hand-fixed back to warm terracotta/rust before this round; this round finishes the job on the rest
-- of the stack, which was still teal (Slate/Pavement/Asphalt, a cool cyan hue -- exactly as forbidden
-- as magenta/purple under the new rule). Every terrain material below now sits in one warm earth-tone
-- family -- hue roughly 10-45 degrees, red through yellow, never pink/magenta/purple/teal/cyan -- as a
-- monotonic sweep from foot to crest: Slate (darkest, the foot/seam shadow) -> Basalt (dark rust
-- boulders) -> Rock (terracotta cliff face, the dominant band) -> Sandstone (warm gold-orange) ->
-- Limestone (bright gold crest), each a brighter, still-saturated step of the same warm family, so
-- shade reads as a darker version of the same hue, never grey and never a cool colour. Pavement (the
-- Warden's flagged arena, per this file's own header) moves off teal into warm ochre, matching the
-- "ochre flags" the header already promised.
-- PS99 ground pass: every terrain colour below is shared verbatim with tools/map_forge.py's ground
-- palette (GRASS / GRASS_DARK / GRASS_DEEP / GROUND_PALE / PATH / GROUND_MID / GROUND_SAND /
-- GROUND_TAN), so the terrain laid over a hidden floor slab and the slab itself are one colour.
-- Round 2 (calm vs vivid): PS99 is not one even pastel. Its big walked surfaces are near-white
-- tints and its grass and props are full chroma, and that contrast is what makes it punchy. So the
-- greens are vivid lime, the roads and walks are near-white cream stepping up through peach to a
-- golden sand, and the rock strata are the warm accents at full colour: a monotonic foot-to-crest
-- sweep from coral-red through orange to coin gold, never grey, never brown, never a cool colour.
terrain:SetMaterialColor(M.Slate, Color3.fromRGB(236, 88, 60)) -- the dark foot and the seam: coral-red, the family's deepest step
terrain:SetMaterialColor(M.Rock, Color3.fromRGB(255, 140, 72)) -- the main cliff face: toy orange
terrain:SetMaterialColor(M.Limestone, Color3.fromRGB(255, 214, 64)) -- the crest: coin gold
terrain:SetMaterialColor(M.Pavement, Color3.fromRGB(255, 132, 112)) -- the Warden's flagged arena: a coral-pink pop set in the cream path
terrain:SetMaterialColor(M.Sandstone, Color3.fromRGB(255, 172, 48)) -- bridging orange to gold: amber
terrain:SetMaterialColor(M.Asphalt, Color3.fromRGB(246, 118, 56)) -- gravel scree: a deeper step of the orange face
terrain:SetMaterialColor(M.Basalt, Color3.fromRGB(226, 80, 52)) -- fallen boulders: the foot's coral-red, a shade deeper
terrain:SetMaterialColor(M.Grass, Color3.fromRGB(56, 248, 92)) -- GRASS: vivid lime, the hub meadow and open turf
terrain:SetMaterialColor(M.Ground, Color3.fromRGB(252, 228, 190)) -- GROUND_MID: the cart line, path edges and leaf litter, one step below the road
terrain:SetMaterialColor(M.Mud, Color3.fromRGB(30, 204, 116)) -- GRASS_DEEP: damp moss at the Mirror Pool shore and mottling the forest paths, never brown
terrain:SetMaterialColor(M.LeafyGrass, Color3.fromRGB(38, 232, 86)) -- GRASS_DARK: leafy cover, the moss on the graves and creeping out of the gutters
terrain:SetMaterialColor(M.Cobblestone, Color3.fromRGB(255, 238, 208)) -- PATH: the High Street, the same near-white cream as the road slabs

-- The strata, by voxel-centre height. Voxels are 4 studs and terrain blends two materials across
-- one voxel, so each band is two or three voxels thick: a solid core of its own colour with a
-- short, straight transition at each boundary, never a gradient.
local BODY = M.Salt -- the placeholder the rock is sculpted in before it is painted
-- Round-14 fix: one monotonic sweep within the warm earth-tone family only, foot to crest -- dark
-- rust-brown, dark rust, terracotta, gold-orange, bright gold -- so neighbouring bands are always
-- adjacent warm hues, never a jump to a cool one (the hard rule) and never back to one already passed.
local STRATA = {
	{ top = 16, mat = M.Slate }, -- the dark foot, where the rock meets the lawn: dark rust-brown
	{ top = 34, mat = M.Basalt }, -- shadow band: dark saturated rust, never grey
	{ top = 60, mat = M.Rock }, -- the main cliff face, by far the largest band: bright terracotta
	{ top = 78, mat = M.Sandstone }, -- bridging terracotta to gold: warm gold-orange
	{ top = math.huge, mat = M.Limestone }, -- the crest, brightest and warmest: bright gold
}
local function stratum(y: number): Enum.Material
	for _, band in ipairs(STRATA) do
		if y < band.top then
			return band.mat
		end
	end
	return M.Sandstone
end

-- ── Wall geometry ────────────────────────────────────────────────────────────
local SIDES = {
	{ key = "S", out = Vector3.zAxis, along = Vector3.xAxis },
	{ key = "N", out = -Vector3.zAxis, along = Vector3.xAxis },
	{ key = "E", out = Vector3.xAxis, along = Vector3.zAxis },
	{ key = "W", out = -Vector3.xAxis, along = Vector3.zAxis },
}

-- A box size from an along-wall length, an outward depth and a height.
local function wallBox(side, length: number, depth: number, height: number): Vector3
	local out, along = side.out, side.along
	return Vector3.new(
		math.abs(along.X) * length + math.abs(out.X) * depth,
		height,
		math.abs(along.Z) * length + math.abs(out.Z) * depth
	)
end

-- A point `o` studs outward from the wall line, `t` along it, at height y.
local function at(side, t: number, o: number, y: number): Vector3
	local p = side.out * (LINE + o) + side.along * t
	return Vector3.new(p.X, y, p.Z)
end

local function bump(t: number, centre: number, width: number): number
	return math.exp(-((t - centre) / width) ^ 2)
end

-- The crest height along each wall. The rule that every wall stands level is lifted: the ridgeline
-- breaks up, and wherever it dips the proxies behind it still hold players in.
local DIPS = {
	-- the south wall frames the Iron Lowlands gate: low shoulders either side of it, then a deep
	-- dip on each side where the far ranges show, rising to tall crags at the corners
	S = { { 0, 30, 8 }, { -52, 13, 13 }, { 55, 12, 12 } },
	N = { { 0, 24, 7 }, { -60, 18, 9 }, { 48, 16, 10 } },
	E = { { 0, 24, 7 }, { 72, 9, 14 }, { -55, 16, 9 } }, -- (+z 72 is the waterfall's notch)
	-- the west wall sags into a broad low saddle south of the Frostbound gate, where the golden-hour
	-- sun sets (WorldLook swings it round into the south-west): the low sun clears the saddle and
	-- rakes the plaza and the north quarter instead of hiding behind the rock
	W = { { 0, 24, 7 }, { 30, 18, 33 }, { 54, 18, 33 }, { -48, 17, 8 } },
}
local function crestAt(side, t: number): number
	-- Flattened to a low rock skirt (not a mountain range) now that the castle wall (map_forge.py)
	-- is the visible boundary: this just grounds the castle in a bit of rocky hillside.
	local y = HUB_Y + 9 + 2 * math.noise(t / 41, #side.key * 3.1, 0.5) + 1 * math.noise(t / 13, 7.3, 1.7)
	y += 3 * math.clamp((math.abs(t) - 70) / 30, 0, 1) -- the corners stand a little taller
	for _, dip in ipairs(DIPS[side.key]) do
		y -= dip[3] * 0.3 * bump(t, dip[1], dip[2])
	end
	return y
end
local function waterfallRun(side, t: number): boolean
	return side.key == "E" and t > 60 and t < 84
end

-- 1. The rock body and its stepped face, run by run (8-15 studs) along each wall, reaching past the
-- corners so the four walls knit into solid corner massifs.
local runs = 0
for _, side in ipairs(SIDES) do
	local t = -(LINE + BACK) - rng:NextNumber(0, 6)
	while t < LINE + BACK do
		local length = rng:NextNumber(8, 15)
		local tc = t + length / 2
		t += length
		runs += 1
		local fall = waterfallRun(side, tc)
		local top = if fall then HUB_Y + 24 else crestAt(side, tc) + rng:NextNumber(-2.5, 2.5)
		-- the body: a slab from the lawn line back, its top tilted a little so crests are not flat
		local tilt = CFrame.Angles(math.rad(rng:NextNumber(-3, 3)), math.rad(rng:NextNumber(-4, 4)), math.rad(rng:NextNumber(-3, 3)))
		local depth = BACK + PAD + 2
		local centre = at(side, tc, BACK - depth / 2, (top - 4) / 2)
		terrain:FillBlock(CFrame.new(centre) * tilt, wallBox(side, length + 1.5, depth, top + 4), BODY)
		if fall then
			continue -- the waterfall runs down a plain face (carved clean below)
		end

		-- two ledges: the face steps back above each; the second ledge is the deeper one.
		-- Round-14 fix: h1/h2/s2/s3 used to be fixed absolute studs sized for a ~57-75 stud wall.
		-- Now that crestAt() returns a low rock skirt (roughly HUB_Y+3 to HUB_Y+25), those fixed
		-- offsets were often taller than the wall itself, so `h1 < top - 6` was false almost every
		-- run and the whole body went uncarved -- a solid, featureless, grass-topped slab (the
		-- "giant flat green wall" bug). Ledge heights and setbacks now scale with how much rock
		-- actually stands above the lawn (avail), so a short skirt still gets real carving.
		local avail = top - HUB_Y
		local h1 = HUB_Y + avail * rng:NextNumber(0.3, 0.5)
		local h2 = h1 + avail * rng:NextNumber(0.25, 0.4)
		local s2 = rng:NextNumber(1.5, 3.5)
		local s3 = s2 + rng:NextNumber(2, 4)
		local function cutBack(from: number, setback: number)
			local d = setback + PAD + 2
			terrain:FillBlock(CFrame.new(at(side, tc, setback - d / 2, from + 60)), wallBox(side, length + 0.2, d, 120), M.Air)
		end
		if avail > 6 and h1 < top - 2 then
			cutBack(h1, s2)
		end
		if avail > 12 and h2 < top - 1.5 then
			cutBack(h2, s3)
		end
		-- an undercut under a ledge's face: the rock above hangs out over its own shadow
		if rng:NextNumber() < 0.45 then
			local base = if rng:NextNumber() < 0.5 then HUB_Y + rng:NextNumber(3, 5) else h1
			local setback = if base < h1 then 0 else s2
			local back = setback + rng:NextNumber(3, 4.5) -- how far under the face it digs
			local front = -PAD - 1
			local h = rng:NextNumber(4, 6)
			terrain:FillBlock(
				CFrame.new(at(side, tc + rng:NextNumber(-1.5, 1.5), (front + back) / 2, base + h / 2)),
				wallBox(side, length * rng:NextNumber(0.5, 0.85), back - front, h),
				M.Air
			)
		end
		-- crags on the crest, set back from the face so they never lean into the hub
		for _ = 1, 2 do
			local r = rng:NextNumber(4, 8)
			local c = at(side, tc + rng:NextNumber(-length / 2, length / 2), s3 + r * 0.6 + rng:NextNumber(0, 10), top - r * 0.35)
			terrain:FillBall(c, r, BODY)
		end
		if rng:NextNumber() < 0.4 then
			local h = rng:NextNumber(8, 16) * (if math.abs(tc) > 70 then 1.3 else 1)
			local w = rng:NextNumber(5, 9)
			local c = at(side, tc + rng:NextNumber(-length / 3, length / 3), s3 + w + rng:NextNumber(0, 8), top + h / 2 - 3)
			local lean = CFrame.Angles(math.rad(rng:NextNumber(-9, 9)), math.rad(rng:NextNumber(0, 90)), math.rad(rng:NextNumber(-9, 9)))
			local size = Vector3.new(w, h, w * rng:NextNumber(0.7, 1.2))
			if top > HUB_Y + 26 then -- no spires in the low west saddle: the setting sun shines through it
				terrain:FillBlock(CFrame.new(c) * lean, size, BODY)
			end
		end
		-- a deep vertical crevice at the run's end. Guarded (min gap of 3 studs): on the now-low
		-- skirt, top - rng(2,6) can undercut HUB_Y + rng(2,6) and invert the block's height.
		if avail > 8 and rng:NextNumber() < 0.5 and math.abs(t) < LINE - 4 then
			local w = rng:NextNumber(3.5, 5)
			local d = rng:NextNumber(5, 9)
			local y0 = HUB_Y + rng:NextNumber(2, 6)
			local y1 = math.max(y0 + 3, top - rng:NextNumber(2, 6))
			terrain:FillBlock(
				CFrame.new(at(side, t, (d - PAD - 1) / 2, (y0 + y1) / 2)) * CFrame.Angles(0, math.rad(rng:NextNumber(-12, 12)), 0),
				wallBox(side, w, d + PAD + 1, y1 - y0),
				M.Air
			)
		end
	end
end

-- 2. Guard rails: carve back anything that reached into the play space or a passage.
local inner = LINE - PAD
local function carve(x0: number, x1: number, y0: number, y1: number, z0: number, z1: number)
	terrain:FillBlock(
		CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		Vector3.new(x1 - x0, y1 - y0, z1 - z0),
		M.Air
	)
end
carve(-inner, inner, HUB_Y - 4, 200, -inner, inner) -- the hub itself
for _, s in ipairs({ -1, 1 }) do -- gate openings, through the full wall depth
	local a, b = s * (LINE - 12), s * (LINE + BACK + 40)
	local lo, hi = math.min(a, b), math.max(a, b)
	carve(-GATE_HALF, GATE_HALF, HUB_Y - 4, 200, lo, hi)
	carve(lo, hi, HUB_Y - 4, 200, -GATE_HALF, GATE_HALF)
end
carve(-GATE_HALF, GATE_HALF, 0, 200, 96, 142) -- the Iron Lowlands pass south of the south gate
carve(-40.5, 40.5, 0, 200, 139.5, 170) -- the quarry overlook at its end
carve(-240, 240, -10, 260, 167.5, 400) -- the Iron Lowlands: no hub rock past its north rim line
carve(LINE - 4, LINE + 0.6, HUB_Y - 4, 44, 64, 80) -- the waterfall's face on the east wall

-- 3. Paint: every sculpted voxel takes its stratum, and flat, open tops (a voxel with air above
-- and rock on all four sides, so never the lip of a face) grow grass, broken by a slow noise so
-- some ledges stay bare rock.
local RING = LINE + BACK + 8
local paintRegion = Region3.new(Vector3.new(-RING, 0, -RING), Vector3.new(RING, 96, RING)):ExpandToGrid(4)
local pm, po = terrain:ReadVoxels(paintRegion, 4)
local nx, ny, nz = #pm, #pm[1], #pm[1][1]
local y0 = paintRegion.CFrame.Position.Y - paintRegion.Size.Y / 2
local x0 = paintRegion.CFrame.Position.X - paintRegion.Size.X / 2
local z0 = paintRegion.CFrame.Position.Z - paintRegion.Size.Z / 2
local function solid(ix: number, iy: number, iz: number): boolean
	if ix < 1 or ix > nx or iz < 1 or iz > nz or iy < 1 or iy > ny then
		return false
	end
	return pm[ix][iy][iz] ~= M.Air and po[ix][iy][iz] > 0.3 -- (neighbours may be painted already)
end
local painted = { grass = 0, rock = 0 }
for ix = 1, nx do
	for iz = 1, nz do
		local x, z = x0 + (ix - 0.5) * 4, z0 + (iz - 0.5) * 4
		local lush = math.noise(x / 23, z / 23, 3.3) > -0.25
		for iy = ny, 1, -1 do
			if pm[ix][iy][iz] == BODY then
				local y = y0 + (iy - 0.5) * 4
				local top = iy == ny or po[ix][iy + 1][iz] < 0.05
				local flat = top and solid(ix + 1, iy, iz) and solid(ix - 1, iy, iz) and solid(ix, iy, iz + 1) and solid(ix, iy, iz - 1)
					and po[ix][iy][iz] > 0.5
				if flat and lush and y > HUB_Y + 8 then
					pm[ix][iy][iz] = M.Grass
					painted.grass += 1
				else
					pm[ix][iy][iz] = stratum(y)
					painted.rock += 1
				end
			end
		end
	end
end
terrain:WriteVoxels(paintRegion, 4, pm, po)

-- 4. The foot: gravel scree skirts and fallen boulders along runs with no hub part (house, stall,
-- lamp) or gameplay marker within reach; elsewhere a few boulders tucked into the rock's foot.
local skirtParams = OverlapParams.new()
skirtParams.FilterType = Enum.RaycastFilterType.Include
skirtParams.FilterDescendantsInstances = { hub }
local markerPoints = {}
local markers = map:FindFirstChild("Markers")
if markers then
	for _, m in ipairs(markers:GetDescendants()) do
		if m:IsA("BasePart") and m.Size.Magnitude < 12 then -- posts and spawns, not region volumes
			table.insert(markerPoints, m.Position)
		end
	end
end
local skirts = 0
for _, side in ipairs(SIDES) do
	for t = -94, 94, 5 do
		if math.abs(t) < GATE_HALF + 3 or waterfallRun(side, t) then
			continue
		end
		local probe = at(side, t, -SKIRT - 2, HUB_Y + 4)
		local clear = true
		for _, hit in ipairs(workspace:GetPartBoundsInBox(CFrame.new(probe), wallBox(side, 8, SKIRT * 2 + 4, 7), skirtParams)) do
			if hit.Transparency < 1 then
				clear = false
				break
			end
		end
		for _, p in ipairs(markerPoints) do
			if Vector3.new(p.X - probe.X, 0, p.Z - probe.Z).Magnitude < SKIRT + 8 then
				clear = false
			end
		end
		if not clear then
			-- no room for a skirt: a boulder half-buried in the rock's own foot
			if rng:NextNumber() < 0.35 then
				terrain:FillBall(at(side, t, rng:NextNumber(1.5, 3), HUB_Y + 0.5), rng:NextNumber(2, 3), M.Basalt)
			end
			continue
		end
		local h = rng:NextNumber(3, 6)
		local reach = SKIRT + PAD + rng:NextNumber(-0.5, 0.5)
		-- a wedge is tall at its local +Z (back) and slopes down toward its LookVector, so the back
		-- goes against the wall and the LookVector points onto the lawn
		local c = at(side, t, -reach / 2 + 0.5, HUB_Y + h / 2)
		terrain:FillWedge(CFrame.lookAt(c, c - side.out), Vector3.new(6, h, reach + 1), M.Asphalt)
		if rng:NextNumber() < 0.7 then
			terrain:FillBall(at(side, t + rng:NextNumber(-2, 2), -rng:NextNumber(1, 3), HUB_Y + 0.8), rng:NextNumber(1.8, 3.2), M.Basalt)
		end
		skirts += 1
	end
end

-- ── The lawn ─────────────────────────────────────────────────────────────────
-- The flat HubFloor slab becomes a terrain meadow, written voxel column by column (4 x 4 studs)
-- across the hub. Its surface sits exactly on the slab's top (Y10), so the slab keeps holding
-- players up and only its look changes. The painting is deliberate, not random: solid clean grass
-- everywhere, and earth only where feet and props would wear it. Each column is read against what
-- stands on it:
--   * paved (a road, the plaza, a yard or a foundation covers its centre): hidden earth, except
--     at the paving's rim, where soil spills a stud over the edge now and then;
--   * the verge: the one ring of columns beside paving is a trodden earth border, continuous
--     except where a slow noise lets the grass break through, so every path has a clear edge;
--   * under props (stalls, flower beds, benches, lamps, trunks) is bare earth; a tight ring of
--     mud round the campfire;
--   * the cliff foot and its scree (already terrain) are left as they are;
--   * everything else, shade included, is one clean grass field with a faint undulation.
local LAWN = 104 -- the slab spans +-104 (the gate openings reach its edge)
local VOX = 4
local COLS = LAWN * 2 // VOX
local floorPart: BasePart? = nil
local groundsHub = map:FindFirstChild("Grounds_Hub")
if groundsHub then
	floorPart = groundsHub:FindFirstChild("HubFloor") :: BasePart?
end

local lawnParams = OverlapParams.new()
lawnParams.FilterType = Enum.RaycastFilterType.Include
lawnParams.FilterDescendantsInstances = if groundsHub then { hub, groundsHub } else { hub }
local function standing(hit: BasePart): boolean
	return hit ~= floorPart and hit.Transparency < 1 and hit.Size.Y < 60
end

-- A part's world-axis bounding size (the plaza disc is a cylinder turned on its side).
local function worldExtents(part: BasePart): Vector3
	local cf, size = part.CFrame, part.Size
	local function span(axis: Vector3): number
		return math.abs(cf.RightVector:Dot(axis)) * size.X
			+ math.abs(cf.UpVector:Dot(axis)) * size.Y
			+ math.abs(cf.LookVector:Dot(axis)) * size.Z
	end
	return Vector3.new(span(Vector3.xAxis), span(Vector3.yAxis), span(Vector3.zAxis))
end

-- The fire, for its ring of mud.
local fireAt: Vector3? = nil
local fire = hub:FindFirstChild("GatheringFire")
if fire and fire:IsA("Model") then
	fireAt = fire:GetPivot().Position
end

local lawnRegion = Region3.new(Vector3.new(-LAWN, 4, -LAWN), Vector3.new(LAWN, 12, LAWN))
local mats, occs = terrain:ReadVoxels(lawnRegion, VOX)
local function centreOf(i: number): number
	return -LAWN + (i - 1) * VOX + VOX / 2
end

-- Pass 1: what each column is.
local PAVED, PROP, OPEN, SKIP = 1, 2, 3, 4
local kind = table.create(COLS)
local paveTop = table.create(COLS)
-- Columns whose only paving is a slab tagged TerrainPaving (the High Street): the street is drawn
-- in terrain cobbles there and the slab is hidden, keeping its collision.
local street = table.create(COLS)
local streetParts: { BasePart } = {}
for ix = 1, COLS do
	kind[ix], paveTop[ix], street[ix] = {}, {}, {}
	for iz = 1, COLS do
		local x, z = centreOf(ix), centreOf(iz)
		if mats[ix][2][iz] ~= M.Air and occs[ix][2][iz] > 0 then
			kind[ix][iz] = SKIP -- the cliff foot or a scree skirt already lives here
			continue
		end
		local k = OPEN
		for _, hit in ipairs(workspace:GetPartBoundsInBox(CFrame.new(x, HUB_Y + 0.3, z), Vector3.new(0.4, 0.4, 0.4), lawnParams)) do
			local ext = worldExtents(hit)
			if standing(hit) and ext.X >= 6 and ext.Z >= 6 and ext.Y < 12 then
				k = PAVED
				local top = hit.Position.Y + ext.Y / 2
				paveTop[ix][iz] = math.min(paveTop[ix][iz] or math.huge, top)
				if hit:GetAttribute("TerrainPaving") == true then
					if street[ix][iz] == nil then
						street[ix][iz] = top
					end
					if not table.find(streetParts, hit) then
						table.insert(streetParts, hit)
					end
				else
					street[ix][iz] = false -- other paving (the plaza, a pad) covers this column too
				end
			end
		end
		if k == OPEN then
			for _, hit in ipairs(workspace:GetPartBoundsInBox(CFrame.new(x, HUB_Y + 0.5, z), Vector3.new(VOX - 0.4, 0.8, VOX - 0.4), lawnParams)) do
				if standing(hit) then
					k = PROP
					break
				end
			end
		end
		kind[ix][iz] = k
	end
end

-- Pass 2: distance (in columns, 8-connected) from paving, capped at 3.
local dist = table.create(COLS)
for ix = 1, COLS do
	dist[ix] = {}
	for iz = 1, COLS do
		dist[ix][iz] = if kind[ix][iz] == PAVED then 0 else 3
	end
end
for _ = 1, 2 do
	for ix = 1, COLS do
		for iz = 1, COLS do
			if dist[ix][iz] > 0 then
				for dx = -1, 1 do
					for dz = -1, 1 do
						local nx2, nz2 = ix + dx, iz + dz
						if nx2 >= 1 and nx2 <= COLS and nz2 >= 1 and nz2 <= COLS then
							dist[ix][iz] = math.min(dist[ix][iz], dist[nx2][nz2] + 1)
						end
					end
				end
			end
		end
	end
end
local function hasLawnNeighbour(ix: number, iz: number): boolean
	for dx = -1, 1 do
		for dz = -1, 1 do
			local nx2, nz2 = ix + dx, iz + dz
			if nx2 >= 1 and nx2 <= COLS and nz2 >= 1 and nz2 <= COLS then
				local k = kind[nx2][nz2]
				if k == OPEN or k == PROP then
					return true
				end
			end
		end
	end
	return false
end

-- Pass 3: material and surface height per column.
local counts = { paved = 0, spill = 0, worn = 0, lawn = 0, street = 0 }
local function write(ix: number, iz: number, mat: Enum.Material, lift: number)
	mats[ix][1][iz], occs[ix][1][iz] = mat, 1
	mats[ix][2][iz], occs[ix][2][iz] = if lift > 0 then mat else M.Air, lift
end
for ix = 1, COLS do
	for iz = 1, COLS do
		local k = kind[ix][iz]
		if k == SKIP then
			continue
		end
		local x, z = centreOf(ix), centreOf(iz)
		-- Mud is now the Briarwood shore's damp-moss green (never brown), so the ring round the
		-- campfire is plain Ground like the rest of the worn verge instead of a darker mud patch.
		local earth = M.Ground
		if k == PAVED and street[ix][iz] then
			-- The High Street: cobbles, worn to bare earth in patches along the cart line down the
			-- middle, with soil and a little grass creeping out of the gutters at the edges. Terrain
			-- blends each change across a voxel, so wear seeps into the cobbles instead of sitting
			-- on them as a flat patch.
			local mat = M.Cobblestone
			local wear = math.noise(x / 13, z / 13, 5.1)
			local edge = math.abs(x) > 4
			if edge then
				local creep = math.noise(x / 7, z / 7, 9.4)
				if creep > 0.4 then
					mat = M.LeafyGrass -- low moss-and-clover, no blades standing in the road
				elseif creep < -0.3 or wear > 0.42 then
					mat = M.Ground
				end
			elseif wear > 0.22 then
				mat = M.Ground
			end
			write(ix, iz, mat, (street[ix][iz] - HUB_Y) / VOX)
			counts.street += 1
			continue
		end
		if k == PAVED then
			-- the rim of a low paving (roads, plaza, yards) spills soil and loose stones over its edge
			local top = paveTop[ix][iz] or HUB_Y
			if top <= HUB_Y + 0.4 and hasLawnNeighbour(ix, iz) and rng:NextNumber() < 0.35 then
				-- lift is in quarter-voxels: 0.05 raises the surface 0.2 studs above Y10
				local lift = (top - HUB_Y) / VOX + rng:NextNumber(0.02, 0.05)
				write(ix, iz, earth, lift)
				counts.spill += 1
			else
				write(ix, iz, M.Ground, 0)
				counts.paved += 1
			end
			continue
		end
		local d = dist[ix][iz]
		local mat = M.Grass
		local lift = math.max(0, 0.03 * math.noise(x / 9, z / 9, 7.7))
		local verge = d == 1 and math.noise(x / 14, z / 14, 2.3) > -0.3
		if k == PROP or verge then
			mat = earth
			-- worn ground humps a little against what it meets, burying hard bases
			lift = if k == PROP then 0.04 else 0.02
			counts.worn += 1
		else
			counts.lawn += 1
		end
		write(ix, iz, mat, lift)
	end
end
terrain:WriteVoxels(lawnRegion, VOX, mats, occs)

-- The slab keeps its collision (and every marker and spawn above it); the meadow is its face now.
if floorPart then
	floorPart.Transparency = 1
	floorPart.CastShadow = false
end
for _, slab in ipairs(streetParts) do
	slab.Transparency = 1
	slab.CastShadow = false
end

print(string.format(
	"[WorldTerrain] canyon walls: %d runs, %d grass tops, %d rock voxels, %d scree skirts; lawn %d worn %d rim-spill %d paved %d street %d in %.2fs",
	runs, painted.grass, painted.rock, skirts, counts.lawn, counts.worn, counts.spill, counts.paved, counts.street, os.clock() - started
))


-- ══ The Iron Lowlands desert oasis ═══════════════════════════════════════════ (DESERT-BEGIN)
-- South of the pass the Iron Lowlands open into a sunny desert basin, built in voxel Terrain on the
-- three walkable floors tools/map_forge.py lays down (rim Y10, mid bench Y6, pit Y2). The slabs
-- stay as invisible collision; everything seen is sand, sandstone and water:
--   * The floors are one sheet of warm sand. Where a floor meets a lower one, the sand pours down
--     over the edge as a soft slope (the haul ramps are buried in it); drifts pile up against the
--     basin's walls and against every adobe house map_forge tags SandDrift, and every other prop
--     sits a little sunk into the sand. A hardpan trail runs the route from the overlook to the
--     Briarwood gate, the Warden's arena is laid in ochre flags, and bare sandstone shows through
--     in pans here and there.
--   * The basin's edge is a low sandstone scarp with a sand bank climbing behind it (in places the
--     scarp gives way and the edge is one soft dune slope), painted by slope: sand wherever it is
--     gentle enough to hold sand, rock in horizontal strata (tan, rust, cream) where it is steep.
--     Invisible cliff proxies from map_forge still hold players in.
--   * Landmarks outside the basin: flat-topped striped mesas that step in as they rise, with sand
--     skirts heaped round their feet, and tall stacked rock towers.
--   * The oasis: a spring-fed pool in the pit's east corner (the old sump), ringed by damp sand
--     and grass, under a sandstone overhang with a cave mouth the spring pours out of.
--   * The cavern: the bandits' hideout passage in the west is entered under a great sandstone arch.
--   * A low sand-and-rock spine crosses the pit either side of the Warden's gap (its proxies stay).
local DESERT_HIDE_SLABS = true
do
	local dMap = workspace:FindFirstChild("LemonadeMap")
	local il = dMap and dMap:FindFirstChild("IronLowlands")
	local ilGround = dMap and dMap:FindFirstChild("Grounds_IronLowlands")
	if not il or not ilGround then
		warn("[WorldTerrain] LemonadeMap.IronLowlands not found; desert not built")
	else
		local dStarted = os.clock()
		local drng = Random.new(SEED + 202)
		local noise = math.noise
		local function clamp01(v: number): number
			return math.clamp(v, 0, 1)
		end
		local function smooth(v: number): number
			v = clamp01(v)
			return v * v * (3 - 2 * v)
		end

		-- Materials the hub does not use carry the desert's own colours; the strata reuse the hub
		-- canyon's tan sandstone, rust rock and cream limestone, so the two places share one palette.
		terrain:SetMaterialColor(M.Sand, Color3.fromRGB(255, 214, 130)) -- GROUND_SAND: the desert floor, golden toy sand matching the pit slab
		terrain:SetMaterialColor(M.Snow, Color3.fromRGB(255, 248, 228)) -- GROUND_PALE: pale drift crests, the near-white step of the sand
		terrain:SetMaterialColor(M.Salt, Color3.fromRGB(255, 224, 212)) -- the trodden hardpan trail: a pale rosy-cream path, calm against the golden sand
		terrain:SetMaterialColor(M.Concrete, Color3.fromRGB(250, 214, 160)) -- GROUND_TAN: damp sand at the water's edge, peach, matching the pool beds
		terrain.WaterColor = Color3.fromRGB(40, 176, 176)
		terrain.WaterTransparency = 0.45
		terrain.WaterReflectance = 0.55
		terrain.WaterWaveSize = 0.05
		terrain.WaterWaveSpeed = 6

		-- The play space, as rectangles { x0, x1, z0, z1, floor Y, kind } (map_forge's floors). "keep"
		-- rectangles (the cobbled pass, the Briarwood trail) are held clear but left as they are.
		local PLAY = {
			{ -14, 14, 90, 140, 10, "keep" }, -- the pass from the hub gate
			{ -40, 40, 140, 168, 10, "floor" }, -- the overlook
			{ -110, 110, 168, 232, 10, "floor" }, -- rim
			{ -110, 110, 232, 330, 6, "floor" }, -- mid bench
			{ -110, 110, 330, 470, 2, "floor" }, -- the pit
			{ -165, -110, 270, 330, 6, "floor" }, -- the bandits' hideout passage
			{ -19.5, 19.5, 466, 600, 2, "keep" }, -- the Briarwood gate and trail
		}
		-- The oasis pools: { x0, x1, z0, z1, centre x, centre z, radius x, radius z, water top }. Terrain
		-- water fills whole voxels, so a pool's surface sits on a 4-stud boundary and the sand round it
		-- is heaped a little higher to hold it. The spring pool in the pit's east corner lies on the old
		-- sump's bed slab (top Y0.8); the town's pool on the mid bench is a raised spring, a stud or two
		-- deep over the bench's slab.
		local POOLS = {
			{ 76, 112, 332, 364, 94, 348, 19, 17, 4 },
			{ 62, 84, 266, 302, 73, 284, 10.5, 17.5, 8 }, -- the town spring, west of the street
		}
		local ARENA = { 0, 424, 34 }
		local TRAIL = {
			Vector2.new(0, 136), Vector2.new(0, 196), Vector2.new(20, 224), Vector2.new(20, 300), Vector2.new(-22, 310),
			Vector2.new(-22, 360), Vector2.new(0, 372), Vector2.new(0, 470),
		}
		local CAMP = Vector2.new(-66, 272) -- the bandits' fire
		local X0, X1, Z0, Z1, YB, YT = -284, 264, 96, 540, -8, 136

		local function playDist(x: number, z: number)
			local best, brect = math.huge, nil
			for _, r in ipairs(PLAY) do
				local px = math.clamp(x, r[1], r[2])
				local pz = math.clamp(z, r[3], r[4])
				local d = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
				if d < best then
					best, brect = d, r
				end
			end
			return best, brect
		end
		local function segDist(p: Vector2, a: Vector2, b: Vector2): number
			local ab = b - a
			local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
			return (p - (a + ab * t)).Magnitude
		end
		local function trailDist(x: number, z: number): number
			local p, best = Vector2.new(x, z), math.huge
			for i = 1, #TRAIL - 1 do
				best = math.min(best, segDist(p, TRAIL[i], TRAIL[i + 1]))
			end
			return best
		end
		-- Distance to the nearest pool's rectangle (0 inside it), and that pool's water top.
		local function poolDist(x: number, z: number): (number, number)
			local best, top = math.huge, 0
			for _, pl in ipairs(POOLS) do
				local dx = math.max(pl[1] - x, 0, x - pl[2])
				local dz = math.max(pl[3] - z, 0, z - pl[4])
				local d = math.sqrt(dx * dx + dz * dz)
				if d < best then
					best, top = d, pl[9]
				end
			end
			return best, top
		end
		-- A pool's own outline: a rounded spring inside its rectangle (the east pool runs right up
		-- under its overhang). Returns the water top, or nil.
		local function inPool(x: number, z: number): number?
			for i, pl in ipairs(POOLS) do
				if x >= pl[1] and x <= pl[2] and z >= pl[3] and z <= pl[4] then
					local u = ((x - pl[5]) / pl[7]) ^ 2 + ((z - pl[6]) / pl[8]) ^ 2
					if u < 1 + 0.35 * noise(x / 9, z / 9, 81 + i) or (i == 1 and x > 104) then
						return pl[9]
					end
				end
			end
			return nil
		end

		-- Strata by height (tan sandstone with rust bands and thin cream seams), dipping gently east
		-- and warped a little so the bands wander across the faces.
		local DSTRATA = {
			{ top = 7, mat = M.Sandstone },
			{ top = 11, mat = M.Rock },
			{ top = 19, mat = M.Sandstone },
			{ top = 22, mat = M.Limestone },
			{ top = 31, mat = M.Sandstone },
			{ top = 38, mat = M.Rock },
			{ top = 48, mat = M.Sandstone },
			{ top = 51, mat = M.Limestone },
			{ top = 63, mat = M.Sandstone },
			{ top = 72, mat = M.Rock },
			{ top = 86, mat = M.Sandstone },
			{ top = 90, mat = M.Limestone },
			{ top = 104, mat = M.Sandstone },
			{ top = 114, mat = M.Rock },
			{ top = math.huge, mat = M.Sandstone },
		}
		local function dstratum(y: number, x: number, z: number): Enum.Material
			local yy = y + 0.018 * x + 2.4 * noise(x / 53, z / 53, 6.6)
			for _, band in ipairs(DSTRATA) do
				if yy < band.top then
					return band.mat
				end
			end
			return M.Sandstone
		end

		-- Landmark mesas outside the basin: { x, z, radius x, radius z, yaw, top }. Each steps in
		-- twice as it rises (the upper tiers narrower), sand heaped round its foot.
		local MESAS = {
			{ 204, 404, 40, 56, 18, 86 }, -- east, over the oasis
			{ 170, 498, 30, 21, -12, 66 }, -- south-east
			{ -226, 420, 36, 48, -8, 76 }, -- west
			{ -214, 198, 32, 26, 24, 60 }, -- north-west
			{ -164, 498, 36, 19, 6, 74 }, -- south-west
			{ 214, 196, 30, 24, -20, 64 }, -- north-east
			-- the south rim's two great blocks, either side of the Briarwood trail (they swallow the
			-- grey cliffs Briarwood lines its entrance with)
			{ 68, 494, 47, 22, 2, 80 },
			{ -70, 494, 49, 22, -2, 74 },
		}
		local function mesaAt(x: number, z: number): number
			local best = -math.huge
			for i, m in ipairs(MESAS) do
				local dx, dz = x - m[1], z - m[2]
				local c, s = math.cos(math.rad(m[5])), math.sin(math.rad(m[5]))
				local lx, lz = (dx * c - dz * s) / m[3], (dx * s + dz * c) / m[4]
				local r = (lx ^ 4 + lz ^ 4) ^ 0.25 -- a rounded block, not a drum
				if r < 2.2 then
					local a = math.atan2(lz, lx)
					r *= 1 + 0.1 * noise(math.cos(a) * 1.7 + i * 7.1, math.sin(a) * 1.7, 5.5) + 0.04 * noise(x / 6, z / 6, i)
					local top = m[6]
					local tiers = { { top, 0.8 }, { top - 16, 0.9 }, { top - 32, 1.0 } }
					local h = -math.huge
					for _, t in ipairs(tiers) do
						-- a rounded shoulder over the last stud or two of each tier's edge
						local edge = smooth((t[2] - r) / 0.05)
						if edge > 0 then
							h = math.max(h, t[1] - 3 * (1 - edge))
						end
					end
					-- the sand skirt heaped round the foot
					local skirt = top * 0.42 * clamp01(1 - (r - 1) / 0.9) ^ 1.6
					best = math.max(best, h, skirt)
				end
			end
			return best
		end

		-- Stacked rock towers (built after the voxels are written).
		local TOWERS = {
			{ 160, 262, 10, 98 },
			{ 232, 300, 12, 116 },
			{ 146, 446, 9, 82 },
			{ -198, 318, 10, 90 },
			{ -130, 505, 8, 76 },
			{ 150, 168, 8, 72 },
			{ -236, 262, 9, 84 },
		}

		-- The basin's edge: a sandstone scarp a few studs back from the play space, with a sand bank
		-- climbing behind it to a crest of dunes. Over the oasis the scarp stands taller.
		local function wallSurface(x: number, z: number, d: number, base: number): number
			local foot = 1 + 3 * clamp01(noise(x / 9, z / 9, 1.1) + 0.5)
			local grotto = math.exp(-((z - 348) / 16) ^ 2) * (if x > 100 and x < 170 then 1 else 0)
			local scarpAmt = math.max(smooth(noise(x / 53, z / 53, 2.7) * 1.8 + 0.55), grotto)
			local scarpH = 11 + 7 * noise(x / 37, z / 37, 2.2) + 3 * noise(x / 12, z / 12, 2.3) + 12 * grotto
			local crest = 32 + 12 * noise(x / 71, z / 71, 3.3) + 5 * noise(x / 23, z / 23, 3.4)
			local scarp = scarpAmt * scarpH * smooth((d - foot) / 3.5)
			local bank = crest * smooth((d - foot) / 32)
			local wave = 4 * math.abs(noise(x / 31 + z / 67, z / 43, 3.9)) * clamp01((d - 10) / 14)
			local s = base + math.max(scarp, bank) + wave
			return math.max(s, mesaAt(x, z))
		end

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Include
		rayParams.FilterDescendantsInstances = { ilGround }

		local region = Region3.new(Vector3.new(X0, YB, Z0), Vector3.new(X1, YT, Z1))
		local mats, occs = terrain:ReadVoxels(region, 4)
		local NX, NY, NZ = #mats, #mats[1], #mats[1][1]
		local function ctr(lo: number, i: number): number
			return lo + (i - 0.5) * 4
		end

		-- Pass 1: what each column is. kind: "wall" (sand bank and rock), "add" (the pass's walls,
		-- where the hub's own rock is kept and only raised), "floor", "pool"; nil is left alone.
		local kind, surf, fl, base = table.create(NX), table.create(NX), table.create(NX), table.create(NX)
		local stats = { wall = 0, floor = 0, pool = 0, drift = 0, towers = 0, boulders = 0, seated = 0 }
		for ix = 1, NX do
			kind[ix], surf[ix], fl[ix], base[ix] = {}, {}, {}, {}
			local x = ctr(X0, ix)
			for iz = 1, NZ do
				local z = ctr(Z0, iz)
				local hub = z < 136 and math.abs(x) <= 140 and not (math.abs(x) <= 34 and z >= 100)
				if hub or (math.abs(x) < 240 and z > 518) then
					continue -- the hub's canyon and lawn; Briarwood
				end
				local d, rect = playDist(x, z)
				-- rock either side of the hideout's arch, where the mouth's proxies stand
				local mouthWall = rect[1] == -165 and d == 0 and x > -126 and x < -112 and (z < 282 or z > 318)
				if d > 0 or mouthWall then
					local s = wallSurface(x, z, if mouthWall then 14 else d, rect[5])
					if z > 498 then -- the rim falls away toward Briarwood's trees
						s = math.min(s, rect[5] + (522 - z) * 2.4)
					end
					kind[ix][iz] = if z < 136 then "add" else "wall"
					surf[ix][iz], base[ix][iz] = s, rect[5]
				elseif rect[6] == "floor" then
					local hit = workspace:Raycast(Vector3.new(x, 40, z), Vector3.new(0, -60, 0), rayParams)
					fl[ix][iz] = if hit then hit.Position.Y else rect[5]
					base[ix][iz] = rect[5]
					local top = inPool(x, z)
					kind[ix][iz] = if top then "pool" else "floor"
					surf[ix][iz] = top
				end
			end
		end

		-- Pass 2: what stands on each floor column (props, houses, gameplay markers).
		local probe = OverlapParams.new()
		probe.FilterType = Enum.RaycastFilterType.Include
		probe.FilterDescendantsInstances = { il }
		local driftOf = {} -- BasePart -> how high sand drifts against its house
		for _, m in ipairs(il:GetDescendants()) do
			if m:IsA("Model") and m:GetAttribute("SandDrift") then
				local amp = m:GetAttribute("SandDrift")
				for _, p in ipairs(m:GetDescendants()) do
					if p:IsA("BasePart") then
						driftOf[p] = amp
					end
				end
			end
		end
		local markerPts = {}
		local markersFolder = dMap:FindFirstChild("Markers")
		if markersFolder then
			for _, m in ipairs(markersFolder:GetDescendants()) do
				if m:IsA("BasePart") and m.Size.Magnitude < 12 then
					table.insert(markerPts, Vector2.new(m.Position.X, m.Position.Z))
				end
			end
		end
		local blocked, houseAmp = table.create(NX), table.create(NX)
		for ix = 1, NX do
			blocked[ix], houseAmp[ix] = {}, {}
			local x = ctr(X0, ix)
			for iz = 1, NZ do
				if kind[ix][iz] == "floor" then
					local z = ctr(Z0, iz)
					local fy = fl[ix][iz]
					for _, hit in ipairs(workspace:GetPartBoundsInBox(CFrame.new(x, fy + 3, z), Vector3.new(6.5, 5.6, 6.5), probe)) do
						if hit.Transparency < 1 then
							local amp = driftOf[hit]
							if amp then
								houseAmp[ix][iz] = math.max(houseAmp[ix][iz] or 0, amp)
							else
								blocked[ix][iz] = true
							end
						end
					end
					local p = Vector2.new(x, z)
					for _, mp in ipairs(markerPts) do
						if (mp - p).Magnitude < 7 then
							blocked[ix][iz] = true
						end
					end
				end
			end
		end

		-- Pass 3: floor heights. h is the sand's height above the slab under it.
		local hgt = table.create(NX)
		local function isWall(k)
			return k == "wall" or k == "add"
		end
		for ix = 1, NX do
			hgt[ix] = {}
			local x = ctr(X0, ix)
			for iz = 1, NZ do
				local k = kind[ix][iz]
				if k ~= "floor" then
					continue
				end
				local z = ctr(Z0, iz)
				local fy = fl[ix][iz]
				local step, wallE, wallBase, house, bigAmp = 0, math.huge, 0, 0, houseAmp[ix][iz] or 0
				for dx = -4, 4 do
					for dz = -4, 4 do
						local jx, jz = ix + dx, iz + dz
						if (dx ~= 0 or dz ~= 0) and jx >= 1 and jx <= NX and jz >= 1 and jz <= NZ then
							local kj = kind[jx][jz]
							local dist = math.sqrt(dx * dx + dz * dz) * 4
							if kj == "floor" and fl[jx][jz] > fy + 1.5 then
								-- sand poured over the edge of a higher floor, down onto this one
								step = math.max(step, (fl[jx][jz] - fy) * clamp01(1 - (dist - 3.5) / 13) ^ 1.25)
							elseif isWall(kj) and dist < wallE then
								wallE, wallBase = dist, base[jx][jz]
							end
							local ha = houseAmp[jx][jz]
							-- a bigger drift reaches further out: a house's banks run a dozen studs
							-- onto the sand, a tent's or a rubble heap's only a few
							if ha then
								local reachH = 5 + 2.4 * ha
								if dist <= reachH + 2 then
									house = math.max(house, ha * clamp01(1 - (dist - 2) / reachH) ^ 1.3)
									bigAmp = math.max(bigAmp, ha)
								end
							end
						end
					end
				end
				-- drifts piled against the basin wall
				local amp = 2.2 + 3.6 * clamp01(noise(x / 13, z / 13, 41) + 0.5)
				local reach = 9 + 5 * noise(x / 19, z / 19, 42)
				local drift = if wallE < math.huge then amp * clamp01(1 - (wallE - 2) / reach) ^ 1.5 else 0
				-- low ripples across the open sand
				local ripple = 0.9 * clamp01(noise(x / 17, z / 17, 43) + 0.15)
				local h = math.max(0.12, drift, ripple)
				if houseAmp[ix][iz] then
					house = math.max(house, houseAmp[ix][iz] * (0.7 + 0.3 * clamp01(noise(x / 5, z / 5, 44) + 0.5)))
				end
				-- the wind heaps some stretches of a drift higher than others. Against a house it is
				-- fickle, column to column: a bank climbs three studs up one stretch of wall and all
				-- but scours the next, so the sand meets the plaster in a wandering line, not a level
				-- one; round a tent, a stall or a heap it only varies a little.
				if bigAmp >= 2 then
					house *= 0.28 + 1.05 * clamp01(noise(x / 6.5, z / 6.5, 45) * 1.9 + 0.5)
				else
					house *= 0.72 + 0.5 * clamp01(noise(x / 9, z / 9, 45) + 0.5)
				end
				if house > 0.3 and not blocked[ix][iz] then
					h = math.max(h, house)
					stats.drift += 1
				end
				if blocked[ix][iz] then
					h = math.min(h, 0.45) -- props sit a little sunk into the sand
				end
				if trailDist(x, z) < 5 then
					h = math.min(h, 0.3) -- the trail stays clear
				end
				h = math.max(h, step)
				-- the oasis berm: the ground round the pool stands above the water so it holds it
				local dp, wtop = poolDist(x, z)
				if dp < 14 then
					local need = if dp <= 2.5 then wtop + 0.6 elseif dp < 7 then wtop - 0.3 else wtop - 1.2 - (dp - 7) * 0.12
					h = math.max(h, need - fy)
				end
				-- the low spine across the pit, either side of the Warden's gap
				local rz, ax = math.abs(z - 375), math.abs(x)
				if rz < 13 and ax > 17 and ax < 114 and fy < 3 then
					local top = 9 + 3 * noise(x / 15, 50.5, 1) + 1.5 * noise(x / 5, 51.5, 2) + 3 * math.exp(-((ax - 26) / 7) ^ 2)
					local ridge = top * (1 - smooth((rz - 2.5) / 10)) * smooth((ax - 17) / 7)
					h = math.max(h, ridge)
				end
				hgt[ix][iz] = h
			end
		end

		-- Pass 4: write every column. Surfaces take their material from the slope and the height.
		local function topMaterialWall(x, z, s, slope)
			if slope < 0.5 then
				if s > 44 and noise(x / 15, z / 15, 61) > 0.1 then
					return M.Snow
				end
				if math.abs(x - 120) < 16 and math.abs(z - 348) < 20 and slope < 0.35 then
					return M.Grass -- green spilling over the lip above the spring
				end
				return M.Sand
			elseif slope < 0.95 and noise(x / 8, z / 8, 62) < 0.25 then
				return M.Sand
			end
			return nil -- rock, by stratum
		end
		local function surfAt(ix, iz): number?
			if ix < 1 or ix > NX or iz < 1 or iz > NZ then
				return nil
			end
			local k = kind[ix][iz]
			if isWall(k) then
				return surf[ix][iz]
			elseif k == "floor" then
				return fl[ix][iz] + (hgt[ix][iz] or 0.12)
			elseif k == "pool" then
				return surf[ix][iz]
			end
			return nil
		end
		for ix = 1, NX do
			local x = ctr(X0, ix)
			for iz = 1, NZ do
				local k = kind[ix][iz]
				if not k then
					continue
				end
				local z = ctr(Z0, iz)
				local s = surfAt(ix, iz) :: number
				local lowest, slope = s, 0
				for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
					local n = surfAt(ix + o[1], iz + o[2])
					if n then
						lowest = math.min(lowest, n)
						slope = math.max(slope, math.abs(n - s) / 4)
					end
				end
				if k == "pool" then
					stats.pool += 1
					for iy = 1, NY do
						local c = ctr(YB, iy)
						if c < s - 4 then
							mats[ix][iy][iz], occs[ix][iy][iz] = M.Sand, 1
						elseif c < s then
							mats[ix][iy][iz], occs[ix][iy][iz] = M.Water, 1
						else
							mats[ix][iy][iz], occs[ix][iy][iz] = M.Air, 0
						end
					end
					continue
				end
				local topMat
				if isWall(k) then
					stats.wall += 1
					topMat = topMaterialWall(x, z, s, slope)
				else
					stats.floor += 1
					local h = hgt[ix][iz]
					local dp = poolDist(x, z)
					local dA = math.sqrt((x - ARENA[1]) ^ 2 + (z - ARENA[2]) ^ 2)
					local g = noise(x / 23, z / 23, 71)
					if dp < 5 + 1.5 * noise(x / 6, z / 6, 72) then
						topMat = M.Concrete -- damp sand at the water
					elseif dp < 16 and noise(x / 9, z / 9, 73) > (dp - 5) / 11 - 0.55 then
						topMat = if noise(x / 5, z / 5, 74) > 0 then M.Grass else M.LeafyGrass
					elseif h < 0.5 and dA < ARENA[3] + 2.5 * noise(x / 7, z / 7, 75) then
						topMat = M.Pavement -- the Warden's flagged arena
					elseif h < 0.6 and trailDist(x, z) < 3.2 + 1.6 * noise(x / 6, z / 6, 76) then
						topMat = M.Salt -- the trodden trail
					elseif (Vector2.new(x, z) - CAMP).Magnitude < 9 + 2 * noise(x / 5, z / 5, 77) then
						topMat = M.Salt -- the trodden camp
					elseif slope > 0.9 then
						topMat = dstratum(s, x, z)
					elseif h > 2.2 and noise(x / 11, z / 11, 78) > -0.2 then
						topMat = M.Snow
					elseif g > 0.42 and h < 0.7 then
						topMat = M.Sandstone -- bedrock showing through
					else
						topMat = M.Sand
					end
				end
				for iy = 1, NY do
					local c = ctr(YB, iy)
					local occ = if c <= s - 4 then 1 else clamp01((s - c) / 4)
					if occ > 0.005 then
						if k == "add" and occs[ix][iy][iz] >= occ then
							continue
						end
						local mat
						if c > s - 6 and topMat then
							mat = topMat
						elseif c > lowest - 4 or c > s - 6 then
							mat = dstratum(c, x, z)
						else
							mat = M.Sandstone
						end
						mats[ix][iy][iz], occs[ix][iy][iz] = mat, occ
					elseif k ~= "add" then
						mats[ix][iy][iz], occs[ix][iy][iz] = M.Air, 0
					end
				end
			end
		end
		terrain:WriteVoxels(region, 4, mats, occs)

		-- Stacked rock towers: bulging drums of sandstone with rust and cream bands, a flat cap.
		local TOWER_MATS = { M.Sandstone, M.Rock, M.Sandstone, M.Limestone, M.Sandstone, M.Rock }
		for i, t in ipairs(TOWERS) do
			local tx, tz, r, h = t[1], t[2], t[3], t[4]
			local y = 2
			local k = i
			-- a talus of sand and rock at the foot, blending into the dunes
			terrain:FillBall(Vector3.new(tx, 6, tz), r * 1.9, M.Sand)
			while y < h do
				local seg = drng:NextNumber(9, 15)
				local rr = r * (1 - 0.18 * (y / h)) * drng:NextNumber(0.9, 1.12)
				local cf = CFrame.new(tx + drng:NextNumber(-1, 1), y + seg / 2, tz + drng:NextNumber(-1, 1))
				local mat = TOWER_MATS[(k % #TOWER_MATS) + 1]
				terrain:FillCylinder(cf, seg + 0.5, rr, mat)
				for _ = 1, 3 do -- knobs that break the drum's circle
					local a = drng:NextNumber(0, math.pi * 2)
					terrain:FillBall(cf.Position + Vector3.new(math.cos(a) * rr * 0.55, drng:NextNumber(-2, 2), math.sin(a) * rr * 0.55), rr * 0.6, mat)
				end
				y += seg
				k += 1
			end
			terrain:FillCylinder(CFrame.new(tx, y + 1.5, tz), 3, r * 0.75, M.Limestone)
			stats.towers += 1
		end

		-- A far rank of mesas beyond the basin's east rim, 350-500 studs out: flat-topped, stepped in
		-- two tiers, banded in the same strata, their feet lost in sand. The aerial haze pales them,
		-- so the view steps back in planes (camp, street, near mesas and towers, far mesas, sky) the
		-- way the reference's does. Out of sight from the town behind its canyon walls.
		local FAR_MESAS = { -- { x, z, radius x, radius z, top, yaw }
			{ 430, 236, 44, 30, 96, 12 },
			{ 452, 352, 62, 38, 128, -18 },
			{ 404, 468, 48, 34, 110, 28 },
			{ 336, 572, 40, 28, 84, 6 },
			{ 470, 120, 38, 30, 80, -30 },
		}
		for i, m in ipairs(FAR_MESAS) do
			local mx, mz, rx, rz, top, yaw = m[1], m[2], m[3], m[4], m[5], m[6]
			terrain:FillBall(Vector3.new(mx, -rx * 0.5, mz), rx * 1.25, M.Sand) -- the skirt
			local y = -4
			while y < top do
				local u = y / top
				local w = if u < 0.55 then 1 - 0.08 * u elseif u < 0.8 then 0.78 else 0.6
				local mat = dstratum(y, mx, mz)
				for k = 0, 2 do
					local jitter = 0.86 + 0.14 * noise(i * 3.1, y / 11, k)
					terrain:FillBlock(
						CFrame.new(mx, y + 2, mz) * CFrame.Angles(0, math.rad(yaw + k * 31), 0),
						Vector3.new(rx * 2 * w * jitter, 4.2, rz * 2 * w * (1.02 - 0.1 * k)),
						mat
					)
				end
				y += 4
			end
			stats.towers += 1
		end

		-- A natural arch over the Briarwood trail, knitting the south rim's two great blocks into one
		-- massif with a portal through it: banded like the mesas, its underside curved, Y26-38.
		terrain:FillBlock(CFrame.new(0, 37, 506), Vector3.new(84, 6, 18), M.Sandstone)
		terrain:FillBlock(CFrame.new(0, 42.5, 506), Vector3.new(84, 5, 18), M.Rock)
		terrain:FillBlock(CFrame.new(0, 49.5, 506), Vector3.new(84, 9, 18), M.Sandstone)
		terrain:FillBall(Vector3.new(-12, 53, 505), 9, M.Sandstone)
		terrain:FillBall(Vector3.new(15, 52, 507), 8, M.Limestone)
		terrain:FillCylinder(CFrame.new(0, 20, 506) * CFrame.Angles(math.rad(90), 0, 0), 30, 18, M.Air)

		-- The oasis overhang: a sandstone lip reaching out over the pool's east side, a cave mouth
		-- in the scarp under it where the spring comes out, and water running back into the cave.
		terrain:FillBlock(CFrame.new(108, 22, 348) * CFrame.Angles(0, 0, math.rad(-6)), Vector3.new(22, 10, 32), M.Sandstone)
		terrain:FillBall(Vector3.new(101, 21, 340), 6, M.Rock)
		terrain:FillBall(Vector3.new(102, 21.5, 356), 6.5, M.Sandstone)
		terrain:FillBall(Vector3.new(112, 28, 348), 10, M.Sandstone)
		terrain:FillBlock(CFrame.new(103, 10.5, 348), Vector3.new(22, 11, 34), M.Air) -- headroom over the water
		terrain:FillBlock(CFrame.new(118, 9, 348), Vector3.new(14, 10, 16), M.Air) -- the cave mouth
		terrain:FillBlock(CFrame.new(118, 2, 348), Vector3.new(12, 4, 16), M.Water)
		terrain:FillBlock(CFrame.new(118, -2, 348), Vector3.new(12, 4, 16), M.Sand)
		-- The hideout's arch: a thick sandstone span over the passage mouth, its underside Y22.
		terrain:FillBlock(CFrame.new(-118, 30, 300), Vector3.new(20, 16, 58), M.Sandstone)
		terrain:FillBall(Vector3.new(-116, 36, 290), 11, M.Sandstone)
		terrain:FillBall(Vector3.new(-120, 35, 311), 10, M.Rock)
		terrain:FillBlock(CFrame.new(-118, 25, 283), Vector3.new(22, 4, 6), M.Limestone)
		terrain:FillBlock(CFrame.new(-118, 25, 317), Vector3.new(22, 4, 6), M.Limestone)

		-- The loose rock heaps out on the open sand (SAND_ROCKS): sandstone knobs half-sunk in a
		-- mound of their own, clear of the trail, the pools and every gameplay marker.
		local seated = 0
		local function surfaceAt(x: number, z: number): number?
			local ix = math.floor((x - X0) / 4) + 1
			local iz = math.floor((z - Z0) / 4) + 1
			if ix < 1 or ix > NX or iz < 1 or iz > NZ or kind[ix][iz] ~= "floor" then
				return nil
			end
			return fl[ix][iz] + (hgt[ix][iz] or 0.12)
		end
		local function clearForSand(x: number, z: number): boolean
			if trailDist(x, z) < 4 or poolDist(x, z) < 3 then
				return false
			end
			local p = Vector2.new(x, z)
			for _, mp in ipairs(markerPts) do
				if (mp - p).Magnitude < 6 then
					return false
				end
			end
			return true
		end
		-- A sand ball whose crown reaches `top`, sunk far enough that it always meets the ground.
		local function heap(x: number, z: number, r: number, top: number, mat: Enum.Material?)
			local s = surfaceAt(x, z)
			if not s or not clearForSand(x, z) or top <= s + 0.2 then
				return
			end
			r = math.max(r, top - s + 0.6)
			terrain:FillBall(Vector3.new(x, top - r, z), r, mat or M.Sand)
			seated += 1
		end
		local SAND_ROCKS = { { -100, 262 }, { -88, 300 }, { -60, 410 }, { 60, 180 }, { -70, 196 } }
		for _, sr in ipairs(SAND_ROCKS) do
			local s = surfaceAt(sr[1], sr[2])
			if s then
				heap(sr[1], sr[2], 4.5, s + 1.2)
				for k = 1, 4 do
					local a = k * 1.7 + drng:NextNumber(-0.4, 0.4)
					local d = drng:NextNumber(0.5, 3)
					local x, z = sr[1] + math.cos(a) * d, sr[2] + math.sin(a) * d
					if clearForSand(x, z) then
						local r = drng:NextNumber(1.4, 2.4)
						terrain:FillBall(Vector3.new(x, s + r * 0.15, z), r, if k % 3 == 0 then M.Rock else M.Sandstone)
						seated += 1
					end
				end
			end
		end
		stats.seated = seated

		-- Fallen boulders at the scarps' feet (outside the play space).
		for ix = 1, NX, 1 do
			for iz = 1, NZ, 1 do
				if kind[ix][iz] == "wall" and drng:NextNumber() < 0.045 then
					local x, z = ctr(X0, ix), ctr(Z0, iz)
					local d = playDist(x, z)
					if d > 2 and d < 9 then
						local b = base[ix][iz]
						local r = drng:NextNumber(1.8, 3.4)
						terrain:FillBall(Vector3.new(x + drng:NextNumber(-1.5, 1.5), b + r * 0.4, z + drng:NextNumber(-1.5, 1.5)), r,
							if drng:NextNumber() < 0.7 then M.Sandstone else M.Rock)
						stats.boulders += 1
					end
				end
			end
		end

		-- The floor slabs and the buried ramps and roads keep their collision; the sand is their face
		-- now. (The cobbled pass is the hub's road and stays; the old sump's bed is the pool's floor.)
		if DESERT_HIDE_SLABS then
			for _, g in ipairs(ilGround:GetChildren()) do
				if g:IsA("BasePart") and g.Name ~= "PassFloor" and g.Name ~= "SumpBed" then
					g.Transparency = 1
					g.CastShadow = false
				end
			end
		end

		print(string.format(
			"[WorldTerrain] desert: %d wall columns, %d floor, %d pool, %d drift, %d seated, %d towers, %d boulders in %.2fs",
			stats.wall, stats.floor, stats.pool, stats.drift, stats.seated, stats.towers, stats.boulders, os.clock() - dStarted
		))
	end
end
-- (DESERT-END)

-- ══ Briarwood ═══════════════════════════════════════════════════════════════ (BRIAR-BEGIN)
-- The wooded vale south of the Lowlands gate, built in voxel Terrain from the ForestPlan that
-- tools/map_forge.py writes into LemonadeMap.Briarwood (its wall line, trails, every trunk's foot
-- and every rock), so the trees and the ground are planned in one place:
--   * The floor is one sheet of grass (Terrain grass decoration grows its blades) with a gentle
--     roll. Under the trees it turns to leafy ground cover, and each trunk rises out of a soft root
--     mound of dark earth, so no trunk stands on a mown lawn. Near the pool the ground is damp.
--   * The trails are packed earth sunk a little below their verges, their edges wandering so the
--     grass spills over them; the Warden's arena is bare earth.
--   * The boulders map_forge plants (grey Slate parts, half sunk) are bedded in leaf cover.
--   * The walls are wooded slopes: a grey scarp at the vale's edge (higher in places, gone in
--     others), then grass climbing to a broken crest, with boulders heaped at the foot. The fall
--     lips and the grotto's roof stand on rock. Invisible cliff proxies still hold players in.
-- The floor slabs keep their collision (and enemy ground raycasts); the terrain is their face.
do
	local bMap = workspace:FindFirstChild("LemonadeMap")
	local bw = bMap and bMap:FindFirstChild("Briarwood")
	local bwGround = bMap and bMap:FindFirstChild("Grounds_Briarwood")
	local planValue = bw and bw:FindFirstChild("ForestPlan")
	if not planValue or not bwGround then
		warn("[WorldTerrain] LemonadeMap.Briarwood ForestPlan not found; Briarwood ground not built")
	else
		local bStarted = os.clock()
		local plan = game:GetService("HttpService"):JSONDecode(planValue.Value)
		local brng = Random.new(SEED + 303)
		local noise = math.noise
		local function clamp01(v: number): number
			return math.clamp(v, 0, 1)
		end
		local function smooth(v: number): number
			v = clamp01(v)
			return v * v * (3 - 2 * v)
		end
		local Y = plan.y
		local X0, X1, Z0, Z1, YB, YT = -180, 180, 472, 1004, -8, 104

		local outline = {}
		for _, p in ipairs(plan.outline) do
			table.insert(outline, Vector2.new(p[1], p[2]))
		end
		local function segDist(p: Vector2, a: Vector2, b: Vector2): number
			local ab = b - a
			local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
			return (p - (a + ab * t)).Magnitude
		end
		local function insideOutline(p: Vector2): boolean
			local n, inside = #outline, false
			local j = n
			for i = 1, n do
				local a, b = outline[i], outline[j]
				if (a.Y > p.Y) ~= (b.Y > p.Y) and p.X < (b.X - a.X) * (p.Y - a.Y) / (b.Y - a.Y) + a.X then
					inside = not inside
				end
				j = i
			end
			return inside
		end
		local function wallDist(p: Vector2): number
			local best = math.huge
			for i = 1, #outline - 1 do
				best = math.min(best, segDist(p, outline[i], outline[i + 1]))
			end
			return best
		end
		local trails = {}
		for _, t in ipairs(plan.trails) do
			local pts = {}
			for _, q in ipairs(t[1]) do
				table.insert(pts, Vector2.new(q[1], q[2]))
			end
			table.insert(trails, { pts = pts, hw = t[2] / 2 })
		end
		-- Distance from a trail's edge (negative on it).
		local function trailDist(p: Vector2): number
			local best = math.huge
			for _, t in ipairs(trails) do
				for i = 1, #t.pts - 1 do
					best = math.min(best, segDist(p, t.pts[i], t.pts[i + 1]) - t.hw)
				end
			end
			return best
		end
		local feet = plan.feet -- { x, z, trunk radius, kind (1 oak, 2 fir, 3 birch) }
		local rocks = plan.rocks -- { x, z, radius, collide }: map_forge's boulders
		local hummocks = plan.hummocks or {} -- { x, z, radius }: moss hummocks among the undergrowth
		local calm = {} -- spawns and arrivals: the ground stays level round them
		for _, s in ipairs(plan.spawns) do
			table.insert(calm, Vector2.new(s[1], s[2]))
		end
		for _, s in ipairs(plan.arrivals) do
			table.insert(calm, Vector2.new(s[1], s[2]))
		end
		local pool = Vector2.new(plan.pool[1], plan.pool[2])
		local poolR = plan.pool[3]
		local grove = Vector2.new(plan.grove[1], plan.grove[2])
		local groveR = plan.grove[3]
		local grotto = plan.grotto

		-- Briarwood's rock: slate, broken by basalt in slow patches (no pale bands: those read as
		-- the desert's strata), warped along the walls.
		local function rockAt(y: number, x: number, z: number): Enum.Material
			local n = noise(x / 17, (y - Y) / 9, z / 17)
			return if n > 0.22 then M.Basalt else M.Slate
		end

		-- The walls' surface height above the floor, `d` studs outside the wall line.
		local function wallHeight(x: number, z: number, d: number): number
			local foot = 1.0 + 1.4 * clamp01(noise(x / 9, z / 9, 1.3) + 0.5)
			local u = d - foot
			if u <= 0 then
				return 0.3
			end
			local scarpAmt = smooth(noise(x / 47, z / 47, 3.1) * 1.8 + 0.6)
			local scarpH = 11 + 9 * noise(x / 33, z / 33, 3.2) + 3 * noise(x / 11, z / 11, 3.3)
			local scarp = scarpAmt * scarpH * smooth(u / 3.5)
			-- the north ridge stands taller, a green mountainside closing the vale off from the desert
			local crest = 46 + 16 * noise(x / 61, z / 61, 3.4) + 6 * noise(x / 19, z / 19, 3.5) + 20 * clamp01((615 - z) / 55)
			local bank = crest * smooth((u - 1.5) / (40 - 22 * clamp01((615 - z) / 55)))
			local rough = 2.5 * noise(x / 9, z / 9, 3.6) * clamp01(u / 6)
			local h = math.max(scarp, bank) + rough
			for _, f in ipairs(plan.falls) do -- the falls pour off a rock shoulder at their lip
				local dz, dx = math.abs(z - f[2]), math.abs(x - f[1])
				if dz < f[4] / 2 + 6 and dx < 14 then
					h = math.max(h, (f[3] - Y + 1.5) * smooth((14 - dx) / 4))
				end
			end
			if x > grotto[2] - 22 and x < grotto[2] + 18 and z > grotto[3] - 14 and z < grotto[4] + 14 then
				h = math.max(h, 38) -- the grotto's roof rests on solid rock
			end
			return h
		end

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Include
		rayParams.FilterDescendantsInstances = { bwGround }
		-- Props flatten the ground under them; vegetation does not.
		local propModels = {}
		for _, c in ipairs(bw:GetChildren()) do
			if not c:GetAttribute("Species") and not string.match(c.Name, "^Fern") and not string.match(c.Name, "^Bush")
				and not string.match(c.Name, "^FallenLog") and not string.match(c.Name, "^Boulder") then
				table.insert(propModels, c)
			end
		end
		local probe = OverlapParams.new()
		probe.FilterType = Enum.RaycastFilterType.Include
		probe.FilterDescendantsInstances = propModels

		local region = Region3.new(Vector3.new(X0, YB, Z0), Vector3.new(X1, YT, Z1))
		local mats, occs = terrain:ReadVoxels(region, 4)
		local NX, NY, NZ = #mats, #mats[1], #mats[1][1]
		local function ctr(lo: number, i: number): number
			return lo + (i - 0.5) * 4
		end

		-- Pass 1: each column's kind ("floor", "wall", "pool"; nil is the desert's) and surface.
		local kind, surf, dist = table.create(NX), table.create(NX), table.create(NX)
		local stats = { floor = 0, wall = 0, mounds = 0, boulders = 0 }
		for ix = 1, NX do
			kind[ix], surf[ix], dist[ix] = {}, {}, {}
			local x = ctr(X0, ix)
			for iz = 1, NZ do
				local z = ctr(Z0, iz)
				local p = Vector2.new(x, z)
				if z < 520 then
					if math.abs(x) > 20 then
						continue -- the Lowlands' rim and the arch are the desert's
					end
				end
				if z < 520 or insideOutline(p) then
					if (p - pool).Magnitude < poolR + 0.8 then
						kind[ix][iz] = "pool"
						continue
					end
					local hit = workspace:Raycast(Vector3.new(x, 40, z), Vector3.new(0, -60, 0), rayParams)
					local fy = if hit then hit.Position.Y else Y
					local h = 0.25 + 0.6 * clamp01(noise(x / 19, z / 19, 11) + 0.5) + 0.25 * noise(x / 6, z / 6, 12)
					local td = trailDist(p)
					if td < 1.5 then
						h = math.min(h, 0.08 + 0.2 * clamp01(td + 0.5)) -- the trail runs a little below its verges
					end
					for _, f in ipairs(feet) do
						local d = math.sqrt((x - f[1]) ^ 2 + (z - f[2]) ^ 2)
						local reach = f[3] * 2.4 + 2.5
						if d < reach and f[4] ~= 3 then
							h = math.max(h, (0.4 + f[3] * 0.5) * smooth(1 - (d - f[3]) / reach))
							stats.mounds += 1
						end
					end
					for _, r in ipairs(rocks) do -- leaf cover heaped round each boulder's foot
						local d = math.sqrt((x - r[1]) ^ 2 + (z - r[2]) ^ 2)
						if d < r[3] + 3 then
							h = math.max(h, (0.5 + r[3] * 0.25) * smooth(1 - (d - r[3] * 0.6) / 3.5))
						end
					end
					for _, hm in ipairs(hummocks) do -- a low moss dome, the ground swelling over an old stone or stump
						local d = math.sqrt((x - hm[1]) ^ 2 + (z - hm[2]) ^ 2)
						if d < hm[3] then
							h = math.max(h, hm[3] * 0.4 * math.sqrt(1 - (d / hm[3]) ^ 2))
						end
					end
					for _, c in ipairs(calm) do
						if (c - p).Magnitude < 7 then
							h = math.min(h, 0.3)
						end
					end
					for _, hitPart in ipairs(workspace:GetPartBoundsInBox(CFrame.new(x, fy + 3, z), Vector3.new(4.5, 5.6, 4.5), probe)) do
						if hitPart.Transparency < 1 then
							h = math.min(h, 0.06)
							break
						end
					end
					local dp = (p - pool).Magnitude
					if dp < poolR + 5 then
						h = math.min(h, 0.1 * (dp - poolR))
					end
					kind[ix][iz], surf[ix][iz] = "floor", fy + math.max(h, 0.02)
				else
					local d = wallDist(p)
					kind[ix][iz], surf[ix][iz], dist[ix][iz] = "wall", Y + wallHeight(x, z, d), d
				end
			end
		end

		local function nearRock(x: number, z: number): boolean
			for _, r in ipairs(rocks) do
				if (x - r[1]) ^ 2 + (z - r[2]) ^ 2 < (r[3] + 3) ^ 2 then
					return true
				end
			end
			for _, hm in ipairs(hummocks) do
				if (x - hm[1]) ^ 2 + (z - hm[2]) ^ 2 < (hm[3] + 0.5) ^ 2 then
					return true
				end
			end
			return false
		end

		-- Pass 2: materials, and every column written.
		local function surfAt(ix: number, iz: number): number?
			if ix < 1 or ix > NX or iz < 1 or iz > NZ then
				return nil
			end
			return surf[ix][iz]
		end
		for ix = 1, NX do
			local x = ctr(X0, ix)
			for iz = 1, NZ do
				local k = kind[ix][iz]
				if not k then
					continue
				end
				local z = ctr(Z0, iz)
				local p = Vector2.new(x, z)
				if k == "pool" then
					for iy = 1, NY do
						if ctr(YB, iy) > Y - 3 then
							mats[ix][iy][iz], occs[ix][iy][iz] = M.Air, 0
						end
					end
					continue
				end
				local s = surf[ix][iz]
				local slope = 0
				for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
					local n = surfAt(ix + o[1], iz + o[2])
					if n then
						slope = math.max(slope, math.abs(n - s) / 4)
					end
				end
				local topMat
				if k == "wall" then
					stats.wall += 1
					if slope > 1.25 + 0.3 * noise(x / 13, z / 13, 22) then
						topMat = nil -- bare rock where it is too steep to hold soil
					elseif noise(x / 23, z / 23, 21) > 0.25 then
						topMat = M.LeafyGrass
					else
						topMat = M.Grass
					end
				else
					stats.floor += 1
					local td = trailDist(p)
					local dp = (p - pool).Magnitude
					local dg = (p - grove).Magnitude
					local under, near = math.huge, math.huge -- distance to the nearest canopy trunk, beyond its radius
					for _, f in ipairs(feet) do
						local d = math.sqrt((x - f[1]) ^ 2 + (z - f[2]) ^ 2) - f[3]
						if f[4] ~= 3 then
							near = math.min(near, d)
						end
						under = math.min(under, d)
					end
					if td < 0.9 + 1.1 * noise(x / 7, z / 7, 31) then
						topMat = if noise(x / 5, z / 5, 32) > 0.38 then M.Mud else M.Ground
					elseif dg < groveR - 2 + 3 * noise(x / 8, z / 8, 33) then
						topMat = M.Ground -- the Warden's trampled arena
					elseif dp < poolR + 4 + 2 * noise(x / 6, z / 6, 34) then
						topMat = M.Mud -- damp shore
					elseif near < 0.4 + 2.4 * noise(x / 5, z / 5, 35) then
						topMat = M.Ground -- bare root earth showing at some trunks' feet
					elseif nearRock(x, z) or s > Y + 0.3 and x < -48 and x > -92 and z > 726 and z < 758 then
						topMat = M.LeafyGrass -- moss round the boulders and on the graves
					else
						-- Grass (whose blades Terrain decoration grows) and leafy ground cover are
						-- dithered, not split at a line: the grass share falls off gradually toward the
						-- trunks, so tufts of blades run deep under the crowns and leafy patches
						-- break out into the open, with drifts of leaf litter (bare earth) nearest
						-- the trees.
						local share = 0.2 + 0.8 * smooth((under - 3) / 26)
						local n = 0.5 + 0.9 * noise(x / 7.3, z / 7.3, 36) + 0.35 * noise(x / 3.1, z / 3.1, 37)
						if n < share then
							topMat = M.Grass
						elseif under < 9 and noise(x / 4.3, z / 4.3, 38) > 0.3 then
							topMat = M.Ground -- leaf litter
						else
							topMat = M.LeafyGrass
						end
					end
				end
				for iy = 1, NY do
					local c = ctr(YB, iy)
					local occ = if c <= s - 4 then 1 else clamp01((s - c) / 4)
					if occ > 0.005 then
						local mat
						if c > s - 6 and topMat then
							mat = topMat
						elseif k == "wall" then
							mat = rockAt(c, x, z)
						else
							mat = M.Ground
						end
						mats[ix][iy][iz], occs[ix][iy][iz] = mat, occ
					else
						mats[ix][iy][iz], occs[ix][iy][iz] = M.Air, 0
					end
				end
			end
		end
		terrain:WriteVoxels(region, 4, mats, occs)

		-- Boulders heaped at the walls' foot.
		for ix = 1, NX do
			for iz = 1, NZ do
				local d = dist[ix][iz]
				if d and d > 2 and d < 8 and brng:NextNumber() < 0.05 then
					local x, z = ctr(X0, ix), ctr(Z0, iz)
					local rr = brng:NextNumber(2.2, 3.8)
					terrain:FillBall(Vector3.new(x + brng:NextNumber(-1.5, 1.5), Y + rr * 0.35, z + brng:NextNumber(-1.5, 1.5)), rr,
						if brng:NextNumber() < 0.6 then M.Slate else M.Basalt)
					stats.boulders += 1
				end
			end
		end

		-- The grotto's floor is swept clean again (the boulders may have rolled in).
		terrain:FillBlock(CFrame.new((grotto[1] + grotto[2]) / 2, Y + 16, (grotto[3] + grotto[4]) / 2),
			Vector3.new(grotto[2] - grotto[1], 28, grotto[4] - grotto[3]), M.Air)

		for _, g in ipairs(bwGround:GetChildren()) do
			if g:IsA("BasePart") and g.Name ~= "PoolBed" then
				g.Transparency = 1
				g.CastShadow = false
			end
		end
		print(string.format(
			"[WorldTerrain] briarwood: %d floor columns, %d wall, %d boulders in %.2fs",
			stats.floor, stats.wall, stats.boulders, os.clock() - bStarted
		))
	end
end
-- (BRIAR-END)
