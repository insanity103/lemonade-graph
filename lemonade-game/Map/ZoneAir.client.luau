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
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

-- ── Air ─────────────────────────────────────────────────────────────────────────────────────────
local DESERT_FADE = { 140, 180, 462, 492 } -- [TUNING] camera Z: fade in from..to, fade out from..to
local SAND_SHARE = 0.85 -- [TUNING] how far the basin's air moves toward the desert values below
-- { Lighting child class/name (nil = Lighting itself), property, desert value }. Bright and warm:
-- the same luminance as the town's shade, moved from sky blue to sun-on-sand cream, never brown.
local AIR = { -- [TUNING]
	{ nil, "Ambient", Color3.fromRGB(184, 168, 158) },
	{ nil, "OutdoorAmbient", Color3.fromRGB(228, 208, 190) },
	{ "Atmosphere", "Color", Color3.fromRGB(255, 234, 204) },
	{ "WorldGrade", "TintColor", Color3.fromRGB(255, 251, 242) },
}

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
local function stepAir(z: number)
	local w = SAND_SHARE * desertFade(z) * daylight(Lighting.ClockTime)
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
	stepAir(at.Z)
	if #beds > 0 then
		stepSound(at, dt)
	end
end)
