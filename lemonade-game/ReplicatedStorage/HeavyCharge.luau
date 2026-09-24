-- HeavyCharge — the client's half of the charged heavy attack.
--
-- There was no heavy attack of any kind before this: `CombatController` bound one action, listened
-- for InputBegan only, and `Tool.Activated` was the single server entry, carrying no arguments.
-- This is the hold, the release and everything the player SEES of a charge. It owns no rule:
--
--   * how long the charge was, what it is worth, what it hits and how long it locks the player
--     out afterwards are all measured and decided by the server (ServerScriptService/SwordSystem
--     against ReplicatedStorage/Config/HeavyConfig),
--   * the two messages this sends carry no number at all -- "press" and "release" -- so a
--     modified client cannot claim a charge it did not hold,
--   * the charge level used below is this client's own stopwatch, and it picks a brightness, a
--     pitch and a bar width. Nothing else.
--
-- ── Why the binding is here and not on the Tool ─────────────────────────────────────────
-- `Tool.Activated` is a click: one event, no press and no release. A charge needs both edges, so
-- the heavy is bound through ContextActionService in CombatController (which already owns input)
-- and calls into this module. The light attack keeps its own path untouched.
--
-- ── Cost, per charge ────────────────────────────────────────────────────────────────────
-- One RenderStepped connection for as long as the button is down (~27 frames at a full 450 ms
-- charge). Each of those frames: one clamp, four Motor6D writes for the tremble and about six
-- property writes across the light, the two emitters and the bar. Two ParticleEmitters and one
-- PointLight exist for the life of the sword and are enabled only while charging. The release
-- costs exactly what any other swing costs: one clip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationController = require(ReplicatedStorage:WaitForChild("AnimationController"))
local ComboClock = require(ReplicatedStorage:WaitForChild("ComboClock"))
local SwingTrail = require(ReplicatedStorage:WaitForChild("SwingTrail"))
-- The world's half of contact: the spark burst the light chain already uses, and the ground
-- burst the finisher's slam uses, which the heavy's follow-through now earns as well.
local SwingImpact = require(ReplicatedStorage:WaitForChild("SwingImpact"))
local SwingTiming = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwingTiming"))
local HeavyConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("HeavyConfig"))
-- The upper/lower split, so a charge held at a run and a heavy thrown at a run keep the run: the
-- clips drive both legs and would otherwise pin them mid-stride while the character travelled.
local SwingMove = require(ReplicatedStorage:WaitForChild("SwingMove"))

local HEAVY = SwingTiming.HEAVY

local HeavyCharge = {}

local charging = false
local startedAt = 0
local chargedTool: Tool? = nil
local fullAnnounced = false
local cueConnection: RBXScriptConnection? = nil
local swingId = 0

local LEMON = Color3.fromRGB(255, 208, 74)
local WHITE = Color3.fromRGB(255, 255, 255)

local remote: RemoteEvent? = nil
if RunService:IsClient() then
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("RemoteEvents", 30)
		remote = remotes and remotes:WaitForChild("HeavyAttack", 30)
	end)
end

local function tell(action: string)
	if remote then
		remote:FireServer(action)
	end
end

local function localCharacter(): Model?
	local player = Players.LocalPlayer
	return player and player.Character or nil
end

local function heldTool(): Tool?
	local character = localCharacter()
	return character and character:FindFirstChildOfClass("Tool") or nil
end

-- ── The cues ────────────────────────────────────────────────────────────────────────────
-- Lemonade, not Deepwoken: the blade gathers warm light and throws lemon sparks, and the ground
-- under the character answers with motes rising round the feet. No grey wind rings, no smoke.
-- All three are built once per sword and per character and only ever enabled or disabled.

