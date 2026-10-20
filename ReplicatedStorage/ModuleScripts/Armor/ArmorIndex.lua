local RS = game:GetService("ReplicatedStorage")
local ArmorModels = RS.ArmorModels

local Armor = require(script.Parent.ArmorClass)
local ArmorTypes = require(script.Parent.ArmorTypes)

return {
	["Cardboard Chestplate"] = Armor.new({
		Name = "Cardboard Chestplate",
		Type = ArmorTypes.Chestplate,
		Defense = 25,
		SpeedBoost = -1,
		Model = ArmorModels.CardboardArmor.Chestplate
	}),
	["Cardboard Helmet"] = Armor.new({
		Name = "Cardboard Helmet",
		Type = ArmorTypes.Helmet,
		Defense = 20,
		SpeedBoost = 0,
		Model = ArmorModels.CardboardArmor.Helmet
	}),
	["Cardboard Leggings"] = Armor.new({
		Name = "Cardboard Leggings",
		Type = ArmorTypes.Leggings,
		Defense = 10,
		SpeedBoost = 5,
		Model = ArmorModels.CardboardArmor.Leggings
	}),
	
	["Wooden Chestplate"] = Armor.new({
		Name = "Wooden Chestplate",
		Type = ArmorTypes.Chestplate,
		Defense = 50,
		SpeedBoost = -3,
		Model = ArmorModels.WoodenArmor.Chestplate
	}),
	["Wooden Helmet"] = Armor.new({
		Name = "Wooden Helmet",
		Type = ArmorTypes.Helmet,
		Defense = 40,
		SpeedBoost = 2,
		Model = ArmorModels.WoodenArmor.Helmet
	}),
	["Wooden Leggings"] = Armor.new({
		Name = "Wooden Leggings",
		Type = ArmorTypes.Leggings,
		Defense = 25,
		SpeedBoost = 10,
		Model = ArmorModels.WoodenArmor.Leggings
	}),
}
