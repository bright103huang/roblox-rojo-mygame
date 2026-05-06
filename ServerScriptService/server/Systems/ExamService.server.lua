-- ============================================================
-- 文件：ServerScriptService.Server.Systems.ExamService.server.lua
-- 功能：考编系统 — 考核流程管理（指数计算、门槛检查、晋升处理）
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(script.Parent.DataManager)
local ExamConfig = require(ReplicatedStorage.Shared.Config.ExamConfig)
local SceneConfig = require(ReplicatedStorage.Shared.Config.SceneConfig)

-- ============================================================
-- 确保 Events 文件夹和 RemoteEvent 存在
-- ============================================================
local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not eventsFolder then
	eventsFolder = Instance.new("Folder")
	eventsFolder.Name = "Events"
	eventsFolder.Parent = ReplicatedStorage
end

-- ExamRemote：客户端与服务端之间的考核通信
local examRemote = eventsFolder:FindFirstChild("ExamRemote")
if not examRemote then
	examRemote = Instance.new("RemoteEvent")
	examRemote.Name = "ExamRemote"
	examRemote.Parent = eventsFolder
	print("✅ ExamRemote 已创建")
end

-- StoryEvent：触发叙事 UI（由 SceneManager 或客户端 StoryViewer 消费）
local storyEvent = eventsFolder:FindFirstChild("StoryEvent")

local ExamService = {}

-- ============================================================
-- 计算考编指数
-- 公式：身法*3 + 火候*3 + 仙力*3 + 功德/10
-- ============================================================
function ExamService.CalculateIndex(player)
	local data = DataManager:GetData(player)
	if not data then return 0 end

	local agility = data.Agility or 1
	local alchemy = data.AlchemyLv or 1
	local combat = data.Combat or 1
	local gongDe = data.GongDe or 0

	local index = agility * ExamConfig.IndexWeights.Agility
		+ alchemy * ExamConfig.IndexWeights.Alchemy
		+ combat * ExamConfig.IndexWeights.Combat
		+ gongDe * ExamConfig.IndexWeights.GongDe

	return math.floor(index)
end

-- ============================================================
-- 检查硬性门槛
-- 返回：eligible (boolean), reason (string)
-- ============================================================
function ExamService.CheckEligibility(player)
	local data = DataManager:GetData(player)
	if not data then return false, "数据未加载" end

	local missing = {}

	local agility = data.Agility or 1
	if agility < ExamConfig.MinAgility then
		table.insert(missing, "身法不足（需要 " .. ExamConfig.MinAgility .. " 级，当前 " .. agility .. " 级）")
	end

	local alchemy = data.AlchemyLv or 1
	if alchemy < ExamConfig.MinAlchemy then
		table.insert(missing, "火候不足（需要 " .. ExamConfig.MinAlchemy .. " 级，当前 " .. alchemy .. " 级）")
	end

	local combat = data.Combat or 1
	if combat < ExamConfig.MinCombat then
		table.insert(missing, "仙力不足（需要 " .. ExamConfig.MinCombat .. " 级，当前 " .. combat .. " 级）")
	end

	local gongDe = data.GongDe or 0
	if gongDe < ExamConfig.MinGongDe then
		table.insert(missing, "功德不足（需要 " .. ExamConfig.MinGongDe .. "，当前 " .. gongDe .. "）")
	end

	if #missing > 0 then
		return false, "考核条件不足：\n" .. table.concat(missing, "\n")
	end

	return true, "满足所有条件"
end

-- ============================================================
-- 内部传送
-- ============================================================
local function teleportToPosition(player, position, sceneName)
	local char = player.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = CFrame.new(position)
		end
	end
	DataManager:UpdateField(player, "CurrentScene", sceneName)
	print("🚀 传送玩家 " .. player.Name .. " 到场景：" .. sceneName)
end

-- ============================================================
-- 开始考核
-- 1. 检查硬性门槛 → 不满足则通知客户端
-- 2. 传送至南天门
-- 3. 触发考核叙事（StoryEvent）
-- ============================================================
function ExamService.StartExam(player)
	-- 已入职则跳过
	if ExamService.GetRecruitStatus(player) then
		examRemote:FireClient(player, "ExamFailed", "你已是天兵在编，无需再次考核")
		return false
	end

	local eligible, reason = ExamService.CheckEligibility(player)
	if not eligible then
		examRemote:FireClient(player, "ExamFailed", reason)
		return false, reason
	end

	-- 计算当前指数并通知客户端
	local index = ExamService.CalculateIndex(player)
	local threshold = ExamConfig.PassThreshold

	-- 传送至南天门（坐标统一管理在 SceneConfig）
	local examCfg = SceneConfig[ExamConfig.ExamScene]
	local spawnPos = examCfg and examCfg.SpawnPosition or Vector3.new(200, 3, 100)
	teleportToPosition(player, spawnPos, ExamConfig.ExamScene)

	-- 通知客户端考核开始（含指数信息）
	examRemote:FireClient(player, "ExamStarted", index, threshold)

	-- 触发考核叙事
	if storyEvent then
		storyEvent:FireClient(player, ExamConfig.ExamScene)
	end

	print("📋 " .. player.Name .. " 开始天兵考核（指数：" .. index .. "/" .. threshold .. "）")
	return true
end

-- ============================================================
-- 完成考核
-- 1. 设置 IsRecruited = true
-- 2. 传送至蟠桃园
-- 3. 触发入职叙事（StoryEvent）
-- ============================================================
function ExamService.CompleteExam(player, passed)
	if not passed then
		examRemote:FireClient(player, "ExamFailed", "考核未通过，请继续修炼")
		return false
	end

	-- 已入职则跳过
	if ExamService.GetRecruitStatus(player) then
		examRemote:FireClient(player, "ExamFailed", "你已是天兵在编")
		return false
	end

	-- 设置晋升
	DataManager:UpdateField(player, "IsRecruited", true)

	-- 传送至蟠桃园（坐标统一管理在 SceneConfig）
	local passCfg = SceneConfig[ExamConfig.PassScene]
	local spawnPos = passCfg and passCfg.SpawnPosition or Vector3.new(300, 3, 50)
	teleportToPosition(player, spawnPos, ExamConfig.PassScene)

	-- 触发入职叙事
	if storyEvent then
		storyEvent:FireClient(player, "PeachGardenOnboard")
	end

	-- 通知客户端考核成功
	examRemote:FireClient(player, "ExamPassed")

	print("🎉 " .. player.Name .. " 通过天兵考核，已入职蟠桃园守卫")
	return true
end

-- ============================================================
-- 查询是否已入职
-- ============================================================
function ExamService.GetRecruitStatus(player)
	local data = DataManager:GetData(player)
	return data and data.IsRecruited or false
end

-- ============================================================
-- 查询考编指数（供其他模块调用）
-- ============================================================
function ExamService.GetExamIndex(player)
	return ExamService.CalculateIndex(player)
end

-- ============================================================
-- 处理客户端远程调用
-- ============================================================
examRemote.OnServerEvent:Connect(function(player, action, ...)
	if action == "StartExam" then
		ExamService.StartExam(player)
	elseif action == "CompleteExam" then
		ExamService.CompleteExam(player, true)
	elseif action == "CheckStatus" then
		local status = ExamService.GetRecruitStatus(player)
		local index = ExamService.CalculateIndex(player)
		examRemote:FireClient(player, "StatusResult", status, index)
	elseif action == "CheckEligibility" then
		local eligible, reason = ExamService.CheckEligibility(player)
		examRemote:FireClient(player, "EligibilityResult", eligible, reason)
	end
end)

print("📋 ExamService 已加载")
return ExamService
