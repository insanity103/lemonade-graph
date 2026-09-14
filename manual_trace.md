
## Manual Trace

Hand-traced findings, kept in `~/lemonade-graph/manual_trace.md` and re-appended after every rebuild (the report generator rewrites this file from scratch). Last verified against the 2026-09-13 sync.

**Open (Research Backlog — Legendary Swords Wiki Gaps)**

1. **XP curve / max level unconfirmed.** Only inferred as ~900 from a YouTube video title. Requires in-game testing (record XP-per-kill for 20+ level intervals) or YouTube video analysis.
2. **Mythical/Eternal numeric drop rates not quantified.** Only "Very rare" with no numbers. Requires in-game testing or wiki page scraping.
3. **4 event bosses missing HP values** (Dragon Lord, Spectrum Destroyer, Chaotic Alien, Sun God). Requires in-game testing.
4. **Rebirth walkspeed bonus — no data found.** Requires in-game testing at Rebirth 0/1/5/10/15/20/25.

**Resolved (Research)**

12. ~~Common/Uncommon shop sword prices missing.~~ All 19 prices scraped from Restored wiki individual pages. Common: Bronze (free), Steel (45G), Iron (108G), Gold (210G), Diamond (500G), Dark Axe (1.5K), Serpentine Axe (2.5K), Dragon Axe (4.5K). Uncommon Spawn: Ice Sword (6.7K), Bone Sword (9.8K), Frostbrand (15.5K). Uncommon Forest: Scaled Sword (23.1K), Blizzard Striker (45K), Cleaver Blade (65K), Morrow Sword (85.75K), Nefertiti Sword (120.75K), Mythic Sword (162K), Winged Sword (195K), Laser Scythe (235K), Overseer Axe (320K).
13. ~~PvP mechanics unknown.~~ Confirmed nonexistent. Legendary Swords is purely PvE across original, LS2, and Restored versions. No PvP page, arena, toggle, or damage formula exists in any wiki.
14. ~~Arcane Gem earning undocumented.~~ Foregone per user request. No code or wiki source available.
15. ~~Forging system undocumented.~~ Foregone per user request. No code or wiki source available.
16. ~~Source code not available.~~ Restored version is built off a decompile of Terrorbans remaster by @Saltels. No public GitHub repo exists. In-game testing is the only path for remaining gaps (XP curve, boss HP, walkspeed).

**Resolved**

