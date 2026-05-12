# 统一场景地基 + 统一引导提示牌 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 所有场景角色不会掉入虚空 + 全场景统一使用炼丹风格的 3D 漂浮编号提示牌（吐槽风文案）

**Architecture:** 在 SceneSetup.server.lua 中新增 `createUnderFloor()` 函数给每个场景铺地基；用 `createHintBoard()` 为每个场景添加编号提示牌；废弃客户端 TutorialHint.local.luau

**Tech Stack:** Luau, Roblox Part/BillboardGui, SceneSetup.server.lua

---

## 文件结构

| 文件 | 操作 | 职责 |
|------|------|------|
| `ServerScriptService/server/Systems/SceneSetup.server.lua` | 修改 | 新增 `createUnderFloor` 函数 + 5 场景地基 + 5 场景提示牌 |
| `StarterPlayer/StarterPlayerScripts/client/TutorialHint.local.luau` | 修改 | 文件开头加 `return nil` 禁用 |

---

### Task 1: 新增 createUnderFloor 辅助函数

**Files:**
- Modify: `ServerScriptService/server/Systems/SceneSetup.server.lua:91`（在 createArea 函数之后，createHintBoard 之前）

- [ ] **Step 1: 在 createArea 闭包之后插入 createUnderFloor 函数**

```lua
-- ============================================================
-- 工具：创建地下地基（防止角色掉入虚空）
-- ============================================================
local function createUnderFloor(position, spanX, spanZ)
	local part = Instance.new("Part")
	part.Name = "UnderFloor"
	part.Size = Vector3.new(spanX, 0.5, spanZ)
	part.Position = position + Vector3.new(0, -1.5, 0)
	part.Anchored = true
	part.CanCollide = true
	part.Transparency = 0.95
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = workspace
end
```

找到 `createArea` 函数的结尾（`end`，约第 138 行），在之后、`createHintBoard`（约第 143 行）之前插入。

- [ ] **Step 2: 提交**

```bash
git add ServerScriptService/server/Systems/SceneSetup.server.lua
git commit -m "feat: add createUnderFloor helper for void protection"
```

---

### Task 2–6: 为 5 个场景添加地下地基

每个场景只需在 `createFloor()` 调用之后追加一行 `createUnderFloor()`。

**Files:**
- Modify: `ServerScriptService/server/Systems/SceneSetup.server.lua`

**共用改动模式：** 在 `createFloor()` 调用之后追加：
```lua
createUnderFloor(origin + Vector3.new(0, -0.5, 0), 500, 40)
```

#### Task 2: 御膳房地基

- [ ] **Step 1: 在 setupYiShanFangScene 中追加**

找到 `setupYiShanFangScene()` 函数第 183 行 `createFloor(...)`，在其后追加：
```lua
	createUnderFloor(origin + Vector3.new(0, -0.5, 0), 500, 40)
```

#### Task 3: 炼丹地基

- [ ] **Step 1: 在 setupAlchemyScene 中追加**

找到 `setupAlchemyScene()` 第 238 行 `createFloor(...)`，在其后追加：
```lua
	createUnderFloor(origin + Vector3.new(0, -0.5, 0), 500, 40)
```

#### Task 4: 妖兽战场地基

- [ ] **Step 1: 在 setupBeastScene 中追加**

找到 `setupBeastScene()` 第 391 行 `createFloor(...)`，在其后追加：
```lua
	createUnderFloor(origin + Vector3.new(0, -0.5, 0), 500, 40)
```

#### Task 5: 仙丹阁地基

- [ ] **Step 1: 在 setupShopScene 中追加**

找到 `setupShopScene()` 第 546 行 `createFloor(...)`，在其后追加：
```lua
	createUnderFloor(origin + Vector3.new(0, -0.5, 0), 500, 40)
```

#### Task 6: 家地基

- [ ] **Step 1: 在 setupHomeScene 中追加**

