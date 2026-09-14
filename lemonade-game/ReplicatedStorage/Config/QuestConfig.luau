-- ReplicatedStorage/Config/QuestConfig.luau
-- Quest system configuration — progressive quest chain with placeholder NPC
-- Framework only: NPC design, dialogue, and art are not included.
-- See: DESIGN_RULES.md rule #4 (no forced tutorials), sword-rpg-onboarding-FTUE.md

local QuestConfig = {}

-- Quest giver placement (near spawn in the hub)
QuestConfig.GIVER_POSITION = Vector3.new(5, 3, -175) -- [TUNING] near hub spawn
QuestConfig.GIVER_NAME = "Quest Master"
QuestConfig.GIVER_COLOR = Color3.fromRGB(200, 180, 60)
QuestConfig.INTERACT_RANGE = 12 -- [TUNING] studs to interact

-- Reward types the quest system can grant
QuestConfig.REWARD_TYPES = {
	LEVEL = "LEVEL",         -- grant 1 free level
	GOLD = "GOLD",           -- grant gold amount
	XP = "XP",               -- grant XP amount
	SKILL_POINTS = "SKILL_POINTS", -- grant skill points
}

-- Quest definitions — progressive chain
-- Each quest has: id, name, description, objective, reward
-- The chain unlocks sequentially: complete quest N to unlock quest N+1
QuestConfig.QUESTS = {
	{
		id = "q1_first_blood",
		name = "First Blood",
		description = "Defeat 3 enemies in the Iron Lowlands.",
		objective = { type = "KILL", target = "any", count = 3 },
		reward = { type = "GOLD", amount = 100 },
	},
	{
		id = "q2_prove_yourself",
		name = "Prove Yourself",
		description = "Defeat 8 enemies in the Iron Lowlands.",
		objective = { type = "KILL", target = "any", count = 8 },
		reward = { type = "XP", amount = 500 },
	},
	{
		id = "q3_boss_hunter",
		name = "Boss Hunter",
		description = "Defeat the Iron Warlord boss.",
		objective = { type = "KILL", target = "boss", count = 1 },
		reward = { type = "LEVEL", amount = 1 },
	},
	{
		id = "q4_growing_stronger",
		name = "Growing Stronger",
		description = "Reach level 10.",
		objective = { type = "LEVEL", target = 10 },
		reward = { type = "SKILL_POINTS", amount = 5 },
	},
	{
		id = "q5_frost_expedition",
		name = "Frost Expedition",
		description = "Defeat 5 enemies in the Frost Glacier.",
		objective = { type = "KILL_ZONE", target = "FrostGlacier", count = 5 },
		reward = { type = "GOLD", amount = 500 },
	},
	{
		id = "q6_glacial_challenge",
		name = "Glacial Challenge",
		description = "Defeat the Frost Revenant boss.",
		objective = { type = "KILL", target = "boss", count = 1 },
		reward = { type = "LEVEL", amount = 1 },
	},
	{
		id = "q7_infernal_trial",
		name = "Infernal Trial",
		description = "Defeat 10 enemies in the Infernal Forge.",
		objective = { type = "KILL_ZONE", target = "InfernalForge", count = 10 },
		reward = { type = "SKILL_POINTS", amount = 8 },
	},
	{
		id = "q8_colossus_slayer",
		name = "Colossus Slayer",
		description = "Defeat the Infernal Colossus.",
		objective = { type = "KILL", target = "boss", count = 1 },
		reward = { type = "LEVEL", amount = 2 },
	},
	{
		id = "q9_void_walker",
		name = "Void Walker",
		description = "Reach level 50.",
		objective = { type = "LEVEL", target = 50 },
		reward = { type = "GOLD", amount = 2000 },
	},
	{
		id = "q10_legend",
		name = "Legendary Warrior",
		description = "Defeat the Celestial Titan.",
		objective = { type = "KILL", target = "boss", count = 1 },
		reward = { type = "SKILL_POINTS", amount = 15 },
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
