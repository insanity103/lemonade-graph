-- ModuleScript | ReplicatedStorage.Config.UpgradeConfig | The gold upgrades sold at the Upgrade Stall.
--
-- Three upgrades, each a short ladder of TIERS bought in order with gold. Every tier has a level
-- gate (and the last prefix slot a rebirth gate) and a price anchored to the gold curve:
--     price = kills x GoldCurve.PerKill(minLevel, "minion"), rounded to two significant figures
-- so a tier costs a fixed number of ordinary kills' worth of gold AT the level it opens: a goal a
-- player saves toward in the zone they are in, never a Robux gate. The server (the Upgrade Stall
-- section of Gameplay/GameplayServices) re-checks every gate and the price before taking gold;
-- the client (ReplicatedStorage.UpgradeShop) only draws what the server sends it.
--
-- What each upgrade owns (all saved player attributes, SaveConfig.ATTRIBUTES):
--   LuckySpins   BonusSpinLevel 0..6. Every PAID spin at the wheel has BonusChance(level) odds of
--                paying one extra sword for free (rolled from the same pool, same RNG, server side).
--   MultiSpin    MultiSpin 0 -> 3 -> 5. One press at the wheel spins that many times.
--   PrefixSlots  PrefixSlots 1 -> 2 -> 3. The prefixes every new sword rolls
--                (WeaponModifiers.SlotUnlocks owns the gates and the prices).
local Config = script.Parent
local GoldCurve = require(Config:WaitForChild("GoldCurve"))
local WeaponModifiers = require(Config:WaitForChild("WeaponModifiers"))

local UpgradeConfig = {}

UpgradeConfig.RANGE = 14 -- studs from the stall's counter a purchase may be made from
UpgradeConfig.ORDER = { "LuckySpins", "MultiSpin", "PrefixSlots" }

local function roundPrice(raw: number): number
	local mag = 10 ^ math.max(math.floor(math.log10(math.max(raw, 1))) - 1, 0)
	return math.floor(raw / mag + 0.5) * mag
end

local function killsPrice(kills: number, minLevel: number): number
	return roundPrice(kills * GoldCurve.PerKill(minLevel, "minion"))
end

-- [TUNING] The ladders. value = what the attribute becomes when that tier is owned.
UpgradeConfig.Defs = {
	LuckySpins = {
		name = "Lucky Spins",
		blurb = "Paid spins can pay a free bonus sword",
		attr = "BonusSpinLevel",
		glyph = "+1",
		color = Color3.fromRGB(0, 196, 180), colorDark = Color3.fromRGB(0, 120, 116),
		tiers = {
			{ minLevel = 1, rebirths = 0, kills = 30, value = 1 },
			{ minLevel = 3, rebirths = 0, kills = 50, value = 2 },
			{ minLevel = 6, rebirths = 0, kills = 80, value = 3 },
			{ minLevel = 12, rebirths = 0, kills = 120, value = 4 },
			{ minLevel = 20, rebirths = 0, kills = 180, value = 5 },
			{ minLevel = 30, rebirths = 0, kills = 250, value = 6 },
		},
	},
	MultiSpin = {
		name = "Multi-Spin",
		blurb = "One press spins the wheel several times",
		attr = "MultiSpin",
		glyph = "x3",
		color = Color3.fromRGB(255, 150, 40), colorDark = Color3.fromRGB(214, 84, 20),
		tiers = {
			{ minLevel = 5, rebirths = 0, kills = 60, value = 3 },
			{ minLevel = 15, rebirths = 0, kills = 150, value = 5 },
		},
	},
	PrefixSlots = {
		name = "Prefix Slots",
		blurb = "Every new sword rolls one more prefix",
		attr = "PrefixSlots",
		glyph = "+P",
		color = Color3.fromRGB(176, 96, 255), colorDark = Color3.fromRGB(104, 40, 196),
		tiers = {}, -- filled from WeaponModifiers.SlotUnlocks below
	},
}

