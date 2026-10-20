--// Services
local Players = game:GetService("Players")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")
local TeleportService = game:GetService("TeleportService")
local TextChatService = game:GetService("TextChatService")

--// Variables
local Modules = SS.Modules
local PlotManager = require(Modules.PlotManager)

local UpdateStateStore = require(RS.ModuleScripts.UpdateStateStore)

local Remotes = RS.Remotes
local UpdatePlantedBuildings = Remotes.Client.UpdatePlantedBuildings

local ServerMsgEvent = RS.AdminRemotes.SendGlobalMessage
local MESSAGE_TOPIC = "GlobalServerMessage"

local Admins = {154609412, 2322084975}
local Testers = {}
local TESTING_PLACE_ID = 120990929340531
local MAIN_PLACE_ID = 101131716323275

--// Local Functions

local function GetPlayer(player, name)
	if name == "me" then
		return player
	else
		return Players:FindFirstChild(name)
	end
end

local function GrowAll(player)
	local manager = PlotManager.GetPlot(player.UserId)
	if not manager or not manager.DoneLoading then return end
	
	local grown = false
	manager.BuildingsManager:InstaGrowBuildings()

	if grown then
		UpdatePlantedBuildings:FireClient(player, manager.BuildingsManager.PlantedBuildings)
	end
end

local function TriggerSoftShutdown(message)
	UpdateStateStore.SetUnderUpdate(true)

	-- 2. Broadcast shutdown message
	MessagingService:PublishAsync("SoftShutdown", message)
end

--// Global Messages
local function OnMessageReceived(messageData)
	local message = messageData.Data
	local text = message.text or ""
	local duration = message.duration or 5

	-- Send to all clients in this server
	ServerMsgEvent:FireAllClients(text, duration)
end

local function BroadcastGlobalMessage(text, duration)
	local message = {
		text = text,
		duration = duration or 5,
	}
	pcall(function()
		MessagingService:PublishAsync(MESSAGE_TOPIC, message)
	end)
end

--// Admin Chat Handler

local function OnPlayerChatted(player, msg)
	if not table.find(Admins, player.UserId) then return end
	
	local splitMsg = string.split(msg, " ")
	if splitMsg[1] == "/coin" then
		local plr = GetPlayer(player, splitMsg[2])
		if not plr then return end
		
		local amount = tonumber(splitMsg[3])
		if not amount then return end
		
		plr.leaderstats.Coin.Value += amount
	elseif splitMsg[1] == "/grow_all" then
		if splitMsg[2] == "everyone" then
			for _, plr in Players:GetPlayers() do
				GrowAll(plr)
			end
		else
			local plr = GetPlayer(player, splitMsg[2])
			if not plr then return end
			
			GrowAll(plr)
		end
	elseif splitMsg[1] == "/global_message" then
		table.remove(splitMsg, 1)
		local text = table.concat(splitMsg, " ")
		BroadcastGlobalMessage(text, 5)
	elseif splitMsg[1] == "/server_message" then
		table.remove(splitMsg, 1)
		local text = table.concat(splitMsg, " ")
		ServerMsgEvent:FireAllClients(text, 5)
	elseif splitMsg[1] == "/update_servers" then
		TriggerSoftShutdown("🔄 Updating servers... you'll be rejoined shortly.")
	elseif splitMsg[1] == "/speed" then
		local plr = GetPlayer(player, splitMsg[2])
		if not plr then return end
		
		local speedStr = splitMsg[3]
		if not speedStr then return end
		
		local speed = tonumber(speedStr)
		if not speed then return end
		
		plr.Character.Humanoid.WalkSpeed = speed
	elseif splitMsg[1] == "/kick" then
		local plr = GetPlayer(splitMsg[2])
		if not plr and not table.find(Admins, plr.UserId) then return end
	
		plr:Kick(splitMsg[3] or "You have been kicked by an owner")
	end
end

Players.PlayerAdded:Connect(function(player)
	if game.GameId ==TESTING_PLACE_ID then
		if not table.find(Admins, player.UserId) and not table.find(Testers, player.UserId) then
			TeleportService:Teleport(101131716323275, player)
		end
	end
	
	if table.find(Admins, player.UserId) then
		player.Chatted:Connect(function(msg)
			OnPlayerChatted(player, msg)
		end)
	end
end)

-- Subscribe to the topic
local success, err = pcall(function()
	MessagingService:SubscribeAsync(MESSAGE_TOPIC, OnMessageReceived)
end)

if not success then
	warn("Failed to subscribe to MessagingService:", err)
end