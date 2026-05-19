-- ============================================================
-- 文件：ServerScriptService.Server.Systems.SpeedCalculator.lua
-- 功能：动态速度计算器
-- 公式：FinalSpeed = (BaseSpeed + Agility * 6) * StatusModifier
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(script.Parent.DataManager)
local Config = require(ReplicatedStorage.Shared.Config)

-- ============================================================
-- StatusModifier 计算
-- ============================================================
local function getStatusModifier(data)
	local modifier = 1.0

	-- 疲劳红线：速度 -40%
	if (data.Fatigue or 0) > Config.Stats.FATIGUE_REDLINE then
		modifier = modifier * Config.Stats.FATIGUE_SPEED_MULTIPLIER
	end

	-- 火毒红线：速度 -50%
	if (data.FirePoison or 0) > Config.Stats.FIREPOISON_SPEED_REDLINE then
		modifier = modifier * Config.Stats.TOXIN_SPEED_MULTIPLIER
	end

	return modifier
end

-- ============================================================
-- SpeedCalculator
-- ============================================================

local SpeedCalculator = {}

-- 计算玩家的理论速度
function SpeedCalculator.Calculate(player)
	local data = DataManager:GetData(player)
	if not data then return Config.Stats.BASE_SPEED end

	local agility = data.Agility or 1
	local baseSpeed = Config.Stats.BASE_SPEED
	local agilityBonus = agility * Config.Stats.AGILITY_SPEED_PER_LEVEL
	local modifier = getStatusModifier(data)

	return math.min(64, (baseSpeed + agilityBonus) * modifier)
end

-- 应用到 Humanoid
function SpeedCalculator.Apply(player)
	local char = player.Character
	if not char then return end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local speed = SpeedCalculator.Calculate(player)
	humanoid.WalkSpeed = speed
end

-- 获取当前状态修正倍率（用于客户端展示）
function SpeedCalculator.GetStatusModifier(player)
	local data = DataManager:GetData(player)
	if not data then return 1.0 end
	return getStatusModifier(data)
end

print("✅ SpeedCalculator 已加载")

return SpeedCalculator
