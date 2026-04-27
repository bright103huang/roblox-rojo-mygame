-- ============================================================
-- 文件：ServerScriptService.Server.Systems.SceneManager.server.lua
-- 功能：场景管理、出生分配、传送与叙事触发
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Parent.DataManager)

-- 不区分大小写查找
local function findChildNoCase(parent, name)
    local target = name:lower()
    for _, child in ipairs(parent:GetChildren()) do
        if child.Name:lower() == target then return child end
    end
    return nil
end

-- 创建 Events 和 RemoteEvent
local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not eventsFolder then
    eventsFolder = Instance.new("Folder")
    eventsFolder.Name = "Events"
    eventsFolder.Parent = ReplicatedStorage
end

local choiceEvent = eventsFolder:FindFirstChild("ChoiceEvent")
if not choiceEvent then
    choiceEvent = Instance.new("RemoteEvent")
    choiceEvent.Name = "ChoiceEvent"
    choiceEvent.Parent = eventsFolder
    print("✅ ChoiceEvent 已创建")
end

local storyEvent = eventsFolder:FindFirstChild("StoryEvent")
if not storyEvent then
    storyEvent = Instance.new("RemoteEvent")
    storyEvent.Name = "StoryEvent"
    storyEvent.Parent = eventsFolder
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
    if success then return result end
    return nil
end

local SceneConfig = loadSceneConfig() or {}

-- 获取场景出生坐标
local function getSceneSpawnPosition(sceneName)
    local cfg = SceneConfig[sceneName]
    return cfg and cfg.SpawnPosition or Vector3.new(0, 10, 0)
end

-- 传送
local function teleportToScene(player, sceneName)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(getSceneSpawnPosition(sceneName))
    DataManager:UpdateField(player, "CurrentScene", sceneName)
    print("🚀 传送玩家 " .. player.Name .. " 到场景：" .. sceneName)
end

-- 出生分配
local playerConnections = {}
local function onPlayerAdded(player)
    if playerConnections[player] then playerConnections[player]:Disconnect() end
    playerConnections[player] = player.CharacterAdded:Connect(function(char)
        local data = DataManager:GetData(player) or DataManager:InitPlayer(player)
        local scene = data.CurrentScene or "Work"
        local hrp = char:WaitForChild("HumanoidRootPart")
        local hum = char:WaitForChild("Humanoid")
        if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end
        hrp.CFrame = CFrame.new(getSceneSpawnPosition(scene))
        print("👣 玩家 " .. player.Name .. " 重生在场景：" .. scene)
    end)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do onPlayerAdded(player) end

-- 处理选择
choiceEvent.OnServerEvent:Connect(function(player, choice)
    if choice == "ContinueWork" then
        print(player.Name .. " 选择继续当牛马")
    elseif choice == "GoHome" then
        DataManager:UpdateField(player, "HasQuitJob", true)
        DataManager:Save(player)
        teleportToScene(player, "GoHomeStory")
        storyEvent:FireClient(player, "GoHomeStory")
    end
end)

return { TeleportToScene = teleportToScene }