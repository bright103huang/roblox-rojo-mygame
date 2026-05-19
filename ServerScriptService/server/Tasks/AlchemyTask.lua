-- ============================================================
-- 文件：ServerScriptService.Server.Tasks.AlchemyTask.lua
-- 功能：炼丹任务处理器
-- 流程：取药材 → 放药材入炉 → 取柴火×3 → 添柴×3 → 成丹/炸炉
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(script.Parent.Parent.Systems.DataManager)
local StatusService = require(script.Parent.Parent.Systems.StatusService)
local Config = require(ReplicatedStorage.Shared.Config)

-- ============================================================
-- 分步消耗常量
-- ============================================================
local COSTS = {
	PickHerb    = { Spirit = -5, Fatigue = 1 },
	PickFirewood = { Spirit = -3, Fatigue = 1 },
	AddFuel     = { Spirit = -5, Fatigue = 2 },
}

local MAX_CRAFT_ATTEMPTS = 5

-- ============================================================
-- 状态
-- ============================================================
local carrying = {}     -- [userId] = "herb" | "firewood" | nil
local hasHerb = {}      -- [userId] = bool  药材是否已入炉
local alchemyStep = {}  -- [userId] = 0~3  添柴进度
local craftCount = {}
local isCrafting = {}   -- [userId] = number

-- ============================================================
-- 获取 TaskEvent RemoteEvent
-- ============================================================
local function getTaskEvent()
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then return nil end
	return eventsFolder:FindFirstChild("TaskEvent")
end

-- ============================================================
-- AlchemyTask
-- ============================================================
local AlchemyTask = {}

--- 玩家触摸材料台/柴火堆
function AlchemyTask.OnPlayerPickup(player, contextData)
	local partName = contextData and contextData.PartName or ""

	if partName == "HerbStation" then
			if isCrafting[player.UserId] then return false end
			carrying[player.UserId] = "herb"
			StatusService:ApplyCosts(player, COSTS.PickHerb)
			return true

	elseif partName == "Woodpile" then
		-- 必须先放药材入炉才能取柴
		if not hasHerb[player.UserId] then
			return false
		end
		carrying[player.UserId] = "firewood"
		StatusService:ApplyCosts(player, COSTS.PickFirewood)
		return true
	end

	return false
end

