-- ModuleScript | ReplicatedStorage.Config.SellValue | WHAT A SWORD IS WORTH. ONE NUMBER, ONE CALL.
--
-- WHY THIS EXISTS. There used to be two prices for the same sword. `SwordDropSystem` owned a
-- BOSS_SELL_VALUES of 60 / 300 / 2,000 / 13,000 / 100,000 with a rarity factor and a lesser-pool
-- factor; `InventoryService` owned a private copy reading 50 / 150 / 450 / 1,200 / 3,000 with NO
-- rarity factor and NO lesser factor. Measured (ledger r00, re-measured r01): the same tier-5 boss
-- Legendary was worth 800,000 gold down one path and 3,000 down the other, and across the ten
-- sword shapes checked the two tables disagreed by up to x267. The price of a thing cannot depend
-- on which button the player happened to press.
--
-- So the price lives here, once, and every path that pays gold for a sword reads it:
--   * the pickup prompt (SwordDropSystem) -- KEEP or SELL, the moment the sword drops
--   * the inventory SELL button (InventoryService, via InventorySystem)
--   * the price printed ON that button (MainMenuGui) -- the client requires this same module, so
--     the number the player reads is the number the server will pay, not a copy of it.
--
-- ── THE PRICE IS A FRACTION OF A STRIKE ──────────────────────────────────────────────────────
-- The old ladder was five tier numbers climbing x1,667 from tier 1 to tier 5, while kill gold per
-- hour -- the faucet it competes with -- climbs x108 over the same span. Measured (r00): selling
-- drops was 0.4%-6.3% of income in the first two zones and 36.3% of it in the last. That is not
-- one faucet, it is two, and the second one only switches on when the player no longer needs it.
--
-- A sword is now worth SELL_FRACTION of what ONE BARE FORGE STRIKE ON THAT SAME SWORD costs, by
-- Config.SwordValue's own formula -- the rarity's PRICE_UNIT times the power factor of the
-- sword's own rolled base damage. Three things follow, and they are the whole reason for it:
--
--   1. IT SCALES WITH THE GAME AUTOMATICALLY. The forge price already climbs with the zone,
--      because it is priced on the square of the sword's base and the pools climb x0.90 -> x13.98
--      across the eight zones. Pinning the sale to it means the sell faucet and the forge sink
--      move together, at every zone, with nobody maintaining a parallel table.
--   2. IT IS ONE SENTENCE A PLAYER CAN HOLD. "Selling this pays about two fifths of what striking
--      it costs." So SELL is legible against the thing the gold is for.
--   3. IT SMOOTHS WHAT A FIVE-RUNG TIER LADDER COULD NOT. Two zones share a tier but not an
--      income; pricing on the sword's own power gives an eight-step ladder rather than a
--      five-step one. Measured across the eight zones (r01 harness, 2,500 rotations each):
--      selling every drop is 4.0%-34.4% of income, mean 13.3%, against the old table's
--      0.4%-36.3% -- and the share now FALLS from the opening zone to the endgame instead of
--      rising, which is the right direction: in the Iron Lowlands the kill loop pays 8,190/h and
--      the zone drops 12 swords an hour, so loot IS the opening zone's payday; by the Celestial
--      Summit the kill loop pays 1.13M/h and the same 13 drops are 13% of it.
--
-- Nothing here is random and nothing here reads the player: the same sword is worth the same gold
-- to everybody, before the rebirth gold multiplier the caller applies on top.
local BossWeapons = require(script.Parent:WaitForChild("BossWeapons"))
local SwordValue = require(script.Parent:WaitForChild("SwordValue"))

local SellValue = {}

-- [TUNING] The whole price, in one number: a sword sells for this much of a bare strike on it.
-- 0.40 was fitted by simulation through the shipped drop code (r01, section 2): it lands the sell
-- faucet at 4%-34% of income across the eight zones with a mean of 13%, which is a faucet a player
-- notices at every level without one that outruns the kill loop anywhere. Push it past ~0.7 and
-- the opening zone earns more from selling than from killing; drop it under ~0.2 and the prompt
-- stops being a decision, which is what the old tier-1 price did (a junk drop was worth 10 gold).
SellValue.SELL_FRACTION = 0.40

-- A lesser (ordinary-enemy) sword sells for BossWeapons.LESSER_SELL_FACTOR of a boss sword of the
-- same power and rarity. That factor lives with the pools, not here, so the pools stay the one
-- place that says what "lesser" means.
function SellValue.LesserFactor(): number
	return BossWeapons.LESSER_SELL_FACTOR
end

-- The sword's price unit: Config.SwordValue's own rarity base times its own power factor. This is
-- the same pair of calls MerchantConfig prices the mystery blade against, so the shop and the sale
-- are quoted in the same unit.
function SellValue.StrikeReference(baseMult: number?, rarity: string?): number
	local base = SwordValue.PRICE_UNIT[rarity] or SwordValue.PRICE_UNIT.Common
	return base * SwordValue.powerFactor(baseMult)
end

-- THE PRICE. `attrs` is the sword, in the same field names BossSwordFactory stamps on the Tool:
--   DamageMult (its rolled base), Rarity, Lesser (true on a normal-enemy sword), Starter.
-- `goldMult` is the caller's rebirth gold multiplier (1 when there is none).
-- Returns a whole number of gold, and 0 for anything that is not a sellable sword.
function SellValue.Gold(attrs, goldMult: number?): number
	if typeof(attrs) ~= "table" then
		return 0
	end
	-- The starter sword is never for sale: a new player cannot be talked out of their only blade.
	if attrs.Starter == true then
		return 0
	end
	-- A save written before the base was stamped, or a hand-made tool, prices at the opening
	-- zone's own tier rather than for nothing (SwordValue.POWER_MIN_BASE does the flooring).
	local baseMult = tonumber(attrs.DamageMult) or tonumber(attrs.BaseMult) or tonumber(attrs.baseMult)
	local value = SellValue.SELL_FRACTION * SellValue.StrikeReference(baseMult, attrs.Rarity)
	if attrs.Lesser == true then
		value *= BossWeapons.LESSER_SELL_FACTOR
	end
	local mult = tonumber(goldMult)
	if typeof(mult) ~= "number" or mult ~= mult or mult == math.huge then
		mult = 1
	end
	-- Rounded to 10 gold, like every other price in the game, and never free.
	return math.max(10, math.floor(value * math.max(0, mult) / 10 + 0.5) * 10)
end

-- The same price, read straight off a live Tool. Used by the inventory sell path and by the
-- inventory tile that prints the price on its button.
function SellValue.ForTool(tool: Instance?, goldMult: number?): number
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") or tool:GetAttribute("BossDrop") ~= true then
		return 0
	end
	return SellValue.Gold({
		DamageMult = tool:GetAttribute("DamageMult"),
		Rarity = tool:GetAttribute("Rarity"),
		Lesser = tool:GetAttribute("Lesser"),
		Starter = tool:GetAttribute("Starter"),
	}, goldMult)
end

-- The rebirth gold multiplier a player carries, read the way every other gold path reads it.
function SellValue.GoldMultFor(player: Instance?): number
	if typeof(player) ~= "Instance" then
		return 1
	end
	local mult = player:GetAttribute("RebirthGoldMult")
	if typeof(mult) ~= "number" or mult ~= mult then
		return 1
	end
	return math.max(0, mult)
end

return SellValue
