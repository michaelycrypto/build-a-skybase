--[[
	SoundManager.lua - Audio management with user preferences
	Handles background music, sound effects, and volume controls
--]]

local SoundManager = {}

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import dependencies
local Config = require(ReplicatedStorage.Shared.Config)
local GameState = require(script.Parent.GameState)

-- Safe logging function
local function safeLog(level, message, data)
	local success, Logger = pcall(function()
		return require(ReplicatedStorage.Shared.Logger)
	end)

	if success and Logger and Logger[level] then
		Logger[level](Logger, "SoundManager", message, data)
	else
		-- Fallback to print statements
		local prefix = "[SoundManager] "
		if level == "Error" or level == "Critical" then
			warn(prefix .. message)
		else
			print(prefix .. message)
		end
	end
end

-- State
local sounds = {}
local musicTracks = {}
local currentMusic = nil
local masterVolume = 1
local musicVolume = 0.5
local sfxVolume = 0.7
local soundEnabled = true

--[[
	Initialize the sound manager
--]]
function SoundManager:Initialize()
	local success, error = pcall(function()
		-- Load settings from game state
		local settings = GameState:Get("settings")
		if settings then
			soundEnabled = settings.soundEnabled
			musicVolume = settings.musicVolume or 0.5
			sfxVolume = settings.sfxVolume or 0.7
		end

		-- Check if AUDIO_SETTINGS is available
		if not Config.AUDIO_SETTINGS then
			safeLog("Warn", "AUDIO_SETTINGS not found in Config, using silent mode", {})
			soundEnabled = false
			return
		end

		-- Load background music with error handling
		if Config.AUDIO_SETTINGS.backgroundMusic then
			for i, musicData in pairs(Config.AUDIO_SETTINGS.backgroundMusic) do
				local musicSuccess, musicError = pcall(function()
					local sound = Instance.new("Sound")
					sound.SoundId = musicData.id
					sound.Volume = musicData.volume * musicVolume
					sound.Looped = true
					sound.Parent = SoundService

					musicTracks[i] = {
						sound = sound,
						baseVolume = musicData.volume
					}
				end)

				if not musicSuccess then
					safeLog("Error", "Failed to load music track", {
						trackIndex = i,
						error = musicError
					})
				end
			end
		end

		-- Load sound effects with error handling
		if Config.AUDIO_SETTINGS.soundEffects then
			for name, sfxData in pairs(Config.AUDIO_SETTINGS.soundEffects) do
				local sfxSuccess, sfxError = pcall(function()
					local sound = Instance.new("Sound")
					sound.SoundId = sfxData.id
					sound.Volume = sfxData.volume * sfxVolume
					sound.Parent = SoundService

					sounds[name] = {
						sound = sound,
						baseVolume = sfxData.volume
					}
				end)

				if not sfxSuccess then
					safeLog("Error", "Failed to load sound effect", {
						soundName = name,
						error = sfxError
					})
				end
			end
		end

		-- Listen for settings changes
		GameState:OnPropertyChanged("settings.soundEnabled", function(newValue)
			self:_setSoundEnabledInternal(newValue)
		end)

		GameState:OnPropertyChanged("settings.musicVolume", function(newValue)
			self:_setMusicVolumeInternal(newValue)
		end)

		GameState:OnPropertyChanged("settings.sfxVolume", function(newValue)
			self:_setSFXVolumeInternal(newValue)
		end)

		-- Listen for currency changes to play appropriate sounds
		GameState:OnPropertyChanged("playerData.coins", function(newValue, oldValue)
			if newValue and oldValue and newValue > oldValue then
				-- Coins were gained, play coin collect sound
				self:PlaySFX("coinCollect")
			end
		end)

		GameState:OnPropertyChanged("playerData.gems", function(newValue, oldValue)
			if newValue and oldValue and newValue > oldValue then
				-- Gems were gained, play achievement sound
				self:PlaySFX("achievement")
			end
		end)

		-- Listen for experience gains
		GameState:OnPropertyChanged("playerData.experience", function(newValue, oldValue)
			if newValue and oldValue and newValue > oldValue then
				-- Experience was gained, play notification sound
				self:PlaySFX("notification")
			end
		end)
	end)

	if success then
		safeLog("Info", "Sound system initialized", {
			musicTracks = #musicTracks,
			soundEffects = self:_countSounds(),
			soundEnabled = soundEnabled
		})
	else
		safeLog("Error", "Sound system initialization failed", {
			error = error
		})
		safeLog("Warn", "Running in silent mode", {})
		soundEnabled = false
	end
