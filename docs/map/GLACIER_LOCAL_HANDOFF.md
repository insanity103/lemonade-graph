# Frostbound Glacier: handoff to the local session

For the Claude Code session on Alex's own PC, with Studio open. It finishes the Glacier gauntlet
that a cloud session started. The cloud session had Blender, Rojo builds and the validators, but no
Studio: it judged every round from Blender Cycles renders of the part geometry, lit by a sun it
chose itself. You have what it didn't: the real Roblox renderer and lighting, a character to walk
the route, the mesh importer, and Alex beside you. This doc says where the work stands, what
carries over, and how to run the loop now that the game itself can be judged.

Read, in this order:
1. `CLAUDE.md`
2. this doc
3. `docs/map/GLACIER_GAUNTLET.md`: the live progress page and the full round log
4. `docs/map/GLACIER.md`: what was built and why

`docs/map/GLACIER_STUDIO_PLAN.md` is still the checklist for mesh import and play-testing, but parts
of it predate the gauntlet. Where it disagrees with this doc, this doc wins (see "What's stale" below).

Branch: `claude/magical-dirac-kww440`. Run `git pull` first; the cloud session may have pushed
after this was written.

## The goal (Alex's words)

> make the frostbound glacier look as cool as these photos but keep the cartoon look. go crazy with
> this you can change anything in that area you have full control

The bar is the three photos in `docs/map/glacier_refs/`:

| Photo | Our piece |
| --- | --- |
| `glacier_valley.png` | the ice walls, the range and the frozen river |
| `ice_canyon.png` | the crevasse canyon and its crystals |
| `snow_village.png` | the Frost Hollow village |

How the gauntlet works:
- Each piece has a builder and a separate critic, each with fresh context.
- The critic sees our frame and the photo side by side, unlabelled, and picks one.
- A piece is done only when the critic picks ours blind. There is no round limit.
- "Cartoon" is non-negotiable: PS99 toy look, rounded chunky masses, SmoothPlastic with Neon and
  Glass only for glints, never grey (`docs/ART_DIRECTION.md`). The critic is told to reject
  photoreal just as hard as bland.

"Full control" covers the Glacier's own area only: its layout, kit, palette, markers and its air
script. It doesn't cover the hub or other zones.

## Where it stands

Check the last lines of `GLACIER_GAUNTLET.md`'s log for anything newer than this.

| Piece | Rounds | Status |
| --- | --- | --- |
| Village | 2 | **Won** on merit. Polish only: the empty snow field in the lower-centre foreground. |
| Walls and range | 5 lost; 6 building | Round 5 (`c9a26bb`: a towering V onto one notch, fluted IceWall cliffs, a stepped glacier tongue) lost as "a blue crystal city". The notch is as busy and as blue as the near walls, the walls have window-like slots, and the foreground plates block the view. Round 6 brief: the critic's next three in the gauntlet page's table. |
| Canyon | 3 lost; 4 building | Round 3 (`65e3791`) lost: it still reads as a hallway, not a gorge. The round 4 builder was running in the cloud when this was written (see below). |
| Frozen river field | 0 | Folded into the walls piece. The river is in the walls' frame. |

**Round 4 canyon brief**, if it hasn't landed (no "canyon round 4" commit in `git log`):
- Gorge walls 4–6× a player's height, built as staggered strata. Each has a bulging, rounded,
  snow-capped lip, leaning in and stepping back to a thin sky slit.
- 3–4 haze planes paler with distance.
- A glossy cyan-glow ice path with drifts and small crystals.
- Rounded pillars, overhangs, icicle rows and wall crystals; navy recesses with cyan rim light.
- The look-up view `g_canyon_up` moved out from under the bridge: eye (−404, 5, −10), target
  (−452, 62, −10).
- Stay at 20 PointLights or fewer and under about 4,000 parts.

What the critics kept asking for, across all pieces (the pattern to beat):
- **Scale.** Walls must tower 8–12 player heights and leave the frame, not stop at 3–4.
- **Value range.** Near-white rims over a navy base, ranks paler with distance, one warm accent.
- **A focal point.** One vanishing point, one landmark, an uncluttered floor.
- **Real sky and sun.** A gradient sky, one strong sun, hard shadows.

