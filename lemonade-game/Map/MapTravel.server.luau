-- Script | ServerScriptService.MapTravel | Map project only: hub spawn point, waypoint discovery,
-- waystone travel and Return to Hub. Stays idle when Workspace.LemonadeMap is absent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local MapMarkers = require(script.Parent:WaitForChild("MapMarkers"))
local CombatUtil = require(script.Parent:WaitForChild("CombatUtil"))

if not MapMarkers.isPresent() then
	warn("[MapTravel] Workspace.LemonadeMap not found; spawn point and travel stay idle")
	return
end

local HUB_WAYPOINT = "HubSpawn"
local TRAVEL_COOLDOWN = 3 -- [TUNING] seconds between teleports per player
local COMBAT_LOCKOUT = 6 -- [TUNING] seconds after losing health before travel is allowed
local ENEMY_THREAT_RADIUS = 30 -- [TUNING] a living enemy this close counts as combat
local WAYSTONE_USE_RANGE = 16 -- server-side check that waystone travel starts at a waystone
local REQUEST_INTERVAL = 0.25 -- ignore remote spam faster than this
local DISCOVERY_INTERVAL = 0.5
local ARRIVAL_LIFT = Vector3.new(0, 3.5, 0) -- markers sit on the floor; the root stands above it

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local travelRemote = remotes:FindFirstChild("TravelAction")
if not travelRemote then
	travelRemote = Instance.new("RemoteEvent")
	travelRemote.Name = "TravelAction"
	travelRemote.Parent = remotes
end

local waypoints = MapMarkers.waypoints()
local waypointById = {}
for _, waypoint in ipairs(waypoints) do
	waypointById[waypoint.Id] = waypoint
end
if not waypointById[HUB_WAYPOINT] then
	warn("[MapTravel] Waypoint HubSpawn missing; Return to Hub stays idle")
end
local waystones = MapMarkers.waystones()
local spawnLocation = MapMarkers.playerSpawn()

local lastHurtAt = {} -- [player] = os.clock() of the latest health loss
local lastTravelAt = {}
local lastRequestAt = {}

-- ── Discovery ───────────────────────────────────────────────────────────────
local function discoveredSet(player: Player)
	local set = { [HUB_WAYPOINT] = true }
	local raw = player:GetAttribute("DiscoveredWaypoints")
	if typeof(raw) == "string" then
		for id in string.gmatch(raw, "[^,]+") do
			set[id] = true
		end
	end
	return set
end

local function discoveredList(player: Player)
	local set, list = discoveredSet(player), {}
	for _, waypoint in ipairs(waypoints) do
		if set[waypoint.Id] then
			table.insert(list, waypoint.Id)
		end
	end
	return list
end

local function discover(player: Player, id: string)
	-- Writing before PlayerDataService applies the save would be overwritten, so wait for it.
	if player:GetAttribute("DataLoaded") ~= true or not waypointById[id] then return end
	if discoveredSet(player)[id] then return end
	local raw = player:GetAttribute("DiscoveredWaypoints")
	raw = if typeof(raw) == "string" then raw else ""
	player:SetAttribute("DiscoveredWaypoints", if raw == "" then id else raw .. "," .. id)
	travelRemote:FireClient(player, "Discovered", id)
end