1. ~~The merchant duplicates the boss-sword builder.~~ Already consolidated. `BossSwordFactory.luau` is the shared module. Both `MerchantSystem` and `SwordDropSystem` delegate to it via one-line wrappers (`allowBlessed = false` vs `blessedBonus = ...`). No remaining duplication of `BOSS_WEAPONS` table, `makeBossSword()`, or `RollModifiers`.
2. ~~5-Hit Combo System with Hitlag.~~ Added 5-hit M1 combo system with escalating endlag (0.2s → 0.5s), combo damage scaling (1.0x → 1.3x), hitlag freeze (20-50ms), screen shake, and combo HUD counter. Files modified: `ReplicatedStorage/Config/ComboConfig.luau` (new), `ServerScriptService/SwordSystem.server.luau` (combo tracking + hitlag), `ServerScriptService/CombatUtil.luau` (applyHitlag function), `ServerScriptService/EnemyCombat.server.luau` (unarmed hitlag), `StarterPlayerScripts/CombatController.client.luau` (combo HUD + endlag), `StarterPlayerScripts/ComboVFX.client.luau` (new — screen shake), `StarterPlayerScripts/DamageNumbers.client.luau` (combo multiplier display), `ReplicatedStorage/Config/Sword.luau` (combo enabled flag), `ReplicatedStorage/Animations/Combo Attack Animation.luau` (new — 5 swing variants), `ServerScriptService/RuntimeBootstrap.server.luau` (new remotes). Research basis: sword-rpg-combat-systems.md (Deepwoken parry/block/feint), DESIGN_RULES.md rules #6 and #7. Known limitation: perfect timing bonus (+5% for hitting within 80ms) designed but not yet wired to server validation.
3. ~~Pity System for RNG Drops.~~ Added pity counter to SwordDropSystem. Guaranteed rare drop after 50 + (rebirths × 5) consecutive failures. Files modified: `ServerScriptService/SwordDropSystem.server.luau`. Research basis: sword-rpg-weapon-acquisition.md, DESIGN_RULES.md rule #10.
4. ~~`RebirthResult` is orphaned.~~ `RebirthSystem` fires `RebirthResult(ok, rebirths, requiredLevel)` on both the refusal and success paths, but its only listener was `RebirthGui`, which Lemonade deleted when rebirth moved into `MainMenuGui`. A refused rebirth therefore failed silently. `MainMenuGui` now subscribes to it, stores the last result, and `buildRebirthPanel()` renders it as a status line — green "Rebirth complete" or red "Not yet — level N required" — rebuilding the panel if the Rebirth tab is open when the event arrives.
5. ~~Neon hides the boss-sword texture on tiers 3–5.~~ The imported blade is a textured MeshPart, and `Enum.Material.Neon` renders a flat glow in place of the texture. All three places that dress a boss sword — the boss rig (`EnemyCombat`), the boss drop (`SwordDropSystem.makeBossSword`) and the merchant's copy (`MerchantSystem`) — now route colour/material through `CombatUtil.applyWeaponAppearance()`, which honours Neon on a textured MeshPart as Metal plus a tinted `PointLight` named `BladeGlow`. The artwork survives and the blade still reads as glowing; every other material is applied unchanged, so Metal (Iron Warlord) and Ice (Frost Revenant) are untouched. Behaviour covered by 17 edit-mode checks against the real `SwordMeshTemplate`.
6. ~~`isEnemy()` is defined three times.~~ Now one definition in `ServerScriptService/CombatUtil`, aliased by `EnemyCombat`, `LevelingSystem` and `SwordSystem`. The copies had already drifted: `LevelingSystem`'s lacked the `IsA("Model")` guard and would error when handed a non-Model. A fourth inline variant inside `SwordDropSystem.hook()` was folded in too. `ENEMY_TAG` / `ENEMY_ATTRIBUTE` now come from the module rather than being re-declared per script.
7. ~~Two overlapping melee paths fire on one left-click.~~ Fixed by Lemonade: `CombatController.fireAttack()` calls `tool:Activate()` when a sword is equipped and only fires `EnemyAttack` when unarmed. Both paths share one formula shape (+5/Strength, +12%/weapon level, sword and rebirth multipliers, crit); they differ only in base damage, 30 armed vs 25 unarmed.
8. ~~`blessedBonus` computed but never applied.~~ `RebirthConfig.GetMultipliers()` returned `blessedBonus` but `RebirthSystem.applyRebirthAttributes()` never set it as a player attribute. Now sets `RebirthBlessedBonus` alongside the other milestone perks (knockback, health, crit, range, critDamageMult). `SwordDropSystem` now reads from the attribute instead of hardcoding `rebirths >= 5`.
9. ~~`Items.luau` is a stub registry.~~ Added all 5 boss weapon entries (Boss_Gorgon through Boss_CelestialTitan) with names/descriptions matching `BossWeapons.luau`. Removed dead `ItemsConfig` import from `MainMenuGui.client.luau`.
10. ~~No schema migration or field backfill.~~ `PlayerDataService.Load()` now backfills missing leaderstat and attribute keys from `SaveConfig` defaults after type-guard coercions. Version guard stamps `record.version` when missing or stale. `Apply()` defaults remain as a complementary safety net at the Instance layer.
11. ~~`blessedBonus` hardcoded in SwordDropSystem.~~ Now reads `killer:GetAttribute("RebirthBlessedBonus")` instead of `rebirths >= 5` check, keeping a single source of truth via RebirthSystem.

**Context**

- Studio's 3D importer rotates imported meshes 180° about Y, so `SwordMeshTemplate` is grip-at−Z. Every placement of it needs `CFrame.Angles(0, math.pi, 0)`; the graph carries this as the "Importer 180 deg Y flip" node.
- `CombatUtil` is the shared server helper module. Lemonade generates scripts independently and may reintroduce local `isEnemy` copies or raw `.Material` writes on sword handles; if so, re-point them at the module rather than re-fixing by hand.
- **Restored wiki is live** at `the-legendary-swords-rpg-restored.fandom.com` (266 pages). Individual sword pages have buy/sell prices. Category pages do not. Original wiki (`the-legendary-swords-rpg.fandom.com`) is HTTP 410 Gone.
- **Legendary Swords is purely PvE.** No PvP system exists in original, LS2, or Restored versions. The Lemonade PvP design should be original, not a port.
- **Drop rate formulas (from LS2 wiki):** `1 / (original_drop_chance - rebirth_level)`. At rebirth 25+, all drops become 1/5. Legendary tier: 1/50 base. God tier: 1/100 base.
- **XP formula (from LS2 wiki):** `XP_to_next_level = n^2 + 100n` (level n to n+1). Strength per upgrade point: `(n/10)^2 + 1`.
