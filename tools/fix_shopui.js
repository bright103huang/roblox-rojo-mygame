// ShopUI fix — content-based replacements, bottom-to-top to avoid index shift
const fs = require('fs');
const path = require('path');
const filePath = path.resolve(__dirname, '../StarterPlayer/StarterPlayerScripts/client/ShopUI.local.lua');
let content = fs.readFileSync(filePath, 'utf-8');

// ===== CHANGE A: Bargain event handlers (bottom of file) =====
// Replace "BargainResult:Shop" handler
content = content.replace(
  '\t\telseif eventType == "BargainResult:Shop" then\n\t\t\t-- 隐藏砍价弹窗\n\t\t\tlocal popup = screenGui and uiRefs.bargainPopup\n\t\t\tif popup then\n\t\t\t\tpopup.Visible = false\n\t\t\t\tpopup.BackgroundTransparency = 1\n\t\t\tend\n\n\t\t\tif data.Success then\n\t\t\t\t-- 记录砍价成功\n\t\t\t\tlocal itemKey = data.ItemKey\n\t\t\t\tif itemKey then\n\t\t\t\t\tbargainState[itemKey] = { discounted = true }\n\t\t\t\tend\n\t\t\t\tShopUI:RefreshUI(currentShopData)\n\t\t\t\tShopUI:ShowResult(true, { Message = "老板很开心！给你打 8 折！" })\n\t\t\telse\n\t\t\t\tShopUI:ShowResult(false, { Message = data.Message or "老板不高兴，还是原价吧" })\n\t\t\tend',
  '\t\telseif eventType == "BargainQuestion" then\n\t\t\t\tShopUI:ShowBargainDialog(data)\n\n\t\t\telseif eventType == "BargainResult" then\n\t\t\t\tlocal popup = screenGui and uiRefs.bargainPopup\n\t\t\t\tif popup then\n\t\t\t\t\tpopup.Visible = false\n\t\t\t\t\tpopup.BackgroundTransparency = 1\n\t\t\t\tend\n\n\t\t\t\tif data.Success then\n\t\t\t\t\tlocal itemKey = data.ItemKey\n\t\t\t\t\tif itemKey then\n\t\t\t\t\t\tbargainState[itemKey] = { discounted = true }\n\t\t\t\t\tend\n\t\t\t\t\tShopUI:RefreshUI(currentShopData)\n\t\t\t\t\tShopUI:ShowResult(true, { Message = data.Message or "老板很开心！给你打 8 折！" })\n\t\t\t\telse\n\t\t\t\t\tShopUI:ShowResult(false, { Message = data.Message or "老板不高兴，还是原价吧" })\n\t\t\t\tend'
);
console.log('OK: Bargain event handlers updated');

// ===== CHANGE B: Add UseItemResult handler =====
content = content.replace(
  '\t\telseif eventType == "ShopClosed" then\n\t\t\t\tShopUI:ShowResult(false, { Message = data.Message or "仙丹阁已打烊" })',
  '\t\telseif eventType == "ShopClosed" then\n\t\t\t\tShopUI:ShowResult(false, { Message = data.Message or "仙丹阁已打烊" })\n\n\t\t\telseif eventType == "UseItemResult" then\n\t\t\t\tif currentShopData then\n\t\t\t\t\tcurrentShopData.Backpack = data.Backpack or {}\n\t\t\t\tend\n\t\t\t\tif currentTab == "backpack" then\n\t\t\t\t\tShopUI:RenderBackpack()\n\t\t\t\tend\n\t\t\t\tShopUI:ShowResult(data.Success, data)'
);
console.log('OK: UseItemResult handler added');

// ===== CHANGE C: isShopOpen = true on OpenShop =====
content = content.replace(
  'if eventType == "OpenShop" then\n\t\t\t\tShopUI:Open(data)',
  'if eventType == "OpenShop" then\n\t\t\t\tisShopOpen = true\n\t\t\t\tShopUI:Open(data)'
);
console.log('OK: OpenShop sets isShopOpen');

