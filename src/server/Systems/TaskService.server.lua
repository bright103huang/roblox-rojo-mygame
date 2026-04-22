-- ============================================================
-- 文件：ServerScriptService.Server.Systems.TaskService.server.lua
-- 功能：传菜任务核心逻辑（含桃子显示修复、出生点强制设置）
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- ============================================================
-- 内嵌默认配置（保证运行）
-- ============================================================
local DEFAULT_REWARDS = {
	Deliver = { XianJing = 10 },
	StealPeach = { XianJing = 30, Risk = 20 },
	HelpNPC = { GongDe = 10 },
	BigEvent = { XianJing = 50, GongDe = 20, Risk = 30 },
}
local DEFAULT_RISK_MAX = 100

-- 尝试加载外部配置（若失败则用默认）
local Config = {
	Economy = { Rewards = DEFAULT_REWARDS },
	Risk = { MaxRisk = DEFAULT_RISK_MAX }
}

local success = pcall(function()
	local shared = ReplicatedStorage:WaitForChild("Shared", 5)
	if shared then
		local configFolder = shared:WaitForChild("Config", 5)
		if configFolder then
			local indexModule = configFolder:WaitForChild("index", 5)
			if indexModule and indexModule:IsA("ModuleScript") then
				Config = require(indexModule)
				print("✅ 成功加载外部配置")
			end
		end
	end
end)

-- 奖励发放函数
local function giveReward(player, rewardType)
	local reward = Config.Economy.Rewards[rewardType]
	if not reward then return end

	for key, value in pairs(reward) do
		if key == "XianJing" or key == "GongDe" then
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local statName = (key == "XianJing") and "仙晶" or "功德"
				local stat = leaderstats:FindFirstChild(statName)
				if stat then
					stat.Value += value
				end
			end
		elseif key == "Risk" then
			local current = player:GetAttribute("Risk") or 0
			player:SetAttribute("Risk", math.min(current + value, Config.Risk.MaxRisk))
		end
	end
end

-- ============================================================
-- 创建 Events 和 RemoteEvent
-- ============================================================
local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not eventsFolder then
	eventsFolder = Instance.new("Folder")
	eventsFolder.Name = "Events"
	eventsFolder.Parent = ReplicatedStorage
end

local TaskEvent = eventsFolder:FindFirstChild("TaskEvent")
if not TaskEvent then
	TaskEvent = Instance.new("RemoteEvent")
	TaskEvent.Name = "TaskEvent"
	TaskEvent.Parent = eventsFolder
	print("✅ TaskEvent 已创建")
end

-- ============================================================
-- 游戏逻辑数据
-- ============================================================
local carrying = {}
local currentTarget = nil
local currentBillboard = nil

-- 收集所有 TableArea
local tables = {}
for _, v in pairs(workspace:GetDescendants()) do
	if v.Name == "TableArea" then
		table.insert(tables, v)
	end
end

-- 强制清除所有桌子上残留的指示器
local function clearAllIndicators()
	for _, tableArea in ipairs(tables) do
		local existing = tableArea:FindFirstChild("TargetIndicator")
		if existing then
			existing:Destroy()
		end
	end
	currentBillboard = nil
end

-- 创建新指示器
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

-- 分配新订单
local function assignOrder()
	if #tables == 0 then return end
	currentTarget = tables[math.random(1, #tables)]
	createIndicator(currentTarget)
	print("🎯 当前目标桌子ID：", currentTarget:GetAttribute("TableId"))
end

-- 启动时只执行一次分配
assignOrder()

-- 盘子模板
local plateTemplate = ReplicatedStorage:WaitForChild("Plate")

-- ============================================================
-- 在桌子上生成盘子（桃子独立放置，确保可见）
-- ============================================================
local function spawnPlateOnTable(tableArea)
	-- --- 1. 生成盘子 ---
	local newPlate = plateTemplate:Clone()
	newPlate.Name = "ServedPlate"
	newPlate.Parent = workspace

	local plateBase = newPlate:FindFirstChild("PlateBase")
	if not plateBase then
		plateBase = newPlate:FindFirstChild("Plate") or newPlate:FindFirstChild("PlatePart")
		if plateBase then
			newPlate.PrimaryPart = plateBase
		end
	end

	if plateBase then
		plateBase.Anchored = true
	end

	-- 计算位置
	local tablePos = tableArea.Position
	local upVector = Vector3.new(0, 1, 0)
	local basePos = tablePos + upVector * 0.8
	local randomOffset = Vector3.new(
		(math.random() - 0.5) * 2,
		0,
		(math.random() - 0.5) * 2
	)
	local platePos = basePos + randomOffset
	local plateRot = CFrame.Angles(0, math.rad(math.random(0, 360)), 0)

	if plateBase then
		newPlate:SetPrimaryPartCFrame(CFrame.new(platePos) * plateRot)
	end

	-- --- 2. 单独生成桃子 ---
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
			(math.random() - 0.5) * 0.8,
			1.2,
			(math.random() - 0.5) * 0.8
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
-- 事件处理（含手持桃子修复）
-- ============================================================
TaskEvent.OnServerEvent:Connect(function(player, action, tableId)
	if action == "Pick" then
		if carrying[player.UserId] then return end
		carrying[player.UserId] = true

		local char = player.Character
		if not char then return end

		local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
		if not hand then return end

		-- 克隆盘子
		local plate = plateTemplate:Clone()
		plate.Name = "Plate"
		plate.Parent = char
		plate.PrimaryPart = plate:FindFirstChild("PlateBase")
		plate:SetPrimaryPartCFrame(hand.CFrame * CFrame.new(0, -0.3, -1))

		-- 焊接盘子到手
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = plate.PrimaryPart
		weld.Parent = plate.PrimaryPart

		-- 单独克隆桃子并焊接到盘子上
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

	elseif action == "Drop" then
		if not carrying[player.UserId] then return end
		if not tableId then return end
		if not currentTarget then return end

		local targetId = currentTarget:GetAttribute("TableId")
		if tableId ~= targetId then
			TaskEvent:FireClient(player, "DropFailed")
			return
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

		giveReward(player, "Deliver")
		print("✅ 加钱成功")

		TaskEvent:FireClient(player, "DropSuccess")

		assignOrder()
	end
end)

-- ============================================================
-- 修复出生点：强制将玩家传送到指定出生点
-- ============================================================
local SPAWN_NAME = "WorkSpawn"  -- 请改为你工作区的出生点名称

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local spawnLocation = workspace:FindFirstChild(SPAWN_NAME)
		if spawnLocation then
			local hrp = char:WaitForChild("HumanoidRootPart")
			hrp.CFrame = spawnLocation.CFrame + Vector3.new(0, 3, 0)
		else
			warn("❌ 未找到出生点：" .. SPAWN_NAME)
		end
	end)
end)