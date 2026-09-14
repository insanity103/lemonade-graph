# Progression System

## XP Source Table

Define XP rewards per action. All sources feed through a single `grantXP` function:

```lua
local XP_SOURCES = {
    Kill       = 10,    -- [TUNING] per enemy killed
    Quest      = 50,    -- [TUNING] per quest completed
    Boss       = 200,   -- [TUNING] per boss defeated
    Assist     = 5,     -- [TUNING] per assist
    Explore    = 25,    -- [TUNING] per new area discovered
    DailyLogin = 30,    -- [TUNING] daily login bonus
}
```

## Level Calculation

Exponential curve: `level = floor(sqrt(xp / 100))` for a smooth progression, or a lookup table for discrete tuning:

### Formula (smooth curve)

```lua
local BASE_XP = 100    -- [TUNING] base XP divisor — higher = slower leveling

local function getLevelFromXP(xp)
    return math.floor(math.sqrt(xp / BASE_XP)) + 1
end

local function getXPForLevel(level)
    return (level - 1) ^ 2 * BASE_XP
end

local MAX_LEVEL = 50 -- [TUNING]
```

### Lookup Table (discrete levels, hand-tuned curve)

```lua
local LEVEL_XP = { -- cumulative XP threshold for each level
    [1]  = 0,     [2]  = 100,   [3]  = 250,   [4]  = 500,
    [5]  = 850,   [6]  = 1300,  [7]  = 1900,  [8]  = 2700,
    [9]  = 3700,  [10] = 5000,  -- extend as needed
}
local MAX_LEVEL = #LEVEL_XP

local function getLevelFromXP(xp)
    for level = MAX_LEVEL, 1, -1 do
        if xp >= LEVEL_XP[level] then return level end
    end
    return 1
end
```

## Unlock System

Map levels to features, items, or cosmetics:

```lua
local UNLOCKS = {
    [3]  = { Type = "Ability",    Id = "dash" },
    [5]  = { Type = "Weapon",     Id = "sword_fire" },
    [8]  = { Type = "Area",       Id = "dark_forest" },
    [10] = { Type = "Ability",    Id = "double_jump" },
    [15] = { Type = "Pet",        Id = "dragon_whelp" },
    [20] = { Type = "Title",      Id = "champion" },
}

local function checkUnlocks(playerData, oldLevel, newLevel)
    local newUnlocks = {}
    for level = oldLevel + 1, newLevel do
        if UNLOCKS[level] then
            table.insert(newUnlocks, UNLOCKS[level])
            if not playerData.Unlocks then playerData.Unlocks = {} end
            table.insert(playerData.Unlocks, UNLOCKS[level])
        end
    end
    return newUnlocks
end
```

Call `checkUnlocks` whenever XP changes and the level increases.

## Leaderboard (leaderstat + OrderedDataStore)

Display level as a leaderstat. Use `OrderedDataStore` for cross-server ranking:

```lua
local DataStoreService = game:GetService("DataStoreService")
local levelBoard = DataStoreService:GetOrderedDataStore("Leaderboard_Level")

-- Update leaderstat on level change
local function updateLeaderstat(player, level)
    local ls = player:FindFirstChild("leaderstats")
    if not ls then
        ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = player
    end
    local lv = ls:FindFirstChild("Level")
    if not lv then
        lv = Instance.new("IntValue"); lv.Name = "Level"; lv.Parent = ls
    end
    lv.Value = level
end

-- Push to OrderedDataStore for cross-server top-N
local function updateLevelLeaderboard(player, level)
    pcall(function()
        levelBoard:SetAsync(tostring(player.UserId), level)
    end)
end

-- Query top players
local function getTopPlayers(count)
    local pages = levelBoard:GetSortedAsync(false, count)
    local results = {}
    for rank, entry in ipairs(pages:GetCurrentPage()) do
        table.insert(results, {
            Rank = rank,
            UserId = tonumber(entry.key),
            Level = entry.value,
        })
    end
    return results
end
```

## Rebirth

Reset level/XP, multiply XP gain rate, award rebirth-specific currency:

```lua
local REBIRTH_LEVEL_REQ = 25    -- [TUNING] minimum level to rebirth
local REBIRTH_XP_BONUS  = 0.20 -- [TUNING] +20% XP gain per rebirth
local REBIRTH_TOKEN_AMOUNT = 1  -- [TUNING] rebirth tokens awarded

local function rebirth(player, playerData)
    local level = getLevelFromXP(playerData.XP)
    if level < REBIRTH_LEVEL_REQ then return false, "Level too low" end

    playerData.Rebirths = (playerData.Rebirths or 0) + 1
    playerData.XP = 0
    playerData.XPMultiplier = 1 + (playerData.Rebirths * REBIRTH_XP_BONUS)
    playerData.Unlocks = {}

    -- award rebirth-specific currency (separate from main XP/currency)
    playerData.RebirthTokens = (playerData.RebirthTokens or 0) + REBIRTH_TOKEN_AMOUNT

    return true
end

-- Apply multiplier when granting XP
local function grantXP(playerData, amount, source)
    local mult = playerData.XPMultiplier or 1
    local adjusted = math.floor(amount * mult)
    playerData.XP += adjusted
    return adjusted
end
```

