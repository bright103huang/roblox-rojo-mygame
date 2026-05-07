-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.SceneChoiceUI.lua
-- 功能：场景选择面板 — 资源耗尽或能力提升时弹出
--       展示 5 个可选场景，点击切换
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- 获取 RemoteEvent
-- ============================================================
local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
local SceneTeleportEvent = eventsFolder and eventsFolder:WaitForChild("SceneTeleportEvent", 10)

-- ============================================================
-- 加载 SceneConfig（获取场景名称/描述）
-- ============================================================
local Config = require(ReplicatedStorage.Shared.Config)
local SceneConfig = Config.Scene or {}

-- 场景显示定义（按展示顺序）
local SCENE_ORDER = { "YiShanFang", "Alchemy", "Beast", "DanShop", "Home" }

-- ============================================================
-- 颜色常量
-- ============================================================
local COLORS = {
	Bg = Color3.fromRGB(20, 20, 30),
	Panel = Color3.fromRGB(30, 30, 45),
	Gold = Color3.fromRGB(255, 215, 0),
	Red = Color3.fromRGB(255, 60, 60),
	Green = Color3.fromRGB(80, 200, 80),
	White = Color3.new(1, 1, 1),
	Gray = Color3.fromRGB(150, 150, 150),
	CardBg = Color3.fromRGB(40, 40, 60),
	CardHover = Color3.fromRGB(55, 55, 80),
	CardDisabled = Color3.fromRGB(35, 35, 40),
	-- 场景类型颜色
	TypeWork = Color3.fromRGB(50, 80, 120),
	TypeShop = Color3.fromRGB(50, 100, 60),
	TypeHome = Color3.fromRGB(100, 85, 50),
	-- 场景状态颜色
	StatusAvailable = Color3.fromRGB(60, 180, 120),
	StatusCaution = Color3.fromRGB(220, 180, 40),
	StatusWarning = Color3.fromRGB(200, 60, 60),
}

-- ============================================================
-- UI 状态
-- ============================================================
local SceneChoiceUI = {}
local screenGui = nil
local isOpen = false
local manualBtn = nil
local transitionOverlay = nil
local transitionLabel = nil

-- ============================================================
-- 获取场景状态颜色
-- ============================================================
local function getStatusColor(status)
	if status == "available" then
		return COLORS.StatusAvailable
	elseif status == "caution" then
		return COLORS.StatusCaution
	elseif status == "warning" then
		return COLORS.StatusWarning
	end
	return COLORS.Gray
end

