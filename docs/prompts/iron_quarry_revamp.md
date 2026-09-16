# Prompt: revamp the Iron Lowlands into an abandoned bandit quarry

Paste this to Claude Code in `~/lemonade-graph` (or the worktree). It is written for the
codebase as of `master` @ 81a0409.

---

You are working on the Lemonade Roblox RPG in this repo. Rebuild the **Iron Lowlands** region
(the first combat area south of Hearthmere) so it reads as a real, worked-out stone quarry that
was abandoned and is now squatted by a bandit gang. Also give this region's three enemies unique
bodies and outfits so they read as members of that gang, not coloured blocks.

## Ground rules (do not break these)

- The map is generated: edit `tools/map_forge.py` only, then run `python3 tools/map_forge.py`.
  Never hand-edit `lemonade-map/`. Keep the region inside `build_iron_lowlands()` and its
  helpers; hub code stays untouched.
- Keep every gameplay identifier: archetype keys `IronSquire`, `IronBerserker`, `Boss_Gorgon`,
  zone `IronLowlands`, spawn ids `IL_*`, waypoints `IronOverlook` / `WarlordGate`, gate marker
  names. Quests, drops and saves depend on them. Display names, colours, outfits and geometry
  are free to change.
- Classic Parts and WedgeParts only, no MeshParts, no Terrain, no external asset ids except the
  catalog shirt/pants ids already verified in `EnemyCombat.server.luau` (`TEXTURE_SETS`). Fire
  and Smoke objects are fine.
- Floors go in `Grounds_IronLowlands` (that is what enemy ground raycasts and the navmesh
  validator use). Walls players must not pass get an invisible proxy in `Collision`; visual
  cliff chunks never collide. Decoration is `CanCollide=false` unless it is meant to block.
- The validator is the contract. After every regeneration run:
  ```sh
  rojo build map.project.json -o /tmp/lemonade-map.rbxlx
  python3 tools/check_map_project.py /tmp/lemonade-map.rbxlx --report docs/map/VALIDATION.md
  python3 tools/luau_balance_check.py lemonade-game
  rojo build default.project.json -o /tmp/b.rbxlx && python3 tools/check_gameplay_project.py /tmp/b.rbxlx
  ```
  It enforces: no coplanar overlapping tops (z-fighting), spawns on floors and clear of solids,
  spawns outside safe zones by patrol radius + 6, waypoint arrivals outside aggro + patrol
  reach, camera clearance 8–28 studs above spawns and arrivals, every NPC/spawn/waypoint
  reachable from the hub spawn, gate blockers for sealed gates. All must pass.
- Walk-time targets from `docs/map/FIRST_SLICE.md` still apply: first enemy within ~16 s
  walking from the hub spawn, boss under ~30 s, encounters 1.5–3 s apart, no beginner maze.
