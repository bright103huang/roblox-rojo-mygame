local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)

	-- 展示层（货币）
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player

	local gold = Instance.new("IntValue")
	gold.Name = "仙晶"
	gold.Value = 0
	gold.Parent = stats

	local merit = Instance.new("IntValue")
	merit.Name = "功德"
	merit.Value = 0
	merit.Parent = stats


	-- 核心状态（隐藏）
	player:SetAttribute("Risk", 10)
	player:SetAttribute("Power", 1)
	player:SetAttribute("HP", 100)

end)