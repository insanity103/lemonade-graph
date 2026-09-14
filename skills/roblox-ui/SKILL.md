---
name: roblox-ui
description: Design and implement Roblox UI systems — menus, HUDs, inventory screens, shop interfaces, dialogs, and mobile-friendly layouts. Use for any ScreenGui, BillboardGui, SurfaceGui, or UI scripting task. Triggers on Roblox UI, menu design, HUD, shop UI, inventory screen, dialog box, mobile UI, or GuiObject.
---

# Roblox UI/UX Design & Implementation

Production guidance for building Roblox GUIs with Luau. Covers hierarchy, layout, responsiveness, animation, input, accessibility, and mobile optimization.

---

## UI Hierarchy

Every Roblox UI instance must live under a correct ancestor. Wrong placement means the UI never renders.

| Gui Type | Parent Location | Typical Use |
|---|---|---|
| `ScreenGui` | `StarterGui` (replicated to `PlayerGui`) | HUD, menus, inventory, shop, dialogs |
| `BillboardGui` | Character model or workspace part | Overhead name tags, health bars, indicators |
| `SurfaceGui` | A `Part` or `Model` in workspace | In-world screens, signs, computer terminals |

### Recommended hierarchy for a full HUD

```
StarterGui
└── ScreenGui ("MainHUD")
    ├── Frame ("TopBar")
    │   ├── TextLabel ("PlayerName")
    │   └── TextLabel ("Currency")
    ├── Frame ("BottomBar")
    │   └── UIListLayout (Horizontal, FillDirection)
    ├── Frame ("InventoryPanel")        -- toggled visible/hidden
    │   ├── ScrollingFrame ("Grid")
    │   │   ├── UIGridLayout
    │   │   └── (ImageButton children per item)
    │   └── TextButton ("CloseButton")
    └── Frame ("DialogOverlay")         -- modal backdrop
        ├── Frame ("DialogContent")
        │   ├── TextLabel ("Title")
        │   ├── TextLabel ("Body")
        │   └── Frame ("ButtonRow")
        │       ├── TextButton ("Confirm")
        │       └── TextButton ("Cancel")
```

**Rules:**
- One `ScreenGui` per logical panel group (HUD, Menu, Overlay). Do NOT put everything in one ScreenGui.
- Set `ScreenGui.ResetOnSpawn = false` for persistent UI.
- Set `ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling` for predictable stacking.
- BillboardGui: set `Size` in studs, `StudsOffset` for positioning above head.
- SurfaceGui: set `Face` to the correct `NormalId`, `SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud` for crisp text.

---

## Layout Objects

### UIListLayout

Arranges children linearly. Use for button bars, chat logs, notification stacks.

```lua
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal  -- or Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder          -- use LayoutOrder on children
layout.Padding = UDim.new(0, 8)                        -- 8px gap
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Top
layout.Parent = containerFrame
```

### UIGridLayout

Grid arrangement for inventory items, shop cards.

```lua
local grid = Instance.new("UIGridLayout")
grid.CellPadding = UDim2.new(0, 8, 0, 8)     -- 8px horizontal and vertical gap
grid.CellSize = UDim2.new(0, 80, 0, 80)       -- 80x80 pixel cells
grid.FillDirection = Enum.FillDirection.Horizontal
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
grid.Parent = scrollingFrame
```

### UIPageLayout

Swipeable pages (e.g., tutorial slides, carousel).

```lua
local pages = Instance.new("UIPageLayout")
pages.TweenTime = 0.4                -- animation duration in seconds
pages.EasingStyle = Enum.EasingStyle.Quad
pages.EasingDirection = Enum.EasingDirection.InOut
pages.Circular = false
pages.SortOrder = Enum.SortOrder.LayoutOrder
pages.Parent = pagesFrame
-- Navigate: pages:Next() / pages:Previous() / pages:JumpTo(page)
```

### UIScale

Uniformly scales all child UI elements. Useful for different screen densities.

```lua
local scale = Instance.new("UIScale")
scale.Scale = 1.0   -- 1.0 = native size; 0.5 = half; 2.0 = double
scale.Parent = containerFrame
```

---

## Responsive Design

### UIAspectRatioConstraint

Locks width-to-height ratio so elements scale proportionally on any resolution.

```lua
local ar = Instance.new("UIAspectRatioConstraint")
ar.AspectRatio = 1       -- square (1:1). Use 16/9 for widescreen frames
ar.AspectType = Enum.AspectType.ScaleWithParentSize  -- default
ar.DominantAxis = Enum.DominantAxis.Width             -- width drives height
ar.Parent = frame
```

### Offset vs Scale