--- 玩家触摸丹炉（放药材/添柴/结算）
function AlchemyTask.OnPlayerDrop(player, _area)
	local userId = player.UserId

	if not carrying[userId] then
		return false, "NotCarrying"
	end

	if carrying[userId] == "herb" then
		-- 第一次：药材入炉，记录状态
		hasHerb[userId] = true
		isCrafting[userId] = true
		alchemyStep[userId] = 0
		craftCount[userId] = nil
		carrying[userId] = nil

		local taskEvent = getTaskEvent()
		if taskEvent then
			taskEvent:FireClient(player, "AlchemyHerbAccepted", {})
		end

		return false, "HerbAccepted"
	end

	-- carrying == "firewood"
	if not hasHerb[userId] then
		-- 还没放药材
		carrying[userId] = nil
		return false, "NeedHerbFirst"
	end

	-- 防御：如果 step 已 >= 3 但 craft 没执行（异常状态），重置
	if (alchemyStep[userId] or 0) >= 3 then
		warn("AlchemyTask: " .. player.Name .. " 异常状态 alchemyStep=" .. tostring(alchemyStep[userId]) .. "，重置")
		alchemyStep[userId] = nil
		hasHerb[userId] = nil
		player:SetAttribute("AlchemyStep", nil)
		return false, "NeedHerbFirst"
	end

	-- 添柴
	local step = alchemyStep[userId] + 1
	alchemyStep[userId] = step
	carrying[userId] = nil

	-- 消耗 Spirit/Fatigue
	StatusService:ApplyCosts(player, COSTS.AddFuel)

	-- 同步 step 到 Attribute 供客户端显示
	player:SetAttribute("AlchemyStep", step)
	player:SetAttribute("AlchemyMaxStep", 3)

	local taskEvent = getTaskEvent()

	if step < 3 then
		-- 第 1 或第 2 次添柴
		if taskEvent then
			taskEvent:FireClient(player, "AlchemyFuel", { Step = step })
		end
		player:SetAttribute("AlchemyCarrying", 0)  -- 服务端已清空 carrying
		return false, "FuelAdded"
	end

	-- ============================================================
	-- 第 3 次添柴 → 成丹结算
	-- ============================================================

	-- 每日上限检查
	craftCount[userId] = (craftCount[userId] or 0) + 1
	if craftCount[userId] > MAX_CRAFT_ATTEMPTS then
		alchemyStep[userId] = nil
		hasHerb[userId] = nil
		player:SetAttribute("AlchemyStep", nil)
		return false, "MaxAttempts"
	end

	local data = DataManager:GetData(player)
	if not data then
		alchemyStep[userId] = nil
		hasHerb[userId] = nil
		player:SetAttribute("AlchemyStep", nil)
		return false, "NoData"
	end

	-- 成功率 = 60% + 火候等级×3% - (火毒>60 ? 30% : 0)
	local alchemyLv = data.AlchemyLv or 1
	local firePoison = data.FirePoison or 0
	local successChance = 0.66 + alchemyLv * 0.03
	if firePoison > Config.Stats.FIREPOISON_REDLINE then
		successChance = successChance - 0.3
	end
	successChance = math.clamp(successChance, 0.1, 0.95)

	-- 虚不受补：Fatigue>80 + FirePoison>60 → 50% 炸炉
	local fatigue = data.Fatigue or 0
	local hasXuBuShou = fatigue > Config.Stats.CHAIN_REACTION.CHAIN_EXHAUSTION_FATIGUE
		and firePoison > Config.Stats.CHAIN_REACTION.CHAIN_EXHAUSTION_POISON
	if hasXuBuShou and math.random() < 0.5 then
		if taskEvent then
			taskEvent:FireClient(player, "AlchemyCraft", {
				Success = false,
				Reason = "虚不受补",
			})
		end
		alchemyStep[userId] = nil
		hasHerb[userId] = nil
		isCrafting[userId] = nil
		player:SetAttribute("AlchemyStep", nil)
		return false, "CraftDone"
	end

	-- 掷骰
	local success = math.random() <= successChance

	if success then
		-- 成丹奖励
		local taskCosts = StatusService:GetTaskCosts("Alchemy")
		if taskCosts and taskCosts.ApplyCost then
			StatusService:ApplyCosts(player, taskCosts.ApplyCost)
		end

		-- 回气丹效果
		StatusService:ApplyCosts(player, { Stamina = 20 })

		if taskEvent then
			taskEvent:FireClient(player, "AlchemyCraft", {
				Success = true,
				SuccessChance = math.floor(successChance * 100),
				AlchemyLv = alchemyLv,
			})
		end
	else
		-- 炸炉
		local taskCosts = StatusService:GetTaskCosts("Alchemy")
		if taskCosts and taskCosts.FailureCost then
			StatusService:ApplyCosts(player, taskCosts.FailureCost)
		else
			StatusService:ApplyCosts(player, { Spirit = -15, Fatigue = 20 })
		end

		if taskEvent then
			taskEvent:FireClient(player, "AlchemyCraft", {
				Success = false,
				Reason = "Explosion",
			})
		end
	end

	alchemyStep[userId] = nil
	hasHerb[userId] = nil
	isCrafting[userId] = nil
	player:SetAttribute("AlchemyStep", nil)
	return false, "CraftDone"
end

-- 玩家离开时清理
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	carrying[userId] = nil
	hasHerb[userId] = nil
	alchemyStep[userId] = nil
	craftCount[userId] = nil
	isCrafting[userId] = nil
end)

return AlchemyTask
