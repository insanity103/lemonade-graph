# Prompt: model the Briarwood pool swords in Blender

You are a senior technical artist and Python/Blender engineer working in the `lemonade-graph`
repository (a Roblox sword RPG) on branch `claude/magical-dirac-kww440`. Your task: design, model,
validate and wire in a unique cartoon-plastic mesh for each of the **nine Briarwood pool swords**,
exactly as the Iron Lowlands pool was just done. This file scopes the job; the full brief is
`docs/prompts/pool_swords_blender.md` and every rule in it applies. Where the two disagree, this file
wins for Briarwood.

---------------------------------------------------------------------------------------------------

## 1. Read first, in this order (do not skip any)

1. `CLAUDE.md`.
2. `docs/ART_DIRECTION.md` -- the Pet Simulator 99 plastic-toy language.
3. `docs/prompts/pool_swords_blender.md` -- **the full brief. Read all of it**: sections 3 (layout
   constraints), 4 (art language), 5 (uniqueness criteria and tier budgets), 6 (palette and HSV
   rule), 7 (pipeline and pitfalls), 9 (wiring), 10 (process), 11 (validation), 12 (rules). Your nine
   design briefs are its section 8.7.
4. `docs/BOSS_SWORDS.md` -- the eight signature swords, and the "Pool swords" section at the end.
5. **Look at** `assets/swords/preview.png` (the signature swords -- Grovebound Bloom, the Rootbound
   Warden's relic, is Briarwood's showpiece and must stay the richest Briarwood sword) and
   `assets/swords/pool/preview_IronLowlands.png` (the six finished pool swords -- your quality and
   detail bar; your nine must sit beside them as the same family).
6. `tools/blender_pool_swords.py` -- **the forge already exists and works.** Read every line: the
   `PoolForge` class (`flat()`, `orient()`), the helpers `rim_disc()`, `rod()`, `through_cutter()`,
   the six `design_*` functions for the Iron Lowlands (your worked examples), `pool_checks()`,
   `silhouette()`, and `main()`. Then read `tools/blender_boss_swords.py` for the `Forge` base class,
   `blade_rings`, `stations_from`, `grip_bands`, `guard_bar`, `prong_pair`, `star`, `chaikin`,
   `finish()`, `material()`, and `design_root_warden` (the Rootbound Warden's relic -- borrow its
   leaf/branch/bloom vocabulary without copying its silhouette).

---------------------------------------------------------------------------------------------------

## 2. Scope: the nine Briarwood swords

All in `NormalPools.Briarwood` plus two spin-wheel lists, in `lemonade-game/ReplicatedStorage/
Config/BossWeapons.luau`. The design briefs are in section 8.7 of the full brief (numbers 46-54).

| # | Sword | Mesh key | Tier | Where in the config |
|---|---|---|---|---|
| 46 | Thornwood Dirk | `Sword_ThornwoodDirk` | T1 | `NormalPools.Briarwood.swords` |
| 47 | Sapwood Falchion | `Sword_SapwoodFalchion` | T2 | `NormalPools.Briarwood.swords` |
| 48 | Bramblecut Sabre | `Sword_BramblecutSabre` | T2 | `NormalPools.Briarwood.swords` |
| 49 | Ranger's Longblade | `Sword_RangersLongblade` | T3 | `NormalPools.Briarwood.swords` |
| 50 | Heartwood Broadsword | `Sword_HeartwoodBroadsword` | T3 | `NormalPools.Briarwood.swords` |
| 51 | Briar Billhook | `Sword_BriarBillhook` | T2 | `spinRegulars.Briarwood` |
| 52 | Hedgehog Hooksword | `Sword_HedgehogHooksword` | T3 | `spinRegulars.Briarwood` |
| 53 | Hollowbough Claymore | `Sword_HollowboughClaymore` | T4 | `wardenEpics.Briarwood` |
| 54 | Honeycomb Thorn | `Sword_HoneycombThorn` | T4 | `spinRelics.Briarwood` |

**Out of scope:** Grovebound Bloom (Briarwood's Relic -- it already has the `RootWarden` signature
mesh; do not touch it), every other pool, the eight signature meshes, the template, the six Iron
Lowlands designs, and the shared checks in the forge. Never change any sword's name, `base`,
`weight`, inherents, description, `length` or `material`.

Briarwood's family (full brief section 6): calm `pale_leaf`; accents `lime`, `leaf_bright`,
`timber`, `bloom`. **Use `leaf_bright` (56, 224, 96), never the boss forge's `leaf` (48, 208, 88)**
-- `leaf` fails the HSV rule (value 0.82). The only sanctioned off-family pop is Bramblecut Sabre's
coral raspberries.

