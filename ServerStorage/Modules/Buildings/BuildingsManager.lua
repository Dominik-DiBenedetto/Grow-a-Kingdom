--// Services
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local MPS = game:GetService("MarketplaceService")
local TagService = game:GetService("CollectionService")
local AnalyticsService = game:GetService("AnalyticsService")

--// Variables
local Modules = SS.Modules
local BadgeManager = require(Modules.BadgeManager)
local SeedStock = require(Modules.SeedStock)

local BuildingsModules = Modules.Buildings
local BuildingClass = require(BuildingsModules.Building)
local BuildingIndex = require(BuildingsModules.BuildingIndex)
local GrowthBoostTracker = require(BuildingsModules.GrowthBoostTracker)

local ItemIndex = require(Modules.NPCs.ItemIndex)
local AnimalDropIndex = require(Modules.Animals.AnimalIndex)

local NPCManager = require(Modules.NPCs.NPCManager)

local Remotes = RS.Remotes 

local ToggleProxPrompt = Remotes.Client.ToggleProxPrompt
local PS = Remotes.Client.PlaySound
local SmokeEffect = Remotes.Client.SmokeEffect
local tutorialEvent = Remotes.Client.Tutorial
local PlayOrbEffect = Remotes.Client.PlayerOrbEffect
local UpdatePlantedBuildings = Remotes.Client.UpdatePlantedBuildings
local ShowNotification = Remotes.Client.ShowErrorMessage
local UpdateStock = Remotes.Client.UpdateStock
local SellerTalk = Remotes.Client.SellerTalk
local HaveBuildingsLoaded = Remotes.Client.FinishedLoadingBuildings

local FinishBuildingEvent = Remotes.Server.FinishBuilding
local AddItemToInventoryEvent = Remotes.Server.AddItemToInventory
local GetActiveBoosts = Remotes.Server.GetActiveBoosts


local BuildingTools = RS.BuildingTools

local ExtraInventorySpaceGamepassId = 1346076823
if game.GameId == _G.testingGameId then
	ExtraInventorySpaceGamepassId = 1340010271
end

--// Local Functions
local function FormatNumberWithCommas(amount)
	amount = math.round(amount)
	return tostring(amount):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function DeserializeCFrame(data)
	if not data or not data.pos or not data.rot then return CFrame.new() end
	local pos = Vector3.new(unpack(data.pos))
	local rot = CFrame.Angles(unpack(data.rot))
	return CFrame.new(pos) * rot
end

--// Module
local BuildingsManager = {}
BuildingsManager.__index = BuildingsManager

local Managers = {}

--// Creation
function BuildingsManager.New(player, existingBuildingData)
	local newManager = setmetatable({}, BuildingsManager)
	
	newManager.Owner = player
	newManager.Inventory = existingBuildingData["Inventory"] or {}
	newManager.PlantedBuildings = {}
	newManager.GrownBuildings = {}
	newManager.BuiltRarities = existingBuildingData["BuiltRarities"] or {}
	newManager.LoadedBuildings = existingBuildingData["Buildings"] or {}
	newManager.Loaded = false
	newManager.NPCManagers = {}
	newManager.ItemsInventory = existingBuildingData["ItemsInventory"] or {}
	
	newManager.LastLeaveTime = existingBuildingData["LeftAtTime"] or nil
	newManager.SpawnedNPCsCount = existingBuildingData["SpawnedNPCsCount"] or {}
	newManager.GrowthBoostTracker = GrowthBoostTracker.new(existingBuildingData["GrowthBoostTracker"] or {})
	
	newManager.MaxInventorySize = 8
	local success, hasPass = pcall(function()
		return MPS:UserOwnsGamePassAsync(player.UserId, ExtraInventorySpaceGamepassId)
	end)
	if success and hasPass then
		newManager.MaxInventorySize = 16
	end
	
	Managers[player.UserId] = newManager
	
	return newManager
end

function BuildingsManager.GetManagers(player)
	return Managers[player.UserId]
end

function BuildingsManager:LoadExistingBuildings()
	local growBatch = {}
	for idx, building in self.LoadedBuildings do
		local plotPiece = self.Owner.OwnedPlot.Value.PurchasedPlotPieces:FindFirstChild(building.PlotPiece)
		local newBuilding = BuildingClass.New(self.Owner, building.BuildingType, DeserializeCFrame(building.Position), plotPiece, self.GrowthBoostTracker, building)
		self.PlantedBuildings[newBuilding.Id] = newBuilding
		table.insert(growBatch, newBuilding.Id)
		--newBuilding:Grow()
		newBuilding:Load()
	end
	if self.Inventory["FinishedBuildings"] then
		local finishedBuildings = {}
		for _, building in self.Inventory["FinishedBuildings"] do
			local extraData = table.clone(BuildingIndex[building.Type])
			for key, val in building do
				extraData[key] = val
			end
			table.insert(finishedBuildings, extraData)
		end
		self.Inventory["FinishedBuildings"] = finishedBuildings
	end
	self.DoneLoading = true
	HaveBuildingsLoaded:FireClient(self.Owner)

