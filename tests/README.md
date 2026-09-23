# Headless tests

These tests run the real server code from `lemonade-game/` in [Lune](https://github.com/lune-org/lune), a standalone Luau
runtime. They need no Roblox, no Studio and no network, and they run on every pull request
(`.github/workflows/tests.yml`).

```sh
tools/install_lune.sh   # once: installs the pinned Lune (0.10.5, checksum-verified) to ~/.local/bin
make test               # or tests/run.sh: the full suite, ~40 s, what CI runs
make test-quick         # sample sizes x0.1, ~5 s: for iterating
tests/run.sh spin_pools # only tests whose "spec > name" contains the text
tests/run.sh --strict   # known game defects (below) fail the run too
tests/run.sh --seed 7   # another RNG seed (the default is fixed, so every run repeats exactly)
```

The run prints PASS / FAIL / KNOWN for each test, then every failure in full with the last lines the
game logged. It exits non-zero if anything failed.

## Installing Lune

`tools/install_lune.sh` downloads the pinned release zip from GitHub and checks it against a SHA-256
recorded in the script, for Linux x86_64 / aarch64 and macOS x86_64 / arm64. It installs to
`~/.local/bin/lune`, or to `$LUNE_INSTALL_DIR` if set. Running it again does nothing when the right
version is already installed. `tests/run.sh` finds Lune in this order: `$LUNE`, then `lune` on
`PATH`, then `~/.local/bin/lune`. It warns if the version differs from the pin. Rokit users can run
`rokit install` instead, since `rokit.toml` pins the same version. To upgrade, bump `LUNE_VERSION`
in the script and replace the checksums.

## How the harness works

| file | what it is |
| --- | --- |
| `harness/world.luau` | A headless DataModel: Instances (parenting, attributes, tags, Clone/Destroy, `WaitForChild`), signals, services (Players, RunService, DataStoreService, CollectionService, TweenService, ...), a virtual clock behind `task.*`, `os.clock` and `GetServerTimeNow`, and the loader that runs each game file with its own `script`, `require` and `game`. |
| `harness/datatypes.luau` | `Vector3`, `CFrame`, `Color3` with real maths; `UDim2`, `Enum`, `Random` (seeded) and the other value types. |
| `harness/project.luau` | Mounts `default.project.json` the way Rojo does, so the tree matches what the game syncs into Studio. |
| `harness/game.luau` | Boots the game: mounts the project, lays down the stock Baseplate, adds the two Studio-only ServerStorage templates, and runs real server Scripts (RuntimeBootstrap, PlayerDataStore, SwordDropSystem, GameplayServices). Adds players through `PlayerAdded`, spawns enemies with the attributes EnemyCombat stamps, and kills them through `Humanoid.Died`. |
| `harness/test.luau`, `run.luau` | The test API (`t.test`, `t.check`, `t.expect`, `t.eq`, `t.near`, `t.note`, `t.scale`) and the runner. |

**What is real:** all game logic, loaded unmodified from `lemonade-game/`. Tests enter through the
same entry points the engine uses: `PlayerAdded`, the `SpinAction` and `UpgradeAction` remotes,
`Humanoid.Died`, and `PlayerDataService` load, save and release against an in-memory DataStore.

**What is stubbed:** the engine itself. There is no physics, rendering or animation.
`Workspace:Raycast` finds nothing. Tweens jump to their goal. `.rbxm` / `.rbxmx` assets mount as empty
Models, so NPC rigs fall back to block rigs and log a warning. `HttpService` requests error.
`ServerStorage.BossSwordTool` and `SwordMeshTemplate` are stand-ins for the place file's templates.
If game code uses an engine API the stubs lack, the test fails loudly with the Luau error; it does
not pass quietly. `WaitForChild` with no timeout on a missing child raises "Infinite yield" instead
of hanging.

A test fails when game code errors inside a `Connect` handler or a spawned task, which Roblox would
only print. Game output goes to a log that is printed for failing tests.

**Time is virtual.** Nothing moves the clock until a test calls `g:advance(seconds)`, which runs
timers in order. `g:flush()` runs `task.defer` work. A 2.4 s wheel spin or a 120 s autosave costs
no wall time.

## What is covered

| spec | covers |
| --- | --- |
| `spin_pools` | Every step's weights sum to 100 (the ultra rides on top) and `SpinPools.Odds` sums to 1 at every level from the gate to 100. `Odds` matches the shipped table exactly. 100,000 spins per (area, step), 32 steps, go through `SpinService.Roll`, and each row's landed rate must be within 5 sigma of the shipped odds. No spin lands a sword above the player's level, checked at every level where a step's roster changes. A low-level player can't spin a later area. `Grant` builds the rolled sword at its rarity with 1 prefix. |
| `prefix_odds` | Every pool sword builds with exactly 1 prefix. 100k one-slot rolls give 1 prefix each, and 2 or 3 unlocked slots give one prefix per category. A level-3 player gets 0 top-tier prefixes in 100k rolls, also at maximum luck and end to end through `Grant`. Odds rise with rarity at every bracket (mean rung and P(rung ≥ k)). Odds rise with level for every rarity; the exception is the chase rung, which is made rarer each bracket on purpose. Rolled prefixes match `TierOdds` within 5 sigma. The level wall and the "luck never moves a chase" rule hold. |
| `save_migration` | A pre-spin profile (Blessed and four-prefix swords, old rung-10 names, removed reforge and auto-sell fields) loads through the real join path. Extra prefixes collapse to the owned slots, strongest first, and stats are re-derived. Unlocking a slot wakes the next stored prefix. Old vault swords are stored and withdrawn collapsed (name and stats), and vault entries an older build left half-collapsed heal on load. Every stored field survives a save. The collapsed save reloads identically. Spin depth is rebuilt from level plus first boss kill. A DataStore hiccup is retried, and a failed load never overwrites the stored profile. |
| `token_economy` | Every kill, across 8 areas and 4 roles, pays tokens in its configured band into the saved `Tokens` attribute, and the client is told the same number. Tokens reach the DataStore on autosave and on leave, and come back on rejoin. No payment for pre-load kills, dummies, untagged deaths or a repeated `Died`. Kills record depth. A spin costs exactly `pool.cost[step]` at every area and step. Prices climb, and the "5-13 kills a spin" design note holds. Multi-spin costs count × price, and Lucky Spins bonus swords are free. Every refusal takes nothing. Every upgrade tier charges exactly its price. |
| `config_integrity` | Every pool row resolves to its own sword and rarity in BossWeapons (`Resolve` would otherwise quietly hand out a Legendary or a Common). Pools are well formed. The documented pool shape holds. Areas agree across SpinPools, WorldLayout, BossWeapons and TokenRules with no orphans. Every token role has a band. Every upgrade has a price, a value and a gate, matching `WeaponModifiers.SlotUnlocks`. Everything the wheel, the stall and the swords write is persisted. Every remote a script waits for is created. Prefix names are unique. |

Before this suite landed, 18 planted defects were each confirmed to fail it: a level-cap bypass,
weight typos, a wrong-step roll, a biased pick, 2 base slots, a mislabelled chase rung, flat rarity
odds, tokens written to the wrong or an unsaved attribute, a spin charged the wrong price, an
upgrade discount, a reversed prefix collapse, dropped save fields, an uncollapsed vault, and a
renamed, mislabelled or unpriced config row.

**Not covered yet:** combat and damage (EnemyCombat, SwordSystem), XP and levelling, quests,
rebirth, the merchant, trading, the vault's remote handlers (only the migration and rebuild paths
it uses), the admin menu, anything client-side (GUIs, SpinPopup, TokenDrops animation), the map
project (`map.project.json`), and real DataStore behaviour such as throttling, size limits or
cross-server session locks beyond the lock fields.

## Known issues

A test marked `{ knownIssue = "..." }` documents a confirmed defect in the game code. It runs every
time and its failures are printed in full under **KNOWN ISSUES**, but it does not fail the run. Once
the defect is fixed the test passes, and the runner then fails with `FIXED?` until the marker is
removed. `--strict` turns known issues into failures. Currently:

- **Spin swords become starters without the template.** With no `ServerStorage.BossSwordTool` (a
  fresh Rojo sync), spin swords are cloned from the starter template and carry `Starter = true`.
  SwordDropSystem's starter de-dupe then destroys all but one: 3 paid spins leave 1 sword.

## Adding a test

Add `tests/spec/<name>.spec.luau` returning `function(t)` and register tests with
`t.test(name, fn)`. Use `Game.new({ scripts = true })` for a booted server, `g:addPlayer{...}`,
`g:module("ReplicatedStorage.Config.X")` for the same module instance the game uses, and
`g:remote("Name")` plus `remote.OnServerEvent:Fire(player, ...)` to act as a client. Read what the
server sent with `g.world:fired(remote)`. Use `t.scale(n)` for sample sizes so `--quick` stays quick.
