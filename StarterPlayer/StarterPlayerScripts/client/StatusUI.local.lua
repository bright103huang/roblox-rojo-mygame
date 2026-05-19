-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.StatusUI.local.lua
-- 功能：状态 UI — 实时显示即时状态 + 属性等级
-- 布局：左下角横版，2 行 x 3 列
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- 等待 player 初始化完成（确保 Attributes 可用）
-- ============================================================
local function waitForAttributes()
	for _, name in ipairs({ "Stamina", "Spirit", "Fatigue", "FirePoison", "Malice" }) do
		local timeout = 60
		repeat
			task.wait(0.5)
			timeout -= 1
		until player:GetAttribute(name) ~= nil or timeout <= 0
		if timeout <= 0 then
			warn("⚠️ StatusUI 等待属性超时:", name)
		end
	end
end
waitForAttributes()

-- ============================================================
-- 颜色常量
-- ============================================================
local COLORS = {
	Bg = Color3.fromRGB(15, 15, 25),
	Stamina = Color3.fromRGB(80, 200, 80),
	Spirit = Color3.fromRGB(60, 120, 255),
	Fatigue = Color3.fromRGB(255, 160, 40),
	FatigueDanger = Color3.fromRGB(255, 50, 0),
	FirePoison = Color3.fromRGB(255, 60, 60),
	FirePoisonDanger = Color3.fromRGB(255, 0, 0),
	Malice = Color3.fromRGB(180, 60, 200),
	MaliceDanger = Color3.fromRGB(220, 80, 255),
	White = Color3.new(1, 1, 1),
	Gold = Color3.fromRGB(255, 215, 0),
	Red = Color3.fromRGB(255, 50, 50),
	BarBg = Color3.fromRGB(40, 40, 40),
}

-- ============================================================
-- 创建 UI — 左下角横版布局
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StatusUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- 主面板
local frame = Instance.new("Frame")
frame.Name = "StatusFrame"
frame.Size = UDim2.new(0, 540, 0, 130)
frame.Position = UDim2.new(0, 12, 1, -142)  -- 左下角
frame.BackgroundColor3 = COLORS.Bg
frame.BackgroundTransparency = 0.35
frame.BorderSizePixel = 0
frame.Parent = screenGui
local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 8)
frameCorner.Parent = frame

-- 标题
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -12, 0, 22)
title.Position = UDim2.new(0, 6, 0, 4)
title.BackgroundTransparency = 1
title.Text = "状态"
title.TextColor3 = COLORS.White
title.TextSize = 14
title.Font = Enum.Font.SourceSansBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

-- 横版状态条布局参数
local BAR_CONFIGS = {
	{ Key = "Stamina", Label = "体力", Color = COLORS.Stamina, DangerThreshold = nil },
	{ Key = "Spirit", Label = "精神", Color = COLORS.Spirit, DangerThreshold = nil },
	{ Key = "Fatigue", Label = "疲劳", Color = COLORS.Fatigue, DangerColor = COLORS.FatigueDanger, DangerThreshold = 80 },
	{ Key = "FirePoison", Label = "火毒", Color = COLORS.FirePoison, DangerColor = COLORS.FirePoisonDanger, DangerThreshold = 60 },
	{ Key = "Malice", Label = "戾气", Color = COLORS.Malice, DangerColor = COLORS.MaliceDanger, DangerThreshold = 50 },
	{ Key = "Risk", Label = "妖气", Color = Color3.fromRGB(80, 200, 80),
		DangerColor = Color3.fromRGB(255, 160, 40), DangerThreshold = 30,
		CriticalColor = Color3.fromRGB(255, 50, 50), CriticalThreshold = 60,
		RampageColor = Color3.fromRGB(255, 0, 0), RampageThreshold = 80 },
}
local BAR_COLS = 3
local BAR_WIDTH = 105
local BAR_HEIGHT = 14
local BAR_LABEL_W = 30
local BAR_VAL_W = 28
local BAR_CELL_W = 172
local BAR_ROW1_Y = 24
local BAR_ROW2_Y = 48
local BAR_X_START = 6

