-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.ShopUI.client.lua
-- 功能：仙丹阁商店 UI + 砍价对话 + 购买立即服用提示
-- 通信：通过 ShopEvent 与服务端交互
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- 获取 ShopEvent
-- ============================================================
local ShopEvent = nil
local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
if eventsFolder then
	ShopEvent = eventsFolder:WaitForChild("ShopEvent", 15)
end

-- ============================================================
-- UI 状态
-- ============================================================
local ShopUI = {}
local screenGui = nil
local currentShopData = nil
local itemButtons = {}  -- [itemKey] = { frame, buyBtn, countLabel, bargainBtn }
local bargainState = {} -- [itemKey] = { discounted = bool }
local uiRefs = {}

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
	DarkGray = Color3.fromRGB(60, 60, 60),
}

-- ============================================================
-- 创建 UI
-- ============================================================
function ShopUI:Create()
	if screenGui then return end
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShopUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100
	screenGui.Parent = playerGui

	-- 背景遮罩
	local backdrop = Instance.new("ImageLabel")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.ImageTransparency = 1
	backdrop.Parent = screenGui

	-- 主面板
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 350, 0, 460)
	panel.Position = UDim2.new(1, -370, 0.5, -230)
	panel.BackgroundColor3 = COLORS.Bg
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Parent = screenGui
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 8)
	panelCorner.Parent = panel

	-- 标题
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "仙 丹 阁"
	title.TextColor3 = COLORS.Gold
	title.TextSize = 22
	title.Font = Enum.Font.SourceSansBold
	title.Parent = panel

	-- 仙晶余额
	local xianJingL = Instance.new("TextLabel")
	xianJingL.Size = UDim2.new(0, 150, 0, 20)
	xianJingL.Position = UDim2.new(0, 10, 0, 44)
	xianJingL.BackgroundTransparency = 1
	xianJingL.Text = "仙晶: 0"
	xianJingL.TextColor3 = COLORS.Gold
	xianJingL.TextSize = 14
	xianJingL.Font = Enum.Font.SourceSansBold
	xianJingL.Parent = panel
	uiRefs.xianJingLabel = xianJingL

	-- 选项卡（商店/背包）
	local tabFrame = Instance.new("Frame")
	tabFrame.Size = UDim2.new(1, 0, 0, 30)
	tabFrame.Position = UDim2.new(0, 0, 0, 68)
	tabFrame.BackgroundTransparency = 1
	tabFrame.Parent = panel

	local shopTab = Instance.new("TextButton")
	shopTab.Size = UDim2.new(0.5, 0, 1, 0)
	shopTab.Text = "商店"
	shopTab.BackgroundColor3 = COLORS.Panel
	shopTab.TextColor3 = COLORS.White
	shopTab.TextSize = 16
	shopTab.Font = Enum.Font.SourceSansBold
	shopTab.BorderSizePixel = 0
	shopTab.Parent = tabFrame
	shopTab.MouseButton1Click:Connect(function()
		currentTab = "shop"
		ShopUI:RefreshUI(currentShopData)
	end)

	local bpTab = Instance.new("TextButton")
	bpTab.Size = UDim2.new(0.5, 0, 1, 0)
	bpTab.Position = UDim2.new(0.5, 0, 0, 0)
	bpTab.Text = "背包"
	bpTab.BackgroundColor3 = COLORS.Panel
	bpTab.TextColor3 = COLORS.White
	bpTab.TextSize = 16
	bpTab.Font = Enum.Font.SourceSansBold
	bpTab.BorderSizePixel = 0
	bpTab.Parent = tabFrame
	bpTab.MouseButton1Click:Connect(function()
		currentTab = "backpack"
		ShopUI:RefreshUI(currentShopData)
	end)

	-- 内容区域（滚动）
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "ScrollFrame"
	scroll.Size = UDim2.new(1, -10, 1, -170)
	scroll.Position = UDim2.new(0, 5, 0, 100)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = panel
	uiRefs.scrollFrame = scroll

	-- 购买结果弹窗（隐藏）
	local resultFrame = Instance.new("Frame")
	resultFrame.Name = "ResultPopup"
	resultFrame.Size = UDim2.new(0, 250, 0, 80)
	resultFrame.Position = UDim2.new(0.5, -125, 0.5, -40)
	resultFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
	resultFrame.BackgroundTransparency = 1
	resultFrame.BorderSizePixel = 0
	resultFrame.Visible = false
	resultFrame.Parent = screenGui
	local resCorner = Instance.new("UICorner")
	resCorner.CornerRadius = UDim.new(0, 8)
	resCorner.Parent = resultFrame
	local resultTitle = Instance.new("TextLabel")
	resultTitle.Size = UDim2.new(1, 0, 0, 28)
	resultTitle.Position = UDim2.new(0, 0, 0, 4)
	resultTitle.BackgroundTransparency = 1
	resultTitle.Text = ""
	resultTitle.TextSize = 16
	resultTitle.Font = Enum.Font.SourceSansBold
	resultTitle.Parent = resultFrame
	local resultMessage = Instance.new("TextLabel")
	resultMessage.Size = UDim2.new(1, -10, 0, 36)
	resultMessage.Position = UDim2.new(0, 5, 0, 32)
	resultMessage.BackgroundTransparency = 1
	resultMessage.Text = ""
	resultMessage.TextSize = 14
	resultMessage.Font = Enum.Font.SourceSans
	resultMessage.Parent = resultFrame

	uiRefs.resultPopup = resultFrame
	uiRefs.resultTitle = resultTitle
	uiRefs.resultMsg = resultMessage
	ShopUI:CreateBargainPopup(screenGui)

	-- 关闭按钮
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 60, 0, 24)
	closeBtn.Position = UDim2.new(1, -70, 0, 10)
	closeBtn.Text = "关闭"
	closeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	closeBtn.TextColor3 = COLORS.Gray
	closeBtn.TextSize = 12
	closeBtn.Parent = panel
	closeBtn.MouseButton1Click:Connect(function() ShopUI:Close() end)
	local clsCorner = Instance.new("UICorner")
	clsCorner.CornerRadius = UDim.new(0, 4)
	clsCorner.Parent = closeBtn
