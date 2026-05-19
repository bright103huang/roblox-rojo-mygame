-- ============================================================
-- 文件：ServerScriptService.Server.Systems.StatusService.lua
-- 功能：状态管理系统 — 恢复、验证、扣除、升级、红线检测
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)
local Config = require(ReplicatedStorage.Shared.Config)

local StatsConfig = Config.Stats
local RiskConfig = Config.Risk

-- ============================================================
-- 本地引用
-- ============================================================
local SpeedCalculator = nil  -- 延迟加载，避免循环依赖
local TimeService = nil      -- 延迟加载，避免循环依赖
	local MeritService = nil     -- 延迟加载，避免循环依赖

local function getSpeedCalculator()
	if not SpeedCalculator then
		SpeedCalculator = require(script.Parent.SpeedCalculator)
	end
	return SpeedCalculator
end

local function getTimeModifier()
	if not TimeService then
		TimeService = require(script.Parent.TimeService)
	end
	if TimeService and TimeService.GetTimeModifier then
		return TimeService.GetTimeModifier()
	end
	return { RestEff = 1.0, TaskEff = 1.0, ShopOpen = false }
end

	local function getMeritService()
		if not MeritService then
			MeritService = require(script.Parent.MeritService)
		end
		return MeritService
	end

-- ============================================================
-- 火毒 DoT 跟踪
-- ============================================================
local firePoisonTimers = {}  -- [userId] = tick()

-- ============================================================
-- 辅助函数
-- ============================================================

local function clamp(value, min, max)
	return math.max(min, math.min(max, value))
end

-- ============================================================
-- StatusService
-- ============================================================

local StatusService = {}

-- 等级提升回调（由 TaskService 注册，用于触发场景选择面板）
StatusService.OnLevelUp = nil

-- 检查玩家能否执行任务
-- costs: { Stamina = 15, Spirit = 20 }
-- 返回: boolean, reason
function StatusService:CanPerformTask(player, costs)
	local data = DataManager:GetData(player)
	if not data then return false, "NoData" end

	if costs.Stamina and costs.Stamina > 0 then
		local stamina = data.Stamina or 0
		if stamina < costs.Stamina then
			return false, "体力不足（需要 " .. costs.Stamina .. "）"
		end
	end

	if costs.Spirit and costs.Spirit > 0 then
		local spirit = data.Spirit or 0
		if spirit < costs.Spirit then
			return false, "精神不足（需要 " .. costs.Spirit .. "）"
		end
	end

	return true, nil
end

