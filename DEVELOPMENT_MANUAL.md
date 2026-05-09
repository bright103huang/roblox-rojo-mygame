# 仙界打工人 — 开发手册

> Roblox 2D 横版叙事沙盒游戏 · SSS 同步 · Luau

---

## 第一章：项目哲学与核心设计原则

### 叙事沙盒核心
> 每个动作都改变多维度状态，状态红线触发事件，事件连锁改变状态。
> 玩家没有"正确"玩法，只有不同的代价和后果——为选择负责。

### 三条铁律
1. **选择即叙事** — 玩法机制的核心是给玩家有意义的抉择，而非引导最优解
2. **场景永不硬锁定** — 条件评估只提供信息（推荐/谨慎/警告），玩家始终可自主选择
3. **数值驱动因果** — 所有行为通过统一数值引擎产生连锁反应，体现逻辑与人性

---

## 第二章：项目架构总览

### 文件拓扑

```
ReplicatedStorage/
  Shared/
    Config/            ← 所有配置表（StatsConfig, TaskConfig, SceneConfig 等）
    Events/            ← RemoteEvent/Function 仓库
ServerScriptService/
  Server/
    Systems/           ← 核心引擎系统
    Tasks/             ← 任务处理器（Task Handler 模式）
StarterPlayer/
  StarterPlayerScripts/
    Client/            ← 客户端 UI 脚本 + 任务客户端
```

### 核心系统关系

```
                    SceneGateService (场景门控评估)
                            │
Client UI ←→ TaskService (调度器) ←→ Task Handlers (5个)
                    │
              StatusService (状态引擎)
              ├─ CanPerformTask / ApplyCosts / AddExp
              ├─ CheckRedLines / ChainReactionCheck
              └─ 定时恢复循环 + Risk 衰减循环
                    │
              DataManager (数据持久化)
              TimeService (时辰循环)
              SpeedCalculator (动态速度)
              BeastNPC (妖兽 AI)
```

### 客户端 UI 概览

| UI | 文件 | 类型 | 触发方式 |
|----|------|------|---------|
| 场景选择面板 | `SceneChoiceUI.lua` | ModuleScript | 升级/资源耗尽/手动 |
| 状态条 | `StatusUI.local.lua` | LocalScript | 常驻左下角 |
| 时辰显示 | `DayNightUI.local.lua` | LocalScript | 常驻左上角 |
| 炼丹面板 | `AlchemyUI.lua` | ModuleScript | 触摸丹炉 |
| 商店面板 | `ShopUI.local.lua` | LocalScript | 触摸商店 |
| 叙事弹窗 | `ChaosEventUI.local.lua` | LocalScript | 事件触发 |

---

## 第三章：SSS 文件命名规范（踩坑记录）

### 后缀与脚本类型对照

| 后缀 | Roblox 类型 | RunContext | 用途 | 坑 |
|------|-------------|-----------|------|-----|
| `.server.lua` | Script | Legacy | 服务端逻辑 | — |
| `.local.lua` | LocalScript | **Legacy** | **StarterPlayerScripts** | ✅ 正确选择 |
| `.client.lua` | LocalScript | NonLegacy | 其他地方 | ❌ 放 StarterPlayerScripts 会执行两次 |
| `.lua` | ModuleScript | — | UI 模块、工具 | — |
| `.luau` | ModuleScript | — | Config 配置表 | — |

### 血的教训

1. **`.client.lua` 在 StarterPlayerScripts 中会导致脚本执行两次**，UI 重复创建、状态混乱。必须使用 `.local.lua`（Legacy RunContext）。

2. **`.legacy.lua` 不是 SSS 标准后缀**，SSS 会误判为 Script（服务端脚本），导致客户端 UI 不运行。旧代码中遗留的 `.legacy.lua` 文件（如 `AlchemyUI.legacy.lua`、`SceneChoiceUI.legacy.lua`）是废弃的，应删除。

3. **被 `require` 的模块必须用 `.lua` 或 `.luau`**，否则 `require` 因类型不匹配（要求 ModuleScript）而失败。`AlchemyUI.lua` 和 `SceneChoiceUI.lua` 是正确示例。

4. **不可通过 `pcall` 设置 RunContext**，无效——必须在文件系统层面确定。

### 判断规则
- 需要独立运行的 UI？→ `.local.lua`（放 StarterPlayerScripts）
- 被其他脚本 require？→ `.lua` 或 `.luau`
- 服务端逻辑？→ `.server.lua`

---

