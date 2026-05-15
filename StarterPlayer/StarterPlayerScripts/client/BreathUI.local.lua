local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local HomeEvent = require(ReplicatedStorage.Shared.Events.HomeEvents)
local ShopEvent = ReplicatedStorage:FindFirstChild("Events"):FindFirstChild("ShopEvent")
local AnimationFactory = require(ReplicatedStorage.Shared.Modules.AnimationFactory)
local BreathUI = {}
local isActive, isHolding, inhaleStartTime, holdStartTime, breathCount, malAdjust, currentTrack
local screenGui, outerRing, phaseLabel, feedbackLabel, breathCounter, backpackFrame
local confirmFrame

local EXPAND_DURATION = 2.0
local HOLD_DURATION = 2.0
local TOTAL_BREATHS = 3
local MIN_INHALE_TIME = 1.0  -- 气球够大才能按 F

function BreathUI:CreateUI()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BreathUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")
	local backdrop = Instance.new("ImageLabel")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.Parent = screenGui
	local rc = Instance.new("Frame")
	rc.Name = "RingContainer"
	rc.Size = UDim2.new(0, 200, 0, 200)
	rc.Position = UDim2.new(0.5, -100, 0.5, -120)
	rc.BackgroundTransparency = 1
	rc.Parent = screenGui
	outerRing = Instance.new("Frame")
	outerRing.Name = "OuterRing"
	outerRing.Size = UDim2.new(0, 40, 0, 40)
	outerRing.Position = UDim2.new(0.5, -20, 0.5, -20)
	outerRing.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
	outerRing.BackgroundTransparency = 0.6
	outerRing.Parent = rc
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = outerRing
	phaseLabel = Instance.new("TextLabel")
	phaseLabel.Size = UDim2.new(0, 200, 0, 30)
	phaseLabel.Position = UDim2.new(0.5, -100, 0.5, 50)
	phaseLabel.BackgroundTransparency = 1
	phaseLabel.Text = ""
	phaseLabel.TextColor3 = Color3.fromRGB(200, 230, 255)
	phaseLabel.TextSize = 24
	phaseLabel.Parent = screenGui
	feedbackLabel = Instance.new("TextLabel")
	feedbackLabel.Size = UDim2.new(0, 300, 0, 24)
	feedbackLabel.Position = UDim2.new(0.5, -150, 0.5, 80)
	feedbackLabel.BackgroundTransparency = 1
	feedbackLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
	feedbackLabel.TextSize = 18
	feedbackLabel.Parent = screenGui
	breathCounter = Instance.new("TextLabel")
	breathCounter.Size = UDim2.new(0, 200, 0, 20)
	breathCounter.Position = UDim2.new(0.5, -100, 0.5, 105)
	breathCounter.BackgroundTransparency = 1
	breathCounter.TextColor3 = Color3.fromRGB(150, 200, 255)
	breathCounter.TextSize = 14
	breathCounter.Parent = screenGui
	backpackFrame = Instance.new("Frame")
	backpackFrame.Size = UDim2.new(0, 120, 0, 300)
	backpackFrame.Position = UDim2.new(0, 10, 0.5, -150)
	backpackFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	backpackFrame.BackgroundTransparency = 0.3
	backpackFrame.Parent = screenGui
	local bpLabel = Instance.new("TextLabel")
	bpLabel.Size = UDim2.new(1, 0, 0, 24)
	bpLabel.BackgroundTransparency = 1
	bpLabel.Text = "丹药"
	bpLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	bpLabel.TextSize = 14
	bpLabel.Parent = backpackFrame

	-- 确认弹窗：是否打坐？
	confirmFrame = Instance.new("Frame")
	confirmFrame.Name = "ConfirmFrame"
	confirmFrame.Size = UDim2.new(0, 300, 0, 160)
	confirmFrame.Position = UDim2.new(0.5, -150, 0.5, -80)
	confirmFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
	confirmFrame.BackgroundTransparency = 0.15
	confirmFrame.Parent = screenGui
	local confirmCorner = Instance.new("UICorner")
	confirmCorner.CornerRadius = UDim.new(0, 8)
	confirmCorner.Parent = confirmFrame
	local confirmTitle = Instance.new("TextLabel")
	confirmTitle.Size = UDim2.new(1, 0, 0, 40)
	confirmTitle.Position = UDim2.new(0, 0, 0, 15)
	confirmTitle.BackgroundTransparency = 1
	confirmTitle.Text = "是否打坐？"
	confirmTitle.TextColor3 = Color3.fromRGB(200, 230, 255)
	confirmTitle.TextSize = 22
	confirmTitle.Font = Enum.Font.SourceSansBold
	confirmTitle.Parent = confirmFrame
	local confirmDesc = Instance.new("TextLabel")
	confirmDesc.Size = UDim2.new(1, -20, 0, 36)
	confirmDesc.Position = UDim2.new(0, 10, 0, 55)
	confirmDesc.BackgroundTransparency = 1
	confirmDesc.Text = '选"打坐"后等气球变大→长按F 2秒→闭气完成\n累计3次入定成功 | 按Q退出'
	confirmDesc.TextColor3 = Color3.fromRGB(160, 180, 200)
	confirmDesc.TextSize = 14
	confirmDesc.TextWrapped = true
	confirmDesc.Parent = confirmFrame
	local function makeConfirmBtn(text, posX, color, onClick)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 100, 0, 32)
		btn.Position = UDim2.new(0, posX, 0, 110)
		btn.Text = text
		btn.BackgroundColor3 = color
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextSize = 16
		btn.Font = Enum.Font.SourceSansBold
		btn.Parent = confirmFrame
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = btn
		btn.MouseButton1Click:Connect(onClick)
	end
	makeConfirmBtn("取消", 30, Color3.fromRGB(80, 80, 100), function()
		confirmFrame.Visible = false
		screenGui.Enabled = false
	end)
	makeConfirmBtn("打坐", 170, Color3.fromRGB(60, 120, 200), function()
		confirmFrame.Visible = false
		BreathUI:Start()
	end)

	BreathUI:Hide()
