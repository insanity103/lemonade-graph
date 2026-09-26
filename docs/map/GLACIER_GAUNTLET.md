# Frostbound Glacier gauntlet: live progress

The bar: the three photos in `docs/map/glacier_refs/`. Ours must be more striking, and still read
as a toy. Each piece has a builder and a separate critic; the critic sees ours and the photo
unlabelled and picks one.

| Piece | Photo | Round | Critic's pick | Biggest remaining gap |
| --- | --- | --- | --- | --- |
| Ice walls and the range | glacier_valley | 2 | **ours** (on style only) | Won because the photo is off-style, not because ours is a great glacier: still a wall of similar blue boxes with little sky, no valley corridor; snow discs hover and fissure sticks read as bugs. Round 3: a corridor with sky and a pale range at its end, a few huge spires, ground the discs, receding lighter ranks. |
| Crevasse canyon and crystals | ice_canyon | 2 building | (round 1: photo) | Reads as a blue hallway: flat slabs in one mid-blue, no sky, no height. Wants walls 2-3x taller with an open sky slot, shading from white rim to navy floor, staggered ledges in three ice colours with snow caps, and deliberate crystal landmarks instead of a tumble. |
| Frost Hollow village | snow_village | 2 built, judging | (round 1: photo) | Round 1's gap was lighting: noon-bright, windows flat white. Round 2 lit it as dusk (in game and in the render), amber panes and pools, pond and fire ring in the foreground, smoke, figures, rows behind the front row, the arch deep with a glow rim. |
| Frozen river field | glacier_valley | 0 | (not judged yet) | |

## Log

- Round 0: starting frames are `docs/map/glacier_preview.png` (the zone as first built).
- Round 1, village: builder made a timber hamlet (lodge, 4 cabins, pond, lantern strings, ice shelves overhead, arch). Critic picked the photo. Gap: lighting/contrast. Next: chimney smoke and figures for life; break the empty foreground; layer roofs behind the front row; darken/saturate the arch.
- Round 2, village: the Glacier's air went to a deep saturated dusk blue (ZoneAir FROST_AIR, 85 % share) and the render now lights the same way (deep-blue world 0.33, low warm sun from the west, Neon at emission 6, a Blender point light at every map PointLight, exposure -1.25, Standard view). Window panes and lantern glass are amber Neon. Foreground: the skating pond moved to just inside the gate (saturated ICE_DEEP with a darker middle) with the skaters' fire ring and benches beside it under a lit lantern string; smoke puffs on every chimney and fire; three snow-people (shopkeeper on the lodge porch, a skater, one at the camp fire); falling snow in the village render. Depth: raised corner shelves (Y 14) carry two small cabins each behind the lodge and CabinSW, and four far roofs on mounds against the west cliff (Y 25-28) peek over them; the exit arch is recoloured a shade deeper with a GLOW rim on both faces. Village view now from the gate's arch with a 17 mm lens. 0 FAILs, 3,365 parts, 16 lights.
- Round 1, walls: builder made three ranks (banded, fissured cliffs ~72 tall; crags ~120 behind; ten peaks). Merged with the village; 0 FAILs, 3,061 parts.
- Round 1, walls: critic picked the photo. Gap: no skyline or height hierarchy; flat tint. Round 2 builder launched (peaks, contrast, chunky seracs, the frozen river).
- Round 2, walls: builder rebuilt the three ranks so they step up from the ground view. Walls halved in count and lowered (~55), each two or three fat deep-blue slabs (#1E5FD0) leaning back under pale overhanging seracs, long navy crevasse slots, snow mounds; rubble at every foot; crags ~170-200 tall a step paler; nine hazed pale peaks 220-290 on the apron's rim; a notch in the ridge's north wall with a peak behind it; a winding frozen river of floes over navy water from the ascent past the lake toward the stair and the notch. New render views `g_river` (eye height on the lake's shore, along the river to the notch) and `g_skyline`. 0 FAILs, 3,269 parts, 20 lights, lanes clear.
- Round 2, village: builder launched (dusk-blue air, amber windows, smoke, second row of roofs, pond and fire in the foreground; also the render script's lighting).
- Round 1, canyon: builder made layered leaning strata walls, geodes, an ice-block floor and a sunset cleft. Critic picked the photo. Gap: no height or tonal range. Round 2 builder launched.
- Round 2, walls: builder made deep-blue slab walls with navy fissures, seracs, giant crags, nine hazed peaks, a notch, rubble and the frozen river (3,269 parts, 0 FAILs). Judging.
- Round 2, walls: critic picked OURS, on style (the photo fails the toy brief). Its own list for ours: open a valley corridor with sky and a pale range at the vanishing point; a few huge spires instead of dozens of mid boxes; delete or ground the floating snow discs and dark stick lines; 2-3 receding ranks lighter with distance. Round 3 launched for those.
- Round 2, village: merged onto the walls and canyon (one rubble chunk under the new corner shelves dropped; the canyon's sunset light gave up its PointLight to stay at 20). 0 FAILs, 3,558 parts. Judging.
