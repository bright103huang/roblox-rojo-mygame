local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local HomeEvent = require(ReplicatedStorage.Shared.Events.HomeEvents)
local DanConfig = require(ReplicatedStorage.Shared.Config.DanConfig)
local SleepUI = {}
local screenGui, mainFrame, rejectTime, isActive
local backpackRenderFn = nil

-- ============================================================
-- 背包丹药选择面板
-- ============================================================
local function pillName(key)
	local item = DanConfig.Items[key]
	if not item then return key end
	return item.RealName or item.Name
end

local function pillEffectText(key)
	local item = DanConfig.Items[key]
	if not item then return "" end
	local val = item.EffectValue * 2
	local label = ""
	if item.EffectType == "Stamina" then
		label = "体力"
	elseif item.EffectType == "Fatigue" then
		label = "疲劳"
	elseif item.EffectType == "Spirit" then
		label = "精神"
	elseif item.EffectType == "FirePoison" then
		label = "火毒"
	elseif item.EffectType == "AgilityExp" then
		label = "身法"
	elseif item.EffectType == "AlchemyExp" then
		label = "火候"
	elseif item.EffectType == "CombatExp" then
		label = "仙力"
	elseif item.EffectType == "RandomStat" then
		return "随机属性+" .. val
	elseif item.EffectType == "AllStats" then
		return "全属性+" .. val
	end
	if val > 0 then
		return label .. "+" .. val
	else
		return label .. val
	end
end

local function createBackpackPicker(onComplete)
	local picker = Instance.new("Frame")
	picker.Name = "PillPicker"
	picker.Size = UDim2.new(1, 0, 1, 0)
	picker.BackgroundTransparency = 0.4
	picker.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	picker.Parent = screenGui

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, 300, 0, 360)
	panel.Position = UDim2.new(0.5, -150, 0.5, -180)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = picker
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.new(0, 0, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "选择丹药服用"
	title.TextColor3 = Color3.fromRGB(200, 230, 255)
	title.TextSize = 18
	title.Font = Enum.Font.SourceSansBold
	title.Parent = panel

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -10, 0, 250)
	scroll.Position = UDim2.new(0, 5, 0, 48)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = panel

	local selectedPills = {}

	local function renderPills(backpack)
		for _, c in ipairs(scroll:GetChildren()) do c:Destroy() end
		local y = 0
		local hasItems = false
		for itemKey, count in pairs(backpack) do
			if count > 0 then
				hasItems = true
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 36)
				row.Position = UDim2.new(0, 0, 0, y)
				row.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
				row.BackgroundTransparency = 0.2
				row.BorderSizePixel = 0
				row.Parent = scroll
				local rcorner = Instance.new("UICorner")
				rcorner.CornerRadius = UDim.new(0, 4)
				rcorner.Parent = row

				local nameL = Instance.new("TextLabel")
				nameL.Size = UDim2.new(0, 150, 0, 20)
				nameL.Position = UDim2.new(0, 8, 0, 2)
				nameL.BackgroundTransparency = 1
				nameL.Text = pillName(itemKey) .. " (" .. pillEffectText(itemKey) .. ")"
				nameL.TextColor3 = Color3.fromRGB(200, 200, 200)
				nameL.TextSize = 14
				nameL.TextXAlignment = Enum.TextXAlignment.Left
				nameL.Parent = row

				local countL = Instance.new("TextLabel")
				countL.Size = UDim2.new(0, 40, 0, 20)
				countL.Position = UDim2.new(0, 160, 0, 2)
				countL.BackgroundTransparency = 1
				countL.Text = "x" .. tostring(count)
				countL.TextColor3 = Color3.fromRGB(150, 150, 150)
				countL.TextSize = 12
				countL.TextXAlignment = Enum.TextXAlignment.Left
				countL.Parent = row

				local useBtn = Instance.new("TextButton")
				useBtn.Size = UDim2.new(0, 50, 0, 24)
				useBtn.Position = UDim2.new(0, 205, 0, 6)
				useBtn.Text = "服用"
				useBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 180)
				useBtn.TextColor3 = Color3.new(1, 1, 1)
				useBtn.TextSize = 12
				useBtn.Font = Enum.Font.SourceSansBold
				useBtn.BorderSizePixel = 0
				useBtn.Parent = row
				local btnCorner = Instance.new("UICorner")
				btnCorner.CornerRadius = UDim.new(0, 4)
				btnCorner.Parent = useBtn

				local takenL = Instance.new("TextLabel")
				takenL.Size = UDim2.new(0, 40, 0, 20)
				takenL.Position = UDim2.new(0, 260, 0, 2)
				takenL.BackgroundTransparency = 1
				takenL.Text = ""
				takenL.TextColor3 = Color3.fromRGB(150, 255, 150)
				takenL.TextSize = 12
				takenL.TextXAlignment = Enum.TextXAlignment.Left
				takenL.Parent = row

				local remaining = count
				useBtn.MouseButton1Click:Connect(function()
					table.insert(selectedPills, itemKey)
					remaining = remaining - 1
					countL.Text = "x" .. tostring(math.max(0, remaining))
					if remaining <= 0 then
						useBtn.Text = "已空"
						useBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
						useBtn.Active = false
					end
					local taken = 0
					for _, v in ipairs(selectedPills) do
						if v == itemKey then taken = taken + 1 end
					end
					takenL.Text = "已服" .. tostring(taken)
				end)
				y = y + 40
			end
		end
		if not hasItems then
			local emptyL = Instance.new("TextLabel")
			emptyL.Size = UDim2.new(1, 0, 0, 30)
			emptyL.Position = UDim2.new(0, 0, 0, 10)
			emptyL.BackgroundTransparency = 1
			emptyL.Text = "背包中没有丹药"
			emptyL.TextColor3 = Color3.fromRGB(150, 150, 150)
			emptyL.TextSize = 14
			emptyL.Parent = scroll
		end
		scroll.CanvasSize = UDim2.new(0, 0, 0, y + 10)
	end

	backpackRenderFn = renderPills

	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Size = UDim2.new(0, 200, 0, 32)
	confirmBtn.Position = UDim2.new(0.5, -100, 1, -40)
	confirmBtn.Text = "结束服药，去睡觉"
	confirmBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 60)
	confirmBtn.TextColor3 = Color3.new(1, 1, 1)
	confirmBtn.TextSize = 14
	confirmBtn.Font = Enum.Font.SourceSansBold
	confirmBtn.Parent = panel
	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 6)
	cCorner.Parent = confirmBtn
	confirmBtn.MouseButton1Click:Connect(function()
		picker:Destroy()
		onComplete(selectedPills)
	end)

	-- 请求背包数据
	HomeEvent:FireServer("GetBackpack")
