--// ReforgeGuiFusion  (the Reforge anvil window, built with Fusion)
-- Pick a relic sword, time a hammer blow, then watch the mystery sword's glow climb the rarity
-- ladder and land on what the server rolled. Same remotes and feature set as the original
-- ReforgeGui.client.luau.
--
-- Bright window in the Inventory / Vault family: a light thick-outlined panel with the title
-- over its top-left edge beside a rendered anvil, a rarity-filter rail down the left with red
-- count badges, and a tray of square sword tiles (one 3D sword and one stat on each rarity
-- face). The stage on the right is the featured item: the picked sword big in a glowing rarity
-- tile, its name and cost in chunky display type with a lucky-roll bar, its modifiers as a
-- wrapping grid of lock chips, and one fat Reforge button
-- between the Odds (tier chances live there) and Animation buttons. On phones the stage stacks
-- over the sword tray and the whole window is sized with one UIScale.
--
-- The forge strike and the mystery-sword reveal stay imperative (a one-shot procedural
-- animation isn't a good fit for declarative state, and Fusion doesn't try to replace
-- TweenService for that); each lives in its own closure further down. Everything else --
-- list rendering, lock chips, button text/color, the odds popup, the pity status -- is
-- Fusion state driving the UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local REFORGE = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("ReforgeAction")
local Config = ReplicatedStorage:WaitForChild("Config")
local SwordValue = require(Config:WaitForChild("SwordValue"))
local WeaponModifiers = require(Config:WaitForChild("WeaponModifiers"))
local BossWeapons = require(Config:WaitForChild("BossWeapons"))
local AudioManager = require(ReplicatedStorage:WaitForChild("AudioManager"))

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local scope = Fusion.scoped(Fusion)
local peek = Fusion.peek
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local PanelChrome = require(ReplicatedStorage:WaitForChild("PanelChrome"))
local BRIGHT = PanelChrome.BRIGHT
local RARITY_TILE = PanelChrome.RARITY_TILE
local DISPLAY = PanelChrome.DISPLAY_FONT
local corner = PanelChrome.corner
local WHITE = Color3.new(1, 1, 1)
local COIN_ICON = "rbxassetid://84697600263846" -- the HUD's gold coin
local TROPHY_ICON = "rbxassetid://77830885604568" -- the Inventory's rating trophy

-- One colour per rung of the ladder, from the config so the popup, the ladder rail and the
-- reveal all agree.
local TIER_COLORS = {}
for tier, rung in ipairs(WeaponModifiers.Rungs) do TIER_COLORS[tier] = rung.color end
local function rungName(tier: number?): string
	local rung = tier and WeaponModifiers.Rungs[tier]
	return rung and rung.name or "?"
end
local POPUP_W, POPUP_H = 780, 560
local RARITIES = { "All", "Legendary", "Epic", "Rare", "Uncommon", "Common" }

-- [TUNING] design-space sizes; the whole window is scaled with one UIScale.
local HEADER_H, SEC_H, EDGE = 70, 50, 18
local X0 = 90 -- content starts right of the rail
local RAIL_X, RAIL_W, TAB = -22, 94, 70
local CLOSE = 68 -- 44 px tall even at the phone scale
local TILE, GAP, VGAP = 112, 12, 18
local TOP_PAD, TRAY_PAD, SCROLLBAR = 24, 16, 10
local MID = 20 -- between the sword tray and the stage
local STAGE_W_WIDE, STAGE_W_TALL = 600, 430
-- The stage is three calm bands: the hero card, the modifier lock grid and the button row.
-- The tier odds live behind the Odds button; the reveal takes the whole screen.
local CHIP_H, CHIP_GAP = 68, 10 -- lock chips sit two to a row; 68 keeps them 44 px on phones
local HERO_H, MODS_H, STRIKE_H, STAGE_GAP = 236, 3 * CHIP_H + 2 * CHIP_GAP, 90, 16
local STAGE_H = HERO_H + MODS_H + STRIKE_H + 2 * STAGE_GAP
local STAGE_TOP = 8 -- the stage starts level with the tray heading
local HERO_Y = 0
local MODS_Y = HERO_Y + HERO_H + STAGE_GAP
local STRIKE_Y = MODS_Y + MODS_H + STAGE_GAP
local TRAY_H_WIDE = STAGE_TOP + STAGE_H - SEC_H


local function trayWidth(cols)
	return 2 * TRAY_PAD + cols * TILE + (cols - 1) * GAP + SCROLLBAR + 8
end
local TRAY_W_WIDE = trayWidth(3)

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
local filterValue = scope:Value("All")
local layout = scope:Value({
	wide = true, s = 1, stageW = STAGE_W_WIDE, trayW = TRAY_W_WIDE, trayH = TRAY_H_WIDE,
	W = X0 + TRAY_W_WIDE + MID + STAGE_W_WIDE + EDGE, H = HEADER_H + STAGE_TOP + STAGE_H + EDGE,
})
local revealingValue = scope:Value(false) -- true from the hand-off until the reveal hands the panel back
-- The forge strike lives further down (it is a one-shot animation, like the reveal), but the
-- button needs to know a meter is live: `active` is true from the moment the server lights one
-- until the blow's payoff is over, and `armToken` retires a request the server never answered.
local forgeState = { active = false, armToken = 0 }
-- The reveal and the run rail are built far below (both are one-shot imperative layers), but
-- strike() has to reach them: the anvil now comes back the instant a result is readable, so
-- pressing FORGE while the card is still up sweeps it away instead of queueing behind it.
local revealHooks = { dismiss = function() end }
local runRail = { onOpen = function() end, onArm = function() end, onBlow = function() end,
	onResult = function() end, refresh = function() end, setLive = function() end }

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
			BossTier = info.tier, Variant = info.variant, BaseMult = info.baseMult }, names)
	end
	local odds = use(oddsInfoValue)
	if odds and (odds.freeIn or 1) <= 0 then return 0 end
	return info.cost
end)

local affordC = scope:Computed(function(use) return use(goldValue) >= use(costC) end)
local strikeReadyC = scope:Computed(function(use)
	return use(selectedC) ~= nil and not use(spinningValue) and use(affordC)
end)

local filteredRowsC = scope:Computed(function(use)
	local rows, filter = use(rowsValue), use(filterValue)
	if filter == "All" then return rows end
	local out = {}
	for _, info in ipairs(rows) do
		if info.rarity == filter then table.insert(out, info) end
	end
	return out
end)

local function goldText(n: number): string
	return n < 100000 and tostring(math.floor(n)) or SwordValue.short(n)
end

local costTextC = scope:Computed(function(use)
	local cost = use(costC)
	return cost == 0 and "FREE" or goldText(cost)
end)

-- The sword's own name without its rolled modifier words ("Blessed Mythic ... Astral Eclipse"
-- -> "Astral Eclipse"); the modifiers are listed under it as lock chips.
local function baseName(name: string?): string
	local words = {}
	for word in string.gmatch(name or "", "%S+") do
		if word ~= "Blessed" and not SwordValue.TIER_BY_NAME[word] and not WeaponModifiers.VariantByName[word] then
			table.insert(words, word)
		end
	end
	return #words > 0 and table.concat(words, " ") or (name or "Relic Sword")
end

local selectedTitleTextC = scope:Computed(function(use)
	local info = use(selectedC)
	return info and baseName(info.name) or "Pick a sword"
end)

local strikeLabelC = scope:Computed(function(use)
	if use(spinningValue) then return "AT THE ANVIL..." end
	if not use(selectedC) then return "PICK A SWORD" end
	local n = #use(lockNamesC)
	if not use(affordC) then return "NEED MORE GOLD" end
	if n > 0 then return string.format("FORGE, KEEP %d", n) end
	return "FORGE"
end)

local pityFracC = scope:Computed(function(use)
	local odds = use(oddsInfoValue)
	if not odds then return 0 end
	return math.clamp((odds.pity or 0) / math.max(odds.pityAfter or 5, 1), 0, 1)
end)
local pityShortC = scope:Computed(function(use)
	local odds = use(oddsInfoValue)
	if not odds then return "" end
	local pity, after = odds.pity or 0, odds.pityAfter or 5
	if pity >= after then return "READY!" end
	return string.format("%d LEFT", after - pity)
end)

-- Luck line for the popup and the hero: "LUCK 1.4x  ·  streak 20 (+0.4)  ·  charge (+1.0)  ·  rebirth (+0.0)".
local function luckSummary(odds): string
	local luck = odds and odds.luck
	if not luck then return "LUCK 1.0x" end
	local parts = { string.format("LUCK %.1fx", luck.total or 1) }
	table.insert(parts, string.format("streak %d (+%.1f)", luck.streak or 0, luck.streakBonus or 0))
	table.insert(parts, string.format("%d charge%s (%s)", luck.charges or 0, (luck.charges or 0) == 1 and "" or "s",
		(luck.charges or 0) > 0 and string.format("+%.1f next paid strike", luck.chargeBonus or 0) or "boss kills bank one"))
	table.insert(parts, string.format("rebirth +%.1f", luck.rebirthBonus or 0))
	-- The wealth ladder's standing luck, when this player has earned any (Config.WealthLadder).
	if (luck.milestoneBonus or 0) > 0 then
		table.insert(parts, string.format("%s +%.2f", luck.title ~= "" and luck.title or "wealth",
			luck.milestoneBonus))
	end
	return table.concat(parts, "  ·  ")
end
local luckLineC = scope:Computed(function(use) return luckSummary(use(oddsInfoValue)) end)

local oddsPopupTextC = scope:Computed(function(use)
	local info = use(selectedC)
	local odds = use(oddsInfoValue)
	if not info or not odds or not odds.odds or not odds.odds[info.rarity] then
		return "Pick a sword to see the exact 1-in-N of every rung for its rarity."
	end
	local o = odds.odds[info.rarity]
	local lines = {}
	local slots = o.slots or 1
	local ladder = o.ladder
	local top = ladder and ladder[odds.tierCount or 10]
	local bc = odds.broadcastTier or 8
	local bcRow = ladder and ladder[bc]
	table.insert(lines, string.format("%s rolls %d slot%s a strike. Odds above are per slot; luck multiplies the long tail (T7+) only.",
		info.rarity, slots, slots == 1 and "" or "s"))
	if bcRow then
		table.insert(lines, string.format("Whole-strike chance of a %s or better: %s. A %s+ strike is announced to the whole server.",
			rungName(bc), bcRow.atLeastOneInText or "?", rungName(bc)))
	end
	if top then
		table.insert(lines, string.format("%s (T%d) lands %s per slot: %s per strike on this sword.", top.name, odds.tierCount or 10,
			top.oneInText or "?", top.atLeastOneInText or "?"))
	end
	local pity, after = odds.pity or 0, odds.pityAfter or 5
	local tailPity, tailAfter = odds.tailPity or 0, odds.tailPityAfter or 250
	table.insert(lines, string.format("Pity: %s. Long-tail pity: %d / %d strikes without a %s+ (then one is guaranteed).",
		pity >= after and string.format("lucky roll READY (a T%d+ is guaranteed next strike)", odds.pityTier or 4)
			or string.format("lucky roll in %d / %d (then a T%d+ is guaranteed)", pity, after, odds.pityTier or 4),
		tailPity, tailAfter, rungName(odds.tailPityTier or 7)))
	local vparts = {}
	for _, v in ipairs(odds.variants or {}) do
		table.insert(vparts, string.format("%s 1 in %d (x%.1f)", v.name, v.oneIn, v.mult))
	end
	if #vparts > 0 then
		table.insert(lines, "Mutations (true odds, every roll): " .. table.concat(vparts, ", ") .. ". Blessed 1 in 33: an extra slot at double tail luck.")
	end
	local strikeRules = odds.strike
	if strikeRules then
		local m = strikeRules.mult or {}
		local sweep = strikeRules.sweep or 1.15
		local okHalf = strikeRules.okHalf or 0.225
		table.insert(lines, string.format("The strike: pay, then time the hammer. PERFECT multiplies the luck above by %.1fx, GOOD by %.1fx, OK by %.2fx. The PERFECT slice is %.0f ms of marker travel, GOOD %.0f ms either side of it and OK %.0f ms either side of that.",
			m.PERFECT or 2, m.GOOD or 1.5, m.OK or 1.15,
			2 * (strikeRules.sweetHalf or 0.055) * sweep * 1000,
			((strikeRules.goodHalf or 0.125) - (strikeRules.sweetHalf or 0.055)) * sweep * 1000,
			(okHalf - (strikeRules.goodHalf or 0.125)) * sweep * 1000))
		table.insert(lines, string.format("The other %.0f%% of the bar is a MISS: the roll still happens, at your base luck and never below it, but the blow buys nothing and the gold is already spent. Letting the meter run out is a MISS too.",
			(1 - 2 * okHalf) * 100))
	end
	return table.concat(lines, "\n")
end)

local freeReadyC = scope:Computed(function(use)
	local odds = use(oddsInfoValue)
	return odds ~= nil and (odds.freeIn or 0) <= 0
end)
local freeTextC = scope:Computed(function(use)
	local odds = use(oddsInfoValue)
	if not odds then return "FREE STRIKE" end
	local freeIn = odds.freeIn or 0
	if freeIn <= 0 then return "FREE STRIKE READY" end
	return string.format("FREE IN %dH %02dM", math.floor(freeIn / 3600), math.floor(freeIn % 3600 / 60))
end)
local bestTextC = scope:Computed(function(use)
	local odds = use(oddsInfoValue)
	return "BEST " .. SwordValue.short(odds and odds.best or 0)
end)
local countTextC = scope:Computed(function(use)
	local odds = use(oddsInfoValue)
	return string.format("%d FORGED", odds and odds.count or 0)
end)
-- The anvil's record (free strike, best roll, reforge count) sits in the Odds popup's footer.
local statsLineC = scope:Computed(function(use)
	local free = use(freeTextC)
	if use(freeReadyC) then free = '<font color="#2E9E34">' .. free .. "</font>" end
	return free .. "  ·  " .. use(bestTextC) .. "  ·  " .. use(countTextC)
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
	revealingValue:set(false)
	selectedToolName:set(toolName)
end

local function setOddsPopupVisible(visible: boolean)
	oddsPopupVisible:set(visible)
end

local reforgeMotion -- shared open/close motion (PanelChrome), set once the window exists

local function close()
	if peek(spinningValue) then return end
	setOddsPopupVisible(false)
	REFORGE:FireServer("Close")
	if not peek(overlayVisible) or not reforgeMotion then
		overlayVisible:set(false)
		return
	end
	PanelChrome.closeMotion(reforgeMotion, function() overlayVisible:set(false) end)
end

local function lockList()
	return peek(lockNamesC)
end

local function currentCost()
	return peek(costC)
end

-- Pressing FORGE no longer rolls: it pays and asks the server for a meter. The roll happens
-- when the hammer lands (or when the meter runs out), so the button is spent from here on.
local function strike()
	if peek(spinningValue) or not peek(selectedC) then return end
	if peek(goldValue) < currentCost() then return end
	-- The last roll's card may still be on screen: the anvil hands the button back the moment
	-- the result is readable, so striking again sweeps the card away rather than waiting it out.
	if peek(revealingValue) then revealHooks.dismiss() end
	spinningValue:set(true)
	runRail.onArm()
	forgeState.armToken += 1
	local token = forgeState.armToken
	REFORGE:FireServer("Arm", peek(selectedToolName), lockList())
	lockedSet:set({})
	-- The server refused (gold moved, sword gone): give the button back rather than wedge it.
	task.delay(5, function()
		if forgeState.armToken == token and not forgeState.active and not peek(revealingValue) then spinningValue:set(false) end
	end)
end

-- ── Small helpers ────────────────────────────────────────────────────────────
local function L(fn)
	return scope:Computed(function(use) return fn(use(layout)) end)
end

local function tierColors(tier: number)
	local c = TIER_COLORS[tier] or TIER_COLORS[1]
	return c:Lerp(WHITE, 0.5), c, c:Lerp(BRIGHT.Outline, 0.45)
end

local function image(parent, img, size, props)
	local l = Instance.new("ImageLabel")
	l.BackgroundTransparency = 1
	l.Image = img
	l.ScaleType = Enum.ScaleType.Fit
	l.Size = UDim2.fromOffset(size, size)
	for k, v in pairs(props or {}) do l[k] = v end
	l.Parent = parent
	return l
end

local function part(parent, className, name, size, cf, color, material, shape)
	local p = Instance.new(className)
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

-- A cartoon anvil built from parts, with a white-hot blade resting on its face.
local function renderAnvil(viewport)
	for _, c in ipairs(viewport:GetChildren()) do c:Destroy() end
	viewport.Ambient = Color3.fromRGB(200, 204, 222)
	viewport.LightColor = Color3.fromRGB(255, 244, 226)
	viewport.LightDirection = Vector3.new(-0.5, -1, -0.8)
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local iron, ironDark = Color3.fromRGB(104, 112, 142), Color3.fromRGB(58, 62, 84)
	local cyl = Enum.PartType.Cylinder
	part(world, "Part", "Base", Vector3.new(3.4, 0.7, 2.2), CFrame.new(0, -1.5, 0), ironDark)
	part(world, "Part", "Foot", Vector3.new(2.4, 0.5, 1.7), CFrame.new(0, -1.0, 0), iron)
	part(world, "Part", "Waist", Vector3.new(1.4, 1.0, 1.1), CFrame.new(0, -0.35, 0), ironDark)
	part(world, "Part", "Face", Vector3.new(3.4, 0.9, 1.7), CFrame.new(0.2, 0.55, 0), iron)
	part(world, "Part", "Horn", Vector3.new(1.4, 0.9, 0.9), CFrame.new(-2.1, 0.62, 0), iron, nil, cyl)
	part(world, "Part", "HornTip", Vector3.new(0.6, 0.6, 0.6), CFrame.new(-2.85, 0.66, 0), iron, nil, Enum.PartType.Ball)
	part(world, "Part", "Heel", Vector3.new(0.6, 0.7, 1.5), CFrame.new(2.1, 0.6, 0), ironDark)
	-- the blade being forged, glowing hot
	part(world, "Part", "Blade", Vector3.new(3.0, 0.18, 0.55), CFrame.new(0.1, 1.1, 0.1) * CFrame.Angles(0, math.rad(-12), 0),
		Color3.fromRGB(255, 160, 50), Enum.Material.Neon)
	part(world, "Part", "Guard", Vector3.new(0.22, 0.24, 1.1), CFrame.new(1.7, 1.1, 0.45) * CFrame.Angles(0, math.rad(-12), 0),
		Color3.fromRGB(255, 206, 60), Enum.Material.Metal)
	part(world, "Part", "Grip", Vector3.new(0.8, 0.26, 0.26), CFrame.new(2.2, 1.1, 0.56) * CFrame.Angles(0, math.rad(-12), 0),
		Color3.fromRGB(110, 62, 34))
	for i, spec in ipairs({ { -0.8, 1.9, 0.6, 0.32 }, { 0.4, 2.3, 0.2, 0.24 }, { 1.2, 1.8, 0.8, 0.2 } }) do
		part(world, "Part", "Spark" .. i, Vector3.new(spec[4], spec[4], spec[4]), CFrame.new(spec[1], spec[2], spec[3]),
			Color3.fromRGB(255, 230, 90), Enum.Material.Neon, Enum.PartType.Ball)
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local target = Vector3.new(0, 0.1, 0)
	camera.CFrame = CFrame.lookAt(target + Vector3.new(2.6, 3.4, 8.4).Unit * 14.2, target)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

-- Stand-in sword for a row whose Tool is not on the client: Handle grip with the blade along
-- -Z, tinted with its boss tier's colour (same build as the Vault's).
local function buildStandInSword(tier)
	local weapon = BossWeapons.GetByTier(tier or 1)
	local bladeColor = (weapon and weapon.color) or Color3.fromRGB(200, 206, 218)
	local tool = Instance.new("Tool")
	local handle = part(tool, "Part", "Handle", Vector3.new(0.44, 0.44, 1.0), CFrame.new(), Color3.fromRGB(70, 44, 32))
	local function add(name, size, c0, color, material, shape, className)
		local p = part(tool, className or "Part", name, size, CFrame.new(), color, material, shape)
		p.Anchored = false
		local w = Instance.new("Weld")
		w.Part0 = handle
		w.Part1 = p
		w.C0 = c0
		w.Parent = handle
	end
	local len, w, t = 2.45, 1.1, 0.26
	local bladeZ = -0.8 - len / 2
	add("Pommel", Vector3.new(0.66, 0.66, 0.66), CFrame.new(0, 0, 0.68), bladeColor, Enum.Material.Neon, Enum.PartType.Ball)
	add("Guard", Vector3.new(1.95, 0.4, 0.44), CFrame.new(0, 0, -0.6), Color3.fromRGB(214, 150, 30), Enum.Material.Metal)
	add("Blade", Vector3.new(w, t, len), CFrame.new(0, 0, bladeZ), Color3.fromRGB(214, 220, 232), Enum.Material.Metal)
	add("Fuller", Vector3.new(w * 0.3, t + 0.04, len * 0.82), CFrame.new(0, 0, bladeZ + len * 0.06), bladeColor, Enum.Material.Neon)
	local tipLen = w * 0.75
	for _, side in ipairs({ 1, -1 }) do
		add("Tip", Vector3.new(t, w / 2, tipLen), CFrame.new(side * w / 4, 0, bladeZ - len / 2 - tipLen / 2)
			* CFrame.Angles(0, 0, side == 1 and -math.pi / 2 or math.pi / 2), Color3.fromRGB(214, 220, 232), Enum.Material.Metal, nil, "WedgePart")
	end
	return tool
end

-- Draws a row's sword: the carried Tool itself when it is on the client, else the stand-in.
local function renderSword(viewport, info, opts)
	local tool
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		local found = container and info and container:FindFirstChild(info.toolName)
		if found and found:IsA("Tool") then tool = found break end
	end
	if tool and PanelChrome.renderTool(viewport, tool, opts) then return end
	local standIn = buildStandInSword(info and info.tier)
	PanelChrome.renderTool(viewport, standIn, opts)
	standIn:Destroy()
end

-- A cut gem: a square turned 45 degrees in the rarity's gradient, with a glossy facet.
local function gemIcon(parent, size, rarity, z)
	local t = RARITY_TILE[rarity] or RARITY_TILE.Common
	local gem = Instance.new("Frame")
	gem.Name = "Gem"
	gem.AnchorPoint = Vector2.new(0.5, 0.5)
	gem.Position = UDim2.fromScale(0.5, 0.5)
	gem.Size = UDim2.fromOffset(size, size)
	gem.Rotation = 45
	gem.BackgroundColor3 = WHITE
	gem.BorderSizePixel = 0
	gem.ZIndex = z
	gem.Parent = parent
	corner(gem, math.floor(size * 0.22))
	PanelChrome.gradient(gem, t.top, t.bottom).Rotation = 45
	PanelChrome.stroke(gem, BRIGHT.Outline, 3)
	local facet = Instance.new("Frame")
	facet.Name = "Facet"
	facet.Position = UDim2.fromScale(0.16, 0.16)
	facet.Size = UDim2.fromScale(0.38, 0.38)
	facet.BackgroundColor3 = WHITE
	facet.BackgroundTransparency = 0.2
	facet.BorderSizePixel = 0
	facet.ZIndex = z
	facet.Parent = gem
	corner(facet, 4)
	return gem
end

-- Rounded pill with a stroked display label; text may be a string or a state object.
local function pill(s, props)
	return s:New "Frame" {
		Name = props.name or "Pill",
		LayoutOrder = props.order or 0,
		Size = UDim2.fromOffset(0, props.height or 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = WHITE,
		Visible = props.visible,
		ZIndex = props.zIndex or 8,
		[Children] = {
			s:New "UICorner" { CornerRadius = UDim.new(0, (props.height or 34) / 2) },
			s:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 2.5 },
			s:New "UIGradient" { Rotation = 90, Color = props.gradient },
			s:New "UIPadding" { PaddingLeft = UDim.new(0, props.icon and 4 or 14), PaddingRight = UDim.new(0, 14) },
			s:New "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
			},
			props.icon and s:New "ImageLabel" {
				LayoutOrder = 1, BackgroundTransparency = 1, Image = props.icon, ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromOffset((props.height or 34) - 2, (props.height or 34) - 2), ZIndex = (props.zIndex or 8) + 1,
			} or nil,
			s:New "TextLabel" {
				LayoutOrder = 2, BackgroundTransparency = 1, Font = DISPLAY, TextSize = props.textSize or 18,
				TextColor3 = props.textColor or WHITE, Text = props.text,
				Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, ZIndex = (props.zIndex or 8) + 1,
				[Children] = { s:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 2 } },
			},
		},
	}
