--// Services
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

--// Variables
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local Camera = workspace.CurrentCamera
local Plot = Player:WaitForChild("OwnedPlot")

local GrowCountdownLabel = Player.PlayerGui:WaitForChild("GrowTimeDisplay").Countdown
local BuildingNameCountdownLabel = GrowCountdownLabel.BuildingName

local Remotes = RS.Remotes
local PlantBuildingEvent = Remotes.Server.PlantBuilding
local GetPlantedBuildings = Remotes.Server.GetPlantedBuildings
local GrowPlant = Remotes.Server.GrowPlant
local UpdatePlantedBuildingsEvent = Remotes.Client.UpdatePlantedBuildings
local GetGrowTimeForBuilding = Remotes.Server.GetGrowTimeForBuilding

local Buildings = RS.Buildings

local raycastDistance = 1000
local isPreviewing = false

local plantedBuildings = {}
local namesCache = {}
local lastTimeLeft = -1
local completedBuildings = {}

local params = RaycastParams.new()
params.FilterDescendantsInstances = {Plot.Value.PurchasedPlotPieces}
params.FilterType = Enum.RaycastFilterType.Include

local rotation = CFrame.Angles(0,0,0)

local HUD = Player:WaitForChild("PlayerGui"):WaitForChild("HUD")
local placeUIBtn = HUD:WaitForChild("PlaceBuilding")
local rotateUIBtn = HUD:WaitForChild("RotateBuilding")

local hitPlot = nil
local lastTouchPosition = nil

local currentBuilding = nil
local cachedGrowTimes = {}

--// Functions

local function GetMouseTarget()
	if Plot.Value == nil then return end
	
	local mousePos = UIS:GetMouseLocation()
	local ray = Camera:ScreenPointToRay(mousePos.X, mousePos.Y)
	
	local hit = workspace:Raycast(ray.Origin, ray.Direction * raycastDistance, params)
	return hit
end

local function GetSnappedCFrameOnPlot(target, model, rotationCFrame)
	local base = model.PrimaryPart
	local baseSize = base.Size
	
	local rotationOnly = rotationCFrame - rotationCFrame.Position 
	local rotatedSize = Vector3.new(
		math.abs(rotationOnly.RightVector.X) * baseSize.X + math.abs(rotationOnly.UpVector.X) * baseSize.Y + math.abs(rotationOnly.LookVector.X) * baseSize.Z,
		math.abs(rotationOnly.RightVector.Y) * baseSize.X + math.abs(rotationOnly.UpVector.Y) * baseSize.Y + math.abs(rotationOnly.LookVector.Y) * baseSize.Z,
		math.abs(rotationOnly.RightVector.Z) * baseSize.X + math.abs(rotationOnly.UpVector.Z) * baseSize.Y + math.abs(rotationOnly.LookVector.Z) * baseSize.Z
	)

	local halfSize = rotatedSize / 2

	local plot = target.Instance
	local plotCF = plot.CFrame
	local plotSize = plot.Size
	local plotHalfSize = plotSize / 2

	local rotationOffset = CFrame.new(0, baseSize.Y / 2 + 0.01, 0) -- 0.01 buffer above surface

	local mouseWorld = hitPlot.Position
	local localPoint = plotCF:PointToObjectSpace(mouseWorld)

	-- clamp within plot bounds so model fits
	if -plotHalfSize.X + halfSize.X > plotHalfSize.X - halfSize.X or -plotHalfSize.Z + halfSize.Z > plotHalfSize.Z - halfSize.Z then return nil end
	
	localPoint = Vector3.new(
		math.clamp(localPoint.X, -plotHalfSize.X + halfSize.X, plotHalfSize.X - halfSize.X),
		0,
		math.clamp(localPoint.Z, -plotHalfSize.Z + halfSize.Z, plotHalfSize.Z - halfSize.Z)
	)

	local snappedLocal = CFrame.new(localPoint)
	local finalCFrame = plotCF * snappedLocal * rotationCFrame * rotationOffset

	return finalCFrame
end

local function SetProps(model, prop, value)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part[prop] = value
		end
	end
end

local function PlantBuilding(seed)
	if seed == nil then return end
	PlantBuildingEvent:FireServer(seed.PrimaryPart:GetAttribute("BuildingType"), seed.PrimaryPart.CFrame)
end

local function OverridePlantedBuildings(buildings)
	plantedBuildings = buildings
end

local function OnInputBegan(input, gpe)
	if input.UserInputType == Enum.UserInputType.Touch then
		lastTouchPosition = input.Position
	end
	
	if input.KeyCode == Enum.KeyCode.R then
		if script.PreviewPart.Value ~= nil then
			local _, ry, _ = rotation:ToEulerAnglesXYZ()
			rotation *= CFrame.Angles(0, math.rad(90), 0)
			
			if not hitPlot then return end
			local finalCFrame = GetSnappedCFrameOnPlot(hitPlot, script.PreviewPart.Value, rotation)
			if not finalCFrame then return end
			script.PreviewPart.Value:SetPrimaryPartCFrame(script.PreviewPart.Value.PrimaryPart.CFrame*rotation)
		end
	end
end

