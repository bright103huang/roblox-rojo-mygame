# MyGame 项目架构指南

## 项目概况

- **同步方式**：Roblox Studio SSS（文件直连，不使用 Rojo）
- **文件命名**：客户端脚本使用 `.local.lua` 后缀（RunContext = Legacy）；被 `require` 的 UI 模块使用 `.lua` 后缀（ModuleScript）
- **语言**：Luau（部分文件使用 `.luau` 扩展名）
- **场景**：多场景沙盒，通过场景选择面板切换（无物理传送阵）

---

## 协作模式：你 ↔ 我 ↔ 仙官司

> **你提想法，我来调度，给你结果。**
> 你不需要记哪个 agent 做什么、谁先谁后、怎么调——交给我协调。

### 标准协作流水线

```
你: "我想加一个新功能 / 修一个 Bug / 改一个系统"
  │
  ▼
我（总接口）
  │  ① 先调 skills（查已有→find-skills→加载）
  │  ② 判断范围，调度子代理
  │
  ├─▶ 灵感司 — 大型新功能需求设计（需要时）
  ├─▶ 执行司 — 一次性完成 Config+服务端+客户端改动
  ├─▶ 查察司 — 代码审查与一致性检查
  └─▶ 诊察司 — Bug 定位与修复（需要时）
  │
  ▼
你: 收到可用成果
```

### 具体走法

1. **你告诉我想法** — "加个钓鱼玩法"、"修这个 Bug"、"数值要调整"
2. **我来判断调度** — 分析范围，决定调哪个司、按什么顺序、能不能并行
3. **中间问你** — 需要你做决策时才问你（选方案、定数值、确认样式）
4. **交付成果** — 代码改好、提交完成、告诉你做了什么

---

## 三步工作法（Skills 调用铁律）

> **做任何事前必须先走完三步：①查已有 skills → ②不够就 find-skills → ③带上再工作。**

这是我（主代理）和所有子代理都必须遵守的纪律，不是可选项。

### 主代理三步走

每次接到任务后、动手前：

1. **查 skills 列表** — 扫描当前会话中的 skills 列表，选出所有可能相关的 skill
2. **没有合适的？调 `find-skills`** — 如果现有 skills 没有覆盖当前任务的，先调 `find-skills` 搜索安装
3. **加载 skill 再开工** — 调 Skill tool 加载选中的技能，然后才开始干活（读代码、问问题、设计方案都不算"干活"）

### 派发子代理时的要求

在 sub-agent 的 prompt 末尾必须加上：

> 开始工作前，请先调用以下 skill(s)：[skill1], [skill2]

### 仙官司对应的必选 skills

| 司 | 必调 skills |
|---|-----------|
| 灵感司 | `brainstorming` |
| 执行司 | `roblox-game-development` |
| 查察司 | `systematic-debugging` + `roblox-game-development` |
| 诊察司 | `systematic-debugging` + `roblox-game-development` |

---

## 仙官司体系（AI 子代理）

### 四司精简架构

| 仙官司 | Agent ID | 触发条件 | 职责 |
|--------|----------|---------|------|
| 灵感司 | `inspiration` | 大型新功能 | 需求探讨、方案设计、输出设计文档 |
| 执行司 | `executor` | 日常功能开发 | 一次性完成 Config + 服务端逻辑 + 客户端 UI |
| 查察司 | `qa-inspector` | 每次改动后 | 代码审查、架构一致性、质量把关 |
| 诊察司 | `diagnostician` | Bug 修复 | 系统化定位、根因分析、修复验证 |

### 我做主（不派子代理）

以下工作我直接做，不需要子代理 handoff：

- **日常改 Config**（StatsConfig、TaskConfig 等微调）
- **修简单 Bug**（单文件、逻辑明确的）
- **架构决策**（项目方向、模块划分）
- **审阅设计文档**（灵感司产出我来审核）
- **git 提交**（版本管理）

### 各司职责

各司被调度时，必须遵守"三步工作法"（查 skills → find-skills → 加载再开工），并在子代理 prompt 末尾注明需要调用的 skills。

**灵感司** — 动工前的第一步（调 `brainstorming` skill）
- 与你探讨需求，一次只问一个问题
- 提出 2-3 种方案并推荐
- 输出设计文档到 `docs/designs/`
- 不写代码，只出方案
- 终点：设计文档获批

