-- Script | ServerScriptService.ReforgeSystem | The Reforge anvil: pay gold to re-roll a relic
-- sword's modifiers. Price = rarity base x current roll quality (SwordValue.rerollCost), so a
-- bare Rare is a cheap gamble and a well-rolled Legendary costs real gold.
-- Opened from the on-screen menu (no world prompt); usable anywhere.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SwordValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwordValue"))
local BossSwordFactory = require(script.Parent:WaitForChild("BossSwordFactory"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local REFORGE = remotes:WaitForChild("ReforgeAction")
local NOTIFY = remotes:WaitForChild("Notify")

local REQUEST_INTERVAL = 0.3
local SAVE_COOLDOWN = 8

local lastRequestAt = {}
local lastSaveAt = {}

local function describe(tool, equipped)
	return {
		toolName = tool.Name,
		name = tool.Name,
		rarity = tool:GetAttribute("Rarity") or "Common",
		prefixes = tool:GetAttribute("Prefixes") or "",
		blessed = tool:GetAttribute("ExtraSlot") == true,
		rating = SwordValue.rateTool(tool),
		cost = SwordValue.rerollCostForTool(tool),
		equipped = equipped == true,
	}
end

local function goldOf(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Gold")
end

local function sendState(player, highlight)
	local rows = {}
	local equippedTool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true then
					table.insert(rows, describe(tool, tool == equippedTool))
				end
			end
		end
	end
	table.sort(rows, function(a, b) return a.rating > b.rating end)
	local gold = goldOf(player)
	REFORGE:FireClient(player, "State", rows, gold and gold.Value or 0, highlight)
end

local function findRelic(player, toolName)
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if container then
			local tool = container:FindFirstChild(toolName)
			if tool and tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true then
				return tool
			end
		end
	end
	return nil
end

local function reroll(player, toolName)
	local tool = findRelic(player, toolName)
	if not tool then
		NOTIFY:FireClient(player, "That sword is not on you.", "error")
		return
	end
	local cost = SwordValue.rerollCostForTool(tool)
	local gold = goldOf(player)
	if not gold or gold.Value < cost then
		NOTIFY:FireClient(player, string.format("Reforging %s costs %d gold.", tool.Name, cost), "error")
		return
	end
	local before = SwordValue.rateTool(tool)
	local oldName = tool.Name
	local mods, newName = BossSwordFactory.reroll(tool, player:GetAttribute("RebirthBlessedBonus") or 0)
	if not mods then
		NOTIFY:FireClient(player, "That sword cannot be reforged.", "error")
		return
	end
	gold.Value -= cost
	local after = SwordValue.rateTool(tool)
	local rolled = {}
	for _, mod in ipairs(mods) do
		table.insert(rolled, { name = mod.name, category = mod.category, tier = mod.tier, desc = mod.desc })
	end
	-- The client plays the case-opening reel with this, then re-lists the swords.
	REFORGE:FireClient(player, "Result", {
		toolName = newName, oldName = oldName, rarity = tool:GetAttribute("Rarity") or "Common",
		mods = rolled, blessed = tool:GetAttribute("ExtraSlot") == true,
		before = before, after = after, cost = cost,
	})
	print(string.format("[ReforgeSystem] %s reforged %s -> %s for %d gold", player.Name, oldName, newName, cost))
	PlayerDataService.MarkDirty(player)
	local now = os.clock()
	if now - (lastSaveAt[player] or -math.huge) >= SAVE_COOLDOWN then
		lastSaveAt[player] = now
		task.spawn(PlayerDataService.Save, player)
	end
	sendState(player, newName)
end

REFORGE.OnServerEvent:Connect(function(player, action, arg)
	local now = os.clock()
	if now - (lastRequestAt[player] or -math.huge) < REQUEST_INTERVAL then return end
	lastRequestAt[player] = now
	if player:GetAttribute("DataLoaded") ~= true then return end
	if action == "Open" then
		sendState(player)
		REFORGE:FireClient(player, "Open")
	elseif action == "Reroll" and typeof(arg) == "string" then
		reroll(player, arg)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequestAt[player], lastSaveAt[player] = nil, nil
end)

print("[ReforgeSystem] Reforge ready (opened from the menu)")
