-- ============================================================
-- 文件：ReplicatedStorage.Shared.Config.StatsConfig.lua
-- 功能：集中管理所有数值系统的常量配置
-- ============================================================

local StatsConfig = {
	-- ============================================================
	-- 即时状态（Current Status）上限
	-- ============================================================
	MAX_STAMINA = 100,
	MAX_SPIRIT = 100,
	MAX_FATIGUE = 100,
	MAX_FIRE_POISON = 100,
	MAX_MALICE = 100,

	-- ============================================================
	-- 状态恢复速率（每秒恢复量，StatusService 每 5 秒循环一次）
	-- ============================================================
	STAMINA_REGEN_PER_TICK = 1,   -- 每 5 秒回复 1
	SPIRIT_REGEN_PER_TICK = 1,    -- 每 5 秒回复 1
	REGEN_INTERVAL = 5,           -- 秒

	-- 疲劳 > 80 时恢复减半倍率
	FATIGUE_REGEN_REDUCTION = 0.5,

	-- ============================================================
	-- 等级经验阈值
	-- ============================================================
	EXP_PER_LEVEL = 30,           -- 每 30 经验升 1 级
	-- 注意：后续可扩展为阶梯表，如 { 30, 60, 100, 150, ... }

	-- ============================================================
	-- 红线阈值（Red Lines）
	-- ============================================================
	FATIGUE_REDLINE = 80,          -- 疲劳红线：速度 -40%，恢复 -50%
	FIREPOISON_REDLINE = 60,       -- 火毒红线：每 10s Stamina -5，炼丹成功率 -30%
	MALICE_REDLINE = 50,           -- 戾气红线：打坐禁用，天庭好感阴跌

	-- ============================================================
	-- 红线惩罚参数
	-- ============================================================
	FIREPOISON_DOT_INTERVAL = 10,  -- 火毒 DoT 间隔（秒）
	FIREPOISON_DOT_DAMAGE = 5,     -- 火毒每次扣 Stamina
	FATIGUE_SPEED_MULTIPLIER = 0.6, -- 疲劳 > 80 速度倍率
	TOXIN_SPEED_MULTIPLIER = 0.5,  -- 火毒 > 80 速度倍率
	FIREPOISON_SPEED_REDLINE = 80, -- 火毒速度惩罚阈值（高于 FIREPOISON_REDLINE 的严重状态）

	-- ============================================================
	-- 速度计算基础
	-- ============================================================
	BASE_SPEED = 16,
	AGILITY_SPEED_PER_LEVEL = 0.5, -- 每级身法增加 WalkSpeed

	-- ============================================================
	-- 任务消耗/收益参数
	-- ============================================================
	TASK_COSTS = {
		Deliver = {
			Stamina = -8, Spirit = -1, Fatigue = 5,
			AgilityExp = 5,
			Reward = { ["仙晶"] = 10 },
		},
		Alchemy = {
			Spirit = -10, FirePoison = 3, Fatigue = 3,
			AlchemyExp = 8,
			SuccessReward = { ["仙晶"] = 15 },
			FailureCost = { Fatigue = 8, FirePoison = 5 }, -- 炸炉额外
			FailurePenalty = { XianJing = -5 },
		},
		Beast = {
			Stamina = -12, Malice = 5,
			CombatExp = 10,
			Reward = { ["仙晶"] = 25 },
		},
	},

	-- ============================================================
	-- 连锁反应参数
	-- ============================================================
	CHAIN_REACTION = {
		-- 过劳螺旋: Fatigue>80 时额外消耗
		OVERWORK_EXTRA_FATIGUE = 2,
		OVERWORK_SPIRIT_REDUCTION = 0.7,
		-- 累倒: Fatigue>90
		COLLAPSE_CHANCE = 0.1,
		COLLAPSE_DURATION = 5,
		COLLAPSE_FATIGUE_RESET = 50,
		COLLAPSE_STAT_PENALTY = 10,
		-- 昏厥: Fatigue=100
		FAINT_DURATION = 10,
		-- 火毒 DoT
		FIREPOISON_DOT_INTERVAL = 10,
		FIREPOISON_DOT_DAMAGE = 5,
		FIREPOISON_SEVERE_DOT_INTERVAL = 5,
		FIREPOISON_FATIGUE_INTERVAL = 30,
		FIREPOISON_FATIGUE_AMOUNT = 1,
		-- 火毒加速
		FIREPOISON_SPIRIT_INTERVAL = 30,
		FIREPOISON_SPIRIT_DAMAGE = 2,
		-- 火毒影响
		FIREPOISON_ALCHEMY_PENALTY = 0.3,
		FIREPOISON_SEVERE_ALCHEMY_PENALTY = 0.5,
		FIREPOISON_MEDICINE_HALVE_THRESHOLD = 90,
		-- 戾气影响
		MALICE_RISK_AMPLIFY = 2,
		MALICE_SHOP_PENALTY = 0.2,
		MALICE_MURDER_CYCLE_THRESHOLD = 90,
		MALICE_MURDER_EXTRA = 5,
		-- 链式反应条件
		CHAIN_EXHAUSTION_FATIGUE = 80,
		CHAIN_EXHAUSTION_POISON = 60,
		CHAIN_DEMON_MALICE = 50,
		CHAIN_DEMON_RISK = 60,
		CHAIN_BURNOUT_STAMINA = 20,
		CHAIN_BURNOUT_SPIRIT = 20,
		CHAIN_TOXIN_FIREPOISON = 80,
		CHAIN_TOXIN_MALICE = 60,
		CHAIN_RAGE_FATIGUE = 80,
		CHAIN_RAGE_MALICE = 80,
	},

	-- ============================================================
	-- 时间系统
	-- ============================================================
	DAY_CYCLE_MINUTES = 12,        -- 12 分钟 = 1 天
	MIDNIGHT_FATIGUE_REDUCTION = -30, -- 深夜结算减 30 疲劳
}

return StatsConfig
