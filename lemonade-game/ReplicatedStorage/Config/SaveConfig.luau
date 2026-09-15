--// SaveConfig  (what PlayerDataService persists, and how)
local SaveConfig = {}

SaveConfig.DATASTORE_NAME = "PlayerData_v1"
SaveConfig.SCHEMA_VERSION = 1
SaveConfig.KEY_PREFIX = "Player_"

SaveConfig.AUTOSAVE_INTERVAL = 120   -- seconds between periodic saves while a player is in-game
SaveConfig.LOCK_STALE_AFTER = 1200   -- a session lock older than this (s) is treated as abandoned
SaveConfig.MAX_RETRIES = 4           -- DataStore call attempts before giving up

-- leaderstats IntValues to persist  (name -> default for a brand-new player)
SaveConfig.LEADERSTATS = {
	Level = 1,
	Experience = 0,
	Gold = 0,
	Rebirths = 0,
}

-- player attributes to persist  (name -> default)
SaveConfig.ATTRIBUTES = {
	SkillPoints = 0,
	WeaponLevel = 0,
	Strength = 0,
	Health = 0,
	Defense = 0,
	ExperienceGain = 0,
	AutoSellLowerSwords = false,
	CompletedQuests = '',      -- comma-separated quest IDs (e.g., 'q1_first_blood,q2_prove_yourself')
	ActiveQuestId = '',        -- current quest ID or '' if none
	QuestProgress = 0,         -- progress toward current objective
	DiscoveredWaypoints = '',  -- comma-separated map waypoint IDs (map project; empty on the baseplate)
}

-- attributes copied verbatim off each saved boss / merchant sword Tool
SaveConfig.SWORD_ATTRS = {
	"DamageMult", "BonusDamagePct", "CritChance", "RangeBonus", "KnockbackBonus",
	"ExtraSlot", "Prefixes", "BossTier", "Rarity", "BaseWeaponName", "WeaponAppearanceMaterial",
}

return SaveConfig
