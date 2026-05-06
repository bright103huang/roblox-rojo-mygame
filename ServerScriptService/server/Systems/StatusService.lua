-- ============================================================
-- 文件：ServerScriptService.Server.Systems.StatusService.lua
-- 功能：状态管理系统 — 恢复、验证、扣除、升级、红线检测
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)
local Config = require(ReplicatedStorage.Shared.Config)

local StatsConfig = Config.Stats

-- ============================================================
-- 本地引用
-- ============================================================
local SpeedCalculator = nil  -- 延迟加载，避免循环依赖

local function getSpeedCalculator()
	if not SpeedCalculator then
		SpeedCalculator = require(script.Parent.SpeedCalculator)
	end
	return SpeedCalculator
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

	for field, delta in pairs(costsTable) do
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

	-- 红线检测
	self:CheckRedLines(player)

	-- 速度更新（如果有身法或状态变化）
	getSpeedCalculator().Apply(player)
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
	else
		-- 只更新经验（不更新 level），无需同步客户端
		-- 但需要存回 cache（已经 set 了）
	end
end

-- 红线检测
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
			print("🔥 火毒发作，" .. player.Name .. " Stamina -" .. StatsConfig.FIREPOISON_DOT_DAMAGE)
		end
	end

	-- 戾气 > 50: 提示（具体限制在任务中执行）
	-- 疲劳红线由 SpeedCalculator 处理（速度计算时自动应用）
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

			-- Stamina 恢复（疲劳 > 80 时减半）
			local staminaRegen = StatsConfig.STAMINA_REGEN_PER_TICK
			if (data.Fatigue or 0) > StatsConfig.FATIGUE_REDLINE then
				staminaRegen = staminaRegen * StatsConfig.FATIGUE_REGEN_REDUCTION
			end
			if staminaRegen > 0 and data.Stamina < StatsConfig.MAX_STAMINA then
				local newStamina = math.min(StatsConfig.MAX_STAMINA, (data.Stamina or 0) + staminaRegen)
				data.Stamina = newStamina
				DataManager:UpdateField(player, "Stamina", newStamina)
			end

			-- Spirit 恢复
			local spiritRegen = StatsConfig.SPIRIT_REGEN_PER_TICK
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

return StatusService
