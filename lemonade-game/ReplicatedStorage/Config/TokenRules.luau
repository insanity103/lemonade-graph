--// TokenRules  (what a kill pays in spin tokens, and how the payout is split into pickups)
-- Enemies no longer drop swords. Every kill pays SPIN TOKENS: a saved currency (the player
-- attribute `Tokens`, SaveConfig.ATTRIBUTES) that is carried back to town and spent at the spin
-- wheel. The server credits the tokens the instant the kill lands (SwordDropSystem) and tells the
-- killer's client how the payout splits into pickups; the client only animates them (the burst,
-- the magnet, the flight to the HUD counter). Nothing on the client decides a count.
--
-- Tokens climb with the world, a little slower than the wheel's price does: a spin costs more the
-- deeper the pool (Config.SpinPools `cost`, about x1.6-2 per area) and a kill pays more the deeper
-- the foe (ZONE_SCALE below), so a spin is ~5 ordinary kills at the first trailhead and ~13 at the
-- Summit boss step, and farming an early field for a late pool is slow on purpose.
local TokenRules = {}

-- [TUNING] Tokens per kill by what the enemy was: { min, max } (inclusive, uniform).
-- A boss is the zone's payday (roughly six ordinary kills); a warden gates a bridge zone.
TokenRules.PER_KILL = {
	minion = { 3, 5 },
	elite = { 8, 10 },
	warden = { 14, 18 },
	boss = { 24, 30 },
}

-- [TUNING] Every kill's band is multiplied by the scale of the area the foe stands in (its Zone
-- attribute); an unknown area pays x1.
TokenRules.ZONE_SCALE = {
	IronLowlands = 1,
	Briarwood = 1.8,
	FrostboundGlacier = 3,
	SunkenMarsh = 4.8,
	InfernalCaldera = 7.5,
	Stormwatch = 11,
	VoidRift = 16,
	CelestialSummit = 24,
}

-- [TUNING] The most pickups one kill bursts into. At or under this, one pickup is one token (the
-- burst IS the count); above it the payout is shared across this many pickups, each worth more.
TokenRules.MAX_PICKUPS = 8

-- The role an enemy model counts as (the same reading GoldCurve.RoleOf uses): Boss = true is a
-- real boss, SpawnRole "boss" without it is a named warden, "elite" an elite, else a minion.
function TokenRules.RoleOf(model: Instance?): string
	if typeof(model) ~= "Instance" then
		return "minion"
	end
	if model:GetAttribute("Boss") == true then
		return "boss"
	end
	local spawnRole = model:GetAttribute("SpawnRole")
	if spawnRole == "boss" then
		return "warden"
	elseif spawnRole == "elite" then
		return "elite"
	end
	return "minion"
end

-- Tokens one kill pays. rng (optional) returns an integer in [lo, hi]; default math.random.
-- zone (optional): the area the foe stood in, scaling the band by ZONE_SCALE.
function TokenRules.ForKill(role: string?, rng: ((number, number) -> number)?, zone: string?): number
	local band = TokenRules.PER_KILL[role or "minion"] or TokenRules.PER_KILL.minion
	local scale = (zone and TokenRules.ZONE_SCALE[zone]) or 1
	local lo = math.max(1, math.floor(band[1] * scale + 0.5))
	local hi = math.max(lo, math.floor(band[2] * scale + 0.5))
	return math.max(1, math.floor((rng or math.random)(lo, hi)))
end

-- Split a payout into pickups: { value, value, ... } summing to `total`, never more than
-- MAX_PICKUPS entries, larger values first.
function TokenRules.Split(total: number): { number }
	total = math.max(0, math.floor(total))
	local count = math.min(total, TokenRules.MAX_PICKUPS)
	local out = {}
	if count <= 0 then
		return out
	end
	local each, extra = total // count, total % count
	for i = 1, count do
		out[i] = each + (if i <= extra then 1 else 0)
	end
	return out
end

return TokenRules