end

-- ============================================================
-- 事件监听
-- ============================================================
HomeEvent.OnClientEvent:Connect(function(action, data)
	if action == "StartSleep" then
		if rejectTime and tick() - rejectTime < 5 then return end
		SleepUI:ShowSleepDialog()
	elseif action == "BackpackData" then
		if backpackRenderFn then
			backpackRenderFn(data.Backpack or {})
		end
	elseif action == "SleepSettlement" then
		SleepUI:ShowSettlement(data.Message or "睡眠结束")
	end
end)

-- ============================================================
-- UI 创建
-- ============================================================
function SleepUI:CreateUI()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SleepUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100
	screenGui.Parent = player:WaitForChild("PlayerGui")
	SleepUI:Hide()
end

-- ============================================================
-- 显示三选项弹窗
-- ============================================================
function SleepUI:ShowSleepDialog()
	if not screenGui then SleepUI:CreateUI() end
	screenGui.Enabled = true

	local backdrop = Instance.new("ImageLabel")
	backdrop.Name = "SleepBackdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.Parent = screenGui

	mainFrame = Instance.new("Frame")
	mainFrame.Name = "SleepDialog"
	mainFrame.Size = UDim2.new(0, 300, 0, 200)
	mainFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
	mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
	mainFrame.BackgroundTransparency = 0.1
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = screenGui
	local mCorner = Instance.new("UICorner")
	mCorner.CornerRadius = UDim.new(0, 8)
	mCorner.Parent = mainFrame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 12)
	title.BackgroundTransparency = 1
	title.Text = "睡 觉"
	title.TextColor3 = Color3.fromRGB(200, 230, 255)
	title.TextSize = 24
	title.Font = Enum.Font.SourceSansBold
	title.Parent = mainFrame

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -20, 0, 24)
	desc.Position = UDim2.new(0, 10, 0, 52)
	desc.BackgroundTransparency = 1
	desc.Text = "选择一种方式入睡"
	desc.TextColor3 = Color3.fromRGB(160, 180, 200)
	desc.TextSize = 14
	desc.Parent = mainFrame

	local sleepBtn = Instance.new("TextButton")
	sleepBtn.Size = UDim2.new(0, 260, 0, 36)
	sleepBtn.Position = UDim2.new(0.5, -130, 0, 80)
	sleepBtn.Text = "直接睡觉"
	sleepBtn.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
	sleepBtn.TextColor3 = Color3.new(1, 1, 1)
	sleepBtn.TextSize = 16
	sleepBtn.Font = Enum.Font.SourceSansBold
	sleepBtn.BorderSizePixel = 0
	sleepBtn.Parent = mainFrame
	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 6)
	sCorner.Parent = sleepBtn
	sleepBtn.MouseButton1Click:Connect(function()
		mainFrame:Destroy()
		if backdrop then backdrop:Destroy() end
		SleepUI:SleepFade(function()
			HomeEvent:FireServer("SleepComplete", { Pills = {} })
		end)
	end)

	local pillSleepBtn = Instance.new("TextButton")
	pillSleepBtn.Size = UDim2.new(0, 260, 0, 36)
	pillSleepBtn.Position = UDim2.new(0.5, -130, 0, 124)
	pillSleepBtn.Text = "服用丹药后睡觉"
	pillSleepBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
	pillSleepBtn.TextColor3 = Color3.new(1, 1, 1)
	pillSleepBtn.TextSize = 16
	pillSleepBtn.Font = Enum.Font.SourceSansBold
	pillSleepBtn.BorderSizePixel = 0
	pillSleepBtn.Parent = mainFrame
	local psCorner = Instance.new("UICorner")
	psCorner.CornerRadius = UDim.new(0, 6)
	psCorner.Parent = pillSleepBtn
	pillSleepBtn.MouseButton1Click:Connect(function()
		mainFrame:Destroy()
		if backdrop then backdrop:Destroy() end
		createBackpackPicker(function(selectedPills)
			SleepUI:SleepFade(function()
				HomeEvent:FireServer("SleepComplete", { Pills = selectedPills or {} })
			end)
		end)
	end)

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.new(0, 100, 0, 28)
	cancelBtn.Position = UDim2.new(0.5, -50, 1, -36)
	cancelBtn.Text = "取消"
	cancelBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	cancelBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
	cancelBtn.TextSize = 14
	cancelBtn.Parent = mainFrame
	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 6)
	cCorner.Parent = cancelBtn
	cancelBtn.MouseButton1Click:Connect(function()
		rejectTime = tick()
		SleepUI:Hide()
	end)
