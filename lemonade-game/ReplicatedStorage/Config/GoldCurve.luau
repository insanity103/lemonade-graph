-- ModuleScript | ReplicatedStorage.Config.GoldCurve | The faucet's shape: what a kill pays.
--
-- WHY THIS EXISTS. Gold used to be a flat `5 x enemy level`. Because kills per hour collapse as
-- enemies grow (measured: ~400/h in the Iron Lowlands, ~34/h on the Celestial Summit), a flat
-- per-level payout made gold PER HOUR rise only x5.5 across the whole game and then FALL 26% into
-- the endgame zone. A sink cannot stay meaningful against an income that does not climb.
--
-- THE SHAPE we want is Dungeon Quest's: each new tier multiplies income while the sink stays
-- worth paying, so one stretch of the zone you are in buys a bounded amount of progress on gear
-- from that zone -- at EVERY tier, including the last one. Ours is a kill-based game, so the unit
-- is gold per hour rather than gold per run.
--
-- HOW. A kill pays `GOLD_BASE x level x BandMultiplier(level) x role`. The band multiplier is a
-- flat opening (levels 1-10, so the first zone is unchanged and the tutorial loop still reads)
-- and then a steady GROWTH_PER_LEVEL compounding. GROWTH_PER_LEVEL is chosen so that, once the
-- measured kills-per-hour collapse is divided back out, gold per hour steps up region by region
-- in the same band Dungeon Quest's dungeon ladder steps in.
--
-- Everything here is server-authoritative: LevelingSystem is the only writer of kill gold, and it
-- reads this module. The client never computes a payout, it only renders the number it is sent.
local GoldCurve = {}

-- [TUNING] Gold a level-1 enemy pays. Unchanged from the flat curve, so the opening minutes of
-- the game pay exactly what they used to.
GoldCurve.GOLD_BASE = 5

-- [TUNING] The payout stays flat-per-level through the opening zone; the curve starts climbing
-- once the player has left it, which is where kills per hour start to fall.
GoldCurve.FLAT_UNTIL_LEVEL = 10

-- [TUNING] Compounding per enemy level above FLAT_UNTIL_LEVEL. 1.038 -> x1.45 per 10 levels,
-- x18.3 at level 88, x28.7 at level 100. Fitted by simulation against the measured
-- kills-per-hour of each zone's own rotation: the step from one REGION to the next lands at
-- 2.3x-2.7x and the step between the two zones inside a region at 1.0x-1.4x, which is the shape
-- Dungeon Quest has between dungeons and between difficulties inside one dungeon.
GoldCurve.GROWTH_PER_LEVEL = 1.038

-- Guard rail: the exponent can never run away, whatever level an enemy is spawned at.
GoldCurve.MAX_GROWTH_LEVELS = 200

-- [TUNING] What a kill is worth by what it was. A zone's payday is its boss, the way a dungeon's
-- payday is its final room. "warden" is a named elite that gates a bridge zone but drops no sword.
GoldCurve.ROLE_MULT = {
	minion = 1.00,
	elite = 1.50,
	warden = 2.60,
	boss = 3.00,
}

-- [TUNING] DEATH, PRICED IN PROGRESS RATHER THAN IN SAVINGS.
--
-- What was wrong. The rule was "lose 5% of the purse, capped at 20 kills' worth at your level".
-- A percentage of the purse is not a price for dying, it is a tax on having saved. Measured over
-- 47 deaths in a 12-hour career (ledger r00, section 5): the player who spent everything at the
-- anvil as they earned it lost 5.3% of their lifetime earnings, while the player who saved -- the
-- same deaths, the same zones, the same hours -- lost 48.9%, and at 12 deaths an hour, 79.1%. The
-- cap that was supposed to stop exactly that fired ZERO times in 47 deaths, because it only binds
-- above a purse of about 5.7 million. Two players who played identically were charged an order of
-- magnitude apart for the same mistake, and the one charged more was the one who had touched
-- nothing.
--
-- What it is now. A death costs DEATH_LOSS_SECONDS of THE PLAYER'S OWN INCOME -- the gold they
-- have actually been earning, measured by the server over a rolling window, not a share of what
-- they are holding. So:
--   * A spender and a hoarder farming the same zone at the same rate pay the same, because they
--     earn the same. Saving is no longer punished and spending is no longer an immunity.
--   * It self-scales with the zone. Nobody has to keep a per-region table in step: a death in the
--     Iron Lowlands costs a minute of Iron Lowlands, a death on the Summit costs a minute of the
--     Summit.
--   * Dying MORE costs more, in proportion, which a flat share of savings never did.
--   * A player who has earned nothing since they arrived loses nothing. There is no gold at risk
--     that they did not put there.
-- DEATH_PURSE_CAP is the one place the purse still appears, and only as a floor-protection: the
-- player who just emptied their purse at the forge cannot be taken below three quarters of the
-- little they have left.
GoldCurve.DEATH_FREE_MAX_LEVEL = 8    -- at or below this level a death costs nothing at all
GoldCurve.DEATH_LOSS_SECONDS = 60     -- a death costs this many seconds of the player's own income
GoldCurve.DEATH_INCOME_WINDOW = 240   -- seconds of earning the income rate is measured over
GoldCurve.DEATH_MIN_SAMPLE = 45       -- never divide by a window shorter than this (no spikes)
GoldCurve.DEATH_PURSE_CAP = 0.25      -- and never more than this share of what is being carried

