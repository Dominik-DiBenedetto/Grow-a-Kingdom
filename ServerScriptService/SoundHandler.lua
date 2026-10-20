local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VolumeChangeEvent = ReplicatedStorage.Remotes.Client:WaitForChild("VolumeChangeEvent")

if not SoundService:FindFirstChild("AmbientMusic") then
	local music = Instance.new("Sound")
	music.Name = "Music"
	music.SoundId = "rbxassetid://117081554687014"
	music.Looped = true
	music.Volume = 0.3
	music.Playing = true
	music.Name = "AmbientMusic"
	music.Parent = SoundService
end

local songs = SoundService:WaitForChild("Music"):GetChildren()

local currentSongIndex = 1
local fadeTime = 15
local maxVolume = 0.3 -- initial max volume

local function TweenVolume(sound, targetVolume, duration)
	local tween = TweenService:Create(sound, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Volume = targetVolume
	})
	tween:Play()
	return tween
end

local function PlaySong(index)
	if index > #songs then index = 1 end
	currentSongIndex = index

	local song = songs[index]
	song.Volume = 0
	song.Looped = false
	song:Play()

	TweenVolume(song, maxVolume, fadeTime)

	local connection
	connection = song.Ended:Connect(function()
		connection:Disconnect()
		TweenVolume(song, 0, fadeTime)
		task.wait(fadeTime)
		song:Stop()
		PlaySong(currentSongIndex + 1)
	end)
end

local function UpdateVolume(newVolume)
	maxVolume = math.clamp(newVolume, 0, 1)
	for _, song in ipairs(songs) do
		if song.IsPlaying then
			TweenVolume(song, maxVolume, 0.5)
		else
			song.Volume = maxVolume
		end
	end
end
PlaySong(currentSongIndex)
VolumeChangeEvent.OnServerEvent:Connect(function(player, newVolume)
	UpdateVolume(newVolume)
end)


