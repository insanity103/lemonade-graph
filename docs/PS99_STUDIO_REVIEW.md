# PS99 look pass: Studio review runbook

For the agent (or person) checking the pass on branch `claude/magical-dirac-kww440` (commit
`5082301` and after) inside the real game. The pass was built and validated offline only: Rojo
builds, project checkers, Lune compile and tests all pass, but nobody has seen it rendered. This
runbook is the in-engine half. Read `CLAUDE.md` and `docs/ART_DIRECTION.md` first; the "Status"
section at the end of ART_DIRECTION.md lists exactly what changed.

## Ground rules (from Alex; do not relax them)

- Sync to Studio only through Rojo (`rojo serve`, plugin connect), and only while Alex is at the PC.
  No stand-in HTTP syncs. Ask before restarting Studio.
- After any Rojo reconnect, check for duplicated scripts (`ServerScriptService`, `StarterPlayerScripts`,
  `ReplicatedStorage`): every name once.
- 16 GB machine: never run Blender renders while Studio is open.
- Another session may be editing combat, swing, outfit, NPC-model and animation files. Do not touch
  or commit its work; `git status` before you start and leave its files alone.
- This pass is Colour, Material and visual shape only. Never move spawns, gates, collision proxies
  or anything gameplay reads.
- Validate before every commit: `rojo build map.project.json -o /tmp/lemonade-map.rbxlx &&
  python3 tools/check_map_project.py /tmp/lemonade-map.rbxlx` (exactly four floating palm/runnel
  FAILs already exist; add none) and `rojo build default.project.json -o /tmp/lemonade-gameplay-only.rbxlx
  && python3 tools/check_gameplay_project.py /tmp/lemonade-gameplay-only.rbxlx` (PASS).
- Commit only when Alex asks.

## Setup

```
git fetch origin claude/magical-dirac-kww440
git checkout claude/magical-dirac-kww440
rojo serve map.project.json          # the map project: world + gameplay on the generated map
```
Connect the Rojo plugin in the map place, then check for duplicated scripts. The gameplay-only
project (`default.project.json`) is the regression baseline on the baseplate; it is not the thing to
judge the look in, but it must still run (enemies, swords, GUI all changed there too).

