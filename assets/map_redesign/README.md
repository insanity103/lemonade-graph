# Fivefold Sanctuary

Blender redesign of Lemonade Sword RPG, authored for the September 13 request: a large circular safe hub, five outward branches, one clearly defined region per main boss, and a rebirth NPC station. This is the Part 2 asset delivery. The live game scripts are unchanged; the integration files are outside the active Rojo tree.

## Open the design

- `FivefoldSanctuary.blend`: editable master scene, named cameras, hidden prop library, and named gameplay empties.
- `previews/01_world_overview.png`: whole-world view.
- `previews/02_top_down.png`: spatial layout.
- `previews/03_sanctuary.png`: central hub.
- `previews/04_rebirth_pavilion.png`: modeled Keeper of Renewal and station.
- `previews/05_spawn_view.png`: first-person-height entrance read.
- `previews/06_IronLowlands.png` through `10_CelestialSummit.png`: region views.
- `exports/`: modular GLBs; `manifest.json` records their mesh counts, triangle counts, and roles.
- `FivefoldSanctuary.glb`: whole-map review export. Do not import this AND the modular exports into the same place.
- `anchors.json` / `MapAnchors.luau`: matching placement contract in Roblox XYZ studs.
- `CollisionLayout.luau`: simple collision decks and walls, separate from decorative meshes.
- `sky/`: six original clear-day cubemap PNGs and an optional `lighting.json` reference. These require texture upload and face-orientation review in Studio.
- `validation.json`: measured geometry/placement checks and remaining Studio limitations.

## Layout and scale

The hub is **360 studs in diameter**, compared with the old 52-stud plaza. Its enemy exclusion radius is **195 studs**. Five gates are spaced **72 degrees** apart around the circumference. Each leads across a **28-stud-wide**, **128-stud-long** stone bridge, then through a regional threshold into four linked enemy clearings. Each main boss has a separate **68-stud circular court** at radial distance **550 studs**, with a **14-stud gate** facing the hub.

| Branch, clockwise from north | Entry level | Main boss | Region silhouette | Retained secondary content |
| --- | ---: | --- | --- | --- |
| Iron Lowlands | 1 | Gorgon, 10 | Mossy twin watchtowers and guardian gate | Briarwood / Root Warden, 8–14 |
| Frostbound Glacier | 15 | Frost Revenant, 25 | Jagged ice crown and snow pines | Sunken Marsh / Drowned Bellwarden, 23–29 |
| Infernal Caldera | 30 | Infernal Colossus, 45 | Volcano, forge stacks and ember channels | Stormwatch / Tempest Warden, 40–48 |
| Void Rift | 50 | Void Wraith, 70 | Open rift ring and fractured obelisks | Rift Summit Steps enemies, 70–74 |
| Celestial Summit | 75 | Celestial Titan, 100 | Ivory sun temple, gold spire and swept wings | Solar elite alcove |

Each island is approximately **318 × 460 studs**, with an irregular shore and lowered cliff skirt. Twelve ordinary enemy anchors per region form four farming groups, followed by the main arena's boss, four minions, and elite. Three secondary arenas preserve the existing level-gap enemies and internal IDs; they do not create extra hub branches. The full contract has **108 enemy anchors**. These are spawn placements, not modeled enemies or a tested concurrent-enemy budget.

At an assumed walking speed of 16 studs/second, hub center to the first enemies is about 22 seconds, center to a boss court about 34 seconds, and opposite edge to edge across the hub 22.5 seconds. Travel times exclude fights and player detours. Actual movement tuning should be measured in Studio.

## Part 2 analysis

The framework mixes estimated sizes from very large Roblox games (1,500–3,000-stud hubs and 300–800-stud boss areas) with this game's concrete **68-stud arena** and **14-stud doorway** requirements. Those research estimates are not mandatory dimensions for this five-boss game. Applying them literally would create several minutes of empty walking and require changing combat scale. This design expands the public space substantially while preserving the actual encounter dimensions.

The old eight-zone S-curve is now five independent branches. **Keep all eight zone IDs.** Folding Briarwood, Sunken Marsh, and Stormwatch into secondary pockets preserves their bosses/enemies and avoids removing progression content. Branches must remain independent polylines: concatenating their waypoints would draw roads across the water and through other territories.

