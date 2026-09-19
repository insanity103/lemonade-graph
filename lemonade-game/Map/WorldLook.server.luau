-- Script | ServerScriptService.WorldLook | Map project.
-- Owns the whole outdoor look: Lighting, the Sky, Atmosphere, Terrain Clouds, post-processing
-- (ColorCorrection, Bloom, SunRays, DepthOfField) and the day/night cycle. It replaces the
-- free-model Workspace.DayCycle, which is parked in ServerStorage.RemovedLegacy.
--
-- The look is a warm-sun / cool-shadow split: a strong yellow-white sun about 40 degrees up at mid
-- afternoon raking in from the west, and a low cool grey-blue sky fill, so shade reads as shade, a deep blue zenith that pales to a warm cream
-- horizon, big soft cumulus, and an aerial haze thin enough that the far ranges (LemonadeMap.Horizon)
-- step back as paler, bluer silhouettes instead of dissolving into grey; a light warm grade with a
-- touch of extra saturation pulls grass, rock and sky into one bright, sunny palette.
--
-- Every value lives in KEYS, a list of looks pinned to clock times; between two keys each value
-- is blended, so dawn, day, dusk and night flow into each other. Everything runs on the server:
-- Lighting and its children replicate, so every client sees the same sky.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local LOOK_VERSION = "worldlook-v6"

-- [TUNING] Sun path. Roblox's sun always rises at 06:00 and sets at 18:00; latitude tilts the
-- path. At 30 it climbs almost overhead by noon and, by mid afternoon (15:20), stands about 40
-- degrees up in the west, square to the town's north-south road and a touch south of it, so it
-- rakes across the canyon walls: every ledge and crag top is sunlit, every face toward town and
-- every crevice falls into cool shade, and trees, awnings and the gates throw long crisp shadows
-- across the road. Latitude is also part of each look (`lat`): through the late afternoon it eases
-- from 30 to 42, which swings the setting sun from due west round to the south-west, so at golden
-- hour it comes in low over the dipped west ridge and rakes the town diagonally instead of hiding
-- behind the wall; through the night it eases back.
local LATITUDE = 30
local START_CLOCK = 9.5
local DAY_SECONDS_PER_HOUR = 55 -- 06:00-18:00 lasts 11 minutes
local NIGHT_SECONDS_PER_HOUR = 25 -- 18:00-06:00 lasts 5 minutes
local STEP = 0.2 -- seconds between look updates (changes are slow, so this is invisible)

