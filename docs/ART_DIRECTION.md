# Art direction: one cartoon language across the whole game

Status: rules doc, 2026-09-21. Written from an audit of the game as it ships today
(commit `11f0956`) plus Pet Simulator 99 as the cartoon bar (Adopt Me! was tried and
dropped: the only clip available was cluttered with an unrelated streamer's overlay).
Nothing in this document is built yet; it is what every later visual piece is judged against.

## Why this exists

Earlier passes built and polished the world, the GUI, the sword models and the
character rigs one at a time, each judged only against its own bar (Arcane Odyssey for
the world, Pet Simulator 99 for GUI motion, Anime Adventures for the reforge menu's
chrome). Each piece won its own comparison. Put side by side, they clash. The rules
below exist so the next pass has one standard, not four.

## Current state (the audit)

- **World/terrain**: bright, high-saturation storybook palette (saturated grass green,
  flat blue sky, warm sandstone), soft matte shading, low-to-mid poly cartoon shapes
  (broccoli-cluster trees, faceted rock spires), primitive-built props. This is already
  close to the target and is the anchor the rest should match, not the thing that changes.
- **GUI chrome** (`ReplicatedStorage/PanelChrome.luau`): a dark-charcoal, gold-and-ember
  "fantasy gacha" palette (Panel `RGB(18,18,22)`, Gold `RGB(255,215,60)`,
  `Font.Fantasy` titles) that the reforge-menu pass deliberately pushed further toward,
  to beat Anime Adventures on "expensive chrome." That direction is now the wrong one:
  dark and gold reads nothing like the bright world it sits on top of.
- **Sword models** (`tools/sword_forge.py`): genuine PBR (metallic 0.6, roughness 0.45),
  baked noise/crack/sparkle JPEG textures, painterly jewel-tone themes per element. The
  most photoreal-leaning asset in the game by a wide margin.
- **Characters/enemies**: two different pipelines. NPCs are custom prebuilt R15 rigs
  (`ReplicatedStorage/NpcAnimator.luau`). Enemies and generic actors are scripted R6-style
  primitive-block rigs (`EnemyCombat.server.luau:525-590`, `GameplayActors.luau:56-92`):
  flat `SmoothPlastic` parts, one solid desaturated `Color3` each, a stock rounded
  `SpecialMesh` head.

## The five clashes, ranked

1. **Swords vs. every body that holds one.** A PBR, texture-mapped, painterly blade in
   the hand of a flat single-colour `SmoothPlastic` block body. The single starkest
   mismatch in the game.
2. **Two character pipelines.** Custom-mesh NPCs next to boxy scripted enemies read as
   two different games standing side by side.
3. **GUI vs. world.** Dark-and-gold "gacha fantasy" chrome over a bright storybook world.
4. **Detail density.** Lofted, textured swords against primitive-built world props and
   block-built characters — an order of magnitude of complexity apart.
5. **No shared material rule.** Matte world, forced-`SmoothPlastic` enemies, flat vector
   GUI, and PBR swords are four different implicit shading systems with nothing tying
   them together.

## The target language

Named after the bar. Pet Simulator 99: bright, chunky, high-key, saturated,
soft-shaded and rounded, nothing muddy or desaturated, everything visibly from the same
toy box across its world, characters and GUI alike. The world as it ships today already
sits close to this target; it is the anchor.

- **Silhouette**: rounded and chunky over sharp and faceted. Where the world currently
  facets a rock spire for "sculpted" detail, prefer fewer, larger, smoother facets — the
  cartoon reads as intentional simplicity, not low budget.
- **Material behavior**: soft matte diffuse with a single soft highlight, everywhere.
  No PBR metallic/roughness maps, no baked photoreal noise textures, on anything a
  player looks at up close, including swords. A sword's "damage" (a fuller, a crack, a
  glow vein) is carved geometry or a flat two-tone paint split, per the existing
  `feedback-sword-detail-real-geometry` rule, never a baked realistic material.