-- ============================================================
-- 创建场景卡片
-- @param isCurrentScene boolean 当前是否正在该场景中（禁用点击+置灰）
-- @param gateStatus { status, reason } 场景评估结果（可选）
-- ============================================================
local function createSceneCard(parent, position, size, sceneId, isCurrentScene, gateStatus)
	local cfg = SceneConfig[sceneId]
	if not cfg then
		return nil
	end

	local icon = cfg.Icon or ""
	local sceneType = cfg.SceneType or ""
	local displayName = cfg.DisplayName or sceneId
	local description = cfg.Description or ""
	local trainLabel = cfg.TrainLabel or ""
	local costDisplay = cfg.CostDisplay or ""
	local rewardDisplay = cfg.RewardDisplay or ""
	local isWork = sceneType == "Work"

	local gateStat = gateStatus and gateStatus.status or "available"
	local gateReason = gateStatus and gateStatus.reason or ""
	local statusColor = getStatusColor(gateStat)

	-- 卡片主框架
	local card = Instance.new("Frame")
	card.Name = "Card_" .. sceneId
	card.Size = size
	card.Position = position
	card.BackgroundColor3 = COLORS.CardBg
	card.BorderSizePixel = 0
	card.Parent = parent
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 10)
	cardCorner.Parent = card

	-- 状态色条（左侧竖条，根据 gateStatus 变色）
	local statusBar = Instance.new("Frame")
	statusBar.Size = UDim2.new(0, 4, 1, -8)
	statusBar.Position = UDim2.new(0, 2, 0, 4)
	statusBar.BackgroundColor3 = statusColor
	statusBar.BorderSizePixel = 0
	statusBar.Parent = card
	local statusBarCorner = Instance.new("UICorner")
	statusBarCorner.CornerRadius = UDim.new(0, 2)
	statusBarCorner.Parent = statusBar

	-- 图标 + 场景名
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -18, 0, 24)
	nameLabel.Position = UDim2.new(0, 10, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = icon .. " " .. displayName
	nameLabel.TextColor3 = COLORS.Gold
	nameLabel.TextSize = 15
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = card

	-- 状态提示文本
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, -18, 0, 16)
	statusLabel.Position = UDim2.new(0, 10, 0, 28)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = gateReason
	statusLabel.TextColor3 = statusColor
	statusLabel.TextSize = 10
	statusLabel.Font = Enum.Font.SourceSansItalic
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusLabel.Parent = card

	-- 描述
	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Desc"
	descLabel.Size = UDim2.new(1, -18, 0, isWork and 22 or 36)
	descLabel.Position = UDim2.new(0, 10, 0, 44)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = description
	descLabel.TextColor3 = COLORS.Gray
	descLabel.TextSize = 10
	descLabel.Font = Enum.Font.SourceSans
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.Parent = card

	-- 打工场景：消耗/收益信息行
	if isWork then
		local infoLabel = Instance.new("TextLabel")
		infoLabel.Name = "Info"
		infoLabel.Size = UDim2.new(1, -18, 0, 30)
		infoLabel.Position = UDim2.new(0, 10, 0, 68)
		infoLabel.BackgroundTransparency = 1
		infoLabel.Text = "训练:" .. trainLabel .. "  |  " .. costDisplay .. "\n" .. rewardDisplay
		infoLabel.TextColor3 = Color3.fromRGB(180, 200, 220)
		infoLabel.TextSize = 8
		infoLabel.Font = Enum.Font.SourceSans
		infoLabel.TextXAlignment = Enum.TextXAlignment.Left
		infoLabel.TextYAlignment = Enum.TextYAlignment.Top
		infoLabel.RichText = true
		infoLabel.Parent = card
	end

	-- 当前场景状态（置灰，不可点击）
	if isCurrentScene then
		card.BackgroundColor3 = COLORS.CardDisabled
		nameLabel.TextColor3 = COLORS.Gray
	end

	card.InputBegan:Connect(function(input)
		if isCurrentScene then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			-- 过渡动画：淡入黑屏 + 显示场景名
			local cfg = SceneConfig[sceneId]
			transitionLabel.Text = "前往 " .. (cfg and cfg.DisplayName or sceneId)
			transitionOverlay.Visible = true
			local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween = TweenService:Create(transitionOverlay, tweenInfo, { BackgroundTransparency = 0 })
			tween:Play()
			tween.Completed:Wait()

			if SceneTeleportEvent then
				SceneTeleportEvent:FireServer(sceneId)
			end
			SceneChoiceUI:Close()
		end
	end)

	-- hover 效果
	card.InputBegan:Connect(function(input)
		if isCurrentScene then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			card.BackgroundColor3 = COLORS.CardHover
		end
	end)
	card.InputEnded:Connect(function(input)
		if isCurrentScene then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			card.BackgroundColor3 = COLORS.CardBg
		end
	end)

	return card
end

