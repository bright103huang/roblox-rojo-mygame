# 子代理 TDD 强制执行 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 更新 CLAUDE.md 子代理 prompt 模板和 tests/run.lua 头部注释，强制子代理执行提取纯逻辑 + TDD 测试流程

**Architecture:** 仅修改 2 个配置文件（CLAUDE.md + tests/run.lua），不碰任何游戏代码。改动点有三处：子代理 prompt 模板替换、主 agent 规则追加、测试文件头部加模板注释。

**Tech Stack:** Markdown + Luau

---

### Task 1: 更新 CLAUDE.md 子代理 Prompt 模板

**Files:**
- Modify: `CLAUDE.md:158-171`

- [ ] **Step 1: 替换子代理 prompt 模板**

把原模板（第 158-171 行）替换为带具体 TDD 命令的模板（替换后内容见下方）。

```markdown
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
```

- [ ] **Step 2: 在 CLAUDE.md `# 🔒 主 agent 强制行为` 区域追加 TEST EVIDENCE 规则**

在 `* **SINGLE INTERFACE**` 下方追加一行：

```markdown
* **TEST EVIDENCE**：子代理必须提供 `luau tests/run.lua` 测试通过的证据，否则禁止合并
```

- [ ] **Step 3: 提交**

```bash
git add CLAUDE.md
git commit -m "feat: enforce sub-agent TDD with explicit test commands and TEST EVIDENCE rule"
```

---

### Task 2: 更新 tests/run.lua 头部 TDD 模板注释

**Files:**
- Modify: `tests/run.lua:1-3`

- [ ] **Step 1: 在 tests/run.lua 头部插入 TDD 模板注释**

在第 3 行（`-- 用法: luau tests/run.lua（在项目根目录执行）`）之后追加：

```lua
-- ====== 子代理 TDD 模板 ======
-- 如何为你的模块写测试：
-- 1. 将业务逻辑提取为纯函数（不依赖 Roblox API）
-- 2. 在文件底部追加 describe/it 测试块
-- 3. 运行验证: luau tests/run.lua
-- 4. 先写测试（RED）→ 验证失败 → 实现逻辑（GREEN）
-- 5. 参考下方 StatusService 测试区（第 ~197 行）的提取模式
-- ============================
```

- [ ] **Step 2: 运行测试确认一切正常**

运行: `cd "C:\Users\lenovo\Desktop\MyGame" && luau tests/run.lua`
预期: 所有现有测试通过

- [ ] **Step 3: 提交**

```bash
git add tests/run.lua
git commit -m "feat: add TDD template comments for sub-agents"
```
