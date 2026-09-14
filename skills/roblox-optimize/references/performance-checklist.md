# Roblox Performance Audit Checklist

Detailed audit guide for AI agents. Each check includes what to look for, how to
measure it, and a specific fix pattern. Run through every item systematically.

---

## Workspace (15 checks)

### W-1: Total Part Count < 5 000

**What to look for:** Total `BasePart` count in `Workspace` (including streamed
descendants).

**How to measure:** Count all `BasePart` instances. In Studio, check Game Explorer →
Workspace → part count. Programmatically:

```lua
local count = 0
for _, desc in workspace:GetDescendants() do
    if desc:IsA("BasePart") then
        count += 1
    end
end
print("Part count:", count)
```

**Fix:** Union static decorative geometry. Replace complex unions with `MeshPart`
assets. Remove invisible / unused parts. Enable `StreamingEnabled` if above threshold.

---

### W-2: StreamingEnabled Enabled

**What to look for:** `Workspace.StreamingEnabled` is `true`.

**How to measure:** `print(workspace.StreamingEnabled)` — should be `true`.

**Fix:**

```lua
-- In Workspace properties or a server Script:
workspace.StreamingEnabled = true
workspace.StreamingMinRadius = 128
workspace.StreamingTargetRadius = 512
```

Adjust radii based on gameplay camera distance. Test that critical gameplay objects
(streamed) are within the target radius during normal play.

---

### W-3: All Static Parts Anchored

**What to look for:** Every part that does not need physics simulation has
`Anchored = true`.

**How to measure:**

```lua
for _, desc in workspace:GetDescendants() do
    if desc:IsA("BasePart") and not desc.Anchored then
        -- Check if it's actually static (not a physics prop, not a character)
        warn("Unanchored static part:", desc:GetFullName())
    end
end
```

**Fix:** Set `Anchored = true`. For parts that must be unanchored (physics props),
ensure they are in a `PhysicsService` collision group that minimizes broadphase
cost.

---

### W-4: No Unnecessary CanCollide on Decorative Parts

**What to look for:** Decorative parts (foliage, trim, visual-only geometry) that
have `CanCollide = true`.

**How to measure:** Tag decorative parts with a `CollectionService` tag
(e.g. `"Decorative"`) and check:

```lua
for _, part in CollectionService:GetTagged("Decorative") do
    if part:IsA("BasePart") and part.CanCollide then
        warn("Decorative part has CanCollide:", part:GetFullName())
    end
end
```

**Fix:** Set `CanCollide = false` on all purely visual parts. Use
`CollisionGroups` via `PhysicsService` for systematic exclusion.

---

### W-5: Textures at Appropriate Resolution

**What to look for:** `Texture`, `Decal`, or `SurfaceAppearance` assets with
resolution higher than necessary for their visual size at typical camera distance.

**How to measure:** Visual inspection at gameplay camera distance. A floor tile
seen from 50+ studs rarely needs 1024×1024.

**Fix:** Reduce source texture resolution. Use texture atlases for small textures
(collections of icons, tilesets). Prefer `SurfaceAppearance` with compressed
textures for terrain and large surfaces.

---

### W-6: Mesh Parts for Complex Geometry

**What to look for:** Groups of parts forming a single visual object that could be
a single `MeshPart`.

**How to measure:** Count child `BasePart` instances of visual-only models. If a
static model has > 10 parts that form one visual shape, it's a candidate.

**Fix:** Model in external tool (Blender), export as `.fbx`, import as `MeshPart`.
Use `AssetService:CreateMeshPartAsync()` for runtime creation. Union in Studio
as a fallback (mesh parts perform better than unions).

---

### W-7: No Temporary / Test Objects in Workspace

**What to look for:** Parts named "Part", "test", or with default properties left
from development.

**How to measure:** Search for parts with default names or colors (e.g.,
`BrickColor.new("Medium stone grey")` + `Part` name + no children + not tagged).

**Fix:** Remove all test objects. Add a pre-publish check script:

```lua
-- In a Plugin or CI script:
for _, desc in workspace:GetDescendants() do
    if desc:IsA("BasePart") and desc.Name == "Part" and not desc:HasTag("Intentional") then
        warn("Possible leftover test part:", desc:GetFullName())
    end
end
```

---

### W-8: ParticleEmitter Count Reasonable

