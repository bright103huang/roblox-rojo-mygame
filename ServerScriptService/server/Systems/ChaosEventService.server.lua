-- ============================================================
-- 文件：ServerScriptService.Server.Systems.ChaosEventService.server.lua
-- 功能：大闹天宫随机事件调度器 + 结局判定
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)

-- 结局场景坐标
local ENDING_SPAWNS = {
	EndingLoyal = Vector3.new(6000, 3, 2),
	EndingWukong = Vector3.new(6000, 3, 2),
	EndingChaos = Vector3.new(6000, 3, 2),
}

-- ============================================================
-- 确保 Events 文件夹和 ChaosEvent RemoteEvent
-- ============================================================
local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not eventsFolder then
	eventsFolder = Instance.new("Folder")
	eventsFolder.Name = "Events"
	eventsFolder.Parent = ReplicatedStorage
end

local ChaosEvent = eventsFolder:FindFirstChild("ChaosEvent")
if not ChaosEvent then
	ChaosEvent = Instance.new("RemoteEvent")
	ChaosEvent.Name = "ChaosEvent"
	ChaosEvent.Parent = eventsFolder
	print("✅ ChaosEvent 已创建")
end

-- ============================================================
-- 事件池（每个事件含标题、描述、选项、时辰约束）
-- ============================================================
local EVENTS = {
	{
		Id = "steal_peach",
		Title = "偷桃事件",
		Desc = "你看见一只猴子正鬼鬼祟祟地摘蟠桃……它冲你挤了挤眼睛，似乎在等你表态。",
		Choices = {
			{ Text = "抓住它！", Effect = { Loyalty = 10, Chaos = -5 } },
			{ Text = "假装没看见", Effect = { WukongFavor = 5, Chaos = 5 } },
			{ Text = "一起分一个", Effect = { WukongFavor = 10, Loyalty = -10, Chaos = 10 } },
		},
		MinHour = 6,
		MaxHour = 18,
	},
	{
		Id = "wukong_taunt",
		Title = "悟空挑衅",
		Desc = "一只毛脸雷公嘴的猴子跳到你面前，叉腰大笑：「这天庭的走狗，也配守桃园？」",
		Choices = {
			{ Text = "拔剑相对", Effect = { Loyalty = 10, WukongFavor = -10 } },
			{ Text = "忍气吞声", Effect = { Chaos = 5 } },
			{ Text = "笑着拱拱手", Effect = { WukongFavor = 10, Loyalty = -5 } },
		},
	},
	{
		Id = "patrol_neglect",
		Title = "巡逻懈怠",
		Desc = "夜深人静，巡逻路线空无一人。你打了个哈欠，想找个地方偷懒。",
		Choices = {
			{ Text = "坚持巡逻", Effect = { Loyalty = 5, Chaos = -5 } },
			{ Text = "找个角落打盹", Effect = { Chaos = 10 } },
			{ Text = "溜去猴山串门", Effect = { WukongFavor = 10, Chaos = 5, Loyalty = -5 } },
		},
		MinHour = 18,
		MaxHour = 6,
	},
	{
		Id = "heavenly_decree",
		Title = "天庭诏令",
		Desc = "太白金星驾云而至，宣读玉帝诏令：「近日蟠桃园异动频繁，命你严加看管，不得有误。」",
		Choices = {
			{ Text = "领命严守", Effect = { Loyalty = 15, Chaos = -10 } },
			{ Text = "口头应付", Effect = { Chaos = 5 } },
			{ Text = "暗示桃园一切太平", Effect = { WukongFavor = 10, Loyalty = -5 } },
		},
		MinHour = 6,
		MaxHour = 18,
	},
	{
		Id = "monkey_distraction",
		Title = "调猴离山",
		Desc = "远处传来喧闹声，几只猴子在故意砸东西引你过去。但你瞥见桃园深处似乎另有动静。",
		Choices = {
			{ Text = "去追闹事的猴子", Effect = { Loyalty = 5, Chaos = -5 } },
			{ Text = "坚守桃园主路", Effect = { Loyalty = 5 } },
			{ Text = "趁乱去猴山探探", Effect = { WukongFavor = 15, Chaos = 10, Loyalty = -10 } },
		},
	},
	{
		Id = "treasure_temptation",
		Title = "宝物诱惑",
		Desc = "一只小猴捧着一颗发光的东西溜到你面前——那是太上老君遗落的金丹葫芦。",
		Choices = {
			{ Text = "上交天庭", Effect = { Loyalty = 15, Chaos = -10 } },
			{ Text = "自己偷偷收好", Effect = { Chaos = 15, Loyalty = -5 } },
			{ Text = "献给孙悟空", Effect = { WukongFavor = 20, Loyalty = -10, Chaos = 5 } },
		},
	},
	{
		Id = "chaos_rumor",
		Title = "混沌谣言",
		Desc = "天兵甲拉你到一旁，压低声音说：「听说了吗？孙悟空要闹天宫了……你站哪边？」",
		Choices = {
			{ Text = "当然是效忠天庭", Effect = { Loyalty = 10, Chaos = -5 } },
			{ Text = "含糊其辞", Effect = { Chaos = 5 } },
			{ Text = "那猴子倒是有几分本事", Effect = { WukongFavor = 10, Chaos = 10, Loyalty = -10 } },
		},
	},
	{
		Id = "celestial_warning",
		Title = "仙官告诫",
		Desc = "值日功曹路过桃园，意味深长地对你说：「最近天庭暗流涌动，你好自为之。」",
		Choices = {
			{ Text = "请教安危之道", Effect = { Loyalty = 5, Chaos = -5 } },
			{ Text = "不以为然", Effect = { Chaos = 5 } },
			{ Text = "打听孙悟空的消息", Effect = { WukongFavor = 10, Chaos = 5 } },
		},
	},
}

