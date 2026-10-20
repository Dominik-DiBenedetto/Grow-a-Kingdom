local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local TagService = game:GetService("CollectionService")
local AnalyticsService = game:GetService("AnalyticsService")

local Remotes = RS.Remotes
local BuildingTools = RS.BuildingTools
local Modules = SS.Modules

local UpdateStock = Remotes.Client.UpdateStock
local UpdateTimerEvent = Remotes.Client.UpdateTimer
local UpdatePlantedBuildings = Remotes.Client.UpdatePlantedBuildings
local UpdateTownHallUpgradeFrame = Remotes.Client.UpdateTownHallInfo								
local ShowNotification = Remotes.Client.ShowErrorMessage
local SellerTalk = Remotes.Client.SellerTalk
local ToggleProxPrompt = Remotes.Client.ToggleProxPrompt
local PS = RS.Remotes.Client.PlaySound
local SmokeEffect = RS.Remotes.Client.SmokeEffect
local tutorialEvent = RS.Remotes.Client.Tutorial

local BuildingIndex = require(Modules.Buildings.BuildingIndex)
local SeedStock = require(Modules.SeedStock)
local PlotManager = require(Modules.PlotManager)
local TownHallUpgrades = require(Modules.TownHallUpgrades)
local BadgeManager = require(Modules.BadgeManager)
local ItemIndex = require(Modules.NPCs.ItemIndex)

local TimedRewards = {
	["300"] = 1000,
	["600"] = 2500,
	["900"] = 5000,
	["1200"] = 7500,
	["1800"] = 10000,
	["2700"] = 15000,
	["3600"] = 20000,
	["5400"] = 25000,
	["7200"] = 50000,

}


local PlotManagers = {}

--// Helpers
local function CombineDicts(t1,t2)
	local result = t1

	for k, v in pairs(t2) do
		result[k] = v
	end

	return result
end

local function GenerateTimeId()
	return tostring(os.time()) .. tostring(math.random(1000, 9999))
end

local function FormatNumberWithCommas(amount)
	amount = math.round(amount)
	return tostring(amount):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end


local function AnchorModel(model)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
end

local function SetProps(model, prop, value)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part[prop] = value
		end
	end
end

--// Events