-- Studio-only fixed clock for world-art captures (see WorldShowcase.client.luau).
local SHOWCASE_CLOCK = { WorldDay = 15.3, WorldSunset = 17.2, WorldTown = 15.3, WorldOasis = 15.3, WorldForest = 15.3 }

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- One look per clock time. Keys must be sorted by `t`; the list wraps from the last to the first.
local KEYS = {
	{
		t = 0, -- deep night: moonlit blue, dim but readable
		stars = 3000, lat = 30, brightness = 1.1, exposure = -0.1,
		top = rgb(70, 90, 150), bottom = rgb(20, 28, 55),
		ambient = rgb(52, 60, 88), outdoor = rgb(70, 84, 122),
		envDiffuse = 0.35, envSpecular = 0.25,
		atmoDensity = 0.34, atmoOffset = 0.1, atmoColor = rgb(80, 96, 138), atmoDecay = rgb(40, 52, 96),
		atmoGlare = 0, atmoHaze = 0.6,
		ccTint = rgb(206, 216, 255), ccSat = -0.12, ccContrast = 0.06, ccBright = 0,
		bloomI = 0.6, bloomSize = 26, bloomTh = 1.1,
		raysI = 0, raysSpread = 0.5,
		cloudCover = 0.5, cloudDensity = 0.55, cloudColor = rgb(96, 108, 142),
	},
	{
		t = 4.9, -- last of the night
		stars = 3000, lat = 30, brightness = 1.1, exposure = -0.1,
		top = rgb(70, 90, 150), bottom = rgb(20, 28, 55),
		ambient = rgb(52, 60, 88), outdoor = rgb(70, 84, 122),
		envDiffuse = 0.35, envSpecular = 0.25,
		atmoDensity = 0.34, atmoOffset = 0.1, atmoColor = rgb(80, 96, 138), atmoDecay = rgb(40, 52, 96),
		atmoGlare = 0, atmoHaze = 0.6,
		ccTint = rgb(206, 216, 255), ccSat = -0.12, ccContrast = 0.06, ccBright = 0,
		bloomI = 0.6, bloomSize = 26, bloomTh = 1.1,
		raysI = 0, raysSpread = 0.5,
		cloudCover = 0.5, cloudDensity = 0.55, cloudColor = rgb(96, 108, 142),
	},
	{
		t = 6.1, -- dawn: rose sun, lilac shade
		stars = 0, lat = 30, brightness = 2.0, exposure = 0,
		top = rgb(255, 176, 130), bottom = rgb(110, 96, 140),
		ambient = rgb(98, 92, 116), outdoor = rgb(128, 118, 148),
		envDiffuse = 0.45, envSpecular = 0.35,
		atmoDensity = 0.36, atmoOffset = 0.12, atmoColor = rgb(236, 190, 170), atmoDecay = rgb(150, 132, 180),
		atmoGlare = 0.6, atmoHaze = 1.8,
		ccTint = rgb(255, 236, 226), ccSat = -0.02, ccContrast = 0.08, ccBright = 0.01,
		bloomI = 0.55, bloomSize = 30, bloomTh = 1.15,
		raysI = 0.12, raysSpread = 0.7,
		cloudCover = 0.55, cloudDensity = 0.65, cloudColor = rgb(255, 212, 196),
	},
	{
		t = 8.0, -- morning: the sun whitens, the shade cools to sky blue
		stars = 0, lat = 30, brightness = 3.6, exposure = 0.05,
		top = rgb(255, 226, 184), bottom = rgb(110, 128, 170),
		ambient = rgb(66, 72, 92), outdoor = rgb(86, 98, 130),
		envDiffuse = 0.25, envSpecular = 0.3,
		atmoDensity = 0.38, atmoOffset = 0.18, atmoColor = rgb(236, 226, 210), atmoDecay = rgb(152, 174, 210),
		atmoGlare = 0.4, atmoHaze = 2.2,
		ccTint = rgb(255, 247, 234), ccSat = -0.04, ccContrast = 0.1, ccBright = 0.02,
		bloomI = 0.3, bloomSize = 22, bloomTh = 2.1,
		raysI = 0.08, raysSpread = 0.6,
		cloudCover = 0.56, cloudDensity = 0.7, cloudColor = rgb(255, 250, 242),
	},
	{
		t = 11.0, -- day: warm yellow sun, blue-violet shade, a thin aerial haze warm at the horizon
		stars = 0, lat = 30, brightness = 4, exposure = -0.03,
		top = rgb(255, 220, 164), bottom = rgb(104, 118, 164),
		ambient = rgb(56, 62, 82), outdoor = rgb(78, 90, 124),
		envDiffuse = 0.22, envSpecular = 0.3,
		atmoDensity = 0.36, atmoOffset = 0.24, atmoColor = rgb(246, 230, 206), atmoDecay = rgb(156, 180, 222),
		atmoGlare = 0.35, atmoHaze = 1.8,
		ccTint = rgb(255, 244, 228), ccSat = 0.03, ccContrast = 0.12, ccBright = 0.01,
		bloomI = 0.25, bloomSize = 20, bloomTh = 2.4,
		raysI = 0.07, raysSpread = 0.55,
		cloudCover = 0.66, cloudDensity = 0.78, cloudColor = rgb(255, 250, 244),
	},
	{
		t = 15.5, -- afternoon, still full day, the sun a touch more golden
		stars = 0, lat = 30, brightness = 4, exposure = -0.03,
		top = rgb(255, 212, 150), bottom = rgb(106, 116, 162),
		ambient = rgb(56, 62, 82), outdoor = rgb(78, 90, 124),
		envDiffuse = 0.22, envSpecular = 0.3,
		atmoDensity = 0.36, atmoOffset = 0.24, atmoColor = rgb(248, 228, 200), atmoDecay = rgb(158, 178, 220),
		atmoGlare = 0.4, atmoHaze = 1.8,
		ccTint = rgb(255, 242, 224), ccSat = 0.03, ccContrast = 0.12, ccBright = 0.01,
		bloomI = 0.25, bloomSize = 20, bloomTh = 2.4,
		raysI = 0.08, raysSpread = 0.55,
		cloudCover = 0.66, cloudDensity = 0.78, cloudColor = rgb(255, 248, 238),
	},
	{
		-- golden hour: the sun has swung round into the south-west and dropped to about 11 degrees,
		-- so it clears the west ridge's low saddle and rakes the town from behind the Frostbound
		-- gate: a saturated amber key on every sun-facing wall, trunk and cobble, long shadows
		-- stretching north-east across the paths, and cool blue-violet shade (a low outdoor fill and
		-- a blue away-from-sun shift) so warm and cool read as a deliberate split, not murk. The
		-- haze turns gold toward the sun and peach away from it (the zenith keeps a little lilac) and
		-- glows round the disc.
		t = 17.2,
		stars = 0, lat = 42, brightness = 5, exposure = 0.05,
		top = rgb(255, 178, 110), bottom = rgb(92, 104, 170),
		ambient = rgb(64, 62, 92), outdoor = rgb(96, 98, 146),
		envDiffuse = 0.3, envSpecular = 0.35,
		atmoDensity = 0.3, atmoOffset = 0.12, atmoColor = rgb(255, 186, 112), atmoDecay = rgb(240, 168, 132),
		atmoGlare = 1.6, atmoHaze = 1.9,
		ccTint = rgb(255, 232, 204), ccSat = 0.08, ccContrast = 0.16, ccBright = 0.01,
		bloomI = 0.45, bloomSize = 30, bloomTh = 1.5,
		raysI = 0.2, raysSpread = 0.8,
		cloudCover = 0.5, cloudDensity = 0.62, cloudColor = rgb(255, 204, 162),
	},
	{
		t = 18.3, -- dusk: ember sky, violet shade
		stars = 1200, lat = 42, brightness = 1.8, exposure = 0,
		top = rgb(255, 140, 96), bottom = rgb(96, 80, 130),
		ambient = rgb(88, 78, 104), outdoor = rgb(108, 96, 134),
		envDiffuse = 0.4, envSpecular = 0.3,
		atmoDensity = 0.36, atmoOffset = 0.1, atmoColor = rgb(214, 150, 140), atmoDecay = rgb(110, 90, 150),
		atmoGlare = 0.5, atmoHaze = 1.6,
		ccTint = rgb(255, 228, 220), ccSat = -0.04, ccContrast = 0.08, ccBright = 0,
		bloomI = 0.6, bloomSize = 30, bloomTh = 1.1,
		raysI = 0.1, raysSpread = 0.7,
		cloudCover = 0.52, cloudDensity = 0.62, cloudColor = rgb(214, 150, 150),
	},
	{
		t = 19.6, -- nightfall
		stars = 3000, lat = 30, brightness = 1.1, exposure = -0.1,
		top = rgb(70, 90, 150), bottom = rgb(20, 28, 55),
		ambient = rgb(52, 60, 88), outdoor = rgb(70, 84, 122),
		envDiffuse = 0.35, envSpecular = 0.25,
		atmoDensity = 0.34, atmoOffset = 0.1, atmoColor = rgb(80, 96, 138), atmoDecay = rgb(40, 52, 96),
		atmoGlare = 0, atmoHaze = 0.6,
		ccTint = rgb(206, 216, 255), ccSat = -0.12, ccContrast = 0.06, ccBright = 0,
		bloomI = 0.6, bloomSize = 26, bloomTh = 1.1,
		raysI = 0, raysSpread = 0.5,
		cloudCover = 0.5, cloudDensity = 0.55, cloudColor = rgb(96, 108, 142),
	},
}