end

--[[
	Check if a sound effect exists
	@param soundName: string - Name of the sound effect
	@return: boolean - Whether the sound exists
--]]
function SoundManager:HasSound(soundName)
	return sounds[soundName] ~= nil
end

--[[
	Get list of available sound effects
	@return: table - Array of sound names
--]]
function SoundManager:GetAvailableSounds()
	local soundNames = {}
	for name, _ in pairs(sounds) do
		table.insert(soundNames, name)
	end
	return soundNames
end

--[[
	Play a sound effect
	@param soundName: string - Name of the sound effect
	@param pitch: number - Optional pitch modifier (default: 1)
	@param volume: number - Optional volume modifier (default: 1)
--]]
function SoundManager:PlaySFX(soundName, pitch, volume)
	if not soundEnabled then return end

	local soundData = sounds[soundName]
	if not soundData then
		-- Silently fail for missing sounds to avoid spam
		safeLog("Debug", "Sound not found", {soundName = soundName})
		return
	end

	local sound = soundData.sound
	if not sound or not sound.Parent then
		-- Sound was destroyed or not properly loaded
		safeLog("Debug", "Sound instance not available", {soundName = soundName})
		return
	end

	-- Apply modifiers safely
	local success, error = pcall(function()
		if pitch then
			sound.Pitch = pitch
		end

		if volume then
			sound.Volume = soundData.baseVolume * sfxVolume * volume
		else
			sound.Volume = soundData.baseVolume * sfxVolume
		end

		-- Play the sound
		sound:Play()
	end)

	if not success then
		safeLog("Error", "Failed to play sound effect", {
			soundName = soundName,
			error = error
		})
	else
		safeLog("Debug", "Sound effect played", {
			soundName = soundName
		})
	end
end

--[[
	Play a sound effect attached to a world instance (BasePart/Attachment)
	@param soundName: string
	@param parentInstance: Instance - BasePart or Attachment to parent the sound to
	@param pitch: number? - Optional pitch modifier
	@param volume: number? - Multiplier applied to base volume
--]]
function SoundManager:PlaySFX3D(soundName, parentInstance, pitch, volume)
	if not soundEnabled then return end

	if not parentInstance or not parentInstance.Parent then
		self:PlaySFX(soundName, pitch, volume)
		return
	end

	local soundData = sounds[soundName]
	if not soundData or not soundData.sound then
		safeLog("Debug", "3D sound not found", {soundName = soundName})
		return
	end

	local clone = soundData.sound:Clone()
	clone.Looped = false
	if pitch then
		clone.Pitch = pitch
	end
	clone.Volume = soundData.baseVolume * sfxVolume * (volume or 1)
	clone.Parent = parentInstance

	local function cleanup()
		if clone then
			clone:Destroy()
			clone = nil
		end
	end

	clone.Ended:Connect(cleanup)
	clone.Stopped:Connect(cleanup)

	clone:Play()

	task.delay(10, function()
		cleanup()
	end)
end

--[[
	Safely play a sound effect (creates temporary sound if not loaded)
	@param soundName: string - Name of the sound effect
	@param pitch: number - Optional pitch modifier (default: 1)
	@param volume: number - Optional volume modifier (default: 1)
--]]
function SoundManager:PlaySFXSafely(soundName, pitch, volume)
	if not soundEnabled then return end

	-- First try to play the loaded sound
	if self:HasSound(soundName) then
		self:PlaySFX(soundName, pitch, volume)
		return
	end

	-- If sound not loaded, try to create it from Config
	if Config.AUDIO_SETTINGS and Config.AUDIO_SETTINGS.soundEffects and Config.AUDIO_SETTINGS.soundEffects[soundName] then
		local sfxData = Config.AUDIO_SETTINGS.soundEffects[soundName]
		local success, error = pcall(function()
			local sound = Instance.new("Sound")
			sound.SoundId = sfxData.id
			sound.Volume = (sfxData.volume or 0.5) * sfxVolume * (volume or 1)
			sound.Pitch = pitch or 1
			sound.Parent = SoundService

			-- Play the sound
			sound:Play()

			-- Clean up after playing
			sound.Ended:Connect(function()
				sound:Destroy()
			end)

			-- Fallback cleanup
			spawn(function()
				wait(10)
				if sound and sound.Parent then
					sound:Destroy()
				end
			end)
		end)

		if not success then
			safeLog("Error", "Failed to play sound safely", {
				soundName = soundName,
				error = error
			})
		end
	else
		safeLog("Debug", "Sound not found in config", {soundName = soundName})
	end