**执行司** — 合并原数据/任务/界面三司（调 `roblox-game-development` skill）
- 改 Config：StatsConfig、TaskConfig、EconomyConfig、DataManager 字段
- 写服务端：Task Handler 处理器（OnPlayerPickup/Drop/Craft/Attack）
- 写客户端：纯 Luau UI（Instance.new，无 Roact）
- 一次性完成，不拆分 handoff
- 注意文件后缀规则：`.local.lua` / `.lua` / `.server.lua`

**查察司** — 质量门（调 `roblox-game-development` + `systematic-debugging` skill）
- 文件后缀与 RunContext 检查
- `.` vs `:` 调用约定检查
- 跨文件引用一致性（RewardType、HandlerModule 路径等）
- DataManager 字段完整性
- 循环依赖检查

**诊察司** — Bug 猎人（调 `systematic-debugging` + `roblox-game-development` skill）
- 四阶段工作法：根因调查 → 模式分析 → 假设验证 → 修复
- 不找到根因不准提修复方案
- 连续 3 次假设失败 → 重新审视架构

### 标准调度流程

每一步启动 sub-agent 前，我都按"三步工作法"在 prompt 中指定该司需要加载的 skills。

```
日常小改动: 我直接改（走三步工作法）→ 查察司审查
中型功能:   执行司实现（加载 roblox-game-development）→ 查察司审查
大型功能:   灵感司设计（加载 brainstorming）→ 我审阅 → 执行司实现 → 查察司审查
Bug修复:    诊察司定位（加载 systematic-debugging + roblox-game-development）→ 执行司修复（或我直接修）→ 诊察司验证
```

---

## 2D 横版游戏设计

### 核心约束
- **摄像机**：固定在角色上方偏后 `CFrame.new(root.Position + Vector3.new(0, 10, 30), root.Position)`
- **Z 轴锁定**：角色 `HumanoidRootPart.Position.Z` 每帧被强制设为 0（由 Lock2D 脚本执行）
- **移动**：角色只能在 X 轴左右移动 + Y 轴跳跃，Z 轴始终为 0
- **交互区域**：所有任务交互区域（DishArea、TableArea、BeastSpawn 等）必须位于 Z=0 才能被角色触摸
- **场景装修**：装饰元素分两层 — 后层 Z=-4，前层 Z=4，角色在 Z=0 的路径上行走
- **NPC（妖兽）**：同样锁定 Z=0，AI 移动仅在 X 轴（`Vector3.new(direction.X * speed * 0.1, 0, 0)`）

### 场景布局原则
所有场景以 2D 横版方式布置：
1. 地面平面在 Z 轴宽 8（从 -4 到 4），角色在 Z=0 线上移动
2. 交互区域（可与角色碰撞的 Part）固定在 Z=0
3. 装饰/背景在 Z=-4（后层）和 Z=4（前层），可碰撞关闭
4. X 轴范围因场景而异（御膳房最宽，约 140 格）

---

## 任务处理器（Task Handler）架构

### 概述

打工任务系统采用 **Task Handler 模式**，将每种任务封装为独立的处理器模块，通过统一的调度器路由交互事件。现已实现 3 个核心任务 + 考编后的巡逻/驱猴任务，并有一套完整的因果数值系统支撑。

### 架构图

```
Client (TaskClient.local.luau)
  │  FireServer("Pick:Deliver", ...)
  │  FireServer("Drop:Deliver", ...)
  │  FireServer("Pick:Alchemy", ...)
  │  FireServer("Drop:Alchemy", ...)   → 触发 UI 弹窗
  │  FireServer("Craft:Alchemy", ...)  → 客户端 UI 触发
  │  FireServer("Pick:Beast", ...)
  │  FireServer("Attack:Beast", ...)   → 触摸妖兽攻击
  ▼
TaskService (调度器)
  │  根据 action 中的任务名路由到对应处理器
  │  支持 actionType: Pick / Drop / Craft / Attack
  ├─▶ DeliverTask.lua     ← 传菜任务
  ├─▶ AlchemyTask.lua     ← 炼丹任务
  ├─▶ BeastTask.lua       ← 妖兽战场
  ├─▶ PatrolTask.lua      ← 蟠桃园巡逻（需考编后）
  └─▶ ExpelMonkeyTask.lua ← 驱猴（需考编后）

支持的交互动作:
  Pick   → handler.OnPlayerPickup(player, area)
  Drop   → handler.OnPlayerDrop(player, area)
  Craft  → handler.OnCraft(player, contextData)    -- 炼丹专用
  Attack → handler.OnAttack(player, contextData)    -- 妖兽专用
```

