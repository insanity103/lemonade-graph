--// ReforgeGuiFusion  (Fusion prototype of the Reforge anvil, for side-by-side comparison
-- against the original ReforgeGui.client.luau. Same remotes, same feature set: pick a
-- relic sword, pay gold, watch the modifier reel spin, reveal the result.
--
-- The reel/spin/reveal sequence stays imperative (a one-shot procedural animation isn't
-- a good fit for declarative state, and Fusion doesn't try to replace TweenService for
-- that). Everything else -- list rendering, lock chips, button text/color, the odds
-- popup, the pity status -- is Fusion state driving the UI, instead of the original's
-- manual "destroy all children and rebuild" pattern in render()/rebuildLockRow().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local REFORGE = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("ReforgeAction")
local SwordValue = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SwordValue"))
local WeaponModifiers = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponModifiers"))
local AudioManager = require(ReplicatedStorage:WaitForChild("AudioManager"))

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local scope = Fusion.scoped(Fusion)
local peek = Fusion.peek
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
local COLORS = PanelChrome.COLORS
local RARITY_COLORS = PanelChrome.RARITY_COLORS
local TIER_COLORS = {
	Color3.fromRGB(170, 170, 176), Color3.fromRGB(90, 200, 120), Color3.fromRGB(80, 150, 255),
	Color3.fromRGB(190, 90, 240), Color3.fromRGB(255, 200, 40), Color3.fromRGB(255, 80, 80),
}

local CARD_W, CARD_H, CARD_GAP = 132, 150, 8
local REEL_CARDS = 48
local LAND_INDEX = 40 -- the result sits here; a few filler cards trail it
local SPIN_TIME = 4.6

-- ── Reactive state ───────────────────────────────────────────────────────────
local goldValue = scope:Value(0)
local rowsValue = scope:Value({})
local selectedToolName = scope:Value(nil :: string?)
local lockedSet = scope:Value({} :: { [string]: boolean })
local spinningValue = scope:Value(false)
local skipAnimationValue = scope:Value(false)
local oddsInfoValue = scope:Value(nil :: any)
local oddsPopupVisible = scope:Value(false)
local overlayVisible = scope:Value(false)

local selectedC = scope:Computed(function(use)
	local rows = use(rowsValue)
	local name = use(selectedToolName)
	if not name then return nil end
	for _, info in ipairs(rows) do
		if info.toolName == name then return info end
	end
	return nil
end)

local modsC = scope:Computed(function(use)
	local info = use(selectedC)
	return SwordValue.modifiersFromPrefixes(info and info.prefixes or "")
end)

local lockNamesC = scope:Computed(function(use)
	local locked = use(lockedSet)
	local names = {}
	for _, mod in ipairs(use(modsC)) do
		if locked[mod.name] then table.insert(names, mod.name) end
	end
	return names
end)

local costC = scope:Computed(function(use)
	local info = use(selectedC)
	if not info then return 0 end
	local names = use(lockNamesC)
	if #names > 0 then
		return SwordValue.rerollCostWithLocks({ Rarity = info.rarity, Prefixes = info.prefixes, ExtraSlot = info.blessed,
			BossTier = info.tier }, names)
	end
	local odds = use(oddsInfoValue)
	if odds and (odds.freeIn or 1) <= 0 then return 0 end
	return info.cost
end)

local affordC = scope:Computed(function(use) return use(goldValue) >= use(costC) end)

local function describeMods(prefixes: string, blessed: boolean)
	local parts = {}
	if blessed then table.insert(parts, "Blessed slot") end
	for _, mod in ipairs(SwordValue.modifiersFromPrefixes(prefixes)) do
		local tierData = WeaponModifiers.Categories[mod.category].Tiers[mod.tier]
		table.insert(parts, string.format("%s (T%d %s)", mod.name, mod.tier, tierData and tierData.desc or mod.category))
	end
	return #parts > 0 and table.concat(parts, "  ·  ") or "No modifiers"
