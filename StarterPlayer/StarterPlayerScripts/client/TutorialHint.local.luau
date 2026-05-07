-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.TutorialHint.local.luau
-- 功能：动态创建新手引导提示，首次交付成功后淡出
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ========== 1. 动态创建 TutorialUI ==========
local tutorialUI = Instance.new("ScreenGui")
tutorialUI.Name = "TutorialUI"
tutorialUI.Parent = playerGui

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintFrame"
hintFrame.Size = UDim2.new(0, 400, 0, 80)
hintFrame.Position = UDim2.new(1, -410, 1, -90)  -- 右下角
hintFrame.BackgroundColor3 = Color3.new(0, 0, 0)
hintFrame.BackgroundTransparency = 0.3
hintFrame.BorderSizePixel = 0
hintFrame.Parent = tutorialUI

-- 圆角
local corner = Instance.new("UICorner", hintFrame)
corner.CornerRadius = UDim.new(0, 8)

local hintText = Instance.new("TextLabel")
hintText.Name = "HintText"
hintText.Size = UDim2.new(1, 0, 1, 0)
hintText.BackgroundTransparency = 1
hintText.TextColor3 = Color3.new(1, 1, 1)
hintText.TextScaled = true
hintText.Font = Enum.Font.SourceSansBold
hintText.TextStrokeTransparency = 0.5
hintText.TextStrokeColor3 = Color3.new(0, 0, 0)
hintText.Parent = hintFrame

-- ========== 2. 黑色幽默提示词 ==========
local MESSAGES = {
	[1] = "🐂 传菜员请注意：左边取仙桃，右边上菜。干得好今晚加鸡腿，干不好明晚变鸡腿。",
	[2] = "🍑 你的任务：把左边的桃子送到右边亮⭐的桌上。别问为什么，问就是仙界编制内。",
	[3] = "📦 左取右送，就这么简单。要是送错了……看见那边炼丹炉了吗？",
	[4] = "🧚 小仙您好，您今日的福报已到账：无限传菜。左边拿，右边送，卷死其他临时工。",
}
hintText.Text = MESSAGES[math.random(1, #MESSAGES)]

-- ========== 3. 等待 TaskEvent（防超时） ==========
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
	warn("⚠️ TutorialHint: Events 未找到，提示将在 5 秒后关闭")
	task.wait(5)
	tutorialUI:Destroy()
	return
end

local TaskEvent = eventsFolder:WaitForChild("TaskEvent", 10)
if not TaskEvent then
	warn("⚠️ TutorialHint: TaskEvent 未找到，提示将在 5 秒后关闭")
	task.wait(5)
	tutorialUI:Destroy()
	return
end

-- ========== 4. 淡出函数 ==========
local function fadeOut()
	local TweenService = game:GetService("TweenService")
	local fadeInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fadeTween = TweenService:Create(hintFrame, fadeInfo, { BackgroundTransparency = 1 })
	local textFade = TweenService:Create(hintText, fadeInfo, { TextTransparency = 1 })
	fadeTween:Play()
	textFade:Play()
	task.wait(1.5)
	tutorialUI:Destroy()
end

-- ========== 5. 监听首次交付成功 ==========
local connection
connection = TaskEvent.OnClientEvent:Connect(function(result)
	if result == "DropSuccess" then
		fadeOut()
		connection:Disconnect()
	end
end)

-- 备用：30 秒后自动消失
task.wait(30)
if tutorialUI and tutorialUI.Parent then
	fadeOut()
end