end

--// Utilities
function BuildingsManager:HasSpaceInInventory()
	local inventoryCount = 0
	for buildingName, buildingCount in self.Inventory do
		if typeof(buildingCount) ~= "number" then 
			if typeof(buildingCount) ~= "table" then continue end
			inventoryCount += #buildingCount
			continue
		end
		inventoryCount += buildingCount
	end
	inventoryCount += #self.ItemsInventory

	return inventoryCount < self.MaxInventorySize
end

--// Actions
function BuildingsManager:PurchaseBuilding(buildingType, townHallLevel, usingRobux)
	local robuxPurchase = usingRobux or false
	
	if not self:HasSpaceInInventory() then
		ShowNotification:FireClient(self.Owner, "Reached max inventory limit ("..self.MaxInventorySize..")")
		return
	end
	
	if not robuxPurchase then
		if not BuildingIndex[buildingType] or not BuildingTools:FindFirstChild(buildingType) then return warn("Hacker?") end
		if townHallLevel < BuildingIndex[buildingType].TownHallRequired then return ShowNotification:FireClient(self.Owner, "Town hall level "..BuildingIndex[buildingType].TownHallRequired.." required!") end

		if self.Owner.leaderstats.Coin.Value < BuildingIndex[buildingType].Price then return ShowNotification:FireClient(self.Owner, "Not enough coin!") end
		if not SeedStock.CanPurchase(self.Owner.UserId, buildingType) then return ShowNotification:FireClient(self.Owner, "Out of stock!") end		

		self.Owner.leaderstats.Coin.Value -= BuildingIndex[buildingType].Price
		SeedStock.MakePurchase(self.Owner.UserId, buildingType)
		
		AnalyticsService:LogEconomyEvent(
			self.Owner,
			Enum.AnalyticsEconomyFlowType.Sink,
			"Coin", -- Currency name
			BuildingIndex[buildingType].Price, -- Cost
			self.Owner.leaderstats.Coin.Value, -- Balance post transaction
			Enum.AnalyticsEconomyTransactionType.Shop.Name, -- Transaction type
			buildingType -- Item SKU
		)
		
		local tutorialStep = self.Owner:FindFirstChild("TutorialStep")

		if tutorialStep and tutorialStep.Value == 2 then
			tutorialEvent:FireClient(self.Owner, 3) -- Let the client handle advancing to next step
		end
	end
	
	local seedClone = BuildingTools:FindFirstChild(buildingType):Clone()
	seedClone.Parent = self.Owner.Backpack

	PS:FireClient(self.Owner, "Buy", true, 0.2)

	UpdateStock:FireClient(self.Owner, buildingType, SeedStock.GetStock(self.Owner.UserId)[buildingType])

	if self.Inventory[buildingType] then
		self.Inventory[buildingType] = self.Inventory[buildingType] + 1
	else
		self.Inventory[buildingType] = 1
	end
	
	return true
end

function BuildingsManager:PlantBuilding(buildingName, cframe, plotPiece)
	-- Validate player actually owns the seed
	if self.Inventory[buildingName] then
		self.Inventory[buildingName] = self.Inventory[buildingName] - 1
		if self.Inventory[buildingName] == 0 then self.Inventory[buildingName] = nil end
	else
		return
	end
	
	-- Plant
	local building = BuildingClass.New(self.Owner, buildingName, cframe, plotPiece, self.GrowthBoostTracker)
	self.PlantedBuildings[building.Id] = building
	building:Grow()
	
	return building
end

function BuildingsManager:ApplyGrowthBoost(duration)
	for _, building in self.PlantedBuildings do
		building:AddActiveGrowthBoost(duration)
	end
end