local events = {
	--// Remote events
	["GetBuilding"] = function(player, seed)
		local manager = PlotManagers[player.UserId]
		
		manager.BuildingsManager:PurchaseBuilding(seed, manager.TownHallLevel)
	end,
	["RestockSeeds"] = function(player)
		SeedStock.Restock(player.UserId, false)
		UpdateTimerEvent:FireClient(player, SeedStock.GetTimeLeft(player.UserId))
	end,
	["UseGroupRestock"] = function(player)
		if not player:IsInGroup(79245806) then return end
		SeedStock.Restock(player.UserId, false)
		UpdateTimerEvent:FireClient(player, SeedStock.GetTimeLeft(player.UserId), false)
	end,
	["PlantBuilding"] = function(player, seedName, position)	
		local manager = PlotManagers[player.UserId]

		-- Validate Correct Plot (and nothing else underneath)
		local direction = Vector3.new(0, -(position.Y+2), 0)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {player.OwnedPlot.Value}
		raycastParams.FilterType = Enum.RaycastFilterType.Include

		local result = workspace:Raycast(position.Position+Vector3.new(0,1,0), direction, raycastParams)
		local onPlot = false
		
		if result and player.OwnedPlot.Value and result.Instance.Parent == player.OwnedPlot.Value.PurchasedPlotPieces then onPlot = true 
		else return print("not on plot") end
		
		if onPlot == false then 
			--seed:Destroy()
			return
		end
		
		-- Validate Not Overlapping Other Buildings
		local building = manager.BuildingsManager:PlantBuilding(seedName, position, result.Instance)
		if not building then return end
		
		local seed = building.Model
		local id = building.Id
		
		seed.Parent = result.Instance
		local primary = seed
		if seed:IsA("Model") then primary = seed.PrimaryPart end

		for _, part in primary:GetTouchingParts() do
			if part.Parent == seed or string.find(part.Name, "PlotPiece") then continue end
			if part.Parent.Parent and string.find(part.Parent.Parent.Name, "PlotPiece") then
				ShowNotification:FireClient(player, "Buildings are overlapping!")
				manager.BuildingsManager:RemoveBuilding(id)
				
				-- Give Seed Back
				if not manager.BuildingsManager.Inventory[seedName] then
					manager.BuildingsManager.Inventory[seedName] = 1
				else
					manager.BuildingsManager.Inventory[seedName] += 1
				end
				
				return
			end
		end
		
		-- Validations passed, keep planted building!
		
		-- Apply effects
		PS:FireClient(player, "Build", true, 0.1)
		SmokeEffect:FireClient(player, seed.PrimaryPart, true)
		
		local tutorialStep = player:FindFirstChild("TutorialStep")

		if tutorialStep and tutorialStep.Value == 4 then
			-- Player is still in the tutorial (not completed)
			tutorialEvent:FireClient(player, 5) -- Let the client handle advancing to next step
		end
		
		UpdatePlantedBuildings:FireClient(player, manager.BuildingsManager.PlantedBuildings)

		local char = player.Character or player.CharacterAdded:Wait()
		
		local tool = player.Backpack:FindFirstChild(seedName)
		if not manager.BuildingsManager.Inventory[seedName] then -- That was the last seed of that type they owned
			tool = char:FindFirstChild(seedName)
			if tool then
				task.delay(2, function()
					tool:Destroy()
				end)
			end
		else -- They have more seeds, keep the current seed equipped delete another one thats the same
			if tool then
				tool:Destroy()
			end
		end	
	end,
	["GrowPlant"] = function(player, batchedBuildingsToGrow)
		local manager = PlotManagers[player.UserId]
		if not manager then 
			manager = PlotManager.GetPlot(player.UserId) 
			PlotManagers[player.UserId] = manager
		end
		
		if not manager then
			repeat task.wait(0.1)
				manager = PlotManager.GetPlot(player.UserId) 
			until manager ~= nil
			PlotManagers[player.UserId] = manager
		end
		
		manager.BuildingsManager:GrowBatchedBuildings(batchedBuildingsToGrow)
		UpdatePlantedBuildings:FireClient(player, manager.BuildingsManager.PlantedBuildings)
	end,

	["SellBuildings"] = function(player)
		local manager = PlotManagers[player.UserId]

		local playerData = manager.BuildingsManager.Inventory
		if not playerData or (not playerData["FinishedBuildings"] and #manager.BuildingsManager.ItemsInventory == 0) or (#playerData["FinishedBuildings"] == 0 and #manager.BuildingsManager.ItemsInventory == 0) then
			SellerTalk:FireClient(player, "I don't see anything...")
			PS:FireClient(player, "Talk", 0.3)
			return
		end

		local sold = manager.BuildingsManager:SellInventory()
		if not sold then return warn("Sell failed") end
		
		local tutorialStep = player:FindFirstChild("TutorialStep")

		if tutorialStep and tutorialStep.Value <= 11 then
			-- Player is still in the tutorial (not completed)
			tutorialEvent:FireClient(player, 10) -- Let the client handle advancing to next step
			
			--test
			local plot = player.OwnedPlot.Value
			local connection
			connection = plot.TownHallPlotPiece.TownHall.Base.Touched:Connect(function(hit)
				local plr = Players:GetPlayerFromCharacter(hit.Parent) or Players:GetPlayerFromCharacter(hit.Parent.Parent)
				if not plr or plr ~= player then return end
				
 				tutorialEvent:FireClient(player, 11) -- Let the client handle advancing to next step
				connection:Disconnect()
			end)
		else
			--print("Tutorial inactive or complete.")
		end
		
		manager:MakeSale() -- track sales for favorite prompt
	end,
	["CheckPrice"] = function(player)
		if not PlotManagers[player.UserId] then
			PlotManagers[player.UserId] = PlotManager.GetPlot(player.UserId)
		end

		local equippedTool = nil
		local character = player.Character
		if character then
			for _, item in ipairs(character:GetChildren()) do
				if item:IsA("Tool") then
					equippedTool = item
				end
			end
		end

		if not equippedTool or (not equippedTool.Name:find(" Completed") and not TagService:HasTag(equippedTool, "Item")) then
			SellerTalk:FireClient(player, "I don't see anything...")
			PS:FireClient(player, "Talk", 0.3)
			return
		end
		
		if TagService:HasTag(equippedTool, "Item") then
			local itemData = ItemIndex[equippedTool.Name]
			if not itemData then
				SellerTalk:FireClient(player, "I can't value that...")
				return
			end
			
			local value = itemData.Value
			if not value then
				SellerTalk:FireClient(player, "I can't value that...")
				return
			end
			
			local message = "That is worth ¢" .. FormatNumberWithCommas(value)
			SellerTalk:FireClient(player, message)

			return
		end

		local buildingName = string.gsub(equippedTool.Name, " Completed", "")
		local buildingInfo = BuildingIndex[buildingName]

		if not buildingInfo or not buildingInfo.Reward then
			SellerTalk:FireClient(player, "I can't value that...")
			return
		end

		-- Count how many same tools in Backpack
		local backpack = player:FindFirstChild("Backpack")
		local count = 1 -- already holding one

		if backpack then
			for _, item in ipairs(backpack:GetChildren()) do
				if item:IsA("Tool") and item.Name == equippedTool.Name then
					count = count + 1
				end
			end
		end

		local totalValue = buildingInfo.Reward
		local formattedValue = FormatNumberWithCommas(totalValue)

		local message = "That is worth ¢" .. formattedValue
		if count > 1 then
			message = message .. " (" .. count .. "x)"
		end

		SellerTalk:FireClient(player, message)
	end,

	["UpgradeTownHall"] = function(player)
		local manager = PlotManagers[player.UserId]
		
		local TownHallLevel = manager.TownHallLevel
		
		if TownHallLevel+1 > #TownHallUpgrades.TownHalls then return ShowNotification:FireClient(player, "Town Hall Max Level!") end
		local NextTownHallData = TownHallUpgrades.TownHalls[TownHallLevel+1]
		
		if player.leaderstats.Coin.Value < NextTownHallData["Price"] then return ShowNotification:FireClient(player, "Not enough coins!") end
		player.leaderstats.Coin.Value -= NextTownHallData["Price"]
		manager.TownHallLevel = TownHallLevel+1
		
		BadgeManager.AwardBadge(player, "TownHall"..(TownHallLevel+1))
		
		manager:LoadTownHall()
		
		local nextCost = 0
		if manager.TownHallLevel+1 <= #TownHallUpgrades.TownHalls then
			nextCost = TownHallUpgrades.TownHalls[PlotManagers[player.UserId].TownHallLevel+1]["Price"]
		end
		
		UpdateTownHallUpgradeFrame:FireClient(player, TownHallLevel+1, nextCost)
	end,
	
	["UpgradeFence"] = function(player)
		if not PlotManagers[player.UserId] then PlotManagers[player.UserId] = PlotManager.GetPlot(player.UserId) end
		
		PlotManagers[player.UserId]:UpgradeFence()
	end,

	["ToggleUI"] = function(player, screenGUI, state)
		screenGUI.Enabled = state
	end,
	
	["SetPvpEnabled"] = function(player, enabled)
		local pvpEnabled = player:FindFirstChild("PVPEnabled")
		if not pvpEnabled then return end
		
		pvpEnabled.Value = enabled
	end,
	
	["UpdateTutorialStep"] = function(player, val)
		if val < player.TutorialStep.Value then return end
		player.TutorialStep.Value = val
		
		if player.TutorialStep.Value >= 11 then
			local pvpVal = player:FindFirstChild("PVPEnabled")
			if not pvpVal then return end
			
			pvpVal.Value = true
		end
	end,
	
	--// Remote functions
	
	["ClaimTimedReward"] = function(player, rewardTime)
		local reward = TimedRewards[tostring(rewardTime)]
		if not reward or player.TimedRewardsElapsed.Value < rewardTime then return false end
		
		player.leaderstats.Coin.Value += reward
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Coin", -- Currency name
			reward,
			player.leaderstats.Coin.Value, -- Balance post transaction
			Enum.AnalyticsEconomyTransactionType.TimedReward.Name -- Transaction type
		)
		player.TimedRewardsClaimed.Value ..= tostring(rewardTime).." "
		if string.find(player.TimedRewardsClaimed.Value, "7200") then
			player.TimedRewardsElapsed.Value = 0
			player.TimedRewardsClaimed.Value = ""
		end
		return true
	end,
	
	["CheckOwnsBuilding"] = function(player, seedName)
		local manager = PlotManagers[player.UserId]

		return manager.BuildingsManager.Inventory[seedName]
	end,
	["GetPlantedBuildings"] = function(player)
		local manager = PlotManagers[player.UserId]

		return manager.BuildingsManager.Inventory
	end,
	["GetGrowTimeForBuilding"] = function(player, buildingType)
		return BuildingIndex[buildingType]["GrowTime"]
	end,
	["RetrieveGrowTime"] = function(player, id)
		local manager = PlotManagers[player.UserId]

		local building = manager.BuildingsManager.PlantedBuildings[id]
		if not building then return end
		
		local timeElapsed = os.time() - building["PlantedAtTime"]
		local timeLeft = math.max(building["GrowTime"] - timeElapsed, 0)
		
		return timeLeft
	end,
	["HasSpaceInInventory"] = function(player)
		local manager = PlotManagers[player.UserId]
		
		return manager.BuildingsManager:HasSpaceInInventory()
	end,
}

for _, remote in Remotes.Server:GetChildren() do
	if not events[remote.Name] then continue end
	if remote:IsA("RemoteEvent") then
		remote.OnServerEvent:Connect(events[remote.Name])
	elseif remote:IsA("BindableEvent") then
		remote.Event:Connect(events[remote.Name])
	elseif remote:IsA("RemoteFunction") then
		remote.OnServerInvoke = events[remote.Name]
	end
end

Players.PlayerAdded:Connect(function(player)
	local manager
	manager = PlotManager.GetPlot(player.UserId) 
	PlotManagers[player.UserId] = manager

	if not manager then
		repeat task.wait(0.1)
			manager = PlotManager.GetPlot(player.UserId) 
		until manager ~= nil
		PlotManagers[player.UserId] = manager
	end
end)