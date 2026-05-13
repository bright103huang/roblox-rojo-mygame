# 三个 Bug 修复计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复用户报告的三个 Bug：炼丹首次添柴计数异常、砍价卡在"砍价中"、购买丹药后背包为空

**Architecture:** 三个 Bug 各自独立，涉及不同模块：AlchemyTask（炼丹服务端逻辑）、ShopService（砍价+购买服务端逻辑）、ShopUI（砍价+背包客户端逻辑）。Bug 之间无依赖关系，可并行修复。

**Tech Stack:** Roblox Luau (server Script + client LocalScript + ModuleScript)

---

### Task 1: Bug 1 — 炼丹首次添柴第三次不成丹

**根因分析：** 客户端 `TaskClient.local.luau` 的 `state.carrying` 与服务器端 `AlchemyTask` 的 `carrying[userId]` 状态在首次炼丹循环中可能不同步。具体地：
- 服务端 `AlchemyTask.OnPlayerDrop` 返回 `false, "FuelAdded"` 时，`TaskService` 不向客户端发送标准的 `DropFailed/DropSuccess`，而是由 `AlchemyTask` 自行 fire `AlchemyFuel` 事件
- 客户端收到 `AlchemyFuel` 后在 `OnClientEvent` 中设置 `carrying = false`
- 但首次循环时，`ShowFire(step)` 的 1.2 秒自动关闭定时器可能与后续 `ShowResult()` 冲突，导致玩家看到的 UI 状态与服务器实际逻辑不符

**Files:**
- Modify: `ServerScriptService/server/Tasks/AlchemyTask.lua`
- Modify: `StarterPlayer/StarterPlayerScripts/client/AlchemyUI.lua`
- Test: 手动测试炼丹流程

- [ ] **Step 1: 修复 AlchemyTask 添柴计数健壮性**

  在 `AlchemyTask:OnPlayerDrop` 中，添柴分支前增加断言日志：

  ```lua
  -- 添柴分支（carrying == "firewood"），在第 99 行前插入：
  -- 防御：如果 step 已 >= 3 但 craft 没执行（异常状态），重置
  if (alchemyStep[userId] or 0) >= 3 then
      warn("AlchemyTask: " .. player.Name .. " 异常状态 alchemyStep=" .. tostring(alchemyStep[userId]) .. "，重置")
      alchemyStep[userId] = nil
      hasHerb[userId] = nil
      player:SetAttribute("AlchemyStep", nil)
      return false, "NeedHerbFirst"
  end
  ```

- [ ] **Step 2: 修复 AlchemyUI 定时器冲突**

  在 `AlchemyUI:ShowFire(step)` 中，记录定时器句柄并在 `Close()` 中取消：

  ```lua
  -- 在 AlchemyUI 顶部添加：
  local closeHandle = nil

  -- ShowFire 中修改为：
  if closeHandle then
      task.cancel(closeHandle)
      closeHandle = nil
  end
  closeHandle = task.delay(1.2, function()
      self:Close()
  end)

  -- 在 Close() 中添加：
  if closeHandle then
      task.cancel(closeHandle)
      closeHandle = nil
  end
  ```

- [ ] **Step 3: 在 AlchemyTask 中添加强制同步**

  在每次添柴后（`FuelAdded` 返回前），显式同步 `carrying` 状态到客户端 Attribute 以确保一致性：

  ```lua
  -- 在第 108 行后添加：
  player:SetAttribute("AlchemyCarrying", 0)  -- 服务端已清空 carrying
  ```

- [ ] **Step 4: 手动测试**

  1. 进入炼丹场景
  2. 取药材 → 入炉 → 取柴 ×3 → 确认第三次成丹或炸炉
  3. 关闭结果，重新开始第二次炼丹，确认流程正常
  4. 重启游戏，再次测试第一次炼丹

---

### Task 2: Bug 2 — 砍价卡在"砍价中"

**根因分析：** 客户端 `ShopUI.local.lua:315` 发送 `ChoiceIndex = data.QuestionId`（问题在题库中的索引），但服务端 `ShopService:SubmitBargainAnswer` 第 119 行用 `choiceIndex` 查题库 `BARGAIN_QUESTIONS[choiceIndex]` 后，在第 127 行又用 `choiceIndex == q.Correct` 比对答案。`ChoiceIndex` 实际上是 `QuestionId`（如 5），而 `q.Correct` 是正确选项编号（如 1），`5 == 1` 永远为 false，所以砍价总是失败。

**Files:**
- Modify: `StarterPlayer/StarterPlayerScripts/client/ShopUI.local.lua`
- Modify: `ServerScriptService/server/Systems/ShopService.server.lua`

