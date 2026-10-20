local buildingIndex = {}

buildingIndex.BuildingsOrder = {
	"WoodlandHut", "RoseCottage", "MapleResidence", "RoundgateHall", "ScarletSpire",
	"StiltstoneHall", "ThreefoldWatch", "StonewatchBastion", "RedEmberHall", "MistwoodAltar"
}

-- Town Hall 1
buildingIndex.WoodlandHut = {
	["Price"] = 50,
	["Reward"] = 100, 
	["GrowTime"] = 60,
	["Rarity"] = "Common",
	["TownHallRequired"] = 1,
	["ProductId"] = 3347035012,
	["PriceInRobux"] = 7,
	["PictureId"] = "rbxassetid://121968707949158",
	["NPCType"] = "Gardener",
	["MaxNPCs"] = 1,
	["DefaultSpawnTime"] = 5, 
}

buildingIndex.RoseCottage = {
	["Price"] = 150,
	["Reward"] = 280, 
	["GrowTime"] = 120,
	["Rarity"] = "Common",
	["TownHallRequired"] = 1,
	["ProductId"] = 3347033249,
	["PriceInRobux"] = 10,
	["PictureId"] = "rbxassetid://78139429966593",
	["NPCType"] = "Farmer",
	["MaxNPCs"] = 2,
	["DefaultSpawnTime"] = 10,
}

buildingIndex.MapleResidence = {
	["Price"] = 400,
	["Reward"] = 750, 
	["GrowTime"] = 240,
	["Rarity"] = "Common",
	["TownHallRequired"] = 1,
	["ProductId"] = 3347007347,
	["PriceInRobux"] = 20,
	["PictureId"] = "rbxassetid://110256102064855",
	["NPCType"] = "Butcher",
	["MaxNPCs"] = 2,
	["DefaultSpawnTime"] = 20,
}

buildingIndex.RoundgateHall = {
	["Price"] = 1000, 
	["Reward"] = 1400, 
	["GrowTime"] = 480,
	["Rarity"] = "Uncommon",
	["TownHallRequired"] = 1,
	["ProductId"] = 3347033530,
	["PriceInRobux"] = 35,
	["PictureId"] = "rbxassetid://110310273575056",
	["NPCType"] = "Baker",
	["MaxNPCs"] = 3,
	["DefaultSpawnTime"] = 30,
}

buildingIndex.ScarletSpire = {
	["Price"] = 1800, 
	["Reward"] = 2500,
	["GrowTime"] = 960,
	["Rarity"] = "Uncommon",
	["TownHallRequired"] = 1,
	["ProductId"] = 3347033822,
	["PriceInRobux"] = 50,
	["PictureId"] = "rbxassetid://75421912596083",
	["NPCType"] = "Rancher",
	["MaxNPCs"] = 3,
	["DefaultSpawnTime"] = 45,
}

-- Town Hall 2
buildingIndex.StiltstoneHall = {
	["Price"] = 4000, 
	["Reward"] = 7000,
	["GrowTime"] = 1920,
	["Rarity"] = "Uncommon",
	["TownHallRequired"] = 2,
	["ProductId"] = 3347034069,
	["PriceInRobux"] = 75,
	["PictureId"] = "rbxassetid://108270858962865",
	["NPCType"] = "Crafter",
	["MaxNPCs"] = 4,
	["DefaultSpawnTime"] = 60,
}

buildingIndex.ThreefoldWatch = {
	["Price"] = 8000, 
	["Reward"] = 11000,
	["GrowTime"] = 3840,
	["Rarity"] = "Uncommon",
	["TownHallRequired"] = 2,
	["ProductId"] = 3347034716,
	["PriceInRobux"] = 110,
	["PictureId"] = "rbxassetid://75909663542300",
	["NPCType"] = "Blacksmith",
	["MaxNPCs"] = 5,
	["DefaultSpawnTime"] = 90,
}

buildingIndex.StonewatchBastion = {
	["Price"] = 16000, 
	["Reward"] = 23000,
	["GrowTime"] = 7680,
	["Rarity"] = "Rare",
	["TownHallRequired"] = 2,
	["ProductId"] = 3347034444,
	["PriceInRobux"] = 160,
	["PictureId"] = "rbxassetid://117112767855819",
	["NPCType"] = "Guard",
	["MaxNPCs"] = 5,
	["DefaultSpawnTime"] = 120,
}

buildingIndex.RedEmberHall = {
	["Price"] = 32000, 
	["Reward"] = 46000,
	["GrowTime"] = 12345,
	["Rarity"] = "Rare",
	["TownHallRequired"] = 2,
	["ProductId"] = 3347035732,
	["PriceInRobux"] = 225,
	["PictureId"] = "rbxassetid://87703003202094",
	["NPCType"] = "Miner",
	["MaxNPCs"] = 6,
	["DefaultSpawnTime"] = 150,
}

buildingIndex.MistwoodAltar = {
	["Price"] = 80000,
	["Reward"] = 100000,
	["GrowTime"] = 25720,
	["Rarity"] = "Rare",
	["TownHallRequired"] = 2,
	["ProductId"] = 3347035266,
	["PriceInRobux"] = 300,
	["PictureId"] = "rbxassetid://108603141849326",
	["NPCType"] = "Prospector",
	["MaxNPCs"] = 6,
	["DefaultSpawnTime"] = 180,
}

return buildingIndex
