-- LocalScript | StarterPlayerScripts.SwordHotbarGui | Single-slot hotbar for the equipped sword.
-- Replaces Roblox's default backpack strip (hidden here): one bottom-centre slot renders the
-- sword that's currently in the character's hands, and hovering it opens a tooltip with the
-- sword's full stat sheet. Switching swords happens from the Inventory panel's EQUIP buttons
-- (MainMenuGui), which call Humanoid:EquipTool the same way the default backpack does.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
local SwordValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwordValue"))
local WeaponModifiers = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponModifiers"))

local COLORS = PanelChrome.COLORS
local RARITY_COLORS = PanelChrome.RARITY_COLORS
local BLESSED_GOLD = Color3.fromRGB(255, 215, 0)

-- The default strip is the only thing this replaces; CoreGui can lag behind PlayerGui on join.
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok then return end
		task.wait(0.5)
	end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SwordHotbarGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 12
screenGui.Parent = playerGui

local SLOT_SIZE = 72

-- ── Slot ─────────────────────────────────────────────────────────────────────
local slot = Instance.new("TextButton")
slot.Name = "Slot"
slot.AnchorPoint = Vector2.new(0.5, 1)
slot.Position = UDim2.new(0.5, 0, 1, -16)
slot.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
slot.BackgroundColor3 = COLORS.Panel
slot.BackgroundTransparency = 0.06
slot.BorderSizePixel = 0
slot.Text = ""
slot.AutoButtonColor = false
slot.Parent = screenGui
PanelChrome.corner(slot, 12)

local slotStroke = Instance.new("UIStroke")
slotStroke.Color = COLORS.Stroke
slotStroke.Thickness = 2
slotStroke.Parent = slot

-- Outer gold halo, shown only for Blessed swords (mirrors the Inventory card treatment).
local halo = Instance.new("Frame")
halo.Name = "BlessedHalo"
halo.Size = UDim2.new(1, 8, 1, 8)
halo.Position = UDim2.fromOffset(-4, -4)
halo.BackgroundTransparency = 1
halo.Visible = false
halo.ZIndex = 0
halo.Parent = slot
PanelChrome.corner(halo, 15)
local haloStroke = Instance.new("UIStroke")
haloStroke.Color = BLESSED_GOLD
haloStroke.Thickness = 2
haloStroke.Transparency = 0.15
haloStroke.Parent = halo

-- 3D preview of the equipped tool: its parts are cloned into a WorldModel and framed by a
-- camera looking at their bounding box, so every sword renders at the same apparent size.
local viewport = Instance.new("ViewportFrame")
viewport.Name = "Preview"
viewport.Size = UDim2.new(1, -8, 1, -8)
viewport.Position = UDim2.fromOffset(4, 4)
viewport.BackgroundTransparency = 1
viewport.Ambient = Color3.fromRGB(180, 180, 190)
viewport.LightColor = Color3.fromRGB(255, 250, 235)
viewport.LightDirection = Vector3.new(-1, -1.2, -0.6)
viewport.ZIndex = 2
viewport.Parent = slot

local worldModel = Instance.new("WorldModel")
worldModel.Parent = viewport

local previewCamera = Instance.new("Camera")
previewCamera.Parent = viewport
viewport.CurrentCamera = previewCamera

local emptyLabel = Instance.new("TextLabel")
emptyLabel.Name = "Empty"
emptyLabel.Size = UDim2.fromScale(1, 1)
emptyLabel.BackgroundTransparency = 1
emptyLabel.Font = Enum.Font.Gotham
emptyLabel.TextSize = 11
emptyLabel.TextColor3 = COLORS.Muted
emptyLabel.TextWrapped = true
emptyLabel.Text = "No sword\nequipped"
emptyLabel.ZIndex = 3
emptyLabel.Parent = slot

