# Iron Lowlands: the living oasis (2026-09-24)

Alex's brief: the Iron Lowlands looked empty, muddy and dead next to Briarwood and Hearthmere, with
ugly cliffs. The direction chosen was a **lush desert oasis**, with **no townsfolk** (it is an enemy
zone): the life comes from plants, water, animals, wind and sound. Gameplay did not move: every
spawn, gate, waystone, floor slab and collision proxy is where it was, and every new part is
decorative (no collision near play, none in the audit's lanes).

It sits on top of the other session's Iron Lowlands look pass (rock as SmoothPlastic parts in
`desert_rockforms`, the Salt/Concrete terrain, trail kerbs and trailside clusters in
`desert_sand_dressing`), which it keeps as it is.

## What was added

| Where | What | Code |
|---|---|---|
| Round both pools and in the open middles | 13 garden patches: palm groves (grown x1.8, tagged `Sway`), raised adobe flower beds (tagged `FlowerBed`), lemon bushes, ferns | `oasis_life`, `desert_bed` |
| The rim and mid bench | a bazaar lane: the lemonade stand facing the overlook, striped shade sails with benches, a pennant line over the trail's start, flower pots, hand carts, barrels | `lemonade_stand`, `shade_sail`, `pennant_line` |
| The pit's west | the bandits' quarter: two stake palisades, a lookout tower, loot piles, broken adobe walls, banners (tagged `Sway`) | `palisade`, `lookout`, `loot_pile`, `adobe_ruin`, `bandit_banner` |
| Every floor | 64 patches of flowering desert plants: a prickly pear, agave or blooming saguaro with dune grass and candy pebbles round it | `prickly_pear`, `agave`, `blooming`, `dune_grass`, `pebbles` |
| The basin's edge | toy boulders in the rock palette at the scarp's foot | `scarp_boulders` |

All of it is placed by `OasisPlacer` (tools/map_forge.py), which keeps every piece off the trail
(its centre line + 5), out of `audit_map.py`'s lanes, 9 studs from spawns and markers (tall pieces
are also run through `clearance_ok`, the validator's camera-headroom rule), off the Warden's arena
and the ridge across the pit, off bench steps, out of the pools, and off anything already standing.
Its seeds are private (`0xDE5E8`, `0xDE5EA`), so the Hub and Briarwood regenerate byte-identical.

**Runtime, client-only** (`lemonade-game/Map`, map project only):

- `OasisAmbience.client.luau`: 4 parrots wheeling over the pools and basin, 6 butterflies working
  the oasis flower beds, 5 dragonflies darting over the water, 3 tumbleweeds bowling across open
  sand, a slow sway on every `Sway` model near the camera (palms, banners), sparkles on the pools and
  sand wisps off the dunes. It idles when the camera leaves the basin. HubAmbience's butterflies now
  keep to the village's own beds.
- `ZoneAir.client.luau`: while the camera is in the basin by day, moves WorldLook's shade from the
  sky's blue-grey toward a warm sand bounce at the same brightness (the "muddy" grey shade sides).
  It also carries three ambience beds (desert wind, oasis water, bazaar chimes) cross-faded by
  position; **their SoundIds are empty until picked in Studio** (Toolbox > Audio), and empty means
  silent.

## Fixes made on the way

- Palm frond tips are joined to their fronds; the spring's runnels lie on the water sheet. These
  were the four long-standing floating FAILs; `check_map_project.py` now reports **0 FAILs**.
- `build_iron_lowlands` left the scrapped quarry mounds in the registry as "ground", so every later
  `floor_at` saw phantom floors; only the floors actually written stay now.
- `check_support` looked for neighbours against a part's centre column only; it now uses the
  part's full height (a drooping tip or leaning post joins at its end).
- Two trailside saguaros stood collidable inside a main lane; they are decoration now.

## Numbers

Iron Lowlands: about 3,750 parts (from about 1,280 before the look passes), 11 PointLights (budget
20). Whole map: 9,590 parts.

## Checking it

```
python3 tools/map_forge.py
rojo build map.project.json -o /tmp/lemonade-map.rbxlx
python3 tools/check_map_project.py /tmp/lemonade-map.rbxlx      # 0 FAILs
python3 tools/audit_map.py /tmp/lemonade-map.rbxlx              # lanes clear, lights <= 20
```

In Studio (with Alex, over Rojo): walk from the overlook to the Briarwood gate; check the frame rate
at the bazaar lane and over the pit; watch the wildlife and sway stop when you leave through the
gate; pick the three ambience SoundIds in `ZoneAir.client.luau`.
