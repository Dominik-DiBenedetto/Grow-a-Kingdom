local RS = game:GetService("ReplicatedStorage")

local AnimalModels = RS:WaitForChild("Animals")
local AnimalDrops = RS:WaitForChild("AnimalDrops")

local AnimalIndex = {}

AnimalIndex.Bear = {
	Model = AnimalModels:WaitForChild("Bear"),
	Drops = {
		{
			Model = AnimalDrops:WaitForChild("Meat"),
			WeightRange = {5, 15},
			Rarity = 0.3
		}
	}
}

return AnimalIndex