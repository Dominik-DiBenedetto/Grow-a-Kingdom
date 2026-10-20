local AnimalIndex = require(script.Parent.AnimalIndex)
local SS = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local AnimalManager = {}

local MAX_ANIMALS = 10
local SPAWN_INTERVAL = 10
local AnimalFolder = Workspace:FindFirstChild("Animals") or Instance.new("Folder", Workspace)
AnimalFolder.Name = "Animals"

local SpawnPoints = Workspace:WaitForChild("AnimalSpawns"):GetChildren()

local function getAliveAnimalsCount()
	local count = 0
	for _, a in ipairs(AnimalFolder:GetChildren()) do
		if a:FindFirstChild("Humanoid") and a.Humanoid.Health > 0 then
			count += 1
		end
	end
	return count
end

local function getRandomSpawn()
	local part = SpawnPoints[math.random(1, #SpawnPoints)]
	return part.Position
end

local function spawnAnimal(animalName)
	if getAliveAnimalsCount() >= MAX_ANIMALS then return end

	local data = AnimalIndex[animalName]
	if not data then return end

	local animal = data.Model:Clone()
	local npcScript = SS.Modules.Animals:WaitForChild("AnimalNPCScript"):Clone()
	npcScript.Disabled = false
	npcScript.Parent = animal

	animal:SetPrimaryPartCFrame(CFrame.new(getRandomSpawn()))
	animal.Parent = AnimalFolder
end

-- Public function to start spawning loop
function AnimalManager.StartSpawning()
	task.spawn(function()
		while true do
			task.wait(SPAWN_INTERVAL)
			spawnAnimal("Bear")
		end
	end)
end

return AnimalManager
