return nil
-- 已废弃：引导提示牌已改用 SceneSetup 中的 createHintBoard 3D 漂浮牌

-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.TutorialHint.local.luau
-- 功能：场景感知新手引导提示，首次完成场景目标后淡出
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

-- ========== 2. 场景感知提示词 ==========
local SCENE_HINTS = {
	YiShanFang = {
		"🐂 传菜员请注意：左边取仙桃，右边上菜。干得好今晚加鸡腿，干不好明晚变鸡腿。",
		"🍑 你的任务：把左边的桃子送到右边亮⭐的桌上。别问为什么，问就是仙界编制内。",
		"📦 左取右送，就这么简单。要是送错了……看见那边炼丹炉了吗？",
		"🧚 小仙您好，您今日的福报已到账：无限传菜。左边拿，右边送，卷死其他临时工。",
	},
	Beast = {
		"🏟️ 踏入角斗场中央红区→妖兽从右侧铁门冲出，三次碰撞定胜负！",
		"⚔️ 走到妖兽面前→自动冲锋碰撞！连撞三次后结算输赢。",
		"💪 仙力越强胜率越高！每次胜利获得仙力经验和仙晶。",
		"😈 小心！20%概率碰到更强的妖兽，打不过会受伤扣体力。",
		"🔄 打不过就跑远点，妖兽会自动消失，下次再来！",
	},
}

-- 获取当前场景的随机提示
local function getHintForScene(scene)
	local hints = SCENE_HINTS[scene] or SCENE_HINTS.YiShanFang
	return hints[math.random(1, #hints)]
end

-- 监听场景变化切换提示
local function onSceneChanged()
	local scene = player:GetAttribute("CurrentScene") or "YiShanFang"
	hintText.Text = getHintForScene(scene)
end

-- 初始设置
onSceneChanged()
player:GetAttributeChangedSignal("CurrentScene"):Connect(onSceneChanged)

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

-- ========== 5. 场景感知首次完成监听 ==========
local connection
connection = TaskEvent.OnClientEvent:Connect(function(result, extraData)
	local scene = player:GetAttribute("CurrentScene")

	if scene == "YiShanFang" and result == "DropSuccess" then
		fadeOut()
		connection:Disconnect()
	elseif scene == "Beast" and result == "BeastVictory" then
		fadeOut()
		connection:Disconnect()
	end
end)

-- 备用：30 秒后自动消失
task.wait(30)
if tutorialUI and tutorialUI.Parent then
	fadeOut()
end
