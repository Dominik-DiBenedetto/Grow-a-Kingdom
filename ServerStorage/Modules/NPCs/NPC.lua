--// Services
local SS = game:GetService("ServerStorage")
local PathfindingService = game:GetService("PathfindingService")
local RS = game:GetService("ReplicatedStorage")

--// Variables
local Modules = SS.Modules
local NPCIndex = require(Modules.NPCs.NPCIndex)

local Remotes = RS.Remotes
local EnableProxPrompt = Remotes.Client.ToggleProxPrompt
local RemoveNPCEvent = Remotes.Server.RemoveNPC
local AddItemToInventoryEvent = Remotes.Server.AddItemToInventory


--// Local Functions
function scaleWeights(level, rarities)
	local scaled = {}
	for rarity, baseWeight in pairs(rarities) do
		local modifier = 1
		if rarity == "Common" then
			modifier = math.max(0.01, 1 - level * 0.02)
		elseif rarity == "Uncommon" then
			modifier = 1 + level * 0.01
		elseif rarity == "Rare" then
			modifier = 1 + level * 0.02
		elseif rarity == "Epic" then
			modifier = 1 + level * 0.03
		elseif rarity == "Legendary" then
			modifier = 1 + level * 0.04
		end
		scaled[rarity] = baseWeight * modifier
	end
	return scaled
end

local function generateNPCId(npcName)
	return npcName.."_"..tostring(os.time()) .. tostring(math.random(1000, 9999))
end

local function getRandomWalkPoint(walkableParts)
	local part = walkableParts[math.random(1, #walkableParts)]
	local size = part.Size
	local pos = part.Position

	local offsetX = (math.random() - 0.5) * size.X
	local offsetZ = (math.random() - 0.5) * size.Z

	return Vector3.new(pos.X + offsetX, pos.Y + 3, pos.Z + offsetZ) -- Y + 3 to stay above ground
end

local function isStuck(npc, timeout)
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not root then return true end

	local initialPos = root.Position
	local timer = 0
	local stuckThreshold = 1.5 -- max distance moved to not be stuck

	while timer < timeout do
		task.wait(0.5)
		timer += 0.5
		local currentPos = root.Position
		if (currentPos - initialPos).Magnitude > stuckThreshold then
			return false -- NPC moved, not stuck
		end
	end

	return true -- didn’t move enough in time
end


--// Module
local NPC = {}
NPC.__index = NPC

-- Creation
function NPC.New(npcType, level)
	local npcData = NPCIndex[npcType]
	if not npcData then
		return warn("'"..npcType.."' Is Not a Valid NPC!")
	end
	
	local newNPC = setmetatable({}, NPC)
	
	newNPC.Type = npcType
	newNPC.Level = level or 1
	newNPC.Model = npcData["Model"]
	newNPC.ItemPool = npcData["Items"]
	newNPC.Rarities = scaleWeights(newNPC.Level, npcData["Rarities"])
	newNPC.Id = generateNPCId(npcType)
	
	return newNPC
end

-- Spawn/Despawn
function NPC:Spawn(plot)
	if self.NPC ~= nil or self.SpawnedAtTime ~= nil then return warn("Already spawned") end
	
	local npc = self.Model:Clone()
	npc.Parent = plot
	npc:MoveTo(plot.TpDest.Position)
	
	self.SpawnedAtTime = os.time()
	self.NPC = npc
	self.Player = plot.PlotOwner.Value
	
	local levelDisplay = npc.BillboardGui.DisplayLevel
	levelDisplay.Text = "Level: "..self.Level
	
	task.wait(2)
	self:EnableProximityPrompt()
	self:Wander(plot.PurchasedPlotPieces:GetChildren())
end

function NPC:Despawn()
	if not self.NPC then return end
	
	RemoveNPCEvent:Fire(self.Player, self.Type, self.Id)
	self.NPC:Destroy()
	self.NPC = nil
	setmetatable(self, nil)
end

-- Actions
function NPC:Wander(walkparts)
	if self.NPC == nil then return end
	
	local humanoid = self.NPC:FindFirstChildOfClass("Humanoid")
	local animation = Instance.new("Animation")
	animation.AnimationId = "http://www.roblox.com/asset/?id=180426354"
	
	local animator = humanoid:FindFirstChild("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	
	task.spawn(function()
		while self.NPC do
			local destination = getRandomWalkPoint(walkparts)
			local path = PathfindingService:CreatePath()
			local primaryPart = self.NPC.PrimaryPart
			if not primaryPart then break end
			
			path:ComputeAsync(primaryPart.Position, destination)

			if path.Status == Enum.PathStatus.NoPath then
				continue
			end

			local waypoints = path:GetWaypoints()
			local track = animator:LoadAnimation(animation)
			track:Play()
			
			for _, wp in ipairs(waypoints) do
				humanoid:MoveTo(wp.Position)
				humanoid.MoveToFinished:Wait()
			end
			
			track:Stop()
			task.wait(math.random(2, 10)) -- how long to wait between moves
		end
	end)
end

function NPC:EnableProximityPrompt()
	if self.NPC == nil then return end
	
	local primary = self.NPC.PrimaryPart
	if not primary then return end
	
	local prompt = primary:FindFirstChild("NPCProx")
	if not prompt then return end
	
	EnableProxPrompt:FireAllClients(prompt, false, self.Player, true)
	prompt.Triggered:Connect(function(plr)
		if plr ~= self.Player then return end
		local item = self:SelectItem()
		if not item.Model or not item.Model:IsA("Tool") then return end
		
		--step 6 to 7 LOOOL
		local tutorialStep = plr:FindFirstChild("TutorialStep")

		if tutorialStep and tutorialStep.Value == 6 then
			local tutorialEvent = RS.Remotes.Client.Tutorial
			tutorialEvent:FireClient(plr, 7) -- Let the client handle advancing to next step
		end
		AddItemToInventoryEvent:Fire(plr, item.Name)
		item = item.Model:Clone()
		item.Parent = self.Player.Backpack
		self:Despawn()
	end)
end

function NPC:LevelUp()
	self.Level += 1
	
	-- Adjust item weights
	self.Rarities = scaleWeights(self.Level, self.Rarities)
end

function NPC:SelectItem()
	local total = 0
	for _, weight in self.Rarities do
		total += weight
	end

	local roll = math.random() * total
	local accum = 0
	local chosenRarity = nil
	for rarity, weight in self.Rarities do
		accum += weight
		if roll <= accum then
			chosenRarity = rarity
			break
		end
	end
	
	if not chosenRarity then return nil end
	
	return self.ItemPool[chosenRarity]
end

return NPC
