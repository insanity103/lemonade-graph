local RebirthConfig = {}

-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- THE REBIRTH LOOP, priced along the career players actually play (rebirth_loop r00 -> r01).
--
-- Every ledger before r00 modelled a twelve-hour career with no rebirths. Measured through the
-- shipped modules, the real career is a SERIES of rebirths, and under the previous rules it was
-- broken in four ways that the numbers ranked:
--
--   1. The price (40,000 x 4^n) dwarfed every other sink. The rebirther saved for 88-96% of each
--      cycle and spent 9,890 gold at the forge and NOTHING at the blacksmith in twelve hours,
--      against 1.1M and 6.1M for a player who never rebirthed. The biggest sink switched every
--      other sink off.
--   2. Every rebirth was gated by gold and never by level: Lv41/66/84/95/103/112 against
--      requirements of 20/35/50/65/80/95. The stated requirement was decoration.
--   3. The wipe zeroed every stat while keeping the sword: DPS fell to 6-11%, max HP by 88%, and
--      the re-climb from the Iron Lowlands cost 15-36% of the next cycle.
--   4. There was no cap and no decision: rebirth 6 needed 77 hours to pay back and was a net loss
--      over twelve hours; rebirth 10 asked for Lv155, which no amount of play reaches.
--
-- What this module now says, and why:
--
--   * THE PRICE IS A LADDER, FITTED (GOLD_COST below), not a growth formula. Each rung was set to
--     roughly a third of what the cycle that ends at that rebirth EARNS, measured by playing the
--     career price-free through the shipped modules (kills, drops, sells, quests, deaths). So the
--     gold is in hand at about the moment the level is, the rest of the cycle's income is free for
--     the forge, the blacksmith and the vault, and the price still grows with the multipliers the
--     earlier rebirths gave.
--   * THE LEVEL IS THE MOMENT. BASE_LEVEL + LEVEL_PER_REBIRTH x n as before, but capped at
--     LEVEL_CAP (100, the highest boss in the world): the enemy table cannot deliver Lv110 or Lv125
--     in any reasonable time, so the old ladder simply stopped being reachable without saying so.
--   * THE WIPE KEEPS A SHARE OF THE BUILD. Level and XP go to 1 and 0; every stat point (Strength,
--     Health, Defense, Experience Gain, and any unspent points) is scaled to RETAINED_SHARE. The
--     sword, the vault, the wealth rungs and the forge's timers were already kept. The intent is
--     the difficulty-tier plan's: the re-climb is a victory lap through zones the player owns, not
--     a walk back to the Iron Lowlands with a Legendary in hand and 100 HP.
--   * THE LADDER ENDS, HONESTLY. MAX_REBIRTHS is a hard cap the server enforces; the panel shows
--     it. Multipliers stack additively to the cap. The panel also shows the price, what it costs
--     in hours of the player's OWN measured income, and how long the extra gold multiplier takes
--     to pay it back, so the decision to rebirth now or spend now is the player's, with numbers.
--
-- Nothing here is bought with Robux, and no saved field was renamed or dropped.
-- ══════════════════════════════════════════════════════════════════════════════════════════════