function BuildingsManager.FinishBuilding(player, building)
	local manager = Managers[player.UserId]
	if not manager then return end
	
	if building then
		-- Restore metatable
		setmetatable(building, BuildingClass)
	end
	
	manager.PlantedBuildings[building.Id] = nil
	manager.GrownBuildings[building.Id] = building

	-- Npc 
	if building.NPCType then
		if manager.NPCManagers[building.Type] then
			if getmetatable(manager.NPCManagers[building.Type]) ~= BuildingClass then
				setmetatable(manager.NPCManagers[building.Type], NPCManager)
			end
			manager.NPCManagers[building.Type]:LevelUp()
		else
			if not building.Model then warn("Trying to make npc manager, but no building model") return end
			manager.NPCManagers[building.Type] = NPCManager.New(manager.Owner, manager.Owner.OwnedPlot.Value, building.NPCType, building.MaxNPCs, building.DefaultSpawnTime)
			manager.NPCManagers[building.Type]:ChangeDisplay(building.Model:WaitForChild("NPCSpawnDisplay", 3))
			if manager.LastLeaveTime then
				local spawnedNpcCount = manager.SpawnedNPCsCount[building.Type]
				if spawnedNpcCount then
					manager.NPCManagers[building.Type]:SpawnLoadedNPCs(spawnedNpcCount, manager.LastLeaveTime)
				end
			end
		end
	end

	-- Enable claim prox prompt

	local tutorialStep = manager.Owner:FindFirstChild("TutorialStep")

	if tutorialStep and tutorialStep.Value == 5 then
		-- Player is still in the tutorial (not completed)
		tutorialEvent:FireClient(manager.Owner, 6) -- Let the client handle advancing to next step
	end
	
	task.defer(function()
		if tutorialStep.Value < 7 then
			repeat task.wait() until tutorialStep.Value >= 7
		end

		local primary = building.Model.PrimaryPart
		if not primary then return end
		
		local proxPrompt = building.Model.PrimaryPart:FindFirstChildWhichIsA("ProximityPrompt")
		proxPrompt.Triggered:Connect(function(plr)
			if manager.Owner ~= plr then return end -- Make sure only owner can claim prompt

			if not manager.Inventory["FinishedBuildings"] then
				manager.Inventory["FinishedBuildings"] = {building}
			else
				table.insert(manager.Inventory["FinishedBuildings"], building)
			end
			-- Add the tool to their backpack
			local builtTool = RS.BuildingTools:FindFirstChild(building.Type):Clone()
			builtTool.Name = builtTool.Name.." Completed"
			builtTool.Parent = manager.Owner.Backpack

			PlayOrbEffect:FireClient(manager.Owner, building.Model.PrimaryPart.Position)

			if tutorialStep and tutorialStep.Value == 7 then
				-- Player is still in the tutorial (not completed)
				tutorialEvent:FireClient(manager.Owner, 8) -- Let the client handle advancing to next step
			end

			PS:FireClient(manager.Owner, "Collect", true, 0.2)

			building.Model:Destroy()
			manager.GrownBuildings[building.Id] = nil
			if manager.NPCManagers[building.Type] then
				if manager.NPCManagers[building.Type].Level > 1 then
					local newBuilding = manager.Owner.OwnedPlot.Value.PurchasedPlotPieces:FindFirstChild(building.Type, true)
					if newBuilding then
						local newDisplay = newBuilding:FindFirstChild("NPCSpawnDisplay")
						if newDisplay then
							manager.NPCManagers[building.Type]:ChangeDisplay(newDisplay)
						end
					end
				end
				
				local prevLevel = manager.NPCManagers[building.Type].Level
				manager.NPCManagers[building.Type]:LevelDown()
				if prevLevel == 1 then
					manager.NPCManagers[building.Type] = nil
				end
			end

			local buildingRarity = building["Rarity"]
			if not table.find(manager.BuiltRarities, buildingRarity) then
				local wasSuccessful = BadgeManager.AwardBadge(manager.Owner, "Completed"..buildingRarity.."Building")
				if wasSuccessful then
					table.insert(manager.BuiltRarities, buildingRarity)
				end
			end
		end)
		ToggleProxPrompt:FireAllClients(proxPrompt, false, manager.Owner, true)
	end)
end

function BuildingsManager.AddItemToInventory(player, item)
	local manager = Managers[player.UserId]
	table.insert(manager.ItemsInventory, item)
end

AddItemToInventoryEvent.Event:Connect(BuildingsManager.AddItemToInventory)

