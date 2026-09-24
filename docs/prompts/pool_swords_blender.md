# Prompt: model a unique Blender mesh for every pool sword in Lemonade

You are a senior technical artist and Python/Blender engineer working in the `lemonade-graph`
repository (a Roblox sword RPG), on branch `claude/magical-dirac-kww440`. Your job is to design,
model, validate and wire in a unique, hand-designed, cartoon-plastic mesh for each of the 115
"pool swords" -- every sword in the game that does not already have one. This document is your
complete brief. Read all of it before writing any code, then follow it exactly. Where this
document and your instincts disagree, this document wins; where this document is silent, prefer
the choice that makes the sword more readable, chunkier and more like a Pet Simulator 99 toy.

---------------------------------------------------------------------------------------------------

## 0. Read first (in this order)

1. `CLAUDE.md` -- repo conventions.
2. `docs/ART_DIRECTION.md` -- the game's visual language. Especially "The target language".
3. `docs/BOSS_SWORDS.md` -- how the eight existing signature swords were designed, and why.
4. `assets/swords/preview.png` -- LOOK at it. This is the quality and style bar: the five boss
   swords and three warden relics you are joining. Your swords must look like they came out of the
   same toy box, and none may look better-dressed than these eight (they are the showpieces).
5. `tools/blender_boss_swords.py` -- the forge those eight were built with. You will reuse its
   `Forge` class, helpers, `finish()`, `material()`, `check()`, `render_previews()` and
   `contact_sheet()`. Read every function.
6. `tools/check_sword_glb.py` -- the standalone GLB validator your output must pass.
7. `lemonade-game/ReplicatedStorage/Config/BossWeapons.luau` -- the sword definitions. Each
   `sword(name, base, weight, look, inherent, desc)` call is one sword. You will change only the
   `look` table of in-scope swords.
8. `lemonade-game/ServerScriptService/BossSwordFactory.luau` -- `findMesh()` and `fitLook()`,
   which turn a `look` into the sword in the player's hand.
9. `lemonade-game/ServerScriptService/CombatUtil.luau` -- `applyWeaponAppearance()` (forces
   SmoothPlastic at runtime; Neon on a textured mesh becomes a PointLight glow) and
   `SWORD_GRIP_FRAC` (0.38: where the hand sits).

---------------------------------------------------------------------------------------------------

## 1. The problem you are fixing

Today every pool sword reuses one of four shapes and changes only its colour:

- `mesh = "Blocks"` -- the starter sword's 2-3 box parts (blade, guard, grip), recoloured.
- `mesh = "Template"` + `textured = false` -- the bandit falchion, flattened to one solid colour.
- `mesh = "Boss_*"` / warden mesh + `textured = false` -- a boss's sword stripped to one colour.

Result: in the player's hands, ~115 swords collapse to four silhouettes, most of them a single flat
colour. They read as placeholders. A player cannot tell a Rubber Duck Rapier from a Foreman's
Longsword. Each sword must become its own object: its own silhouette, its own guard, grip and
pommel, its own motif, painted in several colours -- recognisably the thing its name and
description say it is, and recognisably from its zone.

---------------------------------------------------------------------------------------------------

## 2. Scope

**In scope (115 swords):** every `sword(...)` in `BossWeapons.luau` EXCEPT the nine below. That is:
the regular swords and Legendaries of the five boss `Pools`, every zone's `NormalPools` swords and
Relic, the `wardenEpics`, the `spinRegulars` and the `spinRelics`. Section 8 lists every one with
its design brief.

**Out of scope -- do not touch their mesh, config or file:**
- The eight signature swords: Warlord Greatsword (`Boss_Gorgon`), Frostfang Cleaver
  (`Boss_FrostRevenant`), Inferno Edge (`Boss_InfernalColossus`), Voidrend Blade
  (`Boss_VoidWraith`), Astral Eclipse (`Boss_CelestialTitan`), Grovebound Bloom (`RootWarden`),
  Drowned Chime (`DrownedBellwarden`), Thunderglass Pane (`TempestWarden`).
- `BossWeapons.Starter` (Classic Sword) and `BossWeapons.Fallback`.
- `assets/swords/SwordMeshTemplate.glb` and every `assets/swords/Boss_*.glb` / warden `.glb`.