local function bladeCues(tool: Tool)
	local handle = tool:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then
		return nil, nil
	end
	local light = handle:FindFirstChild("HeavyChargeLight")
	local motes = handle:FindFirstChild("HeavyChargeMotes")
	if not (light and light:IsA("PointLight")) then
		if light then light:Destroy() end
		local made = Instance.new("PointLight")
		made.Name = "HeavyChargeLight"
		made.Color = LEMON
		made.Brightness = 0
		made.Range = 6
		made.Shadows = false
		made.Enabled = false
		made.Parent = handle
		light = made
	end
	if not (motes and motes:IsA("ParticleEmitter")) then
		if motes then motes:Destroy() end
		local made = Instance.new("ParticleEmitter")
		made.Name = "HeavyChargeMotes"
		-- Up the blade: the handle's -Z, three quarters of the way to the tip.
		made.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, WHITE),
			ColorSequenceKeypoint.new(1, LEMON),
		})
		made.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.26),
			NumberSequenceKeypoint.new(1, 0),
		})
		made.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		made.Lifetime = NumberRange.new(0.22, 0.40)
		made.Speed = NumberRange.new(1.5, 4)
		made.SpreadAngle = Vector2.new(40, 40)
		made.EmissionDirection = Enum.NormalId.Back -- along the blade, away from the hand
		made.Rate = 0
		made.LightEmission = 1
		made.LightInfluence = 0
		made.Drag = 4
		made.Enabled = false
		made.Parent = handle
		motes = made
	end
	return light :: PointLight, motes :: ParticleEmitter
end

local function gatherCue(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local gather = root:FindFirstChild("HeavyChargeGather")
	if gather and gather:IsA("ParticleEmitter") then
		return gather :: ParticleEmitter
	end
	if gather then gather:Destroy() end
	local made = Instance.new("ParticleEmitter")
	made.Name = "HeavyChargeGather"
	made.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, LEMON),
		ColorSequenceKeypoint.new(1, WHITE),
	})
	made.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.34),
		NumberSequenceKeypoint.new(1, 0),
	})
	made.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	made.Lifetime = NumberRange.new(0.45, 0.75)
	made.Speed = NumberRange.new(5, 9)
	made.SpreadAngle = Vector2.new(22, 22)
	made.EmissionDirection = Enum.NormalId.Top
	made.Rate = 0
	made.LightEmission = 0.8
	made.LightInfluence = 0
	made.Drag = 2.4
	made.Acceleration = Vector3.new(0, -6, 0)
	made.Enabled = false
	made.Parent = root
	return made
end

-- The bar. Deliberately small and deliberately nowhere near the panels the GUI gauntlet settled:
-- a 190x7 sliver under the middle of the screen that is invisible unless the button is down.
local meterGui: ScreenGui? = nil
local meterFill: Frame? = nil

local function meter()
	if meterGui and meterGui.Parent then
		return meterGui, meterFill
	end
	local player = Players.LocalPlayer
	local parent = player and player:FindFirstChildOfClass("PlayerGui")
	if not parent then
		return nil, nil
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "HeavyChargeGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 12
	gui.Enabled = false

	local track = Instance.new("Frame")
	track.Size = UDim2.fromOffset(190, 7)
	track.Position = UDim2.new(0.5, 0, 0.64, 0)
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.BackgroundColor3 = Color3.fromRGB(28, 24, 16)
	track.BackgroundTransparency = 0.35
	track.BorderSizePixel = 0
	track.Parent = gui
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = LEMON
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	gui.Parent = parent
	meterGui, meterFill = gui, fill
	return gui, fill
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- The charge this client believes it is holding, 0 at HeavyConfig.MIN_CHARGE and 1 at
-- FULL_CHARGE. The server measures its own; this one only decides how bright things are.
local function chargeAt(now: number): number
	local held = now - startedAt
	local span = HeavyConfig.FULL_CHARGE - HeavyConfig.MIN_CHARGE
	if span <= 0 then
		return 1
	end
	return math.clamp((held - HeavyConfig.MIN_CHARGE) / span, 0, 1)
end

local TREMBLE_JOINTS = { "UpperTorso", "RightLowerArm", "RightHand", "Head" }

local function stopCues()
	if cueConnection then
		cueConnection:Disconnect()
		cueConnection = nil
	end
	if chargedTool and chargedTool.Parent then
		local light, motes = bladeCues(chargedTool)
		if light then
			light.Enabled = false
			light.Brightness = 0
		end
		if motes then
			motes.Enabled = false
			motes.Rate = 0
		end
	end
	local character = localCharacter()
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local gather = root and root:FindFirstChild("HeavyChargeGather")
	if gather and gather:IsA("ParticleEmitter") then
		gather.Enabled = false
		gather.Rate = 0
	end
	local gui = meterGui
	if gui and gui.Parent then
		gui.Enabled = false
	end
