-- TutorialHint.local.luau
-- 功能：显示黑色幽默风格的新手引导，拿菜后自动消失

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 等待 UI 加载
local tutorialUI = playerGui:WaitForChild("TutorialUI")
local hintFrame = tutorialUI:WaitForChild("HintFrame")
local hintText = hintFrame:WaitForChild("HintText")

-- ===== 黑色幽默版提示词（可任选其一） =====
local MESSAGES = {
	[1] = "🐂 传菜员请注意：左边取仙桃，右边上菜。干得好今晚加鸡腿，干不好明晚变鸡腿。",
	[2] = "🍑 你的任务：把左边的桃子送到右边亮⭐的桌上。别问为什么，问就是仙界编制内。",
	[3] = "📦 左取右送，就这么简单。要是送错了……看见那边炼丹炉了吗？",
	[4] = "🧚 小仙您好，您今日的福报已到账：无限传菜。左边拿，右边送，卷死其他临时工。",
}

-- 随机选一条，让每次进游戏都有新鲜感
local selectedMessage = MESSAGES[math.random(1, #MESSAGES)]
hintText.Text = selectedMessage

-- 等待第一次拿菜，然后让提示淡出消失
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TaskEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("TaskEvent")

local function fadeOut()
	local TweenService = game:GetService("TweenService")
	local fadeInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fadeTween = TweenService:Create(hintFrame, fadeInfo, { BackgroundTransparency = 1 })
	local textFadeTween = TweenService:Create(hintText, fadeInfo, { TextTransparency = 1 })
	fadeTween:Play()
	textFadeTween:Play()
	
	-- 动画结束后彻底移除 UI
	task.wait(1.5)
	tutorialUI:Destroy()
end

-- 监听交付成功事件（玩家第一次完成送菜后提示消失）
-- 这样比监听拿菜更合理，因为玩家至少完成了一次正确操作
local connection
connection = TaskEvent.OnClientEvent:Connect(function(result)
	if result == "DropSuccess" then
		fadeOut()
		connection:Disconnect()
	end
end)

-- 备用：如果玩家一直不拿菜，30秒后自动淡出
task.wait(30)
if tutorialUI and tutorialUI.Parent then
	fadeOut()
end