end

-- ============================================================
-- 渲染商店物品
-- ============================================================
function ShopUI:RenderItems()
	local scroll = uiRefs.scrollFrame
	if not scroll then return end
	for _, child in ipairs(scroll:GetChildren()) do
		child:Destroy()
	end
	itemButtons = {}
	local data = currentShopData
	if not data or not data.Items then return end
	local purchases = data.DailyPurchases or {}
	local xianJing = data.XianJing or 0

	local y = 0
	for itemKey, item in pairs(data.Items) do
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -10, 0, 60)
		card.Position = UDim2.new(0, 5, 0, y)
		card.BackgroundColor3 = COLORS.Panel
		card.BackgroundTransparency = 0.1
		card.BorderSizePixel = 0
		card.Parent = scroll
		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 6)
		cardCorner.Parent = card

		local nameL = Instance.new("TextLabel")
		nameL.Size = UDim2.new(0, 110, 0, 20)
		nameL.Position = UDim2.new(0, 6, 0, 2)
		nameL.BackgroundTransparency = 1
		nameL.Text = item.Name
		nameL.TextColor3 = item.IsHidden and COLORS.DarkGray or COLORS.White
		nameL.TextSize = 14
		nameL.Font = Enum.Font.SourceSansBold
		nameL.TextXAlignment = Enum.TextXAlignment.Left
		nameL.Parent = card

		local descL = Instance.new("TextLabel")
		descL.Size = UDim2.new(0, 140, 0, 16)
		descL.Position = UDim2.new(0, 6, 0, 22)
		descL.BackgroundTransparency = 1
		if item.IsHidden then
			descL.Text = "仙晶达到 " .. tostring(item.Price) .. " 后揭晓"
		else
			descL.Text = item.Description
		end
		descL.TextColor3 = item.IsHidden and COLORS.DarkGray or COLORS.Gray
		descL.TextSize = 11
		descL.Font = Enum.Font.SourceSans
		descL.TextXAlignment = Enum.TextXAlignment.Left
		descL.Parent = card

		local priceL = Instance.new("TextLabel")
		priceL.Size = UDim2.new(0, 110, 0, 16)
		priceL.Position = UDim2.new(0, 6, 0, 38)
		priceL.BackgroundTransparency = 1
		priceL.Text = "仙晶 x" .. tostring(item.Price)
		priceL.TextColor3 = COLORS.Gold
		priceL.TextSize = 11
		priceL.Font = Enum.Font.SourceSansBold
		priceL.TextXAlignment = Enum.TextXAlignment.Left
		priceL.Parent = card

		if item.DailyLimit and item.DailyLimit > 0 then
			local bought = purchases[itemKey] or 0
			local remaining = item.DailyLimit - bought
			priceL.Text = priceL.Text .. " | 剩" .. tostring(remaining)
		end

		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyBtn_" .. itemKey
		buyBtn.Size = UDim2.new(0, 58, 0, 24)
		buyBtn.Position = UDim2.new(0, 125, 0, 3)
		buyBtn.Text = "购买"
		buyBtn.TextColor3 = COLORS.White
		buyBtn.TextSize = 12
		buyBtn.Font = Enum.Font.SourceSansBold
		buyBtn.BorderSizePixel = 0
		buyBtn.Parent = card

		local bargainBtn = Instance.new("TextButton")
		bargainBtn.Size = UDim2.new(0, 58, 0, 24)
		bargainBtn.Position = UDim2.new(0, 125, 0, 30)
		bargainBtn.Text = "砍价"
		bargainBtn.TextColor3 = COLORS.White
		bargainBtn.TextSize = 12
		bargainBtn.Font = Enum.Font.SourceSansBold
		bargainBtn.BorderSizePixel = 0
		bargainBtn.Parent = card

		if item.IsHidden then
			buyBtn.Text = "???"
			buyBtn.BackgroundColor3 = COLORS.DarkGray
			bargainBtn.Text = "???"
			bargainBtn.BackgroundColor3 = COLORS.DarkGray
		else
			if xianJing < item.Price then
				buyBtn.BackgroundColor3 = COLORS.Red
			else
				buyBtn.BackgroundColor3 = COLORS.Green
			end
			if item.DailyLimit and item.DailyLimit > 0 then
				local bought = purchases[itemKey] or 0
				if bought >= item.DailyLimit then
					buyBtn.Text = "已售罄"
					buyBtn.BackgroundColor3 = COLORS.DarkGray
				end
			end

			local bState = bargainState[itemKey]
			if bState and bState.discounted then
				bargainBtn.Text = "已砍"
				bargainBtn.BackgroundColor3 = COLORS.DarkGray
			else
				bargainBtn.BackgroundColor3 = Color3.fromRGB(180, 150, 50)
				bargainBtn.MouseButton1Click:Connect(function()
					if ShopEvent then
						ShopEvent:FireServer("Bargain:Shop", nil, { ItemKey = itemKey })
					end
				end)
			end

			buyBtn.MouseButton1Click:Connect(function()
				if ShopEvent then
					ShopEvent:FireServer("Purchase:Shop", nil, { ItemKey = itemKey })
				end
			end)
		end

		itemButtons[itemKey] = { card = card, buyBtn = buyBtn, bargainBtn = bargainBtn }
		y = y + 65
	end
	scroll.CanvasSize = UDim2.new(0, 0, 0, y + 10)
