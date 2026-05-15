# 家场景玩法改造设计

- 日期：2026-05-15
- 状态：设计稿

---

## 1. 概述

家场景定位为"服药打坐，炼化提升"，目前玩法单一（仅有被动冥想和每日祈福）。本次改造的目的是：

> 让家**更大更温馨**，同时用**互动小游戏**替代被动挂机，使打坐和睡觉成为有操作感的"任务"。

**关键规则**：服用丹药**必须处于打坐状态**（炼化丹药需要打坐），且目前打坐只能在家中进行。这形成"仙丹阁买药 → 回家打坐炼化"的完整游玩循环。

涉及模块：SceneSetup.server.lua、ShopService.server.lua、ShopUI.local.lua、StatusService、TimeService、DataManager、BreathUI.local.lua（新增）、SleepUI.local.lua（新增）、PrayerUI.local.lua（新增）、Config 文件。

---

## 2. 空间布局与视觉升级

### 2.1 尺寸扩展

| 维度 | 当前 | 改造后 |
|------|------|--------|
| X 轴范围 | -14 ~ +14（共 30 格） | -24 ~ +24（共 50 格） |
| Z 轴 | -4 ~ +4（不变） | 不变 |

### 2.2 分区布局

```
-24           -14           0           +14            +24
  │  祈福区   │   卧室区    │   打坐区    │   休闲区     │
  │  ·香炉    │  ·床(卧榻)  │  ·蓝色蒲团  │  ·小桌茶具   │
  │  ·药架    │  ·屏风(隔断)│  ·暖色地毯  │  ·挂画      │
  │  ·蜡烛    │  ·床头灯   │             │  ·窗        │
  │  ·蒲团    │            │             │             │
```

### 2.3 视觉升级清单

| 项目 | 具体改造 |
|------|---------|
| **蓝色蒲团** | 主色 `Bright blue`，内圈 `Bright orange` 点缀，尺寸 `4×0.3×4` |
| **地毯** | 蒲团下方圆形暖色地毯 (`Bright orange` / `Bright yellow`)，视觉锚点 |
| **屏风** | 卧室与打坐区之间的隔断，Z=0 后侧装饰层 |
| **窗** | 后墙两侧各加一扇窗（透光半透明材质），改善封闭感 |
| **床** | 带卧榻样式的床（`createDecor` 拼装），位于卧室区 |
| **暖光** | 每区一盏 PointLight：中心暖黄、卧室暖白、祈福台暗金 |
| **挂画/字画** | 后墙装饰层增加字画卷轴 |
| **香炉** | 祈福台旁添香炉装饰（飘烟效果用 ParticleEmitter） |

---

## 3. 祈福台仪式感

### 3.1 当前问题

目前祈福台只是"触碰一下 → 加 5 功德"，没有仪式感。

### 3.2 改造方案

祈福流程：

1. **走近祈福台** → 角色播放**跪拜动画**（类似坐姿动画，使用 AnimationTrack）
2. **弹出选择界面** — 三种祈福选项：

| 选项 | 消耗 | 功德收益 | 额外效果 |
|------|------|---------|---------|
| 诚心礼拜 | 无 | 3 功德 | 戾气 -1 |
| 焚香祷告 | 10 仙晶 | 8 功德 | 戾气 -3，精神 +5 |
| 虔诚供奉 | 50 仙晶 | 20 功德 | 戾气 -5，精神 +10，微量修为 |

3. **选择后** → 播放对应动画片段（上香/献果）→ 屏幕淡入"功德 +X" → 结算

**限制**：每日仅可祈福一次（保留现有 `LastPrayerDate` 逻辑）

---

## 4. 打坐：气息循环交互

### 4.1 触发

- 触摸蓝色蒲团 → 角色播放**盘腿坐**动画
- 角色 CFrame 对齐蒲团中心
- Humanoid.WalkSpeed = 0，AutoRotate = false
- 呼吸光环 UI（ScreenGui）淡入

### 4.2 呼吸节奏玩法

三个相位循环执行：

| 相位 | 时长 | 光环表现 | 玩家操作 |
|------|------|---------|---------|
| 吸气 | 2.0s | 外环从内圈 → 最大 | 按住 F |
| 屏息 | 1.5s | 外环保持最大，高亮 | 保持按住 |
| 呼气 | 2.0s | 外环从最大 → 内圈 | 松开 F |

### 4.3 判定规则

| 判定 | 窗口 | 恢复倍率 |
|------|------|---------|
| 完美 | ±0.15s | ×1.5 |
| 精准 | ±0.30s | ×1.2 |
| 普通 | 超出窗口但执行了操作 | ×1.0 |
| 失误 | 未操作 | ×0.5 |