-- Lucky Spins: the free-bonus odds per paid spin at each level (0 = none).
UpgradeConfig.BONUS_PER_LEVEL = 0.05
function UpgradeConfig.BonusChance(level: any): number
	local lv = math.clamp(math.floor(tonumber(level) or 0), 0, #UpgradeConfig.Defs.LuckySpins.tiers)
	return lv * UpgradeConfig.BONUS_PER_LEVEL
end

do -- Prefix slots: the tiers and prices are WeaponModifiers' own, so the two can never disagree.
	local slots = UpgradeConfig.Defs.PrefixSlots.tiers
	for slot = WeaponModifiers.BASE_SLOTS + 1, WeaponModifiers.MAX_SLOTS do
		local row = WeaponModifiers.SlotUnlocks[slot]
		if row then
			table.insert(slots, { minLevel = row.minLevel, rebirths = row.rebirths or 0, kills = row.killsOfGold,
				value = slot, price = WeaponModifiers.SlotUnlockPrice(slot) })
		end
	end
	for _, id in ipairs(UpgradeConfig.ORDER) do
		for _, tier in ipairs(UpgradeConfig.Defs[id].tiers) do
			tier.price = tier.price or killsPrice(tier.kills, tier.minLevel)
		end
	end
end

-- What a tier (or the base, tier 0) DOES, in words.
function UpgradeConfig.EffectText(id: string, tierIndex: number): string
	local def = UpgradeConfig.Defs[id]
	if id == "LuckySpins" then
		if tierIndex <= 0 then return "No bonus spins" end
		return string.format("%d%% bonus spin chance", math.floor(UpgradeConfig.BonusChance(tierIndex) * 100 + 0.5))
	elseif id == "MultiSpin" then
		if tierIndex <= 0 then return "Single spins only" end
		return string.format("Spin x%d at once", def.tiers[tierIndex].value)
	elseif id == "PrefixSlots" then
		local slots = if tierIndex <= 0 then WeaponModifiers.BASE_SLOTS else def.tiers[tierIndex].value
		return string.format("%d prefix slot%s per sword", slots, slots == 1 and "" or "s")
	end
	return ""
end

-- The short label a tier's tile wears (the thing you are buying, in two or three characters).
function UpgradeConfig.TierGlyph(id: string, tierIndex: number): string
	local def = UpgradeConfig.Defs[id]
	local tier = def.tiers[tierIndex]
	if not tier then return "" end
	if id == "LuckySpins" then
		return string.format("%d%%", math.floor(UpgradeConfig.BonusChance(tierIndex) * 100 + 0.5))
	elseif id == "MultiSpin" then
		return "x" .. tier.value
	end
	return tostring(tier.value)
end

-- How many tiers of `id` this player owns, read from the saved attribute.
function UpgradeConfig.LevelOf(id: string, player: Instance?): number
	local def = UpgradeConfig.Defs[id]
	if not def or typeof(player) ~= "Instance" then return 0 end
	local raw = math.floor(tonumber(player:GetAttribute(def.attr)) or 0)
	local owned = 0
	for i, tier in ipairs(def.tiers) do
		if raw >= tier.value then owned = i end
	end
	return owned
end

-- Why this player may not buy tier `tierIndex` of `id` now (nil = may). Every argument is the
-- server's own reading; the client calls this only to draw.
function UpgradeConfig.Blocker(id: string, tierIndex: number, owned: number, level: number, rebirths: number,
	gold: number): (string?, string?)
	local def = UpgradeConfig.Defs[id]
	local tier = def and def.tiers[tierIndex]
	if not tier then return "max", "Maxed out" end
	if tierIndex ~= owned + 1 then return "order", "Buy the tier before it first" end
	if level < tier.minLevel then return "level", string.format("Reach level %d", tier.minLevel) end
	if rebirths < (tier.rebirths or 0) then return "rebirth", string.format("Rebirth %d required", tier.rebirths) end
	if gold < tier.price then return "gold", "Not enough gold" end
	return nil
end

-- The whole shop as this player sees it: one table per upgrade, in ORDER. Plain data (it crosses
-- the remote). level/rebirths/gold are the server's readings.
function UpgradeConfig.StateFor(player: Instance, level: number, rebirths: number, gold: number)
	local list = {}
	for _, id in ipairs(UpgradeConfig.ORDER) do
		local def = UpgradeConfig.Defs[id]
		local owned = UpgradeConfig.LevelOf(id, player)
		local tiers = {}
		for i, tier in ipairs(def.tiers) do
			local code = if i <= owned then "owned" else UpgradeConfig.Blocker(id, i, owned, level, rebirths, gold)
			tiers[i] = { price = tier.price, minLevel = tier.minLevel, rebirths = tier.rebirths or 0,
				glyph = UpgradeConfig.TierGlyph(id, i), status = code or "ready" }
		end
		local nextTier = def.tiers[owned + 1]
		local code, reason = UpgradeConfig.Blocker(id, owned + 1, owned, level, rebirths, gold)
		table.insert(list, {
			id = id, name = def.name, blurb = def.blurb, glyph = def.glyph, owned = owned, max = #def.tiers,
			now = UpgradeConfig.EffectText(id, owned),
			nextText = if nextTier then UpgradeConfig.EffectText(id, owned + 1) else nil,
			nextShort = if nextTier then UpgradeConfig.TierGlyph(id, owned + 1) else nil,
			price = nextTier and nextTier.price or nil, status = code or "ready", reason = reason, tiers = tiers,
		})
	end
	return { upgrades = list, gold = gold, level = level, rebirths = rebirths }
end

return UpgradeConfig