**Never change**, for any sword: its name (saved swords resolve by name -- renaming orphans every
copy in a player's vault), `base`, `weight`, the inherent table, the description, `length`, or
`material`. You change the look only.

---------------------------------------------------------------------------------------------------

## 3. Hard technical constraints (the game's weld and grip maths depend on these)

Every mesh uses the same layout as the eight signature swords. Coordinates below are given in
**Blender** space (what your script builds in) and in **glTF / game** space (what the GLB holds).
Blender is Z-up; the glTF exporter with `export_yup=True` maps Blender +Y -> glTF -Z.

| Feature | Blender (build) | glTF / game |
|---|---|---|
| Length axis | Y | Z |
| Tip (blade point) | y = +0.5 exactly | z = -0.5 |
| Pommel end | y = -0.5 exactly | z = +0.5 |
| Crossguard band | y -0.255 .. -0.195 | z 0.195 .. 0.255 |
| Handle / grip band | y -0.46 .. -0.255 | z 0.255 .. 0.46 |
| Where the hand sits | y = -0.38 | z = 0.38 (`SWORD_GRIP_FRAC`) |
| Pommel region | y -0.50 .. about -0.43 | z about 0.43 .. 0.50 |
| Blade root (hidden in guard) | y = -0.21 | z = 0.21 |
| Width axis | Z | Y |
| Thickness axis | X | X |

Rules, all mandatory:

1. **Length exactly 1.0, extremes are tip and pommel.** Nothing may extend past y = +0.5 or
   y = -0.5. `finish()` normalises by the Y extent and re-centres on the bounding box -- if any
   ornament pokes past the pommel or tip, the whole sword is rescaled and shifted and the hand no
   longer sits on the handle. **Add an assertion** that `finish()`'s returned `length_scale` is
   within 1 +- 0.002 and every component of `centre_shift` is within +-0.002. Build the sword at
   true scale so normalisation is a no-op.
2. **The crossguard is the widest feature, at exactly +-0.13 on the width axis (Blender Z), with
   flat end faces.** A flat end survives the bevel unchanged; a point or round end does not. The
   vertices at maximum |width| must lie inside the guard band (the checker allows +-0.03 slack:
   Blender y -0.285 .. -0.165). **Every other part -- blade, spikes, thorns, icicles, ribbons,
   motifs, pommel -- must stay within |z| <= 0.122.** (The eight existing designs failed this
   twice during development: icicles, thorns and a bell lip poked out. Check it.)
3. **Bounding box symmetric about the grip axis.** max(x) = -min(x) and max(z) = -min(z) within
   1e-4. Studio recentres a MeshPart on its bounding box, so an off-centre silhouette puts the hand
   beside the handle. *Asymmetric details are allowed* (a duck's bill on one side, a hooked tip, a
   single thorn) **as long as they stay inside the extremes set by symmetric parts**: the guard sets
   the width extremes, and give every sword a symmetric part that sets the thickness extremes
   (usually the guard or pommel is the thickest thing). Check both.
4. **Blade proportions.** Blade half-width (Blender |z|) between 0.035 and 0.11. Blade
   half-thickness at the root 0.022 .. 0.031, tapering to 0.012 .. 0.016 near the tip. Total
   thickness (x extent) of the whole sword <= 0.13.
5. **Grip.** Radius `GRIP_R` = 0.038 (thick toy handle), may range 0.032 .. 0.042 for character.
   The grip must be a solid, roughly cylindrical form along the axis through the whole grip band --
   the hand welds there. Bands, wraps and rivets on it are fine; do not bend or offset the grip.
6. **Budget.** <= 10,000 triangles and <= 21,000 vertices (Roblox MeshPart limits) -- but see the
   tier budgets in section 5; you should be far under the hard limit.
7. **One mesh, one material, one texture.** The texture is a flat swatch atlas (one solid colour
   cell per colour slot, `Closest` interpolation, every face's UVs at the centre of its cell).
   glTF material: `metallicFactor` 0, `roughnessFactor` 1, no normal, occlusion or
   metallic-roughness maps. `material()` and `read_glb_material()` in the boss forge already do and
   check this -- reuse them.
8. **No transparency.** Roblox ignores it here; "glass", "ice", "jars" and "globes" must read
   through shape and colour (pale tints, a painted shine stripe, open cut-away windows), never
   alpha.
9. **Minimum feature size.** Every form must be at least 0.014 thick in its thinnest dimension, or
   the 0.006 bevel collapses it and it disappears at game scale (a held sword is 3.2-5.0 studs
   long; 0.014 of that is under a tenth of a stud). Thin decoration below this reads as noise.

---------------------------------------------------------------------------------------------------

## 4. The art language (non-negotiable)

The bar is Pet Simulator 99: bright, chunky, high-key, soft-shaded, rounded plastic toys.

**Do:**
- Few, large, smooth, readable forms. A child should be able to name the motif from across a room.
- Chunky everything: thick blades, fat grips, oversized pommels, guards with volume.
- Round every edge with the global bevel (`finish()` does this: width 0.006, 2 segments, 32 deg
  angle limit). Surfaces are smooth-shaded except where a hard crease is the point.
- Detail as **geometry**: raised ribs, boolean holes and notches, added forms (rings, spikes,
  bells, leaves, gems, little characters), stepped profiles, scalloped edges.
- Detail as a **flat two-tone paint split**: the cutting edge as a chamfer strip in an accent
  colour, a colour band across the blade, alternating stripes along the grip. Hard edges between
  colours, never a gradient.
- Charm. Many of these swords are jokes (a rubber duck rapier, a toasted marshmallow brand, bottled
  lightning). Lean in: they are toys.

**Don't:**
- No baked textures of any kind: no noise, scratches, cracks-as-texture, gradients, sparkle, wood
  grain images, painted highlights. The atlas is solid swatches only.
- No PBR: no metal, no roughness variation, no normal maps.
- No realism: no realistic steel, no fine filigree, no engraved script, no thin wire detail.
- No grey, brown, black or muddy colours (see section 6).
- Don't make a sword a straight slab with a bar -- that is exactly what is being replaced.
- Don't copy a signature sword's silhouette. You may echo a boss's motifs in its pool, but a pool
  sword must never be mistakable for Warlord Greatsword, Frostfang Cleaver, Inferno Edge, Voidrend
  Blade, Astral Eclipse, Grovebound Bloom, Drowned Chime or Thunderglass Pane.

---------------------------------------------------------------------------------------------------

## 5. What "unique" means -- measurable acceptance criteria

Every sword must pass ALL of these. Your script enforces the measurable ones and fails loudly.

1. **Forms.** At least 5 distinct forms: blade, guard, grip, pommel, and at least one **motif
   form** that carries the sword's identity (listed per sword in section 8). Tier 3-4 swords have
   2-4 motif forms.
2. **Colours.** At least 3 colour slots, and area shares (computed in Blender from face areas per
   material slot, before the atlas collapse): calm tints >= 20 % of total area, vivid accents
   >= 15 %, and every slot used >= 2 % (a colour you can't see is noise). Log the shares.
3. **Silhouette distinctness.** Rasterise each sword's side silhouette (project every triangle
   onto the Blender Y-Z plane, i.e. glTF Y-Z, fill into a 256 x 1024 binary mask with the length
   filling the height). Compute IoU against **every other sword in the same pool** and against the
   eight signature swords and `SwordMeshTemplate.glb`. Any IoU > 0.85 fails: redesign one of the
   pair (change blade profile, guard shape or pommel -- not just colour). Write the full IoU table
   per pool to `assets/swords/pool/silhouette_<pool>.csv` and report the maximum.
4. **Readability.** At the contact-sheet side view scaled to 96 px tall, the motif must still be
   identifiable. You verify this by looking at the sheet (section 10).
5. **Tiers.** Complexity follows the sword's place in its pool's ladder. Use these budgets:

| Tier | Which swords | Motif forms | Triangles (after the bevel) |
|---|---|---|---|
| T1 | shivs, dirks, daggers, tantos, the pool's cheapest short swords (weight 27-30) | 1 | 1,800-3,200 |
| T2 | falchions, sabres, cutters, mid swords | 1-2 | 2,600-4,800 |
| T3 | longswords, broadswords, claymores, greatswords, estoc, katana, nodachi, rapiers | 2-3 | 3,400-6,000 |
| T4 | Legendaries, Relics, spin relics, warden epics | 3-4 | 3,800-7,000 |

   Counts are measured on the finished mesh: `finish()`'s bevel roughly triples a part's raw
   triangle count (the eight signature swords land at 3,292-5,380 through the same bevel).
   **Low-poly curved parts cost MORE, not less:** the bevel rounds every edge whose faces meet at
   more than 32 deg, so a sphere, ring or cylinder with fewer than 12 segments around gets every
   edge bevelled (~3x). Build curved parts at >= 12 segments around and >= 6 rings (spheres 12 x 6,
   torus tubes >= 12) so the bevel skips them; spend the savings on silhouette.
   T4 swords are the richest pool swords but must stay *visually* below the eight signature swords
   -- judge that on the contact sheet, not by triangle count. If a T4 design starts to outshine its
   boss's sword, simplify.
6. **Weapon type reads.** `length` in the config sets the held size (3.0-5.0 studs); the mesh is
   always 1.0 long with a fixed grip band, so weapon type must read through blade width, profile
   and taper: a shiv is short-looking because its blade is wide at the root and tapers fast to a
   stubby point; a rapier is a thin needle; a claymore is broad and parallel-sided; a katana is a
   long gentle single-edged curve; a cleaver is a rectangle.

---------------------------------------------------------------------------------------------------

## 6. Palette

Colours are sRGB bytes. Use the shared `P` dict in `tools/blender_boss_swords.py`, extended with the
keys below, so every sword, body and outfit comes out of one toy box. Every colour you use must pass
the **HSV rule**: either *calm* (saturation <= 0.22 and value >= 0.90) or *vivid* (saturation
>= 0.60 and value >= 0.85). Your script asserts this for every slot.

**Two existing `P` entries fail the rule; do not use them as-is:**
- `P["magenta"]` = (255, 128, 255) has saturation 0.50 -> use `magenta_hot` = (255, 96, 255).
- `P["leaf"]` = (48, 208, 88) has value 0.82 -> use `leaf_bright` = (56, 224, 96).

Add these keys (all pass):

| Key | RGB | Role |
|---|---|---|
| `magenta_hot` | 255, 96, 255 | Void accent |
| `leaf_bright` | 56, 224, 96 | Briarwood accent |
| `deep_violet` | 96, 32, 224 | Void accent |
| `basalt` | 226, 80, 52 | Caldera rock accent |
| `amber` | 255, 196, 72 | Iron Lowlands glass/lodestone accent |
| `hot_pink` | 255, 96, 150 | Stormwatch pinwheel / rainbow |
| `duck` | 255, 226, 80 | rubber duck yellow |
| `lemon` | 255, 236, 90 | Sunsqueeze lemon |
| `caramel` | 255, 160, 60 | Caramelt |
| `pale_sky` | 214, 238, 255 | Frost calm variant |
| `pale_peach` | 255, 232, 208 | Caldera calm variant |
| `pale_lilac` | 250, 226, 255 | Void calm variant (check: s 0.11) |
| `lime_green` | 150, 255, 96 | Marsh/lily vivid |
| `mint_bright` | 96, 255, 196 | Marsh vivid |

Zone families -- each sword uses its zone's calm tint(s) plus 2-3 of its zone's accents, and may add
**at most one** off-family pop colour if its brief calls for it:

| Zone / pool | Calm | Accents | Motif vocabulary |
|---|---|---|---|
| Boss_Gorgon pool + IronLowlands | `sky_white`, `cream`, `cream_grip` | `coral`, `toy_blue`, `orange`, `gold`, `amber` | quarry tools, picks, rivets, chains, shackles, cart plates, cage bars, banners, amber desert glass, lodestone |
| Boss_FrostRevenant pool + FrostboundGlacier | `ice_white`, `pale_sky`, `white` | `cyan`, `deep_blue` | icicles, antlers, crowns, snow, snowballs, glacier panes, cut gems, rime, aurora |
| Boss_InfernalColossus pool + InfernalCaldera | `cream`, `pale_peach` | `ember_red`, `ember_yellow`, `orange`, `basalt`, `caramel` | flames, furnaces, kilns, crucibles, slag, lava seams, embers, anvils, sparks, campfire treats |
| Boss_VoidWraith pool + VoidRift | `lavender`, `pale_lilac` | `violet`, `deep_violet`, `magenta_hot` | rifts, holes, crescents, eyes, halos, wings, stars, comets, wavy kris edges |
| Boss_CelestialTitan pool + CelestialSummit | `ivory`, `cloud` | `gold`, `tangerine` | suns, halos, stars, rays, clouds, stairs, peaks, origami, lemons |
| Briarwood | `pale_leaf` | `lime`, `leaf_bright`, `timber`, `bloom` | thorns, branches, leaves, bark, acorns, honeycomb, bees, hedgehog bristles |
| SunkenMarsh | `mint` | `aqua`, `aqua_blue`, `lime_yellow`, `lime_green`, `mint_bright` | reeds, bells, oars, lilypads, frogs, ducks, lanterns, river stones, rope |
| Stormwatch | `cloud` | `storm_blue`, `storm_gold`, `storm_deep`, `lightning`, `hot_pink` | lightning, weathervanes, rods, dials, kites, pinwheels, rainbows, bells, telescopes |

Colour composition rules:
- **One calm surface is big.** Usually the blade body OR the grip+guard, never both vivid.
- **The cutting edge is always a chamfer strip in an accent** (the `blade_rings` helper does this:
  body strips vs. edge strips).
- **Grips alternate:** a grip colour plus 2-3 bands of a contrasting colour (`grip_bands`).
- **Each sword's current `color` in the config is its identity colour.** Keep that colour as one of
  its main slots (blade body or the dominant accent), so a player who knew the sword still
  recognises it; build the rest of the palette around it. (Section 8 names the slots.)

---------------------------------------------------------------------------------------------------

## 7. Build pipeline

### 7.1 Environment
```
pip install "bpy==4.2.*" numpy pillow      # Blender as a Python module; CPU Cycles included
python3 tools/blender_boss_swords.py --help  # sanity: the existing forge runs
```
A Draco "library not found" message from the exporter is harmless (compression is not used).
The `bpy` module segfaults while tearing down at interpreter exit, after all work is written; the
pool forge therefore leaves through `os._exit()` with its own status (0 all checks passed, 1 a check
failed, 2 a crash). **Never re-run `tools/blender_boss_swords.py`**: its output is not
byte-stable, so a rebuild rewrites the eight committed signature GLBs with reordered bytes. If you
do by accident, `git checkout -- assets/swords/` before anything else.
**Never run Blender while Roblox Studio is open on this machine** (16 GB RAM; the pair filled
swap before).

### 7.2 Files you create
- `tools/blender_pool_swords.py` -- the pool forge. **It already exists**: the Iron Lowlands pool
  (six swords) was built with it first as the reference implementation. It imports the boss forge
  as a module and adds `PoolForge` (with `flat()` for faceted parts and `orient()`), `rim_disc()`,
  `rod()`, `through_cutter()`, every pool check in this document, the silhouette IoU pass and the
  per-pool contact sheets. Add your pool's design functions and `DESIGNS` entries to it; study the
  six Iron Lowlands designs and `assets/swords/pool/preview_IronLowlands.png` first -- they are the
  worked examples of this brief. Do not change the Iron Lowlands designs or the shared checks.
- `assets/swords/pool/<MeshKey>.glb` -- one per sword.
- `assets/swords/pool/manifest.json` -- per sword: name, mesh key, pool, tier, design name,
  concept one-liner, triangles, vertices, meshSize, palette (slot -> rgb), area share per slot,
  max silhouette IoU and against which sword, checks passed.
- `assets/swords/pool/preview_<Pool>.png` -- one contact sheet per pool (13 sheets).
- `assets/swords/pool/silhouette_<Pool>.csv` -- the IoU tables.

**MeshKey** = `Sword_` + the sword's name in PascalCase with every non-alphanumeric character
removed: "Pit Shiv" -> `Sword_PitShiv`, "Archon's Verdict" -> `Sword_ArchonsVerdict`, "Rubber Duck
Rapier" -> `Sword_RubberDuckRapier`. Section 8 lists every key; use exactly those.

### 7.3 Script shape
- CLI: `python3 tools/blender_pool_swords.py [--pool=Briarwood] [--only=Sword_PitShiv,...]
  [--no-preview] [--keep-previews]`. Default builds everything.
- One design function per sword, `def design_<mesh_key_snake>(f):`, registered in a
  `DESIGNS = { "<MeshKey>": (pool, tier, fn), ... }` table. Each function's docstring states the
  concept in one sentence, the forms, the calm slot and the accent slots -- copy it from section 8
  and keep it true to what you built. Return `{"design": ..., "calm": [...], "vivid": [...]}` like
  the boss designs.
- Share motif builders across swords where the motif genuinely repeats (a `bell()`, `leaf()`,
  `icicle()`, `star_prism()`, `cloud_puff()`, `hex_cell()`, `rivet()`), with parameters, so the
  code stays readable -- but every sword's *combination* must be its own.

### 7.4 Helper behaviours and pitfalls (learned building the first eight -- read carefully)
- `Forge.loft(name, rings, strip_colours, cap_colour)`: `strip_colours` may be a list (one colour per
  ring strip, constant along the length) or a function `(station_index, strip_index) -> colour`
  for bands and splits along the blade. Use the function form for colour bands, hamons, heat
  bands and rainbow stripes.
- `blade_rings(stations, chamfer, double_edged)`: station = `(y, z_back, z_edge, half_thickness)`.
  Single-edged puts the spine at `z_back` and the edge at `z_edge`. Chamfer 0.024-0.032 gives an
  edge strip wide enough to read at game scale; below 0.02 it vanishes.
- `stations_from(fn, n)`: 24-40 stations for a blade; more for wavy blades (one wave needs ~8).
- `Forge.lathe(name, profile[(r, y)], colour, segs)`: revolves around a line parallel to Blender Y.
  To orient a lathed part along another axis, set `rotation_euler` and `location`, then call
  `Forge.apply_transform(obj)` **before** joining or using it as a boolean cutter.
  - Lathe axis Y -> X (a disc facing the viewer from the side, a hole cutter through the flat of the
    blade): `rotation_euler = (0, 0, radians(90))`.
  - Lathe +Y -> -Z (something hanging off the spine), leaning back toward the pommel by `a` deg:
    `rotation_euler = (radians(-(90 + a)), 0, 0)`.
- `Forge.cut(target, cutter)` is an EXACT boolean difference. It recalculates normals on both
  operands first (the builders do not guarantee winding) and **raises if the cut changed nothing**.
  The cutter's colour paints the new inner walls -- use that deliberately (a hole's wall in an accent
  reads as depth). Cutters must pass fully through the target (make them longer than the blade is
  thick).
- `Forge.prism(name, poly_yz, half_x, colour)`: a simple (non-self-intersecting) outline extruded
  along X. `chaikin()` rounds an outline; re-check the widest ends afterwards (rounding pulls tips
  in -- see `rounded_guard` in the legacy `tools/sword_forge.py` for the re-stretch trick).
- `prong_pair()` builds mirrored guard prongs that end in flat faces at exactly +-0.13.
- `finish()`: joins, merges doubles, fixes normals, applies the bevel, runs
  `shade_smooth_by_angle(32 deg)`, writes the swatch UVs, normalises. **`shade_smooth_by_angle`
  overrides any per-face `use_smooth=False` you set earlier.** Faces whose dihedral angle to their
  neighbours is > 32 deg stay crisp anyway (a 6-sided gem does). For deliberately faceted, low-angle
  forms (glacier facets, basalt columns, origami folds, crystal shards), add an optional
  `flat_objects` argument to `finish()` in your pool forge: after smoothing, set
  `use_smooth = False` on the faces that came from those parts (track them by material slot or a
  face attribute before the join).
- The bevel with `use_clamp_overlap` protects thin features, but anything under 0.014 thick still
  mushes (constraint 9).
- `check()` asserts the layout; extend it with: the normalisation no-op (constraint 1), the
  protrusion limit (constraint 2: no vertex outside the guard band with |z| > 0.122), the HSV rule
  per slot, the colour-slot minimum and area shares (section 5.2), and the tier triangle budget.
- The atlas PNG is written by Pillow from sRGB bytes and loaded into Blender as sRGB; do not
  convert. Byte images in Blender store pixels as written.
- Export with `export_apply=True`, `use_selection=True`, `export_yup=True`,
  `export_format="GLB"`, as the boss forge does.

### 7.5 Previews
Use `render_previews()` and `contact_sheet()` from the boss forge unchanged in look: Cycles on CPU,
48 samples with denoising, `Standard` view transform (honest colours; Filmic desaturates), a neutral
near-white world that lights the sword while camera rays see the PS99 sky blue backdrop, one sun
from the camera's upper left, an orthographic side view and a 55 mm three-quarter view aimed with
`look_at()` so the tip is at the top. One sheet per pool, 4 swords per row, each tile labelled with
the sword name, mesh key, tier and its colour chips.

---------------------------------------------------------------------------------------------------

## 8. The 115 design briefs

Format per sword: **Name** -- `MeshKey` -- tier -- identity colour (from the config). Then the
concept, the forms (silhouette / guard / grip / pommel / motif), and the colour slots. The briefs are
specific on purpose, but you are the artist: you may improve a brief if the result reads better and
still honours the name, description, zone and every rule above -- record any change in the design
function's docstring and in your report. You may not drop the motif.

### 8.1 Boss_Gorgon pool -- the Warden of the Pit's armoury (Iron Lowlands quarry gang)
Echo the Warden: toy-blue iron, coral banners, rust-orange rivets, cage bars, chains, shackles.

1. **Pit Shiv** -- `Sword_PitShiv` -- T1 -- sky_white.
   A prisoner's blade ground from a pit shackle. Stubby single-edged blade, wide at the root, with a
   flat oblique chisel tip (ground down). Guard: short toy_blue bar. Grip: cream with a coral rag
   wrap (2 bands). Pommel: an open D-shaped shackle (half torus in the Y-Z plane with a pin bolt
   through its ends) in toy_blue. Motif: the shackle pommel. Slots: blade sky_white, edge orange,
   toy_blue, cream_grip, coral.
2. **Ironjaw Saber** -- `Sword_IronjawSaber` -- T2 -- toy_blue.
   A curved iron saber notched like a jaw. Curved saber; four rounded notches bitten out of the
   cutting edge near the root (boolean cylinders, walls painted coral like gums). Guard: two
   hooked prongs curling toward the blade like an open jaw. Grip: cream with toy_blue bands.
   Pommel: domed rivet head, orange. Slots: blade toy_blue, edge sky_white, coral, cream_grip, orange.
3. **Slag Falchion** -- `Sword_SlagFalchion` -- T2 -- orange.
   A wide slag-forged chopper still warm. Broad falchion widening to a clipped tip. Three
   ember-glowing slag drips: half-spheres fused along the spine, `amber`. Guard: a thick rounded
   crucible-lip bar, toy_blue. Grip: cream with orange bands. Pommel: a lumpy slag nugget
   (flat-shaded icosphere, squashed), amber. Slots: blade orange, edge cream, amber, toy_blue, cream_grip.
4. **Chainbreaker** -- `Sword_Chainbreaker` -- T3 -- sky_white.
   A greatsword that splits chain and cage bar. Broad parallel-sided greatsword with a square-ish
   rounded tip. A broken toy_blue chain link wraps the blade just above the guard (a torus around
   the blade with a boolean gap cut through one side). Guard: a cage-bar crossguard -- flat bar with
   two short vertical bar stubs rising toward the blade on each side. Grip: cream, toy_blue bands.
   Pommel: an orange hex nut (6-segment lathe, flat facets). Slots: sky_white, coral edge,
   toy_blue, orange, cream_grip.
5. **Duneglass Edge** -- `Sword_DuneglassEdge` -- T3 -- amber.
   Amber desert glass honed sun-bright. A faceted glass blade: 8 flat facets (flat-shaded), with a
   raised cream "sun glint" diagonal stripe near the root on each face. Guard: a rolling dune
   shape -- a low sinusoidal wave bar, cream, flat ends. Grip: orange wrap with cream bands. Pommel:
   faceted amber gem (8-segment bipyramid). Slots: amber, cream, orange, toy_blue collar, sky_white edge.
6. **Pit Sovereign** (Legendary) -- `Sword_PitSovereign` -- T4 -- (255, 92, 40) ember orange.
   The Warden's own ember-lit greatsword, king of the pit. Broad greatsword, sky_white body with a
   gold edge and an ember core: a raised coral-orange rib down the centre. Guard: a crown -- flat
   bar with three short gold crown points rising toward the blade from the hub, rivets on its faces.
   A small coral banner (flat pennant, two tails) hangs from the guard hub over the grip's front
   face (stay inside the grip radius + 0.02). Grip: coral with gold bands. Pommel: a gold crown ring
   (5 points around a short cylinder). Must NOT resemble the Warlord cleaver: symmetric tip, no bite.
   Slots: sky_white, gold, coral, (255, 92, 40) ember, toy_blue collar.

### 8.2 Boss_FrostRevenant pool -- the Frost Revenant's armoury
Echo the Revenant: antlers, icicles, a crown, cut ice gems, deep blue cloth.

7. **Rimeguard Shortsword** -- `Sword_RimeguardShortsword` -- T1 -- pale_sky.
   A short frost-rimed guard's blade. Short double-edged leaf blade; three frost nubs (small spheres)
   along each edge near the root. Guard: deep_blue bar with a white snowball on each face. Grip:
   deep_blue, white bands. Pommel: white snowball. Slots: pale_sky, cyan edge, deep_blue, white.
8. **Glacier Falchion** -- `Sword_GlacierFalchion` -- T2 -- cyan.
   Cut from a glacier's clear heart. Falchion with a low-station (flat-shaded) faceted body whose
   facet strips alternate cyan / ice_white; a raised ice_white diamond "clear heart" at mid-blade.
   Guard: two angular shard prongs swept back toward the grip. Grip: ice_white, cyan bands. Pommel:
   hexagonal crystal bipyramid, cyan. Slots: cyan, ice_white, deep_blue collar, white.
9. **Snowdrift Saber** -- `Sword_SnowdriftSaber` -- T2 -- (245, 250, 255) snow white.
   A packed-snow saber that never melts. Curved saber with a lumpy snow cap along the spine
   (a bulging loft riding the back edge, 4 soft lumps). Guard: bar with a snowflake disc (6-point
   star prism) on its centre faces. Grip: deep_blue with white bands. Pommel: snowball with a cyan
   scarf band. Slots: snow white, deep_blue edge, cyan, white.
10. **Hoarwind Claymore** -- `Sword_HoarwindClaymore` -- T3 -- ice_white.
    Hums with the hoar wind. Long claymore with two wind-swirl cutouts (teardrop holes, cyan walls)
    in the blade. Guard: two gust arcs curling toward the blade, flat outer ends. Grip: ice_white
    with three deep_blue bands offset like a spiral. Pommel: a cyan spiral disc (small torus_yz with
    a centre bead). Slots: ice_white, cyan, deep_blue, white.
11. **Permafrost Greatsword** -- `Sword_PermafrostGreatsword` -- T3 -- deep_blue.
    Quenched in ground that never thawed. Massive deep_blue greatsword; its lower third is encased in
    a chunky faceted ice_white frost block (flat-shaded shell around the blade root). Cyan edge.
    Guard: blocky slab with two short icicles hanging toward the grip. Grip: deep_blue with
    ice_white bands. Pommel: bevelled ice cube, ice_white. Slots: deep_blue, ice_white, cyan, white.
12. **Aurora Greatblade** (Legendary) -- `Sword_AuroraGreatblade` -- T4 -- (96, 232, 255).
    Lit from within by the northern lights. Wide ice_white greatblade with three raised wavy aurora
    ribbons running up each face in (96, 232, 255), `aqua` and `violet` (the one sanctioned pop).
    Guard: an antler crown -- 4 tines rising toward the blade on a bar. Grip: deep_blue with cyan
    bands. Pommel: an 8-point star gem, white. Must not echo Frostfang (no icicle teeth, no hook).
    Slots: ice_white, (96, 232, 255), aqua, violet, deep_blue.

### 8.3 Boss_InfernalColossus pool -- the Infernal Colossus's forge
Echo the Colossus: furnace horns, a molten heart, a crucible, cream and ember.

13. **Cinder Shortsword** -- `Sword_CinderShortsword` -- T1 -- ember_red.
    Stubby, still smouldering. Wide rounded-tip blade, ember_red with ember_yellow edge and a short
    raised yellow glow line near the tip. Guard: short cream bar with two smoulder bumps. Grip:
    cream, ember_red bands. Pommel: a smoke puff (three merged spheres), cream.
    Slots: ember_red, ember_yellow, cream, cream_grip.
14. **Magma Falchion** -- `Sword_MagmaFalchion` -- T2 -- (255, 104, 32).
    Cast straight from the caldera's magma. Falchion whose edge carries three hanging magma drips
    (rounded bumps on the edge side) in ember_yellow. Guard: small cream crucible bowl. Grip: cream,
    orange bands. Pommel: a teardrop (lathe) in ember_yellow. Slots: magma orange, ember_yellow,
    cream, pale_peach.
15. **Slagheap Cleaver** -- `Sword_SlagheapCleaver` -- T2 -- cream.
    Struck from the slagheap's crust. Rectangular meat-cleaver silhouette with a squared tip; four
    raised orange crust plates (flat-shaded rounded patches) on each face; a round hang hole near
    the spine top with an orange wall. Guard: thick collar ring + bar, basalt. Grip: orange. Pommel:
    squared lump. Slots: cream, orange, basalt, ember_yellow edge.
16. **Ashen Saber** -- `Sword_AshenSaber` -- T2 -- pale_peach.
    Ash-steel saber with a glowing fuller. A long capsule groove down the blade (boolean), its wall
    ember_red, with a raised ember_yellow rib inside. Guard: an S-guard (one prong curls toward the
    blade, the other toward the grip; point-symmetric, flat ends). Grip: ember_red. Pommel: cream
    sphere with a red ring. Slots: pale_peach, ember_red, ember_yellow, cream.
17. **Vent Sabre** -- `Sword_VentSabre` -- T2 -- (255, 112, 40).
    Tempered in a steam vent. Sabre with three elongated vent slots cut near the root (cream walls)
    and a cream pipe running along the spine. Guard: pipe-elbow bar (cylinders with rounded joints).
    Grip: cream. Pommel: a valve wheel (torus_yz + cross spokes) in ember_red.
    Slots: vent orange, cream, ember_red, ember_yellow edge.
18. **Emberplate Claymore** -- `Sword_EmberplateClaymore` -- T3 -- orange.
    Plated in cooling ember-scale. Cream claymore covered in five rows of raised rounded
    scale-plates (U-shaped prisms) in orange; ember_yellow edge. Guard: two scaled prongs swept
    back. Grip: ember_red. Pommel: orange scale disc. Slots: cream, orange, ember_yellow, ember_red.
19. **Basalt Claymore** -- `Sword_BasaltClaymore` -- T3 -- basalt.
    Heavy as the mountain. Blade with a hexagonal, flat-shaded columnar cross-section in basalt,
    cream "cooled" cap at the tip, and three ember_yellow zigzag crack ribs. Guard: two stacked hex
    columns each side (hex prisms, flat ends). Grip: cream. Pommel: hex column stub.
    Slots: basalt, cream, ember_yellow, pale_peach.
20. **Pyroclast Greatsword** -- `Sword_PyroclastGreatsword` -- T3 -- (255, 80, 30).
    Cooling lava, cracks still glowing. Greatsword, lava orange-red body with a network of 4-5
    raised ember_yellow crack ribs; three small cream rock chunks on the spine. Guard: a volcano --
    trapezoid hub with a crater dish on top of a bar. Grip: cream. Pommel: lava-bomb sphere with
    cream crust caps. Slots: lava red, ember_yellow, cream, basalt.
21. **Colossus Heart** (Legendary) -- `Sword_ColossusHeart` -- T4 -- (255, 170, 40).
    The Colossus's molten heart, hammered into a greatsword. A big ember_yellow heart-shaped gem in
    a cream bezel set at the blade root; blade split in two hard bands along its length (ember_red
    lower, orange upper) with ember_yellow edges. Guard: two cream furnace horns curving toward the
    blade on a bar. Grip: cream with ember_red bands. Pommel: a tiny furnace -- box with a grate
    cut through it, yellow inside. Must not echo Inferno Edge (no waves, no crucible bowl).
    Slots: (255, 170, 40), ember_red, ember_yellow, cream.

### 8.4 Boss_VoidWraith pool -- the Void Archon's armoury
Echo the Archon: halos, wings, rift eyes, crescents, magenta light in lavender and violet.

22. **Rift Dagger** -- `Sword_RiftDagger` -- T1 -- lavender.
    Slips between moments. Very slim straight dagger with one narrow slit through the blade
    (magenta_hot wall). Guard: small crescent (two short prongs curving toward the blade). Grip:
    violet. Pommel: small magenta_hot diamond (4-segment bipyramid).
    Slots: lavender, magenta_hot edge, violet.
23. **Umbral Falchion** -- `Sword_UmbralFalchion` -- T2 -- violet.
    Pressed shadow. Violet falchion with a wide lavender edge band and a hooked notch in the spine.
    A second, slightly larger "shadow" silhouette plate offset behind the blade on each face
    (a thin raised outline). Guard: flat wedge wings. Grip: deep_violet, lavender bands. Pommel:
    crescent moon prism. Slots: violet, lavender, deep_violet, magenta_hot.
24. **Nightfall Kris** -- `Sword_NightfallKris` -- T2 -- violet.
    Wave-edged kris that drinks the last light. Double-edged kris with 7 small waves; lavender
    edges. A magenta_hot star set at the blade root. Guard: symmetric flared wings. Grip:
    deep_violet. Pommel: a curled cap (a hook-shaped lathe cap). Slots: violet, lavender,
    magenta_hot, deep_violet.
25. **Nether Saber** -- `Sword_NetherSaber` -- T2 -- deep_violet.
    Drinks the light around it. Saber with three round holes of decreasing size along the blade
    (magenta_hot walls); lavender edge. Guard: a ring guard (torus_yz around the guard hub) on a bar.
    Grip: violet. Pommel: magenta_hot orb held in a three-prong violet claw.
    Slots: deep_violet, lavender, magenta_hot, violet.
26. **Starless Sabre** -- `Sword_StarlessSabre` -- T2 -- lavender.
    Where no star shows. Lavender sabre with two empty star-shaped holes (5-point star cutters)
    and violet walls; violet edge. Guard: bar with crescent tips. Grip: violet. Pommel: an empty
    ring (torus). Slots: lavender, violet, deep_violet, magenta_hot band.
27. **Collapse Claymore** -- `Sword_CollapseClaymore` -- T3 -- violet.
    Folded around a collapse that never finished. A claymore with a sharply pinched waist at
    mid-length (narrows then widens again), a magenta_hot sphere half-embedded at the pinch.
    Lavender chamfer edges. Guard: two wings folding inward toward the blade. Grip: deep_violet.
    Pommel: a twisted 4-sided cone. Slots: violet, lavender, magenta_hot, deep_violet.
28. **Eventide Claymore** -- `Sword_EventideClaymore` -- T3 -- magenta_hot.
    The colour of the last light before the rift. Three hard colour bands along the blade, root to
    tip: magenta_hot, violet, deep_violet; lavender edges. A raised half-sun disc (magenta_hot with a
    lavender rim) at the blade root. Guard: a flat "horizon" bar, lavender with violet ends. Grip:
    violet. Pommel: half-sun. Slots: magenta_hot, violet, deep_violet, lavender.
29. **Singularity Greatsword** -- `Sword_SingularityGreatsword` -- T3 -- deep_violet.
    A pinpoint of collapsed void at its heart. Greatsword with a big round hole at mid-blade and a
    magenta_hot sphere suspended inside by two thin lavender struts (>= 0.014 thick); a raised
    lavender ring around the hole. Guard: an accretion ring (torus in the Y-Z plane around the
    guard centre) plus a flat-ended bar. Grip: violet. Pommel: magenta_hot orb.
    Slots: deep_violet, lavender, magenta_hot, violet.
30. **Archon's Verdict** (Legendary) -- `Sword_ArchonsVerdict` -- T4 -- (220, 96, 255).
    The Archon's sentence in a single stroke. Tall straight blade (squared-off point, like a
    judge's blade) in lavender with a (220, 96, 255) edge and a violet rune rib; a magenta_hot halo
    (torus_yz) around the upper third. Guard: big two-tier feathered wings (two stacked prongs each
    side). Grip: violet with lavender bands. Pommel: an eye -- lavender sphere with a violet iris
    disc and magenta_hot pupil on each face. Must not echo Voidrend (no crescent, no rift hole).
    Slots: lavender, (220, 96, 255), violet, magenta_hot.

### 8.5 Boss_CelestialTitan pool -- the Celestial Titan's armoury
Echo the Titan: halos, suns, stars, the eclipse, ivory and gold, the Summit's stairs.

31. **Starlight Shortsword** -- `Sword_StarlightShortsword` -- T1 -- (240, 240, 255).
    Carries a little starlight. Short leaf blade with gold edge and a small raised 4-point gold star
    at the root. Guard: small 4-point star with flat arm ends. Grip: ivory, gold bands. Pommel: gold
    5-point star. Slots: starlight white, gold, ivory, tangerine band.
32. **Comet Falchion** -- `Sword_CometFalchion` -- T2 -- (200, 225, 255).
    A comet's tail along the edge. A gold sphere comet head near the tip on the spine side and three
    tapering tail streaks (raised ribs, tangerine / ivory / gold) trailing back toward the guard.
    Guard: swept-back tail prongs. Grip: tangerine. Pommel: small gold sphere.
    Slots: comet blue-white, gold, tangerine, ivory.
33. **Corona Shortsword** -- `Sword_CoronaShortsword` -- T1 -- tangerine.
    Ringed in a thin corona. Short tangerine blade with an ivory ring around it near the root,
    carrying 8 small gold bumps. Guard: a ray bar with 3 short rays each side. Grip: ivory. Pommel:
    sun disc. Slots: tangerine, ivory, gold.
34. **Halo Saber** -- `Sword_HaloSaber` -- T2 -- gold.
    Ringed with a soft halo. Gold saber with an ivory edge and an ivory halo floating around the blade
    at mid-length (torus_yz) on two tiny struts. Guard: small feathered wings, ivory. Grip: ivory
    with gold bands. Pommel: a mini halo ring. Slots: gold, ivory, tangerine collar.
35. **Meridian Blade** -- `Sword_MeridianBlade` -- T3 -- gold.
    Aligned to the sky's meridian. Straight gold blade with a raised ivory meridian ridge. Guard: an
    armillary -- a ring in the Y-Z plane around the guard hub plus a second ring at right angles (in
    the X-Y plane), on a bar. Grip: ivory. Pommel: a small globe with a gold ring.
    Slots: gold, ivory, tangerine.
36. **Zenithguard Blade** -- `Sword_ZenithguardBlade` -- T2 -- ivory.
    The Zenithguard's issue blade, clear as high air. Clean straight ivory blade, gold chamfer edges,
    a tangerine sun emblem (disc + ring) on the blade root faces. Guard: a squared shield-shaped bar
    in gold with tangerine ends. Grip: tangerine, ivory bands. Pommel: an ivory chevron.
    Slots: ivory, gold, tangerine.
37. **Aurelian Claymore** -- `Sword_AurelianClaymore` -- T3 -- tangerine.
    Leafed in gold from the Titan's steps. Tangerine claymore with four rows of raised rounded
    rhombus gold-leaf plates; ivory edge. Guard: stair-stepped bar (three steps up each side).
    Grip: ivory. Pommel: a small stepped ziggurat (three stacked shrinking boxes).
    Slots: tangerine, gold, ivory.
38. **Sunspire Claymore** -- `Sword_SunspireClaymore` -- T3 -- (255, 200, 60).
    Tall and bright as the Summit's spire. Long, narrow, strongly tapering blade with three raised
    ivory spire collars along it. Guard: bar with small cone finials on its faces pointing toward the
    blade. Grip: ivory. Pommel: a tangerine sun sphere in a gold ring.
    Slots: spire gold, ivory, tangerine.
39. **Titanforged Greatsword** -- `Sword_TitanforgedGreatsword` -- T3 -- (240, 244, 255).
    Hammered on the Titan's own anvil. Massive broad greatsword with four flat hammered facets
    (flat-shaded wide bevel) and two raised gold rivet bands across the blade; tangerine edge.
    Guard: an anvil-shaped heavy bar in gold. Grip: tangerine. Pommel: a hammer head set crosswise.
    Slots: titan white, gold, tangerine, ivory.

### 8.6 IronLowlands -- the quarry gang's everyday blades
40. **Quarry Shank** -- `Sword_QuarryShank` -- T1 -- cream.
    A pit tool reground into a blade. Narrow tapering spike with a rectangular cross-section (a
    pickaxe spike), cream, with an orange tip cap. Guard: a pick-head stub -- short orange bar with a
    rounded end each side. Grip: toy_blue tape spiral bands. Pommel: coral cloth knot (two spheres).
    Slots: cream, orange, toy_blue, coral.
41. **Toolhouse Cleaver** -- `Sword_ToolhouseCleaver` -- T2 -- orange.
    Heavy chopper off the toolhouse wall. Rectangular cleaver blade (kept under |z| 0.11) with a hang
    hole in the top corner; sky_white edge strip; toy_blue spine cap. Guard: toy_blue bar. Grip:
    cream with three orange rivets on its faces. Pommel: flat hook ring. Slots: orange, sky_white,
    toy_blue, cream_grip.
42. **Bandit's Machete** -- `Sword_BanditsMachete` -- T2 -- sky_white.
    The quarry's first real sword. Long machete with a slight belly curve, coral edge; a coral
    bandana tied at the guard with two ribbon tails running down the grip's front face. Guard:
    orange bar. Grip: cream, toy_blue bands. Pommel: rounded bird's-head, toy_blue.
    Slots: sky_white, coral, orange, toy_blue, cream_grip.
43. **Rivetsteel Blade** -- `Sword_RivetsteelBlade` -- T2 -- sky_white.
    Riveted from cart plate. A straight blade built from three overlapping plates -- stepped in
    thickness with a visible lip at each joint -- each joint carrying two gold rivets. Coral edge.
    Guard: riveted plate bar, toy_blue. Grip: cream. Pommel: a cart wheel (torus_yz + 4 spokes),
    orange. Slots: sky_white, coral, gold, toy_blue, orange.
44. **Foreman's Longsword** -- `Sword_ForemansLongsword` -- T3 -- toy_blue.
    Kept sharp out of spite. Toy_blue longsword with sky_white edges and a cream measuring-ruler
    fuller (a raised strip with tick notches cut into it). Guard: a set-square bar (angled ends,
    flat). Grip: orange with a coral wrap. Pommel: a pocket watch -- lathe disc, gold rim, cream face.
    Slots: toy_blue, sky_white, cream, gold, orange.
45. **Lodestone Edge** (Relic) -- `Sword_LodestoneEdge` -- T4 -- (255, 220, 72).
    A splinter of the quarry's singing lodestone, edged in gold. Faceted crystal blade (8 flat
    facets) whose facet strips alternate lodestone gold and sky_white. Guard: a coral horseshoe
    magnet opening toward the blade with sky_white pole tips (U-shaped prism, flat outer faces at
    +-0.13). Two small raised music-note shapes (singing) on the blade near the root. Grip: toy_blue.
    Pommel: a small floating stone (flat-shaded icosphere) in a gold ring.
    Slots: lodestone gold, sky_white, coral, toy_blue, gold.

