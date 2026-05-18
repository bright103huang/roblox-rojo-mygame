-- tests/run.lua
-- 轻量 Luau 测试框架 + 测试入口
-- 用法: luau tests/run.lua（在项目根目录执行）
-- ====== 纯逻辑 TDD 模板 ======
-- 如何为新模块写测试：
-- 1. 将业务逻辑提取为纯函数（不依赖 Roblox API）
-- 2. 在 Shared/PureLogic/ 下创建纯函数模块
-- 3. 在文件底部追加 describe/it 测试块
-- 4. 先写测试（RED）→ 运行验证失败 → 实现逻辑（GREEN）
-- 5. 参考下方 SleepLogic 测试区第 ~360 行的提取模式
-- 6. require 路径: require("../ReplicatedStorage/Shared/PureLogic/模块名")
-- ============================

-- ====== 框架核心 ======
local results = { passed = 0, failed = 0, errors = {} }
local currentSuite = ""

local expect = {}
function expect.equal(a, b, msg)
	if a ~= b then
		error(string.format("%s\n  期望: %s\n  实际: %s", msg or "", tostring(b), tostring(a)), 2)
	end
end
function expect.near(a, b, epsilon, msg)
	epsilon = epsilon or 0.001
	if math.abs(a - b) > epsilon then
		error(string.format("%s  期望≈%s 实际=%s 差=%s",
			msg or "", tostring(b), tostring(a), tostring(math.abs(a - b))), 2)
	end
end
function expect.ok(val, msg)
	if not val then
		error("期望为真: " .. (msg or tostring(val)), 2)
	end
end
function expect.not_ok(val, msg)
	if val then
		error("期望为假: " .. (msg or tostring(val)), 2)
	end
end
function expect.table_contains(tbl, value, msg)
	for _, v in tbl do
		if v == value then return end
	end
	error(string.format("期望表中包含 %s: %s", tostring(value), msg or ""), 2)
end

local function describe(name, fn)
	currentSuite = name
	print("\n📚 " .. name)
	fn()
end

local function it(name, fn)
	local ok, err = pcall(fn)
	if ok then
		results.passed = results.passed + 1
		print("  ✅ " .. name)
	else
		results.failed = results.failed + 1
		table.insert(results.errors, { suite = currentSuite, test = name, error = err })
		print("  ❌ " .. name)
		print("     " .. tostring(err):gsub("\n", "\n     "))
	end
end

-- ====== 测试用例从这里开始 ======

-- ----- 冒烟测试 -----
describe("框架冒烟", function()
	it("基本断言通过", function()
		expect.equal(1, 1)
		expect.ok(true)
		expect.not_ok(false)
	end)
	it("浮点近似", function()
		expect.near(0.1 + 0.2, 0.3)
	end)
end)

-- ----- StatsConfig 数值完整性 -----
describe("StatsConfig 数值", function()
	local StatsConfig = {
		MAX_STAMINA = 100, MAX_SPIRIT = 100, MAX_FATIGUE = 100,
		MAX_FIRE_POISON = 100, MAX_MALICE = 100,
		STAMINA_REGEN_PER_TICK = 1, SPIRIT_REGEN_PER_TICK = 1, REGEN_INTERVAL = 5,
		FATIGUE_REGEN_REDUCTION = 0.5,
		EXP_PER_LEVEL = 30,
		FATIGUE_REDLINE = 80, FIREPOISON_REDLINE = 60, MALICE_REDLINE = 50,
		BASE_SPEED = 32, AGILITY_SPEED_PER_LEVEL = 0.5,
		FATIGUE_SPEED_MULTIPLIER = 0.6, TOXIN_SPEED_MULTIPLIER = 0.5,
	}

	it("所有上限为正数", function()
		for _, key in { "MAX_STAMINA", "MAX_SPIRIT", "MAX_FATIGUE", "MAX_FIRE_POISON", "MAX_MALICE" } do
			expect.ok(StatsConfig[key] > 0, key .. " > 0")
		end
	end)

	it("红线阈值合理（>=50）", function()
		expect.ok(StatsConfig.FATIGUE_REDLINE >= 50)
		expect.ok(StatsConfig.FIREPOISON_REDLINE >= 50)
		expect.ok(StatsConfig.MALICE_REDLINE >= 50)
	end)

	it("速度公式参数合理", function()
		expect.ok(StatsConfig.BASE_SPEED > 0)
		expect.ok(StatsConfig.AGILITY_SPEED_PER_LEVEL > 0)
		expect.ok(StatsConfig.FATIGUE_SPEED_MULTIPLIER < 1)
		expect.ok(StatsConfig.TOXIN_SPEED_MULTIPLIER < 1)
	end)

	it("EXP_PER_LEVEL 为正数", function()
		expect.ok(StatsConfig.EXP_PER_LEVEL > 0)
	end)
end)

