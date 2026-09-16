# Map validation

- 2495 parts: 26 floor, 399 collidable solids, 29 wall proxies, 32 markers/volumes

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
| Waypoint WarlordGate | 396 | 24.8 s | 15.2 s |
| IL_S2 (IronSquire L1) | 247 | 15.5 s | 9.5 s |
| IL_S1 (IronSquire L1) | 252 | 15.8 s | 9.7 s |
| IL_S3 (IronSquire L2) | 262 | 16.4 s | 10.1 s |
| IL_S4 (IronSquire L2) | 319 | 19.9 s | 12.3 s |
| IL_S5 (IronSquire L3) | 332 | 20.7 s | 12.8 s |
| IL_E1 (IronBerserker L6) | 392 | 24.5 s | 15.1 s |
| IL_S6 (IronSquire L3) | 344 | 21.5 s | 13.2 s |
| IL_B1 (IronBerserker L3) | 364 | 22.7 s | 14.0 s |
| IL_S7 (IronSquire L4) | 407 | 25.4 s | 15.6 s |
| IL_B2 (IronBerserker L4) | 401 | 25.1 s | 15.4 s |
| IL_B3 (IronBerserker L5) | 408 | 25.5 s | 15.7 s |
| IL_S8 (IronSquire L4) | 474 | 29.6 s | 18.2 s |
| IL_BOSS (Boss_Gorgon L10) | 470 | 29.4 s | 18.1 s |

## Encounter spacing (walk to nearest other spawn)

| Spawn | Nearest | Studs | Walk |
| --- | --- | ---: | ---: |
| IL_B1 | IL_B2 | 30 | 1.9 s |
| IL_B2 | IL_B3 | 83 | 5.2 s |
| IL_B3 | IL_S7 | 18 | 1.1 s |
| IL_E1 | IL_S7 | 87 | 5.5 s |
| IL_S1 | IL_S3 | 29 | 1.8 s |
| IL_S2 | IL_S3 | 41 | 2.6 s |
| IL_S3 | IL_S1 | 29 | 1.8 s |
| IL_S4 | IL_S6 | 43 | 2.7 s |
| IL_S5 | IL_B1 | 32 | 2.0 s |
| IL_S6 | IL_S4 | 43 | 2.7 s |
| IL_S7 | IL_B3 | 18 | 1.1 s |
| IL_S8 | IL_BOSS | 75 | 4.7 s |

## Result

- PASS: all map checks