RebirthConfig.BASE_LEVEL = 20
RebirthConfig.LEVEL_PER_REBIRTH = 15
-- [TUNING] The requirement never climbs past this. The top boss in the world is Lv100 and the
-- top minion Lv92; ten levels past that is where a never-rebirther sits after a long day, and it
-- is the last stretch a rebirther can still reach in a session (measured r01 section 8: Lv110 in
-- 3-4 hours of Summit play at rebirth 6-7, against 40+ hours for the old ladder's Lv125).
RebirthConfig.LEVEL_CAP = 110
-- [TUNING] The honest end of the ladder. The handler refuses a rebirth past this and publishes
-- RebirthMaxed so the panel can say so. Eight, because the world's XP curve delivers Lv100 in
-- 1-2 hours of Summit play at rebirth 6-7 (measured, r01 section 8), so the last two rungs are
-- real sessions rather than unreachable arithmetic.
RebirthConfig.MAX_REBIRTHS = 8

-- [TUNING] Gold price of the NEXT rebirth for a player holding n of them, indexed n+1.
-- Fitted by simulation (r01, sim_rebirth_loop.luau in "fit" mode: the career played price-free
-- through the shipped modules, so each cycle's length is the LEVEL's and its earnings are what
-- the zones actually pay). The rule for the fit:
--   * rungs 1-5: the level arrives in 2-10 minutes of play, so the price is a few minutes of the
--     kill income of the band the requirement unlocks, at that rung's own gold multiplier. It
--     lands within minutes of the level and stops a rebirth from being free the moment the bar
--     fills. Once-per-career quest gold is NOT counted (it is 86-93% of what cycles 1-3 earn and
--     never comes back).
--   * rung 6: the level is half an hour away, so the price is about a third of what the cycle
--     earns (2.7M measured), in hand well before the level, leaving the rest for the forge, the
--     blacksmith and the vault.
--   * rungs 7-8 (r02): a third of the cycle (12M / 15M) needed 11-13 hours of Summit play to pay
--     back on the rung's own +0.5 gold multiplier, and net of price a twelve-hour player was better
--     off stopping at 6 -- a rung the panel told you not to buy. They now cost about 45-55 minutes
--     of the Summit's income at the rung below (measured r01 section 3: 5.4M/h at rebirth 6,
--     6.5M/h at 7), which pays back in under 4.5 hours: every rung on the ladder is worth buying
--     the moment its gate opens, and the decision the panel presents is WHEN, not WHETHER.
-- The rule that holds across the whole ladder: each rung costs 12-55 minutes of the income of
-- the band its requirement unlocks, and pays for itself on its own multiplier inside a session.
-- Anything past the table (only reachable if MAX_REBIRTHS is raised) keeps growing at
-- GOLD_COST_GROWTH from the last rung so the ladder can never go flat by accident.
RebirthConfig.GOLD_COST = {
	6000,       -- rebirth 1, at Lv20
	25000,      -- rebirth 2, at Lv35
	40000,      -- rebirth 3, at Lv50
	200000,     -- rebirth 4, at Lv65
	500000,     -- rebirth 5, at Lv80
	1200000,    -- rebirth 6, at Lv95
	4000000,    -- rebirth 7, at Lv110 (r02: was 12,000,000)
	5000000,    -- rebirth 8, at Lv110 (r02: was 15,000,000)
}
RebirthConfig.GOLD_COST_GROWTH = 1.5

