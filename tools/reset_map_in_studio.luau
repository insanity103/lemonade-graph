-- Run the entire file in Studio's Command Bar while Play is stopped, AFTER Rojo sync.
-- Save a copy of the place first: clearing terrain removes its voxel data.
-- Old map objects are archived in ServerStorage; game scripts and player data remain.
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Stop Play before resetting the saved map")
local layout = game:GetService("ServerScriptService"):FindFirstChild("WorldLayout")
assert(layout and string.find(layout.Source, "WorldLayout.BLANK_SLATE = true", 1, true),
	"Sync the updated project with Rojo first so the old map cannot regenerate")
assert(not string.find(layout.Source, "terrain.Decoration = false", 1, true),
	"Sync the corrected WorldLayout first; the previous version contains an invalid property write")

local history = game:GetService("ChangeHistoryService")
history:SetWaypoint("Before blank map reset")
local backup = Instance.new("Folder")
backup.Name = "MapBeforeReset_" .. tostring(os.time())
backup.Parent = game:GetService("ServerStorage")
local moved = 0
for _, child in ipairs(workspace:GetChildren()) do
	if child ~= workspace.Terrain and not child:IsA("Camera") then
		if child:IsA("BasePart") or child:IsA("Model") or child:IsA("Folder") then
			child.Parent = backup
			moved += 1
		end
	end
end
workspace.Terrain:Clear()
-- Terrain.Decoration cannot be assigned by Luau, including the Command Bar.
-- The synced project sets it to false; alternatively uncheck it in Properties.
local plate = Instance.new("Part")
plate.Name = "Baseplate"
plate.Anchored = true
plate.Size = Vector3.new(512, 20, 512) -- [TUNING] Standard blank building area.
plate.Position = Vector3.new(0, -10, 0)
plate.Material = Enum.Material.Plastic
plate.BrickColor = BrickColor.new("Medium stone grey")
plate.TopSurface = Enum.SurfaceType.Studs
plate.BottomSurface = Enum.SurfaceType.Inlet
plate.Parent = workspace
local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Anchored = true
spawn.Size = Vector3.new(12, 1, 12)
spawn.Position = Vector3.new(0, 0.5, 0)
spawn.Neutral = true
spawn.Duration = 0
spawn.Parent = workspace
history:SetWaypoint("Blank map reset")
assert(workspace.Terrain:CountCells() == 0, "Terrain was not fully cleared")
print("Blank map ready. Archived " .. moved .. " map roots in " .. backup:GetFullName())