## 第四章：仙官司协作体系（AI 子代理）

### 五司分工

| 仙官司 | Agent ID | 职责 | 输出物 |
|--------|----------|------|--------|
| 营造司 | `architect` | 游戏架构设计、全局规划 | 架构文档、实施计划 |
| 数据司 | `data-steward` | Config 配置表、数据层 | StatsConfig、DataManager |
| 界面司 | `ui-artisan` | 客户端 UI（纯 Luau，无 Roact） | UI 模块、LocalScript |
| 任务司 | `task-craftsman` | Task Handler 模式任务逻辑 | DeliverTask、AlchemyTask 等 |
| 查察司 | `qa-inspector` | 代码审查、Bug 修复、一致性检查 | 质量报告、修复提交 |

### 标准协作流程

```
营造司 设计 → 数据司 定 Config → 界面司 + 任务司 并行实施 → 查察司 验证
```

### 实施顺序模板（复杂功能时参考）

```
Phase 1 (数据基础) ─── 阻塞 ─── Phase 3 (需要统一数值)
     │                              │
     v                              v
Phase 2 (机制玩法) ─── 阻塞 ─── Phase 6 (UI 需要数据)
     │
     v
Phase 4 (链式反应) ─── 独立可并行
     │
     v
Phase 5 (UI 引导)  ─── 独立可并行
```

### 子代理使用注意事项

1. **任务描述要精确** — 指定文件路径、函数名、改动范围。模糊描述会导致子代理偏离方向。

2. **独立工作 + 超时处理** — 子代理有超时限制（约 5 分钟）。大型改动用多个子代理并行，每个专注一个文件。

3. **验收检查** — 子代理完成后必须验证关键代码段是否已修改到位（用 Read 或 Grep 确认）。

4. **避免冲突** — 多个子代理不要同时修改同一文件。数据司和任务司可并行但文件不同。

---

## 第五章：Task Handler 任务系统

### 架构

```
Client (TaskClient.local.luau)
  │  FireServer("Pick:Deliver", ...)
  │  FireServer("Drop:Deliver", ...)
  │  FireServer("Craft:Alchemy", ...)
  │  FireServer("Attack:Beast", ...)
  ▼
TaskService.server.lua (调度器)
  │  路由: actionType + taskName → handler
  ├─ DeliverTask.lua   (传菜)
  ├─ AlchemyTask.lua   (炼丹)
  ├─ BeastTask.lua     (妖兽)
  ├─ PatrolTask.lua    (巡逻·考编后)
  └─ ExpelMonkeyTask.lua (驱猴·考编后)
```

### 处理器接口

```lua
-- 返回 boolean（是否成功）
OnPlayerPickup(player, area) → boolean
OnPlayerDrop(player, area) → boolean, resultType

-- 返回 boolean, { Success, Reason, ... }
OnCraft(player, contextData) → boolean, result
OnAttack(player, contextData) → boolean, result
```

### 新增任务步骤

1. `TaskConfig.luau` — Tasks 表中添加定义（HandlerModule、InteractionAreas、FireAction）
2. `Server/Tasks/` — 新建处理器文件，实现需要的接口方法
3. `StatsConfig.lua` — TASK_COSTS 中添加该任务的 ActionCost/ApplyCost
4. 无需修改 TaskService 或 TaskClient（自动发现机制）

### Pick 流程（含前置检查）

```
客户端 Pick → TaskService
  → 读取 TASK_COSTS[taskName].ActionCost
  → StatusService:CanPerformTask(player, ActionCost)
  → 不足 → FireClient("ShowSceneChoice", reason)
  → 充足 → handler.OnPlayerPickup() → 回执客户端
```

### 统一成本读取

所有任务处理器必须通过 `StatusService:GetTaskCosts(taskName)` 读取成本配置，**禁止硬编码数值**。该函数返回时间修正后的副本（不同时辰消耗不同）。

---

## 第六章：场景系统

### 2D 横版核心约束

- **摄像机**：`CFrame.new(root.Position + Vector3.new(0, 10, 30), root.Position)`
- **Z 轴锁定**：HumanoidRootPart.Position.Z 每帧设为 0（Lock2D.local.lua）
- **交互区域**：必须位于 Z=0（被角色触摸）
- **装饰分层**：后层 Z=-4，前层 Z=4，角色在 Z=0 行走
- **NPC 移动**：仅 X 轴

### 场景坐标

