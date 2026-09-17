-- ReplicatedStorage/PanelChrome.luau
-- Shared visual chrome for modal GUI panels (Reforge, Vault, Merchant, Quest, Main Menu):
-- a consistent bordered shell with a title banner and a close button, so every panel reads
-- as one system instead of five independently-styled ones. Returns plain
-- Instances -- works from imperative scripts (set .Parent yourself) and from Fusion (drop
-- PanelChrome.build(...).Frame straight into a [Children] table).
local PanelChrome = {}

PanelChrome.COLORS = {
	Panel = Color3.fromRGB(18, 18, 22), PanelLight = Color3.fromRGB(26, 26, 32), Dark = Color3.fromRGB(10, 10, 13),
	Stroke = Color3.fromRGB(45, 45, 55), StrokeBright = Color3.fromRGB(75, 75, 90), Gold = Color3.fromRGB(255, 215, 60),
	Text = Color3.fromRGB(245, 245, 250), Muted = Color3.fromRGB(160, 160, 175), Button = Color3.fromRGB(35, 35, 45),
	ButtonHover = Color3.fromRGB(55, 55, 65), Ember = Color3.fromRGB(232, 112, 42), Success = Color3.fromRGB(80, 220, 140),
	Error = Color3.fromRGB(255, 85, 85),
}

PanelChrome.RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180), Uncommon = Color3.fromRGB(80, 200, 120), Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(180, 80, 240), Legendary = Color3.fromRGB(255, 200, 40),
}

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
	return c
end
PanelChrome.corner = corner

-- Builds a bordered modal shell: background, corner radius, accent stroke, a title banner
-- (title + optional subtitle) with a header divider, and a close button. The frame is
-- returned unparented -- parent it yourself, or hand it to Fusion.
--
-- props: { name, title, subtitle, accentColor, size }
function PanelChrome.build(props)
	local accent = props.accentColor or PanelChrome.COLORS.Ember

	local modal = Instance.new("Frame")
	modal.Name = props.name or "Modal"
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = props.size or UDim2.fromOffset(800, 600)
	modal.BackgroundColor3 = PanelChrome.COLORS.Panel
	modal.BorderSizePixel = 0
	corner(modal, 14)

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.Parent = modal

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(20, 14)
	titleLabel.Size = UDim2.new(1, -220, 0, 32)
	titleLabel.Font = Enum.Font.Fantasy
	titleLabel.TextSize = props.titleSize or 30
	titleLabel.TextColor3 = accent
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = props.title or ""
	titleLabel.Parent = modal

	local subtitleLabel
	if props.subtitle then
		subtitleLabel = Instance.new("TextLabel")
		subtitleLabel.Name = "Subtitle"
		subtitleLabel.BackgroundTransparency = 1
		subtitleLabel.Position = UDim2.fromOffset(20, 46)
		subtitleLabel.Size = UDim2.new(1, -220, 0, 20)
		subtitleLabel.Font = Enum.Font.GothamMedium
		subtitleLabel.TextSize = 13
		subtitleLabel.TextColor3 = PanelChrome.COLORS.Muted
		subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
		subtitleLabel.Text = props.subtitle
		subtitleLabel.Parent = modal
	end

	local headerBottom = props.subtitle and 74 or 52

	local divider = Instance.new("Frame")
	divider.Name = "HeaderDivider"
	divider.BackgroundColor3 = accent
	divider.BackgroundTransparency = 0.7
	divider.BorderSizePixel = 0
	divider.Position = UDim2.fromOffset(20, headerBottom - 2)
	divider.Size = UDim2.new(1, -40, 0, 1)
	divider.Parent = modal

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.Position = UDim2.new(1, -14, 0, 14)
	closeBtn.Size = UDim2.fromOffset(34, 34)
	closeBtn.BackgroundColor3 = PanelChrome.COLORS.Button
	closeBtn.Text = "X"
	closeBtn.TextColor3 = PanelChrome.COLORS.Text
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 18
	closeBtn.Parent = modal
	corner(closeBtn, 8)

	return {
		Frame = modal,
		TitleLabel = titleLabel,
		SubtitleLabel = subtitleLabel,
		CloseButton = closeBtn,
		HeaderBottom = headerBottom, -- y-offset where panel-specific body content should start
	}
end

return PanelChrome