-- ============================================================
-- 主 UI 创建
-- ============================================================
function SceneChoiceUI:Open(triggerData)
	if isOpen then return end
	isOpen = true

	-- 隐藏手动按钮
	if manualBtn then
		manualBtn.Visible = false
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SceneChoiceUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- 遮罩
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.7
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 0
	overlay.Parent = screenGui

	-- 请求场景门控状态
	local gatesData = nil
	local requestSceneGates = eventsFolder:FindFirstChild("RequestSceneGates")
	if requestSceneGates and requestSceneGates:IsA("RemoteFunction") then
		local success, result = pcall(function()
			return requestSceneGates:InvokeServer()
		end)
		if success and result then
			gatesData = result
		end
	end

	-- 主面板
	local panelHeight = 520
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 460, 0, panelHeight)
	panel.Position = UDim2.new(0.5, -230, 0.5, -panelHeight/2)
	panel.BackgroundColor3 = COLORS.Panel
	panel.BorderSizePixel = 0
	panel.Parent = screenGui
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = panel

	-- 标题
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.new(0, 0, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "选择打工场景"
	title.TextColor3 = COLORS.Gold
	title.TextSize = 22
	title.Font = Enum.Font.SourceSansBold
	title.Parent = panel

	-- 时辰建议行
	local timeLabel = Instance.new("TextLabel")
	timeLabel.Name = "TimeAdvice"
	timeLabel.Size = UDim2.new(0.9, 0, 0, 22)
	timeLabel.Position = UDim2.new(0.05, 0, 0, 46)
	timeLabel.BackgroundTransparency = 1
	local gameHour = triggerData and triggerData.GameHour or player:GetAttribute("GameHour") or 6
	local isNight = triggerData and triggerData.IsNight or player:GetAttribute("IsNight") or false
	local tLabel = triggerData and triggerData.TimeLabel or player:GetAttribute("TimeLabel") or ""
	if tLabel == "" then
		tLabel = isNight and "夜晚" or "白天"
	end
	timeLabel.Text = "🕐 " .. tLabel .. "  |  " .. (isNight and "🌙 夜间·适合休息冥想" or "☀ 日间·效率正常")
	timeLabel.TextColor3 = COLORS.White
	timeLabel.TextSize = 13
	timeLabel.Font = Enum.Font.SourceSans
	timeLabel.TextXAlignment = Enum.TextXAlignment.Left
	timeLabel.Parent = panel

	-- 分割线
	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(0.9, 0, 0, 1)
	divider.Position = UDim2.new(0.05, 0, 0, 72)
	divider.BackgroundColor3 = COLORS.Gray
	divider.BackgroundTransparency = 0.7
	divider.BorderSizePixel = 0
	divider.Parent = panel

	-- 场景卡片网格 (2行: 第一行3个, 第二行2个)

	-- 传送过渡遮罩（初始隐藏）
	transitionOverlay = Instance.new("Frame")
	transitionOverlay.Name = "TransitionOverlay"
	transitionOverlay.Size = UDim2.new(1, 0, 1, 0)
	transitionOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
	transitionOverlay.BackgroundTransparency = 1
	transitionOverlay.BorderSizePixel = 0
	transitionOverlay.ZIndex = 100
	transitionOverlay.Visible = false
	transitionOverlay.Parent = screenGui

	transitionLabel = Instance.new("TextLabel")
	transitionLabel.Name = "TransitionLabel"
	transitionLabel.Size = UDim2.new(1, 0, 0, 60)
	transitionLabel.Position = UDim2.new(0, 0, 0.5, -30)
	transitionLabel.BackgroundTransparency = 1
	transitionLabel.Text = ""
	transitionLabel.TextColor3 = COLORS.Gold
	transitionLabel.TextSize = 36
	transitionLabel.Font = Enum.Font.SourceSansBold
	transitionLabel.ZIndex = 101
	transitionLabel.Parent = transitionOverlay

	local cardWidth = 130
	local cardHeight = 110
	local startY = 85
	local gapX = 20
	local gapY = 15
	local row1 = { "YiShanFang", "Alchemy", "Beast" }
	local row2 = { "DanShop", "Home" }

	local currentScene = triggerData and triggerData.CurrentScene or "YiShanFang"

	-- 获取门控数据
	local currentSceneGates = gatesData and gatesData.Gates or {}
	local chainEventsStr = gatesData and gatesData.ChainEvents or triggerData and triggerData.ChainEvents or ""

	-- 第一行 (3个居中)
	local row1Width = 3 * cardWidth + 2 * gapX
	local row1StartX = (460 - row1Width) / 2

	for i, sceneId in ipairs(row1) do
		local x = row1StartX + (i - 1) * (cardWidth + gapX)
		createSceneCard(panel,
			UDim2.new(0, x, 0, startY),
			UDim2.new(0, cardWidth, 0, cardHeight),
			sceneId,
			sceneId == currentScene,
			currentSceneGates[sceneId]
		)
	end

	-- 第二行 (2个居中)
	local row2Width = 2 * cardWidth + gapX
	local row2StartX = (460 - row2Width) / 2

	for i, sceneId in ipairs(row2) do
		local x = row2StartX + (i - 1) * (cardWidth + gapX)
		createSceneCard(panel,
			UDim2.new(0, x, 0, startY + cardHeight + gapY),
			UDim2.new(0, cardWidth, 0, cardHeight),
			sceneId,
			sceneId == currentScene,
			currentSceneGates[sceneId]
		)
	end

	-- 玩家状态栏
	local statusY = startY + cardHeight * 2 + gapY * 2 + 12
	local statusBg = Instance.new("Frame")
	statusBg.Name = "StatusBar"
	statusBg.Size = UDim2.new(0.9, 0, 0, 105)
	statusBg.Position = UDim2.new(0.05, 0, 0, statusY)
	statusBg.BackgroundColor3 = COLORS.Bg
	statusBg.BorderSizePixel = 0
	statusBg.Parent = panel
	local statusCorner = Instance.new("UICorner")
	statusCorner.CornerRadius = UDim.new(0, 6)
	statusCorner.Parent = statusBg

	if triggerData then
		local stamina = triggerData.Stamina or 100
		local spirit = triggerData.Spirit or 100
		local fatigue = triggerData.Fatigue or 0
		local firePoison = triggerData.FirePoison or 0
		local malice = triggerData.Malice or 0

		local statusText = string.format("体力:%d  精神:%d  疲劳:%d  火毒:%d  戾气:%d",
			stamina, spirit, fatigue, firePoison, malice)

		local statusLabel = Instance.new("TextLabel")
		statusLabel.Name = "Stats"
		statusLabel.Size = UDim2.new(1, -10, 0, 24)
		statusLabel.Position = UDim2.new(0, 5, 0, 4)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Text = statusText
		statusLabel.TextColor3 = COLORS.White
		statusLabel.TextSize = 14
		statusLabel.Font = Enum.Font.SourceSansBold
		statusLabel.Parent = statusBg

		-- 触发原因
		if triggerData.TriggerDetail then
			local triggerLabel = Instance.new("TextLabel")
			triggerLabel.Name = "Trigger"
			triggerLabel.Size = UDim2.new(1, -10, 0, 18)
			triggerLabel.Position = UDim2.new(0, 5, 0, 26)
			triggerLabel.BackgroundTransparency = 1
			triggerLabel.Text = "触发：" .. triggerData.TriggerDetail
			triggerLabel.TextColor3 = triggerData.TriggerType == "LevelUp" and COLORS.Green or COLORS.Red
			triggerLabel.TextSize = 12
			triggerLabel.Font = Enum.Font.SourceSans
			triggerLabel.TextXAlignment = Enum.TextXAlignment.Left
			triggerLabel.Parent = statusBg
		end

		-- 链式反应状态
		local chainEvents = triggerData.ChainEvents or chainEventsStr or ""
		if chainEvents ~= ""  then
			local chainLabel = Instance.new("TextLabel")
			chainLabel.Name = "ChainEvents"
			chainLabel.Size = UDim2.new(1, -10, 0, 18)
			chainLabel.Position = UDim2.new(0, 5, 0, triggerData.TriggerDetail and 44 or 28)
			chainLabel.BackgroundTransparency = 1
			chainLabel.Text = "⚠ " .. chainEvents
			chainLabel.TextColor3 = COLORS.StatusWarning
			chainLabel.TextSize = 12
			chainLabel.Font = Enum.Font.SourceSansBold
			chainLabel.TextXAlignment = Enum.TextXAlignment.Left
			chainLabel.Parent = statusBg
		end

		-- 等级显示（从 Attribute 读取）
		local levelY = (chainEvents ~= "" or chainEventsStr ~= "") and (triggerData.TriggerDetail and 64 or 48) or (triggerData.TriggerDetail and 46 or 28)
		local agilityLv = player:GetAttribute("Agility") or 1
		local alchemyLv = player:GetAttribute("AlchemyLv") or 1
		local combatLv = player:GetAttribute("Combat") or 1
		local levelLabel = Instance.new("TextLabel")
		levelLabel.Name = "Levels"
		levelLabel.Size = UDim2.new(1, -10, 0, 18)
		levelLabel.Position = UDim2.new(0, 5, 0, levelY)
		levelLabel.BackgroundTransparency = 1
		levelLabel.Text = string.format("身法 Lv.%d  火候 Lv.%d  仙力 Lv.%d",
			agilityLv, alchemyLv, combatLv)
		levelLabel.TextColor3 = COLORS.Gold
		levelLabel.TextSize = 12
		levelLabel.Font = Enum.Font.SourceSansBold
		levelLabel.TextXAlignment = Enum.TextXAlignment.Left
		levelLabel.Parent = statusBg
	end

	-- 关闭按钮
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -36, 0, 6)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = COLORS.Gray
	closeBtn.TextSize = 18
	closeBtn.Font = Enum.Font.SourceSansBold
	closeBtn.BackgroundTransparency = 1
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = panel
	closeBtn.MouseButton1Click:Connect(function()
		SceneChoiceUI:Close()
	end)
