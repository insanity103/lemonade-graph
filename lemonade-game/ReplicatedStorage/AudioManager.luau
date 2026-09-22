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
	-- Strike / clang cues (first written for the removed Reforge anvil; kept for any reveal that
	-- wants a heartbeat tick and a hammer clang, pitched and swelled by quality).
	forge_tick          = "rbxassetid://6042053626",
	forge_clang         = "rbxassetid://6042053626",
	forge_clang_good    = "rbxassetid://6042053626",
	forge_clang_perfect = "rbxassetid://6042053626",
	-- A mystery-sword reveal: a tick per rung as the glow climbs the
	-- ladder, the chime it lands on, and the stamp of each modifier locking in.
	reveal_tick = "rbxassetid://6042053626",
	reveal_land = "rbxassetid://2865227271",
	reveal_lock = "rbxassetid://6042053626",
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
	forge_tick = {
		PlaybackSpeed = 2.1, -- a light tick as the marker enters the sweet zone
		Volume = 0.35,
	},
	forge_clang = {
		PlaybackSpeed = 0.42, -- a flat, heavy hit: an OK blow
		Volume = 0.9,
	},
	forge_clang_good = {
		PlaybackSpeed = 0.55,
		Volume = 1.1,
	},
	forge_clang_perfect = {
		PlaybackSpeed = 0.7, -- the bright ring of a clean strike
		Volume = 1.3,
	},
	reveal_tick = {
		PlaybackSpeed = 1.4, -- the caller pitches each tick up as the ladder slows
		Volume = 0.3,
	},
	reveal_land = {
		Volume = 1.0, -- the caller swells and pitches this by the rung that landed
	},
	reveal_lock = {
		PlaybackSpeed = 1.0,
		Volume = 0.5,
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
    @param overrides  Optional per-call { PlaybackSpeed, Volume }, applied over the table above,
                      for one-shots that need to rise or swell across a sequence.
]]
function AudioManager.PlaySFX(soundName: string, parent: Instance, overrides: { [string]: number }?)
	local soundId = getSoundId(soundName)
	if not soundId then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Name = "SFX_" .. soundName
	sound.Parent = parent

	applyOverrides(sound, soundName)
	if overrides then
		if overrides.PlaybackSpeed then sound.PlaybackSpeed = overrides.PlaybackSpeed end
		if overrides.Volume then sound.Volume = overrides.Volume end
	end

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
