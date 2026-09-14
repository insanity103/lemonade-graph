# Roblox UI Animation — TweenService Reference

All UI animation should use `TweenService`. This reference covers production patterns
with tuned values for common UI transitions, feedback, and visual effects.

---

## TweenService Basics for UI

### Core setup

```lua
local TweenService = game:GetService("TweenService")

-- TweenInfo signature:
-- TweenInfo.new(time, easingStyle, easingDirection, repeatCount, reverses, delayTime)
local info = TweenInfo.new(
    0.3,                                -- time: duration in seconds
    Enum.EasingStyle.Quad,              -- easingStyle
    Enum.EasingDirection.Out,           -- easingDirection
    0,                                  -- repeatCount (0 = play once)
    false,                              -- reverses (true = ping-pong)
    0                                   -- delayTime before starting
)

-- Property goals: only tween GuiObject properties that affect visuals
local goals = {
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 200, 0, 100),
    BackgroundTransparency = 0.5,
    Rotation = 15,
    -- Size, Position, BackgroundTransparency, ImageTransparency,
    -- TextTransparency, Rotation, BackgroundColor3, ImageColor3, TextColor3
}

local tween = TweenService:Create(targetGuiObject, info, goals)
tween:Play()

-- Wait for completion (useful for sequencing)
tween.Completed:Wait()

-- Cancel a playing tween (starts new one to interrupt)
-- Simply calling :Play() on a new tween targeting the same object/property
-- automatically cancels the previous one.
```

### Easing styles reference

| Style | Curve | Best UI Use |
|---|---|---|
| `Linear` | Constant speed | Cooldown timers, progress fills |
| `Quad` | Smooth acceleration | General-purpose transitions |
| `Cubic` | Stronger acceleration | Sliding panels |
| `Quint` | Very strong acceleration | Large panel transitions |
| `Sine` | Gentle sinusoidal | Subtle looping animations |
| `Back` | Overshoots then settles | Playful popups, bouncy entrances |
| `Bounce` | Bouncy at end | Achievement popups, celebratory UI |
| `Elastic` | Spring overshoot | Attention-grabbing alerts |
| `Exponential` | Sharp curve | Quick snaps, cursor-like movement |

### Easing directions

| Direction | Behavior |
|---|---|
| `Out` | Decelerates to target — use for elements appearing |
| `In` | Accelerates away from start — use for elements disappearing |
| `InOut` | Symmetric ease — use for looping or position swaps |

---

## Page Transitions

### Slide left/right (enter/exit)

Use for navigation between full-screen panels (e.g., menu tabs, shop pages).

```lua
local TweenService = game:GetService("TweenService")

local SLIDE_DURATION = 0.35   -- tuning: slide speed
local slideInfo = TweenInfo.new(SLIDE_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function slideOutLeft(frame: Frame)
    TweenService:Create(frame, slideInfo, {
        Position = UDim2.new(-1, 0, 0, 0)   -- off-screen left
    }):Play()
end

local function slideInRight(frame: Frame)
    frame.Position = UDim2.new(1, 0, 0, 0)   -- start off-screen right
    frame.Visible = true
    TweenService:Create(frame, slideInfo, {
        Position = UDim2.new(0, 0, 0, 0)   -- slide to origin
    }):Play()
end

local function slideOutRight(frame: Frame)
    TweenService:Create(frame, slideInfo, {
        Position = UDim2.new(1, 0, 0, 0)   -- off-screen right
    }):Play()
end

local function slideInLeft(frame: Frame)
    frame.Position = UDim2.new(-1, 0, 0, 0)  -- start off-screen left
    frame.Visible = true
    TweenService:Create(frame, slideInfo, {
        Position = UDim2.new(0, 0, 0, 0)
    }):Play()
end

-- Page transition: old page slides out, new page slides in
local function navigateTo(currentPage: Frame, nextPage: Frame, direction: "forward" | "back")
    if direction == "forward" then
        slideOutLeft(currentPage)
        slideInRight(nextPage)
    else
        slideOutRight(currentPage)
        slideInLeft(nextPage)
    end
    task.delay(SLIDE_DURATION, function()
        currentPage.Visible = false
    end)
end
```

