-- ============================================================
-- 文件：ServerScriptService.Server.Systems.SceneSetup.server.lua
-- 功能：场景初始化 — 2D 横版布局，所有交互区域在 Z=0
--        角色 Z 轴锁定在 0，交互区域必须在 Z=0 才能触摸
--        装修元素在 Z=-4（后层）和 Z=4（前层）
-- ============================================================

-- ============================================================
-- 场景坐标配置（与 SceneConfig 保持一致）
-- ============================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Parent.DataManager)
local TimeService = nil  -- 延迟加载，避免循环依赖

local function getTimeModifier()
	if not TimeService then
		TimeService = require(script.Parent.TimeService)
	end
	if TimeService and TimeService.GetTimeModifier then
		return TimeService.GetTimeModifier()
	end
	return { RestEff = 1.0 }
end

local SCENES = {
	YiShanFang = Vector3.new(0, 3, 0),
	Alchemy    = Vector3.new(1000, 3, 0),
	Beast      = Vector3.new(2000, 3, 0),
	DanShop    = Vector3.new(-1000, 3, 0),
	Home       = Vector3.new(-500, 3, 0),
}

-- ============================================================
-- 基础建筑工具
-- ============================================================

local function createFloor(position, sizeX, sizeZ, color, transparency)
	local part = Instance.new("Part")
	part.Name = "Floor"
	part.Size = Vector3.new(sizeX, 0.5, sizeZ)
	part.Position = position
	part.Anchored = true
	part.CanCollide = true
	part.BrickColor = color
	part.Transparency = transparency or 0
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = workspace
	return part
end

local function createWall(position, sizeX, sizeY, sizeZ, color)
	local part = Instance.new("Part")
	part.Name = "Wall"
	part.Size = Vector3.new(sizeX, sizeY, sizeZ)
	part.Position = position
	part.Anchored = true
	part.CanCollide = true
	part.BrickColor = color
	part.Material = Enum.Material.Wood
	part.Parent = workspace
	return part
end

local function createPillar(position, height, color)
	local part = Instance.new("Part")
	part.Name = "Pillar"
	part.Size = Vector3.new(0.8, height, 0.8)
	part.Position = position
	part.Anchored = true
	part.CanCollide = true
	part.BrickColor = color
	part.Material = Enum.Material.Wood
	part.Shape = Enum.PartType.Cylinder
	part.Parent = workspace
	return part
end

local function createDecor(position, size, color, shape, material)
	local part = Instance.new("Part")
	part.Name = "Decor"
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.BrickColor = color
	part.Material = material or Enum.Material.SmoothPlastic
	if shape then part.Shape = shape end
	part.Parent = workspace
	return part
end

-- ============================================================
-- 工具：创建交互区域 Part + 标签（所有交互区域 Z=0）
-- ============================================================
local function createArea(cfg)
	local part = Instance.new("Part")
	part.Name = cfg.Name
	part.Size = cfg.Size
	part.Position = cfg.Position
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = true
	part.BrickColor = cfg.Color
	part.Transparency = cfg.Transparency or 0
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = workspace

	if cfg.Attrs then
		for key, value in pairs(cfg.Attrs) do
			part:SetAttribute(key, value)
		end
	end

	if cfg.Label then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "AreaLabel"
		billboard.Parent = part
		billboard.Adornee = part
		billboard.Size = UDim2.new(0, 200, 0, 40)
		billboard.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 2, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 200

		local label = Instance.new("TextLabel")
		label.Parent = billboard
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = cfg.Label
		label.TextColor3 = cfg.LabelColor or Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextSize = 18
		label.Font = Enum.Font.SourceSansBold
	end

	return part
end

