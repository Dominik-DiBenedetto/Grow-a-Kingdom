local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local CamPart = workspace:WaitForChild("CamPart2")
local plr = game.Players.LocalPlayer

local caseui = plr.PlayerGui:WaitForChild("OpenCase")
local frame = caseui:FindFirstChild("Frame")
local btn = frame:FindFirstChild("CloseButton")

local holder = caseui:FindFirstChild("Holder")
local viewportFrame = holder:FindFirstChild("ViewportFrame")
local worldView = viewportFrame:FindFirstChild("WorldModel")

local OpenCaseRemote = RS.Remotes.Client.ArmorSystem.OpenCase
local caseTemplate = RS.CaseModel:WaitForChild("Case")
local topTemplate = caseTemplate:WaitForChild("Top")

frame.Visible = false

local function tweenModelCFrame(model, startCFrame, endCFrame, duration, easingStyle, easingDirection)
	local primaryPart = model.PrimaryPart
	if not primaryPart then return nil end

	local cfValue = Instance.new("CFrameValue")
	cfValue.Value = startCFrame

	local tweenInfo = TweenInfo.new(duration, easingStyle or Enum.EasingStyle.Linear, easingDirection or Enum.EasingDirection.Out)
	local tween = TweenService:Create(cfValue, tweenInfo, {Value = endCFrame})

	cfValue.Changed:Connect(function(value)
		model:SetPrimaryPartCFrame(value)
	end)

	tween.Completed:Connect(function()
		cfValue:Destroy()
	end)

	tween:Play()
	return tween
end

local function displayViewport(model, armorName)
	if worldView:FindFirstChildWhichIsA("Model") then
		worldView:FindFirstChildWhichIsA("Model"):Destroy()
	end
	if viewportFrame:FindFirstChildWhichIsA("Camera") then
		viewportFrame:FindFirstChildWhichIsA("Camera"):Destroy()
	end
	
	holder.Size = UDim2.new(0.0,0,0.0,0)
	viewportFrame.TextLabel.Text = armorName
	holder.Visible = true
	
	local subject = model:Clone()

	subject.Parent = worldView
	if string.find(model.Name, "Chestplate") then
		subject:PivotTo(CFrame.new(Vector3.new(0,0,-4)) * CFrame.Angles(math.rad(0), math.rad(90), math.rad(0)))
	elseif string.find(model.Name, "Helmet") then
		subject:PivotTo(CFrame.new(Vector3.new(0,0,-2)) * CFrame.Angles(math.rad(0), math.rad(180), math.rad(0)))
	else
		subject:PivotTo(CFrame.new(Vector3.new(-0.5,0,-2.5)) * CFrame.Angles(math.rad(0), math.rad(90), math.rad(0)))
	end

	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.new(Vector3.new(0,0, 0))
	camera.Parent = viewportFrame

	viewportFrame.CurrentCamera = camera
	
	TweenService:Create(holder, TweenInfo.new(0.5), {Size=UDim2.new(0.75,0,.75,0)}):Play()
end

local function dropAndSpin(model, originalCFrame)
	local dropHeight = 5
	local dropStart = originalCFrame * CFrame.new(0, dropHeight, 0) * CFrame.Angles(0, math.rad(-180), 0)
	return tweenModelCFrame(model, dropStart, originalCFrame, 1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

local uiToggles = {}
local function toggleOtherUI(enabled)
	if enabled == false then 
		table.clear(uiToggles)
	end
	for _, ui in plr.PlayerGui:GetChildren() do
		if ui.Name == "OpenCase" then continue end
		if enabled == true then
			ui.Enabled = uiToggles[ui.Name]
		else
			uiToggles[ui.Name] = ui.Enabled
			ui.Enabled = false
		end
	end
end

function OpenCase(armorModel, armorName)
	toggleOtherUI(false)
	
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CamPart.CFrame
	frame.Visible = true

	local newcase = caseTemplate:Clone()
	newcase.Parent = workspace
	newcase.Name = "Case"

	local originalCFrame = newcase.PrimaryPart.CFrame

	-- drop + spin
	local dropTween = dropAndSpin(newcase, originalCFrame)
	if dropTween then
		dropTween.Completed:Connect(function()
			local lid = newcase.Top
			local openCFrame = lid.PrimaryPart.CFrame * CFrame.Angles(math.rad(65), 0, 0)
			tweenModelCFrame(lid, lid.PrimaryPart.CFrame, openCFrame, 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.wait(0.5)
			displayViewport(armorModel, armorName)
		end)
	end
end

btn.MouseButton1Click:Connect(function()
	toggleOtherUI(true)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	frame.Visible = false
	holder.Visible = false

	local newcase = workspace:FindFirstChild("Case")
	if not newcase or not newcase:FindFirstChild("Top") then return end

	newcase:Destroy()
end)

OpenCaseRemote.OnClientEvent:Connect(OpenCase)
