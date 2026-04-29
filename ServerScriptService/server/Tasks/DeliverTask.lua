-- ============================================================
-- 文件：ServerScriptService.Server.Tasks.DeliverTask.lua
-- 功能：传菜任务处理器 — 目标分配、端盘、放盘、奖励+速度成长
-- 架构：Task Handler 模式，被 TaskService 调度器调用
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.Parent.Systems.DataManager)
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

-- workspace 新物体加入时补扫
workspace.DescendantAdded:Connect(function(desc)
	if desc.Name == "TableArea" then
		table.insert(tables, desc)
	end
end)

-- ============================================================
-- 指示器管理
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

-- 启动时分配首个目标
assignOrder()

-- ============================================================
-- 在桌子上生成盘子和桃子
-- ============================================================
local function spawnPlateOnTable(tableArea)
	local plateTemplate = ReplicatedStorage:FindFirstChild("Plate")
	if not plateTemplate then
		warn("❌ 找不到 Plate 模板")
		return
	end

	local newPlate = plateTemplate:Clone()
	newPlate.Name = "ServedPlate"
	newPlate.Parent = workspace

	local plateBase = newPlate:FindFirstChild("PlateBase")
		or newPlate:FindFirstChild("Plate")
		or newPlate:FindFirstChild("PlatePart")
	if plateBase then
		newPlate.PrimaryPart = plateBase
		plateBase.Anchored = true
	end

	local tablePos = tableArea.Position
	local basePos = tablePos + Vector3.new(0, 0.8, 0)
	local randomOffset = Vector3.new(
		(math.random() - 0.5) * 2, 0, (math.random() - 0.5) * 2
	)
	local platePos = basePos + randomOffset
	local plateRot = CFrame.Angles(0, math.rad(math.random(0, 360)), 0)

	if plateBase then
		newPlate:SetPrimaryPartCFrame(CFrame.new(platePos) * plateRot)
	end

	-- 单独生成桃子
	local peachTemplate = plateTemplate:FindFirstChild("Peach", true)
	if peachTemplate then
		local peach = peachTemplate:Clone()
		peach.Name = "ServedPeach"
		peach.Parent = workspace
		peach.Anchored = true
		peach.CanCollide = false
		peach.Transparency = 0
		peach.BrickColor = BrickColor.new("Bright orange")
		peach.Material = Enum.Material.SmoothPlastic

		local peachOffset = Vector3.new(
			(math.random() - 0.5) * 0.8, 1.2, (math.random() - 0.5) * 0.8
		)
		peach.Position = platePos + peachOffset
		local peachRot = CFrame.Angles(0, plateRot:ToEulerAnglesYXZ(), 0)
		peach.CFrame = CFrame.new(peach.Position) * peachRot
		print("🍑 桃子已独立生成在位置:", peach.Position)
	else
		warn("❌ 未找到桃子模板，请检查 Plate 模型内是否有名为 Peach 的部件")
	end
end

-- ============================================================
-- 速度成长逻辑
-- ============================================================
local function checkSpeedGrowth(player)
	local taskCfg = Config.Task.Tasks.Deliver
	if not taskCfg or not taskCfg.SpeedGrowth or not taskCfg.SpeedGrowth.Enabled then
		return
	end

	local growth = taskCfg.SpeedGrowth
	local data = DataManager:GetData(player)
	if not data then return end

	local currentCount = data.DeliverCount or 0
	local currentBonus = data.SpeedBonus or 0
	local newCount = currentCount + 1

	DataManager:UpdateField(player, "DeliverCount", newCount)

	-- 检查是否达到升级门槛
	local expectedBonus = math.min(
		math.floor(newCount / growth.DeliveriesPerLevel) * growth.SpeedPerLevel,
		growth.MaxBonusSpeed
	)

	if expectedBonus > currentBonus then
		DataManager:UpdateField(player, "SpeedBonus", expectedBonus)
		DataManager:ApplySpeed(player)
		print("⚡ " .. player.Name .. " 速度升级！+"
			.. (expectedBonus - currentBonus) .. "（当前总加成 " .. expectedBonus .. "）")

		-- 通知客户端显示升级信息
		local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
		if eventsFolder then
			local taskEvent = eventsFolder:FindFirstChild("TaskEvent")
			if taskEvent then
				taskEvent:FireClient(player, "SpeedUp", expectedBonus)
			end
		end
	end
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

	carrying[player.UserId] = true

	local char = player.Character
	if not char then return false end

	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	if not hand then return false end

	local plateTemplate = ReplicatedStorage:FindFirstChild("Plate")
	if not plateTemplate then
		carrying[player.UserId] = nil
		return false
	end

	-- 克隆盘子
	local plate = plateTemplate:Clone()
	plate.Name = "Plate"
	plate.Parent = char
	plate.PrimaryPart = plate:FindFirstChild("PlateBase")
	if plate.PrimaryPart then
		plate:SetPrimaryPartCFrame(hand.CFrame * CFrame.new(0, -0.3, -1))

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = plate.PrimaryPart
		weld.Parent = plate.PrimaryPart

		-- 单独克隆桃子
		local peachTemplate = plateTemplate:FindFirstChild("Peach", true)
		if peachTemplate then
			local peach = peachTemplate:Clone()
			peach.Name = "HandPeach"
			peach.Parent = char
			peach.Anchored = false
			peach.CanCollide = false
			peach.Transparency = 0
			peach.BrickColor = BrickColor.new("Bright orange")
			peach.Material = Enum.Material.SmoothPlastic

			local peachWeld = Instance.new("WeldConstraint")
			peachWeld.Part0 = plate.PrimaryPart
			peachWeld.Part1 = peach
			peachWeld.Parent = peach
			peach.Position = plate.PrimaryPart.Position + Vector3.new(0, 1.2, 0)
		end
	end

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
		local plate = char:FindFirstChild("Plate")
		if plate then plate:Destroy() end
		local handPeach = char:FindFirstChild("HandPeach")
		if handPeach then handPeach:Destroy() end
	end

	spawnPlateOnTable(currentTarget)

	-- 发放奖励
	local rewardType = "Deliver"
	local reward = Config.Economy.Rewards[rewardType]
	if reward then
		for key, value in pairs(reward) do
			if key == "仙晶" then
				local data = DataManager:GetData(player)
				if data then
					DataManager:UpdateField(player, "XianJing", data.XianJing + value)
				end
			elseif key == "功德" then
				local data = DataManager:GetData(player)
				if data then
					DataManager:UpdateField(player, "GongDe", data.GongDe + value)
				end
			elseif key == "风险" then
				local current = player:GetAttribute("Risk") or 0
				local maxRisk = Config.Risk.MaxRisk
				DataManager:UpdateField(player, "Risk", math.min(current + value, maxRisk))
			end
		end
	end

	print("✅ 加钱成功")

	-- 速度成长
	checkSpeedGrowth(player)

	-- 分配下一单
	assignOrder()

	return true, "Success"
end

-- 获取当前目标（用于客户端校验或其他用途）
function DeliverTask.GetTarget()
	return currentTarget
end

return DeliverTask
