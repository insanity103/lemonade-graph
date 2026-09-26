-- LocalScript | StarterPlayerScripts.ZoneAir | Map project.
-- Each zone's own air and sound, blended in by where the camera is. Purely visual/aural and local.
--
-- WorldLook's daylight is tuned for the town: its shade is the open sky's cool blue-grey. Down in
-- the Iron Lowlands' sand basin that turns every sunlit plaster wall and sand slope slate-grey on the
-- side turned from the sun, which is most of what reads as "muddy" there. In a desert the shade is
-- mostly light bounced off the sand, so while the camera is in the basin (and the sun is up) this
-- client moves a few of WorldLook's values toward a warm, high-key desert air. It follows the
-- server: whenever WorldLook writes a new value, that becomes the base this blends from, so the
-- day/night cycle still drives everything.
--
-- (This blend used to live in WorldHorizon.client.luau, which now exits early since the far ranges
-- were scrapped, so it never ran. Only the desert half is revived here; Briarwood keeps the town's
-- air, as it looks today.)
--
-- The Frostbound Glacier, west of the hub's Frostbound gate, gets its own air the same way: a
-- cool, high-key ice blue that keeps the snow bright white and its shade a clean lavender-blue,
-- never grey.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

-- ── Camera reach ────────────────────────────────────────────────────────────────────────────────
-- The Lowlands are a basin walled by dune banks, not a closed room: at the default zoom the camera
-- could climb out over the crests and look past the edge of the map (the grey baseplate beyond the
-- terrain, 2026-09-24 playtest). While the player is in the basin the zoom-out is held to where the
-- banks still fill the view; anywhere else the place's own limit applies again.
local BASIN_ZOOM = 42 -- [TUNING] studs
local BASIN_Z = { 136, 474 } -- the basin, from the pass to the Briarwood gate
-- The Glacier is walled by ice cliffs ~46 studs over each floor; the cap keeps the camera under
-- their crests, so the view never runs out over the snowfield to the edge of the map.
local GLACIER_ZOOM = 44 -- [TUNING] studs
local function inGlacier(p: Vector3): boolean
	return p.X < -106 and p.Z < 94
end
local player = Players.LocalPlayer
local baseZoom = player.CameraMaxZoomDistance
local zoomCap = nil -- the cap in force, or nil
local function stepZoom()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local at = (root :: BasePart).Position
	local cap = if inGlacier(at) then GLACIER_ZOOM elseif at.Z > BASIN_Z[1] and at.Z < BASIN_Z[2] then BASIN_ZOOM else nil
	if cap ~= zoomCap then
		if cap and not zoomCap then
			baseZoom = player.CameraMaxZoomDistance
		end
		zoomCap = cap
		player.CameraMaxZoomDistance = if cap then math.min(baseZoom, cap) else baseZoom
	end
end

-- ── Air ─────────────────────────────────────────────────────────────────────────────────────────
local DESERT_FADE = { 140, 180, 462, 492 } -- [TUNING] camera Z: fade in from..to, fade out from..to
local SAND_SHARE = 0.75 -- [TUNING] how far the basin's air moves toward the desert values below
-- { Lighting child class/name (nil = Lighting itself), property, desert value }. The same luminance
-- as WorldLook's daylight shade (138/160/192 ambient, 164/190/226 outdoor, stepped down in hub round
-- 4 against bleaching), only moved from sky blue toward sun-on-sand warmth: the coral cliffs'
-- shade side reads as a deeper coral instead of mauve-grey, and the sand does not brighten.
local AIR = { -- [TUNING]
	{ nil, "Ambient", Color3.fromRGB(160, 150, 150) },
	{ nil, "OutdoorAmbient", Color3.fromRGB(194, 180, 172) },
	{ "Atmosphere", "Color", Color3.fromRGB(250, 226, 200) },
}

-- The Glacier's air: a deep dusk blue under the ice, about a third darker than the town's daylight
-- shade and still saturated (never grey), so the hamlet's amber windows and fires read as pools of
-- warm light on blue-shadowed snow (gauntlet round 2, after glacier_refs/snow_village.png).
local FROST_FADE = { -104, -150 } -- [TUNING] camera X: fade in from..to (going west), south of z 96
local FROST_SHARE = 0.85 -- [TUNING]
local FROST_AIR = { -- [TUNING] the same three entries as AIR, in the same order
	Color3.fromRGB(84, 104, 172),
	Color3.fromRGB(108, 136, 204),
	Color3.fromRGB(156, 188, 240),
}
local function frostFade(p: Vector3): number
	local f = FROST_FADE
	return math.clamp((p.X - f[1]) / (f[2] - f[1]), 0, 1) * math.clamp((96 - p.Z) / 20, 0, 1)