**What to look for:** High `MaxParticles` values or many active emitters in the
same area.

**How to measure:** Count all `ParticleEmitter` instances. Sum their
`MaxParticles`. Each active emitter has a CPU cost.

**Fix:** Reduce `MaxParticles` to the minimum visually acceptable. Use `Rate = 0`
and `EmitCount` for burst effects instead of continuous emission. Pool emitter
instances.

---

### W-9: No Excessive Light Overlap

**What to look for:** Multiple `PointLight` or `SpotLight` instances illuminating
the same area, all with `Shadows = true`.

**How to measure:** Count lights with `Shadows = true`. Visual inspection for
overdraw in shadow-heavy areas.

**Fix:** Disable `Shadows` on lights that don't produce visible shadow differences.
Reduce the number of real-time shadow-casting lights. Prefer baked lightmaps for
static lighting.

---

### W-10: Transparency-1 Parts Have CanCollide = False

**What to look for:** Parts with `Transparency = 1` (invisible) but
`CanCollide = true` that aren't intentional collision barriers.

**How to measure:**

```lua
for _, desc in workspace:GetDescendants() do
    if desc:IsA("BasePart") and desc.Transparency == 1 and desc.CanCollide then
        warn("Invisible colliding part:", desc:GetFullName())
    end
end
```

**Fix:** If intentional (invisible wall), leave it. If not, set
`CanCollide = false`. For intentional invisible barriers, consider using
`CollisionGroups` to limit what collides with them.

---

### W-11: CollisionGroups Configured

**What to look for:** All interactable physics objects are in appropriate collision
groups via `PhysicsService`.

**How to measure:** Check `PhysicsService:GetCollisionGroupName()` for each part's
`CollisionGroup` property. Default group interacts with everything.

**Fix:** Register groups (e.g., `"Characters"`, `"Projectiles"`, `"Decorative"`,
 `"NPCs"`) and set group-to-group collisions explicitly:

```lua
PhysicsService:RegisterCollisionGroup("Decorative")
PhysicsService:CollisionGroupSetCollidable("Decorative", "Decorative", false)
PhysicsService:CollisionGroupSetCollidable("Decorative", "Characters", false)
```

---

### W-12: BillboardGui Update Frequency Reasonable

**What to look for:** `BillboardGui` or `SurfaceGui` instances with
`AlwaysOnTop = true` or updating every frame.

**How to measure:** Count active BillboardGuis. Check if their `Adornee` properties
change frequently.

**Fix:** Set `AlwaysOnTop = false` where possible. Update adornee text / images
only on change, not every frame. Use `MaxDistance` to auto-hide at distance.

---

### W-13: Terrain Cells Optimized

**What to look for:** Excessive terrain resolution in areas that don't need detail.

**How to measure:** Check terrain `Region3` cell counts in high-detail areas.

**Fix:** Use lower terrain resolution in areas far from player paths. Trim unused
terrain regions.

---

### W-14: No Nested Models Without Purpose

**What to look for:** Deeply nested `Model` → `Model` → `Model` chains that add
no organizational value but increase traversal cost.

**How to measure:** `:GetDescendants()` depth > 6 for workspace objects.

**Fix:** Flatten unnecessary nesting. Keep models 2–3 levels deep max for gameplay
objects.

---

### W-15: SpawnLocation Count Reasonable

**What to look for:** Multiple `SpawnLocation` instances all active simultaneously
in the same area.

**How to measure:** Count `SpawnLocation` instances in workspace.

**Fix:** Use one `SpawnLocation` per team/spawn area. Disable `Enabled` on spawn
locations not in use. Use `Teams` to assign spawn locations.

---

## Scripts (15 checks)

### S-1: No `while true` Without `task.wait()`

**What to look for:** `while true do` loops that don't yield inside the body.

**How to measure:** Search codebase for `while true do` and `while true\n` patterns.
Verify each has `task.wait()` or another yield (`:Wait()`, `:WaitForChild()`) inside.

**Fix:**

```lua
-- BEFORE (freezes thread):
while true do
    updateSomething()
end

-- AFTER:
while true do
    updateSomething()
    task.wait(1)  -- yield for 1 second
end

-- BETTER: use events instead
someEvent.Event:Connect(updateSomething)
```

---