### Fade transition (modals)

```lua
local FADE_DURATION = 0.2   -- tuning: fade speed

local function fadeIn(frame: Frame)
    frame.BackgroundTransparency = 1
    -- Also fade text/image children
    for _, child in frame:GetDescendants() do
        if child:IsA("TextLabel") or child:IsA("TextButton") then
            child.TextTransparency = 1
        elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
            child.ImageTransparency = 1
        end
    end
    frame.Visible = true

    local info = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(frame, info, {BackgroundTransparency = 0}):Play()
    for _, child in frame:GetDescendants() do
        if child:IsA("TextLabel") or child:IsA("TextButton") then
            TweenService:Create(child, info, {TextTransparency = 0}):Play()
        elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
            TweenService:Create(child, info, {ImageTransparency = 0}):Play()
        end
    end
end

local function fadeOut(frame: Frame)
    local info = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    TweenService:Create(frame, info, {BackgroundTransparency = 1}):Play()
    for _, child in frame:GetDescendants() do
        if child:IsA("TextLabel") or child:IsA("TextButton") then
            TweenService:Create(child, info, {TextTransparency = 1}):Play()
        elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
            TweenService:Create(child, info, {ImageTransparency = 1}):Play()
        end
    end
    task.delay(FADE_DURATION, function()
        frame.Visible = false
    end)
end
```

### Scale popup (appear/disappear)

```lua
local POPUP_DURATION = 0.25   -- tuning: popup speed
local openInfo = TweenInfo.new(POPUP_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local closeInfo = TweenInfo.new(POPUP_DURATION * 0.8, Enum.EasingStyle.Back, Enum.EasingDirection.In)

local function popupOpen(frame: Frame)
    frame.Size = UDim2.new(0, 0, 0, 0)        -- start from zero
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Visible = true
    -- Target size should be stored/read from the frame's stored size
    local targetSize = frame:GetAttribute("TargetSize") or UDim2.fromOffset(300, 200)
    TweenService:Create(frame, openInfo, {Size = targetSize}):Play()
end

local function popupClose(frame: Frame)
    TweenService:Create(frame, closeInfo, {Size = UDim2.new(0, 0, 0, 0)}):Play()
    task.delay(POPUP_DURATION * 0.8, function()
        frame.Visible = false
    end)
end
```

---

## Button Feedback

### Hover scale-up, press scale-down, release tween back

```lua
local TweenService = game:GetService("TweenService")

local HOVER_SCALE = 1.05     -- tuning: how much to grow on hover
local PRESS_SCALE = 0.95     -- tuning: how much to shrink on press
local TWEEN_SPEED = 0.12     -- tuning: feedback animation speed

local hoverInfo = TweenInfo.new(TWEEN_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local pressInfo = TweenInfo.new(TWEEN_SPEED * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local releaseInfo = TweenInfo.new(TWEEN_SPEED, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function setupButtonFeedback(button: GuiButton)
    local originalSize = button.Size
    local originalPos = button.Position

    -- Calculate sizes for scaling (assumes AnchorPoint is centered)
    local function scaledSize(scale: number)
        return UDim2.new(
            originalSize.X.Scale * scale, originalSize.X.Offset * scale,
            originalSize.Y.Scale * scale, originalSize.Y.Offset * scale
        )
    end

    button.MouseEnter:Connect(function()
        TweenService:Create(button, hoverInfo, {Size = scaledSize(HOVER_SCALE)}):Play()
    end)

    button.MouseLeave:Connect(function()
        TweenService:Create(button, releaseInfo, {Size = originalSize}):Play()
    end)

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            TweenService:Create(button, pressInfo, {Size = scaledSize(PRESS_SCALE)}):Play()
        end
    end)

    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            TweenService:Create(button, releaseInfo, {Size = scaledSize(HOVER_SCALE)}):Play()
        end
    end)

    -- Ensure AnchorPoint is centered for scaling to work properly
    if button.AnchorPoint ~= Vector2.new(0.5, 0.5) then
        warn("Button feedback requires AnchorPoint (0.5, 0.5) for centered scaling")
    end
end

-- Usage:
-- setupButtonFeedback(myTextButton)
-- setupButtonFeedback(myImageButton)
```

