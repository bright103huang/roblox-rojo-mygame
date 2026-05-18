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
	BASE_SPEED = 32,
	AGILITY_SPEED_PER_LEVEL = 0.5, -- 每级身法增加 WalkSpeed

	-- ============================================================
	-- 任务消耗/收益参数
	-- ============================================================
	TASK_COSTS = {
		Deliver = {
			ActionCost = { Stamina = 8 },
			ApplyCost = { Stamina = -8, Spirit = -1, Fatigue = 5, AgilityExp = 5, XianJing = 10 },
			Display = "体力-8  疲劳+5  身法exp+5  仙晶+10",
		},
		Alchemy = {
			ActionCost = { Spirit = 5 },    -- 每次动作最低精神门槛
			ApplyCost = { AlchemyExp = 8, XianJing = 15, FirePoison = 3 },  -- 成丹奖励
			FailureCost = { Spirit = -15, Fatigue = 20 },   -- 炸炉惩罚
			Display = "精神-29/轮  火候exp+8  仙晶+15",
		},
		Beast = {
			ActionCost = { Stamina = 12 },
			ApplyCost = { Stamina = -8, Malice = 3, CombatExp = 8, XianJing = 20 },
			Display = "入场体力-12 | 碰撞3回决胜 | 仙力exp+8  仙晶+20",
		},
		Patrol = {
			ActionCost = { Stamina = 10 },
			ApplyCost = { Stamina = -10, Merit = 1, XianJing = 5 },
		},
		ExpelMonkey = {
			ActionCost = { Stamina = 8 },
			ApplyCost = { Stamina = -8, Merit = 1, XianJing = 3 },
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
	-- 时辰效率修正（Time Modifiers）
	-- ============================================================
	TIME_MODIFIERS = {
		-- hourStart (inclusive), hourEnd (exclusive), taskEff, shopOpen, restEff, label
		{ 4, 12, 0.85, false, 0.8, "晨·旭日东升 — 工作效率最佳，炼丹+15%" },        -- 卯时-午时: 消耗减15%
		{ 12, 18, 1.0, true, 1.0, "昼·日正当空 — 效率正常，商店营业" },              -- 未时-酉时: 正常
		{ 18, 22, 1.2, true, 1.2, "暮·夕阳西下 — 效率下降，战斗+20%" },              -- 戌时-亥时: 消耗增20%
		{ 22, 28, 1.4, false, 1.5, "夜·更深露重 — 工作困难，冥想+40%" },             -- 子时-寅时(28=次日4时): 消耗增40%，恢复+50%
	},

	-- ============================================================
	-- 时间系统
	-- ============================================================
	DAY_CYCLE_MINUTES = 12,        -- 12 分钟 = 1 天
	MIDNIGHT_FATIGUE_REDUCTION = -30, -- 深夜结算减 30 疲劳

	-- ============================================================
	-- 打坐/冥想数值
	-- ============================================================
	MEDITATION = {
		BaseStaminaRecovery = 3,
		BaseSpiritRecovery = 6,
		BaseFatigueLoss = 2,
		PerfectMultiplier = 1.5,
		PreciseMultiplier = 1.2,
		NormalMultiplier = 1.0,
		MissMultiplier = 0.5,
		HighMaliceThreshold = 30,
		MaxMaliceThreshold = 50,
		PhaseInhaleDuration = 2.0,
		PhaseHoldDuration = 1.5,
		PhaseExhaleDuration = 2.0,
		PerfectWindow = 0.15,
		PreciseWindow = 0.30,
		TranceLayerStep = 3,
	},

	-- ============================================================
	-- 睡觉数值
	-- ============================================================
	SLEEP = {
		Duration = 20,
		AdvanceHours = 2,
		BaseStaminaRecovery = 35,
		BaseSpiritRecovery = 12,
		BaseFatigueLoss = 18,
		BaseMaliceRecovery = 5,
		PillMultiplier = 2,
		ExpPerDeepSleep = 0,
	},
}

return StatsConfig