-- ============================================================
-- 工具：创建场景提示板
-- ============================================================
local function createHintBoard(position, text, color)
	local part = Instance.new("Part")
	part.Name = "AlchemyHint"
	part.Size = Vector3.new(6, 0.5, 0.5)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.8
	part.BrickColor = color or BrickColor.new("Bright blue")
	part.Parent = workspace

	local bb = Instance.new("BillboardGui")
	bb.Name = "HintText"
	bb.Parent = part
	bb.Adornee = part
	bb.Size = UDim2.new(0, 300, 0, 60)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 500

	local label = Instance.new("TextLabel")
	label.Parent = bb
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 0.8)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextSize = 18
	label.Font = Enum.Font.SourceSansBold
	label.TextWrapped = true
end

-- ============================================================
-- 御膳房（传菜打工）— 2D 横版布局
-- ============================================================
local function setupYiShanFangScene()
	local origin = SCENES.YiShanFang

	-- 地面（Z 从 -4 到 4，加宽至 170 覆盖取餐处 x=-80）
	createFloor(origin + Vector3.new(0, -0.5, 0), 170, 8, BrickColor.new("Bright yellow"), 0.1)

	-- 后墙（z=-4）
	createWall(origin + Vector3.new(0, 3, -4), 170, 6, 0.5, BrickColor.new("Dark brown"))
	createWall(origin + Vector3.new(0, 6.5, -4), 170, 1, 0.5, BrickColor.new("Bright red"))

	-- 前侧柱子（z=4，装饰层）
	for x = -80, 80, 15 do
		createPillar(origin + Vector3.new(x, 3, 4), 6, BrickColor.new("Dark brown"))
	end

	-- 灶台背景（z=3，前层装饰）
	createWall(origin + Vector3.new(-8, 1, 3), 100, 2, 0.5, BrickColor.new("Dark stone"))
	createDecor(origin + Vector3.new(-8, 0.8, 3.5), Vector3.new(100, 0.3, 1), BrickColor.new("Dark grey"), nil, Enum.Material.Slate)

	-- 取餐处 — Z=0，最左边（从 -42 移至 -80，大幅延长跑动距离）
	createArea({
		Name = "DishArea",
		Position = origin + Vector3.new(-80, 1, 0),
		Size = Vector3.new(4, 0.5, 4),
		Color = BrickColor.new("Bright yellow"),
		Transparency = 0.3,
		Label = "取餐处",
	})

	-- 桌子 1-6 — Z=0，间隔拉宽（每 20 格一张，从 -50 到 50）
	local tablePositions = { -50, -30, -10, 10, 30, 50 }
	for i, xOffset in ipairs(tablePositions) do
		-- 桌面（交互区域）
		createArea({
			Name = "TableArea",
			Position = origin + Vector3.new(xOffset, 1, 0),
			Size = Vector3.new(3, 0.3, 3),
			Color = BrickColor.new("Bright red"),
			Transparency = 0.1,
			Attrs = { TableId = i },
			Label = "桌子" .. i,
		})
		-- 桌腿（装饰，z=±2）
		createDecor(origin + Vector3.new(xOffset - 1, 0.2, -2), Vector3.new(0.2, 0.5, 0.2), BrickColor.new("Dark brown"))
		createDecor(origin + Vector3.new(xOffset + 1, 0.2, -2), Vector3.new(0.2, 0.5, 0.2), BrickColor.new("Dark brown"))
		createDecor(origin + Vector3.new(xOffset - 1, 0.2, 2), Vector3.new(0.2, 0.5, 0.2), BrickColor.new("Dark brown"))
		createDecor(origin + Vector3.new(xOffset + 1, 0.2, 2), Vector3.new(0.2, 0.5, 0.2), BrickColor.new("Dark brown"))
	end

	print("🍽️ 御膳房已就绪（取餐处: x=-80, 桌子: x=-50~50, 地板 170 宽）")
end