### Press feedback with color shift

```lua
local function setupColorFeedback(button: GuiButton, baseColor: Color3, hoverColor: Color3, pressColor: Color3)
    local speed = 0.1   -- tuning: color transition speed
    local info = TweenInfo.new(speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    button.BackgroundColor3 = baseColor

    button.MouseEnter:Connect(function()
        TweenService:Create(button, info, {BackgroundColor3 = hoverColor}):Play()
    end)

    button.MouseLeave:Connect(function()
        TweenService:Create(button, info, {BackgroundColor3 = baseColor}):Play()
    end)

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            TweenService:Create(button, TweenInfo.new(speed * 0.5), {BackgroundColor3 = pressColor}):Play()
        end
    end)

    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            TweenService:Create(button, info, {BackgroundColor3 = hoverColor}):Play()
        end
    end)
end

-- Usage:
-- setupColorFeedback(btn, Color3.fromRGB(50, 50, 70), Color3.fromRGB(70, 70, 100), Color3.fromRGB(40, 40, 55))
```

---

## Loading Spinner

A continuously rotating ImageLabel.

**Hierarchy:**
```
Frame ("SpinnerContainer")
└── ImageLabel ("Spinner")
    ├── Size = UDim2.fromOffset(48, 48)          -- tuning: spinner size
    ├── AnchorPoint = (0.5, 0.5)
    ├── Position = UDim2.fromScale(0.5, 0.5)
    ├── Image = "rbxassetid://SPINNER_ASSET_ID"  -- a circular loading icon
    ├── ImageColor3 = Color3.fromRGB(255, 255, 255)
    ├── BackgroundTransparency = 1
    └── Rotation = 0   -- animated continuously
```

**Script:**
```lua
local TweenService = game:GetService("TweenService")

local function createSpinner(parent: GuiObject): ImageLabel
    local spinner = Instance.new("ImageLabel")
    spinner.Name = "Spinner"
    spinner.Size = UDim2.fromOffset(48, 48)   -- tuning: spinner diameter
    spinner.AnchorPoint = Vector2.new(0.5, 0.5)
    spinner.Position = UDim2.fromScale(0.5, 0.5)
    spinner.BackgroundTransparency = 1
    spinner.Image = "rbxassetid://3939272252"   -- built-in circular icon (update asset ID as needed)
    spinner.ImageColor3 = Color3.fromRGB(255, 255, 255)
    spinner.Parent = parent

    -- Continuous rotation
    local spinInfo = TweenInfo.new(
        1.0,                              -- tuning: seconds per full rotation
        Enum.EasingStyle.Linear,          -- constant speed
        Enum.EasingDirection.InOut,
        -1,                               -- repeat forever (-1 = infinite)
        false
    )
    local spinTween = TweenService:Create(spinner, spinInfo, {Rotation = 360})
    spinTween:Play()

    return spinner   -- caller can set spinner.Visible = false to stop
end

-- Usage:
-- local spinner = createSpinner(loadingPanel)
-- task.delay(3, function()
--     spinner.Parent:Destroy()   -- remove when loading completes
-- end)
```

---

## Progress Bar

Tween the inner fill frame's `Size.X.Scale` to represent progress.