---------------------------------------------------------------------------------------------------

## 3. What to build

1. Nine `design_<snake_case_name>(f)` functions in `tools/blender_pool_swords.py`, under a new
   `# ---- Briarwood` banner after the Iron Lowlands block, each with a docstring in the same form as
   the Iron Lowlands ones (the concept, the forms, the calm and vivid slots), returning
   `{"design", "concept", "tier", "calm", "vivid"}`.
2. Nine `DESIGNS` entries: `"Sword_ThornwoodDirk": ("Briarwood", 1, design_thornwood_dirk)`, etc.
3. Build: `python3 tools/blender_pool_swords.py --pool=Briarwood --keep-previews`. It writes
   `assets/swords/pool/Sword_*.glb`, updates `manifest.json`, writes `preview_Briarwood.png` and
   `silhouette_Briarwood.csv`, and exits 0 only when every check passes.
4. Config: for the nine, set `mesh = "<key>"`, remove `textured = false`, remove the Blocks-only
   `accent`, `blade`, `width`, `guard`; keep `color`, `material`, `length`. The `fitLook` fallback is
   already in place -- do not change `BossSwordFactory.luau`.
5. Docs: add a "### Briarwood" table to the "Pool swords" section of `docs/BOSS_SWORDS.md`, in the
   same form as the Iron Lowlands table (sword, key, tier, forms), plus the check summary line.
6. Delete `assets/swords/pool/previews/` before you finish (per-sword renders are working files).

---------------------------------------------------------------------------------------------------

## 4. Traps that were hit building the first 14 swords -- avoid every one

1. **Past the pommel or the tip = the grip slides off the hand.** A pommel's lowest point must be
   exactly at Blender y = -0.5, never beyond. A torus of radius R and tube r centred at `yc` reaches
   `yc - R - r`: two Iron Lowlands pommels overshot by 0.003 on the first try and the check
   `built off-scale` fired. Compute each pommel's extent before placing it.
2. **Spikes, thorns and leaves poking wide.** Nothing outside the guard band may reach |z| > 0.122.
   The Rootbound Warden's thorns and the Frost Revenant's icicles both failed this. Thorns on a
   spine at |z| ~ 0.09 have ~0.03 of room; lean them back toward the pommel and keep them short.
   Hedgehog bristles and Honeycomb cells are the high-risk parts in this pool.
3. **Low-poly curved parts cost MORE after the bevel.** `finish()` bevels every edge whose faces meet
   at > 32 deg. A sphere at 8 x 4 or a torus with tube 6 gets fully bevelled (~3x triangles).
   Spheres at 12 x 6 (or 14 x 7), torus tubes >= 12, lathe rings >= 12 segments: the bevel then
   skips them. Budgets in the brief are post-bevel.
