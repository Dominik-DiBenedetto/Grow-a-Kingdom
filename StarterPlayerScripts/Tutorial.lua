--// SERVICES
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

--// GUI
local tutorialGui = player:WaitForChild("PlayerGui"):WaitForChild("TutorialGui")
local tutorialText = tutorialGui:WaitForChild("Frame"):WaitForChild("TutorialText")

local loadingScreenGui = player.PlayerGui:WaitForChild("LoadingScreen")

--// REMOTES
local tutorialEvent = RS:WaitForChild("Remotes"):WaitForChild("Client"):WaitForChild("Tutorial")
local trailEvent = RS:WaitForChild("Remotes"):WaitForChild("Client"):WaitForChild("TrailEvent")
local AdvanceServerStepValue = RS.Remotes.Server.UpdateTutorialStep

--// TRAIL SETUP
local trailFolder = Instance.new("Folder", workspace)
trailFolder.Name = "TrailPath"

--// TRAIL CONFIG
tutorialText.Visible = false
local segmentSpacing = 2
local segmentSize = Vector3.new(0.5, 0.5, 0.5)
local trailColor = Color3.fromRGB(58, 161, 30)

--// SOUNDS
local talksound = game:GetService("SoundService"):WaitForChild("SFX"):WaitForChild("Talk")
talksound.Volume = 0.3

--// VARIABLES
local stepVal = player:WaitForChild("TutorialStep")
local ownedPlot = player:WaitForChild("OwnedPlot")

repeat task.wait(0.5) until ownedPlot.Value ~= nil

local step = stepVal.Value
local trailParts = {}
local renderConnection
local lastUpdate = tick()
local isTyping = false
local svConn, reConn = nil

--// TUTORIAL STEPS
local tutorialSteps = {
	[1] = {text = "Step 1: Go to the Market", target = workspace.Map.Booth.Buy.HumanoidRootPart},
	[2] = {text = "Step 2: Buy the Woodland Hut building.", target = nil},
	[3] = {text = "Step 3: Teleport to your Kingdom. You can do so by pressing the 'Kingdom' button.", target = player:WaitForChild("OwnedPlot").Value.TpDest},
	[4] = {text = "Step 4: Equip the building and select a spot to place it on your plot\n(click to place on pc and press the 'Place' button to place on mobile)", target = nil},
	[5] = {text = "Step 5: Wait for it to finish building... it may take a while lol", target = nil},
	[6] = {text = "Step 6: Your building is spawning in a Gardener! Collect the Gardener for their item...", target = nil},
	[7] = {text = "Step 7: Collect the building by walking up to it and pressing 'E' or clicking on the prompt.", target = nil},
	[8] = {text = "Step 8: Go to the Seller. You can teleport to him by pressing the 'Sell' button!", target = workspace.Map.Booth.Seller.HumanoidRootPart},
	[9] = {text = "Step 9: Sell the building for coins!", target = nil},
	[10] = {text = "Step 10: Go to your Town hall", target = ownedPlot.Value.TownHallPlotPiece},
	[11] = {text = "Step 11: You can collect your Townhall cash or steal from other players", target = ownedPlot.Value.TownHallPlotPiece.TownHall.Sign.Top},
}

--// TYPEWRITER EFFECT
local function typewrite(obj, text)
	isTyping = true
	obj.Text = ""
	for i = 1, #text do
		obj.Text = string.sub(text, 1, i)
		task.wait(0.02)
	end
	isTyping = false
end

--// CLEAR TRAIL
local beam = nil
local attachmentStart, attachmentEnd = nil, nil

--// Clear previous beam trail
local function clearTrail()
	if beam then
		beam:Destroy()
		beam = nil
	end
	if attachmentStart then
		attachmentStart:Destroy()
		attachmentStart = nil
	end
	if attachmentEnd then
		attachmentEnd:Destroy()
		attachmentEnd = nil
	end
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end


--// Draw Beam from player to target
local function drawTrail(target)
	if not target or not target:IsA("BasePart") then return end
	clearTrail()

	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
	if not torso then return end

	local a0 = Instance.new("Attachment")
	a0.Name = "TrailAttachmentStart"
	a0.Parent = torso

	local a1 = Instance.new("Attachment")
	a1.Name = "TrailAttachmentEnd"
	a1.Parent = target

	attachmentStart = a0
	attachmentEnd = a1

	local beamTemplate = RS:WaitForChild("VFX"):WaitForChild("Beam")
	local newBeam = beamTemplate:Clone()
	newBeam.Attachment0 = a1
	newBeam.Attachment1 = a0
	newBeam.Parent = trailFolder
	beam = newBeam
end

--// GO TO NEXT STEP
local function advanceTutorial()
	if step >= #tutorialSteps+2 then 
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		clearTrail()
		if svConn then
			svConn:Disconnect()
			svConn = nil
		end
		if reConn then
			reConn:Disconnect()
			reConn = nil
		end
		return
	end
	
	local current = tutorialSteps[step]
	--print("Advancing to", current)
	if isTyping then 
		repeat task.wait() until isTyping == false
	end
	if not current then
		tutorialText.Position = UDim2.new(0.5,0,0.8,0)
		tutorialText.Visible = true
		local lasttext = "Tutorial completed, have fun building your kingdom!"
		typewrite(tutorialText, lasttext)
		clearTrail()
		
		wait(#lasttext * 0.05)
		tutorialText.Visible = false
		return
	end
	tutorialText.Visible = true
	
	talksound:Play()
	typewrite(tutorialText, current.text)

	clearTrail()
	if current.target then
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		drawTrail(current.target)

		renderConnection = RunService.RenderStepped:Connect(function()
			if attachmentEnd then
				attachmentEnd.WorldPosition = current.target.Position
			end
		end)
	else
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		clearTrail()
	end
end

--// ADVANCE STEP REMOTELY
reConn = tutorialEvent.OnClientEvent:Connect(function(newStep, ...)	
	local extraParams = {...}
	local isLoading = false
	if #extraParams > 0 and extraParams[1] == true then isLoading = true end
	
	if typeof(newStep) == "number" and tutorialSteps[newStep] then
		if newStep < step then return end
		if not isLoading and newStep > step + 1 then return end

		AdvanceServerStepValue:FireServer(newStep)
	end
	
	if newStep == #tutorialSteps + 1 then
		stepVal.Value = newStep
		advanceTutorial()
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		clearTrail()
		newStep = #tutorialSteps + 2
		AdvanceServerStepValue:FireServer(newStep)
		reConn:Disconnect()
	end
end)

repeat task.wait() until loadingScreenGui.Enabled == false

advanceTutorial()
svConn = stepVal.Changed:Connect(function(newValue)
	step = newValue
	advanceTutorial()
end)


