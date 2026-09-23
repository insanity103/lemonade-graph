-- Script | ServerScriptService | Town stations: the Spin Wheel, and rebirth and skill respec through characters.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local layout = require(script.Parent:WaitForChild("WorldLayout"))
local RespecConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("RespecConfig"))
local actors = require(script.Parent:WaitForChild("GameplayActors"))
if layout.BLANK_SLATE then return end
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

-- ==============================================================================
-- THE TOWN SPIN WHEEL  (tokens in, a sword out, and nothing a client decides)
-- ==============================================================================
-- (Lives here, in the town services script, beside the other hub stations.)
-- The wheel stands in the hub (WorldLayout.HUB.SpinCFrame; built by GameplayActors.spinWheel).
-- Walk up, read your pool on its board (ReplicatedStorage.SpinStation prints Config.SpinPools.Odds, the very
-- list rolled here), press E to spin. Every rule is enforced HERE, at the moment of the spin:
--   * TOWN ONLY. The player must be standing inside the town safe zone (SafeHub) and within
--     SpinPools.SPIN_RANGE studs of the wheel. Tokens are earned in the field and spent in town.
--   * NEVER MID-FIGHT. A spin is refused for SpinPools.COMBAT_LOCK seconds after any hit given or
--     taken (the "CombatAt" stamp SwordSystem and EnemyCombat write on every landed hit). Enemies
--     cannot enter the safe zone, so this only bites a player who fought at the gate and ran in.
--   * THE PRICE. SpinPools.CostFor(area, step) tokens per spin (the pool the spin will roll; deeper
--     pools cost more), read from the saved `Tokens` attribute.
--     The client never sends a price, a pool or a count it may not have.
--   * MULTI-SPIN. One press spins `MultiSpin` times (saved attribute; 0 = not unlocked yet, bought
--     with gold at the upgrade shop). Refused while locked.
--   * ONE AT A TIME. The next spin waits SpinPools.SPIN_SECONDS for the wheel to stop.
-- The roll is SpinService.Roll (area + depth step + level caps) and the sword is SpinService.Grant
-- (BossSwordFactory, prefix rolled at the player's level and slots). Every sword is built BEFORE a
-- single token is taken, so a failed build can never eat a spin.
local function startSpinStation()
	local RunService = game:GetService("RunService")
	if not layout.HUB.SpinCFrame then
		return
	end
	local SafeHub = require(script.Parent:WaitForChild("SafeHub"))
	local SpinService = require(script.Parent:WaitForChild("SpinService"))
	local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
	local SpinPools = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("SpinPools"))
	local WeaponModifiers = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponModifiers"))

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local SPIN_ACTION = remotes:WaitForChild("SpinAction")
	local NOTIFY = remotes:WaitForChild("Notify")

	local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UpgradeConfig"))
	local bonusRng = Random.new()

	local MAX_MULTI = 10 -- the most spins one press may ever buy, whatever a save says

	-- ---------------------------------------------------------------- the station
	local station = actors.spinWheel(layout.HUB.SpinCFrame)
	local promptPart = station:WaitForChild("PromptPart") :: BasePart

	local function makePrompt(name, action, key, order)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = name
		prompt.ActionText = action
		prompt.ObjectText = "Spin Wheel"
		prompt.KeyboardKeyCode = key
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = SpinPools.SPIN_RANGE - 2 -- the server allows a little slack
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Custom -- ReplicatedStorage.SpinStation draws the big key cap
		prompt.UIOffset = Vector2.new(0, order * 110)
		prompt:SetAttribute("SpinPrompt", name)
		prompt.Parent = promptPart
		return prompt
	end
	local singlePrompt = makePrompt("SpinOne", "Spin", Enum.KeyCode.E, 0)
	-- The multi prompt exists for everybody; each client hides it until its player has unlocked it,
	-- and the server refuses it while locked anyway.
	local multiPrompt = makePrompt("SpinMulti", "Multi-spin", Enum.KeyCode.F, 1)

	-- ---------------------------------------------------------------- rules
	local busyUntil = {} -- [player] = os.clock() the current spin finishes

	local function tokensOf(player): number
		return math.max(0, math.floor(tonumber(player:GetAttribute("Tokens")) or 0))
	end

	local function multiOf(player): number
		local n = math.floor(tonumber(player:GetAttribute("MultiSpin")) or 0)
		return if n >= 2 then math.min(n, MAX_MULTI) else 0
	end

	local function stationDistance(player): number
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then return math.huge end
		local here = promptPart.Position
		return Vector3.new(root.Position.X - here.X, 0, root.Position.Z - here.Z).Magnitude
	end

	-- Seconds of combat lock left (0 = free to spin).
	local function combatLockLeft(player): number
		local at = tonumber(player:GetAttribute("CombatAt"))
		if not at then return 0 end
		return math.max(0, SpinPools.COMBAT_LOCK - (workspace:GetServerTimeNow() - at))
	end

	-- Tokens one spin costs this player right now: the price of the pool their spin rolls.
	local function spinCost(player): number
		local zone, step = SpinService.PoolFor(player, nil)
		return SpinPools.CostFor(zone, step)
	end

	local function refuse(player, code, message)
		SPIN_ACTION:FireClient(player, "Refused", { code = code, message = message, tokens = tokensOf(player) })
		NOTIFY:FireClient(player, message, "error")
		return nil
	end

	-- Why this player may not spin `count` times right now, or nil.
	local function check(player, count)
		if player:GetAttribute("DataLoaded") ~= true or not PlayerDataService.IsReady(player) then
			return "loading", "Your data is still loading."
		end
		if not SafeHub.playerInside(player) then
			return "town", "The Spin Wheel only turns in town."
		end
		if stationDistance(player) > SpinPools.SPIN_RANGE then
			return "far", "Step up to the Spin Wheel to spin."
		end
		local lock = combatLockLeft(player)
		if lock > 0 then
			return "combat", string.format("Catch your breath first: %d s since your last fight.",
				math.ceil(SpinPools.COMBAT_LOCK - lock))
		end
		if os.clock() < (busyUntil[player] or 0) then
			return "busy", "The wheel is still spinning."
		end
		local cost = spinCost(player) * count
		local have = tokensOf(player)
		if have < cost then
			return "tokens", string.format("Not enough tokens: a spin costs %d, you have %d. Defeat foes to earn more.",
				cost, have)
		end
		if not player:FindFirstChildOfClass("Backpack") then
			return "loading", "Your inventory is not ready yet."
		end
		return nil
	end

	-- ---------------------------------------------------------------- the spin
	-- rng: optional uniform [0,1) source for the roll (Studio staging only; never set on a live server):
	-- a function for every roll, or a table { [i] = function } pinning only roll i of a multi-spin.
	local function spin(player, count, rng)
		count = math.max(1, math.floor(count))
		local code, message = check(player, count)
		if code then
			return refuse(player, code, message)
		end
		-- Roll and build every sword first. Lucky Spins (a gold upgrade, Config.UpgradeConfig): each
		-- PAID spin has BonusChance odds of paying one extra sword from the same pool for free; the
		-- bonus is decided here, by the server's RNG, and built before any token is taken too.
		local bonusChance = UpgradeConfig.BonusChance(player:GetAttribute("BonusSpinLevel"))
		local bonus = 0
		for _ = 1, count do
			if bonusChance > 0 and bonusRng:NextNumber() < bonusChance then bonus += 1 end
		end
		local rolled = {}
		for i = 1, count + bonus do
			local rollRng = if typeof(rng) == "table" then rng[i] else rng
			local row, zone, step, rows = SpinService.Roll(player, nil, rollRng)
			if not row then
				for _, r in ipairs(rolled) do r.tool:Destroy() end
				return refuse(player, "pool", "No pool is open to you yet.")
			end
			local ok, tool, mods, fullName, weaponData = pcall(SpinService.Grant, player, row)
			if not ok or not tool then
				warn(string.format("[SpinSystem] build failed for %s (%s): %s", player.Name, row.sword, tostring(tool)))
				for _, r in ipairs(rolled) do r.tool:Destroy() end
				return refuse(player, "build", "The wheel jammed. Try again in a moment.")
			end
			rolled[i] = { row = row, zone = zone, step = step, rows = rows, tool = tool, mods = mods,
				fullName = fullName, weaponData = weaponData, bonus = i > count }
		end
		-- Then pay, then hand over.
		local cost = SpinPools.CostFor(rolled[1].zone, rolled[1].step) * count
		local after = tokensOf(player) - cost
		player:SetAttribute("Tokens", after)
		busyUntil[player] = os.clock() + SpinPools.SPIN_SECONDS
		local backpack = player:FindFirstChildOfClass("Backpack")
		local results = {}
		local firsts = PlayerDataService.GetField(player, "bossFirstDrops")
		if typeof(firsts) ~= "table" then firsts = {} end
		-- Chase swords this player had pulled BEFORE this spin: the rest stay "??" in the reel.
		local foundBefore = player:GetAttribute("SwordsFound")
		local newlyFound = {}
		-- The prefix odds the popup prints are the ones the factory rolled with (same rarity, level, luck).
		local level = SpinService.PlayerLevel(player)
		local luck = WeaponModifiers.LuckFrom(0, tonumber(player:GetAttribute("Rebirths")) or 0,
			tonumber(player:GetAttribute("MilestoneLuck")) or 0)
		for i, r in ipairs(rolled) do
			r.tool.Parent = backpack
			if string.sub(r.row.poolKey, 1, 5) == "Boss_" or not SpinPools.ByZone[r.row.poolKey] then
				firsts[r.row.poolKey] = true -- a boss-pool sword in hand settles its OBTAIN_POOL quest
			end
			local mods = {}
			local tierOdds = WeaponModifiers.TierOdds(r.row.rarity, level, luck)
			for _, mod in ipairs(r.mods or {}) do
				table.insert(mods, { name = mod.name, category = mod.category, tier = mod.tier,
					rung = mod.rung or (WeaponModifiers.Rungs[mod.tier] and WeaponModifiers.Rungs[mod.tier].name) or nil,
					p = tierOdds[mod.tier], tag = mod.tag, chase = mod.chase })
			end
			-- The rarities in the pool this sword came from with their real combined odds, commonest
			-- rarity first (the popup's flicker only ever shows what this spin could have landed).
			-- Plus every sword this spin could have landed with its own real odds (the popup's
			-- spinning phase cycles these names, never anything outside the pool).
			local rarities, byRarity, pool = {}, {}, {}
			for _, row in ipairs(r.rows or {}) do
				if row.p > 0 then
					local hidden = row.tag == "Chase" and not SpinPools.SwordFound(foundBefore, row.sword)
					table.insert(pool, { sword = hidden and "??" or row.sword, rarity = row.rarity, p = row.p })
					local entry = byRarity[row.rarity]
					if not entry then
						entry = { rarity = row.rarity, p = 0 }
						byRarity[row.rarity] = entry
						table.insert(rarities, entry)
					end
					entry.p += row.p
				end
			end
			table.sort(rarities, function(a, b)
				return (SpinPools.RARITY_ORDER[a.rarity] or 0) < (SpinPools.RARITY_ORDER[b.rarity] or 0)
			end)
			results[i] = { sword = r.row.sword, fullName = r.fullName, rarity = r.row.rarity, p = r.row.p,
				tag = r.row.tag, poolKey = r.row.poolKey, zone = r.zone, step = r.step, mods = mods,
				baseMult = r.weaponData and r.weaponData.baseMult or nil, poolRarities = rarities,
				pool = pool, bonus = r.bonus or nil, ultra = r.row.ultra or nil,
				great = r.row.great or nil }
			if r.row.tag == "Chase" and not SpinPools.SwordFound(player, r.row.sword) then
				newlyFound[r.row.sword] = true
				local list = player:GetAttribute("SwordsFound")
				player:SetAttribute("SwordsFound", (typeof(list) == "string" and list ~= "") and (list .. "," .. r.row.sword)
					or r.row.sword)
			end
		end
		PlayerDataService.SetField(player, "bossFirstDrops", firsts)
		for _, r in ipairs(results) do -- Lemonade / Great prefixes: counted now, shouted after the reveal
			SpinService.CreditPrefixes(player, r.mods, r.fullName, SpinPools.SPIN_SECONDS + 1)
		end
		-- An area's ultra-rare is the loudest thing the wheel does: the whole server hears it, once the
		-- roller's own reveal has landed. Past 1 in 1,000 (Colossus Heart, Thunderglass, Archon's
		-- Verdict, Astral Eclipse) it is SERVER NEWS. A boss step's GREAT pull gets its own shout.
		for _, r in ipairs(results) do
			local pool = SpinPools.Get(r.zone)
			local message, kind = nil, nil
			if r.ultra then
				local news = (r.p or 1) <= SpinPools.NEWS_P
				message = string.format("%s %s pulled the %s from the %s wheel (%s)%s",
					news and "\u{1F4E3} SERVER NEWS! \u{1F34B} JACKPOT!" or "\u{1F34B} JACKPOT!",
					player.DisplayName, r.fullName or r.sword, pool and pool.name or tostring(r.zone),
					WeaponModifiers.OneInText(r.p), newlyFound[r.sword] and " -- their first!" or "")
				kind = "lemonade"
			elseif r.great then
				message = string.format("GREAT! %s pulled the %s from the %s wheel (%s)", player.DisplayName,
					r.fullName or r.sword, pool and pool.name or tostring(r.zone), WeaponModifiers.OneInText(r.p))
				kind = "chase"
			end
			if message then
				task.delay(SpinPools.SPIN_SECONDS + 1, function()
					NOTIFY:FireAllClients(message, kind)
				end)
				print("[SpinSystem] " .. message)
			end
		end
		PlayerDataService.SetField(player, "spinCount",
			(tonumber(PlayerDataService.GetField(player, "spinCount")) or 0) + count)
		PlayerDataService.MarkDirty(player)
		SPIN_ACTION:FireClient(player, "Result", {
			results = results, tokens = after, cost = cost, count = count, bonus = bonus,
			seconds = SpinPools.SPIN_SECONDS,
		})
		local names = {}
		for _, r in ipairs(results) do
			table.insert(names, string.format("[%s] %s %.2f%%", r.rarity, r.fullName, r.p * 100))
		end
		print(string.format("[SpinSystem] %s spun x%d (+%d bonus) at %s step %d for %d tokens (%d left): %s",
			player.Name, count, bonus, tostring(results[1].zone), results[1].step or 0, cost, after,
			table.concat(names, "; ")))
		return results
	end

	-- Studio only: a capture stage may pin the uniform draw of the NEXT single spin (one roll, then
	-- cleared). Never set outside Studio: only the GuiShowcase stages below write it.
	local studioForcedDraw = {}
	singlePrompt.Triggered:Connect(function(player)
		local forced = RunService:IsStudio() and studioForcedDraw[player] or nil
		studioForcedDraw[player] = nil
		spin(player, 1, forced and function() return forced end or nil)
	end)
	-- Studio only: a capture stage may pin ONE roll of the next multi-spin ({ index, draw }).
	local studioForcedMulti = {}
	multiPrompt.Triggered:Connect(function(player)
		local n = multiOf(player)
		if n < 2 then
			refuse(player, "multi", "Multi-spin is not unlocked yet: buy it with gold at the upgrade shop.")
			return
		end
		local forced = RunService:IsStudio() and studioForcedMulti[player] or nil
		studioForcedMulti[player] = nil
		local rng = nil
		if forced then
			rng = { [forced.index] = function() return forced.draw end }
		end
		spin(player, n, rng)
	end)

	-- Board buttons (tap / click) take the same path as the prompts. Only "one" or "multi" is read.
	SPIN_ACTION.OnServerEvent:Connect(function(player, action, which)
		if action ~= "Spin" then return end
		if which == "multi" then
			local n = multiOf(player)
			if n < 2 then
				refuse(player, "multi", "Multi-spin is not unlocked yet: buy it with gold at the upgrade shop.")
				return
			end
			spin(player, n)
		else
			spin(player, 1)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		busyUntil[player] = nil
		studioForcedDraw[player] = nil
		studioForcedMulti[player] = nil
	end)

	print(string.format("[SpinSystem] Spin Wheel up at %s (%s mode): %d tokens a spin at the first trailhead (rising per pool), town only, %d s combat lock",
		tostring(layout.HUB.SpinPosition), layout.MODE, SpinPools.CostFor(SpinPools.Order[1], 1), SpinPools.COMBAT_LOCK))

	-- ==============================================================================
	-- STUDIO-ONLY MOTION SHOWCASES: "Motion:SpinStation" and "Motion:SpinPopup" (inert outside Studio)
	-- ==============================================================================
	-- The player starts out on the plaza, well back from the wheel, walks up to it on their own legs
	-- (its pool board fades in as they come near), stops in prompt range and presses E: the REAL
	-- prompt, pressed by the client (ReplicatedStorage.SpinStation, attribute GuiShowcaseSpinPress), fires the
	-- real Triggered handler above, so the check, the token charge, the roll (SpinService, real RNG,
	-- nothing forced), the sword build and the result all run their live code paths. The stage grants
	-- the Studio player test tokens and, if needed, the level that unlocks every row of their current
	-- pool step (PlayerDataService refuses to save while a showcase is set). SpinPopup is the same
	-- walk-up with the live follow camera and HUD, and its one roll pinned to the chase row (the
	-- only forced draw anywhere, Studio only) so the popup's rare reveal is filmed.
	if RunService:IsStudio() then
		local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))
		-- opts.lockCamera: hold the framed shot on the wheel and its board (SpinStation). Without it
		-- the player's own follow camera and the whole HUD stay live (SpinPopup: the popup must be
		-- judged over real play). opts.forceChase: pin THIS one roll onto the pool's chase row.
		local function walkUpAndSpin(ctx, opts)
			local player = ctx.player
			do -- enough for this press at the player's own pool price, plus a little
				local zone, step = SpinService.PoolFor(player, nil)
				player:SetAttribute("Tokens", SpinPools.CostFor(zone, step) * (opts.multi or 1) + 60)
			end
			if opts.multi then
				-- Studio session only (PlayerDataService refuses to save while a showcase is set):
				-- multi-spin unlocked at x3, the way the upgrade shop will sell it.
				player:SetAttribute("MultiSpin", opts.multi)
			end
			player:SetAttribute("CombatAt", nil)
			-- Level (Studio session only, never saved): raised, if needed, to the highest minLevel in the
			-- player's current pool step, so no row is locked and the board and face show the whole
			-- pool, chase included, exactly as a player of that level rolls it.
			local stats = player:FindFirstChild("leaderstats")
			local lv = stats and stats:FindFirstChild("Level")
			local pool = SpinPools.Get(player:GetAttribute("SpinZone"))
			local step = SpinPools.ClampStep(player:GetAttribute("SpinStep"))
			if lv and pool then
				local need = 1
				for _, entry in ipairs(pool.entries) do
					if (entry.weights[step] or 0) > 0 then need = math.max(need, entry.minLevel) end
				end
				if lv.Value < need then lv.Value = need end
			end
			local wheel = layout.HUB.SpinCFrame
			-- Start off to the side, outside the board's pop-in range, and walk in to stand beside
			-- the key cap (not behind it), facing the wheel.
			local start = wheel:PointToWorldSpace(Vector3.new(-21, 3, -13))
			local stop = wheel:PointToWorldSpace(Vector3.new(-3.2, 3, -9.5))
			if opts.standAtWheel then
				-- Already at the wheel, facing it: nothing moves on screen until the spin itself.
				local face = wheel:PointToWorldSpace(Vector3.new(0, 3, 0))
				ctx.place(CFrame.lookAt(stop, Vector3.new(face.X, stop.Y, face.Z)))
			else
				ctx.place(CFrame.lookAt(start, Vector3.new(stop.X, start.Y, stop.Z)))
			end
			-- Camera: out in front, raised, centred between the wheel and its board, close enough
			-- that the odds on the face and the board read, the way PS99 films its eggs.
			local eye = wheel:PointToWorldSpace(Vector3.new(-16.5, 11.5, -21))
			local focus = wheel:PointToWorldSpace(Vector3.new(-16.5, 9.5, -1))
			if opts.lockCamera then
				ctx.camera(CFrame.lookAt(eye, focus))
			end
			task.wait(2.5)
			print(string.format("[GuiShowcase] %s before: Tokens=%s Level=%s zone=%s step=%s", opts.name,
				tostring(player:GetAttribute("Tokens")), tostring(SpinService.PlayerLevel(player)),
				tostring(player:GetAttribute("SpinZone")), tostring(player:GetAttribute("SpinStep"))))
			ctx.clapper() -- 0.25 s flash, then 0.5 s
			if opts.standAtWheel then
				-- already beside the key cap: press straight after the clapper, so the popup's whole
				-- reveal (in, spin, land, hold, out) sits in the few seconds after it
			else
				ctx.walkTo(stop)
			end
			-- ~20 studs at walk speed 16: beside the key cap after ~1.3 s.
			local deadline = os.clock() + 4
			while os.clock() < deadline and (ctx.root.Position - stop) * Vector3.new(1, 0, 1) ~= Vector3.zero
				and ((ctx.root.Position - stop) * Vector3.new(1, 0, 1)).Magnitude > 1.2 do
				task.wait(0.05)
			end
			if not opts.standAtWheel then
				task.wait(0.3) -- the key cap has popped in and settled
			end
			if opts.forceChase then
				-- STUDIO CAPTURE ONLY: pin the next single spin's uniform draw to the middle of the
				-- pool's chase (rarest) row, so the popup's rare-pull reveal is what gets filmed.
				-- The real prompt, remote, token charge, factory and prefix roll still run.
				local _, _, rows = SpinService.PoolFor(player, nil)
				local acc, draw = 0, nil
				for _, row in ipairs(rows or {}) do
					if row.p > 0 then
						if row.tag == "Chase" then draw = acc + row.p * 0.5 end
						acc += row.p
					end
				end
				if opts.multi then
					-- only roll #opts.forceIndex of the batch is pinned; the other rolls are real RNG
					studioForcedMulti[player] = draw and { index = opts.forceIndex or 1, draw = draw } or nil
				else
					studioForcedDraw[player] = draw
				end
				print(string.format("[GuiShowcase] %s: roll %d forced to draw %s (chase row)", opts.name,
					opts.forceIndex or 1, tostring(draw)))
			end
			player:SetAttribute("GuiShowcaseSpinWhich", opts.multi and "multi" or "one")
			player:SetAttribute("GuiShowcaseSpinPress", os.clock())
			task.wait(SpinPools.SPIN_SECONDS + 5)
			print(string.format("[GuiShowcase] %s after: Tokens=%s", opts.name, tostring(player:GetAttribute("Tokens"))))
			player:SetAttribute("GuiShowcaseSpinPress", nil)
		end
		GuiShowcase.stage("SpinStation", function(ctx)
			walkUpAndSpin(ctx, { name = "SpinStation", lockCamera = true })
		end)
		GuiShowcase.stage("SpinPopup", function(ctx)
			walkUpAndSpin(ctx, { name = "SpinPopup", lockCamera = false, forceChase = true, standAtWheel = true })
		end)
		-- "Motion:MultiSpin": the same stand-at-the-wheel shot, x3 multi-spin unlocked for the session, the
		-- real F prompt pressed; roll 2 of the 3 is pinned to the chase row so the best-pull celebration
		-- is filmed, rolls 1 and 3 are real RNG.
		GuiShowcase.stage("MultiSpin", function(ctx)
			walkUpAndSpin(ctx, { name = "MultiSpin", lockCamera = false, forceChase = true, standAtWheel = true,
				multi = 3, forceIndex = 2 })
		end)
	end
