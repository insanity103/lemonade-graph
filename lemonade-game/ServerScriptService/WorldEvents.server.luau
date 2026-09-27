--// WorldEvents  (runs the timed zone events in Config.WorldEventConfig)
-- One event at a time: a server-wide warning, then WorldEventConfig.DURATION of bonus tokens in
-- its zone (SwordDropSystem.payTokens reads TokenRules.KillMultiplier), glowing enemies and/or
-- champions worth more. Studio / admin: set workspace attribute WorldEventForce = "<id>" to start
-- one now (no warning); "stop" ends the running one.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local WorldEventConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WorldEventConfig"))
local NOTIFY = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Notify")

local ENEMY_TAG = "Enemy"

local current = nil -- the running event's config
local touched = {} -- [BasePart] = { color, material } to put back when it ends
local runId = 0

local function announce(text: string, style: string?)
	for _, player in Players:GetPlayers() do
		NOTIFY:FireClient(player, text, style or "great")
	end
end

local function remember(part: BasePart)
	if not touched[part] then touched[part] = { color = part.Color, material = part.Material } end
end

local function inZone(model: Instance, zone: string): boolean
	return model:GetAttribute("Zone") == zone
end

-- The zone's own enemies glow (Frost Moon): torso and head turn Neon while it lasts.
local function applyGlow(model: Instance)
	if not current or not current.glow or not inZone(model, current.zone) then return end
	if not current.glow[model:GetAttribute("Archetype")] then return end
	for _, name in ipairs({ "Torso", "Head" }) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			remember(part)
			part.Material = Enum.Material.Neon
		end
	end
end

local function makeChampion(model: Model, spec)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	model:SetAttribute("EventTokenMult", spec.tokenMult)
	model:SetAttribute("EventTitle", spec.title)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			remember(part)
			part.Color = spec.color
			if part.Name == "Torso" or part.Name == "Head" then part.Material = Enum.Material.Neon end
		end
	end
	humanoid.MaxHealth *= spec.healthMult
	humanoid.Health = humanoid.MaxHealth
	if spec.announceKill then
		humanoid.Died:Once(function()
			local tag = humanoid:FindFirstChild("creator")
			local killer = tag and tag:IsA("ObjectValue") and tag.Value
			if killer and killer:IsA("Player") then
				announce(string.format("%s slew the %s!", killer.DisplayName, spec.title), "success")
			end
		end)
	end
	return true
end

local function pickChampions(spec)
	local pool = {}
	for _, model in ipairs(CollectionService:GetTagged(ENEMY_TAG)) do
		if model:IsA("Model") and inZone(model, current.zone) and model:GetAttribute("Boss") ~= true then
			table.insert(pool, model)
		end
	end
	local made = 0
	while made < spec.count and #pool > 0 do
		local model = table.remove(pool, math.random(1, #pool))
		if makeChampion(model, spec) then made += 1 end
	end
	return made
end

local function stop()
	if not current then return end
	local ended = current
	current = nil
	runId += 1
	for part, was in pairs(touched) do
		if part.Parent then
			part.Color = was.color
			part.Material = was.material
		end
	end
	touched = {}
	for _, model in ipairs(CollectionService:GetTagged(ENEMY_TAG)) do
		model:SetAttribute("EventTokenMult", nil)
		model:SetAttribute("EventTitle", nil)
	end
	for _, attr in ipairs({ "WorldEvent", "WorldEventZone", "WorldEventMult", "WorldEventEnds" }) do
		Workspace:SetAttribute(attr, nil)
	end
	announce(string.format("The %s has ended.", ended.name), "info")
end

local function start(event, warn: boolean)
	stop()
	runId += 1
	local myRun = runId
	if warn then
		announce(event.warn, "great")
		task.wait(WorldEventConfig.WARNING)
		if runId ~= myRun then return end -- forced or stopped meanwhile
	end
	current = event
	Workspace:SetAttribute("WorldEvent", event.id)
	Workspace:SetAttribute("WorldEventZone", event.zone)
	Workspace:SetAttribute("WorldEventMult", event.tokenMult)
	Workspace:SetAttribute("WorldEventEnds", Workspace:GetServerTimeNow() + WorldEventConfig.DURATION)
	for _, model in ipairs(CollectionService:GetTagged(ENEMY_TAG)) do applyGlow(model) end
	if event.champions then pickChampions(event.champions) end
	announce(event.start, "great")
	print(string.format("[WorldEvents] %s started in %s (x%d tokens)", event.name, event.zone, event.tokenMult))
	task.delay(WorldEventConfig.DURATION, function()
		if runId == myRun then stop() end
	end)
end

-- An enemy that respawns mid-event in the zone glows too.
CollectionService:GetInstanceAddedSignal(ENEMY_TAG):Connect(function(model)
	task.defer(applyGlow, model)
end)

-- Only zones that have enemies in this place (map mode) can host an event.
local function eligible()
	local zones = {}
	for _, model in ipairs(CollectionService:GetTagged(ENEMY_TAG)) do
		local zone = model:GetAttribute("Zone")
		if typeof(zone) == "string" then zones[zone] = true end
	end
	local list = {}
	for _, e in ipairs(WorldEventConfig.Events) do
		if zones[e.zone] then table.insert(list, e) end
	end
	return list
end

Workspace:GetAttributeChangedSignal("WorldEventForce"):Connect(function()
	local want = Workspace:GetAttribute("WorldEventForce")
	if want == nil then return end
	Workspace:SetAttribute("WorldEventForce", nil)
	if want == "stop" then stop() return end
	local event = WorldEventConfig.ById[want]
	if event then task.spawn(start, event, false) end
end)

task.spawn(function()
	task.wait(WorldEventConfig.FIRST_DELAY)
	local last = nil
	while true do
		local list = eligible()
		if #list > 0 and not current then
			local event
			repeat event = list[math.random(1, #list)] until event ~= last or #list == 1
			last = event
			start(event, true)
			task.wait(WorldEventConfig.DURATION)
		end
		local lo, hi = WorldEventConfig.INTERVAL[1], WorldEventConfig.INTERVAL[2]
		task.wait(lo + math.random() * (hi - lo))
	end
end)

print(string.format("[WorldEvents] %d events; first in %d min, then every %d-%d min", #WorldEventConfig.Events,
	WorldEventConfig.FIRST_DELAY // 60, WorldEventConfig.INTERVAL[1] // 60, WorldEventConfig.INTERVAL[2] // 60))
