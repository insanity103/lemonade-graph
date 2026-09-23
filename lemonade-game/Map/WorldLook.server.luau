-- Script | ServerScriptService.WorldLook | Map project.
-- Owns the whole outdoor look: Lighting, the Sky, Atmosphere, Terrain Clouds, post-processing
-- (ColorCorrection, Bloom, SunRays, DepthOfField) and the day/night cycle. It replaces the
-- free-model Workspace.DayCycle, which is parked in ServerStorage.RemovedLegacy.
--
-- The look is a warm-sun / saturated-violet-shadow split: a strong yellow-white sun about 40 degrees
-- up at mid afternoon, and a low, bright, still-colourful blue-violet sky fill (never grey) that lifts
-- every face away from the sun so shade reads as a darker, still-saturated version of the same hue,
-- never a muted grey-brown; a deep blue zenith that pales to a warm cream horizon, big soft cumulus,
-- and a thin, warm-tinted haze so the far ranges (LemonadeMap.Horizon) step back gently instead of
-- dissolving into grey-tan fog. Round-7 fix: the ranges' own baked rock colour (not the haze) is
-- what was reading grey-mauve at distance, so it is re-hued at script start into the same warm
-- gold/rust family as the near canyon walls (see recolorHorizon below); a strong warm grade with real extra
-- saturation pulls grass, rock and sky into one bright, high-key, storybook-cartoon palette (Pet
-- Simulator 99 is the bar: no muddy or desaturated passages anywhere in frame, and no realistic hard
-- cast shadow or specular sheen on the rock -- shadows are cast by soft ambient fill only, so cliff
-- faces stay flat, matte and vivid instead of reading as directionally-lit PBR stone). Round-8 fix:
-- the daylight keys' own high Brightness was still driving a smooth photoreal highlight-to-shade
-- gradient across Terrain's curved voxel normals no matter how the rock's base colour was tuned;
-- Brightness is now cut hard on every full-day key and Ambient/OutdoorAmbient (flat, non-directional
-- fill) raised in its place, so total exposure holds bright while the lit/shaded spread collapses
-- toward one flat, saturated colour per face, and Bloom threshold is raised past any terrain
-- luminance so a sunlit crag can never itself soften into a haze halo. Round-9 fix: the baked
-- castle wall and towers ringing the hub (tools/map_forge.py) are a near-zero-saturation grey
-- "cobblestone" stone family that reads washed-out next to the rest of this bright palette; they
-- are re-hued at runtime into a warm, saturated cream/tan family (see recolorCastle below), the
-- same baked-colour-recolour trick recolorHorizon already uses on the far country.
--
-- Round-11 fix (named gap): the skybox itself was Roblox's stock "Sunny" cubemap (rbxassetid://
-- 6444884337 etc) -- a naturalistic realistic-blue gradient with soft, photographic-style clouds
-- baked into the image, sitting over the canyon's earthy orange-brown rock. That reads as a grounded
-- outdoor fantasy setting, not storybook. Two changes: (1) the cubemap's own faces are now blank
-- (no baked photo-cloud texture at all) so only the flat, fully-tunable ColorShift_Top/Bottom
-- gradient shows -- a warm peach/lavender horizon blending into a saturated blue zenith, painted, not
-- photographed -- with the flat-shaded Terrain Clouds (chunky voxel puffs, already storybook) as the
-- only visible cloud shapes; Atmosphere.Glare is raised on the daylight keys for a soft colour-bloom
-- glow around the sun disc. (2) WorldTerrain's Rock/Sandstone/Limestone/Slate/Basalt/Asphalt are
-- pushed several degrees warmer into coral/tangerine (see WorldTerrain.server.luau); HORIZON_ROCK_HUE
-- below is re-matched to the same family so the far country doesn't fall back out of step.
--
-- Round-14 fix (HARD RULE): rounds 12-13 chased "more saturated" with no hue ceiling and walked
-- WorldTerrain's Rock/Basalt off warm terracotta into a broken-texture candy magenta, which the
-- day/afternoon keys' Top/atmoColor/atmoDecay/ccTint/cloudColor and HORIZON_ROCK_HUE below all
-- followed into pink-purple to match. Rock/Basalt are hand-fixed back to warm terracotta/rust, and a
-- hard rule now bars terrain materials from ever going cool (pink/magenta/purple/teal) again; every
-- value here that had chased the magenta rock is reverted to the matching warm amber/peach family
-- instead of fighting it. The deliberate cool blue-violet Bottom shade tint is untouched -- it is the
-- warm-sun/violet-shadow split this whole look is built on, a shade tint, never a terrain colour, so
-- the hard rule does not apply to it.
--
-- Round-15 fix (named gap): the round-9 castle recolour (below) pinned the wall to a cream/tan hue
-- but only half the surrounding rock's saturation (0.42 against Rock/Sandstone's 0.74-0.84), so next
-- to the vivid terracotta/gold canyon and the tower caps' saturated red it still read as the
-- washed-out, low-chroma band critics called out. CASTLE_STONE_SAT is raised to match the rock family
-- and CASTLE_STONE_HUE is nudged from cream (42 deg) to a warmer ochre/sandstone (34 deg, matching
-- WorldTerrain's own Sandstone hue) so the whole wall reads as saturated as the stone around it,
-- never past it into the rock's own hue (that would flatten the wall into the cliff instead of
-- reading as built masonry) and never toward any cool hue (the hard rule above).
--
-- Round-16 fix (named gap): the castle-wall recolour above only ever re-hued parts tagged with the
-- CastleWall/CastleTower attribute, so the Iron Lowlands gate's own archway pillars (tools/
-- map_forge.py's gate() -- a separate baked model, un-tagged, un-touched by recolorCastle) kept
-- their raw STONE/STONE_DARK Cobblestone grey and read as plain, neutral stone punched through the
-- vivid orange cliff either side of it -- exactly the "grey pulls the frame toward realism" gap
-- named this round. recolorGates() below applies the same baked-colour-recolour trick to every
-- sealed/open zone gate's Cobblestone pillars (matched by each gate model's own baked Region
-- attribute), warm-sandstone/gold to match the cliffs, never grey. Same round, second half of the
-- gap: the daytime sky read as a naturalistic, photographically clear pale blue rather than a
-- stylized storybook tone -- the day/afternoon keys' `bottom` (the sky's own zenith paint, per the
-- round-11 note above) is pushed to a richer, more saturated storybook cobalt so the sky itself
-- reads as painted, not photographed, without drifting toward the violet-shadow family's own hue
-- (a hue-neutral intensity push, same rule as ccSat's saturation-only bumps in earlier rounds).
--
-- Every value lives in KEYS, a list of looks pinned to clock times; between two keys each value
-- is blended, so dawn, day, dusk and night flow into each other. Everything runs on the server:
-- Lighting and its children replicate, so every client sees the same sky.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local LOOK_VERSION = "worldlook-v14"

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
		atmoDensity = 0.28, atmoOffset = 0.12, atmoColor = rgb(255, 176, 140), atmoDecay = rgb(160, 130, 190),
		atmoGlare = 0.6, atmoHaze = 0.9,
		ccTint = rgb(255, 236, 226), ccSat = 0.14, ccContrast = 0.09, ccBright = 0.01,
		bloomI = 0.55, bloomSize = 30, bloomTh = 1.15,
		raysI = 0.12, raysSpread = 0.7,
		cloudCover = 0.55, cloudDensity = 0.65, cloudColor = rgb(255, 212, 196),
	},
	{
		t = 8.0, -- morning: the sun whitens, the shade cools to sky blue but stays bright and saturated;
		-- fill lifted and haze cut hard so the canyon walls hold flat, saturated colour instead of
		-- greying out in their recessed folds or fading toward the mountains. Round-4 fix: the
		-- Decay colour (what the atmosphere fades distant rock toward) was a cool blue-lavender,
		-- which bleached the mid-ground canyon strata pale grey no matter how thin the haze was;
		-- Decay is now the same warm amber-ochre as the sunlit sandstone, so distance dims the rock
		-- toward more of itself, never toward grey, and density/haze are cut further on top.
		-- Round-5 fix: re-tinted to sit inside WorldTerrain's new brighter, more saturated rock family
		-- (rust Rock, gold Sandstone/Limestone) rather than the old paler amber, now that the rock's
		-- own base colour carries the saturation instead of leaning on the haze to fake it.
		-- Round-6 fix: Bloom/SunRays/Glare were stacking into a large hazy white/peach blowout around
		-- the sun instead of a small tight highlight, pushing a whole quadrant of sky pale -- all three
		-- cut hard (bloom threshold raised so only the sun disc itself catches it) so the sky stays a
		-- deep, uniformly saturated blue with crisp white cloud shapes, never a washed-out patch.
		-- Round-8 fix (named gap): a high Brightness (3.4) driving the sun's own directional term was
		-- still the actual cause of the "naturalistic gradient" critics named -- Terrain's voxel rock
		-- has smoothed, curved normals, so a strong sun term shades it in a smooth photoreal gradient
		-- from a near-white blown highlight on sun-facing curves down to a dark unlit face, no matter
		-- how the base colour or haze are tuned. Brightness is cut hard and Ambient/OutdoorAmbient (a
		-- flat, non-directional fill) raised to fill the gap, so total exposure holds bright and high-key
		-- while the *spread* between a rock's lit and shaded side collapses toward one flat, saturated
		-- colour block. EnvironmentSpecularScale is dropped to 0 (no sheen), and Bloom threshold is
		-- raised well above any realistic terrain luminance so a sunlit crag can never itself bloom into
		-- a soft halo -- edges of every rock band stay crisp, not hazy.
		-- Round-8 second pass: Brightness 2.0 still let the sun's own directional term outweigh the
		-- flat ambient fill enough to hold a visible smooth sweep from lit to shaded rock. Brightness is
		-- cut again, hard, and Ambient/OutdoorAmbient raised to near-match it, so the directional term
		-- is now a small fraction of the flat fill: only the crag tips squarest to the sun clip toward
		-- one small soft highlight (the target language's own rule), the rest of every face reads as
		-- close to one flat, saturated colour.
		stars = 0, lat = 30, brightness = 1.1, exposure = 0.15,
		top = rgb(255, 226, 184), bottom = rgb(110, 128, 170),
		ambient = rgb(176, 178, 208), outdoor = rgb(216, 220, 242),
		envDiffuse = 0.2, envSpecular = 0.0,
		atmoDensity = 0.05, atmoOffset = 0.1, atmoColor = rgb(255, 216, 156), atmoDecay = rgb(230, 136, 70),
		atmoGlare = 0.07, atmoHaze = 0.09,
		ccTint = rgb(255, 247, 234), ccSat = 0.34, ccContrast = 0.09, ccBright = 0.01,
		bloomI = 0.06, bloomSize = 14, bloomTh = 6.0,
		raysI = 0.03, raysSpread = 0.4,
		cloudCover = 0.56, cloudDensity = 0.7, cloudColor = rgb(255, 250, 242),
	},
	{
		t = 11.0, -- day: warm yellow sun, saturated blue-violet shade lifted bright so cliff faces away
		-- from the sun read as darker-saturated sandstone, never grey-brown; fill raised further and
		-- haze cut hard (round-3 fix) so recessed folds stay saturated orange instead of greying out
		-- and the far canyon walls hold their colour instead of fading toward tan-grey. Round-4 fix:
		-- Decay retinted from a pale lavender-grey to warm amber-ochre and density/haze dropped
		-- further still, so the background canyon wall never bleaches toward cream/grey.
		-- Round-5 fix: Decay/Color re-tinted to match the new, more saturated Rock/Sandstone/Limestone
		-- family directly rather than fighting the old paler tan with haze tuning alone.
		-- Round-6 fix: same Bloom/SunRays/Glare blowout as the morning key -- cut hard here too so the
		-- upper-frame sky (where WorldDay's showcase camera catches the sun) never bleaches pale.
		-- Round-6 second pass: cutting only Bloom/SunRays still left a soft graduated wash near the
		-- sun -- that's Atmosphere's own scattering halo (Glare/Density/Offset), not a postprocess
		-- effect, so those are dropped further too, and the midday cloud bank (high Cover/Density,
		-- near-white Color) is thinned and re-tinted a touch blue so it reads as sky-lit puffs, not a
		-- second pale patch next to the sun.
		-- Round-8 fix (named gap, same as the morning key): Brightness cut hard and the flat ambient
		-- fill raised in its place, so the canyon's curved voxel rock stops shading in a smooth
		-- photoreal gradient from blown-white highlight to dark shade and instead holds close to one
		-- flat, saturated colour per face; specular dropped to 0 and Bloom threshold raised well past
		-- any terrain luminance so a lit crag never blooms into soft haze.
		-- Round-8 second pass: same tightening as the morning key -- Brightness cut again and
		-- Ambient/OutdoorAmbient raised to near-match it, so the sun's own directional sweep across
		-- the canyon rock shrinks to a small highlight instead of a visible gradient across the face.
		-- Round-14 fix: this key's Top/atmoColor/atmoDecay/ccTint/cloudColor were pushed pink-magenta in
		-- round 12 to match WorldTerrain's Rock, which a HARD RULE has since barred from ever going
		-- cool (pink/magenta/purple/teal); Rock is back to warm terracotta, so every value below is
		-- reverted to the matching warm amber/peach family instead of fighting it. ccSat's extra
		-- saturation push is kept (it is a hue-neutral intensity boost, not a hue, and the bar wants
		-- more saturated, never less).
		-- Round-16 fix (named gap): `bottom` was a soft, fairly low-chroma blue-violet (sat 0.47) that
		-- read as a naturalistic clear-sky blue rather than a stylized storybook tone; pushed to a
		-- richer, higher-chroma cobalt (sat ~0.64) at the same hue and a touch brighter, so the sky
		-- itself reads as a deliberate saturated paint colour, not a photographed atmosphere.
		stars = 0, lat = 30, brightness = 1.0, exposure = 0.15,
		top = rgb(255, 196, 140), bottom = rgb(76, 92, 220),
		ambient = rgb(196, 182, 210), outdoor = rgb(228, 218, 240),
		envDiffuse = 0.2, envSpecular = 0.0,
		atmoDensity = 0.07, atmoOffset = 0.06, atmoColor = rgb(255, 178, 112), atmoDecay = rgb(216, 122, 70),
		atmoGlare = 0.35, atmoHaze = 0.15,
		ccTint = rgb(255, 244, 228), ccSat = 0.55, ccContrast = 0.11, ccBright = 0.01,
		bloomI = 0.13, bloomSize = 18, bloomTh = 4.4,
		raysI = 0, raysSpread = 0.35,
		cloudCover = 0.62, cloudDensity = 0.68, cloudColor = rgb(255, 250, 240),
	},
	{
		t = 15.5, -- afternoon, still full day, the sun a touch more golden; haze cut hard (round-3 fix)
		-- and shade lifted further so the canyon walls read as flat, high-saturation sandstone colour
		-- blocks with soft cartoon shading -- never desaturated grey-tan fog or grey-brown shadow.
		-- Round-4 fix (biggest named gap): the Decay colour the Atmosphere fades distant rock toward
		-- was a pale lavender-grey, which is exactly what bleached the mid-ground canyon strata to a
		-- flat cream/grey band between the two cliff walls. Decay is now warm amber-ochre -- close to
		-- the sunlit sandstone hue itself -- so distance darkens the rock toward more sandstone,
		-- never toward grey, and density/haze/offset are all dropped further so the effect barely
		-- shows at all; the far wall now reads the same saturated burnt-orange as the near one.
		-- Round-5 fix (root cause): the rock's own SetMaterialColor was the real source of any residual
		-- muddy/washed look, not the haze -- Rock/Sandstone/Limestone are now a brighter, more
		-- saturated warm gold/rust family, and Decay/Color here are retinted to match that family
		-- instead of the old paler amber, so distance still dims toward saturated rock, never grey.
		-- Round-6 fix (named gap): critics called out a large hazy, blown-out white/peach patch in the
		-- WorldDay showcase's upper-right sky -- Bloom, SunRays and Atmosphere Glare were compounding
		-- into a soft wash around the sun far bigger than the disc itself. All three are cut hard here
		-- (bloom threshold raised well above the sky/cloud luminance, size shrunk, rays and glare
		-- dropped near-off) so only the sun disc itself ever catches a highlight; the sky and clouds
		-- around it stay flat, deep and uniformly saturated instead of fading toward pale cream.
		-- Round-6 second pass: the residual wash was Atmosphere's own scattering halo (Glare/Density/
		-- Offset), not a postprocess effect, so those are dropped further, and the cloud bank is
		-- thinned and tinted a touch blue so it reads as sky-lit puffs, not a second pale patch.
		-- Round-8 fix (biggest named gap, this is the WorldDay showcase key): the critics' "naturalistic
		-- gradient shading and soft directional sunlight" on the mountain terrain traced to this key's
		-- own high Brightness (3.4) -- Terrain's smooth voxel normals turn any strong single-direction
		-- sun term into a soft photoreal highlight-to-shade gradient across every crag, no matter the
		-- base colour. Brightness is cut hard and Ambient/OutdoorAmbient raised in its place (a flat,
		-- non-directional fill that lights every face the same regardless of which way it turns), so
		-- overall exposure stays bright and high-key while the lit/shaded spread on the rock collapses
		-- toward a single flat, saturated colour; specular dropped to 0 (no sheen) and Bloom threshold
		-- raised well above any terrain luminance so no sunlit crag can bloom into soft haze -- the
		-- cliffs read as flat storybook colour blocks with one soft highlight, not directionally-lit
		-- stone.
		-- Round-8 second pass: even Brightness 1.9 still let the sun's directional term outweigh the
		-- flat ambient fill enough to hold a visible smooth sweep across the rock in captures --
		-- Brightness is cut again, hard, and Ambient/OutdoorAmbient raised to near-match it, so the
		-- directional term is now only a small top-up on a bright flat fill: just the crag tips
		-- squarest to the sun clip toward one small soft highlight, everything else reads flat.
		-- Round-11 fix (named gap, this is the WorldDay showcase key): the stock photographic skybox
		-- cubemap is now blank (see the Sky block above), so the sky is drawn from this Atmosphere
		-- alone -- Density/Haze/Glare are raised off their round-6/8 near-zero floor (which existed
		-- only to stop a *photographed* cloud texture from smearing into terrain fog) into a
		-- deliberate, warm-pink Color/coral Decay so the horizon band paints itself a storybook
		-- peach/lavender that blends up into the sky's own saturated blue, and Glare gives the sun
		-- disc a soft colour-bloom halo instead of a hard photographic point. Terrain stays clean
		-- because Decay is pinned to the same coral family WorldTerrain's rock now uses, so the
		-- added haze dims distant rock toward more coral, never toward grey. Cloud Cover/Density are
		-- raised and Color flattened toward warm white so Terrain's chunky, flat-shaded cumulus (not
		-- a baked photo texture) become the frame's obvious cloud shapes.
		-- Round-12 fix (named gap, LATER REVERTED round-14): even a painted, un-photographic sky still
		-- sat on the same warm coral/orange family as the naturalistic canyon it was replacing --
		-- critics read the whole Iron Lowlands entrance as a grounded, sun-baked fantasy zone rather
		-- than storybook-cartoon. Color/Decay were pushed round the wheel into hot pink/magenta
		-- (matching WorldTerrain's then-new candy-magenta Rock family) and top/bottom followed the same
		-- swing, so the sky read pink-purple end to end instead of blue-violet.
		-- Round-14 fix (HARD RULE): rounds 12-13 correctly flagged that magenta Rock as a broken-texture
		-- look, not a deliberate storybook colour, and it was hand-fixed back to warm terracotta; a hard
		-- rule now bars any cool hue (pink/magenta/purple/teal) from terrain materials. This key (the
		-- WorldDay showcase key) is reverted to match: Top/atmoColor/atmoDecay/ccTint/cloudColor back to
		-- the warm amber/peach family, Bottom kept a deliberate cool blue-violet shade tint (the
		-- warm-sun/violet-shadow split this whole look is built on, never a terrain colour, so the hard
		-- rule does not apply to it) rather than following Rock's hue at all.
		-- Round-16 fix (named gap, this is the WorldDay showcase key): critics read this key's sky as
		-- "a naturalistic clear blue" -- `bottom` (the sky's own zenith paint, per the round-11 note
		-- above) sat at only 0.47 saturation, pale enough to look photographed rather than painted.
		-- Pushed to a richer, higher-chroma storybook cobalt (sat ~0.64) at the same hue (a hue-neutral
		-- intensity push, same rule ccSat's own saturation bumps already follow) and a touch brighter,
		-- so the sky reads as one deliberate saturated colour block, matching the cliffs' own high-key
		-- saturation instead of sitting next to them as a comparatively washed, realistic gradient.
		stars = 0, lat = 30, brightness = 1.0, exposure = 0.15,
		top = rgb(255, 192, 132), bottom = rgb(78, 96, 224),
		ambient = rgb(198, 180, 212), outdoor = rgb(230, 216, 242),
		envDiffuse = 0.2, envSpecular = 0.0,
		atmoDensity = 0.075, atmoOffset = 0.06, atmoColor = rgb(255, 172, 104), atmoDecay = rgb(222, 126, 68),
		atmoGlare = 0.4, atmoHaze = 0.16,
		ccTint = rgb(255, 242, 224), ccSat = 0.58, ccContrast = 0.11, ccBright = 0.01,
		bloomI = 0.14, bloomSize = 20, bloomTh = 4.2,
		raysI = 0, raysSpread = 0.35,
		cloudCover = 0.64, cloudDensity = 0.7, cloudColor = rgb(255, 248, 236),
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
		ambient = rgb(62, 58, 100), outdoor = rgb(92, 96, 158),
		envDiffuse = 0.3, envSpecular = 0.35,
		atmoDensity = 0.24, atmoOffset = 0.12, atmoColor = rgb(255, 176, 100), atmoDecay = rgb(248, 158, 128),
		atmoGlare = 1.5, atmoHaze = 1.0,
		ccTint = rgb(255, 226, 196), ccSat = 0.2, ccContrast = 0.17, ccBright = 0.02,
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
		atmoDensity = 0.3, atmoOffset = 0.1, atmoColor = rgb(232, 150, 128), atmoDecay = rgb(120, 90, 160),
		atmoGlare = 0.5, atmoHaze = 1.0,
		ccTint = rgb(255, 224, 214), ccSat = 0.1, ccContrast = 0.1, ccBright = 0,
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

-- Round-11 fix (named gap): the previous cubemap here (rbxassetid://6444884337 etc, Roblox's stock
-- "Sunny" pack) is a naturalistic-blue sky with soft photographic clouds baked into the image itself
-- -- no amount of Atmosphere/ColorCorrection tuning can turn a baked photo-cloud texture into a flat
-- painted one. Left blank, the six faces render nothing, so the sky is drawn purely from
-- ColorShift_Top/Bottom below: a flat, fully-authored two-colour gradient (warm peach/lavender
-- horizon paling into a saturated blue zenith) with no photographic detail at all. The only visible
-- clouds are now the flat-shaded Terrain Clouds (chunky voxel puffs, already storybook), and
-- Atmosphere.Glare (raised on the daylight keys below) paints a soft colour-bloom glow around the
-- sun disc instead of relying on a photographed halo.
local sky = claim("Sky", "WorldSky", Lighting)
sky.SkyboxBk = ""
sky.SkyboxFt = ""
sky.SkyboxLf = ""
sky.SkyboxRt = ""
sky.SkyboxDn = ""
sky.SkyboxUp = ""
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
-- No far blur: a storybook-cartoon world stays crisp all the way to the horizon (soft photographic
-- depth-of-field reads as naturalistic, not toy-bright), so distant peaks stay sharp, saturated
-- silhouettes instead of softening into grey haze. Depth is cued by the thin, warm Atmosphere alone.
local depth = claim("DepthOfFieldEffect", "WorldDepth", Lighting)
depth.FocusDistance = 120
depth.InFocusRadius = 200
depth.NearIntensity = 0
depth.FarIntensity = 0
depth.Enabled = true

-- Volumetric cumulus drifting over the valley (Terrain Clouds, so they sit in the sky dome).
local clouds = claim("Clouds", "WorldClouds", workspace.Terrain)
clouds.Enabled = true

-- ── Horizon rock recolour (round-7 fix, named gap) ────────────────────────────
-- tools/map_forge.py bakes the far country (LemonadeMap.Horizon) with real atmospheric-perspective
-- shading: every mountain facet's hue is pulled toward a pale blue-grey HAZE by how far and how low
-- it stands, and the far Far* massifs (haze_share 0.5, versus the near range's 0.24) end up dusty
-- grey-mauve/tan -- naturalistic aerial haze, exactly the look this pass rejects. A full
-- map_forge.py rebuild would re-bake it correctly but is a much bigger, riskier lift than a pure
-- art pass calls for, so it is re-hued at runtime instead, the same trick WorldTerrain uses on
-- Terrain's own baked material colour: every facet keeps its own baked brightness (so ridgelines,
-- gullies and the sun/shade split still read as shaped rock) but its hue and saturation are pinned
-- to the same warm gold/rust family WorldTerrain paints the near canyon walls, with value clamped
-- to a narrow, bright band so the darkest facet is a darker version of that same hue -- never grey
-- -- and the palest never bleaches past the near cliffs' own highlight. Filtered by Material (Rock
-- for the Far/Range facets, SmoothPlastic for the Side ranges' diamond peaks) rather than by name,
-- so Snow-material caps stay storybook white/pale-blue and Grass-material foothills/forest slopes
-- stay green, untouched.
-- Round-14 fix: WorldTerrain's Rock family was hand-fixed off candy magenta back to warm terracotta
-- (a HARD RULE now bars any cool hue -- pink/magenta/purple/teal -- from terrain materials), so the
-- horizon's re-hue is re-matched to that same warm terracotta hue instead of following it into magenta.
local HORIZON_ROCK_HUE = 18 / 360 -- warm terracotta, matching WorldTerrain's Round-14 Rock family
local HORIZON_ROCK_SAT = 0.78
local HORIZON_ROCK_V_LO, HORIZON_ROCK_V_HI = 0.6, 0.95

local function recolorHorizon()
	local lemonadeMap = workspace:FindFirstChild("LemonadeMap")
	local horizon = lemonadeMap and lemonadeMap:FindFirstChild("Horizon")
	if not horizon then
		return
	end
	for _, inst in ipairs(horizon:GetDescendants()) do
		if inst:IsA("BasePart") and (inst.Material == Enum.Material.Rock or inst.Material == Enum.Material.SmoothPlastic) then
			local _, _, v = inst.Color:ToHSV()
			local vv = HORIZON_ROCK_V_LO + (HORIZON_ROCK_V_HI - HORIZON_ROCK_V_LO) * v
			inst.Color = Color3.fromHSV(HORIZON_ROCK_HUE, HORIZON_ROCK_SAT, vv)
		end
	end
end
recolorHorizon()

-- ── Castle wall recolour (round-9 fix, named gap) ─────────────────────────────
-- tools/map_forge.py bakes the Hearthmere castle wall and its towers ringing the hub in a
-- near-zero-saturation "cobblestone grey" family (CASTLE_STONE/CASTLE_STONE_SHADE/CASTLE_TRIM):
-- flat grey/white masonry that reads washed-out against the bright storybook world around it,
-- even though the tower caps are already a saturated terracotta-red accent. A full map_forge.py
-- rebuild would repaint it correctly but is a much bigger, riskier lift than a pure art pass calls
-- for, so -- the same trick recolorHorizon uses on the baked far country above -- every stone part
-- is re-hued at runtime into a warm, saturated cream/tan family, keeping each part's own baked
-- brightness (so the base course, body, buttresses and merlons still read as distinct, shaped
-- masonry, stepping from a darker buttress-tan up to a lighter cream body) while pinning hue and
-- saturation so no course of the wall goes anywhere near grey. Only Cobblestone-material parts are
-- touched: the roof caps (Slate) and gold finials (Metal) already carry their own saturated accent
-- colour, per the named gap's own note that they should be "kept, like the red tower caps already
-- there", and are left alone.
local CASTLE_STONE_HUE = 34 / 360 -- warm ochre/sandstone, matching WorldTerrain's Sandstone hue (round-15)
local CASTLE_STONE_SAT = 0.74 -- matched to the surrounding Rock/Sandstone saturation, not the washed 0.42
local CASTLE_STONE_V_LO, CASTLE_STONE_V_HI = 0.65, 0.98

local function recolorCastle()
	local lemonadeMap = workspace:FindFirstChild("LemonadeMap")
	local hub = lemonadeMap and lemonadeMap:FindFirstChild("Hub")
	if not hub then
		return
	end
	for _, model in ipairs(hub:GetChildren()) do
		if model:GetAttribute("CastleWall") or model:GetAttribute("CastleTower") then
			for _, inst in ipairs(model:GetDescendants()) do
				if inst:IsA("BasePart") and inst.Material == Enum.Material.Cobblestone then
					local _, _, v = inst.Color:ToHSV()
					local vv = CASTLE_STONE_V_LO + (CASTLE_STONE_V_HI - CASTLE_STONE_V_LO) * v
					inst.Color = Color3.fromHSV(CASTLE_STONE_HUE, CASTLE_STONE_SAT, vv)
				end
			end
		end
	end
end
recolorCastle()

-- ── Zone gate stonework recolour (round-16 fix, named gap) ───────────────────
-- tools/map_forge.py's gate() bakes every zone gate's archway pillars (GateIronLowlands and its
-- sealed siblings GateFrostbound/GateCaldera/GateAscension) in a near-zero-saturation grey
-- Cobblestone family (STONE/STONE_DARK) -- unrelated to, and never touched by, the castle-wall
-- recolour above (that one only walks parts tagged CastleWall/CastleTower; the gate models carry
-- neither tag). Framed against the vivid saturated orange/gold canyon either side of it, that plain
-- grey stonework is exactly the "pulls the frame toward realism" gap named this round. Same trick as
-- recolorCastle/recolorHorizon above: every Cobblestone-material part inside a gate model (found by
-- its own baked Region attribute, which every gate() carries) is re-hued at runtime into the same
-- warm sandstone/gold family as WorldTerrain's own Sandstone, keeping each part's own baked
-- brightness so the pillar shafts and their caps still read as distinct, stepped masonry rather than
-- one flat block. The Ascension Gate (CelestialSummit) is built from CELESTIAL marble, not
-- Cobblestone, so it is untouched by this material filter already; excluded by name too, for clarity.
local GATE_STONE_HUE = 35 / 360 -- warm sandstone/gold, matching WorldTerrain's Sandstone hue
local GATE_STONE_SAT = 0.72 -- matched to the surrounding Rock/Sandstone/CastleWall saturation family
local GATE_STONE_V_LO, GATE_STONE_V_HI = 0.62, 0.96

local function recolorGates()
	local lemonadeMap = workspace:FindFirstChild("LemonadeMap")
	local hub = lemonadeMap and lemonadeMap:FindFirstChild("Hub")
	if not hub then
		return
	end
	for _, gateModel in ipairs(hub:GetChildren()) do
		local region = gateModel:GetAttribute("Region")
		if region and region ~= "" and region ~= "CelestialSummit" then
			for _, inst in ipairs(gateModel:GetDescendants()) do
				if inst:IsA("BasePart") and inst.Material == Enum.Material.Cobblestone then
					local _, _, v = inst.Color:ToHSV()
					local vv = GATE_STONE_V_LO + (GATE_STONE_V_HI - GATE_STONE_V_LO) * v
					inst.Color = Color3.fromHSV(GATE_STONE_HUE, GATE_STONE_SAT, vv)
				end
			end
		end
	end
end
recolorGates()

Lighting.GeographicLatitude = LATITUDE
-- Hard directional cast shadows read as realistic/PBR lighting, not storybook-cartoon (the doc's
-- "no realistic hard cast shadow" rule): no dynamic shadow-casting, so canyon walls, awnings and
-- crags are shaded only by the soft, bright, still-saturated ambient/outdoor fill below -- flat,
-- matte colour blocks with a single soft highlight instead of a directional sun-and-shadow split.
Lighting.GlobalShadows = false
Lighting.ShadowSoftness = 1
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
