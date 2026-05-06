-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.ChaosEventUI.client.lua
-- 功能：大闹天宫叙事选择 UI — 事件显示 + 选项 + 数值反馈
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- 等待 RemoteEvent
-- ============================================================
local function waitForEvents()
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then
		eventsFolder = ReplicatedStorage:WaitForChild("Events", 15)
	end
	if not eventsFolder then return nil end
	return eventsFolder
end

local eventsFolder = waitForEvents()
if not eventsFolder then
	warn("❌ ChaosEventUI: 未找到 Events 文件夹")
	return
end

local ChaosEvent = eventsFolder:WaitForChild("ChaosEvent", 10)
if not ChaosEvent then
	warn("❌ ChaosEventUI: 未找到 ChaosEvent RemoteEvent")
	return
end

-- ============================================================
-- 构建 UI
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ChaosEventScreen"
screenGui.Enabled = false
screenGui.Parent = playerGui

-- ---- 背景遮罩 ----
local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.6
overlay.BorderSizePixel = 0
overlay.Parent = screenGui

-- ---- 中央事件面板 ----
local panel = Instance.new("Frame")
panel.Name = "EventPanel"
panel.Size = UDim2.new(0, 420, 0, 340)
panel.Position = UDim2.new(0.5, -210, 0.5, -170)
panel.BackgroundColor3 = Color3.fromRGB(25, 20, 15)
panel.BorderSizePixel = 0
panel.BackgroundTransparency = 0.15
panel.Parent = screenGui

-- 圆角
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

-- ---- 装饰边框 ----
local border = Instance.new("Frame")
border.Name = "Border"
border.Size = UDim2.new(1, 0, 1, 0)
border.BackgroundTransparency = 1
border.BorderSizePixel = 2
border.BorderColor3 = Color3.fromRGB(180, 120, 50)
border.Parent = panel

-- ---- 标题 ----
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -40, 0, 50)
title.Position = UDim2.new(0, 20, 0, 15)
title.BackgroundTransparency = 1
title.Text = ""
title.TextColor3 = Color3.fromRGB(255, 215, 0)  -- 金色
title.Font = Enum.Font.SourceSansBold
title.TextSize = 26
title.TextXAlignment = Enum.TextXAlignment.Center
title.TextTransparency = 1
title.Parent = panel

-- ---- 描述 ----
local desc = Instance.new("TextLabel")
desc.Name = "Description"
desc.Size = UDim2.new(1, -40, 0, 90)
desc.Position = UDim2.new(0, 20, 0, 65)
desc.BackgroundTransparency = 1
desc.Text = ""
desc.TextColor3 = Color3.fromRGB(220, 210, 190)
desc.Font = Enum.Font.SourceSans
desc.TextSize = 18
desc.TextWrapped = true
desc.TextXAlignment = Enum.TextXAlignment.Center
desc.TextYAlignment = Enum.TextYAlignment.Top
desc.TextTransparency = 1
desc.Parent = panel

-- ---- 按钮容器 ----
local btnContainer = Instance.new("Frame")
btnContainer.Name = "ButtonContainer"
btnContainer.Size = UDim2.new(1, -40, 0, 140)
btnContainer.Position = UDim2.new(0, 20, 0, 170)
btnContainer.BackgroundTransparency = 1
btnContainer.Parent = panel

-- ---- 按钮生成函数 ----
local function createChoiceButton(index, text, effects)
	local btn = Instance.new("TextButton")
	btn.Name = "ChoiceBtn" .. index
	btn.Size = UDim2.new(1, 0, 0, 38)
	btn.Position = UDim2.new(0, 0, 0, (index - 1) * 44)
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(240, 235, 225)
	btn.BackgroundColor3 = Color3.fromRGB(55, 45, 35)
	btn.BackgroundTransparency = 0.3
	btn.Font = Enum.Font.SourceSansBold
	btn.TextSize = 17
	btn.TextTruncate = Enum.TextTruncate.AtEnd
	btn.BorderSizePixel = 1
	btn.BorderColor3 = Color3.fromRGB(100, 75, 40)
	btn.AutoButtonColor = false
	btn.Parent = btnContainer

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn

	-- ---- 效果提示文字（初始隐藏） ----
	local effectLabel = Instance.new("TextLabel")
	effectLabel.Name = "EffectText"
	effectLabel.Size = UDim2.new(1, -10, 0, 18)
	effectLabel.Position = UDim2.new(0, 5, 0, 38)
	effectLabel.BackgroundTransparency = 1
	effectLabel.Text = ""
	effectLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	effectLabel.Font = Enum.Font.SourceSans
	effectLabel.TextSize = 13
	effectLabel.TextXAlignment = Enum.TextXAlignment.Center
	effectLabel.Visible = false
	effectLabel.Parent = btn

	-- 存储效果数据供选择后显示
	btn:SetAttribute("Effects", effects)

	return btn
