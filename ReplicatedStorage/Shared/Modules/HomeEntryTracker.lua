local HomeEntryTracker = {}
local usage = {}  -- [userId] = { Meditated = bool, Slept = bool, Prayed = bool }

function HomeEntryTracker.Reset(player)
	usage[player.UserId] = { Meditated = false, Slept = false, Prayed = false }
end

function HomeEntryTracker.CanUse(player, action)
	-- action: "Meditated", "Slept", or "Prayed"
	local u = usage[player.UserId]
	return u and not u[action]
end

function HomeEntryTracker.MarkUsed(player, action)
	local u = usage[player.UserId]
	if u then u[action] = true end
end

-- Test helper: expose internal state for TDD assertions
function HomeEntryTracker._getUsage(userId)
	return usage[userId]
end

return HomeEntryTracker
