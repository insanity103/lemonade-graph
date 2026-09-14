---
name: roblox-systems
description: Architect and implement Roblox game systems: shops, inventories, combat, tycoon mechanics, NPC AI, progression, data persistence, and multiplayer systems. Use when building any game system beyond a single script — shop UI, inventory management, combat framework, tycoon plot, NPC behavior, leaderboard, or matchmaking. Triggers on game system, shop system, inventory, combat system, tycoon builder, NPC AI, leaderboard, game pass, or multiplayer system for Roblox.
---

# Roblox Game Systems

Architect and implement complete game systems with proper data flow, server authority, and anti-exploit validation.

## System Design Process

For every system, produce these artifacts before writing code:

1. **Data Table** — what fields, types, default values, and storage keys
2. **Flow Diagram** — client request → server validation → mutation → response
3. **API List** — all RemoteEvents/RemoteFunctions with their parameters
4. **Edge Cases** — what happens on disconnect, exploit attempt, race condition
5. **Playtest Plan** — 3–5 specific scenarios to verify

## System References

Each system type has detailed implementation patterns:

- **Data Persistence** — [references/data-persistence.md](references/data-persistence.md): DataStore patterns, session locking, data migration, retry logic, `BindToClose`
- **Shop & Economy** — [references/shop-economy.md](references/shop-economy.md): Currency validation, purchase flow, game pass integration, developer products, receipt handling
- **Inventory** — [references/inventory.md](references/inventory.md): Item schemas, slot management, stacking, equipping, persistence, trading
- **Combat** — [references/combat.md](references/combat.md): Hit detection (Raycast/Region3), damage calculation, cooldowns, projectiles, anti-exploit rate limiting
- **NPC AI** — [references/npc-ai.md](references/npc-ai.md): PathfindingService, state machines (Idle → Patrol → Chase → Attack → Return), aggro, respawn
- **Tycoon** — [references/tycoon.md](references/tycoon.md): Plot system, conveyors, collection, upgrades, rebirth mechanics
- **Progression** — [references/progression.md](references/progression.md): XP, levels, unlocks, leaderboards, rebirth multiplier

## Anti-Exploit Checklist

Every system MUST validate on the server:

- [ ] Player state is legal for the requested action (has item, is alive, is in range)
- [ ] Rate limiting prevents spam (debounce + max requests per second)
- [ ] Numeric inputs are bounded (currency amount, item count, position delta)
- [ ] RemoteEvent payloads are type-checked before use
- [ ] No trust in client-reported state (health, position, inventory)

## Output Format

- **Architecture doc** — data table + flow diagram + API list (markdown)
- **Server script** — `Script` in `ServerScriptService`, handles all validation and mutation
- **Client script** — `LocalScript` in `StarterPlayerScripts` or `StarterGui`, handles input and UI
- **Shared module** — `ModuleScript` in `ReplicatedStorage`, shared constants and types
- **Test checklist** — specific scenarios to verify in Studio

## Constraints

- Server authority is non-negotiable. All mutations happen server-side.
- Use ONLY standard Roblox APIs. No third-party libraries.
- Label all tuning values: `-- [TUNING]: value`
- Separate design from implementation. Give architecture first, code second.
- Max ~100 lines per script. Split systems into server module + client module + shared module.
- End every response with a **Next Step** for Studio testing.