- [ ] **Step 1: 修复客户端发送协议**

  在 `ShopUI.local.lua:315`，将 `ChoiceIndex` 改为用户实际选择的选项序号 `i`，并增加 `QuestionId` 字段：

  ```lua
  btn.MouseButton1Click:Connect(function()
      ...
      if ShopEvent and pendingItemKey then
          ShopEvent:FireServer("Bargain:Shop", nil, {
              ItemKey = pendingItemKey,
              ChoiceIndex = i,           -- Fix: 实际选的选项 1/2/3
              QuestionId = data.QuestionId,  -- 新增：题目 ID
          })
      end
  end)
  ```

- [ ] **Step 2: 修复服务端处理逻辑**

  在 `ShopService.server.lua` 的 `Bargain:Shop` 处理器中，从 `contextData` 读取 `QuestionId`，并修改 `SubmitBargainAnswer` 签名：

  ```lua
  -- 在 handler 中（约第404行）：
  else
      -- Step 2: 提交答案
      local questionId = contextData and contextData.QuestionId
      if not questionId then
          -- 兼容旧客户端
          questionId = choiceIndex
      end
      local result = ShopService:SubmitBargainAnswer(player, itemKey, questionId, choiceIndex)
      ...
  end
  ```

  修改函数签名和内部逻辑：

  ```lua
  function ShopService:SubmitBargainAnswer(player, itemKey, questionId, chosenOption)
      local q = BARGAIN_QUESTIONS[questionId]
      if not q then return { Success = false, Message = "无效选项" } end

      local uid = player.UserId
      if pendingBargains[uid] and pendingBargains[uid][itemKey] ~= nil then
          return { Success = false, Message = "已砍过价了" }
      end

      local isCorrect = (chosenOption == q.Correct) or (q.CorrectAlt and chosenOption == q.CorrectAlt)
      if not pendingBargains[uid] then pendingBargains[uid] = {} end
      if isCorrect then
          pendingBargains[uid][itemKey] = true
          return { Success = true, Message = "老板很开心！给你打 8 折！" }
      else
          pendingBargains[uid][itemKey] = false
          return { Success = false, Message = "老板不高兴，还是原价吧" }
      end
  end
  ```

- [ ] **Step 3: 手动测试砍价流程**

  1. 进入仙丹阁
  2. 点击某丹药的"砍价"按钮
  3. 确认出现砍价对话弹窗
  4. 选择一个选项
  5. 确认显示砍价结果（成功打折/原价）
  6. 选择打折后的丹药购买，确认价格正确

---

### Task 3: Bug 3 — 购买丹药后背包为空

**根因分析：** 服务端 `ShopService.server.lua:369-375` 的 `PurchaseResult` 响应中缺少 `Backpack` 字段，客户端 `ShopUI.local.lua:681-686` 的 `PurchaseResult:Shop` 事件处理器调用 `RefreshUI` 时也没有传入 `Backpack`，导致 `currentShopData.Backpack` 在购买后被覆盖为空，切换到背包标签时显示"背包空空如也"。

**Files:**
- Modify: `ServerScriptService/server/Systems/ShopService.server.lua`
- Modify: `StarterPlayer/StarterPlayerScripts/client/ShopUI.local.lua`

- [ ] **Step 1: 修复服务端 PurchaseResult 响应**

  在 `ShopService.server.lua:369-375`，在 `PurchaseResult` 中添加 `Backpack`：

  ```lua
  ShopEvent:FireClient(player, "PurchaseResult:Shop", {
      Success = result == "Success",
      Result = result,
      Message = message,
      XianJing = data and data.XianJing or 0,
      DailyPurchases = data and data.DailyPurchases or {},
      Backpack = data and data.Backpack or {},  -- 新增
  })
  ```

- [ ] **Step 2: 修复客户端 RefreshUI 调用**

  在 `ShopUI.local.lua:681-686`，在 `RefreshUI` 参数中添加 `Backpack`：

  ```lua
  elseif eventType == "PurchaseResult:Shop" then
      ShopUI:RefreshUI({
          Items = (currentShopData or {}).Items or {},
          DailyPurchases = data.DailyPurchases or {},
          XianJing = data.XianJing or 0,
          Backpack = data.Backpack or {},  -- 新增
      })
      ShopUI:ShowResult(data.Success, data)
  ```

- [ ] **Step 3: 验证**

  1. 进入仙丹阁，打开商店
  2. 购买一个丹药
  3. 切换到"背包"标签
  4. 确认购买的丹药出现在背包中
  5. 确认有"使用"按钮

---

### 自审检查

- [ ] **Bug 1 覆盖**: Task 1 覆盖了添柴计数健壮性、UI 定时器冲突、状态同步增强
- [ ] **Bug 2 覆盖**: Task 2 覆盖了客户端发送协议和服务端接收逻辑
- [ ] **Bug 3 覆盖**: Task 3 覆盖了服务端响应和客户端 UI 刷新
- [ ] **占位符检查**: 无 TBD/TODO 占位符，所有代码块完整
- [ ] **类型一致性**: 无跨任务类型/签名不匹配