### 4.4 入定层数

| 连续完美次数 | 层名 | 效果 |
|------------|------|------|
| 3 | 初定 | 恢复 +30% |
| 6 | 入定 | 恢复 +60%，每轮 +1 修为 exp |
| 10 | 禅定 | 恢复 ×2，每轮 +2 修为 exp |

- 一旦判定非完美 → 层数重置为 0
- 每次完美 → 层数说明短暂闪现在 UI 上

### 4.5 戾气影响

| 戾气值 | 效果 |
|--------|------|
| > 30 | 呼吸节奏加快（吸气 1.5s/呼气 1.5s），判定窗口缩窄 20% |
| > 50 | 节奏更快 + 光环轻微抖动（位置脉动），无法入定及以上层级 |
| > 70 | 无法入座（保留现有逻辑） |

### 4.6 打坐中服用丹药（炼化）

打坐呼吸 UI 中集成**丹药面板**，显示玩家背包中的丹药列表。

#### 操作流程

1. 呼吸光环运行时，屏幕左侧浮现**丹药栏**（竖排图标，显示丹药名称 + 剩余数量）
2. 玩家点击丹药图标 → 弹出呼吸光环中央的**服用确认**（短暂暂停一轮呼吸判定）
3. 确认后 → 客户端发送 `UseItem:Shop` 给服务器，附带 `{ ItemKey = "HuiQiDan", IsMeditating = true }`
4. 服务器校验 `IsMeditating == true`，若不满足则拒绝（返回错误消息）
5. 服务器从背包扣除丹药 → 计算效果（打坐状态效果 ×1.5）→ 应用 + 通知客户端

#### 呼吸节奏对丹药吸收的影响

丹药炼化效果与当前呼吸判定挂钩：

| 服用时的判定状态 | 丹药吸收倍率 | 视觉效果 |
|----------------|-------------|---------|
| 完美（吸气峰值时服用） | ×2.0（叠加 ×1.5 打坐基础加成） | 光环爆闪，金色粒子扩散 |
| 精准 | ×1.5 | 光环亮起 |
| 普通 | ×1.0（仅有打坐基础 ×1.5） | 光环微微变色 |
| 失误 | ×0.5（吸收效率低） | 光环暗红闪烁 |

**副作用**：服用丹药会打断入定层数（归零），因为"药力冲击经脉"。

**服务器强制规则**：
- `ShopService:UseItem()` 已在服务器端接受 `isMeditating` 参数
- 修改验证逻辑：若 `isMeditating == false`，返回 `{ Success = false, Message = "丹药需在打坐时炼化" }`
- 从 ShopUI 发起的非打坐 `UseItem:Shop` 调用，服务器强制执行拦截

#### 已有基础设施

- `ShopService:UseItem(player, itemKey, isMeditating)` — 已实现，`isMeditating = true` 时效果 ×1.5
- `数据字段 data.Backpack` — 已实现，格式 `{ HuiQiDan = 3, ... }`
- 仅需在 `ShopService.server.lua` 增加强制校验：`isMeditating == false` → 拒绝使用
- 仅需在 `ShopUI.local.lua` 的 `UseItem` 调用中追加 `IsMeditating` 字段

### 4.7 退出

- 按 F 或 Esc（解除按键绑定）→ 停止动画，关闭 UI，角色站起
- 入定层数清空，无其他惩罚

### 4.8 每轮恢复结算

每轮呼吸结束（约 5.5s）服务器结算一次：

```
体力恢复 = floor(3 × 判定倍率 × 入定加成)
精神恢复 = floor(6 × 判定倍率 × 入定加成)
疲劳消除 = max(1, floor(2 × 判定倍率 × 入定加成))
```

---

## 5. 睡觉：梦境安宁交互

### 5.1 触发

- 触摸床 → 角色播放**躺卧**动画
- 屏幕渐暗 → 睡眠 UI 浮现
- 服务器记录 `LastSleptDay`（一日一次限制）

### 5.2 安宁平衡玩法

**核心机制**：

```
心神指针：◀═══════●═══════▶
                  ↑ 安稳区（绿色）
```

- 指针在左右两端来回摆动，物理模拟（速度曲线）
- 中间一段为绿色 **安稳区**（宽度约 40% 的总范围）
- 玩家**点击鼠标** → 指针向右弹一小段
- **不点击** → 指针自然向左摆动
- 目标是找到节奏，让指针保持在安稳区内

**梦魇扰动**（防止单调 + 体现戾气影响）：

- 每 10-15 秒检查戾气 > 0 → 概率触发梦魇
- 梦魇效果：
  - 屏幕闪烁一次
  - 指针突然剧烈摆动 2 次
  - 安稳区缩小至原来 50%，持续 3 秒