## What changes now that you're local

**1. Judge the real game, not a Blender stand-in.** This is the big one.
- The cloud's "ours" frames were Cycles renders of the parts, lit by `tools/render_glacier.py`'s own
  sun and sky. Roblox's Atmosphere, ColorCorrection, Bloom, shadows and ZoneAir tint weren't in
  them.
- A round won in Blender can lose in Roblox, and the reverse. From now on, the critic's "ours"
  image is a **Studio capture**: a Play-mode frame through the game camera, with UI hidden.
- Blender renders become the builder's fast pre-check only.
- Setup (from `GLACIER_STUDIO_PLAN.md` Phase 0):
  1. Add Glacier views to `lemonade-game/Map/WorldShowcase.client.luau` next to `WorldOasis`.
  2. Give each a `SHOWCASE_CLOCK` entry in `lemonade-game/Map/WorldLook.server.luau`.
  3. Capture with `workspace:SetAttribute("GuiShowcase", "<View>")` and
     `tools/studio_capture.sh OUT.png`.
- Use the same eyes as the render views the critics already know. All are in `render_glacier.py`
  `VIEWS`, as (eye, target[, lens mm]):

  | Showcase view | Render view | Eye | Target | Frames |
  | --- | --- | --- | --- | --- |
  | `GlacierValley` | `g_player` | (−232, 25, 4) | (−340, 30, −70) | walls, 70° FOV |
  | `GlacierCorridor` | `g_corridor` | (−232, 25, 4) | (−340, 30, −70) | walls, wider |
  | `GlacierCanyon` | `g_canyon` | (−363, 16, −6) | (−445, 9, −12) | canyon |
  | `GlacierCanyonUp` | `g_canyon_up` | (−404, 5, −10) | (−452, 62, −10) | canyon, wide |
  | `GlacierVillage` | `g_village` | (−97, 19, 5) | (−172, 13, 3) | village, wide |

- Also capture one frame from a player's real third-person camera on the same spot. That's what
  players see, and the critic should see it too.

**2. The sun moves.** Check this before judging anything.
- The Blender renders froze a sun 32° up in the west-south-west.
- The game runs a day cycle (`WorldLook.server.luau`):
  - latitude 30, a server opens at 08:00, a day lasts 30 minutes;
  - the sun is in the east in the morning, near overhead at noon, about 40° up in the west at
    15:20, then swings south-west at golden hour.
- Walls rounds 4 and 5 set wall heights around that one western sun. The south flank was capped at
  100–130 and the ridge's north edge cut to a lip, so their shadows miss the floor and the tongue.
- In Studio, scrub `Lighting.ClockTime` through 08, 11, 13, 15.3 and 17 at the valley and canyon
  views. Look for:
  - a terrace that sits in shade for half the day;
  - a canyon floor that is dark at every hour except noon;
  - walls kept short for a western sun that the morning sun makes pointless.
- Then pick one of these with Alex:
  - accept it;
  - retune the heights for the whole day;
  - add a Glacier-only lighting override in `ZoneAir`, the way it already blends the frost air.

  Don't change the global day cycle; it's shared by every zone.
- Judge each round at 15.3, the showcase clock, and note in the log how it looks at 08 and 12.

**3. Import the meshes.** Every kit piece exists twice: parts, and a mesh swapped in by
`MeshSlots.server.luau` when `ServerStorage/MapMeshes/<Key>` exists.
- Only 22 GLBs were ever exported, from the first build.
- The gauntlet added 15 pieces that have **no GLB and no Blender modelling yet**. They play as parts:
  - `IceWallA/B`, `IceTierA/B`, `IceSpireA/B`, `IceCragA/B`, `IceLedge`, `SnowPeakC`;
  - `CrystalFieldA/B`, `CrystalGeodeA/B`, `IceBlockPile`.
