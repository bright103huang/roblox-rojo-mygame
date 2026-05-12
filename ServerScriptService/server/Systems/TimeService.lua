-- ============================================================
-- 文件：ServerScriptService.Server.Systems.TimeService.server.lua
-- 功能：12 分钟时间循环系统 — 时辰推进、深夜结算
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local DataManager = require(script.Parent.DataManager)
local StatusService = require(script.Parent.StatusService)
local SpeedCalculator = require(script.Parent.SpeedCalculator)
local Config = require(ReplicatedStorage.Shared.Config)

-- ============================================================
-- 时间常量
-- ============================================================
local CYCLE_MINUTES = Config.Stats.DAY_CYCLE_MINUTES or 12
local CYCLE_SECONDS = CYCLE_MINUTES * 60  -- 720 秒
local DAY_HOURS = 24                      -- 游戏一天 24 时辰
local SECONDS_PER_HOUR = CYCLE_SECONDS / DAY_HOURS  -- 30 秒/时辰

-- 时辰名称
local HOUR_NAMES = {
	"子时", "丑时", "寅时", "卯时",
	"辰时", "巳时", "午时", "未时",
	"申时", "酉时", "戌时", "亥时",
}

local DAY_HOURS_START = 4   -- 卯时（6:00）开始为白天
local NIGHT_HOUR_START = 18 -- 酉时（18:00）开始为夜晚

-- ============================================================
-- 创建 TimeEvent
-- ============================================================
local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not eventsFolder then
	eventsFolder = Instance.new("Folder")
	eventsFolder.Name = "Events"
	eventsFolder.Parent = ReplicatedStorage
end

local TimeEvent = eventsFolder:FindFirstChild("TimeEvent")
if not TimeEvent then
	TimeEvent = Instance.new("RemoteEvent")
	TimeEvent.Name = "TimeEvent"
	TimeEvent.Parent = eventsFolder
end

-- ============================================================
-- 状态
-- ============================================================
local currentGameHour = 12  -- 从未时（12:00）开始，商店立即营业
local isNight = false
local lastMidnightTick = 0  -- 防止重复结算
local lastHourLabel = ""      -- 上一次广播的时辰标签

-- ============================================================
-- 获取当前时辰效率修正
-- ============================================================
local function getCurrentTimeModifier()
	local hour = currentGameHour
	local modifiers = Config.Stats.TIME_MODIFIERS
	for _, mod in ipairs(modifiers) do
		if hour >= mod[1] and hour < mod[2] then
			return {
				TaskEff = mod[3],
				ShopOpen = mod[4],
				RestEff = mod[5],
				Label = mod[6],
			}
		end
	end
	-- Default (shouldn't reach here if hours 0-24 are fully covered)
	return { TaskEff = 1.0, ShopOpen = false, RestEff = 1.0, Label = "" }
end

-- ============================================================
-- 广播时间到单个玩家
-- ============================================================
local function broadcastTimeToPlayer(player, hour, hourName, night)
	local modifier = getCurrentTimeModifier()
	local timeData = {
		Hour = hour,
		HourName = hourName,
		IsNight = night,
		TimeEff = modifier.TaskEff,
		ShopOpen = modifier.ShopOpen,
		RestEff = modifier.RestEff,
		TimeLabel = modifier.Label,
	}
	player:SetAttribute("GameHour", hour)
	player:SetAttribute("IsNight", night)
	player:SetAttribute("TimeEff", modifier.TaskEff)
	player:SetAttribute("ShopOpen", modifier.ShopOpen and 1 or 0)
	player:SetAttribute("RestEff", modifier.RestEff)
	if TimeEvent then
		TimeEvent:FireClient(player, timeData)
	end
end

-- 对所有在线玩家立即广播初始时间
local function broadcastTimeToAll()
	local hourIndex = math.floor(currentGameHour / 2) + 1
	if hourIndex > 12 then hourIndex = 1 end
	local hourName = HOUR_NAMES[hourIndex] or (tostring(currentGameHour) .. ":00")
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			broadcastTimeToPlayer(player, currentGameHour, hourName, isNight)
		end)
	end
end

