--// WorldEventGui  (the running world event: a banner with its countdown, and its sky in its zone)
-- Reads workspace WorldEvent / WorldEventZone / WorldEventMult / WorldEventEnds (set by
-- ServerScriptService.WorldEvents) and Config.WorldEventConfig. The sky is a ColorCorrection of its
-- own, so it layers over ZoneAir / WorldLook instead of fighting them for the Lighting properties.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
local WorldEventConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WorldEventConfig"))

local player = Players.LocalPlayer
local BRIGHT = PanelChrome.BRIGHT

local gui = Instance.new("ScreenGui")
gui.Name = "WorldEventGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")

local banner = Instance.new("Frame")
banner.Name = "EventBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 64)
banner.Size = UDim2.fromOffset(440, 58)
banner.BackgroundColor3 = Color3.new(1, 1, 1)
banner.Visible = false
banner.Parent = gui
PanelChrome.corner(banner, 16)
PanelChrome.stroke(banner, BRIGHT.Outline, 3.5)
local bannerGrad = PanelChrome.gradient(banner, BRIGHT.Blue, Color3.fromRGB(30, 90, 200))
local title = PanelChrome.display(banner, { text = "", size = 24, stroke = 2.5, scaled = true,
	size2 = UDim2.new(1, -20, 0, 30), pos = UDim2.fromOffset(10, 4) })
local sub = PanelChrome.display(banner, { text = "", size = 16, stroke = 1.5, scaled = true,
	size2 = UDim2.new(1, -20, 0, 20), pos = UDim2.fromOffset(10, 34) })
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = banner
PanelChrome.onViewport(function(viewport)
	bannerScale.Scale = math.min(1, (viewport.X - 24) / 440)
end)

local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "WorldEventSky"
cc.Enabled = false
cc.Parent = Lighting
local skyTween = nil
local skyOn = false

local function setSky(event)
	local on = event ~= nil
	if on == skyOn and (not on or cc:GetAttribute("For") == event.id) then return end
	skyOn = on
	if skyTween then skyTween:Cancel() end
	if on then
		cc:SetAttribute("For", event.id)
		cc.Enabled = true
		cc.TintColor = Color3.new(1, 1, 1)
		cc.Brightness, cc.Saturation = 0, 0
		skyTween = TweenService:Create(cc, TweenInfo.new(2.5), {
			TintColor = Color3.new(1, 1, 1):Lerp(event.sky.atmosphere, 0.45),
			Brightness = event.sky.brightness * 0.12, Saturation = 0.1,
		})
	else
		skyTween = TweenService:Create(cc, TweenInfo.new(2.5), { TintColor = Color3.new(1, 1, 1), Brightness = 0, Saturation = 0 })
		skyTween.Completed:Once(function() if not skyOn then cc.Enabled = false end end)
	end
	skyTween:Play()
end

local function insideZone(zone: string): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local map = Workspace:FindFirstChild("LemonadeMap")
	local regions = map and map:FindFirstChild("Markers") and map.Markers:FindFirstChild("Regions")
	local volume = regions and regions:FindFirstChild(zone)
	if not root or not volume or not volume:IsA("BasePart") then return false end
	local p = volume.CFrame:PointToObjectSpace(root.Position)
	local half = volume.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

local accum = 0
RunService.Heartbeat:Connect(function(dt)
	accum += dt
	if accum < 0.25 then return end
	accum = 0
	local event = WorldEventConfig.ById[Workspace:GetAttribute("WorldEvent") or ""]
	if not event then
		banner.Visible = false
		setSky(nil)
		return
	end
	local left = math.max(0, (Workspace:GetAttribute("WorldEventEnds") or 0) - Workspace:GetServerTimeNow())
	local here = insideZone(event.zone)
	banner.Visible = true
	bannerGrad.Color = ColorSequence.new(event.sky.atmosphere:Lerp(Color3.new(1, 1, 1), 0.35), event.sky.atmosphere)
	title.Text = string.format("%s  %d:%02d", string.upper(event.name), left // 60, math.floor(left % 60))
	sub.Text = here and string.format("%dx tokens here!", Workspace:GetAttribute("WorldEventMult") or 1)
		or string.format("%dx tokens in %s", Workspace:GetAttribute("WorldEventMult") or 1,
			(event.zone:gsub("(%l)(%u)", "%1 %2")))
	setSky(here and event or nil)
end)
