--// Services
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local AnalyticsService = game:GetService("AnalyticsService")

--// Modules
local Modules = RS.ModuleScripts
local ArmorModules = Modules.Armor

local ArmorDB = require(ArmorModules.ArmorIndex)
local CrateIndex = require(ArmorModules.Crates.CrateIndex)
local ArmorStocks = require(SS.Modules.SeedStock)

--// Remotes
local Remotes = RS.Remotes
local ServerArmorRemotes = Remotes.Server.ArmorSystem
local ClientArmorRemotes = Remotes.Client.ArmorSystem

local Equip = ServerArmorRemotes.EquipArmor
local Unequip = ServerArmorRemotes.UnequipArmor
local AddArmorEvent = ServerArmorRemotes.AddArmor
local DeleteArmorEvent = ServerArmorRemotes.DeleteArmor
local BuyCrate = ServerArmorRemotes.BuyCrate

local GetInvRemote = ServerArmorRemotes.GetInventorySpace
local GetInvBindable = ServerArmorRemotes.GetInvSpace

local LoadInventoryEvent = ServerArmorRemotes.LoadInventory
local GetInventoryEvent = ServerArmorRemotes.GetInventory

local AddToInvUI = ClientArmorRemotes.AddInventoryItem
local LoadInventoryUI = ClientArmorRemotes.LoadInventory
local RemoveUIs = ClientArmorRemotes.DeleteArmorUI
local OpenCrate = ClientArmorRemotes.OpenCase
local UpdateCrateStock = ClientArmorRemotes.UpdateStock

--// Constants
local MAX_INVENTORY_SIZE = 50
	
--// State
local ArmorInventories = {} -- Tracks what each player is wearing


--// Functions
local function EquipArmor(player, armorName)
	if not ArmorInventories[player.UserId] then ArmorInventories[player.UserId] = {} end
	
	if table.find(ArmorInventories[player.UserId]["Unequipped"] or {}, armorName) == nil then return end
	
	local armor = ArmorDB[armorName]
	if not armor then return end

	-- Unequip old armor of same type
	if ArmorInventories[player.UserId]["Equipped"] and ArmorInventories[player.UserId]["Equipped"][armor.Type] then
		UnequipArmor(player, ArmorInventories[player.UserId]["Equipped"][armor.Type].Name)
	end
	
	-- Equip new armor
	armor:ApplyTo(player)
	ArmorInventories[player.UserId]["Equipped"] = ArmorInventories[player.UserId]["Equipped"] or {}
	ArmorInventories[player.UserId]["Equipped"][armor.Type] = armor
end

function UnequipArmor(player, armorName)
	local armor = ArmorDB[armorName]
	if not armor then return end
	
	if not ArmorInventories[player.UserId] then ArmorInventories[player.UserId] = {["Equipped"] = {}, ["Unequipped"] = {}} end

	if ArmorInventories[player.UserId]["Equipped"][armor.Type] then
		ArmorInventories[player.UserId]["Equipped"][armor.Type]:RemoveFrom(player)
		
		if not ArmorInventories[player.UserId]["Unequipped"] then
			ArmorInventories[player.UserId]["Unequipped"] = {}
		end
		table.insert(ArmorInventories[player.UserId]["Unequipped"], armor.Name)
		
		ArmorInventories[player.UserId]["Equipped"][armor.Type] = nil
		
		AddToInvUI:FireClient(player, armorName)
	end
end

function AddArmor(player, armorName)
	if not ArmorDB[armorName] then return end
	if not ArmorInventories[player.UserId] then ArmorInventories[player.UserId] = {["Equipped"] = {}, ["Unequipped"] = {}} end
	if not ArmorInventories[player.UserId]["Unequipped"] then ArmorInventories[player.UserId]["Unequipped"] = {} end
	
	table.insert(ArmorInventories[player.UserId]["Unequipped"], armorName)
	AddToInvUI:FireClient(player, armorName)
end

function DeleteArmor(player, armorNames)
	local successfulDeletions = {}
	
	for _, name in armorNames do
		local idx = table.find(ArmorInventories[player.UserId]["Unequipped"], name)
		if idx == nil then continue end
		
		table.remove(ArmorInventories[player.UserId]["Unequipped"], idx)
		table.insert(successfulDeletions, name)
	end
	RemoveUIs:FireClient(player, successfulDeletions)
end

