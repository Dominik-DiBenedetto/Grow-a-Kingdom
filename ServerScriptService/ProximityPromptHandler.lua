local RS = game:GetService("ReplicatedStorage")
local PPS = game:GetService("ProximityPromptService")
local SS = game:GetService("ServerStorage")

local SModules = SS.Modules
local PlotManager = require(SModules.PlotManager)

local CrateIndex = require(RS.ModuleScripts.Armor.Crates.CrateIndex)

local SellerTalk = RS.Remotes.Client.SellerTalk
local ToggleUI = RS.Remotes.Client.ToggleUI
local ToggleSpecificUI = RS.Remotes.Client.ToggleSpecificUI
local ToggleBlur = RS.Remotes.Client.ToggleBlur
local ShowError = RS.Remotes.Client.ShowErrorMessage
local PS = RS.Remotes.Client.PlaySound
local PlayOrbEffect = RS.Remotes.Client.PlayerOrbEffect
local tutorialEvent = RS.Remotes.Client.Tutorial

local SArmorRemotes = RS.Remotes.Server.ArmorSystem
local AddArmorEvent = SArmorRemotes.AddArmor

local STEAL_COOLDOWN = PlotManager.STEAL_COOLDOWN
local COLLECT_COOLDOWN = PlotManager.COLLECT_COOLDOWN

local stealingCooldowns, collectCooldowns = {}, {}

local PromptHandlers = {
	["OpenShop"] = function(prompt, player)
		ToggleUI:FireClient(player, "BuildingShop", true)
		ToggleUI:FireClient(player, "HUD", false)
		ToggleBlur:FireClient(player, true)

		local tutorialStep = player:FindFirstChild("TutorialStep")

		if tutorialStep and tutorialStep.Value == 1 then
			tutorialEvent:FireClient(player, 2)-- Let the client handle advancing to next step
		end
	end,
	["OpenSell"] = function(prompt, player)
		SellerTalk:FireClient(player, "Got anything to sell?")
		ToggleUI:FireClient(player, "BuildingSell", true)
		PS:FireClient(player, "Talk", 0.3)
		
		local tutorialStep = player:FindFirstChild("TutorialStep")

		if tutorialStep and tutorialStep.Value == 8 then
			tutorialEvent:FireClient(player, 9) -- Let the client handle advancing to next step
		end
	end,
	["OpenToolStore"] = function(prompt, player)
		ToggleUI:FireClient(player, "ToolStore", true)
		ToggleUI:FireClient(player, "HUD", false)
		ToggleBlur:FireClient(player, true)
	end,
	["OpenCrateShop"] = function(prompt, player)
		ToggleSpecificUI:FireClient(player, player.PlayerGui.ArmorUI.PurchaseCratesFrame, true)
		ToggleUI:FireClient(player, "HUD", false)
		ToggleBlur:FireClient(player, true)
	end,
	["CollectPrompt"] = function(prompt, player)
		local plot = prompt.Parent.Parent.Parent.Parent.Parent
		if player.OwnedPlot.Value ~= plot then return end
		
		local lastCollection = collectCooldowns[player.UserId] or 0
		if os.time() > lastCollection + COLLECT_COOLDOWN then -- local check to not spam remotes. real check happens in plot manager with saved time
			local manager = PlotManager.GetPlot(player.UserId)
			if not manager then return end
			
			PlayOrbEffect:FireClient(player, plot.TownHallPlotPiece.TownHall.Sign.PrimaryPart.Position)
			
			manager:CollectTownHallIncome()
			
			PS:FireClient(player, "Sell", true, 0.2)
			

			local tutorialStep = player:FindFirstChild("TutorialStep")

			if tutorialStep and tutorialStep.Value == 11 then
				tutorialEvent:FireClient(player, 12) -- Let the client handle advancing to next step
			end
			
			collectCooldowns[player.UserId] = os.time()
		else
			ShowError:FireClient(player, "Must wait to collect!")
		end
	end,
	["StealPrompt"] = function(prompt, player)
		local plot = prompt.Parent.Parent.Parent.Parent.Parent
		local plotOwner = plot.PlotOwner.Value
		if plotOwner == player or plotOwner == nil then return end
		
		local stealFromManager = PlotManager.GetPlot(plotOwner.UserId)
		if not stealFromManager then return end
		
		local lastSteal = stealingCooldowns[plotOwner.UserId] or 0
		if os.time() > lastSteal + STEAL_COOLDOWN then -- local check to not spam remotes. real check happens in plot manager with saved time
			stealFromManager:StealTownHallIncome(player)
			PlayOrbEffect:FireClient(player, plot.TownHallPlotPiece.TownHall.Sign.PrimaryPart.Position)
		else
			ShowError:FireClient(player, "Must wait for stealing cooldown to be over!")
		end
	end,
}

PPS.PromptTriggered:Connect(function(prompt, player)
	if string.find(prompt.Name, "ArmorCrate_") then
		local crateName = string.split(prompt.Name, "_")[2]
		local crate = CrateIndex[crateName]
		if not crate then return end

		local chosenArmor = crate:Roll(player)
		if not chosenArmor then return end

		AddArmorEvent:Fire(player, chosenArmor.Name)
		return
	end
	if not PromptHandlers[prompt.Name] then return end
	PromptHandlers[prompt.Name](prompt, player)
	
	
end)