### S-2: All Event Connections Stored

**What to look for:** `:Connect()` calls where the return value is discarded.

**How to measure:** Search for `:Connect(` and verify the result is assigned to a
variable or inserted into a connections table.

**Fix:**

```lua
-- BEFORE:
part.Touched:Connect(function() ... end)

-- AFTER:
local connections = {}
table.insert(connections, part.Touched:Connect(function() ... end))

-- On cleanup:
for _, conn in connections do
    conn:Disconnect()
end
table.clear(connections)
```

---

### S-3: DataStore in pcall + Retry

**What to look for:** `DataStoreService` calls (`:GetAsync`, `:SetAsync`,
`:UpdateAsync`) not wrapped in error handling.

**How to measure:** Search for `DataStore` usage. Every call should be inside
`pcall` or `xpcall` with retry logic.

**Fix:**

```lua
local function dataStoreRetry(func, maxRetries)
    maxRetries = maxRetries or 3
    for attempt = 1, maxRetries do
        local success, result = pcall(func)
        if success then
            return result
        end
        warn("DataStore attempt", attempt, "failed:", result)
        task.wait(2 ^ attempt)  -- exponential backoff
    end
    error("DataStore failed after " .. maxRetries .. " attempts")
end
```

---

### S-4: No Polling Where Events Work

**What to look for:** `while` loops that check a condition periodically when an
event or signal exists.

**How to measure:** Identify loops that read properties repeatedly. Check if
`:GetPropertyChangedSignal()` or `.Changed` exists for that property.

**Fix:**

```lua
-- BEFORE:
while true do
    if part.Parent == nil then break end
    task.wait(1)
end

-- AFTER:
part.AncestryChanged:Connect(function(_, parent)
    if parent == nil then
        -- cleanup
    end
end)
```

---

### S-5: Heartbeat Minimal Work

**What to look for:** `RunService.Heartbeat:Connect()` doing expensive operations
per frame.

**How to measure:** Profile with Microprofiler (View → Microprofiler). Look for
Lua code taking > 2ms per frame in the heartbeat handler.

**Fix:** Move non-essential logic to `task.delay` timers. Batch per-frame work.
Use `RunService.Heartbeat:Connect()` only for time-critical simulation.

---

### S-6: Pre-Computed Values Outside Loops

**What to look for:** Constant expressions or function calls inside loop bodies
that could be computed once before the loop.

**How to measure:** Code review. Look for `#table`, `math.*`, or constant
arithmetic inside `for` loops.

**Fix:**

```lua
-- BEFORE:
for i = 1, #enemies do
    local dist = (enemies[i].Position - Vector3.new(0, 0, 0)).Magnitude
end

-- AFTER:
local origin = Vector3.new(0, 0, 0)
for i = 1, #enemies do
    local dist = (enemies[i].Position - origin).Magnitude
end
```

---

### S-7: `table.clear` for Reusable Tables

**What to look for:** Tables that are frequently emptied and refilled (e.g.,
temporary buffers, per-frame lists).

**How to measure:** Search for `t = {}` inside functions called frequently
(per frame, per event).

**Fix:**

```lua
-- BEFORE:
local function getVisibleEnemies()
    local result = {}  -- new table every call → GC pressure
    for _, enemy in enemies do
        if isVisible(enemy) then table.insert(result, enemy) end
    end
    return result
end

-- AFTER:
local result = {}  -- allocated once
local function getVisibleEnemies()
    table.clear(result)
    for _, enemy in enemies do
        if isVisible(enemy) then result[#result + 1] = enemy end
    end
    return result
end
```

---

### S-8: No String Concatenation in Tight Loops

**What to look for:** `..` operator used to build strings inside loops with many
iterations.

**How to measure:** Search for `..` inside `for` loops. String concatenation
creates a new string object each time.

**Fix:**

```lua
-- BEFORE:
local s = ""
for i = 1, 1000 do
    s = s .. tostring(i) .. ","  -- O(n²)
end

-- AFTER:
local parts = {}
for i = 1, 1000 do
    parts[i] = tostring(i)
end
local s = table.concat(parts, ",")  -- O(n)
```

---

### S-9: RaycastParams Reused

**What to look for:** `RaycastParams.new()` called inside loops or per-frame
callbacks.

