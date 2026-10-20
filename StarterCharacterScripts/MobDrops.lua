local Players = game:GetService("Players")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")

local PlotManager = require(SS.Modules.PlotManager)

local Player = Players:GetPlayerFromCharacter(script.Parent)

script.Parent.ChildAdded:Connect(function(child)
	if string.find(child.Name, "Meat") then
		if child:GetAttribute("Saved") then return end
		local plot = PlotManager.GetPlot(Player.UserId)
		plot.BuildingsManager.AddItemToInventory(Player, child.Name)
		child:SetAttribute("Saved", true)
		child.Parent = Player.Backpack
	end
end)