# Frostbound Glacier

The first Frostbound zone (Lv 18-25). It lies west of Hearthmere, through the hub's west gate
(`GateFrostbound`, now open). There is **no voxel terrain**: every floor is a
`Grounds_FrostboundGlacier` slab and everything you see is parts. The big pieces come from a kit
that is also modelled in Blender. Enemies are the existing FrostImp, GlacialGargoyle and
Boss_FrostRevenant: their looks are code-built (EnemyOutfits), their quests (q9-q11), drops and
spin pools were already wired, and map mode spawns them from this zone's markers.

![route](glacier_preview.png)

Aerial, ascent, lake, ridge, bridge and forecourt, rendered from the parts version in Cycles.

![kit](glacier_kit.png)

## The route

| Area | Where (x, z) | Floor Y | What's there |
| --- | --- | --- | --- |
| Frost Hollow | −184..−104, −56..56 | 10 (corner shelves 14) | Safe zone. A timber hamlet under the ice: the two-storey lodge "The Thawed Kettle" with its lit porch, six cabins (two on each raised corner shelf behind it, one on the south yard), roofs higher still on mounds against the west cliff, every chimney smoking; amber window panes, lantern strings, a dark-ice skating pond and two fires with log benches just inside the gate, a well, sleds, banners, and snow-people (a shopkeeper, a skater, one warming by the fire). The exit arch is deep ice with a glowing rim. **Waystone 6 "Frost Hollow"** (arrival −142, 14). Level with the hub, straight through the gate. |
| The Great Ascent | −228..−186, −28..28 | 10 → 20 | A 56-wide snow ramp between fir-lined banks, two lanterns, under the **Ice Arch**. |
| Frozen Lake terrace | −350..−228, −104..64 | 20 | The ice river's floor: a pale turquoise terrace (`ICE_FLOOR`) with a frozen lake (r 30) sunk in it, the winding river of open cyan water, crevasse cracks running down its centre line toward the notch, the **Frozen Fall** pouring off the north cliff, firs at the edges, three crystal clusters. Four FrostImp packs (L18, L18, L19, L19), one out on the ice. |
| Gargoyle Stair | −350..−318, −100..−60 | 20 → 30 | A ramp up the ridge's ice face, one ruined temple column at its head. |
| Gargoyle Ridge | −440..−350, −132..−24 | 30 | The **Frozen Colossus**: a giant ice knight half-sunk in the glacier, raising his sword. It's the milestone, seen from the lake. Big crystal fields; GlacialGargoyle L21/L22/L22 and the L23 elite. **Waystone 7 "Gargoyle Ridge"** (arrival −366, −44), just before the bridge, for short boss retries. |
| Ice bridge / Blue Crevasse | bridge x −398..−382 over z −24..−4 | 30 (floor of the crevasse 3) | The one crossing. Invisible rails and lips make the crevasse impossible to fall into. Crystals and ice columns glow at its bottom. |
| The Revenant's Forecourt | −440..−350, −4..88 | 30 | A round plaza (r 32) with an inlaid ring, four cold-fire braziers, frost banners, and a colonnade before the **Frozen Temple** (glowing doorway and snowflake crest) and its **Frozen Spire**. Boss_FrostRevenant L25, leash 30. |

Around it all, three ranks of ice stepping up and back, after `glacier_refs/glacier_valley.png`,
so that a player on the floor (camera at most 44 studs out) sees a valley, not a fence: rubble, wall,
spire, crag, mist, range, sky. The lake terrace is the valley's corridor: from the ascent's top
looking west along the frozen river to the Gargoyle Stair, the walls stand tall on the near
flanks, step down on the ridge at the far end, and the far range shows pale in the notch at the
vanishing point under open sky (render view `g_corridor`).
- **Rubble.** Knee-to-shoulder chunks of broken ice tumbled on the snow at every wall's foot
  (`wall_rubble`, laid on whatever floor is there, clear of markers and lanes).
