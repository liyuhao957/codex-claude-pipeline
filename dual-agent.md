# Dual-Agent 协作流程

你正在执行一个双 Agent 协作流程。严格按以下规则执行，不要跳过任何阶段。

## 角色

- **你（Claude Code）**：决策者 + 唯一代码编写者。你负责写设计、实现代码、修复问题。
- **Codex**：只读顾问。通过 `~/.claude/bin/codex-call` 调用。Codex 可以读项目文件但不能写。它的输出是建议，你来决定如何采纳。

## 调用 Codex 的方式

使用 Bash 工具调用：

```
Bash("~/.claude/bin/codex-call 'your prompt here'")
```

或者用 stdin 传递长 prompt：

```
Bash("~/.claude/bin/codex-call - <<'PROMPT'\nyour long prompt here\nPROMPT")
```

**Session 模式**（启用会话复用）：

```
Bash("~/.claude/bin/codex-call --session-file .design/.codex-session - <<'PROMPT'\nyour prompt\nPROMPT")
```

```
Bash("~/.claude/bin/codex-call --resume SESSION_ID --session-file .design/.codex-session - <<'PROMPT'\nyour prompt\nPROMPT")
```

超时默认 600 秒。如果超时，告知用户并询问是否重试。

## 给 Codex 的 Prompt 拼接规则

调用 Codex 前，Claude Code 必须：
1. **读角色 prompt**：用 Read 工具读取对应阶段的角色文件
   - 阶段一：`~/.claude/prompts/dual-agent/architect.md`
   - 阶段三：`~/.claude/prompts/dual-agent/reviewer.md`
2. **读项目上下文**：用 Read 工具读取项目根目录的 `CLAUDE.md`（如果存在）
3. **读上下文文件**：用 Read 工具读取 Codex 需要审查的所有文件内容（设计文档、diff 等）

**关键原则**：不要让 Codex 自己去读文件。所有内容都内联到 prompt 里，用 XML 标签分隔：

```
<角色 prompt 内容>
---

<PROJECT>
项目 CLAUDE.md 的内容（技术栈、目录结构、约定）
</PROJECT>

<DESIGN>
design.md 的完整内容
</DESIGN>

<其他上下文标签>
...
</其他上下文标签>

具体任务指令...
```

**Diff 大小控制**：如果 `.design/diff.txt` 超过 500 行，不要全部内联。改为：
- 内联 `git diff --stat` 的输出（文件级别的变更统计）
- 只内联单文件 diff 不超过 100 行的文件
- 超过 100 行的文件只内联前 50 行 + 末尾 20 行，中间用 `... (省略 N 行，请自行读取源文件) ...` 标记

## 辩论规则

- Codex 返回的 **P0**（必须修复）和 **P1**（应当修复）问题，你必须逐条处理：
  - 接受并修复，或
  - 给出明确的技术理由说明为什么不改
  - **不能默默跳过**
- **P2**（建议改进）：可酌情忽略
- 每轮处理结果按**结构化格式**记录到对应的 debate 文件（见下方格式）
- 更新 `.design/` 文件时优先用 Edit 工具做增量修改，避免 Write 覆盖整文件

### 辩论记录格式

debate 文件（`design-debate.md` 和 `implementation-debate.md`）必须使用以下表格格式：

```markdown
## 轮次 1

| ID | 级别 | 问题 | 状态 | 处理说明 |
|----|------|------|------|----------|
| D-1 | P0 | 缺少鉴权检查 | fixed | 已在 design.md 补充鉴权方案 |
| D-2 | P1 | 缓存策略未说明 | rejected | 当前规模无需缓存，理由：... |
| D-3 | P2 | 建议加监控 | skipped | — |

## 轮次 2

| ID | 级别 | 问题 | 状态 | 处理说明 |
|----|------|------|------|----------|
| D-4 | P1 | 新发现：并发写入风险 | fixed | 已补充事务处理 |
```

状态只有三种：`fixed`（已修复）、`rejected`（已拒绝并给出理由）、`skipped`（P2 跳过）。

## 流程

### 准备

1. 确认当前在 git 仓库中（运行 `git rev-parse --is-inside-work-tree`）
2. 检查工作区是否干净（`git status --porcelain`）
   - 如果有未提交的改动 → 警告用户，建议先 `git commit` 或 `git stash` 再继续
   - 用户确认继续后才往下走
3. 创建 feature 分支：`git checkout -b feat/<需求简述>`
   - 分支名从需求中提取关键词，用英文小写 + 短横线，如 `feat/add-login-page`
   - 记录基准分支名到变量 `BASE_BRANCH`（即创建分支前所在的分支），后续 diff 使用
4. 清理并创建 `.design/` 目录（`rm -rf .design && mkdir -p .design`）
5. 告知用户："开始三阶段双 Agent 协作流程（分支：feat/xxx，基准：BASE_BRANCH）"