4. **Silhouette collisions.** The IoU check compares side outlines. Two straight double-edged blades
   of similar width collide (Rivetsteel vs Foreman's was 0.92 on the first try; fixed by giving
   Rivetsteel a stepped outline and Foreman's a chisel tip). Toolhouse Cleaver collided with the
   Warden's cleaver at 0.90 (fixed with a neck-to-head flare). Plan the nine outlines on paper
   first so no two share a blade profile: dirk (curved thorn), falchion (S-curve), sabre (curve with
   spine thorns), longblade (straight with a fuller), broadsword (wide), billhook (forward hook),
   hooksword (J hook), claymore (with a hollow), thorn-with-comb. Also check against Grovebound
   Bloom's leaf blade (`RootWarden`) -- a leaf-shaped Briarwood blade is the likeliest collision.
5. **Booleans.** `Forge.cut()` is an exact difference and raises if nothing was cut. The cutter must
   pass fully through (use `through_cutter()` for round holes along X); the cutter's colour paints
   the new walls. `apply_transform()` (or `PoolForge.orient()`) a rotated or moved cutter first.
6. **Faceting.** `finish()` smooth-shades by angle and overrides per-face flags. Use
   `f.flat(obj)` on any part meant to look faceted (bark facets, honeycomb cells).
7. **Tiny slots.** Every colour slot must cover >= 2 % of the sword's surface. A two-bead nose or a
   thin trim in its own colour will fail: fold it into a colour the sword already uses, or make it
   bigger. (Lodestone's amber stone failed this and became lodestone gold.)
8. **Calm share.** Calm >= 20 % of the area. Briarwood's calm tint is only `pale_leaf`; a sword whose
   blade is timber or lime must get its calm area from the grip, guard or a wide pale edge.
9. **Thin decoration mushes.** Anything under 0.014 thick in its thinnest dimension collapses under
   the 0.006 bevel. Leaf blades, bee wings and vine spirals must be >= 0.014 thick.
10. **Do not re-run `tools/blender_boss_swords.py`.** Its output is not byte-stable; a rebuild
    rewrites the committed signature GLBs. If it happens, `git checkout -- assets/swords/` at once.
11. **The segfault at exit is normal.** `bpy` crashes while tearing down; the pool forge exits via
    `os._exit()` with its own status. Trust the printed "all checks passed" and the exit code (0).
12. **Never run Blender while Roblox Studio is open** (16 GB machine).

---------------------------------------------------------------------------------------------------

## 5. Process

1. **Design table first.** Before modelling, write for all nine: blade profile, guard, grip,
   pommel, motif forms, colour slots with rough area split. Confirm no two share a blade profile or
   a guard type, and none resembles Grovebound Bloom.
2. **Build one sword at a time** with `--only=<key>`, fixing every failed check before the next.
3. **Build the pool** with `--pool=Briarwood --keep-previews` and **open and look at**
   `preview_Briarwood.png` and the per-sword renders in `previews/`. For every sword, answer in your
   notes: Can I name the motif from the side view alone, and at a 96 px-tall thumbnail? Does it read
   as its weapon type? Is it chunky and toy-like, or thin and fiddly? One big calm surface plus a
   few strong accents, or a flat pastel blob? Does it belong next to the Iron Lowlands sheet? Is it
   less dressed than Grovebound Bloom? Redesign and rebuild anything that fails. Iterate until every
   sword passes -- the Iron Lowlands took several rounds; expect the same.
4. **Wire and validate** (section 6).

The bar for each motif (from the briefs): the dirk *is* a thorn; the Sapwood Falchion visibly
springs (S-curve) with grain ribs; the Bramblecut Sabre has a row of thorns on its spine and a
raspberry pommel; the Ranger's Longblade has an acorn pommel and a bow-arc guard; the Heartwood
Broadsword shows growth rings and sprouting leaves; the Billhook hooks forward like a beak; the
Hedgehog Hooksword has a bristly hedgehog guard and a snout pommel; the Hollowbough Claymore has a
hollow with two bees on the blade and a honey-drop pommel; the Honeycomb Thorn has a comb of hex
cells wrapped round its lower blade with honey drips. If a motif does not read on the sheet, it is
not done.

---------------------------------------------------------------------------------------------------

## 6. Validation (all must pass)

```
python3 tools/blender_pool_swords.py --pool=Briarwood; echo "exit=$?"          # exit=0, "all checks passed"
python3 tools/blender_pool_swords.py --pool=IronLowlands --no-preview; echo "exit=$?"   # still 0 (you broke nothing shared)
python3 tools/check_sword_glb.py assets/swords/pool/*.glb                       # every line "ok"
git status --short assets/swords/*.glb assets/swords/manifest.json              # prints nothing
tools/install_lune.sh && tests/run.sh --quick                                   # 0 failed
rojo build map.project.json -o /tmp/map.rbxlx && python3 tools/check_map_project.py /tmp/map.rbxlx
    # only the four existing floating palm/runnel FAILs
rojo build default.project.json -o /tmp/g.rbxlx && python3 tools/check_gameplay_project.py /tmp/g.rbxlx   # PASS
```
Also confirm the nine config entries each name a GLB that exists in `assets/swords/pool/`, and that
the config diff touches only those nine `look` tables.

---------------------------------------------------------------------------------------------------

## 7. Rules

- Colour, material and visual shape only. Never touch spawns, gates, drop rates, stats, names or
  anything gameplay reads beyond the nine `look` tables.
- Another session may be editing combat, swing, outfit, NPC-model and animation files: leave them.
- Do not modify the Iron Lowlands designs, the shared checks or thresholds, or the signature meshes.
  If you believe a check is wrong, say so in your report instead of changing it.
- Commit only when Alex asks.

---------------------------------------------------------------------------------------------------

## 8. Report

1. The path to `preview_Briarwood.png`, and for each sword: tier, triangle count, calm/vivid area
   shares, colour slots, and its highest silhouette IoU and against what.
2. Every departure from a section 8.7 brief, and why.
3. Every check that failed along the way and how you fixed it (this feeds the next pool's prompt).
4. The validation output (section 6), verbatim for any failure.