Research influence: `research/sword-rpg/sword-rpg-world-design.md`, especially the distinct-island silhouettes, safe service areas, grouped ordinary enemies before bosses, and optional discoveries. Its competitor statistics are research notes, not newly verified gameplay claims. The Roblox map design skill supplied the entrance/teach/escalate/recover structure below.

Roblox's current [mesh specifications](https://create.roblox.com/docs/art/modeling/specifications) cap individual meshes at 20,000 triangles and require solid geometry. This package uses closed meshes, material batches divided by spatial area, and separate collision proxies. [Roblox's Blender guidance](https://create.roblox.com/docs/art/blender) documents glTF export and importer scale/orientation settings.

## Player beats

| Beat | Built experience |
| --- | --- |
| Entrance read | Spawn south of the central sunstone; the teal QUESTS stand is close by, with five numbered gates visible around the circle. |
| Teach | Talk to the quest giver, follow the first regional gate and bridge, meet the weakest enemies in paired clearings. |
| Escalation 1 | Move from the front groups into the tougher rear groups; the central trail provides a readable retreat route. |
| Escalation 2 | Explore a branch's secondary pocket or elite alcove; the higher-level enemies remain visually contained. |
| Escalation 3 | Enter the separate gated boss court beneath the dominant landmark. |
| Checkpoint | Return to the sanctuary for quests, trade, recovery and rebirth; return anchors are supplied at the regional bridgeheads for later activation. |
| Mastery path | An accessible relic ledge in Iron Lowlands and a screened archive in Void Rift reward looking off the central path. Reward logic is not included. |
| Exit / handoff | Return along the same bridge, reorient from the hub's compass layout, and select the next numbered branch or speak to the Keeper. |

## Rebirth station

The Keeper of Renewal stands in a gold-trimmed, open pavilion at **(-98, 6.3, 32)**. A sunstone, halo, offering bowls, floor inscription and REBIRTH sign distinguish it from the relic stall. The NPC is a static, original modeled character, exported independently for replacement or future rigging.

`integration/RebirthStation.server.luau` creates a 12-stud **Talk** prompt and checks the player's distance on the server. Its remote opens the existing rebirth panel using `integration/MainMenuRebirthHook.luau`. Talking does **not** trigger a rebirth immediately. The existing button and `RebirthSystem.server.luau` keep authority over requirements and execution.

The current rebirth implementation resets level, XP and gold; this differs from the aspirational additive-progression rule in `DESIGN_RULES.md`. This asset task does not change those mechanics. Keep the panel's consequences accurate when wiring the conversation.

## Blender to Studio handoff

1. Save a copy of the Studio place. Import `Kit_ScaleReference.glb` first and verify its gold bar is **10 × 1 × 1 studs**. Use **Scale Unit: Stud**. The authored transform is Blender `(x,y,z) = Roblox (X,-Z,Y)`; glTF's Y-up export restores Roblox XYZ. Preserve file positions and orientation. Verify a known non-symmetric anchor such as the rebirth station before importing everything. Do not recenter each island on insertion.
2. Create `Workspace.FivefoldSanctuary`; set its `MapRedesignVersion` attribute to `1`. Import `Hub`, the five `Branch_`, `Terrain_`, `Grounds_`, `Landmark_` groups, eight `Arena_` groups, three `Pocket_` groups and three `NPC_` exports into this model. `Kit_` files belong in an asset library/ServerStorage, not the live world. They include five biome tree/crystal and rock variants at LOD0/LOD1. Keep the ocean visual optional and non-collidable.
3. Set all imported visual parts to anchored. Batched decorative meshes must **not** use default convex hull collision: that would bridge the open gaps between unrelated objects. `CollisionDecks.server.luau` configures terrain chunks and builds native collision parts for the plaza, bridges, ramps, gate posts, walls and counters. Verify island collision in Studio; use precise decomposition for terrain if default hulls visibly bridge irregular coastlines. Ocean is visual only, with no swimming or hazard behavior implied.
4. Copy `MapAnchors.luau`, `CollisionLayout.luau`, and the selected integration modules/scripts into `ServerScriptService`. Run anchor/collision setup from the revised `WorldLayout.EnsureBuilt()` before existing dependent services resume. Do not rely on arbitrary Script startup order.
5. Adapt `WorldLayout` to use the imported world, the five `Branches`, eight `Zones`, and `FieldSpawns`. Its old `EnsureBuilt()` **clears terrain and recreates BossRooms**; importing meshes alone does not disable that behavior. Replace the construction branch only after the imported map and version have been verified. `InstallMapAnchors.server.luau` documents the exact native floor/door/Bounds/Exit construction, preserving the current gate system. Do not run a second copy after anchors already exist.
6. Add the imported regional terrain and `FivefoldSanctuary.Collision` to `EnemyCombat.resolveGroundPosition()`'s ground filter. It currently includes only Terrain, Baseplate and BossRooms. Keep decorations and invisible Bounds out of ground raycasts. Read each enemy's absolute `Position` or use the provided local offsets with `CFrame.lookAt(zone.Center, zone.Approach)`—do not apply the local transform twice.
7. Reuse/relocate the existing quest and merchant logic at the hub anchors. `QuestConfig.GIVER_POSITION` is a placeholder body's center, while the new `QuestGiverPosition` is feet position. Replace the old visual placeholder with the supplied NPC instead of layering two bodies. Keep existing quest IDs and rewards. Merchant anchor is also a feet position.
8. Wire `SafeHub.canEnemyAttack()` into both target acquisition and server damage application, including AOE/projectile paths. Leash enemies to their assigned branch/arena. There are no enemy spawns inside the sanctuary; the nearest is over 346 studs from center, so even the current largest 85-stud leash cannot reach the 195-stud safe boundary. Distance alone is not a damage-permission check.
9. Install the rebirth prompt script, and paste the hook snippet after `setMenuOpen` in `MainMenuGui.client.luau`. It reuses the existing UI, remote request and server validation. Optionally rig the static NPC later; animation is not required for the interaction.
10. Use the playtest below before publishing. The Blender scene is a daylight visual reference; Roblox lighting, emissive appearance, fog, streaming, collisions and NPC interactions still require Studio verification. Nothing has been published by this delivery.

## Five Studio playtests

1. Spawn with a fresh level-1 character. Reach the quest giver and rebirth keeper without jumping; read the signs on desktop and mobile; confirm five accessible hub exits and no obstructed service interaction area.
2. Walk all five bridge centerlines, shoulders, region approaches and boss ramps with a standard avatar. Check the 14-stud door opening, no floating floors, no invisible hulls spanning furniture, and correct scale/orientation at every island.
3. Check all 108 spawn markers against the ground, with bosses and ordinary enemies in their assigned regions. Verify each of the eight gates refuses an under-level player, allows a qualified player, and ejects correctly after rebirth lowers the level.
4. Pull enemies toward the hub and attempt ranged, AOE and melee damage across the safe boundary. Confirm no target acquisition or damage inside the sanctuary, no roadside spawn in it, and a forgiving return/respawn for accidental water falls.
5. Talk to the Keeper with keyboard, gamepad and touch. Confirm the rebirth panel opens without changing progress, dismiss it, reopen, then test refusal below requirement and one deliberate successful rebirth. Verify streamed-out/reloaded regions retain their anchors and prompt behavior.

## Rebuild and verify

```sh
blender --background --factory-startup --threads 8 --python-exit-code 1 --python tools/build_map_redesign.py -- --no-render
blender --background assets/map_redesign/FivefoldSanctuary.blend --threads 4 --python-exit-code 1 --python tools/validate_map_redesign.py
blender --background assets/map_redesign/FivefoldSanctuary.blend --threads 8 --python-exit-code 1 --python tools/render_map_redesign.py
blender --background --factory-startup --threads 4 --python-exit-code 1 --python tools/build_map_sky.py
python3 tools/check_map_integration.py
```

All source geometry is generated locally; no third-party meshes or externally hosted textures are required. The master .blend opens on the overview camera. Collection names and named empty anchors are part of the handoff contract. All spatial edits should be made in `tools/map_redesign_spec.py` / `tools/build_map_redesign.py` and regenerated so the meshes, JSON and Luau stay aligned.

The generator uses the locally installed DejaVu Sans font at `/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf`; lettering is converted to closed solid meshes for export. Blender 5.2.1 was used for this build.
