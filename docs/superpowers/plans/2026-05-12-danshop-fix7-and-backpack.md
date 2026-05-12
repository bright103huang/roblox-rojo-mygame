# 仙丹阁 7 问题修复 + 背包系统实施计划

> **For agentic workers:** 7 个问题按依赖关系依次修复，TDD 驱动，每步提交。

**Goal:** 修复仙丹阁 7 个问题并实现轻量背包系统

**Architecture:** 
- 砍价：修复为 2 步协议（请求题目→对话弹窗→选择答案→判对错→折扣生效）
- 背包：购买改存背包，新增 UseItem 服务端接口，客户端背包标签页
- ShopUI：从居中弹窗改为右下角紧凑面板，含商品 + 背包标签
- 数值：夜间打坐（家·蒲团）使用丹药效果 ×1.5

**Tech Stack:** Luau, Roblox RemoteEvent (ShopEvent), ModuleScript

---

### Task 0: 数据层 — DataManager 新增 Backpack 字段

**Files:**
- Modify: `ServerScriptService/server/Systems/DataManager.lua` (DEFAULT_DATA section)

- [ ] **Step 1: 阅读 DEFAULT_DATA 表位置**

```bash
grep -n "DEFAULT_DATA\|Backpack\|DailyPurchases" ServerScriptService/server/Systems/DataManager.lua
```

- [ ] **Step 2: 追加 Backpack 字段**

在 DEFAULT_DATA 表内（与 DailyPurchases 同区段）添加：
```lua
Backpack = {},
```

- [ ] **Step 3: 提交**

```bash
git add ServerScriptService/server/Systems/DataManager.lua
git commit -m "feat: add Backpack field to DataManager DEFAULT_DATA"
```

---

### Task 1: 服务端 — ShopService 砍价协议修复 + ShopOpen 检查 + 背包购买 + UseItem

**Files:**
- Modify: `ServerScriptService/server/Systems/ShopService.server.lua`

**改点：**
1. Bargain 请求处理：新增 `BargainAnswer` 和 `BargainRequest` 事件类型区分
2. ShopOpen 检查覆盖砍价请求
3. Purchase 改为存入背包
4. 新增 `UseItem` 接口（含夜间打坐倍数）

- [ ] **Step 1: 阅读当前 ShopService**

```bash
grep -n "HandleBargain\|Purchase\|function.*:" ServerScriptService/server/Systems/ShopService.server.lua
```

- [ ] **Step 2: 修改 Bargain 协议 — 区分"请求题目"和"提交答案"**

当前问题：客户端发 Bargain:Shop（无 choiceIndex）→ 服务端返回 Success=true（含题目）→ 客户端误判为砍价成功。

修复方案：服务器端增加 `action` 区分：
- `"Bargain:Shop"` 且无 `ChoiceIndex` → 返回题目（新 eventType: `"BargainQuestion"`）
- `"Bargain:Shop"` 且有 `ChoiceIndex` → 判对错，设 pendingBargains（eventType: `"BargainResult"`）

修改 ShopEvent.OnServerEvent handler 中的 Bargain:Shop 分支：

```lua
-- 砍价
if action == "Bargain:Shop" then
    local itemKey = contextData and contextData.ItemKey
    local choiceIndex = contextData and contextData.ChoiceIndex
    if not itemKey then return end

    -- Step 1: 检查营业时间
    if player:GetAttribute("ShopOpen") == 0 then
        ShopEvent:FireClient(player, "BargainResult", {
            Success = false,
            Message = "仙丹阁已打烊",
        })
        return
    end

    if not choiceIndex then
        -- 请求题目
        local result = ShopService:RequestBargainQuestion(player, itemKey)
        ShopEvent:FireClient(player, "BargainQuestion", {
            ItemKey = itemKey,
            Question = result.Question,
            Options = result.Options,
            QuestionId = result.QuestionId,
        })
    else
        -- 提交答案
        local result = ShopService:SubmitBargainAnswer(player, itemKey, choiceIndex)
        ShopEvent:FireClient(player, "BargainResult", {
            Success = result.Success,
            Message = result.Message,
            ItemKey = itemKey,
        })
    end
    return
end
```

- [ ] **Step 3: 新增 RequestBargainQuestion / SubmitBargainAnswer 方法**