-- The multiplier a kill at this level carries on top of GOLD_BASE x level.
function GoldCurve.BandMultiplier(level: number?): number
	local lv = math.max(1, math.floor(tonumber(level) or 1))
	local over = math.clamp(lv - GoldCurve.FLAT_UNTIL_LEVEL, 0, GoldCurve.MAX_GROWTH_LEVELS)
	return GoldCurve.GROWTH_PER_LEVEL ^ over
end

-- Gold a single kill pays, before the rebirth gold multiplier.
-- role: "minion" (default) | "elite" | "warden" | "boss"
function GoldCurve.PerKill(level: number?, role: string?): number
	local lv = math.max(1, math.floor(tonumber(level) or 1))
	local roleMult = GoldCurve.ROLE_MULT[role or "minion"] or GoldCurve.ROLE_MULT.minion
	return math.floor(GoldCurve.GOLD_BASE * lv * GoldCurve.BandMultiplier(lv) * roleMult)
end

-- The role an enemy model counts as. EnemyCombat stamps `Boss` (a real boss with a sword pool)
-- and `SpawnRole` (WorldLayout's "boss" / "elite" / nil) on every rig it builds.
function GoldCurve.RoleOf(model: Instance?): string
	if typeof(model) ~= "Instance" then
		return "minion"
	end
	if model:GetAttribute("Boss") == true then
		return "boss"
	end
	local spawnRole = model:GetAttribute("SpawnRole")
	if spawnRole == "boss" then
		return "warden" -- a named warden: gates a bridge zone, drops no sword
	elseif spawnRole == "elite" then
		return "elite"
	end
	return "minion"
end

-- The gold a player is earning, per second, from what the server has watched them earn:
-- `earned` gold over `elapsed` seconds of play. The divisor never falls below DEATH_MIN_SAMPLE,
-- so a single boss payday seconds after spawning cannot read as a fortune per second.
function GoldCurve.IncomeRate(earned: number?, elapsed: number?): number
	local gold = math.max(0, tonumber(earned) or 0)
	local seconds = math.max(GoldCurve.DEATH_MIN_SAMPLE, math.min(GoldCurve.DEATH_INCOME_WINDOW,
		tonumber(elapsed) or 0))
	return gold / seconds
end

-- Gold destroyed by one death: DEATH_LOSS_SECONDS of the player's measured income, never more
-- than DEATH_PURSE_CAP of the purse, and nothing at all while they are still learning the loop.
-- `earned` / `elapsed` are the server's rolling income window (LevelingSystem keeps it). A caller
-- that has no income history yet passes nothing and the death is free, which is correct: a player
-- who has earned nothing this session has nothing at risk.
function GoldCurve.DeathLoss(gold: number?, level: number?, earned: number?, elapsed: number?): number
	local purse = math.max(0, math.floor(tonumber(gold) or 0))
	local lv = math.max(1, math.floor(tonumber(level) or 1))
	if lv <= GoldCurve.DEATH_FREE_MAX_LEVEL or purse <= 0 then
		return 0
	end
	local fromIncome = GoldCurve.IncomeRate(earned, elapsed) * GoldCurve.DEATH_LOSS_SECONDS
	local ceiling = purse * GoldCurve.DEATH_PURSE_CAP
	return math.max(0, math.floor(math.min(fromIncome, ceiling)))
end

return GoldCurve
