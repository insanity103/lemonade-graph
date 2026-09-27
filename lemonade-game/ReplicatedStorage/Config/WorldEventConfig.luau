--// WorldEventConfig  (timed zone events: Frost Moon, Sandstorm, Wild Hunt)
-- Wave 1 of the 2026-09-25 fun plan (Blox Fruits sea events, Terraria's Blood Moon, Grow a
-- Garden weather): every so often the whole server hears that something is happening in one
-- zone for a few minutes, and it is worth going there. Run by ServerScriptService.WorldEvents;
-- shown by StarterPlayerScripts.WorldEventGui (banner, timer, the zone's sky).
--
-- While an event runs, workspace carries:
--   WorldEvent      the event id ("FrostMoon"), absent when none
--   WorldEventZone  its zone
--   WorldEventMult  the token multiplier for kills in that zone
--   WorldEventEnds  server time (GetServerTimeNow) it ends
-- and its champions carry EventTokenMult (their kill pays that much more on top).
local WorldEventConfig = {}

WorldEventConfig.FIRST_DELAY = 8 * 60 -- [TUNING] seconds after a server starts before the first event
WorldEventConfig.INTERVAL = { 20 * 60, 30 * 60 } -- [TUNING] seconds between one event's end and the next's warning
WorldEventConfig.WARNING = 60 -- [TUNING] seconds of "coming soon" before it starts
WorldEventConfig.DURATION = 5 * 60 -- [TUNING] seconds an event runs

WorldEventConfig.Events = {
	{
		id = "FrostMoon", zone = "FrostboundGlacier", name = "Frost Moon",
		warn = "A Frost Moon is rising over the Frostbound Glacier...",
		start = "FROST MOON! Triple tokens in the Frostbound Glacier for 5 minutes!",
		tokenMult = 3,
		-- the zone's own enemies glow while it lasts (server: their torsos turn Neon)
		glow = { FrostImp = true, GlacialGargoyle = true },
		-- client sky while inside the zone: a deep blue night
		sky = { ambient = Color3.fromRGB(70, 90, 170), outdoor = Color3.fromRGB(60, 80, 160),
			atmosphere = Color3.fromRGB(40, 60, 140), brightness = -0.9, haze = 1.5 },
	},
	{
		id = "Sandstorm", zone = "IronLowlands", name = "Sandstorm",
		warn = "A Sandstorm is building over the Iron Lowlands...",
		start = "SANDSTORM! Double tokens in the Iron Lowlands, and Gilded enemies pay 5x!",
		tokenMult = 2,
		champions = { count = 3, title = "Gilded", color = Color3.fromRGB(255, 200, 40), healthMult = 1.5, tokenMult = 5 },
		sky = { ambient = Color3.fromRGB(200, 150, 90), outdoor = Color3.fromRGB(210, 160, 90),
			atmosphere = Color3.fromRGB(220, 170, 100), brightness = -0.4, haze = 3 },
	},
	{
		id = "WildHunt", zone = "Briarwood", name = "Wild Hunt",
		warn = "The Wild Hunt stirs in Briarwood...",
		start = "WILD HUNT! Double tokens in Briarwood. Slay the Hunt Leader for 15x!",
		tokenMult = 2,
		champions = { count = 1, title = "Hunt Leader", color = Color3.fromRGB(120, 255, 90), healthMult = 6, tokenMult = 15,
			announceKill = true },
		sky = { ambient = Color3.fromRGB(90, 150, 80), outdoor = Color3.fromRGB(80, 140, 70),
			atmosphere = Color3.fromRGB(70, 130, 60), brightness = -0.6, haze = 1.8 },
	},
}

WorldEventConfig.ById = {}
for _, e in ipairs(WorldEventConfig.Events) do WorldEventConfig.ById[e.id] = e end

return WorldEventConfig