- 戾气越高 → 触发越频繁，摆动幅度越大

### 5.3 持续时间

安宁玩法共 **20 秒**（现实时间），结束后服务器一次性结算。

### 5.4 结算

| 质量 | 安稳区占比 | 恢复效果 |
|------|-----------|---------|
| 酣睡 | ≥ 80% | 体力全满、精神+20、疲劳归零、戾气-8、修为+3 |
| 浅睡 | ≥ 50% | 体力+30、精神+10、疲劳-15、戾气-3、修为+1 |
| 辗转 | ≥ 25% | 体力+15、精神+5、疲劳-5 |
| 失眠 | < 25% | 体力+5、疲劳-2 |

- **提前中断**（Esc）：时间照扣 2 时辰，只给失眠级恢复
- 梦魇中指针持续出界 3 秒 → 直接失眠（吓醒）

### 5.5 时间推进（方案 A）

安宁玩法结束后 → 客户端发 RemoteEvent 给服务器 → 服务器：
1. 检查 `LastSleptDay` 防止重复
2. 记录 `LastSleptDay = today`
3. 调用 `TimeService:AdvanceHours(2)` 推进 2 个时辰
4. 根据判定结果结算恢复

---

## 6. 因果数值平衡

| 维度 | 打坐（一次完美循环） | 睡觉 | 丹药炼化（打坐中服用） |
|------|---------------------|------|----------------------|
| 体力恢复 | +3 ~ +6（×层数） | +15 ~ 全满 | 丹药效果 ×1.5 ~ ×3.0 |
| 精神恢复 | +6 ~ +12（×层数） | +5 ~ +20 | 丹药效果 ×1.5 ~ ×3.0 |
| 疲劳消除 | -2 ~ -4 | -5 ~ 归零 | — |
| 戾气影响 | 节奏加快 + 判定窗口缩窄 | 引发梦魇扰动 | 影响服用时的判定品质 |
| 时间流逝 | 无 | 消耗 2 时辰 | 无 |
| 中断代价 | 层数清空 | 时间照扣，只给失眠 | 层数清空 + 丹药已消耗 |
| 额外收益 | 入定层 → 微弱修为 | 酣睡 → 修为 | 丹药附带永久属性提升 |
| 频率限制 | 不限 | 一日一次 | 受丹药库存限制 |
| 定位 | 短平快恢复 | 大投入大产出 | 资源→永久成长的转换桥 |

---

## 7. 技术实现概览

### 7.1 文件清单

| 文件 | 类型 | 作用 |
|------|------|------|
| `ServerScriptService/server/Systems/SceneSetup.server.lua` | Script | 家场景布局改造（扩宽、装饰、床、祈福台升级） |
| `StarterPlayer/StarterPlayerScripts/client/BreathUI.local.lua` | LocalScript | 呼吸光环 UI（打坐交互 + 丹药炼化面板） |
| `StarterPlayer/StarterPlayerScripts/client/SleepUI.local.lua` | LocalScript | 睡眠安宁平衡 UI（睡觉交互） |
| `StarterPlayer/StarterPlayerScripts/client/PrayerUI.local.lua` | LocalScript | 祈福选择界面 |
| `ServerScriptService/server/Systems/ShopService.server.lua` | Script | 修改 `UseItem` 强制校验打坐状态 |
| `StarterPlayer/StarterPlayerScripts/client/ShopUI.local.lua` | LocalScript | 修改丹药使用按钮，传入 `IsMeditating` |
| `ReplicatedStorage/Shared/Modules/AnimationFactory.lua` | ModuleScript | 程序化生成坐姿/躺卧/跪拜 KeyframeSequence |
| `ReplicatedStorage/Shared/Config/StatsConfig.lua` | ModuleScript | 新增打坐/睡觉数值常量 |
| `ReplicatedStorage/Animations/` | 文件夹 | 坐姿、躺卧、跪拜动画 Asset |

### 7.2 程序化动画生成（无外部资源）

所有角色动画使用 `KeyframeSequence` + `Pose` 在代码中动态生成，不依赖 .rbxm 文件或 Animation ID。

#### 实现方式

```lua
-- 在 ReplicatedStorage 创建一个 AnimationFactory 模块
-- 为每个动画生成一个 KeyframeSequence，然后通过 Humanoid:LoadAnimation() 播放
```

#### 三种动画的关键帧设计

