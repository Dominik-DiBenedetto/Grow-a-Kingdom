--// Services
local Players = game:GetService("Players")
local Tags = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")

--// Variables
local Modules = SS.Modules
local SeedStock = require(Modules.SeedStock)
local DataManager = require(Modules.DataManager)
local PlotManager = require(Modules.PlotManager)

local UpdateStockCounter = RS.Remotes.Client.UpdateStock
local UpdateTimerEvent = RS.Remotes.Client.UpdateTimer
local LoadSeedShop = RS.Remotes.Client.LoadSeedShop

local StarterTools = RS.StarterTools:GetChildren()

local PvpDisplay = RS.VFX.PvpDisplay

local dataManagers = {}
local playerBoosts = {}

--// Helpers
local function SetProperties(model, properties)
	if not model then return end
	if model:IsA("BasePart") then
		for property, value in properties do
			model[property] = value
		end
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			for property, value in properties do
				part[property] = value
			end
		else if part.Name == "CostDisplay" then
				if not properties["Transparency"] then continue end
				
				if properties["Transparency"] == 1 then part.Enabled = false
				else part.Enabled = true end
			end
		end
	end
end

--// Functions

local function Leaderstats(Player)
	--// Actual Leaderstats
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local cash = Instance.new("NumberValue", stats)
	cash.Value = 100
	cash.Name = "Coin"

	stats.Parent = Player
	
	--// Extra values
	local PVPOn = Instance.new("BoolValue")
	PVPOn.Name = "PVPEnabled"
	PVPOn.Value = false
	PVPOn.Parent = Player

	local stepValue = Instance.new("IntValue")
	stepValue.Name = "TutorialStep"
	stepValue.Value = 0 -- 1 means tutorial started, 0 = not started
	stepValue.Parent = Player
	
	local function addStunFlag(char)
		if not char:FindFirstChild("IsStunned") then
			local stunFlag = Instance.new("BoolValue")
			stunFlag.Name = "IsStunned"
			stunFlag.Value = false
			stunFlag.Parent = char
		end
	end

	-- Add it if the character already exists
	if Player.Character then
		addStunFlag(Player.Character)
	end

	-- Also connect to CharacterAdded to handle respawns
	Player.CharacterAdded:Connect(addStunFlag)
end

local function ClearUnownedPlots(plot)
	for _, model in plot.UnpurchasedPlotPieces:GetChildren() do
		SetProperties(model, {Transparency=1, CanCollide=false})
		SetProperties(plot.PurchasePlotButtons:FindFirstChild(model.Name), {Transparency=1, CanCollide=false})
	end
end

