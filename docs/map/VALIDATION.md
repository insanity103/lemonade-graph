# Map validation

- 2813 parts: 26 floor, 483 collidable solids, 29 wall proxies, 32 markers/volumes
- support rule: 2704 visible parts checked, 0 floating, 0 buried

## Walk distance from player spawn

| Target | Studs | Walk (16) | Run (26) |
| --- | ---: | ---: | ---: |
| Iron Lowlands gate | 140 | 8.8 s | 5.4 s |
| NPC QuestMaster | 91 | 5.7 s | 3.5 s |
| NPC Merchant | 69 | 4.3 s | 2.7 s |
| NPC SkillTrainer | 61 | 3.8 s | 2.4 s |
| NPC RebirthKeeper | 81 | 5.1 s | 3.1 s |
| NPC Vaultkeeper | 50 | 3.2 s | 1.9 s |
| Waypoint HubSpawn | 0 | 0.0 s | 0.0 s |
| Waypoint IronOverlook | 193 | 12.0 s | 7.4 s |
| Waypoint WarlordGate | 406 | 25.4 s | 15.6 s |
| IL_S2 (IronSquire L1) | 247 | 15.5 s | 9.5 s |
| IL_S1 (IronSquire L1) | 252 | 15.8 s | 9.7 s |
| IL_S3 (IronSquire L2) | 262 | 16.4 s | 10.1 s |
| IL_S4 (IronSquire L2) | 337 | 21.1 s | 13.0 s |
| IL_S5 (IronSquire L3) | 332 | 20.7 s | 12.8 s |
| IL_E1 (IronBerserker L6) | 446 | 27.9 s | 17.2 s |
| IL_S6 (IronSquire L3) | 350 | 21.9 s | 13.5 s |
| IL_B1 (IronBerserker L3) | 364 | 22.7 s | 14.0 s |
| IL_S7 (IronSquire L4) | 423 | 26.4 s | 16.3 s |
| IL_B2 (IronBerserker L4) | 440 | 27.5 s | 16.9 s |
| IL_B3 (IronBerserker L5) | 414 | 25.9 s | 15.9 s |
| IL_S8 (IronSquire L4) | 489 | 30.6 s | 18.8 s |
| IL_BOSS (Boss_Gorgon L10) | 480 | 30.0 s | 18.5 s |

## Encounter spacing (walk to nearest other spawn)

| Spawn | Nearest | Studs | Walk |
| --- | --- | ---: | ---: |
| IL_B1 | IL_S5 | 32 | 2.0 s |
| IL_B2 | IL_B3 | 84 | 5.3 s |
| IL_B3 | IL_S7 | 18 | 1.1 s |
| IL_E1 | IL_S4 | 101 | 6.3 s |
| IL_S1 | IL_S3 | 29 | 1.8 s |
| IL_S2 | IL_S3 | 41 | 2.6 s |
| IL_S3 | IL_S1 | 29 | 1.8 s |
| IL_S4 | IL_S6 | 45 | 2.8 s |
| IL_S5 | IL_B1 | 32 | 2.0 s |
| IL_S6 | IL_S4 | 44 | 2.7 s |
| IL_S7 | IL_B3 | 18 | 1.1 s |
| IL_S8 | IL_BOSS | 75 | 4.7 s |

## Result

- PASS: all map checks