function BuildingsManager:SellInventory()
	if not self.Inventory["FinishedBuildings"] then self.Inventory["FinishedBuildings"] = {} end
	
	local mult = 1
	local boosts = GetActiveBoosts:Invoke(self.Owner)
	if boosts and boosts["Cash"] then
		mult = 2
	end
	local premiumMult = 1
	if self.Owner.MembershipType == Enum.MembershipType.Premium then
		premiumMult = 1.1
	end
	
	local totalReward = 0
	
	local function getItemValue(item)
		-- If item has its own SellValue attribute, use that
		if item:GetAttribute("SellValue") then
			return item:GetAttribute("SellValue")
		end

		-- Otherwise, fallback to ItemIndex static value
		local data = ItemIndex[item.Name]
		if data and data.Value then
			return data.Value
		end

		return nil
	end

	for _, item in pairs(self.Owner.Backpack:GetChildren()) do
		if not TagService:HasTag(item, "Item") then
			continue
		end

		local value = getItemValue(item)
		if value then
			totalReward += (value * self.Owner.FriendBoost.Value * premiumMult) * mult
			item:Destroy()
		end
	end
	
	local charTool = self.Owner.Character:FindFirstChildWhichIsA("Tool")
	if charTool and TagService:HasTag(charTool, "Item") then
		local value = getItemValue(charTool)
		if value then
			totalReward += (value * self.Owner.FriendBoost.Value * premiumMult) * mult
			charTool:Destroy()
		end
	end
	
	for _, building in pairs(self.Inventory["FinishedBuildings"]) do
		totalReward += (building.Reward * self.Owner.FriendBoost.Value * premiumMult) * mult

		local completedName = building.Type .. " Completed"

		local backpackTool = self.Owner.Backpack:FindFirstChild(completedName)
		if backpackTool then
			backpackTool:Destroy()
		end

		local characterTool = self.Owner.Character and self.Owner.Character:FindFirstChild(completedName)
		if characterTool then
			characterTool:Destroy()
		end
	end
	-- Add total reward to player's cash
	self.Owner.leaderstats.Coin.Value += math.floor(totalReward)
	self.ItemsInventory = {}
	self.Inventory["FinishedBuildings"] = {}
	
	-- Log to roblox economy analytics
	AnalyticsService:LogEconomyEvent(
		self.Owner,
		Enum.AnalyticsEconomyFlowType.Source,
		"Coin", -- Currency name
		math.floor(totalReward), -- Amount earned
		self.Owner.leaderstats.Coin.Value, -- Current balance
		Enum.AnalyticsEconomyTransactionType.Shop.Name -- Transaction type
	)

	-- Send one message with the total
	SellerTalk:FireClient(self.Owner, "Here is " .. FormatNumberWithCommas(totalReward) .. "¢")
	PS:FireClient(self.Owner, "Sell", true, 0.2)
	ShowNotification:FireClient(self.Owner, "Sold for " .. FormatNumberWithCommas(totalReward).."¢", "earn")

	PlayOrbEffect:FireClient(self.Owner, game.Workspace.Map.Booth.Seller.PrimaryPart.Position)
	return true
end

function BuildingsManager:RemoveBuilding(id)
	if self.GrownBuildings[id] then
		self.GrownBuildings[id]:Delete()
		self.GrownBuildings[id] = nil
	elseif self.PlantedBuildings[id] then
		self.PlantedBuildings[id]:Delete()
		self.PlantedBuildings[id] = nil
	end
end

function BuildingsManager:InstaGrowBuildings()
	local grown = false
	for _, building in self.PlantedBuildings do
		building:InstaGrow()
		grown = true
	end
	return grown
end

--// Saving & Cleanup

function BuildingsManager:GetForSaving()
	local buildings = {}
	for _, building in self.PlantedBuildings do
		table.insert(buildings, building:Serialize())
	end
	for _, building in self.GrownBuildings do
		table.insert(buildings, building:Serialize())
	end
	local finishedBuildings = {}
	if self.Inventory["FinishedBuildings"] then
		for _, building in self.Inventory["FinishedBuildings"] do
			if getmetatable(building) == BuildingClass then 
				table.insert(finishedBuildings, building:SerializeFinishedBuilding())
			else
				table.insert(finishedBuildings, building)
			end
		end
	end
	self.Inventory["FinishedBuildings"] = finishedBuildings
	
	local spawnedNPCCounts = {}
	for buildingType, manager in self.NPCManagers do
		spawnedNPCCounts[buildingType] = manager.SpawnedNPCsCount
	end
	
	return {
		["Inventory"] = self.Inventory,
		["Buildings"] = buildings,
		["BuiltRarities"] = self.BuiltRarities,
		["ItemsInventory"] = self.ItemsInventory,
		["LeftAtTime"] = os.time(),
		["SpawnedNPCsCount"] = spawnedNPCCounts,
		["GrowthBosotTracker"] = self.GrowthBoostTracker,
		
	}
end

function BuildingsManager:Cleanup()
	setmetatable(self, nil)
end

FinishBuildingEvent.Event:Connect(BuildingsManager.FinishBuilding)

return BuildingsManager
