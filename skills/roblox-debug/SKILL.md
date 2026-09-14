---
name: roblox-debug
description: >-
  Debug and troubleshoot Roblox scripts in Studio. Use when a script is broken,
  throwing errors, behaving unexpectedly, or the user says it's not working.
  Covers Output log analysis, common Luau errors, Roblox API pitfalls,
  client/server issues, and DataStore troubleshooting. Triggers on Roblox error,
  script not working, debug Roblox, fix Luau error, Output log, or broken
  Roblox script.
---

# Roblox Debug Skill

Dedicated troubleshooting and debugging guide for Roblox development. Use this skill whenever a script is broken, throwing errors, behaving unexpectedly, or the user reports "it's not working."

---

## Debugging Protocol

**Strict. Never skip steps. Follow in order.**

### Step 1 — Do NOT rewrite the script

Resist the urge to rewrite from scratch. Ask for the Output log first.

### Step 2 — Gather context

Ask the user for:
- **Exact error text** (verbatim from Output window)
- **What they were doing** when the error occurred (playtest, studio run, live server, etc.)
- **Current script version** (paste the full script or the relevant section)

### Step 3 — Add print() at every decision branch

Instrument the script with `print()` statements at:
- Top of every function
- Every `if`/`elseif`/`else` branch
- Before and after any API call
- Inside every event callback
- Before every `return`

Example:
```lua
local function loadData(player)
    print("[DEBUG] loadData called for", player.Name)
    local key = "Player_" .. player.UserId
    print("[DEBUG] DataStore key:", key)
    local success, data = pcall(function()
        return DataStore:GetAsync(key)
    end)
    print("[DEBUG] GetAsync success:", success, "data:", data)
    if not success then
        warn("[DEBUG] DataStore failed:", data)
        return nil
    end
    return data
end
```

### Step 4 — Have user re-run and paste output

User runs the game again. Ask them to copy the **entire Output window** contents and paste it.

### Step 5 — Identify the exact line where execution stops

Read the Output log top to bottom. Find:
1. The last `[DEBUG]` print that fired — execution made it this far.
2. The error or warn that follows — this is the failure point.
3. Any `[DEBUG]` prints that did NOT fire — execution never reached them.

### Step 6 — Fix ONLY that line or immediate cause

Do not refactor. Do not "improve" anything else. Change only what is needed to fix the identified failure. Common fixes:
- Add `WaitForChild` if something is nil
- Add `pcall` if an API call errors
- Add a nil check if a variable is unexpectedly nil
- Fix a path if an object is in the wrong location

### Step 7 — Repeat until playtest passes

After the fix, have the user playtest again. If new errors appear, repeat from Step 3. Only remove debug prints after everything works.

---

## Common Error Categories

### Script Type Errors

| Error | Diagnosis |
|-------|-----------|
| `'X is not a valid member of Y'` | Misspelled name, or object is in wrong parent. Check Explorer hierarchy. |
| Client-only API called from server | `LocalPlayer`, `Mouse`, `UserInputService` only work in `LocalScript`. Move code or use `RemoteEvent`. |
| `WaitForChild` never returns / yields forever | Object does not exist. Check spelling, check it's actually in the hierarchy, check it's replicated (server objects don't replicate to client). |

### Nil Errors

| Error | Diagnosis |
|-------|-----------|
| `'attempt to index nil with X'` | `WaitForChild` failed, wrong path, or object doesn't exist yet. |
| `Player is nil` | Event fired before player loaded. Use `Players.PlayerAdded` callback, not `Players:GetPlayers()`. |
| `Character is nil` | Player hasn't spawned yet. Use `player.CharacterAdded:Wait()` or `player.Character or player.CharacterAdded:Wait()`. |
| `Humanoid is nil` | Character loaded but Humanoid not yet parented. `WaitForChild("Humanoid")` inside `CharacterAdded`. |

### Event Errors

| Error | Diagnosis |
|-------|-----------|
| Event never fires | Wrong event name, wrong parent, or wrong script type (server vs. client). |
| Fires too many times | Connection not disconnected. Store the connection and call `:Disconnect()`. |
| `.Touched` fires for wrong parts | Missing filter. Check `hit.Parent` for a Humanoid before acting. |
| Event fires in wrong order | Yielding in an event handler blocks subsequent handlers. Use `task.spawn`. |

### DataStore Errors

| Error | Diagnosis |
|-------|-----------|
| `'403: Cannot write to DataStore'` | API Services not enabled. Game Settings → Security → Enable Studio Access to API Services. |
| `'502: temporarily unavailable'` | Roblox DataStore outage. Implement retry with exponential backoff. |
| `'Request was throttled'` | Too many requests (60+20*n per player per minute). Queue requests, add delays. |
| Data not saving | Missing `BindToClose` or `Players.PlayerRemoving` not connected. |
| Data wiped on join | Migration bug — new schema can't read old format. Write migration code. |

### Client/Server Errors

| Error | Diagnosis |
|-------|-----------|
| `RemoteEvent not found` | Wrong path. Must be in `ReplicatedStorage` (or `StarterPlayerScripts` context). |
| Server never receives `OnServerEvent` | Client firing wrong RemoteEvent, or path mismatch. Print the RemoteEvent reference on both sides. |
| Client sees stale state | Server changed state but didn't `FireClient` to update the client. |
| `FireAllClients` not working | RemoteEvent is in wrong location or was destroyed. |

### Performance Errors

| Error | Diagnosis |
|-------|-----------|
| Script timeout (infinite loop) | `while true do` without `task.wait()`. Add `task.wait()` inside the loop. |
| Memory leak / rising memory | Event connections not cleaned up. Disconnect on `Destroying` or when no longer needed. |
| Low FPS | Too many parts (use MeshParts, streaming), too much work in `Heartbeat`, or `RunService` loop doing heavy computation every frame. |

---

## Quick Checklist

Before declaring a script "fixed," verify every item:

```
- [ ] Correct script type? (ServerScript vs LocalScript vs ModuleScript)
- [ ] All WaitForChild calls correct? (right names, right parents)
- [ ] All connections cleaned up? (Disconnect on leave/destroy)
- [ ] DataStore calls wrapped in pcall?
- [ ] task.wait() in all loops?
- [ ] RemoteEvent paths match on client AND server?
- [ ] Print statements tracing execution flow?
```

---

## How to Use This Skill

1. When a user reports a Roblox issue, start with the **Debugging Protocol**.
2. When reading error messages, consult the **Common Error Categories** above for diagnosis.
3. For specific error strings not listed here, consult `references/error-reference.md` for the full lookup table.
4. Never rewrite from scratch unless the protocol has been followed and the root cause is confirmed.