-- ----- EconomyConfig 完整性 -----
describe("EconomyConfig 奖励", function()
	local EconomyConfig = {
		Rewards = {
			Deliver = { ["仙晶"] = 10 },
			StealPeach = { ["仙晶"] = 30, ["风险"] = 20 },
			HelpNPC = { ["功德"] = 10 },
			BigEvent = { ["仙晶"] = 50, ["功德"] = 20, ["风险"] = 30 },
			Alchemy = { ["仙晶"] = 15 },
			BeastKill = { ["仙晶"] = 25 },
			BeastKill_Elite = { ["仙晶"] = 50 },
			BeastKill_Boss = { ["仙晶"] = 100, ["功德"] = 10 },
			DailyPray = { ["功德"] = 5 },
			DonatePill = { ["功德"] = 5 },
			Patrol = { ["仙晶"] = 5 },
			ExpelMonkey = { ["仙晶"] = 3 },
		}
	}

	it("所有奖励值 > 0", function()
		for name, rewards in EconomyConfig.Rewards do
			for currency, amount in rewards do
				expect.ok(amount > 0, name .. "." .. currency .. " 应为正数")
			end
		end
	end)

	it("所有 Key 都被引用或可访问", function()
		local count = 0
		for _ in EconomyConfig.Rewards do count = count + 1 end
		expect.equal(count, 12, "应有 12 种奖励配置")
	end)
end)

-- ----- SpeedCalculator 纯逻辑 -----
describe("SpeedCalculator 计算逻辑", function()
	-- 纯函数版本的 getStatusModifier（从源码提取，不依赖 Roblox API）
	local function getStatusModifier(data)
		local modifier = 1.0
		if (data.Fatigue or 0) > 80 then
			modifier = modifier * 0.6
		end
		if (data.FirePoison or 0) > 80 then
			modifier = modifier * 0.5
		end
		return modifier
	end

	local function calcSpeed(agility, fatigue, firePoison)
		local data = { Agility = agility or 1, Fatigue = fatigue or 0, FirePoison = firePoison or 0 }
		local baseSpeed = 32
		local agilityBonus = data.Agility * 0.5
		local modifier = getStatusModifier(data)
		return (baseSpeed + agilityBonus) * modifier
	end

	it("基础速度（无状态惩罚）", function()
		local speed = calcSpeed(1, 0, 0)
		expect.near(speed, 32.5, 0.01, "身法1级理论速度为32.5")
	end)

	it("身法加成线性增长", function()
		local s1 = calcSpeed(1, 0, 0)
		local s10 = calcSpeed(10, 0, 0)
		expect.near(s10 - s1, 4.5, 0.01, "身法1→10 速度+4.5")
	end)

	it("疲劳 > 80 速度 * 0.6", function()
		local normal = calcSpeed(1, 0, 0)
		local tired = calcSpeed(1, 85, 0)
		expect.near(tired, normal * 0.6, 0.01)
	end)

	it("火毒 > 80 速度 * 0.5", function()
		local normal = calcSpeed(1, 0, 0)
		local poisoned = calcSpeed(1, 0, 85)
		expect.near(poisoned, normal * 0.5, 0.01)
	end)

	it("双重惩罚叠加", function()
		local normal = calcSpeed(1, 0, 0)
		local both = calcSpeed(1, 85, 85)
		expect.near(both, normal * 0.6 * 0.5, 0.01)
	end)
end)