### 核心引擎系统

```
StatusService (状态引擎)
  ├─ 定时恢复（每 5s Stamina/Spirit +1）
  ├─ CanPerformTask(player, costs) → 检查能否执行任务
  ├─ ApplyCosts(player, costsTable) → 批量扣除/增加状态
  ├─ AddExp(player, attrField, amount) → 增加经验，自动升级
  └─ CheckRedLines(player) → 红线惩罚（火毒DoT等）

SpeedCalculator (速度计算器)
  └─ Calculate/Apply: (16 + Agility×0.5) × StatusModifier

TimeService (时间系统)
  └─ 12 分钟一天，时辰推进，午夜疲劳结算

BeastNPC (妖兽 AI)
  └─ 巡逻/追击/攻击/血条管理

ShopService (仙丹阁)
  └─ 每日限购、库存管理

ExamService (考编系统)
  └─ 考编指数计算、门槛检查、晋升处理

MeritService (天兵功勋)
  └─ 军衔晋升、功勋累计

ChaosEventService (大闹天宫)
  └─ 叙事事件调度、结局判定
```

### 客户端 UI

```
StatusUI.local.lua     → 左下角 5 状态条 + 属性等级 + 红线警告
AlchemyUI.lua          → 药材选择面板 + 配方提示 + 炼制结果弹窗
DayNightUI.local.lua   → 左上角色时辰 + 昼夜图标
ShopUI.local.lua       → 仙丹阁商店面板
ChaosEventUI.local.lua → 叙事选择弹窗
SceneChoiceUI.lua      → 场景选择面板（资源耗尽/升级/手动触发时弹出）
```

---

## 核心文件

| 文件 | 职责 |
|------|------|
| `Config/StatsConfig.lua` | 所有数值常量（上限、恢复速率、红线阈值、任务消耗） |
| `Config/TaskConfig.luau` | 定义所有任务的元数据（交互区域、行为开关） |
| `Config/EconomyConfig.lua` | 奖励表（仙晶/功德配置） |
| `Config/SceneConfig.luau` | 所有场景的出生坐标 |
| `Config/DanConfig.lua` | 丹药品类配置 |
| `Config/ExamConfig.lua` | 考编门槛配置 |
| `Config/PlayerConfig.lua` | 玩家基础配置（注意：WalkSpeed 字段已弃用） |
| `Config/RiskConfig.lua` | 风险系统配置 |
| `Config/init.lua` | 统一加载所有 Config，含默认后备 |
| `Systems/DataManager.lua` | 数据持久化层（DataStore + 内存回退） |
| `Systems/StatusService.lua` | 状态引擎：恢复/验证/扣除/升级/红线检测 |
| `Systems/SpeedCalculator.lua` | 动态速度计算：(16 + 身法×0.5) × 状态修正 |
| `Systems/TimeService.lua` | 12 分钟时间循环，午夜疲劳结算（ModuleScript，延时加载） |
| `Systems/BeastNPC.lua` | 妖兽 NPC 生成和 AI |
| `Systems/TaskService.server.lua` | 调度器：加载处理器、路由事件 |
| `Systems/SceneSetup.server.lua` | 场景初始化：创建交互区域 + 主题装修（2D 横版） |
| `Systems/SceneManager.server.lua` | 场景管理：出生分配、远程传送（RemoteEvent） |
| `Systems/ShopService.server.lua` | 商店逻辑：每日限购、库存、购买 |
| `Systems/ExamService.server.lua` | 考编指数计算、考核逻辑、晋升处理 |
| `Systems/MeritService.lua` | 天兵功勋系统 |
| `Systems/ChaosEventService.server.lua` | 叙事事件调度 + 结局判定 |
| `Systems/PlayerInit.server.lua` | 玩家加入时创建 leaderstats |
| `Tasks/DeliverTask.lua` | 传菜处理器：目标分配、端盘放盘（代码生成盘子） |
| `Tasks/AlchemyTask.lua` | 炼丹处理器：配方匹配、成功率计算、炸炉 |
| `Tasks/BeastTask.lua` | 妖兽处理器：生成、攻击、击杀奖励 |
| `Tasks/PatrolTask.lua` | 蟠桃园巡逻任务 |
| `Tasks/ExpelMonkeyTask.lua` | 驱赶猴妖任务 |
| `Client/TaskClient.local.luau` | 客户端：读取 TaskConfig、绑定触摸事件、处理回执 |
| `Client/StatusUI.local.lua` | 5 状态条 + 等级 + 红线警告 UI |
| `Client/AlchemyUI.lua` | 炼丹面板：药材选择、配方提示、结果弹窗 |
| `Client/DayNightUI.local.lua` | 时辰 + 昼夜显示 |
| `Client/ShopUI.local.lua` | 仙丹阁商店面板 |
| `Client/ChaosEventUI.local.lua` | 叙事选择弹窗 |
| `Client/SceneChoiceUI.lua` | 场景选择面板（资源耗尽/升级/手动触发） |
| `Client/StoryPlayer.local.luau` | 叙事播放器 |
| `Client/StoryIntro.local.luau` | 游戏开场叙事 |
| `Client/Camera2D.local.lua` | 2D 摄像机 |
| `Client/Lock2D.local.lua` | 2D 锁定脚本 |