end

-- ============================================================
-- 睡眠渐黑效果
-- ============================================================
function SleepUI:SleepFade(onComplete)
	if not screenGui then SleepUI:CreateUI() end
	screenGui.Enabled = true

	local fade = Instance.new("ImageLabel")
	fade.Size = UDim2.new(1, 0, 1, 0)
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 1
	fade.Parent = screenGui

	TweenService:Create(fade, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 0 }):Play()
	task.wait(2)
	if onComplete then onComplete() end
end

-- ============================================================
-- 结算显示
-- ============================================================
function SleepUI:ShowSettlement(message)
	for _, c in ipairs(screenGui:GetChildren()) do
		c:Destroy()
	end

	local fade = Instance.new("ImageLabel")
	fade.Size = UDim2.new(1, 0, 1, 0)
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 0
	fade.Parent = screenGui

	local settleLabel = Instance.new("TextLabel")
	settleLabel.Size = UDim2.new(0, 400, 0, 60)
	settleLabel.Position = UDim2.new(0.5, -200, 0.5, -30)
	settleLabel.BackgroundTransparency = 1
	settleLabel.Text = message or "睡眠结束"
	settleLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
	settleLabel.TextSize = 22
	settleLabel.Font = Enum.Font.SourceSansBold
	settleLabel.Parent = screenGui

	task.wait(3)
	isActive = false
	SleepUI:Hide()
end

-- ============================================================
-- 隐藏
-- ============================================================
function SleepUI:Hide()
	if screenGui then screenGui.Enabled = false end
	if screenGui then
		for _, c in ipairs(screenGui:GetChildren()) do
			c:Destroy()
		end
	end
	mainFrame = nil
end

-- ============================================================
-- 场景切换自动退出
-- ============================================================
player:GetAttributeChangedSignal("CurrentScene"):Connect(function()
	if screenGui and screenGui.Enabled then
		SleepUI:Hide()
	end
end)

SleepUI:CreateUI()
return SleepUI
