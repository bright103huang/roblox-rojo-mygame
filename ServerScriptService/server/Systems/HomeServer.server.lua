local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local HomeEvent = require(ReplicatedStorage.Shared.Events.HomeEvents)
local DataManager = require(script.Parent.DataManager)
local StatusService = require(script.Parent.StatusService)
local StatsConfig = require(ReplicatedStorage.Shared.Config.StatsConfig)
local DanConfig = require(ReplicatedStorage.Shared.Config.DanConfig)
local TimeService = require(script.Parent.TimeService)
local HomeEntryTracker = require(ReplicatedStorage.Shared.Modules.HomeEntryTracker)
local SpeedCalculator = require(script.Parent.SpeedCalculator)

-- 睡前服用丹药（2x效果，内联自 ShopService.UseItemBeforeSleep）
local function usePillBeforeSleep(player, itemKey)
	local data = DataManager:GetData(player)
	if not data then return end
	local backpack = data.Backpack or {}
	local count = backpack[itemKey] or 0
	if count <= 0 then return end
	local item = DanConfig.Items[itemKey]
	if not item then return end
	backpack[itemKey] = count - 1
	if backpack[itemKey] <= 0 then backpack[itemKey] = nil end
	data.Backpack = backpack
	DataManager:UpdateField(player, "Backpack", backpack)
	local effectValue = item.EffectValue * 2
	local effectType = item.EffectType
	if effectType == "Stamina" or effectType == "Spirit"
		or effectType == "Fatigue" or effectType == "FirePoison"
		or effectType == "Malice" then
		local costs = {}
		costs[effectType] = effectValue
		StatusService:ApplyCosts(player, costs)
	elseif effectType == "AgilityExp" then
		StatusService:AddExp(player, "Agility", effectValue)
	elseif effectType == "AlchemyExp" then
		StatusService:AddExp(player, "AlchemyLv", effectValue)
	elseif effectType == "CombatExp" then
		StatusService:AddExp(player, "Combat", effectValue)
	elseif effectType == "RandomStat" then
		local stats = { "Agility", "AlchemyLv", "Combat" }
		local chosen = stats[math.random(1, #stats)]
		StatusService:AddExp(player, chosen, effectValue)
	elseif effectType == "AllStats" then
		StatusService:AddExp(player, "Agility", effectValue)
		StatusService:AddExp(player, "AlchemyLv", effectValue)
		StatusService:AddExp(player, "Combat", effectValue)
	end
end

-- Meditation recovery handlers
HomeEvent.OnServerEvent:Connect(function(player, action, data)
	if action == "BreathResult" then
		if not HomeEntryTracker.CanUse(player, "Meditated") then return end
		local mult = StatsConfig.MEDITATION.NormalMultiplier
		if data.Judgment == "perfect" then mult = StatsConfig.MEDITATION.PerfectMultiplier
		elseif data.Judgment == "precise" then mult = StatsConfig.MEDITATION.PreciseMultiplier
		elseif data.Judgment == "miss" then mult = StatsConfig.MEDITATION.MissMultiplier end

		local layerBonus = 1 + (data.Layer or 0) * 0.3
		local totalMult = mult * layerBonus
		local stamina = math.floor(StatsConfig.MEDITATION.BaseStaminaRecovery * totalMult)
		local spirit = math.floor(StatsConfig.MEDITATION.BaseSpiritRecovery * totalMult)
		local fatigue = math.max(1, math.floor(StatsConfig.MEDITATION.BaseFatigueLoss * totalMult))

		StatusService:ApplyCosts(player, { Stamina = stamina, Spirit = spirit, Fatigue = -fatigue })
		HomeEntryTracker.MarkUsed(player, "Meditated")
		SpeedCalculator.Apply(player)
		HomeEvent:FireClient(player, "BreathSettlement", { Stamina = stamina, Spirit = spirit })

	elseif action == "GetBackpack" then
		local plrData = DataManager:GetData(player)
		HomeEvent:FireClient(player, "BackpackData", { Backpack = plrData.Backpack or {} })

	elseif action == "SleepComplete" then
		local plrData = DataManager:GetData(player)
		if not plrData then return end

		if not HomeEntryTracker.CanUse(player, "Slept") then return end

		local hasPills = data.Pills and #data.Pills > 0
		local mult = hasPills and StatsConfig.SLEEP.PillMultiplier or 1

		local oldStamina = plrData.Stamina
		local oldSpirit = plrData.Spirit
		local oldFatigue = plrData.Fatigue
		local oldMalice = plrData.Malice

		if hasPills then
			for _, pillKey in ipairs(data.Pills or {}) do
				usePillBeforeSleep(player, pillKey)
			end
		end

		local stamina = math.min(100, plrData.Stamina + StatsConfig.SLEEP.BaseStaminaRecovery * mult)
		local spirit = math.min(100, plrData.Spirit + StatsConfig.SLEEP.BaseSpiritRecovery * mult)
		local fatigue = math.max(0, plrData.Fatigue - StatsConfig.SLEEP.BaseFatigueLoss * mult)
		local malice = math.max(0, plrData.Malice - StatsConfig.SLEEP.BaseMaliceRecovery * mult)

		plrData.Stamina = stamina
		plrData.Spirit = spirit
		plrData.Fatigue = fatigue
		plrData.Malice = malice

		DataManager:UpdateField(player, "Stamina", stamina)
		DataManager:UpdateField(player, "Spirit", spirit)
		DataManager:UpdateField(player, "Fatigue", fatigue)
		DataManager:UpdateField(player, "Malice", malice)

		TimeService:AdvanceHours(2)
		HomeEntryTracker.MarkUsed(player, "Slept")

		local msg = string.format("睡眠充足！体力+%d 精神+%d 疲劳-%d 戾气-%d",
			stamina - oldStamina, spirit - oldSpirit,
			oldFatigue - fatigue, oldMalice - malice)
		HomeEvent:FireClient(player, "SleepSettlement", { Message = msg })

	elseif action == "PrayerChoice" then
		if not HomeEntryTracker.CanUse(player, "Prayed") then
			HomeEvent:FireClient(player, "PrayerResult", { Success = false, Message = "今日已祈福过" })
			return
		end
		local plrData = DataManager:GetData(player)
		if not plrData then return end

		local option = data.Option
		local cost, gongde, maliceReduce, spiritBonus, expAmount = 0, 0, 0, 0, 0
		if option == "Basic" then
			gongde = 3; maliceReduce = 1
		elseif option == "Incense" then
			cost = 10; gongde = 8; maliceReduce = 3; spiritBonus = 5
		elseif option == "Offering" then
			cost = 50; gongde = 20; maliceReduce = 5; spiritBonus = 10; expAmount = 1
		else
			HomeEvent:FireClient(player, "PrayerResult", { Success = false, Message = "无效选项" })
			return
		end

		if (plrData.XianJing or 0) < cost then
			HomeEvent:FireClient(player, "PrayerResult", { Success = false, Message = "仙晶不足" })
			return
		end

		plrData.PrayerOption = option
		plrData.XianJing = (plrData.XianJing or 0) - cost
		plrData.GongDe = (plrData.GongDe or 0) + gongde
		plrData.Malice = math.max(0, (plrData.Malice or 0) - maliceReduce)
		plrData.Spirit = math.min(100, (plrData.Spirit or 0) + spiritBonus)
		DataManager:UpdateField(player, "PrayerOption", option)
		DataManager:UpdateField(player, "XianJing", plrData.XianJing)
		DataManager:UpdateField(player, "GongDe", plrData.GongDe)
		DataManager:UpdateField(player, "Malice", plrData.Malice)
		DataManager:UpdateField(player, "Spirit", plrData.Spirit)

		HomeEntryTracker.MarkUsed(player, "Prayed")

		if expAmount > 0 then
			StatusService:AddExp(player, "Agility", expAmount)
		end

		HomeEvent:FireClient(player, "PrayerResult", { Success = true, Message = "祈福成功！功德+" .. gongde })
	end
end)

print("🏠 HomeServer 已启动")