### 8.7 Briarwood -- the grove rangers and the Rootbound Warden
46. **Thornwood Dirk** -- `Sword_ThornwoodDirk` -- T1 -- pale_leaf.
    Cut from a thorn trunk. The blade is one big curved thorn (lofted cone, slight curve), pale_leaf
    with a timber base collar. Guard: a knotted bark bar with two rounded knots, timber. Grip:
    timber, pale_leaf bands. Pommel: a small lime leaf. Slots: pale_leaf, timber, lime.
47. **Sapwood Falchion** -- `Sword_SapwoodFalchion` -- T2 -- lime.
    Springy, light as a branch. Slightly S-curved lime falchion with three raised pale_leaf grain
    ribs following the curve. Guard: two leaf-shaped prongs in leaf_bright. Grip: timber. Pommel: a
    sprout -- two small leaves on a stem. Slots: lime, pale_leaf, leaf_bright, timber.
48. **Bramblecut Sabre** -- `Sword_BramblecutSabre` -- T2 -- leaf_bright.
    Clears bramble by the armful. Sabre with five small timber thorns along the spine; pale_leaf
    edge. Guard: a bar with curling vine prongs. Grip: pale_leaf with a leaf_bright vine spiral.
    Pommel: a raspberry cluster (three small coral spheres -- the one sanctioned pop).
    Slots: leaf_bright, pale_leaf, timber, coral.
