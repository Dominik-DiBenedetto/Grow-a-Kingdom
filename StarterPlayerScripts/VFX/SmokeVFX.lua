local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SmokeEffect = RS.Remotes.Client:WaitForChild("SmokeEffect")

local function createSmoothTween(smoke, startRate, endRate, duration)
	return TweenService:Create(smoke, 
		TweenInfo.new(duration, Enum.EasingStyle.Sine), 
		{Rate = endRate}
	)
end

SmokeEffect.OnClientEvent:Connect(function(building, playSmoke)
	if not building then 
		warn("No building specified")
		return 
	end

	if not playSmoke then return end

	local smoke = RS.VFX.Smoke:Clone()
	smoke.Parent = building

	smoke.Enabled = true
	smoke.Rate = 0

	local fadeInTween = createSmoothTween(smoke, 0, 100, 1)
	fadeInTween:Play()
	fadeInTween.Completed:Wait()

	local fadeOutTween = createSmoothTween(smoke, 100, 0, 1)
	fadeOutTween:Play()
	fadeOutTween.Completed:Wait()
	
	task.wait(0.2)
	
	smoke.Enabled = false
	smoke:Destroy()
end)
