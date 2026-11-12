-- Sound effects, ambience loops (ducked under mission results) and character voices.
-- Voices use Roblox's AudioTextToSpeech routed through effect chains (pitch, reverb, phone filter).
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local Audio = {}
Audio.muted = false

local music = Instance.new("SoundGroup")
music.Name = "HushMusic"
music.Volume = 1
music.Parent = SoundService
local sfxGroup = Instance.new("SoundGroup")
sfxGroup.Name = "HushSfx"
sfxGroup.Parent = SoundService

local loops = {}
local holder = Instance.new("Folder")
holder.Name = "HushAudio"
holder.Parent = SoundService

local function duck()
	TweenService:Create(music, TweenInfo.new(0.15), { Volume = 0.25 }):Play()
	task.delay(1.6, function()
		TweenService:Create(music, TweenInfo.new(0.6), { Volume = 1 }):Play()
	end)
end
Audio.duck = duck

function Audio.sfx(name, pos, volume)
	local info = Sounds[name]
	if not info then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. info.id
	s.Volume = (volume or 1) * (info.vol or 1)
	s.SoundGroup = sfxGroup
	local anchor
	if typeof(pos) == "Vector3" then
		anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Position = pos
		anchor.Parent = workspace
		s.RollOffMinDistance = 12
		s.RollOffMaxDistance = 140
		s.Parent = anchor
	else
		s.Parent = holder
	end
	if info.start then
		s.TimePosition = info.start
	end
	s:Play()
	if name == "Ding" or name == "Buzzer" then
		duck()
	end
	local life = info.stop or 10
	task.delay(life, function()
		if info.stop then
			TweenService:Create(s, TweenInfo.new(0.3), { Volume = 0 }):Play()
			task.wait(0.35)
		end
		s:Destroy()
		if anchor then
			anchor:Destroy()
		end
	end)
	return s
end

function Audio.loop(name, on, volume)
	local info = Sounds[name]
	if not info then
		return
	end
	local s = loops[name]
	if on then
		if not s then
			s = Instance.new("Sound")
			s.Name = name
			s.SoundId = "rbxassetid://" .. info.id
			s.Looped = true
			s.SoundGroup = music
			s.Volume = 0
			s.Parent = holder
			loops[name] = s
		end
		if not s.IsPlaying then
			s:Play()
		end
		TweenService:Create(s, TweenInfo.new(1), { Volume = (volume or 1) * (info.vol or 0.5) }):Play()
	elseif s then
		local t = TweenService:Create(s, TweenInfo.new(0.8), { Volume = 0 })
		t:Play()
		t.Completed:Connect(function()
			if s.Volume <= 0.01 then
				s:Stop()
			end
		end)
	end
end

function Audio.stopAll()
	for _, s in pairs(loops) do
		s:Stop()
	end
end

---------------------------------------------------------------- voices
-- VoiceId values are Roblox TTS presets; pitch/speed shape the character.
local Voices = {
	Nell = { voice = "2", pitch = 1.32, speed = 0.82, reverb = true, volume = 1.4 },
	Mum = { voice = "3", pitch = 1.0, speed = 1.0, phone = true, volume = 1.2 },
	Copy = { voice = "3", pitch = 1.0, speed = 0.92, reverb = true, echo = true, volume = 1.0 },
	Host = { voice = "1", pitch = 1.08, speed = 1.05, volume = 1.1 },
	Friend = { voice = "4", pitch = 1.0, speed = 1.0, volume = 1.1 },
	Narrator = { voice = "1", pitch = 0.9, speed = 1.0, volume = 1 },
}
Audio.Voices = Voices
local ttsAvailable = true
local voiceCache = {}

local function wire(a, b, parent)
	local w = Instance.new("Wire")
	w.SourceInstance = a
	w.TargetInstance = b
	w.Parent = parent
	return w
end

function Audio.voice(speaker, text, style)
	if not ttsAvailable or Audio.muted then
		return
	end
	local v = Voices[speaker] or Voices.Narrator
	-- replay a cached line: Roblox rate-limits TTS loads, and many orders repeat
	local key = speaker .. "|" .. tostring(style) .. "|" .. text
	local cached = voiceCache[key]
	if cached and cached.Parent and cached.IsLoaded then
		cached.TimePosition = 0
		cached:Play()
		return
	end
	task.spawn(function()
		local folder = Instance.new("Folder")
		folder.Name = "Voice_" .. speaker
		folder.Parent = holder
		local keep = false
		local ok, err = pcall(function()
			local tts = Instance.new("AudioTextToSpeech")
			tts.Text = text
			tts.VoiceId = v.voice
			tts.Speed = (style == "slow" and 0.6 or (style == "scream" and 1.1 or v.speed))
			tts.Volume = (style == "scream" and 3 or (style == "whisper" and 0.7 or v.volume))
			tts.Parent = folder
			local last = tts
			local function chain(inst)
				inst.Parent = folder
				wire(last, inst, folder)
				last = inst
			end
			local shifter = Instance.new("AudioPitchShifter")
			shifter.Pitch = style == "scream" and v.pitch * 0.9 or v.pitch
			chain(shifter)
			if v.phone then
				local f = Instance.new("AudioFilter")
				f.FilterType = Enum.AudioFilterType.Bandpass
				f.Frequency = 1500
				f.Q = 1.2
				chain(f)
			end
			if style == "scream" then
				local dist = Instance.new("AudioDistortion")
				dist.Level = 0.5
				chain(dist)
			end
			if v.echo then
				local e = Instance.new("AudioEcho")
				e.DelayTime = 0.28
				e.Feedback = 0.35
				e.WetLevel = -4
				chain(e)
			end
			if v.reverb or style == "whisper" then
				local r = Instance.new("AudioReverb")
				r.DecayTime = speaker == "Nell" and 1.6 or 2.6
				r.WetLevel = speaker == "Nell" and -10 or -4
				chain(r)
			end
			local out = Instance.new("AudioDeviceOutput")
			chain(out)
			tts:LoadAsync()
			if tts.TimeLength > 0 then
				voiceCache[key] = tts
				keep = true
			end
			tts:Play()
		end)
		if not ok then
			warn("[HushHour] voice failed:", err)
			if tostring(err):find("not") and tostring(err):find("support") then
				ttsAvailable = false
			end
		end
		if not keep then
			task.delay(1, function()
				folder:Destroy()
			end)
		end
	end)
end

return Audio