end

local strikeTextC = scope:Computed(function(use)
	if use(spinningValue) then return "Reforging..." end
	local info = use(selectedC)
	if not info then return "Select a sword" end
	local cost = use(costC)
	local names = use(lockNamesC)
	if cost == 0 then return "Strike the anvil  ·  FREE" end
	if #names > 0 then return string.format("Strike, keeping %d  ·  %d gold", #names, cost) end
	return string.format("Strike the anvil  ·  %d gold", cost)
end)

local strikeBgC = scope:Computed(function(use)
	if use(spinningValue) then return COLORS.Button end
	if not use(selectedC) then return COLORS.Button end
	return use(affordC) and COLORS.Ember or COLORS.Button
end)

local strikeTextColorC = scope:Computed(function(use)
	if use(spinningValue) then return COLORS.Muted end
	if not use(selectedC) then return COLORS.Muted end
	return use(affordC) and Color3.fromRGB(20, 12, 8) or COLORS.Muted
end)

local goldTextC = scope:Computed(function(use) return "Gold " .. tostring(use(goldValue)) end)
local selectedTitleTextC = scope:Computed(function(use)
	local info = use(selectedC)
	return info and info.name or "Pick a sword"
end)
local selectedTitleColorC = scope:Computed(function(use)
	local info = use(selectedC)
	return info and (RARITY_COLORS[info.rarity] or COLORS.Text) or COLORS.Text
end)
local selectedInfoTextC = scope:Computed(function(use)
	local info = use(selectedC)
	if not info then return "Choose a relic sword on the left." end
	return string.format("%s  ·  rating %s  ·  %s", info.rarity, SwordValue.short(info.rating), describeMods(info.prefixes, info.blessed))
end)

local pityTextC = scope:Computed(function(use)
	local odds = use(oddsInfoValue)
	if not odds then return "" end
	local pity, after = odds.pity or 0, odds.pityAfter or 5
	if pity >= after then return "Guaranteed lucky roll ready!" end
	return string.format("Guaranteed lucky roll in %d", after - pity)
end)

local oddsPopupTextC = scope:Computed(function(use)
	local info = use(selectedC)
	local odds = use(oddsInfoValue)
	if not info or not odds or not odds.odds or not odds.odds[info.rarity] then return "" end
	local o = odds.odds[info.rarity]
	local parts = {}
	for tier = 1, #o.tiers do
		table.insert(parts, string.format("T%d %.1f%%", tier, o.tiers[tier] * 100))
	end
	local pity, after = odds.pity or 0, odds.pityAfter or 5
	local pityText = pity >= after
		and string.format("Guaranteed lucky roll ready: next reforge guarantees a T%d+ modifier.", odds.pityTier or 4)
		or string.format("Guaranteed lucky roll in %d / %d reforges (then a T%d+ modifier is guaranteed).", pity, after, odds.pityTier or 4)
	return string.format("%s odds per modifier: %s.  %s", info.rarity, table.concat(parts, "  "), pityText)
end)

local statsTextC = scope:Computed(function(use)
	local odds = use(oddsInfoValue)
	if not odds then return "" end
	local freeIn = odds.freeIn or 0
	local freeText = freeIn <= 0 and "Free reforge ready" or string.format("Free reforge in %dh %02dm", math.floor(freeIn / 3600), math.floor(freeIn % 3600 / 60))
	return string.format("%s  ·  best roll %s  ·  %d reforges", freeText, SwordValue.short(odds.best or 0), odds.count or 0)
end)

local skipTextC = scope:Computed(function(use)
	return use(skipAnimationValue) and "Animation: skipped" or "Animation: on"
end)

-- ── Actions ──────────────────────────────────────────────────────────────────
local function toggleLock(modName: string)
	if peek(spinningValue) then return end
	local copy = table.clone(peek(lockedSet))
	copy[modName] = (not copy[modName]) or nil
	lockedSet:set(copy)
end

