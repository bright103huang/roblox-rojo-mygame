-- ============================================================
-- 文件：ServerScriptService.Server.Systems.MeritService.lua
-- 功能：天兵功勋系统 — 管理功勋累积和军衔晋升
--       功勋门槛：天兵 → 天将 需要 100 功勋
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)
local DataStoreService = game:GetService("DataStoreService")
local Config = require(ReplicatedStorage.Shared.Config)
local ExamConfig = Config.Exam

local rankingStore = DataStoreService:GetOrderedDataStore("TianbingRankings")

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

-- ============================================================
-- 自动晋升检测 + DataStore 排名
-- ============================================================

-- 自动检测晋升条件（在 StatusService.AddExp / ApplyCosts 中调用）
function MeritService.CheckAutoPromotion(player)
	local data = DataManager:GetData(player)
	if not data then return false end
	if data.IsRecruited then return false end  -- 已晋升，跳过

	-- 检查四项门槛（引用 ExamConfig）
	if (data.Agility or 1) < ExamConfig.MinAgility then return false end
	if (data.AlchemyLv or 1) < ExamConfig.MinAlchemy then return false end
	if (data.Combat or 1) < ExamConfig.MinCombat then return false end
	if (data.GongDe or 0) < ExamConfig.MinGongDe then return false end

	-- 全部达标，执行晋升
	MeritService.PromoteToTianBing(player)
	return true
end

-- 晋升天兵
function MeritService.PromoteToTianBing(player)
	local data = DataManager:GetData(player)
	if not data then return end

	-- 1. 设置晋升状态
	data.IsRecruited = true
	data.MilitaryRank = "天兵"
	DataManager:UpdateField(player, "IsRecruited", true)
	DataManager:UpdateField(player, "MilitaryRank", "天兵")
	player:SetAttribute("IsRecruited", true)

	-- 2. 记录完成天数
	local finishDay = data.TotalDays or 0

	-- 3. 写入 DataStore 排名
	local success, err = pcall(function()
		rankingStore:UpdateAsync(tostring(player.UserId), function(_oldValue)
			return finishDay, {
				UserId = player.UserId,
				Name = player.Name,
				Days = finishDay,
			}
		end)
	end)
	if not success then
		warn("TianbingRankings DataStore write failed for " .. player.Name .. ": " .. tostring(err))
	end

	-- 4. 获取排行榜前10
	-- 注意：DataStore 最终一致性，刚写入的记录可能不立即出现在结果中，
	-- 因此排名 = #rankings + 1 是估算值，下一轮读取会修正
	local rankings = MeritService.GetRankings()

	-- 5. 计算玩家排名（从前10列表中匹配）
	local rank = nil
	for i, entry in ipairs(rankings) do
		if entry.UserId == player.UserId then
			rank = i
			break
		end
	end

	-- 6. 通知客户端播放晋升仪式（先发事件，再传送，防止角色重置导致丢事件）
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if eventsFolder then
		local taskEvent = eventsFolder:FindFirstChild("TaskEvent")
		if taskEvent then
			taskEvent:FireClient(player, "PromotionCeremony", {
				Days = finishDay,
				Rank = rank or (#rankings + 1),
				Rankings = rankings,
			})
		end
	end

	-- 7. 传送至金色大厅
	local SceneManager = require(script.Parent.SceneManager)
	SceneManager.TeleportToScene(player, "GoldenHall")

	-- 立即落盘，防止服务器崩溃导致晋升数据丢失
	DataManager:Save(player)
end

function MeritService.GetRankings()
	local success, pages = pcall(function()
		return rankingStore:GetSortedAsync("Ascending", 10)
	end)
	if not success then return {} end

	local rankings = {}
	local page = pages:GetCurrentPage()
	if page then
		for _, item in ipairs(page) do
			table.insert(rankings, item.value)
		end
	end
	return rankings
end

print("  MeritService（功勋系统）已启动")

return MeritService
