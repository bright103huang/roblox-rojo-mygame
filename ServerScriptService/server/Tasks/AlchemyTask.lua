-- ============================================================
-- 文件：ServerScriptService.Server.Tasks.AlchemyTask.lua
-- 功能：密室炼丹任务处理器
-- 架构：Task Handler 模式，被 TaskService 调度器调用
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(script.Parent.Parent.Systems.DataManager)
local StatusService = require(script.Parent.Parent.Systems.StatusService)
local Config = require(ReplicatedStorage.Shared.Config)

-- ============================================================
-- 丹方数据
-- ============================================================
local RECIPES = {
	{
		Name = "回气丹",
		Ingredients = { "草药", "清水" },
		Description = "恢复体力",
		SpiritReq = 20,
		Difficulty = 0.7,  -- 基础成功率 70%
	},
	{
		Name = "清毒散",
		Ingredients = { "草药", "火晶" },
		Description = "降低火毒",
		SpiritReq = 30,
		Difficulty = 0.5,
	},
	{
		Name = "聚神丹",
		Ingredients = { "灵芝", "仙露" },
		Description = "提升精神上限",
		SpiritReq = 40,
		Difficulty = 0.3,
	},
}

-- 所有可用药材
local AVAILABLE_INGREDIENTS = { "草药", "清水", "灵芝", "仙露", "火晶" }

-- 尝试次数限制（防止无限刷）
local MAX_CRAFT_ATTEMPTS = 5

-- ============================================================
-- 状态
-- ============================================================
local carrying = {}  -- [userId] = true
local craftCount = {}  -- [userId] = number (当日炼丹次数，用于数据参考)

-- ============================================================
-- 辅助：查找匹配的丹方
-- ============================================================
local function findRecipe(selectedIngredients)
	if not selectedIngredients or #selectedIngredients < 2 then
		return nil
	end

	-- 排序后比较（忽略顺序）
	local sorted = table.clone(selectedIngredients)
	table.sort(sorted)

	for _, recipe in ipairs(RECIPES) do
		local reqSorted = table.clone(recipe.Ingredients)
		table.sort(reqSorted)

		if #sorted == #reqSorted then
			local match = true
			for i = 1, #sorted do
				if sorted[i] ~= reqSorted[i] then
					match = false
					break
				end
			end
			if match then
				return recipe
			end
		end
	end

	return nil
end

-- ============================================================
-- 获取 TaskEvent RemoteEvent
-- ============================================================
local function getTaskEvent()
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then return nil end
	return eventsFolder:FindFirstChild("TaskEvent")
end

-- ============================================================
-- AlchemyTask（处理器接口）
-- ============================================================

local AlchemyTask = {}

-- 玩家触摸材料台：捡起药材
function AlchemyTask.OnPlayerPickup(player, _area)
	if carrying[player.UserId] then
		return false  -- 已经拿着药材了
	end

	-- 检查精神是否足够
	local canPerform, reason = StatusService:CanPerformTask(player, { Spirit = 20 })
	if not canPerform then
		print("❌ " .. player.Name .. " 炼丹失败：" .. tostring(reason))
		return false
	end

	carrying[player.UserId] = true
	craftCount[player.UserId] = (craftCount[player.UserId] or 0) + 1
	return true
end

-- 玩家触摸丹炉：打开炼丹 UI
function AlchemyTask.OnPlayerDrop(player, _area)
	if not carrying[player.UserId] then
		return false, "NotCarrying"
	end

	-- 不立即消耗 carrying — UI 打开后客户端会处理
	-- 让客户端打开炼丹 UI
	local taskEvent = getTaskEvent()
	if taskEvent then
		taskEvent:FireClient(player, "OpenAlchemyUI", {
			AvailableIngredients = AVAILABLE_INGREDIENTS,
			Recipes = RECIPES,
			CraftCount = (craftCount[player.UserId] or 0),
		})
	end

	return true, "OpenUI"
end

-- 玩家确认炼制（由客户端 UI 触发）
function AlchemyTask.OnCraft(player, contextData)
	if not carrying[player.UserId] then
		return false, "NotCarrying"
	end

	-- 限制炼制次数
	if (craftCount[player.UserId] or 0) > MAX_CRAFT_ATTEMPTS then
		return false, "MaxAttempts"
	end

	local data = DataManager:GetData(player)
	if not data then return false, "NoData" end

	local selected = contextData and contextData.Ingredients
	if not selected or #selected < 2 then
		return false, "InvalidIngredients"
	end

	local recipe = findRecipe(selected)
	if not recipe then
		-- 无效配方：扣除材料，不消耗精神，提示失败
		carrying[player.UserId] = false
		return true, { Success = false, Reason = "InvalidRecipe" }
	end

	-- 检查精神是否满足配方要求
	if (data.Spirit or 0) < recipe.SpiritReq then
		carrying[player.UserId] = false
		return true, {
			Success = false,
			Reason = "SpiritTooLow",
			SpiritReq = recipe.SpiritReq,
		}
	end

	-- 计算成功率
	local alchemyLv = data.AlchemyLv or 1
	local baseChance = recipe.Difficulty
	local levelBonus = alchemyLv * 0.05  -- 每级 +5%
	local firePoison = data.FirePoison or 0
	local firePoisonPenalty = firePoison > Config.Stats.FIREPOISON_REDLINE and 0.3 or 0

	local successChance = math.clamp(baseChance + levelBonus - firePoisonPenalty, 0.1, 0.95)

	-- 掷骰决定结果
	local success = math.random() <= successChance

	-- 共同的消耗：Spirit -20, FirePoison +5, AlchemyExp +8
	local costs = {
		Spirit = -20,
		FirePoison = 5,
		AlchemyExp = 8,
	}

	if success then
		-- 成功：获得仙晶 + 丹药效果
		costs.XianJing = 15

		StatusService:ApplyCosts(player, costs)
		carrying[player.UserId] = false

		-- 丹药特殊效果
		local specialEffects = {}
		if recipe.Name == "回气丹" then
			-- 额外恢复 Stamina
			StatusService:ApplyCosts(player, { Stamina = 20 })
			specialEffects.Stamina = 20
		elseif recipe.Name == "清毒散" then
			-- 降低火毒
			StatusService:ApplyCosts(player, { FirePoison = -15 })
			specialEffects.FirePoison = -15
		elseif recipe.Name == "聚神丹" then
			-- 额外恢复 Spirit
			StatusService:ApplyCosts(player, { Spirit = 15 })
			specialEffects.Spirit = 15
		end

		return true, {
			Success = true,
			Recipe = recipe.Name,
			Description = recipe.Description,
			SuccessChance = math.floor(successChance * 100),
			SpecialEffects = specialEffects,
		}
	else
		-- 炸炉：消耗精神，增加疲劳，无经验和火毒
		StatusService:ApplyCosts(player, { Spirit = -20, Fatigue = 20 })
		carrying[player.UserId] = false

		return true, {
			Success = false,
			Reason = "Explosion",
			FatigueIncrease = 20,
		}
	end
end

return AlchemyTask
