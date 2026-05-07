-- ============================================================
-- 文件：ServerScriptService.Server.Tasks.DeliverTask.lua
-- 功能：传菜任务处理器 — 目标分配、端盘、放盘、奖励+速度成长
-- 架构：Task Handler 模式，被 TaskService 调度器调用
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.Parent.Systems.DataManager)
local StatusService = require(script.Parent.Parent.Systems.StatusService)
local Config = require(ReplicatedStorage.Shared.Config)

-- ============================================================
-- 状态
-- ============================================================
local carrying = {}   -- { [userId] = true }
local tables = {}    -- 所有 TableArea
local currentTarget = nil
local currentBillboard = nil

-- 收集所有 TableArea（一次性扫描）
local function refreshTables()
	local newTables = {}
	for _, v in pairs(workspace:GetDescendants()) do
		if v.Name == "TableArea" then
			table.insert(newTables, v)
		end
	end
	tables = newTables
	print("🍽️ 扫描到 " .. #tables .. " 个 TableArea")
end
refreshTables()

-- ============================================================
-- 指示器管理（必须在 assignOrder 之前定义）
-- ============================================================
local function clearAllIndicators()
	for _, tableArea in ipairs(tables) do
		local existing = tableArea:FindFirstChild("TargetIndicator")
		if existing then
			existing:Destroy()
		end
	end
	currentBillboard = nil
end

local function createIndicator(targetTableArea)
	clearAllIndicators()

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TargetIndicator"
	billboard.Parent = targetTableArea
	billboard.Adornee = targetTableArea
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 1000

	local textLabel = Instance.new("TextLabel")
	textLabel.Parent = billboard
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "⭐ 目标 ⭐"
	textLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	textLabel.TextStrokeTransparency = 0
	textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.TextSize = 24

	currentBillboard = billboard
	print("🔔 指示器已添加到桌子 ID:", targetTableArea:GetAttribute("TableId"))
end

-- ============================================================
-- 目标分配
-- ============================================================
local function assignOrder()
	if #tables == 0 then return end
	currentTarget = tables[math.random(1, #tables)]
	createIndicator(currentTarget)
	print("🎯 当前目标桌子ID：", currentTarget:GetAttribute("TableId"))
end

-- workspace 新物体加入时补扫（SceneSetup 延迟创建，确保能捕获）
workspace.DescendantAdded:Connect(function(desc)
	if desc.Name == "TableArea" then
		table.insert(tables, desc)
		-- 如果还没有活跃订单，分配首个目标
		if not currentTarget then
			assignOrder()
		end
	end
end)

-- 启动时分配首个目标（如果已有桌子）
assignOrder()

-- ============================================================
-- 创建盘子 Part
-- ============================================================
local function makePlatePart()
	local part = Instance.new("Part")
	part.Size = Vector3.new(1.2, 0.2, 1.2)
	part.BrickColor = BrickColor.new("White")
	part.Material = Enum.Material.SmoothPlastic
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- ============================================================
-- 创建桃子 Part
-- ============================================================
local function makePeachPart()
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.6, 0.6, 0.6)
	part.BrickColor = BrickColor.new("Bright orange")
	part.Material = Enum.Material.SmoothPlastic
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- ============================================================
-- 在桌子上生成盘子和桃子
-- ============================================================
local function spawnPlateOnTable(tableArea)
	local plateBase = makePlatePart()
	plateBase.Name = "ServedPlateBase"
	plateBase.Parent = workspace

	local tablePos = tableArea.Position
	local basePos = tablePos + Vector3.new(0, 0.8, 0)
	local randomOffset = Vector3.new(
		(math.random() - 0.5) * 2, 0, (math.random() - 0.5) * 2
	)
	local platePos = basePos + randomOffset
	plateBase.Position = platePos

	-- 单独生成桃子
	local peach = makePeachPart()
	peach.Name = "ServedPeach"
	peach.Parent = workspace

	local peachOffset = Vector3.new(
		(math.random() - 0.5) * 0.8, 1.2, (math.random() - 0.5) * 0.8
	)
	peach.Position = platePos + peachOffset
	print("🍑 桃子已生成在位置:", peach.Position)
end

-- ============================================================
-- 处理器接口（被 TaskService 调用）
-- ============================================================

local DeliverTask = {}

function DeliverTask.GetConfig()
	return Config.Task.Tasks.Deliver
end

-- 玩家拿起菜品
function DeliverTask.OnPlayerPickup(player, _area)
	if carrying[player.UserId] then
		return false -- 正在端着
	end
	if not currentTarget then
		return false -- 没有活跃订单
	end

	-- 体力检查（从 StatsConfig 读取成本）
	local taskCosts = StatusService:GetTaskCosts("Deliver")
	local actionCost = taskCosts and taskCosts.ActionCost
	if actionCost then
		local canPerform, reason = StatusService:CanPerformTask(player, actionCost)
		if not canPerform then
			print("❌ " .. player.Name .. " 传菜失败：" .. tostring(reason))
			return false
		end
	end

	carrying[player.UserId] = true

	local char = player.Character
	if not char then return false end

	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	if not hand then return false end

	-- 创建盘子（不再依赖 ReplicatedStorage 模板）
	local plateBase = makePlatePart()
	plateBase.Anchored = false
	plateBase.Name = "Dish"
	plateBase.Parent = char
	plateBase.CFrame = hand.CFrame * CFrame.new(0, -0.3, -1)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = plateBase
	weld.Parent = plateBase

	-- 创建桃子
	local peach = makePeachPart()
	peach.Anchored = false
	peach.Name = "HandPeach"
	peach.Parent = char

	local peachWeld = Instance.new("WeldConstraint")
	peachWeld.Part0 = plateBase
	peachWeld.Part1 = peach
	peachWeld.Parent = peach
	peach.Position = plateBase.Position + Vector3.new(0, 1.2, 0)

	return true
end

-- 玩家放下菜品
function DeliverTask.OnPlayerDrop(player, area)
	if not carrying[player.UserId] then
		return false, "NotCarrying"
	end
	if not currentTarget then
		return false, "NoTarget"
	end

	local tableId = area:GetAttribute("TableId")
	local targetId = currentTarget:GetAttribute("TableId")
	if tableId ~= targetId then
		return false, "WrongTable"
	end

	carrying[player.UserId] = nil

	-- 删除手持的盘子和桃子
	local char = player.Character
	if char then
		local dish = char:FindFirstChild("Dish")
		if dish then dish:Destroy() end
		local handPeach = char:FindFirstChild("HandPeach")
		if handPeach then handPeach:Destroy() end
	end

	spawnPlateOnTable(currentTarget)

	-- 应用状态消耗与收益（从 StatsConfig 读取）
	local taskCosts = StatusService:GetTaskCosts("Deliver")
	if taskCosts and taskCosts.ApplyCost then
		StatusService:ApplyCosts(player, taskCosts.ApplyCost)
	end

	print("✅ 传菜完成，状态已更新")

	-- 分配下一单
	assignOrder()

	return true, "Success"
end

-- 获取当前目标（用于客户端校验或其他用途）
function DeliverTask.GetTarget()
	return currentTarget
end

return DeliverTask
