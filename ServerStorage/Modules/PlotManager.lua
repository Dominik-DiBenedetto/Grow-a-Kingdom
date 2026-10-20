--// Services
local SS = game:GetService("ServerStorage")
local Tags = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local MPS = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local AnalyticsService = game:GetService("AnalyticsService")

--// Variables
local Modules = SS.Modules
local TownHallUpgrades = require(Modules.TownHallUpgrades)
local BuildingIndex = require(Modules.Buildings.BuildingIndex)
local BadgeManager = require(Modules.BadgeManager)
local BuildingsManager = require(Modules.Buildings.BuildingsManager)

local NPCManager = require(Modules.NPCs.NPCManager)

local Buildings = RS.Buildings

local Remotes = RS.Remotes
local UpdateFenceData = Remotes.Client.UpdateNextFenceData
local UpdatePlantedBuildings = Remotes.Client.UpdatePlantedBuildings
local UpdateTownHallInfo = Remotes.Client.UpdateTownHallInfo
local ShowErrorMessage = Remotes.Client.ShowErrorMessage
local TogglePrompt = Remotes.Client.ToggleProxPrompt
local StartCooldown = Remotes.Client.ToggleCooldown
local ToggleUI = Remotes.Client.ToggleSpecificUI
local HaveBuildingsLoaded = Remotes.Client.FinishedLoadingBuildings
local PromptFavoriteGame = Remotes.Client.PromptFavoriteGame
local tutorialEvent = Remotes.Client.Tutorial

local GetActiveBoosts = Remotes.Server.GetActiveBoosts

local Incomes = {}

local COST_PER_EXPANSION = 5_000
local ExtraInventorySpaceGamepassId = 1346076823
if game.GameId == _G.testingGameId then
	ExtraInventorySpaceGamepassId = 1340010271
end

local abbreviations = {"", "K", "M", "B", "T"} -- Add more
--// Local Functions

local function abbreviateNum(number)
	if number < 1000 then
		return tostring(number)
	end

	local tier = math.floor(math.log10(number) / 3)
	local suffix = abbreviations[tier + 1] or "??"
	local scale = 10^(tier * 3)
	local short = number / scale

	-- Format to 2 decimal places, remove trailing .00 or .0
	local formatted = string.format("%.2f", short):gsub("%.?0+$", "")
	return formatted .. suffix
end

local function AssignPlot(Player)
	local PlayerPlot = Instance.new("ObjectValue", Player)
	PlayerPlot.Name = "OwnedPlot"

	repeat 
		local Plots = Tags:GetTagged("Plot")
		
		for _, Plot in Plots do
			if Plot.PlotOwner.Value ~= nil or Plot.Parent ~= workspace then continue end -- Already owned
			Plot.PlotOwner.Value = Player
			PlayerPlot.Value = Plot
			return Plot
		end
	until PlayerPlot.Value ~= nil
end

local function SetProperties(model, properties)
	if not model then return end
	if model:IsA("BasePart") then
		for property, value in properties do
			model[property] = value
		end
		return
	end
	local owner = nil
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			if part.Name == "TpDest" then continue end
			if string.find(part.Name, "Separator") and part.Parent.Parent.Name == "PurchasedPlotPieces" then
				if not owner then
					owner = part.Parent.Parent.Parent.PlotOwner.Value
				end
				if owner and owner:IsA("Player") then
					CollectionService:AddTag(part, owner.UserId.."_Path")
				end
			end
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

local function LoadFenceData(owner, fenceType)
	local nextFenceIdx = table.find(TownHallUpgrades.FenceTiers, fenceType)+1
	local nextFenceData
	if nextFenceIdx <= #TownHallUpgrades.FenceTiers then
		local nextFence = TownHallUpgrades.FenceTiers[nextFenceIdx]
		nextFenceData = TownHallUpgrades.FenceUpgrades[nextFence]
	else
		nextFenceData = "Max"
	end
	
	local thisFenceData = TownHallUpgrades.FenceUpgrades[TownHallUpgrades.FenceTiers[table.find(TownHallUpgrades.FenceTiers, fenceType)]]
	
	Incomes[owner.UserId] = {
		["Income"] = thisFenceData.Income, 
		["IncomeWaitTime"] = thisFenceData.IncomeWaitTime,
		["LastPayment"] = os.time()
	}

	UpdateFenceData:FireClient(owner, TownHallUpgrades.FenceUpgrades[fenceType], nextFenceData)
