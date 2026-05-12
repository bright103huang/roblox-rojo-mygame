-- ============================================================
-- 文件：ReplicatedStorage.Shared.Config.SceneConfig.luau
-- 功能：集中管理所有场景的叙事数据与出生坐标
-- ============================================================

local SceneConfig = {
	-- 御膳房（传菜打工）
	YiShanFang = {
		DisplayName = "御膳房",
		Description = "端盘送菜，淬炼身法",
		SpawnPosition = Vector3.new(0, 3, 0),
		SceneType = "Work",
		Icon = "🍽",
		TrainLabel = "身法",
		CostDisplay = "体力-8  疲劳+5",
		RewardDisplay = "身法exp+5  仙晶+10",
	},

	-- 炼丹洞天
	Alchemy = {
		DisplayName = "炼丹洞天",
		Description = "炼制仙丹，提升火候",
		SpawnPosition = Vector3.new(1000, 3, 0),
		SceneType = "Work",
		Icon = "🔥",
		TrainLabel = "火候",
		CostDisplay = "精神-10  火毒+3",
		RewardDisplay = "火候exp+8  仙晶+15",
	},

	-- 妖兽战场
	Beast = {
		DisplayName = "妖兽战场",
		Description = "狩猎妖兽，淬炼仙力",
		SpawnPosition = Vector3.new(2000, 3, 0),
		SceneType = "Work",
		Icon = "🐉",
		TrainLabel = "仙力",
		CostDisplay = "体力-12  戾气+5",
		RewardDisplay = "仙力exp+10  仙晶+25",
	},

	-- 仙丹阁
	DanShop = {
		DisplayName = "仙丹阁",
		Description = "购买丹药，强化己身",
		SpawnPosition = Vector3.new(-1000, 3, 0),
		SceneType = "Shop",
		Icon = "💊",
	},

	-- 家（炼化提升）
	Home = {
		DisplayName = "家",
		Description = "服药打坐，炼化提升",
		SpawnPosition = Vector3.new(-500, 3, 0),
		SceneType = "Home",
		Icon = "🏠",
	},

	-- ============================================================
	-- 以下场景暂不启用（保留配置供后续使用）
	-- ============================================================

	--[[
	-- 南天门（考编考核地点）
	SouthGate = {
		SpawnPosition = Vector3.new(-2000, 3, 0),
	},
	-- 蟠桃园（天兵驻地）
	PeachGarden = {
		SpawnPosition = Vector3.new(3000, 3, 50),
	},
	-- 结局场景
	EndingLoyal = { SpawnPosition = Vector3.new(6000, 3, 2) },
	EndingWukong = { SpawnPosition = Vector3.new(6000, 3, 2) },
	EndingChaos = { SpawnPosition = Vector3.new(6000, 3, 2) },
	--]]
}

return SceneConfig