49. **Ranger's Longblade** -- `Sword_RangersLongblade` -- T3 -- pale_leaf.
    Standard issue for the grove rangers. Clean pale_leaf longsword with a leaf_bright fuller groove
    (boolean, wall painted) and lime edges. Guard: a bow-shaped arc bar, timber. Grip:
    leaf_bright, pale_leaf bands. Pommel: an acorn (timber cap on a lime nut).
    Slots: pale_leaf, lime, leaf_bright, timber.
50. **Heartwood Broadsword** -- `Sword_HeartwoodBroadsword` -- T3 -- timber.
    Grown, not forged. Timber broadsword with three raised concentric growth-ring arcs (pale_leaf)
    near the root and two small leaf sprouts growing off the spine; leaf_bright edges. Guard: root
    tendrils curling toward the grip. Grip: pale_leaf. Pommel: a tree-ring disc (lathe disc painted
    in concentric timber / pale_leaf rings). Slots: timber, pale_leaf, leaf_bright, lime.
51. **Briar Billhook** -- `Sword_BriarBillhook` -- T2 -- timber.
    A hedge billhook with a thorn for a hilt. Straight blade that hooks forward into a beak at the
    tip; lime edge on the inside of the hook. Guard: timber bar with lime leaf ends. Three small
    lime thorn nubs on the grip. Pommel: a thorn point (cone) in lime. Slots: timber, lime, pale_leaf.
