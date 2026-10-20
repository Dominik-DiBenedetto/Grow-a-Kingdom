--// Services
local SS = game:GetService("ServerStorage")
local TagService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")

--// Variables
local Modules = SS.Modules
local NPCModules = Modules.NPCs
local NPCClass = require(NPCModules.NPC)

local Remotes = RS.Remotes
local RemoveNPCEvent = Remotes.Server.RemoveNPC

--// Local Functions
local function formatTime(timeLeft)
	local hours = math.floor(timeLeft / 3600) 
	local minutes = math.floor((timeLeft % 3600) / 60) 
	local secondsRemaining = timeLeft % 60 

	if hours > 0 then
		return string.format("%02i:%02i:%02i", hours, minutes, secondsRemaining)
	else
		return string.format("%02i:%02i", minutes, secondsRemaining)
	end
end

--// Module
local NPCManager = {}
NPCManager.__index = NPCManager

local Instances = {}

function NPCManager.New(player, plot, npcType, maxNPCs, defaultSpawnTime)
	local newManager = setmetatable({}, NPCManager)
	
	newManager.Player = player
	newManager.Plot = plot
	newManager.Level = 1
	newManager.SpawnedNPCs = {}
	newManager.SpawnedNPCsCount = 0
	newManager.NPCType = npcType
	newManager.MaxNPCs = maxNPCs
	newManager.SpawnTime = defaultSpawnTime
	newManager.LastSpawnTime = os.time()
	newManager.Display = nil
	
	Instances[player.UserId.."_"..npcType] = newManager
	
	return newManager
end

function NPCManager:ChangeDisplay(display)
	if not display then return end
	self.Display = display
	display.Enabled = true
end

function NPCManager.DespawnNPC(player, npcType, npcId)
	local manager = Instances[player.UserId.."_"..npcType]
	if not manager then return end
	
	if manager.SpawnedNPCs[npcId] then
		manager.SpawnedNPCs[npcId] = nil
		manager.SpawnedNPCsCount -= 1
	end
end

function NPCManager:Spawn()
	if self.LoadingNPCs then return end
	if self.Display then
		local fillBar = self.Display:FindFirstChild("ProgressBar")
		if not fillBar then return end
		
		fillBar = fillBar:FindFirstChild("FillBar")
		local Timer = self.Display:FindFirstChild("TimerDisplay")
		if not Timer or not fillBar then return end
		
		if self.SpawnedNPCsCount < self.MaxNPCs then
			local timeLeft = self.SpawnTime - (os.time() - self.LastSpawnTime)
			Timer.Text = formatTime(timeLeft).." ("..self.SpawnedNPCsCount.."/"..self.MaxNPCs..")"
			
			local percentDone = 1-math.clamp(timeLeft / self.SpawnTime, 0, 1)
			fillBar.Size = UDim2.new(percentDone,0,1,0)
		else
			Timer.Text = "MAX ("..self.SpawnedNPCsCount.."/"..self.MaxNPCs..")"
			fillBar.Size = UDim2.new(1,0,1,0)
		end
	end
	if self.SpawnedNPCsCount >= self.MaxNPCs then
		self.LastSpawnTime = os.time() -- we set this so that once space is made you have to go through full timer
		return 
	end
	if os.time() - self.LastSpawnTime < self.SpawnTime then return end
	
	local npc = NPCClass.New(self.NPCType, self.Level)

	self.SpawnedNPCs[npc.Id] = npc
	self.SpawnedNPCsCount += 1
	self.LastSpawnTime = os.time()
	npc:Spawn(self.Plot)
end

function NPCManager:SpawnLoadedNPCs(alreadySpawned, timeLeftAt)
	self.LoadingNPCs = true
	
	if alreadySpawned > self.MaxNPCs then alreadySpawned = self.MaxNPCs end
	if alreadySpawned > 0 then
		for i=1,alreadySpawned do
			local npc = NPCClass.New(self.NPCType, self.Level)

			self.SpawnedNPCs[npc.Id] = npc
			self.SpawnedNPCsCount += 1
			npc:Spawn(self.Plot)
		end
		if alreadySpawned == self.MaxNPCs then 
			self.LastSpawnTime = os.time() 
			self.LoadingNPCs = false
			return 
		end
	end
	
	local timeGone = os.time() - timeLeftAt
	local npcsToSpawn = math.floor(math.clamp(timeGone/self.SpawnTime, 0, self.MaxNPCs))
	
	if npcsToSpawn > 0 then
		for i=1,npcsToSpawn do
			local npc = NPCClass.New(self.NPCType, self.Level)

			self.SpawnedNPCs[npc.Id] = npc
			self.SpawnedNPCsCount += 1
			npc:Spawn(self.Plot)
		end
		if npcsToSpawn == self.MaxNPCs then
			self.LastSpawnTime = os.time()
		else
			self.LastSpawnTime = os.time() - (timeGone - (npcsToSpawn * self.SpawnTime))
		end
	else
		self.LastSpawnTime = timeLeftAt
	end
	self.LoadingNPCs = false
end

function NPCManager:LevelUp()
	self.Level += 1
end

function NPCManager:LevelDown()
	self.Level -= 1
	if self.Level <= 0 then
		for _, npc in self.SpawnedNPCs do
			NPCManager.DespawnNPC(self.Player, npc.Id)
		end
		setmetatable(self, nil)
	end
end

RemoveNPCEvent.Event:Connect(NPCManager.DespawnNPC)

return NPCManager