end

-- ============================================================
-- 渲染背包
-- ============================================================
function ShopUI:RenderBackpack()
	local scroll = uiRefs.scrollFrame
	if not scroll then return end
	for _, child in ipairs(scroll:GetChildren()) do
		child:Destroy()
	end
	local data = currentShopData
	if not data then return end
	local backpack = data.Backpack or {}
	local y = 0
	for itemKey, count in pairs(backpack) do
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -10, 0, 50)
		card.Position = UDim2.new(0, 5, 0, y)
		card.BackgroundColor3 = COLORS.Panel
		card.BackgroundTransparency = 0.1
		card.BorderSizePixel = 0
		card.Parent = scroll
		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 6)
		cardCorner.Parent = card

		local nameL = Instance.new("TextLabel")
		nameL.Size = UDim2.new(0, 100, 0, 20)
		nameL.Position = UDim2.new(0, 6, 0, 2)
		nameL.BackgroundTransparency = 1
		nameL.Text = itemKey
		nameL.TextColor3 = COLORS.White
		nameL.TextSize = 14
		nameL.Font = Enum.Font.SourceSansBold
		nameL.TextXAlignment = Enum.TextXAlignment.Left
		nameL.Parent = card

		local countL = Instance.new("TextLabel")
		countL.Size = UDim2.new(0, 30, 0, 20)
		countL.Position = UDim2.new(0, 110, 0, 2)
		countL.BackgroundTransparency = 1
		countL.Text = "x" .. tostring(count)
		countL.TextColor3 = COLORS.Gray
		countL.TextSize = 12
		countL.TextXAlignment = Enum.TextXAlignment.Left
		countL.Parent = card

		local useBtn = Instance.new("TextButton")
		useBtn.Size = UDim2.new(0, 50, 0, 24)
		useBtn.Position = UDim2.new(0, 150, 0, 13)
		useBtn.Text = "使用"
		useBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 180)
		useBtn.TextColor3 = COLORS.White
		useBtn.TextSize = 12
		useBtn.Font = Enum.Font.SourceSansBold
		useBtn.BorderSizePixel = 0
		useBtn.Parent = card
		useBtn.MouseButton1Click:Connect(function()
			if ShopEvent then
				ShopEvent:FireServer("UseItem:Shop", nil, { ItemKey = itemKey, IsMeditating = false })
			end
		end)
		local uCorner = Instance.new("UICorner")
		uCorner.CornerRadius = UDim.new(0, 4)
		uCorner.Parent = useBtn
		y = y + 55
	end
	scroll.CanvasSize = UDim2.new(0, 0, 0, y + 10)