end

local function seq(top, bottom) return ColorSequence.new(top, bottom) end

-- One rung tile for the odds preview: the rung number and name over its colour, the true
-- 1-in-N per slot under it (the ladder the server sent, at the luck the next strike uses).
local function tierTile(tier: number, sizeProp)
	local top, bottom, rim = tierColors(tier)
	local pctC = scope:Computed(function(use)
		local info, odds = use(selectedC), use(oddsInfoValue)
		local o = info and odds and odds.odds and odds.odds[info.rarity]
		if not o then return "?" end
		if o.ladder and o.ladder[tier] then return o.ladder[tier].oneInText or "?" end
		if not o.tiers[tier] then return "?" end
		return WeaponModifiers.OneInText(o.tiers[tier])
	end)
	local tile = scope:New "Frame" {
		Name = "Tier" .. tier, LayoutOrder = tier, Size = sizeProp, BackgroundColor3 = WHITE, ZIndex = 7,
		[Children] = {
			scope:New "UICorner" { CornerRadius = UDim.new(0, 14) },
			scope:New "UIGradient" { Rotation = 90, Color = seq(top, bottom) },
			scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 3 },
			scope:New "Frame" {
				Name = "Rim", BackgroundTransparency = 1, Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), ZIndex = 7,
				[Children] = { scope:New "UICorner" { CornerRadius = UDim.new(0, 11) }, scope:New "UIStroke" { Color = rim, Thickness = 2.5 } },
			},
		},
	}
	local shine = Instance.new("Frame")
	shine.BackgroundColor3 = WHITE
	shine.BackgroundTransparency = 0.6
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromOffset(6, 6)
	shine.Size = UDim2.new(1, -12, 0.26, 0)
	shine.ZIndex = 7
	shine.Parent = tile
	corner(shine, 9)
	PanelChrome.display(tile, { text = "T" .. tier, size = 30, stroke = 3, pos = UDim2.fromScale(0, 0.04), size2 = UDim2.fromScale(1, 0.36), scaled = true, minSize = 12, zIndex = 8 })
	PanelChrome.display(tile, { text = string.upper(rungName(tier)), size = 17, stroke = 2, pos = UDim2.fromScale(0.03, 0.4), size2 = UDim2.fromScale(0.94, 0.24), scaled = true, minSize = 9, zIndex = 8 })
	local pct = PanelChrome.display(tile, { text = "", size = 19, stroke = 2.5, pos = UDim2.fromScale(0.03, 0.66), size2 = UDim2.fromScale(0.94, 0.28), scaled = true, minSize = 9, zIndex = 8 })
	scope:Hydrate(pct) { Text = pctC }
	return tile
end

-- A chunky bevelled button (PanelChrome.chunkyButton) with a dark drop shadow, in a holder the
-- layouts can size. Returns holder, button, label, gradient and the bevel lip.
local function chunky(props)
	local holder = scope:New "Frame" {
		Name = (props.name or "Button") .. "Holder", BackgroundTransparency = 1, LayoutOrder = props.order or 0,
		Size = props.size, ZIndex = 7,
	}
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Position = UDim2.fromOffset(0, 6)
	shadow.Size = UDim2.new(1, 0, 1, -6)
	shadow.BackgroundColor3 = BRIGHT.Outline
	shadow.BackgroundTransparency = 0.45
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 7
	shadow.Parent = holder
	corner(shadow, 18)
	local btn, label, grad = PanelChrome.chunkyButton(holder, {
		name = props.name, text = props.text or "", color = props.color, colorDark = props.colorDark,
		size = UDim2.new(1, 0, 1, -6), textSize = props.textSize or 26, zIndex = 8, radius = 18, strokeThickness = 3.5,
	})
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.AnchorPoint = Vector2.new(0.5, 1)
	lip.Position = UDim2.new(0.5, 0, 1, -3)
	lip.Size = UDim2.new(1, -14, 0, 7)
	lip.BackgroundColor3 = props.colorDark
	lip.BorderSizePixel = 0
	lip.ZIndex = 8
	lip.Parent = btn
	corner(lip, 4)
	return holder, btn, label, grad, lip
end

-- ── Reactive list: sword tiles ───────────────────────────────────────────────
-- One idea per tile, like the Inventory's: the sword framed big on its rarity face and a single
-- stat (its rating) under it. The name lives on the hero card.
local function decorateSwordTile(tile, info)
	local rarity = info.rarity or "Common"
	corner(tile, 18)
	PanelChrome.lootTile(tile, rarity, { radius = 18, zIndex = 6, glowY = 0.42 })
	if info.blessed then
		-- a small gold gem in the corner, so outlines stay free to mark the picked tile
		local gem = Instance.new("Frame")
		gem.Name = "BlessedGem"
		gem.AnchorPoint = Vector2.new(0.5, 0.5)
		gem.Position = UDim2.fromOffset(17, 17)
		gem.Size = UDim2.fromOffset(15, 15)
		gem.Rotation = 45
		gem.BackgroundColor3 = WHITE
		gem.BorderSizePixel = 0
		gem.ZIndex = 10
		gem.Parent = tile
		corner(gem, 4)
		PanelChrome.gradient(gem, Color3.fromRGB(255, 250, 190), BRIGHT.GoldDark)
		PanelChrome.stroke(gem, BRIGHT.Outline, 2.5)
	end

	-- The sword fills the tile's face, clear of the stat under it.
	local view = Instance.new("ViewportFrame")
	view.Name = "SwordRender"
	view.BackgroundTransparency = 1
	view.Position = UDim2.fromScale(0.03, 0.0)
	view.Size = UDim2.fromScale(0.94, 0.8)
	view.ZIndex = 8
	view.Parent = tile
	renderSword(view, info, { tiltDeg = 45, margin = 0.74 })

	-- The one stat: rating, trophy and a chunky number centred along the bottom.
	local stat = Instance.new("Frame")
	stat.Name = "Rating"
	stat.BackgroundTransparency = 1
	stat.AnchorPoint = Vector2.new(0.5, 1)
	stat.Position = UDim2.new(0.5, 0, 1, -3)
	stat.Size = UDim2.new(1, -8, 0, 30)
	stat.ZIndex = 10
	stat.Parent = tile
	local statList = Instance.new("UIListLayout")
	statList.FillDirection = Enum.FillDirection.Horizontal
	statList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	statList.VerticalAlignment = Enum.VerticalAlignment.Center
	statList.Padding = UDim.new(0, 1)
	statList.SortOrder = Enum.SortOrder.LayoutOrder
	statList.Parent = stat
	image(stat, TROPHY_ICON, 28, { LayoutOrder = 1, ZIndex = 10 })
	local value = PanelChrome.display(stat, { name = "RatingText", text = SwordValue.short(info.rating or 0), size = 24, stroke = 3, zIndex = 10 })
	value.LayoutOrder = 2
	value.Size = UDim2.fromScale(0, 1)
	value.AutomaticSize = Enum.AutomaticSize.X
	if info.equipped then
		local check = PanelChrome.checkBadge(tile, 28, 11)
		check.Position = UDim2.new(1, -10, 0, 10)
	end
end

local listRows = scope:ForPairs(filteredRowsC, function(use, innerScope, index, info)
	local isSelected = innerScope:Computed(function(use2) return use2(selectedToolName) == info.toolName end)
	local tile = innerScope:New "TextButton" {
		Name = info.toolName,
		LayoutOrder = index,
		Text = "",
		AutoButtonColor = false,
		-- the picked tile draws over its neighbours so its ring and bump are never covered
		ZIndex = innerScope:Computed(function(use2) return use2(isSelected) and 7 or 6 end),
		[OnEvent "Activated"] = function()
			if not peek(spinningValue) then selectTool(info.toolName) end
		end,
		[Children] = {
			innerScope:New "UIScale" { Scale = innerScope:Computed(function(use2) return use2(isSelected) and 1.08 or 1 end) },
			-- Selection: a thick white ring hugging the tile, edged dark so it reads on any rarity.
			innerScope:New "Frame" {
				Name = "SelectRing", BackgroundTransparency = 1, Position = UDim2.fromOffset(-3, -3), Size = UDim2.new(1, 6, 1, 6),
				ZIndex = 12, Visible = isSelected,
				[Children] = {
					innerScope:New "UICorner" { CornerRadius = UDim.new(0, 21) },
					innerScope:New "UIStroke" { Color = WHITE, Thickness = 7 },
				},
			},
			innerScope:New "Frame" {
				Name = "SelectEdge", BackgroundTransparency = 1, Position = UDim2.fromOffset(-10, -10), Size = UDim2.new(1, 20, 1, 20),
				ZIndex = 12, Visible = isSelected,
				[Children] = {
					innerScope:New "UICorner" { CornerRadius = UDim.new(0, 28) },
					innerScope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 3 },
				},
			},
		},
	}
	decorateSwordTile(tile, info)
	return index, tile
end)

-- ── Reactive list: lock chips (one per modifier on the selected sword) ──────
-- Calm white chips like the Inventory's slots: the tier's colour lives only in the padlock
-- badge on the left and the tier line, so the stage keeps one focal point (the hero). A locked
-- chip turns gold.
local LOCKED_TOP, LOCKED_BOTTOM = Color3.fromRGB(255, 246, 196), Color3.fromRGB(255, 212, 90)
local lockChips = scope:ForPairs(modsC, function(use, innerScope, index, mod)
	local isLocked = innerScope:Computed(function(use2) return use2(lockedSet)[mod.name] == true end)
	local top, bottom, deep = tierColors(mod.tier)
	local chip = innerScope:New "TextButton" {
		Name = "Lock_" .. mod.name,
		LayoutOrder = index, -- sized by the lock grid, two chips to a row
		BackgroundColor3 = WHITE,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 7,
		[OnEvent "Activated"] = function() toggleLock(mod.name) end,
		[Children] = {
			innerScope:New "UICorner" { CornerRadius = UDim.new(0, 16) },
			innerScope:New "UIGradient" {
				Rotation = 90,
				Color = innerScope:Computed(function(use2)
					return use2(isLocked) and seq(LOCKED_TOP, LOCKED_BOTTOM) or seq(WHITE, Color3.fromRGB(226, 233, 247))
				end),
			},
			innerScope:New "UIStroke" {
				Color = innerScope:Computed(function(use2) return use2(isLocked) and BRIGHT.GoldDark or BRIGHT.Outline end),
				Thickness = innerScope:Computed(function(use2) return use2(isLocked) and 5 or 3.5 end),
			},
			innerScope:New "UIScale" { Scale = innerScope:Computed(function(use2) return use2(isLocked) and 1.04 or 1 end) },
			-- Tier badge: a rounded square in the tier's colour holding the padlock (the shackle
			-- lifts open when unlocked).
			innerScope:New "Frame" {
				Name = "TierBadge", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0),
				Size = UDim2.fromOffset(50, 50), BackgroundColor3 = WHITE, ZIndex = 8,
				[Children] = {
					innerScope:New "UICorner" { CornerRadius = UDim.new(0, 13) },
					innerScope:New "UIGradient" { Rotation = 90, Color = seq(top, bottom) },
					innerScope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 3 },
					innerScope:New "Frame" {
						Name = "Padlock", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 40), ZIndex = 8,
						[Children] = {
							innerScope:New "Frame" {
								Name = "Shackle", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), ZIndex = 8,
								Position = innerScope:Computed(function(use2)
									return use2(isLocked) and UDim2.new(0.5, 0, 0, 4) or UDim2.new(0.5, 5, 0, -2)
								end),
								Size = UDim2.fromOffset(19, 24),
								[Children] = {
									innerScope:New "UICorner" { CornerRadius = UDim.new(0, 10) },
									innerScope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 4.5 },
								},
							},
							innerScope:New "Frame" {
								Name = "Body", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2),
								Size = UDim2.fromOffset(28, 22), ZIndex = 9,
								BackgroundColor3 = innerScope:Computed(function(use2) return use2(isLocked) and BRIGHT.Gold or WHITE end),
								[Children] = {
									innerScope:New "UICorner" { CornerRadius = UDim.new(0, 6) },
									innerScope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 2.5 },
									innerScope:New "Frame" {
										AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(5, 9),
										BackgroundColor3 = BRIGHT.Outline, ZIndex = 10,
										[Children] = { innerScope:New "UICorner" { CornerRadius = UDim.new(0, 3) } },
									},
								},
							},
						},
					},
				},
			},
			innerScope:New "TextLabel" {
				Name = "ModName", BackgroundTransparency = 1, Position = UDim2.fromOffset(70, 6), Size = UDim2.new(1, -80, 0, 32),
				Font = DISPLAY, Text = mod.name, TextColor3 = BRIGHT.Ink, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
				[Children] = {
					innerScope:New "UITextSizeConstraint" { MaxTextSize = 26, MinTextSize = 16 },
				},
			},
			innerScope:New "TextLabel" {
				Name = "ModInfo", BackgroundTransparency = 1, Position = UDim2.fromOffset(70, 38), Size = UDim2.new(1, -80, 0, 22),
				Font = DISPLAY, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
				TextColor3 = innerScope:Computed(function(use2) return use2(isLocked) and Color3.fromRGB(150, 86, 6) or deep end),
				Text = innerScope:Computed(function(use2)
					local odds = use2(oddsInfoValue)
					local factors = (odds and odds.lockTierFactor) or SwordValue.LOCK_TIER_FACTOR
					local pct = math.floor((factors[mod.tier] or 0) * 100 + 0.5)
					return use2(isLocked) and string.format("LOCKED  +%d%%", pct) or string.format("T%d  ·  lock +%d%%", mod.tier, pct)
				end),
				[Children] = {
					innerScope:New "UITextSizeConstraint" { MaxTextSize = 18, MinTextSize = 14 },
				},
			},
		},
	}
	return index, chip
end)
local modsHintC = scope:Computed(function(use)
	if not use(selectedC) then return "Its modifiers show here. Tap one to lock it before you strike." end
	return #use(modsC) == 0 and "No modifiers yet. Strike to roll some!" or ""
end)

-- ── Scaffolding ──────────────────────────────────────────────────────────────
local screenGui = scope:New "ScreenGui" {
	Name = "ReforgeGuiFusion",
	ResetOnSpawn = false,
	DisplayOrder = 22,
	Parent = playerGui,
}

local panelScale = Instance.new("UIScale")
local popupScale = Instance.new("UIScale")

local chrome = PanelChrome.buildBright({ name = "Modal", title = "Reforge", titleSize = 50, closeSize = CLOSE })
local modal = chrome.Frame
modal.Size = UDim2.fromScale(1, 1)
modal.Active = true
modal.ZIndex = 3
chrome.CloseButton.Activated:Connect(close)
chrome.TitleLabel.Position = UDim2.fromOffset(86, -2)

-- Title badge: the anvil, big and tilted over the panel's top-left corner.
do
	local titleIcon = chrome.TitleIcon
	titleIcon.Image = ""
	titleIcon.Size = UDim2.fromOffset(112, 112)
	titleIcon.Position = UDim2.fromOffset(-32, -4)
	titleIcon.Rotation = -6
	local titleAnvil = Instance.new("ViewportFrame")
	titleAnvil.Name = "Anvil"
	titleAnvil.BackgroundTransparency = 1
	titleAnvil.Size = UDim2.fromScale(1, 1)
	titleAnvil.ZIndex = titleIcon.ZIndex
	titleAnvil.Parent = titleIcon
	renderAnvil(titleAnvil)
end

-- ── Header: gold pill and the anvil's promise ────────────────────────────────
local GOLD_W_WIDE, GOLD_W_TALL = 210, 150
local goldPill = scope:New "Frame" {
	Name = "GoldPill", AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -(CLOSE + 26), 0, HEADER_H / 2 + 2),
	Size = L(function(l) return UDim2.fromOffset(l.wide and GOLD_W_WIDE or GOLD_W_TALL, 52) end),
	BackgroundColor3 = WHITE, ZIndex = 8,
	[Children] = {
		scope:New "UICorner" { CornerRadius = UDim.new(0, 26) },
		scope:New "UIGradient" { Rotation = 90, Color = seq(Color3.fromRGB(255, 255, 255), Color3.fromRGB(226, 232, 246)) },
		scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 3.5 },
	},
}
image(goldPill, COIN_ICON, 64, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -22, 0.5, -2), ZIndex = 9 })
do
	local goldLabel = PanelChrome.display(goldPill, {
		name = "GoldAmount", text = "0", size = 34, stroke = 3, color = BRIGHT.Gold,
		pos = UDim2.fromOffset(44, 0), size2 = UDim2.new(1, -56, 1, 0), zIndex = 9, scaled = true, minSize = 14,
	})
	scope:Hydrate(goldLabel) { Text = scope:Computed(function(use) return goldText(use(goldValue)) end) }
end
goldPill.Parent = modal

scope:Hydrate(chrome.TitleLabel) {
	Size = L(function(l)
		return UDim2.new(0, math.max(120, l.W - 86 - (CLOSE + 26 + (l.wide and GOLD_W_WIDE or GOLD_W_TALL) + 16)), 0, 58)
	end),
}

-- ── Rarity rail ──────────────────────────────────────────────────────────────
local rail = scope:New "Frame" {
	Name = "RarityRail", Parent = modal,
	Position = UDim2.fromOffset(RAIL_X, HEADER_H + 14),
	Size = UDim2.fromOffset(RAIL_W, #RARITIES * (TAB + 8) + 16),
	BackgroundColor3 = WHITE, ZIndex = 6,
	[Children] = {
		scope:New "UICorner" { CornerRadius = UDim.new(0, 24) },
		scope:New "UIGradient" { Rotation = 90, Color = seq(BRIGHT.Panel, BRIGHT.PanelBottom) },
		scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 4 },
		scope:New "UIListLayout" {
			Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
		},
		scope:New "UIPadding" { PaddingTop = UDim.new(0, 8) },
	},
}
for i, rarity in ipairs(RARITIES) do
	local isActive = scope:Computed(function(use) return use(filterValue) == rarity end)
	local countC = scope:Computed(function(use)
		local n = 0
		for _, info in ipairs(use(rowsValue)) do
			if rarity == "All" or info.rarity == rarity then n += 1 end
		end
		return n
	end)
	local tab = scope:New "TextButton" {
		Name = "Tab_" .. rarity, Parent = rail, LayoutOrder = i, Text = "", AutoButtonColor = false,
		Size = UDim2.fromOffset(TAB, TAB), ZIndex = 7,
		BackgroundColor3 = scope:Computed(function(use) return use(isActive) and BRIGHT.Select or BRIGHT.Row end),
		[OnEvent "Activated"] = function() filterValue:set(rarity) end,
		[Children] = {
			scope:New "UICorner" { CornerRadius = UDim.new(0, 18) },
			scope:New "UIStroke" {
				Color = scope:Computed(function(use) return use(isActive) and BRIGHT.Blue or BRIGHT.RowStroke end),
				Thickness = scope:Computed(function(use) return use(isActive) and 3.5 or 2.5 end),
			},
		},
	}
	if rarity == "All" then
		local view = Instance.new("ViewportFrame")
		view.Name = "Anvil"
		view.BackgroundTransparency = 1
		view.Position = UDim2.fromScale(-0.05, 0)
		view.Size = UDim2.fromScale(1.1, 1.1)
		view.ZIndex = 8
		view.Parent = tab
		renderAnvil(view)
	else
		gemIcon(tab, 34, rarity, 8)
	end
	local badge, badgeLabel = PanelChrome.countBadge(tab, "0", 9)
	scope:Hydrate(badge) { Visible = scope:Computed(function(use) return use(countC) > 0 end) }
	scope:Hydrate(badgeLabel) { Text = scope:Computed(function(use) return tostring(use(countC)) end) }
end

-- ── Sword tray ───────────────────────────────────────────────────────────────
local trayHeadPos = L(function(l)
	return l.wide and UDim2.fromOffset(X0 + 6, HEADER_H) or UDim2.fromOffset(X0 + 6, HEADER_H + STAGE_TOP + STAGE_H + 14)
end)
scope:New "Frame" {
	Name = "TrayHead", Parent = modal, BackgroundTransparency = 1, ZIndex = 7,
	Position = trayHeadPos,
	Size = L(function(l) return UDim2.fromOffset((l.wide and l.trayW or l.stageW) - 6, SEC_H) end),
	[Children] = {
		scope:New "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder,
		},
		scope:New "TextLabel" {
			LayoutOrder = 1, BackgroundTransparency = 1, Font = DISPLAY, TextSize = 30, TextColor3 = BRIGHT.Ink,
			Text = "Relic Swords", Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 7,
		},
		scope:New "TextLabel" {
			LayoutOrder = 2, BackgroundTransparency = 1, Font = DISPLAY, TextSize = 30, TextColor3 = BRIGHT.Blue,
			Text = scope:Computed(function(use) return tostring(#use(filteredRowsC)) end),
			Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 7,
			[Children] = { scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 2.5 } },
		},
	},
}

local trayScroll = scope:New "ScrollingFrame" {
	Name = "SwordScroll", BackgroundTransparency = 1, BorderSizePixel = 0,
	Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), ZIndex = 5,
	ScrollBarThickness = SCROLLBAR, ScrollBarImageColor3 = BRIGHT.GreyDark, ScrollingDirection = Enum.ScrollingDirection.Y,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	[Children] = {
		scope:New "UIPadding" {
			PaddingTop = UDim.new(0, TOP_PAD), PaddingBottom = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, TRAY_PAD - 4), PaddingRight = UDim.new(0, SCROLLBAR + 2),
		},
		scope:New "UIGridLayout" {
			CellSize = UDim2.fromOffset(TILE, TILE), CellPadding = UDim2.fromOffset(GAP, VGAP),
			FillDirectionMaxCells = 3, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		listRows,
	},
}
local tray = scope:New "Frame" {
	Name = "SwordTray", Parent = modal, ZIndex = 4, ClipsDescendants = false,
	Position = L(function(l)
		return l.wide and UDim2.fromOffset(X0, HEADER_H + SEC_H) or UDim2.fromOffset(X0, HEADER_H + STAGE_TOP + STAGE_H + 14 + SEC_H)
	end),
	Size = L(function(l)
		return UDim2.fromOffset(l.wide and l.trayW or l.stageW, l.trayH)
	end),
}
PanelChrome.insetTray(tray, { top = Color3.fromRGB(230, 237, 252), bottom = Color3.fromRGB(206, 218, 242), radius = 22, zIndex = 4, strokeThickness = 3.5 })
trayScroll.Parent = tray
scope:New "TextLabel" {
	Name = "EmptyNote", Parent = tray, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.new(1, -40, 0, 80), ZIndex = 6,
	Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = BRIGHT.InkMuted, TextWrapped = true,
	Visible = scope:Computed(function(use) return #use(filteredRowsC) == 0 end),
	Text = scope:Computed(function(use)
		local f = use(filterValue)
		return f == "All" and "No relic swords yet. Boss drops can be reforged here." or ("No " .. f .. " relic swords.")
	end),
}

-- ── Stage ────────────────────────────────────────────────────────────────────
local stage = scope:New "Frame" {
	Name = "Stage", Parent = modal, BackgroundTransparency = 1, ZIndex = 4,
	Position = L(function(l)
		return UDim2.fromOffset(l.wide and (X0 + l.trayW + MID) or X0, HEADER_H + STAGE_TOP)
	end),
	Size = L(function(l) return UDim2.fromOffset(l.stageW, STAGE_H) end),
}

-- Hero card: one calm featured item, like the Inventory's. A white card; the rarity shows only as
-- the glow ring behind the sword and the rim of its framed tile, so every label stays readable.
local HERO_RING = 1.44 -- the glow ring's diameter, as a multiple of the framed tile
local heroTileSize = L(function(l) return l.wide and 150 or 122 end)
local heroRingSize = scope:Computed(function(use) return math.floor(use(heroTileSize) * HERO_RING) end)
local heroInfoX = scope:Computed(function(use) return 14 + use(heroRingSize) + 22 end)
local heroTintC = scope:Computed(function(use)
	local info = use(selectedC)
	return info and (RARITY_TILE[info.rarity] or RARITY_TILE.Common) or false
end)
local EMPTY_GLOW, EMPTY_RIM = Color3.fromRGB(214, 222, 240), Color3.fromRGB(168, 180, 206)

local heroCard = scope:New "Frame" {
	Name = "HeroCard", Parent = stage, Position = UDim2.fromOffset(0, HERO_Y), Size = UDim2.new(1, 0, 0, HERO_H),
	BackgroundColor3 = WHITE, ZIndex = 5, ClipsDescendants = false,
	[Children] = {
		scope:New "UICorner" { CornerRadius = UDim.new(0, 24) },
		scope:New "UIGradient" { Rotation = 90, Color = seq(WHITE, Color3.fromRGB(229, 236, 250)) },
		scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 4 },
	},
}