end

function BreathUI:Start()
	screenGui.Enabled = true
	isActive = true
	isHolding = false
	breathCount = 0
	breathCounter.Text = "呼吸 0/" .. TOTAL_BREATHS
	feedbackLabel.Text = ""
	local malice = player:GetAttribute("Malice") or 0
	malAdjust = 1.0
	if malice > 50 then BreathUI:Hide(); return end
	if malice > 30 then malAdjust = 1.33 end
	local char = player.Character
	if char then
		local humanoid = char:FindFirstChild("Humanoid")
		if humanoid then
			currentTrack = AnimationFactory:PlayAnimation(humanoid, AnimationFactory:CreateSitSequence())
			humanoid.WalkSpeed = 0
			humanoid.AutoRotate = false
		end
	end
	HomeEvent:FireServer("GetBackpack")
	BreathUI:StartInhale()
end

function BreathUI:Hide()
	isActive = false
	isHolding = false
	if screenGui then screenGui.Enabled = false end
	if confirmFrame then confirmFrame.Visible = false end
end

function BreathUI:StartInhale()
	if not isActive then return end
	phaseLabel.Text = "吸气"
	feedbackLabel.Text = "等气球变大，然后按住 F"
	inhaleStartTime = tick()
	outerRing.Size = UDim2.new(0, 40, 0, 40)
	local dur = EXPAND_DURATION / (malAdjust or 1)
	TweenService:Create(outerRing, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 200, 0, 200) }):Play()
end

function BreathUI:CompleteBreath()
	if not isActive then return end
	breathCount = breathCount + 1
	breathCounter.Text = "呼吸 " .. breathCount .. "/" .. TOTAL_BREATHS
	if breathCount >= TOTAL_BREATHS then
		feedbackLabel.Text = "入定成功！"
		phaseLabel.Text = "完成"
		HomeEvent:FireServer("BreathResult", { Judgment = "perfect", Layer = 3 })
		task.wait(2)
		BreathUI:End()
	else
		feedbackLabel.Text = "呼吸法完成！（" .. breathCount .. "/" .. TOTAL_BREATHS .. "）"
		phaseLabel.Text = "呼气"
		task.wait(0.8)
		BreathUI:StartInhale()
	end
end

function BreathUI:End()
	if currentTrack then pcall(function() currentTrack:Stop() end); currentTrack = nil end
	local char = player.Character
	if char then
		local humanoid = char:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.AutoRotate = true
			humanoid.WalkSpeed = 16
		end
	end
	BreathUI:Hide()
end

-- 长按检测循环
task.spawn(function()
	while true do
		task.wait(0.1)
		if isActive and isHolding then
			if tick() - holdStartTime >= HOLD_DURATION then
				isHolding = false
				BreathUI:CompleteBreath()
			end
		end
	end
end)

-- 输入处理（连接一次永不断开，用 isActive 控制）
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	-- Q 键：无论是否冥想中，只要界面可见就退出
	if input.KeyCode == Enum.KeyCode.Q then
		if isActive or (confirmFrame and confirmFrame.Visible) then
			BreathUI:End()
		end
		return
	end
	if not isActive then return end
	if input.KeyCode == Enum.KeyCode.F and not isHolding then
		local elapsed = tick() - inhaleStartTime
		if elapsed >= MIN_INHALE_TIME then
			isHolding = true
			holdStartTime = tick()
			phaseLabel.Text = "闭气中..."
			feedbackLabel.Text = "保持按住 F..." .. HOLD_DURATION .. " 秒"
		else
			feedbackLabel.Text = "气球还不够大，再等等"
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gp)
	if not isActive or gp then return end
	if input.KeyCode == Enum.KeyCode.F and isHolding then
		isHolding = false
		local held = tick() - holdStartTime
		if held < HOLD_DURATION then
			feedbackLabel.Text = "松开太早，等气球变大再按住 F"
			phaseLabel.Text = "吸气"
		end
	end
end)

-- 切换场景自动退出
player:GetAttributeChangedSignal("CurrentScene"):Connect(function()
	if isActive then BreathUI:End() end
end)

HomeEvent.OnClientEvent:Connect(function(action, data)
	if action == "StartMeditation" then
		screenGui.Enabled = true
		confirmFrame.Visible = true
	elseif action == "BackpackData" then
		for _, child in ipairs(backpackFrame:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		local y = 30
		for itemKey, count in pairs(data.Backpack or {}) do
			if count <= 0 then continue end
			local btn = Instance.new("TextButton")
			btn.Name = itemKey
			btn.Size = UDim2.new(1, -10, 0, 28)
			btn.Position = UDim2.new(0, 5, 0, y)
			btn.Text = itemKey .. " x" .. count
			btn.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
			btn.TextColor3 = Color3.fromRGB(200, 200, 200)
			btn.TextSize = 12
			btn.Parent = backpackFrame
			btn.MouseButton1Click:Connect(function()
				if not isActive then return end
				ShopEvent:FireServer("UseItem:Shop", nil, { ItemKey = itemKey, IsMeditating = true })
				task.wait(0.3)
				HomeEvent:FireServer("GetBackpack")
			end)
			y = y + 32
		end
	end
end)

BreathUI:CreateUI()
return BreathUI