end

-- ---- 选择结果标签（选择后出现） ----
local resultLabel = Instance.new("TextLabel")
resultLabel.Name = "ResultLabel"
resultLabel.Size = UDim2.new(1, -40, 0, 30)
resultLabel.Position = UDim2.new(0, 20, 0, 315)
resultLabel.BackgroundTransparency = 1
resultLabel.Text = ""
resultLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
resultLabel.Font = Enum.Font.SourceSans
resultLabel.TextSize = 15
resultLabel.TextXAlignment = Enum.TextXAlignment.Center
resultLabel.TextTransparency = 1
resultLabel.Parent = panel

-- ---- 混沌等级标签 ----
local chaosLabel = Instance.new("TextLabel")
chaosLabel.Name = "ChaosLevel"
chaosLabel.Size = UDim2.new(1, -40, 0, 25)
chaosLabel.Position = UDim2.new(0, 20, 0, 315)
chaosLabel.BackgroundTransparency = 1
chaosLabel.Text = ""
chaosLabel.TextColor3 = Color3.fromRGB(200, 100, 50)
chaosLabel.Font = Enum.Font.SourceSans
chaosLabel.TextSize = 14
chaosLabel.TextXAlignment = Enum.TextXAlignment.Center
chaosLabel.TextTransparency = 1
chaosLabel.Parent = panel

-- ============================================================
-- 动画工具
-- ============================================================
local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function fadeIn(obj, targetTransparency)
	local tween = TweenService:Create(obj, tweenInfo, { TextTransparency = targetTransparency or 0 })
	tween:Play()
	return tween
end

local function clearButtons()
	for _, child in ipairs(btnContainer:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

-- 格式化效果文本（如 "+忠诚 +10 / -混沌 -5"）
local function formatEffects(effects)
	local parts = {}
	for _, change in ipairs(effects) do
		local fieldName = change.Field
		local delta = change.Delta
		local sign = delta >= 0 and "+" or ""
		table.insert(parts, sign .. fieldName .. " " .. tostring(delta))
	end
	return table.concat(parts, "  ")
end

-- 字段名映射（中文显示）
local FIELD_NAMES = {
	Loyalty = "忠诚",
	WukongFavor = "悟空好感",
	Chaos = "混沌",
}

local function formatEffectDeltas(deltas)
	local parts = {}
	for field, delta in pairs(deltas) do
		local name = FIELD_NAMES[field] or field
		local sign = delta >= 0 and "+" or ""
		table.insert(parts, sign .. name .. " " .. tostring(delta))
	end
	return table.concat(parts, "  ")
end

-- ============================================================
-- 显示事件面板
-- ============================================================
local buttons = {}  -- 当前显示的按钮列表
local activeEventId = nil

local function showEvent(eventData)
	screenGui.Enabled = true
	activeEventId = eventData.EventId

	-- 标题
	title.Text = eventData.Title
	fadeIn(title)

	-- 描述（延迟淡入）
	task.delay(0.3, function()
		desc.Text = eventData.Desc
		fadeIn(desc)
	end)

	-- 清除旧按钮并创建新按钮
	clearButtons()
	buttons = {}

	local choices = eventData.Choices
	for i, choice in ipairs(choices) do
		local btn = createChoiceButton(i, choice.Text, choice.Effect)
		btn.MouseButton1Click:Connect(function()
			onChoiceMade(btn, activeEventId, i, choice.Effect)
		end)
		-- 按钮鼠标悬停效果
		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(80, 65, 50) }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(55, 45, 35) }):Play()
		end)
		table.insert(buttons, {
			Button = btn,
			Effect = choice.Effect,
			Index = i,
		})
		-- 按钮淡入
		btn.BackgroundTransparency = 0.8
		TweenService:Create(btn, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0.2 + i * 0.15), {
			BackgroundTransparency = 0.3,
		}):Play()
		btn.TextTransparency = 0.8
		TweenService:Create(btn, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0.2 + i * 0.15), {
			TextTransparency = 0,
		}):Play()
	end

	-- 隐藏结果标签和混沌标签
	resultLabel.TextTransparency = 1
	chaosLabel.TextTransparency = 1
