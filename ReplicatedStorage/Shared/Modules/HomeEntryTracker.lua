-- ============================================================
-- 文件：ReplicatedStorage.Shared.Modules.HomeEntryTracker.lua
-- 功能：追踪玩家每次进入 Home 场景时各活动的使用状态
-- 用途：HomeServer 和 SceneManager 通过 require() 引用
-- 状态：每进一次 Home 场景，由 SceneManager 调用 Reset()
-- ============================================================

local HomeEntryTracker = {}
local usage = {}  -- [userId] = { Meditated = bool, Slept = bool, Prayed = bool }

function HomeEntryTracker.Reset(player)
	usage[player.UserId] = { Meditated = false, Slept = false, Prayed = false }
end

function HomeEntryTracker.CanUse(player, action)
	local u = usage[player.UserId]
	return u and not u[action] or false
end

function HomeEntryTracker.MarkUsed(player, action)
	local u = usage[player.UserId]
	if u then u[action] = true end
end

return HomeEntryTracker
