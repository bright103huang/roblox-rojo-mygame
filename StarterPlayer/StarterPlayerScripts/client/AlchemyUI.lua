-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.AlchemyUI.lua
-- 功能：炼丹结果弹窗 + 添柴动画
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- UI 状态
-- ============================================================
local AlchemyUI = {}
local screenGui = nil
local closeHandle = nil  -- 添柴自动关闭定时器句柄

-- ============================================================
-- 颜色常量
-- ============================================================
local COLORS = {
	Bg = Color3.fromRGB(20, 20, 30),
	Panel = Color3.fromRGB(30, 30, 45),
	Gold = Color3.fromRGB(255, 215, 0),
	Red = Color3.fromRGB(255, 60, 60),
	Green = Color3.fromRGB(80, 200, 80),
	White = Color3.new(1, 1, 1),
	Gray = Color3.fromRGB(150, 150, 150),
	Fire1 = Color3.fromRGB(100, 80, 40),
	Fire2 = Color3.fromRGB(200, 130, 30),
	Fire3 = Color3.fromRGB(255, 180, 50),
}

-- ============================================================
-- 添柴动画：显示添柴进度条 + 火焰渐变
-- ============================================================
function AlchemyUI:ShowFire(step)
	-- 取消前一个待执行的自动关闭（防止与 ShowResult 冲突）
	if closeHandle then
		task.cancel(closeHandle)
		closeHandle = nil
	end

	-- 关闭旧 UI（如果有）
	self:Close()

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AlchemyFuelUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- 半透明遮罩
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui

	-- 中央面板
	local panel = Instance.new("Frame")
	panel.Name = "FuelPanel"
	panel.Size = UDim2.new(0, 280, 0, 120)
	panel.Position = UDim2.new(0.5, -140, 0.5, -60)
	panel.BackgroundColor3 = COLORS.Panel
	panel.BorderSizePixel = 0
	panel.Parent = screenGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	-- 火焰图标
	local fireLabel = Instance.new("TextLabel")
	fireLabel.Size = UDim2.new(0, 40, 0, 40)
	fireLabel.Position = UDim2.new(0.5, -20, 0, 12)
	fireLabel.BackgroundTransparency = 1
	fireLabel.Text = "🔥"
	fireLabel.TextSize = 28
	fireLabel.Parent = panel

	-- 进度文字（step = 1/2/3）
	local stepColors = { [1] = COLORS.Fire1, [2] = COLORS.Fire2, [3] = COLORS.Fire3 }
	local stepLabels = { [1] = "添柴 1/3", [2] = "添柴 2/3", [3] = "🔥 添柴 3/3" }

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -20, 0, 30)
	textLabel.Position = UDim2.new(0, 10, 0, 55)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = stepLabels[step] or "添柴中"
	textLabel.TextColor3 = stepColors[step] or COLORS.White
	textLabel.TextSize = 20
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.Parent = panel

	-- 进度条背景
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(0.8, 0, 0, 6)
	barBg.Position = UDim2.new(0.1, 0, 0, 90)
	barBg.BackgroundColor3 = COLORS.Bg
	barBg.BorderSizePixel = 0
	barBg.Parent = panel
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 3)
	barCorner.Parent = barBg

	-- 进度条填充
	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(step / 3, 0, 1, 0)
	barFill.BackgroundColor3 = stepColors[step] or COLORS.Gold
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 3)
	fillCorner.Parent = barFill

	-- 渐入动画
	local tween = TweenService:Create(overlay, TweenInfo.new(0.3), { BackgroundTransparency = 0.5 })
	tween:Play()

	-- 1.2 秒后自动关闭，保存句柄以便取消
	closeHandle = task.delay(1.2, function()
		closeHandle = nil
		self:Close()
	end)
end

-- ============================================================
-- 成丹动画：光球飞入葫芦
-- ============================================================
function AlchemyUI:ShowFlyToBottle()
	if not screenGui then return end

	local orb = Instance.new("Frame")
	orb.Name = "Orb"
	orb.Size = UDim2.new(0, 16, 0, 16)
	orb.Position = UDim2.new(0.5, -8, 0.5, -8)
	orb.BackgroundColor3 = COLORS.Gold
	orb.BorderSizePixel = 0
	orb.Parent = screenGui
	local orbCorner = Instance.new("UICorner")
	orbCorner.CornerRadius = UDim.new(1, 0)
	orbCorner.Parent = orb

	-- 发光效果
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.Size = UDim2.new(3, 0, 3, 0)
	glow.Position = UDim2.new(-1, 0, -1, 0)
	glow.BackgroundColor3 = COLORS.Gold
	glow.BackgroundTransparency = 0.6
	glow.BorderSizePixel = 0
	glow.Parent = orb
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(1, 0)
	glowCorner.Parent = glow

	-- 飞到右上角葫芦位置
	local targetPos = UDim2.new(0.9, -8, 0.05, 0)
	local flyTween = TweenService:Create(orb, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = targetPos,
		Size = UDim2.new(0, 4, 0, 4),
	})
	flyTween:Play()
	flyTween.Completed:Wait()
	orb:Destroy()