---

## TaskConfig 配置说明

在 `ReplicatedStorage.Shared.Config.TaskConfig` 中新增任务：

```lua
Tasks = {
    NewTask = {
        DisplayName = "任务名称",
        Description = "任务描述",
        HandlerModule = "Tasks.NewTaskHandler",  -- 处理器路径
        InteractionAreas = {
            Pickup = { PartName = "PickupPart", FireAction = "Pick" },
            Drop   = { PartName = "DropPart",   FireAction = "Drop",
                       NeedsAttribute = "AttrName" },
        },
        RewardType = "RewardKey",        -- 对应 EconomyConfig.Rewards 的键
        TargetRequired = false,           -- 是否需要目标分配
        SpawnOnComplete = false,          -- 完成时是否生成物体
    },
}
```

FireAction 支持的值：`Pick` / `Drop` / `Attack` / `Craft`
- `Attack` 用于妖兽的触摸攻击
- `Craft` 用于客户端 UI 触发的炼制操作

### 新增任务的步骤

1. 在 `TaskConfig.luau` 的 `Tasks` 表中添加新任务定义
2. 在 `Server/Tasks/` 下新建处理器文件（如 `PlantTask.lua`）
3. 处理器需按需实现接口：
   - `OnPlayerPickup(player, area)` → `boolean`
   - `OnPlayerDrop(player, area)` → `boolean, resultType`
   - `OnCraft(player, contextData)` → `boolean, result`（炼丹用）
   - `OnAttack(player, contextData)` → `boolean, result`（妖兽用）
4. （可选）在 `EconomyConfig.lua` 中添加对应的奖励配置
5. 无需修改 TaskService 或 TaskClient

---

## 场景系统

### 场景坐标

| 场景 | 场景ID | 坐标 | 功能 |
|------|--------|------|------|
| 御膳房 | YiShanFang | (0, 3, 0) | 传菜打工 |
| 炼丹洞天 | Alchemy | (1000, 3, 0) | 炼制丹药 |
| 妖兽战场 | Beast | (2000, 3, 0) | 狩猎妖兽 |
| 仙丹阁 | DanShop | (-1000, 3, 0) | 交易丹药 |
| 家 | Home | (-500, 3, 0) | 炼化提升 |

### 场景管理

- **SceneSetup.server.lua**：启动时创建所有场景的交互区域 Part 和装饰元素（无传送阵）
- **SceneManager.server.lua**：管理玩家出生位置和场景切换（通过 RemoteEvent）
- **SceneConfig.luau**：集中管理所有场景的出生坐标、显示名称和描述
- **场景切换方式**：通过 `SceneTeleportEvent` RemoteEvent（客户端 FireServer → 服务端传送）
- **选择面板触发时机**：
  1. **资源耗尽**：任务 Pick 时体力/精神不足 → 服务端 FireClient "ShowSceneChoice"
  2. **能力提升**：属性升级时（身法/火候/仙力升级）→ 服务端 FireClient "ShowSceneChoice"
  3. **手动切换**：客户端常驻按钮"切换场景" → 手动弹出选择面板

