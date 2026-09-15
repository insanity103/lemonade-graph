# Map validation

- 2361 parts: 17 floor, 389 collidable solids, 26 wall proxies, 31 markers/volumes

## Walk distance from player spawn

| Target | Studs | Walk (16) | Run (26) |
| --- | ---: | ---: | ---: |
| Iron Lowlands gate | 140 | 8.8 s | 5.4 s |
| NPC QuestMaster | 91 | 5.7 s | 3.5 s |
| NPC Merchant | 66 | 4.1 s | 2.5 s |
| NPC SkillTrainer | 61 | 3.8 s | 2.4 s |
| NPC RebirthKeeper | 81 | 5.1 s | 3.1 s |
| Waypoint HubSpawn | 0 | 0.0 s | 0.0 s |
| Waypoint IronOverlook | 193 | 12.0 s | 7.4 s |
| Waypoint WarlordGate | 390 | 24.4 s | 15.0 s |
| IL_S2 (IronSquire L1) | 259 | 16.2 s | 9.9 s |
| IL_S1 (IronSquire L1) | 264 | 16.5 s | 10.2 s |
| IL_S3 (IronSquire L2) | 275 | 17.2 s | 10.6 s |
| IL_S5 (IronSquire L3) | 301 | 18.8 s | 11.6 s |
| IL_S4 (IronSquire L2) | 303 | 19.0 s | 11.7 s |
| IL_S6 (IronSquire L3) | 329 | 20.5 s | 12.6 s |
| IL_B1 (IronBerserker L3) | 342 | 21.3 s | 13.1 s |
| IL_E1 (IronBerserker L6) | 413 | 25.8 s | 15.9 s |
| IL_S7 (IronSquire L4) | 374 | 23.4 s | 14.4 s |
| IL_B2 (IronBerserker L4) | 356 | 22.3 s | 13.7 s |
| IL_B3 (IronBerserker L5) | 393 | 24.5 s | 15.1 s |
| IL_S8 (IronSquire L4) | 392 | 24.5 s | 15.1 s |
| IL_BOSS (Boss_Gorgon L10) | 470 | 29.4 s | 18.1 s |

## Encounter spacing (walk to nearest other spawn)

| Spawn | Nearest | Studs | Walk |
| --- | --- | ---: | ---: |
| IL_B1 | IL_B2 | 21 | 1.3 s |
| IL_B2 | IL_B1 | 21 | 1.3 s |
| IL_B3 | IL_B2 | 40 | 2.5 s |
| IL_E1 | IL_S7 | 76 | 4.8 s |
| IL_S1 | IL_S3 | 35 | 2.2 s |
| IL_S2 | IL_S3 | 36 | 2.2 s |
| IL_S3 | IL_S1 | 35 | 2.2 s |
| IL_S4 | IL_S1 | 36 | 2.3 s |
| IL_S5 | IL_S2 | 41 | 2.6 s |
| IL_S6 | IL_B2 | 38 | 2.4 s |
| IL_S7 | IL_S8 | 26 | 1.6 s |
| IL_S8 | IL_S7 | 26 | 1.6 s |

## Result

- PASS: all map checks