-- ============================================================
-- 炼丹洞天 — 2D 横版布局
-- ============================================================
local function setupAlchemyScene()
	local origin = SCENES.Alchemy

	-- 地面
	createFloor(origin + Vector3.new(0, -0.5, 0), 50, 8, BrickColor.new("Dark grey"), 0.1)

	-- 后岩壁（z=-4）
	for x = -22, 22, 8 do
		createDecor(origin + Vector3.new(x, 2, -4), Vector3.new(6, 5, 0.5), BrickColor.new("Dark stone"), nil, Enum.Material.Slate)
	end

	-- 前岩壁（z=4）
	for x = -22, 22, 8 do
		createDecor(origin + Vector3.new(x, 2, 4), Vector3.new(6, 5, 0.5), BrickColor.new("Dark stone"), nil, Enum.Material.Slate)
	end

	-- 炼丹炉基座（z=0）
	createDecor(origin + Vector3.new(0, -0.2, 0), Vector3.new(5, 0.5, 5), BrickColor.new("Dark grey"), nil, Enum.Material.Slate)

	-- 炼丹炉（交互区域，Z=0）
	createArea({
		Name = "Furnace",
		Position = origin + Vector3.new(0, 2, 0),
		Size = Vector3.new(4, 4, 4),
		Color = BrickColor.new("Bright orange"),
		Transparency = 0.1,
		Label = "炼丹炉",
	})

	-- 炉顶发光球
	local glowBall = createDecor(origin + Vector3.new(0, 4.5, 0), Vector3.new(1.5, 1.5, 1.5), BrickColor.new("Bright orange"), Enum.PartType.Ball, Enum.Material.Neon)
	glowBall.Transparency = 0.3
	local fire = Instance.new("Fire")
	fire.Parent = glowBall
	fire.Size = 5
	fire.Heat = 10

	-- 地面光效
	local glowFloor = createDecor(origin + Vector3.new(0, 0, 0), Vector3.new(3, 0.1, 3), BrickColor.new("Bright orange"), nil, Enum.Material.Neon)
	glowFloor.Transparency = 0.5

	-- 药材台（交互区域，Z=0，在炼丹炉右侧）
	createArea({
		Name = "IngredientTable",
		Position = origin + Vector3.new(15, 0.5, 0),
		Size = Vector3.new(5, 0.8, 4),
		Color = BrickColor.new("Bright green"),
		Transparency = 0.2,
		Label = "药材台",
	})

	-- 药材架（z=±3 装饰层）
	createDecor(origin + Vector3.new(16, 1.5, -3), Vector3.new(0.5, 1.5, 0.5), BrickColor.new("Dark brown"))
	createDecor(origin + Vector3.new(16, 1.5, 3), Vector3.new(0.5, 1.5, 0.5), BrickColor.new("Dark brown"))
	createDecor(origin + Vector3.new(16, 2.5, 0), Vector3.new(5, 0.2, 3), BrickColor.new("Dark brown"))

	-- ============================================================
	-- 场景引导提示
	-- ============================================================

	-- Step 1: 药材台提示
	createHintBoard(
		origin + Vector3.new(15, 4, 0),
		"Step 1: 触摸药材台\n捡起 2 种药材",
		BrickColor.new("Bright green")
	)

	-- Step 2: 炼丹炉提示
	createHintBoard(
		origin + Vector3.new(0, 6, 0),
		"Step 2: 触摸丹炉\n打开炼丹面板",
		BrickColor.new("Bright orange")
	)

	-- 丹方提示（放在药材台和丹炉之间）
	createHintBoard(
		origin + Vector3.new(8, 3, 0),
		"丹方:\n草药+清水 = 回气丹\n草药+火晶 = 清毒散\n灵芝+仙露 = 聚神丹",
		BrickColor.new("Bright yellow")
	)

	-- ============================================================
	-- 药材名称标签
	-- ============================================================
	local ingredientNames = { "草药", "清水", "灵芝", "仙露", "火晶" }
	for i, name in ipairs(ingredientNames) do
		local labelPart = Instance.new("Part")
		labelPart.Name = "IngredientLabel_" .. name
		labelPart.Size = Vector3.new(0.5, 0.1, 0.5)
		labelPart.Position = origin + Vector3.new(13 + (i - 1) * 2.5, 1.8, 0)
		labelPart.Anchored = true
		labelPart.CanCollide = false
		labelPart.Transparency = 1
		labelPart.Parent = workspace

		local bb = Instance.new("BillboardGui")
		bb.Parent = labelPart
		bb.Adornee = labelPart
		bb.Size = UDim2.new(0, 80, 0, 30)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 200

		local label = Instance.new("TextLabel")
		label.Parent = bb
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = name
		label.TextColor3 = Color3.new(0.8, 1, 0.8)
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextSize = 16
		label.Font = Enum.Font.SourceSansBold
	end

	print("⚗️ 炼丹洞天已就绪（炼丹炉: x=0, 药材台: x=15）")
