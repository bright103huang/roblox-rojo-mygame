-- ============================================================
-- 文件：ServerScriptService.Server.Systems.ShopService.server.lua
-- 功能：仙丹阁商店服务 — 购买逻辑、限购检查、效果发放
-- 通信：使用独立的 ShopEvent RemoteEvent（避免与 TaskService 冲突）
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DanConfig = require(ReplicatedStorage.Shared.Config.DanConfig)
local DataManager = require(script.Parent.DataManager)
local StatusService = require(script.Parent.StatusService)

-- ============================================================
-- 确保 ShopEvent 存在
-- ============================================================
local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not eventsFolder then
	eventsFolder = Instance.new("Folder")
	eventsFolder.Name = "Events"
	eventsFolder.Parent = ReplicatedStorage
end

local ShopEvent = eventsFolder:FindFirstChild("ShopEvent")
if not ShopEvent then
	ShopEvent = Instance.new("RemoteEvent")
	ShopEvent.Name = "ShopEvent"
	ShopEvent.Parent = eventsFolder
end

-- ============================================================
-- ShopService
-- ============================================================

local ShopService = {}

-- 查询玩家的当日已购次数（自动执行限购刷新检查）
function ShopService:GetDailyPurchases(player)
	local data = DataManager:GetData(player)
	if not data then return {} end

	-- 限购刷新检查
	self:CheckReset(player, data)

	return data.DailyPurchases or {}
end

-- 检查是否需要重置限购数据
function ShopService:CheckReset(player, data)
	local now = os.time()
	local lastReset = data.LastPurchaseReset or 0
	local elapsed = now - lastReset

	if elapsed >= DanConfig.ResetInterval then
		data.DailyPurchases = {}
		data.LastPurchaseReset = now
		print("🔄 限购已刷新：" .. player.Name)
	end
end

