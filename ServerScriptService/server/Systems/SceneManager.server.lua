-- ============================================================
-- 文件：ServerScriptService.Server.Systems.SceneManager.server.lua
-- 功能：场景管理、出生分配、远程传送
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Parent.DataManager)
local SpeedCalculator = require(script.Parent.SpeedCalculator)

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

-- 场景传送 RemoteEvent
local sceneTeleportEvent = eventsFolder:FindFirstChild("SceneTeleportEvent")
if not sceneTeleportEvent then
	sceneTeleportEvent = Instance.new("RemoteEvent")
	sceneTeleportEvent.Name = "SceneTeleportEvent"
	sceneTeleportEvent.Parent = eventsFolder
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

-- ============================================================
-- 公开传送函数（供 TaskService / 外部调用）
-- ============================================================
local function teleportToScene(player, sceneName)
	if not SceneConfig[sceneName] then
		warn("⚠️ 场景不存在: " .. tostring(sceneName))
		return false
	end

	local char = player.Character
	if not char then return false end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	hrp.CFrame = CFrame.new(getSceneSpawnPosition(sceneName))
	hrp.Velocity = Vector3.new(0, 0, 0)
	hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	DataManager:UpdateField(player, "CurrentScene", sceneName)


	print("🚀 传送玩家 " .. player.Name .. " 到场景：" .. sceneName)
	return true
end

-- ============================================================
-- 场景传送 RemoteEvent 监听
-- ============================================================
sceneTeleportEvent.OnServerEvent:Connect(function(player, sceneName)
	if type(sceneName) ~= "string" then return end
	local ok = teleportToScene(player, sceneName)
	if not ok then return end
	local taskEvent = eventsFolder:FindFirstChild("TaskEvent")
	if taskEvent then
		taskEvent:FireClient(player, "SceneSwitched:" .. sceneName)
	end
end)

-- ============================================================
-- 出生分配
-- ============================================================
local playerConnections = {}
local function onPlayerAdded(player)
	if playerConnections[player] then playerConnections[player]:Disconnect() end
	playerConnections[player] = player.CharacterAdded:Connect(function(char)
		local data = DataManager:GetData(player) or DataManager:InitPlayer(player)
		local scene = data.CurrentScene or "YiShanFang"

		local hrp = char:WaitForChild("HumanoidRootPart")
		local hum = char:WaitForChild("Humanoid")
		if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end
		hrp.CFrame = CFrame.new(getSceneSpawnPosition(scene))

		-- 同步属性到 Attributes
		player:SetAttribute("IsRecruited", data.IsRecruited or false)
		player:SetAttribute("MilitaryRank", data.MilitaryRank or "天兵")
		player:SetAttribute("Merit", data.Merit or 0)
		-- 同步即时状态
		player:SetAttribute("Stamina", data.Stamina or 100)
		player:SetAttribute("Spirit", data.Spirit or 100)
		player:SetAttribute("Fatigue", data.Fatigue or 0)
		player:SetAttribute("FirePoison", data.FirePoison or 0)
		player:SetAttribute("Malice", data.Malice or 0)

		-- 同步永久属性等级
		player:SetAttribute("Agility", data.Agility or 1)
		player:SetAttribute("AlchemyLv", data.AlchemyLv or 1)
		player:SetAttribute("Combat", data.Combat or 1)

		-- 同步当前场景
		player:SetAttribute("CurrentScene", data.CurrentScene or "YiShanFang")

		-- 应用动态速度
		SpeedCalculator.Apply(player)
		print("👣 玩家 " .. player.Name .. " 重生在场景：" .. scene)
	end)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do onPlayerAdded(player) end

print("✅ SceneManager 已启动（场景传送事件已注册）")

return { TeleportToScene = teleportToScene }