end

-- ============================================================
-- 妖兽战场 — 2D 横版布局
-- ============================================================
local function setupBeastScene()
	local origin = SCENES.Beast

	-- 地面
	createFloor(origin + Vector3.new(0, -0.5, 0), 50, 8, BrickColor.new("Brown"), 0.1)

	-- 后围栏（z=-3）
	createDecor(origin + Vector3.new(0, 1, -3), Vector3.new(50, 2, 0.5), BrickColor.new("Dark stone"), nil, Enum.Material.Slate)

	-- 前围栏（z=3）
	createDecor(origin + Vector3.new(0, 1, 3), Vector3.new(50, 2, 0.5), BrickColor.new("Dark stone"), nil, Enum.Material.Slate)

	-- 角柱 + 火把
	for _, x in ipairs({ -23, 23 }) do
		createDecor(origin + Vector3.new(x, 3, -3), Vector3.new(1.5, 5, 0.8), BrickColor.new("Dark grey"), nil, Enum.Material.Slate)
		createDecor(origin + Vector3.new(x, 3, 3), Vector3.new(1.5, 5, 0.8), BrickColor.new("Dark grey"), nil, Enum.Material.Slate)
		-- 火把
		for _, z in ipairs({ -3, 3 }) do
			local torch = createDecor(origin + Vector3.new(x, 5.5, z), Vector3.new(0.5, 0.5, 0.5), BrickColor.new("Bright orange"), Enum.PartType.Ball, Enum.Material.Neon)
			local f = Instance.new("Fire")
			f.Parent = torch
			f.Size = 3
		end
	end

	-- 妖兽生成台（交互区域，Z=0）
	createArea({
		Name = "BeastSpawn",
		Position = origin + Vector3.new(0, 0.5, 0),
		Size = Vector3.new(6, 0.5, 6),
		Color = BrickColor.new("Really red"),
		Transparency = 0.3,
		Label = "妖兽战场",
	})

	print("🐉 妖兽战场已就绪（生成台: x=0）")
end

-- ============================================================
-- 仙丹阁 — 2D 横版布局
-- ============================================================
local function setupShopScene()
	local origin = SCENES.DanShop

	-- 地面
	createFloor(origin + Vector3.new(0, -0.5, 0), 40, 8, BrickColor.new("Bright violet"), 0.1)

	-- 后墙（z=-4）
	createWall(origin + Vector3.new(0, 3, -4), 40, 6, 0.5, BrickColor.new("Dark green"))

	-- 前柱（z=4）
	for x = -16, 16, 10 do
		createPillar(origin + Vector3.new(x, 3, 4), 6, BrickColor.new("Dark green"))
	end

	-- 柜台（z=±2 装饰）
	createDecor(origin + Vector3.new(0, 1, -2), Vector3.new(24, 1.5, 0.5), BrickColor.new("Dark brown"), nil, Enum.Material.Wood)
	createDecor(origin + Vector3.new(0, 1, 2), Vector3.new(24, 1.5, 0.5), BrickColor.new("Dark brown"), nil, Enum.Material.Wood)

	-- 仙丹阁（交互区域，Z=0）
	createArea({
		Name = "DanShop",
		Position = origin + Vector3.new(0, 1, 0),
		Size = Vector3.new(4, 0.5, 4),
		Color = BrickColor.new("Bright violet"),
		Transparency = 0.2,
		Label = "仙丹阁",
	})

	-- 丹药展示（z=±3 装饰层）
	for i = 1, 5 do
		local xOffset = -12 + (i - 1) * 6
		createDecor(origin + Vector3.new(xOffset, 0.5, -3), Vector3.new(1.5, 0.8, 1), BrickColor.new("Gold"), Enum.PartType.Cylinder)
		local bottle = createDecor(origin + Vector3.new(xOffset, 1.2, -3), Vector3.new(0.5, 0.8, 0.5), BrickColor.new("Bright blue"), Enum.PartType.Cylinder)
		bottle.Material = Enum.Material.Glass
	end

	print("💎 仙丹阁已就绪")