local function selectTool(toolName: string)
	if peek(spinningValue) then return end
	if peek(selectedToolName) ~= toolName then
		lockedSet:set({})
	end
	selectedToolName:set(toolName)
end

local function setOddsPopupVisible(visible: boolean)
	oddsPopupVisible:set(visible)
end

local function close()
	if peek(spinningValue) then return end
	overlayVisible:set(false)
	setOddsPopupVisible(false)
end

local function lockList()
	return peek(lockNamesC)
end

local function currentCost()
	return peek(costC)
end

-- ── Reactive list: sword rows ────────────────────────────────────────────────
local listRows = scope:ForPairs(rowsValue, function(use, innerScope, index, info)
	local isSelected = innerScope:Computed(function(use2) return use2(selectedToolName) == info.toolName end)
	local row = innerScope:New "Frame" {
		Name = info.toolName,
		LayoutOrder = index,
		Size = UDim2.new(1, -6, 0, 66),
		BackgroundColor3 = COLORS.Panel,
		BorderSizePixel = 0,
		[Children] = {
			innerScope:New "UICorner" { CornerRadius = UDim.new(0, 8) },
			innerScope:New "UIStroke" {
				Color = RARITY_COLORS[info.rarity] or COLORS.Stroke,
				Transparency = innerScope:Computed(function(use2) return use2(isSelected) and 0 or 0.6 end),
			},
			innerScope:New "TextLabel" {
				Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 18), BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = RARITY_COLORS[info.rarity] or COLORS.Text, Text = info.name, TextTruncate = Enum.TextTruncate.AtEnd,
			},
			innerScope:New "TextLabel" {
				Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 16), BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = COLORS.Muted, TextXAlignment = Enum.TextXAlignment.Left,
				Text = string.format("%s · rating %s%s", info.rarity, SwordValue.short(info.rating), info.equipped and " · equipped" or ""),
				TextTruncate = Enum.TextTruncate.AtEnd,
			},
			innerScope:New "TextLabel" {
				Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 0, 16), BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = COLORS.Gold, TextXAlignment = Enum.TextXAlignment.Left,
				Text = string.format("Reforge: %d gold", info.cost),
			},
			innerScope:New "TextButton" {
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
				[OnEvent "Activated"] = function()
					if not peek(spinningValue) then selectTool(info.toolName) end
				end,
			},
		},
	}
	return index, row
end)

-- ── Reactive list: lock chips (one per modifier on the selected sword) ──────
local lockChips = scope:ForPairs(modsC, function(use, innerScope, index, mod)
	local isLocked = innerScope:Computed(function(use2) return use2(lockedSet)[mod.name] == true end)
	local chip = innerScope:New "TextButton" {
		LayoutOrder = index,
		Size = UDim2.fromOffset(math.max(84, #mod.name * 8 + 34), 26),
		BackgroundColor3 = innerScope:Computed(function(use2) return use2(isLocked) and COLORS.Ember or COLORS.Button end),
		TextColor3 = innerScope:Computed(function(use2) return use2(isLocked) and Color3.fromRGB(20, 12, 8) or TIER_COLORS[mod.tier] end),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		Text = innerScope:Computed(function(use2)
			local odds = use2(oddsInfoValue)
			local factors = (odds and odds.lockTierFactor) or SwordValue.LOCK_TIER_FACTOR
			return string.format("%s T%d  +%d%%", mod.name, mod.tier, math.floor((factors[mod.tier] or 0) * 100 + 0.5))
		end),
		[Children] = { innerScope:New "UICorner" { CornerRadius = UDim.new(0, 6) } },
		[OnEvent "Activated"] = function() toggleLock(mod.name) end,
	}
	return index, chip
end)
local lockPrefixTextC = scope:Computed(function(use)
	return #use(modsC) > 0 and "Lock:" or ""
end)

-- ── Scaffolding ──────────────────────────────────────────────────────────────
local screenGui = scope:New "ScreenGui" {
	Name = "ReforgeGuiFusion",
	ResetOnSpawn = false,
	DisplayOrder = 22,
	Parent = playerGui,
}

local reveal = scope:New "Frame" {
	Position = UDim2.fromOffset(14, 84 + CARD_H + 36),
	Size = UDim2.new(1, -28, 0, 100),
	BackgroundColor3 = COLORS.Dark,
	BorderSizePixel = 0,
	Visible = false,
	[Children] = { scope:New "UICorner" { CornerRadius = UDim.new(0, 10) } },
}
local revealName = scope:New "TextLabel" {
	Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 22), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = COLORS.Text, TextXAlignment = Enum.TextXAlignment.Left,
	Parent = reveal,
}
local revealMods = scope:New "TextLabel" {
	Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 34), BackgroundTransparency = 1,
	TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = COLORS.Text,
	TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamMedium,
	Parent = reveal,
}
local revealRating = scope:New "TextLabel" {
	Position = UDim2.fromOffset(12, 64), Size = UDim2.new(1, -24, 0, 22), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = COLORS.Text, TextXAlignment = Enum.TextXAlignment.Left,
	Parent = reveal,
}

