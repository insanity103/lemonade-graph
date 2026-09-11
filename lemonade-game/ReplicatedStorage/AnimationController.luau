-- ReplicatedStorage.AnimationController (Lemonade animation runtime v3)
-- Installed by Lemonade; replaced in place when a newer runtime ships.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationsFolder = ReplicatedStorage:WaitForChild("Animations")

-- Blend from whatever pose the joints are in (usually Roblox's idle or walk)
-- into the first frame, and back out to rest when a clip stops, so a clip
-- never snaps the character.
local FADE_IN = 0.1
local FADE_OUT = 0.15

-- Animations in this set play WITHOUT leg counter-rotation, because their leg
-- keyframes are intentional (kicks, sits, swims, etc.). Everything else gets the
-- counter-rotation applied to keep legs vertical when the torso rotates.
local SKIP_LEG_COUNTERROTATE = {
	["Leg Kick Animation"] = true,
	["Double Jump Backflip Animation"] = true,
	["Driving Steering Animation"] = true,
	["Flying Animation"] = true,
	["Gun Shooting Position Animation"] = true,
	["Injured Hurting Animation"] = true,
	["Injured Walk Animation"] = true,
	["Item Pickup Animation"] = true,
	["Level Up Celebration Animation"] = true,
	["Seating Animation"] = true,
	["Sliding Animation"] = true,
	["Sneak Walk Animation"] = true,
	["Spell Cast Fireball Animation"] = true,
	["Swimming Animation"] = true,
	["Zombie Walk Animation"] = true,
}

-- Internal class: drives Motor6D.Transform per frame, lerping between keyframes.
-- Only the joints a clip mentions are driven; every other joint stays with
-- Roblox's own animations (walk, jump, idle) for the whole clip.
local AnimationExecutor = {}
AnimationExecutor.__index = AnimationExecutor

function AnimationExecutor.new(character: Model)
	local self = setmetatable({}, AnimationExecutor)

	self.Character = character
	self.Joints = {}
	self.Connection = nil
	self.IsPlaying = false
	-- Parts the current clip writes, and parts easing back to rest after a
	-- clip stopped or a new clip took over without them.
	self.Driven = {}
	self.Releasing = {}
	self.ReleaseElapsed = 0

	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("Motor6D") and desc.Part1 then
			self.Joints[desc.Part1.Name] = desc
		elseif desc:IsA("AnimationConstraint") and desc.Attachment1 then
			local part = desc.Attachment1.Parent
			if part:IsA("BasePart") then
				self.Joints[part.Name] = desc
			end
		end
	end

	return self
end

function AnimationExecutor:Disconnect()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
end

-- Moves every driven part (and any part still easing out) into the release
-- set, starting from where it is now, so a stop or a clip switch never leaves
-- a joint frozen.
function AnimationExecutor:BeginRelease(keep)
	local releasing = {}
	for partName in pairs(self.Releasing) do
		if not keep[partName] then releasing[partName] = self.Joints[partName].Transform end
	end
	for partName in pairs(self.Driven) do
		if not keep[partName] then releasing[partName] = self.Joints[partName].Transform end
	end
	self.Releasing = releasing
	self.ReleaseElapsed = 0
	self.Driven = {}
end

-- One step of the ease back to rest; returns true while parts are still easing.
function AnimationExecutor:StepRelease(dt)
	if next(self.Releasing) == nil then return false end
	self.ReleaseElapsed += dt
	local alpha = math.min(1, self.ReleaseElapsed / FADE_OUT)
	for partName, start in pairs(self.Releasing) do
		self.Joints[partName].Transform = start:Lerp(CFrame.identity, alpha)
	end
	if alpha >= 1 then
		self.Releasing = {}
		return false
	end
	return true
end

function AnimationExecutor:Stop()
	if not self.IsPlaying then return end
	self.IsPlaying = false
	self:Disconnect()
	self:BeginRelease({})
	self.Connection = RunService.Stepped:Connect(function(_, dt)
		if not self:StepRelease(dt) then self:Disconnect() end
	end)
end

function AnimationExecutor:PlayFromTable(animTable, options)
	self:Disconnect()
	self.IsPlaying = true

	options = options or {}
	local counterRotateLegs = options.counterRotateLegs ~= false  -- default true

	local timestamps = {}
	for t, _ in pairs(animTable.Timestamps) do
		table.insert(timestamps, t)
	end
	table.sort(timestamps)

	local maxTime = timestamps[#timestamps]
	local isLooping = animTable.Settings.Loop

	-- Driven set: every part any frame mentions. Library clips are sparse
	-- (a frame may omit a part it drives elsewhere), so a missing part holds
	-- the last value this clip wrote for it.
	local driven = {}
	local startTransforms = {}
	for _, frame in pairs(animTable.Timestamps) do
		for partName in pairs(frame) do
			local joint = self.Joints[partName]
			if joint and not driven[partName] then
				driven[partName] = true
				startTransforms[partName] = joint.Transform
			end
		end
	end
	-- Parts the previous clip drove and this one does not ease back to rest.
	self:BeginRelease(driven)
	self.Driven = driven
	local last = {}

	local clipTime = 0
	local elapsed = 0

	self.Connection = RunService.Stepped:Connect(function(_, dt)
		if not self.IsPlaying then return end

		clipTime += dt
		elapsed += dt

		local ended = false
		if clipTime >= maxTime then
			if isLooping then
				clipTime %= maxTime
			else
				clipTime = maxTime
				ended = true
			end
		end

		local tStart, tEnd = timestamps[1], timestamps[#timestamps]
		for i = 1, #timestamps - 1 do
			if clipTime >= timestamps[i] and clipTime < timestamps[i+1] then
				tStart = timestamps[i]
				tEnd = timestamps[i+1]
				break
			end
		end

		local segmentDuration = tEnd - tStart
		local alpha = (segmentDuration > 0) and (clipTime - tStart) / segmentDuration or 0
		-- Blend in from the pose the joints had at Play; wall time, so a loop
		-- wrapping clipTime does not restart the blend.
		local fadeIn = math.min(1, elapsed / FADE_IN)

		local dataStart = animTable.Timestamps[tStart]
		local dataEnd = animTable.Timestamps[tEnd]

		for partName in pairs(self.Driven) do
			local joint = self.Joints[partName]
			local cfA = dataStart[partName] or last[partName] or startTransforms[partName]
			local cfB = dataEnd[partName] or cfA
			local target = cfA:Lerp(cfB, alpha)
			last[partName] = target
			if fadeIn < 1 then
				target = startTransforms[partName]:Lerp(target, fadeIn)
			end
			joint.Transform = target
		end

		self:StepRelease(dt)

		-- Counter-rotate legs against LowerTorso (only when caller asks for it)
		if counterRotateLegs then
			local lowerTorso = self.Joints["LowerTorso"]
			if lowerTorso then
				local lt = lowerTorso.Transform
				local invRot = (lt - lt.Position):Inverse()
				for _, legName in ipairs({"LeftUpperLeg", "RightUpperLeg"}) do
					local legJoint = self.Joints[legName]
					if legJoint then
						legJoint.Transform = invRot * legJoint.Transform
					end
				end
			end
		end

		if ended then self:Stop() end
	end)
end

-- Public API
local AnimationController = {}

local executor = nil
local currentCharacter = nil

local function ensureExecutor()
	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()

	-- Re-create the executor if the character changed (respawn, R6/R15 swap, etc.)
	if character ~= currentCharacter then
		currentCharacter = character
		executor = AnimationExecutor.new(character)
	end
	return executor
end

-- Reset on respawn so we don't reuse joints from the old character
Players.LocalPlayer.CharacterAdded:Connect(function()
	executor = nil
	currentCharacter = nil
end)

function AnimationController.Play(animationName)
	local animModule = AnimationsFolder:FindFirstChild(animationName)
	if not animModule then
		warn("AnimationController: no animation named", animationName)
		return
	end
	local exec = ensureExecutor()
	local animTable = require(animModule)
	if animTable.Rigs then
		local humanoid = exec.Character:WaitForChild("Humanoid")
		animTable = animTable.Rigs[humanoid.RigType.Name]
	end
	local skipLegFix = SKIP_LEG_COUNTERROTATE[animationName] == true
		or animTable.Settings.CounterRotateLegs == false
	exec:PlayFromTable(animTable, { counterRotateLegs = not skipLegFix })
end

function AnimationController.Stop()
	if executor then executor:Stop() end
end

return AnimationController
