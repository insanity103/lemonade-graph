--// DropRules  (the per-kill drop rule, in one place)
-- SwordDropSystem's Died handler calls Plan then Roll and nothing else; the Studio-only
-- measurement stage calls the same two functions, so what it measures IS what the game does.
-- Nothing here touches a player, a Tool or the DataStore: Roll is pure given its ctx, so it can be
-- run ten thousand times a second in a simulation and once per corpse in the game.
--
-- The rule, in full:
--   1. Which pool. A rig flagged Boss by EnemyCombat rolls its own boss pool (BossWeapons.Pools).
--      Any other enemy rolls its ZONE's lesser pool (BossWeapons.NormalPools[rig.Zone]) -- every
--      enemy in the game is on this table; none of them roll nothing.
--   2. How often. Bosses: BossWeapons.DropChance. Everything else: BossWeapons.NormalDrops by
--      archetype, x ELITE_CHANCE_MULT on an elite spawn. Rebirths raise both (flat per rebirth by
--      rarity class for bosses, +8% of itself per rebirth for normal enemies).
--   3. What falls. The rarity ladder is the rig's RANK, not its pool: trash / mid / elite / warden
--      for normal enemies (BossWeapons.NormalRarityOdds), the boss ladder for bosses. The rest of
--      the roll -- which sword of the pool, the +-5% stat jitter, the modifiers -- is
--      BossSwordFactory's, unchanged.
--   4. Pity, in two counters, both persisted with the player (PlayerDataService):
--      * dropPity     is a CREDIT, not a kill count: every kill that pays nothing adds that kill's
--        own drop chance to it. At PITY_CREDIT the next kill is forced to drop. One rule covers a
--        2% Quarry Cutthroat (a drop guaranteed inside 100 kills) and an 18% boss (inside 11),
--        because both are measured in the same unit: drops you were owed and did not get.
--      * dropRarePity counts DROPS since the last Rare or better. At RARE_PITY_DROPS the next
--        drop is floored at Rare. A run of Commons ends by itself.
--   5. The opening, for a brand-new profile (all three persisted with the player):
--      * THE FIRST KILL OF A PROFILE ALWAYS DROPS (FIRST_KILL_DROPS). Measured before this rule
--        (first_minutes r00): the first sword arrived at 6:15 median, p90 8:40, and only 32% of
--        first sessions had seen any sword by 5:00, because the opening zone's rigs roll at 2%
--        and the player leaves them after eleven kills. The rig's own pool and rank ladder are
--        rolled as normal (a Common most of the time); only the "did it drop" coin is skipped.
--      * THE OPENING RAMP: a profile's first OPENING_KILLS kills roll lesser pools at
--        OPENING_CHANCE_MULT x the rig's chance, so the opening zone pays a sword every couple of
--        minutes rather than once an hour. ctx.kills is the profile's lifetime kill count as the
--        drop system counts it (dropKills). The card prints the ramped chance: it is the real one.
--      * A BOSS'S FIRST KILL BY A PROFILE ALWAYS DROPS (FIRST_BOSS_KILL_DROPS): ctx.firstOfBoss is
--        true when the profile's bossFirstDrops record has no entry for this boss's pool. The
--        "claim a sword from <boss>" quests rest on this, so none of them is a lottery.
local DropRules = {}

local BossWeapons = require(script.Parent:WaitForChild("BossWeapons"))
local RebirthConfig = require(script.Parent:WaitForChild("RebirthConfig"))

-- [TUNING] drops' worth of expectation a player may be owed before the next kill is forced.
DropRules.PITY_CREDIT = 2.0
DropRules.PITY_CREDIT_PER_REBIRTH = 0.05 -- a rebirth's higher rates buy a slightly longer rope
DropRules.PITY_CREDIT_REBIRTH_MAX = 0.5
DropRules.RARE_PITY_DROPS = 12 -- [TUNING] drops without a Rare+ before the next one is floored

-- [TUNING] The opening (see rule 5 above).
DropRules.FIRST_KILL_DROPS = true       -- a profile's very first kill pays a sword, always
DropRules.OPENING_KILLS = 40            -- kills 1..this of a profile are on the ramp
DropRules.OPENING_CHANCE_MULT = 3.0     -- ...and roll lesser pools at this many times the chance
DropRules.FIRST_BOSS_KILL_DROPS = true  -- a profile's first kill of each boss pays a sword, always

-- The chance multiplier a lesser-pool roll carries at this many lifetime kills (before the kill).
function DropRules.OpeningMult(kills)
	local k = math.max(0, math.floor(tonumber(kills) or 0))
	if k < DropRules.OPENING_KILLS then
		return DropRules.OPENING_CHANCE_MULT
	end
	return 1
end

-- The rank of a rig: its spawn role first (a capstone or an elite spawn outranks its archetype),
-- then the archetype's own rank.
function DropRules.RankOf(archetypeKey, spawnRole, isBoss)
	if isBoss then return "boss" end
	if spawnRole == "elite" then return "elite" end
	local entry = BossWeapons.NormalDrops[archetypeKey]
	if spawnRole == "boss" then return "warden" end
	return entry and entry.rank or "trash"
end