-- Rarity-tinted name pill under the slot.
local nameLabel = Instance.new("TextLabel")
nameLabel.Name = "SwordName"
nameLabel.AnchorPoint = Vector2.new(0.5, 0)
nameLabel.Position = UDim2.new(0.5, 0, 1, 6)
nameLabel.Size = UDim2.fromOffset(240, 18)
nameLabel.BackgroundTransparency = 1
nameLabel.Font = Enum.Font.GothamBold
nameLabel.TextSize = 12
nameLabel.TextColor3 = COLORS.Text
nameLabel.TextStrokeTransparency = 0.4
nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
nameLabel.ZIndex = 3
nameLabel.Parent = slot

-- ── Tooltip ──────────────────────────────────────────────────────────────────
local TOOLTIP_WIDTH = 300

local tooltip = Instance.new("Frame")
tooltip.Name = "Tooltip"
tooltip.AnchorPoint = Vector2.new(0.5, 1)
tooltip.Position = UDim2.new(0.5, 0, 1, -(16 + SLOT_SIZE + 14))
tooltip.Size = UDim2.fromOffset(TOOLTIP_WIDTH, 100)
tooltip.AutomaticSize = Enum.AutomaticSize.Y
tooltip.BackgroundColor3 = COLORS.Panel
tooltip.BackgroundTransparency = 0.02
tooltip.BorderSizePixel = 0
tooltip.Visible = false
tooltip.ZIndex = 10
tooltip.Parent = screenGui
PanelChrome.corner(tooltip, 12)
local tooltipStroke = Instance.new("UIStroke")
tooltipStroke.Color = COLORS.Stroke
tooltipStroke.Thickness = 1.5
tooltipStroke.Parent = tooltip

local tooltipPadding = Instance.new("UIPadding")
tooltipPadding.PaddingTop = UDim.new(0, 12)
tooltipPadding.PaddingBottom = UDim.new(0, 12)
tooltipPadding.PaddingLeft = UDim.new(0, 14)
tooltipPadding.PaddingRight = UDim.new(0, 14)
tooltipPadding.Parent = tooltip

local tooltipLayout = Instance.new("UIListLayout")
tooltipLayout.SortOrder = Enum.SortOrder.LayoutOrder
tooltipLayout.Padding = UDim.new(0, 4)
tooltipLayout.Parent = tooltip

local function tooltipLine(text: string, props)
	props = props or {}
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.new(1, 0, 0, 0)
	label.Font = props.font or Enum.Font.Gotham
	label.TextSize = props.size or 13
	label.TextColor3 = props.color or COLORS.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.LayoutOrder = props.order or 0
	label.ZIndex = 11
	label.Parent = tooltip
	return label
end

local function tooltipDivider(order: number)
	local line = Instance.new("Frame")
	line.Size = UDim2.new(1, 0, 0, 1)
	line.BackgroundColor3 = COLORS.Stroke
	line.BorderSizePixel = 0
	line.LayoutOrder = order
	line.ZIndex = 11
	line.Parent = tooltip
	return line
end

