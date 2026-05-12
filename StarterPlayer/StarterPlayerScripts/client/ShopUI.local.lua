-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.ShopUI.client.lua
-- 功能：仙丹阁商店 UI + 砍价对话
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
	ShopEvent = eventsFolder:FindFirstChild("ShopEvent")
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
local isShopOpen = false
local currentTab = "shop" -- "shop" or "backpack"

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
	DarkRed = Color3.fromRGB(140, 40, 40),
	DarkGreen = Color3.fromRGB(40, 100, 40),
}

-- ============================================================
-- 创建 UI
-- ============================================================
function ShopUI:Open(data)
	currentShopData = data or {}
	itemButtons = {}
	bargainState = {}
	self:CreateUI()
end

function ShopUI:CreateUI()
	self:Close()

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShopUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- 遮罩
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.6
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui

	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			self:Close()
		end
	end)

	-- 主面板（右下角）
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 350, 0, 460)
	panel.Position = UDim2.new(1, -365, 1, -475)
	panel.BackgroundColor3 = COLORS.Panel
	panel.BorderSizePixel = 0
	panel.Parent = screenGui
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = panel

	-- 标题栏
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 32)
	titleBar.BackgroundColor3 = COLORS.Bg
	titleBar.BorderSizePixel = 0
	titleBar.Parent = panel
	local titleBarCorner = Instance.new("UICorner")
	titleBarCorner.CornerRadius = UDim.new(0, 12)
	titleBarCorner.Parent = titleBar

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, 80, 1, 0)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "仙丹阁"
	title.TextColor3 = COLORS.Gold
	title.TextSize = 18
	title.Font = Enum.Font.SourceSansBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = titleBar

	-- 标签切换
	local shopTab = Instance.new("TextButton")
	shopTab.Name = "ShopTab"
	shopTab.Size = UDim2.new(0, 50, 0, 24)
	shopTab.Position = UDim2.new(0, 100, 0, 4)
	shopTab.Text = "商店"
	shopTab.TextColor3 = COLORS.Gold
	shopTab.TextSize = 14
	shopTab.Font = Enum.Font.SourceSansBold
	shopTab.BackgroundColor3 = COLORS.DarkGray
	shopTab.BorderSizePixel = 0
	shopTab.Parent = titleBar
	local shopTabCorner = Instance.new("UICorner")
	shopTabCorner.CornerRadius = UDim.new(0, 4)
	shopTabCorner.Parent = shopTab

	local bpTab = Instance.new("TextButton")
	bpTab.Name = "BackpackTab"
	bpTab.Size = UDim2.new(0, 50, 0, 24)
	bpTab.Position = UDim2.new(0, 155, 0, 4)
	bpTab.Text = "背包"
	bpTab.TextColor3 = COLORS.White
	bpTab.TextSize = 14
	bpTab.Font = Enum.Font.SourceSansBold
	bpTab.BackgroundColor3 = COLORS.Panel
	bpTab.BorderSizePixel = 0
	bpTab.Parent = titleBar
	local bpTabCorner = Instance.new("UICorner")
	bpTabCorner.CornerRadius = UDim.new(0, 4)
	bpTabCorner.Parent = bpTab

	-- 关闭按钮
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 28, 0, 28)
	closeBtn.Position = UDim2.new(1, -32, 0, 2)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = COLORS.Gray
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.SourceSansBold
	closeBtn.BackgroundTransparency = 1
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = titleBar
	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)
	-- 仙晶余额
	local balanceFrame = Instance.new("Frame")
	balanceFrame.Name = "BalanceFrame"
	balanceFrame.Size = UDim2.new(0.9, 0, 0, 28)
	balanceFrame.Position = UDim2.new(0.05, 0, 0, 36)
	balanceFrame.BackgroundColor3 = COLORS.Bg
	balanceFrame.BorderSizePixel = 0
	balanceFrame.Parent = panel
	local balanceCorner = Instance.new("UICorner")
	balanceCorner.CornerRadius = UDim.new(0, 6)
	balanceCorner.Parent = balanceFrame

	local balanceLabel = Instance.new("TextLabel")
	balanceLabel.Name = "BalanceLabel"
	balanceLabel.Size = UDim2.new(1, -10, 1, 0)
	balanceLabel.Position = UDim2.new(0, 5, 0, 0)
	balanceLabel.BackgroundTransparency = 1
	balanceLabel.Text = "仙晶：" .. tostring(currentShopData.XianJing or 0)
	balanceLabel.TextColor3 = COLORS.Gold
	balanceLabel.TextSize = 16
	balanceLabel.Font = Enum.Font.SourceSansBold
	balanceLabel.TextXAlignment = Enum.TextXAlignment.Center
	balanceLabel.Parent = balanceFrame

	-- 商品/背包容器（可滚动）
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ItemScroll"
	scrollFrame.Size = UDim2.new(1, -10, 1, -80)
	scrollFrame.Position = UDim2.new(0, 5, 0, 70)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.Parent = panel

	uiRefs.scrollFrame = scrollFrame
	uiRefs.balanceLabel = balanceLabel

	-- 标签切换
	local function switchTab(tab)
		currentTab = tab
		if tab == "shop" then
			shopTab.BackgroundColor3 = COLORS.DarkGray
			shopTab.TextColor3 = COLORS.Gold
			bpTab.BackgroundColor3 = COLORS.Panel
			bpTab.TextColor3 = COLORS.White
			ShopUI:RenderItems()
		else
			bpTab.BackgroundColor3 = COLORS.DarkGray
			bpTab.TextColor3 = COLORS.Gold
			shopTab.BackgroundColor3 = COLORS.Panel
			shopTab.TextColor3 = COLORS.White
			ShopUI:RenderBackpack()
		end
	end

	shopTab.MouseButton1Click:Connect(function() switchTab("shop") end)
	bpTab.MouseButton1Click:Connect(function() switchTab("backpack") end)

	-- 初始渲染商品列表
	ShopUI:RenderItems()
	self:CreateResultPopup(panel)
	self:CreateBargainPopup(panel)
