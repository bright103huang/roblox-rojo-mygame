-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.DayNightUI.local.lua
-- 功能：显示当前时辰和白天/夜晚图标
-- 使用 .local.lua 后缀（Legacy RunContext），适合 StarterPlayerScripts
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- 先创建 UI，再异步连接 TimeEvent（不阻塞 UI 显示）
-- ============================================================
local ok, err = pcall(function()

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DayNightUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
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
iconLabel.Text = "昼"
iconLabel.TextSize = 18
iconLabel.Font = Enum.Font.SourceSansBold
iconLabel.Parent = frame

local timeLabel = Instance.new("TextLabel")
timeLabel.Name = "TimeText"
timeLabel.Size = UDim2.new(0, 80, 1, 0)
timeLabel.Position = UDim2.new(0, 32, 0, 0)
timeLabel.BackgroundTransparency = 1
timeLabel.Text = "--:--"
timeLabel.TextColor3 = Color3.new(1, 1, 1)
timeLabel.TextSize = 16
timeLabel.Font = Enum.Font.SourceSansBold
timeLabel.TextXAlignment = Enum.TextXAlignment.Left
timeLabel.Parent = frame

-- 优先使用 Attribute 初始值（服务端 TimeService 设置）
local initHour = player:GetAttribute("GameHour")
if initHour ~= nil then
	local isNight = player:GetAttribute("IsNight") or false
	local hourNames = {
		"子时", "丑时", "寅时", "卯时",
		"辰时", "巳时", "午时", "未时",
		"申时", "酉时", "戌时", "亥时",
	}
	local idx = math.floor(initHour / 2) + 1
	if idx > 12 then idx = 1 end
	timeLabel.Text = hourNames[idx] or tostring(initHour)
	iconLabel.Text = isNight and "夜" or "昼"
	if isNight then
		frame.BackgroundColor3 = Color3.fromRGB(10, 10, 30)
		Lighting.Ambient = Color3.fromRGB(30, 30, 50)
	else
		frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		Lighting.Ambient = Color3.fromRGB(127, 127, 127)
	end
	print("🕐 DayNightUI 使用 Attribute 初始值:", timeLabel.Text)
end

-- ============================================================
-- 后台查找 TimeEvent（不阻塞 UI）
-- ============================================================
task.spawn(function()
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
		warn("❌ DayNightUI: TimeEvent 未找到（仅使用 Attribute）")
		return
	end

	print("🕐 DayNightUI 已连接 TimeEvent")

	TimeEvent.OnClientEvent:Connect(function(data)
		if not data then return end

		local hourName = data.HourName or (tostring(data.Hour) .. ":00")
		timeLabel.Text = hourName

		if data.IsNight then
			iconLabel.Text = "夜"
			frame.BackgroundColor3 = Color3.fromRGB(10, 10, 30)
			Lighting.Ambient = Color3.fromRGB(30, 30, 50)
		else
			iconLabel.Text = "昼"
			frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
			Lighting.Ambient = Color3.fromRGB(127, 127, 127)
		end

		if data.FatigueReduction then
			print("🌙 深夜结算：疲劳 -" .. data.FatigueReduction)
		end
	end)
end)

end)  -- pcall

if not ok then
	warn("❌ DayNightUI 创建失败:", err)
end

print("🕐 DayNightUI 已启动")