找到 `setupHomeScene()` 第 588 行 `createFloor(...)`，在其后追加：
```lua
	createUnderFloor(origin + Vector3.new(0, -0.5, 0), 500, 40)
```

- [ ] **Step 2: 提交 Task 2-6**

```bash
git add ServerScriptService/server/Systems/SceneSetup.server.lua
git commit -m "feat: add underfloor to all 5 scenes to prevent void fall"
```

---

### Task 7: 废弃 TutorialHint.local.luau

**Files:**
- Modify: `StarterPlayer/StarterPlayerScripts/client/TutorialHint.local.luau`

- [ ] **Step 1: 文件开头加 return nil**

在文件第 1 行后（`-- =====` 注释后）、所有代码之前插入：
```lua
return nil
-- 已废弃：引导提示牌已改用 SceneSetup 中的 createHintBoard 3D 漂浮牌
```

- [ ] **Step 2: 提交**

```bash
git add StarterPlayer/StarterPlayerScripts/client/TutorialHint.local.luau
git commit -m "fix: disable TutorialHint panel, replaced by in-world hint boards"
```

---

### Task 8–12: 为 5 个场景添加吐槽风提示牌

所有提示牌使用已有 `createHintBoard(position, text, color)` 函数。

**提示牌风格统一（照搬炼丹现有样式）：**
- Part: Transparency=0.8, Size=(6,0.5,0.5), CanCollide=false
- BillboardGui: Size=(300,60), StudsOffset=(0,3,0), AlwaysOnTop=true
- TextLabel: TextSize=18, Font=SourceSansBold, TextColor3=(1,1,0.8), TextStroke
- 编号格式 + 吐槽风中文文案

注意：`createHintBoard` 的第三个参数 `color` 只影响 Part 的背景色，文字始终是米黄色（1,1,0.8）。

#### Task 8: 御膳房提示牌

**Files:**
- Modify: `ServerScriptService/server/Systems/SceneSetup.server.lua`

- [ ] **Step 1: 在 setupYiShanFangScene 末尾（print 之前）追加**

找到第 227 行附近的 `print("🍽️ 御膳房已就绪...")`，在其之前插入：
```lua

	-- ============================================================
	-- 场景引导提示（吐槽风）
	-- ============================================================
	createHintBoard(
		origin + Vector3.new(-80, 4, 0),
		"① 左边取桃→右边送——送错桌明天喂妖兽",
		BrickColor.new("Bright yellow")
	)
	createHintBoard(
		origin + Vector3.new(0, 4, 0),
		"② 跟着 ⭐ 走，别问为什么，问就是编制",
		BrickColor.new("Bright red")
	)
	createHintBoard(
		origin + Vector3.new(50, 4, 0),
		"③ 送到即结算——干得好加鸡腿，干不好……你懂的",
		BrickColor.new("Bright green")
	)
```

#### Task 9: 炼丹提示牌（原提示改为吐槽风）

**Files:**
- Modify: `ServerScriptService/server/Systems/SceneSetup.server.lua`

- [ ] **Step 1: 替换 setupAlchemyScene 中原有提示牌文字**

找到第 311-336 行（4 个 createHintBoard 调用），将 text 参数替换：

将第 313 行 `"① 取药材"` 改为：
```lua
		"① 灵草台薅羊毛——药材随便拿不要钱",
```

将第 320 行 `"② 取柴火"` 改为：
```lua
		"② 柴火堆搬砖——点火就靠你了",
```

将第 327 行 `"③ 添柴 ×3 → 成丹"` 改为：
```lua
		"③ 添柴×3 赌一把——成丹血赚，炸炉不亏",
```

将第 334 行 `"← 灵草  丹炉 →\n柴火堆"` 改为：
```lua
		"← 薅药材  炉子 →\n搬柴火",
```

#### Task 10: 妖兽战场提示牌（原提示改为吐槽风）

