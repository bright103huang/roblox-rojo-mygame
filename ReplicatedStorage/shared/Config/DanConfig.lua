-- ============================================================
-- 文件：ReplicatedStorage.Shared.Config.DanConfig.lua
-- 功能：仙丹阁商店 — 丹药品类配置
-- ============================================================

local DanConfig = {
	Items = {
		HuiQiDan = {
			Name = "回气丹",
			Description = "恢复体力 30 点",
			Price = 5,
			EffectType = "Stamina",
			EffectValue = 30,
			DailyLimit = 0,  -- 0 = 不限
		},
		QingXinDan = {
			Name = "清心丹",
			Description = "恢复精神 30 点",
			Price = 5,
			EffectType = "Spirit",
			EffectValue = 30,
			DailyLimit = 0,
		},
		QingDuSan = {
			Name = "清毒散",
			Description = "降低火毒 20 点",
			Price = 10,
			EffectType = "FirePoison",
			EffectValue = -20,
			DailyLimit = 0,
		},
		LianTiDan = {
			Name = "练体丹",
			Description = "身法经验 +10",
			Price = 20,
			EffectType = "AgilityExp",
			EffectValue = 10,
			DailyLimit = 1,
		},
		WuDaoDan = {
			Name = "悟道丹",
			Description = "火候经验 +10",
			Price = 20,
			EffectType = "AlchemyExp",
			EffectValue = 10,
			DailyLimit = 1,
		},
		ShaFaDan = {
			Name = "杀伐丹",
			Description = "仙力经验 +10",
			Price = 20,
			EffectType = "CombatExp",
			EffectValue = 10,
			DailyLimit = 1,
		},
	},
	-- 限购刷新时间（秒），配合 TimeService 的午夜结算
	ResetInterval = 720,  -- 12 分钟（一天）
}

return DanConfig
