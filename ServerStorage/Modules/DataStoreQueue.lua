local DataStoreQueue = {}
DataStoreQueue.__index = DataStoreQueue

function DataStoreQueue.new()
	return setmetatable({
		queue = {},
		isProcessing = false,
	}, DataStoreQueue)
end

function DataStoreQueue:Enqueue(callback)
	table.insert(self.queue, callback)
	if not self.isProcessing then
		task.spawn(function()
			self:Process()
		end)
	end
end

function DataStoreQueue:Process()
	self.isProcessing = true
	while #self.queue > 0 do
		local callback = table.remove(self.queue, 1)
		local success, err
		for attempt = 1, 5 do
			success, err = pcall(callback)
			if success then break end
			warn("[DataStoreQueue] Retry", attempt, "Error:", err)
			task.wait(2 ^ attempt) -- exponential backoff
		end
		if not success then
			warn("[DataStoreQueue] Gave up after retries:", err)
		end
		task.wait(0.1) -- small delay to avoid flooding
	end
	self.isProcessing = false
end

return DataStoreQueue
