local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SceneGuideContent = require(ReplicatedStorage.Shared.Config.SceneGuideContent)

local SceneGuideUI = {}

function SceneGuideUI.Show(sceneName)
	local content = SceneGuideContent[sceneName]
	if not content then return end

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SceneGuide_" .. sceneName
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100
	screenGui.Parent = playerGui

	-- backdrop
	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.Parent = screenGui

	-- main window frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, 350, 0, 50 + #content.lines * 28)
	mainFrame.Position = UDim2.new(0.5, -175, 0.5, -(25 + #content.lines * 14))
	mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
	mainFrame.BackgroundTransparency = 0.2
	mainFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = mainFrame

	-- title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 36)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = content.title
	title.TextColor3 = Color3.fromRGB(255, 200, 100)
	title.TextSize = 22
	title.Font = Enum.Font.SourceSansBold
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Parent = mainFrame

	-- guide lines
	local y = 50
	for _, line in ipairs(content.lines) do
		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, -20, 0, 24)
		textLabel.Position = UDim2.new(0, 10, 0, y)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = line
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		textLabel.TextSize = 14
		textLabel.TextXAlignment = Enum.TextXAlignment.Left
		textLabel.TextWrapped = true
		textLabel.Parent = mainFrame
		y = y + 26
	end

	-- close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 120, 0, 30)
	closeBtn.Position = UDim2.new(0.5, -60, 0, y + 10)
	closeBtn.Text = "知道了"
	closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.SourceSansBold
	closeBtn.Parent = mainFrame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		screenGui:Destroy()
	end)
end

return SceneGuideUI
