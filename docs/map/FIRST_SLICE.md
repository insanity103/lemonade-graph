# First slice: Hearthmere → Iron Lowlands → Iron Warlord → sword → hub

Status (2026-09-15): geometry, markers, map-aware gameplay, travel and validation are implemented
and pass static/build checks. **Not yet playtested in Studio.** See "Verification" below.

![Top-down plan](first_slice_topdown.png)

## How to run it

The map lives in its own Rojo project so the gameplay-only baseline stays untouched.

```sh
python3 tools/map_forge.py                                   # regenerate lemonade-map/ + preview
rojo build map.project.json -o /tmp/lemonade-map.rbxlx
python3 tools/check_map_project.py /tmp/lemonade-map.rbxlx --report docs/map/VALIDATION.md
python3 tools/luau_balance_check.py lemonade-game
rojo serve map.project.json --port 34873                     # connect Studio's Rojo plugin to 34873
```

Use a **copy** of the baseplate place for map work (File → Save As). Rojo keeps unknown instances,
so a place that has been synced with the map project keeps `Workspace.LemonadeMap` and the map
scripts after disconnecting. The default project still works there: gameplay switches to map mode
whenever `MapMarkers` and `Workspace.LemonadeMap/Markers` are both present.

| Project | Adds | Mode |
| --- | --- | --- |
| `default.project.json` | gameplay only (18 server, 13 client) | baseplate |
| `map.project.json` | default + `Workspace.LemonadeMap`, `MapMarkers`, `MapTravel`, `MapClient` | map |

`tools/check_map_project.py` fails if `map.project.json` drops or changes any default mapping.

## Layout (studs; +X east, +Z south, floors rest on the Baseplate at Y=0)

| Area | Extent | Floor top | Contents |
| --- | --- | --- | --- |
| Hearthmere hub | x −100..100, z −100..100 | 10 | spawn (0,−40) facing the south gate; plaza + sword monument; Sword Shop (W), Skill Trainer yard (E), Rebirth Shrine (SE), Quest Master beside the south road (14,50); sealed gates W/E/N and Void Rift portal (NE) with visible vistas |
| Pass | x −14..14, z 104..140 | 10 | timber arch "Iron Lowlands · Lv 1–10" |
| Quarry Overlook | x −40..40, z 140..168 | 10 | safe staging area, waystone, route sign; 32-stud ramp down (14°) |
| Squire Yard | z 200..265 | 2 | 5 Squires Lv 1–3, spaced 35–41 studs; tents, campfire, scaffolds at the edges |
| Crusher Pits | z 270..360 | 2 | Squires Lv 3–4 + Berserkers Lv 3–5; rail line, crane, stone stacks |
| Side passage | x −167..−110, z 283..347 | 2 | optional elite Berserker Lv 6, supply cache (decorative for now) |
| Warlord's Gate | (0, 352) | 2 | waystone, boss sign; 40-stud gap in a rock ridge shows the boss early |
| Warlord's Pit | centre (0, 424), r 42 | 2 | Iron Warlord Lv 10, standing stones, braziers, banners |
| Briarwood gate | (0, 470) | 2 | sealed milestone "Lv 9+" with forest vista |

Measured on the navigation grid (`docs/map/VALIDATION.md`): spawn → Iron Lowlands gate 8.8 s
walking; first enemy 16 s (10 s running); boss 29 s (18 s); nearest-encounter spacing 1.6–2.6 s.
Merchant/trainer/quest/rebirth are 4–5.5 s from spawn.

## Decisions

- **Classic Parts, generated.** `tools/map_forge.py` is the source of truth; `lemonade-map/` is its
  output (do not hand-edit). Seeded jitter keeps cliffs irregular but reproducible.
- **Collision separate from visuals.** Cliff chunks never collide; `LemonadeMap/Collision` holds
  invisible wall proxies. Floors live in `Grounds_<Region>` so enemy ground raycasts hit only floors.
- **Flat combat floors,** height only at the overlook (staging) and the hub step; no terrain.
- **Every region has a readable entrance, landmark, enemy family and boss** (arch, crane, ridge gap).
- **Sealed destinations are visible,** not hidden: barred gates with level labels and a vista behind.
- **Existing identities kept.** Spawn markers reuse `IronSquire`, `IronBerserker`, `Boss_Gorgon` and the
  `IronLowlands` quest zone, so quests q1–q5, kill attribution, drops and saves are unchanged.
- **Zones without markers stay idle** in map mode (logged once), rather than falling back to the
  baseplate ring. Only Iron Lowlands has markers in this slice.
- **Travel:** discovering a waypoint (walk within 18 studs or use its waystone) unlocks it, saved in
  the `DiscoveredWaypoints` attribute. Waystones open a menu of discovered destinations; Return to
  Hub works from anywhere. The server validates discovery, waystone proximity, cooldown and combat.
- **Unlock rule (tuning assumption):** regions are gated by visible recommended levels only; the one
  playable region is open. Sealed gates are physical until their regions exist.

## Gameplay changes shipped with this slice (also active in the baseline)

- Enemy attacks telegraph: damage lands at the end of the swing (0.32 s, heavy attackers 0.5 s) and
  only if the target is still within reach + 1.5 studs, so stepping back after the raise avoids it.
- Every enemy shows name, level and a health bar (60-stud draw distance); elites are gold "★ Elite".
- Hub NPCs have nameplates and face the direction their markers give.

## Verification

| Check | Result |
| --- | --- |
| `rojo build` both projects | pass |
| `check_gameplay_project.py` (baseline contract) | pass: 18 server / 13 client, no environment services |
| `check_map_project.py` (schema, floors, overlaps, safe zones, aggro vs arrivals, camera clearance, reachability) | pass |
| `luau_balance_check.py` (63 files) | pass |
| Studio playtest: travel, sword hits, camera, rewards | **not yet run** |

## Known limitations / next

- Studio playtest outstanding: walk the loop, confirm ramp/roof orientation, prompt ranges, spawn facing.
- `canLeaveCombat` in `MapTravel.server.luau` decides the travel combat restriction (see TODO).
- Supply cache, collection hall and a travel-board UI in the hub are decorative/placeholder.
- No keyboard/controller shortcut for Return to Hub yet (button only; menu supports gamepad/touch).
- Region lighting is untouched (Lighting is not mapped by design).