end

-- ============================================================
-- 刷新 UI
-- ============================================================
function ShopUI:RefreshUI(data)
	currentShopData = data
	if not screenGui then return end
	if uiRefs.xianJingLabel then
		uiRefs.xianJingLabel.Text = "仙晶: " .. tostring((data or {}).XianJing or 0)
	end
	if currentTab == "shop" then
		ShopUI:RenderItems()
	else
		ShopUI:RenderBackpack()
	end
end

-- ============================================================
-- 打开
-- ============================================================
function ShopUI:Open(data)
	ShopUI:Create()
	screenGui.Enabled = true
	bargainState = {}
	ShopUI:RefreshUI(data)
end

-- ============================================================
-- 砍价弹窗
-- ============================================================
function ShopUI:CreateBargainPopup(parent)
	local popup = Instance.new("Frame")
	popup.Name = "BargainPopup"
	popup.Size = UDim2.new(0, 300, 0, 240)
	popup.Position = UDim2.new(0.5, -150, 0.5, -120)
	popup.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
	popup.BackgroundTransparency = 0.15
	popup.BorderSizePixel = 0
	popup.Visible = false
	popup.Parent = parent
	local popupCorner = Instance.new("UICorner")
	popupCorner.CornerRadius = UDim.new(0, 8)
	popupCorner.Parent = popup

	local avatar = Instance.new("TextLabel")
	avatar.Size = UDim2.new(0, 40, 0, 40)
	avatar.Position = UDim2.new(0.5, -20, 0, 8)
	avatar.BackgroundTransparency = 1
	avatar.Text = "👴"
	avatar.TextSize = 28
	avatar.Parent = popup

	local questionL = Instance.new("TextLabel")
	questionL.Name = "Question"
	questionL.Size = UDim2.new(1, -20, 0, 50)
	questionL.Position = UDim2.new(0, 10, 0, 50)
	questionL.BackgroundTransparency = 1
	questionL.TextColor3 = COLORS.White
	questionL.TextSize = 14
	questionL.TextWrapped = true
	questionL.Parent = popup

	local optionsFrame = Instance.new("Frame")
	optionsFrame.Size = UDim2.new(1, -20, 0, 100)
	optionsFrame.Position = UDim2.new(0, 10, 0, 110)
	optionsFrame.BackgroundTransparency = 1
	optionsFrame.Parent = popup

	uiRefs.bargainPopup = popup
	uiRefs.bargainQuestion = questionL
	uiRefs.bargainOptions = optionsFrame
end