end

-- ============================================================
-- 家（炼化提升）— 2D 横版布局
-- ============================================================
local function setupHomeScene()
	local origin = SCENES.Home

	-- 地面
	createFloor(origin + Vector3.new(0, -0.5, 0), 30, 8, BrickColor.new("Bright yellow"), 0.1)

	-- 后墙（z=-4）
	createWall(origin + Vector3.new(0, 3, -4), 30, 6, 0.5, BrickColor.new("Dark brown"))

	-- 左右墙（z=-4 到 z=4）
	createWall(origin + Vector3.new(-14, 3, 0), 0.5, 6, 8, BrickColor.new("Dark brown"))
	createWall(origin + Vector3.new(14, 3, 0), 0.5, 6, 8, BrickColor.new("Dark brown"))

	-- 屋顶装饰
	createDecor(origin + Vector3.new(0, 6, 0), Vector3.new(30, 0.3, 8), BrickColor.new("Bright red"), nil, Enum.Material.Wood)

	-- 蒲团（z=0，角色路径上）
	createDecor(origin + Vector3.new(0, 0.3, 0), Vector3.new(3, 0.4, 3), BrickColor.new("Gold"), Enum.PartType.Cylinder)
	createDecor(origin + Vector3.new(0, 0.5, 0), Vector3.new(2, 0.2, 2), BrickColor.new("Bright orange"), Enum.PartType.Cylinder)

	-- 炼化区（交互区域，Z=0）— 冥想恢复
	local cultivationPart = createArea({
		Name = "HomeCultivation",
		Position = origin + Vector3.new(0, 1, 0),
		Size = Vector3.new(3, 0.5, 3),
		Color = BrickColor.new("Gold"),
		Transparency = 0.2,
		Label = "冥想炼化",
	})

	-- 冥想恢复逻辑
	local meditating = {}  -- [userId] = true
	cultivationPart.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = Players:GetPlayerFromCharacter(char)
		if not player then return end
		if meditating[player.UserId] then return end
		-- 戾气 > 50 时不可冥想
		local malice = player:GetAttribute("Malice") or 0
		if malice > 50 then
			local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
			if eventsFolder then
				local taskEvent = eventsFolder:FindFirstChild("TaskEvent")
				if taskEvent then
					taskEvent:FireClient(player, "MeditationBlocked", { Reason = "戾气过重，无法入定" })
				end
			end
			return
		end

		meditating[player.UserId] = true
		-- 冥想协程
		task.spawn(function()
			local maxDuration = 30  -- 最多冥想 30 秒
			local elapsed = 0
			while meditating[player.UserId] and elapsed < maxDuration do
				task.wait(5)
				elapsed += 5
				-- 检查玩家是否还在附近（10 格内）
				local char = player.Character
				if not char then break end
				local root = char:FindFirstChild("HumanoidRootPart")
				if not root then break end
				local dist = (root.Position - cultivationPart.Position).Magnitude
				if dist > 10 then break end

				-- 获取时辰恢复修正（深夜恢复更快）
				local timeMod = getTimeModifier()
				local restEff = timeMod.RestEff or 1.0

				-- 应用恢复（基础值 × 时辰恢复修正）
				local data = DataManager and DataManager:GetData(player)
				if data then
					local staminaGain = math.floor(3 * restEff)
					local spiritGain = math.floor(3 * restEff)
					local fatigueLoss = math.max(1, math.floor(1 * restEff))
					data.Stamina = math.min(100, (data.Stamina or 0) + staminaGain)
					data.Spirit = math.min(100, (data.Spirit or 0) + spiritGain)
					data.Fatigue = math.max(0, (data.Fatigue or 0) - fatigueLoss)
					DataManager:UpdateField(player, "Stamina", data.Stamina)
					DataManager:UpdateField(player, "Spirit", data.Spirit)
					DataManager:UpdateField(player, "Fatigue", data.Fatigue)
				end
			end
			meditating[player.UserId] = nil
		end)
	end)
	-- 玩家离开时停止冥想
	cultivationPart.ChildRemoved:Connect(function(child)
		-- 不直接处理，由协程的距离检查处理
	end)

	-- 祈福台（每日功德）
	local prayerPart = createArea({
		Name = "PrayerAltar",
		Position = origin + Vector3.new(-8, 1, 0),
		Size = Vector3.new(2, 0.5, 2),
		Color = BrickColor.new("Bright yellow"),
		Transparency = 0.1,
		Label = "祈福台（每日功德）",
		Attrs = { PrayerReward = 5 },
	})
	local prayerDebounce = {}
	prayerPart.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = Players:GetPlayerFromCharacter(char)
		if not player then return end
		if prayerDebounce[player.UserId] then return end

		-- 检查是否今日已祈福
		local data = DataManager and DataManager:GetData(player)
		if not data then return end
		local todayKey = os.date("%Y%m%d")
		if data.LastPrayerDate == todayKey then
			return
		end

		prayerDebounce[player.UserId] = true
		data.GongDe = (data.GongDe or 0) + 5
		data.LastPrayerDate = todayKey
		DataManager:UpdateField(player, "GongDe", data.GongDe)
		print("🙏 " .. player.Name .. " 祈福获得 5 功德")

		task.wait(1)
		prayerDebounce[player.UserId] = nil
	end)

	-- 药架（z=-3 装饰层）
	createDecor(origin + Vector3.new(-8, 1, -3), Vector3.new(3, 2.5, 0.5), BrickColor.new("Dark brown"), nil, Enum.Material.Wood)
	for i = 1, 3 do
		local bottle = createDecor(origin + Vector3.new(-8 + (i - 2) * 1.2, 2, -3.2), Vector3.new(0.4, 0.6, 0.4), BrickColor.new("Bright green"), Enum.PartType.Cylinder)
		bottle.Material = Enum.Material.Glass
	end

	-- 小桌（z=3 装饰层）
	createDecor(origin + Vector3.new(8, 0.5, 3), Vector3.new(2, 0.5, 1), BrickColor.new("Dark brown"), nil, Enum.Material.Wood)

	-- 暖色灯光
	local lightPart = createDecor(origin + Vector3.new(0, 5, 0), Vector3.new(0.2, 0.2, 0.2), BrickColor.new("Bright yellow"), Enum.PartType.Ball, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Parent = lightPart
	light.Range = 20
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 200, 100)

	print("🏠 家已就绪（炼化区: x=0）")
end

-- ============================================================
-- 主初始化
-- ============================================================
task.wait(3)
setupYiShanFangScene()
setupAlchemyScene()
setupBeastScene()
setupShopScene()
setupHomeScene()
print("✅ 所有场景已初始化（御膳房/炼丹洞天/妖兽战场/仙丹阁/家）")
