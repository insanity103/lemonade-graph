--// tests/harness/world.luau  (a headless Roblox server: Instances, signals, services, a virtual clock)
-- World.new() builds one isolated DataModel. Game modules are loaded from their real files with a
-- per-script environment (game, workspace, script, require, typeof, Instance, task, os.clock ...),
-- so the code under test runs unmodified. Nothing here talks to Roblox.
--
-- TIME is virtual. task.wait / task.delay / os.clock / workspace:GetServerTimeNow all read the
-- world's clock, which only moves when a test calls world:advance(seconds). task.defer work runs on
-- world:flush() (advance flushes too). Deterministic, and a 2.4 s wheel spin costs no real time.
--
-- ERRORS inside game threads (a Connect handler, a task.spawn) do not propagate, exactly as in
-- Roblox, but every one is recorded in world.errors and the test runner fails the test that caused
-- it. print / warn go to world.logs (shown when a test fails), not to the terminal.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local D = require("./datatypes")
local Vector3, CFrame, Color3, Enum = D.Vector3, D.CFrame, D.Color3, D.Enum
local typeof = D.typeof

local World = {}
World.__index = World

-- Every world a test creates, so the runner can check them for script errors afterwards.
World.live = {}

-- Compiled bytecode per file: a module is compiled once per run however many worlds load it.
local bytecodeCache = {}

-- ================================================================ class model
local SUPER = {
	PVInstance = "Instance", BasePart = "PVInstance", Model = "PVInstance", WorldRoot = "Model",
	Workspace = "WorldRoot", Part = "FormFactorPart", FormFactorPart = "BasePart", MeshPart = "BasePart",
	WedgePart = "FormFactorPart", CornerWedgePart = "BasePart", TrussPart = "BasePart",
	UnionOperation = "PartOperation", PartOperation = "TriangleMeshPart", TriangleMeshPart = "BasePart",
	SpawnLocation = "Part", Seat = "Part", VehicleSeat = "BasePart", Terrain = "BasePart",
	Tool = "BackpackItem", HopperBin = "BackpackItem", BackpackItem = "Instance",
	Accessory = "Accoutrement", Hat = "Accoutrement",
	IntValue = "ValueBase", NumberValue = "ValueBase", StringValue = "ValueBase", BoolValue = "ValueBase",
	ObjectValue = "ValueBase", CFrameValue = "ValueBase", Vector3Value = "ValueBase", Color3Value = "ValueBase",
	BrickColorValue = "ValueBase", RayValue = "ValueBase",
	Script = "BaseScript", LocalScript = "Script", BaseScript = "LuaSourceContainer",
	ModuleScript = "LuaSourceContainer",
	RemoteEvent = "BaseRemoteEvent", UnreliableRemoteEvent = "BaseRemoteEvent",
	ScreenGui = "LayerCollector", BillboardGui = "LayerCollector", SurfaceGui = "SurfaceGuiBase",
	SurfaceGuiBase = "LayerCollector", LayerCollector = "GuiBase2d", GuiBase2d = "GuiBase",
	Frame = "GuiObject", TextLabel = "GuiLabel", GuiLabel = "GuiObject", ImageLabel = "GuiLabel",
	TextButton = "GuiButton", ImageButton = "GuiButton", GuiButton = "GuiObject", TextBox = "GuiObject",
	ScrollingFrame = "GuiObject", CanvasGroup = "GuiObject", ViewportFrame = "GuiObject",
	GuiObject = "GuiBase2d",
	UICorner = "UIComponent", UIStroke = "UIComponent", UIGradient = "UIComponent", UIPadding = "UIComponent",
	UIListLayout = "UIGridStyleLayout", UIGridLayout = "UIGridStyleLayout", UIGridStyleLayout = "UILayout",
	UILayout = "UIComponent", UIScale = "UIComponent", UIAspectRatioConstraint = "UIConstraint",
	UISizeConstraint = "UIConstraint", UITextSizeConstraint = "UIConstraint", UIConstraint = "UIComponent",
	UIComponent = "UIBase",
	Weld = "JointInstance", ManualWeld = "JointInstance", Motor6D = "Motor", Motor = "JointInstance",
	Snap = "JointInstance", WeldConstraint = "Instance", NoCollisionConstraint = "Instance",
	AlignPosition = "Constraint", AlignOrientation = "Constraint", LinearVelocity = "Constraint",
	AngularVelocity = "Constraint", VectorForce = "Constraint", RopeConstraint = "Constraint",
	PointLight = "Light", SpotLight = "Light", SurfaceLight = "Light",
	SpecialMesh = "FileMesh", FileMesh = "DataModelMesh", BlockMesh = "BevelMesh", BevelMesh = "DataModelMesh",
	Decal = "FaceInstance", Texture = "Decal",
	StarterPlayerScripts = "Instance", StarterCharacterScripts = "StarterPlayerScripts",
}

-- Property defaults per class (functions build a fresh value). Unknown properties read as nil.
local DEFAULTS = {
	Instance = { Archivable = true },
	BasePart = {
		Size = function() return Vector3.new(4, 1, 2) end,
		CFrame = function() return CFrame.new() end,
		Color = function() return Color3.new(0.639, 0.635, 0.647) end,
		Material = function() return Enum.Material.Plastic end,
		Transparency = 0, Reflectance = 0, Anchored = false, CanCollide = true, CanTouch = true,
		CanQuery = true, Massless = false, CastShadow = true, Locked = false,
		AssemblyLinearVelocity = function() return Vector3.zero end,
		AssemblyAngularVelocity = function() return Vector3.zero end,
		Shape = function() return Enum.PartType.Block end, CollisionGroup = "Default",
	},
	MeshPart = { MeshId = "", TextureID = "", MeshSize = function() return Vector3.one end },
	Model = { PrimaryPart = nil },
	Tool = { Grip = function() return CFrame.new() end, RequiresHandle = true, CanBeDropped = true,
		Enabled = true, ManualActivationOnly = false, ToolTip = "", TextureId = "" },
	Humanoid = { Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2,
		HipHeight = 2, DisplayName = "", AutoRotate = true, UseJumpPower = true,
		RigType = function() return Enum.HumanoidRigType.R15 end, BreakJointsOnDeath = true,
		MoveDirection = function() return Vector3.zero end, FloorMaterial = function() return Enum.Material.Plastic end },
	IntValue = { Value = 0 }, NumberValue = { Value = 0 }, StringValue = { Value = "" },
	BoolValue = { Value = false }, CFrameValue = { Value = function() return CFrame.new() end },
	Vector3Value = { Value = function() return Vector3.zero end },
	Color3Value = { Value = function() return Color3.new() end },
	Player = { UserId = 1, DisplayName = "", AccountAge = 0, Team = nil, Character = nil, Neutral = true,
		MembershipType = function() return Enum.MembershipType.None end },
	Players = { MaxPlayers = 12, RespawnTime = 5, CharacterAutoLoads = false },
	Workspace = { Gravity = 196.2, DistributedGameTime = 0, StreamingEnabled = false },
	DataModel = { JobId = "", PlaceId = 0, GameId = 0, PlaceVersion = 0, CreatorId = 0 },
	Sound = { Volume = 0.5, PlaybackSpeed = 1, IsPlaying = false, SoundId = "", TimeLength = 1, Looped = false },
	ProximityPrompt = { Enabled = true, HoldDuration = 0, MaxActivationDistance = 10, ActionText = "Interact",
		ObjectText = "", RequiresLineOfSight = true },
	GuiObject = { Visible = true, BackgroundTransparency = 0, ZIndex = 1, LayoutOrder = 0 },
	LayerCollector = { Enabled = true },
	Light = { Enabled = true, Brightness = 1, Range = 8 },
	ParticleEmitter = { Enabled = true, Rate = 20 },
	Attachment = { CFrame = function() return CFrame.new() end, Position = function() return Vector3.zero end },
	Camera = { CFrame = function() return CFrame.new() end, FieldOfView = 70 },
}

