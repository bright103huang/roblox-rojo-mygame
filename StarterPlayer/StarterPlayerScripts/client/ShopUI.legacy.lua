-- ============================================================
-- 文件：StarterPlayer.StarterPlayerScripts.Client.ShopUI.client.lua
-- 功能：仙丹阁商店 UI — 触摸 DanShop Part 打开，独立显示
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
local itemButtons = {}  -- [itemKey] = { frame, buyBtn, countLabel }

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

	-- 点击遮罩关闭
	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			self:Close()
		end
	end)

	-- 主面板
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 400, 0, 450)
	panel.Position = UDim2.new(0.5, -200, 0.5, -225)
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

	-- 商品网格（3 列 x 2 行）
	local gridStartX = 16
	local gridStartY = 92
	local slotWidth = 116
	local slotHeight = 150
	local gapX = 12
	local gapY = 12
	local cols = 3

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
		nameLabel.TextColor3 = COLORS.White
		nameLabel.TextSize = 16
		nameLabel.Font = Enum.Font.SourceSansBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.Parent = slot

		-- 效果描述
		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -4, 0, 20)
		descLabel.Position = UDim2.new(0, 2, 0, 26)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = item.Description
		descLabel.TextColor3 = COLORS.Gray
		descLabel.TextSize = 12
		descLabel.Font = Enum.Font.SourceSans
		descLabel.TextXAlignment = Enum.TextXAlignment.Center
		descLabel.Parent = slot

		-- 价格
		local priceLabel = Instance.new("TextLabel")
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
		buyBtn.Size = UDim2.new(0.85, 0, 0, 34)
		buyBtn.Position = UDim2.new(0.075, 0, 0, 108)
		buyBtn.Text = "购买"
		buyBtn.TextColor3 = COLORS.White
		buyBtn.TextSize = 15
		buyBtn.Font = Enum.Font.SourceSansBold
		buyBtn.BorderSizePixel = 0
		buyBtn.Parent = slot

		-- 检查是否可购买（仙晶足够、未达限购）
		local isSoldOut = false
		if item.DailyLimit and item.DailyLimit > 0 then
			local bought = purchases[itemKey] or 0
			if bought >= item.DailyLimit then
				isSoldOut = true
			end
		end
		local hasMoney = (currentShopData.XianJing or 0) >= item.Price

		if isSoldOut then
			buyBtn.Text = "已售罄"
			buyBtn.BackgroundColor3 = COLORS.DarkGray
			buyBtn.Active = false
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

		-- 保存引用
		itemButtons[itemKey] = {
			frame = slot,
			buyBtn = buyBtn,
			countLabel = countLabel,
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

	-- 存储引用以刷新 UI
	screenGui:SetAttribute("_balanceLabel", balanceLabel)
	screenGui:SetAttribute("_itemButtons", itemButtons)

	-- 结果弹窗
	self:CreateResultPopup(panel)
end

-- 刷新 UI 数据（购买后更新余额和限购状态）
function ShopUI:RefreshUI(data)
	if not screenGui then return end

	currentShopData = data

	-- 更新余额
	local balanceLabel = screenGui:GetAttribute("_balanceLabel")
	if balanceLabel then
		balanceLabel.Text = "仙晶：" .. tostring(data.XianJing or 0)
	end

	-- 更新商品按钮状态
	local purchases = data.DailyPurchases or {}
	for itemKey, refs in pairs(itemButtons) do
		local item = (data.Items or {})[itemKey]
		if not item then continue end

		-- 限购显示
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

		-- 按钮状态
		local isSoldOut = false
		if item.DailyLimit and item.DailyLimit > 0 then
			local bought = purchases[itemKey] or 0
			if bought >= item.DailyLimit then
				isSoldOut = true
			end
		end
		local hasMoney = (data.XianJing or 0) >= item.Price

		if isSoldOut then
			refs.buyBtn.Text = "已售罄"
			refs.buyBtn.BackgroundColor3 = COLORS.DarkGray
			refs.buyBtn.Active = false
		elseif not hasMoney then
			refs.buyBtn.Text = "购买"
			refs.buyBtn.BackgroundColor3 = COLORS.DarkRed
			refs.buyBtn.Active = true
		else
			refs.buyBtn.Text = "购买"
			refs.buyBtn.BackgroundColor3 = COLORS.DarkGreen
			refs.buyBtn.Active = true
		end
	end
end

-- 创建结果弹窗
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

	screenGui:SetAttribute("_resultPopup", resultFrame)
	screenGui:SetAttribute("_resultTitle", resultTitle)
	screenGui:SetAttribute("_resultMsg", resultMessage)
end

-- 显示购买结果
function ShopUI:ShowResult(success, data)
	local resultPopup = screenGui and screenGui:GetAttribute("_resultPopup")
	local resultTitle = screenGui and screenGui:GetAttribute("_resultTitle")
	local resultMsg = screenGui and screenGui:GetAttribute("_resultMsg")
	if not resultPopup then return end

	resultPopup.Visible = true
	resultPopup.BackgroundTransparency = 0

	if success then
		resultTitle.Text = "购买成功"
		resultTitle.TextColor3 = COLORS.Green
		resultMsg.Text = data.Message or ""
		resultMsg.TextColor3 = COLORS.Gold
	else
		resultTitle.Text = "购买失败"
		resultTitle.TextColor3 = COLORS.Red
		resultMsg.Text = data.Message or ""
		resultMsg.TextColor3 = COLORS.Gray
	end

	-- 3 秒后自动关闭结果弹窗
	task.delay(3, function()
		if resultPopup then
			resultPopup.Visible = false
			resultPopup.BackgroundTransparency = 1
		end
	end)
end

function ShopUI:Close()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
	currentShopData = nil
	itemButtons = {}
end

-- ============================================================
-- 监听远程事件
-- ============================================================

-- 监听打开商店
if ShopEvent then
	ShopEvent.OnClientEvent:Connect(function(eventType, data)
		if eventType == "OpenShop" then
			ShopUI:Open(data)

		elseif eventType == "PurchaseResult:Shop" then
			-- 先刷新 UI
			ShopUI:RefreshUI({
				Items = (currentShopData or {}).Items or {},
				DailyPurchases = data.DailyPurchases or {},
				XianJing = data.XianJing or 0,
			})
			-- 再显示结果
			ShopUI:ShowResult(data.Success, data)
		end
	end)
end

-- ============================================================
-- 绑定 DanShop Part 触摸事件
-- 当玩家触摸到名为 "DanShop" 的 Part 时，发送 Pick:Shop
-- ============================================================
local function bindDanShopTouch()
	local debounce = false
	local debounceTime = 0.5

	local function bindPart(part)
		if part.Name ~= "DanShop" then return end
		if part:FindFirstChild("_ShopBound") then return end

		local boundMarker = Instance.new("BoolValue")
		boundMarker.Name = "_ShopBound"
		boundMarker.Parent = part

		part.Touched:Connect(function(hit)
			if not player.Character then return end
			if hit.Parent ~= player.Character then return end
			if debounce then return end
			debounce = true

			print("🏪 进入仙丹阁")
			if ShopEvent then
				ShopEvent:FireServer("Pick:Shop")
			end

			task.wait(debounceTime)
			debounce = false
		end)
	end

	-- 扫描现有 Part
	for _, v in pairs(Workspace:GetDescendants()) do
		if v:IsA("Part") then
			bindPart(v)
		end
	end

	-- 监听新加入的 Part
	Workspace.DescendantAdded:Connect(function(v)
		if v:IsA("Part") then
			bindPart(v)
		end
	end)
end

-- ============================================================
-- 启动
-- ============================================================
task.wait(2)  -- 等待场景加载
bindDanShopTouch()

print("🏪 ShopUI 已启动")

return ShopUI
