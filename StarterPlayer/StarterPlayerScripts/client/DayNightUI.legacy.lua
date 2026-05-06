-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.DayNightUI.client.lua
-- 功能：显示当前时辰和白天/夜晚图标
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- 等待 TimeEvent（带重试，不放弃）
-- ============================================================
local TimeEvent = nil
for retry = 1, 60 do
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if eventsFolder then
		TimeEvent = eventsFolder:FindFirstChild("TimeEvent")
		if TimeEvent then break end
	end
	task.wait(1)
end

if not TimeEvent then
	warn("❌ DayNightUI: TimeEvent 未找到（持续 60 秒），跳过")
	return
end

-- ============================================================
-- 创建 UI
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DayNightUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "TimeFrame"
frame.Size = UDim2.new(0, 120, 0, 36)
frame.Position = UDim2.new(0, 12, 0, 12)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BackgroundTransparency = 0.3
frame.BorderSizePixel = 0
frame.Parent = screenGui
local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 6)
frameCorner.Parent = frame

local iconLabel = Instance.new("TextLabel")
iconLabel.Name = "Icon"
iconLabel.Size = UDim2.new(0, 28, 1, 0)
iconLabel.Position = UDim2.new(0, 4, 0, 0)
iconLabel.BackgroundTransparency = 1
iconLabel.Text = "☀️"
iconLabel.TextSize = 18
iconLabel.Font = Enum.Font.SourceSansBold
iconLabel.Parent = frame

local timeLabel = Instance.new("TextLabel")
timeLabel.Name = "TimeText"
timeLabel.Size = UDim2.new(0, 80, 1, 0)
timeLabel.Position = UDim2.new(0, 32, 0, 0)
timeLabel.BackgroundTransparency = 1
timeLabel.Text = "辰时"
timeLabel.TextColor3 = Color3.new(1, 1, 1)
timeLabel.TextSize = 16
timeLabel.Font = Enum.Font.SourceSansBold
timeLabel.TextXAlignment = Enum.TextXAlignment.Left
timeLabel.Parent = frame

-- ============================================================
-- 监听时间事件
-- ============================================================
TimeEvent.OnClientEvent:Connect(function(data)
	if not data then return end

	local hourName = data.HourName or (tostring(data.Hour) .. ":00")
	timeLabel.Text = hourName

	if data.IsNight then
		iconLabel.Text = "🌙"
		frame.BackgroundColor3 = Color3.fromRGB(10, 10, 30)
		-- 客户端 Lighting 微调
		Lighting.Ambient = Color3.fromRGB(30, 30, 50)
	else
		iconLabel.Text = "☀️"
		frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		Lighting.Ambient = Color3.fromRGB(127, 127, 127)
	end

	-- 午夜结算提示
	if data.FatigueReduction then
		print("🌙 深夜结算：疲劳 -" .. data.FatigueReduction)
	end
end)

print("🕐 DayNightUI 已启动")