52. **Hedgehog Hooksword** -- `Sword_HedgehogHooksword` -- T3 -- pale_leaf.
    Hooked tip, bristly guard; curls up if you drop it. J-hooked tip, timber edge. Guard: a
    hedgehog -- a dome with ~12 short timber cone bristles radiating (all inside |z| 0.122) on a
    flat-ended bar. Pommel: a hedgehog snout -- a small sphere with a bloom nose bead and two timber
    eye beads. Grip: leaf_bright. Slots: pale_leaf, timber, leaf_bright, bloom.
53. **Hollowbough Claymore** (warden epic) -- `Sword_HollowboughClaymore` -- T4 -- timber.
    Carved from the Root Warden's hollow bough; bees still visit. Timber claymore with a pale_leaf
    heartwood core strip and an oval hollow cut near the root; two bees (bloom capsules with two
    timber stripes and two pale_leaf disc wings) sit on the blade. Guard: a branch with lime leaves
    on its prongs. Grip: timber. Pommel: a honey drop (lathe teardrop), bloom.
    Slots: timber, pale_leaf, bloom, lime.
54. **Honeycomb Thorn** (spin relic) -- `Sword_HoneycombThorn` -- T4 -- (255, 204, 72).
    A thorn the grove bees built a comb around; it drips when it hits. Lower half of the blade
    wrapped in a honeycomb of hexagonal prism cells (each with a shallow hex recess) in bloom; the
    upper half a smooth pale_leaf thorn with lime edges; two bloom honey drips hanging off the comb.
    Guard: bar with hex ends. Grip: timber. Pommel: a honey dipper (grooved sphere, bloom with timber
    bands). Slots: bloom, honey (255, 204, 72), pale_leaf, lime, timber.

### 8.8 FrostboundGlacier -- the glacier's everyday blades
55. **Icicle Shiv** -- `Sword_IcicleShiv` -- T1 -- pale_sky.
    An icicle with a wrapped grip; it does not melt. The blade is a tapering icicle (lathe cone with
    three soft bulges), cyan tip. Guard: a deep_blue wrap-knot bar. Grip: deep_blue cloth with cyan
    spiral bands. Pommel: blunt ice lump, ice_white. Slots: pale_sky, cyan, deep_blue, ice_white.
56. **Snowpack Falchion** -- `Sword_SnowpackFalchion` -- T2 -- (236, 246, 255).
    Pressed snowpack. Falchion outline stepped by three soft snow-layer ledges along the spine; a
    snowball stuck near the tip; cyan edge. Guard: deep_blue bar with snowballs on its faces. Grip:
    deep_blue. Pommel: a little mitten, cyan. Slots: snowpack white, cyan, deep_blue, white.
57. **Frostpane Sabre** -- `Sword_FrostpaneSabre` -- T2 -- cyan.
    Window-clear glacier pane. A cyan sabre framed like a window: a raised ice_white border and two
    crossing mullions dividing the flat into four panes. Guard: a window-sill bar. Grip: ice_white.
    Pommel: a frosted knob. Slots: cyan, ice_white, deep_blue, white.
58. **Glacierrun Longsword** -- `Sword_GlacierrunLongsword` -- T3 -- deep_blue.
    Shaped by meltwater over a winter. Deep_blue longsword with two long wavy raised cyan meltwater
    ribs; ice_white edge. Guard: a curling wave bar. Grip: ice_white. Pommel: a cyan droplet.
    Slots: deep_blue, cyan, ice_white.
59. **Rimecoat Broadsword** -- `Sword_RimecoatBroadsword` -- T3 -- deep_blue.
    Under a permanent coat of rime. Deep_blue broadsword whose edges carry a thick lumpy ice_white
    rime crust; a raised frost fern (central rib + 4 pairs of angled short ribs) on each face.
    Guard: frosted bar with rime bumps. Grip: deep_blue. Pommel: a cyan 6-point snowflake prism.
    Slots: deep_blue, ice_white, cyan.
60. **Blue Hour Shard** (Relic) -- `Sword_BlueHourShard` -- T4 -- (96, 226, 255).
    The one blue hour the glacier lights up. A big faceted crystal shard (flat-shaded), banded root
    to tip in three hard blues: deep_blue, cyan, (96, 226, 255). A raised ice_white crescent moon
    and two small stars on each face. Guard: two crystal shards spreading. Grip: deep_blue. Pommel:
    a faceted cyan gem with a white cap. Slots: (96, 226, 255), cyan, deep_blue, ice_white, white.
61. **Icicle Estoc** (spin regular) -- `Sword_IcicleEstoc` -- T3 -- (200, 236, 255).
    A long thin icicle, straight enough to thrust. Thin diamond-section spike with three frozen-drip
    bulges along its length. Guard: a shallow cup (lathe dish) in deep_blue whose lip is the widest
    point inside the guard band. Grip: cyan. Pommel: a cluster of three small icicle cones,
    ice_white. Slots: estoc ice, deep_blue, cyan, ice_white.
62. **Snowglobe Sabre** (spin relic) -- `Sword_SnowglobeSabre` -- T4 -- (220, 245, 255).
    Shake it and it snows on whoever you hit. Ice_white sabre with a cyan edge and five small raised
    white snowflake dots. At the blade root sits a snowglobe: a sphere (radius <= 0.1) on a deep_blue
    lathe base, with round windows cut through both faces (boolean) showing a tiny leaf_bright tree
    and a white snowman inside. Guard: the globe base on a flat-ended bar. Grip: deep_blue. Pommel:
    a key knob. Slots: globe (220, 245, 255), cyan, deep_blue, leaf_bright, white.