- **Colour**: high-saturation, high-key, storybook. No desaturated/muddy tones anywhere,
  including enemy bodies (today's enemy colours like `RGB(150,65,75)` and
  `RGB(130,45,55)` are too muted for this language and should brighten). Shadows are a
  darker, still-saturated version of the same hue, never grey.
- **Proportions**: exaggerated and friendly. Oversized heads/hands on characters,
  thick-handled weapons, chunky architecture — chunky proportions like Pet Simulator 99's costumed characters, not
  realistic ones.
- **Detail density**: even across every asset class. A sword should carry roughly the
  same visual complexity budget as the character holding it and the rock it's swung
  near — no single asset class allowed to be an order of magnitude more detailed than
  its neighbours.
- **GUI**: bright, saturated, rounded, high-contrast — Pet Simulator 99's chunky-icon,
  bold-outline, colour-coded-panel language, not a dark fantasy gacha palette.
  `PanelChrome.luau`'s base palette moves off charcoal-and-gold toward the world's own
  warm palette (the Lemonade identity already named in earlier gauntlets: warm, sunny,
  friendly).
- **One rig pipeline is the long-term fix for the character split**, but is a much
  bigger engineering change than an art pass; the first pass instead unifies the
  *material and colour rules* both pipelines follow (brighter, more saturated part
  colours; a shared simple two-tone shading trick on the block rig to close some of the
  gap) rather than replatforming R6 onto R15 or vice versa.

## How later pieces are judged

Every piece is judged on two things together, not one: does it beat the named bar
(Pet Simulator 99) on cartoon appeal, and does it match the rules above well enough
that it would look at home next to the other three areas. A piece that wins against the bar
but breaks a rule above (for example, a sword redesign that still bakes a photoreal
metallic texture) has not actually won.

## Status: the PS99 pass in code (2026-09-24)

What the rules above have been turned into so far, and what is still to be judged. The map
palette itself (commit `1c412fa`) and everything below were built and checked offline only; the
first in-Studio play-test is the next step, and its gauntlet (matched shot vs. a real PS99 frame,
two blind critics, both A/B orders) decides whether any of it stays.

Built:

- **World light** (`lemonade-game/Map/WorldLook.server.luau`, `worldlook-v15`): the three runtime
  recolours (`recolorHorizon` / `recolorCastle` / `recolorGates`) are gone, so the baked palette is
  what shows. Daylight is one shared table: near-white sun, cyan-blue shade tint, bright
  near-neutral fill, a near-neutral grade (saturation +0.12, not +0.55), the Atmosphere is the sky's
  own cyan-blue so distance fades toward sky, white clouds, soft cast shadows on
  (`SHADOWS` / `SHADOW_SOFTNESS` at the top of the file are the first two things to A/B). The sky
  uses Roblox's built-in default cubemap instead of six blank faces.
- **Terrain** (`WorldTerrain.server.luau`): colours unchanged from the map pass; water is now a
  flat toy cyan-blue with low reflectance. If the Rock/Slate/Basalt strata read rough next to the
  plastic castle in Studio, swap materials per stratum; do not change the colours.
- **Enemies** (`EnemyCombat.server.luau`, `ReplicatedStorage/EnemyOutfits.luau`): every archetype
  body is a full-chroma plastic; outfit cloth is pale and calm, trims carry a second pop; every
  accessory is SmoothPlastic (Neon kept for glows); the catalog shirt/pants templates are off
  (`CLOTHING_TEXTURES`). Measured per-rig saturation spread 0.25-0.33.
- **Swords** (`CombatUtil.applyWeaponAppearance`): a runtime override makes every held blade
  SmoothPlastic (Neon honoured as a glow), drops baked PBR `SurfaceAppearance` maps that carry no
  colour map, and the block/starter sword is a pale blade with a gold guard and coral grip.