local idleHint = scope:New "TextLabel" {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center,
	TextSize = 14, TextColor3 = COLORS.Muted, Font = Enum.Font.GothamMedium,
	Text = "The anvil is cold. Select a sword and strike.",
}
local strip = scope:New "Frame" {
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset((CARD_W + CARD_GAP) * REEL_CARDS, CARD_H),
	Position = UDim2.fromOffset(0, 12),
}
local reelWindow = scope:New "Frame" {
	Position = UDim2.fromOffset(14, 84),
	Size = UDim2.new(1, -28, 0, CARD_H + 24),
	BackgroundColor3 = COLORS.Dark,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	[Children] = {
		scope:New "UICorner" { CornerRadius = UDim.new(0, 10) },
		strip,
		scope:New "Frame" {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 3, 1, 0),
			BackgroundColor3 = COLORS.Ember, BorderSizePixel = 0, ZIndex = 5,
		},
		idleHint,
	},
}

local chrome = PanelChrome.build({
	name = "Modal",
	title = "Reforge",
	subtitle = "Pay gold to re-roll a relic sword's modifiers. Rarity and Blessed slots stay; everything else is chance.",
	accentColor = COLORS.Ember,
	size = UDim2.fromOffset(1000, 630),
})
chrome.CloseButton.Activated:Connect(close)

scope:New "TextLabel" {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 18), Size = UDim2.fromOffset(180, 24),
	BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Right, TextSize = 16,
	TextColor3 = COLORS.Gold, Font = Enum.Font.GothamMedium, Text = goldTextC, Parent = chrome.Frame,
}
scope:New "TextLabel" {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 68), Size = UDim2.fromOffset(300, 20),
	BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12,
	TextColor3 = COLORS.Muted, Font = Enum.Font.GothamMedium, Text = statsTextC, Parent = chrome.Frame,
}

scope:New "ScrollingFrame" {
	Parent = chrome.Frame,
	Position = UDim2.fromOffset(20, 96), Size = UDim2.new(0, 280, 1, -116),
	BackgroundColor3 = COLORS.PanelLight, BorderSizePixel = 0, ScrollBarThickness = 6,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	[Children] = {
		scope:New "UICorner" { CornerRadius = UDim.new(0, 10) },
		scope:New "UIListLayout" { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder },
		scope:New "UIPadding" { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) },
		listRows,
	},
}

