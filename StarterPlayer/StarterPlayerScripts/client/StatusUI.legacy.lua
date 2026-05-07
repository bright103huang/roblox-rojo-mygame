-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.StatusUI.client.lua
-- 功能：状态 UI — 实时显示 5 个即时状态 + 属性等级
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- 等待 player 初始化完成（确保 Attributes 可用）
-- 带超时保护，最多等 15 秒
-- ============================================================
local function waitForAttributes()
	for _, name in ipairs({ "Stamina", "Spirit", "Fatigue", "FirePoison", "Malice" }) do
		local timeout = 60  -- 60 * 0.5s = 30s 超时保护
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
-- 创建 UI
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StatusUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- 主面板
local frame = Instance.new("Frame")
frame.Name = "StatusFrame"
frame.Size = UDim2.new(0, 200, 0, 300)
frame.Position = UDim2.new(1, -212, 0, 60)
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
title.Text = "📊 状态"
title.TextColor3 = COLORS.White
title.TextSize = 14
title.Font = Enum.Font.SourceSansBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

-- 当前场景名（右上角）
local SCENE_NAMES = {
	YiShanFang = "御膳房",
	Alchemy = "炼丹洞天",
	Beast = "妖兽战场",
	DanShop = "仙丹阁",
	Home = "家",
}
local sceneLabel = Instance.new("TextLabel")
sceneLabel.Name = "SceneName"
sceneLabel.Size = UDim2.new(0, 80, 0, 18)
sceneLabel.Position = UDim2.new(1, -85, 0, 6)
sceneLabel.BackgroundTransparency = 1
sceneLabel.Text = ""
sceneLabel.TextColor3 = COLORS.Gold
sceneLabel.TextSize = 11
sceneLabel.Font = Enum.Font.SourceSansBold
sceneLabel.TextXAlignment = Enum.TextXAlignment.Right
sceneLabel.Parent = frame

-- 状态条配置
local BAR_CONFIGS = {
	{ Key = "Stamina", Label = "体力", Color = COLORS.Stamina, DangerThreshold = nil },
	{ Key = "Spirit", Label = "精神", Color = COLORS.Spirit, DangerThreshold = nil },
	{ Key = "Fatigue", Label = "疲劳", Color = COLORS.Fatigue, DangerColor = COLORS.FatigueDanger, DangerThreshold = 80, Invert = true },
	{ Key = "FirePoison", Label = "火毒", Color = COLORS.FirePoison, DangerColor = COLORS.FirePoisonDanger, DangerThreshold = 60 },
	{ Key = "Malice", Label = "戾气", Color = COLORS.Malice, DangerColor = COLORS.MaliceDanger, DangerThreshold = 50 },
	{ Key = "Risk", Label = "妖气", Color = Color3.fromRGB(80, 200, 80),
		DangerColor = Color3.fromRGB(255, 160, 40), DangerThreshold = 30,
		CriticalColor = Color3.fromRGB(255, 50, 50), CriticalThreshold = 60,
		RampageColor = Color3.fromRGB(255, 0, 0), RampageThreshold = 80 },
}

local Y_START = 28
local ROW_HEIGHT = 30
local LABEL_WIDTH = 40
local BAR_WIDTH = 110
local BAR_HEIGHT = 14
local PCT_WIDTH = 36

local barObjects = {}

for i, cfg in ipairs(BAR_CONFIGS) do
	local yPos = Y_START + (i - 1) * ROW_HEIGHT

	-- 标签
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, LABEL_WIDTH, 0, 18)
	label.Position = UDim2.new(0, 6, 0, yPos)
	label.BackgroundTransparency = 1
	label.Text = cfg.Label
	label.TextColor3 = COLORS.White
	label.TextSize = 13
	label.Font = Enum.Font.SourceSansBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	-- 条背景
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(0, BAR_WIDTH, 0, BAR_HEIGHT)
	barBg.Position = UDim2.new(0, 48, 0, yPos + 2)
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

	-- 百分比文字
	local pctLabel = Instance.new("TextLabel")
	pctLabel.Size = UDim2.new(0, PCT_WIDTH, 0, 18)
	pctLabel.Position = UDim2.new(0, 160, 0, yPos)
	pctLabel.BackgroundTransparency = 1
	pctLabel.Text = "0"
	pctLabel.TextColor3 = COLORS.White
	pctLabel.TextSize = 12
	pctLabel.Font = Enum.Font.SourceSans
	pctLabel.TextXAlignment = Enum.TextXAlignment.Right
	pctLabel.Parent = frame

	barObjects[cfg.Key] = {
		Fill = barFill,
		PctLabel = pctLabel,
		Config = cfg,
	}
end

-- 等级显示行
local levelY = Y_START + #BAR_CONFIGS * ROW_HEIGHT + 2
local levelText = Instance.new("TextLabel")
levelText.Size = UDim2.new(1, -12, 0, 20)
levelText.Position = UDim2.new(0, 6, 0, levelY)
levelText.BackgroundTransparency = 1
levelText.Text = "身法 1  火候 1  仙力 1"
levelText.TextColor3 = COLORS.Gold
levelText.TextSize = 12
levelText.Font = Enum.Font.SourceSansBold
levelText.TextXAlignment = Enum.TextXAlignment.Left
levelText.Parent = frame

