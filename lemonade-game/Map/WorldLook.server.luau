-- Script | ServerScriptService.WorldLook | Map project.
-- Owns the whole outdoor look: Lighting, the Sky, Atmosphere, Terrain Clouds, post-processing
-- (ColorCorrection, Bloom, SunRays, DepthOfField) and the day/night cycle. It replaces the
-- free-model Workspace.DayCycle, which is parked in ServerStorage.RemovedLegacy.
--
-- The bar is Pet Simulator 99's plastic-toy cartoon: a clean, saturated cyan-blue sky, a bright
-- near-white sun, soft (never black) shadows, and colour that comes from the parts themselves --
-- pale calm surfaces (near-white paths, pale sky-blue castle stone, cream plaster) against a few
-- full-strength accents (hot lime grass, coral domes, orange timber, candy canopies). The palette
-- is baked into the map by tools/map_forge.py and into voxel Terrain by WorldTerrain; this script's
-- job is to light it without recolouring it, so:
--   * the sun tint (ColorShift_Top) is near-white and the shade tint (ColorShift_Bottom) is the
--     sky's own cyan-blue, so a near-white path stays near-white in sun and goes faintly sky-blue in
--     shade instead of turning orange/lavender under a warm-and-violet split;
--   * the ambient fill is bright and near-neutral, so pale surfaces read pale, not tinted;
--   * the grade is close to neutral: a tiny saturation lift and a whisper of contrast. The old
--     +0.55 saturation grade was compensating for muddy terrain that no longer exists -- on a
--     palette that is already full-chroma it clips the accents and drags every pale tint toward
--     the same mid-pastel, which is exactly the flat, washed-out failure the map pass hit;
--   * the Atmosphere is the clean sky colour itself, thin, so distance fades toward sky blue (the
--     one cool colour the whole look is allowed to fade to), never toward grey or amber;
--   * soft cast shadows are on: PS99 has a visible top-lit/shaded split on every toy, and with a
--     bright fill the shadow is a darker, still-saturated version of the same colour, not black.
--
-- History: rounds 1-16 of the earlier Arcane-Odyssey-then-storybook pass are in git (worldlook-v14).
-- That version re-hued three baked models at runtime (recolorHorizon / recolorCastle / recolorGates)
-- to drag grey masonry and hazy far ranges into a warm sandstone family. Those are gone: the Horizon
-- model was scrapped with the castle-wall rebuild, and every castle and gate part is now baked as
-- SmoothPlastic in the PS99 palette (the recolours only ever matched Cobblestone, so at best they
-- were no-ops and at worst they would have repainted the pale sky-blue stone warm sandstone again).
--
-- Every value lives in KEYS, a list of looks pinned to clock times; between two keys each value
-- is blended, so dawn, day, dusk and night flow into each other. Everything runs on the server:
-- Lighting and its children replicate, so every client sees the same sky.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local LOOK_VERSION = "worldlook-v15"

-- [TUNING] Sun path. Roblox's sun always rises at 06:00 and sets at 18:00; latitude tilts the
-- path. At 30 it climbs almost overhead by noon and, by mid afternoon (15:20), stands about 40
-- degrees up in the west, square to the town's north-south road and a touch south of it. Through
-- the late afternoon `lat` eases from 30 to 42, which swings the setting sun from due west round
-- to the south-west so at golden hour it comes in low over the dipped west ridge; through the
-- night it eases back.
local LATITUDE = 30
local START_CLOCK = 9.5
local DAY_SECONDS_PER_HOUR = 55 -- 06:00-18:00 lasts 11 minutes
local NIGHT_SECONDS_PER_HOUR = 25 -- 18:00-06:00 lasts 5 minutes
local STEP = 0.2 -- seconds between look updates (changes are slow, so this is invisible)

-- [TUNING] Cast shadows. PS99's toys carry a soft top-lit/shaded split; with the bright fill below
-- the shadow side stays a darker version of the same colour. Set SHADOWS = false to fall back to
-- the flat, fill-only shading the earlier terrain rounds used.
local SHADOWS = true
local SHADOW_SOFTNESS = 0.55

