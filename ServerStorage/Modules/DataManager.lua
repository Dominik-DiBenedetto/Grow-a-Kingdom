--// Services
local DSS = game:GetService("DataStoreService")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--// Variables
local Modules = SS.Modules
local PlotManager = require(Modules.PlotManager)

local BuildingsDataStore = DSS:GetDataStore("ProductionBuildingsDatastore")
local CurrencyDataStore = DSS:GetOrderedDataStore("ProductionCurrencyDatastore")

local BuildingTools = RS.BuildingTools

local Remotes = RS.Remotes
local UpdatePlantedBuildings = Remotes.Client.UpdatePlantedBuildings
local TutorialEvent = RS.Remotes.Client.Tutorial

local GetArmor = RS.Remotes.Server.ArmorSystem.GetInventory
local LoadArmor = RS.Remotes.Server.ArmorSystem.LoadInventory

local GetWeapons = RS.Remotes.Server.Weapons.GetInventoryForSaving
local LoadWeapons = RS.Remotes.Server.Weapons.LoadSavedWeapons

local PvpDisplay = RS.VFX.PvpDisplay

--// Local Functions
local function SafeLoad(datastore, key)
	local success, result = pcall(function()
		return datastore:GetAsync(key)
	end)

	if success then
		return result
	else
		warn("[Load Error] " .. key .. ": " .. result)
		return nil
	end
end


local function SafeSave(datastore, key, value)
	local success, err = pcall(function()
		datastore:SetAsync(key, value)
	end)

	if not success then
		warn("[Save Error] " .. key .. ": " .. err)
	end

	return success
end

--// Module

local DataManager = {}
DataManager.__index = DataManager

function DataManager.New(player)
	local manager = setmetatable({}, DataManager)
	manager.Player = player
	manager.PlotManager = nil
	
	manager:LoadData()
	
	return manager
end

