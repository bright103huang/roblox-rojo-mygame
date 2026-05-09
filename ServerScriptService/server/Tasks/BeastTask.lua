-- ============================================================
-- 文件：ServerScriptService.Server.Tasks.BeastTask.lua
-- 功能：妖兽角斗场任务处理器
-- 架构：Processor — 仅处理召唤，战斗由 BeastNPC 内部管理
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
-- BeastTask
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

	-- 体力检查
	local taskCosts = StatusService:GetTaskCosts("Beast")
	local actionCost = taskCosts and taskCosts.ActionCost
	if actionCost then
		local canPerform, reason = StatusService:CanPerformTask(player, actionCost)
		if not canPerform then
			print("❌ " .. player.Name .. " 挑战角斗场失败：" .. tostring(reason))
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

	-- 找到场景中的 BeastSpawn Part
	local spawnPart = nil
	if type(area) == "table" and area.PartName then
		spawnPart = workspace:FindFirstChild(area.PartName, true)
	end
	if not spawnPart then
		spawnPart = area
	end

	BeastNPC.SpawnBeast(player, spawnPart, tier)
	return true
end

function BeastTask.OnPlayerDrop(player, _area)
	return false, "NotSupported"
end

-- 战斗由 BeastNPC 内部自动管理，无需外部调用
function BeastTask.OnAttack(player, contextData)
	return false, "NoManualAttack"
end

return BeastTask