local function OnPlayerAdded(Player)
	if #Players:GetPlayers() > 6 then Player:Kick("Server is full!") end
	
	if game.GameId == _G.testingGameId then -- Testing Server, testers only
		if Player:GetRankInGroup(79245806) < 2 then
			Player:Kick("You must be a tester to play this experience!")
		end
	end
	
	Leaderstats(Player)
	dataManagers[Player.UserId] = DataManager.New(Player)
	
	local friendBoost = Instance.new("NumberValue")
	friendBoost.Name = "FriendBoost"
	friendBoost.Value = 1
	friendBoost.Parent = Player
	
	playerBoosts[Player.UserId] = {}
	for _, plr in Players:GetPlayers() do
		if plr == Player then continue end
		local manager = PlotManager.GetPlot(plr.UserId)
		if manager == nil then 
			repeat 
				task.wait(0.1)
				manager = PlotManager.GetPlot(plr.UserId)
			until manager ~= nil
		end
		
		manager:UpdateStealPromptForPlayer(Player)
		manager:DisablePromptsForPlayer(Player)
		
		playerBoosts[plr.UserId] = playerBoosts[plr.UserId] or {}
		
		local success, result = pcall(function()
			return Player:IsFriendsWith(plr.UserId)
		end)
		if success and result then
			if not table.find(playerBoosts[Player.UserId], plr.UserId) then
				table.insert(playerBoosts[Player.UserId], plr.UserId)
			end
			if not table.find(playerBoosts[plr.UserId], Player.UserId) then
				table.insert(playerBoosts[plr.UserId], Player.UserId)
				plr:WaitForChild("FriendBoost").Value = (#playerBoosts[plr.UserId]*0.1)+1
			end
		end
	end
	
	friendBoost.Value = (#playerBoosts[Player.UserId]*0.1) + 1
	
	local playerStock = SeedStock.LoadStock(Player.UserId)
	
	repeat task.wait(0.1) until Player:FindFirstChild("OwnedPlot").Value ~= nil
	ClearUnownedPlots(Player.OwnedPlot.Value)
	local tpDest = Player.OwnedPlot.Value:WaitForChild("TpDest", 5)
	
	-- ================================================================== --
	-- // CORRECTED TOOL HANDLING LOGIC STARTS HERE
	-- ================================================================== --

	-- Create the temporary folder for holding tools during death/respawn
	local tempTools = Instance.new("Folder", Player)
	tempTools.Name = "TempTools" -- Matching your original folder name

	---- Give the player their starter tools ONCE when they first join.
	--for _, tool in ipairs(StarterTools) do
	--	tool:Clone().Parent = Player.Backpack
	--end

	-- This function saves ALL of the player's tools upon death.
	local function saveAllTools()
		local character = Player.Character
		if not character then return end

		-- 1. Save the EQUIPPED tool from the Character model.
		local equippedTool = character:FindFirstChildOfClass("Tool")
		if equippedTool then
			equippedTool.Parent = tempTools
		end

		-- 2. Save all tools from the Backpack.
		for _, tool in ipairs(Player.Backpack:GetChildren()) do
			tool.Parent = tempTools
		end
	end

	-- This function runs every time a new character is added (on spawn and respawn).
	local function onCharacterAdded(character)
		-- Teleport player to their plot
		local tpDest = Player.OwnedPlot.Value:WaitForChild("TpDest", 5)
		if tpDest then
			character:PivotTo(tpDest.CFrame)
		end

		-- Restore all saved tools from the temporary folder back into the backpack.
		for _, tool in ipairs(tempTools:GetChildren()) do
			tool.Parent = Player.Backpack
		end

		-- Handle the PVP Display on the character's head
		local head = character:WaitForChild("Head")
		local display = head:FindFirstChild("PvpDisplay")
		if not display then
			display = PvpDisplay:Clone()
			display.Parent = head
		end
		display.PvpText.Text = Player.PVPEnabled.Value and "Pvp: On" or "Pvp: Off"
		display.PvpText.TextColor3 = Player.PVPEnabled.Value and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)

		-- Connect the Died event to the new character's Humanoid
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(saveAllTools)
	end

	-- Connect the character setup function to the CharacterAdded event.
	Player.CharacterAdded:Connect(onCharacterAdded)

	-- If the character already exists when this script runs, manually call the setup function.
	if Player.Character then
		onCharacterAdded(Player.Character)
	end
	
end

local function OnPlayerRemoved(Player)
	SeedStock.SaveStock(Player.UserId)
	dataManagers[Player.UserId]:SaveData()
	dataManagers[Player.UserId] = nil
	
	for _, plr in Players:GetPlayers() do
		if plr == Player then continue end

		local success, result = pcall(function()
			return plr:IsFriendsWith(Player.UserId)
		end)
		
		if success and result then
			print("was friends")
			local playerIdx = table.find(playerBoosts[plr.UserId], Player.UserId)
			if playerIdx then
				table.remove(playerBoosts[plr.UserId], playerIdx)
			end
			
			plr.FriendBoost.Value = (#playerBoosts[plr.UserId]*0.1) + 1
			if plr.FriendBoost.Value < 1 then 
				plr.FriendBoost.Value = 1
			end
		end
		playerBoosts[Player.UserId] = nil
	end
end

local function OnServerShutdown()
	for _, player in Players:GetPlayers() do
		OnPlayerRemoved(player)
	end
end

--// Connections
Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoved)
game:BindToClose(OnServerShutdown)