### 场景选择面板

- 由 `SceneChoiceUI.lua` 实现
- 全屏遮罩 + 5 个场景卡片（2x3 网格布局）
- 每个卡片显示场景名和描述
- 当前所在场景置灰不可点击
- 底部显示玩家当前状态（体力/精神/疲劳/火毒/戾气）
- 状态触发原因（升级/资源不足）用绿色/红色标注
- 点击卡片 → FireServer → 服务端 TeleportToScene → FireClient "SceneSwitched"

### 添加新场景

1. 在 `SceneConfig.luau` 中添加 `SceneName = { SpawnPosition = Vector3.new(...), DisplayName = "...", Description = "..." }`
2. 在 `SceneSetup.server.lua` 中添加 `setupXxxScene()` 函数，创建交互区域和装饰
3. 在 `SceneChoiceUI.lua` 的 `SCENE_ORDER` 表中添加场景 ID

---

## 全局因果数值引擎

### 设计哲学

> 每个动作都改变多维度状态，状态红线触发事件，事件连锁改变状态。
> 玩家没有"正确"玩法，只有不同的代价和后果——为选择负责。

### 状态全景

```
即时状态 (0-100)        元状态 (0-100)        永久属性 (等级+经验)
Stamina 体力             Risk 妖气              Agility 身法
Spirit  精神                                  AlchemyLv 火候
Fatigue 疲劳                                  Combat 仙力
FirePoison 火毒
Malice 戾气             资源: XianJing 仙晶, GongDe 功德
```

### 任务因果矩阵

| 字段 | 传菜 | 炼丹成功 | 炼丹炸炉 | 杀妖普通 | 杀妖精英 | 杀妖Boss |
|------|------|---------|---------|---------|---------|---------|
| Stamina | -8 | — | — | -12 | -18 | -25 |
| Spirit | -1 | -10 | -10 | — | — | — |
| Fatigue | +5 | +3 | +20 | — | — | — |
| FirePoison | — | +3 | +8 | — | — | — |
| Malice | — | — | — | +5 | +8 | +12 |
| Risk | — | — | — | +8 | +12 | +20 |
| AgilityExp | +5 | — | — | — | — | — |
| AlchemyExp | — | +8 | — | — | — | — |
| CombatExp | — | — | — | +10 | +15 | +25 |
| 仙晶 | +10 | +15 | -5 | +25 | +50 | +100 |
| 功德 | +1(每5次) | — | — | — | — | +10 |
| 特殊 | 5%暴击翻倍 | 大师级减毒 | 10%引妖 | — | — | — |

### 红线事件表（多级阈值）

| 状态 | 阈值 | 效果 | 连锁 |
|------|------|------|------|
| Fatigue | >80 | 额外 Fatigue+2/action | Spirit 恢复×0.7 |
| Fatigue | >90 | 10% 累倒→强制休息5s, Fatigue→50 | 全状态-10 |
| Fatigue | =100 | 昏厥10s, Fatigue→50 | 全状态-10 |
| FirePoison | >60 | DoT: Stamina-5/10s, 炼丹-30%, Fatigue+1/30s | — |
| FirePoison | >80 | DoT加速: Stamina-5/5s, 速度×0.5, Spirit-2/30s | 清毒散效果减半 |
| Malice | >50 | 冥想锁定, 午夜扣功德, Risk衰减×0.5 | — |
| Malice | >80 | 商店价格+20%, Risk累积×2 | NPC 畏惧 |
| Malice | >90 | 杀妖额外 Malice+5（杀戮循环） | 自激增强 |
| Risk | >30 | 5% 精英妖兽 | — |
| Risk | >60 | 15% 精英, 5% Boss | — |
| Risk | >80 | 30% 精英, 15% Boss, 5% 暴走 | 暴走逃逸→入侵其他场景 |

### 跨状态链式反应

| 条件1 | 条件2 | 事件名 | 效果 |
|-------|-------|--------|------|
| Fatigue>80 | FirePoison>60 | 虚不受补 | 所有恢复停止, 服药50%失败 |
| Malice>50 | Risk>60 | 入魔倾向 | 伤害+20%, 功德-1/action |
| Stamina<20 | Spirit<20 | 油尽灯枯 | 任务消耗×2, 强制传送回家 |
| FirePoison>80 | Malice>60 | 毒戾入体 | 10%毒发: Stamina-15, Spirit-10 |
| Fatigue>80 | Malice>80 | 狂躁 | 伤害+30%, 误伤率+15% |

