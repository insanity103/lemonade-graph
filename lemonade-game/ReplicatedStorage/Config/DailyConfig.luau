--// DailyConfig  (the 7-day login streak: rewards and the day arithmetic)
-- Wave 1 of the 2026-09-25 fun plan: a reason to come back tomorrow. One claim per UTC day; a
-- missed day starts the week over; day 7 is the showcase (an Epic-or-better sword from the
-- player's own zone), shown on the calendar from day 1 so it is something to aim at.
--
-- Rewards are priced in the game's own units so they stay fair at every level:
--   killsGold  gold worth this many kills at the player's level (GoldCurve.PerKill)
--   spins      tokens worth this many spins at the player's zone wheel (SpinPools.CostFor)
--   sword      a sword from the player's zone pool, at this rarity or better
local DailyConfig = {}

DailyConfig.DAY_SECONDS = 86400

DailyConfig.Days = { -- [TUNING]
	{ killsGold = 30 },
	{ spins = 2 },
	{ killsGold = 60 },
	{ spins = 4 },
	{ killsGold = 100, spins = 2 },
	{ spins = 6 },
	{ sword = "Epic", spins = 5 },
}

function DailyConfig.DayNumber(unixTime: number): number
	return math.floor(unixTime / DailyConfig.DAY_SECONDS)
end

-- Where a player stands today. lastClaim: the UTC day number of their last claim (0 = never);
-- streakDay: the calendar day (1..7) they claimed then. Returns the calendar day they can claim
-- next and whether it is claimable today.
function DailyConfig.Next(lastClaim: number, streakDay: number, today: number): (number, boolean)
	lastClaim, streakDay = tonumber(lastClaim) or 0, tonumber(streakDay) or 0
	if lastClaim == today then
		return (streakDay % #DailyConfig.Days) + 1, false -- claimed today; this is tomorrow's
	elseif lastClaim == today - 1 and streakDay > 0 then
		return (streakDay % #DailyConfig.Days) + 1, true -- kept the streak: the next day
	end
	return 1, true -- first claim, or a missed day: the week starts over
end

return DailyConfig