- **The walls.** One kit piece per ~110 studs of edge, standing 15-17 studs outside the outline
  on the floors, which run out under them; an invisible proxy runs along every edge. West of the
  hollow (the terrace's valley and the ridge) they are **IceTierA/B**: four or five fat rounded
  tiers of deep saturated blue (`ICE_WALL` #1E5FD0 and `ICE_WALL_LIT` by turns), each narrower
  than the one under it, sunk into it, a ledge back and turned a few degrees, the whole stack
  leaning 7-9° in over the floor; a thick pure-white snow cap sunk into every tier's top (a white
  ledge between the blue tiers, seen along the wall), a snow dome on the summit, one or two
  two-tone crevasses (a `NAVY` strip inside an `ICE_DEEP` strip, in the tier's own frame) flush
  in each belly, a rounded foot, a drift. `corridor_crest` sets each piece's height for the
  corridor: the terrace's north flank towers 210 down to 160 westward, the corner pieces at its far
  end drop to 50, the ridge's walls (the far rank, recoloured a step hazier with `FAR_RANK`) are
  62-72. The sun stands low in the west-south-west, so every wall on the floor's south or west
  throws its shadow 0.9 studs across it per stud of height: the south flank (80-65) and the
  ridge's walls stay under ~85, where their shadows end at the river's south bank and the floor
  stays bright. The hollow's and the ascent's walls keep the IceCliffA/B/C slabs (~65 tall) the
  hamlet was built under. The ridge's edge over the lake is the **IceLedge**, four rounded lumps
  in the same blue with fissures and snow cornices.
- **The spires.** Five giants (IceSpireA/B, 150-200 tall, 34-48 wide): one enormous leaning shard
  each, three tiers of block narrowing and turning to a pale turned tip, a buttress leaning the
  other way, a rounded foot, two-tone crevasses, snow sunk into the top. They stand at the
  valley's corners, placed by hand so none is in the corridor's sight line: over Frost Hollow's
  north wall, on the terrace's north flank, at the notch's two jambs, over the ridge's west wall.
- **The crags.** Four (IceCragA/B, ~170-200 to the crest) on the snowfield apron well behind the
  walls, a big step paler (`ICE_CRAG`, `ICE_CRAG_LIT`), off the sight line: a huge mass leaning
  back, a higher block over it, a shoulder, a serac, wide two-tone crevasses, snow sunk into every
  shelf.
- **The mist.** Eight big flat translucent lenses of light cyan (`MIST`, transparency 0.5) lying
  on the snowfield between the ranks, thickest between the mid rank and the range, so the feet of
  the crags and the peaks dissolve and each rank reads a step hazier; no straight edge against
  the sky. A low bank lies over the far end of the terrace floor at the stair's mouth and another
  by the notch.
- **The range.** Ten peaks 180-265 tall (SnowPeakA/B, and the broad SnowPeakC massif) far out on
  the apron's rim (250-550 studs from the floor, so they sit low on the horizon), hazed very pale
  (`RANGE`, `RANGE_DEEP`: pale even on the shaded east faces the corridor sees) under snow: a
  rounded mass with a fat sharp ridge and a crossing spur. Three chunky ones stand square in the
  corridor's vanishing point, north-west through the notch, their tops 19-25° up from the eye.
- **The notch.** The ridge's north wall (z −132) opens from its north-west corner to x −366
  (`GL_NOTCH`): a broken low lip instead of a wall, a spire at each jamb, and the range behind.
  From the lake, the frozen river leads the eye to it.
- **The frozen river.** The terrace is the ice river's floor, a pale turquoise (`ICE_FLOOR`), the
  lake disc a shade deeper. A winding strip of open cyan water (`RIVER`) under broken floes (low
  blocks and ellipsoids in ICE_PALE / SNOW / ICE, none collidable) runs from the ascent's top round
  the lake's north shore toward the Gargoyle Stair, fed by a run from the Frozen Fall, white snow
  banks along both edges; three crevasse cracks (`ICE_DEEP` strips lying flat in the ice, at
  heights that never share a plane with the water, the trail or the lake) zigzag beside it down
  the valley's centre line toward the notch, a rounded lump of heaved ice beside every other
  bend. The middle of the terrace is otherwise clear: no rocks, pillars, fishing gear or plates
  of ice, so the eye runs from the river to the notch.

No view at the capped zoom ends on the bare baseplate; nothing here collides (the proxies do).

Beyond the handoff brief (Alex asked for creative choices), I added:
- the frozen lake, as the lower terrace;
- the frozen waterfall;
- the colossus, as the milestone;
- the crevasse and ice bridge, instead of a plain terrace step;
- the aurora;
- the expedition camp, which gives the safe staging area a story.

Walk times from the player spawn (`check_map_project.py`, run speed): Frost Hollow 6 s, the lake
imps 10-13 s, Gargoyle Ridge 15 s, the Revenant 19 s.

## The kit: one spec, two builds

`tools/glacier_kit.py` describes each of the 32 pieces once, as primitives (ball, drum, block,
wedge, cone, shard, icicle) in the piece's own frame:
- the ice cliffs (3), ice tiers (2), ice spires (2), snowy firs (3), snow rocks (3) and crystal clusters (3);
- the crystal geodes (2, growing out of the crevasse walls), the crystal fields (2, the ridge) and the tumbled ice-block pile;
- the ice arch and the ice bridge;
- the temple column (intact and broken), the temple facade and the spire;
- the Frozen Colossus, the Frozen Fall, and snow peaks (3).

(The cliffs, crags, ledge and peaks were redesigned after the GLBs in `assets/glacier` were
exported: rerun `tools/blender_glacier_kit.py` before importing those four kinds, or the meshes
will be the old, smaller shapes.)

Two builders read the same list:

- **Blender** (`tools/blender_glacier_kit.py`). Each piece becomes one mesh:
  - cones are real cones, and the snow drapes scallop and drip over each fir tier;
  - ice columns have a flat chamfer on every edge;
  - crystals and spire tiers are tapered hex prisms;
  - rocks and snow caps wobble;
  - temple columns are fluted;
  - icicles hang under cornices and capitals;
  - the colossus's blade is a real blade.

  Then the swords' toy finish: joined, a small round bevel, smooth by angle, one swatch-atlas
  material (metallic 0, roughness 1). Output is `assets/glacier/<Key>.glb` plus `kit.json`, which
  records each mesh's measured size and centre. The contact sheet at the top of this page shows
  every mesh beside its parts version. Run it any time, Studio open or not:
  `python3 tools/blender_glacier_kit.py`. Check the output with
  `python3 tools/check_glacier_glb.py` (one mesh / material / image, matte plastic, under 10,000
  triangles, size and centre match kit.json).
- **map_forge** (`kit_piece()` in `tools/map_forge.py`) builds the same primitives as parts:
  - cones become rounded ellipsoid tiers;
  - shards become the waystones' block with a turned-cube tip;
  - icicles are skipped.

  Each piece is a Model tagged `MeshSlot`, with attributes `MeshKey`, `SlotX/Y/Z` (the mesh's
  world centre, from kit.json), `SlotYaw` and `SlotScale`. Glow parts carry `MeshGlow`.

## Getting the meshes in (Studio, once, with Alex at the PC)

Until this is done the Glacier plays and looks complete in parts. Nothing depends on it.

1. In Studio, with the map synced through Rojo, File > Import 3D each `assets/glacier/*.glb` (22 files).
   Leave the importer's default orientation: `MeshSlots` turns the importer's 180° back.
2. Move the 22 MeshParts (the importer leaves them in Workspace under "Scene" models) into a
   Folder `ServerStorage/MapMeshes`. Name each exactly its key (`IceCliffA`, `SnowFirB`, ...).
   Each should be a plain MeshPart with a TextureID and no SurfaceAppearance.
3. Play. `ServerScriptService/MeshSlots` swaps every slot whose mesh it finds and prints
   `[MeshSlots] N kit pieces now meshes`, naming any it could not find. A missing one just stays
   parts.
4. After any Rojo reconnect, check for duplicated scripts (MeshSlots, GlacierAmbience, ZoneAir).

## Air, weather, camera

- `ZoneAir.client.luau`:
  - moves the ambient, outdoor ambient and atmosphere colour toward a deep, saturated dusk blue west
    of the gate (`FROST_AIR`, 85 % share, daylight only): about a third darker than the town's
    daylight shade, so the hamlet's amber windows and fires are the warm focal point of a cold frame;
  - caps the camera zoom at 44 in the Glacier;
  - adds an empty-SoundId `GlacierWind` bed for Alex to fill.
- `GlacierAmbience.client.luau`:
  - soft snowfall round the camera;
  - three slow-waving aurora curtains over the northern peaks;
  - a sparkle on every crystal cluster.

  All of it idles outside the Glacier.

## Numbers

- Seed `0x61AC1E5`, private: the hub, Iron Lowlands and Briarwood regenerate byte-identical, apart
  from the hub's gate (unsealed, "Lv 18 - 25 | Open") and its removed placeholder vista.
- About 3,490 parts in `FrostboundGlacier` (42 collidable; the walls, rubble, spires, crags, mist
  and range are ~1,200, the Blue Crevasse ~600) and 12 floors.
- 20 PointLights (budget 20): Neon carries every window and lantern; lights sit at the gate, the waystones, the lodge door, the fires and the pond's lantern string, the temple, the braziers, two crevasse geodes and the ridge's two big crystal fields (the sunset cleft glows unlit).
- `check_map_project.py`: 0 FAILs. The nav grid now spans x −490..150, z −170..960.
- `audit_map.py FrostboundGlacier`: the trail lanes are clear, and nothing collidable is within 4
  studs of a spawn.

## Open

The Studio session's plan (import, play-test, and ideas that need the real renderer): `GLACIER_STUDIO_PLAN.md`.

- Import the meshes (above), then judge the zone in Studio in play: frame rate at the forecourt,
  the snowfall's density, the aurora from the lake.
- Pick SoundIds for `GlacierWind`.
- Sunken Marsh (24-29) is the region's second zone, still to build.