// ===== CHANGE D: isShopOpen guard in polling =====
content = content.replace(
  'if dist < 4 then\n\t\t\t\tlocal now = os.clock()',
  'if dist < 4 and not isShopOpen then\n\t\t\t\tlocal now = os.clock()'
);
console.log('OK: Proximity polling has isShopOpen guard');

// ===== CHANGE E: isShopOpen=false in Close =====
content = content.replace(
  'function ShopUI:Close()\n\t\tif screenGui then',
  'function ShopUI:Close()\n\t\tisShopOpen = false\n\t\tif screenGui then'
);
console.log('OK: Close resets isShopOpen');

// ===== CHANGE F: Add isShopOpen + currentTab declarations =====
content = content.replace(
  'local uiRefs = {}',
  'local uiRefs = {}\nlocal isShopOpen = false\nlocal currentTab = "shop"'
);
console.log('OK: Added isShopOpen + currentTab declarations');

// ===== CHANGE G: Replace panel + title section =====
// Find: -- 主面板 through the line before -- 仙晶余额
const panelSectionEnd = content.indexOf('\n\t-- 仙晶余额');
const panelSectionStart = content.indexOf('\n\t-- 主面板');
if (panelSectionStart === -1 || panelSectionEnd === -1) {
  console.error('ERROR: panel section boundaries');
  process.exit(1);
}
const oldPanel = content.substring(panelSectionStart + 1, panelSectionEnd);
const newPanel =
`\t-- 主面板（右下角）
\tlocal panel = Instance.new("Frame")
\tpanel.Name = "Panel"
\tpanel.Size = UDim2.new(0, 350, 0, 460)
\tpanel.Position = UDim2.new(1, -365, 1, -475)
\tpanel.BackgroundColor3 = COLORS.Panel
\tpanel.BorderSizePixel = 0
\tpanel.Parent = screenGui
\tlocal panelCorner = Instance.new("UICorner")
\tpanelCorner.CornerRadius = UDim.new(0, 12)
\tpanelCorner.Parent = panel

\t-- 标题栏
\tlocal titleBar = Instance.new("Frame")
\ttitleBar.Name = "TitleBar"
\ttitleBar.Size = UDim2.new(1, 0, 0, 32)
\ttitleBar.BackgroundColor3 = COLORS.Bg
\ttitleBar.BorderSizePixel = 0
\ttitleBar.Parent = panel
\tlocal titleBarCorner = Instance.new("UICorner")
\ttitleBarCorner.CornerRadius = UDim.new(0, 12)
\ttitleBarCorner.Parent = titleBar

\tlocal title = Instance.new("TextLabel")
\ttitle.Name = "Title"
\ttitle.Size = UDim2.new(0, 80, 1, 0)
\ttitle.Position = UDim2.new(0, 10, 0, 0)
\ttitle.BackgroundTransparency = 1
\ttitle.Text = "仙丹阁"
\ttitle.TextColor3 = COLORS.Gold
\ttitle.TextSize = 18
\ttitle.Font = Enum.Font.SourceSansBold
\ttitle.TextXAlignment = Enum.TextXAlignment.Left
\ttitle.Parent = titleBar

\t-- 标签切换
\tlocal shopTab = Instance.new("TextButton")
\tshopTab.Name = "ShopTab"
\tshopTab.Size = UDim2.new(0, 50, 0, 24)
\tshopTab.Position = UDim2.new(0, 100, 0, 4)
\tshopTab.Text = "商店"
\tshopTab.TextColor3 = COLORS.Gold
\tshopTab.TextSize = 14
\tshopTab.Font = Enum.Font.SourceSansBold
\tshopTab.BackgroundColor3 = COLORS.DarkGray
\tshopTab.BorderSizePixel = 0
\tshopTab.Parent = titleBar
\tlocal shopTabCorner = Instance.new("UICorner")
\tshopTabCorner.CornerRadius = UDim.new(0, 4)
\tshopTabCorner.Parent = shopTab

\tlocal bpTab = Instance.new("TextButton")
\tbpTab.Name = "BackpackTab"
\tbpTab.Size = UDim2.new(0, 50, 0, 24)
\tbpTab.Position = UDim2.new(0, 155, 0, 4)
\tbpTab.Text = "背包"
\tbpTab.TextColor3 = COLORS.White
\tbpTab.TextSize = 14
\tbpTab.Font = Enum.Font.SourceSansBold
\tbpTab.BackgroundColor3 = COLORS.Panel
\tbpTab.BorderSizePixel = 0
\tbpTab.Parent = titleBar
\tlocal bpTabCorner = Instance.new("UICorner")
\tbpTabCorner.CornerRadius = UDim.new(0, 4)
\tbpTabCorner.Parent = bpTab

\t-- 关闭按钮
\tlocal closeBtn = Instance.new("TextButton")
\tcloseBtn.Name = "CloseBtn"
\tcloseBtn.Size = UDim2.new(0, 28, 0, 28)
\tcloseBtn.Position = UDim2.new(1, -32, 0, 2)
\tcloseBtn.Text = "✕"
\tcloseBtn.TextColor3 = COLORS.Gray
\tcloseBtn.TextSize = 16
\tcloseBtn.Font = Enum.Font.SourceSansBold
\tcloseBtn.BackgroundTransparency = 1
\tcloseBtn.BorderSizePixel = 0
\tcloseBtn.Parent = titleBar
\tcloseBtn.MouseButton1Click:Connect(function()
\t\tself:Close()
\tend)`;

