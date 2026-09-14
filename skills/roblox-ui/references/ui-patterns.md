# Roblox UI Patterns — Reference Implementations

Each pattern includes: hierarchy, LocalScript code, and GuiObject event usage.
All code is Luau, uses standard Roblox APIs, and targets both desktop and mobile.

---

## 1. Modal Dialog

A centered popup with a semi-transparent overlay that blocks background interaction.

**Hierarchy:**
```
ScreenGui ("ModalLayer")
└── Frame ("Overlay")                     -- full-screen backdrop
    ├── BackgroundTransparency = 0.4      -- tuning: dim amount
    ├── BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    └── Frame ("Content")
        ├── AnchorPoint = (0.5, 0.5)
        ├── Position = UDim2.fromScale(0.5, 0.5)
        ├── Size = UDim2.fromOffset(320, 200)   -- tuning: dialog size
        ├── BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        ├── UICorner (CornerRadius = UDim.new(0, 12))
        ├── UIStroke (Thickness = 2, Color = Color3.fromRGB(80, 80, 100))
        ├── TextLabel ("Title")
        │   ├── Size = UDim2.new(1, 0, 0, 40)
        │   ├── Font = Enum.Font.GothamBold
        │   ├── TextSize = 20
        │   └── Text = "Confirm Action"
        ├── TextLabel ("Body")
        │   ├── Position = UDim2.new(0, 16, 0, 48)
        │   ├── Size = UDim2.new(1, -32, 0, 80)
        │   ├── TextWrapped = true
        │   └── Text = "Are you sure?"
        └── Frame ("ButtonRow")
            ├── Position = UDim2.new(0, 0, 1, -56)
            ├── Size = UDim2.new(1, 0, 0, 48)
            └── UIListLayout (Horizontal, Center, Padding = 12)
                ├── TextButton ("Confirm")
                └── TextButton ("Cancel")
```

**Script (LocalScript in StarterGui):**
```lua
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function createModal(title: string, body: string, onConfirm: () -> ())
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ModalLayer"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 100   -- tuning: ensure modal is above other UI
    screenGui.Parent = playerGui

    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 1   -- start invisible for tween
    overlay.BorderSizePixel = 0
    overlay.Parent = screenGui

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.AnchorPoint = Vector2.new(0.5, 0.5)
    content.Position = UDim2.fromScale(0.5, 0.5)
    content.Size = UDim2.fromOffset(320, 200)   -- tuning: dialog width/height
    content.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.Parent = overlay

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = content

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(80, 80, 100)
    stroke.Parent = content

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 40)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 20
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.Text = title
    titleLabel.Parent = content

    local bodyLabel = Instance.new("TextLabel")
    bodyLabel.Position = UDim2.new(0, 16, 0, 48)
    bodyLabel.Size = UDim2.new(1, -32, 0, 80)
    bodyLabel.BackgroundTransparency = 1
    bodyLabel.Font = Enum.Font.Gotham
    bodyLabel.TextSize = 16
    bodyLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    bodyLabel.TextWrapped = true
    bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
    bodyLabel.Text = body
    bodyLabel.Parent = content

    local buttonRow = Instance.new("Frame")
    buttonRow.Position = UDim2.new(0, 0, 1, -56)
    buttonRow.Size = UDim2.new(1, 0, 0, 48)
    buttonRow.BackgroundTransparency = 1
    buttonRow.Parent = content

    local buttonLayout = Instance.new("UIListLayout")
    buttonLayout.FillDirection = Enum.FillDirection.Horizontal
    buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    buttonLayout.Padding = UDim.new(0, 12)
    buttonLayout.Parent = buttonRow

    local function makeButton(text: string, color: Color3): TextButton
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.fromOffset(120, 40)   -- tuning: button size
        btn.BackgroundColor3 = color
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 16
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Text = text
        btn.BorderSizePixel = 0
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = btn
        btn.Parent = buttonRow
        return btn
    end

    local confirmBtn = makeButton("Confirm", Color3.fromRGB(60, 160, 80))
    local cancelBtn = makeButton("Cancel", Color3.fromRGB(80, 80, 100))

    -- Open tween: fade in overlay + scale up content
    local openInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)  -- tuning: open duration/style
    TweenService:Create(overlay, TweenInfo.new(0.25), {BackgroundTransparency = 0.4}):Play()
    content.Size = UDim2.fromOffset(320, 200) * 0.8   -- start smaller
    TweenService:Create(content, openInfo, {
        Size = UDim2.fromOffset(320, 200),
        BackgroundTransparency = 0
    }):Play()

    -- Close function
    local function close()
        local closeInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)  -- tuning: close duration
        TweenService:Create(overlay, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
        TweenService:Create(content, closeInfo, {BackgroundTransparency = 1}):Play()
        task.delay(0.2, function()
            screenGui:Destroy()
        end)
    end

    confirmBtn.Activated:Connect(function()
        close()
        if onConfirm then onConfirm() end
    end)

    cancelBtn.Activated:Connect(function()
        close()
    end)

    overlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            close()   -- clicking outside content closes modal
        end
    end)
end

-- Usage:
-- createModal("Delete Item", "This cannot be undone. Proceed?", function()
--     print("Confirmed!")
-- end)
```

