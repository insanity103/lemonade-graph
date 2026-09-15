# Handoff: Legendary Swords inspired map and gameplay

Date: 2026-09-15. Audience: Claude Code implementing the next development phase.

## What the user wants

Build an original map and improve the gameplay of Lemonade using **The Legendary Swords RPG**
by Omega_RX as the reference: https://www.roblox.com/games/60654525/The-Legendary-Swords-RPG.
The user explicitly asked to study gameplay as well as map design, accepted the improvement
ideas, requested a detailed whole-game plan, and requested this Git handoff for Claude to implement.

Prioritize a compact useful hub, distinct connected combat areas, short farming loops,
collectible swords, frequent meaningful upgrades, and visible goals for the next destination.
Use original geometry, names, and assets; the recordings are behavioral and visual references.

## Where things stand

The user rejected the previous Fivefold Sanctuary map, requested a blank baseplate, then
connected a NEW baseplate place to Rojo and requested gameplay only. After the gameplay-only
integration, the user reported: **"okay everything looks good"**. They explicitly confirmed
enemies and interactive NPCs should appear, with no scenery. That is the working baseline
to preserve while developing the new map separately.

- `default.project.json` explicitly maps gameplay services and clients. It has no Workspace,
  Terrain, Baseplate, SpawnLocation, Lighting, or ServerStorage mapping.
- `lemonade-game/Gameplay/WorldLayout.luau` supplies gameplay placement on the existing plate.
  It is mapped as ServerScriptService.WorldLayout. Its EnsureBuilt method is a no-op.
- The old `lemonade-game/ServerScriptService/WorldLayout.luau` is NOT the active module.
  It retains legacy terrain generation/reset logic and must not reenter the active project.
- Gameplay services include combat, swords, drops, inventory, XP/gold/levels, skill points,
  quests, merchant, rebirth, respec, saving, movement, audio, effects, and existing UI.
- The former Workspace/FivefoldSanctuary mesh copies have been removed. Archived art still
  exists under assets/map_redesign and map kits under ServerStorage; neither is actively synced.
- Build and structural integration checks passed in the prior session. The user reported the
  new place works. Automated Studio playtesting was NOT performed; Rojo connectivity does not
  imply the WEPPY Studio-control plugin is connected.

## Next step

Read this handoff and GAMEPLAY_ONLY.md. Verify the gameplay baseline, then implement the
first complete slice in a separate map-development branch and Rojo project:

**Hub → Iron Lowlands → first boss → sword upgrade → return to hub.**

Start with a dimensioned top-down layout and rough geometry. Integrate spawn markers and
playtest travel, sword hits, camera clearance, and rewards before polishing or adding regions.
Keep the default gameplay-only project usable as the regression baseline.

## Decisions that must survive

- Build classic Roblox environments with Parts, wedges, and selective meshes.
- Flat dependable combat floors; deliberately modeled cliffs and enclosure.
- No animated terrain grass. Do not recreate the prior broad grassy landscape.
- Restrained regional materials and lighting; no unreadable darkness or excessive bloom.
- Every area has a recognizable entrance, landmark, enemy family, and boss.
- Decoration sits outside fighting and travel lanes and usually has collision disabled.
- Preserve gameplay identifiers and saved-data contracts when moving locations.
- No automatic terrain fallback, destructive world reset, or silent baseplate resizing.
- Existing gameplay characters are wanted; scenery is added only through the new map project.
- Work in tested stages. Do not implement all regions in one unverified generation pass.

## Reference evidence and limits

Videos are local user recordings under `/home/alex-christensen/Videos/Screencasts/`.
They are NOT committed to Git. A different machine may not have them; the observations below
are the portable evidence. Request access only if exact visual or timing analysis is needed.
Recordings were sampled into contact sheets, not exhaustively reviewed frame by frame.

| Recording filename | Duration | Observations from sampled frames |
| --- | --- | --- |
| Screencast From 2026-09-15 13-51-20.mp4 | 54 s | Most world surfaces black; UI and labels visible. Poor material/layout evidence. Cause of rendering problem unknown. |
| Screencast From 2026-09-15 13-53-31.mp4 | 185 s | Enclosed hub, timber-framed building, gray paths, labeled entrances, simple trees, cave-like beginner combat space with rocks and campfire. |
| Screencast From 2026-09-15 13-57-38.mp4 | 181 s | Repeated fighting in contained rooms, returns through hub, entry labeled Upper Mountain, basic props distinguishing encounters. |
| Screencast From 2026-09-15 14-02-48.mp4 | 194 s | Roughly level 42 into high 60s, frequent stat spending, rocky areas then hub/shop exterior and forest; some sharp health drops. |
| Screencast From 2026-09-15 14-06-51.mp4 | 204 s | Forest graveyard farming, progression to level 100, hub return and temple entry; very low health in sampled temple fight. |