-- Light burst behind the item: a slowly turning fan of rarity-tinted rays over a soft glow disc
-- ringed in the rarity's colour, with a thin white ring inside it like the Inventory's.
local heroCentre = scope:Computed(function(use)
	return UDim2.fromOffset(14 + use(heroRingSize) / 2, HERO_H / 2)
end)
local function ringSize(extra)
	return scope:Computed(function(use) local s = use(heroRingSize) + extra return UDim2.fromOffset(s, s) end)
end
local rays = scope:New "Frame" {
	Name = "Rays", Parent = heroCard, AnchorPoint = Vector2.new(0.5, 0.5), Position = heroCentre,
	Size = ringSize(10), BackgroundTransparency = 1, ZIndex = 5,
}
local rayList = {}
for i = 0, 5 do
	local ray = Instance.new("Frame")
	ray.AnchorPoint = Vector2.new(0.5, 0.5)
	ray.Position = UDim2.fromScale(0.5, 0.5)
	ray.Size = UDim2.new(0, 30, 1, 0)
	ray.Rotation = i * 30
	ray.BackgroundColor3 = EMPTY_GLOW
	ray.BorderSizePixel = 0
	ray.ZIndex = 5
	ray.Parent = rays
	corner(ray, 12)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 0.75),
	})
	g.Parent = ray
	table.insert(rayList, ray)
end
scope:New "Frame" {
	Name = "GlowRing", Parent = heroCard, AnchorPoint = Vector2.new(0.5, 0.5), Position = heroCentre, Size = ringSize(-14),
	BackgroundColor3 = scope:Computed(function(use) local t = use(heroTintC) return t and t.top or EMPTY_GLOW end),
	BackgroundTransparency = 0.35, ZIndex = 5,
	[Children] = {
		scope:New "UICorner" { CornerRadius = UDim.new(1, 0) },
		scope:New "UIStroke" {
			Color = scope:Computed(function(use) local t = use(heroTintC) return t and t.bottom or EMPTY_RIM end),
			Thickness = 5, Transparency = 0.2,
		},
		scope:New "Frame" {
			Name = "Core", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8),
			BackgroundColor3 = WHITE, BackgroundTransparency = 0.45, ZIndex = 5,
			[Children] = {
				scope:New "UICorner" { CornerRadius = UDim.new(1, 0) },
				scope:New "UIStroke" { Color = WHITE, Thickness = 3, Transparency = 0.1 },
			},
		},
	},
}
scope:Observer(heroTintC):onBind(function()
	local t = peek(heroTintC)
	for _, ray in ipairs(rayList) do ray.BackgroundColor3 = t and t.bottom or EMPTY_GLOW end
end)

local heroTile = scope:New "Frame" {
	Name = "HeroTile", Parent = heroCard, AnchorPoint = Vector2.new(0.5, 0.5), Position = heroCentre,
	Size = scope:Computed(function(use) local s = use(heroTileSize) return UDim2.fromOffset(s, s) end),
	BackgroundColor3 = WHITE, ZIndex = 6,
}

local heroPulse -- the empty slot's breathing prompt
local function renderHero()
	if heroPulse then heroPulse:Cancel() heroPulse = nil end
	for _, c in ipairs(heroTile:GetChildren()) do c:Destroy() end
	local info = peek(selectedC)
	heroTile.BackgroundTransparency = 0
	if info then
		-- A white frame with a thick rarity rim: the icon's colour comes from the glow behind it.
		local t = RARITY_TILE[info.rarity or "Common"] or RARITY_TILE.Common
		corner(heroTile, 24)
		PanelChrome.gradient(heroTile, WHITE, t.top:Lerp(WHITE, 0.45)).Rotation = 70
		PanelChrome.stroke(heroTile, BRIGHT.Outline, 4)
		local rim = Instance.new("Frame")
		rim.Name = "RarityRim"
		rim.BackgroundTransparency = 1
		rim.Position = UDim2.fromOffset(4, 4)
		rim.Size = UDim2.new(1, -8, 1, -8)
		rim.ZIndex = 6
		rim.Parent = heroTile
		corner(rim, 20)
		PanelChrome.stroke(rim, t.bottom, 5)
		local shine = Instance.new("Frame")
		shine.Name = "Shine"
		shine.BackgroundColor3 = WHITE
		shine.BackgroundTransparency = 0.35
		shine.BorderSizePixel = 0
		shine.Position = UDim2.fromOffset(10, 10)
		shine.Size = UDim2.new(1, -20, 0.22, 0)
		shine.ZIndex = 6
		shine.Parent = heroTile
		corner(shine, 12)
		if info.blessed then
			local halo = Instance.new("Frame")
			halo.Name = "BlessedHalo"
			halo.BackgroundTransparency = 1
			halo.Position = UDim2.fromOffset(-7, -7)
			halo.Size = UDim2.new(1, 14, 1, 14)
			halo.ZIndex = 6
			halo.Parent = heroTile
			corner(halo, 30)
			PanelChrome.stroke(halo, BRIGHT.Gold, 4)
		end
		-- The sword is drawn bigger than its frame so it breaks out of it, like rendered item art.
		local view = Instance.new("ViewportFrame")
		view.Name = "SwordRender"
		view.BackgroundTransparency = 1
		view.AnchorPoint = Vector2.new(0.5, 0.5)
		view.Position = UDim2.fromScale(0.5, 0.47)
		view.Size = UDim2.fromScale(1.36, 1.36)
		view.ZIndex = 8
		view.Parent = heroTile
		renderSword(view, info, { tiltDeg = 45, margin = 0.8 })
		if info.equipped then
			local check = PanelChrome.checkBadge(heroTile, 36, 10)
			check.Position = UDim2.new(1, -6, 0, 6)
		end
	else
		-- Empty slot: a recessed well with a dashed rim, a ghosted sword and a breathing prompt.
		PanelChrome.emptyWell(heroTile, { radius = 24, zIndex = 6, color = Color3.fromRGB(226, 234, 250) })
		PanelChrome.dashedOutline(heroTile, { color = BRIGHT.GreyDark, radius = 24, thickness = 4, dashes = 4, zIndex = 7 })
		local ghost = Instance.new("ViewportFrame")
		ghost.Name = "Silhouette"
		ghost.BackgroundTransparency = 1
		ghost.Position = UDim2.fromScale(0.08, 0.02)
		ghost.Size = UDim2.fromScale(0.84, 0.72)
		ghost.ImageColor3 = Color3.fromRGB(112, 124, 156)
		ghost.ImageTransparency = 0.35
		ghost.ZIndex = 7
		ghost.Parent = heroTile
		local standIn = buildStandInSword(1)
		PanelChrome.renderTool(ghost, standIn, { tiltDeg = 45, margin = 0.9, ambient = Color3.new(0, 0, 0) })
		standIn:Destroy()
		local prompt = PanelChrome.display(heroTile, {
			name = "Prompt", text = "Pick a sword", size = 22, stroke = 2.5, anchor = Vector2.new(0.5, 0.5),
			pos = UDim2.fromScale(0.5, 0.82), size2 = UDim2.new(1, -16, 0, 30), scaled = true, minSize = 12, zIndex = 9,
		})
		local ps = Instance.new("UIScale")
		ps.Parent = prompt
		heroPulse = TweenService:Create(ps, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.12 })
		heroPulse:Play()
	end
end
scope:Observer(selectedC):onBind(renderHero)

-- Hero info column: three things with room around them, like the Inventory's featured item --
-- the sword's name in big display type, its rarity and power on one line, and the lucky-roll
-- bar. The cost and the free strike live on the Reforge button; the stats behind Odds.
local heroInfo = scope:New "Frame" {
	Name = "HeroInfo", Parent = heroCard, BackgroundTransparency = 1, ZIndex = 7,
	Position = scope:Computed(function(use) return UDim2.fromOffset(use(heroInfoX), 14) end),
	Size = scope:Computed(function(use) return UDim2.new(1, -(use(heroInfoX) + 18), 1, -28) end),
	[Children] = {
		scope:New "UIListLayout" {
			Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
		},
	},
}
local heroName = PanelChrome.display(heroInfo, {
	name = "HeroName", text = "Pick a sword", size = 48, stroke = 4.5, xAlign = Enum.TextXAlignment.Left,
	size2 = UDim2.new(1, 0, 0, 54), scaled = true, minSize = 20, zIndex = 8,
})
heroName.LayoutOrder = 1
scope:Hydrate(heroName) { Text = selectedTitleTextC }

local hasSelectionC = scope:Computed(function(use) return use(selectedC) ~= nil end)
do
	-- One rarity pill, then the sword's power: a big trophy and a chunky number.
	local rarityRow = scope:New "Frame" {
		Name = "RarityPower", Parent = heroInfo, LayoutOrder = 2, BackgroundTransparency = 1, ZIndex = 7,
		Size = UDim2.new(1, 0, 0, 46), Visible = hasSelectionC,
		[Children] = {
			scope:New "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder,
			},
			pill(scope, {
				name = "Rarity", order = 1, height = 38, textSize = 21,
				text = scope:Computed(function(use) local info = use(selectedC) return info and string.upper(info.rarity) or "" end),
				gradient = scope:Computed(function(use)
					local info = use(selectedC)
					local t = RARITY_TILE[info and info.rarity or "Common"] or RARITY_TILE.Common
					return seq(t.bottom, t.rim)
				end),
			}),
		},
	}
	local power = scope:New "Frame" {
		Name = "Power", Parent = rarityRow, LayoutOrder = 2, BackgroundTransparency = 1, ZIndex = 7,
		Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X,
		[Children] = {
			scope:New "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
			},
		},
	}
	image(power, TROPHY_ICON, 44, { LayoutOrder = 1, ZIndex = 8 })
	local powerLabel = PanelChrome.display(power, { name = "PowerValue", text = "", size = 40, stroke = 4, zIndex = 8 })
	powerLabel.LayoutOrder = 2
	powerLabel.Size = UDim2.fromScale(0, 1)
	powerLabel.AutomaticSize = Enum.AutomaticSize.X
	scope:Hydrate(powerLabel) {
		Text = scope:Computed(function(use) local info = use(selectedC) return info and SwordValue.short(info.rating or 0) or "" end),
	}
end

-- Lucky roll: one thick level bar with its caption and count inside it.
do
	local LUCKY_H = 38
	scope:New "Frame" {
		Name = "LuckyRoll", Parent = heroInfo, LayoutOrder = 3, ZIndex = 8,
		Size = UDim2.new(1, -4, 0, LUCKY_H), BackgroundColor3 = Color3.fromRGB(58, 64, 96), Visible = hasSelectionC,
		[Children] = {
			scope:New "UICorner" { CornerRadius = UDim.new(1, 0) },
			scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 3.5 },
			scope:New "Frame" {
				Name = "Fill", ZIndex = 9, BackgroundColor3 = WHITE,
				Size = scope:Computed(function(use) return UDim2.fromScale(math.max(use(pityFracC), 0.1), 1) end),
				[Children] = {
					scope:New "UICorner" { CornerRadius = UDim.new(1, 0) },
					scope:New "UIGradient" { Rotation = 90, Color = seq(Color3.fromRGB(150, 228, 255), Color3.fromRGB(34, 142, 236)) },
				},
			},
			scope:New "TextLabel" {
				Name = "LuckyText", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0),
				ZIndex = 10, Font = DISPLAY, TextScaled = true, TextColor3 = WHITE,
				Text = scope:Computed(function(use)
					local short = use(pityShortC)
					return short == "" and "LUCKY ROLL" or ("LUCKY ROLL  ·  " .. short)
				end),
				[Children] = {
					scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 2.5 },
					scope:New "UITextSizeConstraint" { MaxTextSize = 21, MinTextSize = 14 },
				},
			},
		},
	}
end

scope:New "TextLabel" {
	Name = "EmptyHint", Parent = heroInfo, LayoutOrder = 6, BackgroundTransparency = 1, ZIndex = 8,
	Size = UDim2.new(1, 0, 0, 96), Visible = scope:Computed(function(use) return not use(hasSelectionC) end),
	Font = DISPLAY, TextSize = 22, TextColor3 = BRIGHT.Ink, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	Text = L(function(l)
		return (l.wide and "Tap a relic sword on the left" or "Tap a relic sword below") .. " to set it on the anvil, then strike to re-roll its modifiers."
	end),
}

-- Modifier lock chips: a two-column grid that wraps, so every name shows in full.
local modsGrid = scope:New "Frame" {
	Name = "Mods", Parent = stage, BackgroundTransparency = 1, ZIndex = 5,
	Position = UDim2.fromOffset(0, MODS_Y), Size = UDim2.new(1, 0, 0, MODS_H),
	Visible = scope:Computed(function(use) return not use(revealingValue) end),
	[Children] = {
		scope:New "UIPadding" { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) },
		scope:New "UIGridLayout" {
			CellSize = UDim2.new(0.5, -CHIP_GAP / 2, 0, CHIP_H), CellPadding = UDim2.fromOffset(CHIP_GAP, CHIP_GAP),
			FillDirectionMaxCells = 2, VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		lockChips,
	},
}
scope:New "TextLabel" {
	Name = "ModsHint", Parent = modsGrid, BackgroundTransparency = 1, ZIndex = 6,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -40, 0, 70),
	Font = DISPLAY, TextSize = 24, TextColor3 = BRIGHT.InkMuted, TextWrapped = true,
	Text = modsHintC, Visible = scope:Computed(function(use) return use(modsHintC) ~= "" end),
}


-- Button row: Odds, the big Reforge button, Animation toggle.
local ODDS_W = L(function(l) return l.wide and 108 or 92 end)
local ANIM_W = L(function(l) return l.wide and 118 or 100 end)
local strikeRow = scope:New "Frame" {
	Name = "StrikeRow", Parent = stage, BackgroundTransparency = 1, ZIndex = 5,
	Position = UDim2.fromOffset(0, STRIKE_Y), Size = UDim2.new(1, 0, 0, STRIKE_H),
	[Children] = {
		scope:New "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder,
		},
	},
}

local oddsHolder, oddsBtn, oddsLabel = chunky({
	name = "OddsButton", order = 1, text = "ODDS", textSize = 18, color = Color3.fromRGB(110, 196, 255), colorDark = Color3.fromRGB(30, 110, 220),
	size = scope:Computed(function(use) return UDim2.fromOffset(use(ODDS_W), STRIKE_H) end),
})
oddsLabel.Position = UDim2.new(0, 6, 1, -32)
oddsLabel.Size = UDim2.new(1, -12, 0, 24)
PanelChrome.display(oddsBtn, { name = "Glyph", text = "?", size = 40, stroke = 3.5, pos = UDim2.fromOffset(0, 2), size2 = UDim2.new(1, 0, 0, 44), zIndex = 9 })
oddsBtn.Activated:Connect(function() setOddsPopupVisible(not peek(oddsPopupVisible)) end)
oddsHolder.Parent = strikeRow

local strikeHolder, strikeBtn, strikeLabel, strikeGrad, strikeLip = chunky({
	name = "StrikeButton", order = 2, text = "FORGE", textSize = 32, color = BRIGHT.Green, colorDark = BRIGHT.GreenDark,
	size = scope:Computed(function(use)
		return UDim2.fromOffset(use(layout).stageW - use(ODDS_W) - use(ANIM_W) - 24, STRIKE_H)
	end),
})
strikeBtn.Activated:Connect(strike)
local showCostC = scope:Computed(function(use) return use(selectedC) ~= nil and not use(spinningValue) end)
scope:Hydrate(strikeLabel) {
	Text = strikeLabelC,
	Position = scope:Computed(function(use) return use(showCostC) and UDim2.fromOffset(8, 4) or UDim2.fromOffset(8, 10) end),
	Size = scope:Computed(function(use) return use(showCostC) and UDim2.new(1, -16, 0, 38) or UDim2.new(1, -16, 1, -26) end),
}
scope:Observer(strikeReadyC):onBind(function()
	local ready = peek(strikeReadyC)
	strikeGrad.Color = ready and seq(BRIGHT.Green, BRIGHT.GreenDark) or seq(BRIGHT.Grey, BRIGHT.GreyDark)
	strikeLip.BackgroundColor3 = ready and Color3.fromRGB(30, 128, 40) or Color3.fromRGB(124, 132, 150)
end)
do
	local strikeCost = scope:New "Frame" {
		Name = "Cost", Parent = strikeBtn, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.new(1, -16, 0, 28), ZIndex = 10, Visible = showCostC,
		[Children] = {
			scope:New "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
			},
		},
	}
	local strikeCoin = image(strikeCost, COIN_ICON, 30, { LayoutOrder = 1, ZIndex = 10 })
	scope:Hydrate(strikeCoin) { Visible = scope:Computed(function(use) return use(costC) > 0 end) }
	local strikeCostLabel = PanelChrome.display(strikeCost, { name = "CostAmount", text = "", size = 26, stroke = 2.5, zIndex = 10 })
	strikeCostLabel.LayoutOrder = 2
	strikeCostLabel.Size = UDim2.fromScale(0, 1)
	strikeCostLabel.AutomaticSize = Enum.AutomaticSize.X
	scope:Hydrate(strikeCostLabel) {
		Text = costTextC,
		TextColor3 = scope:Computed(function(use)
			if use(costC) > 0 and not use(affordC) then return Color3.fromRGB(255, 150, 150) end
			return use(costC) == 0 and Color3.fromRGB(200, 255, 170) or Color3.fromRGB(255, 230, 110)
		end),
	}
	strikeHolder.Parent = strikeRow
end

do
	local animHolder, animBtn, animLabel = chunky({
		name = "AnimationToggle", order = 3, text = "ANIM", textSize = 18,
		color = Color3.fromRGB(206, 150, 255), colorDark = Color3.fromRGB(130, 60, 220),
		size = scope:Computed(function(use) return UDim2.fromOffset(use(ANIM_W), STRIKE_H) end),
	})
	animLabel.Position = UDim2.new(0, 6, 1, -32)
	animLabel.Size = UDim2.new(1, -12, 0, 24)
	local animState = PanelChrome.display(animBtn, { name = "State", text = "ON", size = 32, stroke = 3, pos = UDim2.fromOffset(4, 6), size2 = UDim2.new(1, -8, 0, 38), zIndex = 9 })
	scope:Hydrate(animState) {
		Text = scope:Computed(function(use) return use(skipAnimationValue) and "SKIP" or "ON" end),
		TextColor3 = scope:Computed(function(use) return use(skipAnimationValue) and Color3.fromRGB(255, 226, 110) or Color3.fromRGB(190, 255, 160) end),
	}
	animBtn.Activated:Connect(function() skipAnimationValue:set(not peek(skipAnimationValue)) end)
	animHolder.Parent = strikeRow
end

-- ── Window, overlay and the odds popup ───────────────────────────────────────
local window = scope:New "Frame" {
	Name = "ReforgeWindow", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 2,
	Position = L(function(l) return UDim2.new(0.5, math.floor(11 * l.s), 0.5, math.floor(14 * l.s)) end),
	Size = L(function(l) return UDim2.fromOffset(l.W, l.H) end),
	[Children] = {
		panelScale,
		scope:New "Frame" {
			Name = "DropShadow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 12),
			Size = UDim2.new(1, 12, 1, 12), BackgroundColor3 = Color3.fromRGB(8, 8, 18), BackgroundTransparency = 0.4, ZIndex = 2,
			[Children] = { scope:New "UICorner" { CornerRadius = UDim.new(0, 28) } },
		},
		modal,
	},
}

local popup = scope:New "Frame" {
	Name = "OddsPopup", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(POPUP_W, POPUP_H), BackgroundColor3 = WHITE, ZIndex = 30, Visible = oddsPopupVisible, Active = true,
	[Children] = {
		popupScale,
		scope:New "UICorner" { CornerRadius = UDim.new(0, 22) },
		scope:New "UIGradient" { Rotation = 90, Color = seq(BRIGHT.Panel, BRIGHT.PanelBottom) },
		scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 4.5 },
		scope:New "Frame" {
			Name = "Tiers", BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 48), Size = UDim2.new(1, -40, 0, 216), ZIndex = 31,
			[Children] = {
				scope:New "UIGridLayout" {
					CellSize = UDim2.fromOffset(math.floor((POPUP_W - 40 - 4 * 8) / 5), 104), CellPadding = UDim2.fromOffset(8, 8),
					SortOrder = Enum.SortOrder.LayoutOrder, FillDirectionMaxCells = 5,
				},
			},
		},
		scope:New "TextLabel" {
			Name = "LuckLine", BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 270), Size = UDim2.new(1, -44, 0, 30),
			TextScaled = true, TextColor3 = Color3.fromRGB(150, 86, 6), TextXAlignment = Enum.TextXAlignment.Left,
			Font = DISPLAY, ZIndex = 31, Text = luckLineC,
			[Children] = {
				scope:New "UITextSizeConstraint" { MaxTextSize = 22, MinTextSize = 12 },
				scope:New "UIStroke" { Color = BRIGHT.Outline, Thickness = 1.5 },
			},
		},
		scope:New "TextLabel" {
			Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 304), Size = UDim2.new(1, -44, 1, -366),
			TextSize = 16, TextColor3 = BRIGHT.Ink, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, ZIndex = 31, Text = oddsPopupTextC,
		},
		scope:New "TextLabel" {
			Name = "Record", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 22, 1, -16),
			Size = UDim2.new(1, -44, 0, 34), TextScaled = true, RichText = true, TextColor3 = BRIGHT.Ink,
			TextXAlignment = Enum.TextXAlignment.Left, Font = DISPLAY, ZIndex = 31, Text = statsLineC,
			[Children] = { scope:New "UITextSizeConstraint" { MaxTextSize = 22, MinTextSize = 14 } },
		},
	},
}
for tier = 1, WeaponModifiers.TIER_COUNT do
	tierTile(tier, UDim2.fromOffset(100, 100)).Parent = popup:FindFirstChild("Tiers")
end
do
	local popupTitle = PanelChrome.display(popup, {
		name = "Title", text = "Reforge Odds: 1 in N per slot", size = 38, stroke = 3.5, xAlign = Enum.TextXAlignment.Left,
		anchor = Vector2.new(0, 0.5), pos = UDim2.fromOffset(22, -2), size2 = UDim2.new(0.7, 0, 0, 48), zIndex = 32,
	})
	local popupClose = PanelChrome.chunkyButton(popup, {
		name = "CloseButton", text = "X", color = BRIGHT.Red, colorDark = BRIGHT.RedDark,
		size = UDim2.fromOffset(CLOSE, CLOSE), anchor = Vector2.new(0.5, 0.5), pos = UDim2.new(1, -22, 0, 2),
		textSize = 36, zIndex = 33, radius = 14, strokeThickness = 3.5,
	})
	popupClose.Activated:Connect(function() setOddsPopupVisible(false) end)
end

local overlay = scope:New "TextButton" {
	Name = "Overlay",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.5,
	Text = "",
	AutoButtonColor = false,
	Visible = overlayVisible,
	Parent = screenGui,
	[OnEvent "Activated"] = close,
	[Children] = {
		window,
		scope:New "TextButton" {
			Name = "PopupBackdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35,
			Text = "", AutoButtonColor = false, ZIndex = 29,
			Visible = oddsPopupVisible,
			[OnEvent "Activated"] = function() setOddsPopupVisible(false) end,
		},
		popup,
	},
}