local function fillTooltip(tool: Tool)
	for _, child in ipairs(tooltip:GetChildren()) do
		if child:IsA("TextLabel") or child:IsA("Frame") then child:Destroy() end
	end

	local rarity = tool:GetAttribute("Rarity") or "Common"
	local rarityColor = RARITY_COLORS[rarity] or COLORS.Text
	local isBossDrop = tool:GetAttribute("BossDrop") == true
	local blessed = tool:GetAttribute("ExtraSlot") == true
	local damageMult = tool:GetAttribute("DamageMult") or 1
	local bossTier = tool:GetAttribute("BossTier")
	local prefixes = tool:GetAttribute("Prefixes") or ""

	tooltipLine(tool.Name, { font = Enum.Font.GothamBold, size = 16, color = rarityColor, order = 1 })

	local subtitle = rarity
	if isBossDrop then
		subtitle ..= "  ·  rating " .. SwordValue.short(SwordValue.rateTool(tool))
		if bossTier then subtitle ..= string.format("  ·  boss tier %d", bossTier) end
	else
		subtitle ..= "  ·  starter sword"
	end
	tooltipLine(subtitle, { color = COLORS.Muted, size = 12, order = 2 })
	tooltipDivider(3)

	tooltipLine(string.format("Base damage multiplier  x%.2f", damageMult), { font = Enum.Font.GothamMedium, order = 4 })

	local order = 5
	if blessed then
		tooltipLine("✦ Blessed  —  extra modifier slot", { font = Enum.Font.GothamMedium, color = BLESSED_GOLD, order = order })
		order += 1
	end

	local mods = SwordValue.modifiersFromPrefixes(prefixes)
	if #mods > 0 then
		tooltipDivider(order)
		order += 1
		tooltipLine("Modifiers", { font = Enum.Font.GothamBold, size = 12, color = COLORS.Muted, order = order })
		order += 1
		for _, mod in ipairs(mods) do
			local tierData = WeaponModifiers.Categories[mod.category].Tiers[mod.tier]
			tooltipLine(string.format("%s  (T%d)   %s", mod.name, mod.tier, tierData and tierData.desc or mod.category), { order = order })
			order += 1
		end
	elseif isBossDrop then
		tooltipLine("No modifiers", { color = COLORS.Muted, order = order })
		order += 1
	end

	-- Combined totals, in case several modifiers stack on the same stat.
	local bonusDmg = tool:GetAttribute("BonusDamagePct") or 0
	local critChance = tool:GetAttribute("CritChance") or 0
	local rangeBonus = tool:GetAttribute("RangeBonus") or 0
	local knockbackBonus = tool:GetAttribute("KnockbackBonus") or 0
	if bonusDmg > 0 or critChance > 0 or rangeBonus > 0 or knockbackBonus > 0 then
		tooltipDivider(order)
		order += 1
		tooltipLine("Totals", { font = Enum.Font.GothamBold, size = 12, color = COLORS.Muted, order = order })
		order += 1
		if bonusDmg > 0 then
			tooltipLine(string.format("+%d%% damage", math.round(bonusDmg * 100)), { color = Color3.fromRGB(255, 120, 100), order = order })
			order += 1
		end
		if critChance > 0 then
			tooltipLine(string.format("+%d%% critical strike chance", math.round(critChance * 100)), { color = Color3.fromRGB(255, 180, 70), order = order })
			order += 1
		end
		if rangeBonus > 0 then
			tooltipLine(string.format("+%s studs reach", tostring(rangeBonus)), { color = Color3.fromRGB(120, 200, 255), order = order })
			order += 1
		end
		if knockbackBonus > 0 then
			tooltipLine(string.format("+%d knockback", knockbackBonus), { color = Color3.fromRGB(160, 240, 160), order = order })
			order += 1
		end
	end
end

-- ── Preview rendering ────────────────────────────────────────────────────────
local function clearPreview()
	worldModel:ClearAllChildren()
end

-- Every sword's blade runs along its Handle's local -Z with the flat of the blade facing
-- local +-Y (the runtime-built ClassicSword and the boss mesh pipeline both follow this), so
-- posing the Handle to one fixed orientation gives a consistent upright icon no matter how
-- the hand happens to be holding the sword when it's cloned.
local ICON_POSE = CFrame.Angles(math.pi / 2, 0, 0) -- local -Z (tip) -> +Y (up), flat faces +-Z
local PREVIEW_FOV = 40

