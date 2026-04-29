-- ServerScriptService.Server.Systems.DataManager.luau

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- 检测是否在 Studio 中运行（未经发布的游戏无法使用 DataStore）
local isStudio = RunService:IsStudio() and not RunService:IsRunning()

local dataStore
local testStorage = {}  -- 内存存储，用于 Studio 测试

-- 尝试连接 DataStore，失败则使用内存
local function getDataStore()
	local success, result = pcall(function()
		return DataStoreService:GetDataStore("PlayerData_V1")
	end)
	if success then
		return result
	else
		warn("⚠️ DataStore 不可用（需发布游戏），使用临时内存存储。退出游戏后数据会丢失。")
		return nil
	end
end

dataStore = getDataStore()

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
	local data

	if dataStore then
		local success, result = pcall(function()
			return dataStore:GetAsync(userId)
		end)
		if success and result then
			print("📥 加载存档成功：" .. player.Name)
			return result
		else
			if not success then
				warn("❌ 读取存档失败：" .. tostring(result))
			end
		end
	else
		-- 使用内存存储（Studi o 测试模式）
		data = testStorage[userId]
		if data then
			print("📥 从内存加载存档：" .. player.Name)
			return data
		end
	end

	print("📦 新玩家，使用默认数据：" .. player.Name)
	return getDefaultData()
end

local function savePlayerData(player, data)
	local userId = player.UserId
	if dataStore then
		local success, err = pcall(function()
			dataStore:SetAsync(userId, data)
		end)
		if success then
			print("💾 保存成功：" .. player.Name)
		else
			warn("❌ 保存失败：" .. tostring(err))
		end
	else
		testStorage[userId] = data
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