-- init.lua
-- 等待兄弟模块同步完成（最多等待 10 秒）
local function waitForModule(name)
	local module = script:WaitForChild(name, 10)
	if not module then
		warn("❌ 等待超时: " .. name)
		return nil
	end
	return module
end

local Economy = waitForModule("EconomyConfig")
local Player = waitForModule("PlayerConfig")
local Risk = waitForModule("RiskConfig")
local Task = waitForModule("TaskConfig")
local Stats = waitForModule("StatsConfig")
local Dan = waitForModule("DanConfig")
local Scene = waitForModule("SceneConfig")
local Exam = waitForModule("ExamConfig")

local function safeRequire(module, defaultTable)
	if not module then return defaultTable end
	local success, result = pcall(require, module)
	if success then
		print("✅ 已加载配置模块:", module.Name)
		return result
	else
		warn("❌ 加载模块失败 [" .. module.Name .. "]:", result)
		return defaultTable
	end
end

-- 默认配置（作为后备）
local DEFAULT_ECONOMY = {
	Rewards = {
		Deliver = { ["仙晶"] = 10 },
		StealPeach = { ["仙晶"] = 30, ["风险"] = 20 },
		HelpNPC = { ["功德"] = 10 },
		BigEvent = { ["仙晶"] = 50, ["功德"] = 20, ["风险"] = 30 },
	}
}
local DEFAULT_PLAYER = { MaxHP = 100, BasePower = 1 }
local DEFAULT_RISK = { MaxRisk = 100, Threshold = { Low = 30, Mid = 60, High = 80 } }
local DEFAULT_TASK = {
	Tasks = {},
	General = { DebounceTime = 0.3 },
}
local DEFAULT_STATS = {
	MAX_STAMINA = 100, MAX_SPIRIT = 100, MAX_FATIGUE = 100,
	MAX_FIRE_POISON = 100, MAX_MALICE = 100,
	BASE_SPEED = 16, EXP_PER_LEVEL = 30,
}
local DEFAULT_DAN = { Items = {}, ResetInterval = 720 }
local DEFAULT_SCENE = {}
local DEFAULT_EXAM = {
	MinAgility = 6, MinAlchemy = 6, MinCombat = 6, MinGongDe = 100,
	PassThreshold = 60, ExamScene = "SouthGate", PassScene = "PeachGarden",
	IndexWeights = { Agility = 3, Alchemy = 3, Combat = 3, GongDe = 0.1 },
}

return {
	Economy = safeRequire(Economy, DEFAULT_ECONOMY),
	Player = safeRequire(Player, DEFAULT_PLAYER),
	Risk = safeRequire(Risk, DEFAULT_RISK),
	Task = safeRequire(Task, DEFAULT_TASK),
	Stats = safeRequire(Stats, DEFAULT_STATS),
	Dan = safeRequire(Dan, DEFAULT_DAN),
	Scene = safeRequire(Scene, DEFAULT_SCENE),
	Exam = safeRequire(Exam, DEFAULT_EXAM),
}