- Studio is not reachable from the agent. Verify with the checks above plus the top-down
  preview (`docs/map/first_slice_topdown.png`) and, for new models, a quick Pillow render like
  the ones used for the stall and well (see this session's history in `docs/map/FIRST_SLICE.md`).

## Design brief

**Concept.** A benched open-pit quarry cut into warm sandstone, worked for iron-bearing stone
and abandoned when the seam ran out. Bandits moved into the machinery sheds and the deepest
pit. Everything should look *used*: worn haul roads, drainage, rust, broken timber, and the
gang's improvised comforts on top of the ruin.

**Real-quarry structure (replace the flat 220×304 slab).**
- Terraced benches: three or four stepped levels descending from the Overlook (Y 10) to the
  pit floor (keep the boss floor at Y 2 or lower), each bench 12–18 studs deep with a 6–8 stud
  face, connected by wide haul ramps (≤ 15°) rather than stairs. Ramps and benches are floors
  in `Grounds_IronLowlands`; bench faces are visual chunks with a proxy behind them.
- A spoil heap or two (piled rubble mounds, non-collide rocks on a collidable low mound).
- Drainage sump at the lowest corner: a stone-rimmed pool of still brown water, mud stains
  (darker slab patches) leading to it.
- Haul road: packed earth strip with cart ruts (two thin darker strips), from the ramp down to
  the boss pit; rail spur with a derailed cart and bent rails.
- Cut faces with visible bench lines (stepped ledges every 6 studs) and drill-hole rows
  (small dark cylinders in a line) on one dramatic wall.

**Abandoned machinery and structures (used, broken).**
- Head-frame / crane: tall timber A-frame with a snapped boom and a dangling hook.
- Ore chute / hopper: timber trough on legs, half collapsed, spilling grey rubble.
- Crusher house: a stone-walled shed with a caved roof (wedges sagging), rusted flywheel
  (cylinder) and belt.
- Blacksmith lean-to ruins, empty barrels, broken carts, a collapsed scaffold, ladders.
- Rust everywhere on metal (`CorrodedMetal` material, orange-brown), splintered timber
  (`Wood` darkened), moss on the north faces (thin green plates).

**Bandit occupation (life on top of the ruin).**
- Camp in the crusher house and the side passage: tents, bedrolls, a cooking fire with a
  spit, hanging lanterns, crates of loot, a lookout platform on the head-frame with a
  bandit banner (rag on a pole, torn), skull-and-blade sign at the ramp foot: "TURN BACK".
- Barricades made of quarry timber and cart wheels across the haul road; a gate of scrap
  iron at the boss pit (visual only, the boss must still be visible before aggro).
- Loot cache (decorative) and a stolen Hearthmere cart.
- Warlord's Pit becomes the bandit boss's throne: a seat built from cart parts on a stone
  block, banners, braziers, chained hostages' empty manacles on the wall (props, no gore).
- Keep the optional side passage with the elite as the gang's "back door" hideout.

**Enemy family: the Quarry Bandits.** In `EnemyCombat.server.luau`, give the three
archetypes new display names and looks that share a language (rust, leather, rag) and read at
a glance as light / heavy / boss:
- `IronSquire` → "Quarry Cutthroat": lean, fast, hooded, cloth mask, single rusty pick or
  short blade, leather vest, wrapped forearms.
- `IronBerserker` → "Pit Brute": broad, slow, iron pauldron made from a cart plate, chain
  belt, heavy sledge (two-handed pose), bare arms, scars (darker stripes).
- `Boss_Gorgon` → "Warden of the Pit" (keep `uniqueDrop = "Warlord Greatsword"` and the
  boss weapon mesh path): armoured in scavenged plate, helmet with a horsehair crest, cape
  of stitched banners, the existing sword mesh, a lantern on the hip.
  Elite spawn `IL_E1` gets a variant: same brute with a red sash and skull mask.

Implement looks with anchored accessory parts placed relative to the rig's body parts, the same
way `ReplicatedStorage/NpcOutfits.luau` dresses hub NPCs (specs of `{part, size, offset,
color, material, shape}`), extended into an `EnemyOutfits` table keyed by archetype and applied
inside `createEnemyRig` after the Motor6Ds exist. Enemy rigs are unanchored humanoids that
walk, so accessories must be **welded** (`WeldConstraint` to the body part, `Massless`, no
collision) — the opposite of the hub NPC case, where the server never moves the rig. Keep
`TEXTURE_SETS` shirts/pants as the base layer; accessories add silhouette. Scale accessories by
the archetype `scale`. Keep boss nameplates and health plates working (the `Head` part is
still the plate's parent). Do not change stats, ranges or the swing timing.

**Sound and light.** Wind through the pit is not available (no new audio ids); use existing
`AudioManager` keys only. Light: braziers and lanterns at the camp, a low orange glow in the
crusher house, cold blue-grey elsewhere; keep total PointLights in the region under 20.

## Audit the result (same method as the Hearthmere audit)

After the build passes the validator, run the deeper audit that produced `docs/map/AUDIT.md` on
the Iron Lowlands region and fix what it finds before committing. Reuse the checks from that
session (they load the built `.rbxlx` through `tools/check_map_project.py`'s `Node`/geometry
helpers; consider promoting them into a `tools/audit_map.py` so they can be re-run):

1. **Property census** for `LemonadeMap.IronLowlands`, `Grounds_IronLowlands` and the region's
   `Collision` proxies: part count by class, unanchored parts (must be 0), collidable vs
   decorative counts, PointLight / Fire / Smoke / SurfaceGui counts.
2. **Full-volume overlaps between different models** among collidable, opaque parts: list every
   pair with more than ~8 studs³ of intersection, excluding intentional grounding (rocks sunk
   ≤ 0.6 into floors, foundations in floors). Any prop clipping into a structure, a bench
   face, a ramp or another prop is a defect: move or resize it.
3. **Props buried in cut faces**: any opaque non-cliff part whose centre lies inside a bench
   face or cliff chunk. Half-set-into-rock is fine only when it reads that way from the play
   side (lip rocks, wall braziers); machinery and camp props must not.
4. **Floating entities (search every visible part, not just collidables)**: for each opaque
   part in the region (props, rubble, crates, tents, barrels, fences, ladders, banners, rocks,
   trees, machinery pieces, lanterns, signs, markers' visual companions) find the floor top
   under its centre and check that its bottom is within 0.4 studs of it, **or** that it is
   supported: resting on another part whose top is within 0.4 studs of its bottom and whose
   footprint covers its centre or an edge, attached to a wall/post it intersects (a bracket,
   a shelf, a sign chain, a bench face), or hanging from a part above it it intersects. Also
   catch the opposite: parts sunk more than 0.6 studs below the floor (only rocks may sink,
   and no deeper than 0.6). Every hit is a defect. Fix them at the source in `map_forge.py`,
   not by hand: add a `ground(part_spec)` helper that resolves the floor height under an
   (x, z) from the `Grounds_*` slabs, benches and ramps (use `top_at`-style math on the
   generated floor list, including ramp slopes) and places props at `floor + height / 2`;
   make every prop helper (`rock_cluster`, `crate_stack`, `barrel`, `tent`, `scaffold`,
   `hay_bale`, `campfire`, `lamp_post`, `sign`, `stone_stack`, `mine_cart`, `rail_track`,
   `fence_run`, `tree`, `bush`, `stump`) use it instead of a caller-supplied Y, so a prop
   placed on a bench, a ramp or the pit floor lands correctly wherever it is put. Spawn
   markers, waypoints and NPC markers must also sit on the resolved floor (the validator
   already fails those; keep them passing). Re-run the search after the fix; the list must be
   empty except for deliberate hangers (dangling hook, sign chains, lanterns on brackets),
   which must each be attached to something.
   Promote this search into `tools/check_map_project.py` as a permanent rule (report the
   part path, its bottom, the floor under it and the gap), so future props cannot float.
5. **Seams and gaps**: adjacent floors and ramps must meet within 0.05 studs (no grass or
   void strip between bench, ramp and haul road); parallel faces closer than 0.1 studs
   (window glass on walls, plates on posts) must be separated or merged.
6. **Terrain and grounding**: the region uses no Smooth Terrain; confirm every floor rests on
   the Baseplate (bottom Y 0) or on another floor, and every ramp's ends meet their benches
   flush (top and bottom). Report every ramp grade; none above 15°.
7. **Collision fidelity and physics**: all Parts/WedgeParts (no MeshParts or unions to
   downgrade); no `CanCollide=false` on something that must block (bench faces without a proxy
   behind them, barricades that are meant to block the road); no `CanCollide=true` on pure
   decoration (rubble, banners, moss plates, lanterns).
8. **Streaming and hierarchy**: the region model stays `ModelStreamingMode = Default` (not
   Atomic like the hub); new sub-structures are their own named models under `IronLowlands`;
   part count and PointLights reported against the budget (≤ 20 lights).
9. **Navmesh and lanes**: the validator's reachability table plus a check that no collidable
   prop sits inside the two main lanes (ramp → haul road → pit) or within 4 studs of a spawn.
10. **Enemy rigs and accessories**: after the enemy outfits are in, confirm in the source that
    every accessory is welded to a body part (not anchored), massless, non-collide, and that
    its offset keeps it inside 1.5 studs of that part so it cannot appear to float beside a
    walking rig; the boss weapon weld still sits in the right hand.

Write the findings to `docs/map/AUDIT.md` as a new dated section with the same three parts as
the Hearthmere one: **Critical errors**, **Moderate warnings** (with what was fixed vs
accepted), and **Actionable fixes applied** with file paths. Zero critical errors is the bar
for committing.

## Deliverables

1. `tools/map_forge.py`: new/replaced helpers (`bench_face`, `haul_ramp`, `spoil_heap`,
   `head_frame`, `ore_chute`, `crusher_house`, `bandit_camp`, `barricade`, `throne`, ...)
   and a rewritten `build_iron_lowlands()`; spawn markers moved onto the new floors with the
   same ids, roles and levels; waypoints and gates relocated as needed.
2. `lemonade-game/ServerScriptService/EnemyCombat.server.luau`: new display names and an
   `EnemyOutfits` application step; `ReplicatedStorage/EnemyOutfits.luau` (new module).
3. Regenerated `lemonade-map/`, updated `docs/map/first_slice_topdown.png` and
   `docs/map/VALIDATION.md`, a section in `docs/map/FIRST_SLICE.md` describing the new
   layout with a dimension table, and `docs/map/MARKERS.md` if any marker attribute changes.
4. All four checks green and the audit section written with zero critical errors. Commit in
   three steps (map, audit fixes, enemies) with descriptive messages.
5. In the final message: what changed, the walk-time table, part/light counts for the region,
   and anything that needs a Studio playtest to confirm (ramp grades, accessory placement on
   walking rigs, boss visibility from the ramp foot).

Work in tested stages: benches and ramps first (validate), structures second (validate), camp
and enemies last. Do not touch Hearthmere, the hub scripts, or any other region.