-- Gold the NEXT rebirth costs a player who currently has `rebirths` of them.
function RebirthConfig.GetGoldCost(rebirths)
	local n = math.max(0, math.floor(tonumber(rebirths) or 0))
	local table_ = RebirthConfig.GOLD_COST
	local price
	if n < #table_ then
		price = table_[n + 1]
	else
		price = table_[#table_] * RebirthConfig.GOLD_COST_GROWTH ^ (n + 1 - #table_)
	end
	return math.floor(price / 10 + 0.5) * 10
end

-- True when a player holding `rebirths` cannot buy another: the ladder is finished.
function RebirthConfig.IsMaxed(rebirths)
	local n = math.max(0, math.floor(tonumber(rebirths) or 0))
	return n >= RebirthConfig.MAX_REBIRTHS
end

-- [TUNING] THE SHARE OF THE BUILD A WIPE KEEPS. Applied to every stat point and to unspent
-- points at the moment of rebirth (RebirthSystem). 0.35 was chosen by simulation so that a reborn
-- player has the max HP the game already expects at the door of the zone two regions below the
-- one they left (measured r01 section 6): a six-times-reborn Lv95 player restarts in the
-- Infernal Caldera with a ~1,700 HP pool rather than in the Iron Lowlands with 490, and the
-- re-climb to the level the wipe took falls from a third of the next cycle to a few minutes.
RebirthConfig.RETAINED_SHARE = 0.35

-- Multipliers per rebirth (additive stacking)
RebirthConfig.XP_BOOST_PER_REBIRTH = 0.35      -- +35% XP Gain per rebirth
RebirthConfig.GOLD_BOOST_PER_REBIRTH = 0.50    -- +50% Gold Gain per rebirth
RebirthConfig.DAMAGE_BOOST_PER_REBIRTH = 0.25  -- +25% Global Sword Damage per rebirth
RebirthConfig.HEALTH_BOOST_PER_REBIRTH = 0.15  -- +15% Base Health per rebirth
RebirthConfig.BONUS_SKILL_POINTS_PER_REBIRTH = 5 -- +5 starting bonus skill points immediately on rebirth

-- The flat bonus points a player holding `rebirths` starts a cycle with, on top of the retained
-- share of their own build. The +10 at rebirth 5 is Astral Supernova's.
function RebirthConfig.StartingSkillPoints(rebirths)
	local n = math.max(0, math.floor(tonumber(rebirths) or 0))
	local points = RebirthConfig.BONUS_SKILL_POINTS_PER_REBIRTH * n
	if n >= 5 then points += 10 end
	return points
end

-- Weapon drop rate scaling per rebirth
-- Boosts base drop chances slightly per rebirth tier (e.g. +1% to +2% flat or scaling boost)
RebirthConfig.DROP_RATE_BONUS_PER_REBIRTH = {
	Legendary = 0.010, -- +1.0% flat drop rate per rebirth (e.g. 5% -> 6% at RB1, 10% at RB5)
	Epic      = 0.015, -- +1.5% flat drop rate per rebirth (e.g. 10% -> 11.5% at RB1, 17.5% at RB5)
	Rare      = 0.025, -- +2.5% flat drop rate per rebirth (e.g. 40% -> 42.5% at RB1, 52.5% at RB5)
	Uncommon  = 0.030, -- +3.0% flat drop rate per rebirth (e.g. 60% -> 63% at RB1, 75% at RB5)
	Common    = 0.030, -- +3.0% flat drop rate per rebirth (e.g. 80% -> 83% at RB1, 95% at RB5)
}

-- Rebirth 5+ Blessed Drop Bonus
RebirthConfig.REBIRTH_5_BLESSED_BONUS = 0.05 -- +5% Blessed weapon drop chance at Rebirth 5+ (3% base -> 8% total)

-- Milestone Special Perks
RebirthConfig.Milestones = {
	[1] = {
		title = "Ascendant Strike",
		desc = "+50% Knockback, +5 Starting Skill Points, +Rarity Drop Rates",
		knockbackBonus = 50,
	},
	[2] = {
		title = "Glacial Endurance",
		desc = "+100 Max Base Health",
		flatHealthBonus = 100,
	},
	[3] = {
		title = "Infernal Precision",
		desc = "+10% Permanent Critical Strike Chance",
		flatCritBonus = 0.10,
	},
	[4] = {
		title = "Void Cleave",
		desc = "+3 Studs Extended Reach on all swords",
		flatRangeBonus = 3.0,
	},
	[5] = {
		title = "Astral Supernova",
		desc = "+100% Critical Damage, +10 Starting Skill Points, +5% Blessed Weapon Chance",
		critDamageMultiplier = 2.0,
		blessedBonus = 0.05,
	},
}

function RebirthConfig.GetRequiredLevel(rebirths)
	local n = math.max(0, math.floor(tonumber(rebirths) or 0))
	return math.min(RebirthConfig.LEVEL_CAP, RebirthConfig.BASE_LEVEL + RebirthConfig.LEVEL_PER_REBIRTH * n)
end

function RebirthConfig.GetMultipliers(rebirths)
	rebirths = math.max(0, math.floor(tonumber(rebirths) or 0))
	local blessedBonus = 0
	if rebirths >= 5 then
		blessedBonus = RebirthConfig.REBIRTH_5_BLESSED_BONUS
	end

	return {
		xpMult = 1 + (RebirthConfig.XP_BOOST_PER_REBIRTH * rebirths),
		goldMult = 1 + (RebirthConfig.GOLD_BOOST_PER_REBIRTH * rebirths),
		damageMult = 1 + (RebirthConfig.DAMAGE_BOOST_PER_REBIRTH * rebirths),
		healthMult = 1 + (RebirthConfig.HEALTH_BOOST_PER_REBIRTH * rebirths),
		bonusSkillPoints = RebirthConfig.BONUS_SKILL_POINTS_PER_REBIRTH * rebirths,
		blessedBonus = blessedBonus,
	}
end

-- Seconds until the NEXT rebirth's extra gold multiplier has paid its own price back, at an
-- income of `goldPerHour` measured WITH the player's current multiplier. The server measures the
-- income and publishes the result (RebirthPayback); the panel only renders it. nil when there is
-- no income to measure against or the ladder is finished.
function RebirthConfig.PaybackSeconds(rebirths, goldPerHour)
	local n = math.max(0, math.floor(tonumber(rebirths) or 0))
	local rate = tonumber(goldPerHour) or 0
	if rate <= 0 or RebirthConfig.IsMaxed(n) then
		return nil
	end
	local now = RebirthConfig.GetMultipliers(n).goldMult
	local after = RebirthConfig.GetMultipliers(n + 1).goldMult
	local extraPerHour = rate * (after / now - 1)
	if extraPerHour <= 0 then
		return nil
	end
	return RebirthConfig.GetGoldCost(n) / extraPerHour * 3600
end

function RebirthConfig.GetEffectiveDropChance(baseChance, rarity, rebirths)
	rebirths = rebirths or 0
	local perRebirthBonus = RebirthConfig.DROP_RATE_BONUS_PER_REBIRTH[rarity] or 0.01
	local totalChance = baseChance + (perRebirthBonus * rebirths)
	return math.clamp(totalChance, 0, 1.0)
end

return RebirthConfig