local barObjects = {}

for i, cfg in ipairs(BAR_CONFIGS) do
	local row = (i - 1) // BAR_COLS   -- 0 或 1
	local col = (i - 1) % BAR_COLS    -- 0, 1, 2
	local xPos = BAR_X_START + col * BAR_CELL_W
	local yPos = row == 0 and BAR_ROW1_Y or BAR_ROW2_Y

	-- 标签
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, BAR_LABEL_W, 0, 16)
	label.Position = UDim2.new(0, xPos, 0, yPos)
	label.BackgroundTransparency = 1
	label.Text = cfg.Label
	label.TextColor3 = COLORS.White
	label.TextSize = 12
	label.Font = Enum.Font.SourceSansBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	-- 条背景
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(0, BAR_WIDTH, 0, BAR_HEIGHT)
	barBg.Position = UDim2.new(0, xPos + BAR_LABEL_W, 0, yPos + 1)
	barBg.BackgroundColor3 = COLORS.BarBg
	barBg.BorderSizePixel = 0
	barBg.Parent = frame
	local barBgCorner = Instance.new("UICorner")
	barBgCorner.CornerRadius = UDim.new(0, 4)
	barBgCorner.Parent = barBg

	-- 条填充
	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = cfg.Color
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(0, 4)
	barFillCorner.Parent = barFill

	-- 数值文字
	local pctLabel = Instance.new("TextLabel")
	pctLabel.Size = UDim2.new(0, BAR_VAL_W, 0, 16)
	pctLabel.Position = UDim2.new(0, xPos + BAR_LABEL_W + BAR_WIDTH + 2, 0, yPos)
	pctLabel.BackgroundTransparency = 1
	pctLabel.Text = "0"
	pctLabel.TextColor3 = COLORS.White
	pctLabel.TextSize = 11
	pctLabel.Font = Enum.Font.SourceSans
	pctLabel.TextXAlignment = Enum.TextXAlignment.Left
	pctLabel.Parent = frame

	barObjects[cfg.Key] = {
		Fill = barFill,
		PctLabel = pctLabel,
		Config = cfg,
	}
end

-- 文字信息行
local INFO_Y1 = 72   -- 等级 + 场景
local INFO_Y2 = 92   -- 警告 + 风险等级
local INFO_Y3 = 110  -- 晋升条件 / 天兵

-- 场景名映射
local SCENE_NAMES = {
	YiShanFang = "御膳房",
	Alchemy = "炼丹洞天",
	Beast = "妖兽战场",
	DanShop = "仙丹阁",
	Home = "家",
}

-- 等级行
local levelText = Instance.new("TextLabel")
levelText.Size = UDim2.new(1, -12, 0, 18)
levelText.Position = UDim2.new(0, 6, 0, INFO_Y1)
levelText.BackgroundTransparency = 1
levelText.Text = "身法 1  火候 1  仙力 1"
levelText.TextColor3 = COLORS.Gold
levelText.TextSize = 12
levelText.Font = Enum.Font.SourceSansBold
levelText.TextXAlignment = Enum.TextXAlignment.Left
levelText.Parent = frame

-- 场景名
local sceneLabel = Instance.new("TextLabel")
sceneLabel.Name = "SceneName"
sceneLabel.Size = UDim2.new(0, 100, 0, 18)
sceneLabel.Position = UDim2.new(1, -105, 0, INFO_Y1)
sceneLabel.BackgroundTransparency = 1
sceneLabel.Text = ""
sceneLabel.TextColor3 = COLORS.Gold
sceneLabel.TextSize = 11
sceneLabel.Font = Enum.Font.SourceSansBold
sceneLabel.TextXAlignment = Enum.TextXAlignment.Right
sceneLabel.Parent = frame