end

local function startCues(tool: Tool, character: Model)
	local light, motes = bladeCues(tool)
	local gather = gatherCue(character)
	local gui, fill = meter()
	if light then light.Enabled = true end
	if motes then motes.Enabled = true end
	if gather then gather.Enabled = true end
	if gui then gui.Enabled = true end

	-- Indexed by the part each Motor6D DRIVES (its Part1), which is how AnimationController
	-- finds the same joints; where the joint is parented differs between rigs and does not
	-- matter. A joint that is not there is simply not trembled.
	local byPart = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") and descendant.Part1 then
			byPart[descendant.Part1.Name] = descendant
		end
	end
	local joints = {}
	for _, name in ipairs(TREMBLE_JOINTS) do
		if byPart[name] then
			table.insert(joints, byPart[name])
		end
	end

	-- After AnimationController's Stepped pass has written the clip for this frame, so the
	-- tremble is laid ON the charge pose rather than fighting it.
	cueConnection = RunService.PreRender:Connect(function()
		if not charging then
			return
		end
		local now = os.clock()
		local t = chargeAt(now)
		if light then
			light.Brightness = HeavyConfig.CUE_LIGHT_BRIGHTNESS * t
			light.Range = lerp(6, HeavyConfig.CUE_LIGHT_RANGE, t)
			light.Color = LEMON:Lerp(WHITE, t * 0.7)
		end
		if motes then
			motes.Rate = HeavyConfig.CUE_BLADE_RATE * t
		end
		if gather then
			gather.Rate = HeavyConfig.CUE_GATHER_RATE * t
		end
		if fill then
			fill.Size = UDim2.fromScale(t, 1)
			fill.BackgroundColor3 = LEMON:Lerp(WHITE, t * t)
		end
		-- The strain. Two frequencies so it does not read as a clean vibration, and scaled by
		-- the charge so the body is steady at the start and fighting itself at the end.
		local amp = math.rad(HeavyConfig.CUE_TREMBLE_DEG) * t
		local a = math.sin(now * 107) * amp
		local b = math.sin(now * 61 + 1.7) * amp * 0.8
		for index, motor in ipairs(joints) do
			if motor.Parent then
				local sign = if index % 2 == 0 then -1 else 1
				motor.Transform = motor.Transform * CFrame.Angles(a * sign, b * sign, b * 0.5)
			end
		end
		if t >= 1 and not fullAnnounced then
			fullAnnounced = true
			local handle = tool:FindFirstChild("Handle")
			local ready = handle and handle:FindFirstChild("SwordLunge")
			if ready and ready:IsA("Sound") then
				ready.PlaybackSpeed = 1.55
				ready:Play()
			end
			if motes then
				motes:Emit(18)
			end
		end
	end)
end

-- ── The three edges ─────────────────────────────────────────────────────────────────────

function HeavyCharge.charging(): boolean
	return charging
end

-- Button down. Returns true if a charge actually started, so the caller can fall through to
-- something else when it did not.
function HeavyCharge.press(): boolean
	if charging then
		return true
	end
	local character = localCharacter()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and humanoid) or humanoid.Health <= 0 then
		return false
	end
	local tool = heldTool()
	if not tool then
		return false -- the unarmed path has no heavy; the server refuses one too
	end
	-- The client's own copy of the server's endlag rule, the same one the M1 is gated on: a
	-- charge begun inside endlag would draw a pose for a swing the server is going to drop.
	if not ComboClock.ready(tick()) then
		return false
	end

	charging = true
	startedAt = os.clock()
	chargedTool = tool
	fullAnnounced = false
	tell("press")
	-- No plant in the charge's mask: a charge is a held pose, not a strike, so the legs stay the
	-- run cycle for as long as the button is down and only the loaded upper body is the clip's.
	AnimationController.Play(HEAVY.CHARGE_CLIP, { moveBlend = SwingMove.charge() })
	startCues(tool, character)
	return true
end

