--// Services
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--// Variables
local RoundMessage = RS.RoundMessage
local Arenas = SS.Arenas

local Remotes = RS.Remotes
local ToggleJoinBtn = Remotes.Client.RoundSystem.ToggleJoinButton
local ShowLeaderboard = Remotes.Client.RoundSystem.DIsplayLeaderboard
local UpdatePlacements = Remotes.Client.RoundSystem.UpdatePlacements

local JoinRoundEvent = Remotes.Server.RoundSystem.JoinGauntlet

local GetActiveBoosts = Remotes.Server.GetActiveBoosts

--// State
local curArena = nil
local playersInGauntlet = {}
local totalPlayers = 0

--// Constants
local TIME_BETWEEN_ROUNDS = 300
local MINIMUM_PLAYERS = 2

local PLACEMENT_REWARDS = {
	{100, 150, 250, 350, 500}, -- values for different amount of players in fight (2, 3, 4, 5, 6)
	{50, 100, 150, 200, 250},
	{0, 50, 100, 150, 200},
	{0, 0, 50, 100, 150},
	{0, 0, 0, 50, 100},
	{0, 0, 0, 0, 50}, -- 6th place
}

--// Helpers
local function abbreviateTime(timeLeft)
	local hours = math.floor(timeLeft / 3600) 
	local minutes = math.floor((timeLeft % 3600) / 60) 
	local secondsRemaining = timeLeft % 60 

	if hours > 0 then
		return string.format("%02i:%02i:%02i", hours, minutes, secondsRemaining)
	else
		return string.format("%02i:%02i", minutes, secondsRemaining)
	end
end

local function calculateReward(plr, placement)
	if not plr then return end
	
	local reward = PLACEMENT_REWARDS[placement][totalPlayers-1]
	local multi = plr.FriendBoost.Value

	if plr.MembershipType == Enum.MembershipType.Premium then
		multi += 0.1
	end

	local boosts = GetActiveBoosts:Invoke(plr)
	if boosts["Cash"] then
		multi *= 2
	end

	reward *= multi
	
	return reward
end

--// UI Actions
local function JoinRound(player)
	if table.find(playersInGauntlet, player.UserId) then return end
	
	ToggleJoinBtn:FireClient(player, false)
	table.insert(playersInGauntlet, player.UserId)
	totalPlayers += 1
	teleportToArena(player)
	
	local isArenaMatchStarted = Instance.new("BoolValue", player)
	isArenaMatchStarted.Value = false
	isArenaMatchStarted.Name = "isArenaMatchStarted"
end

--// Round Functions
local function selectArena()
	local arenas = Arenas:GetChildren()
	local arenaNum = math.random(1, #arenas)
	local arena = arenas[arenaNum]
	
	return arena
end

function teleportToArena(player)
	if not curArena then return end
	
	local spawns = curArena.Spawns:GetChildren()
	local usedSpawns = curArena.UsedSpawns
	
	local spawnNum = math.random(1, #spawns)
	local spawnLoc = spawns[spawnNum]
	
	if not spawnLoc then return end
	
	spawnLoc.Parent = usedSpawns
	
	local char = player.Character or player.CharacterAdded:Wait()
	char:PivotTo(spawnLoc.CFrame)
end

local function startRound()
	if curArena ~= nil then return end -- round in progress
	local clone = selectArena():Clone()
	clone.Parent = workspace
	curArena = clone
	
	ToggleJoinBtn:FireAllClients(true)
	for i=15,0,-1 do
		RoundMessage.Value = "Gauntlet Begins in: "..abbreviateTime(i)..(#playersInGauntlet < MINIMUM_PLAYERS and " ("..#playersInGauntlet.."/"..MINIMUM_PLAYERS.." players required)" or "")
		task.wait(1)
	end
	ToggleJoinBtn:FireAllClients(false)
	if #playersInGauntlet >= MINIMUM_PLAYERS then
		RoundMessage.Value = "Gauntlet in Progress..."
		
		for _, playerId in playersInGauntlet do
			local plr = Players:GetPlayerByUserId(playerId)
			if not plr then 
				table.remove(playersInGauntlet, table.find(playersInGauntlet, playerId))
				continue
			end
		
			local char = plr.Character
			if not char then
				table.remove(playersInGauntlet, table.find(playersInGauntlet, playerId))
				continue
			end
			
			local humanoid = char:FindFirstChild("Humanoid")
			if not humanoid then
				table.remove(playersInGauntlet, table.find(playersInGauntlet, playerId))
				continue
			end
			
			plr.isArenaMatchStarted.Value = true
			
			humanoid.Died:Connect(function()
				local placement = #playersInGauntlet
				table.remove(playersInGauntlet, table.find(playersInGauntlet, playerId))
				
				local reward = calculateReward(plr, placement)
				UpdatePlacements:FireAllClients(placement, plr, reward)
				
				local coins = plr.leaderstats.Coin
				coins.Value += reward
				
				plr.isArenaMatchStarted:Destroy()
			end)
		end
		
		repeat task.wait() until #playersInGauntlet <= 1
		
		task.wait(2)
		local winner = playersInGauntlet[1] or nil
		
		if winner then
			winner = Players:GetPlayerByUserId(winner)
			
			local ownedPlot = winner.OwnedPlot.Value
			if ownedPlot and ownedPlot:FindFirstChild("TpDest") then 
				local char = winner.Character
				if char then 
					char:PivotTo(ownedPlot.TpDest.CFrame)
				end
			end
			
			local reward = calculateReward(winner, 1)
			UpdatePlacements:FireAllClients(1, winner, reward)

			local coins = winner.leaderstats.Coin
			coins.Value += reward
			
			winner.isArenaMatchStarted:Destroy()
		end
		
		ShowLeaderboard:FireAllClients()
		RoundMessage.Value = "Gauntlet Won By: "..(winner and winner.Name or "None")
		task.wait(2)
		
		--// Reset
		curArena:Destroy()
		curArena = nil
		totalPlayers = 0
		table.clear(playersInGauntlet)
	else
		RoundMessage.Value = "Not Enough Players!"
		for _, playerId in playersInGauntlet do
			local plr = Players:GetPlayerByUserId(playerId)
			if not plr then continue end
			
			local ownedPlot = plr.OwnedPlot.Value
			if not ownedPlot or not ownedPlot:FindFirstChild("TpDest") then continue end
			
			local char = plr.Character
			if not char then continue end
			
			char:PivotTo(ownedPlot.TpDest.CFrame)
			
			plr.isArenaMatchStarted:Destroy()
		end
		task.wait(1)
		
		--// Reset
		curArena:Destroy()
		curArena = nil
		totalPlayers = 0
		table.clear(playersInGauntlet)
	end
	
end

--// Connections
JoinRoundEvent.OnServerEvent:Connect(JoinRound)
Players.PlayerRemoving:Connect(function(player)
	local idx = table.find(playersInGauntlet, player.UserId)
	if idx == nil then return end
	
	table.remove(playersInGauntlet, idx)
	totalPlayers -= 1
end)

--// Main Loop
while true do
	if curArena ~= nil then continue end
	for i=TIME_BETWEEN_ROUNDS,15,-1 do
		RoundMessage.Value = "Gauntlet Begins In: "..abbreviateTime(i)
		task.wait(1)
	end
	startRound()
end