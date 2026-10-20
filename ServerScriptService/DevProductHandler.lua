--// Services
local MPS = game:GetService("MarketplaceService")
local DSS = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")

--// Variables
local purchaseHistoryStore = DSS:GetDataStore("ProductionPurchaseHistory")
local GiftStore = DSS:GetDataStore("ProductionPendingGifts")

local Modules = SS.Modules
local SeedStock = require(Modules.SeedStock)
local BuildingIndex = require(Modules.Buildings.BuildingIndex)
local PlotManager = require(Modules.PlotManager)
local DataStoreQueue = require(Modules.DataStoreQueue)
local CrateIndex = require(RS.ModuleScripts.Armor.Crates.CrateIndex)

local Remotes = RS.Remotes
local UpdatePlantedBuildings = Remotes.Client.UpdatePlantedBuildings
local ShowNotification = RS.Remotes.Client.ShowErrorMessage

local SendGiftRequestEvent = Remotes.Server.SendGiftRequest
local PurchaseCrateRobux = Remotes.Server.ArmorSystem.RobuxPurchaseCrate

local BuildingTools = RS.BuildingTools

_G.testingGameId = 7943457956
local productIdByName = {
	instantRestock = 3347007060,
	instantRestockArmor = 3365422516,
	
	buildAll = 3333675942,
	tinyCoinsBundle = 3355981985,
	smallCoinsBundle = 3355982175,
	mediumCoinsBundle = 3355982388,
	averageCoinsBundle = 3355982588,
	bigCoinsBundle = 3355982749,
	giantCoinsBundle = 3355982936,
	
	cashBoost1Minute = 3356207878,
	cashBoost10Minute = 3356208056,
	cashBoost30Minute = 3356208353,

	growthBoost1Minute = 3358412601,
	growthBoost10Minute = 3358412764,
	growthBoost30Minute = 3358413089,
	
	eliteSword = 3365492816,
}

local crateIds = {
	["Cardboard Box"] = 3365424279,
	["Wooden Box"] = 3365425069,
}

if game.GameId == _G.testingGameId then -- Switch to testing server product id's
	productIdByName = {
		instantRestock = 3333675417,
		instantRestockArmor = 3364736704,
		buildAll = 3333675942,
		
		cashBoost1Minute = 3356062406,
		cashBoost10Minute = 3356062406,
		cashBoost30Minute = 3356062406,
		
		growthBoost1Minute = 3358268638,
		growthBoost10Minute = 3356208056,
		growthBoost30Minute = 3356208056,
		
		tinyCoinsBundle = 3355981985,
		smallCoinsBundle = 3355982175,
		mediumCoinsBundle = 3355982388,
		averageCoinsBundle = 3355982588,
		bigCoinsBundle = 3355982749,
		giantCoinsBundle = 3355982936,
	}
end

local giftQueue = DataStoreQueue.new()
local retryQueueByUserId = {}

local sessionGiftRequestsBySender = {}     -- indexed by senderId
local sessionGiftRequestsByRecipient = {}  -- indexed by recipientId

--// Gifting Functions
local function generateGiftId(senderId, recipientId)
	return "gift_" .. senderId .. "_" .. recipientId .. "_" .. os.time()
end

local function removeGiftFromList(list, giftId)
	for i = #list, 1, -1 do
		if list[i].giftId == giftId then
			table.remove(list, i)
			break
		end
	end
end

local function cleanupGift(giftData)
	local giftKeyString = "gift_" .. giftData.giftId
	local indexKey = "gift_index_" .. giftData.recipientId

	giftQueue:Enqueue(function()
		GiftStore:RemoveAsync(giftKeyString)
	end)

	giftQueue:Enqueue(function()
		GiftStore:UpdateAsync(indexKey, function(old)
			local newIndex = {}
			for _, key in ipairs(old or {}) do
				if key ~= giftKeyString then
					table.insert(newIndex, key)
				end
			end
			return newIndex
		end)
	end)

	removeGiftFromList(sessionGiftRequestsBySender[giftData.senderId] or {}, giftData.giftId)
	removeGiftFromList(sessionGiftRequestsByRecipient[giftData.recipientId] or {}, giftData.giftId)
end

local function SendGiftRequest(sender, recipient, productId)
	local giftId = generateGiftId(sender.UserId, recipient.UserId)
	local giftKey = "gift_" .. giftId

	local newRequest = {
		senderId = sender.UserId,
		recipientId = recipient.UserId,
		productId = productId,
		timestamp = os.time(),
		giftId = giftId,
	}

	sessionGiftRequestsBySender[sender.UserId] = sessionGiftRequestsBySender[sender.UserId] or {}
	table.insert(sessionGiftRequestsBySender[sender.UserId], newRequest)

	sessionGiftRequestsByRecipient[recipient.UserId] = sessionGiftRequestsByRecipient[recipient.UserId] or {}
	table.insert(sessionGiftRequestsByRecipient[recipient.UserId], newRequest)