### 8.9 SunkenMarsh -- the marsh folk and the Drowned Bellwarden
63. **Reed Cutter** -- `Sword_ReedCutter` -- T1 -- mint.
    For reed and rope alike. Sickle-ish inner-curved cutter, aqua edge on the inside curve. Grip: a
    bundle of five thin reed cylinders bound by two lime_yellow bands (overall radius ~ GRIP_R).
    Guard: small aqua_blue bar. Pommel: a cattail head (aqua_blue capsule on a stem).
    Slots: mint, aqua, aqua_blue, lime_yellow.
64. **Bogiron Falchion** -- `Sword_BogironFalchion` -- T2 -- aqua_blue.
    Smelted from bog iron, pitted and stubborn. Chunky falchion with five shallow round dimples on
    each face (sphere boolean dents, mint walls); lime_yellow edge. Guard: lumpy bar with two knobs.
    Grip: mint. Pommel: flat-shaded nugget, aqua. Slots: aqua_blue, mint, lime_yellow, aqua.
65. **Silt Sabre** -- `Sword_SiltSabre` -- T2 -- aqua.
    Polished by a century of silt. Smooth sabre painted in three hard wavy silt bands along its
    length (aqua / mint alternating). Guard: a river-stone bar (rounded capsule shapes on its faces).
    Grip: mint. Pommel: a flat river pebble (squashed sphere), mint with an aqua band.
    Slots: aqua, mint, aqua_blue, lime_yellow edge.
66. **Marshlight Longsword** -- `Sword_MarshlightLongsword` -- T3 -- mint.
    Carries a marshlight in the fuller, and leads you home. Mint longsword with a long groove down the
    centre and a lime_yellow orb seated in it near the tip; aqua edges. Guard: a lantern-frame bar
    (bar with a small square frame hub). Grip: aqua_blue. Pommel: a small lantern -- box with four
    posts and a lime_yellow core. Slots: mint, aqua, lime_yellow, aqua_blue.
67. **Bellringer Broadsword** -- `Sword_BellringerBroadsword` -- T3 -- aqua_blue.
    Rings like the sunken bell when it lands. Aqua_blue broadsword with a raised lime_yellow bell
    emblem on the blade root faces; mint edges. Guard: a bell yoke -- a bar arching toward the blade
    with flat ends. Grip: mint. Pommel: a small lathe bell with a clapper ball, lime_yellow.
    Must not echo Drowned Chime (no bell-cup guard). Slots: aqua_blue, mint, lime_yellow, aqua.
68. **Ferryman's Cutlass** (spin regular) -- `Sword_FerrymansCutlass` -- T2 -- mint.
    Still smells a little of river. Broad curved cutlass, lime_yellow edge. Guard: a scallop-shell
    fan (a ribbed fan prism) centred on the guard, flat-ended at +-0.13. Grip: a rope wrap in aqua
    (spiral of torus segments). Pommel: a rope-knot ball, aqua_blue. Slots: mint, lime_yellow,
    aqua, aqua_blue.
69. **Oarblade** (spin regular) -- `Sword_Oarblade` -- T3 -- aqua.
    A flat oar with an edge on it. The blade is an oar: a narrow shaft for the lower half then a wide
    rounded paddle for the tip half; mint rim chamfer as the edge and a painted mint band across the
    paddle. Guard: an aqua_blue oarlock (U-shaped prism opening toward the blade). Grip: mint with an
    aqua_blue band. Pommel: an oar knob sphere, mint. Slots: aqua, mint, aqua_blue.
70. **Frogsong Greatsword** (warden epic) -- `Sword_FrogsongGreatsword` -- T4 -- aqua.
    Croaks a tune; the whole marsh sings back. Aqua greatsword, lime_yellow edges, two raised mint
    music notes on each face. A frog sits on the guard hub at the blade root: lime_yellow squashed
    body, two mint eye spheres with aqua_blue pupils on top, a mouth band -- centred on the axis so it
    reads from both sides. Guard: two lilypad discs (with a notch) on a bar, trimmed flat at +-0.13.
    Grip: aqua_blue. Pommel: a lilypad bud. Slots: aqua, lime_yellow, mint, aqua_blue.
71. **Rubber Duck Rapier** (spin relic) -- `Sword_RubberDuckRapier` -- T4 -- duck.
    Squeaks on every hit; everybody wants it. Thin mint rapier blade with an aqua edge. A rubber
    duck (duck yellow: squashed body sphere, raised tail, head sphere, orange flattened bill, two
    aqua_blue eye beads) sits on the guard facing along the width axis; the bill and tail stay inside
    |z| <= 0.122, and a flat-ended aqua_blue bar under the duck sets +-0.13. Grip: aqua_blue with mint
    bands. Pommel: a tiny duckling head. Slots: duck, orange (pop), mint, aqua, aqua_blue.
72. **Lilypad Lantern** (spin relic) -- `Sword_LilypadLantern` -- T4 -- lime_green.
    A lantern-bright blade that floats. Lime_green blade with mint edges and a lime_yellow glowing
    core rib. Guard: a notched lilypad disc (trimmed flat at +-0.13) with a small bloom-like water
    lily (layered petal star prisms in white and lime_yellow) at the blade root. Grip: aqua_blue.
    Pommel: a ribbed paper lantern (lathe) in lime_yellow with aqua_blue caps.
    Slots: lime_green, mint, lime_yellow, aqua_blue, white.

### 8.10 InfernalCaldera -- the caldera's everyday blades and treats
73. **Emberchip Shiv** -- `Sword_EmberchipShiv` -- T1 -- ember_red.
    A chip of the caldera floor, still warm. Chunky irregular triangular chip blade (flat-shaded
    facets) with an ember_yellow glowing tip facet. Guard: short basalt bar. Grip: cream. Pommel:
    an ember nugget, ember_yellow. Slots: ember_red, ember_yellow, basalt, cream.
74. **Sootglass Falchion** -- `Sword_SootglassFalchion` -- T2 -- cream.
    Glass with smoke trapped inside. A cream "smoky glass" falchion with two spiral raised orange
    smoke-curl ribs and a faceted glassy edge. Guard: a bar of round glass beads. Grip: ember_red.
    Pommel: a smoke puff (three merged spheres), pale_peach. Slots: cream, orange, ember_red, pale_peach.
75. **Clinker Sabre** -- `Sword_ClinkerSabre` -- T2 -- orange.
    Rough clinker with a glowing seam. Orange sabre with a lumpy spine and a low-res flat-shaded
    rough face; a raised ember_yellow seam down the centre; cream edge. Guard: lumpy basalt bar.
    Grip: cream. Pommel: a clinker lump, orange. Slots: orange, ember_yellow, cream, basalt.
76. **Furnace Longsword** -- `Sword_FurnaceLongsword` -- T3 -- (255, 132, 48).
    Never quite finished cooling. Longsword in three hard heat bands root to tip: cream (cooled),
    furnace orange, ember_yellow (hot); ember_red edges. Guard: a furnace grate -- bar with three
    vertical slots cut through (ember_yellow walls). Grip: ember_red. Pommel: little bellows (two
    wedges and a nozzle). Slots: furnace orange, cream, ember_yellow, ember_red.
77. **Caldera Broadsword** -- `Sword_CalderaBroadsword` -- T3 -- basalt.
    A broad slab of caldera rock with a hilt. Wide flat-shaded chunky rock slab; a crater dish
    recess near the root on each face with an ember_yellow lava-pool disc inside; cream crust edges.
    Guard: a rock ridge bar. Grip: cream. Pommel: rock lump, basalt. Slots: basalt, cream, ember_yellow.
78. **First Spark** (Relic) -- `Sword_FirstSpark` -- T4 -- (255, 196, 96).
    The spark the caldera was lit from, kept in a blade. Slender cream blade with ember_red edges; a
    round hole cut through near the root holds a big 4-point ember_yellow spark star whose tips touch
    the rim; three small raised spark diamonds along the blade toward the tip. Guard: flint and steel
    -- two small blocks meeting (orange / basalt). Grip: ember_red with cream bands. Pommel: a match
    head (ember_red capsule on a cream stick end). Slots: cream, ember_red, ember_yellow, spark (255, 196, 96), orange.
79. **Kilnhook Khopesh** (spin regular) -- `Sword_KilnhookKhopesh` -- T3 -- cream.
    The kiln-keepers hook the hot trays out with it. Khopesh: straight near the root, then a big C
    curve; ember_red edge on the outside of the curve; a tray-hook notch at the tip. Guard: a kiln
    brick bar with mortar notches, ember_red. Grip: cream. Pommel: a kiln-shelf peg, orange.
    Slots: cream, ember_red, orange, pale_peach.
80. **Cinderwave Flamberge** (spin regular) -- `Sword_CinderwaveFlamberge` -- T3 -- ember_red.
    Flickers like a heat haze. Narrow flamberge with six small waves -- clearly unlike Inferno Edge's
    three big lobes -- cream edges, and three thin wavy raised orange haze ribs paralleling the edge.
    Guard: flame-tip prongs curling up, ember_yellow. Grip: cream. Pommel: a small flame prism.
    Slots: ember_red, cream, orange, ember_yellow.
81. **Anvilback Chopper** (spin regular) -- `Sword_AnvilbackChopper` -- T3 -- basalt.
    A chopper with an anvil for a spine; mind your toes. Basalt cleaver-ish chopper with a cream
    edge; a gold anvil (horn, body and base in profile) built into the spine near the tip. Guard: a
    mallet-head crossbar (bar with squared, larger ends) in gold. Grip: cream. Pommel: a little
    hammer head set crosswise. Slots: basalt, cream, gold.
82. **Toasted Marshmallow Brand** (spin relic) -- `Sword_ToastedMarshmallowBrand` -- T4 -- (255, 236, 208).
    Golden outside, gooey inside. The blade is a skewer carrying four stacked marshmallows (lathe
    cylinders along the axis, radius ~ 0.06, softly rounded), each with toasted gold / tangerine
    top and bottom rim bands; the skewer's sharpened tip ends exactly at the sword tip. Guard: a
    campfire ring of small orange stones around the skewer on a flat-ended bar. Grip: the skewer
    stick (timber). Pommel: a two-tone flame (ember_yellow / ember_red).
    Slots: marshmallow cream, gold, tangerine, timber, ember_red.
83. **Caramelt Claymore** (spin relic) -- `Sword_CarameltClaymore` -- T4 -- caramel.
    Molten sugar set as hard as basalt; smells like a fair. Caramel claymore with a cream candy edge
    and rounded caramel drips along the edge; a cream frosting ribbon spiralling around the lower
    blade. Guard: a candy-cane striped bar (alternating cream / ember_red paint bands). Grip:
    cream. Pommel: a candy apple (ember_red sphere with a caramel drip ring on a short stick).
    Slots: caramel, cream, ember_red, pale_peach.

### 8.11 Stormwatch -- the observatory and the Tempest Warden
84. **Sparkwire Shiv** -- `Sword_SparkwireShiv` -- T1 -- cloud.
    Coiled sparkwire with an edge and a bite. Short cloud blade with a storm_gold wire coiled around
    it (a helix tube >= 0.014 thick). Guard: a small coil (torus_yz) on a bar. Grip: storm_deep.
    Pommel: a lightning 4-point spark star. Slots: cloud, storm_gold, storm_deep, lightning.