end

-- ============================================================
-- 砍价对话弹窗
-- ============================================================
function ShopUI:CreateBargainPopup(parent)
	local frame = Instance.new("Frame")
	frame.Name = "BargainPopup"
	frame.Size = UDim2.new(0.9, 0, 0, 200)
	frame.Position = UDim2.new(0.05, 0, 0, 80)
	frame.BackgroundColor3 = COLORS.Bg
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local questionLabel = Instance.new("TextLabel")
	questionLabel.Name = "BargainQuestion"
	questionLabel.Size = UDim2.new(0.9, 0, 0, 50)
	questionLabel.Position = UDim2.new(0.05, 0, 0, 10)
	questionLabel.BackgroundTransparency = 1
	questionLabel.TextColor3 = COLORS.Gold
	questionLabel.TextSize = 16
	questionLabel.Font = Enum.Font.SourceSansBold
	questionLabel.TextWrapped = true
	questionLabel.TextXAlignment = Enum.TextXAlignment.Center
	questionLabel.Parent = frame

	local optionButtons = {}
	for i = 1, 3 do
		local btn = Instance.new("TextButton")
		btn.Name = "Option" .. i
		btn.Size = UDim2.new(0.85, 0, 0, 34)
		btn.Position = UDim2.new(0.075, 0, 0, 70 + (i - 1) * 40)
		btn.TextColor3 = COLORS.White
		btn.TextSize = 12
		btn.Font = Enum.Font.SourceSans
		btn.TextWrapped = true
		btn.BackgroundColor3 = COLORS.Panel
		btn.BorderSizePixel = 0
		btn.Parent = frame
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = btn
		optionButtons[i] = btn
	end

	uiRefs.bargainPopup = frame
	uiRefs.bargainQuestion = questionLabel
	uiRefs.bargainOptions = optionButtons
end

function ShopUI:ShowBargainDialog(data)
	local popup = screenGui and uiRefs.bargainPopup
	local questionLabel = screenGui and uiRefs.bargainQuestion
	local optionButtons = screenGui and uiRefs.bargainOptions
	if not popup or not questionLabel or not optionButtons then return end

	-- 隐藏结果弹窗
	local resultPopup = screenGui and uiRefs.resultPopup
	if resultPopup then
		resultPopup.Visible = false
		resultPopup.BackgroundTransparency = 1
	end

	popup.Visible = true
	popup.BackgroundTransparency = 0
	questionLabel.Text = "👴 " .. (data.Question or "")

	local pendingItemKey = data.ItemKey
	for i, btn in ipairs(optionButtons) do
		local optionText = (data.Options or {})[i]
		if optionText then
			btn.Text = tostring(i) .. ". " .. optionText
			btn.Visible = true
			btn.Active = true
			btn.BackgroundColor3 = COLORS.Panel
			btn.MouseButton1Click:Connect(function()
				-- Disable all buttons
				for _, b in ipairs(optionButtons) do
					b.Active = false
				end
				if ShopEvent and pendingItemKey then
					ShopEvent:FireServer("Bargain:Shop", nil, {
						ItemKey = pendingItemKey,
						ChoiceIndex = data.QuestionId,
					})
				end
			end)
		else
			btn.Visible = false
		end
	end
