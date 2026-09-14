-- ServerScriptService. Simple collision for batched visual meshes.
-- Terrain chunks are solid convex-ish islands; foliage/text stay non-collidable.
local Workspace = game:GetService("Workspace")
local data = require(script.Parent:WaitForChild("CollisionLayout"))
local map = Workspace:WaitForChild("FivefoldSanctuary", 30)
assert(map and map:GetAttribute("MapRedesignVersion") == 1, "Import and version the map first")
assert(not map:FindFirstChild("Collision"), "Collision already installed")
for _, p in ipairs(map:GetDescendants()) do
	if p:IsA("BasePart") then
		p.Anchored, p.CanTouch = true, false
		local ground = string.match(p.Name, "^Terrain_") ~= nil
		p.CanCollide, p.CanQuery = ground, ground
	end
end
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "Collision", map
local function v(p) return Vector3.new(p[1], p[2], p[3]) end
local function solid(name, size, frame)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, frame
	p.Transparency, p.Anchored = 1, true
	p.CanCollide, p.CanQuery, p.CanTouch = true, true, false
	p.Parent = folder
	return p
end
local hub = solid("HubFloor", Vector3.new(4, 360, 360),
	CFrame.new(0, 4, 0) * CFrame.Angles(0, 0, math.pi / 2))
hub.Shape = Enum.PartType.Cylinder -- [TUNING]: 360-stud diameter, top at Y=6
local fountain = solid("Fountain", Vector3.new(3, 30, 30),
	CFrame.new(0, 7.5, 0) * CFrame.Angles(0, 0, math.pi / 2))
fountain.Shape = Enum.PartType.Cylinder
for _, box in ipairs(data.Boxes) do
	solid(box.Group .. "_" .. box.Name, v(box.Size), CFrame.new(v(box.Position)) * CFrame.Angles(0, box.Yaw, 0))
end
for _, deck in ipairs(data.Roads) do
	local a, b = v(deck.A), v(deck.B)
	local frame = CFrame.lookAt((a + b) / 2, b)
	frame = frame * CFrame.new(0, -deck.Thickness / 2, 0)
	solid(deck.Group .. "_" .. deck.Name, Vector3.new(deck.Width, deck.Thickness, (b - a).Magnitude), frame)
end
map:SetAttribute("CollisionReady", true)
