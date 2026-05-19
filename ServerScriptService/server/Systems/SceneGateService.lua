-- ServerScriptService.Server.Systems.SceneGateService.lua
-- 场景条件评估服务 — 评估玩家在每个场景的状况，但永不锁定场景

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)
local StatusService = require(script.Parent.StatusService)
local Config = require(ReplicatedStorage.Shared.Config)

local SceneGateService = {}

-- TimeService 延迟加载（避免循环依赖）
local TimeService = nil
local function getTimeService()
	if not TimeService then
		TimeService = require(script.Parent.TimeService)
	end
	return TimeService
end

-- 评估单个场景
-- 返回 { status = "available"|"caution"|"warning", reason = "" }
function SceneGateService:EvaluateScene(player, sceneId)
	local data = DataManager:GetData(player)
	if not data then
		return { status = "available", reason = "" }
	end

	local timeMod = getTimeService().GetTimeModifier()

	if sceneId == "Home" then
		return { status = "available", reason = "" }

	elseif sceneId == "DanShop" then
		if (data.XianJing or 0) <= 0 then
			return { status = "caution", reason = "仙晶不足" }
		end
		return { status = "available", reason = "" }

	elseif sceneId == "YiShanFang" then
		local costs = StatusService:GetTaskCosts("Deliver")
		local staminaNeeded = (costs and costs.ActionCost and costs.ActionCost.Stamina) or 8
		local fatigue = data.Fatigue or 0

		if fatigue > Config.Stats.FATIGUE_REDLINE then
			return { status = "caution", reason = "疲劳" .. fatigue .. "（阈值" .. Config.Stats.FATIGUE_REDLINE .. "）" }
		end
		if (data.Stamina or 0) < staminaNeeded then
			return { status = "warning", reason = "体力不足（需" .. staminaNeeded .. "）" }
		end
		if (data.Stamina or 0) < staminaNeeded * 2 then
			return { status = "caution", reason = "体力偏低" }
		end
		return { status = "available", reason = "体力充足" }

	elseif sceneId == "Alchemy" then
		local costs = StatusService:GetTaskCosts("Alchemy")
		local spiritNeeded = (costs and costs.ActionCost and costs.ActionCost.Spirit) or 10
		local firePoison = data.FirePoison or 0

		if firePoison > Config.Stats.FIREPOISON_REDLINE then
			return { status = "warning", reason = "火毒" .. firePoison .. "（阈值" .. Config.Stats.FIREPOISON_REDLINE .. "）" }
		end
		if (data.Spirit or 0) < spiritNeeded then
			return { status = "warning", reason = "精神不足（需" .. spiritNeeded .. "）" }
		end
		if (data.Spirit or 0) < spiritNeeded * 2 then
			return { status = "caution", reason = "精神偏低" }
		end
		return { status = "available", reason = "精神充足" }

	elseif sceneId == "Beast" then
		local costs = StatusService:GetTaskCosts("Beast")
		local staminaNeeded = (costs and costs.ActionCost and costs.ActionCost.Stamina) or 12
		local malice = data.Malice or 0

		if malice > Config.Stats.MALICE_REDLINE then
			return { status = "warning", reason = "戾气" .. malice .. "（阈值" .. Config.Stats.MALICE_REDLINE .. "）" }
		end
		if (data.Stamina or 0) < staminaNeeded then
			return { status = "warning", reason = "体力不足（需" .. staminaNeeded .. "）" }
		end
		if (data.Stamina or 0) < staminaNeeded * 2 then
			return { status = "caution", reason = "体力偏低" }
		end
		return { status = "available", reason = "体力充足" }
	end

	return { status = "available", reason = "" }
end

-- 评估所有场景
function SceneGateService:EvaluateAllScenes(player)
	local sceneIds = { "YiShanFang", "Alchemy", "Beast", "DanShop", "Home" }
	local results = {}
	for _, id in ipairs(sceneIds) do
		results[id] = self:EvaluateScene(player, id)
	end
	return results
end

return SceneGateService