| 场景 | ID | 坐标 | 类型 |
|------|-----|------|------|
| 御膳房 | YiShanFang | (0, 3, 0) | Work |
| 炼丹洞天 | Alchemy | (1000, 3, 0) | Work |
| 妖兽战场 | Beast | (2000, 3, 0) | Work |
| 仙丹阁 | DanShop | (-1000, 3, 0) | Shop |
| 家 | Home | (-500, 3, 0) | Home |

### 场景选择面板（SceneChoiceUI）

**触发时机**（3种）：
1. 资源耗尽 — Pick 时体力/精神不足
2. 能力提升 — 属性升级（身法/火候/仙力）
3. 手动切换 — 常驻"切换场景"按钮

**UI 布局（520px 高）**：
```
Y 层次:
10-46:   标题
46-68:   时辰建议行（当前时段 + 日/夜建议）
68-72:   分割线
72-182:  第1排卡片 (3张)
182-197: 间距
197-307: 第2排卡片 (2张)
307-322: 间距
322-427: 状态栏（含链式反应警告）
427-520: 底部边距 + 关闭按钮
```

**卡片规则**：
- 左侧色条：蓝绿=可用、黄=谨慎、红=警告（来自 SceneGateService 评估）
- 卡片顶端显示简短状态文本（如"体力充足"、"疲劳偏高"）
- **所有卡片始终可点击**（当前场景除外），尊重玩家选择权

---

## 第七章：场景门控系统（SceneGateService）

### 评估机制

```lua
SceneGateService:EvaluateScene(player, sceneId)
→ 返回 { status = "available"|"caution"|"warning", reason = "..." }
```

**Home** — 永远 available
**DanShop** — 检查 ShopOpen + XianJing > 0
**YiShanFang** — 检查体力 vs 传菜消耗 + 疲劳红线
**Alchemy** — 检查精神 vs 炼丹消耗 + 火毒红线
**Beast** — 检查体力 vs 妖兽消耗 + 戾气红线

### 客户端数据流

```
Open() → InvokeServer("RequestSceneGates")
  → 服务端调用 EvaluateAllScenes(player)
  → 返回 { Gates = {...}, GameHour, IsNight, TimeLabel, ChainEvents }
  → UI 渲染彩色卡片 + 时间建议
```

### 关键设计点

- **永不硬锁定**：`EvaluateScene` 只返回建议状态，客户端不阻止点击
- **数据来自 Attribute**：手动切换按钮从 player Attributes 读取状态（兼容 SSS 延迟同步）
- **RemoteFunction 回退**：若 RequestSceneGates 未就绪，UI 回退到全 available

---

## 第八章：因果数值引擎

### 状态全景

```
即时状态 (0-100)        元状态 (0-100)        永久属性 (等级+经验)
Stamina 体力             Risk 妖气              Agility 身法
Spirit  精神                                  AlchemyLv 火候
Fatigue 疲劳                                  Combat 仙力
FirePoison 火毒
Malice 戾气             资源: XianJing 仙晶, GongDe 功德
```

### 任务因果矩阵（精确数值）

| 字段 | 传菜 | 炼丹成功 | 炼丹失败 | 杀妖普通 | 精英 | Boss |
|------|------|---------|---------|---------|------|------|
| Stamina | -8 | — | — | -12 | -18 | -25 |
| Spirit | -1 | -10 | -10 | — | — | — |
| Fatigue | +5 | +3 | +20 | — | — | — |
| FirePoison | — | +3 | +8 | — | — | — |
| Malice | — | — | — | +5 | +8 | +12 |
| Risk | — | — | — | +8 | +12 | +20 |
| AgilityExp | +5 | — | — | — | — | — |
| AlchemyExp | — | +8 | — | — | — | — |
| CombatExp | — | — | — | +10 | +15 | +25 |
| XianJing | +10 | +15 | -5 | +25 | +50 | +100 |
| GongDe | +1/5次 | — | — | — | — | +10 |

### 红线事件表

| 状态 | 阈值 | 效果 |
|------|------|------|
| Fatigue | >80 | 额外 Fatigue+2/action，Spirit 恢复×0.7 |
| Fatigue | >90 | 10% 累倒→强制休息 5s，Fatigue→50，全状态-10 |
| FirePoison | >60 | DoT: Stamina-5/10s，炼丹-30%，Fatigue+1/30s |
| FirePoison | >80 | DoT 加速: Stamina-5/5s，速度×0.5，Spirit-2/30s |
| Malice | >50 | 冥想锁定，午夜扣功德，Risk 衰减×0.5 |
| Malice | >80 | 商店价格+20%，Risk 累积×2 |
| Malice | >90 | 杀妖额外 Malice+5（杀戮循环） |

