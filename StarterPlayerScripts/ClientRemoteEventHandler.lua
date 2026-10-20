--// Services
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local AvatarService = game:GetService("AvatarEditorService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")

--// Variables
local Player = Players.LocalPlayer
local Remotes = RS.Remotes

-- Blur Variables
local blur = Lighting.Blur
local cam = workspace.CurrentCamera

local NORMAL_FOV = 60
local BLUR_FOV = 50
local BLUR_TWEEN_TIME = 0.5
local BLUR_TWEEN_INFO = TweenInfo.new(BLUR_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Seller Talk Variables
local bb = game.Workspace.Map.Booth.Seller.Head.BillboardGui
local textlabel = bb:WaitForChild("Frame"):WaitForChild("TextLabel")

local isTyping = false

-- Server messsage variables
local generalChannel = TextChatService:WaitForChild("TextChannels"):WaitForChild("RBXGeneral")

--// Local Functions
local function typewrite(obj, text)
	isTyping = true
	obj.Text = ""
	for i = 1, #text do
		obj.Text = string.sub(text, 1, i)
		wait(0.03)
	end
	isTyping = false
end

--// Handlers
local remoteHandlers = {
	["PlaySound"] = function(soundName, isPlaying, volume)
		local sound = SoundService.SFX:FindFirstChild(soundName)
		if not sound or not sound:IsA("Sound") then
			warn("Sound not found or not a Sound instance:", soundName)
			return
		end

		sound.Volume = volume or sound.Volume -- fallback if nil

		if isPlaying then
			sound:Play()
		else
			sound:Stop()
		end
	end,
	["SellerTalk"] = function(text)
		if isTyping then return end

		typewrite(textlabel, text)

		if text == "Goodbye!" or text == "I don't see anything..." then
			task.wait(#text * 0.03 + 1)
			textlabel.Text = ""
		end
	end,
	["SendServerMessage"] = function(text)
		generalChannel:DisplaySystemMessage(text)
	end,
	
	--// UI Toggles
	
	["ToggleUI"] = function(uiName, enabled)
		local screenGui = game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild(uiName)
		if screenGui and screenGui:IsA("ScreenGui") then
			screenGui.Enabled = enabled
		else
			warn("UI", uiName, "not found.")
		end
	end,
	["ToggleButtons"] = function(uiName, obj, enabled)
		local frame = Player:WaitForChild("PlayerGui"):WaitForChild(uiName):WaitForChild(obj)
		if frame and frame:IsA("Frame") then
			frame.Visible = enabled
			frame.Parent.Enabled = enabled
		else
			warn("UI", uiName, "not found.")
		end
	end,
	["ToggleSpecificUI"] = function(UI, enabled, ...)
		local params = {...}
		if #params > 0 then 
			if params[1] == Player then return end
		end
		
		if UI:IsA("Frame") then
			UI.Visible = enabled
		else
			UI.Enabled = enabled
		end
	end,
	["ToggleProxPrompt"] = function(prompt, enabled, ...)
		local params = {...}
		if #params > 0 then
			if game.Players.LocalPlayer == params[1] then 
				prompt.Enabled = params[2]
			else
				prompt.Enabled = enabled
			end
			return
		end
		prompt.Enabled = enabled
	end,
	["PromptFavoriteGame"] = function()
		AvatarService:PromptSetFavorite(game.PlaceId, 1, true)
	end,
	["ToggleBlur"] = function(enabled)
		if enabled then
			blur.Enabled = true
			TweenService:Create(cam, BLUR_TWEEN_INFO, {FieldOfView = BLUR_FOV}):Play()
		else
			blur.Enabled = false
			TweenService:Create(cam, BLUR_TWEEN_INFO, {FieldOfView = NORMAL_FOV}):Play()
		end
	end,
	["ToggleCollision"] = function(part, collision)
		part.CanCollide = collision
	end,
}

--// Connections
for _, remote in Remotes.Client:GetChildren() do
	if not remoteHandlers[remote.Name] then continue end
	if remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(remoteHandlers[remote.Name])
	end
end