```lua
function ShopService:RequestBargainQuestion(player, itemKey)
    -- 检查该玩家该商品是否已砍过
    local uid = player.UserId
    if pendingBargains[uid] and pendingBargains[uid][itemKey] ~= nil then
        return { Question = nil }  -- 已砍过，不重复
    end
    local qId = math.random(1, #BARGAIN_QUESTIONS)
    local q = BARGAIN_QUESTIONS[qId]
    return { Question = q.Question, Options = q.Options, QuestionId = qId }
end

function ShopService:SubmitBargainAnswer(player, itemKey, choiceIndex)
    local q = BARGAIN_QUESTIONS[choiceIndex]
    if not q then return { Success = false, Message = "无效选项" } end

    -- 检查是否已砍过（防重复提交）
    local uid = player.UserId
    if pendingBargains[uid] and pendingBargains[uid][itemKey] ~= nil then
        return { Success = false, Message = "已砍过价了" }
    end

    local isCorrect = (choiceIndex == q.Correct) or (q.CorrectAlt and choiceIndex == q.CorrectAlt)
    if isCorrect then
        if not pendingBargains[uid] then pendingBargains[uid] = {} end
        pendingBargains[uid][itemKey] = true
        return { Success = true, Message = "老板很开心！给你打 8 折！" }
    else
        -- 记录失败（不可再砍）
        if not pendingBargains[uid] then pendingBargains[uid] = {} end
        pendingBargains[uid][itemKey] = false
        return { Success = false, Message = "老板不高兴，还是原价吧" }
    end
end
```

- [ ] **Step 4: 修改 GetBargainDiscount（需同时检查 pendingBargains 存的是 true 还是 false）**

```lua
function ShopService:GetBargainDiscount(player, itemKey)
    local uid = player.UserId
    if pendingBargains[uid] and pendingBargains[uid][itemKey] == true then
        return 0.8
    end
    return 1.0
end
```

- [ ] **Step 5: 修改 Purchase — 改为存入背包**

将 Purchase 中的即时效果发放改为存入 Backpack：

```lua
-- 原有的发放效果代码（约 line 224-257）替换为：
local backpack = data.Backpack or {}
backpack[itemKey] = (backpack[itemKey] or 0) + 1
data.Backpack = backpack
DataManager:UpdateField(player, "Backpack", backpack)
```

- [ ] **Step 6: 新增 UseItem 方法**

```lua
-- [[
--   使用物品（从背包消耗，应用效果）
--   如在家场景蒲团打坐状态，效果 ×1.5
-- ]]
function ShopService:UseItem(player, itemKey, isMeditating)
    local data = DataManager:GetData(player)
    if not data then return { Success = false, Message = "数据未加载" } end

    local backpack = data.Backpack or {}
    local count = backpack[itemKey] or 0
    if count <= 0 then return { Success = false, Message = "背包中没有该物品" } end

    local item = DanConfig.Items[itemKey]
    if not item then return { Success = false, Message = "未知物品" } end

    -- 消耗背包
    backpack[itemKey] = count - 1
    if backpack[itemKey] <= 0 then backpack[itemKey] = nil end
    data.Backpack = backpack
    DataManager:UpdateField(player, "Backpack", backpack)

    -- 应用效果
    local effectValue = item.EffectValue
    if isMeditating then
        effectValue = math.floor(effectValue * 1.5)
    end

    local effectType = item.EffectType

    if effectType == "Stamina" or effectType == "Spirit"
        or effectType == "Fatigue" or effectType == "FirePoison"
        or effectType == "Malice" then
        local costs = {}
        costs[effectType] = effectValue
        StatusService:ApplyCosts(player, costs)

    elseif effectType == "AgilityExp" then
        StatusService:AddExp(player, "Agility", effectValue)
    elseif effectType == "AlchemyExp" then
        StatusService:AddExp(player, "AlchemyLv", effectValue)
    elseif effectType == "CombatExp" then
        StatusService:AddExp(player, "Combat", effectValue)
    elseif effectType == "RandomStat" then
        local stats = { "Agility", "AlchemyLv", "Combat" }
        local chosen = stats[math.random(1, #stats)]
        StatusService:AddExp(player, chosen, effectValue)
    elseif effectType == "AllStats" then
        StatusService:AddExp(player, "Agility", effectValue)
        StatusService:AddExp(player, "AlchemyLv", effectValue)
        StatusService:AddExp(player, "Combat", effectValue)
    end

    return { Success = true, Message = "使用成功" }
end
```

- [ ] **Step 7: 新增 UseItem 事件监听**

在 ShopEvent.OnServerEvent handler 中新增：

