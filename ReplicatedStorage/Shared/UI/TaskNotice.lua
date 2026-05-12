-- ============================================================
-- 文件：ReplicatedStorage.Shared.UI.TaskNotice.lua
-- 功能：统一提示弹窗 — 轻量通知，3 秒自动消失
-- 被 TaskClient.local.luau 或其他客户端模块 require
-- ============================================================

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local TaskNotice = {}

function TaskNotice:Notify(config)
	config = config or {}
	local title = config.Title or "提示"
	local text = config.Text or ""
	local color = config.Color or Color3.fromRGB(255, 215, 0)
	local duration = config.Duration or 3

	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TaskNotice_" .. tick()
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 50
	screenGui.Parent = playerGui

	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.new(0, 320, 0, 80)
	bg.Position = UDim2.new(0.5, -160, 0.15, 0)
	bg.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
	bg.BackgroundTransparency = 0.15
	bg.BorderSizePixel = 0
	bg.Parent = screenGui

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 10)
	bgCorner.Parent = bg

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -20, 0, 24)
	titleLabel.Position = UDim2.new(0, 10, 0, 6)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = color
	titleLabel.TextSize = 16
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Parent = bg

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Text"
	textLabel.Size = UDim2.new(1, -20, 0, 40)
	textLabel.Position = UDim2.new(0, 10, 0, 32)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextSize = 14
	textLabel.Font = Enum.Font.SourceSans
	textLabel.TextWrapped = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Center
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.Parent = bg

	task.delay(duration, function()
		if screenGui and screenGui.Parent then
			screenGui:Destroy()
		end
	end)
end

return TaskNotice
