local DSS = game:GetService("DataStoreService")
local updateStore = DSS:GetDataStore("SoftShutdownFlag")

local UpdateStateStore = {}

function UpdateStateStore.SetUnderUpdate(isUpdating)
	updateStore:SetAsync("UnderUpdate", isUpdating)
end

function UpdateStateStore.IsUnderUpdate()
	return updateStore:GetAsync("UnderUpdate") == true
end

return UpdateStateStore
