--!strict
--[[
    AudioManager.luau
    Centralized audio playback for all gameplay events.
    
    Usage:
        local AudioManager = require(path.to.AudioManager)
        AudioManager.PlaySFX("enemy_hit", workspace.EnemyPart)
        AudioManager.PlayGlobal("level_up")
]]

local SoundService = game:GetService("SoundService")

local AudioManager = {}

-------------------------------------------------
-- Sound Definitions
-------------------------------------------------
-- Each entry maps a logical event name to its Roblox library asset ID.
-- Some events reuse the same clip with pitch/volume tweaks.

local SoundIDs: { [string]: string } = {
	enemy_hit       = "rbxassetid://597480294",
	enemy_death     = "rbxassetid://597480294",  -- reused, pitched down via overrides
	crit_hit        = "rbxassetid://597480294",  -- reused, pitched up via overrides
	level_up        = "rbxassetid://2865227271",
	rebirth         = "rbxassetid://2865227271", -- reused, same clip
	quest_accept    = "rbxassetid://6042053626",
	quest_complete  = "rbxassetid://6042053626",
	gold_pickup     = "rbxassetid://6042053626",
	sword_drop      = "rbxassetid://6042053626",
	ui_click        = "rbxassetid://6042053626",
	combo_milestone = "rbxassetid://6042053626",
}

-------------------------------------------------
-- Per-sound property overrides
-------------------------------------------------
-- Optional: tweak Pitch, Volume, or PlaybackSpeed for specific events.

local SoundOverrides: { [string]: { [string]: number } } = {
	enemy_death = {
		PlaybackSpeed = 0.7, -- lower pitch for death
	},
	crit_hit = {
		PlaybackSpeed = 1.5, -- higher pitch for crit
	},
	level_up = {
		Volume = 1.0,
	},
	rebirth = {
		Volume = 1.0,
	},
}

-------------------------------------------------
-- Internal helpers
-------------------------------------------------

local function getSoundId(soundName: string): string?
	local id = SoundIDs[soundName]
	if not id then
		warn("[AudioManager] Unknown sound name:", soundName)
		return nil
	end
	return id
end

local function applyOverrides(sound: Sound, soundName: string)
	local overrides = SoundOverrides[soundName]
	if not overrides then
		return
	end
	if overrides.PlaybackSpeed then
		sound.PlaybackSpeed = overrides.PlaybackSpeed
	end
	if overrides.Volume then
		sound.Volume = overrides.Volume
	end
end

-------------------------------------------------
-- Public API
-------------------------------------------------

--[[
    PlaySFX(soundName, parent)
    Creates a temporary Sound instance under `parent`, plays it, and
    destroys it once it finishes. Ideal for one-shot gameplay effects.

    @param soundName  Key from the SoundIDs table (e.g. "enemy_hit")
    @param parent     Instance to parent the Sound under (e.g. a Part or the workspace)
]]
function AudioManager.PlaySFX(soundName: string, parent: Instance)
	local soundId = getSoundId(soundName)
	if not soundId then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Name = "SFX_" .. soundName
	sound.Parent = parent

	applyOverrides(sound, soundName)

	sound:Play()

	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

--[[
    PlayGlobal(soundName)
    Plays a sound on SoundService. Suitable for music or ambient tracks.
    Respects the local player's "MusicVolume" attribute if present.

    @param soundName  Key from the SoundIDs table (e.g. "level_up")
]]
function AudioManager.PlayGlobal(soundName: string)
	local soundId = getSoundId(soundName)
	if not soundId then
		return
	end

	local Players = game:GetService("Players")
	local localPlayer = Players.LocalPlayer

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Name = "Global_" .. soundName
	sound.Parent = SoundService

	applyOverrides(sound, soundName)

	-- Apply MusicVolume if available
	if localPlayer then
		local musicVolume = localPlayer:GetAttribute("MusicVolume")
		if typeof(musicVolume) == "number" then
			sound.Volume = sound.Volume * musicVolume
		end
	end

	sound:Play()

	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

return AudioManager
