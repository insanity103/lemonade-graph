local ReplicatedStorage = game:GetService("ReplicatedStorage")

local tool = script.Parent
local handle = tool:WaitForChild("Handle")
-- Boss/merchant swords use a MeshPart handle with no sounds; look these up without
-- blocking so the Activated/Equipped handlers below always get connected.
local slashSound = handle:FindFirstChild("SwordSlash")
local unsheathSound = handle:FindFirstChild("Unsheath")

local AnimationController = require(ReplicatedStorage:WaitForChild("AnimationController"))
-- Which hit of the five-swing chain this click is. Predicted from the same constants the server
-- gates on and corrected by the server's ComboUpdate; see ReplicatedStorage/ComboClock. It picks
-- a clip and nothing else -- damage, endlag, reach and hit detection are all the server's.
local ComboClock = require(ReplicatedStorage:WaitForChild("ComboClock"))
-- The ribbon down the outer third of the blade, lit on the clip's "Swing" marker and put out on
-- "ArcEnd". It moved into a module because the heavy attack (bound in StarterPlayerScripts, since
-- it is a hold and a release rather than a Tool.Activated) lights the same ribbon on the same
-- blade; every number in it is the one the arc piece tuned.
local SwingTrail = require(ReplicatedStorage:WaitForChild("SwingTrail"))
-- The charged heavy attack's client half. Required here only so a swing thrown with this tool
-- can cancel a charge that is somehow still open on it; the binding lives in CombatController.
local HeavyCharge = require(ReplicatedStorage:WaitForChild("HeavyCharge"))
-- How this swing shares the body with a run underneath it. The clips drive both legs, which is
-- right standing still and skates the character across the ground at a run, so the swing hands
-- the legs back to Roblox's own cycle in proportion to how fast the player is actually moving,
-- leans the chest into that velocity and plants back into the cut around the contact frame.
-- Nothing here moves the character: it is thirteen Motor6D transforms, and where the body is
-- stays the server's.
local SwingMove = require(ReplicatedStorage:WaitForChild("SwingMove"))
-- What the world does at contact: the spark burst on a landed hit (fired from ComboVFX, which
-- is where the server's "this hit a body" message arrives) and the finisher's ground burst,
-- which is fired from here because it belongs to the ANIMATION -- the blade reaches the floor
-- on hit 5's ArcEnd whether or not anything was standing in the way.
local SwingImpact = require(ReplicatedStorage:WaitForChild("SwingImpact"))

local swingId = 0
local trailOff = 0


local function onActivated()
	local now = tick()
	-- A light swing and a charge are the same body: whichever starts last owns it. In practice
	-- CombatController refuses an M1 while a charge is open and the server drops it too, so this
	-- only catches a Tool:Activate() from somewhere else (the Studio capture stage, a prompt).
	HeavyCharge.cancel()
	-- The old gate here was a flat 0.5 s, which is longer than four of the five hits' endlags:
	-- a chain thrown at the real cadence played its animation for the first swing and then went
	-- silent while the server kept swinging. The gate is now the server's own endlag rule.
	if not ComboClock.ready(now) then
		return
	end
	local index, clipName, timing = ComboClock.advance(now)

	-- The whoosh and the trail belong to the blade, not to the click. Every hit's clip fires
	-- "Swing" when its windup ends and the blade starts forward and "ArcEnd" when its drive is
	-- spent, so neither steps on the anticipation and the ribbon covers that hit's arc exactly
	-- -- which matters more now that the five windups run from 100 ms to 330.
	swingId += 1
	local mySwing = swingId
	trailOff = now + timing.SWING_END
	AnimationController.Play(clipName, {
		-- This hit's own plant window: every hit has a different windup and contact frame, so the
		-- step into the cut is keyed to the hit being thrown rather than to hit 1's clock.
		moveBlend = SwingMove.forHit(index),
		onMarker = function(marker)
			if marker == "Swing" then
				if slashSound then
					-- One whoosh, five swings: the pitch carries the difference. Hits 1-4 climb
					-- 0.99 -> 1.14 as the cadence tightens, and the finisher drops to 0.82 --
					-- lower than any of them, because a heavier swing moves more air, and because
					-- a chain whose fifth note goes DOWN reads as an ending rather than as a
					-- fifth of the same thing.
					slashSound.PlaybackSpeed = if index >= 5 then 0.82 else 0.94 + index * 0.05
					slashSound:Play()
				end
				-- The finisher gets the long ribbon (SwingTrail.BIG_SPAN): it is one 80 ms pass
				-- through twelve studs and the narrow streak that suits a 250 ms light swing
				-- left no line behind it at all.
				SwingTrail.light(tool, timing.SWING_END - timing.WINDUP, index >= 5)
			elseif marker == "ArcEnd" then
				if mySwing == swingId then
					SwingTrail.out(tool)
				end
				-- Hit 5 only: the tip reaches the floor on this marker (see the Finisher block
				-- of SwingChain -- its ArcEnd key puts the tip half a stud INTO the ground), so
				-- this is the frame the slam's disc, dust and shards go off. The burst is put on
				-- the floor under the tip rather than at the tip, because the character's root
				-- sits a known three studs above its feet and a raycast every finisher, on every
				-- client, to learn something that is already known is a raycast wasted.
				if index >= 5 and mySwing == swingId then
					local character = tool.Parent
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						-- The tip if the blade can be measured, and the spot the tip is aimed at
						-- otherwise (4.5 studs down the character's own look vector, which is
						-- where the finisher's ArcEnd key puts it): a boss sword with an odd
						-- handle must not be able to cost the slam its ground burst.
						local tip = SwingTrail.tip(tool)
							or (root.CFrame * CFrame.new(0, 0, -4.5)).Position
						SwingImpact.slam(CFrame.new(tip.X, root.Position.Y - 3.0, tip.Z), 1)
					end
				end
			end
		end,
	})

	-- Safety net: a clip cut short by a respawn or by the next swing never reaches "ArcEnd",
	-- and a trail left lit would draw a ribbon behind the idle sword.
	task.delay(timing.RECOVERY_END, function()
		if SwingTrail.lit(tool) and tick() >= trailOff then
			SwingTrail.out(tool)
		end
	end)
end

local function onEquipped()
	if unsheathSound then
		unsheathSound:Play()
	end
	SwingTrail.ensure(tool)
end

local function onUnequipped()
	SwingTrail.out(tool)
	-- Putting the sword away mid-charge cancels the charge, here and on the server.
	HeavyCharge.cancel()
end


tool.Activated:Connect(onActivated)
tool.Equipped:Connect(onEquipped)
tool.Unequipped:Connect(onUnequipped)
