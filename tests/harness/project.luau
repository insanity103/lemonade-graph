--// tests/harness/project.luau  (mount a Rojo project file into a harness world)
-- Reads default.project.json the way Rojo does, so the harness DataModel has exactly the tree the
-- game syncs into Studio: every `$path` directory becomes a Folder of its files, `X.luau` a
-- ModuleScript, `X.server.luau` a Script, `X.client.luau` a LocalScript, `init.*` turns its folder
-- into that script, `$className` nodes become that class. Model files (.rbxm / .rbxmx) mount as
-- empty Models of the same name: the harness never reads binary assets (code that needs their
-- insides, like prebuilt NPC rigs, falls back as it would on a missing asset).
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Project = {}

local SCRIPT_SUFFIXES = {
	{ ".server.luau", "Script" }, { ".server.lua", "Script" },
	{ ".client.luau", "LocalScript" }, { ".client.lua", "LocalScript" },
	{ ".luau", "ModuleScript" }, { ".lua", "ModuleScript" },
}

local function classifyFile(fileName)
	for _, pair in ipairs(SCRIPT_SUFFIXES) do
		local suffix = pair[1]
		if #fileName > #suffix and string.sub(fileName, -#suffix) == suffix then
			return pair[2], string.sub(fileName, 1, -#suffix - 1)
		end
	end
	local base, ext = string.match(fileName, "^(.*)%.([%w]+)$")
	if ext == "rbxm" or ext == "rbxmx" then return "Model", base end
	if ext == "txt" then return "StringValue", base end
	if ext == "json" and not string.match(fileName, "%.meta%.json$") and not string.match(fileName, "%.project%.json$") then
		return "JsonModule", base
	end
	return nil, nil
end

local function newScript(world, className, name, path)
	local inst = world:newInstance(className)
	inst.Name = name
	world:stateOf(inst).source = path
	world.compile(path)
	return inst
end

-- Build the instance for one filesystem path (file or directory).
local function mountPath(world, path, name)
	if fs.isFile(path) then
		local fileName = string.match(path, "[^/]+$")
		local className = classifyFile(fileName)
		if className == nil then return nil end
		if className == "JsonModule" then
			local inst = world:newInstance("ModuleScript")
			inst.Name = name
			world:stateOf(inst).jsonValue = serde.decode("json", fs.readFile(path))
			return inst
		elseif className == "StringValue" then
			local inst = world:newInstance("StringValue")
			inst.Name = name
			inst.Value = fs.readFile(path)
			return inst
		elseif className == "Model" then
			local inst = world:newInstance("Model")
			inst.Name = name
			return inst
		end
		return newScript(world, className, name, path)
	end
	-- a directory: init.* makes the folder itself a script
	local entries = fs.readDir(path)
	table.sort(entries)
	local container = nil
	for _, entry in ipairs(entries) do
		local className, base = classifyFile(entry)
		if base == "init" and (className == "Script" or className == "LocalScript" or className == "ModuleScript") then
			container = newScript(world, className, name, path .. "/" .. entry)
		end
	end
	if not container then
		local className = "Folder"
		local meta = path .. "/init.meta.json"
		if fs.isFile(meta) then
			local ok, decoded = pcall(serde.decode, "json", fs.readFile(meta))
			if ok and type(decoded) == "table" and decoded.className then className = decoded.className end
		end
		container = world:newInstance(className)
		container.Name = name
	end
	for _, entry in ipairs(entries) do
		local full = path .. "/" .. entry
		local className, base = classifyFile(entry)
		if fs.isDir(full) then
			local child = mountPath(world, full, entry)
			if child then child.Parent = container end
		elseif className and base ~= "init" then
			local child = mountPath(world, full, base)
			if child then child.Parent = container end
		end
	end
	return container
end

local function mountNode(world, root, node, name, parent)
	local inst
	if parent == world.game then
		inst = world:service(name)
	elseif node["$path"] then
		inst = mountPath(world, root .. "/" .. node["$path"], name)
		if not inst then error("project: cannot mount " .. node["$path"]) end
	else
		inst = parent:FindFirstChild(name) or world:newInstance(node["$className"] or "Folder")
		inst.Name = name
	end
	if parent == world.game and node["$path"] then
		-- a service mapped straight to a directory: mount its contents into the service
		local folder = mountPath(world, root .. "/" .. node["$path"], name)
		for _, child in ipairs(folder:GetChildren()) do child.Parent = inst end
	end
	for key, child in pairs(node) do
		if string.sub(key, 1, 1) ~= "$" then
			mountNode(world, root, child, key, inst)
		end
	end
	if inst.Parent == nil and inst ~= world.game then inst.Parent = parent end
	return inst
end

-- Mount `projectFile` (relative to `root`) into `world`.
function Project.mount(world, root, projectFile)
	local project = serde.decode("json", fs.readFile(root .. "/" .. projectFile))
	for key, child in pairs(project.tree) do
		if string.sub(key, 1, 1) ~= "$" then
			mountNode(world, root, child, key, world.game)
		end
	end
	return project
end

return Project
