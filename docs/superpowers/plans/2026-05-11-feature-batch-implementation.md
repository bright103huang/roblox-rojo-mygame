# Feature Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 6 feature changes in batch: DeliverTask order timing, BeastNPC visual fix, Risk wired into Beast arena, Time system pressure, unified TaskNotice prompts, and 仙丹阁 re-pricing with 朦胧 unlock.

**Architecture:** All features are in existing Roblox 2D game — ModuleScripts loaded via `require()`, client UI via `Instance.new`, server logic in Script/ModuleScript files. Communication happens through `RemoteEvent` (TaskEvent and ShopEvent).

**Tech Stack:** Luau (Roblox), 2D横版 (Z-locked), SSS sync, `roblox-2d-game` skill covers conventions and gotchas.

---

### Task 1: Create TaskNotice — unified prompt/notification module

**Files:**
- Create: `ReplicatedStorage/Shared/UI/TaskNotice.lua`

- [ ] **Create TaskNotice.lua**

TaskNotice is a lightweight ModuleScript that creates a timed popup notification. It follows the existing AlchemyUI popup style (dark theme, UICorner, auto-dismiss).

```lua
-- ============================================================
-- 文件：ReplicatedStorage.Shared.UI.TaskNotice.lua
-- 功能：统一提示弹窗 — 轻量通知，3 秒自动消失
-- 被 TaskClient.local.luau 或其他客户端模块 require
-- ============================================================

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local TaskNotice = {}

function TaskNotice:Notify(config)
	config = config or {}
	local title = config.Title or "提示"
	local text = config.Text or ""
	local color = config.Color or Color3.fromRGB(255, 215, 0)
	local duration = config.Duration or 3

	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TaskNotice_" .. tick()
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 50
	screenGui.Parent = playerGui

	-- 背景框
	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.new(0, 320, 0, 80)
	bg.Position = UDim2.new(0.5, -160, 0.15, 0)
	bg.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
	bg.BackgroundTransparency = 0.15
	bg.BorderSizePixel = 0
	bg.Parent = screenGui

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 10)
	bgCorner.Parent = bg

	-- 标题
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -20, 0, 24)
	titleLabel.Position = UDim2.new(0, 10, 0, 6)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = color
	titleLabel.TextSize = 16
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Parent = bg

	-- 内容
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Text"
	textLabel.Size = UDim2.new(1, -20, 0, 40)
	textLabel.Position = UDim2.new(0, 10, 0, 32)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextSize = 14
	textLabel.Font = Enum.Font.SourceSans
	textLabel.TextWrapped = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Center
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.Parent = bg

	-- 自动消失
	task.delay(duration, function()
		if screenGui and screenGui.Parent then
			screenGui:Destroy()
		end
	end)
end

return TaskNotice
```

- [ ] **Commit Task 1**

```bash
git add ReplicatedStorage/Shared/UI/TaskNotice.lua
git commit -m "feat: add TaskNotice unified notification module"
```

---

### Task 2: DeliverTask — move order generation to Pick

**Files:**
- Modify: `ServerScriptService/Server/Tasks/DeliverTask.lua`

- [ ] **Move `assignOrder()` call from `OnPlayerDrop` to `OnPlayerPickup`**

Change `OnPlayerPickup`: after the existing carrying check and cost check pass (line 189), call `assignOrder()` to generate the target before creating the plate. The player picks up the plate and immediately sees the target indicator.

Change `OnPlayerDrop`: remove the `assignOrder()` call at line 263. The order was already generated at Pick time.

Detailed edits:

In `OnPlayerPickup`, insert after line 189 (`carrying[player.UserId] = true`):
```lua
		-- 生成订单目标（Pick 时分配，玩家取餐即看到目标）
		assignOrder()
```

In `OnPlayerDrop`, remove lines 260-264:
```lua
		-- 分配下一单 (moved to Pick)
		-- assignOrder()
```
Comment out or delete the call and its surrounding comment.

- [ ] **Commit Task 2**

```bash
git add ServerScriptService/Server/Tasks/DeliverTask.lua
git commit -m "fix: move order generation to Pick for immediate target visibility"
```

---

### Task 3: BeastNPC — fix buildAnimalShape CFrame offsets

**Files:**
- Modify: `ServerScriptService/Server/Systems/BeastNPC.lua` (lines 184-203, 441-474)

- [ ] **Fix `buildAnimalShape()` to set Part CFrame**

The bug: Parts are created with WeldConstraint but their CFrame is never set. All parts overlap at the root.