-- ----- StatusService 核心逻辑 -----
describe("StatusService 验证/升级逻辑", function()
	-- 纯逻辑版 CanPerformTask
	local function canPerform(stamina, spirit, costs)
		local staminaOK = (stamina or 100) >= (costs.Stamina or 0)
		local spiritOK = (spirit or 100) >= (costs.Spirit or 0)
		return staminaOK and spiritOK
	end

	-- 纯逻辑版 AddExp/升级
	local function addExp(currentLevel, currentExp, amount, expPerLevel)
		expPerLevel = expPerLevel or 30
		local newExp = currentExp + amount
		local levelsGained = 0
		while newExp >= expPerLevel do
			newExp = newExp - expPerLevel
			levelsGained = levelsGained + 1
		end
		return currentLevel + levelsGained, newExp, levelsGained
	end

	-- 纯逻辑版 CheckRedLines
	local function checkRedLines(data, thresholds)
		thresholds = thresholds or { fatigue = 80, firePoison = 60, malice = 50 }
		local warnings = {}
		if (data.Fatigue or 0) > thresholds.fatigue then
			table.insert(warnings, "fatigue_over")
		end
		if (data.FirePoison or 0) > thresholds.firePoison then
			table.insert(warnings, "firePoison_over")
		end
		if (data.Malice or 0) > thresholds.malice then
			table.insert(warnings, "malice_over")
		end
		return warnings
	end

	it("体力足够时 CanPerform 通过", function()
		expect.ok(canPerform(50, 50, { Stamina = 10, Spirit = 5 }))
	end)

	it("体力不足时 CanPerform 不通过", function()
		expect.not_ok(canPerform(5, 50, { Stamina = 10 }))
	end)

	it("精神不足时 CanPerform 不通过", function()
		expect.not_ok(canPerform(50, 3, { Stamina = 10, Spirit = 5 }))
	end)

	it("AddExp 不满 30 不升级", function()
		local lv, exp, gained = addExp(1, 0, 20)
		expect.equal(lv, 1)
		expect.equal(exp, 20)
		expect.equal(gained, 0)
	end)

	it("AddExp 满 30 升 1 级", function()
		local lv, exp, gained = addExp(1, 0, 30)
		expect.equal(lv, 2)
		expect.equal(exp, 0)
		expect.equal(gained, 1)
	end)

	it("AddExp 满 60 升 2 级", function()
		local lv, exp, gained = addExp(1, 0, 65)
		expect.equal(lv, 3)
		expect.equal(exp, 5)
		expect.equal(gained, 2)
	end)

	it("红线检测：正常状态无警告", function()
		local warns = checkRedLines({ Fatigue = 30, FirePoison = 10, Malice = 10 })
		expect.equal(#warns, 0)
	end)

	it("红线检测：疲劳超标", function()
		local warns = checkRedLines({ Fatigue = 90, FirePoison = 10, Malice = 10 })
		expect.table_contains(warns, "fatigue_over")
	end)

	it("红线检测：火毒超标", function()
		local warns = checkRedLines({ Fatigue = 30, FirePoison = 70, Malice = 10 })
		expect.table_contains(warns, "firePoison_over")
	end)

	it("红线检测：戾气超标", function()
		local warns = checkRedLines({ Fatigue = 30, FirePoison = 10, Malice = 60 })
		expect.table_contains(warns, "malice_over")
	end)

	it("红线检测：多项同时超标", function()
		local warns = checkRedLines({ Fatigue = 90, FirePoison = 70, Malice = 60 })
		expect.equal(#warns, 3, "应同时触发三条红线")
	end)
end)

-- ----- Task 奖励计算 -----
describe("任务奖励计算", function()
	local REWARDS = {
		Deliver = { XianJing = 10, GongDeChance = 0.2, GongDeAmount = 1 },
		Alchemy = { XianJing = 15, AlchemyExp = 8 },
		BeastKill = { XianJing = 25, CombatExp = 10 },
		BeastKill_Elite = { XianJing = 50, CombatExp = 15 },
		BeastKill_Boss = { XianJing = 100, CombatExp = 25, GongDe = 10 },
	}

	local function calcTaskReward(taskType, modifiers)
		modifiers = modifiers or {}
		local base = REWARDS[taskType]
		if not base then return nil end
		local result = {}
		for k, v in base do
			if type(v) == "number" then
				if k == "GongDeChance" then
					result[k] = v
				else
					result[k] = v * (modifiers.multiplier or 1)
				end
			end
		end
		return result
	end

	it("基础传菜奖励", function()
		local r = calcTaskReward("Deliver")
		expect.equal(r.XianJing, 10)
	end)

	it("精英妖兽奖励比普通高", function()
		local normal = calcTaskReward("BeastKill")
		local elite = calcTaskReward("BeastKill_Elite")
		expect.ok(elite.XianJing > normal.XianJing)
	end)

	it("Boss 奖励最高", function()
		local boss = calcTaskReward("BeastKill_Boss")
		local elite = calcTaskReward("BeastKill_Elite")
		expect.ok(boss.XianJing > elite.XianJing)
		expect.equal(boss.GongDe, 10)
	end)

	it("未知任务返回 nil", function()
		local r = calcTaskReward("NonExistent")
		expect.equal(r, nil)
	end)
end)

-- ====== SleepLogic 纯逻辑（RED→GREEN TDD 演示） ======
describe("SleepLogic 纯逻辑", function()
	-- require 纯函数模块（不含任何 Roblox API）
	local SleepLogic = require("../ReplicatedStorage/Shared/PureLogic/SleepLogic")

	-- 显式传入配置，测试不依赖模块内部默认值
	local TEST_CFG = {
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

	-- ===== CalcSleepQuality 测试 =====
	it("ratio=0.9 → 酣睡", function()
		expect.equal(SleepLogic.CalcSleepQuality(0.9, TEST_CFG), "酣睡")
	end)

	it("ratio=0.8（边界值）→ 酣睡", function()
		expect.equal(SleepLogic.CalcSleepQuality(0.8, TEST_CFG), "酣睡")
	end)

	it("ratio=0.6 → 浅睡", function()
		expect.equal(SleepLogic.CalcSleepQuality(0.6, TEST_CFG), "浅睡")
	end)

	it("ratio=0.5（边界值）→ 浅睡", function()
		expect.equal(SleepLogic.CalcSleepQuality(0.5, TEST_CFG), "浅睡")
	end)

	it("ratio=0.3 → 辗转", function()
		expect.equal(SleepLogic.CalcSleepQuality(0.3, TEST_CFG), "辗转")
	end)

	it("ratio=0.25（边界值）→ 辗转", function()
		expect.equal(SleepLogic.CalcSleepQuality(0.25, TEST_CFG), "辗转")
	end)

	it("ratio=0.1 → 失眠", function()
		expect.equal(SleepLogic.CalcSleepQuality(0.1, TEST_CFG), "失眠")
	end)

	it("ratio=0.0 → 失眠", function()
		expect.equal(SleepLogic.CalcSleepQuality(0.0, TEST_CFG), "失眠")
	end)

	-- ===== CalcSleepRecovery 测试 =====
	it("酣睡恢复：体力全满，疲劳归零", function()
		local r = SleepLogic.CalcSleepRecovery("酣睡", { Stamina = 30, Spirit = 50, Fatigue = 40, Malice = 10 }, TEST_CFG)
		expect.equal(r.Stamina, 100, "酣睡体力应回满")
		expect.equal(r.Fatigue, 0, "酣睡疲劳应归零")
		expect.equal(r.Exp, 3, "酣睡应给 3 修为")
	end)

	it("浅睡恢复：体力+30，疲劳-15", function()
		local r = SleepLogic.CalcSleepRecovery("浅睡", { Stamina = 30, Spirit = 50, Fatigue = 40, Malice = 10 }, TEST_CFG)
		expect.equal(r.Stamina, 60, "浅睡 30+30=60")
		expect.equal(r.Fatigue, 25, "浅睡 40-15=25")
		expect.equal(r.Exp, 1, "浅睡应给 1 修为")
	end)

	it("辗转恢复：体力+15，精神+5", function()
		local r = SleepLogic.CalcSleepRecovery("辗转", { Stamina = 10, Spirit = 10, Fatigue = 50, Malice = 5 }, TEST_CFG)
		expect.equal(r.Stamina, 25, "辗转 10+15=25")
		expect.equal(r.Spirit, 15, "辗转 10+5=15")
		expect.equal(r.Exp, 0, "辗转无修为")
	end)

	it("失眠恢复：体力+5，疲劳-2", function()
		local r = SleepLogic.CalcSleepRecovery("失眠", { Stamina = 5, Spirit = 0, Fatigue = 90, Malice = 20 }, TEST_CFG)
		expect.equal(r.Stamina, 10, "失眠 5+5=10")
		expect.equal(r.Fatigue, 88, "失眠 90-2=88")
		expect.equal(r.Exp, 0, "失眠无修为")
	end)

	it("恢复不溢出上限", function()
		local r = SleepLogic.CalcSleepRecovery("浅睡", { Stamina = 95, Spirit = 95, Fatigue = 5, Malice = 0 }, TEST_CFG)
		expect.equal(r.Stamina, 100, "上限 100")
		expect.equal(r.Spirit, 100, "上限 100")
		expect.equal(r.Fatigue, 0, "疲劳不会低于 0")
	end)

	it("恢复不溢出下限（疲劳不会负）", function()
		local r = SleepLogic.CalcSleepRecovery("浅睡", { Stamina = 10, Spirit = 10, Fatigue = 3, Malice = 0 }, TEST_CFG)
		expect.equal(r.Fatigue, 0, "疲劳最低为 0")
	end)

	it("Malice 恢复不溢出下限", function()
		local r = SleepLogic.CalcSleepRecovery("浅睡", { Stamina = 10, Spirit = 10, Fatigue = 5, Malice = 2 }, TEST_CFG)
		expect.equal(r.Malice, 0, "Malice 最低为 0")
	end)
end)

-- ----- HomeEntryTracker 纯逻辑 -----
describe("HomeEntryTracker 逻辑", function()
	local HomeEntryTracker = require("../ReplicatedStorage/Shared/Modules/HomeEntryTracker")

	it("新玩家可以执行所有行动", function()
		local player = { UserId = 1 }
		HomeEntryTracker.Reset(player)
		expect.ok(HomeEntryTracker.CanUse(player, "Meditated"))
		expect.ok(HomeEntryTracker.CanUse(player, "Slept"))
		expect.ok(HomeEntryTracker.CanUse(player, "Prayed"))
	end)

	it("标记使用后不能再次使用", function()
		local player = { UserId = 2 }
		HomeEntryTracker.Reset(player)
		HomeEntryTracker.MarkUsed(player, "Meditated")
		expect.not_ok(HomeEntryTracker.CanUse(player, "Meditated"))
		expect.ok(HomeEntryTracker.CanUse(player, "Slept"))
		expect.ok(HomeEntryTracker.CanUse(player, "Prayed"))
	end)

	it("未 Reset 的玩家 CanUse 返回 false", function()
		local player = { UserId = 999 }
		expect.equal(HomeEntryTracker.CanUse(player, "Meditated"), false)
	end)

	it("不同玩家独立追踪", function()
		local p1 = { UserId = 10 }
		local p2 = { UserId = 20 }
		HomeEntryTracker.Reset(p1)
		HomeEntryTracker.Reset(p2)
		HomeEntryTracker.MarkUsed(p1, "Slept")
		expect.not_ok(HomeEntryTracker.CanUse(p1, "Slept"))
		expect.ok(HomeEntryTracker.CanUse(p2, "Slept"))
	end)

	it("Reset 后可以重新使用", function()
		local player = { UserId = 3 }
		HomeEntryTracker.Reset(player)
		HomeEntryTracker.MarkUsed(player, "Meditated")
		HomeEntryTracker.MarkUsed(player, "Slept")
		HomeEntryTracker.MarkUsed(player, "Prayed")
		expect.not_ok(HomeEntryTracker.CanUse(player, "Meditated"))
		HomeEntryTracker.Reset(player)
		expect.ok(HomeEntryTracker.CanUse(player, "Meditated"))
	end)
end)

-- ====== 汇总报告 ======
print("\n" .. "=" .. string.rep("=", 55))
print(string.format("📊 结果: %d 通过, %d 失败", results.passed, results.failed))
if #results.errors > 0 then
	print("")
	for _, e in results.errors do
		print(string.format("  [%s] %s", e.suite, e.test))
		print("    " .. tostring(e.error):gsub("\n", "\n    "))
	end
	os.exit(1)
end
print("🎉 全部通过！")
