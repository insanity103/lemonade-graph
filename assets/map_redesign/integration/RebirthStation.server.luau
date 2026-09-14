-- ServerScriptService. Conversation entry for the existing rebirth system.
-- Talking opens the menu; only its existing confirmation button requests rebirth.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local data = require(script.Parent:WaitForChild("MapAnchors"))
local map = Workspace:WaitForChild("FivefoldSanctuary", 30)
assert(map and map:GetAttribute("MapRedesignVersion") == data.Version, "Import and version the map first")
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local open = remotes:FindFirstChild("RebirthStationOpen")
if not open then
	open = Instance.new("RemoteEvent")
	open.Name, open.Parent = "RebirthStationOpen", remotes
end
assert(open:IsA("RemoteEvent"), "RebirthStationOpen must be a RemoteEvent")
assert(not map:FindFirstChild("RebirthInteraction"), "Rebirth interaction already installed")
local p = data.Hub.RebirthPromptPosition
local anchor = Instance.new("Part")
anchor.Name, anchor.Size = "RebirthInteraction", Vector3.one
anchor.Position = Vector3.new(p[1], p[2], p[3])
anchor.Anchored, anchor.Transparency = true, 1
anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
anchor.Parent = map
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "TalkToRebirthKeeper"
prompt.ActionText, prompt.ObjectText = "Talk", "Keeper of Renewal"
prompt.MaxActivationDistance = data.Hub.RebirthInteractionRadius -- [TUNING]: 12 studs
prompt.RequiresLineOfSight, prompt.HoldDuration = true, 0
prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
prompt.Parent = anchor
prompt.Triggered:Connect(function(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end
	if (root.Position - anchor.Position).Magnitude > prompt.MaxActivationDistance then return end
	open:FireClient(player)
end)