-- Signal-typed members. Any of these read off any Instance returns that Instance's own signal.
local EVENTS = {}
for _, name in ipairs({ "Changed", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving",
	"AncestryChanged", "Destroying", "AttributeChanged", "Died", "HealthChanged", "StateChanged", "Running",
	"MoveToFinished", "Touched", "TouchEnded", "Triggered", "TriggerEnded", "PromptShown", "PromptHidden",
	"PromptButtonHoldBegan", "PromptButtonHoldEnded", "OnServerEvent", "OnClientEvent", "Event",
	"PlayerAdded", "PlayerRemoving", "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded",
	"Equipped", "Unequipped", "Activated", "Deactivated", "Heartbeat", "Stepped", "RenderStepped",
	"PreSimulation", "PostSimulation", "PreRender", "PreAnimation", "Completed", "Ended", "Played",
	"Stopped", "DidLoop", "KeyframeReached", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up",
	"MouseEnter", "MouseLeave", "Activated", "InputBegan", "InputEnded", "InputChanged", "FocusLost",
	"Idled", "Chatted", "OnInvoke" }) do
	EVENTS[name] = true
end
EVENTS.OnInvoke = nil -- a callback property, not a signal

local function isA(className, wanted)
	if wanted == "Instance" then return true end
	local c = className
	while c do
		if c == wanted then return true end
		c = SUPER[c]
	end
	return false
end

-- ================================================================ World
function World.new(options)
	options = options or {}
	local self = setmetatable({}, World)
	self.options = options
	self.clock = 0              -- virtual seconds since the world started
	self.epoch = 1790000000     -- os.time() at clock 0 (fixed: saves and locks compare it)
	self.seq = 0
	self.deferred = {}
	self.timers = {}
	self.errors = {}
	self.logs = {}
	self.remoteLog = {}         -- [remote] = { { kind, player, args } ... }
	self.modules = {}           -- [ModuleScript] = { state = "loading" | "done", value = ... }
	self.tags = {}              -- [tag] = { [instance] = true }
	self.studio = options.studio == true
	self.state = setmetatable({}, { __mode = "k" }) -- [instance proxy] = internal state
	self.shared = {}
	self:buildGlobals()
	self.game = self:newInstance("DataModel")
	self:stateOf(self.game).props.Name = "Game"
	self.services = {}
	self.workspace = self:service("Workspace")
	for _, name in ipairs({ "Players", "ReplicatedStorage", "ServerStorage", "ServerScriptService", "StarterPack",
		"StarterPlayer", "StarterGui", "Lighting", "SoundService", "RunService", "CollectionService",
		"DataStoreService", "HttpService", "TweenService", "Debris", "TextService", "PhysicsService" }) do
		self:service(name)
	end
	table.insert(World.live, self)
	return self
end

-- ---------------------------------------------------------------- scheduler
function World:resume(thread, ...)
	if coroutine.status(thread) == "dead" then return end
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		local trace = debug.traceback(thread, tostring(err))
		table.insert(self.errors, trace)
		self:log("error", trace)
	end
end

function World:spawn(fnOrThread, ...)
	local thread = type(fnOrThread) == "thread" and fnOrThread or coroutine.create(fnOrThread)
	self:resume(thread, ...)
	return thread
end

function World:defer(fnOrThread, ...)
	local thread = type(fnOrThread) == "thread" and fnOrThread or coroutine.create(fnOrThread)
	table.insert(self.deferred, { thread = thread, args = table.pack(...) })
	return thread
end

function World:delay(seconds, fnOrThread, ...)
	local thread = type(fnOrThread) == "thread" and fnOrThread or coroutine.create(fnOrThread)
	self.seq += 1
	table.insert(self.timers, { at = self.clock + math.max(tonumber(seconds) or 0, 0), seq = self.seq,
		thread = thread, args = table.pack(...) })
	return thread
end

function World:wait(seconds)
	local thread = coroutine.running()
	if not coroutine.isyieldable() then
		error("task.wait called outside a yieldable thread (the harness runs game code in coroutines)", 2)
	end
	local start = self.clock
	self.seq += 1
	table.insert(self.timers, { at = self.clock + math.max(tonumber(seconds) or 0, 1 / 60), seq = self.seq,
		thread = thread, args = nil, waitStart = start })
	coroutine.yield()
	return self.clock - start, self.clock
end

-- Run every deferred thread (and whatever those defer), in order.
function World:flush()
	local guard = 0
	while #self.deferred > 0 do
		guard += 1
		if guard > 100000 then error("world:flush(): deferred work never settles (a defer loop?)") end
		local item = table.remove(self.deferred, 1)
		if not item.cancelled then
			self:resume(item.thread, table.unpack(item.args, 1, item.args.n))
		end
	end
end

-- Move the virtual clock forward, waking every timer that falls due on the way (in order).
function World:advance(seconds)
	local target = self.clock + (seconds or 0)
	self:flush()
	while true do
		local best, bestIndex = nil, nil
		for i, t in ipairs(self.timers) do
			if t.at <= target and (not best or t.at < best.at or (t.at == best.at and t.seq < best.seq)) then
				best, bestIndex = t, i
			end
		end
		if not best then break end
		table.remove(self.timers, bestIndex)
		self.clock = math.max(self.clock, best.at)
		if not best.cancelled then
			if best.args then
				self:resume(best.thread, table.unpack(best.args, 1, best.args.n))
			else
				self:resume(best.thread, self.clock - best.waitStart, self.clock)
			end
		end
		self:flush()
	end
	self.clock = target
	self:flush()
end

function World:cancel(thread)
	for _, t in ipairs(self.timers) do
		if t.thread == thread then t.cancelled = true end
	end
	for _, d in ipairs(self.deferred) do
		if d.thread == thread then d.cancelled = true end
	end
	if coroutine.status(thread) == "suspended" then pcall(coroutine.close, thread) end
end

-- ---------------------------------------------------------------- logging
function World:log(kind, text)
	table.insert(self.logs, { kind = kind, text = text, at = self.clock })
end

local function joinArgs(...)
	local parts = table.pack(...)
	for i = 1, parts.n do parts[i] = tostring(parts[i]) end
	return table.concat(parts, " ", 1, parts.n)
