-- ServerScriptService.Server.Systems.PlayerInit.server.lua

local Players = game:GetService("Players")
local DataManager = require(script.Parent.DataManager)

Players.PlayerAdded:Connect(function(player)
	-- 先创建 leaderstats（如果未创建）
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end

	local gold = stats:FindFirstChild("仙晶")
	if not gold then
		gold = Instance.new("IntValue")
		gold.Name = "仙晶"
		gold.Value = 0
		gold.Parent = stats
	end

	local merit = stats:FindFirstChild("功德")
	if not merit then
		merit = Instance.new("IntValue")
		merit.Name = "功德"
		merit.Value = 0
		merit.Parent = stats
	end

	-- 新增：身法、火候、仙力 leaderstats
	local agilityStat = stats:FindFirstChild("身法")
	if not agilityStat then
		agilityStat = Instance.new("IntValue")
		agilityStat.Name = "身法"
		agilityStat.Value = 1
		agilityStat.Parent = stats
	end

	local alchemyStat = stats:FindFirstChild("火候")
	if not alchemyStat then
		alchemyStat = Instance.new("IntValue")
		alchemyStat.Name = "火候"
		alchemyStat.Value = 1
		alchemyStat.Parent = stats
	end

	local combatStat = stats:FindFirstChild("仙力")
	if not combatStat then
		combatStat = Instance.new("IntValue")
		combatStat.Name = "仙力"
		combatStat.Value = 1
		combatStat.Parent = stats
	end

	-- 初始化 DataManager（会加载存档并覆盖数值）
	DataManager:InitPlayer(player)

	-- 原有的 Attribute 设置
	player:SetAttribute("Power", 1)
	player:SetAttribute("HP", 100)
end)