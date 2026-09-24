-- Lune local behavioral check + native preview export; no Studio physics simulation.
-- Usage: lune run tools/check_outfits.luau REPO OUTPUT [baseline]
local fs = require('@lune/fs')
local luau = require('@lune/luau')
local rb = require('@lune/roblox')
local serde = require('@lune/serde')
local process = require('@lune/process')
local repo = process.args[1] or '.'
local output = process.args[2] or 'artifacts/outfit-gauntlet/enemies'
local baseline = process.args[3] == 'baseline'
local env = { Color3 = rb.Color3, CFrame = rb.CFrame, Vector3 = rb.Vector3,
	Instance = rb.Instance, Enum = rb.Enum, warn = warn }
local source = fs.readFile(repo .. '/lemonade-game/ReplicatedStorage/EnemyOutfits.luau')
local outfits = luau.load(source, { environment = env, debugName = 'EnemyOutfits' })()
local combat = fs.readFile(repo .. '/lemonade-game/ServerScriptService/EnemyCombat.server.luau')
local config = assert(combat:match('local ENEMY_ARCHETYPES = (%b{})'))
local archetypes = luau.load('return ' .. config, { environment = env })()
local V, C, I = rb.Vector3, rb.CFrame, rb.Instance
local bodies = {
	HumanoidRootPart = { V.new(2,2,1), V.new(0,3,0) },
	Torso = { V.new(2,2,1), V.new(0,3,0) },
	Head = { V.new(1.2,1.2,1.2), V.new(0,4.5,0) },
	['Left Arm'] = { V.new(1,2,1), V.new(-1.5,3,0) },
	['Right Arm'] = { V.new(1,2,1), V.new(1.5,3,0) },
	['Left Leg'] = { V.new(1,2,1), V.new(-.5,1,0) },
	['Right Leg'] = { V.new(1,2,1), V.new(.5,1,0) },
}
local function rig(key, scale, transform)
	local model = I.new('Model')
	model.Name = key
	for name, values in bodies do
		local p = I.new('Part')
		p.Name, p.Size = name, values[1] * scale
		p.CFrame = transform * C.new(values[2] * scale)
		p.Color = archetypes[key] and archetypes[key].color or rb.Color3.new(1,1,1)
		p.CanCollide = name == 'Torso'
		p.Anchored = false
		p.Parent = model
		if name == 'HumanoidRootPart' then p.Transparency = 1; model.PrimaryPart = p end
		if name == 'Head' then
			local mesh = I.new('SpecialMesh')
			mesh.MeshType, mesh.Scale = rb.Enum.MeshType.Head, V.new(1.25,1.25,1.25)
			mesh.Parent = p
		end
	end
	return model
end
local function verify(model, key)
	local count = 0
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') and not bodies[p.Name] then
			count += 1
			assert(not p.Anchored and p.Massless, key .. ': accessory alters assembly mass/anchoring ' .. p.Name)
			assert(not p.CanCollide and not p.CanQuery and not p.CanTouch, key .. ': accessory blocks gameplay ' .. p.Name)
			assert(p.Size.X > 0 and p.Size.Y > 0 and p.Size.Z > 0, key .. ': invalid size')
			local weld = p:FindFirstChildOfClass('WeldConstraint') or p:FindFirstChildOfClass('Weld')
			assert(weld and weld.Part1 == p and weld.Part0 and bodies[weld.Part0.Name], key .. ': invalid limb weld ' .. p.Name)
		end
	end
	return count
end
fs.writeDir(output)
local keys = {}
for key in archetypes do table.insert(keys, key) end
table.sort(keys)
local results = {}
for _, key in keys do
	assert(baseline or outfits.has(key), 'Missing outfit: ' .. key)
	local model = rig(key, 1, C.identity)
	outfits.apply(model, key, 1)
	local count = verify(model, key)
	local descendants = #model:GetDescendants()
	outfits.apply(model, key, 1)
	assert(#model:GetDescendants() == descendants, key .. ': repeated apply duplicates outfit')
	fs.writeFile(output .. '/' .. key .. '.rbxmx', rb.serializeModel({model}, true))
	local transform = C.new(17, 4, -9) * C.Angles(.1, .6, -.1)
	local scaled = rig(key, archetypes[key].scale, transform)
	outfits.apply(scaled, key, archetypes[key].scale)
	assert(verify(scaled, key) == count, key .. ': scale changes accessory count')
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') and not bodies[p.Name] then
			local other = scaled:FindFirstChild(p.Name, true)
			-- Names should be unique so diagnostics can identify the failing accessory.
			assert(other, key .. ': missing scaled piece ' .. p.Name)
			assert((other.Size - p.Size * archetypes[key].scale).Magnitude < .0001, key .. ': wrong scaled size ' .. p.Name)
			local expected = transform * C.new(p.CFrame.Position * archetypes[key].scale) * p.CFrame.Rotation
			assert((other.CFrame.Position - expected.Position).Magnitude < .0001, key .. ': wrong scaled/rotated offset ' .. p.Name)
		end
	end
	table.insert(results, { key=key, accessories=count, scale=archetypes[key].scale, repeatedApply=true, transformedScale=true })
end
local elite = rig('IronBerserker', 1, C.identity)
outfits.apply(elite, 'IronBerserker', 1, 'elite')
assert(elite:GetAttribute('Outfit') == 'IronBerserker_elite', 'Elite variant not selected')
local eliteCount = verify(elite, 'IronBerserker_elite')
fs.writeFile(output .. '/IronBerserker_elite.rbxmx', rb.serializeModel({elite}, true))
table.insert(results, {key='IronBerserker_elite', accessories=eliteCount})
local unknown = rig('unknown', 1, C.identity)
local before = #unknown:GetDescendants()
outfits.apply(unknown, 'unknown', 1)
assert(#unknown:GetDescendants() == before and unknown:GetAttribute('Outfit') == nil, 'Unknown key changes model')
fs.writeFile(output .. '/validation.json', serde.encode('json', {archetypes=#keys, variants=#results, results=results, unknownNoOp=true}, true))
print('PASS', #keys, 'archetypes;', #results, 'variants; scale, rotated placement, physics flags, welds, repeat apply, unknown no-op')
