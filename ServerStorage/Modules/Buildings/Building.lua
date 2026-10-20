--// Services
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local RunService = game:GetService("RunService")

--// Variables
local Modules = SS.Modules
local BuildingsModules = Modules.Buildings

local BuildingIndex = require(BuildingsModules.BuildingIndex)
local GrowthBoostTracker = require(BuildingsModules.GrowthBoostTracker)

local BuildingsFolder = RS.Buildings

local Remotes = RS.Remotes
local FinishBuildingEvent = Remotes.Server.FinishBuilding
local ToggleProxPrompt = Remotes.Client.ToggleProxPrompt

--// Local Function
local function generateBuildingId(buildingName)
	return buildingName.."_"..tostring(os.time()) .. tostring(math.random(1000, 9999))
end

local function SetProps(model, prop, value)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part[prop] = value
		end
	end
end

local function SerializeCFrame(cf)
	local pos = cf.Position
	local rot = {cf:ToOrientation()}
	return {
		pos = {pos.X, pos.Y, pos.Z},
		rot = {rot[1], rot[2], rot[3]}
	}
end

local function DeserializeCFrame(data)
	if not data or not data.pos or not data.rot then return CFrame.new() end
	local pos = Vector3.new(unpack(data.pos))
	local rot = CFrame.Angles(unpack(data.rot))
	return CFrame.new(pos) * rot
end

--// Module
local Building = {}
Building.__index = Building

function Building.New(player, buildingName, cframe, plotPiece, growthBoostTracker, loadedData)
	local buildingData = BuildingIndex[buildingName]
	if not buildingData then
		error("Couldn't find building '"..buildingName..".' It does not exist in the Building Index!")
		return
	end
	
	local newBuilding = setmetatable({}, Building) 
	for k, v in pairs(buildingData) do -- start with building data so it includes all information from the index
		newBuilding[k] = v
	end
	
	newBuilding.Owner = player
	newBuilding.Id = generateBuildingId(buildingName)
	newBuilding.Type = buildingName
	
	newBuilding.PlantedAtTime = loadedData and loadedData["PlantedAtTime"] or os.time()
	newBuilding.WasInstaGrown = loadedData and	loadedData["WasInstaGrown"] or false
	newBuilding.ScaffoldClearTime = 15
	
	newBuilding.BoostTracker = growthBoostTracker or { BoostHistory = {} }
	
	local buildingModel = BuildingsFolder[buildingName][buildingName]:Clone()
	SetProps(buildingModel, "Anchored", true)
	SetProps(buildingModel, "CanCollide", true)
	if loadedData then
		local savedCFrame = plotPiece.CFrame:ToWorldSpace(DeserializeCFrame(loadedData.Position))
		buildingModel:SetPrimaryPartCFrame(savedCFrame)
		newBuilding.BuildingCFrame = savedCFrame
	else 
		buildingModel:SetPrimaryPartCFrame(cframe)
		newBuilding.BuildingCFrame = cframe
	end
	
	buildingModel.Parent = plotPiece
	newBuilding.PlotPieceCFrame = plotPiece.CFrame
	newBuilding.PlotPieceName = plotPiece.Name
	
	local TimeLeft = Instance.new("IntValue")
	TimeLeft.Name = "TimeLeft"
	TimeLeft.Value = buildingData["GrowTime"]
	TimeLeft.Parent = buildingModel
	
	newBuilding.Model = buildingModel
	
	return newBuilding
end

function Building:AddActiveGrowthBoost(dur)
	self.BoostTracker:AddBoost(dur)
end

function Building:GetSpeedMultiplier(timestamp)
	local boosts = self.BoostTracker.BoostHistory
	local speedMultiplier = 1
	for _, boost in boosts do
		if boost.Start <= timestamp and timestamp <= boost.End then
			speedMultiplier = math.max(speedMultiplier, boost.Multiplier or 2)
		end
	end
	return speedMultiplier
end

function Building:GetElapsedGrowthTime(plantedAt, now)
	local totalElapsed = 0
	now = now or os.time()
	for _, boost in ipairs(self.BoostTracker.BoostHistory or {}) do
		local startTime = math.max(boost.Start, plantedAt)
		local endTime = math.min(boost.End, now)
		if startTime < endTime then
			totalElapsed += (endTime - startTime) * 2
		end
	end

	local normalTime = 0
	local timeCursor = plantedAt
	for _, boost in ipairs(self.BoostTracker.BoostHistory or {}) do
		if timeCursor < boost.Start then
			local gap = math.min(boost.Start, now) - timeCursor
			if gap > 0 then
				normalTime += gap
			end
		end
		timeCursor = math.max(timeCursor, boost.End)
	end

	if timeCursor < now then
		normalTime += now - timeCursor
	end

	totalElapsed += normalTime
	return totalElapsed
