# LemonadeMap marker schema (v1)

Gameplay reads these instead of embedding coordinates. Reader: `lemonade-game/Gameplay/MapMarkers.luau`.
Validator: `tools/check_map_project.py`. Generator: `tools/map_forge.py` (`build_markers`).

Every marker Part is Anchored, `Transparency = 1`, `CanCollide = CanQuery = CanTouch = false`.
Positions are **on the floor surface** (Y = floor top); rotation gives facing (LookVector).

```text
Workspace.LemonadeMap            Folder  attrs MapVersion, MapName
├─ Grounds_<Region>              Model   walkable floors/ramps (enemy ground raycasts use only these)
├─ Collision                     Model   invisible wall proxies (CanCollide, CanQuery=false)
├─ <Region>                      Model   visual geometry, attr Region; waystone models live here
└─ Markers                       Model   ModelStreamingMode = Persistent, attr SchemaVersion = 1
   ├─ PlayerSpawn                SpawnLocation (invisible, Neutral) → Player.RespawnLocation
   ├─ NPCs/QuestMaster|Merchant|SkillTrainer|RebirthKeeper      Part (position + facing)
   ├─ SafeZones/<name>           Part volume, attr Region — enemies never attack in or into these
   ├─ Regions/<RegionName>       Part volume, attrs DisplayName, Subtitle, Order (higher wins overlaps)
   ├─ EnemySpawns/<id>           Part, attrs below
   ├─ Waypoints/<id>             Part arrival point, attrs DisplayName, Region, Order, DiscoverRadius
   └─ Gates/<RegionName>         Part, attrs DisplayName, Region, Sealed, RequiredLevel
```

## EnemySpawns attributes

| Attribute | Type | Rule |
| --- | --- | --- |
| Archetype | string | key of `ENEMY_ARCHETYPES` in EnemyCombat |
| Level | number | integer ≥ 1 |
| Role | string | `minion`, `elite` or `boss` |
| Zone | string | a `WorldLayout.ZONES` name (quest zone) |
| Region | string | region the spawn belongs to |
| LeashRadius | number | ≥ 8; enemy returns home beyond this |

Validator rules: on a floor, 3 studs clear of solids (scaled by archetype), outside every safe zone and
at least patrolRadius + 6 from its edge; waypoint arrivals must be outside every spawn's
aggroRange + patrolRadius; nothing opaque 8–28 studs above spawns/arrivals (camera clearance).

## Waystones

Any model with attributes `Waystone = true` and `WaypointId = <Waypoints child name>`. MapTravel puts a
ProximityPrompt on its `Obelisk` part (or first BasePart). The obelisk must be within 20 studs of the
arrival marker. `HubSpawn` is the Return to Hub destination and is always discovered.

## Adding a region

1. Add a `build_<region>(rng)` to `map_forge.py` returning (ground, visual, proxies) and write its models.
2. Add spawns to `ENEMY_SPAWNS` with the existing archetype/zone identities; add waypoints + waystones.
3. Add `Regions/` and (if staging) `SafeZones/` volumes; flip its gate marker and gate model `Sealed`.
4. Regenerate, build, run `check_map_project.py`, then playtest before starting the next region.
