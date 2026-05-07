# MyGame 项目架构指南

## 项目概况

- **同步方式**：Roblox Studio SSS（文件直连，不使用 Rojo）
- **文件命名**：客户端脚本使用 `.legacy.lua` 后缀（RunContext = Legacy）；被 `require` 的 UI 模块使用 `.lua` 后缀（ModuleScript）
- **语言**：Luau（部分文件使用 `.luau` 扩展名）
- **场景**：多场景沙盒，通过场景选择面板切换（无物理传送阵）

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
StatusUI.legacy.lua   → 右上角 5 状态条 + 属性等级 + 红线警告
AlchemyUI.lua         → 药材选择面板 + 配方提示 + 炼制结果弹窗
DayNightUI.legacy.lua → 左上角色时辰 + 昼夜图标
ShopUI.legacy.lua     → 仙丹阁商店面板
ChaosEventUI.legacy.lua → 叙事选择弹窗
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
| `Systems/TimeService.server.lua` | 12 分钟时间循环，午夜疲劳结算 |
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
| `Client/StatusUI.legacy.lua` | 5 状态条 + 等级 + 红线警告 UI |
| `Client/AlchemyUI.lua` | 炼丹面板：药材选择、配方提示、结果弹窗 |
| `Client/DayNightUI.legacy.lua` | 时辰 + 昼夜显示 |
| `Client/ShopUI.legacy.lua` | 仙丹阁商店面板 |
| `Client/ChaosEventUI.legacy.lua` | 叙事选择弹窗 |
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

## 因果数值系统

### 即时状态（Current Status）

| 名称 | 变量名 | 上限 | 恢复 | 任务影响 |
|------|--------|------|------|----------|
| 体力 | Stamina | 100 | 每5s +1（疲劳>80时减半） | 传菜-15，妖兽-25 |
| 精神 | Spirit | 100 | 每5s +1 | 炼丹-20 |
| 疲劳 | Fatigue | 100 | 午夜结算-30 | 传菜+10，炸炉+20 |
| 火毒 | FirePoison | 100 | 清毒散-15 | 炼丹+5 |
| 戾气 | Malice | 100 | 无自动恢复 | 妖兽+10 |

### 永久属性（Permanent Attributes）

| 名称 | 变量名 | 经验来源 | 效果 |
|------|--------|----------|------|
| 身法 | Agility | 传菜 +5 AgilityExp | 每级 WalkSpeed +0.5 |
| 火候 | AlchemyLv | 炼丹 +8 AlchemyExp | 每级炼丹成功率 +5% |
| 仙力 | Combat | 妖兽 +10 CombatExp | 每级伤害 +2 |

### 升级规则
- 每 30 经验升 1 级（经验溢出保留）
- 升级时自动同步到 leaderstats（身法/火候/仙力）和 player Attributes

### 速度公式

`最终速度 = (16 + 身法等级 × 0.5) × 状态修正倍率`

状态修正：
- 正常: ×1.0
- 疲劳 > 80: ×0.6
- 火毒 > 80: ×0.5

### 红线惩罚

| 条件 | 惩罚 |
|------|------|
| 疲劳 > 80 | 速度 ×0.6，体力恢复减半 |
| 火毒 > 60 | 每10s Stamina-5，炼丹成功率 -30% |
| 戾气 > 50 | 午夜结算时扣除功德 |

### 任务因果对照

| 任务 | 消耗 | 收益 |
|------|------|------|
| 传菜 | Stamina-15, Fatigue+10 | AgilityExp+5, 仙晶+10 |
| 炼丹（成功） | Spirit-20, FirePoison+5 | AlchemyExp+8, 仙晶+15, 丹药效果 |
| 炼丹（炸炉） | Spirit-20, Fatigue+20 | 无 |
| 妖兽（击杀） | Stamina-25, Malice+10 | CombatExp+10, 仙晶+25 |

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
- Stamina/Spirit/Fatigue/FirePoison/Malice → `player:SetAttribute()` 供客户端 StatusUI 读取
- Agility/AlchemyLv/Combat/Merit/MilitaryRank → leaderstats + Attribute 双同步

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
独立运行的 UI 脚本（StatusUI、DayNightUI、ShopUI、ChaosEventUI）使用 `.legacy.lua` 后缀，在 Studio 中 RunContext 设为 Legacy。被其他脚本 `require` 的 UI 模块（AlchemyUI、SceneChoiceUI）必须使用 `.lua` 后缀（ModuleScript），否则 `require` 会因类型不匹配而失败。不要在代码中通过 `pcall` 设置 RunContext，无效。

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