end

--// Dev Product Handlers

-- A dictionary to look up the handler function to grant a purchase corresponding to a product ID
-- These functions return true if the purchase was granted successfully
-- These functions must never yield since they're called later within an UpdateAsync() callback
local grantPurchaseHandlerByProductId = {
	[productIdByName.instantRestock] = function(_receipt, player)
		local success, msg = SeedStock.Restock(player.UserId, true)

		return success
	end,
	[productIdByName.instantRestockArmor] = function(_receipt, player)
		local success, msg = SeedStock.Restock(player.UserId, true, true)

		return success
	end,
	
	[productIdByName.eliteSword] = function(_receipt, player)
		local success = RS.Remotes.Server.Weapons.PurchaseWeaponRobux:Invoke(player, "Elite Sword")
		return success
	end,

	[productIdByName.buildAll] = function(_receipt, player)
		local grown = false
		local manager = PlotManager.GetPlot(player.UserId)
		local grown = manager.BuildingsManager:InstaGrowBuildings()
		
		if grown then
			UpdatePlantedBuildings:FireClient(player, manager.BuildingsManager.PlantedBuildings)
		end
		
		return grown
	end,
	
	--// Boosts
	[productIdByName.cashBoost1Minute] = function(_receipt, player)
		local manager = PlotManager.GetPlot(player.UserId)
		if not manager then
			return false
		end
		if manager.ActiveBoosts["Cash"] then
			manager.ActiveBoosts["Cash"] += 60
		else
			manager.ActiveBoosts["Cash"] = 60
		end
		return true
	end,
	[productIdByName.cashBoost10Minute] = function(_receipt, player)
		local manager = PlotManager.GetPlot(player.UserId)
		if not manager then
			return false
		end
		if manager.ActiveBoosts["Cash"] then
			manager.ActiveBoosts["Cash"] += 600
		else
			manager.ActiveBoosts["Cash"] = 600
		end
		return true
	end,
	[productIdByName.cashBoost30Minute] = function(_receipt, player)
		local manager = PlotManager.GetPlot(player.UserId)
		if not manager then
			return false
		end
		if manager.ActiveBoosts["Cash"] then
			manager.ActiveBoosts["Cash"] += 1_800
		else
			manager.ActiveBoosts["Cash"] = 1_800
		end
		return true
	end,
	
	[productIdByName.growthBoost1Minute] = function(_receipt, player)
		local manager = PlotManager.GetPlot(player.UserId)
		if not manager then
			return false
		end
		if manager.ActiveBoosts["Growth"] then
			manager.ActiveBoosts["Growth"] += 60
			manager.BuildingsManager:ApplyGrowthBoost(60)
		else
			manager.ActiveBoosts["Growth"] = os.time() + 60
			manager.BuildingsManager:ApplyGrowthBoost(60)
		end
		return true
	end,
	[productIdByName.growthBoost10Minute] = function(_receipt, player)
		local manager = PlotManager.GetPlot(player.UserId)
		if not manager then
			return false
		end
		if manager.ActiveBoosts["Growth"] then
			manager.ActiveBoosts["Growth"] += 600
		else
			manager.ActiveBoosts["Growth"] = 600
		end
		return true
	end,
	[productIdByName.growthBoost30Minute] = function(_receipt, player)
		local manager = PlotManager.GetPlot(player.UserId)
		if not manager then
			return false
		end
		if manager.ActiveBoosts["Cash"] then
			manager.ActiveBoosts["Cash"] += 1_800
		else
			manager.ActiveBoosts["Cash"] = 1_800
		end
		return true
	end,
	
	--// Buy Coins
	[productIdByName.tinyCoinsBundle] = function(_receipt, player)
		local coins = player:FindFirstChild("leaderstats"):FindFirstChild("Coin")
		if not coins then return false end
		
		coins.Value += 1_500
		
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Coin", -- Currency name
			1_500, -- Amount earned
			coins.Value, -- Current balance
			Enum.AnalyticsEconomyTransactionType.IAP.Name, -- Transaction type
			"Tiny Coins Bundle"
		)

		return true
	end,
	[productIdByName.smallCoinsBundle] = function(_receipt, player)
		local coins = player:FindFirstChild("leaderstats"):FindFirstChild("Coin")
		if not coins then return false end

		coins.Value += 5_000

		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Coin", -- Currency name
			5_000, -- Amount earned
			coins.Value, -- Current balance
			Enum.AnalyticsEconomyTransactionType.IAP.Name, -- Transaction type
			"Small Coins Bundle"
		)

		return true
	end,
	[productIdByName.mediumCoinsBundle] = function(_receipt, player)
		local coins = player:FindFirstChild("leaderstats"):FindFirstChild("Coin")
		if not coins then return false end

		coins.Value += 12_000

		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Coin", -- Currency name
			12_000, -- Amount earned
			coins.Value, -- Current balance
			Enum.AnalyticsEconomyTransactionType.IAP.Name, -- Transaction type
			"Medium Coins Bundle"
		)

		return true
	end,
	[productIdByName.averageCoinsBundle] = function(_receipt, player)
		local coins = player:FindFirstChild("leaderstats"):FindFirstChild("Coin")
		if not coins then return false end

		coins.Value += 30_000

		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Coin", -- Currency name
			30_000, -- Amount earned
			coins.Value, -- Current balance
			Enum.AnalyticsEconomyTransactionType.IAP.Name, -- Transaction type
			"Average Coins Bundle"
		)

		return true
	end,
	[productIdByName.bigCoinsBundle] = function(_receipt, player)
		local coins = player:FindFirstChild("leaderstats"):FindFirstChild("Coin")
		if not coins then return false end

		coins.Value += 75_000

		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Coin", -- Currency name
			75_000, -- Amount earned
			coins.Value, -- Current balance
			Enum.AnalyticsEconomyTransactionType.IAP.Name, -- Transaction type
			"Big Coins Bundle"
		)

		return true
	end,
	[productIdByName.giantCoinsBundle] = function(_receipt, player)
		local coins = player:FindFirstChild("leaderstats"):FindFirstChild("Coin")
		if not coins then return false end

		coins.Value += 200_000

		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Coin", -- Currency name
			200_000, -- Amount earned
			coins.Value, -- Current balance
			Enum.AnalyticsEconomyTransactionType.IAP.Name, -- Transaction type
			"Giant Coins Bundle"
		)

		return true
	end,
}