end

local function SerializeCFrame(cf)
	local pos = cf.Position
	local rot = {cf:ToOrientation()}
	return {
		pos = {pos.X, pos.Y, pos.Z},
		rot = {rot[1], rot[2], rot[3]}
	}
end

local function DeserializeCFrame(data)
	if not data or not data.pos or not data.rot then return CFrame.new() end
	local pos = Vector3.new(unpack(data.pos))
	local rot = CFrame.Angles(unpack(data.rot))
	return CFrame.new(pos) * rot
end

local function abbreviateTime(timeLeft)
	local hours = math.floor(timeLeft / 3600) 
	local minutes = math.floor((timeLeft % 3600) / 60) 
	local secondsRemaining = timeLeft % 60 

	if hours > 0 then
		return string.format("%02i:%02i:%02i", hours, minutes, secondsRemaining)
	else
		return string.format("%02i:%02i", minutes, secondsRemaining)
	end
end

--// Plot Manager Module

local PlotManager = {}
PlotManager.__index = PlotManager

PlotManager.STEAL_COOLDOWN = 300
PlotManager.COLLECT_COOLDOWN = 150

local Instances = {}

function PlotManager.New(owner, plotData, buildingsData)
	local newPlot = setmetatable({}, PlotManager)
	newPlot.Owner = owner
	newPlot.OwnedPieces = plotData["OwnedPieces"] or {}
	newPlot.FenceType = plotData["FenceType"] or "Wooden"
	newPlot.BuildingsManager = BuildingsManager.New(owner, buildingsData or {})
	
	newPlot.TownHallLevel = plotData["TownHallLevel"] or 1
	newPlot.TownHallIncome = plotData["TownHallIncome"] or 0
	newPlot.LastCollectedAt = plotData["LastCollectedAt"] or 0
	newPlot.LastStolenAt = plotData["LastStolenAt"] or 0
	
	newPlot.Plot = AssignPlot(owner)
	newPlot.ExpansionCost = COST_PER_EXPANSION
	newPlot.DoneLoading = false
	
	newPlot.ActiveBoosts = plotData["ActiveBoosts"] or {}
	
	newPlot.Sales = plotData["Sales"] or 0
	
	newPlot.MaxInventorySize = 8
	local success, hasPass = pcall(function()
		return MPS:UserOwnsGamePassAsync(owner.UserId, ExtraInventorySpaceGamepassId)
	end)
	if success and hasPass then
		newPlot.MaxInventorySize = 16
	end
	
	LoadFenceData(owner, newPlot.FenceType)
	newPlot:LoadTownHall()
	
	local nextCost = 0
	if newPlot.TownHallLevel+1 <= #TownHallUpgrades.TownHalls then
		nextCost = TownHallUpgrades.TownHalls[newPlot.TownHallLevel+1]["Price"]
	end
	UpdateTownHallInfo:FireClient(owner, newPlot.TownHallLevel, nextCost)
	
	Instances[owner.UserId] = newPlot
	
	return newPlot
end

function PlotManager.GetPlot(ownerId)
	return Instances[ownerId]
end

function PlotManager:PurchasePlotPiece(plotPiece, plotButtons)
	plotPiece.Transparency = 0
	plotPiece.CanCollide = true
	self:LoadFenceOnPiece(plotPiece)
	SetProperties(plotButtons, {Transparency=0,CanCollide=true})
	
	table.insert(self.OwnedPieces, plotPiece.Name)
	self.ExpansionCost += COST_PER_EXPANSION
	self.Plot.PurchasePlotButtons.Cost.Value = self.ExpansionCost
end

function PlotManager:MakeSale()
	self.Sales += 1
	if self.Sales == 5 then
		PromptFavoriteGame:FireClient(self.Owner)
	end
end