end

-- ============================================================
-- 显示结果弹窗（由 TaskClient / ShowResult 调用）
-- ============================================================
function AlchemyUI:ShowResult(success, data)
	-- 关闭添柴 UI（如果有）
	self:Close()

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AlchemyResultUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.6
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui

	-- 点击遮罩可关闭
	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			self:Close()
		end
	end)

	-- 弹窗面板
	local panel = Instance.new("Frame")
	panel.Name = "ResultPanel"
	panel.Size = UDim2.new(0, 320, 0, 160)
	panel.Position = UDim2.new(0.5, -160, 0.5, -80)
	panel.BackgroundColor3 = COLORS.Panel
	panel.BorderSizePixel = 0
	panel.Parent = screenGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	if success then
		-- 成丹
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 40)
		title.Position = UDim2.new(0, 0, 0, 12)
		title.BackgroundTransparency = 1
		title.Text = "✅ 炼丹成功"
		title.TextColor3 = COLORS.Green
		title.TextSize = 24
		title.Font = Enum.Font.SourceSansBold
		title.Parent = panel

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -20, 0, 50)
		desc.Position = UDim2.new(0, 10, 0, 56)
		desc.BackgroundTransparency = 1
		desc.Text = "回气丹 +20 体力\n仙晶 +15  火候经验 +8"
		desc.TextColor3 = COLORS.Gold
		desc.TextSize = 16
		desc.Font = Enum.Font.SourceSans
		desc.LineHeight = 1.4
		desc.Parent = panel

		local chanceText = Instance.new("TextLabel")
		chanceText.Size = UDim2.new(1, -20, 0, 24)
		chanceText.Position = UDim2.new(0, 10, 0, 110)
		chanceText.BackgroundTransparency = 1
		chanceText.Text = "成功率 " .. (data and data.SuccessChance or "?") .. "%"
		chanceText.TextColor3 = COLORS.Gray
		chanceText.TextSize = 13
		chanceText.Font = Enum.Font.SourceSans
		chanceText.Parent = panel

		-- 播放成丹飞入葫芦动画
		task.spawn(function()
			task.wait(0.3)
			self:ShowFlyToBottle()
		end)
	else
		-- 炸炉
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 40)
		title.Position = UDim2.new(0, 0, 0, 12)
		title.BackgroundTransparency = 1
		local reason = data and data.Reason or ""
		if reason == "Explosion" then
			title.Text = "💥 炸炉了！"
		elseif reason == "虚不受补" then
			title.Text = "💊 虚不受补"
		else
			title.Text = "❌ 炼制失败"
		end
		title.TextColor3 = COLORS.Red
		title.TextSize = 24
		title.Font = Enum.Font.SourceSansBold
		title.Parent = panel

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -20, 0, 40)
		desc.Position = UDim2.new(0, 10, 0, 60)
		desc.BackgroundTransparency = 1
		if reason == "Explosion" then
			desc.Text = "材料尽毁，精神受损，下次小心火候"
		elseif reason == "虚不受补" then
			desc.Text = "身体太虚，承受不住药力……"
		else
			desc.Text = reason
		end
		desc.TextColor3 = COLORS.Gray
		desc.TextSize = 14
		desc.Font = Enum.Font.SourceSans
		desc.Parent = panel
	end

	-- 关闭按钮
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 100, 0, 30)
	closeBtn.Position = UDim2.new(0.5, -50, 1, -40)
	closeBtn.BackgroundColor3 = COLORS.DarkGray or Color3.fromRGB(60, 60, 80)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "知道了"
	closeBtn.TextColor3 = COLORS.White
	closeBtn.TextSize = 14
	closeBtn.Font = Enum.Font.SourceSansBold
	closeBtn.Parent = panel
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- 3 秒后自动关闭
	task.delay(3, function()
		self:Close()
	end)
end

-- ============================================================
-- 关闭
-- ============================================================
function AlchemyUI:Close()
	if closeHandle then
		task.cancel(closeHandle)
		closeHandle = nil
	end
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return AlchemyUI
