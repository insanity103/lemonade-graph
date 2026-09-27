--// DailyStreak  (the 7-day login calendar: works out what a player may claim, and pays it)
-- Rules and rewards: ReplicatedStorage.Config.DailyConfig. Saved: StreakDay / StreakLastClaim
-- (SaveConfig.ATTRIBUTES). Published for the calendar (DailyStreakGui): StreakNext, StreakClaimable.
-- The server's clock is the only clock: a client can ask to claim, never say what day it is.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = ReplicatedStorage:WaitForChild("Config")
local DailyConfig = require(Config:WaitForChild("DailyConfig"))
local CodexConfig = require(Config:WaitForChild("CodexConfig"))
local GoldCurve = require(Config:WaitForChild("GoldCurve"))
local SpinPools = require(Config:WaitForChild("SpinPools"))
local BossSwordFactory = require(ServerScriptService:WaitForChild("BossSwordFactory"))

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local DAILY = remotes:WaitForChild("DailyAction")
local NOTIFY = remotes:WaitForChild("Notify")

local function today(): number
	return DailyConfig.DayNumber(os.time())
end

local function levelOf(player: Player): number
	local ls = player:FindFirstChild("leaderstats")
	local lv = ls and ls:FindFirstChild("Level")
	return lv and lv.Value or 1
end

-- The furthest built zone this player's level has opened: its wheel prices the tokens and its
-- pool deals the day-7 sword.
local function zoneOf(player: Player): string
	local level, best = levelOf(player), CodexConfig.Pages[1].zone
	for _, zone in ipairs(SpinPools.Order) do
		local pool = SpinPools.Get(zone)
		if pool and (pool.gate or 1) <= level and CodexConfig.PageFor(zone) then best = zone end
	end
	return best
end

local function publish(player: Player)
	local nextDay, claimable = DailyConfig.Next(player:GetAttribute("StreakLastClaim"), player:GetAttribute("StreakDay"), today())
	player:SetAttribute("StreakNext", nextDay)
	player:SetAttribute("StreakClaimable", claimable)
	player:SetAttribute("StreakZone", zoneOf(player))
end

-- What one day pays this player, in plain numbers (the calendar shows the same).
local function rewardFor(player: Player, day: number)
	local r = DailyConfig.Days[day]
	local zone = zoneOf(player)
	return {
		gold = r.killsGold and math.floor(r.killsGold * GoldCurve.PerKill(levelOf(player))) or 0,
		tokens = r.spins and r.spins * SpinPools.CostFor(zone, 1) or 0,
		sword = r.sword, zone = zone,
	}
end

local claiming = {}
DAILY.OnServerEvent:Connect(function(player: Player, action)
	if action ~= "Claim" or claiming[player] or player:GetAttribute("DataLoaded") ~= true then return end
	claiming[player] = true
	local day, claimable = DailyConfig.Next(player:GetAttribute("StreakLastClaim"), player:GetAttribute("StreakDay"), today())
	if not claimable then
		claiming[player] = nil
		NOTIFY:FireClient(player, "Today's reward is already claimed. Come back tomorrow!", "error")
		return
	end
	local r = rewardFor(player, day)
	-- Mark it claimed first: nothing below can be paid twice even if it errors halfway.
	player:SetAttribute("StreakDay", day)
	player:SetAttribute("StreakLastClaim", today())
	local parts = {}
	if r.gold > 0 then
		local ls = player:FindFirstChild("leaderstats")
		local gold = ls and ls:FindFirstChild("Gold")
		if gold then gold.Value += r.gold end
		table.insert(parts, string.format("%d gold", r.gold))
	end
	if r.tokens > 0 then
		player:SetAttribute("Tokens", (tonumber(player:GetAttribute("Tokens")) or 0) + r.tokens)
		table.insert(parts, string.format("%d tokens", r.tokens))
	end
	if r.sword then
		local ok, tool, _, fullName = pcall(BossSwordFactory.build, r.zone, {
			rarityFloor = r.sword, level = levelOf(player),
			slots = tonumber(player:GetAttribute("PrefixSlots")) or 1,
		})
		local backpack = player:FindFirstChildOfClass("Backpack")
		if ok and tool and backpack then
			tool.Parent = backpack
			table.insert(parts, fullName or tool.Name)
		end
	end
	publish(player)
	DAILY:FireClient(player, "Claimed", { day = day, text = table.concat(parts, " + ") })
	NOTIFY:FireClient(player, string.format("Day %d streak reward: %s", day, table.concat(parts, " + ")), "success")
	claiming[player] = nil
end)

-- The calendar asks for its numbers (what each day would pay this player right now).
DAILY.OnServerEvent:Connect(function(player: Player, action)
	if action ~= "Preview" then return end
	local days = {}
	for day = 1, #DailyConfig.Days do days[day] = rewardFor(player, day) end
	DAILY:FireClient(player, "Preview", days)
end)

local function onPlayer(player: Player)
	if player:GetAttribute("DataLoaded") ~= true then player:GetAttributeChangedSignal("DataLoaded"):Wait() end
	if not player.Parent then return end
	publish(player)
end
for _, player in Players:GetPlayers() do task.spawn(onPlayer, player) end
Players.PlayerAdded:Connect(onPlayer)
Players.PlayerRemoving:Connect(function(player) claiming[player] = nil end)

-- A session that runs past midnight UTC gets the new day's claim without rejoining.
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("DataLoaded") == true then publish(player) end
		end
	end
end)

print(string.format("[DailyStreak] %d-day login calendar live (day 7: %s sword)", #DailyConfig.Days,
	DailyConfig.Days[#DailyConfig.Days].sword or "no"))