-- 风险等级文字
local riskLevelLabel = Instance.new("TextLabel")
riskLevelLabel.Name = "RiskLevel"
riskLevelLabel.Size = UDim2.new(1, -12, 0, 16)
riskLevelLabel.Position = UDim2.new(0, 6, 0, levelY + 60)
riskLevelLabel.BackgroundTransparency = 1
riskLevelLabel.Text = ""
riskLevelLabel.TextSize = 12
riskLevelLabel.Font = Enum.Font.SourceSansBold
riskLevelLabel.TextXAlignment = Enum.TextXAlignment.Left
riskLevelLabel.Parent = frame

-- 红 line 警告文字（默认隐藏）
local warningText = Instance.new("TextLabel")
warningText.Size = UDim2.new(1, -12, 0, 18)
warningText.Position = UDim2.new(0, 6, 0, levelY + 20)
warningText.BackgroundTransparency = 1
warningText.Text = ""
warningText.TextColor3 = COLORS.Red
warningText.TextSize = 11
warningText.Font = Enum.Font.SourceSansBold
warningText.TextXAlignment = Enum.TextXAlignment.Left
warningText.Parent = frame

-- 考编指数显示行
local examY = levelY + 40
local examText = Instance.new("TextLabel")
examText.Size = UDim2.new(1, -12, 0, 18)
examText.Position = UDim2.new(0, 6, 0, examY)
examText.BackgroundTransparency = 1
examText.Text = ""
examText.TextColor3 = COLORS.Gold
examText.TextSize = 11
examText.Font = Enum.Font.SourceSansBold
examText.TextXAlignment = Enum.TextXAlignment.Left
examText.Parent = frame

-- 天兵信息行
local soldierY = examY + 18
local soldierText = Instance.new("TextLabel")
soldierText.Size = UDim2.new(1, -12, 0, 18)
soldierText.Position = UDim2.new(0, 6, 0, soldierY)
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

		-- 疲劳反向显示（数值越高，条越短）
		if cfg.Invert then
			pct = 1 - pct
		end

		obj.Fill.Size = UDim2.new(pct, 0, 1, 0)

		-- 数值显示
		obj.PctLabel.Text = tostring(math.floor(value))

		-- 危险阈值颜色变化
		if key == "Risk" then
			-- Risk 特殊颜色逻辑
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
		warningText.Text = "⚠️ 警告：" .. table.concat(warnings, " | ")
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
	riskLevelLabel.Text = "☯ " .. riskLevel
	riskLevelLabel.TextColor3 = riskColor

	-- 链式反应警告
	local chainEvents = player:GetAttribute("ChainEvents") or ""
	if chainEvents ~= "" then
		warningText.Text = "⚠️ " .. chainEvents
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

	-- 考编指数计算（本地估算，精确值以服务端为准）
	local aLv = player:GetAttribute("Agility") or 1
	local alLv = player:GetAttribute("AlchemyLv") or 1
	local cLv = player:GetAttribute("Combat") or 1
	local ls = player:FindFirstChild("leaderstats")
	local gdVal = 0
	if ls then
		local gd = ls:FindFirstChild("功德")
		if gd then gdVal = gd.Value end
	end
	local examIndex = math.floor(aLv * 3 + alLv * 3 + cLv * 3 + gdVal / 10)
	local passThreshold = 60
	local minStats = 6

	if player:GetAttribute("IsRecruited") == true then
		examText.Text = "🏯 天兵在编 考编指数 " .. examIndex
		examText.TextColor3 = Color3.fromRGB(100, 200, 255)
	else
		local needs = {}
		if aLv < minStats then table.insert(needs, "身法" .. aLv .. "→" .. minStats) end
		if alLv < minStats then table.insert(needs, "火候" .. alLv .. "→" .. minStats) end
		if cLv < minStats then table.insert(needs, "仙力" .. cLv .. "→" .. minStats) end
		if gdVal < 100 then table.insert(needs, "功德" .. math.floor(gdVal) .. "→100") end

		if #needs > 0 then
			examText.Text = "📋 考编 " .. examIndex .. "/" .. passThreshold .. " 缺：" .. table.concat(needs, " ")
			examText.TextColor3 = COLORS.Gold
		else
			examText.Text = "⭐ 考编 " .. examIndex .. "/" .. passThreshold .. " 可考核！去南天门"
			examText.TextColor3 = Color3.fromRGB(80, 255, 80)
		end
	end

	-- 天兵信息
	if player:GetAttribute("IsRecruited") == true then
		local rank = player:GetAttribute("MilitaryRank") or "天兵"
		local merit = player:GetAttribute("Merit") or 0
		soldierText.Text = "⚔ " .. rank .. " | 功勋 " .. merit .. "/100"
		soldierText.Visible = true
	else
		soldierText.Visible = false
	end

end)  -- pcall
if not success then
	warn("📊 StatusUI 更新错误:", err)
end
end)  -- RenderStepped

print("📊 StatusUI 已启动")
