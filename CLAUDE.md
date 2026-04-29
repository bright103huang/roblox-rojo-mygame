# MyGame 项目架构指南

## 任务处理器（Task Handler）架构

### 概述

打工任务系统采用 **Task Handler 模式**，将每种任务封装为独立的处理器模块，通过统一的调度器路由交互事件。

### 架构图

```
Client (TaskClient.local.luau)
  │  FireServer("Pick:Deliver", ...)
  │  FireServer("Drop:Deliver", ...)
  ▼
TaskService (调度器)
  │  根据 action 中的任务名路由到对应处理器
  ├─▶ DeliverTask.lua     ← 传菜任务
  └─▶ (预留) PlantTask.lua ← 蟠桃种植
```

### 核心文件

| 文件 | 职责 |
|------|------|
| `Config/TaskConfig.luau` | 定义所有任务的元数据（交互区域、行为开关、成长参数） |
| `Systems/TaskService.server.lua` | 调度器：加载处理器、路由客户端事件、回退出生点 |
| `Tasks/DeliverTask.lua` | 传菜处理器：目标分配、端盘放盘、盘子生成、速度成长 |
| `Client/TaskClient.local.luau` | 客户端：从 TaskConfig 读取交互区域、动态绑定触摸事件 |

### TaskConfig 配置说明

在 `ReplicatedStorage.Shared.Config.TaskConfig` 中新增任务：

```lua
Tasks = {
    NewTask = {
        DisplayName = "任务名称",
        Description = "任务描述",
        HandlerModule = "Tasks.NewTaskHandler",  -- 处理器路径
        InteractionAreas = {
            Pickup = { PartName = "PickupPartName", FireAction = "Pick" },
            Drop   = { PartName = "DropPartName",   FireAction = "Drop",
                       NeedsAttribute = "AttrName" },
        },
        RewardType = "RewardKey",        -- 对应 EconomyConfig.Rewards 的键
        TargetRequired = false,           -- 是否需要目标分配
        SpawnOnComplete = false,          -- 完成时是否生成物体
        -- 可选：速度成长配置
        SpeedGrowth = {
            Enabled = false,
            DeliveriesPerLevel = 6,
            SpeedPerLevel = 1,
            MaxBonusSpeed = 10,
        },
    },
}
```

### 新增任务的步骤

1. 在 `TaskConfig.luau` 的 `Tasks` 表中添加新任务定义
2. 在 `Server/Tasks/` 下新建处理器文件（如 `PlantTask.lua`）
3. 处理器需实现接口：
   - `OnPlayerPickup(player, area)` → `boolean`
   - `OnPlayerDrop(player, area)` → `boolean, resultType`
4. （可选）在 `EconomyConfig.lua` 中添加对应的奖励配置
5. 无需修改 TaskService 或 TaskClient

---

## 预留接口说明

### 体力系统预留

数据层已预留扩展点：
- `DataManager:GetData(player)` 返回的数据表可在 `getDefaultData()` 中添加 `Stamina` 字段
- `DataManager:UpdateField()` 已支持任意字段读写
- 建议新增字段：`MaxStamina = 100`, `CurrentStamina = 100`, `StaminaRegenRate = 1`

接入建议：
- 在 `SceneManager` 的 `CharacterAdded` 回调中增加体力 UI 初始化
- 创建独立 `StaminaService` 模块处理恢复逻辑

### 时间系统预留

场景和时间相关：
- `SceneConfig.luau` 已支持场景坐标和叙事数据配置
- `DataManager` 的 playerData 可扩展 `LastLoginTime`, `DailyResetTime` 等字段
- 建议新增 `TimeService`（客户端/服务端双端）处理：
  - 天庭时辰系统（白天/夜晚）
  - 任务刷新周期
  - 限时活动窗口

### 速度成长系统

已在 DeliverTask 中实现：
- 每完成 6 次传菜，永久提升 WalkSpeed 1 点
- 上限 10 点额外速度
- 数据存入 DataStore（通过 DataManager）
- 玩家重登时自动恢复速度加成
- WalkSpeed 基础值固定 16（Roblox 默认），成长加成在此基础上叠加

### 注意：WalkSpeed 配置历史

`PlayerConfig.lua` 中的 `WalkSpeed = 64` 此前未被任何代码引用/应用，属于无效配置。当前速度系统已改用数据驱动成长方案，不再依赖 PlayerConfig 中的 WalkSpeed 值。