| Dimension | Use When | Example |
|---|---|---|
| `Scale` (0.0–1.0) | Element should be a percentage of parent | Full-width overlay (`Size = UDim2.new(1, 0, 1, 0)`) |
| `Offset` (pixels) | Fixed-size element regardless of screen | Icon button (`Size = UDim2.new(0, 44, 0, 44)`) |
| Mixed | Common pattern — scale width, fixed height | Search bar (`Size = UDim2.new(0.5, 0, 0, 40)`) |

**Guidelines:**
- Background frames: use `Scale` for both axes (fill parent).
- Buttons and icons: `Offset` for consistent tap targets, or `Scale` + `UIAspectRatioConstraint`.
- Text: use `TextScaled = true` with a `UITextSizeConstraint` to set min/max.
- Padding: use `UIPadding` with Scale values for proportional margins.

### Mobile considerations

- Test with the Roblox Studio emulator at 360×640 (small phone) and 414×896 (standard phone).
- Prefer bottom-center or bottom-left placement for primary actions (thumb zone).
- Avoid top-left and top-right corners for interactive elements.
- See the Mobile section below for full details.

---

## Animation

All UI animation should use `TweenService`. Never use `wait()` loops to fake animation.

### Basic UI tween

```lua
local TweenService = game:GetService("TweenService")

local tweenInfo = TweenInfo.new(
    0.3,                                           -- duration (seconds)
    Enum.EasingStyle.Quad,                          -- easing style
    Enum.EasingDirection.Out,                       -- easing direction
    0,                                              -- repeat count (0 = no repeat)
    false,                                          -- reverses?
    0                                               -- delay before start
)

local tween = TweenService:Create(targetFrame, tweenInfo, {
    Position = UDim2.new(0.5, 0, 0.5, 0),          -- move to center
    BackgroundTransparency = 0                       -- fade in
})
tween:Play()
```

### Common easing styles for UI

| Style | Feel | Best For |
|---|---|---|
| `Quad` / `Cubic` | Smooth acceleration | General transitions |
| `Back` | Overshoots then settles | Playful popups, bouncy buttons |
| `Bounce` | Bouncy end | Achievement popups, celebrations |
| `Elastic` | Spring-like | Attention-grabbing elements |
| `Sine` | Gentle sinusoidal | Subtle ambient loops |

Always use `EasingDirection.Out` for elements appearing, `In` for disappearing, `InOut` for looping.

See `references/ui-animation.md` for complete animation patterns and code.

---

## Input

### UserInputService (client-side)

```lua
local UIS = game:GetService("UserInputService")

-- Detect platform
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
local isConsole = UIS.GamepadEnabled

-- Keyboard shortcut
UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.I then
        toggleInventory()
    end
end)
```

### GuiObject events (preferred for UI buttons)

```lua
button.Activated:Connect(function()    -- fires on click/tap, best for most buttons
    handlePurchase()
end)

button.MouseEnter:Connect(function()   -- hover start (desktop only)
    TweenService:Create(button, hoverInfo, {Size = hoverSize}):Play()
end)

button.MouseLeave:Connect(function()   -- hover end
    TweenService:Create(button, hoverInfo, {Size = normalSize}):Play()
end)

-- Touch-friendly alternative for drag or custom gestures
button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        -- handle touch start
    end
end)
```

### ContextActionService (bind game actions to UI buttons)

```lua
local CAS = game:GetService("ContextActionService")

local function onInventory(actionName, inputState)
    if inputState == Enum.UserInputState.Begin then
        toggleInventory()
    end
end

CAS:BindAction("OpenInventory", onInventory, true, Enum.KeyCode.I)
CAS:SetTitle("OpenInventory", "Inventory")
CAS:SetPosition("OpenInventory", UDim2.new(0.5, 0, 0.9, 0))
-- CAS:UnbindAction("OpenInventory")
```

---

## UI Patterns

Detailed implementations are in `references/ui-patterns.md`. Summary:

| Pattern | Key Elements | Notes |
|---|---|---|
| **Modal Dialog** | Overlay frame + content + buttons | Tween opacity; block input with overlay |
| **Toast Notification** | Auto-dismiss frame with text | Slide in from right, hold 3s, slide out |
| **Scrolling Inventory Grid** | ScrollingFrame + UIGridLayout | Populate from data table; click handler per cell |
| **Tabbed Interface** | Tab buttons + content frames | Toggle `Visible`; highlight active tab |
| **Confirmation Popup** | Two buttons + callback | Await user choice via `.Activated` coroutine or event |
| **Health/Mana Bar** | Inner frame that tweens width | Listen to `AttributeChanged` for smooth updates |
| **Leaderboard** | Custom StarterGui + PlayerList | Override default or build side panel |
| **Cooldown Overlay** | ImageLabel with radial fill | Use `ImageRectOffset`/`ImageRectSize` for wipe |

---

