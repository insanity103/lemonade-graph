-- ReplicatedStorage/Config/QuestConfig.luau
-- Quest system configuration — progressive quest chain with placeholder NPC
-- Framework only: NPC design, dialogue, and art are not included.
-- See: DESIGN_RULES.md rule #4 (no forced tutorials), sword-rpg-onboarding-FTUE.md

local GoldCurve = require(script.Parent:WaitForChild("GoldCurve"))

local QuestConfig = {}

-- ── QUEST GOLD ──────────────────────────────────────────────────────────────────────────────
-- The chain used to pay seven fixed sums -- 100, 300, 250, 600, 1,000, 1,500, 2,000 -- adding to
-- 5,750 gold once, ever. Measured (ledger r00): 0.03% of a 12-hour career, and 43 minutes of the
-- OPENING zone. A reward the player cannot feel at the moment they earn it is not a reward, and
-- by the Void Rift the 2,000-gold capstone was worth about four kills.
--
-- A quest now pays a number of KILLS' WORTH OF GOLD AT THE LEVEL IT IS HANDED IN, priced by
-- GoldCurve -- the same curve the kill loop itself is paid on. Two things follow. A quest is
-- always worth a recognisable amount of play (roughly the stretch of farming it asked for, plus a
-- bonus), at every level. And a player who leaves a quest in their log until much later is paid
-- at the rate of where they are, not where the quest was written.
--
-- The `kills` figures are deliberately FLAT-ISH across the chain -- 20 rising to 60 -- which is
-- the secondary bar's shape: Blox Fruits pays 350 for a level-0 quest and 8,250 for a level-300
-- one, a x23 climb over a x300 level span, with boss quests worth 2-3x a normal one. The climb
-- comes from the level factor, not from the listed number.
--
-- Both the server (QuestSystem, which grants it) and the client (QuestGui, which prints it) call
-- this one function, so the number on the card is the number that will be paid.
function QuestConfig.GoldReward(reward, level: number?): number
	if typeof(reward) ~= "table" or reward.type ~= "GOLD" then
		return 0
	end
	local kills = tonumber(reward.kills)
	if kills then
		return math.max(10, math.floor(kills * GoldCurve.PerKill(level, "minion") / 10 + 0.5) * 10)
	end
	-- An older-shaped reward that only carries a flat `amount` still pays that amount.
	return math.max(0, math.floor(tonumber(reward.amount) or 0))
end

-- Quest giver placement (near spawn in the hub)
QuestConfig.GIVER_POSITION = Vector3.new(0, 0, 0) -- fallback only; the placed NPC's position is used at runtime
QuestConfig.GIVER_NAME = "Quest Master"
QuestConfig.GIVER_COLOR = Color3.fromRGB(200, 180, 60)
QuestConfig.INTERACT_RANGE = 12 -- [TUNING] studs to interact

-- Reward types the quest system can grant
QuestConfig.REWARD_TYPES = {
	LEVEL = "LEVEL",             -- grant 1+ free level
	GOLD = "GOLD",               -- grant gold amount
	XP = "XP",                   -- grant XP amount
	SKILL_POINTS = "SKILL_POINTS", -- grant skill points
}

-- Objective types supported by the quest tracker
QuestConfig.OBJECTIVE_TYPES = {
	KILL = "KILL",             -- defeat N enemies (any zone)
	KILL_ZONE = "KILL_ZONE",   -- defeat N enemies in a specific zone
	KILL_BOSS = "KILL_BOSS",   -- defeat a specific boss archetype
	OBTAIN = "OBTAIN",         -- obtain one specific named sword (check inventory). No quest uses it
	                           -- any more: it can dead-end on a weighted roll. Kept for old saves.
	OBTAIN_POOL = "OBTAIN_POOL", -- obtain ANY sword from one boss's pool (poolKey). Satisfied by a
	                           -- matching sword on the player OR by the profile's record of having
	                           -- been handed one (bossFirstDrops), so selling it does not undo it.
	REFORGE = "REFORGE",       -- legacy: the removed anvil. No quest uses it; kept so an old save's
	                           -- active-quest id never names an unknown type.
	LEVEL = "LEVEL",           -- reach a target level
}

