local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local HomeEvent = require(ReplicatedStorage.Shared.Events.HomeEvents)
local DataManager = require(script.Parent.DataManager)
local StatusService = require(script.Parent.StatusService)
local StatsConfig = require(ReplicatedStorage.Shared.Config.StatsConfig)
local TimeService = require(script.Parent.TimeService)
local HomeEntryTracker = require(ReplicatedStorage.Shared.Modules.HomeEntryTracker)
local ShopService = require(script.Parent.ShopService)

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
		HomeEvent:FireClient(player, "BreathSettlement", { Stamina = stamina, Spirit = spirit })

	elseif action == "GetBackpack" then
		local plrData = DataManager:GetData(player)
		HomeEvent:FireClient(player, "BackpackData", { Backpack = plrData.Backpack or {} })

	elseif action == "SleepComplete" then
		local plrData = DataManager:GetData(player)
		if not plrData then return end
		if not HomeEntryTracker.CanUse(player, "Slept") then return end

		local hasPills = data.Pills and #data.Pills > 0
		local mult = 1
		if hasPills then
			mult = StatsConfig.SLEEP.PillMultiplier
			for _, pillKey in ipairs(data.Pills) do
				ShopService:UseItemBeforeSleep(player, pillKey)
			end
		end

		local staminaDelta = StatsConfig.SLEEP.BaseStaminaRecovery * mult
		local spiritDelta = StatsConfig.SLEEP.BaseSpiritRecovery * mult
		local fatigueDelta = StatsConfig.SLEEP.BaseFatigueLoss * mult
		local maliceDelta = StatsConfig.SLEEP.BaseMaliceRecovery * mult

		plrData.Stamina = math.min(100, plrData.Stamina + staminaDelta)
		plrData.Spirit = math.min(100, plrData.Spirit + spiritDelta)
		plrData.Fatigue = math.max(0, plrData.Fatigue - fatigueDelta)
		plrData.Malice = math.max(0, plrData.Malice - maliceDelta)

		DataManager:UpdateField(player, "Stamina", plrData.Stamina)
		DataManager:UpdateField(player, "Spirit", plrData.Spirit)
		DataManager:UpdateField(player, "Fatigue", plrData.Fatigue)
		DataManager:UpdateField(player, "Malice", plrData.Malice)

		HomeEntryTracker.MarkUsed(player, "Slept")

		-- Advance time by 2 hours
		TimeService:AdvanceHours(2)

		HomeEvent:FireClient(player, "SleepSettlement", {
			Message = string.format("体力+%d 精神+%d 疲劳-%d 戾气-%d",
				staminaDelta, spiritDelta, fatigueDelta, maliceDelta),
		})

	elseif action == "PrayerChoice" then
		local plrData = DataManager:GetData(player)
		if not plrData then return end
		if not HomeEntryTracker.CanUse(player, "Prayed") then return end

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

		if expAmount > 0 then
			StatusService:AddExp(player, "Agility", expAmount)
		end

		HomeEntryTracker.MarkUsed(player, "Prayed")
		HomeEvent:FireClient(player, "PrayerResult", { Success = true, Message = "祈福成功！功德+" .. gongde })
	end
end)

print("🏠 HomeServer 已启动")
