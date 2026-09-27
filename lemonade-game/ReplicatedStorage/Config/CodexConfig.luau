--// CodexConfig  (the Codex: a bestiary and a sword index, one page per built zone)
-- Wave 1 of the 2026-09-25 fun plan (Fisch's bestiary, the OSRS collection log, Hollow Knight's
-- Hunter's Journal): every session gets a goal. Each zone page lists its enemies (kill counts,
-- a silhouette until the first kill) and the swords its spin pool can give (found or "??").
--
--   * HUNTER: every enemy on a page killed MASTERY times -> +HUNTER_DAMAGE damage, forever.
--   * COLLECTOR: every sword on a page found -> COLLECTOR_SPINS spins' worth of tokens, once.
--
-- Saved per player as plain attributes (SaveConfig.ATTRIBUTES), so the client reads them directly:
--   CodexKills  "IronSquire=12;FrostImp=3"   kills per archetype
--   CodexSwords "Quarry Shank,Pit Shiv"      swords ever held
--   CodexClaims "IronLowlands:hunter,..."    page rewards already paid
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpinPools = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SpinPools"))

local CodexConfig = {}

CodexConfig.MASTERY = { minion = 50, boss = 3 } -- [TUNING] kills that master an entry
CodexConfig.HUNTER_DAMAGE = 0.02 -- [TUNING] +2% damage per mastered page
CodexConfig.COLLECTOR_SPINS = 10 -- [TUNING] a full sword page pays this many of the pool's dearest spins

-- Only built zones get a page; a new zone joins the Codex by adding its page here.
-- `enemies`: { archetype key, display name, role }. `maxLevel` keeps a pool's late-game guests
-- (Briarwood's Lv 97 Celestial rows) off the page they only visit.
CodexConfig.Pages = {
	{
		zone = "IronLowlands", name = "Iron Lowlands", maxLevel = 20,
		enemies = {
			{ "IronSquire", "Quarry Cutthroat", "minion" },
			{ "IronBerserker", "Pit Brute", "minion" },
			{ "Boss_Gorgon", "Warden of the Pit", "boss" },
		},
	},
	{
		zone = "Briarwood", name = "Briarwood", maxLevel = 24,
		enemies = {
			{ "ThornStalker", "Thorn Stalker", "minion" },
			{ "BriarBrute", "Briar Brute", "minion" },
			{ "RootWarden", "Rootbound Warden", "boss" },
		},
	},
	{
		zone = "FrostboundGlacier", name = "Frostbound Glacier", maxLevel = 35,
		enemies = {
			{ "FrostImp", "Frost Stalker", "minion" },
			{ "GlacialGargoyle", "Glacial Sentinel", "minion" },
			{ "Boss_FrostRevenant", "Frost Revenant", "boss" },
		},
	},
}

-- Each page's swords: its zone's spin pool, minus rows carried in from another area and rows
-- above the page's level band. Built once from SpinPools, so a new pool row shows up by itself.
local byZone, byArchetype = {}, {}
for _, page in ipairs(CodexConfig.Pages) do
	page.swords = {}
	local pool = SpinPools.Get(page.zone)
	local seen = {}
	for _, entry in ipairs(pool and pool.entries or {}) do
		if not entry.from and entry.minLevel <= page.maxLevel and not seen[entry.sword] then
			seen[entry.sword] = true
			table.insert(page.swords, { name = entry.sword, rarity = entry.rarity, ultra = entry.ultra })
		end
	end
	byZone[page.zone] = page
	for _, e in ipairs(page.enemies) do byArchetype[e[1]] = page end
end

function CodexConfig.PageFor(zone: string) return byZone[zone] end
function CodexConfig.PageOfArchetype(key: string) return byArchetype[key] end

function CodexConfig.Mastery(role: string): number
	return CodexConfig.MASTERY[role] or CodexConfig.MASTERY.minion
end

-- "A=1;B=2" <-> { A = 1, B = 2 }
function CodexConfig.DecodeKills(s: any): { [string]: number }
	local out = {}
	if typeof(s) ~= "string" then return out end
	for key, n in string.gmatch(s, "([%w_]+)=(%d+)") do out[key] = tonumber(n) end
	return out
end

function CodexConfig.EncodeKills(t: { [string]: number }): string
	local keys = {}
	for k in pairs(t) do table.insert(keys, k) end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do table.insert(parts, k .. "=" .. math.floor(t[k])) end
	return table.concat(parts, ";")
end

-- "a,b" -> { a = true, b = true }
function CodexConfig.DecodeSet(s: any): { [string]: boolean }
	local out = {}
	if typeof(s) ~= "string" then return out end
	for item in string.gmatch(s, "[^,]+") do out[item] = true end
	return out
end

-- How far a player is through one page.
function CodexConfig.Progress(page, kills: { [string]: number }, found: { [string]: boolean })
	local mastered, seen = 0, 0
	for _, e in ipairs(page.enemies) do
		local n = kills[e[1]] or 0
		if n > 0 then seen += 1 end
		if n >= CodexConfig.Mastery(e[3]) then mastered += 1 end
	end
	local swords = 0
	for _, s in ipairs(page.swords) do
		if found[s.name] then swords += 1 end
	end
	return {
		seen = seen, mastered = mastered, enemies = #page.enemies,
		swords = swords, swordsTotal = #page.swords,
		hunter = mastered == #page.enemies, collector = #page.swords > 0 and swords == #page.swords,
	}
end

-- Tokens a full sword page pays: COLLECTOR_SPINS of the pool's dearest spin.
function CodexConfig.CollectorTokens(page): number
	local pool = SpinPools.Get(page.zone)
	local dearest = 0
	for _, c in ipairs(pool and pool.cost or {}) do dearest = math.max(dearest, c) end
	return CodexConfig.COLLECTOR_SPINS * dearest
end

return CodexConfig