content = content.replace(oldPanel, newPanel);
console.log('OK: Panel section replaced');

// ===== CHANGE H: Replace balance + grid + close section =====
// From -- 仙晶余额 to self:CreateResultPopup(panel) (exclusive)
const gridEnd = content.indexOf('\n\tself:CreateResultPopup(panel)');
const gridStart = content.indexOf('\n\t-- 仙晶余额');
if (gridStart === -1 || gridEnd === -1) {
  console.error('ERROR: grid boundaries');
  process.exit(1);
}
const oldGrid = content.substring(gridStart + 1, gridEnd);
const newGrid =
`\t-- 仙晶余额
\tlocal balanceFrame = Instance.new("Frame")
\tbalanceFrame.Name = "BalanceFrame"
\tbalanceFrame.Size = UDim2.new(0.9, 0, 0, 28)
\tbalanceFrame.Position = UDim2.new(0.05, 0, 0, 36)
\tbalanceFrame.BackgroundColor3 = COLORS.Bg
\tbalanceFrame.BorderSizePixel = 0
\tbalanceFrame.Parent = panel
\tlocal balanceCorner = Instance.new("UICorner")
\tbalanceCorner.CornerRadius = UDim.new(0, 6)
\tbalanceCorner.Parent = balanceFrame

\tlocal balanceLabel = Instance.new("TextLabel")
\tbalanceLabel.Name = "BalanceLabel"
\tbalanceLabel.Size = UDim2.new(1, -10, 1, 0)
\tbalanceLabel.Position = UDim2.new(0, 5, 0, 0)
\tbalanceLabel.BackgroundTransparency = 1
\tbalanceLabel.Text = "仙晶：" .. tostring(currentShopData.XianJing or 0)
\tbalanceLabel.TextColor3 = COLORS.Gold
\tbalanceLabel.TextSize = 16
\tbalanceLabel.Font = Enum.Font.SourceSansBold
\tbalanceLabel.TextXAlignment = Enum.TextXAlignment.Center
\tbalanceLabel.Parent = balanceFrame

\t-- 商品/背包容器（可滚动）
\tlocal scrollFrame = Instance.new("ScrollingFrame")
\tscrollFrame.Name = "ItemScroll"
\tscrollFrame.Size = UDim2.new(1, -10, 1, -80)
\tscrollFrame.Position = UDim2.new(0, 5, 0, 70)
\tscrollFrame.BackgroundTransparency = 1
\tscrollFrame.BorderSizePixel = 0
\tscrollFrame.ScrollBarThickness = 4
\tscrollFrame.Parent = panel

\tuiRefs.scrollFrame = scrollFrame
\tuiRefs.balanceLabel = balanceLabel

\t-- 标签切换
\tlocal function switchTab(tab)
\t\tcurrentTab = tab
\t\tif tab == "shop" then
\t\t\tshopTab.BackgroundColor3 = COLORS.DarkGray
\t\t\tshopTab.TextColor3 = COLORS.Gold
\t\t\tbpTab.BackgroundColor3 = COLORS.Panel
\t\t\tbpTab.TextColor3 = COLORS.White
\t\t\tShopUI:RenderItems()
\t\telse
\t\t\tbpTab.BackgroundColor3 = COLORS.DarkGray
\t\t\tbpTab.TextColor3 = COLORS.Gold
\t\t\tshopTab.BackgroundColor3 = COLORS.Panel
\t\t\tshopTab.TextColor3 = COLORS.White
\t\t\tShopUI:RenderBackpack()
\t\tend
\tend

\tshopTab.MouseButton1Click:Connect(function() switchTab("shop") end)
\tbpTab.MouseButton1Click:Connect(function() switchTab("backpack") end)

\t-- 初始渲染商品列表
\tShopUI:RenderItems()`;

