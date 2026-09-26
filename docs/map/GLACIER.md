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
| Frost Hollow | −184..−104, −56..56 | 10 | Safe zone. The expedition camp: a timber cabin with a smoking chimney, a campfire and log benches, tents, a supply sled, a snowman. **Waystone 6 "Frost Hollow"** (arrival −142, 14). Level with the hub, straight through the gate. |
| The Great Ascent | −228..−186, −28..28 | 10 → 20 | A 56-wide snow ramp between fir-lined banks, two lanterns, under the **Ice Arch**. |
| Frozen Lake terrace | −350..−228, −104..64 | 20 | A cracked ice lake (r 30) with an ice-fishing hole, the **Frozen Fall** pouring off the north cliff, fir groves, crystal clusters. Four FrostImp packs (L18, L18, L19, L19), one out on the ice. |
| Gargoyle Stair | −350..−318, −100..−60 | 20 → 30 | A ramp up the ridge's ice face between temple ruins. |
| Gargoyle Ridge | −440..−350, −132..−24 | 30 | The **Frozen Colossus**: a giant ice knight half-sunk in the glacier, raising his sword. It's the milestone, seen from the lake. Big crystal fields (`CrystalFieldA/B`: forests of shards up to 30 tall, three of them Neon, the two largest lit); GlacialGargoyle L21/L22/L22 and the L23 elite. **Waystone 7 "Gargoyle Ridge"** (arrival −366, −44), just before the bridge, for short boss retries. |
| Ice bridge / Blue Crevasse | bridge x −398..−382 over z −24..−4 | 30 (floor of the crevasse 3) | The one crossing. Invisible rails and lips make the crevasse impossible to fall into. Below: a canyon of layered blue ice (`blue_crevasse`, after `glacier_refs/ice_canyon.png`): strata of ICE / ICE_PALE / ICE_DEEP pitched into the slot and stepping out as they rise, snow on every ledge, crystal geodes glowing out of the walls and gems set into them, brows under the lips, a rim of ice and snow above each lip with icicle curtains beneath, tumbled blocks and drifts round a frozen meltwater pool, and the canyon closing at both ends: a dark cleft lit by a sunset glow in the west, a crystal-lit choke at the mouth over the lake. |
| The Revenant's Forecourt | −440..−350, −4..88 | 30 | A round plaza (r 32) with an inlaid ring, four cold-fire braziers, frost banners, and a colonnade before the **Frozen Temple** (glowing doorway and snowflake crest) and its **Frozen Spire**. Boss_FrostRevenant L25, leash 30. |

Around it all, three ranks of ice stepping up, after `glacier_refs/glacier_valley.png`, so that a
player on the floor (camera at most 44 studs out) sees a skyline, not a fence: rubble, wall, crag,
peak, sky.
- **Rubble.** Knee-to-shoulder chunks of broken ice tumbled on the snow at every wall's foot
  (`wall_rubble`, laid on whatever floor is there, clear of markers and lanes).
- **The walls.** One kit piece (IceCliffA/B/C) per ~64 studs of edge, standing 15 studs outside the
  outline on the floors, which run out under them; crests ~55 over the floor they face. Each is two
  or three fat slabs of deep saturated blue (`ICE_WALL` #1E5FD0, alternating with `ICE_WALL_LIT`)
  leaning back 8-20°, a rounded bulge at each foot, long `NAVY` (#0B2A6B) crevasse slots down the
  faces (one vertical, one diagonal per slab), a pale serac overhanging 15-30° forward off each
  crest, snow mounds sunk into the seam and the serac top, a drift along the foot. An invisible
  proxy runs along every edge. The ridge's edge over the lake is the **IceLedge**, in the same blue.
- **The crags.** Giants (IceCragA/B, ~170-200 to the crest) on the snowfield apron (to x −600 /
  z −260) behind the walls, a step paler (`ICE_CRAG`): a huge mass leaning back, a higher block
  over it, a shoulder, a serac, four long navy crevasses, snow on every shelf.
- **The range.** Nine peaks 220-290 tall (SnowPeakA/B) on the apron's rim along the north and
  west, hazed pale blue (`RANGE`, `RANGE_DEEP`) under snow: a rounded mass with a fat sharp ridge
  and a crossing spur.
- **The notch.** The ridge's north wall (z −132) opens between x −432 and −366 (`GL_NOTCH`): a
  broken low lip instead of a wall, a crag at each jamb, and a peak square behind it. From the
  lake, the frozen river leads the eye to it.
- **The frozen river.** A winding strip of navy water under broken floes (tilted blocks and
  ellipsoids in ICE / ICE_PALE / ICE_DEEP, none collidable), from the ascent's top round the
  lake's north shore toward the Gargoyle Stair, fed by a run from the Frozen Fall; snow banks
  along both edges.

No view at the capped zoom ends on the bare baseplate.

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

`tools/glacier_kit.py` describes each of the 27 pieces once, as primitives (ball, drum, block,
wedge, cone, shard, icicle) in the piece's own frame:
- the ice cliffs (3), snowy firs (3), snow rocks (3) and crystal clusters (3);
- the crystal geodes (2, growing out of the crevasse walls), the crystal fields (2, the ridge) and the tumbled ice-block pile;
- the ice arch and the ice bridge;
- the temple column (intact and broken), the temple facade and the spire;
- the Frozen Colossus, the Frozen Fall, and snow peaks (2).

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

1. In Studio, with the map synced through Rojo, File > Import 3D each `assets/glacier/*.glb` (one per kit piece).
   Leave the importer's default orientation: `MeshSlots` turns the importer's 180° back.
2. Move the MeshParts (the importer leaves them in Workspace under "Scene" models) into a
   Folder `ServerStorage/MapMeshes`. Name each exactly its key (`IceCliffA`, `SnowFirB`, ...).
   Each should be a plain MeshPart with a TextureID and no SurfaceAppearance.
3. Play. `ServerScriptService/MeshSlots` swaps every slot whose mesh it finds and prints
   `[MeshSlots] N kit pieces now meshes`, naming any it could not find. A missing one just stays
   parts.
4. After any Rojo reconnect, check for duplicated scripts (MeshSlots, GlacierAmbience, ZoneAir).

## Air, weather, camera

- `ZoneAir.client.luau`:
  - moves the ambient, outdoor ambient and atmosphere colour toward a cool, high-key ice blue west
    of the gate (`FROST_AIR`, 60 % share, daylight only);
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
- About 3,270 parts in `FrostboundGlacier` (42 collidable; the walls, rubble, crags and range are
  ~1,300, the Blue Crevasse ~600) and 12 floors.
- 20 PointLights (budget 20): the crevasse's sunset cleft and two wall geodes, the ridge's two big fields.
- `check_map_project.py`: 0 FAILs. The nav grid now spans x −490..150, z −170..960.
- `audit_map.py FrostboundGlacier`: the trail lanes are clear, and nothing collidable is within 4
  studs of a spawn.

## Open

The Studio session's plan (import, play-test, and ideas that need the real renderer): `GLACIER_STUDIO_PLAN.md`.

- Import the meshes (above), then judge the zone in Studio in play: frame rate at the forecourt,
  the snowfall's density, the aurora from the lake.
- Pick SoundIds for `GlacierWind`.
- Sunken Marsh (24-29) is the region's second zone, still to build.
