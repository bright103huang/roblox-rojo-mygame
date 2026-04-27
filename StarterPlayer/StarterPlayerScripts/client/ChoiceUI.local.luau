-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.ChoiceUI.local.luau
-- 功能：当仙晶≥60时显示“继续当牛马”或“下班回家躺平”选择
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- 安全等待 Events 和 ChoiceEvent（防止无限等待）
-- ============================================================
local function waitForEvents()
	local events = ReplicatedStorage:FindFirstChild("Events")
	if events then return events end
	events = ReplicatedStorage:WaitForChild("Events", 15)
	if events then return events end
	local start = tick()
	while not events do
		task.wait(0.5)
		events = ReplicatedStorage:FindFirstChild("Events")
		if tick() - start > 15 then return nil end
	end
	return events
end

local eventsFolder = waitForEvents()
if not eventsFolder then
	warn("❌ ChoiceUI：未找到 Events 文件夹，已退出")
	return
end

local ChoiceEvent = eventsFolder:WaitForChild("ChoiceEvent", 10)
if not ChoiceEvent then
	warn("❌ ChoiceUI：未找到 ChoiceEvent，已退出")
	return
end

-- ============================================================
-- 动态创建选择界面
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ChoiceScreen"
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "ChoiceFrame"
frame.Size = UDim2.new(0, 300, 0, 200)
frame.Position = UDim2.new(0.5, -150, 0.5, -100)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = screenGui

local corner = Instance.new("UICorner", frame)
corner.CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 40)
title.Position = UDim2.new(0, 0, 0, 20)
title.BackgroundTransparency = 1
title.Text = "你已经赚够60仙晶！"
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 20
title.Parent = frame

-- 继续工作按钮
local continueBtn = Instance.new("TextButton")
continueBtn.Name = "ContinueBtn"
continueBtn.Size = UDim2.new(0, 220, 0, 45)
continueBtn.Position = UDim2.new(0.5, -110, 0, 80)
continueBtn.Text = "继续当牛马💪"
continueBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
continueBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
continueBtn.Font = Enum.Font.SourceSansBold
continueBtn.TextSize = 18
continueBtn.Parent = frame

local continueCorner = Instance.new("UICorner", continueBtn)
continueCorner.CornerRadius = UDim.new(0, 8)

-- 回家躺平按钮
local quitBtn = Instance.new("TextButton")
quitBtn.Name = "QuitBtn"
quitBtn.Size = UDim2.new(0, 220, 0, 45)
quitBtn.Position = UDim2.new(0.5, -110, 0, 135)
quitBtn.Text = "下班回家躺平🛌"
quitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
quitBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
quitBtn.Font = Enum.Font.SourceSansBold
quitBtn.TextSize = 18
quitBtn.Parent = frame

local quitCorner = Instance.new("UICorner", quitBtn)
quitCorner.CornerRadius = UDim.new(0, 8)

-- ============================================================
-- 监听仙晶变化，达到 60 时显示
-- ============================================================
local leaderstats = player:WaitForChild("leaderstats")
local gold = leaderstats:WaitForChild("仙晶")

local function onGoldChanged()
	if gold.Value >= 60 then
		frame.Visible = true
	else
		frame.Visible = false
	end
end

gold:GetPropertyChangedSignal("Value"):Connect(onGoldChanged)
onGoldChanged()

-- ============================================================
-- 按钮事件
-- ============================================================
continueBtn.MouseButton1Click:Connect(function()
	frame.Visible = false
	ChoiceEvent:FireServer("ContinueWork")
end)

quitBtn.MouseButton1Click:Connect(function()
	frame.Visible = false
	ChoiceEvent:FireServer("GoHome")
end)