end

function Building:Grow(resumeFromElapsed)
	resumeFromElapsed = resumeFromElapsed or false

	local model = self.Model
	local parts = model:GetChildren()
	local primaryPrompt = model.PrimaryPart:FindFirstChildWhichIsA("ProximityPrompt")
	ToggleProxPrompt:FireAllClients(primaryPrompt, false, self.Owner, false)

	local growParts = {}
	local scaffoldParts = {}
	local originalSizes = {}

	for _, part in ipairs(parts) do
		local split = string.split(part.Name, "_")
		if tonumber(split[1]) then
			originalSizes[part.Name] = part.Size
			part.Size = Vector3.zero

			if #split == 1 then
				table.insert(growParts, part)
			elseif #split == 2 then
				table.insert(scaffoldParts, part)
			end
		end
	end

	table.sort(growParts, function(a, b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)

	table.sort(scaffoldParts, function(a, b)
		return tonumber(a.Name:match("(%d+)_E")) > tonumber(b.Name:match("(%d+)_E"))
	end)

	-- Instant build
	if self.WasInstaGrown then
		for name, size in pairs(originalSizes) do
			local part = model:FindFirstChild(name)
			if part then
				if not name:find("_E") then
					part.Size = size
				else
					part:Destroy()
				end
			end
		end
		FinishBuildingEvent:Fire(self.Owner, self)
		return
	end

	local totalTime = self.GrowTime
	local scaffoldTime = self.ScaffoldClearTime
	local growTime = totalTime - scaffoldTime
	local timePerPart = growTime / #growParts
	local scaffoldPerPart = scaffoldTime / #scaffoldParts

	local plantedAt = self.PlantedAtTime or os.time()
	local elapsedFromStart = resumeFromElapsed and self:GetElapsedGrowthTime(plantedAt, os.time()) or 0
	self.GrowthProgress = elapsedFromStart

	local start = os.clock() - (elapsedFromStart / self:GetSpeedMultiplier(os.time()))
	local TimeLeft = model:FindFirstChild("TimeLeft")

	local function getElapsed(building)
		building = setmetatable(building, Building)
		local now = os.clock()
		local rawElapsed = now - start
		return rawElapsed * building:GetSpeedMultiplier(os.time()) + elapsedFromStart
	end

	local steppedConn
	steppedConn = RunService.Heartbeat:Connect(function()
		local elapsed = getElapsed(self)
		local remaining = math.max(totalTime - elapsed, 0)

		if TimeLeft then
			TimeLeft.Value = math.floor(remaining)
		end

		-- Grow structure
		for index, part in ipairs(growParts) do
			local partStart = (index - 1) * timePerPart
			local partEnd = partStart + timePerPart
			local targetSize = originalSizes[part.Name]

			if elapsed >= partEnd then
				part.Size = targetSize
			elseif elapsed >= partStart then
				local alpha = math.clamp((elapsed - partStart) / timePerPart, 0, 1)
				part.Size = targetSize * alpha
			end

			local e_part = model:FindFirstChild(part.Name .. "_E")
			if e_part and originalSizes[e_part.Name] then
				local eSize = originalSizes[e_part.Name]
				if elapsed >= partEnd then
					e_part.Size = eSize
				elseif elapsed >= partStart then
					local alpha = math.clamp((elapsed - partStart) / timePerPart, 0, 1)
					e_part.Size = eSize * alpha
				end
			end
		end

		-- Clear scaffolds
		if elapsed >= growTime then
			local clearElapsed = elapsed - growTime
			for index, e_part in ipairs(scaffoldParts) do
				local partStart = (index - 1) * scaffoldPerPart
				local partEnd = partStart + scaffoldPerPart
				local fullSize = originalSizes[e_part.Name]

				if clearElapsed >= partEnd then
					e_part:Destroy()
				elseif clearElapsed >= partStart then
					local alpha = 1 - ((clearElapsed - partStart) / scaffoldPerPart)
					e_part.Size = fullSize * math.clamp(alpha, 0, 1)
				end
			end
		end

		if elapsed >= totalTime then
			steppedConn:Disconnect()
			FinishBuildingEvent:Fire(self.Owner, self)
		end
	end)
end


function Building:SimulateGrowthTo(elapsedTime)
	local growParts = {}
	local scaffoldParts = {}
	local scaledSizes = {}

	for _, part in ipairs(self.Model:GetChildren()) do
		local split = string.split(part.Name, "_")
		if tonumber(split[1]) then
			scaledSizes[part.Name] = part.Size
			if #split == 1 then
				table.insert(growParts, part)
			elseif #split == 2 then
				table.insert(scaffoldParts, part)
			end
		end
	end

	table.sort(growParts, function(a, b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)

	local growTime = self.GrowTime - self.ScaffoldClearTime
	local partTime = growTime / #growParts

	local totalPartTime = 0
	for i, part in ipairs(growParts) do
		local originalSize = scaledSizes[part.Name]
		local partStart = (i - 1) * partTime
		local partEnd = i * partTime

		if elapsedTime >= partEnd then
			part.Size = originalSize
			-- Scaffold fully grown
			local e_part = self.Model:FindFirstChild(part.Name .. "_E")
			if e_part then
				e_part.Size = scaledSizes[e_part.Name]
			end
		elseif elapsedTime >= partStart then
			local alpha = (elapsedTime - partStart) / partTime
			part.Size = originalSize * alpha

			local e_part = self.Model:FindFirstChild(part.Name .. "_E")
			if e_part then
				e_part.Size = scaledSizes[e_part.Name] * alpha
			end
		else
			part.Size = Vector3.zero
			local e_part = self.Model:FindFirstChild(part.Name .. "_E")
			if e_part then
				e_part.Size = Vector3.zero
			end
		end

		totalPartTime = partEnd
	end

	-- Scaffold clear simulation
	if elapsedTime > growTime then
		local clearElapsed = elapsedTime - growTime
		local clearPerPart = self.ScaffoldClearTime / #scaffoldParts

		table.sort(scaffoldParts, function(a, b)
			return tonumber(a.Name:match("(%d+)_E")) > tonumber(b.Name:match("(%d+)_E"))
		end)

		for i, e_part in ipairs(scaffoldParts) do
			local partStart = (i - 1) * clearPerPart
			local partEnd = i * clearPerPart

			if clearElapsed >= partEnd then
				e_part:Destroy()
			elseif clearElapsed >= partStart then
				local originalSize = e_part.Size
				local alpha = 1 - (clearElapsed - partStart) / clearPerPart
				e_part.Size = originalSize * alpha
			end
		end
	end
end

function Building:Load()
	local TimeLeft = self.Model:FindFirstChild("TimeLeft")
	local plantedAt = self.PlantedAtTime
	local now = os.time()
	local elapsed = self:GetElapsedGrowthTime(plantedAt, now)
	local remaining = math.max(self.GrowTime - elapsed, 0)

	if TimeLeft then TimeLeft.Value = math.floor(remaining) end
	
	if elapsed >= self.GrowTime then
		self:SimulateGrowthTo(elapsed)
		
		local primaryPrompt = self.Model.PrimaryPart:FindFirstChildWhichIsA("ProximityPrompt")
		ToggleProxPrompt:FireAllClients(primaryPrompt, false, self.Owner, true)
		FinishBuildingEvent:Fire(self.Owner, self)
	elseif self.WasInstaGrown then
		local primaryPrompt = self.Model.PrimaryPart:FindFirstChildWhichIsA("ProximityPrompt")
		ToggleProxPrompt:FireAllClients(primaryPrompt, false, self.Owner, true)
		FinishBuildingEvent:Fire(self.Owner, self)
	else
		self:Grow(true)
	end
end



function Building:InstaGrow()
	self.WasInstaGrown = true
end

function Building:Delete()
	self.Model:Destroy()
	setmetatable(self, nil)
end

function Building:Serialize()
	return {
		["PlantedAtTime"] = self["PlantedAtTime"],
		["BuildingType"] = self.Type,
		["GrowTime"] = self["GrowTime"],
		["PlotPiece"] = self.PlotPieceName,
		["Position"] = SerializeCFrame(self.PlotPieceCFrame:ToObjectSpace(self.BuildingCFrame)),
		["Stage"] = self.Stage,
		["WasInstaGrown"] = self.WasInstaGrown,
		["BoostHistory"] = self.BoostTracker.BoostHistory,
	}
end

function Building:SerializeFinishedBuilding()
	return {
		["Type"] = self.Type,
	}
end

return Building