function PlotManager:LoadTownHall()
	local TownHalls = RS.TownHalls
	local TownHall = TownHalls:FindFirstChild("TownHallLevel"..(self.TownHallLevel))
	if not TownHall then return end
	
	local tempTownHall = self.Plot:FindFirstChild("TownHallPlotPiece"):FindFirstChild("TownHall")
	local newTownHall = TownHall:Clone()
	
	newTownHall:PivotTo(tempTownHall.PrimaryPart.CFrame)
	tempTownHall:Destroy()

	newTownHall.Parent = self.Plot:FindFirstChild("TownHallPlotPiece")
	newTownHall.Name = "TownHall"
	
	local signUI = self.Owner:WaitForChild("PlayerGui"):WaitForChild("TownHallUpgrades").TownHallUpgradeSign
	signUI.AdorneeTownHall.TownHallSign.Value = newTownHall:FindFirstChild("Sign")
	signUI.TextLabel.Text = "Level:" ..self.TownHallLevel
	
	local townHallData = TownHallUpgrades.TownHalls[self.TownHallLevel]
	
	Incomes[(self.Owner.UserId).."_TownHall"] = {
		["Income"] = townHallData.IncomePerMinute, 
		["IncomeWaitTime"] = 60,
		["LastPayment"] = os.time(),
		["MaxIncome"] = townHallData.MaxIncome,
	}
	
	local signTop = newTownHall:FindFirstChild("Sign").Top
	local collectPrompt = signTop.CollectPrompt
	local stealPrompt = signTop.StealPrompt
	
	TogglePrompt:FireAllClients(collectPrompt, false, self.Owner, true)
	TogglePrompt:FireAllClients(stealPrompt, true, self.Owner, false)
	
	self.Plot.TownHallPlotPiece.TownHall.IncomeDisplay.IncomeLabel.Income.Value = "$"..abbreviateNum(self.TownHallIncome).."/$"..abbreviateNum(townHallData.MaxIncome)
	
	local UI = self.Plot.TownHallPlotPiece.TownHall.Sign.Top.CooldownUI
	
	local isStealOnCooldown = not (os.time() > self.LastStolenAt + PlotManager.STEAL_COOLDOWN)
	local isCollectOnCooldown = not (os.time() > self.LastCollectedAt + PlotManager.COLLECT_COOLDOWN)

	local percentValue = UI.CooldownFrame.Progress.Percentage
	if isCollectOnCooldown and isStealOnCooldown then
		ToggleUI:FireAllClients(UI, true)
		StartCooldown:FireClient(self.Owner, percentValue, PlotManager.COLLECT_COOLDOWN - (os.time() - self.LastCollectedAt), collectPrompt, nil)
		StartCooldown:FireAllClients(percentValue, PlotManager.STEAL_COOLDOWN - (os.time() - self.LastStolenAt), stealPrompt, self.Owner)
	else
		if isCollectOnCooldown then
			ToggleUI:FireClient(self.Owner, UI, true)
			StartCooldown:FireClient(self.Owner, percentValue, PlotManager.COLLECT_COOLDOWN - (os.time() - self.LastCollectedAt), collectPrompt, nil)
		elseif isStealOnCooldown then
			ToggleUI:FireAllClients(UI, true, self.Owner)
			StartCooldown:FireAllClients(percentValue, PlotManager.STEAL_COOLDOWN - (os.time() - self.LastStolenAt), stealPrompt, self.Owner)
		end
	end

end

function PlotManager:CollectTownHallIncome()
	if os.time() > self.LastCollectedAt + PlotManager.COLLECT_COOLDOWN then
		self.LastCollectedAt = os.time()
		
		local amount = self.TownHallIncome
		if self.Owner.MembershipType == Enum.MembershipType.Premium then
			amount *= 1.1
		end
		if self.ActiveBoosts["Cash"] then
			amount *= 2
		end
		
		
		self.Owner.leaderstats.Coin.Value += amount
		
		-- Log to roblox economy analytics, gaining for stealing player
		AnalyticsService:LogEconomyEvent(
			self.Owner,
			Enum.AnalyticsEconomyFlowType.Source,
			"Coin", -- Currency name
			amount, -- Amount earned
			self.Owner.leaderstats.Coin.Value, -- Current balance
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name -- Transaction type
		)
		
		self.TownHallIncome = 0
		
		self.Plot.TownHallPlotPiece.TownHall.IncomeDisplay.IncomeLabel.Income.Value = "$"..abbreviateNum(self.TownHallIncome).."/$"..Incomes[(self.Owner.UserId).."_TownHall"]["MaxIncome"]
		
		local UI = self.Plot.TownHallPlotPiece.TownHall.Sign.Top.CooldownUI
		ToggleUI:FireClient(self.Owner, UI, true)

		local percentValue = UI.CooldownFrame.Progress.Percentage
		local prompt = UI.Parent.CollectPrompt
		StartCooldown:FireClient(self.Owner, percentValue, PlotManager.COLLECT_COOLDOWN - (os.time() - self.LastCollectedAt), prompt , nil)
	else
		ShowErrorMessage:FireClient(self.Owner, "Must wait to collect!")
	end