**Files:**
- Modify: `ServerScriptService/server/Systems/SceneSetup.server.lua`

- [ ] **Step 1: 替换 setupBeastScene 中提示牌文字**

找到第 526-534 行（3 个 createHintBoard 调用），替换 text 参数：

第 526-528 行：
```lua
	createHintBoard(origin + Vector3.new(0, 6, 0),
		"① 踏入中央红区→召唤妖兽，跑都跑不掉",
		BrickColor.new("Really red"))
```

第 529-531 行：
```lua
	createHintBoard(origin + Vector3.new(-28, 5, 0),
		"② 走近妖兽→自动碰瓷，连撞三次定胜负",
		BrickColor.new("Bright blue"))
```

第 532-534 行：
```lua
	createHintBoard(origin + Vector3.new(28, 5, 0),
		"③ 打不过就跑，30秒后妖兽自己下班",
		BrickColor.new("Bright green"))
```

#### Task 11: 仙丹阁提示牌（新增）

**Files:**
- Modify: `ServerScriptService/server/Systems/SceneSetup.server.lua`

- [ ] **Step 1: 在 setupShopScene 末尾（print 之前）追加**

找到第 578 行 `print("💎 仙丹阁已就绪")`，在其之前插入：
```lua

	-- ============================================================
	-- 场景引导提示
	-- ============================================================
	createHintBoard(
		origin + Vector3.new(0, 4, 0),
		"① 看柜台——好货都在上面，仙晶带够了吗",
		BrickColor.new("Bright violet")
	)
	createHintBoard(
		origin + Vector3.new(0, 2.5, 0),
		"② 仙晶不够？传送去打工啊，还愣着干啥",
		BrickColor.new("Bright yellow")
	)
```

#### Task 12: 家提示牌（新增）

**Files:**
- Modify: `ServerScriptService/server/Systems/SceneSetup.server.lua`

- [ ] **Step 1: 在 setupHomeScene 末尾（print 之前）追加**

找到第 610 行附近的 `print("🏠 家已就绪")`（约第 670 行附近，需要确认具体行号），在其之前插入：
```lua

	-- ============================================================
	-- 场景引导提示
	-- ============================================================
	createHintBoard(
		origin + Vector3.new(0, 4, 0),
		"① 蒲团上坐好——冥想回血回蓝一条龙",
		BrickColor.new("Gold")
	)
	createHintBoard(
		origin + Vector3.new(0, 2.5, 0),
		"② 戾气太重坐不住？先去干点好事再来",
		BrickColor.new("Bright orange")
	)
```

- [ ] **Step 2: 提交 Task 8-12**

```bash
git add ServerScriptService/server/Systems/SceneSetup.server.lua
git commit -m "feat: unify all scene hint boards to alchemy-style with humorous text"
```

---

## 验证

### 地基验证（手动）
1. 在 Studio 运行游戏
2. 逐个传送到每个场景（炼丹/妖兽/仙丹阁/家）
3. 角色跑出地板左右两侧，确认脚下有地面不继续下落
4. 御膳房原有行为不变

### 提示牌验证（手动）
1. 逐个传送每个场景
2. 每个场景看到 3D 漂浮编号提示牌，风格一致（字体/大小/位置）
3. 文案吐槽风，读得懂该干什么
4. 右下角不再出现 TutorialHint 黑色面板

### 回归验证
- 传菜流程：取餐 → 送餐 → 结算，正常
- 炼丹流程：取药材 → 取柴火 → 炼制，正常
- 妖兽流程：触发战斗 → 碰撞 → 结算，正常
- 场景切换：每个场景传送正常

---

## 自审

- [x] Spec 覆盖：地基覆盖 5 场景，提示牌覆盖 5 场景
- [x] 无占位符：所有代码块包含完整内容
- [x] 类型一致：所有函数调用使用已有 `createUnderFloor(position, 500, 40)` 和 `createHintBoard(pos, text, color)` 签名
