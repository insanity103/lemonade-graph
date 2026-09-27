--// EliteAffixConfig  (pack leaders that roll a trait: Frenzied, Frost-shielded, Vampiric, Juggernaut)
-- Wave 1 of the 2026-09-25 fun plan (Diablo / Path of Exile elite modifiers): cheap variety inside
-- the zones we already have. Rolled by EnemyCombat.spawnEnemy on a pack's leader (PackIndex 1) and
-- on elites, never on a boss or warden. The trait shows as a name prefix in its colour, and the
-- kill pays TOKEN_MULT times the tokens (TokenRules.KillMultiplier reads AffixTokenMult).
local EliteAffixConfig = {}

EliteAffixConfig.CHANCE = { leader = 1 / 6, elite = 1 / 2 } -- [TUNING]
EliteAffixConfig.TOKEN_MULT = 2 -- [TUNING]

EliteAffixConfig.Affixes = {
	-- swings 40% sooner and runs a quarter faster
	{ id = "Frenzied", color = Color3.fromRGB(255, 96, 60), cooldownMult = 0.6, speedMult = 1.25 },
	-- the first 3 hits it takes do nothing (its torso shimmers until the shield breaks)
	{ id = "Frost-shielded", color = Color3.fromRGB(140, 225, 255), shield = 3 },
	-- heals twice the damage it deals
	{ id = "Vampiric", color = Color3.fromRGB(200, 40, 90), lifesteal = 2 },
	-- two and a half times the health, and knockback does not move it
	{ id = "Juggernaut", color = Color3.fromRGB(150, 150, 170), healthMult = 2.5, knockbackImmune = true },
}

EliteAffixConfig.ById = {}
for _, a in ipairs(EliteAffixConfig.Affixes) do EliteAffixConfig.ById[a.id] = a end

-- Which trait (if any) a new rig rolls. roll(): a 0..1 random; pick(n): a random 1..n.
function EliteAffixConfig.Roll(role: string?, packIndex: number?, isBoss: boolean, roll: () -> number, pick: (number) -> number)
	if isBoss or role == "boss" then return nil end
	local chance = if role == "elite" then EliteAffixConfig.CHANCE.elite
		elseif packIndex == 1 then EliteAffixConfig.CHANCE.leader else 0
	if roll() >= chance then return nil end
	return EliteAffixConfig.Affixes[pick(#EliteAffixConfig.Affixes)]
end

return EliteAffixConfig