end

function PlotManager:StealTownHallIncome(playerWhoIsStealing)
	if playerWhoIsStealing.PVPEnabled.Value == false then 
		ShowErrorMessage:FireClient(playerWhoIsStealing, "Must have PVP Enabled to steal!")
		return
	end
	if self.Owner.PVPEnabled.Value == false then
		ShowErrorMessage:FireClient(playerWhoIsStealing, "Other player must have PVP on!")
		return
	end
	
	if os.time() > self.LastStolenAt + PlotManager.STEAL_COOLDOWN then
		self.LastStolenAt = os.time()
		
		local additionAmount = self.TownHallIncome
		if self.Owner.MembershipType == Enum.MembershipType.Premium then
			additionAmount *= 1.1
		end
		local otherManager = PlotManager.GetPlot(playerWhoIsStealing)
		if otherManager then
			if otherManager.ActiveBoosts["Cash"] then
				additionAmount *= 2
			end
		end
		
		playerWhoIsStealing.leaderstats.Coin.Value += additionAmount
		-- Log to roblox economy analytics, gaining for stealing player
		AnalyticsService:LogEconomyEvent(
			playerWhoIsStealing,
			Enum.AnalyticsEconomyFlowType.Source,
			"Coin", -- Currency name
			additionAmount, -- Amount earned
			playerWhoIsStealing.leaderstats.Coin.Value, -- Current balance
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name -- Transaction type
		)
		-- Log to roblox economy analytics, losing for player stolen from
		AnalyticsService:LogEconomyEvent(
			self.Owner,
			Enum.AnalyticsEconomyFlowType.Sink,
			"Coin", -- Currency name
			self.TownHallIncome, -- Amount earned
			self.Owner.leaderstats.Coin.Value, -- Current balance
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name -- Transaction type
		)
		
		self.TownHallIncome = 0
		
		self.Plot.TownHallPlotPiece.TownHall.IncomeDisplay.IncomeLabel.Income.Value = "$"..abbreviateNum(self.TownHallIncome).."/$"..Incomes[(self.Owner.UserId).."_TownHall"]["MaxIncome"]
		
		local UI = self.Plot.TownHallPlotPiece.TownHall.Sign.Top.CooldownUI
		ToggleUI:FireAllClients(UI, true, self.Owner)
		
		local percentValue = UI.CooldownFrame.Progress.Percentage
		local prompt = UI.Parent.StealPrompt
		StartCooldown:FireAllClients(percentValue, PlotManager.STEAL_COOLDOWN - (os.time() - self.LastStolenAt), prompt, self.Owner)
	else
		ShowErrorMessage:FireClient(playerWhoIsStealing, "Must wait to steal!")
	end
end

function PlotManager:UpdateStealPromptForPlayer(player)
	local isStealOnCooldown = not (os.time() > self.LastStolenAt + PlotManager.STEAL_COOLDOWN)
	
	local UI = self.Plot.TownHallPlotPiece.TownHall.Sign.Top.CooldownUI
	local prompt = UI.Parent.StealPrompt
	if isStealOnCooldown then 
		ToggleUI:FireClient(player, UI, true)
		local percentValue = UI.CooldownFrame.Progress.Percentage
		StartCooldown:FireClient(player, percentValue, PlotManager.STEAL_COOLDOWN - (os.time() - self.LastStolenAt), prompt, nil)
	end

	local collectPrompt = UI.Parent.CollectPrompt

	if not isStealOnCooldown then
		TogglePrompt:FireClient(player, prompt, true)
		TogglePrompt:FireClient(player, collectPrompt, false)
	end
end

function PlotManager:DisablePromptsForPlayer(player)
	for _, prompt in self.Plot.PurchasedPlotPieces:GetDescendants() do
		if not prompt:IsA("ProximityPrompt") then continue end
		TogglePrompt:FireClient(player, prompt, false)
	end
end

