-- ServerScriptService.Server.Systems.PlayerInit.server.lua

local Players = game:GetService("Players")
local DataManager = require(script.Parent.DataManager)

Players.PlayerAdded:Connect(function(player)
	-- 创建 leaderstats（仅显示仙晶和功德）
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

	-- 初始化 DataManager（会加载存档并覆盖数值）
	DataManager:InitPlayer(player)

	-- 原有的 Attribute 设置
	player:SetAttribute("Power", 1)
	player:SetAttribute("HP", 100)
end)