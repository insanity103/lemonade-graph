-- LocalScript | StarterPlayerScripts.WorldHorizon | Map project.
-- Carries LemonadeMap.Horizon (the far mountain ranges and the Sunspire's wooded hill) along with the
-- camera, like a 3D skybox. map_forge.py builds the Horizon in "sky space": every far layer is
-- shrunk toward the model's SkyEye point until it stands 400-650 studs out, inside the distance
-- parts still render on lower graphics settings, while covering exactly the part of the sky it
-- would at its true distance. Moving it by the camera's offset from SkyEye (translation only, no
-- rotation) keeps it at that apparent distance from anywhere in the map, which is how anything
-- far away behaves: it never gets closer as you walk. Purely visual and local: the parts have no
-- collision, queries or shadows, and the server's copy never moves.
local RunService = game:GetService("RunService")

local MOVE_EPSILON = 0.25 -- [TUNING] studs the camera must move before the ranges follow
-- The south country (its ranges, the Sunspire's wooded hill and foothills) is framed for
-- the town's view through the Iron Lowlands gate. Seen from inside the Lowlands it would hang over
-- the desert basin in front of the basin's own mesas, so it fades out as the camera walks south
-- through the pass, and back in past the Briarwood gate. The east, west and north rings stay.
local DESERT_FADE = { 140, 180, 462, 492 } -- [TUNING] Z: fade out from..to, fade back in from..to

local map = workspace:WaitForChild("LemonadeMap", 60)
local horizon = map and map:WaitForChild("Horizon", 60)
if not horizon then
	return
end

local eye = Vector3.new(
	horizon:GetAttribute("SkyEyeX") or 0,
	horizon:GetAttribute("SkyEyeY") or 20,
	horizon:GetAttribute("SkyEyeZ") or 13
)

local parts: { BasePart } = {}
for _, d in ipairs(horizon:GetDescendants()) do
	if d:IsA("BasePart") then
		table.insert(parts, d)
	end
end

local near: { BasePart } = {}
for _, child in ipairs(horizon:GetChildren()) do
	if child:IsA("Model") then -- the south country: its ranges, foothills and the Sunspire's hill
		for _, d in ipairs(child:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(near, d)
			end
		end
	elseif child:IsA("BasePart") and not string.match(child.Name, "^Side") then
		table.insert(near, child)
	end
end
local function desertFade(z: number): number
	local f = DESERT_FADE
	return math.clamp((z - f[1]) / (f[2] - f[1]), 0, 1) * (1 - math.clamp((z - f[3]) / (f[4] - f[3]), 0, 1))
end

-- The desert's own air. WorldLook's fill is the open sky's cool blue-grey, which is right for the
-- town but turns the basin's sunlit plaster and sandstone slate-grey on every face turned from the
-- sun; down in the Lowlands the shade is mostly light bounced off the sand, and the air carries a
-- little warm dust that pales the mesas as they step back. So while the camera is in the basin
-- (the same fade as above) and the sun is up, this client blends a few of WorldLook's values toward
-- the desert's. It is local and visual only, and it follows the server: whenever WorldLook writes
-- a new value, that becomes the base this blends from.
local Lighting = game:GetService("Lighting")
local SAND_SHARE = 0.7 -- [TUNING] how far the basin's air moves toward the desert values below
-- Briarwood's air, the same way: under the canopy the shade is lit by sunlight coming green through
-- the leaves and bounced off the grass, not by the open blue sky, and the vale holds a little bright
-- mist that softens the deep wood behind the near trunks. Still a sunny day (the key light is
-- untouched), just greener in the shade, with a touch more saturation and stronger sun shafts
-- where the sun shows between the crowns. Blended in over the gate corridor.
local FOREST_FADE = { 500, 548 } -- [TUNING] Z: fade in from..to
-- { class/name (nil = Lighting itself), property, desert value (nil = untouched), forest value }
local AIR = { -- [TUNING]
	{ nil, "Ambient", Color3.fromRGB(104, 80, 60), Color3.fromRGB(62, 80, 64) },
	{ nil, "OutdoorAmbient", Color3.fromRGB(156, 122, 92), Color3.fromRGB(96, 122, 100) },
	{ "Atmosphere", "Haze", 2.6, 2.1 },
	{ "Atmosphere", "Color", Color3.fromRGB(250, 222, 184), Color3.fromRGB(214, 234, 214) },
	{ "Atmosphere", "Density", nil, 0.41 },
	{ "WorldGrade", "TintColor", nil, Color3.fromRGB(250, 255, 232) },
	{ "WorldGrade", "Saturation", nil, 0.1 },
	{ "WorldSunRays", "Intensity", nil, 0.16 },
}
-- Briarwood's ground, the same way: the town's lawn green would glow lime on the forest's sunlit
-- verges beside the leafy cover under the trees, so while the camera is in the vale the grass (and
-- its blades) cools toward the canopy's greens and the leaf cover warms a little toward the grass,
-- until the two read as one floor, and the rock greys toward the forest's stone. Terrain colours are shared by the whole map, but the vale is
-- walled in: nothing else is on screen while this holds, and it eases back past the gate.
local terrain = workspace:FindFirstChildOfClass("Terrain")
local GROUND = { -- [TUNING] { material, forest colour }
	{ Enum.Material.Grass, Color3.fromRGB(90, 138, 62) },
	{ Enum.Material.LeafyGrass, Color3.fromRGB(100, 142, 62) },
	{ Enum.Material.Ground, Color3.fromRGB(118, 100, 74) },
	-- the vale's scarps and wall-foot boulders: the desert's warm mauve slate turns a cool,
	-- mossy grey-brown in the forest's palette
	{ Enum.Material.Slate, Color3.fromRGB(118, 114, 102) },
	{ Enum.Material.Basalt, Color3.fromRGB(96, 96, 88) },
}
local groundBase, groundWrote, groundW = {}, {}, -1
local airBase, airWrote = {}, {}
local function daylight(t: number): number
	return math.clamp(math.min((t - 6.2) / 1.6, (18.1 - t) / 1.6), 0, 1)
end
local function forestFade(z: number): number
	return math.clamp((z - FOREST_FADE[1]) / (FOREST_FADE[2] - FOREST_FADE[1]), 0, 1)
end
local function blend(a, b, w: number)
	if b == nil or w <= 0 then
		return a
	end
	if typeof(a) == "Color3" then
		return a:Lerp(b, w)
	end
	return a + (b - a) * w
end
local function target(class: string?): Instance?
	if not class then
		return Lighting
	end
	return Lighting:FindFirstChild(class) or Lighting:FindFirstChildOfClass(class)
end
RunService:BindToRenderStep("DesertAir", Enum.RenderPriority.Camera.Value + 3, function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local z = camera.CFrame.Position.Z
	local day = daylight(Lighting.ClockTime)
	local wSand = SAND_SHARE * desertFade(z) * day
	local wForest = forestFade(z) * day
	for i, entry in ipairs(AIR) do
		local inst = target(entry[1])
		if not inst then
			continue
		end
		local now = (inst :: any)[entry[2]]
		if airBase[i] == nil or now ~= airWrote[i] then
			airBase[i] = now -- a value WorldLook wrote (or the first read)
		end
		local want = blend(blend(airBase[i], entry[3], wSand), entry[4], wForest)
		if want ~= now then
			(inst :: any)[entry[2]] = want
		end
		-- what the property reads back (it stores single precision), so our own write is never
		-- mistaken for a new server value and compounded
		airWrote[i] = (inst :: any)[entry[2]]
	end
	-- Terrain colours replicate as one block, so any colour the server sets (WorldTerrain paints
	-- the desert's while the map builds) resets ours: like the air, a colour that no longer reads
	-- back as what this wrote is taken as the new base and toned again.
	if terrain then
		local wGround = math.floor(forestFade(z) * 32 + 0.5) / 32 -- stepped, so it is rewritten rarely
		for i, g in ipairs(GROUND) do
			local now = terrain:GetMaterialColor(g[1])
			if groundBase[i] == nil or now ~= groundWrote[i] then
				groundBase[i], groundW = now, -1
			end
		end
		if wGround ~= groundW then
			groundW = wGround
			for i, g in ipairs(GROUND) do
				terrain:SetMaterialColor(g[1], groundBase[i]:Lerp(g[2], wGround))
				groundWrote[i] = terrain:GetMaterialColor(g[1])
			end
		end
	end
end)

-- The Horizon moves as one rigid body. Carrying its ~650 parts one by one (a BulkMoveTo of every
-- part, every frame the camera moved) cost this client about 3.5 ms a frame while walking; so on
-- this client each part is welded, exactly where it stands, to one invisible anchored root at
-- SkyEye, and only the root moves. The engine carries the welded parts to the same places in the
-- same frame. The root and the welds exist on this client alone; the server's copy is untouched.
local skyRoot = Instance.new("Part")
skyRoot.Name = "SkyRoot"
skyRoot.Anchored = true
skyRoot.CanCollide, skyRoot.CanQuery, skyRoot.CanTouch, skyRoot.CastShadow = false, false, false, false
skyRoot.Transparency = 1
skyRoot.Size = Vector3.new(0.2, 0.2, 0.2)
skyRoot.CFrame = CFrame.new(eye)
skyRoot.Parent = horizon
for _, p in ipairs(parts) do
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = skyRoot
	weld.Part1 = p
	weld.Parent = skyRoot
	p.Anchored = false -- held by the anchored root, so the assembly stays anchored and never simulates
end

local last: Vector3? = nil
local lastFade = 0

RunService:BindToRenderStep("WorldHorizon", Enum.RenderPriority.Camera.Value + 2, function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local at = camera.CFrame.Position
	if last and (at - last).Magnitude < MOVE_EPSILON then
		return
	end
	last = at
	local fade = desertFade(at.Z)
	if fade ~= lastFade then
		lastFade = fade
		for _, p in ipairs(near) do
			p.LocalTransparencyModifier = fade
		end
	end
	skyRoot.CFrame = CFrame.new(at) -- SkyEye moved by the camera's offset from it; the parts follow
end)