-- ============================================================
-- 结局定义
-- ============================================================
local ENDINGS = {
	{
		Id = "EndingLoyal",
		Condition = function(data)
			return (data.Loyalty or 50) >= 80
		end,
		Title = "天庭栋梁",
		Desc = "玉帝听闻你忠心耿耿、恪尽职守，特封你为御前侍卫统领，从此平步青云，位列仙班！",
	},
	{
		Id = "EndingWukong",
		Condition = function(data)
			return (data.WukongFavor or 0) >= 80
		end,
		Title = "跟随大圣",
		Desc = "孙悟空看重你的义气与胆识，邀你一同反出天庭，大闹天宫，快意恩仇！",
	},
	{
		Id = "EndingChaos",
		Condition = function(data)
			return (data.Chaos or 0) >= 80
		end,
		Title = "趁乱自立",
		Desc = "天庭大乱之际，你趁势而起，在蟠桃园扯旗自立，三界震动，一个新的枭雄诞生了！",
	},
}

-- ============================================================
-- 工具函数
-- ============================================================
local function clamp(v, min, max)
	return math.max(min, math.min(max, v))
end

-- 返回当前时辰可触发的事件列表（按 MinHour/MaxHour 过滤）
local function getAvailableEvents(gameHour)
	local available = {}
	for _, evt in ipairs(EVENTS) do
		local minH = evt.MinHour
		local maxH = evt.MaxHour
		if minH == nil or maxH == nil then
			-- 无时间约束，全天可用
			table.insert(available, evt)
		elseif minH <= maxH then
			-- 正常区间，如 6~18
			if gameHour >= minH and gameHour < maxH then
				table.insert(available, evt)
			end
		else
			-- 跨天区间，如 18~6（夜晚）
			if gameHour >= minH or gameHour < maxH then
				table.insert(available, evt)
			end
		end
	end
	return available
end

-- 触发概率：基础 30%，混沌每 10 点增加 5%
local function calcTriggerChance(data)
	local chaos = data.Chaos or 0
	return 0.30 + (chaos / 10) * 0.05
end

-- 对玩家应用效果并返回变更列表
local function applyEffect(player, data, effect)
	local changes = {}
	for field, delta in pairs(effect) do
		local current = data[field] or 0
		local newValue = clamp(current + delta, 0, 100)
		data[field] = newValue
		DataManager:UpdateField(player, field, newValue)
		table.insert(changes, {
			Field = field,
			Delta = delta,
			NewValue = newValue,
		})
	end
	return changes
end

-- ============================================================
-- 公开接口
-- ============================================================
local ChaosEventService = {}

-- 当前游戏时辰（由内部循环维护）
ChaosEventService._currentHour = 6

