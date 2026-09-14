-- StarterPlayerScripts/ComboVFX.client.luau
-- Visual feedback for the 5-hit combo system: screen shake, hit flash, combo burst
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local ComboConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ComboConfig"))

-- Screen shake state
local shakeOffset = CFrame.identity
local shakeEndTime = 0
local shakeIntensity = 0

-- Screen shake on hit — intensity scales with combo hit number
local function triggerShake(comboIndex)
    local duration = ComboConfig.HITLAG_DURATION[comboIndex] or 0.020
    shakeIntensity = 0.3 + (comboIndex * 0.15) -- [TUNING] scales with combo
    shakeEndTime = tick() + duration
end

-- Apply shake offset to camera each frame
RunService.RenderStepped:Connect(function()
    local now = tick()
    if now < shakeEndTime then
        local remaining = shakeEndTime - now
        local progress = 1 - (remaining / (shakeEndTime - (shakeEndTime - remaining)))
        local decay = math.clamp(remaining * 10, 0, 1)
        local offsetX = (math.random() - 0.5) * shakeIntensity * decay
        local offsetY = (math.random() - 0.5) * shakeIntensity * decay
        shakeOffset = CFrame.new(offsetX, offsetY, 0)
    else
        shakeOffset = CFrame.identity
    end
    camera.CFrame = camera.CFrame * shakeOffset
end)

-- Listen for hitlag events
local hitlagRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):FindFirstChild("HitlagEffect")
if hitlagRemote then
    hitlagRemote.OnClientEvent:Connect(function(duration, comboIndex)
        triggerShake(comboIndex or 1)
    end)
end

-- Listen for combo updates to trigger shake
local comboRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):FindFirstChild("ComboUpdate")
if comboRemote then
    comboRemote.OnClientEvent:Connect(function(count, endlag)
        triggerShake(count)
    end)
end

print("[ComboVFX] Screen shake and hitlag effects enabled")