end

local function desertFade(z: number): number
	local f = DESERT_FADE
	return math.clamp((z - f[1]) / (f[2] - f[1]), 0, 1) * (1 - math.clamp((z - f[3]) / (f[4] - f[3]), 0, 1))
end
local function daylight(t: number): number
	return math.clamp(math.min((t - 6.2) / 1.6, (18.1 - t) / 1.6), 0, 1)
end
local function target(class: string?): Instance?
	if not class then
		return Lighting
	end
	return Lighting:FindFirstChild(class) or Lighting:FindFirstChildOfClass(class)
end

local airBase, airWrote = {}, {}
local function stepAir(at: Vector3)
	local day = daylight(Lighting.ClockTime)
	local w = SAND_SHARE * desertFade(at.Z) * day
	local wf = FROST_SHARE * frostFade(at) * day
	for i, entry in ipairs(AIR) do
		local inst = target(entry[1])
		if not inst then
			continue
		end
		local now = (inst :: any)[entry[2]]
		if airBase[i] == nil or now ~= airWrote[i] then
			airBase[i] = now -- a value WorldLook wrote (or the first read)
		end
		local want = if w > 0 then airBase[i]:Lerp(entry[3], w) else airBase[i]
		if wf > 0 then
			want = want:Lerp(FROST_AIR[i], wf)
		end
		if want ~= now then
			(inst :: any)[entry[2]] = want
		end
		-- what the property reads back (single precision), so our own write is never mistaken for a
		-- new server value and compounded
		airWrote[i] = (inst :: any)[entry[2]]
	end
end

-- ── Sound ───────────────────────────────────────────────────────────────────────────────────────
-- Looping ambience beds, each cross-faded by the camera's distance to its zone. The SoundIds are
-- left for Alex to pick in Studio (Toolbox > Audio): an empty id is simply silent.
local BEDS = { -- [TUNING] { name, SoundId, volume, zone test (camera position -> 0..1) }
	{
		"DesertWind", "", 0.35,
		function(p: Vector3)
			return desertFade(p.Z)
		end,
	},
	{
		"OasisWater", "", 0.4,
		function(p: Vector3) -- the spring pool under the overhang, and the town spring
			local a = (Vector2.new(p.X, p.Z) - Vector2.new(94, 348)).Magnitude
			local b = (Vector2.new(p.X, p.Z) - Vector2.new(73, 284)).Magnitude
			return math.clamp(1 - (math.min(a, b) - 20) / 50, 0, 1)
		end,
	},
	{
		"GlacierWind", "", 0.35,
		function(p: Vector3) -- a cold wind over the ice, all through the Glacier
			return frostFade(p)
		end,
	},
	{
		"BazaarChimes", "", 0.18,
		function(p: Vector3) -- the street of houses and stalls along the basin's east side
			local d = (Vector2.new(p.X, p.Z) - Vector2.new(70, 240)).Magnitude
			return math.clamp(1 - (d - 40) / 60, 0, 1) * desertFade(p.Z)
		end,
	},
}
local beds = {}
for _, bed in ipairs(BEDS) do
	if bed[2] ~= "" then
		local s = Instance.new("Sound")
		s.Name = "ZoneAir_" .. bed[1]
		s.SoundId = bed[2]
		s.Looped = true
		s.Volume = 0
		s.Parent = SoundService
		s:Play()
		table.insert(beds, { sound = s, volume = bed[3], zone = bed[4] })
	end
end
local function stepSound(at: Vector3, dt: number)
	for _, b in ipairs(beds) do
		local want = b.volume * b.zone(at)
		-- ease toward the target so crossing a zone edge is a fade, not a step
		b.sound.Volume += (want - b.sound.Volume) * math.min(1, dt * 2)
	end
end

RunService:BindToRenderStep("ZoneAir", Enum.RenderPriority.Camera.Value + 3, function(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local at = camera.CFrame.Position
	stepAir(at)
	stepZoom()
	if #beds > 0 then
		stepSound(at, dt)
	end
end)