function PlotManager:LoadExpandedPlots()
	for _, pieceName in self.OwnedPieces do
		local piece = self.Plot.UnpurchasedPlotPieces:FindFirstChild(pieceName)
		if not piece then continue end
		
		piece.Parent = self.Plot.PurchasedPlotPieces
		piece.Transparency = 0
		piece.CanCollide = true
		self:LoadFenceOnPiece(piece)
		
		local plotButtons = self.Plot.PurchasePlotButtons:FindFirstChild(pieceName)
		SetProperties(plotButtons, {Transparency=0,CanCollide=true})
		self.ExpansionCost += COST_PER_EXPANSION
	end
	
	for _, button in self.Plot.PurchasePlotButtons:GetDescendants() do
		if not button:IsA("Part") then continue end
		local plotToPurchase = button.PlotToPurchase
		if plotToPurchase.Value.Parent == self.Plot.PurchasedPlotPieces then button:Destroy() end
	end
	
	self.Plot.PurchasePlotButtons.Cost.Value = self.ExpansionCost

end

function PlotManager:UpgradeFence(...)
	local nextFence = {...}
	if #nextFence == 0 then
		local nextFenceIdx = table.find(TownHallUpgrades.FenceTiers, self.FenceType)+1
		if nextFenceIdx > #TownHallUpgrades.FenceTiers then return end
		
		nextFence = TownHallUpgrades.FenceTiers[nextFenceIdx]
	end
	local nextFenceData = TownHallUpgrades.FenceUpgrades[nextFence]
	
	if self.TownHallLevel < nextFenceData["TownHallRequired"] then return ShowErrorMessage:FireClient(self.Owner, "Need Town Hall Level "..(self.TownHallLevel)) end
	
	local cash = self.Owner.leaderstats.Coin
	if cash.Value < nextFenceData.Price then return ShowErrorMessage:FireClient(self.Owner, "Not enough coins!") end
	
	self.FenceType = nextFence
	cash.Value -= nextFenceData.Price
	self:LoadFence()
	
	-- Log to roblox economy analytics
	AnalyticsService:LogEconomyEvent(
		self.Owner,
		Enum.AnalyticsEconomyFlowType.Sink,
		"Coin", -- Currency name
		nextFenceData.Price, -- Cost
		self.Owner.leaderstats.Coin.Value, -- Current balance
		Enum.AnalyticsEconomyTransactionType.ContextualPurchase.Name -- Transaction type
	)
	
	Incomes[self.Owner.UserId] = {
		["Income"] = nextFenceData.Income, 
		["IncomeWaitTime"] = nextFenceData.IncomeWaitTime,
		["LastPayment"] = os.time()
	}
	LoadFenceData(self.Owner, self.FenceType)
end

function PlotManager:LoadFenceOnPiece(plotPiece)
	for _, child in plotPiece:GetChildren() do
		if string.find(child.Name, "Fence") and child.Name ~= (self.FenceType).."Fence" then
			-- Hide other fence models
			SetProperties(child, {Transparency=1, CanCollide=false})
			SetProperties(self.Plot.PurchasePlotButtons:FindFirstChild(child.Name), {Transparency=1, CanCollide=false})
		else
			-- Show model
			SetProperties(child, {Transparency=0, CanCollide=true})
			SetProperties(self.Plot.PurchasePlotButtons:FindFirstChild(child.Name), {Transparency=0, CanCollide=true})
		end
	end
end

function PlotManager:LoadFence()
	for _, plotPiece in self.Plot.PurchasedPlotPieces:GetChildren()  do
		self:LoadFenceOnPiece(plotPiece)
	end
end

function PlotManager:CleanupPlot()
	local newPlot = RS.Plots:FindFirstChild(self.Plot.Name):Clone()
	
	Instances[self.Owner.UserId] = nil
	Incomes[self.Owner.UserId] = nil
	Incomes[(self.Owner.UserId).."_TownHall"] = nil
	
	self.BuildingsManager:Cleanup()


	self.Plot:Destroy()
	setmetatable(self, nil)
	
	newPlot.Parent = workspace
end

function PlotManager:GetPlotForSaving()
	return {
		["OwnedPieces"] = self.OwnedPieces,
		["FenceType"] = self.FenceType,
		["TownHallLevel"] = self.TownHallLevel,
		["TownHallIncome"] = self.TownHallIncome,
		["LastCollectedAt"] = self.LastCollectedAt,
		["LastStolenAt"] = self.LastStolenAt,
		["Sales"] = self.Sales,
		["ActiveBoosts"] = self.ActiveBoosts,
	}
end

GetActiveBoosts.OnInvoke = function(player)
	local manager = Instances[player.UserId]
	if not manager then return end
	
	return manager.ActiveBoosts
end