function ShopUI:ShowBargainDialog(data)
	if not data or not data.Question then return end
	local popup = uiRefs.bargainPopup
	local questionL = uiRefs.bargainQuestion
	local optionsFrame = uiRefs.bargainOptions
	if not popup then return end

	for _, child in ipairs(optionsFrame:GetChildren()) do
		child:Destroy()
	end
	questionL.Text = "👴 " .. data.Question
	local y = 0
	for _, optText in ipairs(data.Options or {}) do
		local optBtn = Instance.new("TextButton")
		optBtn.Size = UDim2.new(1, 0, 0, 28)
		optBtn.Position = UDim2.new(0, 0, 0, y)
		optBtn.Text = tostring(y / 32 + 1) .. ". " .. optText
		optBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
		optBtn.TextColor3 = COLORS.White
		optBtn.TextSize = 13
		optBtn.TextXAlignment = Enum.TextXAlignment.Left
		optBtn.BorderSizePixel = 0
		optBtn.Parent = optionsFrame
		local optCorner = Instance.new("UICorner")
		optCorner.CornerRadius = UDim.new(0, 4)
		optCorner.Parent = optBtn

		local idx = y / 32 + 1
		optBtn.MouseButton1Click:Connect(function()
			for _, btn in ipairs(optionsFrame:GetChildren()) do
				if btn:IsA("TextButton") then btn.Active = false end
			end
			popup.Visible = false
			popup.BackgroundTransparency = 1
			if ShopEvent then
				ShopEvent:FireServer("Bargain:Shop", nil, {
					ItemKey = data.ItemKey,
					ChoiceIndex = idx,
					QuestionId = data.QuestionId,
				})
			end
		end)
		y = y + 32
	end
	popup.Visible = true
	popup.BackgroundTransparency = 0.15
end

-- ============================================================
-- 结果显示
-- ============================================================
function ShopUI:ShowResult(success, data)
	local resultPopup = screenGui and uiRefs.resultPopup
	local resultTitle = screenGui and uiRefs.resultTitle
	local resultMsg = screenGui and uiRefs.resultMsg
	if not resultPopup then return end

	resultPopup.Visible = true
	resultPopup.BackgroundTransparency = 0

	if success then
		resultTitle.Text = "✅ 购买成功"
		resultTitle.TextColor3 = COLORS.Green
		resultMsg.Text = data.Message or ""
		resultMsg.TextColor3 = COLORS.Gold
	else
		resultTitle.Text = "❌ 购买失败"
		resultTitle.TextColor3 = COLORS.Red
		resultMsg.Text = data.Message or ""
		resultMsg.TextColor3 = COLORS.Gray
	end

	task.delay(3, function()
		if resultPopup then
			resultPopup.Visible = false
			resultPopup.BackgroundTransparency = 1
		end
	end)
end

-- ============================================================
-- 购买后服用提示
-- ============================================================
function ShopUI:ShowUseNowPopup(data)
	if not screenGui then return end
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 320, 0, 140)
	frame.Position = UDim2.new(0.5, -160, 0.5, -70)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = screenGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.new(0, 0, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "获得 " .. (data.ItemName or "丹药")
	title.TextColor3 = Color3.fromRGB(200, 230, 255)
	title.TextSize = 18
	title.Font = Enum.Font.SourceSansBold
	title.Parent = frame

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -20, 0, 30)
	desc.Position = UDim2.new(0, 10, 0, 48)
	desc.BackgroundTransparency = 1
	desc.Text = "是否现在服用？"
	desc.TextColor3 = Color3.fromRGB(180, 200, 220)
	desc.TextSize = 16
	desc.TextWrapped = true
	desc.Parent = frame

	local useBtn = Instance.new("TextButton")
	useBtn.Size = UDim2.new(0, 100, 0, 32)
	useBtn.Position = UDim2.new(0, 30, 0, 90)
	useBtn.Text = "服用"
	useBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 60)
	useBtn.TextColor3 = COLORS.White
	useBtn.TextSize = 16
	useBtn.Font = Enum.Font.SourceSansBold
	useBtn.Parent = frame
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = useBtn
	useBtn.MouseButton1Click:Connect(function()
		frame:Destroy()
		if ShopEvent then
			ShopEvent:FireServer("UseItem:Shop", nil, { ItemKey = data.ItemKey, IsMeditating = false })
		end
	end)

	local storeBtn = Instance.new("TextButton")
	storeBtn.Size = UDim2.new(0, 100, 0, 32)
	storeBtn.Position = UDim2.new(0, 190, 0, 90)
	storeBtn.Text = "放入背包"
	storeBtn.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
	storeBtn.TextColor3 = COLORS.White
	storeBtn.TextSize = 14
	storeBtn.Font = Enum.Font.SourceSans
	storeBtn.Parent = frame
	local btnCorner2 = Instance.new("UICorner")
	btnCorner2.CornerRadius = UDim.new(0, 6)
	btnCorner2.Parent = storeBtn
	storeBtn.MouseButton1Click:Connect(function()
		frame:Destroy()
	end)
