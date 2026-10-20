--// Services
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Variables
local commands = {
	"/coin",
	"/grow_all",
	"/global_message",
	"/server_message",
	"/update_servers",
	"/speed",
	"/kick",
}

local player = Players.LocalPlayer

local Admins = {154609412, 2322084975}

-- Hide Admin Command Messages
TextChatService.OnIncomingMessage = function(message)
	if message.TextSource and not table.find(Admins, message.TextSource.UserId) then return nil end
	
	local text = message.Text
	local command = string.split(text, " ")[1]
	if table.find(commands, command) then
		local props = Instance.new("TextChatMessageProperties")
		props.Text = "  " -- hide the actual message
		props.PrefixText = ""
		return props
	end
	return nil
end
