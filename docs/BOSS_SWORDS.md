# Boss swords: the enemy designs, and a sword for each boss

Status: built 2026-09-24 (`tools/blender_boss_swords.py`, Blender 4.2 headless), judged offline in
Cycles renders only. Eight meshes are in `assets/swords/` (the five bosses and the three wardens)
with a contact sheet in `assets/swords/preview.png`. They have not been imported into the place or
seen in Studio yet (see "Getting them into the game" at the end). The same day, every pool sword
colour in `BossWeapons.luau` moved onto the same palette (see "The pool swords").

## Why the old swords had to go

The previous five (`tools/sword_forge.py`, now guarded as legacy) were the most photoreal assets
in the game: metallic 0.6 / roughness 0.45 PBR, 1024 px baked JPEG textures of noise, cracks,
voronoi ice, lava veins and sparkle, thin lofted blades, and a palette of iron grey, near-black
basalt, deep purple and blood red. `docs/ART_DIRECTION.md` names that as the single starkest clash
in the game: a painterly PBR blade in the hand of a flat plastic block body. Every rule below was
written to close that gap, not to make prettier swords in isolation.

## The enemy designs (what each sword is drawn from)

Every enemy is a scripted R6 block rig (`EnemyCombat.server.luau`) whose body is one full-chroma
plastic, dressed by `ReplicatedStorage/EnemyOutfits.luau` in a few large accessory parts: pale
calm cloth, one or two saturated pops, Neon for glows. The families, and the motifs each boss's
sword takes from them:

| Family (zone) | Body | Outfit | Boss, title | Motifs the sword carries |
|---|---|---|---|---|
| Quarry bandits (Iron Lowlands) | coral / hot pink-red | toy-blue "iron" helm, breast and back plate, chain belt; rust-orange pauldrons, rivets, pick heads; cream vest and war belt; coral / near-white / sky banner capes; gold hip lantern | **Warden of the Pit**, Boss of the Quarry Bandits | pit, cage bars, chains, shackles, rivets, quarry tools |
| Frost (Frostbound Glacier) | deep toy blue | pale ice tunic and mantle, deep-blue crown, cuffs and greaves, white antlers, cyan frost stole, white neon eyes | **Frost Revenant**, Lord of the Permafrost | icicles, antlers, a cut ice gem |
| Cinder (Caldera) | orange | cream tunic, coral-red armour and cuffs, ember-yellow furnace horns, heart vent and eyes | **Infernal Colossus**, Scourge of Flame | furnace, flame tongues, a molten heart |
| Void (Void Rift) | violet | pale lavender veil and tunic, deep-violet wings and spikes, hot-magenta halo and rift eyes | **Void Archon**, Herald of Oblivion | the rift, an eye, crescent wings |
| Astral (Celestial Summit) | gold | ivory tunic, tangerine standard, sun-yellow halo, solar heart and back sunray | **Celestial Titan**, God of the Astral Realm | the sun disc, a halo, stars, an eclipse |
| Briar (Briarwood) | lime | pale leaf tunic, timber-orange thorns and branches, leaf-green hood, yellow glows | Rootbound Warden (warden, no sword) | -- |
| Marsh (Sunken Marsh) | aqua | pale mint tunic, deep aqua-blue helm and cage, lime-yellow reeds and bell | Drowned Bellwarden (warden, no sword) | -- |
| Storm (Stormwatch) | blue | pale cloud tunic, gold bracer and armour, deep-blue hood and crest, pale-lightning glows | Tempest Warden (warden, no sword) | -- |

The three wardens are named elites, not unique bosses: no unique drop, but each already drops
from its zone pool (`BossWeapons.NormalDrops`, rank "warden"). So each one now carries its zone's
Relic -- the pool's Legendary, drawn as the warden's own mesh -- and the sword you see is the sword
that zone drops. Arming them is visual only (`weapon = true` in `EnemyCombat` welds the mesh with
the same Grip joint a boss uses; no stat or drop rate moves).

## The rules every sword follows

From `docs/ART_DIRECTION.md`, made concrete:

- **Few large smooth forms.** Blade, guard, grip, pommel, and at most two carved motifs. No
  filigree, no engraved lines, no decals.
- **Chunky and rounded.** The blade is a thick slab (half-thickness 0.028-0.031 of the length at
  the root, against 0.012-0.020 before), the grip is a fat cylinder (radius 0.038 against 0.020),
  the pommel fills its whole band, and every hard edge carries a real bevel so the silhouette reads
  as moulded plastic, not cut steel.
- **Detail is geometry or a flat paint split, never a material.** The cutting edge is a chamfer
  strip painted the accent colour; a bite is a boolean cut; a glowing core is a raised rib; an eye
  is a hole. One swatch atlas of solid colours, metallic 0, roughness 1, so Studio imports a plain
  MeshPart with a TextureID and no SurfaceAppearance, and `CombatUtil.applyWeaponAppearance`
  makes it SmoothPlastic at runtime like everything else in the hand.
