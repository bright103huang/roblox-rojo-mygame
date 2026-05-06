-- ============================================================
-- 文件：ServerScriptService.Server.Systems.MeritService.lua
-- 功能：天兵功勋系统 — 管理功勋累积和军衔晋升
--       功勋门槛：天兵 → 天将 需要 100 功勋
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)

-- ============================================================
-- 配置
-- ============================================================
local RANKS = {
	{ Name = "天兵", MeritRequired = 0 },
	{ Name = "天将", MeritRequired = 100 },
}

-- 晋升时通知客户端的事件名
local PROMOTION_EVENT_NAME = "Promotion:Merit"

-- ============================================================
-- MeritService
-- ============================================================

local MeritService = {}

-- 增加功勋（自动检测晋升）
-- @param player Player
-- @param amount number 增加的功勋值
-- @return boolean, string? 是否成功，若晋升则返回新军衔
function MeritService.AddMerit(player, amount)
	if amount <= 0 then return false, "InvalidAmount" end

	local data = DataManager:GetData(player)
	if not data then return false, "NoData" end

	-- 增加功勋
	local oldMerit = data.Merit or 0
	local newMerit = oldMerit + amount
	data.Merit = newMerit
	DataManager:UpdateField(player, "Merit", newMerit)

	-- 检测晋升
	local oldRank = data.MilitaryRank or "天兵"
	local newRank = oldRank

	for i = #RANKS, 1, -1 do
		if newMerit >= RANKS[i].MeritRequired then
			newRank = RANKS[i].Name
			break
		end
	end

	if newRank ~= oldRank then
		-- 晋升！
		data.MilitaryRank = newRank
		DataManager:UpdateField(player, "MilitaryRank", newRank)

		print("     " .. player.Name .. " 晋升为 【" .. newRank .. "】！功勋: " .. newMerit)

		-- 通知客户端
		local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
		if eventsFolder then
			local taskEvent = eventsFolder:FindFirstChild("TaskEvent")
			if taskEvent then
				taskEvent:FireClient(player, PROMOTION_EVENT_NAME, {
					OldRank = oldRank,
					NewRank = newRank,
					Merit = newMerit,
				})
			end
		end

		return true, "Promoted:" .. newRank
	end

	print("  " .. player.Name .. " 功勋 +" .. amount .. "（当前: " .. newMerit .. "）")
	return true, "Added"
end

-- 获取玩家当前军衔
-- @param player Player
-- @return string 军衔名（"天兵" / "天将"）
function MeritService.GetRank(player)
	local data = DataManager:GetData(player)
	if not data then return "天兵" end
	return data.MilitaryRank or "天兵"
end

-- 获取玩家当前功勋值
-- @param player Player
-- @return number
function MeritService.GetMerit(player)
	local data = DataManager:GetData(player)
	if not data then return 0 end
	return data.Merit or 0
end

-- 检查玩家是否已达到指定军衔
-- @param player Player
-- @param rankName string 军衔名
-- @return boolean
function MeritService.HasRank(player, rankName)
	local currentRank = MeritService.GetRank(player)
	local rankIndex = 0
	local targetIndex = 0

	for i, rank in ipairs(RANKS) do
		if rank.Name == currentRank then
			rankIndex = i
		end
		if rank.Name == rankName then
			targetIndex = i
		end
	end

	return rankIndex >= targetIndex
end

-- 取下一级军衔信息（用于 UI 显示进度）
-- @param player Player
-- @return string?, number? 下一级军衔名，还需多少功勋（nil 表示已满级）
function MeritService.GetNextRankInfo(player)
	local data = DataManager:GetData(player)
	if not data then return nil, nil end

	local currentMerit = data.Merit or 0

	for i = 1, #RANKS do
		if currentMerit < RANKS[i].MeritRequired then
			return RANKS[i].Name, RANKS[i].MeritRequired - currentMerit
		end
	end

	return nil, nil  -- 已满级
end

print("  MeritService（功勋系统）已启动")

return MeritService