---

## 2. Toast Notification

A small message that slides in from the right, holds, then slides out.

**Hierarchy:**
```
ScreenGui ("ToastLayer")
└── Frame ("Toast")
    ├── AnchorPoint = (1, 1)
    ├── Position = UDim2.new(1, -16, 1, -16)       -- bottom-right with margin
    ├── Size = UDim2.new(0, 300, 0, 50)             -- tuning: toast dimensions
    ├── BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    ├── UICorner (CornerRadius = UDim.new(0, 10))
    └── TextLabel ("Message")
        ├── Size = UDim2.new(1, -24, 1, 0)
        ├── Position = UDim2.new(0, 12, 0, 0)
        ├── TextXAlignment = Left
        └── Font = GothamSemibold, TextSize = 15
```

**Script:**
```lua
local TweenService = game:GetService("TweenService")

local function showToast(message: string, duration: number?)
    duration = duration or 3   -- tuning: hold time in seconds

    local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "ToastLayer"
    gui.DisplayOrder = 90
    gui.Parent = playerGui

    local toast = Instance.new("Frame")
    toast.AnchorPoint = Vector2.new(1, 1)
    toast.Position = UDim2.new(1, 320, 1, -16)   -- start off-screen right
    toast.Size = UDim2.new(0, 300, 0, 50)         -- tuning: width, height
    toast.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    toast.BorderSizePixel = 0
    toast.Parent = gui

    Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -24, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 15
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = message
    label.Parent = toast

    local slideIn = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)  -- tuning: slide-in
    local slideOut = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)    -- tuning: slide-out

    TweenService:Create(toast, slideIn, {Position = UDim2.new(1, -16, 1, -16)}):Play()

    task.delay(duration, function()
        local tween = TweenService:Create(toast, slideOut, {Position = UDim2.new(1, 320, 1, -16)})
        tween:Play()
        tween.Completed:Wait()
        gui:Destroy()
    end)
end

-- Usage:
-- showToast("Item purchased!")
-- showToast("Low on health!", 5)
```

---

## 3. Scrolling Inventory Grid

A scrollable grid populated from a data table with per-item click handlers.

**Hierarchy:**
```
ScreenGui ("InventoryUI")
└── Frame ("Panel")
    ├── Size = UDim2.fromScale(0.4, 0.7)
    ├── AnchorPoint = (0.5, 0.5), Position = Scale(0.5, 0.5)
    ├── BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    ├── UICorner (12)
    └── ScrollingFrame ("Grid")
        ├── Size = UDim2.new(1, -16, 1, -56)    -- leave space for title
        ├── Position = UDim2.new(0, 8, 0, 48)
        ├── CanvasSize = AutomaticY
        ├── ScrollBarThickness = 6
        ├── BackgroundTransparency = 1
        ├── UIGridLayout
        │   ├── CellSize = UDim2.fromOffset(80, 80)   -- tuning: cell size
        │   ├── CellPadding = UDim2.fromOffset(8, 8)   -- tuning: gap
        │   └── SortOrder = LayoutOrder
        └── (ImageButton children added dynamically)
```