end

--[[
	Play a sound by ID (compatibility method for EventManager)
	@param soundId: string - Roblox sound ID
	@param volume: number - Optional volume modifier (default: 1)
	@param pitch: number - Optional pitch modifier (default: 1)
	@param category: string - Sound category (SFX, Music, etc.)
--]]
function SoundManager:PlaySound(soundId, volume, pitch, category)
	if not soundEnabled then return end

	-- Create a temporary sound instance for this play
	local success, error = pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = (volume or 1) * sfxVolume
		sound.Pitch = pitch or 1
		sound.Parent = SoundService

		-- Play the sound
		sound:Play()

		-- Clean up after playing
		sound.Ended:Connect(function()
			sound:Destroy()
		end)

		-- Fallback cleanup in case Ended doesn't fire
		spawn(function()
			wait(10) -- Wait up to 10 seconds
			if sound and sound.Parent then
				sound:Destroy()
			end
		end)
	end)

	if not success then
		safeLog("Error", "Failed to play sound by ID", {
			soundId = soundId,
			error = error
		})
	else
		safeLog("Debug", "Sound played by ID", {
			soundId = soundId,
			category = category
		})
	end
end

--[[
	Play a sound effect by category
	@param soundName: string - Name of the sound effect
	@param category: string - Sound category (SFX, Music, etc.)
	@param pitch: number - Optional pitch modifier (default: 1)
	@param volume: number - Optional volume modifier (default: 1)
--]]
function SoundManager:PlaySoundByCategory(soundName, category, pitch, volume)
	if category == "Music" then
		-- For music, we might want different handling
		self:PlaySFX(soundName, pitch, volume)
	else
		-- Default to SFX handling
		self:PlaySFX(soundName, pitch, volume)
	end
end

--[[
	Play background music
	@param trackIndex: number - Index of music track (default: 1)
	@param fadeIn: boolean - Whether to fade in (default: true)
--]]
function SoundManager:PlayMusic(trackIndex, fadeIn)
	if not soundEnabled then return end

	trackIndex = trackIndex or 1
	fadeIn = fadeIn ~= false -- Default true

	local musicData = musicTracks[trackIndex]
	if not musicData then
		safeLog("Error", "Music track not found", {
			trackIndex = trackIndex
		})
		return
	end

	-- Stop current music
	if currentMusic then
		self:StopMusic(fadeIn)
	end

	currentMusic = musicData
	local sound = musicData.sound

	if fadeIn then
		-- Fade in
		sound.Volume = 0
		sound:Play()

		-- Gradually increase volume
		spawn(function()
			local targetVolume = musicData.baseVolume * musicVolume
			local steps = 20
			local stepSize = targetVolume / steps

			for i = 1, steps do
				if sound.IsPlaying then
					sound.Volume = stepSize * i
					wait(0.05)
				end
			end
		end)
	else
		sound.Volume = musicData.baseVolume * musicVolume
		sound:Play()
	end

	safeLog("Info", "Music track started", {
		trackIndex = trackIndex,
		fadeIn = fadeIn
	})
end

--[[
	Stop background music
	@param fadeOut: boolean - Whether to fade out (default: true)
--]]
function SoundManager:StopMusic(fadeOut)
	if not currentMusic then return end

	fadeOut = fadeOut ~= false -- Default true
	local sound = currentMusic.sound

	if fadeOut then
		-- Fade out
		spawn(function()
			local startVolume = sound.Volume
			local steps = 20
			local stepSize = startVolume / steps

			for i = 1, steps do
				if sound.IsPlaying then
					sound.Volume = startVolume - (stepSize * i)
					wait(0.05)
				end
			end

			sound:Stop()
		end)
	else
		sound:Stop()
	end

	currentMusic = nil
	safeLog("Info", "Music stopped", {})
end

--[[
	Set master sound enabled/disabled
	@param enabled: boolean - Whether sound is enabled
--]]
function SoundManager:SetSoundEnabled(enabled)
	soundEnabled = enabled

	if not enabled then
		-- Stop all sounds
		self:StopMusic(false)
		for _, soundData in pairs(sounds) do
			soundData.sound:Stop()
		end
	else
		-- Resume music if it was playing and tracks are available
		if currentMusic and self:HasMusicTracks() then
			self:PlayMusic(1, false)
		end
	end

	-- Update settings
	GameState:Set("settings.soundEnabled", enabled)
end