- **One calm surface plus the boss's vivid family.** The same toy box as the bodies and outfits:
  a pale near-white (sky-white, ice-white, cream, lavender, ivory) against the family's saturated
  colours, never grey, brown or black.
- **The game's layout, unchanged.** Length 1.0 along Z, tip at -0.5, guard band z 0.195..0.255,
  handle 0.255..0.46, hand at 0.38 (`CombatUtil.SWORD_GRIP_FRAC`), bounding box symmetric about
  the grip axis with the guard the widest feature at exactly +-0.13, under 10k triangles. Every
  weld, Grip and Tool offset in the game fits the new meshes without a change.

## The five designs

Names in the config (`BossWeapons.luau`, `EnemyCombat.uniqueDrop`) are unchanged: saved swords
resolve by name, so renaming a sword would orphan every one already in a vault. The mesh under
each name is what changed. The design names below are what they are called in the manifest.

**Warden of the Pit -- Pit Warden's Cleaver** (`Boss_Gorgon.glb`, 4,640 tris)
A quarry chopper: a broad, squared, sky-white slab with a coral cutting edge, a round cage-bar
bite carved out of the spine near the tip, a toy-blue iron bar guard with three orange rivet
domes on each face, a cream grip with orange bands, a blue collar and a blue shackle ring for a
pommel. Calm: sky-white. Vivid: coral, toy blue, rust orange -- the same three colours as the
Warden's helm, pauldrons and banner cape.

**Frost Revenant -- Frostfang Cleaver** (`Boss_FrostRevenant.glb`, 3,292 tris)
An icicle cleaver: an ice-white slab sweeping to a hooked point, cyan cutting edge, three fat
icicle teeth hanging back off the spine, an antler guard (a hub, two swept prongs, a tine each)
in the Revenant's deep blue, a deep-blue grip with white bands, a cyan collar and a six-facet cut
cyan gem for a pommel (its facets stay flat on purpose). Calm: ice-white. Vivid: cyan, deep blue.

**Infernal Colossus -- Inferno Edge** (`Boss_InfernalColossus.glb`, 3,464 tris)
A furnace flamberge: a coral-red double-edged blade waving in three big lobes, ember-yellow
chamfered edges and the last quarter painted yellow as the hot tongue, a cream crucible guard
that rises in a bowl round the blade root, a cream grip with red bands and a fat yellow flame for
a pommel. Calm: cream. Vivid: ember red, ember yellow -- the Colossus's armour and furnace glow.

**Void Archon -- Voidrend Blade** (`Boss_VoidWraith.glb`, 3,960 tris)
A rift crescent: a pale lavender scimitar curving to a hooked point, magenta cutting edge, a
deep-violet rib along the spine, a round rift cut clean through the blade with its inner wall
painted magenta, a wing guard (hub and two prongs swept toward the tip), a violet grip with
lavender bands, a magenta collar and a big magenta orb pommel. Calm: lavender. Vivid: magenta,
violet -- the Archon's halo and wings.

**Celestial Titan -- Astral Eclipse** (`Boss_CelestialTitan.glb`, 5,380 tris)
A sun-halo greatsword: an ivory leaf blade with gold chamfered edges and a tangerine centre ridge,
a big gold halo ring round the blade root with a tangerine eclipse disc peeking out behind the
blade, a four-point gold star guard (long flat-ended arms, short vertical points that stay out of
the hand), an ivory grip with gold bands and a five-point gold star pommel. Calm: ivory. Vivid:
gold, tangerine -- the Titan's halo and standard.

