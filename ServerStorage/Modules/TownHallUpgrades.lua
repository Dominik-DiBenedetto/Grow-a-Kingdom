local TownHallUpgrades = {}

TownHallUpgrades.FenceTiers = {"Wooden", "Rock"}

TownHallUpgrades.TownHalls = {
	{
		["Level"] = 1,
		["Price"] = 0,
		["IncomePerMinute"] = 250,
		["MaxIncome"] = 2_500
	},
	{
		["Level"] = 2,
		["Price"] = 10_000,
		["IncomePerMinute"] = 750,
		["MaxIncome"] = 10_000
	},
}

TownHallUpgrades.FenceUpgrades = {
	["Wooden"] = {
		["Price"] = 0,
		["Income"] = 0,
		["IncomeWaitTime"] = 0,
		["TownHallRequired"] = 1,
		["Type"] = "Wooden",
	},
	["Rock"] = {
		["Price"] = 7_500,
		["Income"] = 50,
		["IncomeWaitTime"] = 60,
		["TownHallRequired"] = 2,
		["Type"] = "Rock",
	}
}

return TownHallUpgrades
