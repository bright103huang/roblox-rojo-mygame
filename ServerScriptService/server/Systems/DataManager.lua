-- ServerScriptService.Server.Systems.DataManager.luau

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

-- 内存存储，作为 Studio 测试及 DataStore 失效时的通用后备
local memoryStorage = {}

-- 尝试连接 DataStore，失败则使用内存
local function getDataStore()
	local success, result = pcall(function()
		return DataStoreService:GetDataStore("PlayerData_V1")
	end)
	if success then
		print("✅ DataStore 连接成功")
		return result
	else
		warn("⚠️ DataStore 不可用，使用临时内存存储。退出游戏后数据会丢失。")
		return nil
	end
end

local dataStore = getDataStore()

local playerDataCache = {}

local DEFAULT_DATA = {
	XianJing = 0,
	GongDe = 0,
	CurrentScene = "YiShanFang",
	HasQuitJob = false,
	Risk = 10,
	-- 废弃字段（保留兼容旧存档，代码中不再写入）
	DeliverCount = 0,
	SpeedBonus = 0,
	-- 新增 — 即时状态
	Stamina = 100,
	Spirit = 100,
	Fatigue = 0,
	FirePoison = 0,
	Malice = 0,
	-- 新增 — 永久属性（含经验）
	Agility = 1,
	AgilityExp = 0,
	AlchemyLv = 1,
	AlchemyExp = 0,
	Combat = 1,
	CombatExp = 0,
	-- 新增 — 时间
	TotalDays = 0,
	-- 新增 — 商店系统
	DailyPurchases = {},  -- { [itemKey] = count }
	LastPurchaseReset = 0,
	Backpack = {},        -- { [itemKey] = count }
	-- 新增 — 考编 & 天兵
	IsRecruited = false,   -- 是否已入职天兵
	Loyalty = 50,          -- 天庭忠诚度 (0-100)
	WukongFavor = 0,       -- 孙悟空好感度 (0-100)
	Chaos = 0,             -- 混沌值 (0-100)
	EndingReached = false,  -- 是否已达结局
	LastEventHour = -99,   -- 上次事件时辰
	Merit = 0,             -- 天兵功勋
	MilitaryRank = "天兵",  -- 军衔
	PatrolCount = 0,       -- 今日巡逻次数
	ExpelCount = 0,        -- 今日驱猴次数
		LastPrayerDate = "",   -- 上次祈福日期（防止重复）
		PrayerOption = "",     -- 最近选择的祈福类型
		LastSleptDay = "",     -- 最后睡觉日（格式 YYYYMMDD）
	RevealedShopItems = {},  -- 已揭晓的朦胧丹药 { "XiuWeiXiaoDan" = true }
}

local function getDefaultData()
	return DEFAULT_DATA
end

local function loadPlayerData(player)
	local userId = player.UserId

	-- 1. 优先检查当前会话的内存缓存（重连等情况）
	local cached = memoryStorage[userId]
	if cached then
		print("📥 从内存缓存加载存档：" .. player.Name)
		setmetatable(cached, { __index = DEFAULT_DATA })
		return cached
	end

	-- 2. 尝试 DataStore（正式环境）
	if dataStore then
		local success, result = pcall(function()
			return dataStore:GetAsync(userId)
		end)
		if success and result then
			print("📥 加载存档成功：" .. player.Name)
			-- 通过 metatable 保证旧存档缺少新字段时自动使用默认值
			setmetatable(result, { __index = DEFAULT_DATA })
			return result
		elseif not success then
			warn("❌ DataStore 读取失败：" .. tostring(result) .. "，回退内存")
		end
	end

	-- 3. 新玩家，使用默认数据
	print("📦 新玩家，使用默认数据：" .. player.Name)
	local data = getDefaultData()
	return data
end

local function savePlayerData(player, data)
	local userId = player.UserId
	-- 始终写入内存缓存
	memoryStorage[userId] = data

	if dataStore then
		local success, err = pcall(function()
			dataStore:SetAsync(userId, data)
		end)
		if success then
			print("💾 保存成功：" .. player.Name)
		else
			warn("❌ DataStore 保存失败：" .. tostring(err) .. "（数据已保留在内存中）")
		end
	else
		print("💾 已暂存到内存（仅当次有效）：" .. player.Name)
	end
end

local DataManager = {}