-- ── Instances ────────────────────────────────────────────────────────────────
-- The look owns these by name; anything else of the same class left in Lighting by the place
-- (the old stock sky, grey atmosphere, weak rays) is removed so two of a kind never stack.
local OWNED = { "Sky", "Atmosphere", "ColorCorrectionEffect", "BloomEffect", "SunRaysEffect", "DepthOfFieldEffect" }

local function claim(className: string, name: string, parent: Instance): any
	for _, child in ipairs(parent:GetChildren()) do
		if child.ClassName == className and child.Name ~= name then
			child:Destroy()
		end
	end
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = parent
	return made
end

for _, className in ipairs(OWNED) do
	for _, child in ipairs(Lighting:GetChildren()) do
		if child.ClassName == className and child.Name:sub(1, 5) ~= "World" then
			child:Destroy()
		end
	end
end

-- Roblox's own default clear-sky gradient (a deep saturated blue at the zenith paling toward the
-- horizon; Roblox-owned, so it loads in every place). The Atmosphere warms its horizon to a pale
-- cream, and the Terrain Clouds below paint the cumulus into it.
local sky = claim("Sky", "WorldSky", Lighting)
local SKY_SIDE = "rbxassetid://6444884337"
sky.SkyboxBk = SKY_SIDE
sky.SkyboxFt = SKY_SIDE
sky.SkyboxLf = SKY_SIDE
sky.SkyboxRt = SKY_SIDE
sky.SkyboxDn = "rbxassetid://6444884785"
sky.SkyboxUp = "rbxassetid://6412503613"
sky.SunTextureId = "rbxasset://sky/sun.jpg"
sky.MoonTextureId = "rbxasset://sky/moon.jpg"
sky.SunAngularSize = 14
sky.MoonAngularSize = 11
sky.StarCount = 3000
sky.CelestialBodiesShown = true