85. **Coppervane Falchion** -- `Sword_CoppervaneFalchion` -- T2 -- storm_gold.
    A copper vane off the observatory roof, re-edged. A falchion that flares into a weathervane
    tail-fin with two notches near the tip; cloud edge. Guard: a compass bar with four ball finials
    on its faces. Grip: storm_deep. Pommel: an arrowhead pointing down. Slots: storm_gold, cloud, storm_deep.
86. **Weathervane Sabre** -- `Sword_WeathervaneSabre` -- T2 -- storm_blue.
    Turns toward the next storm. Storm_blue sabre, cloud edge, an arrow-shaped cutout near the root.
    Guard: a vane arrow -- one end an arrowhead, the other a fletched tail, both trimmed flat at
    +-0.13. Grip: cloud. Pommel: a tiny cup anemometer (three small cups on arms), storm_gold.
    Slots: storm_blue, cloud, storm_gold.
87. **Rodsteel Longsword** -- `Sword_RodsteelLongsword` -- T3 -- cloud.
    Drawn from a lightning rod that has been hit twice. Narrow straight cloud longsword, storm_gold
    edge, two raised lightning-yellow zigzag scorch marks on each face. Guard: a stack of three
    glass-insulator discs, storm_blue, on a bar. Grip: storm_deep. Pommel: an insulator bell, cloud.
    Slots: cloud, storm_gold, lightning, storm_blue, storm_deep.