end

-- ============================================================
-- 刷新 UI
-- ============================================================
function ShopUI:RefreshUI(data)
	if not screenGui then return end
	currentShopData = data

	local balanceLabel = uiRefs.balanceLabel
	if balanceLabel then
		balanceLabel.Text = "仙晶：" .. tostring(data.XianJing or 0)
	end

	-- 重新渲染当前标签页
	if currentTab == "shop" then
		ShopUI:RenderItems()
	else
		ShopUI:RenderBackpack()
	end
end

-- ============================================================

-- ============================================================
-- 渲染商品列表（紧凑布局）
-- ============================================================
function ShopUI:RenderItems()
	local scroll = uiRefs.scrollFrame
	if not scroll then return end
	for _, v in pairs(scroll:GetChildren()) do
		if v:IsA("Frame") then v:Destroy() end
	end

	local items = (currentShopData or {}).Items or {}
	local purchases = (currentShopData or {}).DailyPurchases or {}
	local y = 5
	for itemKey, item in pairs(items) do
		local card = Instance.new("Frame")
		card.Name = "ItemCard_" .. itemKey
		card.Size = UDim2.new(1, -10, 0, 62)
		card.Position = UDim2.new(0, 5, 0, y)
		card.BackgroundColor3 = COLORS.Bg
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

		-- 限购显示
		if item.DailyLimit and item.DailyLimit > 0 then
			local bought = purchases[itemKey] or 0
			local remaining = item.DailyLimit - bought
			priceL.Text = priceL.Text .. " | 剩" .. tostring(remaining)
		end

		-- 购买按钮
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
		local buyCorner = Instance.new("UICorner")
		buyCorner.CornerRadius = UDim.new(0, 4)
		buyCorner.Parent = buyBtn

		-- 砍价按钮
		local bargainBtn = Instance.new("TextButton")
		bargainBtn.Name = "BargainBtn_" .. itemKey
		bargainBtn.Size = UDim2.new(0, 58, 0, 22)
		bargainBtn.Position = UDim2.new(0, 125, 0, 29)
		bargainBtn.Text = "砍价"
		bargainBtn.TextColor3 = COLORS.White
		bargainBtn.TextSize = 11
		bargainBtn.Font = Enum.Font.SourceSansBold
		bargainBtn.BackgroundColor3 = COLORS.Gold
		bargainBtn.BorderSizePixel = 0
		bargainBtn.Parent = card
		local bargainCorner = Instance.new("UICorner")
		bargainCorner.CornerRadius = UDim.new(0, 4)
		bargainCorner.Parent = bargainBtn

		-- 按钮状态
		local isSoldOut = false
		if item.DailyLimit and item.DailyLimit > 0 then
			local bought = purchases[itemKey] or 0
			if bought >= item.DailyLimit then isSoldOut = true end
		end
		local hasMoney = (currentShopData.XianJing or 0) >= item.Price

		if item.IsHidden then
			buyBtn.Text = "???"; buyBtn.BackgroundColor3 = COLORS.DarkGray; buyBtn.Active = false
			bargainBtn.Text = "???"; bargainBtn.BackgroundColor3 = COLORS.DarkGray; bargainBtn.Active = false
		elseif isSoldOut then
			buyBtn.Text = "已售罄"; buyBtn.BackgroundColor3 = COLORS.DarkGray; buyBtn.Active = false
			bargainBtn.Visible = false
		else
			buyBtn.BackgroundColor3 = hasMoney and COLORS.DarkGreen or COLORS.DarkRed
			buyBtn.Active = true
		end

		-- 砍价后显示折后价
		local bargained = bargainState[itemKey]
		if bargained and bargained.discounted then
			bargainBtn.Text = "已砍"; bargainBtn.BackgroundColor3 = COLORS.DarkGray; bargainBtn.Active = false
			local discountedPrice = math.floor(item.Price * 0.8)
			priceL.Text = "仙晶 x" .. tostring(item.Price) .. " (" .. tostring(discountedPrice) .. ")"
			priceL.TextColor3 = COLORS.Green
		end

		-- 购买点击
		buyBtn.MouseButton1Click:Connect(function()
			if not buyBtn.Active then return end
			buyBtn.Text = "购买中..."; buyBtn.Active = false
			if ShopEvent then
				ShopEvent:FireServer("Purchase:Shop", nil, { ItemKey = itemKey })
			end
		end)

		-- 砍价点击
		bargainBtn.MouseButton1Click:Connect(function()
			if not bargainBtn.Active then return end
			bargainBtn.Active = false; bargainBtn.Text = "砍价中..."
			if ShopEvent then
				ShopEvent:FireServer("Bargain:Shop", nil, { ItemKey = itemKey })
			end
		end)

		y = y + 66
	end
	scroll.CanvasSize = UDim2.new(0, 0, 0, y + 10)