- **Boss sword meshes** (`tools/blender_boss_swords.py`, `docs/BOSS_SWORDS.md`, 2026-09-24): the
  five PBR boss swords are replaced by Blender-built plastic-toy swords -- chunky slabs, thick
  grips, oversized pommels, flat swatch colours (metallic 0, roughness 1), every detail as carved
  geometry or a two-tone paint split, each pairing one calm pale surface with its boss's vivid
  family. The three wardens get the same treatment (each carries its zone Relic, drawn as its
  own mesh), the bandit falchion template gets the same palette, and every pool sword colour in
  `BossWeapons.luau` is now a calm tint or a full-chroma accent from its zone family. Same mesh
  layout as before, so no weld or Grip changes. Judged in Cycles renders only; the eight meshes
  need importing into `ServerStorage/BossSwordMeshes` and a Studio look.
- **GUI** (`PanelChrome.COLORS`, `PanelChrome.build`, `MapClient`): the charcoal-and-gold base
  palette and the dark modal shell are gone; both draw from the bright chrome (`PanelChrome.BRIGHT`).
  `MainMenuGui` still keeps its own local dark card palette for a few tabs; that is the next GUI piece.

Not yet done: any in-engine judgement. The first Studio session should capture, in this order,
the hub at the afternoon showcase clock, an Iron Lowlands fight (enemy + sword in hand), and one
modal panel, and run each through the gauntlet before touching values.

### Studio round log: hub, afternoon clock (2026-09-23, first in-engine session)

Setup: branch `claude/magical-dirac-kww440` merged with `claude/adoring-khayyam-85d49c` (combat,
swing and outfit work), served with `rojo serve map.project.json --port 34873` into "rpg backup".
Reference: `ps99_t048` (grass, path, buildings, sky). Two fresh critics per round, both A/B orders.

| Round | Change | Verdict | Named gap |
|---|---|---|---|
| 1-2 | as synced | 4-0 PS99 | Terrain reads real: grass-blade decoration, photo-textured sand/dirt path edges, gritty Rock/Slate spires |
| 3-4 | Rock/Asphalt -> Glacier, Slate/Basalt -> Ice | (script died on `Terrain.Decoration`, no terrain at all) | the accidental no-terrain frames were the closest to PS99 yet |
| 5 | Glacier/Ice replaced (they ignore SetMaterialColor): Rock -> Concrete, Slate -> Asphalt, Cobblestone -> Salt, Ground -> Pavement, desert Concrete -> Snow; Decoration write guarded | not judged | spires back and colour-true; grass blades back with the meadow |
| 6-7 | `HUB_LAWN_OVERLAY = false`: the meadow overlay is skipped, the HubFloor slab is the lawn | 4-0 PS99 | the lawn is a flat, empty, evenly lit plane: no hex/tile pattern, no contact shading, no pickups or props; second, the Concrete/Asphalt rock skirt still reads grainy next to the plastic wall |

What the critics consistently credit: the castle towers with red domes, the striped stall, the
orange zone gate, the puffy-ball trees and the sky.

Open decisions for the owner:
- The rock skirt. No Terrain material is both smooth and colour-true, so the terrain rock will
  always carry grain. Either accept it, or scrap it the way the horizon mountains were and let
  the castle wall stand alone on the slab.
- The lawn. The remaining gap is content, not colour: PS99's ground is a tiled two-tone lawn
  strewn with pickups. A hex/stud pattern on the HubFloor slab and prop clusters along the path
  are `tools/map_forge.py` work.
- `Workspace.Terrain.Decoration` is not scriptable in this Studio build; untick it by hand in
  Properties if grass blades show anywhere terrain grass remains (Briarwood, desert edges).
| 8 | `HUB_ROCK_SKIRT = false` (Alex: scrap it like the mountains) | 4-0 PS99 | bleaching (pale wall stone, canopies and path washing to near-white, weak contact shadows) x2; empty lawn x2; the faceted orange rock towers over the wall are the Iron Lowlands desert mesas (terrain), not the skirt |
| 9 | daylight a step down: brightness 2.2 -> 1.8, exposure 0.05 -> -0.05, fill and haze trimmed | 4-0 PS99 | stock photographic cloud cubemap x2; walls still near-white and flat-lit x3; empty lawn x3; desert mesas faceted x2 |