```lua
local TweenService = game:GetService("TweenService")

local PROGRESS_TWEEN_DURATION = 0.5   -- tuning: how fast the bar fills

local function tweenProgressBar(fillFrame: Frame, fromPercent: number, toPercent: number)
    -- fromPercent/toPercent: 0.0 to 1.0
    fillFrame.Size = UDim2.new(math.clamp(fromPercent, 0, 1), 0, 1, 0)

    local tween = TweenService:Create(fillFrame, TweenInfo.new(
        PROGRESS_TWEEN_DURATION,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    ), {
        Size = UDim2.new(math.clamp(toPercent, 0, 1), 0, 1, 0)
    })
    tween:Play()
    return tween
end

-- Color shifts as progress increases
local function tweenProgressBarWithColor(fillFrame: Frame, fromPct: number, toPct: number)
    local tween = tweenProgressBar(fillFrame, fromPct, toPct)

    -- Interpolate color: red (0%) → yellow (50%) → green (100%)
    local color
    if toPct > 0.5 then
        color = Color3.new(2 * (1 - toPct), 1, 0)
    else
        color = Color3.new(1, 2 * toPct, 0)
    end
    TweenService:Create(fillFrame, TweenInfo.new(PROGRESS_TWEEN_DURATION), {
        BackgroundColor3 = color
    }):Play()

    return tween
end

-- Usage:
-- tweenProgressBar(healthFill, 0.8, 0.3)   -- health drops from 80% to 30%
-- tweenProgressBarWithColor(xpFill, 0.6, 0.75)  -- XP gains with color update
```

---

## Notification Queue

Sequential notifications that slide in, hold, then slide out before the next appears.

```lua
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local NOTIFY_HOLD_TIME = 3.0     -- tuning: how long each notification stays visible
local NOTIFY_SLIDE_TIME = 0.3    -- tuning: slide animation duration
local NOTIFY_WIDTH = 300         -- tuning: notification width
local NOTIFY_HEIGHT = 50         -- tuning: notification height
local NOTIFY_MARGIN = 12         -- tuning: margin from screen edge

local notificationQueue: {string} = {}
local isProcessing = false

local function createNotificationGui(message: string): ScreenGui
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.DisplayOrder = 95
    gui.Parent = playerGui

    local toast = Instance.new("Frame")
    toast.AnchorPoint = Vector2.new(1, 1)
    toast.Position = UDim2.new(1, NOTIFY_WIDTH + NOTIFY_MARGIN, 1, -NOTIFY_MARGIN)
    toast.Size = UDim2.fromOffset(NOTIFY_WIDTH, NOTIFY_HEIGHT)
    toast.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    toast.BorderSizePixel = 0
    toast.Parent = gui
    Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -24, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = message
    label.Parent = toast

    return gui, toast
end

local function processQueue()
    if isProcessing then return end
    isProcessing = true

    while #notificationQueue > 0 do
        local message = table.remove(notificationQueue, 1)
        local gui, toast = createNotificationGui(message)

        local slideInInfo = TweenInfo.new(NOTIFY_SLIDE_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        local slideOutInfo = TweenInfo.new(NOTIFY_SLIDE_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

        -- Slide in
        TweenService:Create(toast, slideInInfo, {
            Position = UDim2.new(1, -NOTIFY_MARGIN, 1, -NOTIFY_MARGIN)
        }):Play()

        -- Hold
        task.wait(NOTIFY_HOLD_TIME)

        -- Slide out
        TweenService:Create(toast, slideOutInfo, {
            Position = UDim2.new(1, NOTIFY_WIDTH + NOTIFY_MARGIN, 1, -NOTIFY_MARGIN)
        }):Play()
        task.wait(NOTIFY_SLIDE_TIME)

        gui:Destroy()
    end

    isProcessing = false
end

local function enqueueNotification(message: string)
    table.insert(notificationQueue, message)
    task.spawn(processQueue)
end

-- Usage:
-- enqueueNotification("Item purchased: Iron Sword")
-- enqueueNotification("Achievement unlocked!")
-- enqueueNotification("Quest complete!")
```

---

## Particle-Like UI Effects

Multiple small frames with randomized tweens to create confetti, sparkles, or burst effects.