-- 批量扣除状态
-- costsTable: { Stamina = -15, Fatigue = 10, AgilityExp = 5, ... }
-- 正数=增加，负数=减少
function StatusService:ApplyCosts(player, costsTable)
	local data = DataManager:GetData(player)
	if not data then return end

	-- 油尽灯枯: 双倍负面消耗（Stamina/Spirit 消耗翻倍，疲劳/火毒/戾气增加翻倍）
	local hasBurnout = (data.Stamina or 0) < StatsConfig.CHAIN_REACTION.CHAIN_BURNOUT_STAMINA
		and (data.Spirit or 0) < StatsConfig.CHAIN_REACTION.CHAIN_BURNOUT_SPIRIT

	local adjustedCosts = costsTable
	if hasBurnout then
		adjustedCosts = {}
		for field, delta in pairs(costsTable) do
			if (field == "Stamina" or field == "Spirit") and delta < 0 then
				adjustedCosts[field] = delta * 2
			elseif (field == "Fatigue" or field == "FirePoison" or field == "Malice") and delta > 0 then
				adjustedCosts[field] = delta * 2
			else
				adjustedCosts[field] = delta
			end
		end
	end

	for field, delta in pairs(adjustedCosts) do
		if field == "Stamina" then
			data.Stamina = clamp((data.Stamina or StatsConfig.MAX_STAMINA) + delta, 0, StatsConfig.MAX_STAMINA)
			DataManager:UpdateField(player, "Stamina", data.Stamina)

		elseif field == "Spirit" then
			data.Spirit = clamp((data.Spirit or StatsConfig.MAX_SPIRIT) + delta, 0, StatsConfig.MAX_SPIRIT)
			DataManager:UpdateField(player, "Spirit", data.Spirit)

		elseif field == "Fatigue" then
			data.Fatigue = clamp((data.Fatigue or 0) + delta, 0, StatsConfig.MAX_FATIGUE)
			DataManager:UpdateField(player, "Fatigue", data.Fatigue)

		elseif field == "FirePoison" then
			data.FirePoison = clamp((data.FirePoison or 0) + delta, 0, StatsConfig.MAX_FIRE_POISON)
			DataManager:UpdateField(player, "FirePoison", data.FirePoison)

		elseif field == "Malice" then
			data.Malice = clamp((data.Malice or 0) + delta, 0, StatsConfig.MAX_MALICE)
			DataManager:UpdateField(player, "Malice", data.Malice)

		elseif field == "XianJing" then
			data.XianJing = math.max(0, (data.XianJing or 0) + delta)
			DataManager:UpdateField(player, "XianJing", data.XianJing)

		elseif field == "GongDe" then
			data.GongDe = math.max(0, (data.GongDe or 0) + delta)
			DataManager:UpdateField(player, "GongDe", data.GongDe)

		elseif field == "AgilityExp" then
			self:AddExp(player, "Agility", delta)

		elseif field == "AlchemyExp" then
			self:AddExp(player, "AlchemyLv", delta)

		elseif field == "CombatExp" then
			self:AddExp(player, "Combat", delta)

		elseif field == "FatigueFixed" then
			-- 无视 clamp 的直接减（用于深夜结算）
			local newFatigue = math.max(0, (data.Fatigue or 0) + delta)
			data.Fatigue = newFatigue
			DataManager:UpdateField(player, "Fatigue", data.Fatigue)
		end
	end

	-- 过劳螺旋: Fatigue>80 时额外 Fatigue+2
	if (data.Fatigue or 0) > StatsConfig.FATIGUE_REDLINE then
		local extraFatigue = StatsConfig.CHAIN_REACTION.OVERWORK_EXTRA_FATIGUE
		data.Fatigue = math.min(StatsConfig.MAX_FATIGUE, data.Fatigue + extraFatigue)
		DataManager:UpdateField(player, "Fatigue", data.Fatigue)
	end

	-- 累倒检测: Fatigue>90 概率触发
	if (data.Fatigue or 0) > 90 and math.random() < StatsConfig.CHAIN_REACTION.COLLAPSE_CHANCE then
		data.Fatigue = StatsConfig.CHAIN_REACTION.COLLAPSE_FATIGUE_RESET
		data.Stamina = math.max(0, (data.Stamina or 0) - StatsConfig.CHAIN_REACTION.COLLAPSE_STAT_PENALTY)
		data.Spirit = math.max(0, (data.Spirit or 0) - StatsConfig.CHAIN_REACTION.COLLAPSE_STAT_PENALTY)
		DataManager:UpdateField(player, "Fatigue", data.Fatigue)
		DataManager:UpdateField(player, "Stamina", data.Stamina)
		DataManager:UpdateField(player, "Spirit", data.Spirit)
		print("💤 " .. player.Name .. " 累倒了！强制休息")
		-- 通知客户端
		local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
		if eventsFolder then
			local taskEvent = eventsFolder:FindFirstChild("TaskEvent")
			if taskEvent then
				taskEvent:FireClient(player, "Collapsed", { Duration = StatsConfig.CHAIN_REACTION.COLLAPSE_DURATION })
			end
		end
	end

	-- 入魔倾向: 功德-1/action
	if (data.Malice or 0) > StatsConfig.CHAIN_REACTION.CHAIN_DEMON_MALICE
		and (data.Risk or 10) > StatsConfig.CHAIN_REACTION.CHAIN_DEMON_RISK then
		data.GongDe = math.max(0, (data.GongDe or 0) - 1)
		DataManager:UpdateField(player, "GongDe", data.GongDe)
	end

	-- 毒戾入体: FirePoison>80 + Malice>60 -> 10% 毒发: Stamina-15, Spirit-10
	if (data.FirePoison or 0) > StatsConfig.CHAIN_REACTION.CHAIN_TOXIN_FIREPOISON
		and (data.Malice or 0) > StatsConfig.CHAIN_REACTION.CHAIN_TOXIN_MALICE
		and math.random() < 0.1 then
		data.Stamina = math.max(0, (data.Stamina or 0) - 15)
		data.Spirit = math.max(0, (data.Spirit or 0) - 10)
		DataManager:UpdateField(player, "Stamina", data.Stamina)
		DataManager:UpdateField(player, "Spirit", data.Spirit)
		local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
		if eventsFolder then
			local taskEvent = eventsFolder:FindFirstChild("TaskEvent")
			if taskEvent then
				taskEvent:FireClient(player, "PoisonBurst", {
					Message = "毒戾入体！体力-15，精神-10"
				})
			end
		end
	end

	-- 油尽灯枯: 强制传送回家
	if hasBurnout then
		local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
		if eventsFolder then
			local taskEvent = eventsFolder:FindFirstChild("TaskEvent")
			if taskEvent then
				taskEvent:FireClient(player, "ForceTeleportHome", {
					Message = "油尽灯枯！体力与精神耗尽，强制传送回家休养"
				})
			end
		end
	end

	-- 检测晋升条件
	
	getMeritService().CheckAutoPromotion(player)

	-- 红线检测
	self:CheckRedLines(player)

	-- 速度更新（如果有身法或状态变化）
	getSpeedCalculator().Apply(player)
