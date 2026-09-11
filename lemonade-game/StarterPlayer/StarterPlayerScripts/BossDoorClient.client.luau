--// BossDoorClient  (tints boss-room doors for this player's level and explains a locked door)
-- Purely visual/feedback: BossRoomGate on the server decides who can actually pass.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local NOTICE = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("BossDoorNotice")
local ROOMS = Workspace:WaitForChild("BossRooms")

local OPEN_COLOR = Color3.fromRGB(95, 225, 125)
local LOCKED_COLOR = Color3.fromRGB(235, 75, 75)

local function getLevel()
	local ls = player:FindFirstChild("leaderstats")
	local lv = ls and ls:FindFirstChild("Level")
	return (lv and lv.Value) or player:GetAttribute("Level") or 1
end

-- toast
local gui = Instance.new("ScreenGui")
gui.Name = "BossDoorNotice"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0.14, 0)
label.Size = UDim2.fromOffset(560, 44)
label.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
label.BackgroundTransparency = 0.2
label.Font = Enum.Font.GothamBold
label.TextSize = 18
label.TextColor3 = LOCKED_COLOR
label.Visible = false
label.Parent = gui
Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)

local hideToken = 0
local function show(text)
	hideToken += 1
	local token = hideToken
	label.Text = text
	label.Visible = true
	task.delay(3, function()
		if hideToken == token then label.Visible = false end
	end)
end

local doors = {}  -- [door] = { name, required }

local function paint(door, info)
	local open = getLevel() >= info.required
	local sign = door:FindFirstChild("Sign")
	local tl = sign and sign:FindFirstChild("Label")
	if tl then
		tl.Text = string.format("%s\n%s Level %d+", string.upper(info.name), open and "OPEN -" or "LOCKED -", info.required)
		tl.TextColor3 = open and OPEN_COLOR or LOCKED_COLOR
	end
end

local lastWarn = 0
local function track(door)
	if doors[door] or door.Name ~= "Door" then return end
	local model = door.Parent
	local info = {
		name = (model and model:GetAttribute("DisplayName")) or (model and model.Name) or "Boss Room",
		required = door:GetAttribute("RequiredLevel") or 1,
	}
	doors[door] = info
	paint(door, info)
	door.Touched:Connect(function(hit)
		local character = player.Character
		if not character or not hit:IsDescendantOf(character) then return end
		local level = getLevel()
		if level < info.required and os.clock() - lastWarn > 2 then
			lastWarn = os.clock()
			show(string.format("LOCKED: %s needs Level %d (you are Level %d)", info.name, info.required, level))
		end
	end)
end

local function repaintAll()
	for door, info in pairs(doors) do paint(door, info) end
end

for _, d in ipairs(ROOMS:GetDescendants()) do
	if d:IsA("BasePart") then track(d) end
end
ROOMS.DescendantAdded:Connect(function(d)
	if d:IsA("BasePart") then track(d) end
end)

player:GetAttributeChangedSignal("Level"):Connect(repaintAll)
task.spawn(function()
	local ls = player:WaitForChild("leaderstats", 30)
	local lv = ls and ls:WaitForChild("Level", 30)
	if lv then lv.Changed:Connect(repaintAll); repaintAll() end
end)

NOTICE.OnClientEvent:Connect(function(roomName, required)
	show(string.format("Moved out of %s: it requires Level %d", tostring(roomName), required or 0))
end)
