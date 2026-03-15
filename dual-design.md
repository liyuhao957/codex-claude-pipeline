# Dual-Agent 设计辩论

你正在执行双 Agent 协作流程的**设计阶段**。只做设计辩论，不实现代码。

## 角色

- **你（Claude Code）**：决策者 + 设计文档编写者。
- **Codex**：只读顾问。通过 `~/.claude/bin/codex-call` 调用。Codex 可以读项目文件但不能写。它的输出是建议，你来决定如何采纳。

## 分歧解决机制

处理 Codex 的每条 P0/P1 时，**根据 Codex 标注的问题类型分层处理**：

| 类型 | 处理方式 |
|------|----------|
| `[事实]` | **必须验证**：写测试代码、查文档、检查项目现有用法。验证后 fixed 或 rejected（附验证过程） |
| `[取舍]` | **翻译取舍**：小取舍 Claude 选保守方案并说明理由；大取舍标记 `deferred` 让用户决定 |
| `[质量]` | Claude 自行判断，接受或拒绝并给出理由 |

## 心态切换

**重要**：处理 Codex 反馈时，切换到验证者心态。默认假设 Codex 可能是对的，你的任务是**验证**而非反驳。"我觉得不对"不是有效的 reject 理由——必须有具体依据。

## 辩论记录格式

```markdown
## 轮次 1

| ID | 类型 | 级别 | 问题 | 状态 | 处理说明 |
|----|------|------|------|------|----------|
| D-1 | 事实 | P0 | 问题描述 | fixed | 经验证确认，如何修复 |
| D-2 | 取舍 | P1 | 问题描述 | deferred | 已翻译取舍问用户 |
| D-3 | 事实 | P1 | 问题描述 | rejected | 经验证 Codex 判断有误，验证过程：... |
| D-4 | 质量 | P2 | 问题描述 | skipped | — |
```

状态有四种：`fixed`、`rejected`（附验证过程或理由）、`deferred`（提交用户）、`skipped`。

## 流程

### 准备

1. 确认当前在 git 仓库中（运行 `git rev-parse --is-inside-work-tree`）
2. 清理并创建 `.design/` 目录（`rm -rf .design && mkdir -p .design`）
3. 告知用户："开始设计辩论阶段"

### 设计辩论

1. 分析当前项目结构和代码，理解需求上下文
2. 按以下固定模板写设计文档到 `.design/design.md`：

```markdown
# 设计文档：<需求简述>

## 原始需求
> <逐字引用 $ARGUMENTS>

## 目标
- <要达成什么>

## 非目标
- <明确不做什么>

## 方案概述
<用 1-3 段话描述核心方案>

## 文件清单
| 文件 | 操作 | 说明 |
|------|------|------|
| path/to/file | 新建/修改/删除 | 一句话说明改什么 |

## 接口变更
<如果有 API/函数签名/配置格式变更，写新旧对比；如无则写"无">

## 边界情况与风险
| 场景 | 处理方式 |
|------|----------|
| <异常/边界场景> | <如何处理> |
```

3. **需求自检**：逐条对照原始需求检查设计文档——每个要点是否有对应？是否有超出范围的内容？
4. **用户检查点**：向用户展示设计文档摘要（目标、方案概述、文件清单），询问："方向对吗？确认后我发给 Codex 审查。"等待用户确认。
5. **确定 Codex 文件列表**：确认以下文件是否存在（不需要读取内容）：
   - `~/.claude/prompts/dual-agent/architect.md`（角色 prompt）
   - 项目根目录的 `CLAUDE.md`（如果存在）
   - `.claude/codex-context.md`（如果存在，用 Read 读取 manifest，解析出文件路径列表。仅首轮传递）
   - `.design/design.md`（设计文档）
6. 调用 Codex 审查设计（启用 session + 保存原始输出），通过 `--file` 传递文件：

```
~/.claude/bin/codex-call \
  --file ~/.claude/prompts/dual-agent/architect.md \
  --file CLAUDE.md \
  --file .design/design.md \
  <如果有 codex-context.md 中的文件，每个加 --file> \
  --session-file .design/.codex-session \
  --save-output .design/codex-raw-design-1.md \
  - <<'PROMPT'
<REQUIREMENT>
此处逐字引用用户原始需求
</REQUIREMENT>

审查 design.md 中的设计方案。按照 architect.md 中定义的角色要求和检查清单输出审查结论。
PROMPT
```

7. 处理 Codex 的反馈（**注意心态切换**）：
   - 按"分歧解决机制"分类处理每条 P0/P1
   - 如果建议会改变需求范围 → 标记 `deferred`，翻译后呈现给用户
   - 更新 `.design/design.md`
   - 按结构化表格格式将本轮结果追加到 `.design/design-debate.md`
   - 告知用户 Codex 原始输出已保存到 `.design/codex-raw-design-N.md`
8. 第 2 轮及之后：读取 `.design/.codex-session` 获取 session ID，使用 `--resume` 复用会话：

```
~/.claude/bin/codex-call \
  --file ~/.claude/prompts/dual-agent/architect.md \
  --file .design/design.md \
  --file .design/design-debate.md \
  --resume <SESSION_ID> \
  --session-file .design/.codex-session \
  --save-output .design/codex-raw-design-N.md \
  - <<'PROMPT'
<REQUIREMENT>
此处逐字引用用户原始需求
</REQUIREMENT>

以上是之前轮次的处理记录（见 design-debate.md）。状态为 fixed 的问题已修复，状态为 rejected 的问题不要重复提出，除非你认为拒绝理由有具体的技术错误并能给出反驳。只关注：1）验证 fixed 问题是否真正解决，2）发现新的问题。

审查更新后的 design.md。按照角色要求输出审查结论。
PROMPT
```

9. **自适应轮次与收敛判断**：
   - Codex 返回无新 P0/P1 → 直接通过
   - Codex 只重复了已 rejected 的问题且无新的技术反驳 → 直接通过
   - 有新 P0 → 继续（最多 3 轮）
   - 只有新 P1 → 继续（最多 2 轮）
   - 剩余问题全是取舍类且已 deferred → 直接通过
   - 达到上限仍有未解决的 P0/P1 → 停止，告知用户

### 完成

1. 告知用户设计辩论完成，列出产物：
   - `.design/design.md` — 最终设计文档
   - `.design/design-debate.md` — 辩论记录
   - `.design/codex-raw-*.md` — Codex 原始输出（可审计）
   - `.design/.codex-session` — Codex 会话 ID（供后续流程复用）
2. 提示用户："设计完成。如需继续实现，可使用 `/dual-agent` 执行完整流程。"

## 需求

$ARGUMENTS
