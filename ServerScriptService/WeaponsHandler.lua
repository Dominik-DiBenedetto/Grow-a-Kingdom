local RS = game:GetService("ReplicatedStorage")
local TagService = game:GetService("CollectionService")
local AnalyticsService = game:GetService("AnalyticsService")

--// Remotes
local ShowNotifMessage = RS.Remotes.Client.ShowErrorMessage

local WSRemotes = RS.Remotes.Server.Weapons

local BuyWeapon = WSRemotes.BuyWeapon
local ToggleWeapon = WSRemotes.ToggleWeapon
local GetInventoryRemote = WSRemotes.GetOwnedWeapons
local GetInventoryBindable = WSRemotes.GetInventoryForSaving
local LoadInventory = WSRemotes.LoadSavedWeapons

local WCRemotes = RS.Remotes.Client.Weapons
local UpdateWeaponStatus = WCRemotes.UpdateWeaponStatus

--// Weapons Data
local WeaponsIndex = require(RS.Weapons.WeaponStats)

--// State
local weaponsInventory = {}

--// Local Functions
local function Unequip(player)
	local equippedTool = weaponsInventory[player.UserId]["Equipped"]
	if not equippedTool then return end
	
	local char = player.Character or player.CharacterAdded:Wait()
	local tool = player.Backpack:FindFirstChild(equippedTool) or char:WaitForChild(equippedTool, 3)
	if not tool then return end
	
	tool:Destroy()
	table.insert(weaponsInventory[player.UserId]["Unequipped"], equippedTool)
	
	UpdateWeaponStatus:FireClient(player, equippedTool, "Equip")
	weaponsInventory[player.UserId]["Equipped"] = ""
end

local function Equip(player, weaponName)
	local idx = table.find(weaponsInventory[player.UserId]["Unequipped"], weaponName)
	if idx == nil then return end
	
	local equippedTools = weaponsInventory[player.UserId]["Equipped"]
	if #equippedTools ~= 0 then
		Unequip(player)
	end
	
	local tool = Instance.new("Tool")
	tool.Name = weaponName
	tool.Parent = player.Backpack
	
	TagService:AddTag(tool, "Weapon")
	tool:SetAttribute("Weapon", weaponName)
	
	weaponsInventory[player.UserId]["Equipped"] = weaponName
	
	UpdateWeaponStatus:FireClient(player, weaponName, "Unequip")
	table.remove(weaponsInventory[player.UserId]["Unequipped"], idx)
end

--// Functions
function ToggleTool(player, weaponName)
	if weaponsInventory[player.UserId]["Equipped"] == weaponName then
		Unequip(player)
		return
	end
	
	Equip(player, weaponName)
end

function PurchaseWeapon(player, weaponName)
	if table.find(weaponsInventory[player.UserId]["Unequipped"], weaponName) or weaponsInventory[player.UserId]["Equipped"] == weaponName then return end
	
	local weaponData = WeaponsIndex[weaponName]
	if not weaponData then return end
	
	local playerCoins = player.leaderstats.Coin
	if playerCoins.Value < weaponData["Price"] then
		ShowNotifMessage:FireClient(player, "Need "..(weaponData["Price"]-playerCoins.Value).." more coins!")
		return
	end
	
	playerCoins.Value -= weaponData["Price"]
	table.insert(weaponsInventory[player.UserId]["Unequipped"], weaponName)
	AnalyticsService:LogEconomyEvent(
		player,
		Enum.AnalyticsEconomyFlowType.Sink,
		"Coin", -- Currency name
		weaponData["Price"], -- Cost
		playerCoins.Value, -- Current balance
		Enum.AnalyticsEconomyTransactionType.Shop.Name -- Transaction type
	)
	ShowNotifMessage:FireClient(player, "Purchase successful!", "notif")
	UpdateWeaponStatus:FireClient(player, weaponName, "Equip")

end

function RobuxPurchaseWeapon(player,weaponName)
	if table.find(weaponsInventory[player.UserId]["Unequipped"], weaponName) or weaponsInventory[player.UserId]["Equipped"] == weaponName then return false end

	local weaponData = WeaponsIndex[weaponName]
	if not weaponData then return false end

	table.insert(weaponsInventory[player.UserId]["Unequipped"], weaponName)

	ShowNotifMessage:FireClient(player, "Purchase successful!", "notif")
	UpdateWeaponStatus:FireClient(player, weaponName, "Equip")
	return true
end

function GetOwnedWeapons(player, shouldClean)
	if shouldClean then
		task.delay(2, function()
			weaponsInventory[player.UserId] = nil
		end)
	end
	return weaponsInventory[player.UserId] 
end

function LoadSavedWeapons(player, savedInv)
	weaponsInventory[player.UserId] = savedInv
	
	for _, weaponName in weaponsInventory[player.UserId]["Unequipped"] do
		UpdateWeaponStatus:FireClient(player, weaponName, "Equip")
	end
	
	if weaponsInventory[player.UserId]["Equipped"] then
		local weaponName = weaponsInventory[player.UserId]["Equipped"]
		
		local tool = Instance.new("Tool")
		tool.Name = weaponName
		tool.Parent = player.Backpack
		
		TagService:AddTag(tool, "Weapon")
		tool:SetAttribute("Weapon", weaponName)

		UpdateWeaponStatus:FireClient(player, weaponName, "Unequip")
	end
end

--// Connections
ToggleWeapon.OnServerEvent:Connect(ToggleTool)
BuyWeapon.OnServerEvent:Connect(PurchaseWeapon)
GetInventoryRemote.OnServerInvoke = GetOwnedWeapons
LoadInventory.Event:Connect(LoadSavedWeapons)
GetInventoryBindable.OnInvoke = GetOwnedWeapons
WSRemotes.PurchaseWeaponRobux.OnInvoke = RobuxPurchaseWeapon