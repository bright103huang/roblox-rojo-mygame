-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.StoryPlayer.local.luau
-- 功能：叙事播放器
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 不区分大小写查找
local function findChildNoCase(parent, name)
    local target = name:lower()
    for _, child in ipairs(parent:GetChildren()) do
        if child.Name:lower() == target then return child end
    end
    return nil
end

-- 加载 SceneConfig
local function loadSceneConfig()
    local shared = findChildNoCase(ReplicatedStorage, "Shared")
    if not shared then return nil end
    local configFolder = findChildNoCase(shared, "Config")
    if not configFolder then return nil end
    local module = findChildNoCase(configFolder, "SceneConfig")
    if not module or not module:IsA("ModuleScript") then return nil end
    local success, result = pcall(require, module)
    return success and result or nil
end

local SceneConfig = loadSceneConfig()
if not SceneConfig then return end

-- 等待 StoryEvent
local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
if not eventsFolder then return end
local storyEvent = eventsFolder:WaitForChild("StoryEvent", 10)
if not storyEvent then return end

-- 创建播放界面
local screenGui = Instance.new("ScreenGui", playerGui)
screenGui.Name = "StoryScreen"

local background = Instance.new("Frame", screenGui)
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.new(0, 0, 0)
background.BackgroundTransparency = 0.7
background.BorderSizePixel = 0

local textLabel = Instance.new("TextLabel", background)
textLabel.Size = UDim2.new(0.8, 0, 0, 100)
textLabel.Position = UDim2.new(0.1, 0, 0.7, 0)
textLabel.BackgroundTransparency = 1
textLabel.TextColor3 = Color3.new(1, 1, 1)
textLabel.Font = Enum.Font.SourceSansBold
textLabel.TextSize = 24
textLabel.TextWrapped = true
textLabel.TextTransparency = 1

local hintLabel = Instance.new("TextLabel", background)
hintLabel.Size = UDim2.new(1, 0, 0, 30)
hintLabel.Position = UDim2.new(0, 0, 0.85, 0)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
hintLabel.Font = Enum.Font.SourceSans
hintLabel.TextSize = 14
hintLabel.Text = "点击屏幕或按任意键继续"
hintLabel.TextTransparency = 1

-- 播放控制
local function fadeInText(text)
    textLabel.Text = text
    textLabel.TextTransparency = 1
    hintLabel.TextTransparency = 1
    local t = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(textLabel, t, { TextTransparency = 0 }):Play()
    task.wait(0.8)
    TweenService:Create(hintLabel, t, { TextTransparency = 0.5 }):Play()
end

local function playStory(scenes)
    screenGui.Enabled = true
    local idx = 1
    local function show()
        if idx > #scenes then
            local out = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            TweenService:Create(background, out, { BackgroundTransparency = 1 }):Play()
            TweenService:Create(textLabel, out, { TextTransparency = 1 }):Play()
            TweenService:Create(hintLabel, out, { TextTransparency = 1 }):Play()
            task.wait(0.5)
            screenGui:Destroy()
            return
        end
        fadeInText(scenes[idx].Text)
    end
    show()
    local function next() idx = idx + 1 show() if idx > #scenes then return true end end
    local inputConn
    inputConn = UserInputService.InputBegan:Connect(function(_, gp)
        if gp then return end
        if next() then inputConn:Disconnect() end
    end)
    local mouseClick
    mouseClick = player:GetMouse().Button1Down:Connect(function()
        if next() then mouseClick:Disconnect() end
    end)
end

storyEvent.OnClientEvent:Connect(function(sceneName)
    local cfg = SceneConfig[sceneName]
    if cfg and cfg.Scenes then playStory(cfg.Scenes) end
end)