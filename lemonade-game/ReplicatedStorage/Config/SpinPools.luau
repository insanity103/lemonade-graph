--// SpinPools  (what the town spin wheel can give: one sword pool per area, rotating as you push deeper)
-- Shared by the server (SpinService rolls it, and nothing else decides a spin) and the client (the
-- odds display reads the SAME Odds() call), so the odds a player is shown are the odds they roll.
--
-- THE SHAPE (a Pet-Sim-style egg ladder, built from our own sword roster, every number set by hand):
--   * One POOL per area of WorldLayout.ZONES, in content order, each with FOUR DEPTH STEPS. Step 1
--     is what you get the moment the area is reached; each deeper step is a better "egg". There is
--     no template: steps run 2-6 swords, top pulls from 24.5% (Stormwatch's flat four-way opener)
--     to 81.2% (the Summit's katana trailhead), and each area has its own weapon family (billhooks,
--     estoc, cutlass and oar, khopesh / flamberge / chopper, rapier / gladius / epee / tulwar,
--     kris and tanto, katana and nodachi; BossWeapons spinRegulars).
--   * EVERY STEP IS A NEW ROSTER, never a paid reshuffle: each deeper step brings in at least one
--     sword not seen earlier in that area.
--       - step 1 (TRAILHEAD): the area's new regulars plus the last area's ultra carried in. Five of
--         the eight also hide their OWN chase from the first spin (Snowglobe Sabre 0.6%, Rubber Duck
--         Rapier 0.8%, Toasted Marshmallow Brand 0.3%, Wishbone Comet 0.4%, Origami Crane Blade
--         0.2%); Briarwood and Stormwatch open as rests with only the hand-me-down to hope for.
--       - steps 2 and 3: the next regulars arrive, the carried-in ultra fades, and the area's
--         camp chase lands (Honeycomb Thorn, Blue Hour, Lilypad Lantern, First Spark, Kitestring
--         Rapier, Quiet Star, Little Dawn). Stormwatch's midway camp hides its own Bottled Lightning
--         (1.2%, a Legendary chase for the 370-token step) and the Void's has no chase.
--       - step 4 (BOSS DOWN) holds the area's ULTRA and is the boss's own pool, not a reroll of the
--         last camp: no sword carried from an earlier step tops 45% on any boss step, and in seven of
--         eight the TOP row is the new boss sword (Hollowbough 50, Frostfang 52.9, Frogsong 40,
--         Emberplate 38, Pinwheel 50, Singularity 51.9, Titanforged 54.9; only the first boss, the
--         Warden of the Pit, keeps Ironjaw 40 on top). Each has its own shape: the Glacier and the
--         Void are TWO-HEADED (two Epics at about 53/44 and 52/45, a 3% Nice, the ultra); the Summit
--         is three rows with no filler (two Epics and the GREAT Sunsqueeze Blade at 1 in 1,000);
--         the two warden steps of Briarwood and Stormwatch give their camp Legendary 12% (Honeycomb
--         Thorn, Kitestring Rapier); the Caldera is the widest (three boss swords, First Spark 4%,
--         GREAT Caramelt, ultra). What a boss step adds in average sword power is uneven, from
--         about +7% (Briarwood, the Void) to about +15% (the Revenant).
--       - the ULTRAs are spaced spikes: Pit Sovereign 1 in 201 (a new player's first real legend),
--         Grovebound 1 in 401, Aurora 1 in 668, Drowned Chime 1 in 834, then the SERVER-NEWS swords
--         past 1 in 1,000: Colossus Heart 1 in 1,251, Thunderglass 1 in 1,539, Archon's Verdict 1 in
--         2,501, Astral Eclipse 1 in 5,001. An ultra (and any "Chase" row) shows as "??" on the board
--         and in the reel until THIS player has pulled it (SwordsFound, saved); landing an ultra
--         shouts JACKPOT to the whole server (SERVER NEWS past 1 in 1,000), a GREAT gets its own shout.
--   * It ROTATES inside an area: a step's nice or rare sword becomes the next step's common
--     (Ranger's Longblade 70% -> 31% -> 5%, Heartwood 66.8% -> 33%, Collapse Claymore 3% -> 38% ->
--     45%, Glacier Falchion 42% -> 46.4%, Foreman's 2.5% -> 22.5% -> 48%).
--   * It ROTATES ACROSS THE BORDER: an area's ultra comes back as the NEXT area's step-1 nice pull
--     (tagged with where it came from), 5-40x easier than at its boss step, then fades: Pit
--     Sovereign 2.6%, Grovebound 3.4%, Aurora 1.5%, Drowned Chime 3.7%, Colossus Heart 2%,
--     Thunderglass 3%, Archon's Verdict 1.5%. The Astral Eclipse has nowhere to go.
--   * Rarity labels never run backwards at a border (Commons and Uncommons live only in the first
--     field), and the expected base damage of a spin rises on all 31 steps.
--   * THE PRICE climbs with it: `cost` is tokens per spin at each step, about x1.6-2 per area
--     (20 at the first trailhead, 1,250 at the Summit boss step), and kills deeper in the world pay
--     more tokens (Config.TokenRules.ZONE_SCALE), so a spin costs 5-13 ordinary kills where you are.
--   * Depth = the deepest camp you have beaten in that area (highest-level foe defeated there), and
--     step 4 = its boss or warden defeated. We use depth, not kill count, because "further into a
--     zone" is a place, not a grind. The server records it (SpinService), persists it per profile,
--     and it never goes down.
--   * Step thresholds come from the live spawn list (SpinService.Depth): mid = the midpoint of the
--     area's minion levels, deep = its highest minion/elite level, boss = its boss or warden.
--
-- THE CAPS (a new player can never pull far above their level):
--   * An area only spins once your level is at least its `gate`. Reaching an area early (a lucky
--     last hit on a Lv 18 imp at Lv 5) does not open its pool until you are Lv 17.
--   * Every entry has `minLevel`. Below it the entry is LOCKED: its weight leaves the roll and the
--     rest is renormalised, and the display shows it as "Lv N" with 0%. So a Lv 3 player standing
--     at Iron Lowlands step 4 rolls only what a Lv 3 may hold (see Odds()).
--
-- Weights are relative (a step sums to about 100; the ultra rides on top, so a 0.05 ultra in a
-- 100-point step is 0.05 / 100.05). Odds() divides by the real total, so p is always exact. [TUNING]
local SpinPools = {}

SpinPools.STEPS = 4

-- THE STATION (the town wheel that spends tokens on this pool; SpinSystem enforces every rule, the
-- client only prints them). [TUNING]
SpinPools.TOKEN_COST = 20    -- the cheapest spin (Iron Lowlands trailhead); each pool's `cost` sets its own
                             -- price per step, read through SpinPools.CostFor
SpinPools.SPIN_RANGE = 14    -- studs from the wheel a spin may be made from
SpinPools.COMBAT_LOCK = 5    -- seconds after any hit given or taken before the wheel will spin
SpinPools.SPIN_SECONDS = 2.4 -- one spin of the wheel; the next spin waits for it to stop
SpinPools.MULTI_DEFAULT = 3  -- spins a multi-spin press shows while it is still locked
SpinPools.STEP_NAMES = { "Trailhead", "Midway camp", "Deep camp", "Boss down" }
-- How each step is reached (the client prints this under the pool; SpinService enforces it).
SpinPools.STEP_HOW = {
	"reach the area",
	"beat a foe at the area's midway level",
	"beat a foe at the area's deepest camp",
	"defeat the area's boss or warden",
}
SpinPools.RARITY_ORDER = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }

-- e(sword, rarity, minLevel, {w1, w2, w3, w4}, poolKey?, from?, ultra?, great?) -- poolKey defaults to the
-- area's own lesser pool; boss swords name their boss pool. `from` marks the one sword carried in
-- from the previous area (its ultra), shown as "from <area>". `ultra` marks the area's named
-- ultra-rare (hidden as "??" until pulled, announced to the server when it lands). `great` marks a
-- boss step's named GREAT pull (shown by name, tagged Nice, stamped GREAT, announced).
local function e(sword, rarity, minLevel, weights, poolKey, from, ultra, great)
	return { sword = sword, rarity = rarity, minLevel = minLevel, weights = weights, poolKey = poolKey,
		from = from, ultra = ultra == true or nil, great = great == true or nil }
end

SpinPools.Pools = {
	{
		zone = "IronLowlands", name = "Iron Lowlands", gate = 1, boss = "Boss_Gorgon",
		cost = { 20, 24, 28, 34 },
		-- Opens with the Foreman's Longsword to hunt (1 in 40), then the Slag Falchion, the Lodestone Edge at the deep camp, and the Warden of the Pit's step: Ironjaw 40 / Pit Shiv 38 with the Warlord Greatsword up to 15.4% and the Pit Sovereign at 1 in 201, the one ultra a new player can realistically land (about 1,700 kills).
		entries = {
			e("Quarry Shank", "Common", 1, { 38, 0, 0, 0 }),
			e("Toolhouse Cleaver", "Common", 1, { 29, 0, 0, 0 }),
			e("Bandit's Machete", "Common", 1, { 21.5, 0, 0, 0 }),
			e("Rivetsteel Blade", "Uncommon", 1, { 9, 71, 0, 0 }),
			e("Foreman's Longsword", "Uncommon", 1, { 2.5, 22.5, 48, 0 }),
			e("Pit Shiv", "Rare", 4, { 0, 5.25, 30, 38 }, "Boss_Gorgon"),
			e("Slag Falchion", "Epic", 3, { 0, 1.25, 0, 0 }, "Boss_Gorgon"),
			e("Ironjaw Saber", "Rare", 5, { 0, 0, 17.9, 40 }, "Boss_Gorgon"),
			e("Chainbreaker", "Epic", 5, { 0, 0, 3.5, 0 }, "Boss_Gorgon"),
			e("Lodestone Edge", "Legendary", 6, { 0, 0, 0.6, 1.6 }),
			e("Warlord Greatsword", "Epic", 6, { 0, 0, 0, 15.4 }, "Boss_Gorgon"),
			e("Duneglass Edge", "Epic", 8, { 0, 0, 0, 5 }, "Boss_Gorgon"),
			e("Pit Sovereign", "Legendary", 10, { 0, 0, 0, 0.5 }, "Boss_Gorgon", nil, true),
		},
	},
	{
		zone = "Briarwood", name = "Briarwood", gate = 8, warden = "RootWarden",
		cost = { 40, 46, 52, 60 },
		-- Billhook country: the trailhead is a rest (two hooked blades and the Pit Sovereign walking in at 2.6%, no chase of its own). The grove's Honeycomb Thorn arrives at the midway camp (0.9% -> 2.2%), and the Root Warden's step is ITS pool, not more Heartwood: the new Hollowbough Claymore on top at 50%, Heartwood down to 33%, the Honeycomb Thorn up to 12%, and the Grovebound Bloom at 1 in 401.
		entries = {
			e("Briar Billhook", "Rare", 8, { 55, 6, 0, 0 }),
			e("Hedgehog Hooksword", "Rare", 8, { 42.4, 22, 0, 0 }),
			e("Pit Sovereign", "Legendary", 10, { 2.6, 1.1, 0, 0 }, "Boss_Gorgon", "Iron Lowlands"),
			e("Ranger's Longblade", "Rare", 10, { 0, 70, 31, 5 }),
			e("Honeycomb Thorn", "Legendary", 11, { 0, 0.9, 2.2, 12 }),
			e("Heartwood Broadsword", "Epic", 11, { 0, 0, 66.8, 33 }),
			e("Hollowbough Claymore", "Epic", 12, { 0, 0, 0, 50 }),
			e("Grovebound Bloom", "Legendary", 12, { 0, 0, 0, 0.25 }, nil, nil, true),
		},
	},
	{
		zone = "FrostboundGlacier", name = "Frostbound Glacier", gate = 17, boss = "Boss_FrostRevenant",
		cost = { 70, 80, 90, 105 },
		-- A twin opener (Icicle Estoc / Glacierrun Longsword at 48% each) with the glacier's own Snowglobe Sabre to hunt from the first spin (0.6%), the Blue Hour Shard at the camps, then a TWO-HEADED boss step: the new Frostfang Cleaver 52.9 over the Snowdrift Saber 44, the Blue Hour at 3.1%, and the Aurora Greatblade at 1 in 668.
		entries = {
			e("Icicle Estoc", "Rare", 17, { 48, 0, 0, 0 }),
			e("Glacierrun Longsword", "Rare", 19, { 48, 0, 0, 0 }),
			e("Grovebound Bloom", "Legendary", 12, { 3.4, 1.2, 0, 0 }, "Briarwood", "Briarwood"),
			e("Snowglobe Sabre", "Legendary", 19, { 0.6, 0, 0, 0 }),
			e("Rimeguard Shortsword", "Rare", 20, { 0, 40, 20, 0 }, "Boss_FrostRevenant"),
			e("Rimecoat Broadsword", "Rare", 18, { 0, 16, 0, 0 }),
			e("Blue Hour Shard", "Legendary", 21, { 0, 0.8, 1.6, 3.1 }),
			e("Glacier Falchion", "Rare", 21, { 0, 42, 46.4, 0 }, "Boss_FrostRevenant"),
			e("Snowdrift Saber", "Epic", 22, { 0, 0, 32, 44 }, "Boss_FrostRevenant"),
			e("Frostfang Cleaver", "Epic", 23, { 0, 0, 0, 52.9 }, "Boss_FrostRevenant"),
			e("Aurora Greatblade", "Legendary", 25, { 0, 0, 0, 0.15 }, "Boss_FrostRevenant", nil, true),
		},
	},
	{
		zone = "SunkenMarsh", name = "Sunken Marsh", gate = 23, warden = "DrownedBellwarden",
		cost = { 120, 135, 150, 170 },
		-- Cutlass and oar at the trailhead, the Aurora back at 1.5%, and a Rubber Duck Rapier bobbing at 0.8%; the Lilypad Lantern glows brighter each step (0.9% -> 1.6% -> 4.8%). The Bellwarden's step leads with its new Frogsong Greatsword (40%) over Bellringer 30 / Marshlight 25.2, with the Drowned Chime at 1 in 834.
		entries = {
			e("Ferryman's Cutlass", "Rare", 23, { 62, 0, 0, 0 }),
			e("Oarblade", "Rare", 23, { 35.7, 40.2, 0, 0 }),
			e("Aurora Greatblade", "Legendary", 25, { 1.5, 0.9, 0.4, 0 }, "Boss_FrostRevenant", "Frostbound Glacier"),
			e("Rubber Duck Rapier", "Legendary", 24, { 0.8, 0, 0, 0 }),
			e("Marshlight Longsword", "Rare", 25, { 0, 58, 52.5, 25.2 }),
			e("Lilypad Lantern", "Legendary", 26, { 0, 0.9, 1.6, 4.8 }),
			e("Bellringer Broadsword", "Epic", 26, { 0, 0, 45.5, 30 }),
			e("Frogsong Greatsword", "Epic", 27, { 0, 0, 0, 40 }),
			e("Drowned Chime", "Legendary", 27, { 0, 0, 0, 0.12 }, nil, nil, true),
		},
	},
	{
		zone = "InfernalCaldera", name = "Infernal Caldera", gate = 33, boss = "Boss_InfernalColossus",
		cost = { 200, 225, 250, 290 },
		-- Khopesh, flamberge and chopper, the Drowned Chime at 3.7%, and a Toasted Marshmallow Brand at 0.3%; First Spark at the camps; then the widest boss step: the new Emberplate Claymore on top (38%), Inferno Edge 33, Basalt 24.4, the GREAT Caramelt Claymore (1 in 168) and the Colossus Heart, 1 in 1,251, the first server-news sword.
		entries = {
			e("Kilnhook Khopesh", "Rare", 33, { 55, 0, 0, 0 }),
			e("Cinderwave Flamberge", "Rare", 33, { 22, 0, 0, 0 }),
			e("Anvilback Chopper", "Rare", 34, { 19, 48, 0, 0 }),
			e("Drowned Chime", "Legendary", 27, { 3.7, 1.6, 0, 0 }, "SunkenMarsh", "Sunken Marsh"),
			e("Toasted Marshmallow Brand", "Legendary", 35, { 0.3, 0, 0, 0 }),
			e("Furnace Longsword", "Rare", 36, { 0, 31.9, 14.5, 0 }),
			e("Caldera Broadsword", "Rare", 37, { 0, 17, 0, 0 }),
			e("First Spark", "Legendary", 38, { 0, 1.5, 2, 4 }),
			e("Ashen Saber", "Rare", 39, { 0, 0, 18, 0 }, "Boss_InfernalColossus"),
			e("Inferno Edge", "Rare", 41, { 0, 0, 65.5, 33 }, "Boss_InfernalColossus"),
			e("Emberplate Claymore", "Epic", 41, { 0, 0, 0, 38 }, "Boss_InfernalColossus"),
			e("Basalt Claymore", "Epic", 43, { 0, 0, 0, 24.4 }, "Boss_InfernalColossus"),
			e("Caramelt Claymore", "Legendary", 44, { 0, 0, 0, 0.6 }, nil, nil, nil, true),
			e("Colossus Heart", "Legendary", 45, { 0, 0, 0, 0.08 }, "Boss_InfernalColossus", nil, true),
		},
	},
	{
		zone = "Stormwatch", name = "Stormwatch", gate = 40, warden = "TempestWarden",
		cost = { 330, 370, 410, 470 },
		-- A flat four-way opener of weathered blades (24.5% each) with the Colossus Heart at 2%; the midway camp hides a Bottled Lightning (1.2%); the Kitestring Rapier arrives at the deep camp; the Tempest Warden's step is ITS pool: the new Pinwheel Claymore on top at 50%, Observatory down to 30%, the Kitestring up to 12%, the GREAT Double Rainbow (1 in 223) and the Thunderglass Pane at 1 in 1,539.
		entries = {
			e("Barometer Rapier", "Rare", 40, { 24.5, 0, 0, 0 }),
			e("Gustcutter Gladius", "Rare", 40, { 24.5, 0, 0, 0 }),
			e("Weathercock Epee", "Rare", 40, { 24.5, 0, 0, 0 }),
			e("Stormbell Tulwar", "Rare", 41, { 24.5, 36, 0, 0 }),
			e("Colossus Heart", "Legendary", 45, { 2, 0, 0, 0 }, "Boss_InfernalColossus", "Infernal Caldera"),
			e("Rodsteel Longsword", "Rare", 43, { 0, 62.8, 45, 7.55 }),
			e("Bottled Lightning", "Legendary", 44, { 0, 1.2, 0, 0 }),
			e("Kitestring Rapier", "Legendary", 44, { 0, 0, 1.5, 12 }),
			e("Observatory Broadsword", "Epic", 44, { 0, 0, 53.5, 30 }),
			e("Pinwheel Claymore", "Epic", 45, { 0, 0, 0, 50 }),
			e("Double Rainbow", "Legendary", 46, { 0, 0, 0, 0.45 }, nil, nil, nil, true),
			e("Thunderglass Pane", "Legendary", 46, { 0, 0, 0, 0.065 }, nil, nil, true),
		},
	},
	{
		zone = "VoidRift", name = "Void Rift", gate = 54, boss = "Boss_VoidWraith",
		cost = { 540, 600, 670, 760 },
		-- A kris-heavy opener with the Thunderglass back at 3% and the Wishbone Comet to hunt (0.4%), a chase-free midway camp, Quiet Star at the deep camp, then a TWO-HEADED boss step: the new Singularity Greatsword 51.9 over the Collapse Claymore 45, Quiet Star 3.1%, and the Archon's Verdict at 1 in 2,501.
		entries = {
			e("Hushfang Kris", "Rare", 54, { 71, 0, 0, 0 }),
			e("Gloam Tanto", "Rare", 55, { 25.6, 35, 0, 0 }),
			e("Thunderglass Pane", "Legendary", 46, { 3, 1.2, 0, 0 }, "Stormwatch", "Stormwatch"),
			e("Wishbone Comet", "Legendary", 56, { 0.4, 0, 0, 0 }),
			e("Nullbrand Longsword", "Rare", 58, { 0, 60.8, 0, 0 }),
			e("Eventide Claymore", "Rare", 62, { 0, 0, 19.2, 0 }, "Boss_VoidWraith"),
			e("Collapse Claymore", "Epic", 61, { 0, 3, 38, 45 }, "Boss_VoidWraith"),
			e("Quiet Star", "Legendary", 62, { 0, 0, 0.8, 3.1 }),
			e("Riftwalker Broadsword", "Rare", 60, { 0, 0, 42, 0 }),
			e("Singularity Greatsword", "Epic", 68, { 0, 0, 0, 51.9 }, "Boss_VoidWraith"),
			e("Archon's Verdict", "Legendary", 70, { 0, 0, 0, 0.04 }, "Boss_VoidWraith", nil, true),
		},
	},
	{
		zone = "CelestialSummit", name = "Celestial Summit", gate = 79, boss = "Boss_CelestialTitan",
		cost = { 880, 980, 1100, 1250 },
		-- Almost all Cloudstep Katana at the trailhead, the Archon's Verdict at 1.5%, and the Origami Crane Blade at 0.2%; Little Dawn at the camps; then a three-row boss step with no filler: the new Titanforged 54.9 over Aurelian 45, the GREAT Sunsqueeze Blade at 1 in 1,001, and the Astral Eclipse at 1 in 5,001, the rarest sword in the game.
		entries = {
			e("Cloudstep Katana", "Rare", 79, { 81.2, 0, 0, 0 }),
			e("Highwind Nodachi", "Rare", 80, { 17.1, 61.2, 0, 0 }),
			e("Archon's Verdict", "Legendary", 70, { 1.5, 0.8, 0, 0 }, "Boss_VoidWraith", "Void Rift"),
			e("Origami Crane Blade", "Legendary", 81, { 0.2, 0, 0, 0 }),
			e("Daybreak Longsword", "Rare", 84, { 0, 25.3, 38.5, 0 }),
			e("Summitward Broadsword", "Rare", 86, { 0, 12, 40, 0 }),
			e("Little Dawn", "Legendary", 90, { 0, 0.7, 1.5, 0 }),
			e("Aurelian Claymore", "Epic", 92, { 0, 0, 20, 45 }, "Boss_CelestialTitan"),
			e("Titanforged Greatsword", "Epic", 97, { 0, 0, 0, 54.9 }, "Boss_CelestialTitan"),
			e("Sunsqueeze Blade", "Legendary", 97, { 0, 0, 0, 0.1 }, nil, nil, nil, true),
			e("Astral Eclipse", "Legendary", 100, { 0, 0, 0, 0.02 }, "Boss_CelestialTitan", nil, true),
		},
	},
}

SpinPools.ByZone = {}
SpinPools.Order = {}
for index, pool in ipairs(SpinPools.Pools) do
	pool.index = index
	for _, entry in ipairs(pool.entries) do
		entry.poolKey = entry.poolKey or pool.zone
	end
	SpinPools.ByZone[pool.zone] = pool
	table.insert(SpinPools.Order, pool.zone)
end

function SpinPools.Get(zone: string?)
	return zone and SpinPools.ByZone[zone] or nil
end

function SpinPools.ClampStep(step: any): number
	return math.clamp(math.floor(tonumber(step) or 1), 1, SpinPools.STEPS)
end

-- THE ODDS, for one area at one depth step and one player level. The server rolls this list and
-- the client prints it; there is no second copy. Returns rows sorted by odds (highest first), plus
-- the step used:
--   { sword, rarity, poolKey, minLevel, weight, p, locked, tag, from }
-- p is the real probability of that row (0 for a locked row), and the p of every row sums to 1.
-- tag: "Chase" for the step's ultra, or for its rarest row that is not a carried-in sword when that
-- is CHASE_MAX% or less (a fading carry-in rarer than the area's own chase does not hide it); "Nice" for any other row of NICE_MAX% or less that is a HIGHER rarity than the
-- step's most common sword (a leftover lesser sword at 7% is not "nice", it is the old pool fading
-- out), or that was carried in, or a Legendary of NICE_LEGEND_MAX% or less under a non-Legendary top
-- row; nil otherwise. ultra: true on the area's named ultra-rare. from: the area a carried-in sword
-- came from, or nil. great: true on a boss step's named GREAT pull (tag "Nice").
-- If a player is deeper than their level can use (a Lv 1 who landed a hit on the deep camp), every
-- row of that step can be locked; the pool then steps back to the deepest step that has an unlocked
-- row, so a spin is never empty and never above level. Returns nil if the area is not open at this
-- level (level < gate).
SpinPools.NICE_MAX = 7    -- a row of this weight (%) or less, other than the chase, is tagged "Nice"
SpinPools.NICE_LEGEND_MAX = 12.5 -- a Legendary under an Epic/lower top row stays "Nice" up to this weight
                                 -- (the Briarwood and Stormwatch warden steps give their camp chase 12%)
SpinPools.CHASE_MAX = 2.5 -- the rarest row is the step's "Chase" only at this weight (%) or less
SpinPools.NEWS_P = 0.001  -- an ultra at this chance or rarer (1 in 1,000+) is announced as SERVER NEWS

local function oddsAt(pool, s, lv)
	local rows, total = {}, 0
	for _, entry in ipairs(pool.entries) do
		local w = entry.weights[s] or 0
		if w > 0 then
			local locked = lv < entry.minLevel
			table.insert(rows, { sword = entry.sword, rarity = entry.rarity, poolKey = entry.poolKey,
				minLevel = entry.minLevel, weight = w, locked = locked, p = 0, from = entry.from, ultra = entry.ultra,
				great = entry.great })
			if not locked then total += w end
		end
	end
	if total <= 0 then return nil end
	table.sort(rows, function(a, b)
		if a.weight ~= b.weight then return a.weight > b.weight end
		return (SpinPools.RARITY_ORDER[a.rarity] or 0) < (SpinPools.RARITY_ORDER[b.rarity] or 0)
	end)
	local chaseRow = nil -- the rarest row that is not a carry-in (rows are sorted rarest last)
	for i = #rows, 1, -1 do
		if not rows[i].from then chaseRow = rows[i] break end
	end
	for _, row in ipairs(rows) do
		if not row.locked then row.p = row.weight / total end
		if row.ultra or (row == chaseRow and #rows > 1 and row.weight <= SpinPools.CHASE_MAX) then
			row.tag = "Chase"
		elseif row.weight <= SpinPools.NICE_MAX and (row.from
			or (SpinPools.RARITY_ORDER[row.rarity] or 0) > (SpinPools.RARITY_ORDER[rows[1].rarity] or 0)) then
			row.tag = "Nice"
		elseif row.weight <= SpinPools.NICE_LEGEND_MAX and row.rarity == "Legendary"
			and (SpinPools.RARITY_ORDER[rows[1].rarity] or 0) < SpinPools.RARITY_ORDER.Legendary then
			row.tag = "Nice"
		end
	end
	return rows
end

function SpinPools.Odds(zone: string, step: number?, level: number?)
	local pool = SpinPools.ByZone[zone]
	if not pool then return nil end
	local lv = math.max(1, math.floor(tonumber(level) or 1))
	if lv < pool.gate then return nil end
	for s = SpinPools.ClampStep(step), 1, -1 do
		local rows = oddsAt(pool, s, lv)
		if rows then return rows, s end
	end
	return nil
end

-- The area a player's spin uses by default: the furthest area they have reached whose gate their
-- level meets. depthOf(zone) -> step (0 = not reached). Returns zone, step (or nil if none).
function SpinPools.DefaultZone(depthOf: (string) -> number, level: number?)
	local lv = math.max(1, math.floor(tonumber(level) or 1))
	for i = #SpinPools.Order, 1, -1 do
		local zone = SpinPools.Order[i]
		local step = depthOf(zone)
		if step >= 1 and lv >= SpinPools.ByZone[zone].gate then
			return zone, step
		end
	end
	return SpinPools.Order[1], math.max(1, depthOf(SpinPools.Order[1]))
end

-- One roll of an Odds() list with a uniform r in [0, 1). Pure, so the server and the measurement
-- share it. Returns the row.
function SpinPools.Pick(rows, r: number)
	local acc = 0
	local last
	for _, row in ipairs(rows) do
		if row.p > 0 then
			acc += row.p
			last = row
			if r < acc then return row end
		end
	end
	return last
end

-- Tokens one spin costs in `zone` at depth `step` (the step Odds() actually used). Unknown -> TOKEN_COST.
function SpinPools.CostFor(zone: string?, step: number?): number
	local pool = zone and SpinPools.ByZone[zone]
	local cost = pool and pool.cost and pool.cost[SpinPools.ClampStep(step)]
	return math.max(1, math.floor(tonumber(cost) or SpinPools.TOKEN_COST))
end

-- Has this player pulled this chase sword yet? found: a Player (reads the saved SwordsFound
-- attribute, a comma list of sword names) or that string itself. Unfound chases show as "??".
function SpinPools.SwordFound(found: any, sword: string): boolean
	local list = found
	if typeof(found) == "Instance" then list = found:GetAttribute("SwordsFound") end
	if typeof(list) ~= "string" or list == "" then return false end
	for name in string.gmatch(list, "[^,]+") do
		if name == sword then return true end
	end
	return false
end

-- Player attribute the server mirrors each area's step into (0 = not reached), for the display.
function SpinPools.DepthAttr(zone: string): string
	return "Depth_" .. zone
end

return SpinPools
