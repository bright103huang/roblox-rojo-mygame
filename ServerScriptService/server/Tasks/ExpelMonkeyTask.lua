-- ============================================================
-- 文件：ServerScriptService.Server.Tasks.ExpelMonkeyTask.lua
-- 功能：驱猴任务处理器 — 蟠桃园中随机出现捣乱的猴子，
--       玩家触摸即可驱赶，获得功勋奖励
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
local MONKEY_DURATION = 30         -- 猴子存活时间（秒）
local MONKEY_RADIUS = 15           -- 猴子生成范围半径
local REWARD_XIANJING = 3
local REWARD_MERIT = 1

-- ============================================================
-- 猴子数据存储
-- ============================================================
-- activeMonkeys[monkeyId] = { Part, OwnerId, ExpireTime }
local activeMonkeys = {}
local nextMonkeyId = 1

-- ============================================================
-- 辅助：生成猴妖 Part
-- ============================================================
local function spawnMonkeyPart(spawnPosition, ownerId)
	local monkeyId = nextMonkeyId
	nextMonkeyId += 1

	-- 创建猴妖 Part
	local monkeyPart = Instance.new("Part")
	monkeyPart.Name = "Monkey"
	monkeyPart.Anchored = true
	monkeyPart.CanCollide = false
	monkeyPart.CanQuery = false
	monkeyPart.Transparency = 0
	monkeyPart.BrickColor = BrickColor.new("Brown")
	monkeyPart.Material = Enum.Material.SmoothPlastic
	monkeyPart.Size = Vector3.new(3, 3, 3)
	monkeyPart.Shape = Enum.PartType.Ball
	monkeyPart.Position = spawnPosition
	monkeyPart.Parent = workspace

	-- 设置属性
	monkeyPart:SetAttribute("MonkeyId", monkeyId)
	monkeyPart:SetAttribute("OwnerId", ownerId)

	-- 添加 Billboard 指示文字
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MonkeyLabel"
	billboard.Parent = monkeyPart
	billboard.Adornee = monkeyPart
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 1000

	local textLabel = Instance.new("TextLabel")
	textLabel.Parent = billboard
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = " 捣乱猴妖！"
	textLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	textLabel.TextStrokeTransparency = 0
	textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.TextSize = 24

	-- 记录到活跃列表
	local expireTime = tick() + MONKEY_DURATION
	activeMonkeys[monkeyId] = {
		Part = monkeyPart,
		OwnerId = ownerId,
		ExpireTime = expireTime,
	}

	-- 设定自动消失
	task.delay(MONKEY_DURATION, function()
		local monkeyData = activeMonkeys[monkeyId]
		if monkeyData and monkeyData.Part then
			monkeyData.Part:Destroy()
			activeMonkeys[monkeyId] = nil
			print(" 　猴妖 (ID:" .. monkeyId .. ") 已自动消失")
		end
	end)

	return monkeyPart, monkeyId
end

-- ============================================================
-- 辅助：获取玩家附近的 MonkeySpawn 位置
-- ============================================================
local function findMonkeySpawn(player)
	local char = player.Character
	if not char then return nil end

	local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
	if not hrp then return nil end

	local playerPos = hrp.Position

	-- 在玩家附近找一个可生成位置
	local spawnOffset = Vector3.new(
		(math.random() - 0.5) * MONKEY_RADIUS * 2,
		1,
		(math.random() - 0.5) * MONKEY_RADIUS * 2
	)
	local spawnPos = playerPos + spawnOffset

	-- 确保不生成在太远或太近的位置
	if (spawnPos - playerPos).Magnitude < 3 then
		spawnPos = playerPos + Vector3.new(MONKEY_RADIUS * 0.5, 1, 0)
	end

	return spawnPos
end

-- ============================================================
-- 处理器接口（被 TaskService 调用）
-- ============================================================

local ExpelMonkeyTask = {}

-- 玩家触摸 MonkeySpawn：触发猴妖生成
function ExpelMonkeyTask.OnPlayerPickup(player, _area)
	local userId = player.UserId
	local data = DataManager:GetData(player)
	if not data then return false end

	-- 体力检查
	local canPerform, reason = StatusService:CanPerformTask(player, { Stamina = 8 })
	if not canPerform then
		print("  " .. player.Name .. " 驱猴失败：" .. tostring(reason))
		return false
	end

	-- 检查玩家是否已有活跃的猴子（防止刷取）
	for monkeyId, monkeyData in pairs(activeMonkeys) do
		if monkeyData.OwnerId == userId then
			print("  " .. player.Name .. " 已有活跃猴妖")
			return false
		end
	end

	-- 计算生成位置
	local spawnPos = findMonkeySpawn(player)
	if not spawnPos then
		return false
	end

	-- 生成猴妖
	local monkeyPart, monkeyId = spawnMonkeyPart(spawnPos, userId)
	print("  " .. player.Name .. " 引来了猴妖 (ID:" .. monkeyId .. ")")

	return true
end

-- 玩家触摸猴妖 Part：驱赶
function ExpelMonkeyTask.OnPlayerDrop(player, area)
	if not area then
		return false, "NoArea"
	end

	-- 检查触摸的 Part 是否为猴妖
	if area.Name ~= "Monkey" then
		return false, "NotMonkey"
	end

	local monkeyId = area:GetAttribute("MonkeyId")
	if not monkeyId then
		return false, "InvalidMonkey"
	end

	-- 查找猴妖数据
	local monkeyData = activeMonkeys[monkeyId]
	if not monkeyData then
		return false, "AlreadyExpelled"
	end

	-- 允许任何人驱赶任何猴妖（同僚协作）
	-- 但不允许驱赶已过期的猴妖
	if tick() >= monkeyData.ExpireTime then
		-- 已过期，直接清除
		if monkeyData.Part then
			monkeyData.Part:Destroy()
		end
		activeMonkeys[monkeyId] = nil
		return false, "Expired"
	end

	-- 驱赶成功：销毁猴妖 Part
	if monkeyData.Part then
		monkeyData.Part:Destroy()
	end
	activeMonkeys[monkeyId] = nil

	-- 扣除体力
	StatusService:ApplyCosts(player, {
		Stamina = -8,
	})

	-- 发放功勋
	MeritService.AddMerit(player, REWARD_MERIT)

	-- 发放仙晶
	local data = DataManager:GetData(player)
	if data then
		data.XianJing = (data.XianJing or 0) + REWARD_XIANJING
		DataManager:UpdateField(player, "XianJing", data.XianJing)
	end

	-- 更新驱猴次数
	if data then
		data.ExpelCount = (data.ExpelCount or 0) + 1
		DataManager:UpdateField(player, "ExpelCount", data.ExpelCount)
	end

	print("  " .. player.Name .. " 驱赶了猴妖！获得功勋+"
		.. REWARD_MERIT .. "，仙晶+" .. REWARD_XIANJING)

	return true, "Expelled"
end

-- 玩家离开时清理相关的猴妖
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	for monkeyId, monkeyData in pairs(activeMonkeys) do
		if monkeyData.OwnerId == userId then
			if monkeyData.Part then
				monkeyData.Part:Destroy()
			end
			activeMonkeys[monkeyId] = nil
		end
	end
end)

return ExpelMonkeyTask
