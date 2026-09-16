# Map audit — Iron Lowlands bandit quarry (2026-09-16)

Scope: `Workspace.LemonadeMap.IronLowlands`, `Grounds_IronLowlands` and the region's `Collision`
proxies in the built `map.project.json` output, after the quarry revamp. Method: the validator
(`tools/check_map_project.py`, now with the support rule) plus `tools/audit_map.py`, which
re-runs the deeper checks from the Hearthmere audit against the built `.rbxlx`: property census,
cross-model collidable overlaps, props buried in cut faces, parts sunk into floors, floor seams and
ramp grades, collision fidelity, streaming, light budget, lane and spawn clearance. No Studio
session; nothing here is a rendered observation (oblique Pillow renders from
`tools/preview_model.py` were used to eyeball the new models).

Census: 781 parts (779 Part, 2 WedgePart), 17 floors, 23 wall proxies, 0 unanchored, 157
collidable / 624 decorative, 17 PointLights (budget 20, all `Shadows=false`), 5 Fire, 0 Smoke,
6 SurfaceGuis, region model streaming `Default`.

## Critical errors

None after the fixes below. Specifically:

- Floating entities: the new validator rule checks every visible part (2,704 in the map) for a
  floor within 0.4 under its centre or its lowest corner, a part it rests on or hangs from
  (within 0.4), or a part it touches (0.12 tolerance). First run: 41 floating, 10 buried. Now
  0 / 0, with `FloatShard` pieces exempt because HubAmbience orbits them by design.
- Coplanar tops, spawns on floors and clear of solids, camera clearance, reachability: pass.
- Buried props: no prop centre inside a cut face or cliff chunk (bench-line ledges and drill
  holes are exempt; they are meant to be set into the rock).
- Lanes: no collidable part in the rim → ramp 1 → road → ramp 2 → gap corridors (open halves of
  the barricaded segments); nothing collidable within 4 studs of a spawn.

## Moderate warnings

| # | Issue | Where | Fix / decision |
| --- | --- | --- | --- |
| 1 | Cliff ledge caps hovered 0.2–1.2 studs above their chunk (free_top bumps moved the cap up, the chunk did not follow). 7 in the hub, 3 in the quarry. | `cliff_run` caps | Cap now extends 0.6 below the chunk top and overlaps it by 1.5 studs in depth. Hub cliffs change by that much; nothing else in the hub moved. |
| 2 | Door handles floated 0.2 in front of the wall, off the recessed leaf; shelves 0.05 off the wall; the smithy sign bracket 0.4 off the wall; gate sign boards 0.7 clear of the lintel. | `timber_house`, `smithy`, `gate` | Handles 0.05 into the leaf (they already swing with it in HubAmbience), shelves 0.1 into the wall, bracket into the wall, gate boards tied to the lintel with four small brackets. |
| 3 | Bench-face lip chunks were centred behind the slab face: 5 were entirely inside the upper slab (invisible) and the rest showed only a jittered sliver. | `bench_face` | Chunks now straddle the face 2.6 studs proud and collide (rock toe). |
| 4 | Scrap gate leaves stood on the haul road inside the ridge chunks; the Warden sign overlapped a leaf; the WarlordGate waystone base touched road E. | `ScrapGate*`, `WardenSign`, `WarlordWaystone` | Leaves hinged at x ±18.3 and folded flat against the ridge ends (gap 36 studs, boss still visible); sign to (36, 360); waystone to (12, 352), 13 studs from the arrival. |
| 5 | Sump's south curb was hidden inside the ridge. | `Sump.CurbS` | Sump shortened to z 364. |
| 6 | Briarwood gate pillars sat inside the south cliff runs (same defect as the hub gates in the last audit). | `PitSouth*` | Runs stop at x ±19.5. |
| 7 | Head-frame moss plates hung beside the leaning legs; boom stub started outside the apex; broken cart side floated off its tilted bed; side-arch lantern hung beside the beam; ladders stood inside the rock toes; a rock cluster clipped a toe chunk. | `head_frame`, `broken_cart`, `SideArch`, ladders, `MidRocks0` | Positions computed from the parent geometry; lantern hangs on a chain from the beam; ladders' feet 3.6 out with tops on the toe; rocks moved. |
| 8 | Two rocks in one cluster rolled equal heights (coplanar tops, z-fight). | `rock_cluster` | Heights de-duplicated per cluster. |
| 9 | Haul road decals stand 0.2 proud of the benches (18 edge steps of 0.15–0.25). | `HaulRoad*` | Accepted: below the character auto-step; same as the previous quarry path. |
| 10 | Ramp ends meet the benches within 0.07 (ramp bodies are 0.4 longer than their run). | `HaulRamp1/2` | Accepted (< 0.1). Grades 10.3°, both ≤ 15°. Ramp undersides sit inside the lower bench slab. |
| 11 | Rock clusters sink 0.6–0.64 (tilted rocks), derailed cart wheels dug in 0.5. | `*Rocks*`, `DerailedCart` | Accepted: rocks are meant to sit in the ground; nothing else sinks > 0.6. |
| 12 | One cross-model collidable overlap: the two mid-bench toe runs meet at the sump corner (30 studs³). | `MidFaceE_00` / `MidFaceSump_04` | Accepted: same as cliff runs meeting at corners. |

