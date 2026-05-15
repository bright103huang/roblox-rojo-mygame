🏗️ MyGame 项目架构与 Superpowers 全流程执行规范 (claude.md)

🤖 核心元准则 (Meta-Protocol) — USING-SUPERPOWERS 铁律

using-superpowers 不是一句口号，而是一个必须严格执行的**操作模式闸门**。以下规则不可协商、不可跳过。

## 接令五步检查 (Mandatory Five-Step Check)

**每次收到用户指令后，必须依次执行以下五步，任何一步未完成则禁止进入下一步：**

```
Step 1 — 指令分类
  │  判定：这是”设计讨论”、”Bug修复”、”功能实现”、”配置修改”、”知识查询”中的哪一类？
  │  输出：[分类结果]
  │
Step 2 — 技能映射
  │  从技能列表中选出所有可能相关的技能（至少 1 个，通常 2-3 个）
  │  输出：[技能列表] + [选择理由]
  │
Step 3 — Skill 工具调用
  │  调用 Skill 工具加载选中技能，读取其内容（不是 Read，是 Skill 工具！）
  │  输出：[技能已加载]
  │
Step 4 — 流程承诺
  │  根据技能要求，声明本次任务将走哪条路径
  │  例如：brainstorming → writing-plans → (worktree) → 执行
  │  输出：[执行路径]
  │
Step 5 — 执行
  │  按 Step 4 的路径开始执行
  │
  └── 任何步骤发现不适用 → 回到 Step 2 重新映射
```

## 铁律四条 (Non-Negotiable Rules)

**铁律 1：Skill 工具调用优先**
在输出任何内容（包括”让我看看”、”我需要先了解”等回应）之前，必须先调用 Skill 工具加载技能。禁止先说话再调技能。

**铁律 2：永不跳过 brainstorming**
任何修改代码的操作，无论多小，都必须经过 brainstorming → writing-plans 路径。没有”这不值得做设计”的例外。

**铁律 3：元评估日志**
每次激活 using-superpowers 后，第一条回复必须以以下格式输出元评估：

```
[元评估]
指令分类：<分类结果>
匹配技能：[技能1](理由), [技能2](理由)
执行路径：<路径声明>
风险等级：高/中/低
```

**铁律 4：违规自纠**
如果在执行中发现跳过了上述步骤，必须立即 STOP 当前操作，回退到跳过的步骤重新执行。禁止”下次注意”式的带病推进。

---

# 🌊 Superpowers 全流程工作流

## 1️⃣ 对齐需求 (brainstorming)

* **目标**：确保主 agent 与用户需求完全一致，并对项目知识库（PROJECT_KNOWLEDGE.md / claude.md / 因果数值矩阵 / TaskHandler 架构 / 红线事件表）进行深度检索。
* **操作**：

  1. 收集用户输入的需求描述。
  2. 分析对现有系统的影响：2D 横版约束、状态链、任务因果。
  3. 输出需求分析报告，包含潜在风险、涉及模块和初步实现策略。
* **产出**：

  * TODO.md 任务列表
  * 风险评估表

---

## 2️⃣ 拆分任务 (writing-plans)

* **目标**：将需求拆解为可执行的原子任务。
* **操作**：

  1. 按“认知域”拆分（UI、TaskHandler、StatusService、Scene、AI、Data、Network 等）。
  2. 为每个任务生成 **子代理 Prompt 模板**，严格包含 TDD 流程。
  3. 生成任务执行顺序 / 并行策略文档。
* **产出**：

  * 每个任务的子代理 prompt 模板
  * 串行/并行执行计划表

---

## 3️⃣ 分区开发 — using-git-worktrees（强制）

**writing-plans 完成后，必须立即执行此步骤，禁止跳过。**

* **目标**：保证每个任务在独立 Git 工作树执行，main 分支始终保持干净。
* **操作**：

  1. 使用 `EnterWorktree` 创建工作树或在主 repo 创建独立分支：
     ```bash
     git checkout -b feat/<功能名>
     ```
  2. 所有实现代码只写入该分支/工作树。
  3. 在整个实现期间，main 分支不产生任何提交。
* **约束**：

  * **NO BRANCH / NO WORKTREE → 禁止写任何代码**
  * 工作完成前禁止合并到 main
  * 如果接续的会话发现 main 已被污染（前序未使用 worktree），必须先建分支补救，不得继续在 main 上堆叠

---

## 4️⃣ 任务执行 — 纯逻辑提取 + TDD（每个任务内循环）

**工作树就绪后，对 writing-plans 拆解的每个任务，依次执行：**

  1. **纯逻辑提取检查** — 分析任务："有没有一个函数不依赖 Roblox API 也能跑？"
     - ✅ 有 → 在 `Shared/PureLogic/` 下创建纯函数模块
       1. 在 `tests/run.lua` 写测试 → 运行 `luau tests/run.lua` → **RED**
       2. 实现纯函数 → 运行 `luau tests/run.lua` → **GREEN**
       3. 在 Roblox 胶水代码中 `require()` 该模块
     - ❌ 无（纯 UI/Instance 创建）→ 提交时说明理由

  2. 实现 Roblox 胶水代码
  3. 提交
  4. 进入下一个任务，重复步骤 1-3

* 无法提取纯逻辑的理由示例："BreathUI — 全部依赖 TweenService/UserInputService"
* `require` 路径格式: `require("../ReplicatedStorage/Shared/PureLogic/模块名")`