end

-- 获取任务成本配置（含时辰效率修正）
-- taskName: "Deliver" / "Alchemy" / "Beast" / "Patrol" / "ExpelMonkey"
-- 返回 taskCosts 副本（已应用 taskEff 修正）或 nil
function StatusService:GetTaskCosts(taskName)
	local taskCosts = StatsConfig.TASK_COSTS[taskName]
	if not taskCosts then
		return nil
	end

	-- 返回一个副本，不修改原始配置
	local result = {}
	for k, v in pairs(taskCosts) do
		if type(v) == "table" then
			result[k] = {}
			for k2, v2 in pairs(v) do
				result[k][k2] = v2
			end
		else
			result[k] = v
		end
	end

	-- 应用时辰效率修正
	local timeMod = getTimeModifier()
	local taskEff = timeMod.TaskEff or 1.0

	if result.ActionCost then
		result.ActionCost = {}
		for field, val in pairs(taskCosts.ActionCost) do
			result.ActionCost[field] = math.max(1, math.floor(val * taskEff))
		end
	end

	if result.ApplyCost then
		result.ApplyCost = {}
		for field, val in pairs(taskCosts.ApplyCost) do
			if field == "Stamina" or field == "Spirit" then
				-- 负值（消耗）乘以 taskEff；正值（奖励）保持不变
				if val < 0 then
					result.ApplyCost[field] = math.floor(val * taskEff)
				else
					result.ApplyCost[field] = val
				end
			elseif field == "Fatigue" or field == "FirePoison" or field == "Malice" then
				-- 正值（负面效果增加）乘以 taskEff
				if val > 0 then
					result.ApplyCost[field] = math.ceil(val * taskEff)
				else
					result.ApplyCost[field] = val
				end
			else
				result.ApplyCost[field] = val
			end
		end
	end

	if result.CraftCost then
		result.CraftCost = {}
		for field, val in pairs(taskCosts.CraftCost) do
			if val < 0 then
				result.CraftCost[field] = math.floor(val * taskEff)
			else
				result.CraftCost[field] = val
			end
		end
	end

	if result.FailureCost then
		result.FailureCost = {}
		for field, val in pairs(taskCosts.FailureCost) do
			if field == "Fatigue" and val > 0 then
				result.FailureCost[field] = math.ceil(val * taskEff)
			elseif val < 0 then
				result.FailureCost[field] = math.floor(val * taskEff)
			else
				result.FailureCost[field] = val
			end
		end
	end

	return result
end

-- 增加经验（自动检测升级）
-- attrField: "Agility" / "AlchemyLv" / "Combat"
function StatusService:AddExp(player, attrField, amount)
	local data = DataManager:GetData(player)
	if not data or amount <= 0 then return end

	local expField = attrField == "Agility" and "AgilityExp"
		or attrField == "AlchemyLv" and "AlchemyExp"
		or attrField == "Combat" and "CombatExp"
		or nil
	if not expField then return end

	data[expField] = (data[expField] or 0) + amount
	local exp = data[expField]
	local level = data[attrField] or 1
	local expNeeded = StatsConfig.EXP_PER_LEVEL

	-- 检查是否升级
	if exp >= expNeeded then
		data[attrField] = level + 1
		data[expField] = exp - expNeeded  -- 溢出经验保留
		DataManager:UpdateField(player, attrField, data[attrField])

		local nameMap = { Agility = "身法", AlchemyLv = "火候", Combat = "仙力" }
		print("⬆ " .. player.Name .. " 的" .. (nameMap[attrField] or attrField)
			.. "升级至 Lv." .. data[attrField])

		-- 通知客户端升级
		local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
		if eventsFolder then
			local taskEvent = eventsFolder:FindFirstChild("TaskEvent")
			if taskEvent then
				taskEvent:FireClient(player, "LevelUp:" .. attrField, data[attrField])
			end
		end

		-- 触发等级提升回调（TaskService 注册，用于打开场景选择面板）
		if StatusService.OnLevelUp then
			task.spawn(function()
				StatusService.OnLevelUp(player, attrField, data[attrField])
			end)
		end

			-- 检测晋升条件
			
			getMeritService().CheckAutoPromotion(player)
	else
		-- 只更新经验（不更新 level），无需同步客户端
		-- 但需要存回 cache（已经 set 了）
	end
