--// Services
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

--// Variables
local Remotes = RS.Remotes
local SendMessageEvent = Remotes.Client.SendServerMessage

local MESSAGE_INTERVAL = 300
local SERVER_MESSAGES = {
	"Tip: Be sure to upgrade your Town Hall to unlock more buildings!",
	"Did you know you can gift buildings to friends?!",
	"Favorite the game to support development and get updates!",
	"Tip: Fully built buildings spawn NPCs that you can get items from to sell for extra coins!",
	"Tip: Remember to collect your town hall earnings!",
	"Did you know you can turn off pvp in settings?",
	"Tip: Upgrading your Town Hall increases its max income capacity!",
	"Did you know you can steal money from other players Town Hall?",
	"Tip: You can't hurt NPCs, but you can collect them for money!"
}

local COLORS = {
	["Tip"] = Color3.fromRGB(81, 255, 13),
	["Did you know"] = Color3.fromRGB(198, 33, 246),
	["Favorite"] = Color3.fromRGB(255, 247, 45)
}

local TAG = "[SERVER]"

--// Local functions
local function sendServerMessage(text)
	for msgType, color in COLORS do
		if string.find(text, msgType) then
			text = string.format("<font color=\"#%s\">%s</font>", color:ToHex(), TAG.." "..text)
		end
	end
	return text
end

-- Cycle messages
task.spawn(function()
	while true do
		for _, message in ipairs(SERVER_MESSAGES) do
			local text = sendServerMessage(message)
			SendMessageEvent:FireAllClients(text)
			task.wait(MESSAGE_INTERVAL)
		end
	end
end)
