local BadgeService = game:GetService("BadgeService")

local badgeNamesToIds = {
	["CompletedCommonBuilding"] = 377143627405188,
	["CompletedUncommonBuilding"] = 1766496055647194,
	["CompletedRareBuilding"] = 2399378913896778,
	["TownHall2"] = 2931492936072053
}


if game.GameId == _G.testingGameId then -- Testing server game ID, switch to testing server badgeIds
	badgeNamesToIds = {
		["CompletedCommonBuilding"] = 142567060055885,
		["CompletedUncommonBuilding"] = 2895313027337291,
		["CompletedRareBuilding"] = 3504209754993066,
		["TownHall2"] = 318797341389349
	}
end

local BadgeManager = {}

function BadgeManager.AwardBadge(player, badgeName)
	local badgeId = badgeNamesToIds[badgeName] or badgeName
	-- Fetch badge information
	local success, badgeInfo = pcall(function()
		return BadgeService:GetBadgeInfoAsync(badgeId)
	end)
	
	if not success then warn("Error fetching badge with id "..badgeId) return end
	if not badgeInfo.IsEnabled then warn("Badge '"..badgeId.."' is not enabled!") return end
	
	-- Award badge
	local awardSuccess, result = pcall(function()
		return BadgeService:AwardBadge(player.UserId, badgeId)
	end)

	if not awardSuccess then
		warn("Error while awarding badge:", result)
		return
	elseif not result then
		warn("Failed to award badge.")
		return
	end
	
	print("Badge awarded!")
	return true
end

function BadgeManager.UserOwnsBadge(player, badgeName)
	local badgeId = badgeNamesToIds[badgeName] or badgeName
	local success, hasBadge = pcall(function()
		return BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
	end)

	if not success then
		warn("Error while checking if player has badge!")
		return false
	end

	if not hasBadge then return false end
	
	print(player.Name, "has badge", badgeId)
	return true
end

function BadgeManager.UserOwnsBadges(player, badgeIds)
	-- Check if the player has any of the badges
	local success, result = pcall(function()
		return BadgeService:CheckUserBadgesAsync(player.UserId, badgeIds)
	end)
	
	if not success then
		warn("Error while checking if player", player.Name, "has badges:", result)
		return false
	end
	
	if #result == 0 then return false end
	
	return result
end

return BadgeManager