end
startSpinStation()

-- ==============================================================================
-- THE UPGRADE STALL  (gold in, a permanent wheel upgrade out; the server owns every price and gate)
-- ==============================================================================
-- A market stall beside the Spin Wheel (same facing, 17 studs to its right) with the Upgrade Keeper
-- behind the counter. Press E to open the shop (ReplicatedStorage.UpgradeShop draws it); every
-- purchase comes back here as UpgradeAction("Buy", id) and is checked against Config.UpgradeConfig:
--   * TOWN ONLY, AT THE STALL. Inside the safe zone and within UpgradeConfig.RANGE of the counter.
--   * IN ORDER. Only the next tier of an upgrade is ever for sale; the client never names a tier.
--   * THE GATES. The tier's level (and rebirth) gate, read from the player's own stats.
--   * THE PRICE. The tier's price, read from UpgradeConfig, against leaderstats.Gold.
-- Then the gold is taken, the saved attribute raised (BonusSpinLevel / MultiSpin / PrefixSlots:
-- all SaveConfig.ATTRIBUTES, so the next save carries them) and the whole new shop state returned.
local function startUpgradeShop()
	local RunService = game:GetService("RunService")
	if not layout.HUB.SpinCFrame then
		return
	end
	local SafeHub = require(script.Parent:WaitForChild("SafeHub"))
	local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
	local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UpgradeConfig"))
	local UPGRADE_ACTION = remotes:WaitForChild("UpgradeAction")
	local NOTIFY = remotes:WaitForChild("Notify")

	local stallCFrame = layout.HUB.SpinCFrame * CFrame.new(17, 0, 1) -- far enough that its E never overlaps the wheel's E
	local stall = actors.upgradeStall(stallCFrame)
	local counter = stall:WaitForChild("Counter") :: BasePart
	local keeper = actors.create("Upgrade Keeper", stallCFrame:PointToWorldSpace(Vector3.new(0, 0.2, 1.4)),
		Color3.fromRGB(0, 176, 166), { facing = stallCFrame, subtitle = "Wheel Upgrades", outfit = "Gatherer" })
	keeper:SetAttribute("UpgradeKeeper", true)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UpgradePrompt"
	prompt.ActionText = "Upgrades"
	prompt.ObjectText = "Upgrade Stall"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = UpgradeConfig.RANGE - 2
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	local function stats(player)
		local ls = player:FindFirstChild("leaderstats")
		local gold = ls and ls:FindFirstChild("Gold")
		local level = ls and ls:FindFirstChild("Level")
		return gold, level and level.Value or 1, math.floor(tonumber(player:GetAttribute("Rebirths")) or 0)
	end
	local function stateFor(player)
		local gold, level, rebirths = stats(player)
		return UpgradeConfig.StateFor(player, level, rebirths, gold and gold.Value or 0)
	end
	local function distance(player): number
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then return math.huge end
		local d = root.Position - counter.Position
		return Vector3.new(d.X, 0, d.Z).Magnitude
	end
	local function atStall(player): (boolean, string?)
		if player:GetAttribute("DataLoaded") ~= true or not PlayerDataService.IsReady(player) then
			return false, "Your data is still loading."
		end
		if not SafeHub.playerInside(player) then return false, "The Upgrade Stall only trades in town." end
		if distance(player) > UpgradeConfig.RANGE then return false, "Step up to the Upgrade Stall." end
		return true
	end
	local function refuse(player, code, message)
		UPGRADE_ACTION:FireClient(player, "Refused", { code = code, message = message, state = stateFor(player) })
		NOTIFY:FireClient(player, message, "error")
	end

	local lastBuy = {} -- [player] = os.clock(): one purchase per 0.25 s, whatever a client sends

	local function buy(player, id)
		if typeof(id) ~= "string" or not UpgradeConfig.Defs[id] then return end
		local now = os.clock()
		if now - (lastBuy[player] or -math.huge) < 0.25 then return end
		lastBuy[player] = now
		local ok, why = atStall(player)
		if not ok then return refuse(player, "far", why) end
		local def = UpgradeConfig.Defs[id]
		local gold, level, rebirths = stats(player)
		if not gold then return refuse(player, "loading", "Gold data error.") end
		local owned = UpgradeConfig.LevelOf(id, player)
		local tierIndex = owned + 1
		local code, reason = UpgradeConfig.Blocker(id, tierIndex, owned, level, rebirths, gold.Value)
		if code then
			local tier = def.tiers[tierIndex]
			if code == "gold" and tier then
				reason = string.format("%s costs %d gold; you have %d.", def.name, tier.price, gold.Value)
			end
			return refuse(player, code, reason)
		end
		local tier = def.tiers[tierIndex]
		local before = gold.Value
		gold.Value -= tier.price
		player:SetAttribute(def.attr, tier.value)
		PlayerDataService.MarkDirty(player)
		UPGRADE_ACTION:FireClient(player, "Bought", {
			id = id, tier = tierIndex, price = tier.price, goldBefore = before, goldAfter = gold.Value,
			effect = UpgradeConfig.EffectText(id, tierIndex), state = stateFor(player),
		})
		print(string.format("[UpgradeShop] %s bought %s tier %d/%d for %d gold (%d -> %d): %s", player.Name, id,
			tierIndex, #def.tiers, tier.price, before, gold.Value, UpgradeConfig.EffectText(id, tierIndex)))
	end

	local function openFor(player)
		local ok, why = atStall(player)
		if not ok then
			NOTIFY:FireClient(player, why, "error")
			print("[UpgradeShop] open refused for " .. player.Name .. ": " .. tostring(why))
			return
		end
		UPGRADE_ACTION:FireClient(player, "Open", stateFor(player))
		print("[UpgradeShop] shop opened for " .. player.Name)
	end
	prompt.Triggered:Connect(openFor)
	UPGRADE_ACTION.OnServerEvent:Connect(function(player, action, id)
		if action == "Buy" then
			buy(player, id)
		elseif action == "State" then
			if RunService:IsStudio() and id == "showcase" then
				print("[UpgradeShop] showcase client armed for " .. player.Name)
			end
			UPGRADE_ACTION:FireClient(player, "State", stateFor(player))
		end
	end)
	Players.PlayerRemoving:Connect(function(player) lastBuy[player] = nil end)

	local prices = {}
	for _, id in ipairs(UpgradeConfig.ORDER) do
		local list = {}
		for _, tier in ipairs(UpgradeConfig.Defs[id].tiers) do table.insert(list, tostring(tier.price)) end
		table.insert(prices, id .. " " .. table.concat(list, "/"))
	end
	print("[UpgradeShop] Upgrade Stall up beside the wheel: " .. table.concat(prices, "; "))

	-- ==========================================================================
	-- STUDIO-ONLY MOTION SHOWCASE: "Motion:UpgradeShop" (inert outside Studio)
	-- ==========================================================================
	-- The Studio player (level 6, 1,085 gold, Lucky Spins tier 1 owned, multi-spin locked: set for
	-- the session only, PlayerDataService refuses to save while a showcase is set) starts a few
	-- steps from the stall, walks up, and the client presses the REAL prompt (the Triggered handler
	-- above sends the real state), then clicks the REAL buy button for Lucky Spins tier 2: the
	-- remote, the checks, the gold charge and the attribute all run their live code. No RNG is
	-- involved in a purchase, so nothing is forced.
	if RunService:IsStudio() then
		local GuiShowcase = require(ReplicatedStorage:WaitForChild("GuiShowcase"))
		GuiShowcase.stage("UpgradeShop", function(ctx)
			local player = ctx.player
			local gold, _, _ = stats(player)
			local ls = player:FindFirstChild("leaderstats")
			local lv = ls and ls:FindFirstChild("Level")
			if lv and lv.Value < 6 then lv.Value = 6 end
			if gold then gold.Value = 1085 end
			player:SetAttribute("BonusSpinLevel", 1)
			player:SetAttribute("MultiSpin", 0)
			player:SetAttribute("PrefixSlots", 1)
			player:SetAttribute("CombatAt", nil)
			local start = stallCFrame:PointToWorldSpace(Vector3.new(-3, 3, -13))
			local stop = stallCFrame:PointToWorldSpace(Vector3.new(-1.5, 3, -6))
			local face = stallCFrame:PointToWorldSpace(Vector3.new(0, 3, 0))
			ctx.place(CFrame.lookAt(start, Vector3.new(face.X, start.Y, face.Z)))
			task.wait(2.5)
			ctx.clapper()
			ctx.walkTo(stop)
			local deadline = os.clock() + 3
			while os.clock() < deadline and ((ctx.root.Position - stop) * Vector3.new(1, 0, 1)).Magnitude > 1.2 do
				task.wait(0.05)
			end
			-- the prompt's own Triggered handler (the client cannot fire a prompt it has not been
			-- shown yet, and the stall's prompt shares E with the wheel's)
			openFor(player)
			task.wait(1.4)
			player:SetAttribute("GuiShowcaseUpgradeBuy", "LuckySpins")
			task.wait(5)
			print(string.format("[GuiShowcase] UpgradeShop after: Gold=%s BonusSpinLevel=%s",
				tostring(gold and gold.Value), tostring(player:GetAttribute("BonusSpinLevel"))))
			player:SetAttribute("GuiShowcaseUpgradeBuy", nil)
		end)
	end
end
startUpgradeShop()

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