**Script:**
```lua
local TweenService = game:GetService("TweenService")
local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Example inventory data
local inventoryData = {
    {id = "sword",   name = "Iron Sword",   icon = "rbxassetid://123456"},
    {id = "shield",  name = "Wood Shield",   icon = "rbxassetid://123457"},
    {id = "potion",  name = "Health Potion", icon = "rbxassetid://123458"},
    {id = "gem",     name = "Ruby Gem",      icon = "rbxassetid://123459"},
    -- Add more items...
}

local gui = playerGui:FindFirstChild("InventoryUI") or Instance.new("ScreenGui")
gui.Name = "InventoryUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local panel = gui:FindFirstChild("Panel") or Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.4, 0.7)   -- tuning: panel size as fraction of screen
panel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local gridFrame = panel:FindFirstChild("Grid") or Instance.new("ScrollingFrame")
gridFrame.Name = "Grid"
gridFrame.Size = UDim2.new(1, -16, 1, -56)
gridFrame.Position = UDim2.new(0, 8, 0, 48)
gridFrame.BackgroundTransparency = 1
gridFrame.BorderSizePixel = 0
gridFrame.ScrollBarThickness = 6
gridFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
gridFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
gridFrame.Parent = panel

local gridLayout = gridFrame:FindFirstChildOfClass("UIGridLayout") or Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(80, 80)    -- tuning: item cell size
gridLayout.CellPadding = UDim2.fromOffset(8, 8)   -- tuning: spacing between cells
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

local function populateGrid(data)
    -- Clear existing items
    for _, child in gridFrame:GetChildren() do
        if child:IsA("GuiButton") then child:Destroy() end
    end

    for index, item in data do
        local btn = Instance.new("ImageButton")
        btn.Name = item.id
        btn.LayoutOrder = index
        btn.Size = UDim2.fromScale(1, 1)
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        btn.Image = item.icon
        btn.ScaleType = Enum.ScaleType.Fit
        btn.BorderSizePixel = 0
        btn.Parent = gridFrame

        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0, 18)
        nameLabel.Position = UDim2.new(0, 0, 1, -18)
        nameLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        nameLabel.BackgroundTransparency = 0.5
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.TextSize = 11
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.Text = item.name
        nameLabel.Parent = btn

        -- Click handler
        btn.Activated:Connect(function()
            print("Selected item:", item.id, item.name)
            -- Open item detail, equip, etc.
        end)

        -- Hover feedback (desktop)
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(70, 70, 90)
            }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(50, 50, 65)
            }):Play()
        end)
    end
end

populateGrid(inventoryData)
panel.Visible = true
```

---

## 4. Tabbed Interface

Multiple content panels controlled by tab buttons. Only one panel visible at a time.

**Hierarchy:**
```
ScreenGui ("ShopUI")
└── Frame ("Panel")
    ├── Size = UDim2.fromScale(0.5, 0.7), AnchorPoint = (0.5, 0.5)
    ├── BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    ├── Frame ("TabBar")
    │   ├── Size = UDim2.new(1, 0, 0, 44)
    │   ├── BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    │   └── UIListLayout (Horizontal)
    │       ├── TextButton ("WeaponsTab"), TextButton ("ArmorTab"), TextButton ("MiscTab")
    │       └── each: Size = UDim2.new(0, 100, 1, 0)
    ├── Frame ("WeaponsContent")
    ├── Frame ("ArmorContent")
    └── Frame ("MiscContent")
```