content = content.replace(oldGrid, newGrid);
console.log('OK: Grid section replaced');

// ===== CHANGE I: Remove the old CreateUI end + closeBtn + storage section =====
// The old code after self:CreateBargainPopup(panel) had closeBtn + storage. But we moved closeBtn to the title bar.
// The old closeBtn (now replaced) and storage comment lines need cleanup.
// Actually since we replaced the whole grid section, the closeBtn in the old location is gone.
// Let's check: the old closeBtn was after the grid, and we replaced everything from -- 仙晶余额 to self:CreateResultPopup.
// So closeBtn should be removed already. The "存储引用" line is also inside the replaced section.

// ===== CHANGE J: Add RenderItems and RenderBackpack methods =====
// Insert before CreateResultPopup
const insertionPoint = content.indexOf('\n-- 结果弹窗\n');
if (insertionPoint === -1) {
  console.error('ERROR: insertion point not found');
  process.exit(1);
}
const methods = `

-- ============================================================
-- 渲染商品列表（紧凑布局）
-- ============================================================
function ShopUI:RenderItems()
\tlocal scroll = uiRefs.scrollFrame
\tif not scroll then return end
\tfor _, v in pairs(scroll:GetChildren()) do
\t\tif v:IsA("Frame") then v:Destroy() end
\tend

\tlocal items = (currentShopData or {}).Items or {}
\tlocal purchases = (currentShopData or {}).DailyPurchases or {}
\tlocal y = 5
\tfor itemKey, item in pairs(items) do
\t\tlocal card = Instance.new("Frame")
\t\tcard.Name = "ItemCard_" .. itemKey
\t\tcard.Size = UDim2.new(1, -10, 0, 62)
\t\tcard.Position = UDim2.new(0, 5, 0, y)
\t\tcard.BackgroundColor3 = COLORS.Bg
\t\tcard.BorderSizePixel = 0
\t\tcard.Parent = scroll
\t\tlocal cardCorner = Instance.new("UICorner")
\t\tcardCorner.CornerRadius = UDim.new(0, 6)
\t\tcardCorner.Parent = card

\t\tlocal nameL = Instance.new("TextLabel")
\t\tnameL.Size = UDim2.new(0, 110, 0, 20)
\t\tnameL.Position = UDim2.new(0, 6, 0, 2)
\t\tnameL.BackgroundTransparency = 1
\t\tnameL.Text = item.Name
\t\tnameL.TextColor3 = item.IsHidden and COLORS.DarkGray or COLORS.White
\t\tnameL.TextSize = 14
\t\tnameL.Font = Enum.Font.SourceSansBold
\t\tnameL.TextXAlignment = Enum.TextXAlignment.Left
\t\tnameL.Parent = card

\t\tlocal descL = Instance.new("TextLabel")
\t\tdescL.Size = UDim2.new(0, 140, 0, 16)
\t\tdescL.Position = UDim2.new(0, 6, 0, 22)
\t\tdescL.BackgroundTransparency = 1
\t\tif item.IsHidden then
\t\t\tdescL.Text = "仙晶达到 " .. tostring(item.Price) .. " 后揭晓"
\t\telse
\t\t\tdescL.Text = item.Description
\t\tend
\t\tdescL.TextColor3 = item.IsHidden and COLORS.DarkGray or COLORS.Gray
\t\tdescL.TextSize = 11
\t\tdescL.Font = Enum.Font.SourceSans
\t\tdescL.TextXAlignment = Enum.TextXAlignment.Left
\t\tdescL.Parent = card

\t\tlocal priceL = Instance.new("TextLabel")
\t\tpriceL.Size = UDim2.new(0, 110, 0, 16)
\t\tpriceL.Position = UDim2.new(0, 6, 0, 38)
\t\tpriceL.BackgroundTransparency = 1
\t\tpriceL.Text = "仙晶 x" .. tostring(item.Price)
\t\tpriceL.TextColor3 = COLORS.Gold
\t\tpriceL.TextSize = 11
\t\tpriceL.Font = Enum.Font.SourceSansBold
\t\tpriceL.TextXAlignment = Enum.TextXAlignment.Left
\t\tpriceL.Parent = card

\t\t-- 限购显示
\t\tif item.DailyLimit and item.DailyLimit > 0 then
\t\t\tlocal bought = purchases[itemKey] or 0
\t\t\tlocal remaining = item.DailyLimit - bought
\t\t\tpriceL.Text = priceL.Text .. " | 剩" .. tostring(remaining)
\t\tend

\t\t-- 购买按钮
\t\tlocal buyBtn = Instance.new("TextButton")
\t\tbuyBtn.Name = "BuyBtn_" .. itemKey
\t\tbuyBtn.Size = UDim2.new(0, 58, 0, 24)
\t\tbuyBtn.Position = UDim2.new(0, 125, 0, 3)
\t\tbuyBtn.Text = "购买"
\t\tbuyBtn.TextColor3 = COLORS.White
\t\tbuyBtn.TextSize = 12
\t\tbuyBtn.Font = Enum.Font.SourceSansBold
\t\tbuyBtn.BorderSizePixel = 0
\t\tbuyBtn.Parent = card
\t\tlocal buyCorner = Instance.new("UICorner")
\t\tbuyCorner.CornerRadius = UDim.new(0, 4)
\t\tbuyCorner.Parent = buyBtn

\t\t-- 砍价按钮
\t\tlocal bargainBtn = Instance.new("TextButton")
\t\tbargainBtn.Name = "BargainBtn_" .. itemKey
\t\tbargainBtn.Size = UDim2.new(0, 58, 0, 22)
\t\tbargainBtn.Position = UDim2.new(0, 125, 0, 29)
\t\tbargainBtn.Text = "砍价"
\t\tbargainBtn.TextColor3 = COLORS.White
\t\tbargainBtn.TextSize = 11
\t\tbargainBtn.Font = Enum.Font.SourceSansBold
\t\tbargainBtn.BackgroundColor3 = COLORS.Gold
\t\tbargainBtn.BorderSizePixel = 0
\t\tbargainBtn.Parent = card
\t\tlocal bargainCorner = Instance.new("UICorner")
\t\tbargainCorner.CornerRadius = UDim.new(0, 4)
\t\tbargainCorner.Parent = bargainBtn

\t\t-- 按钮状态
\t\tlocal isSoldOut = false
\t\tif item.DailyLimit and item.DailyLimit > 0 then
\t\t\tlocal bought = purchases[itemKey] or 0
\t\t\tif bought >= item.DailyLimit then isSoldOut = true end
\t\tend
\t\tlocal hasMoney = (currentShopData.XianJing or 0) >= item.Price

\t\tif item.IsHidden then
\t\t\tbuyBtn.Text = "???"; buyBtn.BackgroundColor3 = COLORS.DarkGray; buyBtn.Active = false
\t\t\tbargainBtn.Text = "???"; bargainBtn.BackgroundColor3 = COLORS.DarkGray; bargainBtn.Active = false
\t\telseif isSoldOut then
\t\t\tbuyBtn.Text = "已售罄"; buyBtn.BackgroundColor3 = COLORS.DarkGray; buyBtn.Active = false
\t\t\tbargainBtn.Visible = false
\t\telse
\t\t\tbuyBtn.BackgroundColor3 = hasMoney and COLORS.DarkGreen or COLORS.DarkRed
\t\t\tbuyBtn.Active = true
\t\tend

\t\t-- 砍价后显示折后价
\t\tlocal bargained = bargainState[itemKey]
\t\tif bargained and bargained.discounted then
\t\t\tbargainBtn.Text = "已砍"; bargainBtn.BackgroundColor3 = COLORS.DarkGray; bargainBtn.Active = false
\t\t\tlocal discountedPrice = math.floor(item.Price * 0.8)
\t\t\tpriceL.Text = "仙晶 x" .. tostring(item.Price) .. " (" .. tostring(discountedPrice) .. ")"
\t\t\tpriceL.TextColor3 = COLORS.Green
\t\tend

\t\t-- 购买点击
\t\tbuyBtn.MouseButton1Click:Connect(function()
\t\t\tif not buyBtn.Active then return end
\t\t\tbuyBtn.Text = "购买中..."; buyBtn.Active = false
\t\t\tif ShopEvent then
\t\t\t\tShopEvent:FireServer("Purchase:Shop", nil, { ItemKey = itemKey })
\t\t\tend
\t\tend)

\t\t-- 砍价点击
\t\tbargainBtn.MouseButton1Click:Connect(function()
\t\t\tif not bargainBtn.Active then return end
\t\t\tbargainBtn.Active = false; bargainBtn.Text = "砍价中..."
\t\t\tif ShopEvent then
\t\t\t\tShopEvent:FireServer("Bargain:Shop", nil, { ItemKey = itemKey })
\t\t\tend
\t\tend)

\t\ty = y + 66
\tend
\tscroll.CanvasSize = UDim2.new(0, 0, 0, y + 10)
end

-- ============================================================
-- 渲染背包
-- ============================================================
function ShopUI:RenderBackpack()
\tlocal scroll = uiRefs.scrollFrame
\tif not scroll then return end
\tfor _, v in pairs(scroll:GetChildren()) do
\t\tif v:IsA("Frame") then v:Destroy() end
\tend

\tlocal backpack = (currentShopData or {}).Backpack or {}
\tlocal items = (currentShopData or {}).Items or {}
\tlocal y = 5
\tfor itemKey, count in pairs(backpack) do
\t\tlocal item = items[itemKey]
\t\tif not item then continue end
\t\tif item.IsHidden then continue end

\t\tlocal card = Instance.new("Frame")
\t\tcard.Size = UDim2.new(1, -10, 0, 50)
\t\tcard.Position = UDim2.new(0, 5, 0, y)
\t\tcard.BackgroundColor3 = COLORS.Bg
\t\tcard.BorderSizePixel = 0
\t\tcard.Parent = scroll
\t\tlocal cardCorner = Instance.new("UICorner")
\t\tcardCorner.CornerRadius = UDim.new(0, 6)
\t\tcardCorner.Parent = card

\t\tlocal nameL = Instance.new("TextLabel")
\t\tnameL.Size = UDim2.new(0, 120, 0, 20)
\t\tnameL.Position = UDim2.new(0, 6, 0, 2)
\t\tnameL.BackgroundTransparency = 1
\t\tnameL.Text = item.Name .. " x" .. tostring(count)
\t\tnameL.TextColor3 = COLORS.White
\t\tnameL.TextSize = 14
\t\tnameL.Font = Enum.Font.SourceSansBold
\t\tnameL.TextXAlignment = Enum.TextXAlignment.Left
\t\tnameL.Parent = card

\t\tlocal descL = Instance.new("TextLabel")
\t\tdescL.Size = UDim2.new(0, 150, 0, 16)
\t\tdescL.Position = UDim2.new(0, 6, 0, 22)
\t\tdescL.BackgroundTransparency = 1
\t\tdescL.Text = item.Description
\t\tdescL.TextColor3 = COLORS.Gray
\t\tdescL.TextSize = 11
\t\tdescL.Font = Enum.Font.SourceSans
\t\tdescL.TextXAlignment = Enum.TextXAlignment.Left
\t\tdescL.Parent = card

\t\t-- 使用按钮
\t\tlocal useBtn = Instance.new("TextButton")
\t\tuseBtn.Size = UDim2.new(0, 58, 0, 28)
\t\tuseBtn.Position = UDim2.new(0, 130, 0, 10)
\t\tuseBtn.Text = "使用"
\t\tuseBtn.TextColor3 = COLORS.White
\t\tuseBtn.TextSize = 12
\t\tuseBtn.Font = Enum.Font.SourceSansBold
\t\tuseBtn.BackgroundColor3 = COLORS.DarkGreen
\t\tuseBtn.BorderSizePixel = 0
\t\tuseBtn.Parent = card
\t\tlocal useCorner = Instance.new("UICorner")
\t\tuseCorner.CornerRadius = UDim.new(0, 4)
\t\tuseCorner.Parent = useBtn

\t\tuseBtn.MouseButton1Click:Connect(function()
\t\t\tuseBtn.Text = "使用中..."; useBtn.Active = false
\t\t\tif ShopEvent then
\t\t\t\tShopEvent:FireServer("UseItem:Shop", nil, { ItemKey = itemKey })
\t\t\tend
\t\tend)

\t\ty = y + 54
\tend
\tif y == 5 then
\t\tlocal emptyL = Instance.new("TextLabel")
\t\temptyL.Size = UDim2.new(1, 0, 0, 40)
\t\temptyL.Position = UDim2.new(0, 0, 0, 20)
\t\temptyL.BackgroundTransparency = 1
\t\temptyL.Text = "背包空空如也"
\t\temptyL.TextColor3 = COLORS.Gray
\t\temptyL.TextSize = 16
\t\temptyL.Font = Enum.Font.SourceSans
\t\temptyL.TextXAlignment = Enum.TextXAlignment.Center
\t\temptyL.Parent = scroll
\tend
\tscroll.CanvasSize = UDim2.new(0, 0, 0, math.max(y + 10, 60))
end
`;

content = content.substring(0, insertionPoint) + methods + content.substring(insertionPoint);
console.log('OK: RenderItems + RenderBackpack methods added');

// ===== CHANGE K: Remove the overlay section completely =====
// The overlay is not needed for bottom-right panel
content = content.replace(
  '\t\t-- 遮罩\n\t\tlocal overlay = Instance.new("Frame")\n\t\toverlay.Name = "Overlay"\n\t\toverlay.Size = UDim2.new(1, 0, 1, 0)\n\t\toverlay.BackgroundColor3 = Color3.new(0, 0, 0)\n\t\toverlay.BackgroundTransparency = 0.6\n\t\toverlay.BorderSizePixel = 0\n\t\toverlay.Parent = screenGui\n\n\t\toverlay.InputBegan:Connect(function(input)\n\t\t\tif input.UserInputType == Enum.UserInputType.MouseButton1\n\t\t\t\tor input.UserInputType == Enum.UserInputType.Touch then\n\t\t\t\tself:Close()\n\t\t\tend\n\t\tend)\n\n',
  ''
);
console.log('OK: Overlay removed');

fs.writeFileSync(filePath, content, 'utf-8');
console.log('DONE: ShopUI fully updated');