-- ── THE CHAIN, AND WHY IT IS SHAPED LIKE THIS ─────────────────────────────────────────────────
-- Measured (first_minutes r00, 300 first sessions through the shipped modules): the old chain
-- sent a level-10 player at the Warden of the Pit as quest 3 (three deaths in 100% of runs, 2:16
-- without a reward) and then asked for ONE named sword as quest 4, "Obtain the Warlord Greatsword",
-- a 1.6%-per-kill roll that 72% of first sessions were still stuck on at 15:00. Three more quests
-- later in the chain asked for named swords the same way.
--
-- Rules the chain now keeps, all of them checked by simulation (sim_first_minutes.luau):
--   1. Nothing before minute ten can dead-end on a roll. Every objective in the first eight quests
--      is a count the player controls: kills or a level.
--   2. The prefix ladder is a quest, early. Quest 3 asks for level 5, the level that opens the
--      Sunny prefix rung (WeaponModifiers.LevelCeiling), so the first thing a new player learns
--      about swords is that levelling up is what makes stronger prefixes possible. (It used to be
--      a strike at the removed Reforge anvil; the id is kept so a completed profile stays done.)
--   3. Bosses come after the level that beats them. The Warden of the Pit (Lv10, 7,075 HP) is
--      asked for after "Reach level 15", where the simulated player kills him in one attempt.
--   4. "Claim the blade" quests ask for ANY sword of the boss's pool, and a boss's FIRST kill by
--      a profile always drops one (DropRules.FIRST_BOSS_KILL_DROPS), so each of them is settled by
--      the kill quest that precedes it. No named-sword lottery anywhere in the chain.
--   5. Quest 2's XP went from 500 to 150: 500 was 30% of the old level 1-10 band on its own.
QuestConfig.QUESTS = {
	{
		id = "q1_first_blood",
		name = "First Blood",
		description = "Defeat 3 enemies in the Iron Lowlands.",
		objective = { type = "KILL_ZONE", zone = "IronLowlands", count = 3 },
		reward = { type = "GOLD", kills = 20 },  -- 20 kills' worth at the level it is handed in
	},
	{
		id = "q2_prove_yourself",
		name = "Prove Yourself",
		description = "Defeat 8 enemies in the Iron Lowlands.",
		objective = { type = "KILL_ZONE", zone = "IronLowlands", count = 8 },
		reward = { type = "XP", amount = 150 },
	},
	{
		id = "q3_strike_the_anvil", -- id kept: a profile that already completed it stays completed
		name = "Sunny Side Up",
		description = "Reach level 5 to open Sunny sword prefixes.",
		objective = { type = "LEVEL", target = 5 },
		reward = { type = "GOLD", kills = 20 },
	},
	{
		id = "q5_growing_stronger", -- id kept: a profile that already completed it stays completed
		name = "Growing Stronger",
		description = "Reach level 10.",
		objective = { type = "LEVEL", target = 10 },
		reward = { type = "GOLD", kills = 25 },
	},
	{
		id = "q8_briarwood_ready", -- id kept
		name = "Seasoned Steel",
		description = "Reach level 15.",
		objective = { type = "LEVEL", target = 15 },
		reward = { type = "SKILL_POINTS", amount = 4 },
	},
	-- Briarwood bridge zone (Lv 9-14)
	{
		id = "q6_briarwood_thorns",
		name = "Thorn Clearing",
		description = "Defeat 4 enemies in the Briarwood.",
		objective = { type = "KILL_ZONE", zone = "Briarwood", count = 4 },
		reward = { type = "GOLD", kills = 25 },
	},
	{
		id = "q7_grove_keeper",
		name = "Grove Keeper",
		description = "Defeat the Rootbound Warden.",
		objective = { type = "KILL_BOSS", archetype = "RootWarden", count = 1 },
		reward = { type = "XP", amount = 1200 },
	},
	{
		id = "q3_boss_hunter", -- id kept
		name = "Boss Hunter",
		description = "Defeat the Warden of the Pit.",
		objective = { type = "KILL_BOSS", archetype = "Boss_Gorgon", count = 1 },
		reward = { type = "LEVEL", amount = 1 },
	},
	{
		id = "q4_claim_the_blade", -- id kept
		name = "Claim the Blade",
		description = "Claim any sword from the Warden of the Pit.",
		objective = { type = "OBTAIN_POOL", poolKey = "Boss_Gorgon" },
		reward = { type = "SKILL_POINTS", amount = 5 },
	},
	-- Frostbound Glacier (Lv 15-25)
	{
		id = "q9_frost_expedition",
		name = "Frost Expedition",
		description = "Defeat 5 enemies in the Frostbound Glacier.",
		objective = { type = "KILL_ZONE", zone = "FrostboundGlacier", count = 5 },
		reward = { type = "XP", amount = 1500 },
	},
	{
		id = "q10_glacial_challenge",
		name = "Glacial Challenge",
		description = "Defeat the Frost Revenant.",
		objective = { type = "KILL_BOSS", archetype = "Boss_FrostRevenant", count = 1 },
		reward = { type = "LEVEL", amount = 1 },
	},
	{
		id = "q11_frost_fang",
		name = "Frost's Fang",
		description = "Claim any sword from the Frost Revenant.",
		objective = { type = "OBTAIN_POOL", poolKey = "Boss_FrostRevenant" },
		reward = { type = "SKILL_POINTS", amount = 8 },
	},
	-- Sunken Marsh bridge zone (Lv 23-29)
	{
		id = "q12_marsh_expedition",
		name = "Marsh Expedition",
		description = "Defeat 6 enemies in the Sunken Marsh.",
		objective = { type = "KILL_ZONE", zone = "SunkenMarsh", count = 6 },
		reward = { type = "GOLD", kills = 35 },
	},
	{
		id = "q13_bell_toll",
		name = "Bell's Toll",
		description = "Defeat the Drowned Bellwarden.",
		objective = { type = "KILL_BOSS", archetype = "DrownedBellwarden", count = 1 },
		reward = { type = "XP", amount = 2500 },
	},
	{
		id = "q14_marsh_ready",
		name = "Forged in Fire",
		description = "Reach level 30.",
		objective = { type = "LEVEL", target = 30 },
		reward = { type = "SKILL_POINTS", amount = 6 },
	},
	-- Infernal Caldera (Lv 30-45)
	{
		id = "q15_infernal_trial",
		name = "Infernal Trial",
		description = "Defeat 10 enemies in the Infernal Caldera.",
		objective = { type = "KILL_ZONE", zone = "InfernalCaldera", count = 10 },
		reward = { type = "GOLD", kills = 40 },
	},
	{
		id = "q16_colossus_slayer",
		name = "Colossus Slayer",
		description = "Defeat the Infernal Colossus.",
		objective = { type = "KILL_BOSS", archetype = "Boss_InfernalColossus", count = 1 },
		reward = { type = "LEVEL", amount = 2 },
	},
	{
		id = "q17_inferno_edge",
		name = "Inferno Edge",
		description = "Claim any sword from the Infernal Colossus.",
		objective = { type = "OBTAIN_POOL", poolKey = "Boss_InfernalColossus" },
		reward = { type = "SKILL_POINTS", amount = 10 },
	},
	-- Stormwatch bridge zone (Lv 40-48)
	{
		id = "q18_stormwatch_assault",
		name = "Storm Assault",
		description = "Defeat 8 enemies in Stormwatch.",
		objective = { type = "KILL_ZONE", zone = "Stormwatch", count = 8 },
		reward = { type = "GOLD", kills = 45 },
	},
	{
		id = "q19_tempest_challenge",
		name = "Tempest Challenge",
		description = "Defeat the Tempest Warden.",
		objective = { type = "KILL_BOSS", archetype = "TempestWarden", count = 1 },
		reward = { type = "XP", amount = 4000 },
	},
	{
		id = "q20_stormwatch_ready",
		name = "Eye of the Storm",
		description = "Reach level 50.",
		objective = { type = "LEVEL", target = 50 },
		reward = { type = "SKILL_POINTS", amount = 8 },
	},
	-- Void Rift (Lv 50-70)
	{
		id = "q21_void_walker",
		name = "Void Walker",
		description = "Defeat 15 enemies in the Void Rift.",
		objective = { type = "KILL_ZONE", zone = "VoidRift", count = 15 },
		reward = { type = "GOLD", kills = 60 },
	},
	{
		id = "q21b_void_archon",
		name = "Archon's Fall",
		description = "Defeat the Void Archon.",
		objective = { type = "KILL_BOSS", archetype = "Boss_VoidWraith", count = 1 },
		reward = { type = "LEVEL", amount = 1 },
	},
	{
		id = "q22_voidrend",
		name = "Voidrend",
		description = "Claim any sword from the Void Archon.",
		objective = { type = "OBTAIN_POOL", poolKey = "Boss_VoidWraith" },
		reward = { type = "LEVEL", amount = 2 },
	},
	-- Celestial Summit (Lv 75-100)
	{
		id = "q23_legend",
		name = "Legendary Warrior",
		description = "Defeat the Celestial Titan.",
		objective = { type = "KILL_BOSS", archetype = "Boss_CelestialTitan", count = 1 },
		reward = { type = "SKILL_POINTS", amount = 15 },
	},
	{
		id = "q24_astral_eclipse",
		name = "Astral Eclipse",
		description = "Claim any sword from the Celestial Titan.",
		objective = { type = "OBTAIN_POOL", poolKey = "Boss_CelestialTitan" },
		reward = { type = "LEVEL", amount = 3 },
	},
}

-- Build a lookup table for fast access
QuestConfig.QUEST_BY_ID = {}
for i, quest in ipairs(QuestConfig.QUESTS) do
	quest.index = i
	QuestConfig.QUEST_BY_ID[quest.id] = quest
end

function QuestConfig.getQuestById(id: string)
	return QuestConfig.QUEST_BY_ID[id]
end

function QuestConfig.getNextQuest(currentId: string): {}?
	local current = QuestConfig.QUEST_BY_ID[currentId]
	if not current then
		return QuestConfig.QUESTS[1]
	end
	return QuestConfig.QUESTS[current.index + 1] -- nil if chain complete
end

return QuestConfig
