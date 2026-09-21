-- Script | ServerScriptService | Rebirth and skill respec through characters, without a shrine.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local layout = require(script.Parent:WaitForChild("WorldLayout"))
local RespecConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RespecConfig"))
local actors = require(script.Parent:WaitForChild("GameplayActors"))
if layout.BLANK_SLATE then return end
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local openRebirth = remotes:WaitForChild("RebirthStationOpen")
local notify = remotes:WaitForChild("Notify")
if layout.HUB.RebirthPosition then
	local rebirth = actors.create("Rebirth Keeper", layout.HUB.RebirthPosition, Color3.fromRGB(80, 130, 180),
		{ facing = layout.HUB.RebirthCFrame, subtitle = "Rebirth", outfit = "RebirthKeeper" })
	actors.prompt(rebirth, "Rebirth").Triggered:Connect(function(player)
		openRebirth:FireClient(player) -- The existing RebirthSystem validates and performs the purchase.
	end)
end

if not layout.HUB.RespecPosition then return end -- map lacks the marker: respec idle
local respec = actors.create("Skill Trainer", layout.HUB.RespecPosition, Color3.fromRGB(120, 80, 150),
	{ facing = layout.HUB.RespecCFrame, subtitle = "Reset skill points", outfit = "Trainer" })
local cooldowns = {}
local quotes = {} -- [player] = { cost, points, at } -- the price this player was last QUOTED

-- THE RESPEC IS PRICED BY THE SIZE OF THE RESET (Config.RespecConfig owns the formula and the
-- reasoning). It used to be a flat 200 + 100 per rebirth: measured, that was 2.78 gold a point
-- for a level-10 player fixing a mistake and 0.25 a point -- 0.9 seconds of income, 0.01 kills --
-- for a level-100 player handing back 792 points. Now it is
--   4 gold x points refunded x GoldCurve.BandMultiplier(level) x (1 + 0.5 x rebirths)
-- so it climbs with what is being reset AND with the income of the band doing the resetting.
--
-- The prompt states the rate, and pressing it QUOTES the exact price for this player and this
-- reset; a second press inside RespecConfig.CONFIRM_WINDOW seconds is the player agreeing to it.
-- A proximity prompt's text is one shared string for everybody in the server, so it cannot carry
-- a per-player number -- the quote is how the exact price reaches the player who is about to pay
-- it, before any gold moves. The refusal message carries the same number.
local ATTRIBUTES = RespecConfig.ATTRIBUTES
local PROMPT_TEXT = string.format("Reset Skills (%d gold a point, x your level band)",
	RespecConfig.GOLD_PER_POINT)
actors.prompt(respec, PROMPT_TEXT).Triggered:Connect(function(player)
	if player:GetAttribute("DataLoaded") ~= true then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - respec.PrimaryPart.Position).Magnitude > RespecConfig.RANGE then return end
	local now = os.clock()
	if now - (cooldowns[player] or -math.huge) < RespecConfig.COOLDOWN then return end
	cooldowns[player] = now
	local spent = RespecConfig.PointsSpent(player)
	if spent <= 0 then
		notify:FireClient(player, "You have no spent skill points to reset.", "error")
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	local gold = stats and stats:FindFirstChild("Gold")
	local level = stats and stats:FindFirstChild("Level")
	local cost = RespecConfig.Cost(spent, level and level.Value or 1, player:GetAttribute("Rebirths") or 0)
	if not gold then return end
	if gold.Value < cost then
		quotes[player] = nil
		notify:FireClient(player, string.format("Resetting %d skill points costs %d gold (%.1f a point). You have %d.",
			spent, cost, cost / spent, gold.Value), "error")
		return
	end
	-- First press: quote the price. Second press inside the window at the same price: do it.
	local quote = quotes[player]
	if not (quote and quote.cost == cost and quote.points == spent
		and now - quote.at <= RespecConfig.CONFIRM_WINDOW) then
		quotes[player] = { cost = cost, points = spent, at = now }
		notify:FireClient(player, string.format("%s. Press again within %d s to pay.",
			RespecConfig.PriceLine(spent, cost), RespecConfig.CONFIRM_WINDOW), "info")
		return
	end
	quotes[player] = nil
	gold.Value -= cost
	for _, attr in ipairs(ATTRIBUTES) do player:SetAttribute(attr, 0) end
	player:SetAttribute("SkillPoints", (player:GetAttribute("SkillPoints") or 0) + spent)
	notify:FireClient(player, string.format("Refunded %d skill points for %d gold (%.1f a point).",
		spent, cost, cost / spent), "success")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = 100 * (player:GetAttribute("RebirthHealthMult") or 1)
			+ (player:GetAttribute("RebirthFlatHealth") or 0)
		humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth)
	end
end)
Players.PlayerRemoving:Connect(function(player) cooldowns[player], quotes[player] = nil, nil end)
print(string.format("[GameplayServices] Rebirth and skill respec ready (%s mode; respec %d gold a point "
	.. "x level band x rebirths -- Lv10/72pts %d, Lv50/392pts %d, Lv100/792pts %d gold)",
	layout.MODE, RespecConfig.GOLD_PER_POINT,
	RespecConfig.Cost(72, 10, 0), RespecConfig.Cost(392, 50, 0), RespecConfig.Cost(792, 100, 0)))
