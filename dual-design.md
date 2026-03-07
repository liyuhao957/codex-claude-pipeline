# Dual-Agent 设计辩论

你正在执行双 Agent 协作流程的**设计阶段**。只做设计辩论，不实现代码。

## 角色

- **你（Claude Code）**：决策者 + 设计文档编写者。
- **Codex**：只读顾问。通过 `~/.claude/bin/codex-call` 调用。Codex 可以读项目文件但不能写。它的输出是建议，你来决定如何采纳。

## 辩论规则

- Codex 返回的 **P0**（必须修复）和 **P1**（应当修复）问题，你必须逐条处理：
  - 接受并修复，或
  - 给出明确的技术理由说明为什么不改
  - **不能默默跳过**
- **P2**（建议改进）：可酌情忽略
- 每轮处理结果按**结构化表格格式**记录到 `.design/design-debate.md`
- 更新 `.design/` 文件时优先用 Edit 工具做增量修改，避免 Write 覆盖整文件

### 辩论记录格式

```markdown
## 轮次 1

| ID | 级别 | 问题 | 状态 | 处理说明 |
|----|------|------|------|----------|
| D-1 | P0 | 问题描述 | fixed | 如何修复 |
| D-2 | P1 | 问题描述 | rejected | 拒绝理由 |
| D-3 | P2 | 问题描述 | skipped | — |
```

状态只有三种：`fixed`、`rejected`、`skipped`。

## 流程

### 准备

1. 确认当前在 git 仓库中（运行 `git rev-parse --is-inside-work-tree`）
2. 清理并创建 `.design/` 目录（`rm -rf .design && mkdir -p .design`）
3. 告知用户："开始设计辩论阶段"

### 设计辩论（最多 3 轮）

1. 分析当前项目结构和代码，理解需求上下文
2. 按以下固定模板写设计文档到 `.design/design.md`：

```markdown
# 设计文档：<需求简述>

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

3. **准备 Codex prompt**：用 Read 工具读取：
   - `~/.claude/prompts/dual-agent/architect.md`（角色 prompt）
   - 项目根目录的 `CLAUDE.md`（如果存在，作为项目上下文）
   - `.design/design.md`（设计文档）
4. 调用 Codex 审查设计（启用 session 以便后续流程复用），将所有内容内联：

```
~/.claude/bin/codex-call --session-file .design/.codex-session - <<'PROMPT'
<architect.md 的内容>
---

<PROJECT>
此处内联项目 CLAUDE.md 的内容（如果不存在则省略此标签）
</PROJECT>

<DESIGN>
此处内联 .design/design.md 的完整内容
</DESIGN>

审查以上设计文档。按照角色要求输出审查结论。
PROMPT
```

5. 处理 Codex 的反馈：
   - 逐条处理 P0/P1（修复或反驳）
   - 更新 `.design/design.md`
   - 按结构化表格格式将本轮结果追加到 `.design/design-debate.md`
6. 第 2 轮及之后：读取 `.design/.codex-session` 获取 session ID，使用 `--resume` 复用会话。用 Read 工具读取更新后的 `.design/design.md` 和 `.design/design-debate.md`，全部内联：

```
~/.claude/bin/codex-call --resume <SESSION_ID> --session-file .design/.codex-session - <<'PROMPT'
<architect.md 的内容>
---

<PROJECT>
此处内联项目 CLAUDE.md 的内容（如果不存在则省略此标签）
</PROJECT>

<DESIGN>
此处内联更新后的 .design/design.md 完整内容
</DESIGN>

<DEBATE_HISTORY>
此处内联 .design/design-debate.md 完整内容
</DEBATE_HISTORY>

以上是之前轮次的处理记录。状态为 fixed 的问题已修复，状态为 rejected 的问题不要重复提出，除非你认为拒绝理由有具体的技术错误并能给出反驳。只关注：1）验证 fixed 问题是否真正解决，2）发现新的问题。

审查以上设计文档。按照角色要求输出审查结论。
PROMPT
```

7. 收敛判断（满足任一即通过）：
   - Codex 返回无新 P0/P1 → 直接通过
   - Codex 只重复了已 rejected 的问题且无新的技术反驳 → 视为无新问题，直接通过
8. 继续下一轮的条件：有新 P0/P1，或对之前 rejected 的问题给出了实质性技术反驳
9. 满 3 轮仍有未解决的 P0/P1 → 停止，告知用户未解决的问题

### 完成

1. 告知用户设计辩论完成，列出产物：
   - `.design/design.md` — 最终设计文档
   - `.design/design-debate.md` — 辩论记录
   - `.design/.codex-session` — Codex 会话 ID（供后续流程复用）
2. 提示用户："设计完成。如需继续实现，可使用 `/dual-agent` 执行完整流程。"

## 需求

$ARGUMENTS