--// Armor crates dev products
for _, crateName in CrateIndex.Order do
	local crate = CrateIndex[crateName]
	if not crate then continue end
	
	local productId = crate["ProductId"]
	if game.GameId == _G.testingGameId then
		productId = crate["TestingProductId"]
	end
	if not productId then continue end
	
	grantPurchaseHandlerByProductId[productId] = function(_receipt, plr)
		local success = PurchaseCrateRobux:Invoke(plr, crateName)
		return success
	end
end

--// Building developer products + gifting
for _, buildingName in BuildingIndex.BuildingsOrder do
	local buildingData = BuildingIndex[buildingName]
	if not buildingData then continue end
	
	
	local productId = buildingData["ProductId"]
	if game.GameId == _G.testingGameId then
		productId = buildingData["TestingProductId"]
	end
	if not productId then continue end
	
	grantPurchaseHandlerByProductId[productId] = function(_receipt, plr)
		local tool = BuildingTools:FindFirstChild(buildingName)
		if not tool then return false end
		
		local player = plr
		local giftDatas = sessionGiftRequestsBySender[plr.UserId]
		local wasAGift = false
		
		local giftData
		if giftDatas then
			for _, _giftData in giftDatas do 
				if _giftData.productId ~= productId then continue end

				giftData = _giftData
				local recipient = Players:GetPlayerByUserId(_giftData.recipientId)
				if not recipient then return false end
				player = recipient
				wasAGift = true
				break
			end
		end
		
		local plotManager = PlotManager.GetPlot(player.UserId)
		
		local success = plotManager.BuildingsManager:PurchaseBuilding(buildingName, nil, true)
		
		if wasAGift and success then
			ShowNotification:FireClient(player, "You've recieved a "..buildingName.." from "..plr.DisplayName.." (@"..plr.Name..")!", "notif")
			ShowNotification:FireClient(plr, "Purchase successful!", "notif")
		elseif success then
			ShowNotification:FireClient(player, "Purchase successful!", "notif")
		end
		
		if not success and giftDatas then
			-- Save gift and index it under recipient
			local indexKey = "gift_index_" .. player.UserId
			local giftKey = "gift_" .. giftDatas.giftId
			-- 1. Store the actual gift
			giftQueue:Enqueue(function()
				GiftStore:SetAsync(giftKey, giftDatas)
			end)

			-- 2. Append the key to the recipient's index list
			giftQueue:Enqueue(function()
				GiftStore:UpdateAsync(indexKey, function(old)
					local index = old or {}
					table.insert(index, giftKey)
					return index
				end)
			end)
		end
		
		return success, giftData
	end
end