-- What this rig rolls on, or nil if it is not an enemy this game knows how to pay for.
-- archetypeKey / zone / spawnRole / isBoss all come straight off the rig's attributes.
function DropRules.Plan(archetypeKey, zone, spawnRole, isBoss)
	if isBoss then
		local cfg = BossWeapons.DropChance[archetypeKey]
		if not cfg then return nil end
		return {
			poolKey = archetypeKey,
			lesser = false,
			rank = "boss",
			chance = cfg.chance,
			rebirthClass = cfg.rebirthClass,
			rarityOdds = BossWeapons.RarityOdds,
			source = BossWeapons.PoolName(archetypeKey),
		}
	end
	local entry = BossWeapons.NormalDrops[archetypeKey]
	if not entry then return nil end
	-- The rig's own Zone attribute first (EnemyCombat stamps it from the spawn marker); the
	-- archetype's home zone if a rig was spawned without one.
	local poolKey = (zone and BossWeapons.NormalPools[zone]) and zone or entry.zone
	if not (poolKey and BossWeapons.NormalPools[poolKey]) then return nil end
	local rank = DropRules.RankOf(archetypeKey, spawnRole, false)
	local chance = entry.chance
	if spawnRole == "elite" then
		chance *= BossWeapons.ELITE_CHANCE_MULT
	end
	return {
		poolKey = poolKey,
		lesser = true,
		rank = rank,
		chance = math.min(chance, 1),
		rebirthClass = nil,
		rarityOdds = BossWeapons.NormalRarityOdds[rank] or BossWeapons.NormalRarityOdds.trash,
		source = BossWeapons.PoolName(poolKey),
	}
end

-- The chance this kill actually rolls at, with the killer's rebirths.
function DropRules.EffectiveChance(plan, rebirths)
	rebirths = math.max(tonumber(rebirths) or 0, 0)
	if plan.rebirthClass then
		return RebirthConfig.GetEffectiveDropChance(plan.chance, plan.rebirthClass, rebirths)
	end
	return math.min(plan.chance * (1 + BossWeapons.NORMAL_REBIRTH_BONUS * rebirths), 1)
end

-- One kill. ctx = { rebirths, pity, rarePity, kills, firstOfBoss, rng }
--   kills        the profile's lifetime kills as the drop system counts them, BEFORE this one
--                (nil = not a fresh profile: no first-kill guarantee, no opening ramp)
--   firstOfBoss  true when this boss has never dropped for this profile (bosses only)
--   rng          optional: any function returning [0,1)
-- Returns a result table; the caller hands result.buildOpts to BossSwordFactory.build when
-- result.drop is true, and writes result.pity / result.rarePity back onto the player.
-- result.guaranteed is "first" / "boss" when one of the opening guarantees paid, else nil;
-- result.opening is true when the ramp multiplied the chance.
function DropRules.Roll(plan, ctx)
	ctx = ctx or {}
	local rng = ctx.rng or math.random
	local rebirths = math.max(tonumber(ctx.rebirths) or 0, 0)
	local pity = math.max(tonumber(ctx.pity) or 0, 0)
	local rarePity = math.max(tonumber(ctx.rarePity) or 0, 0)
	local kills = tonumber(ctx.kills)

	local chance = DropRules.EffectiveChance(plan, rebirths)
	local opening = false
	if kills and plan.lesser and DropRules.OpeningMult(kills) > 1 then
		chance = math.min(chance * DropRules.OpeningMult(kills), 1)
		opening = true
	end
	local credit = DropRules.PITY_CREDIT
		+ math.min(rebirths * DropRules.PITY_CREDIT_PER_REBIRTH, DropRules.PITY_CREDIT_REBIRTH_MAX)

	local guaranteed = nil
	if DropRules.FIRST_KILL_DROPS and kills == 0 then
		guaranteed = "first"
	elseif DropRules.FIRST_BOSS_KILL_DROPS and plan.rank == "boss" and ctx.firstOfBoss == true then
		guaranteed = "boss"
	end

	local natural = guaranteed ~= nil or rng() <= chance
	local forced = false
	if not natural and pity >= credit then
		forced = true
	end

	if not (natural or forced) then
		-- paid nothing: bank this kill's own expectation
		return { drop = false, chance = chance, pity = pity + chance, rarePity = rarePity,
			pityCredit = credit, forced = false, opening = opening }
	end

	local rarityFloor = nil
	if rarePity + 1 >= DropRules.RARE_PITY_DROPS then
		rarityFloor = "Rare"
	end
	return {
		drop = true,
		chance = chance,
		forced = forced,
		guaranteed = guaranteed,
		opening = opening,
		pity = 0,
		rarePity = rarePity, -- the caller settles this once it knows the rarity that fell
		pityCredit = credit,
		rarityFloor = rarityFloor,
		buildOpts = { rarityOdds = plan.rarityOdds, rarityFloor = rarityFloor },
	}
end

-- Settle the rare counter once the drop's rarity is known: a Rare or better clears it.
function DropRules.AfterDrop(rarePity, rarity)
	if rarity == "Rare" or rarity == "Epic" or rarity == "Legendary" then
		return 0
	end
	return math.max(tonumber(rarePity) or 0, 0) + 1
end

return DropRules
