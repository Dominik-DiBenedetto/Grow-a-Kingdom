--// Local (Private) functions
local function findArmorParents(character, armorType)
	if armorType == "Hemlet" then
		local head = character:WaitForChild("Head")
		return head
	elseif armorType == "Chestplate" then
		local torso = character:WaitForChild("Torso")
		return torso
	elseif armorType == "Leggings" then
		local leftLeg = character:WaitForChild("Left Leg")
		local rightLeg = character:WaitForChild("Right Leg")
		
		return leftLeg, rightLeg
	end
end

local function deleteArmorModel(parent)
	for _, child in pairs(parent:GetChildren()) do
		if child.Name == "Armor" then
			child:Destroy()
		end
	end
end

--// Module
local Armor = {}
Armor.__index = Armor

function Armor.new(data)
	local self = setmetatable({}, Armor)

	self.Name = data.Name
	self.Type = data.Type
	self.Defense = data.Defense or 0
	self.SpeedBoost = data.SpeedBoost or 0
	self.Model = data.Model

	return self
end

function Armor:ApplyTo(player)
	local char = player.Character or player.CharacterAdded:Wait()
	local humanoid = char:WaitForChild("Humanoid")
	
	-- Apply Boosts --
	local wasMaxHealth = humanoid.Health == humanoid.MaxHealth
	humanoid.MaxHealth += self.Defense
	if wasMaxHealth then humanoid.Health = humanoid.MaxHealth end
	
	humanoid.WalkSpeed += self.SpeedBoost
	
	-- Apply Model --
	if not self.Model then return end
	
	for _, child in self.Model:GetChildren() do
		local clone = child:Clone()
		local parent = char:FindFirstChild(child.Name)
		if not parent then continue end
		
		local weld = Instance.new("WeldConstraint")
		weld.Parent = clone
		weld.Part0 = clone
		weld.Part1 = parent
	
		clone.Name = child.Name.."Armor"
		
		local originalParent = self.Model.Parent:FindFirstChild(child.Name)
		local offset = originalParent.CFrame:ToObjectSpace(child.CFrame)
		clone.CFrame = parent.CFrame * offset
		if self.Type == "Helmet" then
			local description = humanoid:GetAppliedDescription()

			description.HatAccessory = 0
			description.HairAccessory = 0
			humanoid:ApplyDescription(description)
		end
		
		clone.Parent = parent
	end
end

function Armor:RemoveFrom(player)
	local char = player.Character or player.CharacterAdded:Wait()
	local humanoid = char:WaitForChild("Humanoid")

	humanoid.MaxHealth -= self.Defense
	humanoid.WalkSpeed -= self.SpeedBoost
	for _, child in self.Model:GetChildren() do
		local parent = char:FindFirstChild(child.Name)
		if not parent then continue end
		
		local armor = parent:FindFirstChild(child.Name.."Armor")
		if not armor then continue end
		armor:Destroy()
	end
end

return Armor
