-- ============================================================
-- 文件：ServerScriptService.Server.Systems.SceneSetup.server.lua
-- 功能：场景初始化 — 按场景分区创建交互区域 + 传送阵
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Parent.DataManager)

-- ============================================================
-- 场景坐标配置（与 SceneConfig 保持一致）
-- ============================================================
local SCENES = {
	Work =    Vector3.new(0, 3, 0),
	Alchemy = Vector3.new(1000, 3, 0),
	Beast =   Vector3.new(2000, 3, 0),
	DanShop = Vector3.new(-1000, 3, 0),
	SouthGate = Vector3.new(-2000, 3, 0),
	PeachGarden = Vector3.new(3000, 3, 50),
}

-- ============================================================
-- 工具：创建传送阵 Part
-- ============================================================
local function createTeleport(position, targetScene, label)
	local part = Instance.new("Part")
	part.Name = "TeleportTo" .. targetScene
	part.Size = Vector3.new(4, 0.5, 4)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = true
	part.BrickColor = BrickColor.new("Bright blue")
	part.Transparency = 0.2
	part.Material = Enum.Material.Neon
	part.Parent = workspace
	part:SetAttribute("TeleportTarget", targetScene)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "AreaLabel"
	billboard.Parent = part
	billboard.Adornee = part
	billboard.Size = UDim2.new(0, 200, 0, 40)
	billboard.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 200

	local label2 = Instance.new("TextLabel")
	label2.Parent = billboard
	label2.Size = UDim2.new(1, 0, 1, 0)
	label2.BackgroundTransparency = 1
	label2.Text = label or ("→ " .. targetScene)
	label2.TextColor3 = Color3.fromRGB(100, 200, 255)
	label2.TextStrokeTransparency = 0
	label2.TextStrokeColor3 = Color3.new(0, 0, 0)
	label2.TextSize = 16
	label2.Font = Enum.Font.SourceSansBold

	return part
end

-- ============================================================
-- 工具：创建交互区域 Part + 标签
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
-- 人间（传菜打工）
-- ============================================================
local function setupWorkScene()
	local origin = SCENES.Work

	-- DishArea
	createArea({
		Name = "DishArea",
		Position = origin + Vector3.new(5, 0, 0),
		Size = Vector3.new(4, 1, 4),
		Color = BrickColor.new("Bright yellow"),
		Transparency = 0.3,
		Label = "取餐处",
	})

	-- 桌子 1-6
	local tablePositions = { -20, -12, -4, 4, 12, 20 }
	for i, xOffset in ipairs(tablePositions) do
		createArea({
			Name = "TableArea",
			Position = origin + Vector3.new(xOffset, 0, 0),
			Size = Vector3.new(3, 0.5, 3),
			Color = BrickColor.new("Bright red"),
			Transparency = 0.2,
			Attrs = { TableId = i },
			Label = "桌子" .. i,
		})
	end

	-- 传送阵：右 → 炼丹
	createTeleport(origin + Vector3.new(35, 0, 0), "Alchemy", "→ 炼丹洞天")
	-- 传送阵：左 → 仙丹阁
	createTeleport(origin + Vector3.new(-35, 0, 0), "DanShop", "→ 仙丹阁")
end

-- ============================================================
-- 炼丹洞天
-- ============================================================
local function setupAlchemyScene()
	local origin = SCENES.Alchemy

	createArea({
		Name = "IngredientTable",
		Position = origin + Vector3.new(5, 0, 0),
		Size = Vector3.new(5, 1, 4),
		Color = BrickColor.new("Bright green"),
		Transparency = 0.2,
		Label = "药材台（炼丹）",
	})

	createArea({
		Name = "Furnace",
		Position = origin + Vector3.new(20, 0, 0),
		Size = Vector3.new(3, 3, 3),
		Color = BrickColor.new("Bright orange"),
		Transparency = 0.1,
		Label = "炼丹炉",
	})

	-- 传送阵：右 → 妖兽战场
	createTeleport(origin + Vector3.new(35, 0, 0), "Beast", "→ 妖兽战场")
	-- 传送阵：左 → 人间
	createTeleport(origin + Vector3.new(-5, 0, 0), "Work", "← 人间")
end

