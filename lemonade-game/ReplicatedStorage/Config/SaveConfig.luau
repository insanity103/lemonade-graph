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
	-- AutoSellLowerSwords was here. Auto-sell is gone (a KEEP-or-SELL prompt at pickup replaced
	-- it, SwordDropSystem), so the game no longer reads or writes the attribute. An old profile
	-- that still carries the key loads and saves exactly as before -- PlayerDataService iterates
	-- THIS table, so an extra key in a saved record is carried along untouched and nothing is
	-- dropped from anybody's data.
	-- ForgeLuckCharges was here (the removed Reforge anvil's boss-kill charges). Nothing reads or
	-- writes it now; an old profile's value is carried along untouched, as above.
	Tokens = 0,                -- spin tokens: every kill pays some (Config.TokenRules), the spin wheel spends them
	MultiSpin = 0,             -- spins one multi-spin press buys at the town wheel; 0 = not unlocked yet (bought with gold)
	PrefixSlots = 1,           -- prefix slots every new sword rolls (WeaponModifiers.SlotUnlocks; 1..3)
	LemonadeFound = 0,         -- Lemonade chase prefixes this player has rolled; 0 = shown as "??" on odds displays
	ChasesFound = '',          -- comma-separated chase prefixes this player has rolled (WeaponModifiers.Chases); the rest show as "??"
	SwordsFound = '',          -- comma-separated spin-wheel chase swords this player has pulled (Config.SpinPools); the rest show as "??"
	BonusSpinLevel = 0,        -- Lucky Spins tiers owned (Config.UpgradeConfig; 0..6): odds a paid spin pays a free bonus sword
	CompletedQuests = '',      -- comma-separated quest IDs (e.g., 'q1_first_blood,q2_prove_yourself')
	ActiveQuestId = '',        -- current quest ID or '' if none
	QuestProgress = 0,         -- progress toward current objective
	DiscoveredWaypoints = '',  -- comma-separated map waypoint IDs (map project; empty on the baseplate)
}

-- [TUNING] The FREE shelf: boss swords the Vaultkeeper holds for a brand-new profile. Slots
-- beyond this are bought with gold (Config.VaultConfig owns the ladder and the cap) or granted by
-- the wealth ladder (Config.WealthLadder), and the count of each is persisted per player
-- (`vaultSlots` / `wealthRung` in PlayerDataService). The number is unchanged, so no existing
-- profile loses a shelf.
SaveConfig.VAULT_CAPACITY = 12

-- attributes copied verbatim off each saved boss / merchant sword Tool
SaveConfig.SWORD_ATTRS = {
	"DamageMult", "BonusDamagePct", "CritChance", "RangeBonus", "KnockbackBonus",
	"ExtraSlot", "Prefixes", "BossTier", "Rarity", "BaseWeaponName", "WeaponAppearanceMaterial",
	"PoolBase", -- the pool's listed base at the sword's rarity (DamageMult is the +-5% roll of it)
	"PoolKey",  -- the exact pool it came from: a boss archetype, or a zone (lesser swords).
	            -- Added with the lesser pools; a save without it still resolves by BossTier.
	"Lesser",   -- true on a lesser (normal-enemy) sword; absent on a boss sword and on old saves
	"Variant",  -- the mutation name, if it rolled one (WeaponModifiers.Variants)
	"Starter",  -- true on the profile's starter sword (never sold, never shattered)
	"StoredPrefixes", -- every prefix a pre-rework sword owns when more than its owner's slots are
	                  -- active (BossSwordFactory.applySlots). "ExtraSlot" above is the removed
	                  -- Blessed flag: still read from old saves, never written true again.
}

return SaveConfig
