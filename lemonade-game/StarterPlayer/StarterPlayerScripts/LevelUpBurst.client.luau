local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LEVELUP_EVENT = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("LevelUpBurst")

local BALL_COUNT = 36
local BURST_DISTANCE = 5
local LIFETIME = 1.5
local BALL_RADIUS = 0.4

local function spawnBurst(origin)
	local camera = workspace.CurrentCamera
	local balls = {}

	for i = 1, BALL_COUNT do
		local ball = Instance.new("Part")
		ball.Name = "LevelUpBall"
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(BALL_RADIUS, BALL_RADIUS, BALL_RADIUS) * 2
		ball.Anchored = true
		ball.CanCollide = false
		ball.CastShadow = false
		ball.Material = Enum.Material.Neon
		ball.Color = Color3.fromHSV(math.random(), 1, 1)
		ball.Transparency = 0
		ball.CFrame = CFrame.new(origin)
		ball.Parent = workspace

		-- Random direction in a full sphere, biased slightly upward.
		local dir = Vector3.new(
			math.random() * 2 - 1,
			math.random() * 0.8 + 0.2,
			math.random() * 2 - 1
		).Unit
		local target = origin + dir * BURST_DISTANCE

		local tweenInfo = TweenInfo.new(
			LIFETIME * 0.6,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)
		local tween = TweenService:Create(ball, tweenInfo, { CFrame = CFrame.new(target) })
		tween:Play()

		table.insert(balls, ball)

		-- Fade out over the final portion of the lifetime, then remove.
		task.delay(LIFETIME * 0.6, function()
			if not ball.Parent then
				return
			end
			local fade = TweenService:Create(ball, TweenInfo.new(LIFETIME * 0.4), { Transparency = 1 })
			fade:Play()
		end)

		task.delay(LIFETIME, function()
			if ball.Parent then
				ball:Destroy()
			end
		end)
	end
end

LEVELUP_EVENT.OnClientEvent:Connect(function(origin)
	if origin and typeof(origin) == "Vector3" then
		spawnBurst(origin)
	end
end)

print("[LevelUpBurst] colored ball burst on level up enabled")
