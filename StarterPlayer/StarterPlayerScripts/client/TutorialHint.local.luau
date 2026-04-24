-- TutorialHint.local.luau
-- 功能：显示黑色幽默风格的新手引导，拿菜后自动消失

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 等待 UI 加载
local tutorialUI = playerGui:WaitForChild("TutorialUI")
local hintFrame = tutorialUI:WaitForChild("HintFrame")
local hintText = hintFrame:WaitForChild("HintText")

-- ===== 黑色幽默版提示词 =====
local MESSAGES = {
	[1] = "🐂 传菜员请注意：左边取仙桃，右边上菜。干得好今晚加鸡腿，干不好明晚变鸡腿。",
	[2] = "🍑 你的任务：把左边的桃子送到右边亮⭐的桌上。别问为什么，问就是仙界编制内。",
	[3] = "📦 左取右送，就这么简单。要是送错了……看见那边炼丹炉了吗？",
	[4] = "🧚 小仙您好，您今日的福报已到账：无限传菜。左边拿，右边送，卷死其他临时工。",
}

-- 随机选一条
local selectedMessage = MESSAGES[math.random(1, #MESSAGES)]
hintText.Text = selectedMessage

-- 等待 TaskEvent（增加超时和重试，避免无限等待）
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 安全获取 Events 文件夹
local function waitForEvents()
	local events = ReplicatedStorage:FindFirstChild("Events")
	if events then return events end
	
	-- 如果还没创建，等待最多 15 秒
	events = ReplicatedStorage:WaitForChild("Events", 15)
	if events then return events end
	
	-- 若超时仍未出现，反复重试
	local start = tick()
	while not events do
		task.wait(0.5)
		events = ReplicatedStorage:FindFirstChild("Events")
		if tick() - start > 30 then
			warn("❌ 超过 30 秒仍未找到 Events，请检查服务端脚本是否正常运行")
			return nil
		end
	end
	return events
end

local eventsFolder = waitForEvents()
if not eventsFolder then
	-- 如果确实找不到 Events，直接隐藏提示（不影响游戏）
	warn("⚠️ 未找到 Events，提示将在 5 秒后消失")
	task.wait(5)
	tutorialUI:Destroy()
	return
end

-- 等待 TaskEvent
local TaskEvent = eventsFolder:WaitForChild("TaskEvent", 10)
if not TaskEvent then
	warn("⚠️ 未找到 TaskEvent，提示将在 5 秒后消失")
	task.wait(5)
	tutorialUI:Destroy()
	return
end

-- 淡出函数
local function fadeOut()
	local TweenService = game:GetService("TweenService")
	local fadeInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fadeTween = TweenService:Create(hintFrame, fadeInfo, { BackgroundTransparency = 1 })
	local textFadeTween = TweenService:Create(hintText, fadeInfo, { TextTransparency = 1 })
	fadeTween:Play()
	textFadeTween:Play()
	
	task.wait(1.5)
	tutorialUI:Destroy()
end

-- 监听交付成功事件，首次成功后淡出
local connection
connection = TaskEvent.OnClientEvent:Connect(function(result)
	if result == "DropSuccess" then
		fadeOut()
		connection:Disconnect()
	end
end)

-- 备用：30 秒后自动淡出
task.wait(30)
if tutorialUI and tutorialUI.Parent then
	fadeOut()
end