## Actionable fixes applied

`tools/map_forge.py` (regenerated `lemonade-map/`, all four checks pass):
- `floor_at()` resolver; every prop helper, the bandit/quarry helpers and the `IL_*` spawn markers
  use it (`AUTO_GROUND` is on only while the quarry and markers build, so the hub is unchanged
  apart from items 1–2 above).
- Items 1–8 above.

`tools/check_map_project.py`:
- `check_support()`: floating / buried search promoted to a permanent rule (reports the part path,
  its bottom, the floor under it and the gap). `vertical_extent`, `bottom_at`, `touches` helpers;
  `Node.streaming` read from `ModelStreamingMode`.

`tools/audit_map.py` (new): the deeper audit as a re-runnable script:
`python3 tools/audit_map.py /tmp/lemonade-map.rbxlx IronLowlands`.

`tools/preview_model.py` (new): oblique render of any XZ box of the generated map.

## Recommended next (not applied)

1. Hub PointLights are still 74; the quarry's 17 are within budget. The hub reduction from the
   previous audit remains open.
2. Playtest: ramp grades under the camera, the rock toes under the player's feet (collidable,
   2.6 studs proud), boss visibility from the ramp-2 foot through the 36-stud gap, and whether
   the 0.2 road lips are felt.

---

# Map audit — Hearthmere + Iron Lowlands (2026-09-15)

Scope: the built `map.project.json` output (`Workspace.LemonadeMap`, 2,455 parts, generated by
`tools/map_forge.py`) plus the project layout. Method: static analysis of the built `.rbxlx`
(property census, full-volume overlap search between models, floor/support checks, streaming and
effect counts) on top of the checks `tools/check_map_project.py` already enforces. No Studio
session was available, so nothing here is a rendered observation.

Facts that frame the findings:

- Everything is `Part`/`WedgePart` (no MeshParts, no unions, no Smooth Terrain). Collision
  fidelity is therefore box/wedge everywhere; there is nothing to downgrade from
  `PreciseConvexDecomposition`.
- 0 unanchored parts. 432 collidable parts; 2,017 decorative parts with `CanCollide=false`.
  26 invisible wall proxies are collidable with `CanQuery=false`, so raycasts (enemy line of
  sight) see the visual cliffs instead.
- Terrain: the map never touches `Workspace.Terrain`. Floors are slabs resting on the place's
  Baseplate (top Y=0). Hub floor top Y=10, quarry floor top Y=2, joined by a 14° ramp.

## Critical errors

None found. Specifically checked and clean:

- Coplanar overlapping top faces (z-fighting): validator rule, 0 hits after the round-floor and
  cliff-top fixes. Roof gable wedges lie inside the slab's lower half (no poke-through).
- Movement: every NPC, spawn and waypoint is reachable from spawn on a 2-stud navmesh
  approximation; no collidable prop blocks a road; door mid-rails no longer cross doorways.
- Floating collidables: the only candidates are wall proxies (invisible by design), lintels and
  table/bench tops carried by their own legs or pillars, and the Ascension vista steps behind a
  sealed gate. Nothing a player can stand under and see float.

## Moderate warnings (fixed in this pass unless noted)

