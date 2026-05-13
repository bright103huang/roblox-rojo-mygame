# 🏗️ MyGame 项目架构与 Superpowers 全流程执行规范 (claude.md)

## 🤖 核心元准则 (Meta-Protocol)

你现在是具备 **14 个 Superpowers 技能** 的全自动软件工程主 agent。
**每次任务必须严格按照以下工作流执行**，禁止跳过任何步骤。

> 每个子代理必须通过主 agent 调度和审核，TDD、上下文隔离、并行/串行执行、验证、分支合并和沉淀必须被强制执行。

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

## 3️⃣ 分区开发 (using-git-worktrees)

* **目标**：保证每个任务或子代理在独立 Git 工作树执行，防止文件/上下文污染。
* **操作**：

  1. 每个任务生成独立分支：

     ```bash
     git checkout -b feature/<任务名>
     ```
  2. 子代理只允许修改其负责的模块 / 文件范围。
* **约束**：

  * NO BRANCH → 禁止操作 src/ 文件
  * 工作完成前禁止合并到主分支

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

## TDD 强制流程（必须遵守）
1. 分析任务，识别可提取的纯逻辑（计算公式/数据校验/状态转换）
2. 在 tests/run.lua 底部添加 describe/it 测试用例（RED case）
3. 运行验证 RED：cd 项目根目录 && luau tests/run.lua → 预期新测试 FAIL
4. 实现纯函数（GREEN）
5. 再次运行 luau tests/run.lua → 预期 ALL PASS
6. 编写 Roblox 胶水层调用纯函数（保持最薄）
7. 将测试结果（stdout 输出）返回主 agent

## 提取纯逻辑原则
- 纯函数 = 入参出参都是基本类型/table，不依赖任何 Roblox API
- Roblox 胶水层只做：读参数 → 调纯函数 → 写回结果/FireEvent
- 如果任务没有可提取的纯逻辑（纯 UI 绑定等），需说明原因

## 约束
- 禁止修改 tests/run.lua 已有测试（只追加新的 describe）
- 禁止修改其他子代理的文件
- 遇到问题必须上报，禁止跳过步骤
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
* **TEST EVIDENCE**：子代理必须提供 `luau tests/run.lua` 测试通过的证据，否则禁止合并

---

# ⚡ 启动任务示例

用户输入：

```text
启动任务：新增炼丹系统
```

主 agent 回复：

```
收到。正在启动 Superpowers 流水线：

[技能: brainstorming] 检索 PROJECT_KNOWLEDGE.md 确认数值和任务因果影响...
[技能: writing-plans] 生成任务拆解和子代理列表...
[技能: using-git-worktrees] 创建 feature/AlchemySystem 分支...
[技能: subagent-driven-development] 生成独立子代理，上下文隔离，绑定 TDD checklist...
[技能: dispatching-parallel-agents] 并行探索未知子领域...
[技能: executing-plans] 子代理开始执行 RED → VERIFY → GREEN → REFACTOR...
[技能: systematic-debugging] 遇到报错进行复现、隔离、根因分析、验证...
[技能: verification-before-completion] 全量测试通过，TDD 检查完成...
[技能: requesting-code-review] 发起代码审查，收集修改意见...
[技能: finishing-a-development-branch] 合并 feature 分支，删除临时工作树...
[技能: writing-skills] 沉淀边界模板、workflow 模板和 Lessons Learned...
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