end

-- 红线检测（增强版：含链式反应）
function StatusService:CheckRedLines(player)
	local data = DataManager:GetData(player)
	if not data then return end
	local userId = player.UserId

	-- 火毒 > 60: 周期性扣 Stamina（DoT）
	local firePoison = data.FirePoison or 0
	if firePoison > StatsConfig.FIREPOISON_REDLINE then
		local lastTick = firePoisonTimers[userId] or 0
		local now = tick()
		if now - lastTick >= StatsConfig.FIREPOISON_DOT_INTERVAL then
			firePoisonTimers[userId] = now
			local newStamina = math.max(0, (data.Stamina or StatsConfig.MAX_STAMINA) - StatsConfig.FIREPOISON_DOT_DAMAGE)
			data.Stamina = newStamina
			DataManager:UpdateField(player, "Stamina", newStamina)
		end

		-- 链式反应：火毒 > 60 导致 Fatigue 缓慢增加
		local fatigueTimer = firePoisonTimers[userId .. "_fatigue"] or 0
		if firePoison > 60 and now - fatigueTimer >= StatsConfig.CHAIN_REACTION.FIREPOISON_FATIGUE_INTERVAL then
			firePoisonTimers[userId .. "_fatigue"] = now
			data.Fatigue = math.min(StatsConfig.MAX_FATIGUE, (data.Fatigue or 0) + StatsConfig.CHAIN_REACTION.FIREPOISON_FATIGUE_AMOUNT)
			DataManager:UpdateField(player, "Fatigue", data.Fatigue)
		end
	end

	-- 火毒 > 80: DoT 加速 + Spirit 侵蚀
	if firePoison > 80 then
		local now = tick()
		local severeTimer = firePoisonTimers[userId .. "_severe"] or 0
		if now - severeTimer >= StatsConfig.CHAIN_REACTION.FIREPOISON_SEVERE_DOT_INTERVAL then
			firePoisonTimers[userId .. "_severe"] = now
			local newStamina = math.max(0, (data.Stamina or StatsConfig.MAX_STAMINA) - StatsConfig.FIREPOISON_DOT_DAMAGE)
			data.Stamina = newStamina
			DataManager:UpdateField(player, "Stamina", newStamina)
		end

		-- Spirit 侵蚀
		local spiritTimer = firePoisonTimers[userId .. "_spirit"] or 0
		if now - spiritTimer >= StatsConfig.CHAIN_REACTION.FIREPOISON_SPIRIT_INTERVAL then
			firePoisonTimers[userId .. "_spirit"] = now
			data.Spirit = math.max(0, (data.Spirit or StatsConfig.MAX_SPIRIT) - StatsConfig.CHAIN_REACTION.FIREPOISON_SPIRIT_DAMAGE)
			DataManager:UpdateField(player, "Spirit", data.Spirit)
		end
	end

	-- 链式反应检测
	self:ChainReactionCheck(player, data)
end

-- 链式反应检测
function StatusService:ChainReactionCheck(player, data)
	local fatigue = data.Fatigue or 0
	local firePoison = data.FirePoison or 0
	local malice = data.Malice or 0
	local stamina = data.Stamina or 0
	local spirit = data.Spirit or 0
	local risk = data.Risk or 10
	local events = {}

	-- 1. 虚不受补: Fatigue>80 + FirePoison>60
	if fatigue > StatsConfig.CHAIN_REACTION.CHAIN_EXHAUSTION_FATIGUE
		and firePoison > StatsConfig.CHAIN_REACTION.CHAIN_EXHAUSTION_POISON then
		table.insert(events, "虚不受补")
	end

	-- 2. 入魔倾向: Malice>50 + Risk>60
	if malice > StatsConfig.CHAIN_REACTION.CHAIN_DEMON_MALICE
		and risk > StatsConfig.CHAIN_REACTION.CHAIN_DEMON_RISK then
		table.insert(events, "入魔倾向")
	end

	-- 3. 油尽灯枯: Stamina<20 + Spirit<20
	if stamina < StatsConfig.CHAIN_REACTION.CHAIN_BURNOUT_STAMINA
		and spirit < StatsConfig.CHAIN_REACTION.CHAIN_BURNOUT_SPIRIT then
		table.insert(events, "油尽灯枯")
	end

	-- 4. 毒戾入体: FirePoison>80 + Malice>60
	if firePoison > StatsConfig.CHAIN_REACTION.CHAIN_TOXIN_FIREPOISON
		and malice > StatsConfig.CHAIN_REACTION.CHAIN_TOXIN_MALICE then
		table.insert(events, "毒戾入体")
	end

	-- 5. 狂躁: Fatigue>80 + Malice>80
	if fatigue > StatsConfig.CHAIN_REACTION.CHAIN_RAGE_FATIGUE
		and malice > StatsConfig.CHAIN_REACTION.CHAIN_RAGE_MALICE then
		table.insert(events, "狂躁")
	end

	-- 通知客户端（通过 Attribute 传递）
	if #events > 0 then
		player:SetAttribute("ChainEvents", table.concat(events, ","))
	else
		player:SetAttribute("ChainEvents", "")
	end