**Script:**
```lua
local TweenService = game:GetService("TweenService")

local tabs = {
    {button = weaponsTab,   content = weaponsContent},
    {button = armorTab,     content = armorContent},
    {button = miscTab,      content = miscContent},
}

local activeColor = Color3.fromRGB(60, 120, 200)   -- tuning: active tab color
local inactiveColor = Color3.fromRGB(40, 40, 55)    -- tuning: inactive tab color
local activeTextColor = Color3.fromRGB(255, 255, 255)
local inactiveTextColor = Color3.fromRGB(150, 150, 160)

local function switchTab(activeTab)
    for _, tab in tabs do
        local isActive = (tab == activeTab)
        tab.content.Visible = isActive
        TweenService:Create(tab.button, TweenInfo.new(0.2), {
            BackgroundColor3 = isActive and activeColor or inactiveColor
        }):Play()
        TweenService:Create(tab.button, TweenInfo.new(0.2), {
            TextColor3 = isActive and activeTextColor or inactiveTextColor
        }):Play()
    end
end

for _, tab in tabs do
    tab.button.Font = Enum.Font.GothamBold
    tab.button.TextSize = 15
    tab.button.BorderSizePixel = 0
    tab.button.BackgroundColor3 = inactiveColor
    tab.button.TextColor3 = inactiveTextColor
    tab.button.Activated:Connect(function()
        switchTab(tab)
    end)
end

-- Default: first tab active
switchTab(tabs[1])
```

---

## 5. Confirmation Popup

A compact Yes/No dialog that invokes a callback on confirm.

**Script:**
```lua
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local function confirmPopup(promptText: string, onConfirm: () -> ())
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.DisplayOrder = 100
    gui.Parent = playerGui

    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.Parent = gui

    local box = Instance.new("Frame")
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.Position = UDim2.fromScale(0.5, 0.5)
    box.Size = UDim2.fromOffset(280, 140)   -- tuning: popup size
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Parent = overlay
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 12)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -24, 0, 50)
    label.Position = UDim2.new(0, 12, 0, 12)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 16
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextWrapped = true
    label.Text = promptText
    label.Parent = box

    local btnRow = Instance.new("Frame")
    btnRow.Position = UDim2.new(0, 0, 1, -52)
    btnRow.Size = UDim2.new(1, 0, 0, 40)
    btnRow.BackgroundTransparency = 1
    btnRow.Parent = box
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 10)
    layout.Parent = btnRow

    local yesBtn = Instance.new("TextButton")
    yesBtn.Size = UDim2.fromOffset(100, 36)
    yesBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
    yesBtn.Font = Enum.Font.GothamBold
    yesBtn.TextSize = 15
    yesBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    yesBtn.Text = "Yes"
    yesBtn.BorderSizePixel = 0
    yesBtn.Parent = btnRow
    Instance.new("UICorner", yesBtn).CornerRadius = UDim.new(0, 8)

    local noBtn = Instance.new("TextButton")
    noBtn.Size = UDim2.fromOffset(100, 36)
    noBtn.BackgroundColor3 = Color3.fromRGB(100, 40, 40)
    noBtn.Font = Enum.Font.GothamBold
    noBtn.TextSize = 15
    noBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    noBtn.Text = "No"
    noBtn.BorderSizePixel = 0
    noBtn.Parent = btnRow
    Instance.new("UICorner", noBtn).CornerRadius = UDim.new(0, 8)

    -- Open tween
    TweenService:Create(overlay, TweenInfo.new(0.2), {BackgroundTransparency = 0.4}):Play()
    TweenService:Create(box, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0
    }):Play()

    local function close()
        TweenService:Create(overlay, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
        task.delay(0.15, function() gui:Destroy() end)
    end

    yesBtn.Activated:Connect(function() close(); if onConfirm then onConfirm() end end)
    noBtn.Activated:Connect(close)
end

-- Usage:
-- confirmPopup("Sell this item for 50 gold?", function()
--     print("Sold!")
-- end)
```

---

## 6. Health / Mana Bar

A frame-based bar that tweens its width when an attribute changes.