task.spawn(function()
	while true do
		local tickedBoostPlayers = {}
		local tickedTimedRewards = {}
		for ownerId, incomeData in Incomes do
			local id = ownerId
			if incomeData["MaxIncome"] then 
				id = tonumber(string.split(ownerId, "_")[1]) 
			end
			
			local owner = Players:GetPlayerByUserId(id)
			if not owner then continue end
			
			local plotManager = Instances[id]
			if not plotManager then continue end
			
			-- Tick Timed Rewards
			if table.find(tickedTimedRewards, owner.UserId) == nil then
				table.insert(tickedTimedRewards, owner.UserId)
				owner:WaitForChild("TimedRewardsElapsed").Value += 1
			end
			
			-- Tick Boosts
			local cashBoostActive = false
			if plotManager.ActiveBoosts["Cash"] and table.find(tickedBoostPlayers, owner.UserId) == nil then
				cashBoostActive = true
				
				plotManager.ActiveBoosts["Cash"] -= 1
				local ui = owner.PlayerGui.AnythingButTimeRewards.BoostsDisplay.CashBoost
				ui.Visible = true
				ui.TextLabel.Text = abbreviateTime(plotManager.ActiveBoosts["Cash"])
				if plotManager.ActiveBoosts["Cash"] <= 0 then
					plotManager.ActiveBoosts["Cash"] = nil
					ui.TextLabel.Text = "00:00"
					ui.Visible = false
				end
				table.insert(tickedBoostPlayers, owner.UserId)
			end
			if plotManager.ActiveBoosts["Growth"] and table.find(tickedBoostPlayers, owner.UserId.."_Growth") == nil then
				cashBoostActive = true

				local ui = owner.PlayerGui.AnythingButTimeRewards.BoostsDisplay.GrowBoost
				ui.Visible = true
				ui.TextLabel.Text = abbreviateTime(plotManager.ActiveBoosts["Growth"] - os.time())
				if plotManager.ActiveBoosts["Growth"] - os.time() <= 0 then
					plotManager.ActiveBoosts["Growth"] = nil
					ui.TextLabel.Text = "00:00"
					ui.Visible = false
				end
				table.insert(tickedBoostPlayers, owner.UserId.."_Growth")
			end
			
			-- Spawn NPCs
			if plotManager.BuildingsManager and plotManager.BuildingsManager.NPCManagers then -- this is a server loop and can run before player data initializes
				for idx, npcManager in plotManager.BuildingsManager.NPCManagers do
					if getmetatable(npcManager) ~= NPCManager then
						plotManager.BuildingsManager.NPCManagers[idx] = nil
						continue
					end
					npcManager:Spawn()
				end
			end
			
			-- Give Income
			if incomeData["MaxIncome"] and plotManager.TownHallIncome >= incomeData["MaxIncome"] then continue end
			
			local income = incomeData["Income"]
			local incomeWaitTime = incomeData["IncomeWaitTime"]
			local lastPayed = incomeData["LastPayment"]
			if os.time() - lastPayed >= incomeWaitTime then
				incomeData["LastPayment"] = os.time()
				if incomeData["MaxIncome"] then
					plotManager.TownHallIncome += income
					if plotManager.TownHallIncome > incomeData["MaxIncome"] then
						plotManager.TownHallIncome = incomeData["MaxIncome"]
					end
					if plotManager.Plot.TownHallPlotPiece:FindFirstChild("TownHall") then
						plotManager.Plot.TownHallPlotPiece.TownHall.IncomeDisplay.IncomeLabel.Income.Value = "$"..abbreviateNum(plotManager.TownHallIncome).."/$"..abbreviateNum(incomeData["MaxIncome"])
					end
				else
					if income > 0 then
						local amount = income
						
						if owner.MembershipType == Enum.MembershipType.Premium then
							amount *= 1.1
						end
						if cashBoostActive then
							amount *= 2
						end
						
						owner.leaderstats.Coin.Value += amount
						-- Log to roblox economy analytics
						AnalyticsService:LogEconomyEvent(
							owner,
							Enum.AnalyticsEconomyFlowType.Source,
							"Coin", -- Currency name
							amount, -- Amount earned
							owner.leaderstats.Coin.Value, -- Current balance
							Enum.AnalyticsEconomyTransactionType.TimedReward.Name -- Transaction type
						)
					end
				end
			end
		end
		task.wait(1)
	end
end)

return PlotManager