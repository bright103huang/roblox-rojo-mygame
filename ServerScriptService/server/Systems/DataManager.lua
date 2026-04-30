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

local function getDefaultData()
	return {
		XianJing = 0,
		GongDe = 0,
		CurrentScene = "Work",
		HasQuitJob = false,
		Risk = 10,
		DeliverCount = 0,
		SpeedBonus = 0,
	}
end

local function loadPlayerData(player)
	local userId = player.UserId

	-- 1. 优先检查当前会话的内存缓存（重连等情况）
	local cached = memoryStorage[userId]
	if cached then
		print("📥 从内存缓存加载存档：" .. player.Name)
		return cached
	end

	-- 2. 尝试 DataStore（正式环境）
	if dataStore then
		local success, result = pcall(function()
			return dataStore:GetAsync(userId)
		end)
		if success and result then
			print("📥 加载存档成功：" .. player.Name)
			return result
		elseif not success then
			warn("❌ DataStore 读取失败：" .. tostring(result) .. "，回退内存")
		end
	end

	-- 3. 新玩家，使用默认数据
	print("📦 新玩家，使用默认数据：" .. player.Name)
	return getDefaultData()
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
	end
	player:SetAttribute("Risk", data.Risk)

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
		end
	elseif field == "Risk" then
		player:SetAttribute("Risk", value)
	end
	-- DeliverCount 和 SpeedBonus 存储在 DataManager 缓存中
	-- 通过 GetData / ApplySpeed 访问，无需同步到 leaderstats
end

-- 应用移动速度到角色（基础速度 + 成长加成）
function DataManager:ApplySpeed(player)
	local data = playerDataCache[player.UserId]
	if not data then return end

	local char = player.Character
	if not char then return end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local baseSpeed = 16
	local totalSpeed = baseSpeed + (data.SpeedBonus or 0)
	humanoid.WalkSpeed = totalSpeed
	print("🏃 已设置 " .. player.Name .. " 的 WalkSpeed = " .. totalSpeed
		.. " (基础 " .. baseSpeed .. " + 加成 " .. (data.SpeedBonus or 0) .. ")")
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