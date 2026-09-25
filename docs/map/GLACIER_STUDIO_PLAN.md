# Frostbound Glacier: the Studio session's plan

For the session that works on the Glacier inside Roblox Studio, with Alex at the PC. The zone was
built in a cloud session with **no Studio access**: everything below was validated only offline
(Rojo builds, `check_map_project.py` 0 FAILs, the audit, the tests) and rendered in Blender
Cycles, not Roblox. Nobody has walked it, fought in it or seen it lit by Roblox yet. You can do
what that session couldn't. Read these first: `CLAUDE.md`, `docs/map/GLACIER.md` (what was built
and why), then this plan.

Branch `claude/magical-dirac-kww440`, commit `1a1fa7f` and after.

## Ground rules (Alex's; do not relax them)

- Sync to Studio only through Rojo, and only while Alex is at the PC. No stand-in HTTP syncs. Ask
  before restarting Studio.
- After any Rojo reconnect, check for duplicated scripts: every name once in ServerScriptService,
  StarterPlayerScripts and ReplicatedStorage. The new ones are `MeshSlots`, `GlacierAmbience`
  and `ZoneAir`.
- **Blender is allowed at any time, Studio open or not** (Alex, 2026-09-25). This replaces the older
  "no Blender while Studio is open" rule for this work, so don't close Studio for a kit export. Use
  Blender freely: exports, Cycles renders, new pieces, quick iterations.
- Another session may be editing combat, swing, outfit, NPC-model and animation files. Don't touch
  or commit its work. Run `git status` before you start.