88. **Observatory Broadsword** -- `Sword_ObservatoryBroadsword` -- T3 -- storm_deep.
    The Observatory's own standard. Storm_deep broadsword with a lightning edge and a raised
    constellation on each face (five cloud dots joined by thin raised lines >= 0.014). Guard: a
    telescope tube crossbar with lens rings, storm_gold (no dome -- that is Thunderglass Pane's).
    Grip: cloud. Pommel: a brass eyepiece, storm_gold. Slots: storm_deep, lightning, cloud, storm_gold.
89. **Barometer Rapier** (spin regular) -- `Sword_BarometerRapier` -- T3 -- storm_blue.
    A brass needle that swings toward low pressure. Thin needle blade, cloud edge. Guard: a round
    barometer dial -- a disc facing the side view with a cloud face, storm_gold rim and a storm_deep
    needle -- on a flat-ended bar. Grip: storm_gold. Pommel: storm_gold knob.
    Slots: storm_blue, cloud, storm_gold, storm_deep.
90. **Gustcutter Gladius** (spin regular) -- `Sword_GustcutterGladius` -- T2 -- cloud.
    Short, wide and quick. Leaf-shaped gladius with a storm_blue edge and three curved raised gust
    swooshes on each face. Guard: a squat oval bar, storm_deep. Grip: ribbed storm_blue. Pommel: a
    big round gladius ball, cloud with a storm_gold band. Slots: cloud, storm_blue, storm_deep, storm_gold.
91. **Weathercock Epee** (spin regular) -- `Sword_WeathercockEpee` -- T3 -- (255, 190, 48).
    Still points into the wind. Thin gold epee. Guard: a flat rooster weathervane silhouette
    (body, tail, lightning-yellow comb) standing on the axis, with a flat-ended storm_deep bar under
    it setting +-0.13. Grip: storm_deep. Pommel: a compass ball with four short arms (N/S/E/W).
    Slots: epee gold, lightning, storm_deep, cloud.
92. **Stormbell Tulwar** (spin regular) -- `Sword_StormbellTulwar` -- T3 -- storm_blue.
    A little storm bell on the pommel. Curved tulwar, cloud edge, a raised cloud emblem (three merged
    discs) at the blade root. Guard: a tulwar crossguard with short langets and ball finials on its
    faces. Grip: cloud. Pommel: a disc pommel with a small lightning-yellow bell hanging on a link.
    Slots: storm_blue, cloud, lightning, storm_gold.
93. **Pinwheel Claymore** (warden epic) -- `Sword_PinwheelClaymore` -- T4 -- hot_pink.
    The Tempest Warden's pinwheel, spun up into a blade. Hot_pink claymore with a cyan edge. At the
    blade root, a big four-vane pinwheel lying in the Y-Z plane (vanes hot_pink / cyan / lightning /
    cloud), radius <= 0.12, with a storm_gold centre pin; a flat-ended bar under it sets +-0.13.
    Grip: cloud with hot_pink bands. Pommel: a storm_gold pin sphere.
    Slots: hot_pink, cyan, lightning, cloud, storm_gold.
94. **Bottled Lightning** (spin relic) -- `Sword_BottledLightning` -- T4 -- lightning.
    A bolt somebody caught in a lemonade jar. The blade is one fat lightning bolt with two zigs --
    clearly unlike Thunderglass Pane's three-zig slab. The guard is the jar: a lathe jar in cloud with
    two painted storm_blue shine stripes and a storm_gold screw lid on the blade side, the bolt
    emerging from the lid; a flat-ended bar under the jar sets +-0.13. Pommel: a lemon slice (disc,
    lightning-yellow segments with a cloud rind ring). Grip: storm_deep.
    Slots: lightning, cloud, storm_blue, storm_gold, storm_deep.
95. **Kitestring Rapier** (spin relic) -- `Sword_KitestringRapier` -- T4 -- (200, 236, 255).
    Flew on a kite through the big storm. A pale rapier with a storm_blue edge; a small diamond kite
    (four triangles painted storm_blue / lightning / hot_pink / cloud) fixed near the tip; a
    storm_gold kite string spiralling down the blade to the guard with three small bow-ties along it.
    Guard: a string spool (lathe spool) on a bar. Grip: cloud. Pommel: a bow-tie knot.
    Slots: kite white, storm_blue, storm_gold, lightning, hot_pink.
96. **Double Rainbow** (spin relic) -- `Sword_DoubleRainbow` -- T4 -- (255, 96, 216).
    Two rainbows after the storm; one came down as a sword. The blade is a rainbow: use a 12-point
    blade ring so each face has 5 strips, painted in bands running the length (coral, orange,
    lightning, lime, cyan, violet across the face). The guard is the second rainbow: a banded
    half-torus arch over the grip top with a cloud puff (merged spheres) at each foot, a hidden
    flat-ended bar setting +-0.13 with the puffs inside |z| 0.122. Grip: cloud with (255, 96, 216)
    bands. Pommel: a cloud puff. Slots: rainbow bands, (255, 96, 216), cloud.

### 8.12 VoidRift -- the rift's everyday blades
97. **Riftsliver** -- `Sword_Riftsliver` -- T1 -- lavender.
    A sliver the rift shed, sharp on every side. A thin rhombus shard blade, double-edged,
    flat-shaded, violet edges. Guard: two small shards as a crossbar, violet. Grip: deep_violet.
    Pommel: a smaller magenta_hot shard. Slots: lavender, violet, deep_violet, magenta_hot.
98. **Hushed Falchion** -- `Sword_HushedFalchion` -- T2 -- violet.
    Makes no sound, not even on impact. Violet falchion, lavender edge, its root wrapped in two
    soft bulging lavender cloth bands (a muffler). Guard: a soft rounded pillow bar, lavender. Grip:
    violet. Pommel: a bell with no clapper (open hollow lathe bell), magenta_hot.
    Slots: violet, lavender, magenta_hot, pale_lilac.
99. **Gloamsteel Sabre** -- `Sword_GloamsteelSabre` -- T2 -- deep_violet.
    Poured in the gloam between two rifts. Deep_violet sabre with magenta_hot edge; its upper part
    poured over in lavender with a wavy hard boundary and two drips (per-station paint). Guard: two
    small rift crescents. Grip: lavender. Pommel: a magenta_hot drop.
    Slots: deep_violet, lavender, magenta_hot.
100. **Nullbrand Longsword** -- `Sword_NullbrandLongsword` -- T3 -- lavender.
    Leaves nothing behind to heal. Lavender longsword with violet edges and a raised violet null
    symbol (ring with a diagonal slash) on the blade root faces. Guard: bar with square hollow frame
    ends. Grip: violet with magenta_hot bands. Pommel: a hollow magenta_hot ring.
    Slots: lavender, violet, magenta_hot.
101. **Riftwalker Broadsword** -- `Sword_RiftwalkerBroadsword` -- T3 -- violet.
    Collapsed rift-glass, heavy as a door. Wide violet broadsword with flat-shaded glassy facets,
    lavender edge, and a raised door-panel outline with a magenta_hot knob on each face near the
    root. Guard: a door-hinge bar (bar with two hinge cylinders), lavender. Grip: deep_violet.
    Pommel: a keyhole plate (disc with a keyhole cut through), lavender.
    Slots: violet, lavender, magenta_hot, deep_violet.
102. **Quiet Star** (Relic) -- `Sword_QuietStar` -- T4 -- (230, 100, 255).
    A star that fell through the rift and stopped shining. (230, 100, 255) blade with lavender edges.
    A big lavender 5-point star with a sleepy face (two closed-eye arcs and a small mouth, violet,
    raised) set at the blade root inside a magenta_hot rift ring (torus_yz); two small trailing
    stars down the blade. Guard: a crescent-moon bar. Grip: deep_violet. Pommel: a small star.
    Slots: (230, 100, 255), lavender, violet, magenta_hot, deep_violet.
103. **Hushfang Kris** (spin regular) -- `Sword_HushfangKris` -- T2 -- violet.
    A wavy kris that bites without a sound. Five waves and a curved fang-shaped tip (distinct from
    Nightfall Kris's seven even waves); magenta_hot edge; two small lavender fang teeth on the guard
    pointing toward the blade. Grip: lavender. Pommel: a curved fang cone, lavender.
    Slots: violet, magenta_hot, lavender.
104. **Gloam Tanto** (spin regular) -- `Sword_GloamTanto` -- T1 -- deep_violet.
    Short and straight, drawn from the gloam. Tanto with an angled chisel tip; lavender edge. Guard:
    a round tsuba disc (lathe, rim at exactly r = 0.13 inside the guard band; confirm the checker
    passes after the bevel) in magenta_hot with two crescent cut-outs. Grip: lavender with raised
    violet diamond wrap. Pommel: a kashira cap, violet. Slots: deep_violet, lavender, magenta_hot, violet.
105. **Wishbone Comet** (spin relic) -- `Sword_WishboneComet` -- T4 -- pale_lilac.
    A comet split like a wishbone; you got the bigger half. The blade forks at mid-length into a Y:
    the bigger tine carries on to the tip, a smaller tine branches off and ends short. Magenta_hot
    edges. A magenta_hot comet head at the fork with three lavender tail streaks. Guard: a bar with
    wishbone knob ends. Grip: violet. Pommel: a comet sphere with a cone tail.
    Slots: pale_lilac, magenta_hot, lavender, violet.

### 8.13 CelestialSummit -- the Summit's everyday blades
106. **Sunmote Shiv** -- `Sword_SunmoteShiv` -- T1 -- (255, 240, 206).
    A mote of the Summit's light, small and very hot. Short leaf blade with a gold edge and a
    tangerine hot dot half-embedded at the root. Guard: a small ray bar (three short rays each side).
    Grip: gold. Pommel: a tangerine sun sphere. Slots: sunmote cream, gold, tangerine.
107. **Cloudcut Falchion** -- `Sword_CloudcutFalchion` -- T2 -- cloud.
    Cut from the cloud deck below the peak. A falchion whose spine is a row of five round cloud
    bumps (scalloped); gold edge. Guard: cloud puffs on a flat-ended bar. Grip: tangerine. Pommel:
    a cloud puff. Slots: cloud, gold, tangerine, ivory.
108. **Zenith Sabre** -- `Sword_ZenithSabre` -- T2 -- gold.
    Aligned to the sun at its highest. Gold sabre, ivory edge, with a raised ivory sundial gnomon
    fin rising off the spine near the root. Guard: a straight bar with a tangerine sun disc at its
    centre. Grip: ivory. Pommel: a sundial disc. Slots: gold, ivory, tangerine.
109. **Daybreak Longsword** -- `Sword_DaybreakLongsword` -- T3 -- tangerine.
    The colour of the first minute of light. Tangerine longsword with ivory edges; a gold half-sun
    with five raised rays climbing the blade root. Guard: a flat horizon bar, ivory with gold ends.
    Grip: gold. Pommel: a half-sun. Slots: tangerine, ivory, gold.
110. **Summitward Broadsword** -- `Sword_SummitwardBroadsword` -- T3 -- (240, 244, 255).
    Carried up the last stair of the Summit. Broadsword whose root shoulders are stepped like a
    stair (three steps each side); gold edge. Guard: a stepped bar. Grip: tangerine. Pommel: a
    mountain peak (triangle prism) with an ivory snowcap on gold. Slots: summit white, gold, tangerine, ivory.
111. **Little Dawn** (Relic) -- `Sword_LittleDawn` -- T4 -- (255, 232, 72).
    Not the Titan's sun: a small, stubborn dawn of your own. Sunny blade with ivory edges; a small
    smiling sun set at the blade root (ivory face, tangerine rim, eight short rounded rays, raised
    tangerine eye dots and smile). No halo ring (that is Astral Eclipse's). Guard: two small cloud
    puffs on a bar. Grip: ivory with gold bands. Pommel: a small rising half-sun.
    Slots: (255, 232, 72), ivory, tangerine, gold, cloud.
112. **Cloudstep Katana** (spin regular) -- `Sword_CloudstepKatana` -- T3 -- (240, 244, 255).
    Light enough to carry up every stair. Gently curved single-edged katana with a gold hamon (the
    edge band painted with a wavy hard boundary via the per-station paint function). Round tsuba
    (as Gloam Tanto's rules) in tangerine with three small round cloud cut-outs. Grip: ivory with a
    gold diamond wrap. Pommel: a gold kashira cap. Must read unlike Gloam Tanto: long curve vs short
    straight chisel. Slots: katana white, gold, tangerine, ivory.
113. **Highwind Nodachi** (spin regular) -- `Sword_HighwindNodachi` -- T3 -- ivory.
    A very long blade for the very high wind. A long narrow curved nodachi with a tangerine edge;
    two tangerine ribbons tied at the guard streaming up along the blade (flat strips >= 0.014
    thick, inside the width limit). Square tsuba in gold. Grip: ivory with gold bands. Pommel: gold
    cap with a small two-cone tassel. Slots: ivory, tangerine, gold.
114. **Origami Crane Blade** (spin relic) -- `Sword_OrigamiCraneBlade` -- T4 -- (255, 250, 235).
    A thousand folds, one edge. The whole sword is flat-shaded like folded paper: a diamond-section
    blade with crisp folds whose valley faces are painted cloud against the paper white. A tangerine
    origami crane (diamond body, two wings, neck and tail spikes, all flat facets) perched on the
    guard hub. Guard: a pleated fan bar (zigzag folds) in gold. Grip: ivory. Pommel: a low-poly
    paper ball, gold. Slots: paper white, cloud, tangerine, gold.
115. **Sunsqueeze Blade** (spin relic) -- `Sword_SunsqueezeBlade` -- T4 -- lemon.
    Squeezed from the first sun over the Summit, like the best lemon in the bowl -- Lemonade's own
    sword. Lemon blade with an ivory pith edge and a raised juice drop near the tip. The guard is a
    halved lemon: a lathe dome with its cut face toward the blade showing eight segments painted
    lemon / ivory with a pith ring, ringed by six short gold sun rays, on a flat-ended bar. Grip:
    tangerine with ivory bands. Pommel: a whole mini lemon (lathe ellipsoid with end nubs), gold,
    with a lime leaf (the one pop). Slots: lemon, ivory, gold, tangerine, lime.

---------------------------------------------------------------------------------------------------

## 9. Wiring them into the game

### 9.1 Config (`lemonade-game/ReplicatedStorage/Config/BossWeapons.luau`)
For each of the 115 in-scope swords, edit only its `look` table:
- set `mesh = "<MeshKey>"`;
- remove `textured = false` (the new mesh's painted texture must show);
- remove the Blocks-only fields `accent`, `blade`, `width`, `guard`;
- keep `color` (it is the fallback tint while the mesh is not imported, and older saves read it),
  `material` and `length` exactly as they are.

Example (Pit Shiv), before:
```lua
sword("Pit Shiv", 1.30, 30, { mesh = "Blocks", color = rgb(232, 240, 255), material = Metal, accent = rgb(255, 140, 40), length = 3.4, blade = 0.75, width = 0.8, guard = 0.8 },
```
after:
```lua
sword("Pit Shiv", 1.30, 30, { mesh = "Sword_PitShiv", color = rgb(232, 240, 255), material = Metal, length = 3.4 },
```
Edit with a script that parses each `sword(...)` call and asserts every one of the 115 names was
found exactly once and nothing else in the file changed (diff the file with the look tables
masked). Update the comment above `local function sword` to describe the new `Sword_*` meshes.

### 9.2 Fallback (`lemonade-game/ServerScriptService/BossSwordFactory.luau`, `fitLook`)
Until each new mesh is imported into Studio, `findMesh()` falls back to `SwordMeshTemplate`, whose
painted texture would hide the sword's own `color`. Make the fallback strip the texture so the sword
shows its colour on the template shape instead:
```lua
local function fitLook(tool, look)
	look = look or BossWeapons.Fallback.look
	local mesh = findMesh(look)
	-- A named mesh that is not imported yet falls back to the shared template; that template's
	-- painted texture would hide this sword's own colour, so strip it like a textured = false look.
	local fellBack = mesh ~= nil and look.mesh ~= nil and look.mesh ~= "Template" and look.mesh ~= "Blocks"
		and mesh.Name ~= look.mesh
	local stripTexture = look.textured == false or fellBack
	...
```
and use `stripTexture` in the two places that currently test `look.textured == false`. Change
nothing else in gameplay code. Another session may be editing combat, swing, outfit, NPC-model and
animation files; do not touch them.

### 9.3 Import (done by Alex in Studio afterwards -- document it, don't do it)
In `docs/BOSS_SWORDS.md` add a "Pool swords" section: one line per sword (key, concept, forms), and
the import steps: File > Import 3D each `assets/swords/pool/*.glb`, name each MeshPart exactly its
key, put all of them in `ServerStorage/BossSwordMeshes`; confirm each is a plain MeshPart with a
TextureID and no SurfaceAppearance, MeshSize roughly (0.05-0.13, 0.26, 1.0). Then capture
`workspace:SetAttribute("GuiShowcase", "Motion:SwordGallery")` to see all of them through the real
factory. Note in the doc that the gallery stage's grid spacing was tuned for thin blades and may
need widening.

---------------------------------------------------------------------------------------------------

## 10. Process: one pool at a time, with a self-review loop

Do not generate all 115 in one unverified pass. For each of the 13 pools, in the order of section 8:

1. **Design table.** Write the pool's section into `docs/BOSS_SWORDS.md` first: per sword, the
   blade profile, guard, grip, pommel, motif forms and slots. Check the table for repeats within
   the pool (two swords with the same blade profile AND guard type is a repeat -- change one).
2. **Build** the pool's design functions; run `--pool=<Pool>`.
3. **Automated checks** (all must pass, else fix and rebuild): layout, normalisation no-op,
   protrusion limit, HSV per slot, >= 3 slots, area shares, tier triangle budget, silhouette IoU
   <= 0.85 within the pool and against the signatures and template, `check_sword_glb.py`.
4. **Look at the contact sheet** (open the PNG and actually view it). For each sword answer, in
   writing in your working notes:
   - Can I name the motif from the side view alone? From the 96 px thumbnail?
   - Does it read as its weapon type (shiv vs claymore vs rapier vs cleaver)?
   - Is it chunky and toy-like, or thin and fiddly? Any form that looks like a sliver or noise?
   - Is there one big calm surface and a few strong accents, or is it a flat mid-pastel blob, or a
     clown-coloured mess? Is any colour off-family without the brief sanctioning it?
   - Does it look like it belongs next to its boss's sword on `assets/swords/preview.png`? Is it
     accidentally better-dressed than that boss sword?
   - Does anything poke out asymmetrically so the grip would sit off-centre?
   Redesign anything that fails and re-render. Iterate until every sword on the sheet passes.
5. **Commit nothing**; move to the next pool.

After all 13 pools: rebuild everything from clean (`rm -rf assets/swords/pool && python3
tools/blender_pool_swords.py`) and confirm the output is deterministic in *geometry*: rebuild again
and compare each GLB's sorted triangle corner positions (rounded to 1e-5). Bytes are NOT stable
between runs -- Blender's exporter/bevel can reorder vertices -- so do not compare file hashes.

---------------------------------------------------------------------------------------------------

## 11. Validation (all must pass before you report)

```
python3 tools/check_sword_glb.py assets/swords/*.glb assets/swords/pool/*.glb     # every file ok
git status --short assets/swords/*.glb assets/swords/manifest.json   # signatures untouched: must print nothing
tools/install_lune.sh && tests/run.sh --quick                                    # 44+ passed, 0 failed
rojo build map.project.json -o /tmp/map.rbxlx && python3 tools/check_map_project.py /tmp/map.rbxlx
    # only the four existing floating palm/runnel FAILs
rojo build default.project.json -o /tmp/g.rbxlx && python3 tools/check_gameplay_project.py /tmp/g.rbxlx
    # PASS
```
Also compile every edited Luau file (Lune's `luau.compile`, as `tests/` does) and confirm the 115
names in the config each point at a GLB that exists in `assets/swords/pool/`.

---------------------------------------------------------------------------------------------------

## 12. Rules

- Never run Blender while Roblox Studio is open.
- Don't regenerate or edit the eight signature meshes or the template; don't rename any sword.
- Colour, material and visual shape only; never touch spawns, gates, drop rates, stats or anything
  gameplay reads beyond the `look` tables and the one `fitLook` fallback.
- Don't touch another session's combat, swing, outfit, NPC-model or animation work.
- Commit only when Alex asks.

---------------------------------------------------------------------------------------------------

## 13. Report

When done, report:
1. Per pool: the contact sheet path, each sword with tier, triangle count, colour slots and area
   shares, and the pool's highest silhouette IoU pair.
2. Every place you departed from a brief in section 8, and why.
3. Any sword you could not make distinct within the rules, and what blocked it.
4. The validation output (section 11), verbatim for failures.
5. Exactly what Alex needs to do in Studio next.