scope:New "Frame" {
	Parent = chrome.Frame,
	Position = UDim2.fromOffset(316, 96), Size = UDim2.new(1, -336, 1, -116),
	BackgroundColor3 = COLORS.PanelLight, BorderSizePixel = 0,
	[Children] = {
		scope:New "UICorner" { CornerRadius = UDim.new(0, 10) },
		scope:New "TextLabel" {
			Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 0, 22), BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = selectedTitleColorC, Text = selectedTitleTextC,
		},
		scope:New "TextLabel" {
			Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -28, 0, 36), BackgroundTransparency = 1,
			TextSize = 12, TextColor3 = COLORS.Muted, TextWrapped = true, Font = Enum.Font.GothamMedium,
			TextYAlignment = Enum.TextYAlignment.Top, TextXAlignment = Enum.TextXAlignment.Left, Text = selectedInfoTextC,
		},
		reelWindow,
		reveal,
		scope:New "Frame" {
			Position = UDim2.fromOffset(14, 84 + CARD_H + 36 + 100 + 8),
			Size = UDim2.new(1, -28, 0, 26),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New "UIListLayout" { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) },
				scope:New "TextLabel" {
					Size = UDim2.fromOffset(52, 26), BackgroundTransparency = 1, TextSize = 11, TextColor3 = COLORS.Muted,
					Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, Text = lockPrefixTextC,
				},
				lockChips,
			},
		},
		scope:New "Frame" {
			Position = UDim2.fromOffset(14, 84 + CARD_H + 36 + 100 + 8 + 26 + 4),
			Size = UDim2.new(1, -28, 0, 30),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New "TextButton" {
					Size = UDim2.fromOffset(110, 30), BackgroundColor3 = COLORS.Button, Text = "Odds  ⓘ",
					TextColor3 = COLORS.Muted, Font = Enum.Font.GothamMedium, TextSize = 12,
					[Children] = { scope:New "UICorner" { CornerRadius = UDim.new(0, 8) } },
					[OnEvent "Activated"] = function() setOddsPopupVisible(not peek(oddsPopupVisible)) end,
				},
				scope:New "TextLabel" {
					Position = UDim2.fromOffset(122, 0), Size = UDim2.new(1, -280, 1, 0), BackgroundTransparency = 1,
					TextSize = 12, TextColor3 = COLORS.Gold, TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = true, Font = Enum.Font.GothamMedium,
					Text = pityTextC,
				},
				scope:New "TextButton" {
					AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(150, 30),
					BackgroundColor3 = COLORS.Button, TextColor3 = COLORS.Muted, Font = Enum.Font.GothamMedium, TextSize = 12,
					Text = skipTextC,
					[Children] = { scope:New "UICorner" { CornerRadius = UDim.new(0, 8) } },
					[OnEvent "Activated"] = function() skipAnimationValue:set(not peek(skipAnimationValue)) end,
				},
			},
		},
		scope:New "TextButton" {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(260, 44),
			BackgroundColor3 = strikeBgC, TextColor3 = strikeTextColorC, Font = Enum.Font.GothamBold, TextSize = 16,
			AutoButtonColor = false, Text = strikeTextC,
			[Children] = { scope:New "UICorner" { CornerRadius = UDim.new(0, 10) } },
			[OnEvent "Activated"] = function()
				if peek(spinningValue) or not peek(selectedC) then return end
				if peek(goldValue) < currentCost() then return end
				REFORGE:FireServer("Reroll", peek(selectedToolName), lockList())
				lockedSet:set({})
			end,
		},
	},
}

