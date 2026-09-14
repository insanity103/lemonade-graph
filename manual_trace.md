
## Manual Trace

Hand-traced findings, kept in `~/lemonade-graph/manual_trace.md` and re-appended after every rebuild (the report generator rewrites this file from scratch). Last verified against the 2026-09-13 sync.

**Open (Research Backlog)**

None remaining. All research gaps resolved or documented from code.

**Resolved (Research)**

12. ~~Common/Uncommon shop sword prices missing.~~ All 19 prices scraped from Restored wiki. Common (Spawn): Bronze (free), Steel (45G), Iron (108G), Gold (210G), Diamond (500G), Dark Axe (1.5K), Serpentine Axe (2.5K), Dragon Axe (4.5K). Uncommon (Spawn): Ice Sword (6.7K), Bone Sword (9.8K), Frostbrand (15.5K). Uncommon (Forest): Scaled Sword (23.1K), Blizzard Striker (45K), Cleaver Blade (65K), Morrow Sword (85.75K), Nefertiti Sword (120.75K), Mythic Sword (162K), Winged Sword (195K), Laser Scythe (235K), Overseer Axe (320K).
13. ~~PvP mechanics unknown.~~ Confirmed nonexistent. Legendary Swords is purely PvE.
14. ~~Arcane Gem earning undocumented.~~ Foregone per user request.
15. ~~Forging system undocumented.~~ Foregone per user request.
16. ~~Source code not available.~~ No public repo. Restored version is decompile-based.
17. ~~Boss HP values missing.~~ 12 bosses scraped. Camp Leader (1.3K) → Dagon (55.3B).
18. ~~Mythical/Eternal drop rates not quantified.~~ Omega 1/55, Mythical 1/150, ETERNAL 1/250. RB25 = 26x multiplier.
19. ~~Rebirth walkspeed undocumented.~~ Toggle exists, maxes at RB25.
20. ~~XP-per-level formula missing from wiki.~~ Found in code: `floor(100 * 1.15^(level-1))`. (`LevelingSystem.server.luau:46`)
21. ~~Rebirth cost formula missing from wiki.~~ Found in code: `20 + 15 * rebirths`. (`RebirthConfig.luau:57`)
22. ~~Settings panel is empty stub.~~ Full settings panel with 3 controls + keyboard shortcuts.
23. ~~Sell button stuck on SELLING.~~ 5s timeout resets stuck button.
24. ~~Dead inventory snapshot pipeline.~~ Removed dead code.

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
12. ~~AudioManager is dead code.~~ Wired into SwordSystem (enemy_hit/crit_hit), EnemyCombat (enemy_death), LevelingSystem (level_up). Module created in ReplicatedStorage with PlaySFX/PlayGlobal API, 11 sound events, MusicVolume support.
13. ~~Quest system double rewards.~~ QuestService.server.luau renamed to .bak. QuestSystem.server.luau is now sole quest script. Eliminates double NPC spawns, double event handlers, and double reward grants.
14. ~~HubLeaderboard unused require.~~ Removed dead `PlayerDataService` require — leaderboard reads `player:GetAttribute("Rebirths")` directly.
15. ~~HUB_FEATURES dead code.~~ Hub scripts (Campfire, Leaderboard, RespecShrine) now read from `WorldLayout.HUB_FEATURES` with hardcoded fallbacks. Table is now the source of truth for hub layout.
16. ~~No onboarding flow.~~ OnboardingGui.client.luau created: welcome overlay (first join), directional arrow to Quest Master, 4 milestone hint toasts (equip sword, find enemies, Q auto-attack, M menu). All client-side, no remotes.
17. ~~Hub is empty.~~ Four hub features built: HubCampfire (fire pit + benches), HubAmbientNPCs (4 wandering villagers), HubLeaderboard (top 10 rebirth pillar), HubRespecShrine (gold-based stat reset). Positions registered in HUB_FEATURES.

**Context**

- Studio's 3D importer rotates imported meshes 180° about Y, so `SwordMeshTemplate` is grip-at−Z. Every placement of it needs `CFrame.Angles(0, math.pi, 0)`; the graph carries this as the "Importer 180 deg Y flip" node.
- `CombatUtil` is the shared server helper module. Lemonade generates scripts independently and may reintroduce local `isEnemy` copies or raw `.Material` writes on sword handles; if so, re-point them at the module rather than re-fixing by hand.
- **Restored wiki is live** at `the-legendary-swords-rpg-restored.fandom.com` (266 pages). Individual sword pages have buy/sell prices. Category pages do not. Original wiki (`the-legendary-swords-rpg.fandom.com`) is HTTP 410 Gone.
- **Legendary Swords is purely PvE.** No PvP system exists in original, LS2, or Restored versions. The Lemonade PvP design should be original, not a port.
- **Drop rates (from Restored wiki):** Omega 1/55, Mythical 1/150, ETERNAL 1/250. Rebirth scaling: numerator becomes (rebirth_level + 1). At RB25: 26/150 for Mythical, 26/250 for ETERNAL. Legendary 1/50, God 1/100 (from LS2 wiki).
- **XP formula (from code):** `XP_required(level) = floor(100 * 1.15^(level-1))`. Level 1→2: 100 XP, Level 10→11: 350 XP, Level 50→51: 57,435 XP. (`LevelingSystem.server.luau:45-46`)
- **Rebirth cost (from code):** `required_level(rebirths) = 20 + 15 * rebirths`. RB0→1: Lv20, RB5→6: Lv95, RB25: Lv395. (`RebirthConfig.luau:56-58`)
- **Gold per kill (from code):** `gold = floor(5 * enemy_level)`. Lv1 enemy: 5G, Lv100 enemy: 500G. (`LevelingSystem.server.luau:107-108`)
- **Combo system (from code):** 5 hits, endlag [0.20, 0.20, 0.35, 0.35, 0.50]s, damage mult [1.0, 1.0, 1.10, 1.15, 1.30]x, hitlag [20-50]ms, reset window 1.5s. (`ComboConfig.luau`)
- **Rebirth 25 is current max.** Rebirth walkspeed is a toggle, maxes at RB25. Rebirth 26 planned. Cost formula undocumented.
- **Area level gates (no rebirths):** Outer Caves (0), Caves (5), Upper Mountain (20), Forest (45), Maxos Temple (100), Legendary Mines (175), Deep Mines (215).
- **Rebirth-gated areas:** RB4 (Tower Roof), RB9 (Sand Dunes), RB16 (OUROBOROS portal), RB22 (Gehenna).
- **Dagon is the strongest boss:** ETERNAL, Level 1,525,000, 55.3B HP, drops Dagon's Lament (1/250). Requires RB20 + Level 880 + hidden puzzle.
- **Map redesign pending integration.** GPT-6 Astra exported Blender geometry to `assets/map_redesign/exports/` (48 GLB files). New hub at (0,6,0) with hub-and-spoke layout. Current WorldLayout.luau uses S-curve at (0,2,-178). Migration path: disable `WorldLayout.EnsureBuilt()`, import meshes via Studio 3D importer, run `InstallMapAnchors.server.luau`. Local spawn offsets match between both systems. Validation: 4/95 checks failed (non-manifold meshes, floor gaps, 2 enemy anchor heights).
