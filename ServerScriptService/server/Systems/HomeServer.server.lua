local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local HomeEvent = require(ReplicatedStorage.Shared.Events.HomeEvents)
local DataManager = require(script.Parent.DataManager)
local StatusService = require(script.Parent.StatusService)
local StatsConfig = require(ReplicatedStorage.Shared.Config.StatsConfig)
local SleepLogic = require(ReplicatedStorage.Shared.PureLogic.SleepLogic)
local TimeService = require(script.Parent.TimeService)

-- Meditation recovery handlers
HomeEvent.OnServerEvent:Connect(function(player, action, data)
	if action == "BreathResult" then
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
		HomeEvent:FireClient(player, "BreathSettlement", { Stamina = stamina, Spirit = spirit })

	elseif action == "GetBackpack" then
		local plrData = DataManager:GetData(player)
		HomeEvent:FireClient(player, "BackpackData", { Backpack = plrData.Backpack or {} })

	elseif action == "SleepComplete" then
		local plrData = DataManager:GetData(player)
		if not plrData then return end

		local todayKey = os.date("%Y%m%d")
		if plrData.LastSleptDay == todayKey then
			HomeEvent:FireClient(player, "SleepSettlement", { Message = "今日已睡过" })
			return
		end
		plrData.LastSleptDay = todayKey
		DataManager:UpdateField(player, "LastSleptDay", todayKey)

		local ratio = data.PeaceRatio or 0
		local quality = SleepLogic.CalcSleepQuality(ratio, StatsConfig.SLEEP)
		local recovery = SleepLogic.CalcSleepRecovery(quality, {
			Stamina = plrData.Stamina,
			Spirit = plrData.Spirit,
			Fatigue = plrData.Fatigue,
			Malice = plrData.Malice,
		}, StatsConfig.SLEEP)

		plrData.Stamina = recovery.Stamina
		plrData.Spirit = recovery.Spirit
		plrData.Fatigue = recovery.Fatigue
		plrData.Malice = recovery.Malice
		if recovery.Exp > 0 then
			StatusService:AddExp(player, "Agility", recovery.Exp)
		end

		DataManager:UpdateField(player, "Stamina", plrData.Stamina)
		DataManager:UpdateField(player, "Spirit", plrData.Spirit)
		DataManager:UpdateField(player, "Fatigue", plrData.Fatigue)
		DataManager:UpdateField(player, "Malice", plrData.Malice)

		-- Advance time by 2 hours
		TimeService:AdvanceHours(2)
		HomeEvent:FireClient(player, "SleepSettlement", { Message = quality .. "。体力精神恢复" })

	elseif action == "PrayerChoice" then
		local plrData = DataManager:GetData(player)
		if not plrData then return end

		local todayKey = os.date("%Y%m%d")
		if plrData.LastPrayerDate == todayKey then
			HomeEvent:FireClient(player, "PrayerResult", { Success = false, Message = "今日已祈福" })
			return
		end

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

		plrData.LastPrayerDate = todayKey
		plrData.PrayerOption = option
		plrData.XianJing = (plrData.XianJing or 0) - cost
		plrData.GongDe = (plrData.GongDe or 0) + gongde
		plrData.Malice = math.max(0, (plrData.Malice or 0) - maliceReduce)
		plrData.Spirit = math.min(100, (plrData.Spirit or 0) + spiritBonus)
		DataManager:UpdateField(player, "LastPrayerDate", todayKey)
		DataManager:UpdateField(player, "PrayerOption", option)
		DataManager:UpdateField(player, "XianJing", plrData.XianJing)
		DataManager:UpdateField(player, "GongDe", plrData.GongDe)
		DataManager:UpdateField(player, "Malice", plrData.Malice)
		DataManager:UpdateField(player, "Spirit", plrData.Spirit)

		if expAmount > 0 then
			StatusService:AddExp(player, "Agility", expAmount)
		end

		HomeEvent:FireClient(player, "PrayerResult", { Success = true, Message = "祈福成功！功德+" .. gongde })
	end
end)

print("🏠 HomeServer 已启动")