end

-- Lines logged by game code (print and warn) whose text matches `pattern` (a Lua pattern).
function World:logged(pattern, kind)
	local out = {}
	for _, entry in ipairs(self.logs) do
		if (kind == nil or entry.kind == kind) and string.find(entry.text, pattern) then
			table.insert(out, entry.text)
		end
	end
	return out
end

-- ---------------------------------------------------------------- signals
local Signal = {}
Signal.__index = Signal
local SignalType = { __type = "RBXScriptSignal", __index = Signal }
local ConnectionType = { __type = "RBXScriptConnection" }
ConnectionType.__index = ConnectionType
function ConnectionType.Disconnect(conn)
	conn.Connected = false
	local list = conn._signal._handlers
	for i, c in ipairs(list) do
		if c == conn then table.remove(list, i) break end
	end
end

function World:newSignal(name)
	return setmetatable({ _world = self, _handlers = {}, _waiting = {}, _name = name }, SignalType)
end

function Signal.Connect(signal, fn)
	assert(type(fn) == "function", "Connect expects a function")
	local conn = setmetatable({ Connected = true, _signal = signal, _fn = fn }, ConnectionType)
	table.insert(signal._handlers, conn)
	return conn
end
Signal.ConnectParallel = Signal.Connect

function Signal.Once(signal, fn)
	local conn
	conn = Signal.Connect(signal, function(...)
		if conn.Connected then
			conn:Disconnect()
			fn(...)
		end
	end)
	return conn
end

function Signal.Wait(signal)
	table.insert(signal._waiting, coroutine.running())
	return coroutine.yield()
end

