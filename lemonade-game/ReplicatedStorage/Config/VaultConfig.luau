-- ModuleScript | ReplicatedStorage.Config.VaultConfig | THE PRICE OF A SHELF.
--
-- WHY THIS EXISTS. The Vaultkeeper used to hold exactly twelve swords for everybody, free,
-- forever. Measured (vault_wealth r00, 2,000 real rotations per zone through the shipped drop
-- code): a player who keeps what drops fills all twelve slots in 59-144 minutes, and over a
-- twelve-hour career 97 of 106 drops (91.5%) could not be kept -- after the shelf filled, every
-- later drop was a forced sale. At the same time the vault destroyed ZERO gold: it was the only
-- major system in the game with no price on it, while the thing players most want more of.
--
-- So slots are bought with gold now, and the price of the next one climbs with how many you
-- already own. Three things that buys us:
--
--   1. GOLD HAS SOMEWHERE TO GO AT EVERY STAGE. The ladder spans x1,069 from the first bought
--      slot to the last, which is the same order as the income climb the ledger measured
--      (7,721 gold/h in the Iron Lowlands -> 778,639/h on the Celestial Summit, x101) times the
--      slower pace at which a player wants another shelf. MEASURED (r01, through the shipped
--      modules): for a player at any band who has put three hours of that band's income into
--      shelves, the next slot costs 25.4-37.8 minutes of that band's income and 4.9-12.2 forge
--      strikes -- at EVERY one of the eight zones, from the Iron Lowlands to the Celestial Summit.
--   2. KEEPING A SWORD IS A PURCHASE. The pickup prompt asks KEEP or SELL. Before this, KEEP was
--      free until the shelf filled and then impossible. Now KEEP has a running price -- the slot
--      it eventually costs -- so hoarding competes with the forge and the blacksmith for the same
--      gold instead of sitting outside the economy.
--   3. THE SHELF STOPS BEING A WALL. Twelve free slots still fill in the first session; after
--      that the player is buying room rather than being told no.
--
-- Nothing here is bought with Robux. Every slot in this ladder is bought with gold earned in play.
local SaveConfig = require(script.Parent:WaitForChild("SaveConfig"))

local VaultConfig = {}

-- [TUNING] Slots every player starts with, free. Unchanged from the flat capacity that shipped
-- (SaveConfig.VAULT_CAPACITY is the same number and stays the authority for a fresh profile), so
-- no existing player loses a shelf and the opening session still gets its 59-144 minutes of
-- keeping everything before the first purchase is even a question.
VaultConfig.STARTING_SLOTS = SaveConfig.VAULT_CAPACITY

-- [TUNING] The hard ceiling on total capacity, bought and granted together.
--
-- Justified by the measured drop rate rather than picked. The eight zones drop 5.0-12.3 swords an
-- hour, of which 0.67-2.14 are Rare or better (r00, 2,000 rotations per zone). At 60 slots a
-- player who keeps only Rare-or-better fills the vault in 28-90 hours of play, and a player who
-- keeps everything fills it in 5-12 hours -- long enough that the cap is a destination rather than
-- a wall, short enough that it is reachable inside a real player's lifetime with the game. Past
-- this the grid stops being readable and the DataStore entry stops being small.
VaultConfig.MAX_SLOTS = 60

-- [TUNING] The price ladder. price(n) = SLOT_BASE_PRICE * SLOT_GROWTH^n, where n is how many
-- slots this player has ALREADY BOUGHT (slots granted by a wealth milestone are free and do not
-- move the price -- they skip the player past the dearest rungs instead).
--
-- SLOT_BASE_PRICE 1,500: 11.5 minutes of Iron Lowlands income (7,807/h measured, r01), or 1.7
-- forge strikes on the sword an Iron Lowlands player is carrying (870 measured). A first slot a
-- new player can decide to buy in their first session, and still feel.
--
-- SLOT_GROWTH 1.16: the 48th bought slot costs 1,605,520 gold, x1,070 the first, against a
-- Celestial Summit income of 939,016/h -- 1.7 hours of the endgame's own income for the last
-- shelf in the game, and 18.7 forge strikes at that band. Buying the whole ladder out destroys
-- 11,630,640 gold, which is more than a measured twelve-hour career earns (8.6M).
--
-- The reason a geometric ladder is the right shape: the next slot always costs the same SHARE of
-- everything already spent on slots. Measured: 27.1% after 6 bought, 19.2% after 12, 16.5% after
-- 24, 16.0% after 47. So the sink never goes soft, at any purse size.
VaultConfig.SLOT_BASE_PRICE = 1500
VaultConfig.SLOT_GROWTH = 1.16

-- Every price in the game rounds to ten gold; these do too.
local function round10(value: number): number
	return math.floor(value / 10 + 0.5) * 10
end

-- How many slots can still be BOUGHT by a player who has bought `bought` and been granted
-- `granted` by the wealth ladder. Granted slots count against the cap, so the ladder's free
-- shelves let a player reach 60 without paying for the ladder's most expensive rungs.
function VaultConfig.PurchasableLeft(bought: number?, granted: number?): number
	local b = math.max(0, math.floor(tonumber(bought) or 0))
	local g = math.max(0, math.floor(tonumber(granted) or 0))
	return math.max(0, VaultConfig.MAX_SLOTS - VaultConfig.STARTING_SLOTS - b - g)
end

-- Total capacity: the free shelf, plus what was bought, plus what the wealth ladder granted,
-- never above the cap.
function VaultConfig.CapacityFor(bought: number?, granted: number?): number
	local b = math.max(0, math.floor(tonumber(bought) or 0))
	local g = math.max(0, math.floor(tonumber(granted) or 0))
	return math.min(VaultConfig.MAX_SLOTS, VaultConfig.STARTING_SLOTS + b + g)
end

-- THE PRICE OF THE NEXT SLOT for a player who has bought `bought` already. Returns nil when
-- there is nothing left to buy, so every caller has to handle the cap rather than quote a price
-- for a slot that cannot exist.
function VaultConfig.PriceForNext(bought: number?, granted: number?): number?
	if VaultConfig.PurchasableLeft(bought, granted) <= 0 then
		return nil
	end
	local b = math.max(0, math.floor(tonumber(bought) or 0))
	return round10(VaultConfig.SLOT_BASE_PRICE * VaultConfig.SLOT_GROWTH ^ b)
end

-- What it costs to go from `bought` bought slots to `target` bought slots, at today's ladder.
-- Used by the dossier and by any UI that wants to say "the next five shelves cost X".
function VaultConfig.PriceRange(bought: number?, target: number?): number
	local from = math.max(0, math.floor(tonumber(bought) or 0))
	local to = math.max(from, math.floor(tonumber(target) or 0))
	local total = 0
	for n = from, to - 1 do
		total += round10(VaultConfig.SLOT_BASE_PRICE * VaultConfig.SLOT_GROWTH ^ n)
	end
	return total
end

-- Short label for a price, in the same style the rest of the HUD uses.
function VaultConfig.short(value: number?): string
	local v = math.max(0, math.floor(tonumber(value) or 0))
	if v >= 1e6 then return string.format("%.2fM", v / 1e6) end
	if v >= 1e4 then return string.format("%.0fK", v / 1e3) end
	if v >= 1e3 then return string.format("%.1fK", v / 1e3) end
	return tostring(v)
end

return VaultConfig