- Several of the 22 changed shape or palette after export, so treat all GLBs as stale.
- To get the pieces into Studio:
  1. Add a modelled builder for each new piece to `tools/blender_glacier_kit.py`. Its shape comes
     from `tools/glacier_kit.py`, which the parts version shares.
  2. Re-export everything: `python3 tools/blender_glacier_kit.py`, then
     `python3 tools/check_glacier_glb.py`.
  3. Regenerate the map: `python3 tools/map_forge.py`. The slots take their centres from the
     fresh `kit.json`.
  4. Import the GLBs in Studio, following "Getting the meshes in" in `GLACIER.md`.
- Check the unverified import assumptions: the 180° `IMPORT_TURN`, `MeshSize`/centre agreement,
  and atlas bleed. Details are in `GLACIER_STUDIO_PLAN.md` Phase 1.
- Then run the gauntlet on the **meshed** frames. The rounded, bevelled meshes are what the critics
  kept asking for ("rounded tiers, not boxes"), so this alone may win rounds.
- The parts version stays the fallback and must still look right.

**4. Use Roblox tools Blender couldn't show.** Several critic gaps are about air and light, and
Roblox has real tools for them that the cloud could only fake with translucent panes:
- **Depth haze.** A Glacier-only `Atmosphere` density and haze blend in `ZoneAir`, instead of (or
  as well as) the mist panes. Ranks go paler with distance for free.
- **Sun shafts.** `SunRaysEffect` is already in `WorldLook`. A `Beam` or thin Neon sheet can make
  the canyon's gold shaft. Judge it in the real frame.
- **Mist, spray and snow.** `ParticleEmitter`s in `GlacierAmbience.client.luau`: mist at the
  canyon floor, blowing spindrift off the wall crests, and ice sparkles on the river.
- **Glow.** Bloom on the Neon crystal cores and the cyan ice path. Watch that pale snow doesn't blow
  out.
- **Surfaces.** A `Glass` or low-reflectance river floor, and SurfaceLight rim light in the navy
  recesses. The rule stays: 20 PointLights or fewer in the zone. `audit_map.py` counts only
  PointLights, so add SurfaceLights and SpotLights to its count before relying on them. They cost
  the same.

Put all of it in the scripts or generators; nothing lives only in the Studio file. Keep the
cartoon rule: Glass and Neon stay accents.

**5. Play-test as you go.** A round can't win by breaking the zone. After each merged round, walk
the route from the gate to the Revenant with a Lv 18+ character. Check:
- the camera never sees past the walls (zoom cap 44);
- a player can't fall into or climb out of the canyon;
- enemies spawn on floors and path cleanly;
- the new tall walls don't trap the camera against a face.

The full checklist is in `GLACIER_STUDIO_PLAN.md` Phase 2.

## Running the loop locally

The `gauntlet-loop` skill was installed only in the cloud session's home directory; it isn't in the
repo. It only writes the loop's prompt, and the loop itself is below, so you don't need it. To have
it anyway: `git clone https://github.com/robonuggets/gauntlet-loop ~/.claude/skills/gauntlet-loop`.

**Lead (you).** Keep `GLACIER_GAUNTLET.md` current. Add one log line per builder landing and per
critic verdict, and update the table row. After each merge and each verdict, commit and push to
`claude/magical-dirac-kww440`. Alex asked for the loop, which covers committing each round; for
anything else, the Studio plan's "commit only when Alex asks" still holds.

**Builder, per piece.** An Agent in its own worktree and branch (`isolation: "worktree"`). It
doesn't push.
- Its brief: the critic's biggest gap and next three, verbatim; the hard constraints below; and
  "commit early and often".
- It changes `tools/map_forge.py` and `tools/glacier_kit.py` (and `render_glacier.py`/`ZoneAir`/
  `GlacierAmbience` if the air is the gap), then regenerates.
- It validates, then pre-checks in Blender (`QUICK=1 python3 tools/render_glacier.py OUT view`).
- It reports parts count, light count and FAILs.
- Builders don't touch Studio. Only you sync and capture, so two agents never fight over the
  plugin.