```lua
local TweenService = game:GetService("TweenService")

local PARTICLE_COUNT = 20       -- tuning: number of particles
local PARTICLE_LIFETIME = 1.5   -- tuning: how long particles live (seconds)
local SPREAD_RADIUS = 200       -- tuning: how far particles travel (pixels)
local PARTICLE_SIZE = 8         -- tuning: particle size in pixels

local function spawnConfetti(parent: GuiObject, origin: UDim2)
    for i = 1, PARTICLE_COUNT do
        local particle = Instance.new("Frame")
        particle.Name = "Particle_" .. i
        particle.Size = UDim2.fromOffset(PARTICLE_SIZE, PARTICLE_SIZE)
        particle.Position = origin
        particle.AnchorPoint = Vector2.new(0.5, 0.5)
        particle.BorderSizePixel = 0
        particle.Rotation = math.random(0, 360)

        -- Random color from a palette
        local colors = {
            Color3.fromRGB(255, 100, 100),   -- red
            Color3.fromRGB(100, 255, 100),   -- green
            Color3.fromRGB(100, 100, 255),   -- blue
            Color3.fromRGB(255, 255, 100),   -- yellow
            Color3.fromRGB(255, 100, 255),   -- magenta
        }
        particle.BackgroundColor3 = colors[math.random(1, #colors)]
        particle.Parent = parent

        -- Random destination
        local angle = math.rad(math.random(0, 360))
        local distance = math.random(SPREAD_RADIUS * 0.3, SPREAD_RADIUS)
        local offsetX = math.cos(angle) * distance
        local offsetY = math.sin(angle) * distance

        local targetPos = UDim2.new(
            origin.X.Scale, origin.X.Offset + offsetX,
            origin.Y.Scale, origin.Y.Offset + offsetY
        )

        -- Staggered start for organic feel
        local delay = math.random() * 0.1   -- tuning: max stagger delay
        local lifetime = PARTICLE_LIFETIME + math.random() * 0.3   -- tuning: lifetime variance

        local info = TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(particle, info, {
            Position = targetPos,
            Rotation = math.random(180, 720),
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(PARTICLE_SIZE * 0.3, PARTICLE_SIZE * 0.3)   -- shrink as they fly
        })

        task.delay(delay, function()
            tween:Play()
        end)

        -- Cleanup
        task.delay(delay + lifetime + 0.1, function()
            particle:Destroy()
        end)
    end
end

-- Sparkle effect: smaller, faster, golden
local function spawnSparkle(parent: GuiObject, origin: UDim2)
    local SPARKLE_COUNT = 12
    local SPARKLE_LIFETIME = 0.8
    local SPARKLE_SIZE = 6

    for i = 1, SPARKLE_COUNT do
        local spark = Instance.new("Frame")
        spark.Size = UDim2.fromOffset(SPARKLE_SIZE, SPARKLE_SIZE)
        spark.Position = origin
        spark.AnchorPoint = Vector2.new(0.5, 0.5)
        spark.BackgroundColor3 = Color3.fromRGB(255, 230, 120)   -- warm gold
        spark.BorderSizePixel = 0
        spark.Parent = parent
        Instance.new("UICorner", spark).CornerRadius = UDim.new(1, 0)   -- circle

        local angle = math.rad((i / SPARKLE_COUNT) * 360)
        local distance = math.random(40, 100)   -- tuning: sparkle spread

        local tween = TweenService:Create(spark, TweenInfo.new(
            SPARKLE_LIFETIME,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        ), {
            Position = UDim2.new(
                origin.X.Scale, origin.X.Offset + math.cos(angle) * distance,
                origin.Y.Scale, origin.Y.Offset + math.sin(angle) * distance
            ),
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(2, 2)
        })

        task.delay(math.random() * 0.05, function()   -- tuning: max stagger
            tween:Play()
        end)

        task.delay(SPARKLE_LIFETIME + 0.1, function()
            spark:Destroy()
        end)
    end
end

-- Pulse ring: expanding circle that fades
local function spawnPulseRing(parent: GuiObject, origin: UDim2)
    local ring = Instance.new("Frame")
    ring.Size = UDim2.fromOffset(20, 20)
    ring.Position = origin
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ring.BackgroundTransparency = 0.5
    ring.BorderSizePixel = 0
    ring.Parent = parent
    Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)

    local PULSE_DURATION = 0.6   -- tuning: ring expansion time
    local PULSE_SIZE = 120       -- tuning: final ring diameter

    local tween = TweenService:Create(ring, TweenInfo.new(
        PULSE_DURATION,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    ), {
        Size = UDim2.fromOffset(PULSE_SIZE, PULSE_SIZE),
        BackgroundTransparency = 1
    })

    tween:Play()
    tween.Completed:Connect(function()
        ring:Destroy()
    end)
end

-- Usage:
-- spawnConfetti(screenGui, UDim2.fromScale(0.5, 0.5))
-- spawnSparkle(screenGui, UDim2.new(0, itemButton.AbsolutePosition.X, 0, itemButton.AbsolutePosition.Y))
-- spawnPulseRing(screenGui, UDim2.fromScale(0.5, 0.5))
```