**Rootbound Warden -- Grovebound Bloom** (`RootWarden.glb`, Briarwood's Relic)
A leaf blade: pale-leaf body, lime chamfered edges, a raised leaf-green midrib, two timber thorns
curling back off the spine, a branch guard (hub, two timber prongs, a twig stub each), a timber
grip with pale bands and the grove heart for a pommel: a fat six-petal yellow bloom with a green
centre. Calm: pale leaf. Vivid: lime, leaf, timber, bloom -- the Warden's hood, branches and heart.

**Drowned Bellwarden -- Drowned Chime** (`DrownedBellwarden.glb`, Sunken Marsh's Relic)
A bell cutlass: a wide mint blade with an aqua cutting edge and a soft scallop along the spine, a
deep aqua-blue bell for a guard (a flared cup round the blade root, its lip the widest point), an
aqua-blue grip with mint bands and a bell clapper pommel: a lime-yellow ball on a short stem.
Calm: mint. Vivid: aqua, aqua-blue, lime-yellow -- the Bellwarden's helm, chain and clapper.

**Tempest Warden -- Thunderglass Pane** (`TempestWarden.glb`, Stormwatch's Relic)
A lightning bolt: a pale cloud slab that zigzags three times to the tip, gold chamfered edges, a
pale-lightning bolt rib down the middle, a deep-blue observatory-dome guard on a gold rim (its flat
ends the widest point), a deep-blue grip with gold bands and an antenna pommel: a gold ball on a
blue mast. Calm: cloud. Vivid: gold, deep blue, lightning -- the Warden's crest, bracer and heart.

Also regenerated in the same palette: the quarry bandits' falchion, `SwordMeshTemplate.glb`
(`tools/blender_forge_enemy_sword.py`: sky-white blade, toy-blue bar, cream cord, gold pommel,
matte). It is the most-seen sword in the game (every Cutthroat and Brute carries it, and every
`mesh = "Template"` pool sword reuses its shape), so it could not stay iron-and-leather.

## Reproducing and checking

```
pip install "bpy==4.2.*" numpy pillow        # Blender as a Python module, CPU Cycles included
python3 tools/blender_boss_swords.py         # -> assets/swords/Boss_*.glb, manifest.json, preview.png
python3 tools/blender_boss_swords.py --keep-previews   # also per-sword side + three-quarter renders
python3 tools/blender_forge_enemy_sword.py assets/swords/SwordMeshTemplate.glb [preview.png]
python3 tools/check_sword_glb.py assets/swords/*.glb   # layout + matte-material rules, no Blender
```
The forge asserts every layout rule and the matte material before it writes a file, and refuses a
boolean that cut nothing. Renders use a neutral white environment for lighting with the PS99 sky
blue visible only to camera rays, and Blender's Standard view transform, so the swatch colours on
the sheet are the sRGB values in the files. Blender was not run on Alex's machine for this; it is
safe to run there whenever Studio is closed.

## Getting them into the game

Studio only. Rojo does not carry MeshParts or ServerStorage in the map project, so this is a
manual import, the same as the original swords:

1. File > Import 3D each of the eight `assets/swords/<archetype>.glb` and `SwordMeshTemplate.glb`. Leave
   the importer's default orientation (the game already corrects the 180-degree turn about Y).
   The importer should produce a plain MeshPart with a TextureID and **no** SurfaceAppearance; if
   one appears, the material factors were not honoured and `CombatUtil.applyWeaponAppearance`
   will drop it at runtime anyway.
2. Name each MeshPart exactly `Boss_Gorgon`, `Boss_FrostRevenant`, `Boss_InfernalColossus`,
   `Boss_VoidWraith`, `Boss_CelestialTitan`, `RootWarden`, `DrownedBellwarden`, `TempestWarden`
   and put them in `ServerStorage/BossSwordMeshes`, replacing the old ones; the falchion is
   `ServerStorage/SwordMeshTemplate`. Until the warden meshes are imported, their Relics and
   held swords fall back to the falchion template.
3. `Motion:SwordGallery` (the Studio-only capture stage, `workspace:SetAttribute("GuiShowcase", ...)`)
   shows the whole roster built through the real `BossSwordFactory`; `Motion:EnemyDrops` shows
   every enemy holding its weapon. Judge those two frames against a PS99 frame with the same
   two-critic gauntlet as the rest of the look pass (`docs/PS99_STUDIO_REVIEW.md`).

## The pool swords

The 100-odd lesser, recoloured and spin-relic swords in `BossWeapons.luau` are one flat colour
each (`textured = false`, or the block sword's `color` + `accent`), so they cannot pair calm and
vivid on one blade; the pairing is across the pool instead. Every `color` and `accent` is now
either a calm pale tint or a full-chroma accent from its zone's family -- the same swatches as the
bodies, outfits, terrain and the meshes above -- and nothing is grey, brown or black any more
(Chainbreaker iron grey is now sky-white, Basalt Claymore near-black is the terrain's coral basalt,
Singularity Greatsword near-black is deep violet, the quarry shivs' greys are cream and sky-white
with orange and coral fittings, and so on: 106 definitions touched). An audit rule guards it:
saturation <= 0.22 with value >= 0.9, or saturation >= 0.6 with value >= 0.85. Names, bases, weights
and inherents are untouched, so saved swords still resolve.

Two mesh fixes rode along. Every boss pool's Legendary and its recoloured claymores used the
`Boss_Gorgon` mesh (the old "generic greatsword"), which with the new meshes would have drawn the
Titan's own drop as the Warden's cage-bar cleaver; each pool's big swords now wear their own boss's
silhouette. And the three warden Relics wear the warden meshes, painted.

## Follow-ups this pass did not take on

- **Studio judgement.** Everything here is offline. The gauntlet is the decision.
- **Spin-station and gallery framing.** Eight distinct silhouettes at 3.3-5.4k triangles each are
  well under budget, but the sword gallery stage (`Motion:SwordGallery`) was framed for the old
  thinner blades; check the grid spacing.