After nine rounds the hub is judged on things this pass does not own: the lawn's emptiness
and pattern (map_forge content), the wall stone's paleness (map_forge palette, measured offline
against PS99 but bleached in engine), and the desert mesas showing over the wall. The one
in-engine lever left is the sky: the default cubemap reads as "a default Roblox place" to two of
four critics; a flat gradient sky (six blank faces under the Atmosphere) is the alternative the
look pass had moved away from.

### Studio round log: boss swords (2026-09-24)

Frames: an Iron Lowlands fight with the Warden's Legendary in hand (`Motion:IronFight`, against
`ps99_t138`) and the sword gallery (`Motion:SwordGallery`, against `ps99_t100`). Two critics, both
A/B orders, 4 verdicts per frame per round. Saturation spread of the frames (cards.py's measure,
over pixels): fight 0.21, gallery 0.21; PS99 frames 0.25-0.30.

| Round | Frame | Verdict | Named gap (biggest, by count) | Fix |
|---|---|---|---|---|
| 1 | fight | 4-0 PS99 | desert floor one flat, washed-out, grainy beige plane (4) | floor: Terrain Sand -> Salt, the hub PATH cream |
| 1 | gallery | 4-0 PS99 | dark navy "spreadsheet" board (4) | pale cream card, ink outline, pale bands, ink text |
| 2 | fight | 4-0 PS99 | held blade a thin washed pink sliver (2); floor now blown out near-white, cliffs streaky (2) | not yet |
| 2 | gallery | 4-0 PS99 | no rounded outlined card per row / title plaque (3); blades thin, white-on-white (1, and second gap in all 4) | Blender pass: every blade profile 1.30x wider, 1.35x thicker (`BLADE_WIDTH_K` / `BLADE_THICK_K`, clamped under the guard span), eight GLBs regenerated and re-imported; Neon PointLight 2.5/12 -> 1.0/8; gallery: outlined pale-blue item tile per sword, scale 1.3 |
| 3 | fight | 4-0 PS99 | held blade still reads flat and pale: sky-white blade against the cream floor (4); mesas grainy/faceted (4, second) | not yet |
| 3 | gallery | 4-0 PS99 | thin navy hairline tiles and small grey stat text read as a spreadsheet (3); pale blades on pale tiles (1, second in all) | not yet |

