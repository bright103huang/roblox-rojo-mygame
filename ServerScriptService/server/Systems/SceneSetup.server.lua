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
-- 工具：创建地下地基（防止角色掉入虚空）
-- ============================================================
local function createUnderFloor(position, spanX, spanZ)
	local part = Instance.new("Part")
	part.Name = "UnderFloor"
	part.Size = Vector3.new(spanX, 0.5, spanZ)
	part.Position = position + Vector3.new(0, -1.5, 0)
	part.Anchored = true
	part.CanCollide = true
	part.Transparency = 0.95
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = workspace
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
	createUnderFloor(origin + Vector3.new(0, -0.5, 0), 500, 40)

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

	-- ============================================================
	-- 场景引导提示（吐槽风）
	-- ============================================================
	createHintBoard(
		origin + Vector3.new(-80, 4, 0),
		"① 左边取桃→右边送——送错桌明天喂妖兽",
		BrickColor.new("Bright yellow")
	)
	createHintBoard(
		origin + Vector3.new(0, 4, 0),
		"② 跟着 ⭐ 走，别问为什么，问就是编制",
		BrickColor.new("Bright red")
	)
	createHintBoard(
		origin + Vector3.new(50, 4, 0),
		"③ 送到即结算——干得好加鸡腿，干不好……你懂的",
		BrickColor.new("Bright green")
	)

	print("🍽️ 御膳房已就绪（取餐处: x=-80, 桌子: x=-50~50, 地板 170 宽）")
end

-- ============================================================
-- 炼丹洞天 — 2D 横版布局
-- ============================================================
local function setupAlchemyScene()
	local origin = SCENES.Alchemy

	-- 地面
	createFloor(origin + Vector3.new(0, -0.5, 0), 50, 8, BrickColor.new("Dark grey"), 0.1)
	createUnderFloor(origin + Vector3.new(0, -0.5, 0), 500, 40)

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

	-- 灵草台（交互区域，Z=0，在丹炉左侧）
	createArea({
		Name = "HerbStation",
		Position = origin + Vector3.new(-10, 0.5, 0),
		Size = Vector3.new(4, 0.8, 4),
		Color = BrickColor.new("Bright green"),
		Transparency = 0.2,
		Label = "灵草台",
	})

	-- 柴火堆（交互区域，Z=0，在丹炉右侧）
	createArea({
		Name = "Woodpile",
		Position = origin + Vector3.new(10, 0.5, 0),
		Size = Vector3.new(4, 0.8, 4),
		Color = BrickColor.new("Bright orange"),
		Transparency = 0.2,
		Label = "柴火堆",
	})

	-- 灵草台装饰
	createDecor(origin + Vector3.new(-10, 1.5, -3), Vector3.new(0.5, 1.5, 0.5), BrickColor.new("Dark brown"))
	createDecor(origin + Vector3.new(-10, 1.5, 3), Vector3.new(0.5, 1.5, 0.5), BrickColor.new("Dark brown"))

	-- 柴火堆装饰
	createDecor(origin + Vector3.new(10, 1, -3), Vector3.new(3, 0.5, 0.5), BrickColor.new("Dark brown"))
	createDecor(origin + Vector3.new(10, 1, 3), Vector3.new(3, 0.5, 0.5), BrickColor.new("Dark brown"))
	for i = 1, 5 do
		local log = createDecor(origin + Vector3.new(8 + i * 0.8, 0.5, 0), Vector3.new(1.2, 0.4, 0.4), BrickColor.new("Dark brown"), Enum.PartType.Cylinder)
	end

	-- ============================================================
	-- 场景引导提示
	-- ============================================================

	-- 灵草台提示
	createHintBoard(
		origin + Vector3.new(-10, 4, 0),
		"① 灵草台薅羊毛——药材随便拿不要钱",
		BrickColor.new("Bright green")
	)

	-- 柴火堆提示
	createHintBoard(
		origin + Vector3.new(10, 4, 0),
		"② 柴火堆搬砖——点火就靠你了",
		BrickColor.new("Bright orange")
	)

	-- 丹炉提示
	createHintBoard(
		origin + Vector3.new(0, 6, 0),
		"③ 添柴×3 赌一把——成丹血赚，炸炉不亏",
		BrickColor.new("Bright orange")
	)

	-- 流程指示
	createHintBoard(
		origin + Vector3.new(-5, 2.5, 0),
		"← 薅药材  炉子 →\n搬柴火",
		BrickColor.new("Bright yellow")
	)

	-- ============================================================
	-- 药材名称标签（装饰用）
	-- ============================================================
	local ingredientNames = { "草药", "清水", "灵芝", "仙露", "火晶" }
	local labelColors = {
		Color3.new(0.6, 1, 0.6),
		Color3.new(0.6, 0.8, 1),
		Color3.new(1, 0.8, 0.6),
		Color3.new(1, 0.6, 1),
		Color3.new(1, 0.5, 0.3),
	}
	for i, name in ipairs(ingredientNames) do
		local labelPart = Instance.new("Part")
		labelPart.Name = "IngredientLabel_" .. name
		labelPart.Size = Vector3.new(0.5, 0.1, 0.5)
		labelPart.Position = origin + Vector3.new(-16 + (i - 1) * 1.8, 3.5, 0)
		labelPart.Anchored = true
		labelPart.CanCollide = false
		labelPart.Transparency = 1
		labelPart.Parent = workspace

		local bb = Instance.new("BillboardGui")
		bb.Parent = labelPart
		bb.Adornee = labelPart
		bb.Size = UDim2.new(0, 60, 0, 24)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 200

		local label = Instance.new("TextLabel")
		label.Parent = bb
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = name
		label.TextColor3 = labelColors[i]
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextSize = 14
		label.Font = Enum.Font.SourceSans
	end

	print("⚗️ 炼丹洞天已就绪（丹炉: x=0, 灵草台: x=-10, 柴火堆: x=10）")
