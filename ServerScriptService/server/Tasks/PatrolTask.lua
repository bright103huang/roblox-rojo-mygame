-- ============================================================
-- 文件：ServerScriptService.Server.Tasks.PatrolTask.lua
-- 功能：蟠桃园巡逻任务处理器 — 玩家按顺序触摸巡逻点，
--       完成全部点位后获得功勋和仙晶奖励
-- 架构：Task Handler 模式，被 TaskService 调度器调用
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.Parent.Systems.DataManager)
local StatusService = require(script.Parent.Parent.Systems.StatusService)
local MeritService = require(script.Parent.Parent.Systems.MeritService)

-- ============================================================
-- 配置
-- ============================================================
-- 巡逻点位 ID（按顺序）
local PATROL_POINT_IDS = {"A", "B", "C"}
local REWARD_XIANJING = 5
local REWARD_MERIT = 1

-- ============================================================
-- 状态
-- ============================================================
-- playerProgress[userId] = { currentIndex = 0, pointsTouched = {} }
local playerProgress = {}

-- ============================================================
-- 辅助：获取巡逻点 Part（提供缓存）
-- ============================================================
local patrolPointCache = {}  -- 按 PointId 缓存 Part 引用

local function refreshPatrolPoints()
	local newCache = {}
	for _, v in ipairs(workspace:GetDescendants()) do
		if v.Name == "PatrolPoint" then
			local pointId = v:GetAttribute("PointId")
			if pointId then
				newCache[pointId] = v
			end
		end
	end
	patrolPointCache = newCache
end

refreshPatrolPoints()

-- workspace 变化时补扫
workspace.DescendantAdded:Connect(function(desc)
	if desc.Name == "PatrolPoint" and desc:GetAttribute("PointId") then
		patrolPointCache[desc:GetAttribute("PointId")] = desc
	end
end)

workspace.DescendantRemoving:Connect(function(desc)
	if desc.Name == "PatrolPoint" then
		local pointId = desc:GetAttribute("PointId")
		if pointId then
			patrolPointCache[pointId] = nil
		end
	end
end)

-- ============================================================
-- 辅助：清除玩家所有巡逻指示器
-- ============================================================
local function clearPlayerIndicators(userId)
	for _, pointId in ipairs(PATROL_POINT_IDS) do
		local pointPart = patrolPointCache[pointId]
		if pointPart then
			local indicator = pointPart:FindFirstChild("PatrolIndicator")
			if indicator then
				indicator:Destroy()
			end
		end
	end
end

-- ============================================================
-- 辅助：在目标巡逻点上创建指示器
-- ============================================================
local function createIndicator(pointId)
	local pointPart = patrolPointCache[pointId]
	if not pointPart then return end

	-- 清除旧指示器
	local existing = pointPart:FindFirstChild("PatrolIndicator")
	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PatrolIndicator"
	billboard.Parent = pointPart
	billboard.Adornee = pointPart
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 1000

	local textLabel = Instance.new("TextLabel")
	textLabel.Parent = billboard
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = " 前往巡逻 " .. pointId
	textLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
	textLabel.TextStrokeTransparency = 0
	textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.TextSize = 24
end

-- ============================================================
-- 处理器接口（被 TaskService 调用）
-- ============================================================

local PatrolTask = {}

-- 玩家触摸 PatrolStart：开始巡逻
function PatrolTask.OnPlayerPickup(player, _area)
	local userId = player.UserId
	local data = DataManager:GetData(player)
	if not data then return false end

	-- 检查是否已在巡逻中
	if playerProgress[userId] then
		print("  " .. player.Name .. " 已在巡逻中")
		return false
	end

	-- 体力检查
	local canPerform, reason = StatusService:CanPerformTask(player, { Stamina = 10 })
	if not canPerform then
		print("  " .. player.Name .. " 巡逻失败：" .. tostring(reason))
		return false
	end

	-- 初始化巡逻进度
	playerProgress[userId] = {
		currentIndex = 0,
		pointsTouched = {},
	}

	-- 指示第一个巡逻点
	if #PATROL_POINT_IDS > 0 then
		createIndicator(PATROL_POINT_IDS[1])
	end

	print("  " .. player.Name .. " 开始巡逻")
	return true
end

-- 玩家触摸巡逻点：更新进度
function PatrolTask.OnPlayerDrop(player, area)
	if not area then
		return false, "NoArea"
	end

	local userId = player.UserId
	local progress = playerProgress[userId]
	if not progress then
		return false, "NotPatrolling"
	end

	-- 检查是否为有效的巡逻点
	if area.Name ~= "PatrolPoint" then
		return false, "WrongPoint"
	end

	local pointId = area:GetAttribute("PointId")
	if not pointId then
		return false, "InvalidPoint"
	end

	-- 查找当前应到达的点位索引
	local expectedIndex = progress.currentIndex + 1
	if expectedIndex > #PATROL_POINT_IDS then
		return false, "AlreadyComplete"
	end

	local expectedPointId = PATROL_POINT_IDS[expectedIndex]

	-- 检查是否已触摸过该点
	if progress.pointsTouched[pointId] then
		return false, "AlreadyTouched"
	end

	-- 检查顺序：必须按 A → B → C 的顺序触摸
	if pointId ~= expectedPointId then
		print("  " .. player.Name .. " 触摸了错误的点位（需要 "
			.. expectedPointId .. "，实际 " .. pointId .. "）")
		return false, "WrongOrder"
	end

	-- 记录已触摸的点位
	progress.pointsTouched[pointId] = true
	progress.currentIndex = expectedIndex

	-- 清除当前点位指示器
	clearPlayerIndicators(userId)

	print("  " .. player.Name .. " 到达巡逻点 " .. pointId
		.. "（" .. expectedIndex .. "/" .. #PATROL_POINT_IDS .. "）")

	-- 检查是否完成全部巡逻
	if progress.currentIndex >= #PATROL_POINT_IDS then
		-- 全部完成，发放奖励
		playerProgress[userId] = nil

		-- 扣除体力
		StatusService:ApplyCosts(player, {
			Stamina = -10,
		})

		-- 发放功勋
		MeritService.AddMerit(player, REWARD_MERIT)

		-- 发放仙晶
		local data = DataManager:GetData(player)
		if data then
			data.XianJing = (data.XianJing or 0) + REWARD_XIANJING
			DataManager:UpdateField(player, "XianJing", data.XianJing)
		end

		-- 更新巡逻次数
		if data then
			data.PatrolCount = (data.PatrolCount or 0) + 1
			DataManager:UpdateField(player, "PatrolCount", data.PatrolCount)
		end

		print("  " .. player.Name .. " 完成巡逻！获得功勋+"
			.. REWARD_MERIT .. "，仙晶+" .. REWARD_XIANJING)

		return true, "PatrolComplete"
	else
		-- 指示下一个巡逻点
		local nextPointId = PATROL_POINT_IDS[progress.currentIndex + 1]
		if nextPointId then
			createIndicator(nextPointId)
		end

		return true, "PointReached"
	end
end

-- 掉落或角色死亡时清理进度
Players.PlayerRemoving:Connect(function(player)
	clearPlayerIndicators(player.UserId)
	playerProgress[player.UserId] = nil
end)

return PatrolTask
