-- Main.server.lua

local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    local stats = Instance.new("Folder")
    stats.Name = "leaderstats"
    stats.Parent = player

    local gold = Instance.new("IntValue")
    gold.Name = "仙晶"
    gold.Value = 0
    gold.Parent = stats
end)