end

-- ============================================================
-- 妖兽战场 — 2D 横版角斗场（摄像机在 z=30，前侧不能有高墙）
-- 设计：宏大的背景墙(z=-9) + 低矮前围栏(z=4) + 中央战场
-- ============================================================
local function setupBeastScene()
	local origin = SCENES.Beast

	-- ============================================================
	-- 地面：140 × 12（半个足球场的感觉）
	-- ============================================================
	createFloor(origin + Vector3.new(0, -0.5, 0), 140, 12, BrickColor.new("Light stone"), 0.05)
	createUnderFloor(origin + Vector3.new(0, -0.5, 0), 500, 40)

	-- ============================================================
	-- 地面标记：中央战斗圈（同心圆环）
	-- ============================================================
	for r = 2, 10, 2 do
		local ring = createDecor(
			origin + Vector3.new(0, 0.05, 0),
			Vector3.new(r * 2, 0.05, r * 2),
			BrickColor.new("Dark grey"),
			Enum.PartType.Ball,
			Enum.Material.SmoothPlastic
		)
		ring.Transparency = 0.5 + (r / 10) * 0.4
		ring.CanCollide = false
	end
	-- 中央十字线
	createDecor(origin + Vector3.new(0, 0.05, 0), Vector3.new(30, 0.05, 0.3), BrickColor.new("Dark grey"), nil, Enum.Material.SmoothPlastic).Transparency = 0.6
	createDecor(origin + Vector3.new(0, 0.05, 0), Vector3.new(0.3, 0.05, 8), BrickColor.new("Dark grey"), nil, Enum.Material.SmoothPlastic).Transparency = 0.6

	-- ============================================================
	-- 后墙（z=-9）：12 高双层竞技场围墙 — 宏大背景
	-- ============================================================
	-- 下层主墙
	createDecor(origin + Vector3.new(0, 3.5, -9), Vector3.new(120, 7, 0.8), BrickColor.new("Dark stone"), nil, Enum.Material.Slate)
	-- 上层墙
	createDecor(origin + Vector3.new(0, 9, -9), Vector3.new(120, 4, 0.8), BrickColor.new("Dark grey"), nil, Enum.Material.Slate)

	-- 拱形窗列
	for x = -55, 55, 10 do
		createDecor(origin + Vector3.new(x, 4, -8.5), Vector3.new(4, 4, 0.3), BrickColor.new("Really black"), Enum.PartType.Cylinder, Enum.Material.SmoothPlastic).Transparency = 0.3
		createDecor(origin + Vector3.new(x, 2.5, -8.5), Vector3.new(0.6, 0.6, 0.3), BrickColor.new("Bright orange"), Enum.PartType.Ball, Enum.Material.Neon).Transparency = 0.2
	end
	-- 城垛
	for x = -58, 58, 4 do
		createDecor(origin + Vector3.new(x, 11.5, -9), Vector3.new(2, 1.5, 0.8), BrickColor.new("Dark stone"), nil, Enum.Material.Slate)
	end
	-- 后墙间隔立柱
	for x = -50, 50, 15 do
		if math.abs(x) > 5 then
			createDecor(origin + Vector3.new(x, 4, -9), Vector3.new(1, 8, 1), BrickColor.new("Dark grey"), nil, Enum.Material.Slate)
		end
	end

	-- ============================================================
	-- 后侧阶梯看台（z=-7，背景墙前方）
	-- ============================================================
	for step = 0, 2 do
		createDecor(origin + Vector3.new(-35, 0.3 + step * 0.6, -7 + step * 0.6), Vector3.new(60, 0.5, 0.8), BrickColor.new("Dark grey"), nil, Enum.Material.SmoothPlastic)
	end
	for x = -40, 40, 10 do
		createDecor(origin + Vector3.new(x, 1.5, -7), Vector3.new(0.5, 3.5, 0.6), BrickColor.new("Dark stone"), nil, Enum.Material.Slate)
	end

	-- ============================================================
	-- 前侧低围栏（z=4，仅 2 格高，不挡 2D 视线）
	-- ============================================================
	createDecor(origin + Vector3.new(0, 1, 4), Vector3.new(120, 2, 0.5), BrickColor.new("Dark grey"), nil, Enum.Material.Slate)
	-- 前侧细柱（像御膳房一样，不挡视线）
	for x = -55, 55, 10 do
		createDecor(origin + Vector3.new(x, 1.5, 4), Vector3.new(0.5, 3, 0.5), BrickColor.new("Dark grey"), nil, Enum.Material.Slate)
	end

	-- ============================================================
	-- 左侧入口大门（玩家走入，z=0）
	-- ============================================================
	createDecor(origin + Vector3.new(-56, 5, 0), Vector3.new(1.5, 10, 1.5), BrickColor.new("Dark grey"), nil, Enum.Material.Slate)
	createDecor(origin + Vector3.new(-52, 5, 0), Vector3.new(1.5, 10, 1.5), BrickColor.new("Dark grey"), nil, Enum.Material.Slate)
	createDecor(origin + Vector3.new(-54, 10, 0), Vector3.new(5, 0.8, 2), BrickColor.new("Dark grey"), nil, Enum.Material.Slate)
	createDecor(origin + Vector3.new(-54, 11, 0), Vector3.new(6, 0.5, 1.6), BrickColor.new("Dark stone"), nil, Enum.Material.Slate)
	local gateTorch = createDecor(origin + Vector3.new(-54, 8.5, 0), Vector3.new(0.5, 0.5, 0.5), BrickColor.new("Bright orange"), Enum.PartType.Ball, Enum.Material.Neon)
	local gFire = Instance.new("Fire")
	gFire.Parent = gateTorch; gFire.Size = 5; gFire.Heat = 15

	-- ============================================================
	-- 右侧铁门（妖兽冲出，z=0）
	-- ============================================================
	createDecor(origin + Vector3.new(52, 5, 0), Vector3.new(1.5, 10, 1.5), BrickColor.new("Dark grey"), nil, Enum.Material.Slate)
	createDecor(origin + Vector3.new(56, 5, 0), Vector3.new(1.5, 10, 1.5), BrickColor.new("Dark grey"), nil, Enum.Material.Slate)
	createDecor(origin + Vector3.new(54, 10, 0), Vector3.new(5, 0.8, 2), BrickColor.new("Dark grey"), nil, Enum.Material.Slate)
	-- 铁栅栏竖条
	for xOff = -1.5, 1.5, 0.3 do
		createDecor(origin + Vector3.new(54 + xOff, 4.5, 0), Vector3.new(0.08, 8, 0.08), BrickColor.new("Dark grey"), nil, Enum.Material.Neon)
	end
	for yOff = 1, 7, 2 do
		createDecor(origin + Vector3.new(54, yOff, 0), Vector3.new(3, 0.08, 0.08), BrickColor.new("Dark grey"), nil, Enum.Material.Neon)
	end
	local monsterTorch = createDecor(origin + Vector3.new(54, 8.5, 0), Vector3.new(0.5, 0.5, 0.5), BrickColor.new("Bright orange"), Enum.PartType.Ball, Enum.Material.Neon)
	local mFire = Instance.new("Fire")
	mFire.Parent = monsterTorch; mFire.Size = 6; mFire.Heat = 18

	-- ============================================================
	-- 四角瞭望塔（只有后侧 z=-9，前侧不建以免挡视线）
	-- ============================================================
	local backCorners = { { -60, -9 }, { 60, -9 } }
	for _, cp in ipairs(backCorners) do
		createDecor(origin + Vector3.new(cp[1], 4, cp[2]), Vector3.new(2.5, 8, 2.5), BrickColor.new("Dark stone"), nil, Enum.Material.Slate)
		createDecor(origin + Vector3.new(cp[1], 8.5, cp[2]), Vector3.new(3, 1, 3), BrickColor.new("Dark grey"), nil, Enum.Material.Slate)
		local torch = createDecor(origin + Vector3.new(cp[1], 9.5, cp[2]), Vector3.new(1, 1, 1), BrickColor.new("Bright orange"), Enum.PartType.Ball, Enum.Material.Neon)
		local f = Instance.new("Fire")
		f.Parent = torch; f.Size = 8; f.Heat = 20
	end

	-- ============================================================
	-- 边缘防掉落碰撞墙（不可见）
	-- ============================================================
	local leftEdge = Instance.new("Part")
	leftEdge.Name = "BeastEdgeWall"
	leftEdge.Size = Vector3.new(0.5, 8, 16)
	leftEdge.Position = origin + Vector3.new(-64, 4, 0)
	leftEdge.Anchored = true; leftEdge.CanCollide = true; leftEdge.Transparency = 1
	leftEdge.Parent = workspace

	local rightEdge = Instance.new("Part")
	rightEdge.Name = "BeastEdgeWall"
	rightEdge.Size = Vector3.new(0.5, 8, 16)
	rightEdge.Position = origin + Vector3.new(64, 4, 0)
	rightEdge.Anchored = true; rightEdge.CanCollide = true; rightEdge.Transparency = 1
	rightEdge.Parent = workspace

	-- ============================================================
	-- 妖兽生成台（交互区域，Z=0）
	-- ============================================================
	createArea({
		Name = "BeastSpawn",
		Position = origin + Vector3.new(0, 0.5, 0),
		Size = Vector3.new(6, 0.5, 6),
		Color = BrickColor.new("Really red"),
		Transparency = 0.3,
		Label = "⚔ 角斗场中央",
	})

	-- ============================================================
	-- 场景引导提示
	-- ============================================================
	createHintBoard(origin + Vector3.new(0, 6, 0),
		"① 踏入中央红区→召唤妖兽，跑都跑不掉",
		BrickColor.new("Really red"))
	createHintBoard(origin + Vector3.new(-28, 5, 0),
		"② 走近妖兽→自动碰瓷，连撞三次定胜负",
		BrickColor.new("Bright blue"))
	createHintBoard(origin + Vector3.new(28, 5, 0),
		"③ 打不过就跑，30秒后妖兽自己下班",
		BrickColor.new("Bright green"))

	print("🏟️ 角斗场已就绪（140x12 沙地 + 12高背景墙 + 前低围栏 + 拱廊看台）")
