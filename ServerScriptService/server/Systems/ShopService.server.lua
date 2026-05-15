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

-- ============================================================
-- 砍价对话题库
-- ============================================================
local BARGAIN_QUESTIONS = {
	{
		Question = "我这丹可都是太上老君亲传的配方，贵自然有贵的道理！",
		Options = { "那是那是，老板一看就是高人！", "少吹牛了，便宜点", "隔壁也卖这个价" },
		Correct = 1,
	},
	{
		Question = "你天天来砍价，我生意还做不做了？",
		Options = { "我这是给你带人气啊", "不卖拉倒", "下次我给你介绍客户" },
		Correct = 1, CorrectAlt = 3,
	},
	{
		Question = "这玉灵丹成本高，真的不能再低了",
		Options = { "老板实诚人，那我多买几颗", "成本高是你的事", "你再降点嘛" },
		Correct = 1,
	},
	{
		Question = "我看你面生，是第一次来吧？",
		Options = { "慕名而来！都说您这丹药正宗", "第一次就不能打折？", "你管我第几次" },
		Correct = 1,
	},
	{
		Question = "这价格已经是最低价了",
		Options = { "就冲您这爽快劲儿，我再加购一颗", "少来这套", "求求你了老板" },
		Correct = 1,
	},
	{
		Question = "你上次砍价成功，我亏了不少",
		Options = { "那说明您人好，好人会有好报的！", "你亏不亏关我啥事", "那你这次涨回去不就得了" },
		Correct = 1,
	},
	{
		Question = "我看你身上有妖气，刚从妖兽战场来吧？",
		Options = { "老板好眼力！所以需要丹药补补", "少打听", "你怎么知道" },
		Correct = 1,
	},
	{
		Question = "你知道我这丹药用什么炼的吗？百年灵芝！",
		Options = { "难怪灵气这么足，值这个价！", "百年？你骗谁呢", "那更该便宜点啦" },
		Correct = 1,
	},
	{
		Question = "我这店小本经营，你再砍价我要去喝西北风了",
		Options = { "老板说笑了，您这店气派得很", "那你去喝吧", "我也穷啊" },
		Correct = 1,
	},
	{
		Question = "你旁边那位昨天也来砍价了",
		Options = { "那更说明您这店受欢迎啊！", "他买多少我不管", "他人怎么样" },
		Correct = 1,
	},
	{
		Question = "这丹药吃了能延年益寿，绝对值这个价",
		Options = { "那我更要买了，健康无价！", "延年益寿？骗鬼呢", "能延多少年" },
		Correct = 1,
	},
	{
		Question = "你要真想买，我送你一句忠告",
		Options = { "老板请讲，洗耳恭听！", "别啰嗦了", "你送丹药更实在" },
		Correct = 1,
	},
}

-- ============================================================
-- 砍价状态（每个玩家每次面板打开期间的砍价记录）
-- ============================================================
local pendingBargains = {}

