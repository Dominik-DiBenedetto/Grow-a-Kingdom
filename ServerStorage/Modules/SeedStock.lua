local DSS = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local PlayerStockStore = DSS:GetDataStore("ProductionPlayerStocks3")
local Remotes = RS.Remotes

local UpdateStock = Remotes.Client.UpdateStock
local UpdateTimer = Remotes.Client.UpdateTimer
local LoadSeedShopRemote = RS.Remotes.Client.LoadSeedShop

local UpdateArmorStock = Remotes.Client.ArmorSystem.UpdateStock
local UpdateArmorTimer = Remotes.Client.ArmorSystem.UpdateTimer
local LoadArmorShopRemote = RS.Remotes.Client.ArmorSystem.LoadCrateShop

local BuildingsIndex = require(SS.Modules.Buildings.BuildingIndex)

local GroupId = 79245806

local SeedStock = {}

-- [idx] = {Name<String>, Weight<Int>, MinPerRestock<Int>, MaxPerRestock<Int>}
local buildingsList = {
	{Name="WoodlandHut", Weight=40, Min=5, Max=20},
	{Name="RoseCottage", Weight=40, Min=5, Max=20},
	{Name="MapleResidence", Weight=35, Min=5, Max=20},
	{Name="RoundgateHall", Weight=30, Min=5, Max=15},
	{Name="ScarletSpire", Weight=30, Min=4, Max=15},
	{Name="StiltstoneHall", Weight=20, Min=3, Max=10},
	{Name="ThreefoldWatch", Weight=17, Min=3, Max=10},
	{Name="StonewatchBastion", Weight=15, Min=2, Max=7},
	{Name="RedEmberHall", Weight=13, Min=1, Max=5},
	{Name="MistwoodAltar", Weight=10, Min=0, Max=5},
}
local cratesList = {
	{Name="Cardboard Box", Weight=20, Min=0, Max=8},
	{Name="Wooden Box", Weight=10, Min=0, Max=6},
}
local extraKeys = {"LastRestock", "TimeElapsed", "JoinedAtTime"}

local playerStocks = {}
local RESTOCK_TIME = 300 -- 5 minutes
local CRATE_RESTOCK_TIME = 300

