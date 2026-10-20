local GrowthBoostTracker = {}
GrowthBoostTracker.__index = GrowthBoostTracker

function GrowthBoostTracker.new(boostHistory)
	return setmetatable({
		BoostHistory = boostHistory or {}
	}, GrowthBoostTracker)
end

-- Call this to start a new boost window (now -> now + duration)
function GrowthBoostTracker:AddBoost(duration)
	local now = os.time()
	
	table.insert(self.BoostHistory, {
		Start = now,
		End = now + duration
	})
end

-- Returns how many seconds of the given window were boosted
function GrowthBoostTracker:GetBoostedDuration(startTime, endTime)
	local boosted = 0
	for _, interval in ipairs(self.BoostHistory) do
		local overlapStart = math.max(startTime, interval.Start)
		local overlapEnd = math.min(endTime, interval.End)
		if overlapStart < overlapEnd then
			boosted += (overlapEnd - overlapStart)
		end
	end
	return boosted
end

-- Returns total adjusted progress seconds: unboosted + (boosted * 2)
function GrowthBoostTracker:GetAdjustedProgress(startTime, endTime)
	local totalElapsed = endTime - startTime
	local boosted = self:GetBoostedDuration(startTime, endTime)
	local normal = totalElapsed - boosted
	return normal + (boosted * 2)
end

-- Returns time remaining until GrowTime is completed, accounting for boosts
function GrowthBoostTracker:GetTimeLeft(startTime, growTime)
	local now = os.time()
	local adjusted = self:GetAdjustedProgress(startTime, now)
	return math.max(growTime - adjusted, 0)
end

return GrowthBoostTracker