- Never hand-edit `lemonade-map/LemonadeMap/*`: it's generated. Every map change goes into
  `tools/map_forge.py` (layout, parts) or `tools/glacier_kit.py` (the kit's shapes), gets
  regenerated with `python3 tools/map_forge.py`, and reaches Studio through Rojo. Studio is for
  **looking, measuring and play-testing**. Things you only try in Studio must be written back
  into the generators.
- Don't move spawns, gates, collision proxies or other gameplay markers unless the change is for
  the Glacier itself (it's still being built, so its own markers may move).
- Before every commit, validate:
  - `rojo build map.project.json -o /tmp/m.rbxlx && python3 tools/check_map_project.py /tmp/m.rbxlx`
    must show 0 FAILs;
  - `python3 tools/audit_map.py /tmp/m.rbxlx FrostboundGlacier` must keep lanes clear and at most
    20 lights;
  - `rojo build default.project.json -o /tmp/g.rbxlx && python3 tools/check_gameplay_project.py /tmp/g.rbxlx`
    must PASS;
  - `python3 tools/check_glacier_glb.py` if the kit changed.
- Commit only when Alex asks.

## Phase 0: sync and a baseline (about 15 min)

1. `git fetch && git checkout claude/magical-dirac-kww440`, run `rojo serve map.project.json`, and
   connect the plugin. Check for duplicate scripts.
2. Add Glacier views to `lemonade-game/Map/WorldShowcase.client.luau`, next to `WorldOasis` (same
   shape: `clock`, `stand`, `camera`, `fov`, `hideEnemies`), so every later change can be judged
   from the same frames. Starting points (Roblox coords; tune the framing in Studio):

   | View | Camera at | Looking at | Shows |
   | --- | --- | --- | --- |
   | `GlacierGate` | (−60, 26, 0) | (−160, 14, 0) | the hub gate opening onto the camp |
   | `GlacierAscent` | (−160, 24, 6) | (−260, 22, −10) | the ramp, the ice arch, the lake beyond |
   | `GlacierLake` | (−236, 34, 40) | (−300, 20, −40) | the frozen lake, the fall, the colossus |
   | `GlacierRidge` | (−340, 44, −40) | (−420, 34, −110) | the colossus and the crystal fields |
   | `GlacierForecourt` | (−360, 44, 70) | (−450, 40, 36) | the plaza, the temple, the spire |

   These match the Blender renders in `docs/map/glacier_preview.png`, so you get a direct
   Blender-versus-Roblox comparison. Capture each with `workspace:SetAttribute("GuiShowcase", ...)`
   and `tools/studio_capture.sh`.
3. Capture all five **before** changing anything. That's the "parts only" baseline.

## Phase 1: bring the meshes in (the big visual step)

Follow "Getting the meshes in" in `docs/map/GLACIER.md`:
1. File > Import 3D all 22 `assets/glacier/*.glb`.
2. Move them into `ServerStorage/MapMeshes`, each named its key.
3. Play. MeshSlots prints how many slots it swapped.

What to verify, because none of it has been tested:
- **Orientation.** `MeshSlots.server.luau` assumes Studio turns every import 180° about Y, as it
  did for the swords (`IMPORT_TURN`). The asymmetric pieces show whether that holds: the ice
  cliffs' drifts should face the play area, the colossus should face south-east toward the lake,
  and the temple door should face the plaza. If they're backwards, set `IMPORT_TURN` to identity.
- **Size and position.** Each MeshPart's `MeshSize` should equal `assets/glacier/kit.json`'s `size`
  (the importer kept sword sizes exact). A mesh standing too high, too low or off to one side
  means kit.json's `centre` doesn't match what the importer did. Measure one piece and fix it in
  one place: either the centre maths in `kit_piece()` in `map_forge.py` or `MeshSlots`. Don't
  nudge pieces one by one.
- **Material.** Each should be a plain MeshPart with a TextureID and no SurfaceAppearance.
  MeshSlots forces SmoothPlastic. The swatch atlas uses `Closest` filtering in Blender; check that
  Roblox doesn't blur neighbouring swatches together at face edges. If it does, pad the atlas
  cells in `KitForge`/`Forge.material` (tools/blender_boss_swords.py's `material`, used as is).
- **Glows stay.** The temple door and crest, the spire tip, the arch keystone, the colossus's visor
  and fuller are `MeshGlow` parts and should survive the swap, sitting correctly against the
  mesh.
- **Parts versus mesh.** Capture the five views again and compare them with the baseline. Wherever
  the mesh looks *worse* than the parts (it can happen: an over-lumpy rock, a heavy bevel on
  distant cliffs), say so. The fix goes in `tools/glacier_kit.py` or `tools/blender_glacier_kit.py`,
  then goes through the Blender-to-Studio loop below.
- **Performance.** There are 123 MeshSlots (44 of them cliffs, 27 firs), each under 10k triangles.
  Check the MicroProfiler and frame rate at the forecourt and from the lake looking west, the
  worst views. Levers:
  - `RenderFidelity = Automatic` on the far pieces;
  - `CastShadow = false` on the vista peaks and the back rank of cliffs;
  - lower-poly variants for peaks (e.g. `SnowPeakA` at 16 segments).

  Put any property changes in `MeshSlots.server.luau`, not by hand.

## Phase 2: play it end to end

Walk and fight the whole route with a character at Lv 18+ (use the admin tools, not saved data),
first with the parts version and then with the meshes. Things only Studio can tell:

- **Enemies on the right floors.** Imp pack FG_I2 stands on the frozen lake, a disc 0.3 above the
  terrace: check they spawn on it, not inside it, and path on and off it cleanly. Gargoyles on the
  ridge (Y30) must not drop to the lake terrace while chasing. Check the Revenant's leash (30)
  inside the plaza, and that the temple proxy doesn't trap it.
- **Aggro spacing.** The encounter spacing is 22–47 studs (see `check_map_project.py`'s table).
  Check whether packs pull together (FG_E1 with FG_G2 at 22 studs is the tightest) and whether the
  lake feels too crowded or too empty. Tune `GLACIER_SPAWNS` in `map_forge.py`.
- **Edges.** Try to fall into the crevasse (the rails and lips are invisible proxies), jump the
  ridge's ice face, climb any cliff, and walk through the temple steps (a proxy stands in front of
  them). Kit pieces don't collide, so players walk *through* firs, rocks, crystal clusters and
  columns. Decide with Alex which should be solid, then add proxies in map_forge; big fir trunks
  and the colossus base are the likely ones.
- **Waystones and travel.** Check that Frost Hollow and Gargoyle Ridge are discovered and that
  travel works both ways. After a boss wipe, is waystone 7 a short enough walk back?
- **The quest chain.** Kill five enemies for q9, the Revenant for q10, claim a Revenant sword for
  q11, and check the quest guide's arrow finds its way through the gate and up the route.
- **The region banner.** "Frostbound Glacier / Recommended Lv 18 - 25" should show once. The old
  "still being built" toast at the west gate must be gone.
- **Camera.** The zoom cap is 44 inside the Glacier. Hunt for any view past the cliffs, especially:
  - the corners (the camp's NE and SE corners next to the hub castle, and the temple notch);
  - over the south wall toward the desert's dune banks;
  - from the hub looking west through the gate.
- **Streaming.** If StreamingEnabled is on, check the far pieces (peaks, spire, colossus) don't pop.
  Kit models may want `ModelStreamingMode = Atomic`, like the hub.

## The Blender-to-Studio loop

Blender runs alongside Studio, so iterate on the kit piece by piece, with the real renderer as judge:

1. Change the piece in `tools/glacier_kit.py` (its shape, which both builds share) or in
   `tools/blender_glacier_kit.py` (how the mesh is modelled: bevels, facets, scallops, lumps).
2. Export just that piece:
   `python3 tools/blender_glacier_kit.py --only=IceArch --no-preview`. That writes the GLB and
   updates its kit.json entry. Drop `--no-preview` for a Cycles side-by-side. An `--only` run
   rewrites the contact sheet with only those pieces, so run everything once at the end to
   refresh `docs/map/glacier_kit.png`. Then run `python3 tools/check_glacier_glb.py`.
3. If the parts version or its footprint changed, run `python3 tools/map_forge.py`. Rojo syncs
   the new slot, and its centre comes from the fresh kit.json.
4. In Studio, re-import that GLB, replace the MeshPart of the same name in `ServerStorage/MapMeshes`,
   press Play, and capture the Glacier view it's in with the view that came before.
5. Keep what reads better in the real frame. Blender renders are for fast exploring; the Studio
   capture decides.

Blender can also do new pieces the walk-through shows are missing: add a builder to
`glacier_kit.py`, place it with `kit_piece()` in `build_frostbound_glacier()`, export, import. And it
can do concept renders of alternatives (two arch designs, three colossus poses) to show Alex before
any of them reach the map.

## Phase 3: ideas to make it better (these need Studio's eyes)

The cloud session could only judge Blender renders. The ideas below are the ones that need the real
renderer, real lighting and a real character. Pick with Alex; not all are wanted.

**Light and air** (the biggest unknown)
- Tune `FROST_AIR` / `FROST_SHARE` in `ZoneAir.client.luau` against the real frame. The snow must
  stay white, shade must read lavender-blue rather than grey, and the ice must stay saturated.
  Blender can't predict Roblox's Atmosphere or ColorCorrection.
- The cliffs are ~46 studs tall. Check where their shadows fall at the showcase clock (15.3): if
  the whole lake or plaza sits in shade, move the time of day or thin the south-west cliffs.
- Neon glows (door, spire tip, braziers) with Bloom: check they glow without blowing out. Try a
  night pass: aurora stronger, braziers and cabin windows carrying the scene.

**Materials worth trying** (stay inside the cartoon rules in `docs/ART_DIRECTION.md`)
- The frozen lake as `Glass` with some Reflectance, or a thin translucent ice layer over a darker
  blue floor, for "ice you can see into". Keep it flat-colour cartoon if Glass reads as realistic.
- A faint ForceField shimmer on the crevasse floor or the spire tip.
- Crystal clusters: a small interior Neon core (a `MeshGlow` part in the kit spec) so they glow at
  dusk.

**Life and motion** (map-side only)
- **Frozen Fall**: mist or ice sparkles at the plunge pool (a ParticleEmitter in
  `GlacierAmbience`). **Chimney**: check the cabin's Smoke reads.
- **Snowfall density** (`snow.Rate`, 70): judge it on a low-end device setting too.
- **Aurora**: tune its height, colours and transparency from the lake and from the forecourt.
  Maybe a second band over the temple.
- **Critters** like the oasis's parrots: snow rabbits hopping in the hollow, penguins by the lake,
  snow owls on the colossus's shoulders. Use the pattern in `OasisAmbience.client.luau`.
- Sway on the firs (they have no `Sway` attribute yet, and OasisAmbience only sways the Iron
  Lowlands). Maybe firs shedding snow puffs when a player walks past.

**Ambience sound**
- Fill `GlacierWind` in `ZoneAir` and add beds for ice creaks by the lake, a low hum at the
  temple, and a crackle at the campfire. Alex picks the SoundIds (Toolbox > Audio).

**Gameplay flavour** (ask Alex first: these touch play, and some need the combat session)
- A slippery lake: `CustomPhysicalProperties` with low friction on the FrozenLake floor. Players
  and imps slide. Fun, but it changes combat.
- Gargoyles that start as stone statues on plinths and "wake" on aggro. The ridge's broken
  columns could be their perches. This needs EnemyCombat, which is the other session's area:
  propose it, don't build it.
- The Revenant's entrance: the temple door glow pulses or brightens when the boss aggros (a map
  script watching the boss model's attributes, no combat change).
- Easter eggs in the safe camp: an ice-fishing ProximityPrompt at the lake hole, or a snowman you
  can knock over.

**Composition** (judge with a character on screen)
- Check scale against a player: the arch clearance (30), the cabin door, the trail width (7), the
  bridge width (16), the colossus's height (~70).
- The ridge's west half and the forecourt's corners may feel empty once the enemies are there.
  The camp may feel crowded. Adjust in `build_frostbound_glacier()` and keep the seeds' layout
  stable.
- The route's milestone: can a player on the lake see the colossus *and* the spire, and does the
  ascent arch frame the lake? If not, move the arch (−236, 0) or grow the colossus.
- The seam at the gate: the hub's castle wall back face against the glacier cliffs.

**The kit in Blender** (any time, through the loop below)
- Anything Phase 1 showed as weak. Likely candidates:
  - the ice arch's snow reads as blobs;
  - the spire tiers still read as stacked boxes;
  - the peaks may want more facets.
- New pieces the zone may want after a walk: an ice bridge railing variant, a snow-roofed
  lean-to, frozen banners, icicle curtains for the crevasse walls.

## Deliverables

- Glacier views in WorldShowcase, with before and after captures of all five. Put them in `docs/map/`.
- Meshes imported and verified, with any MeshSlots or kit.json fixes.
- A play-test report appended to `docs/map/GLACIER.md`: what worked, what was fixed, what Alex
  decided.
- Every map change made through the generators, all validators green, committed only on Alex's
  say-so.