end

-- ============================================================
-- 仙丹阁 — 2D 横版布局
-- ============================================================
local function setupShopScene()
	local origin = SCENES.DanShop

	-- 地面
	createFloor(origin + Vector3.new(0, -0.5, 0), 40, 8, BrickColor.new("Bright violet"), 0.1)
	createUnderFloor(origin + Vector3.new(0, -0.5, 0), 500, 40)

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

	-- ============================================================
	-- 场景引导提示
	-- ============================================================
	createHintBoard(
		origin + Vector3.new(0, 4, 0),
		"① 看柜台——好货都在上面，仙晶带够了吗",
		BrickColor.new("Bright violet")
	)
	createHintBoard(
		origin + Vector3.new(0, 2.5, 0),
		"② 仙晶不够？传送去打工啊，还愣着干啥",
		BrickColor.new("Bright yellow")
	)

	print("💎 仙丹阁已就绪")
end

-- ============================================================
-- 家（炼化提升）— 2D 横版布局
-- ============================================================
local function setupHomeScene()
	local origin = SCENES.Home

	-- 地面
	createFloor(origin + Vector3.new(0, -0.5, 0), 30, 8, BrickColor.new("Bright yellow"), 0.1)
	createUnderFloor(origin + Vector3.new(0, -0.5, 0), 500, 40)

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

	-- ============================================================
	-- 场景引导提示
	-- ============================================================
	createHintBoard(
		origin + Vector3.new(0, 4, 0),
		"① 蒲团上坐好——冥想回血回蓝一条龙",
		BrickColor.new("Gold")
	)
	createHintBoard(
		origin + Vector3.new(0, 2.5, 0),
		"② 戾气太重坐不住？先去干点好事再来",
		BrickColor.new("Bright orange")
	)

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