-- 购买丹药
-- 返回: resultCode, message
-- resultCode: "Success", "InsufficientFunds", "DailyLimitReached", "ShopClosed", "UnknownItem"
function ShopService:Purchase(player, itemKey)
	local data = DataManager:GetData(player)
	if not data then
		return "UnknownItem", "数据未加载"
	end

	-- 检查营业时间
	if player:GetAttribute("ShopOpen") == 0 then
		return "ShopClosed", "仙丹阁已打烊，营业时间：未时-戌时 (12:00-22:00)"
	end

	local item = DanConfig.Items[itemKey]
	if not item then
		return "UnknownItem", "未知商品"
	end

	-- 限购刷新检查
	self:CheckReset(player, data)

	-- 检查限购次数
	if item.DailyLimit and item.DailyLimit > 0 then
		local purchases = data.DailyPurchases or {}
		local count = purchases[itemKey] or 0
		if count >= item.DailyLimit then
			return "DailyLimitReached", "今日已限购 " .. tostring(count) .. "/" .. tostring(item.DailyLimit)
		end
	end

	-- 检查仙晶
	local xianJing = data.XianJing or 0
	if xianJing < item.Price then
		return "InsufficientFunds", "仙晶不足（需要 " .. tostring(item.Price) .. "）"
	end

	-- 扣除仙晶
	data.XianJing = xianJing - item.Price
	DataManager:UpdateField(player, "XianJing", data.XianJing)

	-- 更新购买次数
	if item.DailyLimit and item.DailyLimit > 0 then
		local purchases = data.DailyPurchases or {}
		purchases[itemKey] = (purchases[itemKey] or 0) + 1
		data.DailyPurchases = purchases
	end

	-- 发放效果
	local effectType = item.EffectType
	local effectValue = item.EffectValue

	if effectType == "Stamina" or effectType == "Spirit"
		or effectType == "Fatigue" or effectType == "FirePoison"
		or effectType == "Malice" then
		-- 即时状态：通过 ApplyCosts 处理（支持正/负值）
		local costs = {}
		costs[effectType] = effectValue
		StatusService:ApplyCosts(player, costs)

	elseif effectType == "AgilityExp" then
		StatusService:AddExp(player, "Agility", effectValue)

	elseif effectType == "AlchemyExp" then
		StatusService:AddExp(player, "AlchemyLv", effectValue)

	elseif effectType == "CombatExp" then
		StatusService:AddExp(player, "Combat", effectValue)

	elseif effectType == "RandomStat" then
		local stats = { "Agility", "AlchemyLv", "Combat" }
		local chosen = stats[math.random(1, #stats)]
		StatusService:AddExp(player, chosen, effectValue)
		local nameMap = { Agility = "身法", AlchemyLv = "火候", Combat = "仙力" }
		return "Success", "购买成功！" .. (nameMap[chosen] or chosen) .. " +1"

	elseif effectType == "AllStats" then
		StatusService:AddExp(player, "Agility", effectValue)
		StatusService:AddExp(player, "AlchemyLv", effectValue)
		StatusService:AddExp(player, "Combat", effectValue)
		return "Success", "购买成功！全属性 +1"
	end

	print("🛒 " .. player.Name .. " 购买了 " .. (item.RealName or item.Name))
	return "Success", "购买成功！获得 " .. (item.RealName or item.Name)
end

-- ============================================================
-- 监听客户端请求
-- ============================================================
ShopEvent.OnServerEvent:Connect(function(player, action, legacyArg, contextData)
	-- 打开商店
	if action == "Pick:Shop" then
		local data = DataManager:GetData(player)
		if not data then return end

		-- 检查营业时间
		if player:GetAttribute("ShopOpen") == 0 then
			ShopEvent:FireClient(player, "ShopClosed", {
				Message = "仙丹阁已打烊，营业时间：未时-戌时 (12:00-22:00)",
			})
			return
		end

		-- 检查限购刷新
		ShopService:CheckReset(player, data)

		-- 朦胧机制：检查并更新已揭晓的丹药
		if not data.RevealedShopItems then
			data.RevealedShopItems = {}
		end
		local revealed = data.RevealedShopItems

		-- 发送商品列表和已购数据到客户端
		local items = {}
		for key, cfg in pairs(DanConfig.Items) do
			local showReal = true
			if cfg.RevealThreshold and cfg.RevealThreshold > 0 then
				if not revealed[key] then
					if (data.XianJing or 0) >= cfg.RevealThreshold then
						revealed[key] = true
						DataManager:UpdateField(player, "RevealedShopItems", revealed)
					else
						showReal = false
					end
				end
			end

			if showReal then
				items[key] = {
					Name = cfg.RealName or cfg.Name,
					Description = cfg.RealDescription or cfg.Description,
					Price = cfg.Price,
					EffectType = cfg.EffectType,
					EffectValue = cfg.EffectValue,
					DailyLimit = cfg.DailyLimit,
				}
			else
				items[key] = {
					Name = cfg.Name,
					Description = cfg.Description,
					Price = cfg.Price,
					EffectType = cfg.EffectType,
					EffectValue = cfg.EffectValue,
					DailyLimit = cfg.DailyLimit,
					IsHidden = true,
				}
			end
		end

		ShopEvent:FireClient(player, "OpenShop", {
			Items = items,
			DailyPurchases = data.DailyPurchases or {},
			XianJing = data.XianJing or 0,
		})
		return
	end

	-- 购买商品
	if action == "Purchase:Shop" then
		local itemKey = contextData and contextData.ItemKey
		if not itemKey then return end

		local result, message = ShopService:Purchase(player, itemKey)

		-- 返回购买结果及更新后的仙晶余额
		local data = DataManager:GetData(player)

		ShopEvent:FireClient(player, "PurchaseResult:Shop", {
			Success = result == "Success",
			Result = result,
			Message = message,
			XianJing = data and data.XianJing or 0,
			DailyPurchases = data and data.DailyPurchases or {},
		})
		return
	end
end)

print("✅ ShopService 已启动")

return ShopService
