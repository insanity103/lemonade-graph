-- Script | ServerScriptService.VaultSystem | The Vaultkeeper: store boss swords in the profile's
-- vault so they survive rebirths and server hops, and take them back out later.
-- The vault holds save entries (never Tools); withdrawing rebuilds the Tool with
-- BossSwordFactory.rebuild, exactly as a saved backpack sword is restored on join.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SaveConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SaveConfig"))
local SwordValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwordValue"))
local WorldLayout = require(script.Parent:WaitForChild("WorldLayout"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local BossSwordFactory = require(script.Parent:WaitForChild("BossSwordFactory"))
local actors = require(script.Parent:WaitForChild("GameplayActors"))

if WorldLayout.BLANK_SLATE then return end

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local VAULT_ACTION = remotes:WaitForChild("VaultAction")
local NOTIFY = remotes:WaitForChild("Notify")

local INTERACT_RANGE = 16 -- [TUNING] studs from the keeper for any vault action
local REQUEST_INTERVAL = 0.25
local SAVE_COOLDOWN = 8 -- [TUNING] seconds between DataStore writes triggered by vault edits

local keeper = nil
local lastRequestAt = {}
local lastSaveAt = {}

-- ── State sent to the client ─────────────────────────────────────────────────
local function describe(entry)
	local attrs = entry.attrs or {}
	return {
		name = entry.name,
		rarity = attrs.Rarity or "Common",
		prefixes = attrs.Prefixes or "",
		damageMult = attrs.DamageMult or 1,
		tier = attrs.BossTier or 1,
		rating = SwordValue.rateAttrs(attrs),
	}
end

-- ── Wealth: the sword economy's score ────────────────────────────────────────
-- Wealth = sum of ratings for every relic sword carried or vaulted. Derived,
-- never saved; recomputed on vault changes and on a slow tick so drops, buys and sells
-- show up without every system having to call in.
local WEALTH_TICK = 4 -- [TUNING] seconds

local function computeWealth(player): number
	local total = 0
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				total += SwordValue.rateTool(tool)
			end
		end
	end
	local vault = PlayerDataService.GetVault(player)
	for _, entry in ipairs(vault or {}) do
		total += SwordValue.rateAttrs(entry.attrs)
	end
	return total
end

-- Wealth is a player attribute, not a leaderstat: the Roblox leaderboard keeps showing
-- Level and Rebirths; menus and the vault read player:GetAttribute("Wealth").
local function refreshWealth(player)
	local value = computeWealth(player)
	if player:GetAttribute("Wealth") ~= value then
		player:SetAttribute("Wealth", value)
	end
end

task.spawn(function()
	while true do
		task.wait(WEALTH_TICK)
		for _, player in ipairs(Players:GetPlayers()) do
			if player:GetAttribute("DataLoaded") == true then
				refreshWealth(player)
			end
		end
	end
end)

local function sendState(player)
	local vault = PlayerDataService.GetVault(player)
	if not vault then return end
	local stored = {}
	for i, entry in ipairs(vault) do
		local row = describe(entry)
		row.index = i
		stored[i] = row
	end
	local carried = {}
	local equippedTool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("BossDrop") == true then
					local row = describe(PlayerDataService.SerializeTool(tool, tool == equippedTool))
					row.toolName = tool.Name
					row.equipped = tool == equippedTool
					table.insert(carried, row)
				end
			end
		end
	end
	VAULT_ACTION:FireClient(player, "State", stored, carried, SaveConfig.VAULT_CAPACITY, computeWealth(player))
end

local function saveSoon(player)
	PlayerDataService.MarkDirty(player)
	local now = os.clock()
	if now - (lastSaveAt[player] or -math.huge) < SAVE_COOLDOWN then return end
	lastSaveAt[player] = now
	task.spawn(PlayerDataService.Save, player)
end

-- ── Validation ───────────────────────────────────────────────────────────────
local function nearKeeper(player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return keeper ~= nil and root ~= nil and (root.Position - keeper.PrimaryPart.Position).Magnitude <= INTERACT_RANGE
end

local function findCarriedTool(player, toolName)
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

-- ── Actions ──────────────────────────────────────────────────────────────────
local function deposit(player, toolName)
	local vault = PlayerDataService.GetVault(player)
	if not vault then return end
	if #vault >= SaveConfig.VAULT_CAPACITY then
		NOTIFY:FireClient(player, string.format("The vault is full (%d swords).", SaveConfig.VAULT_CAPACITY), "error")
		return
	end
	local tool = findCarriedTool(player, toolName)
	if not tool then
		NOTIFY:FireClient(player, "Only relic swords can be stored.", "error")
		return
	end
	if tool.Parent == player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:UnequipTools() end
	end
	table.insert(vault, PlayerDataService.SerializeTool(tool, false))
	tool:Destroy()
	NOTIFY:FireClient(player, string.format("%s stored with the Vaultkeeper.", toolName), "success")
	saveSoon(player)
	refreshWealth(player)
	sendState(player)
end

local function withdraw(player, index)
	local vault = PlayerDataService.GetVault(player)
	if not vault or typeof(index) ~= "number" then return end
	index = math.floor(index)
	local entry = vault[index]
	if not entry then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	local tool = BossSwordFactory.rebuild(entry)
	if not tool then
		NOTIFY:FireClient(player, "That sword could not be restored.", "error")
		return
	end
	table.remove(vault, index)
	tool.Parent = backpack
	NOTIFY:FireClient(player, string.format("%s returned to your backpack.", tool.Name), "success")
	saveSoon(player)
	refreshWealth(player)
	sendState(player)
end

VAULT_ACTION.OnServerEvent:Connect(function(player, action, arg)
	local now = os.clock()
	if now - (lastRequestAt[player] or -math.huge) < REQUEST_INTERVAL then return end
	lastRequestAt[player] = now
	if player:GetAttribute("DataLoaded") ~= true or not nearKeeper(player) then return end
	if action == "Open" then
		sendState(player)
	elseif action == "Deposit" and typeof(arg) == "string" then
		deposit(player, arg)
	elseif action == "Withdraw" then
		withdraw(player, arg)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequestAt[player], lastSaveAt[player] = nil, nil
end)

-- ── The keeper ───────────────────────────────────────────────────────────────
if not WorldLayout.HUB.VaultPosition then
	warn("[VaultSystem] No Vaultkeeper position; the vault stays idle")
	return
end
keeper = actors.create("Vaultkeeper", WorldLayout.HUB.VaultPosition, Color3.fromRGB(56, 92, 70),
	{ facing = WorldLayout.HUB.VaultCFrame, subtitle = "Stores your relic swords", outfit = "Vaultkeeper" })
actors.prompt(keeper, "Open Vault", "Vaultkeeper").Triggered:Connect(function(player)
	if player:GetAttribute("DataLoaded") ~= true then return end
	sendState(player)
	VAULT_ACTION:FireClient(player, "Open")
end)
print(string.format("[VaultSystem] Vaultkeeper ready (%d slots per player)", SaveConfig.VAULT_CAPACITY))
