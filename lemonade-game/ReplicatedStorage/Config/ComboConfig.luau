-- ReplicatedStorage/Config/ComboConfig.luau
-- 5-hit M1 combo system constants with escalating endlag per research
-- See: sword-rpg-combat-systems.md, DESIGN_RULES.md rule #6

return {
	-- Combo hit count
	MAX_COMBO = 5,

	-- Endlag per hit (seconds) — hits 1-2 fast, 3-4 medium, 5 heavy recovery
	-- Research: "5-hit M1 combos with escalating endlag (0.2s → 0.5s)"
	ENDLAG = { 0.20, 0.20, 0.35, 0.35, 0.50 },

	-- Damage multiplier per combo hit — later hits deal slightly more
	COMBO_DAMAGE_MULT = { 1.0, 1.0, 1.10, 1.15, 1.30 },

	-- Combo reset window — if no attack within this time, combo resets to 0
	COMBO_RESET_TIME = 1.5, -- [TUNING]

	-- Hitlag duration (seconds) — freeze both attacker + victim briefly
	-- Research: "20-50ms freeze frames — biggest feel-good factor"
	HITLAG_DURATION = { 0.020, 0.025, 0.030, 0.040, 0.050 },

	-- Hitlag scale — brief scale pulse on the enemy model during freeze
	HITLAG_SCALE_MULT = 1.08, -- [TUNING]

	-- Perfect timing bonus — hitting within this window of endlag expiry
	-- Research: "perfect-timing M1 bonus: +5% damage for hitting within 80ms"
	PERFECT_TIMING_WINDOW = 0.080, -- [TUNING] seconds
	PERFECT_TIMING_BONUS = 0.05,   -- [TUNING] +5% damage

	-- Combo HUD display
	HUD_COLORS = {
		Color3.fromRGB(255, 255, 255),  -- Hit 1: white
		Color3.fromRGB(255, 255, 200),  -- Hit 2: warm white
		Color3.fromRGB(255, 200, 80),   -- Hit 3: gold
		Color3.fromRGB(255, 120, 50),   -- Hit 4: orange
		Color3.fromRGB(255, 50, 50),    -- Hit 5: red
	},

	-- Hit-streak banner (HitStreakGui): counts consecutive landed hits for on-screen
	-- feedback, separate from the 5-hit endlag/damage-mult cycle above. Shares the same
	-- reset window as the swing combo so the banner drops exactly when the combo would.
	STREAK_MIN_DISPLAY = 3, -- hits before the banner appears at all
	STREAK_TIERS = {
		{ min = 3,  label = "",         color = Color3.fromRGB(255, 255, 255) },
		{ min = 10, label = "GREAT",    color = Color3.fromRGB(255, 210, 90) },
		{ min = 20, label = "SAVAGE",   color = Color3.fromRGB(255, 140, 60) },
		{ min = 35, label = "BRUTAL",   color = Color3.fromRGB(255, 80, 60) },
		{ min = 50, label = "GODLIKE",  color = Color3.fromRGB(210, 90, 255) },
	},
}
