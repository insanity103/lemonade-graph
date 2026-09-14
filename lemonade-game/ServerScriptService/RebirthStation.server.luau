-- Conversation entry for the existing rebirth system, at the hub's rebirth pavilion.
-- Talking opens the menu on its Rebirth tab; only that panel's existing confirm button
-- requests a rebirth, so RebirthSystem keeps sole authority over requirements.
--
-- Adapted from assets/map_redesign/integration/RebirthStation.server.luau: the
-- delivered version asserts the imported map exists. In the live tree that would throw
-- on every server start until the GLBs are imported, so this waits and then stands
-- down quietly. Import the map and restart to activate it.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLayout = require(script.Parent:WaitForChild("WorldLayout"))
local MapAnchors = require(script.Parent:WaitForChild("MapAnchors"))

local map = Workspace:WaitForChild(WorldLayout.MAP_MODEL_NAME, 20)
if not map or map:GetAttribute("MapRedesignVersion") ~= MapAnchors.Version then
	print("[RebirthStation] Imported map not present; rebirth prompt idle (menu button still works)")
	return
end
if map:FindFirstChild("RebirthInteraction") then
	warn("[RebirthStation] Interaction already installed; not adding a second prompt")
	return
end

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local open = remotes:FindFirstChild("RebirthStationOpen")
if not open then
	open = Instance.new("RemoteEvent")
	open.Name = "RebirthStationOpen"
	open.Parent = remotes
end
assert(open:IsA("RemoteEvent"), "RebirthStationOpen must be a RemoteEvent")

local promptPosition = MapAnchors.Hub.RebirthPromptPosition
local anchor = Instance.new("Part")
anchor.Name = "RebirthInteraction"
anchor.Size = Vector3.one
anchor.Position = Vector3.new(promptPosition[1], promptPosition[2], promptPosition[3])
anchor.Anchored = true
anchor.Transparency = 1
anchor.CanCollide = false
anchor.CanQuery = false
anchor.CanTouch = false
anchor.Parent = map

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "TalkToRebirthKeeper"
prompt.ActionText = "Talk"
prompt.ObjectText = "Keeper of Renewal"
prompt.MaxActivationDistance = MapAnchors.Hub.RebirthInteractionRadius -- [TUNING]: 12 studs
prompt.RequiresLineOfSight = true
prompt.HoldDuration = 0
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
prompt.Parent = anchor

prompt.Triggered:Connect(function(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end
	-- Server-side distance check: the prompt's own range is a client convenience.
	if (root.Position - anchor.Position).Magnitude > prompt.MaxActivationDistance then return end
	open:FireClient(player)
end)

print("[RebirthStation] Keeper of Renewal prompt online")