-- The window grows in while the backdrop dims, then the sword tray's tiles land row by row.
reforgeMotion = {
	frame = window, scale = panelScale, dim = overlay, dimTo = 0.5,
	tiles = function() return { trayScroll } end,
}

-- ── Responsive layout: side by side when it fits, stacked on phones ──────────
local function applyLayout(viewport: Vector2)
	local availX, availY = viewport.X - 8, viewport.Y - 100
	local wideW = X0 + TRAY_W_WIDE + MID + STAGE_W_WIDE + EDGE
	local wideH = HEADER_H + STAGE_TOP + STAGE_H + EDGE
	local sWide = math.min(1, availX / (wideW + 26), availY / wideH)
	local tallW = X0 + STAGE_W_TALL + EDGE
	local tallBase = HEADER_H + STAGE_TOP + STAGE_H + 14 + SEC_H + EDGE
	local rowH = TILE + VGAP
	local sTall = math.min(1, availX / (tallW + 22))
	local tallH = math.clamp(availY / sTall, tallBase + TOP_PAD + 2 * rowH + 16, tallBase + TOP_PAD + 3.4 * rowH)
	sTall = math.min(sTall, availY / tallH)
	if sWide >= sTall * 0.92 then
		layout:set({ wide = true, s = math.max(sWide, 0.3), W = wideW, H = wideH, stageW = STAGE_W_WIDE, trayW = TRAY_W_WIDE, trayH = TRAY_H_WIDE })
	else
		layout:set({
			wide = false, s = math.max(sTall, 0.3), W = tallW, H = math.floor(tallH), stageW = STAGE_W_TALL, trayW = STAGE_W_TALL,
			trayH = math.floor(tallH) - (tallBase - EDGE),
		})
	end
end
scope:Observer(layout):onBind(function()
	local s = peek(layout).s
	panelScale.Scale = s
	local camera = workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(POPUP_W, POPUP_H)
	popupScale.Scale = math.min(s * 1.1, 1, (vp.X - 16) / POPUP_W, (vp.Y - 16) / POPUP_H)
end)
PanelChrome.onViewport(applyLayout)

-- Rays behind the hero turn slowly while the window is open.
RunService.RenderStepped:Connect(function(dt)
	if peek(overlayVisible) then
		rays.Rotation = (rays.Rotation + dt * 12) % 360
	end
end)

-- ── The forge strike (imperative, like the reveal -- see the file header) ─────
-- Paying lights a meter instead of rolling: a marker sweeps a bar with a sweet zone on it, and
-- the player times a hammer blow. The server owns the meter (ReforgeSystem): it sends the plan
-- (when the marker started, how fast it sweeps, where the sweet zone is), the client only draws
-- it from that plan and reports the instant it pressed. The word that appears -- PERFECT, GOOD
-- or OK -- is the server's reply, never the client's guess.
--
-- It is built inside one closure, and the panel only ever sees the handful of calls `Forge`
-- returns: the main chunk is already at Luau's 200-local ceiling, and a one-shot animation has
-- no business spending forty of them.
local Forge = (function()
-- Design space; one UIScale fits it to any screen. The anvil and the sword ARE the shot: they
-- sit big and centred with the meter directly under them, and the whole legend is one line.
local FORGE_W, FORGE_H = 1440, 690
local METER_X, METER_Y, METER_W, METER_H = 120, 440, 1200, 110
local METER_PAD = 10 -- the marker's travel is inset from the track's ends
local MARKER_W = 13  -- a thin bright column: it must never hide a band's own label
-- The forge plate: a dark slab the anvil is lit against, because the anvil is iron and the
-- panel behind it is white. It is cut tight around the anvil -- a wide slab only made the
-- biggest thing on screen a black rectangle.
local PLATE_X, PLATE_Y, PLATE_W, PLATE_H = 420, 0, 600, 408
local ANVIL_X, ANVIL_Y, ANVIL_W, ANVIL_H = 440, 6, 560, 394
local SPARK_X, SPARK_Y = 714, 212 -- the anvil's face, in design space: where the hammer lands
local HAMMER_UP, HAMMER_DOWN = math.rad(-44), math.rad(2)
-- Screen shake is 3-4 px at its hardest, not a camera tantrum; the punch comes from the hitstop,
-- the white frame and the anvil's own squash.
local QUALITY = {
	PERFECT = { color = Color3.fromRGB(128, 238, 92), dark = Color3.fromRGB(38, 158, 48), shake = 4.2, sparks = 34, word = "PERFECT!" },
	GOOD    = { color = Color3.fromRGB(255, 212, 60), dark = Color3.fromRGB(226, 142, 18), shake = 3.4, sparks = 20, word = "GOOD!" },
	OK      = { color = Color3.fromRGB(128, 200, 255), dark = Color3.fromRGB(38, 122, 208), shake = 2.6, sparks = 12, word = "OK" },
	MISS    = { color = Color3.fromRGB(255, 112, 122), dark = Color3.fromRGB(166, 36, 50), shake = 1.4, sparks = 5, word = "MISS" },
}

-- Where the marker sits (0..1) at server time `t` -- the same arithmetic the server validates
-- against, so what the player sees is what the server scores.
local function markerAt(plan, t: number): number
	local elapsed = math.max(t - plan.startAt - plan.lead, 0)
	local phase = (elapsed % (2 * plan.sweep)) / plan.sweep
	return if phase <= 1 then phase else 2 - phase
end

local forgeGui = Instance.new("ScreenGui")
forgeGui.Name = "ForgeStrikeGui"
forgeGui.ResetOnSpawn = false
forgeGui.IgnoreGuiInset = true
forgeGui.DisplayOrder = 23
forgeGui.Enabled = false
forgeGui.Parent = playerGui

-- A tap anywhere is a hammer blow; the button also keeps the meter's clicks off the panel.
local forgeTap = Instance.new("TextButton")
forgeTap.Name = "Tap"
forgeTap.Size = UDim2.fromScale(1, 1)
forgeTap.BackgroundColor3 = Color3.fromRGB(12, 8, 20)
-- Dark enough that the panel behind is plainly subordinate: the anvil is the brightest thing on
-- screen and nothing of the panel reads through the forge's own furniture.
forgeTap.BackgroundTransparency = 0.1
forgeTap.Text = ""
forgeTap.AutoButtonColor = false
forgeTap.ZIndex = 1
forgeTap.Visible = false
forgeTap.Parent = forgeGui

local forgeRoot = Instance.new("Frame")
forgeRoot.Name = "Forge"
forgeRoot.AnchorPoint = Vector2.new(0.5, 0.5)
forgeRoot.Position = UDim2.fromScale(0.5, 0.5)
forgeRoot.Size = UDim2.fromOffset(FORGE_W, FORGE_H)
forgeRoot.BackgroundTransparency = 1
forgeRoot.ZIndex = 2
forgeRoot.Visible = false
forgeRoot.Parent = forgeGui
local forgeScale = Instance.new("UIScale")
forgeScale.Parent = forgeRoot

-- No title banner: the anvil IS the title. The whole legend is one line under the meter, and it
-- is rewritten per strike with the real gold this blow already cost, so the price of missing is
-- readable before the marker has moved a pixel.
local forgeKey = PanelChrome.display(forgeRoot, {
	name = "Key", text = "", size = 30, stroke = 4.5, zIndex = 8, scaled = true, minSize = 13,
	color = Color3.fromRGB(255, 255, 255), pos = UDim2.fromOffset(60, 588), size2 = UDim2.new(1, -120, 0, 36),
})

-- The plate the whole blow happens on: iron on a white panel is invisible, so the forge gets
-- its own dark, ember-lit slab.
local plate = Instance.new("Frame")
plate.Name = "Plate"
plate.Position = UDim2.fromOffset(PLATE_X, PLATE_Y)
plate.Size = UDim2.fromOffset(PLATE_W, PLATE_H)
plate.BackgroundColor3 = Color3.fromRGB(34, 24, 36)
plate.BorderSizePixel = 0
plate.ZIndex = 4
plate.Parent = forgeRoot
corner(plate, 34)
PanelChrome.gradient(plate, Color3.fromRGB(84, 48, 40), Color3.fromRGB(26, 18, 34))
PanelChrome.stroke(plate, BRIGHT.Outline, 7)
local emberGlow = Instance.new("Frame")
emberGlow.Name = "Ember"
emberGlow.AnchorPoint = Vector2.new(0.5, 0.5)
emberGlow.Position = UDim2.fromOffset(SPARK_X - PLATE_X, SPARK_Y - PLATE_Y)
emberGlow.Size = UDim2.fromOffset(300, 300)
emberGlow.BackgroundColor3 = Color3.fromRGB(255, 142, 40)
emberGlow.BackgroundTransparency = 0.74
emberGlow.BorderSizePixel = 0
emberGlow.ZIndex = 4
emberGlow.Parent = plate
corner(emberGlow, 160)

-- The anvil, with a hammer that hangs raised over it until the blow.
local anvilView = Instance.new("ViewportFrame")
anvilView.Name = "Anvil"
anvilView.BackgroundTransparency = 1
anvilView.Position = UDim2.fromOffset(ANVIL_X, ANVIL_Y)
anvilView.Size = UDim2.fromOffset(ANVIL_W, ANVIL_H)
anvilView.ZIndex = 5
anvilView.Parent = forgeRoot

local hammerHead, hammerNeck, hammerHandle
local function setHammer(angle: number)
	if not hammerHead then return end
	-- The pivot is the smith's shoulder: the head travels a real arc down onto the blade.
	local pivot = CFrame.new(1.9, 1.9, 0.3) * CFrame.Angles(0, 0, angle)
	hammerHead.CFrame = pivot * CFrame.new(-2.5, 0, 0)
	hammerNeck.CFrame = pivot * CFrame.new(-2.0, 0, 0)
	hammerHandle.CFrame = pivot * CFrame.new(-1.15, 0, 0)
end

local function buildForgeAnvil()
	renderAnvil(anvilView)
	local world = anvilView:FindFirstChildOfClass("WorldModel")
	if not world then return end
	-- Big and pale, so it reads as a hammer at a glance and not as a stick.
	local iron, ironDark = Color3.fromRGB(196, 204, 230), Color3.fromRGB(96, 102, 132)
	hammerHead = part(world, "Part", "HammerHead", Vector3.new(1.55, 1.65, 1.55), CFrame.new(), iron, Enum.Material.Metal)
	hammerNeck = part(world, "Part", "HammerNeck", Vector3.new(0.5, 0.86, 0.86), CFrame.new(), ironDark, Enum.Material.Metal)
	hammerHandle = part(world, "Part", "HammerGrip", Vector3.new(2.6, 0.44, 0.44), CFrame.new(), Color3.fromRGB(198, 132, 62))
	setHammer(HAMMER_UP)
	local camera = anvilView.CurrentCamera or Instance.new("Camera")
	-- Tight: the anvil, the hot blade on it and the raised hammer fill the frame top to bottom.
	camera.FieldOfView = 28
	local target = Vector3.new(0.2, 1.25, 0)
	camera.CFrame = CFrame.lookAt(target + Vector3.new(0.5, 2.1, 9).Unit * 13.2, target)
	camera.Parent = anvilView
	anvilView.CurrentCamera = camera
end
buildForgeAnvil()
do
	-- A ViewportFrame renders nothing on the frame it first becomes visible, and that is exactly
	-- the frame the meter opens on. Show it once off the top of the screen so it is already warm.
	forgeGui.Enabled = true
	local rest = forgeRoot.Position
	forgeRoot.Position = UDim2.fromScale(0.5, -3)
	forgeRoot.Visible = true
	task.delay(1.5, function()
		forgeRoot.Visible = false
		forgeRoot.Position = rest
		forgeGui.Enabled = false
	end)
end

-- The meter: a deep recessed track whose BACKGROUND is the MISS band -- most of the bar is a
-- way to fail, and it is coloured and named as one. Inside it, a blue OK shoulder, an amber
-- GOOD shoulder and a tight bright-green PERFECT core, each stamped with its own multiplier.
local meter = Instance.new("Frame")
meter.Name = "Meter"
meter.Position = UDim2.fromOffset(METER_X, METER_Y)
meter.Size = UDim2.fromOffset(METER_W, METER_H)
meter.BackgroundColor3 = Color3.fromRGB(66, 32, 42)
meter.BorderSizePixel = 0
meter.ClipsDescendants = true
meter.ZIndex = 5
meter.Parent = forgeRoot
corner(meter, 28)
PanelChrome.gradient(meter, Color3.fromRGB(88, 40, 52), Color3.fromRGB(44, 20, 30))
PanelChrome.stroke(meter, BRIGHT.Outline, 7)

local METER_TRAVEL = METER_W - 2 * METER_PAD
local function zoneFrame(name, color, dark, z)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Position = UDim2.fromOffset(0, 6)
	f.Size = UDim2.fromOffset(10, METER_H - 12)
	f.ZIndex = z
	f.Parent = meter
	corner(f, 18)
	PanelChrome.gradient(f, color, dark)
	PanelChrome.stroke(f, BRIGHT.Outline, 4)
	return f
end
local okZone = zoneFrame("Ok", QUALITY.OK.color, QUALITY.OK.dark, 6)
local goodZone = zoneFrame("Good", QUALITY.GOOD.color, QUALITY.GOOD.dark, 7)
local perfectZone = zoneFrame("Perfect", QUALITY.PERFECT.color, QUALITY.PERFECT.dark, 8)
PanelChrome.stripes(perfectZone, { color = Color3.new(1, 1, 1), bands = 7, alpha = 0.8, rotation = 22, radius = 18, zIndex = 9 })
-- Only the multiplier goes inside a band: the names are on the legend line above, and a short
-- token cannot be swallowed by the marker the way the word PERFECT was.
local function bandMult(parent, name, text, size, z)
	return PanelChrome.display(parent, { name = name, text = text, size = size, stroke = 4, zIndex = z,
		scaled = true, minSize = 11, size2 = UDim2.new(1, -10, 0, 54), pos = UDim2.new(0, 5, 0.5, -27) })
end
bandMult(perfectZone, "Mult", "x2", 46, 10)
local goodLeft = PanelChrome.display(goodZone, { name = "MultL", text = "x1.5", size = 30, stroke = 3.5, zIndex = 8,
	scaled = true, minSize = 10, size2 = UDim2.fromOffset(90, 44), pos = UDim2.fromOffset(8, METER_H / 2 - 28), xAlign = Enum.TextXAlignment.Left })
local goodRight = PanelChrome.display(goodZone, { name = "MultR", text = "x1.5", size = 30, stroke = 3.5, zIndex = 8,
	scaled = true, minSize = 10, size2 = UDim2.fromOffset(90, 44), anchor = Vector2.new(1, 0),
	pos = UDim2.new(1, -8, 0, METER_H / 2 - 28), xAlign = Enum.TextXAlignment.Right })
local okLeft = PanelChrome.display(okZone, { name = "MultL", text = "x1.15", size = 28, stroke = 3.5, zIndex = 7,
	scaled = true, minSize = 10, size2 = UDim2.fromOffset(104, 44), pos = UDim2.fromOffset(10, METER_H / 2 - 28), xAlign = Enum.TextXAlignment.Left })
local okRight = PanelChrome.display(okZone, { name = "MultR", text = "x1.15", size = 28, stroke = 3.5, zIndex = 7,
	scaled = true, minSize = 10, size2 = UDim2.fromOffset(104, 44), anchor = Vector2.new(1, 0),
	pos = UDim2.new(1, -10, 0, METER_H / 2 - 28), xAlign = Enum.TextXAlignment.Right })
-- The two MISS tails: red, named, and between them they are 55% of the bar.
local function missLabel(name, xAlign)
	return PanelChrome.display(meter, { name = name, text = "MISS", size = 38, stroke = 4.5, zIndex = 6,
		scaled = true, minSize = 12, xAlign = xAlign, color = Color3.fromRGB(255, 186, 190),
		size2 = UDim2.fromOffset(120, 50), pos = UDim2.fromOffset(0, METER_H / 2 - 25) })
end
local missLeft = missLabel("MissL", Enum.TextXAlignment.Center)
local missRight = missLabel("MissR", Enum.TextXAlignment.Center)

local markerHolder = Instance.new("Frame")
markerHolder.Name = "Marker"
markerHolder.AnchorPoint = Vector2.new(0.5, 0.5)
markerHolder.Size = UDim2.fromOffset(MARKER_W, METER_H + 8)
markerHolder.Position = UDim2.fromOffset(METER_X + METER_PAD, METER_Y + METER_H / 2)
markerHolder.BackgroundColor3 = Color3.new(1, 1, 1)
markerHolder.BorderSizePixel = 0
markerHolder.ZIndex = 12
markerHolder.Parent = forgeRoot
corner(markerHolder, 12)
PanelChrome.gradient(markerHolder, Color3.new(1, 1, 1), Color3.fromRGB(214, 226, 250))
PanelChrome.stroke(markerHolder, BRIGHT.Outline, 6)
for _, y in ipairs({ 0, 1 }) do
	local cap = Instance.new("Frame")
	cap.Name = "Cap"
	cap.AnchorPoint = Vector2.new(0.5, 0.5)
	cap.Position = UDim2.fromScale(0.5, y)
	cap.Size = UDim2.fromOffset(42, 42)
	cap.Rotation = 45
	cap.BackgroundColor3 = BRIGHT.Gold
	cap.BorderSizePixel = 0
	cap.ZIndex = 13
	cap.Parent = markerHolder
	corner(cap, 8)
	PanelChrome.gradient(cap, Color3.fromRGB(255, 242, 150), BRIGHT.GoldDark)
	PanelChrome.stroke(cap, BRIGHT.Outline, 4)
end

local hintPill = Instance.new("Frame")
hintPill.Name = "Hint"
hintPill.AnchorPoint = Vector2.new(0.5, 0)
hintPill.Position = UDim2.fromOffset(FORGE_W / 2, 632)
hintPill.Size = UDim2.fromOffset(1060, 50)
hintPill.BackgroundColor3 = Color3.fromRGB(28, 26, 46)
hintPill.BorderSizePixel = 0
hintPill.ZIndex = 6
hintPill.Parent = forgeRoot
corner(hintPill, 23)
PanelChrome.stroke(hintPill, BRIGHT.Outline, 5)
local hintLabel = PanelChrome.display(hintPill, { name = "Text", text = "TAP  ·  SPACE  ·  CLICK", size = 34, stroke = 4, zIndex = 7,
	scaled = true, minSize = 13, size2 = UDim2.new(1, -28, 1, 0), pos = UDim2.fromOffset(14, 0) })

-- The white frame: on contact the plate blows out for a single frame, then stays washed while
-- the hitstop holds. It is the loudest thing in the strip and it lasts a tenth of a second.
local whiteOut = Instance.new("Frame")
whiteOut.Name = "Whiteout"
whiteOut.Position = UDim2.fromOffset(PLATE_X, PLATE_Y)
whiteOut.Size = UDim2.fromOffset(PLATE_W, PLATE_H)
whiteOut.BackgroundColor3 = Color3.fromRGB(255, 252, 240)
whiteOut.BorderSizePixel = 0
whiteOut.ZIndex = 16
whiteOut.Visible = false
whiteOut.Parent = forgeRoot
corner(whiteOut, 34)

-- Impact lines out of the contact point: eight spokes that snap out and vanish in a quarter
-- second, so the blow reads as a blow even in a still frame.
local impactLines = {}
for i = 1, 8 do
	local line = Instance.new("Frame")
	line.Name = "Impact"
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.Position = UDim2.fromOffset(SPARK_X, SPARK_Y)
	line.Size = UDim2.fromOffset(40, 12)
	line.Rotation = (i - 1) * 45 + 22
	line.BackgroundColor3 = Color3.fromRGB(255, 250, 226)
	line.BorderSizePixel = 0
	line.ZIndex = 18
	line.Visible = false
	line.Parent = forgeRoot
	corner(line, 6)
	table.insert(impactLines, line)
end

-- ...and the server's verdict once it has landed, in the same place.
local stampHolder = Instance.new("Frame")
stampHolder.Name = "Stamp"
stampHolder.AnchorPoint = Vector2.new(0.5, 0.5)
stampHolder.Position = UDim2.fromOffset(FORGE_W / 2, 100)
stampHolder.Size = UDim2.fromOffset(1320, 196)
stampHolder.BackgroundTransparency = 1
stampHolder.ZIndex = 20
stampHolder.Visible = false
stampHolder.Parent = forgeRoot
local stampScale = Instance.new("UIScale")
stampScale.Parent = stampHolder
local stampWord = PanelChrome.display(stampHolder, { name = "Word", text = "PERFECT!", size = 124, stroke = 12, zIndex = 21,
	scaled = true, minSize = 40, size2 = UDim2.new(1, 0, 1, 0), pos = UDim2.fromOffset(0, 0) })

local flash = Instance.new("Frame")
flash.Name = "Flash"
flash.AnchorPoint = Vector2.new(0.5, 0.5)
flash.Position = UDim2.fromOffset(SPARK_X, SPARK_Y)
flash.Size = UDim2.fromOffset(40, 40)
flash.BackgroundColor3 = Color3.fromRGB(255, 250, 220)
flash.BorderSizePixel = 0
flash.ZIndex = 18
flash.Visible = false
flash.Parent = forgeRoot
corner(flash, 200)

local shock = Instance.new("Frame")
shock.Name = "Shockwave"
shock.AnchorPoint = Vector2.new(0.5, 0.5)
shock.Position = UDim2.fromOffset(SPARK_X, SPARK_Y)
shock.Size = UDim2.fromOffset(60, 60)
shock.BackgroundTransparency = 1
shock.ZIndex = 17
shock.Visible = false
shock.Parent = forgeRoot
corner(shock, 400)
local shockRing = PanelChrome.stroke(shock, Color3.fromRGB(255, 212, 120), 10)

local sparkFolder = Instance.new("Folder")
sparkFolder.Name = "Sparks"
sparkFolder.Parent = forgeRoot

-- The result strip: it outlives the meter and stays up through the whole reveal, so the roll is
-- always labelled with the blow that bought its luck.
local strikeBanner = Instance.new("Frame")
strikeBanner.Name = "StrikeBanner"
strikeBanner.AnchorPoint = Vector2.new(0.5, 0)
strikeBanner.Position = UDim2.new(0.5, 0, 0, 14)
strikeBanner.Size = UDim2.new(0.9, 0, 0, 104)
strikeBanner.BackgroundColor3 = Color3.fromRGB(26, 24, 44)
strikeBanner.BorderSizePixel = 0
strikeBanner.ZIndex = 26
strikeBanner.Visible = false
strikeBanner.Parent = forgeGui
corner(strikeBanner, 26)
PanelChrome.stroke(strikeBanner, BRIGHT.Outline, 6)
local bannerAccent = Instance.new("Frame")
bannerAccent.Name = "Accent"
bannerAccent.Size = UDim2.new(1, 0, 0, 12)
bannerAccent.Position = UDim2.new(0, 0, 1, -12)
bannerAccent.BackgroundColor3 = QUALITY.PERFECT.color
bannerAccent.BorderSizePixel = 0
bannerAccent.ZIndex = 27
bannerAccent.Parent = strikeBanner
local bannerWord = PanelChrome.display(strikeBanner, { name = "Word", text = "", size = 46, stroke = 5, zIndex = 28,
	xAlign = Enum.TextXAlignment.Left, size2 = UDim2.new(0.5, -40, 1, -14), pos = UDim2.fromOffset(30, 0) })
-- A frozen copy of the meter, with the marker where the blow actually landed.
local miniMeter = Instance.new("Frame")
miniMeter.Name = "Mini"
miniMeter.AnchorPoint = Vector2.new(1, 0.5)
miniMeter.Position = UDim2.new(1, -30, 0.5, -6)
miniMeter.Size = UDim2.fromOffset(460, 48)
miniMeter.BackgroundColor3 = Color3.fromRGB(72, 34, 44)
miniMeter.BorderSizePixel = 0
miniMeter.ClipsDescendants = true
miniMeter.ZIndex = 28
miniMeter.Parent = strikeBanner
corner(miniMeter, 14)
PanelChrome.stroke(miniMeter, BRIGHT.Outline, 4)
local miniGood = Instance.new("Frame")
miniGood.BackgroundColor3 = QUALITY.GOOD.color
miniGood.BorderSizePixel = 0
miniGood.Size = UDim2.fromOffset(10, 36)
miniGood.Position = UDim2.fromOffset(0, 6)
miniGood.ZIndex = 29
miniGood.Parent = miniMeter
corner(miniGood, 10)
local miniOk = miniGood:Clone()
miniOk.BackgroundColor3 = QUALITY.OK.color
miniOk.ZIndex = 29
miniOk.Parent = miniMeter
miniGood.ZIndex = 30
local miniPerfect = miniGood:Clone()
miniPerfect.BackgroundColor3 = QUALITY.PERFECT.color
miniPerfect.ZIndex = 31
miniPerfect.Parent = miniMeter
local miniMarker = Instance.new("Frame")
miniMarker.AnchorPoint = Vector2.new(0.5, 0.5)
miniMarker.Size = UDim2.fromOffset(12, 60)
miniMarker.BackgroundColor3 = Color3.new(1, 1, 1)
miniMarker.BorderSizePixel = 0
miniMarker.ZIndex = 32
miniMarker.Parent = miniMeter
corner(miniMarker, 5)
PanelChrome.stroke(miniMarker, BRIGHT.Outline, 3)

-- The run rail owns the top of the screen for the whole forge, so the anvil, the meter and the
-- stamp are fitted into what it leaves and centred in THAT, not in the window. Nothing the blow
-- draws can end up underneath the rail.
local RAIL_BAND = 0.15
local FORGE_REST = RAIL_BAND + (1 - RAIL_BAND) / 2
PanelChrome.onViewport(function(viewport)
	forgeScale.Scale = math.clamp(math.min(viewport.X / (FORGE_W + 40),
		viewport.Y * (1 - RAIL_BAND) / (FORGE_H + 20)), 0.3, 1.2)
	forgeRoot.Position = UDim2.fromScale(0.5, FORGE_REST)
end)

-- ── Meter state ─────────────────────────────────────────────────────────────
local forgePlan = nil
local forgeStruck = false
local struckInfo = nil
local forgeConn = nil
local shakeMag, shakeUntil = 0, 0
local showcaseStrikeQuality = nil -- Studio capture only, see GuiShowcase.motion below
-- Studio capture only: how many seconds into the meter the scripted blow aims for. The strike and
-- rare captures let the marker travel for a few sweeps first so the meter reads on screen; the
-- loop capture ("Motion:ForgeLoop") asks for the first crossing instead, which is what a player
-- who is not waiting about does. It only moves WHEN the press happens, never how it is scored.
local showcaseStrikeAim = nil
-- Studio capture only: the shared-clock instant the scripted blow above is scheduled for.
-- The rare-moment capture reads it so the clapperboard can finish exactly as the hammer falls.
local showcasePressAt = nil

local function layoutZones(plan)
	local okHalf = plan.okHalf or 0.225
	local function place(f, half)
		local w = math.max(math.floor(2 * half * METER_TRAVEL), 20)
		f.Size = UDim2.fromOffset(w, METER_H - 12)
		f.Position = UDim2.fromOffset(math.floor(METER_PAD + (plan.sweetCenter - half) * METER_TRAVEL), 6)
	end
	place(okZone, okHalf)
	place(goodZone, plan.goodHalf)
	place(perfectZone, plan.sweetHalf)
	goodLeft.Visible = plan.goodHalf - plan.sweetHalf > 0.03
	goodRight.Visible = goodLeft.Visible
	okLeft.Visible = okHalf - plan.goodHalf > 0.04
	okRight.Visible = okLeft.Visible
	-- The MISS tails: whatever the OK band leaves at either end of the track.
	local leftEnd = math.floor(METER_PAD + (plan.sweetCenter - okHalf) * METER_TRAVEL)
	local rightStart = math.floor(METER_PAD + (plan.sweetCenter + okHalf) * METER_TRAVEL)
	local leftW, rightW = leftEnd - 8, METER_W - rightStart - 8
	missLeft.Size = UDim2.fromOffset(math.max(leftW, 40), 50)
	missLeft.Position = UDim2.fromOffset(4, METER_H / 2 - 25)
	missRight.Size = UDim2.fromOffset(math.max(rightW, 40), 50)
	missRight.Position = UDim2.fromOffset(rightStart + 4, METER_H / 2 - 25)
	missLeft.Visible = leftW > 46
	missRight.Visible = rightW > 46
end

local function setMarker(pos: number)
	markerHolder.Position = UDim2.fromOffset(
		math.floor(METER_X + METER_PAD + math.clamp(pos, 0, 1) * METER_TRAVEL),
		METER_Y + METER_H / 2)
end

local function fillMini(plan, pos)
	local travel = miniMeter.Size.X.Offset - 8
	local function place(f, half)
		f.Size = UDim2.fromOffset(math.max(math.floor(2 * half * travel), 8), 36)
		f.Position = UDim2.fromOffset(math.floor(4 + (plan.sweetCenter - half) * travel), 6)
	end
	place(miniOk, plan.okHalf or 0.225)
	place(miniGood, plan.goodHalf)
	place(miniPerfect, plan.sweetHalf)
	miniMarker.Position = UDim2.fromOffset(math.floor(4 + math.clamp(pos, 0, 1) * travel), 24)
end

-- Screen shake: the whole forge layer and the world behind it kick, scaled to the blow --
-- 4 px at its hardest and gone inside a fifth of a second, a punch rather than an earthquake.
local SHAKE_TIME = 0.2 -- [TUNING] seconds
RunService:BindToRenderStep("ForgeStrikeShake", Enum.RenderPriority.Camera.Value + 2, function()
	if shakeMag <= 0 then return end
	local left = shakeUntil - os.clock()
	if left <= 0 then
		shakeMag = 0
		forgeRoot.Position = UDim2.fromScale(0.5, FORGE_REST)
		forgeRoot.Rotation = 0
		return
	end
	local a = shakeMag * (left / SHAKE_TIME) ^ 1.6
	forgeRoot.Position = UDim2.new(0.5, math.random(-100, 100) / 100 * a, FORGE_REST, math.random(-100, 100) / 100 * a)
	forgeRoot.Rotation = math.random(-100, 100) / 100 * a * 0.05
	local camera = workspace.CurrentCamera
	if camera then
		local k = a / 46
		camera.CFrame = camera.CFrame * CFrame.new(math.random(-100, 100) / 100 * k, math.random(-100, 100) / 100 * k, 0)
	end
end)

local function burstSparks(count: number, tint: Color3, slow: boolean?)
	-- A hard burst on the blow, then a slower trickle of embers off the face, so the anvil is
	-- still alight a second and a half later instead of snapping back to rest.
	for i = 1, count do
		local s = Instance.new("Frame")
		s.Name = "Spark"
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.fromOffset(SPARK_X, SPARK_Y)
		local size = math.random(16, 40)
		s.Size = UDim2.fromOffset(size, size)
		s.Rotation = math.random(0, 90)
		-- Hot metal throws gold and white; the blow's colour is only flecked through it, so a
		-- PERFECT does not turn the anvil into a green firework.
		s.BackgroundColor3 = if i % 4 == 0 then tint
			elseif i % 2 == 0 then Color3.fromRGB(255, 252, 226) else Color3.fromRGB(255, 196, 68)
		s.BorderSizePixel = 0
		s.ZIndex = 19
		s.Parent = sparkFolder
		corner(s, math.floor(size / 3))
		local angle = math.rad(math.random(-172, -8))
		local reach = math.random(150, 380)
		local dx, dy = math.cos(angle) * reach, math.sin(angle) * reach
		local time = slow and math.random(90, 150) / 100 or math.random(45, 80) / 100
		TweenService:Create(s, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(SPARK_X + dx, SPARK_Y + dy + reach * 0.55),
			BackgroundTransparency = 1, Rotation = s.Rotation + math.random(-260, 260), Size = UDim2.fromOffset(6, 6),
		}):Play()
		task.delay(time + 0.05, function() s:Destroy() end)
	end
