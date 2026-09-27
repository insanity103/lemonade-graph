--// CodexSystem  (keeps each player's Codex: kills per enemy, swords ever held, page rewards)
-- Config and the page rules live in ReplicatedStorage.Config.CodexConfig; the client draws the
-- pages from the same saved attributes (CodexKills / CodexSwords / CodexClaims).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CodexConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CodexConfig"))
local CombatUtil = require(ServerScriptService:WaitForChild("CombatUtil"))
local NOTIFY = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Notify")

local CREATOR_TAG_NAME = "creator"

local function ready(player: Player): boolean
	return player.Parent ~= nil and player:GetAttribute("DataLoaded") == true
end

-- The permanent damage the mastered pages give (SwordSystem.calculateDamage reads it). Derived
-- from the saved claims, never saved itself, so a retuned HUNTER_DAMAGE applies to old profiles.
local function refreshDamage(player: Player)
	local claims = CodexConfig.DecodeSet(player:GetAttribute("CodexClaims"))
	local pages = 0
	for _, page in ipairs(CodexConfig.Pages) do
		if claims[page.zone .. ":hunter"] then pages += 1 end
	end
	player:SetAttribute("CodexDamageMult", 1 + CodexConfig.HUNTER_DAMAGE * pages)
end

-- Pays any page reward the player has earned and not been paid yet.
local function settlePage(player: Player, page)
	local kills = CodexConfig.DecodeKills(player:GetAttribute("CodexKills"))
	local found = CodexConfig.DecodeSet(player:GetAttribute("CodexSwords"))
	local claims = CodexConfig.DecodeSet(player:GetAttribute("CodexClaims"))
	local progress = CodexConfig.Progress(page, kills, found)
	local newClaims = {}
	if progress.hunter and not claims[page.zone .. ":hunter"] then
		table.insert(newClaims, page.zone .. ":hunter")
		NOTIFY:FireClient(player, string.format("Codex: %s mastered! +%d%% damage, forever.",
			page.name, math.round(CodexConfig.HUNTER_DAMAGE * 100)), "great")
	end
	if progress.collector and not claims[page.zone .. ":collector"] then
		table.insert(newClaims, page.zone .. ":collector")
		local tokens = CodexConfig.CollectorTokens(page)
		player:SetAttribute("Tokens", (tonumber(player:GetAttribute("Tokens")) or 0) + tokens)
		NOTIFY:FireClient(player, string.format("Codex: every %s sword found! +%d tokens.", page.name, tokens), "great")
	end
	if #newClaims > 0 then
		local list = player:GetAttribute("CodexClaims")
		local joined = table.concat(newClaims, ",")
		player:SetAttribute("CodexClaims", (typeof(list) == "string" and list ~= "") and (list .. "," .. joined) or joined)
		refreshDamage(player)
	end
end

-- ── Kills ────────────────────────────────────────────────────────────────
local function creditKill(player: Player, archetype: string)
	if not ready(player) then return end
	local page = CodexConfig.PageOfArchetype(archetype)
	if not page then return end -- an enemy with no page (unbuilt zone, staging rig)
	local kills = CodexConfig.DecodeKills(player:GetAttribute("CodexKills"))
	local before = kills[archetype] or 0
	kills[archetype] = before + 1
	player:SetAttribute("CodexKills", CodexConfig.EncodeKills(kills))
	for _, e in ipairs(page.enemies) do
		if e[1] == archetype then
			local target = CodexConfig.Mastery(e[3])
			if before == 0 then
				NOTIFY:FireClient(player, string.format("New Codex entry: %s (1/%d)", e[2], target), "success")
			elseif before + 1 == target then
				NOTIFY:FireClient(player, string.format("Codex: %s mastered (%d/%d)", e[2], target, target), "success")
				settlePage(player, page)
			end
		end
	end
end

local connected = setmetatable({}, { __mode = "k" })
local function watchHumanoid(humanoid: Humanoid)
	if connected[humanoid] then return end
	local model = humanoid:FindFirstAncestorOfClass("Model")
	if not model or not CombatUtil.isEnemy(model) then return end
	connected[humanoid] = true
	humanoid.Died:Once(function()
		local tag = humanoid:FindFirstChild(CREATOR_TAG_NAME)
		local killer = tag and tag:IsA("ObjectValue") and tag.Value
		local archetype = model:GetAttribute("Archetype")
		if killer and killer:IsA("Player") and typeof(archetype) == "string" then
			creditKill(killer, archetype)
		end
	end)
end

local function inspect(instance: Instance)
	if instance:IsA("Humanoid") then watchHumanoid(instance) end
	for _, d in instance:GetDescendants() do
		if d:IsA("Humanoid") then watchHumanoid(d) end
	end
end
for _, instance in workspace:GetChildren() do inspect(instance) end
workspace.ChildAdded:Connect(inspect)

-- ── Swords ───────────────────────────────────────────────────────────────
-- Any relic that reaches the player's hands (spin, merchant, trade, a rebuilt save) is found.
local function noteTool(player: Player, tool: Instance)
	if not tool:IsA("Tool") or not ready(player) then return end
	local name = tool:GetAttribute("BaseWeaponName")
	if typeof(name) ~= "string" or name == "" then return end
	local found = CodexConfig.DecodeSet(player:GetAttribute("CodexSwords"))
	if found[name] then return end
	local list = player:GetAttribute("CodexSwords")
	player:SetAttribute("CodexSwords", (typeof(list) == "string" and list ~= "") and (list .. "," .. name) or name)
	for _, page in ipairs(CodexConfig.Pages) do
		for _, s in ipairs(page.swords) do
			if s.name == name then settlePage(player, page) end
		end
	end
end

local function watchContainer(player: Player, container: Instance?)
	if not container then return end
	for _, child in container:GetChildren() do noteTool(player, child) end
	container.ChildAdded:Connect(function(child) noteTool(player, child) end)
end

local function onPlayer(player: Player)
	if not ready(player) then player:GetAttributeChangedSignal("DataLoaded"):Wait() end
	if not player.Parent then return end
	refreshDamage(player)
	watchContainer(player, player:FindFirstChildOfClass("Backpack"))
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then watchContainer(player, child) end
	end)
	if player.Character then watchContainer(player, player.Character) end
	player.CharacterAdded:Connect(function(character) watchContainer(player, character) end)
	for _, page in ipairs(CodexConfig.Pages) do settlePage(player, page) end
end

for _, player in Players:GetPlayers() do task.spawn(onPlayer, player) end
Players.PlayerAdded:Connect(onPlayer)

print(string.format("[CodexSystem] Codex live: %d pages (mastery %d kills, %d for a boss)",
	#CodexConfig.Pages, CodexConfig.MASTERY.minion, CodexConfig.MASTERY.boss))
