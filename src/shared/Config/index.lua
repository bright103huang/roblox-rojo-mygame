-- index.luau
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
local DEFAULT_PLAYER = { WalkSpeed = 16, MaxHP = 100, BasePower = 1 }
local DEFAULT_RISK = { MaxRisk = 100, Threshold = { Low = 30, Mid = 60, High = 80 } }

return {
	Economy = safeRequire(Economy, DEFAULT_ECONOMY),
	Player = safeRequire(Player, DEFAULT_PLAYER),
	Risk = safeRequire(Risk, DEFAULT_RISK),
}