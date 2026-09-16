# Gameplay on an existing baseplate

`default.project.json` syncs the gameplay systems into a new baseplate place.
It does not own Workspace, Terrain, Baseplate, SpawnLocation, Lighting, or ServerStorage.
It does not run the map reset or import any map art.

Included: starter sword, combat and combos, enemy AI and bosses, drops, weapon modifiers,
inventory, gold, XP, leveling, skill points, movement, quests, merchant, rebirth, skill resets,
player saving, audio, effects, onboarding, and the existing HUD and menus.

The `lemonade-game/Gameplay` modules adapt gameplay to the existing Baseplate. They only
read its position and size. Enemies retain their original identities, levels, and quest tags;
their temporary spawn positions fit on the plate. Quest Master, merchant, rebirth, and skill
reset characters stand near the center. No stalls, shrines, platforms, or decorative props
are created. Boss-room gates and their client script are omitted because there are no rooms.
The cosmetic villagers, leaderboard pillar, campfire, day/night controller, map builders,
collision decks and map anchors are also excluded.

## Connect

Run `rojo serve default.project.json` from this repository, then connect Studio's Rojo plugin
to `localhost:34872` and accept the gameplay sync. Start Play after synchronization finishes.
Use the new baseplate place; do not run `tools/reset_map_in_studio.luau` for this workflow.
That older utility is for clearing the previous map and is not part of this project.

## Verify in Studio

- Baseplate size, position, material, terrain, spawn, and lighting stay the same after sync and Play.
- Equip ClassicSword, attack an Iron Squire, and confirm XP, gold, and quest progress update.
- Approach Quest Master and merchant; open quests/shop, buy/equip a sword, and check inventory.
- Check rebirth in the existing menu and skill reset at Skill Trainer.
- Stop and restart Play; confirm no map appears and Output has no missing-module errors.

Saving uses the existing player-data service. A different experience has its own player data;
the old game's saved progress is not migrated. Studio/API permissions and restricted animation
or audio assets still need validation in the destination experience.

## Local validation

```sh
rojo build default.project.json -o /tmp/lemonade-gameplay-only.rbxlx
python3 tools/check_gameplay_project.py /tmp/lemonade-gameplay-only.rbxlx
git diff --check
```

The build and integration check verify packaged instances and dependencies, not Studio execution.
Future gameplay scripts must be added explicitly to the project so map code cannot enter sync
through a broad ServerScriptService folder mapping.