local function renderPreview(tool: Tool)
	clearPreview()
	local copy = tool:Clone()
	-- Strip anything that could run or interfere inside the viewport copy.
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ParticleEmitter") then
			d:Destroy()
		end
	end

	local handle = copy:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then
		copy:Destroy()
		return
	end
	-- Move the whole assembly rigidly so the Handle lands in ICON_POSE at the origin. Parts
	-- welded to the Handle are placed from the weld's own C0/C1 rather than their current
	-- CFrame: a freshly equipped ClassicSword hasn't had its welds simulated yet, so its
	-- blade/guard/pommel parts would otherwise all still be sitting at the origin.
	local transform = ICON_POSE * handle.CFrame:Inverse()
	local weldedPose = {}
	for _, weld in ipairs(copy:GetDescendants()) do
		if weld:IsA("Weld") and weld.Part0 == handle and weld.Part1 then
			weldedPose[weld.Part1] = ICON_POSE * weld.C0 * weld.C1:Inverse()
		end
	end
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CFrame = if part == handle then ICON_POSE else (weldedPose[part] or transform * part.CFrame)
			part.Anchored = true
		end
	end
	copy.Parent = worldModel

	local minV, maxV
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			local lo, hi = part.Position - half, part.Position + half
			minV = minV and Vector3.new(math.min(minV.X, lo.X), math.min(minV.Y, lo.Y), math.min(minV.Z, lo.Z)) or lo
			maxV = maxV and Vector3.new(math.max(maxV.X, hi.X), math.max(maxV.Y, hi.Y), math.max(maxV.Z, hi.Z)) or hi
		end
	end
	if not minV then return end

	-- Look straight at the flat of the blade from +Z; back off until the taller of height
	-- and width fits the square slot with a little margin.
	local centre = (minV + maxV) / 2
	local size = maxV - minV
	local fit = math.max(size.Y, size.X) * 0.5 * 1.15
	local distance = fit / math.tan(math.rad(PREVIEW_FOV / 2)) + size.Z / 2
	previewCamera.FieldOfView = PREVIEW_FOV
	previewCamera.CFrame = CFrame.lookAt(centre + Vector3.new(0, 0, distance), centre)
end

-- ── Equipped-tool tracking ───────────────────────────────────────────────────
local currentTool: Tool? = nil

local function applyTool(tool: Tool?)
	currentTool = tool
	if not tool then
		clearPreview()
		emptyLabel.Visible = true
		nameLabel.Text = ""
		slotStroke.Color = COLORS.Stroke
		halo.Visible = false
		tooltip.Visible = false
		return
	end
	local rarity = tool:GetAttribute("Rarity") or "Common"
	emptyLabel.Visible = false
	nameLabel.Text = tool.Name
	nameLabel.TextColor3 = RARITY_COLORS[rarity] or COLORS.Text
	slotStroke.Color = RARITY_COLORS[rarity] or COLORS.Stroke
	halo.Visible = tool:GetAttribute("ExtraSlot") == true
	renderPreview(tool)
	if tooltip.Visible then fillTooltip(tool) end
end

local function findEquipped(character: Model?): Tool?
	if not character then return nil end
	return character:FindFirstChildOfClass("Tool")
end

local characterConnections = {}

local function watchCharacter(character: Model)
	for _, conn in ipairs(characterConnections) do conn:Disconnect() end
	characterConnections = {}
	applyTool(findEquipped(character))
	table.insert(characterConnections, character.ChildAdded:Connect(function(child)
		-- One frame later so the tool's replicated parts and attributes have all arrived.
		if child:IsA("Tool") then
			task.defer(function()
				if child.Parent == character then applyTool(child) end
			end)
		end
	end))
	table.insert(characterConnections, character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child == currentTool then
			applyTool(findEquipped(character))
		end
	end))
end

if player.Character then watchCharacter(player.Character) end
player.CharacterAdded:Connect(watchCharacter)

-- ── Hover ────────────────────────────────────────────────────────────────────
local hoverTween

slot.MouseEnter:Connect(function()
	if not currentTool then return end
	fillTooltip(currentTool)
	tooltip.Visible = true
	if hoverTween then hoverTween:Cancel() end
	hoverTween = TweenService:Create(slot, TweenInfo.new(0.12), { BackgroundColor3 = COLORS.PanelLight })
	hoverTween:Play()
end)

slot.MouseLeave:Connect(function()
	tooltip.Visible = false
	if hoverTween then hoverTween:Cancel() end
	hoverTween = TweenService:Create(slot, TweenInfo.new(0.12), { BackgroundColor3 = COLORS.Panel })
	hoverTween:Play()
end)

print("[SwordHotbarGui] Equipped-sword hotbar enabled (default backpack hidden)")