Do not claim exact attack speed, time-to-kill, death frequency, enemy AI rules, or rewards from
these samples. Boosts and bonuses may affect observed progression. Texture/rendering faults
are not a visual target. The hub/forest/temple progression comes from observation; the complete
regional plan below is our proposed adaptation, not a measured reconstruction of the reference.

## Gameplay pillars

1. Short combat loops: enemies close enough to fight consecutively without long empty walks.
2. Noticeable growth: frequent early rewards and upgrades that visibly improve effectiveness.
3. Player-controlled challenge: stay and farm, pursue optional encounters, or enter harder areas.
4. Readable combat: visible health, enemy levels, attacks, and hit confirmation.
5. Useful hub visits: equipment, quests, skills, rebirth, collection, and choosing a destination.
6. Visible milestones: show impressive locked destinations before players can reach them.
7. Fair recovery: short retries and forgiving death; avoid long repetitive travel.

## Whole-world layout

Use a central town with distinct regions reached through visible labeled entrances. Regions
can contain connected rooms/clearings instead of requiring one enormous continuous terrain.
The diagram describes travel/progression, not fixed geometric coordinates.

```text
                         CELESTIAL SUMMIT
                                |
                         Ascension Gate
                                |
       FROSTBOUND GLACIER -- CENTRAL HUB -- INFERNAL CALDERA
               |                |                  |
          Sunken Marsh    Shops / Quests        Stormwatch
                         Spawn / Rebirth
                                |
                     IRON LOWLANDS / QUARRY
                                |
                        BRIARWOOD FOREST
                                |
                       Hidden encounters

                  VOID RIFT: separate hub portal
```

Choose actual entrance requirements from the existing progression after reviewing balance.
Do not copy the reference game's level-100 temple gate directly into our differently scaled
enemy progression. Decide and document whether region completion unlocks travel, level gates,
or both; already discovered regions should have convenient return access.

### Central hub

Starting size target: 180–220 studs across; tune through playtesting.
Timber-and-stone settlement sheltered by rock walls. Spawn in a courtyard looking toward the
beginner entrance. Quest Master is beside the route out. Sword shop on one side; Skill Trainer
and rebirth on the other. Major destinations are visible around the perimeter. A modest sword
monument or fountain provides orientation. Buildings must read before labels become legible.

Services: sword shop with comparisons; quest board with destination/reward; skill allocation
and reset; rebirth explanation; collection hall/journal; travel board for unlocked regions.
Target first combat entrance within 10–15 seconds and important services a few seconds from
spawn. No enemy may enter or attack into the safe zone. Support keyboard, controller, and touch.

### Region specifications

| Region | Sequence and visual identity | Gameplay / acceptance priorities |
| --- | --- | --- |
| Iron Lowlands | Warm stone quarry, packed-earth paths, timber supports. Entrance overlook → spaced Squires → mixed Squires/Berserkers → optional side passage → Gorgon clearing → easy return. | Teach fighting, rewards, upgrades, boss. Flat floors, wide camera clearance, retreat room, boss visible before aggro. No beginner maze. |
| Briarwood | Blocky forest, paths, ruined walls and graveyard. Entrance road → two clearings → graveyard → ruined chapel/arch → Root Warden → subtly signposted hidden encounter. | Recognizable farming circuit; trees frame routes; graves do not trap players; optional discovery rewards. |
| Frostbound Glacier | Pale rock, snow surfaces, restrained ice accents, frozen temple. Sheltered entrance → broad ascent → lower/upper terraces → forecourt → Frost Revenant. | Visible milestone; safe staging area; broad forgiving edges; short retries. Initially visual ice, not slippery movement. |
| Sunken Marsh | Muted greens, decorative shallow water, broken masonry, raised walks. Main walkway → two ruin clearings → optional loot paths → Drowned Bellwarden courtyard. | Optional alternate progression. Obvious ground, flat combat, no hidden deep-water traps. |
| Infernal Caldera | Dark stone mines, timber supports, orange accents and distant lava. Mine entry → broad chamber → elite branch → volcanic corridor → fortress → Infernal Colossus. | Readable silhouettes; lava outside ordinary lanes; introduce stronger enemies singly; shortcut after fortress arrival. |
| Stormwatch | Gray ruins, battlements, banners, restrained storm effects. Ground ruins → broad stepped ascent → open platform → Tempest Warden. | Optional challenge; height without precision platforming; camera clearance; attack warnings; nearby recovery after falls. |
| Void Rift | Purple stone, broken arches, restrained glow. Safe arrival → broad routes → three encounter spaces → optional chamber → Void Wraith. | Readable dark palette, dependable collision, no screen-filling effects or ambiguous routes. |
| Celestial Summit | Pale stone, gold accents, open sky, monumental stairs/columns. Arrival court → outer garden → temple approach → elite court → Celestial Titan → achievement/collection landmark. | Earned destination visible on arrival; staged difficulty, spacious boss fight, useful repeat rewards. |

