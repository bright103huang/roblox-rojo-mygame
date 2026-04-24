-- ============================================================
-- 文件：ServerScriptService.Server.Systems.SceneManager.server.lua
-- 功能：根据存档决定玩家出生场景 + 接收选择事件传送
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 加载 DataManager（现在它已经是 ModuleScript）
local DataManager = require(script.Parent.DataManager)

-- ============================================================
-- 场景起点坐标（根据你的实际布局调整）
-- ============================================================
local SCENE_START_POSITIONS = {
	Work = Vector3.new(0, 10, 0),		-- 工作区起点
	HomeStory = Vector3.new(5000, 3, 2),	-- 回家故事区起点（请按你摆的床旁位置修改）
}

-- ============================================================
-- 传送函数
-- ============================================================
local function teleportToScene(player, sceneName)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local targetPos = SCENE_START_POSITIONS[sceneName]
	if not targetPos then
		warn("未知场景名：" .. sceneName)
		return
	end

	-- 强制设置角色位置
	hrp.CFrame = CFrame.new(targetPos)
	DataManager:UpdateField(player, "CurrentScene", sceneName)
	print("🚀 传送玩家 " .. player.Name .. " 到场景：" .. sceneName)
end

-- ============================================================
-- 玩家出生时的场景分配
-- ============================================================
local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(char)
		local data = DataManager:GetData(player)
		if not data then
			data = DataManager:InitPlayer(player)
		end
		local scene = data.CurrentScene or "Work"
		-- 稍等一秒确保 HumanoidRootPart 完全就位
		task.wait(0.5)
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local pos = SCENE_START_POSITIONS[scene] or SCENE_START_POSITIONS.Work
			hrp.CFrame = CFrame.new(pos)
			print("👣 玩家 " .. player.Name .. " 重生在场景：" .. scene)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- 确保已在线玩家也能生效（Studio 测试常见场景）
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- ============================================================
-- 创建 Events 文件夹及相关 RemoteEvent（防等待卡死）
-- ============================================================
local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not eventsFolder then
	eventsFolder = Instance.new("Folder")
	eventsFolder.Name = "Events"
	eventsFolder.Parent = ReplicatedStorage
end

-- ChoiceEvent：接收客户端的选择
local choiceEvent = eventsFolder:FindFirstChild("ChoiceEvent")
if not choiceEvent then
	choiceEvent = Instance.new("RemoteEvent")
	choiceEvent.Name = "ChoiceEvent"
	choiceEvent.Parent = eventsFolder
end

-- StoryEvent：向客户端推送故事数据（可留空，后续使用）
local storyEvent = eventsFolder:FindFirstChild("StoryEvent")
if not storyEvent then
	storyEvent = Instance.new("RemoteEvent")
	storyEvent.Name = "StoryEvent"
	storyEvent.Parent = eventsFolder
end

-- ============================================================
-- 处理选择
-- ============================================================
choiceEvent.OnServerEvent:Connect(function(player, choice)
	if choice == "ContinueWork" then
		print(player.Name .. " 选择继续当牛马")
		-- 不传送，继续当前场景
	elseif choice == "GoHome" then
		-- 更新状态、保存、传送
		DataManager:UpdateField(player, "HasQuitJob", true)
		DataManager:Save(player)		-- 关键节点存档
		teleportToScene(player, "HomeStory")

		-- 触发叙事事件（发送故事数据给客户端）
		local storyData = {
			{ ImageId = "rbxassetid://6035084653", Text = "你拖着疲惫的身子离开后厨..." },
			{ ImageId = "rbxassetid://1234567890", Text = "路旁一个蟠桃核闪闪发光，像是刚被谁啃过..." },
			{ ImageId = "rbxassetid://9876543210", Text = "你只是个南天门的小仙，趁着混乱赶紧溜回家躺平..." },
		}
		storyEvent:FireClient(player, storyData)
	end
end)

-- 公开传送函数，方便其他脚本调用
return {
	TeleportToScene = teleportToScene,
}