### 跨状态链式反应（5种，全部实装）

| 名称 | 条件 | 效果 | 实装位置 |
|------|------|------|---------|
| 虚不受补 | Fatigue>80 + FirePoison>60 | 恢复停止 + 炼丹 50% 失败 | StatusService 恢复循环 + AlchemyTask |
| 入魔倾向 | Malice>50 + Risk>60 | 伤害+20%，功德-1/次 | StatusService:ApplyCosts |
| 油尽灯枯 | Stamina<20 + Spirit<20 | 消耗×2 + 强制传送回家 | StatusService:ApplyCosts |
| 毒戾入体 | FirePoison>80 + Malice>60 | 10% 毒发: Stamina-15, Spirit-10 | StatusService:ApplyCosts |
| 狂躁 | Fatigue>80 + Malice>80 | 伤害+30%，误伤 15% | BeastNPC:PlayerAttackBeast |

### 伤害公式
```
玩家伤害 = 8 + Combat × 2
入魔倾向时: ×1.2
狂躁时: ×1.3（与入魔倾向叠加）
速度 = (16 + Agility × 0.5) × 状态修正
```

### 升级规则
- 每 30 经验升 1 级（经验溢出保留）
- 同步到 player Attributes + NameDisplay 级别显示

---

## 第九章：时间系统

### 时辰分段（30 秒/时辰，12 分钟/天）

| 时段 | 游戏小时 | taskEff | shopOpen | restEff | 说明 |
|------|---------|---------|----------|---------|------|
| 上午 | 4-12 | 0.87 | false | 0.8 | 工作效率高峰 |
| 下午 | 12-18 | 1.0 | true | 1.0 | 效率正常，商店营业 |
| 傍晚 | 18-22 | 1.15 | true | 1.2 | 效率下降，商店将打烊 |
| 深夜 | 22-28 | 1.3 | false | 1.5 | 适合休息冥想 |

### 时间修正机制

- **任务消耗**：`GetTaskCosts()` 中消耗乘以 `taskEff`（效率低则消耗更多精神/体力）
- **恢复速率**：Stamina/Spirit 恢复乘以 `restEff`（深夜恢复 1.5 倍）
- **商店营业**：DanShop 仅在 `shopOpen == true` 时可交易
- **全服广播**：通过 TimeEvent RemoteEvent + player Attributes（GameHour, IsNight, TimeEff, ShopOpen, RestEff, TimeLabel）

### 午夜结算
- Fatigue -30
- TotalDays +1
- Malice > 50 时额外扣除功德

---

## 第十章：数据层

### 存档字段（DEFAULT_DATA）

所有字段定义在 `DataManager.lua` 的 `DEFAULT_DATA` 表中。新增字段只需加到该表，旧存档通过 `setmetatable(data, { __index = DEFAULT_DATA })` 自动获取默认值。

### Attribute 同步规则

| 字段 | 同步方式 | 客户端读取 |
|------|---------|-----------|
| Stamina/Spirit/Fatigue/FirePoison/Malice/Risk | `player:SetAttribute()` | StatusUI |
| Agility/AlchemyLv/Combat | `player:SetAttribute()` | StatusUI + 场景面板 |
| CurrentScene | `player:SetAttribute()` | 场景面板 |
| Merit/MilitaryRank | leaderstats + Attribute | StatusUI |
| GameHour/IsNight/TimeLabel/ShopOpen/RestEff | `player:SetAttribute()` | 场景面板 + ShopUI |
| ChainEvents | `player:SetAttribute()` | 场景面板 |

### 存储策略
- 内存缓存 + DataStore（正式环境）+ 内存后备（Studio 测试）
- 玩家离开时自动保存
- leaderstats 的仙晶/功德在保存时同步回 data 表

---

## 第十一章：炼丹系统

### 丹方

| 丹药 | 配方 | 基础成功率 | 特殊效果 |
|------|------|-----------|---------|
| 回气丹 | 草药+清水 | 70% | Stamina +20 |
| 清毒散 | 草药+火晶 | 50% | FirePoison -15 |
| 聚神丹 | 灵芝+仙露 | 30% | Spirit +15 |

### 新交互流程（B+方案）