-- 玩家加入时立即同步时间
local function onPlayerAdded(player)
	local hourIndex = math.floor(currentGameHour / 2) + 1
	if hourIndex > 12 then hourIndex = 1 end
	local hourName = HOUR_NAMES[hourIndex] or (tostring(currentGameHour) .. ":00")
	broadcastTimeToPlayer(player, currentGameHour, hourName, isNight)
end
Players.PlayerAdded:Connect(onPlayerAdded)

-- 对已有玩家广播初始时间
task.spawn(broadcastTimeToAll)

-- ============================================================
-- 核心循环
-- ============================================================
task.spawn(function()
	while true do
		task.wait(SECONDS_PER_HOUR)  -- 每 30 秒推进一个时辰

		-- 推进时辰
		currentGameHour = (currentGameHour + 1) % DAY_HOURS

		-- 更新白天/夜晚
		local wasNight = isNight
		isNight = currentGameHour >= NIGHT_HOUR_START or currentGameHour < DAY_HOURS_START

		-- 时辰名称
		local hourIndex = math.floor(currentGameHour / 2) + 1
		if hourIndex > 12 then hourIndex = 1 end
		local hourName = HOUR_NAMES[hourIndex] or (tostring(currentGameHour) .. ":00")

		-- 环境光照变化
		if isNight and not wasNight then
			Lighting.Ambient = Color3.fromRGB(30, 30, 50)
			Lighting.Brightness = 0.5
			print("🌙 入夜")
		elseif not isNight and wasNight then
			Lighting.Ambient = Color3.fromRGB(127, 127, 127)
			Lighting.Brightness = 1
			print("☀️ 天明")
		end

		-- 午夜结算（0:00 = currentGameHour == 0）
		if currentGameHour == 0 then
			local now = os.time()
			if now - lastMidnightTick >= 60 then  -- 至少间隔 60 秒
				lastMidnightTick = now
				task.spawn(function()
					for _, player in ipairs(Players:GetPlayers()) do
						local data = DataManager:GetData(player)
						if not data then continue end

						-- 疲劳结算
						local reduction = math.abs(Config.Stats.MIDNIGHT_FATIGUE_REDUCTION or 30)
						local newFatigue = math.max(0, (data.Fatigue or 0) - reduction)
						data.Fatigue = newFatigue
						DataManager:UpdateField(player, "Fatigue", newFatigue)

						-- 天数 +1
						data.TotalDays = (data.TotalDays or 0) + 1

						-- 戾气 > 50 时功德阴跌
						local malice = data.Malice or 0
						if malice > Config.Stats.MALICE_REDLINE then
							local gongDeDrop = math.floor(malice / 20)
							if gongDeDrop > 0 then
								data.GongDe = math.max(0, (data.GongDe or 0) - gongDeDrop)
								DataManager:UpdateField(player, "GongDe", data.GongDe)
								print("☯ " .. player.Name .. " 戾气过重，功德 -" .. gongDeDrop)
							end
						end

						-- 更新速度
						SpeedCalculator.Apply(player)

						-- 通知客户端（含疲劳结算信息）
						local extraData = {
							Hour = currentGameHour,
							HourName = hourName,
							IsNight = isNight,
							FatigueReduction = reduction,
							TotalDays = data.TotalDays,
						}
						player:SetAttribute("GameHour", currentGameHour)
						player:SetAttribute("IsNight", isNight)
						if TimeEvent then
							TimeEvent:FireClient(player, extraData)
						end
					end
				end)
			end
		end

		-- 广播时间变化（含 Attribute 同步）
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(function()
				broadcastTimeToPlayer(player, currentGameHour, hourName, isNight)
			end)
		end

		-- 时辰变更通知（通过 TaskEvent 触发客户端提示）
		local modifier = getCurrentTimeModifier()
		if modifier.Label ~= lastHourLabel then
			lastHourLabel = modifier.Label
			local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
			if eventsFolder then
				local taskEvent = eventsFolder:FindFirstChild("TaskEvent")
				if taskEvent then
					taskEvent:FireAllClients("HourChange", { Label = modifier.Label, Hour = currentGameHour })
				end
			end
		end
	end
end)

print("⏰ TimeService 已启动（" .. CYCLE_MINUTES .. " 分钟/天）")

return {
	GetHour = function() return currentGameHour end,
	IsNight = function() return isNight end,
	GetTimeModifier = getCurrentTimeModifier,
}