--// Load Gift Functions
local function WaitForBuildingsToLoad(player)
	local manager = PlotManager.GetPlot(player.UserId)
	if not manager then
		repeat 
			task.wait(1) 
			manager = PlotManager.GetPlot(player.UserId)
		until manager ~= nil
	end
	repeat task.wait(1) until manager.DoneLoading
end

local function OnPlayerAdded(player)
	local indexKey = "gift_index_" .. player.UserId

	local success, giftKeys = pcall(function()
		return GiftStore:GetAsync(indexKey)
	end)

	if not success or not giftKeys or #giftKeys == 0 then return end

	for _, giftKey in ipairs(giftKeys) do
		local ok, giftData = pcall(function()
			return GiftStore:GetAsync(giftKey)
		end)
		if not ok or not giftData then continue end

		sessionGiftRequestsBySender[giftData.senderId] = sessionGiftRequestsBySender[giftData.senderId] or {}
		table.insert(sessionGiftRequestsBySender[giftData.senderId], giftData)

		sessionGiftRequestsByRecipient[giftData.recipientId] = sessionGiftRequestsByRecipient[giftData.recipientId] or {}
		table.insert(sessionGiftRequestsByRecipient[giftData.recipientId], giftData)

		print("Gift waiting for", player.Name, "from", giftData.senderId, "->", giftData.productId)

		WaitForBuildingsToLoad(player)

		local function tryGrantGift()
			local handler = grantPurchaseHandlerByProductId[giftData.productId]
			if not handler then return false end

			local success, result = pcall(function()
				return handler(nil, player)
			end)

			return success and result == true
		end

		if tryGrantGift() then
			cleanupGift(giftData)
		else
			print("[GiftRetry] Failed to grant gift to", player.Name, " – will retry next join")
			retryQueueByUserId[player.UserId] = retryQueueByUserId[player.UserId] or {}
			table.insert(retryQueueByUserId[player.UserId], giftKey)
		end
	end
end

local function RetryQueuedGifts()
	for userId, gifts in pairs(retryQueueByUserId) do
		local player = Players:GetPlayerByUserId(userId)
		if not player then continue end

		if #gifts == 0 then
			retryQueueByUserId[userId] = nil
			continue
		end
		
		WaitForBuildingsToLoad(player)
		
		for i = #gifts, 1, -1 do
			local giftKey = gifts[i]
			local ok, giftData = pcall(function()
				return GiftStore:GetAsync(giftKey)
			end)

			if not ok or not giftData then continue end

			local handler = grantPurchaseHandlerByProductId[giftData.productId]
			if not handler then continue end

			local success, granted = pcall(handler, nil, player)
			if not success or not granted then continue end

			print("[GiftRetry] Gift retried successfully for", player.Name)
			table.remove(gifts, i)

			-- Clean up
			giftQueue:Enqueue(function() GiftStore:RemoveAsync(giftKey) end)
			giftQueue:Enqueue(function()
				GiftStore:UpdateAsync("gift_index_" .. userId, function(old)
					local new = {}
					for _, key in ipairs(old or {}) do
						if key ~= giftKey then table.insert(new, key) end
					end
					return new
				end)
			end)
		end
	end
end

--// Core ProcessReceipt callback function
local function processReceipt(receiptInfo)
	local giftData = nil
	local didGrantPurchase = false

	local success, result = pcall(function()
		return purchaseHistoryStore:UpdateAsync(receiptInfo.PurchaseId, function(isPurchased)
			if isPurchased then
				return true
			end

			local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
			if not player then return nil end

			local grantPurchaseHandler = grantPurchaseHandlerByProductId[receiptInfo.ProductId]
			if not grantPurchaseHandler then
				warn("No handler for product:", receiptInfo.ProductId)
				return nil
			end

			local handlerSucceeded, handlerResult, handlerGiftData = pcall(grantPurchaseHandler, receiptInfo, player)
			if not handlerSucceeded then
				warn("Handler error:", handlerResult)
				return nil
			end

			didGrantPurchase = handlerResult == true
			giftData = handlerGiftData

			return didGrantPurchase
		end)
	end)

	if not success then
		warn("DataStore UpdateAsync failed:", result)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if didGrantPurchase and giftData then
		cleanupGift(giftData)
	end

	if didGrantPurchase then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

--// Connections
MPS.ProcessReceipt = processReceipt -- Set the callback; this can only be done once by one script on the server
SendGiftRequestEvent.OnServerEvent:Connect(SendGiftRequest)
Players.PlayerAdded:Connect(OnPlayerAdded)

task.spawn(function()
	while true do
		RetryQueuedGifts()
		task.wait(180) -- retry every 3 minutes
	end
end)