**Hierarchy:**
```
ScreenGui ("HUD")
└── Frame ("HealthBarBG")
    ├── Size = UDim2.new(0.25, 0, 0, 24)              -- tuning: bar dimensions
    ├── Position = UDim2.new(0.02, 0, 0.04, 0)        -- tuning: screen position
    ├── BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    ├── UICorner (CornerRadius = UDim.new(0, 6))
    └── Frame ("HealthFill")
        ├── Size = UDim2.new(1, 0, 1, 0)              -- starts full
        ├── BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        ├── ClipsDescendants = true
        └── UICorner (CornerRadius = UDim.new(0, 6))
```

**Script (LocalScript):**
```lua
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Wait for character and humanoid
local function setupBar()
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")

    local playerGui = player:WaitForChild("PlayerGui")
    local gui = playerGui:WaitForChild("HUD")
    local barBG = gui:WaitForChild("HealthBarBG")
    local fill = barBG:WaitForChild("HealthFill")

    local barTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)  -- tuning: bar speed

    local function updateBar(ratio: number)
        ratio = math.clamp(ratio, 0, 1)
        -- Color gradient: red → yellow → green
        local color
        if ratio > 0.5 then
            color = Color3.new(2 * (1 - ratio), 1, 0)   -- yellow to green
        else
            color = Color3.new(1, 2 * ratio, 0)          -- red to yellow
        end
        TweenService:Create(fill, barTweenInfo, {
            Size = UDim2.new(ratio, 0, 1, 0),
            BackgroundColor3 = color
        }):Play()
    end

    humanoid.HealthChanged:Connect(function(newHealth)
        updateBar(newHealth / humanoid.MaxHealth)
    end)

    -- Initial state
    updateBar(humanoid.Health / humanoid.MaxHealth)
end

setupBar()
player.CharacterAdded:Connect(setupBar)
```

---

## 7. Leaderboard Customization

Modifying or replacing the default Roblox leaderboard with a custom panel.

**Strategy:** Hide the default player list and build a custom scrolling list.

**Script (LocalScript in StarterGui):**
```lua
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Hide default leaderboard (optional)
local starterGui = game:GetService("StarterGui")
pcall(function()
    starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

-- Build custom leaderboard
local gui = Instance.new("ScreenGui")
gui.Name = "CustomLeaderboard"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -8, 0, 8)
panel.Size = UDim2.new(0, 220, 0.5, 0)   -- tuning: leaderboard dimensions
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
title.BackgroundTransparency = 0.3
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "Players"
title.Parent = panel
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

-- Scrolling list
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "PlayerList"
scroll.Size = UDim2.new(1, -8, 1, -40)
scroll.Position = UDim2.new(0, 4, 0, 36)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll

local function refreshList()
    for _, child in scroll:GetChildren() do
        if child:IsA("Frame") then child:Destroy() end
    end

    -- Sort by a custom attribute (e.g., "Score") or alphabetically
    local sorted = Players:GetPlayers()
    table.sort(sorted, function(a, b)
        local scoreA = a:GetAttribute("Score") or 0
        local scoreB = b:GetAttribute("Score") or 0
        return scoreA > scoreB
    end)

    for i, plr in sorted do
        local row = Instance.new("Frame")
        row.Name = plr.Name
        row.LayoutOrder = i
        row.Size = UDim2.new(1, 0, 0, 28)
        row.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
        row.BackgroundTransparency = (plr == player) and 0.3 or 0.6
        row.BorderSizePixel = 0
        row.Parent = scroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
        nameLabel.Position = UDim2.new(0, 8, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.TextSize = 13
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Text = plr.DisplayName
        nameLabel.Parent = row

        local scoreLabel = Instance.new("TextLabel")
        scoreLabel.Size = UDim2.new(0.35, 0, 1, 0)
        scoreLabel.Position = UDim2.new(0.6, 0, 0, 0)
        scoreLabel.BackgroundTransparency = 1
        scoreLabel.Font = Enum.Font.GothamBold
        scoreLabel.TextSize = 13
        scoreLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
        scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
        scoreLabel.Text = tostring(plr:GetAttribute("Score") or 0)
        scoreLabel.Parent = row
    end
end

Players.PlayerAdded:Connect(refreshList)
Players.PlayerRemoving:Connect(refreshList)

-- Refresh when any player's Score attribute changes
for _, plr in Players:GetPlayers() do
    plr:GetAttributeChangedSignal("Score"):Connect(refreshList)
end
refreshList()
```

