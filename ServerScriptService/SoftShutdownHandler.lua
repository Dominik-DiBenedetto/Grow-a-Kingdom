--// Services
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local UpdateStateStore = require(RS.ModuleScripts.UpdateStateStore)

--// Variables
local ServerShutdownEvent = RS.AdminRemotes.ServerShutdown

local STAGING_PLACE_ID = 127879359261010
local SHUTDOWN_TOPIC = "SoftShutdown"

local function onShutdown(data)
	local reason = data.Data or "Updating servers..."
	print("Received shutdown notice:", reason)

	for _, player in ipairs(Players:GetPlayers()) do
		pcall(function()
			TeleportService:Teleport(STAGING_PLACE_ID, player)
		end)
	end
end

-- Subscribe to shutdown messages
pcall(function()
	MessagingService:SubscribeAsync(SHUTDOWN_TOPIC, onShutdown)
end)

Players.PlayerAdded:Connect(function(player)
	if UpdateStateStore.IsUnderUpdate() then
		task.wait(.25)
		pcall(function()
			TeleportService:Teleport(STAGING_PLACE_ID, player)
		end)
	end
end)