**盘腿坐（打坐）**：
| 时间 | 部位 | CFrame 变换 | 说明 |
|------|------|------------|------|
| 0.0s | LowerTorso | CFrame.Angles(0, 0, -0.1) | 臀部下沉 |
| 0.0s | LeftUpperLeg | CFrame.Angles(-0.8, 0.3, 0) | 左腿抬起外翻 |
| 0.0s | RightUpperLeg | CFrame.Angles(-0.8, -0.3, 0) | 右腿抬起外翻 |
| 0.0s | LeftLowerLeg | CFrame.Angles(1.2, 0, 0) | 左小腿折叠 |
| 0.0s | RightLowerLeg | CFrame.Angles(1.2, 0, 0) | 右小腿折叠 |
| 0.0s | HumanoidRootPart | CFrame.new(0, -1.2, 0) | 整体降低到蒲团高度 |
| 0.3s | 同上，ease 过渡 | 从站姿过渡到坐姿 | Weight 渐变 |

**躺卧（睡觉）**：
| 时间 | 部位 | CFrame 变换 | 说明 |
|------|------|------------|------|
| 0.0s → 0.5s | HumanoidRootPart | CFrame.Angles(0, 0, math.rad(-90)) | 身体从垂直→水平 |
| 0.0s → 0.5s | UpperTorso | CFrame.Angles(0, 0, math.rad(-90)) | 跟随身体旋转 |
| 0.0s → 0.5s | LowerTorso | CFrame.Angles(0, 0, math.rad(-90)) | 跟随 |
| 0.3s → 0.5s | LeftUpperArm | CFrame.Angles(0, 0, 0.2) | 手臂放松置于身侧 |

**跪拜（祈福）**：
| 时间 | 部位 | CFrame 变换 | 说明 |
|------|------|------------|------|
| 0.0s | HumanoidRootPart | CFrame.new(0, -1, 0) | 降低到跪姿 |
| 0.0s | LeftUpperLeg | CFrame.Angles(1.2, 0, 0) | 腿部折叠跪下 |
| 0.0s | RightUpperLeg | CFrame.Angles(1.2, 0, 0) | 腿部折叠跪下 |
| 0.5s (拜) | UpperTorso | CFrame.Angles(math.rad(30), 0, 0) | 上半身前倾 |
| 1.0s (起) | UpperTorso | CFrame.Angles(0, 0, 0) | 直起身 |

#### 通用播放器

```lua
local function playAnimation(humanoid, sequence, looped)
    local track = humanoid:LoadAnimation(sequence)
    track.Priority = Enum.AnimationPriority.Action
    track.Looped = looped or false
    track:Play()
    return track  -- 调用方保存引用，用于 Stop
end
```

#### 2D 侧视角适配说明

由于摄像机从背后上方拍摄（`(0, 10, 30)`），角色面向 Z+ 方向：
- **盘腿坐**：从后方看，双腿向外侧折叠，躯干直立，肩臂自然下垂
- **躺卧**：角色绕 Z 轴旋转 90°，从后方看呈水平横卧
- **跪拜**：躯干前倾时，从后方能看到背部弓起的轮廓

所有 CFrame 值以 Roblox Character Rig（R15）为基准。Pose 的 CFrame 是相对于其 Motor6D 原始绑定位置的偏移。

### 7.3 RemoteEvent

新增 `HomeEvents` RemoteEvent（双向）：

- 客户端 → 服务器：`BreathResult`（每轮呼吸判定结果）
- 客户端 → 服务器：`SleepComplete`（安宁玩法结束 + 判定数据）
- 客户端 → 服务器：`PrayerChoice`（祈福选项）
- 服务器 → 客户端：`BreathSettlement`（本轮恢复数值）
- 服务器 → 客户端：`SleepSettlement`（本次睡觉恢复数值）

**服用丹药**复用已有的 `ShopEvent`（`UseItem:Shop` 消息），只需在 `contextData` 中追加 `IsMeditating = true`。

### 7.4 防止作弊

- 服务器端时间戳验证：客户端上报的按键时间必须在合理范围内（与 Heartbeat 累计时间偏差 < 0.5s）
- 打坐每轮结算由服务器计算（客户端只上报判定档位，服务器根据时间窗口二次验证）
- 睡觉数据同样由服务器计算（客户端上报"安稳区占比"，服务器根据开始到结束的耗时做合理性检查）

### 7.5 存档字段

在 DataManager.DEFAULT_DATA 新增：

```lua
LastPrayerDate = "",     -- 已存在
PrayerOption = "",       -- 新增：最近选择的祈福类型
LastSleptDay = "",       -- 新增：最后睡觉日（格式 YYYYMMDD）
```

---

## 8. 未决问题

- 呼吸光环 UI 的具体视觉风格（简约光圈 vs 禅意风格）
- 三种动画的 Pose CFrame 需要在游戏中实际调试微调（不同角色体型可能有差异）