## Accessibility

### Touch targets

- Minimum interactive element size: **44×44 pixels** (Apple HIG / WCAG 2.5.5).
- For primary actions on mobile, prefer **48×48 or larger**.
- Maintain at least 8px gap between adjacent tappable elements.

### Color contrast

- Text on backgrounds: minimum contrast ratio **4.5:1** for normal text, **3:1** for large text (≥18px bold or ≥24px regular).
- Avoid conveying information through color alone — use icons, labels, or patterns alongside color.
- Example: a red "low health" bar should also pulse or show a warning icon.

### Scalable text

```lua
-- Enable TextScaled with bounds
textLabel.TextScaled = true
local constraint = Instance.new("UITextSizeConstraint")
constraint.MaxTextSize = 24   -- tuning: maximum readable size
constraint.MinTextSize = 12   -- tuning: minimum legible size
constraint.Parent = textLabel
```

### Readability

- Use `Font = Enum.Font.GothamBold` or `GothamSemibold` for UI text (clear at small sizes).
- Avoid `Enum.Font.Arcade` or decorative fonts for body text.
- Add a semi-transparent dark background behind floating text for legibility over varied game worlds.

---

## Mobile

### Larger buttons

- Scale buttons generously: `Size = UDim2.new(0, 64, 0, 64)` for primary actions.
- Increase `TextSize` or use `TextScaled` with a minimum of 14.
- Add `UICorner` for visual softness (optional but improves perceived tap target).

### Thumb-zone placement

```
┌──────────────────────────┐
│  Hard to reach (avoid    │
│  interactive elements)   │
│                          │
│      Natural reach       │
│      zone (middle)       │
│                          │
│  ╔══════════════════╗    │
│  ║  Easy reach zone ║    │
│  ║  (bottom 1/3)    ║    │
│  ╚══════════════════╝    │
└──────────────────────────┘
```

- Place primary action buttons in the bottom 1/3 of the screen.
- Bottom-center is the easiest single-thumb reach.
- Bottom-left and bottom-right are reachable with left/right thumbs respectively.

### Avoid edge UI

- Keep at least 16px margin from screen edges (more on phones with rounded corners).
- Roblox's built-in chat and leaderboard occupy the top-left — avoid overlapping.
- The mobile jump button sits bottom-right — leave space.
- Safe area: use `GuiService:GetGuiInset()` to account for the top bar.

### Platform-aware scaling

```lua
local GuiService = game:GetService("GuiService")
local inset = GuiService:GetGuiInset()  -- Vector2 offset for top bar

local UIS = game:GetService("UserInputService")
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

-- Adjust scale factor for mobile
local uiScale = container:FindFirstChildOfClass("UIScale")
if uiScale then
    uiScale.Scale = isMobile and 1.2 or 1.0   -- tuning: 1.2x for mobile readability
end
```

---

## Constraints

Hard rules for all Roblox UI work:

1. **Never use deprecated GUI methods.** This includes:
   - `Gui.Button()` — use `TextButton` or `ImageButton` with `.Activated`
   - `GuiMain` property — use `ScreenGui`
   - `SelectionImageObject` legacy patterns — use modern `GuiService` selection API
   - `Frame.Draggable` — implement drag via `UserInputService` input events
   - `TextLabel.TextStrokeColor3` / `TextStrokeTransparency` — still functional but prefer UIStroke for better control

2. **Always use TweenService for animations.** No `while wait()` loops, no `RunService.RenderStepped` hacks for simple tweens.

3. **Test on mobile viewport.** Use Studio's Device Emulator (menu: Test → Device → select phone). Every UI must be usable at 360×640.

4. **Use `UDim2.fromScale` / `UDim2.fromOffset` constructors** for clarity over raw `UDim2.new()` when the intent is clear.

5. **Destroy unused UI instances** to avoid memory leaks: `gui:Destroy()` or set `Enabled = false`.

6. **Replicate UI through StarterGui**, never by cloning into PlayerGui from a server script directly.

7. **All UI scripts must be LocalScripts** (or ModuleScripts required by LocalScripts). Server scripts cannot manipulate PlayerGui.

---

## Output Format

When generating Roblox UI code, provide:

1. **UI Hierarchy** — A tree showing all GuiObjects and their key properties.
2. **Luau Scripts** — LocalScript code with:
   - Service declarations at the top (`game:GetService(...)`)
   - Variable references to instances using `WaitForChild` when needed
   - Clear comments on tuning values (durations, sizes, positions)
   - Error handling for nil references
3. **Visual Adjustment Recommendations** — Notes on:
   - Spacing, sizing, and alignment values to tweak
   - Easing style/duration adjustments for feel
   - Mobile-specific overrides if applicable
   - Accessibility checks (contrast, touch targets)
