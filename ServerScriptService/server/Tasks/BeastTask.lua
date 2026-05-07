-- ============================================================
-- 文件：ServerScriptService.Server.Tasks.BeastTask.lua
-- 功能：妖兽战场任务处理器
-- 架构：Task Handler 模式，被 TaskService 调度器调用
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(script.Parent.Parent.Systems.DataManager)
local StatusService = require(script.Parent.Parent.Systems.StatusService)
local BeastNPC = require(script.Parent.Parent.Systems.BeastNPC)

-- ============================================================
-- 防重复生成
-- ============================================================
local pendingSpawn = {}  -- [userId] = true（1 秒冷却）

-- ============================================================
-- BeastTask（处理器接口）
-- ============================================================

local BeastTask = {}

-- 玩家触摸 BeastSpawn：生成妖兽
function BeastTask.OnPlayerPickup(player, area)
	if pendingSpawn[player.UserId] then
		return false  -- 冷却中
	end

	-- 检查是否已有妖兽
	local existing = BeastNPC.GetPlayerBeast(player)
	if existing then
		print("❌ " .. player.Name .. " 已有活跃妖兽")
		return false
	end

	-- 体力检查（从 StatsConfig 读取）
	local taskCosts = StatusService:GetTaskCosts("Beast")
	local actionCost = taskCosts and taskCosts.ActionCost
	if actionCost then
		local canPerform, reason = StatusService:CanPerformTask(player, actionCost)
		if not canPerform then
			print("❌ " .. player.Name .. " 狩猎失败：" .. tostring(reason))
			return false
		end
	end

	-- 根据 Combat 等级决定妖兽 tier
	local data = DataManager:GetData(player)
	local combat = data and data.Combat or 1
	local tier = "Normal"
	if combat >= 10 then tier = "Boss"
	elseif combat >= 5 then tier = "Elite" end

	pendingSpawn[player.UserId] = true
	task.delay(1, function()
		pendingSpawn[player.UserId] = nil
	end)

	BeastNPC.SpawnBeast(player, area, tier)

	-- 标记客户端 carrying（用于区分触摸 BeastSpawn vs BeastHitbox）
	return true
end

-- 不使用 Drop（攻击通过 OnAttack）
function BeastTask.OnPlayerDrop(player, _area)
	return false, "NotSupported"
end

-- 玩家攻击妖兽（触摸 BeastHitbox）
function BeastTask.OnAttack(player, contextData)
	-- contextData = { BeastId = number }
	local beastId = contextData and contextData.BeastId
	if not beastId then
		-- 尝试通过 Part 查找
		local hitPart = contextData and contextData.Part
		if hitPart then
			local beast = BeastNPC.GetBeastByPart(hitPart)
			if not beast then return false, "NoBeast" end
			beastId = beast.Id
		else
			return false, "NoBeast"
		end
	end

	local ok, result = BeastNPC.PlayerAttackBeast(beastId, player)
	if not ok then
		return false, result
	end

	if result.Killed then
		-- 击杀奖励：状态消耗 + 收益（从 StatsConfig 读取）
		local taskCosts = StatusService:GetTaskCosts("Beast")
		if taskCosts and taskCosts.ApplyCost then
			StatusService:ApplyCosts(player, taskCosts.ApplyCost)
		else
			StatusService:ApplyCosts(player, {
				Stamina = -25,
				Malice = 10,
				CombatExp = 10,
				XianJing = 25,
			})
		end
		print("⚔ " .. player.Name .. " 击杀了妖兽！")
	end

	return true, result
end

return BeastTask
