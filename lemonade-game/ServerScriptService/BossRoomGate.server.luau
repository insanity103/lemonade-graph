--// BossRoomGate  (level-gated doors on the boss rooms in Workspace/BossRooms)
-- Each room's Door carries a RequiredLevel attribute. Doors are solid for everyone
-- (enemies included) except players at or above that level: every distinct required
-- level gets a door collision group, and each player's character sits in a "tier"
-- group that ignores exactly the doors they qualify for. Server-authoritative, so a
-- client can't talk its way through. A safety loop also moves any under-level player
-- found inside a room back out (covers rebirth resets and getting in some other way).
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ROOMS_FOLDER = Workspace:WaitForChild("BossRooms")
local NOTICE = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("BossDoorNotice")
local EJECT_CHECK_INTERVAL = 0.5

local rooms = {}
for _, model in ipairs(ROOMS_FOLDER:GetChildren()) do
	local door, bounds, exit = model:FindFirstChild("Door"), model:FindFirstChild("Bounds"), model:FindFirstChild("Exit")
	if door and bounds and exit then
		rooms[#rooms + 1] = {
			door = door, bounds = bounds, exit = exit,
			required = door:GetAttribute("RequiredLevel") or 1,
			name = model:GetAttribute("DisplayName") or model.Name,
		}
	end
end

-- distinct required levels, ascending -> rank 1..m
local seen, levels = {}, {}
for _, r in ipairs(rooms) do
	if not seen[r.required] then seen[r.required] = true; levels[#levels + 1] = r.required end
end
table.sort(levels)
local rankOf = {}
for i, lv in ipairs(levels) do rankOf[lv] = i end

local function doorGroup(rank) return "BossDoor" .. rank end
local function tierGroup(tier) return "BossPass" .. tier end
local function register(name)
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end
for rank = 1, #levels do register(doorGroup(rank)) end
for tier = 0, #levels do register(tierGroup(tier)) end
for tier = 0, #levels do
	for rank = 1, #levels do
		-- a tier-t player passes every door ranked <= t
		PhysicsService:CollisionGroupSetCollidable(tierGroup(tier), doorGroup(rank), rank > tier)
	end
end
for _, r in ipairs(rooms) do
	r.door.CollisionGroup = doorGroup(rankOf[r.required])
end

local function getLevel(player)
	local ls = player:FindFirstChild("leaderstats")
	local lv = ls and ls:FindFirstChild("Level")
	return (lv and lv.Value) or player:GetAttribute("Level") or 1
end

local function tierFor(level)
	local tier = 0
	for i, lv in ipairs(levels) do
		if level >= lv then tier = i end
	end
	return tier
end

local playerTier = {}

local function applyTier(player)
	local tier = tierFor(getLevel(player))
	playerTier[player] = tier
	local character = player.Character
	if character then
		local group = tierGroup(tier)
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("BasePart") then d.CollisionGroup = group end
		end
	end
end

local function onCharacter(player, character)
	applyTier(player)
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then d.CollisionGroup = tierGroup(playerTier[player] or 0) end
	end)
end

local function bindPlayer(player)
	player.CharacterAdded:Connect(function(c) onCharacter(player, c) end)
	if player.Character then onCharacter(player, player.Character) end
	player:GetAttributeChangedSignal("Level"):Connect(function() applyTier(player) end)
	task.spawn(function()
		local ls = player:WaitForChild("leaderstats", 30)
		local lv = ls and ls:WaitForChild("Level", 30)
		if lv then
			lv.Changed:Connect(function() applyTier(player) end)
			applyTier(player)
		end
	end)
end

Players.PlayerAdded:Connect(bindPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(bindPlayer, p) end
Players.PlayerRemoving:Connect(function(p) playerTier[p] = nil end)

-- Safety net: under-level players inside a room are moved back outside its door.
local function inside(part, pos)
	local lp = part.CFrame:PointToObjectSpace(pos)
	local h = part.Size / 2
	return math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z
end

task.spawn(function()
	while true do
		task.wait(EJECT_CHECK_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local level = getLevel(player)
				for _, r in ipairs(rooms) do
					if level < r.required and inside(r.bounds, hrp.Position) then
						character:PivotTo(r.exit.CFrame + Vector3.new(0, 3, 0))
						NOTICE:FireClient(player, r.name, r.required)
						break
					end
				end
			end
		end
	end
end)

print(string.format("[BossRoomGate] %d gated rooms online (levels: %s)", #rooms, table.concat(levels, ", ")))