function DataManager:LoadData()
	--// Load Buildings
	local data = SafeLoad(BuildingsDataStore, (self.Player.UserId).."_buildings")
	if not data or not data["Plot"] or not data["Buildings"] then
		data = {
			["Plot"] = {}, 
			["Buildings"] = {
				["Inventory"] = {
					["FinishedBuildings"] = {}
				},
				["Buildings"] = {},
				["BuiltRarities"] = {},
				["ItemsInventory"] = {},
			}, 
			["PVP"] = false,
			["TutorialStep"] = 1,
			["TimedRewardsElapsed"] = 0
		}
	end
	
	self.PlotManager = PlotManager.New(self.Player, data["Plot"], data["Buildings"])
	
	--// Load Inventory
	if self.PlotManager.BuildingsManager == nil then
		repeat task.wait(0.1) until self.PlotManager.BuildingsManager ~= nil
	end
	local inventory = self.PlotManager.BuildingsManager["Inventory"]
	
	task.spawn(function()
		for seedName, val in inventory do
			if typeof(val) == "table" then continue end
			
			local seed = string.split(seedName, "_")[1]
			if val > 1 then
				for i=1,val do
					local seedClone = BuildingTools:FindFirstChild(seed):Clone()
					seedClone.Parent = self.Player.Backpack
				end
			else
				local seedClone = BuildingTools:FindFirstChild(seed):Clone()
				seedClone.Parent = self.Player.Backpack
			end
		end
	end)
	
	task.spawn(function()
		for _, itemName in self.PlotManager.BuildingsManager["ItemsInventory"] do
			if typeof(itemName) == "table" then continue end
			
			if string.find(itemName, "Meat") then
				local meat = RS.AnimalDrops.Meat:Clone()
				meat.Name = itemName
				
				local weight = string.split(string.split(itemName, " ")[2], "kg")[1]
				weight = tonumber(weight)
				
				if not weight then continue end
				
				meat:SetAttribute("Saved", true)
				meat:SetAttribute("SellValue", weight*10)
				meat:SetAttribute("Weight", weight)
				
				local baseSize = Vector3.new(1, 0.1, 1.6) -- Adjust base size as needed
				local sizeMultiplier = math.clamp(weight / 5, 0.5, 8) -- Prevent too small or too big
				meat.Plane.Size = baseSize * sizeMultiplier
				meat.Parent = self.Player.Backpack
			else
				local itemClone = RS.Items:FindFirstChild(itemName):Clone()
				itemClone.Parent = self.Player.Backpack
			end
		end
	end)
	
	task.spawn(function()
		if not inventory["FinishedBuildings"] then return end
		for _, building in inventory["FinishedBuildings"] do
			local builtTool = RS.BuildingTools:FindFirstChild(building.Type):Clone()
			builtTool.Name = builtTool.Name.." Completed"
			builtTool.Parent = self.Player.Backpack
		end
	end)
	
	self.PlotManager:LoadExpandedPlots()
	
	task.delay(4, function()
		self.PlotManager.BuildingsManager:LoadExistingBuildings()
		task.spawn(function()
			repeat task.wait(0.1) until self.PlotManager.BuildingsManager.DoneLoading
			self.PlotManager.DoneLoading = true
		end)
	end)
	
	--// Load Currency
	local cash = SafeLoad(CurrencyDataStore, (self.Player.UserId).."_currency") or 100
	self.Player.leaderstats.Coin.Value = cash
	
	--// Load Other State
	self.Player.PVPEnabled.Value = data["PVP"]
	
	if data["TutorialStep"] == 0 or data["TutorialStep"] == nil then data["TutorialStep"] = 1 end
	
	self.Player.TutorialStep.Value = data["TutorialStep"]
	TutorialEvent:FireClient(self.Player, data["TutorialStep"], true)
	
	if data["TutorialStep"] == 9 then
		local plot = self.Player.OwnedPlot
		repeat task.wait(0.5) until plot.Value ~= nil
		
		local connection
		connection = plot.Value.TownHallPlotPiece.Touched:Connect(function(hit)
			local plr = Players:GetPlayerFromCharacter(hit.Parent) or Players:GetPlayerFromCharacter(hit.Parent.Parent)
			if not plr or plr ~= self.Player then return end

			TutorialEvent:FireClient(self.Player, 10) -- Let the client handle advancing to next step
			connection:Disconnect()
		end)
	end
	
	local char = self.Player.Character or self.Player.CharacterAdded:Wait()
	local head = char.Head
	if head then
		local display = PvpDisplay:Clone()
		display.PvpText.Text = data["PVP"] and "Pvp: On" or "Pvp: Off"
		display.PvpText.TextColor3 = data["PVP"] and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
		display.Parent = head
	end
	self.Player.PVPEnabled.Changed:Connect(function(newVal)
		local char = self.Player.Character or self.Player.CharacterAdded:Wait()
		local head = char.Head
		local display = head:FindFirstChild("PvpDisplay")
		if not display then
			display = PvpDisplay:Clone()
			display.PvpText.Text = data["PVP"] and "Pvp: On" or "Pvp: Off"
			display.PvpText.TextColor3 = data["PVP"] and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
			display.Parent = head
		end
		display.PvpText.Text = newVal and "Pvp: On" or "Pvp: Off"
		display.PvpText.TextColor3 = newVal and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
	end)
	
	--// Load Timed Rewards
	local TimedRewardsElapsed = Instance.new("NumberValue", self.Player)
	TimedRewardsElapsed.Name = "TimedRewardsElapsed"
	
	local TimedRewardsClaimed = Instance.new("StringValue", self.Player)
	TimedRewardsClaimed.Name = "TimedRewardsClaimed"

	if not data["TimedRewardsElapsed"] then
		data["TimedRewardsElapsed"] = 0
	end
	
	if not data["TimedRewardsClaimed"] then
		data["TimedRewardsClaimed"] = ""
	end
	
	if string.find(data["TimedRewardsClaimed"], "7200") then
		data["TimedRewardsElapsed"] = 0
		data["TimedRewardsClaimed"] = ""
	end
	TimedRewardsElapsed.Value = data["TimedRewardsElapsed"]
	TimedRewardsClaimed.Value = data["TimedRewardsClaimed"]

	LoadArmor:Fire(self.Player, data["Armor"] or {})
	LoadWeapons:Fire(self.Player, data["Weapons"] or {
		["Equipped"] = "Iron Sword",
		["Unequipped"] = {}
	})

end

function DataManager:SaveData()
	--// Save Plot & Inventory
	local plotData = self.PlotManager:GetPlotForSaving()
	
	local tutorialStep = self.Player.TutorialStep.Value
	if tutorialStep == 11 then tutorialStep = 12 end
	
	local buildingsToSave = self.PlotManager.BuildingsManager:GetForSaving()
	local armor = GetArmor:Invoke(self.Player, true)
	local weapons = GetWeapons:Invoke(self.Player)
	
	local buildingsData = {
		["Plot"] = plotData,
		["Buildings"] = buildingsToSave,
		["PVP"] = self.Player.PVPEnabled.Value,
		["TutorialStep"] = tutorialStep,
		["TimedRewardsElapsed"] = self.Player.TimedRewardsElapsed.Value,
		["TimedRewardsClaimed"] = self.Player.TimedRewardsClaimed.Value,
		["Armor"] = armor,
		["Weapons"] = weapons,
	}
	
	SafeSave(BuildingsDataStore, (self.Player.UserId).."_buildings", buildingsData)
	
	--// Save Currency
	SafeSave(CurrencyDataStore, (self.Player.UserId).."_currency", self.Player.leaderstats.Coin.Value)
	
	self.PlotManager:CleanupPlot()
	
	task.delay(2, function()
		setmetatable(self, nil)
	end)
end

return DataManager