### 升级规则
- 每 30 经验升 1 级（经验溢出保留）
- 升级时自动同步到 leaderstats（身法/火候/仙力）和 player Attributes

### 速度公式
`最终速度 = (16 + 身法等级 × 0.5) × 状态修正倍率`

状态修正：
- 正常: ×1.0
- 疲劳 > 80: ×0.6
- 火毒 > 80: ×0.5

### 家-冥想恢复
- 触摸蒲团 → 每 5s: Stamina+3, Spirit+3, Fatigue-1
- 限制：Malice>50 或战斗中不可冥想
- 每日祈福台 → GongDe+5（每日 1 次）

### Risk 妖气系统

| 区间 | 状态名 | 精英 | Boss | 暴走 |
|------|--------|------|------|------|
| 0-30 | 风平浪静 | 0% | 0% | 0% |
| 30-60 | 妖气隐现 | 5% | 0% | 0% |
| 60-80 | 危机四伏 | 15% | 5% | 0% |
| 80-100 | 大凶之兆 | 30% | 15% | 5% |

- **衰减**：每 120s 自然 -1，每 20 功德额外 +0.5，最低降到 10
- **化解**：消耗 10/30/80 功德 → 降 5/20/50 Risk（大化解有 CD）
- **功德减免**：每 200 功德降低 50% 强化概率

### 功德获取

| 途径 | 每次获取 | 限制 |
|------|---------|------|
| 帮助 NPC | +10 | 每日 3 次 |
| 每 5 次传菜 | +1 | 自动累计 |
| Boss 击杀 | +10 | — |
| 巡逻任务 | +3 | 考编后 |
| 驱猴任务 | +2 | 考编后 |
| 丹药捐献 | +5 | 每日 2 次 |
| 每日祈福 | +5 | 每日 1 次（家） |
| Chaos 天庭选项 | +5~15 | 考编后 |

### 因果链示例

```
连续杀妖 5 次:
  Risk 0→40 (>30: 进入"妖气隐现")
  Malice 0→25
  Stamina 100→40

第 6 次: Roll 5% → 触发精英妖兽！
  Stamina -18, Malice +8, Risk +12
  Risk 40→52, 仍在"妖气隐现"区间

选择去传菜"休息":
  Fatigue 从 0→+15，若 Fatigue>80 触发过劳螺旋
  → 额外 Fatigue+2/次, Spirit 恢复×0.7

最坏连锁:
  Fatigue>80 + FirePoison>60 → "虚不受补" → 全恢复停止
  → 继续行动 → 油尽灯枯 → 强制传送回家
```

---

## 数据层

### DataManager 存档字段

```lua
{
    -- 经济
    XianJing = 0, GongDe = 0, Risk = 10,
    -- 场景
    CurrentScene = "YiShanFang", HasQuitJob = false,
    -- 即时状态
    Stamina = 100, Spirit = 100, Fatigue = 0,
    FirePoison = 0, Malice = 0,
    -- 永久属性（含经验）
    Agility = 1, AgilityExp = 0,
    AlchemyLv = 1, AlchemyExp = 0,
    Combat = 1, CombatExp = 0,
    -- 时间
    TotalDays = 0,
    -- 商店
    DailyPurchases = {}, LastPurchaseReset = 0,
    -- 考编 & 天兵
    IsRecruited = false, Loyalty = 50, WukongFavor = 0, Chaos = 0,
    EndingReached = false, LastEventHour = -99,
    Merit = 0, MilitaryRank = "天兵",
    PatrolCount = 0, ExpelCount = 0,
}
```

Attribute 同步规则：
- Stamina/Spirit/Fatigue/FirePoison/Malice/Risk → `player:SetAttribute()` 供客户端 StatusUI 读取
- Agility/AlchemyLv/Combat → `player:SetAttribute()` 供 StatusUI 读取
- Merit/MilitaryRank → leaderstats + Attribute 双同步

### 旧存档兼容
`loadPlayerData()` 使用 `setmetatable(data, { __index = DEFAULT_DATA })` 确保旧存档中新字段自动获取默认值。

