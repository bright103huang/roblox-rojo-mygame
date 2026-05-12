-- ============================================================
-- 文件：ReplicatedStorage.Shared.Config.ExamConfig.lua
-- 功能：考编系统 — 硬性门槛、指数权重、场景配置
-- ============================================================

local ExamConfig = {
	-- 硬性门槛
	MinAgility = 6,
	MinAlchemy = 6,
	MinCombat = 6,
	MinGongDe = 100,

	-- 考编指数公式权重
	-- 指数 = 身法*Agility + 火候*Alchemy + 仙力*Combat + 功德*GongDe
	IndexWeights = {
		Agility = 3,
		Alchemy = 3,
		Combat = 3,
		GongDe = 0.1,  -- 功德/10
	},
	PassThreshold = 60,

	-- 考核场景（场景出生坐标统一管理在 SceneConfig 中）
	ExamScene = "SouthGate",    -- 南天门（考核现场）
	PassScene = "PeachGarden",  -- 蟠桃园（晋升后场景）
}

return ExamConfig