```lua
if action == "UseItem:Shop" then
    local itemKey = contextData and contextData.ItemKey
    local isMeditating = contextData and contextData.IsMeditating or false
    if not itemKey then return end

    local result = ShopService:UseItem(player, itemKey, isMeditating)

    -- 返回更新后的背包数据
    local data = DataManager:GetData(player)
    ShopEvent:FireClient(player, "UseItemResult", {
        Success = result.Success,
        Message = result.Message,
        Backpack = data and data.Backpack or {},
    })
    return
end
```

- [ ] **Step 8: OpenShop 响应中附带背包数据**

修改 `"Pick:Shop"` handler，在返回的 data 中添加：

```lua
ShopEvent:FireClient(player, "OpenShop", {
    Items = items,
    DailyPurchases = data.DailyPurchases or {},
    XianJing = data.XianJing or 0,
    Backpack = data.Backpack or {},  -- 新增
})
```

- [ ] **Step 9: 提交**

```bash
git add ServerScriptService/server/Systems/ShopService.server.lua
git commit -m "feat: fix bargain 2-step protocol, add backpack purchase and UseItem"
```

---

### Task 2: 客户端 — ShopUI 全面改造（右下角 + 背包 + 砍价修复 + 商品全可见）

**Files:**
- Modify: `StarterPlayer/StarterPlayerScripts/client/ShopUI.local.lua`

**改点：**
1. 砍价协议改为 2 步（请求题目→弹窗→选答案→结果）
2. ShopOpen = false 时隐藏砍价/购买按钮
3. UI 位置从居中改为右下角
4. 背包标签页（显示已购买且未使用的丹药）
5. 商品格子紧凑化，用 ScrollingFrame 使 6 件全可见
6. 轮询触发器增加打开状态标记，防重复触发

**ShopUI 新布局设计：**

```
┌──────────────────────┐  ← 右下角固定面板，350×480
│  仙丹阁  [背包] [✕]  │  ← 标签切换
├──────────────────────┤
│                      │
│  商品列表 / 背包列表  │  ← ScrollingFrame 切换内容
│                      │
│                      │
├──────────────────────┤
│  仙晶: 250           │  ← 底部固定
└──────────────────────┘
```

**商品卡片紧凑设计（每件约 160×70）：**
```
┌──────────────────────────┐
│ 回气丹      仙晶 x20     │
│ 恢复体力 20    [购买][砍价]│
│ 剩余 5/5                  │
└──────────────────────────┘
```

**背包卡片：**
```
┌──────────────────────────┐
│ 回气丹 × 2    [使用]     │
│ 恢复体力 20              │
└──────────────────────────┘
```

- [ ] **Step 1: 阅读当前 ShopUI**

```bash
wc -l StarterPlayer/StarterPlayerScripts/client/ShopUI.local.lua
```

- [ ] **Step 2: 修改 UI 位置和尺寸**

```lua
-- 主面板改为右下角
panel.Size = UDim2.new(0, 350, 0, 480)
panel.Position = UDim2.new(1, -370, 1, -500)
panel.BackgroundColor3 = COLORS.Panel

-- 去掉全屏遮罩（overlay）
```

- [ ] **Step 3: 替换商品网格为紧凑 ScrollingFrame**

商品列表放入 ScrollingFrame，每个卡片水平排列（1 列，每行约 70px 高）：

```lua
-- 商品容器（可滚动）
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ItemScroll"
scrollFrame.Size = UDim2.new(1, -10, 1, -80)
scrollFrame.Position = UDim2.new(0, 5, 0, 40)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 4
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #itemKeys * 76 + 10)
scrollFrame.Parent = panel
```

- [ ] **Step 4: 修复砍价事件处理**

替换 OnClientEvent 中 BargainResult:Shop 的处理：

```lua
elseif eventType == "BargainQuestion" then
    -- 显示砍价对话弹窗
    ShopUI:ShowBargainDialog(data)

elseif eventType == "BargainResult" then
    -- 隐藏砍价弹窗
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
```

- [ ] **Step 5: 修复砍价按钮点击（先请求题目，不直接判结果）**

```lua
-- 砍价按钮点击
bargainBtn.MouseButton1Click:Connect(function()
    if not bargainBtn.Active then return end
    bargainBtn.Active = false
    bargainBtn.Text = "砍价中..."
    if ShopEvent then
        ShopEvent:FireServer("Bargain:Shop", nil, {
            ItemKey = itemKey,
            -- 不传 ChoiceIndex = 请求题目
        })
    end
end)
```

- [ ] **Step 6: 修复 ShowBargainDialog 选项点击**

选项按钮点击后发答案（传 ChoiceIndex）：

