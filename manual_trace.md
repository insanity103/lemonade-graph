
## Manual Trace

Hand-traced findings, kept in `~/lemonade-graph/manual_trace.md` and re-appended after every rebuild (the report generator rewrites this file from scratch). Last verified against the 2026-09-10 sync.

**Open**

1. **The merchant duplicates the boss-sword builder.** `MerchantSystem` carries its own copy of `SwordDropSystem`'s `BOSS_WEAPONS` table and of `makeBossSword()` (rename, stat attributes, modifier prefixes, retint, SwordClient copy). The copy had already inherited the Neon texture bug below and needed the same fix separately. Any change to a boss weapon's stats or appearance must currently be made in both files. Candidate for moving into a shared module alongside `CombatUtil`.

**Resolved**

2. ~~`RebirthResult` is orphaned.~~ `RebirthSystem` fires `RebirthResult(ok, rebirths, requiredLevel)` on both the refusal and success paths, but its only listener was `RebirthGui`, which Lemonade deleted when rebirth moved into `MainMenuGui`. A refused rebirth therefore failed silently. `MainMenuGui` now subscribes to it, stores the last result, and `buildRebirthPanel()` renders it as a status line — green "Rebirth complete" or red "Not yet — level N required" — rebuilding the panel if the Rebirth tab is open when the event arrives.
3. ~~Neon hides the boss-sword texture on tiers 3–5.~~ The imported blade is a textured MeshPart, and `Enum.Material.Neon` renders a flat glow in place of the texture. All three places that dress a boss sword — the boss rig (`EnemyCombat`), the boss drop (`SwordDropSystem.makeBossSword`) and the merchant's copy (`MerchantSystem`) — now route colour/material through `CombatUtil.applyWeaponAppearance()`, which honours Neon on a textured MeshPart as Metal plus a tinted `PointLight` named `BladeGlow`. The artwork survives and the blade still reads as glowing; every other material is applied unchanged, so Metal (Iron Warlord) and Ice (Frost Revenant) are untouched. Behaviour covered by 17 edit-mode checks against the real `SwordMeshTemplate`.
4. ~~`isEnemy()` is defined three times.~~ Now one definition in `ServerScriptService/CombatUtil`, aliased by `EnemyCombat`, `LevelingSystem` and `SwordSystem`. The copies had already drifted: `LevelingSystem`'s lacked the `IsA("Model")` guard and would error when handed a non-Model. A fourth inline variant inside `SwordDropSystem.hook()` was folded in too. `ENEMY_TAG` / `ENEMY_ATTRIBUTE` now come from the module rather than being re-declared per script.
5. ~~Two overlapping melee paths fire on one left-click.~~ Fixed by Lemonade: `CombatController.fireAttack()` calls `tool:Activate()` when a sword is equipped and only fires `EnemyAttack` when unarmed. Both paths share one formula shape (+5/Strength, +12%/weapon level, sword and rebirth multipliers, crit); they differ only in base damage, 30 armed vs 25 unarmed.

**Context**

- Studio's 3D importer rotates imported meshes 180° about Y, so `SwordMeshTemplate` is grip-at−Z. Every placement of it needs `CFrame.Angles(0, math.pi, 0)`; the graph carries this as the "Importer 180 deg Y flip" node.
- `CombatUtil` is the shared server helper module. Lemonade generates scripts independently and may reintroduce local `isEnemy` copies or raw `.Material` writes on sword handles; if so, re-point them at the module rather than re-fixing by hand.