**Merge.** `git merge` the builder's branch. On conflicts in generated `lemonade-map/**` files,
take either side and rerun `python3 tools/map_forge.py`; never hand-merge generated JSON. Validate.
Rojo syncs the result into Studio; check for duplicate scripts. Capture the piece's views.

**Critic, per piece.** A fresh Agent that sees only three images and no history:
1. Put our capture at `critic/<piece>_1.png`, a second angle at `_1b`, and the photo at `_2`, all
   resized to 860×484. The critic doesn't know which is ours.
2. The prompt: "one is a stylised Roblox game frame, one a reference; the brief is 'as striking as
   the reference but a cartoon toy look'; be harsh; praise is useless".
3. Required output:
   - **PICK**
   - **WHY**
   - **BIGGEST GAP** in the losing image
   - **NEXT THREE** concrete changes

   Only the next three go back to the builder.
4. If it picks ours, the piece is done. Log it and move on to polish.

Run the pieces in parallel: canyon and walls builders can run together, since they touch different
areas of `build_frostbound_glacier`. Expect merge conflicts in shared helpers; resolve by
regenerating.

## Hard constraints (unchanged)

- **Rojo and Studio.**
  - Sync to Studio only through Rojo, and only while Alex is at the PC. No stand-in HTTP syncs.
  - Ask before restarting Studio.
  - After any Rojo reconnect, check for duplicated scripts (`MeshSlots`, `GlacierAmbience`,
    `ZoneAir` and every other name once).
- **Generated files.** Never hand-edit `lemonade-map/LemonadeMap/*` or `map.project.json`'s
  generated parts. Everything goes through `tools/map_forge.py` / `tools/glacier_kit.py`. Anything
  tried by hand in Studio gets written back into a generator before it counts.
- **No voxel Terrain** in the Glacier. Floors stay `Grounds_FrostboundGlacier` slabs, because enemy
  ground raycasts need them.
- **Other regions.** They must regenerate byte-identical; the Glacier uses a private seed. Don't
  move spawns, gates, collision proxies or other markers outside the Glacier.
- **Validators.** 0 FAILs before every commit:
  - `rojo build map.project.json -o /tmp/m.rbxlx && python3 tools/check_map_project.py /tmp/m.rbxlx`
  - `python3 tools/audit_map.py /tmp/m.rbxlx FrostboundGlacier`: lanes clear, 20 PointLights or
    fewer
  - `rojo build default.project.json -o /tmp/g.rbxlx && python3 tools/check_gameplay_project.py /tmp/g.rbxlx`:
    PASS
  - `python3 tools/check_glacier_glb.py` if the kit changed; `tests/run.sh --quick`
- **The other session's files.** Another session may edit combat, swing, outfit, NPC-model and
  animation files. Don't touch or commit its work. Run `git status` before every commit and stage
  by path.
- **Blender.** Allowed any time, Studio open or not. Never re-run `tools/blender_boss_swords.py`
  (import its helpers only).
- **Model identifiers.** Keep them out of commit messages and docs.

## What's stale elsewhere

`GLACIER_STUDIO_PLAN.md` was written before the gauntlet:
- Its "cliffs ~46 tall" is now 100–215.
- Its view list predates the valley corridor and the canyon.
- Its "123 MeshSlots, 22 GLBs" is now more slots and 37 kit pieces.
- It assumes the dusk air. The render and ZoneAir moved to a bright afternoon, `FROST_SHARE` 0.7.
  The hamlet still glows amber.

`GLACIER.md` has some paragraphs duplicated by earlier merge resolutions. Clean it up once, and
bring its counts and air notes up to date.

## Done means

- The critic picks ours blind for walls and canyon, from **Studio captures**. Village is already
  won; re-confirm it in Studio, since it won under Blender dusk lighting.
- The meshes are imported and verified, and every kit piece has a GLB.
- The route is walked and fought end to end without camera leaks, stuck enemies or falls.
- The time-of-day check is done and decided with Alex.
- `GLACIER_GAUNTLET.md` shows every round.
- `GLACIER.md` is current and has a play-test note.
- All validators are green, and everything is pushed to `claude/magical-dirac-kww440`.