end

-- ============================================================
-- 渲染背包
-- ============================================================
function ShopUI:RenderBackpack()
	local scroll = uiRefs.scrollFrame
	if not scroll then return end
	for _, v in pairs(scroll:GetChildren()) do
		if v:IsA("Frame") then v:Destroy() end
	end

	local backpack = (currentShopData or {}).Backpack or {}
	local items = (currentShopData or {}).Items or {}
	local y = 5
	for itemKey, count in pairs(backpack) do
		local item = items[itemKey]
		if not item then continue end
		if item.IsHidden then continue end

		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -10, 0, 50)
		card.Position = UDim2.new(0, 5, 0, y)
		card.BackgroundColor3 = COLORS.Bg
		card.BorderSizePixel = 0
		card.Parent = scroll
		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 6)
		cardCorner.Parent = card

		local nameL = Instance.new("TextLabel")
		nameL.Size = UDim2.new(0, 120, 0, 20)
		nameL.Position = UDim2.new(0, 6, 0, 2)
		nameL.BackgroundTransparency = 1
		nameL.Text = item.Name .. " x" .. tostring(count)
		nameL.TextColor3 = COLORS.White
		nameL.TextSize = 14
		nameL.Font = Enum.Font.SourceSansBold
		nameL.TextXAlignment = Enum.TextXAlignment.Left
		nameL.Parent = card

		local descL = Instance.new("TextLabel")
		descL.Size = UDim2.new(0, 150, 0, 16)
		descL.Position = UDim2.new(0, 6, 0, 22)
		descL.BackgroundTransparency = 1
		descL.Text = item.Description
		descL.TextColor3 = COLORS.Gray
		descL.TextSize = 11
		descL.Font = Enum.Font.SourceSans
		descL.TextXAlignment = Enum.TextXAlignment.Left
		descL.Parent = card

		-- 使用按钮
		local useBtn = Instance.new("TextButton")
		useBtn.Size = UDim2.new(0, 58, 0, 28)
		useBtn.Position = UDim2.new(0, 130, 0, 10)
		useBtn.Text = "使用"
		useBtn.TextColor3 = COLORS.White
		useBtn.TextSize = 12
		useBtn.Font = Enum.Font.SourceSansBold
		useBtn.BackgroundColor3 = COLORS.DarkGreen
		useBtn.BorderSizePixel = 0
		useBtn.Parent = card
		local useCorner = Instance.new("UICorner")
		useCorner.CornerRadius = UDim.new(0, 4)
		useCorner.Parent = useBtn

		useBtn.MouseButton1Click:Connect(function()
			useBtn.Text = "使用中..."; useBtn.Active = false
			if ShopEvent then
				ShopEvent:FireServer("UseItem:Shop", nil, { ItemKey = itemKey })
			end
		end)

		y = y + 54
	end
	if y == 5 then
		local emptyL = Instance.new("TextLabel")
		emptyL.Size = UDim2.new(1, 0, 0, 40)
		emptyL.Position = UDim2.new(0, 0, 0, 20)
		emptyL.BackgroundTransparency = 1
		emptyL.Text = "背包空空如也"
		emptyL.TextColor3 = COLORS.Gray
		emptyL.TextSize = 16
		emptyL.Font = Enum.Font.SourceSans
		emptyL.TextXAlignment = Enum.TextXAlignment.Center
		emptyL.Parent = scroll
	end
	scroll.CanvasSize = UDim2.new(0, 0, 0, math.max(y + 10, 60))