end

-- ============================================================
-- 关闭
-- ============================================================
function ShopUI:Close()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
	itemButtons = {}
	bargainState = {}
	uiRefs = {}
end

-- ============================================================
-- 监听远程事件
-- ============================================================
if ShopEvent then
	ShopEvent.OnClientEvent:Connect(function(eventType, data)
		if eventType == "OpenShop" then
			ShopUI:Open(data)

		elseif eventType == "PurchaseResult:Shop" then
			ShopUI:RefreshUI({
				Items = (currentShopData or {}).Items or {},
				DailyPurchases = data.DailyPurchases or {},
				XianJing = data.XianJing or 0,
				Backpack = data.Backpack or {},
			})
			ShopUI:ShowResult(data.Success, data)
			if data.CanUseNow and data.Success then
				ShopUI:ShowUseNowPopup(data)
			end

		elseif eventType == "BargainQuestion" then
			ShopUI:ShowBargainDialog(data)

		elseif eventType == "BargainResult" then
			local popup = screenGui and uiRefs.bargainPopup
			if popup then
				popup.Visible = false
				popup.BackgroundTransparency = 1
			end

			if data.Success then
				local itemKey = data.ItemKey
				if itemKey then
					bargainState[itemKey] = { discounted = true }
				end
				ShopUI:RefreshUI(currentShopData)
				ShopUI:ShowResult(true, { Message = data.Message or "老板很开心！给你打 8 折！" })
			else
				ShopUI:ShowResult(false, { Message = data.Message or "老板不高兴，还是原价吧" })
			end

		elseif eventType == "ShopClosed" then
			ShopUI:ShowResult(false, { Message = data.Message or "仙丹阁已打烊" })
		end
	end)
end

-- ============================================================
-- 绑定触摸事件
-- ============================================================
local function bindShopTouch()
	local debounce = false
	local debounceTime = 0.5

	local function firePickShop()
		if debounce then return end
		debounce = true
		if ShopEvent then
			ShopEvent:FireServer("Pick:Shop")
		end
		task.wait(debounceTime)
		debounce = false
	end

	local function bindPart(part)
		if part.Name == "DanShop" then
			if part:FindFirstChild("_ShopBound") then return end
			local boundMarker = Instance.new("BoolValue")
			boundMarker.Name = "_ShopBound"
			boundMarker.Parent = part
			part.Touched:Connect(function(hit)
				if hit and hit.Parent then
					local char = hit.Parent
					if char:FindFirstChild("Humanoid") then
						firePickShop()
					end
				end
			end)
			local pos = part.Position
			print("🔗 商店触摸绑定: " .. part:GetFullName() .. " @ " .. tostring(pos))
		end
		-- 如果 Shopkeeper 包含部件，也绑定
		if part.Name == "Torso" or part.Name == "Head" then
			local model = part.Parent
			if model and model.Name == "Shopkeeper" then
				if part:FindFirstChild("_ShopBound") then return end
				local boundMarker = Instance.new("BoolValue")
				boundMarker.Name = "_ShopBound"
				boundMarker.Parent = part
				part.Touched:Connect(function(hit)
					if hit and hit.Parent then
						local char = hit.Parent
						if char:FindFirstChild("Humanoid") then
							firePickShop()
						end
					end
				end)
			end
		end
	end

	-- 立即扫描已存在的部件
	for _, v in ipairs(Workspace:GetDescendants()) do
		if v:IsA("BasePart") then
			bindPart(v)
		end
	end
	-- 监听新加入的部件
	Workspace.DescendantAdded:Connect(function(v)
		if v:IsA("BasePart") then
			task.wait(0.5)
			bindPart(v)
		end
	end)
end

-- 轮询检测（替换触摸）
local function pollShopDistance()
	while true do
		task.wait(0.3)
		if screenGui and screenGui.Enabled then continue end
		local char = player.Character
		if not char then continue end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end
		local danShop = Workspace:FindFirstChild("DanShop")
		if not danShop then continue end
		local dist = (hrp.Position - danShop.Position).Magnitude
		if dist < 4 then
			if ShopEvent and player:GetAttribute("ShopOpen") == 1 then
				ShopEvent:FireServer("Pick:Shop")
			end
		end
	end
end

task.spawn(bindShopTouch)
task.spawn(pollShopDistance)

print("✅ ShopUI 已加载")
return ShopUI
