# Frostbound Glacier gauntlet: live progress

The bar: the three photos in `docs/map/glacier_refs/`. Ours must be more striking, and still read
as a toy. Each piece has a builder and a separate critic; the critic sees ours and the photo
unlabelled and picks one.

| Piece | Photo | Round | Critic's pick | Biggest remaining gap |
| --- | --- | --- | --- | --- |
| Ice walls and the range | glacier_valley | 1 built, judging | | |
| Crevasse canyon and crystals | ice_canyon | 1 building | | |
| Frost Hollow village | snow_village | 2 built, judging | (round 1: photo) | Round 1's gap was lighting: noon-bright, windows flat white. Round 2 lit it as dusk (in game and in the render), amber panes and pools, pond and fire ring in the foreground, smoke, figures, rows behind the front row, the arch deep with a glow rim. |
| Frozen river field | glacier_valley | 0 | (not judged yet) | |

## Log

- Round 0: starting frames are `docs/map/glacier_preview.png` (the zone as first built).
- Round 1, village: builder made a timber hamlet (lodge, 4 cabins, pond, lantern strings, ice shelves overhead, arch). Critic picked the photo. Gap: lighting/contrast. Next: chimney smoke and figures for life; break the empty foreground; layer roofs behind the front row; darken/saturate the arch.
- Round 2, village: the Glacier's air went to a deep saturated dusk blue (ZoneAir FROST_AIR, 85 % share) and the render now lights the same way (deep-blue world 0.33, low warm sun from the west, Neon at emission 6, a Blender point light at every map PointLight, exposure -1.25, Standard view). Window panes and lantern glass are amber Neon. Foreground: the skating pond moved to just inside the gate (saturated ICE_DEEP with a darker middle) with the skaters' fire ring and benches beside it under a lit lantern string; smoke puffs on every chimney and fire; three snow-people (shopkeeper on the lodge porch, a skater, one at the camp fire); falling snow in the village render. Depth: raised corner shelves (Y 14) carry two small cabins each behind the lodge and CabinSW, and four far roofs on mounds against the west cliff (Y 25-28) peek over them; the exit arch is recoloured a shade deeper with a GLOW rim on both faces. Village view now from the gate's arch with a 17 mm lens. 0 FAILs, 3,365 parts, 16 lights.
- Round 1, walls: builder made three ranks (banded, fissured cliffs ~72 tall; crags ~120 behind; ten peaks). Merged with the village; 0 FAILs, 3,061 parts.