---

## Compound Animation Sequences

Chaining multiple tweens using `task.delay` and `Tween.Completed`.

### Staggered list appearance

Items in a list appear one by one with a slide-up + fade-in.

```lua
local TweenService = game:GetService("TweenService")

local STAGGER_DELAY = 0.06     -- tuning: delay between each item
local ITEM_DURATION = 0.3      -- tuning: per-item animation length
local SLIDE_DISTANCE = 20      -- tuning: pixels to slide up

local function staggerAppear(items: {GuiObject})
    for i, item in items do
        local originalPos = item.Position
        item.Position = UDim2.new(
            originalPos.X.Scale, originalPos.X.Offset,
            originalPos.Y.Scale, originalPos.Y.Offset + SLIDE_DISTANCE
        )
        item.TextTransparency = 1   -- or BackgroundTransparency for frames

        task.delay(STAGGER_DELAY * (i - 1), function()
            TweenService:Create(item, TweenInfo.new(ITEM_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Position = originalPos,
                TextTransparency = 0
            }):Play()
        end)
    end
end

-- Usage:
-- staggerAppear({menuItem1, menuItem2, menuItem3, menuItem4, menuItem5})
```

### Counter animation (number counting up)

Visually counts a number from one value to another using an updating TextLabel.

```lua
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local COUNT_DURATION = 1.0   -- tuning: how long the count takes

local function animateCounter(label: TextLabel, fromValue: number, toValue: number)
    local startTime = tick()
    local connection
    connection = RunService.RenderStepped:Connect(function()
        local elapsed = tick() - startTime
        local alpha = math.clamp(elapsed / COUNT_DURATION, 0, 1)

        -- Ease the progress for smooth deceleration
        local eased = 1 - (1 - alpha) ^ 2   -- quadratic ease out
        local currentValue = math.floor(fromValue + (toValue - fromValue) * eased)
        label.Text = tostring(currentValue)

        if alpha >= 1 then
            label.Text = tostring(toValue)
            connection:Disconnect()
        end
    end)
end

-- Usage:
-- animateCounter(coinsLabel, 0, 1500)   -- watch coins count up from 0 to 1500
```

### Shake effect (error feedback)

Rapidly jitters a frame to indicate an error (e.g., wrong password, insufficient funds).

```lua
local TweenService = game:GetService("TweenService")

local SHAKE_INTENSITY = 5    -- tuning: pixels of displacement
local SHAKE_SPEED = 0.04     -- tuning: time per shake cycle
local SHAKE_COUNT = 4        -- tuning: number of shakes

local function shakeFrame(frame: Frame)
    local originalPos = frame.Position

    for i = 1, SHAKE_COUNT do
        local offsetX = (i % 2 == 0) and SHAKE_INTENSITY or -SHAKE_INTENSITY
        local tween = TweenService:Create(frame, TweenInfo.new(SHAKE_SPEED), {
            Position = UDim2.new(
                originalPos.X.Scale, originalPos.X.Offset + offsetX,
                originalPos.Y.Scale, originalPos.Y.Offset
            )
        })
        tween:Play()
        tween.Completed:Wait()
    end

    -- Return to original position
    TweenService:Create(frame, TweenInfo.new(SHAKE_SPEED), {Position = originalPos}):Play()
end

-- Usage:
-- shakeFrame(loginPanel)   -- shake on invalid credentials
```