end

local function emberTrickle(count: number, tint: Color3)
	task.spawn(function()
		for _ = 1, count do
			task.wait(math.random(7, 16) / 100)
			burstSparks(2, tint, true)
		end
	end)
end

local function closeForge()
	forgePlan = nil
	if forgeConn then forgeConn:Disconnect() forgeConn = nil end
	forgeTap.Visible = false
	forgeRoot.Visible = false
	forgeGui.Enabled = strikeBanner.Visible
	forgeState.active = false
end

local function hideStrikeBanner()
	strikeBanner.Visible = false
	if not forgeRoot.Visible then forgeGui.Enabled = false end
end

-- The blow landed. The server's reply says what it was worth; everything here is the payoff.
--
-- Contact, then HITSTOP: the whole scene stops dead -- the marker frozen exactly where it
-- stopped, the hammer buried in the blade, one white frame and then a washed-out hold. Only
-- when the hitstop lets go do the sparks, the impact lines, the shake and the stamp all fire at
-- once, which is what makes a hit feel like a hit rather than a gradient fading in.
local HITSTOP = 0.1 -- [TUNING] seconds; 80-120 ms is the window a hit reads as a hit
local function land(info)
	local q = QUALITY[info.quality] or QUALITY.MISS
	setHammer(HAMMER_DOWN)
	-- The clang rings brighter and louder the closer the marker stopped to the sweet centre; a
	-- MISS out at the tail is a dull, flat, heavy thud.
	local span = math.max(info.okHalf or 0.225, 0.05)
	local acc = 1 - math.clamp(math.abs((info.pos or 0) - (info.sweetCenter or 0)) / span, 0, 1)
	AudioManager.PlaySFX("forge_clang", forgeGui, { PlaybackSpeed = 0.38 + 0.44 * acc, Volume = 0.5 + 0.5 * acc })

	-- One frame of pure white, then the hitstop holds the scene washed out and motionless.
	whiteOut.BackgroundTransparency = 0
	whiteOut.Visible = true
	forgeKey.Visible = false
	anvilView.Position = UDim2.fromOffset(ANVIL_X - 10, ANVIL_Y + 12)
	anvilView.Size = UDim2.fromOffset(ANVIL_W + 20, ANVIL_H - 12)
	RunService.RenderStepped:Wait()
	whiteOut.BackgroundTransparency = 0.42
	task.wait(HITSTOP)
	whiteOut.Visible = false

	-- Hitstop over: everything at once.
	burstSparks(q.sparks, q.color)
	emberTrickle(math.floor(q.sparks / 2), q.color)
	for _, line in ipairs(impactLines) do
		line.Size = UDim2.fromOffset(44, 16)
		line.BackgroundTransparency = 0.05
		line.BackgroundColor3 = q.color:Lerp(Color3.new(1, 1, 1), 0.6)
		line.Visible = true
		TweenService:Create(line, TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(120 + q.sparks * 5, 3), BackgroundTransparency = 1 }):Play()
	end
	task.delay(0.38, function()
		for _, line in ipairs(impactLines) do line.Visible = false end
	end)
	TweenService:Create(anvilView, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(ANVIL_X, ANVIL_Y), Size = UDim2.fromOffset(ANVIL_W, ANVIL_H) }):Play()
	shock.Visible = true
	shock.Size = UDim2.fromOffset(60, 60)
	shockRing.Thickness = 12
	shockRing.Transparency = 0
	shockRing.Color = q.color
	TweenService:Create(shock, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(60 + q.sparks * 9, 60 + q.sparks * 9) }):Play()
	TweenService:Create(shockRing, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = 1, Thickness = 2 }):Play()
	task.delay(0.85, function() shock.Visible = false end)
	-- The struck face stays white-hot for a beat.
	emberGlow.BackgroundTransparency = 0.2
	emberGlow.Size = UDim2.fromOffset(400, 400)
	TweenService:Create(emberGlow, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.74, Size = UDim2.fromOffset(300, 300) }):Play()
	shakeMag = q.shake
	shakeUntil = os.clock() + SHAKE_TIME
	flash.Visible = true
	flash.Size = UDim2.fromOffset(60, 60)
	flash.BackgroundTransparency = 0.05
	TweenService:Create(flash, TweenInfo.new(0.44, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(420, 420), BackgroundTransparency = 1 }):Play()
	task.delay(0.46, function() flash.Visible = false end)

	stampWord.Text = q.word
	stampWord.TextColor3 = q.color
	stampHolder.Visible = true
	stampScale.Scale = 0.35
	TweenService:Create(stampScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- What the blow bought takes over the line under the meter, where the input prompt was: one
	-- place, one line, never stacked on anything. A MISS says what it cost in figures -- the roll
	-- still happens, at the base luck the player earned in play and never below it, but the blow
	-- bought nothing and the gold is already gone.
	if info.quality == "MISS" then
		hintLabel.Text = string.format("%s  ·  NO LUCK BONUS  ·  %s  ·  ROLLING AT BASE %.2fx",
			info.timedOut and "THE HEAT FADED" or "GLANCED OFF",
			(info.free or (info.cost or 0) <= 0) and "FREE STRIKE BURNT" or (SwordValue.short(info.cost or 0) .. " GOLD SPENT"),
			info.baseLuck or 1)
	else
		hintLabel.Text = string.format("STRUCK!  ·  LUCK x%.2f ON THIS ROLL  ·  %.2fx -> %.2fx",
			info.mult or 1, info.baseLuck or 1, info.luck or 1)
	end
	hintLabel.TextColor3 = q.color

	-- The result strip is prepared here but only shown once the forge hands over, so it can
	-- never sit on top of the stamp while the blow is still being paid off.
	bannerWord.Text = string.format("%s STRIKE   LUCK x%.2f", info.quality, info.mult or 1)
	bannerWord.TextColor3 = q.color
	bannerAccent.BackgroundColor3 = q.color
	fillMini({ sweetCenter = info.sweetCenter, sweetHalf = info.sweetHalf, goodHalf = info.goodHalf,
		okHalf = info.okHalf }, info.pos or 0.5)
	-- Let the hammer rebound a little, so it does not look stuck on the anvil.
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.4 do
			local k = (os.clock() - t0) / 0.4
			setHammer(HAMMER_DOWN + (HAMMER_UP - HAMMER_DOWN) * 0.38 * math.sin(k * math.pi))
			RunService.RenderStepped:Wait()
		end
		setHammer(HAMMER_DOWN)
	end)
end

-- How long the blow owns the screen after the hitstop before the reveal takes over. Past about
-- half a second it is only dead air between the hammer and the card, and dead air is what a
-- forge loop cannot afford. [TUNING]
local STRIKE_HOLD = 0.66 -- [TUNING] seconds
local forgeDone = nil -- set by the wiring below: hands the roll the server already made to the reveal

-- The swing: 50 ms of anticipation pulling the hammer further back, then 100 ms of accelerating
-- fall through the arc onto the blade. The press has already been timestamped and sent, so the
-- arc costs the player nothing -- it is the blow being drawn, not the blow being timed.
local SWING_BACK, SWING_FALL = 0.05, 0.1
local function swingAndLand(plan, pos: number)
	task.spawn(function()
		-- The swing is local so it answers the press instantly; the word waits for the server.
		local back = HAMMER_UP - 0.3
		local t0 = os.clock()
		while os.clock() - t0 < SWING_BACK do
			setHammer(HAMMER_UP + (back - HAMMER_UP) * ((os.clock() - t0) / SWING_BACK))
			RunService.RenderStepped:Wait()
		end
		t0 = os.clock()
		while os.clock() - t0 < SWING_FALL do
			local k = (os.clock() - t0) / SWING_FALL
			setHammer(back + (HAMMER_DOWN - back) * k * k)
			RunService.RenderStepped:Wait()
		end
		local deadline = os.clock() + 1.2
		while not struckInfo and os.clock() < deadline do task.wait() end
		land(struckInfo or { quality = "MISS", mult = 1, pos = pos, sweetCenter = plan.sweetCenter,
			sweetHalf = plan.sweetHalf, goodHalf = plan.goodHalf, okHalf = plan.okHalf,
			cost = plan.cost, free = plan.free, baseLuck = 1, luck = 1 })
		task.wait(STRIKE_HOLD)
		strikeBanner.Visible = true
		closeForge()
		if forgeDone then forgeDone() end
	end)
end

-- One press: freeze the marker, report the instant to the server, swing.
local function pressStrike()
	if not forgePlan or forgeStruck then return end
	forgeStruck = true
	local plan = forgePlan
	local t = workspace:GetServerTimeNow()
	local pos = markerAt(plan, t)
	setMarker(pos)
	if forgeConn then forgeConn:Disconnect() forgeConn = nil end
	REFORGE:FireServer("Strike", plan.seq, t)
	swingAndLand(plan, pos)
end

-- The meter ran out with nobody swinging: the server rolled it at base luck anyway, so drop the
-- hammer on screen too rather than leave a live meter hanging.
local function forgeResolvedWithoutPress(info)
	if not forgePlan or forgeStruck then return end
	forgeStruck = true
	local plan = forgePlan
	if forgeConn then forgeConn:Disconnect() forgeConn = nil end
	setMarker(info.pos or 0)
	swingAndLand(plan, info.pos or 0)
end

-- The server lit a meter: draw it from its plan and start reading the shared clock.
local function openForge(plan)
	forgePlan = plan
	forgeStruck = false
	struckInfo = nil
	forgeState.active = true
	stampHolder.Visible = false
	forgeKey.Visible = true
	-- The whole bargain on one line, with the gold this blow already cost spelled out, so the
	-- price of missing is readable before the marker has moved a pixel.
	local mult = plan.mult or { PERFECT = 2, GOOD = 1.5, OK = 1.15, MISS = 1 }
	forgeKey.Text = string.format("PERFECT x%.0f  ·  GOOD x%.1f  ·  OK x%.2f  ·  MISS  NO BONUS, %s SPENT",
		mult.PERFECT or 2, mult.GOOD or 1.5, mult.OK or 1.15,
		(plan.free or (plan.cost or 0) <= 0) and "FREE STRIKE" or (SwordValue.short(plan.cost or 0) .. " GOLD"))
	strikeBanner.Visible = false
	whiteOut.Visible = false
	for _, line in ipairs(impactLines) do line.Visible = false end
	anvilView.Position = UDim2.fromOffset(ANVIL_X, ANVIL_Y)
	anvilView.Size = UDim2.fromOffset(ANVIL_W, ANVIL_H)
	hintLabel.Text = "TAP  ·  SPACE  ·  CLICK  --  STOP THE MARKER IN THE GREEN"
	hintLabel.TextColor3 = Color3.new(1, 1, 1)
	setHammer(HAMMER_UP)
	shock.Visible = false
	emberGlow.BackgroundTransparency = 0.74
	emberGlow.Size = UDim2.fromOffset(300, 300)
	layoutZones(plan)
	setMarker(0)
	forgeGui.Enabled = true
	forgeTap.Visible = true
	forgeRoot.Visible = true
	forgeRoot.Position = UDim2.fromScale(0.5, FORGE_REST)
	forgeRoot.Rotation = 0
	local lastInSweet = false
	if forgeConn then forgeConn:Disconnect() end
	forgeConn = RunService.RenderStepped:Connect(function()
		if not forgePlan then return end
		local now = workspace:GetServerTimeNow()
		local pos = markerAt(forgePlan, now)
		setMarker(pos)
		-- The hammer hangs raised and breathes with the sweep, so the wait has motion in it.
		setHammer(HAMMER_UP + math.sin(now * 5.2) * 0.07)
		local inSweet = math.abs(pos - forgePlan.sweetCenter) <= forgePlan.sweetHalf
		if inSweet ~= lastInSweet then
			lastInSweet = inSweet
			if inSweet then AudioManager.PlaySFX("forge_tick", forgeGui) end
		end
	end)
	if showcaseStrikeQuality then
		local quality = showcaseStrikeQuality
		local aimSecs = showcaseStrikeAim or 3.05
		showcaseStrikeQuality, showcaseStrikeAim = nil, nil
		task.spawn(function()
			-- Studio capture only: press through the very same pressStrike() a finger does, at the
			-- moment the marker reaches the chosen band. The server still validates the timestamp.
			local okHalf = plan.okHalf or 0.225
			local offset = 0
			if quality == "GOOD" then offset = (plan.sweetHalf + plan.goodHalf) / 2
			elseif quality == "OK" then offset = (plan.goodHalf + okHalf) / 2
			elseif quality == "MISS" then offset = math.min(okHalf + 0.09, 0.47) end
			local x = math.clamp(plan.sweetCenter + offset, 0.02, 0.98)
			local base = plan.startAt + plan.lead
			local period = 2 * plan.sweep
			-- Let the meter run for a few sweeps first so the capture shows the marker travelling,
			-- then take the crossing nearest this mark: the blow lands at about the same beat
			-- however the server placed the sweet zone.
			local aim, notBefore = base + aimSecs, base + math.max(aimSecs - 1.05, 0.02)
			local best = math.huge
			for _, off in ipairs({ x * plan.sweep, (2 - x) * plan.sweep }) do
				for k = 0, 8 do
					local t = base + off + k * period
					if t >= notBefore and math.abs(t - aim) < math.abs(best - aim) then best = t end
				end
			end
			showcasePressAt = best
			while workspace:GetServerTimeNow() < best - 0.004 do RunService.Heartbeat:Wait() end
			pressStrike()
		end)
	end
end

forgeTap.Activated:Connect(pressStrike)
UserInputService.InputBegan:Connect(function(input)
	if not forgeState.active or forgeStruck then return end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return
		or input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		pressStrike()
	end
end)

return {
	HOLD = STRIKE_HOLD,
	-- The blow's colour and word, so the run rail can stamp the same PERFECT/GOOD/OK the anvil does.
	qualityInfo = function(word) return QUALITY[word] or QUALITY.OK end,
	open = openForge,
	close = closeForge,
	hideBanner = hideStrikeBanner,
	resolvedWithoutPress = forgeResolvedWithoutPress,
	setStruck = function(info) struckInfo = info end,
	info = function() return struckInfo end,
	isStruck = function() return forgeStruck end,
	plan = function() return forgePlan end,
	setShowcaseQuality = function(q, aimSecs) showcaseStrikeQuality, showcaseStrikeAim = q, aimSecs end,
	pressAt = function() return showcasePressAt end,
	setDone = function(fn) forgeDone = fn end,
}
end)()

