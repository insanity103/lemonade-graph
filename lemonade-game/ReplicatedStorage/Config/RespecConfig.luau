-- ModuleScript | ReplicatedStorage.Config.RespecConfig | WHAT A RESET IS WORTH.
--
-- WHY THIS EXISTS. The Skill Trainer charged a flat 200 gold plus 100 per rebirth, whatever it
-- was handing back. The handler already counted the points it was refunding -- and then never put
-- that number in the price. Measured (r00, section 7):
--
--   Lv10   72 points back for 200 gold = 2.78 gold a point = 29.1 s of that band's income
--   Lv100 792 points back for 200 gold = 0.25 gold a point =  0.9 s of that band's income, 0.01 kills
--
-- Eleven times the refund for the same money, at an income x101 larger. The price ran backwards:
-- dearest for the beginner fixing a mistake, free for the level-100 player rebuilding their whole
-- character between boss pulls. Dungeon Quest's own listed skill-reset sink is priced "by points
-- in use"; ours was the one price in the game that was not priced by anything.
--
-- ── THE PRICE ────────────────────────────────────────────────────────────────────────────────
--
--   cost = GOLD_PER_POINT x points refunded x GoldCurve.BandMultiplier(level) x (1 + REBIRTH_STEP x rebirths)
--
-- Both scaling terms are already the game's own, not new curves:
--
--   * BandMultiplier is the same factor the gold faucet uses to climb (GoldCurve). Pricing the
--     reset on it means the respec keeps pace with the income of the band the player is standing
--     in, automatically, at every level, with nobody maintaining a second table.
--   * REBIRTH_STEP 0.5 matches RebirthConfig's +0.50 gold multiplier per rebirth exactly, so a
--     rebirthed player pays the same number of MINUTES OF PLAY as an un-rebirthed one.
--
-- Fitted so the reset costs roughly a minute of the band's income early and several minutes of it
-- late -- affordable for the beginner, a real decision for the endgame player. Measured through
-- the shipped modules (r01 dossier, section 5), against the measured income of each band:
--
--   Lv10  ( 72 pts)     290 gold   4.03 a point   0.71 min of that band's income, 0.30 forge strikes
--   Lv50  (392 pts)   6,970 gold  17.78 a point   2.74 min of that band's income, 0.60 forge strikes
--   Lv100 (792 pts)  90,900 gold 114.77 a point   5.81 min of that band's income, 1.06 forge strikes
--
-- The old flat 200 was 0.49 min of income at Lv10 and 0.01 min at Lv100. The new price runs
-- 0.71 -> 5.81 minutes: it now costs MORE play time at the top than at the bottom, which is the
-- whole point, and it is never more than six minutes anywhere.
--
-- x28.5 the gold per point from the bottom of the game to the top, in the same direction as income
-- instead of against it, and never more than a few minutes of play at any level.
local GoldCurve = require(script.Parent:WaitForChild("GoldCurve"))

local RespecConfig = {}

-- [TUNING] Gold per refunded skill point, before the level band and rebirth terms.
RespecConfig.GOLD_PER_POINT = 4

-- [TUNING] Each rebirth multiplies the price by this much, matching the rebirth gold multiplier
-- (RebirthConfig.GOLD_PER_REBIRTH) so the price stays constant in minutes of play.
RespecConfig.REBIRTH_STEP = 0.5

-- [TUNING] The floor. A player with almost nothing spent still pays something, so the trainer is
-- never a free button, and the number in the prompt is never zero.
RespecConfig.MIN_COST = 100

-- [TUNING] Seconds the quoted price stays good. The first press of the prompt QUOTES the price;
-- a second press inside this window is the player agreeing to it. That is what makes it a
-- decision rather than a button that silently empties a purse.
RespecConfig.CONFIRM_WINDOW = 10

-- [TUNING] The existing guards, unchanged and kept here beside the price so they are one edit.
RespecConfig.COOLDOWN = 2      -- seconds between prompt presses
RespecConfig.RANGE = 16        -- studs from the Skill Trainer

-- The attributes a reset hands back. Same list the trainer has always wiped.
RespecConfig.ATTRIBUTES = { "Strength", "Health", "Defense", "ExperienceGain" }

-- THE PRICE. points: how many skill points are coming back. level: the player's level.
-- rebirths: their rebirth count. Rounded to ten gold like every other price in the game.
function RespecConfig.Cost(points: number?, level: number?, rebirths: number?): number
	local spent = math.max(0, math.floor(tonumber(points) or 0))
	if spent <= 0 then
		return 0
	end
	local band = GoldCurve.BandMultiplier(level)
	local rebirthMult = 1 + RespecConfig.REBIRTH_STEP * math.max(0, math.floor(tonumber(rebirths) or 0))
	local raw = RespecConfig.GOLD_PER_POINT * spent * band * rebirthMult
	return math.max(RespecConfig.MIN_COST, math.floor(raw / 10 + 0.5) * 10)
end

-- The points a reset would refund, read off the player the way the trainer reads them.
function RespecConfig.PointsSpent(player: Instance?): number
	if typeof(player) ~= "Instance" then
		return 0
	end
	local spent = 0
	for _, attr in ipairs(RespecConfig.ATTRIBUTES) do
		spent += tonumber(player:GetAttribute(attr)) or 0
	end
	return spent
end

-- One line a player can hold, used in the prompt, the quote and the refusal.
function RespecConfig.PriceLine(points: number, cost: number): string
	local perPoint = points > 0 and cost / points or 0
	return string.format("%d skill points back for %d gold (%.1f a point)", points, cost, perPoint)
end

return RespecConfig
