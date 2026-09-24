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
  family. The bandit falchion template gets the same palette. Same mesh layout as before, so
  no weld or Grip changes. Judged in Cycles renders only; they need importing into
  `ServerStorage/BossSwordMeshes` and a Studio look.
- **GUI** (`PanelChrome.COLORS`, `PanelChrome.build`, `MapClient`): the charcoal-and-gold base
  palette and the dark modal shell are gone; both draw from the bright chrome (`PanelChrome.BRIGHT`).
  `MainMenuGui` still keeps its own local dark card palette for a few tabs; that is the next GUI piece.

Not yet done: any in-engine judgement. The first Studio session should capture, in this order,
the hub at the afternoon showcase clock, an Iron Lowlands fight (enemy + sword in hand), and one
modal panel, and run each through the gauntlet before touching values.