-- ── The mystery-sword reveal (imperative, like the forge strike) ─────────────
-- What the anvil made is never shown on a reel. A silhouetted sword stands centre stage and
-- its glow runs up the rarity ladder -- a blur at first, then a tick per rung, slowing, and
-- hanging one whole beat on the rung ABOVE the truth -- until it LANDS on the rung the server
-- actually rolled, with a burst scaled to that rung. Only then does the silhouette resolve
-- into the real sword, and its name, rung, true 1-in-N and modifiers lock in one at a time,
-- the last one slowest.
--
-- The landing colour is the only honest one. The server rolled before any of this started and
-- sent the whole result; the client simply holds it back for the length of the theatre. The
-- flashes before the landing decide nothing and are seeded by nothing.
local Reveal = (function()
local W, H = 1640, 920
local CARD_W, CARD_H, CARD_TOP = 404, 480, 124
local CARD_CX, CARD_CY = W / 2, CARD_TOP + CARD_H / 2
local RAIL_X, PIP, PIP_GAP = W / 2 + CARD_W / 2 + 58, 38, 8
local RAIL_TOP = CARD_TOP + 2
local BAND_Y, BAND_H, BAND_W = 616, 96, 1140
local MODS_Y, MOD_H = 726, 100
local FOOT_Y = 838
local BLOW_X, BLOW_Y, BLOW_W = 44, 168, 440
-- The theatre is scaled to the rung that landed, the way a crate opening is: a Fresh or a Sunny
-- gets a short climb and a quick lock-in, the long tail gets the whole performance. That is what
-- keeps a forge LOOP moving -- the common rolls, which is nearly all of them, are over fast --
-- while a Supernova still stops the room. [TUNING] all of it.
local TICKS = 13                  -- [TUNING] rungs flashed before the near miss, at the top of the ladder
local TICKS_MID = 10              -- [TUNING] rungs 4-6
local TICKS_LOW = 7               -- [TUNING] rungs 1-3 (about 0.92 s of climb)
local NEAR_HOLD = 0.45            -- [TUNING] the extra beat held on the rung above the truth
local NEAR_HOLD_LOW = 0.20        -- [TUNING] the same beat when the near miss was a low rung
local LAND_HOLD = 0.38            -- [TUNING] the landed colour alone, before the sword resolves
local MOD_RUN = 0.95              -- [TUNING] however many modifiers landed, they all lock in inside this
local MOD_RUN_LOW = 0.58          -- [TUNING] ...and faster below the long tail
local LAST_STEP = 0.30            -- [TUNING] the wait before the best modifier, always the longest
local LAST_STEP_LOW = 0.24        -- [TUNING]
local BIG_TIER = 7                -- [TUNING] the rung the full performance starts at (the long tail)
local SETTLE_HOLD = 1.8           -- [TUNING] the settled result before the panel comes back on its own
local RUNGS = WeaponModifiers.TIER_COUNT
local SWORD_POSE = { yawDeg = 16, tiltDeg = 62, margin = 1.02 }
local DARK = Color3.fromRGB(12, 7, 26)

-- The tick before the i-th rung. The ladder blurs past at a flat clip and only lengthens for
-- the last few beats, so the eye can feel it slowing into the result rather than a metronome
-- that simply stops. [TUNING] the last five gaps before the near miss/landing.
local TAIL_GAPS = { 0.066, 0.066, 0.090, 0.140, 0.220 }
local function tickGap(i: number, n: number): number
	local fromEnd = n - i -- 0 on the last tick before the near miss/landing
	local tailLen = #TAIL_GAPS
	if fromEnd < tailLen then
		return TAIL_GAPS[tailLen - fromEnd]
	end
	return TAIL_GAPS[1]
end

local gui = Instance.new("ScreenGui")
gui.Name = "ForgeRevealGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 26
gui.Enabled = false
gui.Parent = playerGui

-- A tap anywhere dismisses the settled result; until then it just keeps clicks off the panel.
local scrim = Instance.new("TextButton")
scrim.Name = "Scrim"
scrim.Size = UDim2.fromScale(1, 1)
scrim.BackgroundColor3 = DARK
scrim.BackgroundTransparency = 0.12
scrim.Text = ""
scrim.AutoButtonColor = false
scrim.ZIndex = 1
scrim.Parent = gui

local root = Instance.new("Frame")
root.Name = "Reveal"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromOffset(W, H)
root.BackgroundTransparency = 1
root.ZIndex = 2
root.Parent = gui
local revScale = Instance.new("UIScale")
revScale.Parent = root
-- The forge run rail owns the top of the screen for the whole loop, so the reveal is laid out
-- in what is left under it rather than sliding its headline -- the sword's name -- behind it.
local TOP_INSET = 182
PanelChrome.onViewport(function(vp)
	local avail = math.max(vp.Y - TOP_INSET, 240)
	revScale.Scale = math.clamp(math.min(vp.X / (W + 40), avail / (H + 30)), 0.3, 1.35)
	root.Position = UDim2.new(0.5, 0, 0, TOP_INSET + avail / 2)
end)

-- Rays and three soft discs behind the card: the rung's colour spilling off it.
local rayHolder = Instance.new("Frame")
rayHolder.Name = "Rays"
rayHolder.AnchorPoint = Vector2.new(0.5, 0.5)
rayHolder.Position = UDim2.fromOffset(CARD_CX, CARD_CY)
rayHolder.Size = UDim2.fromOffset(1500, 1500)
rayHolder.BackgroundTransparency = 1
rayHolder.ZIndex = 2
rayHolder.Parent = root
local rayBars = {}
for i = 1, 14 do
	local ray = Instance.new("Frame")
	ray.Name = "Ray"
	ray.AnchorPoint = Vector2.new(0.5, 0.5)
	ray.Position = UDim2.fromScale(0.5, 0.5)
	ray.Size = UDim2.fromOffset(26, 1500)
	ray.Rotation = (i - 1) * (180 / 14)
	ray.BackgroundColor3 = WHITE
	ray.BackgroundTransparency = 0.86
	ray.BorderSizePixel = 0
	ray.ZIndex = 2
	ray.Parent = rayHolder
	rayBars[i] = ray
end
local glows = {}
for i, spec in ipairs({ { 540, 0.42 }, { 700, 0.64 }, { 880, 0.82 } }) do
	local g = Instance.new("Frame")
	g.Name = "Glow" .. i
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromOffset(CARD_CX, CARD_CY)
	g.Size = UDim2.fromOffset(spec[1], spec[1])
	g.BackgroundColor3 = WHITE
	g.BackgroundTransparency = spec[2]
	g.BorderSizePixel = 0
	g.ZIndex = 3
	g.Parent = root
	corner(g, math.floor(spec[1] / 2))
	glows[i] = { frame = g, rest = spec[2], size = spec[1] }
end

local headline = PanelChrome.display(root, {
	name = "Headline", text = "", size = 76, stroke = 8, zIndex = 12, color = WHITE,
	pos = UDim2.fromOffset(0, 8), size2 = UDim2.new(1, 0, 0, 76), scaled = true, minSize = 28,
})
local subline = PanelChrome.display(root, {
	name = "Subline", text = "", size = 32, stroke = 4.5, zIndex = 12, color = Color3.fromRGB(255, 236, 170),
	pos = UDim2.fromOffset(0, 84), size2 = UDim2.new(1, 0, 0, 34), scaled = true, minSize = 16,
})

-- The mystery card: the sword's own shape in black on the rung's colour.
local card = Instance.new("Frame")
card.Name = "MysteryCard"
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.fromOffset(CARD_CX, CARD_TOP)
card.Size = UDim2.fromOffset(CARD_W, CARD_H)
card.BackgroundColor3 = WHITE
card.BorderSizePixel = 0
card.ZIndex = 6
card.Parent = root
corner(card, 34)
local cardGrad = PanelChrome.gradient(card, WHITE, WHITE)
local cardStroke = PanelChrome.stroke(card, BRIGHT.Outline, 7)
local cardScale = Instance.new("UIScale")
cardScale.Parent = card
local qmark = PanelChrome.display(card, {
	name = "Question", text = "?", size = 330, stroke = 10, zIndex = 7, color = WHITE,
	pos = UDim2.fromOffset(0, 40), size2 = UDim2.new(1, 0, 1, -80),
})
qmark.TextTransparency = 0.52
local qmarkStroke = qmark:FindFirstChildOfClass("UIStroke")
local silView = Instance.new("ViewportFrame")
silView.Name = "Silhouette"
silView.BackgroundTransparency = 1
silView.Position = UDim2.fromOffset(16, 16)
silView.Size = UDim2.fromOffset(CARD_W - 32, CARD_H - 32)
silView.ZIndex = 8
silView.Parent = card
local realView = Instance.new("ViewportFrame")
realView.Name = "RealSword"
realView.BackgroundTransparency = 1
realView.ImageTransparency = 1
realView.Position = UDim2.fromOffset(16, 16)
realView.Size = UDim2.fromOffset(CARD_W - 32, CARD_H - 32)
realView.ZIndex = 9
realView.Parent = card
local cardFlash = Instance.new("Frame")
cardFlash.Name = "CardFlash"
cardFlash.BackgroundColor3 = WHITE
cardFlash.BackgroundTransparency = 1
cardFlash.BorderSizePixel = 0
cardFlash.Size = UDim2.fromScale(1, 1)
cardFlash.ZIndex = 11
cardFlash.Parent = card
corner(cardFlash, 34)

-- The ladder itself, beside the card: ten rungs in their colours, the live one lit.
local pips, pipScales, pipNames = {}, {}, {}
for tier = RUNGS, 1, -1 do
	local row = RUNGS - tier
	local y = RAIL_TOP + row * (PIP + PIP_GAP)
	local holder = Instance.new("Frame")
	holder.Name = "Rung" .. tier
	holder.Position = UDim2.fromOffset(RAIL_X, y)
	holder.Size = UDim2.fromOffset(400, PIP)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 10
	holder.Parent = root
	local s = Instance.new("UIScale")
	s.Parent = holder
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Position = UDim2.fromOffset(0, PIP / 2)
	dot.Size = UDim2.fromOffset(PIP, PIP)
	dot.Rotation = 45
	dot.BackgroundColor3 = TIER_COLORS[tier]
	dot.BorderSizePixel = 0
	dot.ZIndex = 11
	dot.Parent = holder
	corner(dot, 8)
	PanelChrome.gradient(dot, TIER_COLORS[tier]:Lerp(WHITE, 0.45), TIER_COLORS[tier])
	local dotStroke = PanelChrome.stroke(dot, BRIGHT.Outline, 3)
	local nameLabel = PanelChrome.display(holder, {
		name = "Name", text = string.upper(rungName(tier)), size = 27, stroke = 3.5, zIndex = 11,
		color = TIER_COLORS[tier]:Lerp(WHITE, 0.55), xAlign = Enum.TextXAlignment.Left,
		pos = UDim2.fromOffset(PIP + 16, 0), size2 = UDim2.new(1, -PIP - 16, 1, 0),
	})
	nameLabel.TextTransparency = 0.45
	pips[tier] = { holder = holder, dot = dot, stroke = dotStroke, label = nameLabel }
	pipScales[tier] = s
	pipNames[tier] = nameLabel
end

-- The rung band: the one strip that always carries this roll's colour and its true odds.
local band = Instance.new("Frame")
band.Name = "RungBand"
band.AnchorPoint = Vector2.new(0.5, 0)
band.Position = UDim2.fromOffset(W / 2, BAND_Y)
band.Size = UDim2.fromOffset(BAND_W, BAND_H)
band.BackgroundColor3 = WHITE
band.BorderSizePixel = 0
band.ZIndex = 10
band.Parent = root
corner(band, BAND_H / 2)
local bandGrad = PanelChrome.gradient(band, WHITE, WHITE)
PanelChrome.stroke(band, BRIGHT.Outline, 7)
local bandScale = Instance.new("UIScale")
bandScale.Parent = band
local bandName = PanelChrome.display(band, {
	name = "RungName", text = "", size = 64, stroke = 6, zIndex = 11, color = WHITE,
	xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(44, 0), size2 = UDim2.new(0.56, -44, 1, 0),
	scaled = true, minSize = 22,
})
local bandOdds = PanelChrome.display(band, {
	name = "Odds", text = "", size = 56, stroke = 5.5, zIndex = 11, color = WHITE,
	xAlign = Enum.TextXAlignment.Right, anchor = Vector2.new(1, 0.5), pos = UDim2.new(1, -44, 0.5, 0),
	size2 = UDim2.new(0.44, -44, 1, 0), scaled = true, minSize = 20,
})

-- The modifiers, rebuilt per reveal: they land one at a time once the sword is real.
local modsRow = Instance.new("Frame")
modsRow.Name = "Mods"
modsRow.Position = UDim2.fromOffset(0, MODS_Y)
modsRow.Size = UDim2.fromOffset(W, MOD_H)
modsRow.BackgroundTransparency = 1
modsRow.ZIndex = 10
modsRow.Parent = root
local modsLayout = Instance.new("UIListLayout")
modsLayout.FillDirection = Enum.FillDirection.Horizontal
modsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
modsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
modsLayout.Padding = UDim.new(0, 14)
modsLayout.SortOrder = Enum.SortOrder.LayoutOrder
modsLayout.Parent = modsRow

local footLine = PanelChrome.display(root, {
	name = "Foot", text = "", size = 34, stroke = 4.5, zIndex = 12, color = WHITE,
	pos = UDim2.fromOffset(0, FOOT_Y), size2 = UDim2.new(1, 0, 0, 38), scaled = true, minSize = 16,
})

-- What the blow that paid for this roll was worth: known before the reveal, so it is on screen
-- the whole way through and nothing about the outcome leaks from it.
local blowCard = Instance.new("Frame")
blowCard.Name = "Blow"
blowCard.Position = UDim2.fromOffset(BLOW_X, BLOW_Y)
blowCard.Size = UDim2.fromOffset(BLOW_W, 260)
blowCard.BackgroundTransparency = 1
blowCard.ZIndex = 10
blowCard.Parent = root
PanelChrome.display(blowCard, {
	name = "Head", text = "THIS BLOW", size = 32, stroke = 4, zIndex = 11, color = Color3.fromRGB(255, 226, 150),
	xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(6, 0), size2 = UDim2.new(1, -6, 0, 40),
})
local blowRows = {}
for i = 1, 3 do
	local chip = Instance.new("Frame")
	chip.Name = "Row" .. i
	chip.Position = UDim2.fromOffset(0, 46 + (i - 1) * 70)
	chip.Size = UDim2.fromOffset(BLOW_W, 60)
	chip.BackgroundColor3 = Color3.fromRGB(30, 22, 48)
	chip.BorderSizePixel = 0
	chip.ZIndex = 10
	chip.Visible = false
	chip.Parent = blowCard
	corner(chip, 30)
	PanelChrome.stroke(chip, BRIGHT.Outline, 4)
	blowRows[i] = {
		frame = chip,
		label = PanelChrome.display(chip, {
			name = "Text", text = "", size = 30, stroke = 3.5, zIndex = 11, color = WHITE,
			xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(24, 0), size2 = UDim2.new(1, -40, 1, 0),
			scaled = true, minSize = 14,
		}),
	}
end

local hint = PanelChrome.display(root, {
	name = "Hint", text = "", size = 30, stroke = 4, zIndex = 12, color = Color3.fromRGB(190, 255, 170),
	xAlign = Enum.TextXAlignment.Left, pos = UDim2.fromOffset(BLOW_X + 6, BLOW_Y + 400), size2 = UDim2.fromOffset(BLOW_W, 44),
})
hint.Visible = false

-- The reason to go again, on the card itself: the anvil is free the moment the result is
-- readable, so the next strike is one press away and its price is already on the button.
local againBtn, againLabel = PanelChrome.chunkyButton(root, {
	name = "StrikeAgain", text = "STRIKE AGAIN", textSize = 44, radius = 26, strokeThickness = 5,
	color = BRIGHT.Gold, colorDark = BRIGHT.GoldDark, zIndex = 14,
	pos = UDim2.fromOffset(BLOW_X, BLOW_Y + 292), size = UDim2.fromOffset(BLOW_W, 96),
})
againBtn.Visible = false
local againScale = Instance.new("UIScale")
againScale.Parent = againBtn
local strikeAgain = nil -- set by the wiring: the very same strike() the FORGE button calls
againBtn.Activated:Connect(function()
	if strikeAgain then strikeAgain() end
end)

local sparks = Instance.new("Frame")
sparks.Name = "Sparks"
sparks.Size = UDim2.fromScale(1, 1)
sparks.BackgroundTransparency = 1
sparks.ZIndex = 20
sparks.Parent = root

local flash = Instance.new("Frame")
flash.Name = "Flash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = WHITE
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 28
flash.Parent = gui

-- The rays turn slowly the whole time the reveal is up.
RunService.RenderStepped:Connect(function(dt)
	if gui.Enabled then rayHolder.Rotation = (rayHolder.Rotation + dt * 15) % 360 end
end)

-- Screen shake on the landing, scaled to the rung.
local shakeMag, shakeUntil = 0, 0
RunService.RenderStepped:Connect(function()
	if os.clock() > shakeUntil then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	local k = shakeMag / 180
	camera.CFrame = camera.CFrame * CFrame.new(math.random(-100, 100) / 100 * k, math.random(-100, 100) / 100 * k, 0)
end)

local function sparkBurst(count: number, tint: Color3, reach: number)
	for i = 1, count do
		local s = Instance.new("Frame")
		s.Name = "Spark"
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.fromOffset(CARD_CX, CARD_CY)
		local size = math.random(14, 42)
		s.Size = UDim2.fromOffset(size, size)
		s.Rotation = math.random(0, 90)
		s.BackgroundColor3 = if i % 3 == 0 then Color3.fromRGB(255, 252, 226)
			elseif i % 3 == 1 then tint else tint:Lerp(WHITE, 0.55)
		s.BorderSizePixel = 0
		s.ZIndex = 21
		s.Parent = sparks
		corner(s, math.floor(size / 3))
		local angle = math.rad(math.random(0, 359))
		local r = reach * math.random(50, 135) / 100
		local time = math.random(50, 110) / 100
		TweenService:Create(s, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(CARD_CX + math.cos(angle) * r, CARD_CY + math.sin(angle) * r + r * 0.18),
			BackgroundTransparency = 1, Rotation = s.Rotation + math.random(-280, 280), Size = UDim2.fromOffset(5, 5),
		}):Play()
		task.delay(time + 0.06, function() s:Destroy() end)
	end
end

local function shockRing(tint: Color3, to: number, time: number)
	local r = Instance.new("Frame")
	r.Name = "Shock"
	r.AnchorPoint = Vector2.new(0.5, 0.5)
	r.Position = UDim2.fromOffset(CARD_CX, CARD_CY)
	r.Size = UDim2.fromOffset(200, 200)
	r.BackgroundTransparency = 1
	r.BorderSizePixel = 0
	r.ZIndex = 19
	r.Parent = sparks
	corner(r, 600)
	local stroke = PanelChrome.stroke(r, tint, 18)
	TweenService:Create(r, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(to, to) }):Play()
	TweenService:Create(stroke, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = 1, Thickness = 2 }):Play()
	task.delay(time + 0.05, function() r:Destroy() end)
end

