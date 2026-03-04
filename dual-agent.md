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

超时默认 600 秒。如果超时，告知用户并询问是否重试。

## 辩论规则

- Codex 返回的 **P0**（必须修复）和 **P1**（应当修复）问题，你必须逐条处理：
  - 接受并修复，或
  - 给出明确的技术理由说明为什么不改
  - **不能默默跳过**
- **P2**（建议改进）：可酌情忽略
- 每轮处理结果追加记录到对应的 debate 文件
- 更新 `.design/` 文件时优先用 Edit 工具做增量修改，避免 Write 覆盖整文件

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
2. 写设计文档到 `.design/design.md`，包含：
   - 目标 / 非目标
   - 方案概述
   - 要修改的文件清单
   - 边界情况
3. 调用 Codex 审查设计：

```
~/.claude/bin/codex-call - <<'PROMPT'
读取 .design/design.md 文件内容，审查其中的设计文档。

要求：
- 指出设计缺陷、遗漏、潜在问题
- 每个问题标注严重级别：P0（必须修复）、P1（应当修复）、P2（建议改进）
- 给出具体的改进建议
PROMPT
```

4. 处理 Codex 的反馈：
   - 逐条处理 P0/P1（修复或反驳）
   - 更新 `.design/design.md`
   - 将本轮辩论记录追加到 `.design/design-debate.md`
5. 第 2 轮及之后调用 Codex 时，在 prompt 中附上 `.design/design-debate.md` 的内容，并加上指令：

> 以下是之前轮次的处理记录。已接受的问题已修复，已拒绝的问题不要重复提出，除非你认为拒绝理由有具体的技术错误并能给出反驳。只关注：1）验证已修复的问题是否真正解决，2）发现新的问题。

6. 收敛判断（满足任一即通过，进入阶段二）：
   - Codex 返回无新 P0/P1 → 直接通过
   - Codex 只重复了已拒绝的问题且无新的技术反驳 → 视为无新问题，直接通过
7. 继续下一轮的条件：有新 P0/P1，或对之前拒绝的问题给出了实质性技术反驳
8. 满 3 轮仍有未解决的 P0/P1 → 停止，告知用户未解决的问题，询问是否继续

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

1. 获取精确范围的 diff 并保存到文件（`diff.txt` 是给 Codex 读的中间产物，不需要入 commit）：
   - 优先：`git diff $BASE_BRANCH...HEAD > .design/diff.txt`（只含本分支改动）
   - 备选（尚未 commit）：`git diff --cached -- file1 file2 ... > .design/diff.txt`
   - 备选（用户跳过了建分支）：只 diff design.md 中列出的文件 → `git diff -- file1 file2 ... > .design/diff.txt`
2. 从 `.design/design.md` 提取要修改的文件清单，作为审查范围
3. 调用 Codex 审查代码：

```
~/.claude/bin/codex-call - <<'PROMPT'
审查当前项目的代码改动。

上下文：
- 设计文档在 .design/design.md
- 改动摘要在 .design/changeset.md
- git diff 输出在 .design/diff.txt

审查范围仅限以下文件（来自 design.md 的文件清单）：
<此处列出文件清单>

要求：
- 只审查上述范围内的改动，忽略范围外的文件
- 审查代码质量、安全性、性能、正确性
- 每个问题标注 P0/P1/P2
- 如果需要改动，给出具体修改建议
PROMPT
```

4. 处理 Codex 的反馈：
   - 逐条修复 P0/P1
   - 将本轮辩论记录追加到 `.design/implementation-debate.md`
5. **刷新 diff**：修复代码后重新生成 diff（`git diff $BASE_BRANCH...HEAD > .design/diff.txt`），确保下一轮 Codex 审查的是最新代码
6. 第 2 轮及之后调用 Codex 时，在 prompt 中附上 `.design/implementation-debate.md` 的内容，并加上指令：

> 以下是之前轮次的处理记录。已接受的问题已修复，已拒绝的问题不要重复提出，除非你认为拒绝理由有具体的技术错误并能给出反驳。只关注：1）验证已修复的问题是否真正解决，2）发现新的问题。

7. 收敛判断（满足任一即通过）：
   - Codex 返回无新 P0/P1 → 直接通过
   - Codex 只重复了已拒绝的问题且无新的技术反驳 → 视为无新问题，直接通过
8. 继续下一轮的条件：有新 P0/P1，或对之前拒绝的问题给出了实质性技术反驳
9. 满 3 轮仍有未解决的 P0/P1 → 停止，告知用户未解决的问题

### 完成

1. 如果阶段三有 P0/P1 修复导致接口或架构变更，回溯更新 `.design/design.md`，使其与最终实现一致。
2. 告知用户流程结果，列出 `.design/` 目录下的产物。
3. 询问用户是否要提交代码（git commit）。如果用户确认，执行 commit。

## 需求

$ARGUMENTS
