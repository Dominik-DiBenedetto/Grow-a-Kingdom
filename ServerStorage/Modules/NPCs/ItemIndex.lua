--// Services
local RS = game:GetService("ReplicatedStorage")

--// Variables
local ItemModels = RS.Items

--// Module/Index
local ItemIndex = {}


ItemIndex.Peas = {
	["Name"] = "Peas",
	["Value"] = 15, 
	["Model"] = ItemModels.Peas
}

ItemIndex.Grapes = {
	["Name"] = "Grapes",
	["Value"] = 25, 
	["Model"] = ItemModels.Grapes
}

ItemIndex.Berries = {
	["Name"] = "Berries",
	["Value"] = 40, 
	["Model"] = ItemModels.Berries
}

ItemIndex.Bread = {
	["Name"] = "Bread",
	["Value"] = 60, 
	["Model"] = ItemModels.Bread
}

ItemIndex.Hay = {
	["Name"] = "Hay",
	["Value"] = 90, 
	["Model"] = ItemModels.Hay
}

ItemIndex.Meat = {
	["Name"] = "Meat",
	["Value"] = 150, 
	["Model"] = ItemModels.Meat
}

ItemIndex.Haystack = {
	["Name"] = "Haystack",
	["Value"] = 250, 
	["Model"] = ItemModels.Haystack
}

ItemIndex.LargeHaystack = {
	["Name"] = "LargeHaystack",
	["Value"] = 400, 
	["Model"] = ItemModels.Haystack
}

ItemIndex.FoamSword = {
	["Name"] = "FoamSword",
	["Value"] = 600, 
	["Model"] = ItemModels.FoamSword
}

ItemIndex.GardenHoe = {
	["Name"] = "GardenHoe",
	["Value"] = 900, 
	["Model"] = ItemModels.GardenHoe
}

ItemIndex.Axe = {
	["Name"] = "Axe",
	["Value"] = 1300, 
	["Model"] = ItemModels.Axe
}

ItemIndex.Pickaxe = {
	["Name"] = "Pickaxe",
	["Value"] = 1800, 
	["Model"] = ItemModels.Pickaxe
}

return ItemIndex