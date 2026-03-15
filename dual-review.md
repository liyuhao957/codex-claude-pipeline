# Dual-Agent 代码审查

你正在执行双 Agent 协作流程的**代码审查阶段**。只做代码审查，不做设计和实现。

## 角色

- **你（Claude Code）**：决策者 + 唯一代码修改者。你负责修复审查发现的问题。
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
| R-1 | 事实 | P0 | 问题描述 | fixed | 经验证确认，如何修复 |
| R-2 | 取舍 | P1 | 问题描述 | deferred | 已翻译取舍问用户 |
| R-3 | 质量 | P2 | 问题描述 | skipped | — |
```

状态有四种：`fixed`、`rejected`（附验证过程或理由）、`deferred`（提交用户）、`skipped`。

## Diff 大小控制

如果 diff 超过 500 行，不要全部内联。改为：
- 内联 `git diff --stat` 的输出（文件级别的变更统计）
- 只内联单文件 diff 不超过 100 行的文件
- 超过 100 行的文件只内联前 50 行 + 末尾 20 行，中间用 `... (省略 N 行，请自行读取源文件) ...` 标记

## 流程

### 准备

1. 确认当前在 git 仓库中（运行 `git rev-parse --is-inside-work-tree`）
2. 创建 `.design/` 目录（如果不存在）：`mkdir -p .design`
3. 确定 diff 范围（按优先级尝试）：
   - 如果用户指定了 commit 范围或分支 → 使用指定的范围
   - 如果存在 `.design/design.md` 且有 `BASE_BRANCH` 信息 → 使用 `git diff $BASE_BRANCH...HEAD`
   - 否则 → 使用 `git diff HEAD~1...HEAD`（审查最近一次 commit）
4. 生成 diff：`git diff <范围> > .design/diff.txt`
5. 获取 diff 行数：`wc -l < .design/diff.txt`，记录到变量 `DIFF_LINES`
6. 告知用户："开始代码审查（审查范围：xxx，diff 共 N 行）"

### 代码审查

1. 确定审查文件范围：
   - 如果存在 `.design/design.md` → 从中提取文件清单
   - 否则 → 从 `git diff --name-only <范围>` 获取
2. **准备 Codex prompt**：用 Read 工具读取以下所有内容：
   - `~/.claude/prompts/dual-agent/reviewer.md`（角色 prompt）
   - 项目根目录的 `CLAUDE.md`（如果存在，作为项目上下文）
   - `.claude/codex-context.md`（如果存在，解析 `- ` 开头的行为文件路径，逐一读取。仅首轮发送）
   - `.design/diff.txt`（代码 diff，注意大小控制）
   - `.design/design.md`（如果存在，提供设计上下文）
3. **尝试复用 session**：检查 `.design/.codex-session` 是否存在，如果存在则读取其中的 session ID
4. 调用 Codex 审查代码，将所有内容内联（diff 按大小控制规则处理）：

```
~/.claude/bin/codex-call [--resume <SESSION_ID>] --session-file .design/.codex-session --save-output .design/codex-raw-review-1.md - <<'PROMPT'
<reviewer.md 的内容>
---

<REQUIREMENT>
此处逐字引用用户原始需求（如果有 $ARGUMENTS）
</REQUIREMENT>

<PROJECT>
此处内联项目 CLAUDE.md 的内容（如果不存在则省略此标签）
</PROJECT>

<CONTEXT>
此处内联 .claude/codex-context.md 中列出的所有文件内容（如果不存在则省略此标签）
每个文件用 --- FILE: <路径> --- 分隔
</CONTEXT>

<DIFF>
此处内联 diff 内容（如果超过 500 行，按大小控制规则裁剪）
</DIFF>

审查范围仅限以下文件：
<此处列出文件清单>

按照角色要求输出审查结论。
PROMPT
```

5. 处理 Codex 的反馈（**注意心态切换**）：
   - 按"分歧解决机制"分类处理每条 P0/P1
   - 按结构化表格格式将本轮结果追加到 `.design/implementation-debate.md`
   - 告知用户 Codex 原始输出已保存到 `.design/codex-raw-review-N.md`
6. **刷新 diff**：修复代码后重新生成 diff，确保下一轮 Codex 审查的是最新代码
7. 第 2 轮及之后：继续使用 `--resume` 复用会话：

```
~/.claude/bin/codex-call --resume <SESSION_ID> --session-file .design/.codex-session --save-output .design/codex-raw-review-N.md - <<'PROMPT'
<reviewer.md 的内容>
---

<REQUIREMENT>
此处逐字引用用户原始需求（如果有 $ARGUMENTS）
</REQUIREMENT>

<DIFF>
此处内联最新的 diff 内容（按大小控制规则处理）
</DIFF>

<REVIEW_HISTORY>
此处内联 .design/implementation-debate.md 完整内容
</REVIEW_HISTORY>

以上是之前轮次的处理记录。状态为 fixed 的问题已修复，状态为 rejected 的问题不要重复提出，除非你认为拒绝理由有具体的技术错误并能给出反驳。只关注：1）验证 fixed 问题是否真正解决，2）发现新的问题。

按照角色要求输出审查结论。
PROMPT
```

8. **自适应轮次与收敛判断**：
   - Codex 返回无新 P0/P1 → 直接通过
   - Codex 只重复了已 rejected 的问题且无新的技术反驳 → 直接通过
   - 有新 P0 → 继续（最多 3 轮）
   - 只有新 P1 → 继续（最多 2 轮）
   - 剩余问题全是取舍类且已 deferred → 直接通过
   - 达到上限仍有未解决的 P0/P1 → 停止，告知用户

### 完成

1. 告知用户审查结果，列出产物：
   - `.design/diff.txt` — 审查的 diff
   - `.design/implementation-debate.md` — 辩论记录
   - `.design/codex-raw-*.md` — Codex 原始输出（可审计）
2. 如果有代码修复，询问用户是否要提交代码（git commit）。

## 需求

$ARGUMENTS
