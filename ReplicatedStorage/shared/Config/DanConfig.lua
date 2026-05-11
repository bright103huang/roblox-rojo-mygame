-- ============================================================
-- 文件：ReplicatedStorage.Shared.Config.DanConfig.lua
-- 功能：仙丹阁商店 — 丹药品类配置（含朦胧未解锁机制）
-- ============================================================

local DanConfig = {
	Items = {
		HuiQiDan = {
			Name = "回气丹",
			Description = "恢复体力 20 点",
			Price = 20,
			EffectType = "Stamina",
			EffectValue = 20,
			DailyLimit = 0,
		},
		QingXinSan = {
			Name = "清心散",
			Description = "降低疲劳 15 点",
			Price = 35,
			EffectType = "Fatigue",
			EffectValue = -15,
			DailyLimit = 0,
		},
		JuShenDan = {
			Name = "聚神丹",
			Description = "恢复精神 15 点",
			Price = 40,
			EffectType = "Spirit",
			EffectValue = 15,
			DailyLimit = 0,
		},
		YuLingDan = {
			Name = "玉灵丹",
			Description = "化解火毒 20 点",
			Price = 80,
			EffectType = "FirePoison",
			EffectValue = -20,
			DailyLimit = 0,
		},
		XiuWeiXiaoDan = {
			Name = "???",
			Description = "???",
			Price = 200,
			EffectType = "RandomStat",
			EffectValue = 1,
			DailyLimit = 0,
			RevealThreshold = 200,
			RealName = "凝气丹",
			RealDescription = "身法/火候/仙力随机一项 +1",
		},
		XiuWeiDaDan = {
			Name = "???",
			Description = "???",
			Price = 500,
			EffectType = "AllStats",
			EffectValue = 1,
			DailyLimit = 0,
			RevealThreshold = 500,
			RealName = "混元丹",
			RealDescription = "身法/火候/仙力 全部 +1",
		},
	},
	-- 限购刷新时间（秒），配合 TimeService 的午夜结算
	ResetInterval = 720,
}

return DanConfig
