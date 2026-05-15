-- ReplicatedStorage/Shared/PureLogic/SleepLogic.lua
-- 纯逻辑：睡眠品质判定与恢复计算（无 Roblox API 依赖）

local DEFAULT_CONFIG = {
	DeepThreshold = 0.8,
	LightThreshold = 0.5,
	RestlessThreshold = 0.25,
	MAX_STAMINA = 100,
	MAX_SPIRIT = 100,
	DeepSpiritRecovery = 20,
	LightStaminaRecovery = 30,
	LightSpiritRecovery = 10,
	LightFatigueLoss = 15,
	RestlessStaminaRecovery = 15,
	RestlessSpiritRecovery = 5,
	RestlessFatigueLoss = 5,
	InsomniaStaminaRecovery = 5,
	InsomniaFatigueLoss = 2,
	ExpPerDeepSleep = 3,
	ExpPerLightSleep = 1,
}

local SleepLogic = {}

--[[
	根据安宁占比判定睡眠品质
	@param ratio number — 安宁区停留时间占比 (0~1)
	@param config table? — 配置覆盖（默认使用 DEFAULT_CONFIG）
	@return string — "酣睡" | "浅睡" | "辗转" | "失眠"
]]
function SleepLogic.CalcSleepQuality(ratio, config)
	config = config or DEFAULT_CONFIG
	if ratio >= config.DeepThreshold then return "酣睡" end
	if ratio >= config.LightThreshold then return "浅睡" end
	if ratio >= config.RestlessThreshold then return "辗转" end
	return "失眠"
end

--[[
	根据品质和当前状态计算恢复数值
	@param quality string — CalcSleepQuality 的返回值
	@param current {Stamina, Spirit, Fatigue, Malice}
	@param config table? — 配置覆盖
	@return {Stamina, Spirit, Fatigue, Malice, Exp}
]]
function SleepLogic.CalcSleepRecovery(quality, current, config)
	config = config or DEFAULT_CONFIG
	local c = current or {}
	local result = {
		Stamina = c.Stamina or 0,
		Spirit = c.Spirit or 0,
		Fatigue = c.Fatigue or 0,
		Malice = c.Malice or 0,
		Exp = 0,
	}

	if quality == "酣睡" then
		result.Stamina = config.MAX_STAMINA
		result.Spirit = math.min(config.MAX_SPIRIT, result.Spirit + config.DeepSpiritRecovery)
		result.Fatigue = 0
		result.Malice = math.max(0, result.Malice - 8)
		result.Exp = config.ExpPerDeepSleep
	elseif quality == "浅睡" then
		result.Stamina = math.min(config.MAX_STAMINA, result.Stamina + config.LightStaminaRecovery)
		result.Spirit = math.min(config.MAX_SPIRIT, result.Spirit + config.LightSpiritRecovery)
		result.Fatigue = math.max(0, result.Fatigue - config.LightFatigueLoss)
		result.Malice = math.max(0, result.Malice - 3)
		result.Exp = config.ExpPerLightSleep
	elseif quality == "辗转" then
		result.Stamina = math.min(config.MAX_STAMINA, result.Stamina + config.RestlessStaminaRecovery)
		result.Spirit = math.min(config.MAX_SPIRIT, result.Spirit + config.RestlessSpiritRecovery)
		result.Fatigue = math.max(0, result.Fatigue - config.RestlessFatigueLoss)
	else
		result.Stamina = math.min(config.MAX_STAMINA, result.Stamina + config.InsomniaStaminaRecovery)
		result.Fatigue = math.max(0, result.Fatigue - config.InsomniaFatigueLoss)
	end

	return result
end

return SleepLogic
