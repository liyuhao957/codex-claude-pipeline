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

## 流程

### 准备

1. 确认当前在 git 仓库中（运行 `git rev-parse --is-inside-work-tree`）
2. 创建 `.design/` 目录（`mkdir -p .design`）
3. 告知用户："开始三阶段双 Agent 协作流程"

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
审查 .design/design.md 中的设计文档。

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
5. 如果有 P0/P1 被修复，再调 Codex 审查（回到步骤 3）
6. 无 P0/P1 → 告知用户"设计通过"，进入阶段二
7. 满 3 轮仍有 P0/P1 → 停止，告知用户未解决的问题，询问是否继续

### 阶段二：实现

1. 读取 `.design/design.md` 中的最终设计
2. 实现所有代码改动
3. 运行项目的构建/测试命令
4. 写改动摘要到 `.design/changeset.md`，包含：
   - 修改/新建的文件清单
   - 风险点
   - 需要人工确认的事项

### 阶段三：代码审查（最多 3 轮）

1. 获取 git diff（`git diff` 或 `git diff HEAD`）
2. 调用 Codex 审查代码：

```
~/.claude/bin/codex-call - <<'PROMPT'
审查当前项目的代码改动。

上下文：
- 设计文档在 .design/design.md
- 改动摘要在 .design/changeset.md

要求：
- 审查代码质量、安全性、性能、正确性
- 每个问题标注 P0/P1/P2
- 如果需要改动，给出具体修改建议
PROMPT
```

3. 处理 Codex 的反馈：
   - 逐条修复 P0/P1
   - 将本轮辩论记录追加到 `.design/implementation-debate.md`
4. 修复后再调 Codex 审查（回到步骤 2）
5. 无 P0/P1 → 告知用户"代码审查通过，流程完成"
6. 满 3 轮仍有 P0/P1 → 停止，告知用户未解决的问题

### 完成

告知用户流程结果，列出 `.design/` 目录下的产物。

## 需求

$ARGUMENTS
