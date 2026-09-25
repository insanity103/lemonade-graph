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
| Gargoyle Ridge | −440..−350, −132..−24 | 30 | The **Frozen Colossus**: a giant ice knight half-sunk in the glacier, raising his sword. It's the milestone, seen from the lake. Big crystal fields; GlacialGargoyle L21/L22/L22 and the L23 elite. **Waystone 7 "Gargoyle Ridge"** (arrival −366, −44), just before the bridge, for short boss retries. |
| Ice bridge / Blue Crevasse | bridge x −398..−382 over z −24..−4 | 30 (floor of the crevasse 3) | The one crossing. Invisible rails and lips make the crevasse impossible to fall into. Crystals and ice columns glow at its bottom. |
| The Revenant's Forecourt | −440..−350, −4..88 | 30 | A round plaza (r 32) with an inlaid ring, four cold-fire braziers, frost banners, and a colonnade before the **Frozen Temple** (glowing doorway and snowflake crest) and its **Frozen Spire**. Boss_FrostRevenant L25, leash 30. |

Around it all: ice cliffs grown so their crests stand ~46 studs over the floor they face, an
invisible proxy on every edge, a snowfield apron to x −600 / z −260, and snow peaks on it. No view
at the capped zoom ends on the bare baseplate.

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

`tools/glacier_kit.py` describes each of the 22 pieces once, as primitives (ball, drum, block,
wedge, cone, shard, icicle) in the piece's own frame:
- the ice cliffs (3), snowy firs (3), snow rocks (3) and crystal clusters (3);
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
  every mesh beside its parts version. Run it with Studio closed:
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
- About 1,400 parts in `FrostboundGlacier` (19 collidable) and 12 floors.
- 14 PointLights (budget 20).
- `check_map_project.py`: 0 FAILs. The nav grid now spans x −490..150, z −170..960.
- `audit_map.py FrostboundGlacier`: the trail lanes are clear, and nothing collidable is within 4
  studs of a spawn.

## Open

The Studio session's plan (import, play-test, and ideas that need the real renderer): `GLACIER_STUDIO_PLAN.md`.

- Import the meshes (above), then judge the zone in Studio in play: frame rate at the forecourt,
  the snowfall's density, the aurora from the lake.
- Pick SoundIds for `GlacierWind`.
- Sunken Marsh (24-29) is the region's second zone, still to build.
