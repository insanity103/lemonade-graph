-- ModuleScript | ServerScriptService.GameplayActors | Plain interaction characters, no scenery.
local Actors = {}

local function nameplate(head: BasePart, title: string, subtitle: string?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(180, subtitle and 40 or 24)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	gui.MaxDistance = 70 -- [TUNING] Readable across the hub courtyard, hidden beyond it.
	gui.AlwaysOnTop = false
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 22)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(255, 232, 170)
	label.TextStrokeTransparency = 0.3
	label.Text = title
	label.Parent = gui
	if subtitle then
		local sub = label:Clone()
		sub.Position = UDim2.fromOffset(0, 20)
		sub.Size = UDim2.new(1, 0, 0, 16)
		sub.Font = Enum.Font.Gotham
		sub.TextSize = 12
		sub.TextColor3 = Color3.fromRGB(215, 215, 225)
		sub.Text = subtitle
		sub.Parent = gui
	end
end

-- options.facing: CFrame whose rotation the character adopts (map markers supply one).
-- options.title / options.subtitle: nameplate text; title defaults to the model name.
function Actors.create(name: string, position: Vector3, color: Color3, options: {}?): Model
	options = options or {}
	local model = Instance.new("Model")
	model.Name = name
	local pieces = {
		{"HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0)},
		{"Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0)},
		{"Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0)},
		{"Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0)},
		{"Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0)},
		{"Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0)},
		{"Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0)},
	}
	for _, spec in ipairs(pieces) do
		local part = Instance.new("Part")
		part.Name, part.Size, part.Position = spec[1], spec[2], position + spec[3]
		part.Anchored, part.CanCollide = true, false
		part.Material, part.Color = Enum.Material.SmoothPlastic, color
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Parent = model
		if part.Name == "HumanoidRootPart" then
			part.Transparency = 1
			model.PrimaryPart = part
		end
	end
	if options.facing then
		model:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)) * options.facing.Rotation)
	end
	nameplate(model:FindFirstChild("Head"), options.title or name, options.subtitle)
	model.Parent = workspace
	return model
end
function Actors.prompt(model: Model, action: string, objectText: string?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = action, objectText or model.Name
	prompt.MaxActivationDistance = 12 -- [TUNING] Same interaction range as existing services.
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	return prompt
end
return Actors