-- ============================================================
-- 妖兽战场
-- ============================================================
local function setupBeastScene()
	local origin = SCENES.Beast

	createArea({
		Name = "BeastSpawn",
		Position = origin + Vector3.new(5, 0, 0),
		Size = Vector3.new(6, 1, 6),
		Color = BrickColor.new("Really red"),
		Transparency = 0.3,
		Label = "妖兽战场",
	})

	-- 传送阵：左 → 炼丹
	createTeleport(origin + Vector3.new(-5, 0, 0), "Alchemy", "← 炼丹洞天")
end

-- ============================================================
-- 仙丹阁
-- ============================================================
local function setupShopScene()
	local origin = SCENES.DanShop

	createArea({
		Name = "DanShop",
		Position = origin + Vector3.new(5, 0, 0),
		Size = Vector3.new(4, 1, 4),
		Color = BrickColor.new("Bright violet"),
		Transparency = 0.2,
		Label = "仙丹阁",
	})

	-- 传送阵：左 → 南天门
	createTeleport(origin + Vector3.new(-35, 0, 0), "SouthGate", "→ 南天门")
	-- 传送阵：右 → 人间
	createTeleport(origin + Vector3.new(35, 0, 0), "Work", "← 人间")
end

-- ============================================================
-- 南天门（考编）
-- ============================================================
local function setupExamScene()
	local origin = SCENES.SouthGate

	createArea({
		Name = "ExamGate",
		Position = origin + Vector3.new(5, 0, 0),
		Size = Vector3.new(5, 3, 3),
		Color = BrickColor.new("Gold"),
		Transparency = 0.1,
		Label = "南天门（考编）",
	})

	-- 传送阵：右 → 仙丹阁
	createTeleport(origin + Vector3.new(35, 0, 0), "DanShop", "← 仙丹阁")
end

-- ============================================================
-- 传送触发处理
-- ============================================================
local function handleTeleport(player, targetScene)
	local data = DataManager:GetData(player)
	if not data then return end

	local spawnPos = SCENES[targetScene]
	if not spawnPos then return end

	data.CurrentScene = targetScene
	DataManager:UpdateField(player, "CurrentScene", targetScene)

	local char = player.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = CFrame.new(spawnPos + Vector3.new(0, 3, 0))
			print("🚀 " .. player.Name .. " 传送至 " .. targetScene)
		end
	end
end

-- 监听触发
workspace.ChildAdded:Connect(function(child)
	if not child:IsA("Part") then return end
	local targetAttr = child:GetAttribute("TeleportTarget")
	if not targetAttr then return end

	child.Touched:Connect(function(hit)
		local playerChar = hit.Parent
		local player = Players:GetPlayerFromCharacter(playerChar)
		if not player then
			-- 也可能是 humanoid 的根部件
			local humanoid = playerChar and playerChar:FindFirstChildOfClass("Humanoid")
			if humanoid then
				player = Players:GetPlayerFromCharacter(humanoid.Parent)
			end
		end
		if not player then return end
		if child:GetAttribute("Debounce") then return end
		child:SetAttribute("Debounce", true)
		task.delay(1.5, function()
			child:SetAttribute("Debounce", nil)
		end)
		handleTeleport(player, targetAttr)
	end)
end)

-- 已经存在的传送阵也绑定
for _, child in ipairs(workspace:GetChildren()) do
	if child:IsA("Part") and child:GetAttribute("TeleportTarget") then
		-- 重新触发 ChildAdded 不会发生，手动绑定
		coroutine.wrap(function()
			task.wait(0.1)
			local targetAttr = child:GetAttribute("TeleportTarget")
			child.Touched:Connect(function(hit)
				local playerChar = hit.Parent
				local player = Players:GetPlayerFromCharacter(playerChar)
				if not player then
					local humanoid = playerChar and playerChar:FindFirstChildOfClass("Humanoid")
					if humanoid then
						player = Players:GetPlayerFromCharacter(humanoid.Parent)
					end
				end
				if not player then return end
				if child:GetAttribute("Debounce") then return end
				child:SetAttribute("Debounce", true)
				task.delay(1.5, function()
					child:SetAttribute("Debounce", nil)
				end)
				handleTeleport(player, targetAttr)
			end)
		end)()
	end
end

-- ============================================================
-- 主初始化
-- ============================================================
task.wait(3)
setupWorkScene()
setupAlchemyScene()
setupBeastScene()
setupShopScene()
setupExamScene()
print("✅ 所有场景已初始化，传送阵已就绪")
