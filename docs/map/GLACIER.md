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
| Frozen Lake terrace | −350..−228, −104..64 | 20 | A cracked ice lake (r 30) with an ice-fishing hole, the **Frozen Fall** pouring off the north cliff, fir groves, crystal clusters. Four FrostImp packs (L18, L18, L19, L19), one out on the ice. |
| Gargoyle Stair | −350..−318, −100..−60 | 20 → 30 | A ramp up the ridge's ice face between temple ruins. |
| Gargoyle Ridge | −440..−350, −132..−27 | 30 | The **Frozen Colossus**: a giant ice knight half-sunk in the glacier, raising his sword. It's the milestone, seen from the lake. Big crystal fields; GlacialGargoyle L21/L22/L22 and the L23 elite. **Waystone 7 "Gargoyle Ridge"** (arrival −366, −44), just before the bridge, for short boss retries. |
| Ice bridge / Blue Crevasse | bridge x −398..−382 over z −27..8 | 30 (floor of the crevasse 3) | The one crossing. Invisible rails and lips make the crevasse impossible to fall into. Below: the **Blue Crevasse** (`blue_crevasse`, after `glacier_refs/ice_canyon.png`), a slot 35 wide open to the sky. Each wall is three ranks in plan: a proud rank of big blocks of varied width (6-18) standing 2-8 studs into the slot, one tall unbroken NAVY band at the floor, COBALT (ICE_DEEP on every other block), an ICE block overhanging the floor under a dark flush band, then white for the top 30 % (frosted, then SNOW or SNOW_WARM at the rim, alternating), every ledge under a thick white cap; a recessed rank behind it one tone paler at every height, with dark flush bands and fissures; and near-white ice towers 26-54 tall on the ridge and forecourt slabs above the lips (frosted, white, sun-warmed snow on top, a cobalt band on the foot; every other one's middle tier overhangs its foot), stepping back and leaning out so the sky slit is wide from the floor, with a gap at the bridge so the deck is a pass between them; icicle curtains under the lips. Two faint cyan panes of mist stand across the slot on the way in, so each rank of wall beyond them is a step paler; west it funnels into a dark cleft with a sunset glow behind four more panes, each paler and denser, so the far end fades; before them one big lit crystal field (`CrystalFieldA` x1.5) is the landmark under two crossed sheets of warm-gold sun (Neon, translucent; one carries a PointLight) let in by the slit; a pink crystal cluster glows unlit in a niche on each wall, and two geodes grow from ledges. The floor is white snow between big white drifts and chunky deep-blue rocks at the walls' feet. |
| The Revenant's Forecourt | −440..−350, 8..88 | 30 | A round plaza (r 32) with an inlaid ring, four cold-fire braziers, frost banners, and a colonnade before the **Frozen Temple** (glowing doorway and snowflake crest) and its **Frozen Spire**. Boss_FrostRevenant L25, leash 30. |
| Frozen Lake terrace | −350..−228, −104..64 | 20 | The ice river's floor: a pale turquoise terrace (`ICE_FLOOR`) with a frozen lake (r 30) sunk in it, the glacier tongue of stepped broken ice running along the north flank's foot toward the stair and the notch, the **Frozen Fall** pouring off the north cliff onto it, firs at the edges, two crystal clusters. Four FrostImp packs (L18, L18, L19, L19), one out on the ice. |
| Gargoyle Stair | −350..−318, −100..−60 | 20 → 30 | A ramp up the ridge's ice face, one ruined temple column at its head. |
| Gargoyle Ridge | −440..−350, −132..−24 | 30 | The **Frozen Colossus**: a giant ice knight half-sunk in the glacier, raising his sword. It's the milestone, seen from the lake. Big crystal fields; GlacialGargoyle L21/L22/L22 and the L23 elite. **Waystone 7 "Gargoyle Ridge"** (arrival −366, −44), just before the bridge, for short boss retries. |
| Ice bridge / Blue Crevasse | bridge x −398..−382 over z −24..−4 | 30 (floor of the crevasse 3) | The one crossing. Invisible rails and lips make the crevasse impossible to fall into. Below: the **Blue Crevasse** (`blue_crevasse`, after `glacier_refs/ice_canyon.png`): each wall is a stack of staggered ledges climbing from NAVY at the floor through COBALT and ICE to frosted ice at the lip, every proud band under a thick snow cap; above each lip ice towers 20-40 tall stand on the ridge and forecourt slabs (frosted, then near-white, a sun-warmed snow cap on top), leaning in and leaving a slot of sky over the middle, with a gap at the bridge so the deck is a pass between them; icicle curtains under the lips. West it closes on a dark cleft with a sunset glow, three translucent panes of mist across the far end, one big lit crystal field (`CrystalFieldA` x1.4) as the landmark before it and a geode on a ledge above; a lit geode mid-canyon on the north wall. The floor is a packed-snow path between navy and cobalt chunks and drifts at the walls' feet. |
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
  hollow (the terrace's valley and the ridge) they are **IceWallA/B** (round 5): one continuous
  fluted cliff each, a big faceted core of deep saturated blue (`ICE_WALL` #1E5FD0) leaning
  10-12° in over the floor, and against its front seven to nine tall blades of the wall's two
  blues (a pale one now and then) shoulder to shoulder, uneven in width, height and prominence,
  each turned a hair, so the face is ribbed and the crest ragged; a snow cap sunk into every
  blade's top, two white ledges right across the face (the strata; their tops catch the sun even
  on a wall with its back to it), snow streaks in the grooves, `NAVY`-in-`ICE_DEEP` crevasse
  slots in the widest blades, two pale seracs tipped over the crest, a rounded foot and a drift.
  The terrace's two flanks get one piece per 60 studs, so the pieces overlap by half their width
  and read as one cliff. `corridor_crest` sets each piece's height for the corridor (render view
  `g_player`, eye height at the ascent's top looking north-west): the north flank towers 215 down
  to 145 westward and is the sunlit wall; the south flank (120-100) and the forecourt's south
  wall (130) stand with the sun behind them and throw their shadows east-north-east over the lake
  and the near floor (the sun is low in the west-south-west: every wall south or west of a point
  shades it if it stands taller than 0.62 × its distance along the light); the terrace's far
  corners drop to 50-60 so the notch beside them stays open; the ridge's walls (the far rank,
  recoloured a step hazier with `FAR_RANK`) are 62-72. A 150-tall jamb (`WestJamb`, IceWallB)
  stands on the terrace's west edge from z 9 to 79, its back under the forecourt: the frame's left
  wall, rising out of the top at its left edge, its face in shade, placed no further north than
  z 9 so that its shadow misses the tongue. North of it the ridge's edge is only the broken
  **IceLedge** lip (anything taller there would shade the tongue's head). The hollow's and the
  ascent's walls keep the IceCliffA/B/C slabs (~65 tall) the hamlet was built under; IceTierA/B
  (round 4's rounded drums) stay in the kit, unused.
- **The spires.** Five giants (IceSpireA/B, 150-200 tall, 34-48 wide): one enormous leaning shard
  each, three tiers of block narrowing and turning to a pale turned tip, a buttress leaning the
  other way, a rounded foot, two-tone crevasses, snow sunk into the top. Recoloured a step paler
  (`FAR_RANK`) as the mid rank, the silhouette behind the walls, and placed by hand so none is in
  the corridor's sight line to the peaks: over Frost Hollow's north wall, on the terrace's north
  flank, over the flank's far end at the notch's east jamb, and two on the apron west of the
  ridge and the forecourt, 20° and 36° left of the notch, their crests just over the frame's top.
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
  the apron's rim (250-500 studs from the floor, so they sit low on the horizon), hazed pale
  (`RANGE`, `RANGE_DEEP`: a hair deeper than the sky, so they read against it) under snow: a
  rounded mass with a fat sharp ridge and a crossing spur. Three big ones stand square in the
  corridor's vanishing point, north-west through the notch, 430-480 studs out, their tops 24-28°
  up from the eye, over the notch's low jambs (15°).
- **The notch.** The ridge's north wall (z −132) opens from its north-west corner to x −366
  (`GL_NOTCH`): a broken low lip instead of a wall, a spire at each jamb, and the range behind.
  From the lake, the frozen river leads the eye to it.
- **The glacier tongue.** The terrace is the ice river's floor, a pale turquoise (`ICE_FLOOR`),
  the lake disc a shade deeper and kept clean. Up the valley's centre line runs the tongue
  (`glacier_tongue`): a raised band 30 wide of fat rounded slabs of frosted ice and snow
  (flattened ellipsoids in ICE_PALE / SNOW / ICE, 3.5 tall at the snout and 9.5 at the head,
  each turned and tipped, overlapping like scales) over a `NAVY` bed that shows in the gaps, a
  tipped serac under a snow cap on every third slab, a snow heap on every third, snow banks along
  both edges; from the lake's east rim north-west and then west along the north flank's foot to
  the stair's mouth, the strip the sun reaches, rising toward the notch. A patch of flat broken
  plates (`broken_ice`) lies in the frame's near foreground. None of it collides. The lake's rim
  is a ring of low snow drifts. The middle of the terrace is otherwise clear, so the eye runs
  from the tongue to the notch.

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

`tools/glacier_kit.py` describes each of the 37 pieces once, as primitives (ball, drum, block,
wedge, cone, shard, icicle) in the piece's own frame:
- the ice cliffs (3), ice tiers (2), ice walls (2), ice spires (2), snowy firs (3), snow rocks (3) and crystal clusters (3);
- the crystal geodes (2, growing out of the crevasse walls), the crystal fields (2, the ridge) and the tumbled ice-block pile;
- the ice arch and the ice bridge (16 x 36 since the crevasse widened: its GLB is stale until re-exported);
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
- About 3,360 parts in `FrostboundGlacier` (47 collidable; the walls, rubble, spires, crags, mist
  and range are ~1,100, the Blue Crevasse ~450) and 14 floors.
- 20 PointLights (budget 20): Neon carries every window and lantern; lights sit at the gate, the waystones, the lodge door, the fires and the pond's lantern string, the temple, the braziers, the crevasse's landmark crystal field and its sun shaft, and the ridge's two big crystal fields (the sunset cleft, the geodes and the pink clusters glow unlit).
- About 3,300 parts in `FrostboundGlacier` (42 collidable; the walls, rubble, spires, crags, mist
  and range are ~1,100, the Blue Crevasse ~500) and 12 floors.
- About 3,710 parts in `FrostboundGlacier` (46 collidable; the walls, rubble, spires, crags, mist
  and range are ~1,400, the Blue Crevasse ~600) and 14 floors.
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