end

-- ============================================================
-- 处理选择
-- ============================================================
local function onChoiceMade(clickedBtn, eventId, choiceIndex, effectDeltas)
	-- 禁用所有按钮
	for _, entry in ipairs(buttons) do
		entry.Button.Active = false
		entry.Button.AutoButtonColor = false
	end

	-- 被点击的按钮变色
	TweenService:Create(clickedBtn, TweenInfo.new(0.3), {
		BackgroundColor3 = Color3.fromRGB(120, 90, 40),
		BorderColor3 = Color3.fromRGB(200, 160, 60),
	}):Play()

	-- 在按钮下方显示效果预览
	local effectTxt = formatEffectDeltas(effectDeltas)
	local effectLabel = clickedBtn:FindFirstChild("EffectText")
	if effectLabel then
		effectLabel.Text = effectTxt
		effectLabel.Visible = true
		TweenService:Create(effectLabel, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	end

	-- 发送选择到服务器
	ChaosEvent:FireServer(eventId, choiceIndex)
end

-- ============================================================
-- 显示选择结果（收到服务器确认）
-- ============================================================
local function showChoiceResult(resultData)
	-- 显示数值变化
	local changeText = formatEffects(resultData.Changes)
	resultLabel.Text = changeText

	-- 根据效果总值决定颜色（正/负）
	local totalDelta = 0
	for _, ch in ipairs(resultData.Changes) do
		totalDelta = totalDelta + ch.Delta
	end
	if totalDelta > 0 then
		resultLabel.TextColor3 = Color3.fromRGB(100, 200, 100)  -- 绿
	elseif totalDelta < 0 then
		resultLabel.TextColor3 = Color3.fromRGB(200, 100, 100)  -- 红
	else
		resultLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	end

	fadeIn(resultLabel)
	fadeIn(chaosLabel, 0)

	-- 2 秒后关闭
	task.delay(2, function()
		screenGui.Enabled = false
		activeEventId = nil
	end)
end

-- ============================================================
-- 显示结局
-- ============================================================
local function showEnding(endingData)
	screenGui.Enabled = true

	-- 清除事件按钮
	clearButtons()
	buttons = {}

	-- 标题
	title.Text = "【结局】" .. endingData.Title
	fadeIn(title)

	-- 描述
	task.delay(0.4, function()
		desc.Text = endingData.Desc
		desc.TextColor3 = Color3.fromRGB(255, 200, 100)
		fadeIn(desc)
	end)

	-- 隐藏混沌标签
	chaosLabel.TextTransparency = 1

	-- 显示提示
	task.delay(2, function()
		resultLabel.Text = "— 故事暂告一段落 —"
		resultLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		fadeIn(resultLabel)
	end)

	-- 不自动关闭结局画面，让玩家查看
end

-- ============================================================
-- 监听服务器事件
-- ============================================================
ChaosEvent.OnClientEvent:Connect(function(data)
	if data.Type == "Event" then
		showEvent(data)
	elseif data.Type == "ChoiceResult" then
		showChoiceResult(data)
	elseif data.Type == "Ending" then
		showEnding(data)
	elseif data.Type == "ChaosUpdate" then
		chaosLabel.Text = "混沌程度: " .. data.ChaosLevel
	elseif data.Type == "Error" then
		warn("⚠️ ChaosEvent: " .. (data.Message or "未知错误"))
	end
end)

print("📜 ChaosEventUI 已加载")