---

## 8. Cooldown Overlay

A radial wipe effect over an ability icon that reveals as the cooldown expires.

**Approach:** Use a CanvasGroup with an ImageLabel that clips a wedge, rotating to reveal the icon. Alternatively, use multiple small frames in a clock pattern for a pure-frame approach.

**Hierarchy:**
```
Frame ("AbilityButton")                     -- the ability icon container
├── Size = UDim2.fromOffset(64, 64)
├── ImageLabel ("Icon")                     -- the ability icon
│   ├── Size = UDim2.fromScale(1, 1)
│   └── Image = "rbxassetid://ICON_ID"
└── Frame ("CooldownOverlay")
    ├── Size = UDim2.fromScale(1, 1)
    ├── ClipsDescendants = true
    ├── BackgroundTransparency = 1
    └── ImageLabel ("Wedge")
        ├── Size = UDim2.fromScale(2, 2)
        ├── AnchorPoint = (0.5, 0.5)
        ├── Position = UDim2.fromScale(0.5, 0.5)
        ├── Image = "rbxassetid://282401033"   -- standard radial wipe asset
        ├── ImageColor3 = Color3.fromRGB(0, 0, 0)
        ├── ImageTransparency = 0.5
        └── Rotation = 0   -- tweens from 360 to 0 over cooldown duration
```

**Script:**
```lua
local TweenService = game:GetService("TweenService")

local COOLDOWN_DURATION = 5   -- tuning: total cooldown time in seconds

local function startCooldown(abilityButton: Frame)
    local overlay = abilityButton:FindFirstChild("CooldownOverlay")
    if not overlay then return end
    local wedge = overlay:FindFirstChild("Wedge")
    if not wedge then return end

    overlay.Visible = true
    wedge.Rotation = 360   -- fully covered

    -- Radial wipe: rotate from 360 → 0 over the cooldown duration
    local tween = TweenService:Create(wedge, TweenInfo.new(
        COOLDOWN_DURATION,
        Enum.EasingStyle.Linear,   -- linear for even cooldown progression
        Enum.EasingDirection.Out
    ), {Rotation = 0})

    tween:Play()
    tween.Completed:Connect(function()
        overlay.Visible = false
    end)

    return tween   -- return so caller can cancel if needed
end

-- Alternative pure-frame approach for radial cooldown (no image asset needed)
-- Splits cooldown into segments using small triangular-like frames
local function startCooldownSegments(abilityButton: Frame, cooldownSeconds: number)
    local NUM_SEGMENTS = 12   -- tuning: number of wipe segments (more = smoother)
    local segmentAngle = 360 / NUM_SEGMENTS
    local segmentDelay = cooldownSeconds / NUM_SEGMENTS

    local overlay = abilityButton:FindFirstChild("CooldownOverlay")
    if not overlay then return end

    overlay.Visible = true

    for i = 1, NUM_SEGMENTS do
        task.delay(segmentDelay * (i - 1), function()
            -- Each segment "clears" by tweening transparency
            -- Implementation depends on visual approach
            -- For simplicity, reduce overlay opacity in steps
            local progress = i / NUM_SEGMENTS
            TweenService:Create(overlay, TweenInfo.new(segmentDelay), {
                BackgroundTransparency = progress
            }):Play()
        end)
    end

    task.delay(cooldownSeconds, function()
        overlay.Visible = false
        overlay.BackgroundTransparency = 1
    end)
end

-- Usage:
-- local tween = startCooldown(abilityButton)
-- -- or for the segment approach:
-- startCooldownSegments(abilityButton, 5)
```
