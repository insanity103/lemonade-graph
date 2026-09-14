-- ServerScriptService. Install only after the visual map and WorldLayout adapter.
-- This file is intentionally outside the active Rojo tree.
local Workspace = game:GetService("Workspace")
local data = require(script.Parent:WaitForChild("MapAnchors"))
local map = Workspace:WaitForChild("FivefoldSanctuary", 30)
assert(map and map:GetAttribute("MapRedesignVersion") == data.Version, "Import and version the map first")
assert(not Workspace:FindFirstChild("BossRooms"), "Old builder must be disabled before installing anchors")
local function v(p) return Vector3.new(p[1], p[2], p[3]) end
local function part(parent, name, size, frame, collide, query)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, frame
	p.Anchored, p.Transparency = true, 1
	p.CanCollide, p.CanTouch, p.CanQuery = collide, false, query
	p.Parent = parent
	return p
end
local rooms = Instance.new("Folder")
rooms.Name, rooms.Parent = "BossRooms", Workspace
for _, zone in ipairs(data.Zones) do
	local room = Instance.new("Model")
	room.Name, room.Parent = zone.Name, rooms
	room:SetAttribute("DisplayName", zone.DisplayName)
	local frame = CFrame.lookAt(v(zone.Center), v(zone.Approach))
	local floor = part(room, "Floor", Vector3.new(1, 68, 68),
		frame * CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), true, true)
	floor.Shape = Enum.PartType.Cylinder -- [TUNING]: authored 68-stud floor
	room.PrimaryPart = floor
	local door = part(room, "Door", v(zone.DoorSize), frame * CFrame.new(0, 7, -34), true, false)
	door:SetAttribute("RequiredLevel", zone.RequiredLevel)
	door.Color, door.Material, door.Transparency = Color3.fromRGB(180, 218, 228), Enum.Material.ForceField, 0.7
	part(room, "Bounds", v(zone.BoundsSize), frame * CFrame.new(0, 11, 0), false, false)
	part(room, "Exit", Vector3.new(4, 1, 4), CFrame.new(v(zone.Exit)), false, false)
end
local anchors = Instance.new("Folder")
anchors.Name, anchors.Parent = "GameplayAnchors", map
for _, key in ipairs({"QuestGiverPosition", "MerchantPosition", "RebirthPosition", "RebirthPromptPosition"}) do
	part(anchors, key, Vector3.one, CFrame.new(v(data.Hub[key])), false, false)
end
local safe = part(anchors, "SafeHub", Vector3.new(280, data.Hub.SafeRadius * 2, data.Hub.SafeRadius * 2),
	CFrame.new(0, 60, 0) * CFrame.Angles(0, 0, math.pi / 2), false, false)
safe.Shape = Enum.PartType.Cylinder
safe:SetAttribute("Radius", data.Hub.SafeRadius)
safe:SetAttribute("EnemyFree", true) -- Marker only; enforce targeting and damage in the server combat services.
local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation") or Instance.new("SpawnLocation")
spawn.Name, spawn.Parent = "SpawnLocation", Workspace
spawn.Anchored, spawn.Neutral, spawn.Transparency = true, true, 1
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = v(data.Hub.SpawnPosition) - Vector3.new(0, 2.5, 0)
map:SetAttribute("GameplayAnchorsReady", true)
