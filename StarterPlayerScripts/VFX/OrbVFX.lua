local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local orb = RS:WaitForChild("VFX"):WaitForChild("Orb")
local event = RS:WaitForChild("Remotes"):WaitForChild("Client"):WaitForChild("PlayerOrbEffect")

local Spacing = math.random(3,5)
local Height = math.random(2,5)
local Info = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local function CreateTween(part, target)
	return TweenService:Create(part, Info, {Position = target})
end

local function CurvePath(startPos, endPos, height)
	return function(t)
		local x = (1 - t) * startPos.X + t * endPos.X
		local y = (1 - t) * startPos.Y + t * endPos.Y + math.sin(t * math.pi) * height
		local z = (1 - t) * startPos.Z + t * endPos.Z
		return Vector3.new(x, y, z)
	end
end

local function Affect(startPosition)
	local character = player.Character or player.CharacterAdded:Wait()
	local rootPart = character:WaitForChild("HumanoidRootPart")
	local clones = {}

	-- create orbs
	for i = 1, 3 do
		local clone = orb:Clone()
		clone.Position = startPosition + Vector3.new((i - 2) * Spacing, 0, 0)
		clone.Parent = workspace
		table.insert(clones, clone)
	end

	-- animate orbs
	for _, clone in ipairs(clones) do
		local orbStartPos = clone.Position -- the starting position for this specific orb
		local startTime = tick()

		local connection
		connection = RunService.RenderStepped:Connect(function()
			local targetPosition = rootPart.Position
			local t = (tick() - startTime) / Info.Time

			if t >= 1 then
				connection:Disconnect()
				clone.Trail.Enabled = false
				clone.Transparency = 1
				task.wait(0.1)
				clone:Destroy()
			else
				-- recalc curve pos wit new target pos
				local x = (1 - t) * orbStartPos.X + t * targetPosition.X
				local y = (1 - t) * orbStartPos.Y + t * targetPosition.Y + math.sin(t * math.pi) * Height
				local z = (1 - t) * orbStartPos.Z + t * targetPosition.Z
				clone.CFrame = CFrame.new(Vector3.new(x, y, z))
			end
		end)
	end
end

event.OnClientEvent:Connect(function(startPos)
	Affect(startPos)
end)