local overlay = scope:New "TextButton" {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.55,
	Text = "",
	AutoButtonColor = false,
	Visible = overlayVisible,
	Parent = screenGui,
	[OnEvent "Activated"] = close,
	[Children] = {
		chrome.Frame,

		scope:New "TextButton" {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35,
			Text = "", AutoButtonColor = false, ZIndex = 29,
			Visible = oddsPopupVisible,
			[OnEvent "Activated"] = function() setOddsPopupVisible(false) end,
		},
		scope:New "Frame" {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(420, 170),
			BackgroundColor3 = COLORS.Dark, BorderSizePixel = 0, ZIndex = 30,
			Visible = oddsPopupVisible,
			[Children] = {
				scope:New "UICorner" { CornerRadius = UDim.new(0, 12) },
				scope:New "UIStroke" { Color = COLORS.Ember, Thickness = 1.5, Transparency = 0.3 },
				scope:New "TextLabel" {
					Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -50, 0, 22), BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = COLORS.Ember, ZIndex = 31,
					TextXAlignment = Enum.TextXAlignment.Left, Text = "Reforge Odds",
				},
				scope:New "TextButton" {
					AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(28, 28),
					BackgroundColor3 = COLORS.Button, Text = "X", TextColor3 = COLORS.Text, Font = Enum.Font.GothamBold,
					TextSize = 14, ZIndex = 31,
					[Children] = { scope:New "UICorner" { CornerRadius = UDim.new(0, 7) } },
					[OnEvent "Activated"] = function() setOddsPopupVisible(false) end,
				},
				scope:New "TextLabel" {
					Position = UDim2.fromOffset(16, 44), Size = UDim2.new(1, -32, 1, -56), BackgroundTransparency = 1,
					TextSize = 13, TextColor3 = COLORS.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
					TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamMedium, ZIndex = 31, Text = oddsPopupTextC,
				},
			},
		},
	},
}

-- Opened from the right-side nav rail's slot-machine icon (see MainMenuGui.client.luau).