Fix: After creating each part and creating its weld, set the part's CFrame based on the root's CFrame offset by `partDef.Offset * animalDef.Scale`:

In the loop at line 185-203, after the weld creation (after line 203):
```lua
			-- Set part position relative to root (FIX: was missing)
			local partOffset = partDef.Offset * s
			part.CFrame = root.CFrame * CFrame.new(partOffset)
```

The weld will maintain this relative position.

- [ ] **Add `task.wait()` before collision animation steps**

The `CollisionAnimation` function (line 416) animates in a loop with `task.wait(0.05)`. This is fine. But the issue is that the charge animation might complete before the server's physics update. Add a small initial delay:

After line 428:
```lua
	task.wait(0.1)  -- Wait for physics to settle before charging
```

- [ ] **Commit Task 3**

```bash
git add ServerScriptService/Server/Systems/BeastNPC.lua
git commit -m "fix: BeastNPC buildAnimalShape part CFrame offset bug"
```

---

### Task 4: Wire Risk 妖气侵蚀 into BeastTask + BeastNPC

**Files:**
- Modify: `ServerScriptService/Server/Tasks/BeastTask.lua` (add Risk-based tier roll)
- Modify: `ServerScriptService/Server/Systems/BeastNPC.lua` (add Risk gain to SettleFight)

- [ ] **Modify `BeastTask.OnPlayerPickup` to roll tier using Risk**

After the existing Combat-based tier determination (line 52-53), add Risk-based roll:

```lua
		-- Risk 妖气侵蚀: 根据 Risk 概率提升妖兽等级
		local riskTierRoll = math.random()
		local risk = data and data.Risk or RiskConfig.InitialRisk
		-- 找到当前 Risk 对应的概率表
		local spawnChances = { EliteChance = 0, BossChance = 0, RampageChance = 0 }
		for threshold, chances in pairs(RiskConfig.SpawnModifiers) do
			if risk >= threshold then
				spawnChances = chances
			end
		end
		-- Roll: 暴走 → Boss → Elite → Normal
		if riskTierRoll < spawnChances.RampageChance then
			tier = "Boss"  -- 暴走以 Boss 形态出现，在结算时区分
		elseif riskTierRoll < spawnChances.RampageChance + spawnChances.BossChance then
			tier = "Boss"
		elseif riskTierRoll < spawnChances.RampageChance + spawnChances.BossChance + spawnChances.EliteChance then
			-- 只有 Risk 提升的等级比 Combat 高时才覆盖
			if tier ~= "Boss" then
				tier = "Elite"
			end
		end
```

Add `require` for RiskConfig at the top of BeastTask.lua:
```lua
local RiskConfig = require(ReplicatedStorage.Shared.Config.RiskConfig)
```

- [ ] **Modify `BeastNPC.SettleFight` to add Risk gain**

In the victory branch (line 511-517), add `Risk = RiskConfig.Accumulation[beast.Tier] or RiskConfig.Accumulation.NormalKill` to the costs table:

```lua
		-- 玩家胜利
		local mult = beast.Stats.RewardMult or 1
		local riskGain = 0
		if beast.Tier == "Boss" then
			riskGain = RiskConfig.Accumulation.BossKill
		elseif beast.Tier == "Elite" then
			riskGain = RiskConfig.Accumulation.EliteKill
		else
			riskGain = RiskConfig.Accumulation.NormalKill
		end
		StatusService:ApplyCosts(player, {
			Stamina = -8 * mult,
			Malice = 3 * mult,
			CombatExp = 8 * mult,
			XianJing = 20 * mult,
			Risk = riskGain,
		})
```

Add `require` at top of BeastNPC.lua:
```lua
local RiskConfig = require(ReplicatedStorage.Shared.Config.RiskConfig)
```

- [ ] **Commit Task 4**

```bash
git add ServerScriptService/Server/Tasks/BeastTask.lua ServerScriptService/Server/Systems/BeastNPC.lua
git commit -m "feat: wire Risk 妖气侵蚀 into Beast arena — risk-based tier and gain"
```

---

### Task 5: Time system — update modifiers + hourly notification

**Files:**
- Modify: `ReplicatedStorage/Shared/Config/StatsConfig.lua` (update TIME_MODIFIERS values)
- Modify: `ServerScriptService/Server/Systems/TimeService.lua` (add hour change event)

- [ ] **Update TIME_MODIFIERS in StatsConfig.lua**

Update the 4 time periods to match the approved design:

```lua
		TIME_MODIFIERS = {
			-- hourStart (inclusive), hourEnd (exclusive), taskEff, shopOpen, restEff, label
			{ 4, 12, 0.85, false, 0.8, "晨·旭日东升 — 工作效率最佳，炼丹+15%" },
			{ 12, 18, 1.0, true, 1.0, "昼·日正当空 — 效率正常，商店营业" },
			{ 18, 22, 1.2, true, 1.2, "暮·夕阳西下 — 效率下降，战斗+20%" },
			{ 22, 28, 1.4, false, 1.5, "夜·更深露重 — 工作困难，冥想+40%" },
		},
```

Edit the existing table:
- Change `0.87` → `0.85`
- Change `1.15` → `1.2`
- Change `1.3` → `1.4`
- Update label strings

- [ ] **Add hour change notification in TimeService.lua**

In the TimeService tick loop, detect when hour changes and fire a client event:

```lua
		-- Hour change notification
		local currentPeriod = nil
		for _, mod in ipairs(StatsConfig.TIME_MODIFIERS) do
			if currentHour >= mod[1] and currentHour < mod[2] then
				currentPeriod = mod[6]
				break
			end
		end
		if currentPeriod ~= lastHourLabel then
			lastHourLabel = currentPeriod
			-- Fire to all players
			for _, player in ipairs(Players:GetPlayers()) do
				local taskEvent = eventsFolder:FindFirstChild("TaskEvent")
				if taskEvent then
					taskEvent:FireClient(player, "HourChange", {
						Hour = currentHour,
						Label = currentPeriod or "",
					})
				end
			end
		end
```

Add `lastHourLabel` variable before the main loop:
```lua
local lastHourLabel = ""
```

- [ ] **Commit Task 5**

```bash
git add ReplicatedStorage/Shared/Config/StatsConfig.lua ServerScriptService/Server/Systems/TimeService.lua
git commit -m "feat: update time system modifiers and add hour change notifications"
```

---

### Task 6: 仙丹阁 — re-pricing and 朦胧 unlock mechanism

**Files:**
- Modify: `ReplicatedStorage/Shared/Config/DanConfig.lua` (re-price items, add RevealThreshold)
- Modify: `ServerScriptService/Server/Systems/DataManager.lua` (add RevealedShopItems field)
- Modify: `ServerScriptService/Server/Systems/ShopService.server.lua` (filter items by reveal status)
- Modify: `StarterPlayer/StarterPlayerScripts/Client/ShopUI.local.lua` (display ??? for hidden items)

- [ ] **Update DanConfig.lua with new prices and reveal threshold**

Replace the entire Items table:

```lua
local DanConfig = {
	Items = {
		HuiQiDan = {
			Name = "回气丹",
			Description = "恢复体力 20 点",
			Price = 20,
			EffectType = "Stamina",
			EffectValue = 20,
			DailyLimit = 0,
		},
		QingXinSan = {
			Name = "清心散",
			Description = "降低疲劳 15 点",
			Price = 35,
			EffectType = "Fatigue",
			EffectValue = -15,
			DailyLimit = 0,
		},
		JuShenDan = {
			Name = "聚神丹",
			Description = "恢复精神 15 点",
			Price = 40,
			EffectType = "Spirit",
			EffectValue = 15,
			DailyLimit = 0,
		},
		YuLingDan = {
			Name = "玉灵丹",
			Description = "化解火毒 20 点",
			Price = 80,
			EffectType = "FirePoison",
			EffectValue = -20,
			DailyLimit = 0,
		},
		XiuWeiXiaoDan = {
			Name = "???",
			Description = "???",
			Price = 200,
			EffectType = "AgilityExp",  -- Placeholder, actual effect random
			EffectValue = 0,
			DailyLimit = 0,
			RevealThreshold = 200,
			RealName = "凝气丹",
			RealDescription = "身法/火候/仙力随机一项 +1",
			RealEffectType = "RandomStat",
			RealEffectValue = 1,
		},
		XiuWeiDaDan = {
			Name = "???",
			Description = "???",
			Price = 500,
			EffectType = "AgilityExp",
			EffectValue = 0,
			DailyLimit = 0,
			RevealThreshold = 500,
			RealName = "混元丹",
			RealDescription = "身法/火候/仙力 全部 +1",
			RealEffectType = "AllStats",
			RealEffectValue = 1,
		},
	},
	ResetInterval = 720,
}
return DanConfig
```

- [ ] **Add RevealedShopItems to DataManager DEFAULT_DATA**

Add to the DEFAULT_DATA table (line 27-68), after `LastPrayerDate`:

```lua
	RevealedShopItems = {},  -- 已解锁的朦胧丹药 { "XiuWeiXiaoDan" = true, ... }
```

- [ ] **Modify ShopService.server.lua to handle reveal logic**

In the `Pick:Shop` handler (line 140-173), before sending items, check and update revealed items:

```lua
		-- 朦胧机制：检查并更新已解锁的丹药
		if not data.RevealedShopItems then
			data.RevealedShopItems = {}
		end
		local revealed = data.RevealedShopItems

		-- 发送商品列表和已购数据到客户端
		local items = {}
		for key, cfg in pairs(DanConfig.Items) do
			-- 检查是否需要解锁
			local showReal = true
			if cfg.RevealThreshold and cfg.RevealThreshold > 0 then
				if not revealed[key] then
					-- 仙晶足够则永久解锁
					if (data.XianJing or 0) >= cfg.RevealThreshold then
						revealed[key] = true
						DataManager:UpdateField(player, "RevealedShopItems", revealed)
					else
						showReal = false
					end
				end
			end

			if showReal then
				items[key] = {
					Name = cfg.RealName or cfg.Name,
					Description = cfg.RealDescription or cfg.Description,
					Price = cfg.Price,
					EffectType = cfg.RealEffectType or cfg.EffectType,
					EffectValue = cfg.RealEffectValue or cfg.EffectValue,
					DailyLimit = cfg.DailyLimit,
				}
			else
				items[key] = {
					Name = cfg.Name,      -- "???"
					Description = cfg.Description,  -- "???"
					Price = cfg.Price,
					EffectType = cfg.EffectType,
					EffectValue = cfg.EffectValue,
					DailyLimit = cfg.DailyLimit,
					IsHidden = true,
				}
			end
		end
```

Replace the existing items loop (lines 157-166) with this logic.

- [ ] **Modify ShopUI.local.lua to display hidden items**

In the item slot creation loop (line 157-293), add handling for `IsHidden` items:

After setting `nameLabel.Text` (line 181), if `item.IsHidden`:
```lua
			if item.IsHidden then
				nameLabel.TextColor3 = COLORS.DarkGray
			end
```

After setting `descLabel.Text` (line 193), if `item.IsHidden`:
```lua
			if item.IsHidden then
				descLabel.Text = "仙晶达到 " .. tostring(item.Price) .. " 后揭晓"
				descLabel.TextColor3 = COLORS.DarkGray
			end
```

For the buy button on hidden items, disable it:
```lua
			if item.IsHidden then
				buyBtn.Text = "???"
				buyBtn.BackgroundColor3 = COLORS.DarkGray
				buyBtn.Active = false
			end
```

- [ ] **Add RandomStat and AllStats effect handling in ShopService.server.lua**

In the `Purchase` function, add handlers for the new effect types. After the existing `elseif effectType == "CombatExp"` block (line 129):

```lua
		elseif effectType == "RandomStat" then
			local stats = { "Agility", "AlchemyLv", "Combat" }
			local chosen = stats[math.random(1, #stats)]
			StatusService:AddExp(player, chosen, effectValue)
			-- Override the default message with which stat was boosted
			local nameMap = { Agility = "身法", AlchemyLv = "火候", Combat = "仙力" }
			local resultMsg = "购买成功！" .. (nameMap[chosen] or chosen) .. " +1"
			return "Success", resultMsg

		elseif effectType == "AllStats" then
			StatusService:AddExp(player, "Agility", effectValue)
			StatusService:AddExp(player, "AlchemyLv", effectValue)
			StatusService:AddExp(player, "Combat", effectValue)
			return "Success", "购买成功！全属性 +1"
```

- [ ] **Commit Task 6**

```bash
git add ReplicatedStorage/Shared/Config/DanConfig.lua \
       ServerScriptService/Server/Systems/DataManager.lua \
       ServerScriptService/Server/Systems/ShopService.server.lua \
       StarterPlayer/StarterPlayerScripts/Client/ShopUI.local.lua
git commit -m "feat: DanShop re-pricing, 朦胧 unlock, random stat pills"
```

---

### Task 7: Integrate TaskNotice into TaskClient for all events

**Files:**
- Modify: `StarterPlayer/StarterPlayerScripts/Client/TaskClient.local.luau`

- [ ] **Add TaskNotice require at top of TaskClient**

After the existing requires (line 11):
```lua
local TaskNotice = require(script.Parent.Parent.Shared.UI.TaskNotice)
```