end

-- 结果弹窗
-- ============================================================
function ShopUI:CreateResultPopup(parent)
	local resultFrame = Instance.new("Frame")
	resultFrame.Name = "ResultPopup"
	resultFrame.Size = UDim2.new(0.8, 0, 0, 100)
	resultFrame.Position = UDim2.new(0.1, 0, 0, -130)
	resultFrame.BackgroundColor3 = COLORS.Bg
	resultFrame.BorderSizePixel = 0
	resultFrame.BackgroundTransparency = 1
	resultFrame.Visible = false
	resultFrame.Parent = parent
	local resultCorner = Instance.new("UICorner")
	resultCorner.CornerRadius = UDim.new(0, 10)
	resultCorner.Parent = resultFrame

	local resultTitle = Instance.new("TextLabel")
	resultTitle.Name = "ResultTitle"
	resultTitle.Size = UDim2.new(1, 0, 0, 30)
	resultTitle.Position = UDim2.new(0, 0, 0, 10)
	resultTitle.BackgroundTransparency = 1
	resultTitle.Text = ""
	resultTitle.TextSize = 18
	resultTitle.Font = Enum.Font.SourceSansBold
	resultTitle.Parent = resultFrame

	local resultMessage = Instance.new("TextLabel")
	resultMessage.Name = "ResultMsg"
	resultMessage.Size = UDim2.new(1, -20, 0, 40)
	resultMessage.Position = UDim2.new(0, 10, 0, 44)
	resultMessage.BackgroundTransparency = 1
	resultMessage.Text = ""
	resultMessage.TextSize = 14
	resultMessage.Font = Enum.Font.SourceSans
	resultMessage.Parent = resultFrame

	uiRefs.resultPopup = resultFrame
	uiRefs.resultTitle = resultTitle
	uiRefs.resultMsg = resultMessage
end

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
			})
			ShopUI:ShowResult(data.Success, data)

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
				if not player.Character then return end
				if hit.Parent ~= player.Character then return end
				firePickShop()
			end)
		end
	end

	local function bindShopkeeper()
		-- Find the Shopkeeper model in workspace
		local model = Workspace:FindFirstChild("Shopkeeper")
		if not model then return end
		for _, child in ipairs(model:GetDescendants()) do
			if child:IsA("BasePart") and child.Name ~= "ShopkeeperRoot" then
				if child:FindFirstChild("_ShopBound") then return end
				local boundMarker = Instance.new("BoolValue")
				boundMarker.Name = "_ShopBound"
				boundMarker.Parent = child
				child.Touched:Connect(function(hit)
					if not player.Character then return end
					if hit.Parent ~= player.Character then return end
					firePickShop()
				end)
			end
		end
	end

	-- 绑定 DanShop 区域
	for _, v in pairs(Workspace:GetDescendants()) do
		if v:IsA("Part") then
			bindPart(v)
		end
	end
	Workspace.DescendantAdded:Connect(function(v)
		if v:IsA("Part") then
			bindPart(v)
		end
	end)

	-- 绑定掌柜 NPC
	bindShopkeeper()
	Workspace.DescendantAdded:Connect(function(v)
		if v:IsA("Model") and v.Name == "Shopkeeper" then
			bindShopkeeper()
		end
	end)
end
-- ============================================================
-- 可靠轮询触发器（替代 Touched，防止物理引擎漏检）
-- ============================================================
task.spawn(function()
	local zone = workspace:FindFirstChild("DanShop")
	if not zone then
		-- 等场景同步
		local waited = 0
		while not zone and waited < 30 do
			task.wait(1)
			zone = workspace:FindFirstChild("DanShop")
			waited += 1
		end
		if not zone then return end
	end
	local lastTrigger = 0
	while zone and zone.Parent do
		task.wait(0.3)
		local char = player.Character
		if not char then continue end
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then continue end
		local dist = (root.Position - zone.Position).Magnitude
		if dist < 4 then
			local now = os.clock()
			if now - lastTrigger > 1 then
				lastTrigger = now
				if ShopEvent then
					ShopEvent:FireServer("Pick:Shop")
				end
			end
		end
	end
end)

-- ============================================================
-- 启动
-- ============================================================
task.wait(2)
bindShopTouch()

print("🏪 ShopUI 已启动（含砍价）")

return ShopUI
