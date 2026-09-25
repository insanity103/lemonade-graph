-- Script | ServerScriptService.MeshSlots | Map project.
-- Upgrades the Frostbound Glacier's kit pieces from parts to their Blender meshes, once the meshes
-- are in the place.
--
-- tools/map_forge.py builds every kit piece (ice cliffs, firs, rocks, crystals, the temple, the
-- colossus, the frozen fall, the peaks) from SmoothPlastic parts inside a Model tagged MeshSlot, so
-- the zone is whole through Rojo alone. tools/blender_glacier_kit.py models the same pieces as
-- meshes (assets/glacier/<Key>.glb). Rojo cannot carry MeshParts, so the meshes are imported by hand,
-- once, into ServerStorage.MapMeshes, each MeshPart named its key (docs/map/GLACIER.md). When a
-- slot's mesh is there, this swaps it in: the mesh goes where the slot says, the slot's parts go,
-- and any part tagged MeshGlow (the Neon glows, which are never in a mesh) stays. A slot whose mesh
-- is missing keeps its parts, so a half-finished import is never a hole in the map.
local ServerStorage = game:GetService("ServerStorage")

local library = ServerStorage:FindFirstChild("MapMeshes")
local map = workspace:WaitForChild("LemonadeMap", 30)
if not library or not map then
	return
end

-- Studio turns an imported GLB 180 degrees about Y (docs/BOSS_SWORDS.md, "Studio's axes"); this
-- turns it back, so the mesh faces the way the parts did.
local IMPORT_TURN = CFrame.Angles(0, math.pi, 0) -- [TUNING] only if a future importer stops turning

local function meshFor(key: string): MeshPart?
	local found = library:FindFirstChild(key)
	if found and found:IsA("MeshPart") then
		return found
	end
	return found and found:FindFirstChildWhichIsA("MeshPart", true) or nil
end

local swapped, missing = 0, {}
for _, slot in ipairs(map:GetDescendants()) do
	if not (slot:IsA("Model") and slot:GetAttribute("MeshSlot") == true) then
		continue
	end
	local key = slot:GetAttribute("MeshKey")
	local source = typeof(key) == "string" and meshFor(key) or nil
	if not source then
		missing[tostring(key)] = true
		continue
	end
	local scale = slot:GetAttribute("SlotScale") or 1
	local mesh = source:Clone()
	mesh.Name = "Mesh"
	mesh.Anchored = true
	mesh.CanCollide = false -- the zone's collision is its floors and invisible proxies, as before
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.Material = Enum.Material.SmoothPlastic
	mesh.Size = source.Size * scale
	mesh.CFrame = CFrame.new(slot:GetAttribute("SlotX") or 0, slot:GetAttribute("SlotY") or 0, slot:GetAttribute("SlotZ") or 0)
		* CFrame.Angles(0, math.rad(slot:GetAttribute("SlotYaw") or 0), 0)
		* IMPORT_TURN
	for _, child in ipairs(slot:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute("MeshGlow") ~= true then
			child:Destroy()
		end
	end
	mesh.Parent = slot
	swapped += 1
end

local names = {}
for key in pairs(missing) do
	table.insert(names, key)
end
table.sort(names)
print(string.format("[MeshSlots] %d kit pieces now meshes%s", swapped,
	if #names > 0 then "; still parts (no mesh in ServerStorage.MapMeshes): " .. table.concat(names, ", ") else ""))