function DataManager:InitPlayer(player)
	local data = loadPlayerData(player)
	playerDataCache[player.UserId] = data

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local gold = leaderstats:FindFirstChild("仙晶")
		if gold then gold.Value = data.XianJing end
		local merit = leaderstats:FindFirstChild("功德")
		if merit then merit.Value = data.GongDe end
	else
		warn("DataManager:InitPlayer 未找到 leaderstats 文件夹！")
	end

	-- 同步所有即时状态为 Attribute（客户端可读）
	player:SetAttribute("Risk", data.Risk)
	player:SetAttribute("Stamina", data.Stamina)
	player:SetAttribute("Spirit", data.Spirit)
	player:SetAttribute("Fatigue", data.Fatigue)
	player:SetAttribute("FirePoison", data.FirePoison)
	player:SetAttribute("Malice", data.Malice)
	-- 同步属性等级
	player:SetAttribute("Agility", data.Agility or 1)
	player:SetAttribute("AlchemyLv", data.AlchemyLv or 1)
	player:SetAttribute("Combat", data.Combat or 1)
	-- 同步场景
	player:SetAttribute("CurrentScene", data.CurrentScene or "YiShanFang")
	-- 同步考编 & 天兵状态
	player:SetAttribute("IsRecruited", data.IsRecruited or false)
	player:SetAttribute("MilitaryRank", data.MilitaryRank or "天兵")
	player:SetAttribute("Merit", data.Merit or 0)

	return data
end

function DataManager:GetData(player)
	return playerDataCache[player.UserId]
end

function DataManager:UpdateField(player, field, value)
	local data = playerDataCache[player.UserId]
	if not data then return end
	data[field] = value

	if field == "XianJing" or field == "GongDe" then
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local stat = leaderstats:FindFirstChild(
				field == "XianJing" and "仙晶" or "功德"
			)
			if stat then
				stat.Value = value
			end
		else
			warn("DataManager:UpdateField 未找到 leaderstats 文件夹！")
		end
	elseif field == "Agility" or field == "AlchemyLv" or field == "Combat" then
		-- 永久属性等级同步到 Attribute（StatusUI 读取）
		player:SetAttribute(field, value)
	elseif field == "Risk" then
		player:SetAttribute("Risk", value)
	elseif field == "Stamina" or field == "Spirit" or field == "Fatigue"
		or field == "FirePoison" or field == "Malice" then
		-- 即时状态同步到 Attribute
		player:SetAttribute(field, value)
	elseif field == "CurrentScene" then
		player:SetAttribute("CurrentScene", value)
	elseif field == "Merit" or field == "MilitaryRank" then
		-- 天兵功勋/军衔同步到 Attribute（StatusUI 读取）
		player:SetAttribute(field, value)
	end
	-- AgilityExp / AlchemyExp / CombatExp / TotalDays
	-- 存储在 DataManager 缓存中，无需同步到客户端
end

-- ApplySpeed 临时实现（使用身法系统）
-- 后续由 SpeedCalculator（Phase 2）替代
function DataManager:ApplySpeed(player)
	local data = playerDataCache[player.UserId]
	if not data then return end

	local char = player.Character
	if not char then return end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local agility = data.Agility or 1
	local fatigue = data.Fatigue or 0
	local firePoison = data.FirePoison or 0
	local baseSpeed = 16
	local agilityBonus = agility * 0.5
	local modifier = 1.0
	if fatigue > 80 then modifier = 0.6 end
	if firePoison > 80 then modifier = 0.5 end

	local totalSpeed = (baseSpeed + agilityBonus) * modifier
	humanoid.WalkSpeed = totalSpeed
	print("🏃 已设置 " .. player.Name .. " 的 WalkSpeed = " .. totalSpeed)
end

function DataManager:Save(player)
	local data = playerDataCache[player.UserId]
	if not data then return end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local gold = leaderstats:FindFirstChild("仙晶")
		if gold then data.XianJing = gold.Value end
		local merit = leaderstats:FindFirstChild("功德")
		if merit then data.GongDe = merit.Value end
	end
	data.Risk = player:GetAttribute("Risk") or 0
	savePlayerData(player, data)
end

Players.PlayerRemoving:Connect(function(player)
	DataManager:Save(player)
	playerDataCache[player.UserId] = nil
end)

return DataManager