-- 为指定玩家触发一个随机事件（返回事件数据，无可触发的返回 nil）
function ChaosEventService:TriggerEvent(player)
	local data = DataManager:GetData(player)
	if not data then return nil end
	if data.EndingReached then return nil end
	if not data.IsRecruited then return nil end

	local available = getAvailableEvents(ChaosEventService._currentHour)
	if #available == 0 then return nil end

	return available[math.random(1, #available)]
end

-- 处理玩家选择，返回变更列表
function ChaosEventService:MakeChoice(player, eventId, choiceIndex)
	local data = DataManager:GetData(player)
	if not data then return nil end
	if data.EndingReached then return nil end

	local evt
	for _, e in ipairs(EVENTS) do
		if e.Id == eventId then evt = e; break end
	end
	if not evt then return nil end

	local choice = evt.Choices[choiceIndex]
	if not choice then return nil end

	local changes = applyEffect(player, data, choice.Effect)
	return changes
end

-- 获取混沌程度描述
function ChaosEventService:GetChaosLevel(player)
	local data = DataManager:GetData(player)
	if not data then return "平静" end
	local c = data.Chaos or 0
	if c < 30 then return "平静"
	elseif c < 60 then return "骚动"
	else return "大乱" end
end

-- 检测结局条件，满足则返回结局数据（并标记 EndingReached=true）
function ChaosEventService:CheckEnding(player)
	local data = DataManager:GetData(player)
	if not data then return nil end
	if data.EndingReached then return nil end

	for _, ending in ipairs(ENDINGS) do
		if ending.Condition(data) then
			data.EndingReached = true
			data.CurrentScene = ending.Id
			DataManager:UpdateField(player, "EndingReached", true)
			DataManager:UpdateField(player, "CurrentScene", ending.Id)
			DataManager:Save(player)

			-- 传送玩家到结局场景
			local char = player.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					local spawnPos = ENDING_SPAWNS[ending.Id] or Vector3.new(6000, 3, 2)
					hrp.CFrame = CFrame.new(spawnPos)
				end
			end

			print("🎬 结局触发 " .. player.Name .. " → " .. ending.Title)
			return ending
		end
	end
	return nil
end

-- ============================================================
-- 时间循环（每 30 秒推进一个时辰，与 TimeService 同步）
-- ============================================================
local COOLDOWN_HOURS = 3  -- 冷却：至少间隔 3 个时辰（90 秒）

task.spawn(function()
	while true do
		task.wait(30)

		local currentHour = (ChaosEventService._currentHour + 1) % 24
		ChaosEventService._currentHour = currentHour

		-- ==========================================
		-- 午夜结算（0:00）：检测结局
		-- ==========================================
		if currentHour == 0 then
			task.spawn(function()
				for _, player in ipairs(Players:GetPlayers()) do
					local ending = ChaosEventService:CheckEnding(player)
					if ending then
						ChaosEvent:FireClient(player, {
							Type = "Ending",
							EndingId = ending.Id,
							Title = ending.Title,
							Desc = ending.Desc,
						})
					end
				end
			end)
		end

		-- ==========================================
		-- 时辰推进：检测事件触发
		-- ==========================================
		task.spawn(function()
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataManager:GetData(player)
				if not data then continue end
				if data.EndingReached then continue end        -- 已达成结局
				if not data.IsRecruited then continue end      -- 未入职天兵

				-- ---- 冷却检查 ----
				local lastHour = data.LastEventHour
				if lastHour ~= nil and lastHour >= 0 then
					local elapsed = (currentHour - lastHour + 24) % 24
					if elapsed < COOLDOWN_HOURS then continue end
				end
				-- 首次（LastEventHour == -99）跳过冷却检查

				-- ---- 随机触发 ----
				local chance = calcTriggerChance(data)
				if math.random() > chance then continue end

				-- ---- 选取事件 ----
				local available = getAvailableEvents(currentHour)
				if #available == 0 then continue end

				local evt = available[math.random(1, #available)]

				-- ---- 通知客户端 ----
				ChaosEvent:FireClient(player, {
					Type = "Event",
					EventId = evt.Id,
					Title = evt.Title,
					Desc = evt.Desc,
					Choices = evt.Choices,
				})

				-- ---- 记录事件时辰 ----
				data.LastEventHour = currentHour
				DataManager:UpdateField(player, "LastEventHour", currentHour)
			end
		end)
	end
end)

-- ============================================================
-- 接收客户端选择
-- ============================================================
ChaosEvent.OnServerEvent:Connect(function(player, eventId, choiceIndex)
	if type(eventId) ~= "string" or type(choiceIndex) ~= "number" then
		warn("⚠️ ChaosEvent: 参数类型错误", player.Name)
		return
	end

	local changes = ChaosEventService:MakeChoice(player, eventId, choiceIndex)
	if changes then
		ChaosEvent:FireClient(player, {
			Type = "ChoiceResult",
			EventId = eventId,
			ChoiceIndex = choiceIndex,
			Changes = changes,
		})
		-- 同时发送当前的混沌程度
		ChaosEvent:FireClient(player, {
			Type = "ChaosUpdate",
			ChaosLevel = ChaosEventService:GetChaosLevel(player),
		})
	else
		ChaosEvent:FireClient(player, {
			Type = "Error",
			Message = "选择无效或结局已触发",
		})
	end
end)

print("🔥 ChaosEventService 已启动（大闹天宫事件系统）")

return ChaosEventService
