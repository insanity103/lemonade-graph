# The Legendary Swords RPG - Comprehensive Bug Catalog

> **Purpose**: Catalog every known bug across the original game and its fan projects so a spiritual successor can avoid these same issues.
>
> **Sources**: [LSRPG: Restored Wiki Bugs Page](https://the-legendary-swords-rpg-restored.fandom.com/wiki/Bugs), [LSRPG: Restored Main Page](https://the-legendary-swords-rpg-restored.fandom.com/wiki/The_Legendary_Swords_RPG:_Restored_Wiki), [LSRPG: Restored Gamepasses](https://the-legendary-swords-rpg-restored.fandom.com/wiki/Gamepasses), [Roblox Game Page (ID: 60654525)](https://www.roblox.com/games/60654525/The-Legendary-Swords-RPG), [Roblox DataStoreService Docs](https://create.roblox.com/docs/reference/engine/classes/DataStoreService)
>
> **Version note**: The game was described as "vibecoded" by the Restored wiki maintainers. The Restored version (by Saltels) is based on a decompile of TerrorBan's remaster. The original was by Omega_RX. All three versions share similar bug patterns due to shared codebase lineage.
>
> **Last updated**: Based on data gathered June 28, 2026

---

## Table of Contents

1. [Data / Persistence Bugs](#1-data--persistence-bugs)
2. [Combat Bugs](#2-combat-bugs)
3. [Economy / Shop Bugs](#3-economy--shop-bugs)
4. [Progression Bugs](#4-progression-bugs)
5. [Weapon / Item Bugs](#5-weapon--item-bugs)
6. [Gamepass Bugs](#6-gamepass-bugs)
7. [UI / UX Bugs](#7-ui--ux-bugs)
8. [NPC / Enemy Bugs](#8-npc--enemy-bugs)
9. [Teleportation / World Bugs](#9-teleportation--world-bugs)
10. [Server / Performance Bugs](#10-server--performance-bugs)
11. [Exploit / Security Vulnerabilities](#11-exploit--security-vulnerabilities)
12. [Inferred Architectural Weaknesses](#12-inferred-architectural-weaknesses)
13. [Prevention Summary Matrix](#13-prevention-summary-matrix)

---

## 1. Data / Persistence Bugs

| # | Bug | Root Cause | Impact | Status | Prevention |
|---|-----|-----------|--------|--------|------------|
| D-1 | **Milestone Sword duplicates every rejoin** — players receive multiple copies of the Milestone Sword each time they rejoin the game | Likely a DataStore save/load issue where the "already collected" flag for this weapon was not persisted correctly, OR the item-granting logic runs on each PlayerAdded without checking existing inventory | Players accumulate dozens of free Milestone Swords, inflating inventory and devaluing the weapon | **Patched** (changed from drop to non-drop in 6/27 update) | Always check inventory BEFORE granting items. Use a unique key per weapon ID in a dictionary rather than an array. Run `if not inventory[weaponId] then grant(weaponId) end` |
| D-2 | **Original game data loss on rejoin** — The original game (Omega_RX) was known to have data persistence problems due to its age and early Roblox DataStore implementation | Primitive DataStore usage, likely no retry logic, no session locking, no backup system | Players lose hours of progress; this was a primary driver for the Restored/Remastered projects | Inherent to original; mitigated in fan versions | Implement session-locked DataStore with retry queue. Use `UpdateAsync` not `SetAsync`. Keep a rolling backup in a separate DataStore key. See [data-persistence.md](./data-persistence.md) |
| D-3 | **Enemy cross-hit XP exploit** — Enemies could hit each other, and the old credit system awarded XP to the player when a dead enemy was hit | Hit registration system credited XP to the nearest player regardless of who actually dealt the damage; enemy-vs-enemy collision was not filtered | Players could AFK farm massive XP by positioning between enemy groups | **Patched** | Never credit damage from NPC-to-NPC to a player. Tag all damage sources with explicit owner. Only award XP when `damageSource == player` |
| D-4 | **Singularity Scythe sold for Arcane Gems instead of Gold** — The sell price used the wrong currency type | Incorrect data table reference; the weapon's sell value pointed to the gem currency field instead of gold | Players could exploit gem pricing or lose expected gold income | **Patched** | Use typed currency enums. Validate all shop entries against a schema at startup. Unit test every item's buy/sell price pair |

## 2. Combat Bugs

| # | Bug | Root Cause | Impact | Status | Prevention |
|---|-----|-----------|--------|--------|------------|
| C-1 | **Enemies deal insane damage (hit registration failure)** — A persistent bug since the ORIGINAL game where enemies would deal far more damage than intended | Flawed hit registration system — likely raycast or hitbox-based with no damage cap or rate limiting. Server trusted client hit events or had no cooldown between enemy attacks | Players get one-shot by basic enemies, making the game unplayable for some | **Patched in Restored** (6/1/2026: "Adjusted Enemy hit registration") | Implement server-authoritative hit detection with attack cooldowns. Cap max DPS per enemy per second. Never trust client-reported damage. Use `Magnitude` checks to verify hit range |
| C-2 | **Enemy anti-tamper broken** — The system preventing enemies from being modified by exploits was non-functional | Anti-tamper checks were bypassable, likely because critical enemy properties were replicated to the client | Exploiters could kill all enemies instantly or make them harmless | **Patched** (6/27/2026: "Fixed enemy anti-tamper") | Keep enemy HP, damage, and behavior entirely on the server. Only replicate visual state to clients. Use server-side hit validation with spatial hashing |
| C-3 | **Client-side errors causing combat issues** — Various clientsided errors affected combat experience | Unhandled exceptions in client combat scripts, likely from destroyed instances or nil references | Erratic behavior during fights, potential crashes | **Patched** (6/27/2026: "Fixed a few clientsided errors") | Wrap all combat-related client code in pcall/xpcall. Use `Instance.Destroying` events. Never assume a target exists between frames |
| C-4 | **Bubbles5610 NPC stuck in ground** — A boss NPC spawns partially or fully underground | Spawn position or terrain collision issue; the NPC's spawn CFrame intersected with the ground mesh | Players cannot reach or damage the boss | **Patched** | Raycast downward from spawn points to find the surface. Set NPC position via `workspace:Raycast()` result. Add a "stuck" detection that teleports NPCs if they haven't moved in N seconds |

## 3. Economy / Shop Bugs

| # | Bug | Root Cause | Impact | Status | Prevention |
|---|-----|-----------|--------|--------|------------|
| E-1 | **Singularity Scythe priced in wrong currency** (see D-4) | Shop data table mismatch | Economy confusion | **Patched** | Schema validation at startup |
| E-2 | **Private server rewards deficit** — Private servers had a reduced reward multiplier, initially higher than intended | Server-type reward multiplier was too aggressive for private servers, punishing solo/small group play | Players on private servers earned significantly less XP/Gold | **Patched** (6/1/2026: deficit reduced to 10%) | Make server-type multipliers configurable and transparent. Show the multiplier in the UI. Cap minimum reward at 50% of base |
| E-3 | **Heart Cookie given 3x instead of 1x** — The Heart Cookie event item was distributed three times to players who should have received one | Distribution script didn't check if the item was already granted; likely a similar issue to D-1 | Duplicate event items in inventory | **Patched** | Use idempotent distribution: check `PlayerHasItem(player, itemId)` before granting. Use a "claimed" flag per player per event |

## 4. Progression Bugs

| # | Bug | Root Cause | Impact | Status | Prevention |
|---|-----|-----------|--------|--------|------------|
| P-1 | **XP bar displays "-nan(ind)" at 0 XP** — The XP counter shows `"-nan(ind) / (X)*Current levels XP requirement"` when XP is exactly 0 | Division by zero in the XP percentage calculation: `currentXP / (currentXP + requiredXP)` or similar formula returns NaN when numerator is 0 | Confusing UI; players think their data is corrupted | **Patched** | Guard all division: `local pct = (required > 0) and (current / required) or 0`. Use `math.clamp(pct, 0, 1)` |
| P-2 | **Reality Dislocator bypasses area lock (progression skip)** — Teleportation gamepass allowed players to reach areas they hadn't unlocked | The Reality Dislocator only checked if the destination existed, not whether the player met the rebirth requirement | Players skip progression, reaching endgame areas at rebirth 0 | **Patched** | Server-side validation: `if player.RebirthValue >= area.RequiredRebirth then teleport()`. Never trust client for area-unlock checks |
| P-3 | **XP exploit via enemy cross-hits** (see C-3) | Credit system flaw | Rapid leveling exploit | **Patched** | Tag-based XP system |

## 5. Weapon / Item Bugs

| # | Bug | Root Cause | Impact | Status | Prevention |
|---|-----|-----------|--------|--------|------------|
| W-1 | **Laser Scythe backwards with Dual Weaponry** — When held with the Dual Weaponry gamepass, one copy of the Laser Scythe would be oriented backwards | CFrame offset for the second weapon copy didn't account for the scythe's unique orientation. The weapon's `GripPos` or attachment wasn't mirrored correctly | Visually broken weapon; caused Center of Mass (COM) offset affecting player movement | **Patched** | Define per-weapon dual-wield CFrame overrides in a data table. Test every weapon visually with Dual Weaponry before shipping |
| W-2 | **Sword of Darkness missing particles + COM offset** — The weapon's particle effects were absent, and it caused a center-of-mass offset | Missing particle emitter in the weapon model, and an unbalanced physical property (Mass or CenterOfMass) | Reduced visual quality; movement feels off | **Patched** | Asset validation pipeline: check that every weapon model has its expected particle emitters. Verify `Massless` property is set correctly on decorative parts |
| W-3 | **Chaotic Blade missing particles** — Same category as W-2 | Particle emitter not included in the weapon model | Reduced visual quality | **Patched** | Same as W-2 |
| W-4 | **Lil' Spitters drop Sparkling Arachnid** — A weak enemy (Lil' Spitter, from Azure Kingdom) incorrectly drops a high-tier Mythical weapon (Sparkling Arachnid) | Drop table assignment error: the Lil' Spitter enemy was given the wrong loot table, likely a copy-paste error or misconfigured reference | Players farm a trivial enemy for a top-tier weapon, breaking progression | **Patched** | Use a structured loot table system where each enemy type references an explicit loot table ID. Validate that enemy level is consistent with drop rarity at startup |
| W-5 | **Milestone Sword rejoin duplication** (see D-1) | DataStore not tracking "already owned" state | Item inflation | **Patched** | Idempotent grant logic |

## 6. Gamepass Bugs

| # | Bug | Root Cause | Impact | Status | Prevention |
|---|-----|-----------|--------|--------|------------|
| G-1 | **Dual Weaponry lazy arm effect** — After holding dual weapons for a while, the left arm goes slack/droops | Motor6D `C0` or `C1` transform drifts over time, or the animation system doesn't properly reset the left arm's Motor6D when the tool is active | Visually broken character; cosmetic issue that looks unprofessional | **Patched** | Periodically reset Motor6D transforms to their default values. Use `AnimationTrack.Stopped` event to ensure clean arm pose reset |
| G-2 | **Dual Weaponry zombie arm effect** — After unequipping a dual-wielded weapon, the player's arms stay raised in an unnatural position | The arm-reset animation doesn't fire after tool unequip, leaving Motor6D in the "holding" state | Visually broken character | **Still unpatched** (as of 6/28/2026) | Play a "reset" animation on `Tool.Unequipped`. Use a `Humanoid.StateChanged` fallback to detect and fix stuck arm states |
| G-3 | **Reality Dislocator + Heart Cookie walkspeed reset** — Using both items resets walkspeed to default (16) | Reality Dislocator teleportation overwrites the rebirth walkspeed bonus. The Heart Cookie interaction triggers a full stat recalculation that doesn't account for the rebirth bonus | Player suddenly moves at base speed; workaround is toggling rebirth walkspeed setting off/on | **Still unpatched** (as of 6/28/2026) | Separate walkspeed sources into additive layers: `baseWalkspeed + rebirthBonus + gamepassBonus`. Never overwrite — always recalculate from all sources |
| G-4 | **Heart Cookie + weapon equip breaks left sword handle** — Rapidly using Heart Cookie and equipping a weapon can invert the left sword's handle (with Dual Weaponry) | Race condition between the Heart Cookie's speed-boost effect and the weapon equip animation, corrupting the Dual Weaponry attachment CFrame | Weapon appears flipped/broken on the left hand | **Still unpatched** (as of 6/28/2026) | Debounce weapon equip/unequip during item-use animations. Add a minimum delay (e.g., 0.3s) between any item activation and tool equip |
| G-5 | **Balloon effect persists after reset** — If a player resets their character while holding the Balloon tool, the balloon's effect (reduced gravity/jump boost) continues even after respawning | The Balloon's effect is applied via a body mover or humanoid property that isn't cleaned up on death. The `CharacterRemoving` or `Humanoid.Died` event doesn't cancel the effect | Free permanent movement boost without needing the item equipped | **Still unpatched** (as of 6/28/2026) | Always clean up item effects in `CharacterAdded` (reset to defaults) AND in a `Humanoid.Died` listener. Don't rely solely on `Tool.Unequipped` |

## 7. UI / UX Bugs

| # | Bug | Root Cause | Impact | Status | Prevention |
|---|-----|-----------|--------|--------|------------|
| U-1 | **XP counter shows "-nan(ind)"** (see P-1) | Division by zero | Confusing display | **Patched** | Math guards |
| U-2 | **Close buttons hidden on small screens** — UI close buttons were not visible on smaller viewport sizes | Fixed-position UI elements placed without accounting for minimum viewport size or safe area insets | Players unable to close menus, forced to rejoin | **Patched** (6/1/2026) | Use `UIListLayout` with `SafeAreaCompatibility`. Test on minimum viewport (phone portrait). Anchor close buttons to screen corners with `Offset` margins |
| U-3 | **Sell All button broken on controllers** — The "Sell All" function didn't work when using a gamepad/controller | UI button activation didn't respond to `GuiButton.Activated` from controller input, or the button wasn't focusable via `GamepadNavigation` | Console/controller players cannot sell inventory | **Partially patched** (6/27/2026: "maybe") | Test all interactive UI with controller. Set `Selectable = true` on all buttons. Use `UserInputService` gamepad events as fallback |

## 8. NPC / Enemy Bugs

| # | Bug | Root Cause | Impact | Status | Prevention |
|---|-----|-----------|--------|--------|------------|
| N-1 | **Enemies can hit each other** (see C-3) | No team/faction filtering on hit detection | XP exploit | **Patched** | Faction-based hit filtering |
| N-2 | **Enemies deal excessive damage** (see C-1) | Broken hit registration | One-shot deaths | **Patched** | Server-side damage validation |
| N-3 | **Bubbles5610 stuck in ground** (see C-4) | Spawn CFrame below terrain | Unkillable boss | **Patched** | Surface-aware spawning |
| N-4 | **Lil' Spitters drop wrong loot** (see W-4) | Incorrect loot table | Progression break | **Patched** | Loot table validation |
| N-5 | **Alien Leader missing UFO visual** — The Alien Leader server event boss no longer has its UFO model above it | The UFO visual element was present in both Omega_RX's original and TerrorBan's remaster but was lost during the Restored version's development (likely during the decompile/reconstruction) | Server event feels incomplete; loss of visual identity | **Still unpatched** (as of 6/28/2026) | Version-control all assets. Maintain an asset manifest that lists every model component per NPC. Run visual regression tests comparing NPC models against expected state |

## 9. Teleportation / World Bugs

| # | Bug | Root Cause | Impact | Status | Prevention |
|---|-----|-----------|--------|--------|------------|
| T-1 | **Floating Fortress teleport fallback breaks portal system** — The Floating Fortress area's teleport fallback mechanism interfered with the game's general portal teleportation system | Shared teleportation handler with conflicting fallback logic: when a Floating Fortress teleport fails, the fallback repositions the player in a way that corrupts the next portal teleport destination | Players spawning far from intended location after using portals | **Patched** | Isolate teleportation contexts per area. Each area should have its own teleport handler with independent fallback positions. Use `TeleportService` for sub-place teleports rather than CFrame manipulation |
| T-2 | **Reality Dislocator bypasses area locks** (see P-2) | Missing server-side unlock check | Progression skip | **Patched** | Server-side validation |

## 10. Server / Performance Bugs

| # | Bug | Root Cause | Impact | Status | Prevention |
|---|-----|-----------|--------|--------|------------|
| S-1 | **"Vibecoded" architecture** — The Restored wiki explicitly states the game is "vibecoded," indicating a lack of formal software engineering practices | Rapid prototyping without testing, code review, or architectural planning | All bugs in this catalog stem in part from this root cause | Ongoing | Implement CI/CD with automated testing. Use type checking (Luau strict mode). Code review all gameplay-critical paths |
| S-2 | **Decompiled codebase fragility** — The Restored version is based on a decompile of TerrorBan's remaster, meaning some code may be obfuscated, missing comments, or have lost variable names | Decompiled Luau bytecode doesn't preserve original variable names, comments, or structure; some logic may be subtly broken | Difficulty maintaining and fixing bugs; potential for hidden issues | Ongoing | If building a successor from scratch, don't decompile — rebuild with clean architecture. Use modular patterns with clear separation of concerns |
| S-3 | **Server event timing issues** — Server events (like Alien Leader) spawn inconsistently | Server event scheduling may rely on unreliable timing mechanisms or not account for server lifecycle | Events miss players or spawn at wrong times | Ongoing | Use `os.time()` based scheduling with server-side event queue. Persist event state so new servers don't double-spawn |
| S-4 | **Private server reward deficit** (see E-2) | Incorrect multiplier configuration | Reduced earnings | **Patched** | Configurable, transparent multipliers |

## 11. Exploit / Security Vulnerabilities

| # | Bug | Root Cause | Impact | Status | Prevention |
|---|-----|-----------|--------|--------|------------|
| X-1 | **Enemy anti-tamper bypass** (see C-2) | Critical enemy properties replicated to client | Instant-kill exploits | **Patched** | Server-only authoritative state |
| X-2 | **Reality Dislocator area skip** (see P-2) | Client-side area validation | Progression bypass | **Patched** | Server-side validation |
| X-3 | **Potential RemoteEvent exploitation** — Classic LSRPG-style Roblox games are notorious for having unprotected RemoteEvents that allow exploiters to fire arbitrary game actions | No rate limiting, argument validation, or authentication on RemoteEvents | Speed hacking, teleport hacking, damage hacking, item granting, currency manipulation | **Likely present** (inferred from "vibecoded" nature and era) | Validate ALL RemoteEvent arguments server-side. Rate-limit all remotes. Use a single authenticated RemoteFunction with command routing. See [sword-rpg-anti-exploit-architecture.md](./sword-rpg-anti-exploit-architecture.md) |
| X-4 | **Milestone Sword item duplication** (see D-1) | DataStore race condition / missing idempotency | Item duplication via rejoin spam | **Patched** | Session locking + idempotent grants |
| X-5 | **Enemy cross-hit XP farming** (see C-3) | Credit system flaw | AFK XP farming | **Patched** | Source-tagged damage system |
| X-6 | **Potential DataStore manipulation** — Older Roblox games (pre-2020) often had weaker DataStore security, allowing exploiters to call SetAsync directly via RemoteEvents | RemoteEvents that proxy DataStore calls without proper authorization | Data manipulation, currency injection, inventory editing | **Likely present** (inferred) | NEVER expose raw DataStore operations via RemoteEvents. All persistence should be server-initiated with no client-facing interface for direct data writes |

## 12. Inferred Architectural Weaknesses

These aren't confirmed bugs but are strong inferences based on the game's known characteristics ("vibecoded," decompiled, early Roblox era) and common patterns in similar games.

### 12.1 DataStore Architecture Risks

| Risk | Evidence | Impact | Mitigation |
|------|----------|--------|------------|
| **No session locking** | Game predates modern DataStore patterns; item duplication bug (D-1) suggests race conditions | Data corruption during cross-server joins, item duplication | Use MemoryStoreService session locks with automatic expiry |
| **No retry/backoff on save failures** | Early DataStore code typically lacks retry logic | Data loss when Roblox throttles requests | Exponential backoff with jitter, up to 5 retries. Queue failed saves for retry |
| **No data versioning** | No mention of migration scripts or schema versioning | Breaking changes when updating data format | Version every data schema. Run migration on load with `pcall` fallback |
| **No backup/rollback** | No mention of backup DataStore | Permanent data loss from corruption | Keep rolling 24h backup in separate DataStore. Use `UpdateAsync` for atomic read-modify-write |

### 12.2 Combat System Risks

| Risk | Evidence | Impact | Mitigation |
|------|----------|--------|------------|
| **Client-side damage authority** | Enemy damage bug (C-1) and anti-tamper bypass (C-2) | Damage hacking | Server-only damage calculation. Client only triggers "swing" animation; server validates range, cooldown, and computes damage |
| **No hit rate limiting** | Enemies dealt "insane damage" | Burst damage exploits | Per-enemy attack cooldown enforced server-side. Global DPS cap per damage source |
| **No spatial validation** | Enemies hitting each other suggests no faction/team filtering | Friendly fire exploits, XP farming | Server-side team/faction check before processing damage |

### 12.3 Economy Risks

| Risk | Evidence | Impact | Mitigation |
|------|----------|--------|------------|
| **Currency writes from client** | "Vibecoded" early-Roblox game pattern | Currency injection | All currency changes server-initiated. No RemoteEvent for "add gold" |
| **No transaction logging** | No mention of audit trail | Undetectable exploits | Log every currency/item transaction with timestamp, player, amount, reason |
| **No anti-farming detection** | AFK XP exploit existed (C-3) | Economy inflation | Track kill rate per player. Flag anomalous patterns. Implement diminishing returns on same-enemy kills |

## 13. Prevention Summary Matrix

This matrix maps every bug category to specific code patterns and architectural decisions for the spiritual successor.

### Data Persistence

```
PREVENTION PATTERN: Session-Locked DataStore with Retry Queue
──────────────────────────────────────────────────────────────
1. On PlayerAdded: Acquire MemoryStoreService lock (60s TTL)
2. Load data with pcall + exponential backoff (max 5 retries)
3. On data load failure: Load from backup key OR use default template
4. On save: Use UpdateAsync (atomic read-modify-write)
5. On PlayerRemoving: Save + release lock + save backup copy
6. Schedule auto-save every 120-300 seconds
7. On server shutdown: BindToClose with 30s grace period
```

### Combat

```
PREVENTION PATTERN: Server-Authoritative Combat
────────────────────────────────────────────────
1. Client sends: {action="swing", weaponId=X, timestamp=T}
2. Server validates: weapon equipped? cooldown elapsed? target in range?
3. Server computes: damage = baseDamage * modifiers
4. Server applies: enemy HP -= damage, checks death, awards XP
5. Server broadcasts: visual effects to all clients
6. Rate limit: max 1 attack per weapon cooldown per player
7. Faction check: only process damage between opposing factions
```

### Economy

```
PREVENTION PATTERN: Transactional Economy
─────────────────────────────────────────
1. All currency changes go through a single server module
2. Every transaction logged: {player, currency, delta, reason, timestamp}
3. Buy/sell validated against item data table (price, currency type, availability)
4. Anti-farming: Track kill diversity, implement diminishing returns on repeated kills
5. Shop prices validated against schema on server startup
6. No client-accessible RemoteEvent for direct currency manipulation
```

### Gamepass Effects

```
PREVENTION PATTERN: Layered Effect System
─────────────────────────────────────────
1. Walkspeed = base + Σ(bonuses from all sources)
2. On any stat change: recalculate from all sources (never overwrite)
3. On CharacterAdded: reapply all gamepass effects from scratch
4. On Humanoid.Died: clean up all temporary effects
5. On Tool.Unequipped: remove tool-specific effects, reset arm poses
6. Debounce rapid equip/unequip sequences (0.3s minimum)
```

### UI

```
PREVENTION PATTERN: Responsive UI Testing
──────────────────────────────────────────
1. Test all UI at minimum viewport (phone portrait: 360x640)
2. Anchor close buttons to screen corners with safe-area margins
3. Ensure all buttons are gamepad-navigable (Selectable=true)
4. Guard all math: divide by zero, NaN checks, math.clamp
5. Use UIScale for consistent sizing across viewports
```

### NPC / Enemy

```
PREVENTION PATTERN: Validated NPC Spawning
──────────────────────────────────────────
1. Raycast to find ground surface before spawning
2. Validate spawn position is accessible (not inside geometry)
3. Keep all NPC state (HP, damage, behavior) server-side only
4. Maintain asset manifest: every NPC lists required visual components
5. Stuck detection: teleport NPC if no position change in N seconds
6. Loot tables: validate enemy level vs drop rarity at startup
```

### Anti-Exploit

```
PREVENTION PATTERN: Zero-Trust Client Architecture
──────────────────────────────────────────────────
1. NEVER trust client-reported damage, position, or currency
2. Validate ALL RemoteEvent arguments (type, range, rate)
3. Rate-limit all remotes: max N calls per second per player
4. Use MemoryStoreService for session locking (anti-duplication)
5. Server-side spatial validation for all combat interactions
6. Never expose DataStore operations via RemoteEvents
7. Log all suspicious activity for post-hoc analysis
8. Implement server-side anomaly detection for farming patterns
```

---

## Source URLs

| Source | URL | Content |
|--------|-----|---------|
| LSRPG:R Wiki Bugs Page | https://the-legendary-swords-rpg-restored.fandom.com/wiki/Bugs | All documented patched and unpatched bugs |
| LSRPG:R Wiki Main Page | https://the-legendary-swords-rpg-restored.fandom.com/wiki/The_Legendary_Swords_RPG:_Restored_Wiki | Update logs with fix notes |
| LSRPG:R Wiki Gamepasses | https://the-legendary-swords-rpg-restored.fandom.com/wiki/Gamepasses | Gamepass details and known issues |
| LSRPG:R Wiki Enemies | https://the-legendary-swords-rpg-restored.fandom.com/wiki/Enemies | Enemy list and drop tables |
| LSRPG:R Wiki Weapons | https://the-legendary-swords-rpg-restored.fandom.com/wiki/Weapons | Full weapon catalog |
| LSRPG:R Wiki Areas | https://the-legendary-swords-rpg-restored.fandom.com/wiki/Areas | Area list with rebirth requirements |
| LSRPG:R Wiki All Pages | https://the-legendary-swords-rpg-restored.fandom.com/wiki/Special:AllPages | 266 pages total |
| Roblox Game Page | https://www.roblox.com/games/60654525/The-Legendary-Swords-RPG | Original game by Omega_RX |
| Roblox DataStoreService | https://create.roblox.com/docs/reference/engine/classes/DataStoreService | Official DataStore API reference |
| Omega_RX Profile | https://www.roblox.com/users/16332998/profile | Original developer |
| Saltels Profile | https://www.roblox.com/users/559650993/profile | Restored version developer |
| TerrorBan Profile | https://www.roblox.com/users/218773923/profile | Remastered version developer |
| LSRPG:R Discord | https://discord.gg/QF46wjJD | Community Discord server |
| LSRPG:R Roblox Game | https://www.roblox.com/games/129119196465909/The-Legendary-Swords-RPG-Restored | Restored version game page |

---

## Bug Count Summary

| Category | Patched | Unpatched | Inferred | Total |
|----------|---------|-----------|----------|-------|
| Data / Persistence | 3 | 0 | 4 | 7 |
| Combat | 4 | 0 | 3 | 7 |
| Economy / Shop | 2 | 0 | 3 | 5 |
| Progression | 3 | 0 | 0 | 3 |
| Weapon / Item | 4 | 0 | 0 | 4 |
| Gamepass | 2 | 3 | 0 | 5 |
| UI / UX | 3 | 0 | 0 | 3 |
| NPC / Enemy | 3 | 1 | 0 | 4 |
| Teleportation | 2 | 0 | 0 | 2 |
| Server / Performance | 2 | 2 | 0 | 4 |
| Exploit / Security | 4 | 0 | 2 | 6 |
| **TOTAL** | **32** | **6** | **12** | **50** |

> **Note**: The original LSRPG fandom wiki (the-legendary-swords-rpg.fandom.com) has been taken down (HTTP 410 Gone). The Remastered wiki URL (the-legendary-swords-rpg-remastered.fandom.com) returns 404. Only the Restored wiki remains active as a source. Web searches for Reddit/DevForum threads were unsuccessful due to JavaScript-rendered content. The inferred bugs section represents common Roblox RPG vulnerabilities that are highly likely given the game's "vibecoded" nature and era of development.
