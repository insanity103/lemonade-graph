---
name: roblox-luau
description: Write production-quality Luau scripts for Roblox with correct script types, API patterns, and anti-exploit validation. Use for any Luau coding task: game logic, UI scripts, visual effects, input handling, animations, sound, or module scripts. Triggers on Luau, Roblox scripting, RemoteEvent pattern, DataStore code, client/server script, or any Roblox code request.
---

# Roblox Luau Scripting

Write production-quality Luau with correct script types, server authority, and Roblox API patterns.

## Script Type & Location

ALWAYS specify the correct type and location:

| Script Type | Location | Use For |
|-------------|----------|---------|
| `Script` | `ServerScriptService` | Game logic, damage, spawning, DataStores, validation |
| `LocalScript` | `StarterPlayerScripts` or `StarterCharacterScripts` | Input, camera, client UI, visual feedback |
| `ModuleScript` | `ReplicatedStorage` | Shared logic, data tables, utility functions |
| `LocalScript` | Inside a `ScreenGui` in `StarterGui` | UI interactions, button handlers |

## Required Code Patterns

- `task.wait()`, `task.spawn()`, `task.delay()` — NEVER `wait()`, `spawn()`, `delay()`
- All DataStore calls wrapped in `pcall` with retry logic (see reference)
- `game:BindToClose()` for saving on shutdown
- Debounce rapid-fire events with boolean flag + `task.delay`
- `CollectionService` for managing groups of identical objects
- Type-annotate function parameters and return values
- Explicit `:Disconnect()` or `Maid` pattern for all event connections
- Constants table at top of script for all tuning values
- Early returns to avoid deep nesting
- Max ~50 lines per function; split larger logic into named sub-functions

## RemoteEvent/RemoteFunction Pattern

For the full client/server validation pattern with anti-exploit checks, read [references/remote-pattern.md](references/remote-pattern.md).

Quick reference — Client (LocalScript):
```lua
local RemoteEvent = ReplicatedStorage.Remotes:WaitForChild("ActionName")
RemoteEvent:FireServer(playerInput)
```

Server (Script in ServerScriptService):
```lua
local RemoteEvent = ReplicatedStorage.Remotes:WaitForChild("ActionName")
RemoteEvent.OnServerEvent:Connect(function(player, input)
    -- VALIDATE: check player has permission, input is in bounds, rate-limit
    -- MUTATE: apply the change
    -- RESPOND: fire back to client if needed
end)
```

## DataStore Pattern

For the full data persistence pattern with retry, migration, and session locking, read [references/datastore-pattern.md](references/datastore-pattern.md).

## Genre-Specific Code Patterns

For detailed code templates, read the appropriate reference:
- **Obby** (checkpoints, kill bricks, timers, rebirth) → [references/obby-code.md](references/obby-code.md)
- **Combat / FPS** (hit detection, damage, projectiles, cooldowns) → [references/combat-code.md](references/combat-code.md)
- **Tycoon** (conveyors, buildings, upgrades, rebirth) → [references/tycoon-code.md](references/tycoon-code.md)
- **Horror** (lighting, sound, NPC AI, sanity system) → [references/horror-code.md](references/horror-code.md)

## Code Template

Every script should follow this structure:

```lua
-- [ScriptType] | [Location] | [Purpose]
local Players = game:GetService("Players")
-- other services...

-- === CONSTANTS ===
local DAMAGE = 25        -- [TUNING]
local COOLDOWN = 0.5     -- [TUNING]

-- === STATE ===
local playerData = {}

-- === FUNCTIONS ===
local function doThing(player: Player, amount: number): boolean
    -- logic here
    return true
end

-- === CONNECTIONS ===
local remote = ReplicatedStorage.Remotes:WaitForChild("Action")
remote.OnServerEvent:Connect(function(player, amount)
    -- validate, mutate, respond
end)
```

## Constraints

- Use ONLY standard Roblox Luau APIs. No third-party libraries.
- Do NOT invent Roblox services, classes, or events. If unsure, say "verify in the Creator Documentation."
- Label all tuning values: `-- [TUNING]: value`
- Max ~100 lines per response unless explicitly asked. Split into follow-ups.
- End every response with a **Next Step** for Studio testing.
