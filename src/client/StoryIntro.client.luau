-- StoryIntro.client.lua
--[[
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "IntroGui"
screenGui.IgnoreGuiInset = true
screenGui.Parent = pGui

local blackFrame = Instance.new("Frame")
blackFrame.Size = UDim2.new(1, 0, 1, 0)
blackFrame.BackgroundColor3 = Color3.new(0, 0, 0)
blackFrame.Parent = screenGui

local storyLabel = Instance.new("TextLabel")
storyLabel.Size = UDim2.new(0.8, 0, 0.2, 0)
storyLabel.Position = UDim2.new(0.1, 0, 0.4, 0)
storyLabel.BackgroundTransparency = 1
storyLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
storyLabel.TextScaled = true
storyLabel.Font = Enum.Font.SourceSansItalic
storyLabel.Parent = screenGui

local function typeWrite(text)
	storyLabel.Text = ""
	storyLabel.TextTransparency = 0

	for i = 1, #text do
		storyLabel.Text = string.sub(text, 1, i)
		task.wait(0.05)
	end

	task.wait(2)
	TweenService:Create(storyLabel, TweenInfo.new(1), {TextTransparency = 1}):Play()
	task.wait(1)
end

task.spawn(function()
	task.wait(1)

	typeWrite("我在地球修炼万年，终成化神，破碎虚空...")
	typeWrite("本以为飞升之后是万仙朝拜，长生久视...")
	typeWrite("谁承想，这天庭御膳房...竟还缺个传菜的。")

	TweenService:Create(blackFrame, TweenInfo.new(2), {BackgroundTransparency = 1}):Play()

	task.wait(2)
	screenGui:Destroy()
end)  ]] 