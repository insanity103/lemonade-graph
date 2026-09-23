-- ModuleScript | ReplicatedStorage.Config.XPCurve | XP required per level, in one place.
--
-- WHY THIS EXISTS. LevelingSystem and QuestSystem each carried their own copy of the curve
-- (floor(100 x 1.15^(L-1))). Measured (first_minutes r00, 300 first sessions through the shipped
-- modules): the whole level 1-10 band was over 99 seconds after the first kill, because the opening
-- zone's rigs pay 75-840 XP a kill and the band asked 1,675 in total. The first zone was finished
-- before a new player had read it.
--
-- THE SHAPE. The exponential body is untouched: from level OPENING_UNTIL + 1 on, Required(L) is
-- exactly what it was, so nothing past the opening zone is a second slower. Levels 2..OPENING_UNTIL
-- carry an OPENING HUMP on top, OPENING_K x (L-1) x (OPENING_UNTIL+1-L): zero at level 1 (so the
-- first level-up still lands on the second kill), zero again at OPENING_UNTIL + 1, largest in the
-- middle of the band. It stretches levels 1-10 to about five minutes of ordinary play in the Iron
-- Lowlands and leaves 11+ alone. Tuned by simulation (first_minutes r01, sim_first_minutes.luau).
--
-- Both the server (LevelingSystem, QuestSystem's XP rewards) and any reader that prints the curve
-- call this one function, so the bar and the level-up can never disagree.
local XPCurve = {}

XPCurve.BASE = 100 -- [TUNING] XP from level 1 to 2, before the hump (the hump is 0 there)
XPCurve.GROWTH = 0.15 -- [TUNING] +15% per level, compounding: the mid and late game's whole shape
XPCurve.OPENING_UNTIL = 10 -- [TUNING] the hump spans levels 2..this and is gone at this + 1
XPCurve.OPENING_K = 16 -- [TUNING] hump height; total extra over the band = K x sum((L-1)(11-L)) = 165 K = 2,640

function XPCurve.Body(level: number): number
	local lv = math.max(1, math.floor(tonumber(level) or 1))
	return math.floor(XPCurve.BASE * (1 + XPCurve.GROWTH) ^ (lv - 1))
end

function XPCurve.OpeningExtra(level: number): number
	local lv = math.max(1, math.floor(tonumber(level) or 1))
	if lv <= 1 or lv > XPCurve.OPENING_UNTIL then
		return 0
	end
	return XPCurve.OPENING_K * (lv - 1) * (XPCurve.OPENING_UNTIL + 1 - lv)
end

-- XP needed to go from `level` to `level + 1`.
function XPCurve.Required(level: number): number
	return XPCurve.Body(level) + XPCurve.OpeningExtra(level)
end

-- Total XP from level 1 to reach `level`.
function XPCurve.Cumulative(level: number): number
	local total = 0
	for lv = 1, math.max(1, math.floor(tonumber(level) or 1)) - 1 do
		total += XPCurve.Required(lv)
	end
	return total
end

return XPCurve