task.spawn(function()
	while true do
		task.wait(DISCOVERY_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and player:GetAttribute("DataLoaded") == true then
				local known = discoveredSet(player)
				for _, waypoint in ipairs(waypoints) do
					if not known[waypoint.Id] then
						local offset = root.Position - waypoint.CFrame.Position
						if math.abs(offset.Y) < 16 and Vector3.new(offset.X, 0, offset.Z).Magnitude <= waypoint.DiscoverRadius then
							discover(player, waypoint.Id)
						end
					end
				end
			end
		end
	end
end)

-- ── Combat restriction ──────────────────────────────────────────────────────
-- Closest living enemy to a position, and its distance (nil when none are alive).
local function closestLivingEnemy(position: Vector3): (Model?, number?)
	local best, bestDistance = nil, math.huge
	for _, enemy in ipairs(CollectionService:GetTagged(CombatUtil.ENEMY_TAG)) do
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		local enemyRoot = enemy:IsA("Model") and enemy.PrimaryPart
		if humanoid and humanoid.Health > 0 and enemyRoot then
			local distance = (enemyRoot.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = enemy, distance
			end
		end
	end
	return best, if best then bestDistance else nil
end

-- Decides whether `player` may teleport right now. Returns (allowed, reason shown when denied).
-- Available: lastHurtAt[player], COMBAT_LOCKOUT, ENEMY_THREAT_RADIUS, closestLivingEnemy(root.Position).
local function canLeaveCombat(player: Player, root: BasePart): (boolean, string?)
	-- TODO(human)
	return true, nil
end

-- ── Travel ──────────────────────────────────────────────────────────────────
local function nearWaystone(root: BasePart): boolean
	for _, stone in ipairs(waystones) do
		if (stone.Anchor.Position - root.Position).Magnitude <= WAYSTONE_USE_RANGE then
			return true
		end
	end
	return false
end

local function travel(player: Player, destinationId: any)
	if player:GetAttribute("DataLoaded") ~= true or typeof(destinationId) ~= "string" then return end
	local destination = waypointById[destinationId]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not destination or not humanoid or humanoid.Health <= 0 or not root then return end

	local function deny(reason: string)
		travelRemote:FireClient(player, "Denied", reason)
	end
	-- Return to Hub works from anywhere; every other destination starts at a waystone.
	if destinationId ~= HUB_WAYPOINT then
		if not discoveredSet(player)[destinationId] then
			return deny("You have not found that waystone yet.")
		end
		if not nearWaystone(root) then
			return deny("Stand beside a waystone to travel there.")
		end
	end
	local now = os.clock()
	if now - (lastTravelAt[player] or -math.huge) < TRAVEL_COOLDOWN then
		return deny("The waystones are still humming. Try again in a moment.")
	end
	local allowed, reason = canLeaveCombat(player, root)
	if not allowed then
		return deny(reason or "You cannot travel during a fight.")
	end

	lastTravelAt[player] = now
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(destination.CFrame + ARRIVAL_LIFT)
	travelRemote:FireClient(player, "Arrived", destinationId)
end

travelRemote.OnServerEvent:Connect(function(player, action, destinationId)
	local now = os.clock()
	if now - (lastRequestAt[player] or -math.huge) < REQUEST_INTERVAL then return end
	lastRequestAt[player] = now
	if action == "Travel" then
		travel(player, destinationId)
	end
end)

for _, stone in ipairs(waystones) do
	local waypoint = waypointById[stone.WaypointId]
	if waypoint then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TravelPrompt"
		prompt.ActionText = "Travel"
		prompt.ObjectText = waypoint.DisplayName .. " Waystone"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = stone.Anchor
		prompt.Triggered:Connect(function(player)
			discover(player, waypoint.Id)
			travelRemote:FireClient(player, "Open", waypoint.Id, discoveredList(player))
		end)
	else
		warn(string.format("[MapTravel] Waystone %s names unknown waypoint %s", stone.Model:GetFullName(), stone.WaypointId))
	end
end

-- ── Spawning and damage tracking ────────────────────────────────────────────
local function watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth then
			lastHurtAt[player] = os.clock()
		end
		lastHealth = health
	end)
end

local function onPlayer(player: Player)
	if spawnLocation then
		player.RespawnLocation = spawnLocation
		-- A character that loaded before this script ran spawned at the place's own SpawnLocation.
		local existing = player.Character
		if existing then
			existing:PivotTo(spawnLocation.CFrame + ARRIVAL_LIFT)
		end
	end
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	lastHurtAt[player], lastTravelAt[player], lastRequestAt[player] = nil, nil, nil
end)

print(string.format("[MapTravel] %d waypoints, %d waystones, spawn %s", #waypoints, #waystones,
	spawnLocation and "set" or "missing"))