---

## 4️⃣ 执行与探索

### a. 串行子代理执行 (subagent-driven-development)

* 每个子代理独立上下文，负责单一认知域。
* 按 TDD 流程执行：

  1. 编写 RED case（失败断言）
  2. VERIFY RED
  3. 编写最简实现（GREEN）
  4. REFACTOR
* 输出必须返回主 agent，主 agent 审核后整合。

### b. 并行探索 (dispatching-parallel-agents)

* 对于未知或复杂任务：

  * 同时生成多个子代理，每个独立上下文处理不同子领域。
  * 主 agent 负责合并输出，并解决冲突。
* 子代理仍必须严格遵守 TDD 流程。

### c. 执行计划 (executing-plans)

* 主 agent 调度所有子代理，按照拆解计划执行。
* 禁止子代理跳过 RED → GREEN → REFACTOR 流程。
* 输出结果必须整合到主 agent 汇总上下文。

---

## 5️⃣ 系统化调试 (systematic-debugging)

* 遇到错误或测试失败时：

  1. 复现问题
  2. 隔离变量 / 上下文
  3. 根因分析
  4. 修复并再次运行 TDD
* 主 agent 全程监督，子代理报告问题前禁止继续执行下一个阶段。

---

## 6️⃣ 完成前验证 (verification-before-completion)

* 主 agent 必须确认：

  * 所有 RED case 存在且验证
  * GREEN 已通过
  * REFACTOR 已完成
  * 子代理上下文未污染其他模块
* 未通过 → 返回子代理补全，禁止合并

---

## 7️⃣ 代码审查 (requesting-code-review / receiving-code-review)

* 主 agent 负责发起代码审查：

  * 对每个子代理输出或分支进行静态审查、TDD 验证、边界检查
* 子代理必须根据审查意见修改，并重新验证 TDD 流程。
* 用户可触发审查请求，主 agent 汇总反馈。

---

## 8️⃣ 分支合并 (finishing-a-development-branch)

* 仅在：

  * TDD 流程完成
  * 子代理审核通过
  * 所有依赖模块整合完成
* 主 agent 执行：

  ```bash
  git merge feature/<任务名> -> main
  git branch -d feature/<任务名>
  ```
* 合并同时更新 workflow 文档和边界模板。

---

## 9️⃣ 沉淀知识 (writing-skills)

* 记录：

  * 本次任务发现的 Luau 性能特性
  * 特殊逻辑
  * 认知域边界模板
  * workflow 模板
* 主 agent 负责：

  * 保存边界模板
  * 保存 TDD checklist 模板
  * 清理临时子代理上下文

---

# 🔧 子代理 Prompt 模板示例

```text
你是子代理，负责 [认知域名称]。
任务：[任务名称]
规则：
1. 严格 TDD 流程：
   - RED case → VERIFY RED → GREEN → REFACTOR
2. 禁止修改主上下文和其他子代理上下文
3. 输出结果必须返回主 agent
4. 遇到问题必须上报，禁止跳过任何步骤
5. 完成任务后立即销毁上下文
6. 所有边界和流程遵循主 agent 提供的边界模板和 workflow 模板
```

---

# 🔒 主 agent 强制行为

* **NO BRANCH, NO WORK**：无独立分支禁止操作 src/
* **NO RED, NO GREEN**：RED case 未写禁止实现业务逻辑
* **KNOWLEDGE ALIGNMENT**：brainstorming 阶段必须引用 PROJECT_KNOWLEDGE.md
* **TDD GATEKEEPER**：主 agent 必须审核每个子代理输出
* **CONTEXT ISOLATION**：所有子代理上下文独立
* **PARALLEL CONTROL**：并行子代理的结果必须主 agent 汇总
* **SINGLE INTERFACE**：用户仅能与主 agent 交互

---

# ⚡ 启动任务示例

用户输入：

```text
新增一个炼丹系统
```


```
主 agent 回复：

[元评估]
指令分类：功能实现（新增完整系统）
匹配技能：
  - brainstorming（需要先对齐需求和设计）
  - writing-plans（需要拆解多模块任务）
  - roblox-2d-game（项目专属规则）
执行路径：brainstorming → writing-plans → 实施
风险等级：高（涉及数值矩阵与逻辑状态变更）

我正在使用 brainstorming 技能来对齐设计。在创建执行计划前，我需要与你确认以下设计要点：

......

[后续流水线预告]：
设计批准后 → writing-plans 拆解任务 → worktree 隔离开发 → TDD 驱动实施 → verification 验证 → code review → 合并。
```
## 🧠 输出安全规则（防止超长输出）

### 1. 控制一次性大范围分析
不要同时分析多个系统（如炼丹/商店/背包）。
每次尽量只处理一个模块或一个 Bug。

### 2. 分步执行
分析必须拆成步骤：
- 第一步：定位相关文件
- 第二步：只读取关键函数
- 第三步：给出结论 + 下一步建议

禁止一次输出完整全局分析。

### 3. 单次输出限制
每次回答控制在较小范围（约3000~5000 tokens）。
如果内容过多，必须中断并输出：
“需要继续（CONTINUE）”

### 4. 文件读取限制
- 不要整文件输出
- 只读关键函数或片段
- 优先搜索关键词，而不是全文读取

### 5. 多问题处理规则
如果有多个 Bug：
- 一次只处理一个
- 其他必须等待下一轮指令
---