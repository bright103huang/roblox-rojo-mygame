-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.TaskClient.local.luau
-- 功能：通用任务客户端 — 从 TaskConfig 读取交互区域配置，
--       动态绑定触摸事件，支持多任务扩展
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- 加载 Config
local Config = require(ReplicatedStorage.Shared.Config)
local TaskConfig = Config.Task

-- ============================================================
-- 等待 TaskEvent
-- ============================================================
local function waitForTaskEvent()
	local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
	if not eventsFolder then
		repeat
			eventsFolder = ReplicatedStorage:FindFirstChild("Events")
			RunService.Heartbeat:Wait()
		until eventsFolder
	end

	local taskEvent = eventsFolder:WaitForChild("TaskEvent", 10)
	if not taskEvent then
		error("TaskEvent not found - server may not be running")
	end
	return taskEvent
end

local TaskEvent = waitForTaskEvent()

-- ============================================================
-- 状态管理
-- ============================================================
local playerState = {}  -- { [taskName] = { carrying = bool, debounce = bool } }

local function getState(taskName)
	if not playerState[taskName] then
		playerState[taskName] = {
			carrying = false,
			debounce = false,
		}
	end
	return playerState[taskName]
end

-- ============================================================
-- 处理服务器回执
-- ============================================================
TaskEvent.OnClientEvent:Connect(function(result)
	-- 新版格式: "DropSuccess:Deliver", "DropFailed:Deliver" 等
	local resultType, taskName = string.match(result, "^(%w+):(%w+)$")
	if not resultType then
		-- 旧版格式兼容
		if result == "DropSuccess" then
			resultType = "DropSuccess"
			taskName = "Deliver"
		elseif result == "DropFailed" then
			resultType = "DropFailed"
			taskName = "Deliver"
		else
			return
		end
	end

	local state = getState(taskName)

	if resultType == "DropSuccess" then
		print("客户端：" .. taskName .. " 交付成功")
		state.carrying = false

		-- 清理手持道具
		local char = player.Character
		if char then
			local dish = char:FindFirstChild("Dish")
			if dish then dish:Destroy() end
			local handPeach = char:FindFirstChild("HandPeach")
			if handPeach then handPeach:Destroy() end
		end

	elseif resultType == "PickFailed" then
		-- 拿起失败：可能是服务端 detected carrying 不一致，重置状态
		print("客户端：" .. taskName .. " 拿起失败（重置 carrying）")
		state.carrying = false

	elseif resultType == "DropFailed" then
		-- 不打印"交付失败"避免混淆（2D游戏经过非目标桌子时会触发）
		-- 注意：不重置 carrying，玩家可以继续尝试
		-- 若服务端实际已解除 carrying，下一次 Pick 时会返回 PickFailed 才重置

	elseif resultType == "SpeedUp" then
		print("⚡ 速度升级！当前额外速度：" .. tostring(result))

	elseif resultType == "OpenAlchemyUI" then
		-- 打开炼丹 UI（result 包含药材和配方数据）
		local alchemyUI = require(script.Parent.AlchemyUI)
		alchemyUI:Open(result)
		-- 炼丹 UI 打开后，carrying 保持 true，防止重复触发
		-- 炼制完成或关闭 UI 后，服务端会重置 carrying

	elseif resultType == "CraftSuccess" then
		-- 炼丹成功
		local alchemyUI = require(script.Parent.AlchemyUI)
		alchemyUI:ShowResult(true, result)
		state.carrying = false

	elseif resultType == "CraftFailed" then
		-- 炼丹失败
		local alchemyUI = require(script.Parent.AlchemyUI)
		alchemyUI:ShowResult(false, result)
		state.carrying = false

	elseif resultType == "LevelUp" then
		-- 属性升级（由 StatusService 触发）
		print("⬆ " .. taskName .. " 升级至 Lv." .. tostring(result))

	elseif resultType == "BeastHit" then
		-- 妖兽攻击玩家
		print("💥 妖兽造成 " .. tostring(result and result.Damage) .. " 点伤害")

	elseif resultType == "AttackSuccess" then
		-- 玩家攻击成功
		if result and result.Killed then
			print("⚔ 妖兽被击杀！")
			state.carrying = false
		end

	elseif resultType == "AttackFailed" then
		-- 攻击失败
		print("❌ 攻击失败：" .. tostring(result))
		-- 如果妖兽已消失，重置 carrying
		if result == "NoBeast" or result == "NotYourBeast" then
			state.carrying = false
		end

	elseif resultType == "Promotion" then
		-- 天兵军衔晋升（由 MeritService 触发）
		print("🏅 军衔晋升：" .. tostring(result and result.NewRank))
		if result then
			-- 更新 leaderstats 军衔显示（通过 Attribute 自动同步）
			player:SetAttribute("MilitaryRank", result.NewRank)
			player:SetAttribute("Merit", result.Merit)
		end
	end
end)