-- Studio-only fixed clock for world-art captures (see WorldShowcase.client.luau).
local SHOWCASE_CLOCK = { WorldDay = 15.3, WorldSunset = 17.2, WorldTown = 15.3, WorldOasis = 15.3, WorldForest = 15.3 }

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- The PS99 daylight look, shared by every full-day key (morning, day, afternoon). One table so
-- the three keys cannot drift apart again; each key spreads it and overrides only the sun angle.
-- Colour notes (all sRGB, as Studio shows them):
--   top      near-white sun, a hair warm so it never reads blue-white/clinical
--   bottom   the shade tint: the sky's own cyan-blue
--   ambient / outdoor   bright, near-neutral, a touch cool: pale parts stay pale
--   atmoColor / atmoDecay   the clean saturated sky cyan-blue; distance fades toward it
--   ccTint   almost pure white; ccSat a small lift only (the palette is already full-chroma)
--   cloudColor   pure white puffs, a PS99 sky is white-on-cyan
local DAYLIGHT = {
	stars = 0, brightness = 2.2, exposure = 0.05,
	top = rgb(255, 250, 240), bottom = rgb(118, 176, 255),
	ambient = rgb(150, 172, 200), outdoor = rgb(184, 206, 236),
	envDiffuse = 0.35, envSpecular = 0.12,
	atmoDensity = 0.26, atmoOffset = 0.18, atmoColor = rgb(148, 206, 255), atmoDecay = rgb(92, 166, 255),
	atmoGlare = 0.12, atmoHaze = 0.45,
	ccTint = rgb(255, 253, 250), ccSat = 0.12, ccContrast = 0.06, ccBright = 0.0,
	bloomI = 0.12, bloomSize = 18, bloomTh = 3.2,
	raysI = 0.04, raysSpread = 0.4,
	cloudCover = 0.5, cloudDensity = 0.72, cloudColor = rgb(255, 255, 255),
}

local function daylight(overrides: { [string]: any }): { [string]: any }
	local key = table.clone(DAYLIGHT)
	for field, value in pairs(overrides) do
		key[field] = value
	end
	return key
end