end

-- ============================================================
-- 定时恢复循环（每 5 秒恢复 Stamina/Spirit）
-- ============================================================
task.spawn(function()
	while true do
		task.wait(StatsConfig.REGEN_INTERVAL)

		for _, player in ipairs(Players:GetPlayers()) do
			local data = DataManager:GetData(player)
			if not data then continue end

			-- 获取时辰恢复修正
			local timeMod = getTimeModifier()
			local restEff = timeMod.RestEff or 1.0

			-- 虚不受补: Fatigue>80 + FirePoison>60 时完全停止恢复
			local hasXuBuShou = (data.Fatigue or 0) > StatsConfig.CHAIN_REACTION.CHAIN_EXHAUSTION_FATIGUE
				and (data.FirePoison or 0) > StatsConfig.CHAIN_REACTION.CHAIN_EXHAUSTION_POISON
			if hasXuBuShou then
				-- 跳过所有恢复，只做红线检测
				StatusService:CheckRedLines(player)
				continue
			end

			-- Stamina 恢复（疲劳 > 80 时减半 × 时辰恢复修正）
			local staminaRegen = StatsConfig.STAMINA_REGEN_PER_TICK * restEff
			if (data.Fatigue or 0) > StatsConfig.FATIGUE_REDLINE then
				staminaRegen = staminaRegen * StatsConfig.FATIGUE_REGEN_REDUCTION
			end
			if staminaRegen > 0 and data.Stamina < StatsConfig.MAX_STAMINA then
				local newStamina = math.min(StatsConfig.MAX_STAMINA, (data.Stamina or 0) + staminaRegen)
				data.Stamina = newStamina
				DataManager:UpdateField(player, "Stamina", newStamina)
			end

			-- Spirit 恢复（× 时辰恢复修正）
			local spiritRegen = StatsConfig.SPIRIT_REGEN_PER_TICK * restEff
			if spiritRegen > 0 and data.Spirit < StatsConfig.MAX_SPIRIT then
				local newSpirit = math.min(StatsConfig.MAX_SPIRIT, (data.Spirit or 0) + spiritRegen)
				data.Spirit = newSpirit
				DataManager:UpdateField(player, "Spirit", newSpirit)
			end

			-- 火毒 DoT 检查
			StatusService:CheckRedLines(player)
		end
	end
end)

-- ============================================================
-- 玩家离开时清理 timer
-- ============================================================
Players.PlayerRemoving:Connect(function(player)
	firePoisonTimers[player.UserId] = nil
end)

print("✅ StatusService 已启动")

-- ============================================================
-- Risk 自然衰减循环
-- ============================================================
task.spawn(function()
	while true do
		task.wait(RiskConfig.Decay.RealDecayInterval)  -- 120 seconds

		for _, player in ipairs(Players:GetPlayers()) do
			local data = DataManager:GetData(player)
			if not data then continue end

			local currentRisk = data.Risk or RiskConfig.InitialRisk
			if currentRisk <= RiskConfig.Decay.MinRisk then continue end

			local gongDe = data.GongDe or 0
			local boost = math.floor(gongDe / 20) * RiskConfig.Decay.GongDeBoostPer20
			local decayAmount = RiskConfig.Decay.BaseDecayPerTick + boost

			local newRisk = math.max(RiskConfig.Decay.MinRisk, currentRisk - decayAmount)
			data.Risk = newRisk
			DataManager:UpdateField(player, "Risk", newRisk)
		end
	end
end)

return StatusService