```lua
btn.MouseButton1Click:Connect(function()
    for _, b in ipairs(optionButtons) do
        b.Active = false
    end
    if ShopEvent and pendingItemKey then
        ShopEvent:FireServer("Bargain:Shop", nil, {
            ItemKey = pendingItemKey,
            ChoiceIndex = data.QuestionId,  -- 传选中的题目ID作为答案
        })
    end
end)
```

- [ ] **Step 7: 实现背包标签页**

新增 `ShopUI:ShowBackpack()` 和 `ShopUI:ShowItems()` 两个视图切换：

```lua
function ShopUI:ShowBackpack()
    local scroll = uiRefs.itemScroll
    if not scroll then return end
    -- 清空 scroll
    for _, v in pairs(scroll:GetChildren()) do
        if v:IsA("Frame") then v:Destroy() end
    end

    local backpack = currentShopData.Backpack or {}
    local y = 5
    for itemKey, count in pairs(backpack) do
        local item = (currentShopData.Items or {})[itemKey]
        if not item then continue end
        -- 创建紧凑卡片
        local card = createBackpackCard(itemKey, item, count, y)
        card.Parent = scroll
        y = y + 66
    end
    scroll.CanvasSize = UDim2.new(0, 0, 0, y + 10)
end

function ShopUI:ShowItems()
    -- 重新生成商品列表（同现有逻辑但更紧凑）
end
```

- [ ] **Step 8: 防重复触发标记**

在轮询触发器中添加标记，如果 UI 已打开则不重复触发：

```lua
local isShopOpen = false

-- 修改事件监听
if eventType == "OpenShop" then
    isShopOpen = true
    ShopUI:Open(data)
elseif eventType == "ShopClosed" then
    -- 不设 isShopOpen，因为没有 UI 打开
    ShopUI:ShowResult(false, { Message = data.Message or "仙丹阁已打烊" })
end

-- 修改 Close()
function ShopUI:Close()
    isShopOpen = false
    if screenGui then ...
```

轮询触发器检查：

```lua
if dist < 4 and not isShopOpen then
    -- 只在 UI 未打开时触发
end
```

- [ ] **Step 9: 提交**

```bash
git add StarterPlayer/StarterPlayerScripts/client/ShopUI.local.lua
git commit -m "feat: redesign ShopUI as compact bottom-right panel with backpack tab, fix bargain dialog"
```

---

### Task 3: 家场景 — 蒲团打坐时使用丹药显示倍率提示

**Files:**
- Modify: `ServerScriptService/server/Systems/SceneSetup.server.lua` (home scene area)

在家的蒲团交互中添加检测，当玩家打坐且有丹药时提示可按某键/Button 使用丹药。

- [ ] **Step 1: 阅读家场景相关代码**

```bash
grep -n "Home\|蒲团\|Meditation\|Prayer" ServerScriptService/server/Systems/SceneSetup.server.lua
```

- [ ] **Step 2: 在蒲团交互中添加打坐状态属性**

当玩家触摸蒲团开始冥想时，设置 `player:SetAttribute("IsMeditating", true)`；
停止冥想时设为 false。

此属性供客户端在背包 UI 中显示「夜间打坐 ×1.5」标识。

- [ ] **Step 3: 提交**

```bash
git add ServerScriptService/server/Systems/SceneSetup.server.lua
git commit -m "feat: add IsMeditating attribute for meditation bonus"
```

---

### Task 4: 验证 — 全流程检查

- [ ] **Step 1: 砍价流程验证**
  1. 进入仙丹阁 → ShopUI 右下角显示
  2. 点击「砍价」→ 弹出对话弹窗，有老板对话 + 3 选项
  3. 选正确选项 → 显示「老板很开心！8 折！」
  4. 选错误选项 → 显示「老板不高兴，原价」
  5. 购买时：砍价成功 → 8 折；未砍价 → 原价

- [ ] **Step 2: 打烊检查**
  1. 不在营业时间（非 12-21 时）进入仙丹阁
  2. 砍价按钮不可见或不可点

- [ ] **Step 3: 背包检查**
  1. 购买丹药 → 背包 +1
  2. 打开背包标签 → 显示所有已购物品
  3. 点击「使用」→ 消耗 1 个，效果生效
  4. 如果正在打坐 → 效果 ×1.5

- [ ] **Step 4: 重复进入检查**
  1. 离开仙丹阁再进入
  2. 面板重新打开，砍价按钮可用（新的砍价机会）
  3. 无闪烁、无重复打开

- [ ] **Step 5: 商品可见性检查**
  1. 6 件商品全部可见，可滚动查看
  2. 朦胧商品显示 ???，达到仙晶后揭晓