### 阶段一：设计辩论（最多 3 轮）

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
4. 调用 Codex 审查设计（首次调用启用 session），将所有内容内联：

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
6. 第 2 轮及之后：读取 `.design/.codex-session` 获取 session ID，使用 `--resume` 复用会话。用 Read 工具读取更新后的 `.design/design.md` 和 `.design/design-debate.md`，全部内联到 prompt 中：

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

7. 收敛判断（满足任一即通过，进入阶段二）：
   - Codex 返回无新 P0/P1 → 直接通过
   - Codex 只重复了已 rejected 的问题且无新的技术反驳 → 视为无新问题，直接通过
8. 继续下一轮的条件：有新 P0/P1，或对之前 rejected 的问题给出了实质性技术反驳
9. 满 3 轮仍有未解决的 P0/P1 → 停止，告知用户未解决的问题，询问是否继续

### 阶段二：实现

1. 读取 `.design/design.md` 中的最终设计
2. 实现所有代码改动
3. 运行项目的构建/测试命令
4. 写改动摘要到 `.design/changeset.md`，包含：
   - 修改/新建的文件清单（必须与实际改动的文件一一对应，不多不少）
   - 风险点
   - 需要人工确认的事项
   - 注意：实现全部完成后，用 `git diff --name-only $BASE_BRANCH...HEAD` 交叉验证文件清单的准确性（如果尚未 commit，用 `git diff --name-only --cached` 替代）。验证时忽略 `.design/` 目录和构建系统自动生成的文件（如 `.xcodeproj`、`package-lock.json`），只核对源码文件

### 阶段三：代码审查（最多 3 轮）

1. 获取精确范围的 diff 并保存到文件：
   - 优先：`git diff $BASE_BRANCH...HEAD > .design/diff.txt`（只含本分支改动）
   - 备选（尚未 commit）：`git diff --cached -- file1 file2 ... > .design/diff.txt`
   - 备选（用户跳过了建分支）：只 diff design.md 中列出的文件 → `git diff -- file1 file2 ... > .design/diff.txt`
   - 同时获取 diff 行数：`wc -l < .design/diff.txt`，记录到变量 `DIFF_LINES`
2. 从 `.design/design.md` 提取要修改的文件清单，作为审查范围
3. **准备 Codex prompt**：用 Read 工具读取以下所有内容：
   - `~/.claude/prompts/dual-agent/reviewer.md`（角色 prompt）
   - 项目根目录的 `CLAUDE.md`（如果存在，作为项目上下文）
   - `.design/design.md`（设计文档）
   - `.design/changeset.md`（改动摘要）
   - `.design/diff.txt`（代码 diff，注意大小控制）
4. **尝试复用 session**：检查 `.design/.codex-session` 是否存在，如果存在则读取其中的 session ID
5. 调用 Codex 审查代码，将所有内容内联（diff 按大小控制规则处理）：

```
~/.claude/bin/codex-call --resume <SESSION_ID> --session-file .design/.codex-session - <<'PROMPT'
<reviewer.md 的内容>
---

<PROJECT>
此处内联项目 CLAUDE.md 的内容（如果不存在则省略此标签）
</PROJECT>

<DESIGN>
此处内联 .design/design.md 的完整内容
</DESIGN>

<CHANGESET>
此处内联 .design/changeset.md 的完整内容
</CHANGESET>

<DIFF>
此处内联 diff 内容（如果超过 500 行，按大小控制规则裁剪）
</DIFF>

审查范围仅限以下文件：
<此处列出文件清单>

按照角色要求输出审查结论。
PROMPT
```

6. 处理 Codex 的反馈：
   - 逐条修复 P0/P1
   - 按结构化表格格式将本轮结果追加到 `.design/implementation-debate.md`
7. **刷新 diff**：修复代码后重新生成 diff（`git diff $BASE_BRANCH...HEAD > .design/diff.txt`），确保下一轮 Codex 审查的是最新代码
8. 第 2 轮及之后：继续使用 `--resume` 复用会话。用 Read 工具重新读取最新的 `.design/diff.txt` 和 `.design/implementation-debate.md`，全部内联：

```
~/.claude/bin/codex-call --resume <SESSION_ID> --session-file .design/.codex-session - <<'PROMPT'
<reviewer.md 的内容>
---

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

9. 收敛判断（满足任一即通过）：
   - Codex 返回无新 P0/P1 → 直接通过
   - Codex 只重复了已 rejected 的问题且无新的技术反驳 → 视为无新问题，直接通过
10. 继续下一轮的条件：有新 P0/P1，或对之前 rejected 的问题给出了实质性技术反驳
11. 满 3 轮仍有未解决的 P0/P1 → 停止，告知用户未解决的问题

### 完成

1. 如果阶段三有 P0/P1 修复导致接口或架构变更，回溯更新 `.design/design.md`，使其与最终实现一致。
2. 告知用户流程结果，列出 `.design/` 目录下的产物。
3. 询问用户是否要提交代码（git commit）。如果用户确认，执行 commit。

## 需求

$ARGUMENTS
