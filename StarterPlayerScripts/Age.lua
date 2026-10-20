local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStats = ReplicatedStorage.Remotes.Server:WaitForChild("ServerStats")

ServerStats.OnClientEvent:Connect(function(data)
	local serverAge = data.age
	local version = data.version

	game.Players.LocalPlayer.PlayerGui:WaitForChild("AnythingButTimeRewards").SettingFrame.Top.Age.Text = 
	     "Server Age: " .. serverAge .. " | Version: v" .. version
end)
