--// Services
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

--// Variables
local ItemIndex = require(SS.Modules.NPCs.ItemIndex)

local NPCModels = RS.NPCs
local ItemModels = RS.Items

--// Module/Index


local NPCIndex = {}

NPCIndex.Gardener = {
	["Model"] = NPCModels.Gardener,
	["Rarities"] = { ["Common"] = 60, ["Uncommon"] = 25, ["Rare"] = 10, ["Epic"] = 5 },
	["Items"] = {
		["Common"] = ItemIndex.Peas,
		["Uncommon"] = ItemIndex.Grapes,
		["Rare"] = ItemIndex.Berries,
		["Epic"] = ItemIndex.Bread,
	}
}

NPCIndex.Farmer = {
	["Model"] = NPCModels.Farmer,
	["Rarities"] = { ["Common"] = 60, ["Uncommon"] = 25, ["Rare"] = 10, ["Epic"] = 5 },
	["Items"] = {
		["Common"] = ItemIndex.Grapes,
		["Uncommon"] = ItemIndex.Berries,
		["Rare"] = ItemIndex.Bread,
		["Epic"] = ItemIndex.Hay,
	}
}

NPCIndex.Butcher = {
	["Model"] = NPCModels.Butcher, -- Or your preferred model
	["Rarities"] = { ["Common"] = 60, ["Uncommon"] = 25, ["Rare"] = 10, ["Epic"] = 5 },
	["Items"] = {
		["Common"] = ItemIndex.Berries,
		["Uncommon"] = ItemIndex.Bread,
		["Rare"] = ItemIndex.Hay,
		["Epic"] = ItemIndex.Meat,
	}
}

NPCIndex.Baker = {
	["Model"] = NPCModels.Baker,
	["Rarities"] = { ["Common"] = 60, ["Uncommon"] = 25, ["Rare"] = 10, ["Epic"] = 5 },
	["Items"] = {
		["Common"] = ItemIndex.Bread,
		["Uncommon"] = ItemIndex.Hay,
		["Rare"] = ItemIndex.Meat,
		["Epic"] = ItemIndex.Haystack,
	}
}

NPCIndex.Rancher = {
	["Model"] = NPCModels.Rancher,
	["Rarities"] = { ["Common"] = 60, ["Uncommon"] = 25, ["Rare"] = 10, ["Epic"] = 5 },
	["Items"] = {
		["Common"] = ItemIndex.Hay,
		["Uncommon"] = ItemIndex.Meat,
		["Rare"] = ItemIndex.Haystack,
		["Epic"] = ItemIndex.LargeHaystack,
	}
}

NPCIndex.Crafter = {
	["Model"] = NPCModels.Crafter,
	["Rarities"] = { ["Common"] = 60, ["Uncommon"] = 25, ["Rare"] = 10, ["Epic"] = 5 },
	["Items"] = {
		["Common"] = ItemIndex.Meat,
		["Uncommon"] = ItemIndex.Haystack,
		["Rare"] = ItemIndex.LargeHaystack,
		["Epic"] = ItemIndex.FoamSword,
	}
}

NPCIndex.Blacksmith = {
	["Model"] = NPCModels.Blacksmith,
	["Rarities"] = { ["Common"] = 60, ["Uncommon"] = 25, ["Rare"] = 10, ["Epic"] = 5 },
	["Items"] = {
		["Common"] = ItemIndex.Haystack,
		["Uncommon"] = ItemIndex.LargeHaystack,
		["Rare"] = ItemIndex.FoamSword,
		["Epic"] = ItemIndex.GardenHoe,
	}
}

NPCIndex.Guard = {
	["Model"] = NPCModels.Guard,
	["Rarities"] = { ["Common"] = 60, ["Uncommon"] = 25, ["Rare"] = 10, ["Epic"] = 5 },
	["Items"] = {
		["Common"] = ItemIndex.LargeHaystack,
		["Uncommon"] = ItemIndex.FoamSword,
		["Rare"] = ItemIndex.GardenHoe,
		["Epic"] = ItemIndex.Axe,
	}
}

NPCIndex.Miner = {
	["Model"] = NPCModels.Miner,
	["Rarities"] = { ["Common"] = 60, ["Uncommon"] = 25, ["Rare"] = 10, ["Epic"] = 5 },
	["Items"] = {
		["Common"] = ItemIndex.FoamSword,
		["Uncommon"] = ItemIndex.GardenHoe,
		["Rare"] = ItemIndex.Axe,
		["Epic"] = ItemIndex.Pickaxe,
	}
}

NPCIndex.Prospector = {
	["Model"] = NPCModels.Prospector,
	["Rarities"] = { ["Common"] = 60, ["Uncommon"] = 25, ["Rare"] = 10, ["Epic"] = 5 },
	["Items"] = {
		["Common"] = ItemIndex.GardenHoe,
		["Uncommon"] = ItemIndex.Axe,
		["Rare"] = ItemIndex.Pickaxe,
		["Epic"] = ItemIndex.Pickaxe, -- Epic gives a second chance at the best item
	}
}


return NPCIndex