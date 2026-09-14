return {
	BaseDamage = 30,
	StrengthDamagePerPoint = 5,
	WeaponDamagePerLevel = 0.12,
	AttackCooldown = 0.5,
	HitboxSize = Vector3.new(6, 5, 6),
	HitboxOffset = CFrame.new(0, 0, -3),
	-- Combo system (see ComboConfig.luau for full combo constants)
	ComboEnabled = true,
	ComboResetTime = 1.5, -- seconds of no attack before combo resets
}