-- Handlers run immediately, each on its own thread (Roblox's immediate signal mode).
function Signal.Fire(signal, ...)
	local handlers = table.clone(signal._handlers)
	for _, conn in ipairs(handlers) do
		if conn.Connected then signal._world:spawn(conn._fn, ...) end
	end
	local waiting = signal._waiting
	signal._waiting = {}
	for _, thread in ipairs(waiting) do signal._world:resume(thread, ...) end
end

-- ================================================================ instances
local STATE = {} -- unique key: an Instance proxy keeps its state under it

function World:stateOf(inst)
	return rawget(inst, STATE)
end

local Methods = {}   -- [className] = { name = fn }, looked up along SUPER
local function method(className, name, fn)
	Methods[className] = Methods[className] or {}
	Methods[className][name] = fn
end

local InstanceMT = { __type = "Instance" }

local function findMethod(className, key)
	local c = className
	while c do
		local m = Methods[c]
		if m and m[key] then return m[key] end
		c = SUPER[c]
	end
	local m = Methods.Instance
	return m and m[key]
end

local function findDefault(className, key)
	local c = className
	while c do
		local d = DEFAULTS[c]
		if d and d[key] ~= nil then return d[key], true end
		c = SUPER[c]
	end
	local d = DEFAULTS.Instance
	if d[key] ~= nil then return d[key], true end
	return nil, false
end

InstanceMT.__index = function(self, key)
	local st = rawget(self, STATE)
	local props = st.props
	local v = props[key]
	if v ~= nil then return v end
	if key == "Parent" then return st.parent end
	if key == "ClassName" then return st.class end
	local m = findMethod(st.class, key)
	if m then return m end
	if EVENTS[key] then
		local sig = st.signals[key]
		if not sig then
			sig = st.world:newSignal(key)
			st.signals[key] = sig
		end
		return sig
	end
	if key == "Position" and isA(st.class, "BasePart") then
		return InstanceMT.__index(self, "CFrame").Position
	end
	for _, child in ipairs(st.children) do
		if rawget(child, STATE).props.Name == key then return child end
	end
	local d, has = findDefault(st.class, key)
	if has then
		if type(d) == "function" then d = d() end
		props[key] = d
		return d
	end
	return nil
end

InstanceMT.__tostring = function(self)
	return rawget(self, STATE).props.Name
end

function World:propertySignal(inst, prop)
	local st = rawget(inst, STATE)
	local sig = st.propSignals[prop]
	if not sig then
		sig = self:newSignal("Property:" .. prop)
		st.propSignals[prop] = sig
	end
	return sig
end

local function fireChanged(st, inst, key, value)
	local sig = st.propSignals[key]
	if sig then sig:Fire() end
	local changed = st.signals.Changed
	if changed then
		if isA(st.class, "ValueBase") then
			if key == "Value" then changed:Fire(value) end
		else
			changed:Fire(key)
		end
	end
end

InstanceMT.__newindex = function(self, key, value)
	local st = rawget(self, STATE)
	local world = st.world
	if key == "Parent" then
		world:setParent(self, value)
		return
	end
	if key == "ClassName" then error("ClassName is read-only", 2) end
	if EVENTS[key] then error(key .. " is a signal and cannot be assigned", 2) end
	if st.class == "Humanoid" and key == "Health" then
		local maxHealth = st.props.MaxHealth or 100
		value = math.clamp(tonumber(value) or 0, 0, maxHealth)
		local before = st.props.Health or 100
		st.props.Health = value
		if value ~= before then
			fireChanged(st, self, key, value)
			if st.signals.HealthChanged then st.signals.HealthChanged:Fire(value) end
		end
		if value <= 0 and not st.dead then
			st.dead = true
			InstanceMT.__index(self, "Died"):Fire()
		end
		return
	end
	if isA(st.class, "BasePart") then
		if key == "Position" then
			local old = InstanceMT.__index(self, "CFrame")
			st.props.CFrame = CFrame.new(value) * old.Rotation
			fireChanged(st, self, "CFrame", st.props.CFrame)
			fireChanged(st, self, "Position", value)
			return
		end
	end
	if st.class == "IntValue" and type(value) == "number" then
		value = if value >= 0 then math.floor(value) else math.ceil(value)
	end
	local before = st.props[key]
	st.props[key] = value
	if before ~= value then fireChanged(st, self, key, value) end
end

function World:newInstance(className, parent)
	local st = {
		world = self, class = className, props = { Name = className }, parent = nil, children = {},
		attributes = {}, signals = {}, propSignals = {}, attrSignals = {}, tags = {},
	}
	local inst = setmetatable({ [STATE] = st }, InstanceMT)
	self.state[inst] = st
	if parent then inst.Parent = parent end
	return inst
end

local function descendants(inst, out)
	for _, child in ipairs(rawget(inst, STATE).children) do
		table.insert(out, child)
		descendants(child, out)
	end
	return out
end

function World:setParent(inst, parent)
	local st = rawget(inst, STATE)
	if st.destroyed then
		error(string.format("The Parent property of %s is locked, current parent: NULL, new parent %s",
			st.props.Name, parent and tostring(parent) or "NULL"), 3)
	end
	if parent == st.parent then return end
	if parent ~= nil and typeof(parent) ~= "Instance" then error("Parent must be an Instance or nil", 3) end
	-- no cycles
	local p = parent
	while p do
		if p == inst then error("Attempt to set parent of " .. st.props.Name .. " to itself or a descendant", 3) end
		p = rawget(p, STATE).parent
	end
	local old = st.parent
	if old then
		local ost = rawget(old, STATE)
		for i, c in ipairs(ost.children) do
			if c == inst then table.remove(ost.children, i) break end
		end
		local removing = { inst }
		descendants(inst, removing)
		local a = old
		while a do
			local ast = rawget(a, STATE)
			if ast.signals.DescendantRemoving then
				for _, d in ipairs(removing) do ast.signals.DescendantRemoving:Fire(d) end
			end
			a = ast.parent
		end
		if ost.signals.ChildRemoved then ost.signals.ChildRemoved:Fire(inst) end
	end
	st.parent = parent
	if parent then
		local pst = rawget(parent, STATE)
		table.insert(pst.children, inst)
		if pst.signals.ChildAdded then pst.signals.ChildAdded:Fire(inst) end
		local added = { inst }
		descendants(inst, added)
		local a = parent
		while a do
			local ast = rawget(a, STATE)
			if ast.signals.DescendantAdded then
				for _, d in ipairs(added) do ast.signals.DescendantAdded:Fire(d) end
			end
			a = ast.parent
		end
	end
	local anc = { inst }
	descendants(inst, anc)
	for _, d in ipairs(anc) do
		local dst = rawget(d, STATE)
		if dst.signals.AncestryChanged then dst.signals.AncestryChanged:Fire(inst, parent) end
	end
	local sig = st.propSignals.Parent
	if sig then sig:Fire() end
	if st.signals.Changed then st.signals.Changed:Fire("Parent") end
end

-- ---------------------------------------------------------------- Instance methods
method("Instance", "IsA", function(self, name) return isA(rawget(self, STATE).class, name) end)
method("Instance", "GetChildren", function(self) return table.clone(rawget(self, STATE).children) end)
method("Instance", "GetDescendants", function(self) return descendants(self, {}) end)
method("Instance", "FindFirstChild", function(self, name, recursive)
	for _, child in ipairs(rawget(self, STATE).children) do
		if rawget(child, STATE).props.Name == name then return child end
	end
	if recursive then
		for _, d in ipairs(descendants(self, {})) do
			if rawget(d, STATE).props.Name == name then return d end
		end
	end
	return nil
end)
method("Instance", "FindFirstDescendant", function(self, name) return self:FindFirstChild(name, true) end)
method("Instance", "FindFirstChildOfClass", function(self, className)
	for _, child in ipairs(rawget(self, STATE).children) do
		if rawget(child, STATE).class == className then return child end
	end
	return nil
end)
method("Instance", "FindFirstChildWhichIsA", function(self, className, recursive)
	local list = recursive and descendants(self, {}) or rawget(self, STATE).children
	for _, child in ipairs(list) do
		if isA(rawget(child, STATE).class, className) then return child end
	end
	return nil
end)
method("Instance", "FindFirstAncestor", function(self, name)
	local p = rawget(self, STATE).parent
	while p do
		if rawget(p, STATE).props.Name == name then return p end
		p = rawget(p, STATE).parent
	end
	return nil
end)
method("Instance", "FindFirstAncestorOfClass", function(self, className)
	local p = rawget(self, STATE).parent
	while p do
		if rawget(p, STATE).class == className then return p end
		p = rawget(p, STATE).parent
	end
	return nil
end)
method("Instance", "FindFirstAncestorWhichIsA", function(self, className)
	local p = rawget(self, STATE).parent
	while p do
		if isA(rawget(p, STATE).class, className) then return p end
		p = rawget(p, STATE).parent
	end
	return nil
end)
method("Instance", "IsDescendantOf", function(self, other)
	local p = rawget(self, STATE).parent
	while p do
		if p == other then return true end
		p = rawget(p, STATE).parent
	end
	return false
end)
method("Instance", "IsAncestorOf", function(self, other) return other:IsDescendantOf(self) end)
-- WaitForChild: a present child returns at once. A missing one with a timeout yields on the
-- virtual clock (returning nil if it never comes); a missing one with NO timeout would hang
-- forever in Roblox too, so it fails loudly instead of deadlocking the run.
method("Instance", "WaitForChild", function(self, name, timeout)
	local found = self:FindFirstChild(name)
	if found then return found end
	local st = rawget(self, STATE)
	if timeout == nil or not coroutine.isyieldable() then
		error(string.format("Infinite yield: WaitForChild(%q) on %s -- the harness world has no such child",
			name, self:GetFullName()), 2)
	end
	local thread = coroutine.running()
	local done = false
	local conn
	conn = self.ChildAdded:Connect(function(child)
		if not done and child.Name == name then
			done = true
			conn:Disconnect()
			st.world:resume(thread, child)
		end
	end)
	st.world:delay(timeout, function()
		if not done then
			done = true
			conn:Disconnect()
			st.world:resume(thread, nil)
		end
	end)
	return coroutine.yield()
end)
method("Instance", "GetFullName", function(self)
	local parts = {}
	local p = self
	while p do
		local pst = rawget(p, STATE)
		if pst.class == "DataModel" then break end
		table.insert(parts, 1, pst.props.Name)
		p = pst.parent
	end
	return table.concat(parts, ".")
end)
method("Instance", "GetDebugId", function(self) return tostring(rawget(self, STATE)) end)
method("Instance", "Destroy", function(self)
	local st = rawget(self, STATE)
	if st.destroyed then return end
	if st.signals.Destroying then st.signals.Destroying:Fire() end
	for _, child in ipairs(table.clone(st.children)) do child:Destroy() end
	st.world:setParent(self, nil)
	st.destroyed = true
	for _, sig in pairs(st.signals) do sig._handlers = {} end
	for tag in pairs(st.tags) do
		local set = st.world.tags[tag]
		if set then set[self] = nil end
	end
end)
method("Instance", "Remove", function(self) self.Parent = nil end)
method("Instance", "ClearAllChildren", function(self)
	for _, child in ipairs(table.clone(rawget(self, STATE).children)) do child:Destroy() end
end)
method("Instance", "Clone", function(self)
	local st = rawget(self, STATE)
	if st.props.Archivable == false then return nil end
	local copy = st.world:newInstance(st.class)
	local cst = rawget(copy, STATE)
	for k, v in pairs(st.props) do cst.props[k] = v end
	for k, v in pairs(st.attributes) do cst.attributes[k] = v end
	for tag in pairs(st.tags) do copy:AddTag(tag) end
	cst.source = st.source
	for _, child in ipairs(st.children) do
		local c = child:Clone()
		if c then c.Parent = copy end
	end
	-- a Model's PrimaryPart points into the copy, as in Roblox
	if st.props.PrimaryPart then
		local path = {}
		local p = st.props.PrimaryPart
		while p and p ~= self do table.insert(path, 1, p.Name) p = p.Parent end
		local target = copy
		for _, n in ipairs(path) do target = target and target:FindFirstChild(n) end
		cst.props.PrimaryPart = target
	end
	return copy
end)
-- Attributes: the Roblox value types only (a table or a function errors, as it does there).
local ATTR_TYPES = { boolean = true, number = true, string = true, Vector3 = true, Vector2 = true,
	CFrame = true, Color3 = true, UDim = true, UDim2 = true, NumberRange = true, NumberSequence = true,
	ColorSequence = true, Rect = true, BrickColor = true, EnumItem = true, Font = true }
method("Instance", "SetAttribute", function(self, name, value)
	local st = rawget(self, STATE)
	if type(name) ~= "string" then error("SetAttribute: attribute name must be a string", 2) end
	if value ~= nil and not ATTR_TYPES[typeof(value)] then
		error(string.format("SetAttribute(%q): %s is not a supported attribute type", name, typeof(value)), 2)
	end
	if value ~= value then error("SetAttribute: NaN is not allowed", 2) end
	local before = st.attributes[name]
	st.attributes[name] = value
	if before ~= value then
		local sig = st.attrSignals[name]
		if sig then sig:Fire() end
		if st.signals.AttributeChanged then st.signals.AttributeChanged:Fire(name) end
	end
end)
method("Instance", "GetAttribute", function(self, name) return rawget(self, STATE).attributes[name] end)
method("Instance", "GetAttributes", function(self) return table.clone(rawget(self, STATE).attributes) end)
method("Instance", "GetAttributeChangedSignal", function(self, name)
	local st = rawget(self, STATE)
	local sig = st.attrSignals[name]
	if not sig then
		sig = st.world:newSignal("Attribute:" .. name)
		st.attrSignals[name] = sig
	end
	return sig
end)
method("Instance", "GetPropertyChangedSignal", function(self, prop)
	return rawget(self, STATE).world:propertySignal(self, prop)
end)
method("Instance", "AddTag", function(self, tag)
	local st = rawget(self, STATE)
	st.tags[tag] = true
	st.world.tags[tag] = st.world.tags[tag] or {}
	st.world.tags[tag][self] = true
end)
method("Instance", "RemoveTag", function(self, tag)
	local st = rawget(self, STATE)
	st.tags[tag] = nil
	if st.world.tags[tag] then st.world.tags[tag][self] = nil end
end)
method("Instance", "HasTag", function(self, tag) return rawget(self, STATE).tags[tag] == true end)
method("Instance", "GetTags", function(self)
	local out = {}
	for tag in pairs(rawget(self, STATE).tags) do table.insert(out, tag) end
	return out
end)
method("Instance", "GetActor", function() return nil end)

-- PVInstance / BasePart / Model
local function modelPivot(self)
	local st = rawget(self, STATE)
	if st.props.PrimaryPart then return st.props.PrimaryPart.CFrame end
	if st.props.WorldPivot then return st.props.WorldPivot end
	local part = self:FindFirstChildWhichIsA("BasePart", true)
	return part and part.CFrame or CFrame.new()
end
method("BasePart", "GetPivot", function(self) return self.CFrame end)
method("BasePart", "PivotTo", function(self, target) self.CFrame = target end)
method("BasePart", "GetMass", function(self) local s = self.Size return s.X * s.Y * s.Z * 0.7 end)
method("BasePart", "ApplyImpulse", function() end)
method("BasePart", "ApplyAngularImpulse", function() end)
method("BasePart", "SetNetworkOwner", function() end)
method("BasePart", "SetNetworkOwnershipAuto", function() end)
method("BasePart", "GetNetworkOwner", function() return nil end)
method("BasePart", "CanSetNetworkOwnership", function() return true, nil end)
method("BasePart", "GetTouchingParts", function() return {} end)
method("BasePart", "GetConnectedParts", function(self) return { self } end)
method("BasePart", "GetJoints", function() return {} end)
method("BasePart", "BreakJoints", function() end)
method("Model", "GetPivot", modelPivot)
method("Model", "PivotTo", function(self, target)
	local from = modelPivot(self)
	local delta = target * from:Inverse()
	for _, d in ipairs(descendants(self, {})) do
		if d:IsA("BasePart") then d.CFrame = delta * d.CFrame end
	end
	if rawget(self, STATE).props.WorldPivot then rawget(self, STATE).props.WorldPivot = target end
end)
method("Model", "SetPrimaryPartCFrame", function(self, target) self:PivotTo(target) end)
method("Model", "GetPrimaryPartCFrame", function(self) return modelPivot(self) end)
method("Model", "MoveTo", function(self, pos) self:PivotTo(CFrame.new(pos) * modelPivot(self).Rotation) end)
method("Model", "TranslateBy", function(self, delta) self:PivotTo(modelPivot(self) + delta) end)
method("Model", "GetBoundingBox", function(self) return modelPivot(self), Vector3.new(4, 5, 2) end)
method("Model", "GetExtentsSize", function() return Vector3.new(4, 5, 2) end)
method("Model", "ScaleTo", function(self, s) rawget(self, STATE).props.__scale = s end)
method("Model", "GetScale", function(self) return rawget(self, STATE).props.__scale or 1 end)
method("Model", "BreakJoints", function() end)
method("Model", "MakeJoints", function() end)

-- Humanoid / Animator
local function animTrack(world, anim)
	return {
		Animation = anim, IsPlaying = false, Length = 1, Speed = 1, TimePosition = 0, Looped = false,
		Priority = Enum.AnimationPriority.Action, WeightCurrent = 1,
		Play = function(t) t.IsPlaying = true end, Stop = function(t) t.IsPlaying = false end,
		AdjustSpeed = function(t, s) t.Speed = s end, AdjustWeight = function() end,
		GetMarkerReachedSignal = function() return world:newSignal("Marker") end,
		Stopped = world:newSignal("Stopped"), Ended = world:newSignal("Ended"),
		KeyframeReached = world:newSignal("KeyframeReached"), DidLoop = world:newSignal("DidLoop"),
		Destroy = function() end,
	}
end
method("Humanoid", "TakeDamage", function(self, amount) self.Health = self.Health - amount end)
method("Humanoid", "MoveTo", function(self) end)
method("Humanoid", "LoadAnimation", function(self, anim) return animTrack(rawget(self, STATE).world, anim) end)
method("Animator", "LoadAnimation", function(self, anim) return animTrack(rawget(self, STATE).world, anim) end)
method("AnimationController", "LoadAnimation", function(self, anim) return animTrack(rawget(self, STATE).world, anim) end)
method("Humanoid", "GetPlayingAnimationTracks", function() return {} end)
method("Animator", "GetPlayingAnimationTracks", function() return {} end)
method("Humanoid", "GetState", function(self)
	return rawget(self, STATE).dead and Enum.HumanoidStateType.Dead or Enum.HumanoidStateType.Running
end)
method("Humanoid", "ChangeState", function(self, state)
	if state == Enum.HumanoidStateType.Dead then self.Health = 0 end
end)
method("Humanoid", "SetStateEnabled", function() end)
method("Humanoid", "GetStateEnabled", function() return true end)
method("Humanoid", "EquipTool", function(self, tool)
	local model = self.Parent
	if model then tool.Parent = model end
end)
method("Humanoid", "UnequipTools", function(self)
	local model = self.Parent
	local world = rawget(self, STATE).world
	local player = model and world:service("Players"):GetPlayerFromCharacter(model)
	local bag = player and player:FindFirstChildOfClass("Backpack")
	if model and bag then
		for _, c in ipairs(model:GetChildren()) do
			if c:IsA("Tool") then c.Parent = bag end
		end
	end
end)
method("Humanoid", "ApplyDescription", function() end)
method("Humanoid", "GetAppliedDescription", function(self) return rawget(self, STATE).world:newInstance("HumanoidDescription") end)
method("Humanoid", "BuildRigFromAttachments", function() end)
method("Humanoid", "GetLimb", function() return Enum.Limb.Unknown end)

-- Remotes and bindables. Every server-to-client fire is recorded (world:fired) for tests to read.
local function recordFire(self, kind, player, ...)
	local world = rawget(self, STATE).world
	world.remoteLog[self] = world.remoteLog[self] or {}
	table.insert(world.remoteLog[self], { kind = kind, player = player, args = table.pack(...) })
end
method("BaseRemoteEvent", "FireClient", function(self, player, ...)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		error("FireClient: argument 1 must be a Player", 2)
	end
	recordFire(self, "client", player, ...)
end)
method("BaseRemoteEvent", "FireAllClients", function(self, ...) recordFire(self, "all", nil, ...) end)
method("BaseRemoteEvent", "FireServer", function(self, ...) recordFire(self, "server", nil, ...) end)
method("RemoteFunction", "InvokeClient", function(self, player, ...)
	recordFire(self, "invoke", player, ...)
	return nil
end)
method("BindableEvent", "Fire", function(self, ...) self.Event:Fire(...) end)
method("BindableFunction", "Invoke", function(self, ...)
	local cb = rawget(self, STATE).props.OnInvoke
	if not cb then error("BindableFunction has no OnInvoke", 2) end
	return cb(...)
end)

-- Media and effects: no-ops.
for _, name in ipairs({ "Play", "Stop", "Pause", "Resume" }) do method("Sound", name, function() end) end
method("ParticleEmitter", "Emit", function() end)
method("ParticleEmitter", "Clear", function() end)
method("ProximityPrompt", "InputHoldBegin", function() end)
method("ProximityPrompt", "InputHoldEnd", function() end)
method("Tool", "Activate", function(self) self.Activated:Fire() end)

-- Players
method("Players", "GetPlayers", function(self)
	local out = {}
	for _, c in ipairs(rawget(self, STATE).children) do
		if rawget(c, STATE).class == "Player" then table.insert(out, c) end
	end
	return out
end)
method("Players", "GetPlayerFromCharacter", function(self, character)
	for _, p in ipairs(self:GetPlayers()) do
		if p.Character == character then return p end
	end
	return nil
end)
method("Players", "GetPlayerByUserId", function(self, id)
	for _, p in ipairs(self:GetPlayers()) do
		if p.UserId == id then return p end
	end
	return nil
end)
method("Players", "GetUserIdFromNameAsync", function() return 1 end)
method("Players", "GetNameFromUserIdAsync", function() return "Player" end)
method("Players", "GetUserThumbnailAsync", function() return "", true end)
method("Players", "GetHumanoidDescriptionFromUserId", function(self)
	return rawget(self, STATE).world:newInstance("HumanoidDescription")
end)
method("Player", "Kick", function(self, reason)
	rawget(self, STATE).world:log("warn", "Kick(" .. tostring(self) .. "): " .. tostring(reason))
	self.Parent = nil
end)
method("Player", "LoadCharacter", function() end)
method("Player", "GetRankInGroup", function() return 0 end)
method("Player", "GetRoleInGroup", function() return "Guest" end)
method("Player", "IsInGroup", function() return false end)
method("Player", "GetJoinData", function() return {} end)
method("Player", "GetNetworkPing", function() return 0 end)
method("Player", "HasAppearanceLoaded", function() return true end)
method("Player", "DistanceFromCharacter", function(self, point)
	local root = self.Character and self.Character:FindFirstChild("HumanoidRootPart")
	return root and (root.Position - point).Magnitude or 0
end)

-- DataModel / services
method("DataModel", "GetService", function(self, name) return rawget(self, STATE).world:service(name) end)
method("DataModel", "FindService", function(self, name) return rawget(self, STATE).world.services[name] end)
method("DataModel", "BindToClose", function(self, fn)
	local world = rawget(self, STATE).world
	world.closeHandlers = world.closeHandlers or {}
	table.insert(world.closeHandlers, fn)
end)
method("DataModel", "IsLoaded", function() return true end)
method("RunService", "IsStudio", function(self) return rawget(self, STATE).world.studio end)
method("RunService", "IsServer", function() return true end)
method("RunService", "IsClient", function() return false end)
method("RunService", "IsRunning", function() return true end)
method("RunService", "IsRunMode", function() return false end)
method("RunService", "IsEdit", function() return false end)
method("RunService", "BindToRenderStep", function() end)
method("RunService", "UnbindFromRenderStep", function() end)
method("Workspace", "GetServerTimeNow", function(self)
	local world = rawget(self, STATE).world
	return world.epoch + world.clock
end)
method("Workspace", "Raycast", function() return nil end)
method("Workspace", "Blockcast", function() return nil end)
method("Workspace", "Spherecast", function() return nil end)
method("Workspace", "Shapecast", function() return nil end)
method("Workspace", "GetPartBoundsInRadius", function() return {} end)
method("Workspace", "GetPartBoundsInBox", function() return {} end)
method("Workspace", "GetPartsInPart", function() return {} end)
method("Workspace", "FindPartOnRay", function() return nil end)
method("Workspace", "FindPartOnRayWithIgnoreList", function() return nil end)
method("Workspace", "FindPartsInRegion3", function() return {} end)
method("Workspace", "ArePartsTouchingOthers", function() return false end)
method("Workspace", "GetRealPhysicsFPS", function() return 60 end)
method("CollectionService", "AddTag", function(_, inst, tag) inst:AddTag(tag) end)
method("CollectionService", "RemoveTag", function(_, inst, tag) inst:RemoveTag(tag) end)
method("CollectionService", "HasTag", function(_, inst, tag) return inst:HasTag(tag) end)
method("CollectionService", "GetTags", function(_, inst) return inst:GetTags() end)
method("CollectionService", "GetTagged", function(self, tag)
	local out = {}
	for inst in pairs(rawget(self, STATE).world.tags[tag] or {}) do table.insert(out, inst) end
	return out
end)
method("CollectionService", "GetInstanceAddedSignal", function(self, tag)
	return rawget(self, STATE).world:propertySignal(self, "TagAdded:" .. tag)
end)
method("CollectionService", "GetInstanceRemovedSignal", function(self, tag)
	return rawget(self, STATE).world:propertySignal(self, "TagRemoved:" .. tag)
end)
method("CollectionService", "GetAllTags", function(self)
	local out = {}
	for tag in pairs(rawget(self, STATE).world.tags) do table.insert(out, tag) end
	return out
end)
method("Debris", "AddItem", function(self, inst, seconds)
	rawget(self, STATE).world:delay(seconds or 10, function()
		if inst.Parent then inst:Destroy() end
	end)
end)
method("HttpService", "JSONEncode", function(_, value) return serde.encode("json", value) end)
method("HttpService", "JSONDecode", function(_, text) return serde.decode("json", text) end)
method("HttpService", "GenerateGUID", function(self, braces)
	local world = rawget(self, STATE).world
	world.guid = (world.guid or 0) + 1
	local id = string.format("00000000-0000-4000-8000-%012d", world.guid)
	return braces == false and id or ("{" .. id .. "}")
end)
method("HttpService", "UrlEncode", function(_, s) return (s:gsub("[^%w%-_%.~]", function(c) return string.format("%%%02X", string.byte(c)) end)) end)
method("HttpService", "PostAsync", function() error("HttpService is disabled in the harness", 2) end)
method("HttpService", "GetAsync", function() error("HttpService is disabled in the harness", 2) end)
method("HttpService", "RequestAsync", function() error("HttpService is disabled in the harness", 2) end)
method("TextService", "GetTextSize", function(_, text, size) return D.Vector2.new(#tostring(text) * size * 0.5, size) end)
method("TextService", "FilterStringAsync", function(_, text)
	return { GetNonChatStringForBroadcastAsync = function() return text end,
		GetChatForUserAsync = function() return text end,
		GetNonChatStringForUserAsync = function() return text end }
end)
method("PhysicsService", "RegisterCollisionGroup", function() end)
method("PhysicsService", "CollisionGroupSetCollidable", function() end)
method("PhysicsService", "IsCollisionGroupRegistered", function() return true end)
method("PhysicsService", "CreateCollisionGroup", function() end)
method("PhysicsService", "SetPartCollisionGroup", function() end)
method("PhysicsService", "GetRegisteredCollisionGroups", function() return {} end)
method("ContentProvider", "PreloadAsync", function() end)
method("MarketplaceService", "UserOwnsGamePassAsync", function() return false end)
method("MarketplaceService", "GetProductInfo", function() return {} end)
method("MarketplaceService", "PromptProductPurchase", function() end)
method("MarketplaceService", "PromptGamePassPurchase", function() end)
method("BadgeService", "AwardBadge", function() return true end)
method("BadgeService", "UserHasBadgeAsync", function() return false end)
method("MessagingService", "PublishAsync", function() end)
method("MessagingService", "SubscribeAsync", function() return { Disconnect = function() end } end)
method("PathfindingService", "CreatePath", function(self)
	local world = rawget(self, STATE).world
	return { ComputeAsync = function() end, Status = Enum.PathStatus.NoPath, GetWaypoints = function() return {} end,
		Blocked = world:newSignal("Blocked"), Destroy = function() end }
end)

-- TweenService: a tween lands its goal on Play (no test reads a half-way frame).
method("TweenService", "Create", function(self, inst, info, goal)
	local world = rawget(self, STATE).world
	local tween = { Instance = inst, TweenInfo = info, PlaybackState = Enum.PlaybackState.Begin,
		Completed = world:newSignal("Completed") }
	function tween.Play(t)
		for k, v in pairs(goal) do inst[k] = v end
		t.PlaybackState = Enum.PlaybackState.Completed
		world:defer(function() t.Completed:Fire(Enum.PlaybackState.Completed) end)
	end
	function tween.Cancel(t) t.PlaybackState = Enum.PlaybackState.Cancelled end
	function tween.Pause(t) t.PlaybackState = Enum.PlaybackState.Paused end
	function tween.Destroy() end
	return setmetatable(tween, { __type = "Instance" })
end)
method("TweenService", "GetValue", function(_, alpha) return alpha end)

-- DataStoreService: in-memory stores that behave like the real API (UpdateAsync's transform can
-- return nil to cancel; values are deep-copied through JSON so nothing aliases the caller's table).
-- A test seeds a profile with world:dataStore(name):Seed(key, value) and can make the next N calls
-- fail with :FailNext(n).
local function deepCopy(v)
	if v == nil then return nil end
	return serde.decode("json", serde.encode("json", v))
end
function World:dataStore(name, scope)
	self.dataStores = self.dataStores or {}
	local key = name .. "/" .. tostring(scope or "global")
	local store = self.dataStores[key]
	if store then return store end
	local world = self
	store = { Name = name, data = {}, calls = {}, fail = 0 }
	local function guard(op, k)
		table.insert(store.calls, { op = op, key = k })
		if store.fail > 0 then
			store.fail -= 1
			error("DataStore request failed (harness FailNext)", 3)
		end
	end
	function store.GetAsync(_, k) guard("Get", k) return deepCopy(store.data[k]) end
	function store.SetAsync(_, k, v) guard("Set", k) store.data[k] = deepCopy(v) end
	function store.RemoveAsync(_, k)
		guard("Remove", k)
		local old = store.data[k]
		store.data[k] = nil
		return deepCopy(old)
	end
	function store.IncrementAsync(_, k, delta)
		guard("Increment", k)
		store.data[k] = (store.data[k] or 0) + (delta or 1)
		return store.data[k]
	end
	function store.UpdateAsync(_, k, transform)
		guard("Update", k)
		local new = transform(deepCopy(store.data[k]))
		if new == nil then return deepCopy(store.data[k]) end
		store.data[k] = deepCopy(new)
		return deepCopy(new)
	end
	function store.GetSortedAsync()
		return { IsFinished = true, GetCurrentPage = function() return {} end, AdvanceToNextPageAsync = function() end }
	end
	function store:Seed(k, v) self.data[k] = deepCopy(v) end
	function store:Read(k) return deepCopy(self.data[k]) end
	function store:FailNext(n) self.fail = n or 1 end
	setmetatable(store, { __type = "Instance" })
	self.dataStores[key] = store
	return store
end
method("DataStoreService", "GetDataStore", function(self, name, scope)
	return rawget(self, STATE).world:dataStore(name, scope)
end)
method("DataStoreService", "GetOrderedDataStore", function(self, name, scope)
	return rawget(self, STATE).world:dataStore("ordered:" .. name, scope)
end)
method("DataStoreService", "GetGlobalDataStore", function(self)
	return rawget(self, STATE).world:dataStore("global")
end)
method("DataStoreService", "GetRequestBudgetForRequestType", function() return 100 end)

-- Services not listed anywhere above still exist; calling an unknown method on one is a no-op
-- returning nil (a service the code under test only touches in passing).
local LENIENT_SERVICES = { StarterGui = true, Lighting = true, SoundService = true, Chat = true,
	TextChatService = true, GuiService = true, LocalizationService = true, ProximityPromptService = true,
	InsertService = true, MemoryStoreService = true, AnalyticsService = true, PolicyService = true,
	TeleportService = true, UserInputService = true, ContextActionService = true, VRService = true,
	SocialService = true, Teams = true, AssetService = true, StarterPlayer = true, GroupService = true }

function World:service(name)
	local s = self.services[name]
	if s then return s end
	local className = name
	s = self:newInstance(className)
	rawget(s, STATE).props.Name = name
	rawget(s, STATE).isService = true
	self.services[name] = s
	if self.game then self:setParent(s, self.game) end
	if name == "Workspace" then
		local cam = self:newInstance("Camera", s)
		cam.Name = "Camera"
		rawget(s, STATE).props.CurrentCamera = cam
		local terrain = self:newInstance("Terrain", s)
		terrain.Name = "Terrain"
		rawget(s, STATE).props.Terrain = terrain
	end
	if LENIENT_SERVICES[name] then
		local st = rawget(s, STATE)
		local mt = getmetatable(s)
		-- lenient: unknown member reads that look like method calls become no-ops
		setmetatable(s, {
			__type = "Instance",
			__index = function(inst, key)
				local v = mt.__index(inst, key)
				if v == nil and type(key) == "string" and string.match(key, "^%u") and not st.props[key]
					and not DEFAULTS[name] then
					return function() return nil end
				end
				return v
			end,
			__newindex = mt.__newindex,
			__tostring = mt.__tostring,
		})
	end
	return s
end

-- ================================================================ globals and require
function World:buildGlobals()
	local world = self
	local G = {}
	G.math, G.string, G.table, G.coroutine, G.bit32, G.utf8 = math, string, table, coroutine, bit32, utf8
	G.gcinfo, G.newproxy = gcinfo, newproxy
	G.assert, G.error, G.getmetatable, G.ipairs, G.next, G.pairs, G.pcall = assert, error, getmetatable, ipairs, next, pairs, pcall
	G.rawequal, G.rawget, G.rawset, G.rawlen, G.select, G.setmetatable = rawequal, rawget, rawset, rawlen, select, setmetatable
	G.tonumber, G.tostring, G.type, G.unpack, G.xpcall = tonumber, tostring, type, table.unpack, xpcall
	G.buffer = buffer
	G.typeof = typeof
	for _, name in ipairs({ "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "NumberRange",
		"NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "TweenInfo", "Rect",
		"Ray", "RaycastParams", "OverlapParams", "PhysicalProperties", "Region3", "Faces", "Axes", "Font",
		"BrickColor", "DateTime", "Random", "Enum", "Vector3int16", "Vector2int16", "PathWaypoint" }) do
		G[name] = D[name]
	end
	G.print = function(...) world:log("print", joinArgs(...)) end
	G.warn = function(...) world:log("warn", joinArgs(...)) end
	G.os = {
		clock = function() return world.clock end,
		time = function(t) if t then return os.time(t) end return math.floor(world.epoch + world.clock) end,
		date = os.date, difftime = os.difftime,
	}
	G.tick = function() return world.epoch + world.clock end
	G.time = function() return world.clock end
	G.elapsedTime = G.time
	G.task = {
		spawn = function(f, ...) return world:spawn(f, ...) end,
		defer = function(f, ...) return world:defer(f, ...) end,
		delay = function(t, f, ...) return world:delay(t, f, ...) end,
		wait = function(t) return world:wait(t) end,
		cancel = function(thread) world:cancel(thread) end,
		synchronize = function() end,
		desynchronize = function() end,
	}
	G.wait = G.task.wait
	G.delay = G.task.delay
	G.spawn = G.task.defer
	G.debug = { traceback = debug.traceback, info = debug.info, profilebegin = function() end,
		profileend = function() end, setmemorycategory = function() end, resetmemorycategory = function() end }
	G.shared = world.shared
	G.settings = function() return setmetatable({}, { __index = function() return {} end }) end
	G.UserSettings = G.settings
	G.Instance = {
		new = function(className, parent) return world:newInstance(className, parent) end,
		fromExisting = function(inst) return inst:Clone() end,
	}
	self.globals = G
end

-- The environment one script runs in: its own table (script-level globals stay private, as in
-- Roblox) falling back to the shared globals.
function World:envFor(scriptInstance)
	local world = self
	local env = setmetatable({}, { __index = self.globals })
	env.script = scriptInstance
	env.game = self.game
	env.workspace = self.workspace
	env.Workspace = self.workspace
	env.require = function(target) return world:require(target) end
	env._G = env
	return env
end

-- Read and compile a source file. Must run on the main thread: Lune's fs yields to Lune's own
-- scheduler, which would strand a game coroutine, so the project mount compiles everything up front.
function World.compile(path)
	if not bytecodeCache[path] then
		bytecodeCache[path] = luau.compile(fs.readFile(path), { optimizationLevel = 2, debugLevel = 1 })
	end
	return bytecodeCache[path]
end

function World:chunkFor(scriptInstance)
	local st = rawget(scriptInstance, STATE)
	local path = st.source
	if not path then
		error(string.format("%s has no source file in the harness", scriptInstance:GetFullName()), 3)
	end
	local bytecode = bytecodeCache[path]
	if not bytecode then
		error(string.format("%s was not compiled at mount time (World.compile)", path), 3)
	end
	return luau.load(bytecode, { debugName = path, environment = self:envFor(scriptInstance),
		injectGlobals = false, codegenEnabled = true })
end

function World:require(target)
	if typeof(target) ~= "Instance" or not target:IsA("ModuleScript") then
		error("require: expected a ModuleScript, got " .. tostring(target), 3)
	end
	local entry = self.modules[target]
	if entry then
		if entry.state == "loading" then
			error("Cyclic require of " .. target:GetFullName(), 3)
		end
		return entry.value
	end
	local json = rawget(target, STATE).jsonValue
	if json ~= nil then
		self.modules[target] = { state = "done", value = json }
		return json
	end
	entry = { state = "loading" }
	self.modules[target] = entry
	local chunk = self:chunkFor(target)
	local results = table.pack(chunk())
	if results.n ~= 1 then
		self.modules[target] = nil
		error(string.format("Module %s returned %d values (must return exactly one)", target:GetFullName(), results.n), 3)
	end
	entry.state, entry.value = "done", results[1]
	return entry.value
end

-- Run a Script (server script) the way Roblox does: on its own thread.
function World:runScript(scriptInstance)
	local chunk = self:chunkFor(scriptInstance)
	return self:spawn(chunk)
end

-- Load a ModuleScript on a fresh thread and hand back what it returned (yields allowed inside).
function World:load(moduleScript)
	local result, done = nil, false
	self:spawn(function()
		result = self:require(moduleScript)
		done = true
	end)
	self:flush()
	if not done then
		error("require of " .. moduleScript:GetFullName() .. " did not finish (it yielded; advance the clock?)", 2)
	end
	return result
end

-- Look an Instance up by dotted path from the DataModel: world:find("ServerScriptService.SpinService").
function World:find(path)
	local node = self.game
	for part in string.gmatch(path, "[^%.]+") do
		local nextNode = self.services[part] and node == self.game and self.services[part] or node:FindFirstChild(part)
		if not nextNode then error("world:find: no " .. part .. " in " .. node:GetFullName(), 2) end
		node = nextNode
	end
	return node
end

-- What a RemoteEvent has sent to clients so far: { { kind, player, args } ... }.
function World:fired(remote)
	return self.remoteLog[remote] or {}
end

function World:clearFired(remote)
	self.remoteLog[remote] = nil
end

World.typeof = typeof
World.isA = isA
World.STATE = STATE

return World