-- One look per clock time. Keys must be sorted by `t`; the list wraps from the last to the first.
local KEYS = {
	{
		t = 0, -- deep night: moonlit blue, dim but readable, still saturated (never grey)
		stars = 3000, lat = 30, brightness = 1.1, exposure = -0.1,
		top = rgb(150, 176, 235), bottom = rgb(40, 60, 130),
		ambient = rgb(60, 72, 112), outdoor = rgb(78, 96, 150),
		envDiffuse = 0.35, envSpecular = 0.15,
		atmoDensity = 0.34, atmoOffset = 0.1, atmoColor = rgb(72, 100, 170), atmoDecay = rgb(36, 56, 120),
		atmoGlare = 0, atmoHaze = 0.6,
		ccTint = rgb(214, 224, 255), ccSat = 0.0, ccContrast = 0.06, ccBright = 0,
		bloomI = 0.4, bloomSize = 26, bloomTh = 1.4,
		raysI = 0, raysSpread = 0.5,
		cloudCover = 0.5, cloudDensity = 0.55, cloudColor = rgb(110, 130, 190),
	},
	{
		t = 4.9, -- last of the night
		stars = 3000, lat = 30, brightness = 1.1, exposure = -0.1,
		top = rgb(150, 176, 235), bottom = rgb(40, 60, 130),
		ambient = rgb(60, 72, 112), outdoor = rgb(78, 96, 150),
		envDiffuse = 0.35, envSpecular = 0.15,
		atmoDensity = 0.34, atmoOffset = 0.1, atmoColor = rgb(72, 100, 170), atmoDecay = rgb(36, 56, 120),
		atmoGlare = 0, atmoHaze = 0.6,
		ccTint = rgb(214, 224, 255), ccSat = 0.0, ccContrast = 0.06, ccBright = 0,
		bloomI = 0.4, bloomSize = 26, bloomTh = 1.4,
		raysI = 0, raysSpread = 0.5,
		cloudCover = 0.5, cloudDensity = 0.55, cloudColor = rgb(110, 130, 190),
	},
	{
		t = 6.1, -- dawn: peach sun, lilac shade; a short candy sunrise, not a haze
		stars = 0, lat = 30, brightness = 1.8, exposure = 0,
		top = rgb(255, 200, 160), bottom = rgb(150, 140, 230),
		ambient = rgb(120, 118, 160), outdoor = rgb(160, 156, 204),
		envDiffuse = 0.4, envSpecular = 0.15,
		atmoDensity = 0.3, atmoOffset = 0.14, atmoColor = rgb(255, 190, 170), atmoDecay = rgb(170, 150, 240),
		atmoGlare = 0.4, atmoHaze = 0.7,
		ccTint = rgb(255, 242, 236), ccSat = 0.08, ccContrast = 0.06, ccBright = 0.0,
		bloomI = 0.3, bloomSize = 26, bloomTh = 1.8,
		raysI = 0.1, raysSpread = 0.6,
		cloudCover = 0.55, cloudDensity = 0.65, cloudColor = rgb(255, 224, 214),
	},
	daylight({ t = 8.0, lat = 30 }), -- morning: full PS99 daylight, sun climbing in the east
	daylight({ t = 11.0, lat = 30 }), -- day: sun near overhead
	daylight({ t = 15.5, lat = 30 }), -- afternoon: the capture clock (SHOWCASE_CLOCK), sun 40 degrees up in the west
	{
		-- golden hour: the sun swings south-west and drops to about 11 degrees, raking the town from
		-- behind the Frostbound gate. Warm sun, sky-blue shade -- the same two-tone split as daylight,
		-- just tilted warm, so the pale surfaces go cream, never orange.
		t = 17.2,
		stars = 0, lat = 42, brightness = 3.0, exposure = 0.03,
		top = rgb(255, 214, 150), bottom = rgb(110, 150, 240),
		ambient = rgb(110, 124, 170), outdoor = rgb(140, 160, 214),
		envDiffuse = 0.35, envSpecular = 0.2,
		atmoDensity = 0.3, atmoOffset = 0.14, atmoColor = rgb(255, 196, 140), atmoDecay = rgb(120, 170, 255),
		atmoGlare = 0.9, atmoHaze = 0.8,
		ccTint = rgb(255, 240, 222), ccSat = 0.12, ccContrast = 0.08, ccBright = 0.01,
		bloomI = 0.3, bloomSize = 28, bloomTh = 1.8,
		raysI = 0.16, raysSpread = 0.7,
		cloudCover = 0.5, cloudDensity = 0.62, cloudColor = rgb(255, 226, 196),
	},
	{
		t = 18.3, -- dusk: ember sky, violet shade
		stars = 1200, lat = 42, brightness = 1.6, exposure = 0,
		top = rgb(255, 150, 110), bottom = rgb(120, 96, 200),
		ambient = rgb(96, 88, 140), outdoor = rgb(120, 110, 176),
		envDiffuse = 0.4, envSpecular = 0.15,
		atmoDensity = 0.3, atmoOffset = 0.1, atmoColor = rgb(240, 150, 140), atmoDecay = rgb(120, 96, 200),
		atmoGlare = 0.5, atmoHaze = 0.9,
		ccTint = rgb(255, 230, 224), ccSat = 0.08, ccContrast = 0.08, ccBright = 0,
		bloomI = 0.4, bloomSize = 28, bloomTh = 1.4,
		raysI = 0.1, raysSpread = 0.7,
		cloudCover = 0.52, cloudDensity = 0.62, cloudColor = rgb(236, 160, 170),
	},
	{
		t = 19.6, -- nightfall
		stars = 3000, lat = 30, brightness = 1.1, exposure = -0.1,
		top = rgb(150, 176, 235), bottom = rgb(40, 60, 130),
		ambient = rgb(60, 72, 112), outdoor = rgb(78, 96, 150),
		envDiffuse = 0.35, envSpecular = 0.15,
		atmoDensity = 0.34, atmoOffset = 0.1, atmoColor = rgb(72, 100, 170), atmoDecay = rgb(36, 56, 120),
		atmoGlare = 0, atmoHaze = 0.6,
		ccTint = rgb(214, 224, 255), ccSat = 0.0, ccContrast = 0.06, ccBright = 0,
		bloomI = 0.4, bloomSize = 26, bloomTh = 1.4,
		raysI = 0, raysSpread = 0.5,
		cloudCover = 0.5, cloudDensity = 0.55, cloudColor = rgb(110, 130, 190),
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

-- The cubemap is Roblox's built-in default sky (the Sky object's own defaults, shipped inside the
-- client, so it can never fail to load): a plain, clean light-blue gradient with a few faint wisps,
-- which is already close to PS99's flat cyan-blue and takes the Atmosphere tint cleanly. The
-- earlier "blank cubemap" (six empty faces, sky painted by ColorShift alone) was only ever judged
-- offline; six missing textures are not a guaranteed flat colour in-engine, and ColorShift tints
-- lighting, not the sky dome, so the sky is drawn from a real cubemap plus the Atmosphere below.
-- To try a custom flat-gradient cubemap later, set the six ids here and nothing else changes.
local sky = claim("Sky", "WorldSky", Lighting)
sky.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
sky.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
sky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
sky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
sky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
sky.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
sky.SunTextureId = "rbxasset://sky/sun.jpg"
sky.MoonTextureId = "rbxasset://sky/moon.jpg"
sky.SunAngularSize = 14
sky.MoonAngularSize = 11
sky.StarCount = 3000
sky.CelestialBodiesShown = true

local atmosphere = claim("Atmosphere", "WorldAtmosphere", Lighting)
local grade = claim("ColorCorrectionEffect", "WorldGrade", Lighting)
-- Bloom only catches true highlights (the sun disc, neon, glints): a low threshold smears the
-- pale near-white paths and plaster into fog.
local bloom = claim("BloomEffect", "WorldBloom", Lighting)
local rays = claim("SunRaysEffect", "WorldSunRays", Lighting)
-- No far blur: a toy world stays crisp all the way to the castle wall.
local depth = claim("DepthOfFieldEffect", "WorldDepth", Lighting)
depth.FocusDistance = 120
depth.InFocusRadius = 200
depth.NearIntensity = 0
depth.FarIntensity = 0
depth.Enabled = true

-- Chunky cumulus drifting over the valley (Terrain Clouds, so they sit in the sky dome).
local clouds = claim("Clouds", "WorldClouds", workspace.Terrain)
clouds.Enabled = true

Lighting.GeographicLatitude = LATITUDE
Lighting.GlobalShadows = SHADOWS
Lighting.ShadowSoftness = SHADOW_SOFTNESS
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