-- ── The reel (kept imperative -- see file header) ───────────────────────────
local function plainText(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = COLORS.Text
	l.Font = Enum.Font.GothamMedium
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in pairs(props) do l[k] = v end
	l.Parent = parent
	return l
end

local function makeCard(index, label, sub, color, big)
	local card = Instance.new("Frame")
	card.Position = UDim2.fromOffset((index - 1) * (CARD_W + CARD_GAP), 0)
	card.Size = UDim2.fromOffset(CARD_W, CARD_H)
	card.BackgroundColor3 = COLORS.PanelLight
	card.BorderSizePixel = 0
	card.Parent = strip
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = card end
	local edge = Instance.new("Frame")
	edge.Size = UDim2.new(1, 0, 0, 5)
	edge.Position = UDim2.new(0, 0, 1, -5)
	edge.BackgroundColor3 = color
	edge.BorderSizePixel = 0
	edge.Parent = card
	plainText(card, { Position = UDim2.fromOffset(8, 14), Size = UDim2.new(1, -16, 0, big and 70 or 60), TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBold, TextSize = big and 15 or 14, TextColor3 = color, TextWrapped = true, Text = label })
	plainText(card, { Position = UDim2.fromOffset(8, big and 88 or 80), Size = UDim2.new(1, -16, 0, 40), TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 11, TextColor3 = COLORS.Muted, TextWrapped = true, Text = sub })
	return card
end

local function randomFillerCard(index, rarity)
	local odds = WeaponModifiers.TierOdds(rarity, 0)
	local pick, tier = math.random(), 1
	for t = 1, WeaponModifiers.TIER_COUNT do
		pick -= odds[t]
		if pick <= 0 then tier = t break end
	end
	local categories = { "Damage", "CritChance", "Range", "Knockback" }
	local category = categories[math.random(#categories)]
	local entry = WeaponModifiers.Categories[category].Tiers[tier]
	makeCard(index, entry.name, entry.desc, TIER_COLORS[tier])
end

local function spin(result)
	spinningValue:set(true)
	idleHint.Visible = false
	reveal.Visible = false
	for _, c in ipairs(strip:GetChildren()) do c:Destroy() end
	for i = 1, REEL_CARDS do
		if i == LAND_INDEX then
			local names = {}
			for _, m in ipairs(result.mods) do table.insert(names, m.name) end
			if result.blessed then table.insert(names, 1, "Blessed") end
			makeCard(i, #names > 0 and table.concat(names, "\n") or "Plain", result.rarity, RARITY_COLORS[result.rarity] or COLORS.Text, true)
		else
			randomFillerCard(i, result.rarity)
		end
	end
	local windowW = reelWindow.AbsoluteSize.X
	local landX = (LAND_INDEX - 1) * (CARD_W + CARD_GAP) + CARD_W / 2 + math.random(-40, 40)
	strip.Position = UDim2.fromOffset(windowW / 2 - CARD_W / 2, 12)
	local tween = TweenService:Create(strip, TweenInfo.new(peek(skipAnimationValue) and 0.35 or SPIN_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(windowW / 2 - landX, 12) })
	local lastIndex = 0
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local passing = math.floor((windowW / 2 - strip.Position.X.Offset) / (CARD_W + CARD_GAP))
		if passing ~= lastIndex then
			lastIndex = passing
			AudioManager.PlaySFX("ui_click", screenGui)
		end
	end)
	tween:Play()
	tween.Completed:Wait()
	conn:Disconnect()
	AudioManager.PlaySFX(result.after >= result.before and "quest_complete" or "enemy_hit", screenGui)

	reveal.Visible = true
	revealName.Text = result.toolName
	revealName.TextColor3 = RARITY_COLORS[result.rarity] or COLORS.Text
	local parts = {}
	if result.blessed then table.insert(parts, "Blessed slot") end
	for _, m in ipairs(result.mods) do table.insert(parts, string.format("%s (T%d %s)", m.name, m.tier, m.desc or m.category)) end
	revealMods.Text = (#parts > 0 and table.concat(parts, "  ·  ") or "No modifiers this time.")
		.. (result.pityApplied and "   (pity floor applied)" or "") .. (result.kept and ("   (kept " .. result.kept .. ")") or "")
	if result.personalBest then
		revealName.Text = revealName.Text .. "   NEW PERSONAL BEST"
	end
	local delta = result.after - result.before
	revealRating.Text = string.format("Rating %s  ->  %s   (%s%d)   %s", SwordValue.short(result.before), SwordValue.short(result.after),
		delta >= 0 and "+" or "", delta, result.free and "free" or ("-" .. result.cost .. " gold"))
	revealRating.TextColor3 = delta > 0 and COLORS.Success or (delta < 0 and COLORS.Error or COLORS.Muted)
	reveal.BackgroundColor3 = delta > 0 and Color3.fromRGB(18, 40, 26) or (delta < 0 and Color3.fromRGB(44, 18, 18) or COLORS.Dark)
	TweenService:Create(reveal, TweenInfo.new(1.2), { BackgroundColor3 = COLORS.Dark }):Play()
	spinningValue:set(false)
end

-- ── Wiring ───────────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape and peek(overlayVisible) then
		if peek(oddsPopupVisible) then setOddsPopupVisible(false) else close() end
	end
end)

local function applyState(stateRows, goldVal, highlight, disclosure)
	rowsValue:set(stateRows)
	goldValue:set(goldVal)
	if disclosure then oddsInfoValue:set(disclosure) end
	if highlight then
		if peek(selectedToolName) ~= highlight then lockedSet:set({}) end
		selectedToolName:set(highlight)
	elseif peek(selectedToolName) then
		local stillExists = false
		for _, info in ipairs(stateRows) do
			if info.toolName == peek(selectedToolName) then stillExists = true break end
		end
		if not stillExists then selectedToolName:set(nil) end
	end
end

local pendingState = nil
REFORGE.OnClientEvent:Connect(function(kind, a, b, c, d)
	if kind == "Open" then
		overlayVisible:set(true)
		reveal.Visible = false
		idleHint.Visible = true
		setOddsPopupVisible(false)
		for _, card in ipairs(strip:GetChildren()) do card:Destroy() end
	elseif kind == "Result" then
		pendingState = nil
		task.spawn(function()
			spin(a)
			if pendingState then applyState(pendingState[1], pendingState[2], pendingState[3], pendingState[4]) pendingState = nil end
		end)
	elseif kind == "State" then
		if peek(spinningValue) then
			pendingState = { a, b, c, d } -- apply after the reel lands so the list does not jump mid-spin
		else
			applyState(a, b, c, d)
		end
	end
end)

print("[ReforgeGuiFusion] Fusion-based Reforge panel enabled")