--// Local functions
local function RollRestock(armorRestock)
	-- Weighted random selection
	local pool = {}
	local stockList = armorRestock and cratesList or buildingsList
	
	for _, seed in ipairs(stockList) do
		for i = 1, seed.Weight do
			table.insert(pool, seed)
		end
	end

	local chosenBuildings = {}
	while #chosenBuildings < #stockList and #pool > 0 do
		local index = math.random(1, #pool)
		local building = pool[index]

		-- Avoid duplicates
		if not chosenBuildings[building.Name] then
			chosenBuildings[building.Name] = math.random(building.Min, building.Max)
		end

		-- Remove all of this seed from pool to prevent duplicates
		local newPool = {}
		for _, s in ipairs(pool) do
			if s.Name ~= building.Name then
				table.insert(newPool, s)
			end
		end
		pool = newPool
	end

	return chosenBuildings
end

--// Public Functions
function SeedStock.GetStock(playerId)
	return playerStocks[playerId]
end

function SeedStock.GetTimeLeft(playerId)
	local lastRestock = playerStocks[playerId]["LastRestock"]
	local joinedAtTime = playerStocks[playerId]["JoinedAtTime"]
	local timeElapsed = playerStocks[playerId]["TimeElapsed"] -- time elapsed is incase player leaves so time progress is saved
	
	if lastRestock == nil then
		playerStocks[playerId]["LastRestock"] = os.time()
		lastRestock = playerStocks[playerId]["LastRestock"]
	end
	
	if timeElapsed and joinedAtTime then
		local timeSinceJoin = os.time() - joinedAtTime
		local totalTimeElapsed = os.time() - lastRestock
		
		local effectiveTimeElapsed = timeElapsed + timeSinceJoin
		local trueTimeElapsed = math.min(effectiveTimeElapsed, totalTimeElapsed)
		
		local timeLeft = RESTOCK_TIME - trueTimeElapsed
		
		return timeLeft
	else
		return RESTOCK_TIME - (os.time() - lastRestock)
	end
end

function SeedStock.GetArmorTimeLeft(playerId)
	local now = os.time()
	if not playerStocks[playerId]["Armor"] then
		playerStocks[playerId]["Armor"] = {["LastRestock"] = now}
		return 0
	end
	
	local lastRestock = playerStocks[playerId]["Armor"]["LastRestock"]
	
	local joinedAtTime = playerStocks[playerId]["Armor"]["JoinedAtTime"]
	local timeElapsed = playerStocks[playerId]["Armor"]["TimeElapsed"] -- time elapsed is incase player leaves so time progress is saved

	if timeElapsed and joinedAtTime then
		local timeSinceJoin = os.time() - joinedAtTime
		local totalTimeElapsed = os.time() - lastRestock

		local effectiveTimeElapsed = timeElapsed + timeSinceJoin
		local trueTimeElapsed = math.min(effectiveTimeElapsed, totalTimeElapsed)

		local timeLeft = RESTOCK_TIME - trueTimeElapsed

		return timeLeft
	else
		return RESTOCK_TIME - (os.time() - lastRestock)
	end
end

function SeedStock.CanPurchase(playerId, name, isArmor)
	local stock = playerStocks[playerId][name]
	if isArmor then
		stock = playerStocks[playerId]["Armor"][name]
	end
	if not stock or stock <= 0 then
		return false, "Out of stock"
	end
	return true
end

function SeedStock.MakePurchase(playerId, name, isArmor)
	if not SeedStock.CanPurchase(playerId, name, isArmor) then return false end
	local stock = playerStocks[playerId]
	if isArmor then
		stock = playerStocks[playerId]["Armor"]
	end
	stock[name] -= 1
end

function SeedStock.Restock(playerId, purchasedRestock, purchasedArmor)
	if not playerStocks[playerId] then playerStocks[playerId] = {} end
	
	local now = os.time()
	
	-- Buildings Restock
	local timeElapsed = SeedStock.GetTimeLeft(playerId)
	local lastRestock = playerStocks[playerId]["LastRestock"]
	if lastRestock == nil then
		playerStocks[playerId]["LastRestock"] = now
		lastRestock = playerStocks[playerId]["LastRestock"]
	end
	
	local hasGroupRestock = playerStocks[playerId]["HasGroupRestock"]
	
	local didRestock = false
	
	if lastRestock == now or (purchasedRestock and not purchasedArmor) or hasGroupRestock or lastRestock ~= now and timeElapsed <= 0 then
		local newStock = RollRestock()
		
		playerStocks[playerId] = newStock
		playerStocks[playerId]["LastRestock"] = now
		playerStocks[playerId]["TimeElapsed"] = nil
		playerStocks[playerId]["JoinedAtTime"] = nil
		
		if lastRestock ~= now and not purchasedRestock and timeElapsed > 0 then -- use group restock
			playerStocks[playerId]["HasGroupRestock"] = false
			playerStocks[playerId]["LastGroupRestockTime"] = os.time()
		end
		
		local player = Players:GetPlayerByUserId(playerId)
		for buildingName, buildingStock in newStock do
			UpdateStock:FireClient(player, buildingName, buildingStock)
		end
		UpdateTimer:FireClient(player, SeedStock.GetTimeLeft(player.UserId))
	end
	
	-- Armor Crates Restock
	local armorTimeLeft = SeedStock.GetArmorTimeLeft(playerId)
	if (purchasedRestock and purchasedArmor) or (armorTimeLeft and armorTimeLeft <= 0) then
		local newStock = RollRestock(true)

		playerStocks[playerId]["Armor"] = newStock
		playerStocks[playerId]["Armor"]["LastRestock"] = now
		playerStocks[playerId]["Armor"]["TimeElapsed"] = nil
		playerStocks[playerId]["Armor"]["JoinedAtTime"] = nil
		
		local player = Players:GetPlayerByUserId(playerId)
		for buildingName, buildingStock in newStock do
			UpdateArmorStock:FireClient(player, buildingName, buildingStock)
		end
		UpdateArmorTimer:FireClient(player, SeedStock.GetTimeLeft(player.UserId))
		return true, playerStocks[playerId]
	elseif didRestock then
		return true, playerStocks[playerId]
	end
	
	return false, "Restock Failed, Must Wait"..(now - (lastRestock + RESTOCK_TIME)).." More Seconds!"
end

-- Datastore

function SeedStock.LoadStock(playerId)
	local playerStock = PlayerStockStore:GetAsync(playerId.."_stock")
	if not playerStock then
		print("First time player, no old stock")
		local success, data = SeedStock.Restock(playerId, false)
		if success then
			playerStock = data
		else
			warn(data)
			return false
		end
	end
	
	playerStock["JoinedAtTime"] = os.time()
	
	local player = Players:GetPlayerByUserId(playerId)
	if player:IsInGroup(GroupId) then
		if playerStock["LastGroupRestockTime"] then
			if os.time() >= playerStock["LastGroupRestockTime"] + 86400 then
				playerStock["LastGroupRestockTime"] = os.time()
				playerStock["HasGroupRestock"] = true
			else
				playerStock["HasGroupRestock"] = false
			end
		else
			playerStock["LastGroupRestockTime"] = os.time()
			playerStock["HasGroupRestock"] = true
		end 
	end
	
	playerStocks[playerId] = playerStock
	
	LoadSeedShopRemote:FireClient(player, BuildingsIndex, playerStock)
	LoadArmorShopRemote:FireClient(player, playerStock["Armor"])

	UpdateTimer:FireClient(player, SeedStock.GetTimeLeft(playerId))
	UpdateArmorTimer:FireClient(player, SeedStock.GetArmorTimeLeft(playerId))
	
	return playerStock
end

function SeedStock.SaveStock(playerId)
	local playerStock = playerStocks[playerId]
	if not playerStock then return warn("NO STOCK??") end
	
	local timeElapsed = playerStocks[playerId]["TimeElapsed"]
	if timeElapsed then
		playerStocks[playerId]["TimeElapsed"] = timeElapsed + (os.time() - playerStocks[playerId]["JoinedAtTime"])
	else
		playerStocks[playerId]["TimeElapsed"] = os.time() - playerStocks[playerId]["LastRestock"]
	end
	
	PlayerStockStore:SetAsync(playerId.."_stock", playerStock)
end

return SeedStock
