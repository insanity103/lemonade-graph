--// SwordPreview  (a client-side stand-in Tool that looks like a real sword, for 3D icons)
-- A sword the player holds is its own best icon: PanelChrome.renderTool draws the Tool itself.
-- A sword the player does NOT hold -- a spin board's pool, a vault entry -- has no Tool on the
-- client, and the models live in ServerStorage where no client can reach them. RuntimeBootstrap
-- publishes a copy of every sword MeshPart to ReplicatedStorage/SwordMeshes; this builds a Tool
-- whose Handle is that mesh, fitted the way BossSwordFactory.fitLook fits a real sword (the look's
-- mesh or the shared template, its length, its colour, the texture stripped where the factory strips
-- it). Returns nil when there is nothing to draw -- a "Blocks" look, or the library has not
-- replicated -- and the caller keeps its own block stand-in.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossWeapons = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BossWeapons"))

local SwordPreview = {}

local DEFAULT_LENGTH = 4.2 -- BossSwordFactory.DEFAULT_SWORD_LENGTH

local function library(): Folder?
	local f = ReplicatedStorage:FindFirstChild("SwordMeshes")
	return if f and f:IsA("Folder") then f else nil
end

function SwordPreview.fromLook(look): Tool?
	look = look or BossWeapons.Fallback.look
	local lib = library()
	local wanted = look.mesh or "Template"
	if not lib or wanted == "Blocks" then
		return nil
	end
	local mesh = lib:FindFirstChild(wanted)
	-- not imported yet: the shared template stands in, and (as in fitLook) without its painted
	-- texture, which would hide the colour this sword is built on
	local fellBack = false
	if not (mesh and mesh:IsA("MeshPart")) then
		mesh = lib:FindFirstChild("Template")
		fellBack = true
	end
	if not (mesh and mesh:IsA("MeshPart")) then
		return nil
	end
	local handle = mesh:Clone()
	handle.Name = "Handle"
	local length = look.length or DEFAULT_LENGTH
	local ms = handle.MeshSize
	if ms.Z > 0 then
		handle.Size = ms * (length / ms.Z)
	end
	if look.textured == false or fellBack then
		handle.TextureID = ""
	end
	if look.color then
		handle.Color = look.color
	end
	-- every sword draws as matte plastic in the hand (CombatUtil.applyWeaponAppearance)
	handle.Material = Enum.Material.SmoothPlastic
	for _, child in ipairs(handle:GetChildren()) do
		if child:IsA("SurfaceAppearance") then
			local ok, colorMap = pcall(function() return (child :: any).ColorMap end)
			if not (ok and typeof(colorMap) == "string" and colorMap ~= "") then
				child:Destroy()
			end
		end
	end
	local tool = Instance.new("Tool")
	tool.Name = "SwordPreview"
	handle.Parent = tool
	return tool
end

-- The sword named `name`, looked up in `poolKey`'s pool first and then everywhere.
function SwordPreview.forSword(name: string?, poolKey: string?): Tool?
	if typeof(name) ~= "string" or name == "" then
		return nil
	end
	local def = poolKey and BossWeapons.FindSword(name, poolKey) or nil
	def = def or BossWeapons.FindSword(name)
	return if def then SwordPreview.fromLook(def.look) else nil
end

return SwordPreview