Keep existing quest zone names and enemy identities across these regions. Their display labels
can improve without breaking saved quests, kill attribution, drop tables, or sword identities.

## Combat changes

- Align damage with visible sword swing. Improve sounds, brief impacts, and readable numbers.
- Keep input responsive and optional auto-attack; manual attacks should still feel worthwhile.
- Limit effects so incoming attacks stay visible. Verify hit range against animation.
- Basic melee: approach and readable swing. Heavy: longer warning, stronger hit. Fast: lower
  durability, faster movement, shorter reach. Elite: familiar enemy plus one extra behavior.
- Bosses: two or three recognizable attacks and recovery windows, with retreat space.
- Improve existing melee first; ranged enemies are a later addition after melee is reliable.
- Introduce new types in small encounters before mixed groups. Limit beginner surround pressure.
- Validate line of sight, walls, pursuit limits, safe-zone protection, retreat/reset behavior.
- Show recommended levels and danger before commitment. Harder-region entry has safe staging
  and a small first encounter rather than immediate overwhelming enemy density.
- Preserve server-authoritative damage, cooldowns, rewards, and interaction validation.

## Progression, economy, and collection

Starting playtest targets (proposals, NOT measurements or final balance):

| Measure | Target |
| --- | --- |
| First meaningful reward | Within 1 minute |
| First level | About 1–2 minutes |
| First equipment improvement | About 3–5 minutes |
| First boss attempt | About 8–12 minutes |
| Ordinary appropriately geared fight | A few satisfying swings |
| Travel between nearby encounters | Usually under 10 seconds |

Tune using fresh-player sessions and actual combat metrics, not sampled video level gains.
Record kill time, damage taken, deaths, gold/XP per minute, drop frequency, and travel time.

- Each region gets a recognizable weapon family. Rare drops remain exciting goals.
- Add side-by-side equipped/new sword comparisons and understandable modifier effects.
- Protect favorite swords from accidental sale; clearly explain auto-sell rules.
- Collection journal tracks found swords and reveals source regions once unlocked.
- Boss clears always grant useful progress. Consider tokens toward a guaranteed weapon after
  repeated clears; introduce save schema/migration and server validation if implementing tokens.
- Main progression must not require an exceptionally rare drop. Keep rare collection goals optional.
- Review rebirth pacing, rewards, and reset explanation after ordinary progression works.

## Quests and exploration

Main quests: local enemy kills → equipment improvement → regional boss → next entrance.
Optional quests: hidden chamber, elite, short farming circuit, regional sword, nearby NPC task.
Show destination, progress, reward, and ready-to-turn-in state clearly. Avoid repeated cross-map
errands. Permit local/remote turn-in for routine repeatables while keeping meaningful hub visits.
Use subtle clues for secrets rather than arbitrary invisible walls. Exploration rewards must
be useful but optional. Preserve the existing sequential quest chain and persisted state during
any migration; do not silently rename completed quest IDs.

## Travel, death, UI, accessibility

- Unlock return travel when first reaching a region. Arrival points are outside aggro range.
- Short boss retry routes; clear death/reset consequences; retain forgiving recovery.
- Add Return to Hub with server-validated combat restrictions to prevent escape exploits.
- HUD: health, XP, contextual enemy name/level/health, distinct incoming/outgoing damage,
  visible auto-attack state, and available skill-point reminder.
- Navigation: named entrances and recommended levels, simple destination list before a full
  minimap, optional quest direction indicator, icons plus text instead of color alone.
- Settings: separate music/effects volume, reduced particles/shake, number visibility, UI scale.
- Test actual touch controls and controller navigation, especially shop/quest/skill flows.

## Technical implementation boundaries

- New map project should extend the gameplay project deliberately; do not broadly map the old
  ServerScriptService or Workspace directories. That would restore unwanted builders/assets.
- Use one new map container, region models, and named gameplay markers for NPCs, enemy spawns,
  entrances, safe zones, boss areas, and return travel. Document the marker schema.
- Gameplay reads markers instead of embedding map coordinates. Missing markers warn and leave
  the affected feature idle; never trigger legacy terrain generation.