```
材料台 → 取药材 (carrying=herb)
柴火堆 → 取柴火 (carrying=firewood)  
丹炉 → 添柴 (1/3)，炉火微亮
柴火堆 → 取柴火
丹炉 → 添柴 (2/3)，炉火更旺
柴火堆 → 取柴火
丹炉 → 添柴 (3/3)，炉火最旺 → Roll 出结果
  ├ 成功：光球飞入葫芦，获得仙晶+火候经验
  └ 炸炉：黑烟特效，疲劳大增
```

### 分步消耗

| 动作 | Spirit | Fatigue |
|------|--------|---------|
| 取药材 | -5 | +1 |
| 取柴火（每次） | -3 | +1 |
| 添柴（每次） | -5 | +2 |
| **一轮满炼总计** | **-29** | **+10** |

### 成功率公式

```
成丹率 = 50% + AlchemyLv × 4% + 添柴次数 × 12% - (FirePoison > 60 时 -20%)
clamp 到 [10%, 95%]
```

添柴次数 = 0~3（每添一次 +12%，跑满3趟 +36%）。

### 设计意图（数值依据）

| 阶段 | 行为 | 意图 |
|------|------|------|
| Lv1-3 | 跑满3趟 ≈ 90%成功率 | 新手友好，建立正反馈 |
| Lv4-7 | 可少跑1-2趟柴火，效率优先 | 火候够了给玩家灵活选择 |
| Lv8+ | 直接添柴1次也稳 | 后期节约时间做其他事 |
| FirePoison>60 | -20%硬惩罚 | 驱毒（清毒散/冥想）成为有意义决策 |
| 每日上限 | 约4-5轮满炼（Spirit 100→0） | 配合自动恢复，刚好跑完休息或切换场景 |

---

## 第十二章：妖兽系统

### 妖兽等级

| 等级 | Combat 需求 | HP | 伤害 | 速度 | 奖励倍率 |
|------|------------|-----|------|------|---------|
| 普通 | < 5 | 30 | 5 | 12 | ×1 |
| 精英 | ≥ 5 | 60 | 8 | 15 | ×2 |
| Boss | ≥ 10 | 120 | 12 | 18 | ×3 |

### 交互流程
1. 触摸 BeastSpawn → 生成妖兽
2. AI 巡逻 → 发现玩家（15格）→ 追击 → 攻击（近战，2秒CD）
3. 触摸妖兽 hitbox → Attack:Beast → 服务端扣血
4. 击杀 → 奖励 CombatExp + XianJing
5. 逃离（>30格）或超时（30秒）→ 妖兽消失

### 玩家伤害修正
- 基础：`8 + Combat × 2`
- 入魔倾向：×1.2
- 狂躁：×1.3
- 狂躁误伤：15% 概率自伤 30%

### Risk 对妖兽等级的影响

| Risk | 精英概率 | Boss概率 | 暴走概率 |
|------|---------|---------|---------|
| 0-30 | 0% | 0% | 0% |
| 30-60 | 5% | 0% | 0% |
| 60-80 | 15% | 5% | 0% |
| 80-100 | 30% | 15% | 5% |

---

## 第十三章：模块调用约定

### `:` 与 `.` 的关键区别

```lua
-- 用 . 定义（无 self）
function BeastNPC.SomeMethod()
  -- 无 self 参数
end

-- 必须用 . 调用
BeastNPC.SomeMethod()  -- ✅
BeastNPC:SomeMethod()  -- ❌ 会多传 self 导致参数错位

-- 用 : 定义（有 self）
function StatusService:ApplyCosts(player, costs)
  -- self = StatusService
end

-- 必须用 : 调用
StatusService:ApplyCosts(player, costs)  -- ✅
StatusService.ApplyCosts(player, costs)  -- ❌ 缺少 self
```

**经验法则**：看模块的定义方式决定调用方式。大多数 Systems 用 `:`，BeastNPC 部分函数用 `.`。

### 延迟加载避免循环依赖

```lua
-- StatusService 中的模式
local SpeedCalculator = nil
local function getSpeedCalculator()
  if not SpeedCalculator then
    SpeedCalculator = require(script.Parent.SpeedCalculator)
  end
  return SpeedCalculator
end

-- SceneGateService 也遵循此模式加载 TimeService
```

在有循环依赖风险的地方使用此模式（StatusService ↔ SpeedCalculator，SceneGateService ↔ TimeService）。

---

## 第十四章：新功能开发检查清单

### 步骤流程