-- 警告文字行
local warningText = Instance.new("TextLabel")
warningText.Size = UDim2.new(0.7, -6, 0, 18)
warningText.Position = UDim2.new(0, 6, 0, INFO_Y2)
warningText.BackgroundTransparency = 1
warningText.Text = ""
warningText.TextColor3 = COLORS.Red
warningText.TextSize = 11
warningText.Font = Enum.Font.SourceSansBold
warningText.TextXAlignment = Enum.TextXAlignment.Left
warningText.Parent = frame

-- 风险等级文字
local riskLevelLabel = Instance.new("TextLabel")
riskLevelLabel.Name = "RiskLevel"
riskLevelLabel.Size = UDim2.new(0.3, -6, 0, 18)
riskLevelLabel.Position = UDim2.new(0.7, 6, 0, INFO_Y2)
riskLevelLabel.BackgroundTransparency = 1
riskLevelLabel.Text = ""
riskLevelLabel.TextSize = 11
riskLevelLabel.Font = Enum.Font.SourceSansBold
riskLevelLabel.TextXAlignment = Enum.TextXAlignment.Right
riskLevelLabel.Parent = frame

-- 晋升条件行
local examText = Instance.new("TextLabel")
examText.Size = UDim2.new(0.6, -6, 0, 18)
examText.Position = UDim2.new(0, 6, 0, INFO_Y3)
examText.BackgroundTransparency = 1
examText.Text = ""
examText.TextColor3 = COLORS.Gold
examText.TextSize = 11
examText.Font = Enum.Font.SourceSansBold
examText.TextXAlignment = Enum.TextXAlignment.Left
examText.Parent = frame

-- 天兵信息行
local soldierText = Instance.new("TextLabel")
soldierText.Size = UDim2.new(0.4, -6, 0, 18)
soldierText.Position = UDim2.new(0.6, 6, 0, INFO_Y3)
soldierText.BackgroundTransparency = 1
soldierText.Text = ""
soldierText.TextColor3 = Color3.fromRGB(100, 200, 255)
soldierText.TextSize = 11
soldierText.Font = Enum.Font.SourceSansBold
soldierText.TextXAlignment = Enum.TextXAlignment.Left
soldierText.Parent = frame

-- ============================================================
-- 更新循环（3 Hz 轮询 Attributes）
-- ============================================================
local lastUpdate = 0

