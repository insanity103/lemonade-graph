---
name: roblox-optimize
description: >
  Optimize Roblox game performance, reduce lag, harden anti-exploit measures,
  and improve script efficiency. Use when a game has low FPS, high ping, memory
  leaks, exploit vulnerabilities, or needs production-readiness review. Triggers
  on Roblox optimization, reduce lag, improve FPS, anti-exploit, memory leak,
  performance review, or slow Roblox game.
---

# Roblox Performance Optimization & Anti-Exploit Hardening

Systematic guide for making Roblox games fast, memory-safe, and exploit-resistant.
Treat every section as an audit surface: read the codebase, measure against each
checklist item, and produce concrete fixes with before/after code.

---

## 1. Performance Optimization

### 1.1 Workspace Optimization

**Part Count Reduction**

- Target < 5 000 active parts (streamed count).
- Union static decorative meshes; prefer `MeshPart` over unions for collision
  performance.
- Use `AssetService:CreateMeshPartAsync()` or pre-authored `.rbxm` meshes.
- Remove or archive any test / placeholder parts left in `Workspace`.

**StreamingEnabled**

- Always enable `Workspace.StreamingEnabled = true` for worlds above ~2 000 parts.
- Set `StreamingMinRadius` and `StreamingTargetRadius` appropriate to gameplay
  sight-lines (typical: min 128, target 512).
- Place persistent gameplay logic in `ServerScriptService` or
  `ReplicatedStorage`, not inside streamed workspace descendants.

**Texture Optimization**

- Compress all textures (PNG-8 where alpha not needed, WebP where supported by
  pipeline).
- Use texture atlases for tilesets and UI icon sheets.
- Cap texture resolution to what the camera distance demands; a floor tile rarely
  needs 1024×1024.
- Prefer `SurfaceAppearance` with packed textures over multiple decal instances.

**Lighting**

- Prefer baked lighting (`Lighting.Technology = ShadowMap` or `Future` with baked
  lightmaps) over fully real-time point lights.
- Limit real-time `SpotLight` / `PointLight` to ≤ 32 active casters.
- Disable `Shadows` on lights that don't contribute visually.
- Use `Lighting.ClockTime` skyboxes instead of real-time sky simulation where
  possible.

**Anchoring & Collision**

- Anchor **every** static part. Unanchored statics trigger continuous physics.
- Set `CanCollide = false` on purely decorative / transparent parts.
- Configure `PhysicsService` CollisionGroups so decorative parts never participate
  in collision broadphase.
- Set `CastShadow = false` on small decorative parts that don't cast visible
  shadows.

### 1.2 Script Optimization

**Heartbeat / Per-Frame Work**

- Move non-time-critical logic out of `RunService.Heartbeat` / `RenderStepped`.
  Use timers (`task.delay`, `task.spawn` with `task.wait`).
- Batch per-frame operations: one loop pass, not N separate connections.
- Always use `dt` (delta time) for movement / interpolation; never assume a fixed
  frame rate.

**Event-Driven Over Polling**

- Replace `while` polling loops with `Changed`, `ChildAdded`, attribute listeners,
  or `CollectionService` tags where possible.
- Use `:GetPropertyChangedSignal()` for single-property watches instead of `.Changed`.

**Memory Hygiene**

- Store **every** connection in a table; `:Disconnect()` all on cleanup.
- Call `:Destroy()` on instances that are no longer needed; nil the reference.
- For tables used as temporary buffers, call `table.clear(t)` instead of `t = {}`
  to avoid GC churn.
- Pre-allocate tables with known size where Luau supports it.

**String Handling**

- Avoid `..` concatenation inside tight loops. Build parts in a table and
  `table.concat` once.
- Prefer `string.format` over repeated `..` for log messages.

**Raycasting**

- Reuse a single `RaycastParams` object; update `.FilterDescendantsInstances` as
  needed rather than constructing a new one every cast.
- Minimize ray count per frame; spatial queries (`Workspace:GetPartBoundsInRadius`)
  can replace many individual rays.

**Module Structure**

- Use `ModuleScript` for shared logic; Luau caches module returns so code runs
  once.
- Keep modules stateless where possible; if stateful, expose a `:Reset()` method.

### 1.3 Network Optimization

**RemoteEvent / RemoteFunction Frequency**

- Batch position updates into a single remote firing at a fixed tick (e.g. 20 Hz)
  instead of per-frame.
- Send **deltas** (only what changed) instead of full state snapshots.
- Use `UnreliableRemoteEvent` for high-frequency, loss-tolerant data (positions,
  cosmetics).

**Data Compression**

- Encode vectors as 3 packed numbers; avoid sending `Vector3` / `CFrame` objects
  directly when bandwidth matters (they serialize to more bytes).
- Bit-pack booleans and small enums into a single number.

**Client-Side Prediction**

- Move the local character on the client immediately (prediction).
- Server validates and corrects; smooth correction with interpolation on the client.
- Never let the client dictate final position — see Anti-Exploit §2.1.

### 1.4 Memory Management

**Connection Cleanup Pattern**

```lua
local connections = {}

local function onCharacterAdded(character)
    -- Clean previous connections
    for _, conn in connections do
        conn:Disconnect()
    end
    table.clear(connections)

    -- Store new connections
    table.insert(connections, character.Humanoid.Died:Connect(function()
        -- handle death
    end))
end
```

**Instance Pooling**

For objects created and destroyed frequently (projectiles, VFX, damage numbers):

```lua
local pool = {}

local function acquire(template, parent)
    local obj = table.remove(pool)
    if not obj then
        obj = template:Clone()
    end
    obj.Parent = parent
    return obj
end

local function release(obj)
    obj.Parent = nil
    table.insert(pool, obj)
end
```

