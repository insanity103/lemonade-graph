return {
	BaseDamage = 30,
	StrengthDamagePerPoint = 5,
	WeaponDamagePerLevel = 0.12,
	AttackCooldown = 0.5,
	-- Dead. The hitbox is no longer a fixed box in front of the player's feet: SwordSystem
	-- derives it from the swing clip itself (ReplicatedStorage/SwingBlade), which is where the
	-- blade actually is on the animation's contact frame. Left here only so a saved place or a
	-- tool that still reads them does not error; nothing in the tree reads them any more.
	HitboxSize = Vector3.new(6, 5, 6),
	HitboxOffset = CFrame.new(0, 0, -3),
	-- Combo system (see ComboConfig.luau for full combo constants)
	ComboEnabled = true,
	ComboResetTime = 1.5, -- seconds of no attack before combo resets
}