Wait — TaskClient is in `StarterPlayerScripts/Client/` and TaskNotice is in `ReplicatedStorage/Shared/UI/`. The require path needs to reach ReplicatedStorage. In Roblox, `script.Parent.Parent` from `Client/TaskClient.local.luau` would be `StarterPlayerScripts`, which isn't right.

Looking at the file structure more carefully:
- TaskClient is at: `StarterPlayer/StarterPlayerScripts/Client/TaskClient.local.luau`
- TaskNotice will be at: `ReplicatedStorage/Shared/UI/TaskNotice.lua`

The correct path would be `game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("TaskNotice")`. Let me use the FindFirstChild pattern as recommended in the `roblox-2d-game` skill:

```lua
local function loadTaskNotice()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	if not shared then return nil end
	local ui = shared:FindFirstChild("UI")
	if not ui then return nil end
	local module = ui:FindFirstChild("TaskNotice")
	if module then
		return require(module)
	end
	return nil
end

local TaskNotice = loadTaskNotice()
```

- [ ] **Add notifications after each relevant event handler**

In the `TaskEvent.OnClientEvent` handler, add TaskNotice calls:

After `BeastFightStart` (line 269-272):
```lua
		if TaskNotice then
			TaskNotice:Notify({
				Title = "角斗场",
				Text = tostring(extraData and extraData.AnimalName or "妖兽") .. " 出现了！准备战斗",
				Color = Color3.fromRGB(255, 60, 60),
			})
		end
```

After `BeastCollision` (line 274-277):
```lua
		if TaskNotice then
			TaskNotice:Notify({
				Title = "碰撞",
				Text = "第 " .. tostring(extraData and extraData.Round or "?") .. " 轮碰撞！",
				Color = Color3.fromRGB(255, 200, 60),
				Duration = 1.5,
			})
		end
```

After `BeastVictory` (line 279-283):
```lua
		if TaskNotice then
			TaskNotice:Notify({
				Title = "胜利",
				Text = tostring(extraData and extraData.Message or "击败妖兽！"),
				Color = Color3.fromRGB(80, 200, 80),
			})
		end
```

After `BeastLost` (line 285-289):
```lua
		if TaskNotice then
			TaskNotice:Notify({
				Title = "败北",
				Text = tostring(extraData and extraData.Message or "妖兽太强！"),
				Color = Color3.fromRGB(180, 40, 40),
			})
		end
```

After `DropSuccess` (line 308-319), inside the block:
```lua
		if TaskNotice then
			TaskNotice:Notify({
				Title = "传菜",
				Text = "送餐完成！仙晶 +" .. (result and tostring(result.XianJing) or "10"),
				Color = Color3.fromRGB(255, 215, 0),
			})
		end
```

After `LevelUp` (line 334-337):
```lua
		if TaskNotice then
			local nameMap = { Agility = "身法", AlchemyLv = "火候", Combat = "仙力" }
			TaskNotice:Notify({
				Title = "升级",
				Text = (nameMap[taskName] or taskName) .. " 提升至 Lv." .. tostring(result),
				Color = Color3.fromRGB(80, 200, 255),
			})
		end
```

Add a handler for `HourChange` — add a new condition before the old-format check (line 291):
```lua
		if result == "HourChange" then
			if TaskNotice then
				local label = extraData and extraData.Label or ""
				TaskNotice:Notify({
					Title = label,
					Text = "",
					Color = Color3.fromRGB(200, 180, 255),
					Duration = 2.5,
				})
			end
			return
		end
```

- [ ] **Commit Task 7**

```bash
git add StarterPlayer/StarterPlayerScripts/Client/TaskClient.local.luau
git commit -m "feat: integrate TaskNotice notifications into all task events"
```

---

### Self-Review Checklist

**Spec coverage:**
1. ✅ DeliverTask order timing → Task 2
2. ✅ Beast visual fix (buildAnimalShape CFrame) → Task 3
3. ✅ Beast 3-charge fight (already works, just needs CFrame fix) → Task 3
4. ✅ Risk 妖气侵蚀 → Task 4 (wired into existing RiskConfig)
5. ✅ Time system pressure → Task 5 (modifiers already work in GetTaskCosts, added notification)
6. ✅ Unified prompt → Task 1 + Task 7
7. ✅ 仙丹阁 re-pricing + 朦胧 → Task 6

**Placeholder scan:** All steps have complete code. No TBD/TODO/placeholder patterns found.

**Type consistency:** EffectType "RandomStat" and "AllStats" used consistently across DanConfig, ShopService handler, and ShopUI display. RevealedShopItems referenced consistently between DataManager and ShopService.
