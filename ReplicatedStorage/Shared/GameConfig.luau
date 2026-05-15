local EconomyConfig = {}

-- 所有奖励必须写成结构
EconomyConfig.Rewards = {

	Deliver = {
		仙晶 = 10,
	},

	StealPeach = {
		仙晶 = 30,
		风险 = 20,
	},

	HelpNPC = {
		功德 = 10,
	},

	BigEvent = {
		仙晶 = 50,
		功德 = 20,
		风险 = 30,
	}

}

return EconomyConfig