RunService.RenderStepped:Connect(function()
	local success, err = pcall(function()
		local now = tick()
		if now - lastUpdate < 0.3 then return end
		lastUpdate = now

	local warnings = {}

	for key, obj in pairs(barObjects) do
		local cfg = obj.Config
		local value = player:GetAttribute(cfg.Key) or 0
		local maxVal = 100
		local pct = math.clamp(value / maxVal, 0, 1)

		-- 疲劳反向显示
		if cfg.Invert then
			pct = 1 - pct
		end

		obj.Fill.Size = UDim2.new(pct, 0, 1, 0)
		obj.PctLabel.Text = tostring(math.floor(value))

		-- 危险阈值颜色变化
		if key == "Risk" then
			if value >= 80 then
				obj.Fill.BackgroundColor3 = cfg.RampageColor or Color3.fromRGB(255, 0, 0)
			elseif value >= 60 then
				obj.Fill.BackgroundColor3 = cfg.CriticalColor or Color3.fromRGB(255, 50, 50)
			elseif value >= 30 then
				obj.Fill.BackgroundColor3 = cfg.DangerColor or Color3.fromRGB(255, 160, 40)
			else
				obj.Fill.BackgroundColor3 = cfg.Color
			end
		elseif cfg.DangerThreshold and value > cfg.DangerThreshold then
			obj.Fill.BackgroundColor3 = cfg.DangerColor or cfg.Color
			table.insert(warnings, cfg.Label .. " " .. math.floor(value))
		else
			obj.Fill.BackgroundColor3 = cfg.Color
		end
	end

	-- 更新等级
	local agility = player:GetAttribute("Agility") or 1
	local alchemyLv = player:GetAttribute("AlchemyLv") or 1
	local combat = player:GetAttribute("Combat") or 1
	levelText.Text = "身法 " .. tostring(agility)
		.. "  火候 " .. tostring(alchemyLv)
		.. "  仙力 " .. tostring(combat)

	-- 更新当前场景名
	local curSceneId = player:GetAttribute("CurrentScene") or ""
	sceneLabel.Text = SCENE_NAMES[curSceneId] or curSceneId

	-- 警告文字
	if #warnings > 0 then
		warningText.Text = "警告：" .. table.concat(warnings, " | ")
	else
		warningText.Text = ""
	end

	-- 更新风险等级文字
	local riskVal = player:GetAttribute("Risk") or 0
	local riskLevel, riskColor
	if riskVal >= 80 then
		riskLevel, riskColor = "大凶之兆", Color3.fromRGB(255, 50, 50)
	elseif riskVal >= 60 then
		riskLevel, riskColor = "危机四伏", Color3.fromRGB(255, 160, 40)
	elseif riskVal >= 30 then
		riskLevel, riskColor = "妖气隐现", Color3.fromRGB(200, 200, 80)
	else
		riskLevel, riskColor = "风平浪静", Color3.fromRGB(80, 200, 80)
	end
	riskLevelLabel.Text = riskLevel
	riskLevelLabel.TextColor3 = riskColor

	-- 链式反应警告
	local chainEvents = player:GetAttribute("ChainEvents") or ""
	if chainEvents ~= "" then
		warningText.Text = chainEvents
		warningText.TextColor3 = Color3.fromRGB(255, 100, 0)
	end

	-- 戾气 > 50 时脉冲特效
	local malice = player:GetAttribute("Malice") or 0
	if malice > 50 then
		local pulse = 0.5 + math.sin(now * 3) * 0.3
		local maliceObj = barObjects["Malice"]
		if maliceObj then
			maliceObj.Fill.BackgroundColor3 = Color3.fromRGB(
				180 + math.floor(pulse * 40),
				40 + math.floor(pulse * 20),
				200 + math.floor(pulse * 55)
			)
		end
	end

	-- 晋升条件显示
	local aLv = player:GetAttribute("Agility") or 1
	local alLv = player:GetAttribute("AlchemyLv") or 1
	local cLv = player:GetAttribute("Combat") or 1
	local ls = player:FindFirstChild("leaderstats")
	local gdVal = 0
	if ls then
		local gd = ls:FindFirstChild("功德")
		if gd then gdVal = gd.Value end
	end
	local minStats = 6

	if player:GetAttribute("IsRecruited") == true then
		examText.Text = "已晋升天兵 ✓"
		examText.TextColor3 = Color3.fromRGB(80, 255, 80)
	else
		local items = {
			"身法" .. aLv .. "/" .. minStats,
			"火候" .. alLv .. "/" .. minStats,
			"仙力" .. cLv .. "/" .. minStats,
			"功德" .. math.floor(gdVal) .. "/100",
		}
		examText.Text = "晋升条件 " .. table.concat(items, " ")
		examText.TextColor3 = COLORS.Gold
	end

	-- 天兵信息
	if player:GetAttribute("IsRecruited") == true then
		local rank = player:GetAttribute("MilitaryRank") or "天兵"
		local merit = player:GetAttribute("Merit") or 0
		soldierText.Text = rank .. " | 功勋 " .. merit .. "/100"
		soldierText.Visible = true
	else
		soldierText.Visible = false
	end

end)  -- pcall
if not success then
	warn("StatusUI 更新错误:", err)
end
end)  -- RenderStepped

print("StatusUI 已启动")
