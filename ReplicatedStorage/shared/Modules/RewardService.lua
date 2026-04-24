-- RewardService.luau

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local RewardService = {}

function RewardService:Give(player, rewardType)
	local reward = Config.Economy.Rewards[rewardType]
	if not reward then
		warn("未找到奖励类型: " .. rewardType)
		return
	end

	for key, value in pairs(reward) do
		if key == "仙晶" or key == "功德" then
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local stat = leaderstats:FindFirstChild(key)
				if stat then
					stat.Value += value
				end
			end
		elseif key == "风险" then
			local current = player:GetAttribute("Risk") or 0
			player:SetAttribute("Risk", math.min(current + value, Config.Risk.MaxRisk))
		end
	end
end

return RewardService