| # | Issue | Where | Fix |
| --- | --- | --- | --- |
| 1 | Corner bastion rocks (22-stud cubes at the four hub corners) intersected the back corner of HouseNW1 and HouseSW walls (≈50 studs³ each): rock visible through the interior corner. | `Hub.CornerBastion` vs `HouseNW1.WallW`, `HouseSW.WallW` | Bastions shrunk to 18 studs; no house contact. |
| 2 | Boulder cluster inside the Frostbound gate's south pillar (32 studs³). | `Hub.HubBoulder0` vs `GateFrostbound.Pillar-1` | Boulder moved to (−94, −34). |
| 3 | All eight gate pillars sat half inside the perimeter cliff runs (cliff chunks jitter ±4°, so chunk faces cut through pillar faces). | `Hub.Gate*` pillars vs `HubCliff*` | Cliff runs now stop at the pillars' outer faces (gap half-width 19.5 instead of 12). |
| 4 | 0.5-stud grass seam between the smithy paving and the shop-yard paving. | `Smithy.Paving` / `Grounds_Hub.ShopYard` | Paving extended to z −18. |
| 5 | Window glass 0.05 studs from the wall face (parallel, near-coplanar → flicker at distance). | `timber_house` windows | Glass moved to 0.15 studs proud. |
| 6 | Rock clusters are sunk 0.6 studs into floors on purpose (grounding); several sit up to 125 studs³ inside the quarry floor. Hidden, but they count against collision volume. | `IronLowlands.YardRocks*`, `PitRocks*` | Not changed. Acceptable; revisit if physics cost matters. |
| 7 | Waterfall pool rock 0 and the lip rock are embedded in the east cliff chunk. Reads as "set into the cliff" from the play side. | `Hub.Waterfall` | Not changed. |

## Layout and performance

| Item | Value | Note |
| --- | --- | --- |
| Parts | 2,455 (Hub 1,896, Iron Lowlands 438) | Fine for a hub; keep future regions in their own models. |
| PointLights | 74, all `Shadows=false` | High for one 200×200 area. Roblox caps active lights per view; low-end devices will drop some. Recommend ≤ 40: drop window lights on the two houses farthest from spawn and the candle lights indoors, keep Neon materials for glow. |
| Fire / Smoke | 12 / 7 | Legacy particle objects; each is a small cost. OK at this count. |
| SurfaceGuis | 26 | Signs; `MaxDistance=260`. OK. |
| Streaming | `Hub` model Atomic (1,896 parts), `Markers` Persistent | Atomic means the whole hub arrives in one burst on join; correct for the spawn area. Do not make Iron Lowlands atomic. |
| Hierarchy | `LemonadeMap/{Grounds_*, Collision, Hub, IronLowlands, Markers}` | Clean. Decorative parts inside named models; floors and proxies isolated for raycast filtering. |

## Repository layout

- `lemonade-game/ServerScriptService/` still holds 11 legacy scripts that no project maps
  (`WorldBuilder.server.luau`, the old `WorldLayout.luau` with terrain fills, `MapAnchors`,
  `CollisionLayout`, `BossRoomGate`, hub decor scripts, a `.bak`). They cannot leak into a build
  because both projects map scripts explicitly, but they confuse the graph and reviews.
  **Recommendation:** move them to `legacy/ServerScriptService/` (no project change needed).
- `lemonade-map/` is generated. Do not hand-edit; change `tools/map_forge.py` and regenerate.

## Actionable fixes applied

`tools/map_forge.py` (regenerated `lemonade-map/`, validator passes):
- `CornerBastion` 22 → 18 studs.
- `HubBoulder0` → (−94, −34).
- Perimeter cliff segments end at ±19.5 around each gate.
- Smithy paving z extent +0.5.
- Window glass offset 0.2 → 0.3 from the wall face.

## Recommended next (not applied)

1. Reduce PointLights to ≤ 40 (see table).
2. Move legacy scripts to `legacy/`.
3. Add a validator rule for cross-model collidable overlaps above ~20 studs³ excluding
   `Grounds_*`, rocks and bastions, so future props cannot clip into buildings unnoticed.
4. Playtest pass for anything static analysis cannot see: material tiling seams on long slabs,
   shadow acne on the cliff chunks, and the ramp's 14° grade under the player camera.
