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

-- 统一提示模块
local TaskNotice = require(ReplicatedStorage.Shared.UI.TaskNotice)

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
TaskEvent.OnClientEvent:Connect(function(result, extraData)
	-- 特殊事件：场景选择面板（不含冒号格式）
	if result == "ShowSceneChoice" then
		local module = script.Parent:FindFirstChild("SceneChoiceUI")
		if not module then
			module = script.Parent:FindFirstChild("Client") and script.Parent.Client:FindFirstChild("SceneChoiceUI")
		end
		if module then
			local sceneChoiceUI = require(module)
			local ok, err = pcall(sceneChoiceUI.Open, sceneChoiceUI, extraData)
			if not ok then
				warn("❌ SceneChoiceUI:Open 调用失败:", err)
			end
		else
			warn("⚠️ SceneChoiceUI 模块未加载，刷新 SSS 同步后重试")
		end
		return
	end

	-- 药材入炉事件（由 AlchemyTask 触发）
	if result == "AlchemyHerbAccepted" then
		getState("Alchemy").carrying = false
		-- 播放简短提示：药材已入炉
		local playerGui = player:WaitForChild("PlayerGui")
		local msg = Instance.new("ScreenGui")
		msg.Name = "AlchemyHerbMsg"
		msg.ResetOnSpawn = false
		msg.Parent = playerGui

		local bg = Instance.new("Frame")
		bg.Size = UDim2.new(0, 200, 0, 40)
		bg.Position = UDim2.new(0.5, -100, 0.7, 0)
		bg.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
		bg.BackgroundTransparency = 0.15
		bg.BorderSizePixel = 0
		bg.Parent = msg
		local bgCorner = Instance.new("UICorner")
		bgCorner.CornerRadius = UDim.new(0, 8)
		bgCorner.Parent = bg

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = "🌿 药材已入炉，去取柴火吧！"
		label.TextColor3 = Color3.fromRGB(144, 238, 144)
		label.TextSize = 14
		label.Font = Enum.Font.SourceSansBold
		label.Parent = bg

		task.delay(2, function()
			msg:Destroy()
		end)
		return
	end

	-- 添柴进度事件（由 AlchemyTask 触发）
	if result == "AlchemyFuel" then
		local alchemyUI = require(script.Parent.AlchemyUI)
		alchemyUI:ShowFire(extraData and extraData.Step or 1)
		-- 重置 carrying 允许继续取柴（服务端已清空 carrying）
		getState("Alchemy").carrying = false
		return
	end

	-- 炼丹结算事件（由 AlchemyTask 触发，替代旧的 Craft 流程）
	if result == "AlchemyCraft" then
		local alchemyUI = require(script.Parent.AlchemyUI)
		alchemyUI:ShowResult(extraData and extraData.Success, extraData)
		-- 重置本地 carrying 状态
		for _, state in pairs(playerState) do
			state.carrying = false
		end
		return
	end


	-- 时辰变更通知
	if result == "HourChange" then
		TaskNotice:Notify({
			Title = "⏰ " .. tostring(extraData and extraData.Label or ""),
			Text = "第 " .. tostring(extraData and extraData.Hour or 0) .. " 时辰",
			Duration = 2,
			Color = Color3.fromRGB(180, 180, 250),
		})
		return
	end

	-- 场景指南
	if result == "ShowSceneGuide" then
		local SceneGuideUI = require(ReplicatedStorage.Shared.UI.SceneGuideUI)
		SceneGuideUI.Show(extraData and extraData.SceneName)
		return
	end

	-- 妖兽角斗场战斗事件
	if result == "BeastFightStart" then
		TaskNotice:Notify({
			Title = "⚔ 妖兽出现",
			Text = "妖兽: " .. tostring(extraData and extraData.AnimalName or "???"),
			Duration = 2,
		})
		return
	end

	if result == "BeastCollision" then
		TaskNotice:Notify({
			Title = "💥 碰撞",
			Text = "第 " .. tostring(extraData and extraData.Round or 1) .. " 轮碰撞！",
			Duration = 1.5,
			Color = Color3.fromRGB(255, 180, 60),
		})
		return
	end

	if result == "BeastVictory" then
		getState("Beast").carrying = false
		TaskNotice:Notify({
			Title = "🏆 胜利",
			Text = tostring(extraData and extraData.Message or "击败妖兽！"),
			Color = Color3.fromRGB(80, 200, 80),
		})
		return
	end

	if result == "BeastLost" then
		getState("Beast").carrying = false
		TaskNotice:Notify({
			Title = "💀 战败",
			Text = tostring(extraData and extraData.Message or "妖兽太强！"),
			Color = Color3.fromRGB(255, 60, 60),
		})
		return
	end

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
		TaskNotice:Notify({
			Title = "✅ 交付成功",
			Text = taskName .. " 任务完成",
			Duration = 2,
			Color = Color3.fromRGB(80, 200, 80),
		})
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
		if extraData and extraData.Reason == "MaxAttempts" then
			TaskNotice:Notify({
				Title = "❌ 炼丹已达上限",
				Text = "今日炼丹次数已用完",
				Duration = 2,
				Color = Color3.fromRGB(255, 100, 100),
			})
		end

	elseif resultType == "SpeedUp" then
		print("⚡ 速度升级！当前额外速度：" .. tostring(result))

	elseif resultType == "LevelUp" then
		-- 属性升级（由 StatusService 触发）
		TaskNotice:Notify({
			Title = "⬆ 升级",
			Text = taskName .. " 提升至 Lv." .. tostring(result),
			Color = Color3.fromRGB(100, 200, 255),
		})

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

	elseif resultType == "SceneSwitched" then
		-- 场景切换成功（taskName 即为场景名）
		print("🚀 已切换到场景：" .. taskName)
		-- 重置所有 carrying 状态
		for _, state in pairs(playerState) do
			state.carrying = false
		end

	elseif resultType == "ForceTeleportHome" then
		-- 油尽灯枯: 强制传送回家
		print("[传送] " .. tostring(result and result.Message))

	elseif resultType == "PoisonBurst" then
		-- 毒戾入体: 毒发通知
		TaskNotice:Notify({
			Title = "☠ 毒戾入体",
			Text = tostring(result and result.Message or "火毒发作！"),
			Color = Color3.fromRGB(180, 60, 255),
		})

	elseif resultType == "SelfHarm" then
		-- 狂躁: 误伤自己
		TaskNotice:Notify({
			Title = "💢 误伤",
			Text = tostring(result and result.Message or "狂躁误伤自己！"),
			Color = Color3.fromRGB(255, 100, 100),
		})
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
			-- 支持数组格式（多个同任务Pickup区域）和单表格式
			local pickupList = areas.Pickup.PartName and { areas.Pickup } or areas.Pickup
			for _, entry in ipairs(pickupList) do
				partMap[entry.PartName] = {
					TaskName = taskName,
					ActionType = entry.FireAction or "Pick",
					AreaCfg = entry,
				}
			end
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

		if mapping.ActionType == "Pick" and (not state.carrying or mapping.TaskName == "Alchemy") then
			state.carrying = true
			print("🎯 拿起：" .. mapping.TaskName)
			TaskEvent:FireServer(
				"Pick:" .. mapping.TaskName,
				nil,
				{ PartName = part.Name }
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