local function IsTouchOverGui()
	if not lastTouchPosition then return false end

	for _, guiObject in pairs(Player.PlayerGui:GetDescendants()) do
		if guiObject:IsA("GuiButton") 
			and guiObject.Visible 
			and guiObject.AbsoluteSize.Magnitude > 0 
			and guiObject.Parent:IsA("ScreenGui")
			and guiObject.Parent.Enabled then

			local pos = guiObject.AbsolutePosition
			local size = guiObject.AbsoluteSize

			if lastTouchPosition.X >= pos.X and lastTouchPosition.X <= pos.X + size.X
				and lastTouchPosition.Y >= pos.Y and lastTouchPosition.Y <= pos.Y + size.Y then
				return true
			end
		end
	end

	return false
end

--// Connections
RunService.RenderStepped:Connect(function()
	if IsTouchOverGui() then return end
	-- Preview
	local hit = GetMouseTarget()
	hitPlot = hit
	if hit then
		if script:FindFirstChild("Preview") then 
			script.PreviewPart.Value = script.Preview
			script.Preview.Parent = workspace 
		end
		if script.PreviewPart.Value ~= nil then
			if not UIS.KeyboardEnabled or not UIS.MouseEnabled then
				rotateUIBtn.Visible = true
				placeUIBtn.Visible = true
			end
			
			local finalCFrame = GetSnappedCFrameOnPlot(hit, script.PreviewPart.Value, rotation)
			if not finalCFrame then return end
			script.PreviewPart.Value:SetPrimaryPartCFrame(finalCFrame)
			
			local isIntersecting = false
			
			script.PreviewPart.Value.PrimaryPart.CanCollide = true
			for _, part in script.PreviewPart.Value.PrimaryPart:GetTouchingParts() do
				if part.Parent == script.PreviewPart.Value or string.find(part.Name, "PlotPiece") then continue end
				if part.Parent.Parent and string.find(part.Parent.Parent.Name, "PlotPiece") then
					isIntersecting = true
					SetProps(script.PreviewPart.Value, "Color", Color3.fromRGB(200,0,0))
					SetProps(script.PreviewPart.Value, "Transparency", 0.5)
					break
				end
			end
			script.PreviewPart.Value.PrimaryPart.CanCollide = true
			if not isIntersecting then
				SetProps(script.PreviewPart.Value, "Transparency", 0.5)
				SetProps(script.PreviewPart.Value, "Color", Color3.fromRGB(0,200,0))
			end
		else
			rotateUIBtn.Visible = false
			placeUIBtn.Visible = false
		end
	end
	
	-- Plant Growth Label
	local unitRay = Camera:ScreenPointToRay(Mouse.X, Mouse.Y)
	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 50, RaycastParams.new())
	if result and result.Instance.Parent then
		if result.Instance.Parent:FindFirstChild("TimeLeft") then
			local timeLeft = result.Instance.Parent:FindFirstChild("TimeLeft").Value
			local buildingName = string.split(result.Instance.Parent.Name, "Stage")[1]
			
			local timeToBuild = cachedGrowTimes[buildingName]
			if not timeToBuild then
				timeToBuild = GetGrowTimeForBuilding:InvokeServer(buildingName)
				cachedGrowTimes[buildingName] = timeToBuild
			end
			
			if lastTimeLeft ~= timeLeft then
				lastTimeLeft = timeLeft
				local hours = math.floor(timeLeft / 3600) 
				local minutes = math.floor((timeLeft % 3600) / 60) 
				local secondsRemaining = timeLeft % 60 
				
				local percentDone = 100
				if timeLeft > 0 then
					percentDone = 100-math.round((timeLeft/timeToBuild)*100)
				end
				
				if hours > 0 then
					GrowCountdownLabel.Text = percentDone.."% done ("..string.format("%02i:%02i:%02i", hours, minutes, secondsRemaining)..")"
				else
					GrowCountdownLabel.Text = percentDone.."% done ("..string.format("%02i:%02i", minutes, secondsRemaining)..")"
				end
			end
			
			
			BuildingNameCountdownLabel.Text = buildingName
			
			GrowCountdownLabel.Position = UDim2.new(0, Mouse.X, 0, Mouse.Y + GrowCountdownLabel.AbsoluteSize.Y + 34)
			GrowCountdownLabel.Visible = true
		else
			GrowCountdownLabel.Visible = false
		end
	else
		GrowCountdownLabel.Visible = false
	end
end)

if UIS.KeyboardEnabled and UIS.MouseEnabled then
	Mouse.Button1Down:Connect(function()
		PlantBuilding(script.PreviewPart.Value)
	end)
else
	rotateUIBtn.MouseButton1Click:Connect(function()
		if script.PreviewPart.Value ~= nil then
			local _, ry, _ = rotation:ToEulerAnglesXYZ()
			rotation *= CFrame.Angles(0, math.rad(90), 0)
			
			if not hitPlot then return end
			local finalCFrame = GetSnappedCFrameOnPlot(hitPlot, script.PreviewPart.Value, rotation)
			if not finalCFrame then return end
			script.PreviewPart.Value:SetPrimaryPartCFrame(finalCFrame)
		end
	end)
	placeUIBtn.MouseButton1Click:Connect(function()
		PlantBuilding(script.PreviewPart.Value)
	end)
end

UpdatePlantedBuildingsEvent.OnClientEvent:Connect(OverridePlantedBuildings)
UIS.InputBegan:Connect(OnInputBegan)