---

## 时间系统

- 12 分钟 = 1 天（30 秒/时辰）
- 凌晨 0:00（子时）触发疲劳结算：Fatigue -30，天数 +1
- 戾气 > 50 时额外扣除功德
- 白天/夜晚自动切换环境光照
- 客户端显示当前时辰（子丑寅卯...）

---

## 炼丹系统

### 丹方

| 丹药 | 配方 | 成功率 | 特殊效果 |
|------|------|--------|----------|
| 回气丹 | 草药+清水 | 70% | Stamina +20 |
| 清毒散 | 草药+火晶 | 50% | FirePoison -15 |
| 聚神丹 | 灵芝+仙露 | 30% | Spirit +15 |

### 成功率修正
`最终成功率 = 基础成功率 + 火候等级×5% - (火毒>60 ? 30% : 0)`

### 交互流程
1. 触摸 IngredientTable → 捡起药材（carrying=true）
2. 触摸 Furnace → 服务端返回 OpenAlchemyUI → 客户端打开药材选择面板
3. 选择 2 种药材 → 点击「开始炼制」→ FireServer("Craft:Alchemy")
4. 服务端计算成功率 → 返回 CraftSuccess / CraftFailed

---

## 妖兽系统

### 妖兽等级

| 等级 | Combat需求 | HP | 伤害 | 速度 |
|------|-----------|-----|------|------|
| 普通 | < 5 | 30 | 5 | 12 |
| 精英 | ≥ 5 | 60 | 8 | 15 |
| Boss | ≥ 10 | 120 | 12 | 18 |

### 交互流程
1. 触摸 BeastSpawn → 妖兽出现
2. 妖兽 AI：巡逻 → 发现玩家（15格）→ 追击 → 攻击（每2秒，近战）
3. 触摸妖兽 hitbox → 发送 Attack:Beast → 服务端计算伤害
4. 击杀：获得 CombatExp+10, 仙晶+25
5. 逃离（>30格）或超时（30秒）→ 妖兽消失

### 伤害公式
`玩家伤害 = 8 + 仙力等级 × 2`

---

## 重要注意事项

### 客户端脚本 RunContext
独立运行的 UI 脚本（StatusUI、DayNightUI、ShopUI、ChaosEventUI）使用 `.local.lua` 后缀（SSS 识别为 LocalScript + Legacy RunContext）。被其他脚本 `require` 的 UI 模块（AlchemyUI、SceneChoiceUI）必须使用 `.lua` 后缀（ModuleScript），否则 `require` 会因类型不匹配而失败。不要在代码中通过 `pcall` 设置 RunContext，无效。

注意：`.client.lua` 后缀在 StarterPlayerScripts 中会被设为 NonLegacy RunContext，导致脚本执行两次（UI 重复创建、状态混乱）。必须使用 `.local.lua`。

### StatusUI 容错模式
- `waitForAttributes()` 带超时（15 秒最大等待），防止服务器数据未就绪时死循环
- `RenderStepped` 更新循环用 `pcall` 包裹，单个帧报错不会导致 UI 彻底崩溃

### DayNightUI 重试
TimeEvent 查找使用轮询方式（最多 60 秒，每秒重试），而不是单次 WaitForChild 超时。

### DeliverTask 盘子生成
盘子和桃子由 `makePlatePart()` / `makePeachPart()` 代码生成，不依赖 ReplicatedStorage 中的模型模板。删除 Plate 模型不会影响功能。

### 方法调用的 `:` 与 `.` 约定
模块函数若用 `.` 定义（如 `function BeastNPC.SomeMethod()`），调用时必须用 `BeastNPC.SomeMethod()`，不可用 `self:SomeMethod()`。混用会导致参数错位和 bug。

### 旧存档兼容
DataManager 的 `__index = DEFAULT_DATA` 机制可自动填充旧存档中缺少的新字段。新增 DataManager 字段时只需加到 `DEFAULT_DATA` 表即可。

### 场景选择面板客户端集成
在 `TaskClient.local.luau` 中处理 `ShowSceneChoice` 事件时，通过 `FindFirstChild` 查找 SceneChoiceUI 模块（兼容 SSS 延迟同步），而非直接 `require`。其他 UI 模块（AlchemyUI）同样遵循此模式。
