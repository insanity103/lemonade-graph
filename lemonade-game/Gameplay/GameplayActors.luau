-- ModuleScript | ServerScriptService.GameplayActors | Plain interaction characters, no scenery.
local Actors = {}
function Actors.create(name: string, position: Vector3, color: Color3): Model
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
	model.Parent = workspace
	return model
end
function Actors.prompt(model: Model, action: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = action, model.Name
	prompt.MaxActivationDistance = 12 -- [TUNING] Same interaction range as existing services.
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	return prompt
end
return Actors