-- Button up. The swing.
function HeavyCharge.release()
	if not charging then
		return
	end
	local tool = chargedTool
	charging = false
	stopCues()
	tell("release")

	local held = os.clock() - startedAt
	swingId += 1
	local mySwing = swingId

	-- Released before the body finished loading: the server gives this a weak swing on the light
	-- M1's own clip, so the picture is the light M1's clip too. It is a fumble, and it is
	-- supposed to look like one.
	local slipped = held < HeavyConfig.MIN_CHARGE
	local charge = chargeAt(os.clock())
	local timing = if slipped then SwingTiming.HITS[1] else HEAVY
	local clipName = if slipped then SwingTiming.HITS[1].CLIP else HEAVY.CLIP
	local endlag = if slipped
		then HeavyConfig.SLIP_ENDLAG
		else lerp(HeavyConfig.ENDLAG[1], HeavyConfig.ENDLAG[2], charge)
	-- The heavy is not a member of the chain: it resets the counter and books its own endlag, so
	-- the next M1 is hit 1 and cannot be thrown early. The server's ComboUpdate corrects both.
	ComboClock.spend(endlag)

	local handle = tool and tool:FindFirstChild("Handle")
	AnimationController.Play(clipName, {
		-- A slip falls back to the light M1's clip, so it takes the light M1's plant window too.
		moveBlend = if slipped then SwingMove.forHit(1) else SwingMove.heavy(),
		onMarker = function(marker)
			if marker == "Swing" then
				-- SwordLunge, not SwordSlash: a lower, longer note for a heavier swing, pitched
				-- down further the more of it was charged. (It has existed since the sword was
				-- built and nothing has ever played it.)
				local whoosh = handle and handle:FindFirstChild(if slipped then "SwordSlash" else "SwordLunge")
				if whoosh and whoosh:IsA("Sound") then
					whoosh.PlaybackSpeed = if slipped then 1.08 else lerp(0.80, 0.62, charge)
					whoosh:Play()
				end
				-- A charged heavy gets the LONG ribbon (SwingTrail.BIG_SPAN), the one the
				-- finisher gets and for the same reason: the pass through the target is a
				-- single 27 ms frame across 11.7 studs, and the narrow streak that suits a
				-- 250 ms light swing leaves no line behind it at all at that speed. A slip
				-- is a light swing and keeps the light swing's streak.
				SwingTrail.light(tool, timing.SWING_END - timing.WINDUP, not slipped)
			elseif marker == "Plow" then
				-- THE GROUND ANSWERS. The heavy's follow-through drives the tip down to a
				-- height of -3.0 in root space -- the floor -- out past the left hip, so the
				-- frame it gets there throws the finisher's ground burst, scaled by how much
				-- of the charge was actually paid for. The burst is placed on the floor under
				-- the tip rather than at the tip, for the reason SwordClient gives for the
				-- slam: the root sits a known three studs above the feet, and a raycast on
				-- every client on every heavy to learn something already known is wasted.
				if mySwing == swingId and not slipped then
					local character = tool and tool.Parent
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						local tip = SwingTrail.tip(tool)
							or (root.CFrame * CFrame.new(-3.0, 0, -3.0)).Position
						SwingImpact.slam(
							CFrame.new(tip.X, root.Position.Y - 3.0, tip.Z),
							lerp(0.55, 1.0, charge))
					end
				end
			elseif marker == "ArcEnd" then
				if mySwing == swingId then
					SwingTrail.out(tool)
				end
			end
		end,
	})

	-- Safety net, exactly as the light swing has: a clip cut short by a respawn or by the next
	-- swing never reaches "ArcEnd", and a ribbon left lit would trail behind the idle sword.
	task.delay(timing.RECOVERY_END, function()
		if mySwing == swingId and SwingTrail.lit(tool) then
			SwingTrail.out(tool)
		end
	end)
end

-- Abandon a charge without swinging: death, respawn, putting the sword away, or something else
-- taking the body over. The server is told so it does not keep a charge open.
function HeavyCharge.cancel()
	if not charging then
		return
	end
	charging = false
	stopCues()
	tell("cancel")
	AnimationController.Stop()
end

if RunService:IsClient() then
	local player = Players.LocalPlayer
	if player then
		player.CharacterRemoving:Connect(function()
			HeavyCharge.cancel()
			chargedTool = nil
		end)
		player.CharacterAdded:Connect(function(character)
			chargedTool = nil
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid then
				humanoid.Died:Connect(function()
					HeavyCharge.cancel()
				end)
			end
		end)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Died:Connect(function()
				HeavyCharge.cancel()
			end)
		end
	end
end

return HeavyCharge
