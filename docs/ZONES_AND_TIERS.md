# Zones and difficulty tiers

Status: plan, 2026-09-20. Nothing here is built. The economy and loot work it builds on is
committed (`9bf74e0`); the rebirth loop and the first fifteen minutes are being fixed as this
is written, and both come before any of this.

The rule that decides every question below: **the player's time is the only budget that
matters.** A tier that saves us art but costs a player a confusing minute is a bad trade.

## 1. The shape

**Four built regions, eight zones, three tiers, three worlds.**

| Region | Zones (native levels) | Art |
|---|---|---|
| Iron Lowlands | Iron Lowlands 1-3, Briarwood 9-14 | built (desert oasis, forest) |
| Frostbound | Glacier 18-23, Sunken Marsh 24-29 | Glacier built (parts now, Blender meshes on import: docs/map/GLACIER.md); Marsh to build |
| Infernal | Caldera 34-41, Stormwatch 41-48 | to build |
| Celestial Summit | Void Rift 55-70, Summit 80-100 | to build (Void Rift is the Summit's underside) |

`Gameplay/WorldLayout.luau` already pairs the eight zones into these regions. Void Rift folds
into the Summit build rather than being its own region: one fewer build, and the empty band
between level 70 and 80 disappears.

Each zone is played at three tiers: **Normal, Hard, Nightmare**. A tier is not a setting and
not a per-zone instance. **A tier is a world**: a separate place in the same Roblox universe,
running the same map and the same scripts with one config value different.

Why not more zones: six of the eight do not exist in the world yet (the shipped map has 37
spawn markers in two zones and nothing above level 14). Each region costs a full gauntlet of
building and judging. Tiers multiply the regions we do build by three at a fraction of that
cost, and it is the model the loot bar (Dungeon Quest) uses.

Why not fewer: four regions is the minimum that gives the 1-100 curve real scenery changes.
Two regions at five tiers each would be the same corridor with bigger numbers.

## 2. Worlds, not instances

### Three places, one build

```
Lemonade (universe)
  Lemonade            place: tier Normal   (the current place)
  Lemonade Hard       place: tier Hard
  Lemonade Nightmare  place: tier Nightmare
```

- All three are published from the same Rojo project. A new module,
  `ReplicatedStorage/Config/TierConfig.luau`, maps `game.PlaceId` to a tier table. Unknown
  place id (a Studio copy, a test place) means Normal, and Studio can override with a
  workspace attribute for testing, gated by `RunService:IsStudio()`.
- The DataStore is per universe, so gold, swords, vault, wealth rungs, quests and unlocks are
  the same profile in every world. Nothing is copied between worlds; there is one profile.
- The map, the hub, the NPCs and the region walls are identical in every world. What differs
  is read from `TierConfig` at runtime: enemy affixes, boss phases, the gold band, rarity
  odds, the hazard layer, and which routes are open.

### Why worlds and not per-zone expeditions

A shared open world cannot give two players in the same zone different tiers, so tiers must
be per server. The alternative to whole worlds is a per-zone reserved-server "expedition"
(party up at the gate, get a private copy). Worlds win because:

- A Hard world is full of Hard players. An expedition is four people in a private copy.
- No party panel, no objective, no extraction, no reserved-server bookkeeping.
- Switching tiers is one teleport, and switching down to help a friend is always allowed.
- The rebirth loop needs no special code: after a wipe the player still owns Hard, but at
  level 1 they start in Normal and climb, which is the victory lap the rebirth fix is aiming
  for.

The cost is population split, three ways. Roblox servers hold a dozen or two, most players
sit in Normal for their first hours, and Nightmare being quiet suits an endgame. Accepted.

## 3. Unlocking

Unlocks are **account-wide, permanent, and server-granted**. They are stored in the profile
as new fields (`tierHard`, `tierNightmare`, both false on old saves; nothing renamed).

| Tier | Unlock | Where it is granted |
|---|---|---|
| Normal | always | |
| Hard | kill the Celestial Titan (the last Normal boss) once | the kill handler in `EnemyCombat`, same place the drop rolls |
| Nightmare | kill the Celestial Titan on Hard, and Rebirths >= 1 | same, on a Hard server |

Notes:

- Hard is not unlocked zone by zone. A whole-world tier needs a whole-world key, and the
  final boss is the honest one. Unlocking Hard at the first boss would put a level 12 player
  on a Hard server that kills them at the gate.
- The Nightmare rebirth gate is what gives rebirth a reward beyond multipliers, which the
  rebirth measurement found it lacks. It also means a player who rebirths at level 20 (the
  first requirement) is not immediately handed a world that one-shots them.
- Unlocks never lapse. A rebirth wipes level and XP, not tiers.

## 4. What a tier changes

Never only health. A tier that is the same fight with a bigger number is the repetition cost
of this whole plan, so every row below has to change how the fight reads.

| | Normal | Hard | Nightmare |
|---|---|---|---|
| Enemy levels | native | native +15 | native +30 |
| Enemy affixes | none | one per enemy, rolled from the zone's affix list | two, and elites get three |
| Boss | as built | one added attack | second phase at 50% health |
| Zone hazard | none | none | one per zone (blizzard, ashfall, void tears, storm) |
| Routes | as built | a longer branch opens | the short route closes |
| Gold | that zone's `GoldCurve` band | the band 15 levels up | the band 30 levels up |
| Loot | the zone pool at its rarity odds | same pool, one rarity table up | same pool, plus one Nightmare-only Legendary per zone |
| Death | one minute of income (as now) | same rule | same rule |

Affixes are a small shared list so they read at a glance and the enemy animator can show
them: **Shielded** (a bar that must be broken first), **Enraged** (faster, glows), **Summoner**
(spawns two minions on notice), **Thorns** (returns a fraction of damage), **Vampiric**
(heals on hit). Each gets one visual tell and one sound. An affix the player cannot see
coming is a cheap death, not difficulty.

The Nightmare-only Legendary per zone is straight from Dungeon Quest, where Legendaries drop
only on Nightmare, and it is the strongest reason to return to a zone the player has
outlevelled. It goes in the zone's existing pool in `BossWeapons.luau` with a
`minTier = "Nightmare"` flag, so `DropRules` can filter it; nothing else about drops changes.

### Level scaling and who can go where

Hard and Nightmare do not scale to the player. Enemies are +15 and +30 levels, flat. A level
40 player on a Hard server is fine in the Lowlands (level 16-18) and dead in the Caldera
(level 49-56). That is intended: a tier is a harder version of the world, and the world's
own gates already pace it.

The tier board tells the truth before the teleport: "Hard: enemies are 15 levels above
Normal. You are level 40; the Lowlands and Briarwood are safe for you." That one line is
the difference between a choice and a trap.

## 5. Moving between worlds

### The tier board

One board in Hearthmere, next to the Ascension Gate, and one at each region gate. It shows
the three worlds, which are unlocked, the unlock condition for each locked one, and a
**Travel** button. Travelling teleports to a public server of that place.

- **Party travel:** the board has "Travel with party". Everyone in the party who owns that
  tier goes to the same server (`TeleportService:TeleportAsync` with the whole list); anyone
  who does not is told why and stays. Nobody is silently left behind.
- **Follow a friend:** the friends list shows which world a friend is in and offers "Join",
  which teleports to their server instance if the tier is unlocked.
- **From the pause menu:** the same board is reachable from the main menu, so a player who
  walked into the wrong tier does not have to find a gate to leave.

### First minutes

The board does not exist for a new player. It appears after the first boss kill (the Gorgon
at level 10), with a one-line reveal: "Harder worlds open when you finish this one." Before
that, the word "tier" appears nowhere. This keeps the opening exactly as simple as the
first-minutes piece is making it.

## 6. Every angle: glitches and inconveniences

This is the section that earns the plan. Each item is a way the player gets hurt, and what
prevents it.

### Data

1. **The profile lock.** `PlayerDataService` locks a profile per server and treats a lock
   older than 1,200 s as abandoned (`SaveConfig.LOCK_STALE_AFTER`). A teleport is a fast
   leave and a fast join: if the old server has not saved and released, the new server
   either waits or loads a stale profile. **Rule: the old server saves and releases the lock
   before it calls teleport, and the new server retries the load for up to 10 s before
   showing "Loading your progress" rather than a default profile.** A player must never see
   a fresh level-1 profile because they changed worlds.
2. **Autosave gap.** Autosave is every 120 s. Anything earned in the last two minutes before a
   teleport must be saved by the pre-teleport save, not left to chance. The BindToClose save
   already exists; the teleport path calls the same function.
3. **In-memory state that is not in the profile.** The kill streak (`KillStreak`,
   `KillStreakAt`) is memory only and resets on teleport. Acceptable, and the streak already
   resets on death. `ForgeLuckCharges` is a persisted attribute and survives. Anything new
   that matters to the player (an armed strike, an open sell offer) is resolved before
   teleport, below.
4. **Two servers, one profile.** If a teleport fails after the old server released the lock,
   the player is still on the old server with a released profile. The old server must
   re-acquire the lock (reload) on teleport failure. Teleports fail often enough on Roblox
   that this is not an edge case.

### Interrupted actions

5. **An armed forge strike.** The player pays, the meter is sweeping, and they hit Travel.
   The server resolves the strike as a MISS (base luck, gold spent, which is the documented
   MISS outcome) or refunds it; refund is kinder and cannot be exploited because arming
   already cost the gold. **Refund on teleport.** The Travel button is also disabled while a
   strike is armed, so this is a fallback, not the path.
6. **An open KEEP-or-SELL prompt.** The offer id is server-owned with a 25 s server timeout.
   Teleport resolves it as KEEP (the sword is already in the backpack), which is what
   ignoring the prompt does. Nothing is lost.
7. **A trade in progress.** `TradeSystem` cancels the trade and returns both sides' swords,
   the same as a disconnect. Both players are told.
8. **The vault open.** The vault panel is client UI over a server list; closing it on
   teleport loses nothing. Deposits and withdrawals are single server calls.
9. **Mid-combat.** Teleporting out of a fight is allowed (it is an escape), but the death
   penalty is not applied and the enemy resets. A player who teleports at 1 HP into a Hard
   server at level 1 is going to die on arrival; the arrival spawn is the hub, which is safe
   in every world, and the board warned them.

### Arrival

10. **Where you land.** Always the hub spawn of the target world, never the zone you were
    in. The hub is safe in every tier, so a bad choice costs a walk, not a death.
11. **Level-1 in Nightmare.** Possible after a rebirth for a player who owns Nightmare. The
    hub is safe, the board is right there, and the board's line says "You are level 1;
    nothing outside the hub is safe for you here." They can leave in one tap.
12. **Arrival in an empty server.** Nightmare will often be empty. The world must be
    complete and correct with one player: no enemy waits for "enough players", no boss needs
    a party. Party scaling (below) is additive on top of solo, never a requirement.

### Fairness

13. **Farming Normal with Hard gear.** A Hard player can always go down. Normal pays Normal
    rewards; there is no penalty and no bonus. Since rewards scale with the tier and the
    player's gear is the same in both, farming Normal is strictly slower, so nothing needs
    enforcing.
14. **Client-set tier.** The tier comes from `game.PlaceId` on the server. The client never
    sends a tier. A Studio override exists only under `RunService:IsStudio()`.
15. **Unlock races.** Two players kill the Titan together; both get the unlock, because the
    unlock is granted to every player credited on the kill, using the same credit rule as
    drops.
16. **Party scaling.** Enemies gain +30% health per additional player who has damaged them in
    the last 10 s (Dungeon Quest's rule, on the same "who is fighting it" basis the drop
    credit already uses). Health is added, never removed mid-fight, so a player who joins a
    fight does not heal the enemy visibly, and one who leaves does not make it drop.

### Progress across worlds

17. **Quests.** Kill-count objectives count in any world. OBTAIN objectives count in any
    world. A quest never says "do this on Normal"; the player should never have to think
    about which world their quest wants.
18. **Drop pity.** Pity counters are per profile, not per world, so switching worlds does
    not reset a pity run.
19. **Leaderboards and the wealth ladder.** Global, one profile. A Nightmare kill and a
    Normal kill both count toward the same fortune.
20. **The blacksmith's Mystery Blade** rolls from the zone the player is standing in. On a
    Hard server it rolls the same pool at the Hard rarity table, and its price uses the
    Hard gold band, so it stays a fair decision against a strike in that world.

### Building and shipping

21. **Three places from one build.** The Rojo project publishes to three place ids. A
    `MapVersion` attribute is already written by `map_forge.py`; the three places must
    match on it, and the tier board shows a "world is updating" state if a target place
    reports an older version, instead of teleporting a player into an old map.
22. **Studio testing.** All three tiers are testable in one Studio session through the
    override attribute. The gauntlet stages for tiers use it.
23. **Perf.** Nightmare hazards are the only new per-frame cost. The performance pass
    budgeted 1.6 ms of script time per frame; a hazard layer gets a fixed share of that and
    is measured the same way before it ships.

## 7. Multiplayer within a world

Nothing in the tier design assumes a party. Everything below is additive.

- Party up in the hub (the existing trade/friends UI gains a "Party" tab). Parties share
  kill credit for quests, share the unlock on a boss kill, and can travel together.
- Boss health scales with the number of players fighting it (item 16). Boss drops roll for
  each player credited, as now.
- Enemies do not scale to bystanders. A player passing through a fight is not part of it.
- Trading works across worlds (it is profile to profile) but only when both players are on
  the same server, as now.

## 8. Order of work

1. **First minutes and the rebirth loop** (in progress). Tiers do not start until the opening
   is solid and the rebirth is a decision.
2. **Tier infrastructure with Hard only:** `TierConfig`, the three places, the pre-teleport
   save and lock release, the tier board with party travel, affixes with tells, the boss's
   added attack, the Hard gold band and rarity table. Judged in a gauntlet against Dungeon
   Quest's difficulty ladder on the economy side and against the enemy-animation bar on the
   affix tells.
3. **Nightmare:** hazards, boss phase 2, the per-zone Legendary, the rebirth gate.
4. **Regions two to four**, one at a time, each through the world gauntlet like the first.

## 9. Open questions for the owner

- Should Hard unlock require the Titan, or is the Void Wraith (level 70) early enough? The
  Titan is the honest key; the Wraith gets players into Hard sooner.
- Should a Hard-tier Legendary exist, or only Nightmare's? One per tier per zone is 16 new
  swords; Nightmare-only is 8.
- Do parties get a shared loot roll (one drop, one keep-or-sell for the party) or per-player
  rolls as now? Per-player is simpler and cannot be griefed.
