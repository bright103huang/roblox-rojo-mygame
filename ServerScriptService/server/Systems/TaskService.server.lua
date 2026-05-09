-- ============================================================
-- 文件：ServerScriptService.Server.Systems.TaskService.server.lua
-- 功能：通用任务调度器 — 加载 TaskConfig，注册任务处理器，
--       将客户端的交互事件路由到对应的处理器模块
--       新增：资源耗尽检测、升级触发场景选择面板
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)
local SpeedCalculator = require(script.Parent.SpeedCalculator)
local StatusService = require(script.Parent.StatusService)
local Config = require(ReplicatedStorage.Shared.Config)

-- ============================================================
-- 确保 Events 文件夹和 TaskEvent 存在
-- ============================================================
local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not eventsFolder then
	eventsFolder = Instance.new("Folder")
	eventsFolder.Name = "Events"
	eventsFolder.Parent = ReplicatedStorage
end

local TaskEvent = eventsFolder:FindFirstChild("TaskEvent")
if not TaskEvent then
	TaskEvent = Instance.new("RemoteEvent")
	TaskEvent.Name = "TaskEvent"
	TaskEvent.Parent = eventsFolder
	print("✅ TaskEvent 已创建")
end

-- SceneGate RemoteFunction（客户端查询场景状态）
local gateFunction = eventsFolder:FindFirstChild("RequestSceneGates")
if not gateFunction then
	gateFunction = Instance.new("RemoteFunction")
	gateFunction.Name = "RequestSceneGates"
	gateFunction.Parent = eventsFolder
end
local SceneGateService = require(script.Parent.SceneGateService)
gateFunction.OnServerInvoke = function(player)
	local data = DataManager:GetData(player)
	local gates = SceneGateService:EvaluateAllScenes(player)
	return {
		Gates = gates,
		CurrentScene = data and data.CurrentScene or "YiShanFang",
		GameHour = player:GetAttribute("GameHour") or 6,
		IsNight = player:GetAttribute("IsNight") or false,
		TimeLabel = player:GetAttribute("TimeLabel") or "",
		ChainEvents = player:GetAttribute("ChainEvents") or "",
	}
end

-- ============================================================
-- 任务处理器注册
-- ============================================================
local handlers = {}