**How to measure:** Search for `RaycastParams.new()` inside functions that run
frequently.

**Fix:**

```lua
-- BEFORE:
local function checkLineOfSight(origin, direction)
    local params = RaycastParams.new()  -- new object every call
    params.FilterDescendantsInstances = {character}
    return workspace:Raycast(origin, direction, params)
end

-- AFTER:
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function checkLineOfSight(origin, direction, character)
    rayParams.FilterDescendantsInstances = {character}
    return workspace:Raycast(origin, direction, rayParams)
end
```

---

### S-10: ModuleScripts for Shared Code

**What to look for:** Duplicated logic across multiple `Script` / `LocalScript`
instances.

**How to measure:** Search for repeated function bodies or utility code copied
between files.

**Fix:** Extract shared logic into `ModuleScript` instances in
`ReplicatedStorage` (client-shared) or `ServerScriptService` (server-only).
Luau caches module returns — code runs once.

---

### S-11: `task.spawn` Not `spawn`

**What to look for:** Deprecated `spawn()` and `delay()` globals.

**How to measure:** Search for `spawn(` and `delay(` (the bare globals, not
`task.spawn`).

**Fix:**

```lua
-- BEFORE:
spawn(function() ... end)
delay(5, function() ... end)

-- AFTER:
task.spawn(function() ... end)
task.delay(5, function() ... end)
```

---

### S-12: No Nested High-Iteration Loops

**What to look for:** Nested `for` loops where total iterations = product of
ranges, exceeding ~10 000.

**How to measure:** Identify loop nests. If `O(n²)` or worse, estimate total
iterations. Profile with Microprofiler.

**Fix:** Use spatial partitioning (`Region3` queries, grids, quadtrees). Cache
results. Offload to `OverlapParams` / `GetPartBoundsInRadius` instead of
manual iteration.

---

### S-13: RemoteEvents Batched

**What to look for:** Multiple `:FireClient()` / `:FireServer()` calls per frame
for the same logical update.

**How to measure:** Search for `:FireClient` and `:FireServer`. Count occurrences
in per-frame code paths.

**Fix:**

```lua
-- BEFORE (multiple fires per frame):
for _, player in players do
    remote:FireClient(player, "health", data.health)
    remote:FireClient(player, "mana", data.mana)
    remote:FireClient(player, "stamina", data.stamina)
end

-- AFTER (batched):
for _, player in players do
    remote:FireClient(player, {
        health = data.health,
        mana = data.mana,
        stamina = data.stamina,
    })
end
```

---

### S-14: Client-Side Prediction

**What to look for:** Player movement that waits for server round-trip before
responding to input.

**How to measure:** Test input responsiveness. If there's visible latency between
keypress and character movement, prediction is missing.

**Fix:** Move character on the client immediately. Server validates and sends
correction. Client smoothly interpolates to corrected position.

---

### S-15: Debounce on Rapid-Fire Events

**What to look for:** Event handlers (`.Touched`, remote events) that can fire
rapidly without throttling.

**How to measure:** Check `.Touched` handlers and remote event handlers for
debounce guards.

**Fix:**

```lua
local debounce = {}
local function onTouched(hit)
    local player = game.Players:GetPlayerFromCharacter(hit.Parent)
    if not player or debounce[player] then return end
    debounce[player] = true

    -- process touch
    task.delay(1, function()
        debounce[player] = nil
    end)
end
```

---

## Memory (10 checks)

### M-1: No Growing Tables Without Cleanup

**What to look for:** Tables that accumulate entries (append, insert) but never
have entries removed or the table cleared.

**How to measure:** Monitor table sizes over time. Add a debug counter:

```lua
print("table size:", #myTable, tick())
```

If it grows unboundedly, it's a leak.

**Fix:** Add cleanup logic. Remove entries when their lifecycle ends. Use
`table.clear()` when the table's purpose is fulfilled.

---

### M-2: Destroyed Instances Disconnected

**What to look for:** Event connections that reference instances which may be
`:Destroy()`ed, leaving dangling connections that fire on garbage.

**How to measure:** After destroying an instance, check if connections to it
are still active. Use `:Disconnect()` before or immediately after `:Destroy()`.

**Fix:**

```lua
-- BEFORE:
local conn = part.Touched:Connect(handler)
-- later...
part:Destroy()  -- connection may linger

-- AFTER:
local conn = part.Touched:Connect(handler)
-- later...
conn:Disconnect()
part:Destroy()
```