-- ============================================================
-- 工具函数
-- ============================================================
local function pairsCount(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

-- ============================================================
-- 构建交互映射
-- ============================================================
-- partName → { taskName, actionType, areaCfg }
local partMap = {}

for taskName, taskCfg in pairs(TaskConfig.Tasks or {}) do
	local areas = taskCfg.InteractionAreas
	if areas then
		if areas.Pickup then
			partMap[areas.Pickup.PartName] = {
				TaskName = taskName,
				ActionType = areas.Pickup.FireAction or "Pick",
				AreaCfg = areas.Pickup,
			}
		end
		if areas.Drop then
			-- 使用 FireAction 作为 ActionType，支持 "Attack" 等自定义动作
			local actionType = areas.Drop.FireAction or "Drop"
			partMap[areas.Drop.PartName] = {
				TaskName = taskName,
				ActionType = actionType,
				AreaCfg = areas.Drop,
			}
		end
	end
end

print("📋 客户端已加载 " .. pairsCount(partMap) .. " 个交互区域类型")

-- ============================================================
-- 绑定触摸事件
-- ============================================================

local DebounceTime = TaskConfig.General.DebounceTime or 0.3

local function bind(part)
	local mapping = partMap[part.Name]
	if not mapping then return end

	local state = getState(mapping.TaskName)

	part.Touched:Connect(function(hit)
		if not player.Character then return end
		if hit.Parent ~= player.Character then return end
		if state.debounce then return end

		state.debounce = true

		if mapping.ActionType == "Pick" and not state.carrying then
			state.carrying = true
			print("🎯 拿起：" .. mapping.TaskName)
			TaskEvent:FireServer(
				"Pick:" .. mapping.TaskName,
				nil,
				nil
			)

		elseif mapping.ActionType == "Drop" and state.carrying then
			-- 构建上下文数据供服务端查找 area
			local areaCfg = mapping.AreaCfg
			local attrValue = areaCfg.NeedsAttribute
				and part:GetAttribute(areaCfg.NeedsAttribute)
				or nil

			local contextData = {
				AreaName = part.Name,
				AttrName = areaCfg.NeedsAttribute,
				AttrValue = attrValue,
			}

			print("🎯 放下：" .. mapping.TaskName
				.. (attrValue and (" (ID: " .. tostring(attrValue) .. ")") or ""))
			TaskEvent:FireServer(
				"Drop:" .. mapping.TaskName,
				nil,
				contextData
			)

		elseif mapping.ActionType == "Attack" and state.carrying then
			-- 妖兽攻击
			print("⚔ 攻击妖兽：" .. mapping.TaskName)
			TaskEvent:FireServer(
				"Attack:" .. mapping.TaskName,
				nil,
				{ Part = part }
			)
		end

		task.wait(DebounceTime)
		state.debounce = false
	end)
end

-- 等待场景加载完成
task.wait(1)

-- 扫描现有物体并绑定
for _, v in pairs(workspace:GetDescendants()) do
	bind(v)
end

-- 新加入的物体也绑定
workspace.DescendantAdded:Connect(bind)

print("🚀 TaskClient 启动完成，监听 " .. pairsCount(partMap) .. " 种交互区域")