local function pairsCount(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

local function loadHandlers()
	local taskDefs = Config.Task.Tasks
	if not taskDefs then return end

	for taskName, taskCfg in pairs(taskDefs) do
		if Config.Task.General.ActiveTasks then
			local found = false
			for _, active in ipairs(Config.Task.General.ActiveTasks) do
				if active == taskName then found = true; break end
			end
			if not found then continue end
		end

		local handlerPath = taskCfg.HandlerModule
		if not handlerPath then
			warn("⚠️ 任务 " .. taskName .. " 未指定 HandlerModule，跳过")
			continue
		end

		-- 将 "Tasks.DeliverTask" 转为文件路径
		local pathParts = string.split(handlerPath, ".")
		local moduleRef = script.Parent.Parent  -- 从 Server 文件夹开始
		for _, part in ipairs(pathParts) do
			moduleRef = moduleRef:FindFirstChild(part)
			if not moduleRef then break end
		end

		if moduleRef and moduleRef:IsA("ModuleScript") then
			local success, handler = pcall(require, moduleRef)
			if success then
				handlers[taskName] = handler
				print("✅ 已加载任务处理器: " .. taskName)
			else
				warn("❌ 加载任务处理器失败 " .. taskName .. ": " .. tostring(handler))
			end
		else
			warn("⚠️ 找不到任务处理器模块: " .. handlerPath)
		end
	end

	print("📋 共加载 " .. pairsCount(handlers) .. " 个任务处理器")
end

loadHandlers()

-- ============================================================
-- 注册等级提升回调（触发场景选择面板）
-- ============================================================
StatusService.OnLevelUp = function(player, attrField, newLevel)
	local nameMap = { Agility = "身法", AlchemyLv = "火候", Combat = "仙力" }
	print("⬆ 升级触发场景选择：" .. player.Name .. " " .. (nameMap[attrField] or attrField) .. " Lv." .. newLevel)

	-- 获取当前玩家数据用于选择面板
	local data = DataManager:GetData(player)
	if not data then return end

	local sceneInfo = {
		CurrentScene = data.CurrentScene,
		Stamina = data.Stamina,
		Spirit = data.Spirit,
		Fatigue = data.Fatigue,
		FirePoison = data.FirePoison,
		Malice = data.Malice,
		TriggerType = "LevelUp",
		TriggerDetail = (nameMap[attrField] or attrField) .. " 提升至 Lv." .. newLevel,
		GameHour = player:GetAttribute("GameHour") or 6,
		IsNight = player:GetAttribute("IsNight") or false,
		TimeLabel = player:GetAttribute("TimeLabel") or "",
		ChainEvents = player:GetAttribute("ChainEvents") or "",
	}

	TaskEvent:FireClient(player, "ShowSceneChoice", sceneInfo)
end

-- ============================================================
-- 辅助：从 workspace 查找交互区域
-- ============================================================
local function findArea(partName, attrName, attrValue)
	for _, v in pairs(workspace:GetDescendants()) do
		if v.Name == partName then
			if attrName == nil then
				return v
			end
			if v:GetAttribute(attrName) == attrValue then
				return v
			end
		end
	end
	return nil
end

-- ============================================================
-- 辅助：发送 ShowSceneChoice（资源耗尽时触发）
-- ============================================================
local function sendSceneChoice(player, reason)
	local data = DataManager:GetData(player)
	if not data then return end

	local sceneInfo = {
		CurrentScene = data.CurrentScene,
		Stamina = data.Stamina,
		Spirit = data.Spirit,
		Fatigue = data.Fatigue,
		FirePoison = data.FirePoison,
		Malice = data.Malice,
		TriggerType = "ResourceExhausted",
		TriggerDetail = reason or "资源不足",
		GameHour = player:GetAttribute("GameHour") or 6,
		IsNight = player:GetAttribute("IsNight") or false,
		TimeLabel = player:GetAttribute("TimeLabel") or "",
		ChainEvents = player:GetAttribute("ChainEvents") or "",
	}

	TaskEvent:FireClient(player, "ShowSceneChoice", sceneInfo)
end

-- ============================================================
-- 核心：客户端请求处理
-- ============================================================
TaskEvent.OnServerEvent:Connect(function(player, action, legacyArg, contextData)
	-- ----- 尝试解析 action 格式 -----
	local actionType, taskName

	if type(action) == "string" and string.find(action, ":") then
		actionType, taskName = string.match(action, "^(%w+):(%w+)$")
	else
		actionType = action
		taskName = "Deliver"

		if actionType == "Drop" and legacyArg ~= nil then
			local tableId = legacyArg
			contextData = {
				AreaName = "TableArea",
				AttrName = "TableId",
				AttrValue = tableId,
			}
		end
	end

	if not actionType or not taskName then
		warn("⚠️ 无效的 action 格式: " .. tostring(action))
		return
	end

	-- 查找处理器
	local handler = handlers[taskName]
	if not handler then
		warn("⚠️ 未找到任务处理器: " .. taskName)
		TaskEvent:FireClient(player, "Error:UnknownTask")
		return
	end

	-- ============================================================
	-- 路由到处理器
	-- ============================================================
	if actionType == "Pick" then
		-- 前置资源检查：从 TASK_COSTS 读取 ActionCost（正数阈值）
		local taskCosts = Config.Stats.TASK_COSTS[taskName]
		if taskCosts and taskCosts.ActionCost then
			local canPerform, reason = StatusService:CanPerformTask(player, taskCosts.ActionCost)
			if not canPerform then
				print("❌ " .. player.Name .. " " .. taskName .. " 资源不足：" .. tostring(reason))
				sendSceneChoice(player, reason)
				TaskEvent:FireClient(player, "PickFailed:" .. taskName)
				return
			end
		end

		local ok = handler.OnPlayerPickup(player, contextData)
		if ok then
			TaskEvent:FireClient(player, "PickSuccess:" .. taskName)
		else
			TaskEvent:FireClient(player, "PickFailed:" .. taskName)
		end

	elseif actionType == "Drop" then
		local area = nil
		if contextData then
			area = findArea(
				contextData.AreaName,
				contextData.AttrName,
				contextData.AttrValue
			)
		end

		local ok, result = handler.OnPlayerDrop(player, area)
		if ok then
			TaskEvent:FireClient(player, "DropSuccess:" .. taskName)
		elseif result == "WrongTable" then
			TaskEvent:FireClient(player, "DropFailed:" .. taskName)
		elseif result == "NotCarrying" then
			TaskEvent:FireClient(player, "DropFailed:" .. taskName)
		elseif result == "OpenUI" then
			-- UI 已在 OnPlayerDrop 中触发
		elseif result == "FuelAdded" or result == "CraftDone" then
			-- 由 AlchemyTask 自行通知客户端
		elseif result == "WrongIngredient" or result == "MaxAttempts" then
			TaskEvent:FireClient(player, "DropFailed:" .. taskName)
		else
			TaskEvent:FireClient(player, "DropFailed:" .. taskName)
		end

	elseif actionType == "Craft" then
		if handler.OnCraft then
			local ok, result = handler.OnCraft(player, contextData)
			if ok and result then
				if result.Success then
					TaskEvent:FireClient(player, "CraftSuccess:" .. taskName, result)
				else
					TaskEvent:FireClient(player, "CraftFailed:" .. taskName, result)
				end
			else
				TaskEvent:FireClient(player, "CraftFailed:" .. taskName, { Reason = tostring(result) })
			end
		else
			warn("⚠️ 任务 " .. taskName .. " 未实现 OnCraft 处理器")
		end

	elseif actionType == "Attack" then
		if handler.OnAttack then
			local ok, result = handler.OnAttack(player, contextData)
			if ok then
				TaskEvent:FireClient(player, "AttackSuccess:" .. taskName, result)
			else
				TaskEvent:FireClient(player, "AttackFailed:" .. taskName, result)
			end
		else
			warn("⚠️ 任务 " .. taskName .. " 未实现 OnAttack 处理器")
		end

	else
		warn("⚠️ 未知的 actionType: " .. tostring(actionType))
	end
end)

-- ============================================================
-- 回退出生点管理
-- ============================================================
local SPAWN_NAME = "YiShanFangSpawn"

local sceneManager = script.Parent:FindFirstChild("SceneManager")
if not sceneManager then
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			local spawnLocation = workspace:FindFirstChild(SPAWN_NAME)
			if spawnLocation then
				local hrp = char:WaitForChild("HumanoidRootPart")
				hrp.CFrame = spawnLocation.CFrame + Vector3.new(0, 3, 0)
			else
				warn("❌ 未找到出生点：" .. SPAWN_NAME)
			end
			SpeedCalculator.Apply(player)
		end)
	end)
end

print("🚀 TaskService 调度器启动完成")