function ShopService:RequestBargainQuestion(player, itemKey)
	local uid = player.UserId
	if pendingBargains[uid] and pendingBargains[uid][itemKey] ~= nil then
		return { Question = nil }
	end
	local qId = math.random(1, #BARGAIN_QUESTIONS)
	local q = BARGAIN_QUESTIONS[qId]
	return { Question = q.Question, Options = q.Options, QuestionId = qId }
end

function ShopService:SubmitBargainAnswer(player, itemKey, questionId, chosenOption)
	local q = BARGAIN_QUESTIONS[questionId]
	if not q then return { Success = false, Message = "无效选项" } end

	local uid = player.UserId
	if pendingBargains[uid] and pendingBargains[uid][itemKey] ~= nil then
		return { Success = false, Message = "已砍过价了" }
	end

	local isCorrect = (chosenOption == q.Correct) or (q.CorrectAlt and chosenOption == q.CorrectAlt)
	if not pendingBargains[uid] then pendingBargains[uid] = {} end
	if isCorrect then
		pendingBargains[uid][itemKey] = true
		return { Success = true, Message = "老板很开心！给你打 8 折！" }
	else
		pendingBargains[uid][itemKey] = false
		return { Success = false, Message = "老板不高兴，还是原价吧" }
	end
end

function ShopService:GetBargainDiscount(player, itemKey)
	local uid = player.UserId
	if pendingBargains[uid] and pendingBargains[uid][itemKey] == true then
		return 0.8
	end
	return 1.0
end

function ShopService:ClearBargains(player)
	pendingBargains[player.UserId] = nil
end

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
	local discount = ShopService:GetBargainDiscount(player, itemKey)
	local finalPrice = math.floor(item.Price * discount)
	if xianJing < finalPrice then
		return "InsufficientFunds", "仙晶不足（需要 " .. tostring(finalPrice) .. "）"
	end

	-- 扣除仙晶（折后价）
	data.XianJing = xianJing - finalPrice
	DataManager:UpdateField(player, "XianJing", data.XianJing)
	if discount < 1 then
		print("💰 " .. player.Name .. " 砍价成功！" .. (item.RealName or item.Name) .. " $" .. item.Price .. "→" .. finalPrice)
	end

	-- 更新购买次数
	if item.DailyLimit and item.DailyLimit > 0 then
		local purchases = data.DailyPurchases or {}
		purchases[itemKey] = (purchases[itemKey] or 0) + 1
		data.DailyPurchases = purchases
	end

	-- 改为存入背包
	local backpack = data.Backpack or {}
	backpack[itemKey] = (backpack[itemKey] or 0) + 1
	data.Backpack = backpack
	DataManager:UpdateField(player, "Backpack", backpack)

	print("🛒 " .. player.Name .. " 购买了 " .. (item.RealName or item.Name) .. "（背包 +1）")
	return "Success", "购买成功！" .. (item.RealName or item.Name) .. " 已存入背包"
end



-- ============================================================
-- 使用物品（从背包消耗，应用效果）
-- isMeditating: 打坐状态效果 x1.5
-- ============================================================
function ShopService:UseItem(player, itemKey, isMeditating)
	if not isMeditating then
		return { Success = false, Message = "丹药需在打坐时炼化" }
	end
	local data = DataManager:GetData(player)
	if not data then return { Success = false, Message = "数据未加载" } end
	local backpack = data.Backpack or {}
	local count = backpack[itemKey] or 0
	if count <= 0 then return { Success = false, Message = "背包中没有该物品" } end
	local item = DanConfig.Items[itemKey]
	if not item then return { Success = false, Message = "未知物品" } end
	backpack[itemKey] = count - 1
	if backpack[itemKey] <= 0 then backpack[itemKey] = nil end
	data.Backpack = backpack
	DataManager:UpdateField(player, "Backpack", backpack)
	local effectValue = item.EffectValue
	if isMeditating then
		effectValue = math.floor(effectValue * 1.5)
	end
	local effectType = item.EffectType
	if effectType == "Stamina" or effectType == "Spirit"
		or effectType == "Fatigue" or effectType == "FirePoison"
		or effectType == "Malice" then
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
	elseif effectType == "AllStats" then
		StatusService:AddExp(player, "Agility", effectValue)
		StatusService:AddExp(player, "AlchemyLv", effectValue)
		StatusService:AddExp(player, "Combat", effectValue)
	end
	print("💊 " .. player.Name .. " 使用了 " .. (item.RealName or item.Name))
	return { Success = true, Message = "使用成功" }
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
		ShopService:ClearBargains(player)
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
			Backpack = data.Backpack or {},
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
				Backpack = data and data.Backpack or {},
		})
		return
	end

	-- 砍价（2 步协议：先请求题目，再提交答案）
	if action == "Bargain:Shop" then
		local itemKey = contextData and contextData.ItemKey
		local choiceIndex = contextData and contextData.ChoiceIndex
		if not itemKey then return end

		-- 检查营业时间
		if player:GetAttribute("ShopOpen") == 0 then
			ShopEvent:FireClient(player, "BargainResult", {
				Success = false,
				Message = "仙丹阁已打烊",
			})
			return
		end

		if not choiceIndex then
			-- Step 1: 请求题目
			local result = ShopService:RequestBargainQuestion(player, itemKey)
			ShopEvent:FireClient(player, "BargainQuestion", {
				ItemKey = itemKey,
				Question = result.Question,
				Options = result.Options,
				QuestionId = result.QuestionId,
			})
		else
			-- Step 2: 提交答案
			local questionId = contextData and contextData.QuestionId
			if not questionId then
				questionId = choiceIndex -- 兼容旧客户端
			end
			local result = ShopService:SubmitBargainAnswer(player, itemKey, questionId, choiceIndex)
			ShopEvent:FireClient(player, "BargainResult", {
				Success = result.Success,
				Message = result.Message,
				ItemKey = itemKey,
			})
		end
		return
	end

	-- 使用物品
	if action == "UseItem:Shop" then
		local itemKey = contextData and contextData.ItemKey
		local isMeditating = contextData and contextData.IsMeditating or false
		if not itemKey then return end

		local result = ShopService:UseItem(player, itemKey, isMeditating)

		local data = DataManager:GetData(player)
		ShopEvent:FireClient(player, "UseItemResult", {
			Success = result.Success,
			Message = result.Message,
			Backpack = data and data.Backpack or {},
		})
		return
	end
end)

print("✅ ShopService 已启动")

return ShopService