- [ ] **需求分析** — 明确功能的目标和用户故事
- [ ] **架构设计**（营造司）— 确定影响的系统和文件，设计数据流
- [ ] **数值配置**（数据司）— StatsConfig/其他 Config 中定义常量
- [ ] **数据字段**（数据司）— DataManager DEFAULT_DATA 新增字段（如需）
- [ ] **服务端逻辑**（任务司/查察司）— Task Handler 或 System 实现
- [ ] **客户端 UI**（界面司）— UI 模块 + 事件处理
- [ ] **集成联调** — TaskEvent 路由、Attribute 同步、RemoteEvent/Function 注册
- [ ] **验证**（查察司）— 一致性检查、边界情况

### 常见的坑

- [ ] 文件后缀是否正确？（`.local.lua` vs `.client.lua` vs `.lua`）
- [ ] 成本数值是否通过 `GetTaskCosts()` 读取？（禁止硬编码）
- [ ] Attribute 是否在 DataManager:UpdateField 中同步？
- [ ] 场景交互区域是否在 Z=0？
- [ ] 循环依赖是否处理？（用延迟加载 getter）
- [ ] `:` vs `.` 调用方式是否正确？
- [ ] 旧存档兼容 — 新字段是否在 DEFAULT_DATA 中？
- [ ] 客户端模块查找 — 用 `FindFirstChild` 而非直接 `require`（SSS 延迟同步）
- [ ] RemoteEvent 是否存在且在 Events 文件夹中？
- [ ] 是否遵循"场景永不硬锁定"原则？

---

## 附录：关键文件速查

### 服务端核心文件路径

| 模块 | 路径 |
|------|------|
| Config 入口 | `ReplicatedStorage.Shared.Config` |
| StatsConfig | `ReplicatedStorage.Shared.Config.StatsConfig` |
| TaskConfig | `ReplicatedStorage.Shared.Config.TaskConfig` |
| SceneConfig | `ReplicatedStorage.Shared.Config.SceneConfig` |
| DataManager | `ServerScriptService.Server.Systems.DataManager` |
| StatusService | `ServerScriptService.Server.Systems.StatusService` |
| TimeService | `ServerScriptService.Server.Systems.TimeService` |
| TaskService | `ServerScriptService.Server.Systems.TaskService.server` |
| SceneGateService | `ServerScriptService.Server.Systems.SceneGateService` |
| SceneSetup | `ServerScriptService.Server.Systems.SceneSetup.server` |
| SceneManager | `ServerScriptService.Server.Systems.SceneManager.server` |
| BeastNPC | `ServerScriptService.Server.Systems.BeastNPC` |
| SpeedCalculator | `ServerScriptService.Server.Systems.SpeedCalculator` |
| ShopService | `ServerScriptService.Server.Systems.ShopService.server` |

### 任务处理器路径

| 任务 | 路径 |
|------|------|
| Deliver | `ServerScriptService.Server.Tasks.DeliverTask` |
| Alchemy | `ServerScriptService.Server.Tasks.AlchemyTask` |
| Beast | `ServerScriptService.Server.Tasks.BeastTask` |
| Patrol | `ServerScriptService.Server.Tasks.PatrolTask` |
| ExpelMonkey | `ServerScriptService.Server.Tasks.ExpelMonkeyTask` |

### 客户端路径

| UI | 路径 |
|----|------|
| TaskClient | `StarterPlayer.StarterPlayerScripts.Client.TaskClient.local` |
| StatusUI | `StarterPlayer.StarterPlayerScripts.Client.StatusUI.local` |
| DayNightUI | `StarterPlayer.StarterPlayerScripts.Client.DayNightUI.local` |
| SceneChoiceUI | `StarterPlayer.StarterPlayerScripts.Client.SceneChoiceUI` |
| AlchemyUI | `StarterPlayer.StarterPlayerScripts.Client.AlchemyUI` |
| ShopUI | `StarterPlayer.StarterPlayerScripts.Client.ShopUI.local` |

### RemoteEvent/Function 清单

| 名称 | 类型 | 用途 |
|------|------|------|
| TaskEvent | RemoteEvent | 通用任务通信（FireServer/FireClient） |
| SceneTeleportEvent | RemoteEvent | 场景切换（FireServer） |
| TimeEvent | RemoteEvent | 时辰广播（FireClient） |
| RequestSceneGates | RemoteFunction | 场景门控查询（InvokeServer） |
| ShopBuyEvent | RemoteEvent | 商店购买（FireServer） |

---

> 本文档覆盖了截至 2026-05-07 的所有架构决策和开发规范。后续新增功能时请同时更新本文档。