--[[
	Set music volume
	@param volume: number - Volume level (0-1)
--]]
function SoundManager:SetMusicVolume(volume)
	musicVolume = math.clamp(volume, 0, 1)

	-- Update current music volume
	if currentMusic then
		currentMusic.sound.Volume = currentMusic.baseVolume * musicVolume
	end

	-- Update settings
	GameState:Set("settings.musicVolume", musicVolume)

	safeLog("Debug", "Music volume changed", {
		volume = musicVolume
	})
end

--[[
	Set sound effects volume
	@param volume: number - Volume level (0-1)
--]]
function SoundManager:SetSFXVolume(volume)
	sfxVolume = math.clamp(volume, 0, 1)

	-- Update all sound effect volumes
	for _, soundData in pairs(sounds) do
		soundData.sound.Volume = soundData.baseVolume * sfxVolume
	end

	-- Update settings
	GameState:Set("settings.sfxVolume", sfxVolume)

	safeLog("Debug", "SFX volume changed", {
		volume = sfxVolume
	})
end

--[[
	Get current volume settings
	@return: table - Volume settings
--]]
function SoundManager:GetVolumeSettings()
	return {
		soundEnabled = soundEnabled,
		musicVolume = musicVolume,
		sfxVolume = sfxVolume
	}
end

--[[
	Check if music tracks are available
	@return: boolean - Whether music tracks exist
--]]
function SoundManager:HasMusicTracks()
	return next(musicTracks) ~= nil
end

--[[
	Add a custom sound effect
	@param name: string - Sound name
	@param soundId: string - Roblox sound ID
	@param volume: number - Base volume (default: 0.5)
--]]
function SoundManager:AddSFX(name, soundId, volume)
	volume = volume or 0.5

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume * sfxVolume
	sound.Parent = SoundService

	sounds[name] = {
		sound = sound,
		baseVolume = volume
	}

	safeLog("Debug", "Custom SFX added", {
		soundName = name
	})
end

--[[
	Remove a sound effect
	@param name: string - Sound name to remove
--]]
function SoundManager:RemoveSFX(name)
	local soundData = sounds[name]
	if soundData then
		soundData.sound:Destroy()
		sounds[name] = nil
		print("SoundManager: Removed SFX", name)
	end
end

--[[
	Count total number of sounds
	@return: number - Total sound count
--]]
function SoundManager:_countSounds()
	local count = 0
	for _ in pairs(sounds) do
		count = count + 1
	end
	return count
end

--[[
	Cleanup when leaving game
--]]
function SoundManager:Cleanup()
	-- Stop all sounds
	self:StopMusic(false)

	for _, soundData in pairs(sounds) do
		soundData.sound:Stop()
		soundData.sound:Destroy()
	end

	for _, musicData in pairs(musicTracks) do
		musicData.sound:Stop()
		musicData.sound:Destroy()
	end

	safeLog("Info", "SoundManager cleanup completed", {})
end

--[[
	Internal method: Set master sound enabled/disabled without updating GameState
	@param enabled: boolean - Whether sound is enabled
--]]
function SoundManager:_setSoundEnabledInternal(enabled)
	soundEnabled = enabled

	if not enabled then
		-- Stop all sounds
		self:StopMusic(false)
		for _, soundData in pairs(sounds) do
			soundData.sound:Stop()
		end
	else
		-- Resume music if it was playing and tracks are available
		if currentMusic and self:HasMusicTracks() then
			self:PlayMusic(1, false)
		end
	end

	safeLog("Debug", "Sound enabled changed (internal)", {
		enabled = enabled
	})
end

--[[
	Internal method: Set music volume without updating GameState
	@param volume: number - Volume level (0-1)
--]]
function SoundManager:_setMusicVolumeInternal(volume)
	musicVolume = math.clamp(volume, 0, 1)

	-- Update current music volume
	if currentMusic then
		currentMusic.sound.Volume = currentMusic.baseVolume * musicVolume
	end

	safeLog("Debug", "Music volume changed (internal)", {
		volume = musicVolume
	})
end

--[[
	Internal method: Set sound effects volume without updating GameState
	@param volume: number - Volume level (0-1)
--]]
function SoundManager:_setSFXVolumeInternal(volume)
	sfxVolume = math.clamp(volume, 0, 1)

	-- Update all sound effect volumes
	for _, soundData in pairs(sounds) do
		soundData.sound.Volume = soundData.baseVolume * sfxVolume
	end

	safeLog("Debug", "SFX volume changed (internal)", {
		volume = sfxVolume
	})
end

return SoundManager