**Attributes vs. Value Objects**

- Prefer `instance:SetAttribute()` over `IntValue` / `StringValue` children.
  Attributes are lighter, replicated automatically, and don't create extra
  instances.

**Garbage Collection**

- `nil` references to destroyed instances promptly.
- `table.clear(t)` for reusable tables; `table.remove` only when order matters.
- Avoid closures in hot paths that capture large upvalues; each closure is a GC
  root.

---

## 2. Anti-Exploit Hardening

### 2.1 Server Authority Checklist

Every one of these **must** happen on the server. The client is untrusted.

| Action | Server-Side? | Notes |
|---|---|---|
| Damage calculation | ✅ | Client never sends damage numbers |
| Currency changes | ✅ | Server increments/decrements; client requests an action |
| Item grants / removals | ✅ | Server validates inventory state |
| Teleportation | ✅ | Client requests; server moves |
| Hit detection | ✅ | Use server-predicted positions, not client-reported |
| Speed / jump power | ✅ | Server sets Humanoid properties; never read from client |
| Purchase completion | ✅ | MarketplaceService.ProcessReceipt callback |

### 2.2 Input Validation

**Type Checking**

```lua
remoteEvent.OnServerEvent:Connect(function(player, actionType, targetId, amount)
    if typeof(actionType) ~= "string" then return end
    if typeof(targetId) ~= "number" then return end
    if typeof(amount) ~= "number" then return end
    if amount ~= amount then return end  -- NaN check
    -- proceed
end)
```

**Range Checking**

- `amount` must be > 0 and ≤ max reasonable value.
- `targetId` must index a valid, existing item.
- Enumerate valid `actionType` strings; reject unknowns.

**Rate Limiting**

```lua
local RATE_LIMIT = 0.2  -- seconds between calls per player
local lastCall = {}

remoteEvent.OnServerEvent:Connect(function(player, ...)
    local now = os.clock()
    if now - (lastCall[player] or 0) < RATE_LIMIT then return end
    lastCall[player] = now
    -- process
end)

-- Clean up on player leave
Players.PlayerRemoving:Connect(function(player)
    lastCall[player] = nil
end)
```

### 2.3 Speed / Teleport Hacks

**Server-Side Position Validation**

```lua
local MAX_SPEED = 50          -- studs/sec, above Humanoid.WalkSpeed
local MAX_TELEPORT_DIST = 200  -- studs, game-dependent
local TICK_INTERVAL = 0.2

-- On each position update from client:
local function validatePosition(player, claimedPos)
    local char = player.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local delta = (claimedPos - root.Position).Magnitude
    local maxDist = MAX_SPEED * TICK_INTERVAL * 2  -- 2x tolerance

    if delta > MAX_TELEPORT_DIST then
        -- Teleport exploit detected
        return false
    elseif delta > maxDist then
        -- Speed exploit: snap back
        root.CFrame = root.CFrame  -- server position, ignore client
        return false    end

    return true
end
```

**Anti-Fly Detection**

```lua
local function isGrounded(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return true end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {character}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), params)
    return result ~= nil
end

-- Check periodically (server-side, e.g. every 1 second):
if not isGrounded(character) and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
    -- Player is airborne but not falling — possible fly hack
end
```

**Anti-Noclip Detection**

```lua
local function hasObstacleBetween(from, to, character)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {character}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local direction = to - from
    local result = workspace:Raycast(from, direction, params)
    return result ~= nil
end

-- If player moved through a wall, the raycast from old to new position
-- should hit the wall. If it doesn't, they clipped through.
```

### 2.4 Economy Protection

- **Never accept client-reported currency amounts.** The server owns the balance;
  the client requests "buy item X" and the server deducts the price.
- **Log every transaction** to a DataStore or external log. Include player ID,
  action, amount, timestamp, and resulting balance.
- **Daily earning caps:** track earnings per day per player; reject actions that
  exceed the cap.
- **Verify item existence:** before granting an item, confirm the item ID exists in
  your game's item registry and the player's state allows the grant (e.g., they're
  in the correct zone, have prerequisites).

---

## 3. Output Format

When delivering an audit, structure findings as:

### Performance Audit Checklist

| # | Area | Check | Status | Evidence | Fix |
|---|---|---|---|---|---|
| 1 | Workspace | Part count < 5000 | ✅ Pass / ❌ Fail | Count: N | Action |
| 2 | Scripts | No `while true` without `task.wait()` | ✅ / ❌ | File:Line | Rewrite |

### Prioritized Code Changes

Each change includes:

- **Priority:** Critical → High → Medium → Low
- **File & line**
- **Before** (current code)
- **After** (optimized code)
- **Expected impact** (FPS gain, memory reduction, attack surface removed)

Critical = crash / exploit vulnerability. High = major perf win. Medium = measurable
improvement. Low = polish / best practice.

---

## 4. Quick Reference: Common Anti-Patterns

| Anti-Pattern | Fix |
|---|---|
| `while true do ... end` (no yield) | Add `task.wait()` or switch to events |
| `spawn()` / `delay()` | Use `task.spawn()` / `task.delay()` |
| Creating RaycastParams every cast | Create once, reuse |
| Client sends damage number | Server calculates from weapon stats |
| `table.insert` in hot loop | Direct index `t[#t+1] = v` or pre-allocate |
| String concatenation in loop | `table.concat` after loop |
| Unanchored static parts | Anchor all non-physics parts |
| `Instance.new` + set Parent last | Set Parent **last** to avoid double-replication |
| No connection cleanup on character death | Store connections, disconnect in `CharacterRemoving` |
| Client teleports itself | Server moves the character via `PivotTo` / `CFrame` |