end

-- ============================================================
-- 关闭 UI
-- ============================================================
function SceneChoiceUI:Close()
	isOpen = false
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
	transitionOverlay = nil
	transitionLabel = nil
	-- 恢复手动按钮
	if manualBtn then
		manualBtn.Visible = true
	end
end

-- ============================================================
-- 创建手动切换按钮（屏幕角落常驻）
-- ============================================================
local function createManualButton()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SceneSwitchBtnGui"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	manualBtn = Instance.new("TextButton")
	manualBtn.Name = "SceneSwitchBtn"
	manualBtn.Size = UDim2.new(0, 100, 0, 36)
	manualBtn.Position = UDim2.new(1, -110, 0, 10)
	manualBtn.Text = "切换场景"
	manualBtn.TextColor3 = COLORS.White
	manualBtn.TextSize = 14
	manualBtn.Font = Enum.Font.SourceSansBold
	manualBtn.BackgroundColor3 = COLORS.Panel
	manualBtn.BorderSizePixel = 0
	manualBtn.Parent = gui

	manualBtn.MouseButton1Click:Connect(function()
		if isOpen then return end
		-- 从 Attributes 读取当前状态
		local triggerData = {
			CurrentScene = player:GetAttribute("CurrentScene") or "YiShanFang",
			Stamina = player:GetAttribute("Stamina") or 100,
			Spirit = player:GetAttribute("Spirit") or 100,
			Fatigue = player:GetAttribute("Fatigue") or 0,
			FirePoison = player:GetAttribute("FirePoison") or 0,
			Malice = player:GetAttribute("Malice") or 0,
			TriggerType = "Manual",
			TriggerDetail = "手动切换场景",
			GameHour = player:GetAttribute("GameHour") or 6,
			IsNight = player:GetAttribute("IsNight") or false,
			TimeLabel = player:GetAttribute("TimeLabel") or "",
			ChainEvents = player:GetAttribute("ChainEvents") or "",
		}
		SceneChoiceUI:Open(triggerData)
	end)

	-- hover
	manualBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			manualBtn.BackgroundColor3 = COLORS.CardHover
		end
	end)
	manualBtn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			manualBtn.BackgroundColor3 = COLORS.Panel
		end
	end)
end

-- ============================================================
-- 初始化
-- ============================================================
task.spawn(function()
	task.wait(3)  -- 等待服务器就绪
	createManualButton()
	print("🔘 场景切换按钮已创建")
end)

return SceneChoiceUI