## Battle Pass (Optional)

Tier unlock table, daily/weekly challenges, XP toward tiers:

```lua
local BATTLE_PASS_TIERS = {
    [1]  = { Type = "Cosmetic", Id = "banner_basic" },
    [5]  = { Type = "Currency", Amount = 500 },
    [10] = { Type = "Cosmetic", Id = "skin_shadow" },
    [15] = { Type = "Currency", Amount = 1000 },
    [20] = { Type = "Pet",      Id = "phoenix" },
    [25] = { Type = "Cosmetic", Id = "emote_legendary" },
}

local TIER_XP = 500 -- [TUNING] XP per battle pass tier

local function advanceBattlePass(playerData, xpGained)
    playerData.BattlePassXP = (playerData.BattlePassXP or 0) + xpGained
    local newTier = math.floor(playerData.BattlePassXP / TIER_XP)
    local oldTier = playerData.BattlePassTier or 0
    if newTier > oldTier then
        playerData.BattlePassTier = newTier
        -- grant rewards for tiers (oldTier+1) through newTier
        local rewards = {}
        for tier = oldTier + 1, newTier do
            if BATTLE_PASS_TIERS[tier] then
                table.insert(rewards, BATTLE_PASS_TIERS[tier])
            end
        end
        return rewards
    end
    return {}
end
```

## Achievement / Badge System

Trigger conditions checked against player data. Use `BadgeService:AwardBadge` for Roblox badges, or custom tracking:

```lua
local BadgeService = game:GetService("BadgeService")

local BADGE_IDS = {
    FirstKill  = 123456789,  -- [TUNING] replace with real badge IDs
    Level10    = 234567890,
    Rebirth1   = 345678901,
    BossSlayer = 456789012,
    AllUnlocks = 567890123,
}

local function awardBadge(player, badgeName)
    local badgeId = BADGE_IDS[badgeName]
    if not badgeId then return end
    pcall(function()
        if not BadgeService:UserHasBadgeAsync(player.UserId, badgeId) then
            BadgeService:AwardBadge(player.UserId, badgeId)
        end
    end)
end

local function checkAchievements(player, playerData)
    if playerData.Kills and playerData.Kills >= 1 then awardBadge(player, "FirstKill") end
    if getLevelFromXP(playerData.XP) >= 10 then awardBadge(player, "Level10") end
    if (playerData.Rebirths or 0) >= 1 then awardBadge(player, "Rebirth1") end
    if playerData.BossKills and playerData.BossKills >= 1 then awardBadge(player, "BossSlayer") end
end
```

Call `checkAchievements` after any significant data change (kill, level up, rebirth).

## Full Working Example: XP + Level + Unlock Module (< 80 lines)

```lua
-- ReplicatedStorage/Modules/ProgressionModule (ModuleScript)
local Progression = {}

local XP_SOURCES = { Kill = 10, Quest = 50, Boss = 200 } -- [TUNING]
local BASE_XP = 100 -- [TUNING]
local MAX_LEVEL = 50 -- [TUNING]
local REBIRTH_LVL = 10 -- [TUNING]

local UNLOCKS = {
    [3]  = { Type = "Ability", Id = "dash" },
    [5]  = { Type = "Weapon",  Id = "sword_fire" },
    [10] = { Type = "Title",   Id = "champion" },
}

function Progression.GetLevel(xp)
    local lvl = math.floor(math.sqrt(xp / BASE_XP)) + 1
    return math.min(lvl, MAX_LEVEL)
end

function Progression.GetXPForLevel(level)
    return (level - 1) ^ 2 * BASE_XP
end

function Progression.GrantXP(data, source)
    local base = XP_SOURCES[source]
    if not base then return 0, {} end
    local mult = data.XPMultiplier or 1
    local amount = math.floor(base * mult)

    local oldLevel = Progression.GetLevel(data.XP)
    data.XP += amount
    local newLevel = Progression.GetLevel(data.XP)

    local unlocks = {}
    if newLevel > oldLevel then
        for lvl = oldLevel + 1, newLevel do
            if UNLOCKS[lvl] then
                table.insert(unlocks, UNLOCKS[lvl])
                if not data.Unlocks then data.Unlocks = {} end
                table.insert(data.Unlocks, UNLOCKS[lvl])
            end
        end
    end
    return amount, unlocks
end

function Progression.Rebirth(data)
    if Progression.GetLevel(data.XP) < REBIRTH_LVL then return false end
    data.Rebirths = (data.Rebirths or 0) + 1
    data.XP = 0
    data.XPMultiplier = 1 + data.Rebirths * 0.2 -- [TUNING]
    data.Unlocks = {}
    return true
end

function Progression.UpdateLeaderstats(player, data)
    local ls = player:FindFirstChild("leaderstats")
    if not ls then ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = player end
    local lv = ls:FindFirstChild("Level")
    if not lv then lv = Instance.new("IntValue"); lv.Name = "Level"; lv.Parent = ls end
    lv.Value = Progression.GetLevel(data.XP)
end

return Progression
```