function PurchaseCrate(player, crateName)
	local stocks = ArmorStocks.GetStock(player.UserId)
	if not stocks or not stocks["Armor"] then return end
	
	local stock = stocks["Armor"][crateName]
	if not stock or stock == 0 then return end
	
	local crate = CrateIndex[crateName]
	if not crate then return end
	
	if player.leaderstats.Coin.Value < crate["Price"] then
		
		return
	end
	
	player.leaderstats.Coin.Value -= crate["Price"]
	AnalyticsService:LogEconomyEvent(
		player,
		Enum.AnalyticsEconomyFlowType.Sink,
		"Coin", -- Currency name
		crate["Price"], -- Cost
		player.leaderstats.Coin.Value, -- Current balance
		Enum.AnalyticsEconomyTransactionType.Shop.Name -- Transaction type
	)
	
	local rolledItem = crate:Roll()
	if not rolledItem then return end
	
	ArmorStocks.MakePurchase(player.UserId, crateName, true)
	AddArmor(player, rolledItem.Name)
	UpdateCrateStock:FireClient(player, crateName, stocks["Armor"][crateName])
	
	task.delay(0.25, function()
		OpenCrate:FireClient(player, rolledItem.Model, rolledItem.Name)
	end)
	
end

function PurchaseCrateRobux(player, crateName)
	local crate = CrateIndex[crateName]
	if not crate then return false end

	local rolledItem = crate:Roll()
	if not rolledItem then return false end

	AddArmor(player, rolledItem.Name)
	task.delay(0.25, function()
		OpenCrate:FireClient(player, rolledItem.Model, rolledItem.Name)
	end)
	return true
end

--// Datastore Helpers
function LoadInventory(player, savedInv)
	local loadedInv = savedInv
	if loadedInv["Equipped"] then
		for armorType, armorName in loadedInv["Equipped"] do
			loadedInv["Equipped"][armorType] = ArmorDB[armorName]
			loadedInv["Equipped"][armorType]:ApplyTo(player)
		end
	end
	
	ArmorInventories[player.UserId] = loadedInv
	LoadInventoryUI:FireClient(player, savedInv)
end

function GetInventory(player, forSaving)
	local inv = ArmorInventories[player.UserId]
	if inv["Equipped"] then
		for armorType, armor in inv["Equipped"] do
			inv["Equipped"][armorType] = armor.Name
		end
	end
	if forSaving then
		task.delay(2, function()
			ArmorInventories[player.UserId] = nil
		end)
	end
	return inv
end

function GetInventorySpace(player)
	if not ArmorInventories[player.UserId] then return 0, MAX_INVENTORY_SIZE end
	
	local count = 0
	if ArmorInventories[player.UserId]["Equipped"] then
		count += #ArmorInventories[player.UserId]["Equipped"]
	end
	if ArmorInventories[player.UserId]["Unequipped"] then
		count += #ArmorInventories[player.UserId]["Unequipped"]
	end
	
	return count, MAX_INVENTORY_SIZE
end

--// Connections
Players.PlayerAdded:Connect(function(player)
	local function makeBlock(character)
		task.wait(1)
		local humanoid = character:WaitForChild("Humanoid")
		local description = humanoid:GetAppliedDescription()
		-- Resetting limb properties to 0 will result in the blocky part.
		description.Head = 0
		description.LeftArm = 0
		description.RightArm = 0
		description.LeftLeg = 0
		description.RightLeg = 0
		description.Torso = 0
		humanoid:ApplyDescription(description)
	end
	
	local character = player.Character or player.CharacterAdded:Wait()
	makeBlock(character)
	player.CharacterAdded:Connect(function(character)
		makeBlock(character)
		if ArmorInventories[player.UserId]["Equipped"] then
			for _, armor in ArmorInventories[player.UserId]["Equipped"] do
				EquipArmor(player, armor["Name"])
			end
		end
	end)
end)

Equip.OnServerEvent:Connect(EquipArmor)
Unequip.OnServerEvent:Connect(UnequipArmor)
DeleteArmorEvent.OnServerEvent:Connect(DeleteArmor)
BuyCrate.OnServerEvent:Connect(PurchaseCrate)
ServerArmorRemotes.RobuxPurchaseCrate.OnInvoke = PurchaseCrateRobux
AddArmorEvent.Event:Connect(AddArmor)

LoadInventoryEvent.Event:Connect(LoadInventory)
GetInventoryEvent.OnInvoke = GetInventory

GetInvRemote.OnServerInvoke = GetInventorySpace
GetInvBindable.OnInvoke = GetInventorySpace