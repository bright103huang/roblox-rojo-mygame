# 场景边缘虚空修复 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Alchemy、Beast、DanShop 三个场景添加不可见碰撞墙，防止角色走出地板边缘掉入虚空

**Architecture:** 在 `SceneSetup.server.lua` 中添加 `createInvisibleWall` 辅助函数，然后在每个问题场景的地板左右边缘各安装一道透明碰撞墙。利用 Lock2D 锁定 Z=0 的机制，只需处理 X 方向边界。

**Tech Stack:** Roblox Luau (Script)

**影响文件：** 只改 `ServerScriptService/server/Systems/SceneSetup.server.lua`

---

### Task 1: 添加 createInvisibleWall 辅助函数

**Files:**
- Modify: `ServerScriptService/server/Systems/SceneSetup.server.lua:52-63`

在现有的 `createWall` 函数之后（约第 63 行）插入一个通用透明碰撞墙函数，供所有场景复用。

- [ ] **Step 1: 插入 createInvisibleWall 函数**

在 `createWall` 函数之后（第 63 行 end 之后）添加：

```lua
local function createInvisibleWall(position, sizeX, sizeY, sizeZ)
	local part = Instance.new("Part")
	part.Name = "EdgeWall"
	part.Size = Vector3.new(sizeX, sizeY, sizeZ)
	part.Position = position
	part.Anchored = true
	part.CanCollide = true
	part.Transparency = 1
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = workspace
	return part
end
```

---

### Task 2: 修复 Alchemy 场景（左右边缘墙）

**Files:**
- Modify: `ServerScriptService/server/Systems/SceneSetup.server.lua:264-410`

Alchemy 场景的地板尺寸 50×8（X 从 975 到 1025，Z 从 -4 到 4）。在左右地板边缘外侧各加一道不可见墙。

- [ ] **Step 1: 在 setupAlchemyScene() 返回前添加左右边缘墙**

在 `setupAlchemyScene` 函数末尾，`print("⚗️ 炼丹洞天已就绪..."` 之前（第 408 行前）插入：

```lua
	-- 不可见边缘碰撞墙（防止走出地板掉入虚空）
	createInvisibleWall(origin + Vector3.new(-25, 2, 0), 0.3, 8, 8)   -- 左墙，X=-25
	createInvisibleWall(origin + Vector3.new(25, 2, 0), 0.3, 8, 8)    -- 右墙，X=25
```

墙的 Z 尺寸取 8（覆盖地板全宽 Z=-4 到 4），高 8 确保角色无法跳过。

---

### Task 3: 修复 DanShop 场景（左右边缘墙）

**Files:**
- Modify: `ServerScriptService/server/Systems/SceneSetup.server.lua:574-698`

DanShop 场景地板尺寸 80×8（X 从 -1040 到 -960，Z 从 -4 到 4）。

- [ ] **Step 1: 在 setupShopScene() 返回前添加左右边缘墙**

在 `setupShopScene` 末尾，`print("💎 仙丹阁已就绪..."` 之前（第 697 行前）插入：

```lua
	-- 不可见边缘碰撞墙（防止走出地板掉入虚空）
	createInvisibleWall(origin + Vector3.new(-40, 2, 0), 0.3, 8, 8)   -- 左墙，X=-40
	createInvisibleWall(origin + Vector3.new(40, 2, 0), 0.3, 8, 8)    -- 右墙，X=40
```

---

### Task 4: 修复 Beast 场景（调整现有边缘墙位置）

**Files:**
- Modify: `ServerScriptService/server/Systems/SceneSetup.server.lua:528-541`

Beast 场景地板尺寸 140×12（X 从 1930 到 2070，Z 从 -6 到 6）。现有边缘墙在 X=±64（中心偏移），但地板延伸到 ±70，墙在板内导致边缘仍有空隙。

- [ ] **Step 1: 替换现有边缘墙为正确位置**

将第 529-541 行的左右边缘墙代码替换为：

```lua
	-- 不可见边缘碰撞墙（防止走出地板掉入虚空）
	createInvisibleWall(origin + Vector3.new(-70, 2, 0), 0.3, 8, 12)   -- 左墙，地板边缘 X=-70
	createInvisibleWall(origin + Vector3.new(70, 2, 0), 0.3, 8, 12)    -- 右墙，地板边缘 X=70
```

注意 Z 尺寸取 12（匹配 Beast 地板 Z 范围 -6 到 6），比 Alchemy/DanShop 的 8 更宽。

---

### Task 5: 验证

- [ ] **Step 1: 手动验证**

改动只能在 Roblox Studio 中验证：
1. 打开 Roblox Studio，运行游戏
2. 依次传送至炼丹洞天、仙丹阁、妖兽战场
3. 在每个场景中走向左右边缘
4. 确认角色被不可见墙挡住，不会掉入虚空
5. 确认传菜和家两个场景未被影响，功能正常

- [ ] **Step 2: 提交**

```bash
git add ServerScriptService/server/Systems/SceneSetup.server.lua
git commit -m "fix: add invisible edge walls to prevent void fall in Alchemy, Beast, DanShop"
```
