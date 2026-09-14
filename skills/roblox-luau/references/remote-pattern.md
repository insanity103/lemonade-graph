# RemoteEvent / RemoteFunction Patterns

## Naming Convention

Use PascalCase verb-noun names: `RequestPurchase`, `FireWeapon`, `EquipTool`, `SyncInventory`.

Prefix server→client broadcasts: `NotifyPlayer`, `UpdateHUD`.

## Creating Remotes

### In Explorer (preferred for visibility)

1. Insert a `Folder` into `ReplicatedStorage` named `Remotes`.
2. Add `RemoteEvent` / `RemoteFunction` children inside it.
3. Scripts reference them via `WaitForChild` chains.

### Programmatically (for dynamic remotes)

```lua
-- Server Script (e.g., ServerScriptService/RemoteSetup)
local RS = game:GetService("ReplicatedStorage")
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = RS

Instance.new("RemoteEvent", remotes).Name = "RequestPurchase"
Instance.new("RemoteEvent", remotes).Name = "FireWeapon"
Instance.new("RemoteEvent", remotes).Name = "NotifyPlayer"
-- Avoid RemoteFunction when possible (see caution below)
```

---

## Client-Side Pattern

```lua
-- Client (LocalScript, e.g., StarterPlayerScripts)
local RS = game:GetService("ReplicatedStorage")
local remotes = RS:WaitForChild("Remotes", 10)
if not remotes then warn("Remotes folder missing") return end

local requestPurchase = remotes:WaitForChild("RequestPurchase", 10)
local notifyPlayer   = remotes:WaitForChild("NotifyPlayer", 10)

-- Fire to server (one-way)
requestPurchase:FireServer("Sword", 1) -- itemId, quantity

-- Listen for server response / broadcast
notifyPlayer.OnClientEvent:Connect(function(message: string)
    -- update UI, show toast, etc.
    print(message)
end)

-- Invoke server (two-way, blocking — prefer FireServer + callback)
-- local remoteFunc = remotes:WaitForChild("GetInventory")
-- local inventory = remoteFunc:InvokeServer()
```

---

## Server-Side Pattern with Full Validation Pipeline

```lua
-- Server Script (ServerScriptService/PurchaseHandler)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local remotes = RS:WaitForChild("Remotes")

local requestPurchase = remotes:WaitForChild("RequestPurchase")
local notifyPlayer    = remotes:WaitForChild("NotifyPlayer")

-------------------------------------------------
-- Validation checklist (every handler must do ALL of these):
--   1. Type-check every parameter
--   2. Range-check numerics
--   3. State-check permissions (alive, not in cooldown zone, etc.)
--   4. Rate-limit the caller
-------------------------------------------------

-- Rate limiter: per-player debounce table
local rateLimits: {[Player]: {[string]: boolean}} = {}

local function isRateLimited(player: Player, action: string, cooldown: number): boolean
    local bucket = rateLimits[player]
    if not bucket then
        bucket = {}
        rateLimits[player] = bucket
    end
    if bucket[action] then
        return true
    end
    bucket[action] = true
    task.delay(cooldown, function() -- [TUNING] cooldown seconds
        bucket[action] = nil
    end)
    return false
end

-- Clean up on player leave
Players.PlayerRemoving:Connect(function(player)
    rateLimits[player] = nil
end)

-- Item catalog (server-authoritative)
local CATALOG = {
    Sword  = { price = 100, maxQty = 5 },
    Shield = { price = 150, maxQty = 3 },
    Potion = { price =  50, maxQty = 10 },
}

-- Player data helper (stub — wire to your DataStore module)
local function getCash(player: Player): number
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local cash = ls:FindFirstChild("Cash")
        if cash then return cash.Value end
    end
    return 0
end
local function addCash(player: Player, amount: number)
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local cash = ls:FindFirstChild("Cash")
        if cash then cash.Value += amount end
    end
end

-- Main handler
requestPurchase.OnServerEvent:Connect(function(player: Player, itemId: string, quantity: number)
    -- 1. Type check
    if typeof(itemId) ~= "string" then return end
    if typeof(quantity) ~= "number" then return end

    -- 2. Range / value check
    quantity = math.floor(quantity)
    if quantity < 1 or quantity > 10 then return end -- [TUNING] max purchase qty
    local item = CATALOG[itemId]
    if not item then return end
    if quantity > item.maxQty then return end

    -- 3. State check
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- 4. Rate limit
    if isRateLimited(player, "Purchase", 0.5) then return end -- [TUNING] 0.5s cooldown

    -- Deduct cash
    local totalCost = item.price * quantity
    if getCash(player) < totalCost then
        notifyPlayer:FireClient(player, "Not enough cash!")
        return
    end
    addCash(player, -totalCost)

    -- Grant item (example: clone from ServerStorage)
    local SS = game:GetService("ServerStorage")
    local toolTemplate = SS:FindFirstChild(itemId)
    if toolTemplate and toolTemplate:IsA("Tool") then
        for _ = 1, quantity do
            local tool = toolTemplate:Clone()
            tool.Parent = player.Backpack
        end
    end

    notifyPlayer:FireClient(player, `Purchased {quantity}x {itemId}!`)
end)
```

---

## RemoteFunction Caution

| RemoteEvent | RemoteFunction |
|---|---|
| Fire-and-forget or callback pattern | Blocks the calling thread (yields until server responds) |
| Client never hangs if server is slow | Client freezes if server errors or is slow |
| Preferred for most gameplay | Use only for low-frequency queries (e.g., initial inventory load) |

**Pattern to replace RemoteFunction:** Client fires a `RequestX` RemoteEvent; server processes and fires a `RespondX` RemoteEvent back to that specific client.

---

## Anti-Exploit Checklist

- **Never trust client position.** Server should raycast / sanity-check positions.
- **Never trust client health.** All `TakeDamage` calls happen on the server.
- **Never trust client inventory.** Server owns the authoritative inventory.
- **Never trust client-reported damage.** Server computes damage from weapon stats.
- **Rate-limit every remote.** A compromised client can fire thousands of events per second.
- **Validate ownership.** Before equipping a tool, verify the player actually owns it server-side.
- **Log suspicious activity.** Flag players who send malformed data for further review.

---

## Full Working Example: Client Requests Item Purchase

### Client (LocalScript in StarterPlayerScripts)

```lua
local RS = game:GetService("ReplicatedStorage")
local remotes = RS:WaitForChild("Remotes", 10)
if not remotes then return end

local requestPurchase = remotes:WaitForChild("RequestPurchase")
local notifyPlayer    = remotes:WaitForChild("NotifyPlayer")

-- UI button wired to this function
local function buyItem(itemId: string)
    requestPurchase:FireServer(itemId, 1)
end

notifyPlayer.OnClientEvent:Connect(function(msg: string)
    -- Display to player (toast, label, etc.)
    print("[Shop]", msg)
end)

-- Example: buy a sword
buyItem("Sword")
```

### Server (Script in ServerScriptService)

The full server script is the `PurchaseHandler` shown above in the Server-Side Pattern section. It covers all four validation steps, rate limiting, cash deduction, and tool granting.
