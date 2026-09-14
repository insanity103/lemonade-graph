# Roblox Error Reference

Comprehensive error → cause → fix lookup. Organized by category. Written for AI agents as a diagnostic reference.

---

## Luau Errors

### `'attempt to index nil with X'`
- **Root cause**: Variable is `nil`. Tried to access a field on it (e.g., `nil.Name`).
- **Fix**: Add `WaitForChild` if it's a descendant not yet loaded, or add a nil guard: `if obj then ... end`.

### `'attempt to perform arithmetic (add/sub/mul/div) on nil'`
- **Root cause**: A value used in arithmetic is nil. Often data from DataStore or a property that hasn't loaded.
- **Fix**: Ensure data is loaded before use. Default: `local value = data or 0`.

### `'X is not a valid member of Y'`
- **Root cause**: Accessed a property or child that doesn't exist. Misspelled name, wrong parent, or object destroyed.
- **Fix**: Check spelling in Explorer. Use `FindFirstChild` instead of direct indexing. Verify the object hasn't been `:Destroy()`ed.

### `'Maximum event re-entrancy depth exceeded'`
- **Root cause**: An event handler triggers the same event recursively (e.g., setting a `.Changed` property inside `.Changed`).
- **Fix**: Add a debounce flag: `if debounce then return end; debounce = true; ...; debounce = false`.

### `'Stack overflow'`
- **Root cause**: Infinite recursion — function calls itself with no base case.
- **Fix**: Add a base case / termination condition. Add a depth counter and bail at a max.

### `'attempt to call a nil value'`
- **Root cause**: Tried to call something that isn't a function. Wrong `require()` path, function not defined, or module returned nil.
- **Fix**: Verify the `require()` path returns a valid module. Check the module actually returns a function. Print the value before calling.

### `'Expected X got Y'` (type errors)
- **Root cause**: Wrong argument type passed to an API. E.g., `:WaitForChild(123)` instead of `:WaitForChild("Name")`.
- **Fix**: Validate arguments before the call. Convert types if needed (`tostring`, `tonumber`).

### `'String expected, got nil'`
- **Root cause**: A nil value was passed where a string is required. Common with `Instance.Name = nil` or `string.find(nil, ...)`.
- **Fix**: Provide a default: `local name = input or "default"`.

### `'Cannot resume non-suspended coroutine'`
- **Root cause**: Tried to `coroutine.resume` a coroutine that is already running or dead.
- **Fix**: Check `coroutine.status(co)` before resuming. Only resume if status is `"suspended"`.

### `'Code exceeded allowed execution time'`
- **Root cause**: Infinite loop or extremely long computation without yielding.
- **Fix**: Add `task.wait()` inside the loop. For heavy computation, yield periodically: `if tick() - last > 0.03 then task.wait(); last = tick() end`.

### `'invalid argument #1 to X (Y expected, got Z)'`
- **Root cause**: Wrong type passed to a built-in function (string, table, math library).
- **Fix**: Check the function signature. Validate/cast the argument before passing.

---

## Roblox API Errors

### `'Cannot load the AnimationData'`
- **Root cause**: Animation asset is not owned by the game or the uploading user. Roblox requires the animation to be owned by the group/game owner.
- **Fix**: Re-upload the animation under the correct account or group that owns the game.

### `'Humanoid is not a valid member of Model'`
- **Root cause**: Character model hasn't fully loaded yet. Humanoid is added after the character is parented.
- **Fix**: Use `character:WaitForChild("Humanoid")` inside a `CharacterAdded` handler.

### `'DataStore: Request was throttled'`
- **Root cause**: Exceeded DataStore rate limits (60 + 20 × n requests per player per minute).
- **Fix**: Implement a request queue. Add `task.wait()` between requests. Cache reads in memory.

### `'DataStore: 403: Cannot write to DataStore'`
- **Root cause**: API Services access is disabled for the place.
- **Fix**: Game Settings → Security → Enable "Allow Studio Access to API Services". In live games, ensure the place is published.

### `'PathfindingService: ComputeAsync failed'`
- **Root cause**: Pathfinding could not compute a path. Start or goal position is unreachable (inside a wall, too high, etc.).
- **Fix**: Validate start/end positions are on navigable terrain. Check the returned path's `.Status` property.

### `'MarketplaceService: UserOwnsGamePassAsync failed'`
- **Root cause**: Invalid GamePass ID, or the pass was deleted.
- **Fix**: Verify the GamePass ID is correct and the pass is active. Wrap in `pcall`.

### `'TeleportService: Teleport failed'`
- **Root cause**: Target place ID is invalid, not in the same universe, or the player is already teleporting.
- **Fix**: Verify place ID is in the same game universe. Check player isn't mid-teleport. Wrap in `pcall`.

### `'BadgeService: AwardBadge failed'`
- **Root cause**: Badge is not enabled, player doesn't own the game, or badge isn't associated with the game.
- **Fix**: Enable the badge on the Roblox website. Verify the badge ID. Check `BadgeService:AwardBadge` returns success.

### `'Sound.SoundId is not a valid asset ID'`
- **Root cause**: Wrong asset ID format. Should be `rbxassetid://123456` or just the numeric ID.
- **Fix**: Use the numeric asset ID. Ensure the sound asset exists and is not moderated.

### `'TweenService: invalid property X'`
- **Root cause**: Property doesn't exist on the target instance, or it can't be tweened (read-only).
- **Fix**: Check the class reference for valid tweenable properties. Common mistake: tweening `Text` instead of `TextTransparency`.

### `'Workspace:WaitForChild timed out'`
- **Root cause**: Object never appeared in Workspace. Could be a server-only object not replicating, or a typo.
- **Fix**: Verify the object exists on the expected side (client vs. server). Check exact name spelling.

### `'Debris service failed to add item'`
- **Root cause**: Passed a non-Instance or invalid lifetime to `Debris:AddItem`.
- **Fix**: Ensure first argument is an Instance. Second argument must be a positive number.

---

## Network Errors

### `'RemoteEvent "X" not found'`
- **Root cause**: Client or server is looking for a RemoteEvent at the wrong path.
- **Fix**: Place RemoteEvents in `ReplicatedStorage`. Use `WaitForChild` on the client. Verify the name matches exactly.

### `'OnServerEvent can only be connected on the server'`
- **Root cause**: A LocalScript tried to connect to `OnServerEvent`.
- **Fix**: Move the `OnServerEvent` connection to a Script (server-side). LocalScript uses `OnClientEvent`.

### `'OnClientEvent can only be connected on the client'`
- **Root cause**: A Script (server) tried to connect to `OnClientEvent`.
- **Fix**: Move the `OnClientEvent` connection to a LocalScript. Server uses `OnServerEvent`.

### `'FireClient: Player argument is required'`
- **Root cause**: Called `RemoteEvent:FireClient()` without the player argument.
- **Fix**: `RemoteEvent:FireClient(player, ...)` — first argument must be the target Player.

### `'Requested module errored during load'`
- **Root cause**: The ModuleScript being `require()`d has a syntax error or runtime error at the top level.
- **Fix**: Open the ModuleScript and check for errors. Test it in isolation. Common: missing `return` statement.

### `'RemoteFunction: InvokeServer timeout'`
- **Root cause**: Server-side `OnInvoke` callback never returned (yielded forever or errored).
- **Fix**: Ensure the server callback returns a value. Wrap server logic in `pcall`. Add a timeout fallback.

### `'DataStore: GetAsync failed: HTTP 500'`
- **Root cause**: Roblox internal server error. Not a user code issue.
- **Fix**: Implement retry with exponential backoff. If persistent, check Roblox status page.