Or use the `Connections` pattern from S-2 to bulk-disconnect on character removal.

---

### M-3: Instance Pooling for Frequent Create/Destroy

**What to look for:** Frequent `Instance.new()` + `:Destroy()` cycles for the
same instance type (projectiles, VFX, damage numbers).

**How to measure:** Count `Instance.new` calls per second in Microprofiler. If
> 100/sec for a single type, consider pooling.

**Fix:**

```lua
local pool = {}

local function acquire(template: Instance, parent: Instance): Instance
    local obj = table.remove(pool)
    if not obj then
        obj = template:Clone()
    end
    obj.Parent = parent
    return obj
end

local function release(obj: Instance)
    obj.Parent = nil
    table.insert(pool, obj)
end
```

---

### M-4: No Circular References Preventing GC

**What to look for:** Tables or closures that reference each other, preventing
garbage collection when both should be freed.

**How to measure:** Use `gcinfo()` or Studio's Memory profiler. Watch for
instances that should be collected but aren't.

**Fix:** Break circular references explicitly:

```lua
-- When done:
objA.refToB = nil
objB.refToA = nil
```

Prefer weak references where applicable:
`setmetatable(cache, { __mode = "v" })` for value-weak tables.

---

### M-5: Module Cache Not Stale

**What to look for:** ModuleScripts that mutate state after first `require()`,
causing unexpected behavior or stale data for new consumers.

**How to measure:** Verify that each module's returned API is stateless or
that consumers get fresh data via function calls, not cached table values.

**Fix:** Expose getter functions instead of direct table values:

```lua
-- BEFORE (stale):
local Module = { maxHealth = 100 }
return Module

-- AFTER (always fresh):
local Module = {}
local maxHealth = 100
function Module.getMaxHealth() return maxHealth end
function Module.setMaxHealth(v) maxHealth = v end
return Module
```

---

### M-6: No Event Listeners on Temporary UI

**What to look for:** `GuiButton.Activated` or `Changed` connections on UI
elements that get destroyed when navigating away.

**How to measure:** Check that UI navigation (switching screens, closing menus)
disconnects all event listeners on the old screen.

**Fix:** Use a connections-per-screen pattern:

```lua
local screenConnections = {}

local function openShop()
    -- Disconnect previous screen
    for _, conn in screenConnections do conn:Disconnect() end
    table.clear(screenConnections)

    -- Build shop UI...
    table.insert(screenConnections, buyButton.Activated:Connect(onBuy))
end
```

---

### M-7: Cleanup on Player Leave

**What to look for:** Player-specific data (tables, connections, cached instances)
that persists after the player disconnects.

**How to measure:** Monitor memory after player joins and leaves. Use
`Players.PlayerRemoving` to verify cleanup runs.

**Fix:**

```lua
local playerData = {}

Players.PlayerRemoving:Connect(function(player)
    local data = playerData[player]
    if data then
        for _, conn in data.connections do
            conn:Disconnect()
        end
        if data.cachedModel then
            data.cachedModel:Destroy()
        end
    end
    playerData[player] = nil
end)
```

---

### M-8: No Large String Concatenation in Memory

**What to look for:** Large strings built via `..` that accumulate intermediate
strings in memory before GC.

**How to measure:** Monitor `gcinfo()` during string-heavy operations.

**Fix:** Use `table.concat` for any string building > ~50 concatenations.

---

### M-9: Weak Tables for Caches

**What to look for:** Caches (e.g., model caches, computed result caches) that
grow indefinitely because references are held strongly.

**How to measure:** Monitor cache table size over time.

**Fix:** Use weak-value metatables so cached entries can be GC'd when no other
reference exists:

```lua
local cache = setmetatable({}, { __mode = "v" })
```

---

### M-10: No Duplicate ReplicatedStorage Assets

**What to look for:** The same asset (mesh, texture, sound) cloned into multiple
locations instead of referenced from a single source.

**How to measure:** Search `ReplicatedStorage` for duplicate names or identical
`MeshId` / `TextureId` values.

**Fix:** Store each unique asset once in `ReplicatedStorage`. Reference it by
`FindFirstChild` or path; clone only at runtime when needed.
