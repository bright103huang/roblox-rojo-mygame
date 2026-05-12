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

	-- 主面板
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 400, 0, 500)
	panel.Position = UDim2.new(0.5, -200, 0.5, -250)
	panel.BackgroundColor3 = COLORS.Panel
	panel.BorderSizePixel = 0
	panel.Parent = screenGui
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = panel

	-- 标题
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.new(0, 0, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "仙丹阁"
	title.TextColor3 = COLORS.Gold
	title.TextSize = 24
	title.Font = Enum.Font.SourceSansBold
	title.Parent = panel

	-- 仙晶余额
	local balanceFrame = Instance.new("Frame")
	balanceFrame.Name = "BalanceFrame"
	balanceFrame.Size = UDim2.new(0.9, 0, 0, 32)
	balanceFrame.Position = UDim2.new(0.05, 0, 0, 46)
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
	balanceLabel.Text = "仙晶："
		.. tostring(currentShopData.XianJing or 0)
	balanceLabel.TextColor3 = COLORS.Gold
	balanceLabel.TextSize = 18
	balanceLabel.Font = Enum.Font.SourceSansBold
	balanceLabel.TextXAlignment = Enum.TextXAlignment.Center
	balanceLabel.Parent = balanceFrame

	-- 分割线
	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(0.9, 0, 0, 1)
	divider.Position = UDim2.new(0.05, 0, 0, 82)
	divider.BackgroundColor3 = COLORS.Gray
	divider.BackgroundTransparency = 0.7
	divider.BorderSizePixel = 0
	divider.Parent = panel

	-- 商品网格（2 列 x 3 行）
	local gridStartX = 24
	local gridStartY = 92
	local slotWidth = 170
	local slotHeight = 190
	local gapX = 12
	local gapY = 12
	local cols = 2

	local items = currentShopData.Items or {}
	local purchases = currentShopData.DailyPurchases or {}
	local itemKeys = {}
	for key in pairs(items) do
		table.insert(itemKeys, key)
	end
	table.sort(itemKeys)

	for i, itemKey in ipairs(itemKeys) do
		local item = items[itemKey]
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local x = gridStartX + col * (slotWidth + gapX)
		local y = gridStartY + row * (slotHeight + gapY)

		-- 商品格子
		local slot = Instance.new("Frame")
		slot.Name = "Slot_" .. itemKey
		slot.Size = UDim2.new(0, slotWidth, 0, slotHeight)
		slot.Position = UDim2.new(0, x, 0, y)
		slot.BackgroundColor3 = COLORS.Bg
		slot.BorderSizePixel = 0
		slot.Parent = panel
		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 8)
		slotCorner.Parent = slot

		-- 丹药名称
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -4, 0, 22)
		nameLabel.Position = UDim2.new(0, 2, 0, 4)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = item.Name
		nameLabel.TextColor3 = item.IsHidden and COLORS.DarkGray or COLORS.White
		nameLabel.TextSize = 16
		nameLabel.Font = Enum.Font.SourceSansBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.Parent = slot

		-- 效果描述
		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -4, 0, 20)
		descLabel.Position = UDim2.new(0, 2, 0, 26)
		descLabel.BackgroundTransparency = 1
		if item.IsHidden then
			descLabel.Text = "仙晶达到 " .. tostring(item.Price) .. " 后揭晓"
		else
			descLabel.Text = item.Description
		end
		descLabel.TextColor3 = item.IsHidden and COLORS.DarkGray or COLORS.Gray
		descLabel.TextSize = 12
		descLabel.Font = Enum.Font.SourceSans
		descLabel.TextXAlignment = Enum.TextXAlignment.Center
		descLabel.Parent = slot

		-- 价格
		local priceLabel = Instance.new("TextLabel")
		priceLabel.Name = "PriceLabel"
		priceLabel.Size = UDim2.new(1, -4, 0, 20)
		priceLabel.Position = UDim2.new(0, 2, 0, 48)
		priceLabel.BackgroundTransparency = 1
		priceLabel.Text = "仙晶 x" .. tostring(item.Price)
		priceLabel.TextColor3 = COLORS.Gold
		priceLabel.TextSize = 14
		priceLabel.Font = Enum.Font.SourceSansBold
		priceLabel.TextXAlignment = Enum.TextXAlignment.Center
		priceLabel.Parent = slot

		-- 限购次数显示
		local countLabel = Instance.new("TextLabel")
		countLabel.Name = "CountLabel"
		countLabel.Size = UDim2.new(1, -4, 0, 18)
		countLabel.Position = UDim2.new(0, 2, 0, 70)
		countLabel.BackgroundTransparency = 1
		countLabel.TextSize = 12
		countLabel.Font = Enum.Font.SourceSans
		countLabel.TextXAlignment = Enum.TextXAlignment.Center
		countLabel.Parent = slot

		if item.DailyLimit and item.DailyLimit > 0 then
			local bought = purchases[itemKey] or 0
			local remaining = item.DailyLimit - bought
			countLabel.Text = "剩余 " .. tostring(remaining) .. "/" .. tostring(item.DailyLimit)
			if remaining <= 0 then
				countLabel.TextColor3 = COLORS.Red
			else
				countLabel.TextColor3 = COLORS.Green
			end
		else
			countLabel.Text = "不限购"
			countLabel.TextColor3 = COLORS.Gray
		end

		-- 购买按钮
		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyBtn"
		buyBtn.Size = UDim2.new(0.85, 0, 0, 28)
		buyBtn.Position = UDim2.new(0.075, 0, 0, 95)
		buyBtn.Text = "购买"
		buyBtn.TextColor3 = COLORS.White
		buyBtn.TextSize = 14
		buyBtn.Font = Enum.Font.SourceSansBold
		buyBtn.BorderSizePixel = 0
		buyBtn.Parent = slot

		-- 砍价按钮
		local bargainBtn = Instance.new("TextButton")
		bargainBtn.Name = "BargainBtn"
		bargainBtn.Size = UDim2.new(0.85, 0, 0, 24)
		bargainBtn.Position = UDim2.new(0.075, 0, 0, 128)
		bargainBtn.Text = "砍价"
		bargainBtn.TextColor3 = COLORS.White
		bargainBtn.TextSize = 12
		bargainBtn.Font = Enum.Font.SourceSansBold
		bargainBtn.BackgroundColor3 = COLORS.Gold
		bargainBtn.BorderSizePixel = 0
		bargainBtn.Parent = slot
		local bargainCorner = Instance.new("UICorner")
		bargainCorner.CornerRadius = UDim.new(0, 6)
		bargainCorner.Parent = bargainBtn

		-- 检查是否可购买
		local isSoldOut = false
		if item.DailyLimit and item.DailyLimit > 0 then
			local bought = purchases[itemKey] or 0
			if bought >= item.DailyLimit then
				isSoldOut = true
			end
		end
		local hasMoney = (currentShopData.XianJing or 0) >= item.Price

		if item.IsHidden then
			buyBtn.Text = "???"
			buyBtn.BackgroundColor3 = COLORS.DarkGray
			buyBtn.Active = false
			bargainBtn.Text = "???"
			bargainBtn.BackgroundColor3 = COLORS.DarkGray
			bargainBtn.Active = false
		elseif isSoldOut then
			buyBtn.Text = "已售罄"
			buyBtn.BackgroundColor3 = COLORS.DarkGray
			buyBtn.Active = false
			bargainBtn.Visible = false
		elseif not hasMoney then
			buyBtn.BackgroundColor3 = COLORS.DarkRed
			buyBtn.Active = true
		else
			buyBtn.BackgroundColor3 = COLORS.DarkGreen
			buyBtn.Active = true
		end
		local buyCorner = Instance.new("UICorner")
		buyCorner.CornerRadius = UDim.new(0, 6)
		buyCorner.Parent = buyBtn

		-- 购买按钮点击
		buyBtn.MouseButton1Click:Connect(function()
			if not buyBtn.Active then return end
			buyBtn.Text = "购买中..."
			buyBtn.Active = false
			if ShopEvent then
				ShopEvent:FireServer("Purchase:Shop", nil, {
					ItemKey = itemKey,
				})
			end
		end)

		-- 砍价按钮点击
		bargainBtn.MouseButton1Click:Connect(function()
			if not bargainBtn.Active then return end
			bargainBtn.Active = false
			bargainBtn.Text = "砍价中..."
			if ShopEvent then
				ShopEvent:FireServer("Bargain:Shop", nil, {
					ItemKey = itemKey,
				})
			end
		end)

		-- 保存引用
		itemButtons[itemKey] = {
			frame = slot,
			buyBtn = buyBtn,
			bargainBtn = bargainBtn,
			countLabel = countLabel,
			priceLabel = priceLabel,
		}
	end

	-- 关闭按钮
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -36, 0, 6)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = COLORS.Gray
	closeBtn.TextSize = 18
	closeBtn.Font = Enum.Font.SourceSansBold
	closeBtn.BackgroundTransparency = 1
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = panel
	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- 存储引用
	uiRefs.balanceLabel = balanceLabel

	-- 结果弹窗 + 砍价弹窗
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

	local purchases = data.DailyPurchases or {}
	for itemKey, refs in pairs(itemButtons) do
		local item = (data.Items or {})[itemKey]
		if not item then continue end

		if item.DailyLimit and item.DailyLimit > 0 then
			local bought = purchases[itemKey] or 0
			local remaining = item.DailyLimit - bought
			refs.countLabel.Text = "剩余 " .. tostring(remaining) .. "/" .. tostring(item.DailyLimit)
			if remaining <= 0 then
				refs.countLabel.TextColor3 = COLORS.Red
			else
				refs.countLabel.TextColor3 = COLORS.Green
			end
		end

		local isSoldOut = false
		if item.DailyLimit and item.DailyLimit > 0 then
			local bought = purchases[itemKey] or 0
			if bought >= item.DailyLimit then
				isSoldOut = true
			end
		end
		local hasMoney = (data.XianJing or 0) >= item.Price

		-- 如果已砍价成功，显示折后价
		local bargained = bargainState[itemKey]
		if bargained and bargained.discounted then
			local discountedPrice = math.floor(item.Price * 0.8)
			refs.priceLabel.Text = "仙晶 x" .. tostring(item.Price) .. " → (" .. tostring(discountedPrice) .. ")"
			refs.priceLabel.TextColor3 = COLORS.Green
		else
			refs.priceLabel.Text = "仙晶 x" .. tostring(item.Price)
			refs.priceLabel.TextColor3 = COLORS.Gold
		end

		if item.IsHidden then
			refs.buyBtn.Text = "???"
			refs.buyBtn.BackgroundColor3 = COLORS.DarkGray
			refs.buyBtn.Active = false
			refs.bargainBtn.Visible = false
		elseif isSoldOut then
			refs.buyBtn.Text = "已售罄"
			refs.buyBtn.BackgroundColor3 = COLORS.DarkGray
			refs.buyBtn.Active = false
			refs.bargainBtn.Visible = false
		elseif not hasMoney then
			refs.buyBtn.Text = "购买"
			refs.buyBtn.BackgroundColor3 = COLORS.DarkRed
			refs.buyBtn.Active = true
			refs.bargainBtn.Visible = true
		else
			refs.buyBtn.Text = "购买"
			refs.buyBtn.BackgroundColor3 = COLORS.DarkGreen
			refs.buyBtn.Active = true
			refs.bargainBtn.Visible = true
		end

		-- 如果已经砍过价，禁用砍价按钮
		if bargainState[itemKey] then
			refs.bargainBtn.Text = "已砍"
			refs.bargainBtn.BackgroundColor3 = COLORS.DarkGray
			refs.bargainBtn.Active = false
		elseif refs.bargainBtn.Visible and not isSoldOut then
			refs.bargainBtn.Text = "砍价"
			refs.bargainBtn.BackgroundColor3 = COLORS.Gold
			refs.bargainBtn.Active = true
		end
	end
end

-- ============================================================
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

		elseif eventType == "BargainResult:Shop" then
			-- 隐藏砍价弹窗
			local popup = screenGui and uiRefs.bargainPopup
			if popup then
				popup.Visible = false
				popup.BackgroundTransparency = 1
			end

			if data.Success then
				-- 记录砍价成功
				local itemKey = data.ItemKey
				if itemKey then
					bargainState[itemKey] = { discounted = true }
				end
				ShopUI:RefreshUI(currentShopData)
				ShopUI:ShowResult(true, { Message = "老板很开心！给你打 8 折！" })
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