Reference material (local to Alex's PC, not in git):
- PS99 recording: `/home/alex-christensen/Videos/Screencasts/Screencast From 2026-09-18 00-04-38.mp4`
- Clean frames: `~/.local/share/lemonade-gauntlet/ps99style/ref/frames/`
- Palette measurement: `~/.local/share/lemonade-gauntlet/ps99style/cards.py` (saturation spread and
  plastic share for map parts). Target spread 0.22-0.30.
- Capture: `tools/studio_capture.sh OUT.png [DELAY]` grabs the Studio window.

## Captures (in this order)

Set the attribute in edit mode, press Play, wait for the settle, capture, clear the attribute.

| # | What | `workspace:SetAttribute("GuiShowcase", ...)` | Judge against |
|---|------|-----|------|
| 1 | Hub, afternoon | `"WorldDay"` (also `"WorldTown"`, `"WorldWall"`) | a PS99 overworld frame with sky, grass, path and a building |
| 2 | Iron Lowlands desert | `"WorldOasis"` | a PS99 frame with sand/water if one exists, else #1's frame |
| 3 | Briarwood | `"WorldForest"` | a PS99 frame with trees |
| 4 | Enemy in a fight | `"Motion:EnemyAttack"` (also `"Motion:EnemyIdle"`, `"Motion:EnemyDrops"` for the whole roster) | a PS99 frame with a character/pet in view |
| 5 | Sword in hand | `"Motion:SwordGallery"` (whole roster) plus a normal play shot with the Classic Sword equipped | same as #4 |
| 6 | A modal panel | `"Inventory"`, `"Vault"`, `"Shop"` | a PS99 shop/inventory frame |
| 7 | Sunset | `"WorldSunset"` | only if 1-6 pass; the day look is the target |

Each capture is a gauntlet round: a builder takes the matched shot; two fresh, harsh critics see
our frame and the PS99 frame blind, in both A/B orders, and each names the single biggest gap.
Keep going until both critics pick ours. Fix the named gap only; do not re-tune things nobody named.

## What to look at first, per capture

**Sky and light (`lemonade-game/Map/WorldLook.server.luau`, `worldlook-v15`).**
Everything is in the `DAYLIGHT` table (shared by the 08:00 / 11:00 / 15:30 keys) and two toggles:
- `SHADOWS` / `SHADOW_SOFTNESS`: soft cast shadows are on. If shadows read as hard, dark or PBR-real,
  raise softness or the `ambient`/`outdoor` fill before turning them off; if the frame reads flat
  and washed with them off, that is the map pass's known failure, not a win.
- The sky cubemap is Roblox's built-in default (`rbxasset://textures/sky/sky512_*.tex`) under a
  cyan-blue Atmosphere. If the sky is not a clean saturated cyan-blue, tune `atmoColor` /
  `atmoDecay` / `atmoDensity` first; only swap the cubemap if the default's own wisps show through.
- `ccSat` is +0.12. Do not push it back up to fix a dull frame: the palette is already full-chroma,
  a big saturation grade clips the accents and drags the pale tints into one mid-pastel. If the
  frame is dull, the fault is `brightness`/`exposure`/fill, or a part colour.
- Near-white paths and pale sky-blue castle stone must stay pale in sun and go faintly sky-blue in
  shade. If they turn orange or lavender, `top`/`bottom` (ColorShift) are wrong.

**Terrain (`WorldTerrain.server.luau`).** Colours are the map pass's, unchanged. The one thing the
offline renders never showed is Terrain's own material relief (Rock/Slate/Basalt/Asphalt on the rock
skirt). If it reads rough or "real" next to the SmoothPlastic castle, swap the stratum materials in
`stratum()` toward smoother ones (Sand, Salt, Concrete, Limestone, Ice) and keep the colours. Water
is a flat toy cyan with low reflectance.

**Enemies (`ServerScriptService/EnemyCombat.server.luau`, `ReplicatedStorage/EnemyOutfits.luau`).**
Body = one full-chroma plastic per archetype; outfit cloth pale and calm; trims a second pop; every
accessory SmoothPlastic (Neon kept); catalog shirt/pants off (`CLOTHING_TEXTURES = false`). If a rig
reads as one flat vivid block, the calm share is too small: lighten a large cloth piece, not the
body. If it reads pastel/washed, the body colour is not saturated enough. Do not add detail parts:
few large smooth forms.

**Swords (`ServerScriptService/CombatUtil.luau` `applyWeaponAppearance`).** Every held blade should
read as matte plastic: no metal sheen, no baked-noise look, texture still visible on boss meshes. If a
boss mesh still shows PBR sheen, it has a `SurfaceAppearance` with a ColorMap (kept on purpose so the
paint survives); the fix is then in `tools/sword_forge.py`'s export, which this pass deliberately did
not touch. Note which meshes.

**GUI (`ReplicatedStorage/PanelChrome.luau`).** `COLORS` and `build()` are now the bright chrome.
Panels drawing from `COLORS`: AdminGui (dev only), parts of MainMenuGui, SwordHotbarGui stat rows,
enemy nameplates. Check text stays readable on every one (ink on pale, white-with-outline on colour).
`MainMenuGui` keeps its own local dark card palette for some tabs; that is the next GUI piece, not
this review's.

## Reporting

For each capture: the two critics' named gaps per round, what was changed (file + value), and the
round both critics picked ours. Update the "Status" section of `docs/ART_DIRECTION.md` with the
outcome. Anything found that is outside this pass (gameplay, animation, another session's files)
goes in the report, not in the diff.