Not won after three rounds on each frame. The meshes are now ~1:3 width to length (measured on
the GLBs; they were 1:5 to 1:6) and every one was re-measured in play with the hand on the grip.
What the critics still name is not thickness any more: (1) **contrast** -- the calm sky-white /
ice-white / ivory blades of the five boss designs vanish against the cream desert floor and the
cream gallery card, which are the same "calm" tint. One of the two has to give: either the boss
blades take a mid-value body colour (a design change to `tools/blender_boss_swords.py`'s palettes,
against the "one calm surface" rule in docs/BOSS_SWORDS.md) or the surfaces they are seen against
stay mid-value; (2) the gallery's chrome (stat text, hairline frames, no title plate) -- a UI
rebuild, not a colour tweak; (3) the Iron Lowlands mesa strata (Terrain Sandstone/Limestone)
still read grainy, the same finding as the hub rounds. Known tooling fault: the
Motion camera lock (`GuiShowcase`) never binds on the client this session ("client camera lock
never reported ready"), so the fight frame is the follow camera; the gallery's framing is
unaffected because its stage parks the character behind its own eye point.

### Studio round log: Iron Lowlands (2026-09-24)

Six showcase angles now exist for the zone (`WorldShowcase.client.luau`: WorldOasis, WorldBasin,
WorldMesas, WorldPit, WorldWest, WorldNorth; clocks in `WorldLook`). Judged: oasis, basin, west.
Two critics, both A/B orders, against `ps99_t048` / `ps99_t138`.

| Round | Change | Verdict | Named gap (biggest, by count) |
|---|---|---|---|
| 1 (oasis) | as synced: Salt floor in the hub's cream, Sandstone/Limestone/Rock strata | 4-0 PS99 | sand and sky blown to near-white under a yellow haze, no shadows (3); grainy, faceted dune cliffs (1, second in all) |
| 2 (oasis, basin, west) | floor Salt in its own warm tan (255,198,104), Sandstone and Rock strata -> Concrete in amber, PATH merged into Pavement | 12-0 PS99 | one mustard mass: floor, dunes and cliffs the same hue, shade side olive under the sky-blue shade tint (12); faceted low-poly rock (12, second) |
| 3 (oasis, basin, west) | hue separation: floor pale warm sand (255,232,186), cliff faces coral-orange (255,132,60), crest bands pale peach (255,208,150) | 12-0 PS99 | the mesas are faceted terrain rock with dark crevices, not rounded soft-shaded forms (9 of 9 so far); the sand plane empty, and half the critics now want it a touch more saturated than pale |

What the critics credit every round: the cream stucco houses with their yellow, pink, cyan and
orange trims, the striped tents, the chunky cacti, the palm arch, the sky.

Where it stands: colour and material are as far as the engine can take them. Every named gap
left is geometry or content. (1) **The mesas, the rim scarp and the rock towers are Roblox
Terrain**, and voxel terrain cannot be rounded or bevelled; the critics want "a few large smooth
rounded masses", which is what the castle wall already is -- SmoothPlastic parts from
`tools/map_forge.py`. The precedent is the hub: its terrain skirt was scrapped for the wall.
(2) **The tent frames, lamp posts and stall props read spindly** next to the chunky houses.
(3) **Nothing on the sand to run to**: pickups, crates, breakables, the same content note as the hub.
| 4 | the rock as parts: `tools/map_forge.py` `desert_rockforms()` (8 mesas, 5 far mesas, 7 hoodoos, the trail arch, the hideout arch, 5 sand boulders; 324 SmoothPlastic parts, coral body, peach bands, domed tops) and `WorldTerrain` `DESERT_ROCK_PARTS` (terrain keeps sand, pools, drifts; every wall column paints as sand; rock fills and foot boulders skipped) | 12-0 PS99 | the rock is no longer named. The sand floor plus the sand bank is "one flat near-white plane filling 60-70% of the frame" (12); nothing on it to run to (12, second) |
| 5 | sand golden peach (255, 212, 140) now the cliffs carry the coral; the floor's "bedrock showing through" patches and the deep body fill routed to sand (they were the last "orange smudges"; the sand bank's foot boulders too) | not judged | |

The mesa rebuild closed its own gap: from round 4 on, no critic names the rock, and several credit
"the banded orange mesas and hoodoos" as the frame's silhouette. What every verdict names now is
the ground plane and what stands on it: a warmer sand (done, round 5), value steps in the dune bank,
and props and pickups within 20-40 studs of the camera -- content, `tools/map_forge.py`.
| 6 | dressing the sand: `desert_sand_dressing()` in `tools/map_forge.py` -- a round peach kerb along both edges of every trail segment, and 19 clusters beside the trail (coral boulders, barrel cacti, short saguaros, crate stacks, sand mounds, flower pads), placed by a clearance rule off the trail, every spawn, pool, marker, the arena and every standing prop | 12-0 PS99 | the sand plane itself: "one flat beige with no shading or value steps" (12); the kerbs read as thin pipes (4); props still sparse and thin (6). Three critics ask for saturated ground fields -- grass patches, turquoise water -- which is a theme change for a desert |

Six rounds. The rock is solved, the floor is coloured, the trail is dressed, and the verdict is
still 12-0 because a PS99 frame is a lawn full of coins and the Iron Lowlands is a desert. What is
left is either more of the same (denser prop clusters, fatter kerbs, a tiled floor pattern on the
sand) or a decision to give the basin saturated ground fields that are not sand -- turf and water
around the oasis and the camp -- which changes what the zone is. The owner's call.

