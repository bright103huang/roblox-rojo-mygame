-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.SceneChoiceUI.lua
-- 功能：场景选择面板 — 资源耗尽或能力提升时弹出
--       展示 5 个可选场景，点击切换
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
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
}

-- ============================================================
-- UI 状态
-- ============================================================
local SceneChoiceUI = {}
local screenGui = nil
local isOpen = false
local manualBtn = nil

-- ============================================================
-- 创建场景卡片
-- @param isCurrentScene boolean 当前是否正在该场景中（禁用点击+置灰）
-- ============================================================
local function createSceneCard(parent, position, size, sceneId, isCurrentScene)
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

	-- 场景类型色条（顶部细线装饰）
	if sceneType == "Work" then
		local accent = Instance.new("Frame")
		accent.Size = UDim2.new(1, -4, 0, 3)
		accent.Position = UDim2.new(0, 2, 0, 2)
		accent.BackgroundColor3 = COLORS.TypeWork
		accent.BorderSizePixel = 0
		accent.Parent = card
		local accentCorner = Instance.new("UICorner")
		accentCorner.CornerRadius = UDim.new(0, 3)
		accentCorner.Parent = accent
	end

	-- 图标 + 场景名
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -10, 0, 24)
	nameLabel.Position = UDim2.new(0, 5, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = icon .. " " .. displayName
	nameLabel.TextColor3 = COLORS.Gold
	nameLabel.TextSize = 16
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = card

	-- 描述
	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Desc"
	descLabel.Size = UDim2.new(1, -10, 0, isWork and 26 or 42)
	descLabel.Position = UDim2.new(0, 5, 0, 34)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = description
	descLabel.TextColor3 = COLORS.Gray
	descLabel.TextSize = 11
	descLabel.Font = Enum.Font.SourceSans
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.Parent = card

	-- 打工场景：消耗/收益信息行
	if isWork then
		local infoLabel = Instance.new("TextLabel")
		infoLabel.Name = "Info"
		infoLabel.Size = UDim2.new(1, -10, 0, 36)
		infoLabel.Position = UDim2.new(0, 5, 0, 62)
		infoLabel.BackgroundTransparency = 1
		infoLabel.Text = "训练:" .. trainLabel .. "  |  " .. costDisplay .. "\n" .. rewardDisplay
		infoLabel.TextColor3 = Color3.fromRGB(180, 200, 220)
		infoLabel.TextSize = 9
		infoLabel.Font = Enum.Font.SourceSans
		infoLabel.TextXAlignment = Enum.TextXAlignment.Left
		infoLabel.TextYAlignment = Enum.TextYAlignment.Top
		infoLabel.RichText = true
		infoLabel.Parent = card
	end

	-- 点击 / 当前场景状态
	if isCurrentScene then
		card.BackgroundColor3 = COLORS.CardDisabled
		nameLabel.TextColor3 = COLORS.Gray
	end

	card.InputBegan:Connect(function(input)
		if isCurrentScene then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
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

	-- 主面板
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 460, 0, 440)
	panel.Position = UDim2.new(0.5, -230, 0.5, -220)
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

	-- 分割线
	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(0.9, 0, 0, 1)
	divider.Position = UDim2.new(0.05, 0, 0, 50)
	divider.BackgroundColor3 = COLORS.Gray
	divider.BackgroundTransparency = 0.7
	divider.BorderSizePixel = 0
	divider.Parent = panel

	-- 场景卡片网格 (2行: 第一行3个, 第二行2个)
	local cardWidth = 130
	local cardHeight = 110
	local startY = 65
	local gapX = 20
	local gapY = 15
	local row1 = { "YiShanFang", "Alchemy", "Beast" }
	local row2 = { "DanShop", "Home" }

	local currentScene = triggerData and triggerData.CurrentScene or "YiShanFang"

	-- 第一行 (3个居中)
	local row1Width = 3 * cardWidth + 2 * gapX
	local row1StartX = (460 - row1Width) / 2

	for i, sceneId in ipairs(row1) do
		local x = row1StartX + (i - 1) * (cardWidth + gapX)
		createSceneCard(panel,
			UDim2.new(0, x, 0, startY),
			UDim2.new(0, cardWidth, 0, cardHeight),
			sceneId,
			sceneId == currentScene
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
			sceneId == currentScene
		)
	end

	-- 玩家状态栏
	local statusY = startY + cardHeight * 2 + gapY * 2 + 10
	local statusBg = Instance.new("Frame")
	statusBg.Name = "StatusBar"
	statusBg.Size = UDim2.new(0.9, 0, 0, 75)
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

		-- 等级显示（从 Attribute 读取）
		local levelY = triggerData.TriggerDetail and 46 or 28
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
