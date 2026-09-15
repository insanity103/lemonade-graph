# GnomeCode "RPG Tutorial" playlist — takeaways for Lemonade

Source: GnomeCode's 16-episode "RPG Tutorial" playlist on YouTube (reviewed 2026-09-15 from the
episodes' auto-generated captions). Summaries below are our own notes; the tutorial's project
files are paywalled and were not used.

## Episode map

| # | Topic | Core idea |
| --- | --- | --- |
| 1 | NPC | Wander loop: `MoveTo` random point within a range, `MoveToFinished`, random idle time |
| 2 | Module loader | One server + one client loader; class modules bound to CollectionService tags (`_Server`/`_Client` suffix); connect `GetInstanceAddedSignal` before looping existing; server network ownership; collision groups |
| 3 | Sword | Tool + welded parts; client plays animation with cooldown; server validates and hits via `GetPartBoundsInRadius`, swept over the swing on Heartbeat, deduping targets |
| 4 | Enemy AI | Hunt nearest **visible** player (raycast), attack in range, move otherwise; respawn from a stored template; immortal attribute for friendly NPCs |
| 5 | Dialogue | Data-only dialogue chains (text + responses → next id); typewriter text; number-key responses via `BindActionAtPriority`; ViewportFrame portrait |
| 6 | Data-driven stats | EnemyData / WeaponData tables instead of per-script constants |
| 7 | Currency + saving | ProfileStore with template + reconcile; gold pouch loot that despawns |
| 8 | Dialogue events | Per-NPC `onResponse` hook on client and server (rate-limited rewards) |
| 9 | Shop | Grid of items with spinning ViewportFrame previews, preview panel (Owned/Buy), server-validated purchase |
| 10 | Selling | Confirm popup "Sell X for N gold?", half price, remove from backpack/StarterGear/character |
| 11 | Notifications | Every refused action tells the player why; red + fail sound, green + success sound |
| 12 | Hotbar | Custom inventory replacing CoreGui backpack, number-key binds, rebuild on removal |
| 13 | XP + levels | Weapon min-level (client + server); per-player damage contribution → XP split by share; 12.5K/1.2M formatting |
| 14 | Quests | Multi-objective quests, sequential objectives, kill/touch triggers, save status per quest |
| 15 | Quest UI | Tracker with strikethrough, progress sounds, dialogue index unlocks, **Highlight on the quest focus** |
| 16 | Wrap-up | Boss + gear gating, per-enemy gold, respawning world pickups, quest rewards |

## Adopted now

- **Quest focus outline** (ep 15): MapClient outlines the Quest Master, merchant, nearest living quest
  enemy or boss with a `Highlight`, alongside the existing guide marker.
- **Line of sight before aggro** (ep 4): enemies only acquire players they can see.
- **Feedback for refused actions** (ep 11): `RemoteEvents.Notify` + `Notifications.client.luau`;
  skill reset now explains missing points/gold and confirms refunds.
- **Readable big numbers** (ep 13): `ReplicatedStorage.NumberFormat.short` in the XP bar.

## Backlog (ranked by value for Lemonade)

1. **Damage-share rewards** (ep 13): today the last hitter (`creator` tag) takes all XP, quest credit
   and drops. Track damage per player on the enemy and split XP / credit contributors. Needs a
   policy decision (split vs everyone ≥ N% gets full credit) and touches Leveling/Quest/Drop systems.
2. **Hub NPC dialogue** (ep 5, 8): short chains that explain rebirth, skill reset and the next
   destination, with actions (open shop, reset) — the handoff asks for a rebirth explanation.
3. **3D sword previews** (ep 9): spinning ViewportFrames in the merchant and inventory panels.
4. **Sell confirmation + favourites** (ep 10 + handoff): confirm before selling; protect favourites.
5. **Enemy-enemy collision group** (ep 2): stops packs jamming in chokepoints.
6. **Exploration objectives** (ep 14): a REACH/DISCOVER objective type fed by map waypoints, for
   optional side quests (keep the main chain IDs unchanged).
7. **Ambient villagers** (ep 1): a few wandering hub NPCs with the Animate script run on the client.

Not planned: the custom hotbar (ep 12) and ProfileStore migration (ep 7) — Lemonade already has
MainMenuGui inventory and a session-locked PlayerDataService.