- Separate collision proxies from visual geometry. Validate spawns on floors, no prop overlap,
  valid entrance targets, non-overlapping safe/combat areas, and camera clearance.
- Terrain.Decoration is NotScriptable: never assign it in ordinary Luau or the Command Bar.
  Configure it through Studio Properties or serialized place/project settings if terrain is used.
  Official reference: https://create.roblox.com/docs/reference/engine/classes/Terrain/Decoration.
- Rojo preserves unknown Studio objects in the baseline. Removing a source file or changing
  runtime behavior is not proof of saved-place cleanup. Runtime changes revert after Stop.
- Do NOT run tools/reset_map_in_studio.luau on the working new place. It was an older reset utility.
- New experience saves and restricted asset permissions need destination-specific validation.
- Avoid claiming Studio certification from Rojo build or source/static checks alone.

## Implementation sequence and exit criteria

1. **Baseline:** preserve current working state; build and run regression checks; establish new
   map-development branch/project. Record current gameplay and save behavior.
2. **First slice:** dimensioned hub/quarry plan, rough geometry, markers, NPCs, first boss and
   reward loop. Exit: a new player completes the loop without confusion, falling, or long travel.
3. **Combat/progression polish:** sword timing, feedback, attack warnings, early rewards/recovery,
   inventory comparisons and quest clarity, touch/controller validation. Exit: measured targets
   and a documented tuning pass, with no duplicate damage or reward events.
4. **Forest/mountain:** Briarwood, Glacier, first secret and major unlock. Exit: destinations
   understandable, difficulty transitions fair, safe staging and convenient return paths.
5. **Remaining regions:** Marsh → Caldera → Stormwatch → Void → Celestial, each separately
   validated for geometry, combat, navigation, rewards, and performance before continuing.
6. **Replay:** collection journal, guaranteed boss progress if selected, repeatables, optional
   challenges, and rebirth pacing. Exit: all new progression data saves/reloads correctly.
7. **Whole-game pass:** fresh progression, death, reconnect, saves, multiplayer reward ownership,
   mobile performance, complete quest/travel routes, and destination asset permissions.

For each phase record changed files, decisions, verification evidence, and known limitations.
Mark tasks complete only after their actual behavior is checked. Git publication and updating
the live Roblox experience are separate actions; this handoff does not request a live publish.

## Entry points and validation

| File | Role |
| --- | --- |
| default.project.json / GAMEPLAY_ONLY.md | Active baseline sync contract and user instructions |
| lemonade-game/Gameplay/WorldLayout.luau | Active gameplay adapter; replaces legacy WorldLayout in the Rojo tree |
| lemonade-game/Gameplay/SafeHub.luau | Active spawn safety rule |
| lemonade-game/Gameplay/GameplayActors.luau | Plain interaction NPC bodies and prompts |
| lemonade-game/Gameplay/GameplayServices.server.luau | Rebirth entry and server-side skill respec |
| lemonade-game/ServerScriptService/EnemyCombat.server.luau | Combat, spawning, AI, damage, pursuit and rewards hooks |
| lemonade-game/ServerScriptService/MerchantSystem.server.luau | Merchant backend and gameplay-only actor branch |
| lemonade-game/ServerScriptService/QuestSystem.server.luau | Quest state and gameplay-only actor branch |
| lemonade-game/ReplicatedStorage/Config/ | Quest, sword, combo, merchant, rebirth and save configuration |
| lemonade-game/ServerScriptService/PlayerDataService.luau | Persistence; review before adding collection/token data |
| lemonade-game/StarterPlayer/StarterPlayerScripts/ | HUD, menus, combat controls and effects |
| tools/check_gameplay_project.py | Built-package regression check for gameplay-only baseline |

```sh
rojo build default.project.json -o /tmp/lemonade-gameplay-only.rbxlx
python3 tools/check_gameplay_project.py /tmp/lemonade-gameplay-only.rbxlx
git diff --check
```

The baseline check expects 18 server components and 13 client scripts and rejects mapped
environment services/terrain writes. Keep that baseline check; add separate map-project
validation rather than weakening it to let a map leak into the default project.
Use repository Roblox Luau/map skills where helpful, and verify source when using the older
graph: it predates the active gameplay adapter. Full recordings and actual Studio playtests
are required for precise timing claims.

## Status and open design choices

The new map and improvements in this plan are NOT yet implemented. Baseline gameplay-only
integration is implemented and user-reported working. The first slice is the next task.
Exact region coordinates, revised unlock levels, enemy timing, economy rates, and boss-token
prices remain playtest-driven design choices. Choose sensible initial values, label them as
tuning assumptions, and keep the implementation moving within this agreed direction.
