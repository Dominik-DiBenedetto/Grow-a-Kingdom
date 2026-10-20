local plrs = game:GetService("Players")
local ps = game:GetService("PhysicsService")

ps:RegisterCollisionGroup("plrs")
ps:RegisterCollisionGroup("NPCs")

ps:CollisionGroupSetCollidable("plrs", "plrs", false)
ps:CollisionGroupSetCollidable("plrs", "NPCs", false)
ps:CollisionGroupSetCollidable("NPCs", "NPCs", false)


plrs.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(chr)
		for _, part in pairs(chr:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CollisionGroup = "plrs"
			end
		end
	end)
end)