-- Paint the whole stage in one rung's colour: the card, its glow, the rays, the band and the
-- rung lit on the ladder. This is the only thing a tick does.
local litTier = nil
-- `punch` marks the one tick that locks the result: instead of the same small boop every other
-- tick gets, it grows past life-size on an ease-out-back over the first 60 ms and settles back to
-- 1.0 by 120 ms, with a brighter flare on the glow discs and card synced to that same 60 ms beat --
-- so the frame that locks reads as its own event, not just "the ladder happened to stop".
local function setTint(tier: number, pop: number?, punch: boolean?)
	local c = TIER_COLORS[tier] or TIER_COLORS[1]
	cardGrad.Color = ColorSequence.new(c:Lerp(WHITE, 0.34), c:Lerp(DARK, 0.28))
	cardStroke.Color = BRIGHT.Outline
	bandGrad.Color = ColorSequence.new(c:Lerp(WHITE, 0.3), c:Lerp(DARK, 0.3))
	bandName.Text = string.upper(rungName(tier))
	for _, g in ipairs(glows) do g.frame.BackgroundColor3 = c end
	for _, ray in ipairs(rayBars) do ray.BackgroundColor3 = c:Lerp(WHITE, 0.5) end
	if litTier and pips[litTier] then
		pipScales[litTier].Scale = 1
		pips[litTier].stroke.Thickness = 3
		pipNames[litTier].TextTransparency = 0.45
	end
	litTier = tier
	if pips[tier] then
		pipScales[tier].Scale = 1.28
		pips[tier].stroke.Thickness = 6
		pipNames[tier].TextTransparency = 0
	end
	if punch then
		cardScale.Scale = 1
		local grow = TweenService:Create(cardScale, TweenInfo.new(0.06, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.12 })
		grow.Completed:Once(function()
			TweenService:Create(cardScale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)
		grow:Play()
		cardFlash.BackgroundTransparency = 0.45
		TweenService:Create(cardFlash, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		for _, g in ipairs(glows) do
			g.frame.BackgroundTransparency = math.max(g.rest - 0.55, 0)
			TweenService:Create(g.frame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = g.rest }):Play()
		end
		sparkBurst(12, c, 220)
	elseif pop then
		cardScale.Scale = pop
		TweenService:Create(cardScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

-- The relic on the anvil, by whichever of its two names has reached this client: the server
-- renames the Tool as it re-rolls it, and the rename and the Result race each other.
local function swordInfo(result, tier)
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if container then
			for _, n in ipairs({ result.toolName, result.oldName }) do
				local found = n and container:FindFirstChild(n)
				if found and found:IsA("Tool") then return { toolName = n, tier = tier } end
			end
		end
	end
	return { toolName = result.toolName, tier = tier }
end

local function blacken(viewport)
	viewport.Ambient = Color3.fromRGB(0, 0, 0)
	viewport.LightColor = Color3.fromRGB(0, 0, 0)
	for _, d in ipairs(viewport:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Color = Color3.fromRGB(9, 7, 18)
			d.Material = Enum.Material.SmoothPlastic
			d.Transparency = 0
			d.Reflectance = 0
			if d:IsA("MeshPart") then pcall(function() d.TextureID = "" end) end
		elseif d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture") then
			d:Destroy()
		end
	end
end

local function clearMods()
	for _, c in ipairs(modsRow:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
end

-- One modifier, still dark and empty until it locks in.
local function modChip(order: number, width: number, title: string, desc: string, oneIn: string, tier: number)
	local c = TIER_COLORS[tier] or TIER_COLORS[1]
	local chip = Instance.new("Frame")
	chip.Name = "Mod" .. order
	chip.LayoutOrder = order
	chip.Size = UDim2.fromOffset(width, MOD_H)
	chip.BackgroundColor3 = WHITE
	chip.BorderSizePixel = 0
	chip.ZIndex = 10
	chip.Parent = modsRow
	corner(chip, 26)
	PanelChrome.gradient(chip, c:Lerp(WHITE, 0.4), c:Lerp(DARK, 0.2))
	PanelChrome.stroke(chip, BRIGHT.Outline, 5)
	PanelChrome.display(chip, {
		name = "Title", text = title, size = 38, stroke = 4.5, zIndex = 11, color = WHITE,
		pos = UDim2.fromOffset(16, 6), size2 = UDim2.new(1, -32, 0, 44), scaled = true, minSize = 16,
	})
	PanelChrome.display(chip, {
		name = "Desc", text = desc, size = 26, stroke = 3, zIndex = 11, color = Color3.fromRGB(255, 252, 232),
		pos = UDim2.fromOffset(16, 50), size2 = UDim2.new(1, -32, 0, 30), scaled = true, minSize = 12,
	})
	PanelChrome.display(chip, {
		name = "Odds", text = oneIn, size = 22, stroke = 3, zIndex = 11, color = Color3.fromRGB(255, 240, 190),
		pos = UDim2.fromOffset(16, 78), size2 = UDim2.new(1, -32, 0, 24), scaled = true, minSize = 11,
	})
	local s = Instance.new("UIScale")
	s.Scale = 0.001
	s.Parent = chip
	return chip, s
end

local summaryText = { headline = "", band = "", odds = "", mods = "", foot = "" }
local dismissed = false
local readyToStrike = false
-- Once the card is readable, tapping anywhere is the next forge, not just a dismissal: that is
-- the whole loop -- strike, read what came off the anvil, strike again without leaving the card.
scrim.Activated:Connect(function()
	if readyToStrike and strikeAgain then strikeAgain() return end
	dismissed = true
end)

local playToken = 0
local function hide()
	playToken += 1
	readyToStrike = false
	againBtn.Visible = false
	gui.Enabled = false
	flash.BackgroundTransparency = 1
	scrim.BackgroundColor3 = DARK
	for _, c in ipairs(sparks:GetChildren()) do c:Destroy() end
end

-- `onReady` fires the instant the whole result is legible -- name, rung, true 1-in-N and every
-- modifier locked in. That is when the anvil is handed back, with the card still on screen.
local function play(result, onReady)
	playToken += 1
	local token = playToken
	readyToStrike = false
	againBtn.Visible = false
	local fast = peek(skipAnimationValue) == true
	local t0 = os.clock()
	local landTier = math.max(result.topTier or 0, 1)
	local plain = (result.topTier or 0) < 1
	local nearTier = if landTier >= RUNGS then landTier - 1 else landTier + 1
	local landColor = TIER_COLORS[landTier] or TIER_COLORS[1]
	local selected = peek(selectedC)

	-- The sword itself. The silhouette is the relic that went on the anvil (a re-roll changes
	-- its modifiers and its name, never its shape), so the mystery is up on the first frame;
	-- the real one is drawn at the landing, by which time the server's rename has replicated.
	local tier = (selected and selected.tier) or 1
	renderSword(silView, swordInfo(result, tier), SWORD_POSE)
	blacken(silView)
	realView.ImageTransparency = 1
	silView.ImageTransparency = 0

	clearMods()
	qmark.Visible = true
	qmark.TextTransparency = 0.52
	if qmarkStroke then qmarkStroke.Transparency = 0 end
	cardFlash.BackgroundTransparency = 1
	headline.Text = "WHAT CAME OFF THE ANVIL?"
	headline.TextColor3 = WHITE
	subline.Text = string.upper(baseName(result.oldName or result.toolName or "relic"))
	footLine.Text = ""
	bandOdds.Text = "1 IN ?"
	hint.Visible = false
	dismissed = false
	scrim.BackgroundColor3 = DARK
	scrim.BackgroundTransparency = 0.12
	for _, g in ipairs(glows) do
		g.frame.Size = UDim2.fromOffset(g.size, g.size)
		g.frame.BackgroundTransparency = g.rest
	end

	-- The blow that bought this roll's luck, on screen from the first frame.
	local blowLines = {}
	local st = result.strike
	if st then table.insert(blowLines, string.format("%s STRIKE  x%.2f", string.upper(st.quality or "MISS"), st.mult or 1)) end
	local luckTotal = (st and st.luck) or (result.luck and result.luck.total) or 1
	table.insert(blowLines, string.format("LUCK  %.1fx", luckTotal))
	if result.strikeOneInText then table.insert(blowLines, string.upper(result.strikeOneInText) .. " PER STRIKE") end
	for i, row in ipairs(blowRows) do
		row.frame.Visible = blowLines[i] ~= nil
		row.label.Text = blowLines[i] or ""
	end

	setTint(1)
	cardScale.Scale = 0.55
	bandScale.Scale = 1
	gui.Enabled = true
	TweenService:Create(cardScale, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	-- The ladder climbs past, wrapping, and ends on the rung above the truth.
	local big = landTier >= BIG_TIER
	local ticks = fast and 4 or (big and TICKS or (landTier >= 4 and TICKS_MID or TICKS_LOW))
	local ladder = {}
	for i = 1, ticks do
		ladder[i] = ((nearTier - (ticks - i) - 1) % RUNGS) + 1
	end
	for i, rung in ipairs(ladder) do
		if playToken ~= token then return end
		local gap = fast and 0.07 or tickGap(i, ticks)
		-- As the beats lengthen toward the landing, the glow swells with them: tension the eye
		-- can feel building, not just a slower metronome.
		local tension = (not fast) and math.clamp((gap - TAIL_GAPS[1]) / (TAIL_GAPS[#TAIL_GAPS] - TAIL_GAPS[1]), 0, 1) or 0
		setTint(rung, 1.07 + 0.1 * tension)
		if tension > 0 then
			for _, g in ipairs(glows) do
				g.frame.Size = UDim2.fromOffset(g.size * (1 + 0.08 * tension), g.size * (1 + 0.08 * tension))
			end
		end
		AudioManager.PlaySFX("reveal_tick", gui, { PlaybackSpeed = 1.15 + 0.09 * i, Volume = 0.22 + 0.02 * i })
		task.wait(gap)
	end

	-- The near miss: one whole beat sitting on the rung above, with the card shivering.
	local nearAt = os.clock() - t0
	if not fast then
		AudioManager.PlaySFX("reveal_tick", gui, { PlaybackSpeed = 0.75, Volume = 0.5 })
		local until_ = os.clock() + (landTier >= 4 and NEAR_HOLD or NEAR_HOLD_LOW)
		while os.clock() < until_ do
			if playToken ~= token then return end
			card.Rotation = math.sin((until_ - os.clock()) * 42) * 1.6
			RunService.RenderStepped:Wait()
		end
		card.Rotation = 0
	else
		task.wait(0.1)
	end

	-- THE LANDING. Everything from here is the server's answer. The card gets its own punch here
	-- (not the same small boop a tick gets) so the eye can tell "it just locked" on sight alone.
	local landAt = os.clock() - t0
	setTint(landTier, nil, true)
	local heat = landTier / RUNGS
	AudioManager.PlaySFX("reveal_land", gui, { PlaybackSpeed = 0.82 + 0.5 * heat, Volume = 0.6 + 0.5 * heat })
	sparkBurst(math.floor(14 + landTier * 15), landColor, 320 + landTier * 62)
	shockRing(landColor, 560 + landTier * 130, 0.5 + 0.06 * landTier)
	if landTier >= 4 then shockRing(WHITE, 420 + landTier * 90, 0.36 + 0.05 * landTier) end
	shakeMag = 6 + landTier * 3.4
	shakeUntil = os.clock() + 0.16 + 0.035 * landTier
	flash.BackgroundColor3 = landColor:Lerp(WHITE, 0.5)
	flash.BackgroundTransparency = math.max(0.88 - 0.08 * landTier, 0.12)
	TweenService:Create(flash, TweenInfo.new(0.22 + 0.035 * landTier, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }):Play()
	-- The rung's colour floods the screen behind the card, the way a crate's does.
	scrim.BackgroundColor3 = landColor:Lerp(DARK, 0.76)
	for _, g in ipairs(glows) do
		g.frame.BackgroundTransparency = math.max(g.rest - 0.3, 0)
		g.frame.Size = UDim2.fromOffset(g.size * 1.22, g.size * 1.22)
		TweenService:Create(g.frame, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = g.rest - 0.12, Size = UDim2.fromOffset(g.size * 1.06, g.size * 1.06) }):Play()
	end
	renderSword(realView, swordInfo(result, tier), SWORD_POSE)
	realView.ImageTransparency = 1
	bandScale.Scale = 1.16
	TweenService:Create(bandScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	headline.Text = plain and "PLAIN" or (string.upper(rungName(landTier)) .. "!")
	headline.TextColor3 = landColor:Lerp(WHITE, 0.4)
	task.wait(fast and 0.12 or LAND_HOLD)

	-- The silhouette resolves into the real sword.
	if playToken ~= token then return end
	cardFlash.BackgroundTransparency = 0.1
	TweenService:Create(cardFlash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(silView, TweenInfo.new(0.22), { ImageTransparency = 1 }):Play()
	TweenService:Create(realView, TweenInfo.new(0.22), { ImageTransparency = 0 }):Play()
	TweenService:Create(qmark, TweenInfo.new(0.18), { TextTransparency = 1 }):Play()
	if qmarkStroke then TweenService:Create(qmarkStroke, TweenInfo.new(0.18), { Transparency = 1 }):Play() end
	AudioManager.PlaySFX("reveal_lock", gui, { PlaybackSpeed = 1.05, Volume = 0.55 })
	headline.Text = string.upper(result.toolName or "")
	headline.TextColor3 = WHITE
	subline.Text = string.format("%s RELIC  ·  %s", string.upper(result.rarity or ""), plain and "NO MODIFIERS" or "MODIFIERS LOCKING IN")
	bandOdds.Text = plain and "NO ROLL" or string.upper(result.topOneInText or "1 IN ?")
	local resolvedAt = os.clock() - t0

	-- ...and the modifiers land one at a time, the best of them last and slowest.
	local order = {}
	if result.variant then
		table.insert(order, { title = string.upper(tostring(result.variant)), desc = "mutation", oneIn = "", tier = 8 })
	end
	if result.blessed then
		table.insert(order, { title = "BLESSED", desc = "extra slot, rolled a rung higher", oneIn = "", tier = 9 })
	end
	local sorted = table.clone(result.mods)
	table.sort(sorted, function(a, b) return (a.tier or 0) < (b.tier or 0) end)
	for _, m in ipairs(sorted) do
		table.insert(order, {
			title = string.upper(m.name or "?"), desc = m.desc or "", tier = m.tier or 1,
			oneIn = string.format("%s  ·  %s", string.upper(m.rung or rungName(m.tier)), string.upper(m.oneInText or "")),
		})
	end
	if #order == 0 then
		table.insert(order, { title = "PLAIN", desc = "no modifiers this time", oneIn = "", tier = 1 })
	end
	local names = {}
	local chipW = math.floor(math.min(372, (W - 80 - (#order - 1) * 14) / #order))
	-- Whether one modifier landed or six, the lock-in runs for the same beat and a half: the
	-- earlier ones share what is left after the last one's long pause.
	local modRun = if big then MOD_RUN else MOD_RUN_LOW
	local lastStep = if big then LAST_STEP else LAST_STEP_LOW
	local restStep = if #order > 1 then math.max((modRun - lastStep) / (#order - 1), 0.09) else 0
	for i, m in ipairs(order) do
		if playToken ~= token then return end
		-- The pause comes before the chip, and the last pause is the longest: the best modifier
		-- of the roll is sorted last, so the wait for it is the one that hurts.
		task.wait(fast and 0.06 or (i == #order and lastStep or restStep))
		if playToken ~= token then return end
		local _, s = modChip(i, chipW, m.title, m.desc, m.oneIn, m.tier)
		TweenService:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		AudioManager.PlaySFX("reveal_lock", gui, { PlaybackSpeed = 0.9 + 0.08 * i, Volume = 0.45 })
		if m.tier >= 7 then sparkBurst(10, TIER_COLORS[m.tier], 220) end
		table.insert(names, m.title)
	end

	-- The receipt: what it cost and what it was worth.
	local notes = {}
	if result.personalBest then table.insert(notes, "NEW PERSONAL BEST") end
	if result.broadcast then table.insert(notes, "SERVER-WIDE!") end
	if result.pityApplied then table.insert(notes, "PITY FLOOR APPLIED") end
	if result.kept then table.insert(notes, "KEPT " .. string.upper(tostring(result.kept))) end
	local delta = result.after - result.before
	footLine.Text = string.format("%s -> %s  (%s%s)   %s%s", SwordValue.short(result.before), SwordValue.short(result.after),
		delta >= 0 and "+" or "-", SwordValue.short(math.abs(delta)),
		result.free and "FREE" or ("-" .. SwordValue.short(result.cost) .. " GOLD"),
		#notes > 0 and ("   ·   " .. table.concat(notes, "  ·  ")) or "")
	footLine.TextColor3 = delta > 0 and Color3.fromRGB(160, 255, 130) or (delta < 0 and Color3.fromRGB(255, 140, 140) or WHITE)
	subline.Text = string.format("%s RELIC  ·  %s", string.upper(result.rarity or ""),
		plain and "NO MODIFIERS" or (#result.mods .. (#result.mods == 1 and " MODIFIER" or " MODIFIERS")))
	summaryText = {
		headline = headline.Text, band = bandName.Text, odds = bandOdds.Text,
		mods = table.concat(names, " / "), foot = footLine.Text,
	}
	local readableAt = os.clock() - t0

	-- READABLE. The anvil goes back to the player here, not when the card finally clears: the
	-- button on the card is live, a tap anywhere is the next strike, and the panel behind has
	-- already caught up with the sword that just came off the anvil.
	readyToStrike = true
	againLabel.Text = (onReady and onReady()) or "STRIKE AGAIN"
	againBtn.Visible = true
	againScale.Scale = 0.72
	TweenService:Create(againScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	AudioManager.PlaySFX("reveal_lock", gui, { PlaybackSpeed = 1.3, Volume = 0.3 })
	hint.Text = "TAP ANYWHERE  ·  THE ANVIL IS HOT"
	hint.Visible = true

	dismissed = false
	local until_ = os.clock() + (fast and 0.5 or SETTLE_HOLD)
	while os.clock() < until_ and not dismissed do
		if playToken ~= token then return end
		task.wait(0.03)
	end
	if playToken ~= token then return end
	hide()
	return { near = nearAt, land = landAt, resolved = resolvedAt, readable = readableAt, total = os.clock() - t0 }
end

return {
	play = play,
	hide = hide,
	dismiss = function()
		readyToStrike = false
		dismissed = true
		hide()
	end,
	setStrikeAgain = function(fn) strikeAgain = fn end,
	summary = function() return summaryText end,
	LAND_HOLD = LAND_HOLD,
	SETTLE_HOLD = SETTLE_HOLD,
}
end)()

-- ── The forge run rail ──────────────────────────────────────────────────────
-- One strip across the top of the screen that never goes away while the anvil is open: not
-- during the meter, not under the blow, not behind the full-screen reveal. It carries the state
-- a forge loop is actually played on -- how many strikes into this run you are, the kill streak
-- and the luck it is worth, the blow's multiplier the moment the server scores it, how far the
-- lucky-roll floor has crept, and the rungs of the last eight forges as a row of coloured pips
-- with the best of the run called out. Every number on it comes from the server's own
-- disclosure (the State payload) or from the server's own Struck/Result payloads; the client
-- adds nothing but the arithmetic of counting.
local RunRail = (function()
local W, H = 1500, 116
local PIPS = 6

local gui = Instance.new("ScreenGui")
gui.Name = "ForgeRunRail"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 28 -- above the reveal (26) and the strike layer (23)
gui.Enabled = false
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Rail"
root.AnchorPoint = Vector2.new(0.5, 0)
root.Position = UDim2.new(0.5, 0, 0, 56) -- clear of Roblox's own top bar
root.Size = UDim2.fromOffset(W, H)
root.BackgroundTransparency = 1
root.Parent = gui
local railScale = Instance.new("UIScale")
railScale.Parent = root
PanelChrome.onViewport(function(vp)
	railScale.Scale = math.clamp(vp.X / (W + 60), 0.3, 1.05)
end)

local INK = Color3.fromRGB(255, 255, 255)
local HEAD = Color3.fromRGB(196, 206, 236)

local function cell(x, w, headText)
	local f = Instance.new("Frame")
	f.Name = headText
	f.Position = UDim2.fromOffset(x, 0)
	f.Size = UDim2.fromOffset(w, H)
	f.BackgroundColor3 = Color3.fromRGB(26, 20, 44)
	f.BackgroundTransparency = 0.06
	f.BorderSizePixel = 0
	f.ZIndex = 4
	f.Parent = root
	corner(f, 26)
	local rim = PanelChrome.stroke(f, BRIGHT.Outline, 5)
	PanelChrome.display(f, {
		name = "Head", text = headText, size = 22, stroke = 3, zIndex = 6, color = HEAD,
		pos = UDim2.fromOffset(0, 10), size2 = UDim2.new(1, 0, 0, 26), scaled = true, minSize = 10,
	})
	local value = PanelChrome.display(f, {
		name = "Value", text = "", size = 46, stroke = 4.5, zIndex = 6, color = INK,
		pos = UDim2.fromOffset(8, 36), size2 = UDim2.new(1, -16, 0, 50), scaled = true, minSize = 14,
	})
	local note = PanelChrome.display(f, {
		name = "Note", text = "", size = 22, stroke = 3, zIndex = 6, color = Color3.fromRGB(180, 255, 164),
		pos = UDim2.fromOffset(8, 84), size2 = UDim2.new(1, -16, 0, 26), scaled = true, minSize = 10,
	})
	return f, value, note, rim
end

local _, runValue, runNote = cell(0, 196, "FORGE RUN")
local _, streakValue, streakNote = cell(204, 250, "KILL STREAK")
local _, luckValue, luckNote, luckRim = cell(462, 366, "LUCK ON THIS STRIKE")
local _, pityValue, pityNote = cell(836, 216, "LUCKY ROLL")
local pipCell, _, pipNote = cell(1060, 440, "LAST FORGES  ·  BEST OF THE RUN")

local pips = {}
for i = 1, PIPS do
	local w = 58
	local pip = Instance.new("Frame")
	pip.Name = "Pip" .. i
	pip.Position = UDim2.fromOffset(20 + (i - 1) * (w + 8), 32)
	pip.Size = UDim2.fromOffset(w, 48)
	pip.BackgroundColor3 = Color3.fromRGB(48, 40, 70)
	pip.BorderSizePixel = 0
	pip.ZIndex = 6
	pip.Parent = pipCell
	corner(pip, 12)
	local stroke = PanelChrome.stroke(pip, BRIGHT.Outline, 3.5)
	local label = PanelChrome.display(pip, {
		name = "T", text = "", size = 34, stroke = 3.5, zIndex = 7, color = INK,
		scaled = true, minSize = 12,
	})
	pips[i] = { frame = pip, label = label, stroke = stroke }
end

-- A short-lived word on the rail's own bottom line: SO CLOSE on a near miss, NEW BEST OF THE RUN
-- when one lands. It is written into the pip cell's note rather than floated over the screen, so
-- it can never sit on top of the reveal's headline -- the sword's name.
local flashText, flashColor, flashToken = nil, nil, 0
local paint -- forward: the flash repaints the rail

-- Run state. `forges` counts the strikes made since this anvil was opened. The pips themselves
-- are the server's own reforgeRecent list (the top rung of each of the last forges, persisted in
-- the profile), so the rail is already worth reading on the first strike of a session and the
-- client never gets to invent a rung.
local run = { forges = 0, bestTier = 0, bestRung = "", live = false }
local blow = nil -- the server's word on the blow currently being paid for

function paint()
	local odds = peek(oddsInfoValue)
	local luck = odds and odds.luck
	local base = (luck and luck.total) or 1

	runValue.Text = "#" .. tostring(run.forges)
	runNote.Text = string.format("%d FORGED ALL TIME", (odds and odds.count) or 0)

	local streak = (luck and luck.streak) or 0
	streakValue.Text = string.format("%d KILL%s", streak, streak == 1 and "" or "S")
	streakValue.TextColor3 = streak > 0 and Color3.fromRGB(180, 255, 164) or INK
	streakNote.Text = string.format("+%.2f LUCK", (luck and luck.streakBonus) or 0)

	if blow then
		local q = Forge.qualityInfo(blow.quality)
		luckValue.Text = string.format("%.2fx  x%.1f  =  %.2fx", blow.baseLuck or base, blow.mult or 1, blow.luck or base)
		luckValue.TextColor3 = q.color
		luckNote.Text = string.format("%s STRIKE", string.upper(blow.quality or "MISS"))
		luckNote.TextColor3 = q.color
		luckRim.Color, luckRim.Thickness = q.color, 6
	else
		luckValue.Text = string.format("%.2fx", base)
		luckValue.TextColor3 = INK
		local charges = (luck and luck.charges) or 0
		luckNote.Text = string.format("STREAK +%.2f  ·  %d CHARGE%s  ·  REBIRTH +%.2f",
			(luck and luck.streakBonus) or 0, charges, charges == 1 and "" or "S", (luck and luck.rebirthBonus) or 0)
		luckNote.TextColor3 = Color3.fromRGB(180, 255, 164)
		luckRim.Color, luckRim.Thickness = BRIGHT.Outline, 5
	end

	local pity, after = (odds and odds.pity) or 0, math.max((odds and odds.pityAfter) or 5, 1)
	pityValue.Text = pity >= after and "READY!" or string.format("%d / %d", pity, after)
	pityValue.TextColor3 = pity >= after and Color3.fromRGB(180, 255, 164) or INK
	pityNote.Text = string.format("TAIL %d / %d", (odds and odds.tailPity) or 0, (odds and odds.tailPityAfter) or 250)

	local recent = (odds and odds.recent) or {}
	local n = #recent
	for i, pip in ipairs(pips) do
		local tier = recent[n - #pips + i]
		if tier then
			local c = TIER_COLORS[tier] or TIER_COLORS[1]
			pip.frame.BackgroundColor3 = c
			pip.label.Text = string.sub(rungName(tier), 1, 1)
			-- The strikes made since this anvil was opened wear a white rim; the ones the
			-- profile remembers from before sit behind them in the dark rim.
			local thisRun = (#pips - i) < run.forges
			pip.stroke.Color = thisRun and INK or BRIGHT.Outline
			pip.stroke.Thickness = thisRun and 5 or 3.5
		else
			pip.frame.BackgroundColor3 = Color3.fromRGB(48, 40, 70)
			pip.label.Text = ""
			pip.stroke.Color = BRIGHT.Outline
			pip.stroke.Thickness = 3.5
		end
	end
	if flashText then
		pipNote.Text = flashText
		pipNote.TextColor3 = flashColor or INK
	else
		pipNote.Text = run.bestTier > 0 and ("BEST OF THE RUN:  " .. string.upper(run.bestRung)) or "NOTHING FORGED YET"
		pipNote.TextColor3 = run.bestTier > 0 and (TIER_COLORS[run.bestTier] or INK) or Color3.fromRGB(180, 255, 164)
	end
end

local function flash(text, color)
	flashToken += 1
	local token = flashToken
	flashText, flashColor = text, color
	paint()
	task.delay(2.6, function()
		if flashToken == token then
			flashText, flashColor = nil, nil
			paint()
		end
	end)
end

local function setLive(on: boolean)
	run.live = on
	gui.Enabled = on
	if on then paint() end
end

return {
	-- The anvil opened: a fresh run.
	onOpen = function()
		run.forges, run.bestTier, run.bestRung = 0, 0, ""
		blow = nil
		paint()
	end,
	-- FORGE pressed: the strike is paid for and the meter is coming.
	onArm = function()
		run.forges += 1
		blow = nil
		paint()
	end,
	-- The server scored the blow: its multiplier belongs on the rail at once.
	onBlow = function(info)
		blow = info
		paint()
	end,
	-- The server's roll came back: pip it, and say so if it nearly beat the run.
	onResult = function(result)
		local tier = math.max(result.topTier or 0, 1)
		local previousBest = run.bestTier
		if tier > run.bestTier then
			run.bestTier, run.bestRung = tier, result.topRung or rungName(tier)
		end
		paint()
		if tier > previousBest and previousBest > 0 then
			flash("NEW BEST OF THE RUN  ·  " .. string.upper(result.topRung or rungName(tier)), TIER_COLORS[tier] or BRIGHT.Gold)
		elseif previousBest > 0 and tier == previousBest - 1 then
			flash("SO CLOSE  ·  ONE RUNG OFF THE RUN'S BEST", Color3.fromRGB(255, 176, 96))
		elseif result.pityApplied then
			flash("LUCKY ROLL SPENT  ·  FLOOR APPLIED", BRIGHT.Gold)
		end
	end,
	refresh = paint,
	setLive = setLive,
}
end)()

runRail.onOpen, runRail.onArm, runRail.onBlow = RunRail.onOpen, RunRail.onArm, RunRail.onBlow
runRail.onResult, runRail.refresh, runRail.setLive = RunRail.onResult, RunRail.refresh, RunRail.setLive
-- The rail is up for exactly as long as the anvil is: it must not blink out between the panel
-- closing over the reveal and the reveal clearing.
scope:Observer(overlayVisible):onBind(function()
	runRail.setLive(peek(overlayVisible) == true)
end)
-- Striking again from the card: the same strike() the FORGE button calls, and the card goes.
revealHooks.dismiss = function()
	Reveal.dismiss()
	revealingValue:set(false)
end
Reveal.setStrikeAgain(function() strike() end)

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
	runRail.refresh()
end

local pendingState = nil
local queuedResult = nil -- the roll, held back while the hammer blow is still paying off
local lastRevealTiming = nil -- Studio capture only: what the last reveal measured of itself
local lastReadyAt = nil -- Studio capture only: the instant the anvil was handed back

local function playResult(result)
	-- Studio capture only ("Motion:ForgeReveal", below): the strike that paid for this roll runs
	-- before the clapperboard so the reveal itself can start on it, and the server's answer waits
	-- here in the meantime. It is the real roll, held for a beat, only while that stage is staging.
	if forgeState.showcaseHoldReveal then
		forgeState.showcaseHeldResult = result
		return
	end
	-- Studio capture only ("Motion:ForgeRare" and "Motion:ForgeLoop", below): keep the payload so
	-- those stages can print the rung, the true 1-in-N, the luck the blow bought and whether the
	-- server broadcast it. Read only; nothing acts on it.
	forgeState.showcaseRareResult = result
	task.spawn(function()
		local token = forgeState.armToken
		spinningValue:set(true)
		revealingValue:set(true)
		-- The reveal takes the whole screen and carries the blow on its own card, so the strike
		-- banner hands over rather than sitting under it.
		Forge.hideBanner()
		local timing = Reveal.play(result, function()
			-- READABLE. Three things happen together, and this is the whole point of the loop:
			-- the panel behind catches up with the sword that just came off the anvil (the State
			-- the server sent while the hammer was landing -- without this the next strike is
			-- sent with the old sword's name and refused), the rail pips the rung, and the
			-- button goes live again while the card is still on screen.
			if pendingState then
				applyState(pendingState[1], pendingState[2], pendingState[3], pendingState[4])
				pendingState = nil
			end
			runRail.onResult(result)
			if forgeState.armToken == token then spinningValue:set(false) end
			lastReadyAt = os.clock()
			local cost = peek(costTextC)
			return cost == "FREE" and "STRIKE AGAIN  ·  FREE" or ("STRIKE AGAIN  ·  " .. cost)
		end)
		if timing then lastRevealTiming = timing end
		-- A new strike already took the anvil off the card: it owns the panel state now.
		if forgeState.armToken ~= token then return end
		revealingValue:set(false)
		spinningValue:set(false)
		if pendingState then applyState(pendingState[1], pendingState[2], pendingState[3], pendingState[4]) pendingState = nil end
	end)
end
-- The blow's payoff is over: reveal the roll the server already made.
Forge.setDone(function()
	local result = queuedResult
	queuedResult = nil
	if result then playResult(result) end
end)

REFORGE.OnClientEvent:Connect(function(kind, a, b, c, d)
	if kind == "Open" then
		overlayVisible:set(true)
		revealingValue:set(false)
		runRail.onOpen()
		setOddsPopupVisible(false)
		Forge.close()
		Forge.hideBanner()
		Reveal.hide()
		PanelChrome.openMotion(reforgeMotion)
	elseif kind == "Armed" then
		-- Paid: the server lit a meter. Everything about it (speed, sweet zone, start) is its own.
		spinningValue:set(true)
		Forge.open(a)
	elseif kind == "Struck" then
		-- The server scored the blow. This is the only place the word comes from.
		Forge.setStruck(a)
		runRail.onBlow(a)
		if forgeState.active and not Forge.isStruck() then Forge.resolvedWithoutPress(a) end
	elseif kind == "Result" then
		if forgeState.active then
			queuedResult = a -- the hammer is still landing; the reveal waits its turn
		else
			playResult(a)
		end
	elseif kind == "State" then
		if peek(spinningValue) then
			pendingState = { a, b, c, d } -- apply after the reveal lands so the list does not jump mid-roll
		else
			applyState(a, b, c, d)
		end
	end
end)

-- Showcase: open the anvil exactly as the HUD's Reforge button does, then tap the top sword
-- as a player would (a local pick only). Only ever "Open": never "Reroll", which spends gold.
local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))
GuiShowcase.register("Reforge", function()
	REFORGE:FireServer("Open")
	local deadline = os.clock() + 20
	while not (peek(overlayVisible) and #peek(rowsValue) > 0) and os.clock() < deadline do
		task.wait(0.25)
	end
	task.wait(0.6)
	local rows = peek(rowsValue)
	if peek(overlayVisible) and rows[1] and not peek(selectedToolName) then
		selectTool(rows[1].toolName)
	end
end)
-- Studio-only capture of the odds disclosure: the panel with row 1 selected and the Odds popup up.
GuiShowcase.register("ReforgeOdds", function()
	REFORGE:FireServer("Open")
	local deadline = os.clock() + 20
	while not (peek(overlayVisible) and #peek(rowsValue) > 0) and os.clock() < deadline do
		task.wait(0.25)
	end
	task.wait(0.6)
	local rows = peek(rowsValue)
	if peek(overlayVisible) and rows[1] and not peek(selectedToolName) then
		selectTool(rows[1].toolName)
	end
	task.wait(0.4)
	setOddsPopupVisible(true)
end)

-- Motion capture of the strike itself (Studio only, see GuiShowcase.motion). `prepare` opens the
-- anvil and picks the top sword the way a player would, so the panel is settled before the
-- clapperboard; `play` then presses Strike through the very same strike() the button calls, so the
-- server rolls it for real with real gold and the real RNG. ReforgeSystem's Studio stage lends the
-- relic and the gold, and PlayerDataService refuses to save while a showcase is staging.
GuiShowcase.motion("ForgeStrike", function()
	local t0 = os.clock()
	-- Studio capture only: the scripted blow aims for the middle of the sweet zone. It is still a
	-- real press through pressStrike(), on the server's own meter, scored by the server.
	Forge.setShowcaseQuality("PERFECT", 0.8)
	strike()
	local deadline = os.clock() + 45
	while not forgeState.active and os.clock() < deadline do task.wait() end
	local armedAt = os.clock()
	local plan = Forge.plan()
	if plan then
		print(string.format("[ReforgeGuiFusion] showcase strike: meter armed %d ms after the click (sweep %.2f s, sweet zone %.0f ms wide, good zone %.0f ms, centre %.2f)",
			math.floor((armedAt - t0) * 1000 + 0.5), plan.sweep, 2 * plan.sweetHalf * plan.sweep * 1000,
			2 * plan.goodHalf * plan.sweep * 1000, plan.sweetCenter))
	end
	while not Forge.isStruck() and os.clock() < deadline do task.wait() end
	local struckAt = os.clock()
	while not Forge.info() and os.clock() < deadline do task.wait() end
	local info = Forge.info()
	if info then
		print(string.format("[ReforgeGuiFusion] showcase strike: server scored %s (x%.1f), marker %.4f vs sweet centre %.4f (%.0f ms off), luck %.2fx -> %.2fx; blow %d ms after the click",
			tostring(info.quality), info.mult or 1, info.pos or -1, info.sweetCenter or -1,
			math.abs((info.pos or 0) - (info.sweetCenter or 0)) * (plan and plan.sweep or 1) * 1000,
			info.baseLuck or 1, info.luck or 1, math.floor((struckAt - t0) * 1000 + 0.5)))
	end
	while forgeState.active and os.clock() < deadline do task.wait() end
	local revealStart = os.clock()
	print(string.format("[ReforgeGuiFusion] showcase strike: the reveal starts %d ms after the click", math.floor((revealStart - t0) * 1000 + 0.5)))
	while peek(spinningValue) and os.clock() < deadline do task.wait() end
	local closed = os.clock() - t0
	local timing = lastRevealTiming
	local readable = timing and (revealStart - t0 + timing.resolved) or closed
	print(string.format("[ReforgeGuiFusion] showcase strike: click to readable result %d ms; panel handed back %d ms (strike hold %.2f s, settle hold %.2f s)",
		math.floor(readable * 1000 + 0.5), math.floor(closed * 1000 + 0.5), Forge.HOLD, Reveal.SETTLE_HOLD))
	task.wait(1)
	print(string.format("[ReforgeGuiFusion] showcase strike: next strike accepted %d ms after the first",
		math.floor(closed * 1000 + 0.5)))
end, function()
	REFORGE:FireServer("Open")
	local deadline = os.clock() + 20
	while not (peek(overlayVisible) and #peek(rowsValue) > 0) and os.clock() < deadline do
		task.wait(0.25)
	end
	task.wait(0.6)
	-- Set the rarest relic on the anvil (the stage lends a Legendary), so the capture films a
	-- sword with modifiers to re-roll rather than whatever this Studio profile happens to carry.
	local rank = { Legendary = 5, Epic = 4, Rare = 3, Uncommon = 2, Common = 1 }
	local best = nil
	for _, info in ipairs(peek(rowsValue)) do
		if not best or (rank[info.rarity] or 0) > (rank[best.rarity] or 0)
			or ((rank[info.rarity] or 0) == (rank[best.rarity] or 0) and info.rating > best.rating) then
			best = info
		end
	end
	if peek(overlayVisible) and best and not peek(selectedToolName) then
		selectTool(best.toolName)
	end
	task.wait(0.5)
	-- Lock the sword's best modifier, the way a player protecting a good roll does. It is a
	-- local pick like selectTool above, and it is also what makes this strike cost real gold
	-- instead of burning the three-hourly free one, so the price of a MISS is a number on screen.
	local mods = peek(modsC)
	if mods[1] then lockedSet:set({ [mods[1].name] = true }) end
	task.wait(0.7) -- let the hero card and lock chips settle before the clapperboard
end)

-- Motion capture of the reveal (Studio only, see GuiShowcase.motion). The reveal is what happens
-- after the blow, so `prepare` runs the whole strike first -- open the anvil, pick the top relic,
-- arm the meter, land the hammer -- and parks the server's answer instead of revealing it. The
-- clapperboard therefore falls on a settled panel with the roll already in hand, and `play` hands
-- that same answer to the very same playResult() a live roll goes through: real remote, real
-- server RNG, no seed and no forced outcome. Only the instant the hammer falls is scripted.
-- Registered under both names: "ForgeReveal" is the original capture target, "ReforgeReveal" is
-- what the strike-to-reveal transition piece of the reveal is judged under -- same real strike,
-- same real roll, same playResult().
local function revealMotionPlay()
	local result = forgeState.showcaseHeldResult
	forgeState.showcaseHeldResult = nil
	forgeState.showcaseHoldReveal = false
	if not result then
		warn("[ReforgeGuiFusion] showcase reveal: the staged strike never produced a roll")
		return
	end
	local t0 = os.clock()
	playResult(result)
	local deadline = os.clock() + 45
	while not peek(spinningValue) and os.clock() < deadline do task.wait() end
	local started = os.clock()
	while peek(spinningValue) and os.clock() < deadline do task.wait() end
	local closed = os.clock() - t0
	local timing = lastRevealTiming
	local sum = Reveal.summary()
	local lead = started - t0
	print(string.format("[ReforgeGuiFusion] showcase reveal: the ladder started flashing %d ms after the hand-off; near miss %d ms, landing %d ms, name/rung/odds readable %d ms, last modifier locked %d ms, panel handed back %d ms",
		math.floor(lead * 1000 + 0.5), math.floor(((timing and timing.near or 0) + lead) * 1000 + 0.5),
		math.floor(((timing and timing.land or 0) + lead) * 1000 + 0.5),
		math.floor(((timing and timing.resolved or 0) + lead) * 1000 + 0.5),
		math.floor(((timing and timing.readable or 0) + lead) * 1000 + 0.5), math.floor(closed * 1000 + 0.5)))
	print(string.format("[ReforgeGuiFusion] showcase reveal: headline '%s' | rung '%s' | odds '%s' | modifiers '%s' | %s",
		sum.headline, sum.band, sum.odds, sum.mods, sum.foot))
	task.wait(1)
end
local function revealMotionPrepare()
	forgeState.showcaseHoldReveal = true
	forgeState.showcaseHeldResult = nil
	REFORGE:FireServer("Open")
	local deadline = os.clock() + 20
	while not (peek(overlayVisible) and #peek(rowsValue) > 0) and os.clock() < deadline do
		task.wait(0.25)
	end
	task.wait(0.6)
	local rank = { Legendary = 5, Epic = 4, Rare = 3, Uncommon = 2, Common = 1 }
	local best = nil
	for _, info in ipairs(peek(rowsValue)) do
		if not best or (rank[info.rarity] or 0) > (rank[best.rarity] or 0)
			or ((rank[info.rarity] or 0) == (rank[best.rarity] or 0) and info.rating > best.rating) then
			best = info
		end
	end
	if peek(overlayVisible) and best and not peek(selectedToolName) then
		selectTool(best.toolName)
	end
	task.wait(0.8)
	Forge.setShowcaseQuality("PERFECT")
	strike()
	local struckBy = os.clock() + 45
	while not forgeState.showcaseHeldResult and os.clock() < struckBy do task.wait() end
	while forgeState.active and os.clock() < struckBy do task.wait() end
	task.wait(0.9) -- let the forge plate close and the panel go still before the clapperboard
	print("[ReforgeGuiFusion] showcase reveal: the roll is in hand; the reveal waits for the clapperboard")
end
GuiShowcase.motion("ForgeReveal", revealMotionPlay, revealMotionPrepare)
GuiShowcase.motion("ReforgeReveal", revealMotionPlay, revealMotionPrepare)

-- Motion capture of the RARE moment (Studio only, see GuiShowcase.motion): a strike that lands
-- the top rung of the ladder, which is what the whole server is told about. A real one is 1 in
-- 500,000 per slot, so ReforgeSystem's Studio stage forces the first rolled slot of this one
-- strike to the top rung -- the roll is otherwise the live code path (real gold, real luck, real
-- slot count, real mutation, real remotes, real broadcast), and nothing here can run outside
-- Studio. The clapperboard is aimed at the hammer blow itself: `prepare` opens the anvil, picks
-- the Legendary, arms the meter and then waits until 1.1 s before the blow the meter has already
-- scheduled, so the flash, its half-second hold and the impact land in that order. The strip
-- therefore starts on the blow and runs through the payoff, the server-wide broadcast toast and
-- the whole reveal to the settled sword.
GuiShowcase.motion("ForgeRare", function()
	local t0 = os.clock()
	local deadline = os.clock() + 60
	while not Forge.isStruck() and os.clock() < deadline do task.wait() end
	local struckAt = os.clock()
	while not Forge.info() and os.clock() < deadline do task.wait() end
	local info = Forge.info()
	print(string.format("[ReforgeGuiFusion] showcase rare: the hammer fell %d ms after the clapperboard; server scored %s (x%.1f), luck %.2fx -> %.2fx",
		math.floor((struckAt - t0) * 1000 + 0.5), tostring(info and info.quality), (info and info.mult) or 1,
		(info and info.baseLuck) or 1, (info and info.luck) or 1))
	while forgeState.active and os.clock() < deadline do task.wait() end
	local revealStart = os.clock()
	while not peek(spinningValue) and os.clock() < deadline do task.wait() end
	while peek(spinningValue) and os.clock() < deadline do task.wait() end
	local closed = os.clock() - t0
	local timing = lastRevealTiming
	local lead = revealStart - t0
	local last = forgeState.showcaseRareResult
	print(string.format("[ReforgeGuiFusion] showcase rare: reveal opened %d ms after the blow; near miss %d ms, landing %d ms, name/rung/odds readable %d ms, last modifier locked %d ms, panel handed back %d ms",
		math.floor(lead * 1000 + 0.5), math.floor(((timing and timing.near or 0) + lead) * 1000 + 0.5),
		math.floor(((timing and timing.land or 0) + lead) * 1000 + 0.5),
		math.floor(((timing and timing.resolved or 0) + lead) * 1000 + 0.5),
		math.floor(((timing and timing.readable or 0) + lead) * 1000 + 0.5), math.floor(closed * 1000 + 0.5)))
	local sum = Reveal.summary()
	print(string.format("[ReforgeGuiFusion] showcase rare: headline '%s' | rung '%s' | odds '%s' | modifiers '%s' | %s",
		sum.headline, sum.band, sum.odds, sum.mods, sum.foot))
	if last then
		print(string.format("[ReforgeGuiFusion] showcase rare: top rung %s (tier %d), %s per slot, %s per strike; broadcast to the whole server: %s (broadcast tier %s)",
			tostring(last.topRung), last.topTier or 0, tostring(last.topOneInText), tostring(last.strikeOneInText),
			tostring(last.broadcast), tostring(last.broadcastTier)))
	end
	task.wait(1)
end, function()
	REFORGE:FireServer("Open")
	local deadline = os.clock() + 20
	while not (peek(overlayVisible) and #peek(rowsValue) > 0) and os.clock() < deadline do
		task.wait(0.25)
	end
	task.wait(0.6)
	local rank = { Legendary = 5, Epic = 4, Rare = 3, Uncommon = 2, Common = 1 }
	local best = nil
	for _, info in ipairs(peek(rowsValue)) do
		if not best or (rank[info.rarity] or 0) > (rank[best.rarity] or 0)
			or ((rank[info.rarity] or 0) == (rank[best.rarity] or 0) and info.rating > best.rating) then
			best = info
		end
	end
	if peek(overlayVisible) and best and not peek(selectedToolName) then
		selectTool(best.toolName)
	end
	task.wait(0.8)
	Forge.setShowcaseQuality("PERFECT")
	strike()
	local armedBy = os.clock() + 45
	while not Forge.pressAt() and os.clock() < armedBy do task.wait() end
	local pressAt = Forge.pressAt()
	if not pressAt then
		warn("[ReforgeGuiFusion] showcase rare: the meter never scheduled a blow")
		return
	end
	-- GuiShowcase.motion waits 0.3 s after prepare, flashes for 0.25 s and holds 0.5 s before
	-- play(), so hand back 1.1 s before the blow and the strip's first frames are the impact.
	while workspace:GetServerTimeNow() < pressAt - 1.1 do task.wait() end
	print("[ReforgeGuiFusion] showcase rare: the meter is armed and the blow is 1.1 s out; the clapperboard goes now")
end)

-- Motion capture of the forge LOOP (Studio only, see GuiShowcase.motion): several forges back to
-- back, which is what this piece is judged on -- how soon the hammer can come round again, what
-- the panel keeps showing of the streak, the luck, the blow's multiplier and the pity between
-- rolls, and what carries a player into the next strike. `prepare` opens the anvil and picks the
-- top relic, the same way the other forge captures do; `play` then runs LOOP_FORGES whole cycles
-- through the very same strike() the button calls -- real gold, real remotes, the server's own
-- meter and the server's own RNG, nothing seeded or forced -- and presses the next one the moment
-- the panel hands the button back, which is as fast as a player can go. The blows are aimed at
-- PERFECT, GOOD and OK in turn so one strip carries all three multipliers and the miss as well as
-- the hit; the server still scores every one of them from its own clock, and the rolls are
-- whatever the ladder gives. ReforgeSystem's Studio stage lends the relic and the gold, and
-- PlayerDataService refuses to save while a showcase is staging.
local LOOP_FORGES = 4 -- [TUNING] Studio capture only
local LOOP_QUALITIES = { "PERFECT", "GOOD", "PERFECT", "OK" }
local LOOP_AIM = 0.35 -- [TUNING] seconds into the meter: the first crossing, not a long wait
local LOOP_REACTION = 0.2 -- [TUNING] Studio capture only: a hand's reaction, not a system wait
GuiShowcase.motion("ForgeLoop", function()
	local loopT0 = os.clock()
	local cycles = {}
	for i = 1, LOOP_FORGES do
		local quality = LOOP_QUALITIES[(i - 1) % #LOOP_QUALITIES + 1]
		-- Studio capture only: a real press through pressStrike(), aimed at the first crossing of
		-- the chosen band. Nothing about the scoring, the luck or the roll is touched.
		Forge.setShowcaseQuality(quality, LOOP_AIM)
		local clickAt = os.clock()
		local deadline = clickAt + 45
		local goldBefore = peek(goldValue)
		strike()
		while not forgeState.active and os.clock() < deadline do task.wait() end
		local armedAt = os.clock()
		while not Forge.isStruck() and os.clock() < deadline do task.wait() end
		local blowAt = os.clock()
		while forgeState.active and os.clock() < deadline do task.wait() end
		local revealAt = os.clock()
		-- The anvil hands the button back the instant the card is readable, with the card still
		-- up: spinningValue going false IS that instant, so it is both the readable time and the
		-- time the next strike became available.
		while peek(spinningValue) and os.clock() < deadline do task.wait() end
		local readableAt = lastReadyAt or os.clock()
		if i < LOOP_FORGES then task.wait(LOOP_REACTION) end
		local doneAt = os.clock()
		local timing = lastRevealTiming
		local info = Forge.info()
		local result = forgeState.showcaseRareResult
		local disclosure = peek(oddsInfoValue) or {}
		local luck = (result and result.luck) or {}
		table.insert(cycles, { click = clickAt, readable = readableAt, done = doneAt })
		local ms = function(t) return math.floor((t - clickAt) * 1000 + 0.5) end
		print(string.format("[ReforgeGuiFusion] showcase loop %d/%d: aimed %s, server scored %s (x%.1f, marker %.3f vs centre %.3f); meter lit %d ms, hammer fell %d ms, reveal opened %d ms, result readable AND button live again %d ms, next strike sent %d ms -- whole cycle %d ms",
			i, LOOP_FORGES, quality, tostring(info and info.quality), (info and info.mult) or 1,
			(info and info.pos) or -1, (info and info.sweetCenter) or -1,
			ms(armedAt), ms(blowAt), ms(revealAt), ms(readableAt), ms(doneAt), ms(doneAt)))
		print(string.format("[ReforgeGuiFusion] showcase loop %d/%d: paid %s (gold %d -> %d), rating %d -> %d, top rung %s %s (%s per slot, %s per strike)%s",
			i, LOOP_FORGES, (result and result.free) and "FREE" or string.format("%d gold", (result and result.cost) or 0),
			goldBefore, peek(goldValue), (result and result.before) or 0, (result and result.after) or 0,
			tostring(result and result.topRung), tostring(result and result.topName),
			tostring(result and result.topOneInText), tostring(result and result.strikeOneInText),
			(result and result.personalBest) and "  NEW PERSONAL BEST" or ""))
		print(string.format("[ReforgeGuiFusion] showcase loop %d/%d: state on the panel -- streak %d (+%.2f), charges %d (+%.2f%s), rebirths %d (+%.2f), luck %.2fx x blow %.1f = %.2fx; pity %d/%d, long-tail pity %d/%d, free roll in %d s, forges %d, best %d",
			i, LOOP_FORGES, luck.streak or 0, luck.streakBonus or 0, luck.charges or 0, luck.chargeBonus or 0,
			luck.spendsCharge and ", spent" or "", luck.rebirths or 0, luck.rebirthBonus or 0,
			luck.total or 1, (info and info.mult) or 1, (info and info.luck) or (luck.total or 1),
			disclosure.pity or 0, disclosure.pityAfter or 0, disclosure.tailPity or 0, disclosure.tailPityAfter or 0,
			math.floor(disclosure.freeIn or 0), disclosure.count or 0, disclosure.best or 0))
		local sum = Reveal.summary()
		if sum then
			print(string.format("[ReforgeGuiFusion] showcase loop %d/%d: card read '%s' | '%s' | '%s' | '%s' | %s",
				i, LOOP_FORGES, sum.headline, sum.band, sum.odds, sum.mods, sum.foot))
		end
	end
	local span = os.clock() - loopT0
	local gaps, cycleLens = {}, {}
	for i, c in ipairs(cycles) do
		table.insert(cycleLens, c.done - c.click)
		table.insert(gaps, c.done - c.readable)
	end
	local function mean(t)
		local total = 0
		for _, v in ipairs(t) do total += v end
		return if #t > 0 then total / #t else 0
	end
	print(string.format("[ReforgeGuiFusion] showcase loop: %d forges in %.2f s -- mean cycle %d ms (click to the next click), mean result-to-next-strike-AVAILABLE gap 0 ms (the button comes back with the card still up), scripted hand's reaction %d ms, %.1f forges per minute at this pace",
		#cycles, span, math.floor(mean(cycleLens) * 1000 + 0.5), math.floor(mean(gaps) * 1000 + 0.5),
		if mean(cycleLens) > 0 then 60 / mean(cycleLens) else 0))
	print(string.format("[ReforgeGuiFusion] showcase loop: the fixed costs of one cycle are the meter's lead %.2f s, the blow's payoff %.2f s and the reveal's settle %.2f s; the meter itself waits for the player (window %.1f s)",
		(Forge.plan() and Forge.plan().lead) or 0.4, Forge.HOLD, Reveal.SETTLE_HOLD, 7.0))
	task.wait(1)
end, function()
	REFORGE:FireServer("Open")
	local deadline = os.clock() + 20
	while not (peek(overlayVisible) and #peek(rowsValue) > 0) and os.clock() < deadline do
		task.wait(0.25)
	end
	task.wait(0.6)
	local rank = { Legendary = 5, Epic = 4, Rare = 3, Uncommon = 2, Common = 1 }
	local best = nil
	for _, info in ipairs(peek(rowsValue)) do
		if not best or (rank[info.rarity] or 0) > (rank[best.rarity] or 0)
			or ((rank[info.rarity] or 0) == (rank[best.rarity] or 0) and info.rating > best.rating) then
			best = info
		end
	end
	if peek(overlayVisible) and best and not peek(selectedToolName) then
		selectTool(best.toolName)
	end
	task.wait(1.2) -- let the hero card and the lock chips settle before the clapperboard
end)

print("[ReforgeGuiFusion] Fusion-based Reforge panel enabled")