local atmosphere = claim("Atmosphere", "WorldAtmosphere", Lighting)
local grade = claim("ColorCorrectionEffect", "WorldGrade", Lighting)
-- Bloom only catches true highlights (the sun disc, neon, glints): with a strong sun the lit rock
-- itself is bright, and a low threshold smeared it into white fog bands across the canyon walls.
local bloom = claim("BloomEffect", "WorldBloom", Lighting)
local rays = claim("SunRaysEffect", "WorldSunRays", Lighting)
-- The faintest far blur: the town and its cliffs stay crisp (texture on the rock is what sells
-- its scale), and only the country past the gates softens a touch; the haze does the rest.
local depth = claim("DepthOfFieldEffect", "WorldDepth", Lighting)
depth.FocusDistance = 120
depth.InFocusRadius = 200
depth.NearIntensity = 0
depth.FarIntensity = 0.04
depth.Enabled = true

-- Volumetric cumulus drifting over the valley (Terrain Clouds, so they sit in the sky dome).
local clouds = claim("Clouds", "WorldClouds", workspace.Terrain)
clouds.Enabled = true

Lighting.GeographicLatitude = LATITUDE
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.06 -- crisp, so every canopy, awning and crag throws a hard-edged shadow
Lighting.FogStart = 0
Lighting.FogEnd = 100000
Lighting.ClockTime = START_CLOCK

-- ── Blending ─────────────────────────────────────────────────────────────────
local function lerp(a: any, b: any, f: number): any
	if typeof(a) == "number" then
		return a + (b - a) * f
	end
	return a:Lerp(b, f)
end

-- Smoothstep between keys, so each phase eases in and out instead of turning a corner.
local function sample(clock: number): { [string]: any }
	local n = #KEYS
	local prev, nextKey = KEYS[n], KEYS[1]
	local span, into
	for i = 1, n do
		local key = KEYS[i]
		local following = KEYS[i % n + 1]
		local t0, t1 = key.t, following.t
		if t1 <= t0 then
			t1 += 24
		end
		local c = clock
		if c < t0 then
			c += 24
		end
		if c >= t0 and c < t1 then
			prev, nextKey, span, into = key, following, t1 - t0, c - t0
			break
		end
	end
	local f = if span and span > 0 then into / span else 0
	f = f * f * (3 - 2 * f)
	local out = {}
	for field, value in pairs(prev) do
		out[field] = lerp(value, nextKey[field], f)
	end
	return out
end

local function apply(look: { [string]: any })
	Lighting.GeographicLatitude = look.lat
	-- Roblox starts drawing stars well before sunset; hold them back until dusk so the golden sky
	-- stays clean.
	sky.StarCount = math.round(look.stars)
	Lighting.Brightness = look.brightness
	Lighting.ExposureCompensation = look.exposure
	Lighting.ColorShift_Top = look.top
	Lighting.ColorShift_Bottom = look.bottom
	Lighting.Ambient = look.ambient
	Lighting.OutdoorAmbient = look.outdoor
	Lighting.EnvironmentDiffuseScale = look.envDiffuse
	Lighting.EnvironmentSpecularScale = look.envSpecular

	atmosphere.Density = look.atmoDensity
	atmosphere.Offset = look.atmoOffset
	atmosphere.Color = look.atmoColor
	atmosphere.Decay = look.atmoDecay
	atmosphere.Glare = look.atmoGlare
	atmosphere.Haze = look.atmoHaze

	grade.TintColor = look.ccTint
	grade.Saturation = look.ccSat
	grade.Contrast = look.ccContrast
	grade.Brightness = look.ccBright

	bloom.Intensity = look.bloomI
	bloom.Size = look.bloomSize
	bloom.Threshold = look.bloomTh

	rays.Intensity = look.raysI
	rays.Spread = look.raysSpread

	clouds.Cover = look.cloudCover
	clouds.Density = look.cloudDensity
	clouds.Color = look.cloudColor
end

local function showcaseClock(): number?
	if not RunService:IsStudio() then
		return nil
	end
	local name = workspace:GetAttribute("GuiShowcase")
	return if typeof(name) == "string" then SHOWCASE_CLOCK[name] else nil
end

-- ── Cycle ────────────────────────────────────────────────────────────────────
local clock = showcaseClock() or START_CLOCK
Lighting.ClockTime = clock
apply(sample(clock))
Lighting:SetAttribute("WorldLook", LOOK_VERSION)
print(string.format("[WorldLook] %s owns the sky (clock %.1f, latitude %d)", LOOK_VERSION, clock, LATITUDE))

while true do
	local dt = task.wait(STEP)
	local held = showcaseClock()
	if held then
		clock = held
	else
		local secondsPerHour = if clock >= 6 and clock < 18 then DAY_SECONDS_PER_HOUR else NIGHT_SECONDS_PER_HOUR
		clock = (clock + dt / secondsPerHour) % 24
	end
	if math.abs(Lighting.ClockTime - clock) > 1e-4 then
		Lighting.ClockTime = clock
		apply(sample(clock))
	end
end
